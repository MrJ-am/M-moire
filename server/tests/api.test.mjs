import { before, after, test } from 'node:test';
import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { readFile } from 'node:fs/promises';
import { connect, migrate, importCorpus, digest } from '../src/database.mjs';
import { createApp } from '../src/app.mjs';
import { token } from '../src/security.mjs';

const connectionString = process.env.TEST_DATABASE_URL || 'postgres://postgres@127.0.0.1:55432/matheval_api_test';
if (!new URL(connectionString).pathname.endsWith('_test')) throw new Error('Les tests exigent une base dont le nom se termine par _test.');
const pool = connect(connectionString), origin = 'http://127.0.0.1:4173', setup = token();
let server, url, adminCookie;
const bank = JSON.parse(await readFile(new URL('../../research/bank.json', import.meta.url)));
const codes = JSON.parse(await readFile(new URL('../../research/codebook.json', import.meta.url)));
const password = 'mot-de-passe-pour-les-tests-uniquement';
async function request(path, { method = 'GET', data, secret, admin = false, foreign = false } = {}) {
  const response = await fetch(`${url}${path}`, { method, headers: { 'Content-Type': 'application/json', Origin: foreign ? 'https://foreign.invalid' : origin, 'X-Matheval-Request': '1', ...(secret ? { 'X-Session-Token': secret } : {}), ...(admin ? { Cookie: adminCookie } : {}) }, ...(data ? { body: JSON.stringify(data) } : {}) });
  return { status: response.status, response, body: response.headers.get('content-type')?.includes('json') ? await response.json() : await response.text() };
}
async function create() {
  const secret = token(), id = randomUUID(), body = { id, secret, bankVersion: bank.version, levels: ['5e'], seed: 12345 };
  const response = await request('/sessions', { method: 'POST', data: body });
  assert.equal(response.status, 201);
  return { secret, id, body, session: response.body };
}
function payload(session, final = false) {
  const q = session.questions[0], p = q.productions[0];
  return { revision: 1, final, snapshot: { answers: { [p.id]: { note: 0, initialNote: 1, coordinates: { x: 0, y: 0, z: 0 }, evaluatedAxes: ['x'] } }, skippedQuestions: [], progress: { mode: final ? 'finished' : 'running', index: 0, selected: p.id, exposed: { [q.id]: 1 }, reader: false, tour: -1 } }, events: [{ event: 'grade', questionId: q.id, productionId: p.id, at: '2026-09-16T10:00:00.000Z', elapsedMs: 200, value: 0, initial: true }] };
}
before(async () => {
  await migrate(pool);
  await pool.query('TRUNCATE administrators,administrator_sessions,interaction_events,answers,participations,corpus RESTART IDENTITY CASCADE');
  await importCorpus(pool, bank, codes);
  const app = createApp({ pool, origin, prefix: '/matheval', setupHash: digest(setup), currentVersion: bank.version, testMode: true });
  server = app.listen(0, '127.0.0.1'); await new Promise(resolve => server.once('listening', resolve));
  url = `http://127.0.0.1:${server.address().port}/matheval/api`;
});
after(async () => { if (server) await new Promise(resolve => server.close(resolve)); await pool.end(); });
test('l’API privée exige une connexion et refuse une origine étrangère', async () => {
  assert.equal((await request('/admin/statistics')).status, 401);
  assert.equal((await request('/admin/corpus/' + bank.version)).status, 401);
  assert.equal((await request('/admin/setup', { method: 'POST', data: { token: setup, username: 'admin', password }, foreign: true })).status, 403);
  assert.equal((await request('/admin/setup', { method: 'POST', data: { token: token(), username: 'admin', password } })).status, 403);
});
test('l’activation est unique et les cookies administrateur sont protégés', async () => {
  const result = await request('/admin/setup', { method: 'POST', data: { token: setup, username: 'admin', password } });
  assert.equal(result.status, 200);
  const header = result.response.headers.get('set-cookie'); assert.match(header, /HttpOnly/); assert.match(header, /SameSite=Strict/); assert.match(header, /Path=\/matheval\/api\/admin/);
  adminCookie = header.split(';')[0];
  assert.equal((await request('/admin/me', { admin: true })).body.username, 'admin');
  assert.equal((await request('/admin/setup', { method: 'POST', data: { token: setup, username: 'another', password } })).status, 409);
  assert.equal((await request('/admin/login', { method: 'POST', data: { username: 'admin', password: 'wrong' } })).status, 401);
});
test('création réessayée : une seule participation, corpus public et accès isolé', async () => {
  const p = await create();
  assert.equal((await request('/sessions', { method: 'POST', data: p.body })).body.id, p.id);
  const row = (await pool.query('SELECT count(*)::int AS n FROM participations WHERE id=$1', [p.id])).rows[0]; assert.equal(row.n, 1);
  assert.equal((await request('/sessions/' + p.id, { secret: token() })).status, 401);
  assert.equal((await request('/sessions', { method: 'POST', data: { ...p.body, secret: token() } })).status, 409);
  assert.equal(p.session.questions[0].referenceAnswer, undefined); assert.equal(p.session.questions[0].productions[0].research, undefined);
});
test('sauvegarde transactionnelle, reprise, zéro évalué et retransmission sans doublon', async () => {
  const p = await create(), data = payload(p.session);
  const save = () => request('/sessions/' + p.id, { method: 'PUT', secret: p.secret, data });
  assert.equal((await save()).status, 200); assert.equal((await save()).status, 200);
  const saved = (await request('/sessions/' + p.id, { secret: p.secret })).body;
  assert.deepEqual(saved.snapshot, data.snapshot); assert.equal(saved.revision, 1);
  assert.equal((await pool.query('SELECT count(*)::int AS n FROM interaction_events WHERE participation_id=$1', [p.id])).rows[0].n, 1);
  const invalid = structuredClone(data); invalid.revision = 2; Object.values(invalid.snapshot.answers)[0].note = 4;
  assert.equal((await request('/sessions/' + p.id, { method: 'PUT', secret: p.secret, data: invalid })).status, 400);
  assert.equal((await request('/sessions/' + p.id, { secret: p.secret })).body.revision, 1);
  const changed = structuredClone(data); Object.values(changed.snapshot.answers)[0].note = 2;
  assert.equal((await request('/sessions/' + p.id, { method: 'PUT', secret: p.secret, data: changed })).status, 409);
});
test('une validation reçue est durable et ne peut pas être écrasée', async () => {
  const p = await create(), data = payload(p.session, true);
  const save = value => request('/sessions/' + p.id, { method: 'PUT', secret: p.secret, data: value });
  const result = await save(data); assert.equal(result.status, 200); assert.ok(result.body.completedAt);
  assert.equal((await save(data)).body.completedAt, result.body.completedAt);
  assert.equal((await save({ ...data, revision: 2, final: false })).status, 409);
  assert.ok((await request('/sessions/' + p.id, { secret: p.secret })).body.completedAt);
});
test('les statistiques utilisent les réponses évaluées et les filtres de validation', async () => {
  const data = (await request('/admin/statistics?status=completed', { admin: true })).body;
  assert.equal(data.completed, 1); assert.equal(data.answered, 1); assert.equal(data.summary.grades.n, 1); assert.equal(data.summary.grades.mean, 0);
  assert.equal(data.summary.axes.x.n, 1); assert.equal(data.summary.axes.y.n, 0);
  const rows = (await request('/admin/participations?status=completed', { admin: true })).body;
  assert.equal(rows.total, 1);
  const detail = (await request(`/admin/participations/${rows.rows[0].id}`, { admin: true })).body;
  assert.equal(detail.events.length, 1); assert.equal(detail.secret, undefined); assert.equal(detail.token_hash, undefined);
  assert.equal((await request('/admin/exports/responses.csv?status=completed', { admin: true })).status, 200);
  assert.equal((await request('/admin/statistics?level=4e', { admin: true })).body.started, 0);
});
test('le journal refuse les suppressions et les modifications rétrospectives', async () => {
  const p = await create(), data = payload(p.session);
  assert.equal((await request('/sessions/' + p.id, { method: 'PUT', secret: p.secret, data })).status, 200);
  data.revision++; data.events[0].value = 2;
  assert.equal((await request('/sessions/' + p.id, { method: 'PUT', secret: p.secret, data })).status, 409);
});
test('un corpus modifié doit recevoir une nouvelle version', async () => {
  const changed = structuredClone(bank); changed.questions[0].statement += ' modification';
  await assert.rejects(importCorpus(pool, changed, codes), /BANK_VERSION/);
});
test('la déconnexion invalide le cookie en base', async () => {
  assert.equal((await request('/admin/logout', { method: 'POST', data: {}, admin: true })).status, 200);
  assert.equal((await request('/admin/me', { admin: true })).status, 401);
});
