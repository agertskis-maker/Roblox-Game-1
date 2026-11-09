--!strict
-- HOP / DIVE button (Round 8, WS-10, R-03), copied almost exactly from ChatGPT's R8-IMG-28 (Car-Hop-Art/review/round8/chatgpt-images).
-- One big round glossy button, bottom right. It replaces every earlier hop button (the Round 7 orange TextButton in RunExtras and the
-- Lane 3 rectangle with the HopCar icon): there is one button art, in this file.
--
--   HOP      glossy orange disc, bright rim, a chunky white UP arrow with a dark outline, the word HOP
--   DIVE     after the first press: bright yellow, the arrow turned DOWN with a quick squash-and-flip, the word DIVE, a pulsing glow
--            ring, and a thin ring round the edge that drains while the player floats (how long is left to dive)
--   PRESSED  pushed in and darker (HOP and DIVE each have one)
--   NO TARGET (DIVE with no car in reach)   the DIVE look dimmed to mustard
--   NO STAMINA                                grey, with a small empty bolt
--   input    PC: a cream "SPACE" keycap on the lower disc; gamepad: a round "A" badge; touch: nothing extra
-- The art is text-free PNGs (AssetIds r8_hop_*); every word is a live TextLabel. When AssetIds.image(key) is "" (not uploaded yet)
-- the disc, arrow, shadow and glow are drawn in code, so the button always shows.
-- Size: about 132 px on a 1080p desktop window (0.122 of the window's height), 0.15 of the height on a phone, never under 44 px.
--
--   HopButton.attach(options?) -> Handle      the live button for the run (RunHud/RunExtras): its own ScreenGui, bottom right inside
--                                             the safe area, presses call options.onHop; handle:update(runState) every frame
--   HopButton.buildFace(parent, size, options?) -> Face        the face alone (no input, no layout): playground, frames, side-by-sides
--   HopButton.sizeFor(area: Vector2, touch: boolean) -> number
--   HopButton.new(ctx, options?)                               the Lane 3 preview's store-driven button (HUD playground)
--   HopButton.buildSpecimenFace(parent, display, cooldown01?, iconName?) -> Frame
--   Face: :set(action, look?)  :setPressed(on)  :setDrain(fraction?)  :setInput(kind)  :setPrompt(on)  :getDebugState()  :destroy()
-- Studio test hook: the LocalPlayer attribute Lane3ScreenProfile ("PhoneLandscape", "Tablet", ...) lays the live button out inside
-- that device's frame, like every other Lane 3 screen (Screen.luau). Outside Studio it is ignored.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TextService = game:GetService("TextService")
local UserInputService = game:GetService("UserInputService")

local Arc = require(script.Parent.Arc)
local AssetIds = require(ReplicatedStorage.Shared.Style.AssetIds)
local Motion = require(script.Parent.Parent.Motion)
local Screen = require(script.Parent.Parent.Screen)
local Tokens = require(ReplicatedStorage.Shared.UI.Tokens)
local Trove = require(ReplicatedStorage.Packages.Trove)

local HopButton = {}

local Live = {} -- the run's button (attach)
Live.__index = Live
local Preview = {} -- the Lane 3 preview's store-driven button (new)
Preview.__index = Preview

export type Action = "Hop" | "Dive"
export type Look = "Ready" | "NoTarget" | "NoStamina"
export type InputKind = "Keyboard" | "Touch" | "Gamepad"
export type FaceOptions = { input: InputKind?, reducedMotion: (() -> boolean)? }

local NAVY = Color3.fromRGB(11, 22, 53)
local CREAM = Color3.fromRGB(255, 248, 238)
local KEY_FILL = Color3.fromRGB(255, 244, 218)
local YELLOW = Color3.fromRGB(255, 227, 37)
local GOLD = Color3.fromRGB(255, 200, 40)
local TRACK = Color3.fromRGB(201, 204, 214)
local DIM_WORD = Color3.fromRGB(232, 234, 240)

-- design size of the Lane 3 preview's canvas button (HopButton.new) and the old API's numbers
HopButton.Size = 96
HopButton.IconSize = HopButton.Size * 0.44
HopButton.CarIconSize = HopButton.IconSize

local DISC_KEYS = {
	hop = "r8_hop_disc_hop",
	hopPressed = "r8_hop_disc_hop_pressed",
	dive = "r8_hop_disc_dive",
	divePressed = "r8_hop_disc_dive_pressed",
	noTarget = "r8_hop_disc_notarget",
	noStamina = "r8_hop_disc_nostamina",
}

-- code-drawn fallback colours per disc image key: top, bottom, rim
local FALLBACK: { [string]: { Color3 } } = {
	r8_hop_disc_hop = { Color3.fromRGB(255, 180, 75), Color3.fromRGB(240, 100, 8), Color3.fromRGB(255, 210, 120) },
	r8_hop_disc_hop_pressed = { Color3.fromRGB(240, 100, 20), Color3.fromRGB(180, 56, 6), Color3.fromRGB(235, 100, 20) },
	r8_hop_disc_dive = { Color3.fromRGB(255, 239, 99), Color3.fromRGB(243, 169, 10), Color3.fromRGB(255, 243, 160) },
	r8_hop_disc_dive_pressed = {
		Color3.fromRGB(247, 194, 31),
		Color3.fromRGB(196, 122, 5),
		Color3.fromRGB(240, 190, 50),
	},
	r8_hop_disc_notarget = { Color3.fromRGB(214, 190, 94), Color3.fromRGB(143, 122, 44), Color3.fromRGB(207, 195, 138) },
	r8_hop_disc_nostamina = {
		Color3.fromRGB(188, 192, 203),
		Color3.fromRGB(118, 122, 136),
		Color3.fromRGB(210, 213, 222),
	},
}

local function make(className: string, props: { [string]: any }, parent: Instance?): any
	local inst = Instance.new(className)
	for k, v in props do
		(inst :: any)[k] = v
	end
	if parent then
		inst.Parent = parent
	end
	return inst
end

local function round(parent: Instance, radius: number?): UICorner
	return make("UICorner", { CornerRadius = UDim.new(radius or 0.5, 0) }, parent)
end

local function defaultReduced(): boolean
	return Motion.reduced()
end

----------------------------------------------------------------------------------------------
-- Size and input

-- about 132 px on a 1080p desktop window (0.122 of the height), 0.15 of the height on a phone (short side up to 500 px), never
-- under 44 px; a touch screen that is not a phone keeps at least 104 px (a thumb on a tablet)
function HopButton.sizeFor(area: Vector2, touch: boolean): number
	local short = math.min(area.X, area.Y)
	local phone = touch and short <= 500
	local size = if phone then area.Y * 0.15 else area.Y * (132 / 1080)
	if touch and not phone then
		size = math.max(size, 104)
	end
	return math.max(44, math.floor(size + 0.5))
end

local function detectInput(forcedTouch: boolean?): InputKind
	if forcedTouch ~= nil then
		return if forcedTouch then "Touch" else "Keyboard"
	end
	local kind: InputKind? = nil
	pcall(function()
		local preferred = (UserInputService :: any).PreferredInput
		if preferred == (Enum :: any).PreferredInput.Gamepad then
			kind = "Gamepad"
		elseif preferred == (Enum :: any).PreferredInput.Touch then
			kind = "Touch"
		elseif preferred ~= nil then
			kind = "Keyboard"
		end
	end)
	if kind then
		return kind :: InputKind
	end
	if UserInputService.GamepadEnabled and not UserInputService.KeyboardEnabled then
		return "Gamepad"
	end
	if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
		return "Touch"
	end
	return "Keyboard"
end

----------------------------------------------------------------------------------------------
-- The face

local Face = {}
Face.__index = Face

export type FaceObject = typeof(setmetatable(
	{} :: {
		root: Frame,
		size: number,
		_trove: any,
		_reduced: () -> boolean,
		_body: Frame,
		_bodyScale: UIScale,
		_shadow: GuiObject,
		_glow: GuiObject,
		_glowStrokes: { UIStroke },
		_track: Frame,
		_arc: any,
		_disc: ImageLabel,
		_discFallback: Frame,
		_fallbackGradient: UIGradient,
		_arrow: Frame,
		_arrowImage: ImageLabel,
		_arrowFallback: Frame,
		_word: TextLabel,
		_bolt: Frame,
		_boltImage: ImageLabel,
		_boltFallback: Frame,
		_key: Frame,
		_keyCorner: UICorner,
		_keyText: TextLabel,
		_prompt: TextLabel,
		_promptScale: UIScale,
		_action: Action,
		_look: Look,
		_pressed: boolean,
		_input: InputKind,
		_drain: number?,
		_promptOn: boolean,
		_discKey: string,
		_arrowPixels: number,
		_flips: number,
		_art: boolean,
	},
	Face
))

local function arrowFallback(parent: Instance): Frame
	local holder = make("Frame", { Name = "Drawn", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, parent)
	local function piece(name: string, grow: number, colour: Color3, z: number)
		local head = make("Frame", {
			Name = name .. "Head",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.36),
			Size = UDim2.fromScale(0.5 + grow, 0.5 + grow),
			Rotation = 45,
			BackgroundColor3 = colour,
			BorderSizePixel = 0,
			ZIndex = z,
		}, holder)
		round(head, 0.14)
		local shaft = make("Frame", {
			Name = name .. "Shaft",
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.fromScale(0.5, 0.52 - grow / 2),
			Size = UDim2.fromScale(0.3 + grow, 0.44 + grow),
			BackgroundColor3 = colour,
			BorderSizePixel = 0,
			ZIndex = z,
		}, holder)
		round(shaft, 0.18)
	end
	piece("Outline", 0.1, NAVY, 1)
	piece("Fill", 0, Color3.fromRGB(250, 251, 255), 2)
	return holder
end

local function boltFallback(parent: Instance, height: number): Frame
	local StaminaBolt = require(script.Parent.StaminaBolt) -- the code-drawn bolt, only when the art is not uploaded yet
	local holder = make("Frame", { Name = "Drawn", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, parent)
	local art = StaminaBolt.new(
		holder,
		{ height = height, colour = Color3.fromRGB(200, 204, 216), crack = false, name = "Bolt", z = 8 }
	)
	art.root.AnchorPoint = Vector2.new(0.5, 0.5)
	art.root.Position = UDim2.fromScale(0.5, 0.5)
	return holder
end

function HopButton.buildFace(parent: Instance, size: number, options: FaceOptions?): FaceObject
	local opts: FaceOptions = options or {}
	local D = size
	local trove = Trove.new()
	local root = make("Frame", {
		Name = "HopFace",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(D, D),
		BackgroundTransparency = 1,
	}, parent)
	trove:Add(root)

	-- shadow
	local shadowArt = AssetIds.image("r8_hop_shadow")
	local shadow: GuiObject
	if shadowArt ~= "" then
		shadow = make("ImageLabel", {
			Name = "Shadow",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, 0, 0.5, D * 0.07),
			Size = UDim2.fromOffset(D * 1.18, D * 1.18),
			BackgroundTransparency = 1,
			Image = shadowArt,
			ImageTransparency = 0.1,
			ZIndex = 1,
		}, root)
	else
		shadow = make("Frame", {
			Name = "Shadow",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, 0, 0.5, D * 0.07),
			Size = UDim2.fromOffset(D * 1.04, D * 1.04),
			BackgroundColor3 = NAVY,
			BackgroundTransparency = 0.72,
			BorderSizePixel = 0,
			ZIndex = 1,
		}, root)
		round(shadow)
	end

	-- the pulsing glow ring behind DIVE
	local glowArt = AssetIds.image("r8_hop_glow")
	local glow: GuiObject
	local glowStrokes: { UIStroke } = {}
	if glowArt ~= "" then
		glow = make("ImageLabel", {
			Name = "Glow",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(D * 1.55, D * 1.55),
			BackgroundTransparency = 1,
			Image = glowArt,
			ImageTransparency = 0.25,
			Visible = false,
			ZIndex = 2,
		}, root)
	else
		glow = make("Frame", {
			Name = "Glow",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(D * 1.2, D * 1.2),
			BackgroundTransparency = 1,
			Visible = false,
			ZIndex = 2,
		}, root)
		round(glow)
		table.insert(glowStrokes, make("UIStroke", { Color = GOLD, Thickness = D * 0.12, Transparency = 0.8 }, glow))
		local inner = make("Frame", {
			Name = "Inner",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			ZIndex = 2,
		}, glow)
		round(inner)
		table.insert(glowStrokes, make("UIStroke", { Color = YELLOW, Thickness = D * 0.06, Transparency = 0.5 }, inner))
	end

	-- the drain ring: a grey track and a yellow arc that shrinks (clockwise from 12 o'clock) round the edge of the disc
	local ringSize = D * 1.14
	local track = make("Frame", {
		Name = "Track",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(ringSize, ringSize),
		BackgroundColor3 = TRACK,
		BorderSizePixel = 0,
		Visible = false,
		ZIndex = 3,
	}, root)
	round(track)
	make("UIStroke", { Color = NAVY, Thickness = math.max(2, D * 0.03) }, track)
	local arc = Arc.new(track, ringSize, YELLOW, 0, 4)
	arc.root.Position = UDim2.fromScale(0.5, 0.5)

	-- the body: disc, arrow, word, bolt and keycap, scaled together for the press and the squash
	local body = make("Frame", {
		Name = "Body",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(D, D),
		BackgroundTransparency = 1,
		ZIndex = 5,
	}, root)
	local bodyScale = make("UIScale", { Scale = 1 }, body)

	local disc = make("ImageLabel", {
		Name = "Disc",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ScaleType = Enum.ScaleType.Fit,
		Image = "",
		ZIndex = 5,
	}, body)
	local discFallback = make("Frame", {
		Name = "Drawn",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		ZIndex = 5,
	}, body)
	round(discFallback)
	make("UIStroke", { Color = NAVY, Thickness = math.max(2, D * 0.045) }, discFallback)
	local fallbackGradient = make("UIGradient", { Rotation = 90 }, discFallback)
	local gloss = make("Frame", {
		Name = "Gloss",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.34, 0.2),
		Size = UDim2.fromScale(0.46, 0.17),
		Rotation = -32,
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.45,
		BorderSizePixel = 0,
		ZIndex = 6,
	}, discFallback)
	round(gloss)

	-- the arrow: one up arrow; DIVE turns it round (squash and flip)
	local arrow = make("Frame", {
		Name = "Arrow",
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		ZIndex = 7,
	}, body)
	local arrowArt = AssetIds.image("r8_hop_arrow")
	local arrowImage = make("ImageLabel", {
		Name = "Art",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Image = arrowArt,
		Visible = arrowArt ~= "",
		ZIndex = 7,
	}, arrow)
	local arrowDrawn = arrowFallback(arrow)
	arrowDrawn.Visible = arrowArt == ""

	-- the word
	local word = make("TextLabel", {
		Name = "Word",
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		FontFace = Tokens.font(),
		Text = "HOP",
		TextColor3 = CREAM,
		TextScaled = false,
		ZIndex = 8,
	}, body)
	make("UIStroke", {
		Color = NAVY,
		Thickness = math.max(2, D * 0.04),
		LineJoinMode = Enum.LineJoinMode.Round,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
	}, word)

	-- the empty bolt (NO STAMINA)
	local bolt = make("Frame", {
		Name = "Bolt",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.86),
		Size = UDim2.fromOffset(D * 0.2, D * 0.2),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 8,
	}, body)
	local boltArt = AssetIds.image("r8_hop_bolt_empty")
	local boltImage = make("ImageLabel", {
		Name = "Art",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Image = boltArt,
		Visible = boltArt ~= "",
		ZIndex = 8,
	}, bolt)
	local boltDrawn = boltFallback(bolt, D * 0.2)
	boltDrawn.Visible = boltArt == ""

	-- the keycap (PC: SPACE) or badge (gamepad: A), on the lower disc
	local key = make("Frame", {
		Name = "Key",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.83),
		Size = UDim2.fromScale(0.6, 0.19),
		BackgroundColor3 = KEY_FILL,
		BorderSizePixel = 0,
		Visible = false,
		ZIndex = 8,
	}, body)
	local keyCorner = round(key, 0.3)
	make("UIStroke", { Color = NAVY, Thickness = math.max(2, D * 0.028) }, key)
	local keyText = make("TextLabel", {
		Name = "Text",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		FontFace = Tokens.font(),
		Text = "SPACE",
		TextColor3 = NAVY,
		TextSize = math.max(12, math.floor(D * 0.115)),
		ZIndex = 9,
	}, key)

	-- PRESS AGAIN! (the first runs, while floating), above the button
	local prompt = make("TextLabel", {
		Name = "PressAgain",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, D * 0.07, 0, -D * 0.32),
		Size = UDim2.fromOffset(D * 2.4, math.max(24, D * 0.26)),
		BackgroundTransparency = 1,
		FontFace = Tokens.font(),
		Text = "PRESS AGAIN!",
		TextColor3 = YELLOW,
		TextSize = math.max(18, math.floor(D * 0.22)),
		TextXAlignment = Enum.TextXAlignment.Right,
		Visible = false,
		ZIndex = 12,
	}, root)
	make("UIStroke", {
		Color = NAVY,
		Thickness = math.max(2, D * 0.03),
		LineJoinMode = Enum.LineJoinMode.Round,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
	}, prompt)
	local promptScale = make("UIScale", { Scale = 1 }, prompt)

	local self = setmetatable({
		root = root,
		size = D,
		_trove = trove,
		_reduced = opts.reducedMotion or defaultReduced,
		_body = body,
		_bodyScale = bodyScale,
		_shadow = shadow,
		_glow = glow,
		_glowStrokes = glowStrokes,
		_track = track,
		_arc = arc,
		_disc = disc,
		_discFallback = discFallback,
		_fallbackGradient = fallbackGradient,
		_arrow = arrow,
		_arrowImage = arrowImage,
		_arrowFallback = arrowDrawn,
		_word = word,
		_bolt = bolt,
		_boltImage = boltImage,
		_boltFallback = boltDrawn,
		_key = key,
		_keyCorner = keyCorner,
		_keyText = keyText,
		_prompt = prompt,
		_promptScale = promptScale,
		_action = "Hop" :: Action,
		_look = "Ready" :: Look,
		_pressed = false,
		_input = opts.input or "Touch",
		_drain = nil :: number?,
		_promptOn = false,
		_discKey = "",
		_arrowPixels = D * 0.44,
		_flips = 0,
		_art = false,
	}, Face)
	-- one light per-frame step: the DIVE glow pulse and the prompt's pulse (none in Reduce Motion)
	trove:Add(RunService.Heartbeat:Connect(function()
		self:_step(os.clock())
	end))
	trove:Add(function()
		Motion.cancelAll(self._bodyScale)
		Motion.cancelAll(self._arrow)
		Motion.cancelAll(self._disc)
	end)
	self:_apply(false)
	return self
end

local function discKeyFor(action: Action, look: Look, pressed: boolean): string
	if look == "NoTarget" then
		return DISC_KEYS.noTarget
	elseif look == "NoStamina" then
		return DISC_KEYS.noStamina
	elseif action == "Dive" then
		return if pressed then DISC_KEYS.divePressed else DISC_KEYS.dive
	end
	return if pressed then DISC_KEYS.hopPressed else DISC_KEYS.hop
end

-- Lays out and dresses the face for the current action, look, press and input. `flip` plays the HOP <-> DIVE squash-and-flip.
function Face._apply(self: FaceObject, flip: boolean)
	local D = self.size
	local action, look, pressed = self._action, self._look, self._pressed
	local dimmed = look ~= "Ready"
	local withKey = self._input ~= "Touch" and look ~= "NoStamina"
	local reduced = self._reduced()

	-- the disc
	local key = discKeyFor(action, look, pressed)
	self._discKey = key
	local image = AssetIds.image(key)
	self._art = image ~= ""
	self._disc.Image = image
	self._disc.Visible = image ~= ""
	self._discFallback.Visible = image == ""
	if image == "" then
		local colours = FALLBACK[key]
		self._fallbackGradient.Color = ColorSequence.new(colours[1], colours[2])
	end

	-- arrow and word (the PC look moves both up to make room for the keycap, as in the reference)
	local arrowCentre = if withKey then 0.31 else 0.355
	local arrowSize = D * (if withKey then 0.4 else 0.44)
	local wordCentre = if withKey then 0.585 else 0.69
	self._arrowPixels = arrowSize
	self._arrow.Position = UDim2.fromScale(0.5, arrowCentre + (if pressed then 0.012 else 0))
	self._word.Position = UDim2.fromScale(0.5, wordCentre + (if pressed then 0.012 else 0))
	self._word.Size = UDim2.fromOffset(D * 0.9, D * 0.3)
	self._word.TextSize = math.max(14, math.floor(D * (if withKey then 0.25 else 0.27)))
	self._word.Text = if action == "Dive" then "DIVE" else "HOP"
	self._word.TextColor3 = if dimmed then DIM_WORD else CREAM
	local tint = if dimmed then Color3.fromRGB(232, 234, 240) else Color3.new(1, 1, 1)
	self._arrowImage.ImageColor3 = tint
	local wantRotation = if action == "Dive" then 180 else 0
	Motion.cancelAll(self._arrow)
	if flip and not reduced then
		self._flips += 1
		-- squash: the body pops in, the arrow turns half way round while it flattens and springs back
		self._bodyScale.Scale = 0.86
		Motion.tween(
			self._bodyScale,
			"flip",
			TweenInfo.new(0.26, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
			{ Scale = 1 }
		)
		self._arrow.Size = UDim2.fromOffset(arrowSize, arrowSize * 0.35)
		Motion.tween(
			self._arrow,
			"flip",
			TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
			{ Rotation = wantRotation, Size = UDim2.fromOffset(arrowSize, arrowSize) }
		)
	else
		self._arrow.Rotation = wantRotation
		self._arrow.Size = UDim2.fromOffset(arrowSize, arrowSize)
		if not flip then
			self._bodyScale.Scale = if pressed then 0.94 else 1
		end
	end

	-- the empty bolt (NO STAMINA), the keycap or badge, the ring, the glow
	self._bolt.Visible = look == "NoStamina"
	self._key.Visible = withKey
	if withKey then
		if self._input == "Gamepad" then
			self._keyText.Text = "A"
			self._key.Size = UDim2.fromScale(0.21, 0.21)
			self._key.Position = UDim2.fromScale(0.5, 0.83)
			self._keyCorner.CornerRadius = UDim.new(0.5, 0)
			self._keyText.TextSize = math.max(12, math.floor(D * 0.15))
		else
			self._keyText.Text = "SPACE"
			self._key.Size = UDim2.fromScale(0.6, 0.19)
			self._key.Position = UDim2.fromScale(0.5, 0.83)
			self._keyCorner.CornerRadius = UDim.new(0.3, 0)
			self._keyText.TextSize = math.max(12, math.floor(D * 0.115))
		end
	end
	self._track.Visible = action == "Dive" and self._drain ~= nil
	self._arc.root.Visible = self._track.Visible and (self._drain or 0) > 0.002
	self._arc:setColor(if dimmed then Color3.fromRGB(214, 190, 90) else YELLOW)
	self._glow.Visible = action == "Dive" and look == "Ready"
end

-- HOP or DIVE, and the look (Ready, NoTarget, NoStamina). A change of action plays the squash-and-flip.
function Face.set(self: FaceObject, action: Action, look: Look?)
	local newLook: Look = look or "Ready"
	if action == self._action and newLook == self._look then
		return
	end
	local flip = action ~= self._action
	self._action = action
	self._look = newLook
	self:_apply(flip)
end

function Face.setPressed(self: FaceObject, on: boolean)
	if on == self._pressed then
		return
	end
	self._pressed = on
	if self._look == "NoStamina" then
		-- nothing happens on press, but the button still gives way a little
		Motion.tween(self._bodyScale, "press", TweenInfo.new(0.08), { Scale = if on then 0.94 else 1 })
		return
	end
	self:_apply(false)
	Motion.tween(
		self._bodyScale,
		"press",
		if on then TweenInfo.new(0.06) else TweenInfo.new(0.14, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Scale = if on then 0.94 else 1 }
	)
end

-- fraction of the float left (1 = just leapt, 0 = about to drop); nil = no ring
function Face.setDrain(self: FaceObject, fraction: number?)
	if fraction == self._drain then
		return
	end
	self._drain = fraction
	self._track.Visible = self._action == "Dive" and fraction ~= nil
	self._arc:set(fraction or 0)
	self._arc.root.Visible = self._track.Visible and (fraction or 0) > 0.002
end

function Face.setInput(self: FaceObject, kind: InputKind)
	if kind == self._input then
		return
	end
	self._input = kind
	self:_apply(false)
end

function Face.setPrompt(self: FaceObject, on: boolean)
	self._promptOn = on
	self._prompt.Visible = on
	if not on then
		self._promptScale.Scale = 1
	end
end

function Face._step(self: FaceObject, now: number)
	local reduced = self._reduced()
	if self._glow.Visible then
		local wave = if reduced then 0.5 else 0.5 + 0.5 * math.sin(now * 2 * math.pi * 1.6)
		local size = self.size * (1.5 + 0.12 * wave)
		if self._glow:IsA("ImageLabel") then
			self._glow.Size = UDim2.fromOffset(size, size)
			self._glow.ImageTransparency = 0.12 + 0.3 * (1 - wave)
		else
			local drawn = self.size * (1.18 + 0.1 * wave)
			self._glow.Size = UDim2.fromOffset(drawn, drawn)
			for _, stroke in self._glowStrokes do
				stroke.Transparency = 0.35 + 0.35 * (1 - wave)
			end
		end
	end
	if self._promptOn then
		self._promptScale.Scale = if reduced then 1 else 1 + 0.08 * math.sin(now * 2 * math.pi * 1.6)
	end
end

function Face.getDebugState(self: FaceObject): { [string]: any }
	return {
		size = self.size,
		action = self._action,
		look = self._look,
		pressed = self._pressed,
		input = self._input,
		word = self._word.Text,
		wordSize = self._word.TextSize,
		disc = self._discKey,
		usingArt = self._art,
		arrowRotation = self._arrow.Rotation,
		arrowPixels = self._arrowPixels,
		drain = self._drain,
		ringShown = self._track.Visible,
		glowShown = self._glow.Visible,
		boltShown = self._bolt.Visible,
		keyShown = self._key.Visible,
		keyText = self._keyText.Text,
		promptShown = self._prompt.Visible,
		flips = self._flips,
		instances = #self.root:GetDescendants(),
	}
end

function Face.destroy(self: FaceObject)
	self._trove:Destroy()
end

----------------------------------------------------------------------------------------------
-- The live button for the run (RunHud/RunExtras)

export type AttachOptions = { onHop: (() -> ())?, floatHelp: boolean?, displayOrder: number? }

-- Studio test hook for the R-03 frames: the seven states of R8-IMG-28 (HOP, HOP PRESSED, DIVE, DIVE PRESSED, NO TARGET, NO STAMINA, PC) in
-- two rows, each a real face (the same code the live button uses) at the size the live button has on the device profile. The NO STAMINA
-- face shows the reference's DIVE variant (the live button only ever blocks a HOP, so its own NO STAMINA keeps the up arrow).
local BOARD_STATES = {
	{ "HOP", "Hop", "Ready", "Touch", false, nil },
	{ "HOP PRESSED", "Hop", "Ready", "Touch", true, nil },
	{ "DIVE", "Dive", "Ready", "Touch", false, 0.35 },
	{ "DIVE PRESSED", "Dive", "Ready", "Touch", true, 0.35 },
	{ "NO TARGET", "Dive", "NoTarget", "Touch", false, 0.3 },
	{ "NO STAMINA", "Dive", "NoStamina", "Touch", false, nil },
	{ "PC", "Hop", "Ready", "Keyboard", false, nil },
}

local function buildBoard(gui: ScreenGui, profile: Screen.Profile): (Frame, { FaceObject })
	local D = HopButton.sizeFor(profile.size, profile.touch)
	local cellW, cellH = math.floor(D * 2.0), math.floor(D * 2.25)
	local board = make("Frame", {
		Name = "HopBoard",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(cellW * 4, cellH * 2),
		BackgroundColor3 = Color3.fromRGB(52, 57, 72),
		BorderSizePixel = 0,
		ZIndex = 50,
	}, gui)
	-- fitted into the window like Screen.luau fits a device frame (never enlarged)
	local viewport = gui.AbsoluteSize
	make("UIScale", {
		Scale = math.max(math.min((viewport.X - 16) / (cellW * 4), (viewport.Y - 16) / (cellH * 2), 1), 0.05),
	}, board)
	local faces: { FaceObject } = {}
	for i, st in BOARD_STATES do
		local col = (i - 1) % 4
		local row = (i - 1) // 4
		local cx = (col + 0.5) * cellW + (if row == 1 then cellW / 2 else 0)
		local cy = row * cellH + D * 0.95
		local face = HopButton.buildFace(board, D, { input = st[4] :: InputKind })
		face.root.Position = UDim2.fromOffset(cx, cy)
		face:set(st[2] :: Action, st[3] :: Look)
		if st[5] then
			face:setPressed(true)
		end
		if st[6] then
			face:setDrain(st[6] :: number)
		end
		table.insert(faces, face)
		local pill = make("TextLabel", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(cx, cy + D * 0.95),
			Size = UDim2.fromOffset(cellW * 0.82, math.max(20, D * 0.2)),
			BackgroundColor3 = Color3.fromRGB(255, 244, 218),
			TextColor3 = NAVY,
			FontFace = Tokens.font(),
			TextSize = math.max(12, math.floor(D * 0.11)),
			Text = st[1],
			ZIndex = 51,
		}, board)
		round(pill, 0.4)
	end
	return board, faces
end

local function studioProfile(): Screen.Profile?
	if not RunService:IsStudio() then
		return nil
	end
	local player = Players.LocalPlayer
	local name = player and player:GetAttribute("Lane3ScreenProfile")
	return if type(name) == "string" then Screen.Profiles[name] else nil
end

function HopButton.attach(options: AttachOptions?)
	local opts: AttachOptions = options or {}
	local player = Players.LocalPlayer
	local trove = Trove.new()
	local self = setmetatable({}, Live) :: any
	self._trove = trove
	self._opts = opts
	self._visible = true
	self._state = ""
	self._face = nil :: FaceObject?

	local gui = trove:Add(make("ScreenGui", {
		Name = "CarHopHopButton",
		ResetOnSpawn = false,
		IgnoreGuiInset = true, -- the whole window: the origin is the window's corner (the top bar's inset would push the button off the bottom)
		DisplayOrder = opts.displayOrder or 12,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	}))
	pcall(function()
		(gui :: any).ScreenInsets = (Enum :: any).ScreenInsets.DeviceSafeInsets
	end)
	-- the frame the button is laid out in: the whole screen, or (Studio test hook) a device-sized frame in the middle of it
	local frame = make("Frame", {
		Name = "Frame",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
	}, gui)
	local fit = make("UIScale", { Name = "DeviceFit", Scale = 1 }, frame)
	-- the hit box sits above the face: a little bigger than the disc, never under 44 px
	local hit = make("TextButton", {
		Name = "Hop",
		AnchorPoint = Vector2.new(1, 1),
		BackgroundTransparency = 1,
		AutoButtonColor = false,
		Text = "",
		ZIndex = 20,
	}, frame)
	self._gui, self._frame, self._fit, self._hit = gui, frame, fit, hit

	local function layout()
		local forced = studioProfile()
		local viewport = gui.AbsoluteSize
		local area = viewport
		local insets = { top = 0, bottom = 0, left = 0, right = 0 }
		local touch = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
		if forced then
			area = forced.size
			insets = forced.insets
			touch = forced.touch
			frame.AnchorPoint = Vector2.new(0.5, 0.5)
			frame.Position = UDim2.fromScale(0.5, 0.5)
			frame.Size = UDim2.fromOffset(area.X, area.Y)
			fit.Scale = math.max(math.min((viewport.X - 24) / area.X, (viewport.Y - 24) / area.Y, 1), 0.05)
		else
			frame.AnchorPoint = Vector2.zero
			frame.Position = UDim2.fromScale(0, 0)
			frame.Size = UDim2.fromScale(1, 1)
			fit.Scale = 1
		end
		self._touchForced = if forced then touch else nil
		local D = HopButton.sizeFor(Vector2.new(area.X - insets.left - insets.right, area.Y), touch)
		local margin = math.max(16, math.floor(D * 0.26))
		local right = area.X - insets.right - margin
		local bottom = area.Y - insets.bottom - margin
		local old = self._face :: FaceObject?
		if not old or old.size ~= D then
			if old then
				old:Destroy()
			end
			local face = HopButton.buildFace(frame, D, { input = detectInput(self._touchForced) })
			face.root.ZIndex = 10
			self._face = face
			self._state = "" -- dress it again
		end
		local face = self._face :: FaceObject
		face.root.Position = UDim2.fromOffset(right - D / 2, bottom - D / 2)
		local hitSize = math.max(44, D * 1.1)
		hit.Size = UDim2.fromOffset(hitSize, hitSize)
		hit.Position = UDim2.fromOffset(right + (hitSize - D) / 2, bottom + (hitSize - D) / 2)
		face:setInput(detectInput(self._touchForced))
	end
	self._layout = layout
	layout()

	local function pressed(on: boolean)
		local face = self._face :: FaceObject?
		if face then
			face:setPressed(on)
		end
	end
	trove:Connect(hit.Activated, function()
		if opts.onHop then
			opts.onHop()
		end
	end)
	trove:Connect(hit.MouseButton1Down, function()
		pressed(true)
	end)
	trove:Connect(hit.MouseButton1Up, function()
		pressed(false)
	end)
	trove:Connect(hit.MouseLeave, function()
		pressed(false)
	end)
	-- Space and the gamepad A button press the same button (RunInput binds them): show the press
	trove:Connect(UserInputService.InputBegan, function(input: InputObject)
		if input.KeyCode == Enum.KeyCode.Space or input.KeyCode == Enum.KeyCode.ButtonA then
			pressed(true)
		end
	end)
	trove:Connect(UserInputService.InputEnded, function(input: InputObject)
		if input.KeyCode == Enum.KeyCode.Space or input.KeyCode == Enum.KeyCode.ButtonA then
			pressed(false)
		end
	end)
	trove:Connect(UserInputService.LastInputTypeChanged, function()
		local face = self._face :: FaceObject?
		if face then
			face:setInput(detectInput(self._touchForced))
		end
	end)
	trove:Connect(gui:GetPropertyChangedSignal("AbsoluteSize"), layout)
	if player then
		trove:Connect(player:GetAttributeChangedSignal("Lane3ScreenProfile"), layout)
	end
	trove:Add(function()
		local face = self._face :: FaceObject?
		if face then
			face:Destroy()
		end
	end)

	-- Studio only: the LocalPlayer attribute Lane3HopBoard = "Desktop" | "PhoneLandscape" | "Tablet" shows the seven-state board; "off" hides it
	if RunService:IsStudio() and player then
		local boardFaces: { FaceObject } = {}
		local board: Frame? = nil
		local function clearBoard()
			for _, f in boardFaces do
				f:Destroy()
			end
			table.clear(boardFaces)
			if board then
				board:Destroy()
				board = nil
			end
		end
		local function onBoard()
			clearBoard()
			local name = player:GetAttribute("Lane3HopBoard")
			local profile = if type(name) == "string" then Screen.Profiles[name] else nil
			if profile then
				board, boardFaces = buildBoard(gui, profile)
			end
		end
		trove:Connect(player:GetAttributeChangedSignal("Lane3HopBoard"), onBoard)
		trove:Add(clearBoard)
	end

	gui.Parent = (player :: Player):WaitForChild("PlayerGui")
	return self
end

-- The run's state, once a frame: { mode, target, stamina, floatLeft, floatDuration } (RunController.getDebugState)
--   Riding, Recover           HOP (NO STAMINA when no bolt is left: pressing it only says "Out of bolts!")
--   Float                     DIVE, the ring draining; NO TARGET when no car is in reach
--   Dive                      DIVE (the last 0.28 s)
--   Ended                     hidden
function Live.update(self: any, s: { [string]: any })
	local face = self._face :: FaceObject?
	if not face then
		return
	end
	local mode: string = s.mode
	local show = self._visible and mode ~= "Ended"
	self._gui.Enabled = show
	if not show then
		return
	end
	local floating = mode == "Float"
	local diving = mode == "Dive"
	local action: Action = if floating or diving then "Dive" else "Hop"
	local look: Look = "Ready"
	if floating and s.target == nil then
		look = "NoTarget"
	elseif not (floating or diving) and s.stamina ~= nil and (s.stamina :: number) <= 0 then
		look = "NoStamina"
	end
	face:set(action, look)
	local drain: number? = nil
	if floating and s.floatLeft ~= nil and s.floatDuration ~= nil and (s.floatDuration :: number) > 0 then
		drain = math.clamp((s.floatLeft :: number) / (s.floatDuration :: number), 0, 1)
	elseif diving then
		drain = 0
	end
	face:setDrain(drain)
	face:setPrompt(self._opts.floatHelp == true and floating and s.target ~= nil)
	self._state = action .. "/" .. look
end

function Live.setVisible(self: any, on: boolean)
	self._visible = on
	self._gui.Enabled = on
end

function Live.getFace(self: any): FaceObject?
	return self._face
end

function Live.getDebugState(self: any): { [string]: any }
	local face = self._face :: FaceObject?
	local debug = if face then face:getDebugState() else {}
	debug.visible = self._gui.Enabled
	debug.hit = self._hit.AbsoluteSize.X
	debug.hitPosition = self._hit.AbsolutePosition
	debug.screen = self._gui.AbsoluteSize
	debug.profile = (self._touchForced ~= nil) and "forced" or "live"
	return debug
end

function Live.destroy(self: any)
	self._trove:Destroy()
end

----------------------------------------------------------------------------------------------
-- Lane 3 preview compatibility (the HUD playground): the same face on the store-driven canvas

local function lookFor(display: string): (Action, Look)
	if display == "NoTarget" then
		return "Hop", "NoTarget"
	elseif display == "OutOfStamina" then
		return "Hop", "NoStamina"
	end
	return "Hop", "Ready"
end

-- Playground specimen: one face in `display` (HopState names), with no store, input or sounds. The caller owns (and destroys) it.
-- `iconName` is ignored: the old HopCar icon candidates are gone with the old button.
function HopButton.buildSpecimenFace(parent: Instance, display: string, cooldown01: number?, _iconName: string?): Frame
	local HopState = require(script.Parent.HopState)
	local body = make("Frame", {
		Name = "HopSpecimen_" .. HopState.key(display),
		Size = UDim2.fromOffset(HopButton.Size, HopButton.Size),
		BackgroundTransparency = 1,
	}, parent)
	local face = HopButton.buildFace(body, HopButton.Size, { input = "Keyboard" })
	face.root.Position = UDim2.fromScale(0.5, 0.5)
	local action, lookName = lookFor(display)
	face:set(action, lookName)
	if cooldown01 and cooldown01 > 0 then
		face:setDrain(cooldown01)
	end
	return body
end

-- The widest line of the state's word and whether it fits the disc (design px, Fredoka One)
function HopButton.measureLabel(display: string): (number, boolean)
	local action = lookFor(display)
	local text = if action == "Dive" then "DIVE" else "HOP"
	local size = math.max(14, math.floor(HopButton.Size * 0.27))
	local bounds = TextService:GetTextSize(text, size, Enum.Font.FredokaOne, Vector2.new(4096, 4096))
	return bounds.X, bounds.X <= HopButton.Size * 0.8
end

function HopButton.iconSizeFor(_iconName: string): number
	return HopButton.IconSize
end

export type Options = { onHopIntent: (() -> ())?, gamepadKey: string? }

function HopButton.new(ctx: any, options: Options?)
	local RunLayout = require(script.Parent.RunLayout)
	local self = setmetatable({}, Preview) :: any
	local opts: Options = options or {}
	self._ctx = ctx
	self._trove = Trove.new()
	self._onIntent = opts.onHopIntent
	self._state = ""
	self._intents = 0
	local root = self._trove:Add(RunLayout.canvas(ctx, "HopButton"))
	self.root = root
	local holder = make("Frame", {
		Name = "Hop",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(HopButton.Size, HopButton.Size),
		ZIndex = 2,
		Parent = root,
	})
	self._holder = holder
	local face = HopButton.buildFace(holder, HopButton.Size, { input = detectInput(nil) })
	face.root.Position = UDim2.fromScale(0.5, 0.5)
	self._face = face
	local hit = make("TextButton", {
		Name = "Body",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		AutoButtonColor = false,
		Text = "",
		ZIndex = 30,
		Parent = holder,
	})
	self._trove:Connect(hit.Activated, function()
		if self._state ~= "OutOfStamina" and self._state ~= "NoTarget" then
			self._intents += 1
			if self._onIntent then
				self._onIntent()
			end
		end
	end)
	self._trove:Connect(hit.MouseButton1Down, function()
		face:setPressed(true)
	end)
	self._trove:Connect(hit.MouseButton1Up, function()
		face:setPressed(false)
	end)
	self._trove:Connect(hit.MouseLeave, function()
		face:setPressed(false)
	end)
	self._trove:Add(function()
		face:Destroy()
	end)
	self._trove:Add(ctx.store:subscribe("run", function()
		self:_apply()
	end))
	self._trove:Connect(ctx.store.ModeChanged, function()
		self:_apply()
	end)
	self:layout()
	return self
end

function Preview._apply(self: any)
	local HopState = require(script.Parent.HopState)
	local storeState = self._ctx.store:get()
	local run = storeState.run
	self._holder.Visible = storeState.mode == "Run" and run ~= nil
	local display = HopState.resolve(run)
	self._state = display
	local action, lookName = lookFor(display)
	self._face:set(action, lookName)
end

function Preview.layout(self: any)
	local RunLayout = require(script.Parent.RunLayout)
	local ctx = self._ctx
	RunLayout.fit(ctx, self.root)
	local rect = RunLayout.hopRect(ctx)
	self._holder.Position = UDim2.fromOffset(rect.pos.X, rect.pos.Y)
	self._face:setInput(detectInput(if ctx.screen:profile().touch then true else nil))
	self:_apply()
end

function Preview.setHopIntent(self: any, fn: (() -> ())?)
	self._onIntent = fn
end

function Preview.setInputKind(self: any, kind: InputKind?)
	self._face:setInput(kind or detectInput(nil))
end

function Preview.setVisible(self: any, on: boolean)
	self.root.Visible = on
end

function Preview.getDebugState(self: any): { [string]: any }
	local debug = self._face:getDebugState()
	debug.state = self._state
	debug.intents = self._intents
	return debug
end

function Preview.destroy(self: any)
	self._trove:Destroy()
end

return HopButton
