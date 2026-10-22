--!strict
-- Home HUD: toast stack in a reserved area below the tutorial banner (Lane 3 preview).
--
--   * At most PreviewTokens.Motion.ToastMaxVisible (2) visible, each for ToastSeconds (2.5 s).
--   * Bounded queue of ToastQueue (6) waiting toasts; when full, the oldest waiting toast is
--     dropped (a toast is time-bound information, not a claim).
--   * Duplicate merging: the same text and tone as a visible or waiting toast adds to its count
--     ("x2", "x3"...) instead of a new toast; a visible one restarts its timer.
--   * Tones (colour is never the only signal; each has an icon): Success = green with a tick,
--     Info = cream/navy with an "i" disc, Unlock = gold with a star.
--   * Oldest on top; when it leaves, the next slides up (snaps in reduced motion) and a waiting
--     toast appears below.
-- Placement (Home/Layout) keeps it under the banner and away from the reserved bottom control
-- zones; on PhonePortrait it is right-aligned and 220 px wide, right of the thumbstick zone.
-- Nothing is interactive.
--
-- Store wiring: store.Event kind "Toast" (event.text, event.tone).
-- API: ToastStack.new(ctx) -> ToastStack
--   :push(text, tone?)  :clear()  :layout()  :setVisible(on)  :destroy()  :getDebugState()

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextService = game:GetService("TextService")

local Fade = require(script.Parent.Fade)
local Gloss = require(script.Parent.Parent.Gloss)
local Icons = require(script.Parent.Parent.Icons)
local Layout = require(script.Parent.Layout)
local Motion = require(script.Parent.Parent.Motion)
local PreviewTokens = require(script.Parent.Parent.PreviewTokens)
local Sounds = require(script.Parent.Parent.Sounds)
local Store = require(script.Parent.Parent.Store)
local Tokens = require(ReplicatedStorage.Shared.UI.Tokens)
local Trove = require(ReplicatedStorage.Packages.Trove)
local Types = require(script.Parent.Types)

local C = PreviewTokens.Color
local M = PreviewTokens.Motion
local make = Gloss.make

local TEXT = 18
local ICON = 26
local PAD = 12
local POOL = 3 -- two visible plus one leaving

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
	shadow: Frame,
	gradient: UIGradient,
	text: TextLabel,
	textStroke: UIStroke,
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
	local container = make("Frame", {
		Name = "Toast" .. index,
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(300, 44),
		Visible = false,
		ZIndex = 5,
		Parent = parent,
	})
	local shadow = make("Frame", {
		Name = "Shadow",
		Position = UDim2.fromOffset(0, PreviewTokens.Size.ShadowOffset),
		Size = UDim2.new(1, 0, 1, -PreviewTokens.Size.ShadowOffset),
		BackgroundColor3 = C.Shadow,
		BackgroundTransparency = 0.55,
		BorderSizePixel = 0,
		ZIndex = 5,
		Parent = container,
	})
	Gloss.corner(shadow, 14)
	local body = make("Frame", {
		Name = "Body",
		Size = UDim2.new(1, 0, 1, -PreviewTokens.Size.ShadowOffset),
		BackgroundColor3 = C.White,
		BorderSizePixel = 0,
		ZIndex = 6,
		Parent = container,
	})
	Gloss.corner(body, 14)
	Gloss.stroke(body, 2.5)
	local gradient = Gloss.gradient(body, C.White, C.White)
	local icons: { [string]: Frame } = {}
	for _, tone in { "Success", "Info", "Unlock" } do
		local holder = make("Frame", {
			Name = "Icon" .. tone,
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, PAD, 0.5, 0),
			Size = UDim2.fromOffset(ICON, ICON),
			BackgroundTransparency = 1,
			Visible = false,
			ZIndex = 7,
			Parent = body,
		})
		if tone == "Success" then
			Icons.draw(holder, "Check")
		elseif tone == "Unlock" then
			Icons.draw(holder, "Star", C.White)
		else
			holder.BackgroundTransparency = 0
			holder.BackgroundColor3 = C.Ink
			Gloss.corner(holder, ICON / 2)
			make("TextLabel", {
				Name = "I",
				BackgroundTransparency = 1,
				Size = UDim2.fromScale(1, 1),
				FontFace = Tokens.font(),
				Text = "i",
				TextSize = 18,
				TextColor3 = C.White,
				ZIndex = 8,
				Parent = holder,
			})
		end
		icons[tone] = holder
	end
	local text = make("TextLabel", {
		Name = "Text",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(PAD + ICON + 10, 0),
		FontFace = Tokens.font(),
		Text = "",
		TextSize = TEXT,
		TextColor3 = C.Ink,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = true,
		ZIndex = 7,
		Parent = body,
	})
	local textStroke = Gloss.stroke(text, 2, C.Ink, Enum.ApplyStrokeMode.Contextual)
	local count = make("Frame", {
		Name = "Count",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -PAD + 2, 0.5, 0),
		Size = UDim2.fromOffset(36, 24),
		BackgroundColor3 = C.Ink,
		BorderSizePixel = 0,
		Visible = false,
		ZIndex = 8,
		Parent = body,
	})
	Gloss.corner(count, 12)
	local countText = make("TextLabel", {
		Name = "Text",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		FontFace = Tokens.font(),
		Text = "x2",
		TextSize = 16,
		TextColor3 = C.White,
		ZIndex = 9,
		Parent = count,
	})
	local v: Visual = {
		container = container,
		body = body,
		shadow = shadow,
		gradient = gradient,
		text = text,
		textStroke = textStroke,
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
	local root = trove:Add(make("Frame", {
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
	self._scale = make("UIScale", { Name = "HudScale", Scale = ctx.screen:uiScale(), Parent = root })
	self._visuals = {} :: { Visual }
	for i = 1, POOL do
		table.insert(self._visuals, buildVisual(root, i))
	end
	trove:Add(function()
		for _, t in self._shown do
			t.token += 1
		end
		for _, v in self._visuals do
			Motion.cancelAll(v.container)
			v.fade:destroy()
		end
	end)
	trove:Connect(ctx.store.Event, function(event: Store.Event)
		if event.kind == "Toast" and type(event.text) == "string" and event.text ~= "" then
			self:push(event.text, event.tone)
		end
	end)
	trove:Connect(ctx.screen.Changed, function()
		self:layout()
	end)
	self:layout()
	return self :: ToastStack
end

function ToastStack._contentWidth(self: any, count: number): number
	local countW = if count > 1 then 36 + 8 else 0
	return self._width - (PAD + ICON + 10) - PAD - countW
end

function ToastStack._style(self: any, toast: Toast)
	local v = toast.visual :: Visual
	local tone = toast.tone
	if tone == "Success" then
		v.body.BackgroundColor3 = C.White
		v.gradient.Color = ColorSequence.new(C.SuccessLight, C.Success)
		v.text.TextColor3 = C.White
		v.textStroke.Enabled = true
	elseif tone == "Unlock" then
		v.body.BackgroundColor3 = C.White
		v.gradient.Color = ColorSequence.new(C.KeysLight, C.KeysDeep)
		v.text.TextColor3 = C.Ink
		v.textStroke.Enabled = false
	else
		v.body.BackgroundColor3 = C.White
		v.gradient.Color = ColorSequence.new(C.Panel, C.Panel)
		v.text.TextColor3 = C.Ink
		v.textStroke.Enabled = false
	end
	for name, holder in v.icons do
		holder.Visible = name == tone
	end
	self:_fill(toast)
end

-- Text, count pill and height for the toast's current count.
function ToastStack._fill(self: any, toast: Toast)
	local v = toast.visual :: Visual
	v.text.Text = toast.text
	v.count.Visible = toast.count > 1
	v.countText.Text = "x" .. tostring(math.min(toast.count, 99))
	local w = self:_contentWidth(toast.count)
	local h = math.max(PreviewTokens.Size.ToastHeight, math.ceil(measure(toast.text, TEXT, w).Y) + 18)
	toast.height = h
	v.text.Size = UDim2.fromOffset(w, h - PreviewTokens.Size.ShadowOffset)
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

function ToastStack._arm(self: any, toast: Toast)
	toast.token += 1
	local token = toast.token
	task.delay(M.ToastSeconds, function()
		if self._destroyed or token ~= toast.token then
			return
		end
		self:_dismiss(toast)
	end)
end

function ToastStack._show(self: any, toast: Toast)
	local visual: Visual? = nil
	for _, v in self._visuals do
		if not v.busy then
			visual = v
			break
		end
	end
	if visual == nil then
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
				visual = v
				break
			end
		end
	end
	if visual == nil then
		return
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
end

function ToastStack._dismiss(self: any, toast: Toast)
	local index = table.find(self._shown, toast)
	if not index then
		return
	end
	table.remove(self._shown, index)
	toast.token += 1
	local v = toast.visual :: Visual
	toast.visual = nil
	local tw = v.fade:tween(1, if Motion.reduced() then 0.12 else 0.2)
	local function done()
		v.container.Visible = false
		v.busy = false
	end
	if tw then
		tw.Completed:Connect(function(state)
			if state == Enum.PlaybackState.Completed then
				done()
			end
		end)
	else
		done()
	end
	self:_restack(true)
	if #self._queue > 0 and #self._shown < M.ToastMaxVisible then
		self:_show(table.remove(self._queue, 1) :: Toast)
	end
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
	local toast: Toast = { text = text, tone = t, count = 1, visual = nil, token = 0, height = 44 }
	if #self._shown < M.ToastMaxVisible then
		self:_show(toast)
	else
		if #self._queue >= M.ToastQueue then
			table.remove(self._queue, 1)
			self._dropped += 1
		end
		table.insert(self._queue, toast)
	end
end

function ToastStack.clear(self: any)
	table.clear(self._queue)
	for _, toast in table.clone(self._shown) do
		toast.token += 1
	end
	table.clear(self._shown)
	for _, v in self._visuals do
		Motion.cancelAll(v.container)
		v.fade:set(1)
		v.container.Visible = false
		v.busy = false
	end
end

function ToastStack.layout(self: any)
	local ctx: Types.Ctx = self._ctx
	local scale = ctx.screen:uiScale()
	self._scale.Scale = scale
	local t = Layout.forProfile(ctx.screen:profile(), scale).toasts
	self._width = t.width
	self.root.AnchorPoint = Vector2.new(t.anchorX, 0)
	self.root.Position = UDim2.fromOffset(t.x * scale, t.y * scale) -- layer px (UIScale does not move it)
	local maxH = 2 * 64 + Layout.ToastGap
	self.root.Size = UDim2.fromOffset(t.width, maxH)
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
	local rpos, rsize = ctx.screen:rectOf(self.root)
	return {
		visible = self.root.Visible,
		shownCount = #self._shown,
		maxVisible = M.ToastMaxVisible,
		queueCount = #self._queue,
		queueLimit = M.ToastQueue,
		dropped = self._dropped,
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
