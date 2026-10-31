--!strict
-- DEVELOPMENT CHECKS (Lane 3). Reads the terrain itself after the environment build and checks
-- that it keeps the approved layout: nothing above the walking surface inside any plot
-- reservation, viewing corridor or walk route; solid ground under them (water only under the
-- bridges); water in the lake, pool, stream and outlet; the waterfall present; and the Task 4
-- river loop rules (EnvChecks.river, also callable on its own without terrain).
--
--   local I = game.ServerStorage.Island:Clone()
--   require(I.Hub.Preview.EnvChecks).run()
--   require(I.Hub.Preview.EnvChecks).river()       -- layout and height-field checks only
--   require(I.Hub.Preview.EnvChecks).river(true)   -- plus water in the written terrain

local Cascade = require(script.Parent.Parent.Environment.Cascade)
local EnvironmentBuild = require(script.Parent.Parent.Environment.EnvironmentBuild)
local Field = require(script.Parent.Parent.Environment.Field)
local Layout = require(script.Parent.Parent.Layout)
local TerrainWriter = require(script.Parent.Parent.Environment.TerrainWriter)

local EnvChecks = {}

-- River loop rules (Task 4). Deterministic: they read only the layout and the height field,
-- except `terrainWater`, which reads the written terrain.
EnvChecks.RiverMaxGap = 12 -- studs between consecutive centre-line points
EnvChecks.RiverMirrorTolerance = 0.05
EnvChecks.BridgeTolerance = 2 -- a crossing needs a bridge centre this close
EnvChecks.RiverSampleStep = 4 -- studs between water samples along the centre line

local function fmt(p: Vector2): string
	return string.format("(%.1f, %.1f)", p.X, p.Y)
end

-- Where segment a-b crosses segment c-d, or nil.
local function intersect(a: Vector2, b: Vector2, c: Vector2, d: Vector2): Vector2?
	local r, s = b - a, d - c
	local den = r.X * s.Y - r.Y * s.X
	if math.abs(den) < 1e-9 then
		return nil
	end
	local q = c - a
	local t = (q.X * s.Y - q.Y * s.X) / den
	local u = (q.X * r.Y - q.Y * r.X) / den
	if t >= 0 and t <= 1 and u >= 0 and u <= 1 then
		return a + r * t
	end
	return nil
end

-- Points every `step` studs along a polyline (both ends included).
local function along(points: { Vector2 }, step: number): { Vector2 }
	local out = { points[1] }
	for i = 2, #points do
		local a, b = points[i - 1], points[i]
		local n = math.max(1, math.ceil((b - a).Magnitude / step))
		for k = 1, n do
			table.insert(out, a:Lerp(b, k / n))
		end
	end
	return out
end

-- The built main curtain sits on the falls line (Task 4 moved it to Cascade.Curtain.x): its
-- beams exist and their mean x at the lip is within a quarter width of the line.
function EnvChecks.curtain(): { [string]: any }
	local env = workspace:FindFirstChild("Lane3_IslandEnvironment")
	local waterfall = env and env:FindFirstChild("Waterfall")
	local folder = waterfall and waterfall:FindFirstChild("Curtain")
	if not folder then
		return { ok = false, failure = "no Lane3_IslandEnvironment.Waterfall.Curtain" }
	end
	local beams, sumX = 0, 0
	for _, d in folder:GetChildren() do
		if d:IsA("Beam") and d.Attachment0 then
			beams += 1
			sumX += d.Attachment0.WorldPosition.X
		end
	end
	if beams == 0 then
		return { ok = false, failure = "the Curtain folder has no beams" }
	end
	local meanX = sumX / beams
	local off = math.abs(meanX - Cascade.Curtain.x)
	local ok = off <= Cascade.Curtain.width / 4
	return {
		ok = ok,
		beams = beams,
		meanX = math.round(meanX * 10) / 10,
		expectedX = Cascade.Curtain.x,
		failure = if ok
			then nil
			else string.format(
				"curtain centre x %.1f is %.1f from the falls line %.1f",
				meanX,
				off,
				Cascade.Curtain.x
			),
	}
end

export type RiverReport = {
	ok: boolean,
	failures: { string },
	points: number,
	maxGap: number,
	ends: { string },
	mirrorWorst: number,
	crossings: number,
	bridges: number,
	fieldWaterSamples: number,
	terrainWaterSamples: number?,
}

-- The river checks. `readTerrain` adds (e): water in the written terrain along the centre line.
function EnvChecks.river(readTerrain: boolean?): RiverReport
	local park = Layout.Data.park
	local stream = park.stream
	local failures: { string } = {}
	local function fail(text: string)
		table.insert(failures, text)
	end

	-- (a) continuity: no gap over RiverMaxGap between consecutive points
	local maxGap = 0
	for i = 2, #stream do
		local gap = (stream[i] - stream[i - 1]).Magnitude
		maxGap = math.max(maxGap, gap)
		if gap > EnvChecks.RiverMaxGap then
			fail(string.format("river gap %.1f between points %d and %d at %s", gap, i - 1, i, fmt(stream[i - 1])))
		end
	end

	-- (b) both ends inside the lake (the approved ellipse and the written shoreline)
	local ends = {}
	for _, i in { 1, #stream } do
		local p = stream[i]
		local inLake = Field.lakeShape(p)
		local e = Field.lakeE(p)
		table.insert(ends, string.format("point %d %s lake e %.2f %s", i, fmt(p), e, if inLake then "in" else "OUT"))
		if not inLake or e >= 1 then
			fail(string.format("river end %d at %s is not inside the lake (e %.2f)", i, fmt(p), e))
		end
	end

	-- (c) mirrored about x = park.axisX
	local axis = (park :: any).axisX or 0
	local mirrorWorst = 0
	for i = 1, #stream do
		local p, q = stream[i], stream[#stream + 1 - i]
		local err = math.max(math.abs((p.X - axis) + (q.X - axis)), math.abs(p.Y - q.Y))
		mirrorWorst = math.max(mirrorWorst, err)
		if err > EnvChecks.RiverMirrorTolerance and i <= #stream / 2 then
			fail(string.format("river not mirrored at point %d %s (off by %.3f)", i, fmt(p), err))
		end
	end

	-- (d) every crossing of the river centre line with a path has a bridge within tolerance
	local crossings = 0
	local used: { [number]: boolean } = {}
	for _, path in park.paths do
		local pts = path.points
		for i = 1, #pts - 1 do
			for j = 1, #stream - 1 do
				local x = intersect(pts[i], pts[i + 1], stream[j], stream[j + 1])
				if x then
					crossings += 1
					local best, which = math.huge, 0
					for k, b in park.bridges do
						local d = (b.at - x).Magnitude
						if d < best then
							best, which = d, k
						end
					end
					if best > EnvChecks.BridgeTolerance then
						fail(
							string.format(
								"%s crosses the river at %s with no bridge (nearest %.1f)",
								path.kind,
								fmt(x),
								best
							)
						)
					else
						used[which] = true
					end
				end
			end
		end
	end
	for k, b in park.bridges do
		if not used[k] then
			fail(string.format("bridge %d (%s) at %s is not on a river crossing", k, b.path, fmt(b.at)))
		end
	end

	-- (e, field) the height field itself puts water on every sample of the centre line
	local samples = along(stream, EnvChecks.RiverSampleStep)
	local state = workspace:FindFirstChild("Lane3_IslandEnvironment")
	local seed = state and state:GetAttribute("Seed") or EnvironmentBuild.Seed
	local nz = Field.noiseFor(seed :: number)
	local river = TerrainWriter.river(stream)
	local dryField = 0
	for _, p in samples do
		local s = Field.sample(nz, p)
		Field.applyStream(s, river, p)
		if s.water ~= Field.LakeLevel or s.h >= Field.LakeLevel then
			dryField += 1
			if dryField <= 6 then
				fail(string.format("height field has no river water at %s (h %.2f)", fmt(p), s.h))
			end
		end
	end

	local report: RiverReport = {
		ok = false,
		failures = failures,
		points = #stream,
		maxGap = math.round(maxGap * 100) / 100,
		ends = ends,
		mirrorWorst = math.round(mirrorWorst * 1000) / 1000,
		crossings = crossings,
		bridges = #park.bridges,
		fieldWaterSamples = #samples - dryField,
		terrainWaterSamples = nil,
	}

	-- (e, terrain) water in the written terrain along the centre line (voxel y -4..0)
	if readTerrain then
		local dry = 0
		local terrain = workspace.Terrain
		for i, p in samples do
			local x = math.floor(p.X / 4) * 4
			local z = math.floor(-p.Y / 4) * 4
			local liquid = terrain:ReadVoxelChannels(
				Region3.new(Vector3.new(x, -4, z), Vector3.new(x + 4, 0, z + 4)),
				4,
				{ "LiquidOccupancy" }
			).LiquidOccupancy[1][1][1]
			if liquid <= 0 then
				dry += 1
				if dry <= 6 then
					fail(string.format("no terrain water on the river at %s", fmt(p)))
				end
			end
			if i % 100 == 0 then
				task.wait()
			end
		end
		report.terrainWaterSamples = #samples - dry
	end
	report.ok = #failures == 0
	return report
end

local terrain = workspace.Terrain

-- Solid above the surface (y 0..8) and solid/liquid in the voxel below (y -4..0) at a plan point.
local function column(p: Vector2): (number, number, number)
	local x = math.floor(p.X / 4) * 4
	local z = math.floor(-p.Y / 4) * 4
	local above = terrain:ReadVoxelChannels(
		Region3.new(Vector3.new(x, 0, z), Vector3.new(x + 4, 8, z + 4)),
		4,
		{ "SolidOccupancy" }
	).SolidOccupancy[1]
	local below = terrain:ReadVoxelChannels(
		Region3.new(Vector3.new(x, -4, z), Vector3.new(x + 4, 0, z + 4)),
		4,
		{ "SolidOccupancy", "LiquidOccupancy" }
	)
	return math.max(above[1][1], above[2][1]), below.SolidOccupancy[1][1][1], below.LiquidOccupancy[1][1][1]
end

local function nearBridge(p: Vector2): boolean
	for _, b in Layout.Data.park.bridges do
		if (b.at - p).Magnitude < b.span / 2 + 2 then
			return true
		end
	end
	return false
end

function EnvChecks.run(): { [string]: any }
	local points: { { kind: string, p: Vector2 } } = {}
	-- plot reservations: corners and centres in every plot
	for index = 1, Layout.PlotCount do
		local bearing = Layout.plotBearing(index)
		for _, r in Layout.Data.reservations do
			local x0, u0, x1, u1 = Layout.bounds(r.poly)
			for _, q in { Vector2.new(x0, u0), Vector2.new(x1, u0), Vector2.new(x0, u1), Vector2.new(x1, u1) } do
				table.insert(points, { kind = "reservation", p = Layout.plotToPlan(bearing, q) })
			end
			table.insert(
				points,
				{ kind = "reservation", p = Layout.plotToPlan(bearing, Vector2.new((x0 + x1) / 2, (u0 + u1) / 2)) }
			)
		end
	end
	-- corridors: a lattice inside each triangle
	for _, tri in Layout.Data.park.corridors do
		for a = 0, 1, 0.1 do
			for b = 0, 1 - a, 0.1 do
				table.insert(points, { kind = "corridor", p = tri[1] + (tri[2] - tri[1]) * a + (tri[3] - tri[1]) * b })
			end
		end
	end
	-- walk routes every 4 studs
	for _, route in Layout.Data.routes do
		for i = 2, #route.points do
			local a, b = route.points[i - 1], route.points[i]
			local n = math.max(1, math.ceil((b - a).Magnitude / 4))
			for k = 0, n do
				table.insert(points, { kind = "route", p = a:Lerp(b, k / n) })
			end
		end
	end

	local raised: { [string]: number } = { reservation = 0, corridor = 0, route = 0 }
	local unsupported: { [string]: number } = { reservation = 0, route = 0 }
	local examples = {}
	for i, item in points do
		local above, solid, liquid = column(item.p)
		if above > 0.05 then
			raised[item.kind] += 1
			if #examples < 6 then
				table.insert(examples, string.format("%s raised at (%.0f, %.0f)", item.kind, item.p.X, item.p.Y))
			end
		end
		-- corridors are sightlines: flat water in one is fine, so only footing is checked there
		if item.kind ~= "corridor" and solid < 0.25 and not (liquid > 0 and nearBridge(item.p)) then
			unsupported[item.kind] += 1
			if #examples < 12 then
				table.insert(
					examples,
					string.format(
						"%s unsupported at (%.0f, %.0f) solid %.2f liquid %.2f",
						item.kind,
						item.p.X,
						item.p.Y,
						solid,
						liquid
					)
				)
			end
		end
		if i % 400 == 0 then
			task.wait()
		end
	end

	local function liquidAt(p: Vector2): number
		local _, _, liquid = column(p)
		return liquid
	end
	local stream = Layout.Data.park.stream
	local env = workspace:FindFirstChild("Lane3_IslandEnvironment")
	return {
		pointsChecked = #points,
		terrainAboveSurface = raised,
		noGroundBelow = unsupported,
		examples = examples,
		waterLakeCentre = liquidAt(Vector2.new(0, -172)),
		waterPool = liquidAt(Cascade.Pool.centre + Vector2.new(1, -3)),
		waterStreamMiddle = liquidAt(stream[math.floor(#stream / 2)]),
		waterUnderBridges = (function()
			local wet = 0
			for _, b in Layout.Data.park.bridges do
				if liquidAt(b.at) > 0 then
					wet += 1
				end
			end
			return string.format("%d of %d", wet, #Layout.Data.park.bridges)
		end)(),
		waterfall = env ~= nil and env:FindFirstChild("Waterfall") ~= nil,
		curtain = EnvChecks.curtain(),
		-- Task 4 river loop: continuity, lake ends, mirror, a bridge at every crossing, water
		-- in the height field and in the written terrain along the centre line
		river = EnvChecks.river(env ~= nil and env:GetAttribute("TerrainWritten") == true),
	}
end

return EnvChecks
