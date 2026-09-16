import pg from 'pg';
import { readFile } from 'node:fs/promises';
import { createHash } from 'node:crypto';

export const digest = value => createHash('sha256').update(value).digest('hex');
export function connect(connectionString = process.env.DATABASE_URL) {
  return new pg.Pool(connectionString ? { connectionString, max: 10, options: '-c timezone=UTC' } : { host: '/run/postgresql', database: 'matheval', user: 'matheval', max: 10, options: '-c timezone=UTC' });
}
export async function transaction(pool, work) {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const result = await work(client);
    await client.query('COMMIT');
    return result;
  } catch (error) { await client.query('ROLLBACK'); throw error; }
  finally { client.release(); }
}
export async function migrate(pool) {
  const sql = await readFile(new URL('../migrations/001-collecte.sql', import.meta.url), 'utf8');
  await transaction(pool, async client => {
    await client.query('SELECT pg_advisory_xact_lock(78041001)');
    await client.query(sql);
  });
}
export async function importCorpus(pool, bank, codebook) {
  const hash = digest(JSON.stringify({ bank, codebook }));
  await transaction(pool, async client => {
    await client.query('SELECT pg_advisory_xact_lock(78041002)');
    const previous = (await client.query('SELECT digest FROM corpus WHERE version=$1', [bank.version])).rows[0];
    if (previous && previous.digest !== hash) throw new Error('Le corpus a changé : attribuez-lui une nouvelle BANK_VERSION avant le déploiement.');
    await client.query('INSERT INTO corpus(version,digest,bank,codebook) VALUES($1,$2,$3,$4) ON CONFLICT DO NOTHING', [bank.version, hash, bank, codebook]);
  });
}
