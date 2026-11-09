--!strict
-- TrailBursts (Lane 3 Round 8, T-04 and T-05; to R8-IMG-22): the trail's hop moments, drawn in the equipped trail's own colours.
-- Short-lived and cosmetic only. Nothing here changes a run, a save or the server; the client only draws.
--
--   TrailBursts.play(target, look, moment, reduceMotion?) -> Effect?
--       target   a Model (a car) or a BasePart (the avatar's HumanoidRootPart) in Workspace; look = a CarLook.Look
--       "leap"   a burst ring in the trail's colours puffs out from the car you leave (target = that car)
--       "dive"   a bright streak follows the avatar down (target = the avatar's root or character)
--       "catch"  a flash in the trail's colours washes over the new car (target = that car)
--       "flare"  a brief brighter flare from the back of the car (top speed, right after a dive)
--       With no trail in the look (nil, "no_trail") nothing plays and nil comes back. Effect:stop() ends it early.
--   TrailBursts.stream(target, look, reduceMotion?) -> Stream?   a thin version of the trail from the floating avatar
--   TrailBursts.destroyAll()                                       drop everything (a run ends, a test finishes)
--   (The hop chain, T-05, and the trail's own flare are TrailFx's: fx:setLevel and fx:flare; TrailMoments drives them.)
--
-- Everything follows its target (a car moves by PivotTo, the avatar by CFrame) from one render-step connection that exists only
-- while an effect is alive; each effect owns a Trove and goes away with its target. Per effect budget: a burst is at most about
-- 60 particles for under a second, at most MAX_ONE_SHOTS bursts at once (the oldest goes first). Reduce Motion (Motion.reduced)
-- and low graphics (UserGameSettings.SavedQualityLevel 1 to 3) halve every particle count; Reduce Motion also shrinks the rings,
-- drops the lights and softens the wash. Textures are Roblox's built-in particle textures; a ParticleFX flipbook from WS-5a is
-- used when AssetIds.image("r8_trail_fx_<trailKey>") (else "r8_trail_fx_burst") returns an id.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local AssetIds = require(ReplicatedStorage.Shared.Style.AssetIds)
local CarLook = require(ReplicatedStorage.Shared.Style.CarLook)
local Catalog = require(ReplicatedStorage.Shared.UI.CosmeticPreviewCatalog)
local Trove = require(ReplicatedStorage.Packages.Trove)
local Motion = require(script.Parent.Parent.Motion)

local TrailBursts = {}

export type Moment = "leap" | "dive" | "catch" | "flare"
export type Effect = {
	stop: (self: Effect) -> (),
	destroy: (self: Effect) -> (),
}
export type Stream = {
	setStep: (self: Stream, step: number) -> (),
	stop: (self: Stream) -> (),
	destroy: (self: Stream) -> (),
}

local MAX_ONE_SHOTS = 5
local LOST_GRACE = 6 -- seconds a kept effect waits when its target is gone (the car you left is retired while you float)
local FOLLOW = "TrailBurstsFollow"
local LOW_OVERRIDE = "Lane3LowGraphicsOverride"

-- T-05 (recorded value): the avatar stream's width and particle-rate multiplier at hop-chain step 0 to 3 (the trail on the car grows
-- through TrailFx's own fx:setLevel, WS-5a).
local STREAM_WIDTH = table.freeze({ 1, 1.3, 1.6, 2.0 })

local P = "rbxasset://textures/particles/"
local SPARKLE = P .. "sparkles_main.dds"
local FIRE = P .. "fire_main.dds"
local EMBER = P .. "fire_sparks_main.dds"
local SMOKE = P .. "smoke_main.dds"
local GLOW = P .. "forcefield_glow_main.dds"
local SQUARE = P .. "SquareParticle.png"

local WHITE = Color3.new(1, 1, 1)
local DEFAULT_A = Color3.fromRGB(255, 214, 90)
local DEFAULT_B = Color3.fromRGB(255, 120, 60)

-- Palette and style ------------------------------------------------------------------------------------------------------------

type Palette = {
	key: string,
	list: { Color3 },
	a: Color3,
	b: Color3,
	core: Color3, -- the hot, nearly white version of the first colour
	rarity: string,
}

-- How each trail's particles look: the main puff texture, the spark texture, whether every spoke gets its own colour (confetti,
-- pixels, rainbow), and the sideways pull on sparks (negative = falls).
type Style = { tex: string, spark: string, each: boolean?, fall: number? }
local STYLES: { [string]: Style } = {
	flame = { tex = FIRE, spark = EMBER },
	comet = { tex = GLOW, spark = SQUARE },
	lightning = { tex = SPARKLE, spark = SPARKLE },
	neon = { tex = GLOW, spark = SPARKLE },
	galaxy = { tex = SMOKE, spark = SPARKLE },
	rainbow = { tex = SPARKLE, spark = GLOW, each = true },
	bubble = { tex = GLOW, spark = SPARKLE, fall = 4 },
	confetti = { tex = SQUARE, spark = SQUARE, each = true, fall = -14 },
	pixel = { tex = SQUARE, spark = SQUARE, each = true },
	frost = { tex = SPARKLE, spark = SMOKE },
	slime = { tex = GLOW, spark = GLOW, fall = -20 },
	gold = { tex = EMBER, spark = GLOW, fall = -10 },
	vip = { tex = SPARKLE, spark = GLOW },
}
local DEFAULT_STYLE: Style = { tex = SPARKLE, spark = GLOW }

local function paletteOf(look: CarLook.Look?): Palette?
	if not look or not look.trail then
		return nil
	end
	local item = Catalog.byId("Trails", look.trail)
	if not item or item.isNone then
		return nil
	end
	local list: { Color3 } = table.clone(item.colours)
	if look.matchPaint and look.paint then
		local paint = Catalog.byId("Paint", look.paint)
		if paint and paint.colours[1] then
			list = { paint.colours[1], paint.colours[2] or paint.colours[1] }
		end
	end
	if #list == 0 then
		list = { DEFAULT_A, DEFAULT_B }
	end
	local a = list[1]
	local tier = Catalog.tierOf("Trails", item.tier)
	return {
		key = item.key or "",
		list = list,
		a = a,
		b = list[2] or a,
		core = a:Lerp(WHITE, 0.78),
		rarity = if tier then tier.rarity else "Common",
	}
end

local function styleOf(p: Palette): Style
	return STYLES[p.key] or DEFAULT_STYLE
end

local function seq(...: Color3): ColorSequence
	local list = { ... }
	if #list == 1 then
		return ColorSequence.new(list[1])
	end
	local keys: { ColorSequenceKeypoint } = {}
	for i, c in list do
		table.insert(keys, ColorSequenceKeypoint.new((i - 1) / (#list - 1), c))
	end
	return ColorSequence.new(keys)
end

local function num(a: number, b: number?): NumberSequence
	return if b then NumberSequence.new(a, b) else NumberSequence.new(a)
end

-- Comfort and budget --------------------------------------------------------------------------------------------------------------

local function lowGraphics(): boolean
	local player = Players.LocalPlayer
	local override = player and player:GetAttribute(LOW_OVERRIDE)
	if type(override) == "boolean" then
		return override
	end
	local ok, level = pcall(function()
		return UserSettings():GetService("UserGameSettings").SavedQualityLevel.Value
	end)
	return ok and type(level) == "number" and level >= 1 and level <= 3
end

type Comfort = { reduce: boolean, k: number }

local function comfort(reduceMotion: boolean?): Comfort
	local reduce = if reduceMotion ~= nil then reduceMotion else Motion.reduced()
	return { reduce = reduce, k = if reduce or lowGraphics() then 0.5 else 1 }
end

local function count(n: number, c: Comfort): number
	return math.max(1, math.floor(n * c.k + 0.5))
end

-- Particles -----------------------------------------------------------------------------------------------------------------------

type Spec = {
	tex: string,
	flip: number?, -- 4, 16 or 64 frames when tex is a ParticleFX sheet
	color: ColorSequence,
	size: NumberSequence,
	fade: NumberSequence?,
	life: { number },
	speed: { number },
	spread: Vector2?,
	accel: Vector3?,
	drag: number?,
	rate: number?,
	light: number?,
	dir: Enum.NormalId?,
	spin: number?,
	locked: boolean?,
}

local LAYOUTS: { [number]: Enum.ParticleFlipbookLayout } = {
	[4] = Enum.ParticleFlipbookLayout.Grid2x2,
	[16] = Enum.ParticleFlipbookLayout.Grid4x4,
	[64] = Enum.ParticleFlipbookLayout.Grid8x8,
}

local function emitter(parent: Instance, s: Spec): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.Texture = s.tex
	if s.flip and LAYOUTS[s.flip] then
		e.FlipbookLayout = LAYOUTS[s.flip]
		e.FlipbookMode = Enum.ParticleFlipbookMode.OneShot
	end
	e.Rate = s.rate or 0
	e.Color = s.color
	e.Size = s.size
	e.Transparency = s.fade or num(0, 1)
	e.Lifetime = NumberRange.new(s.life[1], s.life[2])
	e.Speed = NumberRange.new(s.speed[1], s.speed[2])
	local spread = s.spread or Vector2.new(10, 10)
	e.SpreadAngle = spread
	e.Acceleration = s.accel or Vector3.zero
	e.Drag = s.drag or 0
	e.LightEmission = s.light or 1
	e.LightInfluence = 0
	e.LockedToPart = s.locked == true
	e.EmissionDirection = s.dir or Enum.NormalId.Front
	if s.spin then
		e.Rotation = NumberRange.new(0, 360)
		e.RotSpeed = NumberRange.new(-s.spin, s.spin)
	end
	e.Parent = parent
	return e
end

-- A ParticleFX flipbook for this trail, when WS-5a has uploaded one (id and frame count), else the built-in texture.
local function sheet(p: Palette, fallback: string): (string, number?)
	for _, name in { "r8_trail_fx_" .. p.key, "r8_trail_fx_burst" } do
		local id = AssetIds.image(name)
		if id ~= "" then
			local entry = AssetIds.entry(name)
			return id, if entry then entry.frames else nil
		end
	end
	return fallback, nil
end

-- Following ------------------------------------------------------------------------------------------------------------------------

type Fx = {
	trove: any,
	anchor: Part,
	target: Instance,
	offset: CFrame,
	dead: boolean,
	stopped: boolean,
	counted: boolean,
	tail: number,
	stoppers: { () -> () },
	lostAt: number?,
	stop: (self: Fx) -> (),
	destroy: (self: Fx) -> (),
}

local Fx = {}
Fx.__index = Fx

local live: { [Fx]: boolean } = {}
local oneShots: { Fx } = {}
local folderCache: Folder? = nil
local bound = false

local function getFolder(): Folder
	local f = folderCache
	if f and f.Parent then
		return f
	end
	local made = Instance.new("Folder")
	made.Name = "TrailBurstFx"
	made.Parent = Workspace
	folderCache = made
	return made
end

local function frameOf(target: Instance): CFrame?
	if target:IsA("Model") then
		return target:GetPivot()
	elseif target:IsA("BasePart") then
		return target.CFrame
	end
	return nil
end

local function follow()
	for fx in live do
		local target = fx.target
		local cf = frameOf(target)
		if cf ~= nil and target:IsDescendantOf(Workspace) then
			fx.lostAt = nil
			fx.anchor.CFrame = cf * fx.offset
		elseif fx.counted then
			fx:destroy() -- a burst goes with its car
		else
			-- an effect its owner keeps (the stream) waits a few seconds for a new target before giving up
			local now = os.clock()
			local since = fx.lostAt or now
			fx.lostAt = since
			if now - since > LOST_GRACE then
				fx:destroy()
			end
		end
	end
end

local function bind()
	if not bound then
		bound = true
		-- after the run's own render step (Camera + 1) so the effect sits on the car's final position of the frame
		RunService:BindToRenderStep(FOLLOW, Enum.RenderPriority.Last.Value, follow)
	end
end

local function unbindIfIdle()
	if bound and next(live) == nil then
		bound = false
		RunService:UnbindFromRenderStep(FOLLOW)
	end
end

function Fx.destroy(self: Fx)
	if self.dead then
		return
	end
	self.dead = true
	live[self] = nil
	local i = table.find(oneShots, self)
	if i then
		table.remove(oneShots, i)
	end
	self.trove:Destroy()
	unbindIfIdle()
end

-- Ends the emission now; whatever is in flight (ribbons, particles) fades over `tail` seconds, then everything goes.
function Fx.stop(self: Fx)
	if self.dead or self.stopped then
		return
	end
	self.stopped = true
	for _, fn in self.stoppers do
		fn()
	end
	task.delay(self.tail, function()
		self:destroy()
	end)
end

local function newFx(target: Instance, offset: CFrame, size: Vector3?, life: number?, counted: boolean): Fx
	local trove = Trove.new()
	local anchor = Instance.new("Part")
	anchor.Name = "TrailBurst"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.CastShadow = false
	anchor.Transparency = 1
	anchor.Size = size or Vector3.new(0.2, 0.2, 0.2)
	anchor.CFrame = (frameOf(target) or CFrame.identity) * offset
	anchor.Parent = getFolder()
	trove:Add(anchor)
	local self: Fx = setmetatable({
		trove = trove,
		anchor = anchor,
		target = target,
		offset = offset,
		dead = false,
		stopped = false,
		counted = counted,
		tail = 0.6,
		stoppers = {},
		lostAt = nil,
	}, Fx) :: any
	if counted then
		while #oneShots >= MAX_ONE_SHOTS do
			oneShots[1]:destroy()
		end
		table.insert(oneShots, self)
	end
	live[self] = true
	bind()
	if life then
		task.delay(life, function()
			self:destroy()
		end)
	end
	return self
end

-- The box of a target in its own frame: where its middle is, and how big it is (x across, y up, z along; the back is +Z).
local function measure(target: Instance): (CFrame, Vector3)
	if target:IsA("Model") then
		local box, size = target:GetBoundingBox()
		return target:GetPivot():ToObjectSpace(box), size
	elseif target:IsA("BasePart") then
		return CFrame.identity, target.Size
	end
	return CFrame.identity, Vector3.new(5, 3, 9)
end

local function rootOf(target: Instance): BasePart?
	if target:IsA("BasePart") then
		return target
	end
	local root = target:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root
	end
	return nil
end

local function tween(fx: Fx, instance: Instance, seconds: number, goal: { [string]: any }, style: Enum.EasingStyle?)
	local info = TweenInfo.new(seconds, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local t = TweenService:Create(instance, info, goal)
	fx.trove:Add(t, "Cancel")
	t:Play()
end

local function attachment(parent: Instance, cf: CFrame): Attachment
	local a = Instance.new("Attachment")
	a.CFrame = cf
	a.Parent = parent
	return a
end

-- A soft light that flashes and fades (skipped under Reduce Motion and low graphics).
local function flash(fx: Fx, p: Palette, c: Comfort, brightness: number, range: number, seconds: number)
	if c.reduce or c.k < 1 then
		return
	end
	local light = Instance.new("PointLight")
	light.Color = p.a:Lerp(WHITE, 0.3)
	light.Range = range
	light.Brightness = brightness
	light.Shadows = false
	light.Parent = fx.anchor
	tween(fx, light, seconds, { Brightness = 0 })
end

-- A flat ring on the ground in the trail's colours that grows and thins out. Drawn with a SurfaceGui on the effect's flat anchor
-- (the anchor's size is the ring's final diameter).
local function ring(fx: Fx, p: Palette, startScale: number, seconds: number, after: number, thickness: number)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Top
	gui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
	gui.CanvasSize = Vector2.new(512, 512)
	gui.LightInfluence = 0
	gui.Brightness = 2
	gui.AlwaysOnTop = false
	gui.Parent = fx.anchor
	-- the glow (wide and soft) and the crisp line on top of it
	for pass = 1, 2 do
		local frame = Instance.new("Frame")
		frame.BackgroundTransparency = 1
		frame.AnchorPoint = Vector2.new(0.5, 0.5)
		frame.Position = UDim2.fromScale(0.5, 0.5)
		frame.Size = UDim2.fromScale(startScale, startScale)
		frame.Visible = false
		frame.Parent = gui
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0.5, 0)
		corner.Parent = frame
		local stroke = Instance.new("UIStroke")
		stroke.Thickness = if pass == 1 then thickness * 2.4 else thickness
		stroke.Transparency = if pass == 1 then 0.62 else 0.05
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		stroke.Color = WHITE
		stroke.Parent = frame
		local gradient = Instance.new("UIGradient")
		gradient.Color = seq(p.core, p.a, p.b)
		gradient.Rotation = 90
		gradient.Parent = stroke
		task.delay(after, function()
			if fx.dead then
				return
			end
			frame.Visible = true
			tween(fx, frame, seconds, { Size = UDim2.fromScale(1, 1) })
			tween(fx, stroke, seconds, { Thickness = thickness * 0.3, Transparency = 1 }, Enum.EasingStyle.Quad)
		end)
	end
end

-- Puffs flying outward in a ring from the centre of a flat anchor: `n` spokes, each a short burst.
local function spokes(
	fx: Fx,
	p: Palette,
	st: Style,
	c: Comfort,
	n: number,
	per: number,
	radius: number,
	speed: number,
	size: number
)
	local tex, flip = sheet(p, st.tex)
	-- puffs rise like flames, or fall like confetti, as the trail's style says
	local lift = if st.fall then st.fall * 0.3 else 10
	for i = 1, n do
		local ang = (i - 1) / n * math.pi * 2
		local dir = Vector3.new(math.cos(ang), 0, math.sin(ang))
		local from = dir * radius + Vector3.new(0, 0.5, 0)
		local att = attachment(fx.anchor, CFrame.lookAt(from, from + dir))
		local colour = if st.each then p.list[(i - 1) % #p.list + 1] else nil
		emitter(att, {
			tex = tex,
			flip = flip,
			color = if colour then seq(p.core, colour) else seq(p.core, p.a, p.b),
			size = num(size, size * 0.15),
			fade = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.1),
				NumberSequenceKeypoint.new(0.6, 0.35),
				NumberSequenceKeypoint.new(1, 1),
			}),
			life = { 0.45, 0.8 },
			speed = { speed * 0.8, speed * 1.15 },
			spread = Vector2.new(10, 6),
			accel = Vector3.new(0, lift, 0),
			drag = 2.5,
			locked = true,
		}):Emit(count(per, c))
	end
end

-- Recipes --------------------------------------------------------------------------------------------------------------------------

-- LEAP: the car you leave. A burst ring in the trail's colours around the car's footprint, puffs flying out along the ground and a
-- few sparks up, a quick light. Reduce Motion: one smaller ring, half the particles, no light.
local function leap(target: Instance, p: Palette, c: Comfort): Fx
	local box, size = measure(target)
	local base = math.clamp(math.max(size.X, size.Z), 5, 22)
	local finalD = base * (if c.reduce then 1.7 else 2.5)
	local fx = newFx(target, box * CFrame.new(0, -size.Y / 2 + 0.25, 0), Vector3.new(finalD, 0.05, finalD), 1.1, true)
	local st = styleOf(p)
	ring(fx, p, base * 0.8 / finalD, 0.5, 0, 22)
	if not c.reduce then
		ring(fx, p, base * 0.6 / finalD, 0.45, 0.07, 14)
	end
	spokes(fx, p, st, c, if c.k < 1 then 6 else 10, 5, base * 0.45, 20, base * 0.28)
	local centre = attachment(fx.anchor, CFrame.new(0, 0.4, 0))
	local tex, flip = sheet(p, st.spark)
	emitter(centre, {
		tex = tex,
		flip = flip,
		color = seq(p.core, p.a, p.b),
		size = num(0.55, 0),
		life = { 0.5, 0.8 },
		speed = { 14, 24 },
		spread = Vector2.new(35, 35),
		accel = Vector3.new(0, st.fall or -26, 0),
		dir = Enum.NormalId.Top,
		spin = if st.each then 300 else nil,
		locked = true,
	}):Emit(count(10, c))
	flash(fx, p, c, 3, 18, 0.3)
	return fx
end

-- CATCH: the new car. A wash of the trail's colours over the whole car (a Highlight fading from white-hot to the trail colour and
-- out), a ring on the road, a puff off the roof.
local function catch(target: Instance, p: Palette, c: Comfort): Fx
	local box, size = measure(target)
	local base = math.clamp(math.max(size.X, size.Z), 5, 22)
	local finalD = base * (if c.reduce then 1.4 else 1.9)
	local fx = newFx(target, box * CFrame.new(0, -size.Y / 2 + 0.25, 0), Vector3.new(finalD, 0.05, finalD), 1.0, true)
	local st = styleOf(p)
	local wash = Instance.new("Highlight")
	wash.Adornee = target
	wash.DepthMode = Enum.HighlightDepthMode.Occluded
	wash.FillColor = p.core
	wash.OutlineColor = p.a
	wash.FillTransparency = if c.reduce then 0.6 else 0.3
	wash.OutlineTransparency = 0
	wash.Parent = fx.anchor
	local seconds = if c.reduce then 0.65 else 0.5
	tween(fx, wash, seconds, { FillTransparency = 1, OutlineTransparency = 1, FillColor = p.a })
	ring(fx, p, base * 0.7 / finalD, 0.45, 0, 18)
	local roof = attachment(fx.anchor, CFrame.new(0, size.Y, 0))
	local tex, flip = sheet(p, st.tex)
	emitter(roof, {
		tex = tex,
		flip = flip,
		color = seq(p.core, p.a, p.b),
		size = num(base * 0.22, 0.1),
		life = { 0.35, 0.6 },
		speed = { 6, 12 },
		spread = Vector2.new(180, 180),
		drag = 2,
		dir = Enum.NormalId.Top,
		locked = true,
	}):Emit(count(16, c))
	local sparks = attachment(fx.anchor, CFrame.new(0, size.Y * 0.8, 0))
	emitter(sparks, {
		tex = st.spark,
		color = seq(WHITE, p.a),
		size = num(0.5, 0),
		life = { 0.4, 0.7 },
		speed = { 8, 16 },
		spread = Vector2.new(180, 180),
		accel = Vector3.new(0, st.fall or -12, 0),
		dir = Enum.NormalId.Top,
		spin = if st.each then 300 else nil,
		locked = true,
	}):Emit(count(8, c))
	flash(fx, p, c, 2.5, 16, 0.3)
	return fx
end

-- FLARE: a brief brighter flare from the back of the car: a hot jet of the trail's puffs and a short bright core beam.
local function flare(target: Instance, p: Palette, c: Comfort): Fx
	local box, size = measure(target)
	local width = math.clamp(size.X, 2, 10)
	local fx = newFx(target, box * CFrame.new(0, -size.Y * 0.2, size.Z / 2 + 0.3), nil, 0.9, true)
	local st = styleOf(p)
	local tex, flip = sheet(p, st.tex)
	local back = attachment(fx.anchor, CFrame.identity)
	emitter(back, {
		tex = tex,
		flip = flip,
		color = seq(WHITE, p.core, p.a, p.b),
		size = num(width * 0.45, 0.2),
		life = { 0.25, 0.45 },
		speed = { 22, 34 },
		spread = Vector2.new(10, 10),
		dir = Enum.NormalId.Back,
	}):Emit(count(14, c))
	local length = 9 + width
	local tip = attachment(fx.anchor, CFrame.new(0, 0, length))
	local beam = Instance.new("Beam")
	beam.Attachment0 = back
	beam.Attachment1 = tip
	beam.Color = seq(WHITE, p.core, p.a)
	beam.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.7, 0.3),
		NumberSequenceKeypoint.new(1, 1),
	})
	beam.Width0 = width * 0.35
	beam.Width1 = 0
	beam.LightEmission = 1
	beam.LightInfluence = 0
	beam.FaceCamera = true
	beam.Segments = 6
	beam.Parent = fx.anchor
	tween(fx, beam, 0.35, { Width0 = 0 }, Enum.EasingStyle.Quad)
	flash(fx, p, c, 3.5, 20, 0.35)
	return fx
end

-- DIVE: a bright streak that follows the avatar down: a wide glow ribbon and a thin white-hot core ribbon off the avatar, with
-- embers along the path. It runs for DIVE_SECONDS, then fades over the ribbons' lifetime.
local DIVE_SECONDS = 0.45
local function dive(target: Instance, p: Palette, c: Comfort): Fx?
	local root = rootOf(target)
	if not root then
		return nil
	end
	local fx = newFx(root, CFrame.new(0, 0, 0.6), nil, nil, true)
	fx.tail = 0.6
	local st = styleOf(p)
	local function ribbon(half: number, life: number, colour: ColorSequence, width: NumberSequence)
		local a0 = attachment(fx.anchor, CFrame.new(0, half, 0))
		local a1 = attachment(fx.anchor, CFrame.new(0, -half, 0))
		local t = Instance.new("Trail")
		t.Attachment0 = a0
		t.Attachment1 = a1
		t.Lifetime = life
		t.Color = colour
		t.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.05),
			NumberSequenceKeypoint.new(0.5, 0.35),
			NumberSequenceKeypoint.new(1, 1),
		})
		t.WidthScale = width
		t.LightEmission = 1
		t.LightInfluence = 0
		t.FaceCamera = true
		t.MinLength = 0.05
		t.Parent = fx.anchor
		table.insert(fx.stoppers, function()
			t.Enabled = false
		end)
	end
	ribbon(1.5, 0.5, seq(p.core, p.a, p.b), NumberSequence.new(1, 0.1))
	ribbon(0.45, 0.38, seq(WHITE, p.core), NumberSequence.new(1, 0))
	local mid = attachment(fx.anchor, CFrame.identity)
	local embers = emitter(mid, {
		tex = st.spark,
		color = seq(p.core, p.a, p.b),
		size = num(0.9, 0),
		life = { 0.25, 0.45 },
		speed = { 0, 4 },
		spread = Vector2.new(35, 35),
		drag = 2,
		rate = 70 * c.k,
		dir = Enum.NormalId.Back,
		spin = if st.each then 300 else nil,
	})
	table.insert(fx.stoppers, function()
		embers.Enabled = false
	end)
	flash(fx, p, c, 2, 14, 0.4)
	task.delay(DIVE_SECONDS, function()
		fx:stop()
	end)
	return fx
end

local RECIPES: { [string]: (Instance, Palette, Comfort) -> Fx? } = {
	leap = leap,
	catch = catch,
	flare = flare,
	dive = dive,
}

function TrailBursts.play(target: Instance, look: CarLook.Look?, moment: Moment, reduceMotion: boolean?): Effect?
	local p = paletteOf(look)
	local make = RECIPES[moment]
	if not p or not make or not target:IsDescendantOf(Workspace) then
		return nil
	end
	return make(target, p, comfort(reduceMotion)) :: any
end

-- The avatar's thin stream --------------------------------------------------------------------------------------------------------

-- While you float: a thin ribbon and a few particles in the trail's colours off the avatar's back. setStep(0..3) widens it with
-- the hop chain (T-05). stop() lets it fade; destroy() removes it now.
function TrailBursts.stream(target: Instance, look: CarLook.Look?, reduceMotion: boolean?): Stream?
	local p = paletteOf(look)
	local root = rootOf(target)
	if not p or not root or not root:IsDescendantOf(Workspace) then
		return nil
	end
	local c = comfort(reduceMotion)
	local st = styleOf(p)
	local fx = newFx(root, CFrame.new(0, 0, 0.8), nil, nil, false)
	local a0 = attachment(fx.anchor, CFrame.new(0, 0.45, 0))
	local a1 = attachment(fx.anchor, CFrame.new(0, -0.45, 0))
	local ribbon = Instance.new("Trail")
	ribbon.Attachment0 = a0
	ribbon.Attachment1 = a1
	ribbon.Lifetime = 0.55
	ribbon.Color = seq(p.core, p.a, p.b)
	ribbon.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.15),
		NumberSequenceKeypoint.new(0.6, 0.55),
		NumberSequenceKeypoint.new(1, 1),
	})
	ribbon.WidthScale = NumberSequence.new(1, 0.1)
	ribbon.LightEmission = 1
	ribbon.LightInfluence = 0
	ribbon.FaceCamera = true
	ribbon.MinLength = 0.05
	ribbon.Parent = fx.anchor
	local tex, flip = sheet(p, st.tex)
	local baseRate = 16 * c.k
	local bits = emitter(attachment(fx.anchor, CFrame.identity), {
		tex = tex,
		flip = flip,
		color = seq(p.core, p.a, p.b),
		size = num(0.7, 0),
		life = { 0.35, 0.6 },
		speed = { 3, 7 },
		spread = Vector2.new(15, 15),
		rate = baseRate,
		dir = Enum.NormalId.Back,
	})
	table.insert(fx.stoppers, function()
		ribbon.Enabled = false
		bits.Enabled = false
	end)
	local handle = {}
	function handle.setStep(_self: Stream, step: number)
		local s = STREAM_WIDTH[math.clamp(math.floor(step), 0, 3) + 1]
		ribbon.WidthScale = NumberSequence.new(s, 0.1)
		ribbon.Lifetime = 0.55 + 0.08 * (s - 1)
		bits.Rate = baseRate * s
		bits.Size = num(0.7 * s, 0)
	end
	function handle.stop(_self: Stream)
		fx:stop()
	end
	function handle.destroy(_self: Stream)
		fx:destroy()
	end
	return handle :: any
end

function TrailBursts.destroyAll()
	for fx in table.clone(live) do
		fx:destroy()
	end
end

return TrailBursts
