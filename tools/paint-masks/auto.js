// node auto.js <clusters.json> <specs-out.json> [overrides.json]
// A first guess at each car's spec from its colour clusters (genclusters.js): body = paint-coloured clusters, the rest labelled by
// colour (dark = tyre, mid grey = glass, small bright or red = light, light grey = trim). overrides.json can replace any class list
// for a car ({ "Putter": { "body": [1,2,7] } }) or set whiteBody / darkBody. The guess is only a starting point: it is checked
// against the car in Studio and corrected by hand (see the contact sheets in review/round8/frames/paint-audit).
const fs = require('fs');
const lib = require('./lib.js');
const [, , clustersPath, outPath, overridePath] = process.argv;
const clusters = JSON.parse(fs.readFileSync(clustersPath, 'utf8'));
const overrides = overridePath && fs.existsSync(overridePath) ? JSON.parse(fs.readFileSync(overridePath, 'utf8')) : {};
const specs = {};
for (const [car, cl] of Object.entries(clusters)) {
  const ov = overrides[car] || {};
  if (ov.skip) continue; // no spec yet: the car keeps its old mask
  if (ov.remove) { specs[car] = { remove: true }; continue; } // no believable mask: the car is not paintable
  const spec = { body: [], glass: [], light: [], tyre: [], trim: [], interior: [], other: [] };
  const info = cl.clusters.map(c => { const lab = lib.rgbToLab(c.rgb[0], c.rgb[1], c.rgb[2]); return { id: c.cluster, share: c.share, L: lab[0], chroma: Math.hypot(lab[1], lab[2]), hue: Math.atan2(lab[2], lab[1]) * 180 / Math.PI }; });
  // the car's own colour: the chromatic cluster with the biggest share
  const chromatic = info.filter(c => c.chroma >= 16 && c.L > 25 && c.L < 92).sort((a, b) => b.share - a.share);
  const main = chromatic[0];
  for (const c of info) {
    let kind;
    // Rainbow editions are painted in every hue, so any coloured cluster is paint there
    const anyHue = car.startsWith('Rainbow ') || ov.anyHue;
    const hueNear = anyHue || (main && Math.abs(((c.hue - main.hue + 540) % 360) - 180) < 40);
    if (c.share < 2.5 && (c.chroma > 35 || c.L > 88) && c.L > 35) kind = 'light';
    else if (c.L < 24) kind = 'tyre';
    else if (c.chroma >= 14 && c.L >= (anyHue ? 38 : Math.max(28, main ? 0.6 * main.L : 0)) && (!main || hueNear || c.share > 8)) kind = 'body';
    else if (anyHue && c.L >= 62 && c.chroma >= 7) kind = 'body'; // pale pastel paint
    else if (c.chroma >= 14 && c.L >= 28 && hueNear) kind = 'glass'; // tinted glass: the car's hue, much darker
    else if (c.L >= 66 && c.chroma < 16 && ov.whiteBody) kind = 'body';
    else if (c.L >= 70 && c.chroma < 14) kind = 'trim';
    else if (c.chroma < 14 && c.L >= 24) kind = c.L < 52 ? 'interior' : 'glass';
    else kind = c.chroma >= 14 ? 'trim' : 'other';
    spec[kind].push(c.id);
  }
  for (const k of Object.keys(spec)) if (ov[k]) spec[k] = ov[k];
  if (ov.specks) spec.specks = ov.specks;
  if (ov.smooth !== undefined) spec.smooth = ov.smooth;
  if (ov.mode !== undefined) spec.mode = ov.mode;
  specs[car] = spec;
}
fs.writeFileSync(outPath, JSON.stringify(specs, null, 1));
console.log(Object.keys(specs).length, 'specs');
