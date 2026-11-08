--!strict
-- Trails.Kit (Round 8, T-01): the layer builders every trail recipe uses. A trail is built in layers from each exhaust point:
--   1 CORE      Kit.core      a thin white-hot Beam (+ the Trail ribbon that draws while the car moves)
--   2 BODY      Kit.body      a wider Beam with a scrolling texture (flame, energy, lightning ...), or Kit.ribbon (a Trail)
--   3 PARTICLES Kit.emit      ParticleEmitters, flipbooks from ParticleFX Studio (Drag, Squash and VelocityInheritance tuned)
--   4 TAIL      transparency and width curves that end at 1 and 0, so nothing ends in a hard cut
--   5 ROAD GLOW Kit.glow      a soft coloured patch on the road behind the car (Epic and up)
--   + SOUND     Kit.sound     one soft loop per car (Epic and up), in the player's "Effects" volume
-- Every builder returns nil when the quality or the tier says "not here", so a recipe is just a list of layers by tier.
-- The context `c` is made by Style/TrailFx.luau for each exhaust point; recipes live in Warm / Cool / Wild.

local AudioMix = require(script.Parent.Parent.Parent.AudioMix) :: any
local Textures = require(script.Parent.Textures)

local Kit = {}

export type Quality = "full" | "phone" | "low"

export type Tip = { att: Attachment, home: CFrame, off: Vector3 }

export type Shared = {
	alive: number, -- particles alive at full rate, summed over every emitter of the car (the cap input)
	glow: Part?,
	sound: Sound?,
	soundBase: number,
	first: Attachment?, -- the first exhaust's emission point (Lightning jumps between the two)
	mid: CFrame, -- holder-relative: on the road at the middle of the car's rear end
	count: number, -- exhaust points
}

export type Ctx = {
	holder: BasePart,
	item: any,
	k: { Color3 }, -- the trail's colours (or the paint's, when MATCH MY PAINT is on)
	paint: Color3?, -- the equipped paint colour (nil when match-paint is off)
	tier: number, -- 1 Common .. 6 Robux / VIP
	quality: Quality,
	reduce: boolean, -- Reduce Motion: half the particles, calmer wiggles
	scale: number, -- the car's size factor (about width / 5)
	rateMul: number, -- quality and Reduce Motion multiplier on emission
	amp: number, -- 1, or 0.5 with Reduce Motion: how wild the wiggle motion is
	at: Attachment, -- the emission point, +Z away from the car
	a: Attachment, -- vertical pair for ribbons (a above b)
	b: Attachment,
	tip: Attachment, -- 7 studs behind and a little down
	tip2: Attachment, -- 11 studs behind
	ground: Attachment, -- on the road behind
	side: number, -- -1 left, +1 right, 0 middle
	index: number, -- 1-based exhaust number
	count: number,
	height: number, -- the point's height above the road
	home: CFrame, -- the point relative to the holder
	out: { Instance },
	tips: { Tip },
	motion: { (number, any) -> () },
	shared: Shared,
	wheel: boolean, -- this point is a rear wheel (Drift Smoke)
}

local P = "rbxasset://textures/particles/"
local SPARKLE = P .. "sparkles_main.dds"

-- Per-tier cap on particles alive at once, both exhausts, full quality, top speed. Phone halves emission on top of this.
Kit.CAP = table.freeze({ 45, 90, 150, 220, 300, 380 })

-- Small helpers --------------------------------------------------------------------------------------------------------------------

function Kit.seq(...: Color3): ColorSequence
	local list = { ... }
	if #list == 0 then
		return ColorSequence.new(Color3.new(1, 1, 1))
	end
	if #list == 1 then
		return ColorSequence.new(list[1])
	end
	local keys = {}
	for i, c in list do
		table.insert(keys, ColorSequenceKeypoint.new((i - 1) / (#list - 1), c))
	end
	return ColorSequence.new(keys)
end

function Kit.num(a: number, b: number?): NumberSequence
	return if b then NumberSequence.new(a, b) else NumberSequence.new(a)
end

-- A NumberSequence through points {t, v}.
function Kit.curve(points: { { number } }): NumberSequence
	local keys = {}
	for _, p in points do
		table.insert(keys, NumberSequenceKeypoint.new(p[1], p[2]))
	end
	return NumberSequence.new(keys)
end

-- The usual fade: solid for a while, then dissolving to nothing.
function Kit.fadeOut(solid: number, start: number?): NumberSequence
	local from = start or 0.55
	return Kit.curve({ { 0, solid }, { from, math.min(solid + 0.15, 1) }, { 1, 1 } })
end

local function setProp(inst: Instance, prop: string, value: any)
	pcall(function()
		(inst :: any)[prop] = value
	end)
end

-- Tint a colour toward white (for hot cores).
function Kit.hot(c: Color3, amount: number): Color3
	return c:Lerp(Color3.new(1, 1, 1), amount)
end

-- Frame helpers --------------------------------------------------------------------------------------------------------------------

-- A new attachment at `off` (studs, the exhaust point's own frame: +Z back, +Y up) from this exhaust point.
function Kit.attach(c: Ctx, name: string, off: CFrame): Attachment
	local a = Instance.new("Attachment")
	a.Name = name
	a.CFrame = c.home * off
	a.Parent = c.holder
	table.insert(c.out, a)
	return a
end

-- An attachment whose distance behind the car follows speed (setSpeed scales its offset).
function Kit.tipAt(c: Ctx, name: string, off: Vector3): Attachment
	local a = Kit.attach(c, name, CFrame.new(off))
	table.insert(c.tips, { att = a, home = c.home, off = off })
	return a
end

function Kit.motion(c: Ctx, fn: (number, any) -> ())
	table.insert(c.motion, fn)
end

-- Layers ---------------------------------------------------------------------------------------------------------------------------

export type Emit = {
	tier: number?, -- build only from this tier up
	sheet: string?, -- Textures name (a flipbook or a single image)
	texture: string?, -- or a raw texture
	rate: number,
	life: { number },
	speed: { number },
	size: NumberSequence?,
	colour: ColorSequence?,
	fade: NumberSequence?,
	spread: number?,
	accel: Vector3?,
	drag: number?,
	rot: boolean?, -- random start rotation
	spin: number?, -- degrees a second, either way
	light: number?, -- LightEmission
	squash: NumberSequence?,
	mode: string?, -- "OneShot" (default for sheets) | "Loop" | "PingPong" | "Random"
	fps: number?, -- Loop mode speed (max 30)
	orient: string?, -- "velocity" = aligned with its movement
	inherit: number?, -- VelocityInheritance 0..1
	locked: boolean?, -- LockedToPart
	from: Attachment?, -- emit from another attachment than the exhaust point
	brightness: number?,
	random: boolean?, -- start on a random frame
}

function Kit.emit(c: Ctx, spec: Emit): ParticleEmitter?
	if c.quality == "low" or (spec.tier ~= nil and c.tier < spec.tier) then
		return nil
	end
	local sheet = if spec.sheet then Textures.get(spec.sheet) else nil
	local e = Instance.new("ParticleEmitter")
	e.Texture = if sheet then sheet.texture elseif spec.texture then spec.texture else SPARKLE
	if sheet and sheet.layout ~= Enum.ParticleFlipbookLayout.None then
		e.FlipbookLayout = sheet.layout
		local mode = spec.mode or "OneShot"
		e.FlipbookMode = (Enum.ParticleFlipbookMode :: any)[mode]
		if mode == "Loop" or mode == "PingPong" then
			local fps = math.clamp(spec.fps or 24, 1, 30)
			e.FlipbookFramerate = NumberRange.new(fps * 0.8, fps)
		end
		if spec.random then
			e.FlipbookStartRandom = true
		end
	end
	local rate = spec.rate * c.rateMul
	e.Rate = rate
	e.Lifetime = NumberRange.new(spec.life[1], spec.life[2] or spec.life[1])
	e.Speed = NumberRange.new(spec.speed[1], spec.speed[2] or spec.speed[1])
	e.Size = spec.size or Kit.num(0.6 * c.scale, 0)
	e.Color = spec.colour or Kit.seq(Color3.new(1, 1, 1))
	e.Transparency = spec.fade or Kit.num(0, 1)
	local spread = spec.spread or 10
	e.SpreadAngle = Vector2.new(spread, spread)
	e.Acceleration = spec.accel or Vector3.zero
	e.Drag = spec.drag or 0
	e.Rotation = NumberRange.new(0, if spec.rot then 360 else 0)
	e.RotSpeed = NumberRange.new(-(spec.spin or 0), spec.spin or 0)
	e.LightEmission = spec.light or 0.6
	e.LightInfluence = 0
	e.EmissionDirection = Enum.NormalId.Back -- away from the car
	if spec.squash then
		e.Squash = spec.squash
	end
	if spec.orient == "velocity" then
		e.Orientation = Enum.ParticleOrientation.VelocityParallel
	end
	if spec.inherit then
		e.VelocityInheritance = spec.inherit
	end
	if spec.locked then
		e.LockedToPart = true
	end
	if spec.brightness then
		setProp(e, "Brightness", spec.brightness)
	end
	local avg = (spec.life[1] + (spec.life[2] or spec.life[1])) / 2
	e:SetAttribute("BaseRate", rate)
	e:SetAttribute("Alive", rate * avg)
	c.shared.alive += rate * avg
	e.Parent = spec.from or c.at
	table.insert(c.out, e)
	return e
end

export type Ribbon = {
	a: Attachment?,
	b: Attachment?,
	life: number?,
	colour: ColorSequence,
	fade: NumberSequence?,
	width: NumberSequence?,
	light: number?,
	faceCamera: boolean?, -- false = a flat ribbon that lies in the plane of its two attachments
	sheet: string?, -- Textures name for a ribbon texture
	textureLength: number?,
	wrap: boolean?,
	brightness: number?,
	minLength: number?,
}

-- A ribbon that draws while the car moves (a Trail between two attachments).
function Kit.ribbon(c: Ctx, spec: Ribbon): Trail
	local t = Instance.new("Trail")
	t.Attachment0 = spec.a or c.a
	t.Attachment1 = spec.b or c.b
	t.Lifetime = spec.life or 0.5
	t.Color = spec.colour
	t.Transparency = spec.fade or Kit.curve({ { 0, 0.25 }, { 1, 1 } })
	t.WidthScale = spec.width or Kit.num(1, 0)
	t.LightEmission = spec.light or 0.7
	t.LightInfluence = 0
	t.FaceCamera = spec.faceCamera ~= false
	t.MinLength = spec.minLength or 0.05
	if spec.sheet then
		local uri = Textures.uri(spec.sheet)
		if uri ~= "" then
			t.Texture = uri
			t.TextureMode = if spec.wrap then Enum.TextureMode.Wrap else Enum.TextureMode.Stretch
			t.TextureLength = spec.textureLength or 1
		end
	end
	if spec.brightness then
		setProp(t, "Brightness", spec.brightness)
	end
	t:SetAttribute("BaseLife", t.Lifetime)
	t.Parent = (spec.a or c.a).Parent
	table.insert(c.out, t)
	return t
end

export type BeamSpec = {
	from: Attachment?,
	to: Attachment?,
	colour: ColorSequence,
	fade: NumberSequence?,
	w0: number,
	w1: number,
	light: number?,
	segments: number?,
	sheet: string?, -- a beam texture (runs along the beam, repeats)
	speed: number?, -- texture scroll
	textureLength: number?,
	faceCamera: boolean?,
	curve0: number?,
	curve1: number?,
	brightness: number?,
}

-- A beam from the exhaust to a point behind it: it draws even when the car stands still.
function Kit.beam(c: Ctx, spec: BeamSpec): Beam
	local beam = Instance.new("Beam")
	beam.Attachment0 = spec.from or c.at
	beam.Attachment1 = spec.to or c.tip
	beam.Color = spec.colour
	beam.Transparency = spec.fade or Kit.curve({ { 0, 0.2 }, { 1, 1 } })
	beam.Width0 = spec.w0
	beam.Width1 = spec.w1
	beam.LightEmission = spec.light or 1
	beam.LightInfluence = 0
	beam.FaceCamera = spec.faceCamera ~= false
	beam.Segments = spec.segments or 10
	if spec.curve0 then
		beam.CurveSize0 = spec.curve0
	end
	if spec.curve1 then
		beam.CurveSize1 = spec.curve1
	end
	if spec.sheet then
		local uri = Textures.uri(spec.sheet)
		if uri ~= "" then
			beam.Texture = uri
			beam.TextureMode = Enum.TextureMode.Wrap
			beam.TextureSpeed = if c.reduce then (spec.speed or 1) * 0.5 else (spec.speed or 1)
			beam.TextureLength = spec.textureLength or math.max((spec.w0 + spec.w1) / 2, 0.5)
		end
	end
	if spec.brightness then
		setProp(beam, "Brightness", spec.brightness)
	end
	beam:SetAttribute("BaseW0", spec.w0)
	beam:SetAttribute("BaseW1", spec.w1)
	beam.Parent = (spec.from or c.at).Parent
	table.insert(c.out, beam)
	return beam
end

-- 1 CORE: the thin white-hot streak down the middle.
function Kit.core(c: Ctx, colour: ColorSequence, w0: number, w1: number?): Beam
	return Kit.beam(c, {
		colour = colour,
		fade = Kit.curve({ { 0, 0.1 }, { 0.4, 0.4 }, { 0.75, 0.88 }, { 1, 1 } }),
		w0 = w0 * 0.5,
		w1 = (w1 or w0 * 0.15) * 0.5,
		segments = 12,
		light = 1,
		brightness = 1.4,
	})
end

-- A soft coloured glow on the road behind the car, one per car (Epic and up). A flat part with a SurfaceGui, glued to the car each frame.
function Kit.glow(c: Ctx, colour: Color3, width: number, length: number, alpha: number?, pulse: number?)
	if c.quality == "low" or c.shared.glow ~= nil then
		return
	end
	local part = Instance.new("Part")
	part.Name = "RoadGlow"
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Transparency = 1
	part.Size = Vector3.new(width, 0.1, length)
	local rel = c.shared.mid * CFrame.new(0, 0.12, length * 0.5 - 1.5)
	part.CFrame = c.holder.CFrame * rel
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Top
	gui.LightInfluence = 0
	gui.AlwaysOnTop = false
	gui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
	gui.CanvasSize = Vector2.new(256, 256)
	gui.Brightness = 3
	gui.Parent = part
	local base = alpha or 0.45
	local layers: { GuiObject } = {}
	local uri = Textures.get("glow")
	if uri.uploaded then
		local img = Instance.new("ImageLabel")
		img.BackgroundTransparency = 1
		img.Size = UDim2.fromScale(1, 1)
		img.Image = uri.texture
		img.ImageColor3 = colour
		img.ImageTransparency = 1 - base
		img.Parent = gui
		table.insert(layers, img)
	else
		-- before the art exists: three round frames, brighter toward the middle
		for i = 1, 3 do
			local f = Instance.new("Frame")
			f.AnchorPoint = Vector2.new(0.5, 0.5)
			f.Position = UDim2.fromScale(0.5, 0.5)
			local size = 1.0 - (i - 1) * 0.28
			f.Size = UDim2.fromScale(size, size)
			f.BackgroundColor3 = colour
			f.BackgroundTransparency = 1 - base * (0.25 + i * 0.2)
			f.BorderSizePixel = 0
			local corner = Instance.new("UICorner")
			corner.CornerRadius = UDim.new(0.5, 0)
			corner.Parent = f
			f.Parent = gui
			table.insert(layers, f)
		end
	end
	part.Parent = workspace -- not inside the car, so the car's size and pivot never change
	c.shared.glow = part
	table.insert(c.out, part)
	local holder = c.holder
	Kit.motion(c, function(t: number)
		if not part.Parent then
			return
		end
		if not holder:IsDescendantOf(game) then
			part:Destroy() -- the car went without calling destroy: never leave a glow behind
			return
		end
		part.CFrame = holder.CFrame * rel
		if pulse and not c.reduce then
			local f = 0.78 + 0.22 * math.sin(t * pulse * math.pi * 2)
			for i, l in layers do
				if l:IsA("ImageLabel") then
					l.ImageTransparency = 1 - base * f
				else
					l.BackgroundTransparency = 1 - base * (0.25 + i * 0.2) * f
				end
			end
		end
	end)
end

-- One soft loop per car (Epic and up), in the player's Effects volume. `name` is Textures.sound's name.
function Kit.sound(c: Ctx, name: string, volume: number, pitch: number?)
	if c.quality ~= "full" or c.shared.sound ~= nil then
		return
	end
	local s = Instance.new("Sound")
	s.Name = "TrailLoop"
	s.SoundId = Textures.sound(name)
	s.Looped = true
	s.Volume = volume
	s.PlaybackSpeed = pitch or 1
	s.RollOffMode = Enum.RollOffMode.Linear
	s.RollOffMinDistance = 8
	s.RollOffMaxDistance = 70
	s.SoundGroup = AudioMix.group("Effects")
	s.Parent = c.holder
	s:Play()
	c.shared.sound = s
	c.shared.soundBase = volume
	table.insert(c.out, s)
end

-- Cap: scale every emitter's rate so the car's live particles stay under the tier cap (and update the stored base rate).
function Kit.applyCap(made: { Instance }, tier: number)
	local alive = 0
	for _, i in made do
		if i:IsA("ParticleEmitter") then
			alive += (i:GetAttribute("Alive") :: number?) or 0
		end
	end
	local cap = Kit.CAP[math.clamp(tier, 1, #Kit.CAP)]
	if alive <= cap or alive <= 0 then
		return alive
	end
	local f = cap / alive
	for _, i in made do
		if i:IsA("ParticleEmitter") then
			local base = ((i:GetAttribute("BaseRate") :: number?) or i.Rate) * f
			i:SetAttribute("BaseRate", base)
			i:SetAttribute("Alive", ((i:GetAttribute("Alive") :: number?) or 0) * f)
			i.Rate = base
		end
	end
	return cap
end

-- A deterministic little pseudo-random in 0..1 from a time and a seed (for flicker that needs no state).
function Kit.hash(t: number, seed: number): number
	local v = math.sin(t * 12.9898 + seed * 78.233) * 43758.5453
	return v - math.floor(v)
end

Kit.Textures = Textures

return Kit
