// Lane 3 island: the measured sightline envelope for the plaza fountain.
//   node assets/island/rework/fountain-envelope.js [out.json]
// For every 1 x 1 stud cell of the plaza (world x and z from -46 to 46), the tallest solid
// object that stays below every sight ray from the six plot entrances to the three portal
// placeholders. Rays go from a spread of eye points at each entrance (eye 4.5, 5.5 and 6.5 studs
// above the walking surface; 3 studs either side and 4 studs ahead and behind the entrance point,
// for player and camera variation) to points filling each portal's full outline (the 26-stud
// glowing disc, radius 11, centre 13 above the ground, every 1.5 studs; the faint halo round it,
// which reaches the ground, is not counted, or a bench anywhere in the plaza would "block" it). A cell no ray crosses has no
// limit from the portals. World frame: x east, z = -plan y; the plaza surface is y 0.
// Numbers from Layout (park.corridors, park.portals, park.portal) and the built portal models
// (bounding boxes read in Studio, 2026-10-21).
"use strict";
const fs = require("fs");

const entrances = [
	[-238.764, 63.977],
	[-174.787, 174.787],
	[-63.977, 238.764],
	[63.977, 238.764],
	[174.787, 174.787],
	[238.764, 63.977],
].map(([x, y]) => ({ x, z: -y }));
const portals = [
	{ id: "SummitPass", x: -28, z: 57.85 },
	{ id: "Downtown", x: 0, z: 59 },
	{ id: "DustyHighway", x: 28, z: 57.85 },
];
const R = 11; // the glowing disc (22 wide, its bottom 2 studs up); the faint halo round it is 13
const CY = 13; // disc centre height
const EYES = [4.5, 5.5, 6.5];
const HALF = 46;
const N = HALF * 2;

const env = new Float32Array(N * N).fill(Infinity);
const byEntrance = entrances.map(() => new Float32Array(N * N).fill(Infinity));

for (let ei = 0; ei < entrances.length; ei++) {
	const e = entrances[ei];
	const len = Math.hypot(e.x, e.z);
	const fwd = { x: -e.x / len, z: -e.z / len }; // toward the plaza centre
	const side = { x: -fwd.z, z: fwd.x };
	const eyes = [];
	for (const h of EYES)
		for (const s of [-3, 0, 3])
			for (const f of [-4, 0, 4]) eyes.push({ x: e.x + side.x * s + fwd.x * f, y: h, z: e.z + side.z * s + fwd.z * f });
	for (const p of portals) {
		const pts = [];
		for (let u = -R; u <= R; u += 1.5)
			for (let v = -R; v <= R; v += 1.5) if (u * u + v * v <= R * R) pts.push({ x: p.x + u, y: CY + v, z: p.z });
		for (let a = 0; a < 48; a++) pts.push({ x: p.x + Math.cos((a / 48) * 2 * Math.PI) * R, y: CY + Math.sin((a / 48) * 2 * Math.PI) * R, z: p.z });
		for (const q of pts) {
			if (q.y < 0) continue;
			for (const eye of eyes) {
				// march along the ray's plan path inside the plaza grid
				const dx = q.x - eye.x, dz = q.z - eye.z;
				const steps = Math.ceil(Math.hypot(dx, dz) / 0.5);
				for (let k = 0; k <= steps; k++) {
					const t = k / steps;
					const x = eye.x + dx * t, z = eye.z + dz * t;
					if (Math.abs(x) >= HALF || Math.abs(z) >= HALF) continue;
					const y = eye.y + (q.y - eye.y) * t;
					const ix = Math.floor(x + HALF), iz = Math.floor(z + HALF);
					const i = iz * N + ix;
					if (y < env[i]) env[i] = y;
					if (y < byEntrance[ei][i]) byEntrance[ei][i] = y;
				}
			}
		}
	}
}

const cell = (x, z) => env[Math.floor(z + HALF) * N + Math.floor(x + HALF)];
const out = { half: HALF, eyes: EYES, haloRadius: R, grid: Array.from(env, (v) => (Number.isFinite(v) ? Math.round(v * 100) / 100 : null)) };
// summary: allowed height along the east-west and north-south lines through the centre, and
// rings round the centre
const sections = { eastWest: [], northSouth: [] };
for (let d = -40; d <= 40; d += 2) {
	sections.eastWest.push([d, cell(d + 0.5, 0.5)]);
	sections.northSouth.push([d, cell(0.5, d + 0.5)]);
}
const rings = [];
for (const r of [2, 4, 6, 8, 10, 12, 14, 16, 18, 20, 24, 28, 32, 36, 40]) {
	let lo = Infinity, hi = -Infinity;
	for (let a = 0; a < 72; a++) {
		const v = cell(Math.cos((a / 72) * 2 * Math.PI) * r, Math.sin((a / 72) * 2 * Math.PI) * r);
		lo = Math.min(lo, v);
		hi = Math.max(hi, Number.isFinite(v) ? v : 99);
	}
	rings.push({ r, min: Math.round(lo * 100) / 100, max: hi });
}
out.sections = sections;
out.rings = rings;
// a narrow central column: the widest square column at the centre whose cells are free of rays
let column = 0;
for (let w = 0.5; w <= 10; w += 0.5) {
	let free = true;
	for (let x = -w; x < w; x += 0.5) for (let z = -w; z < w; z += 0.5) if (Number.isFinite(cell(x, z)) && cell(x, z) < 20) free = false;
	if (free) column = w; else break;
}
out.freeCentreHalfWidth = column;
fs.writeFileSync(process.argv[2] || "fountain-envelope.json", JSON.stringify(out));
console.log(JSON.stringify({ rings, sections, freeCentreHalfWidth: column }, null, 1));
