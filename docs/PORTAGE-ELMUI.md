# Portage complet — candidat en validation

La reprise complète porte le questionnaire, le prototype et l’administration
(activation comprise) en ElmUI. Les textes mathématiques, les gestes et la
projection 3D conservent leurs ponts spécialisés. Le corpus et les contrats
HTTP, JSON, cookies et PostgreSQL restent inchangés.

Le style est figé dans `style-mrjam.json`, révision
`0fa714d16615131e169e8d3658d3c25fc466e29b` de la branche
`integration/matheval-complet`. Il intègre les ajouts Matheval préparés à
`a160ec1` et les contrôles déjà publiés à `492afe5`. Les empreintes de tous les
modules et des ressources sont vérifiées à chaque construction.

Les polices de Signature sont les blobs exacts de la révision
`17495b13cefa24473e37434b98336b27caec8cdf`, attestés dans
`identite/provenance.json`. La signature demeure le texte sélectionnable
`MrJ.am`. Tous les droits du logo et de la signature sont réservés.

`npm --prefix docs run build:main` reconstruit Main, Survey, Administration et
DemoCard en mode optimisé dans un atelier Linux temporaire, installe les
ressources communes et versionne les références. Les JavaScript générés et les
copies d’identité sont ignorés par Git : les sources Elm et les verrous sont
la référence, et la publication utilise l’artefact issu des tests.

Les tests de corpus, de construction, de logique, d’API et de navigateur sont
requis avant publication. Cette version est un candidat : le résultat du
workflow, puis l’attestation HTTPS du déploiement, doivent être consignés
avant d’annoncer sa publication. Les opérations distantes passent par Actions
avec le compte applicatif existant, sans reconstruction NixOS.
