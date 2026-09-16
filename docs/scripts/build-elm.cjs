'use strict';
// Elm's file locks require a Linux filesystem, including on Android shared storage.
const fs = require('node:fs'), os = require('node:os'), path = require('node:path');
const { execFileSync } = require('node:child_process');
const root = path.resolve(__dirname, '..');
const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'matheval-elm-'));
try {
  fs.copyFileSync(path.join(root, 'elm.json'), path.join(tmp, 'elm.json'));
  fs.cpSync(path.join(root, 'src'), path.join(tmp, 'src'), { recursive: true });
  for (const [entry, output, flags] of [['Main', 'main.js', []], ['Survey', 'survey.js', ['--optimize']]]) {
    execFileSync(path.join(root, 'node_modules/.bin/elm'), ['make', `src/${entry}.elm`, `--output=${path.join(tmp, output)}`, ...flags], {
      cwd: tmp, stdio: 'inherit', env: { ...process.env, ELM_HOME: process.env.ELM_HOME || '/tmp/memoire-elm-cache' }
    });
    fs.copyFileSync(path.join(tmp, output), path.join(root, 'site', output));
  }
} finally { fs.rmSync(tmp, { recursive: true, force: true }); }
