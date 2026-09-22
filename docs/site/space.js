/* Orthographic XYZ projection. The DOM preserves sharp, accessible mathematics.
   Elm owns the coordinates; this surface rotates the camera and opens productions. */
import { axes } from './session.js?v=44fc617998f1';
const SVG = 'http://www.w3.org/2000/svg';
const colors = { x: '#087f71', y: '#087ea2', z: '#7260b3' }, xyz = ['x', 'y', 'z'];
const point = (x = 0, y = 0, z = 0) => ({ x, y, z });
const dot = (a, b) => a.x * b.x + a.y * b.y + a.z * b.z;
function orbitBasis(a, e) { return [point(Math.cos(a), 0, -Math.sin(a)), point(-Math.sin(a) * Math.sin(e), Math.cos(e), -Math.cos(a) * Math.sin(e)), point(Math.sin(a) * Math.cos(e), Math.sin(e), Math.cos(a) * Math.cos(e))]; }
function svg(name, attrs = {}) { const n = document.createElementNS(SVG, name); for (const [k, v] of Object.entries(attrs)) n.setAttribute(k, v); return n; }

export class EvaluationSpace extends HTMLElement {
  static get observedAttributes() { return ['payload']; }
  connectedCallback() {
    this.azimuth ??= .64; this.elevation ??= .38; this.basis = orbitBasis(this.azimuth, this.elevation); this.cards = new Map();
    // Un élément reconnecté ne doit jamais conserver une ancienne couche immobile.
    this.replaceChildren(); this.drag = null;
    this.svg = svg('svg', { class: 'space-svg', 'aria-hidden': 'true' });
    this.walls = svg('g'); this.lines = svg('g'); this.guides = svg('g'); this.svg.append(this.walls, this.lines, this.guides);
    this.labels = document.createElement('div'); this.labels.className = 'axis-labels';
    this.orbs = document.createElement('div'); this.orbs.className = 'orb-layer';
    this.append(this.svg, this.labels, this.orbs);
    this.resize = new ResizeObserver(() => this.draw()); this.resize.observe(this);
    this.down = e => this.pointerDown(e); this.move = e => this.pointerMove(e); this.up = e => this.pointerUp(e);
    this.addEventListener('pointerdown', this.down); this.addEventListener('pointermove', this.move); this.addEventListener('pointerup', this.up); this.addEventListener('pointercancel', this.up); this.addEventListener('lostpointercapture', this.up);
    this.onKey = e => this.key(e); this.addEventListener('keydown', this.onKey);
    this.readPayload();
  }
  attributeChangedCallback() { if (this.cards) this.readPayload(); }
  disconnectedCallback() {
    this.resize?.disconnect(); this.removeEventListener('keydown', this.onKey);
    this.removeEventListener('pointerdown', this.down); this.removeEventListener('pointermove', this.move); this.removeEventListener('pointerup', this.up); this.removeEventListener('pointercancel', this.up); this.removeEventListener('lostpointercapture', this.up);
  }
  orb(id) { return this.cards.get(id); }
  dispatch(name, detail) { this.dispatchEvent(new CustomEvent(name, { detail, bubbles: true })); }
  readPayload() {
    let next; try { next = JSON.parse(this.getAttribute('payload')); } catch { return; }
    this.data = next;
    this.setAttribute('aria-label', 'Espace à trois dimensions. Faites glisser pour tourner, ou utilisez les flèches du clavier.');
    this.setAttribute('tabindex', '0'); this.classList.add('free-view');
    for (const [id, orb] of this.cards) if (!next.points.some(p => p.id === id)) { orb.remove(); this.cards.delete(id); }
    for (const p of next.points) {
      let orb = this.cards.get(p.id);
      if (!orb) {
        orb = document.createElement('button'); orb.type = 'button'; orb.className = 'orb'; orb.dataset.id = p.id;
        const preview = document.createElement('rich-text'); preview.setAttribute('content', p.content); preview.className = 'orb-preview'; preview.setAttribute('aria-hidden', 'true');
        const shine = document.createElement('span'); shine.className = 'orb-shine';
        const title = document.createElement('span'); title.className = 'orb-caption'; title.innerHTML = `<strong>${p.number}</strong>`;
        orb.append(preview, shine, title);
        orb.onclick = e => { if (e.detail === 0) this.dispatch('read', { id: p.id }); };
        this.cards.set(p.id, orb); this.orbs.append(orb);
      }
      orb.classList.toggle('selected', p.id === next.selected); orb.classList.toggle('pending', p.judged.length < 3); orb.classList.toggle('being-read', p.id === next.selected && next.reader);
      orb.setAttribute('aria-label', `Rédaction ${p.number}. Appuyer pour lire.`);
      orb.querySelector('.orb-caption strong').textContent = p.number;
      orb.querySelector('rich-text').setAttribute('content', p.content);

    }
    this.draw();
  }
  project(p) { return { x: this.cx + dot(p, this.basis[0]) * this.unit, y: this.cy - dot(p, this.basis[1]) * this.unit, depth: dot(p, this.basis[2]) }; }
  line(parent, a, b, attributes = {}) { const p = this.project(a), q = this.project(b); parent.append(svg('line', { x1: p.x, y1: p.y, x2: q.x, y2: q.y, ...attributes })); }
  draw() {
    if (!this.data || !this.clientWidth) return;
    const w = this.clientWidth, h = this.clientHeight, free = true; this.cx = w / 2; this.cy = h / 2;
    const diameter = Math.max(49, Math.min(68, Math.min(w, h) * .125));
    this.style.setProperty('--orb-size', `${diameter}px`);
    this.style.setProperty('--orb-preview-scale', String(diameter * .78 / 285));
    // L'enveloppe du cube projeté varie avec la caméra ; elle tient dans la scène.
    const largeur = 20 * xyz.reduce((s, a) => s + Math.abs(this.basis[0][a]), 0);
    const hauteur = 20 * xyz.reduce((s, a) => s + Math.abs(this.basis[1][a]), 0);
    this.unit = Math.max(1, Math.min((w - diameter * 1.3 - 32) / largeur, (h - diameter * 1.3 - 40) / hauteur));
    this.svg.setAttribute('viewBox', `0 0 ${w} ${h}`); this.walls.replaceChildren(); this.lines.replaceChildren(); this.guides.replaceChildren(); this.labels.replaceChildren();
    for (const pair of ['xy', 'xz', 'yz']) {
      const [a, b] = pair, hidden = xyz.find(axis => !pair.includes(axis)), base = point(); base[hidden] = free ? -10 : 0;
      const corners = [[-10, -10], [10, -10], [10, 10], [-10, 10]].map(([u, v]) => this.project({ ...base, [a]: u, [b]: v }));
      this.walls.append(svg('polygon', { points: corners.map(p => `${p.x},${p.y}`).join(' '), fill: free ? colors[hidden] : '#dff1ed', 'fill-opacity': free ? '.045' : '.22' }));
    }
    for (const axis of xyz) {
      // Both poles have identical rounded ends, with no directional arrowhead.
      this.line(this.lines, { ...point(), [axis]: -10.5 }, { ...point(), [axis]: 10.5 }, { stroke: colors[axis], 'stroke-width': '1.5', 'stroke-opacity': '.7', 'stroke-linecap': 'round' });
      for (const sign of [-1, 1]) {
        const p = this.project({ ...point(), [axis]: sign * (free ? 12.4 : 11.8) }); const label = document.createElement('span'); label.className = `axis-label axis-${axis}`; label.style.left = `${p.x}px`; label.style.top = `${p.y}px`;
        label.innerHTML = `<strong>${sign < 0 ? axes[axis].negative : axes[axis].positive}</strong>`; this.labels.append(label);
      }
    }
    const zero = this.project(point()); this.lines.append(svg('circle', { cx: zero.x, cy: zero.y, r: '3', fill: '#456962' }));
    const selected = this.data.points.find(p => p.id === this.data.selected);
    if (selected) {
      const pos = this.drag?.id === selected.id && this.drag.current ? this.drag.current : selected.point;
      if (free) for (const axis of xyz) {
        const foot = { ...pos, [axis]: -10 }; this.line(this.guides, pos, foot, { stroke: colors[axis], 'stroke-dasharray': '4 4', 'stroke-width': '1.3', opacity: '.65' });
      }
    }
    const projected = this.data.points.map(item => { const pos = this.drag?.id === item.id && this.drag.current ? this.drag.current : item.point; return { item, pos, screen: this.project(pos) }; });
    for (const { item, pos, screen } of projected) {
      const orb = this.cards.get(item.id);
      // Fan overlapping projections out, with a visible line to the exact coordinate.
      const gap = diameter * 1.12 + 8;
      const siblings = projected.filter(p => Math.hypot(p.screen.x - screen.x, p.screen.y - screen.y) < gap).sort((a, b) => a.item.number - b.item.number), order = siblings.findIndex(p => p.item.id === item.id);
      const offsetX = siblings.length > 1 ? (order - (siblings.length - 1) / 2) * gap : 0, offsetY = siblings.length > 1 ? -diameter * .4 : 0;
      const inset = diameter * .56 + 6;
      const x = Math.max(inset, Math.min(w - inset, screen.x + offsetX)), y = Math.max(inset, Math.min(h - inset, screen.y + offsetY));
      if (offsetX || offsetY || x !== screen.x || y !== screen.y) { this.guides.append(svg('line', { x1: screen.x, y1: screen.y, x2: x, y2: y, stroke: '#526f68', 'stroke-width': '1.1', 'stroke-dasharray': '3 3' })); this.guides.append(svg('circle', { cx: screen.x, cy: screen.y, r: '4', fill: '#087f71', stroke: 'white', 'stroke-width': '1.5' })); }
      const size = free ? Math.max(.9, Math.min(1.12, .94 + screen.depth / 110)) : 1;
      Object.assign(orb.style, { left: `${x}px`, top: `${y}px`, transform: `translate(-50%,-50%) scale(${size})`, zIndex: item.id === this.data.selected ? 80 : Math.round(screen.depth + 35) });
      orb.dataset.x = pos.x; orb.dataset.y = pos.y; orb.dataset.z = pos.z;
    }
  }
  pointerDown(e) {
    if (e.button !== 0 || this.data.reader || this.drag) return;
    const card = e.target.closest('.orb'), entry = card && this.data.points.find(p => p.id === card.dataset.id);
    this.drag = { pointer: e.pointerId, x: e.clientX, y: e.clientY, id: entry?.id, start: entry ? { ...entry.point } : null, moved: false, az: this.azimuth, el: this.elevation };
    this.setPointerCapture(e.pointerId); if (card) card.focus({ preventScroll: true });
  }
  pointerMove(e) {
    const d = this.drag; if (!d || e.pointerId !== d.pointer) return;
    const dx = e.clientX - d.x, dy = e.clientY - d.y; if (Math.hypot(dx, dy) > 5) d.moved = true; if (!d.moved) return;
    this.azimuth = d.az - dx * .008; this.elevation = Math.max(-1.25, Math.min(1.25, d.el + dy * .007)); this.basis = orbitBasis(this.azimuth, this.elevation); this.draw();
  }
  pointerUp(e) {
    const d = this.drag; if (!d || (e.pointerId !== undefined && e.pointerId !== d.pointer)) return;
    this.drag = null; this.cards.get(d.id)?.classList.remove('dragging');
    if (e.type === 'pointercancel' || e.type === 'lostpointercapture') { this.draw(); return; }
    if (d.moved) this.dispatch('orbit', {});
    else if (d.id) this.dispatch('read', { id: d.id }); this.draw();
  }
  key(e) {
    if (this.data?.reader || e.target !== this) return;
    const motion = { ArrowLeft: [-.1, 0], ArrowRight: [.1, 0], ArrowUp: [0, .1], ArrowDown: [0, -.1] }[e.key];
    if (!motion) return;
    e.preventDefault(); this.azimuth += motion[0]; this.elevation = Math.max(-1.25, Math.min(1.25, this.elevation + motion[1]));
    this.basis = orbitBasis(this.azimuth, this.elevation); this.draw(); this.dispatch('orbit', {});
  }
}
customElements.define('evaluation-space', EvaluationSpace);
