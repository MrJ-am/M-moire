// Coordinates stay on the rail. Only the visible billes move to avoid overlaps.
export const clamp = (value, min, max) => Math.max(min, Math.min(max, value));
export function dragValue(start, dx, width, min, max, step) {
  const value = start + dx / Math.max(1, width) * (max - min);
  return Number(clamp(Math.round(value / step) * step, min, max).toFixed(8));
}

export function layoutThumbs(points, width, preferred, gap = 42, grabbed = null) {
  const placed = [], inset = 22;
  const ordered = [...points].sort((a, b) => (b.id === preferred) - (a.id === preferred) || a.number - b.number);
  for (const p of ordered) {
    const anchor = inset + (clamp(p.value, -10, 10) + 10) / 20 * Math.max(1, width - inset * 2);
    // Keep the grabbed sphere under the pointer, including its raised row.
    // Only its neighbours rearrange until the gesture is released.
    let candidate = p.id === preferred && grabbed ? {
      ...p, anchor,
      x: clamp(anchor + grabbed.offset, inset, Math.max(inset, width - inset)),
      y: grabbed.y
    } : null;
    for (let level = 0; !candidate; level++) {
      const shifts = [0, ...Array.from({ length: points.length }, (_, i) => [-(i + 1) * gap, (i + 1) * gap]).flat()];
      for (const shift of shifts) {
        const x = clamp(anchor + shift, inset, Math.max(inset, width - inset)), y = level === 0 ? 0 : -level * gap;
        if (placed.every(other => Math.hypot(x - other.x, y - other.y) >= gap - .01)) {
          candidate = { ...p, anchor, x, y }; break;
        }
      }
    }
    placed.push(candidate);
  }
  return placed;
}
