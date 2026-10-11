# Intégration du socle commun

Les règles actives sont le [contrat frontend central](https://github.com/MrJ-am/vps-infrastructure/blob/main/assemblage/FRONTENDS.md),
les [commandes locales](https://github.com/MrJ-am/vps-infrastructure/blob/main/assemblage/DEVELOPPEMENT.md) et le
[manifeste d’assemblage](https://github.com/MrJ-am/vps-infrastructure/blob/main/assemblage/manifest.json). Les décisions et preuves
antérieures restent dans `coordination/historique/` ; elles ne qualifient pas
l’amendement du 11 octobre 2026.

Présentation en elm-ui, transitions avec elm-animator dans le socle style-mrjam.
Les applications expriment état métier et intentions puis composent ce socle.
Pas de présentation Html/Html.Styled/elm-css, CSS applicatif, styles inline, HTML
injecté ni moteur d’animation local. Bootstrap minimal et adaptateurs techniques
étroits seulement : périmètre nommé, justification de la capacité manquante,
contrôle et tests. Element.html/htmlAttribute sont réservés à ces adaptateurs.
Les références de type nécessaires au navigateur restent autorisées.

elm-review central bloque la qualification des sources assemblées, y compris le
style à sa révision verrouillée. Les règles résolvent les symboles (alias/exposing),
vérifient frontières et échappatoires ; tests positifs/négatifs et fixture rejetée.
Aucun contournement par exclusions générales ou suppressions régénérées.

À qualifier sur le candidat exact : interruptions/inversions rapides, état/focus/clavier,
reduced-motion et arrêt du rafraîchissement inutile. Une action métier n’attend
pas une décoration. Préserver fonctionnalités, accessibilité et identité visuelle.
Une analyse statique ne prouve pas ces parcours navigateur.

Sources de style à révision Git exacte, récupérées pour la construction sans
copie divergente entretenue dans l’application ; artefact complet/empreintes.
Composants publiés avant manifeste. CI/CD uniquement dans l’infrastructure,
réservée à la promotion du candidat qualifié et à ses sondes/préconditions ;
aucune campagne de développement distante, aucun workflow composant ou acquittement.

Matheval conserve Main, Survey, prototype et administration, le parcours,
clavier/tactile, dimensions et ressources. Le rendu scientifique, la lecture/note et la projection/interaction3D passent
par Mathematiques, Lectures, Curseurs, Espace et AxesSpatiaux communs. Seuls
leurs adaptateurs privés étroits et contrôlés raccordent KaTeX/SVG/pointeurs.
Les références géométriques historiques restent dans tests/references, hors site.
Les quatre entrées restent construites centralement selon l’impact. Préserver
zéro/absence, dates, pseudonymat, secret de reprise et participations ouvertes.
Lire tests/e2e/README.org. Aucune refonte graphique gratuite.
