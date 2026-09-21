# Reprise : style MrJ.am

## État au 21 septembre 2026

La préparation est sur `migration/style-mrjam`. Le contrôle de référence `35605792689` a réussi : validation de 20 questions, 88 productions et 638 formules, 10 tests Python, 12 tests Elm et compilation de Main et Survey. Les échecs des premiers ateliers provenaient de leur préparation ; ils n’ont modifié aucune source applicative. La production est inchangée et le portage des interfaces n’est pas encore réalisé. Le noyau de style est préparé séparément ; `MrJ-am/style-mrjam` reste à créer et à publier.

## Contrat de style

Toutes les interfaces passent en ElmUI, administration comprise. Conserver et harmoniser l’identité existante. Utiliser les composants de la bibliothèque publique `MrJ-am/style-mrjam` à une révision Git exacte, fournie lors de la compilation. Pas de CSS partagé mutable chargé à distance ni de copie maintenue manuellement des composants.

L’appel courant est `bouton "Valider" Valider`, sans décoration ajoutée dans l’application. Les variantes portent une sémantique distincte ; la bibliothèque porte leurs styles. Les règles d’évaluation, les données et les autorisations restent dans Matheval.

Tout nom contrôlé doit être français. Avant un renommage, conserver une compilation de référence ; changer un seul symbole et tous ses usages, compiler tous les points d’entrée consommateurs, tester les contrats externes concernés, puis passer au nom suivant. Ne pas remplacer aveuglément les clés JSON, les noms de ports, les identifiants persistants ou les données éditoriales.

## Périmètre et pièges identifiés

- Vues Elm : `docs/src/Main.elm`, `Survey.elm`, `DemoCard.elm` et `Survey/Model.elm`.
- Présentation : `docs/site/enquete.css`, `sliders.css`, les vues HTML et JavaScript, et `docs/site/admin/admin.css` avec l’interface d’administration. Ne pas oublier cette dernière.
- Le script `docs/scripts/build-elm.cjs` copie actuellement seulement `elm.json` et `src` dans un atelier temporaire. Ajouter une dépendance source sans adapter cette copie casse la construction. Préserver la compilation sur stockage Android et compiler Main ET Survey.
- Conserver les espaces initiaux des blocs `verse`, les contrastes expérimentaux, les données déjà collectées, les identifiants et le rendu KaTeX. Ne pas profiter de cette migration pour modifier le corpus.
- Les ponts spécialisés, l’espace de manipulation, les curseurs, l’aide sur demande, la comparaison et les lecteurs nécessitent des tests d’interaction. Envelopper l’ancien HTML dans `Element.html` ne termine pas le portage.

## Identité et publication

Le logo et la signature restent référencés dans `MrJ-am/Signature`, révision `17495b13cefa24473e37434b98336b27caec8cdf`. Toute utilisation est strictement réservée. La signature demeure le texte sélectionnable `MrJ.am` avec le point U+002E.

Chaque adoption reconstruit et redéploie tous les projets concernés après validation de tous leurs artefacts. Ce raccordement n’est pas encore activé. Respecter `deploy/INFRASTRUCTURE.org` : aucun `nixos-rebuild`, changement PostgreSQL ou restauration de données depuis cette migration d’interface. La préparation n’est ni une migration terminée ni un déploiement.
