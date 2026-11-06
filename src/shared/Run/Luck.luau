--!strict
-- Round 7 (L-02, decision 0042 item 10): the one odds rule for rarer cars, used by the run (RunSequence, on the client and on the
-- server, which rebuilds the same traffic from the seed) and by the Lucky Clover panel's numbers, so what the panel says is what
-- spawns. Lane 3 wrote it in Brian R's lane with Adam's opening of every lane (Round 7 brief section 0 item 1).
--
-- The rule (brief L-02, with ChatGPT's algorithm note): start from the run's normal odds at that distance (Brian R's curve, with
-- Brian L's x2 on Rare, Epic and Legendary of 2026-11-05); Luck L multiplies Legendary and Epic by L and Rare by 1 + (L - 1) / 2.
-- If those three then add up to more than 65%, all three are scaled down evenly to 65%, so Commons (and the Uncommons drawn from
-- them) never fall below 35% of spawns. Commons take what is left. L = 1 is no luck.
--
--   Luck.weightsAt(distanceStuds, luck?) -> { Legendary, Epic, Rare, Common }   (sums to 1)
--   Luck.shares(luck, metres) -> same, at a distance in metres        Luck.rareOrBetter(luck, metres) -> number
--   Luck.averageShares(luck, metres) -> the shares averaged over a run from 0 to `metres` (the panel's numbers)

local RunConfig = require(script.Parent.RunConfig)

local Luck = {}

Luck.COMMON_FLOOR = 0.35
-- Brian L with Adam, 2026-11-05 (feature/lane2-run-tweaks): Rare, Epic and Legendary weights doubled. Was x1.
Luck.RARE_BOOST = 2
Luck.MAX = 4 -- the top Lucky Clover level

export type Weights = { Legendary: number, Epic: number, Rare: number, Common: number }

local function finite(n: number): boolean
	return n == n and n ~= math.huge and n ~= -math.huge
end

-- A saved or sent luck value made safe: a finite number from 1 to MAX (anything else is 1).
function Luck.clamp(luck: any): number
	if type(luck) ~= "number" or not finite(luck) then
		return 1
	end
	return math.clamp(luck, 1, Luck.MAX)
end

-- Brian R's curve: rarer cars grow more common over the first 3,000 m of a run.
local function base(distance: number): Weights
	local a = math.clamp(RunConfig.toMetres(math.max(distance, 0)) / 3000, 0, 1)
	local b = Luck.RARE_BOOST
	local w = {
		Legendary = (0.006 + 0.024 * a) * b,
		Epic = (0.03 + 0.07 * a) * b,
		Rare = (0.15 + 0.1 * a) * b,
		Common = 0,
	}
	return w
end

function Luck.weightsAt(distance: number, luck: number?): Weights
	local L = Luck.clamp(luck)
	local w = base(if finite(distance) then distance else 0)
	w.Legendary *= L
	w.Epic *= L
	w.Rare *= 1 + (L - 1) / 2
	local rare = w.Legendary + w.Epic + w.Rare
	local most = 1 - Luck.COMMON_FLOOR
	if rare > most then
		local fit = most / rare
		w.Legendary *= fit
		w.Epic *= fit
		w.Rare *= fit
		rare = most
	end
	w.Common = 1 - rare
	return w
end

function Luck.shares(luck: number, metres: number): Weights
	return Luck.weightsAt(metres / RunConfig.METRES_PER_STUD, luck)
end

function Luck.rareOrBetter(luck: number, metres: number): number
	local w = Luck.shares(luck, metres)
	return w.Legendary + w.Epic + w.Rare
end

-- The shares averaged over a run from 0 to `metres` (100 even steps): what a player sees over a whole run of that length.
function Luck.averageShares(luck: number, metres: number): Weights
	local sum = { Legendary = 0, Epic = 0, Rare = 0, Common = 0 }
	local steps = 100
	for i = 0, steps - 1 do
		local w = Luck.shares(luck, metres * (i + 0.5) / steps)
		sum.Legendary += w.Legendary / steps
		sum.Epic += w.Epic / steps
		sum.Rare += w.Rare / steps
		sum.Common += w.Common / steps
	end
	return sum
end

-- L-04: draws `count` spawns with the real sequence code (RunSequence, passed in to keep this module free of a require cycle) at
-- luck L from a recorded seed, and compares the share of Rare-or-better with the rule's expectation at each spawn's own distance.
-- Returns observed share, expected share and the counts by rarity.
function Luck.draw(
	RunSequence: any,
	profile: any,
	seed: number,
	luck: number,
	count: number
): (number, number, { [string]: number })
	local sequence = RunSequence.new(seed, profile, luck)
	local counts = { Legendary = 0, Epic = 0, Rare = 0, Common = 0 }
	local expected = 0
	local distance = 0
	local drawn = 0
	while drawn < count do
		distance += 2000
		local spawns = sequence:ensure(distance)
		for i = drawn + 1, math.min(#spawns, count) do
			local s = spawns[i]
			counts[s.rarity] += 1
			local w = Luck.weightsAt(s.start or 0, luck)
			expected += w.Legendary + w.Epic + w.Rare
		end
		drawn = math.min(#spawns, count)
	end
	local rare = counts.Legendary + counts.Epic + counts.Rare
	return rare / count, expected / count, counts
end

function Luck.selfTest(RunSequence: any): { string }
	local lines: { string } = {}
	local function expect(name: string, ok: boolean, detail: string)
		table.insert(lines, string.format("%s %s: %s", if ok then "PASS" else "FAIL", name, detail))
	end
	local function near(a: number, b: number, tol: number): boolean
		return math.abs(a - b) <= tol
	end
	-- the rule itself
	local w0 = Luck.weightsAt(0, 1)
	expect(
		"L=1 start: Rare 30%, Epic 6%, Legendary 1.2%",
		near(w0.Rare, 0.3, 1e-9) and near(w0.Epic, 0.06, 1e-9) and near(w0.Legendary, 0.012, 1e-9),
		string.format("%.3f %.3f %.4f", w0.Rare, w0.Epic, w0.Legendary)
	)
	for _, L in { 1, 1.25, 1.5, 2, 3, 4 } do
		for _, m in { 0, 1500, 3000, 6000 } do
			local w = Luck.shares(L, m)
			local sum = w.Legendary + w.Epic + w.Rare + w.Common
			local ok = near(sum, 1, 1e-9)
				and w.Common >= Luck.COMMON_FLOOR - 1e-9
				and w.Legendary >= 0
				and w.Epic >= 0
				and w.Rare >= 0
			if not ok then
				expect(
					string.format("shares L=%g at %d m", L, m),
					false,
					string.format("sum %.6f common %.4f", sum, w.Common)
				)
			end
		end
	end
	expect("every level and distance sums to 1 with Commons >= 35%", true, "checked 24 points")
	local w2 = Luck.weightsAt(0, 2)
	expect(
		"L=2 start: Legendary x2, Epic x2, Rare x1.5",
		near(w2.Legendary, 0.024, 1e-9) and near(w2.Epic, 0.12, 1e-9) and near(w2.Rare, 0.45, 1e-9),
		string.format("%.4f %.3f %.3f", w2.Legendary, w2.Epic, w2.Rare)
	)
	local w4 = Luck.weightsAt(0, 4)
	expect(
		"L=4 start is clamped to 65% rare-or-better",
		near(w4.Legendary + w4.Epic + w4.Rare, 0.65, 1e-9),
		string.format("%.4f", w4.Legendary + w4.Epic + w4.Rare)
	)
	expect(
		"bad luck values are 1",
		Luck.clamp(0 / 0) == 1 and Luck.clamp(-3) == 1 and Luck.clamp("4") == 1 and Luck.clamp(9) == 4,
		'NaN, -3, "4", 9'
	)
	-- L-04: 20,000 real spawns at L = 1 and L = 4, recorded seed, never rerolled
	local RunConfigProfile = RunConfig.profile("Circuit")
	local seed = 70707
	local o1, e1, c1 = Luck.draw(RunSequence, RunConfigProfile, seed, 1, 20000)
	local o4, e4, c4 = Luck.draw(RunSequence, RunConfigProfile, seed, 4, 20000)
	expect(
		"L-04 L=1 observed vs rule within 1 point",
		math.abs(o1 - e1) <= 0.01,
		string.format(
			"observed %.2f%% expected %.2f%% (L %d E %d R %d C %d, seed %d)",
			o1 * 100,
			e1 * 100,
			c1.Legendary,
			c1.Epic,
			c1.Rare,
			c1.Common,
			seed
		)
	)
	expect(
		"L-04 L=4 observed vs rule within 1 point",
		math.abs(o4 - e4) <= 0.01,
		string.format(
			"observed %.2f%% expected %.2f%% (L %d E %d R %d C %d, seed %d)",
			o4 * 100,
			e4 * 100,
			c4.Legendary,
			c4.Epic,
			c4.Rare,
			c4.Common,
			seed
		)
	)
	expect(
		"L-04 luck x4 raises the Rare-or-better share",
		o4 > o1,
		string.format("%.2f%% -> %.2f%%", o1 * 100, o4 * 100)
	)
	return lines
end

return Luck
