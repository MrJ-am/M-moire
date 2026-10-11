const application = Elm.Main.init({
  node: document.getElementById('elm-main'),
  flags: matchMedia('(prefers-reduced-motion: reduce)').matches
});
window.MrJamAnimations.relier(application.ports.reductionAnimations, { initiale: false });
