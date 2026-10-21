--!strict
-- Park dressing (Lane 3, build-time): the shared park's finished objects from the island kit,
-- placed by rule from the approved layout (HubData.park) into
-- Workspace.Lane3_IslandEnvironment.ParkDressing. While that folder exists, the greybox park
-- recipe keeps its fountain, bridge, gazebo and food-stand placeholders only as invisible
-- colliders.
--
-- Rules: nothing sits on a path, the stream, a bridge approach, a building or the portal row;
-- nothing taller than 3 studs reaches into a viewing corridor (the same corner test as
-- LayoutChecks); trees keep breathing room round paths and each other. Placement is seeded.
--   Fountain      tiered fountain (stone under 3; the water jets give it height)
--   Bridges       one kit bridge per crossing (rail-less where two bridges share a junction)
--   Buildings     gazebo; food stands (decorative only: no prices or shop prompts)
--   Furniture     benches along paths, lamp posts outside the corridors, signpost structures
--                 with blank boards (their designed content follows the Figma workflow)
--   Hedges        low hedges round the plaza, topiary, the car topiary, lakeside fences
--   Beds          raised flower beds in colour drifts (tulips, daisies, sunflowers, lavender, roses)
--   Trees         oak, blossom, birch and fruit trees framing paths, willows and birches by the
--                 stream, bushes beneath; forest floor under each tree

local HttpService = game:GetService("HttpService")

local AssetIds = require(script.Parent.AssetIds)
local Flora = require(script.Parent.Flora)
local KitAssets = require(script.Parent.KitAssets)
local Layout = require(script.Parent.Parent.Layout)
local TerrainWriter = require(script.Parent.TerrainWriter)

local ParkDressing = {}

local park = Layout.Data.park
local SURFACE = Layout.SurfaceY
local CORRIDOR_HEIGHT = 3
local PARK_OUTER = park.promenade.inner - 3

-- ---------------------------------------------------------------- plan geometry
local function cross(a: Vector2, b: Vector2): number
	return a.X * b.Y - a.Y * b.X
end

local function inTriangle(p: Vector2, a: Vector2, b: Vector2, c: Vector2): boolean
	local d1, d2, d3 = cross(b - a, p - a), cross(c - b, p - b), cross(a - c, p - c)
	local neg = d1 < 0 or d2 < 0 or d3 < 0
	local pos = d1 > 0 or d2 > 0 or d3 > 0
	return not (neg and pos)
end

local function inCorridor(p: Vector2): boolean
	for _, tri in park.corridors do
		if inTriangle(p, tri[1], tri[2], tri[3]) then
			return true
		end
	end
	return false
end

local function segmentDistance(p: Vector2, a: Vector2, b: Vector2): number
	local ab = b - a
	local t = if ab.Magnitude > 1e-6 then math.clamp((p - a):Dot(ab) / ab:Dot(ab), 0, 1) else 0
	return (p - (a + ab * t)).Magnitude
end

local function polylineDistance(points: { Vector2 }, p: Vector2): number
	local best = math.huge
	for i = 1, #points - 1 do
		best = math.min(best, segmentDistance(p, points[i], points[i + 1]))
	end
	return best
end

-- Distance from p to the nearest path edge (negative on a path), and that path.
local function pathClear(p: Vector2): (number, any)
	local best, which = math.huge, nil
	for _, path in park.paths do
		local pts = (path :: any).points
		if pts then
			local d = polylineDistance(pts, p) - ((path :: any).width or 8) / 2
			if d < best then
				best, which = d, path
			end
		end
	end
	return best, which
end

local function streamClear(p: Vector2): number
	return polylineDistance(park.stream, p) - park.streamWidth / 2
end

local function boxClear(p: Vector2, centre: Vector2, facing: Vector2, width: number, depth: number): number
	local side = Vector2.new(-facing.Y, facing.X)
	local d = p - centre
	return math.max(math.abs(d:Dot(side)) - width / 2, math.abs(d:Dot(facing)) - depth / 2)
end

local function buildingClear(p: Vector2): number
	local best = math.huge
	for _, b in park.buildings do
		best = math.min(best, boxClear(p, b.centre, b.facing, b.width, b.depth))
	end
	for _, b in park.boards do
		best = math.min(best, boxClear(p, b.centre, Vector2.new(0, 1), b.width, b.depth))
	end
	-- the portal row and its approach
	local pr = park.portal
	best = math.min(
		best,
		boxClear(
			p,
			Vector2.new(0, pr.frontY - pr.depth / 2),
			Vector2.new(0, 1),
			3 * pr.spacing + 2 * pr.width,
			pr.depth + 20
		)
	)
	return best
end

local function bridgeClear(p: Vector2): number
	local best = math.huge
	for _, b in park.bridges do
		best = math.min(best, (p - b.at).Magnitude - math.max(b.span, b.deckWidth) / 2)
	end
	return best
end

local function yawAlong(d: Vector2): number -- mesh +X along plan direction d
	return math.atan2(d.Y, d.X)
end

local function yawFacing(f: Vector2): number -- mesh +Z (its front) toward plan direction f
	return math.atan2(f.X, -f.Y)
end

local terrainOnly = RaycastParams.new()
terrainOnly.FilterType = Enum.RaycastFilterType.Include
terrainOnly.FilterDescendantsInstances = { workspace.Terrain }

local function groundY(p: Vector2): number
	local hit = workspace:Raycast(Vector3.new(p.X, SURFACE + 60, -p.Y), Vector3.new(0, -120, 0), terrainOnly)
	return if hit then hit.Position.Y else SURFACE
end

-- ---------------------------------------------------------------- placing
type Taken = { p: Vector2, r: number }

type Ctx = {
	root: Folder,
	folders: { [string]: Folder },
	taken: { Taken },
	counts: { [string]: number },
	rejected: { [string]: number },
	triangles: number,
	planter: Flora.Planter,
	rng: Random,
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

local function free(ctx: Ctx, p: Vector2, r: number): boolean
	for _, t in ctx.taken do
		if (t.p - p).Magnitude < t.r + r then
			return false
		end
	end
	return true
end

local function corridorSafe(name: string, base: CFrame, scale: number): boolean
	local corners, top = KitAssets.footprint(name, base, scale)
	if top - SURFACE <= CORRIDOR_HEIGHT then
		return true
	end
	for _, c in corners do
		if inCorridor(c) then
			return false
		end
	end
	return true
end

-- Places one kit mesh with its ground line at the ground under p. Returns nil (and counts the
-- reason) when it would reach into a viewing corridor while taller than 3.
local function put(
	ctx: Ctx,
	category: string,
	name: string,
	p: Vector2,
	yaw: number,
	scale: number,
	options: { solid: boolean?, y: number?, r: number?, material: Enum.Material?, transparency: number? }?
): MeshPart?
	local o = options or {}
	local base = CFrame.new(p.X, o.y or groundY(p), -p.Y) * CFrame.Angles(0, yaw, 0)
	if not corridorSafe(name, base, scale) then
		ctx.rejected.corridor = (ctx.rejected.corridor or 0) + 1
		return nil
	end
	local part = KitAssets.place(name, base, scale, o.solid)
	if o.material then
		part.Material = o.material
	end
	if o.transparency then
		part.Transparency = o.transparency
	end
	part.Parent = folder(ctx, category)
	ctx.counts[name] = (ctx.counts[name] or 0) + 1
	ctx.triangles += KitAssets.info(name).triangles
	if o.r then
		table.insert(ctx.taken, { p = p, r = o.r })
	end
	return part
end

-- ---------------------------------------------------------------- fountain
local function emitter(parent: Instance, name: string, props: { [string]: any }): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.Name = name
	for k, v in props do
		(e :: any)[k] = v
	end
	e:SetAttribute("BaseRate", e.Rate)
	e.Parent = parent
	return e
end

local function buildFountain(ctx: Ctx)
	local y = SURFACE
	put(ctx, "Fountain", "FountainTiered", Vector2.zero, 0, 1, { solid = true, y = y, r = park.basinRadius + 2 })
	put(ctx, "Fountain", "FountainWater", Vector2.zero, 0, 1, {
		y = y,
		material = Enum.Material.Glass,
		transparency = 0.3,
	})
	local meta = KitAssets.info("FountainTiered").meta
	-- an invisible host for the jets: a centre plume and eight arcs from the middle tier
	local host = Instance.new("Part")
	host.Name = "JetHost"
	host.Anchored = true
	host.CanCollide = false
	host.CanQuery = false
	host.CanTouch = false
	host.Transparency = 1
	host.Size = Vector3.new(1, 1, 1)
	host.CFrame = CFrame.new(0, y, 0)
	host.Parent = folder(ctx, "Fountain")
	local spray = AssetIds.Textures.Mist
	local drop = AssetIds.Textures.Droplet
	local centre = Instance.new("Attachment")
	centre.Name = "CentreJet"
	centre.Position = Vector3.new(0, meta.jet or 2.7, 0)
	centre.Parent = host
	emitter(centre, "Plume", {
		Texture = spray,
		Rate = 70,
		Lifetime = NumberRange.new(1.0, 1.3),
		Speed = NumberRange.new(15, 17),
		SpreadAngle = Vector2.new(4, 4),
		Acceleration = Vector3.new(0, -26, 0),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 1.4) }),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.25), NumberSequenceKeypoint.new(1, 0.8) }),
		Color = ColorSequence.new(Color3.fromRGB(196, 228, 246)),
		LightEmission = 0.15,
	})
	emitter(centre, "PlumeDroplets", {
		Texture = drop,
		Rate = 30,
		Lifetime = NumberRange.new(1.1, 1.5),
		Speed = NumberRange.new(13, 16),
		SpreadAngle = Vector2.new(10, 10),
		Acceleration = Vector3.new(0, -26, 0),
		Size = NumberSequence.new(0.35),
		Transparency = NumberSequence.new(0.1),
		Color = ColorSequence.new(Color3.fromRGB(170, 214, 240)),
	})
	for k = 0, 7 do
		local a = k / 8 * math.pi * 2
		local at = Instance.new("Attachment")
		at.Name = string.format("ArcJet%d", k + 1)
		at.CFrame = CFrame.new(math.cos(a) * 2.2, (meta.tier2 or 1.65) + 0.2, math.sin(a) * 2.2)
			* CFrame.Angles(0, -a, 0)
			* CFrame.Angles(0, 0, -math.rad(42))
		at.Parent = host
		emitter(at, "Arc", {
			Texture = spray,
			Rate = 22,
			Lifetime = NumberRange.new(0.7, 0.8),
			Speed = NumberRange.new(8.5, 9.5),
			SpreadAngle = Vector2.new(2, 2),
			Acceleration = Vector3.new(0, -32, 0),
			Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.45), NumberSequenceKeypoint.new(1, 0.9) }),
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.15),
				NumberSequenceKeypoint.new(1, 0.7),
			}),
			Color = ColorSequence.new(Color3.fromRGB(196, 228, 246)),
		})
	end
	-- ripples where the plume and arcs land: a disc emitter on its own thin part (the disc
	-- shape follows the part size)
	local rippleHost = host:Clone()
	rippleHost.Name = "RippleHost"
	rippleHost:ClearAllChildren()
	rippleHost.Size = Vector3.new(14, 0.2, 14)
	rippleHost.CFrame = CFrame.new(0, y + (meta.pool or 0.95) + 0.12, 0)
	rippleHost.Parent = host.Parent
	emitter(rippleHost, "Ripples", {
		Texture = AssetIds.Textures.Ripple,
		Rate = 6,
		Lifetime = NumberRange.new(1.6, 2.2),
		Speed = NumberRange.new(0.01, 0.01),
		Shape = Enum.ParticleEmitterShape.Disc,
		ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
		Orientation = Enum.ParticleOrientation.VelocityPerpendicular,
		EmissionDirection = Enum.NormalId.Top,
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 3) }),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 1) }),
	})
end

-- ---------------------------------------------------------------- bridges and buildings
local function buildBridges(ctx: Ctx)
	for i, b in park.bridges do
		local shared = false
		for k, other in park.bridges do
			if k ~= i and (other.at - b.at).Magnitude < (b.span + other.deckWidth) / 2 then
				shared = true
			end
		end
		local name = if shared
			then "BridgeAvenueOpen"
			elseif b.deckWidth >= 16 then "BridgeAvenue"
			elseif b.deckWidth >= 12 then "BridgeLakeside"
			else "BridgeGarden"
		local part = put(ctx, "Bridges", name, b.at, yawAlong(b.dir), 1, { y = SURFACE })
		if part then
			part.Name = string.format("Bridge%02d", i)
			part:SetAttribute("Path", b.path)
		end
	end
end

local function buildingById(id: string): any
	for _, b in park.buildings do
		if b.id == id then
			return b
		end
	end
	return nil
end

local function buildStands(ctx: Ctx)
	local g = buildingById("Gazebo")
	if g then
		put(ctx, "Buildings", "Gazebo", g.centre, yawAlong(g.facing), 1, { y = SURFACE })
	end
	local f = buildingById("FoodStands")
	if not f then
		return
	end
	local side = Vector2.new(-f.facing.Y, f.facing.X)
	local items = { "HotDogCart", "IceCreamStand", "LemonadeStand", "PopcornCart" }
	for k, name in items do
		local offset = (k - 2.5) * 8
		put(ctx, "FoodStands", name, f.centre + side * offset, yawFacing(f.facing), 1, { solid = true })
	end
	-- bunting on three slim poles in front of the stands, or behind them where the front reaches
	-- into a viewing corridor (the poles and strings are taller than 3); none if both do
	local offset: number? = nil
	for _, o in { f.depth / 2 + 1.5, -(f.depth / 2 + 1.5) } do
		local clear = true
		for t = -1, 1, 0.25 do
			if inCorridor(f.centre + side * t * 16 + f.facing * o) then
				clear = false
			end
		end
		if clear then
			offset = o
			break
		end
	end
	if not offset then
		ctx.rejected.corridor = (ctx.rejected.corridor or 0) + 1
		table.insert(ctx.taken, { p = f.centre, r = f.width / 2 + 3 })
		return
	end
	local poles = {}
	for k = -1, 1 do
		local p = f.centre + side * k * 16 + f.facing * (offset :: number)
		local y = groundY(p)
		local pole = Instance.new("Part")
		pole.Name = "BuntingPole"
		pole.Shape = Enum.PartType.Cylinder
		pole.Size = Vector3.new(7.6, 0.4, 0.4)
		pole.CFrame = CFrame.new(p.X, y + 3.8, -p.Y) * CFrame.Angles(0, 0, math.pi / 2)
		pole.Color = Color3.fromRGB(246, 242, 236)
		pole.Material = Enum.Material.SmoothPlastic
		pole.Anchored = true
		pole.CanTouch = false
		pole.Parent = folder(ctx, "FoodStands")
		table.insert(poles, Vector3.new(p.X, y + 7.3, -p.Y))
	end
	for k = 1, 2 do
		local a, c = poles[k], poles[k + 1]
		local d = Vector2.new(c.X - a.X, -(c.Z - a.Z))
		local length = d.Magnitude
		local base = CFrame.new(a) * CFrame.Angles(0, yawAlong(d.Unit), 0)
		local part = KitAssets.place("BuntingString", base, 1)
		part.Size = Vector3.new(part.Size.X * length / 16, part.Size.Y, part.Size.Z)
		local entry = KitAssets.info("BuntingString")
		local centre = (entry.min + entry.max) / 2
		part.CFrame = base * CFrame.new(centre.X * length / 16, centre.Y, centre.Z)
		part:SetAttribute("Sway", 0.4)
		part.Parent = folder(ctx, "FoodStands")
		ctx.counts.BuntingString = (ctx.counts.BuntingString or 0) + 1
	end
	table.insert(ctx.taken, { p = f.centre, r = f.width / 2 + 3 })
end

-- ---------------------------------------------------------------- along the paths
-- Walks every path, calling visit(point, direction, normal, path) every `step` studs from `start`.
local function walkPaths(step: number, start: number, visit: (Vector2, Vector2, Vector2, any, number) -> ())
	for _, path in park.paths do
		local pts = (path :: any).points
		if pts and #pts >= 2 then
			local travelled = 0
			local nextAt = start
			local n = 0
			for i = 1, #pts - 1 do
				local a, b = pts[i], pts[i + 1]
				local seg = (b - a).Magnitude
				if seg > 1e-6 then
					local dir = (b - a) / seg
					while nextAt <= travelled + seg do
						local p = a + dir * (nextAt - travelled)
						n += 1
						visit(p, dir, Vector2.new(-dir.Y, dir.X), path, n)
						nextAt += step
					end
				end
				travelled += seg
			end
		end
	end
end

local function lawnOk(p: Vector2, r: number, pathMin: number): boolean
	local radius = p.Magnitude
	if radius < park.plazaRadius + r + 2 or radius > PARK_OUTER + 18 then
		return false
	end
	local pc = pathClear(p)
	return pc >= pathMin and streamClear(p) >= r + 1.5 and bridgeClear(p) >= r + 4 and buildingClear(p) >= r + 2
end

local function nearSign(ctx: Ctx, p: Vector2): boolean
	local signs = ctx.folders.Signposts
	if not signs then
		return false
	end
	for _, s in signs:GetChildren() do
		local q = (s :: BasePart).Position
		if (Vector2.new(q.X, -q.Z) - p).Magnitude < 45 then
			return true
		end
	end
	return false
end

local function buildFurniture(ctx: Ctx)
	-- benches facing the path, on alternate sides
	walkPaths(26, 13, function(p, _dir, normal, path, n)
		if (ctx.counts.Bench or 0) >= 34 then
			return
		end
		local width = (path :: any).width or 8
		local side = if n % 2 == 0 then 1 else -1
		local at = p + normal * side * (width / 2 + 1.9)
		if lawnOk(at, 3.2, 1.0) and free(ctx, at, 3.5) then
			put(ctx, "Benches", "Bench", at, yawFacing(-normal * side), 1, { solid = true, r = 3.5 })
		end
	end)
	-- lamp posts on the other side, outside the viewing corridors
	walkPaths(34, 6, function(p, _dir, normal, path, n)
		if (ctx.counts.LampPost or 0) >= 30 then
			return
		end
		local width = (path :: any).width or 8
		local side = if n % 2 == 0 then -1 else 1
		local at = p + normal * side * (width / 2 + 1.2)
		if lawnOk(at, 0.8, 0.6) and free(ctx, at, 2) and not inCorridor(at) then
			local lamp = put(ctx, "Lamps", "LampPost", at, 0, 1, { solid = true, r = 2 })
			if lamp then
				put(ctx, "Lamps", "LampGlass", at, 0, 1, {
					material = Enum.Material.Glass,
					transparency = 0.15,
				})
			end
		end
	end)
	-- signpost structures where paths meet the promenade and the garden ring (blank boards)
	walkPaths(24, 10, function(p, _dir, normal, path, _n)
		if (ctx.counts.Signpost or 0) >= 6 then
			return
		end
		local width = (path :: any).width or 8
		for _, side in { 1, -1 } do
			local at = p + normal * side * (width / 2 + 2.5)
			if lawnOk(at, 1.5, 1.2) and free(ctx, at, 4) and not inCorridor(at) and not nearSign(ctx, at) then
				local s = put(ctx, "Signposts", "Signpost", at, ctx.rng:NextNumber(0, 6.28), 1, { r = 4 })
				if s then
					s:SetAttribute("BoardsDesign", "pending Figma mock and spec (vault/design/ui)")
					return
				end
			end
		end
	end)
end

local function buildHedges(ctx: Ctx)
	-- low clipped hedges round the plaza, with openings where the paths arrive
	local r = park.plazaRadius + 2.6
	local n = math.floor(2 * math.pi * r / 6.4)
	for k = 0, n - 1 do
		local a = (k + 0.5) / n * math.pi * 2
		local p = Vector2.new(math.cos(a), math.sin(a)) * r
		local tangent = Vector2.new(-math.sin(a), math.cos(a))
		if pathClear(p) > 1.5 and streamClear(p) > 2 and buildingClear(p) > 1 then
			put(ctx, "Hedges", "HedgeLow", p, yawAlong(tangent), 1, { solid = true })
		end
	end
	table.insert(ctx.taken, { p = Vector2.zero, r = r + 2 })
	-- topiary pairs beside path ends, outside the corridors
	walkPaths(1e6, 4, function(p, dir, normal, path, _n)
		local width = (path :: any).width or 8
		for _, side in { 1, -1 } do
			local at = p + normal * side * (width / 2 + 2.4) - dir * 1
			if lawnOk(at, 1.8, 1.2) and free(ctx, at, 2.2) then
				put(
					ctx,
					"Hedges",
					if side > 0 then "TopiaryBall" else "TopiaryCone",
					at,
					0,
					1,
					{ solid = true, r = 2.2 }
				)
			end
		end
	end)
	-- the car topiary: the first open lawn spot near the plaza or the Garage approach
	local candidates = {}
	for ring = 60, 200, 10 do
		for k = 0, 35 do
			local a = k / 36 * math.pi * 2
			table.insert(candidates, Vector2.new(math.cos(a), math.sin(a)) * ring)
		end
	end
	for _, p in candidates do
		if lawnOk(p, 7, 4) and free(ctx, p, 8) and not inCorridor(p) then
			local _, nearest = pathClear(p)
			local yaw = 0
			if nearest and (nearest :: any).points then
				local pts = (nearest :: any).points
				yaw = yawAlong((pts[#pts] - pts[1]).Unit)
			end
			if put(ctx, "Hedges", "CarTopiary", p, yaw, 1, { solid = true, r = 8 }) then
				break
			end
		end
	end
	-- white fences along the lake side of the lakeside walks
	for _, path in park.paths do
		local pts = (path :: any).points
		if pts and string.find((path :: any).kind, "Lakeside") then
			local width = (path :: any).width or 8
			for i = 1, #pts - 1 do
				local a, b = pts[i], pts[i + 1]
				local seg = (b - a).Magnitude
				local dir = (b - a) / math.max(seg, 1e-6)
				local normal = Vector2.new(-dir.Y, dir.X)
				local side = if normal.Y < 0 then 1 else -1 -- toward the lake (plan south)
				for t = 4, seg - 4, 9 do
					local at = a + dir * t + normal * side * (width / 2 + 0.8)
					if bridgeClear(at) > 4 and buildingClear(at) > 1 then
						put(ctx, "Fences", "FenceSegment", at, yawAlong(dir), 1, { solid = true })
					end
				end
			end
		end
	end
end

-- ---------------------------------------------------------------- flower beds
local BED_FLOWERS = {
	{ "TulipsRed", "Daisies" },
	{ "Lavender", "RosesPink" },
	{ "TulipsYellow", "Lavender" },
	{ "RosesRed", "Daisies" },
	{ "Sunflowers", "TulipsYellow" },
	{ "RosesPink", "TulipsRed" },
	{ "Daisies", "Lavender" },
}

local function buildBeds(ctx: Ctx)
	local beds = 0
	local grid = 11
	local spots = {}
	for x = -PARK_OUTER, PARK_OUTER, grid do
		for y = -60, PARK_OUTER, grid do
			table.insert(spots, Vector2.new(x + ctx.rng:NextNumber(-3, 3), y + ctx.rng:NextNumber(-3, 3)))
		end
	end
	for _, p in spots do
		if beds >= 16 then
			break
		end
		local _, nearest = pathClear(p)
		local oval = ctx.rng:NextNumber() < 0.5
		local name = if oval then "BedOval" else "BedRound"
		local meta = KitAssets.info(name).meta
		local reach = math.max(meta.rx or 4.5, meta.ry or 4.5)
		if lawnOk(p, reach, 2.5) and free(ctx, p, reach + 22) then
			local dir = Vector2.new(1, 0)
			if nearest and (nearest :: any).points then
				local pts = (nearest :: any).points
				dir = (pts[#pts] - pts[1]).Unit
			end
			local y = groundY(p)
			local bed = put(ctx, "Beds", name, p, yawAlong(dir), 1, { y = y, r = reach + 1 })
			if bed then
				beds += 1
				-- two flowers per bed in drifts: the taller kind away from the nearest path
				local pair = BED_FLOWERS[(beds - 1) % #BED_FLOWERS + 1]
				local tall, low = pair[1], pair[2]
				if (KitAssets.info(tall).meta.height or 1) < (KitAssets.info(low).meta.height or 1) then
					tall, low = low, tall
				end
				local normal = Vector2.new(-dir.Y, dir.X)
				local pc = pathClear(p + normal)
				local back = if pc > pathClear(p - normal) then normal else -normal
				local rx, ry = (meta.rx or 4.5) - 1.3, (meta.ry or 4.5) - 1.3
				for u = -rx, rx, 1.9 do
					for v = -ry, ry, 1.9 do
						if (u / rx) ^ 2 + (v / ry) ^ 2 <= 1.05 then
							local q = p + dir * u + normal * v
							local depth = (q - p):Dot(back) / math.max(ry, 0.1)
							local kind = if depth > -0.1 + ctx.rng:NextNumber(-0.25, 0.25) then tall else low
							put(ctx, "Beds", kind, q, ctx.rng:NextNumber(0, 6.28), ctx.rng:NextNumber(0.9, 1.1), {
								y = y + (meta.soil or 0.6),
							})
						end
					end
				end
			end
		end
	end
end

-- ---------------------------------------------------------------- lawns
-- Grass tufts set back from the path edges (never over them), and low flower drifts on the
-- open lawns, one kind per drift.
local function buildLawns(ctx: Ctx)
	walkPaths(6.5, 2, function(p, _dir, normal, path, n)
		local width = (path :: any).width or 8
		local side = if n % 2 == 0 then 1 else -1
		local at = p + normal * side * (width / 2 + ctx.rng:NextNumber(1.2, 2.2))
		if ctx.rng:NextNumber() < 0.6 and lawnOk(at, 0.8, 0.9) and free(ctx, at, 1.2) then
			put(
				ctx,
				"Lawns",
				if ctx.rng:NextNumber() < 0.6 then "GrassTuft" else "GrassTuftWide",
				at,
				ctx.rng:NextNumber(0, 6.28),
				1
			)
		end
	end)
	local kinds = { "Daisies", "BlueWildflowers", "Poppies", "Daisies", "TulipsYellow" }
	local drifts, tries = 0, 0
	while drifts < 12 and tries < 800 do
		tries += 1
		local a = ctx.rng:NextNumber(0, 6.28)
		local r = ctx.rng:NextNumber(park.plazaRadius + 12, PARK_OUTER - 6)
		local p = Vector2.new(math.cos(a), math.sin(a)) * r
		if lawnOk(p, 5, 4) and free(ctx, p, 7) then
			drifts += 1
			local kind = kinds[(drifts - 1) % #kinds + 1]
			for _ = 1, ctx.rng:NextInteger(6, 9) do
				local b = ctx.rng:NextNumber(0, 6.28)
				local q = p + Vector2.new(math.cos(b), math.sin(b)) * 4.5 * math.sqrt(ctx.rng:NextNumber())
				if lawnOk(q, 0.8, 1) then
					put(ctx, "Lawns", kind, q, ctx.rng:NextNumber(0, 6.28), ctx.rng:NextNumber(0.9, 1.1))
				end
			end
			put(ctx, "Lawns", "Clover", p + Vector2.new(5, 2), 0, 1)
			table.insert(ctx.taken, { p = p, r = 5 })
		end
	end
	ctx.counts.lawnDrifts = drifts
end

-- ---------------------------------------------------------------- park trees
local function buildTrees(ctx: Ctx)
	local nz = 0.37
	local folderTrees = folder(ctx, "Trees")
	local spots = {}
	for x = -PARK_OUTER, PARK_OUTER, 8 do
		for y = -70, PARK_OUTER, 8 do
			table.insert(spots, Vector2.new(x + ctx.rng:NextNumber(-3, 3), y + ctx.rng:NextNumber(-3, 3)))
		end
	end
	-- shuffle deterministically so the grid order does not show
	for i = #spots, 2, -1 do
		local j = ctx.rng:NextInteger(1, i)
		spots[i], spots[j] = spots[j], spots[i]
	end
	local trees = 0
	for _, p in spots do
		if trees >= 64 then
			break
		end
		-- groups and open lawns: a slow noise mask decides where trees gather
		local mask = math.noise(p.X / 55, p.Y / 55, nz)
		if mask > -0.05 and lawnOk(p, 3, 4) and free(ctx, p, 12) then
			local nearStream = streamClear(p) < 16
			local weights = if nearStream
				then { Birch = 3, Willow = 2, Oak = 1 }
				else { Oak = 3, Blossom = 3, Fruit = 2.2, Birch = 1.6 }
			local total = 0
			local keys = {}
			for k, w in weights do
				table.insert(keys, k)
				total += w
			end
			table.sort(keys)
			local roll = ctx.rng:NextNumber() * total
			local family = keys[#keys]
			for _, k in keys do
				roll -= weights[k]
				if roll <= 0 then
					family = k
					break
				end
			end
			local list = Flora.Variants[family]
			local variant = list[ctx.rng:NextInteger(1, #list)]
			local scale = ctx.rng:NextNumber(0.85, 1.1)
			local yaw = ctx.rng:NextNumber(0, 6.28)
			local base = CFrame.new(p.X, SURFACE, -p.Y) * CFrame.Angles(0, yaw, 0)
			if corridorSafe(variant .. "_Canopy", base, scale) and corridorSafe(variant .. "_Trunk", base, scale) then
				if Flora.plant(ctx.planter, folderTrees, variant, p, scale, yaw) then
					trees += 1
					table.insert(ctx.taken, { p = p, r = 6 })
					ctx.counts[variant] = (ctx.counts[variant] or 0) + 1
					-- an understory bush on the side away from the nearest path
					if ctx.rng:NextNumber() < 0.45 then
						local a = ctx.rng:NextNumber(0, 6.28)
						local q = p + Vector2.new(math.cos(a), math.sin(a)) * ctx.rng:NextNumber(3.5, 6)
						if lawnOk(q, 1.5, 2) then
							local bush = Flora.Bushes[ctx.rng:NextInteger(1, #Flora.Bushes)]
							local bbase = CFrame.new(q.X, SURFACE, -q.Y)
							if corridorSafe(bush, bbase, 1.6) then
								Flora.plant(ctx.planter, folderTrees, bush, q, 1.6, a)
							end
						end
					end
				end
			else
				ctx.rejected.corridor = (ctx.rejected.corridor or 0) + 1
			end
		end
	end
	ctx.counts.parkTrees = trees
end

export type Report = {
	counts: { [string]: number },
	rejected: { [string]: number },
	uniqueMeshes: number,
	sceneTriangles: number,
	treeTriangles: number,
	parts: number,
	seconds: number,
}

function ParkDressing.build(parent: Instance, grid: TerrainWriter.Grid, seed: number): Report
	local started = os.clock()
	local old = parent:FindFirstChild("ParkDressing")
	if old then
		Flora.revertPatches(old, grid)
		old:Destroy()
	end
	local root = Instance.new("Folder")
	root.Name = "ParkDressing"
	root:SetAttribute("PreviewOf", "Lane 3 park dressing (Task 2 revision)")
	local ctx: Ctx = {
		root = root,
		folders = {},
		taken = {},
		counts = {},
		rejected = {},
		triangles = 0,
		planter = Flora.newPlanter(grid),
		rng = Random.new(seed + 303),
	}
	buildFountain(ctx)
	buildBridges(ctx)
	buildStands(ctx)
	task.wait()
	buildHedges(ctx)
	buildFurniture(ctx)
	task.wait()
	buildBeds(ctx)
	task.wait()
	buildTrees(ctx)
	buildLawns(ctx)
	Flora.recordPatches(root, ctx.planter)
	root:SetAttribute("MeshSources", HttpService:JSONEncode(KitAssets.sources()))
	root.Parent = parent
	local unique, parts = {}, 0
	for _, d in root:GetDescendants() do
		if d:IsA("MeshPart") then
			unique[d.Name] = true
		end
		if d:IsA("BasePart") then
			parts += 1
		end
	end
	local n = 0
	for _ in unique do
		n += 1
	end
	return {
		counts = ctx.counts,
		rejected = ctx.rejected,
		uniqueMeshes = n,
		sceneTriangles = ctx.triangles + ctx.planter.counts.triangles,
		treeTriangles = ctx.planter.counts.triangles,
		parts = parts,
		seconds = math.round((os.clock() - started) * 100) / 100,
	}
end

return ParkDressing
