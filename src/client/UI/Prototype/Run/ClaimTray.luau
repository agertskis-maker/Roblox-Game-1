--!strict
-- "Claimed this run" tray (Lane 3 preview, HUD rebuild worker HR; U-06). Left middle, below the
-- compact Cash: a clear count ("2 CLAIMED", italic number), bounded
-- cheap thumbnails (rarity-coloured tiles with the car icon and name; NO ViewportFrames), and an
-- overflow "+N" chip that opens a scrollable review of every car claimed this run.
--
-- Display only. Sources of confirmed claims (union, deduplicated by capture / claim id):
--   * store.run.claims (the supplied confirmed list), and
--   * store events { kind = "KeysConfirmed", captureId, car } (the confirmed-claim event).
-- store.run.pendingClaim shows a distinct DASHED, GHOSTED slot with "SECURING…" and NEVER
-- increases the count; it disappears once that id is confirmed. AlreadyOwned (Joyride) events
-- never count (no new claim).
--
-- Arrival: the count increments EXACTLY ONCE per claim id, with a small Stamp. If the capture
-- ribbon is presenting that id it first calls tray:expect(id); the tray then waits for
-- tray:arrive(id) (the car icon settling in) or 4 s, whichever is first, so a late or
-- suppressed ribbon can never lose or double a count. A confirmation that arrives late (after a
-- Canceled, after run end) still counts once. A new run (mode -> Run) clears the tray.
--
--   local tray = ClaimTray.new(ctx)
--   tray:expect(id)                     -- the ribbon is presenting this id (hold the +1)
--   tray:arrive(id, car?)               -- the icon has settled: +1 now (idempotent)
--   tray:arrivalPoint(id) -> Vector2?   -- absolute GUI position where that id will appear
--   tray:countPoint() -> Vector2?       -- absolute GUI position of the count (the reveal lands there)
--   tray:openReview() / tray:closeReview()
--   tray:count() -> number, tray:claimed() -> { CarRef }
--   tray:layout(), tray:setVisible(on), tray:destroy(), tray:getDebugState()
-- Registered on RunBus as "tray" (CaptureRibbon finds it there).
--
-- Round 2 (R2-T1): each tile is a small STATIC thumbnail of the car (RunKit.thumb: one ViewportFrame per visible tile,
-- never more than the tray’s four slots, no spin and no render loop; the icon stays when there is no model), the
-- car name (truncated at a readable 16 px, in full in the review rows and the card detail), a thin rarity edge and a NEW
-- chip when the car was not owned before this claim (car.owned == false, supplied). Three or four tiles, then "+N" for
-- the older claims. Tapping a car tile opens its card detail (options.onDetail); "+N" opens the review of every claim
-- (long names wrap there instead of being cut). Its place is independent of the Stamina meter (RunLayout.trayGeometry).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Arcade = require(script.Parent.Parent.Arcade)
local Motion = require(script.Parent.Parent.Motion)
local PreviewTokens = require(script.Parent.Parent.PreviewTokens)
local RunBus = require(script.Parent.RunBus)
local RunKit = require(script.Parent.RunKit)
local RunLayout = require(script.Parent.RunLayout)
local Store = require(script.Parent.Parent.Store)
local Tokens = require(ReplicatedStorage.Shared.UI.Tokens)
local Trove = require(ReplicatedStorage.Packages.Trove)

local A = PreviewTokens.Arcade
local T = RunLayout.Tray
local make = Arcade.make

local EXPECT_TIMEOUT = 4
local SETTLE = 0.15 -- seconds a newly confirmed id waits for a ribbon's expect()
local PENDING_WORD = "SECURING…"
local MAX_REVIEW = 60 -- bounded review rows
local THUMB_LIMIT = 4 -- ViewportFrame thumbnails alive at once

local ClaimTray = {}
ClaimTray.__index = ClaimTray

type Entry = { kind: "Car" | "Pending" | "More", car: Store.CarRef?, id: string?, more: number? }

export type Options = { onDetail: ((Store.CarRef) -> ())? }

type Slot = {
	frame: Frame,
	ground: Frame,
	edge: UIStroke,
	thumb: ViewportFrame?,
	new: Frame,
	entry: Entry?,
	icon: Frame,
	name: TextLabel,
	more: TextLabel,
	dashed: UIStroke,
	solid: UIStroke,
	hit: TextButton,
	entryKey: string?,
}

-- a dashed stroke: a UIGradient on the UIStroke with alternating transparency bands
local DASHES = (function(): NumberSequence
	local kps = {}
	local n = 9
	for i = 0, n do
		local t = i / n
		local on = i % 2 == 0
		table.insert(kps, NumberSequenceKeypoint.new(t, if on then 0 else 1))
		if i < n then
			table.insert(kps, NumberSequenceKeypoint.new(math.min(t + 1 / n - 0.001, 1), if on then 0 else 1))
		end
	end
	return NumberSequence.new(kps)
end)()

function ClaimTray.new(ctx: RunLayout.Ctx, options: Options?)
	local self = setmetatable({}, ClaimTray)
	self._ctx = ctx
	self._onDetail = if options then options.onDetail else nil
	self._trove = Trove.new()
	self._visible = true
	self._arrived = {} :: { string } -- arrival order (ids)
	self._arrivedSet = {} :: { [string]: boolean }
	self._cars = {} :: { [string]: Store.CarRef }
	self._expected = {} :: { [string]: number } -- id -> os.clock() when expected
	self._waiting = {} :: { [string]: boolean } -- confirmed, waiting for the ribbon's arrive
	self._settling = {} :: { [string]: boolean }
	self._dead = false
	self._reviewCount = -1
	self._stamps = 0
	self._reviewOpen = false
	self._geometry = nil :: RunLayout.TrayGeometry?
	self._slots = {} :: { Slot }
	self._token = 0

	local root = self._trove:Add(RunLayout.canvas(ctx, "ClaimTray"))
	self.root = root
	local holder = make("Frame", {
		Name = "Tray",
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 2,
		Parent = root,
	})
	self._holder = holder

	-- header: italic count + word, no backing card
	local header = make("Frame", {
		Name = "Header",
		BackgroundTransparency = 1,
		ZIndex = 3,
		Parent = holder,
	})
	make("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		VerticalAlignment = Enum.VerticalAlignment.Bottom,
		Padding = UDim.new(0, 5),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = header,
	})
	local number = Arcade.text(header, {
		text = "0",
		role = "ValueRun",
		name = "Count",
		italic = true,
		face = "Cars",
		autoWidth = true,
		z = 4,
	})
	number.LayoutOrder = 1
	make("UIScale", { Name = "Pop", Parent = number })
	local word = Arcade.text(header, {
		text = "CLAIMED",
		role = "Label",
		name = "Word",
		autoWidth = true,
		z = 4,
	})
	word.LayoutOrder = 2
	self._header = header
	self._number = number
	self._word = word
	-- the stamp (Icons2 "Stamp") that lands on the count once per claim
	local stamp = make("Frame", {
		Name = "Stamp",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(34, 34),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 9,
		Parent = holder,
	})
	Arcade.icon(stamp, "Stamp")
	make("UIScale", { Name = "Pop", Parent = stamp })
	self._stamp = stamp

	local grid = make("Frame", {
		Name = "Slots",
		BackgroundTransparency = 1,
		ZIndex = 3,
		Parent = holder,
	})
	self._grid = grid
	local caption = Arcade.text(holder, {
		text = PENDING_WORD,
		role = "Small",
		name = "Pending",
		face = "Keys",
		autoWidth = true,
		z = 4,
	})
	caption.Visible = false
	self._caption = caption

	-- review panel (opened from "+N"); a scrollable list, bounded
	local review = make("Frame", {
		Name = "Review",
		BackgroundColor3 = A.Ink,
		BackgroundTransparency = 0.08,
		Visible = false,
		ZIndex = 20,
		Parent = root,
	})
	Arcade.corner(review, A.Button.Radius)
	-- Round 2: the same bold blue surface as the other overlays (was a dark panel with a white outline)
	Arcade.surface(review, "Garage")
	local title = Arcade.text(review, {
		text = "CLAIMED THIS RUN",
		role = "Label",
		name = "Title",
		xAlign = Enum.TextXAlignment.Left,
		z = 21,
	})
	title.Position = UDim2.fromOffset(10, 6)
	title.Size = UDim2.new(1, -70, 0, 24)
	local close = make("TextButton", {
		Name = "Close",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.fromOffset(Tokens.Touch.Minimum, Tokens.Touch.Minimum),
		BackgroundTransparency = 1,
		Text = "",
		ZIndex = 22,
		Parent = review,
	})
	local x = make("Frame", {
		Name = "X",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(26, 26),
		BackgroundTransparency = 1,
		ZIndex = 23,
		Parent = close,
	})
	Arcade.icon(x, "Close")
	self._trove:Connect(close.Activated, function()
		self:closeReview()
	end)
	local list = make("ScrollingFrame", {
		Name = "List",
		Position = UDim2.fromOffset(6, 48),
		Size = UDim2.new(1, -12, 1, -54),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		ZIndex = 21,
		Parent = review,
	})
	make("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder, Parent = list })
	self._review = review
	self._list = list

	self._trove:Add(ctx.store:subscribe("run", function()
		self:_sync()
	end))
	self._trove:Connect(ctx.store.Event, function(event: Store.Event)
		if event.kind == "KeysConfirmed" and event.car then
			local id = event.captureId or event.id
			self:_confirmed(id, event.car :: Store.CarRef)
		end
	end)
	self._trove:Connect(ctx.store.ModeChanged, function(mode: string, from: string?)
		if mode == "Run" and from ~= "Run" then
			self:_resetRun()
		end
		self:_render()
	end)
	self._trove:Add(function()
		self._dead = true
		self._token += 1
		Motion.cancelAll(stamp)
		Motion.cancelAll(number)
		RunBus.unregister(ctx, "tray", self)
	end)
	RunBus.register(ctx, "tray", self)
	self:layout()
	self:_sync()
	return self
end

export type ClaimTray = typeof(ClaimTray.new((nil :: any) :: RunLayout.Ctx))

function ClaimTray._resetRun(self: ClaimTray)
	table.clear(self._arrived)
	table.clear(self._arrivedSet)
	table.clear(self._cars)
	table.clear(self._expected)
	table.clear(self._waiting)
	table.clear(self._settling)
	self._number.Text = "0"
	self:closeReview()
end

-- A confirmed claim id was seen (state or event). Counts once: after a short settle (so a ribbon
-- presenting it can call expect first), or on the ribbon's arrival.
function ClaimTray._confirmed(self: ClaimTray, id: string, car: Store.CarRef)
	if self._arrivedSet[id] or self._waiting[id] or self._settling[id] then
		return
	end
	self._cars[id] = self._cars[id] or car
	self._settling[id] = true
	task.delay(SETTLE, function()
		self._settling[id] = nil
		if self._dead or self._arrivedSet[id] then
			return
		end
		local expectedAt = self._expected[id]
		local age = if expectedAt then os.clock() - expectedAt else math.huge
		if age < EXPECT_TIMEOUT then
			self._waiting[id] = true
			task.delay(EXPECT_TIMEOUT - age, function()
				if not self._dead and self._waiting[id] then
					self:arrive(id) -- the ribbon never came back: count it anyway
				end
			end)
			self:_render()
		else
			self:arrive(id)
		end
	end)
end

function ClaimTray.expect(self: ClaimTray, id: string)
	if self._arrivedSet[id] then
		return
	end
	self._expected[id] = os.clock()
end

function ClaimTray.arrive(self: ClaimTray, id: string, car: Store.CarRef?)
	if self._arrivedSet[id] then
		return
	end
	if car then
		self._cars[id] = self._cars[id] or car
	end
	if not self._cars[id] then
		return -- nothing to show for an id we never saw confirmed
	end
	self._waiting[id] = nil
	self._expected[id] = nil
	self._arrivedSet[id] = true
	table.insert(self._arrived, id)
	self._stamps += 1
	self:_render()
	self:_stampNow()
end

function ClaimTray._sync(self: ClaimTray)
	local run = self._ctx.store:get().run
	if run and run.claims then
		for _, claim in run.claims do
			if claim and claim.id and claim.car then
				self:_confirmed(claim.id, claim.car)
			end
		end
	end
	self:_render()
end

function ClaimTray.count(self: ClaimTray): number
	return #self._arrived
end

function ClaimTray.claimed(self: ClaimTray): { Store.CarRef }
	local out = {}
	for _, id in self._arrived do
		table.insert(out, self._cars[id])
	end
	return out
end

-- The pending claim to show (nil once its id is confirmed or waiting for the ribbon).
function ClaimTray._pending(self: ClaimTray): Store.Claim?
	local run = self._ctx.store:get().run
	local p = run and run.pendingClaim
	if p and p.id and not self._arrivedSet[p.id] and not self._waiting[p.id] and not self._settling[p.id] then
		return p
	end
	return nil
end

function ClaimTray._entries(self: ClaimTray, extraId: string?): { Entry }
	local g = self._geometry
	if not g then
		return {}
	end
	local capacity = g.columns * g.rows
	local ids = table.clone(self._arrived)
	if extraId and not self._arrivedSet[extraId] then
		table.insert(ids, extraId)
	end
	local pending = self:_pending()
	local free = capacity - (if pending then 1 else 0)
	local out: { Entry } = {}
	local hidden = 0
	if #ids > free then
		-- the first visible slot becomes "+N" (the older claims), the newest stay visible
		hidden = #ids - (free - 1)
		table.insert(out, { kind = "More", more = hidden })
	end
	for i = hidden + 1, #ids do
		local id = ids[i]
		table.insert(out, { kind = "Car", car = self._cars[id], id = id })
	end
	if pending then
		table.insert(out, { kind = "Pending", car = pending.car, id = pending.id })
	end
	return out
end

function ClaimTray._makeSlot(self: ClaimTray, i: number, size: number): Slot
	local frame = make("Frame", {
		Name = "Slot" .. i,
		Size = UDim2.fromOffset(size, size),
		BackgroundTransparency = 1,
		ZIndex = 4,
		Parent = self._grid,
	})
	local ground = make("Frame", {
		Name = "Ground",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		ZIndex = 4,
		Parent = frame,
	})
	Arcade.corner(ground, 6)
	make("UIGradient", { Name = "Rarity", Rotation = 90, Parent = ground })
	local solid = Arcade.outline(ground, "Major")
	-- the thin rarity edge sits just inside the dark boundary
	local edgeFrame = make("Frame", {
		Name = "RarityEdge",
		Position = UDim2.fromOffset(2, 2),
		Size = UDim2.new(1, -4, 1, -4),
		BackgroundTransparency = 1,
		ZIndex = 5,
		Parent = ground,
	})
	Arcade.corner(edgeFrame, 4)
	local edge = make("UIStroke", {
		Thickness = 2.5,
		Color = Color3.new(1, 1, 1),
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = edgeFrame,
	})
	local dashed = make("UIStroke", {
		Name = "Dashed",
		Thickness = 2.5,
		Color = Color3.new(1, 1, 1),
		Enabled = false,
		Parent = frame,
	})
	make("UIGradient", { Transparency = DASHES, Rotation = 45, Parent = dashed })
	make("UICorner", { CornerRadius = UDim.new(0, 6), Parent = frame })
	local icon = make("Frame", {
		Name = "Icon",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 3),
		Size = UDim2.fromOffset(size * 0.62, size * 0.62),
		BackgroundTransparency = 1,
		ZIndex = 6,
		Parent = ground,
	})
	Arcade.icon(icon, "Car")
	local name = Arcade.text(ground, { text = "", role = "Small", name = "Name", z = 7 })
	name.AnchorPoint = Vector2.new(0.5, 1)
	name.Position = UDim2.new(0.5, 0, 1, 2)
	name.Size = UDim2.new(1, 6, 0, 20)
	name.TextTruncate = Enum.TextTruncate.AtEnd
	-- NEW: the car was not owned before this claim (explicit supplied flag only)
	local newChip = make("Frame", {
		Name = "New",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 1, 0, -1),
		Size = UDim2.fromOffset(40, 20),
		BackgroundColor3 = Color3.new(1, 1, 1),
		Visible = false,
		ZIndex = 9,
		Parent = ground,
	})
	Arcade.surface(newChip, "Gold", { outline = "Minor", gloss = false })
	local newText = Arcade.text(newChip, { text = "NEW", role = "Small", name = "Text", z = 10 })
	newText.Size = UDim2.fromScale(1, 1)
	newText.TextScaled = true
	make("UITextSizeConstraint", { MinTextSize = 16, MaxTextSize = 16, Parent = newText })
	local more = Arcade.text(ground, {
		text = "",
		role = "ValueRun",
		name = "More",
		italic = true,
		face = "White",
		size = if size < 50 then 20 else 24,
		z = 8,
	})
	more.AnchorPoint = Vector2.new(0.5, 0.5)
	more.Position = UDim2.fromScale(0.5, 0.5)
	-- "+N" opens the review (hit box at least the approved 48 design px)
	local hitSize = math.max(size, Tokens.Touch.Minimum)
	local hit = make("TextButton", {
		Name = "Hit",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(hitSize, hitSize),
		BackgroundTransparency = 1,
		Text = "",
		Visible = false,
		ZIndex = 10,
		Parent = frame,
	})
	local slot: Slot = {
		frame = frame,
		ground = ground,
		edge = edge,
		thumb = nil,
		new = newChip,
		entry = nil,
		icon = icon,
		name = name,
		more = more,
		dashed = dashed,
		solid = solid,
		hit = hit,
		entryKey = nil,
	}
	self._trove:Connect(hit.Activated, function()
		local e = slot.entry
		if e and e.kind == "Car" and e.car and self._onDetail then
			(self._onDetail :: any)(e.car) -- a car tile: its card detail
		elseif self._reviewOpen then
			self:closeReview()
		else
			self:openReview()
		end
	end)
	return slot
end

-- Thumbnails alive right now (the tray never keeps more than THUMB_LIMIT ViewportFrames).
function ClaimTray._thumbCount(self: ClaimTray): number
	local n = 0
	for _, s in self._slots do
		if s.thumb then
			n += 1
		end
	end
	return n
end

function ClaimTray._render(self: ClaimTray)
	local g = self._geometry
	if not g then
		return
	end
	local state = self._ctx.store:get()
	local entries = self:_entries(nil)
	local count = #self._arrived
	local show = self._visible and state.mode == "Run" and (count > 0 or #entries > 0)
	self._holder.Visible = show
	self._number.Text = tostring(count)
	local pending = self:_pending()
	-- one SECURING… on screen: while the Keys ring shows its own pending word, the slot stays ghosted
	-- without a caption
	local keys = state.run and state.run.keys
	local keysSays = keys ~= nil and keys.status == "Pending"
	self._caption.Visible = show and pending ~= nil and not keysSays
	for i, slot in self._slots do
		local e = entries[i]
		slot.frame.Visible = e ~= nil
		if not e then
			slot.entryKey = nil
			continue
		end
		local key = e.kind .. ":" .. tostring(e.id or e.more)
		if key == slot.entryKey then
			continue
		end
		slot.entryKey = key
		slot.entry = e
		if slot.thumb then
			slot.thumb:Destroy()
			slot.thumb = nil
		end
		slot.new.Visible = false
		slot.edge.Enabled = false
		local grad = slot.ground:FindFirstChild("Rarity") :: UIGradient
		local compact = g.thumb < 50
		if e.kind == "More" then
			slot.ground.BackgroundTransparency = 0
			grad.Color = ColorSequence.new(A.Ink, Color3.fromRGB(44, 56, 92))
			slot.icon.Visible = false
			slot.name.Visible = false
			slot.more.Visible = true
			slot.more.Text = "+" .. tostring(e.more)
			slot.solid.Enabled = true
			slot.dashed.Enabled = false
			slot.hit.Visible = true
		else
			local r = RunKit.rarity(e.car)
			local ghost = e.kind == "Pending"
			-- a dark tile: the thumbnail pops, and the rarity is the thin edge inside the boundary
			grad.Color = ColorSequence.new(Color3.fromRGB(46, 58, 104), Color3.fromRGB(24, 32, 72))
			slot.edge.Enabled = not ghost
			slot.edge.Color = r.light
			if not ghost and self:_thumbCount() < THUMB_LIMIT then
				local vp = RunKit.thumb(slot.ground, e.car)
				if vp then
					vp.AnchorPoint = Vector2.new(0.5, 0)
					vp.Position = UDim2.new(0.5, 0, 0, 3)
					vp.Size = UDim2.fromOffset(g.thumb * 0.84, g.thumb * 0.62)
					vp.ZIndex = 6
					slot.thumb = vp
				end
			end
			slot.icon.Visible = slot.thumb == nil
			slot.more.Visible = false
			slot.hit.Visible = e.kind == "Car" and self._onDetail ~= nil
			slot.new.Visible = e.kind == "Car" and e.car ~= nil and e.car.owned == false
			-- compact tiles hide the name, so the NEW chip takes the bottom edge; larger tiles keep it top-right
			slot.new.AnchorPoint = if compact then Vector2.new(0.5, 1) else Vector2.new(1, 0)
			slot.new.Position = if compact then UDim2.new(0.5, 0, 1, 2) else UDim2.new(1, 2, 0, -2)
			slot.name.Text = if e.car then e.car.name else ""
			slot.name.Visible = not compact
			slot.ground.BackgroundTransparency = if ghost then 0.65 else 0
			slot.solid.Enabled = not ghost
			slot.dashed.Enabled = ghost
			for _, d in slot.icon:GetDescendants() do
				if d:IsA("GuiObject") then
					d:SetAttribute("BaseT", d:GetAttribute("BaseT") or d.BackgroundTransparency)
					d.BackgroundTransparency = if ghost then 0.6 else d:GetAttribute("BaseT") :: number
				end
			end
		end
	end
	self:_renderReview()
end

function ClaimTray._stampNow(self: ClaimTray)
	local stamp = self._stamp
	local number = self._number
	self._token += 1
	local token = self._token
	stamp.Visible = true
	local at = RunLayout.absToCanvas(
		self.root,
		number.AbsolutePosition + Vector2.new(number.AbsoluteSize.X, number.AbsoluteSize.Y * 0.4),
		self._ctx
	)
	local origin = Vector2.new(self._holder.Position.X.Offset, self._holder.Position.Y.Offset)
	stamp.Position = UDim2.fromOffset(at.X - origin.X + 10, at.Y - origin.Y)
	local pop = stamp:FindFirstChild("Pop") :: UIScale
	if Motion.reduced() then
		pop.Scale = 1
	else
		pop.Scale = 1.4
		Motion.tween(pop, "stamp", Motion.info(0.18, Enum.EasingStyle.Back), { Scale = 1 })
		Motion.pop(number, 1.15)
	end
	task.delay(0.7, function()
		if token == self._token then
			stamp.Visible = false
		end
	end)
end

function ClaimTray.arrivalPoint(self: ClaimTray, id: string): Vector2?
	local entries = self:_entries(id)
	for i, e in entries do
		if e.id == id and e.kind == "Car" then
			local slot = self._slots[i]
			if slot then
				return slot.frame.AbsolutePosition + slot.frame.AbsoluteSize / 2
			end
		end
	end
	-- hidden behind "+N": aim at the overflow chip
	local first = self._slots[1]
	return if first then first.frame.AbsolutePosition + first.frame.AbsoluteSize / 2 else nil
end

function ClaimTray._renderReview(self: ClaimTray)
	if not self._reviewOpen or self._reviewCount == #self._arrived then
		return
	end
	self._reviewCount = #self._arrived
	for _, c in self._list:GetChildren() do
		if c:IsA("GuiObject") then
			c:Destroy()
		end
	end
	for i, id in self._arrived do
		if i > MAX_REVIEW then
			break
		end
		local car = self._cars[id]
		local r = RunKit.rarity(car)
		local row = make("Frame", {
			Name = "Row" .. i,
			Size = UDim2.new(1, -8, 0, 52),
			BackgroundTransparency = 1,
			LayoutOrder = i,
			ZIndex = 22,
			Parent = self._list,
		})
		local chip = make("Frame", {
			Name = "Rarity",
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.fromScale(0, 0.5),
			Size = UDim2.fromOffset(30, 30),
			BackgroundColor3 = Color3.new(1, 1, 1),
			ZIndex = 22,
			Parent = row,
		})
		Arcade.corner(chip, 5)
		Arcade.outline(chip, "Minor")
		make("UIGradient", { Color = ColorSequence.new(r.light, r.deep), Rotation = 90, Parent = chip })
		local label = Arcade.text(row, {
			text = r.label .. "  " .. (if car then car.name else "") .. (if car and car.owned == false
				then "  NEW"
				else ""),
			role = "Small",
			name = "Name",
			xAlign = Enum.TextXAlignment.Left,
			z = 23,
		})
		-- the review is where long names are read in full: they wrap instead of being cut
		label.Position = UDim2.new(0, 38, 0.5, -23)
		label.Size = UDim2.new(1, -40, 0, 46)
		label.TextWrapped = true
	end
end

-- Where the count is on screen (absolute GUI position): the SECURED card and the ribbon’s car fly to it. nil
-- while the tray has no size yet.
function ClaimTray.countPoint(self: ClaimTray): Vector2?
	local number = self._number
	if number.AbsoluteSize.X <= 0 then
		return nil
	end
	return number.AbsolutePosition + number.AbsoluteSize / 2
end

function ClaimTray.openReview(self: ClaimTray)
	if #self._arrived == 0 then
		return
	end
	self._reviewOpen = true
	self._reviewCount = -1
	self._review.Visible = true
	self:_renderReview()
end

function ClaimTray.closeReview(self: ClaimTray)
	self._reviewOpen = false
	self._review.Visible = false
end

function ClaimTray.layout(self: ClaimTray)
	local ctx = self._ctx
	RunLayout.fit(ctx, self.root)
	local g = RunLayout.trayGeometry(ctx)
	local rebuild = not self._geometry or self._geometry.thumb ~= g.thumb or #self._slots ~= g.columns * g.rows
	self._geometry = g
	local r = g.rect
	-- leave room for the SECURING… caption under the slots
	RunLayout.place(self._holder, RunLayout.rect(r.pos.X, r.pos.Y, r.size.X, r.size.Y + 22))
	local slotsX, slotsY = 0, g.header
	self._header.Position = UDim2.fromOffset(0, 0)
	self._header.Size = UDim2.fromOffset(r.size.X, g.header)
	self._word.TextSize = A.Text.Label
	self._grid.Position = UDim2.fromOffset(slotsX, slotsY)
	self._grid.Size = UDim2.fromOffset(g.columns * (g.thumb + T.Gap), g.rows * (g.thumb + T.Gap))
	if rebuild then
		for _, s in self._slots do
			s.frame:Destroy()
		end
		table.clear(self._slots)
		for i = 1, g.columns * g.rows do
			table.insert(self._slots, self:_makeSlot(i, g.thumb))
		end
	end
	for i, s in self._slots do
		local col = (i - 1) % g.columns
		local row = (i - 1) // g.columns
		s.frame.Position = UDim2.fromOffset(col * (g.thumb + T.Gap), row * (g.thumb + T.Gap))
	end
	self._caption.Position = UDim2.fromOffset(slotsX, slotsY + g.rows * (g.thumb + T.Gap))
	-- review panel beside the tray, outside the protected region, bounded height
	local d = RunLayout.design(ctx)
	local prot = RunLayout.protected(ctx)
	local w = math.clamp(prot.pos.X - r.pos.X - r.size.X - 16, 200, 300)
	local h = math.min(240, d.Y - r.pos.Y - 12)
	local x = r.pos.X + r.size.X + 8
	local y = r.pos.Y
	self._review.Position = UDim2.fromOffset(x, y)
	self._review.Size = UDim2.fromOffset(math.min(w, d.X - x - 12), h)
	self:_render()
end

function ClaimTray.setVisible(self: ClaimTray, on: boolean)
	self._visible = on
	self.root.Visible = on
	if not on then
		self:closeReview()
	end
	self:_render()
end

function ClaimTray.getDebugState(self: ClaimTray): { [string]: any }
	local entries = self:_entries(nil)
	local kinds = {}
	for _, e in entries do
		table.insert(kinds, e.kind .. (if e.more then ("+" .. e.more) else ""))
	end
	local waiting = 0
	for _ in self._waiting do
		waiting += 1
	end
	local r = self._geometry and self._geometry.rect
	return {
		visible = self._visible,
		shown = self._holder.Visible,
		count = #self._arrived,
		countText = self._number.Text,
		stamps = self._stamps,
		waitingForRibbon = waiting,
		pendingShown = self._caption.Visible,
		slots = kinds,
		reviewOpen = self._reviewOpen,
		reviewRows = #self._list:GetChildren() - 1,
		thumbs = self:_thumbCount(),
		thumbLimit = THUMB_LIMIT,
		box = r and RunLayout.describe(r),
		overlapsProtected = r ~= nil and RunLayout.overlaps(r, RunLayout.protected(self._ctx)),
		instances = #self.root:GetDescendants(),
	}
end

function ClaimTray.destroy(self: ClaimTray)
	self._trove:Destroy()
end

return ClaimTray
