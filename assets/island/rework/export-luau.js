// Car Hop island rework: writes the computed hub layout as a Luau data module for the
// greybox recipes (Lane 3, build-time data). island-layout.js stays the single source of
// the geometry; the recipes in src/island/Hub only read this file.
//
// Run from the repository root, then format:
//   node assets/island/rework/export-luau.js [--plots 6]
//   stylua src/island/Hub/HubData.luau
//
// --plots N rebuilds the same half circle for another plot count (the switch-back route if
// the six-plot change to the plot contract is not agreed). Units are studs.

"use strict";
const fs = require("fs");
const path = require("path");
const L = require("./island-layout.js");
const D = require("./island-diagram.js");

const args = process.argv.slice(2);
const plotsArg = args.indexOf("--plots");
const plots = plotsArg >= 0 ? Number(args[plotsArg + 1]) : 6;
const OUT = path.join(__dirname, "..", "..", "..", "src", "island", "Hub", "HubData.luau");

const o = L.run({ plots }, `${plots} plots`);
const { H, net } = o;
const { P, g } = H;
const T = H.T;
const { V, len, sub, add, mul } = L;

// ---------- routes: route lines with the basin crossings bent round the rim ----------
function bendRoundBasin(pts) {
	const R = P.basinR + 2;
	const out = [pts[0]];
	for (let i = 1; i < pts.length; i++) {
		const a = pts[i - 1];
		const b = pts[i];
		const d = sub(b, a);
		const t = Math.max(0, Math.min(1, -(a.x * d.x + a.y * d.y) / (d.x * d.x + d.y * d.y)));
		if (len(add(a, mul(d, t))) < R && len(a) > R && len(b) > R) {
			// walk round the basin on the side the segment passes
			const angA = Math.atan2(a.y, a.x) + Math.sign(a.x * b.y - a.y * b.x) * Math.acos(R / len(a));
			const angB = Math.atan2(b.y, b.x) - Math.sign(a.x * b.y - a.y * b.x) * Math.acos(R / len(b));
			let sweep = angB - angA;
			while (sweep > Math.PI) sweep -= 2 * Math.PI;
			while (sweep < -Math.PI) sweep += 2 * Math.PI;
			const steps = Math.max(2, Math.ceil(Math.abs(sweep) / (Math.PI / 8)));
			for (let k = 0; k <= steps; k++) {
				const ang = angA + (sweep * k) / steps;
				out.push(V(R * Math.cos(ang), R * Math.sin(ang)));
			}
		}
		out.push(b);
	}
	// drop repeated points
	return out.filter((p, i) => i === 0 || len(sub(p, out[i - 1])) > 0.5);
}

// The layout's network joins a door straight to the nearest path node, which can cut through the
// building itself (the Stunt gate's north pillar, found by the greybox walk test). Such a last leg
// goes round to a point in front of the door first.
const doorBuildings = { Garage: o.garage, StuntGate: o.stunt };
function approachDoor(pts, b) {
	const n = pts.length;
	if (!b || n < 2) return pts;
	const lastLeg = [pts[n - 2], pts[n - 1]];
	if (!L.strip(lastLeg, 1).some((q) => L.overlaps(q, b.poly))) return pts;
	const front = add(b.door, mul(b.c, -8 / len(b.c)));
	return [...pts.slice(0, n - 1), front, pts[n - 1]];
}
const polylineLength = (pts) => pts.slice(1).reduce((s, p, i) => s + len(sub(p, pts[i])), 0);

const destinations = ["Fountain", "SummitPass", "Downtown", "DustyHighway", "Garage", "StuntGate"];
const routes = [];
for (const plot of H.plots) {
	const r = net.routes[plot.index];
	for (const dest of destinations) {
		let pts;
		if (dest === "Fountain") pts = [plot.entrance, L.polar(plot.bearing, P.basinR + 1)];
		else pts = approachDoor(bendRoundBasin(r.lines[dest]), doorBuildings[dest]);
		routes.push({ plot: plot.index, destination: dest, studs: polylineLength(pts), networkStuds: r.dist[dest], points: pts });
	}
}

// ---------- path lines and bridges (as in island-layout.js run(), with each bridge's direction) ----------
const arc = (r, b0, b1) => {
	const pts = [];
	for (let b = b0; b <= b1; b += 1) pts.push(L.polar(b, r));
	return pts;
};
const paths = [];
for (const a of H.avenues) paths.push({ kind: "Avenue" + a.index, width: P.avenueW, points: a.line });
paths.push({ kind: "Promenade", width: P.promenadeW, points: arc(H.prom.centre, -90, 90) });
paths.push({ kind: "GardenRing", width: 8, points: arc(P.ringR, -80, 80) });
for (const q of H.portals) paths.push({ kind: "Approach" + q.id, width: 14, points: [mul(q.front, P.plazaR / len(q.front)), q.front] });
paths.push({ kind: "StageWalk", width: 10, points: [V(-P.portal.spacing, P.portal.frontY + 3), V(P.portal.spacing, P.portal.frontY + 3)] });
for (const [kind, points] of Object.entries(o.walks)) paths.push({ kind, width: 10, points }); // Task 4: lakeside and forecourt walks
for (const b of [o.garage, o.stunt]) paths.push({ kind: b.id + "Approach", width: 12, points: [b.door, mul(b.door, P.plazaR / len(b.door))] });
for (const [kind, points] of Object.entries(o.spurs)) paths.push({ kind, width: L.SPUR_W, points }); // Task 4: snack corner and gazebo spurs

const BANK = 4.5; // studs of dry bank under each deck corner (the shore rule asks 4)
function streamGap(p) {
	let best = Infinity;
	for (let j = 1; j < o.stream.length; j++) {
		const c = o.stream[j - 1], ab = sub(o.stream[j], c);
		const t = Math.max(0, Math.min(1, ((p.x - c.x) * ab.x + (p.y - c.y) * ab.y) / (ab.x * ab.x + ab.y * ab.y)));
		best = Math.min(best, len(sub(p, add(c, mul(ab, t)))));
	}
	return best - P.task4.riverWidth / 2;
}
function cross2(a, b) {
	return a.x * b.y - a.y * b.x;
}
const bridges = [];
for (const pl of paths)
	for (let i = 1; i < pl.points.length; i++)
		for (let j = 1; j < o.stream.length; j++) {
			const a = pl.points[i - 1];
			const b = pl.points[i];
			const c = o.stream[j - 1];
			const d = o.stream[j];
			const r = sub(b, a);
			const s = sub(d, c);
			const den = cross2(r, s);
			if (Math.abs(den) < 1e-12) continue;
			const t = cross2(sub(c, a), s) / den;
			const u = cross2(sub(c, a), r) / den;
			if (t >= 0 && t <= 1 && u >= 0 && u < 1) {
				// the deck runs on until each of its corners is BANK studs clear of the river edge on both
				// sides, measured on the real (curving) river; at least the kit's 26 (Task 4 shore check:
				// Bridges 01 and 06 cross a bend at an angle and landed a corner 0.5 from the water)
				const deckWidth = pl.width + 2;
				const at = add(a, mul(r, t));
				const dir = mul(r, 1 / len(r));
				const side = V(-dir.y, dir.x);
				let half = 13;
				for (const lat of [-deckWidth / 2, deckWidth / 2])
					for (const sgn of [-1, 1]) {
						let k = 0;
						while (k < 40 && streamGap(add(add(at, mul(side, lat)), mul(dir, sgn * k))) < BANK) k += 0.1;
						half = Math.max(half, k);
					}
				const span = Math.round(2 * half * 10) / 10;
				bridges.push({ path: pl.kind, at: add(a, mul(r, t)), dir: mul(r, 1 / len(r)), deckWidth, span });
			}
		}
if (bridges.length !== o.bridges.length) throw new Error(`bridge count ${bridges.length} differs from the layout's ${o.bridges.length}`);

// ---------- buildings ----------
const facing = (b) => mul(b.c, -1 / len(b.c)); // doors face the fountain
const C4 = P.task4;
const buildings = [
	{ id: "Garage", b: o.garage, height: C4.garage.top },
	{ id: "StuntGate", b: o.stunt, height: C4.stunt.h },
	{ id: "Gazebo", b: o.gazebo, height: C4.gazebo.h },
	{ id: "SnackCornerEast", b: o.food, height: C4.snack.h },
	{ id: "SnackCornerWest", b: o.foodWest, height: C4.snack.h },
].map(({ id, b, height }) => ({ id, centre: b.c, facing: facing(b), door: b.door, width: b.w, depth: b.d, height }));
const boards = o.boards.map((b) => ({ id: b.id, centre: b.c, facing: facing(b), width: b.w, depth: b.d, height: b.h }));

// ---------- reservations: one uniform shape per entry ----------
const reservations = T.res.map((r) => ({
	id: r.id,
	name: r.name,
	layer: r.layer,
	use: r.use,
	occupants: r.occupants,
	height: r.height,
	poly: r.poly,
	ring: r.ring || [],
	replaces: r.replaces || "",
	replacedBy: r.replacedBy || "",
	note: [r.airspace, r.note, r.clear ? `${r.clear} clear` : "", r.sky ? "open sky above" : ""].filter(Boolean).join("; "),
}));
const allowed = [];
for (const p of o.check.pairs) {
	if (!p.allowed) throw new Error("layout conflict: " + p.a + " / " + p.b);
	allowed.push({ a: p.a, b: p.b, why: p.why });
}

const B = D.backdrop(o);

const data = {
	source: "assets/island/rework/island-layout.js via export-luau.js",
	plotCount: P.plots,
	sectorDeg: 180 / P.plots,
	bufferPerSide: P.buffer / 2,
	walkSpeed: L.WALK,
	bearings: H.bearings,
	track: { turnRadius: P.R, width: P.trackWidth, clearance: P.off, straight: T.L, pathLength: 2 * T.L + 2 * Math.PI * P.R, sampleCount: 86 },
	plot: { entranceRadius: g.r0, frontDepth: P.frontDepth, frontEnd: g.r0 + P.frontDepth, nearTip: g.uTip, straightsStart: g.uS, farTip: g.uFar, outerClearance: g.rOut, infieldHalf: g.rIn, band: P.band, outerRadius: H.rMax },
	reservations,
	allowedPairs: allowed,
	park: {
		plazaRadius: P.plazaR,
		basinRadius: P.basinR,
		promenade: { inner: H.prom.inner, outer: H.prom.outer, centre: H.prom.centre },
		ringRadius: P.ringR,
		portal: { width: P.portal.outer, opening: P.portal.opening, depth: P.portal.depth, height: P.portal.height, spacing: P.portal.spacing, frontY: P.portal.frontY, gateSetback: P.task4.gateSetback },
		portals: H.portals.map((q) => ({ id: q.id, x: q.x })),
		buildings,
		boards,
		axisX: C4.axisX,
		stream: o.stream, // Task 4: the river loop, west lake mouth first, east lake mouth last
		streamWidth: C4.riverWidth,
		riverLoop: true,
		gantry: o.stunt.gantry,
		paths,
		bridges,
		corridors: H.corridors,
	},
	backdrop: {
		lake: { centre: B.lake.c, rx: B.lake.rx, ry: B.lake.ry },
		peaks: B.peaks.map((k) => ({ centre: k.c, radius: k.r, height: k.h })),
		waterfall: { top: B.waterfall.top, width: B.waterfall.width, height: B.waterfall.height },
		foothills: { inner: B.foot.inner, outer: B.foot.outer },
	},
	routes,
};

// ---------- Luau writer ----------
const num = (n) => {
	const r = Math.round(n * 1000) / 1000;
	return Object.is(r, -0) ? "0" : String(r);
};
const isVec = (v) => v && typeof v === "object" && !Array.isArray(v) && Object.keys(v).length === 2 && typeof v.x === "number" && typeof v.y === "number";
function lua(v, ind) {
	const pad = "\t".repeat(ind + 1);
	const end = "\t".repeat(ind);
	if (typeof v === "number") return num(v);
	if (typeof v === "boolean") return String(v);
	if (typeof v === "string") return JSON.stringify(v);
	if (isVec(v)) return `Vector2.new(${num(v.x)}, ${num(v.y)})`;
	if (Array.isArray(v)) {
		if (v.length === 0) return "{}";
		return "{\n" + v.map((x) => pad + lua(x, ind + 1) + ",").join("\n") + "\n" + end + "}";
	}
	const keys = Object.keys(v);
	return "{\n" + keys.map((k) => `${pad}${k} = ${lua(v[k], ind + 1)},`).join("\n") + "\n" + end + "}";
}

const header = `--!strict
-- GENERATED by assets/island/rework/export-luau.js from island-layout.js (Lane 3, build-time data).
-- Do not edit by hand: change the layout script, re-run the exporter, then run StyLua.
-- Plan frame: x east, y north toward the plots, origin at the fountain centre. Plot frame:
-- x (v) to the right when facing outward, y (u) outward along the plot's centre line.

return `;
fs.mkdirSync(path.dirname(OUT), { recursive: true });
fs.writeFileSync(OUT, header + lua(data, 0) + "\n");
console.log(`wrote ${OUT}: ${P.plots} plots, r0 ${num(g.r0)}, outer ${num(H.rMax)}, ${reservations.length} reservations, ${bridges.length} bridges, ${routes.length} routes`);
