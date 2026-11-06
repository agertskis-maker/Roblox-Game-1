--!strict
-- RacewayAura: rare cars look special on the Raceway (Round 7, K-01; to R7-IMG-18). Lane 3, presentation only: it reads the
-- car's rarity (RosterFixtures) and the owner's saved edition (LiveData), and adds light and particles to the car model, so
-- every player walking past sees who has the good cars.
--   Every rarity: a glowing strip under the car (faint for Uncommon, bright for Legendary) and a light.
--   Uncommon: a soft green underglow.
--   Rare: a blue underglow and a faint shimmer of sparkles on the body.
--   Epic: a purple aura and rising sparkles.
--   Legendary: a gold aura, gold sparkles, a gold light pillar over the car, and fireworks when it crosses the line
--     (RacewayAura.celebrate, called on the server's Lap Pay event).
--   Editions on top: Gold shines, Diamond glints, Rainbow cycles its glow, Galaxy shows drifting stars.
-- Reduce Motion (Motion.reduced): the glow, strip and pillar stay; no moving particles and no fireworks.
-- Everything is added inside the car's model, so the Raceway's PivotTo carries it round the lap.
--
--   RacewayAura.attach(model, carId, edition) -> Aura    Aura:destroy()
--   RacewayAura.celebrate(aura)                           the Legendary finish-line moment
--   RacewayAura.step(t)                                   colour-cycles every Rainbow aura (one call per frame)

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Motion = require(script.Parent.Parent.Motion)
local RosterFixtures = require(ReplicatedStorage.Shared.UI.RosterFixtures)

local RacewayAura = {}

local P = "rbxasset://textures/particles/"
local SPARKLE = P .. "sparkles_main.dds"
local GLOW = P .. "forcefield_glow_main.dds"

local COLOUR: { [string]: Color3 } = {
	Uncommon = Color3.fromRGB(80, 230, 120),
	Rare = Color3.fromRGB(60, 150, 255),
	Epic = Color3.fromRGB(176, 92, 246),
	Legendary = Color3.fromRGB(255, 200, 40),
}
local STRIP_ALPHA: { [string]: number } = { Uncommon = 0.6, Rare = 0.45, Epic = 0.3, Legendary = 0.2 }
local GOLD = Color3.fromRGB(255, 214, 90)
local DIAMOND = Color3.fromRGB(200, 240, 255)

export type Aura = {
	model: Model,
	rarity: string,
	edition: number,
	parts: { Instance },
	light: PointLight?,
	strip: BasePart?,
	firework: ParticleEmitter?,
	destroy: (self: Aura) -> (),
}

local rainbows: { [Aura]: boolean } = {}

local function sizeOf(model: Model): (CFrame, Vector3)
	return model:GetBoundingBox()
end

local function emitter(parent: Instance, props: { [string]: any }): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.LightEmission = 1
	e.LightInfluence = 0
	e.Texture = SPARKLE
	for k, v in props do
		(e :: any)[k] = v
	end
	e.Enabled = not Motion.reduced()
	e.Parent = parent
	return e
end

-- An invisible anchored part inside the model at `cf` (it moves with the model's PivotTo).
local function holder(model: Model, name: string, size: Vector3, cf: CFrame): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Transparency = 1
	p.Size = size
	p.CFrame = cf
	p.Parent = model
	return p
end

function RacewayAura.attach(model: Model, carId: string, edition: number?): Aura?
	local info = RosterFixtures.byId(carId)
	local rarity = info and info.rarity or "Common"
	local ed = edition or 1
	if rarity == "Common" and ed <= 1 then
		return nil
	end
	local box, size = sizeOf(model)
	local floor = box * CFrame.new(0, -size.Y / 2 + 0.15, 0)
	local parts: { Instance } = {}
	local aura: Aura = {
		model = model,
		rarity = rarity,
		edition = ed,
		parts = parts,
		destroy = function(self: Aura)
			rainbows[self] = nil
			for _, p in self.parts do
				p:Destroy()
			end
			table.clear(self.parts)
		end,
	}
	local colour = COLOUR[rarity]
	if colour then
		local base = holder(model, "AuraBase", Vector3.new(size.X * 0.9, 0.2, size.Z * 0.85), floor)
		table.insert(parts, base)
		local light = Instance.new("PointLight")
		light.Color = colour
		light.Range = math.max(size.Z * 0.9, 10)
		light.Brightness = if rarity == "Legendary" then 4 elseif rarity == "Epic" then 3 else 2
		light.Shadows = false
		light.Parent = base
		aura.light = light
		if rarity == "Rare" then
			emitter(base, {
				Color = ColorSequence.new(colour, Color3.new(1, 1, 1)),
				Size = NumberSequence.new(0.35, 0),
				Lifetime = NumberRange.new(0.6, 1.1),
				Rate = 4,
				Speed = NumberRange.new(0.3, 0.8),
				SpreadAngle = Vector2.new(180, 180),
				Transparency = NumberSequence.new(0.3, 1),
			})
		end
		do
			-- the light strip under the car (daylight hides a PointLight, so every rarity has one, brighter the rarer it is)
			local strip = Instance.new("Part")
			strip.Name = "AuraStrip"
			strip.Anchored = true
			strip.CanCollide = false
			strip.CanQuery = false
			strip.CanTouch = false
			strip.CastShadow = false
			strip.Material = Enum.Material.Neon
			strip.Color = colour
			strip.Transparency = STRIP_ALPHA[rarity] or 0.5
			strip.Size = Vector3.new(size.X * 0.8, 0.08, size.Z * 0.85)
			strip.CFrame = floor * CFrame.new(0, -0.1, 0)
			strip.Parent = model
			table.insert(parts, strip)
			aura.strip = strip
		end
		if rarity == "Epic" or rarity == "Legendary" then
			emitter(base, {
				Color = ColorSequence.new(colour),
				Size = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 0.2),
					NumberSequenceKeypoint.new(0.4, 0.6),
					NumberSequenceKeypoint.new(1, 0),
				}),
				Lifetime = NumberRange.new(1.2, 1.8),
				Rate = if rarity == "Legendary" then 18 else 10,
				Speed = NumberRange.new(2, 4),
				EmissionDirection = Enum.NormalId.Top,
				SpreadAngle = Vector2.new(25, 25),
				Shape = Enum.ParticleEmitterShape.Box,
				Transparency = NumberSequence.new(0.1, 1),
			})
			emitter(base, {
				Texture = GLOW,
				Color = ColorSequence.new(colour),
				Size = NumberSequence.new(size.Z * 0.45),
				Lifetime = NumberRange.new(1.5),
				Rate = 1.5,
				Speed = NumberRange.new(0),
				LockedToPart = true,
				Transparency = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 1),
					NumberSequenceKeypoint.new(0.5, 0.75),
					NumberSequenceKeypoint.new(1, 1),
				}),
			})
		end
		if rarity == "Legendary" then
			-- the gold light pillar over the car, seen from across the island
			local pillar = Instance.new("Part")
			pillar.Name = "AuraPillar"
			pillar.Shape = Enum.PartType.Cylinder
			pillar.Anchored = true
			pillar.CanCollide = false
			pillar.CanQuery = false
			pillar.CanTouch = false
			pillar.CastShadow = false
			pillar.Material = Enum.Material.Neon
			pillar.Color = colour
			pillar.Transparency = 0.72
			pillar.Size = Vector3.new(40, 2.2, 2.2)
			pillar.CFrame = floor * CFrame.new(0, 20, 0) * CFrame.Angles(0, 0, math.pi / 2)
			pillar.Parent = model
			table.insert(parts, pillar)
			local burst = emitter(base, {
				Color = ColorSequence.new({
					ColorSequenceKeypoint.new(0, GOLD),
					ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 120, 60)),
					ColorSequenceKeypoint.new(1, Color3.fromRGB(120, 200, 255)),
				}),
				Size = NumberSequence.new(1.1, 0),
				Lifetime = NumberRange.new(1, 1.6),
				Rate = 0,
				Speed = NumberRange.new(18, 28),
				EmissionDirection = Enum.NormalId.Top,
				SpreadAngle = Vector2.new(40, 40),
				Acceleration = Vector3.new(0, -14, 0),
				Drag = 1.5,
				Transparency = NumberSequence.new(0, 1),
			})
			burst.Enabled = true -- Rate 0: only celebrate() emits
			aura.firework = burst
		end
	end
	-- editions, on top of the rarity
	if ed >= 2 then
		local body = holder(model, "AuraEdition", size * Vector3.new(0.9, 0.6, 0.9), box)
		table.insert(parts, body)
		if ed == 2 then
			emitter(body, {
				Color = ColorSequence.new(GOLD),
				Size = NumberSequence.new(0.5, 0),
				Lifetime = NumberRange.new(0.4, 0.7),
				Rate = 6,
				Speed = NumberRange.new(0),
				Shape = Enum.ParticleEmitterShape.Box,
			})
		elseif ed == 3 then
			emitter(body, {
				Color = ColorSequence.new(DIAMOND),
				Size = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 0),
					NumberSequenceKeypoint.new(0.3, 0.9),
					NumberSequenceKeypoint.new(1, 0),
				}),
				Lifetime = NumberRange.new(0.3, 0.5),
				Rate = 8,
				Speed = NumberRange.new(0),
				Rotation = NumberRange.new(0, 90),
				Shape = Enum.ParticleEmitterShape.Box,
			})
		elseif ed == 4 then
			rainbows[aura] = true
			if not aura.light then
				local light = Instance.new("PointLight")
				light.Range = math.max(size.Z * 0.9, 10)
				light.Brightness = 3
				light.Shadows = false
				light.Parent = body
				aura.light = light
			end
		elseif ed >= 5 then
			emitter(body, {
				Color = ColorSequence.new(Color3.fromRGB(150, 120, 255), Color3.fromRGB(90, 200, 255)),
				Size = NumberSequence.new(0.3, 0.1),
				Lifetime = NumberRange.new(2, 3),
				Rate = 10,
				Speed = NumberRange.new(0.5, 1),
				SpreadAngle = Vector2.new(180, 180),
				Shape = Enum.ParticleEmitterShape.Box,
				Transparency = NumberSequence.new(0.2, 1),
			})
		end
	end
	if #parts == 0 then
		return nil
	end
	return aura
end

function RacewayAura.celebrate(aura: Aura?)
	if aura and aura.firework and not Motion.reduced() then
		aura.firework:Emit(40)
		task.delay(0.35, function()
			if aura.firework and aura.firework.Parent then
				aura.firework:Emit(30)
			end
		end)
	end
end

function RacewayAura.step(t: number)
	for aura in rainbows do
		local colour = Color3.fromHSV((t / 4) % 1, 0.8, 1)
		if aura.light then
			aura.light.Color = colour
		end
		if aura.strip then
			aura.strip.Color = colour
		end
	end
end

return RacewayAura
