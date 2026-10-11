(in-package #:matheval)

(declaim (inline entier-32))
(defun entier-32 (valeur) (logand valeur #xffffffff))

(defun generateur-32 (graine)
  "Mulberry32 du contrat JavaScript, résultat entier non signé avant division.
Le masquage reproduit Math.imul et les opérateurs bit à bit JS ; aucune RNG crypto."
  (unless (typep graine '(integer 0 4294967295))
    (error "Graine 32 bits invalide."))
  (let ((valeur graine))
    (lambda ()
      (setf valeur (entier-32 (+ valeur #x6d2b79f5)))
      (let ((calcul valeur))
        (setf calcul (entier-32 (* (logxor calcul (ash calcul -15))
                                 (logior calcul 1))))
        (setf calcul (entier-32
                      (logxor calcul
                        (+ calcul (entier-32
                                    (* (logxor calcul (ash calcul -7))
                                       (logior calcul 61)))))))
        (entier-32 (logxor calcul (ash calcul -14)))))))

(defun melanger (elements generateur)
  "Fisher-Yates sans mutation du corpus ; indice exact sans arrondi flottant."
  (let ((resultat (coerce elements 'vector)))
    (loop for i downfrom (1- (length resultat)) above 0
          for j = (floor (* (funcall generateur) (1+ i)) #x100000000)
          do (rotatef (aref resultat i) (aref resultat j)))
    (coerce resultat 'list)))

(defun preparer-session (corpus niveaux graine &optional vus)
  "Ordre stable à graine donnée, dédoublonnage familles, vingt questions maximum."
  (let* ((generateur (generateur-32 graine))
         (candidats (remove-if-not
                      (lambda (q) (member (champ q "level") niveaux :test #'equal))
                      (json-array-items (champ corpus "questions"))))
         (nouveaux (remove-if (lambda (q) (member (champ q "id") vus :test #'equal))
                              candidats))
         (familles (make-hash-table :test #'equal))
         (questions
           (remove-if
             (lambda (q)
               (let ((famille (champ q "family")))
                 (prog1 (gethash famille familles)
                   (setf (gethash famille familles) t))))
             (melanger (or nouveaux candidats) generateur))))
    (loop for q in questions for i below 20
          collect (vision::%make-json-object
                    (loop for (cle . valeur) in (json-object-entries q)
                          collect (cons cle (if (string= cle "productions")
                                               (tableau (melanger (json-array-items valeur) generateur))
                                               valeur)))))))
