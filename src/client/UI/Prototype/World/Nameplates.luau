--!strict
-- Traffic nameplates (Lane 3 preview, HUD rebuild 2026-10-22, worker HW; ledger T-01..T-03,
-- K-04 plate state, X-04). ONE pooled manager owns every plate; cars never create their own.
--
-- Choice: a fixed pool of BillboardGuis (not one ScreenGui layer of projected labels).
--   * occlusion comes free: AlwaysOnTop = false lets buildings and cars hide a plate without any
--     raycast (a projected ScreenGui label would need rays to be occluded);
--   * the engine positions billboards every frame; Lua only scores and assigns at 12 Hz;
--   * a billboard keeps its render cache until a property changes, so we write properties only
--     when a quantised value changes (BillboardGui docs, "caching").
--   Cheap labels only: TextLabels and Frames, no ViewportFrames, no images.
--
-- Content (WorldKit.plate): rarity word + pip diamonds (1..5; word and count carry meaning,
-- colour is the third cue), car name, NEW! only when `car.owned == false` (nil = unknown never
-- shows NEW!), the variant tag only when variant ~= "None" (its own row, never merged with the
-- rarity), and an optional state row ("CAPTURING").
--
-- Priority each tick: 1 ridden car, 2 selected Hop target, 3 nearby notable (Rare+ or NEW),
-- 4 nearest others; ties by distance, currently shown plates first (stability). Cap: Desktop 6,
-- Tablet 5, phones 4 (options.cap / setCap override; ridden and target count toward it).
-- Overlap: plates are projected (Camera:WorldToViewportPoint, the same viewport pixels the
-- billboards render in) into rectangles; a lower-priority plate overlapping an accepted one by
-- more than 30% of the smaller area, or a reserved touch zone, is suppressed.
-- Hysteresis: a plate stays at least 0.6 s once shown and stays hidden at least 0.3 s once
-- hidden (ridden/target bypass both); newcomers must be 6 studs inside the fade end to enter;
-- fades in/out over 0.15 s (opacity only, so it is the same in reduced motion).
-- Legibility: plates are sized in pixels (offset), scaled by distance between 1.0 (<= 45 studs)
-- and 0.73 (the smallest text, 22 design px, reaches the 16 px minimum there). Past that point a
-- plate does NOT shrink further: it fades out between 62 and 90 studs; MaxDistance 95 is only a
-- backstop. The ridden car and the target never fade by distance (they clamp at the minimum).
-- Occlusion policy: AlwaysOnTop only for the ridden car and the Hop target (the player must
-- always find them); every other plate is occluded by geometry.
--
--   local plates = Nameplates.new(ctx, { cap = 6? })
--   plates:track(instanceId, model, car)   -- again with the same id updates the car fields
--   plates:untrack(instanceId)             -- despawn: fades and frees the plate
--   plates:setRidden(instanceId?)  plates:setTarget(instanceId?)
--   plates:setPlateState(instanceId, "CAPTURING" | nil)
--   plates:setCap(n?)  plates:isTracked(id) -> boolean  plates:clear()
--   plates:layout(), plates:setVisible(on), plates:destroy(), plates:getDebugState()

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Trove = require(ReplicatedStorage.Packages.Trove)
local WorldKit = require(script.Parent.WorldKit)

local TICK = 1 / 12
local FADE_SECONDS = 0.15
local MIN_ON = 0.6
local MIN_OFF = 0.3
local NEAR = 45 -- studs: full size at or nearer
local K_MIN = 16 / WorldKit.PlateText.Name -- 0.73: smallest text reaches 16 design px
local FADE_START = NEAR / K_MIN -- about 62 studs: minimum size reached, start fading
local FADE_END = 90
local ENTER_MARGIN = 6
local MAX_DISTANCE = 95
local OVERLAP = 0.3
local LIFT = 1.2 -- studs above the roof
local POOL_EXTRA = 3 -- plates allowed to finish fading out beyond the cap
local CAP_BY_PROFILE: { [string]: number } = { Desktop = 6, Tablet = 5, PhoneLandscape = 4, PhonePortrait = 4 }

export type PlateState = "CAPTURING"

type Tracked = {
	id: string,
	model: Instance,
	part: BasePart,
	top: number,
	car: WorldKit.CarInfo,
	state: string?,
	shown: boolean,
	changedAt: number,
	slot: Slot?,
	dist: number,
}

type Slot = {
	board: BillboardGui,
	plate: WorldKit.Plate,
	scale: UIScale,
	owner: Tracked?,
	alpha: number,
	goal: number,
	distAlpha: number,
	k: number,
	onTop: boolean,
	applied: number,
}

local Nameplates = {}
Nameplates.__index = Nameplates

function Nameplates.new(ctx: WorldKit.Ctx, options: { cap: number? }?)
	local self = setmetatable({}, Nameplates)
	self._ctx = ctx
	self._trove = Trove.new()
	self._visible = true
	self._capOverride = options and options.cap
	self._tracked = {} :: { [string]: Tracked }
	self._ridden = nil :: string?
	self._target = nil :: string?
	self._slots = {} :: { Slot }
	self._fadeConn = nil :: RBXScriptConnection?
	self._acc = 0
	self._ticks = 0
	self._lastSuppressed = { overlap = 0, cap = 0, zone = 0, hysteresis = 0 }
	self._scale = WorldKit.billboardScale(ctx)

	local folder = self._trove:Add(Instance.new("Folder"))
	folder.Name = "Nameplates"
	folder.Parent = ctx.world
	self._folder = folder

	local poolSize = 6 + POOL_EXTRA
	for i = 1, poolSize do
		local board = Instance.new("BillboardGui")
		board.Name = "Nameplate" .. i
		board.AlwaysOnTop = false
		board.LightInfluence = 0
		board.MaxDistance = MAX_DISTANCE
		board.ResetOnSpawn = false
		board.Enabled = false
		board.ClipsDescendants = false
		board.Parent = folder
		local frame = Instance.new("Frame")
		frame.Name = "Holder"
		frame.BackgroundTransparency = 1
		frame.Size = UDim2.fromScale(1, 0.5) -- top half: the plate's bottom edge sits on the anchor
		frame.Parent = board
		local scale = Instance.new("UIScale")
		scale.Name = "HudScale"
		scale.Parent = frame
		local plate = WorldKit.plate(frame, { name = "", rarity = "Common", variant = "None", owned = nil })
		plate.holder.AnchorPoint = Vector2.new(0.5, 1)
		plate.holder.Position = UDim2.fromScale(0.5, 1)
		plate.setAlpha(0)
		table.insert(self._slots, {
			board = board,
			plate = plate,
			scale = scale,
			owner = nil,
			alpha = 0,
			goal = 0,
			distAlpha = 1,
			k = 1,
			onTop = false,
			applied = 0,
		})
	end

	self._trove:Connect(RunService.Heartbeat, function(dt: number)
		self._acc += dt
		if self._acc >= TICK then
			self._acc = 0
			self:_tick()
		end
	end)
	self._trove:Add(function()
		self:_stopFade()
	end)
	self:layout()
	return self
end

export type Nameplates = typeof(Nameplates.new((nil :: any) :: WorldKit.Ctx))

function Nameplates._cap(self: Nameplates): number
	if self._capOverride then
		return math.clamp(self._capOverride, 1, 6)
	end
	return CAP_BY_PROFILE[self._ctx.screen:profile().name] or 6
end

function Nameplates.setCap(self: Nameplates, n: number?)
	self._capOverride = n
	self:_tick()
end

-- TRACKING -----------------------------------------------------------------------------------

function Nameplates.track(self: Nameplates, instanceId: string, model: Instance, car: WorldKit.CarInfo)
	local part = WorldKit.mainPart(model)
	if not part then
		return
	end
	local existing = self._tracked[instanceId]
	if existing and existing.model == model then
		existing.car = car
		local sl = existing.slot
		if sl and sl.owner == existing then
			sl.plate.setCar(car)
			self:_applyBoardSize(sl)
		end
		return
	end
	if existing then
		self:untrack(instanceId)
	end
	local box, size = WorldKit.box(model)
	local top = (box.Position.Y + size.Y / 2) - part.Position.Y + LIFT
	self._tracked[instanceId] = {
		id = instanceId,
		model = model,
		part = part :: BasePart,
		top = top,
		car = car,
		state = nil,
		shown = false,
		changedAt = -math.huge,
		slot = nil,
		dist = math.huge,
	}
end

function Nameplates.isTracked(self: Nameplates, instanceId: string): boolean
	local t = self._tracked[instanceId]
	return t ~= nil and t.part.Parent ~= nil
end

function Nameplates._release(self: Nameplates, t: Tracked, immediate: boolean)
	local slot = t.slot
	t.shown = false
	t.changedAt = os.clock()
	if not slot then
		return
	end
	slot.goal = 0
	if immediate then
		slot.alpha = 0
		self:_freeSlot(slot)
	else
		self:_startFade()
	end
end

function Nameplates._freeSlot(_self: Nameplates, slot: Slot)
	local owner = slot.owner
	if owner and owner.slot == slot then
		owner.slot = nil
	end
	slot.owner = nil
	slot.board.Enabled = false
	slot.board.Adornee = nil
	slot.plate.setAlpha(0)
	slot.applied = 0
end

function Nameplates.untrack(self: Nameplates, instanceId: string)
	local t = self._tracked[instanceId]
	if not t then
		return
	end
	self._tracked[instanceId] = nil
	-- a despawned car frees its plate at once; a car leaving tracking fades out
	self:_release(t, t.part.Parent == nil)
	if self._ridden == instanceId then
		self._ridden = nil
	end
	if self._target == instanceId then
		self._target = nil
	end
end

function Nameplates.clear(self: Nameplates)
	for id in table.clone(self._tracked) do
		local t = self._tracked[id]
		self._tracked[id] = nil
		self:_release(t, true)
	end
	self._ridden = nil
	self._target = nil
end

function Nameplates.setRidden(self: Nameplates, instanceId: string?)
	self._ridden = instanceId
	self:_tick()
end

function Nameplates.setTarget(self: Nameplates, instanceId: string?)
	self._target = instanceId
	self:_tick()
end

function Nameplates.setPlateState(self: Nameplates, instanceId: string, state: PlateState?)
	local t = self._tracked[instanceId]
	if not t then
		return
	end
	if state ~= nil and state ~= "CAPTURING" then
		return
	end
	t.state = state
	local sl = t.slot
	if sl and sl.owner == t then
		sl.plate.setState(state)
	end
end

-- SCORING ------------------------------------------------------------------------------------

local function classOf(self: Nameplates, t: Tracked): number
	if t.id == self._ridden then
		return 0
	elseif t.id == self._target then
		return 1
	elseif WorldKit.rank(t.car.rarity) >= 3 or WorldKit.isNew(t.car) then
		return 2
	end
	return 3
end

local function scaleFor(dist: number, forced: boolean): (number, number)
	local k = math.clamp(NEAR / math.max(dist, 1), K_MIN, 1)
	if forced or dist <= FADE_START then
		return WorldKit.quantise(k, 0.05), 1
	end
	local a = 1 - math.clamp((dist - FADE_START) / (FADE_END - FADE_START), 0, 1)
	return WorldKit.quantise(k, 0.05), WorldKit.quantise(a, 0.1)
end

local function overlapFraction(a: Rect, b: Rect): number
	local x0 = math.max(a.min.X, b.min.X)
	local y0 = math.max(a.min.Y, b.min.Y)
	local x1 = math.min(a.max.X, b.max.X)
	local y1 = math.min(a.max.Y, b.max.Y)
	if x1 <= x0 or y1 <= y0 then
		return 0
	end
	local inter = (x1 - x0) * (y1 - y0)
	local areaA = (a.max.X - a.min.X) * (a.max.Y - a.min.Y)
	local areaB = (b.max.X - b.min.X) * (b.max.Y - b.min.Y)
	return inter / math.max(math.min(areaA, areaB), 1)
end

type Rect = { min: Vector2, max: Vector2 }

type Candidate = {
	t: Tracked,
	class: number,
	k: number,
	distAlpha: number,
	rect: Rect,
}

function Nameplates._tick(self: Nameplates)
	self._ticks += 1
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end
	local now = os.clock()
	local camPos = camera.CFrame.Position
	local s = self._scale
	local cap = self:_cap()
	local suppressed = { overlap = 0, cap = 0, zone = 0, hysteresis = 0 }

	-- despawn: anything whose part left the world is dropped right away
	for id, t in table.clone(self._tracked) do
		if t.part.Parent == nil or not t.model:IsDescendantOf(game) then
			self._tracked[id] = nil
			self:_release(t, true)
			if self._ridden == id then
				self._ridden = nil
			end
			if self._target == id then
				self._target = nil
			end
		end
	end

	local candidates: { Candidate } = {}
	if self._visible then
		for _, t in self._tracked do
			local anchor = t.part.Position + Vector3.new(0, t.top, 0)
			local dist = (anchor - camPos).Magnitude
			t.dist = dist
			local class = classOf(self, t)
			local forced = class <= 1
			local limit = if t.shown then FADE_END else FADE_END - ENTER_MARGIN
			if not forced and dist > limit then
				continue
			end
			local v, onScreen = camera:WorldToViewportPoint(anchor)
			if not onScreen or v.Z <= 0 then
				continue
			end
			local k, distAlpha = scaleFor(dist, forced)
			local sl = t.slot
			local w = (if sl then sl.plate.width else 280) * s * k
			local rows = WorldKit.PlateRows
			-- visible content height: hidden rows collapse
			local contentH = rows.Rarity + rows.Name
			if t.state then
				contentH += rows.State
			end
			if WorldKit.isNew(t.car) or (t.car.variant ~= nil and t.car.variant ~= "None") then
				contentH += rows.Tags
			end
			local hPx = contentH * s * k
			table.insert(candidates, {
				t = t,
				class = class,
				k = k,
				distAlpha = distAlpha,
				rect = {
					min = Vector2.new(v.X - w / 2, v.Y - hPx),
					max = Vector2.new(v.X + w / 2, v.Y),
				},
			})
		end
	end
	table.sort(candidates, function(a, b)
		if a.class ~= b.class then
			return a.class < b.class
		end
		if a.t.shown ~= b.t.shown then
			return a.t.shown
		end
		return a.t.dist < b.t.dist
	end)

	local accepted: { Candidate } = {}
	local wanted: { [Tracked]: Candidate } = {}
	local screen = self._ctx.screen
	local origin = screen.root.AbsolutePosition
	for _, c in candidates do
		local forced = c.class <= 1
		if not forced then
			if #accepted >= cap then
				suppressed.cap += 1
				continue
			end
			local clash = false
			for _, a in accepted do
				if overlapFraction(c.rect, a.rect) > OVERLAP then
					clash = true
					break
				end
			end
			if clash then
				suppressed.overlap += 1
				continue
			end
			local pos = screen:toDevice(c.rect.min - origin)
			local size = screen:toDevice(c.rect.max - c.rect.min)
			if screen:overlapsReserved(pos, size) then
				suppressed.zone += 1
				continue
			end
		end
		table.insert(accepted, c)
		wanted[c.t] = c
	end

	-- apply with hysteresis
	for _, t in self._tracked do
		local c = wanted[t]
		local forced = t.id == self._ridden or t.id == self._target
		if c then
			if not t.shown then
				if not forced and now - t.changedAt < MIN_OFF then
					suppressed.hysteresis += 1
					continue
				end
				if not self:_show(t) then
					continue
				end
			end
			self:_update(t, c.k, c.distAlpha, forced)
		elseif t.shown then
			local stillOnScreen = t.dist <= FADE_END
			if not forced and stillOnScreen and now - t.changedAt < MIN_ON and self._visible then
				suppressed.hysteresis += 1
				continue
			end
			self:_release(t, false)
		end
	end
	self._lastSuppressed = suppressed
end

function Nameplates._show(self: Nameplates, t: Tracked): boolean
	-- a plate still fading out for the same car is simply faded back in
	local own = t.slot
	if own and own.owner == t then
		t.shown = true
		t.changedAt = os.clock()
		own.goal = 1
		self:_startFade()
		return true
	end
	local free: Slot? = nil
	for _, slot in self._slots do
		if slot.owner == nil then
			free = slot
			break
		end
	end
	if not free then
		return false
	end
	local slot = free :: Slot
	slot.owner = t
	t.slot = slot
	t.shown = true
	t.changedAt = os.clock()
	slot.plate.setCar(t.car)
	slot.plate.setState(t.state)
	slot.board.Adornee = t.part
	slot.board.StudsOffsetWorldSpace = Vector3.new(0, t.top, 0)
	slot.alpha = 0
	slot.applied = -1
	slot.goal = 1
	slot.plate.setAlpha(0)
	slot.board.Enabled = true
	self:_startFade()
	return true
end

function Nameplates._applyBoardSize(self: Nameplates, slot: Slot)
	local s = self._scale * slot.k
	slot.scale.Scale = s
	local p = slot.plate
	slot.board.Size = UDim2.fromOffset(math.ceil(p.width * s), math.ceil(p.height * s * 2))
end

function Nameplates._update(self: Nameplates, t: Tracked, k: number, distAlpha: number, forced: boolean)
	local slot = t.slot
	if not slot then
		return
	end
	if slot.k ~= k or slot.applied == -1 then
		slot.k = k
		self:_applyBoardSize(slot)
	end
	if slot.onTop ~= forced then
		slot.onTop = forced
		slot.board.AlwaysOnTop = forced
	end
	if slot.distAlpha ~= distAlpha then
		slot.distAlpha = distAlpha
		self:_applyAlpha(slot)
	end
	if slot.applied == -1 then
		self:_applyAlpha(slot)
	end
end

function Nameplates._applyAlpha(_self: Nameplates, slot: Slot)
	local a = WorldKit.quantise(slot.alpha * slot.distAlpha, 0.05)
	if a ~= slot.applied then
		slot.applied = a
		slot.plate.setAlpha(a)
	end
end

-- per-frame fade, connected only while some plate is fading
function Nameplates._startFade(self: Nameplates)
	if self._fadeConn then
		return
	end
	self._fadeConn = RunService.Heartbeat:Connect(function(dt: number)
		local busy = false
		for _, slot in self._slots do
			if slot.owner or slot.alpha > 0 then
				if slot.alpha ~= slot.goal then
					local step = dt / FADE_SECONDS
					slot.alpha = if slot.goal > slot.alpha
						then math.min(slot.goal, slot.alpha + step)
						else math.max(slot.goal, slot.alpha - step)
					self:_applyAlpha(slot)
					if slot.alpha ~= slot.goal then
						busy = true
					elseif slot.goal == 0 then
						self:_freeSlot(slot)
					end
				end
			end
		end
		if not busy then
			self:_stopFade()
		end
	end)
end

function Nameplates._stopFade(self: Nameplates)
	if self._fadeConn then
		self._fadeConn:Disconnect()
		self._fadeConn = nil
	end
end

-- COMPONENT ----------------------------------------------------------------------------------

function Nameplates.layout(self: Nameplates)
	self._scale = WorldKit.billboardScale(self._ctx)
	for _, slot in self._slots do
		if slot.owner then
			self:_applyBoardSize(slot)
		end
	end
end

function Nameplates.setVisible(self: Nameplates, on: boolean)
	self._visible = on
	if not on then
		for _, t in self._tracked do
			if t.shown then
				self:_release(t, true)
			end
		end
	end
	self:_tick()
end

function Nameplates.getDebugState(self: Nameplates): { [string]: any }
	local tracked, shownIds, inUse, fading, onTop = 0, {}, 0, 0, 0
	for _, t in self._tracked do
		tracked += 1
		if t.shown then
			table.insert(shownIds, t.id)
		end
	end
	table.sort(shownIds)
	for _, slot in self._slots do
		if slot.owner then
			inUse += 1
		end
		if slot.alpha ~= slot.goal then
			fading += 1
		end
		if slot.board.Enabled and slot.board.AlwaysOnTop then
			onTop += 1
		end
	end
	return {
		tracked = tracked,
		shown = shownIds,
		shownCount = #shownIds,
		cap = self:_cap(),
		pool = #self._slots,
		slotsInUse = inUse,
		fading = fading,
		alwaysOnTop = onTop,
		ridden = self._ridden,
		target = self._target,
		suppressed = self._lastSuppressed,
		ticks = self._ticks,
		tickHz = math.floor(1 / TICK),
		fadeConnected = self._fadeConn ~= nil,
		visible = self._visible,
		billboards = #self._folder:GetChildren(),
	}
end

function Nameplates.destroy(self: Nameplates)
	self._trove:Destroy()
	table.clear(self._tracked)
end

return Nameplates
