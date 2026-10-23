--!strict
-- PLAYGROUND ONLY: run HUD scenarios for the HUD rebuild (Lane 3 preview, worker HR, 2026-10-22).
-- Every value is a synthetic fixture played through the preview store; no remotes, saves,
-- rewards or purchases. Events carry explicit ids (store dedupe) and capture ids (component
-- dedupe); several scenarios deliver duplicates, late and out-of-order events on purpose.
--
-- Component keys used (guarded; a missing component is skipped): strip, banner, heat, tray,
-- keys, ribbon, runEnd, hop, dash, milestones, run, results.

local Players = game:GetService("Players")

local Prototype = Players.LocalPlayer
	:WaitForChild("PlayerScripts")
	:WaitForChild("Client")
	:WaitForChild("UI")
	:WaitForChild("Prototype")
local Motion = require(Prototype:WaitForChild("Motion"))

type Host = { [string]: any }

local counter = 0
local function nonce(): string
	counter += 1
	return string.format("%d-%d", math.floor(os.clock() * 1000), counter)
end

-- Emits with an explicit event id (pass `id` to deliver an exact duplicate).
local function send(host: Host, kind: string, fields: { [string]: any }?): boolean
	local e = fields or {}
	e.id = e.id or (kind .. "-" .. nonce())
	return host.emit(kind, e)
end

local function comp(host: Host, key: string): any
	return host.api.components and host.api.components[key]
end

-- A clean run (tray, flags and dedupe tables reset by the Home -> Run transition).
local function freshRun(host: Host)
	local store = host.store
	Motion.setOverride(nil)
	if store:get().mode == "Run" then
		store:setMode("Home")
	end
	host.enterRun()
	local keys = comp(host, "keys")
	if keys and keys.setAnchor and host.api.backdrop then
		keys:setAnchor(host.api.backdrop.ride)
	end
	local runEnd = comp(host, "runEnd")
	if runEnd and runEnd.setAnchor and host.api.backdrop then
		runEnd:setAnchor(host.api.backdrop.ride)
	end
	host.wait(0.4)
end

-- runPatch cannot clear a field (a nil value is not a table entry); this clears fields.
local function clear(host: Host, fields: { string })
	local run = host.store:get().run
	if not run then
		return
	end
	local n = table.clone(run)
	for _, f in fields do
		(n :: any)[f] = nil
	end
	host.store:set("run", n)
end

local function keys(host: Host, id: string?, car: any, progress: number, status: string, reason: string?)
	host.runPatch({ keys = { id = id, target = car, progress = progress, status = status, reason = reason } })
end

-- Holding from `from` to `to` in steps (the store delivers each step).
local function fill(host: Host, id: string, car: any, from: number, to: number, seconds: number)
	local steps = 12
	for i = 0, steps do
		keys(host, id, car, from + (to - from) * i / steps, "Holding")
		host.wait(seconds / steps)
	end
end

-- Goes to Results the way the lead's playground does (fixture values).
local function toResults(host: Host, reason: string?)
	local store = host.store
	local claimed = {}
	local tray = comp(host, "tray")
	if tray and tray.claimed then
		for _, c in tray:claimed() do
			table.insert(claimed, c)
		end
	end
	local ribbon = comp(host, "ribbon")
	if ribbon and ribbon.takePendingCards then
		for _, c in ribbon:takePendingCards() do
			if not table.find(claimed, c) then
				table.insert(claimed, c)
			end
		end
	end
	local run = store:get().run
	local res = {
		distance = if run then run.distance else 0,
		coins = if run then run.coins else 0,
		best = if run then run.best else 0,
		newBest = false,
		claimed = claimed,
		earnings = 0,
		endReason = reason,
	}
	store:set("results", res)
	if store:setMode("Results") then
		local card = comp(host, "results")
		if card and card.show then
			card:show(res, claimed)
		end
	end
end

-- Waits for RunEnd's hand-off (Finished), bounded.
local function awaitFinished(host: Host, limit: number)
	local runEnd = comp(host, "runEnd")
	local t = 0
	while t < limit do
		if runEnd and runEnd.getDebugState and runEnd:getDebugState().finished then
			return
		end
		host.wait(0.1)
		t += 0.1
	end
end

local S: { [string]: (Host) -> () } = {}

S["Run: district transition and cycle"] = function(host)
	freshRun(host)
	host.log("Districts: Main Street 170 m, City Hall 150, Harbor Bridge 135, Midtown 190, Skyline Park 160 (fixture)")
	host.runPatch({ distance = 10 })
	send(host, "DistrictEnter", { district = "MainStreet", cycle = 1 })
	host.wait(3)
	host.runPatch({ distance = 171 }) -- boundary into City Hall
	local id = "district-cityhall-" .. nonce()
	send(host, "DistrictEnter", { id = id, district = "CityHall", cycle = 1 })
	send(host, "DistrictEnter", { id = id, district = "CityHall", cycle = 1 }) -- exact duplicate (store)
	send(host, "DistrictEnter", { district = "CityHall", cycle = 1 }) -- repeat, new id (banner dedupe)
	host.wait(3)
	host.runPatch({ distance = 456 }) -- Midtown (unequal spans: the head sits near its start)
	send(host, "DistrictEnter", { district = "Midtown", cycle = 1 })
	send(host, "DistrictEnter", { district = "HarborBridge", cycle = 1 }) -- late, out of order: stale
	host.wait(3)
	host.runPatch({ distance = 790 }) -- Skyline Park, near the end of the first pass
	send(host, "DistrictEnter", { district = "SkylinePark", cycle = 1 })
	host.wait(3)
	host.runPatch({ distance = 808 }) -- the plan repeats: Main Street again, LAP 2, no end cap
	send(host, "DistrictEnter", { district = "MainStreet", cycle = 2 })
	host.wait(3)
	host.log("Strip debug: " .. tostring(comp(host, "strip") and comp(host, "strip"):getDebugState().cycle))
end

S["Run: Keys start/progress/75%/pending/confirmed"] = function(host)
	freshRun(host)
	local car = host.car("rev6")
	local id = "cap-" .. nonce()
	host.runPatch({ ride = car })
	send(host, "KeysStart", { captureId = id, car = car })
	fill(host, id, car, 0, 0.7, 2.4)
	fill(host, id, car, 0.7, 0.95, 1.0) -- crosses 75%: ALMOST! once
	keys(host, id, car, 0.6, "Holding") -- a stale lower progress never moves the ring back
	host.wait(0.3)
	keys(host, id, car, 1, "Pending")
	host.runPatch({ pendingClaim = { id = id, car = car } })
	host.wait(1.6) -- SECURING… (no ownership, no count)
	send(host, "KeysConfirmed", { captureId = id, car = car })
	host.runPatch({ claims = { { id = id, car = car } } })
	clear(host, { "pendingClaim" })
	host.wait(0.4)
	clear(host, { "keys" })
	host.wait(3.5) -- ribbon hold, icon flight, tray +1 with a stamp
end

S["Run: Keys delayed and duplicate confirmation"] = function(host)
	freshRun(host)
	local car = host.car("hurrikan")
	local id = "cap-" .. nonce()
	send(host, "KeysStart", { captureId = id, car = car })
	fill(host, id, car, 0, 1, 2.5)
	keys(host, id, car, 1, "Pending")
	host.runPatch({ pendingClaim = { id = id, car = car } })
	host.wait(3) -- a slow confirmation: SECURING… holds
	local eventId = "confirm-" .. nonce()
	send(host, "KeysConfirmed", { id = eventId, captureId = id, car = car })
	send(host, "KeysConfirmed", { id = eventId, captureId = id, car = car }) -- same event id (store)
	send(host, "KeysConfirmed", { captureId = id, car = car }) -- same capture, new id (component)
	host.runPatch({ claims = { { id = id, car = car } } })
	clear(host, { "pendingClaim" })
	host.wait(0.3)
	keys(host, id, car, 1, "Pending") -- an out-of-order Pending after Confirmed: never reverses
	send(host, "KeysCanceled", { captureId = id, reason = "HoppedOff" }) -- late cancel: ignored
	host.wait(3)
	-- a confirmation that arrives after the capture was already shown as not confirmed
	local car2 = host.car("zoomurai")
	local id2 = "cap-" .. nonce()
	send(host, "KeysStart", { captureId = id2, car = car2 })
	fill(host, id2, car2, 0, 1, 2)
	keys(host, id2, car2, 1, "Pending")
	host.wait(8.6) -- the 8 s proposal timeout: "Not confirmed"
	send(host, "KeysConfirmed", { captureId = id2, car = car2 }) -- late truth: ribbon only, no replay
	clear(host, { "keys" })
	host.wait(4)
	local tray = comp(host, "tray")
	host.log("Tray count (expect 2): " .. tostring(tray and tray:count()))
end

S["Run: Keys cancel"] = function(host)
	freshRun(host)
	local car = host.car("rangy")
	local id = "cap-" .. nonce()
	send(host, "KeysStart", { captureId = id, car = car })
	fill(host, id, car, 0, 0.55, 1.6)
	keys(host, id, car, 0.55, "Canceled", "HoppedOff") -- "You hopped off": gentle fracture
	host.wait(0.2)
	send(host, "KeysCanceled", { captureId = id, reason = "HoppedOff" }) -- duplicate cancel
	host.wait(2)
	clear(host, { "keys" })
	-- a cancel with no reason: no invented text
	local id2 = "cap-" .. nonce()
	fill(host, id2, car, 0, 0.3, 1)
	send(host, "KeysCanceled", { captureId = id2 })
	host.wait(1.5)
	clear(host, { "keys" })
	host.wait(1)
end

S["Run: capture at run end"] = function(host)
	freshRun(host)
	local car = host.car("hyperion")
	local id = "cap-" .. nonce()
	send(host, "KeysStart", { captureId = id, car = car })
	fill(host, id, car, 0, 1, 2)
	keys(host, id, car, 1, "Pending")
	host.runPatch({ pendingClaim = { id = id, car = car }, heat = 1, stage = "Meltdown" })
	host.wait(0.8)
	send(host, "Dismounted", { reason = "Overheated" })
	send(host, "RunEnded", { reason = "Overheated" })
	host.wait(0.5)
	-- the confirmation arrives after the run ended: kept for Results, never celebrated on top
	send(host, "KeysConfirmed", { captureId = id, car = car })
	host.runPatch({ claims = { { id = id, car = car } } })
	clear(host, { "pendingClaim", "keys" })
	awaitFinished(host, 3)
	toResults(host, "Overheated")
	host.wait(4)
end

S["Run: already owned (Joyride, synthetic)"] = function(host)
	freshRun(host)
	local car = table.clone(host.car("puglet")) -- owned == true: the silver ring
	local id = "cap-" .. nonce()
	send(host, "KeysStart", { captureId = id, car = car })
	fill(host, id, car, 0, 1, 2)
	keys(host, id, car, 1, "Pending")
	host.wait(0.8)
	-- the Joyride Bonus is Decided (GDD); +$50 is a SYNTHETIC fixture amount (Brian L owns it)
	send(host, "AlreadyOwned", { captureId = id, car = car, amount = 50 })
	send(host, "AlreadyOwned", { captureId = id, car = car, amount = 50 }) -- duplicate
	clear(host, { "keys" })
	host.wait(3)
	local tray = comp(host, "tray")
	host.log("Tray count after Joyride (expect 0): " .. tostring(tray and tray:count()))
end

S["Run: warning with advance notice → eject → OVERHEATED → Results"] = function(host)
	freshRun(host)
	local car = host.car("rev6")
	host.runPatch({ claims = { { id = "fixture-claim-1", car = host.car("rangy") } } })
	host.wait(0.5)
	for _, h in { { 0.5, "Warning" }, { 0.8, "Warning" }, { 0.9, "Critical" } } do
		host.runPatch({ heat = h[1], stage = h[2] })
		host.wait(0.8)
	end
	local warnId = "warn-" .. nonce()
	host.runPatch({ warning = { id = warnId, reason = "TooHot" }, ride = car })
	send(host, "RunWarning", { id = warnId .. "-event", reason = "TooHot" })
	host.wait(0.4)
	send(host, "DistrictEnter", { district = "MainStreet", cycle = 1 }) -- deferred by the warning
	send(host, "Milestone", { text = "100 m!" }) -- deferred / dropped by the warning
	host.runPatch({ heat = 1, stage = "Meltdown" })
	host.wait(1.6)
	send(host, "Dismounted", { reason = "Overheated" }) -- the eject (HW: tumble proxy)
	clear(host, { "warning" })
	host.wait(0.5)
	send(host, "RunEnded", { reason = "Overheated" })
	send(host, "RunEnded", { reason = "Overheated" }) -- duplicate end: one heading, one hand-off
	awaitFinished(host, 3)
	toResults(host, "Overheated")
	host.wait(4)
end

S["Run: instant failure (no warning)"] = function(host)
	freshRun(host)
	host.runPatch({ heat = 0.3, stage = "Calm" })
	host.wait(1.5)
	send(host, "RunEnded", { reason = "MissedHop" }) -- no prior warning: explained at once
	awaitFinished(host, 3)
	host.wait(0.3)
	freshRun(host)
	host.wait(1)
	send(host, "RunEnded", { reason = "SomethingUnmapped" }) -- truthful fallback: "RUN ENDED"
	awaitFinished(host, 3)
	toResults(host, nil)
	host.wait(3)
end

-- Round 2 (R2-H4): the canonical Heat input sequence. Identical steps and timing are replayed through the
-- original ENGINE HEAT panel standalone (heat/baseline-original.json) and through the integrated adapter,
-- so the two can be compared number for number. A fixture with the original thresholds, not a live run.
S["Run: Heat sequence (HEAT_SEQ)"] = function(host)
	freshRun(host)
	host.runPatch({ heat = 0, stage = "Calm" }) -- t 0 (snap)
	host.wait(1)
	host.runPatch({ heat = 0.3, stage = "Calm" }) -- t 1
	host.wait(2)
	host.runPatch({ heat = 0.6, stage = "Warning" }) -- t 3
	host.wait(2)
	host.runPatch({ heat = 0.85, stage = "Critical" }) -- t 5
	host.wait(2)
	host.runPatch({ heat = 1, stage = "Meltdown" }) -- t 7
	host.wait(4)
	host.runPatch({ heat = 0, stage = "Calm" }) -- t 11: the Hop reset
	host.wait(3)
end

S["Run: Heat stages"] = function(host)
	freshRun(host)
	for _, h in
		{
			{ 0.05, "Calm" },
			{ 0.3, "Calm" },
			{ 0.55, "Calm" },
			{ 0.62, "Warning" },
			{ 0.78, "Warning" },
			{ 0.88, "Critical" },
			{ 0.97, "Critical" },
			{ 1, "Meltdown" },
		}
	do
		host.runPatch({ heat = h[1], stage = h[2] })
		host.wait(1.4)
	end
	for i = 1, 6 do -- rapid stage changes: one brief emphasis each, no shaking
		host.runPatch({ heat = if i % 2 == 0 then 0.9 else 0.5, stage = if i % 2 == 0 then "Critical" else "Warning" })
		host.wait(0.3)
	end
	host.runPatch({ heat = 0.1, stage = "Calm" }) -- a Hop resets Heat
	host.wait(1.5)
end

S["Run: claim tray overflow"] = function(host)
	freshRun(host)
	local ids = { "rev6", "zoomurai", "hurrikan", "rangy", "hyperion", "rev6", "zoomurai" }
	local claims = {}
	for i, carId in ids do
		local car = host.car(carId)
		local id = "claim-" .. i .. "-" .. nonce()
		table.insert(claims, { id = id, car = car })
		send(host, "KeysConfirmed", { captureId = id, car = car })
		host.runPatch({ claims = table.clone(claims) })
		host.wait(if i <= 2 then 3.2 else 0.5)
	end
	host.runPatch({ pendingClaim = { id = "claim-pending-" .. nonce(), car = host.car("hyperion") } })
	host.wait(1.5)
	local tray = comp(host, "tray")
	if tray and tray.openReview then
		tray:openReview() -- the "+N" tap
	end
	host.wait(3)
	if tray and tray.closeReview then
		tray:closeReview()
	end
	clear(host, { "pendingClaim" })
	host.log("Tray count (expect 7): " .. tostring(tray and tray:count()))
	host.wait(1)
end

S["Run: Hop button states (keyboard/touch/gamepad)"] = function(host)
	freshRun(host)
	local hop = comp(host, "hop")
	for _, kind in { "Keyboard", "Touch", "Gamepad" } do
		if hop and hop.setInputKind then
			hop:setInputKind(kind)
		end
		for _, st in { "Available", "Timing", "Unavailable", "Available" } do
			host.runPatch({ hop = st, hopCooldown01 = 0 })
			host.wait(1)
		end
		host.runPatch({ hopCooldown01 = 1 }) -- the cooldown sweep + WAIT
		host.wait(1.8)
	end
	if hop and hop.setInputKind then
		hop:setInputKind(nil)
	end
end

S["Run: reduced motion capture"] = function(host)
	freshRun(host)
	Motion.setOverride(true)
	local car = host.car("hurrikan")
	local id = "cap-" .. nonce()
	send(host, "DistrictEnter", { district = "MainStreet", cycle = 1 })
	send(host, "KeysStart", { captureId = id, car = car })
	fill(host, id, car, 0, 1, 2.4)
	keys(host, id, car, 1, "Pending")
	host.wait(1.2)
	send(host, "KeysConfirmed", { captureId = id, car = car })
	host.runPatch({ claims = { { id = id, car = car } } })
	clear(host, { "keys" })
	host.wait(3)
	local id2 = "cap-" .. nonce()
	fill(host, id2, car, 0, 0.5, 1)
	keys(host, id2, car, 0.5, "Canceled", "HoppedOff")
	host.wait(2)
	clear(host, { "keys" })
	host.runPatch({ heat = 0.92, stage = "Critical" })
	host.wait(2)
	Motion.setOverride(nil)
end

S["Run: four layouts"] = function(host)
	freshRun(host)
	local car = host.car("rev6")
	local id = "cap-" .. nonce()
	host.runPatch({
		distance = 300,
		heat = 0.7,
		stage = "Warning",
		claims = {
			{ id = "lay-1", car = host.car("rangy") },
			{ id = "lay-2", car = host.car("zoomurai") },
			{ id = "lay-3", car = host.car("hurrikan") },
		},
		pendingClaim = { id = id, car = car },
	})
	keys(host, id, car, 0.62, "Holding")
	local run = comp(host, "run")
	if run and run.setDiagnostics then
		run:setDiagnostics(true)
	end
	for i, profile in { "Desktop", "PhoneLandscape", "PhonePortrait", "Tablet" } do
		host.api.setProfile(profile)
		-- each layout on its own pass of the repeating plan (805 m per pass), so City Hall is the
		-- current district and its banner is new (dedupe is per district and cycle)
		host.runPatch({ distance = 200 + 805 * (i - 1) })
		host.wait(0.3)
		send(host, "DistrictEnter", { district = "CityHall", cycle = i })
		host.wait(2.6)
	end
	if run and run.setDiagnostics then
		run:setDiagnostics(false)
	end
	host.api.setProfile("Desktop")
	clear(host, { "keys", "pendingClaim" })
end

return S
