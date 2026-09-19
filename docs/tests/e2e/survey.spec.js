const { test, expect } = require('@playwright/test');
const fs = require('node:fs');

test.use({ reducedMotion: 'reduce' });
const axis = (page, name) => page.locator(`#axis-${name}`);
const thumb = (page, name, number = 1) => axis(page, name).getByRole('slider', { name: `Rédaction ${number} ·`, exact: false });
async function rotate(page) {
  await page.locator('#space').press('ArrowRight');
}
async function grade(page, quarters) {
  const slider = page.getByRole('slider', { name: 'Note sur 3' });
  await slider.press('Home');
  for (let i = 0; i < quarters; i++) await slider.press('ArrowRight');
  await expect(slider).toHaveValue(String(quarters / 4));
}
async function close(page) {
  await page.locator('#validate-reading').click();
  await expect(page.locator('reading-card')).toHaveCount(0);
  const contextual = page.locator('context-help');
  if (await contextual.count()) await contextual.getByRole('button', { name: /Compris|Fermer/, exact: false }).click();
}
async function start(page, level = '3e') {
  await page.goto('./');
  await page.getByRole('checkbox', { name: level, exact: true }).check();
  await page.getByRole('button', { name: 'Commencer', exact: true }).click();
  await expect(page.locator('.help-dialog')).toBeVisible();
  await page.getByRole('button', { name: 'Suivant', exact: true }).click();
  await expect(page.locator('context-help')).toBeVisible();
  await page.getByRole('button', { name: 'Compris', exact: true }).click();
  await expect(page.locator('reading-card')).toBeVisible();
  await expect(page.locator('.orb')).toHaveCount(1);
  await expect(page.locator('#grade')).toHaveClass(/ungraded/);
}

test('aide facultative, contextuelle et réinitialisable', async ({ page }) => {
  await page.goto('./');
  await page.getByRole('checkbox', { name: '3e', exact: true }).check();
  await page.getByRole('button', { name: 'Commencer', exact: true }).click();
  await expect(page.locator('.help-dialog')).toBeVisible();
  await expect(page.locator('.help-dialog')).toContainText('Vous allez être amené');
  await page.getByRole('button', { name: 'Passer l’aide', exact: true }).click();
  await expect(page.locator('.help-dialog, context-help')).toHaveCount(0);

  await page.getByRole('button', { name: 'Aide sur la fiche de rédaction', exact: true }).click();
  await expect(page.locator('context-help')).toContainText('Lisez la production');
  await page.getByRole('button', { name: 'Fermer', exact: true }).click();
  await grade(page, 6);
  await page.locator('#validate-reading').click();
  await expect(page.locator('.reader')).toHaveCount(0);
  const axesHelp = page.locator('context-help');
  if (await axesHelp.count()) await axesHelp.getByRole('button', { name: 'Compris', exact: true }).click();

  await page.getByRole('button', { name: 'Ouvrir le menu', exact: true }).click();
  await page.getByRole('menuitem', { name: 'Réinitialiser l’aide', exact: true }).click();
  await expect(page.locator('.help-dialog')).toBeVisible();
  await page.getByRole('button', { name: 'Suivant', exact: true }).click();
  await expect(page.locator('context-help')).toBeVisible();
  await page.getByRole('button', { name: 'Compris', exact: true }).click();
  await expect(page.locator('.help-dialog, context-help')).toHaveCount(0);
  await expect(page.locator('#validate-reading')).toHaveText(/Valider/);
});

test('les aides contextuelles apparaissent une seule fois à l’étape concernée', async ({ page }) => {
  await page.goto('./');
  await page.getByRole('checkbox', { name: '3e', exact: true }).check();
  await page.getByRole('button', { name: 'Commencer', exact: true }).click();
  await page.getByRole('button', { name: 'Suivant', exact: true }).click();
  await page.getByRole('button', { name: 'Compris', exact: true }).click();
  await grade(page, 6);
  await page.locator('#validate-reading').click();
  await expect(page.locator('context-help')).toContainText('Déplacez les trois curseurs');
  await page.getByRole('button', { name: 'Compris', exact: true }).click();
  await page.locator('#axis-x').getByRole('slider').press('ArrowRight');
  await expect(page.locator('context-help')).toHaveCount(0);
});
async function coordinates(orb) {
  return orb.evaluate(el => ['x', 'y', 'z'].map(a => Number(el.dataset[a])));
}
async function finishBySkipping(page) {
  while (await page.getByRole('button', { name: 'Passer cette question', exact: true }).count()) {
    if (await page.locator('reading-card').count()) { await grade(page, 6); await close(page); }
    await page.getByRole('button', { name: 'Passer cette question', exact: true }).click();
    await expect(page.locator('reading-card, .finish-panel')).toBeVisible();
  }
}

test('trois curseurs indépendants, note révisable et enregistrement traçable', async ({ page }) => {
  await start(page);
  await expect(page.locator('reading-card input')).toHaveCount(1);
  await expect(page.locator('#grade')).toHaveAttribute('step', '0.25');
  await expect(page.locator('main')).not.toContainText(/contrat|rédaction de référence|−10|\+10/i);
  const firstId = await page.locator('reading-card').getAttribute('production-id');
  await grade(page, 9); await close(page);
  const first = page.locator(`.orb[data-id="${firstId}"]`);
  for (let i = 0; i < 2; i++) await thumb(page, 'x').press('Shift+ArrowRight');
  await expect.poll(() => coordinates(first)).toEqual([2, 0, 0]);
  for (let i = 0; i < 2; i++) await thumb(page, 'y').press('Shift+ArrowRight');
  await expect.poll(() => coordinates(first)).toEqual([2, 2, 0]);
  for (let i = 0; i < 3; i++) await thumb(page, 'z').press('Shift+ArrowRight');
  await expect.poll(() => coordinates(first)).toEqual([2, 2, 3]);
  await rotate(page);
  await expect.poll(() => coordinates(first)).toEqual([2, 2, 3]);
  await page.locator('#next-production').click();
  await expect(page.locator('#reader-title')).toHaveText('Rédaction 2');
  await expect(page.locator('.orb')).toHaveCount(2);
  await grade(page, 0); await close(page);
  await thumb(page, 'x', 1).click();
  await expect(page.locator('#grade')).toHaveValue('2.25');
  await grade(page, 6); await close(page);
  await page.getByRole('button', { name: 'Comparer', exact: true }).click();
  await expect(page.locator('.comparison-columns rich-text')).toHaveCount(2);
  await page.getByRole('button', { name: 'Fermer la comparaison', exact: true }).click();
  await finishBySkipping(page);
  const exported = await require('./collection.cjs').submitted(page, () => page.getByRole('button', { name: 'Valider ma participation', exact: true }).click());
  expect(Number.isInteger(exported.session.seed)).toBe(true);
  expect(exported.session.questions).toHaveLength(2);
  expect(exported.answers[firstId]).toMatchObject({ note: 1.5, initialNote: 2.25, coordinates: { x: 2, y: 2, z: 3 } });
  expect(exported.answers[firstId].evaluatedAxes.sort()).toEqual(['x', 'y', 'z']);
  expect(Object.values(exported.answers).some(a => a.note === 0)).toBe(true);
  expect(exported.answers['practice-1']).toBeUndefined();
  expect(exported.events.every(e => e.questionId !== 'practice')).toBe(true);
  expect(exported.events.some(e => e.event === 'orbit')).toBe(true);
  expect(exported.events.filter(e => e.event === 'place').every(e => ['x','y','z'].includes(e.axis))).toBe(true);
  expect(exported.session.completedAt).toBeTruthy();
});

test('la saisie ne saute pas, le centre se confirme et la caméra garde les coordonnées', async ({ page }) => {
  await start(page, '5e');
  await grade(page, 6);
  const knob = await page.locator('.grade-knob').boundingBox();
  await page.mouse.move(knob.x + knob.width / 2 + 45, knob.y + knob.height / 2);
  await page.mouse.down();
  await expect(page.locator('#grade')).toHaveValue('1.5');
  await page.mouse.move(knob.x + knob.width / 2 + 75, knob.y + knob.height / 2, { steps: 6 });
  await page.mouse.up();
  const note = Number(await page.locator('#grade').inputValue());
  expect(note).toBeGreaterThan(1.5); expect(note).toBeLessThan(2.5);
  await close(page);
  await page.locator('#confirm-position').click();
  await expect(page.locator('.orb')).not.toHaveClass(/pending/);
  await expect.poll(() => coordinates(page.locator('.orb'))).toEqual([0, 0, 0]);
  const firstId = await page.locator('.orb').getAttribute('data-id');
  const box = await thumb(page, 'x').boundingBox();
  await page.mouse.move(box.x + box.width / 2, box.y + box.height / 2);
  await page.mouse.down();
  await page.mouse.move(box.x + box.width / 2, box.y + box.height / 2 + 25, { steps: 5 });
  await page.mouse.up();
  await expect(page.locator('reading-card')).toHaveCount(0);
  await expect.poll(() => coordinates(page.locator('.orb'))).toEqual([0, 0, 0]);
  await page.mouse.move(box.x + box.width / 2 + 17, box.y + box.height / 2);
  await page.mouse.down();
  await expect.poll(() => coordinates(page.locator('.orb'))).toEqual([0, 0, 0]);
  await page.mouse.move(box.x + box.width / 2 + 67, box.y + box.height / 2, { steps: 8 });
  await expect.poll(async () => (await coordinates(page.locator('.orb')))[0]).toBeGreaterThan(0);
  await page.mouse.up();
  const before = await coordinates(page.locator('.orb'));
  expect(before[1]).toBe(0); expect(before[2]).toBe(0);
  const space = await page.locator('#space').boundingBox();
  await page.mouse.move(space.x + space.width - 35, space.y + 60);
  await page.mouse.down(); await page.mouse.move(space.x + space.width - 110, space.y + 100, { steps: 8 }); await page.mouse.up();
  await expect.poll(() => coordinates(page.locator('.orb'))).toEqual(before);
  await page.getByRole('button', { name: 'Passer cette question', exact: true }).click();
  await grade(page, 5); await close(page);
  await page.getByRole('button', { name: '← Question précédente', exact: true }).click();
  await expect(page.locator('reading-card')).toHaveAttribute('production-id', firstId);
  await expect(page.locator('#grade')).toHaveValue(String(note));
  await close(page);
  await expect.poll(() => coordinates(page.locator('.orb'))).toEqual(before);
});

test('billes proches dégagées, cliquables et toujours à leur vraie coordonnée', async ({ page }) => {
  await start(page);
  await grade(page, 6); await close(page); await page.locator('#confirm-position').click();
  await page.locator('#next-production').click();
  await grade(page, 7); await close(page);
  const first = thumb(page, 'x', 1), second = thumb(page, 'x', 2);
  await expect(first).toHaveAttribute('data-lift', '42');
  await expect(second).toHaveAttribute('data-lift', '0');
  await expect(first).toHaveAttribute('data-value', '0');
  await expect(second).toHaveAttribute('data-value', '0');
  await second.press('ArrowRight');
  await expect(first).toHaveAttribute('data-lift', '42');
  await expect(second).toHaveAttribute('data-value', '0.1');
  await expect(first).toHaveAttribute('data-value', '0');
  await page.screenshot({ path: test.info().outputPath('billes-proches.png'), fullPage: true });
  await first.click(); await expect(page.locator('#reader-title')).toHaveText('Rédaction 1'); await close(page);
  await second.click(); await expect(page.locator('#reader-title')).toHaveText('Rédaction 2'); await close(page);
  await second.press('End');
  await expect(first).toHaveAttribute('data-lift', '0');
  await expect(second).toHaveAttribute('data-value', '10');
  await expect(first).toHaveAttribute('data-value', '0');
  await expect(page.locator('#space .axis-label small, #space svg text')).toHaveCount(0);
});

test('curseurs au-dessus sur téléphone et lecture après rotation de l’écran', async ({ page }) => {
  await page.setViewportSize({ width: 390, height: 844 });
  await start(page, '5e');
  const question = await page.locator('#question-panel').boundingBox();
  await expect(page.locator('#question-panel')).toBeInViewport({ ratio: 1 });
  const reader = await page.locator('reading-card').boundingBox();
  expect(reader.width).toBeGreaterThan(350);
  expect(reader.y).toBeGreaterThanOrEqual(question.y + question.height);
  expect(reader.height).toBeGreaterThan(500);
  expect(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth)).toBe(true);
  await page.screenshot({ path: test.info().outputPath('note-mobile.png'), fullPage: true });
  await grade(page, 8); await close(page);
  const bars = await page.locator('#axes-panel').boundingBox(), scene = await page.locator('#space').boundingBox();
  expect(bars.y + bars.height).toBeLessThanOrEqual(scene.y);
  expect(bars.height).toBeLessThan(350);
  // The statement has variable length: measure the controls below it.
  expect(scene.y - question.y - question.height).toBeLessThan(365);
  await thumb(page, 'z').press('Shift+ArrowRight');
  await page.screenshot({ path: test.info().outputPath('axes-mobile.png'), fullPage: true });
  await page.setViewportSize({ width: 844, height: 390 });
  await expect.poll(() => coordinates(page.locator('.orb'))).toEqual([0, 0, 1]);
  await page.locator('.orb').press('Enter');
  await expect(page.locator('#grade')).toHaveValue('2');
  await expect(page.locator('#validate-reading')).toBeInViewport();
  expect(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth)).toBe(true);
});

test('présentation épurée et proportions adaptées aux trois tailles d’écran', async ({ page }) => {
  await start(page, '5e');
  await grade(page, 8); await close(page);
  await thumb(page, 'x').press('Shift+ArrowRight');
  await thumb(page, 'y').press('Shift+ArrowRight');
  await thumb(page, 'z').press('Shift+ArrowLeft');
  await expect(page.locator('.question-meta')).toHaveText(/^Question \d+ \/ \d+\s*5e$/);
  await expect(page.locator('main')).not.toContainText('Les pointillés situent la rédaction sélectionnée');
  await expect(page.locator('main')).not.toContainText('Faites glisser pour tourner · touchez une bille pour lire');
  await expect(page.locator('.orb-caption')).toHaveText('1');
  await expect(page.locator('.orb')).toHaveAttribute('aria-label', 'Rédaction 1. Appuyer pour lire.');
  await expect(page.locator('#space marker, #space [marker-start], #space [marker-end]')).toHaveCount(0);

  for (const viewport of [{ width: 390, height: 844 }, { width: 820, height: 1180 }, { width: 1363, height: 936 }]) {
    await page.setViewportSize(viewport);
    await expect.poll(() => page.locator('#space').evaluate(el => el.style.getPropertyValue('--orb-size'))).toBeTruthy();
    const strip = await page.locator('.production-strip').boundingBox();
    const bars = await page.locator('#axes-panel').boundingBox();
    const scene = await page.locator('#space').boundingBox();
    expect(strip.y + strip.height).toBeLessThanOrEqual(Math.min(bars.y, scene.y) + 1);
    if (viewport.width < 900) {
      expect(bars.y + bars.height).toBeLessThanOrEqual(scene.y + 1);
      expect(bars.height).toBeLessThan(240);
      expect(scene.height).toBeGreaterThan(bars.height);
    } else {
      expect(bars.x + bars.width).toBeLessThan(scene.x);
      expect(Math.abs(bars.height - scene.height)).toBeLessThan(2);
    }
    // No rectangular surface between the scene and the shared page background.
    expect(await page.locator('#space').evaluate(el => {
      for (let node = el; node && !node.classList.contains('evaluation-layout'); node = node.parentElement) {
        const css = getComputedStyle(node);
        if (css.backgroundColor !== 'rgba(0, 0, 0, 0)' || css.backgroundImage !== 'none' || css.boxShadow !== 'none' || css.borderTopWidth !== '0px') return false;
      }
      return true;
    })).toBe(true);
    await expect.poll(async () => (await page.locator('.orb').boundingBox()).width).toBeLessThan(Math.min(scene.width, scene.height) * .25);
    const orb = await page.locator('.orb').boundingBox(), number = await page.locator('.orb-caption strong').boundingBox();
    expect(orb.width).toBeGreaterThanOrEqual(44);
    expect(Math.abs(number.x + number.width / 2 - orb.x - orb.width / 2)).toBeLessThan(1.5);
    expect(Math.abs(number.y + number.height / 2 - orb.y - orb.height / 2)).toBeLessThan(1.5);
    expect(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth)).toBe(true);
    expect(await coordinates(page.locator('.orb'))).toEqual([1, 1, -1]);
    await page.screenshot({ path: test.info().outputPath(`presentation-${viewport.width}.png`), fullPage: true });
  }
  await page.getByRole('button', { name: 'Relire la rédaction 1', exact: true }).click();
  await expect(page.locator('#reader-title')).toHaveText('Rédaction 1');
  await close(page);
  await page.locator('#next-production').click();
  await expect(page.locator('#reader-title')).toHaveText('Rédaction 2');
});

test('les portées indentées survivent au chargement, à la lecture et à la comparaison', async ({ page }, testInfo) => {
  test.setTimeout(60000);
  const bank = JSON.parse(fs.readFileSync(require('node:path').resolve(__dirname, '../../site/data/bank.json'), 'utf8'));
  const original = bank.questions.find(q => q.id === 'R17');
  const question = { ...original, productions: original.productions.filter(p => ['R17-6', 'R17-7'].includes(p.id)) };
  await page.route('**/data/bank.json*', route => route.fulfill({ json: { ...bank, questions: [question] } }));
  // This rendering regression isolates the indentation pair; the collection has its own integration tests.
  await page.route('**/api/sessions', route => route.fulfill({ json: { id: route.request().postDataJSON().id, bankVersion: bank.version, startedAt: new Date().toISOString(), questions: [question], revision: 0 } }));
  await page.route('**/api/sessions/**', route => route.fulfill({ json: { revision: route.request().postDataJSON()?.revision || 0, savedAt: new Date().toISOString(), completedAt: null } }));
  await start(page, 'Études supérieures');
  const seen = [];
  for (let i = 0; i < 2; i++) {
    const card = page.locator('reading-card');
    const pid = await card.getAttribute('production-id');
    seen.push(pid);
    const rich = card.locator('rich-text');
    await expect(rich).toHaveAttribute('content', question.productions.find(p => p.id === pid).content);
    if (pid === 'R17-7') {
      for (const width of [390, 1363]) {
        await page.setViewportSize({ width, height: 936 });
        const geometry = await rich.evaluate(el => {
          const lines = [...el.querySelectorAll('.proof-line')];
          return lines.map(line => ({
            indent: parseFloat(getComputedStyle(line).paddingLeft),
            width: line.clientWidth, scroll: line.scrollWidth,
            firstText: line.textContent.slice(0, 12)
          }));
        });
        expect(geometry).toHaveLength(8);
        expect(geometry[0].indent).toBe(0);
        expect(geometry[1].indent).toBeGreaterThan(0);
        expect(geometry[3].indent).toBeCloseTo(geometry[1].indent * 2, 0);
        expect(geometry[5].indent).toBe(geometry[1].indent);
        expect(geometry[6].indent).toBe(0);
        expect(geometry.every(line => line.scroll <= line.width + 1)).toBeTruthy();
        await page.screenshot({ path: testInfo.outputPath(`portees-${width}.png`) });
      }
      await expect(rich.locator('.katex-error')).toHaveCount(0);
    } else {
      await expect(rich.locator('.proof-line')).toHaveCount(0);
    }
    await grade(page, 8); await close(page);
    if (i === 0) await page.locator('#next-production').click();
  }
  expect(seen.sort()).toEqual(['R17-6', 'R17-7']);
  await page.getByRole('button', { name: 'Comparer', exact: true }).click();
  const comparison = page.locator('.comparison-columns rich-text');
  await expect(comparison).toHaveCount(2);
  await expect(page.locator('.comparison-columns .proof-line')).toHaveCount(8);
  const content = await comparison.evaluateAll(elements => elements.map(el => el.getAttribute('content')));
  expect(content.sort()).toEqual(question.productions.map(p => p.content).sort());
});
