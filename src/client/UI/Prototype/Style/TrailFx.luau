--!strict
-- TrailFx (Round 8, T-01 to T-12; first built in Round 7): the trails, built in layers from each EXHAUST point of the car:
--   core (a thin white-hot Beam and Trail), body (a wider textured Beam or ribbon), particles (ParticleFX Studio flipbooks), a fading
--   tail (every curve ends at nothing), a road glow under the car and a soft loop (Epic and up). The recipes are in Style/Trails/
--   (Warm, Cool, Wild: 18 trails, one function each) on top of Style/Trails/Kit.luau (the layer builders) and Textures.luau.
--
-- Cosmetic only: no trail changes a run. Particles stream backwards even when the car stands still and the beams draw standing too,
-- so the Style Shop turntable and the Launch Pad show the trail (a Trail ribbon only draws while the car moves).
--
-- Where the exhausts are (T-02): src/shared/Style/Anchors/Exhausts.luau, per car, one or two points at the real tail pipes. A handle
-- finds them from the car's model name (CarName attribute, or the model name without Gold/Diamond/Rainbow). A car with no entry falls
-- back to the old two points either side of the tail.
--
--   local fx = TrailFx.attach(holder: BasePart, tail: CFrame, width: number, options: Options?) -> Handle     (Round 7 API, kept)
--   local fx = TrailFx.attachModel(model: Model, options: Options?) -> Handle                                (Round 8: finds the holder)
--   fx:set(item?)   fx:place(tail: CFrame)   fx:setSpeed(0..1)   fx:clear()   fx:destroy()                   (Round 7 API, kept)
--   Round 8 additions:
--   fx:setMatchPaint(colour: Color3?)   T-08: Neon Ribbon, Comet Tail and Drift Smoke take their colours from this (nil = off)
--   fx:setQuality("full"|"phone"|"low") phone: about half the emission; low: beams and ribbons only, no particles, glow or sound
--   fx:setReduceMotion(on: boolean?)    half the particles, calmer wiggle; nil = follow the player's setting
--   fx:setLevel(step: number)           T-05: a hop chain, 0..3: bigger, brighter, more particles
--   fx:flare(seconds: number?)          T-03: a brief brighter, longer, wider moment (top speed, after a dive)
--   fx:setSoundEnabled(on: boolean)     fx:stats() -> { emitters, alive, beams, ribbons, ... }   fx:exhausts() -> { Attachment }
--   TrailFx.tierOf(item) -> 1..6        TrailFx.supportsMatchPaint(item) -> boolean    TrailFx.autoQuality() -> Quality
--   TrailFx.exhaustsFor(carName) -> Anchors.Exhausts?   TrailFx.CAP (per tier)
--
-- Speed (T-03): setSpeed scales emission, ribbon life, beam width and length: 0 = standing (a short gentle trail), 1 = run speed.

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Catalog = require(ReplicatedStorage.Shared.UI.CosmeticPreviewCatalog)
local Exhausts = require(ReplicatedStorage.Shared.Style.Anchors.Exhausts)
local Kit = require(script.Parent.Trails.Kit)
local Warm = require(script.Parent.Trails.Warm)
local Cool = require(script.Parent.Trails.Cool)
local Wild = require(script.Parent.Trails.Wild)

local TrailFx = {}

export type Quality = Kit.Quality

export type Options = {
	model: Model?, -- the car (finds its exhaust points)
	car: string?, -- the car's name when the model is not named for it
	quality: Quality?,
	reduceMotion: boolean?,
	paint: Color3?, -- MATCH MY PAINT colour
}

type Recipe = (Kit.Ctx) -> ()

local RECIPES: { [string]: Recipe } = {
	flame = Warm.flame,
	comet = Warm.comet,
	gold = Warm.gold,
	confetti = Warm.confetti,
	money = Warm.money,
	pixel = Warm.pixel,
	neon = Cool.neon,
	bubble = Cool.bubble,
	frost = Cool.frost,
	lightning = Cool.lightning,
	aurora = Cool.aurora,
	retro = Cool.retro,
	galaxy = Wild.galaxy,
	rainbow = Wild.rainbow,
	slime = Wild.slime,
	vip = Wild.vip,
	petal = Wild.petal,
	drift = Wild.drift,
}

-- The visual tier of each catalog tier (T-06): 1 Common ribbon, 2 + light particles, 3 + sparks and a second layer, 4 + animated
-- texture, road glow and a soft loop, 5 + flares, pulse and a third layer, 6 the flashiest (Robux and VIP).
local TIER: { [string]: number } = { starter = 1, street = 2, track = 3, elite = 4, legendary = 5, robux = 6, vip = 6 }

-- Trails that may take the colour of the equipped paint (T-08).
local MATCH: { [string]: boolean } = { neon = true, comet = true, drift = true }

TrailFx.CAP = Kit.CAP

function TrailFx.tierOf(item: Catalog.Item?): number
	if not item then
		return 1
	end
	return TIER[item.tier] or 3
end

function TrailFx.supportsMatchPaint(item: Catalog.Item?): boolean
	return item ~= nil and item.key ~= nil and MATCH[item.key] == true
end

function TrailFx.exhaustsFor(carName: string): any
	return Exhausts[carName]
end

function TrailFx.autoQuality(): Quality
	local lp = Players.LocalPlayer
	local profile = if lp then lp:GetAttribute("Lane3ScreenProfile") else nil
	if type(profile) == "string" then
		return if string.find(profile, "Phone", 1, true) then "phone" else "full"
	end
	if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
		return "phone"
	end
	return "full"
end

local function reducedMotion(): boolean
	local lp = Players.LocalPlayer
	local override = if lp then lp:GetAttribute("Lane3ReducedMotionOverride") else nil
	if type(override) == "boolean" then
		return override
	end
	return GuiService.ReducedMotionEnabled
end

-- The colours a trail is built with: its own, or (MATCH MY PAINT) the paint's.
local function matchColours(key: string, p: Color3): { Color3 }
	local h, s, v = p:ToHSV()
	local accent = Color3.fromHSV((h + 0.07) % 1, math.clamp(s, 0.35, 1), math.clamp(v, 0.6, 1))
	if key == "comet" then
		return { p:Lerp(Color3.new(1, 1, 1), 0.5), p }
	elseif key == "drift" then
		return { p, p:Lerp(Color3.new(1, 1, 1), 0.3) }
	end
	return { p, accent }
end

-- Where the car's own frame is ----------------------------------------------------------------------------------------------------

local EDITION_PREFIX = { "Gold ", "Diamond ", "Rainbow " }

local function carKey(model: Model): string
	local name = model:GetAttribute("CarName")
	if type(name) == "string" and name ~= "" then
		return name
	end
	for _, prefix in EDITION_PREFIX do
		if string.sub(model.Name, 1, #prefix) == prefix then
			return string.sub(model.Name, #prefix + 1)
		end
	end
	return model.Name
end

local storedScales: { [string]: number } = {}
local function storedScale(key: string): number
	local cached = storedScales[key]
	if cached then
		return cached
	end
	local cars = ReplicatedStorage:FindFirstChild("Cars")
	local stored = if cars then cars:FindFirstChild(key) else nil
	local scale = if stored and stored:IsA("Model") then stored:GetScale() else 1
	storedScales[key] = scale
	return scale
end

local function findHolder(model: Model): BasePart?
	local body = model:FindFirstChild("body_geom", true)
	if body and body:IsA("BasePart") then
		return body
	end
	if model.PrimaryPart then
		return model.PrimaryPart
	end
	local best: BasePart? = nil
	local bestVolume = 0
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			local v = d.Size.X * d.Size.Y * d.Size.Z
			if v > bestVolume then
				best, bestVolume = d, v
			end
		end
	end
	return best
end

type Frame = {
	rel: CFrame, -- the car's frame relative to the holder
	points: { CFrame }, -- exhaust points in the car's frame (scaled)
	scale: number, -- effect size factor
	height: { number }, -- each point's height above the road
	wheel: boolean, -- the points are rear wheels (Drift Smoke)
}

local function rearWheels(model: Model, frame: CFrame, ratio: number): { CFrame }
	local out: { CFrame } = {}
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			local n = string.lower(d.Name)
			if string.find(n, "rear", 1, true) and string.find(n, "wheel", 1, true) then
				local at = frame:PointToObjectSpace(d.Position)
				local radius = math.max(d.Size.X, d.Size.Y, d.Size.Z) / 2
				table.insert(out, CFrame.new(at.X, math.max(radius * 0.4, 0.3 * ratio), at.Z + radius * 0.55))
			end
		end
	end
	return out
end

local Fx = {}
Fx.__index = Fx

local function frameOf(self: any, drift: boolean): Frame
	local holder: BasePart = self._holder
	local model: Model? = self._model
	if model and model.Parent then
		local key = self._car or carKey(model)
		local data = Exhausts[key]
		if data then
			local world = model:GetPivot()
			local ratio = model:GetScale() / storedScale(key)
			local points: { CFrame } = {}
			local heights: { number } = {}
			local wheel = false
			if drift then
				local wheels = rearWheels(model, world, ratio)
				if #wheels > 0 then
					points, wheel = wheels, true
				end
			end
			if not wheel then
				for _, cf in data.points do
					table.insert(points, CFrame.new(cf.Position * ratio) * (cf - cf.Position))
				end
			end
			for _, p in points do
				table.insert(heights, math.max(p.Position.Y, 0.3))
			end
			local width = self._width
			if not width then
				local _, size = model:GetBoundingBox()
				width = size.X
			end
			return {
				rel = holder.CFrame:ToObjectSpace(world),
				points = points,
				scale = math.clamp((width :: number) / 5, 0.5, 1.6),
				height = heights,
				wheel = wheel,
			}
		end
	end
	-- no per-car data: two points either side of the tail, as in Round 7
	local width: number = self._width
	local spread = width * 0.28
	local tail: CFrame = self._tailWorld
	return {
		rel = holder.CFrame:ToObjectSpace(tail),
		points = { CFrame.new(spread, -0.1, 0.2), CFrame.new(-spread, -0.1, 0.2) },
		scale = math.clamp(width / 5, 0.5, 1.6),
		height = { 1, 1 },
		wheel = false,
	}
end

-- Building -----------------------------------------------------------------------------------------------------------------------

local animated: { [any]: boolean } = {}
local clock: RBXScriptConnection? = nil

local function tick()
	local t = os.clock()
	for h in animated do
		for _, fn in h._motion do
			fn(t, h)
		end
		if h._flareStart then
			h:_stepFlare(t)
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

local function teardown(self: any)
	for _, i in self._made do
		i:Destroy()
	end
	self._made, self._tips, self._motion, self._shared = {}, {}, {}, nil
	watch(self, false)
end

local function build(self: any)
	teardown(self)
	local item: Catalog.Item? = self._item
	if not item or item.isNone then
		return
	end
	local key = item.key or ""
	local make = RECIPES[key]
	if not make then
		return
	end
	local holder: BasePart = self._holder
	local reduce: boolean = if self._reduce ~= nil then self._reduce else reducedMotion()
	local quality: Quality = self._quality
	local tier = TIER[item.tier] or 3
	local frame = frameOf(self, key == "drift")
	local colours = item.colours
	if self._paint and MATCH[key] then
		colours = matchColours(key, self._paint)
	end
	local rateMul = (if quality == "phone" then 0.5 else 1) * (if reduce then 0.5 else 1)
	local maxZ, sumX = 0, 0
	for _, p in frame.points do
		maxZ = math.max(maxZ, p.Position.Z)
		sumX += p.Position.X
	end
	local shared: Kit.Shared = {
		alive = 0,
		soundBase = 0,
		first = nil,
		mid = frame.rel * CFrame.new(sumX / math.max(#frame.points, 1), 0, maxZ),
		count = #frame.points,
	}
	self._shared = shared
	local s = frame.scale
	for index, point in frame.points do
		local home = frame.rel * point
		local height = frame.height[index]
		local side = if #frame.points == 1 then 0 else math.sign(point.Position.X)
		local c: any = {
			holder = holder,
			item = item,
			k = colours,
			paint = self._paint,
			tier = tier,
			quality = quality,
			reduce = reduce,
			scale = s,
			rateMul = rateMul,
			amp = if reduce then 0.5 else 1,
			side = side,
			index = index,
			count = #frame.points,
			height = height,
			home = home,
			out = self._made,
			tips = self._tips,
			motion = self._motion,
			shared = shared,
			wheel = frame.wheel,
		}
		c.at = Kit.attach(c, "Exhaust", CFrame.identity)
		c.a = Kit.attach(c, "RibbonA", CFrame.new(0, 0.2 * s, 0))
		c.b = Kit.attach(c, "RibbonB", CFrame.new(0, -0.2 * s, 0))
		local out = if side == 0 then 0.3 else side
		c.tip = Kit.tipAt(c, "Tip", Vector3.new(out * 0.4 * s, -0.18 * height, 7 * s))
		c.tip2 = Kit.tipAt(c, "Tip2", Vector3.new(out * 0.8 * s, -0.35 * height, 11.5 * s))
		c.ground = Kit.tipAt(c, "Ground", Vector3.new(out * 1.2 * s, -height + 0.1, 6 * s))
		make(c :: Kit.Ctx)
		-- every step up the ladder adds a glitter layer of its own (T-06): Legendary one, Robux and VIP two
		local first, second = colours[1], colours[2] or colours[1]
		if tier >= 5 then
			Kit.emit(c, {
				sheet = "flare",
				rate = 8,
				life = { 0.5, 0.9 },
				speed = { 2, 6 },
				size = Kit.num(0.8 * s, 0),
				colour = Kit.seq(Color3.new(1, 1, 1), first),
				spread = 60,
				light = 1,
				rot = true,
			})
		end
		if tier >= 6 then
			Kit.emit(c, {
				sheet = "stars",
				rate = 6,
				life = { 0.7, 1.2 },
				speed = { 2, 5 },
				size = Kit.num(1.6 * s, 0.2 * s),
				colour = Kit.seq(Color3.new(1, 1, 1), second),
				spread = 50,
				light = 1,
				random = true,
				mode = "Random",
			})
		end
	end
	Kit.applyCap(self._made, tier)
	self._tier = tier
	self:setSpeed(self._speed)
	watch(self, #self._motion > 0)
end

-- The public handle -------------------------------------------------------------------------------------------------------------

export type Handle = {
	set: (self: Handle, item: Catalog.Item?) -> (),
	place: (self: Handle, tail: CFrame) -> (),
	setSpeed: (self: Handle, speed: number) -> (),
	clear: (self: Handle) -> (),
	destroy: (self: Handle) -> (),
	setMatchPaint: (self: Handle, colour: Color3?) -> (),
	setQuality: (self: Handle, quality: Quality) -> (),
	setReduceMotion: (self: Handle, on: boolean?) -> (),
	setLevel: (self: Handle, step: number) -> (),
	flare: (self: Handle, seconds: number?) -> (),
	setSoundEnabled: (self: Handle, on: boolean) -> (),
	stats: (self: Handle) -> { [string]: number },
	exhausts: (self: Handle) -> { Attachment },
}

-- `holder` is a part that moves with the car; `tail` is the back of the car in world space (+Z away from the car), used only when the
-- car has no Exhausts entry; `width` is the car's width, which sizes the effect.
function TrailFx.attach(holder: BasePart, tail: CFrame, width: number, options: Options?): Handle
	local opts = options or {}
	local self = setmetatable(
		{
			_holder = holder,
			_width = width,
			_made = {},
			_tips = {},
			_motion = {},
			_item = nil,
			_speed = 1,
			_level = 0,
			_flare = 0,
			_quality = opts.quality or TrailFx.autoQuality(),
			_reduce = opts.reduceMotion,
			_paint = opts.paint,
			_tailWorld = tail,
			_soundOn = true,
		} :: any,
		Fx
	)
	if opts.model then
		local key = opts.car or carKey(opts.model)
		if Exhausts[key] then
			self._model = opts.model
			self._car = key
		end
	else
		-- walk up from the holder to the car model (Putter > body > body_geom: the car is the one with an Exhausts entry)
		local ancestor: Instance? = holder.Parent
		while ancestor do
			if ancestor:IsA("Model") then
				local key = opts.car or carKey(ancestor)
				if Exhausts[key] then
					self._model = ancestor
					self._car = key
					break
				end
			end
			ancestor = ancestor.Parent
		end
	end
	return self :: any
end

-- Dress a car model: finds the holder part and the exhaust points from the model itself.
function TrailFx.attachModel(model: Model, options: Options?): Handle
	local holder = findHolder(model)
	assert(holder, "TrailFx.attachModel: the car has no part")
	local opts = table.clone(options or {})
	opts.model = model
	local _, size = model:GetBoundingBox()
	return TrailFx.attach(holder, model:GetPivot(), size.X, opts)
end

function Fx.set(self: any, item: Catalog.Item?)
	if self._item == item then
		return
	end
	self._item = item
	build(self)
end

function Fx.place(self: any, tail: CFrame)
	self._tailWorld = tail
	build(self)
end

function Fx.setMatchPaint(self: any, colour: Color3?)
	if self._paint == colour then
		return
	end
	self._paint = colour
	local item: Catalog.Item? = self._item
	if item and MATCH[item.key or ""] then
		build(self)
	end
end

function Fx.setQuality(self: any, quality: Quality)
	if self._quality == quality then
		return
	end
	self._quality = quality
	build(self)
end

function Fx.setReduceMotion(self: any, on: boolean?)
	if self._reduce == on then
		return
	end
	self._reduce = on
	build(self)
end

-- A hop chain (T-05): 0 to 3 steps, each a little bigger, brighter and fuller.
function Fx.setLevel(self: any, step: number)
	self._level = math.clamp(math.floor(step), 0, 3)
	self:setSpeed(self._speed)
end

-- Speed 0 (parked) to 1 (run speed): emission, ribbon life, beam width and length follow it (T-03).
function Fx.setSpeed(self: any, speed: number)
	self._speed = math.clamp(speed, 0, 1)
	local v = self._speed
	local boost = (1 + 0.25 * self._level) * (1 + 0.6 * self._flare)
	local wide = (0.7 + 0.3 * v) * (1 + 0.12 * self._level) * (1 + 0.35 * self._flare)
	local long = (0.5 + 0.5 * v) * (1 + 0.08 * self._level) * (1 + 0.3 * self._flare)
	for _, i in self._made do
		if i:IsA("ParticleEmitter") then
			i.Rate = ((i:GetAttribute("BaseRate") :: number?) or i.Rate) * (0.35 + 0.65 * v) * boost
		elseif i:IsA("Trail") then
			i.Lifetime = ((i:GetAttribute("BaseLife") :: number?) or i.Lifetime)
				* (0.45 + 0.55 * v)
				* (1 + 0.3 * self._flare)
		elseif i:IsA("Beam") then
			local w0 = i:GetAttribute("BaseW0") :: number?
			local w1 = i:GetAttribute("BaseW1") :: number?
			if w0 and w1 then
				i.Width0 = w0 * wide
				i.Width1 = w1 * wide
			end
		end
	end
	for _, tip in self._tips do
		tip.att.CFrame = tip.home * CFrame.new(tip.off.X, tip.off.Y, tip.off.Z * long)
	end
	local shared = self._shared
	if shared and shared.sound then
		shared.sound.Volume = if self._soundOn then shared.soundBase * (0.4 + 0.6 * v) * (1 + 0.3 * self._flare) else 0
	end
end

-- A brief flare (T-03): brighter, longer, wider for `seconds` (default 0.9), then back to normal.
function Fx.flare(self: any, seconds: number?)
	self._flareDur = seconds or 0.9
	self._flareStart = os.clock()
	self._flare = 1
	watch(self, true)
	self:setSpeed(self._speed)
end

function Fx._stepFlare(self: any, t: number)
	local f = 1 - (t - self._flareStart) / self._flareDur
	if f <= 0 then
		self._flare, self._flareStart = 0, nil
		self:setSpeed(self._speed)
		if #self._motion == 0 then
			watch(self, false)
		end
		return
	end
	self._flare = f * f
	self:setSpeed(self._speed)
end

function Fx.setSoundEnabled(self: any, on: boolean)
	self._soundOn = on
	self:setSpeed(self._speed)
end

-- Forget the ribbon behind the car (after a teleport, so it never draws a line across the map).
function Fx.clear(self: any)
	for _, i in self._made do
		if i:IsA("Trail") or i:IsA("ParticleEmitter") then
			(i :: any):Clear()
		end
	end
end

-- Numbers for the performance budget (T-11): what this trail costs on this car right now.
function Fx.stats(self: any): { [string]: number }
	local out = {
		emitters = 0,
		alive = 0,
		beams = 0,
		ribbons = 0,
		sounds = 0,
		glows = 0,
		attachments = 0,
		tier = self._tier or 0,
	}
	for _, i in self._made do
		if i:IsA("ParticleEmitter") then
			out.emitters += 1
			out.alive += (i:GetAttribute("Alive") :: number?) or 0
		elseif i:IsA("Beam") then
			out.beams += 1
		elseif i:IsA("Trail") then
			out.ribbons += 1
		elseif i:IsA("Sound") then
			out.sounds += 1
		elseif i.Name == "RoadGlow" then
			out.glows += 1
		elseif i:IsA("Attachment") then
			out.attachments += 1
		end
	end
	return out
end

function Fx.exhausts(self: any): { Attachment }
	local out: { Attachment } = {}
	for _, i in self._made do
		if i:IsA("Attachment") and i.Name == "Exhaust" then
			table.insert(out, i)
		end
	end
	return out
end

function Fx.destroy(self: any)
	self._item = nil
	build(self)
end

return TrailFx
