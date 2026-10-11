/* Browser integration only. Survey state and coordinate invariants live in Elm. */
import { createSeed } from './session.js?v=44fc617998f1';
import { Collection } from './collection.js?v=74a6e0c9ba96';
const root = document.getElementById('app');
let application, bank, starting = false;
const collection = new Collection(message => send(message));
const helpStorageKey = 'regards-help-v1';
const defaultHelpState = { enabled: true, introSeen: false, ratingSeen: false, axesSeen: false };
function readHelpState() {
  try { return { ...defaultHelpState, ...(JSON.parse(localStorage.getItem(helpStorageKey) || 'null') || {}) }; }
  catch { return { ...defaultHelpState }; }
}
function saveHelpState(state) {
  try { localStorage.setItem(helpStorageKey, JSON.stringify({ ...defaultHelpState, ...state })); }
  catch { /* The interface remains usable when browser storage is unavailable. */ }
}
function send(message) {
  application?.ports.incoming.send(message);
}
function telechargerReponses(donnees) {
  const url = URL.createObjectURL(new Blob([JSON.stringify(donnees, null, 2)], { type: 'application/json' }));
  const lien = document.createElement('a'); lien.href = url; lien.download = 'mes-reponses-matheval.json'; lien.click();
  setTimeout(() => URL.revokeObjectURL(url), 1000);
}
function showQuestion() {
  window.scrollTo({ top: 0, behavior: 'instant' });
  window.dispatchEvent(new Event('regards-layout'));
}

try {
  const response = await fetch('data/bank.json'); if (!response.ok) throw new Error('bank'); bank = await response.json();
  const levels = ['5e', '4e', '3e', '2de', '1re spé', 'Tle spé', 'Sup 1'].filter(l => bank.questions.some(q => q.level === l));
  application = Elm.Survey.init({ node: root, flags: { levels, version: bank.version, help: readHelpState(), reductionAnimations: matchMedia('(prefers-reduced-motion: reduce)').matches } });
  window.MrJamAnimations.relier(application.ports.reductionAnimations, { initiale: false });
  application.ports.action.subscribe(async message => {
    switch (message.type) {
      case 'session': {
        if (starting) break;
        starting = true;
        try {
          const session = await collection.start(message.levels, bank.version, createSeed());
          send({ type: 'session', bankVersion: session.bankVersion, questions: session.questions }); showQuestion();
        } catch (error) { send({ type: 'error', message: 'La connexion au questionnaire est indisponible. Réessayez dans un instant.' }); }
        finally { starting = false; }
        break;
      }
      case 'recharger': location.reload(); break;
      case 'event': { const { type, ...entry } = message; collection.event(entry); if (['question', 'open', 'reveal', 'compare'].includes(entry.event)) showQuestion(); break; }
      case 'checkpoint': collection.checkpoint(message.snapshot); break;
      case 'submit': collection.submit(message.snapshot); break;
      case 'retry-save': collection.flush(); break;
      case 'restart': collection.restart(); break;
      case 'help-state': saveHelpState(message.state); break;
      case 'export': {
        const donnees = { niveaux: collection.record?.levels, reponses: collection.record?.snapshot?.answers || {} };
        telechargerReponses(donnees); break;
      }
    }
  });
  const resumed = await collection.resume();
  if (resumed) { send({ ...resumed, type: resumed.new ? 'session' : 'restore' }); showQuestion(); }
  root.inert = false;
} catch (error) {
  if (!application) {
    application = Elm.Survey.init({ node: root, flags: { levels: [], help: readHelpState(), erreurChargement: true, reductionAnimations: matchMedia('(prefers-reduced-motion: reduce)').matches } });
    application.ports.action.subscribe(message => { if (message.type === 'recharger') location.reload(); });
    window.MrJamAnimations.relier(application.ports.reductionAnimations, { initiale: false });
  }
  send({ type: 'error', message: 'Les questions n’ont pas pu être chargées. Réessayez dans un instant.' });
}
