--!strict
-- Home HUD: preview Settings panel (Lane 3 preview, HUD rebuild 2026-10-22; ledger H-14).
-- Every control does exactly what it says for this client session; nothing is saved and no
-- schema is added ("Preview: kept this session, not saved" is a harness caption on the card).
--
--   Music / Sound effects   (2026-10-29, Design 7; spec vault/design/ui/settings-sound.md, awaiting Adam's visual
--                  approval) two AUDIO ROWS: a 48 x 48 mute button with the note / speaker icon (a slash and "MUTED"
--                  when muted, never colour alone), the label, a right-aligned whole percentage, and a 0 to 100 slider
--                  beneath (navy recessed track, cream inactive part, teal fill, cream knob). Home/MusicSetting turns them
--                  into the player's level on the "Music" / "Effects" category groups (AudioMix). Music On / Off is the
--                  MUSIC mute (the Home switch shows the same state). Mute keeps the level; unmute restores it (100 if
--                  none); a slider above 0 unmutes; 0 is muted. The SOUND EFFECTS slider plays a soft 70 ms preview tick
--                  through Effects: at most one per 150 ms while dragging, one on release when the level moved, none at 0.
--                  NORMAL frames stack the two rows; COMPACT (phone) frames put them side by side.
--   Reduce motion  three choices -> Motion.setOverride(nil | true | false):
--                  "Use Roblox setting" (default, follows GuiService.ReducedMotionEnabled),
--                  "On", "Off". The line under the label shows the effective state.
--   Haptics        (Round 3, R3-F5) the kit's ON / OFF switch (the same Arcade.toggle as the Home Music row) ->
--                  store.settings.haptics through Run/Haptics.setEnabled, ON by default, local preview state only. The
--                  line beside the switch says what it does: "Buzz when you get a car" / "Buzz is off". On a device that
--                  cannot vibrate (Haptics.isSupported() false: no controller motor and no touch screen) the row is still
--                  shown, the switch is dimmed, disabled and OFF, and the line says "Not available on this device";
--                  nothing is requested and nothing errors. Turning it OFF stops a cue that is running.
--
-- Look (Arcade kit family): a deep navy card with the thick dark boundary and a shallow lip, a
-- big white outlined "Settings" title, a red labelled "Close" button (kit Small, the same family
-- as the Home Settings rectangle), white outlined row labels, chunky sliders (dark track, green
-- fill, white knob with a dark outline) and segment buttons (gold when chosen, with a tick, so
-- the state is not colour alone).
--
-- Input: sliders take drag and tap (mouse and touch). A drag owns the one pointer that started it until that pointer ends
-- or is cancelled (or the window loses focus), clamps to 0 and 100 anywhere on screen, and ends when the card closes. While
-- selected with a gamepad or keyboard navigation, Left / Right (arrow keys, D-pad) move a slider in 5-point steps
-- (read from UserInputService while that slider is selected); on a mute button Right goes to its slider. Close,
-- Escape and ButtonB close the panel (Back is bound only while open). Tapping the dim backdrop also closes it.
-- Opening selects the first control when the last input was a gamepad (or keyboard navigation was active); closing returns
-- the selection to the opener (the Home Settings button) when it is still on screen, otherwise
-- clears it. Gamepad selection is kept inside the card (SelectionGroup with Stop behaviours).
--
-- Layout: centred card with wide rows on every (landscape) profile. Hit targets are 48 px or larger. The short phone frames
-- (safe height under COMPACT_BELOW design px: 300 and 325) use the COMPACT metrics (shorter title and rows, the harness
-- caption in the title row, the two audio rows side by side); taller frames keep the NORMAL metrics.
--
-- API: SettingsPanel.new(ctx, { onClosed: (() -> ())? }?) -> SettingsPanel
--   :open(opener: GuiObject?)  :close()  :isOpen() -> boolean
--   :layout()  :setVisible(on)  :destroy()  :getDebugState()
--   :getControls() -> { music, sfx, musicMute, sfxMute, motionRoblox, motionOn, motionOff, haptics, close, replay? }  (test hook)
--
-- Replay tutorial (BRIEF M11-07): when options.onReplayTutorial is given, a "Replay tutorial" button sits in the title row,
-- left of Close (a 48 px hit box). It closes the card and calls the option. It is a button in the title row and not a fifth
-- row because the card has no spare height on the tablet and phone frames (the rows already fill 495 and 258 design px).

local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextService = game:GetService("TextService")
local UserInputService = game:GetService("UserInputService")

local Arcade = require(script.Parent.Parent.Arcade)
local AudioMix = require(script.Parent.Parent.AudioMix)
local Fade = require(script.Parent.Fade)
local Haptics = require(script.Parent.Parent.Run.Haptics)
local IconArt = require(script.Parent.IconArt)
local Layout = require(script.Parent.Layout)
local Motion = require(script.Parent.Parent.Motion)
local MusicSetting = require(script.Parent.MusicSetting)
local PreviewTokens = require(script.Parent.Parent.PreviewTokens)
local Sounds = require(script.Parent.Parent.Sounds)
local TutorialStrings = require(script.Parent.Parent.Parent.Tutorial.TutorialStrings)
local Tokens = require(ReplicatedStorage.Shared.UI.Tokens)
local Trove = require(ReplicatedStorage.Packages.Trove)
local Types = require(script.Parent.Types)

local A = PreviewTokens.Arcade
local B = A.Button
local PM = PreviewTokens.Motion
local make = Arcade.make

local OVERRIDE = "Lane3ReducedMotionOverride"
local BACK_ACTION = "Lane3PreviewSettingsBack"
local PAD = 16 -- Design 7 side padding (was 20)
local LABEL = Tokens.TextSize.Value
local VALUE = Tokens.TextSize.Minimum
-- Design 7 audio rows (Adam's proposed values; spec section 2)
local AUDIO_H = 80
local MUTE = Tokens.Touch.Minimum -- the mute button, 48 x 48
local AUDIO_TEXT_X = MUTE + 8 -- the label and the slider start here
local AUDIO_LABEL = Tokens.TextSize.Label -- 18
local KNOB = 24
local SURROUND_H = 16 -- the navy recessed surround around the 10 px visual track
local TRACK_H = 10
local SLIDER_Y = 64 -- the slider hit box (48 high) is centred here: y 40 to 88
local COLUMN_GAP = 24 -- COMPACT: between the two audio rows (12 left MUSIC's "MUTED" reading as part of the next row)
local KEY_STEP = 0.05 -- keyboard / gamepad: 5 points
local TICK_GAP = 0.15 -- the preview tick: at most one per 150 ms
local TRACK_CREAM = Tokens.Color.Card
local TRACK_TEAL = Tokens.Color.Calm
-- TOKEN CANDIDATE: the settings card body (deep navy) and an unchosen segment.
local CARD_FILL = ColorSequence.new(Color3.fromRGB(58, 74, 126), Color3.fromRGB(28, 36, 72))
local SEGMENT_OFF = Color3.fromRGB(70, 86, 140)
-- Haptics row text (child-facing)
local HAPTICS_ON_LINE = "Buzz when you get a car"
local HAPTICS_OFF_LINE = "Buzz is off"
local HAPTICS_UNAVAILABLE_LINE = "Not available on this device"

-- TOKEN CANDIDATE: card metrics. COMPACT is used when the safe height is under COMPACT_BELOW design px (the phone frames):
-- the two 80 px audio rows side by side, then two 52 px rows: 52 + 80 + 8 + 52 + 4 + 52 + 10 = 258 px against the smallest
-- safe height of 300 (four stacked rows would need 338). NORMAL stacks all four: 70 + 80 + 12 + 80 + 12 + 60 + 12 + 60 + 48
-- = 434 px, against 495 on the tablet.
local COMPACT_BELOW = 400
type Metrics = {
	titleY: number, -- the "Settings" title top
	titleBoxH: number,
	closeY: number, -- the Close button top
	rowsTop: number, -- where the first row starts
	rowH: number, -- Reduce motion and Haptics
	gap: number, -- between rows
	audioGap: number, -- under the audio rows
	audioColumns: boolean, -- the two audio rows side by side (COMPACT)
	labelH: number,
	valueY: number, -- the small line under the row label
	controlY: number,
	footer: number, -- space under the last row (NORMAL: the harness caption line sits there)
	noteInTitle: boolean, -- the harness caption goes on the title row (COMPACT)
}
local NORMAL: Metrics = {
	titleY = 12,
	titleBoxH = 44,
	closeY = 10,
	rowsTop = 70,
	rowH = 60,
	gap = 12,
	audioGap = 12,
	audioColumns = false,
	labelH = 34,
	valueY = 34,
	controlY = 6,
	footer = 48,
	noteInTitle = false,
}
local COMPACT: Metrics = {
	titleY = 4,
	titleBoxH = 40,
	closeY = 2,
	rowsTop = 52,
	rowH = 52,
	gap = 4,
	audioGap = 8,
	audioColumns = true,
	labelH = 30,
	valueY = 30,
	controlY = 2,
	footer = 10,
	noteInTitle = true,
}

export type Options = { onClosed: (() -> ())?, onReplayTutorial: (() -> ())? }

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
	track: Frame, -- the navy surround: positions are measured across it
	fill: Frame,
	knob: Frame,
	value: number, -- the level shown (the effective level: 0 while muted)
	dragStart: number, -- the level when the current drag started (kept for unmute when the drag ends at 0)
	set: (v: number, fromUser: boolean, kept: number?) -> (),
}

-- One audio row (Design 7): the mute button, the percentage and the slider of one category.
type AudioRow = {
	category: MusicSetting.Category,
	mute: TextButton,
	slash: Frame,
	pct: TextLabel,
	slider: Slider,
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

local function rectOf(g: GuiObject): { number }
	local p, z = g.AbsolutePosition, g.AbsoluteSize
	return { math.floor(p.X + 0.5), math.floor(p.Y + 0.5), math.floor(z.X + 0.5), math.floor(z.Y + 0.5) }
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
	self._audio = {} :: { [string]: AudioRow } -- "music" / "sfx"
	self._segments = {} :: { Segment }
	self._dragging = nil :: InputObject? -- the one pointer that owns the current drag
	self._dragSlider = nil :: Slider?
	self._tickAt = -math.huge -- the last preview tick (os.clock)
	self._tickLevel = -1 -- the effects level it was played at
	self._tickTimer = nil :: thread? -- a release tick waiting for the 150 ms gap
	self._ticks = 0
	self._closeToken = 0
	self._haptics = nil :: Arcade.Toggle? -- the Haptics switch (rebuilt with the card)
	self._hapticsDim = nil :: Frame? -- the "not available" shade over the switch
	self._hapticsLabel = nil :: TextLabel? -- the state line beside the switch
	self._hapticsSupported = true -- the device capability, read when the card is built and each time it opens

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
		-- only the owning pointer moves the knob: the same touch, or the mouse while its button holds the drag
		local mouseDrag = drag.UserInputType == Enum.UserInputType.MouseButton1
			and input.UserInputType == Enum.UserInputType.MouseMovement
		if input == drag or mouseDrag then
			self:_setFromX(slider, input.Position.X)
		end
	end)
	self._trove:Connect(UserInputService.InputEnded, function(input: InputObject)
		local drag: InputObject? = self._dragging
		if not drag then
			return
		end
		-- the owning pointer ended or was cancelled; another finger lifting does not end it
		local mouseUp = drag.UserInputType == Enum.UserInputType.MouseButton1
			and input.UserInputType == Enum.UserInputType.MouseButton1
		if input == drag or mouseUp then
			self:_endDrag()
		end
	end)
	-- Left / Right (arrow keys, D-pad) on a SELECTED slider: 5-point steps. Roblox's GUI navigation marks these keys as
	-- processed before ContextActionService sees them (measured in Studio Play, 2026-10-29: the old CAS binding never fired),
	-- so the panel reads them here, and only while one of its sliders is the selected object. The slider's own NextSelection
	-- Left / Right point at itself, so the selection never moves; Up / Down still navigate and nothing traps the focus.
	self._trove:Connect(UserInputService.InputBegan, function(input: InputObject)
		local k = input.KeyCode
		local dir = if k == Enum.KeyCode.Left or k == Enum.KeyCode.DPadLeft
			then -1
			elseif k == Enum.KeyCode.Right or k == Enum.KeyCode.DPadRight then 1
			else 0
		if dir == 0 or not self._open then
			return
		end
		local selected = GuiService.SelectedObject
		for _, slider: Slider in self._sliders do
			if slider.hit == selected then
				local before = slider.value
				slider.set(math.floor((before + dir * KEY_STEP) * 100 + 0.5) / 100, true, before)
				if slider == self._sliders.sfx then
					self:_tick(true)
				end
				return
			end
		end
	end)
	self._trove:Connect(UserInputService.WindowFocusReleased, function()
		self:_endDrag()
	end)
	self._trove:Add(function()
		local timer: thread? = self._tickTimer
		self._tickTimer = nil
		if timer then
			task.cancel(timer)
		end
	end)
	self._trove:Add(Motion.onReducedChanged(function()
		self:_refreshMotion()
	end))
	self._trove:Add(ctx.store:subscribe("settings", function()
		self:_refreshSound()
		self:_refreshHaptics(false)
	end))
	self._trove:Add(function()
		ContextActionService:UnbindAction(BACK_ACTION)
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

-- The SOUND EFFECTS preview tick, through Effects at the new level. `final` is a release or a key step: it plays only when
-- the level moved since the last tick, and waits out the 150 ms gap instead of being dropped. Never at 0, never overlapping
-- (the tick is 70 ms long, ticks are at least 150 ms apart).
function SettingsPanel._tick(self: any, final: boolean)
	local level = MusicSetting.effective(self._ctx.store, "Effects")
	local timer: thread? = self._tickTimer
	if timer then
		self._tickTimer = nil
		task.cancel(timer)
	end
	if level <= 0 or math.abs(level - self._tickLevel) < 0.005 then
		return
	end
	local wait = self._tickAt + TICK_GAP - os.clock()
	if wait > 0 then
		if final then
			self._tickTimer = task.delay(wait + 0.005, function()
				self._tickTimer = nil
				self:_tick(true)
			end)
		end
		return
	end
	self._tickAt = os.clock()
	self._tickLevel = level
	self._ticks += 1
	Sounds.play("VolumeTick")
end

function SettingsPanel._endDrag(self: any)
	local slider: Slider? = self._dragSlider
	self._dragging = nil
	self._dragSlider = nil
	if slider and slider == self._sliders.sfx then
		self:_tick(true) -- lets the player hear the new effects level
	end
end

function SettingsPanel._setFromX(self: any, slider: Slider, x: number)
	local left = slider.track.AbsolutePosition.X
	local width = slider.track.AbsoluteSize.X
	if width <= 0 then
		return
	end
	local v = math.clamp((x - left) / width, 0, 1) -- clamps anywhere on screen, inside the card or not
	slider.set(math.floor(v * 100 + 0.5) / 100, true, slider.dragStart)
	if slider == self._sliders.sfx then
		self:_tick(false)
	end
end

function SettingsPanel._makeSlider(
	self: any,
	parent: Instance,
	name: string,
	width: number,
	initial: number,
	onChange: (number, number?) -> ()
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
	-- Design 7: a navy recessed surround (16 high) holding the 10 px cream track; the knob's centre runs end to end
	local track = make("Frame", {
		Name = "Track",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, KNOB / 2, 0.5, 0),
		Size = UDim2.new(1, -KNOB, 0, SURROUND_H),
		BackgroundColor3 = A.Ink,
		ZIndex = 45,
		Parent = hit,
	})
	Arcade.corner(track, SURROUND_H // 2)
	local inner = make("Frame", {
		Name = "Inactive",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, (SURROUND_H - TRACK_H) // 2, 0.5, 0),
		Size = UDim2.new(1, -(SURROUND_H - TRACK_H), 0, TRACK_H),
		BackgroundColor3 = TRACK_CREAM,
		ZIndex = 46,
		Parent = track,
	})
	Arcade.corner(inner, TRACK_H // 2)
	local fill = make("Frame", {
		Name = "Fill",
		Size = UDim2.fromScale(initial, 1),
		BackgroundColor3 = TRACK_TEAL,
		Visible = initial > 0, -- no misleading sliver at 0
		ZIndex = 47,
		Parent = inner,
	})
	Arcade.corner(fill, TRACK_H // 2)
	local knob = make("Frame", {
		Name = "Knob",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(initial, 0.5),
		Size = UDim2.fromOffset(KNOB, KNOB),
		BackgroundColor3 = TRACK_CREAM,
		ZIndex = 48,
		Parent = track,
	})
	Arcade.corner(knob, KNOB // 2)
	Arcade.outline(knob, 2, A.Ink)
	local slider: Slider
	slider = {
		hit = hit,
		track = track,
		fill = fill,
		knob = knob,
		value = initial,
		dragStart = initial,
		set = function(v: number, fromUser: boolean, kept: number?)
			local clamped = math.clamp(v, 0, 1)
			slider.value = clamped
			fill.Size = UDim2.fromScale(clamped, 1)
			fill.Visible = clamped > 0
			knob.Position = UDim2.fromScale(clamped, 0.5)
			if fromUser then
				onChange(clamped, kept)
			end
		end,
	}
	trove:Connect(hit.InputBegan, function(input: InputObject)
		local t = input.UserInputType
		if self._dragging then
			return -- a drag already owns a pointer: a second finger neither steals nor restarts it
		end
		if t == Enum.UserInputType.MouseButton1 or t == Enum.UserInputType.Touch then
			self._dragging = input
			self._dragSlider = slider
			slider.dragStart = slider.value
			self:_setFromX(slider, input.Position.X)
		end
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

-- Each audio row shows the level as heard: the slider and the percentage follow the effective level, and a muted (or 0)
-- category shows the slash, a navy button and "MUTED" (state is never colour alone).
function SettingsPanel._refreshSound(self: any)
	local store = self._ctx.store
	for _, row: AudioRow in self._audio do
		local level = MusicSetting.effective(store, row.category)
		local muted = level <= 0
		row.slider.set(level, false)
		row.pct.Text = if muted then "MUTED" else pct(level)
		row.slash.Visible = muted
		row.mute.BackgroundColor3 = if muted then A.Ink else SEGMENT_OFF
	end
end

-- One Design 7 audio row (80 high): the mute button (48 x 48) on the left, the label and the right-aligned percentage on
-- the 48 px top line, the slider beneath from the label's x to the row's right edge.
function SettingsPanel._audioRow(
	self: any,
	parent: Instance,
	key: string,
	category: MusicSetting.Category,
	icon: string,
	text: string,
	x: number,
	y: number,
	width: number
): AudioRow
	local ctx: Types.Ctx = self._ctx
	local trove = self._content
	local row = make("Frame", {
		Name = "Audio" .. category,
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(x, y),
		Size = UDim2.fromOffset(width, AUDIO_H),
		ZIndex = 42,
		Parent = parent,
	})
	local mute = make("TextButton", {
		Name = "Mute",
		Size = UDim2.fromOffset(MUTE, MUTE),
		BackgroundColor3 = SEGMENT_OFF,
		AutoButtonColor = false,
		Selectable = true,
		Text = "",
		ZIndex = 44,
		Parent = row,
	})
	Arcade.corner(mute)
	Arcade.outline(mute, "Button")
	mute.SelectionImageObject = selectionRing(mute)
	mute.NextSelectionLeft = mute
	local iconHolder = make("Frame", {
		Name = "Icon",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(30, 30),
		BackgroundTransparency = 1,
		ZIndex = 45,
		Parent = mute,
	})
	IconArt.draw(iconHolder, { icon })
	-- the mute slash: a cream bar with a navy outline, corner to corner over the icon, drawn above it
	local slash = make("Frame", {
		Name = "Slash",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(4, 40),
		Rotation = 45,
		BackgroundColor3 = TRACK_CREAM,
		Visible = false,
		ZIndex = 50,
		Parent = mute,
	})
	Arcade.corner(slash, 2)
	Arcade.outline(slash, 3, A.Ink)
	local label = Arcade.text(row, {
		text = text,
		role = "Label",
		name = "Label",
		size = AUDIO_LABEL,
		xAlign = Enum.TextXAlignment.Left,
		z = 43,
	})
	label.Position = UDim2.fromOffset(AUDIO_TEXT_X, 0)
	label.Size = UDim2.fromOffset(math.ceil(measure(text, AUDIO_LABEL)) + 12, MUTE)
	local value = Arcade.text(row, {
		text = "",
		role = "Small",
		name = "Percent",
		size = VALUE,
		colour = Color3.fromRGB(214, 226, 255),
		z = 43,
	})
	value.AnchorPoint = Vector2.new(1, 0)
	value.Position = UDim2.fromScale(1, 0)
	value.Size = UDim2.fromOffset(72, MUTE)
	value.TextXAlignment = Enum.TextXAlignment.Right
	local holder = make("Frame", {
		Name = "Control",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.fromOffset(AUDIO_TEXT_X, SLIDER_Y),
		Size = UDim2.fromOffset(width - AUDIO_TEXT_X, MUTE),
		ZIndex = 43,
		Parent = row,
	})
	local initial = MusicSetting.effective(ctx.store, category)
	local slider = self:_makeSlider(holder, key, width - AUDIO_TEXT_X, initial, function(v: number, kept: number?)
		if category == "Music" then
			MusicSetting.setLevel(ctx.store, v, kept)
		else
			MusicSetting.setSfx(ctx.store, v, kept)
		end
	end)
	slider.hit.Position = UDim2.fromOffset(0, 0)
	mute.NextSelectionRight = slider.hit
	trove:Connect(mute.Activated, function()
		Sounds.play("Tap")
		MusicSetting.toggle(ctx.store, category)
		if category == "Effects" then
			self._tickLevel = -1
			self:_tick(true) -- unmuting effects: hear the level that came back (silent when this muted them)
		end
	end)
	local out: AudioRow = { category = category, mute = mute, slash = slash, pct = value, slider = slider }
	self._sliders[key] = slider
	self._audio[key] = out
	return out
end

-- The Haptics row follows the preference (ON unless false) and the device: unsupported = shown but OFF, dimmed, disabled, with
-- its reason. `recheck` re-reads the device capability (when the card is built and when it opens); a settings change
-- (a slider drag) reuses the last answer.
function SettingsPanel._refreshHaptics(self: any, recheck: boolean)
	local toggle: Arcade.Toggle? = self._haptics
	if not toggle then
		return
	end
	if recheck then
		self._hapticsSupported = Haptics.isSupported()
	end
	local supported: boolean = self._hapticsSupported
	local on = supported and Haptics.isOn(self._ctx.store:get().settings)
	toggle.set(on)
	local hit = toggle.root:FindFirstChild("Hit") :: TextButton?
	if hit then
		hit.Active = supported
		hit.Selectable = supported
	end
	-- gamepad order: the motion choices lead to the switch only when it can be selected, otherwise straight to Close
	local close: GuiObject? = self._closeButton
	if close then
		local below: GuiObject = if supported and hit then hit else close
		for _, seg in self._segments do
			seg.button.NextSelectionDown = below
		end
		close.NextSelectionUp = below
	end
	local dim: Frame? = self._hapticsDim
	if dim then
		dim.Visible = not supported
	end
	local line: TextLabel? = self._hapticsLabel
	if line then
		line.Text = if not supported then HAPTICS_UNAVAILABLE_LINE elseif on then HAPTICS_ON_LINE else HAPTICS_OFF_LINE
	end
end

-- The switch was pressed. A device that cannot vibrate never gets a preference change: the switch snaps back to OFF.
function SettingsPanel._setHaptics(self: any, on: boolean)
	if not self._hapticsSupported then
		self:_refreshHaptics(false)
		return
	end
	Haptics.setEnabled(self._ctx.store, on) -- writes settings.haptics, stops a running cue when OFF; the subscriber refreshes
end

-- One labelled row; returns the control frame, the value label and the row height.
function SettingsPanel._row(
	_self: any,
	parent: Instance,
	order: number,
	icons: { string },
	text: string,
	cardInner: number,
	m: Metrics
): (Frame, TextLabel, number)
	local rowH = m.rowH
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
	label.Size = UDim2.fromOffset(math.ceil(measure(text, LABEL)) + 12, m.labelH)
	local value = Arcade.text(row, {
		text = "",
		role = "Small",
		name = "Value",
		size = VALUE,
		colour = Color3.fromRGB(214, 226, 255),
		z = 43,
	})
	local labelColumn = 210
	value.Position = UDim2.fromOffset(38, m.valueY)
	value.Size = UDim2.fromOffset(labelColumn - 40, 22)
	value.TextXAlignment = Enum.TextXAlignment.Left
	local control = make("Frame", {
		Name = "Control",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(labelColumn, m.controlY),
		Size = UDim2.fromOffset(cardInner - labelColumn, 48),
		ZIndex = 43,
		Parent = row,
	})
	return control, value, rowH
end

function SettingsPanel._build(self: any, cardWidth: number, compact: boolean)
	local m: Metrics = if compact then COMPACT else NORMAL
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
	title.Position = UDim2.fromOffset(PAD, m.titleY)
	title.Size = UDim2.new(1, -2 * PAD - B.SmallW - 8, 0, m.titleBoxH)
	local close = Arcade.button(card, {
		name = "Close",
		label = "Close",
		fill = "Settings",
		size = "Small",
		sound = "Tap",
		position = UDim2.new(1, -14, 0, m.closeY),
		anchor = Vector2.new(1, 0),
		onActivate = function()
			self:close()
		end,
	})
	self._content:Add(close.trove)
	close.root.ZIndex = 44
	self._closeButton = close.body
	self._replayButton = nil :: GuiObject?
	local onReplay = self._opts.onReplayTutorial
	if onReplay then
		-- the title is about 150 design px wide ("Settings" at the Display size): the button starts after it
		local replayW = 196
		local replay = Arcade.button(card, {
			name = "ReplayTutorial",
			label = TutorialStrings.get("replay.button"),
			fill = "Garage",
			size = "Custom",
			width = replayW,
			height = 40,
			icon = "Hand",
			sound = "Tap",
			position = UDim2.fromOffset(PAD + 150 + 14, m.closeY),
			onActivate = function()
				self:close()
				onReplay()
			end,
		})
		self._content:Add(replay.trove)
		replay.root.ZIndex = 44
		self._replayButton = replay.body
		replay.body.NextSelectionRight = close.body
		close.body.NextSelectionLeft = replay.body
	end

	local list = make("Frame", {
		Name = "Rows",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(PAD, m.rowsTop),
		Size = UDim2.fromOffset(inner, 100),
		ZIndex = 42,
		Parent = card,
	})
	local gap = m.gap
	make("UIListLayout", {
		FillDirection = Enum.FillDirection.Vertical,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, gap),
		Parent = list,
	})
	local total = 0
	table.clear(self._audio)

	-- Design 7 audio rows: stacked (NORMAL) or side by side (COMPACT), in one block so the list keeps its order. The block
	-- carries any extra space under it (audioGap beyond the list's own gap).
	local extra = m.audioGap - gap
	local audioH = if m.audioColumns then AUDIO_H + extra else 2 * AUDIO_H + m.audioGap + extra
	local audio = make("Frame", {
		Name = "Audio",
		BackgroundTransparency = 1,
		LayoutOrder = 1,
		Size = UDim2.fromOffset(inner, audioH),
		ZIndex = 42,
		Parent = list,
	})
	local musicRow: AudioRow
	local sfxRow: AudioRow
	if m.audioColumns then
		local colW = (inner - COLUMN_GAP) // 2
		musicRow = self:_audioRow(audio, "music", "Music", "Music", "Music", 0, 0, colW)
		sfxRow = self:_audioRow(audio, "sfx", "Effects", "Speaker", "Sound effects", inner - colW, 0, colW)
	else
		musicRow = self:_audioRow(audio, "music", "Music", "Music", "Music", 0, 0, inner)
		sfxRow = self:_audioRow(audio, "sfx", "Effects", "Speaker", "Sound effects", 0, AUDIO_H + m.audioGap, inner)
	end
	local music = musicRow.slider
	local sfx = sfxRow.slider
	total += audioH + gap

	local motionControl, motionValue, h3 = self:_row(list, 3, { "Motion" }, "Reduce motion", inner, m)
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
	total += h3 + gap

	-- Haptics (R3-F5): the kit's ON / OFF switch, the state line beside it. The switch fills the control so its label
	-- (the state line) has the control's whole width after the 92 px track.
	local hapticsControl, hapticsValue, h4 = self:_row(list, 4, { "Haptics", "Motion" }, "Haptics", inner, m)
	hapticsValue.Visible = false -- the line sits beside the switch instead (it needs more than the label column)
	local toggle = Arcade.toggle(hapticsControl, {
		name = "HapticsSwitch",
		label = HAPTICS_ON_LINE,
		value = true,
		onChanged = function(on: boolean)
			self:_setHaptics(on)
		end,
	})
	self._content:Add(toggle.trove)
	toggle.root.Size = UDim2.fromScale(1, 1)
	local hit = toggle.root:FindFirstChild("Hit") :: TextButton
	hit.SelectionImageObject = selectionRing(hit)
	hit.NextSelectionLeft = hit
	hit.NextSelectionRight = hit
	local line = toggle.root:FindFirstChild("Label") :: TextLabel
	line.TextSize = VALUE -- the 16 px minimum: "Not available on this device" must fit the control beside the track
	line.TextXAlignment = Enum.TextXAlignment.Left
	line.TextTruncate = Enum.TextTruncate.AtEnd
	-- "not available": a shade over the track (the switch is also disabled and OFF)
	local dim = make("Frame", {
		Name = "Unavailable",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.fromScale(0, 0.5),
		Size = UDim2.fromOffset(92, 40), -- the kit switch's track
		BackgroundColor3 = A.Ink,
		BackgroundTransparency = 0.4,
		Visible = false,
		ZIndex = 8,
		Parent = toggle.root,
	})
	Arcade.corner(dim, 8)
	self._haptics = toggle
	self._hapticsDim = dim
	self._hapticsLabel = line
	total += h4

	local footer = Arcade.text(card, {
		text = "Preview: kept this session, not saved",
		role = "Small",
		name = "PreviewNote", -- harness caption (hidden in player-facing captures)
		size = VALUE,
		colour = Color3.fromRGB(255, 236, 140),
		xAlign = if m.noteInTitle then Enum.TextXAlignment.Right else Enum.TextXAlignment.Left,
		z = 42,
	})
	footer:SetAttribute("PreviewCaption", true)
	if m.noteInTitle then
		-- short phone frames: the caption shares the title row, left of the Close button
		footer.AnchorPoint = Vector2.new(1, 0)
		footer.Position = UDim2.new(1, -(B.SmallW + 28), 0, m.titleY + 10)
		footer.Size = UDim2.fromOffset(220, 22)
	else
		footer.Position = UDim2.fromOffset(PAD, m.rowsTop + total + 10)
		footer.Size = UDim2.new(1, -2 * PAD, 0, 22)
	end
	list.Size = UDim2.fromOffset(inner, total)
	local cardH = m.rowsTop + total + m.footer
	holder.Size = UDim2.fromOffset(cardWidth, cardH)
	self._cardHeight = cardH

	-- Selection order: MUSIC mute -> MUSIC slider -> SOUND EFFECTS mute -> SOUND EFFECTS slider -> motion choices -> haptics
	-- (only when the device can vibrate: _refreshHaptics sets the two links around it) -> close -> MUSIC mute.
	musicRow.mute.NextSelectionDown = music.hit
	music.hit.NextSelectionUp = musicRow.mute
	music.hit.NextSelectionDown = sfxRow.mute
	sfxRow.mute.NextSelectionUp = music.hit
	sfxRow.mute.NextSelectionDown = sfx.hit
	sfx.hit.NextSelectionUp = sfxRow.mute
	sfx.hit.NextSelectionDown = self._segments[1].button
	for i, seg in self._segments do
		seg.button.NextSelectionUp = sfx.hit
		seg.button.NextSelectionDown = close.body
		seg.button.NextSelectionLeft = if i > 1 then self._segments[i - 1].button else seg.button
		seg.button.NextSelectionRight = if i < #self._segments then self._segments[i + 1].button else seg.button
	end
	hit.NextSelectionUp = self._segments[1].button
	hit.NextSelectionDown = close.body
	close.body.NextSelectionDown = musicRow.mute
	close.body.NextSelectionUp = self._segments[1].button
	musicRow.mute.NextSelectionUp = close.body
	self:_refreshHaptics(true) -- reads the device capability, then links the motion choices and Close around the switch

	self._fade = Fade.capture(self.root)
	self:_refreshMotion()
	self:_refreshSound()
	if hadSelection and self._open then
		GuiService.SelectedObject = musicRow.mute
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
	local compact = L.safeH < COMPACT_BELOW
	local kind = string.format("Wide:%d:%s", width, if compact then "compact" else "normal")
	if kind ~= self._kind then
		self._kind = kind
		self:_build(width, compact)
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
	self:_refreshHaptics(true) -- a controller may have been plugged in or removed since the card was built
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
		GuiService.SelectedObject = self._audio.music.mute
	end
end

function SettingsPanel.close(self: any)
	if not self._open then
		return
	end
	self._open = false
	self:_endDrag()
	ContextActionService:UnbindAction(BACK_ACTION)
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
		musicMute = self._audio.music.mute,
		sfxMute = self._audio.sfx.mute,
		close = self._closeButton,
	}
	local switch: Arcade.Toggle? = self._haptics
	local hapticsHit = if switch then switch.root:FindFirstChild("Hit") else nil
	if hapticsHit then
		controls.haptics = hapticsHit :: GuiObject
	end
	for _, seg in self._segments do
		controls["motion" .. seg.choice] = seg.button
	end
	local replay: GuiObject? = self._replayButton
	if replay then
		controls.replay = replay
	end
	return controls
end

function SettingsPanel.getDebugState(self: any): { [string]: any }
	local ctx: Types.Ctx = self._ctx
	local selected = GuiService.SelectedObject
	local pos, size = ctx.screen:rectOf(self._card)
	local player = Players.LocalPlayer
	local s = ctx.store:get().settings
	-- the Haptics row as the player sees it: the switch word, the line beside it, and whether it can be pressed
	local switch: Arcade.Toggle? = self._haptics
	local track = if switch then switch.root:FindFirstChild("Track") else nil
	local word = if track then track:FindFirstChild("State") :: TextLabel? else nil
	local hitButton = if switch then switch.root:FindFirstChild("Hit") :: TextButton? else nil
	local stateLine: TextLabel? = self._hapticsLabel
	local dim: Frame? = self._hapticsDim
	return {
		haptics = {
			supported = self._hapticsSupported,
			preferenceOn = Haptics.isOn(s), -- the stored preference (kept even when the device cannot vibrate)
			switchOn = if switch then switch.get() else nil,
			switchWord = if word then word.Text else nil, -- "ON" / "OFF" inside the switch
			stateLine = if stateLine then stateLine.Text else nil,
			stateLineFits = if stateLine then stateLine.TextBounds.X <= stateLine.AbsoluteSize.X - 6 else nil,
			switchEnabled = if hitButton then hitButton.Active and hitButton.Selectable else nil,
			dimmed = if dim then dim.Visible else nil,
			hitHeight = if switch then (switch.root.Parent :: Frame).Size.Y.Offset else nil, -- design px (the control)
			compact = string.find(self._kind, "compact", 1, true) ~= nil,
			cue = Haptics.counts(),
		},
		open = self._open,
		visible = self.root.Visible,
		layout = self._kind,
		music = AudioMix.group("Music").Volume, -- the player's category groups (0..1 as heard)
		sfx = AudioMix.group("Effects").Volume,
		musicMix = Sounds.musicGroup().Volume, -- the approved mix levels nested under them (never written by Settings)
		sfxMix = Sounds.group().Volume,
		musicSetting = s.music,
		musicOn = s.musicOn ~= false,
		sfxSetting = s.sfx,
		sfxOn = (s :: any).sfxOn ~= false,
		musicSlider = self._sliders.music.value,
		sfxSlider = self._sliders.sfx.value,
		musicText = self._audio.music.pct.Text,
		sfxText = self._audio.sfx.pct.Text,
		musicSlash = self._audio.music.slash.Visible,
		sfxSlash = self._audio.sfx.slash.Visible,
		musicFill = self._sliders.music.fill.Visible,
		sfxFill = self._sliders.sfx.fill.Visible,
		dragOwner = if self._dragging then self._dragging.UserInputType.Name else nil,
		dragSlider = if self._dragSlider == self._sliders.music
			then "music"
			elseif self._dragSlider == self._sliders.sfx then "sfx"
			else nil,
		ticks = self._ticks,
		audioColumns = string.find(self._kind, "compact", 1, true) ~= nil,
		musicRow = rectOf(self._audio.music.mute.Parent :: GuiObject), -- device px: { x, y, w, h }
		sfxRow = rectOf(self._audio.sfx.mute.Parent :: GuiObject),
		musicMute = rectOf(self._audio.music.mute),
		sfxMute = rectOf(self._audio.sfx.mute),
		musicHit = rectOf(self._sliders.music.hit),
		sfxHit = rectOf(self._sliders.sfx.hit),
		musicKnob = rectOf(self._sliders.music.knob),
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
		safeHeight = self.root.Size.Y.Offset, -- design px: the card must fit inside it
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
