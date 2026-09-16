const { test, expect } = require('@playwright/test');
const { start } = require('./gestures.cjs');
const { driver } = require('./gestures.cjs');

test.use({ reducedMotion: 'reduce' });

test('la reprise retrouve la note sauvegardée et une panne ne confirme jamais un enregistrement', async ({ page }) => {
  const d = await driver(page);
  await start(page, d);
  await page.locator('#grade').fill('2');
  await page.locator('#grade').dispatchEvent('input');
  await expect(page.locator('.save-status')).toHaveAttribute('data-status', 'saved');
  const id = await page.locator('reading-card').getAttribute('production-id');
  await page.reload();
  await expect(page.locator('reading-card')).toHaveAttribute('production-id', id);
  await expect(page.locator('#grade')).toHaveValue('2');
  await page.route('**/api/sessions/**', route => route.request().method() === 'PUT' ? route.abort('failed') : route.continue());
  await page.locator('#grade').fill('1');
  await page.locator('#grade').dispatchEvent('input');
  await expect(page.locator('.save-status')).toHaveAttribute('data-status', 'error');
  await page.reload();
  await expect(page.locator('#grade')).toHaveValue('1');
  await page.unroute('**/api/sessions/**');
  await page.getByRole('button', { name: 'Réessayer l’enregistrement' }).click();
  await expect(page.locator('.save-status')).toHaveAttribute('data-status', 'saved');
});

test('administration : connexion, statistiques, corpus complet, réponses et déconnexion', async ({ page }) => {
  const origin = new URL(test.info().project.use.baseURL || 'http://127.0.0.1:4173').origin;
  const headers = { Origin: origin, 'X-Matheval-Request': '1' };
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
  await page.getByRole('button', { name: 'Énoncés et rédactions', exact: true }).click();
  await expect(page.locator('.question-card')).toHaveCount(20);
  await page.getByRole('button', { name: 'Consulter l’énoncé et les résultats →' }).first().click();
  await expect(page.getByRole('heading', { name: 'Réponse de référence', exact: true })).toBeVisible();
  await expect(page.getByRole('heading', { name: 'Analyse de conception', exact: true }).first()).toBeVisible();
  await expect(page.locator('.katex').first()).toBeVisible();
  await page.getByRole('button', { name: 'Participations', exact: true }).click();
  await expect(page.locator('table')).toBeVisible();
  await page.getByRole('button', { name: 'Déconnexion', exact: true }).click();
  await expect(page.getByRole('button', { name: 'Se connecter' })).toBeVisible();
  expect((await page.request.get('api/admin/statistics')).status()).toBe(401);
});
