const { expect } = require('@playwright/test');

const thumb = (page, axis, number = 1) => page.locator(`#axis-${axis}`).getByRole('slider', { name: `Rédaction ${number} ·`, exact: false });
const center = async locator => {
  const b = await locator.boundingBox();
  if (!b) throw new Error('Le contrôle doit être visible avant le geste.');
  return { x: b.x + b.width / 2, y: b.y + b.height / 2 };
};
async function settled(locator) {
  await expect(locator).toBeVisible();
  await expect.poll(() => locator.evaluate(el => el.getAnimations({ subtree: true }).every(a => a.playState !== 'running'))).toBe(true);
}
async function driver(page, touch = false) {
  const cdp = touch ? await page.context().newCDPSession(page) : null;
  let point;
  const send = (type, p) => cdp.send('Input.dispatchTouchEvent', { type, touchPoints: p ? [{ id: 1, ...p }] : [] });
  return {
    async down(p) { point = p; if (cdp) await send('touchStart', p); else { await page.mouse.move(p.x, p.y); await page.mouse.down(); } },
    async move(p) {
      const from = point;
      for (let i = 1; i <= 8; i++) {
        point = { x: from.x + (p.x - from.x) * i / 8, y: from.y + (p.y - from.y) * i / 8 };
        if (cdp) await send('touchMove', point); else await page.mouse.move(point.x, point.y);
        // A physical gesture spans several rendering frames.
        await page.waitForTimeout(18);
      }
    },
    async up() { if (cdp) await send('touchEnd'); else await page.mouse.up(); },
    async cancel() { if (!cdp) throw new Error('Touch driver required'); await send('touchCancel'); },
    async click(locator) { await locator.scrollIntoViewIfNeeded(); if (cdp) await locator.tap(); else await locator.click(); }
  };
}
async function drag(d, locator, dx, dy = 0) {
  await locator.scrollIntoViewIfNeeded(); await settled(locator);
  const p = await center(locator);
  await d.down(p); await d.move({ x: p.x + dx, y: p.y + dy }); await d.up();
}
async function note(page, d, dx = 35) {
  await settled(page.locator('reading-card'));
  await drag(d, page.locator('.grade-knob'), dx);
  await expect(page.locator('#grade')).not.toHaveClass(/ungraded/);
}
async function close(page, d) {
  await d.click(page.locator('#place-button'));
  await expect(page.locator('reading-card')).toHaveCount(0);
}
async function start(page, d) {
  await page.goto('./');
  await d.click(page.getByRole('checkbox', { name: '5e', exact: true }));
  await d.click(page.getByRole('button', { name: 'Commencer', exact: true }));
  const step = n => expect(page.locator('spotlight-guide')).toHaveAttribute('step', String(n));
  await step(0); await note(page, d); await step(1); await close(page, d); await step(2);
  for (const [i, a] of ['x', 'y', 'z'].entries()) { await drag(d, thumb(page, a), 25); await step(i + 3); }
  const scene = page.locator('#space'); await scene.scrollIntoViewIfNeeded();
  const b = await scene.boundingBox(), p = { x: b.x + b.width - 40, y: b.y + 40 };
  await d.down(p); await d.move({ x: p.x - 45, y: p.y + 12 }); await d.up(); await step(6);
  await d.click(thumb(page, 'x')); await step(7);
  await d.click(page.getByRole('button', { name: 'Commencer mes questions', exact: true }));
  await expect(page.locator('spotlight-guide')).toHaveCount(0);
  await settled(page.locator('reading-card'));
}
module.exports = { thumb, center, settled, driver, drag, note, close, start };
