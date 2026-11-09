// Shared helpers for the paint-mask tools (Round 8, C-04). Node only, no packages.
const png = require('./png.js');
const N = 256;

// 1024 (or any square) RGB image -> N x N float RGB by box filter
function downscale(img, n) {
  const f = img.w / n;
  const out = new Float32Array(n * n * 3);
  for (let y = 0; y < n; y++) for (let x = 0; x < n; x++) {
    let r = 0, g = 0, b = 0, c = 0;
    for (let dy = 0; dy < f; dy++) for (let dx = 0; dx < f; dx++) {
      const o = (((y * f + dy) | 0) * img.w + ((x * f + dx) | 0)) * 3;
      r += img.rgb[o]; g += img.rgb[o + 1]; b += img.rgb[o + 2]; c++;
    }
    const k = (y * n + x) * 3; out[k] = r / c; out[k + 1] = g / c; out[k + 2] = b / c;
  }
  return out;
}

function srgbToLin(c) { c /= 255; return c <= 0.04045 ? c / 12.92 : Math.pow((c + 0.055) / 1.055, 2.4); }
function rgbToLab(r, g, b) {
  const R = srgbToLin(r), G = srgbToLin(g), B = srgbToLin(b);
  let X = (R * 0.4124 + G * 0.3576 + B * 0.1805) / 0.95047, Y = R * 0.2126 + G * 0.7152 + B * 0.0722, Z = (R * 0.0193 + G * 0.1192 + B * 0.9505) / 1.08883;
  const f = (t) => (t > 0.008856 ? Math.cbrt(t) : 7.787 * t + 16 / 116);
  X = f(X); Y = f(Y); Z = f(Z);
  return [116 * Y - 16, 500 * (X - Y), 200 * (Y - Z)];
}
function toLab(rgb, n) {
  const lab = new Float32Array(n * n * 3);
  for (let i = 0; i < n * n; i++) {
    const l = rgbToLab(rgb[i * 3], rgb[i * 3 + 1], rgb[i * 3 + 2]);
    lab[i * 3] = l[0]; lab[i * 3 + 1] = l[1]; lab[i * 3 + 2] = l[2];
  }
  return lab;
}

// small seeded RNG
function rng(seed) { let s = seed >>> 0; return () => { s = (s + 0x6d2b79f5) >>> 0; let t = s; t = Math.imul(t ^ (t >>> 15), t | 1); t ^= t + Math.imul(t ^ (t >>> 7), t | 61); return ((t ^ (t >>> 14)) >>> 0) / 4294967296; }; }

// k-means++ on Lab, deterministic. Returns { assign: Uint8Array, centres: [[L,a,b]], counts }
function kmeans(lab, n, k, seed, iters) {
  const total = n * n;
  const R = rng(seed || 1);
  const centres = [];
  const first = Math.floor(R() * total);
  centres.push([lab[first * 3], lab[first * 3 + 1], lab[first * 3 + 2]]);
  const d2 = new Float32Array(total).fill(1e9);
  while (centres.length < k) {
    const c = centres[centres.length - 1];
    let sum = 0;
    for (let i = 0; i < total; i++) {
      const dl = lab[i * 3] - c[0], da = lab[i * 3 + 1] - c[1], db = lab[i * 3 + 2] - c[2];
      const d = dl * dl + da * da + db * db;
      if (d < d2[i]) d2[i] = d;
      sum += d2[i];
    }
    let t = R() * sum, pick = total - 1;
    for (let i = 0; i < total; i++) { t -= d2[i]; if (t <= 0) { pick = i; break; } }
    centres.push([lab[pick * 3], lab[pick * 3 + 1], lab[pick * 3 + 2]]);
  }
  const assign = new Uint8Array(total);
  for (let it = 0; it < (iters || 25); it++) {
    const sums = centres.map(() => [0, 0, 0, 0]);
    for (let i = 0; i < total; i++) {
      let best = 0, bd = 1e12;
      for (let c = 0; c < k; c++) {
        const dl = lab[i * 3] - centres[c][0], da = lab[i * 3 + 1] - centres[c][1], db = lab[i * 3 + 2] - centres[c][2];
        const d = dl * dl + da * da + db * db;
        if (d < bd) { bd = d; best = c; }
      }
      assign[i] = best;
      const s = sums[best]; s[0] += lab[i * 3]; s[1] += lab[i * 3 + 1]; s[2] += lab[i * 3 + 2]; s[3]++;
    }
    for (let c = 0; c < k; c++) if (sums[c][3] > 0) centres[c] = [sums[c][0] / sums[c][3], sums[c][1] / sums[c][3], sums[c][2] / sums[c][3]];
  }
  const counts = new Array(k).fill(0);
  for (let i = 0; i < total; i++) counts[assign[i]]++;
  return { assign, centres, counts };
}

// 3x3 mode filter on a label image (Uint8Array n*n)
function modeFilter(lab, n, passes) {
  let cur = lab;
  for (let p = 0; p < (passes || 1); p++) {
    const out = new Uint8Array(n * n);
    for (let y = 0; y < n; y++) for (let x = 0; x < n; x++) {
      const cnt = {};
      let best = cur[y * n + x], bc = 0;
      for (let dy = -1; dy <= 1; dy++) for (let dx = -1; dx <= 1; dx++) {
        const xx = Math.min(n - 1, Math.max(0, x + dx)), yy = Math.min(n - 1, Math.max(0, y + dy));
        const v = cur[yy * n + xx];
        cnt[v] = (cnt[v] || 0) + (dx === 0 && dy === 0 ? 1.5 : 1);
        if (cnt[v] > bc) { bc = cnt[v]; best = v; }
      }
      out[y * n + x] = best;
    }
    cur = out;
  }
  return cur;
}

// remove connected components of a binary mask smaller than minSize (4-connected); returns new Uint8Array. fill=true removes holes instead
function dropSmall(bin, n, minSize, fill) {
  const out = Uint8Array.from(bin);
  const want = fill ? 0 : 1;
  const seen = new Uint8Array(n * n);
  const stack = [];
  for (let s = 0; s < n * n; s++) {
    if (seen[s] || out[s] !== want) continue;
    const comp = [];
    stack.push(s); seen[s] = 1;
    while (stack.length) {
      const i = stack.pop(); comp.push(i);
      const x = i % n, y = (i / n) | 0;
      if (x > 0 && !seen[i - 1] && out[i - 1] === want) { seen[i - 1] = 1; stack.push(i - 1); }
      if (x < n - 1 && !seen[i + 1] && out[i + 1] === want) { seen[i + 1] = 1; stack.push(i + 1); }
      if (y > 0 && !seen[i - n] && out[i - n] === want) { seen[i - n] = 1; stack.push(i - n); }
      if (y < n - 1 && !seen[i + n] && out[i + n] === want) { seen[i + n] = 1; stack.push(i + n); }
    }
    if (comp.length < minSize) for (const i of comp) out[i] = 1 - want;
  }
  return out;
}

// gaussian-ish blur of a float field (separable box x3), then threshold: smooth the contour of a binary mask
function smoothBinary(bin, n, radius, thr) {
  let a = Float32Array.from(bin);
  for (let pass = 0; pass < 3; pass++) {
    const t = new Float32Array(n * n), u = new Float32Array(n * n);
    for (let y = 0; y < n; y++) for (let x = 0; x < n; x++) {
      let s = 0, c = 0;
      for (let d = -radius; d <= radius; d++) { const xx = x + d; if (xx >= 0 && xx < n) { s += a[y * n + xx]; c++; } }
      t[y * n + x] = s / c;
    }
    for (let y = 0; y < n; y++) for (let x = 0; x < n; x++) {
      let s = 0, c = 0;
      for (let d = -radius; d <= radius; d++) { const yy = y + d; if (yy >= 0 && yy < n) { s += t[yy * n + x]; c++; } }
      u[y * n + x] = s / c;
    }
    a = u;
  }
  const out = new Uint8Array(n * n);
  for (let i = 0; i < n * n; i++) out[i] = a[i] >= thr ? 1 : 0;
  return out;
}

// blur a float field with box blur passes
function blurField(f, n, radius, passes) {
  let a = Float32Array.from(f);
  for (let p = 0; p < passes; p++) {
    const t = new Float32Array(n * n), u = new Float32Array(n * n);
    for (let y = 0; y < n; y++) for (let x = 0; x < n; x++) {
      let s = 0, c = 0;
      for (let d = -radius; d <= radius; d++) { const xx = x + d; if (xx >= 0 && xx < n) { s += a[y * n + xx]; c++; } }
      t[y * n + x] = s / c;
    }
    for (let y = 0; y < n; y++) for (let x = 0; x < n; x++) {
      let s = 0, c = 0;
      for (let d = -radius; d <= radius; d++) { const yy = y + d; if (yy >= 0 && yy < n) { s += t[yy * n + x]; c++; } }
      u[y * n + x] = s / c;
    }
    a = u;
  }
  return a;
}

// run-length code a value image (0..15) the way PaintMasks.luau expects: two bytes per run, value in the high nibble of byte 1
function rleEncode(values, n) {
  const bytes = [];
  let i = 0;
  const total = n * n;
  while (i < total) {
    const v = values[i];
    let len = 1;
    while (i + len < total && values[i + len] === v && len < 4096) len++;
    bytes.push((v << 4) | ((len - 1) >> 8), (len - 1) & 255);
    i += len;
  }
  return Buffer.from(bytes).toString('base64');
}
function rleDecode(text, n) {
  const bytes = Buffer.from(text, 'base64');
  const out = new Uint8Array(n * n);
  let at = 0;
  for (let i = 0; i + 1 < bytes.length; i += 2) {
    const hi = bytes[i], v = hi >> 4, len = ((hi & 15) << 8) + bytes[i + 1] + 1;
    for (let k = 0; k < len && at + k < n * n; k++) out[at + k] = v;
    at += len;
    if (at >= n * n) break;
  }
  return out;
}

// a 3x5 digit font for labelling
const FONT = { 0: '111101101101111', 1: '010110010010111', 2: '111001111100111', 3: '111001111001111', 4: '101101111001001', 5: '111100111001111', 6: '111100111101111', 7: '111001001001001', 8: '111101111101111', 9: '111101111001111' };
function drawText(buf, W, x, y, text, rgb, scale) {
  scale = scale || 2;
  let cx = x;
  for (const ch of String(text)) {
    const g = FONT[ch];
    if (g) {
      for (let r = 0; r < 5; r++) for (let c = 0; c < 3; c++) if (g[r * 3 + c] === '1')
        for (let sy = 0; sy < scale; sy++) for (let sx = 0; sx < scale; sx++) {
          const o = ((y + r * scale + sy) * W + cx + c * scale + sx) * 3;
          if (o >= 0 && o < buf.length - 2) { buf[o] = rgb[0]; buf[o + 1] = rgb[1]; buf[o + 2] = rgb[2]; }
        }
    }
    cx += 4 * scale;
  }
}

module.exports = { png, N, downscale, toLab, rgbToLab, kmeans, modeFilter, dropSmall, smoothBinary, blurField, rleEncode, rleDecode, drawText, rng };
