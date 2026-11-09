// node cluster.js <texture.png> <out.png> [k] [seed]
// Splits a car texture into k colour clusters (Lab k-means, deterministic) and draws: the texture, the cluster map in bright
// distinct colours, and a legend (cluster number, true mean colour, share). Used to decide which clusters are body paint.
const lib = require('./lib.js');
const [, , texPath, outPath, kArg, seedArg] = process.argv;
const k = Number(kArg || 12), seed = Number(seedArg || 1);
const N = lib.N;
const img = lib.png.read(texPath);
const rgb = lib.downscale(img, N);
const lab = lib.toLab(rgb, N);
const km = lib.kmeans(lab, N, k, seed, 30);
const PAL = [[230, 25, 75], [60, 180, 75], [255, 225, 25], [0, 130, 200], [245, 130, 48], [145, 30, 180], [70, 240, 240], [240, 50, 230], [210, 245, 60], [250, 190, 212], [0, 128, 128], [220, 190, 255], [170, 110, 40], [255, 250, 200], [128, 0, 0], [170, 255, 195]];
const S = 2; // scale
const legendW = 150;
const W = N * S * 2 + legendW, H = Math.max(N * S, k * 36 + 10);
const out = Buffer.alloc(W * H * 3, 32);
for (let y = 0; y < N * S; y++) for (let x = 0; x < N * S; x++) {
  const i = ((y / S) | 0) * N + ((x / S) | 0);
  const o = (y * W + x) * 3;
  out[o] = rgb[i * 3]; out[o + 1] = rgb[i * 3 + 1]; out[o + 2] = rgb[i * 3 + 2];
  const o2 = (y * W + N * S + x) * 3;
  const p = PAL[km.assign[i]];
  out[o2] = p[0]; out[o2 + 1] = p[1]; out[o2 + 2] = p[2];
}
// mean true colour per cluster
const mean = Array.from({ length: k }, () => [0, 0, 0, 0]);
for (let i = 0; i < N * N; i++) { const m = mean[km.assign[i]]; m[0] += rgb[i * 3]; m[1] += rgb[i * 3 + 1]; m[2] += rgb[i * 3 + 2]; m[3]++; }
const info = [];
for (let c = 0; c < k; c++) {
  const m = mean[c]; const col = m[3] ? [Math.round(m[0] / m[3]), Math.round(m[1] / m[3]), Math.round(m[2] / m[3])] : [0, 0, 0];
  const y0 = 6 + c * 36, x0 = N * S * 2 + 6;
  for (let y = 0; y < 30; y++) for (let x = 0; x < 28; x++) { const o = ((y0 + y) * W + x0 + x) * 3; out[o] = PAL[c][0]; out[o + 1] = PAL[c][1]; out[o + 2] = PAL[c][2]; }
  for (let y = 0; y < 30; y++) for (let x = 0; x < 28; x++) { const o = ((y0 + y) * W + x0 + 32 + x) * 3; out[o] = col[0]; out[o + 1] = col[1]; out[o + 2] = col[2]; }
  lib.drawText(out, W, x0 + 66, y0 + 4, c, [255, 255, 255], 3);
  lib.drawText(out, W, x0 + 66, y0 + 22, Math.round(100 * km.counts[c] / (N * N)), [200, 200, 200], 1);
  info.push({ cluster: c, rgb: col, share: +(100 * km.counts[c] / (N * N)).toFixed(1) });
}
lib.png.write(outPath, W, H, out, 3);
console.log(JSON.stringify(info));
