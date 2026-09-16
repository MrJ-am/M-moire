import { before, after, test } from 'node:test';
import assert from 'node:assert/strict';
import { createApp } from '../src/app.mjs';

let server, url;
before(async () => {
  const pool = { query() { throw new Error('Une page statique ne doit pas accéder à PostgreSQL.'); } };
  server = createApp({ pool, currentVersion: 'test', testMode: true }).listen(0, '127.0.0.1');
  await new Promise(resolve => server.once('listening', resolve));
  url = 'http://127.0.0.1:' + server.address().port;
});
after(async () => { await new Promise(resolve => server.close(resolve)); });

test('le sous-chemin redirige une seule fois et conserve les paramètres', async () => {
  const response = await fetch(url + '/matheval?seed=42', { redirect: 'manual' });
  assert.equal(response.status, 308);
  assert.equal(response.headers.get('location'), '/matheval/?seed=42');
  const page = await fetch(url + response.headers.get('location'), { redirect: 'manual' });
  assert.equal(page.status, 200);
  assert.match(await page.text(), /enquete\.js/);
});

test('les pages et ressources sont accessibles sous le préfixe, sans script intégré', async () => {
  for (const path of ['/', '/admin/', '/prototype.html', '/prototype.js', '/collection.js', '/data/exercise-001.json']) {
    const response = await fetch(url + '/matheval' + path, { redirect: 'manual' });
    assert.equal(response.status, 200, path);
    assert.match(response.headers.get('content-security-policy'), /script-src 'self';/);
    if (path.endsWith('/') || path.endsWith('.html')) {
      assert.doesNotMatch(await response.text(), /<script\b(?![^>]*\bsrc=)[^>]*>/i, path);
    }
  }
});

test('le serveur ne publie ni les sources ni les fichiers de configuration', async () => {
  for (const path of ['/data/exercise-001.json', '/matheval/.env', '/matheval/server/src/app.mjs', '/matheval/research/bank.json']) {
    assert.equal((await fetch(url + path, { redirect: 'manual' })).status, 404, path);
  }
});
