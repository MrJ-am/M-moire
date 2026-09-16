const storageKey = 'matheval-participation-v1';
const api = new URL('api/', document.baseURI);
const randomSecret = () => [...crypto.getRandomValues(new Uint8Array(32))].map(n => n.toString(16).padStart(2, '0')).join('');

export class Collection {
  constructor(notify) {
    this.notify = notify;
    this.record = null;
    this.busy = false;
    this.timer = null;
    window.addEventListener('online', () => this.flush());
    document.addEventListener('visibilitychange', () => { if (document.hidden) this.flush(); });
  }
  status(status, message = '') { this.notify({ type: 'save-state', status, message }); }
  persist() {
    try { localStorage.setItem(storageKey, JSON.stringify(this.record)); }
    catch { this.status('error', 'Le navigateur ne peut pas conserver une copie locale. Gardez cette page ouverte jusqu’à la confirmation d’enregistrement.'); }
  }
  async request(path, options = {}) {
    const response = await fetch(new URL(path, api), { ...options, credentials: 'same-origin', headers: {
      'Content-Type': 'application/json', 'X-Matheval-Request': '1', ...(this.record ? { 'X-Session-Token': this.record.secret } : {}), ...options.headers
    } });
    const result = await response.json();
    if (!response.ok) throw Object.assign(new Error(result.error || 'Enregistrement indisponible.'), { status: response.status });
    return result;
  }
  async start(levels, bankVersion, seed) {
    if (!this.record || this.record.session || this.record.bankVersion !== bankVersion || JSON.stringify(levels) !== JSON.stringify(this.record.levels)) {
      this.record = { id: crypto.randomUUID(), secret: randomSecret(), bankVersion, levels, seed, events: [], revision: 0, savedRevision: 0, final: false, snapshot: null };
      this.persist();
    }
    this.status('saving');
    const { id, secret, levels: selected, bankVersion: version, seed: draw } = this.record;
    const session = await this.request('sessions', { method: 'POST', body: JSON.stringify({ id, secret, levels: selected, bankVersion: version, seed: draw }) });
    this.record.session = session; this.persist();
    return session;
  }
  async resume() {
    try { this.record = JSON.parse(localStorage.getItem(storageKey) || 'null'); } catch { return null; }
    if (!this.record?.session || !this.record?.secret) return null;
    try {
      const remote = await this.request(`sessions/${this.record.id}`);
      if (remote.completedAt || remote.revision > this.record.revision) {
        this.record.snapshot = remote.snapshot; this.record.revision = remote.revision; this.record.savedRevision = remote.revision;
        this.record.final = Boolean(remote.completedAt); this.record.session = remote;
        // An advanced remote copy must supply its full append-only event journal.
        if (!remote.completedAt) {
          const history = await this.request(`sessions/${this.record.id}/events`);
          this.record.events = history;
        }
      } else {
        this.record.savedRevision = remote.revision;
        this.record.session = { ...remote, snapshot: this.record.snapshot || remote.snapshot };
      }
      this.persist();
    } catch (error) {
      if (error.status === 401 || error.status === 404) throw new Error('Cette participation n’est plus accessible. Contactez l’équipe de recherche avant d’effacer les données de ce navigateur.');
      this.status('error');
    }
    const session = this.record.session;
    if (!this.record.snapshot?.progress) return { ...session, new: true };
    setTimeout(() => this.flush(), 300);
    return { ...session, snapshot: this.record.snapshot, saveStatus: session.completedAt ? 'completed' : this.record.final ? 'submitting' : this.record.revision > this.record.savedRevision ? 'saving' : 'saved' };
  }
  event(entry) {
    if (!this.record || this.record.session?.completedAt) return;
    const elapsedMs = Math.max(Date.now() - Date.parse(this.record.session.startedAt), this.record.events.at(-1)?.elapsedMs || 0);
    this.record.events.push({ ...entry, at: new Date().toISOString(), elapsedMs });
    this.changed();
  }
  checkpoint(snapshot) {
    if (!this.record || this.record.session?.completedAt || this.record.final) return;
    if (JSON.stringify(snapshot) === JSON.stringify(this.record.snapshot)) return;
    this.record.snapshot = snapshot; this.changed();
  }
  changed() {
    this.record.revision++; this.status(this.record.final ? 'submitting' : 'saving'); this.persist();
    clearTimeout(this.timer); this.timer = setTimeout(() => this.flush(), 350);
  }
  submit(snapshot) {
    if (this.record.final) { this.flush(); return; }
    this.record.snapshot = snapshot; this.record.final = true; this.changed();
    clearTimeout(this.timer);
    // Allow Elm's checkpoint and interaction commands to finish in the same turn.
    this.timer = setTimeout(() => this.flush(), 0);
  }
  async flush() {
    if (this.busy || !this.record?.snapshot || this.record.revision <= this.record.savedRevision || this.record.session?.completedAt) return;
    this.busy = true;
    try {
      while (this.record.revision > this.record.savedRevision) {
        this.status(this.record.final ? 'submitting' : 'saving');
        const payload = { revision: this.record.revision, final: this.record.final, snapshot: this.record.snapshot, events: this.record.events };
        const result = await this.request(`sessions/${this.record.id}`, { method: 'PUT', body: JSON.stringify(payload) });
        this.record.savedRevision = result.revision;
        if (result.completedAt) this.record.session.completedAt = result.completedAt;
        this.persist();
        this.status(result.completedAt ? 'completed' : this.record.final ? 'submitting' : 'saved');
        if (result.completedAt) break;
      }
    } catch (error) {
      this.status(this.record.final ? 'submit-error' : 'error', error.status === 409 ? error.message : 'Enregistrement en attente. Vos réponses sont conservées sur cet appareil.');
    } finally { this.busy = false; }
  }
  restart() { clearTimeout(this.timer); this.record = null; localStorage.removeItem(storageKey); }
}
