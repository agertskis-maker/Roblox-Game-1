--!strict
-- TrailFx (Round 7, C-06): the trails, built like boost trails: from two exhaust points at the back of the car, each trail is
-- layers (a bright core, a body that streams back, breakup particles, and a fading Trail ribbon for motion), with its own shape.
-- Particles stream backwards even when the car stands still, so the Style Shop's turntable and the Launch Pad kiosk show the trail
-- too (a Trail ribbon only draws while the car moves). Particles are flat sprites in 3D, so the depth comes from two origins,
-- movement and the ribbons; nothing here is a volumetric mesh. Cosmetic only: no trail changes a run.
--
-- Textures are Roblox's own built-in particle textures (rbxasset://textures/particles/...) plus the game's ribbon art.
-- Particle budget: every trail stays under about 160 particles alive per car (rate x lifetime, both exhausts).
--
--   local fx = TrailFx.attach(holder: BasePart, tail: CFrame, width: number) -> Handle
--   fx:set(item?)   fx:place(tail: CFrame)   fx:setSpeed(0..1)   fx:clear()   fx:destroy()

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Catalog = require(ReplicatedStorage.Shared.UI.CosmeticPreviewCatalog)
local GameIcons = require(script.Parent.Parent.GameIcons) :: any

local TrailFx = {}

local P = "rbxasset://textures/particles/"
local SPARKLE = P .. "sparkles_main.dds"
local FIRE = P .. "fire_main.dds"
local EMBER = P .. "fire_sparks_main.dds"
local SMOKE = P .. "smoke_main.dds"
local GLOW = P .. "forcefield_glow_main.dds"
local SQUARE = P .. "SquareParticle.png"

local function seq(...: Color3): ColorSequence
	local list = { ... }
	if #list == 1 then
		return ColorSequence.new(list[1])
	end
	local keys = {}
	for i, c in list do
		table.insert(keys, ColorSequenceKeypoint.new((i - 1) / (#list - 1), c))
	end
	return ColorSequence.new(keys)
end

local function num(a: number, b: number?): NumberSequence
	return if b then NumberSequence.new(a, b) else NumberSequence.new(a)
end

type Layer = { [string]: any }

-- One emitter at an exhaust. Fields: texture, rate, life {min,max}, speed {min,max}, size (NumberSequence), colour, fade
-- (NumberSequence), spread, accel, drag, rot, spin, light, squash.
local function emitter(at: Attachment, l: Layer): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.Texture = l.texture or SPARKLE
	e.Rate = l.rate or 10
	e.Lifetime = NumberRange.new(l.life[1], l.life[2])
	e.Speed = NumberRange.new(l.speed[1], l.speed[2])
	e.Size = l.size or num(0.6, 0)
	e.Color = l.colour or seq(Color3.new(1, 1, 1))
	e.Transparency = l.fade or num(0, 1)
	e.SpreadAngle = Vector2.new(l.spread or 10, l.spread or 10)
	e.Acceleration = l.accel or Vector3.zero
	e.Drag = l.drag or 0
	e.Rotation = NumberRange.new(0, if l.rot then 360 else 0)
	e.RotSpeed = NumberRange.new(-(l.spin or 0), l.spin or 0)
	e.LightEmission = l.light or 0.6
	e.LightInfluence = 0
	e.EmissionDirection = Enum.NormalId.Back -- away from the car
	if l.squash then
		e.Squash = l.squash
	end
	e:SetAttribute("BaseRate", e.Rate)
	e.Parent = at
	return e
end

-- A ribbon behind the car that draws while it moves.
local function ribbon(a: Attachment, b: Attachment, l: Layer): Trail
	local t = Instance.new("Trail")
	t.Attachment0 = a
	t.Attachment1 = b
	t.Lifetime = l.life or 0.5
	t.Color = l.colour
	t.Transparency = l.fade or num(0.1, 1)
	t.WidthScale = l.width or num(1, 0)
	t.LightEmission = l.light or 0.7
	t.LightInfluence = 0
	t.FaceCamera = l.faceCamera ~= false
	t.MinLength = 0.05
	if l.texture then
		t.Texture = l.texture
		t.TextureMode = Enum.TextureMode.Stretch
	end
	t:SetAttribute("BaseLife", t.Lifetime)
	t.Parent = a.Parent
	return t
end

-- A static streak from an exhaust to a point behind it, so a standing car shows the trail's shape.
local function streak(a: Attachment, b: Attachment, l: Layer): Beam
	local beam = Instance.new("Beam")
	beam.Attachment0 = a
	beam.Attachment1 = b
	beam.Color = l.colour
	beam.Transparency = l.fade or num(0.2, 1)
	beam.Width0 = l.w0 or 0.8
	beam.Width1 = l.w1 or 0
	beam.LightEmission = l.light or 1
	beam.LightInfluence = 0
	beam.FaceCamera = true
	beam.Segments = l.segments or 8
	if l.texture then
		beam.Texture = l.texture
		beam.TextureSpeed = l.textureSpeed or 1
		beam.TextureLength = l.textureLength or 4
	end
	beam.Parent = a.Parent
	return beam
end

-- What a trail builds at each exhaust. `x` is +1 or -1 (which exhaust); `ctx` has the exhausts, ribbon pairs and the tip.
type Ctx =
	{ at: Attachment, a: Attachment, b: Attachment, tip: Attachment, ground: Attachment, x: number, scale: number }
local BUILD: { [string]: (Ctx, { Color3 }, { Instance }, { (number, any) -> () }) -> () } = {}

BUILD.flame = function(c, k, out, _)
	local s = c.scale
	table.insert(
		out,
		emitter(c.at, {
			texture = FIRE,
			rate = 34,
			life = { 0.25, 0.4 },
			speed = { 9, 13 },
			size = num(1.3 * s, 0.2),
			colour = seq(Color3.fromRGB(255, 250, 200), k[1], k[2]),
			light = 1,
		})
	)
	table.insert(
		out,
		emitter(c.at, {
			texture = EMBER,
			rate = 16,
			life = { 0.4, 0.7 },
			speed = { 6, 12 },
			size = num(0.35 * s, 0),
			colour = seq(k[1], k[2]),
			spread = 45,
			accel = Vector3.new(0, 4, 0),
			light = 1,
		})
	)
	table.insert(
		out,
		emitter(c.at, {
			texture = SMOKE,
			rate = 5,
			life = { 0.8, 1.2 },
			speed = { 2, 4 },
			size = num(0.8 * s, 2.4 * s),
			colour = seq(Color3.fromRGB(120, 110, 110)),
			fade = num(0.7, 1),
			accel = Vector3.new(0, 3, 0),
			light = 0,
		})
	)
	table.insert(out, ribbon(c.a, c.b, { life = 0.3, colour = seq(k[1], k[2]), light = 1 }))
end

BUILD.comet = function(c, k, out, _)
	local s = c.scale
	table.insert(
		out,
		emitter(c.at, {
			texture = GLOW,
			rate = 26,
			life = { 0.15, 0.25 },
			speed = { 1, 2 },
			size = num(1.6 * s, 0.8 * s),
			colour = seq(Color3.new(1, 1, 1), k[1]),
			fade = num(0, 1),
			light = 1,
		})
	)
	table.insert(
		out,
		emitter(c.at, {
			texture = SQUARE,
			rate = 8,
			life = { 0.6, 1.1 },
			speed = { 3, 7 },
			size = num(0.3 * s, 0.05),
			colour = seq(k[1]),
			spread = 30,
			accel = Vector3.new(0, -8, 0),
			rot = true,
			spin = 200,
		})
	)
	table.insert(
		out,
		streak(c.at, c.tip, { colour = seq(Color3.new(1, 1, 1), k[1], k[2]), fade = num(0, 1), w0 = 1.2 * s, w1 = 0 })
	)
	table.insert(out, ribbon(c.a, c.b, { life = 1.1, colour = seq(k[1], k[2]), fade = num(0, 1) }))
end

BUILD.lightning = function(c, k, out, motion)
	local s = c.scale
	local bolt = streak(
		c.at,
		c.ground,
		{ colour = seq(Color3.new(1, 1, 1), k[1]), fade = num(0, 0.3), w0 = 0.35 * s, w1 = 0.15 * s, segments = 12 }
	)
	table.insert(out, bolt)
	local back = streak(
		c.at,
		c.tip,
		{ colour = seq(Color3.new(1, 1, 1), k[1]), fade = num(0, 1), w0 = 0.3 * s, w1 = 0.05, segments = 12 }
	)
	table.insert(out, back)
	table.insert(
		out,
		emitter(c.at, {
			rate = 18,
			life = { 0.2, 0.4 },
			speed = { 4, 9 },
			size = num(0.5 * s, 0),
			colour = seq(k[1]),
			spread = 70,
			light = 1,
		})
	)
	table.insert(out, ribbon(c.a, c.b, { life = 0.25, colour = seq(k[2], k[1]), width = num(0.4, 0) }))
	local nextBend = 0
	table.insert(motion, function(t: number)
		if t < nextBend then
			return
		end
		nextBend = t + 0.07 + math.random() * 0.06
		for _, beam in { bolt, back } do
			beam.CurveSize0 = math.random(-30, 30) / 10
			beam.CurveSize1 = math.random(-30, 30) / 10
			beam.Enabled = math.random() > 0.15
		end
	end)
end

BUILD.neon = function(c, k, out, motion)
	local s = c.scale
	local colour = if c.x > 0 then k[1] else (k[2] or k[1])
	local beam = streak(c.at, c.tip, { colour = seq(colour), fade = num(0, 1), w0 = 0.45 * s, w1 = 0.1, segments = 16 })
	table.insert(out, beam)
	table.insert(out, ribbon(c.a, c.b, { life = 0.6, colour = seq(colour), fade = num(0, 1), width = num(0.5, 0) }))
	table.insert(
		out,
		emitter(
			c.at,
			{ rate = 8, life = { 0.4, 0.7 }, speed = { 3, 5 }, size = num(0.3 * s, 0), colour = seq(colour), light = 1 }
		)
	)
	local home = c.at.Position
	table.insert(motion, function(t: number)
		-- the two ribbons twist round each other
		local a = t * 7 + (if c.x > 0 then 0 else math.pi)
		c.at.Position = home + Vector3.new(math.cos(a) * 0.5 * s, math.sin(a) * 0.5 * s, 0)
		beam.CurveSize0 = math.sin(a) * 2
		beam.CurveSize1 = -math.sin(a) * 2
	end)
end

BUILD.galaxy = function(c, k, out, _)
	local s = c.scale
	table.insert(
		out,
		emitter(c.at, {
			texture = SMOKE,
			rate = 10,
			life = { 0.8, 1.3 },
			speed = { 3, 5 },
			size = num(1 * s, 3 * s),
			colour = seq(k[1], k[2], k[3] or k[1]),
			fade = num(0.45, 1),
			light = 1,
		})
	)
	table.insert(
		out,
		emitter(c.at, {
			rate = 18,
			life = { 0.6, 1.2 },
			speed = { 2, 6 },
			size = num(0.4 * s, 0),
			colour = seq(Color3.new(1, 1, 1)),
			spread = 25,
			light = 1,
		})
	)
	table.insert(out, ribbon(c.a, c.b, { life = 0.7, colour = seq(k[1], k[2]), fade = num(0.2, 1) }))
end

BUILD.rainbow = function(c, k, out, _)
	local s = c.scale
	local art = GameIcons.uri and GameIcons.uri("ribbon_rainbow") or nil
	table.insert(
		out,
		streak(c.at, c.ground, {
			colour = seq(table.unpack(k)),
			fade = num(0, 0.9),
			w0 = 1.4 * s,
			w1 = 2.2 * s,
			texture = art,
			textureSpeed = 2,
		})
	)
	table.insert(
		out,
		emitter(c.at, {
			rate = 14,
			life = { 0.5, 0.9 },
			speed = { 2, 5 },
			size = num(0.45 * s, 0),
			colour = seq(Color3.new(1, 1, 1), k[3]),
			spread = 30,
			light = 1,
		})
	)
	table.insert(
		out,
		ribbon(
			c.a,
			c.b,
			{ life = 0.8, colour = seq(table.unpack(k)), fade = num(0, 1), faceCamera = false, width = num(1.6, 1.2) }
		)
	)
end

BUILD.bubble = function(c, k, out, _)
	local s = c.scale
	table.insert(
		out,
		emitter(c.at, {
			texture = GLOW,
			rate = 9,
			life = { 0.8, 1.3 },
			speed = { 2, 4 },
			size = num(0.7 * s, 1 * s),
			colour = seq(k[1], k[2]),
			fade = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.3),
				NumberSequenceKeypoint.new(0.85, 0.3),
				NumberSequenceKeypoint.new(1, 1),
			}),
			drag = 2,
			accel = Vector3.new(0, 2, 0),
			light = 0.8,
		})
	)
	-- the pop: little stars where the bubbles end
	table.insert(
		out,
		emitter(c.at, {
			rate = 7,
			life = { 0.25, 0.4 },
			speed = { 5, 7 },
			size = num(0.5 * s, 0),
			colour = seq(Color3.new(1, 1, 1)),
			spread = 60,
			light = 1,
		})
	)
	table.insert(
		out,
		ribbon(c.a, c.b, { life = 0.4, colour = seq(k[1], k[2]), fade = num(0.4, 1), width = num(0.5, 0) })
	)
end

BUILD.confetti = function(c, k, out, _)
	local s = c.scale
	for _, colour in k do
		table.insert(
			out,
			emitter(c.at, {
				texture = SQUARE,
				rate = 7,
				life = { 0.8, 1.3 },
				speed = { 4, 9 },
				size = num(0.3 * s),
				colour = seq(colour),
				fade = num(0, 1),
				spread = 50,
				accel = Vector3.new(0, -9, 0),
				rot = true,
				spin = 360,
				squash = num(0.6),
				light = 0.3,
			})
		)
	end
	table.insert(out, ribbon(c.a, c.b, { life = 0.5, colour = seq(k[1], k[2], k[3] or k[1]), width = num(0.25, 0.1) }))
end

BUILD.pixel = function(c, k, out, _)
	local s = c.scale
	for _, colour in k do
		table.insert(
			out,
			emitter(c.at, {
				texture = SQUARE,
				rate = 8,
				life = { 0.4, 0.8 },
				speed = { 5, 9 },
				size = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 0.5 * s),
					NumberSequenceKeypoint.new(0.5, 0.5 * s),
					NumberSequenceKeypoint.new(0.51, 0.3 * s),
					NumberSequenceKeypoint.new(1, 0.3 * s),
				}),
				colour = seq(colour),
				fade = num(0, 0.6),
				spread = 15,
				light = 1,
			})
		)
	end
	table.insert(out, ribbon(c.a, c.b, { life = 0.35, colour = seq(k[1], k[2]), width = num(0.5, 0.5) }))
end

BUILD.frost = function(c, k, out, _)
	local s = c.scale
	table.insert(
		out,
		emitter(c.at, {
			rate = 16,
			life = { 0.5, 0.9 },
			speed = { 3, 7 },
			size = num(0.5 * s, 0),
			colour = seq(Color3.new(1, 1, 1), k[1]),
			spread = 30,
			rot = true,
			spin = 90,
			light = 1,
		})
	)
	table.insert(
		out,
		emitter(c.at, {
			texture = SMOKE,
			rate = 7,
			life = { 0.8, 1.2 },
			speed = { 2, 3 },
			size = num(1 * s, 2.6 * s),
			colour = seq(k[1], k[2]),
			fade = num(0.55, 1),
			light = 0.4,
		})
	)
	table.insert(out, ribbon(c.a, c.b, { life = 0.6, colour = seq(Color3.new(1, 1, 1), k[2]), fade = num(0.2, 1) }))
end

BUILD.slime = function(c, k, out, _)
	local s = c.scale
	table.insert(
		out,
		emitter(c.at, {
			texture = GLOW,
			rate = 10,
			life = { 0.5, 0.9 },
			speed = { 1, 3 },
			size = num(0.6 * s, 0.3 * s),
			colour = seq(k[1], k[2]),
			fade = num(0.1, 1),
			accel = Vector3.new(0, -16, 0),
			light = 0.7,
		})
	)
	table.insert(
		out,
		emitter(c.at, {
			rate = 8,
			life = { 0.6, 1 },
			speed = { 2, 4 },
			size = num(0.4 * s, 0.6 * s),
			colour = seq(k[1]),
			fade = num(0.2, 1),
			accel = Vector3.new(0, 3, 0),
			light = 1,
		})
	)
	table.insert(
		out,
		ribbon(c.a, c.b, { life = 0.5, colour = seq(k[1], k[2]), fade = num(0.2, 1), width = num(0.8, 0.2) })
	)
end

BUILD.gold = function(c, k, out, _)
	local s = c.scale
	table.insert(
		out,
		emitter(c.at, {
			texture = EMBER,
			rate = 20,
			life = { 0.4, 0.7 },
			speed = { 6, 11 },
			size = num(0.4 * s, 0),
			colour = seq(k[2], k[1]),
			spread = 35,
			accel = Vector3.new(0, -6, 0),
			light = 1,
		})
	)
	table.insert(
		out,
		emitter(c.at, {
			texture = GLOW,
			rate = 5,
			life = { 0.7, 1 },
			speed = { 3, 6 },
			size = num(0.45 * s),
			colour = seq(k[1]),
			fade = num(0, 1),
			spread = 30,
			accel = Vector3.new(0, -10, 0),
			squash = num(-0.6),
			rot = true,
			spin = 300,
			light = 0.6,
		})
	)
	table.insert(out, ribbon(c.a, c.b, { life = 0.5, colour = seq(k[2], k[1]), fade = num(0.1, 1) }))
end

BUILD.vip = function(c, k, out, motion)
	local s = c.scale
	local beam =
		streak(c.at, c.tip, { colour = seq(k[1], k[2]), fade = num(0, 1), w0 = 0.7 * s, w1 = 0.1, textureSpeed = 1 })
	table.insert(out, beam)
	local tail = ribbon(c.a, c.b, { life = 0.8, colour = seq(k[1], k[2]), fade = num(0, 1) })
	table.insert(out, tail)
	table.insert(
		out,
		emitter(c.at, {
			rate = 14,
			life = { 0.5, 0.9 },
			speed = { 3, 6 },
			size = num(0.45 * s, 0),
			colour = seq(k[1]),
			spread = 30,
			light = 1,
		})
	)
	table.insert(motion, function(t: number)
		-- the gradient slides from gold to purple and back
		local f = (math.sin(t * 2) + 1) / 2
		local a, b = k[1]:Lerp(k[2], f), k[2]:Lerp(k[1], f)
		beam.Color = seq(a, b)
		tail.Color = seq(a, b)
	end)
end

export type Handle = {
	set: (self: Handle, item: Catalog.Item?) -> (),
	place: (self: Handle, tail: CFrame) -> (),
	setSpeed: (self: Handle, speed: number) -> (),
	clear: (self: Handle) -> (),
	destroy: (self: Handle) -> (),
}

local animated: { [any]: boolean } = {}
local clock: RBXScriptConnection? = nil
local function tick()
	local t = os.clock()
	for h in animated do
		for _, fn in h._motion do
			fn(t, h)
		end
	end
end
local function watch(h: any, on: boolean)
	if on then
		animated[h] = true
		if not clock then
			clock = RunService.Heartbeat:Connect(tick)
		end
	else
		animated[h] = nil
		if clock and next(animated) == nil then
			clock:Disconnect()
			clock = nil
		end
	end
end

local Fx = {}
Fx.__index = Fx

-- `holder` is a part that moves with the car; `tail` is the back of the car in world space (+Z away from the car); `width` is
-- the car's width, which spaces the two exhausts and sizes the effect.
function TrailFx.attach(holder: BasePart, tail: CFrame, width: number): Handle
	local self = setmetatable(
		{
			_holder = holder,
			_width = width,
			_scale = math.clamp(width / 5, 0.5, 1.6),
			_made = {},
			_attachments = {},
			_motion = {},
			_item = nil,
			_speed = 1,
		} :: any,
		Fx
	)
	self._tail = holder.CFrame:ToObjectSpace(tail)
	return self :: any
end

local function build(self: any)
	for _, i in self._made do
		i:Destroy()
	end
	for _, a in self._attachments do
		a:Destroy()
	end
	self._made, self._attachments, self._motion = {}, {}, {}
	watch(self, false)
	local item: Catalog.Item? = self._item
	if not item or item.isNone then
		return
	end
	local make = BUILD[item.key or ""]
	if not make then
		return
	end
	local function attach(name: string, cf: CFrame): Attachment
		local a = Instance.new("Attachment")
		a.Name = name
		a.CFrame = self._tail * cf
		a.Parent = self._holder
		table.insert(self._attachments, a)
		return a
	end
	local spread = self._width * 0.28
	for _, x in { 1, -1 } do
		local at = attach("Exhaust", CFrame.new(x * spread, -0.1, 0.2))
		local a = attach("RibbonA", CFrame.new(x * spread, 0.3 * self._scale, 0.2))
		local b = attach("RibbonB", CFrame.new(x * spread, -0.3 * self._scale, 0.2))
		local tip = attach("Tip", CFrame.new(x * spread * 0.6, 0, 9 * self._scale))
		local ground = attach("Ground", CFrame.new(x * spread * 1.2, -1.6, 6 * self._scale))
		make(
			{ at = at, a = a, b = b, tip = tip, ground = ground, x = x, scale = self._scale },
			item.colours,
			self._made,
			self._motion
		)
	end
	self:setSpeed(self._speed)
	watch(self, #self._motion > 0)
end

function Fx.set(self: any, item: Catalog.Item?)
	if self._item == item then
		return
	end
	self._item = item
	build(self)
end

function Fx.place(self: any, tail: CFrame)
	self._tail = self._holder.CFrame:ToObjectSpace(tail)
	build(self)
end

-- Faster cars push out more: 0 (parked) to 1 (full speed).
function Fx.setSpeed(self: any, speed: number)
	self._speed = math.clamp(speed, 0, 1)
	local k = 0.5 + 0.5 * self._speed
	for _, i in self._made do
		if i:IsA("ParticleEmitter") then
			i.Rate = (i:GetAttribute("BaseRate") :: number? or i.Rate) * k
		elseif i:IsA("Trail") then
			i.Lifetime = (i:GetAttribute("BaseLife") :: number? or i.Lifetime) * k
		end
	end
end

-- Forget the ribbon behind the car (after a teleport, so it never draws a line across the map).
function Fx.clear(self: any)
	for _, i in self._made do
		if i:IsA("Trail") or i:IsA("ParticleEmitter") then
			(i :: any):Clear()
		end
	end
end

function Fx.destroy(self: any)
	self._item = nil
	build(self)
end

return TrailFx
