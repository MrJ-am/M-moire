# Composant Matheval

L’assemblage, les commandes locales et toute la CI/CD appartiennent à
[MrJ-am/vps-infrastructure](https://github.com/MrJ-am/vps-infrastructure).
Lire le [contrat central](https://github.com/MrJ-am/vps-infrastructure/blob/main/coordination/CONTRATS.org),
le [manifeste](https://github.com/MrJ-am/vps-infrastructure/blob/main/assemblage/manifest.json)
et les [commandes de développement](https://github.com/MrJ-am/vps-infrastructure/blob/main/assemblage/DEVELOPPEMENT.md).
Interfaces Elm : elm-ui pour la présentation et elm-animator pour les transitions,
mutualisés dans style-mrjam. Pas de Html/Html.Styled/elm-css, CSS/HTML applicatif ou
animation ad hoc. Adaptateurs techniques étroits, documentés/testés ; Element.html
et htmlAttribute bornés. elm-review central obligatoire, sans suppressions/exclusions
générales ; tests des règles et parcours Continuous UI (interruptions/inversions,
focus/clavier/reduced-motion, rafraîchissement arrêté). Lire le
[contrat frontend](https://github.com/MrJ-am/vps-infrastructure/blob/main/assemblage/FRONTENDS.md).

Ce dépôt conserve ses sources, contrats et tests ; publier son commit avant
référencement central. Aucun workflow satellite, publication autonome, échange
obligatoire entre conversations ou acquittement. L’intégration centrale et les
tests pertinents valident un changement.

Préserver les modifications concurrentes, les données et les secrets. Commits
français, push sans force ; aucune PR ni modification de visibilité ou licence.
Une compilation ou un test local ne prouve pas une publication : citer les
révisions et les contrôles de la version réellement servie. Les anciennes règles
sont conservées dans `coordination/historique/AGENTS-avant-composants-20261011.md`.

Le métier Matheval est la bibliothèque ASDF `matheval`, assemblée dans le serveur
SBCL commun. `server/` est la référence historique différentielle, réservée aux
bases de test indépendantes ; aucun backend Node cible. Le chargement Lisp
n’ouvre ni connexion, transport, tâche ni migration. L’infrastructure possède
cycle de vie, PostgreSQL, rôles, sauvegardes, Nginx et déploiement. Le port 3000,
le processus et le compte Unix historiques ne sont pas des contrats cibles.
Les anciens modules `deploy/` restent des sources de retour identifiables.

Préserver le préfixe `/matheval`, l’origine `https://principiipetit.io`, HTTP/JSON,
identifiants, transactions, conflits de révision, idempotence, dates et données
scientifiques. Vérifier graines, tirages, arithmétique 32 bits et empreintes JSON ;
distinguer zéro, réponse absente et null. Garder les participations ouvertes,
leur pseudonymat et leur secret de reprise indépendants d’un compte Log.
Les droits scientifiques de résultats n’accordent aucun accès général à Vision.

Questions/textes/codage : sources `research/questions.org` et `research/contrats.org`.
Ne pas éditer les JSON ou blocs Org générés. Utiliser les commandes centrales
qui appellent construction, contrôle et tests de données après impact. Conserver
les espaces initiaux des blocs verse et la distinction `INDENTATION_DE`.

Elm/ElmUI et l’interopérabilité JavaScript restent en place. Lire
`docs/STYLE-MRJAM.md` et `docs/tests/e2e/README.org` pour une modification
concernée. Compiler Elm seulement si sources, dépendances ou configuration
l’exigent ; documentation seule : vérifications éditoriales. Les ateliers
isolés utilisent les versions verrouillées centralement ; aucune publication
Pages ou installation d’outil depuis ce composant. Les anciennes notes Android
restent dans l’archive et ne contraignent pas l’environnement Codex.

Réutiliser le style à sa révision exacte, conserver Main/Survey, la compacité,
le tactile, le clavier et le texte sélectionnable `MrJ.am`. Écrire en français
les noms sous notre contrôle ; garder les identifiants et contrats externes.
La seule synchronisation autorisée est Git, sans copie vendor divergente.

Développement Lisp : architecture C actuelle, métier/cl-mcp sans pool/Swank dans
l’image de tâche ; Tron séparé via le pont central. CL-MCP pour le travail ordinaire,
Tron dès l’appel devant conserver le contexte. Commandes locales/fallback Tron
hors travail métier ; cibles et comportements testés distingués dans le guide
central référencé ci-dessus. Après reconnexion, vérifier PID/marqueur/état partagé
et invalider anciennes références. Édition structurelle facultative ; sources
canoniques avant compilation. Pendant une suspension, réparation seulement,
pile DEBUG/thread/niveau et restart choisi par sens/position actuelle, effets
vérifiés ; timeout sans preuve d’annulation. Validation propre distincte permise,
image saine préservée. Qualifier synthétique jamais utilisé comme sonde de santé.
Outils hors production/public, MCP métier distinct ; aucun serveur/débogueur
réécrit, fusion ou cl-harness. Aucun appel MCP artificiel pour les autres formats.
