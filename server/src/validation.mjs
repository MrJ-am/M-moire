import { z } from 'zod';
const id = z.string().regex(/^R\d{2}(?:-\d+)?$/);
const grade = z.number().min(0).max(3).multipleOf(.25).nullable();
const coordinate = z.number().min(-10).max(10);
const axes = z.array(z.enum(['x', 'y', 'z'])).max(3).refine(a => new Set(a).size === a.length);
export const newParticipation = z.object({
  id: z.uuid(), secret: z.string().regex(/^[a-f0-9]{64}$/),
  bankVersion: z.string().regex(/^\d+\.\d+\.\d+$/), levels: z.array(z.string().max(30)).min(1).max(7), seed: z.number().int().min(0).max(4294967295)
}).strict();
export const credentials = z.object({ username: z.string().trim().min(3).max(80).regex(/^[\p{L}\p{N}_.@-]+$/u), password: z.string().min(14).max(256) }).strict();
export const loginCredentials = z.object({ username: z.string().max(80), password: z.string().max(256) }).strict();
export const setupCredentials = credentials.extend({ token: z.string().regex(/^[a-f0-9]{64}$/) });
const answer = z.object({ note: grade, initialNote: grade, coordinates: z.object({ x: coordinate, y: coordinate, z: coordinate }).strict(), evaluatedAxes: axes }).strict();
const event = z.object({
  event: z.enum(['grade', 'place', 'question', 'skip', 'finish', 'close', 'open', 'reveal', 'confirm-position', 'compare', 'orbit']),
  questionId: id, productionId: id, at: z.iso.datetime(), elapsedMs: z.number().int().min(0).max(31536000000),
  value: grade.optional(), initial: z.boolean().optional(), axis: z.enum(['x', 'y', 'z']).optional(),
  coordinates: z.object({ x: coordinate, y: coordinate, z: coordinate }).strict().optional(), source: z.enum(['next-production']).optional()
}).strict();
export const checkpoint = z.object({
  revision: z.number().int().min(1).max(2147483647), final: z.boolean(),
  snapshot: z.object({
    answers: z.record(id, answer), skippedQuestions: z.array(id).max(20),
    progress: z.object({ mode: z.enum(['training', 'running', 'finished']), index: z.number().int().min(0).max(19), selected: z.string().max(40),
      exposed: z.record(z.string().max(40), z.number().int().min(1).max(100)), reader: z.boolean(), tour: z.number().int().min(-1).max(7) }).strict()
  }).strict(), events: z.array(event).max(20000)
}).strict();
export function validateCheckpoint(data, participation, bank) {
  const questions = new Map(bank.questions.filter(q => participation.question_order.includes(q.id)).map(q => [q.id, q]));
  const productions = new Map([...questions.values()].flatMap(q => q.productions.map(p => [p.id, q.id])));
  const { snapshot, events } = data;
  const fail = message => { const error = new Error(message); error.status = 400; throw error; };
  if (Object.keys(snapshot.answers).some(p => !productions.has(p))) fail('Rédaction inconnue dans cette participation.');
  for (const a of Object.values(snapshot.answers)) {
    if (a.note === null && a.initialNote !== null) fail('Une note initiale exige une note.');
  }
  if (new Set(snapshot.skippedQuestions).size !== snapshot.skippedQuestions.length || snapshot.skippedQuestions.some(q => !questions.has(q))) fail('Question passée inconnue.');
  if (snapshot.progress.index >= participation.question_order.length) fail('Position de reprise invalide.');
  for (const [qid, count] of Object.entries(snapshot.progress.exposed)) {
    if (qid === 'practice' && count === 1) continue;
    if (!questions.has(qid) || count > questions.get(qid).productions.length) fail('Progression invalide.');
  }
  if (snapshot.progress.mode !== 'training') {
    const current = participation.question_order[snapshot.progress.index];
    if (productions.get(snapshot.progress.selected) !== current) fail('Rédaction de reprise invalide.');
  }
  if (data.final && snapshot.progress.mode !== 'finished') fail('Terminez le parcours avant de valider.');
  if (events.some(e => !questions.has(e.questionId) || productions.get(e.productionId) !== e.questionId)) fail('Interaction étrangère à cette participation.');
  if (events.some((e, i) => i > 0 && e.elapsedMs < events[i - 1].elapsedMs)) fail('Chronologie des interactions invalide.');
  return productions;
}
