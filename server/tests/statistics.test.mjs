import test from 'node:test';
import assert from 'node:assert/strict';
import { summary, summarizeAnswers, csv } from '../src/statistics.mjs';

test('les zéros et les absences de réponse restent distincts', () => {
  assert.deepEqual(summary([null, 0, 1, 2, 3]), { n: 4, mean: 1.5, median: 1.5, q1: .75, q3: 2.25 });
  const rows = [{ note: '0', initial_note: '1', x: 0, y: 5, z: 0, evaluated_axes: ['x'] }, { note: null, initial_note: null, x: 0, y: 0, z: 0, evaluated_axes: [] }];
  const stats = summarizeAnswers(rows);
  assert.equal(stats.grades.n, 1); assert.equal(stats.grades.mean, 0);
  assert.equal(stats.axes.x.n, 1); assert.equal(stats.axes.x.mean, 0); assert.equal(stats.axes.y.n, 0); assert.equal(stats.axes.y.mean, null);
  assert.equal(stats.revisions.mean, -1); assert.equal(stats.revisions.changed, 1);
});
test('un export CSV préserve le zéro et les axes non évalués', () => {
  const result = csv([{ participation_id: 'a', bank_version: '1', started_at: new Date('2026-01-01Z'), completed_at: null, levels: ['=HYPERLINK("bad")'], question_id: 'R01', production_id: 'R01-1', note: 0, initial_note: null, x: 0, y: 0, z: 0, evaluated_axes: ['x'] }]);
  assert.ok(result.includes('"\'=HYPERLINK('));
  assert.ok(result.includes(';"";"0";"0";"";"";"x"'));
});
