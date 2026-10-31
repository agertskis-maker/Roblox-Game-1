--!strict
-- DEVELOPMENT TESTS for the island walking speed and boost lanes (Lane 3). Nothing requires this
-- module; it runs only when a developer calls it. Spec: vault/design/specs/walk-boost.md.
--
-- Three groups:
--   logic      WalkBoostLogic, pure: numbers (island base 32, boost 48), the speed formula,
--              geometry, height band, the state machine as a function of time and on-strip samples
--              (fixed and seeded random sample sequences), the state guard (gait per humanoid
--              state, air grace, stepGated), and the dust puff rules (none at rest, none off the
--              lane, none under Reduced Motion or low graphics, at most 4 a second).
--   modifiers  SpeedModifiers on a stand-alone Humanoid (not in a character): max-wins, no
--              stacking and no compounding, the 48 cap, exact base restore, someone else's base
--              kept, cleanup.
--   character  Studio Play mode, client: WalkBoost controllers on the real local character, with
--              a test clock and test strips (deterministic), then once over a strip of the built
--              island. Covers the island base (applied once on bind, restored on release), enter,
--              linger and ease, no stacking, takeover (released completely, nothing written over the
--              other controller, 32 again afterwards), the two switches, the state guard (Sit,
--              PlatformStand), dust puffs, destroy, and (option respawn) a respawn.
-- The live boost and island base are switched off (LocalPlayer "Lane3WalkBoostEnabled" and
-- "Lane3IslandBaseEnabled" = false) while the character group runs, which hands the pre-island
-- WalkSpeed (16) back; every attribute, the root's anchoring, position and WalkSpeed are put back
-- after, and the live controller then applies 32 again.
--
-- Studio, Play mode, client side (the MCP execute_luau tool with datamodel_type "Client"):
--   local T = require(game.Players.LocalPlayer.PlayerScripts.Client.Home.Island.WalkBoostTests)
--   return T.text(T.run({ respawn = true }))
-- respawn = true resets the character from the client and waits for the new one (about 5 to
-- 10 s). Edit mode (command bar) runs the logic and modifiers groups only:
--   local T = require(game.StarterPlayer.StarterPlayerScripts.Client.Home.Island.WalkBoostTests)
--   print(T.text(T.run()))

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local SpeedModifiers = require(ReplicatedStorage.Shared.Movement.SpeedModifiers)
local WalkBoost = require(script.Parent.WalkBoost)
local WalkBoostLogic = require(ReplicatedStorage.Shared.Island.WalkBoostLogic)

local WalkBoostTests = {}

export type Result = { group: string, name: string, ok: boolean?, detail: string? } -- ok nil: skipped
export type Report = {
	passed: number,
	failed: number,
	skipped: number,
	failures: { string },
	results: { Result },
}

local TEST_SWITCH = "Lane3WalkBoostTestEnabled"
local TEST_BASE_SWITCH = "Lane3IslandBaseTestEnabled"
local OVERRIDE = "Lane3ReducedMotionOverride"
local EPS = 1e-6
local ISLAND = WalkBoostLogic.IslandBase -- 32
local TOP = WalkBoostLogic.topSpeed() -- 48
local DT = 1 / 64 -- exact in binary: 16 steps are exactly one puff interval

local function approx(a: number?, b: number, eps: number?): boolean
	return a ~= nil and math.abs(a - b) <= (eps or 1e-3)
end

local function fmt(v: any): string
	if type(v) == "number" then
		return string.format("%.4f", v)
	end
	return tostring(v)
end

type Checker = (name: string, ok: boolean, detail: any?) -> ()

local function newReport(): (Report, (group: string) -> Checker, (group: string, name: string, why: string) -> ())
	local report: Report = { passed = 0, failed = 0, skipped = 0, failures = {}, results = {} }
	local function checker(group: string): Checker
		return function(name: string, ok: boolean, detail: any?)
			local d = if detail == nil then nil else fmt(detail)
			table.insert(report.results, { group = group, name = name, ok = ok, detail = d })
			if ok then
				report.passed += 1
			else
				report.failed += 1
				table.insert(report.failures, group .. ": " .. name .. (if d then " (" .. d .. ")" else ""))
			end
		end
	end
	local function skip(group: string, name: string, why: string)
		table.insert(report.results, { group = group, name = name, ok = nil, detail = why })
		report.skipped += 1
	end
	return report, checker, skip
end

----------------------------------------------------------------------------------------------
-- logic

local function logicTests(check: Checker)
	local L = WalkBoostLogic
	local M, LINGER, EASE = L.Multiplier, L.Linger, L.Ease
	check("numbers: 1.5x, 0.5 s linger, 0.5 s ease", M == 1.5 and LINGER == 0.5 and EASE == 0.5)
	check("island base is exactly 32 (Roblox's default is 16)", L.IslandBase == 32)
	check("32 boosted is 48", L.IslandBase * M == 48 and L.topSpeed() == 48)

	-- multiplierAt
	check("never on a strip: 1", L.multiplierAt(5, nil) == 1)
	for _, since in { 0, 0.1, 0.25, 0.4999, LINGER } do
		check("linger at +" .. since .. " s: full", L.multiplierAt(10 + since, 10) == M)
	end
	check("clock backwards: full", L.multiplierAt(9, 10) == M)
	check("ease midpoint (+0.75 s): 1.25", approx(L.multiplierAt(10.75, 10), 1.25, EPS), L.multiplierAt(10.75, 10))
	check(
		"ease midpoint speed (+0.75 s): 40",
		approx(L.speed(ISLAND, L.multiplierAt(10.75, 10)), 40, EPS),
		L.speed(ISLAND, L.multiplierAt(10.75, 10))
	)
	check("just after the linger: below full", L.multiplierAt(10 + LINGER + 0.001, 10) < M)
	check("end of ease (+1.0 s): exactly 1", L.multiplierAt(10 + LINGER + EASE, 10) == 1)
	check("end of ease (+1.0 s): exactly 32", L.speed(ISLAND, L.multiplierAt(10 + LINGER + EASE, 10)) == ISLAND)
	check("long after: exactly 1", L.multiplierAt(1e6, 10) == 1)
	do
		local prev, mono, bounded = M, true, true
		for i = 0, 100 do
			local m = L.multiplierAt(10 + LINGER + EASE * i / 100, 10)
			mono = mono and m <= prev + EPS
			bounded = bounded and m >= 1 and m <= M
			prev = m
		end
		check("ease is monotonic down", mono)
		check("ease stays within [1, 1.5]", bounded)
		-- 95 % of the way back within the ease time
		check("back within the ease time", L.multiplierAt(10 + LINGER + EASE * 0.9, 10) < 1 + 0.05 * (M - 1))
	end

	-- speed: the boost multiplies the base
	do
		check("speed: base 32, no boost: 32", L.speed(32, 1) == 32)
		check("speed: base 32, boosted: exactly 48", L.speed(32, M) == 48)
		check("speed: base 32, halfway back (1.25): exactly 40", L.speed(32, 1.25) == 40)
		check("speed: the old default base 16 boosts to 24", L.speed(16, M) == 24)
		check("speed: someone else's base 20 boosts to 30", L.speed(20, M) == 30)
		check("speed: a foreign base 40 x 1.5 is held to 48, not 60", L.speed(40, M) == 48)
		check("speed: base 48 stays 48", L.speed(48, M) == 48)
		check("speed: a base above 48 is not slowed by a boost (60)", L.speed(60, M) == 60)
		check("speed: a multiplier below 1 scales the base (32 x 0.5 = 16)", L.speed(32, 0.5) == 16)
		local rng = Random.new(20261029)
		local ok = true
		for _ = 1, 500 do
			local base = rng:NextNumber(0, 80)
			local m = rng:NextNumber(0.2, M)
			local v = L.speed(base, m)
			if m > 1 then
				ok = ok and v >= base - EPS and v <= math.max(base, L.topSpeed()) + EPS
			else
				ok = ok and approx(v, base * m, EPS)
			end
		end
		check("speed: 500 random: a boost never goes above max(base, 48) or below the base", ok)
		local v = ISLAND
		for _ = 1, 100 do
			v = L.speed(ISLAND, M) -- a function of the base, never of the speed it made last time
		end
		check("speed: a boost applied 100 times never compounds", v == 48)
	end

	-- step: the state machine
	do
		local s = L.newState()
		check("new state: 1", L.step(s, 0, false) == 1)
		check("enter: full", L.step(s, 1, true) == M)
		check("same frame again: still full, no stack", L.step(s, 1, true) == M)
		for _ = 1, 50 do
			L.step(s, 1, true)
		end
		check("50 samples in one frame: full", L.step(s, 1, true) == M)
		check("off within linger: full", L.step(s, 1.3, false) == M)
		check("off in the ease: between", L.step(s, 1.7, false) > 1 and L.step(s, 1.7, false) < M)
		check("re-enter during the ease: full, not more", L.step(s, 1.8, true) == M)
		check(
			"an older on-sample never shortens the boost",
			(function()
				L.step(s, 1.2, true)
				return s.lastOnStrip == 1.8
			end)()
		)
		check("after the ease: exactly 1", L.step(s, 1.8 + LINGER + EASE, false) == 1)
		L.reset(s)
		check("reset: 1 at once", L.step(s, 1.81, false) == 1)
	end

	-- step against an independent model, seeded random sample sequences
	do
		local rng = Random.new(20261022)
		local ok, maxSeen, minSeen = true, 1, 1
		for _ = 1, 200 do
			local s = L.newState()
			local t = 0
			local lastOn: number? = nil
			for _ = 1, 120 do
				t += rng:NextNumber(0, 0.08)
				local on = rng:NextNumber() < 0.35
				if on then
					lastOn = t
				end
				local m = L.step(s, t, on)
				local expect = 1
				if lastOn then
					local since = t - lastOn
					if since <= LINGER then
						expect = M
					elseif since < LINGER + EASE then
						local u = (since - LINGER) / EASE
						expect = M - (M - 1) * u * u * (3 - 2 * u)
					end
				end
				ok = ok and math.abs(m - expect) < EPS
				maxSeen = math.max(maxSeen, m)
				minSeen = math.min(minSeen, m)
			end
		end
		check("200 random sequences match the model", ok)
		check("random sequences never above 1.5", maxSeen <= M, maxSeen)
		check("random sequences never below 1", minSeen >= 1, minSeen)
		check("random sequences: the speed never goes above 48", L.speed(ISLAND, maxSeen) <= 48)
	end

	-- a frame-stepped walk across a strip at 60 Hz: on for 2 s, then off
	do
		local s = L.newState()
		local dt = 1 / 60
		local leftAt: number? = nil
		local fullUntil, backAt = 0, math.huge
		for f = 0, 240 do
			local t = f * dt
			local on = t <= 2
			local m = L.step(s, t, on)
			if on then
				leftAt = t
			end
			if m == M then
				fullUntil = t
			end
			if not on and m == 1 and backAt == math.huge then
				backAt = t
			end
		end
		local left = leftAt :: number
		check("walk: full for the linger after leaving", approx(fullUntil - left, LINGER, dt + EPS), fullUntil - left)
		check(
			"walk: base again about 0.5 s after the linger",
			approx(backAt - left, LINGER + EASE, dt + EPS),
			backAt - left
		)
	end

	-- the state guard (review M1): gait classification
	do
		local H = Enum.HumanoidStateType
		local GRACE = L.AirGrace
		check("guard: air grace is 1 s", GRACE == 1)
		local function all(states: { Enum.HumanoidStateType }, want: WalkBoostLogic.Gait): boolean
			for _, st in states do
				if L.gait(st) ~= want then
					return false
				end
			end
			return true
		end
		check(
			"guard: Running, RunningNoPhysics, Landed are walk",
			all({ H.Running, H.RunningNoPhysics, H.Landed }, "walk")
		)
		check("guard: Jumping, Freefall are air", all({ H.Jumping, H.Freefall }, "air"))
		check(
			"guard: Climbing, PlatformStanding, Physics, Ragdoll, FallingDown, GettingUp are off",
			all({ H.Climbing, H.PlatformStanding, H.Physics, H.Ragdoll, H.FallingDown, H.GettingUp }, "off")
		)
		check("guard: None, Flying, StrafingNoPhysics are off", all({ H.None, H.Flying, H.StrafingNoPhysics }, "off"))
		check("guard: Seated, Swimming, Dead are drop", all({ H.Seated, H.Swimming, H.Dead }, "drop"))
		do
			local walks, valid = 0, true
			for _, item in H:GetEnumItems() do
				local g = L.gait(item :: any)
				valid = valid and (g == "walk" or g == "air" or g == "off" or g == "drop")
				if g == "walk" then
					walks += 1
				end
			end
			check("guard: every state has a gait; only three are walk", valid and walks == 3, walks)
		end
		check("guard: Sit while Running is drop", L.gait(H.Running, true) == "drop")
		check("guard: Sit while in the air is drop", L.gait(H.Freefall, true) == "drop")
		check("guard: PlatformStand while Running is off", L.gait(H.Running, false, true) == "off")
		check("guard: PlatformStand while Swimming is still drop", L.gait(H.Swimming, false, true) == "drop")

		check("guard: walk counts", L.counts("walk"))
		check("guard: off never counts", not L.counts("off") and not L.counts("off", 0))
		check("guard: drop never counts", not L.counts("drop"))
		check("guard: air counts at take-off", L.counts("air", 0))
		check("guard: air counts at the end of the grace", L.counts("air", GRACE))
		check("guard: air stops counting after the grace", not L.counts("air", GRACE + 0.01))
	end

	-- the state guard: stepGated
	do
		local GRACE = L.AirGrace
		local s = L.newState()
		local m, counted = L.stepGated(s, 0, true, "walk")
		check("gated: walking onto a strip: full, counted", m == M and counted)
		m, counted = L.stepGated(s, 0.25, true, "off")
		check("gated: not walking on a strip: not counted, linger holds", m == M and not counted)
		check(
			"gated: not walking: eases like stepping off (+0.75 s)",
			approx(L.stepGated(s, 0.75, true, "off"), 1.25, EPS)
		)
		check("gated: not walking: exactly 1 at +1.0 s", L.stepGated(s, 1.0, true, "off") == 1)
		check("gated: walking again on the strip: full at once", L.stepGated(s, 1.1, true, "walk") == M)

		-- seated (or swimming, or dead) on a strip: exactly 1 at once, state cleared
		s = L.newState()
		L.stepGated(s, 0, true, "walk")
		m, counted = L.stepGated(s, 0.1, true, "drop")
		check("gated: drop on a strip: exactly 1 at once", m == 1 and not counted)
		check("gated: drop clears the state", s.lastOnStrip == nil and s.airSince == nil)
		check("gated: drop a frame later: still 1", L.stepGated(s, 0.2, true, "drop") == 1)
		check("gated: stand up on the strip: full", L.stepGated(s, 0.3, true, "walk") == M)
		L.stepGated(s, 0.4, true, "drop")
		check("gated: stand up off the strip: 1, nothing carried", L.stepGated(s, 0.5, false, "walk") == 1)

		-- a hop on a strip: full boost throughout, 60 Hz
		s = L.newState()
		L.stepGated(s, 0, true, "walk")
		local held = true
		for f = 1, 60 do
			held = held and L.stepGated(s, f / 60, true, "air") == M
		end
		check("gated: a 1 s hop on a strip: full throughout", held)
		check("gated: landing after the hop: full", L.stepGated(s, 1.05, true, "walk") == M)
		check("gated: landing ends the air spell", s.airSince == nil)

		-- a long fall over a strip: counts for the grace, then the normal linger and ease
		s = L.newState()
		L.stepGated(s, 0, true, "walk")
		L.stepGated(s, 0, true, "air") -- take-off: the spell starts at 0
		m, counted = L.stepGated(s, GRACE, true, "air")
		check("gated: long fall, end of the grace: counted", m == M and counted)
		m, counted = L.stepGated(s, GRACE + 0.01, true, "air")
		check("gated: long fall, past the grace: not counted", m == M and not counted)
		check("gated: long fall: full to grace + linger", L.stepGated(s, GRACE + LINGER, true, "air") == M)
		check(
			"gated: long fall: easing (grace + 0.75 s)",
			approx(L.stepGated(s, GRACE + 0.75, true, "air"), 1.25, EPS),
			L.stepGated(s, GRACE + 0.75, true, "air")
		)
		check("gated: long fall: exactly 1 at grace + 1.0 s", L.stepGated(s, GRACE + LINGER + EASE, true, "air") == 1)

		-- the air clock restarts after landing; a jump onto a strip counts
		s = L.newState()
		L.stepGated(s, 10, false, "air")
		L.stepGated(s, 10.5, false, "walk")
		L.stepGated(s, 10.6, false, "air")
		check("gated: a new jump restarts the air clock", s.airSince == 10.6)
		check("gated: jumping onto a strip: full", L.stepGated(s, 11.5, true, "air") == M)
		check(
			"gated: reset clears the air clock",
			(function()
				L.reset(s)
				return s.airSince == nil and s.lastOnStrip == nil
			end)()
		)
	end

	-- the state guard against an independent model, seeded random gait sequences
	do
		local rng = Random.new(20261023)
		local gaits: { WalkBoostLogic.Gait } = { "walk", "walk", "air", "off", "drop" }
		local ok, dropOk, maxSeen, minSeen, expired = true, true, 1, 1, 0
		for _ = 1, 200 do
			local s = L.newState()
			local t = 0
			local gait: WalkBoostLogic.Gait = "walk"
			local lastOn: number?, airSince: number? = nil, nil
			for _ = 1, 120 do
				t += rng:NextNumber(0, 0.2)
				if rng:NextNumber() < 0.2 then
					gait = gaits[rng:NextInteger(1, #gaits)]
				end
				local over = rng:NextNumber() < 0.5
				local expect = 1
				if gait == "drop" then
					lastOn, airSince = nil, nil
				else
					if gait == "air" then
						airSince = airSince or t
					else
						airSince = nil
					end
					local inGrace = gait == "air" and t - (airSince :: number) <= L.AirGrace
					if gait == "air" and not inGrace then
						expired += 1
					end
					if over and (gait == "walk" or inGrace) then
						lastOn = t
					end
					if lastOn then
						local since = t - lastOn
						if since <= LINGER then
							expect = M
						elseif since < LINGER + EASE then
							local u = (since - LINGER) / EASE
							expect = M - (M - 1) * u * u * (3 - 2 * u)
						end
					end
				end
				local m = L.stepGated(s, t, over, gait)
				ok = ok and math.abs(m - expect) < EPS
				dropOk = dropOk and (gait ~= "drop" or m == 1)
				maxSeen = math.max(maxSeen, m)
				minSeen = math.min(minSeen, m)
			end
		end
		check("gated: 200 random gait sequences match the model", ok)
		check("gated: random sequences cover an expired air grace", expired > 0, expired)
		check("gated: random sequences: a drop is always exactly 1", dropOk)
		check("gated: random sequences never above 1.5 or below 1", maxSeen <= M and minSeen >= 1, maxSeen)
	end

	-- geometry
	do
		local strip: WalkBoostLogic.Strip = { from = Vector2.new(0, 0), to = Vector2.new(20, 0) }
		local hw = 2.1
		check("centre line: on", L.onStripPlan(Vector2.new(10, 0), { strip }, hw))
		check("at the half-width: on", L.onStripPlan(Vector2.new(10, 2.1), { strip }, hw))
		check("just outside: off", not L.onStripPlan(Vector2.new(10, 2.11), { strip }, hw))
		check("past the end, inside the round cap: on", L.onStripPlan(Vector2.new(21.5, 0), { strip }, hw))
		check("past the end: off", not L.onStripPlan(Vector2.new(22.2, 0), { strip }, hw))
		check("no strips: off", not L.onStripPlan(Vector2.new(0, 0), {}, hw))
		check(
			"degenerate strip: a point",
			L.distanceToStrip(Vector2.new(3, 4), { from = Vector2.new(0, 0), to = Vector2.new(0, 0) }) == 5
		)
		check("default half-width is 2.1", L.HalfWidth == 2.1)
		-- world frame: plan y north = world -Z
		check("toPlan flips Z", L.toPlan(Vector3.new(3, 9, -7)) == Vector2.new(3, 7))
		local raised: WalkBoostLogic.Strip = { from = Vector2.new(0, 0), to = Vector2.new(20, 0), y = 5 }
		check("height: standing root (+3): on", L.overStrip(Vector3.new(10, 8, 0), { raised }, hw))
		check("height: jump apex (+9.4): on", L.overStrip(Vector3.new(10, 14.4, 0), { raised }, hw))
		check("height: bridge above (+12): off", not L.overStrip(Vector3.new(10, 17, 0), { raised }, hw))
		check("height: below the surface (-2): off", not L.overStrip(Vector3.new(10, 3, 0), { raised }, hw))
		check("height unknown: plan only", L.overStrip(Vector3.new(10, 500, 0), { strip }, hw))
		check("world Z: plan y 1 is world Z -1", L.overStrip(Vector3.new(10, 8, -1), { raised }, hw))
		check("two overlapping strips: on, once", L.overStrip(Vector3.new(10, 8, 0), { raised, raised }, hw))
	end

	check("intensity 1 = 0", L.intensity(1) == 0)
	check("intensity 1.5 = 1", L.intensity(M) == 1)
	check("intensity 1.25 = 0.5", approx(L.intensity(1.25), 0.5, EPS))
	check("intensity clamps", L.intensity(3) == 1 and L.intensity(0.5) == 0)

	-- dust puffs (Adam's Design 6): the rules, without a character
	do
		check(
			"dust: limits are 0.25 s lifetime, 0.15 to 0.35 stud, at most 4 a second",
			L.PuffLifetime == 0.25 and L.PuffSizeMin == 0.15 and L.PuffSizeMax == 0.35 and 1 / L.PuffInterval == 4
		)
		check(
			"dust: low graphics is saved quality 1 to 3 (Automatic 0 is not low)",
			not L.lowGraphics(0)
				and L.lowGraphics(1)
				and L.lowGraphics(2)
				and L.lowGraphics(3)
				and not L.lowGraphics(4)
				and not L.lowGraphics(10)
		)
		local fast = L.topSpeed()
		check("dust: wanted when walking along a lane at speed", L.puffWanted(true, "walk", fast, false, false))
		check("dust: none at rest", not L.puffWanted(true, "walk", 0, false, false))
		check("dust: none at the rest threshold", not L.puffWanted(true, "walk", L.PuffMinSpeed, false, false))
		check(
			"dust: wanted just above the rest threshold",
			L.puffWanted(true, "walk", L.PuffMinSpeed + 0.1, false, false)
		)
		check("dust: none at normal 32 walking off a lane", not L.puffWanted(false, "walk", ISLAND, false, false))
		check("dust: none under Reduced Motion", not L.puffWanted(true, "walk", fast, true, false))
		check("dust: none at low graphics detail", not L.puffWanted(true, "walk", fast, false, true))
		check(
			"dust: none in the air, off the ground, or seated",
			not L.puffWanted(true, "air", fast, false, false)
				and not L.puffWanted(true, "off", fast, false, false)
				and not L.puffWanted(true, "drop", fast, false, false)
		)
		check("puffDue: the first puff", L.puffDue(nil, 5))
		check("puffDue: not before the interval", not L.puffDue(5, 5.1) and not L.puffDue(5, 5.2499))
		check("puffDue: at the interval", L.puffDue(5, 5.25))
		check("puffDue: a clock that went backwards", L.puffDue(5, 4))
		-- a stream of frames, at several frame rates: at most four puffs a second
		for _, hz in { 30, 60, 144, 240 } do
			local last: number? = nil
			local times: { number } = {}
			for f = 0, hz * 10 do
				local now = f / hz
				if L.puffWanted(true, "walk", fast, false, false) and L.puffDue(last, now) then
					last = now
					table.insert(times, now)
				end
			end
			local gapOk, five = true, math.huge
			for i = 2, #times do
				gapOk = gapOk and times[i] - times[i - 1] >= L.PuffInterval - 1e-6
			end
			for i = 5, #times do
				five = math.min(five, times[i] - times[i - 4])
			end
			check(hz .. " Hz, 10 s moving on a lane: puffs are 0.25 s or more apart", gapOk)
			check(hz .. " Hz: any five puffs in a row take 1 s or more (at most 4 a second)", five >= 1 - 1e-4, five)
			check(hz .. " Hz: puffs do happen (at least 30 in 10 s)", #times >= 30 and #times <= 41, #times)
		end
	end
end

----------------------------------------------------------------------------------------------
-- modifiers

local function flush()
	task.wait() -- lets deferred property-changed events run
end

local function modifierTests(check: Checker)
	local S = SpeedModifiers
	check("cap: BoostCap is the island base x the multiplier (32 x 1.5 = 48)", S.BoostCap == WalkBoostLogic.topSpeed())
	check("cap: MaxMultiplier is the lane multiplier", S.MaxMultiplier == WalkBoostLogic.Multiplier)
	do
		local same = true
		for _, base in { 0, 16, 20, 32, 40, 48, 60 } do
			for _, m in { 0.5, 1, 1.25, 1.5 } do
				same = same and S.target(base, m) == WalkBoostLogic.speed(base, m)
			end
		end
		check("target: the same formula as WalkBoostLogic.speed", same)
		check(
			"target: 32 x 1.5 = 48, 40 x 1.5 held to 48, 60 not slowed",
			S.target(32, 1.5) == 48 and S.target(40, 1.5) == 48 and S.target(60, 1.5) == 60
		)
	end
	check("combine: none is 1", S.combine({}) == 1)
	check("combine: largest wins", S.combine({ a = 1.5, b = 1.2 }) == 1.5)
	check("combine: clamped to 1.5", S.combine({ a = 3 }) == 1.5)
	check("combine: a slow alone", S.combine({ a = 0.5 }) == 0.5)

	local before = S.stats()
	local h = Instance.new("Humanoid")

	-- the island base: 32 boosted is 48, never more
	h.WalkSpeed = ISLAND
	S.set(h, "A", 1.5)
	check("island base: set 1.5: 48", h.WalkSpeed == TOP, h.WalkSpeed)
	S.set(h, "A", 1.5)
	check("island base: set again: still 48", h.WalkSpeed == TOP, h.WalkSpeed)
	S.set(h, "B", 1.2)
	check("island base: second source 1.2: still 48 (max, not product)", h.WalkSpeed == TOP, h.WalkSpeed)
	S.set(h, "A", 3)
	check("island base: a multiplier of 3 is clamped: 48", h.WalkSpeed == TOP, h.WalkSpeed)
	for _ = 1, 100 do
		S.set(h, "A", 1.5)
		S.set(h, "B", 1.5)
	end
	check("island base: 100 repeated sets never compound: 48", h.WalkSpeed == TOP, h.WalkSpeed)
	S.set(h, "A", 1.25)
	S.clear(h, "B")
	check("island base: eased to 1.25: exactly 40", h.WalkSpeed == 40, h.WalkSpeed)
	S.clear(h, "A")
	check("island base: clear the last: exactly 32", h.WalkSpeed == ISLAND, h.WalkSpeed)
	check("island base: idle humanoid holds no state", S.stats().humanoids == before.humanoids)

	-- the old default 16 still boosts to 24 (the base is whatever the humanoid has)
	h.WalkSpeed = 16
	S.set(h, "A", 1.5)
	check("set 1.5 on a base of 16: 24", h.WalkSpeed == 24, h.WalkSpeed)
	S.set(h, "A", 1.5)
	check("set again: still 24", h.WalkSpeed == 24, h.WalkSpeed)
	S.set(h, "B", 1.2)
	check("second source 1.2: still 24 (max, not product)", h.WalkSpeed == 24, h.WalkSpeed)
	S.clear(h, "A")
	check("clear the larger: 19.2", approx(h.WalkSpeed, 19.2), h.WalkSpeed)
	S.clear(h, "B")
	check("clear the last: exactly 16", h.WalkSpeed == 16, h.WalkSpeed)
	check("idle humanoid holds no state", S.stats().humanoids == before.humanoids)
	check("idle humanoid holds no connections", S.stats().connections == before.connections)
	S.clear(h, "B")
	check("clearing an absent source changes nothing", h.WalkSpeed == 16)

	-- eased values (float read-back) are not mistaken for someone else's change
	S.set(h, "A", 1.2345)
	flush()
	S.set(h, "A", 1.2345)
	flush()
	check("eased value: base kept at 16", S.base(h) == 16, S.base(h))
	S.set(h, "A", 1.1)
	flush()
	S.clear(h, "A")
	check("after eased values: exactly 16", h.WalkSpeed == 16, h.WalkSpeed)

	-- someone else sets a base while a source is active
	S.set(h, "A", 1.5)
	h.WalkSpeed = 20
	flush()
	check("someone else's 20 becomes the base", S.base(h) == 20, S.base(h))
	check("boost on their base 20: 30 (their base x 1.5)", h.WalkSpeed == 30, h.WalkSpeed)
	h.WalkSpeed = 40
	flush()
	check("boost on their base 40: held to 48, not 60", h.WalkSpeed == TOP, h.WalkSpeed)
	h.WalkSpeed = 60
	flush()
	check("a base already above 48 is left as it is: 60", h.WalkSpeed == 60, h.WalkSpeed)
	S.clear(h, "A")
	check("clear: their 60 stays, not our old 16", h.WalkSpeed == 60, h.WalkSpeed)
	h.WalkSpeed = 16
	flush()

	-- someone else changes it after the boost and before the clear: never stomped
	S.set(h, "A", 1.5)
	S.clearAll(h)
	check("clearAll: exactly 16", h.WalkSpeed == 16, h.WalkSpeed)

	-- destroyed humanoid: state dropped
	S.set(h, "A", 1.5)
	h:Destroy()
	flush()
	check("destroyed humanoid: state dropped", S.stats().humanoids == before.humanoids)
	check("destroyed humanoid: connections dropped", S.stats().connections == before.connections)
end

----------------------------------------------------------------------------------------------
-- character

type Saved = { [string]: any }

local function effectCounts(character: Instance): { [string]: number }
	local out: { [string]: number } = { Attachment = 0, Trail = 0, ParticleEmitter = 0, PointLight = 0 }
	for _, d in character:GetDescendants() do
		if string.sub(d.Name, 1, #WalkBoost.EffectPrefix) == WalkBoost.EffectPrefix then
			out[d.ClassName] = (out[d.ClassName] or 0) + 1
		end
	end
	return out
end

local function effectTotal(character: Instance): number
	local n = 0
	for _, v in effectCounts(character) do
		n += v
	end
	return n
end

-- One set of effects: the dust attachment and its emitter, and nothing else (no wind trails,
-- streaks or glow any more).
local function oneSet(character: Instance): boolean
	local c = effectCounts(character)
	return c.Attachment == 1 and c.ParticleEmitter == 1 and c.Trail == 0 and c.PointLight == 0
end

local function parts(player: Player, timeout: number): (Model?, Humanoid?, BasePart?)
	local started = os.clock()
	while os.clock() - started < timeout do
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if character and humanoid and humanoid.Health > 0 and root and root:IsA("BasePart") then
			return character, humanoid, root :: BasePart
		end
		task.wait(0.1)
	end
	return nil, nil, nil
end

-- Waits (real time, up to timeout s) until the controller's state guard reads the given gait:
-- the humanoid's own state changes (standing up, getting up) take a few frames.
local function waitGait(c: WalkBoost.Controller, gait: WalkBoostLogic.Gait, timeout: number): boolean
	local started = os.clock()
	while c.status().gait ~= gait do
		if os.clock() - started > timeout then
			return false
		end
		task.wait()
	end
	return true
end

-- Steps a controller with its test clock for `seconds` of test time at 64 Hz; returns the end
-- time and the times at which a dust puff was made.
local function runFor(ctl: WalkBoost.Controller, from: number, seconds: number): (number, { number })
	local times: { number } = {}
	local seen = ctl.status().puffs
	local steps = math.floor(seconds / DT + 0.5)
	for i = 1, steps do
		local now = from + i * DT
		ctl.update(now)
		local after = ctl.status().puffs
		if after > seen then
			table.insert(times, now)
			seen = after
		end
	end
	return from + steps * DT, times
end

local function minGap(times: { number }): number
	local gap = math.huge
	for i = 2, #times do
		gap = math.min(gap, times[i] - times[i - 1])
	end
	return gap
end

-- The shortest time taken by any five puffs in a row (at most 4 a second means 1 s or more).
local function fiveSpan(times: { number }): number
	local best = math.huge
	for i = 5, #times do
		best = math.min(best, times[i] - times[i - 4])
	end
	return best
end

local function stripUnder(root: BasePart, humanoid: Humanoid, withHeight: boolean): WalkBoostLogic.Strip
	local p = WalkBoostLogic.toPlan(root.Position)
	local ground = root.Position.Y - humanoid.HipHeight - root.Size.Y / 2
	return {
		from = p - Vector2.new(10, 0),
		to = p + Vector2.new(10, 0),
		y = if withHeight then ground else nil,
	}
end

local function characterTests(check: Checker, skip: (string) -> (), respawn: boolean, cleanups: { () -> () })
	local player = Players.LocalPlayer
	local character, humanoid, root = parts(player, 10)
	if not (character and humanoid and root) then
		skip("no live local character after 10 s")
		return
	end
	local char, hum, hrp = character :: Model, humanoid :: Humanoid, root :: BasePart

	-- switch the live boost and island base off for the test (the pre-island speed comes back),
	-- and check those switches on the way; low graphics is forced off so the dust tests do not
	-- depend on this machine's quality setting
	player:SetAttribute(WalkBoost.SwitchAttribute, false)
	player:SetAttribute(WalkBoost.BaseSwitchAttribute, false)
	player:SetAttribute(TEST_SWITCH, nil)
	player:SetAttribute(TEST_BASE_SWITCH, nil)
	player:SetAttribute(WalkBoost.TakeoverAttribute, nil)
	player:SetAttribute(OVERRIDE, false)
	player:SetAttribute(WalkBoost.LowGraphicsOverride, false)
	flush()
	flush()
	local pre = hum.WalkSpeed -- the speed the island hands back: the default 16
	check("live boost switched off: no effects on the character", effectTotal(char) == 0, effectTotal(char))
	check("live boost switched off: status attribute removed", player:GetAttribute(WalkBoost.PublishAttribute) == nil)
	check("live island base released: WalkSpeed is the default 16", pre == 16, pre)

	local wasAnchored = hrp.Anchored
	local home = char:GetPivot()
	hrp.Anchored = true -- hold still: the strips are placed round the root
	table.insert(cleanups, function()
		if hrp.Parent then
			hrp.AssemblyLinearVelocity = Vector3.zero
			char:PivotTo(home)
			hrp.Anchored = wasAnchored
		end
	end)

	local t = 0
	local strips: { WalkBoostLogic.Strip } = {}
	local c = WalkBoost.new({
		strips = strips,
		halfWidth = 2.1,
		manual = true,
		clock = function()
			return t
		end,
		switchAttribute = TEST_SWITCH,
		baseSwitchAttribute = TEST_BASE_SWITCH,
	})
	table.insert(cleanups, c.destroy)
	local idle = WalkBoost.IdleConnections
	local boundManual = idle + 1 + WalkBoost.GuardConnections -- Died + the state guard

	-- the island base: written once on bind
	local st = c.status()
	check("bound to the character", st.bound and st.character == char)
	check("island base: exactly 32 on bind", hum.WalkSpeed == ISLAND, hum.WalkSpeed)
	check("island base: written once, held", st.islandWrites == 1 and st.islandHeld, st.islandWrites)
	check("island base: the pre-island speed is remembered (16)", st.preIsland == pre, st.preIsland)
	local walking = waitGait(c, "walk", 3)
	check("state guard: the held test character reads as walking", walking, c.status().gait)
	check("bound: connection count", st.connections == boundManual, st.connections)
	check("one set of effects", oneSet(char))
	check("off the strip: the island base", c.update(0) == 1 and hum.WalkSpeed == ISLAND, hum.WalkSpeed)

	-- enter
	table.insert(strips, stripUnder(hrp, hum, true))
	c.update(0.1)
	check("enter: WalkSpeed 48", hum.WalkSpeed == TOP, hum.WalkSpeed)
	c.update(0.1)
	c.update(0.1)
	check("repeat samples: still 48", hum.WalkSpeed == TOP, hum.WalkSpeed)
	for _ = 1, 50 do
		c.update(0.15)
	end
	check("50 updates in one frame: still 48", hum.WalkSpeed == TOP, hum.WalkSpeed)
	table.insert(strips, stripUnder(hrp, hum, true))
	table.insert(strips, stripUnder(hrp, hum, true))
	c.update(0.2)
	check("three overlapping strips: still 48, not per lane", hum.WalkSpeed == TOP, hum.WalkSpeed)
	table.remove(strips)
	table.remove(strips)
	for f = 1, 60 do
		c.update(0.2 + f / 60)
	end
	check("a second on the strip: still 48", hum.WalkSpeed == TOP, hum.WalkSpeed)
	check("island base: only the one write so far", c.status().islandWrites == 1, c.status().islandWrites)
	local leftAt = 0.2 + 60 / 60

	-- reduced motion mid-boost, applied on the attribute event (no update call)
	check("full motion: dust allowed", c.status().dust)
	player:SetAttribute(OVERRIDE, true)
	flush()
	st = c.status()
	check("reduced motion: dust not allowed", st.reducedMotion and not st.dust)
	c.update(leftAt)
	check("reduced motion: the boost itself is unchanged", hum.WalkSpeed == TOP, hum.WalkSpeed)
	player:SetAttribute(OVERRIDE, false)
	flush()
	check("full motion back: dust allowed", c.status().dust)
	check("effects not duplicated", oneSet(char))

	-- leave: linger, then ease
	table.clear(strips)
	c.update(leftAt + 0.25)
	check("left +0.25 s: still 48", hum.WalkSpeed == TOP, hum.WalkSpeed)
	c.update(leftAt + 0.5)
	check("left +0.5 s: still 48 (end of linger)", hum.WalkSpeed == TOP, hum.WalkSpeed)
	c.update(leftAt + 0.75)
	check("left +0.75 s: easing (40)", approx(hum.WalkSpeed, ISLAND * 1.25, 0.01), hum.WalkSpeed)
	c.update(leftAt + 0.95)
	check("left +0.95 s: nearly back", hum.WalkSpeed > ISLAND and hum.WalkSpeed < ISLAND + 0.8, hum.WalkSpeed) -- smoothstep at 90 % of the ease: 1.014 x = 32.45
	c.update(leftAt + 1.0)
	check("left +1.0 s: exactly 32", hum.WalkSpeed == ISLAND, hum.WalkSpeed)
	check("back at base: no modifier state left", SpeedModifiers.multiplier(hum) == 1)

	-- re-enter during the ease
	table.insert(strips, stripUnder(hrp, hum, true))
	c.update(5)
	table.clear(strips)
	c.update(5.7)
	table.insert(strips, stripUnder(hrp, hum, true))
	c.update(5.8)
	check("re-enter while easing: 48, not more", hum.WalkSpeed == TOP, hum.WalkSpeed)

	-- someone else sets a base while boosted (their value is the base, kept after)
	hum.WalkSpeed = 20
	flush()
	c.update(5.9)
	check("someone else's base 20, boosted: 30 (their base x 1.5)", hum.WalkSpeed == 30, hum.WalkSpeed)
	hum.WalkSpeed = 40
	flush()
	c.update(5.95)
	check("someone else's base 40, boosted: held to 48, not 60", hum.WalkSpeed == TOP, hum.WalkSpeed)
	table.clear(strips)
	c.update(7)
	check("their base 40 comes back, not 32", hum.WalkSpeed == 40, hum.WalkSpeed)
	check("island base: not written again over theirs", c.status().islandWrites == 1, c.status().islandWrites)
	hum.WalkSpeed = ISLAND
	flush()

	-- takeover (Brian R's run): the island releases completely and writes nothing over it
	table.insert(strips, stripUnder(hrp, hum, true))
	c.update(8)
	check("before takeover: boosted 48", hum.WalkSpeed == TOP, hum.WalkSpeed)
	local writes = c.status().islandWrites
	player:SetAttribute(WalkBoost.TakeoverAttribute, "WalkBoostTest")
	flush()
	st = c.status()
	check("takeover: stands aside (unbound)", not st.bound and st.takenOver)
	check("takeover: the exact pre-island speed (16) is back", hum.WalkSpeed == pre, hum.WalkSpeed)
	check("takeover: effects removed", effectTotal(char) == 0, effectTotal(char))
	check("takeover: only idle connections", st.connections == idle, st.connections)
	check("takeover: updates do nothing", c.update(8.1) == 1 and hum.WalkSpeed == pre, hum.WalkSpeed)
	do
		-- the other controller writes its own speed; the island must not write over it
		flush() -- the island's own restore write has been reported before the count starts
		local events = 0
		local watch = hum:GetPropertyChangedSignal("WalkSpeed"):Connect(function()
			events += 1
		end)
		hum.WalkSpeed = 23
		for i = 1, 8 do
			c.update(8.1 + i * 0.1)
			task.wait()
		end
		flush()
		check("takeover: the other controller's 23 is not overwritten", hum.WalkSpeed == 23, hum.WalkSpeed)
		check("takeover: the island wrote nothing (one change seen, the other controller's own)", events == 1, events)
		check("takeover: no island write counted", c.status().islandWrites == writes, c.status().islandWrites)
		watch:Disconnect()
	end
	hum.WalkSpeed = pre -- the other controller hands back 16 when its run ends
	player:SetAttribute(WalkBoost.TakeoverAttribute, nil)
	flush()
	st = c.status()
	check("takeover ended: exactly 32 again", hum.WalkSpeed == ISLAND, hum.WalkSpeed)
	check("takeover ended: written once more, not repeatedly", st.islandWrites == writes + 1, st.islandWrites)
	check("takeover ended: bound again, same connection count", st.bound and st.connections == boundManual)
	check("takeover ended: the pre-island speed is 16 again", st.preIsland == pre, st.preIsland)
	check("takeover ended: one set of effects", oneSet(char))
	c.update(9)
	check("takeover ended: boost works again (48)", hum.WalkSpeed == TOP, hum.WalkSpeed)

	-- takeover during the linger, and the other controller writing before the island saw the event
	table.clear(strips)
	c.update(9.2)
	check("linger before takeover: still 48", hum.WalkSpeed == TOP, hum.WalkSpeed)
	player:SetAttribute(WalkBoost.TakeoverAttribute, "WalkBoostTest")
	hum.WalkSpeed = 23 -- written straight after the attribute, before the event is handled
	flush()
	check("takeover with a late event: the 23 is kept", hum.WalkSpeed == 23, hum.WalkSpeed)
	check(
		"takeover with a late event: unbound, idle connections",
		not c.status().bound and c.status().connections == idle
	)
	player:SetAttribute(WalkBoost.TakeoverAttribute, nil) -- the run ended and left 23 behind
	flush()
	st = c.status()
	check("takeover ended: 32 again", hum.WalkSpeed == ISLAND, hum.WalkSpeed)
	check("takeover ended: the speed at that moment (23) is the pre-island value", st.preIsland == 23, st.preIsland)
	c.update(9.3)
	check("departure during the linger: no boost carried back", hum.WalkSpeed == ISLAND, hum.WalkSpeed)
	player:SetAttribute(WalkBoost.TakeoverAttribute, "WalkBoostTest")
	flush()
	check("second takeover: 23 comes back exactly", hum.WalkSpeed == 23, hum.WalkSpeed)
	hum.WalkSpeed = pre
	player:SetAttribute(WalkBoost.TakeoverAttribute, nil)
	flush()
	check("takeover ended: 32 again, pre-island 16", hum.WalkSpeed == ISLAND and c.status().preIsland == pre)

	-- consumer mode for a movement system: computes, never writes
	do
		table.insert(strips, stripUnder(hrp, hum, true))
		player:SetAttribute(WalkBoost.TakeoverAttribute, "WalkBoostTest")
		flush()
		local held = hum.WalkSpeed
		local seen: number? = nil
		local consumer = WalkBoost.new({
			strips = strips,
			manual = true,
			clock = function()
				return t
			end,
			switchAttribute = TEST_SWITCH,
			baseSwitchAttribute = TEST_BASE_SWITCH,
			write = false,
			effects = false,
			respectTakeover = false,
		})
		local conn = consumer.Changed:Connect(function(m: number)
			seen = m
		end)
		local m = consumer.update(9.5)
		check("consumer: reports 1.5", m == 1.5 and seen == 1.5, m)
		check("consumer: WalkSpeed untouched", hum.WalkSpeed == held, hum.WalkSpeed)
		check("consumer: no island base", consumer.status().islandWrites == 0 and not consumer.status().island)
		conn:Disconnect()
		consumer.destroy()
		check("consumer destroyed: no connections", consumer.status().connections == 0)
		check("consumer destroyed: WalkSpeed untouched", hum.WalkSpeed == held, hum.WalkSpeed)
		player:SetAttribute(WalkBoost.TakeoverAttribute, nil)
		flush()
		c.update(9.6)
	end

	-- the two switches. Lanes off: the boost goes, the island base stays.
	c.update(10)
	check("boosted before the switches", hum.WalkSpeed == TOP, hum.WalkSpeed)
	player:SetAttribute(TEST_SWITCH, false)
	flush()
	st = c.status()
	check("lanes off: the boost is gone, the island base stays: exactly 32", hum.WalkSpeed == ISLAND, hum.WalkSpeed)
	check("lanes off: bound for the island base only", st.bound and st.island and not st.boosting)
	check("lanes off: only the island connection", st.connections == idle + WalkBoost.IslandConnections, st.connections)
	check("lanes off: effects removed", effectTotal(char) == 0, effectTotal(char))
	check("lanes off: no modifier state", SpeedModifiers.multiplier(hum) == 1)
	check("lanes off: updates do nothing", c.update(10.1) == 1 and hum.WalkSpeed == ISLAND)
	-- island base off as well: the pre-island speed comes back and nothing is held
	player:SetAttribute(TEST_BASE_SWITCH, false)
	flush()
	st = c.status()
	check("both off: the pre-island speed (16) is back", hum.WalkSpeed == pre, hum.WalkSpeed)
	check("both off: unbound, idle connections only", not st.bound and st.connections == idle, st.connections)
	-- lanes on, island base off: the lanes multiply the speed the humanoid has
	player:SetAttribute(TEST_SWITCH, nil)
	flush()
	st = c.status()
	check("lanes on, island off: bound for the boost only", st.bound and st.boosting and not st.island)
	check("lanes on, island off: WalkSpeed untouched (16)", hum.WalkSpeed == pre, hum.WalkSpeed)
	c.update(10.5)
	check("lanes on, island off: 16 x 1.5 = 24", hum.WalkSpeed == pre * 1.5, hum.WalkSpeed)
	-- island base on again
	player:SetAttribute(TEST_BASE_SWITCH, nil)
	flush()
	st = c.status()
	check("both on again: bound, same connection count", st.bound and st.boosting and st.island, st.connections)
	check("both on again: connection count", st.connections == boundManual, st.connections)
	check("both on again: exactly 32", hum.WalkSpeed == ISLAND, hum.WalkSpeed)
	c.update(11)
	check("both on again: boost works (48)", hum.WalkSpeed == TOP, hum.WalkSpeed)

	-- the state guard on the real humanoid (review M1). Sit and PlatformStand are set the way a
	-- seat or a script sets them; the strip under the root stays in place throughout.
	do
		table.insert(cleanups, function()
			if hum.Parent then
				hum.Sit = false
				hum.PlatformStand = false
			end
		end)
		hrp.AssemblyLinearVelocity = Vector3.new(TOP, 0, 0) -- moving, so a puff would show if allowed
		local puffs = c.status().puffs
		hum.Sit = true
		flush()
		st = c.status()
		check("state guard: sit on a strip: exact base at once, no update", hum.WalkSpeed == ISLAND, hum.WalkSpeed)
		check("state guard: sit: gait drop", st.gait == "drop", st.gait)
		check("state guard: sit: no modifier state", SpeedModifiers.multiplier(hum) == 1)
		c.update(11.5)
		st = c.status()
		check("state guard: seated a frame later: still the island base", hum.WalkSpeed == ISLAND, hum.WalkSpeed)
		check("state guard: seated: over the strip but not counted", st.overStrip and not st.onStrip)
		check("state guard: seated: no dust puff", st.puffs == puffs, st.puffs)
		check("state guard: seated: effects kept, not duplicated", oneSet(char))
		hum.Sit = false
		local stood = waitGait(c, "walk", 3)
		check("state guard: stand up: walking again", stood, c.status().gait)
		c.update(12)
		check("state guard: stand up on the strip: 48", hum.WalkSpeed == TOP, hum.WalkSpeed)

		-- sit, move off the strip, stand up: nothing carried over
		local kept = table.clone(strips)
		hum.Sit = true
		flush()
		table.clear(strips)
		hum.Sit = false
		waitGait(c, "walk", 3)
		c.update(12.1)
		check("state guard: stand up off the strip: exact base", hum.WalkSpeed == ISLAND, hum.WalkSpeed)
		for _, s in kept do
			table.insert(strips, s)
		end

		-- PlatformStand on the strip: not counted, the normal linger and ease
		c.update(13)
		check("state guard: boosted before PlatformStand", hum.WalkSpeed == TOP, hum.WalkSpeed)
		hum.PlatformStand = true
		flush()
		c.update(13.25)
		st = c.status()
		check("state guard: PlatformStand: gait off", st.gait == "off", st.gait)
		check("state guard: PlatformStand +0.25 s: linger holds 48", hum.WalkSpeed == TOP, hum.WalkSpeed)
		c.update(13.75)
		check(
			"state guard: PlatformStand +0.75 s: easing (about 40)",
			approx(hum.WalkSpeed, ISLAND * 1.25, 0.01),
			hum.WalkSpeed
		)
		c.update(14)
		check("state guard: PlatformStand +1.0 s: exactly 32", hum.WalkSpeed == ISLAND, hum.WalkSpeed)
		hum.PlatformStand = false
		local back = waitGait(c, "walk", 3)
		c.update(15)
		check("state guard: PlatformStand off: boost works again", back and hum.WalkSpeed == TOP, hum.WalkSpeed)
		check("state guard: connection count unchanged", c.status().connections == boundManual, c.status().connections)
		hrp.AssemblyLinearVelocity = Vector3.zero
	end

	-- re-entry and overlapping strips: never above 48 or below 32, whatever the sequence
	do
		local rng = Random.new(20261029)
		local now = 200
		local writesBefore = c.status().islandWrites
		local worst, lowest = 0, math.huge
		for _ = 1, 300 do
			now += rng:NextNumber(0, 0.3)
			table.clear(strips)
			for _ = 1, rng:NextInteger(0, 3) do
				table.insert(strips, stripUnder(hrp, hum, true))
			end
			c.update(now)
			worst = math.max(worst, hum.WalkSpeed)
			lowest = math.min(lowest, hum.WalkSpeed)
		end
		check("300 random entries, exits and overlaps: never above 48", worst <= TOP, worst)
		check("300 random entries, exits and overlaps: never below 32", lowest >= ISLAND, lowest)
		check("random entries: the island base is never written again", c.status().islandWrites == writesBefore)
		table.clear(strips)
		c.update(now + 2)
		check("random entries, then away: exactly 32", hum.WalkSpeed == ISLAND, hum.WalkSpeed)
	end

	-- dust puffs (Adam's Design 6), with the test clock at 64 Hz and a velocity on the held root
	do
		local emitter = char:FindFirstChild(WalkBoost.EffectPrefix .. "Dust", true)
		if emitter and emitter:IsA("ParticleEmitter") then
			check("dust: lifetime 0.25 s", emitter.Lifetime.Min == 0.25 and emitter.Lifetime.Max == 0.25)
			local sizeOk = true
			for _, k in emitter.Size.Keypoints do
				sizeOk = sizeOk and k.Value - k.Envelope >= 0.15 - 1e-4 and k.Value + k.Envelope <= 0.35 + 1e-4
			end
			check("dust: size 0.15 to 0.35 stud", sizeOk)
			check("dust: never emits by itself (Rate 0, not Enabled)", emitter.Rate == 0 and not emitter.Enabled)
			local colour = emitter.Color.Keypoints[1].Value
			check("dust: soft sand colour", colour.R > colour.G and colour.G > colour.B and colour.R > 0.7)
			check("dust: opaque-looking at birth", emitter.Transparency.Keypoints[1].Value <= 0.2)
			check("dust: puffs stay where they were made", not emitter.LockedToPart)
		else
			check("dust: the emitter exists", false)
		end
		check("dust: nothing else: one attachment and one emitter, no trails, streaks or glow", oneSet(char))
		player:SetAttribute(WalkBoost.LowGraphicsOverride, nil)
		flush()
		check("dust: the real graphics setting can be read", type(c.status().lowGraphics) == "boolean")
		player:SetAttribute(WalkBoost.LowGraphicsOverride, false)
		flush()

		table.clear(strips)
		table.insert(strips, stripUnder(hrp, hum, true))
		hrp.AssemblyLinearVelocity = Vector3.zero
		local tt, times = runFor(c, 300, 2)
		check("dust: none at rest on the lane", #times == 0, #times)
		check("dust: at rest on the lane the boost is on (48)", hum.WalkSpeed == TOP, hum.WalkSpeed)

		hrp.AssemblyLinearVelocity = Vector3.new(TOP, 0, 0)
		tt, times = runFor(c, tt, 2)
		check("dust: moving along the lane: puffs are made", #times >= 6, #times)
		check("dust: at most 4 a second (no more than 9 in 2 s)", #times <= 9, #times)
		check("dust: puffs are 0.25 s or more apart", minGap(times) >= 0.25 - 1e-6, minGap(times))
		check("dust: any five in a row take 1 s or more", fiveSpan(times) >= 1 - 1e-4, fiveSpan(times))
		check("dust: the speed stays 48", hum.WalkSpeed == TOP, hum.WalkSpeed)
		check("dust: still one set of effects", oneSet(char))

		player:SetAttribute(OVERRIDE, true)
		flush()
		tt, times = runFor(c, tt, 1)
		check("dust: none under Reduced Motion", #times == 0, #times)
		check("dust: Reduced Motion leaves the boost alone (48)", hum.WalkSpeed == TOP, hum.WalkSpeed)
		player:SetAttribute(OVERRIDE, false)
		flush()

		player:SetAttribute(WalkBoost.LowGraphicsOverride, true)
		flush()
		check("dust: low graphics reads as low", c.status().lowGraphics and not c.status().dust)
		tt, times = runFor(c, tt, 1)
		check("dust: none at low graphics detail", #times == 0, #times)
		player:SetAttribute(WalkBoost.LowGraphicsOverride, false)
		flush()

		tt, times = runFor(c, tt, 1)
		check("dust: back once both are off again", #times >= 3, #times)

		hrp.AssemblyLinearVelocity = Vector3.zero
		tt, times = runFor(c, tt, 1)
		check("dust: stops at rest", #times == 0, #times)

		-- exit: moving fast, the lane is left; no puff after that, though the linger keeps 48
		hrp.AssemblyLinearVelocity = Vector3.new(TOP, 0, 0)
		tt = runFor(c, tt, 0.5)
		table.clear(strips)
		tt, times = runFor(c, tt, 0.4)
		check("dust: stops on exit (none after leaving the lane)", #times == 0, #times)
		check("dust: ...while the linger still holds 48", hum.WalkSpeed == TOP, hum.WalkSpeed)

		-- normal 32 walking off the lane: no effect at all
		tt = runFor(c, tt, 1.5)
		check("dust: the boost has eased back to exactly 32", hum.WalkSpeed == ISLAND, hum.WalkSpeed)
		local _, quiet = runFor(c, tt, 2)
		check("dust: none at normal 32 walking off the lane", #quiet == 0, #quiet)
		check("dust: normal walking is exactly 32", hum.WalkSpeed == ISLAND, hum.WalkSpeed)
		hrp.AssemblyLinearVelocity = Vector3.zero
	end

	-- destroy
	c.destroy()
	st = c.status()
	check("destroy: the pre-island speed (16) is back", hum.WalkSpeed == pre, hum.WalkSpeed)
	check("destroy: zero connections", st.connections == 0, st.connections)
	check("destroy: effects removed", effectTotal(char) == 0)
	check("destroy: updates do nothing", c.update(12) == 1 and hum.WalkSpeed == pre)

	-- the built island's strips
	local model = WalkBoost.lanesModel()
	if model then
		local built, hw = WalkBoost.readStrips(model)
		check("built lanes: strips read", #built > 0, #built)
		check("built lanes: half-width", hw > 1 and hw < 4, hw)
		local s = built[1]
		if s and s.y then
			local mid = s.from:Lerp(s.to, 0.5)
			local lift = hum.HipHeight + hrp.Size.Y / 2
			local real = WalkBoost.new({
				manual = true,
				clock = function()
					return t
				end,
				switchAttribute = TEST_SWITCH,
				baseSwitchAttribute = TEST_BASE_SWITCH,
			})
			table.insert(cleanups, real.destroy)
			local look = (s.to - s.from).Unit
			char:PivotTo(
				CFrame.lookAt(
					Vector3.new(mid.X, s.y + lift, -mid.Y),
					Vector3.new(mid.X + look.X, s.y + lift, -mid.Y - look.Y)
				)
			)
			real.update(20)
			check("built strip: on, 48", real.status().onStrip and hum.WalkSpeed == TOP, hum.WalkSpeed)
			check(
				"built strip: watchers added",
				real.status().connections == idle + 1 + WalkBoost.GuardConnections + WalkBoost.StripWatchConnections,
				real.status().connections
			)
			local side = Vector2.new(-look.Y, look.X) * 8
			char:PivotTo(CFrame.new(mid.X + side.X, s.y + lift, -(mid.Y + side.Y)))
			real.update(20.1)
			check("8 studs to the side: off the strip", not real.status().onStrip)
			char:PivotTo(CFrame.new(mid.X, s.y + lift + 30, -mid.Y))
			real.update(20.2)
			check("30 studs above the strip: off", not real.status().onStrip)
			real.update(22)
			check("built strip, after the ease: exactly 32", hum.WalkSpeed == ISLAND, hum.WalkSpeed)
			real.destroy()
			check("built strip controller destroyed: zero connections", real.status().connections == 0)
			check("built strip controller destroyed: the pre-island speed is back", hum.WalkSpeed == pre, hum.WalkSpeed)
		end
		char:PivotTo(home)
	else
		skip("built lanes: Workspace.Lane3_IslandEnvironment.BoostLanes not found")
	end

	for i = #cleanups, 1, -1 do
		cleanups[i]()
	end
	table.clear(cleanups)

	if not respawn then
		skip("respawn: not run (pass { respawn = true })")
		return
	end

	-- respawn
	local r = WalkBoost.new({
		strips = strips,
		manual = true,
		clock = function()
			return t
		end,
		switchAttribute = TEST_SWITCH,
		baseSwitchAttribute = TEST_BASE_SWITCH,
	})
	table.insert(cleanups, r.destroy)
	table.clear(strips)
	table.insert(strips, stripUnder(hrp, hum, false))
	r.update(30)
	check("respawn: island base 32 and boosted 48 before", hum.WalkSpeed == TOP, hum.WalkSpeed)
	-- a client-side reset, as Roblox's own reset does
	hum.Health = 0
	hum:ChangeState(Enum.HumanoidStateType.Dead)
	flush()
	flush()
	st = r.status()
	local writesAtDeath = st.islandWrites
	check("death: unbound", not st.bound)
	check("death: only idle connections", st.connections == idle, st.connections)
	check("death: effects removed", effectTotal(char) == 0)
	local newChar: Model?, newHum: Humanoid?, newRoot: BasePart? = nil, nil, nil
	local started = os.clock()
	while os.clock() - started < 20 do
		local c2, h2, r2 = parts(player, 0.2)
		if c2 and c2 ~= char then
			newChar, newHum, newRoot = c2, h2, r2
			break
		end
	end
	if not (newChar and newHum and newRoot) then
		check("respawn: a new character within 20 s", false)
		return
	end
	local nc, nh, nr = newChar :: Model, newHum :: Humanoid, newRoot :: BasePart
	flush()
	st = r.status()
	check("respawn: bound to the new character", st.bound and st.character == nc)
	check("respawn: same connection count (no duplicates)", st.connections == boundManual, st.connections)
	check("respawn: one set of effects", oneSet(nc))
	check("respawn: island base exactly 32", nh.WalkSpeed == ISLAND, nh.WalkSpeed)
	check("respawn: written exactly once for the new character", st.islandWrites == writesAtDeath + 1, st.islandWrites)
	task.wait(0.5)
	check(
		"respawn: still one write after half a second, still 32",
		r.status().islandWrites == writesAtDeath + 1 and nh.WalkSpeed == ISLAND,
		r.status().islandWrites
	)
	check("respawn: the new character reads as walking", waitGait(r, "walk", 5), r.status().gait)
	table.clear(strips)
	r.update(40)
	check("respawn: fresh state (no boost carried over)", nh.WalkSpeed == ISLAND, nh.WalkSpeed)
	table.insert(strips, stripUnder(nr, nh, false))
	r.update(41)
	check("respawn: boost works (48)", nh.WalkSpeed == TOP, nh.WalkSpeed)
	r.update(41.1)
	check("respawn: boosted again and again, still 48", nh.WalkSpeed == TOP, nh.WalkSpeed)
	r.destroy()
	check("respawn: destroy hands back the pre-island speed (16)", nh.WalkSpeed == pre, nh.WalkSpeed)
	check("respawn: destroy leaves zero connections", r.status().connections == 0)
end

----------------------------------------------------------------------------------------------

-- Runs every group. options.respawn also resets the character (Play mode, client).
function WalkBoostTests.run(options: { respawn: boolean? }?): Report
	local report, checker, skip = newReport()
	logicTests(checker("logic"))
	modifierTests(checker("modifiers"))
	local player = Players.LocalPlayer
	if not (RunService:IsStudio() and RunService:IsClient() and RunService:IsRunning() and player) then
		skip("character", "all", "needs Studio Play mode, client side")
		return report
	end
	local names = {
		WalkBoost.SwitchAttribute,
		WalkBoost.BaseSwitchAttribute,
		TEST_SWITCH,
		TEST_BASE_SWITCH,
		WalkBoost.TakeoverAttribute,
		WalkBoost.LowGraphicsOverride,
		OVERRIDE,
	}
	local saved: Saved = {}
	for _, name in names do
		saved[name] = player:GetAttribute(name)
	end
	local check = checker("character")
	local cleanups: { () -> () } = {}
	local ok, err = pcall(characterTests, check, function(why: string)
		skip("character", why, "skipped")
	end, options ~= nil and options.respawn == true, cleanups)
	if not ok then
		check("ran without an error", false, err)
	end
	for i = #cleanups, 1, -1 do
		pcall(cleanups[i])
	end
	for _, name in names do
		player:SetAttribute(name, saved[name])
	end
	return report
end

-- A printable summary.
function WalkBoostTests.text(report: Report): string
	local lines = {
		string.format(
			"WalkBoost tests: %d passed, %d failed, %d skipped",
			report.passed,
			report.failed,
			report.skipped
		),
	}
	for _, r in report.results do
		local mark = if r.ok == nil then "SKIP" elseif r.ok then "ok  " else "FAIL"
		table.insert(
			lines,
			string.format("%s [%s] %s%s", mark, r.group, r.name, if r.detail then " = " .. r.detail else "")
		)
	end
	return table.concat(lines, "\n")
end

return WalkBoostTests
