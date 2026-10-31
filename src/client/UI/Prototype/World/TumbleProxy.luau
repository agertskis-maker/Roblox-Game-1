--!strict
-- SAFE FIXTURE PROXY for the cartoon ejection (Lane 3 preview, HUD rebuild 2026-10-22, worker
-- HW; ledger E-03). PLACEHOLDER PHYSICS: a separate stand-in figure built from a few anchored,
-- non-colliding, non-queryable parts tumbles off the ridden car along a SCRIPTED arc (no physics
-- simulation), lands softly with two small bounces and a little dust puff, rests, then fades.
-- It never touches the real character, its physics, ragdoll, collision, network ownership or
-- the camera; the real run's ejection belongs to Lane 1 (Brian R).
--
-- Child-friendly: a cartoon spin and squash-free soft landing, no harsh impact, no scary sound
-- (one gentle Sounds.play("Bonk") on landing). Reduced motion: no arc and no spin; the figure
-- fades in sitting beside the car and fades out.
-- A "PLACEHOLDER PHYSICS" caption (attribute PreviewCaption) floats above the figure.
--
-- Plays on the store event "Dismounted" (dedupe by event id via the store; one figure at a
-- time: a new play replaces the previous one) or by a direct call.
--
--   local tumble = TumbleProxy.new(ctx, { ride = model? })
--   tumble:setRide(model?)
--   tumble:play(from: CFrame?) -> boolean    -- from = the rider's roof position (default: ride)
--   tumble:stop()
--   tumble:layout(), tumble:setVisible(on), tumble:destroy(), tumble:getDebugState()

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Arcade = require(script.Parent.Parent.Arcade)
local Motion = require(script.Parent.Parent.Motion)
local Sounds = require(script.Parent.Parent.Sounds)
local Store = require(script.Parent.Parent.Store)
local Trove = require(ReplicatedStorage.Packages.Trove)
local WorldKit = require(script.Parent.WorldKit)

local ARC_SECONDS = 1.1
local SIDE = 9 -- studs sideways
local BACK = 4 -- studs backward (the car keeps going forward)
local APEX = 6 -- studs above the start
local SPINS = 1.25
local BOUNCE_SECONDS = 0.45
local REST_SECONDS = 1.4
local FADE_SECONDS = 0.4

-- stand-in colours (neutral, no real avatar art) — TOKEN CANDIDATE
local SKIN = Color3.fromRGB(255, 214, 160)
local SHIRT = Color3.fromRGB(80, 170, 255)
local PANTS = Color3.fromRGB(40, 60, 110)

local TumbleProxy = {}
TumbleProxy.__index = TumbleProxy

type Figure = {
	model: Model,
	parts: { BasePart },
	offsets: { CFrame },
	caption: BillboardGui,
	dust: ParticleEmitter,
}

local function build(parent: Instance): Figure
	local model = Instance.new("Model")
	model.Name = "TumbleProxy_PLACEHOLDER"
	model:SetAttribute("Proxy", "placeholder physics stand-in (not the real character)")
	local parts: { BasePart } = {}
	local offsets: { CFrame } = {}
	local function add(name: string, size: Vector3, offset: CFrame, colour: Color3, ball: boolean?)
		local p = WorldKit.part(model, name, size, offset, colour)
		if ball then
			p.Shape = Enum.PartType.Ball
		end
		table.insert(parts, p)
		table.insert(offsets, offset)
		return p
	end
	-- a chunky cartoon figure about 5 studs tall, centred on its torso
	local torso = add("Torso", Vector3.new(2, 2, 1), CFrame.new(), SHIRT)
	add("Head", Vector3.new(1.6, 1.6, 1.6), CFrame.new(0, 1.85, 0), SKIN, true)
	add("ArmL", Vector3.new(0.8, 1.8, 0.8), CFrame.new(-1.45, 0.1, 0) * CFrame.Angles(0, 0, math.rad(-35)), SHIRT)
	add("ArmR", Vector3.new(0.8, 1.8, 0.8), CFrame.new(1.45, 0.1, 0) * CFrame.Angles(0, 0, math.rad(35)), SHIRT)
	add("LegL", Vector3.new(0.9, 1.8, 0.9), CFrame.new(-0.5, -1.9, 0) * CFrame.Angles(0, 0, math.rad(-12)), PANTS)
	add("LegR", Vector3.new(0.9, 1.8, 0.9), CFrame.new(0.5, -1.9, 0) * CFrame.Angles(0, 0, math.rad(12)), PANTS)
	model.PrimaryPart = torso
	local caption = Instance.new("BillboardGui")
	caption.Name = "PlaceholderCaption"
	caption.Adornee = torso
	caption.AlwaysOnTop = false
	caption.LightInfluence = 0
	caption.MaxDistance = 150
	caption.Size = UDim2.fromOffset(240, 30)
	caption.StudsOffsetWorldSpace = Vector3.new(0, 4.5, 0)
	caption.Parent = model
	local label = Arcade.text(caption, {
		text = "PLACEHOLDER PHYSICS",
		role = "Small",
		name = "PreviewNote",
		colour = Color3.new(1, 1, 1),
	})
	label.Size = UDim2.fromScale(1, 1)
	label:SetAttribute("PreviewCaption", true)
	local dust = Instance.new("ParticleEmitter")
	dust.Name = "SoftDust"
	dust.Enabled = false
	dust.Rate = 0
	dust.Texture = "rbxasset://textures/particles/smoke_main.dds"
	dust.Lifetime = NumberRange.new(0.5, 0.8)
	dust.Speed = NumberRange.new(2, 4)
	dust.SpreadAngle = Vector2.new(80, 10)
	dust.EmissionDirection = Enum.NormalId.Top
	dust.Color = ColorSequence.new(Color3.fromRGB(240, 236, 226))
	dust.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.8), NumberSequenceKeypoint.new(1, 2) })
	dust.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.4), NumberSequenceKeypoint.new(1, 1) })
	dust.LightInfluence = 0.5
	dust.Parent = torso
	model.Parent = parent
	return { model = model, parts = parts, offsets = offsets, caption = caption, dust = dust }
end

function TumbleProxy.new(ctx: WorldKit.Ctx, options: { ride: Instance? }?)
	local self = setmetatable({}, TumbleProxy)
	self._ctx = ctx
	self._trove = Trove.new()
	self._visible = true
	self._ride = options and options.ride
	self._figure = nil :: Figure?
	self._step = nil :: RBXScriptConnection?
	self._plays = 0
	self._landings = 0
	self._phase = "Idle"
	self._trove:Connect(ctx.store.Event, function(event: Store.Event)
		if event.kind == "Dismounted" then
			self:play(nil)
		end
	end)
	self._trove:Connect(ctx.store.ModeChanged, function(mode: Store.Mode)
		if mode ~= "Run" then
			self:stop()
		end
	end)
	self._trove:Add(function()
		self:stop()
	end)
	return self
end

export type TumbleProxy = typeof(TumbleProxy.new((nil :: any) :: WorldKit.Ctx))

function TumbleProxy.setRide(self: TumbleProxy, model: Instance?)
	self._ride = model
end

local function pose(f: Figure, root: CFrame, alpha: number)
	for i, p in f.parts do
		p.CFrame = root * f.offsets[i]
		p.Transparency = 1 - alpha
	end
end

function TumbleProxy.stop(self: TumbleProxy)
	if self._step then
		self._step:Disconnect()
		self._step = nil
	end
	if self._figure then
		self._figure.model:Destroy()
		self._figure = nil
	end
	self._phase = "Idle"
end

function TumbleProxy.play(self: TumbleProxy, from: CFrame?): boolean
	local start = from
	if not start then
		local ride = self._ride
		if not ride or not ride.Parent then
			return false
		end
		local box, size = WorldKit.box(ride)
		start = WorldKit.flat(box, box.Position + Vector3.new(0, size.Y / 2 + 2.5, 0))
	end
	self:stop()
	if not self._visible then
		return false
	end
	local origin = start :: CFrame
	local figure = build(self._ctx.world)
	self._figure = figure
	self._plays += 1
	-- landing spot: to the right and a little behind, on whatever ground is below
	local landXZ = (origin * CFrame.new(SIDE, 0, BACK)).Position
	local ground = WorldKit.groundY(landXZ + Vector3.new(0, 10, 0), { self._ctx.world }, 60)
	local restY = (ground or (origin.Position.Y - 6)) + 1.2 -- lying figure: torso about 1.2 up
	local landing = CFrame.new(landXZ.X, restY, landXZ.Z) * origin.Rotation
	local lying = landing * CFrame.Angles(math.rad(-90), 0, math.rad(15)) -- on its back, cartoon
	local sitting = landing * CFrame.new(0, 0.6, 0)
	local reduced = Motion.reduced()
	local t = 0
	local landed = false
	self._phase = if reduced then "FadeIn" else "Arc"
	if reduced then
		pose(figure, sitting, 0)
	else
		pose(figure, origin, 1)
	end
	self._step = RunService.Heartbeat:Connect(function(dt: number)
		t += dt
		local f = self._figure
		if not f then
			return
		end
		if self._phase == "FadeIn" then
			local a = math.min(t / FADE_SECONDS, 1)
			pose(f, sitting, a)
			if a >= 1 then
				self._phase, t = "Rest", 0
			end
		elseif self._phase == "Arc" then
			local u = math.min(t / ARC_SECONDS, 1)
			local pos = origin.Position:Lerp(landing.Position, u) + Vector3.new(0, APEX * 4 * u * (1 - u), 0)
			local spin = CFrame.Angles(-u * SPINS * math.pi * 2, 0, u * math.pi * 0.6)
			local root = (CFrame.new(pos) * origin.Rotation * spin):Lerp(lying, math.max(0, (u - 0.85) / 0.15))
			pose(f, root, 1)
			if u >= 1 then
				self._phase, t = "Bounce", 0
			end
		elseif self._phase == "Bounce" then
			if not landed then
				landed = true
				self._landings += 1
				Sounds.play("Bonk")
				f.dust:Emit(6)
			end
			local u = math.min(t / BOUNCE_SECONDS, 1)
			-- two small, decaying hops (soft landing, no impact shake)
			local hop = if u < 0.6 then math.sin(u / 0.6 * math.pi) * 0.9 else math.sin((u - 0.6) / 0.4 * math.pi) * 0.3
			-- lying on its back, the figure's local +Z points up
			pose(f, lying * CFrame.new(0, 0, hop), 1)
			if u >= 1 then
				self._phase, t = "Rest", 0
			end
		elseif self._phase == "Rest" then
			if t >= REST_SECONDS then
				self._phase, t = "FadeOut", 0
			end
		elseif self._phase == "FadeOut" then
			local a = 1 - math.min(t / FADE_SECONDS, 1)
			pose(f, if reduced then sitting else lying, a)
			f.caption.Enabled = a > 0.5
			if a <= 0 then
				self:stop()
			end
		end
	end)
	return true
end

function TumbleProxy.layout(_self: TumbleProxy) end

function TumbleProxy.setVisible(self: TumbleProxy, on: boolean)
	self._visible = on
	if not on then
		self:stop()
	end
end

function TumbleProxy.getDebugState(self: TumbleProxy): { [string]: any }
	return {
		phase = self._phase,
		figureAlive = self._figure ~= nil,
		plays = self._plays,
		landings = self._landings,
		stepping = self._step ~= nil,
		touchesRealCharacter = false,
		reducedMotion = Motion.reduced(),
	}
end

function TumbleProxy.destroy(self: TumbleProxy)
	self._trove:Destroy()
end

return TumbleProxy
