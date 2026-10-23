--!strict
-- Home HUD: preview Settings panel (Lane 3 preview, HUD rebuild 2026-10-22; ledger H-14).
-- Every control does exactly what it says for this session only; nothing is saved and no
-- schema is added ("Preview: not saved" is a harness caption on the card).
--
--   Music          slider -> store.settings.music via Home/MusicSetting, which sets the preview
--                  music SoundGroup "Lane3PreviewMusic" (0 while the Home Music toggle is Off;
--                  the line under the label says so)
--   Sound effects  slider -> store.settings.sfx -> the preview SoundGroup "Lane3PreviewUI"
--   Reduce motion  three choices -> Motion.setOverride(nil | true | false):
--                  "Use Roblox setting" (default, follows GuiService.ReducedMotionEnabled),
--                  "On", "Off". The line under the label shows the effective state.
--
-- Look (Arcade kit family): a deep navy card with the thick dark boundary and a shallow lip, a
-- big white outlined "Settings" title, a red labelled "Close" button (kit Small, the same family
-- as the Home Settings rectangle), white outlined row labels, chunky sliders (dark track, green
-- fill, white knob with a dark outline) and segment buttons (gold when chosen, with a tick, so
-- the state is not colour alone).
--
-- Input: sliders take drag and tap (mouse and touch) and, while selected with a gamepad or
-- keyboard navigation, Left / Right (arrow keys, D-pad) in 10% steps (ContextActionService,
-- bound only while the slider is selected). Close, Escape and ButtonB close the panel (Back is
-- bound only while open). Tapping the dim backdrop also closes it. Opening selects the first
-- control when the last input was a gamepad (or keyboard navigation was active); closing returns
-- the selection to the opener (the Home Settings button) when it is still on screen, otherwise
-- clears it. Gamepad selection is kept inside the card (SelectionGroup with Stop behaviours).
--
-- Layout: centred card with wide rows on every (landscape) profile. Hit targets are 48 px or larger.
--
-- API: SettingsPanel.new(ctx, { onClosed: (() -> ())? }?) -> SettingsPanel
--   :open(opener: GuiObject?)  :close()  :isOpen() -> boolean
--   :layout()  :setVisible(on)  :destroy()  :getDebugState()
--   :getControls() -> { music, sfx, motionRoblox, motionOn, motionOff, close }  (test hook)

local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextService = game:GetService("TextService")
local UserInputService = game:GetService("UserInputService")

local Arcade = require(script.Parent.Parent.Arcade)
local Fade = require(script.Parent.Fade)
local IconArt = require(script.Parent.IconArt)
local Layout = require(script.Parent.Layout)
local Motion = require(script.Parent.Parent.Motion)
local MusicSetting = require(script.Parent.MusicSetting)
local PreviewTokens = require(script.Parent.Parent.PreviewTokens)
local Sounds = require(script.Parent.Parent.Sounds)
local Tokens = require(ReplicatedStorage.Shared.UI.Tokens)
local Trove = require(ReplicatedStorage.Packages.Trove)
local Types = require(script.Parent.Types)

local A = PreviewTokens.Arcade
local B = A.Button
local PM = PreviewTokens.Motion
local make = Arcade.make

local OVERRIDE = "Lane3ReducedMotionOverride"
local BACK_ACTION = "Lane3PreviewSettingsBack"
local SLIDER_ACTION = "Lane3PreviewSettingsSlider"
local PAD = 20
local KNOB = 30
local LABEL = Tokens.TextSize.Value
local VALUE = Tokens.TextSize.Minimum
local TITLE_H = 64
-- TOKEN CANDIDATE: the settings card body (deep navy) and an unchosen segment.
local CARD_FILL = ColorSequence.new(Color3.fromRGB(58, 74, 126), Color3.fromRGB(28, 36, 72))
local SEGMENT_OFF = Color3.fromRGB(70, 86, 140)

export type Options = { onClosed: (() -> ())? }

export type SettingsPanel = {
	root: Frame,
	open: (self: SettingsPanel, opener: GuiObject?) -> (),
	close: (self: SettingsPanel) -> (),
	isOpen: (self: SettingsPanel) -> boolean,
	layout: (self: SettingsPanel) -> (),
	setVisible: (self: SettingsPanel, on: boolean) -> (),
	destroy: (self: SettingsPanel) -> (),
	getControls: (self: SettingsPanel) -> { [string]: GuiObject },
	getDebugState: (self: SettingsPanel) -> { [string]: any },
}

type Slider = {
	hit: TextButton,
	track: Frame,
	fill: Frame,
	knob: Frame,
	value: number,
	set: (v: number, fromUser: boolean) -> (),
}

type Segment = { button: TextButton, choice: string, tick: Frame, text: TextLabel, gradient: UIGradient }

local SettingsPanel = {}
SettingsPanel.__index = SettingsPanel

local function measure(text: string, size: number): number
	return TextService:GetTextSize(text, size, Enum.Font.FredokaOne, Vector2.new(4096, 4096)).X
end

local function isGamepad(t: Enum.UserInputType): boolean
	return t.Name:sub(1, 7) == "Gamepad"
end

local function selectionRing(parent: GuiObject): Frame
	local ring = make("Frame", {
		Name = "SelectionRing",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 10, 1, 10),
		Position = UDim2.fromOffset(-5, -5),
		Visible = false,
		Parent = parent,
	})
	Arcade.corner(ring, B.Radius + 5)
	Arcade.outline(ring, 3, Color3.new(1, 1, 1))
	return ring
end

local function choiceNow(): string
	local player = Players.LocalPlayer
	local v = player and player:GetAttribute(OVERRIDE)
	if v == true then
		return "On"
	elseif v == false then
		return "Off"
	end
	return "Roblox"
end

local function pct(v: number): string
	return string.format("%d%%", math.floor(v * 100 + 0.5))
end

function SettingsPanel.new(ctx: Types.Ctx, opts: Options?): SettingsPanel
	local self = setmetatable({}, SettingsPanel) :: any
	self._trove = Trove.new()
	self._ctx = ctx
	self._opts = opts or {}
	self._open = false
	self._opener = nil :: GuiObject?
	self._kind = ""
	self._content = self._trove:Extend()
	self._sliders = {} :: { [string]: Slider }
	self._segments = {} :: { Segment }
	self._dragging = nil :: InputObject?
	self._dragSlider = nil :: Slider?
	self._closeToken = 0

	local root = self._trove:Add(make("Frame", {
		Name = "SettingsPanel",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(100, 100),
		Visible = false,
		ZIndex = 40,
		Parent = ctx.layer,
	}))
	self.root = root
	self._scale = make("UIScale", { Name = "HudScale", Scale = ctx.screen:uiScale(), Parent = root })
	local scrim = make("TextButton", {
		Name = "Backdrop",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = A.Ink,
		BackgroundTransparency = 0.5,
		AutoButtonColor = false,
		Selectable = false,
		Text = "",
		ZIndex = 40,
		Parent = root,
	})
	self._trove:Connect(scrim.Activated, function()
		self:close()
	end)

	self._trove:Connect(UserInputService.InputChanged, function(input: InputObject)
		local slider: Slider? = self._dragSlider
		local drag: InputObject? = self._dragging
		if not slider or not drag then
			return
		end
		local mouseDrag = drag.UserInputType == Enum.UserInputType.MouseButton1
			and input.UserInputType == Enum.UserInputType.MouseMovement
		if input == drag or mouseDrag then
			self:_setFromX(slider, input.Position.X)
		end
	end)
	self._trove:Connect(UserInputService.InputEnded, function(input: InputObject)
		local drag: InputObject? = self._dragging
		if drag and (input == drag or input.UserInputType == drag.UserInputType) then
			self:_endDrag()
		end
	end)
	self._trove:Add(Motion.onReducedChanged(function()
		self:_refreshMotion()
	end))
	self._trove:Add(ctx.store:subscribe("settings", function()
		self:_refreshSound()
	end))
	self._trove:Add(function()
		ContextActionService:UnbindAction(BACK_ACTION)
		ContextActionService:UnbindAction(SLIDER_ACTION)
		if self._fade then
			self._fade:destroy()
		end
	end)
	self._trove:Connect(ctx.screen.Changed, function()
		self:layout()
	end)
	self:layout()
	return self :: SettingsPanel
end

function SettingsPanel._endDrag(self: any)
	local slider: Slider? = self._dragSlider
	self._dragging = nil
	self._dragSlider = nil
	if slider and slider == self._sliders.sfx then
		Sounds.play("Tap") -- lets the player hear the new effects level
	end
end

function SettingsPanel._setFromX(_self: any, slider: Slider, x: number)
	local left = slider.track.AbsolutePosition.X
	local width = slider.track.AbsoluteSize.X
	if width <= 0 then
		return
	end
	local v = math.clamp((x - left) / width, 0, 1)
	slider.set(math.floor(v * 20 + 0.5) / 20, true)
end

function SettingsPanel._makeSlider(
	self: any,
	parent: Instance,
	name: string,
	width: number,
	initial: number,
	onChange: (number) -> ()
): Slider
	local trove = self._content
	local hit = make("TextButton", {
		Name = name .. "Slider",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(width, Tokens.Touch.Minimum),
		AutoButtonColor = false,
		Selectable = true,
		Text = "",
		ZIndex = 44,
		Parent = parent,
	})
	hit.SelectionImageObject = selectionRing(hit)
	hit.NextSelectionLeft = hit
	hit.NextSelectionRight = hit
	local track = make("Frame", {
		Name = "Track",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, KNOB / 2, 0.5, 0),
		Size = UDim2.new(1, -KNOB, 0, 14),
		BackgroundColor3 = A.Ink,
		ZIndex = 45,
		Parent = hit,
	})
	Arcade.corner(track, 7)
	Arcade.outline(track, 2, Color3.new(1, 1, 1))
	local fill = make("Frame", {
		Name = "Fill",
		Size = UDim2.fromScale(initial, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		ZIndex = 46,
		Parent = track,
	})
	Arcade.corner(fill, 7)
	make("UIGradient", { Color = A.Fill.Green, Rotation = 90, Parent = fill })
	local knob = make("Frame", {
		Name = "Knob",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(initial, 0.5),
		Size = UDim2.fromOffset(KNOB, KNOB),
		BackgroundColor3 = Color3.new(1, 1, 1),
		ZIndex = 47,
		Parent = track,
	})
	Arcade.corner(knob, B.Radius)
	Arcade.outline(knob, "Button")
	local slider: Slider
	slider = {
		hit = hit,
		track = track,
		fill = fill,
		knob = knob,
		value = initial,
		set = function(v: number, fromUser: boolean)
			local clamped = math.clamp(v, 0, 1)
			slider.value = clamped
			fill.Size = UDim2.fromScale(clamped, 1)
			knob.Position = UDim2.fromScale(clamped, 0.5)
			if fromUser then
				onChange(clamped)
			end
		end,
	}
	trove:Connect(hit.InputBegan, function(input: InputObject)
		local t = input.UserInputType
		if t == Enum.UserInputType.MouseButton1 or t == Enum.UserInputType.Touch then
			self._dragging = input
			self._dragSlider = slider
			self:_setFromX(slider, input.Position.X)
		end
	end)
	trove:Connect(hit.SelectionGained, function()
		ContextActionService:BindActionAtPriority(
			SLIDER_ACTION,
			function(_name: string, state: Enum.UserInputState, input: InputObject)
				if state ~= Enum.UserInputState.Begin then
					return Enum.ContextActionResult.Sink
				end
				local k = input.KeyCode
				local step = if k == Enum.KeyCode.Left or k == Enum.KeyCode.DPadLeft then -0.1 else 0.1
				slider.set(math.floor((slider.value + step) * 10 + 0.5) / 10, true)
				if slider == self._sliders.sfx then
					Sounds.play("Tap")
				end
				return Enum.ContextActionResult.Sink
			end,
			false,
			Enum.ContextActionPriority.High.Value,
			Enum.KeyCode.Left,
			Enum.KeyCode.Right,
			Enum.KeyCode.DPadLeft,
			Enum.KeyCode.DPadRight
		)
	end)
	trove:Connect(hit.SelectionLost, function()
		ContextActionService:UnbindAction(SLIDER_ACTION)
	end)
	return slider
end

function SettingsPanel._choose(self: any, choice: string)
	if choice == "On" then
		Motion.setOverride(true)
	elseif choice == "Off" then
		Motion.setOverride(false)
	else
		Motion.setOverride(nil)
	end
	self:_refreshMotion()
end

function SettingsPanel._refreshMotion(self: any)
	local choice = choiceNow()
	for _, seg in self._segments do
		local on = seg.choice == choice
		seg.gradient.Enabled = on
		seg.button.BackgroundColor3 = if on then Color3.new(1, 1, 1) else SEGMENT_OFF
		seg.tick.Visible = on
	end
	if self._motionValue then
		self._motionValue.Text = "Now: " .. (if Motion.reduced() then "reduced" else "full motion")
	end
end

function SettingsPanel._refreshSound(self: any)
	local s = self._ctx.store:get().settings
	local music: Slider? = self._sliders.music
	if music then
		music.set(s.music, false)
	end
	local sfx: Slider? = self._sliders.sfx
	if sfx then
		sfx.set(s.sfx, false)
	end
	if self._musicValue then
		self._musicValue.Text = if s.musicOn == false then pct(s.music) .. " · Music is Off" else pct(s.music)
	end
	if self._sfxValue then
		self._sfxValue.Text = pct(s.sfx)
	end
end

-- One labelled row; returns the control frame, the value label and the row height.
function SettingsPanel._row(
	_self: any,
	parent: Instance,
	order: number,
	icons: { string },
	text: string,
	cardInner: number
): (Frame, TextLabel, number)
	local rowH = 60
	local row = make("Frame", {
		Name = "Row" .. order,
		BackgroundTransparency = 1,
		LayoutOrder = order,
		Size = UDim2.fromOffset(cardInner, rowH),
		ZIndex = 42,
		Parent = parent,
	})
	local iconHolder = make("Frame", {
		Name = "Icon",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 2),
		Size = UDim2.fromOffset(30, 30),
		ZIndex = 43,
		Parent = row,
	})
	IconArt.draw(iconHolder, icons)
	local label = Arcade.text(row, {
		text = text,
		role = "Label",
		name = "Label",
		size = LABEL,
		xAlign = Enum.TextXAlignment.Left,
		z = 43,
	})
	label.Position = UDim2.fromOffset(38, 0)
	label.Size = UDim2.fromOffset(math.ceil(measure(text, LABEL)) + 12, 34)
	local value = Arcade.text(row, {
		text = "",
		role = "Small",
		name = "Value",
		size = VALUE,
		colour = Color3.fromRGB(214, 226, 255),
		z = 43,
	})
	local labelColumn = 210
	value.Position = UDim2.fromOffset(38, 34)
	value.Size = UDim2.fromOffset(labelColumn - 40, 22)
	value.TextXAlignment = Enum.TextXAlignment.Left
	local control = make("Frame", {
		Name = "Control",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(labelColumn, 6),
		Size = UDim2.fromOffset(cardInner - labelColumn, 48),
		ZIndex = 43,
		Parent = row,
	})
	return control, value, rowH
end

function SettingsPanel._build(self: any, cardWidth: number)
	local ctx: Types.Ctx = self._ctx
	local selected = GuiService.SelectedObject
	local hadSelection = selected ~= nil and selected:IsDescendantOf(self.root)
	self._content:Clean()
	table.clear(self._sliders)
	table.clear(self._segments)
	if self._fade then
		self._fade:destroy()
		self._fade = nil
	end
	local inner = cardWidth - 2 * PAD
	local holder = self._content:Add(make("Frame", {
		Name = "CardHolder",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(cardWidth, 100),
		BackgroundTransparency = 1,
		ZIndex = 41,
		Parent = self.root,
	}))
	self._pop = make("UIScale", { Name = "Open", Scale = 1, Parent = holder })
	local lip = make("Frame", {
		Name = "Lip",
		Position = UDim2.fromOffset(0, B.DepthOffset + 2),
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = A.Ink,
		ZIndex = 41,
		Parent = holder,
	})
	Arcade.corner(lip, B.Radius + 3)
	local card = make("Frame", {
		Name = "Card",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		ZIndex = 41,
		SelectionGroup = true,
		SelectionBehaviorUp = Enum.SelectionBehavior.Stop,
		SelectionBehaviorDown = Enum.SelectionBehavior.Stop,
		SelectionBehaviorLeft = Enum.SelectionBehavior.Stop,
		SelectionBehaviorRight = Enum.SelectionBehavior.Stop,
		Parent = holder,
	})
	Arcade.corner(card, B.Radius + 3)
	Arcade.outline(card, "Button")
	make("UIGradient", { Color = CARD_FILL, Rotation = 90, Parent = card })
	self._card = card
	self._holder = holder

	local title = Arcade.text(card, {
		text = "Settings",
		role = "Display",
		name = "Title",
		xAlign = Enum.TextXAlignment.Left,
		z = 42,
	})
	title.Position = UDim2.fromOffset(PAD, 12)
	title.Size = UDim2.new(1, -2 * PAD - B.SmallW - 8, 0, 44)
	local close = Arcade.button(card, {
		name = "Close",
		label = "Close",
		fill = "Settings",
		size = "Small",
		sound = "Tap",
		position = UDim2.new(1, -14, 0, 10),
		anchor = Vector2.new(1, 0),
		onActivate = function()
			self:close()
		end,
	})
	self._content:Add(close.trove)
	close.root.ZIndex = 44
	self._closeButton = close.body

	local list = make("Frame", {
		Name = "Rows",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(PAD, TITLE_H + 6),
		Size = UDim2.fromOffset(inner, 100),
		ZIndex = 42,
		Parent = card,
	})
	local gap = 10
	make("UIListLayout", {
		FillDirection = Enum.FillDirection.Vertical,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, gap),
		Parent = list,
	})
	local total = 0
	local settings = ctx.store:get().settings

	local musicControl, musicValue, h1 = self:_row(list, 1, { "Music" }, "Music", inner)
	self._musicValue = musicValue
	local music = self:_makeSlider(musicControl, "Music", musicControl.Size.X.Offset, settings.music, function(v)
		MusicSetting.setLevel(ctx.store, v)
	end)
	self._sliders.music = music
	total += h1 + gap

	local sfxControl, sfxValue, h2 = self:_row(list, 2, { "Speaker" }, "Sound effects", inner)
	self._sfxValue = sfxValue
	local sfx = self:_makeSlider(sfxControl, "Sfx", sfxControl.Size.X.Offset, settings.sfx, function(v)
		MusicSetting.setSfx(ctx.store, v)
	end)
	self._sliders.sfx = sfx
	total += h2 + gap

	local motionControl, motionValue, h3 = self:_row(list, 3, { "Motion" }, "Reduce motion", inner)
	self._motionValue = motionValue
	local choices = { { "Roblox", "Use Roblox setting" }, { "On", "On" }, { "Off", "Off" } }
	local x = 0
	for _, pair in choices do
		local label = pair[2]
		local w = math.max(72, math.ceil(measure(label, VALUE)) + 20 + 26)
		local b = make("TextButton", {
			Name = "Motion" .. pair[1],
			Position = UDim2.fromOffset(x, 0),
			Size = UDim2.fromOffset(w, Tokens.Touch.Minimum),
			BackgroundColor3 = SEGMENT_OFF,
			AutoButtonColor = false,
			Selectable = true,
			Text = "",
			ZIndex = 44,
			Parent = motionControl,
		})
		Arcade.corner(b)
		Arcade.outline(b, "Button")
		local g = make("UIGradient", { Color = A.Fill.Gold, Rotation = 90, Enabled = false, Parent = b })
		b.SelectionImageObject = selectionRing(b)
		local tick = make("Frame", {
			Name = "Tick",
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 6, 0.5, 0),
			Size = UDim2.fromOffset(20, 20),
			BackgroundTransparency = 1,
			Visible = false,
			ZIndex = 45,
			Parent = b,
		})
		IconArt.draw(tick, { "Check" })
		local t = Arcade.text(b, { text = label, role = "Small", name = "Text", size = VALUE, z = 45 })
		t.Position = UDim2.fromOffset(26, 0)
		t.Size = UDim2.new(1, -30, 1, 0)
		local choice = pair[1]
		self._content:Connect(b.Activated, function()
			Sounds.play("Tap")
			self:_choose(choice)
		end)
		table.insert(self._segments, { button = b, choice = choice, tick = tick, text = t, gradient = g })
		x += w + 8
	end
	total += h3

	local footer = Arcade.text(card, {
		text = "Preview: not saved",
		role = "Small",
		name = "PreviewNote", -- harness caption (hidden in player-facing captures)
		size = VALUE,
		colour = Color3.fromRGB(255, 236, 140),
		xAlign = Enum.TextXAlignment.Left,
		z = 42,
	})
	footer:SetAttribute("PreviewCaption", true)
	footer.Position = UDim2.fromOffset(PAD, TITLE_H + 6 + total + 10)
	footer.Size = UDim2.new(1, -2 * PAD, 0, 22)
	list.Size = UDim2.fromOffset(inner, total)
	local cardH = TITLE_H + 6 + total + 10 + 22 + 16
	holder.Size = UDim2.fromOffset(cardWidth, cardH)
	self._cardHeight = cardH

	-- Selection order: music -> sfx -> motion choices -> close.
	music.hit.NextSelectionDown = sfx.hit
	sfx.hit.NextSelectionUp = music.hit
	sfx.hit.NextSelectionDown = self._segments[1].button
	for i, seg in self._segments do
		seg.button.NextSelectionUp = sfx.hit
		seg.button.NextSelectionDown = close.body
		seg.button.NextSelectionLeft = if i > 1 then self._segments[i - 1].button else seg.button
		seg.button.NextSelectionRight = if i < #self._segments then self._segments[i + 1].button else seg.button
	end
	close.body.NextSelectionDown = music.hit
	close.body.NextSelectionUp = self._segments[1].button
	music.hit.NextSelectionUp = close.body

	self._fade = Fade.capture(self.root)
	self:_refreshMotion()
	self:_refreshSound()
	if hadSelection and self._open then
		GuiService.SelectedObject = music.hit
	end
end

function SettingsPanel.layout(self: any)
	local ctx: Types.Ctx = self._ctx
	local scale = ctx.screen:uiScale()
	self._scale.Scale = scale
	local L = Layout.forProfile(ctx.screen:profile(), scale)
	-- the root is the safe area in design px, so after HudScale it fills the layer exactly
	self.root.Size = UDim2.fromOffset(L.safeW, L.safeH)
	local width = math.min(620, L.safeW - 24)
	local kind = string.format("Wide:%d", width)
	if kind ~= self._kind then
		self._kind = kind
		self:_build(width)
		if self._fade then
			self._fade:set(if self._open then 0 else 1)
		end
	end
end

local function lastInputIsGamepad(): boolean
	return isGamepad(UserInputService:GetLastInputType())
end

function SettingsPanel.open(self: any, opener: GuiObject?)
	if self._open then
		return
	end
	self._open = true
	self._opener = opener
	self._closeToken += 1
	local useSelection = lastInputIsGamepad() or GuiService.SelectedObject ~= nil
	self:_refreshSound()
	self:_refreshMotion()
	self.root.Visible = true
	Sounds.play("Open")
	self._fade:set(1)
	self._fade:tween(0, PM.Panel)
	local pop: UIScale = self._pop
	if Motion.reduced() then
		pop.Scale = 1
	else
		pop.Scale = 0.92
		Motion.tween(pop, "open", Motion.info(PM.Panel, Enum.EasingStyle.Back), { Scale = 1 })
	end
	ContextActionService:BindActionAtPriority(BACK_ACTION, function(_name: string, state: Enum.UserInputState)
		if state == Enum.UserInputState.Begin then
			self:close()
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.ContextActionPriority.High.Value, Enum.KeyCode.Escape, Enum.KeyCode.ButtonB)
	if useSelection then
		GuiService.SelectedObject = self._sliders.music.hit
	end
end

function SettingsPanel.close(self: any)
	if not self._open then
		return
	end
	self._open = false
	self:_endDrag()
	ContextActionService:UnbindAction(BACK_ACTION)
	ContextActionService:UnbindAction(SLIDER_ACTION)
	local selected = GuiService.SelectedObject
	local hadSelection = (selected ~= nil and selected:IsDescendantOf(self.root)) or lastInputIsGamepad()
	if selected ~= nil and selected:IsDescendantOf(self.root) then
		GuiService.SelectedObject = nil
	end
	Sounds.play("Close")
	self._closeToken += 1
	local token = self._closeToken
	local tw = self._fade:tween(1, PM.PanelOut)
	local function hide()
		if token == self._closeToken and not self._open then
			self.root.Visible = false
		end
	end
	if tw then
		tw.Completed:Connect(function(state)
			if state == Enum.PlaybackState.Completed then
				hide()
			end
		end)
	else
		hide()
	end
	local opener: GuiObject? = self._opener
	if hadSelection and opener and opener.Visible and opener:IsDescendantOf(game) then
		GuiService.SelectedObject = opener
	end
	local cb = self._opts.onClosed
	if cb then
		cb()
	end
end

function SettingsPanel.isOpen(self: any): boolean
	return self._open
end

function SettingsPanel.setVisible(self: any, on: boolean)
	if not on and self._open then
		self:close()
	end
end

function SettingsPanel.getControls(self: any): { [string]: GuiObject }
	local controls: { [string]: GuiObject } = {
		music = self._sliders.music.hit,
		sfx = self._sliders.sfx.hit,
		close = self._closeButton,
	}
	for _, seg in self._segments do
		controls["motion" .. seg.choice] = seg.button
	end
	return controls
end

function SettingsPanel.getDebugState(self: any): { [string]: any }
	local ctx: Types.Ctx = self._ctx
	local selected = GuiService.SelectedObject
	local pos, size = ctx.screen:rectOf(self._card)
	local player = Players.LocalPlayer
	local s = ctx.store:get().settings
	return {
		open = self._open,
		visible = self.root.Visible,
		layout = self._kind,
		music = Sounds.musicGroup().Volume,
		sfx = Sounds.group().Volume,
		musicSetting = s.music,
		musicOn = s.musicOn ~= false,
		sfxSetting = s.sfx,
		musicSlider = self._sliders.music.value,
		sfxSlider = self._sliders.sfx.value,
		motionChoice = choiceNow(),
		override = if player then player:GetAttribute(OVERRIDE) else nil,
		reduced = Motion.reduced(),
		selected = if selected then selected:GetFullName() else nil,
		selectedInside = selected ~= nil and selected:IsDescendantOf(self.root),
		opener = if self._opener then self._opener:GetFullName() else nil,
		dragging = self._dragging ~= nil,
		cardDevicePos = pos,
		cardDeviceSize = size,
		cardHeight = self._cardHeight,
	}
end

function SettingsPanel.destroy(self: any)
	if self._open then
		self._open = false
		local selected = GuiService.SelectedObject
		if selected ~= nil and selected:IsDescendantOf(self.root) then
			GuiService.SelectedObject = nil
		end
	end
	self._trove:Destroy()
end

return SettingsPanel
