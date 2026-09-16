import { connect, migrate } from './database.mjs';
const pool = connect();
try { await migrate(pool); console.log('Schéma de collecte prêt.'); }
finally { await pool.end(); }
