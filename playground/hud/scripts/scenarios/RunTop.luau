--!strict
-- PLAYGROUND ONLY (Lane 3 Round 3, R3-D and R3-L): the top of the run view. One distance pill (RouteLine), the
-- arrival popup below it (DistrictBanner) and the transient landing label (RideChip) that replaced the permanent riding
-- chip. Every value is a synthetic fixture played through the preview store; the fixture speed is set to 0 so each
-- scenario owns the distance. Each scenario logs PASS: or FAIL: lines (host.log) so the lead can grep them; numbers are
-- logged next to the verdict. Nothing here was run by the worker who wrote it.
--
-- Scenarios: wording, long names and large distances on every frame, stable digits, layout clear on every frame, the
-- popup below the pill, removed pieces absent, landing label (timing, rarity words, one at a time, duplicates, run end,
-- capture hold, reduced motion, long names) and leak checks.

local Players = game:GetService("Players")

local Prototype = Players.LocalPlayer
	:WaitForChild("PlayerScripts")
	:WaitForChild("Client")
	:WaitForChild("UI")
	:WaitForChild("Prototype")
local Run = Prototype:WaitForChild("Run")
local Motion = require(Prototype:WaitForChild("Motion"))
local RideChip = require(Run:WaitForChild("RideChip"))
local RouteLine = require(Run:WaitForChild("RouteLine"))
local RouteMath = require(Run:WaitForChild("RouteMath"))
local RunBus = require(Run:WaitForChild("RunBus"))
local RunLayout = require(Run:WaitForChild("RunLayout"))
local WorldRoutes = require(script.Parent.Parent:WaitForChild("WorldRoutes"))

type Host = { [string]: any }

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

-- collects reasons; one verdict per scenario part
local function check(list: { string }, cond: boolean, why: string)
	if not cond then
		table.insert(list, why)
	end
end

local function report(host: Host, name: string, list: { string }, summary: string)
	verdict(host, name, #list == 0, if #list == 0 then summary else table.concat(list, "; "))
end

local function freshRun(host: Host)
	Motion.setOverride(nil)
	if host.store:get().mode == "Run" then
		host.store:setMode("Home")
	end
	host.enterRun()
	host.wait(0.4)
end

local function patchPlan(host: Host, plan: any, distance: number)
	host.runPatch({ districtPlan = plan, distance = distance })
end

local WORLD_INFO = { id = "Downtown", name = "Downtown", colour = Color3.fromRGB(52, 168, 255) }

-- four of the longest names, 30,000 m each: 5-digit metres to go, and past 100,000 m the km format
local LONG_PLAN = {
	repeats = true,
	world = WORLD_INFO,
	districts = {
		{ id = "RedRockArches", name = "Red Rock Arches", short = "Arches", length = 30000 },
		{ id = "MirageDunes", name = "Mirage Dunes", short = "Dunes", length = 30000 },
		{ id = "GlacierTunnel", name = "Glacier Tunnel", short = "Glacier", length = 30000 },
		{ id = "SummitLodge", name = "Summit Lodge", short = "Lodge", length = 30000 },
	},
}

-- widest numbers: 99,999 m still to go at distance 1, and a distance of 99,999 m
local WIDE_PLAN = {
	repeats = true,
	world = WORLD_INFO,
	districts = {
		{ id = "RedRockArches", name = "Red Rock Arches", short = "Arches", length = 100000 },
		{ id = "SummitLodge", name = "Summit Lodge", short = "Lodge", length = 100000 },
	},
}

local function copyPlan(plan: any): any
	return table.clone(plan)
end

local S: { [string]: (Host) -> () } = {}

-- WORDING --------------------------------------------------------------------------------------

S["RunTop: pill wording (current and upcoming)"] = function(host: Host)
	local plan = WorldRoutes.plan("Downtown")
	local list: { string } = {}
	-- pure: the area AHEAD with the metres to it
	local p0 = RouteLine.describe(plan, 0) :: any
	check(
		list,
		p0.kind == "Upcoming" and p0.area == "City Hall" and p0.hint == "Next in 170 m" and p0.distance == "0 m",
		"start " .. tostring(p0.area) .. " / " .. tostring(p0.hint)
	)
	local p1 = RouteLine.describe(plan, 169.2) :: any
	check(
		list,
		p1.hint == "Next in 1 m" and p1.distance == "169 m",
		"just before a boundary " .. tostring(p1.hint) .. " / " .. tostring(p1.distance)
	)
	local p2 = RouteLine.describe(plan, 170) :: any
	check(
		list,
		p2.areaId == "HarborBridge" and p2.hint == "Next in 150 m",
		"at the boundary the NEXT area moves on: " .. tostring(p2.areaId)
	)
	-- the last area of a repeating plan looks ahead to the first (never names itself as next)
	local sum = RouteMath.total(plan)
	local pl = RouteLine.describe(plan, sum - 10) :: any
	check(
		list,
		pl.kind == "Upcoming" and pl.areaId == "MainStreet" and pl.index == 5,
		"wraps to the first: " .. tostring(pl.areaId)
	)
	-- a plan that does not repeat: nothing lies ahead, so the pill names the area the run is in, plainly
	local once = copyPlan(plan)
	once.repeats = false
	local pc = RouteLine.describe(once, sum - 10) :: any
	check(
		list,
		pc.kind == "Current" and pc.areaId == "SkylinePark" and pc.hint == "You are here" and pc.toNext == nil,
		"current: " .. tostring(pc.kind) .. " " .. tostring(pc.hint)
	)
	local pe = RouteLine.describe(once, sum * 3) :: any
	check(
		list,
		pe.kind == "Current" and pe.areaId == "SkylinePark",
		"past the end of a plan that does not repeat: " .. tostring(pe.kind)
	)
	-- units and odd numbers
	check(list, RouteLine.distanceText(821) == "821 m" and RouteLine.distanceText(12345.9) == "12,345 m", "metres")
	check(
		list,
		RouteLine.distanceText(99999.9) == "99,999 m" and RouteLine.distanceText(100000) == "100.0 km",
		"km from 100,000 m: " .. RouteLine.distanceText(100000)
	)
	check(
		list,
		RouteLine.distanceText(0 / 0) == "0 m"
			and RouteLine.distanceText(-5) == "0 m"
			and RouteLine.distanceText(math.huge) ~= "",
		"NaN, negative, infinite"
	)
	report(
		host,
		"Pill wording (pure)",
		list,
		string.format("start %q / %q, wrap %s, current %q", p0.area, p0.hint, pl.areaId, pc.hint)
	)

	-- live: the same words on the real pill
	host.api.setSpeed(0)
	host.api.setWorld("Downtown")
	freshRun(host)
	host.api.setWorld("Downtown")
	host.wait(0.3)
	local live: { string } = {}
	local s = dbg(host, "routeLine")
	check(
		live,
		s.shown == true and s.kind == "Upcoming" and s.areaText == "City Hall" and s.hintText == "Next in 170 m",
		string.format("%s %q %q", tostring(s.kind), tostring(s.areaText), tostring(s.hintText))
	)
	patchPlan(host, once, sum * 3)
	host.wait(0.3)
	local c = dbg(host, "routeLine")
	check(
		live,
		c.kind == "Current" and c.areaText == "Skyline Park" and c.hintText == "You are here",
		string.format("%s %q %q", tostring(c.kind), tostring(c.areaText), tostring(c.hintText))
	)
	patchPlan(host, plan, sum * 3)
	host.wait(0.3)
	local u = dbg(host, "routeLine")
	check(
		live,
		u.kind == "Upcoming" and u.hintText ~= "You are here",
		string.format("%s %q", tostring(u.kind), tostring(u.hintText))
	)
	-- NaN and infinity never reach the number
	local shownBefore = u.distanceText
	host.runPatch({ distance = 0 / 0 })
	host.wait(0.2)
	host.runPatch({ distance = math.huge })
	host.wait(0.2)
	host.runPatch({ distance = sum * 3 }) -- a real number again before anything else reads the run
	check(
		live,
		dbg(host, "routeLine").distanceText ~= nil and dbg(host, "routeLine").distanceText == shownBefore,
		"NaN or infinity changed the number to " .. tostring(dbg(host, "routeLine").distanceText)
	)
	report(
		host,
		"Pill wording (live)",
		live,
		string.format("upcoming %q, current %q", tostring(s.hintText), tostring(c.hintText))
	)
	host.api.setSpeed(nil)
end

-- LONG NAMES AND LARGE DISTANCES, ON EVERY FRAME -------------------------------------------------

local function boxesFit(s: { [string]: any }): (boolean, string)
	local d, a, h = s.distanceBox, s.areaBox, s.hintBox
	local ok = d ~= nil and a ~= nil and h ~= nil and d.fits and a.fits and h.fits
	return ok,
		string.format(
			"distance %s/%s, area %s/%s, hint %s/%s",
			d and string.format("%.1f", d.boundsX) or "?",
			d and string.format("%.1f", d.boxX) or "?",
			a and string.format("%.1f", a.boundsX) or "?",
			a and string.format("%.1f", a.boxX) or "?",
			h and string.format("%.1f", h.boundsX) or "?",
			h and string.format("%.1f", h.boxX) or "?"
		)
end

S["RunTop: pill long names and big numbers on every frame"] = function(host: Host)
	host.api.setSpeed(0)
	for _, profile in host.api.profiles do
		host.api.setProfile(profile)
		host.wait(0.3)
		freshRun(host)
		local list: { string } = {}
		local worst = ""
		-- four district names ahead with 5-digit metres to go (and the km format past 100,000 m)
		patchPlan(host, LONG_PLAN, 12345)
		for k = 1, 4 do
			local distance = (k - 1) * 30000 + 12345
			host.runPatch({ distance = distance })
			host.wait(0.25)
			local s = dbg(host, "routeLine")
			local expected = LONG_PLAN.districts[(k % 4) + 1].name
			local fits, numbers = boxesFit(s)
			check(
				list,
				s.areaText == expected and s.nameFits == true,
				string.format("k%d area %q for %q", k, tostring(s.areaText), expected)
			)
			check(list, fits, string.format("k%d text wider than its box (%s)", k, numbers))
			check(
				list,
				s.areaBox ~= nil and s.areaBox.size >= 16 and s.hintBox.size >= 16 and s.distanceBox.size >= 16,
				string.format("k%d text under 16 px", k)
			)
			check(
				list,
				s.areaText ~= nil
					and string.find(s.areaText, "%.%.%.") == nil
					and string.find(s.hintText, "%.%.%.") == nil,
				"ellipsis"
			)
			worst = string.format(
				"%s | %s %q %q %q",
				worst,
				expected,
				tostring(s.distanceText),
				tostring(s.areaText),
				tostring(s.hintText)
			)
		end
		-- the widest hint (99,999 m to go) and the widest distance (99,999 m), then 100,000 m in km
		freshRun(host)
		patchPlan(host, WIDE_PLAN, 1)
		host.wait(0.25)
		local a = dbg(host, "routeLine")
		check(list, a.hintText == "Next in 99,999 m", "widest hint " .. tostring(a.hintText))
		check(list, (boxesFit(a)), "widest hint does not fit")
		host.runPatch({ distance = 99999 })
		host.wait(0.25)
		local b = dbg(host, "routeLine")
		check(list, b.distanceText == "99,999 m" and (boxesFit(b)), "widest distance " .. tostring(b.distanceText))
		host.runPatch({ distance = 100000 })
		host.wait(0.25)
		local c = dbg(host, "routeLine")
		check(list, c.distanceText == "100.0 km" and (boxesFit(c)), "km " .. tostring(c.distanceText))
		check(
			list,
			c.width == RunLayout.routeGeometry().size.X and c.height == RunLayout.Route.Height,
			"pill size changed"
		)
		report(
			host,
			"Pill long names / big numbers, " .. profile,
			list,
			string.format("4 names + widest numbers fit; %s | %s %s", worst, a.hintText, b.distanceText)
		)
	end
	host.api.setProfile("Desktop")
	host.api.setSpeed(nil)
end

-- DIGITS DO NOT MOVE ANYTHING ----------------------------------------------------------------------

S["RunTop: pill is stable while digits tick"] = function(host: Host)
	host.api.setSpeed(0)
	local list: { string } = {}
	for _, profile in { "Desktop", "PhoneSmall" } do
		host.api.setProfile(profile)
		host.wait(0.3)
		freshRun(host)
		patchPlan(host, WIDE_PLAN, 8)
		host.wait(0.25)
		local line = comp(host, "routeLine")
		local pill = line.root:FindFirstChild("Pill", true)
		local function geometry(): string
			local parts = {}
			for _, name in { "Pill", "Distance", "Area", "Hint", "Divider" } do
				local g = line.root:FindFirstChild(name, true) :: GuiObject?
				table.insert(
					parts,
					g
							and string.format(
								"%s %.2f,%.2f %.2f,%.2f",
								name,
								g.AbsolutePosition.X,
								g.AbsolutePosition.Y,
								g.AbsoluteSize.X,
								g.AbsoluteSize.Y
							)
						or name .. " missing"
				)
			end
			return table.concat(parts, " | ")
		end
		local first = geometry()
		local seen = 0
		for _, d in { 9, 10, 99, 100, 999, 1000, 9999, 10000 } do
			host.runPatch({ distance = d })
			host.wait(0.2)
			seen += 1
			check(list, geometry() == first, string.format("%s: boxes moved at %d m", profile, d))
		end
		check(list, pill ~= nil, "no pill")
		-- tabular digits: strings with the same number of digits are the same width (the kit's number face)
		freshRun(host)
		patchPlan(host, WIDE_PLAN, 111)
		host.wait(0.25)
		local widths: { number } = {}
		local hints: { number } = {}
		for _, d in { 111, 222, 808, 999 } do
			host.runPatch({ distance = d })
			host.wait(0.2)
			local s = dbg(host, "routeLine")
			table.insert(widths, s.distanceBox.boundsX)
			table.insert(hints, s.hintBox.boundsX)
		end
		for i = 2, #widths do
			check(
				list,
				math.abs(widths[i] - widths[1]) <= 0.5,
				string.format("%s: distance width %.2f vs %.2f", profile, widths[i], widths[1])
			)
			check(
				list,
				math.abs(hints[i] - hints[1]) <= 0.5,
				string.format("%s: hint width %.2f vs %.2f", profile, hints[i], hints[1])
			)
		end
		host.log(
			string.format(
				"Pill digits %s: distance widths %.2f %.2f %.2f %.2f, hint widths %.2f %.2f %.2f %.2f",
				profile,
				widths[1],
				widths[2],
				widths[3],
				widths[4],
				hints[1],
				hints[2],
				hints[3],
				hints[4]
			)
		)
	end
	report(
		host,
		"Pill stable (boxes fixed, digits tabular)",
		list,
		"boxes identical at 9, 10, 99, 100, 999, 1,000, 9,999, 10,000 m; same-length numbers are the same width"
	)
	host.api.setProfile("Desktop")
	host.api.setSpeed(nil)
end

-- CONTRAST ---------------------------------------------------------------------------------------

local function channel(c: number): number
	return if c <= 0.03928 then c / 12.92 else ((c + 0.055) / 1.055) ^ 2.4
end

local function luminance(c: Color3): number
	return 0.2126 * channel(c.R) + 0.7152 * channel(c.G) + 0.0722 * channel(c.B)
end

local function ratio(a: Color3, b: Color3): number
	local la, lb = luminance(a), luminance(b)
	return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05)
end

-- the pill sits over any backdrop: the worst case is a white one showing through its small transparency
S["RunTop: pill contrast"] = function(host: Host)
	host.api.setSpeed(0)
	freshRun(host)
	local list: { string } = {}
	local line = comp(host, "routeLine")
	local pill = line.root:FindFirstChild("Pill", true) :: Frame
	local worstFill = pill.BackgroundColor3:Lerp(Color3.new(1, 1, 1), pill.BackgroundTransparency)
	local lowest = math.huge
	local detail: { string } = {}
	local function note(name: string, c: Color3)
		local r = ratio(c, worstFill)
		lowest = math.min(lowest, r)
		table.insert(detail, string.format("%s %.1f", name, r))
		check(list, r >= 7, string.format("%s only %.1f:1", name, r))
	end
	local distance = line.root:FindFirstChild("Distance", true) :: TextLabel
	local gradient = distance:FindFirstChildOfClass("UIGradient")
	check(list, gradient ~= nil, "no gold face on the distance")
	if gradient then
		for i, key in gradient.Color.Keypoints do
			note("distance gold " .. i, key.Value)
		end
	end
	note("area name", (line.root:FindFirstChild("Area", true) :: TextLabel).TextColor3)
	note("hint", (line.root:FindFirstChild("Hint", true) :: TextLabel).TextColor3)
	report(
		host,
		"Pill contrast against the worst backdrop",
		list,
		string.format("all at least 7:1 (%s)", table.concat(detail, ", "))
	)
	host.api.setSpeed(nil)
end

-- LAYOUT -----------------------------------------------------------------------------------------

S["RunTop: layout clear on every frame"] = function(host: Host)
	host.api.setSpeed(0)
	freshRun(host)
	local ctx = comp(host, "routeLine")._ctx
	for _, profile in host.api.profiles do
		host.api.setProfile(profile)
		host.wait(0.35)
		local list: { string } = {}
		local d = RunLayout.design(ctx)
		local pill = RunLayout.routeRect(ctx)
		local cash = RunLayout.cashRect(ctx)
		local gear = RunLayout.gearRect(ctx)
		local prot = RunLayout.protected(ctx)
		local banner = RunLayout.bannerRect(ctx)
		local landing = RunLayout.landingRect(ctx)
		local heat = RunLayout.heatRect(ctx)
		local hop = RunLayout.hopRect(ctx)
		local named: { [string]: any } =
			{ Pill = pill, Cash = cash, Settings = gear, Protected = prot, Popup = banner, Landing = landing }
		check(list, RunLayout.inside(pill, d), "pill outside the canvas")
		check(
			list,
			RunLayout.inside(banner, d) and RunLayout.inside(landing, d),
			"popup or landing label outside the canvas"
		)
		for _, other in { "Cash", "Settings", "Protected", "Landing" } do
			check(list, not RunLayout.overlaps(pill, named[other]), "pill overlaps " .. other)
		end
		for _, other in { "Pill", "Cash", "Settings", "Protected", "Landing" } do
			check(list, not RunLayout.overlaps(banner, named[other]), "popup overlaps " .. other)
		end
		check(list, not RunLayout.overlaps(banner, heat), "popup overlaps Heat")
		for _, other in { "Pill", "Cash", "Settings", "Protected", "Popup" } do
			check(list, not RunLayout.overlaps(landing, named[other]), "landing label overlaps " .. other)
		end
		check(
			list,
			not RunLayout.overlaps(landing, heat) and not RunLayout.overlaps(landing, hop),
			"landing label overlaps Heat or Hop"
		)
		for _, z in RunLayout.zones(ctx) do
			check(
				list,
				not RunLayout.overlaps(pill, z)
					and not RunLayout.overlaps(banner, z)
					and not RunLayout.overlaps(landing, z),
				"touch zone " .. tostring(z.name)
			)
		end
		check(list, banner.pos.Y - (pill.pos.Y + pill.size.Y) >= 8, "popup is not clear of the pill for its entry drop")
		check(list, math.abs(pill.size.X - RunLayout.routeGeometry().size.X) < 0.01, "pill size changed")
		-- the same through the components' own flags
		local s = dbg(host, "routeLine")
		check(
			list,
			s.overlapsProtected == false
				and s.overlapsCash == false
				and s.overlapsGear == false
				and s.overlapsBanner == false,
			"pill flags"
		)
		report(
			host,
			"Layout clear, " .. profile,
			list,
			string.format(
				"pill %s, popup %s, landing %s, gear %s",
				RunLayout.describe(pill),
				RunLayout.describe(banner),
				RunLayout.describe(landing),
				RunLayout.describe(gear)
			)
		)
	end
	host.api.setProfile("Desktop")
	host.api.setSpeed(nil)
end

-- THE ARRIVAL POPUP, BELOW THE PILL -----------------------------------------------------------------

S["RunTop: arrival popup below the pill"] = function(host: Host)
	host.api.setSpeed(0)
	for _, profile in { "Desktop", "PhoneSmall", "Tablet" } do
		host.api.setProfile(profile)
		host.wait(0.3)
		host.api.setWorld("Downtown")
		freshRun(host)
		host.api.setWorld("Downtown")
		host.wait(0.3)
		local line = comp(host, "routeLine")
		local banner = comp(host, "banner")
		local list: { string } = {}
		local before = dbg(host, "banner")
		-- the run is in district 1; the event names it, the way the production source would
		host.emit("DistrictEnter", { district = "MainStreet", cycle = 1 })
		local worstGap = math.huge
		local sawShowing = false
		local started = os.clock()
		while os.clock() - started < 0.9 do
			local pillGui = line.root:FindFirstChild("Pill", true) :: GuiObject?
			local group = banner.root:FindFirstChild("Banner", true) :: GuiObject?
			if pillGui and group and group.Visible then
				sawShowing = true
				local gap = group.AbsolutePosition.Y - (pillGui.AbsolutePosition.Y + pillGui.AbsoluteSize.Y)
				worstGap = math.min(worstGap, gap)
			end
			host.wait(0)
		end
		local after = dbg(host, "banner")
		check(
			list,
			sawShowing and after.shown == before.shown + 1,
			string.format("popup shown %s -> %s", tostring(before.shown), tostring(after.shown))
		)
		check(
			list,
			worstGap >= -0.5,
			string.format("the popup came within %.1f px of the pill (negative = over it)", worstGap)
		)
		check(
			list,
			after.overlapsPill == false
				and after.overlapsProtected == false
				and after.overlapsCash == false
				and after.overlapsHeat == false,
			"popup flags"
		)
		check(
			list,
			after.topWithDrop >= after.pillBottom,
			string.format("drop start %.1f above the pill bottom %.1f", after.topWithDrop, after.pillBottom)
		)
		report(
			host,
			"Popup below the pill, " .. profile,
			list,
			string.format("closest %.1f px (in real GUI pixels) below the pill, shown +1", worstGap)
		)
		host.wait(2)
	end
	host.api.setProfile("Desktop")
	host.api.setSpeed(nil)
end

-- REMOVED PIECES ARE GONE ------------------------------------------------------------------------------

local REMOVED = {
	"Track",
	"Travelled",
	"BestBadge",
	"BestName",
	"BestMarker",
	"Pointer",
	"Marker",
	"Lap",
	"Next",
	"Record",
	"Chip",
	"RidingTag",
	"RarityBar",
	"Pips",
	"FamilyIcon",
}

S["RunTop: removed route and riding pieces are gone"] = function(host: Host)
	host.api.setSpeed(0)
	freshRun(host)
	host.wait(0.3)
	local list: { string } = {}
	local s = dbg(host, "routeLine")
	local r = dbg(host, "ride")
	check(
		list,
		s.imageLabels == 0 and s.viewportFrames == 0,
		string.format("route images %s, viewports %s", tostring(s.imageLabels), tostring(s.viewportFrames))
	)
	check(list, s.routePieces == 0, "route pieces left: " .. tostring(s.routePieces))
	check(
		list,
		s.tweens == 0 and s.threads == 0 and s.renderStepped == false,
		string.format(
			"running pieces: tweens %s, threads %s, per-frame %s",
			tostring(s.tweens),
			tostring(s.threads),
			tostring(s.renderStepped)
		)
	)
	check(list, s.textLabels == 3, "pill text labels " .. tostring(s.textLabels))
	check(
		list,
		r.threads == 0 and r.renderStepped == false and r.tweens == 0,
		string.format("riding pieces: tweens %s, threads %s", tostring(r.tweens), tostring(r.threads))
	)
	-- by name, in the two components' own trees, and no image anywhere under them
	for _, key in { "routeLine", "ride" } do
		local c = comp(host, key)
		for _, d in c.root:GetDescendants() do
			if table.find(REMOVED, d.Name) then
				table.insert(list, key .. " still has " .. d.Name)
			end
			if string.match(d.Name, "^Station%d") or string.match(d.Name, "^Node%d") then
				table.insert(list, key .. " still has " .. d.Name)
			end
			if d:IsA("ImageLabel") or d:IsA("ViewportFrame") then
				table.insert(list, key .. " has an image: " .. d:GetFullName())
			end
		end
	end
	check(list, s.instances <= 24, "pill instances " .. tostring(s.instances))
	-- the old riding text appears nowhere
	local found = false
	for _, d in comp(host, "ride").root:GetDescendants() do
		if d:IsA("TextLabel") and string.find(string.upper(d.Text), "RIDING") then
			found = true
		end
	end
	check(list, not found, "a RIDING text is still drawn")
	report(
		host,
		"Removed pieces absent",
		list,
		string.format(
			"pill instances %s, text labels %s, images 0, tweens 0, threads 0, per-frame connections none; riding chip gone",
			tostring(s.instances),
			tostring(s.textLabels)
		)
	)
	host.api.setSpeed(nil)
end

-- THE LANDING LABEL --------------------------------------------------------------------------------------

local function ride(host: Host): any
	return comp(host, "ride")
end

-- waits until `cond()` or `limit` seconds; returns the seconds waited, or nil
local function waitUntil(host: Host, limit: number, cond: () -> boolean): number?
	local started = os.clock()
	while os.clock() - started < limit do
		if cond() then
			return os.clock() - started
		end
		host.wait(0)
	end
	return nil
end

S["RunTop: landing label shows once, then fades"] = function(host: Host)
	host.api.setSpeed(0)
	local pre = dbg(host, "ride").landings
	freshRun(host)
	local list: { string } = {}
	local r0 = dbg(host, "ride")
	check(list, r0.showing == false and r0.landings == pre, "the ride a run starts with must not announce itself")
	local car = host.car("hurrikan")
	host.runPatch({ ride = car })
	local landedAt = os.clock()
	local appeared = waitUntil(host, 0.5, function()
		return dbg(host, "ride").showing == true
	end)
	check(list, appeared ~= nil and appeared <= 0.3, "appeared after " .. tostring(appeared))
	host.wait(0.1)
	local s = dbg(host, "ride")
	check(
		list,
		s.rarityWord == "EPIC" and s.nameText == "Hurrikan",
		string.format("%q %q", tostring(s.rarityWord), tostring(s.nameText))
	)
	check(
		list,
		s.overlapsProtected == false
			and s.overlapsPill == false
			and s.overlapsCash == false
			and s.overlapsGear == false
			and s.overlapsBanner == false
			and s.inside == true,
		"label overlaps something: " .. tostring(s.box)
	)
	check(list, s.landings == r0.landings + 1, "landings " .. tostring(s.landings))
	host.wait(0.7)
	local mid = dbg(host, "ride")
	check(
		list,
		mid.showing == true and mid.groupTransparency < 0.1,
		string.format("1.0 s: showing %s, transparency %.2f", tostring(mid.showing), mid.groupTransparency)
	)
	local gone = waitUntil(host, 4, function()
		return dbg(host, "ride").showing == false
	end)
	local total = os.clock() - landedAt
	check(
		list,
		gone ~= nil and total >= 1.45 and total <= 2.15,
		string.format("gone after %.2f s (expected 1.5 s hold + 0.25 s fade)", total)
	)
	host.wait(0.1)
	local done = dbg(host, "ride")
	check(
		list,
		done.groupTransparency == 1 and done.tweens == 0 and done.threads == 0,
		string.format("after: transparency %.2f, tweens %s", done.groupTransparency, tostring(done.tweens))
	)
	-- the same ride again, and the store re-sending it every tick, is not another landing
	host.runPatch({ ride = host.car("hurrikan") })
	host.wait(0.4)
	check(list, dbg(host, "ride").landings == s.landings, "the same car again counted as a landing")
	report(
		host,
		"Landing label timing",
		list,
		string.format("appeared %.2f s, 1.0 s still up, gone at %.2f s", appeared or -1, total)
	)
	host.api.setSpeed(nil)
end

S["RunTop: landing label full rarity words"] = function(host: Host)
	host.api.setSpeed(0)
	freshRun(host)
	local list: { string } = {}
	local expected = {
		{ "puglet", "COMMON" },
		{ "waffle", "UNCOMMON" },
		{ "rev6", "RARE" },
		{ "hurrikan", "EPIC" },
		{ "hyperion", "LEGENDARY" },
	}
	local seen: { string } = {}
	for _, e in expected do
		local car = host.car(e[1])
		host.runPatch({ ride = car })
		host.wait(0.3)
		local s = dbg(host, "ride")
		check(
			list,
			s.rarityWord == e[2] and s.nameText == car.name and s.showing == true,
			string.format("%s: %q %q", e[1], tostring(s.rarityWord), tostring(s.nameText))
		)
		table.insert(seen, tostring(s.rarityWord))
	end
	report(host, "Landing label rarity words", list, table.concat(seen, ", "))
	host.wait(2.2)
	host.api.setSpeed(nil)
end

S["RunTop: landing label replaces and never stacks"] = function(host: Host)
	host.api.setSpeed(0)
	freshRun(host)
	local list: { string } = {}
	local ids = { "puglet", "waffle", "rev6", "hurrikan", "hyperion" }
	host.runPatch({ ride = host.car("puglet") })
	host.wait(0.3)
	local base = dbg(host, "ride")
	local rootBefore = base.instances
	for i = 1, 10 do
		host.runPatch({ ride = host.car(ids[(i % #ids) + 1]) }) -- never the same as the one before it
		host.wait(0.1)
	end
	local s = dbg(host, "ride")
	local labels = 0
	for _, d in ride(host).root:GetDescendants() do
		if d.Name == "Landing" then
			labels += 1
		end
	end
	check(list, s.landings - base.landings == 10, "landings +" .. tostring(s.landings - base.landings))
	check(list, s.replaced - base.replaced >= 8, "replaced +" .. tostring(s.replaced - base.replaced))
	check(
		list,
		labels == 1 and s.instances == rootBefore,
		string.format("labels %d, instances %s -> %s", labels, tostring(rootBefore), tostring(s.instances))
	)
	check(
		list,
		s.showing == true and s.nameText == host.car(ids[(10 % #ids) + 1]).name,
		"the last landing is not the one shown: " .. tostring(s.nameText)
	)
	check(
		list,
		s.tweens <= 3 and s.threads == 0,
		string.format("tweens %s, threads %s", tostring(s.tweens), tostring(s.threads))
	)
	local gone = waitUntil(host, 4, function()
		return dbg(host, "ride").showing == false
	end)
	host.wait(0.1)
	local done = dbg(host, "ride")
	check(
		list,
		gone ~= nil and done.tweens == 0 and done.instances == rootBefore,
		string.format("after: tweens %s, instances %s", tostring(done.tweens), tostring(done.instances))
	)
	report(
		host,
		"Landing label: 10 landings in about a second",
		list,
		string.format(
			"one label, replaced %d times, instances stay %s, nothing left running",
			s.replaced - base.replaced,
			tostring(rootBefore)
		)
	)
	host.api.setSpeed(nil)
end

S["RunTop: landing label ignores duplicates"] = function(host: Host)
	host.api.setSpeed(0)
	freshRun(host)
	local list: { string } = {}
	local chip = ride(host)
	local car = host.car("rev6")
	local before = dbg(host, "ride")
	local first = chip:land("dup-a", car)
	local second = chip:land("dup-a", car) -- the same instance delivered twice
	local third = chip:land("dup-a", table.clone(car))
	local s = dbg(host, "ride")
	check(
		list,
		first == true and second == false and third == false,
		string.format("returns %s %s %s", tostring(first), tostring(second), tostring(third))
	)
	check(
		list,
		s.landings - before.landings == 1 and s.duplicates - before.duplicates == 2,
		string.format("landings +%d, duplicates +%d", s.landings - before.landings, s.duplicates - before.duplicates)
	)
	-- another instance of the same model is a different landing; coming back to an earlier instance is too
	check(list, chip:land("dup-b", car) == true and chip:land("dup-a", car) == true, "a different identity must land")
	report(
		host,
		"Landing label duplicates",
		list,
		"same identity twice: one landing, two ignored; other identities land"
	)
	host.wait(2.2)
	host.api.setSpeed(nil)
end

S["RunTop: landing label clears at run end"] = function(host: Host)
	host.api.setSpeed(0)
	freshRun(host)
	local list: { string } = {}
	host.runPatch({ ride = host.car("hyperion") })
	host.wait(0.3)
	check(list, dbg(host, "ride").showing == true, "no label to clear")
	local landings = dbg(host, "ride").landings
	host.store:setMode("Results") -- the run ended
	local gone = waitUntil(host, 0.5, function()
		return dbg(host, "ride").showing == false
	end)
	check(list, gone ~= nil, "still showing after the run ended")
	-- the next run's first ride is a baseline, not a landing
	host.enterRun()
	host.wait(0.5)
	local s = dbg(host, "ride")
	check(
		list,
		s.showing == false and s.landings == landings,
		string.format(
			"new run: showing %s, landings %s -> %s",
			tostring(s.showing),
			tostring(landings),
			tostring(s.landings)
		)
	)
	-- a landing while the run-end flag is up is not shown
	local heldBefore = dbg(host, "ride").suppressed
	RunBus.flags(ride(host)._ctx).ended = true
	host.runPatch({ ride = host.car("waffle") })
	host.wait(0.3)
	local ended = dbg(host, "ride")
	check(
		list,
		ended.showing == false and ended.suppressed == heldBefore + 1,
		string.format(
			"while the run is ending: showing %s, suppressed %s",
			tostring(ended.showing),
			tostring(ended.suppressed)
		)
	)
	RunBus.flags(ride(host)._ctx).ended = false
	report(
		host,
		"Landing label at run end",
		list,
		"cleared, next run starts without a label, no label while the run ends"
	)
	host.wait(0.3)
	host.api.setSpeed(nil)
end

S["RunTop: landing label yields to the capture nameplate"] = function(host: Host)
	host.api.setSpeed(0)
	freshRun(host)
	local list: { string } = {}
	local target = host.car("rangy")
	local before = dbg(host, "ride")
	-- landing on a car that is being captured: the nameplate names it, the label stays away
	host.runPatch({ ride = target, keys = { id = "cap-hold", target = target, progress = 0.2, status = "Holding" } })
	host.wait(0.3)
	local s = dbg(host, "ride")
	check(
		list,
		s.showing == false and s.suppressed == before.suppressed + 1 and s.landings == before.landings,
		string.format("capturing: showing %s, suppressed %s", tostring(s.showing), tostring(s.suppressed))
	)
	-- a label that is up when a capture starts fades out quickly
	local run = table.clone(host.store:get().run)
	run.keys = nil
	host.store:set("run", run)
	host.runPatch({ ride = host.car("hurrikan") })
	host.wait(0.3)
	check(list, dbg(host, "ride").showing == true, "label did not show on an ordinary landing")
	local hurrikan = host.car("hurrikan")
	host.runPatch({ keys = { id = "cap-late", target = hurrikan, progress = 0.1, status = "Holding" } })
	local gone = waitUntil(host, 0.6, function()
		return dbg(host, "ride").showing == false
	end)
	check(list, gone ~= nil, "label stayed up while the capture plate showed")
	local clean = table.clone(host.store:get().run)
	clean.keys = nil
	host.store:set("run", clean)
	report(
		host,
		"Landing label vs capture plate",
		list,
		"label withheld while a capture is Holding, and fades out when one starts"
	)
	host.wait(0.3)
	host.api.setSpeed(nil)
end

S["RunTop: landing label reduced motion"] = function(host: Host)
	host.api.setSpeed(0)
	freshRun(host)
	local list: { string } = {}
	-- reduced: no scale at all, a steady fade only
	Motion.setOverride(true)
	host.wait(0.6)
	host.runPatch({ ride = host.car("hyperion") })
	local maxScale, last, monotonic = 1, 1, true
	local started = os.clock()
	while os.clock() - started < 0.4 do
		local s = dbg(host, "ride")
		maxScale = math.max(maxScale, s.popScale)
		if s.groupTransparency > last + 1e-3 then
			monotonic = false
		end
		last = s.groupTransparency
		host.wait(0)
	end
	check(list, maxScale == 1, string.format("reduced motion scaled the label to %.3f", maxScale))
	check(list, monotonic and dbg(host, "ride").showing == true, "reduced motion fade was not steady")
	local gone = waitUntil(host, 3, function()
		return dbg(host, "ride").showing == false
	end)
	check(list, gone ~= nil, "reduced motion label never faded")
	-- normal: a short emphasis is seen (frame timing dependent)
	Motion.setOverride(false)
	host.wait(0.6)
	host.runPatch({ ride = host.car("puglet") })
	local peak = 1
	started = os.clock()
	while os.clock() - started < 0.3 do
		peak = math.max(peak, dbg(host, "ride").popScale)
		host.wait(0)
	end
	check(list, peak > 1.005, string.format("normal motion showed no emphasis (peak %.3f; frame-rate dependent)", peak))
	Motion.setOverride(nil)
	report(
		host,
		"Landing label reduced motion",
		list,
		string.format("reduced: scale stays 1 and the fade is steady; normal: peak scale %.3f", peak)
	)
	host.wait(2)
	host.api.setSpeed(nil)
end

S["RunTop: landing label long names on every frame"] = function(host: Host)
	host.api.setSpeed(0)
	local names =
		{ "Puglet", "Citrine Waffle Van", "Citrine Waffle Van Deluxe", "Super Duper Extra Long Car Name Here" }
	for _, profile in host.api.profiles do
		host.api.setProfile(profile)
		host.wait(0.3)
		freshRun(host)
		local list: { string } = {}
		local lines: { string } = {}
		for i, name in names do
			local car = table.clone(host.car("rev6")) :: any
			car.id = "long-" .. profile .. "-" .. i
			car.name = name
			host.runPatch({ ride = car })
			host.wait(0.3)
			local s = dbg(host, "ride")
			check(list, s.showing == true and s.nameText == name, "not shown: " .. name)
			check(
				list,
				s.nameTruncate == "None" and s.nameWrapped == true and string.find(s.nameText, "%.%.%.") == nil,
				"name is cut: " .. name
			)
			check(list, s.nameSize >= 16, "name under 16 px: " .. name)
			check(
				list,
				s.nameBoundsX <= s.nameBoxX + 0.5 and s.nameBoundsY <= s.nameBoxY + 1,
				string.format(
					"%s: text %.1fx%.1f in box %.1fx%.1f",
					name,
					s.nameBoundsX,
					s.nameBoundsY,
					s.nameBoxX,
					s.nameBoxY
				)
			)
			if i <= 3 then
				check(list, s.nameLines <= 2, string.format("%s wraps to %d lines", name, s.nameLines))
			end
			check(
				list,
				s.overlapsProtected == false
					and s.overlapsPill == false
					and s.overlapsGear == false
					and s.overlapsBanner == false
					and s.inside == true,
				name .. " label overlaps: " .. tostring(s.box)
			)
			table.insert(lines, string.format("%d@%d", s.nameLines, s.nameSize))
		end
		report(host, "Landing label long names, " .. profile, list, "lines@size " .. table.concat(lines, ", "))
	end
	host.wait(2)
	host.api.setProfile("Desktop")
	host.api.setSpeed(nil)
end

-- LEAKS --------------------------------------------------------------------------------------------------

S["RunTop: pill and landing label leave nothing behind"] = function(host: Host)
	host.api.setSpeed(0)
	freshRun(host)
	local list: { string } = {}
	local ctx = comp(host, "routeLine")._ctx
	local layer = ctx.layer
	local keep = RunBus.get(ctx, "ride")
	for _ = 1, 5 do
		local before = #layer:GetDescendants()
		local line = RouteLine.new(ctx)
		local mid = #layer:GetDescendants()
		line:destroy()
		local chip = RideChip.new(ctx)
		chip:land("leak-a", host.car("rev6"))
		chip:land("leak-b", host.car("hurrikan"))
		host.wait(0.1)
		chip:destroy()
		local after = #layer:GetDescendants()
		check(
			list,
			mid > before and after == before,
			string.format("layer %d -> %d (with the pill) -> %d", before, mid, after)
		)
	end
	-- the throwaway chip took the "ride" registration and removed it again: give it back to the live one
	if RunBus.get(ctx, "ride") ~= keep then
		RunBus.register(ctx, "ride", keep)
	end
	local live = dbg(host, "routeLine")
	local chip = dbg(host, "ride")
	report(
		host,
		"No leaks (5 pill + label cycles)",
		list,
		string.format(
			"live pill: %s instances, %s connections; live label: %s instances, %s connections, tweens %s",
			tostring(live.instances),
			tostring(live.connections),
			tostring(chip.instances),
			tostring(chip.connections),
			tostring(chip.tweens)
		)
	)
	host.wait(2)
	host.api.setSpeed(nil)
end

return S
