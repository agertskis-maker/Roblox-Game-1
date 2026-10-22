// Car Hop island rework, Task 1: layout and spatial validation (Lane 3, design calculation).
//
// Computes the half-circle "stadium audience facing a stage" layout: plots on the curved
// side, the park in front of them, the portal row on the straight side. Reports radii,
// angles, zone depths, reservation footprints with wedge-containment and overlap checks,
// viewing corridors, path-network walking routes, and draws the review diagrams.
// Pure geometry, no Roblox. Run: node island-layout.js <outDir>
//
// Plan frame: x east, y north (toward the plots), origin at the fountain centre F.
// Roblox world later: X = x, Z = -y. Plot frame: u outward along the plot's centre line,
// v to the right when facing outward. Bearings are clockwise from north. Units: studs.

"use strict";
const fs = require("fs");
const path = require("path");

const WALK = 16; // Roblox default WalkSpeed; no override exists in src (Stage A read 16 in the place)
const APPROVED_PATH = 427.1; // approved Speedway lap length (island-base.md revision 2)

function baseParams(over) {
	return Object.assign(
		{
			plots: 6,
			buffer: 16, // total gap between neighbouring plot envelopes (8 each side of a sector ray)
			orientation: "radial", // oval long axis
			R: 35, // oval centreline turn radius (approved hairpin 35, tightest turn 30)
			trackWidth: 16,
			off: 11, // centreline to clearance edge, both sides: 8 half width + 1 barrier/curb + 2 margin
			band: 50, // side bands for bleachers and crowds
			frontDepth: 90, // front zone (brief: 80 to 100)
			frontGap: 6, // walkway between the front zone and the oval's near tip
			plazaR: 40, // fountain plaza (paved, open)
			basinR: 12, // fountain basin; walkers keep 1 stud off it
			promenadeW: 20,
			avenueW: 16,
			portal: { outer: 22, opening: 16, depth: 6, height: 36, spacing: 28, frontY: -56 },
			ringR: 135, // secondary garden ring path radius
			eye: 5,
			// viewing corridors widen by this much each side at the portal row; with 0 the Stunt gate
			// grazed the corridor edge and hid part of Summit Pass from Plot01 (greybox, 2026-10-21)
			corridorMargin: 10,
			// Task 4 (2026-10-22): the mirrored destination pair and the river loop, as measured by
			// task4-layout.js (see vault/design/island-rework.md, IRW-127 onward)
			task4: {
				axisX: 0, // the one centre axis: every mirrored pair is (x, y) and (-x, y)
				riverR: 157, // river loop centre line between the garden ring and the wings
				riverTurn: 78, // bearing where the loop leaves the circle and runs down to the lake
				riverLeg: [
					[146, 5],
					[138, -25],
					[131, -55],
					[126, -85],
					[122, -104],
				], // east leg to the lake (the west leg mirrors it)
				riverWidth: 16,
				wingBearing: 105.5, // Garage centre bearing (the Stunt entrance mirrors it)
				wingR: 195,
				garage: { w: 62, d: 40, h: 26, top: 34 },
				stunt: { w: 37, d: 40, h: 18 }, // same depth as the Garage so the doors mirror
				board: { w: 18, d: 4, h: 15, along: 10 }, // display about 18 x 14 (research note); along is the gap from the Garage corner
				snack: { bearing: 34, r: 192, w: 30, d: 28, h: 10 }, // 60 hid Plot 2's lower falls (47 %), 30 hid 1 % of Plot 3's
				gazebo: { r: 196, w: 16, d: 16, h: 12 },
			},
		},
		over || {},
	);
}

// ---------- small geometry ----------
const rad = (d) => (d * Math.PI) / 180;
const V = (x, y) => ({ x, y });
const add = (a, b) => V(a.x + b.x, a.y + b.y);
const sub = (a, b) => V(a.x - b.x, a.y - b.y);
const mul = (a, k) => V(a.x * k, a.y * k);
const len = (a) => Math.hypot(a.x, a.y);
const dot = (a, b) => a.x * b.x + a.y * b.y;
const cross = (a, b) => a.x * b.y - a.y * b.x;
const r1 = (n) => Math.round(n * 10) / 10;
const r2 = (n) => Math.round(n * 100) / 100;

function rect(v0, v1, u0, u1) {
	return [V(v0, u0), V(v1, u0), V(v1, u1), V(v0, u1)];
}
function stadium(cu0, cu1, r, n = 48) {
	// in plot frame: v horizontal, u along the long axis; semicircle centres at u = cu0 and cu1
	const pts = [];
	for (let i = 0; i <= n; i++) {
		const a = Math.PI + (Math.PI * i) / n; // near end: from (-r, cu0) round the bottom to (r, cu0)
		pts.push(V(r * Math.cos(a), cu0 + r * Math.sin(a)));
	}
	for (let i = 0; i <= n; i++) {
		const a = (Math.PI * i) / n;
		pts.push(V(r * Math.cos(a), cu1 + r * Math.sin(a)));
	}
	return pts;
}
function circle(c, r, n = 40) {
	const pts = [];
	for (let i = 0; i < n; i++) pts.push(V(c.x + r * Math.cos((2 * Math.PI * i) / n), c.y + r * Math.sin((2 * Math.PI * i) / n)));
	return pts;
}
function segX(a, b, c, d) {
	const r = sub(b, a);
	const s = sub(d, c);
	const den = cross(r, s);
	if (Math.abs(den) < 1e-12) return null;
	const t = cross(sub(c, a), s) / den;
	const u = cross(sub(c, a), r) / den;
	if (t > 1e-9 && t < 1 - 1e-9 && u > 1e-9 && u < 1 - 1e-9) return { t, u, p: add(a, mul(r, t)) };
	return null;
}
function segXHalfOpen(a, b, c, d) {
	const r = sub(b, a);
	const s = sub(d, c);
	const den = cross(r, s);
	if (Math.abs(den) < 1e-12) return null;
	const t = cross(sub(c, a), s) / den;
	const u = cross(sub(c, a), r) / den;
	if (t >= 0 && t <= 1 && u >= 0 && u < 1) return { t, u, p: add(a, mul(r, t)) };
	return null;
}
function inside(p, poly) {
	let c = false;
	for (let i = 0, j = poly.length - 1; i < poly.length; j = i++) {
		const a = poly[i];
		const b = poly[j];
		if (a.y > p.y !== b.y > p.y && p.x < ((b.x - a.x) * (p.y - a.y)) / (b.y - a.y) + a.x) c = !c;
	}
	return c;
}
function shrink(poly, e) {
	const c = centroid(poly);
	return poly.map((p) => {
		const d = sub(p, c);
		const l = len(d);
		return l > e ? sub(p, mul(d, e / l)) : p;
	});
}
function overlaps(A0, B0) {
	const A = shrink(A0, 0.05);
	const B = shrink(B0, 0.05);
	for (let i = 0; i < A.length; i++)
		for (let j = 0; j < B.length; j++) if (segX(A[i], A[(i + 1) % A.length], B[j], B[(j + 1) % B.length])) return true;
	if (A.some((p) => inside(p, B))) return true;
	if (B.some((p) => inside(p, A))) return true;
	return false;
}
function centroid(poly) {
	let x = 0;
	let y = 0;
	for (const p of poly) {
		x += p.x;
		y += p.y;
	}
	return V(x / poly.length, y / poly.length);
}
function area(poly) {
	let s = 0;
	for (let i = 0; i < poly.length; i++) s += cross(poly[i], poly[(i + 1) % poly.length]);
	return Math.abs(s) / 2;
}
function polyline(pts) {
	let s = 0;
	for (let i = 1; i < pts.length; i++) s += len(sub(pts[i], pts[i - 1]));
	return s;
}
// thick polyline as a list of quads
function strip(pts, w) {
	const out = [];
	for (let i = 1; i < pts.length; i++) {
		const a = pts[i - 1];
		const b = pts[i];
		const d = sub(b, a);
		const n = mul(V(-d.y, d.x), w / 2 / len(d));
		out.push([add(a, n), add(b, n), sub(b, n), sub(a, n)]);
	}
	return out;
}

// plot frame -> plan
function toPlan(b, p) {
	const s = Math.sin(rad(b));
	const c = Math.cos(rad(b));
	return V(p.x * c + p.y * s, -p.x * s + p.y * c);
}
const polar = (b, r) => V(r * Math.sin(rad(b)), r * Math.cos(rad(b)));

// shortest walk between two points around the basin disk (open plaza)
function aroundDisk(a, b, R) {
	const d = sub(b, a);
	const t = Math.max(0, Math.min(1, -dot(a, d) / dot(d, d)));
	if (len(add(a, mul(d, t))) >= R) return len(d);
	const ta = Math.sqrt(Math.max(0, dot(a, a) - R * R));
	const tb = Math.sqrt(Math.max(0, dot(b, b) - R * R));
	let ang = Math.abs(Math.atan2(cross(a, b), dot(a, b)));
	ang -= Math.acos(Math.min(1, R / len(a))) + Math.acos(Math.min(1, R / len(b)));
	return ta + tb + R * Math.max(0, ang);
}

// ---------- the plot ----------
function plotTemplate(P) {
	const N = P.plots;
	const alpha = rad(90 / N); // half sector
	const half = P.buffer / 2;
	const fits = (p) => p.y * Math.sin(alpha) - Math.abs(p.x) * Math.cos(alpha) >= half - 1e-6;
	const L = (APPROVED_PATH - 2 * Math.PI * P.R) / 2; // straight length keeps the approved lap length
	const rOut = P.R + P.off; // outer clearance half width of the oval
	const rIn = P.R - P.off; // infield half width
	let uS; // u where the straights start (near semicircle centre)
	let geom;
	if (P.orientation === "radial") {
		const h = rOut + P.band;
		uS = (h * Math.cos(alpha) + half) / Math.sin(alpha);
		const uTip = uS - rOut;
		const r0 = uTip - P.frontGap - P.frontDepth;
		geom = { L, rOut, rIn, uS, uTip, r0, uFar: uS + L + rOut };
	} else {
		// tangential: long axis across the plot; bands in front of and behind the oval
		const hx = L / 2 + rOut;
		const u1 = (hx * Math.cos(alpha) + half) / Math.sin(alpha); // front band inner corners
		const r0 = u1 - P.frontGap - P.frontDepth;
		geom = { L, rOut, rIn, u1, r0, uFar: u1 + 2 * P.band + 2 * rOut };
		return { P, alpha, fits, geom, res: [], tangential: true };
	}
	const g = geom;
	const r0 = g.r0;
	const uF = r0 + P.frontDepth;
	const res = [];
	const R = (id, name, layer, use, occupants, poly, height, extra) =>
		res.push(Object.assign({ id, name, layer, use, occupants, poly, height }, extra || {}));

	// front zone (closest to the park)
	R("EntranceCourt", "Entrance court, gate arch and nameplate", "base", "plot entrance facing the fountain", "gate arch, nameplate, planters under 3", rect(-16, 16, r0, r0 + 14), 10);
	R("Kiosk", "Upgrade kiosk", "base", "Paddock kiosk (outline 08)", "kiosk only", rect(19, 29, r0 + 3, r0 + 11), 9);
	R("Paddock", "Paddock, 15 bays (3 visible at start)", "base", "parking bays for the Lineup: row A 7, aisle 10, row B 8; bays 9 x 16", "bays, bay lines, cars", rect(-36, 36, r0 + 16, r0 + 58), 1);
	const wAt = (u) => u * Math.tan(alpha) - half / Math.cos(alpha); // usable half width
	const fbV1 = Math.floor(wAt(r0 + 20) - 1);
	R("FrontBuildingsL", "Front building pad, left (pit garages)", "future", "pit garage every third Slot, up to 5 (outline 08)", "pit garages", rect(-fbV1, -40, r0 + 20, r0 + 56), 18);
	R("FrontBuildingsR", "Front building pad, right (pit garages)", "future", "pit garage every third Slot, up to 5 (outline 08)", "pit garages", rect(40, fbV1, r0 + 20, r0 + 56), 18);
	R("FrontBuildingsRear", "Front building strip behind the Paddock", "future", "income-tier front buildings", "buildings under 18", rect(-22, -5, r0 + 62, uF), 18);
	R("FrontBuildingsRear2", "Front building strip behind the Paddock (right)", "future", "income-tier front buildings", "buildings under 18", rect(5, 22, r0 + 62, uF), 18);
	R("PlotWalk", "Plot walkway to the near curve", "base", "players walk from the court to the track end", "paving, low rail", rect(-3, 3, r0 + 58, g.uTip), 0);
	// pit lanes alongside the near curve, joining where the straights start
	R("PitExit", "Pit exit lane (Paddock to right straight)", "base", "Lineup cars leave the Paddock", "track surface", [V(26, r0 + 58), V(36, r0 + 58), V(g.rOut + 10, uF), V(g.rOut + 10, g.uS - 1), V(g.rOut + 1, g.uS - 1), V(g.rOut + 1, uF + 6)], 0);
	R("PitEntry", "Pit entry lane (left straight to Paddock)", "base", "Lineup cars return", "track surface", [V(-26, r0 + 58), V(-36, r0 + 58), V(-g.rOut - 10, uF), V(-g.rOut - 10, g.uS - 1), V(-g.rOut - 1, g.uS - 1), V(-g.rOut - 1, uF + 6)], 0);
	// pit building and screen pad beside the near curve (tier 4)
	R("PitBuilding", "Pit building", "future", "tier 4 pit building (outline 08)", "one building", rect(g.rOut + 12, g.rOut + 36, g.uS - 34, g.uS - 4), 18);
	R("ScreenPad", "Big screen pad", "future", "tier 4 big screen showing the Lineup", "screen on legs, faces the near curve and the court", rect(-g.rOut - 36, -g.rOut - 12, g.uS - 14, g.uS - 4), 30);

	// the oval
	const outer = stadium(g.uS, g.uS + L, g.rOut);
	const inner = stadium(g.uS, g.uS + L, g.rIn);
	R("Track", "Speedway oval (clearance edge)", "base", "lap path, barrier, curb, margins", "track only", outer, 2, { ring: inner });
	R("ElevatedEnvelope", "Elevated track and supports airspace", "future", "raised deck 10 clear, ramp 72 at 1 in 6 on the right straight; supports only in the 2-stud margins", "raised deck, ramp, supports", outer, 40, {
		ring: inner,
		airspace: "8 to 40 above the track",
		note: "never over the start/finish gantry segment of the left straight",
	});
	const gU = g.uS + L * 0.25; // start/finish on the left straight, near the park end
	R("Gantry", "Start / finish gantry clearance", "future", "tier 3 gantry spanning the left straight; cars finish heading toward the park", "gantry, legs in the margins", rect(-g.rOut, -g.rIn, gU - 3, gU + 3), 22, { clear: 16 });
	// side bands (bleachers, grandstand, floodlight pads)
	const b0 = g.rOut + 1;
	const b1 = g.rOut + P.band;
	R("BleachersR", "Right band: bleachers and crowds", "future", "tier 2 small bleachers, crowds", "bleachers under 12", rect(b0, b1 - 11, g.uS, g.uS + L), 12);
	R("BleachersL", "Left band: bleachers (tier 2), replaced by the covered grandstand (tier 3)", "future", "tier 2 small bleachers", "bleachers under 12, removed when the grandstand arrives", rect(-b1 + 11, -b0, g.uS, g.uS + L), 12, { replacedBy: "Grandstand" });
	R("Grandstand", "Covered grandstand and stadium roof section", "future", "tier 3 covered grandstand, tier 5 roof section", "grandstand, roof under 40", rect(-b1 + 11, -b0, g.uS, g.uS + L), 40, { replaces: "BleachersL" });
	R("CrowdWalkR", "Right band outer walk", "future", "crowd circulation between the floodlight pads", "paving, crowds", rect(b1 - 10, b1, g.uS + 11, g.uS + L - 11), 0);
	R("CrowdWalkL", "Left band outer walk", "future", "crowd circulation between the floodlight pads", "paving, crowds", rect(-b1, -b1 + 10, g.uS + 11, g.uS + L - 11), 0);
	const pads = [
		["FloodNR", b1 - 10, b1, g.uS, g.uS + 10],
		["FloodFR", b1 - 10, b1, g.uS + L - 10, g.uS + L],
		["FloodNL", -b1, -b1 + 10, g.uS, g.uS + 10],
		["FloodFL", -b1, -b1 + 10, g.uS + L - 10, g.uS + L],
	];
	for (const [id, v0, v1, u0, u1] of pads) R(id, "Floodlight pad", "future", "tier 3 floodlight tower, 10 x 10 pad", "one tower under 60", rect(v0, v1, u0, u1), 60);
	// infield
	R("Statue", "Champion statue pad", "future", "tier 5 statue of the rarest car", "statue under 20", rect(-6, 6, g.uS - 10, g.uS + 2), 20);
	R("LoopEnvelope", "Vertical loop envelope", "future", "loop radius 16; footprint 38 x 34 with the exit offset; top 40", "loop and supports", rect(-17, 17, g.uS + L / 2 - 19, g.uS + L / 2 + 19), 40);
	R("FireworksL", "Fireworks launch point", "future", "tier 5 fireworks, open sky above", "launcher under 3", rect(-14, -8, g.uS + L - 6, g.uS + L), 3, { sky: true });
	R("FireworksR", "Fireworks launch point", "future", "tier 5 fireworks, open sky above", "launcher under 3", rect(8, 14, g.uS + L - 6, g.uS + L), 3, { sky: true });
	// outer sign band
	R("SignBand", "Outer sign and banner band (base flag line lives here)", "future", "signs and banners; the tier 2 flag line starts here and is replaced by signs", "flags, signs, banners under 20", rect(-b1, b1, g.uFar + 2, g.uFar + 14), 20);

	return { P, alpha, fits, geom: g, res, L, wAt };
}

// which reservation pairs may share space, and why
const ALLOWED = {
	"BleachersL|Grandstand": "planned replacement: the tier 2 bleachers are removed when the tier 3 grandstand is built",
	"ElevatedEnvelope|Track": "a track is allowed inside its own elevated-track envelope",
	"ElevatedEnvelope|Gantry": "conditional: the raised deck must not pass over the gantry segment (documented)",
	"ElevatedEnvelope|PitEntry": "pit lanes join the oval at ground level where the straights start",
	"ElevatedEnvelope|PitExit": "pit lanes join the oval at ground level where the straights start",
	"PitEntry|Track": "pit lanes join the oval where the straights start",
	"PitExit|Track": "pit lanes join the oval where the straights start",
	"Gantry|Track": "the gantry spans the track; legs in the margins",
	"PlotWalk|Track": "the walkway ends at the near tip's clearance edge",
	"ElevatedEnvelope|PlotWalk": "the walkway ends at the near tip's clearance edge",
};
const pairKey = (a, b) => [a, b].sort().join("|");

function checkPlot(T) {
	const { res, fits, geom: g } = T;
	const contain = [];
	for (const r of res) {
		let worst = Infinity;
		for (const p of r.poly) worst = Math.min(worst, p.y * Math.sin(T.alpha) - Math.abs(p.x) * Math.cos(T.alpha));
		const minU = Math.min(...r.poly.map((p) => len(p)));
		contain.push({ id: r.id, ok: r.poly.every(fits) && minU >= g.r0 - 1e-6, rayClear: r2(worst), minRadius: r1(minU) });
	}
	const pairs = [];
	for (let i = 0; i < res.length; i++)
		for (let j = i + 1; j < res.length; j++) {
			const A = res[i];
			const B = res[j];
			let hit = overlaps(A.poly, B.poly);
			// a ring reservation does not overlap something wholly inside its infield
			if (hit && A.ring && B.poly.every((p) => inside(p, A.ring))) hit = false;
			if (hit && B.ring && A.poly.every((p) => inside(p, B.ring))) hit = false;
			if (!hit) continue;
			const why = ALLOWED[pairKey(A.id, B.id)];
			pairs.push({ a: A.id, b: B.id, allowed: !!why, why: why || "CONFLICT" });
		}
	// infield items must be wholly inside the infield
	const track = res.find((r) => r.id === "Track");
	const infield = ["Statue", "LoopEnvelope", "FireworksL", "FireworksR"].map((id) => ({
		id,
		inside: res.find((r) => r.id === id).poly.every((p) => inside(p, track.ring)),
	}));
	return { contain, pairs, infield };
}

// ---------- the whole hub ----------
function layout(over) {
	const P = baseParams(over);
	const T = plotTemplate(P);
	if (T.tangential) return { P, T, tangential: true };
	const g = T.geom;
	const N = P.plots;
	const sector = 180 / N;
	const bearings = [];
	for (let i = 1; i <= N; i++) bearings.push(-90 + sector * (i - 0.5));
	const plots = bearings.map((b, k) => ({
		index: k + 1,
		bearing: b,
		entrance: polar(b, g.r0),
		res: T.res.map((r) => Object.assign({}, r, { plan: r.poly.map((p) => toPlan(b, p)) })),
	}));
	const rMax = Math.max(...plots[0].res.map((r) => Math.max(...r.plan.map(len))));

	// neighbouring plots must not touch
	const neighbour = [];
	for (let k = 0; k + 1 < plots.length; k++) {
		let hits = 0;
		for (const A of plots[k].res) for (const B of plots[k + 1].res) if (overlaps(A.plan, B.plan)) hits++;
		neighbour.push({ a: k + 1, b: k + 2, overlaps: hits });
	}

	// park
	const prom = { inner: g.r0 - P.promenadeW, outer: g.r0, centre: g.r0 - P.promenadeW / 2 };
	const portal = P.portal;
	const portals = [
		{ id: "SummitPass", x: -portal.spacing },
		{ id: "Downtown", x: 0 },
		{ id: "DustyHighway", x: portal.spacing },
	].map((q) => Object.assign(q, { front: V(q.x, portal.frontY), base: rect(q.x - portal.outer / 2, q.x + portal.outer / 2, portal.frontY - portal.depth, portal.frontY) }));
	const span = [V(-portal.spacing - portal.outer / 2, portal.frontY), V(portal.spacing + portal.outer / 2, portal.frontY)];
	const m = P.corridorMargin;
	const corridors = plots.map((p) => [p.entrance, V(span[0].x - m, span[0].y), V(span[1].x + m, span[1].y)]);

	// avenues as strips from the promenade inner edge to the plaza edge
	const avenues = plots.map((p) => ({ index: p.index, line: [polar(p.bearing, prom.inner), polar(p.bearing, P.plazaR)] }));

	return { P, T, g, plots, bearings, rMax, neighbour, prom, portals, span, corridors, avenues };
}

// ---------- placement and routes ----------
function placeOutsideCorridors(H, name, w, d, opts) {
	const score = opts.score || ((c) => [c.spread, c.worst]);
	// grid search for a footprint facing the fountain, outside every corridor, avenue, plaza,
	// stream and other building; minimise the best-to-worst spread, then the worst route
	const { P, g, corridors, plots } = H;
	const best = [];
	for (let y = opts.yMin; y <= opts.yMax; y += 2)
		for (let x = opts.xMin; x <= opts.xMax; x += 2) {
			const c = V(x, y);
			const rr = len(c);
			if (rr < P.plazaR + d / 2 + 6 || rr > H.prom.inner - d / 2 - 6) continue;
			const dir = mul(c, -1 / rr); // door faces the fountain
			const side = V(-dir.y, dir.x);
			const poly = [add(add(c, mul(side, w / 2)), mul(dir, d / 2)), add(sub(c, mul(side, w / 2)), mul(dir, d / 2)), sub(sub(c, mul(side, w / 2)), mul(dir, d / 2)), sub(add(c, mul(side, w / 2)), mul(dir, d / 2))];
			if (opts.tall !== false && corridors.some((t) => overlaps(poly, t))) continue;
			if (H.avenues.some((a) => strip(a.line, P.avenueW + 8).some((q) => overlaps(poly, q)))) continue;
			if ((opts.avoid || []).some((q) => overlaps(poly, q))) continue;
			if (poly.some((p) => p.y < P.portal.frontY + 4)) continue;
			const door = add(c, mul(dir, d / 2 + 2));
			// its approach path to the plaza must not run into another building
			if ((opts.approachClear || []).some((q) => strip([door, mul(door, P.plazaR / len(door))], 12).some((a) => overlaps(a, q)))) continue;
			const ds = plots.map((p) => len(sub(door, p.entrance)));
			best.push({ c, poly, door, spread: Math.max(...ds) - Math.min(...ds), worst: Math.max(...ds) });
		}
	best.sort((a, b) => {
		const sa = score(a);
		const sb = score(b);
		return sa[0] - sb[0] || sa[1] - sb[1];
	});
	if (!best[0]) throw new Error("no place found for " + name);
	return Object.assign(best[0], { id: name, w, d });
}

// path network: nodes and straight edges; plaza crossings use the basin-avoiding distance
function network(H, extras) {
	const { P, g, plots, prom, portals } = H;
	const nodes = [];
	const edges = [];
	const node = (p, tag) => {
		nodes.push({ p, tag });
		return nodes.length - 1;
	};
	const edge = (a, b, w, kind) => edges.push({ a, b, w: w === undefined ? len(sub(nodes[a].p, nodes[b].p)) : w, kind });
	// promenade arc, 1 degree steps, plus each entrance
	const promNodes = [];
	for (let b = -90; b <= 90; b += 1) promNodes.push({ b, n: node(polar(b, prom.centre), "prom") });
	for (let i = 1; i < promNodes.length; i++) edge(promNodes[i - 1].n, promNodes[i].n, undefined, "promenade");
	const nearestProm = (b) => promNodes.reduce((m, q) => (Math.abs(q.b - b) < Math.abs(m.b - b) ? q : m));
	// ring path
	const ringNodes = [];
	for (let b = -80; b <= 80; b += 1) ringNodes.push({ b, n: node(polar(b, P.ringR), "ring") });
	for (let i = 1; i < ringNodes.length; i++) edge(ringNodes[i - 1].n, ringNodes[i].n, undefined, "ring");
	const nearestRing = (b) => ringNodes.reduce((m, q) => (Math.abs(q.b - b) < Math.abs(m.b - b) ? q : m));
	// plaza boundary nodes
	const plazaNodes = [];
	const plaza = (p, tag) => {
		const n = node(p, tag);
		for (const q of plazaNodes) edge(n, q, aroundDisk(p, nodes[q].p, P.basinR + 1), "plaza");
		plazaNodes.push(n);
		return n;
	};
	const fountain = node(V(0, -(P.basinR + 1)), "fountain"); // stands at the rim; any rim point is equivalent by symmetry for radial arrivals
	// entrances and avenues
	const ent = [];
	for (const p of plots) {
		const e = node(p.entrance, "entrance" + p.index);
		ent.push(e);
		const pr = node(polar(p.bearing, prom.centre), "promAt" + p.index);
		edge(e, pr, undefined, "court");
		edge(pr, nearestProm(p.bearing).n, 0.0001, "join");
		const rg = node(polar(p.bearing, P.ringR), "ringAt" + p.index);
		edge(pr, rg, undefined, "avenue");
		edge(rg, nearestRing(p.bearing).n, 0.0001, "join");
		const pz = plaza(polar(p.bearing, P.plazaR), "plazaAt" + p.index);
		edge(rg, pz, undefined, "avenue");
	}
	// every rim point: the fountain destination is the nearest rim point from each avenue mouth
	const fountainRim = plots.map((p) => node(polar(p.bearing, P.basinR + 1), "rim" + p.index));
	plots.forEach((p, k) => edge(fountainRim[k], plazaNodes[k], P.plazaR - P.basinR - 1, "plaza"));
	// portal approaches and a stage walk along the portal fronts
	const dest = {};
	const stage = [];
	for (const q of portals) {
		const front = node(V(q.x, q.front.y + 3), q.id);
		const dir = mul(sub(V(q.x, q.front.y + 3), V(0, 0)), 1 / len(V(q.x, q.front.y + 3)));
		const mouth = plaza(mul(dir, P.plazaR), "mouth" + q.id);
		edge(mouth, front, undefined, "approach");
		dest[q.id] = front;
		stage.push(front);
	}
	for (let i = 1; i < stage.length; i++) edge(stage[i - 1], stage[i], undefined, "stage");
	// stage walk ends to the promenade ends (lakeside walk)
	const westEnd = promNodes[0].n;
	const eastEnd = promNodes[promNodes.length - 1].n;
	if (!H.wingsRoute) edge(stage[0], westEnd, undefined, "lakeside");
	if (!H.wingsRoute) edge(stage[stage.length - 1], eastEnd, undefined, "lakeside");
	// buildings: a spur from the door to the nearest of plaza, ring or promenade
	for (const b of extras) {
		const dn = node(b.door, b.id);
		const rB = (Math.atan2(b.door.x, b.door.y) * 180) / Math.PI;
		const options = [
			{ n: plaza(mul(b.door, P.plazaR / len(b.door)), "mouth" + b.id), d: len(b.door) - P.plazaR },
			{ n: nearestRing(rB).n, d: null },
		];
		for (const o of options) edge(dn, o.n, o.d === null ? undefined : o.d, "spur");
		if (b.lakeside) edge(dn, b.door.x < 0 ? stage[0] : stage[stage.length - 1], undefined, "stage");
		for (const k of b.links || []) {
			const to = { stage: b.door.x < 0 ? stage[0] : stage[stage.length - 1], prom: b.door.x < 0 ? westEnd : eastEnd }[k.to];
			edge(dn, to, k.w, k.kind);
		}
		dest[b.id] = dn;
	}
	dest.Fountain = "rim";
	// Dijkstra
	const adj = nodes.map(() => []);
	for (const e of edges) {
		adj[e.a].push([e.b, e.w, e.kind]);
		adj[e.b].push([e.a, e.w, e.kind]);
	}
	function sp(src) {
		const dist = new Array(nodes.length).fill(Infinity);
		const prev = new Array(nodes.length).fill(-1);
		dist[src] = 0;
		const done = new Array(nodes.length).fill(false);
		for (;;) {
			let u = -1;
			let best = Infinity;
			for (let i = 0; i < nodes.length; i++) if (!done[i] && dist[i] < best) {
				best = dist[i];
				u = i;
			}
			if (u < 0) break;
			done[u] = true;
			for (const [v, w] of adj[u]) if (dist[u] + w < dist[v]) {
				dist[v] = dist[u] + w;
				prev[v] = u;
			}
		}
		return { dist, prev };
	}
	const routes = {};
	plots.forEach((p, k) => {
		const { dist, prev } = sp(ent[k]);
		const row = {};
		const lines = {};
		for (const [name, n] of Object.entries(dest)) {
			if (n === "rim") {
				row.Fountain = Math.min(...fountainRim.map((f) => dist[f]));
				continue;
			}
			row[name] = dist[n];
			const pts = [];
			for (let at = n; at >= 0; at = prev[at]) pts.push(nodes[at].p);
			lines[name] = pts.reverse();
		}
		routes[p.index] = { dist: row, lines };
	});
	return { nodes, edges, routes };
}

// ---------- stream ----------
function spline(w, steps = 16) {
	const pts = [];
	const P = [w[0], ...w, w[w.length - 1]];
	for (let i = 1; i < P.length - 2; i++)
		for (let k = 0; k < steps; k++) {
			const t = k / steps;
			const [a, b, c, d] = [P[i - 1], P[i], P[i + 1], P[i + 2]];
			const f = (A, B, C, D) => 0.5 * (2 * B + (-A + C) * t + (2 * A - 5 * B + 4 * C - D) * t * t + (-A + 3 * B - 3 * C + D) * t * t * t);
			pts.push(V(f(a.x, b.x, c.x, d.x), f(a.y, b.y, c.y, d.y)));
		}
	pts.push(w[w.length - 1]);
	return pts;
}
function bezier(p0, p1, p2, p3, n = 120) {
	const pts = [];
	for (let i = 0; i <= n; i++) {
		const t = i / n;
		const a = (1 - t) ** 3;
		const b = 3 * (1 - t) ** 2 * t;
		const c = 3 * (1 - t) * t * t;
		const d = t ** 3;
		pts.push(V(a * p0.x + b * p1.x + c * p2.x + d * p3.x, a * p0.y + b * p1.y + c * p2.y + d * p3.y));
	}
	return pts;
}

function run(over, label) {
	const H = layout(over);
	if (H.tangential) {
		const g = H.T.geom;
		return { label, tangential: true, r0: r1(g.r0), frontBandInner: r1(g.u1), outer: r1(g.uFar), fountainSeconds: r1((g.r0 - H.P.basinR - 1) / WALK) };
	}
	const { P, g } = H;
	const check = checkPlot(H.T);
	// Task 4 (2026-10-22): one mirrored river loop replaces the S stream (it reached the lake on one
	// side only), and the Garage and the Stunt Circuit entrance become a mirrored pair of lakeside
	// wings. task4-layout.js measured every closer position: each one hides part of a portal field
	// from an entrance, hides one plot's waterfall view, or sits on an avenue.
	const T4 = P.task4;
	const mirror = (p) => V(2 * T4.axisX - p.x, p.y);
	const facingBox = (c, w, d) => {
		const dir = mul(c, -1 / len(c)); // front toward the fountain
		const side = V(-dir.y, dir.x);
		const poly = [add(add(c, mul(side, w / 2)), mul(dir, d / 2)), add(sub(c, mul(side, w / 2)), mul(dir, d / 2)), sub(sub(c, mul(side, w / 2)), mul(dir, d / 2)), sub(add(c, mul(side, w / 2)), mul(dir, d / 2))];
		return { c, poly, door: add(c, mul(dir, d / 2 + 2)), w, d, dir, side };
	};
	const eastWay = [];
	for (let bb = 0; bb < T4.riverTurn; bb += 12) eastWay.push(polar(bb, T4.riverR));
	eastWay.push(polar(T4.riverTurn, T4.riverR));
	for (const [x, y] of T4.riverLeg) eastWay.push(V(x, y));
	const stream = spline([...eastWay.slice(1).reverse().map(mirror), ...eastWay], 8); // west lake to east lake
	const arcPts = (r, b0, b1) => {
		const pts = [];
		for (let b = b0; b <= b1; b += 1) pts.push(polar(b, r));
		return pts;
	};
	const ringStrips = strip(arcPts(P.ringR, -80, 80), 16);
	const streamStrips = strip(stream, T4.riverWidth + 2);
	const garage = Object.assign(facingBox(polar(T4.wingBearing, T4.wingR), T4.garage.w, T4.garage.d), { id: "Garage" });
	const stunt = Object.assign(facingBox(mirror(garage.c), T4.stunt.w, T4.stunt.d), { id: "StuntGate" });
	// the start-line gantry stands at the front of the Stunt envelope; its apron runs outward
	stunt.gantry = add(stunt.c, mul(stunt.dir, T4.stunt.d / 2 - 3));
	const gazebo = Object.assign(facingBox(polar(0, T4.gazebo.r), T4.gazebo.w, T4.gazebo.d), { id: "Gazebo" });
	const food = Object.assign(facingBox(polar(T4.snack.bearing, T4.snack.r), T4.snack.w, T4.snack.d), { id: "SnackCornerEast" });
	const foodWest = Object.assign(facingBox(mirror(food.c), T4.snack.w, T4.snack.d), { id: "SnackCornerWest" });
	// leaderboards: Most Cars Owned beside the Garage (north end of its forecourt), Fastest Stunt
	// Circuit at the mirrored spot beside the Stunt entrance
	const north = garage.side.y > 0 ? garage.side : mul(garage.side, -1);
	const boardC = add(add(garage.c, mul(garage.dir, T4.garage.d / 2 + 3)), mul(north, T4.garage.w / 2 + T4.board.along));
	const boards = [
		Object.assign(facingBox(boardC, T4.board.w, T4.board.d), { id: "LeaderboardGarage", h: T4.board.h }),
		Object.assign(facingBox(mirror(boardC), T4.board.w, T4.board.d), { id: "LeaderboardStunt", h: T4.board.h }),
	];
	// walks: each lakeside walk leaves the stage end and joins its wing's approach before the
	// bridge; a forecourt walk carries on past the leaderboard to the promenade end
	const mouthOf = (bd) => mul(bd.door, P.plazaR / len(bd.door));
	const joinOf = (bd) => add(mouthOf(bd), mul(sub(bd.door, mouthOf(bd)), 0.55));
	const fore = add(garage.door, mul(garage.dir, 12)); // forecourt walk line, 14 in front of the facade
	const foreN = add(fore, mul(north, T4.garage.w / 2 + T4.board.along + T4.board.w + 6)); // past the board
	const walks = {
		LakesideEast: [V(P.portal.spacing, P.portal.frontY + 3), joinOf(garage)],
		ForecourtEast: [fore, foreN, polar(90, H.prom.centre)],
	};
	walks.LakesideWest = walks.LakesideEast.map(mirror);
	walks.ForecourtWest = walks.ForecourtEast.map(mirror);
	const polyLen = (pts) => pts.slice(1).reduce((t, q, i) => t + len(sub(q, pts[i])), 0);
	H.wingsRoute = true;
	const wingLinks = [
		{ to: "stage", kind: "lakeside", w: polyLen(walks.LakesideEast) + len(sub(garage.door, joinOf(garage))) },
		{ to: "prom", kind: "lakeside", w: len(sub(garage.door, fore)) + polyLen(walks.ForecourtEast) },
	];
	const boardX = P.portal.spacing + P.portal.outer / 2 + 18;
	// alternatives for the review: Garage and Stunt gate as wings at the ends of the stage
	const wing = (x) => {
		const c = V(x, P.portal.frontY - 4);
		return { c, poly: rect(x - 22, x + 22, c.y - 18, c.y + 18), door: V(x, c.y + 20) };
	};
	const wingX = boardX + 40;
	const alt = network(H, [
		{ id: "GarageWestWing", door: wing(-wingX).door, lakeside: true },
		{ id: "StuntEastWing", door: wing(wingX).door, lakeside: true },
	]);
	const extras = [
		{ id: "Garage", door: garage.door, links: wingLinks },
		{ id: "StuntGate", door: stunt.door, links: wingLinks },
	];
	const net = network(H, extras);
	// bridges where the stream crosses a path centre line
	const pathLines = [];
	for (const a of H.avenues) pathLines.push({ kind: "avenue " + a.index, pts: a.line, w: P.avenueW });
	const arc = (r, b0, b1) => {
		const pts = [];
		for (let b = b0; b <= b1; b += 1) pts.push(polar(b, r));
		return pts;
	};
	pathLines.push({ kind: "promenade", pts: arc(H.prom.centre, -90, 90), w: P.promenadeW });
	pathLines.push({ kind: "garden ring", pts: arc(P.ringR, -80, 80), w: 8 });
	for (const q of H.portals) pathLines.push({ kind: "approach " + q.id, pts: [mul(q.front, P.plazaR / len(q.front)), q.front], w: 14 });
	pathLines.push({ kind: "stage walk", pts: [V(-P.portal.spacing, P.portal.frontY + 3), V(P.portal.spacing, P.portal.frontY + 3)], w: 10 });
	for (const [kind, pts] of Object.entries(walks)) pathLines.push({ kind, pts, w: 10 });
	for (const b of [garage, stunt]) pathLines.push({ kind: b.id + " approach", pts: [b.door, mul(b.door, P.plazaR / len(b.door))], w: 12 });
	const bridges = [];
	for (const pl of pathLines)
		for (let i = 1; i < pl.pts.length; i++)
			for (let j = 1; j < stream.length; j++) {
				// half-open on the stream so a crossing exactly at a stream vertex counts once
				const x = segXHalfOpen(pl.pts[i - 1], pl.pts[i], stream[j - 1], stream[j]);
				if (x) bridges.push({ path: pl.kind, at: V(r1(x.p.x), r1(x.p.y)), deckWidth: pl.w + 2, span: 10 + 6 });
			}
	const streamClear = Math.min(...stream.map((p) => len(p))) - 9;
	// sightline obstacles: things taller than eye level inside any corridor
	const tall = [
		{ id: "Garage", poly: garage.poly, h: 22 },
		{ id: "StuntGate", poly: stunt.poly, h: 16 },
		{ id: "Gazebo", poly: gazebo.poly, h: 12 },
		{ id: "SnackCornerEast", poly: food.poly, h: T4.snack.h },
		{ id: "SnackCornerWest", poly: foodWest.poly, h: T4.snack.h },
		...boards.map((b) => ({ id: b.id, poly: b.poly, h: b.h })),
	];
	const corridorHits = [];
	H.corridors.forEach((t, k) => {
		for (const o of tall) if (overlaps(o.poly, t)) corridorHits.push({ plot: k + 1, obstacle: o.id });
	});
	// routes table
	const table = {};
	const destNames = ["Fountain", "SummitPass", "Downtown", "DustyHighway", "Garage", "StuntGate", "GarageWestWing", "StuntEastWing"];
	for (const d of destNames) {
		const src = d.endsWith("Wing") ? alt : net;
		const vals = H.plots.map((p) => src.routes[p.index].dist[d]);
		table[d] = {
			studs: vals.map(r2),
			seconds: vals.map((v) => r1(v / WALK)),
			best: r1(Math.min(...vals) / WALK),
			worst: r1(Math.max(...vals) / WALK),
			spread: r1((Math.max(...vals) - Math.min(...vals)) / WALK),
			straightLine: H.plots.map((p) => r1(len(sub(p.entrance, d === "Fountain" ? V(0, 0) : src.nodes.find((n) => n.tag === d).p)) / WALK)),
		};
	}
	// the stream must stay clear of the plaza, buildings and portals
	const streamHits = [garage, stunt, gazebo, food, foodWest, ...boards].filter((b) => streamStrips.some((q) => overlaps(q, b.poly))).map((b) => b.id);
	return { label, H, check, stream, streamClear, streamHits, garage, stunt, gazebo, food, foodWest, boards, walks, wing, wingX, net, alt, table, bridges, corridorHits, extras };
}

// ---------- report ----------
function summary(o) {
	if (o.tangential) return o;
	const { H, check, table } = o;
	const g = H.g;
	const P = H.P;
	return {
		label: o.label,
		plots: P.plots,
		sectorDeg: 180 / P.plots,
		bufferStuds: P.buffer,
		plotBearings: H.bearings,
		r0_entrance: r1(g.r0),
		frontZone: [r1(g.r0), r1(g.r0 + P.frontDepth)],
		ovalNearTip: r1(g.uTip),
		straightsStart: r1(g.uS),
		ovalFarTip: r1(g.uFar),
		plotOuterRadius: r1(H.rMax),
		plotDepth: r1(H.rMax - g.r0),
		usableHalfWidthAtEntrance: r1(H.T.wAt(g.r0)),
		usableHalfWidthAtStraights: r1(H.T.wAt(g.uS)),
		track: {
			path: r1(2 * H.T.L + 2 * Math.PI * P.R),
			straight: r1(H.T.L),
			turnRadius: P.R,
			width: P.trackWidth,
			clearanceFootprint: [r1(2 * g.rOut), r1(H.T.L + 2 * g.rOut)],
			infieldWidth: r1(2 * g.rIn),
		},
		containment: check.contain,
		overlaps: check.pairs,
		infield: check.infield,
		neighbours: H.neighbour,
		promenade: H.prom,
		portals: H.portals.map((q) => ({ id: q.id, x: q.x, frontY: q.front.y })),
		garage: { centre: V(r1(o.garage.c.x), r1(o.garage.c.y)), door: V(r1(o.garage.door.x), r1(o.garage.door.y)) },
		stunt: { centre: V(r1(o.stunt.c.x), r1(o.stunt.c.y)), door: V(r1(o.stunt.door.x), r1(o.stunt.door.y)) },
		streamMinRadius: r1(o.streamClear),
		streamHits: o.streamHits,
		gazebo: V(r1(o.gazebo.c.x), r1(o.gazebo.c.y)),
		food: V(r1(o.food.c.x), r1(o.food.c.y)),
		bridges: o.bridges,
		corridorHits: o.corridorHits,
		routes: table,
	};
}

module.exports = { run, summary, baseParams, layout, network, toPlan, polar, rect, V, len, sub, add, mul, overlaps, inside, area, strip, WALK };

if (require.main === module) {
	const outDir = process.argv[2] || ".";
	fs.mkdirSync(outDir, { recursive: true });
	const variants = [
		[{}, "six plots, radial oval R 35 (recommended)"],
		[{ plots: 5 }, "five plots, radial oval R 35"],
		[{ R: 30 }, "six plots, radial oval R 30"],
		[{ orientation: "tangential" }, "six plots, tangential oval R 35"],
		[{ plots: 5, orientation: "tangential" }, "five plots, tangential oval R 35"],
	];
	const out = variants.map(([o, l]) => summary(run(o, l)));
	fs.writeFileSync(path.join(outDir, "layout.json"), JSON.stringify(out, null, 1));
	for (const s of out) {
		if (s.tangential) {
			console.log(`${s.label}: entrance r ${s.r0}, front band from ${s.frontBandInner}, outer ${s.outer}, fountain ${s.fountainSeconds} s`);
			continue;
		}
		const bad = s.containment.filter((c) => !c.ok).map((c) => c.id);
		const conf = s.overlaps.filter((p) => !p.allowed);
		console.log(`\n== ${s.label}`);
		console.log(`entrance r ${s.r0_entrance}; front ${s.frontZone}; oval tip ${s.ovalNearTip}; straights from ${s.straightsStart}; far tip ${s.ovalFarTip}; plot outer ${s.plotOuterRadius} (depth ${s.plotDepth})`);
		console.log(`track ${JSON.stringify(s.track)}`);
		console.log(`containment failures: ${bad.length ? bad.join(", ") : "none"}; conflicts: ${conf.length ? JSON.stringify(conf) : "none"}; infield ${JSON.stringify(s.infield)}`);
		console.log(`neighbours ${JSON.stringify(s.neighbours)}; garage ${JSON.stringify(s.garage)}; stunt ${JSON.stringify(s.stunt)}; corridor hits ${JSON.stringify(s.corridorHits)}`);
		console.log(`stream hits ${s.streamHits}; gazebo ${JSON.stringify(s.gazebo)} food ${JSON.stringify(s.food)}; stream min radius ${s.streamMinRadius}; bridges ${s.bridges.length}: ${s.bridges.map((b) => b.path).join(", ")}`);
		for (const [d, t] of Object.entries(s.routes)) console.log(`  ${d.padEnd(15)} s ${t.seconds.join(" / ")}  best ${t.best} worst ${t.worst} spread ${t.spread}`);
	}
}
