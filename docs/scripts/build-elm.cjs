'use strict';
const { preparerAtelier, installerIdentite } = require('./style-mrjam.cjs');
// Les verrous Elm exigent un système de fichiers Linux, y compris sur Android.
const fs = require('node:fs'), os = require('node:os'), path = require('node:path');
const { execFileSync } = require('node:child_process');
const root = path.resolve(__dirname, '..');
const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'matheval-elm-'));
try {
  const commun = preparerAtelier(tmp);
  for (const [entry, output, flags] of [['Main', 'main.js', ['--optimize']], ['Survey', 'survey.js', ['--optimize']], ['Administration', 'administration.js', ['--optimize']], ['DemoCard', 'demo-card.js', ['--optimize']]]) {
    execFileSync(path.join(root, 'node_modules/.bin/elm'), ['make', `src/${entry}.elm`, `--output=${path.join(tmp, output)}`, ...flags], {
      cwd: tmp, stdio: 'inherit', env: { ...process.env, ELM_HOME: process.env.ELM_HOME || '/tmp/memoire-elm-cache' }
    });
  }
  // Rien n’est recopié tant que tous les points d’entrée n’ont pas compilé.
  for (const output of ['main.js', 'survey.js', 'demo-card.js']) fs.copyFileSync(path.join(tmp, output), path.join(root, 'site', output));
  fs.copyFileSync(path.join(tmp, 'administration.js'), path.join(root, 'site/admin/administration.js'));
  installerIdentite(commun, path.join(root, 'site/assets/mrjam'));
  installerIdentite(commun, path.join(root, 'site/admin/assets/mrjam'));
  const style = JSON.parse(fs.readFileSync(path.join(root, 'style-mrjam.json'), 'utf8'));
  const identite = JSON.parse(fs.readFileSync(path.join(root, 'identite/provenance.json'), 'utf8'));
  const application = process.env.GITHUB_SHA || execFileSync('git', ['rev-parse', 'HEAD'], { cwd: root, encoding: 'utf8' }).trim();
  fs.writeFileSync(path.join(root, 'site/interface.json'), JSON.stringify({ application, style: style.revision, signature: identite.revision }, null, 2) + '\n');
} finally { fs.rmSync(tmp, { recursive: true, force: true }); }
