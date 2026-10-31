--!strict
-- Island World portals (Lane 3, client presentation only). Each portal is a frameless energy
-- field about 20 x 30 studs floating over a soft pool of coloured light (the field itself has no
-- frame; the shared gate stands round it, see below). Built on this client from the shared rig (Lane3_IslandEnvironment.Portals):
--   the field: soft translucent layers on SurfaceGuis of three invisible carriers at different
--     depths (so an oblique view sees depth): a coloured depth oval and a wide aura at the back,
--     two cloudy bodies, two counter-rotating spirals and a pink accent in the middle, a luminous
--     core and a sliding sheen in front. Every layer is a soft oval or round swirl with its own
--     falloff; there is no clip, frame, rim or rectangle anywhere;
--   particles: motes drawn inward on a slowly turning host (LockedToPart, so they swirl round
--     the centre), outward-floating sparkles, embers rising from the pool, an occasional soft
--     outward burst;
--   light: a few upward light beams, a pool of light on the ground and a point light;
--   sound: a quiet positional hum with a soft shimmer layer (louder close up; quieter and lower
--     when locked).
-- Presentation levels, eased over about a second: idle far away, stronger from about 60 studs,
-- strongest within about 15 (the local character's distance; a free camera never activates it).
-- The camera's distance and view set the rendering budget: off-screen or far portals stop their
-- animation and emitters and keep a cheap still look. Reduced motion (GuiService
-- .ReducedMotionEnabled or the preview-only "Lane3ReducedMotionOverride" attribute) keeps the
-- field stable: very slow layers, gentle breathing, no bursts, fewer particles.
-- Locked portals (PortalPreviewState, a preview source) are dimmer, desaturated and slower, with
-- no beams or bursts and sparse particles. The gate round each field is built for everyone
-- (Environment/PortalGates); per player this script colours its inlay bands (dark while locked,
-- lit in the World colour when open) and, on Dusty Highway and Summit Pass while locked, builds
-- the lock from the PortalKit pieces: chains wrapped round both columns and crossing in an X,
-- a padlock with the World emblem hung from the crossing, a friendly LOCKED plaque under it and
-- the requirement plaque (PREVIEW values) on its short pedestal beside the column. Downtown is
-- never chained. Unlocking (preview toggle) opens the padlock, drops and fades the chains,
-- retracts the plaques, lights the inlays bottom to top and plays one burst; reduced motion
-- cross-fades instead. Locking again removes any fading lock at once and rebuilds it cleanly.
-- While a kit mesh is only a session preview (blank in a playtest), the lock pieces are built
-- from parts and the gate shows its part stand-in. Nothing here moves the player, changes
-- physics or touches shared state.

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Trove = require(ReplicatedStorage.Packages.Trove)
local PortalPreviewState = require(script.Parent.PortalPreviewState)

local ROOT_NAME = "Lane3_IslandEnvironment"
local OVERRIDE = "Lane3ReducedMotionOverride"
local PPS = 16 -- SurfaceGui pixels per stud
local MARGIN = 6 -- studs of canvas round the field for the veil
local NEAR, FAR = 15, 60 -- presentation levels by character distance (Tunable)
local EASE = 0.35 -- seconds time constant: about a second to settle
local CAMERA_BUDGET = 420 -- beyond this camera distance the portal rests (Tunable)

local player = Players.LocalPlayer

type Palette = { core: Color3, a: Color3, b: Color3, depth: Color3, accent: Color3, spark: Color3, band: Color3 }

-- World palettes (Adam, 2026-10-22)
local PALETTES: { [string]: Palette } = {
	Downtown = {
		core = Color3.fromRGB(255, 244, 214), -- warm white-gold
		a = Color3.fromRGB(255, 214, 84), -- yellow movement
		b = Color3.fromRGB(255, 156, 46), -- orange movement
		depth = Color3.fromRGB(150, 78, 18), -- amber depth
		accent = Color3.fromRGB(255, 72, 168), -- pink accent (saturated so it survives the glow)
		spark = Color3.fromRGB(255, 236, 170),
		band = Color3.fromRGB(154, 78, 18), -- amber recess
	},
	DustyHighway = {
		core = Color3.fromRGB(255, 226, 150), -- pale gold
		a = Color3.fromRGB(232, 78, 30), -- deep orange
		b = Color3.fromRGB(176, 22, 44), -- red, toward crimson so it stays apart from Downtown
		depth = Color3.fromRGB(84, 16, 36), -- dark wine
		accent = Color3.fromRGB(255, 170, 90),
		spark = Color3.fromRGB(255, 200, 130),
		band = Color3.fromRGB(70, 12, 30), -- wine recess
	},
	SummitPass = {
		core = Color3.fromRGB(255, 255, 255), -- white
		a = Color3.fromRGB(120, 232, 255), -- icy cyan
		b = Color3.fromRGB(96, 170, 255),
		depth = Color3.fromRGB(64, 52, 168), -- violet-blue
		accent = Color3.fromRGB(200, 170, 255),
		spark = Color3.fromRGB(228, 246, 255), -- pale sparkle
		band = Color3.fromRGB(44, 34, 128), -- violet-blue recess
	},
}

local function reducedMotion(): boolean
	local override = player:GetAttribute(OVERRIDE)
	if type(override) == "boolean" then
		return override
	end
	return GuiService.ReducedMotionEnabled
end

local function lockedColour(c: Color3): Color3
	-- desaturate toward a light cool grey and lower the contrast: calm and dormant, never a
	-- dark soot cloud (the review: dark smoke reads as danger to children)
	local grey = 0.3 * c.R + 0.59 * c.G + 0.11 * c.B
	local cool = Color3.new(0.62 + 0.25 * grey, 0.66 + 0.25 * grey, 0.74 + 0.22 * grey)
	return cool:Lerp(c, 0.35)
end

local function smooth(x: number): number
	x = math.clamp(x, 0, 1)
	return x * x * (3 - 2 * x)
end

type Layer = { label: ImageLabel, spin: number, base: number }

type Portal = {
	world: string,
	anchor: BasePart,
	palette: Palette,
	trove: Trove.Trove,
	level: number,
	lock: number, -- 1 locked look, 0 open (eased)
	locked: boolean,
	guis: { SurfaceGui },
	layers: { [string]: { ImageLabel } },
	spinHost: BasePart,
	emitters: { [string]: ParticleEmitter },
	beams: { Beam },
	light: PointLight,
	pool: ImageLabel?,
	hum: Sound?,
	shimmer: Sound?,
	lockModel: Model?, -- the live lock (nil while one fades out)
	lockTrove: Trove.Trove?, -- owns the lock model, live or fading, and its tweens and timers
	nextBurst: number,
	angle: number,
	resting: boolean,
	gate: Model?,
	bands: { { BasePart } }, -- inlay parts per band, bottom to top
	bandTrove: Trove.Trove?,
}

local function newImage(parent: Instance, name: string, id: string, z: number): ImageLabel
	local i = Instance.new("ImageLabel")
	i.Name = name
	i.BackgroundTransparency = 1
	i.Image = id
	i.AnchorPoint = Vector2.new(0.5, 0.5)
	i.Position = UDim2.fromScale(0.5, 0.5)
	i.ZIndex = z
	i.Parent = parent
	return i
end

local function run(trove: Trove.Trove, rig: Instance)
	local kit = rig:WaitForChild("PortalKit")
	local function tex(name: string): string
		local v = kit:GetAttribute(name)
		return if type(v) == "string" then v else ""
	end
	local origin = CFrame.new(kit:GetAttribute("Origin") :: Vector3)
	local templates: { [string]: BasePart } = {}
	local offsets: { [string]: CFrame } = {}
	for _, t in kit:GetChildren() do
		if t:IsA("BasePart") then
			templates[t.Name] = t
			offsets[t.Name] = origin:ToObjectSpace(t.CFrame)
		end
	end

	local liveFolder = trove:Add(Instance.new("Folder"))
	liveFolder.Name = "Lane3_PortalFields"
	liveFolder.Parent = Workspace

	-- one shared hum loader: a sound that fails to load is not retried
	local soundIds = {
		hum = kit:GetAttribute("SoundPortalHum"),
		shimmer = kit:GetAttribute("SoundPortalShimmer"),
	}

	local portals: { Portal } = {}

	local function buildField(p: Portal)
		local w, h = p.anchor:GetAttribute("Width") :: number, p.anchor:GetAttribute("Height") :: number
		local cf = p.anchor.CFrame
		local pal = p.palette
		local fw, fh = w * PPS, h * PPS
		-- Three carriers at different depths (front toward the plots, middle, back), so an oblique
		-- view sees the layers separate. Every layer is a soft oval or a soft round swirl with its
		-- own falloff: no clip, frame, rim or rectangle. From behind, the same stack shows mirrored
		-- (each outer carrier's far face carries the opposite layer set).
		local function carrier(name: string, z: number): Part
			local c = p.trove:Add(Instance.new("Part"))
			c.Name = p.world .. name
			c.Anchored = true
			c.CanCollide = false
			c.CanQuery = false
			c.CanTouch = false
			c.CastShadow = false
			c.Transparency = 1
			c.Size = Vector3.new(w + 2 * MARGIN, h + 2 * MARGIN, 0.05)
			c.CFrame = cf * CFrame.new(0, 0, z)
			c.Parent = liveFolder
			return c
		end
		local function surface(part: Part, face: Enum.NormalId): SurfaceGui
			local g = Instance.new("SurfaceGui")
			g.Name = "Field" .. face.Name
			g.Face = face
			g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
			g.PixelsPerStud = PPS
			g.LightInfluence = 0
			g.Brightness = 2
			g.MaxDistance = 0
			g.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
			g.Parent = part
			table.insert(p.guis, g)
			return g
		end
		local function add(key: string, image: ImageLabel)
			p.layers[key] = p.layers[key] or {}
			table.insert(p.layers[key], image)
		end
		-- the deep layer: coloured depth and a wide soft aura
		local function deep(g: SurfaceGui)
			local aura = newImage(g, "Aura", tex("Glow"), 1)
			aura.Size = UDim2.fromOffset(fw * 1.6, fh * 1.15)
			aura.Position = UDim2.fromScale(0.5, 0.47)
			aura.ImageColor3 = pal.b
			aura.ImageTransparency = 0.55
			add("aura", aura)
			local depth = newImage(g, "Depth", tex("PortalDepth"), 2)
			depth.Size = UDim2.fromOffset(fw * 1.04, fh * 1.0)
			depth.ImageColor3 = pal.depth
			depth.ImageTransparency = 0.05
			add("depth", depth)
		end
		-- the near layer: the luminous core and a sliding sheen of light
		local function near(g: SurfaceGui)
			local sheen = newImage(g, "Sheen", tex("PortalCloudBallB"), 1)
			sheen.Size = UDim2.fromOffset(fw * 0.8, fh * 0.75)
			sheen.ImageColor3 = pal.core
			sheen.ImageTransparency = 0.55
			add("sheen", sheen)
			local core = newImage(g, "Core", tex("PortalCore"), 2)
			core.Size = UDim2.fromOffset(fw * 0.62, fw * 0.62)
			core.Position = UDim2.fromScale(0.5, 0.46)
			core.ImageColor3 = pal.core
			core.ImageTransparency = 0.05
			add("core", core)
		end
		local back = carrier("FieldBack", 2.2)
		local mid = carrier("Field", 0)
		local front = carrier("FieldFront", -1.6)
		deep(surface(back, Enum.NormalId.Front))
		near(surface(back, Enum.NormalId.Back))
		near(surface(front, Enum.NormalId.Front))
		deep(surface(front, Enum.NormalId.Back))
		-- the recess: a dark, unlit band just inside the edge, on its own carrier (a SurfaceGui's
		-- Brightness would light it), so the field seems to sink inward
		local recess = carrier("FieldRecess", -0.5)
		local recessBack = carrier("FieldRecessBack", 0.5)
		for _, pair in { { recess, Enum.NormalId.Front }, { recessBack, Enum.NormalId.Back } } do
			local g = surface(pair[1], pair[2])
			g.Brightness = 1
			g:SetAttribute("Unlit", true)
			local band = newImage(g, "Band", tex("PortalBand"), 1)
			band.Size = UDim2.fromOffset(fw * 1.02, fh * 0.98)
			band.ImageColor3 = pal.band
			band.ImageTransparency = 0.15
			add("band", band)
		end
		-- the middle: two cloudy bodies drifting against each other, two counter-turning spirals
		-- and a restrained pink accent, all inside the depth oval
		for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
			local g = surface(mid, face)
			local cloudA = newImage(g, "CloudA", tex("PortalCloudBall"), 1)
			cloudA.Size = UDim2.fromOffset(fw * 0.86, fh * 0.84)
			cloudA.ImageColor3 = pal.depth:Lerp(pal.b, 0.55)
			cloudA.ImageTransparency = 0.45
			add("cloudA", cloudA)
			local cloudB = newImage(g, "CloudB", tex("PortalCloudBallB"), 2)
			cloudB.Size = UDim2.fromOffset(fw * 0.8, fh * 0.78)
			cloudB.ImageColor3 = pal.b:Lerp(pal.a, 0.5)
			cloudB.ImageTransparency = 0.3
			add("cloudB", cloudB)
			local swirlA = newImage(g, "SwirlA", tex("PortalSwirlA"), 3)
			swirlA.Size = UDim2.fromOffset(fw * 1.05, fw * 1.05)
			swirlA.ImageColor3 = pal.a
			swirlA.ImageTransparency = 0.02
			add("swirlA", swirlA)
			local swirlB = newImage(g, "SwirlB", tex("PortalSwirlB"), 4)
			swirlB.Size = UDim2.fromOffset(fw * 0.82, fw * 0.82)
			swirlB.Position = UDim2.fromScale(0.5, 0.47)
			swirlB.ImageColor3 = pal.b
			swirlB.ImageTransparency = 0.12
			add("swirlB", swirlB)
			-- a darker counter-turning spiral round the core: the field seems to recede into its centre
			local tunnel = newImage(g, "Tunnel", tex("PortalSwirlA"), 5)
			tunnel.Size = UDim2.fromOffset(fw * 0.62, fw * 0.62)
			tunnel.Position = UDim2.fromScale(0.5, 0.46)
			tunnel.ImageColor3 = pal.depth
			tunnel.ImageTransparency = 0.25
			add("tunnel", tunnel)
			for k = 1, 3 do
				local ring = newImage(g, "Inflow" .. k, tex("PortalSwirlB"), 4)
				ring.ImageColor3 = pal.a:Lerp(pal.core, 0.3)
				ring:SetAttribute("Phase", (k - 1) / 3)
				add("inflow", ring)
			end
			local accent = newImage(g, "Accent", tex("PortalSwirlB"), 6)
			accent.Size = UDim2.fromOffset(fw * 0.78, fw * 0.78)
			accent.ImageColor3 = pal.accent
			accent.ImageTransparency = 0.35
			add("accent", accent)
		end

		-- particles: an inward swirl on a turning host, sparkles, embers and the burst
		local spin = p.trove:Add(Instance.new("Part"))
		spin.Name = p.world .. "Spin"
		spin.Anchored = true
		spin.CanCollide = false
		spin.CanQuery = false
		spin.CanTouch = false
		spin.Transparency = 1
		spin.Size = Vector3.new(w * 0.95, w * 0.95, 2.4)
		spin.CFrame = cf
		spin.Parent = liveFolder
		p.spinHost = spin
		local function emitter(parent: Instance, name: string, props: { [string]: any }): ParticleEmitter
			local e = Instance.new("ParticleEmitter")
			e.Name = name
			for k, v in props do
				(e :: any)[k] = v
			end
			e:SetAttribute("BaseRate", e.Rate)
			e.Parent = parent
			p.emitters[name] = e
			return e
		end
		emitter(spin, "Motes", {
			Texture = tex("Mote"),
			Shape = Enum.ParticleEmitterShape.Sphere,
			ShapeInOut = Enum.ParticleEmitterShapeInOut.Inward,
			ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface,
			Rate = 10,
			Lifetime = NumberRange.new(2.4, 3.2),
			Speed = NumberRange.new(2.6, 3.6),
			LockedToPart = true,
			Size = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.1),
				NumberSequenceKeypoint.new(0.5, 0.32),
				NumberSequenceKeypoint.new(1, 0.05),
			}),
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(0.2, 0.15),
				NumberSequenceKeypoint.new(1, 1),
			}),
			LightEmission = 1,
			Color = ColorSequence.new(pal.spark),
			ZOffset = 0.5,
		})
		local centreAttach = Instance.new("Attachment")
		centreAttach.Name = "Centre"
		centreAttach.Parent = p.anchor
		emitter(centreAttach, "Sparkles", {
			Texture = tex("Sparkle"),
			Shape = Enum.ParticleEmitterShape.Sphere,
			ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward,
			Rate = 5,
			Lifetime = NumberRange.new(2.2, 3.4),
			Speed = NumberRange.new(1.2, 2.6),
			Drag = 0.8,
			SpreadAngle = Vector2.new(180, 180),
			Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 0.05) }),
			Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1) }),
			RotSpeed = NumberRange.new(-90, 90),
			LightEmission = 1,
			Color = ColorSequence.new(pal.spark),
		})
		local base = Instance.new("Attachment")
		base.Name = "Base"
		base.Position = Vector3.new(0, -h / 2 - 1.5, 0)
		base.Parent = p.anchor
		emitter(base, "Embers", {
			Texture = tex("Ember"),
			Shape = Enum.ParticleEmitterShape.Box,
			Rate = 5,
			Lifetime = NumberRange.new(3, 5),
			Speed = NumberRange.new(1.5, 3),
			SpreadAngle = Vector2.new(18, 18),
			Acceleration = Vector3.new(0, 1.2, 0),
			Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.22), NumberSequenceKeypoint.new(1, 0.05) }),
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(0.15, 0.2),
				NumberSequenceKeypoint.new(1, 1),
			}),
			LightEmission = 1,
			Color = ColorSequence.new(pal.b, pal.a),
		})
		local bodyHost = p.trove:Add(Instance.new("Part"))
		bodyHost.Name = p.world .. "Body"
		bodyHost.Anchored = true
		bodyHost.CanCollide = false
		bodyHost.CanQuery = false
		bodyHost.CanTouch = false
		bodyHost.Transparency = 1
		bodyHost.Size = Vector3.new(w * 0.55, h * 0.6, 3.5)
		bodyHost.CFrame = cf
		bodyHost.Parent = liveFolder
		emitter(bodyHost, "Body", {
			Texture = tex("Glow"),
			Shape = Enum.ParticleEmitterShape.Box,
			Rate = 4,
			Lifetime = NumberRange.new(2.5, 3.5),
			Speed = NumberRange.new(0, 0.3),
			Size = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 5),
				NumberSequenceKeypoint.new(0.5, 8),
				NumberSequenceKeypoint.new(1, 6),
			}),
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(0.4, 0.7),
				NumberSequenceKeypoint.new(1, 1),
			}),
			LightEmission = 1,
			Color = ColorSequence.new(pal.a, pal.b),
		})
		-- the emitter's box shape follows its parent part, so the embers use their own strip part
		local emberHost = p.trove:Add(Instance.new("Part"))
		emberHost.Name = p.world .. "Embers"
		emberHost.Anchored = true
		emberHost.CanCollide = false
		emberHost.CanQuery = false
		emberHost.CanTouch = false
		emberHost.Transparency = 1
		emberHost.Size = Vector3.new(w, 0.4, 3)
		emberHost.CFrame = cf * CFrame.new(0, -h / 2 - 1.2, 0)
		emberHost.Parent = liveFolder
		p.emitters.Embers.Parent = emberHost
		emitter(centreAttach, "Burst", {
			Texture = tex("Glow"),
			Shape = Enum.ParticleEmitterShape.Sphere,
			ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward,
			Rate = 0,
			Lifetime = NumberRange.new(0.9, 1.3),
			Speed = NumberRange.new(9, 13),
			Drag = 3,
			SpreadAngle = Vector2.new(180, 180),
			Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 2) }),
			Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 1) }),
			LightEmission = 1,
			Color = ColorSequence.new(pal.core, pal.a),
		})

		-- a few upward light beams from the pool, behind and at the sides of the field
		local beamHost = p.anchor
		for k, x in { -0.32, 0.36, 0 } do
			local a0 = Instance.new("Attachment")
			a0.Position = Vector3.new(x * w, -h / 2 - 2, if k == 3 then 1.2 else 0.6)
			a0.Parent = beamHost
			p.trove:Add(a0)
			local a1 = Instance.new("Attachment")
			a1.Position = Vector3.new(x * w * 1.1, h / 2 + (if k == 3 then 22 else 14), if k == 3 then 1.2 else 0.6)
			a1.Parent = beamHost
			p.trove:Add(a1)
			local b = Instance.new("Beam")
			b.Name = "LightBeam"
			b.Attachment0, b.Attachment1 = a0, a1
			b.Texture = tex("PortalBeam")
			b.TextureMode = Enum.TextureMode.Stretch
			b.TextureLength = 1
			b.TextureSpeed = 0
			b.FaceCamera = true
			b.Width0 = if k == 3 then 12 else 6
			b.Width1 = if k == 3 then 7 else 3
			b.LightEmission = 1
			b.LightInfluence = 0
			b.Segments = 1
			b.Color = ColorSequence.new(pal.a, pal.b)
			b.Transparency = NumberSequence.new(0.6, 1)
			b.Parent = beamHost
			p.trove:Add(b)
			b:SetAttribute("BaseWidth0", b.Width0)
			b:SetAttribute("BaseWidth1", b.Width1)
			table.insert(p.beams, b)
		end

		-- the pool of light on the ground
		local ground = p.anchor:GetAttribute("Ground") :: number
		local poolPart = p.trove:Add(Instance.new("Part"))
		poolPart.Name = p.world .. "Pool"
		poolPart.Anchored = true
		poolPart.CanCollide = false
		poolPart.CanQuery = false
		poolPart.CanTouch = false
		poolPart.Transparency = 1
		poolPart.Size = Vector3.new(w + 10, 0.05, 14)
		poolPart.CFrame = CFrame.new(cf.Position.X, ground + 0.08, cf.Position.Z - 2) * cf.Rotation
		poolPart.Parent = liveFolder
		local poolGui = Instance.new("SurfaceGui")
		poolGui.Face = Enum.NormalId.Top
		poolGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		poolGui.PixelsPerStud = 8
		poolGui.LightInfluence = 0
		poolGui.Brightness = 1.4
		poolGui.Parent = poolPart
		local pool = newImage(poolGui, "Pool", tex("GroundPool"), 1)
		pool.Size = UDim2.fromScale(1, 1)
		pool.ImageColor3 = pal.a
		pool.ImageTransparency = 0.25
		p.pool = pool
		local light = Instance.new("PointLight")
		light.Color = pal.a
		light.Range = 24
		light.Brightness = 1.4
		light.Shadows = false
		local lightAt = Instance.new("Attachment")
		lightAt.Position = Vector3.new(0, -h / 2 + 2, -3)
		lightAt.Parent = p.anchor
		light.Parent = lightAt
		p.light = light

		-- the hum and its shimmer layer (one load attempt each; no retries on failure)
		local function loop(id: any, volume: number): Sound?
			if type(id) ~= "string" or id == "" then
				return nil
			end
			local s = Instance.new("Sound")
			s.SoundId = id
			s.Looped = true
			s.Volume = volume
			s.RollOffMode = Enum.RollOffMode.InverseTapered
			s.RollOffMinDistance = 12
			s.RollOffMaxDistance = 110
			s.Parent = p.anchor
			p.trove:Add(s)
			s:Play()
			return s
		end
		p.hum = loop(soundIds.hum, 0.3)
		p.shimmer = loop(soundIds.shimmer, 0.12)
		p.trove:Add(centreAttach)
		p.trove:Add(base)
		p.trove:Add(lightAt)
	end

	-- ------------------------------------------------------------------ plaque faces (per player)
	-- Built by hand from the pending sign spec (vault/design/ui/island-task4-signs.md, section 2;
	-- not approved). Every number is a PREVIEW placeholder (made up, not an economy number) and
	-- carries the PREVIEW tag. Nothing is pressable; the Peek area is reserved and left empty.
	local FONT = Font.fromName("FredokaOne")
	local CREAM = Color3.fromRGB(255, 246, 224)
	local INK = Color3.fromRGB(59, 42, 30) -- outline brown
	local NAVY = Color3.fromRGB(30, 42, 74)
	local GREEN = Color3.fromRGB(61, 190, 108)
	local MAGENTA = Color3.fromRGB(194, 24, 122)
	local TRACK = Color3.fromRGB(90, 64, 48)
	local PLANK = Color3.fromRGB(176, 132, 86)
	local INLAY_DARK = Color3.fromRGB(58, 63, 92) -- dark but visible (sign spec section 1)
	-- lit inlay colours (review M10: gold, warm amber, ice). Dusty and Summit use their WorldPalette
	-- swatches; Downtown uses its field's gold, because WorldPalette.PortalDowntown is still the
	-- old violet (reversible; a question for Adam)
	local LIT: { [string]: Color3 } = {
		Downtown = Color3.fromRGB(255, 214, 84),
		DustyHighway = Color3.fromRGB(255, 150, 60),
		SummitPass = Color3.fromRGB(110, 210, 255),
	}
	local WORLD_NAMES: { [string]: string } =
		{ Downtown = "DOWNTOWN", DustyHighway = "DUSTY HIGHWAY", SummitPass = "SUMMIT PASS" }
	local TITLE_STRIP: { [string]: Color3 } =
		{ DustyHighway = Color3.fromRGB(255, 150, 60), SummitPass = Color3.fromRGB(110, 210, 255) }
	type Row = { label: string, have: number, need: number, icon: string, fill: Color3 }
	local COIN = Color3.fromRGB(255, 200, 61)
	local CARS = Color3.fromRGB(110, 210, 255)
	-- PREVIEW rows (sign spec 2b): Summit Pass shows the same numbers, because no Summit values
	-- exist and none are invented
	local ROWS: { [string]: { Row } } = {
		DustyHighway = {
			{ label = "CASH", have = 1200, need = 5000, icon = "IconCoin", fill = COIN },
			{ label = "DOWNTOWN CARS", have = 2, need = 3, icon = "IconGarage", fill = CARS },
		},
		SummitPass = {
			{ label = "CASH", have = 1200, need = 5000, icon = "IconCoin", fill = COIN },
			{ label = "DUSTY HIGHWAY CARS", have = 2, need = 3, icon = "IconGarage", fill = CARS },
		},
	}
	local function text(parent: Instance, t: string, size: number, stroke: number, colour: Color3?): TextLabel
		local l = Instance.new("TextLabel")
		l.BackgroundTransparency = 1
		l.FontFace = FONT
		l.Text = t
		l.TextSize = size
		l.TextColor3 = colour or CREAM
		if stroke > 0 then
			local st = Instance.new("UIStroke")
			st.Color = INK
			st.Thickness = stroke
			st.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
			st.Parent = l
		end
		l.Parent = parent
		return l
	end
	local function rounded(f: GuiObject, r: number, stroke: number?, strokeColour: Color3?)
		local c = Instance.new("UICorner")
		c.CornerRadius = if r >= 1 then UDim.new(0, r) else UDim.new(r, 0)
		c.Parent = f
		if stroke then
			local st = Instance.new("UIStroke")
			st.Color = strokeColour or INK
			st.Thickness = stroke
			st.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
			st.Parent = f
		end
	end
	local function box(parent: Instance, x: number, y: number, w: number, h: number, colour: Color3): Frame
		local f = Instance.new("Frame")
		f.Position = UDim2.fromOffset(x, y)
		f.Size = UDim2.fromOffset(w, h)
		f.BackgroundColor3 = colour
		f.BorderSizePixel = 0
		f.Parent = parent
		return f
	end
	local function icon(parent: Instance, name: string, x: number, y: number, size: number): ImageLabel
		local i = Instance.new("ImageLabel")
		i.BackgroundTransparency = 1
		i.Image = tex(name)
		i.ScaleType = Enum.ScaleType.Fit
		i.Position = UDim2.fromOffset(x, y)
		i.Size = UDim2.fromOffset(size, size)
		i.ZIndex = 2
		i.Parent = parent
		return i
	end
	local function comma(n: number): string
		local s0 = tostring(math.floor(n))
		local out = s0:reverse():gsub("(%d%d%d)", "%1,"):reverse()
		return (out:gsub("^,", ""))
	end

	-- the requirement plaque's face: a 700 x 275 px canvas at 100 px per stud on the plaque's
	-- 7.0 x 2.75 face (the corridor-height plaque). Spec 2b's 800 x 400 layout re-cut to fit: every
	-- element kept (title, state pill, two rows of icon, label, PREVIEW tag, numbers, bar and tick
	-- slot), type about 0.75 of the spec's, and the Peek strip (from the plaque meta) left empty.
	type PeekRect = { x: number, y: number, w: number, h: number }
	local REQ_W, REQ_H = 700, 275
	local function requirementFace(p: Portal, gui: SurfaceGui, size: Vector2, peekRect: PeekRect)
		local canvas = Instance.new("Frame")
		canvas.Name = "Requirement"
		canvas.AnchorPoint = Vector2.new(0.5, 0.5)
		canvas.Position = UDim2.fromScale(0.5, 0.5)
		canvas.Size = UDim2.fromOffset(REQ_W, REQ_H)
		-- Texture hook: once plaque-requirement-bg-<world>.png is approved and uploaded (re-cut to
		-- this face), an ImageLabel with that id replaces this plank fill and the title strip.
		canvas.BackgroundColor3 = PLANK
		canvas.BorderSizePixel = 0
		rounded(canvas, 18, 6)
		local scale = Instance.new("UIScale")
		scale.Scale = math.min(size.X * 100 / REQ_W, size.Y * 100 / REQ_H)
		scale.Parent = canvas
		canvas.Parent = gui
		local strip = box(canvas, 0, 0, REQ_W, 56, TITLE_STRIP[p.world] or CREAM)
		rounded(strip, 18)
		box(canvas, 0, 38, REQ_W, 18, TITLE_STRIP[p.world] or CREAM)
		local title = text(canvas, "TO OPEN " .. (WORLD_NAMES[p.world] or p.world), 26, 2)
		title.Position = UDim2.fromOffset(16, 8)
		title.Size = UDim2.fromOffset(556, 40)
		title.TextXAlignment = Enum.TextXAlignment.Left
		title.ZIndex = 2
		local pill = box(canvas, 588, 11, 100, 34, INK)
		pill.ZIndex = 2
		rounded(pill, 17)
		local pt = text(pill, "LOCKED", 18, 0)
		pt.Size = UDim2.fromScale(1, 1)
		pt.ZIndex = 3
		for k, row in ROWS[p.world] or {} do
			local y = if k == 1 then 62 else 137
			local met = row.have >= row.need
			icon(canvas, row.icon, 10, y + 6, 52)
			local label = text(canvas, row.label, 21, 2)
			label.Position = UDim2.fromOffset(70, y)
			label.Size = UDim2.fromOffset(300, 28)
			label.TextXAlignment = Enum.TextXAlignment.Left
			-- the PREVIEW tag 6 px left of the numbers, whose right edge is at x 602
			local group = Instance.new("Frame")
			group.BackgroundTransparency = 1
			group.AnchorPoint = Vector2.new(1, 0)
			group.Position = UDim2.fromOffset(602, y)
			group.Size = UDim2.fromOffset(300, 28)
			local list = Instance.new("UIListLayout")
			list.FillDirection = Enum.FillDirection.Horizontal
			list.HorizontalAlignment = Enum.HorizontalAlignment.Right
			list.VerticalAlignment = Enum.VerticalAlignment.Center
			list.SortOrder = Enum.SortOrder.LayoutOrder
			list.Padding = UDim.new(0, 6)
			list.Parent = group
			group.Parent = canvas
			local tag = box(group, 0, 0, 0, 20, Color3.new(1, 1, 1))
			tag.AutomaticSize = Enum.AutomaticSize.X
			tag.LayoutOrder = 1
			rounded(tag, 5, 2, MAGENTA)
			local pad = Instance.new("UIPadding")
			pad.PaddingLeft = UDim.new(0, 6)
			pad.PaddingRight = UDim.new(0, 6)
			pad.Parent = tag
			local tt = text(tag, "PREVIEW", 13, 0, MAGENTA)
			tt.AutomaticSize = Enum.AutomaticSize.X
			tt.Size = UDim2.fromOffset(0, 20)
			tag:SetAttribute("Placeholder", "made-up value; real values need the agreed unlock contract")
			local numbers = text(group, comma(row.have) .. " / " .. comma(row.need), 21, 2)
			numbers.AutomaticSize = Enum.AutomaticSize.X
			numbers.Size = UDim2.fromOffset(0, 28)
			numbers.LayoutOrder = 2
			local track = box(canvas, 70, y + 31, 532, 28, TRACK)
			rounded(track, 14, 2)
			local frac = math.clamp(row.have / row.need, 0, 1)
			local fill = box(canvas, 73, y + 34, math.max(1, 526 * frac), 22, if met then GREEN else row.fill)
			fill.ZIndex = 2
			rounded(fill, 11)
			if met then
				icon(canvas, "IconTick", 626, y + 22, 46)
			else
				local slot = box(canvas, 630, y + 26, 38, 38, TRACK)
				rounded(slot, 0.5, 3, CREAM)
				local ring = slot:FindFirstChildOfClass("UIStroke")
				if ring then
					ring.Transparency = 0.5
				end
			end
		end
		-- reserved for a future Peek prompt (not built; never a button on the plaque)
		local peek = Instance.new("Frame")
		peek.Name = "PeekReserved"
		peek.BackgroundTransparency = 1
		peek.Position = UDim2.fromOffset(peekRect.x, peekRect.y)
		peek.Size = UDim2.fromOffset(peekRect.w, peekRect.h)
		peek:SetAttribute("Reserved", "Peek (future); leave empty")
		peek.Parent = canvas
	end

	-- the LOCKED plaque's face: LOCKED in navy at 2.5-stud capitals on the plaque's cream face
	local function lockedFace(gui: SurfaceGui)
		-- Texture hook: once plaque-locked.png is approved and uploaded, an ImageLabel with that id
		-- goes under this text.
		local l = text(gui, "LOCKED", math.min(100, math.floor(2.5 / 0.75 * gui.PixelsPerStud)), 0, NAVY)
		l.Size = UDim2.fromScale(1, 1)
	end

	-- ------------------------------------------------------------------ kit pieces
	local emblems = kit:FindFirstChild("Emblems")
	local function kitAttr(piece: string, key: string): any
		local t = templates[piece]
		return if t then t:GetAttribute(key) else nil
	end
	local function kitNumber(piece: string, key: string, default: number): number
		local v = kitAttr(piece, key)
		return if type(v) == "number" then v else default
	end
	local function kitPoint(piece: string, key: string, default: Vector3): Vector3
		local v = kitAttr(piece, "pt_" .. key)
		return if typeof(v) == "Vector3" then v else default
	end

	-- A thin transparent part whose Front face lies on a piece's recorded sign face (the manifest's
	-- centre, outward normal and up, in the piece frame), 0.03 proud of the mesh; its SurfaceGui
	-- goes on Face = Front.
	local function faceOf(piece: string, frame: CFrame, name: string, parent: Instance): (Part?, Vector2)
		local size = kitAttr(piece, "FaceSize")
		if typeof(size) ~= "Vector2" then
			return nil, Vector2.zero
		end
		local c = frame:PointToWorldSpace(kitPoint(piece, "sign_faces_1_centre", Vector3.zero))
		local n = frame:VectorToWorldSpace(kitPoint(piece, "sign_faces_1_normal", Vector3.zAxis)).Unit
		local u = frame:VectorToWorldSpace(kitPoint(piece, "sign_faces_1_up", Vector3.yAxis)).Unit
		local at = c + n * 0.005
		local part = Instance.new("Part")
		part.Name = "SignFace_" .. name
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.CastShadow = false
		part.Transparency = 1
		part.Size = Vector3.new(size.X, size.Y, 0.05)
		part.CFrame = CFrame.lookAt(at, at + n, u)
		part.Parent = parent
		return part, size
	end
	local function faceGui(part: Part, pps: number): SurfaceGui
		local g = Instance.new("SurfaceGui")
		g.Face = Enum.NormalId.Front
		g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		g.PixelsPerStud = pps
		g.LightInfluence = 1
		g.MaxDistance = 200
		g.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
		g.Parent = part
		return g
	end
	local function emblemOn(part: Part, size: Vector2, world: string)
		local template = emblems and emblems:FindFirstChild(world)
		if not (template and template:IsA("Frame")) then
			return
		end
		local g = faceGui(part, 60)
		local e = template:Clone()
		local s = Instance.new("UIScale")
		s.Scale = size.X * 60 / 256
		s.Parent = e
		e.Parent = g
	end

	-- Part-built lock pieces: the fallback while a mesh is only a session preview (which does not
	-- reach a playtest), each in the same frame as its mesh (the gates kit README, "Production").
	local STEEL = Color3.fromRGB(150, 158, 170)
	local IRON_HI = Color3.fromRGB(184, 192, 204)
	local GOLD = Color3.fromRGB(224, 176, 64)
	local STONE = Color3.fromRGB(154, 163, 174)
	local CYLINDER = Enum.PartType.Cylinder
	local function bit(parent: Instance, size: Vector3, cf: CFrame, colour: Color3, shape: Enum.PartType?): Part
		local b = Instance.new("Part")
		b.Anchored = true
		b.CanCollide = false
		b.CanQuery = false
		b.CanTouch = false
		b.Size = size
		b.CFrame = cf
		b.Color = colour
		b.Material = if colour == STEEL or colour == IRON_HI then Enum.Material.Metal else Enum.Material.SmoothPlastic
		b.TopSurface = Enum.SurfaceType.Smooth
		b.BottomSurface = Enum.SurfaceType.Smooth
		if shape then
			b.Shape = shape
		end
		b.Parent = parent
		return b
	end
	local function partPiece(name: string, cf: CFrame, parent: Instance): Instance?
		local alongZ = CFrame.Angles(0, math.pi / 2, 0) -- a cylinder's axis is X; this lays it along Z
		local alongY = CFrame.Angles(0, 0, math.pi / 2) -- and this stands it along Y
		local m = Instance.new("Model")
		m.Name = name
		m:SetAttribute("Build", "parts")
		if name == "GateChainRun" then
			-- five links along +X; the even ones face the plots (an oval of two sides and two ends),
			-- the odd ones are edge-on and read as one bar
			local pitch = kitNumber(name, "pitch", 2.2)
			for i = 0, kitNumber(name, "links", 5) - 1 do
				local at = cf * CFrame.new(i * pitch, 0, 0)
				if i % 2 == 0 then
					for _, y in { -0.51, 0.51 } do
						bit(m, Vector3.new(2.05, 0.5, 0.5), at * CFrame.new(0, y, 0), STEEL, CYLINDER)
					end
					for _, x in { -1.28, 1.28 } do
						bit(m, Vector3.new(1.02, 0.5, 0.5), at * CFrame.new(x, 0, 0) * alongY, STEEL, CYLINDER)
					end
				else
					bit(m, Vector3.new(3.05, 0.5, 0.5), at, IRON_HI, CYLINDER)
				end
			end
		elseif name == "GateChainWrap" then
			-- an iron band round the 3 x 3 neck and the front lug the X chain hooks on
			bit(m, Vector3.new(3.4, 1.2, 3.4), cf, STEEL)
			local lug = cf * CFrame.new(kitPoint(name, "lug", Vector3.new(0, 0, 2.35)))
			for _, y in { -0.45, 0.45 } do
				bit(m, Vector3.new(1.4, 0.4, 0.4), lug * CFrame.new(0, y, 0), IRON_HI, CYLINDER)
			end
			for _, x in { -0.7, 0.7 } do
				bit(m, Vector3.new(0.9, 0.4, 0.4), lug * CFrame.new(x, 0, 0) * alongY, IRON_HI, CYLINDER)
			end
		elseif name == "GatePadlockBody" then
			-- front at the emblem face plane (1.53)
			bit(m, Vector3.new(7, 6, 2.73), cf * CFrame.new(0, 0, 0.165), GOLD)
			bit(
				m,
				Vector3.new(0.6, 1.3, 0.05),
				cf * CFrame.new(kitNumber(name, "keyhole_centre_1", 0), kitNumber(name, "keyhole_centre_2", -2.1), 1.55),
				Color3.fromRGB(40, 30, 24)
			)
		elseif name == "GatePadlockShackle" then
			-- origin at the bottom of the left leg (the hinge); the right leg sits leg_gap along X
			local gap = kitNumber(name, "leg_gap", 4.6)
			local section = kitNumber(name, "section", 0.84)
			local rightBottom = kitNumber(name, "right_leg_bottom", 0.3)
			local legTop = kitNumber(name, "height", 3.6) - section / 2
			local s = Vector3.new(0, section, section)
			bit(m, s + Vector3.new(legTop, 0, 0), cf * CFrame.new(0, legTop / 2, 0) * alongY, STEEL, CYLINDER)
			bit(
				m,
				s + Vector3.new(legTop - rightBottom, 0, 0),
				cf * CFrame.new(gap, (legTop + rightBottom) / 2, 0) * alongY,
				STEEL,
				CYLINDER
			)
			bit(m, s + Vector3.new(gap + section, 0, 0), cf * CFrame.new(gap / 2, legTop, 0), STEEL, CYLINDER)
		elseif name == "GateLockedPlaque" then
			bit(m, Vector3.new(15.4, 4.4, 0.5), cf, NAVY)
			bit(m, Vector3.new(14.4, 3.4, 0.06), cf * CFrame.new(0, 0, 0.28), CREAM)
			for k, x in { -2.4, 2.4 } do
				local ring = kitPoint(name, "hang_rings_" .. k, Vector3.new(x, 2.42, 0))
				bit(m, Vector3.new(0.25, 0.9, 0.9), cf * CFrame.new(ring) * alongZ, STEEL, CYLINDER)
			end
		elseif name == "GateRequirementPlaque" then
			-- a low stone foot, a short cream post and the tilted board under the face (top under 3)
			local c = kitPoint(name, "sign_faces_1_centre", Vector3.new(0, 1.765, 0.193))
			local n = kitPoint(name, "sign_faces_1_normal", Vector3.new(0, 0.574, 0.819))
			local u = kitPoint(name, "sign_faces_1_up", Vector3.new(0, 0.819, -0.574))
			-- the manifest's board point is (width, thickness, -length) in Roblox axes
			local board = kitPoint(name, "board", Vector3.new(7.4, 0.35, -3.05))
			local thick = math.abs(board.Y)
			local at = c - n * (thick / 2)
			local low = kitNumber(name, "board_low_edge_z", 0.482)
			bit(m, Vector3.new(3, 0.3, 1.8), cf * CFrame.new(0, 0.15, at.Z), STONE)
			bit(m, Vector3.new(0.9, math.max(0.1, low), 0.7), cf * CFrame.new(0, 0.3 + low / 2 - 0.15, at.Z), CREAM)
			bit(m, Vector3.new(math.abs(board.X), math.abs(board.Z), thick), cf * CFrame.lookAt(at, at + n, u), NAVY)
		else
			m:Destroy()
			return nil
		end
		m.Parent = parent
		return m
	end
	local function partCount(i: Instance): number
		local n = if i:IsA("BasePart") then 1 else 0
		for _, d in i:GetDescendants() do
			if d:IsA("BasePart") then
				n += 1
			end
		end
		return n
	end

	local function placePiece(name: string, cf: CFrame, parent: Instance): Instance?
		local t = templates[name]
		if
			not t
			or t:GetAttribute("Source") == "preview"
			or (RunService:IsStudio() and player:GetAttribute("Lane3PortalLockParts") == true)
		then
			return partPiece(name, cf, parent)
		end
		local part = t:Clone()
		part.Transparency = 0
		part.CastShadow = true
		part.CanCollide = false
		part.CanQuery = false
		part.CFrame = cf * offsets[name]
		part.Parent = parent
		return part
	end

	-- ------------------------------------------------------------------ the gate (shared build)
	-- The gate meshes are built for everyone (Environment/PortalGates). This client only colours
	-- the inlay bands, and in a playtest, while the gate meshes are session previews (blank in
	-- Play), shows the gate's part stand-in and its part inlay strips instead.
	local function setupGate(p: Portal)
		local gate = rig:FindFirstChild(p.world .. "Gate")
		if not (gate and gate:IsA("Model")) then
			return
		end
		p.gate = gate
		local fallback = gate:GetAttribute("Source") == "preview"
		local standIn = gate:FindFirstChild("StandIn")
		if fallback and standIn then
			-- a preview MeshPart reaches Play without its mesh and would draw as a solid box over
			-- the whole gate, opening included: hide the gate meshes and show the stand-in
			-- (plinths, columns, crest and medallion only; nothing crosses the opening)
			for _, d in gate:GetChildren() do
				if d:IsA("MeshPart") then
					d.Transparency = 1
					d.CastShadow = false
				end
			end
			for _, d in standIn:GetChildren() do
				if d:IsA("BasePart") then
					d.Transparency = 0
					d.CastShadow = true
				end
			end
		end
		local holder = if fallback then gate:FindFirstChild("InlayStrips") else gate
		for _, d in if holder then holder:GetChildren() else {} do
			local band = d:GetAttribute("Band")
			if d:IsA("BasePart") and type(band) == "number" and p.bands[band] then
				table.insert(p.bands[band], d)
			end
		end
	end
	local function paint(part: BasePart, colour: Color3, lit: boolean)
		if part:IsA("MeshPart") then
			part.TextureID = "" -- the band's own colour, not the palette swatch
		end
		part.Transparency = 0
		part.Material = if lit then Enum.Material.Neon else Enum.Material.SmoothPlastic
		part.Color = colour
	end
	-- Inlay bands: dark while locked, lit in the World colour when open. Lighting up runs bottom to
	-- top (Low, Mid, High) over about 1.1 s; under reduced motion all three light together.
	local function setBands(p: Portal, lit: boolean, animate: boolean)
		if p.bandTrove then
			p.trove:Remove(p.bandTrove)
		end
		local bt = p.trove:Extend()
		p.bandTrove = bt
		local colour = LIT[p.world] or LIT.Downtown
		if not (lit and animate) then
			for _, list in p.bands do
				for _, part in list do
					paint(part, if lit then colour else INLAY_DARK, lit)
				end
			end
			return
		end
		local calm = reducedMotion()
		for i, list in p.bands do
			bt:Add(task.delay(if calm then 0 else 0.3 + 0.35 * (i - 1), function()
				for _, part in list do
					paint(part, INLAY_DARK, true)
					local tw = TweenService:Create(
						part,
						TweenInfo.new(if calm then 0.5 else 0.4, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
						{ Color = colour }
					)
					bt:Add(tw, "Cancel")
					tw:Play()
				end
			end))
		end
	end

	-- ------------------------------------------------------------------ the lock (per player)
	local function clearLock(p: Portal)
		local lt = p.lockTrove
		p.lockTrove = nil
		p.lockModel = nil
		if lt then
			-- everything of the old lock, a fading one included, goes now: never two lock models
			p.trove:Remove(lt)
		end
	end

	type Diagonal = { a: string, b: string, offset: number }
	-- the X: left high to right low, and left low to right high set 0.7 toward the plots so the two
	-- pass each other at the crossing (the gates README, "Key meta")
	-- The gate stands its Setback behind the field plane, so the X, the padlock and the LOCKED
	-- plaque are brought this far in front of the field plane (toward the plots), clear of the
	-- field's frontmost layer (1.6 in front), so they read across the field. Tunable, reversible.
	local LOCK_AHEAD = 2
	local DIAGONALS: { Diagonal } = {
		{ a = "left_high", b = "right_low", offset = 0 },
		{ a = "left_low", b = "right_high", offset = 0.7 },
	}

	local function buildLock(p: Portal)
		clearLock(p)
		local gate = p.gate
		if not (gate and gate:GetAttribute("Chained") == true) then
			return -- Downtown is never chained
		end
		local gateFrame = gate:GetAttribute("Origin")
		if typeof(gateFrame) ~= "CFrame" then
			return
		end
		local lt = p.trove:Extend()
		p.lockTrove = lt
		local model = lt:Add(Instance.new("Model"))
		model.Name = p.world .. "Lock"
		local function group(name: string): Model
			local g = Instance.new("Model")
			g.Name = name
			g.Parent = model
			return g
		end
		local chains, padlock, shackle, plaque =
			group("Chains"), group("Padlock"), group("Shackle"), group("RequirementPlaque")
		local front = gateFrame:VectorToWorldSpace(Vector3.zAxis) -- the gate front, toward the plots
		local setback = gate:GetAttribute("Setback")
		-- the gate-frame z of the field plane, and of the X's plane in front of it
		local fieldZ = if type(setback) == "number" then setback else 0
		local function localPoint(key: string): Vector3?
			local v = gate:GetAttribute("pt_" .. key)
			return if typeof(v) == "Vector3" then v else nil
		end

		-- a wrap on each chain neck, its lug to the front
		for _, key in { "left_low", "left_high", "right_low", "right_high" } do
			local at = gate:GetAttribute("pt_chain_wraps_" .. key)
			if typeof(at) == "Vector3" then
				placePiece("GateChainWrap", gateFrame * CFrame.new(at), chains)
			end
		end
		-- each diagonal: whole pre-linked runs (run_pitch apart), centred between its two anchors.
		-- The end runs leave the wrap lugs on the columns and angle forward; the middle runs lie in
		-- the X's plane, LOCK_AHEAD in front of the field plane
		local runPitch = kitNumber("GateChainRun", "run_pitch", 11)
		local runLength = kitPoint("GateChainRun", "last_link_centre", Vector3.new(8.8, 0, 0)).X
		local runs = 0
		local crossZ = fieldZ + LOCK_AHEAD
		for _, d in DIAGONALS do
			local la, lb = localPoint("chain_anchors_" .. d.a), localPoint("chain_anchors_" .. d.b)
			if la and lb then
				local a, b = gateFrame:PointToWorldSpace(la), gateFrame:PointToWorldSpace(lb)
				local ahead = math.max(0, fieldZ + LOCK_AHEAD + d.offset - la.Z)
				crossZ = math.max(crossZ, la.Z)
				local dir = (b - a).Unit
				local length = (b - a).Magnitude
				local count = math.max(1, math.floor((length - runLength) / runPitch) + 1)
				local start = (length - ((count - 1) * runPitch + runLength)) / 2
				local finish = start + (count - 1) * runPitch + runLength
				local function along(s0: number): Vector3
					local ramp = math.clamp(math.min((s0 - start) / runLength, (finish - s0) / runLength), 0, 1)
					return a + dir * s0 + front * (ahead * ramp)
				end
				for r = 0, count - 1 do
					local s0 = start + r * runPitch
					local p0, p1 = along(s0), along(s0 + runLength)
					local runDir = (p1 - p0).Unit
					local up = front:Cross(runDir).Unit -- the run's links stay square to the gate front
					placePiece("GateChainRun", CFrame.fromMatrix(p0, runDir, up), chains)
					runs += 1
				end
			end
		end
		-- the padlock hangs from the crossing (its shackle between the two chains), the LOCKED plaque
		-- from the padlock's eyes (each hang ring 0.5 below its eye)
		local crossLocal = localPoint("chain_cross")
		if crossLocal then
			-- between the two chains' middle runs (0.35 is half their 0.7 spacing)
			local cross = gateFrame:PointToWorldSpace(Vector3.new(crossLocal.X, crossLocal.Y, crossZ + 0.35))
			local below = kitNumber("GatePadlockBody", "assembly_body_centre_below_cross", 4.5)
			local body = CFrame.new(cross - Vector3.new(0, below, 0)) * gateFrame.Rotation
			placePiece("GatePadlockBody", body, padlock)
			local face, size = faceOf("GatePadlockBody", body, "PadlockEmblem", padlock)
			if face then
				emblemOn(face, size, p.world)
			end
			local hinge = body
				* CFrame.new(
					kitNumber("GatePadlockBody", "shackle_seat_1", -2.3),
					kitNumber("GatePadlockBody", "shackle_seat_2", 2.4),
					0
				)
			placePiece("GatePadlockShackle", hinge, shackle)
			shackle.WorldPivot = hinge
			local eyeY = kitPoint("GatePadlockBody", "plaque_eyes_1", Vector3.new(-2.4, -2.925, 0)).Y
			local ringY = kitPoint("GateLockedPlaque", "hang_rings_1", Vector3.new(-2.4, 2.42, 0)).Y
			local board = body * CFrame.new(0, eyeY - 0.5 - ringY, 0)
			placePiece("GateLockedPlaque", board, padlock)
			local lockedPart = faceOf("GateLockedPlaque", board, "LockedText", padlock)
			if lockedPart then
				lockedFace(faceGui(lockedPart, 25))
			end
		end
		-- the requirement plaque on its short pedestal, beside the column (PortalGates)
		local base = gate:GetAttribute("PlaqueBase")
		if typeof(base) == "CFrame" then
			placePiece("GateRequirementPlaque", base, plaque)
			local reqPart, reqSize = faceOf("GateRequirementPlaque", base, "RequirementFace", plaque)
			if reqPart then
				local piece = "GateRequirementPlaque"
				requirementFace(p, faceGui(reqPart, 100), reqSize, {
					x = kitNumber(piece, "peek_reserved_canvas_px_x", 10),
					y = kitNumber(piece, "peek_reserved_canvas_px_y", 213),
					w = kitNumber(piece, "peek_reserved_canvas_px_w", 680),
					h = kitNumber(piece, "peek_reserved_canvas_px_h", 62),
				})
			end
		end
		model:SetAttribute("Runs", runs)
		model:SetAttribute("Parts", partCount(model))
		local built = "meshes"
		for _, d in model:GetDescendants() do
			if d:GetAttribute("Build") == "parts" then
				built = "parts"
				break
			end
		end
		model:SetAttribute("Build", built)
		model:SetAttribute("PreviewState", PortalPreviewState.Source)
		model.Parent = liveFolder
		p.lockModel = model
	end

	-- fades every GUI layer under `root`
	local function fadeGuis(root: Instance, duration: number, lt: Trove.Trove)
		local info = TweenInfo.new(duration, Enum.EasingStyle.Sine, Enum.EasingDirection.In)
		local function go(inst: Instance, goal: { [string]: any })
			local tw = TweenService:Create(inst, info, goal)
			lt:Add(tw, "Cancel")
			tw:Play()
		end
		for _, d in root:GetDescendants() do
			if d:IsA("TextLabel") then
				go(d, { TextTransparency = 1, BackgroundTransparency = 1 })
			elseif d:IsA("ImageLabel") then
				go(d, { ImageTransparency = 1, BackgroundTransparency = 1 })
			elseif d:IsA("Frame") then
				go(d, { BackgroundTransparency = 1 })
			elseif d:IsA("UIStroke") then
				go(d, { Transparency = 1 })
			end
		end
	end
	-- moves every part of a group down by `drop` while it fades (drop 0: a fade in place)
	local function sink(group: Instance, drop: number, duration: number, lt: Trove.Trove, stagger: number?)
		local i = 0
		for _, d in group:GetDescendants() do
			if d:IsA("BasePart") then
				i += 1
				local info = TweenInfo.new(
					duration,
					if drop > 0 then Enum.EasingStyle.Quad else Enum.EasingStyle.Sine,
					Enum.EasingDirection.In,
					0,
					false,
					(stagger or 0) * (i % 6)
				)
				local tw =
					TweenService:Create(d, info, { CFrame = d.CFrame - Vector3.new(0, drop, 0), Transparency = 1 })
				lt:Add(tw, "Cancel")
				tw:Play()
			end
		end
	end

	-- The preview unlock: the shackle lifts and swings open, the padlock and the LOCKED plaque drop
	-- and fade, the chains fall a little and fade, the requirement plaque sinks into the ground,
	-- the inlays light bottom to top and one soft burst plays (about 1.5 s). Reduced motion: a
	-- short cross-fade with nothing moving, the inlays lit together, no burst. A relock at any
	-- point removes the fading lock at once (clearLock) before the new one is built.
	local function unlock(p: Portal)
		setBands(p, true, true)
		local model, lt = p.lockModel, p.lockTrove
		p.lockModel = nil
		if not (model and lt) then
			return
		end
		local calm = reducedMotion()
		if calm then
			sink(model, 0, 0.5, lt)
			fadeGuis(model, 0.4, lt)
		else
			local shackle = model:FindFirstChild("Shackle")
			if shackle and shackle:IsA("Model") then
				-- the shackle turns as one through a pivot value: up out of its socket, then about
				-- the left leg toward the plots
				local hinge = shackle:GetPivot()
				local lifted = hinge * CFrame.new(0, kitNumber("GatePadlockShackle", "lift_to_open", 0.35), 0)
				local v = lt:Add(Instance.new("CFrameValue"))
				v.Value = hinge
				lt:Connect(v.Changed, function(value: any)
					if shackle.Parent then
						shackle:PivotTo(value)
					end
				end)
				local up = TweenService:Create(
					v,
					TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
					{ Value = lifted }
				)
				local swing = TweenService:Create(
					v,
					TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
					{ Value = lifted * CFrame.Angles(0, math.rad(-100), 0) }
				)
				lt:Add(up, "Cancel")
				lt:Add(swing, "Cancel")
				lt:Connect(up.Completed, function(state)
					if state == Enum.PlaybackState.Completed then
						swing:Play()
					end
				end)
				up:Play()
			end
			lt:Add(task.delay(0.4, function()
				local plaque = model:FindFirstChild("RequirementPlaque")
				if plaque then
					sink(plaque, 5.2, 0.8, lt)
					fadeGuis(plaque, 0.4, lt)
				end
			end))
			lt:Add(task.delay(0.6, function()
				for _, name in { "Padlock", "Shackle" } do
					local g = model:FindFirstChild(name)
					if g then
						sink(g, 3, 0.6, lt)
						fadeGuis(g, 0.35, lt)
					end
				end
				local chains = model:FindFirstChild("Chains")
				if chains then
					sink(chains, 2.5, 0.6, lt, 0.05)
				end
			end))
			lt:Add(task.delay(0.9, function()
				local burst = p.emitters.Burst
				if burst and burst.Parent then
					burst:Emit(36)
				end
			end))
		end
		lt:Add(task.delay(if calm then 0.7 else 1.7, function()
			if p.lockTrove == lt then
				p.lockTrove = nil
			end
			p.trove:Remove(lt)
		end))
	end

	-- ------------------------------------------------------------------ portals from the rig
	for _, anchor in rig:GetChildren() do
		if
			anchor:IsA("BasePart")
			and type(anchor:GetAttribute("World")) == "string"
			and anchor:GetAttribute("Width")
		then
			local world = anchor:GetAttribute("World") :: string
			local p: Portal = {
				world = world,
				anchor = anchor,
				palette = PALETTES[world] or PALETTES.Downtown,
				trove = trove:Extend(),
				level = 0,
				lock = if PortalPreviewState.isLocked(world) then 1 else 0,
				locked = PortalPreviewState.isLocked(world),
				guis = {},
				layers = {},
				spinHost = anchor,
				emitters = {},
				beams = {},
				light = Instance.new("PointLight"),
				pool = nil,
				hum = nil,
				shimmer = nil,
				lockModel = nil,
				lockTrove = nil,
				nextBurst = os.clock() + 8,
				angle = 0,
				resting = false,
				gate = nil,
				bands = { {}, {}, {} },
				bandTrove = nil,
			}
			buildField(p)
			setupGate(p)
			setBands(p, not p.locked, false)
			if p.locked then
				buildLock(p)
			end
			table.insert(portals, p)
		end
	end
	trove:Add(PortalPreviewState.onChanged(function(world)
		for _, p in portals do
			if p.world == world then
				local now = PortalPreviewState.isLocked(world)
				if now ~= p.locked then
					p.locked = now
					if now then
						buildLock(p)
						setBands(p, false, false)
					else
						unlock(p)
					end
				end
			end
		end
	end))

	-- ------------------------------------------------------------------ animation
	local started = os.clock()
	local lastFar = 0
	trove:Connect(RunService.RenderStepped, function(dt)
		local now = os.clock()
		local t = now - started
		local camera = Workspace.CurrentCamera
		if not camera then
			return
		end
		local calm = reducedMotion()
		local character = player.Character
		local rootPart = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local farTick = now - lastFar > 0.25
		if farTick then
			lastFar = now
		end
		for _, p in portals do
			local centre = p.anchor.Position
			-- rendering budget by the camera
			local camDist = (camera.CFrame.Position - centre).Magnitude
			local _, onScreen = camera:WorldToViewportPoint(centre)
			local rest = camDist > CAMERA_BUDGET or (not onScreen and camDist > 40)
			-- presentation level by the character's distance (never the free camera)
			local target = 0
			if rootPart then
				local d = ((rootPart.Position - centre) * Vector3.new(1, 0, 1)).Magnitude
				target = 1 - smooth((d - NEAR) / (FAR - NEAR))
			end
			local k = 1 - math.exp(-dt / EASE)
			p.level += (target - p.level) * k
			local lockTarget = if p.locked then 1 else 0
			p.lock += (lockTarget - p.lock) * (1 - math.exp(-dt / 0.5))
			if rest then
				if not p.resting then
					p.resting = true
					for _, e in p.emitters do
						e.Enabled = false
					end
				end
				if not farTick then
					continue
				end
			elseif p.resting then
				p.resting = false
				for _, e in p.emitters do
					e.Enabled = true
				end
			end
			local L = p.level * (1 - 0.6 * p.lock)
			-- seen almost edge-on, the flat layers fade out (no bright sliver); the glows, the aura
			-- particles and the beams carry the side view
			local toCam = (camera.CFrame.Position - centre).Unit
			local facing = math.abs(toCam:Dot(p.anchor.CFrame.LookVector))
			local fade = smooth((facing - 0.12) / 0.33)
			if farTick then
				-- readable in tests: the eased presentation level (0 idle, 1 strongest) on this client
				p.anchor:SetAttribute("Level", math.round(p.level * 100) / 100)
			end
			local lock = p.lock
			local speed = (if calm then 0.18 else 1) * (1 - 0.6 * lock) * (1 + 0.7 * L)
			p.angle += dt * speed
			local breathe = if calm
				then 0.5 + 0.5 * math.sin(t * 0.6)
				else 0.5 + 0.5 * math.sin(t * 1.3) * (0.7 + 0.3 * math.sin(t * 0.37))
			local pal = p.palette
			local function tint(c: Color3): Color3
				return c:Lerp(lockedColour(c), lock)
			end
			for _, g in p.guis do
				if g:GetAttribute("Unlit") then
					g.Brightness = fade
				else
					g.Brightness = (1.5 + 1.3 * L + 0.2 * breathe) * (1 - 0.4 * lock) * fade
				end
				g.Enabled = fade > 0.02
			end
			for _, img in p.layers.swirlA or {} do
				img.Rotation = (p.angle * 14) % 360
				img.ImageColor3 = tint(pal.a)
			end
			for _, img in p.layers.swirlB or {} do
				img.Rotation = (-p.angle * 22) % 360
				img.ImageColor3 = tint(pal.b)
			end
			-- the inflow rings shrink from the edge to the core and fade at both ends
			local fwPx = (p.anchor:GetAttribute("Width") :: number) * PPS
			for _, img in p.layers.inflow or {} do
				local u = (p.angle * 0.22 + (img:GetAttribute("Phase") :: number)) % 1
				local size = fwPx * (1.15 - 0.95 * u)
				img.Size = UDim2.fromOffset(size, size * 1.35)
				img.Rotation = (-p.angle * 30 - u * 90) % 360
				img.ImageTransparency = 1 - (0.2 + 0.6 * L) * math.sin(math.pi * u) * (1 - 0.6 * lock)
				img.ImageColor3 = tint(pal.a:Lerp(pal.core, 0.3))
			end
			for _, img in p.layers.band or {} do
				img.ImageColor3 = tint(pal.band)
				img.ImageTransparency = 0.15 + 0.3 * lock
			end
			for _, img in p.layers.tunnel or {} do
				img.Rotation = (-p.angle * 40) % 360
				img.ImageColor3 = tint(pal.depth)
			end
			for _, img in p.layers.accent or {} do
				img.Rotation = (p.angle * 31) % 360
				img.ImageTransparency = 0.3 + 0.3 * lock + 0.1 * breathe - 0.1 * L
				img.ImageColor3 = tint(pal.accent)
			end
			-- the cloudy bodies sway a few degrees and drift, never spin (a spinning oval would
			-- read as a turning card)
			for i, img in p.layers.cloudA or {} do
				local sway = math.sin(p.angle * 0.35 + i)
				img.Rotation = 6 * sway
				img.Position = UDim2.new(0.5, 10 * math.sin(p.angle * 0.23), 0.5, 8 * math.cos(p.angle * 0.19))
				img.ImageColor3 = tint(pal.depth:Lerp(pal.b, 0.55))
			end
			for i, img in p.layers.cloudB or {} do
				local sway = math.sin(-p.angle * 0.41 + i * 2)
				img.Rotation = 7 * sway
				img.Position = UDim2.new(0.5, -12 * math.sin(p.angle * 0.29), 0.5, -9 * math.cos(p.angle * 0.17))
				img.ImageTransparency = 0.5 + 0.25 * lock + 0.1 * (1 - breathe)
				img.ImageColor3 = tint(pal.b:Lerp(pal.a, 0.5))
			end
			for _, img in p.layers.sheen or {} do
				img.Position = UDim2.new(0.5, 26 * math.sin(p.angle * 0.5), 0.46, 20 * math.sin(p.angle * 0.31))
				img.ImageTransparency = 0.5 + 0.35 * lock + 0.15 * (1 - breathe)
				img.ImageColor3 = tint(pal.core)
			end
			for _, img in p.layers.core or {} do
				local s = 0.2 + 0.05 * L + 0.03 * breathe
				local fw = (p.anchor:GetAttribute("Width") :: number) * PPS
				img.Size = UDim2.fromOffset(fw * s, fw * s)
				img.ImageTransparency = 0.08 + 0.35 * lock - 0.06 * L
				img.ImageColor3 = tint(pal.core)
			end
			for _, img in p.layers.depth or {} do
				img.ImageColor3 = tint(pal.depth)
				-- a locked field stays energy, not a dark hole: its depth thins out
				img.ImageTransparency = 0.05 + 0.35 * lock
			end
			for _, img in p.layers.aura or {} do
				img.ImageTransparency = 0.78 - 0.42 * L - 0.06 * breathe + 0.15 * lock
				img.ImageColor3 = tint(pal.b)
			end
			-- the particle host turns, so motes locked to it swirl round the centre
			p.spinHost.CFrame = p.anchor.CFrame * CFrame.Angles(0, 0, -p.angle * 0.6)
			local rateScale = (0.4 + 2.2 * L) * (if calm then 0.4 else 1) * (1 - 0.75 * lock)
			for name, e in p.emitters do
				local base = e:GetAttribute("BaseRate")
				if type(base) == "number" and name ~= "Burst" then
					e.Rate = base * rateScale
				end
				if name ~= "Burst" then
					e.Color = if name == "Sparkles"
						then ColorSequence.new(tint(pal.spark), tint(pal.accent))
						elseif name == "Body" then ColorSequence.new(tint(pal.a), tint(pal.b))
						else ColorSequence.new(tint(if name == "Embers" then pal.b else pal.spark))
				end
			end
			local farWiden = math.clamp(camDist / 90, 1, 3.2)
			for _, b in p.beams do
				b.Enabled = lock < 0.5
				b.Width0 = (b:GetAttribute("BaseWidth0") :: number) * farWiden
				b.Width1 = (b:GetAttribute("BaseWidth1") :: number) * farWiden
				b.Transparency = NumberSequence.new(0.62 - 0.2 * L - 0.08 * breathe, 1)
			end
			if p.pool then
				p.pool.ImageTransparency = 0.35 - 0.2 * L + 0.3 * lock
				p.pool.ImageColor3 = tint(pal.a)
			end
			p.light.Brightness = (1 + 1.8 * L) * (1 - 0.6 * lock)
			p.light.Color = tint(pal.a)
			if p.hum then
				p.hum.Volume = (0.22 + 0.4 * L) * (1 - 0.5 * lock)
				p.hum.PlaybackSpeed = 1 - 0.15 * lock
			end
			if p.shimmer then
				p.shimmer.Volume = (0.06 + 0.16 * L) * (1 - lock)
			end
			-- an occasional soft outward burst (open portals only, never under reduced motion)
			if now > p.nextBurst then
				p.nextBurst = now + 9 + math.random() * 7
				if not calm and lock < 0.5 and not rest then
					p.emitters.Burst:Emit(math.floor(10 + 14 * L))
				end
			end
		end
	end)
end

local current: Trove.Trove? = nil
local function attach(root: Instance)
	if current then
		current:Destroy()
	end
	local trove = Trove.new()
	current = trove
	trove:Add(task.spawn(function()
		run(trove, root:WaitForChild("Portals"))
	end))
	trove:Connect(root.AncestryChanged, function()
		if not root:IsDescendantOf(Workspace) then
			trove:Destroy()
			if current == trove then
				current = nil
			end
		end
	end)
end

local existing = Workspace:FindFirstChild(ROOT_NAME)
if existing then
	attach(existing)
end
Workspace.ChildAdded:Connect(function(child)
	if child.Name == ROOT_NAME then
		attach(child)
	end
end)
