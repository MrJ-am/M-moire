const { test, expect } = require('@playwright/test');
const { driver, start, close, thumb } = require('./gestures.cjs');

test('toutes les rédactions sont disponibles ; fermeture et passage restent libres', async ({ page }) => {
  const d = await driver(page); await start(page, d);
  const ids = await page.locator('#space').evaluate(e => JSON.parse(e.getAttribute('payload')).points.map(p => p.id));
  expect(ids.length).toBeGreaterThan(1);
  await close(page, d); // aucune note
  await expect(page.locator('.production-strip').getByRole('button')).toHaveCount(ids.length);
  await page.getByRole('button', { name: `Rédaction ${ids.length}`, exact: true }).click();
  await expect(page.locator('reading-card')).toHaveAttribute('production-id', ids.at(-1));
  await close(page, d);
  await thumb(page, 'x', ids.length).press('Shift+ArrowRight'); // axe sans note
  await page.locator('#next-production').click();
  await expect(page.getByRole('dialog', { name: 'Évaluations incomplètes' })).toBeVisible();
  await page.getByRole('button', { name: 'Rester', exact: true }).click();
  await expect(page.locator('.question-meta')).toContainText('Question 1');
  await page.locator('#next-production').click();
  await page.getByRole('button', { name: 'Passer quand même', exact: true }).click();
  await expect(page.locator('.question-meta')).toContainText('Question 2');
  const reponses = await page.evaluate(() => JSON.parse(localStorage.getItem('matheval-participation-v1')).snapshot.answers);
  expect(reponses[ids.at(-1)].note).toBeNull();
  expect(reponses[ids.at(-1)].evaluatedAxes).toEqual(['x']);
  expect(reponses[ids.at(-1)].coordinates.x).toBe(1);
});

test('menu, lecteur et scène restent bornés après chaque redimensionnement', async ({ page }) => {
  const d = await driver(page); await start(page, d); await close(page, d);
  for (const viewport of [{width:320,height:640},{width:390,height:844},{width:844,height:390},{width:820,height:1180},{width:1440,height:900}]) {
    await page.setViewportSize(viewport);
    await page.getByRole('button', { name:'Ouvrir le menu',exact:true }).click();
    const menu = page.getByRole('dialog', { name:'Menu',exact:true });
    await expect(menu).toBeInViewport({ratio:1});
    expect(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth + 1)).toBe(true);
    await page.getByRole('button', { name:'Ma participation et mes informations',exact:true }).click();
    await expect(page.getByRole('dialog', {name:'Ma participation'})).toBeInViewport({ratio:1});
    await page.getByRole('dialog', {name:'Ma participation'}).getByRole('button',{name:'Fermer',exact:true}).click();
    await page.getByRole('button', {name:'Rédaction 1',exact:true}).click();
    await expect(page.locator('#validate-reading')).toBeInViewport({ratio:1});
    await close(page,d);
    const scene = await page.locator('#space').boundingBox(), axes = await page.locator('#axes-panel').boundingBox();
    if (viewport.width < 900 && viewport.height > viewport.width) expect(scene.height).toBeGreaterThan(axes.height);
  }
});

test('chaque bille suit la caméra, même après reconnexion et redimensionnement', async ({ page }) => {
  const d=await driver(page); await start(page,d); await close(page,d);
  await page.locator('#space').evaluate(e => {
    const donnees=JSON.parse(e.getAttribute('payload'));
    donnees.points.forEach((p,i) => { p.point={x:i%2 ? 8:-8,y:i%3 ? 7:-7,z:i%2 ? -6:6}; });
    e.setAttribute('payload',JSON.stringify(donnees));
    const parent=e.parentNode, suivant=e.nextSibling;e.remove();parent.insertBefore(e,suivant);
  });
  const scene=page.locator('#space');
  await expect(scene.locator('.orb-layer')).toHaveCount(1);
  const lire=()=>scene.locator('.orb').evaluateAll(es=>es.map(e=>({id:e.dataset.id,x:parseFloat(e.style.left),y:parseFloat(e.style.top),coord:[e.dataset.x,e.dataset.y,e.dataset.z]})));
  const avant=await lire();
  for (let i=0;i<12;i++) await scene.press('ArrowRight');
  const apres=await lire();
  expect(apres.map(e=>e.coord)).toEqual(avant.map(e=>e.coord));
  for(let i=0;i<avant.length;i++) expect(Math.hypot(apres[i].x-avant[i].x,apres[i].y-avant[i].y)).toBeGreaterThan(3);
  for (let i=0;i<12;i++) await scene.press('ArrowLeft');
  const retour=await lire();
  retour.forEach((p,i)=>{expect(p.x).toBeCloseTo(avant[i].x,4);expect(p.y).toBeCloseTo(avant[i].y,4);});
  await page.setViewportSize({width:390,height:844});
  await expect.poll(()=>scene.evaluate(e=>[...e.querySelectorAll('.orb')].every(b=>{const p=b.getBoundingClientRect(),r=e.getBoundingClientRect();return p.left>=r.left&&p.right<=r.right&&p.top>=r.top&&p.bottom<=r.bottom;}))).toBe(true);
});
