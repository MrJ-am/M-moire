'use strict';
// Version local module imports as well as HTML entrypoints to avoid mixed releases.
const fs = require('node:fs'), path = require('node:path'), { createHash } = require('node:crypto');
const site = path.resolve(__dirname, '../site'), visited = new Map();
const hash = content => createHash('sha256').update(content).digest('hex').slice(0, 12);
function versionModule(name) {
  if (visited.has(name)) return visited.get(name);
  const file = path.join(site, name);
  let source = fs.readFileSync(file, 'utf8');
  source = source.replace(/((?:from\s*|import\s*)['"])(\.\/[^'"]+)(['"])/g, (_, prefix, ref, suffix) => {
    const clean = ref.split('?')[0], dependency = path.join(path.dirname(name), clean);
    return `${prefix}${clean}?v=${versionModule(dependency)}${suffix}`;
  });
  fs.writeFileSync(file, source); const version = hash(source); visited.set(name, version); return version;
}
versionModule('enquete.js');
const assets = new Set(['survey.js', 'enquete.js', 'enquete.css', 'sliders.css', 'rich-text.js']);
let html = fs.readFileSync(path.join(site, 'index.html'), 'utf8');
html = html.replace(/((?:src|href)=")([^"]+)(")/g, (whole, prefix, ref, suffix) => {
  const clean = ref.split('?')[0];
  return assets.has(clean) ? `${prefix}${clean}?v=${hash(fs.readFileSync(path.join(site, clean)))}${suffix}` : whole;
});
for (const name of ['index.html', 'enquete.html']) fs.writeFileSync(path.join(site, name), html);
// Chaque point d’entrée conserve ses chemins relatifs, administration comprise.
function versionnerPage(nom, ressources) {
  const fichier = path.join(site, nom);
  const contenu = fs.readFileSync(fichier, 'utf8').replace(/((?:src|href)=")([^"]+)(")/g, (original, prefixe, reference, suffixe) => {
    const chemin = reference.split('?')[0];
    return ressources.includes(chemin)
      ? `${prefixe}${chemin}?v=${hash(fs.readFileSync(path.join(path.dirname(fichier), chemin)))}${suffixe}`
      : original;
  });
  fs.writeFileSync(fichier, contenu);
}
versionnerPage('prototype.html', ['main.js', 'prototype.js', 'rich-text.js']);
versionnerPage('admin/index.html', ['administration.js', 'admin.js', 'admin.css', '../rich-text.js']);
console.log('Modules et feuilles de style versionnés.');
