// Transport HTTP seulement : toutes les vues et interactions sont dans ElmUI.
const racine = document.getElementById('admin');
const api = new URL('../api/admin/', location.href);
let jetonActivation = new URLSearchParams(location.hash.slice(1)).get('activation');
if (jetonActivation) history.replaceState(null, '', location.pathname);
const application = Elm.Administration.init({ node: racine, flags: { activation: Boolean(jetonActivation) } });
async function transmettre({ identifiant, contexte, chemin, methode, corps }) {
  try {
    const contenu = chemin === 'setup' ? { ...corps, token: jetonActivation } : corps;
    const reponse = await fetch(new URL(chemin, api), {
      credentials: 'same-origin', method: methode,
      headers: { 'Content-Type': 'application/json', 'X-Matheval-Request': '1' },
      ...(methode === 'GET' ? {} : { body: JSON.stringify(contenu) })
    });
    const donnees = await reponse.json();
    if (reponse.ok && chemin === 'setup') jetonActivation = null;
    application.ports.retourAdministration.send({ identifiant, contexte, reussi: reponse.ok, statut: reponse.status, donnees, erreur: donnees.error || 'Requête impossible.' });
  } catch {
    application.ports.retourAdministration.send({ identifiant, contexte, reussi: false, statut: 0, donnees: null, erreur: 'Connexion interrompue. Réessayez.' });
  }
}
application.ports.connexion.subscribe(corps => transmettre({ identifiant: 'connexion', contexte: 0, chemin: 'login', methode: 'POST', corps }));
application.ports.requeteAdministration.subscribe(transmettre);
