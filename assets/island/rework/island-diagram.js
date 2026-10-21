// Draws the island rework review diagrams from island-layout.js (inline SVG with CSS classes,
// styled by the review page). Run: node island-diagram.js <outDir>
"use strict";
const fs = require("fs");
const path = require("path");
const L = require("./island-layout.js");
const { V, len, sub, add, mul, polar, rect } = L;

const f1 = (n) => (Math.round(n * 10) / 10).toString();
const esc = (s) => String(s).replace(/&/g, "&amp;").replace(/</g, "&lt;");
const pt = (p) => `${f1(p.x)},${f1(-p.y)}`;
const poly = (pts, cls, extra = "") => `<polygon class="${cls}" points="${pts.map(pt).join(" ")}" ${extra}/>`;
const line = (pts, cls, extra = "") => `<polyline class="${cls}" points="${pts.map(pt).join(" ")}" ${extra}/>`;
const text = (p, s, cls = "lbl", extra = "") => `<text class="${cls}" x="${f1(p.x)}" y="${f1(-p.y)}" ${extra}>${esc(s)}</text>`;
const circ = (c, r, cls) => `<circle class="${cls}" cx="${f1(c.x)}" cy="${f1(-c.y)}" r="${f1(r)}"/>`;
const arcPts = (r, b0, b1, step = 1) => {
	const out = [];
	for (let b = b0; b <= b1 + 1e-9; b += step) out.push(polar(b, r));
	return out;
};
function ellipse(c, rx, ry, n = 72) {
	const out = [];
	for (let i = 0; i < n; i++) out.push(V(c.x + rx * Math.cos((2 * Math.PI * i) / n), c.y + ry * Math.sin((2 * Math.PI * i) / n)));
	return out;
}

// Placeholder backdrop: lake, waterfall, mountain peaks, foothill band (greybox masses later)
function backdrop(o) {
	const H = o.H;
	const rMax = H.rMax;
	const lake = { c: V(0, -172), rx: 300, ry: 100 };
	const peaks = [
		{ c: V(-640, -250), r: 150, h: 140 },
		{ c: V(-430, -360), r: 170, h: 190 },
		{ c: V(-215, -410), r: 190, h: 260 },
		{ c: V(10, -440), r: 210, h: 300 },
		{ c: V(235, -400), r: 190, h: 250 },
		{ c: V(445, -355), r: 170, h: 200 },
		{ c: V(650, -250), r: 150, h: 140 },
	];
	const waterfall = { top: V(-120, -268), base: V(-120, -258), width: 20, height: 120 };
	const foot = { inner: rMax + 8, outer: rMax + 110, h: [30, 90] };
	return { lake, peaks, waterfall, foot };
}

function overview(o, opts = {}) {
	const H = o.H;
	const P = H.P;
	const g = H.g;
	const B = backdrop(o);
	const s = [];
	const ext = H.rMax + 130;
	const vb = opts.viewBox || [-ext - 20, -(ext + 20), 2 * ext + 40, ext + 20 + 680];
	const zoom = !!opts.viewBox && !opts.fullScale;
	s.push(`<svg xmlns="http://www.w3.org/2000/svg" viewBox="${vb.join(" ")}" class="plan${zoom ? " zoom" : ""}" role="img" aria-label="${esc(opts.aria || "Island layout, top-down")}">`);
	// backdrop
	s.push(`<g data-layer="backdrop">`);
	s.push(poly([...arcPts(B.foot.outer, -90, 90, 2), ...arcPts(B.foot.inner, -90, 90, 2).reverse()], "foothill"));
	for (const side of [-1, 1]) s.push(poly([V(side * B.foot.inner, 0), V(side * B.foot.outer, 0), V(side * (B.foot.outer - 40), -260), V(side * (B.foot.inner - 140), -230), V(side * (H.prom.outer + 40), -110)], "foothill"));
	for (const k of B.peaks) s.push(poly(ellipse(k.c, k.r, k.r * 0.62, 40), "mtn"));
	for (const k of B.peaks) s.push(text(add(k.c, V(0, -6)), `peak ${k.h}`, "lbl-sm mtn-lbl", 'text-anchor="middle"'));
	s.push(poly(ellipse(B.lake.c, B.lake.rx, B.lake.ry), "lake"));
	s.push(text(V(150, -190), "LAKE", "lbl lake-lbl", 'text-anchor="middle"'));
	s.push(poly(rect(B.waterfall.top.x - 10, B.waterfall.top.x + 10, B.waterfall.top.y - 16, B.waterfall.top.y), "waterfall"));
	s.push(text(V(B.waterfall.top.x, B.waterfall.top.y - 30), "waterfall, 120 tall", "lbl-sm", 'text-anchor="middle"'));
	s.push(text(V(0, -560), "MOUNTAINS (placeholder masses, peaks 140 to 300 tall)", "lbl", 'text-anchor="middle"'));
	s.push(text(polar(-38, B.foot.inner + 55), "FOOTHILLS AND FOREST", "lbl foot-lbl", `text-anchor="middle" transform="rotate(-38 ${pt(polar(-38, B.foot.inner + 55)).replace(",", " ")})"`));
	s.push(`</g>`);
	// sector rays
	s.push(`<g data-layer="sectors">`);
	for (let i = 0; i <= P.plots; i++) {
		const b = -90 + (180 / P.plots) * i;
		s.push(line([polar(b, 0), polar(b, H.rMax + 10)], "ray"));
	}
	s.push(`</g>`);
	// park
	s.push(`<g data-layer="park">`);
	s.push(poly([...arcPts(H.prom.outer, -90, 90), ...arcPts(H.prom.inner, -90, 90).reverse()], "promenade"));
	for (const a of H.avenues) for (const q of L.strip(a.line, P.avenueW)) s.push(poly(q, "path"));
	for (const q of L.strip(arcPts(P.ringR, -80, 80), 8)) s.push(poly(q, "path ring"));
	for (const pq of H.portals) for (const q of L.strip([mul(pq.front, P.plazaR / len(pq.front)), pq.front], 14)) s.push(poly(q, "path"));
	for (const b of [o.garage, o.stunt]) for (const q of L.strip([b.door, mul(b.door, P.plazaR / len(b.door))], 12)) s.push(poly(q, "path"));
	for (const q of L.strip([V(-P.portal.spacing - 12, P.portal.frontY + 3), V(P.portal.spacing + 12, P.portal.frontY + 3)], 10)) s.push(poly(q, "path"));
	for (const side of [-1, 1]) for (const q of L.strip([V(side * P.portal.spacing, P.portal.frontY + 3), polar(side * 90, H.prom.centre)], 10)) s.push(poly(q, "path"));
	s.push(circ(V(0, 0), P.plazaR, "plaza"));
	s.push(circ(V(0, 0), P.basinR, "basin"));
	for (const q of L.strip(o.stream, 10)) s.push(poly(q, "stream"));
	for (const b of o.bridges) s.push(circ(b.at, 6, "bridge"));
	s.push(`</g>`);
	// corridors
	s.push(`<g data-layer="corridors">`);
	H.corridors.forEach((t) => s.push(poly(t, "corridor")));
	s.push(`</g>`);
	// buildings and portals
	s.push(`<g data-layer="park-buildings">`);
	for (const pq of H.portals) s.push(poly(pq.base, "portal"));
	for (const b of [o.garage, o.stunt, o.gazebo, o.food]) s.push(poly(b.poly, "bldg"));
	for (const b of o.boards) s.push(poly(b.poly, "bldg"));
	s.push(text(add(o.garage.c, V(0, -3)), "GARAGE", "lbl bldg-lbl on-dark", 'text-anchor="middle"'));
	s.push(text(add(o.stunt.c, V(0, -18)), "STUNT CIRCUIT GATE", "lbl-sm bldg-lbl", 'text-anchor="middle"'));
	s.push(text(add(o.gazebo.c, V(0, -16)), "gazebo", "lbl-sm", 'text-anchor="middle"'));
	s.push(text(add(o.food.c, V(0, -16)), "food stands (decor)", "lbl-sm", 'text-anchor="middle"'));
	for (const b of o.boards) s.push(text(add(L.V(b.poly[0].x + 6, b.poly[0].y), V(0, -12)), "board", "lbl-sm", 'text-anchor="middle"'));
	const names = { SummitPass: "SUMMIT PASS", Downtown: "DOWNTOWN", DustyHighway: "DUSTY HWY" };
	if (zoom) for (const pq of H.portals) s.push(text(V(pq.x, P.portal.frontY - 14 - (pq.x === 0 ? 0 : 9)), names[pq.id], "lbl-sm portal-lbl", `text-anchor="middle"`));
	else s.push(text(V(0, P.portal.frontY - 26), "PORTAL ROW", "lbl-sm portal-lbl", 'text-anchor="middle"'));
	s.push(text(V(0, 3), "fountain", "lbl-sm", 'text-anchor="middle"'));
	s.push(`</g>`);
	// plots
	s.push(`<g data-layer="reservations">`);
	for (const p of H.plots) {
		for (const r of p.res) {
			let cls = r.layer === "base" ? "res-base" : "res-future";
			if (r.id === "Track") cls = "track";
			if (r.id === "ElevatedEnvelope") cls = "elev";
			if (r.id === "Grandstand") cls = "grand";
			if (r.id === "BleachersL") continue; // same footprint as the grandstand that replaces it
			s.push(poly(r.plan, cls));
			if (r.ring) s.push(poly(r.ring.map((q) => L.toPlan(p.bearing, q)), "infield"));
		}
		s.push(text(polar(p.bearing, g.uS + H.T.L / 2 + 4), `Plot0${p.index}`, "lbl plot-lbl", 'text-anchor="middle"'));
	}
	s.push(`</g>`);
	// orientation arrows: every entrance faces the fountain
	s.push(`<g data-layer="orientation">`);
	for (const p of H.plots) {
		const a = polar(p.bearing, g.r0 + 30);
		const b = polar(p.bearing, g.r0 - 28);
		s.push(line([a, b], "arrow", 'marker-end="url(#arrowhead)"'));
	}
	const mid = H.plots[Math.floor(P.plots / 2) - 1];
	s.push(text(polar(mid.bearing + 3.2, g.r0 + 150), "park → front → track → expansion", "lbl-sm orient-lbl", `transform="rotate(${f1(mid.bearing - 90)} ${pt(polar(mid.bearing + 3.2, g.r0 + 150)).replace(",", " ")})"`));
	s.push(`</g>`);
	// routes
	s.push(`<g data-layer="routes">`);
	const show = opts.routes || [
		[1, "Downtown"],
		[Math.ceil(P.plots / 2), "Downtown"],
		[1, "Garage"],
	];
	for (const [k, d] of show) {
		const r = o.net.routes[k];
		if (!r || !r.lines[d]) continue;
		s.push(line(r.lines[d], "route"));
		const last = r.lines[d][Math.floor(r.lines[d].length * 0.55)];
		if (!zoom) s.push(text(add(last, V(6, 6)), `Plot0${k}→${d} ${f1(r.dist[d] / L.WALK)} s`, "lbl-sm route-lbl"));
	}
	s.push(`</g>`);
	// dimensions along the middle-right plot
	s.push(`<g data-layer="dims">`);
	const dp = H.plots[Math.ceil(P.plots / 2)];
	const off = 7;
	const ticks = [
		[g.r0, `entrance r ${f1(g.r0)}`],
		[g.r0 + P.frontDepth, `front zone ${P.frontDepth} deep`],
		[g.uS, `straights start ${f1(g.uS)}`],
		[g.uS + H.T.L, `straights end ${f1(g.uS + H.T.L)}`],
		[H.rMax, `plot outer r ${f1(H.rMax)}`],
	];
	for (const [r, label] of ticks) {
		const c = polar(dp.bearing + off, r);
		s.push(circ(c, 2.5, "dimdot"));
		s.push(text(add(c, V(6, -3)), label, "lbl-sm dim-lbl"));
	}
	s.push(line([polar(dp.bearing + off, g.r0), polar(dp.bearing + off, H.rMax)], "dim"));
	s.push(text(V(-ext + 10, -ext + 640), `${P.plots} plots, ${180 / P.plots}° sectors, ${P.buffer}-stud buffer between plot envelopes`, "lbl"));
	s.push(text(V(-ext + 10, -ext + 625), `oval path ${f1(2 * H.T.L + 2 * Math.PI * P.R)}, straights ${f1(H.T.L)}, turns R ${P.R}, track 16 wide; side bands 50`, "lbl"));
	// scale bar and north
	const sb = V(ext - 230, -ext + 630);
	s.push(line([sb, add(sb, V(200, 0))], "scale"));
	for (let i = 0; i <= 4; i++) s.push(line([add(sb, V(50 * i, -4)), add(sb, V(50 * i, 4))], "scale"));
	s.push(text(add(sb, V(100, 10)), "200 studs", "lbl-sm", 'text-anchor="middle"'));
	s.push(line([V(ext - 20, ext - 60), V(ext - 20, ext - 20)], "arrow", 'marker-end="url(#arrowhead)"'));
	s.push(text(V(ext - 20, ext - 75), "N", "lbl", 'text-anchor="middle"'));
	s.push(`</g>`);
	s.push(`<defs><marker id="arrowhead" viewBox="0 0 10 10" refX="8" refY="5" markerWidth="5" markerHeight="5" orient="auto-start-reverse"><path d="M0,0 L10,5 L0,10 z" class="arrowfill"/></marker></defs>`);
	s.push(`</svg>`);
	return s.join("\n");
}

// One plot in its own frame (u up, v right), every reservation labelled
function plotDetail(o) {
	const H = o.H;
	const T = H.T;
	const g = H.g;
	const P = H.P;
	const half = P.buffer / 2;
	const a = T.alpha;
	const s = [];
	const top = H.rMax + 8;
	const wTop = top * Math.tan(a) + 20;
	const toS = (p) => V(p.x, p.y - 0); // plot frame drawn directly: x = v, y = u
	s.push(`<svg xmlns="http://www.w3.org/2000/svg" viewBox="${f1(-wTop - 140)} ${f1(-top - 6)} ${f1(2 * wTop + 280)} ${f1(top - g.r0 + 40)}" class="plan detail" role="img" aria-label="One plot, every reserved area, dimensions in studs">`);
	// sector rays and buffer lines
	for (const sgn of [-1, 1]) {
		s.push(line([V(0, 0), V(sgn * top * Math.tan(a), top)].map(toS), "ray"));
		const off = half / Math.cos(a);
		s.push(line([V(sgn * (g.r0 * Math.tan(a) - off), g.r0), V(sgn * (top * Math.tan(a) - off), top)].map(toS), "buffer"));
	}
	s.push(line([V(-g.r0 * Math.tan(a), g.r0), V(g.r0 * Math.tan(a), g.r0)], "entrance-line"));
	for (const r of T.res) {
		let cls = r.layer === "base" ? "res-base" : "res-future";
		if (r.id === "Track") cls = "track";
		if (r.id === "ElevatedEnvelope") continue;
		if (r.id === "Grandstand") cls = "grand";
		if (r.id === "BleachersL") continue;
		s.push(poly(r.poly.map(toS), cls));
		if (r.ring) s.push(poly(r.ring.map(toS), "infield"));
	}
	// elevated envelope outline on top
	s.push(poly(T.res.find((r) => r.id === "ElevatedEnvelope").poly, "elev"));
	const lab = {
		EntranceCourt: "entrance court + gate + nameplate",
		Kiosk: "k",
		Paddock: "PADDOCK 72 × 42, 15 bays",
		FrontBuildingsL: "pit garages",
		FrontBuildingsR: "pit garages",
		FrontBuildingsRear: "front",
		FrontBuildingsRear2: "front",
		PitExit: "pit exit",
		PitEntry: "pit entry",
		PitBuilding: "pit building (t4)",
		ScreenPad: "big screen (t4)",
		Gantry: "S/F gantry (t3)",
		BleachersR: "bleachers (t2)",
		Grandstand: "bleachers t2 → covered grandstand t3 / roof t5",
		Statue: "statue (t5)",
		LoopEnvelope: "loop envelope 38 × 34",
		FireworksL: "fw",
		FireworksR: "fw",
		SignBand: "outer sign and banner band (flag line starts here)",
	};
	const rot = { Grandstand: -90, BleachersR: 90, PitExit: 90, PitEntry: -90, FrontBuildingsL: -90, FrontBuildingsR: 90, PitBuilding: 90, ScreenPad: 0 };
	for (const r of T.res) {
		if (!lab[r.id]) continue;
		const c = L.add(centroid(r.poly), V(0, 0));
		const rr = rot[r.id];
		s.push(text(c, lab[r.id], "lbl-sm", `text-anchor="middle" dominant-baseline="middle"${rr ? ` transform="rotate(${rr} ${f1(c.x)} ${f1(-c.y)})"` : ""}`));
	}
	for (const id of ["FloodNR", "FloodFR", "FloodNL", "FloodFL"]) {
		const r = T.res.find((q) => q.id === id);
		s.push(text(add(centroid(r.poly), V(id.endsWith("R") ? 10 : -10, 0)), "flood", "lbl-sm", `text-anchor="${id.endsWith("R") ? "start" : "end"}" dominant-baseline="middle"`));
	}
	// dimension column on the right
	const dx = wTop + 30;
	const ds = [
		[g.r0, "entrance (r " + f1(g.r0) + ")"],
		[g.r0 + P.frontDepth, "front zone ends " + f1(g.r0 + P.frontDepth) + "; oval tip " + f1(g.uTip)],
		[g.uS, "straights start " + f1(g.uS)],
		[g.uS + T.L, "straights end " + f1(g.uS + T.L)],
		[g.uFar, "oval far tip " + f1(g.uFar)],
		[H.rMax, "plot outer " + f1(H.rMax)],
	];
	s.push(line([V(dx, g.r0), V(dx, H.rMax)], "dim"));
	for (const [u, l] of ds) {
		s.push(line([V(dx - 4, u), V(dx + 4, u)], "dim"));
		s.push(text(V(dx + 8, u), l, "lbl-sm dim-lbl", 'dominant-baseline="middle"'));
	}
	// width labels
	const bandU = g.uS + T.L * 0.62;
	s.push(line([V(g.rOut, bandU), V(g.rOut + P.band, bandU)], "dim"));
	s.push(text(V(g.rOut + P.band + 4, bandU), "band 50", "lbl-sm dim-lbl", 'dominant-baseline="middle"'));
	s.push(line([V(-g.rOut, g.uS + T.L + 12), V(g.rOut, g.uS + T.L + 12)], "dim"));
	s.push(text(V(0, g.uS + T.L + 16), `oval ${f1(2 * g.rOut)} wide`, "lbl-sm dim-lbl", 'text-anchor="middle"'));
	s.push(text(V(-wTop - 130, g.r0 + 20), "↓ park and fountain", "lbl-sm"));
	s.push(text(V(-wTop - 130, H.rMax - 10), `${P.buffer / 2} from each`, "lbl-sm"));
	s.push(text(V(-wTop - 130, H.rMax - 22), "sector ray (buffer)", "lbl-sm"));
	s.push(`</svg>`);
	return s.join("\n");
}
function centroid(p) {
	let x = 0;
	let y = 0;
	for (const q of p) {
		x += q.x;
		y += q.y;
	}
	return V(x / p.length, y / p.length);
}

// Eye-level panorama: azimuth across, elevation up; computed silhouettes, painter's order
function panorama(o, plotIndex, title) {
	const H = o.H;
	const P = H.P;
	const B = backdrop(o);
	const plot = H.plots[plotIndex - 1];
	const eye = plot.entrance;
	const fwd = mul(sub(V(0, 0), eye), 1 / len(eye));
	const eyeZ = P.eye;
	const W = 1200;
	const Hpx = 330;
	const FOV = 120;
	const EL0 = -6;
	const EL1 = 26;
	const sx = (az) => ((az + FOV / 2) / FOV) * W;
	const sy = (el) => Hpx - ((el - EL0) / (EL1 - EL0)) * Hpx;
	const proj = (p, z) => {
		const d = sub(p, eye);
		const az = (Math.atan2(cross(fwd, d), dot(fwd, d)) * 180) / Math.PI;
		const el = (Math.atan2(z - eyeZ, len(d)) * 180) / Math.PI;
		return { az: -az, el, dist: len(d) };
	};
	function cross(a, b) {
		return a.x * b.y - a.y * b.x;
	}
	function dot(a, b) {
		return a.x * b.x + a.y * b.y;
	}
	const items = [];
	const prism = (id, footprint, z0, z1, cls) => {
		const pts = [];
		for (const p of footprint) {
			pts.push(proj(p, z0));
			pts.push(proj(p, z1));
		}
		if (pts.some((q) => Math.abs(q.az) > 90)) return; // behind the viewer
		const dist = Math.min(...footprint.map((p) => len(sub(p, eye))));
		items.push({ id, pts: hull(pts.map((q) => V(sx(q.az), sy(q.el)))), dist, cls });
	};
	const cone = (id, c, r, h, cls) => {
		const pts = [];
		for (let i = 0; i < 24; i++) pts.push(proj(add(c, V(r * Math.cos((i * Math.PI) / 12), r * Math.sin((i * Math.PI) / 12))), 0));
		pts.push(proj(c, h));
		if (pts.some((q) => Math.abs(q.az) > 90)) return;
		items.push({ id, pts: hull(pts.map((q) => V(sx(q.az), sy(q.el)))), dist: len(sub(c, eye)) - r, cls });
	};
	for (const k of B.peaks) cone("mountain", k.c, k.r, k.h, "pano-mtn");
	prism("waterfall", rect(B.waterfall.top.x - 10, B.waterfall.top.x + 10, B.waterfall.top.y - 4, B.waterfall.top.y), 0, B.waterfall.height, "pano-water");
	// foothills: a band of low cones round the arc
	for (let b = -88; b <= 88; b += 8) cone("foothill", polar(b, B.foot.inner + 50), 60, 30 + 60 * Math.abs(Math.sin((b * Math.PI) / 50)), "pano-foot");
	for (const pq of H.portals) {
		const x0 = pq.x - P.portal.outer / 2;
		const x1 = pq.x + P.portal.outer / 2;
		const y0 = P.portal.frontY - P.portal.depth;
		const y1 = P.portal.frontY;
		const pil = (P.portal.outer - P.portal.opening) / 2;
		prism("portal", rect(x0, x0 + pil, y0, y1), 0, P.portal.height, "pano-portal");
		prism("portal", rect(x1 - pil, x1, y0, y1), 0, P.portal.height, "pano-portal");
		prism("portal", rect(x0, x1, y0, y1), P.portal.height - 6, P.portal.height, "pano-portal");
		prism("portalfield", rect(x0 + pil, x1 - pil, y0 + 2, y1 - 2), 2, P.portal.height - 6, "pano-field");
	}
	prism("garage", o.garage.poly, 0, 22, "pano-bldg");
	prism("stunt", o.stunt.poly, 0, 16, "pano-bldg");
	prism("gazebo", o.gazebo.poly, 0, 12, "pano-bldg2");
	prism("food", o.food.poly, 0, 8, "pano-bldg2");
	for (const b of o.boards) prism("board", b.poly, 0, b.h, "pano-bldg2");
	prism("fountain", L.strip([V(-12, 0), V(12, 0)], 24)[0], 0, 3, "pano-fountain");
	// other plots' tallest future envelopes (grandstand 40, floodlights 60) for reading neighbours' progress
	for (const p of H.plots) {
		if (p.index === plotIndex) continue;
		for (const r of p.res) {
			if (r.id === "Grandstand") prism("grandstand", r.plan, 0, 40, "pano-future");
			if (r.id.startsWith("Flood")) prism("flood", r.plan, 0, 60, "pano-future");
			if (r.id === "PitBuilding") prism("pit", r.plan, 0, 18, "pano-future");
		}
	}
	items.sort((a, b) => b.dist - a.dist);
	const s = [];
	s.push(`<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${W} ${Hpx + 34}" class="pano" role="img" aria-label="${esc(title)}">`);
	s.push(`<rect class="pano-sky" x="0" y="0" width="${W}" height="${f1(sy(0))}"/>`);
	s.push(`<rect class="pano-ground" x="0" y="${f1(sy(0))}" width="${W}" height="${f1(Hpx - sy(0))}"/>`);
	// lake band
	const lakeNear = proj(V(0, B.lake.c.y + B.lake.ry), 0);
	const lakeFar = proj(V(0, B.lake.c.y - B.lake.ry), 0);
	s.push(`<rect class="pano-lake" x="${f1(sx(-35))}" y="${f1(sy(lakeFar.el))}" width="${f1(sx(35) - sx(-35))}" height="${f1(Math.max(1, sy(lakeNear.el) - sy(lakeFar.el)))}"/>`);
	for (const it of items) s.push(`<polygon class="${it.cls}" points="${it.pts.map((q) => `${f1(q.x)},${f1(q.y)}`).join(" ")}"/>`);
	s.push(`<line class="pano-horizon" x1="0" x2="${W}" y1="${f1(sy(0))}" y2="${f1(sy(0))}"/>`);
	for (let az = -60; az <= 60; az += 20) s.push(`<text class="lbl-sm pano-tick" x="${f1(sx(az))}" y="${Hpx + 14}" text-anchor="middle">${az}°</text>`);
	s.push(`<text class="lbl-sm pano-tick" x="6" y="${Hpx + 28}">eye height ${P.eye} at the Plot0${plotIndex} entrance, facing the fountain; 120° wide, −6° to +26° tall; computed outlines, not a Studio capture</text>`);
	// labels
	const tag = (p, z, s2) => {
		const q = proj(p, z);
		if (Math.abs(q.az) < 58) s.push(`<text class="lbl-sm pano-lbl" x="${f1(sx(q.az))}" y="${f1(sy(q.el) - 6)}" text-anchor="middle">${esc(s2)}</text>`);
	};
	tag(V(0, P.portal.frontY), P.portal.height + 2, "Downtown");
	tag(V(-P.portal.spacing, P.portal.frontY), P.portal.height + 9, "Summit");
	tag(V(P.portal.spacing, P.portal.frontY), P.portal.height + 9, "Dusty");
	tag(o.garage.c, 24, "Garage");
	tag(o.stunt.c, 18, "Stunt gate");
	tag(V(B.waterfall.top.x, B.waterfall.top.y), B.waterfall.height + 4, "waterfall");
	s.push(`</svg>`);
	// visible portal fraction: field outline vs anything nearer drawn over it is not computed; report angles instead
	const angles = H.portals.map((pq) => {
		const q = proj(V(pq.x, P.portal.frontY), P.portal.height);
		const d = len(sub(V(pq.x, P.portal.frontY), eye));
		return { id: pq.id, distance: Math.round(d), heightDeg: Math.round(((Math.atan2(P.portal.height - P.eye, d) - Math.atan2(-P.eye, d)) * 1800) / Math.PI) / 10, azimuth: Math.round(q.az * 10) / 10 };
	});
	return { svg: s.join("\n"), angles };
}
function hull(points) {
	const p = points.slice().sort((a, b) => a.x - b.x || a.y - b.y);
	const c = (o, a, b) => (a.x - o.x) * (b.y - o.y) - (a.y - o.y) * (b.x - o.x);
	const lo = [];
	for (const q of p) {
		while (lo.length >= 2 && c(lo[lo.length - 2], lo[lo.length - 1], q) <= 0) lo.pop();
		lo.push(q);
	}
	const up = [];
	for (const q of p.reverse()) {
		while (up.length >= 2 && c(up[up.length - 2], up[up.length - 1], q) <= 0) up.pop();
		up.push(q);
	}
	return lo.slice(0, -1).concat(up.slice(0, -1));
}

module.exports = { overview, plotDetail, panorama, backdrop };

if (require.main === module) {
	const out = process.argv[2] || ".";
	fs.mkdirSync(out, { recursive: true });
	const six = L.run({}, "six");
	const five = L.run({ plots: 5 }, "five");
	const ext6 = six.H.rMax + 130;
	const sameScale = [-ext6 - 20, -(ext6 + 20), 2 * ext6 + 40, ext6 + 20 + 680];
	fs.writeFileSync(path.join(out, "overview6.svg"), overview(six, { aria: "Six-plot island layout, top-down, dimensions in studs" }));
	fs.writeFileSync(path.join(out, "overview5.svg"), overview(five, { aria: "Five-plot alternative, same scale", viewBox: sameScale, fullScale: true, routes: [[1, "Downtown"], [3, "Downtown"]] }));
	fs.writeFileSync(path.join(out, "plot6.svg"), plotDetail(six));
	fs.writeFileSync(path.join(out, "hub6.svg"), overview(six, { aria: "Hub close-up: fountain plaza, portal row, approaches", viewBox: [-190, -190, 380, 300], routes: [[1, "Downtown"], [3, "Downtown"], [1, "SummitPass"], [6, "SummitPass"]] }));
	const mid = panorama(six, 3, "Eye-level view from the Plot03 (middle) entrance toward the portals");
	const end = panorama(six, 1, "Eye-level view from the Plot01 (end) entrance toward the portals");
	fs.writeFileSync(path.join(out, "sight-mid.svg"), mid.svg);
	fs.writeFileSync(path.join(out, "sight-end.svg"), end.svg);
	fs.writeFileSync(path.join(out, "sight.json"), JSON.stringify({ mid: mid.angles, end: end.angles }, null, 1));
	console.log(JSON.stringify({ mid: mid.angles, end: end.angles }));
}
