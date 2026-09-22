# Règles de travail de l'agent

<!-- coordination-commune:v1 -->
## Coordination commune

- Identifiant de ce projet : `memoire`. À chaque reprise (y compris après compaction), lire aussi le [AGENTS.md distant de référence](https://github.com/MrJ-am/M-moire/blob/master/AGENTS.md), même sur une ancienne branche.
- Avant de travailler, consulter dans le dépôt privé `MrJ-am/vps-infrastructure`, **branche `main` actuelle**, [coordination/CONTRATS.org](https://github.com/MrJ-am/vps-infrastructure/blob/main/coordination/CONTRATS.org) et [coordination/REGISTRE.org](https://github.com/MrJ-am/vps-infrastructure/blob/main/coordination/REGISTRE.org). Lire le protocole au début du registre à la première utilisation ; ensuite, charger la synthèse et les messages destinés à `memoire`. Ne pas charger les archives par défaut.
- Reconsulter avant toute modification d'un contrat partagé, avant publication et à la clôture. La commande `python3 scripts/coordination.py lire memoire`, dans une copie fraîche du dépôt VPS, produit la vue ciblée. Les outils GitHub permettent aussi cette lecture sans clone ni SSH.
- Publier les impacts globaux pour tous les projets ; pour un impact ciblé, nommer explicitement les destinataires et les actions. Informer avant le changement puis consigner le résultat avec commit et preuves. Une demande n'est pas un changement exécuté.
- Acquitter uniquement pour `memoire`, après lecture réelle, avec l'empreinte du message et le dépôt@commit du contexte. Distinguer LU, BLOQUE et DONE ; DONE exige une preuve. Suivre le protocole pour publier la réponse sur le main VPS sans écraser les autres écritures.
- Si le registre est inaccessible, le dire, poursuivre les tâches indépendantes et suspendre seulement les changements partagés dont les préconditions restent inconnues. Ne pas inventer d'accusé ni demander à l'utilisateur de transporter les messages entre projets.
- Les consignes locales continuent de s'appliquer. Le registre ne donne aucun droit supplémentaire de publication ou d'administration. Après les mises à jour, vérifier l'archivage des échanges intégralement traités ; ne jamais effacer un message non acquitté.

<!-- /coordination-commune:v1 -->

## Frontière entre Matheval et l'infrastructure VPS

- Lire `deploy/INFRASTRUCTURE.org` avant toute intervention sur le déploiement.
- Depuis ChatGPT Work, l'accès au VPS passe par GitHub Actions. Aucun accès
  SSH direct n'est disponible : ne pas retenter `deploy/connect.sh` depuis
  Work ni redemander une clé pour résoudre cette limitation réseau. Lire les
  exécutions identifiées par leur URL et leur commit ; les runners ouvrent les
  connexions SSH. Les diagnostics administratifs appartiennent au dépôt VPS.
- Le projet VPS, https://github.com/MrJ-am/vps-infrastructure (privé), est
  responsable de Nginx, des certificats ACME, des domaines, du pare-feu, du
  réseau, de SSH, de l'activation de NixOS et de PostgreSQL (instance, bases,
  rôles, règles d'accès et sauvegardes locales). Ne pas administrer ces
  éléments depuis le projet mémoire ni exécuter `nixos-rebuild` ici.
- Matheval conserve l'application, `deploy/matheval.nix`, son service et ses
  comptes Unix, les données, le schéma, les migrations, les publications et
  l'export chiffré `matheval-backup` avec son workflow Actions. Toute évolution
  du module NixOS doit être intégrée explicitement par le projet VPS.
- Le module applicatif ne déclare ni `services.postgresql` ni
  `services.postgresqlBackup`. Son client de sauvegarde suit
  `config.services.postgresql.package`. Le service attend `postgresql.service`
  et `postgresql-setup.service` avec `after` et `requires`.
- Le raccordement reste `127.0.0.1:3000`, préfixe `/matheval` conservé et origine
  `https://principiipetit.io` ; PostgreSQL utilise le socket `/run/postgresql`,
  la base, le rôle et le compte Unix `matheval`. Tout changement de ce contrat
  est coordonné avec le projet VPS avant déploiement.
- `deploy/hostinger/`, `deploy/legacy-nginx.nix` et
  `deploy/legacy-postgresql.nix` préservent la reconstructibilité de l'ancienne
  installation. Seule cette configuration importe les deux modules historiques ;
  la nouvelle infrastructure ne les importe jamais. Ne pas les étendre.
  La publication applicative n'a jamais à les copier sur le VPS.
- Ne jamais copier isolément le nouveau module sur l'ancienne installation.
  La bascule porte sur la configuration complète, coordonnée par le projet VPS.
  Celui-ci vérifie les restrictions HBA/SQL et leur retour arrière : un retour
  de génération NixOS ne restaure ni les données ni les ACL PostgreSQL.
- La séparation a été activée et enregistrée le 18 septembre 2026 à 21:10 UTC,
  avec les contrôles de l'exécution VPS `35395320446`. Les références installées
  et le point de retour sont dans `deploy/INFRASTRUCTURE.org`. Vérifier les
  dernières exécutions pour tout nouvel état ; préserver les accès et les données.

## Source éditoriale des questions et des contrats

- Modifier les questions, les textes et les tableaux de codage dans `research/questions.org`, et les définitions dans `research/contrats.org`.
- Ne pas éditer les JSON générés ni les blocs Org `generated`. Lancer `npm --prefix docs run build:data`, puis `npm --prefix docs run check:data` et `npm --prefix docs run test:data` après une modification du corpus ou du compilateur.
- Conserver les espaces initiaux des blocs `verse` : ils portent les variantes d’indentation. Les paires `INDENTATION_DE` ne doivent différer que par ces espaces.
- Les tests navigateur restent requis pour les changements des données ou de leur affichage, comme indiqué dans `docs/tests/e2e/README.org`.

## Validation adaptée aux changements

- Compiler localement les applications Elm uniquement lorsque les changements affectent les sources Elm, les dépendances ou la configuration Elm, ou les commandes de compilation. Utiliser `npm --prefix docs run build:main` (`docs/src/Main.elm` vers `docs/site/main.js` et `docs/src/Survey.elm` vers `docs/site/survey.js`).
- Pour les seuls changements de bibliographie, de PDF, de manifeste, de documentation ou de consignes (`AGENTS.md`), ne pas lancer de compilation Elm. Vérifier les fichiers concernés : cohérence du manifeste, noms et tailles des fichiers, liens et format, selon la modification.
- Pour les changements de données, de HTML, de CSS ou de JavaScript, effectuer les validations et la copie des ressources de publication nécessaires, sans recompiler Elm si ses sources, ses dépendances et sa configuration restent inchangées.
- Une compilation peut aussi être lancée sur demande explicite de l'utilisateur ou pour vérifier l'installation du compilateur.

## Compilation sur le téléphone Android

Elm 0.19.1 est installé globalement via le paquet communautaire `@lydell/elm`, compatible Linux ARM64. Le stockage partagé (`/sdcard` ou `/storage/emulated/0`) ne prend pas en charge le verrouillage utilisé par Elm. Lorsqu’une compilation est nécessaire, copier `docs/elm.json` et `docs/src/` dans un répertoire temporaire Linux, puis compiler depuis ce répertoire avec `ELM_HOME=/tmp/memoire-elm-cache`. Ne pas recopier le dossier `elm-stuff` du téléphone. Après une compilation réussie, recopier les JavaScript produits vers `docs/site/main.js` et `docs/site/survey.js` si les fichiers publiés doivent être actualisés. Pour un simple contrôle de l’installation, conserver la sortie dans le répertoire temporaire.

## Commit et synchronisation

Après les validations pertinentes pour les changements :

1. Faire un commit Git avec un message en français, descriptif et concis.
2. Pousser les changements sur le dépôt distant (`origin`) et la branche courante.

En cas d'échec d'une validation requise, du commit ou du push, l'indiquer explicitement dans la réponse. Une compilation non nécessaire ne constitue pas une validation manquante et ne doit pas bloquer la synchronisation.

## Style MrJ.am et francisation

- Lire `docs/STYLE-MRJAM.md` avant de modifier les interfaces. Le passage de toutes les interfaces, administration comprise, à ElmUI est décidé ; la préparation n’est pas encore une migration publiée.
- Consommer la bibliothèque `MrJ-am/style-mrjam` à une révision Git exacte lors de la compilation. Appeler les composants usuels simplement, par exemple `bouton "Valider" Valider`, sans répéter leurs réglages décoratifs. Les variantes portent une intention distincte.
- Franciser tout nom contrôlé et garder le code lisible et compact. Pour les noms existants, compiler la référence, renommer un seul symbole avec ses usages, recompiler tous les points d’entrée consommateurs et vérifier les contrats non typés avant de passer au symbole suivant.
- Préserver les noms imposés, identifiants persistants, ports et clés échangées tant que leur éventuelle migration compatible n’est pas définie. Ne pas faire de remplacement aveugle dans les données.
- L’atelier de compilation temporaire devra aussi recevoir la bibliothèque commune à sa révision vérifiée ; ne pas ajouter un chemin dans `elm.json` sans adapter cette copie. Conserver Main et Survey et la compatibilité Android.
- Le logo et la signature sont d’utilisation strictement réservée ; `MrJ-am/Signature` reste la source à version précise. Préserver le texte sélectionnable `MrJ.am`.
- Une nouvelle version du style reconstruit et redéploie tous les projets concernés après validation collective, sans changement implicite de données ni de configuration système. Ne pas confondre compilation, validation fonctionnelle et publication effective.
