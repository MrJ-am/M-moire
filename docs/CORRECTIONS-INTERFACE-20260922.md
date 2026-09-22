# Corrections des interactions et de la navigation

La liste et la scène montrent toutes les rédactions de l'énoncé dès son ouverture.
On peut lire, fermer, rouvrir et évaluer dans l'ordre souhaité, sans obligation
de noter avant de placer les trois repères. « Énoncé suivant » prévient si des
évaluations manquent, avec la possibilité de poursuivre. Aucune absence de réponse
n'est convertie en zéro évalué. Les anciens enregistrements restent compatibles.

Le menu est une fenêtre bornée par l'écran : accueil, informations de participation,
export des réponses, compte administrateur et aide. La participation n'est pas un
compte : elle ne collecte ni adresse électronique ni mot de passe. La déconnexion
du compte existant reste dans l'administration.

Les rails conservent leur géométrie pendant la saisie, même si une mise à jour Elm
arrive entre deux mouvements. Les contrôles sont séparés sans modifier les valeurs.
Le style des curseurs appartient au dépôt commun. En portrait, les trois rails
occupent moins de hauteur que la scène ; les sphères et la projection s'adaptent
à l'espace disponible. La reconnexion du composant 3D reconstruit une seule couche
de billes, ce qui supprime les copies immobiles.

Les fenêtres suivent `100dvh`. Les petits écrans gardent le défilement, et l'énoncé
cesse d'être collant lorsque la hauteur disponible est faible.

## Sécurité

Migration additive `002-sessions-administrateur.sql` : expiration administrative
après deux heures d'inactivité, durée absolue de huit heures conservée, vingt sessions
maximum par compte, remplacement de l'ancien jeton à la reconnexion. Le hachage
scrypt des mots de passe, les réponses et les secrets de participation sont conservés.
Le retour applicatif reste compatible avec la colonne supplémentaire ; il ne
doit jamais restaurer la base et effacer les réponses reçues entre-temps.

L'audit comparé et les résultats effectifs de publication sont conservés dans le
dépôt privé d'infrastructure, et notifiés par le registre commun. Un test local
ou un commit ne constitue pas une preuve de déploiement.
