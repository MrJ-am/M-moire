(in-package #:matheval)

(defstruct (contexte (:constructor faire-contexte (&key connexion version activation)))
  connexion version activation)

(defun refuser-acces (status message)
  (error 'validation-error :status status :message message))

(defun avec-base (contexte fonction)
  (mrjam-native:avec-connexion (contexte-connexion contexte) fonction))

(defun lignes-json (connexion sql &optional valeurs)
  (mapcar (lambda (row) (parse-json (cdr (first row))))
          (mrjam-native:requete connexion sql valeurs)))

(defun un-json (connexion sql &optional valeurs)
  (first (lignes-json connexion sql valeurs)))

(defun parametre (v)
  (cond ((stringp v) v) ((eq v :null) :null) (t (mrjam-native:json-js v))))

(defun egal-json-p (a b)
  (cond ((and (numberp a) (numberp b)) (= a b))
        ((and (json-object-p a) (json-object-p b))
         (and (= (length (json-object-entries a)) (length (json-object-entries b)))
              (every (lambda (p) (multiple-value-bind (v present) (json-object-get b (car p))
                                  (and present (egal-json-p (cdr p) v)))) (json-object-entries a))))
        ((and (json-array-p a) (json-array-p b))
         (let ((aa (json-array-items a)) (bb (json-array-items b)))
           (and (= (length aa) (length bb)) (every #'egal-json-p aa bb))))
        (t (equal a b))))

(defun importer-corpus (contexte banque codebook)
  "Opération explicite d'exploitation ; aucune migration ou connexion au chargement."
  (let ((hash (mrjam-native:sha256 (mrjam-native:json-js (jobject "bank" banque "codebook" codebook)))))
    (avec-base contexte
      (lambda (c)
        (mrjam-native:transaction c
          (lambda (c)
            (mrjam-native:requete c "SELECT pg_advisory_xact_lock(78041002)")
            (let ((ancien (un-json c "SELECT row_to_json(t)::text FROM (SELECT digest FROM corpus WHERE version=$1) t"
                                  (list (champ banque "version")))))
              (when (and ancien (not (equal (champ ancien "digest") hash)))
                (refuser-acces 409 "Le corpus a changé : attribuez-lui une nouvelle BANK_VERSION avant le déploiement.")))
            (mrjam-native:requete c "INSERT INTO corpus(version,digest,bank,codebook) VALUES($1,$2,$3::jsonb,$4::jsonb) ON CONFLICT DO NOTHING"
                                 (list (champ banque "version") hash (mrjam-native:json-js banque) (mrjam-native:json-js codebook)))))))))

(defparameter +participation-json+
  "SELECT (to_jsonb(p) || jsonb_build_object('bank',c.bank,
    'started_at',to_char(p.started_at AT TIME ZONE 'UTC','YYYY-MM-DD\"T\"HH24:MI:SS.MS\"Z\"'),
    'updated_at',to_char(p.updated_at AT TIME ZONE 'UTC','YYYY-MM-DD\"T\"HH24:MI:SS.MS\"Z\"'),
    'completed_at',to_char(p.completed_at AT TIME ZONE 'UTC','YYYY-MM-DD\"T\"HH24:MI:SS.MS\"Z\"')))::text
   FROM participations p JOIN corpus c ON c.version=p.bank_version WHERE p.id=$1::uuid")

(defun participation (c id &key verrou)
  (un-json c (concatenate 'string +participation-json+ (if verrou " FOR UPDATE OF p" "")) (list id)))

(defun autoriser-participation (p secret)
  (unless (and p (stringp secret)
               (mrjam-native:secret-egal-p (champ p "token_hash") (mrjam-native:sha256 secret)))
    (refuser-acces 401 "Accès à cette participation refusé.")) p)

(defun id-ressource (id)
  ;; L'ancien filtre hex/traits d'union acceptait des UUID invalides, puis donnait 500.
  ;; Les UUID historiques sont lus sans imposer les bits version/variant de
  ;; la validation de création Zod. Ne jamais réidentifier une participation.
  (unless (uuid-syntaxe-p id) (refuser-acces 404 "Participation introuvable.")) id)

(defun vue-session (p)
  (let ((banque (champ p "bank")))
    (jobject "id" (champ p "id") "bankVersion" (champ p "bank_version")
      "levels" (champ p "levels") "seed" (champ p "seed") "startedAt" (champ p "started_at")
      "revision" (champ p "revision") "completedAt" (champ p "completed_at") "snapshot" (champ p "snapshot")
      "questions" (tableau
        (loop for id in (json-array-items (champ p "question_order"))
              for q = (find id (json-array-items (champ banque "questions")) :key (lambda (q) (champ q "id")) :test #'equal)
              collect (jobject "id" id "level" (champ q "level") "domain" (champ q "domain")
                         "statement" (champ q "statement") "productions"
                         (tableau (loop for pid in (json-array-items (champ (champ p "production_order") id))
                                        for production = (find pid (json-array-items (champ q "productions")) :key (lambda (v) (champ v "id")) :test #'equal)
                                        collect (jobject "id" pid "content" (champ production "content"))))))))))

(defun creer-session (contexte brut)
  (let ((donnees (valider-participation brut)))
    (avec-base contexte
      (lambda (c)
        (mrjam-native:transaction c
          (lambda (c)
            (let* ((banque (un-json c "SELECT bank::text FROM corpus WHERE version=$1" (list (champ donnees "bankVersion"))))
                   (niveaux (json-array-items (champ donnees "levels"))))
              (unless banque (refuser "Version du questionnaire inconnue."))
              (unless (and (= (length niveaux) (length (remove-duplicates niveaux :test #'equal)))
                           (every (lambda (niveau) (some (lambda (q) (equal (champ q "level") niveau))
                                                        (json-array-items (champ banque "questions")))) niveaux))
                (refuser "Niveau inconnu."))
              (let* ((questions (preparer-session banque niveaux (champ donnees "seed")))
                     (ordre (tableau (mapcar (lambda (q) (champ q "id")) questions)))
                     (productions (vision::%make-json-object
                                   (loop for q in questions collect
                                     (cons (champ q "id") (tableau (mapcar (lambda (p) (champ p "id"))
                                                                          (json-array-items (champ q "productions")))))))))
                (mrjam-native:requete c
                  "INSERT INTO participations(id,token_hash,bank_version,levels,seed,question_order,production_order)
                   VALUES($1::uuid,$2,$3,ARRAY(SELECT jsonb_array_elements_text($4::jsonb)),$5::bigint,
                          ARRAY(SELECT jsonb_array_elements_text($6::jsonb)),$7::jsonb) ON CONFLICT DO NOTHING"
                  (mapcar #'parametre (list (champ donnees "id") (mrjam-native:sha256 (champ donnees "secret"))
                                             (champ donnees "bankVersion") (champ donnees "levels")
                                             (champ donnees "seed") ordre productions))))
              (let ((p (participation c (champ donnees "id"))))
                (unless (mrjam-native:secret-egal-p (champ p "token_hash") (mrjam-native:sha256 (champ donnees "secret")))
                  (refuser-acces 409 "Cet identifiant est déjà utilisé."))
                (unless (and (equal (champ p "bank_version") (champ donnees "bankVersion"))
                             (= (champ p "seed") (champ donnees "seed"))
                             (egal-json-p (champ p "levels") (champ donnees "levels")))
                  (refuser-acces 409 "Les paramètres de cette participation sont déjà fixés."))
                (vue-session p)))))))))

(defun lire-session (contexte id secret)
  (id-ressource id)
  (avec-base contexte (lambda (c) (vue-session (autoriser-participation (participation c id) secret)))))

(defun evenements (c id)
  (lignes-json c "SELECT payload::text FROM interaction_events WHERE participation_id=$1::uuid ORDER BY sequence" (list id)))

(defun lire-evenements (contexte id secret)
  (id-ressource id)
  (avec-base contexte
    (lambda (c)
      (mrjam-native:transaction c
        (lambda (c)
          (autoriser-participation (participation c id) secret)
          (tableau (evenements c id))) :lecture-seule t))))

(defun vue-sauvegarde (p)
  (jobject "revision" (champ p "revision") "savedAt" (champ p "updated_at") "completedAt" (champ p "completed_at")))

(defun sauvegarder-session (contexte id secret brut)
  (id-ressource id)
  (let* ((donnees (valider-sauvegarde brut))
         (hash (mrjam-native:sha256 (mrjam-native:json-js donnees))))
    (avec-base contexte
      (lambda (c)
        (mrjam-native:transaction c
          (lambda (c)
            (let ((p (autoriser-participation (participation c id :verrou t) secret)))
              (when (and (= (champ p "revision") (champ donnees "revision")) (equal (champ p "payload_hash") hash))
                (return-from sauvegarder-session (vue-sauvegarde p)))
              (unless (absence-p (champ p "completed_at")) (refuser-acces 409 "Cette participation est déjà validée."))
              (when (<= (champ donnees "revision") (champ p "revision"))
                (refuser-acces 409 "Une version plus récente existe. Rechargez la page pour la retrouver."))
              (let* ((productions (valider-rattachements donnees p (champ p "bank")))
                     (anciens (evenements c id)) (nouveaux (json-array-items (champ donnees "events"))))
                (unless (and (>= (length nouveaux) (length anciens)) (every #'egal-json-p anciens nouveaux))
                  (refuser-acces 409 "Le journal de cette participation a déjà progressé."))
                (mrjam-native:requete c "DELETE FROM answers WHERE participation_id=$1::uuid" (list id))
                (dolist (paire (json-object-entries (champ (champ donnees "snapshot") "answers")))
                  (let* ((pid (car paire)) (a (cdr paire)) (coords (champ a "coordinates")))
                    (mrjam-native:requete c
                      "INSERT INTO answers(participation_id,question_id,production_id,note,initial_note,x,y,z,evaluated_axes)
                       VALUES($1::uuid,$2,$3,$4::numeric,$5::numeric,$6::float8,$7::float8,$8::float8,
                              ARRAY(SELECT jsonb_array_elements_text($9::jsonb)))"
                      (mapcar #'parametre (list id (gethash pid productions) pid (champ a "note") (champ a "initialNote")
                                               (champ coords "x") (champ coords "y") (champ coords "z") (champ a "evaluatedAxes"))))))
                (loop for e in (nthcdr (length anciens) nouveaux) for i from (length anciens) do
                  (mrjam-native:requete c
                    "INSERT INTO interaction_events(participation_id,sequence,event,occurred_at,elapsed_ms,payload)
                     VALUES($1::uuid,$2::int,$3,$4::timestamptz,$5::bigint,$6::jsonb)"
                    (mapcar #'parametre (list id i (champ e "event") (champ e "at") (champ e "elapsedMs") e))))
                (mrjam-native:requete c
                  "UPDATE participations SET snapshot=$2::jsonb,revision=$3::int,payload_hash=$4,updated_at=now(),
                   completed_at=CASE WHEN $5::boolean THEN now() ELSE NULL END WHERE id=$1::uuid"
                  (mapcar #'parametre (list id (champ donnees "snapshot") (champ donnees "revision") hash (champ donnees "final"))))
                (vue-sauvegarde (participation c id))))))))))
