const { test, expect } = require('@playwright/test');

async function centerOf(locator) {
  const box = await locator.boundingBox();
  if (!box) throw new Error('carte introuvable');
  return {
    x: box.x + box.width / 2,
    y: box.y + box.height / 2,
    width: box.width,
    height: box.height
  };
}

function expectCentersClose(a, b, tolerance = 1.5) {
  expect(Math.abs(a.x - b.x)).toBeLessThanOrEqual(tolerance);
  expect(Math.abs(a.y - b.y)).toBeLessThanOrEqual(tolerance);
}

test('drag de carte conserve 4 cartes uniques et ne declenche pas le zoom', async ({ page }) => {
  await page.goto('prototype.html');
  await page.waitForTimeout(200);

  const cardA = page.getByTestId('card-A');
  await expect(cardA).toBeVisible();
  await expect(page.locator('[data-testid^="card-"]')).toHaveCount(4);

  const box = await cardA.boundingBox();
  if (!box) throw new Error('card-A introuvable');

  await page.mouse.move(box.x + box.width / 2, box.y + box.height / 2);
  await page.mouse.down();
  await page.mouse.move(box.x + box.width / 2 + 180, box.y + box.height / 2 + 120, { steps: 12 });
  await page.mouse.up();

  await page.waitForTimeout(160);
  await expect(page.locator('[data-testid^="card-"]')).toHaveCount(4);
  await expect(cardA).toHaveAttribute('data-state', 'mini');
});

test('zoom: meme noeud DOM, centre anime vers le viewport, plein ecran et fermeture par la carte', async ({ page }) => {
  await page.goto('prototype.html');
  await page.waitForTimeout(220);

  const cardB = page.getByTestId('card-B');
  await expect(page.locator('[data-testid^="card-"]:not([data-testid^="card-anchor-"])')).toHaveCount(4);

  await page.evaluate(() => {
    window.__originalCardB = document.querySelector('[data-testid="card-B"]');
  });

  const before = await centerOf(cardB);
  const viewport = page.viewportSize();
  if (!viewport) throw new Error('viewport introuvable');
  const viewportCenter = { x: viewport.width / 2, y: viewport.height / 2 };

  const initialDistance = Math.hypot(before.x - viewportCenter.x, before.y - viewportCenter.y);

  await cardB.click();
  await expect(cardB).toHaveAttribute('data-state', 'expanded');

  await page.waitForTimeout(80);
  const duringOpen = await centerOf(cardB);
  const duringDistance = Math.hypot(duringOpen.x - viewportCenter.x, duringOpen.y - viewportCenter.y);
  expect(duringDistance).toBeLessThan(initialDistance);

  await page.waitForTimeout(220);
  const opened = await centerOf(cardB);
  expect(Math.abs(opened.x - viewportCenter.x)).toBeLessThanOrEqual(2);
  expect(Math.abs(opened.y - viewportCenter.y)).toBeLessThanOrEqual(2);
  expect(opened.width).toBeGreaterThanOrEqual(viewport.width - 28);
  expect(opened.height).toBeGreaterThanOrEqual(viewport.height - 28);

  expect(await page.evaluate(() =>
    window.__originalCardB === document.querySelector('[data-testid="card-B"]')
  )).toBe(true);

  const overflowY = await cardB.evaluate(el => getComputedStyle(el).overflowY);
  expect(['auto', 'scroll']).toContain(overflowY);

  await cardB.click({ position: { x: 24, y: 24 } });
  await expect(cardB).toHaveAttribute('data-state', 'mini');

  await page.waitForTimeout(80);
  const duringClose = await centerOf(cardB);
  const closeDistanceToStart = Math.hypot(duringClose.x - before.x, duringClose.y - before.y);
  const openedDistanceToStart = Math.hypot(opened.x - before.x, opened.y - before.y);
  expect(closeDistanceToStart).toBeLessThan(openedDistanceToStart);

  await page.waitForTimeout(220);
  const closed = await centerOf(cardB);
  expectCentersClose(before, closed, 2);
  expect(Math.abs(closed.width - before.width)).toBeLessThanOrEqual(2);
  expect(Math.abs(closed.height - before.height)).toBeLessThanOrEqual(2);

  expect(await page.evaluate(() =>
    window.__originalCardB === document.querySelector('[data-testid="card-B"]')
  )).toBe(true);
});

test('une seule carte peut etre ouverte globalement', async ({ page }) => {
  await page.goto('prototype.html');
  await page.waitForTimeout(220);

  const cardA = page.getByTestId('card-A');
  const cardB = page.getByTestId('card-B');

  await cardA.click();
  await expect(cardA).toHaveAttribute('data-state', 'expanded');
  await expect(page.locator('[data-state="expanded"]')).toHaveCount(1);

  await cardB.evaluate(el => el.click());
  await expect(cardA).toHaveAttribute('data-state', 'mini');
  await expect(cardB).toHaveAttribute('data-state', 'expanded');
  await expect(page.locator('[data-state="expanded"]')).toHaveCount(1);
});

test.describe('mobile emulation', () => {
  test.use({
    viewport: { width: 393, height: 851 },
    hasTouch: true
  });

  test('mobile: tap ouvre presque plein ecran et retap sur la carte referme', async ({ page }) => {
    await page.goto('prototype.html');
    await page.waitForTimeout(220);

    const cardC = page.getByTestId('card-C');
    await expect(cardC).toBeVisible();

    await page.evaluate(() => {
      window.__originalCardC = document.querySelector('[data-testid="card-C"]');
    });

    await cardC.tap();
    await expect(cardC).toHaveAttribute('data-state', 'expanded');
    await page.waitForTimeout(260);

    const opened = await centerOf(cardC);
    expect(opened.width).toBeGreaterThanOrEqual(365);
    expect(opened.height).toBeGreaterThanOrEqual(823);

    expect(await page.evaluate(() =>
      window.__originalCardC === document.querySelector('[data-testid="card-C"]')
    )).toBe(true);

    await cardC.tap({ position: { x: 20, y: 20 } });
    await expect(cardC).toHaveAttribute('data-state', 'mini');
  });

  test('mobile: une carte ouverte reste scrollable si son contenu devient long', async ({ page }) => {
    await page.goto('prototype.html');
    await page.waitForTimeout(220);

    const cardD = page.getByTestId('card-D');
    await cardD.tap();
    await page.waitForTimeout(260);

    await cardD.evaluate(el => {
      const richTexts = el.querySelectorAll('rich-text');
      const target = richTexts[richTexts.length - 1];
      target.setAttribute(
        'content',
        Array.from({ length: 80 }, (_, i) => 'Ligne ' + (i + 1) + ' : contenu de test.').join('\n\n')
      );
    });

    const scrollState = await cardD.evaluate(el => {
      el.scrollTop = Math.max(1, el.scrollHeight - el.clientHeight);
      return {
        scrollHeight: el.scrollHeight,
        clientHeight: el.clientHeight,
        scrollTop: el.scrollTop,
        overflowY: getComputedStyle(el).overflowY
      };
    });

    expect(scrollState.scrollHeight).toBeGreaterThan(scrollState.clientHeight);
    expect(scrollState.scrollTop).toBeGreaterThan(0);
    expect(['auto', 'scroll']).toContain(scrollState.overflowY);
  });
});

test('le plateau occupe l espace restant et conserve les positions relatives apres rotation', async ({ page }) => {
  await page.setViewportSize({ width: 851, height: 393 });
  await page.goto('prototype.html');
  await page.waitForTimeout(260);

  async function geometry() {
    const header = await page.getByTestId('header').boundingBox();
    const board = await page.getByTestId('board').boundingBox();
    const card = await centerOf(page.getByTestId('card-A'));
    if (!header || !board) throw new Error('geometrie introuvable');

    return {
      header,
      board,
      normalizedCard: {
        x: (card.x - board.x) / board.width,
        y: (card.y - board.y) / board.height
      }
    };
  }

  const landscape = await geometry();
  expect(landscape.board.y).toBeGreaterThanOrEqual(landscape.header.y + landscape.header.height + 8);
  expect(Math.abs((landscape.board.y + landscape.board.height) - (393 - 12))).toBeLessThanOrEqual(2);
  expect(Math.abs(landscape.normalizedCard.x - 0.18)).toBeLessThanOrEqual(0.01);
  expect(Math.abs(landscape.normalizedCard.y - 0.14)).toBeLessThanOrEqual(0.02);

  await page.setViewportSize({ width: 393, height: 851 });
  await page.waitForTimeout(160);

  const portrait = await geometry();
  expect(portrait.board.y).toBeGreaterThanOrEqual(portrait.header.y + portrait.header.height + 8);
  expect(Math.abs((portrait.board.y + portrait.board.height) - (851 - 12))).toBeLessThanOrEqual(2);
  expect(Math.abs(portrait.normalizedCard.x - 0.18)).toBeLessThanOrEqual(0.01);
  expect(Math.abs(portrait.normalizedCard.y - 0.14)).toBeLessThanOrEqual(0.02);
});


test('contenu externe Markdown + LaTeX charge et rendu par KaTeX', async ({ page, request }) => {
  const response = await request.get('/data/exercise-001.json');
  expect(response.ok()).toBe(true);

  const data = await response.json();
  expect(data.productions).toHaveLength(4);
  expect(data.productions[1].content).toContain('\\frac');
  expect(data.productions[3].content).toContain('$$');

  await page.goto('prototype.html');
  await expect(page.getByTestId('card-A')).toBeVisible();
  await expect(page.locator('rich-text')).toHaveCount(9);
  await expect(page.locator('.katex').first()).toBeVisible();

  const renderedText = await page.getByTestId('card-B').innerText();
  expect(renderedText).toContain('Copie B');
  expect(renderedText).toContain('On part de');
});
