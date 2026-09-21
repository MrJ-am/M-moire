# Portage ElmUI — lot de raccordement

Ce lot prépare la migration ; il ne l’achève pas et ne publie aucun site.

## Références

- Consignes de départ : `60ad0360c033b800f061679b86c4fccf96b91abc`.
- Atelier de référence : `55cf4cb45809fa9817aa9632c66edaa05547de46`, exécution `35616521685`, deuxième tentative réussie. La première a échoué sur un téléchargement `elm/random` en HTTP 504.
- Style compilé : **`52ad33f881b50feef91d60915d17bae90abfc592`**, jamais `main`.
- Identité autorisée : `MrJ-am/Signature`, `17495b13cefa24473e37434b98336b27caec8cdf`.

## Réalisé dans ce lot

L’atelier Linux temporaire et celui des tests reçoivent les sources communes. Le verrou `docs/style-mrjam.json` fixe la révision et les empreintes SHA-256 de tous les modules consommés et des ressources d’identité. Une source modifiée, supplémentaire, manquante ou remplacée par un lien symbolique est refusée. `STYLE_MRJAM_SOURCE` permet un atelier hors ligne, avec les mêmes vérifications ; ce n’est pas une autorisation de divergence locale.

Main, Survey et le nouveau point d’entrée Administration sont compilés en mode optimisé. Les sorties ne sont recopiées qu’après la réussite des trois compilations. La compilation reste indépendante du stockage partagé Android. Le contrôle Android physique demeure à effectuer ; le mécanisme de copie vers un système de fichiers Linux est conservé.

Les écrans d’accueil et de fin du questionnaire, l’en-tête du prototype et la connexion ordinaire de l’administration utilisent réellement les composants ElmUI de la bibliothèque. Le corps mathématique spécialisé reste un `rich-text` ; les contrôles ne sont pas des pages HTML anciennes enveloppées dans ElmUI. Les clés `username` et `password`, l’en-tête HTTP anti-CSRF, les cookies, les identifiants de niveau et les ports de collecte existants sont conservés.

La compilation installe des copies vérifiées de distribution du logo SVG et du manifeste, relativement aux deux bases `/matheval/` et `/matheval/admin/`. Elle ne copie ni composant maintenu localement ni police. Les références des ressources JavaScript des trois points d’entrée sont versionnées lors de la construction. `build:data` reste une construction éditoriale ; `predev` compile les points d’entrée avant de démarrer Vite, y compris depuis une installation neuve.

## Limites explicites

Le reste du prototype, DemoCard, l’espace d’évaluation de Survey, les lecteurs, la comparaison, les menus et les aides ne sont **pas encore portés**. L’activation du premier compte et les écrans administratifs après connexion (filtres, statistiques, corpus, participations) restent également à porter. Le CSS historique nécessaire à ces vues est conservé ; sa suppression avant leur migration casserait l’application.

Le noyau figé ne fournit pas encore les tableaux, les sélecteurs, les modales accessibles et les menus requis par ces vues. Leurs composants communs doivent évoluer dans `style-mrjam`, puis leur nouvelle révision doit être adoptée de manière coordonnée. Ne pas contourner le verrou par des variantes locales.

Aucun identifiant Elm ou JavaScript existant n’a été renommé dans ce lot. Le repère DOM de l’écran de fin a été adapté avec les tests qui l’utilisent, pour ne pas réappliquer son ancien style. Les nouveaux noms sont français ; les noms imposés et les protocoles historiques restent intacts. Toute francisation ultérieure reprend la procédure de compilation et de test symbole par symbole.

La signature est toujours le texte sélectionnable `MrJ.am`, avec le point U+002E. **La typographie exacte n’est pas intégrée ni validée.** Les ressources de police ne sont pas fournies dans ce lot. La feuille de composition est copiée pour traçabilité, mais n’est pas activée sans ses ressources autorisées. Le logo et la signature restent d’utilisation strictement réservée ; aucune licence générale ne leur est appliquée.

## Contrôles

- `npm --prefix docs run test:construction` : vérifie le verrou, les empreintes et les refus de divergence.
- `npm --prefix docs run test:logic` : tests Elm dans l’atelier partagé.
- `npm --prefix docs run build:main` : compile les trois points d’entrée, vérifie la source éditoriale et versionne les ressources.
- `npm --prefix docs run test:e2e` : conserve la suite réelle avec serveur et PostgreSQL isolé. Les nouveaux tests de présentation couvrent quatre largeurs, le clavier, les libellés, l’attente et l’erreur de connexion, le chargement du logo et la sélection de la signature. Le test de refus simule seulement cette réponse HTTP ; `collection-admin.spec.js` vérifie toujours les vraies sessions, les statistiques et la déconnexion.

Le navigateur de l’atelier ChatGPT interdit HTTP : les contrôles locaux en mémoire ne remplacent pas les tests HTTP de GitHub Actions. Les résultats doivent être lus sur l’exécution associée au commit, pas déduits de la CI de la bibliothèque.

Aucun fichier du corpus, des espaces initiaux, du schéma, des migrations ou de l’infrastructure n’est modifié. Aucun déploiement, accès VPS ou restauration de données n’est autorisé par le workflow de vérification de cette branche. Les artefacts restent des préparations à valider collectivement, pas des versions prêtes à activer.
