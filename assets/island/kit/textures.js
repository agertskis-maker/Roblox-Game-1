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
];

fs.mkdirSync(OUT, { recursive: true });
for (const [name, make] of jobs) {
	const img = make();
	writePng(path.join(OUT, name), img.w, img.h, img.px);
	console.log(name, img.w + "x" + img.h);
}
