# Portage ElmUI publié le 21 septembre 2026

Matheval est actif depuis **23:11 UTC** sur
[principiipetit.io/matheval](https://principiipetit.io/matheval/), avec son
[administration](https://principiipetit.io/matheval/admin/).

## Références attestées

| Élément | Référence |
|---|---|
| Application installée | `9ad544dfc7ce546a851e01b6c8f9a2a8334ca616` |
| Bibliothèque commune | `553e5a85fc28d09ab2d034401c6cb912ef97320d` |
| Source de Signature | `17495b13cefa24473e37434b98336b27caec8cdf` |
| Validation du portage | [35665937903](https://github.com/MrJ-am/M-moire/actions/runs/35665937903) |
| Construction et publication | [35665981516](https://github.com/MrJ-am/M-moire/actions/runs/35665981516) |
| Validation de la bibliothèque | [35664284639](https://github.com/MrJ-am/style-mrjam/actions/runs/35664284639) |
| Artefact de publication | `matheval-release`, ID `10668998334` |
| SHA-256 du ZIP GitHub | `0d82ddacffd1096a66491814bac8660f7a12d0dbb1f26f3563fea7838e06968e` |

Le job `deploy` a confirmé la version active à 23:11:17 UTC. À 23:11:28,
**104 fichiers servis en HTTPS** étaient identiques aux fichiers testés,
polices et manifestes compris. Le contrôle suivant a confirmé le service
actif et les réponses **401** des accès anonymes à `admin/me` et
`admin/statistics`. Le manifeste public `interface.json` associe les trois
révisions exactes de l’application, du style et de Signature.

## Périmètre et validations

Le questionnaire, le prototype, DemoCard et toute l’administration
(connexion, activation, statistiques, corpus, réponses, événements, filtres,
pagination et export) utilisent ElmUI et les composants partagés. Le
JavaScript administratif transporte les requêtes ; les vues restent en Elm.
Les textes mathématiques, les gestes, la projection 3D et la lecture animée
conservent leurs ponts spécialisés.

Les deux exécutions applicatives finales ont réussi : **50 parcours navigateur**
(Firefox, Chromium et tactile émulé), **12 tests Elm**, **14 tests API**,
**7 tests de construction**, **10 tests du corpus** et **3 tests du contrôle
de publication**. Les quatre points d’entrée compilent en mode optimisé.
Les parcours couvrent notamment la reprise réseau, la collecte réelle en base
jetable, l’administration, les valeurs nulles et zéro, les gestes, les petits
écrans, les portées mathématiques, l’activation et le focus des dialogues.
Les captures ont été examinées. Un téléphone physique reste un contexte de
vérification distinct de l’émulation tactile.

Le corpus est inchangé : **20 questions, 88 productions, 638 formules**.
Aucune source du serveur, du corpus ou du module VPS n’a changé par rapport
à la version précédente `0c2758f5a1df6821903a684e9a3c41f600acf02c`.
Les contrats HTTP/JSON, les cookies, les identifiants, les retraits des blocs
`verse` et le stockage PostgreSQL sont conservés.

## Construction, identité et retour

`docs/style-mrjam.json` verrouille la révision et les empreintes de tous les
modules communs. La bibliothèque réunit les ajouts de Vision et de Matheval ;
les dates et tableaux partagent leurs constructeurs. La construction utilise
un atelier Linux temporaire et ne recopie les sorties qu’après compilation
de Main, Survey, Administration et DemoCard.

Les polices de `docs/identite` sont les blobs exacts de Signature : leurs
empreintes Git et SHA-256 sont vérifiées à chaque construction. La signature
reste le texte sélectionnable `MrJ.am`. Les droits du logo et de la signature
restent strictement réservés. Les JavaScript générés et les copies d’identité
ne sont pas maintenus manuellement dans Git.

La publication utilise l’archive issue des tests, le compte `matheval-deploy`
et l’environnement `matheval-production`. Elle conserve les versions dans
`/srv/matheval/releases`, relève l’ancienne cible de `current`, puis active la
nouvelle. Un échec de santé du service ou des contrôles HTTPS déclenche le
retour applicatif. Le retour ne restaure pas de base de données. Cette
publication n’a reconstruit ni NixOS ni PostgreSQL et n’a changé aucun schéma.

Cette mise en production applicative répond à la demande explicite de reprise
jusqu’au VPS. Elle n’installe pas l’orchestrateur collectif des trois projets.
