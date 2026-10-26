--!strict
-- Hop arc telegraph (Lane 3 preview; chevron stream rebuilt in Round 2, R2-P1; origin moved onto the ridden car's
-- roof in Round 3, R3-L3; worker HW built the original dotted version, HUD rebuild 2026-10-22, ledger T-06, T-07).
--
-- A DIRECTIONAL CUE DRIVEN BY TARGET DATA, NOT A BALLISTIC PATH. A narrow stream of small chevrons flows from the
-- ridden car's roof toward the point above the selected target, so the player sees which car the Hop goes to and
-- which way it goes. Its height and shape are a fixed presentation rule (a quadratic curve whose apex sits 1.5-4
-- studs above the higher end); they do not predict where a jump would land, how long it takes, or whether it
-- succeeds. Lane 1 (Brian R) owns the real Hop and any trajectory; until it supplies one this stays a direction cue.
--
--   * ORIGIN (R3-L3): the stream is BORN ON the ridden car's roof, not ahead of it. The roof anchor is measured ONCE
--     per ridden car, in the car's own pivot space, and only applied to the car's current pose each frame (nothing
--     is measured per frame, so it cannot jitter). It is the first of these that the model has:
--       1. an Attachment named "RideTop" anywhere in the model (the contract a finished car can supply);
--       2. an open vehicle (attribute OpenTop = true or VehicleKind = "Motorcycle"): an Attachment named
--          "SeatAnchor", else the seat height (62% of the box) at the box centre, as the landing reticle does;
--       3. a closed vehicle: the roof top, at the footprint-weighted centre of its highest big parts (a pickup's cab,
--          not its empty bed), ROOF_INSET under the box top; with nothing big enough to measure, the bounding-box
--          top centre.
--     The stream starts ORIGIN_LIFT above the anchor along the car's up and rises, so it never crosses the body.
--     The destination is anchored the same way on the target and follows it as both move.
--   * a POOL of 11 chevrons (never more than 12), each a small billboard (2 rounded bars forming a V, depth-tested
--     so cars and scenery occlude it) turned along the curve's on-screen direction; they flow toward the target and
--     fade in near the car and out at the landing; they are narrow (1.5 studs) so traffic stays visible through and
--     around the stream: no luminous hose on the road;
--   * brightness rises modestly toward the landing; during the best-timing window the last part warms to the gold
--     accent;
--   * RETARGET: positions are recomputed from the current curve every frame, so the stream swings to the new target
--     at once and nothing of the old one remains (no trails, no history);
--   * shown only for "Available" and "Timing"; hidden for "Unavailable" and "Hidden" (an arc to an unavailable
--     target would imply a valid jump), when either car is missing or despawned (it then stops following and lets
--     go of the car), and when the cars are under 3 or over 140 studs apart;
--   * REDUCED MOTION: the chevrons stand still along the arc (steady, no flow, no brightness change over time).
-- Follows the cars on Heartbeat only while shown.
--
--   local arc = ArcTelegraph.new(ctx, { ride = model?, target = model? })
--   arc:setRide(model?)  arc:setTarget(model?)  arc:setState(state)
--   arc:origin() -> Vector3?       arc:destination() -> Vector3?   -- the two ends of the stream, from the cars' pose now
--   arc:points() -> { Vector3 }                                    -- where the shown chevrons are (for tests)
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

local CHEVRONS = 11 -- the pool; the brief caps it at 12 (9 over 73% of the curve before; about the same spacing now)
local MIN_GAP, MAX_GAP = 3, 140
-- the curve is used between these fractions. Round 2 started at 0.24 (the old bar-like trail drew as "a teal beam
-- pointing at nothing" from the chase camera); Round 3 starts ON the ridden car's roof (Adam: "it must visibly begin
-- on that car"), and each chevron fades in over its first 12%, so nothing draws as a bar from the camera
local FROM, TO = 0, 0.97
local SPEED = 0.55 -- stream cycles per second (static in reduced motion)
local SIDE = 1.5 -- studs: narrow enough to see traffic through and around it
-- TOKEN CANDIDATE (R3-L3): how the roof anchor is measured and where the stream starts
local ROOF_INSET = 0.1 -- the anchor sits this far under the box top (low-poly roofs are not flat to the box)
local ROOF_BAND = 0.6 -- parts whose tops are within this of the highest big top make up the roof
local ROOF_SHARE = 0.05 -- a part is "big" when its footprint is at least this share of the car's footprint
local SEAT_HEIGHT = 0.62 -- open vehicles: the seat as a share of the box height (the landing reticle's rule)
local ORIGIN_LIFT = 0.4 -- the stream starts this far above the ridden car's anchor, so the first chevron clears the roof
local DEST_LIFT = 0.5 -- ...and ends this far above the target's anchor (0.4 above its roof top, as in Round 2)

export type ArcState = "Available" | "Unavailable" | "Timing" | "Hidden"

local ArcTelegraph = {}
ArcTelegraph.__index = ArcTelegraph

type Chevron = { gui: BillboardGui, holder: Frame, bars: { Frame }, attachment: Attachment }
-- a roof anchor: a point in the model's pivot space, and which rule found it ("RideTop", "Seat", "Open", "Roof", "Box")
type Anchor = { point: Vector3, kind: string }
-- the measured anchor of one model, kept until the model changes
type Slot = { model: Instance?, anchor: Anchor? }
-- one part's footprint in the pivot space: its centre, its area seen from above, and the height of its top
type Slab = { x: number, z: number, area: number, top: number }

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
	self._rideSlot = { model = nil, anchor = nil } :: Slot
	self._targetSlot = { model = nil, anchor = nil } :: Slot
	self._measures = 0 -- anchors measured so far: once per ridden car, once per target, never per frame
	self._start = nil :: Vector3? -- the ends of the stream as last drawn
	self._finish = nil :: Vector3?

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

-- ANCHORS ------------------------------------------------------------------------------------------------------

-- The model's current pivot, or nil when it is not in the game (a model that is gone has no pose to follow).
local function pivotOf(model: Instance?): CFrame?
	if not model or not model:IsDescendantOf(game) then
		return nil
	end
	if model:IsA("Model") then
		return (model :: Model):GetPivot()
	elseif model:IsA("BasePart") then
		return (model :: BasePart).CFrame
	end
	return nil
end

local function attachmentNamed(model: Instance, name: string): Attachment?
	local found = model:FindFirstChild(name, true)
	if found and found:IsA("Attachment") then
		return found :: Attachment
	end
	return nil
end

-- Measures a model's roof anchor in its pivot space (see the header for the rules). Called once per model.
local function measure(model: Instance, pivot: CFrame): Anchor
	local tag = attachmentNamed(model, "RideTop")
	if tag then
		return { point = pivot:PointToObjectSpace(tag.WorldPosition), kind = "RideTop" }
	end
	local box, size = WorldKit.box(model)
	if model:GetAttribute("OpenTop") == true or model:GetAttribute("VehicleKind") == "Motorcycle" then
		local seat = attachmentNamed(model, "SeatAnchor")
		if seat then
			return { point = pivot:PointToObjectSpace(seat.WorldPosition), kind = "Seat" }
		end
		return { point = pivot:PointToObjectSpace(box * Vector3.new(0, size.Y * (SEAT_HEIGHT - 0.5), 0)), kind = "Open" }
	end
	-- closed: every visible part's footprint and top, in the pivot space (an axis-aligned box around each part)
	local candidates = model:GetDescendants()
	table.insert(candidates, model)
	local slabs: { Slab } = {}
	local minX, maxX, minZ, maxZ = math.huge, -math.huge, math.huge, -math.huge
	for _, item in candidates do
		if not item:IsA("BasePart") then
			continue
		end
		local part = item :: BasePart
		if part.Transparency >= 0.95 then
			continue -- an invisible root or hitbox is not the roof
		end
		local px, py, pz, r00, r01, r02, r10, r11, r12, r20, r21, r22 = pivot:ToObjectSpace(part.CFrame):GetComponents()
		local s = part.Size
		local hx = (math.abs(r00) * s.X + math.abs(r01) * s.Y + math.abs(r02) * s.Z) / 2
		local hy = (math.abs(r10) * s.X + math.abs(r11) * s.Y + math.abs(r12) * s.Z) / 2
		local hz = (math.abs(r20) * s.X + math.abs(r21) * s.Y + math.abs(r22) * s.Z) / 2
		minX, maxX = math.min(minX, px - hx), math.max(maxX, px + hx)
		minZ, maxZ = math.min(minZ, pz - hz), math.max(maxZ, pz + hz)
		table.insert(slabs, { x = px, z = pz, area = 4 * hx * hz, top = py + hy })
	end
	local big = ROOF_SHARE * (maxX - minX) * (maxZ - minZ)
	local roofTop = -math.huge
	for _, slab in slabs do
		if slab.area >= big and slab.top > roofTop then
			roofTop = slab.top -- the highest big surface (an antenna or a roof light is too small to count)
		end
	end
	local sumX, sumZ, sumArea = 0, 0, 0
	for _, slab in slabs do
		if slab.area >= big and slab.top >= roofTop - ROOF_BAND then
			sumX += slab.x * slab.area
			sumZ += slab.z * slab.area
			sumArea += slab.area
		end
	end
	if sumArea <= 0 then
		-- nothing to measure: the bounding-box top centre
		return { point = pivot:PointToObjectSpace(box * Vector3.new(0, size.Y / 2 - ROOF_INSET, 0)), kind = "Box" }
	end
	return { point = Vector3.new(sumX / sumArea, roofTop - ROOF_INSET, sumZ / sumArea), kind = "Roof" }
end

-- The anchor's world point on the model NOW, `lift` studs above it along the model's up.
local function lifted(model: Instance?, anchor: Anchor?, lift: number): Vector3?
	local pivot = pivotOf(model)
	if not pivot or not anchor then
		return nil
	end
	return pivot:PointToWorldSpace(anchor.point) + pivot.UpVector * lift
end

-- The anchor of `model`: measured the first time, kept while the model stays the same, forgotten when it goes.
function ArcTelegraph._anchor(self: ArcTelegraph, slot: Slot, model: Instance?): Anchor?
	if not model then
		slot.model, slot.anchor = nil, nil
		return nil
	end
	if slot.model == model and slot.anchor then
		return slot.anchor
	end
	local pivot = pivotOf(model)
	if not pivot then
		return nil -- not in the game yet: measured on the first frame it is
	end
	local anchor = measure(model, pivot)
	slot.model, slot.anchor = model, anchor
	self._measures += 1
	return anchor
end

-- The two ends of the stream from the cars' pose right now (nil for an end whose car is missing or gone).
function ArcTelegraph._ends(self: ArcTelegraph): (Vector3?, Vector3?)
	local start = lifted(self._ride, self:_anchor(self._rideSlot, self._ride), ORIGIN_LIFT)
	local finish = lifted(self._target, self:_anchor(self._targetSlot, self._target), DEST_LIFT)
	return start, finish
end

-- Moves every chevron to its place on the current curve. Returns false when the arc cannot be drawn.
function ArcTelegraph._update(self: ArcTelegraph, dt: number): boolean
	local start, finish = self:_ends()
	self._start, self._finish = start, finish
	if not start or not finish then
		return false
	end
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
	-- no cue without BOTH cars: no target means no stream, and nothing keeps running
	local wanted = self._visible
		and (self._state == "Available" or self._state == "Timing")
		and self._ride ~= nil
		and self._target ~= nil
	if not wanted then
		self:_stopStep()
		self:_setShown(false)
		self._start, self._finish = nil, nil
		return
	end
	self:_setShown(self:_update(0))
	if not self._step then
		self._step = RunService.Heartbeat:Connect(function(dt: number)
			local ride, target = self._ride, self._target
			if not ride or not ride:IsDescendantOf(game) or not target or not target:IsDescendantOf(game) then
				-- a despawned car (the ridden one or the target): let go of it and stop following (a new setRide or
				-- setTarget restarts), so no trail is left behind
				if ride and not ride:IsDescendantOf(game) then
					self._ride = nil
					self._rideSlot.model, self._rideSlot.anchor = nil, nil
				end
				if target and not target:IsDescendantOf(game) then
					self._target = nil
					self._targetSlot.model, self._targetSlot.anchor = nil, nil
				end
				self:_stopStep()
				self:_setShown(false)
				self._start, self._finish = nil, nil
				return
			end
			self:_setShown(self:_update(dt))
		end)
	end
end

function ArcTelegraph.setRide(self: ArcTelegraph, model: Instance?)
	if model ~= self._ride then
		self._rideSlot.model, self._rideSlot.anchor = nil, nil -- a new ridden car is measured afresh, once
	end
	self._ride = model
	self:_apply()
end

function ArcTelegraph.setTarget(self: ArcTelegraph, model: Instance?)
	if model ~= self._target then
		self._targetSlot.model, self._targetSlot.anchor = nil, nil
	end
	self._target = model
	self:_apply()
end

-- The stream's origin on the ridden car, from the car's pose right now (nil without a ridden car in the game).
function ArcTelegraph.origin(self: ArcTelegraph): Vector3?
	local start = self:_ends()
	return start
end

-- The stream's destination above the selected target, from the target's pose right now.
function ArcTelegraph.destination(self: ArcTelegraph): Vector3?
	local _, finish = self:_ends()
	return finish
end

-- Where the shown chevrons are (in drawing order), for tests.
function ArcTelegraph.points(self: ArcTelegraph): { Vector3 }
	local out: { Vector3 } = {}
	for _, chevron in self._chevrons do
		if chevron.gui.Enabled then
			table.insert(out, chevron.attachment.Position)
		end
	end
	return out
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
	local function plain(v: Vector3?): { [string]: number }?
		return if v then { x = v.X, y = v.Y, z = v.Z } else nil
	end
	local ridden = self._rideSlot.anchor
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
		origin = plain(self._start), -- the ends as last drawn (a frame behind a moving car; origin() is the pose now)
		destination = plain(self._finish),
		anchorKind = ridden and ridden.kind,
		anchorMeasures = self._measures, -- once per ridden car and per target, never per frame
		instances = #self._carrier:GetDescendants() + 1, -- carrier, attachments, billboards and their parts
		connections = 1 + (if self._step then 1 else 0), -- the reduced-motion listener, plus the follow step while shown
		threads = 0,
		kind = "directional cue (not a ballistic path)",
	}
end

function ArcTelegraph.destroy(self: ArcTelegraph)
	self._trove:Destroy()
end

return ArcTelegraph
