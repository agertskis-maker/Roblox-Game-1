--!strict
-- DEVELOPMENT CHECKS (Lane 3). Reads the built hub preview and reports its fit checks from the
-- instances themselves (markers and parts), not from the plan's numbers:
--   markers identical in every plot's own frame, the lap length from the path markers,
--   every plot part inside its sector with the buffer, nothing taller than eye level in a
--   viewing corridor, the bridge count, and the fountain rim height;
--   every later-tier ("future") reservation empty: no plot part that stands above the ground
--   (more than 0.6 studs) has its centre inside a future reservation, except where the plan
--   allows the overlap (allowedPairs) or the reservation's own note allows it (the base flag
--   line in the SignBand).
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

local function inReservation(p: Vector2, r: any): boolean
	if not inPoly(p, r.poly) then
		return false
	end
	local ring = r.ring
	return not (ring and #ring >= 3 and inPoly(p, ring))
end

-- Parts allowed inside a future reservation by name or attribute (the base flag line in the
-- SignBand, whose note says the tier 2 flag line starts there; and the owner's banner, Task 4:
-- the band is the sign and banner band, and a flat banner on the curved far-turn wall was cropped).
local FUTURE_ALLOWED: { [string]: (BasePart) -> boolean } = {
	SignBand = function(part)
		local line = part:FindFirstAncestor("FlagLine")
		return (line ~= nil and line:GetAttribute("FlagLine") == true) or part:GetAttribute("OwnerBanner") == true
	end,
}

local function reservationCheck(plots: Folder): { [string]: any }
	local future, base = {}, {}
	for _, res in Layout.Data.reservations do
		if res.layer == "future" then
			table.insert(future, res)
		else
			table.insert(base, res)
		end
	end
	local allowed: { [string]: boolean } = {}
	for _, pair in Layout.Data.allowedPairs do
		allowed[pair.a .. "|" .. pair.b] = true
		allowed[pair.b .. "|" .. pair.a] = true
	end
	local violations, checked = {}, 0
	local byZone: { [string]: number } = {}
	for _, plot in plots:GetChildren() do
		local index = tonumber(string.match(plot.Name, "%d+"))
		if not index then
			continue
		end
		local bearing = Layout.plotBearing(index)
		for _, part in plot:GetDescendants() do
			if not part:IsA("BasePart") then
				continue
			end
			checked += 1
			local top = part.Position.Y + part.Size.Y / 2
			if part:IsA("Part") then
				local h = 0
				for _, c in corners(part) do
					h = math.max(h, c.Y)
				end
				top = h
			end
			if top <= Layout.SurfaceY + 0.6 then
				continue -- flat ground dressing does not occupy a reservation
			end
			-- the part's centre decides its home (base) reservation; any corner of its footprint
			-- inside a later-tier reservation counts as occupying it
			local q = Layout.planToPlot(bearing, Vector2.new(part.Position.X, -part.Position.Z))
			local pts = { q }
			for _, c in corners(part) do
				table.insert(pts, Layout.planToPlot(bearing, Vector2.new(c.X, -c.Z)))
			end
			local home = nil
			for _, res in base do
				if inReservation(q, res) then
					home = res.id
					break
				end
			end
			for _, res in future do
				local touches = false
				for _, pt in pts do
					if inReservation(pt, res) then
						touches = true
						break
					end
				end
				if touches then
					local ok = (home ~= nil and allowed[home .. "|" .. res.id])
						or (FUTURE_ALLOWED[res.id] ~= nil and FUTURE_ALLOWED[res.id](part))
					if not ok then
						byZone[res.id] = (byZone[res.id] or 0) + 1
						if #violations < 12 then
							table.insert(
								violations,
								string.format(
									"%s %s in %s",
									plot.Name,
									part:GetFullName():match("[^.]+%.[^.]+$") or part.Name,
									res.id
								)
							)
						end
					end
				end
			end
		end
	end
	return { partsChecked = checked, violations = violations, violationsByReservation = byZone }
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
	report.futureReservations = reservationCheck(plots)
	return report
end

return LayoutChecks
