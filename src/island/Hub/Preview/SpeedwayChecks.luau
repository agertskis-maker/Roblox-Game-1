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
--     than 0.3 over the pit lanes (with names)
--   plazaView: of 40 sample points on the ground track, the share visible from five eye points
--     on the plaza edge (eye height 5), with this plot's Speedway parts as the only blockers.

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
	local eyes = {}
	for k = -2, 2 do
		local p = Layout.plotToPlan(bearing, Vector2.new(k * 8, plazaR - 2))
		table.insert(eyes, Layout.planToWorld(p, 5))
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
		-- plaza view of the ground track
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Include
		params.FilterDescendantsInstances = { look }
		local path = Path.forLevel(level)
		local seen, total = 0, 0
		for k = 0, 39 do
			local pos = path and Path.sample(path, path.length * k / 40)
			local target = Path.plotFrame(bearing) * (pos :: Vector3) + Vector3.yAxis * 1.5
			for _, eye in eyes do
				total += 1
				local hit = workspace:Raycast(eye, target - eye, params)
				if not hit or (hit.Position - target).Magnitude < 2 then
					seen += 1
				end
			end
		end
		report[level] = {
			parts = parts,
			meshParts = meshParts,
			triangles = triangles,
			bounds = string.format("x %.1f..%.1f  u %.1f..%.1f", x0, x1, u0, u1),
			top = math.round(top * 10) / 10,
			sectorViolations = sector,
			protectedViolations = protected,
			plazaViewPercent = math.round(seen / total * 1000) / 10,
		}
		task.wait()
	end
	Look.clear(plot)
	return report
end

return SpeedwayChecks
