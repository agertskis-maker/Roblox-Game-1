--!strict
-- DEVELOPMENT CHECKS (Lane 3). Reads the terrain itself after the environment build and checks
-- that it keeps the approved layout: nothing above the walking surface inside any plot
-- reservation, viewing corridor or walk route; solid ground under them (water only under the
-- bridges); water in the lake, pool, stream and outlet; the waterfall present.
--
--   local I = game.ServerStorage.Island:Clone()
--   require(I.Hub.Preview.EnvChecks).run()

local Layout = require(script.Parent.Parent.Layout)

local EnvChecks = {}

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
		waterPool = liquidAt(Vector2.new(-120, -268)),
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
	}
end

return EnvChecks
