(in-package #:matheval)

(defun identifiants-connexion (objet)
  (schema objet (list (cons "username" (lambda (v) (chaine-bornee v 80)))
                      (cons "password" (lambda (v) (chaine-bornee v 256))))))

(defun identifiants-activation (objet)
  (schema objet (list
    (cons "username" (lambda (v)
                       (chaine-bornee v 1000)
                       (let* ((espaces '(9 10 11 12 13 32 160 5760 8192 8193 8194 8195 8196 8197 8198 8199 8200 8201 8202 8232 8233 8239 8287 12288 65279))
                              (v (string-trim (mapcar #'code-char espaces) v)))
                         (chaine-bornee v 80 3)
                         (unless (every (lambda (c) (or (find c "_.@-")
                                                       (member (sb-unicode:general-category c)
                                                               '(:lu :ll :lt :lm :lo :nd :nl :no)))) v)
                           (refuser "Identifiant administrateur invalide.")) v)))
    (cons "password" (lambda (v) (chaine-bornee v 256 14)))
    (cons "token" (lambda (v)
                    (unless (and (stringp v) (= (length v) 64) (every (lambda (c) (find c "0123456789abcdef")) v))
                      (refuser "Jeton d'activation invalide.")) v)))))

(defun ouvrir-session-administrateur (c admin ancien)
  (let ((secret (mrjam-native:aleatoire-hex)))
    (mrjam-native:requete c "SELECT id FROM administrators WHERE id=$1::int FOR UPDATE" (list (parametre (champ admin "id"))))
    (mrjam-native:requete c
      "DELETE FROM administrator_sessions WHERE expires_at<=now() OR last_seen<=now()-interval '2 hours' OR token_hash=$1"
      (list (mrjam-native:sha256 (or ancien ""))))
    (mrjam-native:requete c
      "DELETE FROM administrator_sessions WHERE token_hash IN
       (SELECT token_hash FROM administrator_sessions WHERE administrator_id=$1::int ORDER BY last_seen DESC,token_hash OFFSET 19)"
      (list (parametre (champ admin "id"))))
    (mrjam-native:requete c "INSERT INTO administrator_sessions(token_hash,administrator_id,expires_at) VALUES($1,$2::int,now()+interval '8 hours')"
                         (list (mrjam-native:sha256 secret) (parametre (champ admin "id"))))
    (values (jobject "username" (champ admin "username")) secret)))

(defun activer-administrateur (contexte objet &optional ancien)
  (let ((data (identifiants-activation objet)))
    (unless (and (contexte-activation contexte)
                 (mrjam-native:secret-egal-p (mrjam-native:sha256 (champ data "token")) (contexte-activation contexte)))
      (refuser-acces 403 "Lien d’activation invalide."))
    (let ((empreinte (mrjam-native:mot-de-passe-encoder (champ data "password"))))
      (avec-base contexte
        (lambda (c)
          (mrjam-native:transaction c
            (lambda (c)
              (mrjam-native:requete c "SELECT pg_advisory_xact_lock(78041003)")
              (when (mrjam-native:requete c "SELECT id FROM administrators LIMIT 1")
                (refuser-acces 409 "Le compte administrateur est déjà activé."))
              (let ((a (un-json c "WITH t AS (INSERT INTO administrators(username,password_hash) VALUES($1,$2) RETURNING id,username) SELECT row_to_json(t)::text FROM t"
                                 (list (champ data "username") empreinte))))
                (ouvrir-session-administrateur c a ancien)))))))))

(defun connecter-administrateur (contexte objet &optional ancien)
  (let ((data (identifiants-connexion objet)))
    (avec-base contexte
      (lambda (c)
        (let* ((admin (un-json c "SELECT row_to_json(t)::text FROM (SELECT id,username,password_hash FROM administrators WHERE username=$1) t"
                              (list (champ data "username"))))
               (empreinte (if admin (champ admin "password_hash")
                              (format nil "scrypt:~A:~A" (make-string 32 :initial-element #\0) (make-string 128 :initial-element #\0))))
               (valide (mrjam-native:mot-de-passe-verifier (champ data "password") empreinte)))
          (unless (and valide admin) (refuser-acces 401 "Identifiant ou mot de passe incorrect."))
          (mrjam-native:transaction c (lambda (c) (ouvrir-session-administrateur c admin ancien))))))))

(defun autoriser-administrateur (c secret)
  (let ((admin (un-json c
                 "WITH t AS (UPDATE administrator_sessions s SET last_seen=now() FROM administrators a
                  WHERE a.id=s.administrator_id AND s.token_hash=$1 AND s.expires_at>now()
                    AND s.last_seen>now()-interval '2 hours' RETURNING a.id,a.username)
                  SELECT row_to_json(t)::text FROM t"
                 (list (mrjam-native:sha256 (or secret ""))))))
    (unless admin (refuser-acces 401 "Connectez-vous à l’administration.")) admin))

(defun avec-science (contexte secret fonction)
  ;; Autorisation scientifique bornée à Matheval, aucune capacité sur Vision.
  (avec-base contexte
    (lambda (c)
      (mrjam-native:transaction c
        (lambda (c) (funcall fonction c (autoriser-administrateur c secret)))))))

(defun administrateur-courant (contexte secret)
  (avec-science contexte secret (lambda (c admin) (declare (ignore c)) (jobject "username" (champ admin "username")))))

(defun deconnecter-administrateur (contexte secret)
  (avec-science contexte secret
    (lambda (c admin) (declare (ignore admin))
      (mrjam-native:requete c "DELETE FROM administrator_sessions WHERE token_hash=$1" (list (mrjam-native:sha256 secret)))
      (jobject "ok" :true))))

(defun corpus-scientifiques (contexte secret)
  (avec-science contexte secret
    (lambda (c admin) (declare (ignore admin))
      (tableau (lignes-json c "SELECT row_to_json(t)::text FROM (SELECT version,
       to_char(imported_at AT TIME ZONE 'UTC','YYYY-MM-DD\"T\"HH24:MI:SS.MS\"Z\"') AS imported_at FROM corpus ORDER BY imported_at DESC) t")))))

(defun corpus-scientifique (contexte secret version)
  (avec-science contexte secret
    (lambda (c admin) (declare (ignore admin))
      (or (un-json c "SELECT row_to_json(t)::text FROM (SELECT bank,codebook FROM corpus WHERE version=$1) t" (list version))
          (refuser-acces 404 "Corpus inconnu.")))))

(defun participation-scientifique (contexte secret id)
  (id-ressource id)
  (avec-science contexte secret
    (lambda (c admin) (declare (ignore admin))
      (let ((p (or (participation c id) (refuser-acces 404 "Participation inconnue."))))
        (vision::%make-json-object (append (json-object-entries (vue-session p))
                                         (list (cons "events" (tableau (evenements c id))))))))))

(defun filtre-scientifique (query)
  (let ((clauses (list "TRUE")) (valeurs nil))
    (labels ((ajouter (sql valeur)
               (push valeur valeurs) (push (format nil sql (length valeurs)) clauses))
             (date (v)
               (unless (and (stringp v) (= (length v) 10) (char= (char v 4) #\-) (char= (char v 7) #\-)
                            (every #'chiffre-ascii-p (remove #\- v))) (refuser "Date invalide."))
               ;; Corrige l'ancien 500 pour les dates calendaires impossibles.
               (date-iso (concatenate 'string v "T00:00:00Z")) v))
      (dolist (cle '("version" "level" "from" "to"))
        (let ((v (champ query cle nil)))
          (when (and v (not (equal v "")))
            (ajouter (cond ((equal cle "version") "p.bank_version=$~D")
                           ((equal cle "level") "$~D=ANY(p.levels)")
                           ((equal cle "from") "p.started_at >= $~D::date")
                           (t "p.started_at < $~D::date + interval '1 day'"))
                     (if (member cle '("from" "to") :test #'equal) (date v) v)))))
      (cond ((equal (champ query "status") "completed") (push "p.completed_at IS NOT NULL" clauses))
            ((equal (champ query "status") "incomplete") (push "p.completed_at IS NULL" clauses)))
      (values (format nil "~{~A~^ AND ~}" (reverse clauses)) (reverse valeurs)))))

(defun reponses (c query)
  (multiple-value-bind (sql valeurs) (filtre-scientifique query)
    (lignes-json c (format nil "SELECT (to_jsonb(a) || jsonb_build_object('bank_version',p.bank_version,'levels',p.levels,
      'note',a.note::text,'initial_note',a.initial_note::text,
      'started_at',to_char(p.started_at AT TIME ZONE 'UTC','YYYY-MM-DD\"T\"HH24:MI:SS.MS\"Z\"'),
      'completed_at',to_char(p.completed_at AT TIME ZONE 'UTC','YYYY-MM-DD\"T\"HH24:MI:SS.MS\"Z\"')))::text
      FROM answers a JOIN participations p ON p.id=a.participation_id WHERE ~A ORDER BY p.started_at,a.production_id" sql) valeurs)))

(defun reponses-scientifiques (contexte secret query &optional production)
  (avec-science contexte secret (lambda (c admin) (declare (ignore admin))
    (tableau (if production (remove-if-not (lambda (r) (equal (champ r "production_id") production)) (reponses c query))
                 (reponses c query))))))

(defun export-scientifique (contexte secret query)
  (avec-science contexte secret (lambda (c admin) (declare (ignore admin)) (export-csv (reponses c query)))))

(defun entier-prefixe (v &optional (defaut 1))
  (or (ignore-errors (parse-integer (string-left-trim '(#\Space #\Tab #\Newline #\Return) v) :junk-allowed t)) defaut))

(defun participations-scientifiques (contexte secret query)
  (avec-science contexte secret
    (lambda (c admin) (declare (ignore admin))
      (multiple-value-bind (sql valeurs) (filtre-scientifique query)
        (let* ((page (max 1 (min 100000 (entier-prefixe (champ query "page" "1")))))
               (total (champ (un-json c (format nil "SELECT json_build_object('n',count(*))::text FROM participations p WHERE ~A" sql) valeurs) "n"))
               (rows (lignes-json c (format nil "SELECT row_to_json(t)::text FROM (SELECT p.id,p.bank_version,p.levels,
                to_char(p.started_at AT TIME ZONE 'UTC','YYYY-MM-DD\"T\"HH24:MI:SS.MS\"Z\"') AS started_at,
                to_char(p.updated_at AT TIME ZONE 'UTC','YYYY-MM-DD\"T\"HH24:MI:SS.MS\"Z\"') AS updated_at,
                to_char(p.completed_at AT TIME ZONE 'UTC','YYYY-MM-DD\"T\"HH24:MI:SS.MS\"Z\"') AS completed_at,
                (SELECT count(*) FROM answers a WHERE a.participation_id=p.id AND a.note IS NOT NULL)::int AS answers
                FROM participations p WHERE ~A ORDER BY p.started_at DESC LIMIT 30 OFFSET $~D::int) t" sql (1+ (length valeurs)))
                                   (append valeurs (list (parametre (* (1- page) 30)))))))
          (jobject "page" page "total" total "pages" (ceiling total 30) "rows" (tableau rows)))))))

(defun statistiques-scientifiques (contexte secret query)
  (avec-science contexte secret
    (lambda (c admin) (declare (ignore admin))
      (multiple-value-bind (sql valeurs) (filtre-scientifique query)
        (let* ((rows (reponses c query))
               (sessions (lignes-json c (format nil "SELECT row_to_json(t)::text FROM (SELECT p.id,p.levels,
                to_char(p.started_at AT TIME ZONE 'UTC','YYYY-MM-DD\"T\"HH24:MI:SS.MS\"Z\"') AS started_at,
                to_char(p.completed_at AT TIME ZONE 'UTC','YYYY-MM-DD\"T\"HH24:MI:SS.MS\"Z\"') AS completed_at
                FROM participations p WHERE ~A) t" sql) valeurs))
               (evaluees (remove-if (lambda (r) (absence-p (champ r "note"))) rows))
               (completees (count-if (lambda (p) (not (absence-p (champ p "completed_at")))) sessions))
               (productions nil) (jours nil) (niveaux nil))
          (dolist (r rows)
            (let ((id (concatenate 'string (champ r "bank_version") ":" (champ r "production_id"))))
              (unless (assoc id productions :test #'equal) (setf productions (append productions (list (cons id nil)))))
              (push r (cdr (assoc id productions :test #'equal)))))
          (dolist (p sessions)
            (let* ((date (subseq (champ p "started_at") 0 10)) (d (assoc date jours :test #'equal)))
              (unless d (setf d (cons date (jobject "date" date "started" 0 "completed" 0))) (push d jours))
              (incf (cdr (assoc "started" (json-object-entries (cdr d)) :test #'equal)))
              (unless (absence-p (champ p "completed_at")) (incf (cdr (assoc "completed" (json-object-entries (cdr d)) :test #'equal))))
              (dolist (niveau (json-array-items (champ p "levels")))
                (unless (assoc niveau niveaux :test #'equal) (setf niveaux (append niveaux (list (cons niveau 0)))))
                (incf (cdr (assoc niveau niveaux :test #'equal))))))
          (jobject "started" (length sessions) "answered" (length (remove-duplicates (mapcar (lambda (r) (champ r "participation_id")) evaluees) :test #'equal))
            "completed" completees "incomplete" (- (length sessions) completees)
            "completionRate" (if sessions (/ completees (float (length sessions) 1d0)) 0)
            "evaluations" (length evaluees) "daily" (tableau (mapcar #'cdr (sort jours #'string< :key #'car)))
            "levels" (vision::%make-json-object niveaux) "summary" (resumer-reponses rows)
            "productions" (vision::%make-json-object (mapcar (lambda (p) (cons (car p) (resumer-reponses (reverse (cdr p))))) productions))))))))
