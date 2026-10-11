(asdf:defsystem "matheval"
  :description "Collecte scientifique Matheval : bibliothèque sans démarrage implicite."
  :version "1.0.0"
  :depends-on ("vision/json" "mrjam-native")
  :serial t
  :components ((:file "lisp/package")
               (:file "lisp/tirages")
               (:file "lisp/statistiques")
               (:file "lisp/validation")
               (:file "lisp/collecte")
               (:file "lisp/administration")))

(asdf:defsystem "matheval/tests"
  :depends-on ("matheval")
  :serial t
  :components ((:file "lisp/tests/pures")))
