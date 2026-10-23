--!strict
-- Hop arc telegraph (Lane 3 preview, HUD rebuild 2026-10-22, worker HW; ledger T-06, T-07).
--
-- A DIRECTIONAL CUE DRIVEN BY TARGET DATA, NOT A BALLISTIC PATH. It draws a thin dotted curve
-- from the ridden car's roof to the point above the selected target's ring centre, so the
-- player sees which car the Hop goes to. Its height and shape are a fixed presentation rule
-- (a quadratic curve whose apex sits 2.5–8 studs above the higher end); they do not predict
-- where a jump would land, how long it takes, or whether it succeeds. Lane 1 (Brian R) owns
-- the real Hop and any trajectory.
--
--   * 6 short Beam dashes over one carrier (FaceCamera, LightInfluence 0), 0.3 -> 0.18 studs
--     wide, semi-transparent and fading out over the last third so it never covers the target
--     or other cars; no images, no particles;
--   * shown only for "Available" and "Timing"; hidden for "Unavailable" (an arc to an
--     unavailable target would imply a valid jump) and "Hidden";
--   * hidden when either car is missing/despawned or the cars are under 3 or over 140 studs apart;
--   * static in every motion mode (nothing pulses), so reduced motion needs no change;
--   * the pointing pose is skipped on purpose (no new animation pipeline).
-- Follows the cars on Heartbeat only while shown.
--
--   local arc = ArcTelegraph.new(ctx, { ride = model?, target = model? })
--   arc:setRide(model?)  arc:setTarget(model?)  arc:setState(state)
--   arc:layout(), arc:setVisible(on), arc:destroy(), arc:getDebugState()

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local PreviewTokens = require(script.Parent.Parent.PreviewTokens)
local Trove = require(ReplicatedStorage.Packages.Trove)
local WorldKit = require(script.Parent.WorldKit)

local C = PreviewTokens.Color

local POINTS = 12 -- 11 spans, every other one drawn = 6 dashes
local MIN_GAP, MAX_GAP = 3, 140
-- the curve is drawn from this fraction on: the chase camera sits just behind the ride, so the first
-- span drew as a long bar up the road (reviewer, 2026-10-23: "a teal beam pointing at nothing")
local DRAW_FROM = 0.3

export type ArcState = "Available" | "Unavailable" | "Timing" | "Hidden"

local ArcTelegraph = {}
ArcTelegraph.__index = ArcTelegraph

function ArcTelegraph.new(ctx: WorldKit.Ctx, options: { ride: Instance?, target: Instance? }?)
	local self = setmetatable({}, ArcTelegraph)
	self._ctx = ctx
	self._trove = Trove.new()
	self._visible = true
	self._state = "Hidden" :: ArcState
	self._ride = options and options.ride
	self._target = options and options.target
	self._step = nil :: RBXScriptConnection?
	self._shown = false
	self._updates = 0

	local carrier = WorldKit.part(ctx.world, "HopArcCarrier", Vector3.new(0.2, 0.2, 0.2), CFrame.new(), C.White)
	carrier.Transparency = 1
	self._trove:Add(carrier)
	self._carrier = carrier
	self._points = {} :: { Attachment }
	for i = 1, POINTS do
		local a = Instance.new("Attachment")
		a.Name = "P" .. i
		a.Parent = carrier
		table.insert(self._points, a)
	end
	self._beams = {} :: { Beam }
	local dashes = math.floor(POINTS / 2)
	for d = 1, dashes do
		local i = d * 2 - 1
		local beam = Instance.new("Beam")
		beam.Name = "Dash" .. d
		beam.Attachment0 = self._points[i]
		beam.Attachment1 = self._points[i + 1]
		beam.FaceCamera = true
		beam.Segments = 1
		beam.LightInfluence = 0
		beam.LightEmission = 0.4
		-- even width and opacity to the end: the arc must land visibly on the target (reviewer,
		-- 2026-10-23: with the old fade over the last third it read as a bar pointing at nothing)
		beam.Width0 = 0.6
		beam.Width1 = 0.6
		beam.Transparency = NumberSequence.new(0.25)
		beam.Color = ColorSequence.new(if d % 2 == 1 then C.HopLight else C.White)
		beam.Enabled = false
		beam.Parent = carrier
		table.insert(self._beams, beam)
	end
	self._trove:Add(function()
		self:_stopStep()
	end)
	return self
end

export type ArcTelegraph = typeof(ArcTelegraph.new((nil :: any) :: WorldKit.Ctx))

local function roofTop(model: Instance?): Vector3?
	if not model or not model:IsDescendantOf(game) then
		return nil
	end
	local box, size = WorldKit.box(model)
	return box.Position + Vector3.new(0, size.Y / 2, 0)
end

function ArcTelegraph._update(self: ArcTelegraph): boolean
	local a = roofTop(self._ride)
	local b = roofTop(self._target)
	if not a or not b then
		return false
	end
	local start = (a :: Vector3) + Vector3.new(0, 0.6, 0)
	local finish = (b :: Vector3) + Vector3.new(0, 0.4, 0)
	local gap = (finish - start).Magnitude
	if gap < MIN_GAP or gap > MAX_GAP then
		return false
	end
	local apex = math.max(start.Y, finish.Y) + math.clamp(gap * 0.1, 1.5, 4) -- a low hop, kept near the cars
	local mid = (start + finish) / 2
	local control = Vector3.new(mid.X, 2 * apex - mid.Y, mid.Z)
	for i, p in self._points do
		local t = DRAW_FROM + (1 - DRAW_FROM) * (i - 1) / (POINTS - 1)
		local q = start:Lerp(control, t):Lerp(control:Lerp(finish, t), t)
		p.Position = q -- the carrier sits at the origin, so local = world
	end
	self._updates += 1
	return true
end

function ArcTelegraph._setBeams(self: ArcTelegraph, on: boolean)
	if self._shown == on then
		return
	end
	self._shown = on
	for _, b in self._beams do
		b.Enabled = on
	end
end

function ArcTelegraph._stopStep(self: ArcTelegraph)
	if self._step then
		self._step:Disconnect()
		self._step = nil
	end
end

function ArcTelegraph._apply(self: ArcTelegraph)
	local wanted = self._visible and (self._state == "Available" or self._state == "Timing")
	if not wanted then
		self:_stopStep()
		self:_setBeams(false)
		return
	end
	self:_setBeams(self:_update())
	if not self._step then
		self._step = RunService.Heartbeat:Connect(function()
			local target = self._target
			if not target or not target:IsDescendantOf(game) then
				-- despawned target: drop it and stop following (a new setTarget restarts)
				self._target = nil
				self:_stopStep()
				self:_setBeams(false)
				return
			end
			self:_setBeams(self:_update())
		end)
	end
end

function ArcTelegraph.setRide(self: ArcTelegraph, model: Instance?)
	self._ride = model
	self:_apply()
end

function ArcTelegraph.setTarget(self: ArcTelegraph, model: Instance?)
	self._target = model
	self:_apply()
end

function ArcTelegraph.setState(self: ArcTelegraph, state: ArcState)
	self._state = state
	self:_apply()
end

function ArcTelegraph.layout(_self: ArcTelegraph) end

function ArcTelegraph.setVisible(self: ArcTelegraph, on: boolean)
	self._visible = on
	self:_apply()
end

function ArcTelegraph.getDebugState(self: ArcTelegraph): { [string]: any }
	return {
		state = self._state,
		shown = self._shown,
		dashes = #self._beams,
		stepping = self._step ~= nil,
		updates = self._updates,
		ride = self._ride and self._ride.Name,
		target = self._target and self._target.Name,
		kind = "directional cue (not a ballistic path)",
	}
end

function ArcTelegraph.destroy(self: ArcTelegraph)
	self._trove:Destroy()
end

return ArcTelegraph
