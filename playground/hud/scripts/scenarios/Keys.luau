--!strict
-- PLAYGROUND ONLY (Lane 3 Round 3, R3-K1 and R3-K2): the continuous Keys ring. Every value is a synthetic fixture played
-- through the preview store; ownership comes only from the explicit KeysConfirmed event, never from progress. Each
-- scenario logs the numbers it checks and PASS / FAIL lines (grep "PASS Keys" / "FAIL Keys" in the harness log).
--
-- The numbers are read back from the real ring instances through KeysLock:getDebugState().ring (gradient rotations,
-- clip and gradient visibility, stroke thickness, clip edges, centres), not from what the code meant to set.
--
--   Keys: ring geometry (every frame)           0, 1, 25, 50, 75, 99 and 100 percent on every frame: shown fill, sweep
--                                               angle from the instances, one origin (12 o'clock) and direction (clockwise),
--                                               halves, closed ring, no filled centre, ring concentric with the key plate,
--                                               key centred, readable size, the Round 2 placement kept
--   Keys: smooth follow                         never past the supplied value, within 120 ms of every step, forward only,
--                                               one representation at a time (no flash at 0 or 360), stale lower values,
--                                               the ease connection stops when shown equals supplied
--   Keys: pending before confirmation           full progress before the claim: steady full ring, one pulse only, SECURING,
--                                               no SECURED / reveal / tray change; the confirmation hands off
--   Keys: cancel, lose and reset cleanup        six ways to end early: nothing left running, instance count back to baseline
--   Keys: reduced motion                        no pulse, steady brighter thicker completion, values shown at once
--   Keys: repeated start and cancel             twenty rounds: no leaked instance, connection or timer

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Prototype = Players.LocalPlayer
	:WaitForChild("PlayerScripts")
	:WaitForChild("Client")
	:WaitForChild("UI")
	:WaitForChild("Prototype")
local Motion = require(Prototype:WaitForChild("Motion"))

type Host = { [string]: any }

local EPS = 0.0025 -- fill fraction tolerance (0.9 degrees)
local FOLLOW_LIMIT = 0.12 -- seconds: the shown fill has reached each supplied value by now
local ORIGIN = "12 o'clock (top)"

local counter = 0
local function nonce(): string
	counter += 1
	return string.format("%d-%d", math.floor(os.clock() * 1000), counter)
end

local function comp(host: Host, key: string): any
	return host.api.components and host.api.components[key]
end

local function dbg(host: Host, key: string): { [string]: any }
	local c = comp(host, key)
	return if c and c.getDebugState then c:getDebugState() else {}
end

local function verdict(host: Host, name: string, ok: boolean, detail: string)
	host.log(string.format("%s %s: %s", if ok then "PASS" else "FAIL", name, detail))
end

local function near(a: number, b: number, tolerance: number): boolean
	return math.abs(a - b) <= tolerance
end

local function send(host: Host, kind: string, fields: { [string]: any }?)
	local e = fields or {}
	e.id = e.id or (kind .. "-" .. nonce())
	return host.emit(kind, e)
end

-- A clean run (the Home -> Run transition resets the tray, flags and dedupe tables) with the Keys ring following the
-- backdrop ride, as the HUD playground mounts it.
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
	host.wait(0.5)
end

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

local function setKeys(host: Host, id: string, car: any, progress: number, status: string, reason: string?)
	setRun(host, { keys = { id = id, target = car, progress = progress, status = status, reason = reason } })
end

local function clearKeys(host: Host)
	setRun(host, { keys = "__nil" })
end

local function ownedFalse(host: Host, id: string): any
	local c = table.clone(host.car(id)) :: any
	c.owned = false
	return c
end

-- The sweep the ring shows, in degrees from 12 o'clock clockwise, worked out from the instances' own state.
local function sweepDegrees(r: any): number
	if r.closedVisible then
		return 360
	end
	local total = 0
	if r.rightVisible then
		total += math.clamp(r.rightRotation, 0, 180)
	end
	if r.leftVisible then
		total += math.clamp(r.leftRotation, 180, 360) - 180
	end
	return total
end

local function startCapture(host: Host, car: any): string
	local id = "ring-" .. nonce()
	send(host, "KeysStart", { captureId = id, car = car })
	return id
end

-- Lets a finished capture hide and drop every connection, then returns the baseline instance count.
local function settle(host: Host): { [string]: any }
	host.wait(2.2)
	return dbg(host, "keys")
end

-- One full capture to a steady full ring, then a cancel: after it the one-time instances (the ALMOST! scale) exist,
-- so the instance count it returns is the baseline every later capture must return to.
local function warmUp(host: Host): number
	local car = ownedFalse(host, "rev6")
	local id = startCapture(host, car)
	for _, p in { 0.4, 0.8, 1 } do
		setKeys(host, id, car, p, "Holding")
		host.wait(0.2)
	end
	send(host, "KeysCanceled", { captureId = id, reason = "HoppedOff" })
	clearKeys(host)
	return settle(host).instances
end

local S: { [string]: (Host) -> () } = {}

S["Keys: ring geometry (every frame)"] = function(host: Host)
	host.api.setSpeed(0)
	local percents = { 0, 1, 25, 50, 75, 99, 100 }
	for _, profile in host.api.profiles do
		host.api.setProfile(profile)
		freshRun(host)
		host.api.backdrop.hold(0)
		local car = ownedFalse(host, "rev6")
		local id = startCapture(host, car)
		local failures = 0
		for _, pct in percents do
			setKeys(host, id, car, pct / 100, "Holding")
			host.wait(0.25)
			local d = dbg(host, "keys")
			local r = d.ring
			local name = string.format("Ring %s %d%%", profile, pct)
			if not r then
				verdict(host, name, false, "no ring in the debug state")
				failures += 1
				continue
			end
			local f = pct / 100
			local sweep = sweepDegrees(r)
			local ok = near(r.shown, f, EPS)
				and near(sweep, f * 360, EPS * 360)
				and near(r.rightRotation, r.expectedRightRotation, 0.01)
				and near(r.leftRotation, r.expectedLeftRotation, 0.01)
				and r.rightVisible == (pct > 0 and pct < 100)
				and r.leftVisible == (pct > 50 and pct < 100)
				and r.closedVisible == (pct == 100)
				and r.rightGradientOn == (pct < 50)
				and r.stepping == false
				and r.origin == ORIGIN
				and r.direction == "clockwise"
				and d.percent == string.format("%d%%", pct)
				and near(r.keyRotation, r.expectedKeyRotation, 0.01)
			verdict(
				host,
				name,
				ok,
				string.format(
					"shown %.4f, sweep %.2f deg (want %.2f), right %.2f, left %.2f, halves %s/%s, closed %s, origin %s %s, text %s",
					r.shown,
					sweep,
					f * 360,
					r.rightRotation,
					r.leftRotation,
					tostring(r.rightVisible),
					tostring(r.leftVisible),
					tostring(r.closedVisible),
					tostring(r.origin),
					tostring(r.direction),
					tostring(d.percent)
				)
			)
			if not ok then
				failures += 1
			end
		end
		-- the shape: concentric, split on the centre line, nothing filled, no segments, readable, key centred, placed
		-- as in Round 2 (clear of the protected road view)
		local d = dbg(host, "keys")
		local r = d.ring
		if r then
			verdict(
				host,
				"Ring shape " .. profile,
				near(r.splitX, 0.5, 0.01)
					and near(r.leftEdgeX, 0.5, 0.02)
					and r.centreOffsetPx <= 1.5
					and r.keyHolderOffsetPx <= 1.5
					and r.fillsCentre == false
					and r.segmented == false
					and r.instances <= 24
					and r.closedThickness > r.thickness,
				string.format(
					"split %.3f / %.3f, centre offset %.2f px, key offset %.2f px, fills centre %s, segmented %s, %d ring instances, closed thickness %.1f over %.1f",
					r.splitX,
					r.leftEdgeX,
					r.centreOffsetPx,
					r.keyHolderOffsetPx,
					tostring(r.fillsCentre),
					tostring(r.segmented),
					r.instances,
					r.closedThickness,
					r.thickness
				)
			)
			verdict(
				host,
				"Ring size and placement " .. profile,
				d.ringSize >= 64 and r.thickness >= 10 and r.outerDiameter >= 56 and d.overlapsProtected == false,
				string.format(
					"widget ring %s design px, outer %s, width %s, placed as %s at %s, overlaps the protected road view %s, key lock fallback %s",
					tostring(d.ringSize),
					tostring(r.outerDiameter),
					tostring(r.thickness),
					tostring(d.tracking),
					tostring(d.box),
					tostring(d.overlapsProtected),
					tostring(d.keyLockFallback)
				)
			)
		end
		send(host, "KeysCanceled", { captureId = id, reason = "HoppedOff" })
		clearKeys(host)
		host.wait(1.6)
		if failures > 0 then
			host.log(string.format("INFO Keys geometry %s: %d failing sample(s) above", profile, failures))
		end
	end
	host.api.setProfile("Desktop")
	host.api.setSpeed(nil)
end

S["Keys: smooth follow"] = function(host: Host)
	host.api.setProfile("Desktop")
	host.api.setSpeed(0)
	freshRun(host)
	host.api.backdrop.hold(0)
	local car = ownedFalse(host, "rev6")
	local id = startCapture(host, car)
	host.wait(0.3)
	local r0 = dbg(host, "keys").ring
	verdict(
		host,
		"No ease connection while nothing differs",
		r0 ~= nil and r0.stepping == false and r0.shown == 0,
		string.format("stepping %s, shown %s", tostring(r0 and r0.stepping), tostring(r0 and r0.shown))
	)
	-- A. a ramp the way the preview adapter supplies it (steps ten times a second), sampled on every frame
	local supplied = 0
	local history: { { t: number, v: number } } = { { t = os.clock(), v = 0 } }
	local frames, worstOver, worstLag, drops, badSwap = 0, -1, 1, 0, 0
	local lastShown = 0
	local deadline = os.clock() + 14
	local conn: RBXScriptConnection? = nil
	conn = RunService.Heartbeat:Connect(function()
		local now = os.clock()
		if now > deadline and conn then
			conn:Disconnect()
			return
		end
		local r = dbg(host, "keys").ring
		if not r then
			return
		end
		frames += 1
		worstOver = math.max(worstOver, r.shown - supplied)
		local expected = 0
		for _, h in history do
			if h.t <= now - FOLLOW_LIMIT then
				expected = h.v
			else
				break
			end
		end
		worstLag = math.min(worstLag, r.shown - expected)
		if r.shown < lastShown - 1e-9 then
			drops += 1
		end
		lastShown = r.shown
		-- one representation at a time: the halves while open, the closed ring only when exactly full
		if r.shown > 0 and ((r.rightVisible or r.leftVisible) == r.closedVisible) then
			badSwap += 1
		end
		if r.closedVisible and r.shown < 1 then
			badSwap += 1
		end
	end)
	local function supply(p: number)
		if p > supplied then
			supplied = p
			table.insert(history, { t = os.clock(), v = supplied })
		end
		setKeys(host, id, car, p, "Holding")
	end
	for i = 1, 19 do
		supply(i * 0.05)
		if i == 10 then
			supply(0.2) -- a stale lower value: the ring never moves back
		end
		host.wait(0.1)
	end
	supply(0.99)
	host.wait(0.1)
	supply(0.995)
	host.wait(0.1)
	supply(1)
	host.wait(0.5)
	if conn then
		conn:Disconnect()
	end
	verdict(
		host,
		"Never past the supplied value",
		worstOver <= 1e-6 and frames > 10,
		string.format("largest shown minus supplied %.8f over %d frames", worstOver, frames)
	)
	verdict(
		host,
		"Never more than 120 ms behind",
		worstLag >= -0.003,
		string.format("smallest (shown minus the value supplied 120 ms earlier) %.5f", worstLag)
	)
	verdict(host, "Only ever moves forward", drops == 0, string.format("%d frames where it went back", drops))
	verdict(
		host,
		"No flash at 0 or 360 degrees",
		badSwap == 0,
		string.format("%d frames where the halves and the closed ring disagreed", badSwap)
	)
	local end1 = dbg(host, "keys").ring
	verdict(
		host,
		"Full: the closed ring, the ease connection stopped",
		end1 ~= nil and end1.closedVisible == true and end1.shown == 1 and end1.stepping == false,
		string.format(
			"closed %s, shown %s, stepping %s",
			tostring(end1 and end1.closedVisible),
			tostring(end1 and end1.shown),
			tostring(end1 and end1.stepping)
		)
	)
	-- the ring stays full after a stale lower value, with no step connection left over
	setKeys(host, id, car, 0.3, "Holding")
	host.wait(0.25)
	local stale = dbg(host, "keys").ring
	verdict(
		host,
		"A stale lower value does nothing",
		stale ~= nil and stale.shown == 1 and stale.target == 1 and stale.stepping == false,
		string.format("shown %s, target %s", tostring(stale and stale.shown), tostring(stale and stale.target))
	)
	send(host, "KeysCanceled", { captureId = id, reason = "HoppedOff" })
	clearKeys(host)
	host.wait(1.6)
	-- B. single steps, measured 120 ms after each
	local id2 = startCapture(host, car)
	host.wait(0.3)
	for _, p in { 0.6, 0.61, 0.9, 1 } do
		setKeys(host, id2, car, p, "Holding")
		host.wait(FOLLOW_LIMIT)
		local r = dbg(host, "keys").ring
		verdict(
			host,
			string.format("Step to %d%% is reached within 120 ms", math.floor(p * 100 + 0.5)),
			r ~= nil and near(r.shown, p, 0.002) and r.stepping == false,
			string.format(
				"shown %s of %s, ease connection %s",
				tostring(r and r.shown),
				tostring(p),
				tostring(r and r.stepping)
			)
		)
	end
	send(host, "KeysCanceled", { captureId = id2, reason = "HoppedOff" })
	clearKeys(host)
	host.wait(1.6)
	host.api.setSpeed(nil)
end

S["Keys: pending before confirmation"] = function(host: Host)
	host.api.setProfile("Desktop")
	host.api.setSpeed(0)
	freshRun(host)
	host.api.backdrop.hold(0)
	local tray = comp(host, "tray")
	local count0 = if tray and tray.count then tray:count() else 0
	local ribbon0 = dbg(host, "ribbon").shown or 0
	local reveal0 = dbg(host, "reveal").plays or 0
	local pulses0 = (dbg(host, "keys").ring or {}).pulses or 0
	local car = ownedFalse(host, "rev6")
	local id = startCapture(host, car)
	for _, p in { 0.2, 0.5, 0.8, 0.95, 1 } do
		setKeys(host, id, car, p, "Holding")
		host.wait(0.2)
	end
	-- full progress arrives BEFORE the confirmation
	setKeys(host, id, car, 1, "Pending")
	host.wait(0.5)
	local d = dbg(host, "keys")
	local r = d.ring or {}
	local tray1 = if tray and tray.count then tray:count() else 0
	verdict(
		host,
		"Full before confirmation: a calm pending ring",
		d.phase == "Pending"
			and d.instruction == "SECURING…"
			and r.closedVisible == true
			and r.shown == 1
			and r.stepping == false
			and r.pulses == pulses0 + 1
			and near(r.popScale, 1, 0.001)
			and near(r.closedThickness or -1, (r.thickness or 0) + 2, 0.01),
		string.format(
			"phase %s, text %s, closed %s, shown %s, one pulse (+%s), settled scale %s, thickness %s over %s",
			tostring(d.phase),
			tostring(d.instruction),
			tostring(r.closedVisible),
			tostring(r.shown),
			tostring((r.pulses or 0) - pulses0),
			tostring(r.popScale),
			tostring(r.closedThickness),
			tostring(r.thickness)
		)
	)
	verdict(
		host,
		"Nothing is secured yet",
		tray1 == count0
			and (dbg(host, "ribbon").shown or 0) == ribbon0
			and (dbg(host, "reveal").plays or 0) == reveal0
			and d.instruction ~= "SECURED!",
		string.format(
			"tray count %d -> %d, ribbon shown +%s, reveal plays +%s",
			count0,
			tray1,
			tostring((dbg(host, "ribbon").shown or 0) - ribbon0),
			tostring((dbg(host, "reveal").plays or 0) - reveal0)
		)
	)
	-- it holds, still and quiet (the proposal time-out is 8 s)
	host.wait(2.5)
	local held = dbg(host, "keys")
	local hr = held.ring or {}
	verdict(
		host,
		"It holds steady with no pulse or motion",
		held.phase == "Pending"
			and hr.pulses == pulses0 + 1
			and hr.stepping == false
			and near(hr.popScale, 1, 0.001)
			and hr.closedVisible == true
			and held.pulsing == false,
		string.format(
			"phase %s, pulses +%s, stepping %s, scale %s, edge pulse %s",
			tostring(held.phase),
			tostring((hr.pulses or 0) - pulses0),
			tostring(hr.stepping),
			tostring(hr.popScale),
			tostring(held.pulsing)
		)
	)
	-- duplicate full values change nothing
	setKeys(host, id, car, 1, "Pending")
	setKeys(host, id, car, 1, "Holding")
	host.wait(0.3)
	verdict(
		host,
		"Repeated full values add no pulse",
		(dbg(host, "keys").ring or {}).pulses == pulses0 + 1,
		"pulses +" .. tostring(((dbg(host, "keys").ring or {}).pulses or 0) - pulses0)
	)
	-- the explicit confirmation hands off
	send(host, "KeysConfirmed", { captureId = id, car = car })
	host.wait(0.1)
	local handed = dbg(host, "keys")
	verdict(
		host,
		"The confirmation hands off with the ring still full",
		handed.phase == "Confirmed" and (handed.ring or {}).closedVisible == true and handed.instruction == "",
		string.format(
			"phase %s, closed %s, text %q",
			tostring(handed.phase),
			tostring((handed.ring or {}).closedVisible),
			tostring(handed.instruction)
		)
	)
	host.wait(1.4)
	local after = dbg(host, "keys")
	verdict(
		host,
		"Then the ring is gone and nothing runs",
		after.showing == false and after.groupVisible == false and after.connections == 0 and after.timers == 0,
		string.format(
			"showing %s, visible %s, connections %s, timers %s",
			tostring(after.showing),
			tostring(after.groupVisible),
			tostring(after.connections),
			tostring(after.timers)
		)
	)
	host.log(
		string.format(
			"INFO Keys pending: tray count %d after the confirmation (the tray is the claim tray's own business)",
			if tray and tray.count then tray:count() else -1
		)
	)
	host.api.setSpeed(nil)
end

S["Keys: cancel, lose and reset cleanup"] = function(host: Host)
	host.api.setProfile("Desktop")
	host.api.setSpeed(0)
	freshRun(host)
	host.api.backdrop.hold(0)
	local baseline = warmUp(host)
	host.log("INFO Keys cleanup: baseline " .. tostring(baseline) .. " instances in the Keys layer")
	local car = ownedFalse(host, "rev6")
	local variants: { { name: string, progress: number, run: (id: string) -> () } } = {
		{
			name = "keys status Canceled",
			progress = 0.9,
			run = function(id: string)
				setKeys(host, id, car, 0.9, "Canceled", "HoppedOff")
			end,
		},
		{
			name = "keys status Lost",
			progress = 0.6,
			run = function(id: string)
				setKeys(host, id, car, 0.6, "Lost")
			end,
		},
		{
			name = "KeysCanceled event",
			progress = 0.85,
			run = function(id: string)
				send(host, "KeysCanceled", { captureId = id, reason = "HoppedOff" })
			end,
		},
		{
			name = "the meter removed",
			progress = 0.4,
			run = function(_: string)
				clearKeys(host)
			end,
		},
		{
			name = "cancelled while pending",
			progress = 1,
			run = function(id: string)
				send(host, "KeysCanceled", { captureId = id, reason = "HoppedOff" })
			end,
		},
		{
			name = "the run left (mode change)",
			progress = 0.8,
			run = function(_: string)
				host.store:setMode("Home")
			end,
		},
	}
	for _, v in variants do
		if host.store:get().mode ~= "Run" then
			freshRun(host)
			host.api.backdrop.hold(0)
		end
		local id = startCapture(host, car)
		for _, p in { v.progress * 0.5, v.progress } do
			setKeys(host, id, car, p, "Holding")
			host.wait(0.2)
		end
		if v.name == "cancelled while pending" then
			setKeys(host, id, car, 1, "Pending")
			host.wait(0.4)
		end
		local during = dbg(host, "keys")
		v.run(id)
		local d = settle(host)
		local r = d.ring or {}
		-- two reads apart: nothing animates any more (a leftover tween would move one of these)
		local a = { r.popScale, r.closedThickness, r.shown, r.keyRotation, r.rightRotation, r.leftRotation }
		host.wait(0.3)
		local r2 = dbg(host, "keys").ring or {}
		local b = { r2.popScale, r2.closedThickness, r2.shown, r2.keyRotation, r2.rightRotation, r2.leftRotation }
		local quiet = true
		for i = 1, #a do
			if a[i] ~= b[i] then
				quiet = false
			end
		end
		verdict(
			host,
			"Clean after: " .. v.name,
			d.showing == false
				and d.groupVisible == false
				and d.connections == 0
				and d.timers == 0
				and r.stepping == false
				and d.instances == baseline
				and d.rising == false
				and quiet,
			string.format(
				"was showing with %s connection(s); after: showing %s, visible %s, connections %s, timers %s, ease %s, instances %s of %s, rising %s, still %s",
				tostring(during.connections),
				tostring(d.showing),
				tostring(d.groupVisible),
				tostring(d.connections),
				tostring(d.timers),
				tostring(r.stepping),
				tostring(d.instances),
				tostring(baseline),
				tostring(d.rising),
				tostring(quiet)
			)
		)
	end
	host.api.setSpeed(nil)
end

S["Keys: reduced motion"] = function(host: Host)
	host.api.setProfile("Desktop")
	host.api.setSpeed(0)
	freshRun(host)
	host.api.backdrop.hold(0)
	Motion.setOverride(true)
	host.wait(0.6) -- the preview override is picked up by the component
	local pulses0 = (dbg(host, "keys").ring or {}).pulses or 0
	local car = ownedFalse(host, "rev6")
	local id = startCapture(host, car)
	host.wait(0.3)
	setKeys(host, id, car, 0.4, "Holding")
	host.wait(0.06)
	local mid = dbg(host, "keys").ring or {}
	verdict(
		host,
		"Reduced motion: a supplied value is shown at once",
		near(mid.shown or -1, 0.4, 1e-6) and mid.stepping == false,
		string.format("shown %s, ease connection %s", tostring(mid.shown), tostring(mid.stepping))
	)
	setKeys(host, id, car, 1, "Holding")
	host.wait(0.25)
	local full = dbg(host, "keys").ring or {}
	verdict(
		host,
		"Reduced motion: full is a steady brighter, thicker ring and no pulse",
		full.closedVisible == true
			and full.pulses == pulses0
			and near(full.popScale or -1, 1, 1e-6)
			and near(full.closedThickness or -1, (full.thickness or 0) + 2, 0.01)
			and full.closedColour ~= full.fillColour
			and full.stepping == false,
		string.format(
			"closed %s, pulses +%s, scale %s, thickness %s over %s, colour %s against %s",
			tostring(full.closedVisible),
			tostring((full.pulses or 0) - pulses0),
			tostring(full.popScale),
			tostring(full.closedThickness),
			tostring(full.thickness),
			tostring(full.closedColour),
			tostring(full.fillColour)
		)
	)
	setKeys(host, id, car, 1, "Pending")
	host.wait(0.8)
	local pending = dbg(host, "keys")
	local pr = pending.ring or {}
	verdict(
		host,
		"Reduced motion: pending holds the same steady ring",
		pending.phase == "Pending"
			and pending.instruction == "SECURING…"
			and pr.pulses == pulses0
			and near(pr.closedThickness or -1, (pr.thickness or 0) + 2, 0.01)
			and pending.pulsing == false,
		string.format(
			"phase %s, text %s, pulses +%s, pulsing %s",
			tostring(pending.phase),
			tostring(pending.instruction),
			tostring((pr.pulses or 0) - pulses0),
			tostring(pending.pulsing)
		)
	)
	send(host, "KeysConfirmed", { captureId = id, car = car })
	host.wait(1.2)
	Motion.setOverride(nil)
	host.api.setSpeed(nil)
end

S["Keys: repeated start and cancel"] = function(host: Host)
	host.api.setProfile("Desktop")
	host.api.setSpeed(0)
	freshRun(host)
	host.api.backdrop.hold(0)
	local baseline = warmUp(host)
	local car = ownedFalse(host, "rev6")
	local worstConnections, instancesOff, ends = 0, 0, 0
	for i = 1, 20 do
		local id = startCapture(host, car)
		setKeys(host, id, car, 0.35, "Holding")
		host.wait(0.12)
		setKeys(host, id, car, 0.8, "Holding")
		host.wait(0.12)
		local mid = dbg(host, "keys")
		worstConnections = math.max(worstConnections, mid.connections or 0)
		local kind = i % 4
		if kind == 1 then
			setKeys(host, id, car, 0.8, "Canceled", "HoppedOff")
		elseif kind == 2 then
			send(host, "KeysCanceled", { captureId = id, reason = "HoppedOff" })
		elseif kind == 3 then
			setKeys(host, id, car, 0.8, "Lost")
		else
			clearKeys(host)
		end
		host.wait(0.15)
		local after = dbg(host, "keys")
		if after.instances ~= baseline then
			instancesOff += 1
		end
		if after.phase ~= "Idle" and (after.rank or 0) >= 3 then
			ends += 1
		end
	end
	local final = settle(host)
	verdict(
		host,
		"Twenty rounds: nothing left running",
		final.showing == false
			and final.groupVisible == false
			and final.connections == 0
			and final.timers == 0
			and (final.ring or {}).stepping == false,
		string.format(
			"showing %s, connections %s, timers %s, ease %s",
			tostring(final.showing),
			tostring(final.connections),
			tostring(final.timers),
			tostring((final.ring or {}).stepping)
		)
	)
	verdict(
		host,
		"Twenty rounds: no instance leaked",
		instancesOff == 0 and final.instances == baseline,
		string.format(
			"%d of 20 rounds off the baseline of %s, now %s",
			instancesOff,
			tostring(baseline),
			tostring(final.instances)
		)
	)
	verdict(
		host,
		"Twenty rounds: at most three connections at once, every capture ended",
		worstConnections <= 3 and ends == 20 and (final.finals or 0) <= 64,
		string.format(
			"most connections at once %d (follow, ease, pulse), %d of 20 ended, %s remembered",
			worstConnections,
			ends,
			tostring(final.finals)
		)
	)
	host.api.setSpeed(nil)
end

return S
