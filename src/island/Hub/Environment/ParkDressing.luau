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
--   Fountain      the grand fountain, inside the measured sightline envelope (revision 2)
--   Bridges       one kit bridge per crossing (rail-less where two bridges share a junction)
--   Buildings     gazebo; food stands (decorative only: no prices or shop prompts)
--   Furniture     paired benches facing each other across the avenues, lamp posts in matched
--                 pairs along the paths, signpost structures with their boards
--   Hedges        low hedges round the plaza, topiary, the car topiary, lakeside fences
--   Beds          raised flower beds, each parallel to its path at one clearance or centred in
--                 its sector, planted inside the bed's true outline (BedShapes)
--   Trees         oak, blossom, birch and fruit trees framing paths, willows and birches by the
--                 stream, bushes beneath; forest floor under each tree

local HttpService = game:GetService("HttpService")

local AssetIds = require(script.Parent.AssetIds)
local BedShapes = require(script.Parent.BedShapes)
local Field = require(script.Parent.Field)
local Flora = require(script.Parent.Flora)
local KitAssets = require(script.Parent.KitAssets)
local Layout = require(script.Parent.Parent.Layout)
local Sightlines = require(script.Parent.Sightlines)
local Signs = require(script.Parent.Signs)
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

-- A viewing corridor, widened at the entrance by the player and camera allowance the portal
-- sightline test uses (4 studs either side, 5 behind): a player standing anywhere at the
-- entrance sees the whole portal row (Hub/Preview/PortalSight, 2026-10-21).
local ENTRANCE_SIDE, ENTRANCE_BACK = 4, 5
local function inCorridor(p: Vector2): boolean
	for _, tri in park.corridors do
		local e, a, b = tri[1], tri[2], tri[3]
		local fwd = ((a + b) / 2 - e).Unit
		local side = Vector2.new(-fwd.Y, fwd.X)
		local back = e - fwd * ENTRANCE_BACK
		local l, r = back + side * ENTRANCE_SIDE, back - side * ENTRANCE_SIDE
		-- the convex hull of the four corners, whichever way round they come
		if inTriangle(p, l, r, a) or inTriangle(p, l, r, b) or inTriangle(p, l, a, b) or inTriangle(p, r, a, b) then
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
		-- the Garage and Stunt entrance keep their forecourt (14 in front) clear of park furniture
		local fore = if b.id == "Garage" or b.id == "StuntGate" then 14 else 0
		best = math.min(best, boxClear(p, b.centre + b.facing * fore / 2, b.facing, b.width, b.depth + fore))
	end
	for _, b in park.boards do
		best = math.min(best, boxClear(p, b.centre, b.facing or Vector2.new(0, 1), b.width, b.depth))
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

-- ---------------------------------------------------------------- land, shore and mirror (Task 4)
-- Dry land with a margin: not in the lake (its irregular shoreline, Field.lakeShape) within
-- `margin` studs, and clear of the river channel and its bank. Task 4 found the car topiary (the
-- "turtle on a brown pad") and lawn flower drifts standing in the lake: the old rule tested only
-- paths, the stream, bridges and buildings, never the shore, and only a centre point.
local SHORE_MARGIN = 3 -- studs from the waterline to any part of a footprint
local RIVER_BANK = 4 -- studs from the river's edge to any part of a footprint

local function onLand(p: Vector2, margin: number): boolean
	if Field.lakeShape(p) then
		return false
	end
	for k = 0, 7 do
		local a = k / 8 * math.pi * 2
		if Field.lakeShape(p + Vector2.new(math.cos(a), math.sin(a)) * margin) then
			return false
		end
	end
	return polylineDistance(park.stream, p) - park.streamWidth / 2 >= RIVER_BANK
end

-- Every corner of a placed footprint (and its centre) on dry land.
local function landSafe(corners: { Vector2 }): boolean
	local centre = Vector2.zero
	for _, c in corners do
		if not onLand(c, SHORE_MARGIN) then
			return false
		end
		centre += c
	end
	return onLand(centre / #corners, SHORE_MARGIN)
end

-- The one centre axis (HubData park.axisX): mirrored pairs are (x, y) and (2 axis - x, y).
local AXIS = park.axisX or 0
local function mirrorP(p: Vector2): Vector2
	return Vector2.new(2 * AXIS - p.X, p.Y)
end
local function mirrorD(d: Vector2): Vector2
	return Vector2.new(-d.X, d.Y)
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

-- With envelope, the piece was measured against the portal discs themselves (the fountain) and
-- its sightlines are checked by ray tests (Hub/Preview/PortalSight), not by its bounding box,
-- whose square corners reach past the round fountain.
local function corridorSafe(name: string, base: CFrame, scale: number, envelope: boolean?): boolean
	if envelope then
		return true
	end
	local corners, top = KitAssets.footprint(name, base, scale)
	if Sightlines.boxBlocksFalls(corners, top) then
		return false
	end
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
	options: {
		solid: boolean?,
		y: number?,
		r: number?,
		material: Enum.Material?,
		transparency: number?,
		envelope: boolean?,
		wet: boolean?, -- allowed over water (bridges, lake dressing)
	}?
): MeshPart?
	local o = options or {}
	local base = CFrame.new(p.X, o.y or groundY(p), -p.Y) * CFrame.Angles(0, yaw, 0)
	if not corridorSafe(name, base, scale, o.envelope) then
		ctx.rejected.corridor = (ctx.rejected.corridor or 0) + 1
		return nil
	end
	if not o.wet and not landSafe((KitAssets.footprint(name, base, scale))) then
		ctx.rejected.shore = (ctx.rejected.shore or 0) + 1
		return nil
	end
	local part = KitAssets.place(name, base, scale, o.solid)
	-- the placement point (mesh origin) in plan, for the mirror check (a mesh whose bounds are
	-- off-centre has a mirrored origin but not a mirrored bounding-box centre)
	part:SetAttribute("PlanAt", Vector2.new(p.X, p.Y))
	if o.envelope then
		part:SetAttribute("SightlineEnvelope", true)
	end
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

type PutOptions = {
	envelope: boolean?, -- thin enough to judge by the portal ray test, not the blanket corridor rule
	solid: boolean?,
	y: number?,
	r: number?,
	material: Enum.Material?,
	transparency: number?,
	wet: boolean?,
}

-- Would put() accept this piece here? (corridor, falls, shore and free-space tests, no placing)
local function canPut(ctx: Ctx, name: string, p: Vector2, yaw: number, scale: number, o: PutOptions): boolean
	local base = CFrame.new(p.X, o.y or groundY(p), -p.Y) * CFrame.Angles(0, yaw, 0)
	local why: string? = nil
	if not corridorSafe(name, base, scale, o.envelope) then
		why = "corridor"
	elseif not o.wet and not landSafe((KitAssets.footprint(name, base, scale))) then
		why = "shore"
	elseif o.r ~= nil and not free(ctx, p, o.r :: number) then
		why = "space"
	end
	if why then
		local key = name .. ":" .. why -- counted per piece and reason, for the build report
		ctx.rejected[key] = (ctx.rejected[key] or 0) + 1
		return false
	end
	return true
end

-- A mirrored pair (Task 4, brief §6: mirror the non-tree dressing): the piece at p facing plan
-- direction `front`, and its mirror image about the centre axis. Both are tested first; either
-- both are placed or neither (so one side never ends up with a piece the other lacks). A piece
-- within 0.5 of the axis is placed once.
local function putPair(
	ctx: Ctx,
	category: string,
	name: string,
	p: Vector2,
	front: Vector2,
	scale: number,
	o: PutOptions
): (MeshPart?, MeshPart?)
	local yaw, myaw = yawFacing(front), yawFacing(mirrorD(front))
	local q = mirrorP(p)
	if math.abs(p.X - AXIS) < 0.5 then
		if not canPut(ctx, name, p, yaw, scale, o) then
			return nil, nil
		end
		return put(ctx, category, name, p, yaw, scale, o :: any), nil
	end
	if not canPut(ctx, name, p, yaw, scale, o) or not canPut(ctx, name, q, myaw, scale, o) then
		ctx.rejected.pair = (ctx.rejected.pair or 0) + 1
		return nil, nil
	end
	local a = put(ctx, category, name, p, yaw, scale, o :: any)
	local b = put(ctx, category, name, q, myaw, scale, o :: any)
	if a and b then
		a:SetAttribute("MirrorPair", true)
		b:SetAttribute("MirrorPair", true)
	end
	return a, b
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

local function invisibleCylinder(parent: Instance, name: string, radius: number, height: number, y: number): Part
	local c = Instance.new("Part")
	c.Name = name
	c.Shape = Enum.PartType.Cylinder
	c.Size = Vector3.new(height, radius * 2, radius * 2)
	c.CFrame = CFrame.new(0, y + height / 2, 0) * CFrame.Angles(0, 0, math.pi / 2)
	c.Anchored = true
	c.Transparency = 1
	c.CastShadow = false
	c.CanTouch = false
	c.Parent = parent
	return c
end

local function flatAttach(host: BasePart, pos: Vector3, along: Vector3): Attachment
	local a = Instance.new("Attachment")
	local x = along.Unit
	a.CFrame = host.CFrame:ToObjectSpace(CFrame.fromMatrix(pos, x, Vector3.new(0, 1, 0):Cross(x).Unit))
	a.Parent = host
	return a
end

local function plainPart(name: string, size: Vector3, cframe: CFrame, colour: Color3, parent: Instance): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Color = colour
	part.Material = Enum.Material.SmoothPlastic
	part.Anchored = true
	part.CanTouch = false
	part.Parent = parent
	return part
end

-- The car statue fountain (Adam, big round M3): a polished car on a tall pedestal rising from the
-- basin, nose up as if launching off a ramp, with water arcing round the pedestal into the pool. The
-- pedestal carries the car, so it never seems to hover. Built from parts and the group-owned
-- SwStatueCar mesh (Raceway kit), so it needs no new upload. It replaces the FountainGrand mesh,
-- which showed as a sunken car in Play (Adam's screenshot 11). Client: Home/Island/EnvironmentMotion
-- waves the arcs; reduced motion holds them calm.
local FOUNTAIN = {
	Stone = Color3.fromRGB(240, 232, 214),
	Navy = Color3.fromRGB(30, 50, 104),
	Gold = Color3.fromRGB(240, 190, 72),
	Water = Color3.fromRGB(72, 186, 226),
	Rim = 12.4,
	Pool = 1.86, -- the water's top above the plaza
	PedestalTop = 8.1,
}

local function buildFountain(ctx: Ctx)
	local y = Layout.PlazaTop
	local f = folder(ctx, "Fountain")
	local function disc(name: string, radius: number, top: number, thick: number, colour: Color3): Part
		local d = plainPart(
			name,
			Vector3.new(thick, radius * 2, radius * 2),
			CFrame.new(0, y + top - thick / 2, 0) * CFrame.Angles(0, 0, math.pi / 2),
			colour,
			f
		)
		d.Shape = Enum.PartType.Cylinder
		d.CanCollide = false
		d.CanQuery = false
		return d
	end
	local function block(name: string, size: Vector3, at: Vector3, colour: Color3): Part
		local b = plainPart(name, size, CFrame.new(0, y, 0) * CFrame.new(at), colour, f)
		b.CanCollide = false
		b.CanQuery = false
		return b
	end
	disc("FountainStep", 15, 0.28, 0.4, FOUNTAIN.Stone)
	disc("FountainStepHigh", 13.6, 0.56, 0.5, Color3.fromRGB(226, 216, 196))
	disc("FountainWall", FOUNTAIN.Rim, 1.7, 1.3, FOUNTAIN.Navy)
	disc("FountainRim", FOUNTAIN.Rim + 0.5, 1.78, 0.2, FOUNTAIN.Gold).CastShadow = false
	local pool = disc("FountainWater", FOUNTAIN.Rim - 0.7, FOUNTAIN.Pool, 0.1, FOUNTAIN.Water)
	pool.Material = Enum.Material.Glass
	pool.Transparency = 0.15
	pool.CastShadow = false
	disc("PedestalFoot", 4.6, 2.5, 0.9, FOUNTAIN.Stone)
	block("PedestalBase", Vector3.new(6, 1.2, 6), Vector3.new(0, 3.1, 0), FOUNTAIN.Stone)
	block("PedestalShaft", Vector3.new(4.4, 3.6, 4.4), Vector3.new(0, 5.5, 0), FOUNTAIN.Stone)
	for k = 0, 3 do
		local a = k * math.pi / 2
		local panel = plainPart(
			"PedestalPanel",
			Vector3.new(2.8, 2.4, 0.12),
			CFrame.new(0, y + 5.5, 0) * CFrame.Angles(0, a, 0) * CFrame.new(0, 0, 2.24),
			FOUNTAIN.Navy,
			f
		)
		panel.CanCollide = false
		panel.CanQuery = false
	end
	block("PedestalCollar", Vector3.new(5.2, 0.4, 5.2), Vector3.new(0, 7.5, 0), FOUNTAIN.Gold)
	block("PedestalCap", Vector3.new(4, 0.4, 4), Vector3.new(0, FOUNTAIN.PedestalTop - 0.2, 0), FOUNTAIN.Stone)
	-- a short steel stay under the raised nose: the statue is held, not hovering
	local tilt = math.rad(13)
	local toward = Vector3.new(0, 0, 1) -- the nose points down the portal row's axis (south)
	local seat = CFrame.lookAt(Vector3.new(0, y + FOUNTAIN.PedestalTop + 0.5, 0), toward) * CFrame.Angles(tilt, 0, 0)
	block("StatueStay", Vector3.new(1.2, 1.4, 1.2), Vector3.new(0, FOUNTAIN.PedestalTop + 0.5, 0), FOUNTAIN.Navy)
	local Speedway = game:GetService("ReplicatedStorage"):FindFirstChild("Shared")
	local kit: any = Speedway and (require :: any)((Speedway :: any).Island.Speedway.Kit)
	local car = kit and kit.place("SwStatueCar", seat, 1.05)
	if car then
		car.TextureID = ""
		car.Color = FOUNTAIN.Gold
		car.Material = Enum.Material.Metal
		car.Reflectance = 0.08
		car.Name = "StatueCar"
		car:SetAttribute("SightlineEnvelope", true)
		car.Parent = f
		ctx.counts.StatueCar = 1
	else
		ctx.rejected.statueCar = 1
	end
	put(ctx, "Fountain", "PlazaMosaic", Vector2.zero, 0, 1, { y = y - 0.045, envelope = true })
	local meta = { pool = FOUNTAIN.Pool, mid_pool = 2.9 }
	-- simple colliders: the basin wall and the two walkable steps
	invisibleCylinder(f, "BasinCollider", FOUNTAIN.Rim + 0.5, 2.15, y)
	invisibleCylinder(f, "StepCollider", 13.6, 0.55, y)
	invisibleCylinder(f, "LowStepCollider", 15, 0.28, y)

	local host = Instance.new("Part")
	host.Name = "JetHost"
	host.Anchored = true
	host.CanCollide = false
	host.CanQuery = false
	host.CanTouch = false
	host.Transparency = 1
	host.Size = Vector3.one
	host.CFrame = CFrame.new(0, y, 0)
	host.Parent = f
	local spray, drop = AssetIds.Textures.Mist, AssetIds.Textures.Droplet
	local water = Color3.fromRGB(190, 228, 240)

	-- eight arching jets from the pedestal base into the basin; each lands about r 9.4 in the pool
	for k = 0, 7 do
		local a = (k + 0.5) / 8 * math.pi * 2
		local d = Vector3.new(math.cos(a), 0, math.sin(a))
		local at = Instance.new("Attachment")
		at.Name = string.format("ArcJet%d", k + 1)
		-- emitters shoot along the attachment's Y axis: tilt it 50 degrees out from vertical
		local origin = d * 4.7 + Vector3.new(0, meta.mid_pool + 0.15, 0)
		local out = (d * math.sin(math.rad(50)) + Vector3.yAxis * math.cos(math.rad(50))).Unit
		at.CFrame = CFrame.fromMatrix(origin, d:Cross(out).Unit, out)
		at.Parent = host
		local arc = emitter(at, "Arc", {
			Texture = spray,
			Rate = 20,
			Lifetime = NumberRange.new(0.58, 0.62),
			Speed = NumberRange.new(10, 10.4),
			SpreadAngle = Vector2.new(1.5, 1.5),
			Acceleration = Vector3.new(0, -32, 0),
			Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.28), NumberSequenceKeypoint.new(1, 0.6) }),
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.25),
				NumberSequenceKeypoint.new(1, 0.7),
			}),
			Color = ColorSequence.new(water),
		})
		arc:SetAttribute("BaseSpeed", 10.2)
		arc:SetAttribute("Index", k)
		local landing = Instance.new("Attachment")
		landing.Name = string.format("ArcLanding%d", k + 1)
		landing.Position = d * 9.4 + Vector3.new(0, meta.pool + 0.08, 0)
		landing.Parent = host
		emitter(landing, "Splash", {
			Texture = drop,
			Rate = 7,
			Lifetime = NumberRange.new(0.3, 0.5),
			Speed = NumberRange.new(2, 3.2),
			SpreadAngle = Vector2.new(50, 50),
			Acceleration = Vector3.new(0, -30, 0),
			Size = NumberSequence.new(0.16),
			Transparency = NumberSequence.new(0.25),
			Color = ColorSequence.new(water),
		})
	end

	-- a slow shimmer on the basin: flat beams round the pool
	local n = 14
	for k = 0, n - 1 do
		local a0 = k / n * math.pi * 2
		local a1 = (k + 1) / n * math.pi * 2
		local p0 = Vector3.new(math.cos(a0) * 8, y + meta.pool + 0.04, math.sin(a0) * 8)
		local p1 = Vector3.new(math.cos(a1) * 8, y + meta.pool + 0.04, math.sin(a1) * 8)
		local b = Instance.new("Beam")
		b.Name = string.format("Shimmer%02d", k + 1)
		b.Attachment0 = flatAttach(host, p0, p1 - p0)
		b.Attachment1 = flatAttach(host, p1, p1 - p0)
		b.Texture = AssetIds.Textures.WaterHighlights
		b.TextureMode = Enum.TextureMode.Wrap
		b.TextureLength = 6
		b.TextureSpeed = 0.12
		b.Width0, b.Width1 = 5.5, 5.5
		b.FaceCamera = false
		b.Color = ColorSequence.new(Color3.fromRGB(236, 250, 252))
		b.Transparency = NumberSequence.new(0.72)
		b.LightEmission = 0.3
		b.Segments = 1
		b:SetAttribute("BaseSpeed", 0.12)
		b.Parent = f
	end

	-- ripples where the arcs and spills land
	local rippleHost = host:Clone()
	rippleHost.Name = "RippleHost"
	rippleHost:ClearAllChildren()
	rippleHost.Size = Vector3.new(20, 0.2, 20)
	rippleHost.CFrame = CFrame.new(0, y + meta.pool + 0.12, 0)
	rippleHost.Parent = f
	emitter(rippleHost, "Ripples", {
		Texture = AssetIds.Textures.Ripple,
		Rate = 7,
		Lifetime = NumberRange.new(1.6, 2.2),
		Speed = NumberRange.new(0.01, 0.01),
		Shape = Enum.ParticleEmitterShape.Disc,
		ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
		Orientation = Enum.ParticleOrientation.VelocityPerpendicular,
		EmissionDirection = Enum.NormalId.Top,
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 2.6) }),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(1, 1) }),
	})

	-- a soft underwater light: reads in shade and at night, faint in daylight
	local lightAt = Instance.new("Attachment")
	lightAt.Name = "UnderwaterLight"
	lightAt.Position = Vector3.new(0, meta.pool - 0.6, 0)
	lightAt.Parent = host
	local glow = Instance.new("PointLight")
	glow.Name = "UnderwaterLight"
	glow.Color = Color3.fromRGB(130, 226, 236)
	glow.Brightness = 1.1
	glow.Range = 14
	glow.Shadows = false
	glow.Parent = lightAt
end

-- ---------------------------------------------------------------- bridges and buildings
local function buildingById(id: string): any
	for _, b in park.buildings do
		if b.id == id then
			return b
		end
	end
	return nil
end

-- A stand's picture header (3.0 x 1.6, approved 2026-10-22; kit HeaderBoard, printable face 2.8
-- x 1.4 in a bark frame). Task 4 (brief §6): every stand's header must read above or in front of
-- its awning, so carts hang it from two straps clear in front of the awning edge and booths carry
-- it above the roof fascia instead of in front of the scallops (Task 3 review F8).
local HEADERS = {
	HotDogCart = { art = "HotDog", bottom = 4.45, front = 2.35, straps = true },
	IceCreamStand = { art = "IceCream", bottom = 5.55, front = 2.6 },
	LemonadeStand = { art = "Lemonade", bottom = 5.55, front = 2.6 },
	PopcornCart = { art = "Popcorn", bottom = 4.45, front = 2.35, straps = true },
}

local function standHeader(ctx: Ctx, name: string, at: Vector2, facing: Vector2)
	local h = HEADERS[name]
	if not h or not KitAssets.has("HeaderBoard") then
		return
	end
	local front = at + facing * h.front
	local base = CFrame.new(front.X, groundY(at) + h.bottom + 0.8, -front.Y) * CFrame.Angles(0, yawFacing(facing), 0)
	local board = KitAssets.place("HeaderBoard", base, 1)
	board.Name = "Header" .. h.art
	board:SetAttribute("Hanging", true) -- hangs from the stand; not ground-standing
	board.Parent = folder(ctx, "SnackCorners")
	ctx.counts.HeaderBoard = (ctx.counts.HeaderBoard or 0) + 1
	local face = Instance.new("Part")
	face.Name = "HeaderFace"
	face.Anchored = true
	face.CanCollide = false
	face.CanQuery = false
	face.CanTouch = false
	face.CastShadow = false
	face.Transparency = 1
	face.Size = Vector3.new(2.8, 1.4, 0.05)
	-- mesh front is +Z after the turn; the face plane is 0.09 in front of the origin
	face.CFrame = base * CFrame.new(0, 0, 0.11) * CFrame.Angles(0, math.pi, 0)
	face.Parent = board
	Signs.header(face, h.art)
	local strapLength = if h.straps then 0.62 else 0.95 -- booths: posts down to the roof ridge
	for _, x in { -1.0, 1.0 } do
		local strap = plainPart(
			if h.straps then "Strap" else "HeaderPost",
			Vector3.new(0.1, strapLength, 0.06),
			base * CFrame.new(x, -(0.8 + strapLength / 2) + 0.05, 0),
			Color3.fromRGB(59, 42, 30),
			board
		)
		strap.CanCollide = false
		strap.CanQuery = false
		if h.straps then
			strap.CFrame = base * CFrame.new(x, 1.06 + 0.31 - 0.25, 0)
		end
	end
end

-- The gazebo on the centre axis (Task 4 layout: plan (0, 196)).
local function buildGazebo(ctx: Ctx)
	local g = buildingById("Gazebo")
	if g then
		put(ctx, "Buildings", "Gazebo", g.centre, yawAlong(g.facing), 1, { y = SURFACE })
	end
end

-- Two balanced snack corners (Task 4, brief §6), mirrored about the axis: two stands each at the
-- back, picnic tables with parasols in front, light posts at the four corners carrying bunting
-- along the front and string lights along the sides, and bins at the front corners. Positions
-- are laid out in the east corner's frame and mirrored for the west one; the stands differ
-- (hot dogs and ice cream east, popcorn and lemonade west), the layout does not.
local SNACK_STANDS = { "HotDogCart", "IceCreamStand" }
local SNACK_STANDS_WEST = { "PopcornCart", "LemonadeStand" }

local function stringBetween(ctx: Ctx, a: Vector3, c: Vector3, kind: string)
	local d = Vector2.new(c.X - a.X, -(c.Z - a.Z))
	local length = d.Magnitude
	local base = CFrame.new(a) * CFrame.Angles(0, yawAlong(d.Unit), 0)
	local part = KitAssets.place("BuntingString", base, 1)
	part.Size = Vector3.new(part.Size.X * length / 16, part.Size.Y, part.Size.Z)
	local entry = KitAssets.info("BuntingString")
	local centre = (entry.min + entry.max) / 2
	part.CFrame = base * CFrame.new(centre.X * length / 16, centre.Y, centre.Z)
	part:SetAttribute("Sway", 0.4)
	part:SetAttribute("StringKind", kind)
	part.Parent = folder(ctx, "SnackCorners")
	ctx.counts.BuntingString = (ctx.counts.BuntingString or 0) + 1
end

local function buildSnackCorners(ctx: Ctx)
	local east = buildingById("SnackCornerEast")
	if not east then
		return
	end
	local front = east.facing
	local side = Vector2.new(-front.Y, front.X)
	local c = east.centre
	local at = function(s: number, f: number): Vector2
		return c + side * s + front * f
	end
	-- stands at the back, facing the picnic area and the path beyond it
	for k, s in { -6.5, 6.5 } do
		local p = at(s, -6)
		local q = mirrorP(p)
		local nameE, nameW = SNACK_STANDS[k], SNACK_STANDS_WEST[k]
		local o: PutOptions = { solid = true, r = 4 }
		if canPut(ctx, nameE, p, yawFacing(front), 1, o) and canPut(ctx, nameW, q, yawFacing(mirrorD(front)), 1, o) then
			put(ctx, "SnackCorners", nameE, p, yawFacing(front), 1, o :: any)
			put(ctx, "SnackCorners", nameW, q, yawFacing(mirrorD(front)), 1, o :: any)
			standHeader(ctx, nameE, p, front)
			standHeader(ctx, nameW, q, mirrorD(front))
		else
			ctx.rejected.snackStand = (ctx.rejected.snackStand or 0) + 1
		end
	end
	-- picnic tables with parasols through their centres, out at the sides so no canopy stands
	-- between the front spur and a header (Task 4 concept review M18, complaint review J6)
	for _, s in { -10.5, 10.5 } do
		local p = at(s, 9)
		if KitAssets.has("PicnicTable") then
			local a = putPair(ctx, "SnackCorners", "PicnicTable", p, side, 1, { solid = true, r = 3.5 })
			if a and KitAssets.has("Parasol") then
				putPair(ctx, "SnackCorners", "Parasol", p, side, 1, {})
			end
		else
			ctx.rejected.missingMesh = (ctx.rejected.missingMesh or 0) + 1
		end
	end
	-- light posts at the corners; bunting across the front, string lights down the sides
	local corners = { at(-14, 12), at(14, 12), at(-14, -12), at(14, -12) }
	local hooks: { Vector3 } = {}
	local ok = true
	for _, p in corners do
		for _, q in { p, mirrorP(p) } do
			if inCorridor(q) or not onLand(q, SHORE_MARGIN) then
				ok = false
			end
		end
	end
	if ok then
		for _, side_ in { 1, -1 } do
			for i, p0 in corners do
				local p = if side_ == 1 then p0 else mirrorP(p0)
				local y = groundY(p)
				if KitAssets.has("LightPost") then
					local post = put(ctx, "SnackCorners", "LightPost", p, 0, 1, { solid = true, r = 1 })
					local hook = KitAssets.info("LightPost").points.Hook
					local hookY = if hook then hook.Y else 11.05
					hooks[(side_ == 1 and 0 or 4) + i] = Vector3.new(p.X, y + hookY, -p.Y)
					if not post then
						ok = false
					end
				else
					local pole = plainPart(
						"LightPost",
						Vector3.new(8.6, 0.45, 0.45),
						CFrame.new(p.X, y + 4.3, -p.Y) * CFrame.Angles(0, 0, math.pi / 2),
						Color3.fromRGB(246, 242, 236),
						folder(ctx, "SnackCorners")
					)
					pole.Shape = Enum.PartType.Cylinder
					-- a footing so it is visibly anchored, not stuck in the grass
					plainPart(
						"Footing",
						Vector3.new(1.2, 0.3, 1.2),
						CFrame.new(p.X, y + 0.1, -p.Y),
						Color3.fromRGB(226, 220, 206),
						folder(ctx, "SnackCorners")
					)
					hooks[(side_ == 1 and 0 or 4) + i] = Vector3.new(p.X, y + 8.4, -p.Y)
				end
			end
		end
		for base = 0, 4, 4 do
			if hooks[base + 1] and hooks[base + 2] then
				stringBetween(ctx, hooks[base + 1], hooks[base + 2], "Bunting")
				stringBetween(ctx, hooks[base + 1], hooks[base + 3], "Lights")
				stringBetween(ctx, hooks[base + 2], hooks[base + 4], "Lights")
			end
		end
	else
		ctx.rejected.snackPosts = (ctx.rejected.snackPosts or 0) + 1
	end
	-- bins either side of the spur mouth, clear of the post feet (review N5)
	if KitAssets.has("ParkBin") then
		for _, s in { -6, 6 } do
			putPair(ctx, "SnackCorners", "ParkBin", at(s, 12.8), front, 1, { solid = true, r = 1.2 })
		end
	end
	for _, b in { east, buildingById("SnackCornerWest") } do
		if b then
			table.insert(ctx.taken, { p = b.centre, r = math.max(b.width, b.depth) / 2 + 2 })
		end
	end
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

-- The east half of the paths only (x past the axis): every placement made from these points is
-- mirrored, so the west half comes out as an exact mirror image (the paths are mirrored too).
local function walkEast(step: number, start: number, visit: (Vector2, Vector2, Vector2, any, number) -> ())
	walkPaths(step, start, function(p, dir, normal, path, n)
		if p.X > AXIS + 0.5 then
			visit(p, dir, normal, path, n)
		end
	end)
end

local function lawnOk(p: Vector2, r: number, pathMin: number): boolean
	local radius = p.Magnitude
	if radius < park.plazaRadius + r + 2 or radius > PARK_OUTER + 18 then
		return false
	end
	local pc = pathClear(p)
	return pc >= pathMin
		and streamClear(p) >= r + RIVER_BANK
		and bridgeClear(p) >= r + 4
		and buildingClear(p) >= r + 2
		and onLand(p, r + SHORE_MARGIN)
		and not Layout.onPaved(p, math.min(r, pathMin) + 0.5) -- nothing on any paving, forecourt included
end

local function lawnOkPair(p: Vector2, r: number, pathMin: number): boolean
	return lawnOk(p, r, pathMin) and lawnOk(mirrorP(p), r, pathMin)
end

-- Signposts (Task 4, brief §13): each arrow follows the first walkable leg of the route from the
-- post, not the straight-line bearing. One post per avenue at its promenade end, the decision
-- point for the walkers leaving that avenue's plot (down the avenue, or along the promenade): for
-- each destination the post takes that plot's route (HubData routes), finds where the route passes
-- the post, and points along the route from there. Every post carries all three boards (movement
-- review M2: a 14-stud "route passes the post" limit dropped the Garage board on posts 5 and 6 and
-- the Stunts board on posts 1 and 2, whose routes leave along the promenade).
local SIGN_DESTINATIONS = {
	{ board = "Portals", route = "Downtown" },
	{ board = "Garage", route = "Garage" },
	{ board = "Stunts", route = "StuntGate" },
}

local function routeFor(plot: number, destination: string): { Vector2 }?
	for _, r in (Layout.Data :: any).routes do
		if r.plot == plot and r.destination == destination then
			return r.points
		end
	end
	return nil
end

-- Direction along `pts` from the point nearest `at`, looking `ahead` studs further on; nil when
-- the route passes further than `near` from the post.
local function legDirection(pts: { Vector2 }, at: Vector2, near: number, ahead: number): Vector2?
	local best, bi, bt = math.huge, 1, 0
	for i = 1, #pts - 1 do
		local a, b = pts[i], pts[i + 1]
		local ab = b - a
		local t = if ab.Magnitude > 1e-6 then math.clamp((at - a):Dot(ab) / ab:Dot(ab), 0, 1) else 0
		local d = (at - (a + ab * t)).Magnitude
		if d < best then
			best, bi, bt = d, i, t
		end
	end
	if best > near then
		return nil
	end
	-- walk `ahead` studs on from the nearest point
	local from = pts[bi] + (pts[bi + 1] - pts[bi]) * bt
	local left = ahead
	local p = from
	for i = bi, #pts - 1 do
		local q = pts[i + 1]
		local seg = (q - p).Magnitude
		if seg >= left then
			p = p + (q - p).Unit * left
			left = 0
			break
		end
		left -= seg
		p = q
	end
	local d = p - from
	return if d.Magnitude > 0.5 then d.Unit else nil
end

local SIGN_NEAR = 40 -- the post stands at the junction; a promenade route passes within about 25
local function signBoards(ctx: Ctx, post: BasePart, at: Vector2, plot: number)
	local y = groundY(at)
	local n = 0
	for _, dest in SIGN_DESTINATIONS do
		local pts = routeFor(plot, dest.route)
		local dir = pts and legDirection(pts, at, SIGN_NEAR, 10)
		if dir then
			n += 1
			-- board +X along dir: plan (x, y) is world (x, -z)
			local yaw = math.atan2(dir.Y, dir.X)
			local base = CFrame.new(at.X, y + 7.0 - 1.35 * (n - 1), -at.Y) * CFrame.Angles(0, yaw, 0)
			local board = KitAssets.place("SignpostBoard", base, 1)
			board.Parent = post.Parent
			ctx.counts.SignpostBoard = (ctx.counts.SignpostBoard or 0) + 1
			ctx.triangles += KitAssets.info("SignpostBoard").triangles
			local face = Instance.new("Part")
			face.Name = "BoardFace"
			face.Anchored = true
			face.CanCollide = false
			face.CanQuery = false
			face.CanTouch = false
			face.CastShadow = false
			face.Transparency = 1
			face.Size = Vector3.new(4.2, 0.95, 0.26)
			face.CFrame = base * CFrame.new(2.0, 0, 0)
			face.Parent = board
			Signs.signpostBoard(face, dest.board)
			board:SetAttribute("Destination", dest.board)
			board:SetAttribute("RoutePlot", plot)
			board:SetAttribute("LegDirection", dir)
		end
	end
	post:SetAttribute("Boards", n)
	post:SetAttribute("BoardsWanted", #SIGN_DESTINATIONS)
	post:SetAttribute("ForPlot", plot)
end

local function avenueLine(index: number): ({ Vector2 }, number)
	for _, path in park.paths do
		if (path :: any).kind == "Avenue" .. index then
			return (path :: any).points, (path :: any).width
		end
	end
	error("no Avenue" .. index)
end

local function buildSignposts(ctx: Ctx)
	-- east avenues 4 to 6 with their mirrors 3 to 1 (the plots mirror as k and 7 - k)
	for k = 4, 6 do
		local pts, width = avenueLine(k)
		local a, b = pts[1], pts[#pts] -- promenade end first, plaza end last
		local dir = (b - a).Unit
		local normal = Vector2.new(-dir.Y, dir.X)
		-- near the promenade end of the avenue, where the viewing corridor is still narrow enough
		-- for a post beside the path to stand outside it (nearer the ring a 7-tall post would hide
		-- the portals, and the river bank and the ring path take the rest)
		-- (the two centre avenues' corridors cover the path sides near the promenade, so the search
		-- also steps further out from the path and on down the avenue; movement review M2)
		local spots = {}
		for _, offset in { 6, 9, 12, 15, 18, 22, 26, 30, 34, 38 } do
			for _, out in { 2.5, 4.5, 6.5 } do
				table.insert(spots, { offset, out })
			end
		end
		for _, spot in spots do
			local offset, out = spot[1], spot[2]
			local placed = false
			for _, s in { 1, -1 } do
				local at = a + dir * offset + normal * s * (width / 2 + out)
				local q = mirrorP(at)
				if
					lawnOk(at, 1.5, 1.2)
					and lawnOk(q, 1.5, 1.2)
					and free(ctx, at, 4)
					and free(ctx, q, 4)
					and not inCorridor(at)
					and not inCorridor(q)
				then
					local e = put(ctx, "Signposts", "SignpostPost", at, 0, 1, { r = 4 })
					local w = put(ctx, "Signposts", "SignpostPost", q, 0, 1, { r = 4 })
					if e then
						signBoards(ctx, e, at, k)
					end
					if w then
						signBoards(ctx, w, q, 7 - k)
					end
					placed = e ~= nil and w ~= nil
					break
				end
			end
			if placed then
				break
			end
		end
	end
end

-- Where a bench pair stands along an avenue, as a radius from the fountain. One pair on the inner
-- lawn, one on the outer, so every avenue has the same rhythm (M2-06).
local BENCH_RADII = { 86, 190 }
local BENCH_SETBACK = 1.2 -- studs from the path edge to the bench's front feet

-- Formal furniture, mirrored. Lamps stand in matched pairs across a path, every 36 studs. A lamp is
-- too thin for the blanket corridor rule; PortalSight's ray test judges it. Benches are few and paired: two
-- facing each other across an avenue, backs to the lawn, and a bin beside the inner pairs.
local function buildFurniture(ctx: Ctx)
	walkEast(36, 18, function(p, dir, normal, path, _n)
		local width = (path :: any).width or 8
		local a = p + normal * (width / 2 + 1.2)
		local b = p - normal * (width / 2 + 1.2)
		local function clear(at: Vector2): boolean
			return lawnOkPair(at, 0.8, 0.6) and free(ctx, at, 1)
		end
		if clear(a) and clear(b) then
			for _, at in { a, b } do
				local lamp = putPair(ctx, "Lamps", "LampPost", at, dir, 1, { solid = true, r = 2, envelope = true })
				if lamp then
					putPair(ctx, "Lamps", "LampGlass", at, dir, 1, {
						material = Enum.Material.Glass,
						transparency = 0.15,
						envelope = true,
					})
				end
			end
		end
	end)
	for k = 4, 6 do
		local pts, width = avenueLine(k)
		local dir = (pts[1] - pts[#pts]).Unit -- plaza end toward the promenade
		local normal = Vector2.new(-dir.Y, dir.X)
		for i, r in BENCH_RADII do
			local centre = pts[#pts] + dir * (r - (pts[#pts] - Vector2.zero).Magnitude)
			local a = centre + normal * (width / 2 + BENCH_SETBACK + 0.9)
			local b = centre - normal * (width / 2 + BENCH_SETBACK + 0.9)
			local ok = true
			for _, at in { a, b } do
				ok = ok and lawnOkPair(at, 3.2, 1) and free(ctx, at, 3) and free(ctx, mirrorP(at), 3)
			end
			if ok then
				putPair(ctx, "Benches", "Bench", a, -normal, 1, { solid = true, r = 3.5 })
				putPair(ctx, "Benches", "Bench", b, normal, 1, { solid = true, r = 3.5 })
				if i == 1 and KitAssets.has("ParkBin") then
					putPair(ctx, "Benches", "ParkBin", a + dir * 4, -normal, 1, { solid = true, r = 1 })
				end
			else
				ctx.rejected.benchPair = (ctx.rejected.benchPair or 0) + 1
			end
		end
	end
	buildSignposts(ctx)
end

-- Lakeside fence: the segment mesh's length is the pitch; each run ends in a white post.
local FENCE_PITCH = 8
local FENCE_WHITE = Color3.fromRGB(246, 242, 236)
local function fencePost(ctx: Ctx, p: Vector2)
	local y = groundY(p)
	local f = folder(ctx, "Fences")
	-- the cap's top at 2.9, under the 3-stud viewing-corridor limit (the fence itself is 2.8)
	local post =
		plainPart("FenceEndPost", Vector3.new(0.5, 2.95, 0.5), CFrame.new(p.X, y + 1.275, -p.Y), FENCE_WHITE, f)
	post:SetAttribute("FenceEnd", true)
	plainPart("FenceEndCap", Vector3.new(0.7, 0.15, 0.7), CFrame.new(p.X, y + 2.825, -p.Y), FENCE_WHITE, f)
	ctx.counts.FenceEndPost = (ctx.counts.FenceEndPost or 0) + 1
end

local function buildHedges(ctx: Ctx)
	-- low clipped hedges round the plaza, with openings where the paths arrive (an even count so
	-- the ring is mirror-symmetric about the axis)
	local r = park.plazaRadius + 2.6
	local n = math.floor(2 * math.pi * r / 6.4 / 2) * 2
	for k = 0, n - 1 do
		local a = (k + 0.5) / n * math.pi * 2
		local p = Vector2.new(math.cos(a), math.sin(a)) * r
		local tangent = Vector2.new(-math.sin(a), math.cos(a))
		-- both hedge ends off the round plaza fillets (review J7: hedges lay on the join paving)
		local ends = { p + tangent * 3.4, p - tangent * 3.4, p }
		local onFillet = false
		for _, q in ends do
			onFillet = onFillet or Layout.onPlazaFillet(q, 0.8)
		end
		-- nor on the paved stage forecourt between the plaza and the portal stage walk (Park
		-- buildJoins paves |x| < spacing + 7 up to the walk's plaza-side edge)
		local pr = park.portal
		local onForecourt = p.Y < 0 and math.abs(p.X) < pr.spacing + 7 + 3 and p.Y > pr.frontY + 3 + 5 - 3
		if pathClear(p) > 1.5 and streamClear(p) > 2 and buildingClear(p) > 1 and not onFillet and not onForecourt then
			put(ctx, "Hedges", "HedgeLow", p, yawAlong(tangent), 1, { solid = true })
		end
	end
	table.insert(ctx.taken, { p = Vector2.zero, r = r + 2 })
	-- topiary pairs beside the path ends, mirrored
	walkEast(1e6, 4, function(p, dir, normal, path, _n)
		local width = (path :: any).width or 8
		for _, side in { 1, -1 } do
			local at = p + normal * side * (width / 2 + 2.4) - dir * 1
			if lawnOkPair(at, 1.8, 1.2) then
				putPair(ctx, "Hedges", "TopiaryCone", at, dir, 1, { solid = true, r = 2.2 })
			end
		end
	end)
	-- Task 4: no car topiary. It was the "turtle on a brown pad" standing in the lake; the shore
	-- rule (onLand) now keeps every footprint on dry land, and Task4Checks asserts it.
	-- white fences on the lake side of the lakeside walks, ending in a post before each bridge and
	-- building
	for _, path in park.paths do
		local pts = (path :: any).points
		local kind = (path :: any).kind
		if pts and string.find(kind, "Lakeside") then -- the forecourt walks stay open to the buildings
			local width = (path :: any).width or 8
			for i = 1, #pts - 1 do
				local a, b = pts[i], pts[i + 1]
				local seg = (b - a).Magnitude
				local dir = (b - a) / math.max(seg, 1e-6)
				local normal = Vector2.new(-dir.Y, dir.X)
				local side = if normal.Y < 0 then 1 else -1 -- toward the lake (plan south)
				-- segments end to end (pitch = the mesh length; movement review M8: a 9-stud pitch left
				-- 1-stud gaps), and a post at both ends of every unbroken run
				local runStart: Vector2? = nil
				local runEnd: Vector2? = nil
				local function closeRun()
					if runStart and runEnd then
						fencePost(ctx, runStart)
						fencePost(ctx, runEnd)
					end
					runStart, runEnd = nil, nil
				end
				for t = 4, seg - 4, FENCE_PITCH do
					local at = a + dir * t + normal * side * (width / 2 + 0.8)
					local ok = bridgeClear(at) > 4 and buildingClear(at) > 4 and onLand(at, 1) -- room to stand at a board
					if ok and put(ctx, "Fences", "FenceSegment", at, yawAlong(dir), 1, { solid = true }) then
						runStart = runStart or (at - dir * FENCE_PITCH / 2)
						runEnd = at + dir * FENCE_PITCH / 2
					else
						closeRun()
					end
				end
				closeRun()
			end
		end
	end
end

-- ---------------------------------------------------------------- flower beds
-- The flower-bed family (Task 4, brief §6), mirrored: corner beds in the grass corners where the
-- avenues meet the garden ring, beds along the avenues, and arc beds round the fountain plaza.
-- Planting is layered (tall at the back, middle, low edging at the front toward the path) in
-- colour drifts of three kinds per bed. The family's own meshes (BedCornerFillet, BedAvenueArc,
-- BedFountainArc) are used when imported; until then the kit's round and oval beds stand in.
local BED_FLOWERS = { -- back, middle, front; all under 3 (beds sit in viewing corridors)
	{ "TulipsRed", "Poppies", "Daisies" },
	{ "Lavender", "RosesPink", "BlueWildflowers" },
	{ "TulipsYellow", "Poppies", "Clover" },
	{ "RosesPink", "Lavender", "Daisies" },
	{ "RosesRed", "TulipsYellow", "Clover" },
	{ "Lavender", "BlueWildflowers", "Daisies" },
}

-- One clump every PLANT_STEP studs on a staggered grid (Task 4: thousands of clumps cost 530k
-- triangles, so the carpet below carries the green and the clumps stay few).
local PLANT_STEP = 3.1
local BED_CLEARANCE = 2 -- studs from a bed's kerb to any path edge, everywhere (M2-03)
local FLOWER_SCALES = { 1, 0.85, 0.7 } -- the largest that fits wins
local TALL_DEPTH, MID_DEPTH = 2.2, 1.1 -- how far in from the rim the taller bands start

-- The smallest path edge distance anywhere round a bed's kerb.
local function bedClearance(name: string, at: Vector2, yaw: number): number
	local worst = math.huge
	for _, q in BedShapes.outline(name) do
		local p = BedShapes.toPlan(at, yaw, q)
		local d = pathClear(p)
		if Layout.onPaved(p, 0) then
			d = -1
		end
		worst = math.min(worst, d)
	end
	return worst
end

local function plantAt(ctx: Ctx, name: string, q: Vector2, y: number, yaw: number, scale: number, id: string)
	local part = put(ctx, "Beds", name, q, yaw, scale, { y = y })
	if part then
		part:SetAttribute("BedId", id)
	end
end

-- The rotated bounds of a clump, as points in the plan.
local function clumpCorners(name: string, at: Vector2, yaw: number, scale: number): { Vector2 }
	local e = KitAssets.info(name)
	local c, s = math.cos(yaw), math.sin(yaw)
	local out = {}
	for _, x in { e.min.X * scale, e.max.X * scale } do
		for _, z in { e.min.Z * scale, e.max.Z * scale } do
			table.insert(out, at + Vector2.new(x * c + z * s, x * s - z * c))
		end
	end
	return out
end

local function fits(name: string, kind: string, bedAt: Vector2, bedYaw: number, at: Vector2, yaw: number, scale: number)
	for _, p in clumpCorners(kind, at, yaw, scale) do
		if BedShapes.soil(name, BedShapes.toLocal(bedAt, bedYaw, p)) < 0.05 then
			return false
		end
	end
	return true
end

-- Plants a bed and its mirror image, one planned scheme per bed: edging plants at the rim, taller
-- flowers in the middle. A clump goes in only if its whole footprint, petals and leaves, is inside
-- the soil on BOTH sides, so the two beds stay mirror images.
local function plantBed(ctx: Ctx, name: string, at: Vector2, yaw: number, mAt: Vector2?, mYaw: number?, palette: number)
	local info = KitAssets.info(name)
	local y = groundY(at) + (info.meta.soil or 0.6)
	local kinds = BED_FLOWERS[(palette - 1) % #BED_FLOWERS + 1]
	local id = string.format("%s@%.0f,%.0f", name, at.X, at.Y)
	local mid = if mAt then string.format("%s@%.0f,%.0f", name, mAt.X, mAt.Y) else ""
	local row = 0
	for z = info.min.Z, info.max.Z, PLANT_STEP * 0.87 do
		row += 1
		for x = info.min.X + (if row % 2 == 0 then PLANT_STEP / 2 else 0), info.max.X, PLANT_STEP do
			local q = Vector2.new(x, z)
			local depth = BedShapes.soil(name, q)
			if depth > 0.3 then
				local band = if depth > TALL_DEPTH then 1 elseif depth > MID_DEPTH then 2 else 3
				local kind = kinds[band]
				local turn = (x * 7 + z * 3) % 6.28
				local p = BedShapes.toPlan(at, yaw, q)
				local mp = if mAt then mirrorP(p) else p
				for _, scale in FLOWER_SCALES do
					local scaleFit = math.min(scale, (2.85 - (info.meta.soil or 0.6)) / math.max(info.max.Y, 0.1))
					local ok = fits(name, kind, at, yaw, p, turn, scaleFit)
					if ok and mAt then
						ok = fits(name, kind, mAt, mYaw :: number, mp, -turn, scaleFit)
					end
					if ok then
						plantAt(ctx, kind, p, y, turn, scaleFit, id)
						if mAt then
							plantAt(ctx, kind, mp, y, -turn, scaleFit, mid)
						end
						break
					end
				end
			end
		end
	end
end

local function placeBed(ctx: Ctx, name: string, at: Vector2, yaw: number): MeshPart?
	local bed = put(ctx, "Beds", name, at, yaw, 1, { y = groundY(at) })
	if bed then
		bed:SetAttribute("BedAt", at)
		bed:SetAttribute("BedYaw", yaw)
		bed:SetAttribute("BedId", string.format("%s@%.0f,%.0f", name, at.X, at.Y))
	end
	return bed
end

local function reserveBed(ctx: Ctx, name: string, at: Vector2, yaw: number)
	for _, q in BedShapes.outline(name) do
		table.insert(ctx.taken, { p = BedShapes.toPlan(at, yaw, q), r = 2.5 })
	end
end

-- A bed and its mirror image, or one bed on the axis, with the kerb's clearance tested first.
local function bedPair(ctx: Ctx, name: string, at: Vector2, yaw: number, mirrorYaw: number, palette: number): boolean
	local onAxis = math.abs(at.X - AXIS) < 0.5
	local mAt = if onAxis then nil else mirrorP(at)
	if bedClearance(name, at, yaw) < BED_CLEARANCE - 0.05 then
		ctx.rejected.bedClearance = (ctx.rejected.bedClearance or 0) + 1
		return false
	end
	if mAt and bedClearance(name, mAt, mirrorYaw) < BED_CLEARANCE - 0.05 then
		ctx.rejected.bedClearance = (ctx.rejected.bedClearance or 0) + 1
		return false
	end
	local a = placeBed(ctx, name, at, yaw)
	local b = if mAt then placeBed(ctx, name, mAt, mirrorYaw) else nil
	if not a or (mAt and not b) then
		return false
	end
	reserveBed(ctx, name, at, yaw)
	if mAt then
		reserveBed(ctx, name, mAt, mirrorYaw)
		a:SetAttribute("MirrorPair", true);
		(b :: MeshPart):SetAttribute("MirrorPair", true)
	end
	plantBed(ctx, name, at, yaw, mAt, mirrorYaw, palette)
	return true
end

-- An arc bed: the mesh's arc is centred behind it (mesh -Z), so that side faces the fountain and the
-- bed reads as part of a ring round it. The mesh's front (+Z) points away from the fountain.
local function arcBed(ctx: Ctx, name: string, bearing: number, radii: { number }, palette: number): boolean
	local dir = Vector2.new(math.sin(math.rad(bearing)), math.cos(math.rad(bearing)))
	for _, r in radii do
		local at = dir * r
		if bedPair(ctx, name, at, yawFacing(dir), yawFacing(mirrorD(dir)), palette) then
			return true
		end
	end
	return false
end

-- A corner bed in the grass corner at C, whose two path edges leave C along u1 and u2 (near enough
-- square). The mesh's origin is the path corner and its straight sides run along mesh +X and -Z,
-- which end up along u1 and u2. It slides out of the corner until the whole kerb clears both paths.
local function cornerBed(ctx: Ctx, C: Vector2, u1: Vector2, u2: Vector2, palette: number): boolean
	if cross(u1, u2) < 0 then
		u1, u2 = u2, u1
	end
	local name = "BedCornerFillet"
	local mu1 = mirrorD(u2) -- the mirror image swaps handedness
	for slide = 1, 5, 0.25 do
		local at = C + (u1 + u2) * slide
		local yaw = math.atan2(u1.Y, u1.X)
		if bedClearance(name, at, yaw) >= BED_CLEARANCE then
			local mAt = mirrorP(at)
			local myaw = math.atan2(mu1.Y, mu1.X)
			if bedClearance(name, mAt, myaw) >= BED_CLEARANCE then
				return bedPair(ctx, name, at, yaw, myaw, palette)
			end
		end
	end
	ctx.rejected.cornerBed = (ctx.rejected.cornerBed or 0) + 1
	return false
end

local function buildBeds(ctx: Ctx)
	local palette = 0
	-- 1. fountain beds: a ring round the plaza, one centred in each sector between two paths, moved
	--    out to where the sector is wide enough for the bed at one clearance. The same radius for
	--    all four keeps the ring a ring.
	if KitAssets.has("BedFountainArc") then
		local radii = {}
		for r = 60, 96, 2 do
			table.insert(radii, r)
		end
		local fit: number? = nil
		for _, r in radii do
			local ok = true
			for _, bearing in { 0, 30, 60, 90 } do
				local dir = Vector2.new(math.sin(math.rad(bearing)), math.cos(math.rad(bearing)))
				ok = ok and bedClearance("BedFountainArc", dir * r, yawFacing(dir)) >= BED_CLEARANCE
			end
			if ok then
				fit = r
				break
			end
		end
		ctx.counts.fountainBedRadius = fit or 0
		if fit then
			for _, bearing in { 0, 30, 60, 90 } do
				palette += 1
				arcBed(ctx, "BedFountainArc", bearing, { fit }, palette)
			end
		end
	end
	-- 2. corner beds in the grass corners where each east avenue meets the garden ring (plaza
	--    side) and the promenade, mirrored to the west avenues
	for k = 4, 6 do
		local pts, width = avenueLine(k)
		local dir = (pts[#pts] - pts[1]).Unit -- promenade end toward the plaza
		local normal = Vector2.new(-dir.Y, dir.X)
		for _, edge in
			{
				{ r = park.ringRadius - 4 }, -- the ring's plaza-side edge; beds on the plaza side
				{ r = park.promenade.inner }, -- the promenade's park-side edge; beds on the park side
			}
		do
			local J = pts[1] + dir * ((pts[1] - Vector2.zero).Magnitude - edge.r) -- on the centre line
			local tangent = Vector2.new(J.Y, -J.X).Unit
			for _, s in { 1, -1 } do
				-- the avenue edge on side s meets the circle edge at C (local straight-line model)
				local C = J + normal * s * (width / 2)
				C = C.Unit * edge.r
				local u2 = tangent * (if tangent:Dot(normal * s) >= 0 then 1 else -1) -- along the circle, away from the avenue
				palette += 1
				if KitAssets.has("BedCornerFillet") then
					cornerBed(ctx, C, dir, u2, palette)
				end
			end
		end
	end
	-- 3. (removed, Task 4 review J1: the 24 straight beds along the avenues read as brown
	--    confetti from above; the lawns there stay open, which also frames the avenues)
	-- 4. curved beds along the promenade's park-side edge, between the avenues
	if KitAssets.has("BedAvenueArc") then
		for _, bearing in { 30, 60 } do
			palette += 1
			local kerbOut = KitAssets.info("BedAvenueArc").max.Z
			arcBed(ctx, "BedAvenueArc", bearing, { park.promenade.inner - BED_CLEARANCE - kerbOut - 0.1 }, palette)
		end
	end
	-- 5. round beds exactly centred in the sectors inside the garden ring
	if KitAssets.has("BedJunctionRound") then
		for _, bearing in { 0, 30, 60 } do
			palette += 1
			for _, radius in { 95, 85, 105, 75, 115 } do
				local p = Vector2.new(math.sin(math.rad(bearing)), math.cos(math.rad(bearing))) * radius
				if lawnOkPair(p, 9, 2) and bedPair(ctx, "BedJunctionRound", p, 0, 0, palette) then
					break
				end
			end
		end
	end
end

-- Bedding carpets (Task 4 review J1: the beds read as half-empty brown soil). Each bed gets a
-- copy of its own mesh, untextured, in a deep leaf green, shrunk toward its centre so its rim
-- sits just inside the stone kerb and raised above the soil: the soil reads as low bedding foliage
-- with the flowers rising from it. No new asset; mirrored with its bed.
local CARPET_GREEN = Color3.fromRGB(70, 138, 74) -- deeper than the lawn (proposal)
local CARPET_SHRINK = 0.9 -- of the bed's plan size
local CARPET_LIFT = 0.08 -- clear of the soil's own plane, so the two never fight
local function carpetBeds(ctx: Ctx)
	local beds = folder(ctx, "Beds")
	local made = 0
	for _, bed in beds:GetChildren() do
		if bed:IsA("MeshPart") and string.sub(bed.Name, 1, 3) == "Bed" and KitAssets.has(bed.Name) then
			local c = bed:Clone()
			c.Name = "BedCarpet"
			c.TextureID = ""
			c.Color = CARPET_GREEN
			c.Material = Enum.Material.Grass
			c.CastShadow = false
			c.CanCollide = false
			c.CanQuery = false
			c.Size = Vector3.new(bed.Size.X * CARPET_SHRINK, bed.Size.Y, bed.Size.Z * CARPET_SHRINK)
			c.CFrame = bed.CFrame + Vector3.new(0, CARPET_LIFT, 0)
			c.Parent = beds
			made += 1
		end
	end
	ctx.counts.BedCarpet = made
end

-- ---------------------------------------------------------------- lawns
-- Grass tufts set back from the path edges, never on paving; mirrored about the axis. The loose
-- flower drifts are gone (Adam, M2-05): every flower in the park is in a bed.
local function buildLawns(ctx: Ctx)
	walkEast(9, 2, function(p, _dir, normal, path, n)
		local width = (path :: any).width or 8
		local side = if n % 2 == 0 then 1 else -1
		local at = p + normal * side * (width / 2 + ctx.rng:NextNumber(1.2, 2.2))
		if ctx.rng:NextNumber() < 0.4 and lawnOkPair(at, 0.8, 0.9) and free(ctx, at, 1.2) then
			local kind = if ctx.rng:NextNumber() < 0.6 then "GrassTuft" else "GrassTuftWide"
			putPair(ctx, "Lawns", kind, at, Vector2.new(0, 1), 1, {})
		end
	end)
end

-- ---------------------------------------------------------------- park trees
local TREE_BUILDING_CLEAR = 13 -- a crown's reach plus air: no leaves in the gazebo roof (M2-08)
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
		if mask > -0.05 and lawnOk(p, 3, 4) and free(ctx, p, 12) and buildingClear(p) >= TREE_BUILDING_CLEAR then
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
	buildGazebo(ctx)
	buildSnackCorners(ctx)
	task.wait()
	buildHedges(ctx)
	-- Task 4: the formal bed family first, then the furniture fills round it
	buildBeds(ctx)
	carpetBeds(ctx)
	task.wait()
	buildFurniture(ctx)
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
