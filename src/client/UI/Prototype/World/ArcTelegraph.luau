--!strict
-- Hop arc telegraph (Lane 3 preview; chevron stream rebuilt in Round 2, R2-P1; worker HW built the original
-- dotted version, HUD rebuild 2026-10-22, ledger T-06, T-07).
--
-- A DIRECTIONAL CUE DRIVEN BY TARGET DATA, NOT A BALLISTIC PATH. A narrow stream of small chevrons flows from the
-- ridden car's roof toward the point above the selected target, so the player sees which car the Hop goes to and
-- which way it goes. Its height and shape are a fixed presentation rule (a quadratic curve whose apex sits 1.5-4
-- studs above the higher end); they do not predict where a jump would land, how long it takes, or whether it
-- succeeds. Lane 1 (Brian R) owns the real Hop and any trajectory; until it supplies one this stays a direction cue.
--
--   * a POOL of 9 chevrons (never more than 12), each a small billboard (2 rounded bars forming a V, depth-tested
--     so cars and scenery occlude it) turned along the curve's on-screen direction; they flow toward the target and
--     fade in near the car and out at the landing; they are narrow (1.5 studs) so traffic stays visible through and
--     around the stream: no luminous hose on the road;
--   * brightness rises modestly toward the landing; during the best-timing window the last part warms to the gold
--     accent;
--   * RETARGET: positions are recomputed from the current curve every frame, so the stream swings to the new target
--     at once and nothing of the old one remains (no trails, no history);
--   * shown only for "Available" and "Timing"; hidden for "Unavailable" and "Hidden" (an arc to an unavailable
--     target would imply a valid jump), when either car is missing or despawned, and when the cars are under 3 or
--     over 140 studs apart;
--   * REDUCED MOTION: the chevrons stand still along the arc (steady, no flow, no brightness change over time).
-- Follows the cars on Heartbeat only while shown.
--
--   local arc = ArcTelegraph.new(ctx, { ride = model?, target = model? })
--   arc:setRide(model?)  arc:setTarget(model?)  arc:setState(state)
--   arc:layout(), arc:setVisible(on), arc:destroy(), arc:getDebugState()

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Motion = require(script.Parent.Parent.Motion)
local PreviewTokens = require(script.Parent.Parent.PreviewTokens)
local Trove = require(ReplicatedStorage.Packages.Trove)
local WorldKit = require(script.Parent.WorldKit)

local C = PreviewTokens.Color
local INK = PreviewTokens.Arcade.Ink
local GOLD = Color3.fromRGB(255, 204, 48)

local CHEVRONS = 9 -- the pool; the brief caps it at 12
local MIN_GAP, MAX_GAP = 3, 140
-- the curve is used between these fractions: the chase camera sits just behind the ride, so the first part drew as a
-- long bar up the road (reviewer, 2026-10-23: "a teal beam pointing at nothing")
local FROM, TO = 0.24, 0.97
local SPEED = 0.55 -- stream cycles per second (static in reduced motion)
local SIDE = 1.5 -- studs: narrow enough to see traffic through and around it

export type ArcState = "Available" | "Unavailable" | "Timing" | "Hidden"

local ArcTelegraph = {}
ArcTelegraph.__index = ArcTelegraph

type Chevron = { gui: BillboardGui, holder: Frame, bars: { Frame }, attachment: Attachment }

local function bar(parent: Instance, y: number, rotation: number): Frame
	local f = Instance.new("Frame")
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Position = UDim2.fromScale(0.54, y)
	f.Size = UDim2.fromScale(0.56, 0.17)
	f.Rotation = rotation
	f.BackgroundColor3 = C.HopLight
	f.BorderSizePixel = 0
	f.Parent = parent
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = f
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.Color = INK
	stroke.Transparency = 0.1
	stroke.Parent = f
	return f
end

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
	self._phase = 0

	local carrier = WorldKit.part(ctx.world, "HopArcCarrier", Vector3.new(0.2, 0.2, 0.2), CFrame.new(), C.White)
	carrier.Transparency = 1
	self._trove:Add(carrier)
	self._carrier = carrier
	self._chevrons = {} :: { Chevron }
	for i = 1, CHEVRONS do
		local a = Instance.new("Attachment")
		a.Name = "P" .. i
		a.Parent = carrier
		local gui = Instance.new("BillboardGui")
		gui.Name = "Chevron" .. i
		gui.Adornee = a
		gui.AlwaysOnTop = false -- cars and scenery occlude it
		gui.LightInfluence = 0
		gui.MaxDistance = 160
		gui.ResetOnSpawn = false
		gui.Size = UDim2.fromScale(SIDE, SIDE)
		gui.Enabled = false
		gui.Parent = carrier
		local holder = Instance.new("Frame")
		holder.Name = "Holder"
		holder.AnchorPoint = Vector2.new(0.5, 0.5)
		holder.Position = UDim2.fromScale(0.5, 0.5)
		holder.Size = UDim2.fromScale(1, 1)
		holder.BackgroundTransparency = 1
		holder.Parent = gui
		-- the V points along +x of the holder: two arms meeting at the tip on the right
		local upper = bar(holder, 0.36, 30)
		local lower = bar(holder, 0.64, -30)
		table.insert(self._chevrons, { gui = gui, holder = holder, bars = { upper, lower }, attachment = a })
	end
	self._trove:Add(Motion.onReducedChanged(function()
		self:_apply()
	end))
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

-- Moves every chevron to its place on the current curve. Returns false when the arc cannot be drawn.
function ArcTelegraph._update(self: ArcTelegraph, dt: number): boolean
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
	local function curve(t: number): Vector3
		return start:Lerp(control, t):Lerp(control:Lerp(finish, t), t)
	end
	local camera = Workspace.CurrentCamera
	local moving = not Motion.reduced()
	if moving then
		self._phase = (self._phase + dt * SPEED) % 1
	else
		self._phase = 0 -- steady: the chevrons stand along the arc
	end
	local timing = self._state == "Timing"
	for i, chevron in self._chevrons do
		local f = (self._phase + (i - 1) / CHEVRONS) % 1
		local t = FROM + (TO - FROM) * f
		local q = curve(t)
		chevron.attachment.Position = q -- the carrier sits at the origin, so local = world
		if camera then
			local v1 = camera:WorldToViewportPoint(q)
			local v2 = camera:WorldToViewportPoint(curve(math.min(t + 0.03, 1)))
			chevron.holder.Rotation = math.deg(math.atan2(v2.Y - v1.Y, v2.X - v1.X))
		end
		-- modestly brighter toward the landing; faded in near the car and out at the very end
		local fadeIn = math.clamp(f / 0.12, 0, 1)
		local fadeOut = math.clamp((1 - f) / 0.05, 0, 1)
		local transparency = 1 - (1 - (0.34 - 0.3 * f * f)) * fadeIn * fadeOut
		local colour = C.HopLight
		if f > 0.55 then
			local k = (f - 0.55) / 0.45
			colour = colour:Lerp(if timing then GOLD else C.White, if timing then math.min(k * 1.4, 1) else k * 0.6)
		end
		for _, part in chevron.bars do
			part.BackgroundTransparency = transparency
			part.BackgroundColor3 = colour
		end
	end
	self._updates += 1
	return true
end

function ArcTelegraph._setShown(self: ArcTelegraph, on: boolean)
	if self._shown == on then
		return
	end
	self._shown = on
	for _, chevron in self._chevrons do
		chevron.gui.Enabled = on
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
		self:_setShown(false)
		return
	end
	self:_setShown(self:_update(0))
	if not self._step then
		self._step = RunService.Heartbeat:Connect(function(dt: number)
			local target = self._target
			if not target or not target:IsDescendantOf(game) then
				-- despawned target: drop it and stop following (a new setTarget restarts)
				self._target = nil
				self:_stopStep()
				self:_setShown(false)
				return
			end
			self:_setShown(self:_update(dt))
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
	local enabled = 0
	for _, chevron in self._chevrons do
		if chevron.gui.Enabled then
			enabled += 1
		end
	end
	return {
		state = self._state,
		shown = self._shown,
		chevrons = #self._chevrons,
		visibleChevrons = enabled,
		stepping = self._step ~= nil,
		flowing = self._shown and not Motion.reduced(),
		phase = self._phase,
		updates = self._updates,
		ride = self._ride and self._ride.Name,
		target = self._target and self._target:GetFullName(),
		kind = "directional cue (not a ballistic path)",
	}
end

function ArcTelegraph.destroy(self: ArcTelegraph)
	self._trove:Destroy()
end

return ArcTelegraph
