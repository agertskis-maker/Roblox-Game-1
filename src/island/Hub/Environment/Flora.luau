--!strict
-- Island environment planting for the environment stage (Lane 3, build-time): clustered pines,
-- shrubs and rocks on the near rises, forest masses on the foothills and lower flanks, boulders
-- on the slopes, reeds and stones on the lake and stream banks. Each kind is one Studio union
-- made once and cloned, so a tree is one part. Placement is seeded and deterministic, and keeps
-- off the hub, the lake, the channels, the snow and steep rock. The park's own trees and
-- flowers come later (park dressing), not here.

local GeometryService = game:GetService("GeometryService")

local Cascade = require(script.Parent.Cascade)
local Field = require(script.Parent.Field)
local Layout = require(script.Parent.Parent.Layout)
local TerrainWriter = require(script.Parent.TerrainWriter)

local Flora = {}

local rgb = Color3.fromRGB
local GREENS = {
	{ rgb(44, 104, 68), rgb(58, 128, 78), rgb(80, 150, 88) },
	{ rgb(38, 96, 72), rgb(52, 118, 84), rgb(72, 140, 92) },
	{ rgb(52, 110, 62), rgb(70, 134, 72), rgb(96, 158, 82) },
}
local BARK = rgb(116, 84, 58)

-- Unions the parts into one part (falls back to a model of parts if unions are unavailable).
local function union(parts: { BasePart }, name: string): BasePart | Model
	local holder = Instance.new("Model")
	holder.Name = "Lane3_EnvTemplate"
	for _, p in parts do
		p.Parent = holder
	end
	holder.Parent = workspace
	local ok, result = pcall(function()
		return GeometryService:UnionAsync(parts[1], table.move(parts, 2, #parts, 1, {}), {
			CollisionFidelity = Enum.CollisionFidelity.Box,
			RenderFidelity = Enum.RenderFidelity.Automatic,
			SplitApart = false,
		})
	end)
	if ok and result and result[1] then
		local u = result[1] :: BasePart
		u.Name = name
		u.UsePartColor = false
		u.Anchored = true
		u.Parent = nil
		holder:Destroy()
		return u
	end
	holder.Name = name
	holder.Parent = nil
	return holder
end

local function block(size: Vector3, cf: CFrame, colour: Color3, material: Enum.Material?): Part
	local p = Instance.new("Part")
	p.Size = size
	p.CFrame = cf
	p.Color = colour
	p.Material = material or Enum.Material.SmoothPlastic
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	return p
end

-- A layered pine 20 tall: trunk and four square tiers turned alternately (reference 2's
-- chunky stacked silhouette).
local function pineTemplate(widthRatio: number, greens: { Color3 }, name: string): BasePart | Model
	local H = 20
	local W = H * widthRatio
	local parts: { BasePart } = { block(Vector3.new(1.6, H * 0.3, 1.6), CFrame.new(0, H * 0.15, 0), BARK) }
	local scales = { 1, 0.76, 0.53, 0.3 }
	for k, s in scales do
		local y = H * (0.22 + 0.19 * (k - 1))
		local colour = greens[math.min(k, #greens)]
		table.insert(
			parts,
			block(
				Vector3.new(W * s, H * 0.22, W * s),
				CFrame.new(0, y + H * 0.11, 0) * CFrame.Angles(0, math.rad(if k % 2 == 0 then 45 else 0), 0),
				colour
			)
		)
	end
	return union(parts, name)
end

local function shrubTemplate(name: string): BasePart | Model
	local parts: { BasePart } = {}
	for k, spec in { { 0, 1.6, 0, 3.4 }, { 1.6, 1.2, 0.6, 2.6 }, { -1.3, 1.1, -0.8, 2.4 } } do
		local ball = block(Vector3.one * spec[4], CFrame.new(spec[1], spec[2], spec[3]), GREENS[1][math.min(k + 1, 3)])
		ball.Shape = Enum.PartType.Ball
		table.insert(parts, ball)
	end
	return union(parts, name)
end

local function rockTemplate(name: string, seed: number): BasePart | Model
	local rng = Random.new(seed)
	local parts: { BasePart } = {}
	for _ = 1, 3 do
		local s = Vector3.new(rng:NextNumber(3, 6), rng:NextNumber(2, 4), rng:NextNumber(3, 5))
		local cf = CFrame.new(rng:NextNumber(-1.5, 1.5), s.Y / 2 - 0.6, rng:NextNumber(-1.5, 1.5))
			* CFrame.Angles(rng:NextNumber(-0.4, 0.4), rng:NextNumber(0, math.pi), rng:NextNumber(-0.4, 0.4))
		table.insert(parts, block(s, cf, rgb(132, 138, 144), Enum.Material.Slate))
	end
	return union(parts, name)
end

local function reedTemplate(name: string): BasePart | Model
	local parts: { BasePart } = {}
	local rng = Random.new(11)
	for k = 1, 7 do
		local h = rng:NextNumber(1.6, 2.7)
		local cf = CFrame.new(rng:NextNumber(-0.9, 0.9), h / 2, rng:NextNumber(-0.9, 0.9))
			* CFrame.Angles(rng:NextNumber(-0.15, 0.15), 0, rng:NextNumber(-0.15, 0.15))
		table.insert(
			parts,
			block(Vector3.new(0.25, h, 0.25), cf, if k % 3 == 0 then rgb(150, 140, 86) else rgb(96, 140, 70))
		)
	end
	return union(parts, name)
end

local function place(template: BasePart | Model, parent: Instance, at: Vector3, scale: number, yaw: number): Instance
	local c = template:Clone()
	if c:IsA("BasePart") then
		c.Size *= scale
		c.CFrame = CFrame.new(at + Vector3.new(0, c.Size.Y / 2, 0)) * CFrame.Angles(0, yaw, 0)
		c.CanTouch = false
		c.CastShadow = true
	elseif c:IsA("Model") then
		c:ScaleTo(scale)
		local _, size = c:GetBoundingBox()
		c:PivotTo(CFrame.new(at + Vector3.new(0, size.Y / 2, 0)) * CFrame.Angles(0, yaw, 0))
	end
	c.Parent = parent
	return c
end

local LAKE_OR_WATER = TerrainWriter.Flags.LAKE + TerrainWriter.Flags.CHANNEL

local function plantable(grid: TerrainWriter.Grid, p: Vector2, maxSlope: number): boolean
	local box = Field.Box
	if p.X < box.minX + 8 or p.X > box.maxX - 8 or -p.Y < box.minZ + 8 or -p.Y > box.maxZ - 8 then
		return false
	end
	if bit32.band(TerrainWriter.flagsAt(grid, p), LAKE_OR_WATER + TerrainWriter.Flags.BANK) ~= 0 then
		return false
	end
	if Field.lakeE(p) < 1.25 then
		return false
	end
	return TerrainWriter.slopeAt(grid, p) < maxSlope
end

local terrainOnly = RaycastParams.new()
terrainOnly.FilterType = Enum.RaycastFilterType.Include
terrainOnly.FilterDescendantsInstances = { workspace.Terrain }

-- The rendered surface (a ray down onto the terrain), or the computed height if the terrain has
-- not finished building its collision yet; the lower of the two, so nothing floats on a slope.
local function groundAt(grid: TerrainWriter.Grid, p: Vector2, sink: number): Vector3
	local h = TerrainWriter.heightAt(grid, p)
	local hit = workspace:Raycast(Vector3.new(p.X, h + 40, -p.Y), Vector3.new(0, -80, 0), terrainOnly)
	if hit then
		h = math.min(h, hit.Position.Y)
	end
	return Vector3.new(p.X, h - sink, -p.Y)
end

export type Counts = { pines: number, shrubs: number, rocks: number, reeds: number, clusters: number }

function Flora.build(parent: Instance, grid: TerrainWriter.Grid, seed: number): Counts
	-- give the new terrain a moment to build collision so the rays below can land on it
	for _ = 1, 30 do
		task.wait()
	end
	local rng = Random.new(seed + 101)
	local folder = Instance.new("Folder")
	folder.Name = "Flora"
	local near = Instance.new("Folder")
	near.Name = "NearClusters"
	near.Parent = folder
	local forest = Instance.new("Folder")
	forest.Name = "Forest"
	forest.Parent = folder
	local banks = Instance.new("Folder")
	banks.Name = "Banks"
	banks.Parent = folder
	local counts: Counts = { pines = 0, shrubs = 0, rocks = 0, reeds = 0, clusters = 0 }

	local pines = {
		pineTemplate(0.42, GREENS[1], "PineSlim"),
		pineTemplate(0.5, GREENS[2], "PineMedium"),
		pineTemplate(0.6, GREENS[3], "PineBroad"),
	}
	local shrub = shrubTemplate("Shrub")
	local rocks = { rockTemplate("RockA", seed + 1), rockTemplate("RockB", seed + 2), rockTemplate("RockC", seed + 3) }
	local reed = reedTemplate("Reeds")

	-- Near-edge clusters: a large focal pine, smaller pines round it, shrubs and a rock or two.
	local centres: { Vector2 } = {}
	local tries = 0
	while #centres < 46 and tries < 4000 do
		tries += 1
		local p = Vector2.new(rng:NextNumber(-860, 860), rng:NextNumber(-760, 740))
		local dF = Field.hubDistance(p)
		local ok = dF > 24 and dF < 175 and plantable(grid, p, 0.55)
		if ok then
			for _, q in centres do
				if (q - p).Magnitude < 62 then
					ok = false
					break
				end
			end
		end
		if ok then
			table.insert(centres, p)
			local cluster = Instance.new("Model")
			cluster.Name = string.format("Cluster%02d", #centres)
			place(
				pines[rng:NextInteger(1, 3)],
				cluster,
				groundAt(grid, p, 0.6),
				rng:NextNumber(1.25, 1.55),
				rng:NextNumber(0, 6.28)
			)
			counts.pines += 1
			for _ = 1, rng:NextInteger(3, 7) do
				local q = p + Vector2.new(rng:NextNumber(-22, 22), rng:NextNumber(-22, 22))
				if plantable(grid, q, 0.6) and Field.hubDistance(q) > 16 then
					place(
						pines[rng:NextInteger(1, 3)],
						cluster,
						groundAt(grid, q, 0.6),
						rng:NextNumber(0.6, 1.1),
						rng:NextNumber(0, 6.28)
					)
					counts.pines += 1
				end
			end
			for _ = 1, rng:NextInteger(1, 3) do
				local q = p + Vector2.new(rng:NextNumber(-14, 14), rng:NextNumber(-14, 14))
				if plantable(grid, q, 0.6) and Field.hubDistance(q) > 12 then
					place(shrub, cluster, groundAt(grid, q, 0.8), rng:NextNumber(0.8, 1.4), rng:NextNumber(0, 6.28))
					counts.shrubs += 1
				end
			end
			for _ = 1, rng:NextInteger(0, 2) do
				local q = p + Vector2.new(rng:NextNumber(-16, 16), rng:NextNumber(-16, 16))
				if plantable(grid, q, 0.8) and Field.hubDistance(q) > 12 then
					place(
						rocks[rng:NextInteger(1, 3)],
						cluster,
						groundAt(grid, q, 1),
						rng:NextNumber(0.8, 1.6),
						rng:NextNumber(0, 6.28)
					)
					counts.rocks += 1
				end
			end
			cluster.Parent = near
			counts.clusters += 1
		end
	end

	-- Forest masses on the foothills and lower flanks, in patches rather than an even scatter.
	local nz = Field.noiseFor(seed + 5)
	for gx = Field.Box.minX + 10, Field.Box.maxX - 10, 15 do
		for gy = -Field.Box.maxZ + 10, -Field.Box.minZ - 10, 15 do
			if counts.pines > 1100 then
				break
			end
			local p = Vector2.new(gx + rng:NextNumber(-6, 6), gy + rng:NextNumber(-6, 6))
			local dF = Field.hubDistance(p)
			if dF > 150 then
				local h = TerrainWriter.heightAt(grid, p)
				local mask = math.noise(p.X / 240 + nz.ox, p.Y / 240 + nz.oy, nz.oz[1])
					+ 0.35 * math.noise(p.X / 70 + nz.ox, p.Y / 70 + nz.oy, nz.oz[2])
				local treeLine = 1 - Field.smoothstep(120, 175, h)
				if h > 12 and mask > 0.08 and rng:NextNumber() < 0.85 * treeLine and plantable(grid, p, 0.7) then
					local scale = rng:NextNumber(1.0, 1.7) * (1 - 0.3 * Field.smoothstep(60, 170, h))
					place(pines[rng:NextInteger(1, 3)], forest, groundAt(grid, p, 0.8), scale, rng:NextNumber(0, 6.28))
					counts.pines += 1
				end
			end
		end
		task.wait()
	end

	-- Boulders on the slopes below the snow.
	local boulders = 0
	tries = 0
	while boulders < 70 and tries < 3000 do
		tries += 1
		local p = Vector2.new(rng:NextNumber(-860, 860), rng:NextNumber(-760, 740))
		local h = TerrainWriter.heightAt(grid, p)
		if Field.hubDistance(p) > 120 and h > 10 and h < 200 and plantable(grid, p, 1.0) then
			place(
				rocks[rng:NextInteger(1, 3)],
				forest,
				groundAt(grid, p, 1.2),
				rng:NextNumber(1.4, 3.2),
				rng:NextNumber(0, 6.28)
			)
			boulders += 1
		end
	end
	counts.rocks += boulders

	-- Reeds and stones on the lake banks, kept out of the portal view (|x| > 80) and the falls.
	local lake = Field.Lake
	for k = 0, 71 do
		local a = k / 72 * math.pi * 2
		local p = lake.centre + Vector2.new(math.cos(a) * lake.rx * 1.04, math.sin(a) * lake.ry * 1.04)
		local nearFalls = (p - Cascade.Pool.centre).Magnitude < 40
		if math.abs(p.X) > 80 and not nearFalls and rng:NextNumber() < 0.75 then
			local at = Vector3.new(p.X, TerrainWriter.heightAt(grid, p) - 0.3, -p.Y)
			if rng:NextNumber() < 0.6 then
				place(reed, banks, at, rng:NextNumber(0.9, 1.3), rng:NextNumber(0, 6.28))
				counts.reeds += 1
			else
				place(
					rocks[rng:NextInteger(1, 3)],
					banks,
					at - Vector3.new(0, 0.6, 0),
					rng:NextNumber(0.6, 1.1),
					rng:NextNumber(0, 6.28)
				)
				counts.rocks += 1
			end
		end
	end
	-- Reeds along the park stream, away from the bridges, under 3 tall (outside every view rule).
	local stream = Layout.Data.park.stream
	for k = 4, #stream - 2, 6 do
		local a, b = stream[k], stream[k + 1]
		local dir = (b - a).Unit
		local side = Vector2.new(-dir.Y, dir.X) * (if k % 12 == 4 then 6.5 else -6.5)
		local p = a + side
		local clear = true
		for _, br in Layout.Data.park.bridges do
			if (br.at - p).Magnitude < 16 then
				clear = false
			end
		end
		if clear then
			place(reed, banks, Vector3.new(p.X, -0.3, -p.Y), 0.9, rng:NextNumber(0, 6.28))
			counts.reeds += 1
		end
	end

	for _, t in pines do
		t:Destroy()
	end
	shrub:Destroy()
	reed:Destroy()
	for _, r in rocks do
		r:Destroy()
	end
	folder.Parent = parent
	return counts
end

return Flora
