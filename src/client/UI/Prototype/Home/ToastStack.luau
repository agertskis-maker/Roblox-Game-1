--!strict
-- Home HUD: toast stack in a reserved area below the tutorial banner (Lane 3 preview, HUD
-- rebuild 2026-10-22; ledger H-13, L-06).
--
--   * Kit look: wide compact rectangles with limited rounding, the thick dark boundary, a strong
--     fill per tone with the narrow gloss band, white outlined text. Tones (colour is never the
--     only signal; each has an icon): Success = "Green" fill + tick, Info = "Garage" blue + "i"
--     disc, Unlock = "Gold" fill + star. Round 3 (R2-HM3): the body is an Arcade.surface (fill, ONE
--     dark outline, gloss), Info is no longer a dark navy body, and the "x2" count is a white tag
--     with a thin dark outline instead of a dark block with a white border.
--   * At most PreviewTokens.Motion.ToastMaxVisible (2) visible, each for ToastSeconds (2.5 s).
--   * Bounded queue of ToastQueue (6); when full, the oldest waiting toast is dropped (a toast is
--     time-bound information, not a claim).
--   * Duplicate coalescing: the same text and tone as a visible or waiting toast adds to its
--     count ("×2", "×3"...) instead of a new toast; a visible one restarts its timer.
--   * Oldest on top; the next slides up (snaps in reduced motion).
--   * While mode == "Run", the stack asks the screen-slot arbiter (ctx.priority) for the "Upper"
--     slot at level "Reward" before showing anything, shows only while it holds the slot, hides
--     at once when the slot is revoked (a higher level such as Capture or Safety took it) and
--     releases it when the stack empties. Waiting toasts stay queued (bounded). In Home mode, or
--     with no arbiter, it shows directly.
-- Placement (Home/Layout) keeps it under the banner and away from the menu, the stats and the
-- reserved touch zones. Nothing is interactive.
-- Round 3 (R2-HM3), run view only: the Home spot sits across the protected road rectangle on the tablet and the
-- phone frames, so while the arbiter gates the stack (the Run mode) it uses the Upper row it asks for, centred
-- under the distance pill where the district popup and the milestone band also sit (RunLayout.upperY). Only as
-- many toasts show as fit between that row and the protected rectangle (one on the phone frames, two elsewhere);
-- the rest wait in the bounded queue. Set RUN_UPPER_ROW = false to go back to the Home spot in the run view.
--
-- Store wiring: store.Event kind "Toast" (event.text, event.tone); store.ModeChanged.
-- API: ToastStack.new(ctx) -> ToastStack
--   :push(text, tone?)  :clear()  :layout()  :setVisible(on)  :destroy()  :getDebugState()

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextService = game:GetService("TextService")

local Arcade = require(script.Parent.Parent.Arcade)
local Fade = require(script.Parent.Fade)
local IconArt = require(script.Parent.IconArt)
local Layout = require(script.Parent.Layout)
local Motion = require(script.Parent.Parent.Motion)
local Priority = require(script.Parent.Parent.Priority)
local PreviewTokens = require(script.Parent.Parent.PreviewTokens)
local RunLayout = require(script.Parent.Parent.Run.RunLayout)
local Sounds = require(script.Parent.Parent.Sounds)
local Store = require(script.Parent.Parent.Store)
local Trove = require(ReplicatedStorage.Packages.Trove)
local Types = require(script.Parent.Types)

local A = PreviewTokens.Arcade
local B = A.Button
local M = PreviewTokens.Motion

local TEXT = A.Text.Label
local ICON = 28
local PAD = 12
local POOL = 3 -- two visible plus one leaving
local SLOT: Priority.Slot = "Upper"
local LEVEL: Priority.Level = "Reward"
local SLOT_ID = "home-toasts"
-- Round 3: the run view places the stack in the Upper row (see the header); false = the Home spot everywhere.
local RUN_UPPER_ROW = true
-- TOKEN CANDIDATE: the stack width in the run view (the widest Home width).
local RUN_WIDTH = 360
-- TOKEN CANDIDATE: how much taller the label font draws a line than TextService measures it (Fredoka One).
local LINE_RATIO = 1.2
-- TOKEN CANDIDATE: the count tag ("x2") size; the wide one is for two-digit counts.
local COUNT_W = 38
local COUNT_W_WIDE = 50
local COUNT_H = 26

export type Tone = "Success" | "Info" | "Unlock"

export type ToastStack = {
	root: Frame,
	push: (self: ToastStack, text: string, tone: string?) -> (),
	clear: (self: ToastStack) -> (),
	layout: (self: ToastStack) -> (),
	setVisible: (self: ToastStack, on: boolean) -> (),
	destroy: (self: ToastStack) -> (),
	getDebugState: (self: ToastStack) -> { [string]: any },
}

type Visual = {
	container: Frame,
	body: Frame,
	lip: Frame,
	gradient: UIGradient,
	text: TextLabel,
	icons: { [string]: Frame },
	count: Frame,
	countText: TextLabel,
	fade: Fade.FadeObject,
	busy: boolean,
}

type Toast = {
	text: string,
	tone: Tone,
	count: number,
	visual: Visual?,
	token: number,
	height: number,
	timer: thread?, -- the pending dismissal (cancelled when the toast goes or restarts)
}

local ToastStack = {}
ToastStack.__index = ToastStack

local function toneOf(tone: string?): Tone
	if tone == "Success" then
		return "Success"
	elseif tone == "Unlock" then
		return "Unlock"
	end
	return "Info"
end

local function measure(text: string, size: number, width: number?): Vector2
	return TextService:GetTextSize(text, size, Enum.Font.FredokaOne, Vector2.new(width or 4096, 4096))
end

local function buildVisual(parent: Instance, index: number): Visual
	local make = Arcade.make
	local container = make("Frame", {
		Name = "Toast" .. index,
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(300, Layout.ToastHeight),
		Visible = false,
		ZIndex = 5,
		Parent = parent,
	})
	local lip = make("Frame", {
		Name = "Lip",
		Position = UDim2.fromOffset(0, B.DepthOffset),
		Size = UDim2.new(1, 0, 1, -B.DepthOffset),
		BackgroundColor3 = A.Ink,
		ZIndex = 5,
		Parent = container,
	})
	Arcade.corner(lip)
	local body = make("Frame", {
		Name = "Body",
		Size = UDim2.new(1, 0, 1, -B.DepthOffset),
		ZIndex = 6,
		Parent = container,
	})
	-- Round 3 (R2-HM3): the arcade surface (fill, ONE dark outline, gloss); _style swaps the fill per tone
	Arcade.surface(body, "Green")
	local gradient = body:FindFirstChildOfClass("UIGradient") :: UIGradient
	local icons: { [string]: Frame } = {}
	for _, tone in { "Success", "Info", "Unlock" } do
		local holder = make("Frame", {
			Name = "Icon" .. tone,
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, PAD - 2, 0.5, 0),
			Size = UDim2.fromOffset(ICON, ICON),
			BackgroundTransparency = 1,
			Visible = false,
			ZIndex = 8,
			Parent = body,
		})
		if tone == "Success" then
			IconArt.draw(holder, { "Check" })
		elseif tone == "Unlock" then
			IconArt.draw(holder, { "Star" })
		else
			holder.BackgroundTransparency = 0
			holder.BackgroundColor3 = Color3.new(1, 1, 1)
			Arcade.corner(holder, ICON)
			Arcade.outline(holder, "Minor")
			local i = Arcade.text(holder, { text = "i", role = "Small", name = "I", colour = A.Ink, z = 9 })
			i.Size = UDim2.fromScale(1, 1)
		end
		icons[tone] = holder
	end
	local text = Arcade.text(body, {
		text = "",
		role = "Label",
		name = "Text",
		size = TEXT,
		xAlign = Enum.TextXAlignment.Left,
		z = 8,
	})
	text.Position = UDim2.fromOffset(PAD + ICON + 8, 0)
	text.TextWrapped = true
	-- only used while TextScaled is on (the run view where the rows are fixed height): never below the 16 minimum
	make("UITextSizeConstraint", { MaxTextSize = TEXT, MinTextSize = A.Text.Small, Parent = text })
	local count = make("Frame", {
		Name = "Count",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -PAD + 4, 0.5, 0),
		Size = UDim2.fromOffset(COUNT_W, COUNT_H),
		BackgroundColor3 = Color3.new(1, 1, 1),
		Visible = false,
		ZIndex = 9,
		Parent = body,
	})
	Arcade.corner(count, 6)
	Arcade.outline(count, "Minor")
	local countText = Arcade.text(count, {
		text = "×2",
		role = "Small",
		name = "Text",
		italic = true,
		colour = A.Ink,
		z = 10,
	})
	countText.Size = UDim2.fromScale(1, 1)
	local v: Visual = {
		container = container,
		body = body,
		lip = lip,
		gradient = gradient,
		text = text,
		icons = icons,
		count = count,
		countText = countText,
		fade = Fade.capture(container),
		busy = false,
	}
	v.fade:set(1)
	return v
end

function ToastStack.new(ctx: Types.Ctx): ToastStack
	local self = setmetatable({}, ToastStack) :: any
	local trove = Trove.new()
	self._trove = trove
	self._ctx = ctx
	self._destroyed = false
	self._width = 300
	self._shown = {} :: { Toast }
	self._queue = {} :: { Toast }
	self._dropped = 0
	self._revoked = 0
	self._maxVisible = M.ToastMaxVisible -- fewer in the run view on the frames with little room (layout)
	self._fixed = false -- fixed-height rows with shrinking text (the run view when two-line rows would not fit)
	self._place = "Home" :: string -- "Home" or "Upper" (the run view row)
	self._timers = {} :: { [thread]: boolean } -- pending dismissals (cancelled on destroy)
	self._conns = {} :: { [RBXScriptConnection]: boolean } -- tween completions in flight (disconnected on destroy)
	self._handle = nil :: Priority.Handle?
	self._granted = false
	local root = trove:Add(Arcade.make("Frame", {
		Name = "ToastStack",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(300, 120),
		ZIndex = 5,
		Parent = ctx.layer,
	}))
	pcall(function()
		(root :: any).Interactable = false
	end)
	self.root = root
	self._scale = Arcade.make("UIScale", { Name = "HudScale", Scale = ctx.screen:uiScale(), Parent = root })
	self._visuals = {} :: { Visual }
	for i = 1, POOL do
		table.insert(self._visuals, buildVisual(root, i))
	end
	trove:Add(function()
		for _, t in self._shown do
			t.token += 1
		end
		for thread in self._timers do
			pcall(task.cancel, thread)
		end
		table.clear(self._timers)
		for conn in self._conns do
			conn:Disconnect()
		end
		table.clear(self._conns)
		for _, v in self._visuals do
			Motion.cancelAll(v.container)
			v.fade:destroy()
		end
		self:_release()
	end)
	trove:Connect(ctx.store.Event, function(event: Store.Event)
		if event.kind == "Toast" and type(event.text) == "string" and event.text ~= "" then
			self:push(event.text, event.tone)
		end
	end)
	trove:Connect(ctx.store.ModeChanged, function()
		self:_onMode()
	end)
	trove:Connect(ctx.screen.Changed, function()
		self:layout()
	end)
	self:layout()
	return self :: ToastStack
end

-- SLOT ARBITRATION ---------------------------------------------------------------------------

function ToastStack._gated(self: any): boolean
	local ctx: Types.Ctx = self._ctx
	return ctx.priority ~= nil and ctx.store:get().mode == "Run"
end

function ToastStack._canShow(self: any): boolean
	return not self:_gated() or self._granted
end

function ToastStack._release(self: any)
	local ctx: Types.Ctx = self._ctx
	local h: Priority.Handle? = self._handle
	self._handle = nil
	self._granted = false
	if h and ctx.priority then
		ctx.priority:release(h)
	end
end

function ToastStack._requestSlot(self: any)
	local ctx: Types.Ctx = self._ctx
	local arb = ctx.priority
	local held: Priority.Handle? = self._handle
	if held and held.released then
		-- the arbiter let a queued request expire: ask again
		self._handle = nil
		self._granted = false
	end
	if not arb or self._handle then
		return
	end
	self._handle = arb:request(SLOT, LEVEL, SLOT_ID, {
		grant = function()
			if self._destroyed then
				return
			end
			self._granted = true
			self:_drain()
		end,
		revoke = function()
			if self._destroyed then
				return
			end
			-- a higher level took the slot: hide the shown toasts at once (they are dropped:
			-- time-bound information whose moment has passed); waiting ones stay queued
			self._handle = nil
			self._granted = false
			self._revoked += 1
			self:_hideShown()
		end,
		wait = M.ToastSeconds,
	})
	if self._handle == nil then
		-- the arbiter could not queue the request (busy at a higher level): try again on the
		-- next push; the toasts wait in the bounded queue meanwhile
		self._granted = false
	end
end

function ToastStack._onMode(self: any)
	self:layout() -- the run view and the Home view place the stack differently
	if self:_gated() then
		if #self._shown > 0 or #self._queue > 0 then
			self:_requestSlot()
		end
	else
		self:_release()
		self:_drain()
	end
end

-- Shows waiting toasts while there is room and permission.
function ToastStack._drain(self: any)
	while #self._queue > 0 and #self._shown < self._maxVisible and self:_canShow() do
		if not self:_show(table.remove(self._queue, 1) :: Toast) then
			break
		end
	end
	if self:_gated() and #self._shown == 0 and #self._queue == 0 then
		self:_release()
	end
end

-- VISUALS ------------------------------------------------------------------------------------

-- The row height a text needs. TextService measures Enum.Font lines at the font size, but the label's own font draws a
-- line about LINE_RATIO taller, and the final pixel size is rounded, so the text is wrapped a little narrower than its
-- box and the height keeps that slack: a text always fits in full (Round 3: Studio reported TextFits = false on Desktop).
local function rowHeight(text: string, width: number): number
	local wrapW = width - 8 - math.ceil(width * 0.06)
	return math.ceil(measure(text, TEXT, wrapW).Y * LINE_RATIO) + 20 + B.DepthOffset
end

-- the count tag is wider once it shows two digits ("x10" and up) so the number never spills out of it
local function countWidth(count: number): number
	return if count >= 10 then COUNT_W_WIDE else COUNT_W
end

function ToastStack._contentWidth(self: any, count: number): number
	local countW = if count > 1 then countWidth(count) + 8 else 0
	return self._width - (PAD + ICON + 8) - PAD - countW
end

function ToastStack._style(self: any, toast: Toast)
	local v = toast.visual :: Visual
	local tone = toast.tone
	v.gradient.Color = if tone == "Success" then A.Fill.Green elseif tone == "Unlock" then A.Fill.Gold else A.Fill.Garage
	for name, holder in v.icons do
		holder.Visible = name == tone
	end
	self:_fill(toast)
end

function ToastStack._fill(self: any, toast: Toast)
	local v = toast.visual :: Visual
	v.text.Text = toast.text
	v.count.Visible = toast.count > 1
	v.count.Size = UDim2.fromOffset(countWidth(toast.count), COUNT_H)
	v.countText.Text = "×" .. tostring(math.min(toast.count, 99))
	local w = self:_contentWidth(toast.count)
	-- Round 3: where the run view has too little room for two-line toasts the rows keep the base height and the
	-- text shrinks to fit (18 down to the 16 minimum, wrapping to two lines); elsewhere a long text grows the row
	local fixed: boolean = self._fixed
	v.text.TextScaled = fixed
	local h = if fixed then Layout.ToastHeight else math.max(Layout.ToastHeight, rowHeight(toast.text, w))
	toast.height = h
	v.text.Size = UDim2.fromOffset(w, h - B.DepthOffset)
	v.container.Size = UDim2.fromOffset(self._width, h)
end

function ToastStack._restack(self: any, animate: boolean)
	local y = 0
	for _, toast in self._shown do
		local v = toast.visual :: Visual
		local goal = UDim2.fromOffset(0, y)
		if animate and not Motion.reduced() and v.container.Visible then
			Motion.tween(v.container, "move", Motion.info(0.2), { Position = goal })
		else
			Motion.cancelAll(v.container)
			v.container.Position = goal
		end
		y += toast.height + Layout.ToastGap
	end
end

-- Cancels the toast's pending dismissal (it goes, or its timer restarts).
function ToastStack._disarm(self: any, toast: Toast)
	local pending = toast.timer
	toast.timer = nil
	if pending then
		self._timers[pending] = nil
		pcall(task.cancel, pending)
	end
end

function ToastStack._arm(self: any, toast: Toast)
	self:_disarm(toast)
	toast.token += 1
	local token = toast.token
	local timers: { [thread]: boolean } = self._timers
	local thread: thread
	thread = task.delay(M.ToastSeconds, function()
		timers[thread] = nil
		if toast.timer == thread then
			toast.timer = nil
		end
		if self._destroyed or token ~= toast.token then
			return
		end
		self:_dismiss(toast)
	end)
	toast.timer = thread
	timers[thread] = true
end

function ToastStack._freeVisual(self: any): Visual?
	for _, v in self._visuals do
		if not v.busy then
			return v
		end
	end
	-- every visual busy (two shown, one leaving): finish the leaving one now
	for _, v in self._visuals do
		local inUse = false
		for _, t in self._shown do
			if t.visual == v then
				inUse = true
			end
		end
		if not inUse then
			Motion.cancelAll(v.container)
			v.fade:set(1)
			v.container.Visible = false
			v.busy = false
			return v
		end
	end
	return nil
end

function ToastStack._show(self: any, toast: Toast): boolean
	local visual = self:_freeVisual()
	if visual == nil then
		table.insert(self._queue, 1, toast)
		return false
	end
	local v = visual :: Visual
	v.busy = true
	toast.visual = v
	table.insert(self._shown, toast)
	self:_style(toast)
	self:_restack(false)
	v.container.Visible = true
	v.fade:set(1)
	v.fade:tween(0, 0.15)
	if not Motion.reduced() then
		local rest = v.container.Position
		v.container.Position = rest + UDim2.fromOffset(0, -8)
		Motion.tween(v.container, "move", Motion.info(0.2), { Position = rest })
	end
	Sounds.play("Toast")
	self:_arm(toast)
	return true
end

function ToastStack._hideVisual(self: any, v: Visual, seconds: number)
	local tw = v.fade:tween(1, seconds)
	local function done()
		v.container.Visible = false
		v.busy = false
	end
	if tw then
		local conns: { [RBXScriptConnection]: boolean } = self._conns
		local conn: RBXScriptConnection
		conn = tw.Completed:Connect(function(state)
			conns[conn] = nil
			conn:Disconnect()
			if state == Enum.PlaybackState.Completed then
				done()
			end
		end)
		conns[conn] = true
	else
		done()
	end
end

function ToastStack._hideShown(self: any)
	for _, toast in self._shown do
		toast.token += 1
		self:_disarm(toast)
		local v = toast.visual
		toast.visual = nil
		if v then
			Motion.cancelAll(v.container)
			self:_hideVisual(v, 0)
		end
	end
	table.clear(self._shown)
end

function ToastStack._dismiss(self: any, toast: Toast)
	local index = table.find(self._shown, toast)
	if not index then
		return
	end
	table.remove(self._shown, index)
	toast.token += 1
	self:_disarm(toast)
	local v = toast.visual :: Visual
	toast.visual = nil
	self:_hideVisual(v, if Motion.reduced() then 0.12 else 0.2)
	self:_restack(true)
	self:_drain()
end

function ToastStack.push(self: any, text: string, tone: string?)
	if self._destroyed then
		return
	end
	local t = toneOf(tone)
	for _, toast in self._shown do
		if toast.text == text and toast.tone == t then
			toast.count += 1
			self:_fill(toast)
			self:_restack(false)
			Motion.pop((toast.visual :: Visual).count, 1.15)
			self:_arm(toast)
			return
		end
	end
	for _, toast in self._queue do
		if toast.text == text and toast.tone == t then
			toast.count += 1
			return
		end
	end
	local toast: Toast = {
		text = text,
		tone = t,
		count = 1,
		visual = nil,
		token = 0,
		height = Layout.ToastHeight,
		timer = nil,
	}
	if #self._queue >= M.ToastQueue then
		table.remove(self._queue, 1)
		self._dropped += 1
	end
	table.insert(self._queue, toast)
	if self:_gated() and not self._granted then
		self:_requestSlot()
	end
	self:_drain()
end

function ToastStack.clear(self: any)
	table.clear(self._queue)
	for _, toast in table.clone(self._shown) do
		toast.token += 1
		self:_disarm(toast)
	end
	table.clear(self._shown)
	for _, v in self._visuals do
		Motion.cancelAll(v.container)
		v.fade:set(1)
		v.container.Visible = false
		v.busy = false
	end
	self:_release()
end

function ToastStack.layout(self: any)
	local ctx: Types.Ctx = self._ctx
	local scale = ctx.screen:uiScale()
	self._scale.Scale = scale
	local home = Layout.forProfile(ctx.screen:profile(), scale)
	local t = home.toasts
	local x, y, width = t.x, t.y, t.width
	local maxVisible = M.ToastMaxVisible
	local fixed = false
	local stackH = 2 * 64 + Layout.ToastGap
	-- the height of a stack of the most visible two-line rows
	local tall = math.ceil(measure("A\nA", TEXT).Y * LINE_RATIO) + 20 + B.DepthOffset
	self._place = "Home"
	if RUN_UPPER_ROW and self:_gated() then
		-- the run view: the Upper row under the distance pill, as many toasts as fit above the protected rectangle
		local rl: RunLayout.Ctx = ctx :: any
		local d = RunLayout.design(rl)
		local top = RunLayout.upperY(rl)
		local room = RunLayout.protected(rl).pos.Y - top
		width = math.min(RUN_WIDTH, d.X - 2 * RunLayout.Margin)
		x, y = d.X / 2, top
		maxVisible =
			math.clamp(math.floor((room + Layout.ToastGap) / (Layout.ToastHeight + Layout.ToastGap)), 1, maxVisible)
		-- a two-line row is taller than the base row: when that many of them would not fit, rows stay at the base height
		fixed = room < maxVisible * tall + (maxVisible - 1) * Layout.ToastGap
		stackH = maxVisible * (if fixed then Layout.ToastHeight else tall) + (maxVisible - 1) * Layout.ToastGap
		self._place = "Upper"
	else
		-- Home: the spot Home/Layout chose can reach a touch zone once two-line rows stack (PhoneSmall: the Jump zone,
		-- already so in Round 2). The rows then keep the base height, which clears every zone on all six frames.
		local left = x - width * t.anchorX
		local worst = 2 * tall + Layout.ToastGap
		for _, z in home.reserved do
			if left < z.x + z.w and left + width > z.x and y < z.y + z.h and y + worst > z.y then
				fixed = true
				stackH = 2 * Layout.ToastHeight + Layout.ToastGap
				break
			end
		end
	end
	self._maxVisible = maxVisible
	self._fixed = fixed
	self._width = width
	self.root.AnchorPoint = Vector2.new(t.anchorX, 0)
	self.root.Position = UDim2.fromOffset(x * scale, y * scale) -- layer px
	self.root.Size = UDim2.fromOffset(width, stackH)
	for _, toast in self._shown do
		self:_fill(toast)
	end
	self:_restack(false)
end

function ToastStack.setVisible(self: any, on: boolean)
	self.root.Visible = on
end

function ToastStack.getDebugState(self: any): { [string]: any }
	local ctx: Types.Ctx = self._ctx
	local shown = {}
	local overlap: string? = nil
	for _, toast in self._shown do
		local v = toast.visual :: Visual
		local pos, size = ctx.screen:rectOf(v.container)
		overlap = overlap or ctx.screen:overlapsReserved(pos, size)
		table.insert(shown, {
			text = toast.text,
			tone = toast.tone,
			count = toast.count,
			height = toast.height,
			textFits = v.text.TextFits,
			devicePos = pos,
			deviceSize = size,
		})
	end
	local queued = {}
	for _, toast in self._queue do
		table.insert(queued, { text = toast.text, tone = toast.tone, count = toast.count })
	end
	local busy = 0
	for _, v in self._visuals do
		if v.busy then
			busy += 1
		end
	end
	local rpos, rsize = ctx.screen:rectOf(self.root)
	-- every toast body is one arcade surface: ONE UIStroke on the frame itself, one fill gradient, the gloss band
	local surfaces = {}
	for _, v in self._visuals do
		local outlines, gradients = 0, 0
		for _, child in v.body:GetChildren() do
			if child:IsA("UIStroke") then
				outlines += 1
			elseif child:IsA("UIGradient") then
				gradients += 1
			end
		end
		table.insert(surfaces, {
			name = v.container.Name,
			outlines = outlines,
			gradients = gradients,
			gloss = v.body:FindFirstChild("Gloss") ~= nil,
		})
	end
	local timers, conns = 0, 0
	for _ in self._timers do
		timers += 1
	end
	for _ in self._conns do
		conns += 1
	end
	return {
		visible = self.root.Visible,
		surfaces = surfaces,
		timers = timers, -- pending dismissals (0 after destroy)
		connections = conns, -- tween completions in flight (0 after destroy)
		instances = if self._destroyed then 0 else #self.root:GetDescendants(),
		shownCount = #self._shown,
		maxVisible = self._maxVisible,
		placement = self._place,
		fixedHeight = self._fixed,
		queueCount = #self._queue,
		queueLimit = M.ToastQueue,
		dropped = self._dropped,
		visualsBusy = busy,
		visualPool = POOL,
		gated = self:_gated(),
		slotHeld = self._handle ~= nil,
		slotGranted = self._granted,
		revoked = self._revoked,
		shown = shown,
		queued = queued,
		width = self._width,
		devicePos = rpos,
		deviceSize = rsize,
		reservedOverlap = overlap or ctx.screen:overlapsReserved(rpos, rsize),
	}
end

function ToastStack.destroy(self: any)
	if self._destroyed then
		return
	end
	self._destroyed = true
	self._trove:Destroy()
end

return ToastStack
