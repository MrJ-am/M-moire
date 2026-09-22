import { axes } from './session.js?v=44fc617998f1';
import { dragValue, layoutThumbs } from './slider-layout.js?v=99cc66c54b63';

const labels = { x: 'Lisibilité', y: 'Précision', z: 'Validité' };
const dispatch = (node, name, detail) => node.dispatchEvent(new CustomEvent(name, { detail, bubbles: true }));

// Grab-relative movement: pointerdown never assigns the clicked rail position.
function relativeDrag(node, handlers) {
  let drag;
  const down = e => {
    if (e.button !== 0 || drag) return;
    const start = handlers.begin(e); if (!start) return;
    e.preventDefault();
    drag = { ...start, pointer: e.pointerId, x: e.clientX, y: e.clientY, moved: false, horizontalMoved: false, intent: start.lockAxis ? 'horizontal' : null, current: start.value };
    node.setPointerCapture(e.pointerId);
  };
  const move = e => {
    if (!drag || e.pointerId !== drag.pointer) return;
    const dx = e.clientX - drag.x, dy = e.clientY - drag.y;
    if (Math.hypot(dx, dy) > 4) drag.moved = true;
    if (!drag.moved) return;
    if (!drag.intent) drag.intent = Math.abs(dx) >= Math.abs(dy) ? 'horizontal' : 'vertical';
    if (drag.intent === 'vertical') return;
    if (Math.abs(dx) > 4) drag.horizontalMoved = true;
    if (!drag.horizontalMoved) return;
    e.preventDefault();
    const value = dragValue(drag.value, dx, drag.width, drag.min, drag.max, drag.step);
    if (value !== drag.current) { drag.current = value; handlers.move(drag, false); }
  };
  const end = e => {
    if (!drag || e.pointerId !== drag.pointer) return;
    const ended = drag; drag = null;
    const cancelled = e.type !== 'pointerup' || ended.intent === 'vertical';
    if (cancelled && ended.current !== ended.value) { ended.current = ended.value; handlers.move(ended, false); }
    handlers.end(ended, cancelled);
    if (node.hasPointerCapture(ended.pointer)) node.releasePointerCapture(ended.pointer);
  };
  node.addEventListener('pointerdown', down);
  node.addEventListener('pointermove', move);
  for (const name of ['pointerup', 'pointercancel', 'lostpointercapture']) node.addEventListener(name, end);
  return () => {
    node.removeEventListener('pointerdown', down); node.removeEventListener('pointermove', move);
    for (const name of ['pointerup', 'pointercancel', 'lostpointercapture']) node.removeEventListener(name, end);
  };
}

class AxisSlider extends HTMLElement {
  static get observedAttributes() { return ['payload']; }
  connectedCallback() {
    this.axis = this.getAttribute('axis'); this.cards = new Map();
    this.setAttribute('aria-label', labels[this.axis]);
    this.innerHTML = `<div class="slider-poles"><span>${axes[this.axis].negative}</span><span>${axes[this.axis].positive}</span></div><div class="slider-field"><div class="slider-rail"><span class="axis-midpoint" aria-hidden="true"></span></div><svg class="slider-leaders" aria-hidden="true"></svg><div class="slider-handles"></div></div>`;
    this.field = this.querySelector('.slider-field'); this.leaders = this.querySelector('.slider-leaders'); this.handles = this.querySelector('.slider-handles');
    this.resize = new ResizeObserver(() => this.draw()); this.resize.observe(this);
    this.cleanupDrag = relativeDrag(this, {
      begin: e => {
        if (this.data?.reader || !e.target.closest('.slider-field')) return;
        const direct = e.target.closest('.slider-thumb');
        const nearest = direct || [...this.cards.values()].filter(b => !b.disabled).sort((a, b) => {
          const distance = el => { const r = el.getBoundingClientRect(); return Math.hypot(e.clientX - r.x - r.width / 2, e.clientY - r.y - r.height / 2); };
          return distance(a) - distance(b);
        })[0];
        if (!nearest || nearest.disabled) return;
        const item = this.data.points.find(p => p.id === nearest.dataset.id);
        this.grabbed = { y: -Number(nearest.dataset.lift), offset: parseFloat(nearest.style.left) - Number(nearest.dataset.anchor), baseline: parseFloat(this.style.getPropertyValue('--rail-y')) };
        this.active = item.id; this.valeurActive = item.point[this.axis]; nearest.focus({ preventScroll: true });
        return { id: item.id, value: item.point[this.axis], width: this.field.clientWidth - 44, min: -10, max: 10, step: .1, direct: Boolean(direct), lockAxis: Boolean(direct || e.target.closest('.slider-rail')) };
      },
      move: (d, committed) => this.propose(d.id, d.current, committed),
      end: (d, cancelled) => {
        this.cards.get(d.id)?.classList.remove('dragging');
        if (!cancelled) {
          if (d.horizontalMoved) this.propose(d.id, d.current, true);
          else if (!d.moved && d.direct) dispatch(this, 'read', { id: d.id });
        }
        this.active = null; this.valeurActive = undefined; this.grabbed = null; this.draw();
      }
    });
    this.read();
  }
  attributeChangedCallback() { if (this.cards) this.read(); }
  disconnectedCallback() { this.resize?.disconnect(); this.cleanupDrag?.(); }
  read() {
    try { this.data = JSON.parse(this.getAttribute('payload')); } catch { return; }
    if (this.active && this.valeurActive !== undefined) {
      const courante = this.data.points.find(p => p.id === this.active);
      if (courante) courante.point[this.axis] = this.valeurActive;
    }
    for (const [id, b] of this.cards) if (!this.data.points.some(p => p.id === id)) { b.remove(); this.cards.delete(id); }
    for (const p of this.data.points) {
      let b = this.cards.get(p.id);
      if (!b) {
        b = document.createElement('button'); b.type = 'button'; b.className = 'slider-thumb'; b.dataset.id = p.id;
        b.setAttribute('role', 'slider'); b.setAttribute('aria-valuemin', '-10'); b.setAttribute('aria-valuemax', '10');
        b.setAttribute('aria-orientation', 'horizontal'); b.setAttribute('aria-keyshortcuts', 'Enter ArrowLeft ArrowRight Home End');
        b.innerHTML = '<span class="slider-sphere"></span>'; this.cards.set(p.id, b); this.handles.append(b);
        b.onclick = e => { if (e.detail === 0) dispatch(this, 'read', { id: p.id }); };
        b.onkeydown = e => {
          const step = e.shiftKey ? 1 : .1, current = this.data.points.find(item => item.id === p.id).point[this.axis];
          const values = { ArrowLeft: current - step, ArrowDown: current - step, ArrowRight: current + step, ArrowUp: current + step, Home: -10, End: 10 };
          if (Object.hasOwn(values, e.key)) { e.preventDefault(); this.propose(p.id, dragValue(values[e.key], 0, 1, -10, 10, .1), true); }
        };
      }
      b.querySelector('.slider-sphere').textContent = p.number;
      b.setAttribute('aria-label', `Rédaction ${p.number} · ${labels[this.axis]}`);
      b.disabled = this.data.reader;
    }
    this.draw();
  }
  propose(id, value, committed) {
    const p = this.data.points.find(item => item.id === id); if (!p) return;
    p.point[this.axis] = value;
    if (id === this.active) this.valeurActive = value;
    this.cards.get(id)?.classList.toggle('dragging', !committed);
    this.draw();
    dispatch(this, 'placement', { id, axis: this.axis, value, committed });
  }
  draw() {
    if (!this.data || !this.field.clientWidth) return;
    const layout = layoutThumbs(this.data.points.map(p => ({ id: p.id, number: p.number, value: p.point[this.axis] })), this.field.clientWidth, this.active || this.data.selected, 42, this.grabbed);
    // Stacked panels need no empty upper row for a lone sphere. Once several
    // productions are visible, keep room for their pop-up without moving the
    // rail or the grabbed sphere in the middle of a gesture.
    const reserve = parseFloat(getComputedStyle(this).getPropertyValue('--slider-reserve')) || 0;
    const lift = Math.max(reserve, ...layout.map(p => -p.y)), baseline = this.grabbed?.baseline ?? lift + 22;
    this.field.style.height = `${baseline + 22}px`; this.style.setProperty('--rail-y', `${baseline}px`);
    this.leaders.replaceChildren();
    for (const position of layout) {
      const b = this.cards.get(position.id), p = this.data.points.find(item => item.id === position.id);
      const judged = p.judged.includes(this.axis);
      b.classList.toggle('selected', p.id === (this.active || this.data.selected)); b.classList.toggle('pending', !judged);
      b.classList.toggle('lifted', position.y !== 0);
      b.dataset.value = position.value; b.dataset.anchor = position.anchor; b.dataset.lift = -position.y;
      b.setAttribute('aria-valuenow', String(position.value));
      b.setAttribute('aria-valuetext', !judged ? 'À placer' : position.value === 0 ? 'Au repère central' : `Vers ${position.value < 0 ? axes[this.axis].negative : axes[this.axis].positive}`);
      Object.assign(b.style, { left: `${position.x}px`, top: `${baseline + position.y}px`, zIndex: p.id === (this.active || this.data.selected) ? 5 : 3 });
      if (position.y !== 0 || position.x !== position.anchor) {
        const line = document.createElementNS('http://www.w3.org/2000/svg', 'line');
        for (const [key, value] of Object.entries({ x1: position.anchor, y1: baseline, x2: position.x, y2: baseline + position.y, class: 'slider-leader' })) line.setAttribute(key, value);
        this.leaders.append(line);
        const anchor = document.createElementNS('http://www.w3.org/2000/svg', 'circle');
        for (const [key, value] of Object.entries({ cx: position.anchor, cy: baseline, r: 3, class: 'slider-anchor' })) anchor.setAttribute(key, value);
        this.leaders.append(anchor);
      }
    }
  }
}
customElements.define('axis-slider', AxisSlider);

class GradeSlider extends HTMLElement {
  static get observedAttributes() { return ['value', 'ungraded']; }
  connectedCallback() {
    this.frame = requestAnimationFrame(() => {
      this.input = this.querySelector('input'); if (!this.input) return;
      this.rail = document.createElement('div'); this.rail.className = 'grade-rail'; this.rail.setAttribute('aria-hidden', 'true');
      for (const value of [0, 1, 2, 3]) { const tick = document.createElement('i'); tick.className = 'grade-tick'; tick.style.left = `${value / 3 * 100}%`; this.rail.append(tick); }
      this.knob = document.createElement('span'); this.knob.className = 'grade-knob slider-sphere'; this.knob.setAttribute('aria-hidden', 'true');
      this.append(this.rail, this.knob);
      this.paint = () => { this.knob.style.left = `${16 + Number(this.input.value) / 3 * (this.clientWidth - 32)}px`; this.knob.classList.toggle('pending', this.input.classList.contains('ungraded')); };
      this.resize = new ResizeObserver(this.paint); this.resize.observe(this);
      this.input.addEventListener('input', this.paint); this.input.addEventListener('change', this.paint);
      this.cleanupDrag = relativeDrag(this, {
        begin: e => { this.input.focus({ preventScroll: true }); return { value: Number(this.input.value), width: this.clientWidth - 32, min: 0, max: 3, step: .25, direct: Math.abs(e.clientX - this.knob.getBoundingClientRect().x - 16) < 24, lockAxis: Boolean(e.target.closest('.grade-knob,.grade-rail')) }; },
        move: d => { this.input.value = d.current; this.paint(); },
        end: (d, cancelled) => { if (!cancelled && (d.horizontalMoved || (!d.moved && d.direct))) { this.input.value = d.current; this.paint(); this.input.dispatchEvent(new Event('change', { bubbles: true })); } }
      });
      this.paint();
    });
  }
  attributeChangedCallback() { if (this.paint) requestAnimationFrame(this.paint); }
  disconnectedCallback() { cancelAnimationFrame(this.frame); this.resize?.disconnect(); this.cleanupDrag?.(); this.input?.removeEventListener('input', this.paint); this.input?.removeEventListener('change', this.paint); }
}
customElements.define('grade-slider', GradeSlider);
