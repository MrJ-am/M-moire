import express from 'express';
import { rateLimit } from 'express-rate-limit';
import { fileURLToPath } from 'node:url';
import { isDeepStrictEqual } from 'node:util';
import { digest, transaction } from './database.mjs';
import { token, sameSecret, hashPassword, checkPassword, cookie } from './security.mjs';
import { newParticipation, checkpoint, validateCheckpoint, loginCredentials, setupCredentials } from './validation.mjs';
import { filter, summarizeAnswers, csv } from './statistics.mjs';
import { prepareSession } from '../../docs/site/session.js';

const fail = (status, message) => { throw Object.assign(new Error(message), { status }); };
const publicQuestion = q => ({ id: q.id, level: q.level, domain: q.domain, statement: q.statement, productions: q.productions.map(p => ({ id: p.id, content: p.content })) });
const sessionView = (p, bank) => ({ id: p.id, bankVersion: p.bank_version, levels: p.levels, seed: Number(p.seed), startedAt: p.started_at.toISOString(), revision: p.revision,
  completedAt: p.completed_at?.toISOString() || null, snapshot: p.snapshot, questions: p.question_order.map(id => {
    const q = bank.questions.find(q => q.id === id); return publicQuestion({ ...q, productions: p.production_order[id].map(id => q.productions.find(p => p.id === id)) });
  }) });

export function createApp({ pool, origin = 'http://127.0.0.1:4173', prefix = '/matheval', setupHash = '', currentVersion, testMode = false }) {
  const app = express();
  app.disable('x-powered-by');
  app.set('trust proxy', 'loopback');
  app.use((req, res, next) => {
    res.set({ 'X-Content-Type-Options': 'nosniff', 'X-Frame-Options': 'DENY', 'Referrer-Policy': 'no-referrer', 'Permissions-Policy': 'camera=(), microphone=(), geolocation=()',
      'Content-Security-Policy': "default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline'; img-src 'self' data:; font-src 'self' data:; connect-src 'self'; base-uri 'self'; frame-ancestors 'none'; object-src 'none'; form-action 'self'" });
    if (origin.startsWith('https:')) res.set('Strict-Transport-Security', 'max-age=31536000');
    next();
  });
  const api = express.Router();
  app.use(`${prefix}/api`, api);
  api.use((req, res, next) => {
    res.set('Cache-Control', 'no-store');
    if (!['GET', 'HEAD'].includes(req.method) && (req.get('origin') !== origin || req.get('x-matheval-request') !== '1' || !req.is('application/json'))) return res.status(403).json({ error: 'Origine de la requête refusée.' });
    next();
  });
  api.use(express.json({ limit: '5mb', strict: true }));
  const limit = (max, windowMs) => rateLimit({ windowMs, limit: testMode ? 10000 : max, standardHeaders: 'draft-8', legacyHeaders: false, message: { error: 'Trop de tentatives. Réessayez dans quelques minutes.' } });
  api.get('/health', async (req, res) => { await pool.query('SELECT 1'); res.json({ status: 'ok', version: currentVersion }); });
  api.post('/sessions', limit(30, 60 * 60 * 1000), async (req, res) => {
    const data = newParticipation.parse(req.body);
    const row = (await pool.query('SELECT bank FROM corpus WHERE version=$1', [data.bankVersion])).rows[0];
    if (!row) fail(400, 'Version du questionnaire inconnue.');
    if (new Set(data.levels).size !== data.levels.length || data.levels.some(l => !row.bank.questions.some(q => q.level === l))) fail(400, 'Niveau inconnu.');
    const questions = prepareSession(row.bank, data.levels, data.seed);
    await pool.query(`INSERT INTO participations(id,token_hash,bank_version,levels,seed,question_order,production_order)
      VALUES($1,$2,$3,$4,$5,$6,$7) ON CONFLICT DO NOTHING`, [data.id, digest(data.secret), data.bankVersion, data.levels, data.seed, questions.map(q => q.id), Object.fromEntries(questions.map(q => [q.id, q.productions.map(p => p.id)]))]);
    const p = (await pool.query('SELECT * FROM participations WHERE id=$1', [data.id])).rows[0];
    if (!sameSecret(p.token_hash, digest(data.secret))) fail(409, 'Cet identifiant est déjà utilisé.');
    if (p.bank_version !== data.bankVersion || Number(p.seed) !== data.seed || JSON.stringify(p.levels) !== JSON.stringify(data.levels)) fail(409, 'Les paramètres de cette participation sont déjà fixés.');
    res.status(201).json(sessionView(p, row.bank));
  });
  api.use('/sessions/:id', async (req, res, next) => {
    if (!/^[a-f0-9-]{36}$/i.test(req.params.id)) return res.status(404).json({ error: 'Participation introuvable.' });
    const p = (await pool.query('SELECT p.*,c.bank FROM participations p JOIN corpus c ON c.version=p.bank_version WHERE p.id=$1', [req.params.id])).rows[0];
    if (!p || !sameSecret(p.token_hash, digest(req.get('x-session-token') || ''))) return res.status(401).json({ error: 'Accès à cette participation refusé.' });
    req.participation = p; next();
  });
  api.get('/sessions/:id', (req, res) => res.json(sessionView(req.participation, req.participation.bank)));
  api.get('/sessions/:id/events', async (req, res) => res.json((await pool.query('SELECT payload FROM interaction_events WHERE participation_id=$1 ORDER BY sequence', [req.params.id])).rows.map(e => e.payload)));
  api.put('/sessions/:id', limit(300, 60 * 1000), async (req, res) => {
    const data = checkpoint.parse(req.body), hash = digest(JSON.stringify(data));
    const result = await transaction(pool, async client => {
      const p = (await client.query('SELECT * FROM participations WHERE id=$1 FOR UPDATE', [req.params.id])).rows[0];
      if (p.revision === data.revision && p.payload_hash === hash) return p;
      if (p.completed_at) fail(409, 'Cette participation est déjà validée.');
      if (data.revision <= p.revision) fail(409, 'Une version plus récente existe. Rechargez la page pour la retrouver.');
      const productions = validateCheckpoint(data, p, req.participation.bank);
      const oldEvents = (await client.query('SELECT payload FROM interaction_events WHERE participation_id=$1 ORDER BY sequence', [p.id])).rows;
      if (data.events.length < oldEvents.length || oldEvents.some((e, i) => !isDeepStrictEqual(e.payload, data.events[i]))) fail(409, 'Le journal de cette participation a déjà progressé.');
      await client.query('DELETE FROM answers WHERE participation_id=$1', [p.id]);
      for (const [id, a] of Object.entries(data.snapshot.answers)) await client.query(`INSERT INTO answers(participation_id,question_id,production_id,note,initial_note,x,y,z,evaluated_axes) VALUES($1,$2,$3,$4,$5,$6,$7,$8,$9)`, [p.id, productions.get(id), id, a.note, a.initialNote, a.coordinates.x, a.coordinates.y, a.coordinates.z, a.evaluatedAxes]);
      for (let i = oldEvents.length; i < data.events.length; i++) { const e = data.events[i]; await client.query('INSERT INTO interaction_events(participation_id,sequence,event,occurred_at,elapsed_ms,payload) VALUES($1,$2,$3,$4,$5,$6)', [p.id, i, e.event, e.at, e.elapsedMs, e]); }
      return (await client.query(`UPDATE participations SET snapshot=$2,revision=$3,payload_hash=$4,updated_at=now(),completed_at=CASE WHEN $5 THEN now() ELSE NULL END WHERE id=$1 RETURNING *`, [p.id, data.snapshot, data.revision, hash, data.final])).rows[0];
    });
    res.json({ revision: result.revision, savedAt: result.updated_at.toISOString(), completedAt: result.completed_at?.toISOString() || null });
  });
  const cookieOptions = { httpOnly: true, secure: origin.startsWith('https:'), sameSite: 'strict', path: `${prefix}/api/admin`, maxAge: 8 * 60 * 60 * 1000 };
  const signIn = async (req, res, admin) => {
    const secret = token();
    await transaction(pool, async client => {
      await client.query('SELECT id FROM administrators WHERE id=$1 FOR UPDATE', [admin.id]);
      await client.query("DELETE FROM administrator_sessions WHERE expires_at<=now() OR last_seen<=now()-interval '2 hours' OR token_hash=$1", [digest(cookie(req, 'matheval_admin') || '')]);
      await client.query("DELETE FROM administrator_sessions WHERE token_hash IN (SELECT token_hash FROM administrator_sessions WHERE administrator_id=$1 ORDER BY last_seen DESC,token_hash OFFSET 19)", [admin.id]);
      await client.query("INSERT INTO administrator_sessions(token_hash,administrator_id,expires_at) VALUES($1,$2,now()+interval '8 hours')", [digest(secret), admin.id]);
    });
    res.cookie('matheval_admin', secret, cookieOptions); res.json({ username: admin.username });
  };
  const loginLimit = limit(8, 15 * 60 * 1000);
  api.post('/admin/setup', loginLimit, async (req, res) => {
    const data = setupCredentials.parse(req.body);
    if (!setupHash || !sameSecret(digest(data.token), setupHash)) fail(403, 'Lien d’activation invalide.');
    const passwordHash = await hashPassword(data.password);
    const admin = await transaction(pool, async client => {
      await client.query('SELECT pg_advisory_xact_lock(78041003)');
      if ((await client.query('SELECT id FROM administrators LIMIT 1')).rowCount) fail(409, 'Le compte administrateur est déjà activé.');
      return (await client.query('INSERT INTO administrators(username,password_hash) VALUES($1,$2) RETURNING id,username', [data.username, passwordHash])).rows[0];
    });
    await signIn(req, res, admin);
  });
  api.post('/admin/login', loginLimit, async (req, res) => {
    const data = loginCredentials.parse(req.body);
    const admin = (await pool.query('SELECT * FROM administrators WHERE username=$1', [data.username])).rows[0];
    // A constant dummy hash keeps unknown users on the same password-verification path.
    const stored = admin?.password_hash || `scrypt:${'0'.repeat(32)}:${'0'.repeat(128)}`;
    if (!(await checkPassword(data.password, stored)) || !admin) fail(401, 'Identifiant ou mot de passe incorrect.');
    await signIn(req, res, admin);
  });
  api.use('/admin', async (req, res, next) => {
    const admin = (await pool.query(`UPDATE administrator_sessions s SET last_seen=now() FROM administrators a WHERE a.id=s.administrator_id AND s.token_hash=$1 AND s.expires_at>now() AND s.last_seen>now()-interval '2 hours' RETURNING a.id,a.username`, [digest(cookie(req, 'matheval_admin') || '')])).rows[0];
    if (!admin) return res.status(401).json({ error: 'Connectez-vous à l’administration.' });
    req.admin = admin; next();
  });
  api.get('/admin/me', (req, res) => res.json({ username: req.admin.username }));
  api.post('/admin/logout', async (req, res) => { await pool.query('DELETE FROM administrator_sessions WHERE token_hash=$1', [digest(cookie(req, 'matheval_admin') || '')]); res.clearCookie('matheval_admin', cookieOptions); res.json({ ok: true }); });
  api.get('/admin/corpora', async (req, res) => res.json((await pool.query('SELECT version,imported_at FROM corpus ORDER BY imported_at DESC')).rows));
  api.get('/admin/corpus/:version', async (req, res) => {
    const row = (await pool.query('SELECT bank,codebook FROM corpus WHERE version=$1', [req.params.version])).rows[0]; if (!row) fail(404, 'Corpus inconnu.'); res.json(row);
  });
  async function answerRows(query) {
    const f = filter(query);
    return (await pool.query(`SELECT a.*,p.bank_version,p.levels,p.started_at,p.completed_at FROM answers a JOIN participations p ON p.id=a.participation_id WHERE ${f.sql} ORDER BY p.started_at,a.production_id`, f.values)).rows;
  }
  api.get('/admin/statistics', async (req, res) => {
    const f = filter(req.query), rows = await answerRows(req.query);
    const sessions = (await pool.query(`SELECT p.id,p.started_at,p.completed_at,p.levels FROM participations p WHERE ${f.sql}`, f.values)).rows;
    const answered = new Set(rows.filter(a => a.note !== null).map(a => a.participation_id));
    const byProduction = {};
    for (const row of rows) (byProduction[`${row.bank_version}:${row.production_id}`] ||= []).push(row);
    const daily = {}, levels = {};
    for (const p of sessions) { const date = p.started_at.toISOString().slice(0, 10); daily[date] ||= { date, started: 0, completed: 0 }; daily[date].started++; if (p.completed_at) daily[date].completed++; for (const level of p.levels) levels[level] = (levels[level] || 0) + 1; }
    const completed = sessions.filter(s => s.completed_at).length;
    res.json({ started: sessions.length, answered: answered.size, completed, incomplete: sessions.length - completed, completionRate: sessions.length ? completed / sessions.length : 0, evaluations: rows.filter(a => a.note !== null).length,
      daily: Object.values(daily).sort((a, b) => a.date.localeCompare(b.date)), levels, summary: summarizeAnswers(rows), productions: Object.fromEntries(Object.entries(byProduction).map(([id, data]) => [id, summarizeAnswers(data)])) });
  });
  api.get('/admin/participations', async (req, res) => {
    const f = filter(req.query), page = Math.max(1, Math.min(100000, Number.parseInt(req.query.page || '1', 10) || 1));
    const total = Number((await pool.query(`SELECT count(*) FROM participations p WHERE ${f.sql}`, f.values)).rows[0].count);
    const rows = (await pool.query(`SELECT p.id,p.bank_version,p.levels,p.started_at,p.updated_at,p.completed_at,(SELECT count(*) FROM answers a WHERE a.participation_id=p.id AND a.note IS NOT NULL)::int AS answers FROM participations p WHERE ${f.sql} ORDER BY p.started_at DESC LIMIT 30 OFFSET $${f.values.length + 1}`, [...f.values, (page - 1) * 30])).rows;
    res.json({ page, total, pages: Math.ceil(total / 30), rows });
  });
  api.get('/admin/productions/:id/answers', async (req, res) => {
    const rows = await answerRows(req.query);
    res.json(rows.filter(r => r.production_id === req.params.id));
  });
  api.get('/admin/participations/:id', async (req, res) => {
    if (!/^[a-f0-9-]{36}$/i.test(req.params.id)) fail(404, 'Participation inconnue.');
    const p = (await pool.query('SELECT p.*,c.bank FROM participations p JOIN corpus c ON c.version=p.bank_version WHERE p.id=$1', [req.params.id])).rows[0];
    if (!p) fail(404, 'Participation inconnue.');
    const events = (await pool.query('SELECT payload FROM interaction_events WHERE participation_id=$1 ORDER BY sequence', [p.id])).rows.map(e => e.payload);
    res.json({ ...sessionView(p, p.bank), events });
  });
  api.get('/admin/exports/responses.csv', async (req, res) => { res.type('text/csv').attachment('matheval-reponses.csv').send(csv(await answerRows(req.query))); });
  api.use((req, res) => res.status(404).json({ error: 'Ressource inconnue.' }));
  if (prefix) app.get(prefix, (req, res, next) => req.path === prefix ? res.redirect(308, `${prefix}/${req.url.slice(prefix.length)}`) : next());
  app.use(`${prefix}/admin`, (req, res, next) => { res.set('Cache-Control', 'no-store'); next(); });
  app.use(prefix || '/', express.static(fileURLToPath(new URL('../../docs/site', import.meta.url)), { dotfiles: 'deny', index: 'index.html', setHeaders: res => res.set('Cache-Control', 'no-cache') }));
  app.use((error, req, res, next) => {
    const status = error.name === 'ZodError' || error.type === 'entity.parse.failed' ? 400 : error.status || 500;
    if (status >= 500) console.error('Erreur de collecte', error.code || error.name, error.message);
    res.status(status).json({ error: status === 400 ? 'Données invalides. Vérifiez les champs et réessayez.' : status >= 500 ? 'Enregistrement temporairement indisponible. Vos réponses sont conservées sur cet appareil.' : error.message });
  });
  return app;
}
