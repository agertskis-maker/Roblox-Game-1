--!strict
-- PLAYGROUND ONLY (Lane 3 Round 2, R2-R1 / R2-R2): route line scenarios. Every value is a synthetic fixture
-- played through the preview store (explicit unequal district lengths from WorldRoutes; the personal best is a
-- supplied number, never saved). The fixture speed is set to 0 so each scenario owns the distance, and the
-- scenario sends the DistrictEnter events that Lane 1 would send at each boundary crossing.
--
-- Per World: a full cycle into the second one (lap tag, sweep back, total distance continues), a record
-- crossing (NEW BEST once, also across later oscillation and a second cycle), then the static record cases and
-- the reordered / repeated update case. Each logs the debug numbers it checks and a PASS / FAIL line.

local Players = game:GetService("Players")

local Prototype = Players.LocalPlayer
	:WaitForChild("PlayerScripts")
	:WaitForChild("Client")
	:WaitForChild("UI")
	:WaitForChild("Prototype")
local Motion = require(Prototype:WaitForChild("Motion"))
local RouteMath = require(Prototype:WaitForChild("Run"):WaitForChild("RouteMath"))
local WorldRoutes = require(script.Parent.Parent:WaitForChild("WorldRoutes"))

type Host = { [string]: any }

local function comp(host: Host, key: string): any
	return host.api.components and host.api.components[key]
end

local function line(host: Host): any
	return comp(host, "routeLine")
end

local function state(host: Host): { [string]: any }
	local c = line(host)
	return if c and c.getDebugState then c:getDebugState() else {}
end

local function freshRun(host: Host)
	local store = host.store
	Motion.setOverride(nil)
	if store:get().mode == "Run" then
		store:setMode("Home")
	end
	host.enterRun()
	host.wait(0.4)
end

local function setDistance(host: Host, distance: number)
	host.runPatch({ distance = distance })
end

-- Moves the run to `target` in steps, sending DistrictEnter whenever a (cycle, district) is entered, the way
-- the production source would.
local function advance(host: Host, plan: any, from: number, target: number, step: number, interval: number)
	local at = from
	local previous = RouteMath.locate(plan, at)
	while at < target do
		at = math.min(at + step, target)
		setDistance(host, at)
		local loc = RouteMath.locate(plan, at)
		if loc and previous and (loc.index ~= previous.index or loc.cycle ~= previous.cycle) then
			host.emit("DistrictEnter", { district = plan.districts[loc.index].id, cycle = loc.cycle })
		end
		previous = loc
		host.wait(interval)
	end
end

local function verdict(host: Host, name: string, ok: boolean, detail: string)
	host.log(string.format("%s %s: %s", if ok then "PASS" else "FAIL", name, detail))
end

local function total(plan: any): number
	return RouteMath.total(plan)
end

local S: { [string]: (Host) -> () } = {}

for _, id in WorldRoutes.ids do
	local world = WorldRoutes.worlds[id]

	-- A full cycle into the second one: stations, arrivals, lap tag, total distance continues.
	S["Route: full cycle and lap (" .. world.name .. ")"] = function(host: Host)
		local plan = WorldRoutes.plan(id)
		local sum = total(plan)
		host.api.setSpeed(0)
		host.api.setRecord(nil, nil)
		host.api.setWorld(id)
		freshRun(host)
		host.api.setWorld(id)
		host.wait(0.3)
		local first = state(host)
		verdict(host, id .. " stations", #first.stations == 5, "stations " .. tostring(#first.stations))
		advance(host, plan, 0, sum * 0.999, 14, 0.05)
		local late = state(host)
		verdict(host, id .. " last district", late.index == 5 and late.cycle == 1, "index " .. tostring(late.index))
		host.wait(0.5)
		advance(host, plan, sum * 0.999, sum * 1.35, 10, 0.05)
		host.wait(0.8)
		local after = state(host)
		verdict(
			host,
			id .. " second cycle",
			after.cycle == 2 and after.lap == "LAP 2" and after.lapWraps - first.lapWraps == 1,
			string.format(
				"cycle %s, tag %s, wraps %s",
				tostring(after.cycle),
				tostring(after.lap),
				tostring(after.lapWraps - first.lapWraps)
			)
		)
		verdict(
			host,
			id .. " total distance continues",
			after.distance >= sum * 1.35 - 1e-6,
			string.format("callout distance %.0f of total %.0f", after.distance, sum)
		)
		local endLoc = RouteMath.locate(plan, sum * 1.35) :: any
		local expected = (endLoc.cycle - 1) * #plan.districts + endLoc.index - 1
		verdict(
			host,
			id .. " arrivals once per district",
			after.arrivals - first.arrivals == expected,
			string.format(
				"arrivals %s of the expected %s",
				tostring(after.arrivals - first.arrivals),
				tostring(expected)
			)
		)
		host.api.setSpeed(nil)
	end

	-- Record inside the cycle: crossing fires NEW BEST once, even across oscillation and a second cycle.
	S["Route: record crossing (" .. world.name .. ")"] = function(host: Host)
		local plan = WorldRoutes.plan(id)
		local sum = total(plan)
		local record = math.floor(sum * 0.55)
		host.api.setSpeed(0)
		host.api.setRecord(record, true)
		host.api.setWorld(id)
		freshRun(host)
		host.api.setWorld(id)
		host.wait(0.3)
		local s0 = state(host)
		local base = s0.newBestCount
		verdict(host, id .. " marker at its distance", s0.record == "Inside" and s0.recordMarker == true, s0.record)
		advance(host, plan, 0, record - 6, 12, 0.05)
		verdict(
			host,
			id .. " before the record",
			state(host).newBestCount == base,
			"NEW BEST count " .. tostring(state(host).newBestCount - base)
		)
		advance(host, plan, record - 6, record + 30, 6, 0.08)
		host.wait(0.4)
		local crossed = state(host)
		verdict(
			host,
			id .. " NEW BEST once",
			crossed.newBestCount - base == 1 and crossed.newBest == true,
			"count " .. tostring(crossed.newBestCount - base)
		)
		-- the same crossing again from below (an oscillating update stream) must not fire again
		for _ = 1, 3 do
			setDistance(host, record - 20)
			host.wait(0.15)
			setDistance(host, record + 20)
			host.wait(0.15)
		end
		verdict(
			host,
			id .. " no replay on oscillation",
			state(host).newBestCount - base == 1,
			"count " .. tostring(state(host).newBestCount - base)
		)
		advance(host, plan, record + 20, sum * 1.3, 14, 0.05)
		host.wait(0.4)
		verdict(
			host,
			id .. " no replay in the second cycle",
			state(host).newBestCount - base == 1,
			"count " .. tostring(state(host).newBestCount - base)
		)
		host.api.setSpeed(nil)
		host.api.setRecord(nil, nil)
	end
end

-- Static record cases (Downtown): none, inside, ahead, behind, below the start, unverified.
S["Route: record cases"] = function(host: Host)
	local plan = WorldRoutes.plan("Downtown")
	local sum = total(plan)
	host.api.setSpeed(0)
	host.api.setWorld("Downtown")
	local function hold(name: string, distance: number, record: number?, verified: boolean?, expect: string)
		host.api.setRecord(record, verified)
		freshRun(host) -- the run keeps its furthest distance, so each case is its own run
		setDistance(host, distance)
		host.wait(1.2)
		local s = state(host)
		verdict(
			host,
			name,
			s.record == expect,
			string.format(
				"record %s, label %q, marker %s, delta %s",
				tostring(s.record),
				tostring(s.recordText),
				tostring(s.recordMarker),
				tostring(s.recordDelta)
			)
		)
	end
	hold("No prior best", 120, nil, nil, "None")
	hold("Record inside the cycle (ahead of you)", 120, math.floor(sum * 0.6), true, "Inside")
	hold("Record inside the cycle (behind you)", math.floor(sum * 0.8), math.floor(sum * 0.3), true, "Inside")
	hold("Record beyond this cycle", 120, math.floor(sum * 2.4), true, "Ahead")
	hold("Record below this cycle (second cycle)", sum + 140, math.floor(sum * 0.3), true, "Behind")
	hold("Record in the first stretch", 400, 25, true, "Inside")
	-- an unverified record is still shown, but no NEW BEST moment fires
	host.api.setRecord(math.floor(sum * 0.5), false)
	freshRun(host)
	local base = state(host).newBestCount
	setDistance(host, math.floor(sum * 0.45))
	host.wait(0.6)
	advance(host, plan, math.floor(sum * 0.45), math.floor(sum * 0.65), 8, 0.05)
	verdict(
		host,
		"Unverified record: no NEW BEST",
		state(host).newBestCount == base,
		"count " .. tostring(state(host).newBestCount - base)
	)
	host.api.setSpeed(nil)
	host.api.setRecord(nil, nil)
end

-- Reordered and repeated updates: no banner replay, no arrival replay, the marker never moves back.
S["Route: reordered and repeated updates"] = function(host: Host)
	local plan = WorldRoutes.plan("Downtown")
	host.api.setSpeed(0)
	host.api.setRecord(nil, nil)
	host.api.setWorld("Downtown")
	freshRun(host)
	local banner = comp(host, "banner")
	local function shown(): number
		return if banner and banner.getDebugState then banner:getDebugState().shown else -1
	end
	advance(host, plan, 0, 330, 15, 0.05) -- into district 3 (City Hall -> Harbor Bridge)
	host.wait(2.4)
	local before = state(host)
	local bannersBefore = shown()
	-- repeated and late events for districts already entered, and a threshold crossed back and forth
	local last = RouteMath.locate(plan, 330) :: any
	for _ = 1, 3 do
		host.emit("DistrictEnter", { district = plan.districts[last.index].id, cycle = 1 })
	end
	host.emit("DistrictEnter", { district = plan.districts[2].id, cycle = 1 })
	for _ = 1, 4 do
		setDistance(host, 318)
		host.wait(0.12)
		setDistance(host, 345)
		host.wait(0.12)
	end
	host.wait(2)
	local after = state(host)
	verdict(
		host,
		"Arrivals do not replay",
		after.arrivals == before.arrivals,
		string.format("%s -> %s", tostring(before.arrivals), tostring(after.arrivals))
	)
	verdict(
		host,
		"Banners do not replay",
		shown() == bannersBefore,
		string.format("%s -> %s", tostring(bannersBefore), tostring(shown()))
	)
	verdict(
		host,
		"Marker never moved back",
		after.distance >= 345 - 1e-6 and after.shownT >= before.shownT - 1e-3,
		string.format("distance %s, shown %.3f -> %.3f", tostring(after.distance), before.shownT, after.shownT)
	)
	host.api.setSpeed(nil)
end

return S
