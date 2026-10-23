--!strict
-- Rare-or-better arrival reveal (Lane 3 preview, HUD rebuild 2026-10-22, worker HW; ledger
-- T-04). A brief side ribbon that says what arrived ("RARE · NEARBY", the car name, and NEW!
-- only when `car.owned == false`); no urgency, countdown or "don't miss it" wording.
--
-- Driven by the store event RareArrival { instanceId, car }:
--   * Rare, Epic and Legendary only (Common/Uncommon are ignored);
--   * dedupe by traffic instance identity per run: the same car leaving and re-entering view is
--     announced at most once; two cars of the same model are two arrivals;
--   * arrivals within 0.12 s are coalesced and the highest rarity is shown first;
--   * a 6 s cooldown between reveal starts and a ONE-slot queue: a higher rarity replaces a
--     lower queued one; a queued reveal is dropped when it is older than 6.5 s, its car is no
--     longer present (options.isPresent), or a quiet time starts;
--   * silent (dropped, not queued) outside Run, during Results, while a warning is active, in
--     Critical/Meltdown, or while the screen arbiter's Safety level holds the slot;
--   * screen slot: requests "Side" at level "Reward" (then "Upper"); a revoke hides it at once.
-- Placement: the shared "Side" column (RunLayout.sideRect: left of the protected road-ahead
-- region, clear of the claim tray); without it, below the top stack outside RunLayout.protected.
-- Motion: slides 40 px in from the edge with a fade (0.22 s), holds 1.8 s, fades out (0.25 s);
-- reduced motion: fade only. Sound: one soft "Toast" chime per reveal.
--
--   local reveal = RareReveal.new(ctx, { isPresent = function(instanceId) -> boolean }?)
--   reveal:arrive(instanceId, car)      -- the same path as the store event (for direct calls)
--   reveal:forget(instanceId)           -- the car despawned: drop it from the queue
--   reveal:resetRun()                   -- a new run: forget announced identities
--   reveal:layout(), reveal:setVisible(on), reveal:destroy(), reveal:getDebugState()

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Arcade = require(script.Parent.Parent.Arcade)
local Motion = require(script.Parent.Parent.Motion)
local PreviewTokens = require(script.Parent.Parent.PreviewTokens)
local Priority = require(script.Parent.Parent.Priority)
local RunLayout = require(script.Parent.Parent.Run.RunLayout)
local Sounds = require(script.Parent.Parent.Sounds)
local Store = require(script.Parent.Parent.Store)
local Trove = require(ReplicatedStorage.Packages.Trove)
local WorldKit = require(script.Parent.WorldKit)

local COALESCE = 0.12
local COOLDOWN = 6
local STALE = 6.5
local IN_SECONDS = 0.22
local HOLD_SECONDS = 1.8
local OUT_SECONDS = 0.25
local SLIDE = 40
local SIZE = Vector2.new(300, 74)
local MIN_WIDTH = 200

type Entry = { instanceId: string, car: WorldKit.CarInfo, at: number }

local RareReveal = {}
RareReveal.__index = RareReveal

function RareReveal.new(ctx: WorldKit.Ctx, options: { isPresent: ((string) -> boolean)? }?)
	local self = setmetatable({}, RareReveal)
	self._ctx = ctx
	self._trove = Trove.new()
	self._visible = true
	self._isPresent = options and options.isPresent
	self._announced = {} :: { [string]: boolean }
	self._collect = {} :: { Entry }
	self._collecting = false
	self._showing = nil :: Entry?
	self._queued = nil :: Entry?
	self._lastStart = -math.huge
	self._token = 0
	self._handle = nil :: Priority.Handle?
	self._retry = false
	self._counts = { shown = 0, deduped = 0, belowRare = 0, silenced = 0, replaced = 0, dropped = 0, stale = 0 }

	local root = RunLayout.canvas(ctx :: any, "RareReveal")
	self._trove:Add(root)
	self.root = root
	local group = Instance.new("CanvasGroup")
	group.Name = "Ribbon"
	group.BackgroundTransparency = 1
	group.Size = UDim2.fromOffset(SIZE.X + 40, SIZE.Y + 30)
	group.GroupTransparency = 1
	group.Visible = false
	group.Active = false
	group.Parent = root
	self._group = group
	local body = Arcade.make("Frame", {
		Name = "Body",
		Position = UDim2.fromOffset(14, 16),
		Size = UDim2.fromOffset(SIZE.X, SIZE.Y),
		BackgroundColor3 = Color3.new(1, 1, 1),
		ZIndex = 2,
		Parent = group,
	}) :: Frame
	Arcade.corner(body)
	Arcade.outline(body, "Button")
	self._fill = Arcade.make("UIGradient", { Rotation = 90, Parent = body }) :: UIGradient
	Arcade.gloss(body)
	self._body = body
	local icon = Arcade.make("Frame", {
		Name = "Icon",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, -10, 0.5, -2),
		Size = UDim2.fromOffset(62, 62),
		BackgroundTransparency = 1,
		ZIndex = 6,
		Parent = body,
	}) :: Frame
	Arcade.icon(icon, "Car")
	local row = Arcade.make("Frame", {
		Name = "Headline",
		Position = UDim2.fromOffset(58, 6),
		Size = UDim2.new(1, -64, 0, 34),
		BackgroundTransparency = 1,
		ZIndex = 6,
		Parent = body,
	}) :: Frame
	Arcade.make("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 6),
		Parent = row,
	})
	local pips = Arcade.make("Frame", {
		Name = "Pips",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(0, 14),
		AutomaticSize = Enum.AutomaticSize.X,
		LayoutOrder = 1,
		ZIndex = 6,
		Parent = row,
	}) :: Frame
	Arcade.make("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, 4),
		Parent = pips,
	})
	self._pips = {} :: { Frame }
	for i = 1, 5 do
		local d = Arcade.make("Frame", {
			Name = "Pip" .. i,
			Size = UDim2.fromOffset(9, 9),
			Rotation = 45,
			BackgroundColor3 = Color3.new(1, 1, 1),
			ZIndex = 7,
			Parent = pips,
		}) :: Frame
		Arcade.corner(d, 2)
		Arcade.outline(d, "Minor")
		table.insert(self._pips, d)
	end
	local word = Arcade.text(row, {
		text = "RARE",
		role = "Value",
		name = "Rarity",
		size = 26,
		outline = "Major",
		autoWidth = true,
		z = 7,
	})
	word.LayoutOrder = 2
	self._word = word
	local nearby = Arcade.text(row, {
		text = "NEARBY",
		role = "Label",
		name = "Nearby",
		size = 18,
		autoWidth = true,
		z = 7,
	})
	nearby.LayoutOrder = 3
	local name = Arcade.text(body, {
		text = "",
		role = "Label",
		name = "CarName",
		size = 20,
		xAlign = Enum.TextXAlignment.Left,
		outline = "Major",
		z = 7,
	})
	name.Position = UDim2.fromOffset(58, 40)
	name.Size = UDim2.new(1, -64, 0, 28)
	name.TextTruncate = Enum.TextTruncate.AtEnd
	self._name = name
	local newTag = Arcade.text(group, {
		text = "NEW!",
		role = "Label",
		name = "New",
		size = 20,
		italic = true,
		outline = "Major",
		autoWidth = true,
		z = 9,
	})
	newTag.AnchorPoint = Vector2.new(1, 0.5)
	newTag.Position = UDim2.fromOffset(14 + SIZE.X + 6, 16)
	newTag.Rotation = -8 -- purposeful asymmetry
	Arcade.make("UIGradient", { Color = PreviewTokens.Arcade.Face.Danger, Rotation = 90, Parent = newTag })
	self._new = newTag

	self._trove:Connect(ctx.store.Event, function(event: Store.Event)
		if event.kind == "RareArrival" and type(event.instanceId) == "string" and event.car then
			self:arrive(event.instanceId :: string, event.car :: any)
		end
	end)
	self._trove:Connect(ctx.store.ModeChanged, function(mode: Store.Mode, from: Store.Mode?)
		if mode ~= "Run" then
			self:_quietNow()
		end
		if (mode == "Run" and from ~= "Run") or from == nil then
			self:resetRun()
		end
	end)
	self._trove:Add(ctx.store:subscribe("run", function(run: Store.RunState?)
		if not run or run.warning or run.stage == "Critical" or run.stage == "Meltdown" then
			self:_quietNow()
		end
	end))
	self._trove:Add(function()
		self._token += 1
		Motion.cancelAll(self._group)
		self:_release()
	end)
	self:layout()
	return self
end

export type RareReveal = typeof(RareReveal.new((nil :: any) :: WorldKit.Ctx))

function RareReveal._quiet(self: RareReveal): boolean
	local state = self._ctx.store:get()
	if state.mode ~= "Run" or not state.run then
		return true
	end
	local run = state.run :: Store.RunState
	if run.warning or run.stage == "Critical" or run.stage == "Meltdown" then
		return true
	end
	local arb = self._ctx.priority
	if arb then
		local _, level = arb:holder("Center")
		if level == "Safety" then
			return true
		end
	end
	return false
end

-- A quiet time began: drop what is waiting and hide what is showing (no catch-up later).
function RareReveal._quietNow(self: RareReveal)
	table.clear(self._collect)
	if self._queued then
		self._queued = nil
		self._counts.dropped += 1
	end
	if self._showing then
		self:_hide(true)
	end
end

function RareReveal.resetRun(self: RareReveal)
	table.clear(self._announced)
	self._lastStart = -math.huge
end

function RareReveal.forget(self: RareReveal, instanceId: string)
	local q = self._queued
	if q and q.instanceId == instanceId then
		self._queued = nil
		self._counts.dropped += 1
	end
end

function RareReveal.arrive(self: RareReveal, instanceId: string, car: WorldKit.CarInfo)
	if WorldKit.rank(car.rarity) < 3 then
		self._counts.belowRare += 1
		return
	end
	if self._announced[instanceId] then
		self._counts.deduped += 1
		return
	end
	if self:_quiet() then
		self._counts.silenced += 1
		return
	end
	for _, e in self._collect do
		if e.instanceId == instanceId then
			self._counts.deduped += 1
			return
		end
	end
	local s = self._showing
	local q = self._queued
	if (s and s.instanceId == instanceId) or (q and q.instanceId == instanceId) then
		self._counts.deduped += 1
		return
	end
	table.insert(self._collect, { instanceId = instanceId, car = car, at = os.clock() })
	if not self._collecting then
		self._collecting = true
		task.delay(COALESCE, function()
			self._collecting = false
			self:_flush()
		end)
	end
end

local function better(a: Entry, b: Entry?): boolean
	if not b then
		return true
	end
	local ra, rb = WorldKit.rank(a.car.rarity), WorldKit.rank(b.car.rarity)
	if ra ~= rb then
		return ra > rb
	end
	return a.at < b.at
end

function RareReveal._flush(self: RareReveal)
	local batch = table.clone(self._collect)
	table.clear(self._collect)
	table.sort(batch, function(a, b)
		return better(a, b)
	end)
	for _, e in batch do
		self:_offer(e)
	end
end

function RareReveal._valid(self: RareReveal, e: Entry): boolean
	if os.clock() - e.at > STALE then
		self._counts.stale += 1
		return false
	end
	if self._isPresent and not self._isPresent(e.instanceId) then
		self._counts.dropped += 1
		return false
	end
	return not self._announced[e.instanceId]
end

function RareReveal._offer(self: RareReveal, e: Entry)
	if not self._showing and os.clock() - self._lastStart >= COOLDOWN and not self:_quiet() then
		if self:_show(e) then
			return
		end
	end
	local q = self._queued
	if not q or WorldKit.rank(e.car.rarity) > WorldKit.rank(q.car.rarity) then
		if q then
			self._counts.replaced += 1
		end
		self._queued = e
		self:_scheduleRetry()
	else
		self._counts.dropped += 1
	end
end

function RareReveal._scheduleRetry(self: RareReveal)
	if self._retry then
		return
	end
	self._retry = true
	local wait = math.max(COOLDOWN - (os.clock() - self._lastStart), 0.5)
	task.delay(wait, function()
		self._retry = false
		local q = self._queued
		if not q then
			return
		end
		if not self:_valid(q) or self:_quiet() then
			self._queued = nil
			return
		end
		if self._showing or os.clock() - self._lastStart < COOLDOWN then
			self:_scheduleRetry()
			return
		end
		self._queued = nil
		if not self:_show(q) then
			self._counts.dropped += 1
		end
	end)
end

function RareReveal._release(self: RareReveal)
	local arb = self._ctx.priority
	if arb and self._handle then
		arb:release(self._handle)
	end
	self._handle = nil
end

function RareReveal._show(self: RareReveal, e: Entry): boolean
	if not self._visible then
		self._counts.dropped += 1
		return true
	end
	local arb = self._ctx.priority
	local granted = arb == nil
	if arb then
		local id = "rare-" .. e.instanceId
		local callbacks = {
			grant = function() end,
			revoke = function()
				if self._showing == e then
					self._handle = nil
					self:_hide(true)
				end
			end,
			wait = 0,
		}
		for _, slot in { "Side", "Upper" } :: { Priority.Slot } do
			local h = arb:request(slot, "Reward", id, callbacks)
			if h then
				local holder = arb:holder(slot)
				if holder == id then
					self._handle = h
					granted = true
					break
				end
				arb:release(h)
			end
		end
	end
	if not granted then
		return false
	end
	self._announced[e.instanceId] = true
	self._showing = e
	self._lastStart = os.clock()
	self._counts.shown += 1
	self:_fillCar(e.car)
	self:_place()
	self._token += 1
	local token = self._token
	local group = self._group
	local rest = group.Position
	local reduced = Motion.reduced()
	group.Visible = true
	group.GroupTransparency = 1
	if not reduced then
		group.Position = rest - UDim2.fromOffset(SLIDE, 0)
		Motion.tween(group, "slide", Motion.info(IN_SECONDS, Enum.EasingStyle.Back), { Position = rest })
	end
	Motion.tween(group, "fade", Motion.info(if reduced then 0.15 else IN_SECONDS), { GroupTransparency = 0 })
	Sounds.play("Toast")
	task.delay(IN_SECONDS + HOLD_SECONDS, function()
		if token == self._token then
			self:_hide(false)
		end
	end)
	return true
end

function RareReveal._fillCar(self: RareReveal, car: WorldKit.CarInfo)
	local r = WorldKit.rarity(car.rarity)
	self._fill.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, r.light:Lerp(Color3.new(1, 1, 1), 0.2)),
		ColorSequenceKeypoint.new(0.5, r.light),
		ColorSequenceKeypoint.new(1, r.deep),
	})
	self._word.Text = r.label
	for i, p in self._pips do
		p.Visible = i <= r.pips
		p.BackgroundColor3 = Color3.new(1, 1, 1)
	end
	self._name.Text = car.name
	self._new.Visible = WorldKit.isNew(car)
end

function RareReveal._hide(self: RareReveal, quick: boolean)
	self._token += 1
	local token = self._token
	local group = self._group
	self._showing = nil
	local seconds = if quick then 0.12 else OUT_SECONDS
	Motion.tween(group, "fade", Motion.info(seconds), { GroupTransparency = 1 })
	task.delay(seconds + 0.02, function()
		if token == self._token then
			group.Visible = false
		end
	end)
	self:_release()
	if self._queued then
		self:_scheduleRetry()
	end
end

-- left column below the top stack, outside the landing band; right column as a fallback
function RareReveal._place(self: RareReveal)
	local ctx = self._ctx :: any
	local m = RunLayout.Margin
	local band = RunLayout.landingBand(ctx)
	-- preferred: the shared "Side" column (RunLayout.sideRect: left of the protected road region,
	-- clear of the claim tray; the band above it in phone portrait)
	local okSide, side = pcall(function()
		return (RunLayout :: any).sideRect(ctx)
	end)
	local x, y, w
	if okSide and side then
		local r = side :: RunLayout.Rect
		w = math.clamp(r.size.X - 20, MIN_WIDTH, SIZE.X)
		x = r.pos.X
		y = r.pos.Y + math.max((r.size.Y - SIZE.Y) / 2, 0) - 16
	else
		local okTop, top = pcall(RunLayout.topBlock, ctx)
		y = if okTop then (top :: RunLayout.Rect).pos.Y + (top :: RunLayout.Rect).size.Y + 8 else 96
		w = math.clamp(band.pos.X - 2 * m, MIN_WIDTH, SIZE.X)
		local d = RunLayout.design(ctx)
		local h = SIZE.Y + 30
		local rect = RunLayout.solve(ctx, {
			RunLayout.rect(m, y, w + 40, h, "RareLeft"),
			RunLayout.rect(d.X - m - w - 40, y, w + 40, h, "RareRight"),
			RunLayout.rect(m, band.pos.Y + band.size.Y + 4, w + 40, h, "RareLeftLow"),
		}, { band })
		x, y = rect.pos.X, rect.pos.Y
	end
	self._group.Position = UDim2.fromOffset(x - 14, y)
	self._body.Size = UDim2.fromOffset(w, SIZE.Y)
	self._new.Position = UDim2.fromOffset(14 + w + 6, 16)
end

function RareReveal.layout(self: RareReveal)
	RunLayout.fit(self._ctx :: any, self.root)
	if self._showing then
		self:_place()
	end
end

function RareReveal.setVisible(self: RareReveal, on: boolean)
	self._visible = on
	self.root.Visible = on
	if not on then
		self:_quietNow()
	end
end

function RareReveal.getDebugState(self: RareReveal): { [string]: any }
	local announced = 0
	for _ in self._announced do
		announced += 1
	end
	local s, q = self._showing, self._queued
	return {
		showing = s and s.instanceId,
		queued = q and q.instanceId,
		collecting = #self._collect,
		announcedThisRun = announced,
		cooldownLeft = math.max(0, COOLDOWN - (os.clock() - self._lastStart)),
		counts = table.clone(self._counts),
		holdsSlot = self._handle ~= nil,
		groupVisible = self._group.Visible,
	}
end

function RareReveal.destroy(self: RareReveal)
	self._trove:Destroy()
end

return RareReveal
