(in-package #:matheval)

(defun nombre (valeur)
  (if (numberp valeur) valeur
      ;; Notes numeric PostgreSQL : parse JSON n'évalue jamais du code Lisp.
      (let ((n (parse-json valeur)))
        (unless (numberp n) (error "Nombre attendu.")) n)))

(defun resume (valeurs)
  (let* ((tries (coerce (sort (mapcar #'nombre (remove :null valeurs)) #'<) 'vector))
         (n (length tries)))
    (labels ((quantile (p)
               (let* ((x (* (1- n) p)) (i (floor x)))
                 (+ (aref tries i) (* (- x i)
                                      (- (aref tries (min (1+ i) (1- n)))
                                         (aref tries i)))))))
      (jobject "n" n "mean" (if (plusp n) (coerce (/ (reduce #'+ tries) n) 'double-float) :null)
               "median" (if (plusp n) (coerce (quantile 1/2) 'double-float) :null)
               "q1" (if (plusp n) (coerce (quantile 1/4) 'double-float) :null)
               "q3" (if (plusp n) (coerce (quantile 3/4) 'double-float) :null)))))

(defun distribution (valeurs &optional (pas 1/4) (minimum 0) (maximum 3))
  (let* ((n (1+ (floor (+ 1/2 (/ (- maximum minimum) pas)))))
         (comptes (make-array n :initial-element 0)))
    (dolist (valeur valeurs)
      ;; Math.round JS arrondit les demi-entiers vers +inf, pas round de Lisp.
      (incf (aref comptes (max 0 (min (1- n)
                                      (floor (+ 1/2 (/ (- (nombre valeur) minimum) pas))))))))
    (tableau (loop for i below n collect
               (jobject "value" (coerce (+ minimum (* i pas)) 'double-float)
                        "count" (aref comptes i))))))

(defun completer (objet &rest paires)
  (vision::%make-json-object (append (json-object-entries objet)
    (loop for (cle valeur) on paires by #'cddr collect (cons cle valeur)))))

(defun resumer-reponses (lignes)
  (let* ((notes (loop for r in lignes unless (absence-p (champ r "note")) collect (nombre (champ r "note"))))
         (ecarts (loop for r in lignes
                       unless (or (absence-p (champ r "note")) (absence-p (champ r "initial_note")))
                       collect (- (nombre (champ r "note")) (nombre (champ r "initial_note"))))))
    (jobject "grades" (completer (resume notes) "distribution" (distribution notes))
             "initialGrades" (resume (mapcar (lambda (r) (champ r "initial_note")) lignes))
             "revisions" (completer (resume ecarts) "changed" (count-if-not #'zerop ecarts))
             "axes" (vision::%make-json-object
                       (loop for axe in '("x" "y" "z")
                             for valeurs = (loop for r in lignes
                                               when (member axe (json-array-items (champ r "evaluated_axes")) :test #'equal)
                                               collect (nombre (champ r axe)))
                             collect (cons axe (completer (resume valeurs)
                                               "distribution" (distribution valeurs 2 -10 10))))))))

(defun cellule-csv (valeur)
  (let ((texte (cond ((or (null valeur) (absence-p valeur)) "")
                     ((numberp valeur) (mrjam-native:json-js valeur))
                     (t (princ-to-string valeur)))))
    (with-output-to-string (s)
      (write-char #\" s)
      (when (and (plusp (length texte)) (find (char texte 0) '(#\= #\+ #\@ #\Tab #\Return)))
        (write-char #\' s))
      (loop for c across texte do (write-char c s) (when (char= c #\") (write-char c s)))
      (write-char #\" s))))

(defun export-csv (lignes)
  (let ((colonnes '("participation" "version" "debut" "validation" "niveaux" "question" "redaction"
                    "note_initiale" "note" "lisibilite" "precision" "validite" "axes_evalues")))
    (with-output-to-string (s)
      (write-char (code-char #xfeff) s)
      (labels ((ligne (valeurs)
                 (format s "~{~A~^;~}" (mapcar #'cellule-csv valeurs)))
               (joindre (elements separateur)
                 (format nil "~{~A~}" (loop for x in elements for premier = t then nil
                                            append (if premier (list x) (list separateur x))))))
        (ligne colonnes)
        (dolist (r lignes)
          (format s "~C~C" #\Return #\Linefeed)
          (ligne (append (loop for k in '("participation_id" "bank_version" "started_at" "completed_at") collect (champ r k))
                         (list (joindre (json-array-items (champ r "levels")) " | "))
                         (loop for k in '("question_id" "production_id" "initial_note" "note") collect (champ r k))
                         (loop for axe in '("x" "y" "z") collect
                               (if (member axe (json-array-items (champ r "evaluated_axes")) :test #'equal) (champ r axe) :null))
                         (list (joindre (json-array-items (champ r "evaluated_axes")) "|")))))))))
