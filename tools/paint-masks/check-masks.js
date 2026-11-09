// node check-masks.js <PaintMasks.luau> <PaintMasksRainbow.luau>
// An offline copy of the mask-level checks in src/server/Beta/PaintAudit.luau (painted share, ragged specks under 12 texels, region
// labels): run it after build.js. It does NOT replace the Studio audit (that one runs the real BodyPaint code on the real models).
const fs = require('fs');
const lib = require('./lib.js');
const N = lib.N;
const [, , a, b] = process.argv;
const entries = {};
for (const p of [a, b]) {
  const text = fs.readFileSync(p, 'utf8');
  const re = /^\t\["([^"]+)"\] = "([^"]*)",$/gm;
  let m;
  while ((m = re.exec(text))) entries[m[1]] = m[2];
}
let flags = 0;
for (const key of Object.keys(entries).sort()) {
  const v = lib.rleDecode(entries[key], N);
  const body = new Uint8Array(N * N);
  let painted = 0;
  const labels = {};
  for (let i = 0; i < N * N; i++) { if (v[i] >= 1 && v[i] <= 6) { body[i] = 1; painted++; } labels[v[i]] = (labels[v[i]] || 0) + 1; }
  // specks: 4-connected painted components under 12 texels
  const seen = new Uint8Array(N * N);
  let specks = 0;
  for (let s = 0; s < N * N; s++) {
    if (!body[s] || seen[s]) continue;
    const stack = [s]; seen[s] = 1; let size = 0;
    while (stack.length) {
      const i = stack.pop(); size++;
      const x = i % N, y = (i / N) | 0;
      if (x > 0 && body[i - 1] && !seen[i - 1]) { seen[i - 1] = 1; stack.push(i - 1); }
      if (x < N - 1 && body[i + 1] && !seen[i + 1]) { seen[i + 1] = 1; stack.push(i + 1); }
      if (y > 0 && body[i - N] && !seen[i - N]) { seen[i - N] = 1; stack.push(i - N); }
      if (y < N - 1 && body[i + N] && !seen[i + N]) { seen[i + N] = 1; stack.push(i + N); }
    }
    if (size < 12) specks++;
  }
  const share = 100 * painted / (N * N);
  const bad = [];
  if (share < 8 || share > 90) bad.push('painted share ' + share.toFixed(1) + '%');
  if (specks > 0) bad.push(specks + ' ragged specks');
  for (const k of Object.keys(labels)) if (+k === 7 || +k > 13) bad.push('unknown label ' + k);
  if (bad.length) { flags += bad.length; console.log('FLAG', key.padEnd(22), bad.join('; ')); }
  else console.log('ok  ', key.padEnd(22), 'body ' + share.toFixed(1) + '%');
}
console.log('MASK CHECK: ' + Object.keys(entries).length + ' masks, ' + flags + ' flags -> ' + (flags === 0 ? 'PASS' : 'FAIL'));
