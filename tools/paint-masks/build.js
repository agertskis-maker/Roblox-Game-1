// node build.js <clusters.json> <specs.json> <PaintMasks.luau in> <PaintMasks.luau out> <previewDir>
// Turns each car's colour clusters (genclusters.js) plus its hand-written spec into the run-length coded region mask that
// BodyPaint reads. specs.json: { "<car>": { "body": [cluster ids], "glass": [...], "light": [...], "tyre": [...], "trim": [...],
// "interior": [...], "other": [...], "smooth"?: 1, "specks"?: 14, "holes"?: 24 } }. A cluster not listed is "other".
// Cars with no spec keep their old entry. Values: 1..6 body shade (dark to bright), 8 glass, 9 light, 10 tyre, 11 trim,
// 12 interior, 13 other (see BodyPaint.luau).
const fs = require('fs');
const path = require('path');
const lib = require('./lib.js');
const [, , clustersPath, specsPath, inPath, outPath, previewDir] = process.argv;
const N = lib.N;
const clusters = JSON.parse(fs.readFileSync(clustersPath, 'utf8'));
const specs = JSON.parse(fs.readFileSync(specsPath, 'utf8'));
const CLASS = { body: 1, glass: 8, light: 9, tyre: 10, trim: 11, interior: 12, other: 13 };
const COLOUR = { 1: [255, 0, 255], 8: [30, 60, 200], 9: [255, 230, 60], 10: [20, 20, 20], 11: [160, 160, 170], 12: [120, 80, 40], 13: [70, 70, 70], 0: [0, 0, 0] };
if (previewDir) fs.mkdirSync(previewDir, { recursive: true });

function buildCar(car, spec, cl, texRgb) {
  const assign = Buffer.from(cl.assign, 'base64');
  const classOf = new Array(cl.k).fill(CLASS.other);
  for (const [name, ids] of Object.entries(spec)) if (CLASS[name]) for (const id of ids) classOf[id] = CLASS[name];
  let L = new Uint8Array(N * N);
  for (let i = 0; i < N * N; i++) L[i] = classOf[assign[i]];
  L = lib.modeFilter(L, N, spec.mode === undefined ? 2 : spec.mode);
  let body = new Uint8Array(N * N);
  for (let i = 0; i < N * N; i++) body[i] = L[i] === 1 ? 1 : 0;
  body = lib.dropSmall(body, N, spec.specks || 14, false);
  body = lib.dropSmall(body, N, spec.holes || 24, true);
  if (spec.smooth !== 0) body = lib.smoothBinary(body, N, spec.smooth || 1, 0.5);
  body = lib.dropSmall(body, N, spec.specks || 14, false);
  // non-body labels: where a body speck was removed, take the most common neighbouring non-body label
  const lab = new Uint8Array(N * N);
  for (let i = 0; i < N * N; i++) lab[i] = body[i] ? 1 : (L[i] === 1 ? 0 : L[i]);
  for (let pass = 0; pass < 6; pass++) {
    for (let y = 0; y < N; y++) for (let x = 0; x < N; x++) {
      const i = y * N + x;
      if (lab[i] !== 0) continue;
      const cnt = {};
      let best = 0, bc = 0;
      for (let dy = -1; dy <= 1; dy++) for (let dx = -1; dx <= 1; dx++) {
        const xx = x + dx, yy = y + dy;
        if (xx < 0 || yy < 0 || xx >= N || yy >= N) continue;
        const v = lab[yy * N + xx];
        if (v <= 1) continue;
        cnt[v] = (cnt[v] || 0) + 1;
        if (cnt[v] > bc) { bc = cnt[v]; best = v; }
      }
      if (best) lab[i] = best;
    }
  }
  for (let i = 0; i < N * N; i++) if (lab[i] === 0) lab[i] = CLASS.other;
  // tidy the non-body labels (specks of one class inside another)
  const nb = new Uint8Array(N * N);
  for (let i = 0; i < N * N; i++) nb[i] = lab[i] === 1 ? 0 : lab[i];
  const tidy = lib.modeFilter(nb, N, 1);
  for (let i = 0; i < N * N; i++) if (lab[i] !== 1 && tidy[i] > 1) lab[i] = tidy[i];
  // body shade from the texture's own light and shade, blurred, relative to this car's body mean
  const lum = new Float32Array(N * N), w = new Float32Array(N * N);
  for (let i = 0; i < N * N; i++) if (lab[i] === 1) { lum[i] = 0.3 * texRgb[i * 3] + 0.59 * texRgb[i * 3 + 1] + 0.11 * texRgb[i * 3 + 2]; w[i] = 1; }
  const bl = lib.blurField(lum, N, 3, 3), bw = lib.blurField(w, N, 3, 3);
  let mean = 0, cnt = 0;
  for (let i = 0; i < N * N; i++) if (lab[i] === 1) { mean += lum[i]; cnt++; }
  mean = cnt ? mean / cnt : 128;
  const out = new Uint8Array(N * N);
  for (let i = 0; i < N * N; i++) {
    if (lab[i] !== 1) { out[i] = lab[i]; continue; }
    const r = bw[i] > 0.05 ? (bl[i] / bw[i]) / mean : 1;
    out[i] = r < 0.72 ? 1 : r < 0.88 ? 2 : r < 1.0 ? 3 : r < 1.12 ? 4 : r < 1.28 ? 5 : 6;
  }
  // the shade levels and the region edges both come out smoother (and much shorter to store) after one more mode pass
  return lib.modeFilter(out, N, 2);
}

const old = fs.readFileSync(inPath, 'utf8');
const entries = {};
const re = /^\t\["([^"]+)"\] = "([^"]*)",$/gm;
let m;
while ((m = re.exec(old))) entries[m[1]] = m[2];
const { texturesDir } = JSON.parse(fs.readFileSync(path.join(path.dirname(specsPath), 'textures.json'), 'utf8'));
const stats = {};
for (const [car, spec] of Object.entries(specs)) {
  if (car.startsWith('_')) continue;
  const cl = clusters[car];
  if (!cl) { console.log('no clusters for', car); continue; }
  const img = lib.png.read(path.join(texturesDir, cl.stem + '.png'));
  const texRgb = lib.downscale(img, N);
  const out = buildCar(car, spec, cl, texRgb);
  entries[car] = lib.rleEncode(out, N);
  let body = 0; const per = {};
  for (let i = 0; i < N * N; i++) { const v = out[i]; if (v >= 1 && v <= 6) body++; per[v >= 1 && v <= 6 ? 'body' : v] = (per[v >= 1 && v <= 6 ? 'body' : v] || 0) + 1; }
  stats[car] = { bodyPct: +(100 * body / (N * N)).toFixed(1), bytes: entries[car].length, labels: per };
  if (previewDir) {
    const S = 2, W = N * S * 2, H = N * S;
    const pv = Buffer.alloc(W * H * 3);
    for (let y = 0; y < H; y++) for (let x = 0; x < N * S; x++) {
      const i = ((y / S) | 0) * N + ((x / S) | 0);
      const o = (y * W + x) * 3; pv[o] = texRgb[i * 3]; pv[o + 1] = texRgb[i * 3 + 1]; pv[o + 2] = texRgb[i * 3 + 2];
      const v = out[i]; const o2 = (y * W + N * S + x) * 3;
      if (v >= 1 && v <= 6) { const k = 0.45 + v * 0.1; pv[o2] = 255 * k; pv[o2 + 1] = 0; pv[o2 + 2] = 255 * k; }
      else { const c = COLOUR[v] || [0, 0, 0]; pv[o2] = c[0]; pv[o2 + 1] = c[1]; pv[o2 + 2] = c[2]; }
    }
    lib.png.write(path.join(previewDir, car + '.mask.png'), W, H, pv, 3);
  }
}
const head = old.slice(0, old.indexOf('return table.freeze({'));
const body = Object.keys(entries).sort().map(k => `\t["${k}"] = "${entries[k]}",`).join('\n');
fs.writeFileSync(outPath, head + 'return table.freeze({\n' + body + '\n})\n');
console.log(JSON.stringify(stats, null, 1));
