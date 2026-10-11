La bibliothèque `matheval` ne démarre aucun service, ne migre aucune base et
n'acquiert aucun secret lors de son chargement. L'assembleur central fournit un
contexte PostgreSQL et appelle explicitement l'import du corpus source.

Collecte : `creer-session`, `lire-session`, `lire-evenements`,
`sauvegarder-session`. Le secret pseudonyme est exigé pour chaque opération privée.
Les transactions réservent la participation, protègent la révision et conservent
le préfixe du journal. Zéro est une note ; null signifie absence.

Administration scientifique : activation/connexion, sessions durables en SQL,
corpus, statistiques, réponses et exports. Chaque lecture vérifie sa session.
Ces droits sont limités aux résultats Matheval expressément prévus ; ils ne
donnent aucun droit sur Vision et ne réidentifient aucune participation.

`mrjam-native`, bibliothèque interne de l'infrastructure, fournit les appels aux
API officielles OpenSSL et libpq existantes. Scrypt conserve le sel textuel et les
paramètres Node historiques. Les empreintes reprennent JSON.stringify après la
normalisation du schéma, dont l'ordre des propriétés et le binaire64.

Écarts corrigés et différentiels : l'ancien backend retournait 500 pour un UUID
syntaxiquement impossible ou une date de filtre comme 2026-02-30 ; le nouveau
renvoie respectivement 404 et 400. Les parcours correspondants vérifient les deux
comportements. Aucune migration de données pour ces corrections.

Production : reste sur Node tant que l'assemblage complet n'est pas qualifié et
promu par `MrJ-am/vps-infrastructure`. L'adaptateur HTTP central, les limitations
de débit, le listener et les ressources statiques appartiennent à l'assembleur.
