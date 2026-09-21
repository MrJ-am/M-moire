const { test, expect } = require('@playwright/test');
const { randomUUID, randomBytes } = require('node:crypto');
const { start } = require('./gestures.cjs');
const { driver } = require('./gestures.cjs');

test.use({ reducedMotion: 'reduce' });

test('la reprise retrouve la note sauvegardée et une panne ne confirme jamais un enregistrement', async ({ page }) => {
  await page.setViewportSize({ width: 390, height: 844 });
  const d = await driver(page);
  await start(page, d);
  await page.locator('#grade').evaluate(el => { el.value = '2'; el.dispatchEvent(new Event('input', { bubbles: true })); });
  await expect(page.locator('.save-status')).toHaveAttribute('data-status', 'saved');
  const id = await page.locator('reading-card').getAttribute('production-id');
  await page.reload();
  await expect(page.locator('reading-card')).toHaveAttribute('production-id', id);
  await expect(page.locator('#grade')).toHaveValue('2');
  await page.route('**/api/sessions/**', route => route.request().method() === 'PUT' ? route.abort('failed') : route.continue());
  await page.locator('#grade').evaluate(el => { el.value = '1'; el.dispatchEvent(new Event('input', { bubbles: true })); });
  await expect(page.locator('.save-status')).toHaveAttribute('data-status', 'error');
  await page.reload();
  await expect(page.locator('#grade')).toHaveValue('1');
  await expect(page.locator('.save-status')).toHaveAttribute('data-status', 'error');
  await expect.poll(() => page.evaluate(() => document.querySelector('reading-card').getBoundingClientRect().bottom <= document.querySelector('.save-status').getBoundingClientRect().top)).toBe(true);
  await page.screenshot({ path: test.info().outputPath('reprise-reseau-mobile.png'), fullPage: true });
  await page.unroute('**/api/sessions/**');
  await page.getByRole('button', { name: 'Réessayer l’enregistrement' }).click();
  await expect(page.locator('.save-status')).toHaveAttribute('data-status', 'saved');
});

test('une confirmation perdue se retrouve au rechargement sans créer une seconde participation', async ({ page }) => {
  const d = await driver(page);
  await start(page, d);
  while (await page.getByRole('button', { name: 'Passer cette question', exact: true }).count()) {
    await page.locator('#grade').evaluate(el => { el.value = '1.5'; el.dispatchEvent(new Event('input', { bubbles: true })); });
    await page.locator('#validate-reading').click();
    await expect(page.locator('reading-card')).toHaveCount(0);
    await page.getByRole('button', { name: 'Passer cette question', exact: true }).click();
    await expect(page.locator('reading-card, .finish-panel-mrjam')).toBeVisible();
  }
  await expect(page.locator('context-help')).toHaveCount(0);
  const id = await page.evaluate(() => JSON.parse(localStorage.getItem('matheval-participation-v1')).id);
  await page.route('**/api/sessions/**', async route => {
    if (route.request().method() === 'PUT' && route.request().postDataJSON().final) {
      const response = await route.fetch();
      expect(response.status()).toBe(200);
      expect((await response.json()).completedAt).toBeTruthy();
      await route.abort('failed');
    } else await route.continue();
  });
  await page.getByRole('button', { name: 'Valider ma participation', exact: true }).click();
  await expect(page.locator('.save-status')).toHaveAttribute('data-status', 'submit-error');
  await expect(page.getByRole('button', { name: 'Revenir aux questions', exact: true })).toBeDisabled();
  await expect(page.getByText('Vos réponses ont bien été reçues.', { exact: false })).toHaveCount(0);
  await page.unroute('**/api/sessions/**');
  await page.reload();
  await expect(page.locator('.save-status')).toHaveAttribute('data-status', 'completed');
  await expect(page.getByText('Vos réponses ont bien été reçues.', { exact: false })).toBeVisible();
  expect(await page.evaluate(() => JSON.parse(localStorage.getItem('matheval-participation-v1')).id)).toBe(id);
});

test('administration : connexion, statistiques, corpus complet, réponses et déconnexion', async ({ page }) => {
  const origin = new URL(test.info().project.use.baseURL || 'http://127.0.0.1:4173').origin;
  const headers = { Origin: origin, 'X-Matheval-Request': '1' };
  const bank = await (await page.request.get('data/bank.json')).json();
  const id = randomUUID(), secret = randomBytes(32).toString('hex');
  const created = await page.request.post('api/sessions', { headers, data: { id, secret, bankVersion: bank.version, levels: ['5e'], seed: 12345 } });
  expect(created.status()).toBe(201);
  const session = await created.json(), question = session.questions[0], production = question.productions[0];
  const saved = await page.request.put('api/sessions/' + id, {
    headers: { ...headers, 'X-Session-Token': secret },
    data: {
      revision: 1, final: true,
      snapshot: {
        answers: { [production.id]: { note: 0, initialNote: 1, coordinates: { x: 0, y: 0, z: 0 }, evaluatedAxes: ['x'] } },
        skippedQuestions: [],
        progress: { mode: 'finished', index: 0, selected: production.id, exposed: { [question.id]: 1 }, reader: false, tour: -1 }
      },
      events: []
    }
  });
  expect(saved.status()).toBe(200);
  const creds = { username: 'admin-browser-tests', password: 'mot-de-passe-des-tests-navigateur' };
  await page.request.post('api/admin/setup', { headers, data: { ...creds, token: 'a'.repeat(64) } });
  await page.goto('admin/');
  if (await page.getByRole('button', { name: 'Se connecter' }).count()) {
    await page.getByLabel('Identifiant', { exact: true }).fill(creds.username);
    await page.getByLabel('Mot de passe', { exact: true }).fill(creds.password);
    await page.getByRole('button', { name: 'Se connecter' }).click();
  }
  await expect(page.getByRole('heading', { name: 'Vue d’ensemble' })).toBeVisible();
  await expect(page.getByText('Participations commencées', { exact: true })).toBeVisible();
  await page.screenshot({ path: test.info().outputPath('tableau-de-bord-admin.png'), fullPage: true });
  await page.getByRole('button', { name: 'Énoncés et rédactions', exact: true }).click();
  await expect(page.locator('.question-card')).toHaveCount(20);
  await page.getByRole('button', { name: 'Consulter l’énoncé et les résultats →' }).first().click();
  await expect(page.getByRole('heading', { name: 'Réponse de référence', exact: true })).toBeVisible();
  await expect(page.getByRole('heading', { name: 'Analyse de conception', exact: true }).first()).toBeVisible();
  await expect(page.locator('.katex').first()).toBeVisible();
  await page.getByRole('button', { name: 'Participations', exact: true }).click();
  await expect(page.locator('table')).toBeVisible();
  await page.getByRole('button', { name: id.slice(0, 8), exact: true }).click();
  await expect(page.getByRole('heading', { name: /Participation/ }).first()).toBeVisible();
  const answer = page.locator('article.production').filter({ has: page.getByRole('heading', { name: production.id, exact: true }) });
  await expect(answer.locator('tbody td')).toHaveText(['1', '0', '0', 'Non évalué', 'Non évalué']);
  await page.screenshot({ path: test.info().outputPath('participation-admin.png'), fullPage: true });
  await page.getByRole('button', { name: 'Déconnexion', exact: true }).click();
  await expect(page.getByRole('button', { name: 'Se connecter' })).toBeVisible();
  expect((await page.request.get('api/admin/statistics')).status()).toBe(401);
});
