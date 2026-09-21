# Reprise : style MrJ.am

## État au 21 septembre 2026

Le questionnaire, le prototype, DemoCard et toute l’administration (activation comprise) sont portés en ElmUI. La version est publiée sur le VPS depuis 23:11 UTC. Le relevé de validation et de publication figure dans [PORTAGE-ELMUI.md](PORTAGE-ELMUI.md).

La bibliothèque commune est publiée sur `MrJ-am/style-mrjam`, à la révision exacte de `docs/style-mrjam.json`. Les ajouts de Matheval et de Vision sont intégrés ensemble ; les dates et tableaux utilisent les mêmes constructeurs. Le verrou conserve les empreintes de tous les modules. Les ressources sont locales à la publication.

## Contrat de style

Toutes les interfaces passent en ElmUI, administration comprise. Conserver et harmoniser l’identité existante. Utiliser les composants de la bibliothèque publique `MrJ-am/style-mrjam` à une révision Git exacte, fournie lors de la compilation. Pas de CSS partagé mutable chargé à distance ni de copie maintenue manuellement des composants.

L’appel courant est `bouton "Valider" Valider`, sans décoration ajoutée dans l’application. Les variantes portent une sémantique distincte ; la bibliothèque porte leurs styles. Les règles d’évaluation, les données et les autorisations restent dans Matheval. Tout composant commun manquant doit être ajouté à la bibliothèque, pas recréé localement ; sa nouvelle révision sera ensuite adoptée de façon coordonnée.

Tout nom contrôlé doit être français. Avant un renommage, conserver une compilation de référence ; changer un seul symbole et tous ses usages, compiler tous les points d’entrée consommateurs, tester les contrats externes concernés, puis passer au nom suivant. Ne pas remplacer aveuglément les clés JSON, les noms de ports, les identifiants persistants ou les données éditoriales.

## Périmètre et pièges identifiés

- Vues Elm : `docs/src/Main.elm`, `Survey.elm`, `Administration.elm` et `DemoCard.elm`. Les règles du questionnaire restent dans `Survey/Model.elm`.
- Présentation : `docs/site/enquete.css`, `sliders.css`, les vues HTML et JavaScript, et `docs/site/admin/admin.css` avec l’interface d’administration. Ne pas oublier cette dernière.
- `docs/scripts/build-elm.cjs` prépare les sources de la bibliothèque verrouillée dans un atelier Linux temporaire et compile les quatre points d’entrée avant de recopier un fichier. Préserver ce fonctionnement pour les environnements Android.
- Conserver les espaces initiaux des blocs `verse`, les contrastes expérimentaux, les données déjà collectées, les identifiants et le rendu KaTeX. Ne pas profiter de cette migration pour modifier le corpus.
- Les ponts spécialisés, l’espace de manipulation, les curseurs, l’aide sur demande, la comparaison et les lecteurs nécessitent des tests d’interaction. Envelopper l’ancien HTML dans `Element.html` ne termine pas le portage.

## Identité et publication

Le logo et la signature restent référencés dans `MrJ-am/Signature`, révision `17495b13cefa24473e37434b98336b27caec8cdf`. Toute utilisation est strictement réservée. La signature demeure le texte sélectionnable `MrJ.am` avec le point U+002E. La bibliothèque ne contient pas les fontes. Matheval conserve les fichiers autorisés dans `docs/identite`, vérifie leurs blobs Git et leurs SHA-256 contre la source Signature, puis les installe au moment de la construction. Les contrôles navigateur vérifient leur chargement et la sélection du texte.

Chaque adoption reconstruit et redéploie tous les projets concernés après validation de tous leurs artefacts. Ce raccordement n’est pas encore activé. Préparer et tester la migration sur sa branche ; ne pas déclencher isolément le déploiement collectif. Respecter `deploy/INFRASTRUCTURE.org` : aucun `nixos-rebuild`, changement PostgreSQL ou restauration de données depuis cette migration d’interface. La publication du noyau n’est ni une migration terminée ni un déploiement de Matheval.
