// Car Hop island rework, Task 4: destination pair, river loop and sightline envelopes (Lane 3,
// design calculation). Builds on island-layout.js (same plan frame: x east, y north toward the
// plots, origin at the fountain centre; Roblox world X = x, Z = -y). The island's centre axis is
// x = 0: every mirrored pair below is placed at (+x, y) and (-x, y).
//
// What it measures (pure geometry, no Roblox):
//   * portal-field visibility: rays from every plot entrance (27 eye points: eye 4.5 / 5.5 / 6.5,
//     3 studs either side, 4 studs ahead / behind) to a grid over each 20 x 30 field;
//   * falls visibility: the same eyes to a grid over the lower falls (x -131 to -111, 4 to 70 up,
//     at plan y -271) and the upper falls (x -128 to -114, 70 to 130 up);
//   * the river loop: one mirrored watercourse round the inner park, lake to lake;
//   * a symmetric search for the Garage (east) and Stunt Circuit entrance (west) with their
//     leaderboards, outside every route strip and blocking no ray to a portal field, scoring
//     falls rays blocked, then walking time.
// Sampling is evidence with limits: a ray grid at 1.5-stud spacing, boxes as extruded
// footprints. Run: node task4-layout.js <outDir>

"use strict";
const fs = require("fs");
const path = require("path");
const L = require("./island-layout.js");
const { V, len, sub, add, mul, polar, rect, overlaps, inside, strip } = L;

const WALK = 16;
const BOOST = 1.5; // authorised for Task 4 (Adam): 1.5 x on the avenue strips

// ---------- task 4 parameters (all tunable here, nowhere else) ----------
const T4 = {
	axisX: 0,
	ground: 0.3, // plaza surface height
	river: { radius: 200, width: 16, bankWidth: 6, endBearing: 118, lakeEntry: 14 },
	garage: { w: 70, d: 40, h: 26, roofTop: 34 }, // footprint and heights (eaves, sculpture top)
	stunt: { span: 22, pillar: 3.5, beamDepth: 4, beamUnder: 10, h: 18, d: 30 }, // gantry (research note) and apron depth
	board: { w: 12, d: 4, h: 14 },
	clear: { avenue: 6, ring: 4, river: 6, promenade: 6, plaza: 10 },
	field: { w: 20, h: 30, bottom: 2.8 },
	falls: { lower: { x0: -131, x1: -111, h0: 4, h1: 70 }, upper: { x0: -128, x1: -114, h0: 70, h1: 130 }, y: -271 },
};

// ---------- rays ----------
function eyes(e) {
	// the 27 eye points round an entrance, facing the fountain
	const fwd = mul(e, -1 / len(e));
	const side = V(-fwd.y, fwd.x);
	const out = [];
	for (const h of [4.5, 5.5, 6.5]) for (const s of [-3, 0, 3]) for (const f of [-4, 0, 4]) out.push({ p: add(add(e, mul(side, s)), mul(fwd, f)), z: T4.ground + h });
	return out;
}
function fieldTargets(qx, frontY) {
	const pts = [];
	const y = frontY - 3; // field plane (PortalRig: field centre 3 behind the portal front)
	for (let u = -T4.field.w / 2 + 1; u <= T4.field.w / 2 - 1; u += 1.5)
		for (let v = 1; v <= T4.field.h - 1; v += 1.5) pts.push({ p: V(qx + u, y + 1), z: T4.ground + T4.field.bottom + v });
	return pts;
}
function fallsTargets(band) {
	const pts = [];
	for (let x = band.x0; x <= band.x1; x += 2) for (let h = band.h0; h <= band.h1; h += 4) pts.push({ p: V(x, T4.falls.y), z: h });
	return pts;
}
// does the segment eye -> target pass through the extruded footprint (poly, height h)?
function blocks(eye, tgt, poly, h, z0 = -1e9) {
	// quick reject: the segment's bounding box misses the footprint's
	const xs = poly.map((q) => q.x);
	const ys = poly.map((q) => q.y);
	if (Math.max(eye.p.x, tgt.p.x) < Math.min(...xs) || Math.min(eye.p.x, tgt.p.x) > Math.max(...xs)) return false;
	if (Math.max(eye.p.y, tgt.p.y) < Math.min(...ys) || Math.min(eye.p.y, tgt.p.y) > Math.max(...ys)) return false;
	const d = sub(tgt.p, eye.p);
	const n = 40;
	for (let i = 1; i < n; i++) {
		const t = i / n;
		const p = add(eye.p, mul(d, t));
		if (inside(p, poly)) {
			const z = eye.z + (tgt.z - eye.z) * t;
			if (z < h && z >= z0) return true;
		}
	}
	return false;
}
function blockedFraction(entrances, targets, boxes) {
	let total = 0;
	let hit = 0;
	for (const e of entrances)
		for (const eye of eyes(e))
			for (const t of targets) {
				total++;
				if (boxes.some((b) => blocks(eye, t, b.poly, b.h, b.z0))) hit++;
			}
	return total ? hit / total : 0;
}

// ---------- footprints ----------
function facing(c, w, d) {
	// a w (tangential) x d (radial) footprint centred at c, front toward the fountain
	const r = len(c);
	const dir = mul(c, -1 / r);
	const side = V(-dir.y, dir.x);
	const poly = [add(add(c, mul(side, w / 2)), mul(dir, d / 2)), add(sub(c, mul(side, w / 2)), mul(dir, d / 2)), sub(sub(c, mul(side, w / 2)), mul(dir, d / 2)), sub(add(c, mul(side, w / 2)), mul(dir, d / 2))];
	return { c, poly, door: add(c, mul(dir, d / 2 + 2)), dir, side };
}
const mirror = (p) => V(2 * T4.axisX - p.x, p.y);

// ---------- river loop ----------
function riverLoop(H) {
	const R = T4.river.radius;
	const pts = [];
	const b1 = T4.river.endBearing;
	for (let b = -b1; b <= b1; b += 2) pts.push(polar(b, R));
	// each end runs on into the lake until well inside the water (lake ellipse at (0,-172), 300 x 100)
	const lake = { c: V(0, -172), rx: 300, ry: 100 };
	const inLake = (p) => ((p.x - lake.c.x) / lake.rx) ** 2 + ((p.y - lake.c.y) / lake.ry) ** 2 < 1;
	const extend = (from, prev) => {
		const out = [];
		const dir = mul(sub(from, prev), 1 / len(sub(from, prev)));
		let p = from;
		for (let k = 0; k < 40 && !(inLake(p) && out.length > T4.river.lakeEntry / 2); k++) {
			p = add(p, mul(dir, 2));
			out.push(p);
		}
		return out;
	};
	const tail = extend(pts[pts.length - 1], pts[pts.length - 2]);
	const head = extend(pts[0], pts[1]).reverse();
	const all = [...head, ...pts, ...tail];
	// mirror check: the loop is symmetric about the axis by construction (bearings -b..b)
	return { centre: all, R, width: T4.river.width, strips: strip(all, T4.river.width + 2 * T4.river.bankWidth) };
}

// ---------- search ----------
const LAKE = { c: V(0, -172), rx: 300, ry: 100 };
const lakeValue = (p) => ((p.x - LAKE.c.x) / LAKE.rx) ** 2 + ((p.y - LAKE.c.y) / LAKE.ry) ** 2;
// the Stunt entrance as what actually blocks a view: two pillars and the beam band above the
// apron (the apron, grid boxes and tire walls stay under 3, below every eye)
function gantryBoxes(f, span) {
	const S = T4.stunt;
	const pillar = (k) => {
		const c = add(f.c, mul(f.side, k * (span / 2 + S.pillar / 2)));
		return facing(c, S.pillar, S.pillar).poly;
	};
	return [
		{ id: "StuntPillarL", poly: pillar(-1), h: S.h },
		{ id: "StuntPillarR", poly: pillar(1), h: S.h },
		{ id: "StuntBeam", poly: facing(f.c, span + 2 * S.pillar, S.beamDepth).poly, z0: S.beamUnder, h: S.h },
	];
}
function search(opts = {}) {
	const o = L.run({}, "task4");
	const { H } = o;
	const { P } = H;
	const entrances = H.plots.map((p) => p.entrance);
	const fields = H.portals.map((q) => fieldTargets(q.x, q.front.y));
	const fieldsCoarse = fields.map((f) => f.filter((_, i) => i % 3 === 0));
	const fallsLower = fallsTargets(T4.falls.lower);
	const fallsUpper = fallsTargets(T4.falls.upper);
	const arc = (r, b0, b1) => {
		const out = [];
		for (let b = b0; b <= b1; b += 1) out.push(polar(b, r));
		return out;
	};
	// fixed routes a building may not sit on (the lakeside walks are re-routed round whatever is
	// chosen, so they are not fixed here)
	const routeStrips = [
		...H.avenues.flatMap((av) => strip(av.line, P.avenueW + 2 * T4.clear.avenue)),
		...strip(arc(P.ringR, -80, 80), 8 + 2 * T4.clear.ring),
		...H.portals.flatMap((q) => [rect(q.x - P.portal.outer / 2 - 8, q.x + P.portal.outer / 2 + 8, q.front.y - P.portal.depth - 8, q.front.y + 8), ...strip([mul(q.front, P.plazaR / len(q.front)), q.front], 14 + 8)]),
	];
	const ok = (poly) =>
		!routeStrips.some((q) => overlaps(poly, q)) &&
		poly.every((p) => len(p) > P.plazaR + T4.clear.plaza && len(p) < H.prom.inner - T4.clear.promenade && lakeValue(p) > 1.12);
	const B = T4.board;
	const res = [];
	for (const gw of opts.widths || [70, 62, 54])
		for (let r = 60; r <= 222; r += 3)
			for (let b = 8; b <= 172; b += 1.5) {
				const c = polar(b, r);
				const G = T4.garage;
				const g = facing(c, gw, G.d);
				if (!ok(g.poly)) continue;
				const sf = facing(mirror(c), T4.stunt.span + 2 * T4.stunt.pillar + 8, T4.stunt.d);
				if (!ok(sf.poly)) continue;
				// leaderboards beside each building, flush with its front, whichever side fits
				let gb = null;
				for (const k of [1, -1]) {
					const cb = add(add(c, mul(g.side, k * (gw / 2 + B.w / 2 + 6))), mul(g.dir, G.d / 2 - B.d / 2));
					const f = facing(cb, B.w, B.d);
					const fm = facing(mirror(cb), B.w, B.d);
					if (ok(f.poly) && ok(fm.poly)) {
						gb = [f, fm];
						break;
					}
				}
				if (!gb) continue;
				const boxes = [{ id: "Garage", poly: g.poly, h: G.roofTop }, ...gantryBoxes(sf, T4.stunt.span), { id: "BoardGarage", poly: gb[0].poly, h: B.h }, { id: "BoardStunt", poly: gb[1].poly, h: B.h }];
				let portalBlocked = 0;
				for (const f of fieldsCoarse) portalBlocked += blockedFraction(entrances, f, boxes);
				if (portalBlocked > 0) continue;
				res.push({ gw, b, r, g, s: sf, gb, boxes });
			}
	for (const c of res) {
		c.fallsLower = blockedFraction(entrances, fallsLower, c.boxes);
		c.fallsUpper = blockedFraction(entrances, fallsUpper, c.boxes);
		c.walk = walkTable(H, [
			{ id: "Garage", door: c.g.door },
			{ id: "StuntGate", door: c.s.door },
		]);
		c.radialSpan = [Math.min(...c.g.poly.map(len)), Math.max(...c.g.poly.map(len))];
	}
	return { o, H, candidates: res, entrances, fields, fallsLower, fallsUpper, routeStrips };
}

// walking time on the layout's own path network (island-layout.js network()), with the avenue
// edges at the boost speed and everything else at walking speed
function walkTable(H, extras, boost = BOOST) {
	const net = L.network(H, extras);
	const adj = net.nodes.map(() => []);
	for (const e of net.edges) {
		const t = e.w / (e.kind === "avenue" ? WALK * boost : WALK);
		adj[e.a].push([e.b, t]);
		adj[e.b].push([e.a, t]);
	}
	const rows = {};
	for (const x of extras) rows[x.id] = [];
	for (const p of H.plots) {
		const src = net.nodes.findIndex((n) => n.tag === "entrance" + p.index);
		const dist = dijkstra(adj, src);
		for (const x of extras) rows[x.id].push(dist[net.nodes.findIndex((n) => n.tag === x.id)]);
	}
	let worst = 0;
	let spread = 0;
	const out = {};
	for (const [id, t] of Object.entries(rows)) {
		out[id] = { seconds: t.map((v) => Math.round(v * 10) / 10), worst: Math.max(...t), spread: Math.max(...t) - Math.min(...t) };
		worst = Math.max(worst, out[id].worst);
		spread = Math.max(spread, out[id].spread);
	}
	return { rows: out, worst, spread };
}
function dijkstra(adj, src) {
	const dist = new Array(adj.length).fill(Infinity);
	const done = new Array(adj.length).fill(false);
	dist[src] = 0;
	for (;;) {
		let u = -1;
		let best = Infinity;
		for (let i = 0; i < adj.length; i++) if (!done[i] && dist[i] < best) (best = dist[i]), (u = i);
		if (u < 0) break;
		done[u] = true;
		for (const [v, w] of adj[u]) if (dist[u] + w < dist[v]) dist[v] = dist[u] + w;
	}
	return dist;
}

module.exports = { T4, search, check, riverLoop, blockedFraction, eyes, fieldTargets, fallsTargets, facing, mirror };

// ---------- checks on the chosen layout (island-layout.js run(), P.task4) ----------
// Tolerances: rays use the full field grid (1.5 studs) and falls grid (2 x 4 studs) from 27 eye
// points per entrance; a ray counts as blocked when any of 40 samples along it is inside a
// footprint below that object's top (and above its underside, for the gantry beam). Clearances
// are footprint-to-strip overlaps at the stated margins. Mirror pairs must agree to 0.01 stud.
function check(over = {}) {
	const o = L.run(over, "task4 chosen");
	const { H } = o;
	const { P } = H;
	const C = P.task4;
	const entrances = H.plots.map((p) => p.entrance);
	const fields = H.portals.map((q) => fieldTargets(q.x, q.front.y));
	const fallsLower = fallsTargets(T4.falls.lower);
	const fallsUpper = fallsTargets(T4.falls.upper);
	const gantryAt = { c: o.stunt.gantry, side: o.stunt.side, dir: o.stunt.dir };
	const tall = [
		{ id: "Garage", poly: o.garage.poly, h: C.garage.top },
		...gantryBoxes(gantryAt, T4.stunt.span),
		...o.boards.map((b) => ({ id: b.id, poly: b.poly, h: b.h })),
		// the portal gate family (kit_gates production): per gate two columns with their stepped
		// plinths and capitals, |x| 10.6 to 15.4 from the field centre line, 5 deep, top 33; the
		// crest band x ±15, z 33 to 44, and the crown x ±10, up to 50
		...H.portals.flatMap((q) => {
			const y = q.front.y - P.portal.depth / 2;
			return [
				{ id: q.id + "ColumnW", poly: rect(q.x - 15.4, q.x - 10.6, y - 2.5, y + 2.5), h: 33 },
				{ id: q.id + "ColumnE", poly: rect(q.x + 10.6, q.x + 15.4, y - 2.5, y + 2.5), h: 33 },
				{ id: q.id + "Crest", poly: rect(q.x - 15, q.x + 15, y - 2.4, y + 2.4), z0: 33, h: 44 },
				{ id: q.id + "Crown", poly: rect(q.x - 10, q.x + 10, y - 1, y + 2.6), z0: 42.8, h: 50 },
			];
		}),
		// the Stunt loop sculpture on its pedestal at the closed end of the apron (kit_stunt
		// production placed it at x -8..8, y 14.2..19.8 and it hid 2 % of Plot 1's lower falls at any height, so the loop stands in the side strip x 13.4..18.3, y -10..2, top 12.9; its low pedestal, top 4.4, stays at the closed end) and the two checkered flags
		// (x Â±9.6, y 17, top 10.1); envelope-local +y runs away from the fountain
		...(() => {
			const s = o.stunt;
			const at = (x, y) => add(add(s.c, mul(s.side, x)), mul(s.dir, -y));
			const box = (x0, x1, y0, y1) => [at(x0, y0), at(x1, y0), at(x1, y1), at(x0, y1)];
			return [
				{ id: "StuntLoop", poly: box(13.4, 18.3, -10, 2), h: 12.9 },
				{ id: "StuntPedestal", poly: box(-8, 8, 14.2, 19.8), h: 4.4 },
				{ id: "StuntFlagL", poly: box(-10.1, -9.1, 16.5, 17.5), h: 10.1 },
				{ id: "StuntFlagR", poly: box(9.1, 10.1, 16.5, 17.5), h: 10.1 },
			];
		})(),
		{ id: "Gazebo", poly: o.gazebo.poly, h: C.gazebo.h },
		{ id: "SnackCornerEast", poly: o.food.poly, h: C.snack.h },
		{ id: "SnackCornerWest", poly: o.foodWest.poly, h: C.snack.h },
	];
	const failures = [];
	// 1. portal fields: every ray from every entrance clear
	const portal = H.portals.map((q, i) => {
		const per = entrances.map((e) => blockedFraction([e], fields[i], tall));
		per.forEach((f, k) => {
			if (f > 0) {
				const who = tall.filter((b) => blockedFraction([entrances[k]], fields[i], [b]) > 0).map((b) => b.id);
				failures.push({ check: "portal field", portal: q.id, plot: k + 1, blockedPct: f * 100, objects: who });
			}
		});
		return { portal: q.id, blockedPctByPlot: per.map((f) => Math.round(f * 1000) / 10) };
	});
	// 2. waterfall, lower and upper parts
	const falls = entrances.map((e, k) => {
		const lo = blockedFraction([e], fallsLower, tall);
		const up = blockedFraction([e], fallsUpper, tall);
		if (lo > 0 || up > 0) failures.push({ check: "waterfall", plot: k + 1, lowerPct: lo * 100, upperPct: up * 100, objects: tall.filter((b) => blockedFraction([e], [...fallsLower, ...fallsUpper], [b]) > 0).map((b) => b.id) });
		return { plot: k + 1, lowerBlockedPct: Math.round(lo * 1000) / 10, upperBlockedPct: Math.round(up * 1000) / 10 };
	});
	// 3. clearances
	const arc = (r, b0, b1) => {
		const out = [];
		for (let b = b0; b <= b1; b += 1) out.push(polar(b, r));
		return out;
	};
	const strips = [
		...H.avenues.map((av) => ({ id: "Avenue" + av.index, s: strip(av.line, P.avenueW + 2 * T4.clear.avenue) })),
		{ id: "GardenRing", s: strip(arc(P.ringR, -80, 80), 8 + 2 * T4.clear.ring) },
		{ id: "River", s: strip(o.stream, C.riverWidth + 2 * 4) },
		...Object.entries(o.walks).map(([id, pts]) => ({ id, s: strip(pts, 10 + 2) })),
		...H.portals.map((q) => ({ id: "Approach" + q.id, s: strip([mul(q.front, P.plazaR / len(q.front)), q.front], 14 + 4) })),
		...H.portals.map((q) => ({ id: "Portal" + q.id, s: [rect(q.x - P.portal.outer / 2 - 4, q.x + P.portal.outer / 2 + 4, q.front.y - P.portal.depth - 4, q.front.y + 4)] })),
	];
	const objects = [o.garage, o.stunt, ...o.boards, o.gazebo, o.food, o.foodWest];
	const clear = [];
	for (const b of objects) {
		const hits = strips.filter((x) => x.s.some((q) => overlaps(b.poly, q))).map((x) => x.id);
		const lake = b.poly.some((p) => lakeValue(p) < 1.05);
		const plaza = b.poly.some((p) => len(p) < P.plazaR + T4.clear.plaza);
		const prom = b.poly.some((p) => len(p) > H.prom.inner - 2);
		const others = objects.filter((x) => x !== b && overlaps(b.poly, x.poly)).map((x) => x.id);
		const all = [...hits, ...(lake ? ["Lake"] : []), ...(plaza ? ["Plaza"] : []), ...(prom ? ["Promenade"] : []), ...others];
		if (all.length) failures.push({ check: "clearance", object: b.id, hits: all });
		clear.push({ object: b.id, hits: all });
	}
	// 4. mirror pairs
	const pairs = [
		[o.garage.c, o.stunt.c, "Garage/Stunt centres"],
		[o.boards[0].c, o.boards[1].c, "leaderboards"],
		[o.food.c, o.foodWest.c, "snack corners"],
	];
	const mirrorErr = pairs.map(([a, b, id]) => ({ id, error: Math.hypot(a.x + b.x - 2 * C.axisX, a.y - b.y) }));
	mirrorErr.filter((m) => m.error > 0.01).forEach((m) => failures.push({ check: "mirror", pair: m.id, error: m.error }));
	const n = o.stream.length;
	const riverMirror = Math.max(...o.stream.map((p, i) => Math.hypot(p.x + o.stream[n - 1 - i].x - 2 * C.axisX, p.y - o.stream[n - 1 - i].y)));
	if (riverMirror > 0.01) failures.push({ check: "mirror", pair: "river", error: riverMirror });
	if (Math.abs(o.gazebo.c.x - C.axisX) > 0.01) failures.push({ check: "axis", object: "Gazebo", x: o.gazebo.c.x });
	// 5. river continuity and ends in the lake
	let gap = 0;
	for (let i = 1; i < n; i++) gap = Math.max(gap, len(sub(o.stream[i], o.stream[i - 1])));
	const endsInLake = [o.stream[0], o.stream[n - 1]].map((p) => lakeValue(p) < 0.95);
	if (gap > 12) failures.push({ check: "river continuity", maxGap: gap });
	if (!endsInLake.every(Boolean)) failures.push({ check: "river ends", endsInLake });
	// 6. walking, unboosted and boosted
	const dests = [
		{ id: "Garage", door: o.garage.door },
		{ id: "StuntGate", door: o.stunt.door },
	];
	const walk1 = walkTable(H, o.extras, 1);
	const walk15 = walkTable(H, o.extras, BOOST);
	void dests;
	return { o, portal, falls, clear, mirrorErr, riverMirror, river: { points: n, maxGap: gap, endsInLake, minRadius: Math.min(...o.stream.map(len)) }, bridges: o.bridges, walk: { unboosted: walk1, boosted: walk15 }, failures, tall };
}

// ---------- Task 4 top-down plan (review page) ----------
function plan(res) {
	const { o } = res;
	const { H } = o;
	const { P } = H;
	const f1 = (x) => Math.round(x * 10) / 10;
	const pt = (p) => `${f1(p.x)},${f1(-p.y)}`;
	const poly = (pts, cls) => `<polygon class="${cls}" points="${pts.map(pt).join(" ")}"/>`;
	const line = (pts, cls) => `<polyline class="${cls}" points="${pts.map(pt).join(" ")}"/>`;
	const text = (p, t, cls = "lbl", anchor = "middle") => `<text class="${cls}" x="${f1(p.x)}" y="${f1(-p.y)}" text-anchor="${anchor}">${t}</text>`;
	const arc = (r, b0, b1) => {
		const out = [];
		for (let b = b0; b <= b1; b += 1) out.push(polar(b, r));
		return out;
	};
	const ell = (c, rx, ry) => {
		const out = [];
		for (let i = 0; i < 72; i++) out.push(V(c.x + rx * Math.cos((i / 72) * 2 * Math.PI), c.y + ry * Math.sin((i / 72) * 2 * Math.PI)));
		return out;
	};
	const s = [];
	s.push(`<svg xmlns="http://www.w3.org/2000/svg" viewBox="-300 -300 600 420" class="t4plan" role="img" aria-label="Task 4 proposed layout, top-down">`);
	s.push(poly(ell(V(0, -172), 300, 100), "lake"));
	s.push(poly([...arc(H.prom.outer, -90, 90), ...arc(H.prom.inner, -90, 90).reverse()], "path"));
	for (const t of H.corridors) s.push(poly(t, "corridor"));
	// sightlines to the waterfall (centre ray per entrance)
	for (const p of H.plots) s.push(line([p.entrance, V(-121, -271)], "ray-falls"));
	for (const av of H.avenues) for (const q of strip(av.line, P.avenueW)) s.push(poly(q, "path"));
	for (const q of strip(arc(P.ringR, -80, 80), 8)) s.push(poly(q, "path"));
	for (const q of H.portals) for (const k of strip([mul(q.front, P.plazaR / len(q.front)), q.front], 14)) s.push(poly(k, "path"));
	for (const pts of Object.values(o.walks)) for (const q of strip(pts, 10)) s.push(poly(q, "path"));
	for (const b of [o.garage, o.stunt]) for (const q of strip([b.door, mul(b.door, P.plazaR / len(b.door))], 12)) s.push(poly(q, "path"));
	s.push(`<circle class="plaza" cx="0" cy="0" r="${P.plazaR}"/>`);
	s.push(`<circle class="basin" cx="0" cy="0" r="${P.basinR}"/>`);
	for (const q of strip(o.stream, P.task4.riverWidth)) s.push(poly(q, "river"));
	for (const b of o.bridges) s.push(`<circle class="bridge" cx="${f1(b.at.x)}" cy="${f1(-b.at.y)}" r="5"/>`);
	for (const q of H.portals) s.push(poly(q.base, "portal"));
	// old anchors (Task 3) dashed
	const old = [
		{ id: "old Garage", poly: rect(-22, 22, 144, 180) },
		{ id: "old Stunt", poly: rect(-121, -91, -41, -31) },
		{ id: "old boards", poly: rect(-63, -51, -60, -56) },
		{ id: "", poly: rect(51, 63, -60, -56) },
		{ id: "old gazebo", poly: rect(-152, -136, 54, 70) },
		{ id: "old food", poly: rect(124, 156, 70, 82) },
	];
	for (const b of old) {
		s.push(poly(b.poly, "old"));
		if (b.id) s.push(text(add(b.poly[3], V(0, 3)), b.id, "lbl-old", "start"));
	}
	const objs = [
		[o.garage, "GARAGE"],
		[o.stunt, "STUNT"],
		[o.boards[0], "Most Cars"],
		[o.boards[1], "Fastest Stunt"],
		[o.gazebo, "gazebo"],
		[o.food, "snacks"],
		[o.foodWest, "snacks"],
	];
	for (const [b, t] of objs) {
		s.push(poly(b.poly, "bldg"));
		s.push(text(add(b.c, mul(b.dir, -(b.d / 2 + 6))), t));
	}
	s.push(`<line class="axis" x1="0" y1="-300" x2="0" y2="120"/>`);
	s.push(text(V(4, 290), "centre axis x = 0", "lbl-sm", "start"));
	for (const p of H.plots) s.push(text(add(p.entrance, mul(p.entrance, 10 / len(p.entrance))), "E" + p.index, "lbl"));
	s.push(text(V(-121, -262), "falls", "lbl-sm"));
	s.push(`</svg>`);
	return s.join("\n");
}

if (require.main === module) {
	const outDir = process.argv[2] || ".";
	fs.mkdirSync(outDir, { recursive: true });
	if (process.argv.includes("--search")) {
		const r = search();
		console.log(`search: ${r.candidates.length} candidates`);
		process.exit(0);
	}
	const t0 = Date.now();
	const res = check();
	const r1 = (n) => Math.round(n * 10) / 10;
	const C = res.o.H.P.task4;
	const summary = {
		chosen: { garage: res.o.garage.c, stunt: res.o.stunt.c, gantry: res.o.stunt.gantry, boards: res.o.boards.map((b) => ({ id: b.id, c: b.c })), gazebo: res.o.gazebo.c, snack: [res.o.food.c, res.o.foodWest.c], params: C },
		portal: res.portal,
		falls: res.falls,
		clearance: res.clear,
		mirror: { pairs: res.mirrorErr, river: res.riverMirror },
		river: res.river,
		bridges: res.bridges.map((b) => b.path),
		walk: Object.fromEntries(
			Object.entries(res.walk).map(([k, w]) => [k, { worst: r1(w.worst), spread: r1(w.spread), rows: Object.fromEntries(Object.entries(w.rows).map(([d, v]) => [d, { seconds: v.seconds, worst: r1(v.worst), spread: r1(v.spread) }])) }]),
		),
		failures: res.failures,
	};
	fs.writeFileSync(path.join(outDir, "task4-layout-check.json"), JSON.stringify(summary, null, 1));
	fs.writeFileSync(path.join(outDir, "task4-plan.svg"), plan(res));
	console.log(`checked in ${((Date.now() - t0) / 1000).toFixed(1)} s; failures ${res.failures.length}`);
	for (const f of res.failures) console.log("  FAIL " + JSON.stringify(f));
	console.log("falls " + JSON.stringify(summary.falls));
	console.log("river " + JSON.stringify(summary.river) + " mirror " + r1(res.riverMirror));
	console.log("bridges " + summary.bridges.join(", "));
	for (const [k, w] of Object.entries(summary.walk)) {
		console.log(`walk ${k}: worst ${w.worst} spread ${w.spread}`);
		for (const [d, v] of Object.entries(w.rows)) console.log(`   ${d.padEnd(12)} ${v.seconds.join(" / ")}`);
	}
}
