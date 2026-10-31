--!strict
-- Hop control for the rebuilt run view (Lane 3 preview, HUD rebuild worker HR; U-07). A chunky
-- arcade rectangle (limited rounding, thick dark boundary, teal/white = Hop's colour) with the
-- original HopCar symbol (Icons2) and "HOP", bottom right with clearance (RunLayout.hopRect:
-- beside the Roblox Jump zone on touch, never in a reserved zone or the protected road region).
-- Presentation only: it shows run.hop and run.hopCooldown01 as supplied; pressing it only calls
-- the preview intent callback. It never hops, picks a target or judges a landing (Lane 1).
--
-- Input-specific label (UserInputService.PreferredInput when available, else GamepadEnabled /
-- TouchEnabled / KeyboardEnabled; the device profile's touch flag wins in the playground):
--   keyboard  a "Space" key chip under the button
--   touch     no key label (the button is the control)
--   gamepad   the bound button's chip. No real binding exists in the preview: ButtonA is the
--             documented ASSUMPTION ("A"), overridable with options.gamepadKey.
-- Round 3 (R3-C2): the icon is HopCar, an original side-view car. Since 2026-10-28 it draws no arrow (Adam: the car
-- is the main focus) and gets a larger slot (iconSizeFor); the arrow candidates stay switchable in Icons2. It names
-- the action only; the production character or car may or may not leave the ground. It supersedes the Round 2
-- HopFigure (a character between two roofs). The display state still follows HopState (precedence
-- OutOfStamina > Cooldown > NoTarget > BestTiming > Ready), filtered by Run/HopCue when one is mounted (best timing
-- is debounced; the gold accent is one event per window).
-- States, never by colour alone. The three unavailable looks differ in tint, overlay AND a short word (at least 16 px):
--   Ready        teal, full-strength icon, "HOP"
--   BestTiming   + a STEADY gold ring around the button, one brief pop when the window opens (none in reduced motion)
--   Cooldown     teal under a dark radial sweep shrinking to 0 + dimmed icon + "WAIT"
--   NoTarget     cool blue-grey fill + dimmed icon + diagonal hatching + "NO CAR"; not pressable
--   OutOfStamina dusty rose fill + a large grey cracked bolt crossed by a red slash (the car icon steps aside; the
--                bolt is the Stamina meter's own StaminaBolt since 2026-10-28) +
--                "NO STAMINA" on two lines; not pressable; never shows best timing or the sweep
--
--   local hop = HopButton.new(ctx, { onHopIntent = fn?, gamepadKey = "A"? })
--   hop:setHopIntent(fn)        -- preview: called on press; no gameplay
--   hop:setInputKind(kind?)     -- "Keyboard" | "Touch" | "Gamepad" | nil (auto) for review
--   hop:layout(), hop:setVisible(on), hop:destroy(), hop:getDebugState()
--   HopButton.buildSpecimenFace(parent, display, cooldown01?, iconName?) -> Frame -- playground specimen: the SAME face
--                                                                         and look as the live button, no store, no input
--   HopButton.measureLabel(display) -> (widestLinePx, fits)            -- design px, Fredoka One, with the outline
--   HopButton.Size, HopButton.IconSize, HopButton.CarIconSize           -- design px
--   HopButton.iconSizeFor(iconName) -> number                           -- the slot size that icon gets on the face

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextService = game:GetService("TextService")
local UserInputService = game:GetService("UserInputService")

local Arc = require(script.Parent.Arc)
local Arcade = require(script.Parent.Parent.Arcade)
local HopState = require(script.Parent.HopState)
local Icons2 = require(script.Parent.Parent.Icons2)
local Motion = require(script.Parent.Parent.Motion)
local PreviewTokens = require(script.Parent.Parent.PreviewTokens)
local RunBus = require(script.Parent.RunBus)
local RunLayout = require(script.Parent.RunLayout)
local Sounds = require(script.Parent.Parent.Sounds)
local StaminaBolt = require(script.Parent.StaminaBolt)
local Tokens = require(ReplicatedStorage.Shared.UI.Tokens)
local Trove = require(ReplicatedStorage.Packages.Trove)

local A = PreviewTokens.Arcade
local make = Arcade.make

local SIZE = PreviewTokens.Size.HopButton -- 96 design px body
local ICON_SIZE = SIZE * 0.58
-- The car alone (Icons2.HopArrow "None", Adam 2026-10-28: the car "the main focus", "the majority of the button"):
-- an 84 px slot, so the car is about 74 px of the 96 px button wide and about 50 px tall, between the top edge and
-- the word. TOKEN CANDIDATE (lead's choice, reversible).
local CAR_ICON_SIZE = SIZE * 0.875
local ICON_CENTRE_Y = 6 + ICON_SIZE / 2 -- every icon slot is centred where the 56 px slot always was
local KEY_CHIP_H = 26
local GOLD = Color3.fromRGB(255, 204, 48) -- the one timing accent (Keys gold stays a different, nearby shape)

-- TOKEN CANDIDATES (Round 3, R3-C2): the two unavailable fills (A.Fill.Disabled was one grey for both) and the
-- Stamina glyph geometry. Preview values; the lead may retune after measuring.
local function fill(top: Color3, mid: Color3, bottom: Color3): ColorSequence
	return ColorSequence.new({
		ColorSequenceKeypoint.new(0, top),
		ColorSequenceKeypoint.new(0.5, mid),
		ColorSequenceKeypoint.new(1, bottom),
	})
end
local FILL_NO_TARGET = fill(Color3.fromRGB(176, 190, 212), Color3.fromRGB(132, 150, 180), Color3.fromRGB(98, 116, 148))
local FILL_NO_STAMINA = fill(Color3.fromRGB(190, 150, 152), Color3.fromRGB(146, 100, 108), Color3.fromRGB(104, 66, 78))
local BOLT_SIZE = 44 -- the crossed bolt that replaces the car when Stamina is empty
local BOLT_GREY = Color3.fromRGB(170, 176, 190) -- the Stamina meter's Empty grey (StaminaMeter GREY)
local BOLT_TOP = 5
local SLASH_RED = Color3.fromRGB(226, 52, 62)
local SLASH_LENGTH = 58
local LABEL_WIDTH = SIZE - 6 -- the label box; it has 3 px of padding each side
local LABEL_ONE_LINE = 30
local LABEL_TWO_LINES = 40

export type InputKind = "Keyboard" | "Touch" | "Gamepad"
export type Options = { onHopIntent: (() -> ())?, gamepadKey: string? }

-- What each display state looks like (everything except the word, which HopState owns).
type Look = {
	name: string, -- the fill's name, for the debug state
	fill: ColorSequence,
	veil: number, -- BackgroundTransparency of the dark veil over the face (1 = none)
	hatch: boolean,
	slash: boolean,
	bolt: boolean, -- the crossed bolt replaces the car
	sweep: boolean, -- the cooldown wedge is drawn
	labelSize: number, -- design px, never below Tokens.TextSize.Minimum
}

local LOOKS: { [string]: Look } = {
	Ready = {
		name = "Home",
		fill = A.Fill.Home,
		veil = 1,
		hatch = false,
		slash = false,
		bolt = false,
		sweep = false,
		labelSize = 24,
	},
	BestTiming = {
		name = "Home",
		fill = A.Fill.Home,
		veil = 1,
		hatch = false,
		slash = false,
		bolt = false,
		sweep = false,
		labelSize = 24,
	},
	Cooldown = {
		name = "Home",
		fill = A.Fill.Home,
		veil = 0.55,
		hatch = false,
		slash = false,
		bolt = false,
		sweep = true,
		labelSize = 24,
	},
	NoTarget = {
		name = "NoTarget",
		fill = FILL_NO_TARGET,
		veil = 0.45,
		hatch = true,
		slash = false,
		bolt = false,
		sweep = false,
		labelSize = 18,
	},
	OutOfStamina = {
		name = "NoStamina",
		fill = FILL_NO_STAMINA,
		veil = 1,
		hatch = false,
		slash = true,
		bolt = true,
		sweep = false,
		labelSize = 16,
	},
}

local function lookOf(display: string): Look
	return LOOKS[display] or LOOKS.Ready
end

local function midOf(sequence: ColorSequence): Color3
	local keys = sequence.Keypoints
	return keys[math.ceil(#keys / 2)].Value
end

-- The face's middle colour as the player sees it: the fill under the veil (the sweep is not counted).
local function visibleTint(look: Look): Color3
	return midOf(look.fill):Lerp(A.Ink, 1 - look.veil)
end

local HopButton = {}
HopButton.__index = HopButton

HopButton.Size = SIZE
HopButton.IconSize = ICON_SIZE
HopButton.CarIconSize = CAR_ICON_SIZE

-- The slot size an icon gets on the face: the larger car slot for HopCar while it draws no arrow, else ICON_SIZE.
function HopButton.iconSizeFor(iconName: string): number
	return if iconName == "HopCar" and Icons2.HopArrow == "None" then CAR_ICON_SIZE else ICON_SIZE
end

-- The widest line of a state's word at its size in design px (Fredoka One, the label's font, measured with
-- TextService), and whether it fits the label's text area with its outline.
function HopButton.measureLabel(display: string): (number, boolean)
	local look = lookOf(display)
	local size = math.max(look.labelSize, Tokens.TextSize.Minimum)
	local widest = 0
	for _, line in string.split(HopState.label(display), "\n") do
		local bounds = TextService:GetTextSize(line, size, Enum.Font.FredokaOne, Vector2.new(4096, 4096))
		widest = math.max(widest, bounds.X)
	end
	local outline = if look.labelSize >= 24 then A.OutlineMajor else A.OutlineMinor
	return widest, widest + 2 * outline <= LABEL_WIDTH - 6
end

-- The face of the button (lip, face, icon, crossed bolt, veil, label, hatching, slash, cooldown sweep) and the one
-- function that dresses it for a display state. The live button and the playground specimen both use these two, so
-- a specimen shows exactly what the button draws.
type Parts = {
	face: Frame,
	grad: UIGradient,
	icon: Frame,
	bolt: Frame,
	veil: Frame,
	label: TextLabel,
	hatch: Frame,
	slash: Frame,
	sweep: Arc.Arc,
}

local function buildFace(body: GuiObject, iconName: string?): Parts
	local lip = make("Frame", {
		Name = "Lip",
		Position = UDim2.fromOffset(0, A.Button.DepthOffset),
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = A.Ink,
		ZIndex = 3,
		Parent = body,
	})
	Arcade.corner(lip, 12)
	local face = make("Frame", {
		Name = "Face",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		ClipsDescendants = true,
		ZIndex = 4,
		Parent = body,
	})
	Arcade.corner(face, 12)
	Arcade.outline(face, "Button")
	local grad = make("UIGradient", { Color = A.Fill.Home, Rotation = 90, Parent = face })
	Arcade.gloss(face)
	local name = iconName or "HopCar"
	local iconSize = HopButton.iconSizeFor(name)
	local icon = make("Frame", {
		Name = "Icon",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0, ICON_CENTRE_Y),
		Size = UDim2.fromOffset(iconSize, iconSize),
		BackgroundTransparency = 1,
		ZIndex = 7,
		Parent = face,
	})
	Arcade.icon(icon, name)
	-- Out of Stamina: the car steps aside for a big grey cracked bolt with a red slash across it
	local bolt = make("Frame", {
		Name = "Bolt",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, BOLT_TOP),
		Size = UDim2.fromOffset(BOLT_SIZE, BOLT_SIZE),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 7,
		Parent = face,
	})
	-- the Stamina meter's own sharp bolt, grey and cracked as the meter shows it at zero (Adam, 2026-10-28: the
	-- Icons2 BoltEmpty blob "isnt shaped like a lightning bolt")
	local boltArt = StaminaBolt.new(bolt, { height = BOLT_SIZE, colour = BOLT_GREY, crack = true, name = "Art", z = 7 })
	boltArt.root.AnchorPoint = Vector2.new(0.5, 0.5)
	boltArt.root.Position = UDim2.fromScale(0.5, 0.5)
	boltArt:setCracked(true)
	-- dim veil over the icon (structure cue for cooldown / no target)
	local veil = make("Frame", {
		Name = "Dim",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = A.Ink,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 9,
		Parent = face,
	})
	Arcade.corner(veil, 12)
	local label = Arcade.text(face, { text = "HOP", role = "Button", name = "Label", size = 24, z = 12 })
	label.AnchorPoint = Vector2.new(0.5, 1)
	label.Position = UDim2.new(0.5, 0, 1, -2)
	label.Size = UDim2.new(1, -6, 0, LABEL_ONE_LINE)
	-- diagonal hatching for NoTarget
	local hatch = make("Frame", {
		Name = "Hatch",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		Visible = false,
		ZIndex = 10,
		Parent = face,
	})
	for i = -2, 5 do
		make("Frame", {
			Name = "Stripe" .. i,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(i * 22, SIZE / 2),
			Size = UDim2.fromOffset(6, SIZE * 1.8),
			Rotation = 35,
			BackgroundColor3 = A.Ink,
			BackgroundTransparency = 0.72,
			BorderSizePixel = 0,
			ZIndex = 10,
			Parent = hatch,
		})
	end
	-- OutOfStamina: a red slash across the bolt (a different look from NoTarget's hatching)
	local slash = make("Frame", {
		Name = "Slash",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(SIZE / 2, BOLT_TOP + BOLT_SIZE / 2),
		Size = UDim2.fromOffset(SLASH_LENGTH, 7),
		Rotation = -38,
		BackgroundColor3 = SLASH_RED,
		Visible = false,
		ZIndex = 13,
		Parent = face,
	})
	Arcade.corner(slash, 4)
	Arcade.outline(slash, "Minor")
	-- cooldown sweep (dark wedge shrinking from hopCooldown01 to 0)
	local sweep = Arc.new(face, SIZE * 1.5, A.Ink, 0.5, 11)
	return {
		face = face,
		grad = grad,
		icon = icon,
		bolt = bolt,
		veil = veil,
		label = label,
		hatch = hatch,
		slash = slash,
		sweep = sweep,
	}
end

local function applyLook(parts: Parts, display: string, cooldown: number)
	local look = lookOf(display)
	parts.grad.Color = look.fill
	parts.hatch.Visible = look.hatch
	parts.slash.Visible = look.slash
	parts.bolt.Visible = look.bolt
	parts.icon.Visible = not look.bolt
	parts.veil.BackgroundTransparency = look.veil
	-- the wedge belongs to the Cooldown state only (an empty Stamina bar outranks it, and NoTarget has none)
	parts.sweep:set(if look.sweep then cooldown else 0)
	local label = parts.label
	local text = HopState.label(display)
	label.Text = text
	label.TextSize = math.max(look.labelSize, Tokens.TextSize.Minimum)
	label.TextTransparency = 0
	label.Size = UDim2.new(1, -6, 0, if string.find(text, "\n", 1, true) then LABEL_TWO_LINES else LABEL_ONE_LINE)
	local stroke = label:FindFirstChildOfClass("UIStroke")
	if stroke then
		stroke.Thickness = if look.labelSize >= 24 then A.OutlineMajor else A.OutlineMinor
	end
end

-- Playground specimen: one face in `display`, with no store, input or sounds. The caller owns (and destroys) it.
-- `iconName` (optional) draws another Icons2 name in the icon slot, e.g. "HopCar_B" to compare the arrow candidates;
-- the live button never passes it and always draws "HopCar".
function HopButton.buildSpecimenFace(parent: Instance, display: string, cooldown01: number?, iconName: string?): Frame
	local body = make("Frame", {
		Name = "HopSpecimen_" .. HopState.key(display),
		Size = UDim2.fromOffset(SIZE, SIZE),
		BackgroundTransparency = 1,
		Parent = parent,
	})
	local parts = buildFace(body, iconName)
	applyLook(parts, display, math.clamp(cooldown01 or 0, 0, 1))
	return body
end

function HopButton.new(ctx: RunLayout.Ctx, options: Options?)
	local self = setmetatable({}, HopButton)
	local opts: Options = options or {}
	self._ctx = ctx
	self._trove = Trove.new()
	self._dead = false
	self._visible = true
	self._state = "" :: string
	self._cue = nil :: any
	self._accents = 0
	self._cooldown = 0
	self._intents = 0
	self._onIntent = opts.onHopIntent
	self._gamepadKey = opts.gamepadKey or "A"
	self._forced = nil :: InputKind?
	self._input = "Keyboard" :: InputKind
	self._rect = nil :: RunLayout.Rect?
	self._conflict = nil :: string?
	self._reservedHit = nil :: string?
	self._last = -math.huge

	local root = self._trove:Add(RunLayout.canvas(ctx, "HopButton"))
	self.root = root
	local holder = make("Frame", {
		Name = "Hop",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(SIZE, SIZE + 4),
		ZIndex = 2,
		Parent = root,
	})
	self._holder = holder
	local body = make("TextButton", {
		Name = "Body",
		Size = UDim2.fromOffset(SIZE, SIZE),
		BackgroundTransparency = 1,
		AutoButtonColor = false,
		Text = "",
		Selectable = true,
		ZIndex = 3,
		Parent = holder,
	})
	local press = make("UIScale", { Name = "Press", Parent = body })
	self._body = body
	self._press = press
	local parts = buildFace(body)
	self._parts = parts
	-- Timing ring outside the boundary
	local ring = make("Frame", {
		Name = "TimingRing",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, 16, 1, 16),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 2,
		Parent = body,
	})
	Arcade.corner(ring, 18)
	local ringStroke = make("UIStroke", { Thickness = 5, Color = GOLD, Parent = ring })
	local ringScale = make("UIScale", { Name = "Pulse", Parent = ring })
	self._ring, self._ringStroke, self._ringScale = ring, ringStroke, ringScale
	-- input key chip (keyboard / gamepad)
	local chip = make("Frame", {
		Name = "KeyChip",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 1, A.Button.DepthOffset + 4),
		Size = UDim2.fromOffset(78, KEY_CHIP_H),
		BackgroundColor3 = Color3.new(1, 1, 1),
		Visible = false,
		ZIndex = 5,
		Parent = holder,
	})
	Arcade.corner(chip, 6)
	Arcade.outline(chip, "Major")
	local chipText = Arcade.text(chip, { text = "Space", role = "Small", name = "Key", colour = A.Ink, z = 6 })
	chipText.Size = UDim2.fromScale(1, 1)
	local chipStroke = chipText:FindFirstChildOfClass("UIStroke")
	if chipStroke then
		chipStroke.Enabled = false -- dark text on a white key cap needs no outline
	end
	self._chip, self._chipText = chip, chipText

	self._trove:Connect(body.Activated, function()
		self:_intent()
	end)
	self._trove:Connect(body.MouseButton1Down, function()
		if self:_pressable() then
			Motion.tween(press, "press", Motion.info(A.Motion.Press), { Scale = 0.94 })
		end
	end)
	self._trove:Connect(body.MouseButton1Up, function()
		Motion.tween(press, "press", Motion.info(A.Motion.Release), { Scale = 1 })
	end)
	self._trove:Connect(body.MouseLeave, function()
		Motion.tween(press, "press", Motion.info(A.Motion.Release), { Scale = 1 })
	end)
	self._trove:Connect(UserInputService.LastInputTypeChanged, function()
		self:_applyInput()
	end)
	pcall(function()
		self._trove:Connect(UserInputService:GetPropertyChangedSignal("PreferredInput"), function()
			self:_applyInput()
		end)
	end)
	self._trove:Add(function()
		Motion.cancelAll(press)
		Motion.cancelAll(ringScale)
		Motion.cancelAll(ringStroke)
	end)
	self._trove:Add(ctx.store:subscribe("run", function()
		self:_apply()
	end))
	self._trove:Connect(ctx.store.ModeChanged, function()
		self:_apply()
	end)
	self._trove:Add(Motion.onReducedChanged(function()
		self:_applyRing()
	end))
	self:layout()
	return self
end

export type HopButton = typeof(HopButton.new((nil :: any) :: RunLayout.Ctx))

function HopButton._pressable(self: HopButton): boolean
	return self._state == "Ready" or self._state == "BestTiming"
end

function HopButton._intent(self: HopButton)
	local now = os.clock()
	if not self:_pressable() or now - self._last < 0.25 then
		return
	end
	self._last = now
	self._intents += 1
	Sounds.play("Hop")
	local fn = self._onIntent
	if fn then
		fn()
	end
end

function HopButton._detectInput(self: HopButton): InputKind
	if self._forced then
		return self._forced :: InputKind
	end
	if self._ctx.screen:profile().touch then
		return "Touch"
	end
	local kind: InputKind? = nil
	pcall(function()
		local p = (UserInputService :: any).PreferredInput
		if p == (Enum :: any).PreferredInput.Gamepad then
			kind = "Gamepad"
		elseif p == (Enum :: any).PreferredInput.Touch then
			kind = "Touch"
		elseif p ~= nil then
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

function HopButton._applyInput(self: HopButton)
	local kind = self:_detectInput()
	self._input = kind
	self._chip.Visible = kind ~= "Touch"
	if kind == "Keyboard" then
		self._chipText.Text = "Space"
		self._chip.Size = UDim2.fromOffset(78, KEY_CHIP_H)
	elseif kind == "Gamepad" then
		self._chipText.Text = self._gamepadKey
		self._chip.Size = UDim2.fromOffset(KEY_CHIP_H + 8, KEY_CHIP_H + 8)
		self._chip:FindFirstChildOfClass("UICorner").CornerRadius = UDim.new(0.5, 0)
	end
	if kind == "Keyboard" then
		self._chip:FindFirstChildOfClass("UICorner").CornerRadius = UDim.new(0, 6)
	end
end

function HopButton._applyRing(self: HopButton)
	local timing = self._state == "BestTiming"
	local ring, scale, stroke = self._ring, self._ringScale, self._ringStroke
	Motion.cancelAll(scale)
	Motion.cancelAll(stroke)
	ring.Visible = timing
	scale.Scale = 1
	stroke.Transparency = 0
end

-- One brief pop when a best-timing window opens (an event from HopCue, not a loop); none in reduced motion.
function HopButton._accent(self: HopButton)
	self._accents += 1
	if Motion.reduced() or not self._visible or not self._ring.Visible then
		return
	end
	local scale = self._ringScale
	scale.Scale = 1.16
	Motion.tween(scale, "accent", Motion.info(0.3), { Scale = 1 })
end

function HopButton._hookCue(self: HopButton)
	if self._cue then
		return
	end
	local cue = RunBus.get(self._ctx, "hopCue")
	if not cue then
		return
	end
	self._cue = cue
	self._trove:Add(cue.Changed:Connect(function()
		self:_apply()
	end))
	self._trove:Add(cue.Accent:Connect(function()
		task.defer(function()
			if not self._dead then
				self:_accent()
			end
		end)
	end))
end

function HopButton._apply(self: HopButton)
	self:_hookCue()
	local storeState = self._ctx.store:get()
	local run = storeState.run
	self._holder.Visible = storeState.mode == "Run" and run ~= nil
	local cue = self._cue
	local display: string = if cue and cue.display then cue:display() else HopState.resolve(run)
	local cooldown = if run then math.clamp(run.hopCooldown01, 0, 1) else 0
	self._cooldown = cooldown
	local changed = display ~= self._state
	self._state = display
	applyLook(self._parts, display, cooldown)
	self._body.Active = display ~= "NoTarget" and display ~= "OutOfStamina"
	if changed then
		self:_applyRing()
	end
end

function HopButton.layout(self: HopButton)
	local ctx = self._ctx
	RunLayout.fit(ctx, self.root)
	local rect, conflict = RunLayout.hopRect(ctx)
	self._rect = rect
	self._conflict = conflict
	self._holder.Position = UDim2.fromOffset(rect.pos.X, rect.pos.Y)
	local pos, size = RunLayout.toDevice(ctx, rect)
	self._reservedHit = ctx.screen:overlapsReserved(pos, size)
	self:_applyInput()
	-- the key chip sits under the button on desktop; above it when that would leave the canvas
	local d = RunLayout.design(ctx)
	local below = rect.pos.Y + SIZE + A.Button.DepthOffset + 4 + KEY_CHIP_H + 4 <= d.Y
	self._chip.AnchorPoint = if below then Vector2.new(0.5, 0) else Vector2.new(0.5, 1)
	self._chip.Position = if below
		then UDim2.new(0.5, 0, 0, SIZE + A.Button.DepthOffset + 4)
		else UDim2.new(0.5, 0, 0, -6)
	self:_apply()
end

function HopButton.setHopIntent(self: HopButton, fn: (() -> ())?)
	self._onIntent = fn
end

function HopButton.setInputKind(self: HopButton, kind: InputKind?)
	self._forced = kind
	self:_applyInput()
end

function HopButton.setVisible(self: HopButton, on: boolean)
	self._visible = on
	self.root.Visible = on
	self:_applyRing()
end

-- Live object counts for leak checks: the component's own instances and what its Trove holds (connections,
-- subscriptions, cleanup functions). It starts no thread and no render step.
local function troveSize(trove: any): number
	local objects = trove._objects
	return if type(objects) == "table" then #objects else 0
end

function HopButton.getDebugState(self: HopButton): { [string]: any }
	local rect = self._rect
	local parts = self._parts
	local look = lookOf(self._state)
	local labelWidth, labelFits = HopButton.measureLabel(self._state)
	return {
		visible = self._visible,
		input = self._input,
		forcedInput = self._forced,
		keyLabel = if self._chip.Visible then self._chipText.Text else nil,
		state = self._state,
		display = self._state,
		-- Round 3: one key, one tint and one word per state, so the unavailable looks can be told apart
		stateKey = HopState.key(self._state),
		fillName = look.name,
		tint = visibleTint(look):ToHex(),
		labelSize = parts.label.TextSize,
		labelWidth = labelWidth,
		labelFits = labelFits,
		carIcon = parts.icon.Visible,
		boltIcon = parts.bolt.Visible,
		cooldown01 = self._cooldown,
		sweep = parts.sweep:get(),
		label = parts.label.Text,
		hatched = parts.hatch.Visible,
		iconDimmed = parts.veil.BackgroundTransparency < 1,
		ringShown = self._ring.Visible,
		ringColour = self._ringStroke.Color,
		ringPulsing = false, -- the ring is steady; only the window’s opening pops it once
		accents = self._accents,
		outOfStamina = parts.slash.Visible,
		cueMounted = self._cue ~= nil,
		intents = self._intents,
		box = rect and RunLayout.describe(rect),
		conflict = self._conflict,
		overlapsReserved = self._reservedHit,
		overlapsProtected = rect ~= nil and RunLayout.overlaps(rect, RunLayout.protected(self._ctx)),
		instances = #self.root:GetDescendants(),
		connections = troveSize(self._trove),
		threads = 0,
	}
end

function HopButton.destroy(self: HopButton)
	self._dead = true
	self._trove:Destroy()
end

return HopButton
