const root = document.getElementById('admin');
const api = new URL('../api/admin/', location.href);
let setupToken = new URLSearchParams(location.hash.slice(1)).get('activation');
if (setupToken) history.replaceState(null, '', location.pathname);
let username, versions = [], corpus, stats, currentView = 'dashboard', currentPage = 1;
const selections = { version: '', status: '', level: '', from: '', to: '' };
const e = (tag, props = {}, ...children) => {
  const node = document.createElement(tag);
  for (const [key, value] of Object.entries(props)) {
    if (key.startsWith('on')) node.addEventListener(key.slice(2), value);
    else if (key === 'class') node.className = value;
    else if (key === 'text') node.textContent = value;
    else if (value != null) node.setAttribute(key, value);
  }
  for (const child of children.flat(Infinity)) if (child != null) node.append(child instanceof Node ? child : document.createTextNode(String(child)));
  return node;
};
const rich = value => e('rich-text', { content: value || '' });
const n = value => value == null ? '—' : new Intl.NumberFormat('fr-FR', { maximumFractionDigits: 2 }).format(value);
const date = value => value ? new Date(value).toLocaleString('fr-FR', { dateStyle: 'short', timeStyle: 'short' }) : '—';
const query = () => new URLSearchParams(Object.entries(selections).filter(([, v]) => v)).toString();
const button = (label, onclick, cls = '') => e('button', { type: 'button', class: cls, onclick }, label);
const empty = label => e('div', { class: 'empty' }, label);
async function request(path, options = {}) {
  const response = await fetch(new URL(path, api), { credentials: 'same-origin', ...options, headers: { 'Content-Type': 'application/json', 'X-Matheval-Request': '1', ...options.headers } });
  const data = await response.json();
  if (!response.ok) { if (response.status === 401 && username) { username = null; login(); } throw new Error(data.error || 'Requête impossible.'); }
  return data;
}
function brand() { return e('div', { class: 'brand' }, e('span', { class: 'brand-mark', 'aria-hidden': 'true' }, '≋'), 'Matheval', e('span', { class: 'badge' }, 'Admin')); }
function login() {
  const error = e('div', { role: 'alert' });
  const user = e('input', { name: 'username', autocomplete: 'username', required: '', minlength: 3, maxlength: 80, value: 'admin' });
  const password = e('input', { type: 'password', name: 'password', autocomplete: setupToken ? 'new-password' : 'current-password', required: '', minlength: setupToken ? 14 : 1, maxlength: 256 });
  const confirm = e('input', { type: 'password', name: 'confirm', autocomplete: 'new-password', required: '', minlength: 14 });
  const submit = e('button', { type: 'submit', class: 'primary' }, setupToken ? 'Créer mon accès' : 'Se connecter');
  const form = e('form', { onsubmit: async event => {
    event.preventDefault(); error.replaceChildren();
    if (setupToken && confirm.value !== password.value) { error.replaceChildren(e('p', { class: 'error' }, 'Les mots de passe ne correspondent pas.')); return; }
    submit.disabled = true;
    try {
      const data = await request(setupToken ? 'setup' : 'login', { method: 'POST', body: JSON.stringify({ username: user.value, password: password.value, ...(setupToken ? { token: setupToken } : {}) }) });
      username = data.username; setupToken = null; await initialize();
    } catch (err) { error.replaceChildren(e('p', { class: 'error' }, err.message)); }
    finally { submit.disabled = false; }
  } }, e('label', {}, 'Identifiant', user), e('label', {}, 'Mot de passe', password), setupToken ? e('label', {}, 'Confirmer le mot de passe', confirm) : null, error, submit);
  root.replaceChildren(e('main', { class: 'login' }, brand(), e('div', { class: 'eyebrow' }, 'Espace de recherche'), e('h1', {}, setupToken ? 'Bienvenue dans votre administration.' : 'Retrouver les regards.'), e('p', { class: 'muted' }, setupToken ? 'Choisissez votre identifiant et un mot de passe d’au moins 14 caractères. Ce lien d’activation ne fonctionne qu’une fois.' : 'Connectez-vous pour consulter le corpus et les réponses des enseignants.'), form, setupToken ? button('J’ai déjà un compte', () => { setupToken = null; login(); }, 'quiet') : null, e('p', { class: 'note', style: 'margin-top:24px' }, e('a', { href: '../' }, 'Accéder au questionnaire'))));
}
function shell(title, subtitle) {
  const nav = e('nav', { 'aria-label': 'Administration' }, ...[['dashboard', 'Vue d’ensemble'], ['corpus', 'Énoncés et rédactions'], ['participations', 'Participations']].map(([key, label]) => button(label, () => navigate(key), `nav${currentView === key ? ' active' : ''}`)));
  const logout = async () => { try { await request('logout', { method: 'POST', body: '{}' }); username = null; login(); } catch (err) { alert(err.message); } };
  const sidebar = e('aside', { class: 'sidebar' }, brand(), nav, e('div', { class: 'sidebar-bottom' }, e('span', { class: 'small muted' }, username), e('a', { class: 'button quiet', href: '../', target: '_blank', rel: 'noopener' }, 'Ouvrir le questionnaire ↗'), button('Se déconnecter', logout, 'quiet')));
  const main = e('main', { class: 'workspace' });
  main.append(e('header', { class: 'page-header' }, e('div', {}, e('div', { class: 'eyebrow' }, 'Regards · Rédactions mathématiques'), e('h1', {}, title), e('p', { class: 'muted' }, subtitle)), e('div', {}, e('a', { class: 'button', href: new URL(`exports/responses.csv?${query()}`, api).href }, 'Exporter les réponses CSV'), button('Déconnexion', logout, 'quiet small'))));
  root.replaceChildren(e('div', { class: 'shell' }, sidebar, main)); return main;
}
function filters(main) {
  const select = (key, label, options) => {
    const input = e('select', { name: key }, options.map(([v, label]) => e('option', { value: v, ...(selections[key] === v ? { selected: '' } : {}) }, label)));
    return e('label', {}, label, input);
  };
  const form = e('form', { class: 'filters', onsubmit: event => {
    event.preventDefault(); for (const [key, value] of new FormData(form)) selections[key] = value;
    currentPage = 1; navigate(currentView);
  } }, select('version', 'Version du corpus', versions.map(v => [v.version, v.version])), select('status', 'Participations', [['', 'Toutes'], ['completed', 'Validées'], ['incomplete', 'Non validées']]), select('level', 'Niveaux enseignés', [['', 'Tous'], ...[...new Set(corpus.bank.questions.map(q => q.level))].map(l => [l, l])]),
    ...[['from', 'Depuis'], ['to', 'Jusqu’au']].map(([key, label]) => e('label', {}, label, e('input', { type: 'date', name: key, value: selections[key] }))), e('button', { type: 'submit', class: 'primary' }, 'Appliquer'));
  main.append(form);
}
function histogram(data, label, format = n) {
  if (!data?.length || !data.some(d => d.count)) return empty('Aucune évaluation pour cette sélection.');
  const max = Math.max(...data.map(d => d.count), 1);
  return e('div', { class: 'chart', role: 'img', 'aria-label': label + '. ' + data.map(d => `${format(d.value)} : ${d.count}`).join('; ') }, data.map(d => e('div', { class: 'chart-column', title: `${format(d.value)} : ${d.count}` }, e('span', {}, d.count || ''), e('div', { class: 'chart-bar', style: `height:${Math.max(1, d.count / max * 120)}px` }), e('span', {}, format(d.value)))));
}
function metrics(s) { return e('div', { class: 'metrics-inline' }, `n = ${n(s?.n || 0)}`, e('span', {}, 'Moyenne ', e('strong', {}, n(s?.mean))), e('span', {}, 'Médiane ', e('strong', {}, n(s?.median))), e('span', {}, 'Quartiles ', e('strong', {}, `${n(s?.q1)} · ${n(s?.q3)}`))); }
function table(headers, rows) { return e('div', { class: 'table-wrap' }, e('table', {}, e('thead', {}, e('tr', {}, headers.map(h => e('th', { scope: 'col' }, h)))), e('tbody', {}, rows.map(cells => e('tr', {}, cells.map(c => e('td', {}, c))))))); }
async function dashboard(main) {
  const cards = [['Participations commencées', stats.started, 'Identifiants de participation'], ['Avec des réponses', stats.answered, 'Au moins une note enregistrée'], ['Participations validées', stats.completed, `${n(stats.completionRate * 100)} % de la sélection`], ['Rédactions évaluées', stats.evaluations, `${n(stats.incomplete)} participation(s) non validée(s)`]];
  main.append(e('div', { class: 'stats' }, cards.map(([title, value, help]) => e('article', { class: 'stat' }, e('span', { class: 'small muted' }, title), e('strong', {}, n(value)), e('small', {}, help)))));
  const daily = stats.daily.slice(-30).map(d => ({ value: d.date, count: d.started }));
  const maxLevel = Math.max(1, ...Object.values(stats.levels));
  main.append(e('div', { class: 'grid' }, e('section', { class: 'panel' }, e('h2', {}, 'Participations dans le temps'), histogram(daily, 'Participations commencées par jour', v => v.slice(5).split('-').reverse().join('/')), e('p', { class: 'chart-caption' }, 'Les 30 derniers jours comportant des participations dans la sélection.')), e('section', { class: 'panel' }, e('h2', {}, 'Niveaux enseignés'), Object.keys(stats.levels).length ? e('div', { class: 'levels' }, Object.entries(stats.levels).map(([level, count]) => e('div', { class: 'level' }, level, e('div', { class: 'track' }, e('span', { style: `width:${count / maxLevel * 100}%` })), n(count)))) : empty('Les premières participations apparaîtront ici.')), e('section', { class: 'panel wide' }, e('h2', {}, 'Distribution des notes'), metrics(stats.summary.grades), histogram(stats.summary.grades.distribution, 'Notes sur trois points'), e('p', { class: 'chart-caption' }, 'Une note zéro compte comme une réponse. Les notes manquantes sont exclues.'))));
  main.append(e('p', { class: 'note' }, 'Les effectifs comptent des participations, pas des personnes identifiées. Un enseignant peut participer plusieurs fois et déclarer plusieurs niveaux. Les filtres s’appliquent à tous les résultats et à l’export.'));
}
function catalog(main) {
  const list = e('div', { class: 'question-list' });
  const render = search => {
    const qs = corpus.bank.questions.filter(q => `${q.id} ${q.title} ${q.level} ${q.domain} ${q.statement}`.toLocaleLowerCase('fr').includes(search.toLocaleLowerCase('fr')));
    list.replaceChildren(...qs.map(q => e('article', { class: 'question-card' }, e('div', { class: 'question-head' }, e('div', {}, e('span', { class: 'badge' }, `${q.id} · ${q.level}`), e('h2', {}, q.title)), e('span', { class: 'small muted' }, q.domain)), e('p', {}, `${q.productions.length} rédactions · ${q.productions.reduce((total, p) => total + (stats.productions[`${corpus.bank.version}:${p.id}`]?.grades.n || 0), 0)} évaluations`), button('Consulter l’énoncé et les résultats →', () => questionDetail(q.id), 'quiet'))));
    if (!qs.length) list.append(empty('Aucun énoncé ne correspond à cette recherche.'));
  };
  main.append(e('input', { type: 'search', class: 'catalog-search', placeholder: 'Rechercher un énoncé, un niveau, un domaine…', 'aria-label': 'Rechercher dans le corpus', oninput: event => render(event.target.value) }), list); render('');
}
function axisPanels(s) {
  return e('div', { class: 'axis-stats' }, [['x', 'Confus → Lisible'], ['y', 'Vague → Précis'], ['z', 'Fautif → Valide']].map(([axis, label]) => e('section', { class: 'panel' }, e('h3', {}, label), metrics(s?.axes[axis]), histogram(s?.axes[axis]?.distribution, label), e('p', { class: 'note' }, 'Valeurs regroupées par pas de 2 ; seuls les axes évalués sont comptés.'))));
}
function questionDetail(id) {
  const q = corpus.bank.questions.find(q => q.id === id);
  const main = shell(`${q.id} · ${q.title}`, `${q.level} · ${q.domain} · Corpus ${corpus.bank.version}`);
  main.append(e('div', { class: 'breadcrumbs' }, button('← Tous les énoncés', () => navigate('corpus'), 'quiet')));
  const panel = e('section', { class: 'panel' }, e('h2', {}, 'Énoncé'), rich(q.statement), e('div', { class: 'reference' }, e('h3', {}, 'Réponse de référence'), rich(q.referenceAnswer)));
  for (const p of q.productions) {
    const s = stats.productions[`${corpus.bank.version}:${p.id}`];
    panel.append(e('article', { class: 'production' }, e('div', { class: 'production-head' }, e('h2', {}, p.id), button('Réponses individuelles', () => productionAnswers(q, p), 'quiet')), rich(p.content), e('div', { class: 'analysis' }, e('h3', {}, 'Analyse de conception'), rich(p.research.analysis), e('p', { class: 'note' }, `Cibles : ${(p.research.targets || []).join(', ')}`), e('details', {}, e('summary', {}, 'Contrats examinés'), table(['Contrat', 'Codage de conception'], Object.entries(p.research.contracts || {}).map(([k, v]) => [k, typeof v === 'string' ? v : JSON.stringify(v)])))), e('h3', { style: 'margin-top:24px' }, 'Notes attribuées'), metrics(s?.grades), histogram(s?.grades.distribution, `Notes ${p.id}`), e('p', { class: 'note' }, `Note initiale moyenne : ${n(s?.initialGrades.mean)} · Révisions : ${n(s?.revisions.changed || 0)} · Écart moyen final − initial : ${n(s?.revisions.mean)}`), axisPanels(s)));
  }
  main.append(panel); window.scrollTo(0, 0);
}
async function productionAnswers(q, p) {
  const main = shell(`Évaluations de ${p.id}`, `${q.title} · Corpus ${corpus.bank.version}`);
  main.append(button('← Énoncé et statistiques', () => questionDetail(q.id), 'quiet'), e('section', { class: 'panel' }, rich(p.content)));
  try {
    const rows = await request(`productions/${p.id}/answers?${query()}`);
    main.append(e('section', { class: 'panel' }, e('h2', {}, `${rows.length} réponses enregistrées`), rows.length ? table(['Participation', 'Validation', 'Note initiale', 'Note', 'Lisibilité', 'Précision', 'Validité'], rows.map(r => [button(r.participation_id.slice(0, 8), () => participationDetail(r.participation_id), 'link-button'), r.completed_at ? 'Validée' : 'En cours', n(r.initial_note), n(r.note), ...['x', 'y', 'z'].map(a => r.evaluated_axes.includes(a) ? n(r[a]) : 'Non évalué')])) : empty('Aucune réponse pour cette sélection.')));
  } catch (err) { main.append(e('p', { class: 'error', role: 'alert' }, err.message)); }
}
async function participations(main) {
  const data = await request(`participations?${query()}&page=${currentPage}`);
  const panel = e('section', { class: 'panel' }, e('h2', {}, `${n(data.total)} participations`));
  panel.append(data.rows.length ? table(['Participation', 'Début', 'Niveaux', 'Évaluations', 'Statut'], data.rows.map(p => [button(p.id.slice(0, 8), () => participationDetail(p.id), 'link-button'), date(p.started_at), p.levels.join(', '), n(p.answers), e('span', { class: `badge${p.completed_at ? ' complete' : ''}` }, p.completed_at ? 'Validée' : 'Non validée')])) : empty('Aucune participation pour cette sélection.'));
  if (data.pages > 1) { const previous = button('← Précédent', () => { currentPage--; navigate('participations'); }); previous.disabled = currentPage === 1; const next = button('Suivant →', () => { currentPage++; navigate('participations'); }); next.disabled = currentPage >= data.pages; panel.append(e('div', { class: 'pager' }, previous, `${currentPage} / ${data.pages}`, next)); }
  main.append(panel);
}
async function participationDetail(id) {
  const main = shell(`Participation ${id.slice(0, 8)}`, 'Les valeurs ci-dessous correspondent à la dernière sauvegarde.');
  main.append(button('← Toutes les participations', () => navigate('participations'), 'quiet'));
  try {
    const p = await request(`participations/${id}`);
    main.append(e('section', { class: 'panel' }, e('div', { class: 'metrics-inline' }, `Début : ${date(p.startedAt)}`, `Validation : ${date(p.completedAt)}`, `Corpus : ${p.bankVersion}`, `Niveaux : ${p.levels.join(', ')}`), e('p', { class: 'mono' }, p.id), e('p', { class: 'note' }, `Graine du tirage : ${p.seed} · ${p.events.length} interactions · Questions passées : ${(p.snapshot.skippedQuestions || []).join(', ') || 'aucune'}`)));
    for (const q of p.questions) main.append(e('section', { class: 'panel' }, e('h2', {}, `${q.id} · ${q.level}`), rich(q.statement), q.productions.map(v => {
      const a = p.snapshot.answers?.[v.id];
      return e('article', { class: 'production' }, e('h3', {}, v.id), rich(v.content), a ? table(['Note initiale', 'Note', 'Lisibilité', 'Précision', 'Validité'], [[n(a.initialNote), n(a.note), ...['x', 'y', 'z'].map(axis => a.evaluatedAxes.includes(axis) ? n(a.coordinates[axis]) : 'Non évalué')]]) : e('p', { class: 'muted' }, 'Aucune réponse enregistrée.'));
    })));
    main.append(e('section', { class: 'panel' }, e('h2', {}, 'Journal du parcours'), e('p', { class: 'note' }, 'Les durées décrivent les interactions du navigateur ; elles ne mesurent pas le temps de réflexion.'), e('div', { class: 'journal' }, table(['Depuis le début', 'Événement', 'Question', 'Rédaction', 'Détail'], p.events.map(v => [`${n(v.elapsedMs / 1000)} s`, v.event, v.questionId, v.productionId, v.coordinates ? `x ${n(v.coordinates.x)} · y ${n(v.coordinates.y)} · z ${n(v.coordinates.z)}` : v.value != null ? n(v.value) : '—'])))));
  } catch (err) { main.append(e('p', { class: 'error', role: 'alert' }, err.message)); }
}
async function navigate(view) {
  currentView = view;
  const titles = { dashboard: ['Vue d’ensemble', 'Suivre les participations et les jugements recueillis.'], corpus: ['Énoncés et rédactions', 'Consulter les textes, les analyses et leurs évaluations.'], participations: ['Participations', 'Retrouver les réponses et les parcours enregistrés.'] };
  const main = shell(...titles[view]);
  const loading = e('p', { class: 'loading' }, 'Chargement des résultats…'); main.append(loading);
  try {
    [corpus, stats] = await Promise.all([request(`corpus/${selections.version}`), request(`statistics?${query()}`)]);
    loading.remove(); filters(main);
    if (view === 'dashboard') await dashboard(main); else if (view === 'corpus') catalog(main); else await participations(main);
  } catch (err) { loading.replaceWith(e('p', { class: 'error', role: 'alert' }, err.message)); }
}
async function initialize() { versions = await request('corpora'); selections.version ||= versions[0]?.version || ''; await navigate('dashboard'); }
try { const me = await request('me'); username = me.username; await initialize(); }
catch { login(); }
