/* Séparer les projections sans modifier les coordonnées mathématiques. */
export function placerBilles(points, largeur, hauteur, diametre) {
  const marge = diametre * .56 + 6, ecart = diametre * 1.12 + 8;
  const borner = (v, taille) => Math.max(marge, Math.min(taille - marge, v));
  const places = [];
  for (const point of points) {
    const origine = { x: borner(point.x, largeur), y: borner(point.y, hauteur) };
    const candidats = [];
    const limite = Math.ceil(Math.max(largeur, hauteur) / ecart);
    for (let rang = -limite; rang <= limite; rang++) for (let colonne = -limite; colonne <= limite; colonne++) {
      const x = origine.x + colonne * ecart, y = origine.y + rang * ecart;
      if (x >= marge && x <= largeur-marge && y >= marge && y <= hauteur-marge)
        candidats.push({x,y,cout:colonne*colonne+rang*rang+Math.abs(rang)*.01});
    }
    candidats.sort((a,b)=>a.cout-b.cout);
    const libre = candidats.find(p=>places.every(q=>Math.hypot(p.x-q.x,p.y-q.y)>=ecart-.01));
    places.push({id:point.id,...(libre || origine)});
  }
  return places;
}
