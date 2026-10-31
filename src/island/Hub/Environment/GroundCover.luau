--!strict
-- Ground vegetation outside the park (Lane 3, build-time), from the island kit:
--   flower drifts: one kind and colour per drift, 7 to 12 clumps in a soft blob, on gentle sunny
--     grass; taller kinds (sunflowers, lavender) only low down and in the sun;
--   grass: tufts and tall grass along the lake shore (outside the beach and the portal view);
--   understory: ferns in the shade of pines and clusters, leaf litter under broadleaf trees,
--     red/white and brown mushrooms at some tree bases;
--   a hollow fallen log at three cluster edges (one is the raccoon's), stumps at forest edges,
--     mossy rocks in the shade.
-- The park's lawns and path edges are dressed by ParkDressing. Placement is seeded. Writes
-- WildlifeAnchors for butterflies (flower drifts), the raccoon (its log) and fireflies (shady
-- fern spots in tree clusters).
-- Terrain grass decoration is not used: this Studio build has no Terrain.Decoration property
-- (checked 2026-10-21), so grass near paths and the lake is kit meshes.

local Cascade = require(script.Parent.Cascade)
local Field = require(script.Parent.Field)
local Flora = require(script.Parent.Flora)
local KitAssets = require(script.Parent.KitAssets)
local Layout = require(script.Parent.Parent.Layout)
local TerrainWriter = require(script.Parent.TerrainWriter)

local GroundCover = {}

type Ctx = {
	root: Folder,
	anchors: BasePart,
	folders: { [string]: Folder },
	counts: { [string]: number },
	triangles: number,
	rng: Random,
	grid: TerrainWriter.Grid,
}

local function folder(ctx: Ctx, name: string): Folder
	local f = ctx.folders[name]
	if not f then
		f = Instance.new("Folder")
		f.Name = name
		f.Parent = ctx.root
		ctx.folders[name] = f
	end
	return f
end

local function put(
	ctx: Ctx,
	category: string,
	name: string,
	p: Vector2,
	sink: number,
	yaw: number,
	scale: number
): MeshPart?
	if Layout.inDestination(p, 2) then
		return nil -- not on a hub building, forecourt, apron or leaderboard (Task 4 review N2)
	end
	local y = Flora.surfaceY(ctx.grid, p) - sink
	local base = CFrame.new(p.X, y, -p.Y) * CFrame.Angles(0, yaw, 0)
	local part = KitAssets.place(name, base, scale)
	part.Parent = folder(ctx, category)
	ctx.counts[name] = (ctx.counts[name] or 0) + 1
	ctx.triangles += KitAssets.info(name).triangles
	return part
end

local function anchor(ctx: Ctx, kind: string, at: Vector3, data: { [string]: any }?)
	local a = Instance.new("Attachment")
	a.Name = kind
	a.Position = at
	for k, v in data or {} do
		a:SetAttribute(k, v)
	end
	a.Parent = ctx.anchors
end

local function weighted(rng: Random, weights: { [string]: number }): string
	local keys, total = {}, 0
	for k, w in weights do
		if w > 0 then
			table.insert(keys, k)
			total += w
		end
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

local function grassy(ctx: Ctx, p: Vector2): boolean
	return TerrainWriter.materialAt(ctx.grid, p) == Enum.Material.Grass
end

-- ---------------------------------------------------------------- flower drifts
local function buildDrifts(ctx: Ctx)
	local drifts, tries = 0, 0
	local centres: { Vector2 } = {}
	while drifts < 34 and tries < 5000 do
		tries += 1
		local p = Vector2.new(ctx.rng:NextNumber(-840, 840), ctx.rng:NextNumber(-740, 720))
		local dF = Field.hubDistance(p)
		local h = TerrainWriter.heightAt(ctx.grid, p)
		local ok = dF > 6
			and dF < 260
			and h < 90
			and Flora.plantable(ctx.grid, p, 0.32)
			and grassy(ctx, p)
			and Field.lakeE(p) > 1.3
			and (p - Cascade.Pool.centre).Magnitude > 60
		if ok then
			for _, q in centres do
				if (q - p).Magnitude < 40 then
					ok = false
					break
				end
			end
		end
		if ok then
			table.insert(centres, p)
			drifts += 1
			local kind = weighted(ctx.rng, {
				Daisies = 3,
				BlueWildflowers = 3,
				Poppies = 2.2,
				TulipsYellow = 1,
				TulipsRed = 1,
				Lavender = if h < 50 then 1.5 else 0,
				Sunflowers = if h < 35 then 0.7 else 0,
			})
			local n = ctx.rng:NextInteger(7, 12)
			local stretch = Vector2.new(ctx.rng:NextNumber(0.6, 1.4), ctx.rng:NextNumber(0.6, 1.4))
			for _ = 1, n do
				local a = ctx.rng:NextNumber(0, 6.28)
				local r = 6 * math.sqrt(ctx.rng:NextNumber())
				local q = p + Vector2.new(math.cos(a) * r * stretch.X, math.sin(a) * r * stretch.Y)
				if Flora.plantable(ctx.grid, q, 0.4) then
					put(ctx, "Flowers", kind, q, 0.15, ctx.rng:NextNumber(0, 6.28), ctx.rng:NextNumber(0.9, 1.15))
				end
			end
			-- grass and clover round the drift's edge tie it into the meadow
			for _ = 1, ctx.rng:NextInteger(2, 4) do
				local a = ctx.rng:NextNumber(0, 6.28)
				local q = p + Vector2.new(math.cos(a), math.sin(a)) * ctx.rng:NextNumber(6, 9)
				if Flora.plantable(ctx.grid, q, 0.4) then
					put(ctx, "Grass", if ctx.rng:NextNumber() < 0.5 then "GrassTuftWide" else "Clover", q, 0.1, a, 1)
				end
			end
			if drifts % 3 == 1 then
				anchor(ctx, "ButterflyDrift", Vector3.new(p.X, Flora.surfaceY(ctx.grid, p) + 2, -p.Y), { Radius = 8 })
			end
		end
	end
	ctx.counts.drifts = drifts
end

-- ---------------------------------------------------------------- lake shore grass
local function buildShoreGrass(ctx: Ctx)
	local lake = Field.Lake
	for k = 0, 119 do
		local theta = k * 3 + ctx.rng:NextNumber(-1, 1)
		local t = math.rad(theta)
		local e = ctx.rng:NextNumber(1.08, 1.3)
		local p = lake.centre + Vector2.new(math.cos(t) * lake.rx * e, math.sin(t) * lake.ry * e)
		local z = Field.LakeZones
		local beach = theta >= z.beach.from and theta <= z.beach.to
		local view = math.abs(p.X) < 80 and p.Y > lake.centre.Y
		if not beach and not view and Flora.plantable(ctx.grid, p, 0.5) and ctx.rng:NextNumber() < 0.7 then
			local name = if ctx.rng:NextNumber() < 0.45 then "TallGrass" else "GrassTuftWide"
			put(ctx, "Grass", name, p, 0.15, ctx.rng:NextNumber(0, 6.28), ctx.rng:NextNumber(0.9, 1.3))
		end
	end
end

-- ---------------------------------------------------------------- understory, logs, rocks
local function buildUnderstory(ctx: Ctx, flora: Instance?)
	if not flora then
		return
	end
	local clusters: { Model } = {}
	local fireflies, clusterFerns = 0, 0
	for _, m in flora:GetDescendants() do
		if m:IsA("Model") and m:FindFirstChild("Trunk") then
			local pivot = m.WorldPivot.Position
			local p = Vector2.new(pivot.X, -pivot.Z)
			local family = m:GetAttribute("Family")
			local inCluster = m.Parent and m.Parent:IsA("Model")
			local pine = family == "Pine" or family == "PineSapling"
			local roll = ctx.rng:NextNumber()
			if (inCluster and roll < 0.5) or (pine and roll < 0.16) then
				for _ = 1, ctx.rng:NextInteger(1, 2) do
					local a = ctx.rng:NextNumber(0, 6.28)
					local q = p + Vector2.new(math.cos(a), math.sin(a)) * ctx.rng:NextNumber(2.5, 5.5)
					if Flora.plantable(ctx.grid, q, 0.7) then
						put(
							ctx,
							"Understory",
							if ctx.rng:NextNumber() < 0.5 then "FernA" else "FernB",
							q,
							0.1,
							a,
							ctx.rng:NextNumber(0.9, 1.4)
						)
						-- every sixth fern in a tree cluster is a shady spot for fireflies (no random draw, so
						-- the rest of the planting is unchanged)
						clusterFerns += if inCluster then 1 else 0
						if inCluster and fireflies < 12 and clusterFerns % 6 == 0 then
							fireflies += 1
							anchor(ctx, "FireflyShade", Vector3.new(q.X, Flora.surfaceY(ctx.grid, q) + 1.5, -q.Y))
						end
					end
				end
			end
			if not pine and inCluster and ctx.rng:NextNumber() < 0.7 then
				put(ctx, "Understory", "LeafLitter", p, 0.02, ctx.rng:NextNumber(0, 6.28), ctx.rng:NextNumber(1.1, 1.6))
			end
			if ctx.rng:NextNumber() < 0.07 then
				local a = ctx.rng:NextNumber(0, 6.28)
				local q = p + Vector2.new(math.cos(a), math.sin(a)) * ctx.rng:NextNumber(1.8, 3)
				put(
					ctx,
					"Understory",
					if ctx.rng:NextNumber() < 0.5 then "MushroomsRed" else "MushroomsBrown",
					q,
					0.1,
					a,
					1
				)
			end
			if inCluster and m.Parent and not table.find(clusters, m.Parent :: Model) then
				table.insert(clusters, m.Parent :: Model)
			end
		end
	end
	-- hollow logs at three cluster edges; the first is the raccoon's
	local logs = 0
	for _, cluster in clusters do
		if logs >= 3 then
			break
		end
		local pivot = cluster:GetPivot().Position
		local p = Vector2.new(pivot.X, -pivot.Z)
		local a = ctx.rng:NextNumber(0, 6.28)
		local q = p + Vector2.new(math.cos(a), math.sin(a)) * 13
		if Flora.plantable(ctx.grid, q, 0.25) and Field.hubDistance(q) > 30 then
			local log = put(ctx, "Logs", "HollowLog", q, 0.3, a + math.pi / 2, 1)
			if not log then
				continue
			end
			logs += 1
			put(ctx, "Logs", "MushroomsBrown", q + Vector2.new(math.cos(a), math.sin(a)) * 2.2, 0.1, a, 1)
			if logs == 1 then
				anchor(ctx, "RaccoonLog", log.Position, { Yaw = a + math.pi / 2 })
			end
		end
	end
	-- stumps and mossy rocks in the forest shade
	local forest = flora:FindFirstChild("Forest")
	local stumps, mossy = 0, 0
	if forest then
		for _, m in forest:GetChildren() do
			if m:IsA("Model") and m:FindFirstChild("Trunk") then
				local pivot = m.WorldPivot.Position
				local p = Vector2.new(pivot.X, -pivot.Z)
				local roll = ctx.rng:NextNumber()
				local a = ctx.rng:NextNumber(0, 6.28)
				local q = p + Vector2.new(math.cos(a), math.sin(a)) * ctx.rng:NextNumber(5, 8)
				if roll < 0.012 and stumps < 10 and Flora.plantable(ctx.grid, q, 0.5) then
					stumps += 1
					put(ctx, "Logs", "Stump", q, 0, a, ctx.rng:NextNumber(0.9, 1.3))
				elseif roll > 0.975 and mossy < 20 and Flora.plantable(ctx.grid, q, 0.8) then
					mossy += 1
					local name = if ctx.rng:NextNumber() < 0.5 then "MossyRockA" else "MossyRockB"
					put(ctx, "Rocks", name, q, KitAssets.info(name).meta.sink or 0.6, a, ctx.rng:NextNumber(0.8, 1.4))
				end
			end
		end
	end
	ctx.counts.logs = logs
	ctx.counts.fireflySpots = fireflies
end

export type Report = { counts: { [string]: number }, triangles: number, parts: number, seconds: number }

function GroundCover.build(parent: Instance, grid: TerrainWriter.Grid, seed: number): Report
	local started = os.clock()
	local old = parent:FindFirstChild("GroundCover")
	if old then
		old:Destroy()
	end
	local root = Instance.new("Folder")
	root.Name = "GroundCover"
	local anchors = Instance.new("Part")
	anchors.Name = "WildlifeAnchors"
	anchors.Anchored = true
	anchors.CanCollide = false
	anchors.CanQuery = false
	anchors.CanTouch = false
	anchors.Transparency = 1
	anchors.Size = Vector3.one
	anchors.CFrame = CFrame.new()
	anchors.Parent = root
	local ctx: Ctx = {
		root = root,
		anchors = anchors,
		folders = {},
		counts = {},
		triangles = 0,
		rng = Random.new(seed + 707),
		grid = grid,
	}
	buildDrifts(ctx)
	task.wait()
	buildShoreGrass(ctx)
	buildUnderstory(ctx, parent:FindFirstChild("Flora"))
	root.Parent = parent
	local parts = 0
	for _, d in root:GetDescendants() do
		if d:IsA("BasePart") then
			parts += 1
		end
	end
	return {
		counts = ctx.counts,
		triangles = ctx.triangles,
		parts = parts,
		seconds = math.round((os.clock() - started) * 100) / 100,
	}
end

return GroundCover
