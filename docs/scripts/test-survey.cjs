'use strict';
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
(async () => {
  const { dragValue, layoutThumbs } = await import('../site/slider-layout.js');
  const { placerBilles } = await import('../site/space-layout.js');
  for (const [largeur,hauteur] of [[264,350],[366,464],[820,650]]) {
    for (const [x,y] of [[largeur/2,hauteur/2],[0,0],[largeur,hauteur]]) {
      const points=Array.from({length:6},(_,id)=>({id,x,y}));
      const copie=JSON.stringify(points), positions=placerBilles(points,largeur,hauteur,49);
      assert.equal(JSON.stringify(points),copie,'La séparation préserve les coordonnées');
      for (const [i,p] of positions.entries()) {
        assert.ok(p.x>=30&&p.y>=30&&p.x<=largeur-30&&p.y<=hauteur-30,'Bille dans la scène');
        for(const q of positions.slice(i+1)) assert.ok(Math.hypot(p.x-q.x,p.y-q.y)>54,'Six billes distinctes, même au bord');
      }
    }
  }
  const { prepareSession, axes } = await import('../site/session.js');
  const bank = JSON.parse(fs.readFileSync(path.join(__dirname, '../site/data/bank.json')));
  const levels = [...new Set(bank.questions.map(q => q.level))];
  const first = prepareSession(bank, levels, 1234);
  assert.deepEqual(first, prepareSession(bank, levels, 1234), 'The exported seed must reproduce both orders');
  assert.notDeepEqual(first, prepareSession(bank, levels, 5678));
  for (const q of first) assert.deepEqual([...q.productions.map(p => p.id)].sort(), bank.questions.find(b => b.id === q.id).productions.map(p => p.id).sort());
  for (const level of levels) assert.ok(prepareSession(bank, [level], 7).every(q => q.level === level));
  const seen = new Set(first.slice(0, 4).map(q => q.id));
  assert.ok(prepareSession(bank, levels, 42, seen).every(q => !seen.has(q.id)));
  const synthetic = { questions: [...bank.questions, { ...bank.questions[0], id: 'duplicate-family' }] };
  const sample = prepareSession(synthetic, levels, 12);
  assert.equal(new Set(sample.map(q => q.family)).size, sample.length);
  assert.equal(prepareSession(bank, [], 123).length, 0);
  assert.deepEqual(Object.keys(axes), ['x', 'y', 'z']);
  assert.ok(Object.values(axes).every(a => a.min === -10 && a.max === 10));
  assert.equal(dragValue(1.5, 0, 200, 0, 3, .25), 1.5, 'A grab must not jump');
  assert.equal(dragValue(1.5, 50, 200, 0, 3, .25), 2.25);
  assert.equal(dragValue(1.5, -500, 200, 0, 3, .25), 0);
  for (const width of [132, 220, 300, 500]) {
    for (const values of [[0,0,0,0,0,0], [-10,-10,-9.9,9.9,10,10], [-5,-4.9,0,.1,5,5.1]]) {
      const points = values.map((value, number) => ({ id: String(number), number, value }));
      const before = JSON.stringify(points), layout = layoutThumbs(points, width, '1');
      assert.equal(JSON.stringify(points), before, 'Fanning must not alter coordinates');
      assert.equal(layout.find(p => p.id === '1').y, 0, 'The selected bille rests on the rail');
      for (const [i, p] of layout.entries()) {
        assert.ok(p.x >= 22 && p.x <= width - 22, 'Thumbs stay reachable at both ends');
        assert.equal(p.value, values[Number(p.id)]);
        for (const q of layout.slice(i+1)) assert.ok(Math.hypot(p.x-q.x,p.y-q.y) >= 41.99, 'All billes remain individually reachable');
      }
      const raised = layout.find(p => p.y < 0);
      if (raised) {
        const held = layoutThumbs(points, width, raised.id, 42, { y: raised.y, offset: raised.x - raised.anchor });
        const sphere = held.find(p => p.id === raised.id);
        assert.equal(sphere.y, raised.y, 'Grabbing a raised bille must not change its row');
        assert.equal(sphere.x, raised.x, 'Grabbing a raised bille must not change its horizontal position');
        assert.equal(JSON.stringify(points), before);
        for (const [i, p] of held.entries()) for (const q of held.slice(i+1)) {
          assert.ok(Math.hypot(p.x-q.x,p.y-q.y) >= 41.99, 'Neighbours must separate around the grabbed bille');
        }
      }
    }
  }
  console.log('Tirage, axes indépendants, saisie relative et séparation des billes : OK.');
})().catch(error => { console.error(error); process.exitCode = 1; });
