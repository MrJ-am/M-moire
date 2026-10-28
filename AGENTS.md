# Mémoire — documents et reproductibilité scientifique

Ce dépôt est le dépôt du mémoire. Le développement applicatif est dans
https://github.com/MrJ-am/matheval ; l’assemblage serveur est dans
https://github.com/MrJ-am/mrjam-plateforme. Motion est un autre projet.

- Lire README.org. Les anciennes consignes d’exploitation conservées dans
  les archives ou documents historiques ne réactivent aucun serveur ni workflow.
- Préserver les manuscrits, bibliographies, rendus, archives, sources et données
  scientifiques lors d’un nettoyage technique. Ne pas ouvrir ces contenus pour
  réaliser une simple migration de code ; ne pas réécrire un corpus pour faire
  passer les tests de l’application.
- docs/ est l’instrument figé de l’édition scientifique, conservé pour la
  reproductibilité. Il ne doit pas servir au développement de la nouvelle
  application ni à la création de l’environnement VPS. Les modifications
  scientifiques explicites suivent les instructions de l’auteur.
- Les outils scientifiques relient encore research/, les artefacts JSON,
  les pages et leurs ressources. Ne pas supprimer un fichier en déduisant
  de son extension qu’il est inutile au mémoire. Documenter toute séparation
  future de cet outillage avant de la réaliser.
- Les backends historiques et leurs lanceurs ne sont plus à installer ici.
  Les commandes conservées de construction/test ne lancent aucun serveur
  Node ou Lisp. Le proxy local du navigateur vise le monolithe Rust ; son
  branchement SQL, l’administration et les parcours complets restent à qualifier.
- Aucun accès à une base réelle, réponse réelle, sauvegarde ou journal de
  production pour qualifier un changement technique. Les tests de navigateur
  exigent un harnais local entièrement synthétique. Ne jamais journaliser les
  réponses, identités, secrets ou diagnostics SQL.
- Les scripts historiques de génération peuvent lire les documents et les PDF
  référencés, puis écrire des blocs scientifiques. Ne pas les lancer comme
  effet secondaire de l’installation d’un environnement serveur.
- Les artefacts applicatifs publics sont publiés explicitement dans Mateval
  avec version, provenance et empreintes. Aucun checkout du mémoire ne doit
  devenir une dépendance de compilation ou d’exécution du serveur.
- Les déploiements restent gelés. Aucun workflow, SSH, migration SQL, import
  de corpus ou bascule de service ne découle de la publication de ce nettoyage.
