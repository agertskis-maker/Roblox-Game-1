--!strict
-- PLAYGROUND ONLY (Lane 3 Round 2, R2-P1): Hop cue scenarios. Every value is a synthetic fixture played through the
-- preview store; the HUD never picks a target, judges a landing or changes a pose (Lane 1, Brian R). The traffic
-- is held still so the cues can be sampled. Each scenario logs the numbers it checks and PASS / FAIL lines.
--
--   Hop: state precedence             every combination of hop state, cooldown and Stamina -> one display state
--   Hop: best-window hysteresis       flicker at the boundary, one gold accent per window, event identity
--   Hop: retarget and cleanup         one coordinated target, whoosh throttle, no orphan cue after target loss,
--                                     mode exit
--   Hop: reduced motion               the stream and the reticle stand still

local Players = game:GetService("Players")

local Prototype = Players.LocalPlayer
	:WaitForChild("PlayerScripts")
	:WaitForChild("Client")
	:WaitForChild("UI")
	:WaitForChild("Prototype")
local Motion = require(Prototype:WaitForChild("Motion"))

type Host = { [string]: any }

local function comp(host: Host, key: string): any
	return host.api.components and host.api.components[key]
end

local function debugOf(host: Host, key: string): { [string]: any }
	local c = comp(host, key)
	return if c and c.getDebugState then c:getDebugState() else {}
end

local function verdict(host: Host, name: string, ok: boolean, detail: string)
	host.log(string.format("%s %s: %s", if ok then "PASS" else "FAIL", name, detail))
end

local function freshRun(host: Host)
	local store = host.store
	Motion.setOverride(nil)
	if store:get().mode == "Run" then
		store:setMode("Home")
	end
	host.enterRun()
	host.wait(0.6)
end

-- Sets (or clears) one run field the store keeps.
local function setRun(host: Host, fields: { [string]: any })
	local run = host.store:get().run
	if not run then
		return
	end
	local merged = table.clone(run) :: any
	for k, v in fields do
		merged[k] = if v == "__nil" then nil else v
	end
	host.store:set("run", merged)
end

local function stamina(value: number?): any
	if value == nil then
		return "__nil"
	end
	return { value = value, max = 10, lowAt = 3, restore = false }
end

local S: { [string]: (Host) -> () } = {}

S["Hop: state precedence"] = function(host: Host)
	host.api.setSpeed(0)
	freshRun(host)
	host.api.backdrop.hold(0)
	-- hop state, cooldown (the fixture decays it over 1.5 s, so cooldown cases start from 1), Stamina (nil = the demo is
	-- off) -> the display every cue must agree on
	local cases = {
		{ "Available", 0, nil, "Ready" },
		{ "Timing", 0, nil, "BestTiming" },
		{ "Unavailable", 0, nil, "NoTarget" },
		{ "Available", 1, nil, "Cooldown" },
		{ "Timing", 1, nil, "Cooldown" },
		{ "Unavailable", 1, nil, "Cooldown" },
		{ "Available", 0, 0, "OutOfStamina" },
		{ "Timing", 0, 0, "OutOfStamina" },
		{ "Timing", 1, 0, "OutOfStamina" },
		{ "Unavailable", 0, 0, "OutOfStamina" },
		{ "Timing", 0, 5, "BestTiming" },
	}
	for _, c in cases do
		local hop, cooldown, st, expected = c[1], c[2], c[3], c[4]
		setRun(host, { hop = hop, hopCooldown01 = cooldown, stamina = stamina(st) })
		host.wait(0.6) -- longer than the best-timing filter, so the display has settled
		local button = debugOf(host, "hop")
		local cue = debugOf(host, "hopCue")
		local reticle = debugOf(host, "hopReticle")
		local arc = debugOf(host, "hopArc")
		local ring = debugOf(host, "hopRing")
		local best = expected == "BestTiming"
		local advertisesBest = button.ringShown == true
			or reticle.state == "Best"
			or arc.state == "Timing"
			or ring.state == "Timing"
		local ok = button.state == expected
			and cue.display == expected
			and (best or not advertisesBest)
			and (not best or (button.ringShown == true and reticle.state == "Best"))
		verdict(
			host,
			string.format("%s / cooldown %.1f / stamina %s", hop, cooldown, tostring(st)),
			ok,
			string.format(
				"expected %s: button %s, cue %s, ring %s, arc %s, reticle %s, best advertised %s",
				expected,
				tostring(button.state),
				tostring(cue.display),
				tostring(ring.state),
				tostring(arc.state),
				tostring(reticle.state),
				tostring(advertisesBest)
			)
		)
		host.wait(0.5)
	end
	setRun(host, { hop = "Available", hopCooldown01 = 0, stamina = "__nil" })
	host.api.setSpeed(nil)
end

S["Hop: best-window hysteresis"] = function(host: Host)
	host.api.setSpeed(0)
	freshRun(host)
	host.api.backdrop.hold(0)
	setRun(host, { hop = "Available", hopCooldown01 = 0, stamina = "__nil", hopWindowId = "__nil" })
	host.wait(0.9)
	local base = debugOf(host, "hopCue")
	-- 1. flicker faster than the enter delay: the cues never leave Ready
	for _ = 1, 20 do
		setRun(host, { hop = "Timing" })
		host.wait(0.03)
		setRun(host, { hop = "Available" })
		host.wait(0.03)
	end
	host.wait(0.4)
	local fast = debugOf(host, "hopCue")
	verdict(
		host,
		"Fast flicker at the boundary",
		fast.changes == base.changes and fast.accents == base.accents and fast.display == "Ready",
		string.format(
			"display %s, changes %d, accents %d",
			tostring(fast.display),
			fast.changes - base.changes,
			fast.accents - base.accents
		)
	)
	-- 2. hovering: in for 0.12 s, out for 0.10 s (less than the exit hold): one entry, no flashing
	for _ = 1, 8 do
		setRun(host, { hop = "Timing" })
		host.wait(0.12)
		setRun(host, { hop = "Available" })
		host.wait(0.1)
	end
	local hover = debugOf(host, "hopCue")
	verdict(
		host,
		"Hovering at the boundary",
		hover.changes - base.changes <= 1 and hover.accents - base.accents <= 1,
		string.format("display changes %d, accents %d", hover.changes - base.changes, hover.accents - base.accents)
	)
	host.wait(0.6)
	-- 3. a clean window with an identity: one accent, then Ready again
	local before = debugOf(host, "hopCue")
	setRun(host, { hop = "Timing", hopWindowId = "window-1" })
	host.wait(0.7)
	local opened = debugOf(host, "hopCue")
	verdict(
		host,
		"A clean window: one gold accent",
		opened.display == "BestTiming" and opened.accents - before.accents == 1,
		string.format("display %s, accents +%d", tostring(opened.display), opened.accents - before.accents)
	)
	setRun(host, { hop = "Available" })
	host.wait(0.5)
	verdict(
		host,
		"The window closes",
		debugOf(host, "hopCue").display == "Ready",
		tostring(debugOf(host, "hopCue").display)
	)
	-- 4. a second window right after the first (a new id, but inside the accent gap): no second accent
	host.wait(0.9)
	local gapBefore = debugOf(host, "hopCue")
	setRun(host, { hop = "Timing", hopWindowId = "window-2" })
	host.wait(0.25) -- the window shows and plays its one accent
	setRun(host, { hop = "Available" })
	host.wait(0.25) -- it closes (after the exit hold)
	setRun(host, { hop = "Timing", hopWindowId = "window-3" })
	host.wait(0.4) -- ...and re-opens about 0.5 s after the accent
	local gap = debugOf(host, "hopCue")
	verdict(
		host,
		"Re-entry inside the gap",
		gap.accents - gapBefore.accents == 1 and gap.accentsSuppressed - gapBefore.accentsSuppressed >= 1,
		string.format(
			"accents +%d, suppressed +%d",
			gap.accents - gapBefore.accents,
			gap.accentsSuppressed - gapBefore.accentsSuppressed
		)
	)
	setRun(host, { hop = "Available" })
	host.wait(0.9)
	-- 5. the id of the window that last played its accent, again, after the gap: identity suppresses it
	local sameBefore = debugOf(host, "hopCue")
	setRun(host, { hop = "Timing", hopWindowId = "window-2" })
	host.wait(0.5)
	local same = debugOf(host, "hopCue")
	verdict(
		host,
		"The same window id again",
		same.accents == sameBefore.accents,
		string.format("accents +%d", same.accents - sameBefore.accents)
	)
	setRun(host, { hop = "Available" })
	host.wait(0.9)
	-- 6. a new window id after the gap: one accent
	local newBefore = debugOf(host, "hopCue")
	setRun(host, { hop = "Timing", hopWindowId = "window-4" })
	host.wait(0.5)
	local fresh = debugOf(host, "hopCue")
	verdict(
		host,
		"A new window id",
		fresh.accents - newBefore.accents == 1,
		string.format("accents +%d", fresh.accents - newBefore.accents)
	)
	setRun(host, { hop = "Available", hopWindowId = "__nil" })
	host.api.setSpeed(nil)
end

S["Hop: retarget and cleanup"] = function(host: Host)
	host.api.setSpeed(0)
	freshRun(host)
	host.api.backdrop.hold(0)
	local traffic = host.api.backdrop.traffic
	host.api.setHopTarget(2)
	setRun(host, { hop = "Available", hopCooldown01 = 0, stamina = "__nil" })
	host.wait(0.8)
	local cue = debugOf(host, "hopCue")
	local arc = debugOf(host, "hopArc")
	verdict(
		host,
		"One coordinated target",
		cue.oneTarget == true and cue.shownCues == 3,
		string.format(
			"cues shown %s, one target %s, chevrons %s of at most 12",
			tostring(cue.shownCues),
			tostring(cue.oneTarget),
			tostring(arc.chevrons)
		)
	)
	verdict(host, "Chevron pool stays bounded", (arc.chevrons :: number) <= 12, "chevrons " .. tostring(arc.chevrons))
	-- target flicker: the whoosh is throttled
	local locksBefore = debugOf(host, "hopCue")
	for i = 1, 6 do
		host.api.setHopTarget(if i % 2 == 1 then 3 else 2)
		host.wait(0.1)
	end
	local flick = debugOf(host, "hopCue")
	verdict(
		host,
		"Target flicker: whoosh throttled",
		flick.locks - locksBefore.locks <= 1 and flick.locksSuppressed - locksBefore.locksSuppressed >= 4,
		string.format(
			"whooshes +%d, suppressed +%d",
			flick.locks - locksBefore.locks,
			flick.locksSuppressed - locksBefore.locksSuppressed
		)
	)
	-- a clean retarget: every cue follows the new car, nothing stays on the old one
	host.api.setHopTarget(4)
	host.wait(0.7)
	local want = traffic[4]:GetFullName()
	local ring, arcNow, reticle = debugOf(host, "hopRing"), debugOf(host, "hopArc"), debugOf(host, "hopReticle")
	verdict(
		host,
		"Retarget is clean",
		ring.target == want
			and arcNow.target == want
			and reticle.target == want
			and debugOf(host, "hopCue").oneTarget == true,
		string.format(
			"ring %s, arc %s, reticle %s",
			tostring(ring.target == want),
			tostring(arcNow.target == want),
			tostring(reticle.target == want)
		)
	)
	-- the target disappears: no orphan cue
	local model = traffic[4]
	local folder = model.Parent
	model.Parent = nil
	host.wait(0.5)
	local gone = debugOf(host, "hopCue")
	local arcGone, reticleGone, ringGone =
		debugOf(host, "hopArc"), debugOf(host, "hopReticle"), debugOf(host, "hopRing")
	verdict(
		host,
		"Target loss: no orphan cue",
		arcGone.shown == false
			and reticleGone.shown == false
			and ringGone.inWorld == false
			and reticleGone.rim == false
			and gone.shownCues == 0,
		string.format(
			"arc %s, reticle %s, ring in world %s, rim %s, cues shown %s",
			tostring(arcGone.shown),
			tostring(reticleGone.shown),
			tostring(ringGone.inWorld),
			tostring(reticleGone.rim),
			tostring(gone.shownCues)
		)
	)
	model.Parent = folder
	host.api.setHopTarget(2)
	host.wait(0.6)
	verdict(
		host,
		"A new target restores the cues",
		debugOf(host, "hopCue").shownCues == 3,
		"cues shown " .. tostring(debugOf(host, "hopCue").shownCues)
	)
	-- mode exit
	host.store:setMode("Home")
	host.wait(0.5)
	local exit = debugOf(host, "hopCue")
	verdict(
		host,
		"Mode exit hides every cue",
		exit.shownCues == 0
			and debugOf(host, "hopArc").stepping == false
			and debugOf(host, "hopReticle").stepping == false,
		string.format(
			"cues shown %s, arc stepping %s, reticle stepping %s",
			tostring(exit.shownCues),
			tostring(debugOf(host, "hopArc").stepping),
			tostring(debugOf(host, "hopReticle").stepping)
		)
	)
	host.api.setSpeed(nil)
end

S["Hop: reduced motion"] = function(host: Host)
	host.api.setSpeed(0)
	freshRun(host)
	host.api.backdrop.hold(0)
	host.api.setHopTarget(2)
	setRun(host, { hop = "Available", hopCooldown01 = 0, stamina = "__nil" })
	host.wait(0.8)
	local p0 = debugOf(host, "hopArc").phase
	host.wait(0.5)
	local p1 = debugOf(host, "hopArc").phase
	verdict(host, "Normal motion: the stream flows", p0 ~= p1, string.format("phase %.3f -> %.3f", p0, p1))
	Motion.setOverride(true)
	host.wait(0.4)
	local r0 = debugOf(host, "hopArc")
	host.wait(0.5)
	local r1 = debugOf(host, "hopArc")
	verdict(
		host,
		"Reduced motion: the arc stands still",
		r0.phase == 0 and r1.phase == 0 and r1.flowing == false and r1.shown == true,
		string.format("phase %.3f, flowing %s, shown %s", r1.phase, tostring(r1.flowing), tostring(r1.shown))
	)
	setRun(host, { hop = "Timing", hopWindowId = "reduced-1" })
	host.wait(0.7)
	local reticle = debugOf(host, "hopReticle")
	local button = debugOf(host, "hop")
	verdict(
		host,
		"Reduced motion: the window is steady",
		reticle.state == "Best" and reticle.tighten == 0.72 and button.ringShown == true and button.ringPulsing == false,
		string.format(
			"reticle %s tighten %.2f, ring %s, pulsing %s",
			tostring(reticle.state),
			reticle.tighten,
			tostring(button.ringShown),
			tostring(button.ringPulsing)
		)
	)
	setRun(host, { hop = "Available", hopWindowId = "__nil" })
	Motion.setOverride(nil)
	host.api.setSpeed(nil)
end

-- Review captures (no checks): each Hop state held for a moment, and a retarget tour with the traffic moving.
S["Hop: state tour"] = function(host: Host)
	host.api.setSpeed(0)
	freshRun(host)
	host.api.backdrop.hold(0)
	host.api.setHopTarget(2)
	local function hold(name: string, fields: { [string]: any }, seconds: number)
		host.log("Hop state tour: " .. name)
		setRun(host, fields)
		host.wait(seconds)
	end
	hold("Ready", { hop = "Available", hopCooldown01 = 0, stamina = "__nil" }, 2.4)
	hold("BestTiming", { hop = "Timing", hopWindowId = "tour-1" }, 2.4)
	hold("Cooldown", { hop = "Available", hopCooldown01 = 1 }, 2.4)
	hold("NoTarget", { hop = "Unavailable", hopCooldown01 = 0 }, 2.4)
	hold("OutOfStamina", { hop = "Available", stamina = stamina(0) }, 2.4)
	hold("Ready again", { hop = "Available", hopWindowId = "__nil", stamina = "__nil" }, 1.2)
	host.api.setSpeed(nil)
end

S["Hop: retarget tour"] = function(host: Host)
	host.api.setSpeed(0)
	freshRun(host)
	host.api.setHopTarget(2)
	setRun(host, { hop = "Available", hopCooldown01 = 0, stamina = "__nil" })
	host.wait(1.6)
	for _, index in { 3, 4, 2, 5, 2 } do
		host.log("Hop retarget tour: target " .. tostring(index))
		host.api.setHopTarget(index)
		host.wait(1.7)
	end
	host.api.setSpeed(nil)
end

return S
