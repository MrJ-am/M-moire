'use strict';
const fs = require('node:fs'), os = require('node:os'), path = require('node:path');
const { execFileSync } = require('node:child_process');
const root = path.resolve(__dirname, '..'), tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'matheval-elm-tests-'));
try {
  fs.copyFileSync(path.join(root, 'elm.json'), path.join(tmp, 'elm.json'));
  fs.cpSync(path.join(root, 'src'), path.join(tmp, 'src'), { recursive: true });
  fs.mkdirSync(path.join(tmp, 'tests'));
  for (const file of fs.readdirSync(path.join(root, 'tests')).filter(n => n.endsWith('.elm'))) fs.copyFileSync(path.join(root, 'tests', file), path.join(tmp, 'tests', file));
  execFileSync(path.join(root, 'node_modules/.bin/elm-test'), ['--compiler', path.join(root, 'node_modules/.bin/elm')], {
    cwd: tmp, stdio: 'inherit', env: { ...process.env, ELM_HOME: process.env.ELM_HOME || '/tmp/memoire-elm-cache' }
  });
} finally { fs.rmSync(tmp, { recursive: true, force: true }); }
