--!strict
-- World-space capture feedback on the RIDDEN car (Lane 3 preview, HUD rebuild 2026-10-22,
-- worker HW; ledger K-03/K-04 world parts). The Keys ring, HOLD ON, SECURING…, the confirmation
-- text and the capture sounds belong to the run HUD (worker HR); this module only draws on the
-- car and sets the nameplate state.
--
--   start     a restrained rarity outline (the one shared Highlight, outline only, DepthMode
--             Occluded; thickness cannot be set, so intensity is capped through
--             OutlineTransparency >= 0.2), sparse upward sparkles over the roof (one
--             ParticleEmitter, 5/s x 1.4–1.8 s life = at most 9 alive, LockedToPart so they ride
--             with the car), and the nameplate state "CAPTURING"
--   confirmed a short gold + rarity burst (one Emit of 10, never more than 12), then the outline
--             fades over 0.5 s; reduced motion: no burst, the outline just fades
--   canceled  the outline fades over 0.3 s, sparkles stop, the plate state clears
--   warning   the shared Highlight shows the warning instead (warning wins) and the sparkles
--             pause; the capture outline returns if the warning clears first
-- Colour roles (K-03): rarity colour only on the outline and in the final burst; gold is the
-- capture colour (sparkles); teal stays the Hop colour.
--
-- Driven by store events KeysStart / KeysConfirmed / KeysCanceled (field `captureId`) and by
-- `run.keys` ({ id, status }), whichever arrives first. Idempotent per captureId: states only
-- move forward (Capturing 1 < Confirmed / Canceled 3); duplicates, late and out-of-order
-- deliveries never replay or reverse a state. A late Confirmed after a Cancel draws nothing
-- here (the HUD ribbon reports it). Cleans up on despawn, run end, mode change and reset.
--
--   local fx = CaptureFx.new(ctx, { nameplates = plates?, rideId = "ride"?, ride = model? })
--   fx:setRide(instanceId?, model?)     fx:setNameplates(plates?)
--   fx:start(captureId, car)  fx:confirm(captureId)  fx:cancel(captureId)   -- direct calls
--   fx:layout(), fx:setVisible(on), fx:destroy(), fx:getDebugState()

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local CarHighlight = require(script.Parent.CarHighlight)
local Motion = require(script.Parent.Parent.Motion)
local PreviewTokens = require(script.Parent.Parent.PreviewTokens)
local Store = require(script.Parent.Parent.Store)
local Trove = require(ReplicatedStorage.Packages.Trove)
local WorldKit = require(script.Parent.WorldKit)

local OUTLINE_MIN_TRANSPARENCY = 0.2 -- intensity cap
local RAMP_IN = 0.2
local FADE_CANCEL = 0.3
local FADE_CONFIRM = 0.5
local SPARSE_RATE = 5
local SPARSE_LIFE = NumberRange.new(1.4, 1.8) -- 5 x 1.8 = at most 9 alive
local BURST = 10 -- one Emit, <= 12
local GOLD = PreviewTokens.Color.KeysLight
local GOLD_DEEP = PreviewTokens.Color.KeysDeep

export type Phase = "Idle" | "Capturing" | "Confirming" | "Canceling"

local RANK = { Capturing = 1, Confirmed = 3, Canceled = 3 }

local CaptureFx = {}
CaptureFx.__index = CaptureFx

type Options = { nameplates: any?, rideId: string?, ride: Instance? }

function CaptureFx.new(ctx: WorldKit.Ctx, options: Options?)
	local self = setmetatable({}, CaptureFx)
	self._ctx = ctx
	self._trove = Trove.new()
	self._visible = true
	self._phase = "Idle" :: Phase
	self._captureId = nil :: string?
	self._car = nil :: WorldKit.CarInfo?
	self._seen = {} :: { [string]: number }
	self._ride = nil :: Instance?
	self._rideId = nil :: string?
	self._plates = options and options.nameplates
	self._outlineT = 1
	self._fadeFrom = 1
	self._fadeT = 0
	self._fadeSeconds = 0
	self._step = nil :: RBXScriptConnection?
	self._bursts = 0
	self._plateState = nil :: string?
	self._fadeTo = 1
	self._burstAt = 0

	self._hl = CarHighlight.get(ctx.world)
	self._trove:Add(function()
		self._hl:set("Capture", nil)
		self._hl:release()
	end)

	local carrier = WorldKit.part(ctx.world, "CaptureFxCarrier", Vector3.new(4, 0.2, 8), CFrame.new(), GOLD)
	carrier.Transparency = 1
	self._trove:Add(carrier)
	self._carrier = carrier
	local sparse = Instance.new("ParticleEmitter")
	sparse.Name = "CaptureSparkles"
	sparse.Enabled = false
	sparse.Rate = SPARSE_RATE
	sparse.Lifetime = SPARSE_LIFE
	sparse.Speed = NumberRange.new(2, 3)
	sparse.SpreadAngle = Vector2.new(20, 20)
	sparse.EmissionDirection = Enum.NormalId.Top
	sparse.Shape = Enum.ParticleEmitterShape.Box
	sparse.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	sparse.LockedToPart = true
	sparse.LightEmission = 0.5
	sparse.LightInfluence = 0
	sparse.Color = ColorSequence.new(GOLD, GOLD_DEEP)
	sparse.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(1, 0) })
	sparse.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.15),
		NumberSequenceKeypoint.new(0.7, 0.35),
		NumberSequenceKeypoint.new(1, 1),
	})
	sparse.Parent = carrier
	self._sparse = sparse
	local burst = Instance.new("ParticleEmitter")
	burst.Name = "CaptureBurst"
	burst.Enabled = false
	burst.Rate = 0
	burst.Lifetime = NumberRange.new(0.6, 0.9)
	burst.Speed = NumberRange.new(9, 13)
	burst.SpreadAngle = Vector2.new(60, 60)
	burst.EmissionDirection = Enum.NormalId.Top
	burst.Drag = 3
	burst.Acceleration = Vector3.new(0, -6, 0)
	burst.LockedToPart = true
	burst.LightEmission = 0.6
	burst.LightInfluence = 0
	burst.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.9), NumberSequenceKeypoint.new(1, 0.1) })
	burst.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) })
	burst.Parent = carrier
	self._burst = burst

	if options and options.ride then
		self:setRide(options.rideId, options.ride)
	end

	self._trove:Connect(ctx.store.Event, function(event: Store.Event)
		local id = event.captureId
		if not id then
			return
		end
		if event.kind == "KeysStart" then
			local car = event.car or self:_keysCar()
			if car then
				self:start(id, car)
			end
		elseif event.kind == "KeysConfirmed" then
			self:confirm(id)
		elseif event.kind == "KeysCanceled" then
			self:cancel(id)
		end
	end)
	self._trove:Add(ctx.store:subscribe("run", function(run: Store.RunState?)
		if not run then
			self:_reset()
			return
		end
		local keys = run.keys
		if keys and keys.id then
			if keys.status == "Holding" or keys.status == "Pending" then
				self:start(keys.id, keys.target)
			elseif keys.status == "Confirmed" then
				self:confirm(keys.id)
			elseif keys.status == "Canceled" or keys.status == "Lost" then
				self:cancel(keys.id)
			end
		end
	end))
	self._trove:Connect(ctx.store.ModeChanged, function(mode: Store.Mode, from: Store.Mode?)
		if mode ~= "Run" or from == nil then
			self:_reset()
			table.clear(self._seen)
		end
	end)
	self._trove:Add(Motion.onReducedChanged(function(reduced: boolean)
		if reduced then
			self._sparse.Enabled = false
			self._sparse:Clear()
		elseif self._phase == "Capturing" then
			self._sparse.Enabled = self._visible
		end
	end))
	self._trove:Add(function()
		self:_stopStep()
	end)
	return self
end

export type CaptureFx = typeof(CaptureFx.new((nil :: any) :: WorldKit.Ctx))

function CaptureFx._keysCar(self: CaptureFx): WorldKit.CarInfo?
	local run = self._ctx.store:get().run
	local keys = run and run.keys
	return keys and keys.target
end

function CaptureFx.setNameplates(self: CaptureFx, plates: any?)
	self._plates = plates
end

function CaptureFx.setRide(self: CaptureFx, instanceId: string?, model: Instance?)
	if model ~= self._ride and self._phase ~= "Idle" then
		self:_reset()
	end
	self._ride = model
	self._rideId = instanceId
	if model then
		local _, size = WorldKit.box(model)
		self._carrier.Size = Vector3.new(math.max(size.X * 0.8, 1), 0.2, math.max(size.Z * 0.7, 1))
	end
end

function CaptureFx._setPlate(self: CaptureFx, state: string?)
	self._plateState = state
	local plates = self._plates
	if plates and self._rideId and plates.setPlateState then
		plates:setPlateState(self._rideId, state)
	end
end

function CaptureFx._advance(self: CaptureFx, captureId: string, status: string): boolean
	local rank = RANK[status]
	local prev = self._seen[captureId] or 0
	if rank <= prev then
		return false
	end
	self._seen[captureId] = rank
	return true
end

function CaptureFx._follow(self: CaptureFx): boolean
	local part = WorldKit.mainPart(self._ride)
	if not part or not self._ride or not self._ride:IsDescendantOf(game) then
		return false
	end
	local box, size = WorldKit.box(self._ride :: Instance)
	local roof = box.Position + Vector3.new(0, size.Y / 2 + 0.2, 0)
	self._carrier.CFrame = WorldKit.flat(box, roof)
	return true
end

function CaptureFx._outlineSpec(self: CaptureFx, transparency: number)
	local car = self._car
	local ride = self._ride
	if not ride or not car then
		self._hl:set("Capture", nil)
		return
	end
	self._outlineT = transparency
	if transparency >= 0.999 then
		self._hl:set("Capture", nil)
		return
	end
	self._hl:set("Capture", {
		adornee = ride,
		outline = WorldKit.rarity(car.rarity).light,
		outlineTransparency = math.max(transparency, OUTLINE_MIN_TRANSPARENCY),
	})
end

function CaptureFx._fadeOutline(self: CaptureFx, to: number, seconds: number)
	self._fadeFrom = self._outlineT
	self._fadeTo = to
	self._fadeT = 0
	self._fadeSeconds = seconds
	self:_startStep()
end

function CaptureFx._startStep(self: CaptureFx)
	if self._step then
		return
	end
	self._step = RunService.Heartbeat:Connect(function(dt: number)
		if not self:_follow() then
			-- the ridden car despawned: end everything without a fade
			self:_reset()
			return
		end
		-- the warning wins: pause the sparkles while it shows
		local warned = self._hl:active() == "Warn"
		local want = self._phase == "Capturing" and self._visible and not warned and not Motion.reduced()
		if self._sparse.Enabled ~= want then
			self._sparse.Enabled = want
		end
		if self._fadeSeconds > 0 then
			self._fadeT = math.min(self._fadeT + dt, self._fadeSeconds)
			local a = self._fadeT / self._fadeSeconds
			self:_outlineSpec(self._fadeFrom + ((self._fadeTo or 1) - self._fadeFrom) * a)
			if self._fadeT >= self._fadeSeconds then
				self._fadeSeconds = 0
				if self._phase ~= "Capturing" then
					self._phase = "Idle"
					self._captureId = nil
				end
			end
		end
		if self._phase == "Idle" and self._fadeSeconds == 0 then
			self._sparse.Enabled = false
			-- linger until the last burst sparks are gone, then stop stepping
			if os.clock() - (self._burstAt or 0) > 1 then
				self:_stopStep()
			end
		end
	end)
end

function CaptureFx._stopStep(self: CaptureFx)
	if self._step then
		self._step:Disconnect()
		self._step = nil
	end
end

function CaptureFx.start(self: CaptureFx, captureId: string, car: WorldKit.CarInfo)
	if not self._ride or not self:_advance(captureId, "Capturing") then
		return
	end
	-- a new capture supersedes any earlier one
	self._captureId = captureId
	self._car = car
	self._phase = "Capturing"
	self:_follow()
	self:_setPlate("CAPTURING")
	if Motion.reduced() then
		self._fadeSeconds = 0
		self:_outlineSpec(OUTLINE_MIN_TRANSPARENCY)
	else
		self:_outlineSpec(1)
		self:_fadeOutline(OUTLINE_MIN_TRANSPARENCY, RAMP_IN)
	end
	self._sparse.Enabled = self._visible and not Motion.reduced()
	self:_startStep()
end

function CaptureFx.confirm(self: CaptureFx, captureId: string)
	local wasCapturing = self._captureId == captureId and self._phase == "Capturing"
	if not self:_advance(captureId, "Confirmed") or not wasCapturing then
		return
	end
	self._phase = "Confirming"
	self._sparse.Enabled = false
	self._sparse:Clear()
	self:_setPlate(nil)
	local car = self._car
	if self._visible and not Motion.reduced() and car and self:_follow() then
		local r = WorldKit.rarity(car.rarity)
		self._burst.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, GOLD),
			ColorSequenceKeypoint.new(0.5, r.light),
			ColorSequenceKeypoint.new(1, GOLD_DEEP),
		})
		self._burst:Emit(BURST)
		self._bursts += 1
		self._burstAt = os.clock()
	end
	self:_fadeOutline(1, FADE_CONFIRM)
end

function CaptureFx.cancel(self: CaptureFx, captureId: string)
	local wasCapturing = self._captureId == captureId and self._phase == "Capturing"
	if not self:_advance(captureId, "Canceled") or not wasCapturing then
		return
	end
	self._phase = "Canceling"
	self._sparse.Enabled = false
	self:_setPlate(nil)
	self:_fadeOutline(1, FADE_CANCEL)
end

-- immediate cleanup (despawn, run end, mode change, reset)
function CaptureFx._reset(self: CaptureFx)
	self:_stopStep()
	self._sparse.Enabled = false
	self._sparse:Clear()
	self._burst:Clear()
	if self._plateState then
		self:_setPlate(nil)
	end
	self._fadeSeconds = 0
	self._outlineT = 1
	self._hl:set("Capture", nil)
	self._phase = "Idle"
	self._captureId = nil
end

function CaptureFx.layout(_self: CaptureFx) end

function CaptureFx.setVisible(self: CaptureFx, on: boolean)
	self._visible = on
	if not on then
		self._sparse.Enabled = false
		self._hl:set("Capture", nil)
	elseif self._phase == "Capturing" then
		self:_outlineSpec(OUTLINE_MIN_TRANSPARENCY)
	end
end

function CaptureFx.getDebugState(self: CaptureFx): { [string]: any }
	local seen = 0
	for _ in self._seen do
		seen += 1
	end
	return {
		phase = self._phase,
		captureId = self._captureId,
		ride = self._ride and self._ride.Name,
		rideId = self._rideId,
		highlight = self._hl:debug(),
		outlineTransparency = self._outlineT,
		sparseEnabled = self._sparse.Enabled,
		sparseMaxAlive = SPARSE_RATE * SPARSE_LIFE.Max,
		burstSize = BURST,
		bursts = self._bursts,
		plateState = self._plateState,
		stepping = self._step ~= nil,
		seenCaptureIds = seen,
		reducedMotion = Motion.reduced(),
		emitters = 2,
	}
end

function CaptureFx.destroy(self: CaptureFx)
	if self._plateState then
		self:_setPlate(nil)
	end
	self._trove:Destroy()
end

return CaptureFx
