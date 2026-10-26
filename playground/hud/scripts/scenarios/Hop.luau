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
--
-- Round 3 (R3-L3): the stream is born ON the ridden car's roof. These scenarios build their own proxy cars and their own
-- private arcs (a "HopOriginScenario" folder under the backdrop's world, up in the air: the numbers need no road), so the
-- mounted cues are untouched except in the run-view scenario that says so. Each one logs PASS / FAIL lines.
--
--   Hop: trail origin on the roof          3 sizes (small, bus, truck), a plain model, a RideTop attachment and two
--                                          open vehicles: the origin is on the roof, over the car, never ahead of its
--                                          front face, and the stream rises from it (target ahead and behind)
--   Hop: trail origin and retarget         a retarget moves only the destination; the ridden car is measured once
--   Hop: trail origin follows a moving car 60 frames of a moving car: no jitter; the destination follows the target
--   Hop: trail cleanup (despawn, no target) no target, despawned ridden car, despawned target, other states, destroy
--   Hop: trail origin reduced motion       the stream stands still and still begins on the car
--   Hop: trail origin in the run view      the mounted cues on the playground's own ridden car (the coordinator's setRideModel)
--   Hop: trail origin tour                 review captures: the run camera on each vehicle kind (no checks)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Prototype = Players.LocalPlayer
	:WaitForChild("PlayerScripts")
	:WaitForChild("Client")
	:WaitForChild("UI")
	:WaitForChild("Prototype")
local Motion = require(Prototype:WaitForChild("Motion"))
local ProxyCar = require(Prototype:WaitForChild("ProxyCar"))
local ArcTelegraph = require(Prototype:WaitForChild("World"):WaitForChild("ArcTelegraph"))
local WorldKit = require(Prototype:WaitForChild("World"):WaitForChild("WorldKit"))
local Trove = require(ReplicatedStorage.Packages.Trove)

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

-- ROUND 3 (R3-L3): TRAIL ORIGIN --------------------------------------------------------------------------------------

type Stage = {
	folder: Folder,
	arcWorld: Folder,
	trove: any,
	grounded: boolean, -- true: cars sit on the ground (the tour); false: they hang in the air at the pose given
	finish: () -> (),
	look: (eye: Vector3, at: Vector3) -> (),
	place: (model: Model, cf: CFrame) -> Model,
	car: (spec: any, cf: CFrame) -> Model,
	arc: (ride: Instance?, target: Instance?) -> any,
}

type Case = {
	name: string,
	kind: string, -- the rule the arc should report for this vehicle
	open: boolean, -- an open vehicle (no roof for the stream to stay above)
	-- the car, where a person would say its roof is (found without the arc), and half its length
	build: (stage: Stage, cf: CFrame) -> (Model, Vector3, number),
}

-- up in the air above open grass, yawed and pitched so the car's OWN axes matter
local SKY = CFrame.new(-170, 80, -170) * CFrame.Angles(math.rad(5), math.rad(25), 0)
local SMALL: any = { name = "SmallProxy", family = "Compact", length = 9 }
local BUS: any = { name = "BusProxy", family = "Bus", length = 26 }
local TRUCK: any = { name = "TruckProxy", family = "Pickup", length = 18 }
local BIKE: any = { name = "BikeProxy", family = "Motorcycle", length = 7 }
local OTHER: any = { name = "TargetProxy", family = "Compact", length = 12.5 }

-- A private stage: its own folder, its own arcs, cleaned up when the scenario ends or is cancelled (a watcher thread,
-- as World.luau does: a cancelled scenario cannot clean up after itself).
local function openStage(host: Host, name: string): Stage
	local api = host.api
	local world: Folder = api.backdrop.world
	local old = world:FindFirstChild("HopOriginScenario")
	if old then
		old:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = "HopOriginScenario"
	folder.Parent = world
	local arcWorld = Instance.new("Folder")
	arcWorld.Name = "ArcWorld"
	arcWorld.Parent = folder
	local trove = Trove.new()
	local done = false
	local cameraSet = false
	local stage: Stage
	local function finish()
		if done then
			return
		end
		done = true
		trove:Destroy()
		folder:Destroy()
		Motion.setOverride(nil)
		if cameraSet then
			api.setCamera(nil, nil)
		end
	end
	task.spawn(function()
		local scenarios = api.scenarios
		while not done do
			task.wait(0.25)
			if not scenarios or scenarios.current ~= name then
				finish()
			end
		end
	end)
	stage = {
		folder = folder,
		arcWorld = arcWorld,
		trove = trove,
		grounded = false,
		finish = finish,
		look = function(eye: Vector3, at: Vector3)
			cameraSet = true
			api.setCamera(eye, at)
		end,
		place = function(model: Model, cf: CFrame): Model
			if stage.grounded then
				WorldKit.seat(model, cf)
			else
				model:PivotTo(cf)
			end
			model.Parent = folder
			return model
		end,
		car = function(spec: any, cf: CFrame): Model
			return stage.place(ProxyCar.build(spec), cf)
		end,
		arc = function(ride: Instance?, target: Instance?): any
			local ctx: any = {
				store = api.store,
				screen = api.screen,
				layer = api.layers.Feedback,
				world = arcWorld,
				priority = api.priority,
			}
			local made = ArcTelegraph.new(ctx, { ride = ride, target = target })
			trove:Add(function()
				made:destroy()
			end)
			return made
		end,
	}
	return stage
end

-- Where a person would say the roof is: the top of the proxy's own Roof part (found without the arc's measuring).
local function roofOf(model: Model): Vector3
	local roof = model:FindFirstChild("Roof") :: BasePart
	return roof.CFrame * Vector3.new(0, roof.Size.Y / 2, 0)
end

local function plain(v: any): Vector3?
	return if v then Vector3.new(v.x, v.y, v.z) else nil
end

-- the largest distance any matching chevron moved between two samples (math.huge when the counts differ)
local function maxMove(a: { Vector3 }, b: { Vector3 }): number
	local worst = if #a == #b then 0 else math.huge
	for i = 1, math.min(#a, #b) do
		worst = math.max(worst, (a[i] - b[i]).Magnitude)
	end
	return worst
end

-- a model of one plain block with no attachment (PrimaryPart set, like the finished cars' Root)
local function plainBox(stage: Stage, cf: CFrame, transparency: number): (Model, Vector3, number)
	local m = Instance.new("Model")
	m.Name = "PlainBox"
	local p = Instance.new("Part")
	p.Name = "Block"
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Size = Vector3.new(6, 4, 12)
	p.Transparency = transparency
	p.Parent = m
	m.PrimaryPart = p
	stage.place(m, cf)
	return m, p.CFrame * Vector3.new(0, 2, 0), 6
end

local function closed(name: string, spec: any): Case
	return {
		name = name,
		kind = "Roof",
		open = false,
		build = function(stage: Stage, cf: CFrame): (Model, Vector3, number)
			local m = stage.car(spec, cf)
			return m, roofOf(m), spec.length / 2
		end,
	}
end

local function cases(): { Case }
	return {
		closed("small (Compact, 9 studs)", SMALL),
		closed("bus (26 studs)", BUS),
		closed("truck (Pickup, 18 studs: the cab is not at the centre)", TRUCK),
		{
			name = "plain model, no attachment",
			kind = "Roof",
			open = false,
			build = function(stage: Stage, cf: CFrame): (Model, Vector3, number)
				return plainBox(stage, cf, 0)
			end,
		},
		{
			name = "model with only invisible parts (the box fallback)",
			kind = "Box",
			open = false,
			build = function(stage: Stage, cf: CFrame): (Model, Vector3, number)
				return plainBox(stage, cf, 1)
			end,
		},
		{
			name = "a RideTop attachment (0.6 off the roof centre)",
			kind = "RideTop",
			open = false,
			build = function(stage: Stage, cf: CFrame): (Model, Vector3, number)
				local m = stage.car(SMALL, cf)
				local roof = m:FindFirstChild("Roof") :: BasePart
				local a = Instance.new("Attachment")
				a.Name = "RideTop"
				a.Position = Vector3.new(0.6, roof.Size.Y / 2, 0.4)
				a.Parent = roof
				return m, a.WorldPosition, SMALL.length / 2
			end,
		},
		{
			name = "open vehicle (motorcycle, VehicleKind attribute)",
			kind = "Open",
			open = true,
			build = function(stage: Stage, cf: CFrame): (Model, Vector3, number)
				local m = stage.car(BIKE, cf)
				m:SetAttribute("VehicleKind", "Motorcycle")
				local box, size = m:GetBoundingBox()
				return m, box * Vector3.new(0, size.Y * 0.12, 0), BIKE.length / 2 -- the seat: 62% of the box height
			end,
		},
		{
			name = "open vehicle with a SeatAnchor attachment",
			kind = "Seat",
			open = true,
			build = function(stage: Stage, cf: CFrame): (Model, Vector3, number)
				local m = stage.car(BIKE, cf)
				m:SetAttribute("OpenTop", true)
				local body = m.PrimaryPart :: BasePart
				local a = Instance.new("Attachment")
				a.Name = "SeatAnchor"
				a.Position = Vector3.new(0, body.Size.Y / 2 + 0.2, 0.6)
				a.Parent = body
				return m, a.WorldPosition, BIKE.length / 2
			end,
		},
	}
end

-- Origin on the roof (0.5 stud, in the car's own up and centre axes) and over the car (not ahead of its front face).
local function checkOrigin(host: Host, case: Case, ride: Model, arc: any, expected: Vector3, half: number)
	local pivot = ride:GetPivot()
	local origin: Vector3? = arc:origin()
	if not origin then
		verdict(host, "Origin on the roof: " .. case.name, false, "the arc has no origin")
		return
	end
	local d = pivot:PointToObjectSpace(origin) - pivot:PointToObjectSpace(expected)
	local kind = arc:getDebugState().anchorKind
	verdict(
		host,
		"Origin on the roof: " .. case.name,
		math.abs(d.X) <= 0.5 and math.abs(d.Z) <= 0.5 and d.Y >= -0.1 and d.Y <= 0.5 and kind == case.kind,
		string.format(
			"rule %s (expected %s), offset from the roof in the car's own axes (%.2f, %.2f, %.2f) studs",
			tostring(kind),
			case.kind,
			d.X,
			d.Y,
			d.Z
		)
	)
	local forward = (origin - pivot.Position):Dot(pivot.LookVector)
	verdict(
		host,
		"Origin over the car, not ahead of its front: " .. case.name,
		math.abs(forward) <= half,
		string.format("forward offset %.2f studs, half the car's length %.2f", forward, half)
	)
end

-- The stream stays above the roof wherever it crosses the car's footprint (it never passes through the body).
local function checkRise(host: Host, label: string, ride: Model, arc: any, expected: Vector3)
	local pivot = ride:GetPivot()
	local box, size = ride:GetBoundingBox()
	local centre = pivot:PointToObjectSpace(box.Position)
	local roofY = pivot:PointToObjectSpace(expected).Y
	local inside, lowest = 0, math.huge
	for _, p in arc:points() do
		local l = pivot:PointToObjectSpace(p)
		if math.abs(l.X - centre.X) <= size.X / 2 and math.abs(l.Z - centre.Z) <= size.Z / 2 then
			inside += 1
			lowest = math.min(lowest, l.Y - roofY)
		end
	end
	verdict(
		host,
		"Stream rises from the roof: " .. label,
		inside >= 1 and lowest >= -0.1,
		string.format(
			"%d chevrons over the car, the lowest %.2f studs above the roof",
			inside,
			if inside > 0 then lowest else 0
		)
	)
end

S["Hop: trail origin on the roof"] = function(host: Host)
	local stage = openStage(host, "Hop: trail origin on the roof")
	for _, case in cases() do
		local ride, expected, half = case.build(stage, SKY)
		local ahead = stage.car(OTHER, SKY * CFrame.new(0, 0, -40))
		local behind = stage.car(OTHER, SKY * CFrame.new(0, 0, 40))
		local arc = stage.arc(ride, ahead)
		arc:setState("Available")
		host.wait(0.35)
		checkOrigin(host, case, ride, arc, expected, half)
		if not case.open then
			checkRise(host, case.name .. " (target ahead)", ride, arc, expected)
			arc:setTarget(behind)
			host.wait(0.2)
			checkRise(host, case.name .. " (target behind)", ride, arc, expected)
		end
		arc:destroy()
		for _, m in { ride, ahead, behind } do
			m:Destroy()
		end
	end
	stage.finish()
end

S["Hop: trail origin and retarget"] = function(host: Host)
	local stage = openStage(host, "Hop: trail origin and retarget")
	local ride = stage.car(TRUCK, SKY)
	local targets = {
		stage.car(OTHER, SKY * CFrame.new(0, 0, -35)),
		stage.car(OTHER, SKY * CFrame.new(-10, 0, -45)),
		stage.car(OTHER, SKY * CFrame.new(4, 0, 38)),
	}
	local arc = stage.arc(ride, targets[1])
	arc:setState("Available")
	host.wait(0.3)
	local first: Vector3? = arc:origin()
	local measures: number = arc:getDebugState().anchorMeasures
	verdict(
		host,
		"Retarget: the ridden car and the first target are measured once each",
		first ~= nil and measures == 2,
		"anchor measurements " .. tostring(measures)
	)
	local ridePivot = ride:GetPivot()
	for step, index in { 2, 3, 1, 2 } do
		arc:setTarget(targets[index])
		host.wait(0.15)
		local origin: Vector3? = arc:origin()
		local destination: Vector3? = arc:destination()
		local state = arc:getDebugState()
		local drawn = plain(state.origin)
		local target = targets[index]
		local tp = target:GetPivot()
		local moved = if origin and first then (origin - first).Magnitude else math.huge
		local drawnMoved = if drawn and first then (drawn - first).Magnitude else math.huge
		local d = if destination
			then tp:PointToObjectSpace(destination) - tp:PointToObjectSpace(roofOf(target))
			else nil
		verdict(
			host,
			"Retarget " .. tostring(step) .. ": the origin stays, only the destination moves",
			moved < 0.001
				and drawnMoved < 0.001
				and d ~= nil
				and math.abs(d.X) <= 0.5
				and math.abs(d.Z) <= 0.5
				and d.Y >= -0.1
				and d.Y <= 0.5
				and state.target == target:GetFullName()
				and state.anchorMeasures == measures + step
				and (ridePivot.Position - ride:GetPivot().Position).Magnitude < 0.001,
			string.format(
				"origin moved %.4f (drawn %.4f) studs, destination %s above target %d, measurements %s (+1 per target, none for the ridden car)",
				moved,
				drawnMoved,
				if d then string.format("(%.2f, %.2f, %.2f)", d.X, d.Y, d.Z) else "missing",
				index,
				tostring(state.anchorMeasures)
			)
		)
	end
	stage.finish()
end

S["Hop: trail origin follows a moving car"] = function(host: Host)
	local stage = openStage(host, "Hop: trail origin follows a moving car")
	local base = CFrame.new(-170, 80, -170)
	local speed = 40 -- studs per second
	local function pose(s: number, lateral: number): CFrame
		local x0 = lateral + 6 * math.sin(s / 14)
		local x1 = lateral + 6 * math.sin((s + 1) / 14)
		return CFrame.lookAt(base * Vector3.new(x0, 0, -s), base * Vector3.new(x1, 0, -(s + 1)))
	end
	local ride = stage.car(TRUCK, pose(0, 0))
	local target = stage.car(OTHER, pose(40, 8))
	local arc = stage.arc(ride, target)
	arc:setState("Available")
	host.wait(0.3)
	local measures0: number = arc:getDebugState().anchorMeasures
	local frames, offRoof, offTarget = 0, false, false
	local jitter, destJitter, lag = 0, 0, 0
	local prevDev: Vector3? = nil
	local prevDevT: Vector3? = nil
	local t0 = os.clock()
	-- one sample per frame: the cars move, then the arc's ends are read from the cars' pose now and compared with the
	-- roof found without the arc; the drawn origin (the last Heartbeat's) is logged for information
	stage.trove:Connect(RunService.Heartbeat, function()
		local s = (os.clock() - t0) * speed
		ride:PivotTo(pose(s, 0))
		target:PivotTo(pose(s * 0.9 + 40, 8))
		local origin: Vector3? = arc:origin()
		local destination: Vector3? = arc:destination()
		if not origin or not destination then
			return
		end
		local rp, tp = ride:GetPivot(), target:GetPivot()
		local dev = rp:PointToObjectSpace(origin) - rp:PointToObjectSpace(roofOf(ride))
		local devT = tp:PointToObjectSpace(destination) - tp:PointToObjectSpace(roofOf(target))
		if prevDev and prevDevT then
			jitter = math.max(jitter, (dev - prevDev).Magnitude)
			destJitter = math.max(destJitter, (devT - prevDevT).Magnitude)
		end
		prevDev, prevDevT = dev, devT
		offRoof = offRoof or math.abs(dev.X) > 0.5 or math.abs(dev.Z) > 0.5 or dev.Y < -0.1 or dev.Y > 0.5
		offTarget = offTarget or math.abs(devT.X) > 0.5 or math.abs(devT.Z) > 0.5 or devT.Y < -0.1 or devT.Y > 0.5
		local drawn = plain(arc:getDebugState().origin)
		if drawn then
			lag = math.max(lag, (drawn - origin).Magnitude)
		end
		frames += 1
	end)
	local deadline = os.clock() + 8
	while frames < 60 and os.clock() < deadline do
		host.wait(0.05)
	end
	local state = arc:getDebugState()
	verdict(host, "Moving car: 60 frames sampled", frames >= 60, string.format("%d frames", frames))
	verdict(
		host,
		"Moving car: the origin stays on the roof without jitter",
		frames >= 60 and not offRoof and jitter <= 0.1,
		string.format(
			"largest frame-to-frame change %.4f studs (limit 0.1), off the roof %s",
			jitter,
			tostring(offRoof)
		)
	)
	verdict(
		host,
		"Moving car: the destination stays attached to the target",
		frames >= 60 and not offTarget and destJitter <= 0.1,
		string.format(
			"largest frame-to-frame change %.4f studs (limit 0.1), off the target %s",
			destJitter,
			tostring(offTarget)
		)
	)
	verdict(
		host,
		"Moving car: nothing is measured per frame",
		state.anchorMeasures == measures0 and state.shown == true,
		string.format("measurements %s -> %s", tostring(measures0), tostring(state.anchorMeasures))
	)
	host.log(
		string.format(
			"Hop trail origin: the DRAWN origin trailed the car's pose by at most %.2f studs (the cars move %.2f studs per frame at 60 fps; the order of the two Heartbeat steps is not fixed)",
			lag,
			speed / 60
		)
	)
	stage.finish()
end

S["Hop: trail cleanup (despawn, no target)"] = function(host: Host)
	local stage = openStage(host, "Hop: trail cleanup (despawn, no target)")
	local ride = stage.car(SMALL, SKY)
	local target = stage.car(TRUCK, SKY * CFrame.new(0, 0, -40))
	local before = #stage.arcWorld:GetDescendants()
	local arc = stage.arc(ride, target)
	arc:setState("Available")
	host.wait(0.3)
	local live = arc:getDebugState()
	verdict(
		host,
		"Cleanup: the stream is up with both cars",
		live.visibleChevrons == live.chevrons
			and live.stepping == true
			and live.instances == #stage.arcWorld:GetDescendants()
			and live.connections == 2
			and live.threads == 0,
		string.format(
			"chevrons %s of %s, stepping %s, instances %s (counted %d), connections %s",
			tostring(live.visibleChevrons),
			tostring(live.chevrons),
			tostring(live.stepping),
			tostring(live.instances),
			#stage.arcWorld:GetDescendants(),
			tostring(live.connections)
		)
	)
	-- no target: no cue, nothing runs
	arc:setTarget(nil)
	host.wait(0.15)
	local none = arc:getDebugState()
	verdict(
		host,
		"No target: no cue",
		none.visibleChevrons == 0 and none.stepping == false and arc:destination() == nil and none.connections == 1,
		string.format("chevrons %s, stepping %s", tostring(none.visibleChevrons), tostring(none.stepping))
	)
	arc:setTarget(target)
	host.wait(0.2)
	-- the ridden car despawns
	ride.Parent = nil
	host.wait(0.25)
	local noRide = arc:getDebugState()
	verdict(
		host,
		"The ridden car despawns: no trail left",
		noRide.visibleChevrons == 0 and noRide.stepping == false and noRide.ride == nil and arc:origin() == nil,
		string.format(
			"chevrons %s, stepping %s, ride %s",
			tostring(noRide.visibleChevrons),
			tostring(noRide.stepping),
			tostring(noRide.ride)
		)
	)
	ride.Parent = stage.folder
	arc:setRide(ride)
	host.wait(0.25)
	verdict(
		host,
		"A new ridden car restores the stream",
		arc:getDebugState().visibleChevrons == live.chevrons and arc:getDebugState().stepping == true,
		"chevrons " .. tostring(arc:getDebugState().visibleChevrons)
	)
	-- the target despawns
	target:Destroy()
	host.wait(0.25)
	local noTarget = arc:getDebugState()
	verdict(
		host,
		"The target despawns: no trail left",
		noTarget.visibleChevrons == 0
			and noTarget.stepping == false
			and noTarget.target == nil
			and arc:destination() == nil,
		string.format(
			"chevrons %s, stepping %s, target %s",
			tostring(noTarget.visibleChevrons),
			tostring(noTarget.stepping),
			tostring(noTarget.target)
		)
	)
	-- the other states show nothing
	local again = stage.car(TRUCK, SKY * CFrame.new(0, 0, -40))
	arc:setTarget(again)
	host.wait(0.2)
	local quiet = true
	for _, state in { "Unavailable", "Hidden" } do
		arc:setState(state)
		host.wait(0.1)
		local d = arc:getDebugState()
		quiet = quiet and d.visibleChevrons == 0 and d.stepping == false
	end
	verdict(host, "Unavailable and Hidden show nothing and run nothing", quiet, "checked both")
	arc:destroy()
	verdict(
		host,
		"Destroy leaves nothing behind",
		#stage.arcWorld:GetDescendants() == before,
		string.format("%d instances in the arc's folder (before the arc: %d)", #stage.arcWorld:GetDescendants(), before)
	)
	stage.finish()
end

S["Hop: trail origin reduced motion"] = function(host: Host)
	local stage = openStage(host, "Hop: trail origin reduced motion")
	Motion.setOverride(nil)
	local ride = stage.car(TRUCK, SKY)
	local target = stage.car(OTHER, SKY * CFrame.new(0, 0, -40))
	local arc = stage.arc(ride, target)
	arc:setState("Available")
	host.wait(0.4)
	local flow0: { Vector3 } = arc:points()
	host.wait(0.4)
	local flow1: { Vector3 } = arc:points()
	local moving = maxMove(flow0, flow1)
	verdict(host, "Normal motion: the stream flows", moving > 0.05, string.format("chevrons moved %.2f studs", moving))
	local originMoving: Vector3? = arc:origin()
	Motion.setOverride(true)
	host.wait(0.5)
	local still0: { Vector3 } = arc:points()
	host.wait(0.6)
	local still1: { Vector3 } = arc:points()
	local state = arc:getDebugState()
	local steady = maxMove(still0, still1)
	local origin: Vector3? = arc:origin()
	verdict(
		host,
		"Reduced motion: the stream stands still",
		steady < 0.0001 and state.phase == 0 and state.flowing == false and state.shown == true,
		string.format(
			"chevrons moved %.5f studs, phase %.3f, flowing %s, shown %s",
			steady,
			state.phase,
			tostring(state.flowing),
			tostring(state.shown)
		)
	)
	local pivot = ride:GetPivot()
	local second = still1[2]
	local forward = if second then (second - pivot.Position):Dot(pivot.LookVector) else math.huge
	verdict(
		host,
		"Reduced motion: it still begins on the car",
		origin ~= nil
			and originMoving ~= nil
			and (origin - originMoving).Magnitude < 0.0001
			and still1[1] ~= nil
			and (still1[1] - origin).Magnitude < 0.01
			and forward <= 9,
		string.format(
			"first chevron on the origin, the next %.2f studs along the car's forward axis (half the car is 9)",
			forward
		)
	)
	Motion.setOverride(nil)
	stage.finish()
end

S["Hop: trail origin in the run view"] = function(host: Host)
	host.api.setSpeed(0)
	freshRun(host)
	host.api.backdrop.hold(0)
	host.api.setHopTarget(2)
	setRun(host, { hop = "Available", hopCooldown01 = 0, stamina = "__nil" })
	host.wait(0.8)
	local backdrop = host.api.backdrop
	local ride: Model = backdrop.ride
	local arc = comp(host, "hopArc")
	local cue = comp(host, "hopCue")
	if not arc or not cue or not arc.origin or not cue.setRideModel then
		verdict(host, "Run view: the cues are mounted", false, "hopArc / hopCue (with origin / setRideModel) missing")
		host.api.setSpeed(nil)
		return
	end
	local function onRoof(model: Model): (boolean, string)
		local origin: Vector3? = arc:origin()
		if not origin then
			return false, "no origin"
		end
		local pivot = model:GetPivot()
		local d = pivot:PointToObjectSpace(origin) - pivot:PointToObjectSpace(roofOf(model))
		return math.abs(d.X) <= 0.5 and math.abs(d.Z) <= 0.5 and d.Y >= -0.1 and d.Y <= 0.5,
			string.format("(%.2f, %.2f, %.2f) studs from the roof", d.X, d.Y, d.Z)
	end
	local ok, detail = onRoof(ride)
	local m0: number = debugOf(host, "hopArc").anchorMeasures
	verdict(
		host,
		"Run view: the stream begins on the ridden car's roof",
		ok and debugOf(host, "hopArc").anchorKind == "Roof",
		detail .. ", rule " .. tostring(debugOf(host, "hopArc").anchorKind)
	)
	host.wait(1)
	verdict(
		host,
		"Run view: a second of running measures nothing again",
		debugOf(host, "hopArc").anchorMeasures == m0,
		string.format("measurements %s -> %s", tostring(m0), tostring(debugOf(host, "hopArc").anchorMeasures))
	)
	-- the coordinator hands over the ridden car (the same car: nothing is measured again; another car: measured once)
	cue:setRideModel(ride)
	host.wait(0.2)
	verdict(
		host,
		"Run view: setRideModel with the same car changes nothing",
		debugOf(host, "hopArc").anchorMeasures == m0 and debugOf(host, "hopCue").rideModel == ride.Name,
		string.format("measurements %s", tostring(debugOf(host, "hopArc").anchorMeasures))
	)
	local other: Model = backdrop.traffic[3]
	cue:setRideModel(other)
	host.wait(0.3)
	local okOther, detailOther = onRoof(other)
	verdict(
		host,
		"Run view: a new ridden car moves the origin and is measured once",
		okOther and debugOf(host, "hopArc").anchorMeasures == m0 + 1,
		detailOther .. ", measurements " .. tostring(debugOf(host, "hopArc").anchorMeasures)
	)
	cue:setRideModel(ride)
	host.wait(0.3)
	-- no target: no cue anywhere
	host.api.setHopTarget(nil)
	host.wait(0.5)
	local arcNone = debugOf(host, "hopArc")
	verdict(
		host,
		"Run view: no target, no cue",
		debugOf(host, "hopCue").shownCues == 0 and arcNone.visibleChevrons == 0 and arcNone.stepping == false,
		string.format(
			"cues shown %s, chevrons %s, stepping %s",
			tostring(debugOf(host, "hopCue").shownCues),
			tostring(arcNone.visibleChevrons),
			tostring(arcNone.stepping)
		)
	)
	host.api.setHopTarget(2)
	host.wait(0.6)
	verdict(
		host,
		"Run view: a target brings the cues back",
		debugOf(host, "hopCue").shownCues == 3 and debugOf(host, "hopArc").visibleChevrons > 0,
		"cues shown " .. tostring(debugOf(host, "hopCue").shownCues)
	)
	host.api.setSpeed(nil)
end

-- Review captures (no checks): the run camera on each vehicle kind, the stream beginning on its roof.
S["Hop: trail origin tour"] = function(host: Host)
	local stage = openStage(host, "Hop: trail origin tour")
	stage.grounded = true
	local ground = CFrame.new(-170, 0, -170)
	for _, case in cases() do
		host.log("Hop trail origin tour: " .. case.name)
		local ride = case.build(stage, ground)
		local target = stage.car(OTHER, ground * CFrame.new(0, 0, -34))
		local arc = stage.arc(ride, target)
		arc:setState("Available")
		-- the run's chase camera: 12 behind and 6 above the ridden car, looking 20 ahead
		stage.look(ground.Position + Vector3.new(0, 6, 12), ground.Position + Vector3.new(0, 1.5, -20))
		host.wait(2.6)
		arc:destroy()
		ride:Destroy()
		target:Destroy()
	end
	stage.finish()
end

return S
