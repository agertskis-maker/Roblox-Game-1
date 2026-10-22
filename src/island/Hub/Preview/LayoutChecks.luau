--!strict
-- DEVELOPMENT CHECKS (Lane 3). Reads the built hub preview and reports its fit checks from the
-- instances themselves (markers and parts), not from the plan's numbers:
--   markers identical in every plot's own frame, the lap length from the path markers,
--   every plot part inside its sector with the buffer, nothing taller than eye level in a
--   viewing corridor, the bridge count, and the fountain rim height.
--
--   local I = game.ServerStorage.Island:Clone()
--   require(I.Hub.Preview.LayoutChecks).run()

local Layout = require(script.Parent.Parent.Layout)

local LayoutChecks = {}

local CORRIDOR_HEIGHT = 3 -- nothing taller may stand in a viewing corridor

local function round(n: number, places: number?): number
	local m = 10 ^ (places or 2)
	return math.round(n * m) / m
end

local function corners(part: BasePart): { Vector3 }
	local out = {}
	local h = part.Size / 2
	for _, x in { -1, 1 } do
		for _, y in { -1, 1 } do
			for _, z in { -1, 1 } do
				table.insert(out, part.CFrame:PointToWorldSpace(Vector3.new(x * h.X, y * h.Y, z * h.Z)))
			end
		end
	end
	return out
end

local function cross(a: Vector2, b: Vector2): number
	return a.X * b.Y - a.Y * b.X
end

local function inTriangle(p: Vector2, a: Vector2, b: Vector2, c: Vector2): boolean
	local d1, d2, d3 = cross(b - a, p - a), cross(c - b, p - b), cross(a - c, p - c)
	local neg = d1 < 0 or d2 < 0 or d3 < 0
	local pos = d1 > 0 or d2 > 0 or d3 > 0
	return not (neg and pos)
end

function LayoutChecks.run(): { [string]: any }
	local root = workspace:FindFirstChild("Lane3_IslandPreview")
	assert(root, "Build the hub preview first")
	local island = root:FindFirstChild("Island") :: Model
	assert(island:GetAttribute("LayoutVersion") == Layout.LayoutVersion, "The preview is not the hub build")
	local plotCount = island:GetAttribute("PlotCount") :: number
	local plots = island:FindFirstChild("Plots") :: Folder
	local report: { [string]: any } = {}
	report.plotCountAttribute = plotCount
	report.plotModels = #plots:GetChildren()

	-- Markers: same in every plot's own frame; lap length from the path markers
	local reference: { [string]: CFrame } = {}
	local worstDeviation, markerCount = 0, 0
	local pathLengths = {}
	for index = 1, plotCount do
		local plot = plots:FindFirstChild(string.format("Plot%02d", index)) :: Model
		local markers = plot:FindFirstChild("Markers") :: BasePart
		local speedway = markers:FindFirstChild("Speedway") :: Attachment
		local count = speedway:GetAttribute("PathSampleCount") :: number
		for _, a in markers:GetChildren() do
			if a:IsA("Attachment") then
				if index == 1 then
					reference[a.Name] = a.CFrame
					markerCount += 1
				elseif reference[a.Name] then
					worstDeviation =
						math.max(worstDeviation, (reference[a.Name].Position - a.CFrame.Position).Magnitude)
				end
			end
		end
		local length = 0
		for i = 1, count do
			local a = (markers:FindFirstChild(string.format("Path%03d", i)) :: Attachment).WorldPosition
			local b = (markers:FindFirstChild(string.format("Path%03d", i % count + 1)) :: Attachment).WorldPosition
			length += (b - a).Magnitude
		end
		pathLengths[index] = round(length, 1)
	end
	-- every GateSpawn faces the fountain
	local worstFacing = 1
	for index = 1, plotCount do
		local spawn = (
			(plots:FindFirstChild(string.format("Plot%02d", index)) :: Model):FindFirstChild("Markers") :: BasePart
		):FindFirstChild("GateSpawn") :: Attachment
		local look = spawn.WorldCFrame.LookVector
		local toFountain = (Vector3.new(0, spawn.WorldPosition.Y, 0) - spawn.WorldPosition).Unit
		worstFacing = math.min(worstFacing, Vector3.new(look.X, 0, look.Z).Unit:Dot(toFountain))
	end
	report.gateSpawnFacingFountainWorstDot = round(worstFacing, 4)
	report.markersPerPlot = markerCount
	report.worstMarkerDeviation = round(worstDeviation, 4)
	report.pathLengthFromMarkers = pathLengths
	report.pathLengthPlanned = round(Layout.PathLength, 1)

	-- Every plot part inside its own sector, at least the buffer from both rays
	local worstRay, worstRadius, innerRadius = math.huge, 0, math.huge
	local worstPart = ""
	for index = 1, plotCount do
		local plot = plots:FindFirstChild(string.format("Plot%02d", index)) :: Model
		local bearing = plot:GetAttribute("BearingDeg") :: number
		for _, d in plot:GetDescendants() do
			if d:IsA("BasePart") and d.Name ~= "Markers" then
				for _, c in corners(d) do
					local p = Layout.planToPlot(bearing, Layout.worldToPlan(c))
					local clear = Layout.rayClear(p)
					if clear < worstRay then
						worstRay = clear
						worstPart = string.format("Plot%02d %s", index, d.Name)
					end
					worstRadius = math.max(worstRadius, p.Magnitude)
					innerRadius = math.min(innerRadius, p.Magnitude)
				end
			end
		end
	end
	report.worstRayClearance = round(worstRay)
	report.worstRayPart = worstPart
	report.rayBufferRequired = Layout.BufferPerSide
	report.plotPartsOuterRadius = round(worstRadius, 1)
	report.plotPartsInnerRadius = round(innerRadius, 1)

	-- Viewing corridors: parts in the park or the plots taller than eye level whose footprint
	-- reaches into a corridor. A plot's own gate stands round the viewer and is ignored there.
	local hits = {}
	local corridors = Layout.Data.park.corridors
	local function scan(parts: { Instance }, ownPlot: number?)
		for _, d in parts do
			-- the grand fountain is held to its measured sightline envelope instead (PortalSight)
			if d:IsA("BasePart") and d.Transparency < 1 and not d:GetAttribute("SightlineEnvelope") then
				local top = -math.huge
				local cs = corners(d)
				for _, c in cs do
					top = math.max(top, c.Y)
				end
				if top - Layout.SurfaceY > CORRIDOR_HEIGHT then
					for i, tri in corridors do
						if i ~= ownPlot then
							for _, c in cs do
								if inTriangle(Layout.worldToPlan(c), tri[1], tri[2], tri[3]) then
									table.insert(hits, string.format("corridor %d: %s", i, d:GetFullName()))
									break
								end
							end
						end
					end
				end
			end
		end
	end
	scan((island:FindFirstChild("Plaza") :: Instance):GetDescendants(), nil)
	-- the park dressing (kit meshes) and the island planting near the hub
	local env = workspace:FindFirstChild("Lane3_IslandEnvironment")
	local dressing = env and env:FindFirstChild("ParkDressing")
	if dressing then
		scan(dressing:GetDescendants(), nil)
	end
	for index = 1, plotCount do
		local plot = plots:FindFirstChild(string.format("Plot%02d", index)) :: Model
		local front = (plot:FindFirstChild("Visual") :: Folder):FindFirstChild("Front") :: Folder
		local gate, rest = {}, {}
		for _, d in front:GetChildren() do
			if string.find(d.Name, "^Gate") or d.Name == "Nameplate" then
				table.insert(gate, d)
			else
				table.insert(rest, d)
			end
		end
		scan(gate, index)
		scan(rest, nil)
	end
	report.corridorObstacles = hits

	local plaza = island:FindFirstChild("Plaza") :: Model
	report.bridges = #(plaza:FindFirstChild("Bridges") :: Folder):GetChildren()
	report.bridgesPlanned = #Layout.Data.park.bridges
	local rim = plaza:FindFirstChild("FountainRim") :: BasePart
	report.fountainRimTop = round(rim.Position.Y + rim.Size.X / 2 - Layout.SurfaceY)
	return report
end

return LayoutChecks
