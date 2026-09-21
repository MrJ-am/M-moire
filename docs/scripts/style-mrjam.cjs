'use strict';
// Une seule révision de la bibliothèque, partagée par la compilation et les tests.
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { createHash } = require('node:crypto');
const { execFileSync } = require('node:child_process');
const racine = path.resolve(__dirname, '..');
const verrou = JSON.parse(fs.readFileSync(path.join(racine, 'style-mrjam.json'), 'utf8'));

function verifierVerrou(contrat) {
  if (contrat.depot !== 'MrJ-am/style-mrjam' || !/^[a-f0-9]{40}$/.test(contrat.revision)) {
    throw new Error('Le style exige le dépôt autorisé et une révision Git complète, jamais une branche.');
  }
  if (!contrat.fichiers || !Object.keys(contrat.fichiers).length) throw new Error('Empreintes du style absentes.');
  for (const [nom, empreinte] of Object.entries(contrat.fichiers)) {
    if (!/^[a-f0-9]{64}$/.test(empreinte) || path.isAbsolute(nom) || nom.split('/').some(p => p === '..' || p === '.' || !p)) {
      throw new Error(`Entrée de verrou invalide : ${nom}`);
    }
  }
}

function fichiersSources(dossier, prefixe = 'src') {
  return fs.readdirSync(path.join(dossier, prefixe), { withFileTypes: true }).flatMap(entree => {
    const nom = `${prefixe}/${entree.name}`;
    if (entree.isSymbolicLink()) throw new Error(`Lien symbolique interdit dans le style : ${nom}`);
    return entree.isDirectory() ? fichiersSources(dossier, nom) : [nom];
  }).sort();
}

function verifierSources(dossier, contrat = verrou) {
  verifierVerrou(contrat);
  const attendus = Object.keys(contrat.fichiers).filter(nom => nom.startsWith('src/')).sort();
  if (JSON.stringify(fichiersSources(dossier)) !== JSON.stringify(attendus)) {
    throw new Error('Les modules du style ne correspondent pas à la révision verrouillée.');
  }
  for (const [nom, empreinte] of Object.entries(contrat.fichiers)) {
    // Ne pas suivre un lien symbolique, même dans un répertoire intermédiaire.
    let courant = dossier;
    for (const partie of nom.split('/')) {
      courant = path.join(courant, partie);
      if (fs.lstatSync(courant).isSymbolicLink()) throw new Error(`Lien symbolique interdit : ${nom}`);
    }
    const contenu = fs.readFileSync(courant);
    if (createHash('sha256').update(contenu).digest('hex') !== empreinte) {
      throw new Error(`Empreinte du style incorrecte : ${nom}`);
    }
  }
  return dossier;
}

function sources() {
  verifierVerrou(verrou);
  // Un atelier hors ligne doit fournir les mêmes octets, pas une copie modifiée.
  if (process.env.STYLE_MRJAM_SOURCE) return verifierSources(path.resolve(process.env.STYLE_MRJAM_SOURCE));
  const cache = path.join(os.tmpdir(), 'matheval-style-mrjam', verrou.revision);
  if (fs.existsSync(cache)) return verifierSources(cache);
  const temporaire = fs.mkdtempSync(path.join(os.tmpdir(), 'matheval-style-'));
  try {
    const git = (...arguments_) => execFileSync('git', arguments_, { cwd: temporaire, stdio: 'pipe', timeout: 120000 });
    git('init', '--quiet');
    git('remote', 'add', 'origin', `https://github.com/${verrou.depot}.git`);
    git('fetch', '--depth=1', 'origin', verrou.revision);
    git('checkout', '--detach', '--quiet', 'FETCH_HEAD');
    if (git('rev-parse', 'HEAD').toString().trim() !== verrou.revision) throw new Error('Révision du style inattendue.');
    verifierSources(temporaire);
    fs.mkdirSync(path.dirname(cache), { recursive: true });
    // Le cache est immuable ; deux compilations simultanées peuvent le préparer.
    try { fs.renameSync(temporaire, cache); }
    catch (erreur) { if (!fs.existsSync(cache)) throw erreur; }
    return verifierSources(cache);
  } finally {
    fs.rmSync(temporaire, { recursive: true, force: true });
  }
}

function preparerAtelier(dossier) {
  const commun = sources();
  fs.copyFileSync(path.join(racine, 'elm.json'), path.join(dossier, 'elm.json'));
  fs.cpSync(path.join(racine, 'src'), path.join(dossier, 'src'), { recursive: true });
  fs.mkdirSync(path.join(dossier, '.style-mrjam'), { recursive: true });
  fs.cpSync(path.join(commun, 'src'), path.join(dossier, '.style-mrjam/src'), { recursive: true });
  return commun;
}

function installerIdentite(commun, destination) {
  verifierSources(commun);
  fs.mkdirSync(destination, { recursive: true });
  for (const nom of Object.keys(verrou.fichiers).filter(n => n.startsWith('public/assets/mrjam/'))) {
    fs.copyFileSync(path.join(commun, nom), path.join(destination, path.basename(nom)));
  }
  const provenance = JSON.parse(fs.readFileSync(path.join(racine, 'identite/provenance.json'), 'utf8'));
  const identite = JSON.parse(fs.readFileSync(path.join(commun, 'identite.json'), 'utf8'));
  if (provenance.revision !== identite.revision || provenance.depot !== identite.depot) throw new Error('Révision typographique différente du style.');
  for (const [nom, attendu] of Object.entries(provenance.fichiers)) {
    if (path.basename(nom) !== nom) throw new Error('Chemin typographique invalide.');
    const contenu = fs.readFileSync(path.join(racine, 'identite', nom));
    const blob = createHash('sha1').update(Buffer.from(`blob ${contenu.length}\0`)).update(contenu).digest('hex');
    if (blob !== identite.ressources_externes[`web/${nom}`] || blob !== attendu.git_blob || createHash('sha256').update(contenu).digest('hex') !== attendu.sha256) throw new Error(`Police non conforme : ${nom}`);
    fs.writeFileSync(path.join(destination, nom), contenu);
  }
  fs.copyFileSync(path.join(racine, 'identite/provenance.json'), path.join(destination, 'polices.json'));
  fs.copyFileSync(path.join(commun, 'identite.json'), path.join(destination, 'identite.json'));
}

module.exports = { preparerAtelier, installerIdentite, verifierSources, verifierVerrou, verrou };
