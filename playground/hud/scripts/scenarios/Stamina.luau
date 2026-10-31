--!strict
-- PLAYGROUND ONLY (Lane 3 Round 3, R3-S1 / R3-S2 / R3-F15 / R3-F4): the Stamina meter's presentation. Every value is a
-- synthetic fixture played through the preview store (the StaminaFixture stand-in; the rule is Lane 1's and is not
-- decided). Nothing here spends, saves or ends a run. Each check logs a PASS or FAIL line (grep them); the first few
-- also log the numbers they compared. Stamina is OFF by default: every scenario switches it on and back off.
--
--   Stamina: thresholds (pure function)      stateFor over every value of a maximum of 10, the nine boundaries the brief
--                                            names (both directions), other maxima, clamps and bad input
--   Stamina: thresholds on the live meter    10 -> 6 -> 5 -> 4 -> 3 -> 1 -> 0 and back up 0 -> 1 -> 3 -> 4 -> 5 -> 6: state,
--                                            colour, number, lit pips, words, glow, the Hop button's unavailable flag
--   Stamina: pips and number match           lit pips = the value and the number = the value for 0..10 both ways, and the
--                                            grouped pips for a maximum of 20 ("17 / 20")
--   Stamina: transitions do not accumulate tweens   40 rapid changes across every state: live tweens stay bounded and
--                                            settle to 0 (or to the one glow loop in Red), no instance growth
--   Stamina: red glow is one loop, reduced motion is steady   Red pulses with ONE looping tween; Reduce Motion makes the
--                                            glow steady and strong, with no tween and no pip/number animation
--   Stamina: zero state                      grey, cracked, OUT OF STAMINA, pips hidden, Hop unavailable, the run goes on
--   Stamina: empty taps are throttled        rapid taps on the empty Hop button: one warning and one sound per 1.5 s
--   Stamina: thumb clearance on every frame  the drawn content (not just the rectangle) against the reserved thumbstick
--                                            zone on all six frames, three states, two ways of measuring; the remaining
--                                            overlap in px is FAIL
--   Stamina: nothing left after destroy      a second meter built and destroyed: no instance, connection, tween or thread
--   Stamina: no hop streak                   no streak field and no STREAK text anywhere while hops are accepted
--   Stamina: tour (review shots)             every state held for two seconds (no checks; for captures)

local Players = game:GetService("Players")

local Prototype = Players.LocalPlayer
	:WaitForChild("PlayerScripts")
	:WaitForChild("Client")
	:WaitForChild("UI")
	:WaitForChild("Prototype")
local Motion = require(Prototype:WaitForChild("Motion"))
local Sounds = require(Prototype:WaitForChild("Sounds"))
local Run = Prototype:WaitForChild("Run")
local RunBus = require(Run:WaitForChild("RunBus"))
local RunLayout = require(Run:WaitForChild("RunLayout"))
local StaminaMeter = require(Run:WaitForChild("StaminaMeter"))

type Host = { [string]: any }

local function verdict(host: Host, name: string, ok: boolean, detail: string)
	host.log(string.format("%s %s: %s", if ok then "PASS" else "FAIL", name, detail))
end

local function comp(host: Host, key: string): any
	return host.api.components and host.api.components[key]
end

local function dbg(host: Host, key: string): { [string]: any }
	local c = comp(host, key)
	return if c and c.getDebugState then c:getDebugState() else {}
end

local function meterDebug(host: Host): { [string]: any }
	return dbg(host, "stamina")
end

-- A clean run with the Stamina demo on at a full meter, motion forced ON (an animated check must not depend on this
-- machine's Reduce Motion setting).
local function begin(host: Host, max: number?)
	Motion.setOverride(false)
	host.api.setStamina(true, max or 10)
	host.api.setStaminaRestore(false)
	if host.store:get().mode == "Run" then
		host.store:setMode("Home")
	end
	host.enterRun()
	host.wait(0.6)
	host.api.resetStamina()
	host.wait(0.3)
end

local function finish(host: Host)
	Motion.setOverride(nil)
	host.api.setStamina(false)
end

local function setValue(host: Host, value: number)
	host.api.stamina:setValue(value)
end

local S: { [string]: (Host) -> () } = {}

----------------------------------------------------------------------------------------------------------------------
-- the pure function

S["Stamina: thresholds (pure function)"] = function(host: Host)
	-- the whole table for a maximum of 10
	local expected = {
		[0] = "Empty",
		[1] = "Red",
		[2] = "Red",
		[3] = "Red",
		[4] = "Orange",
		[5] = "Orange",
		[6] = "Normal",
		[7] = "Normal",
		[8] = "Normal",
		[9] = "Normal",
		[10] = "Normal",
	}
	local wrong = {}
	for v = 0, 10 do
		if StaminaMeter.stateFor(v, 10) ~= expected[v] then
			table.insert(wrong, string.format("%d gave %s (wanted %s)", v, StaminaMeter.stateFor(v, 10), expected[v]))
		end
	end
	verdict(
		host,
		"stateFor(0..10, 10)",
		#wrong == 0,
		if #wrong == 0 then "all eleven values as specified" else table.concat(wrong, "; ")
	)

	-- the boundaries the brief names, each as a pair (down, and the reverse)
	local boundaries: { { any } } = {
		{ 10, 6, "Normal", "Normal", "10 -> 6 stays normal yellow" },
		{ 6, 5, "Normal", "Orange", "6 -> 5 Normal -> Orange" },
		{ 5, 4, "Orange", "Orange", "5 -> 4 stays orange" },
		{ 4, 3, "Orange", "Red", "4 -> 3 Orange -> Red" },
		{ 3, 1, "Red", "Red", "3 -> 1 stays red (1 to 3 is red, the 5-or-fewer idea does not override it)" },
		{ 1, 0, "Red", "Empty", "1 -> 0 Red -> Empty" },
		{ 0, 1, "Empty", "Red", "0 -> 1 replenish Empty -> Red" },
		{ 3, 4, "Red", "Orange", "3 -> 4 replenish Red -> Orange" },
		{ 5, 6, "Orange", "Normal", "5 -> 6 replenish Orange -> Normal" },
	}
	for _, p in boundaries do
		local a, b = StaminaMeter.stateFor(p[1], 10), StaminaMeter.stateFor(p[2], 10)
		verdict(
			host,
			"boundary " .. p[5],
			a == p[3] and b == p[4],
			string.format("%d is %s, %d is %s", p[1], a, p[2], b)
		)
	end

	-- other maxima scale by the same 60% / 40% lines (integer arithmetic, so no rounding at a boundary)
	local scaled = {
		{ 20, 20, "Normal" },
		{ 12, 20, "Normal" },
		{ 11, 20, "Orange" },
		{ 8, 20, "Orange" },
		{ 7, 20, "Red" },
		{ 1, 20, "Red" },
		{ 0, 20, "Empty" },
		{ 3, 5, "Normal" },
		{ 2, 5, "Orange" },
		{ 1, 5, "Red" },
		{ 1, 1, "Normal" },
		{ 0, 1, "Empty" },
	}
	local scaledWrong = {}
	for _, c in scaled do
		local got = StaminaMeter.stateFor(c[1], c[2])
		if got ~= c[3] then
			table.insert(scaledWrong, string.format("%d of %d gave %s (wanted %s)", c[1], c[2], got, c[3]))
		end
	end
	verdict(
		host,
		"stateFor with other maxima (20, 5, 1)",
		#scaledWrong == 0,
		if #scaledWrong == 0 then "all as specified" else table.concat(scaledWrong, "; ")
	)

	-- clamps and bad input: never an error, never a state outside the four
	local odd = {
		{ -3, 10, "Empty" },
		{ 99, 10, "Normal" },
		{ 5.9, 10, "Orange" }, -- floored to 5
		{ 6.1, 10, "Normal" },
		{ 0 / 0, 10, "Empty" }, -- NaN value
		{ 3, 0, "Normal" }, -- a maximum below 1 counts as 1
		{ 0, 0 / 0, "Empty" },
	}
	local oddWrong = {}
	for _, c in odd do
		local got = StaminaMeter.stateFor(c[1], c[2])
		if got ~= c[3] then
			table.insert(
				oddWrong,
				string.format("%s of %s gave %s (wanted %s)", tostring(c[1]), tostring(c[2]), got, c[3])
			)
		end
	end
	verdict(
		host,
		"stateFor clamps and bad input",
		#oddWrong == 0,
		if #oddWrong == 0 then "negative, above max, fractions, NaN, zero max" else table.concat(oddWrong, "; ")
	)
end

----------------------------------------------------------------------------------------------------------------------
-- the live meter

S["Stamina: thresholds on the live meter"] = function(host: Host)
	host.api.setProfile("Desktop")
	begin(host)
	-- (value to set, the state it must show, the label)
	local steps = {
		{ 6, "Normal", "10 -> 6" },
		{ 5, "Orange", "6 -> 5 (Normal -> Orange)" },
		{ 4, "Orange", "5 -> 4" },
		{ 3, "Red", "4 -> 3 (Orange -> Red)" },
		{ 1, "Red", "3 -> 1" },
		{ 0, "Empty", "1 -> 0 (Red -> Empty)" },
		{ 1, "Red", "0 -> 1 (replenish)" },
		{ 3, "Red", "1 -> 3" },
		{ 4, "Orange", "3 -> 4 (replenish)" },
		{ 5, "Orange", "4 -> 5" },
		{ 6, "Normal", "5 -> 6 (replenish)" },
		{ 10, "Normal", "6 -> 10" },
	}
	local first = meterDebug(host)
	verdict(
		host,
		"start: 10 is Normal",
		first.state == "Normal" and first.number == "10" and first.pipsLit == 10,
		string.format(
			"state %s, number %s, lit %s",
			tostring(first.state),
			tostring(first.number),
			tostring(first.pipsLit)
		)
	)
	local tints: { [string]: string } = { Normal = tostring(first.tint) }
	for _, step in steps do
		local value, want, label = step[1], step[2], step[3]
		setValue(host, value)
		host.wait(0.3)
		local d = meterDebug(host)
		local hop = dbg(host, "hop")
		local wantWord = if want == "Red" then "LOW STAMINA" elseif want == "Empty" then "OUT OF STAMINA" else ""
		local hopOut = hop.display == "OutOfStamina" or hop.outOfStamina == true
		local red = want == "Red"
		local ok = d.state == want
			and d.mode == want
			and StaminaMeter.stateFor(value, 10) == want
			and d.number == tostring(value)
			and d.pipsLit == value
			and d.word == wantWord
			and d.hopUnavailable == (want == "Empty")
			and hopOut == (want == "Empty")
			and d.glowShown == red
			and d.pulsing == red
		tints[want] = tostring(d.tint)
		verdict(
			host,
			"live " .. label,
			ok,
			string.format(
				"state %s, tint %s, number %s, lit %s, word %q, glow %s pulsing %s, hop unavailable %s (button %s)",
				tostring(d.state),
				tostring(d.tint),
				tostring(d.number),
				tostring(d.pipsLit),
				tostring(d.word),
				tostring(d.glowShown),
				tostring(d.pulsing),
				tostring(d.hopUnavailable),
				tostring(hop.display)
			)
		)
	end
	local seen = {}
	local distinct = true
	for _, name in { "Normal", "Orange", "Red", "Empty" } do
		local t = tints[name]
		if t == nil or seen[t] then
			distinct = false
		end
		seen[t or name] = true
	end
	verdict(
		host,
		"the four states have four different colours",
		distinct,
		string.format(
			"Normal %s, Orange %s, Red %s, Empty %s",
			tostring(tints.Normal),
			tostring(tints.Orange),
			tostring(tints.Red),
			tostring(tints.Empty)
		)
	)
	finish(host)
end

S["Stamina: pips and number match"] = function(host: Host)
	host.api.setProfile("Desktop")
	begin(host)
	local bad = {}
	for _, direction in { -1, 1 } do
		local from, to = if direction < 0 then 10 else 0, if direction < 0 then 0 else 10
		for v = from, to, direction do
			setValue(host, v)
			host.wait(0.12)
			local d = meterDebug(host)
			if d.pips ~= 10 or d.pipsLit ~= v or d.number ~= tostring(v) or d.value ~= v then
				table.insert(
					bad,
					string.format(
						"%d: pips %s lit %s number %q",
						v,
						tostring(d.pips),
						tostring(d.pipsLit),
						tostring(d.number)
					)
				)
			end
		end
	end
	verdict(
		host,
		"max 10: ten pips, lit = value, number = value (10 down to 0 and back)",
		#bad == 0,
		if #bad == 0 then "22 readings agree" else table.concat(bad, "; ")
	)

	-- a larger maximum: still ten pips, each standing for two units, and the number keeps the exact value
	host.api.setStamina(true, 20)
	host.wait(0.3)
	local cases = {
		{ 20, "20 / 20", 10 },
		{ 17, "17 / 20", 9 },
		{ 12, "12 / 20", 6 },
		{ 8, "8 / 20", 4 },
		{ 1, "1 / 20", 1 },
		{ 0, "0 / 20", 0 },
	}
	local bad20 = {}
	for _, c in cases do
		setValue(host, c[1])
		host.wait(0.15)
		local d = meterDebug(host)
		if d.pips ~= 10 or d.number ~= c[2] or d.pipsLit ~= c[3] or d.unitsPerPip ~= 2 then
			table.insert(
				bad20,
				string.format(
					"%d: number %q lit %s units %s",
					c[1],
					tostring(d.number),
					tostring(d.pipsLit),
					tostring(d.unitsPerPip)
				)
			)
		end
	end
	verdict(
		host,
		"max 20: ten pips of two units, exact number",
		#bad20 == 0,
		if #bad20 == 0 then "20, 17, 12, 8, 1 and 0 agree" else table.concat(bad20, "; ")
	)
	host.api.setStamina(true, 10)
	finish(host)
end

S["Stamina: transitions do not accumulate tweens"] = function(host: Host)
	host.api.setProfile("Desktop")
	begin(host)
	local before = meterDebug(host)
	local cycle = { 10, 7, 5, 3, 2, 0, 1, 4, 6, 9 }
	local peak, changes = 0, 0
	for i = 1, 40 do
		setValue(host, cycle[(i - 1) % #cycle + 1])
		changes += 1
		host.wait(0.03)
		peak = math.max(peak, meterDebug(host).activeTweens :: number)
	end
	local burst = meterDebug(host)
	-- one tween per pip (10), one for the number, one for the bolt, one for the word, one glow loop
	verdict(
		host,
		"40 rapid changes keep the live tweens bounded",
		peak <= 14 and (burst.drains + burst.refills) > 0,
		string.format(
			"peak %d live tweens over %d changes (limit 14), %d drains + %d refills animated",
			peak,
			changes,
			burst.drains,
			burst.refills
		)
	)
	setValue(host, 2)
	host.wait(0.9)
	local red = meterDebug(host)
	verdict(
		host,
		"settled in Red: exactly the one glow loop",
		red.activeTweens == 1 and red.pulsing == true,
		string.format("%d live tween(s), pulsing %s", red.activeTweens, tostring(red.pulsing))
	)
	setValue(host, 8)
	host.wait(0.9)
	local calm = meterDebug(host)
	verdict(
		host,
		"settled in Normal: no tween left, no glow",
		calm.activeTweens == 0 and calm.pulsing == false and calm.glowShown == false,
		string.format(
			"%d live tween(s), pulsing %s, glow %s",
			calm.activeTweens,
			tostring(calm.pulsing),
			tostring(calm.glowShown)
		)
	)
	verdict(
		host,
		"no instance, thread or connection growth over the burst",
		calm.instances == before.instances and calm.threads == 0 and calm.connections == before.connections,
		string.format(
			"instances %d -> %d, threads %d, connections %d -> %d",
			before.instances,
			calm.instances,
			calm.threads,
			before.connections,
			calm.connections
		)
	)
	finish(host)
end

S["Stamina: red glow is one loop, reduced motion is steady"] = function(host: Host)
	host.api.setProfile("Desktop")
	begin(host)
	setValue(host, 2)
	host.wait(0.5)
	local low, high = 1, 0
	local last = meterDebug(host)
	for _ = 1, 22 do
		last = meterDebug(host)
		low = math.min(low, last.glowTransparency :: number)
		high = math.max(high, last.glowTransparency :: number)
		host.wait(0.1)
	end
	verdict(
		host,
		"Red with motion: a calm pulse from one looping tween",
		last.pulsing == true and last.glowShown == true and last.activeTweens == 1 and (high - low) > 0.1,
		string.format("glow transparency %.2f to %.2f over 2.2 s, %d live tween(s)", low, high, last.activeTweens)
	)

	-- Reduce Motion: a steady strong glow, static words, no animation of any kind
	Motion.setOverride(true)
	host.wait(0.9)
	local a = meterDebug(host)
	host.wait(1.0)
	local b = meterDebug(host)
	verdict(
		host,
		"Red in reduced motion: steady strong glow, no tween",
		a.reducedMotion == true
			and a.pulsing == false
			and a.activeTweens == 0
			and a.glowShown == true
			and a.glowTransparency == b.glowTransparency
			and (a.glowTransparency :: number) <= 0.5
			and a.word == "LOW STAMINA",
		string.format(
			"reduced %s, pulsing %s, %d tween(s), glow %.2f then %.2f, word %q",
			tostring(a.reducedMotion),
			tostring(a.pulsing),
			a.activeTweens,
			a.glowTransparency,
			b.glowTransparency,
			tostring(a.word)
		)
	)
	for _, v in { 1, 3, 0, 5, 2, 10 } do
		setValue(host, v)
		host.wait(0.12)
	end
	local c = meterDebug(host)
	verdict(
		host,
		"value changes in reduced motion animate nothing",
		c.drains == a.drains
			and c.refills == a.refills
			and c.activeTweens == 0
			and c.state == "Normal"
			and c.number == "10",
		string.format(
			"drains %d -> %d, refills %d -> %d, %d tween(s), %s %s",
			a.drains,
			c.drains,
			a.refills,
			c.refills,
			c.activeTweens,
			tostring(c.state),
			tostring(c.number)
		)
	)
	setValue(host, 2)
	host.wait(0.4)
	local d = meterDebug(host)
	verdict(
		host,
		"back in Red (reduced): still steady",
		d.pulsing == false and d.activeTweens == 0 and d.glowShown == true,
		string.format("pulsing %s, %d tween(s), glow %s", tostring(d.pulsing), d.activeTweens, tostring(d.glowShown))
	)
	-- and with motion on again the loop returns
	Motion.setOverride(false)
	host.wait(0.9)
	local e = meterDebug(host)
	verdict(
		host,
		"motion on again: the one loop returns",
		e.reducedMotion == false and e.pulsing == true and e.activeTweens == 1,
		string.format(
			"reduced %s, pulsing %s, %d tween(s)",
			tostring(e.reducedMotion),
			tostring(e.pulsing),
			e.activeTweens
		)
	)
	finish(host)
end

S["Stamina: zero state"] = function(host: Host)
	for _, profile in { "Desktop", "PhoneLandscape" } do
		host.api.setProfile(profile)
		begin(host)
		setValue(host, 0)
		host.wait(0.5)
		local d = meterDebug(host)
		local hop = dbg(host, "hop")
		verdict(
			host,
			profile .. ": zero shows the depleted state and the reason",
			d.state == "Empty"
				and d.number == "0"
				and d.word == "OUT OF STAMINA"
				and d.pipsLit == 0
				and d.pipsVisible == false
				and d.glowShown == false
				and d.pulsing == false,
			string.format(
				"state %s, number %s, word %q, lit %s, pips visible %s, glow %s",
				tostring(d.state),
				tostring(d.number),
				tostring(d.word),
				tostring(d.pipsLit),
				tostring(d.pipsVisible),
				tostring(d.glowShown)
			)
		)
		verdict(
			host,
			profile .. ": zero reports Hop unavailable (the button reads the same store value)",
			d.hopUnavailable == true and (hop.display == "OutOfStamina" or hop.outOfStamina == true),
			string.format(
				"meter flag %s, button display %s, button flag %s",
				tostring(d.hopUnavailable),
				tostring(hop.display),
				tostring(hop.outOfStamina)
			)
		)
		-- no new rule: the ride goes on, nothing ends the run
		host.runPatch({ distance = 400 })
		host.wait(2.5)
		local run = host.store:get().run
		verdict(
			host,
			profile .. ": the run continues at zero (no forced end)",
			host.store:get().mode == "Run" and run ~= nil and run.stamina ~= nil and run.stamina.value == 0,
			string.format(
				"mode %s, value %s",
				tostring(host.store:get().mode),
				tostring(run and run.stamina and run.stamina.value)
			)
		)
		setValue(host, 1)
		host.wait(0.4)
		local up = meterDebug(host)
		local hopUp = dbg(host, "hop")
		verdict(
			host,
			profile .. ": one Stamina back = Red, Hop available again",
			up.state == "Red" and up.hopUnavailable == false and hopUp.display ~= "OutOfStamina",
			string.format(
				"state %s, meter flag %s, button display %s",
				tostring(up.state),
				tostring(up.hopUnavailable),
				tostring(hopUp.display)
			)
		)
		finish(host)
	end
	host.api.setProfile("Desktop")
end

S["Stamina: empty taps are throttled"] = function(host: Host)
	host.api.setProfile("Desktop")
	begin(host)
	local meter = comp(host, "stamina")
	setValue(host, 0)
	host.wait(1.7) -- a fresh throttle window
	local base = meterDebug(host)
	local fxBase = host.api.staminaDebug().counts.emptyTaps
	local soundBase = Sounds.counts().Warning or 0

	-- twenty taps in under a second, the way a panicking child taps
	for _ = 1, 20 do
		host.emit("HopRejected", { reason = "OutOfStamina" })
		host.wait(0.03)
	end
	local a = meterDebug(host)
	local soundsA = (Sounds.counts().Warning or 0) - soundBase
	verdict(
		host,
		"20 rapid taps: one warning and one sound",
		a.emptyTaps - base.emptyTaps == 20
			and a.emptyWarnings - base.emptyWarnings == 1
			and a.emptySounds - base.emptySounds == 1
			and a.emptyThrottled - base.emptyThrottled == 19
			and soundsA == 1,
		string.format(
			"taps %d, warnings %d, sounds %d (Sounds.play Warning calls %d), throttled %d",
			a.emptyTaps - base.emptyTaps,
			a.emptyWarnings - base.emptyWarnings,
			a.emptySounds - base.emptySounds,
			soundsA,
			a.emptyThrottled - base.emptyThrottled
		)
	)
	-- the direct call (what the Hop button may use) shares the same window
	local played = 0
	for _ = 1, 6 do
		if meter:emptyTap() then
			played += 1
		end
	end
	verdict(
		host,
		"direct emptyTap() calls inside the same window are counted and silent",
		played == 0 and meterDebug(host).emptyWarnings == a.emptyWarnings,
		string.format("%d of 6 played feedback", played)
	)
	-- a new window after 1.5 s
	host.wait(1.7)
	for _ = 1, 10 do
		host.emit("HopRejected", { reason = "OutOfStamina" })
		host.wait(0.02)
	end
	local b = meterDebug(host)
	local soundsB = (Sounds.counts().Warning or 0) - soundBase
	verdict(
		host,
		"after 1.5 s the next window gives exactly one more",
		b.emptyWarnings - a.emptyWarnings == 1 and b.emptySounds - a.emptySounds == 1 and soundsB == 2,
		string.format(
			"warnings %d -> %d, sounds %d -> %d (Warning calls in total %d)",
			a.emptyWarnings,
			b.emptyWarnings,
			a.emptySounds,
			b.emptySounds,
			soundsB
		)
	)
	-- another reason is not an empty tap
	host.wait(1.7)
	local c0 = meterDebug(host)
	host.emit("HopRejected", { reason = "NoTarget" })
	host.wait(0.1)
	local c1 = meterDebug(host)
	verdict(
		host,
		"HopRejected for another reason is ignored",
		c1.emptyTaps == c0.emptyTaps and c1.emptyWarnings == c0.emptyWarnings,
		string.format("taps %d -> %d", c0.emptyTaps, c1.emptyTaps)
	)
	-- taps while Stamina is not empty give no feedback at all
	setValue(host, 3)
	host.wait(1.7)
	local d0 = meterDebug(host)
	for _ = 1, 5 do
		host.emit("HopRejected", { reason = "OutOfStamina" })
		host.wait(0.05)
	end
	local d1 = meterDebug(host)
	verdict(
		host,
		"taps above zero are counted but give no warning or sound",
		d1.emptyTaps - d0.emptyTaps == 5 and d1.emptyWarnings == d0.emptyWarnings and d1.emptySounds == d0.emptySounds,
		string.format(
			"taps +%d, warnings +%d, sounds +%d",
			d1.emptyTaps - d0.emptyTaps,
			d1.emptyWarnings - d0.emptyWarnings,
			d1.emptySounds - d0.emptySounds
		)
	)
	-- the fixture only counted them; the run was never touched
	local fx = host.api.staminaDebug()
	verdict(
		host,
		"the taps were only counted: the run continues",
		host.store:get().mode == "Run" and fx.counts.emptyTaps - fxBase == 20 + 10 + 5 and fx.value == 3,
		string.format(
			"mode %s, fixture counted %d, value %s",
			tostring(host.store:get().mode),
			fx.counts.emptyTaps - fxBase,
			tostring(fx.value)
		)
	)
	finish(host)
end

----------------------------------------------------------------------------------------------------------------------
-- placement

-- One frame, one state: the content against the thumbstick zone, measured from the layout numbers and from the real
-- AbsolutePosition through Screen.overlapsReserved. The room that really exists is logged so a failure is explainable.
local function clearance(host: Host, profile: string, label: string)
	local meter = comp(host, "stamina")
	local d = meterDebug(host)
	local ctx = meter._ctx
	local reserved: string? = nil
	local box = d.contentRect
	if box then
		local pos, size = RunLayout.toDevice(ctx, RunLayout.rect(box.x, box.y, box.w, box.h))
		reserved = ctx.screen:overlapsReserved(pos, size)
	end
	local protected = RunLayout.protected(ctx)
	local soft = RunLayout.staminaSoft(ctx)
	local ok = d.shown == true
		and d.zonePx == 0
		and d.realZonePx == 0
		and reserved == nil
		and d.contentOverlapsTray == false
		and d.contentOverlapsProtected == false
		and (d.realRight :: number) <= protected.pos.X
		and (d.numberSize :: number) >= 16
		and (d.boltH :: number) >= 20
	verdict(
		host,
		string.format("%s: %s clear of the thumbstick zone", profile, label),
		ok,
		string.format(
			"content %s (row %s, bolt %s px, number %s px), into the zone by %.1f px (layout) / %.1f px (real) / hit %s, tray %s, protected view %s, right edge %.1f vs %.1f, box sinks %.1f px",
			tostring(d.content),
			tostring(d.rowH),
			tostring(d.boltH),
			tostring(d.numberSize),
			d.zonePx,
			d.realZonePx,
			tostring(reserved),
			tostring(d.contentOverlapsTray),
			tostring(d.contentOverlapsProtected),
			d.realRight,
			protected.pos.X,
			soft
		)
	)
end

S["Stamina: thumb clearance on every frame"] = function(host: Host)
	for _, profile in host.api.profiles do
		host.api.setProfile(profile)
		host.wait(0.3)
		begin(host)
		clearance(host, profile, "10 (pips)")
		setValue(host, 2)
		host.wait(0.6)
		clearance(host, profile, "2 (red; the word on phones)")
		host.wait(3.0) -- past the phones' word swap: the pips are back
		clearance(host, profile, "2 (red, after the swap)")
		setValue(host, 0)
		host.wait(0.6)
		clearance(host, profile, "0 (out of stamina)")
	end
	finish(host)
	host.api.setProfile("Desktop")
end

----------------------------------------------------------------------------------------------------------------------
-- cleanup and scope

S["Stamina: nothing left after destroy"] = function(host: Host)
	host.api.setProfile("Desktop")
	begin(host)
	local mounted = comp(host, "stamina")
	local ctx = mounted._ctx
	local layer: Frame = ctx.layer
	local before = #layer:GetDescendants()
	local temp = StaminaMeter.new(ctx)
	host.wait(0.2)
	for _, v in { 10, 7, 5, 3, 2, 0, 4, 8, 2 } do
		setValue(host, v)
		host.wait(0.12)
	end
	host.wait(0.3) -- ends in Red: the glow loop is running when the meter is destroyed
	local alive = temp:getDebugState()
	local frozen = alive.value
	temp:destroy()
	RunBus.register(ctx, "stamina", mounted) -- the second meter took the registration; hand it back
	local after = #layer:GetDescendants()
	local gone = temp:getDebugState()
	verdict(
		host,
		"a live second meter has instances, 4 connections and a running glow",
		alive.instances > 50 and alive.connections == 4 and alive.pulsing == true and alive.activeTweens >= 1,
		string.format(
			"%d instances, %d connections, pulsing %s, %d tween(s)",
			alive.instances,
			alive.connections,
			tostring(alive.pulsing),
			alive.activeTweens
		)
	)
	verdict(
		host,
		"destroy leaves nothing in the layer",
		after == before,
		string.format("layer descendants %d before, %d after", before, after)
	)
	verdict(
		host,
		"the destroyed meter reports no instance, connection, tween or thread",
		gone.instances == 0
			and gone.connections == 0
			and gone.activeTweens == 0
			and gone.threads == 0
			and gone.pulsing == false,
		string.format(
			"instances %d, connections %d, tweens %d, threads %d, pulsing %s",
			gone.instances,
			gone.connections,
			gone.activeTweens,
			gone.threads,
			tostring(gone.pulsing)
		)
	)
	setValue(host, 5)
	host.wait(0.2)
	verdict(
		host,
		"a destroyed meter no longer listens to the store",
		temp:getDebugState().value == frozen
			and comp(host, "stamina") == mounted
			and RunBus.get(ctx, "stamina") == mounted,
		string.format("value stays %s", tostring(temp:getDebugState().value))
	)
	finish(host)
end

S["Stamina: no hop streak"] = function(host: Host)
	host.api.setProfile("Desktop")
	begin(host)
	for _ = 1, 6 do
		host.emit("HopAccepted", {})
		host.wait(0.25)
	end
	local run = host.store:get().run :: any
	local streakText = {}
	for _, d in host.api.screen.root:GetDescendants() do
		if
			(d:IsA("TextLabel") or d:IsA("TextButton"))
			and string.find(string.upper((d :: any).Text), "STREAK", 1, true)
		then
			table.insert(streakText, d:GetFullName())
		end
	end
	verdict(
		host,
		"six accepted hops: no streak field, no STREAK text on screen",
		run ~= nil and run.hopStreak == nil and #streakText == 0,
		string.format(
			"hopStreak %s, %d label(s) with STREAK%s",
			tostring(run and run.hopStreak),
			#streakText,
			if #streakText > 0 then ": " .. table.concat(streakText, ", ") else ""
		)
	)
	finish(host)
end

S["Stamina: tour (review shots)"] = function(host: Host)
	host.api.setProfile("Desktop")
	begin(host)
	for _, v in { 10, 7, 6, 5, 4, 3, 2, 1, 0, 1, 4, 6, 10 } do
		setValue(host, v)
		host.wait(2.0)
		local d = meterDebug(host)
		host.log(
			string.format(
				"TOUR value %d: %s, number %s, lit %s, word %q, tint %s",
				v,
				tostring(d.state),
				tostring(d.number),
				tostring(d.pipsLit),
				tostring(d.word),
				tostring(d.tint)
			)
		)
	end
	finish(host)
end

return S
