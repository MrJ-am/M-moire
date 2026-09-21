'use strict';
const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { createHash } = require('node:crypto');
const { verifierSources, verifierVerrou, verrou } = require('../../scripts/style-mrjam.cjs');

function exemple(controle) {
  const dossier = fs.mkdtempSync(path.join(os.tmpdir(), 'style-controle-'));
  const contenu = 'module Exemple exposing (valeur)\nvaleur = 1\n';
  const contrat = { depot: verrou.depot, revision: verrou.revision,
    fichiers: { 'src/Exemple.elm': createHash('sha256').update(contenu).digest('hex') } };
  fs.mkdirSync(path.join(dossier, 'src'));
  fs.writeFileSync(path.join(dossier, 'src/Exemple.elm'), contenu);
  try { controle(dossier, contrat); }
  finally { fs.rmSync(dossier, { recursive: true, force: true }); }
}

test('la révision demandée est verrouillée sans branche mobile', () => {
  assert.equal(verrou.revision, '52ad33f881b50feef91d60915d17bae90abfc592');
  verifierVerrou(verrou);
  for (const revision of ['main', '52ad33f', '', '../main']) {
    assert.throws(() => verifierVerrou({ ...verrou, revision }), /révision Git complète/);
  }
});
test('le dépôt et les chemins du verrou sont contrôlés', () => {
  assert.throws(() => verifierVerrou({ ...verrou, depot: 'autre/style' }));
  assert.throws(() => verifierVerrou({ ...verrou, fichiers: { '../hors-atelier': '0'.repeat(64) } }));
  assert.throws(() => verifierVerrou({ ...verrou, fichiers: {} }));
});
test('une source exacte est acceptée hors ligne', () => exemple((dossier, contrat) => {
  assert.equal(verifierSources(dossier, contrat), dossier);
}));
test('une modification du code partagé est refusée', () => exemple((dossier, contrat) => {
  fs.appendFileSync(path.join(dossier, 'src/Exemple.elm'), '-- divergence locale\n');
  assert.throws(() => verifierSources(dossier, contrat), /Empreinte/);
}));
test('un module supplémentaire ne peut contourner le verrou', () => exemple((dossier, contrat) => {
  fs.writeFileSync(path.join(dossier, 'src/Intrus.elm'), 'module Intrus exposing (..)');
  assert.throws(() => verifierSources(dossier, contrat), /modules du style/);
}));
test('un module manquant est refusé', () => exemple((dossier, contrat) => {
  fs.unlinkSync(path.join(dossier, 'src/Exemple.elm'));
  assert.throws(() => verifierSources(dossier, contrat), /modules du style/);
}));
test('un lien symbolique ne peut remplacer un module', () => exemple((dossier, contrat) => {
  fs.renameSync(path.join(dossier, 'src/Exemple.elm'), path.join(dossier, 'autre.elm'));
  fs.symlinkSync('../autre.elm', path.join(dossier, 'src/Exemple.elm'));
  assert.throws(() => verifierSources(dossier, contrat), /Lien symbolique/);
}));
