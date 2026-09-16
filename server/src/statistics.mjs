export function distribution(values, step = .25, min = 0, max = 3) {
  const counts = Array.from({ length: Math.round((max - min) / step) + 1 }, (_, i) => ({ value: min + i * step, count: 0 }));
  for (const value of values) counts[Math.min(counts.length - 1, Math.max(0, Math.round((value - min) / step)))].count++;
  return counts;
}
export function summary(values) {
  const sorted = values.filter(v => v !== null && Number.isFinite(Number(v))).map(Number).sort((a, b) => a - b);
  const n = sorted.length, quantile = p => { const x = (n - 1) * p, i = Math.floor(x); return sorted[i] + (sorted[Math.min(i + 1, n - 1)] - sorted[i]) * (x - i); };
  return { n, mean: n ? sorted.reduce((a, b) => a + b, 0) / n : null, median: n ? quantile(.5) : null, q1: n ? quantile(.25) : null, q3: n ? quantile(.75) : null };
}
export function summarizeAnswers(rows) {
  const grades = rows.filter(a => a.note !== null).map(a => Number(a.note));
  const deltas = rows.filter(a => a.note !== null && a.initial_note !== null).map(a => Number(a.note) - Number(a.initial_note));
  return {
    grades: { ...summary(grades), distribution: distribution(grades) }, initialGrades: summary(rows.map(a => a.initial_note)),
    revisions: { ...summary(deltas), changed: deltas.filter(x => x !== 0).length },
    axes: Object.fromEntries(['x', 'y', 'z'].map(axis => {
      const values = rows.filter(a => a.evaluated_axes.includes(axis)).map(a => Number(a[axis]));
      return [axis, { ...summary(values), distribution: distribution(values, 2, -10, 10) }];
    }))
  };
}
export function filter(query) {
  const values = [], clauses = ['TRUE'];
  const add = (sql, value) => { values.push(value); clauses.push(sql.replace('?', `$${values.length}`)); };
  if (query.version) add('p.bank_version=?', String(query.version));
  if (query.level) add('?=ANY(p.levels)', String(query.level));
  if (query.from) { if (!/^\d{4}-\d{2}-\d{2}$/.test(query.from)) throw Object.assign(new Error('Date invalide.'), { status: 400 }); add('p.started_at >= ?::date', query.from); }
  if (query.to) { if (!/^\d{4}-\d{2}-\d{2}$/.test(query.to)) throw Object.assign(new Error('Date invalide.'), { status: 400 }); add("p.started_at < ?::date + interval '1 day'", query.to); }
  if (query.status === 'completed') clauses.push('p.completed_at IS NOT NULL');
  else if (query.status === 'incomplete') clauses.push('p.completed_at IS NULL');
  return { sql: clauses.join(' AND '), values };
}
export function csv(rows) {
  const columns = ['participation', 'version', 'debut', 'validation', 'niveaux', 'question', 'redaction', 'note_initiale', 'note', 'lisibilite', 'precision', 'validite', 'axes_evalues'];
  const cell = value => { let s = value == null ? '' : String(value); if (/^[=+@\t\r]/.test(s)) s = `'${s}`; return `"${s.replaceAll('"', '""')}"`; };
  return '\uFEFF' + [columns, ...rows.map(r => [r.participation_id, r.bank_version, r.started_at.toISOString(), r.completed_at?.toISOString(), r.levels.join(' | '), r.question_id, r.production_id, r.initial_note, r.note, ...['x', 'y', 'z'].map(a => r.evaluated_axes.includes(a) ? r[a] : null), r.evaluated_axes.join('|')])].map(row => row.map(cell).join(';')).join('\r\n');
}
