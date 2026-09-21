const { test, expect } = require('@playwright/test');
const { start, driver, close } = require('./gestures.cjs');

test.use({ reducedMotion: 'reduce' });

test('activation ElmUI : confirmation, secret hors URL et requête protégée', async ({ page }) => {
  const demandes = [];
  await page.route('**/api/admin/me', route => route.fulfill({ status: 401, json: { error: 'Connexion requise.' } }));
  await page.route('**/api/admin/setup', route => {
    demandes.push(route.request());
    return route.fulfill({ status: 400, json: { error: 'Jeton de contrôle refusé.' } });
  });
  await page.goto('admin/#activation=' + 'b'.repeat(64));
  await expect(page.getByRole('heading', { name: 'Bienvenue dans votre administration.' })).toBeVisible();
  expect(new URL(page.url()).hash).toBe('');
  const secret = page.getByLabel('Mot de passe', { exact: true });
  await expect(secret).toHaveAttribute('autocomplete', 'new-password');
  await page.getByLabel('Identifiant', { exact: true }).fill('compte-controle');
  await secret.fill('secret-fictif-de-controle');
  await page.getByLabel('Confirmer le mot de passe', { exact: true }).fill('confirmation-differente');
  await page.getByRole('button', { name: 'Créer mon accès', exact: true }).click();
  await expect(page.getByText('Les mots de passe ne correspondent pas.', { exact: false })).toBeVisible();
  expect(demandes).toHaveLength(0);
  await page.getByLabel('Confirmer le mot de passe', { exact: true }).fill('secret-fictif-de-controle');
  await secret.press('Enter');
  await expect(page.getByText('Jeton de contrôle refusé.', { exact: false })).toBeVisible();
  expect(demandes).toHaveLength(1);
  expect(demandes[0].postDataJSON()).toEqual({ username: 'compte-controle', password: 'secret-fictif-de-controle', token: 'b'.repeat(64) });
  expect(demandes[0].headers()['x-matheval-request']).toBe('1');
});

test('les dialogues isolent le fond, gardent le focus et le restituent', async ({ page }) => {
  const d = await driver(page);
  await start(page, d);
  await expect.poll(() => page.locator('#axes-panel').evaluate(el => Boolean(el.closest('[inert]')))).toBe(true);
  await page.locator('#grade').evaluate(el => { el.value = '2'; el.dispatchEvent(new Event('input', { bubbles: true })); });
  await page.locator('#validate-reading').focus();
  for (let i = 0; i < 7; i++) {
    await page.keyboard.press('Tab');
    expect(await page.evaluate(() => document.querySelector('reading-card').contains(document.activeElement))).toBe(true);
  }
  await close(page, d);
  await expect.poll(() => page.locator('#axes-panel').evaluate(el => Boolean(el.closest('[inert]')))).toBe(false);
  await page.locator('#next-production').click();
  await page.locator('#grade').evaluate(el => { el.value = '1'; el.dispatchEvent(new Event('input', { bubbles: true })); });
  await close(page, d);
  const comparer = page.getByRole('button', { name: 'Comparer', exact: true });
  await comparer.click();
  const dialogue = page.getByRole('dialog', { name: 'Comparer les rédactions', exact: true });
  await expect(dialogue).toBeVisible();
  for (let i = 0; i < 6; i++) {
    await page.keyboard.press(i % 2 ? 'Shift+Tab' : 'Tab');
    expect(await dialogue.evaluate(el => el.contains(document.activeElement))).toBe(true);
  }
  await page.keyboard.press('Escape');
  await expect(dialogue).toHaveCount(0);
  await expect(comparer).toBeFocused();
});

test('la signature utilise les polices autorisées et reste sélectionnable', async ({ page }) => {
  for (const adresse of ['./', 'admin/']) {
    await page.goto(adresse);
    const signature = page.locator('.mrjam');
    await expect(signature).toHaveText('MrJ.am');
    await page.evaluate(() => document.fonts.ready);
    expect(await signature.evaluate(el => getComputedStyle(el).fontFamily)).toContain('MrJamSignature');
    expect(await page.evaluate(() => document.fonts.check('28px MrJamSignature'))).toBe(true);
    const response = await page.request.get(new URL('assets/mrjam/MrJamSignature.woff2', page.url()).href);
    expect(response.status()).toBe(200);
    expect((await response.body()).length).toBe(7396);
  }
});
