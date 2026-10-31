--!strict
-- DEVELOPMENT PREVIEW ONLY (Lane 3). Plot fit and plaza view of every Speedway look level,
-- measured in Studio edit mode on the built island hub (Adam's private island place only):
--
--   local I = game.ServerStorage.Island:Clone()
--   print(require(I.Hub.Preview.SpeedwayChecks).run({ plot = 3 }))
--
-- For each level 1 to 12 it assembles the look on one plot (then restores that plot) and
-- reports, from the actual placed parts:
--   parts, mesh parts and triangles (mesh triangles from the kit manifests, 12 per box part)
--   the plan bounds in the plot frame and the highest point, including the blimp's orbit and the
--     firework bloom envelope (both moving or transient, added analytically)
--   sector: parts outside the plot's sector less its 8-stud buffer, or past the outer radius
--   protected: parts over the entrance court, the plot walk, the Paddock, the kiosk, or taller
--     than 0.3 over the pit lanes (with names); the Raceway shop is the Kiosk reservation's occupant,
--     so its parts are checked against that reservation instead (shop: every corner at least 0.5
--     inside it, nothing higher than its 9-stud limit)
--   plazaView: of 40 sample points along the lap (1.5 above the road), the share visible from five
--     points on the plaza edge, with this plot's Speedway parts as the only blockers: at standing eye
--     height (5) and at a usual third-person camera height (12).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local KitManifest = require(script.Parent.Parent.Environment.KitManifest)
local Layout = require(script.Parent.Parent.Layout)

local SpeedwayChecks = {}

local function shared(): any
	local s = ReplicatedStorage:FindFirstChild("Shared") :: any
	assert(s, "ReplicatedStorage.Shared is not synced")
	return s:Clone()
end

local function inPoly(p: Vector2, poly: { Vector2 }): boolean
	local inside = false
	local j = #poly
	for i = 1, #poly do
		local a, b = poly[i], poly[j]
		if (a.Y > p.Y) ~= (b.Y > p.Y) and p.X < (b.X - a.X) * (p.Y - a.Y) / (b.Y - a.Y) + a.X then
			inside = not inside
		end
		j = i
	end
	return inside
end

-- plan-frame footprint corners of a part (its box), in the plot frame
local function footprint(part: BasePart, bearing: number): ({ Vector2 }, number, number)
	local cf, size = part.CFrame, part.Size / 2
	local pts = {}
	local lo, hi = math.huge, -math.huge
	for _, sx in { -1, 1 } do
		for _, sy in { -1, 1 } do
			for _, sz in { -1, 1 } do
				local w = cf:PointToWorldSpace(Vector3.new(sx * size.X, sy * size.Y, sz * size.Z))
				lo, hi = math.min(lo, w.Y), math.max(hi, w.Y)
				table.insert(pts, Layout.planToPlot(bearing, Layout.worldToPlan(w)))
			end
		end
	end
	return pts, lo, hi
end

function SpeedwayChecks.run(options: { plot: number?, levels: { number }? }?): { [string]: any }
	assert(RunService:IsStudio() and not RunService:IsRunning(), "edit mode in Studio only")
	local o = options or {}
	local index = o.plot or 3
	local root = workspace:FindFirstChild("Lane3_IslandPreview") :: any
	assert(root, "build the island hub first")
	local plot = root.Island.Plots:FindFirstChild(string.format("Plot%02d", index)) :: Model
	local bearing = Layout.plotBearing(index)
	local S = shared()
	local Look = (require :: any)(S.Island.Speedway.Look)
	local Path = (require :: any)(S.Island.Speedway.Path)
	local speedwayManifest = (require :: any)(S.Island.Speedway.KitManifest)

	local function tris(part: BasePart): number
		if part:IsA("MeshPart") then
			local e = (speedwayManifest :: any)[part.Name] or (KitManifest :: any)[part.Name]
			return if e then e.triangles else 0
		end
		return 12
	end

	local protectedIds = { "EntranceCourt", "PlotWalk", "Paddock", "Kiosk" }
	local laneIds = { "PitExit", "PitEntry" }
	local sinH = math.sin(math.rad(Layout.HalfSectorDeg))
	local cosH = math.cos(math.rad(Layout.HalfSectorDeg))
	local outer = Layout.Data.plot.outerRadius

	-- plaza eye points: the plaza edge toward this plot, five points across
	local plazaR = Layout.Data.park.plazaRadius
	local function eyesAt(height: number): { Vector3 }
		local list = {}
		for k = -2, 2 do
			local p = Layout.plotToPlan(bearing, Vector2.new(k * 8, plazaR - 2))
			table.insert(list, Layout.planToWorld(p, height))
		end
		return list
	end

	local levels = o.levels or { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12 }
	local report = {}
	for _, level in levels do
		Look.clear(plot)
		Look.apply(plot, level, { index = index, bearing = bearing, owner = "" })
		local look = plot:FindFirstChild("SpeedwayLook") :: Folder
		local parts, meshParts, triangles = 0, 0, 0
		local x0, u0, x1, u1, top = math.huge, math.huge, -math.huge, -math.huge, -math.huge
		local sector, protected = {}, {}
		for _, d in look:GetDescendants() do
			if not d:IsA("BasePart") then
				continue
			end
			parts += 1
			if d:IsA("MeshPart") then
				meshParts += 1
			end
			triangles += tris(d)
			local pts, lo, hi = footprint(d, bearing)
			top = math.max(top, hi)
			local outside = false
			for _, p in pts do
				x0, x1 = math.min(x0, p.X), math.max(x1, p.X)
				u0, u1 = math.min(u0, p.Y), math.max(u1, p.Y)
				local clear = p.Y * sinH - math.abs(p.X) * cosH
				if clear < Layout.BufferPerSide - 0.01 or p.Magnitude > outer then
					outside = true
				end
			end
			if outside and #sector < 12 then
				table.insert(sector, d:GetFullName())
			end
			local centre = Layout.planToPlot(bearing, Layout.worldToPlan(d.Position))
			local feature = d:FindFirstAncestorWhichIsA("Folder")
			while feature and feature:GetAttribute("SpeedwayFeature") == nil do
				feature = feature:FindFirstAncestorWhichIsA("Folder")
			end
			if feature and feature:GetAttribute("SpeedwayFeature") == "Shop" then
				local kx0, ku0, kx1, ku1 = Layout.bounds(Layout.reservation("Kiosk").poly)
				local limit = Layout.reservation("Kiosk").height
				for _, p in pts do
					if
						(p.X < kx0 + 0.49 or p.X > kx1 - 0.49 or p.Y < ku0 + 0.49 or p.Y > ku1 - 0.49 or hi > limit)
						and #protected < 12
					then
						table.insert(protected, "Shop outside the Kiosk reservation less 0.5: " .. d.Name)
						break
					end
				end
				continue
			end
			for _, id in protectedIds do
				local r = Layout.reservation(id)
				if inPoly(centre, r.poly) and hi > 0.4 and #protected < 12 then
					table.insert(protected, id .. ": " .. d.Name)
				end
			end
			for _, id in laneIds do
				local r = Layout.reservation(id)
				if inPoly(centre, r.poly) and hi - lo > 0.3 and hi > 0.5 and #protected < 12 then
					table.insert(protected, id .. ": " .. d.Name)
				end
			end
		end
		-- moving and transient envelopes, added analytically
		if level >= 11 then
			-- the blimp orbit: radius 52 about (0, 441), height 58, half length about 12
			x0, x1 = math.min(x0, -64), math.max(x1, 64)
			u0, u1 = math.min(u0, 441 - 64), math.max(u1, 441 + 64)
			top = math.max(top, 58 + 7)
		end
		if level >= 12 then
			top = math.max(top, 28 + 12) -- the firework bloom: 28 up, about 12 across
		end
		-- plaza view of the lap: every Speedway part blocks the view, decoration included (it is
		-- CanQuery false in the game, so turn querying on for this measurement; the look is cleared
		-- after the run)
		for _, d in look:GetDescendants() do
			if d:IsA("BasePart") then
				d.CanQuery = true
			end
		end
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Include
		params.FilterDescendantsInstances = { look }
		local path = Path.forLevel(level)
		local function view(height: number): number
			local seen, total = 0, 0
			for k = 0, 39 do
				local pos = path and Path.sample(path, path.length * k / 40)
				local target = Path.plotFrame(bearing) * (pos :: Vector3) + Vector3.yAxis * 1.5
				for _, eye in eyesAt(height) do
					total += 1
					local hit = workspace:Raycast(eye, target - eye, params)
					if not hit or (hit.Position - target).Magnitude < 2 then
						seen += 1
					end
				end
			end
			return math.round(seen / total * 1000) / 10
		end
		report[level] = {
			parts = parts,
			meshParts = meshParts,
			triangles = triangles,
			bounds = string.format("x %.1f..%.1f  u %.1f..%.1f", x0, x1, u0, u1),
			top = math.round(top * 10) / 10,
			sectorViolations = sector,
			protectedViolations = protected,
			plazaViewPercent = view(5),
			plazaViewCamera = view(12),
		}
		task.wait()
	end
	Look.clear(plot)
	return report
end

-- Raceway round 2 parking: the client's bay list matches Hub/Layout's, and for every owned count 2 to
-- 15 the parking pieces stay inside the Paddock reservation (the sign in its free left margin), no
-- parking piece stands on the plot walk or a pit lane, and only the post colliders collide.
function SpeedwayChecks.parking(options: { plot: number? }?): { [string]: any }
	assert(RunService:IsStudio() and not RunService:IsRunning(), "edit mode in Studio only")
	local index = (options and options.plot) or 3
	local root = workspace:FindFirstChild("Lane3_IslandPreview") :: any
	assert(root, "build the island hub first")
	local plot = root.Island.Plots:FindFirstChild(string.format("Plot%02d", index)) :: Model
	local bearing = Layout.plotBearing(index)
	local S = shared()
	local Parking = (require :: any)(S.Island.Speedway.Parking)
	local Ctx = (require :: any)(S.Island.Speedway.Ctx)
	local mismatch = {}
	for i, bay in Layout.Bays do
		local mine = Parking.Bays[i]
		if not mine or mine.row ~= bay.row or math.abs(mine.x - bay.x) > 1e-3 or math.abs(mine.u - bay.u) > 1e-3 then
			table.insert(mismatch, i)
		end
	end
	local pad = Layout.reservation("Paddock").poly
	local ctx = Ctx.new(plot, index, bearing, 1, "")
	local report = { bayListMismatch = mismatch, counts = {} }
	for n = Parking.StartSpots, Parking.MaxSpots do
		local built = Parking.build(plot, ctx, n)
		local outside, onRoutes, colliding = {}, {}, {}
		for _, d in built.folder:GetDescendants() do
			if not d:IsA("BasePart") then
				continue
			end
			local pts = footprint(d, bearing)
			for _, p in pts do
				if not inPoly(p, pad) then
					table.insert(outside, d.Name)
					break
				end
			end
			local centre = Layout.planToPlot(bearing, Layout.worldToPlan(d.Position))
			for _, id in { "PlotWalk", "PitExit", "PitEntry", "EntranceCourt" } do
				if inPoly(centre, Layout.reservation(id).poly) then
					table.insert(onRoutes, id .. ": " .. d.Name)
				end
			end
			if d.CanCollide and not string.find(d.Name, "Collider") then
				table.insert(colliding, d.Name)
			end
		end
		report.counts[n] = {
			ownedBays = #built.lines,
			barrierAt = if built.arm then built.arm:GetAttribute("BayIndex") else "none",
			outsidePaddock = outside,
			onRoutes = onRoutes,
			collidingDecoration = colliding,
		}
		built.folder:Destroy()
		task.wait()
	end
	return report
end

return SpeedwayChecks
