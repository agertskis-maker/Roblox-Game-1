// board position sweep (Task 4, movement review M3): k along the approach, off across it.
// Run: node board-sweep.js (a few minutes). Prints every (k, off) with zero check failures.
const T = require("./task4-layout.js");
const L = require("./island-layout.js");
const base = L.baseParams({}).task4;
const ok = [];
for (let k = 0.5; k <= 0.72 + 1e-9; k += 0.01)
	for (let off = -15.5; off >= -19 - 1e-9; off -= 0.25) {
		const t4 = JSON.parse(JSON.stringify(base));
		t4.board.k = +k.toFixed(2);
		t4.board.off = +off.toFixed(2);
		let r;
		try { r = T.check({ task4: t4 }); } catch (e) { continue; }
		if (r.failures.length === 0) ok.push({ k: t4.board.k, off: t4.board.off, worst: r.walk.boosted.worst });
	}
console.log(ok.length + " clear: " + JSON.stringify(ok));
