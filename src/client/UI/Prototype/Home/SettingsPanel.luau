--!strict
-- Home HUD: preview Settings panel (Lane 3 preview). Every control does exactly what it says
-- for this session only; nothing is saved ("Preview: not saved" is shown on the card).
--
--   Music          slider -> Sounds.musicGroup().Volume (preview SoundGroup "Lane3PreviewMusic")
--   Sound effects  slider -> Sounds.group().Volume      (preview SoundGroup "Lane3PreviewUI")
--   Reduce motion  three choices -> Motion.setOverride(nil | true | false):
--                  "Use Roblox setting" (default, follows GuiService.ReducedMotionEnabled),
--                  "On", "Off". The line under the label shows the effective state.
--
-- Input: sliders take drag and tap (mouse and touch) and, while selected with a gamepad or
-- keyboard navigation, Left / Right (arrow keys, D-pad) in 10% steps (ContextActionService,
-- bound only while the slider is selected). The close button (X), Escape and ButtonB close the
-- panel (Back is bound only while open; Escape may also open the Roblox menu, which this
-- preview cannot suppress). Tapping the dim backdrop also closes it. Opening selects the first
-- control when the last input was a gamepad (or keyboard navigation was active); closing returns
-- the selection to the opener button when it is still on screen, and otherwise clears it.
-- Gamepad selection is kept inside the card (SelectionGroup with Stop behaviours).
--
-- Layout: a centred cream card with a navy "SETTINGS" title. Wide rows (label left, control
-- right) on Desktop, Tablet and PhoneLandscape; stacked rows (label above control) on
-- PhonePortrait. Hit targets are 48 px or larger.
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

local Fade = require(script.Parent.Fade)
local Gloss = require(script.Parent.Parent.Gloss)
local Icons = require(script.Parent.Parent.Icons)
local Layout = require(script.Parent.Layout)
local Motion = require(script.Parent.Parent.Motion)
local PreviewTokens = require(script.Parent.Parent.PreviewTokens)
local Sounds = require(script.Parent.Parent.Sounds)
local Tokens = require(ReplicatedStorage.Shared.UI.Tokens)
local Trove = require(ReplicatedStorage.Packages.Trove)
local Types = require(script.Parent.Types)

local C = PreviewTokens.Color
local PM = PreviewTokens.Motion
local make = Gloss.make

local OVERRIDE = "Lane3ReducedMotionOverride"
local BACK_ACTION = "Lane3PreviewSettingsBack"
local SLIDER_ACTION = "Lane3PreviewSettingsSlider"
local PAD = 20
local KNOB = 28
local LABEL = 20
local VALUE = 16

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

type Segment = { button: TextButton, choice: string, tick: Frame, text: TextLabel }

local SettingsPanel = {}
SettingsPanel.__index = SettingsPanel

local function measure(text: string, size: number): number
	return TextService:GetTextSize(text, size, Enum.Font.FredokaOne, Vector2.new(4096, 4096)).X
end

local function isGamepad(t: Enum.UserInputType): boolean
	return t.Name:sub(1, 7) == "Gamepad"
end

local function selectionRing(parent: GuiObject, radius: number): Frame
	local ring = make("Frame", {
		Name = "SelectionRing",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 8, 1, 8),
		Position = UDim2.fromOffset(-4, -4),
		Visible = false,
		Parent = parent,
	})
	Gloss.corner(ring, radius + 4)
	Gloss.stroke(ring, 3, C.Ink)
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
		BackgroundColor3 = C.Ink,
		BackgroundTransparency = 0.55,
		AutoButtonColor = false,
		Selectable = false,
		Text = "",
		ZIndex = 40,
		Parent = root,
	})
	self._scrim = scrim
	self._trove:Connect(scrim.Activated, function()
		self:close()
	end)

	-- Drag tracking (connected once; does nothing unless a drag is active).
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
		Size = UDim2.fromOffset(width, 48),
		AutoButtonColor = false,
		Selectable = true,
		Text = "",
		ZIndex = 44,
		Parent = parent,
	})
	hit.SelectionImageObject = selectionRing(hit, 14)
	hit.NextSelectionLeft = hit
	hit.NextSelectionRight = hit
	local track = make("Frame", {
		Name = "Track",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, KNOB / 2, 0.5, 0),
		Size = UDim2.new(1, -KNOB, 0, 12),
		BackgroundColor3 = C.PanelShade,
		BorderSizePixel = 0,
		ZIndex = 45,
		Parent = hit,
	})
	Gloss.corner(track, 6)
	Gloss.stroke(track, 2)
	local fill = make("Frame", {
		Name = "Fill",
		Size = UDim2.fromScale(initial, 1),
		BackgroundColor3 = C.GarageDeep,
		BorderSizePixel = 0,
		ZIndex = 46,
		Parent = track,
	})
	Gloss.corner(fill, 6)
	local knob = make("Frame", {
		Name = "Knob",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(initial, 0.5),
		Size = UDim2.fromOffset(KNOB, KNOB),
		BackgroundColor3 = C.White,
		BorderSizePixel = 0,
		ZIndex = 47,
		Parent = track,
	})
	Gloss.corner(knob, KNOB / 2)
	Gloss.stroke(knob, 3)
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
		seg.button.BackgroundColor3 = if on then C.Ink else C.PanelShade
		seg.text.TextColor3 = if on then C.White else C.Ink
		seg.tick.Visible = on
	end
	if self._motionValue then
		self._motionValue.Text = "Now: " .. (if Motion.reduced() then "reduced" else "full motion")
	end
end

-- One labelled row; returns the frame that holds the control and the value label.
function SettingsPanel._row(
	_self: any,
	parent: Instance,
	order: number,
	icon: Icons.Name,
	text: string,
	stacked: boolean,
	cardInner: number
): (Frame, TextLabel, number)
	local rowH = if stacked then 30 + 6 + 48 else 56
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
		Position = UDim2.fromOffset(0, if stacked then 1 else 4),
		Size = UDim2.fromOffset(28, 28),
		ZIndex = 43,
		Parent = row,
	})
	Icons.draw(iconHolder, icon, C.White)
	make("TextLabel", {
		Name = "Label",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(36, if stacked then 0 else 2),
		Size = UDim2.fromOffset(math.ceil(measure(text, LABEL)) + 4, 30),
		FontFace = Tokens.font(),
		Text = text,
		TextSize = LABEL,
		TextColor3 = C.Ink,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 43,
		Parent = row,
	})
	local value = make("TextLabel", {
		Name = "Value",
		BackgroundTransparency = 1,
		FontFace = Tokens.font(),
		Text = "",
		TextSize = VALUE,
		TextColor3 = C.InkSoft,
		ZIndex = 43,
		Parent = row,
	})
	local labelColumn = 200
	if stacked then
		value.AnchorPoint = Vector2.new(1, 0)
		value.Position = UDim2.new(1, 0, 0, 4)
		value.Size = UDim2.fromOffset(150, 24)
		value.TextXAlignment = Enum.TextXAlignment.Right
	else
		value.Position = UDim2.fromOffset(36, 30)
		value.Size = UDim2.fromOffset(labelColumn - 40, 22)
		value.TextXAlignment = Enum.TextXAlignment.Left
	end
	local control = make("Frame", {
		Name = "Control",
		BackgroundTransparency = 1,
		Position = if stacked then UDim2.fromOffset(0, 36) else UDim2.fromOffset(labelColumn, 4),
		Size = UDim2.fromOffset(if stacked then cardInner else cardInner - labelColumn, 48),
		ZIndex = 43,
		Parent = row,
	})
	return control, value, rowH
end

function SettingsPanel._build(self: any, stacked: boolean, cardWidth: number)
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
	local card = self._content:Add(make("Frame", {
		Name = "Card",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(cardWidth, 100),
		BackgroundColor3 = C.Panel,
		BorderSizePixel = 0,
		ZIndex = 41,
		SelectionGroup = true,
		SelectionBehaviorUp = Enum.SelectionBehavior.Stop,
		SelectionBehaviorDown = Enum.SelectionBehavior.Stop,
		SelectionBehaviorLeft = Enum.SelectionBehavior.Stop,
		SelectionBehaviorRight = Enum.SelectionBehavior.Stop,
		Parent = self.root,
	}))
	Gloss.corner(card, 20)
	Gloss.stroke(card, 3)
	local shadow = Gloss.shadow(card, 20)
	self._content:Add(shadow)
	self._card = card
	self._cardShadow = shadow
	self._pop = make("UIScale", { Name = "Open", Scale = 1, Parent = card })

	make("TextLabel", {
		Name = "Title",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(PAD, 12),
		Size = UDim2.new(1, -2 * PAD - 56, 0, 40),
		FontFace = Tokens.font(),
		Text = "SETTINGS",
		TextSize = 30,
		TextColor3 = C.Ink,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 42,
		Parent = card,
	})
	local close = Gloss.button(card, {
		name = "Close",
		size = Vector2.new(48, 48),
		position = UDim2.new(1, -12, 0, 10),
		anchor = Vector2.new(1, 0),
		light = C.SettingsLight,
		deep = C.SettingsDeep,
		radius = 14,
		icon = function(holder: Frame)
			Icons.draw(holder, "Close")
		end,
		iconSize = 26,
		sound = "Tap",
		onActivate = function()
			self:close()
		end,
	})
	self._content:Add(close.trove)
	self._closeButton = close.body

	local list = make("Frame", {
		Name = "Rows",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(PAD, 66),
		Size = UDim2.fromOffset(inner, 100),
		ZIndex = 42,
		Parent = card,
	})
	make("UIListLayout", {
		FillDirection = Enum.FillDirection.Vertical,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, if stacked then 14 else 10),
		Parent = list,
	})
	local total = 0
	local gap = if stacked then 14 else 10

	-- Music
	local musicControl, musicValue, h1 = self:_row(list, 1, "Music", "Music", stacked, inner)
	local musicGroup = Sounds.musicGroup()
	local music = self:_makeSlider(musicControl, "Music", musicControl.Size.X.Offset, musicGroup.Volume, function(v)
		Sounds.musicGroup().Volume = v
		musicValue.Text = string.format("%d%%", math.floor(v * 100 + 0.5))
	end)
	musicValue.Text = string.format("%d%%", math.floor(musicGroup.Volume * 100 + 0.5))
	self._sliders.music = music
	total += h1 + gap

	-- Sound effects
	local sfxControl, sfxValue, h2 = self:_row(list, 2, "Speaker", "Sound effects", stacked, inner)
	local sfxGroup = Sounds.group()
	local sfx = self:_makeSlider(sfxControl, "Sfx", sfxControl.Size.X.Offset, sfxGroup.Volume, function(v)
		Sounds.group().Volume = v
		sfxValue.Text = string.format("%d%%", math.floor(v * 100 + 0.5))
	end)
	sfxValue.Text = string.format("%d%%", math.floor(sfxGroup.Volume * 100 + 0.5))
	self._sliders.sfx = sfx
	total += h2 + gap

	-- Reduce motion: three choices
	local motionControl, motionValue, h3 = self:_row(list, 3, "Motion", "Reduce motion", stacked, inner)
	self._motionValue = motionValue
	local choices = { { "Roblox", "Use Roblox setting" }, { "On", "On" }, { "Off", "Off" } }
	local x = 0
	for _, pair in choices do
		local label = pair[2]
		local w = math.max(64, math.ceil(measure(label, VALUE)) + 20 + 22)
		local b = make("TextButton", {
			Name = "Motion" .. pair[1],
			Position = UDim2.fromOffset(x, 0),
			Size = UDim2.fromOffset(w, 48),
			BackgroundColor3 = C.PanelShade,
			AutoButtonColor = false,
			Selectable = true,
			Text = "",
			ZIndex = 44,
			Parent = motionControl,
		})
		Gloss.corner(b, 12)
		Gloss.stroke(b, 2.5)
		b.SelectionImageObject = selectionRing(b, 12)
		local tick = make("Frame", {
			Name = "Tick",
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 8, 0.5, 0),
			Size = UDim2.fromOffset(18, 18),
			BackgroundTransparency = 1,
			Visible = false,
			ZIndex = 45,
			Parent = b,
		})
		Icons.draw(tick, "Check", C.SuccessLight)
		local t = make("TextLabel", {
			Name = "Text",
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(26, 0),
			Size = UDim2.new(1, -32, 1, 0),
			FontFace = Tokens.font(),
			Text = label,
			TextSize = VALUE,
			TextColor3 = C.Ink,
			ZIndex = 45,
			Parent = b,
		})
		local choice = pair[1]
		self._content:Connect(b.Activated, function()
			Sounds.play("Tap")
			self:_choose(choice)
		end)
		table.insert(self._segments, { button = b, choice = choice, tick = tick, text = t })
		x += w + 6
	end
	total += h3

	-- Footer
	local footer = make("TextLabel", {
		Name = "Footer",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(PAD, 66 + total + 10),
		Size = UDim2.new(1, -2 * PAD, 0, 20),
		FontFace = Tokens.font(),
		Text = "Preview: not saved",
		TextSize = VALUE,
		TextColor3 = C.InkSoft,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 42,
		Parent = card,
	})
	list.Size = UDim2.fromOffset(inner, total)
	local cardH = 66 + total + 10 + footer.Size.Y.Offset + 16
	card.Size = UDim2.fromOffset(cardWidth, cardH)
	shadow.Size = card.Size
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
	if hadSelection and self._open then
		GuiService.SelectedObject = music.hit
	end
end

function SettingsPanel.layout(self: any)
	local ctx: Types.Ctx = self._ctx
	local scale = ctx.screen:uiScale()
	self._scale.Scale = scale
	local L = Layout.forProfile(ctx.screen:profile(), scale)
	-- The root is the safe area in design px, so after HudScale it fills the layer exactly.
	self.root.Size = UDim2.fromOffset(L.safeW, L.safeH)
	local stacked = L.profile == "PhonePortrait"
	local width = if stacked then L.safeW - 16 else math.min(600, L.safeW - 24)
	local kind = string.format("%s:%d", if stacked then "Stacked" else "Wide", width)
	if kind ~= self._kind then
		self._kind = kind
		self:_build(stacked, width)
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
	-- Refresh the controls from the live preview mix (another tool may have changed it).
	self._sliders.music.set(Sounds.musicGroup().Volume, false)
	self._sliders.sfx.set(Sounds.group().Volume, false)
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
	return {
		open = self._open,
		visible = self.root.Visible,
		layout = self._kind,
		music = Sounds.musicGroup().Volume,
		sfx = Sounds.group().Volume,
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
