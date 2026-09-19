/* Browser integration only. Survey state and coordinate invariants live in Elm. */
import { createSeed } from './session.js?v=44fc617998f1';
import { Collection } from './collection.js?v=74a6e0c9ba96';
import './space.js?v=68e5e5433449';
import './sliders.js?v=e690453bfce2';
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
  if (message.type === 'save-state') requestAnimationFrame(() => {
    document.querySelector('reading-card')?.layout?.();
    positionComparison();
  });
}
function saveNoticeSpace() {
  const notice = document.querySelector('.save-status:is([data-status="error"],[data-status="submit-error"])');
  return notice ? `${Math.ceil(notice.getBoundingClientRect().height) + 24}px` : '';
}
function showQuestion() {
  requestAnimationFrame(() => {
    window.scrollTo({ top: 0, behavior: 'instant' });
    window.dispatchEvent(new Event('regards-layout'));
    positionComparison();
  });
}
function positionComparison() {
  const layer = document.querySelector('.comparison-layer');
  if (layer) {
    layer.style.paddingTop = `${Math.max(12, (document.querySelector('#question-panel')?.getBoundingClientRect().bottom || 140) + 14)}px`;
    layer.style.paddingBottom = saveNoticeSpace();
  }
}
window.addEventListener('resize', positionComparison);
window.addEventListener('scroll', positionComparison, true);

class ReadingCard extends HTMLElement {
  static get observedAttributes() { return ['production-id']; }
  attributeChangedCallback() {
    if (this.layout) requestAnimationFrame(() => {
      this.querySelector('.reader-content').scrollTop = 0;
      this.layout();
      this.focus({ preventScroll: true });
    });
  }
  connectedCallback() {
    this.layout = () => {
      const bottom = document.querySelector('#question-panel')?.getBoundingClientRect().bottom || 140;
      this.closest('.reader-layer').style.paddingTop = `${Math.max(12, bottom + 14)}px`;
      this.closest('.reader-layer').style.paddingBottom = saveNoticeSpace();
    };
    this.resize = new ResizeObserver(this.layout);
    const questionPanel = document.querySelector('#question-panel'); if (questionPanel) this.resize.observe(questionPanel);
    window.addEventListener('resize', this.layout);
    window.addEventListener('regards-layout', this.layout);
    this.onKey = e => {
      if (e.key !== 'Tab') return;
      const controls = [...this.querySelectorAll('button:not(:disabled),input,select,[tabindex="0"]'), ...document.querySelectorAll('.context-help-card button, .help-dialog button, .save-status button')];
      const first = controls[0], last = controls.at(-1);
      if (e.shiftKey && (document.activeElement === first || document.activeElement === this)) { last?.focus(); e.preventDefault(); }
      if (!e.shiftKey && document.activeElement === last) { first?.focus(); e.preventDefault(); }
    };
    window.addEventListener('keydown', this.onKey);
    requestAnimationFrame(() => {
      this.layout();
      this.focus({ preventScroll: true });
      const orb = document.querySelector('evaluation-space')?.orb(this.getAttribute('production-id'));
      const from = orb?.getBoundingClientRect(), to = this.getBoundingClientRect();
      if (from && !matchMedia('(prefers-reduced-motion: reduce)').matches) this.animate([
        { transform: `translate(${from.x + from.width / 2 - to.x - to.width / 2}px,${from.y + from.height / 2 - to.y - to.height / 2}px) scale(${from.width / to.width},${from.height / to.height})`, borderRadius: '50%', opacity: .65 },
        { transform: 'none', borderRadius: '28px', opacity: 1 }
      ], { duration: 520, easing: 'cubic-bezier(.16,1,.3,1)' }).finished.then(() => window.dispatchEvent(new Event('regards-layout')));
      else window.dispatchEvent(new Event('regards-layout'));
    });
  }
  disconnectedCallback() { window.removeEventListener('keydown', this.onKey); this.resize?.disconnect(); window.removeEventListener('resize', this.layout); window.removeEventListener('regards-layout', this.layout); }
}
customElements.define('reading-card', ReadingCard);
async function closeReader(id) {
  const card = document.querySelector('reading-card'), orb = document.querySelector('evaluation-space')?.orb(id);
  if (card && orb && !matchMedia('(prefers-reduced-motion: reduce)').matches) {
    const from = card.getBoundingClientRect(), to = orb.getBoundingClientRect();
    const anim = card.animate([
      { transform: 'none', borderRadius: '28px', opacity: 1 },
      { transform: `translate(${to.x + to.width / 2 - from.x - from.width / 2}px,${to.y + to.height / 2 - from.y - from.height / 2}px) scale(${to.width / from.width},${to.height / from.height})`, borderRadius: '50%', opacity: .65 }
    ], { duration: 420, easing: 'cubic-bezier(.65,0,.35,1)', fill: 'forwards' });
    await anim.finished.catch(() => {});
  }
  send({ type: 'closed' });
  requestAnimationFrame(() => orb?.focus({ preventScroll: true }));
}

class ContextHelp extends HTMLElement {
  static get observedAttributes() { return ['target']; }
  connectedCallback() {
    this.updateBounds = () => this.schedule();
    this.resize = new ResizeObserver(this.updateBounds); this.resize.observe(document.documentElement);
    window.addEventListener('resize', this.updateBounds); window.addEventListener('scroll', this.updateBounds, true); window.addEventListener('regards-layout', this.updateBounds);
    this.schedule();
  }
  attributeChangedCallback() { this.schedule(); }
  schedule() {
    cancelAnimationFrame(this.frame);
    this.frame = requestAnimationFrame(() => this.position());
  }
  position() {
    const target = document.querySelector(this.getAttribute('target')), card = this.querySelector('.context-help-card');
    if (!this.isConnected || !target || !card) return;
    const rect = target.getBoundingClientRect(), margin = 12, gap = 14, width = innerWidth, height = innerHeight;
    const cardWidth = card.offsetWidth, cardHeight = card.offsetHeight;
    const above = rect.top - cardHeight - gap >= margin;
    const below = !above;
    let top = above ? rect.top - cardHeight - gap : rect.bottom + gap;
    top = Math.max(margin, Math.min(height - cardHeight - margin, top));
    const left = Math.max(margin, Math.min(width - cardWidth - margin, rect.left + (rect.width - cardWidth) / 2));
    const arrowLeft = Math.max(18, Math.min(cardWidth - 18, rect.left + rect.width / 2 - left));
    this.classList.toggle('below', below);
    card.style.setProperty('--arrow-left', `${arrowLeft}px`);
    Object.assign(this.style, { left: `${left}px`, top: `${top}px` });
  }
  disconnectedCallback() {
    cancelAnimationFrame(this.frame); this.resize?.disconnect(); window.removeEventListener('resize', this.updateBounds); window.removeEventListener('scroll', this.updateBounds, true); window.removeEventListener('regards-layout', this.updateBounds);
  }
}
customElements.define('context-help', ContextHelp);
const paths = {
  layers: '<path d="m12 3 9 5-9 5-9-5 9-5Zm-9 9 9 5 9-5M3 16l9 5 9-5"/>',
  cube: '<path d="m12 3 9 5v8l-9 5-9-5V8l9-5Zm0 10v8M3 8l9 5 9-5M12 3v10"/>',
  'plane-xy': '<rect x="4" y="4" width="16" height="16" rx="3"/><path d="M4 12h16M12 4v16"/>',
  'plane-xz': '<path d="m4 7 12-4 4 14-12 4L4 7Zm2 7 12-4M10 5l4 14"/>',
  'plane-yz': '<path d="m4 4 16 5v11L4 15V4Zm0 6 16 5M12 7v11"/>',
  help: '<circle cx="12" cy="12" r="9"/><path d="M9.5 9a2.5 2.5 0 0 1 5 0c0 2-2.5 2-2.5 4m0 3h.01"/>',
  info: '<circle cx="12" cy="12" r="9"/><path d="M12 11v6m0-10h.01"/>',
  arrow: '<path d="M4 12h16m-6-6 6 6-6 6"/>', close: '<path d="m6 6 12 12M6 18 18 6"/>', check: '<path d="m5 12 4 4L19 6"/>',
  read: '<rect x="5" y="3" width="14" height="18" rx="3"/><path d="M9 8h6m-6 4h6m-6 4h3"/>',
  sliders: '<path d="M4 7h16M4 17h16"/><circle cx="9" cy="7" r="3" fill="currentColor"/><circle cx="15" cy="17" r="3" fill="currentColor"/>',
  shrink: '<path d="M4 4l6 6m0-5v5H5m15 10-6-6m0 5v-5h5"/>',
  hand: '<path d="M8 12V5a2 2 0 0 1 4 0v6-3a2 2 0 0 1 4 0v3-1a2 2 0 0 1 4 0v5c0 4-3 6-6 6h-2c-2 0-3-1-4-3l-4-6a2 2 0 0 1 3-2l1 2Z"/>',
  compare: '<rect x="3" y="4" width="7" height="16" rx="2"/><rect x="14" y="4" width="7" height="16" rx="2"/>',
  download: '<path d="M12 3v12m-5-5 5 5 5-5M4 16v5h16v-5"/>',
  menu: '<path d="M4 7h16M4 12h16M4 17h16"/>',
  reset: '<path d="M4 12a8 8 0 1 0 2.3-5.7L4 8.6M4 4v4.6h4.6"/>'
};
customElements.define('ui-icon', class extends HTMLElement {
  connectedCallback() { this.innerHTML = `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">${paths[this.getAttribute('name')] || paths.cube}</svg>`; }
});

try {
  const response = await fetch('data/bank.json'); if (!response.ok) throw new Error('bank'); bank = await response.json();
  const levels = ['5e', '4e', '3e', '2de', '1re spé', 'Tle spé', 'Sup 1'].filter(l => bank.questions.some(q => q.level === l));
  const mount = document.createElement('div'); root.replaceChildren(mount); root.inert = true;
  application = Elm.Survey.init({ node: mount, flags: { levels, version: bank.version, help: readHelpState() } });
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
      case 'close': closeReader(message.id); break;
      case 'event': { const { type, ...entry } = message; collection.event(entry); if (['question', 'open', 'reveal', 'compare'].includes(entry.event)) showQuestion(); break; }
      case 'checkpoint': collection.checkpoint(message.snapshot); break;
      case 'submit': collection.submit(message.snapshot); break;
      case 'retry-save': collection.flush(); break;
      case 'restart': collection.restart(); break;
      case 'help-state': saveHelpState(message.state); break;
    }
  });
  const resumed = await collection.resume();
  if (resumed) { send({ ...resumed, type: resumed.new ? 'session' : 'restore' }); showQuestion(); }
  root.inert = false;
} catch (error) {
  root.inert = false;
  root.replaceChildren(); const panel = document.createElement('section'); panel.className = 'finish-panel';
  const title = document.createElement('h1'); title.textContent = 'Les questions n’ont pas pu être chargées.';
  const retry = document.createElement('button'); retry.className = 'primary'; retry.textContent = 'Réessayer'; retry.onclick = () => location.reload(); panel.append(title, retry); root.append(panel); console.error(error);
}
