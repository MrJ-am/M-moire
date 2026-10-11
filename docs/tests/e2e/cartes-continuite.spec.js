const { test, expect } = require('@playwright/test');

async function auRepos(page) {
  await page.waitForTimeout(350);
  const avant = await page.evaluate(() => window.compteurImages);
  await page.waitForTimeout(200);
  expect(await page.evaluate(() => window.compteurImages)).toBe(avant);
}

for (const largeur of [390, 1280]) {
  for (const reduite of [false, true]) {
    test(`cartes communes ${largeur} / réduction ${reduite}`, async ({ page }) => {
      await page.setViewportSize({ width: largeur, height: 900 });
      await page.emulateMedia({ reducedMotion: reduite ? 'reduce' : 'no-preference' });
      await page.addInitScript(() => {
        window.compteurImages = 0;
        const demander = window.requestAnimationFrame;
        window.requestAnimationFrame = fonction => demander.call(window, temps => {
          window.compteurImages += 1;
          fonction(temps);
        });
      });
      for (const [adresse, repere] of [['prototype.html', 'card-B'], ['test.html', 'card-demo']]) {
        await page.goto(adresse);
        const carte = page.getByTestId(repere);
        await expect(carte).toBeVisible();
        await auRepos(page);
        await carte.evaluate(e => window.carteOriginale = e);
        await carte.focus();
        await carte.press('Enter');
        await expect(carte).toHaveAttribute('data-state', 'expanded');
        await expect(carte).toBeFocused();
        // Les intentions successives n'attendent aucune fin décorative.
        await carte.press('Escape');
        await expect(carte).toHaveAttribute('data-state', 'mini');
        await carte.press('Space');
        await expect(carte).toHaveAttribute('data-state', 'expanded');
        await expect(carte).toBeFocused();
        expect(await carte.evaluate(e => e === window.carteOriginale)).toBe(true);
        await auRepos(page);
        await carte.press('Enter');
        await expect(carte).toHaveAttribute('data-state', 'mini');
        await auRepos(page);
        if (!reduite) {
          await carte.press('Enter');
          await page.waitForTimeout(40);
          await page.emulateMedia({ reducedMotion: 'reduce' });
          await expect(carte).toHaveAttribute('data-state', 'expanded');
          await auRepos(page);
          await expect(carte).toBeFocused();
          await carte.press('Escape');
          await expect(carte).toHaveAttribute('data-state', 'mini');
          await auRepos(page);
          await page.emulateMedia({ reducedMotion: 'no-preference' });
        }
        expect(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth)).toBe(true);
      }
    });
  }
}
