const {test,expect}=require('@playwright/test');
const {driver,center,drag,thumb}=require('./gestures.cjs');

for (const viewport of [{width:320,height:568},{width:390,height:844},{width:844,height:390},{width:1363,height:936}]) {
  for (const reducedMotion of ['reduce','no-preference']) {
    test.describe(`espace commun ${viewport.width} ${reducedMotion}`,()=>{
      test.use({viewport,reducedMotion});
      test('géométrie, geste relatif, annulation et caméra sans mutation',async({page})=>{
        const erreurs=[];page.on('pageerror',e=>erreurs.push(e.message));
        await page.addInitScript(()=>{
          localStorage.setItem('regards-help-v1',JSON.stringify({enabled:false,introSeen:true,ratingSeen:true,axesSeen:true}));
          window.framesEspace=0;const original=requestAnimationFrame;
          window.requestAnimationFrame=f=>{framesEspace++;return original(f);};
          document.addEventListener('gotpointercapture',e=>window.pointeurEspace=e.pointerId,true);
        });
        await page.goto('./');
        await page.getByRole('checkbox',{name:'5e',exact:true}).click();
        await page.getByRole('button',{name:'Commencer',exact:true}).click();
        await expect(page.locator('#reading-card')).toBeVisible();
        await page.locator('#validate-reading').click();
        const scene=page.locator('#space'), billes=scene.locator('[data-mrjam-bille]');
        expect(await billes.count()).toBeGreaterThan(1);
        const x=thumb(page,'x');
        await expect(x).toHaveAttribute('aria-valuetext','À placer');
        await x.scrollIntoViewIfNeeded();
        const d=await driver(page),depart=await center(x);
        await d.down({x:depart.x+7,y:depart.y});
        await expect(x).toHaveAttribute('data-value','0');
        await d.move({x:depart.x+35,y:depart.y+24});
        await expect.poll(async()=>Number(await x.getAttribute('data-value'))).toBeGreaterThan(0);
        expect(Math.abs((await center(x)).y-depart.y)).toBeLessThan(1);
        await page.locator('#axis-x [data-mrjam-axe]').evaluate(e=>e.dispatchEvent(new PointerEvent('pointercancel',{pointerId:window.pointeurEspace,bubbles:true})));
        await expect(x).toHaveAttribute('data-value','0');
        await expect(x).toHaveAttribute('aria-valuetext','À placer');
        await page.mouse.up();
        // Une ouverture clavier pendant une capture annule l'aperçu et libère
        // le pointeur. La reprise suivante doit fonctionner, sans double effet.
        await dragDebut();
        await x.press('Enter');
        await expect(page.locator('#reading-card')).toBeVisible();
        await page.mouse.up();
        await page.locator('#validate-reading').click();
        await expect(x).toHaveAttribute('data-value','0');
        await expect(x).toHaveAttribute('aria-valuetext','À placer');
        async function dragDebut() {
          const p=await center(x);await d.down(p);await d.move({x:p.x+30,y:p.y});
          await expect.poll(async()=>Number(await x.getAttribute('data-value'))).toBeGreaterThan(0);
        }
        await drag(d,x,20);
        await expect.poll(async()=>Number(await x.getAttribute('data-value'))).toBeGreaterThan(0);
        await x.press('Home');await expect(x).toHaveAttribute('data-value','-10');
        await expect(x).toHaveAttribute('aria-valuetext','Vers Confus');
        await x.press('End');await expect(x).toHaveAttribute('data-value','10');
        await x.press('Shift+ArrowLeft');await expect(x).toHaveAttribute('data-value','9');
        await x.press('ArrowLeft');await expect(x).toHaveAttribute('data-value','8.9');
        const id=await x.getAttribute('data-mrjam-poignee');
        const lire=()=>billes.evaluateAll(es=>es.map(e=>{const r=e.getBoundingClientRect();return{id:e.dataset.mrjamBille,x:r.x+r.width/2,y:r.y+r.height/2,coord:[e.dataset.x,e.dataset.y,e.dataset.z]};}).sort((a,b)=>a.id.localeCompare(b.id)));
        const avant=await lire();
        expect(avant.find(e=>e.id===id).coord).toEqual(['8.9','0','0']);
        await scene.scrollIntoViewIfNeeded();
        const origine=await lire();
        await scene.focus();for(let i=0;i<12;i++)await scene.press('ArrowRight');
        const apres=await lire();expect(apres.map(e=>e.coord)).toEqual(origine.map(e=>e.coord));
        const bougee=apres.find(e=>e.id===id),initiale=origine.find(e=>e.id===id);
        expect(Math.hypot(bougee.x-initiale.x,bougee.y-initiale.y)).toBeGreaterThan(3);
        for(let i=0;i<12;i++)await scene.press('ArrowLeft');
        await expect.poll(async()=>{const retour=await lire();return retour.every((p,i)=>Math.abs(p.x-origine[i].x)<.001 && Math.abs(p.y-origine[i].y)<.001);}).toBe(true);
        const retour=await lire();retour.forEach((p,i)=>{expect(p.x).toBeCloseTo(origine[i].x,3);expect(p.y).toBeCloseTo(origine[i].y,3);});
        const boite=await scene.boundingBox();
        for(const b of await billes.all()){
          const r=await b.boundingBox();expect(r.x).toBeGreaterThanOrEqual(boite.x-1);expect(r.x+r.width).toBeLessThanOrEqual(boite.x+boite.width+1);
          expect(r.y).toBeGreaterThanOrEqual(boite.y-1);expect(r.y+r.height).toBeLessThanOrEqual(boite.y+boite.height+1);
        }
        await scene.locator(`[data-mrjam-bille="${id}"]`).press('Enter');
        await expect(page.locator('#reader-title')).toHaveText('Rédaction 1');
        await page.keyboard.press('Escape');await expect(page.locator('#reading-card')).toHaveCount(0);
        await expect(x).toHaveAttribute('data-value','8.9');
        await expect(page.locator('[data-testid="save-status"]')).toContainText('Réponses enregistrées');
        await page.waitForTimeout(400);const frames=await page.evaluate(()=>framesEspace);await page.waitForTimeout(200);
        expect(await page.evaluate(()=>framesEspace)).toBe(frames);
        expect(await page.evaluate(()=>document.documentElement.scrollWidth)).toBeLessThanOrEqual(viewport.width+1);
        expect(erreurs).toEqual([]);
      });
    });
  }
}
