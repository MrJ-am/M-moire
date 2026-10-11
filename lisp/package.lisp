(defpackage #:matheval
  (:use #:cl)
  (:import-from #:vision #:jobject #:jarray #:json-object-get #:json-array-items
                #:json-object-entries #:json-object-p #:json-array-p
                #:parse-json #:json-encode #:%make-json-array)
  (:export #:generateur-32 #:melanger #:preparer-session #:resume #:distribution
           #:resumer-reponses #:export-csv #:valider-participation
           #:valider-sauvegarde #:valider-rattachements
           #:validation-error #:validation-status #:validation-message))

(in-package #:matheval)

(defun champ (objet nom &optional (defaut :null))
  (json-object-get objet nom defaut))

(defun tableau (elements) (%make-json-array elements))

(defun absence-p (valeur) (eq valeur :null))
