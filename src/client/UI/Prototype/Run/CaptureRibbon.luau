--!strict
-- Capture ribbon (Lane 3 preview, HUD rebuild worker HR; K-04 confirmed + tray arrival, K-06,
-- K-07, E-05). Replaces the overnight CaptureCelebration (large card) and AlreadyOwned note, both
-- retired. It plays ONLY on the explicit confirmed events, once per capture id:
--   { kind = "KeysConfirmed", captureId, car }  ->  "YOU GOT THE KEYS!" + rarity word and car name
--                                                    + "Keep going!"
--   { kind = "AlreadyOwned", captureId, car, amount? }  ->  silver "JOYRIDE BONUS" + car name +
--                                                    "+$N" (the amount is supplied; the playground's
--                                                    +$50 is SYNTHETIC and captioned as such)
-- A compact SIDE ribbon (RunLayout.sideRect: the left column outside the protected road region;
-- the band above it in phone portrait), never a full card while driving. It requests the "Side"
-- slot at "Capture" (ctx.priority) and asks the district banner to yield, so capture fanfare,
-- the banner, a warning and Results never stack. Timing: slide in 0.22 s, a short burst of at
-- most 12 key/star/confetti pieces (screen space), hold PreviewTokens.Arcade.Keys.
-- RibbonHoldSeconds (1.6 s), then the car icon flies and settles into the ClaimTray (tray:arrive
-- through RunBus "tray"), and the ribbon slides out (0.25 s). Sounds: "KeysCapture" once per
-- confirmed id (never before the event).
--
-- Suppressed (not shown, but the claim is kept): while a Safety warning holds (run.warning or
-- RunBus flags), after RunEnded, or outside Run mode. A confirmed claim that is suppressed or
-- arrives at / after run end is recorded for Results (pendingCards / takePendingCards); the tray
-- still counts it once. A larger card reveal is left to Results (phones always use the ribbon).
-- Reduced motion: a 0.15 s fade in place, no burst, no flight (the tray stamps at once), calm.
--
--   local ribbon = CaptureRibbon.new(ctx)
--   ribbon:pendingCards() -> { CarRef }, ribbon:takePendingCards() -> { CarRef }
--   ribbon:dismiss(), ribbon:layout(), ribbon:setVisible(on), ribbon:destroy(),
--   ribbon:getDebugState()

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Arcade = require(script.Parent.Parent.Arcade)
local Format = require(ReplicatedStorage.Shared.UI.Format)
local Motion = require(script.Parent.Parent.Motion)
local PreviewTokens = require(script.Parent.Parent.PreviewTokens)
local RunBus = require(script.Parent.RunBus)
local RunKit = require(script.Parent.RunKit)
local RunLayout = require(script.Parent.RunLayout)
local Sounds = require(script.Parent.Parent.Sounds)
local Store = require(script.Parent.Parent.Store)
local Trove = require(ReplicatedStorage.Packages.Trove)

local A = PreviewTokens.Arcade
local make = Arcade.make

local IN = 0.22
local OUT = 0.25
local FLY = 0.45
local BURST = 12 -- hard cap on burst pieces
local QUEUE = 3
local PRESENTED_MEMORY = 64

local CaptureRibbon = {}
CaptureRibbon.__index = CaptureRibbon

type Item = { id: string, kind: "Confirmed" | "Joyride", car: Store.CarRef, amount: number?, at: number }

function CaptureRibbon.new(ctx: RunLayout.Ctx)
	local self = setmetatable({}, CaptureRibbon)
	self._ctx = ctx
	self._trove = Trove.new()
	self._visible = true
	self._presented = {} :: { [string]: boolean }
	self._presentedOrder = {} :: { string }
	self._queue = {} :: { Item }
	self._current = nil :: Item?
	self._handle = nil :: any
	self._pending = {} :: { Store.CarRef }
	self._token = 0
	self._shown = 0
	self._suppressed = 0
	self._bursts = 0
	self._pieces = 0
	self._flights = 0

	local root = self._trove:Add(RunLayout.canvas(ctx, "CaptureRibbon"))
	self.root = root
	local ribbon = make("CanvasGroup", {
		Name = "Ribbon",
		BackgroundTransparency = 1,
		GroupTransparency = 1,
		Visible = false,
		ZIndex = 5,
		Parent = root,
	})
	RunKit.nonInteractive(ribbon)
	self._ribbon = ribbon
	local band = make("Frame", {
		Name = "Band",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = A.Ink,
		BackgroundTransparency = 0.08,
		ZIndex = 5,
		Parent = ribbon,
	})
	Arcade.corner(band, A.Button.Radius)
	local stripe = make("Frame", {
		Name = "Stripe",
		Size = UDim2.new(0, 8, 1, 0),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		ZIndex = 6,
		Parent = band,
	})
	Arcade.corner(stripe, A.Button.Radius)
	self._stripeGrad = make("UIGradient", { Color = A.Fill.Gold, Rotation = 90, Parent = stripe })
	local underline = make("Frame", {
		Name = "RarityLine",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 10, 1, -3),
		Size = UDim2.new(1, -20, 0, 3),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		ZIndex = 6,
		Parent = band,
	})
	self._underline = underline
	local icon = make("Frame", {
		Name = "Icon",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 14, 0.5, 0),
		Size = UDim2.fromOffset(48, 48),
		BackgroundTransparency = 1,
		ZIndex = 8,
		Parent = band,
	})
	self._icon = icon
	local title = Arcade.text(band, {
		text = "",
		role = "Display",
		name = "Title",
		size = 26,
		face = "Keys",
		xAlign = Enum.TextXAlignment.Left,
		z = 9,
	})
	title.TextScaled = true
	make("UITextSizeConstraint", { MinTextSize = 16, MaxTextSize = 26, Parent = title })
	local identity = Arcade.text(band, {
		text = "",
		role = "Label",
		name = "Identity",
		xAlign = Enum.TextXAlignment.Left,
		z = 9,
	})
	identity.RichText = true
	identity.TextTruncate = Enum.TextTruncate.AtEnd
	local sub = Arcade.text(band, {
		text = "",
		role = "Small",
		name = "Sub",
		xAlign = Enum.TextXAlignment.Left,
		z = 9,
	})
	local amount = Arcade.text(band, {
		text = "",
		role = "Earning",
		name = "Amount",
		italic = true,
		face = "Cash",
		autoWidth = true,
		z = 9,
	})
	amount.AnchorPoint = Vector2.new(1, 0.5)
	local caption = Arcade.text(band, {
		text = "synthetic amount",
		role = "Small",
		name = "SyntheticCaption",
		colour = Color3.fromRGB(255, 230, 120),
		autoWidth = true,
		z = 10,
	})
	caption:SetAttribute("PreviewCaption", true)
	caption.AnchorPoint = Vector2.new(1, 0)
	caption.Visible = false
	self._title, self._identity, self._sub, self._amount, self._caption = title, identity, sub, amount, caption

	-- burst pieces (a fixed pool, never more than BURST)
	local burst = make("Frame", {
		Name = "Burst",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = 12,
		Parent = root,
	})
	RunKit.nonInteractive(burst)
	self._burstPool = {} :: { Frame }
	for i = 1, BURST do
		local piece = make("Frame", {
			Name = "Piece" .. i,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Size = UDim2.fromOffset(if i % 3 == 0 then 12 else 8, if i % 3 == 0 then 12 else 5),
			BackgroundColor3 = Color3.new(1, 1, 1),
			Visible = false,
			ZIndex = 12,
			Parent = burst,
		})
		Arcade.outline(piece, 1.25)
		table.insert(self._burstPool, piece)
	end
	-- the flying car icon (one, reused)
	local flyer = make("Frame", {
		Name = "Flyer",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(40, 40),
		BackgroundColor3 = Color3.new(1, 1, 1),
		Visible = false,
		ZIndex = 14,
		Parent = root,
	})
	Arcade.corner(flyer, 6)
	Arcade.outline(flyer, "Major")
	self._flyerGrad = make("UIGradient", { Rotation = 90, Parent = flyer })
	local flyerIcon = make("Frame", {
		Name = "Icon",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.8, 0.8),
		BackgroundTransparency = 1,
		ZIndex = 15,
		Parent = flyer,
	})
	Arcade.icon(flyerIcon, "Car")
	self._flyer = flyer

	self._trove:Connect(ctx.store.Event, function(event: Store.Event)
		if (event.kind == "KeysConfirmed" or event.kind == "AlreadyOwned") and event.car then
			local item: Item = {
				id = event.captureId or event.id,
				kind = if event.kind == "KeysConfirmed" then "Confirmed" else "Joyride",
				car = event.car :: Store.CarRef,
				amount = event.amount,
				at = os.clock(),
			}
			self:_receive(item)
		elseif event.kind == "RunEnded" then
			-- whatever is showing gives way; the showing and queued claims go to Results
			local showing = self._current
			if showing then
				self:_record(showing)
			end
			self:_flushToResults()
			self:dismiss()
		end
	end)
	self._trove:Connect(ctx.store.ModeChanged, function(mode: string, from: string?)
		if mode ~= "Run" then
			self:_flushToResults()
			self:dismiss()
		end
		if mode == "Run" and from ~= "Run" then
			table.clear(self._pending) -- a new run (Results already took its cards)
		end
	end)
	self._trove:Add(function()
		self._token += 1
		Motion.cancelAll(ribbon)
		Motion.cancelAll(flyer)
		for _, p in self._burstPool do
			Motion.cancelAll(p)
		end
		if self._handle then
			RunBus.priority(ctx):release(self._handle)
			self._handle = nil
		end
		RunBus.unregister(ctx, "ribbon", self)
	end)
	RunBus.register(ctx, "ribbon", self)
	self:layout()
	return self
end

export type CaptureRibbon = typeof(CaptureRibbon.new((nil :: any) :: RunLayout.Ctx))

function CaptureRibbon._markPresented(self: CaptureRibbon, id: string): boolean
	if self._presented[id] then
		return false
	end
	self._presented[id] = true
	table.insert(self._presentedOrder, id)
	if #self._presentedOrder > PRESENTED_MEMORY then
		self._presented[table.remove(self._presentedOrder, 1) :: string] = nil
	end
	return true
end

function CaptureRibbon._isSuppressed(self: CaptureRibbon): boolean
	local state = self._ctx.store:get()
	local flags = RunBus.flags(self._ctx)
	return not self._visible
		or state.mode ~= "Run"
		or flags.ended
		or flags.warning
		or (state.run ~= nil and state.run.warning ~= nil)
end

function CaptureRibbon._record(self: CaptureRibbon, item: Item)
	if item.kind ~= "Confirmed" then
		return
	end
	for _, c in self._pending do
		if c == item.car then
			return
		end
	end
	table.insert(self._pending, item.car)
end

function CaptureRibbon._receive(self: CaptureRibbon, item: Item)
	if not self:_markPresented(item.id) then
		return -- duplicate, late repeat or a Joyride for an id already celebrated
	end
	if self:_isSuppressed() then
		self._suppressed += 1
		self:_record(item)
		return -- the tray counts it on its own (no expect), Results shows the card
	end
	local tray = RunBus.get(self._ctx, "tray")
	if tray and item.kind == "Confirmed" then
		tray:expect(item.id)
	end
	if self._current then
		if #self._queue >= QUEUE then
			local dropped = table.remove(self._queue, 1) :: Item
			self:_settle(dropped)
		end
		table.insert(self._queue, item)
		return
	end
	self:_request(item)
end

function CaptureRibbon._request(self: CaptureRibbon, item: Item)
	self._current = item
	local arb = RunBus.priority(self._ctx)
	local granted = false
	local handle = arb:request("Side", "Capture", "capture-" .. item.id, {
		grant = function()
			granted = true
			if self._current == item then
				self:_present(item)
			end
		end,
		revoke = function()
			if self._current == item then
				self:_abort(item)
			end
		end,
		wait = 2,
	})
	self._handle = handle
	local function giveUp()
		-- the side column is busy with something more important: keep the claim, skip the show
		self._suppressed += 1
		self:_settle(item)
		self._current = nil
		if self._handle == handle then
			self._handle = nil
		end
		self:_next()
	end
	if handle == nil and not granted then
		giveUp()
	elseif not granted then
		task.delay(2.1, function()
			if not granted and self._current == item then
				arb:release(handle)
				giveUp()
			end
		end)
	end
end

-- The claim lands in the tray without a flight (suppressed, dropped or aborted).
function CaptureRibbon._settle(self: CaptureRibbon, item: Item)
	if item.kind ~= "Confirmed" then
		return
	end
	local tray = RunBus.get(self._ctx, "tray")
	if tray then
		tray:arrive(item.id, item.car)
	end
	if RunBus.flags(self._ctx).ended then
		self:_record(item)
	end
end

function CaptureRibbon._flushToResults(self: CaptureRibbon)
	for _, item in self._queue do
		self:_settle(item)
		self:_record(item)
	end
	table.clear(self._queue)
end

function CaptureRibbon._present(self: CaptureRibbon, item: Item)
	self._token += 1
	local token = self._token
	self._shown += 1
	local banner = RunBus.get(self._ctx, "banner")
	if banner then
		banner:yield()
	end
	local joy = item.kind == "Joyride"
	local r = RunKit.rarity(item.car)
	self._stripeGrad.Color = if joy then RunKit.SilverFill else A.Fill.Gold
	self._underline.BackgroundColor3 = r.light
	self._icon:ClearAllChildren()
	if joy or not Arcade.icon(self._icon, "KeyLock") then
		self._icon:ClearAllChildren()
		Arcade.icon(self._icon, if joy then "Car" else "Key")
	end
	self._title.Text = if joy then "JOYRIDE BONUS" else "YOU GOT THE KEYS!"
	local grad = self._title:FindFirstChildOfClass("UIGradient")
	if grad then
		grad.Color = if joy then RunKit.SilverFill else A.Face.Keys
	end
	local hex = r.light:ToHex()
	self._identity.Text = string.format('<font color="#%s">%s</font>  %s', hex, r.label, item.car.name)
	self._sub.Text = if joy then "Already in your Garage" else "Keep going!"
	self._amount.Visible = joy and item.amount ~= nil
	-- a PreviewCaption: the playground shows it only in captioned review captures
	self._caption.Text = if joy and item.amount then "synthetic amount" else ""
	if joy and item.amount then
		self._amount.Text = "+" .. Format.cash(item.amount :: number)
	end
	if item.kind == "Confirmed" then
		Sounds.play("KeysCapture")
	else
		Sounds.play("CashGain")
	end
	self:layout()
	local ribbon = self._ribbon
	local rect = RunLayout.sideRect(self._ctx)
	local w = ribbon.Size.X.Offset
	local reduced = Motion.reduced()
	ribbon.Visible = true
	if reduced then
		ribbon.Position = UDim2.fromOffset(rect.pos.X, rect.pos.Y)
		ribbon.GroupTransparency = 1
		Motion.tween(ribbon, "fade", Motion.info(0.15), { GroupTransparency = 0 })
	else
		ribbon.Position = UDim2.fromOffset(rect.pos.X - w * 0.35, rect.pos.Y)
		ribbon.GroupTransparency = 1
		Motion.tween(ribbon, "fade", Motion.info(IN), { GroupTransparency = 0 })
		Motion.tween(ribbon, "slide", Motion.info(IN, Enum.EasingStyle.Back), {
			Position = UDim2.fromOffset(rect.pos.X, rect.pos.Y),
		})
		self:_burst(rect.pos + Vector2.new(38, rect.size.Y / 2), r.light, joy)
	end
	task.delay(IN + A.Keys.RibbonHoldSeconds, function()
		if token ~= self._token then
			return
		end
		self:_finish(item, token)
	end)
end

function CaptureRibbon._burst(self: CaptureRibbon, origin: Vector2, accent: Color3, silver: boolean)
	self._bursts += 1
	local colours = {
		if silver then RunKit.SilverFill.Keypoints[1].Value else A.Fill.Gold.Keypoints[2].Value,
		Color3.new(1, 1, 1),
		accent,
	}
	for i, piece in self._burstPool do
		local angle = (i / BURST) * math.pi * 2 + 0.3
		local dist = 46 + (i % 4) * 10
		piece.BackgroundColor3 = colours[(i % #colours) + 1]
		piece.Position = UDim2.fromOffset(origin.X, origin.Y)
		piece.Rotation = (i * 37) % 90
		piece.BackgroundTransparency = 0
		piece.Visible = true
		self._pieces = math.max(self._pieces, i)
		local goal = origin + Vector2.new(math.cos(angle), math.sin(angle)) * dist
		local t = Motion.tween(piece, "burst", Motion.info(0.6), {
			Position = UDim2.fromOffset(goal.X, goal.Y),
			Rotation = piece.Rotation + 120,
			BackgroundTransparency = 1,
		})
		t.Completed:Connect(function(state)
			if state == Enum.PlaybackState.Completed then
				piece.Visible = false
			end
		end)
	end
end

function CaptureRibbon._finish(self: CaptureRibbon, item: Item, token: number)
	local ribbon = self._ribbon
	local reduced = Motion.reduced()
	local tray = RunBus.get(self._ctx, "tray")
	if item.kind == "Confirmed" and tray and not reduced then
		-- the car icon flies from the ribbon and settles into the tray
		local target = tray:arrivalPoint(item.id)
		if target then
			self._flights += 1
			local from =
				RunLayout.absToCanvas(self.root, self._icon.AbsolutePosition + self._icon.AbsoluteSize / 2, self._ctx)
			local to = RunLayout.absToCanvas(self.root, target, self._ctx)
			local r = RunKit.rarity(item.car)
			self._flyerGrad.Color = ColorSequence.new(r.light, r.deep)
			local flyer = self._flyer
			flyer.Position = UDim2.fromOffset(from.X, from.Y)
			flyer.Visible = true
			local t = Motion.tween(flyer, "fly", Motion.info(FLY, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				Position = UDim2.fromOffset(to.X, to.Y),
			})
			t.Completed:Connect(function()
				flyer.Visible = false
				tray:arrive(item.id, item.car)
			end)
		else
			tray:arrive(item.id, item.car)
		end
	elseif item.kind == "Confirmed" and tray then
		tray:arrive(item.id, item.car)
	end
	local out = Motion.tween(ribbon, "fade", Motion.info(if reduced then 0.15 else OUT), { GroupTransparency = 1 })
	if not reduced then
		Motion.tween(ribbon, "slide", Motion.info(OUT), {
			Position = ribbon.Position - UDim2.fromOffset(24, 0),
		})
	end
	out.Completed:Connect(function(state)
		if state == Enum.PlaybackState.Completed and token == self._token then
			ribbon.Visible = false
		end
	end)
	self:_release()
	self._current = nil
	task.delay(if reduced then 0.2 else OUT, function()
		if token == self._token then
			self:_next()
		end
	end)
end

function CaptureRibbon._release(self: CaptureRibbon)
	if self._handle then
		RunBus.priority(self._ctx):release(self._handle)
		self._handle = nil
	end
end

-- A higher level took the side column: hide now; the claim still lands in the tray.
function CaptureRibbon._abort(self: CaptureRibbon, item: Item)
	self._token += 1
	self._handle = nil
	self._current = nil
	Motion.cancelAll(self._ribbon)
	self._ribbon.GroupTransparency = 1
	self._ribbon.Visible = false
	self:_settle(item)
	self:_next()
end

function CaptureRibbon._next(self: CaptureRibbon)
	if self._current then
		return
	end
	while #self._queue > 0 do
		local item = table.remove(self._queue, 1) :: Item
		if self:_isSuppressed() or os.clock() - item.at > 6 then
			self._suppressed += 1
			self:_settle(item)
			self:_record(item)
		else
			self:_request(item)
			return
		end
	end
end

function CaptureRibbon.dismiss(self: CaptureRibbon)
	local item = self._current
	self._token += 1
	self._current = nil
	self:_release()
	Motion.cancelAll(self._ribbon)
	Motion.cancelAll(self._flyer)
	self._flyer.Visible = false
	self._ribbon.GroupTransparency = 1
	self._ribbon.Visible = false
	if item then
		self:_settle(item)
	end
end

function CaptureRibbon.pendingCards(self: CaptureRibbon): { Store.CarRef }
	return table.clone(self._pending)
end

function CaptureRibbon.takePendingCards(self: CaptureRibbon): { Store.CarRef }
	local out = self._pending
	self._pending = {}
	return out
end

function CaptureRibbon.layout(self: CaptureRibbon)
	local ctx = self._ctx
	RunLayout.fit(ctx, self.root)
	local rect = RunLayout.sideRect(ctx)
	local compact = RunLayout.compact(ctx)
	local h = math.min(rect.size.Y, if compact then 78 else 96)
	local w = rect.size.X
	self._ribbon.Size = UDim2.fromOffset(w, h)
	if not self._current then
		self._ribbon.Position = UDim2.fromOffset(rect.pos.X, rect.pos.Y)
	end
	local iconSize = if compact then 36 else 48
	self._icon.Size = UDim2.fromOffset(iconSize, iconSize)
	local left = 14 + iconSize + 10
	local titleH = if compact then 22 else 30
	local lineH = if compact then 20 else 24
	local top = math.max(4, (h - titleH - lineH - 20) / 2)
	self._title.Position = UDim2.fromOffset(left, top)
	self._title.Size = UDim2.new(1, -left - 8, 0, titleH)
	self._identity.Position = UDim2.fromOffset(left, top + titleH)
	self._identity.Size = UDim2.new(1, -left - 8, 0, lineH)
	self._sub.Position = UDim2.fromOffset(left, top + titleH + lineH)
	self._sub.Size = UDim2.new(1, -left - 90, 0, 20)
	self._amount.Position = UDim2.new(1, -10, 0, top + titleH + lineH + 10)
	self._caption.Position = UDim2.new(1, -8, 0, 4)
end

function CaptureRibbon.setVisible(self: CaptureRibbon, on: boolean)
	self._visible = on
	self.root.Visible = on
	if not on then
		self:dismiss()
	end
end

function CaptureRibbon.getDebugState(self: CaptureRibbon): { [string]: any }
	local rect = RunLayout.sideRect(self._ctx)
	local pending = {}
	for _, c in self._pending do
		table.insert(pending, c.name)
	end
	return {
		visible = self._visible,
		showing = self._current and self._current.id,
		showingKind = self._current and self._current.kind,
		title = self._title.Text,
		queued = #self._queue,
		shown = self._shown,
		suppressed = self._suppressed,
		bursts = self._bursts,
		maxBurstPieces = self._pieces,
		flights = self._flights,
		pendingForResults = pending,
		box = RunLayout.describe(rect),
		overlapsProtected = RunLayout.overlaps(rect, RunLayout.protected(self._ctx)),
	}
end

function CaptureRibbon.destroy(self: CaptureRibbon)
	self._trove:Destroy()
end

return CaptureRibbon
