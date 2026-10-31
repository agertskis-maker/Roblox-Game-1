// Portal spacing / falls shift / front line sweep (Task 4): the search behind spacing 58, falls +18 and
// gate setback 2.6 (island-layout.js portal comment). Run: node gate-sweep2.js (about a minute).
// Written when T4.falls held the unshifted falls (lower x -131 to -111); T4.falls now includes the
// 18-stud shift, so a re-run today adds `shift` on top of 18 (read the shift column as 18 + shift).
const T = require("./task4-layout.js");
const L = require("./island-layout.js");
const base = L.baseParams({});
const fb = JSON.parse(JSON.stringify(T.T4.falls));
const rows = [];
for (const spacing of [50, 54, 58, 62])
	for (const shift of [15, 18, 21, 24, 27, 30])
		for (const frontY of [-58, -56, -54]) {
			for (const k of ["lower", "upper"]) { T.T4.falls[k].x0 = fb[k].x0 + shift; T.T4.falls[k].x1 = fb[k].x1 + shift; }
			let r;
			try { r = T.check({ portal: Object.assign({}, base.portal, { spacing, frontY }), task4: Object.assign({}, base.task4, { gateSetback: 2.6 }) }); } catch (e) { continue; }
			const field = r.failures.filter((f) => f.check === "portal field").reduce((s, f) => s + f.blockedPct, 0);
			// falls excluding the leaderboard and the stunt loop (both movable)
			let fallsGates = 0;
			for (const f of r.failures.filter((f) => f.check === "waterfall")) if (f.objects.some((o) => /Column|Crest|Crown/.test(o))) fallsGates += f.lowerPct + f.upperPct;
			const other = r.failures.filter((f) => f.check !== "portal field" && f.check !== "waterfall").length;
			rows.push({ spacing, shift, frontY, field: +field.toFixed(1), fallsGates: +fallsGates.toFixed(1), other, per: r.falls.map((f) => f.lowerBlockedPct + "/" + f.upperBlockedPct).join(" "), objs: [...new Set(r.failures.filter((f) => f.check === "waterfall").flatMap((f) => f.objects))].join(","), worst: +r.walk.boosted.worst.toFixed(1) });
		}
rows.sort((a, b) => a.other - b.other || a.field - b.field || a.fallsGates - b.fallsGates);
for (const x of rows.slice(0, 12)) console.log(JSON.stringify(x));
