# Portage ElmUI — lot de raccordement

Ce lot prépare la migration ; **le portage de toutes les interfaces n’est pas terminé**. Il ne publie aucun site.

## Références

- Consignes de départ : `60ad0360c033b800f061679b86c4fccf96b91abc`.
- Atelier de référence : `55cf4cb45809fa9817aa9632c66edaa05547de46`, exécution `35616521685`, deuxième tentative réussie. La première a échoué sur un téléchargement `elm/random` en HTTP 504.
- Style compilé : **`52ad33f881b50feef91d60915d17bae90abfc592`**, jamais `main`.
- Identité autorisée : `MrJ-am/Signature`, `17495b13cefa24473e37434b98336b27caec8cdf`.
- Sources du lot enregistrées : `ef24a4d8f1fc1346d3c5a6c30ed02c25c9504609`, après réussite de l’exécution applicative `35621663805`.

## Réalisé

L’atelier Linux temporaire et celui des tests reçoivent les sources communes. Le verrou `docs/style-mrjam.json` fixe la révision et les empreintes SHA-256 de tous les modules consommés et des ressources d’identité. Une source modifiée, supplémentaire, manquante ou remplacée par un lien symbolique est refusée. `STYLE_MRJAM_SOURCE` permet un atelier hors ligne, avec les mêmes vérifications ; ce n’est pas une autorisation de divergence locale.

Main, Survey et le nouveau point d’entrée Administration sont compilés en mode optimisé. Les sorties ne sont recopiées qu’après la réussite des trois compilations. La compilation reste indépendante du stockage partagé Android. Le contrôle Android physique demeure à effectuer ; le mécanisme de copie vers un système de fichiers Linux est conservé.

Les écrans d’accueil et de fin du questionnaire, l’en-tête du prototype et la connexion ordinaire de l’administration utilisent réellement les composants ElmUI de la bibliothèque. Le corps mathématique spécialisé reste un `rich-text` ; les contrôles ne sont pas des pages HTML anciennes enveloppées dans ElmUI. Les clés `username` et `password`, l’en-tête HTTP anti-CSRF, les cookies, les identifiants de niveau et les ports de collecte existants sont conservés.

La compilation installe des copies vérifiées de distribution du logo SVG et du manifeste, relativement aux deux bases `/matheval/` et `/matheval/admin/`. Elle ne copie ni composant maintenu localement ni police. Les références des ressources JavaScript des trois points d’entrée sont versionnées lors de la construction. `build:data` reste une construction éditoriale ; `predev` compile les points d’entrée avant de démarrer Vite. `test:all` reconstruit également les programmes avant les tests navigateur, afin de ne pas tester des JavaScript périmés.

## Composants communs supplémentaires

La branche **`migration/composants-matheval`** de `MrJ-am/style-mrjam` contient le commit **`a160ec11ba36787913e08a996d7cf2388f3b5bef`**. Il ajoute `identifiant`, `nouveauMotDePasse` et le module `MrJam.Tableaux` (`tableau`, `colonne`), avec leurs exemples et tests clavier, saisie, état vide, zéro et défilement local à petit écran. Son exécution **`35620939414`** a réussi : formatage, empreintes d’identité, compilation optimisée et navigateur HTTP aux largeurs 320, 390, 768 et 1440 pixels.

Ces ajouts sont préparés dans la bibliothèque, **pas consommés par Mémoire**, qui reste strictement verrouillé sur `52ad33f`. Leur adoption requiert une nouvelle révision complète approuvée, puis les tests de chaque application. Ni la branche mobile des ajouts ni une copie locale divergente ne doit remplacer le noyau imposé. Les sélecteurs, menus et modales accessibles restent à préparer dans la bibliothèque.

## Limites explicites

Le reste du prototype, DemoCard, l’espace d’évaluation de Survey, les lecteurs, la comparaison, les menus et les aides ne sont **pas encore portés**. L’activation du premier compte et les écrans administratifs après connexion (filtres, statistiques, corpus, participations) restent également à porter. Le CSS historique nécessaire à ces vues est conservé ; sa suppression avant leur migration casserait l’application. Le portage devra aussi revoir la structure des régions de page, et ne pas empiler les gabarits complets de la bibliothèque dans les anciens conteneurs.

Aucun identifiant Elm ou JavaScript existant n’a été renommé dans ce lot. Le repère DOM de l’écran de fin a été adapté avec les tests qui l’utilisent, pour ne pas réappliquer son ancien style. Les nouveaux noms sont français ; les noms imposés et les protocoles historiques restent intacts. Toute francisation ultérieure reprend la procédure de compilation et de test symbole par symbole.

La signature est toujours le texte sélectionnable `MrJ.am`, avec le point U+002E. **La typographie exacte n’est pas intégrée ni validée.** Les ressources de police ne sont pas fournies dans ce lot. La feuille de composition est copiée pour traçabilité, mais n’est pas activée sans ses ressources autorisées. Le logo et la signature restent d’utilisation strictement réservée ; aucune licence générale ne leur est appliquée.

## Validation applicative

L’exécution **`35621663805`** a validé les sources ensuite enregistrées dans `ef24a4d8f1fc1346d3c5a6c30ed02c25c9504609`. Les exécutions ultérieures du workflow vérifient directement les sources enregistrées, sans recette de transformation ni écriture Git. Le mécanisme temporaire d’intégration a été supprimé ; le workflow final ne dispose que de `contents: read`.

Les contrôles comprennent le corpus et le site publié, les règles du questionnaire, 7 tests du verrou de construction, 12 tests Elm, 14 tests serveur sur PostgreSQL isolé et 44 tests navigateur Firefox, Chromium et Chromium tactile. Les tests navigateur conservent la vraie collecte, les cookies, la connexion, les statistiques, la déconnexion, les gestes, les coordonnées, les notes nulles et la préservation des espaces initiaux. Les nouveaux contrôles de présentation vérifient le clic, le clavier, les libellés, l’attente et le refus de connexion, quatre largeurs, le chargement du logo et la sélection de la signature. Le refus de connexion est simulé dans ce seul test de présentation ; le parcours administratif réel reste testé séparément.

Deux régressions révélées par les premiers essais HTTP ont été corrigées : l’en-tête ElmUI pouvait recouvrir le plateau, et une aide contextuelle pouvait intercepter la validation finale. L’espacement et la géométrie du plateau ont été rétablis, et l’aide est fermée en entrant dans l’écran final. Les assertions de sélection attendent maintenant le rendu ElmUI : le clic est réel et l’état coché est toujours contrôlé, sans clic forcé ni suppression d’assertion.

Les artefacts `javascript-portage-mrjam` contiennent les trois JavaScript compilés, le verrou du style, le commit vérifié et leurs empreintes. Ils ne contiennent aucune police et ne constituent pas une distribution complète prête à déployer. Les captures et résultats navigateur sont conservés séparément dans `controles-portage-mrjam`, avec un rapport JUnit pour les exécutions du workflow final.

Le navigateur de l’atelier ChatGPT interdit HTTP : les contrôles locaux en mémoire ne remplacent pas les tests HTTP de GitHub Actions. Aucune réussite de la bibliothèque n’est utilisée comme preuve de réussite de Mémoire.

Aucun fichier du corpus, des espaces initiaux, du schéma, des migrations ou de l’infrastructure n’est modifié. Aucun déploiement, accès VPS ou restauration de données de production n’est réalisé. Les artefacts restent des préparations à valider collectivement, pas des versions prêtes à activer.
