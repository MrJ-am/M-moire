const { test, expect } = require('@playwright/test');

// Ces contrôles de présentation simulent uniquement le refus de connexion.
// collection-admin.spec.js conserve le parcours réel avec PostgreSQL et cookies.
test('la connexion ElmUI conserve les libellés, Entrée et le contrat HTTP', async ({ page }) => {
  const demandes = [];
  let refuser;
  await page.route('**/api/admin/me', route => route.fulfill({ status: 401, json: { error: 'Connexion requise.' } }));
  await page.route('**/api/admin/login', async route => {
    demandes.push(route.request());
    await new Promise(resolve => { refuser = resolve; });
    await route.fulfill({ status: 401, json: { error: 'Identifiants incorrects.' } });
  });
  await page.goto('admin/');
  const identifiant = page.getByLabel('Identifiant', { exact: true });
  const secret = page.getByLabel('Mot de passe', { exact: true });
  await identifiant.fill('enseignant');
  await secret.fill('secret-de-test-non-valide');
  await expect(secret).toHaveAttribute('autocomplete', 'current-password');
  await secret.press('Enter');
  await expect.poll(() => demandes.length).toBe(1);
  const attente = page.getByRole('button', { name: 'Connexion en cours…', exact: true });
  await expect(attente).toBeDisabled();
  await secret.press('Enter');
  expect(demandes).toHaveLength(1);
  expect(demandes[0].method()).toBe('POST');
  expect(demandes[0].postDataJSON()).toEqual({ username: 'enseignant', password: 'secret-de-test-non-valide' });
  expect(demandes[0].headers()['x-matheval-request']).toBe('1');
  refuser();
  await expect(page.getByText('Identifiants incorrects.', { exact: false })).toBeVisible();
  await expect(page.getByRole('button', { name: 'Se connecter', exact: true })).toBeEnabled();
  await expect(secret).toHaveValue('secret-de-test-non-valide');
});

for (const largeur of [320, 390, 768, 1363]) {
  test(`les écrans partagés restent utilisables à ${largeur} pixels`, async ({ page }) => {
    await page.setViewportSize({ width: largeur, height: 844 });
    await page.goto('./');
    await expect(page.getByRole('heading', { name: 'Quels niveaux avez-vous enseignés ?', exact: true })).toBeVisible();
    const souris = page.getByRole('checkbox', { name: '3e', exact: true });
    await souris.click();
    await expect(souris).toBeChecked();
    await souris.click();
    await expect(souris).not.toBeChecked();
    const niveau = page.getByRole('checkbox', { name: '5e', exact: true });
    await niveau.focus();
    await niveau.press('Space');
    await expect(niveau).toBeChecked();
    await niveau.press('Space');
    await expect(niveau).not.toBeChecked();
    for (const adresse of ['./', 'admin/']) {
      if (adresse === 'admin/') {
        await page.route('**/api/admin/me', route => route.fulfill({ status: 401, json: { error: 'Connexion requise.' } }));
        await page.goto(adresse);
        await expect(page.getByRole('button', { name: 'Se connecter', exact: true })).toBeVisible();
      }
      const signature = page.locator('.mrjam');
      await expect(signature).toHaveText('MrJ.am');
      expect(await signature.evaluate(element => {
        const plage = document.createRange(); plage.selectNodeContents(element);
        const selection = window.getSelection(); selection.removeAllRanges(); selection.addRange(plage);
        const texte = selection.toString(); selection.removeAllRanges(); return texte;
      })).toBe('MrJ.am');
      await expect.poll(() => page.locator('img').first().evaluate(image => image.complete && image.naturalWidth > 0)).toBe(true);
      expect(await page.evaluate(() => document.documentElement.scrollWidth <= window.innerWidth)).toBe(true);
      const bouton = page.getByRole('button', { name: adresse === './' ? 'Commencer' : 'Se connecter', exact: true });
      expect((await bouton.boundingBox()).height).toBeGreaterThanOrEqual(44);
      await page.screenshot({ path: test.info().outputPath(`${adresse === './' ? 'accueil' : 'connexion'}-${largeur}.png`), fullPage: true });
    }
  });
}
