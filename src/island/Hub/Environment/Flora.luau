--!strict
-- Island environment planting (Lane 3, build-time): mesh trees and shrubs from the island kit
-- (KitAssets), boulders, and reeds on the lake and stream banks. Each tree is a Model of a trunk
-- MeshPart, a canopy MeshPart and an invisible trunk collider. Placement is seeded and
-- deterministic and keeps off the hub, the lake, the channels, the snow and steep rock.
--
-- Grounding: every kit trunk continues `sink` studs below its ground line (y 0 in mesh space)
-- with roots that run along the ground and then dive in. A tree is set at the LOWEST ground
-- under its root spread (24 samples), so on a slope the downhill roots still touch and the
-- uphill side is simply buried deeper; spots where that would bury too much trunk get no tree.
-- The grass under each tree is darkened into a forest floor patch with an uneven edge.
--
-- Habitats: pines on the foothills and flanks (saplings at forest edges); mixed broadleaf
-- clusters on the near rises; willows and birches by the lake; bushes as understory. The park's
-- own trees and flowers are placed by the park dressing, not here.

local HttpService = game:GetService("HttpService")

local Cascade = require(script.Parent.Cascade)
local Field = require(script.Parent.Field)
local KitAssets = require(script.Parent.KitAssets)
local KitManifest = require(script.Parent.KitManifest)
local Layout = require(script.Parent.Parent.Layout)
local Sightlines = require(script.Parent.Sightlines)
local TerrainWriter = require(script.Parent.TerrainWriter)

local Flora = {}

local VARIANTS: { [string]: { string } } = {
	Oak = { "OakA", "OakB", "OakC" },
	Tiered = { "TieredA", "TieredB", "TieredC" },
	Umbrella = { "UmbrellaA", "UmbrellaB", "UmbrellaC" },
	Birch = { "BirchA", "BirchB", "BirchC" },
	Blossom = { "BlossomA", "BlossomB", "BlossomC" },
	Willow = { "WillowA", "WillowB", "WillowC" },
	Fruit = { "FruitA", "FruitB", "FruitC" },
	Pine = { "PineA", "PineB", "PineC" },
}
local BUSHES = { "BushSmall", "BushMedium", "BushLarge", "BerryBush", "FloweringShrub" }
-- canopy sway strength per family (read by the client motion script near the camera)
local SWAY: { [string]: number } = {
	Oak = 0.6,
	Tiered = 0.5,
	Umbrella = 0.55,
	Birch = 1,
	Blossom = 0.8,
	Willow = 1.1,
	Fruit = 0.7,
	Pine = 0.35,
	PineSapling = 0.6,
}
-- forest floor under trees: the terrain's own forest-floor material (Look.TerrainColours)
local FLOOR = Enum.Material.Ground

-- Places a kit rock or reed clump with its ground line at `at` (rocks collide, reeds do not).
local function place(name: string, parent: Instance, at: Vector3, scale: number, yaw: number): Instance
	local solid = string.find(name, "Boulder") ~= nil
	local part = KitAssets.place(name, CFrame.new(at) * CFrame.Angles(0, yaw, 0), scale, solid)
	part.Parent = parent
	return part
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
-- not finished building its collision yet; the lower of the two, so nothing floats.
local function surfaceY(grid: TerrainWriter.Grid, p: Vector2): number
	local h = TerrainWriter.heightAt(grid, p)
	local hit = workspace:Raycast(Vector3.new(p.X, h + 40, -p.Y), Vector3.new(0, -80, 0), terrainOnly)
	if hit then
		h = math.min(h, hit.Position.Y)
	end
	return h
end

local function groundAt(grid: TerrainWriter.Grid, p: Vector2, sink: number): Vector3
	return Vector3.new(p.X, surfaceY(grid, p) - sink, -p.Y)
end

-- The lowest and highest ground under a root spread of radius `reach` (centre, two rings of 12).
local function footprint(grid: TerrainWriter.Grid, p: Vector2, reach: number): (number, number)
	local lo = surfaceY(grid, p)
	local hi = lo
	for k = 0, 11 do
		local a = k * math.pi / 6
		local d = Vector2.new(math.cos(a), math.sin(a))
		for _, f in { 0.5, 1 } do
			local y = surfaceY(grid, p + d * reach * f)
			lo = math.min(lo, y)
			hi = math.max(hi, y)
		end
	end
	return lo, hi
end

export type Patch = { x: number, z: number, y: number, r: number }

-- Turns the grass within an uneven radius into forest floor (material only; occupancy is kept).
-- With `restore`, turns forest floor back into the material each column was generated with.
local function forestFloor(
	centre: Vector3,
	radius: number,
	from: Enum.Material,
	to: Enum.Material,
	restore: ((Vector2) -> Enum.Material)?
): boolean
	local terrain = workspace.Terrain
	local region = Region3.new(
		Vector3.new(centre.X - radius, centre.Y - 10, centre.Z - radius),
		Vector3.new(centre.X + radius, centre.Y + 8, centre.Z + radius)
	):ExpandToGrid(4)
	local materials, occupancy = terrain:ReadVoxels(region, 4)
	local size = materials.Size
	local corner = region.CFrame.Position - region.Size / 2
	local changed = false
	for x = 1, size.X do
		local wx = corner.X + (x - 0.5) * 4
		for z = 1, size.Z do
			local wz = corner.Z + (z - 0.5) * 4
			local d = math.sqrt((wx - centre.X) ^ 2 + (wz - centre.Z) ^ 2)
			local edge = radius * (0.72 + 0.3 * math.noise(wx / 7.3, wz / 7.3, 0.37))
			if d < edge then
				local target = if restore then restore(Vector2.new(wx, -wz)) else to
				for y = 1, size.Y do
					if materials[x][y][z] == from and occupancy[x][y][z] > 0 and target ~= from then
						materials[x][y][z] = target
						changed = true
					end
				end
			end
		end
	end
	if changed then
		terrain:WriteVoxels(region, 4, materials, occupancy)
	end
	return changed
end

export type Counts = {
	trees: number,
	pines: number,
	broadleaf: number,
	bushes: number,
	rocks: number,
	reeds: number,
	clusters: number,
	skippedSteep: number,
	fallsView: number,
	recovery: { attempted: number, recovered: number, stillSteep: number, crowded: number, unplantable: number },
	floorPatches: number,
	triangles: number,
	byVariant: { [string]: number },
}

export type Planter = {
	grid: TerrainWriter.Grid,
	counts: Counts,
	patches: { Patch },
	placed: { { p: Vector2, r: number } },
}

-- Plants one kit tree or bush with its ground line on the lowest ground under its roots.
local function newCounts(): Counts
	return {
		trees = 0,
		pines = 0,
		broadleaf = 0,
		bushes = 0,
		rocks = 0,
		reeds = 0,
		clusters = 0,
		skippedSteep = 0,
		fallsView = 0,
		recovery = { attempted = 0, recovered = 0, stillSteep = 0, crowded = 0, unplantable = 0 },
		floorPatches = 0,
		triangles = 0,
		byVariant = {},
	}
end

-- A planter for other dressing modules (the park): its own counts and floor patches.
function Flora.newPlanter(grid: TerrainWriter.Grid): Planter
	return { grid = grid, counts = newCounts(), patches = {}, placed = {} }
end

-- The plan radius a plant's foliage covers, for spacing recovered plants.
local function crownRadius(variant: string, scale: number): number
	local name = if KitManifest[variant] ~= nil then variant else variant .. "_Canopy"
	local e = KitAssets.info(name)
	return math.max(e.max.X - e.min.X, e.max.Z - e.min.Z) / 2 * scale
end

local function crowded(pl: Planter, q: Vector2, r: number): boolean
	for _, other in pl.placed do
		if (other.p - q).Magnitude < 0.75 * (other.r + r) then
			return true
		end
	end
	return false
end

-- Steep-spot recovery (Adam, 2026-10-21): a skipped spot searches a short ring of nearby points
-- (2.5, 5 and 7.5 studs, eight directions starting from an angle set by the spot) for ground that
-- passes the same trunk-grounding rule, on plantable ground no closer to the hub, and clear of
-- the crowns already planted. The first point that passes is used; otherwise the spot stays
-- empty, counted by its reason.
local RECOVERY_RINGS = { 2.5, 5, 7.5 }
Flora.RecoverSteep = true -- set false (on a required copy) to measure the old planting

local function plant(pl: Planter, parent: Instance, variant: string, p: Vector2, scale: number, yaw: number): Model?
	-- bushes are one mesh; trees are a trunk and a canopy
	local single = KitManifest[variant] ~= nil
	local trunkName = if single then variant else variant .. "_Trunk"
	local info = KitAssets.info(trunkName)
	local meta = info.meta
	local reach = (meta.root_reach or 1) * scale
	local lo, hi = footprint(pl.grid, p, reach)
	-- the uphill side may bury at most this much of the trunk before the spot is too steep
	local maxBury = if single then 0.9 * scale else math.min(3.2, 0.3 * (meta.canopy_base or 6) * scale + 1.2)
	local crown = crownRadius(variant, scale)
	if hi - lo > maxBury then
		pl.counts.skippedSteep += 1
		if not Flora.RecoverSteep then
			return nil
		end
		local rec = pl.counts.recovery
		rec.attempted += 1
		local found: Vector2? = nil
		local anyPlantable, sawCrowded = false, false
		local start = (p.X * 0.731 + p.Y * 0.377) % (math.pi * 2)
		local hub = Field.hubDistance(p)
		for _, ring in RECOVERY_RINGS do
			for k = 0, 7 do
				local a = start + k * math.pi / 4
				local q = p + Vector2.new(math.cos(a), math.sin(a)) * ring
				if plantable(pl.grid, q, 0.7) and Field.hubDistance(q) >= math.min(hub, 160) - 1 then
					anyPlantable = true
					local qlo, qhi = footprint(pl.grid, q, reach)
					if qhi - qlo <= maxBury then
						if crowded(pl, q, crown) then
							sawCrowded = true
						else
							found, lo, hi = q, qlo, qhi
							break
						end
					end
				end
			end
			if found then
				break
			end
		end
		if not found then
			if sawCrowded then
				rec.crowded += 1
			elseif anyPlantable then
				rec.stillSteep += 1
			else
				rec.unplantable += 1
			end
			return nil
		end
		rec.recovered += 1
		p = found :: Vector2
	end
	-- keep the lower falls in view from every plot entrance
	local topName = if single then variant else variant .. "_Canopy"
	if Sightlines.blocksFalls(p, crown, lo + KitAssets.info(topName).max.Y * scale) then
		pl.counts.fallsView += 1
		return nil
	end
	table.insert(pl.placed, { p = p, r = crown })
	local base = CFrame.new(p.X, lo - 0.12, -p.Y) * CFrame.Angles(0, yaw, 0)
	local model = Instance.new("Model")
	model.Name = variant
	local family = info.family
	local triangles = info.triangles
	if single then
		local bush = KitAssets.place(variant, base, scale)
		bush.Name = "Foliage"
		bush:SetAttribute("Sway", 0.5)
		bush.Parent = model
	else
		local trunk = KitAssets.place(trunkName, base, scale)
		trunk.Name = "Trunk"
		trunk.Parent = model
		local canopy = KitAssets.place(variant .. "_Canopy", base, scale)
		canopy.Name = "Canopy"
		canopy:SetAttribute("Sway", SWAY[family] or 0.6)
		canopy:SetAttribute("SwayPivotY", lo + (meta.canopy_base or 4) * scale)
		canopy.Parent = model
		triangles += KitAssets.info(variant .. "_Canopy").triangles
		-- a simple invisible trunk collider instead of mesh collision
		local r = (meta.trunk_radius or 0.6) * scale
		local h = math.max(6, (meta.canopy_base or 6) * scale)
		local collider = Instance.new("Part")
		collider.Name = "Collider"
		collider.Shape = Enum.PartType.Cylinder
		collider.Size = Vector3.new(h, r * 2.2, r * 2.2)
		collider.CFrame = CFrame.new(p.X, lo + h / 2 - 0.5, -p.Y) * CFrame.Angles(0, 0, math.pi / 2)
		collider.Anchored = true
		collider.Transparency = 1
		collider.CastShadow = false
		collider.CanTouch = false
		collider.Parent = model
	end
	model:SetAttribute("Family", family)
	model:SetAttribute("GroundDrop", math.round((hi - lo) * 100) / 100)
	model.WorldPivot = base
	model.Parent = parent
	local c = pl.counts
	c.byVariant[variant] = (c.byVariant[variant] or 0) + 1
	c.triangles += triangles
	if single then
		c.bushes += 1
	else
		c.trees += 1
		if family == "Pine" or family == "PineSapling" then
			c.pines += 1
		else
			c.broadleaf += 1
		end
		local floorR = math.max(3, reach * 1.25)
		if forestFloor(Vector3.new(p.X, lo, -p.Y), floorR, Enum.Material.Grass, FLOOR) then
			table.insert(pl.patches, { x = p.X, z = -p.Y, y = lo, r = floorR })
			c.floorPatches += 1
		end
	end
	return model
end

-- Plants one kit tree (variant, e.g. "OakA") or bush grounded on its lowest root point.
Flora.plant = plant
Flora.plantable = plantable
Flora.surfaceY = surfaceY
Flora.Variants = VARIANTS
Flora.Bushes = BUSHES

-- The patches a planter wrote, for Flora.revertFloor (stored as a JSON attribute on `folder`).
function Flora.recordPatches(folder: Instance, pl: Planter)
	folder:SetAttribute("FloorPatches", HttpService:JSONEncode(pl.patches))
end

local function pick(rng: Random, list: { string }): string
	return list[rng:NextInteger(1, #list)]
end

local function weighted(rng: Random, weights: { [string]: number }): string
	local total = 0
	local keys = {}
	for k, w in weights do
		table.insert(keys, k)
		total += w
	end
	table.sort(keys)
	local roll = rng:NextNumber() * total
	for _, k in keys do
		roll -= weights[k]
		if roll <= 0 then
			return k
		end
	end
	return keys[#keys]
end

local function treeVariant(rng: Random, family: string): string
	if family == "PineSapling" then
		return "PineSapling"
	end
	return pick(rng, VARIANTS[family])
end

-- Returns the forest floor patches written by an earlier planting to the generated material.
function Flora.revertFloor(previous: Instance?, grid: TerrainWriter.Grid)
	local flora = previous and previous:FindFirstChild("Flora")
	if flora then
		Flora.revertPatches(flora, grid)
	end
end

-- Returns the forest floor patches recorded on `folder` to the generated material.
function Flora.revertPatches(folder: Instance, grid: TerrainWriter.Grid)
	local text = folder:GetAttribute("FloorPatches")
	if type(text) ~= "string" then
		return
	end
	local ok, patches = pcall(HttpService.JSONDecode, HttpService, text)
	if ok and type(patches) == "table" then
		for _, q in patches :: { Patch } do
			forestFloor(Vector3.new(q.x, q.y, q.z), q.r + 4, FLOOR, Enum.Material.Grass, function(p: Vector2)
				return TerrainWriter.materialAt(grid, p)
			end)
		end
	end
end

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
	local lakeside = Instance.new("Folder")
	lakeside.Name = "Lakeside"
	lakeside.Parent = folder
	local banks = Instance.new("Folder")
	banks.Name = "Banks"
	banks.Parent = folder
	local pl = Flora.newPlanter(grid)
	local counts = pl.counts
	local rocks = { "BoulderA", "BoulderB", "BoulderC" }
	local reed = "Reeds"

	-- Near-edge clusters: a large broadleaf focal tree, smaller trees of mixed families round it,
	-- understory bushes and a rock or two. Blossom and fruit trees only close to the hub.
	local centres: { Vector2 } = {}
	local tries = 0
	while #centres < 46 and tries < 4000 do
		tries += 1
		local p = Vector2.new(rng:NextNumber(-860, 860), rng:NextNumber(-760, 740))
		local dF = Field.hubDistance(p)
		local ok = dF > 24 and dF < 175 and plantable(grid, p, 0.5)
		if ok then
			for _, q in centres do
				if (q - p).Magnitude < 62 then
					ok = false
					break
				end
			end
		end
		if ok then
			local cluster = Instance.new("Model")
			cluster.Name = string.format("Cluster%02d", #centres + 1)
			local focal = weighted(rng, {
				Oak = 4,
				Umbrella = 2.5,
				Tiered = 2.5,
				Birch = 1.5,
				Blossom = if dF < 70 then 1.2 else 0,
				Fruit = 0, -- their mesh's apples float (Adam, M2-08); back after a re-export
			})
			if plant(pl, cluster, treeVariant(rng, focal), p, rng:NextNumber(1.15, 1.4), rng:NextNumber(0, 6.28)) then
				table.insert(centres, p)
				for _ = 1, rng:NextInteger(2, 5) do
					local q = p + Vector2.new(rng:NextNumber(-24, 24), rng:NextNumber(-24, 24))
					if (q - p).Magnitude > 11 and plantable(grid, q, 0.55) and Field.hubDistance(q) > 16 then
						local fam = weighted(rng, {
							Pine = 3,
							PineSapling = 1,
							Oak = 1,
							Birch = 1.5,
							Tiered = 1,
							[focal] = 2,
						})
						plant(
							pl,
							cluster,
							treeVariant(rng, fam),
							q,
							rng:NextNumber(0.75, 1.05),
							rng:NextNumber(0, 6.28)
						)
					end
				end
				for _ = 1, rng:NextInteger(2, 4) do
					local a = rng:NextNumber(0, 6.28)
					local q = p + Vector2.new(math.cos(a), math.sin(a)) * rng:NextNumber(5, 16)
					if plantable(grid, q, 0.6) and Field.hubDistance(q) > 12 then
						plant(pl, cluster, pick(rng, BUSHES), q, rng:NextNumber(1.4, 2.4), rng:NextNumber(0, 6.28))
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
			else
				cluster:Destroy()
			end
		end
		if tries % 200 == 0 then
			task.wait()
		end
	end

	-- Forest masses on the foothills and lower flanks, in patches: pines, with oak and tiered
	-- trees mixed in low down, saplings and bushes at the patch edges.
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
					local edge = mask < 0.16
					local scale = rng:NextNumber(1.0, 1.6) * (1 - 0.3 * Field.smoothstep(60, 170, h))
					local fam = if edge and rng:NextNumber() < 0.4
						then "PineSapling"
						elseif h < 55 and rng:NextNumber() < 0.18 then (if rng:NextNumber() < 0.6
							then "Oak"
							else "Tiered")
						else "Pine"
					if fam == "PineSapling" then
						scale *= 1.6
					elseif fam ~= "Pine" then
						scale *= 0.9
					end
					plant(pl, forest, treeVariant(rng, fam), p, scale, rng:NextNumber(0, 6.28))
					if edge and rng:NextNumber() < 0.3 then
						local q = p + Vector2.new(rng:NextNumber(-6, 6), rng:NextNumber(-6, 6))
						if plantable(grid, q, 0.7) then
							plant(pl, forest, pick(rng, BUSHES), q, rng:NextNumber(1.6, 2.6), rng:NextNumber(0, 6.28))
						end
					end
				end
			end
		end
		task.wait()
	end

	-- Lakeside: willows leaning over the beach and marsh sides, birches on the rocky shore, kept
	-- out of the portal view and the falls. Task 4: the portal view is the viewing corridors
	-- themselves (a canopy-wide margin), not a fixed |x| < 80 (the wider portal row put a birch in
	-- front of Dusty Highway for Plot 6).
	-- the hub buildings (Garage, Stunt entrance, snack corners, gazebo) with the wings' 14-stud
	-- forecourts, and the leaderboards, plus a canopy margin
	local function nearBuilding(p: Vector2, r: number): boolean
		local park = Layout.Data.park
		local function boxGap(c: Vector2, f: Vector2, w: number, d: number): number
			local side = Vector2.new(-f.Y, f.X)
			local q = p - c
			return math.max(math.abs(q:Dot(side)) - w / 2, math.abs(q:Dot(f)) - d / 2)
		end
		for _, b in park.buildings do
			local fore = if b.id == "Garage" or b.id == "StuntGate" then 14 else 0
			if boxGap(b.centre + b.facing * fore / 2, b.facing, b.width, b.depth + fore) < r then
				return true
			end
		end
		for _, b in park.boards do
			if boxGap(b.centre, b.facing or Vector2.new(0, 1), b.width, b.depth) < r then
				return true
			end
		end
		return false
	end
	local function inPortalView(p: Vector2, r: number): boolean
		for _, tri in Layout.Data.park.corridors do
			local a, b, c = tri[1], tri[2], tri[3]
			for _, off in { Vector2.zero, Vector2.new(r, 0), Vector2.new(-r, 0), Vector2.new(0, r), Vector2.new(0, -r) } do
				local q = p + off
				local d1 = (b.X - a.X) * (q.Y - a.Y) - (b.Y - a.Y) * (q.X - a.X)
				local d2 = (c.X - b.X) * (q.Y - b.Y) - (c.Y - b.Y) * (q.X - b.X)
				local d3 = (a.X - c.X) * (q.Y - c.Y) - (a.Y - c.Y) * (q.X - c.X)
				local neg = d1 < 0 or d2 < 0 or d3 < 0
				local pos = d1 > 0 or d2 > 0 or d3 > 0
				if not (neg and pos) then
					return true
				end
			end
		end
		return false
	end
	local lake = Field.Lake
	local lakeTrees = 0
	tries = 0
	while lakeTrees < 16 and tries < 800 do
		tries += 1
		local a = rng:NextNumber(0, math.pi * 2)
		local e = rng:NextNumber(1.3, 1.55)
		local p = lake.centre + Vector2.new(math.cos(a) * lake.rx * e, math.sin(a) * lake.ry * e)
		local nearFalls = (p - Cascade.Pool.centre).Magnitude < 55
		if
			math.abs(p.X) > 80
			and not nearFalls
			and not inPortalView(p, 6)
			and not nearBuilding(p, 8)
			and plantable(grid, p, 0.45)
		then
			local zone = TerrainWriter.zoneAt(grid, p)
			local fam = if zone == "rocky" then "Birch" elseif rng:NextNumber() < 0.65 then "Willow" else "Birch"
			if plant(pl, lakeside, treeVariant(rng, fam), p, rng:NextNumber(1.0, 1.3), rng:NextNumber(0, 6.28)) then
				lakeTrees += 1
			end
		end
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
	-- Reeds along the river at its waterline, away from the bridges, under 3 tall (outside every
	-- view rule). Task 4: the river is 16 wide, so they stand just inside its edge, not mid-stream.
	local stream = Layout.Data.park.stream
	local edge = Layout.Data.park.streamWidth / 2 + 0.5
	for k = 4, #stream - 2, 6 do
		local a, b = stream[k], stream[k + 1]
		local dir = (b - a).Unit
		local side = Vector2.new(-dir.Y, dir.X) * (if k % 12 == 4 then edge else -edge)
		local p = a + side
		local clear = true
		for _, br in Layout.Data.park.bridges do
			if (br.at - p).Magnitude < 16 then
				clear = false
			end
		end
		if clear then
			place(reed, banks, Vector3.new(p.X, Field.LakeLevel + 0.1, -p.Y), 0.9, rng:NextNumber(0, 6.28))
			counts.reeds += 1
		end
	end

	Flora.recordPatches(folder, pl)
	folder:SetAttribute("MeshSources", HttpService:JSONEncode(KitAssets.sources()))
	folder.Parent = parent
	return counts
end

return Flora
