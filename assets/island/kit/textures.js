// Island environment effect textures (Lane 3). Original, procedurally drawn and seeded; writes
// soft-edged PNGs (RGBA) for the waterfall beams, foam, ripples, droplets, mist, rainbow,
// sparkle, currents and the vegetation palette. Run from the repository root:
//   node assets/island/kit/textures.js C:\Users\agert\Documents\Car-Hop-Art\island-kit\textures
// The PNGs are art sources and stay outside Git; this script is the recipe.
//
// Beam textures: Roblox maps U along the beam and V across it, so water streaks run along the
// image's width. Tiling textures wrap seamlessly on both axes.

"use strict";
const fs = require("fs");
const path = require("path");
const zlib = require("zlib");

const OUT = process.argv[2] || path.join(__dirname, "out");
const SEED = 20261021;

// ---------- PNG ----------
const crcTable = (() => {
	const t = new Uint32Array(256);
	for (let n = 0; n < 256; n++) {
		let c = n;
		for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
		t[n] = c >>> 0;
	}
	return t;
})();
function crc32(buf) {
	let c = 0xffffffff;
	for (const b of buf) c = crcTable[(c ^ b) & 0xff] ^ (c >>> 8);
	return (c ^ 0xffffffff) >>> 0;
}
function chunk(type, data) {
	const len = Buffer.alloc(4);
	len.writeUInt32BE(data.length);
	const td = Buffer.concat([Buffer.from(type), data]);
	const crc = Buffer.alloc(4);
	crc.writeUInt32BE(crc32(td));
	return Buffer.concat([len, td, crc]);
}
function writePng(file, w, h, rgba) {
	const raw = Buffer.alloc((w * 4 + 1) * h);
	for (let y = 0; y < h; y++) {
		raw[y * (w * 4 + 1)] = 0;
		for (let x = 0; x < w * 4; x++) raw[y * (w * 4 + 1) + 1 + x] = rgba[y * w * 4 + x];
	}
	const ihdr = Buffer.alloc(13);
	ihdr.writeUInt32BE(w, 0);
	ihdr.writeUInt32BE(h, 4);
	ihdr[8] = 8;
	ihdr[9] = 6;
	const png = Buffer.concat([
		Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]),
		chunk("IHDR", ihdr),
		chunk("IDAT", zlib.deflateSync(raw, { level: 9 })),
		chunk("IEND", Buffer.alloc(0)),
	]);
	fs.writeFileSync(file, png);
}

// ---------- noise ----------
function rng(seed) {
	let s = seed >>> 0;
	return () => {
		s = (s + 0x6d2b79f5) >>> 0;
		let t = s;
		t = Math.imul(t ^ (t >>> 15), t | 1);
		t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
		return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
	};
}
// tileable value noise on a periodic lattice (px by py cells)
function makeNoise(seed, px, py) {
	const r = rng(seed);
	const g = new Float32Array(px * py).map(() => r());
	const at = (i, j) => g[((j % py) + py) % py * px + (((i % px) + px) % px)];
	const s = (t) => t * t * (3 - 2 * t);
	return (u, v) => {
		const x = u * px;
		const y = v * py;
		const i = Math.floor(x);
		const j = Math.floor(y);
		const fx = s(x - i);
		const fy = s(y - j);
		const a = at(i, j) + (at(i + 1, j) - at(i, j)) * fx;
		const b = at(i, j + 1) + (at(i + 1, j + 1) - at(i, j + 1)) * fx;
		return a + (b - a) * fy;
	};
}
function fbm(seed, px, py, octaves) {
	const layers = [];
	for (let o = 0; o < octaves; o++) layers.push(makeNoise(seed + o * 97, px << o, py << o));
	return (u, v) => {
		let sum = 0;
		let amp = 1;
		let norm = 0;
		for (const n of layers) {
			sum += n(u, v) * amp;
			norm += amp;
			amp *= 0.5;
		}
		return sum / norm;
	};
}
const clamp = (x, a = 0, b = 1) => Math.min(b, Math.max(a, x));
const smooth = (a, b, x) => {
	const t = clamp((x - a) / (b - a));
	return t * t * (3 - 2 * t);
};

function image(w, h, fn) {
	const px = new Uint8Array(w * h * 4);
	for (let y = 0; y < h; y++)
		for (let x = 0; x < w; x++) {
			const [r, g, b, a] = fn((x + 0.5) / w, (y + 0.5) / h);
			const i = (y * w + x) * 4;
			px[i] = Math.round(clamp(r) * 255);
			px[i + 1] = Math.round(clamp(g) * 255);
			px[i + 2] = Math.round(clamp(b) * 255);
			px[i + 3] = Math.round(clamp(a) * 255);
		}
	return { w, h, px };
}

// ---------- textures ----------
// Water streaks: bands across V (one per strand) that break along U into dashes with gaps.
// Colour is white (beam Color tints it); alpha carries the shape.
function streaks({ seed, strands, gapBias, softness, brokenness, w = 512, h = 128 }) {
	const r = rng(seed);
	const bands = [];
	for (let k = 0; k < strands; k++)
		bands.push({ v: r(), width: 0.015 + r() * 0.05, gate: makeNoise(seed + 11 * k, 6 + Math.floor(r() * 6), 1), shift: r() });
	const fine = fbm(seed + 3, 16, 8, 3);
	return image(w, h, (u, v) => {
		let a = 0;
		for (const b of bands) {
			let dv = Math.abs(v - b.v);
			dv = Math.min(dv, 1 - dv); // wraps across V
			const core = 1 - smooth(b.width * (1 - softness), b.width, dv);
			const g = b.gate((u + b.shift) % 1, 0.5);
			const on = smooth(gapBias, gapBias + 0.12, g);
			a = Math.max(a, core * on);
		}
		const grain = 0.75 + 0.25 * fine(u, v);
		const broken = 1 - brokenness * smooth(0.35, 0.65, fine((u * 2) % 1, v));
		const al = a * grain * broken;
		return [1, 1, 1, al];
	});
}

// Soft lacy foam, tileable: thresholded fbm with soft edges and holes.
function foamTile(seed, w = 256, h = 256) {
	const n = fbm(seed, 8, 8, 4);
	const holes = fbm(seed + 7, 16, 16, 2);
	return image(w, h, (u, v) => {
		const f = smooth(0.45, 0.62, n(u, v)) * (1 - 0.7 * smooth(0.55, 0.7, holes(u, v)));
		return [1, 1, 1, f * 0.95];
	});
}

// A lacy foam patch with a soft round falloff (for particles and floating patches).
function foamPatch(seed, w = 256, h = 256) {
	const n = fbm(seed, 6, 6, 4);
	return image(w, h, (u, v) => {
		const d = Math.hypot(u - 0.5, v - 0.5) * 2;
		const fall = 1 - smooth(0.45, 1, d + 0.25 * (n(u, v) - 0.5));
		const lace = smooth(0.38, 0.6, n(u, v));
		return [1, 1, 1, fall * lace];
	});
}

function ripple(w = 256, h = 256) {
	return image(w, h, (u, v) => {
		const d = Math.hypot(u - 0.5, v - 0.5) * 2;
		const ring = Math.exp(-Math.pow((d - 0.78) / 0.07, 2)) + 0.35 * Math.exp(-Math.pow((d - 0.6) / 0.05, 2));
		return [1, 1, 1, clamp(ring) * (1 - smooth(0.92, 1, d))];
	});
}

function droplet(w = 64, h = 64) {
	return image(w, h, (u, v) => {
		const d = Math.hypot(u - 0.5, (v - 0.5) * 0.8) * 2;
		const body = 1 - smooth(0.55, 1, d);
		const glint = Math.exp(-Math.pow(Math.hypot(u - 0.4, v - 0.36) / 0.08, 2));
		return [0.85 + 0.15 * glint, 0.93 + 0.07 * glint, 1, body];
	});
}

function mist(seed, w = 256, h = 256) {
	const n = fbm(seed, 4, 4, 4);
	return image(w, h, (u, v) => {
		const d = Math.hypot(u - 0.5, v - 0.5) * 2;
		const a = (1 - smooth(0.2, 1, d)) * (0.55 + 0.45 * n(u, v));
		return [1, 1, 1, a * 0.8];
	});
}

// Rainbow band: colours across V (beam width), soft at both edges, constant along U.
function rainbow(w = 64, h = 256) {
	const stops = [
		[0.0, [0.55, 0.3, 0.85]],
		[0.18, [0.3, 0.45, 0.95]],
		[0.36, [0.25, 0.8, 0.9]],
		[0.52, [0.4, 0.9, 0.4]],
		[0.68, [1.0, 0.92, 0.35]],
		[0.84, [1.0, 0.6, 0.25]],
		[1.0, [0.95, 0.3, 0.3]],
	];
	const col = (t) => {
		for (let i = 1; i < stops.length; i++)
			if (t <= stops[i][0]) {
				const [t0, c0] = stops[i - 1];
				const [t1, c1] = stops[i];
				const f = (t - t0) / (t1 - t0);
				return c0.map((c, k) => c + (c1[k] - c) * f);
			}
		return stops[stops.length - 1][1];
	};
	return image(w, h, (u, v) => {
		const t = (v - 0.15) / 0.7;
		const a = smooth(0, 0.2, t) * (1 - smooth(0.8, 1, t));
		const [r, g, b] = col(clamp(t));
		return [r, g, b, a * 0.85];
	});
}

function sparkle(w = 64, h = 64) {
	return image(w, h, (u, v) => {
		const dx = u - 0.5;
		const dy = v - 0.5;
		const d = Math.hypot(dx, dy) * 2;
		const core = Math.exp(-Math.pow(d / 0.18, 2));
		const rays = Math.exp(-Math.pow(dx / 0.025, 2)) * Math.exp(-Math.pow(dy / 0.4, 2)) + Math.exp(-Math.pow(dy / 0.025, 2)) * Math.exp(-Math.pow(dx / 0.4, 2));
		return [1, 1, 1, clamp(core + 0.8 * rays) * (1 - smooth(0.9, 1, d))];
	});
}

function glow(w = 64, h = 64) {
	return image(w, h, (u, v) => {
		const d = Math.hypot(u - 0.5, v - 0.5) * 2;
		return [1, 1, 1, Math.pow(1 - smooth(0, 1, d), 2)];
	});
}

// Currents: elongated foam streaks along U, broken, tileable; soft at both edges across V.
function current(seed, w = 512, h = 128) {
	const n = fbm(seed, 4, 8, 4);
	const lace = fbm(seed + 5, 16, 16, 3);
	return image(w, h, (u, v) => {
		const edge = smooth(0, 0.25, v) * (1 - smooth(0.75, 1, v));
		const streak = smooth(0.5, 0.7, n(u, (v * 3) % 1));
		return [1, 1, 1, edge * streak * (0.4 + 0.6 * lace(u, v))];
	});
}

// Boost-lane chevron: one soft white chevron per tile. Beams lay this texture with its V axis
// along the beam (seen in Studio, 2026-10-21: a chevron drawn along U came out sideways), so the
// chevron points along -V (toward the top of the image), with clear space before and after.
// Soft edges, a slightly brighter core, transparent elsewhere.
function chevron(w = 64, h = 128) {
	const seg = (px, py, ax, ay, bx, by) => {
		const dx = bx - ax, dy = by - ay;
		const t = clamp(((px - ax) * dx + (py - ay) * dy) / (dx * dx + dy * dy));
		return Math.hypot(px - (ax + dx * t), py - (ay + dy * t));
	};
	return image(w, h, (u, v) => {
		// in tile units: u 0..1 across, v 0..1 along, aspect 1:2
		const x = u, y = v * 2;
		const d = Math.min(seg(x, y, 0.14, 1.38, 0.5, 0.78), seg(x, y, 0.86, 1.38, 0.5, 0.78));
		const a = 1 - smooth(0.055, 0.095, d);
		const core = 1 - smooth(0, 0.05, d);
		return [1, 1, 1, clamp(0.85 * a + 0.15 * core)];
	});
}

// ---------- portal energy field and race dressing (Task 3) ----------
// The portal is a frameless field about 20 x 30 studs: several translucent layers that rotate or
// scroll inside a rounded clip, plus a soft edge veil. All of these are white or grey (the game
// tints them with ImageColor3 or Beam Color); alpha carries the shape and reaches exactly 0 at
// the image border wherever an image may be rotated or scaled, so no square edge ever shows.
// The noise lattices are periodic, so any real coordinate is valid and angles wrap seamlessly.

// Supersampled image (ss x ss samples per pixel) for hard-edged flat art such as flags.
function imageSS(w, h, ss, fn) {
	const px = new Uint8Array(w * h * 4);
	for (let y = 0; y < h; y++)
		for (let x = 0; x < w; x++) {
			let r = 0, g = 0, b = 0, a = 0;
			for (let sy = 0; sy < ss; sy++)
				for (let sx = 0; sx < ss; sx++) {
					const c = fn((x + (sx + 0.5) / ss) / w, (y + (sy + 0.5) / ss) / h);
					const ca = clamp(c[3]);
					r += clamp(c[0]) * ca;
					g += clamp(c[1]) * ca;
					b += clamp(c[2]) * ca;
					a += ca;
				}
			const i = (y * w + x) * 4;
			const n = ss * ss;
			px[i] = Math.round(a > 0 ? (r / a) * 255 : 255);
			px[i + 1] = Math.round(a > 0 ? (g / a) * 255 : 255);
			px[i + 2] = Math.round(a > 0 ? (b / a) * 255 : 255);
			px[i + 3] = Math.round((a / n) * 255);
		}
	return { w, h, px };
}

// Spiral cloud vortex. Polar coordinates with the spiral phase phi = dir * theta + twist * ln r;
// arms come from cos(arms * phi) and the cloud is fbm sampled in (phi, ln r), warped by a
// Cartesian fbm. The noise covers the whole circle, so arms never repeat one another.
// Alpha is exactly 0 from radius `edge` (in image widths) outward.
// `wisp` noise is stretched along the arms (many cells around, few along ln r) for streaky
// wisps; a Cartesian billow layer breaks the arms into puffs so they read as cloud, not ribbon.
// Near the centre the arms blend into a smooth core so the spiral never pinches into moire.
function portalSwirl({ seed, arms, twist, dir, cloudCells, wispCells, wispAmt, armSharp, broken, warpAmt, edge = 0.48, w = 512, h = 512 }) {
	const warp = fbm(seed + 1, 5, 5, 4);
	const warp2 = fbm(seed + 2, 6, 6, 3);
	const cloud = fbm(seed + 3, cloudCells[0], cloudCells[1], 5);
	const holes = fbm(seed + 4, cloudCells[0] * 2, cloudCells[1] * 2, 3);
	const wisp = fbm(seed + 5, wispCells[0], wispCells[1], 4);
	const puff = [];
	for (let o = 0; o < 5; o++) puff.push(makeNoise(seed + 6 + o * 31, 6 << o, 6 << o));
	const billow = (u, v) => {
		let sum = 0, amp = 1, norm = 0;
		for (const n of puff) {
			sum += Math.abs(2 * n(u, v) - 1) * amp;
			norm += amp;
			amp *= 0.5;
		}
		return sum / norm;
	};
	const TAU = Math.PI * 2;
	return image(w, h, (u, v) => {
		const x = u - 0.5;
		const y = v - 0.5;
		const r = Math.hypot(x, y);
		if (r >= edge) return [1, 1, 1, 0];
		const th = Math.atan2(y, x);
		const lr = Math.log(Math.max(r, 0.004));
		const phi = dir * th + twist * lr + warpAmt * (warp(u, v) - 0.5) * TAU;
		const s = phi / TAU;
		const rv = (lr + 6.5) / 7 + 0.06 * (warp2(u, v) - 0.5);
		const c = cloud(s, rv);
		const wave = 0.5 + 0.5 * Math.cos(arms * phi + (c - 0.5) * 4);
		const arm = Math.pow(wave, armSharp);
		const ws = wisp(s, rv);
		let dens = smooth(0.12, 0.95, arm * 0.6 + c * 0.7 + (ws - 0.5) * wispAmt - 0.2);
		dens *= 1 - broken * smooth(0.45, 0.68, holes(s * 2, rv * 1.7));
		dens *= 0.55 + 0.45 * smooth(0.15, 0.6, billow(u + 0.1 * (warp2(v, u) - 0.5), v));
		const cb = Math.exp(-r / 0.035);
		dens = dens * (1 - cb) + 0.85 * cb;
		const inner = 0.45 + 0.55 * Math.exp(-r / 0.2); // brighter towards the centre
		const core = Math.exp(-Math.pow(r / 0.07, 2));
		const fall = 1 - smooth(edge * 0.55, edge, r);
		const a = clamp(dens * inner + core * 0.7) * fall;
		const lum = 0.72 + 0.28 * clamp(dens * inner + core);
		return [lum, lum, lum, a];
	});
}

// Seamless billowy cloud: sum of |2n - 1| octaves (billow noise: round puffs with soft dark
// creases), domain-warped by a periodic field so the tile still wraps. Alpha 0.25 to 1.
function portalCloudTile(seed, w = 512, h = 512) {
	const oct = [];
	for (let o = 0; o < 6; o++) oct.push(makeNoise(seed + o * 131, 4 << o, 4 << o));
	const wx = fbm(seed + 50, 4, 4, 3);
	const wy = fbm(seed + 60, 4, 4, 3);
	const base = fbm(seed + 70, 3, 3, 5);
	return image(w, h, (u, v) => {
		const pu = u + 0.35 * (wx(u, v) - 0.5);
		const pv = v + 0.35 * (wy(u, v) - 0.5);
		let sum = 0, amp = 1, norm = 0;
		for (const n of oct) {
			sum += Math.abs(2 * n(pu, pv) - 1) * amp;
			norm += amp;
			amp *= 0.42; // weak high octaves: soft puffs, no contour grain
		}
		const b = 0.6 * base(pu, pv) + 0.4 * (sum / norm);
		const t = smooth(0.3, 0.62, b);
		const lum = 0.7 + 0.3 * t;
		return [lum, lum, lum, 0.25 + 0.75 * t];
	});
}

// Luminous core: soft radial glow, rim wobbled by angular and 2D noise, 0 at the border.
function portalCore(seed, w = 256, h = 256) {
	const rimN = fbm(seed, 9, 1, 4);
	const n2 = fbm(seed + 1, 8, 8, 4);
	return image(w, h, (u, v) => {
		const x = u - 0.5;
		const y = v - 0.5;
		const d = Math.hypot(x, y) * 2;
		const s = Math.atan2(y, x) / (Math.PI * 2);
		const dd = d * (1 + 0.22 * (rimN(s, 0.5) - 0.5) + 0.1 * (n2(u, v) - 0.5));
		const glowA = 0.85 * Math.exp(-Math.pow(dd / 0.3, 2)) + 0.4 * Math.exp(-dd / 0.28);
		const rim = 0.13 * Math.exp(-Math.pow((dd - 0.5) / 0.1, 2)) * (0.4 + 1.2 * n2(u * 2, v * 2));
		const a = clamp(glowA + rim) * (1 - smooth(0.62, 0.97, d));
		const lum = 0.8 + 0.2 * clamp(glowA * 1.2);
		return [lum, lum, lum, a];
	});
}

// Rounded rectangle shared by the veil and the mask, in units of image width (Y runs 0..h/w).
// Inset 8% of each image dimension, so the rect keeps the image's 2:3 shape; corner radius is
// 30% of the rect's width.
function portalRect(w, h) {
	const H = h / w;
	const hx = 0.5 * 0.84;
	const hy = 0.5 * 0.84 * H;
	const R = 0.3 * 0.84;
	return (u, v) => {
		const X = u - 0.5;
		const Y = (v - 0.5) * H;
		const qx = Math.abs(X) - (hx - R);
		const qy = Math.abs(Y) - (hy - R);
		const d = Math.hypot(Math.max(qx, 0), Math.max(qy, 0)) + Math.min(Math.max(qx, qy), 0) - R;
		const s = Math.atan2(Y / hy, X / hx) / (Math.PI * 2); // perimeter parameter, wraps seamlessly
		return { d, s };
	};
}

// Distance (pixels) from a pixel centre to the nearest image edge; 0.5 on the border pixels.
const edgePx = (u, v, w, h) => Math.min(u * w, (1 - u) * w, v * h, (1 - v) * h);

// The field's fluid edge: a luminous band on the rounded rect with flame tendrils that point
// along the edge normal, tapering as they reach inward (longer) and outward (shorter).
function portalVeil(seed, w = 512, h = 768) {
	const rect = portalRect(w, h);
	const wob = fbm(seed + 1, 6, 9, 4);
	const curl = fbm(seed + 2, 5, 7, 3);
	const flame = fbm(seed + 3, 90, 5, 4);
	const flick = fbm(seed + 4, 180, 9, 3);
	const pulse = fbm(seed + 5, 14, 1, 3);
	return image(w, h, (u, v) => {
		const { d, s } = rect(u, v);
		const dw = d + 0.026 * (wob(u, v) - 0.5);
		const p = pulse(s, 0.5); // brightness and thickness drift along the edge
		const bw = 0.008 + 0.012 * p;
		const band = (0.45 + 0.45 * p) * Math.exp(-Math.pow(dw / bw, 2)) + 0.3 * Math.exp(-Math.pow(dw / 0.04, 2));
		const sw = s + 0.03 * (curl(u, v) - 0.5) + 1.2 * dw * (curl(u * 2, v * 2) - 0.5);
		const t = flame(sw, (dw + 0.32) / 0.5) * 0.7 + flick(sw, (dw + 0.32) / 0.35) * 0.3;
		const inward = dw < 0;
		const reach = inward ? -dw : dw;
		const thr = 0.42 + reach * (inward ? 2.0 : 5.0);
		const env = inward ? Math.exp(-reach / 0.08) : Math.exp(-reach / 0.028);
		const tendril = smooth(thr, thr + 0.28, t) * env;
		const fade = smooth(0.5, 26, edgePx(u, v, w, h));
		const a = clamp(band + 0.95 * tendril) * fade;
		const lum = 0.75 + 0.25 * clamp(band * 1.3);
		return [lum, lum, lum, a];
	});
}

// Depth backing: the same rounded rect filled, alpha 1 inside, noisy soft falloff over the
// last 6% of the width to exactly 0 at the rect edge.
function portalMask(seed, w = 512, h = 768) {
	const rect = portalRect(w, h);
	const n = fbm(seed, 10, 15, 4);
	return image(w, h, (u, v) => {
		const { d } = rect(u, v);
		const dd = d + 0.02 * (n(u, v) - 0.5) - 0.01;
		return [1, 1, 1, 1 - smooth(-0.06, 0, dd)];
	});
}

// Frameless field shapes (Task 3 review fix, 2026-10-22): no rectangle, ring or border anywhere.
// Elliptical distance with a noisy, wispy radius, so the outline is soft and irregular.
function ovalDist(u, v, rn, s0) {
	const x = (u - 0.5) * 2;
	const y = (v - 0.5) * 2;
	const d = Math.hypot(x, y);
	const a = Math.atan2(y, x) / (Math.PI * 2) + 0.5;
	return d * (1 + 0.16 * (rn(a, s0) - 0.5) * 2);
}

// The field's coloured depth: a soft vertical oval, fully opaque in the middle and fading over
// the outer third through broken wisps (no rim, no edge line).
function portalDepth(seed, w = 384, h = 576) {
	const rn = fbm(seed, 12, 1, 4);
	const wisp = fbm(seed + 1, 24, 36, 5);
	return image(w, h, (u, v) => {
		const d = ovalDist(u, v, rn, 0.5);
		const n = wisp(u, v);
		const a = 1 - smooth(0.5, 0.98, d + 0.12 * (n - 0.5));
		const lum = 0.75 + 0.25 * (1 - smooth(0, 0.8, d));
		return [lum, lum, lum, clamp(a)];
	});
}

// The recess: a broad, soft, broken band just inside the oval's edge (alpha only; drawn dark
// and unlit so the field seems to sink inward). Wide and feathered on both sides, never a line.
function portalBand(seed, w = 384, h = 576) {
	const rn = fbm(seed, 12, 1, 4);
	const n = fbm(seed + 1, 20, 30, 4);
	return image(w, h, (u, v) => {
		const d = ovalDist(u, v, rn, 0.5);
		const a = smooth(0.5, 0.74, d) * (1 - smooth(0.8, 0.97, d)) * (0.7 + 0.3 * n(u, v));
		return [1, 1, 1, clamp(a)];
	});
}

// A cloudy ball for the swirling body: billowy noise inside a soft oval falloff.
function portalCloudBall(seed, w = 384, h = 576) {
	const rn = fbm(seed, 10, 1, 4);
	const n = fbm(seed + 2, 6, 9, 5);
	const n2 = fbm(seed + 3, 14, 21, 4);
	return image(w, h, (u, v) => {
		const d = ovalDist(u, v, rn, 0.3);
		const c = clamp((n(u, v) - 0.35) * 2.2) * (0.6 + 0.4 * n2(u, v));
		const fall = 1 - smooth(0.35, 0.95, d + 0.18 * (n2(u, v) - 0.5));
		const lum = 0.7 + 0.3 * c;
		return [lum, lum, lum, clamp(c * fall * 1.2)];
	});
}

// Vertical light beam: bright centre column, wide soft halo, 0 at left and right edges,
// fading out toward the top (v = 0) and softly at the bottom.
function portalBeam(seed, w = 64, h = 256) {
	const n = fbm(seed, 6, 3, 3);
	return image(w, h, (u, v) => {
		const x = Math.abs(u - 0.5) * 2;
		const col = 0.8 * Math.exp(-Math.pow(x / 0.2, 2)) + 0.35 * Math.exp(-Math.pow(x / 0.55, 2));
		const side = 1 - smooth(0.6, 0.97, x);
		const along = smooth(0.0, 0.8, v) * (1 - smooth(0.9, 0.995, v));
		const a = clamp(col) * side * along * (0.85 + 0.15 * n(u, v));
		const lum = 0.8 + 0.2 * Math.exp(-Math.pow(x / 0.2, 2));
		return [lum, lum, lum, a];
	});
}

// Round light pool for the ground (scale it to an ellipse in game), faint rings, 0 at the border.
function groundPool(w = 256, h = 256) {
	return image(w, h, (u, v) => {
		const d = Math.hypot(u - 0.5, v - 0.5) * 2;
		const base = Math.pow(1 - smooth(0, 0.96, d), 1.5);
		const rings = 1 + 0.16 * Math.cos(d * Math.PI * 2 * 4.5) * smooth(0.12, 0.35, d);
		return [1, 1, 1, clamp(base * rings * 0.95)];
	});
}

function mote(w = 64, h = 64) {
	return image(w, h, (u, v) => {
		const d = Math.hypot(u - 0.5, v - 0.5) * 2;
		const halo = 0.75 * Math.exp(-Math.pow(d / 0.42, 2));
		const centre = Math.exp(-Math.pow(d / 0.1, 2));
		const a = clamp(halo + centre) * (1 - smooth(0.75, 0.96, d));
		const lum = 0.78 + 0.22 * centre;
		return [lum, lum, lum, a];
	});
}

// Small vertical spark: a bright head near the top with a softer tail below it.
function ember(w = 64, h = 64) {
	return image(w, h, (u, v) => {
		const x = (u - 0.5) * 2;
		const y = (v - 0.5) * 2;
		const body = Math.exp(-(Math.pow(x / 0.18, 2) + Math.pow((y + 0.1) / (y < -0.1 ? 0.45 : 0.75), 2)));
		const head = Math.exp(-(Math.pow(x / 0.08, 2) + Math.pow((y + 0.28) / 0.14, 2)));
		const edge = 1 - smooth(0.8, 0.97, Math.max(Math.abs(x), Math.abs(y)));
		const a = clamp(0.8 * body + head) * edge;
		const lum = 0.8 + 0.2 * head;
		return [lum, lum, lum, a];
	});
}

// Tileable faint shimmer: thin ridged caustic streaks (two warped ridge sets) plus a few glints.
function shimmer(seed, w = 256, h = 256) {
	const n1 = fbm(seed, 4, 3, 4);
	const n2 = fbm(seed + 1, 3, 5, 4);
	const wx = fbm(seed + 2, 4, 4, 3);
	const brk = fbm(seed + 3, 5, 5, 3);
	const r = rng(seed + 4);
	const glints = [];
	for (let k = 0; k < 14; k++) glints.push([r(), r(), 0.4 + 0.6 * r()]);
	const wy = fbm(seed + 5, 4, 4, 3);
	return image(w, h, (u, v) => {
		// warp both axes by more than a lattice cell so no grid-aligned ridges survive
		const pu = u + 0.45 * (wx(u, v) - 0.5);
		const pv = v + 0.45 * (wy(u, v) - 0.5);
		const r1 = Math.pow(1 - Math.abs(2 * n1(pu, pv) - 1), 10);
		const r2 = Math.pow(1 - Math.abs(2 * n2(pv + 0.3, pu + 0.6) - 1), 12);
		let g = 0;
		for (const [gx, gy, gs] of glints) {
			let dx = Math.abs(u - gx);
			let dy = Math.abs(v - gy);
			dx = Math.min(dx, 1 - dx);
			dy = Math.min(dy, 1 - dy);
			g = Math.max(g, gs * Math.exp(-(dx * dx + dy * dy) / (0.006 * 0.006)));
		}
		const streak = (r1 + 0.7 * r2) * (0.35 + 0.65 * smooth(0.35, 0.7, brk(u, v)));
		return [1, 1, 1, clamp(0.32 * streak + 0.45 * g)];
	});
}

// ---- race track dressing ----
// Beams lay a texture's V axis ALONG the beam and U across its width (seen in Studio,
// 2026-10-21, see chevron above). So for these images: image width = across the beam,
// image height = along the beam, and V = 0 (image top) is one end of the beam.

// Bunting strip: rope near u = 0.08, four triangular pennants per tile hanging toward u = 1,
// red, yellow, blue, green in order along V, transparent between them, tileable along V.
function pennants(w = 128, h = 512) {
	const cols = [[230, 70, 70], [250, 206, 70], [80, 140, 230], [90, 180, 110]].map((c) => c.map((x) => x / 255));
	const rope = [0.24, 0.2, 0.18];
	const ropeU = 0.08 * w;
	const tipU = 0.92 * w;
	const slot = h / 4;
	const half = 0.42 * slot;
	return image(w, h, (u, v) => {
		const x = u * w;
		const y = v * h;
		const k = Math.floor(y / slot);
		const ly = y - (k + 0.5) * slot; // along the rope, relative to the pennant centre
		// signed distance (pixels) to the triangle: base at the rope, apex at tipU
		const len = tipU - ropeU;
		const t = (x - ropeU) / len;
		const halfAt = half * (1 - t);
		const slant = Math.hypot(len, half);
		const dSide = ((Math.abs(ly) - halfAt) * len) / slant;
		const sd = Math.max(dSide, ropeU - x, x - tipU);
		const pa = 1 - smooth(-0.8, 0.8, sd);
		const shade = 1 - 0.14 * clamp(t) - 0.06 * smooth(0.2, 1, Math.abs(ly) / Math.max(halfAt, 1e-3));
		const pc = cols[k % 4].map((c) => c * shade);
		const ra = 1 - smooth(1.2, 2.2, Math.abs(x - ropeU));
		const a = ra + pa * (1 - ra);
		if (a <= 0) return [1, 1, 1, 0];
		const mix = (i) => (rope[i] * ra + pc[i] * pa * (1 - ra)) / a;
		return [mix(0), mix(1), mix(2), a];
	});
}

// Flags for waving beams, full alpha. Image width (U) = flag height, image height (V) = the fly
// from pole to tip, V = 0 (image top) at the hoist. Flag coordinates: fx 0..2 along the fly,
// fy 0..1 across. Gentle fold shading runs across the fly.
function flag(kind, w = 128, h = 256) {
	const C = (r, g, b) => [r / 255, g / 255, b / 255];
	const coral = C(242, 110, 90), white = C(250, 248, 240), yellow = C(250, 206, 70);
	const mint = C(120, 215, 180), blue = C(70, 130, 220), red = C(220, 60, 60);
	const black = C(30, 30, 34);
	const star = (px, py, cx, cy, R) => {
		// inside a 5-point star with one point toward fy = 0
		const x = px - cx, y = py - cy;
		const ang = Math.atan2(x, -y);
		const seg = Math.PI / 5;
		const a = ((((ang + seg) % (2 * seg)) + 2 * seg) % (2 * seg)) - seg;
		const rho = Math.hypot(x, y);
		const ri = R * 0.382;
		// edge between outer point (angle 0, R) and inner vertex (angle seg, ri)
		const ox = 0, oy = R, ix = ri * Math.sin(seg), iy = ri * Math.cos(seg);
		const lx = rho * Math.sin(Math.abs(a)), ly = rho * Math.cos(Math.abs(a));
		return (ix - ox) * (ly - oy) - (iy - oy) * (lx - ox) <= 0;
	};
	return imageSS(w, h, 4, (u, v) => {
		const fx = v * 2;
		const fy = u;
		let c;
		if (kind === "checker") c = (Math.floor(fx / 0.25) + Math.floor(fy / 0.25)) % 2 ? black : white;
		else if (kind === "stripes-a") c = [coral, white, yellow, white, coral][Math.min(4, Math.floor(fy * 5))];
		else if (kind === "stripes-b") {
			const dChev = Math.abs(fy - 0.5) * 1.6 + fx; // chevron from the hoist pointing along the fly
			c = dChev < 0.8 ? blue : dChev < 0.88 ? white : mint;
		} else c = star(fx, fy, 1.0, 0.52, 0.36) ? yellow : red;
		const fold = 0.95 + 0.05 * Math.cos(Math.PI * 2 * (fx * 1.25 + 0.12 * fy));
		return [c[0] * fold, c[1] * fold, c[2] * fold, 1];
	});
}

const jobs = [
	["water-body.png", () => streaks({ seed: SEED + 1, strands: 26, gapBias: 0.25, softness: 0.7, brokenness: 0.15 })],
	["water-strands-fast.png", () => streaks({ seed: SEED + 2, strands: 18, gapBias: 0.5, softness: 0.5, brokenness: 0.45 })],
	["water-strands-slow.png", () => streaks({ seed: SEED + 3, strands: 12, gapBias: 0.38, softness: 0.85, brokenness: 0.3 })],
	["water-highlights.png", () => streaks({ seed: SEED + 4, strands: 7, gapBias: 0.68, softness: 0.4, brokenness: 0.5 })],
	["water-spray.png", () => streaks({ seed: SEED + 5, strands: 4, gapBias: 0.55, softness: 0.9, brokenness: 0.6, h: 64 })],
	["foam-tile.png", () => foamTile(SEED + 6)],
	["foam-patch.png", () => foamPatch(SEED + 7)],
	["ripple.png", () => ripple()],
	["droplet.png", () => droplet()],
	["mist.png", () => mist(SEED + 8)],
	["rainbow.png", () => rainbow()],
	["sparkle.png", () => sparkle()],
	["glow.png", () => glow()],
	["current.png", () => current(SEED + 9)],
	["chevron.png", () => chevron()],
	// portal energy field
	["portal-swirl-a.png", () => portalSwirl({ seed: SEED + 101, arms: 3, twist: 2.4, dir: 1, cloudCells: [10, 6], wispCells: [40, 3], wispAmt: 0.35, armSharp: 1.6, broken: 0.25, warpAmt: 0.22 })],
	["portal-swirl-b.png", () => portalSwirl({ seed: SEED + 102, arms: 5, twist: -3.2, dir: 1, cloudCells: [22, 10], wispCells: [72, 3], wispAmt: 0.9, armSharp: 1.4, broken: 0.6, warpAmt: 0.3 })],
	["portal-cloud-tile.png", () => portalCloudTile(SEED + 103)],
	["portal-core.png", () => portalCore(SEED + 104)],
	["portal-veil.png", () => portalVeil(SEED + 105)],
	["portal-veil-b.png", () => portalVeil(SEED + 106)],
	["portal-mask.png", () => portalMask(SEED + 107)],
	["portal-beam.png", () => portalBeam(SEED + 108)],
	["portal-depth.png", () => portalDepth(SEED + 120)],
	["portal-cloud-ball.png", () => portalCloudBall(SEED + 121)],
	["portal-band.png", () => portalBand(SEED + 123)],
	["portal-cloud-ball-b.png", () => portalCloudBall(SEED + 122)],
	["ground-pool.png", () => groundPool()],
	["mote.png", () => mote()],
	["ember.png", () => ember()],
	["shimmer.png", () => shimmer(SEED + 109)],
	// race track dressing (beam textures: V along the beam)
	["pennants.png", () => pennants()],
	["flag-checker.png", () => flag("checker")],
	["flag-stripes-a.png", () => flag("stripes-a")],
	["flag-stripes-b.png", () => flag("stripes-b")],
	["flag-star.png", () => flag("star")],
];

fs.mkdirSync(OUT, { recursive: true });
const only = process.argv.slice(3);
for (const [name, make] of jobs) {
	if (only.length > 0 && !only.includes(name)) continue;
	const img = make();
	writePng(path.join(OUT, name), img.w, img.h, img.px);
	console.log(name, img.w + "x" + img.h);
}
