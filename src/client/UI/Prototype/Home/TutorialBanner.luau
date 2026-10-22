--!strict
-- Home HUD: tutorial objective banner (Lane 3 preview, HUD rebuild 2026-10-22; ledger H-13).
-- The tutorial content is a PLACEHOLDER fixture list, not the real onboarding flow, and the
-- banner grants nothing.
--
-- Look (Arcade kit): a yellow ("Gold" fill) rectangle with limited rounding, the thick dark
-- button boundary and a narrow gloss band, a small yellow "TUTORIAL" tab, an ink status disc
-- (flag while active, tick when done). Text hierarchy — not every line enlarged equally:
--   1. objective   largest: white, Value size (24), heavy dark outline, wraps (never clipped)
--   2. progress    smaller italic counter "1/3" (Label 18) and a segmented-looking strip
--   3. micro-hint  smallest: white Small (16) with a light outline floating under the banner,
--                  no cream pill
-- States from store.tutorial (Store.Tutorial):
--   Active  objective + counter + strip
--   Hint    the same plus the micro-hint (tutorial.hint)
--   Done    tick, green body ("Green" fill), full strip, bounded confetti (16 pieces, none in
--           reduced motion), sound hook TutorialDone. After DONE_SECONDS the optional
--           opts.onDoneShown(step) fires once so the playground can advance the fixture; the
--           banner itself never writes the store.
-- A new step crossfades (and slides 12 px in, not in reduced motion). nil fades it out. Nothing
-- here is interactive: input passes through, no modal, no full-screen layer.
--
-- Placement (Home/Layout): top centre, clear of the left menu; full width at the top on
-- PhonePortrait. The body grows to fit wrapped text.
--
-- API: TutorialBanner.new(ctx, { onDoneShown: ((step: number) -> ())? }?) -> TutorialBanner
--   :layout()  :setVisible(on)  :destroy()  :getDebugState()

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextService = game:GetService("TextService")

local Arcade = require(script.Parent.Parent.Arcade)
local Fade = require(script.Parent.Fade)
local Format = require(ReplicatedStorage.Shared.UI.Format)
local IconArt = require(script.Parent.IconArt)
local Layout = require(script.Parent.Layout)
local Motion = require(script.Parent.Parent.Motion)
local PreviewTokens = require(script.Parent.Parent.PreviewTokens)
local Sounds = require(script.Parent.Parent.Sounds)
local Store = require(script.Parent.Parent.Store)
local Tokens = require(ReplicatedStorage.Shared.UI.Tokens)
local Trove = require(ReplicatedStorage.Packages.Trove)
local Types = require(script.Parent.Types)

local A = PreviewTokens.Arcade
local B = A.Button

local DONE_SECONDS = 1.6
local CONFETTI = 16
local CONFETTI_SECONDS = 0.9
local STATUS = 36
local PAD = 12
local STRIP = 8
local COUNTER_SIZE = A.Text.Label
local HINT_SIZE = A.Text.Small
local CONFETTI_COLOURS = {
	Color3.fromRGB(255, 120, 170),
	Color3.fromRGB(90, 190, 255),
	Color3.fromRGB(110, 220, 120),
	Color3.fromRGB(255, 255, 255),
	Color3.fromRGB(255, 170, 70),
	Color3.fromRGB(170, 130, 255),
}

export type Options = { onDoneShown: ((step: number) -> ())? }

export type TutorialBanner = {
	root: Frame,
	layout: (self: TutorialBanner) -> (),
	setVisible: (self: TutorialBanner, on: boolean) -> (),
	destroy: (self: TutorialBanner) -> (),
	getDebugState: (self: TutorialBanner) -> { [string]: any },
}

local TutorialBanner = {}
TutorialBanner.__index = TutorialBanner

local function measure(text: string, size: number, width: number?): Vector2
	return TextService:GetTextSize(text, size, Enum.Font.FredokaOne, Vector2.new(width or 4096, 4096))
end

local function counterText(t: Store.Tutorial): string
	local count = math.clamp(t.count, 0, t.goal)
	if t.state == "Done" then
		count = t.goal
	end
	return string.format("%s/%s", Format.group(count), Format.group(t.goal))
end

function TutorialBanner.new(ctx: Types.Ctx, opts: Options?): TutorialBanner
	local self = setmetatable({}, TutorialBanner) :: any
	local trove = Trove.new()
	self._trove = trove
	self._ctx = ctx
	self._opts = opts or {}
	self._destroyed = false
	self._width = 400
	self._textSize = Tokens.TextSize.Value
	self._bodyH = 60
	self._tutorial = nil :: Store.Tutorial?
	self._doneToken = 0
	self._wanted = true
	local make = Arcade.make

	local root = trove:Add(make("Frame", {
		Name = "TutorialBanner",
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(400, 120),
		Visible = false,
		ZIndex = 5,
		Parent = ctx.layer,
	}))
	pcall(function()
		(root :: any).Interactable = false
	end)
	self.root = root
	self._scale = make("UIScale", { Name = "HudScale", Scale = ctx.screen:uiScale(), Parent = root })

	local all = make("Frame", {
		Name = "All",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 5,
		Parent = root,
	})
	self._all = all

	-- shallow dark lip under the body (kit depth), then the body
	local lip = make("Frame", {
		Name = "Lip",
		Position = UDim2.fromOffset(0, Layout.BannerTabOverlap + B.DepthOffset),
		Size = UDim2.fromOffset(400, 60),
		BackgroundColor3 = A.Ink,
		ZIndex = 5,
		Parent = all,
	})
	Arcade.corner(lip)
	self._lip = lip
	local body = make("Frame", {
		Name = "Body",
		Position = UDim2.fromOffset(0, Layout.BannerTabOverlap),
		Size = UDim2.fromOffset(400, 60),
		BackgroundColor3 = Color3.new(1, 1, 1),
		ZIndex = 6,
		Parent = all,
	})
	Arcade.corner(body)
	Arcade.outline(body, "Button")
	self._gradient = make("UIGradient", { Color = A.Fill.Gold, Rotation = 90, Parent = body })
	Arcade.gloss(body)
	self._body = body

	local tab = make("Frame", {
		Name = "Tab",
		Position = UDim2.fromOffset(16, 0),
		Size = UDim2.fromOffset(math.ceil(measure("TUTORIAL", HINT_SIZE).X) + 22, 26),
		BackgroundColor3 = Color3.new(1, 1, 1),
		ZIndex = 9,
		Parent = all,
	})
	Arcade.corner(tab, 5)
	Arcade.outline(tab, "Button")
	make("UIGradient", { Color = A.Fill.Gold, Rotation = 90, Parent = tab })
	local tabText = Arcade.text(tab, { text = "TUTORIAL", role = "Small", name = "Text", z = 10 })
	tabText.Size = UDim2.fromScale(1, 1)

	-- content that crossfades on a new step
	local content = make("Frame", {
		Name = "Content",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 8,
		Parent = body,
	})
	self._content = content
	local status = make("Frame", {
		Name = "Status",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, PAD, 0.5, 0),
		Size = UDim2.fromOffset(STATUS, STATUS),
		BackgroundColor3 = A.Ink,
		ZIndex = 9,
		Parent = content,
	})
	Arcade.corner(status, STATUS)
	Arcade.outline(status, 2, Color3.new(1, 1, 1))
	self._statusIcons = {} :: { [string]: Frame }
	for _, name in { "Flag", "Check" } do
		local holder = make("Frame", {
			Name = name,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(24, 24),
			BackgroundTransparency = 1,
			Visible = name == "Flag",
			ZIndex = 10,
			Parent = status,
		})
		IconArt.draw(holder, { name })
		self._statusIcons[name] = holder
	end
	self._status = status
	self._statusName = "Flag"

	local objective = Arcade.text(content, {
		text = "",
		role = "Button",
		name = "Objective",
		size = Tokens.TextSize.Value,
		xAlign = Enum.TextXAlignment.Left,
		z = 9,
	})
	objective.TextWrapped = true
	self._objective = objective
	local counter = Arcade.text(content, {
		text = "",
		role = "Label",
		name = "Counter",
		size = COUNTER_SIZE,
		italic = true,
		xAlign = Enum.TextXAlignment.Right,
		z = 9,
	})
	self._counter = counter
	local track = make("Frame", {
		Name = "Strip",
		BackgroundColor3 = A.Ink,
		BackgroundTransparency = 0.45,
		ZIndex = 9,
		Parent = body,
	})
	Arcade.corner(track, STRIP / 2)
	Arcade.outline(track, "Minor")
	local fill = make("Frame", {
		Name = "Fill",
		BackgroundColor3 = Color3.new(1, 1, 1),
		Size = UDim2.fromScale(0, 1),
		ZIndex = 10,
		Parent = track,
	})
	Arcade.corner(fill, STRIP / 2)
	self._fillGradient = make("UIGradient", { Color = A.Fill.Green, Rotation = 90, Parent = fill })
	self._track = track
	self._fill = fill
	self._progress = 0

	-- micro-hint: floating outlined text under the banner (smallest line, no pill)
	local hint = make("Frame", {
		Name = "Hint",
		AnchorPoint = Vector2.new(0.5, 0),
		Size = UDim2.fromOffset(200, Layout.HintHeight),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 6,
		Parent = all,
	})
	local hintText = Arcade.text(hint, { text = "", role = "Small", name = "Text", size = HINT_SIZE, z = 7 })
	hintText.Size = UDim2.fromScale(1, 1)
	self._hint = hint
	self._hintText = hintText
	self._hintFade = Fade.capture(hint)
	self._contentFade = Fade.capture(content)
	self._allFade = Fade.capture(all)
	trove:Add(function()
		self._hintFade:destroy()
		self._contentFade:destroy()
		self._allFade:destroy()
		Motion.cancelAll(content)
		Motion.cancelAll(fill)
	end)

	self._confetti = {} :: { Frame }
	for i = 1, CONFETTI do
		local piece = make("Frame", {
			Name = "Confetti" .. i,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Size = UDim2.fromOffset(if i % 2 == 0 then 8 else 6, if i % 2 == 0 then 5 else 9),
			BackgroundColor3 = CONFETTI_COLOURS[(i - 1) % #CONFETTI_COLOURS + 1],
			BorderSizePixel = 0,
			Visible = false,
			ZIndex = 12,
			Parent = root,
		})
		Arcade.corner(piece, 2)
		table.insert(self._confetti, piece)
	end
	trove:Add(function()
		for _, piece in self._confetti do
			Motion.cancelAll(piece)
		end
	end)

	trove:Add(ctx.store:subscribe("tutorial", function(t: Store.Tutorial?)
		self:_set(t)
	end))
	trove:Add(Motion.onReducedChanged(function(reduced: boolean)
		if reduced then
			self:_stopConfetti()
			Motion.cancelAll(content)
			content.Position = UDim2.new()
		end
	end))
	trove:Connect(ctx.screen.Changed, function()
		self:layout()
	end)
	self:layout()
	self:_set(ctx.store:get().tutorial)
	return self :: TutorialBanner
end

function TutorialBanner._setStatusIcon(self: any, name: string)
	if self._statusName == name then
		return
	end
	self._statusName = name
	for key, holder in self._statusIcons do
		holder.Visible = key == name
	end
end

function TutorialBanner._arrange(self: any)
	local width: number = self._width
	local size: number = self._textSize
	local counterW = math.ceil(measure(self._counter.Text, COUNTER_SIZE).X * 1.1) + 12
	local textX = PAD + STATUS + 10
	local objectiveW = width - textX - counterW - PAD
	local textH = measure(self._objective.Text, size, objectiveW - 10).Y
	local bodyH = math.max(60, math.ceil(textH) + 24 + STRIP)
	self._bodyH = bodyH
	self._objective.TextSize = size
	self._objective.Position = UDim2.fromOffset(textX, 6)
	self._objective.Size = UDim2.fromOffset(objectiveW, bodyH - STRIP - 18)
	self._counter.Position = UDim2.fromOffset(width - PAD - counterW, 6)
	self._counter.Size = UDim2.fromOffset(counterW, bodyH - STRIP - 18)
	self._body.Size = UDim2.fromOffset(width, bodyH)
	self._lip.Size = self._body.Size
	self._track.Position = UDim2.fromOffset(textX, bodyH - STRIP - 9)
	self._track.Size = UDim2.fromOffset(width - textX - PAD, STRIP)
	local hintW = math.min(width, math.ceil(measure(self._hintText.Text, HINT_SIZE).X) + 24)
	self._hint.Size = UDim2.fromOffset(hintW, Layout.HintHeight)
	self._hint.Position = UDim2.fromOffset(width / 2, Layout.BannerTabOverlap + bodyH + B.DepthOffset + Layout.HintGap)
	self.root.Size =
		UDim2.fromOffset(width, Layout.BannerTabOverlap + bodyH + B.DepthOffset + Layout.HintGap + Layout.HintHeight)
end

function TutorialBanner._setProgress(self: any, p: number)
	local fill: Frame = self._fill
	self._progress = p
	if Motion.reduced() then
		Motion.cancelAll(fill)
		fill.Size = UDim2.fromScale(p, 1)
	else
		Motion.tween(fill, "fill", Motion.info(0.25), { Size = UDim2.fromScale(p, 1) })
	end
end

function TutorialBanner._applyContent(self: any, t: Store.Tutorial)
	self._objective.Text = t.objective
	self._counter.Text = counterText(t)
	local done = t.state == "Done"
	self._gradient.Color = if done then A.Fill.Green else A.Fill.Gold
	self._status.BackgroundColor3 = if done then Color3.fromRGB(30, 150, 60) else A.Ink
	self:_setStatusIcon(if done then "Check" else "Flag")
	local hintOn = t.state == "Hint" and t.hint ~= nil and t.hint ~= ""
	if hintOn then
		self._hintText.Text = t.hint :: string
	end
	self:_arrange()
	local p = if t.goal > 0 then math.clamp(t.count / t.goal, 0, 1) else 0
	self:_setProgress(if done then 1 else p)
	if hintOn and not self._hint.Visible then
		self._hint.Visible = true
		self._hintFade:set(1)
		self._hintFade:tween(0, 0.18)
	elseif not hintOn and self._hint.Visible then
		local tw = self._hintFade:tween(1, 0.15)
		if tw then
			tw.Completed:Connect(function(state)
				if state == Enum.PlaybackState.Completed then
					self._hint.Visible = false
				end
			end)
		else
			self._hint.Visible = false
		end
	end
end

function TutorialBanner._set(self: any, t: Store.Tutorial?)
	local previous: Store.Tutorial? = self._tutorial
	self._tutorial = if t then table.clone(t) else nil
	if t == nil then
		self._doneToken += 1
		self:_stopConfetti()
		if self.root.Visible then
			local tw = self._allFade:tween(1, 0.2)
			if tw then
				tw.Completed:Connect(function(state)
					if state == Enum.PlaybackState.Completed and self._tutorial == nil then
						self.root.Visible = false
					end
				end)
			else
				self.root.Visible = false
			end
		end
		return
	end
	local tut = t :: Store.Tutorial
	if not self.root.Visible or previous == nil then
		self.root.Visible = self._wanted
		self._allFade:set(1)
		self._allFade:tween(0, 0.2)
	end
	local newStep = previous ~= nil and previous.step ~= tut.step
	if newStep then
		local content: Frame = self._content
		self._contentFade:set(1)
		self:_applyContent(tut)
		if Motion.reduced() then
			content.Position = UDim2.new()
			self._contentFade:tween(0, 0.18)
		else
			content.Position = UDim2.fromOffset(12, 0)
			Motion.tween(content, "slide", Motion.info(0.22), { Position = UDim2.new() })
			self._contentFade:tween(0, 0.22)
		end
	else
		self:_applyContent(tut)
	end
	local becameDone = tut.state == "Done" and (previous == nil or previous.state ~= "Done" or newStep)
	if becameDone then
		Sounds.play("TutorialDone")
		Motion.pop(self._status, 1.12)
		self:_confettiBurst()
		self._doneToken += 1
		local token = self._doneToken
		local step = tut.step
		task.delay(DONE_SECONDS, function()
			if self._destroyed or token ~= self._doneToken then
				return
			end
			local cb = self._opts.onDoneShown
			if cb then
				cb(step)
			end
		end)
	elseif tut.state ~= "Done" then
		self._doneToken += 1
	end
end

function TutorialBanner._stopConfetti(self: any)
	for _, piece in self._confetti do
		Motion.cancelAll(piece)
		piece.Visible = false
	end
end

function TutorialBanner._confettiBurst(self: any)
	if Motion.reduced() or not self.root.Visible then
		return
	end
	local width: number = self._width
	local cy = Layout.BannerTabOverlap + self._bodyH / 2
	local rng = Random.new(self._doneToken + 7)
	for i, piece in self._confetti do
		Motion.cancelAll(piece)
		local sx = width * (0.15 + 0.7 * (i - 1) / (CONFETTI - 1))
		piece.Position = UDim2.fromOffset(sx, cy)
		piece.Rotation = rng:NextInteger(0, 90)
		piece.BackgroundTransparency = 0
		piece.Visible = true
		local gx = sx + rng:NextNumber(-40, 40)
		local gy = cy + rng:NextNumber(-46, 52)
		Motion.tween(piece, "move", Motion.info(CONFETTI_SECONDS), {
			Position = UDim2.fromOffset(gx, gy),
			Rotation = piece.Rotation + rng:NextNumber(-200, 200),
		})
		local fadeInfo = TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, 0.55)
		local tw = Motion.tween(piece, "fade", fadeInfo, { BackgroundTransparency = 1 })
		tw.Completed:Connect(function(state)
			if state == Enum.PlaybackState.Completed then
				piece.Visible = false
			end
		end)
	end
end

function TutorialBanner.layout(self: any)
	local ctx: Types.Ctx = self._ctx
	local scale = ctx.screen:uiScale()
	self._scale.Scale = scale
	local b = Layout.forProfile(ctx.screen:profile(), scale).banner
	self._width = b.width
	self._textSize = math.max(b.textSize, Tokens.TextSize.Minimum)
	self.root.Position = UDim2.fromOffset(b.cx * scale, b.y * scale) -- layer px
	self:_arrange()
end

function TutorialBanner.setVisible(self: any, on: boolean)
	self._wanted = on
	self.root.Visible = on and self._tutorial ~= nil
	if not on then
		self:_stopConfetti()
	end
end

function TutorialBanner.getDebugState(self: any): { [string]: any }
	local ctx: Types.Ctx = self._ctx
	local t: Store.Tutorial? = self._tutorial
	local confetti = 0
	for _, piece in self._confetti do
		if piece.Visible then
			confetti += 1
		end
	end
	local pos, size = ctx.screen:rectOf(self._body)
	return {
		visible = self.root.Visible,
		state = if t then t.state else nil,
		step = if t then t.step else nil,
		objective = self._objective.Text,
		objectiveSize = self._objective.TextSize,
		counter = self._counter.Text,
		counterSize = self._counter.TextSize,
		hintSize = self._hintText.TextSize,
		progress = self._progress,
		hintVisible = self._hint.Visible,
		hint = self._hintText.Text,
		confettiVisible = confetti,
		confettiPool = CONFETTI,
		bodyHeight = self._bodyH,
		width = self._width,
		objectiveFits = self._objective.TextFits,
		devicePos = pos,
		deviceSize = size,
		reservedOverlap = ctx.screen:overlapsReserved(pos, size),
	}
end

function TutorialBanner.destroy(self: any)
	if self._destroyed then
		return
	end
	self._destroyed = true
	self._trove:Destroy()
end

return TutorialBanner
