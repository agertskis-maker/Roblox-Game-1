--!strict
-- PLAYGROUND ONLY (Lane 3 Round 2 R2-R1, revised for Round 3 R3-D): distance pill and district scenarios. Every value
-- is a synthetic fixture played through the preview store (explicit unequal district lengths from WorldRoutes). The
-- fixture speed is set to 0 so each scenario owns the distance, and the scenario sends the DistrictEnter events that
-- Lane 1 would send at each boundary crossing.
--
-- Round 3: the route line (stations, marker, LAP tag, BEST badge, NEW BEST) was removed, so its scenarios are gone. What
-- stays true, per World: the pill names the area AHEAD and the metres to it, the shown distance only grows, an area is
-- entered once per (cycle, district) however often a boundary is crossed, and the arrival popup never replays. The
-- personal-best maths (RouteMath.record / crossed) is kept as pure domain code and is tested here without any overlay.

local Players = game:GetService("Players")

local Prototype = Players.LocalPlayer
	:WaitForChild("PlayerScripts")
	:WaitForChild("Client")
	:WaitForChild("UI")
	:WaitForChild("Prototype")
local Motion = require(Prototype:WaitForChild("Motion"))
local RouteLine = require(Prototype:WaitForChild("Run"):WaitForChild("RouteLine"))
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

	-- A full cycle into the second one: the pill names the area ahead (never the current one), the distance
	-- continues, an area is entered once.
	S["Route: full cycle (" .. world.name .. ")"] = function(host: Host)
		local plan = WorldRoutes.plan(id)
		local sum = total(plan)
		host.api.setSpeed(0)
		host.api.setRecord(nil, nil)
		host.api.setWorld(id)
		freshRun(host)
		host.api.setWorld(id)
		host.wait(0.3)
		local first = state(host)
		verdict(
			host,
			id .. " names the area ahead",
			first.kind == "Upcoming" and first.areaText == plan.districts[2].name and first.nameFits == true,
			string.format(
				"kind %s, area %q (expected %q)",
				tostring(first.kind),
				tostring(first.areaText),
				plan.districts[2].name
			)
		)
		verdict(
			host,
			id .. " says how far",
			string.find(tostring(first.hintText), "^Next in ") ~= nil,
			tostring(first.hintText)
		)
		advance(host, plan, 0, sum * 0.999, 14, 0.05)
		local late = state(host)
		verdict(
			host,
			id .. " last district looks ahead to the first (never shows itself as next)",
			late.index == 5
				and late.cycle == 1
				and late.areaId == plan.districts[1].id
				and late.areaId ~= plan.districts[5].id,
			string.format("index %s, ahead %s", tostring(late.index), tostring(late.areaId))
		)
		host.wait(0.5)
		advance(host, plan, sum * 0.999, sum * 1.35, 10, 0.05)
		host.wait(0.4)
		local after = state(host)
		verdict(
			host,
			id .. " second cycle",
			after.cycle == 2,
			string.format(
				"cycle %s, index %s, ahead %s",
				tostring(after.cycle),
				tostring(after.index),
				tostring(after.areaText)
			)
		)
		verdict(
			host,
			id .. " total distance continues",
			after.distance >= sum * 1.35 - 1e-6
				and after.distanceText == RouteLine.distanceText(math.floor(after.distance)),
			string.format("shown %q for %.0f of cycle length %.0f", tostring(after.distanceText), after.distance, sum)
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
end

-- The personal-best maths is domain code with no overlay caller any more: tested as pure functions (none, inside
-- the cycle, ahead, behind, the first stretch, and the once-per-crossing edge).
S["Route: record maths (pure)"] = function(host: Host)
	local plan = WorldRoutes.plan("Downtown")
	local sum = total(plan)
	local function kind(record: number?, distance: number): string
		return RouteMath.record(plan, record, distance).kind
	end
	verdict(host, "No prior best", kind(nil, 120) == "None" and kind(0, 120) == "None", kind(nil, 120))
	verdict(
		host,
		"Record inside the cycle",
		kind(math.floor(sum * 0.6), 120) == "Inside",
		kind(math.floor(sum * 0.6), 120)
	)
	verdict(
		host,
		"Record beyond this cycle",
		kind(math.floor(sum * 2.4), 120) == "Ahead",
		kind(math.floor(sum * 2.4), 120)
	)
	verdict(
		host,
		"Record below the second cycle",
		kind(math.floor(sum * 0.3), sum + 140) == "Behind",
		kind(math.floor(sum * 0.3), sum + 140)
	)
	verdict(host, "Record in the first stretch", kind(25, 400) == "Inside", kind(25, 400))
	verdict(
		host,
		"Crossing edge",
		RouteMath.crossed(99, 101, 100)
			and not RouteMath.crossed(101, 150, 100)
			and not RouteMath.crossed(99, 99.5, 100),
		"crossed(99,101,100) true, crossed(101,150,100) false"
	)
	verdict(host, "NaN is not a record", not RouteMath.crossed(0 / 0, 5, 0 / 0), "no crossing")
end

-- Reordered and repeated updates: no popup replay, no arrival replay, the shown distance never moves back.
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
		"Popups do not replay",
		shown() == bannersBefore,
		string.format("%s -> %s", tostring(bannersBefore), tostring(shown()))
	)
	verdict(
		host,
		"Distance never moved back",
		after.distance >= 345 - 1e-6,
		string.format("distance %s after a drop to 318", tostring(after.distance))
	)
	host.api.setSpeed(nil)
end

return S
