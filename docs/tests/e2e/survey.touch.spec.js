const { test, expect } = require('@playwright/test');
const { thumb, center, settled, driver, drag, note, close, start } = require('./gestures.cjs');
test.use({ reducedMotion: 'no-preference' });
test.setTimeout(90000);
test('gestes tactiles Android : glissement, défilement et rédaction suivante', async ({ page }) => {
  page.on('pageerror', error => { throw error; });
  const d = await driver(page, true); await start(page, d);
  await note(page, d); await close(page, d);
  const first = thumb(page, 'x'); await drag(d, first, 30);
  await expect.poll(async () => Number(await first.getAttribute('data-value'))).toBeGreaterThan(0);
  const value = await first.getAttribute('data-value');
  const y = thumb(page, 'y'); await y.scrollIntoViewIfNeeded();
  // Scroll from the empty area, not from the control being manipulated.
  const field = await page.locator('#axis-y .slider-field').boundingBox();
  const beforeScroll = await page.evaluate(() => scrollY), p = { x: field.x + 8, y: field.y + 8 };
  await d.down(p); await d.move({ x: p.x + 2, y: p.y - 90 }); await d.up();
  await expect.poll(() => page.evaluate(() => scrollY)).toBeGreaterThan(beforeScroll);
  await expect(page.locator('reading-card')).toHaveCount(0);
  await expect(y).toHaveAttribute('data-value', '0');
  await expect(first).toHaveAttribute('data-value', value);
  await d.click(page.locator('#next-production'));
  await expect(page.locator('#reader-title')).toHaveText('Rédaction 2');
  await note(page, d); await close(page, d);
  await d.click(thumb(page, 'y', 1)); await expect(page.locator('#reader-title')).toHaveText('Rédaction 1');
});

for (const viewport of [{ width: 390, height: 844 }, { width: 534, height: 405 }]) {
  test.describe(`trajectoire filmée ${viewport.width}×${viewport.height}`, () => {
    test.use({ viewport });
    test('la bille ne revient pas au centre lorsque le doigt sort de la barre', async ({ page }) => {
      const d = await driver(page, true);
      // The filmed interaction starts at the axes, after the reading step.
      // Exercise the resize at that same stage on the short landscape viewport.
      await page.setViewportSize({ width: 390, height: 844 });
      await page.goto('./');
      await d.click(page.getByRole('checkbox', { name: '5e', exact: true }));
      await d.click(page.getByRole('button', { name: 'Commencer', exact: true }));
      await expect(page.locator('.help-dialog')).toBeVisible();
      await d.click(page.getByRole('button', { name: 'Suivant', exact: true }));
      await expect(page.locator('context-help')).toBeVisible();
      await d.click(page.getByRole('button', { name: 'Compris', exact: true }));
      await note(page, d); await close(page, d);
      await page.setViewportSize(viewport);
      const x = thumb(page, 'x'); await x.scrollIntoViewIfNeeded(); await settled(x);
      const p = await center(x), scroll = await page.evaluate(() => scrollY);
      expect(await page.evaluate(p => document.elementFromPoint(p.x, p.y + 10)?.closest('.slider-thumb')?.getAttribute('aria-label'), p)).toBe('Rédaction 1 · Lisibilité');
      // Off-centre grab, then a curved diagonal path beyond the highlighted rail,
      // as in 431097.mp4. A perfectly horizontal swipe missed this regression.
      await d.down({ x: p.x, y: p.y + 10 });
      await d.move({ x: p.x + 6, y: p.y + 14 });
      await expect.poll(async () => Number(await x.getAttribute('data-value'))).toBeGreaterThan(0);
      await d.move({ x: p.x + 9, y: p.y + 40 });
      await expect.poll(async () => Number(await x.getAttribute('data-value'))).toBeGreaterThan(0);
      await d.move({ x: p.x + 60, y: p.y + 90 });
      const position = await x.getAttribute('data-value');
      expect(Number(position)).toBeGreaterThan(0);
      await expect.poll(() => page.evaluate(() => scrollY)).toBe(scroll);
      await d.up();
      await expect(x).toHaveAttribute('data-value', position);
      await expect(thumb(page, 'y')).toHaveAttribute('data-value', '0');
      await expect(thumb(page, 'z')).toHaveAttribute('data-value', '0');
      await expect(page.getByRole('heading', { name: 'Ajustez la précision', exact: true })).toBeInViewport({ ratio: 1 });
      await expect(thumb(page, 'y')).toBeInViewport({ ratio: 1 });
    });
  });
}

test('la note suit aussi une trajectoire tactile qui commence verticalement', async ({ page }) => {
  const d = await driver(page, true); await start(page, d);
  const p = await center(page.locator('.grade-knob'));
  await d.down(p); await d.move({ x: p.x + 2, y: p.y - 10 });
  await d.move({ x: p.x + 40, y: p.y - 50 }); await d.up();
  await expect(page.locator('#grade')).not.toHaveClass(/ungraded/);
  expect(Number(await page.locator('#grade').inputValue())).toBeGreaterThan(1.5);
  await expect(page.locator('#validate-reading')).toBeEnabled();
});

test('un geste tactile annulé ne valide ni la note ni la coordonnée', async ({ page }) => {
  const d = await driver(page, true); await start(page, d);
  const knob = page.locator('.grade-knob'), p = await center(knob);
  await d.down(p); await d.move({ x: p.x + 30, y: p.y }); await d.cancel();
  await expect(page.locator('#grade')).toHaveValue('1.5');
  await expect(page.locator('#grade')).toHaveClass(/ungraded/);
  await expect(page.locator('#validate-reading')).toBeDisabled();
  await note(page, d); await close(page, d);
  const x = thumb(page, 'x'); await x.scrollIntoViewIfNeeded(); const q = await center(x);
  await d.down(q); await d.move({ x: q.x + 30, y: q.y }); await d.cancel();
  await expect(x).toHaveAttribute('data-value', '0');
  await expect(x).toHaveClass(/pending/);
  await expect(page.locator('reading-card')).toHaveCount(0);
});
