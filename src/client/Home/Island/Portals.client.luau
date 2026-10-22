--!strict
-- Island World portals (Lane 3, client presentation only). Each portal is a frameless energy
-- field about 20 x 30 studs floating over a soft pool of coloured light (no arch, frame or
-- surround). Built on this client from the shared rig (Lane3_IslandEnvironment.Portals):
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
-- no beams or bursts, sparse particles, two crossing chains, a padlock and the requirement sign
-- in its locked state. Unlocking (preview) opens the padlock, lets the chains fall and fade,
-- brightens the field and plays one burst; locking again rebuilds the lock cleanly. Nothing here
-- moves the player, changes physics or touches shared state.

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
	lockModel: Model?,
	lockTrove: Trove.Trove?,
	nextBurst: number,
	angle: number,
	resting: boolean,
	sign: BasePart?,
	signGuis: { SurfaceGui },
	signTrove: Trove.Trove?,
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

	-- the requirement sign's faces (per player: LOCKED or READY!), built by hand from the Figma
	-- spec (vault/design/ui/portal-sign.md, frames 8:411 and 8:448). Every number is a PREVIEW
	-- placeholder (made-up values, not economy numbers) and carries the PREVIEW tag. Nothing on
	-- the sign is pressable; room for a future Peek prompt is left in front of it.
	local FONT = Font.fromName("FredokaOne")
	local CREAM = Color3.fromRGB(255, 246, 224)
	local INK = Color3.fromRGB(59, 42, 30)
	local GREEN = Color3.fromRGB(61, 190, 108)
	local NAMES = { Downtown = "DOWNTOWN", DustyHighway = "DUSTY HIGHWAY", SummitPass = "SUMMIT PASS" }
	local BADGES = {
		Downtown = Color3.fromRGB(186, 92, 255),
		DustyHighway = Color3.fromRGB(255, 150, 60),
		SummitPass = Color3.fromRGB(110, 210, 255),
	}
	-- preview rows: { label, have, need } (made up; the sign shows them with the PREVIEW tag)
	local ROWS: { [string]: { { any } } } = {
		DustyHighway = { { "CASH", 1200, 5000, "IconCoin" }, { "DOWNTOWN CARS", 2, 3, "IconGarage" } },
		SummitPass = { { "CASH", 3100, 20000, "IconCoin" }, { "DUSTY CARS", 0, 3, "IconGarage" } },
	}
	local function text(parent: Instance, t: string, size: number, stroke: number, colour: Color3?): TextLabel
		local l = Instance.new("TextLabel")
		l.BackgroundTransparency = 1
		l.FontFace = FONT
		l.Text = t
		l.TextSize = size
		l.TextColor3 = colour or CREAM
		local st = Instance.new("UIStroke")
		st.Color = INK
		st.Thickness = stroke
		st.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
		st.Parent = l
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
	-- one plank's canvas: the spec's 560 x 120 px, scaled uniformly onto the kit's 5.5 x 1.1 face
	local function plank(p: Portal, k: number, st: Trove.Trove): Frame?
		local sign = p.sign
		local at = sign and sign:FindFirstChild("Plank" .. k) :: Attachment?
		if not (sign and at) then
			return nil
		end
		local w, h = at:GetAttribute("Width") :: number, at:GetAttribute("Height") :: number
		local face = Instance.new("Part")
		face.Name = p.world .. "SignPlank" .. k
		face.Anchored = true
		face.CanCollide = false
		face.CanQuery = false
		face.CanTouch = false
		face.CastShadow = false
		face.Transparency = 1
		face.Size = Vector3.new(w, h, 0.02)
		face.CFrame = at.WorldCFrame
		face.Parent = liveFolder
		st:Add(face)
		local g = Instance.new("SurfaceGui")
		-- the attachment's +Z faces the plots: the part's Back face
		g.Face = Enum.NormalId.Back
		g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		g.PixelsPerStud = 100
		g.LightInfluence = 1
		g.MaxDistance = 200
		g.Parent = face
		local canvas = Instance.new("Frame")
		canvas.BackgroundTransparency = 1
		canvas.AnchorPoint = Vector2.new(0.5, 0.5)
		canvas.Position = UDim2.fromScale(0.5, 0.5)
		canvas.Size = UDim2.fromOffset(560, 120)
		local scale = Instance.new("UIScale")
		scale.Scale = math.min(w * 100 / 560, h * 100 / 120)
		scale.Parent = canvas
		canvas.Parent = g
		return canvas
	end
	local function buildSignFaces(p: Portal)
		if p.signTrove then
			p.trove:Remove(p.signTrove)
		end
		local st = p.trove:Extend()
		p.signTrove = st
		local sign = rig:FindFirstChild(p.world .. "Sign")
		if not (sign and sign:IsA("BasePart")) then
			return
		end
		p.sign = sign
		local locked = p.locked
		-- plank 1: badge, World name, state pill
		local c1 = plank(p, 1, st)
		if c1 then
			local badge = box(c1, 12, 12, 96, 96, BADGES[p.world] or BADGES.Downtown)
			rounded(badge, 0.5, 4)
			icon(c1, if locked then "IconLock" else "IconPortal", 22, 22, 76)
			local name = text(c1, NAMES[p.world] or p.world, 44, 4)
			name.Position = UDim2.fromOffset(124, 12)
			name.Size = UDim2.fromOffset(420, 56)
			name.TextXAlignment = Enum.TextXAlignment.Left
			name.TextScaled = true
			local cap = Instance.new("UITextSizeConstraint")
			cap.MaxTextSize = 44
			cap.MinTextSize = 28
			cap.Parent = name
			local pill = box(c1, 124, 74, if locked then 123 else 122, 36, if locked then INK else GREEN)
			rounded(pill, 18, if locked then nil else 3)
			local pt =
				text(pill, if locked then "LOCKED" else "READY!", if locked then 22 else 24, if locked then 0 else 3)
			pt.Size = UDim2.fromScale(1, 1)
			pt.ZIndex = 2
		end
		local rows = ROWS[p.world]
		for k = 2, 3 do
			local c = plank(p, k, st)
			if not c then
				continue
			end
			local row = rows and rows[k - 1]
			if not row then
				-- the first World has no requirement: two plain lines (a decision for Adam)
				local l = text(c, if k == 2 then "FIRST WORLD" else "ALWAYS OPEN", 40, 4)
				l.Size = UDim2.fromScale(1, 1)
				continue
			end
			local label, have, need, iconName = row[1], row[2], row[3], row[4]
			local met = not locked or have >= need
			if not locked then
				have = need
			end
			icon(c, iconName, 14, 20, 80)
			local l = text(c, label, 26, 3)
			l.Position = UDim2.fromOffset(108, 12)
			l.Size = UDim2.fromOffset(240, 32)
			l.TextXAlignment = Enum.TextXAlignment.Left
			local numbers = text(c, comma(have) .. " / " .. comma(need), 26, 3)
			numbers.AnchorPoint = Vector2.new(1, 0)
			numbers.Position = UDim2.fromOffset(544, 12)
			numbers.Size = UDim2.fromOffset(170, 32)
			numbers.TextXAlignment = Enum.TextXAlignment.Right
			local numbersWidth = (if label == "CASH" then 159 else 75)
			local tag = box(c, 544 - numbersWidth - 8 - 94, 16, 94, 28, Color3.new(1, 1, 1))
			rounded(tag, 6, 2, Color3.fromRGB(194, 24, 122))
			local tt = text(tag, "PREVIEW", 16, 0, Color3.fromRGB(194, 24, 122))
			tt.Size = UDim2.fromScale(1, 1)
			tag:SetAttribute("Placeholder", "made-up value; real values need the agreed unlock contract")
			local track = box(c, 108, 62, 372, 40, Color3.fromRGB(90, 64, 48))
			rounded(track, 20, 3)
			local frac = math.clamp(have / need, 0, 1)
			local fill = box(
				c,
				112,
				66,
				math.max(1, 364 * frac),
				32,
				if met
					then GREEN
					elseif label == "CASH" then Color3.fromRGB(255, 200, 61)
					else Color3.fromRGB(110, 210, 255)
			)
			fill.ZIndex = 2
			rounded(fill, 16)
			if met then
				icon(c, "IconTick", 488, 58, 48)
			else
				local slot = box(c, 490, 60, 44, 44, Color3.fromRGB(90, 64, 48))
				rounded(slot, 0.5, 4, CREAM)
				local ring = slot:FindFirstChildOfClass("UIStroke")
				if ring then
					ring.Transparency = 0.5
				end
			end
		end
	end

	-- ------------------------------------------------------------------ the lock (per player)
	-- Part-built lock pieces (the comparison for the kit meshes, and the fallback while a mesh is
	-- only a session preview, which does not reach a playtest): each in the same frame as its
	-- mesh. Steel links of four cylinders, a brass block padlock, a wooden post with steel eyes.
	local STEEL = Color3.fromRGB(150, 158, 170)
	local BRASS = Color3.fromRGB(214, 168, 70)
	local WOOD = Color3.fromRGB(122, 86, 56)
	local function bit(parent: Instance, size: Vector3, cf: CFrame, colour: Color3, cylinder: boolean): Part
		local b = Instance.new("Part")
		b.Anchored = true
		b.CanCollide = false
		b.CanQuery = false
		b.CanTouch = false
		b.Size = size
		b.CFrame = cf
		b.Color = colour
		b.Material = if colour == WOOD then Enum.Material.Wood else Enum.Material.Metal
		if cylinder then
			b.Shape = Enum.PartType.Cylinder
		end
		b.Parent = parent
		return b
	end
	local function partPiece(name: string, cf: CFrame, parent: Instance): Instance?
		local turn = CFrame.Angles(0, math.pi / 2, 0) -- a cylinder's axis is X; this lays it along Z
		local up = CFrame.Angles(0, 0, math.pi / 2) -- and this stands it along Y
		if name == "ChainLink" then
			-- an oval ring in the link's XZ plane: two sides along X, two ends along Z
			local m = Instance.new("Model")
			m.Name = name
			for _, z in { -0.235, 0.235 } do
				bit(m, Vector3.new(0.6, 0.15, 0.15), cf * CFrame.new(0, 0, z), STEEL, true)
			end
			for _, x in { -0.425, 0.425 } do
				bit(m, Vector3.new(0.47, 0.15, 0.15), cf * CFrame.new(x, 0, 0) * turn, STEEL, true)
			end
			m.Parent = parent
			return m
		elseif name == "PadlockBody" then
			local m = Instance.new("Model")
			m.Name = name
			bit(m, Vector3.new(1.7, 1.5, 0.75), cf * CFrame.new(0, 0.025, 0.05), BRASS, false)
			bit(m, Vector3.new(0.18, 0.42, 0.05), cf * CFrame.new(0, -0.1, 0.44), Color3.fromRGB(40, 30, 24), false)
			m.Parent = parent
			return m
		elseif name == "PadlockShackle" then
			-- origin at the left leg's foot, the right leg 1.0 along X
			local m = Instance.new("Model")
			m.Name = name
			local left = bit(m, Vector3.new(1.0, 0.16, 0.16), cf * CFrame.new(0, 0.5, 0) * up, STEEL, true)
			bit(m, Vector3.new(1.0, 0.16, 0.16), cf * CFrame.new(1, 0.5, 0) * up, STEEL, true)
			bit(m, Vector3.new(1.16, 0.16, 0.16), cf * CFrame.new(0.5, 1.08, 0), STEEL, true)
			m.PrimaryPart = left
			m.Parent = parent
			return m
		elseif name == "ChainAnchorPost" then
			local m = Instance.new("Model")
			m.Name = name
			bit(m, Vector3.new(13, 1.1, 1.1), cf * CFrame.new(0, 6.5, 0) * up, WOOD, true)
			for _, y in { 12.2, 2.8 } do
				bit(m, Vector3.new(0.12, 0.5, 0.5), cf * CFrame.new(0.6, y, 0) * turn * turn, STEEL, true)
			end
			m.Parent = parent
			return m
		end
		return nil
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

	-- links along a sagging curve from eye a to eye b, alternating 90 degrees about the chain's
	-- axis. kit_portal.py: link pitch 0.70; count = round((length - 0.72) / 0.70), then spaced
	-- evenly so the chain ends in both eyes.
	local function chain(model: Model, a: Vector3, b: Vector3, sag: number, front: Vector3): number
		local pts = {}
		local cum = { 0 }
		for k = 0, 64 do
			local s = k / 64
			table.insert(pts, a:Lerp(b, s) - Vector3.new(0, sag * 4 * s * (1 - s), 0))
			if k > 0 then
				table.insert(cum, cum[k] + (pts[k + 1] - pts[k]).Magnitude)
			end
		end
		local length = cum[#cum]
		local count = math.max(2, math.floor((length - 0.72) / 0.7 + 0.5))
		local step = (length - 0.36 * 2) / (count - 1)
		local i = 1
		for n = 0, count - 1 do
			local at = 0.36 + n * step
			while i < #pts - 1 and cum[i + 1] < at do
				i += 1
			end
			local f = (at - cum[i]) / math.max(cum[i + 1] - cum[i], 1e-6)
			local pos = pts[i]:Lerp(pts[i + 1], f)
			local tangent = (pts[i + 1] - pts[i]).Unit
			local up = front:Cross(tangent).Unit
			local frame = CFrame.fromMatrix(pos, tangent, up)
			if n % 2 == 1 then
				frame *= CFrame.Angles(math.pi / 2, 0, 0)
			end
			placePiece("ChainLink", frame, model)
		end
		return count
	end

	local function buildLock(p: Portal)
		if p.lockTrove then
			p.trove:Remove(p.lockTrove)
		end
		local lt = Trove.new()
		p.lockTrove = lt
		p.trove:Add(lt)
		local model = Instance.new("Model")
		model.Name = p.world .. "Lock"
		local w = p.anchor:GetAttribute("Width") :: number
		local ground = p.anchor:GetAttribute("Ground") :: number
		local cf = p.anchor.CFrame
		local front = cf.LookVector -- toward the plots
		-- kit_portal.py: posts 13 tall, ring eyes on the post's +x side at 12.2 and 2.8, 0.565 out
		local ends = {}
		for _, side in { -1, 1 } do
			local x = side * (w / 2 + 1)
			local foot = (cf * CFrame.new(x, 0, -1.3)).Position
			-- each post's +x (its eyes) faces the field
			local base = CFrame.new(foot.X, ground, foot.Z)
				* cf.Rotation
				* CFrame.Angles(0, if side < 0 then 0 else math.pi, 0)
			placePiece("ChainAnchorPost", base, model)
			ends[side] = {
				high = (base * CFrame.new(0.565, 12.2, 0)).Position,
				low = (base * CFrame.new(0.565, 2.8, 0)).Position,
			}
		end
		local links = chain(model, ends[-1].high, ends[1].low, 0.8, front)
			+ chain(model, ends[-1].low + front * 0.25, ends[1].high + front * 0.25, 0.8, front)
		-- the padlock hangs where the chains cross, facing the plots
		local cross = (ends[-1].high + ends[1].low + ends[-1].low + ends[1].high) / 4
		local lockFrame = CFrame.lookAt(
			cross - Vector3.new(0, 1.45, 0) + front * 0.5,
			cross - Vector3.new(0, 1.45, 0) + front * 2
		) * CFrame.Angles(0, math.pi, 0)
		placePiece("PadlockBody", lockFrame, model)
		-- the shackle's origin is its left leg's foot, seated at (-0.5, 0.60) on the body
		local shackle = placePiece("PadlockShackle", lockFrame * CFrame.new(-0.5, 0.6, 0), model)
		if shackle then
			shackle:SetAttribute("Hinge", true)
		end
		model:SetAttribute("Links", links)
		model:SetAttribute("Parts", partCount(model))
		model:SetAttribute("Build", if model:FindFirstChildWhichIsA("Model") then "parts" else "meshes")
		model:SetAttribute("PreviewState", PortalPreviewState.Source)
		model.Parent = liveFolder
		lt:Add(model)
		p.lockModel = model
	end

	local function unlockAnimation(p: Portal)
		local model = p.lockModel
		local lt = p.lockTrove
		if not (model and lt) then
			return
		end
		p.lockModel = nil
		p.lockTrove = nil
		local calm = reducedMotion()
		local shackle = model:FindFirstChild("PadlockShackle")
		if shackle and not calm then
			local info = TweenInfo.new(0.35, Enum.EasingStyle.Back)
			if shackle:IsA("BasePart") then
				local open = shackle.CFrame * CFrame.new(0, 0.5, 0) * CFrame.Angles(0, math.rad(100), 0)
				TweenService:Create(shackle, info, { CFrame = open }):Play()
			elseif shackle:IsA("Model") then
				-- a part-built shackle turns as one through a pivot value
				local start = shackle:GetPivot()
				local v = Instance.new("CFrameValue")
				v.Value = start
				v.Changed:Connect(function(cf)
					shackle:PivotTo(cf)
				end)
				TweenService
					:Create(v, info, { Value = start * CFrame.new(0, 0.5, 0) * CFrame.Angles(0, math.rad(100), 0) })
					:Play()
				task.delay(0.4, function()
					v:Destroy()
				end)
			end
		end
		task.delay(if calm then 0 else 0.4, function()
			for i, part in model:GetDescendants() do
				if part:IsA("BasePart") then
					local goal = {
						Transparency = 1,
						CFrame = if calm then part.CFrame else part.CFrame - Vector3.new(0, 3 + (i % 5) * 0.4, 0),
					}
					local info = TweenInfo.new(
						if calm then 0.8 else 0.9 + (i % 7) * 0.05,
						if calm then Enum.EasingStyle.Sine else Enum.EasingStyle.Quad,
						Enum.EasingDirection.In
					)
					TweenService:Create(part, info, goal):Play()
				end
			end
			task.delay(1.4, function()
				lt:Destroy()
			end)
		end)
		if not calm then
			task.delay(0.7, function()
				local burst = p.emitters.Burst
				if burst and burst.Parent then
					burst:Emit(36)
				end
			end)
		end
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
				sign = nil,
				signGuis = {},
				signTrove = nil,
			}
			buildField(p)
			buildSignFaces(p)
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
					buildSignFaces(p)
					if now then
						buildLock(p)
					else
						unlockAnimation(p)
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
