--!strict
-- DEVELOPMENT TESTS for the island walking boost (Lane 3). Nothing requires this module; it runs
-- only when a developer calls it. Spec: vault/design/specs/walk-boost.md.
--
-- Three groups:
--   logic      WalkBoostLogic, pure: numbers, geometry, height band, the state machine as a
--              function of time and on-strip samples (fixed and seeded random sample sequences).
--   modifiers  SpeedModifiers on a stand-alone Humanoid (not in a character): max-wins, no
--              stacking, exact base restore, someone else's base kept, cleanup.
--   character  Studio Play mode, client: WalkBoost controllers on the real local character, with
--              a test clock and test strips (deterministic), then once over a strip of the built
--              island. Covers enter, linger and ease, no stacking, effects and reduced motion,
--              takeover, runtime disable, destroy, and (option respawn) a respawn.
-- The live boost is switched off (LocalPlayer "Lane3WalkBoostEnabled" = false) while the character
-- group runs; every attribute, the root's anchoring, position and WalkSpeed are put back after.
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
local OVERRIDE = "Lane3ReducedMotionOverride"
local EPS = 1e-6

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
	check("16 boosted is 24", 16 * M == 24)

	-- multiplierAt
	check("never on a strip: 1", L.multiplierAt(5, nil) == 1)
	for _, since in { 0, 0.1, 0.25, 0.4999, LINGER } do
		check("linger at +" .. since .. " s: full", L.multiplierAt(10 + since, 10) == M)
	end
	check("clock backwards: full", L.multiplierAt(9, 10) == M)
	check("ease midpoint (+0.75 s): 1.25", approx(L.multiplierAt(10.75, 10), 1.25, EPS), L.multiplierAt(10.75, 10))
	check("just after the linger: below full", L.multiplierAt(10 + LINGER + 0.001, 10) < M)
	check("end of ease (+1.0 s): exactly 1", L.multiplierAt(10 + LINGER + EASE, 10) == 1)
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
end

----------------------------------------------------------------------------------------------
-- modifiers

local function flush()
	task.wait() -- lets deferred property-changed events run
end

local function modifierTests(check: Checker)
	local S = SpeedModifiers
	check("combine: none is 1", S.combine({}) == 1)
	check("combine: largest wins", S.combine({ a = 1.5, b = 1.2 }) == 1.5)
	check("combine: clamped to 1.5", S.combine({ a = 3 }) == 1.5)
	check("combine: a slow alone", S.combine({ a = 0.5 }) == 0.5)

	local before = S.stats()
	local h = Instance.new("Humanoid")
	h.WalkSpeed = 16
	S.set(h, "A", 1.5)
	check("set 1.5: 24", h.WalkSpeed == 24, h.WalkSpeed)
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
	check("boost on a faster base 20 stops at the cap 24", h.WalkSpeed == 24, h.WalkSpeed)
	S.clear(h, "A")
	check("clear: their 20 stays, not our old 16", h.WalkSpeed == 20, h.WalkSpeed)
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

local function oneSet(character: Instance): boolean
	local c = effectCounts(character)
	return c.Attachment == 6 and c.Trail == 2 and c.ParticleEmitter == 1 and c.PointLight == 1
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

	-- switch the live boost off for the test, and check that switch on the way
	player:SetAttribute(WalkBoost.SwitchAttribute, false)
	player:SetAttribute(TEST_SWITCH, nil)
	player:SetAttribute(WalkBoost.TakeoverAttribute, nil)
	player:SetAttribute(OVERRIDE, false)
	flush()
	flush()
	local base = hum.WalkSpeed
	check("live boost switched off: no effects on the character", effectTotal(char) == 0, effectTotal(char))
	check("live boost switched off: status attribute removed", player:GetAttribute(WalkBoost.PublishAttribute) == nil)
	check("base WalkSpeed is the default 16", base == 16, base)

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
	})
	table.insert(cleanups, c.destroy)
	local idle = WalkBoost.IdleConnections
	local boundManual = idle + 1

	local st = c.status()
	check("bound to the character", st.bound and st.character == char)
	check("bound: connection count", st.connections == boundManual, st.connections)
	check("one set of effects", oneSet(char))
	check("off the strip: base", c.update(0) == 1 and hum.WalkSpeed == base, hum.WalkSpeed)

	-- enter
	table.insert(strips, stripUnder(hrp, hum, true))
	c.update(0.1)
	check("enter: WalkSpeed 24", hum.WalkSpeed == base * 1.5, hum.WalkSpeed)
	c.update(0.1)
	c.update(0.1)
	check("repeat samples: still 24", hum.WalkSpeed == base * 1.5, hum.WalkSpeed)
	table.insert(strips, stripUnder(hrp, hum, true))
	c.update(0.2)
	check("two overlapping strips: still 24", hum.WalkSpeed == base * 1.5, hum.WalkSpeed)
	for f = 1, 60 do
		c.update(0.2 + f / 60)
	end
	check("a second on the strip: still 24", hum.WalkSpeed == base * 1.5, hum.WalkSpeed)
	local leftAt = 0.2 + 60 / 60

	-- effects, full motion (moving: the anchored root is given a velocity)
	hrp.AssemblyLinearVelocity = Vector3.new(16 * 1.5, 0, 0)
	c.update(leftAt)
	st = c.status()
	check("full motion: wind trails on", st.trails)
	check("full motion: streaks emitting", st.streaksEnabled and st.streakRate > 0, st.streakRate)
	check("full motion: glow", st.glow > 0, st.glow)
	-- reduced motion mid-boost, applied on the attribute event (no update call)
	player:SetAttribute(OVERRIDE, true)
	flush()
	st = c.status()
	check("reduced motion: no trails", not st.trails)
	check("reduced motion: no particles", not st.streaksEnabled and st.streakRate == 0, st.streakRate)
	check("reduced motion: steady glow kept", st.glow > 0, st.glow)
	c.update(leftAt)
	st = c.status()
	check("reduced motion after a frame: still no particles", not st.streaksEnabled and st.streakRate == 0)
	check("reduced motion: boost unchanged", hum.WalkSpeed == base * 1.5)
	player:SetAttribute(OVERRIDE, false)
	flush()
	c.update(leftAt)
	check("full motion back: trails on", c.status().trails)
	hrp.AssemblyLinearVelocity = Vector3.zero
	check("effects not duplicated", oneSet(char))

	-- leave: linger, then ease
	table.clear(strips)
	c.update(leftAt + 0.25)
	check("left +0.25 s: still 24", hum.WalkSpeed == base * 1.5, hum.WalkSpeed)
	c.update(leftAt + 0.5)
	check("left +0.5 s: still 24 (end of linger)", hum.WalkSpeed == base * 1.5, hum.WalkSpeed)
	c.update(leftAt + 0.75)
	check("left +0.75 s: easing (about 20)", approx(hum.WalkSpeed, base * 1.25, 0.01), hum.WalkSpeed)
	c.update(leftAt + 0.95)
	check("left +0.95 s: nearly back", hum.WalkSpeed > base and hum.WalkSpeed < base + 0.4, hum.WalkSpeed) -- smoothstep at 90 % of the ease: 1.014 x = 16.22
	c.update(leftAt + 1.0)
	check("left +1.0 s: exactly 16", hum.WalkSpeed == base, hum.WalkSpeed)
	check("back at base: no modifier state left", SpeedModifiers.multiplier(hum) == 1)

	-- re-enter during the ease
	table.insert(strips, stripUnder(hrp, hum, true))
	c.update(5)
	table.clear(strips)
	c.update(5.7)
	table.insert(strips, stripUnder(hrp, hum, true))
	c.update(5.8)
	check("re-enter while easing: 24, not more", hum.WalkSpeed == base * 1.5, hum.WalkSpeed)

	-- someone else sets a base while boosted (their value is kept after)
	hum.WalkSpeed = 20
	flush()
	c.update(5.9)
	check("someone else's base 20, boosted: capped at 24", hum.WalkSpeed == 24, hum.WalkSpeed)
	table.clear(strips)
	c.update(7)
	check("their base 20 comes back, not 16", hum.WalkSpeed == 20, hum.WalkSpeed)
	hum.WalkSpeed = base
	flush()

	-- takeover
	table.insert(strips, stripUnder(hrp, hum, true))
	c.update(8)
	player:SetAttribute(WalkBoost.TakeoverAttribute, "WalkBoostTest")
	flush()
	st = c.status()
	check("takeover: stands aside (unbound)", not st.bound and st.takenOver)
	check("takeover: exact base back", hum.WalkSpeed == base, hum.WalkSpeed)
	check("takeover: effects removed", effectTotal(char) == 0, effectTotal(char))
	check("takeover: only idle connections", st.connections == idle, st.connections)
	check("takeover: updates do nothing", c.update(8.1) == 1 and hum.WalkSpeed == base, hum.WalkSpeed)
	player:SetAttribute(WalkBoost.TakeoverAttribute, nil)
	flush()
	c.update(9)
	check("takeover ended: boost works again", hum.WalkSpeed == base * 1.5, hum.WalkSpeed)
	check("takeover ended: one set of effects", oneSet(char))

	-- consumer mode for a movement system: computes, never writes
	do
		player:SetAttribute(WalkBoost.TakeoverAttribute, "WalkBoostTest")
		flush()
		local seen: number? = nil
		local consumer = WalkBoost.new({
			strips = strips,
			manual = true,
			clock = function()
				return t
			end,
			switchAttribute = TEST_SWITCH,
			write = false,
			effects = false,
			respectTakeover = false,
		})
		local conn = consumer.Changed:Connect(function(m: number)
			seen = m
		end)
		local m = consumer.update(9.5)
		check("consumer: reports 1.5", m == 1.5 and seen == 1.5, m)
		check("consumer: WalkSpeed untouched", hum.WalkSpeed == base, hum.WalkSpeed)
		conn:Disconnect()
		consumer.destroy()
		check("consumer destroyed: no connections", consumer.status().connections == 0)
		player:SetAttribute(WalkBoost.TakeoverAttribute, nil)
		flush()
		c.update(9.6)
	end

	-- runtime disable mid-boost
	c.update(10)
	check("boosted before disable", hum.WalkSpeed == base * 1.5)
	player:SetAttribute(TEST_SWITCH, false)
	flush()
	st = c.status()
	check("disable: exact base at once", hum.WalkSpeed == base, hum.WalkSpeed)
	check("disable: unbound", not st.bound)
	check("disable: only idle connections", st.connections == idle, st.connections)
	check("disable: effects removed", effectTotal(char) == 0, effectTotal(char))
	check("disable: no modifier state", SpeedModifiers.multiplier(hum) == 1)
	check("disable: updates do nothing", c.update(10.1) == 1 and hum.WalkSpeed == base)
	player:SetAttribute(TEST_SWITCH, nil)
	flush()
	st = c.status()
	check("enable again: bound, same connection count", st.bound and st.connections == boundManual, st.connections)
	c.update(11)
	check("enable again: boost works", hum.WalkSpeed == base * 1.5, hum.WalkSpeed)

	-- destroy
	c.destroy()
	st = c.status()
	check("destroy: exact base", hum.WalkSpeed == base, hum.WalkSpeed)
	check("destroy: zero connections", st.connections == 0, st.connections)
	check("destroy: effects removed", effectTotal(char) == 0)
	check("destroy: updates do nothing", c.update(12) == 1 and hum.WalkSpeed == base)

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
			check("built strip: on, 24", real.status().onStrip and hum.WalkSpeed == base * 1.5, hum.WalkSpeed)
			check(
				"built strip: watchers added",
				real.status().connections == idle + 1 + WalkBoost.StripWatchConnections,
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
			check("built strip, after the ease: exactly 16", hum.WalkSpeed == base, hum.WalkSpeed)
			real.destroy()
			check("built strip controller destroyed: zero connections", real.status().connections == 0)
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
	})
	table.insert(cleanups, r.destroy)
	table.clear(strips)
	table.insert(strips, stripUnder(hrp, hum, false))
	r.update(30)
	check("respawn: boosted before", hum.WalkSpeed == base * 1.5, hum.WalkSpeed)
	-- a client-side reset, as Roblox's own reset does
	hum.Health = 0
	hum:ChangeState(Enum.HumanoidStateType.Dead)
	flush()
	flush()
	st = r.status()
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
	check("respawn: base speed", nh.WalkSpeed == base, nh.WalkSpeed)
	table.clear(strips)
	r.update(40)
	check("respawn: fresh state (no boost carried over)", nh.WalkSpeed == base, nh.WalkSpeed)
	table.insert(strips, stripUnder(nr, nh, false))
	r.update(41)
	check("respawn: boost works (24)", nh.WalkSpeed == base * 1.5, nh.WalkSpeed)
	r.destroy()
	check("respawn: destroy leaves the base", nh.WalkSpeed == base, nh.WalkSpeed)
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
	local names = { WalkBoost.SwitchAttribute, TEST_SWITCH, WalkBoost.TakeoverAttribute, OVERRIDE }
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
