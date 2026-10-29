--!strict
-- Return-to-home arrival sparkle (Lane 3 preview, HUD rebuild 2026-10-22, worker HW; ledger
-- E-07). A restrained ring of sparkles around a STAND-IN plot gate when the store event
-- "ArrivedHome" arrives (or on a direct play()). Test fixtures only; nothing on the island.
--
--   * bounded: one ParticleEmitter whose emission point is stepped around a ring of 16 points (one per frame),
--     emitting 1 per point, twice (0.35 s apart): at most 32 particles alive, each living
--     0.9–1.3 s, drifting gently upward;
--   * plus a soft gold glow disc on the ground that fades from 55% to fully transparent over
--     1.4 s;
--   * reduced motion: no particles, only the soft glow fade;
--   * ignores repeats within 1.5 s (the store already dedupes by event id).
--
--   local sparkle = ArrivalSparkle.new(ctx, { gate = modelOrPart?, radius = 7? })
--   sparkle:setGate(instance?, radius?)   sparkle:play() -> boolean
--   sparkle:layout(), sparkle:setVisible(on), sparkle:destroy(), sparkle:getDebugState()

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Motion = require(script.Parent.Parent.Motion)
local PreviewTokens = require(script.Parent.Parent.PreviewTokens)
local Store = require(script.Parent.Parent.Store)
local Trove = require(ReplicatedStorage.Packages.Trove)
local WorldKit = require(script.Parent.WorldKit)

local POINTS = 16
local WAVES = 2
local WAVE_GAP = 0.35
local GLOW_FROM = 0.55
local GLOW_SECONDS = 1.4
local REPEAT_GUARD = 1.5
local GOLD = PreviewTokens.Color.KeysLight

local ArrivalSparkle = {}
ArrivalSparkle.__index = ArrivalSparkle

function ArrivalSparkle.new(ctx: WorldKit.Ctx, options: { gate: Instance?, radius: number? }?)
	local self = setmetatable({}, ArrivalSparkle)
	self._ctx = ctx
	self._trove = Trove.new()
	self._visible = true
	self._gate = nil :: Instance?
	self._radius = 7
	self._lastPlay = -math.huge
	self._plays = 0
	self._emitted = 0
	self._token = 0

	local carrier = WorldKit.part(ctx.world, "ArrivalSparkleCarrier", Vector3.new(0.2, 0.2, 0.2), CFrame.new(), GOLD)
	carrier.Transparency = 1
	self._trove:Add(carrier)
	self._carrier = carrier
	local point = Instance.new("Attachment")
	point.Name = "EmitPoint"
	point.Parent = carrier
	self._point = point
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "ArrivalSparkles"
	emitter.Enabled = false
	emitter.Rate = 0
	emitter.Lifetime = NumberRange.new(0.9, 1.3)
	emitter.Speed = NumberRange.new(1.5, 2.5)
	emitter.SpreadAngle = Vector2.new(15, 15)
	emitter.EmissionDirection = Enum.NormalId.Top
	emitter.Acceleration = Vector3.new(0, 1, 0)
	emitter.LightEmission = 0.6
	emitter.LightInfluence = 0
	emitter.Color = ColorSequence.new(Color3.new(1, 1, 1), GOLD)
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.2),
		NumberSequenceKeypoint.new(0.3, 0.7),
		NumberSequenceKeypoint.new(1, 0),
	})
	emitter.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1) })
	emitter.Parent = point
	self._emitter = emitter
	local glow =
		WorldKit.part(ctx.world, "ArrivalGlow", Vector3.new(0.04, 14, 14), CFrame.new(), GOLD, Enum.Material.Neon)
	glow.Shape = Enum.PartType.Cylinder
	glow.Transparency = 1
	self._trove:Add(glow)
	self._glow = glow
	self._trove:Add(function()
		self._token += 1
		Motion.cancelAll(glow)
	end)

	self._trove:Connect(ctx.store.Event, function(event: Store.Event)
		if event.kind == "ArrivedHome" then
			self:play()
		end
	end)
	if options and options.gate then
		self:setGate(options.gate, options.radius)
	end
	return self
end

export type ArrivalSparkle = typeof(ArrivalSparkle.new((nil :: any) :: WorldKit.Ctx))

function ArrivalSparkle.setGate(self: ArrivalSparkle, gate: Instance?, radius: number?)
	self._gate = gate
	if radius then
		self._radius = radius
	elseif gate then
		local _, size = WorldKit.box(gate)
		self._radius = math.max(size.X, size.Z) / 2 + 2
	end
end

function ArrivalSparkle.play(self: ArrivalSparkle): boolean
	local gate = self._gate
	if not gate or not gate:IsDescendantOf(game) or not self._visible then
		return false
	end
	local now = os.clock()
	if now - self._lastPlay < REPEAT_GUARD then
		return false
	end
	self._lastPlay = now
	self._plays += 1
	self._token += 1
	local token = self._token
	local box, size = WorldKit.box(gate)
	local groundY = box.Position.Y - size.Y / 2
	local centre = Vector3.new(box.Position.X, groundY, box.Position.Z)
	self._carrier.CFrame = CFrame.new(centre + Vector3.new(0, 0.6, 0))
	-- soft glow (also the whole reduced-motion version)
	local r = self._radius
	local glow = self._glow
	glow.Size = Vector3.new(0.04, r * 2, r * 2)
	glow.CFrame = CFrame.new(centre + Vector3.new(0, 0.1, 0)) * CFrame.Angles(0, 0, math.pi / 2)
	glow.Transparency = GLOW_FROM
	Motion.tween(glow, "fade", Motion.info(GLOW_SECONDS, Enum.EasingStyle.Sine), { Transparency = 1 })
	if Motion.reduced() then
		return true
	end
	task.spawn(function()
		for wave = 1, WAVES do
			if token ~= self._token or not self._carrier.Parent then
				return
			end
			for i = 1, POINTS do
				local a = (i - 1 + (wave - 1) * 0.5) / POINTS * math.pi * 2
				self._point.Position = Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)
				self._emitter:Emit(1)
				self._emitted += 1
				-- one point per frame: the ring draws itself in about a quarter second, and each
				-- Emit is sure to use the attachment's new position
				task.wait()
				if token ~= self._token or not self._carrier.Parent then
					return
				end
			end
			task.wait(WAVE_GAP)
		end
	end)
	return true
end

function ArrivalSparkle.layout(_self: ArrivalSparkle) end

function ArrivalSparkle.setVisible(self: ArrivalSparkle, on: boolean)
	self._visible = on
	if not on then
		self._token += 1
		self._emitter:Clear()
		Motion.cancelAll(self._glow)
		self._glow.Transparency = 1
	end
end

function ArrivalSparkle.getDebugState(self: ArrivalSparkle): { [string]: any }
	return {
		plays = self._plays,
		emittedTotal = self._emitted,
		maxAlive = POINTS * WAVES,
		gate = self._gate and self._gate.Name,
		radius = self._radius,
		glowTransparency = self._glow.Transparency,
		reducedMotion = Motion.reduced(),
	}
end

function ArrivalSparkle.destroy(self: ArrivalSparkle)
	self._trove:Destroy()
end

return ArrivalSparkle
