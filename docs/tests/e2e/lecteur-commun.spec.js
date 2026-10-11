const { test, expect } = require('@playwright/test');

for (const format of [{ width: 390, height: 844 }, { width: 844, height: 390 }]) {
  for (const reducedMotion of ['no-preference', 'reduce']) {
    test.describe(`lecteur commun ${format.width} ${reducedMotion}`, () => {
      test.use({ viewport: format, reducedMotion });
      test('note facultative, fermeture immédiate et redémarrage du document', async ({ page }) => {
        await page.addInitScript(() => {
          localStorage.setItem('regards-help-v1', JSON.stringify({ enabled: false, introSeen: true, ratingSeen: true, axesSeen: true }));
          window.framesLecture = 0;
          const original = requestAnimationFrame;
          window.requestAnimationFrame = f => { framesLecture++; return original(f); };
        });
        await page.goto('./');
        await page.getByRole('checkbox', { name: '3e', exact: true }).click();
        await page.getByRole('button', { name: 'Commencer', exact: true }).click();
        const lecteur = page.locator('#reading-card');
        await expect(lecteur).toBeVisible();
        await expect(page.locator('#grade')).toHaveAttribute('aria-valuetext', 'Non noté');
        const document = lecteur.locator('[data-mrjam-document]');
        const source = await document.getAttribute('data-mrjam-document');
        await expect(document.locator('script, img')).toHaveCount(0);
        await page.locator('#validate-reading').click();
        await expect(lecteur).toHaveCount(0);
        await page.getByRole('button', { name: 'Rédaction 1', exact: true }).click();
        await expect(lecteur).toBeVisible();
        await expect(document).toHaveAttribute('data-mrjam-document', source);
        await expect(page.locator('#grade')).toHaveAttribute('aria-valuetext', 'Non noté');
        await page.locator('#grade').focus();
        await page.locator('#grade').press('Home');
        await expect(page.locator('#grade')).toHaveValue('0');
        await expect(page.locator('#grade')).toHaveAttribute('aria-valuetext', '0 sur 3');
        for (let i = 0; i < 6; i++) {
          await page.keyboard.press('Tab');
          expect(await lecteur.evaluate(e => e.contains(window.document.activeElement))).toBe(true);
        }
        await page.waitForTimeout(350);
        const boite = await lecteur.boundingBox();
        expect(boite.x).toBeGreaterThanOrEqual(0);
        expect(boite.y).toBeGreaterThanOrEqual(0);
        expect(boite.x + boite.width).toBeLessThanOrEqual(format.width + 1);
        expect(boite.y + boite.height).toBeLessThanOrEqual(format.height + 1);
        const question = await page.locator('#question-panel').boundingBox();
        expect(boite.y).toBeCloseTo(Math.ceil(Math.min(format.height * .32, Math.max(12, question.y + question.height + 14))), 0);
        await page.getByRole('button', { name: 'Aide sur la fiche de rédaction', exact: true }).click();
        const aide = page.locator('[data-testid="context-help"]');
        await expect(aide).toContainText('dans l’ordre de votre choix');
        const boiteAide = await aide.boundingBox();
        expect(boiteAide.y).toBeGreaterThanOrEqual(0);
        expect(boiteAide.y + boiteAide.height).toBeLessThanOrEqual(format.height + 1);
        await aide.getByRole('button', { name: 'Fermer', exact: true }).click();
        await expect(aide).toHaveCount(0);
        const frames = await page.evaluate(() => framesLecture);
        await page.waitForTimeout(200);
        expect(await page.evaluate(() => framesLecture)).toBe(frames);
        await page.keyboard.press('Escape');
        await expect(lecteur).toHaveCount(0);
        await page.getByRole('button', { name: 'Rédaction 1', exact: true }).click();
        await expect(lecteur).toBeVisible();
        await expect(page.locator('#grade')).toHaveValue('0');
        await expect.poll(() => page.locator('#reader-content').evaluate(e => e.scrollTop)).toBe(0);
      });
    });
  }
}
