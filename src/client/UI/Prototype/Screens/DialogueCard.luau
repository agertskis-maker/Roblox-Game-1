--!strict
-- DialogueCard: a friendly character card for locked portals, the Raceway shopkeeper and (optionally) the tutorial (Lane 3,
-- Round 2 N11-01; PREVIEW). A title bar with an icon and a red X, an ORIGINAL mechanic portrait ("Coach Roxy", drawn from UI
-- shapes: a reversible local name proposal, not approved lore), a speech bubble with typed-out text, an optional progress bar
-- with "N TO GO", and a big green GOT IT!.
--
--   local card = DialogueCard.show(parent, spec) -> Handle
--       spec = { key?, title, icon?, portraitName, portraitImage?, text (string | (remaining) -> string),
--                progress = { label, current, target }?, primary = { label?, onActivate? }?,
--                ready = { text, primary? }?, onClose? }
--   card:setProgress(current, target?)   -- live update; remaining = max(0, target - current); at 0 the card shows Ready
--   card:setText(text)  card:reveal()  card:close()  card:isOpen()  card:pressPrimary() -> boolean
--   card:getDebugState()  card:touchReport()
--   DialogueCard.isSuppressed(key) / DialogueCard.clearSuppression(key)   -- see "REPEATS" below
--   DialogueCard.new(ctx, options) -> Controller   -- the playground mount: controller:open(), :setPreset(name), :setProgress(n)
--   DialogueCard.geometry(designSize, hasProgress) -> Geo
--
-- BEHAVIOUR (N11-01a). Typewriter at 28 characters a second, never longer than 2.5 s for a short message (4 s for a long one);
-- tapping the speech area reveals all of it (and does nothing else: no purchase can fire from the reveal tap); reduced motion
-- shows the whole message at once. Default controller focus is GOT IT! and closing puts the selection back where it was. A
-- locked-portal card reads "Collect N more <World> cars to unlock <Portal>." with current / target in the SAME unit and
-- "N TO GO" computed as max(0, target - current); a missing or invalid requirement says "Unlock details aren't available yet."
-- and shows no bar; when the requirement is met while the card is open it switches to Ready and offers only the existing travel
-- action (spec.ready.primary), never a new unlock rule. The shopkeeper variant only points to the existing upgrade panel.
--
-- REPEATS. Dismissing a card with a `key` marks that key suppressed until the caller calls clearSuppression(key) (the player
-- leaving the proximity zone), so standing in the zone does not reopen it at once. The card itself never decides proximity.
--
-- Touch: GOT IT! is 56 px tall, the X is 48. Hover, press and gamepad selection come from the kit buttons.

local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Prototype = script.Parent.Parent
local Arcade = require(Prototype.Arcade)
local CardKit = require(script.Parent.CardKit)
local DialogueFixtures = require(Prototype.SupportFixtures.DialogueFixtures)
local Motion = require(Prototype.Motion)
local Overlay = require(script.Parent.Overlay)
local PreviewTokens = require(Prototype.PreviewTokens)
local Sounds = require(Prototype.Sounds)
local SupportKit = require(script.Parent.SupportKit)
local Format = require(ReplicatedStorage.Shared.UI.Format)
local Tokens = require(ReplicatedStorage.Shared.UI.Tokens)
local Trove = require(ReplicatedStorage.Packages.Trove)

local A = PreviewTokens.Arcade
local make = Arcade.make

local DialogueCard = {}

DialogueCard.CharactersPerSecond = 28
DialogueCard.ShortSeconds = 2.5
DialogueCard.LongSeconds = 4
DialogueCard.UnknownText = "Unlock details aren't available yet."

local BORDER = 5
local GAP = 6
local SIDE_PAD = 8

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

export type Progress = { label: string, current: number, target: number, cash: boolean? } -- cash: numbers drawn with Format.cash
export type Action = { label: string?, onActivate: (() -> ())? }

export type Spec = {
	key: string?, -- identity for the repeat suppression ("portal:Dusty Highway")
	title: string,
	icon: string?, -- a painter name for the title bar ("Lock", "Raceway", "Info")
	portraitName: string,
	portraitImage: string?, -- the real portrait art once it exists; nil draws the UI-shape placeholder
	text: string | ((remaining: number) -> string),
	progress: Progress?,
	-- Round 7 (A-05): a second bar under the first (Coach Roxy's locked portal: CARS and CASH, like the reference's goal card). With
	-- two bars each row is "LABEL [ count ]" and the remaining-amount text is left to the speech bubble.
	progress2: Progress?,
	primary: Action?, -- default GOT IT! (closes)
	ready: { text: string, primary: Action? }?,
	onClose: (() -> ())?,
}

export type Rect = { x: number, y: number, w: number, h: number }

export type Geo = {
	fit: SupportKit.Fit,
	cw: number,
	ch: number,
	stageH: number,
	plateH: number,
	overhang: number,
	bodyW: number,
	bodyH: number,
	portrait: Rect,
	bubble: Rect,
	progress: Rect?,
	button: Vector2,
	buttonY: number, -- the button's bottom edge, in body px
	rightX: number,
	rightW: number,
	textSize: number,
}

export type DebugState = {
	open: boolean,
	fit: string,
	title: string,
	portrait: string,
	text: string,
	typedChars: number,
	totalChars: number,
	typing: boolean,
	remaining: number?,
	ready: boolean,
	progressText: string,
	togoText: string,
	progressVisible: boolean,
	primaryLabel: string,
	primaryCalls: number,
	closeCalls: number,
	reduced: boolean,
}

export type Handle = {
	root: Frame,
	setProgress: (self: Handle, current: number, target: number?) -> (),
	setText: (self: Handle, text: string) -> (),
	reveal: (self: Handle) -> (),
	close: (self: Handle) -> (),
	isOpen: (self: Handle) -> boolean,
	pressPrimary: (self: Handle) -> boolean,
	getDebugState: (self: Handle) -> DebugState,
	touchReport: (self: Handle) -> { { name: string, w: number, h: number } },
}

-- REPEAT SUPPRESSION --------------------------------------------------------------------------------------------------

local suppressed: { [string]: boolean } = {}

function DialogueCard.isSuppressed(key: string): boolean
	return suppressed[key] == true
end

function DialogueCard.clearSuppression(key: string)
	suppressed[key] = nil
end

-- GEOMETRY ------------------------------------------------------------------------------------------------------------

-- The portrait column on the left (about 26 to 32 percent of the card), the speech bubble, the progress panel and GOT IT! on
-- the right. A pure function of the design-px viewport. Phone landscape (about 750 x 325 and 573 x 310) keeps a smaller
-- portrait and a shorter bubble; nothing is a fixed 300-wide box.
function DialogueCard.geometry(ds: Vector2, hasProgress: boolean): Geo
	local fit = SupportKit.fitFor(ds)
	local cw, plateH, textSize, button, bubbleH, progressH
	if fit == "Compact" then
		cw, plateH, textSize, button = math.min(ds.X - 16, 560), 46, 18, Vector2.new(200, 56)
		bubbleH, progressH = if hasProgress then 70 else 112, if hasProgress then 62 else 0
	elseif fit == "Regular" then
		cw, plateH, textSize, button = math.min(ds.X - 32, 620), 52, 20, Vector2.new(230, 60)
		bubbleH, progressH = if hasProgress then 96 else 150, if hasProgress then 84 else 0
	else
		cw, plateH, textSize, button = math.min(ds.X - 48, 700), 58, 24, Vector2.new(260, 66)
		bubbleH, progressH = if hasProgress then 120 else 180, if hasProgress then 100 else 0
	end
	local overhang = plateH / 2
	local buttonBox = button.Y + 4
	local colH = bubbleH + (if progressH > 0 then GAP + progressH else 0) + GAP + buttonBox
	local topPad = overhang - BORDER + 8
	local bodyW = cw - BORDER * 2
	local bodyH = topPad + colH + 10
	local ch = bodyH + BORDER * 2
	local portraitW = math.clamp(math.floor(colH / 1.25), 96, math.floor(bodyW * 0.32))
	local rightX = SIDE_PAD + portraitW + 16
	local rightW = bodyW - rightX - SIDE_PAD
	return {
		fit = fit,
		cw = cw,
		ch = ch,
		stageH = overhang + ch,
		plateH = plateH,
		overhang = overhang,
		bodyW = bodyW,
		bodyH = bodyH,
		portrait = { x = SIDE_PAD, y = topPad, w = portraitW, h = colH },
		bubble = { x = rightX, y = topPad, w = rightW, h = bubbleH },
		progress = if progressH > 0 then { x = rightX, y = topPad + bubbleH + GAP, w = rightW, h = progressH } else nil,
		button = button,
		buttonY = topPad + colH,
		rightX = rightX,
		rightW = rightW,
		textSize = textSize,
	}
end

-- THE PORTRAIT --------------------------------------------------------------------------------------------------------

-- Coach Roxy: an original friendly mechanic built from shapes in a 100 x 120 unit box (red cap with a wrench mark, golden
-- ponytail, blue overalls, a spanner in her hand). Drawn in fractions of its box, so it scales cleanly and costs about 40
-- frames, built once. Replace it by passing spec.portraitImage when the real art exists.
local function unit(
	parent: Instance,
	name: string,
	x: number,
	y: number,
	w: number,
	h: number,
	colour: Color3,
	z: number,
	round: (boolean | number)?,
	rotation: number?
): Frame
	local f: Frame = make("Frame", {
		Name = name,
		Position = UDim2.fromScale(x / 100, y / 120),
		Size = UDim2.fromScale(w / 100, h / 120),
		Rotation = rotation or 0,
		BackgroundColor3 = colour,
		BorderSizePixel = 0,
		ZIndex = z,
		Parent = parent,
	})
	if round == true then
		make("UICorner", { CornerRadius = UDim.new(0.5, 0), Parent = f })
	elseif type(round) == "number" then
		make("UICorner", { CornerRadius = UDim.new(round, 0), Parent = f })
	end
	return f
end

local function drawPortrait(art: Frame, z: number)
	local skin = rgb(255, 208, 164)
	local hair = rgb(232, 168, 60)
	local navy = rgb(46, 84, 170)
	local red = rgb(226, 58, 66)
	local function inked(f: Frame): Frame
		Arcade.outline(f, "Minor")
		return f
	end
	-- hair behind the head, and the ponytail
	inked(unit(art, "HairBack", 20, 20, 60, 62, hair, z, true))
	inked(unit(art, "Ponytail", 70, 36, 22, 44, hair, z, true, -18))
	-- shoulders and overalls
	inked(unit(art, "Sleeves", 8, 86, 84, 30, rgb(244, 244, 250), z + 1, 0.4))
	inked(unit(art, "Overalls", 18, 92, 64, 40, navy, z + 2, 0.25))
	unit(art, "Bib", 36, 96, 28, 24, rgb(66, 108, 196), z + 3, 0.15)
	unit(art, "Pocket", 42, 104, 16, 10, rgb(40, 74, 150), z + 4, 0.2)
	inked(unit(art, "StrapL", 30, 84, 8, 16, navy, z + 3, 0.3))
	inked(unit(art, "StrapR", 62, 84, 8, 16, navy, z + 3, 0.3))
	-- neck and face
	unit(art, "Neck", 43, 76, 14, 14, rgb(238, 184, 140), z + 2)
	inked(unit(art, "Face", 28, 32, 44, 48, skin, z + 5, true))
	unit(art, "CheekL", 31, 62, 9, 6, rgb(255, 150, 140), z + 6, true)
	unit(art, "CheekR", 60, 62, 9, 6, rgb(255, 150, 140), z + 6, true)
	-- eyes with a spark, eyebrows, nose and a big friendly smile
	unit(art, "EyeL", 37, 52, 8, 11, rgb(30, 40, 70), z + 7, true)
	unit(art, "EyeR", 55, 52, 8, 11, rgb(30, 40, 70), z + 7, true)
	unit(art, "SparkL", 40, 53, 3, 4, Color3.new(1, 1, 1), z + 8, true)
	unit(art, "SparkR", 58, 53, 3, 4, Color3.new(1, 1, 1), z + 8, true)
	unit(art, "BrowL", 36, 46, 10, 2.5, rgb(150, 92, 40), z + 7, true, -8)
	unit(art, "BrowR", 54, 46, 10, 2.5, rgb(150, 92, 40), z + 7, true, 8)
	unit(art, "Nose", 47, 58, 6, 4, rgb(238, 176, 130), z + 7, true)
	-- a friendly CLOSED smile (the old open red rectangle read as shouting): a dark crescent, made of one ellipse with a
	-- skin-coloured ellipse cut from its top and its sides, so the ends curl up and no outline box is needed
	unit(art, "Mouth", 40, 65, 20, 11, rgb(122, 38, 48), z + 7, true)
	unit(art, "SmileCut", 38.5, 62, 23, 11, skin, z + 8, true)
	-- hair framing the face under the cap
	unit(art, "LockL", 24, 42, 9, 24, hair, z + 6, true)
	unit(art, "LockR", 67, 42, 9, 24, hair, z + 6, true)
	-- the red cap: a dome, a brim, a white front panel with a small wrench mark
	inked(unit(art, "CapDome", 25, 14, 50, 30, red, z + 9, 0.5))
	inked(unit(art, "Brim", 22, 38, 56, 8, rgb(184, 36, 48), z + 10, 0.5))
	inked(unit(art, "CapPanel", 38, 18, 24, 20, rgb(248, 248, 252), z + 10, 0.4))
	unit(art, "MarkHandle", 49, 22, 3, 13, rgb(40, 52, 96), z + 11, 0.3, 35)
	unit(art, "MarkHeadA", 44, 21, 5, 5, rgb(40, 52, 96), z + 11, true)
	unit(art, "MarkHeadB", 50, 30, 5, 5, rgb(40, 52, 96), z + 11, true)
	-- a spanner held up at the right
	inked(unit(art, "Spanner", 82, 70, 6, 42, rgb(176, 184, 198), z + 12, 0.4, 24))
	inked(unit(art, "SpannerHead", 78, 62, 14, 14, rgb(176, 184, 198), z + 12, true))
	unit(art, "SpannerSlot", 82, 60, 6, 8, rgb(80, 150, 240), z + 13, 0.2, 24)
	inked(unit(art, "Glove", 80, 88, 14, 14, rgb(110, 70, 44), z + 13, true))
end

-- BUILD ---------------------------------------------------------------------------------------------------------------

local function lastInputIsGamepad(): boolean
	return UserInputService:GetLastInputType().Name:sub(1, 7) == "Gamepad"
end

function DialogueCard.show(parent: GuiBase2d, spec: Spec): Handle
	local trove = Trove.new()
	local typeTrove = trove:Extend()
	local closed = false
	local primaryCalls, closeCalls = 0, 0
	local primaryGuard = SupportKit.guard()
	local typing = false
	local totalChars = 0
	local currentText = ""
	local progress: Progress? = if spec.progress then table.clone(spec.progress) else nil
	local progress2: Progress? = if spec.progress2 then table.clone(spec.progress2) else nil
	local readyShown = false
	local builtButton = ""
	local priorSelection: GuiObject? = GuiService.SelectedObject
	local actionName = "Lane3Dialogue_" .. HttpService:GenerateGUID(false)
	local geo = DialogueCard.geometry(Vector2.new(750, 325), progress ~= nil)
	local handle: Handle

	local parentSize = function(): Vector2
		return (parent :: any).AbsoluteSize
	end
	local function scaleNow(): number
		return Tokens.windowScale(parentSize())
	end

	local root: Frame = trove:Add(make("Frame", {
		Name = "DialogueCard",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 1,
		Parent = parent,
	}))
	local hudScale: UIScale = make("UIScale", { Name = "HudScale", Parent = root })
	local dim: TextButton = make("TextButton", {
		Name = "Dim",
		BackgroundColor3 = A.Ink,
		BackgroundTransparency = 1,
		AutoButtonColor = false,
		Selectable = false,
		Text = "",
		Size = UDim2.fromScale(1, 1),
		ZIndex = 1,
		Parent = root,
	})
	local content: Frame = make("Frame", {
		Name = "Content",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1),
		ZIndex = 2,
		Parent = root,
	})
	local pop: UIScale = make("UIScale", { Name = "Pop", Parent = content })

	local stage: Frame = make("Frame", {
		Name = "Stage",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(560, 270),
		BackgroundTransparency = 1,
		ZIndex = 3,
		Parent = content,
	})
	local card = CardKit.card(stage, { name = "Card", z = 3, border = BORDER, radius = 16 })
	local body = card.body
	local plate = CardKit.titlePlate(stage, {
		text = spec.title,
		icon = spec.icon,
		iconFallback = { "Padlock", "Info" },
		size = 30,
		height = 52,
		face = "White",
		top = rgb(255, 224, 92),
		bottom = rgb(240, 166, 20),
		edge = rgb(255, 244, 170),
		rightInset = 62,
		z = 20,
	})
	local closeX = SupportKit.closeX(stage, function()
		handle:close()
	end)
	trove:Add(closeX.trove)
	closeX.root.ZIndex = 24

	-- the portrait column ----------------------------------------------------------------------------------------------
	local portraitBack: Frame = make("Frame", {
		Name = "Portrait",
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		ClipsDescendants = true,
		ZIndex = 6,
		Parent = body,
	})
	Arcade.corner(portraitBack, 12)
	Arcade.outline(portraitBack, "Button")
	make("UIGradient", {
		Color = ColorSequence.new(rgb(140, 210, 255), rgb(70, 150, 240)),
		Rotation = 90,
		Parent = portraitBack,
	})
	local artHolder: Frame = make("Frame", {
		Name = "Art",
		AnchorPoint = Vector2.new(0.5, 1),
		BackgroundTransparency = 1,
		ZIndex = 7,
		Parent = portraitBack,
	})
	-- Round 7 (A-05): Coach Roxy's new portrait (cut from R7-IMG-01, image 106010075891034, owned by peskaface) wherever she appears
	local portraitImage = spec.portraitImage
		or (if spec.portraitName == "Coach Roxy" then "rbxassetid://106010075891034" else nil)
	if portraitImage then
		make("ImageLabel", {
			Name = "PortraitImage",
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Image = portraitImage,
			ScaleType = Enum.ScaleType.Fit,
			ZIndex = 8,
			Parent = artHolder,
		})
	else
		drawPortrait(artHolder, 8)
	end
	local namePlate: Frame = make("Frame", {
		Name = "NamePlate",
		AnchorPoint = Vector2.new(0.5, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		ZIndex = 30,
		Parent = portraitBack,
	})
	Arcade.corner(namePlate, 8)
	Arcade.outline(namePlate, "Button")
	make("UIGradient", { Color = A.Fill.Gold, Rotation = 90, Parent = namePlate })
	local nameLabel = CardKit.ink(namePlate, string.upper(spec.portraitName), 18, { name = "Name", z = 31 })
	nameLabel.Size = UDim2.new(1, -8, 1, 0)
	nameLabel.Position = UDim2.fromOffset(4, 0)

	-- the speech bubble: its tail is a turned square UNDER the bubble body, so the outline never crosses the cream
	local bubbleTail: Frame = make("Frame", {
		Name = "Tail",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(18, 18),
		Rotation = 45,
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		ZIndex = 6,
		Parent = body,
	})
	Arcade.outline(bubbleTail, "Button")
	local bubble: Frame = make("Frame", {
		Name = "Bubble",
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		ZIndex = 7,
		Parent = body,
	})
	Arcade.corner(bubble, 14)
	Arcade.outline(bubble, "Button")
	local speech: TextLabel = make("TextLabel", {
		Name = "Speech",
		BackgroundTransparency = 1,
		FontFace = Tokens.font(),
		Text = "",
		TextSize = 20,
		TextColor3 = CardKit.Navy,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
		ZIndex = 9,
		Parent = bubble,
	})
	-- tapping the speech area reveals the rest of the text and does NOTHING else
	local speechHit: TextButton = make("TextButton", {
		Name = "SpeechHit",
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false,
		Selectable = false,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 10,
		Parent = bubble,
	})

	-- the progress panel ------------------------------------------------------------------------------------------------
	local panel: Frame = make("Frame", {
		Name = "Progress",
		BackgroundColor3 = rgb(214, 236, 255),
		BorderSizePixel = 0,
		ZIndex = 7,
		Parent = body,
	})
	Arcade.corner(panel, 12)
	Arcade.outline(panel, "Button")
	local progressLabel = CardKit.ink(panel, "", 18, { name = "Label", xAlign = Enum.TextXAlignment.Left, z = 9 })
	local togoLabel = CardKit.ink(panel, "", 18, { name = "ToGo", xAlign = Enum.TextXAlignment.Right, z = 9 })
	local track: Frame = make("Frame", {
		Name = "Track",
		BackgroundColor3 = rgb(40, 52, 86),
		BorderSizePixel = 0,
		ZIndex = 8,
		Parent = panel,
	})
	Arcade.corner(track, 9)
	Arcade.outline(track, "Minor")
	local fill: Frame = make("Frame", {
		Name = "Fill",
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		Size = UDim2.fromScale(0, 1),
		ZIndex = 9,
		Parent = track,
	})
	Arcade.corner(fill, 9)
	local fillGradient: UIGradient = make("UIGradient", { Color = A.Fill.Garage, Rotation = 90, Parent = fill })
	local countLabel = Arcade.text(track, { text = "", role = "Label", name = "Count", z = 11 })
	countLabel.Size = UDim2.fromScale(1, 1)
	countLabel.Position = UDim2.fromScale(0, 0)
	-- the second bar (A-05), drawn only when spec.progress2 is set
	local label2 = CardKit.ink(panel, "", 18, { name = "Label2", xAlign = Enum.TextXAlignment.Left, z = 9 })
	local track2: Frame = make("Frame", {
		Name = "Track2",
		BackgroundColor3 = rgb(40, 52, 86),
		BorderSizePixel = 0,
		ZIndex = 8,
		Visible = false,
		Parent = panel,
	})
	Arcade.corner(track2, 9)
	Arcade.outline(track2, "Minor")
	local fill2: Frame = make("Frame", {
		Name = "Fill",
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		Size = UDim2.fromScale(0, 1),
		ZIndex = 9,
		Parent = track2,
	})
	Arcade.corner(fill2, 9)
	local fillGradient2: UIGradient = make("UIGradient", { Color = A.Fill.Garage, Rotation = 90, Parent = fill2 })
	local count2 = Arcade.text(track2, { text = "", role = "Label", name = "Count", z = 11 })
	count2.Size = UDim2.fromScale(1, 1)
	count2.Position = UDim2.fromScale(0, 0)
	label2.Visible = false

	-- the primary button: rebuilt only when its size changes --------------------------------------------------------------
	local primaryButton: Arcade.Button? = nil
	local buttonTrove = trove:Extend()
	local function buildButton()
		local key = string.format("%dx%d", geo.button.X, geo.button.Y)
		if key == builtButton and primaryButton then
			return
		end
		builtButton = key
		buttonTrove:Clean()
		local b = Arcade.button(body, {
			name = "Primary",
			label = "GOT IT!",
			fill = "Green",
			size = "Custom",
			width = geo.button.X,
			height = geo.button.Y,
			pattern = true,
			cooldown = 0.4,
			onActivate = function()
				handle:pressPrimary()
			end,
		})
		buttonTrove:Add(b.trove)
		b.root.ZIndex = 12
		primaryButton = b
	end

	-- STATE ------------------------------------------------------------------------------------------------------------------

	local function progressValid(): boolean
		local p = progress
		if not p then
			return false
		end
		local c, t = p.current, p.target
		return type(c) == "number"
			and type(t) == "number"
			and c == c
			and t == t
			and c ~= math.huge
			and t ~= math.huge
			and c >= 0
			and t > 0
	end

	local function remainingNow(): number?
		local p = progress
		if p and progressValid() then
			return math.max(0, math.ceil(p.target - p.current))
		end
		return nil
	end

	local function isReady(): boolean
		return remainingNow() == 0
	end

	local function wantedText(): string
		local remaining = remainingNow()
		if remaining == 0 and spec.ready then
			return spec.ready.text
		end
		local t = spec.text
		if type(t) == "function" then
			if remaining == nil then
				return DialogueCard.UnknownText
			end
			return t(remaining)
		end
		if progress ~= nil and remaining == nil then
			return DialogueCard.UnknownText
		end
		return t
	end

	local function currentPrimary(): Action
		if isReady() and spec.ready and spec.ready.primary then
			return spec.ready.primary
		end
		return spec.primary or {}
	end

	local function fitSpeech()
		local b = geo.bubble
		speech.Position = UDim2.fromOffset(12, 6)
		speech.Size = UDim2.fromOffset(b.w - 24, b.h - 12)
		SupportKit.fitLabel(speech, currentText, b.w - 24, b.h - 12, geo.textSize)
		speech.TextColor3 = CardKit.Navy
		-- fitLabel leaves no outline and keeps the colour: the speech is navy on white
	end

	local function finishTyping()
		typeTrove:Clean()
		typing = false
		speech.MaxVisibleGraphemes = -1
	end

	local function startTyping()
		typeTrove:Clean()
		totalChars = utf8.len(currentText) or #currentText
		speech.Text = currentText
		if Motion.reduced() or totalChars <= 1 then
			typing = false
			speech.MaxVisibleGraphemes = -1
			return
		end
		typing = true
		speech.MaxVisibleGraphemes = 0
		local natural = totalChars / DialogueCard.CharactersPerSecond
		local duration =
			math.min(natural, if totalChars <= 70 then DialogueCard.ShortSeconds else DialogueCard.LongSeconds)
		local t0 = os.clock()
		typeTrove:Connect(RunService.Heartbeat, function()
			local a = math.clamp((os.clock() - t0) / math.max(duration, 0.05), 0, 1)
			speech.MaxVisibleGraphemes = math.floor(totalChars * a)
			if a >= 1 then
				finishTyping()
			end
		end)
	end

	local function setBubbleText(text: string, retype: boolean)
		currentText = text
		speech.Text = text
		fitSpeech()
		if retype then
			startTyping()
		else
			finishTyping()
			totalChars = utf8.len(text) or #text
		end
	end

	local function renderProgress()
		local p = progress
		local g = geo.progress
		panel.Visible = p ~= nil and g ~= nil
		if not p or not g then
			return
		end
		local valid = progressValid()
		track.Visible = valid
		togoLabel.Visible = valid
		if not valid then
			progressLabel.Text = DialogueCard.UnknownText
			progressLabel.Size = UDim2.new(1, -20, 0, g.h - 12)
			progressLabel.Position = UDim2.fromOffset(10, 6)
			progressLabel.TextXAlignment = Enum.TextXAlignment.Center
			return
		end
		progressLabel.TextXAlignment = Enum.TextXAlignment.Left
		local remaining = remainingNow() or 0
		local fraction = SupportKit.fraction(p.current, p.target, "dialogue:" .. (spec.key or spec.title))
		local shownFraction = fraction or 0
		progressLabel.Text = p.label
		local current = math.min(math.max(math.floor(p.current), 0), math.max(math.floor(p.target), 0))
		if p.cash then
			togoLabel.Text = if remaining == 0 then "READY!" else Format.cash(remaining) .. " TO GO"
			countLabel.Text = Format.cash(current) .. " / " .. Format.cash(p.target)
		else
			togoLabel.Text = if remaining == 0 then "READY!" else string.format("%d TO GO", remaining)
			countLabel.Text = string.format("%d / %d", current, math.floor(p.target))
		end
		fill.Size = UDim2.fromScale(shownFraction, 1)
		fill.Visible = shownFraction > 0
		fillGradient.Color = if remaining == 0 then A.Fill.Green else A.Fill.Garage
		local q = progress2
		label2.Visible = q ~= nil
		track2.Visible = q ~= nil
		if q then
			-- two rows: "LABEL [ count ]" each, the bar green once that goal is met
			togoLabel.Visible = false
			local half = math.floor((g.h - 12) / 2)
			local function row(
				lbl: TextLabel,
				trk: Frame,
				f: Frame,
				grad: UIGradient,
				cnt: TextLabel,
				item: Progress,
				y: number
			)
				local cur = math.min(math.max(math.floor(item.current), 0), math.max(math.floor(item.target), 0))
				local frac = if item.target > 0 then math.clamp(item.current / item.target, 0, 1) else 0
				lbl.Text = item.label
				lbl.TextXAlignment = Enum.TextXAlignment.Left
				lbl.Position = UDim2.fromOffset(10, y)
				lbl.Size = UDim2.new(0.34, -10, 0, half)
				trk.Position = UDim2.new(0.34, 0, 0, y + 2)
				trk.Size = UDim2.new(0.66, -10, 0, half - 4)
				f.Size = UDim2.fromScale(frac, 1)
				f.Visible = frac > 0
				grad.Color = if frac >= 1 then A.Fill.Green else A.Fill.Garage
				cnt.Text = if item.cash
					then Format.cash(cur) .. " / " .. Format.cash(item.target)
					else string.format("%d / %d", cur, math.floor(item.target))
			end
			row(progressLabel, track, fill, fillGradient, countLabel, p, 4)
			row(label2, track2, fill2, fillGradient2, count2, q, 8 + half)
			return
		end
		local rowH = if geo.fit == "Compact" then 22 else 26
		progressLabel.Position = UDim2.fromOffset(10, 4)
		progressLabel.Size = UDim2.new(0.6, -10, 0, rowH)
		togoLabel.Position = UDim2.new(0.6, 0, 0, 4)
		togoLabel.Size = UDim2.new(0.4, -10, 0, rowH)
		track.Position = UDim2.fromOffset(10, 4 + rowH + 4)
		track.Size = UDim2.new(1, -20, 0, math.max(g.h - rowH - 18, 24))
	end

	local function renderPrimary()
		local b = primaryButton
		if b then
			b.setLabel(currentPrimary().label or "GOT IT!")
		end
	end

	-- LAYOUT -----------------------------------------------------------------------------------------------------------------

	local function layoutNow()
		local s = scaleNow()
		hudScale.Scale = s
		root.Size = UDim2.fromScale(1 / s, 1 / s)
		geo = DialogueCard.geometry(parentSize() / s, progress ~= nil)
		stage.Size = UDim2.fromOffset(geo.cw, geo.stageH)
		card.root.AnchorPoint = Vector2.zero
		card.root.Position = UDim2.fromOffset(0, geo.overhang)
		card.root.Size = UDim2.fromOffset(geo.cw, geo.ch)
		plate.root.Size = UDim2.fromOffset(geo.cw - 16, geo.plateH)
		plate.root.Position = UDim2.fromOffset(geo.cw / 2, geo.overhang)
		closeX.root.AnchorPoint = Vector2.new(1, 0.5)
		closeX.root.Position = UDim2.fromOffset(geo.cw - 12, geo.overhang)
		local p = geo.portrait
		portraitBack.Position = UDim2.fromOffset(p.x, p.y)
		portraitBack.Size = UDim2.fromOffset(p.w, p.h)
		local artH = p.h
		local artW = artH / 1.2
		artHolder.Size = UDim2.fromOffset(artW, artH)
		artHolder.Position = UDim2.fromOffset(p.w / 2, p.h)
		namePlate.Size = UDim2.fromOffset(math.min(p.w - 12, 150), if geo.fit == "Compact" then 28 else 34)
		namePlate.Position = UDim2.fromOffset(p.w / 2, p.h - 6)
		local b = geo.bubble
		bubble.Position = UDim2.fromOffset(b.x, b.y)
		bubble.Size = UDim2.fromOffset(b.w, b.h)
		speechHit.Size = UDim2.fromScale(1, 1)
		bubbleTail.Position = UDim2.fromOffset(b.x - 2, b.y + math.min(b.h * 0.45, 46))
		local g = geo.progress
		if g then
			panel.Position = UDim2.fromOffset(g.x, g.y)
			panel.Size = UDim2.fromOffset(g.w, g.h)
		end
		buildButton()
		local pb = primaryButton
		if pb then
			pb.root.AnchorPoint = Vector2.new(0.5, 1)
			pb.root.Position = UDim2.fromOffset(geo.rightX + geo.rightW / 2, geo.buttonY)
		end
		fitSpeech()
		renderProgress()
		renderPrimary()
	end

	-- CLOSING AND BACK ----------------------------------------------------------------------------------------------------

	local function unbind()
		ContextActionService:UnbindAction(actionName)
	end
	trove:Add(unbind)

	local function restoreSelection()
		local selected = GuiService.SelectedObject
		if selected and selected:IsDescendantOf(root) then
			local prior = priorSelection
			if prior and prior:IsDescendantOf(game) and prior.Visible then
				GuiService.SelectedObject = prior
			else
				GuiService.SelectedObject = nil
			end
		end
	end

	local function doClose()
		if closed then
			return
		end
		closed = true
		closeCalls += 1
		finishTyping()
		unbind()
		restoreSelection()
		if spec.key then
			suppressed[spec.key] = true
		end
		local reduced = Motion.reduced()
		Sounds.play("Close")
		if reduced then
			trove:Destroy()
		else
			Motion.tween(dim, "dim", Motion.info(0.14), { BackgroundTransparency = 1 })
			Motion.tween(pop, "pop", Motion.info(0.14), { Scale = 0.94 })
			task.delay(0.15, function()
				trove:Destroy()
			end)
		end
		if spec.onClose then
			spec.onClose()
		end
	end

	trove:Connect(dim.Activated, function()
		doClose()
	end)
	trove:Connect(speechHit.Activated, function()
		if typing then
			finishTyping()
		end
	end)
	trove:Connect(parent:GetPropertyChangedSignal("AbsoluteSize"), function()
		if not closed then
			layoutNow()
		end
	end)

	-- BUILD THE CONTENT, THEN OPEN ---------------------------------------------------------------------------------------------

	layoutNow()
	setBubbleText(wantedText(), true)
	readyShown = isReady()
	Sounds.play("Open")
	ContextActionService:BindActionAtPriority(
		actionName,
		function(_name: string, state: Enum.UserInputState, _input: InputObject)
			if state == Enum.UserInputState.Begin and not closed then
				doClose()
			end
			return Enum.ContextActionResult.Sink
		end,
		false,
		Enum.ContextActionPriority.High.Value + 10,
		Enum.KeyCode.Escape,
		Enum.KeyCode.ButtonB
	)
	if Motion.reduced() then
		dim.BackgroundTransparency = 0.45
		pop.Scale = 1
	else
		dim.BackgroundTransparency = 1
		pop.Scale = 0.94
		Motion.tween(dim, "dim", Motion.info(0.2), { BackgroundTransparency = 0.45 })
		Motion.tween(pop, "pop", Motion.info(0.22, Enum.EasingStyle.Back), { Scale = 1 })
	end
	local focusTarget = primaryButton
	if focusTarget and lastInputIsGamepad() then
		GuiService.SelectedObject = focusTarget.body
	end
	trove:Add(function()
		Motion.cancelAll(dim)
		Motion.cancelAll(pop)
	end)

	-- PUBLIC -------------------------------------------------------------------------------------------------------------------

	handle = {
		root = root,
		setProgress = function(_self: Handle, current: number, target: number?)
			if closed then
				return
			end
			local p = progress
			if not p then
				return
			end
			p.current = current
			if target ~= nil then
				p.target = target
			end
			local nowReady = isReady()
			local becameReady = nowReady and not readyShown
			readyShown = nowReady
			renderProgress()
			renderPrimary()
			-- a new line replaces the old one at once; only the move to Ready is typed again
			setBubbleText(wantedText(), becameReady)
		end,
		setText = function(_self: Handle, text: string)
			if closed then
				return
			end
			setBubbleText(text, true)
		end,
		reveal = function(_self: Handle)
			if typing then
				finishTyping()
			end
		end,
		close = function(_self: Handle)
			doClose()
		end,
		isOpen = function(_self: Handle): boolean
			return not closed
		end,
		pressPrimary = function(_self: Handle): boolean
			if closed or not primaryGuard:tryFire() then
				return false -- a second press does nothing
			end
			primaryCalls += 1
			local action = currentPrimary()
			if action.onActivate then
				action.onActivate()
			end
			doClose()
			return true
		end,
		getDebugState = function(_self: Handle): DebugState
			local b = primaryButton
			return {
				open = not closed,
				fit = geo.fit,
				title = spec.title,
				portrait = spec.portraitName,
				text = currentText,
				typedChars = if speech.MaxVisibleGraphemes < 0 then totalChars else speech.MaxVisibleGraphemes,
				totalChars = totalChars,
				typing = typing,
				remaining = remainingNow(),
				ready = isReady(),
				progressText = countLabel.Text,
				togoText = togoLabel.Text,
				progressVisible = panel.Visible and track.Visible,
				primaryLabel = if b then b.label.Text else "",
				primaryCalls = primaryCalls,
				closeCalls = closeCalls,
				reduced = Motion.reduced(),
			}
		end,
		touchReport = function(_self: Handle): { { name: string, w: number, h: number } }
			local s = hudScale.Scale
			return SupportKit.touchReport(root, s)
		end,
	}
	return handle
end

-- THE PLAYGROUND MOUNT -----------------------------------------------------------------------------------------------------

export type Controller = {
	root: Frame?,
	open: (self: Controller, returnTo: GuiObject?) -> (),
	close: (self: Controller) -> (),
	isOpen: (self: Controller) -> boolean,
	setPreset: (self: Controller, name: string) -> boolean,
	setProgress: (self: Controller, current: number, target: number?) -> (),
	getHandle: (self: Controller) -> Handle?,
	layout: (self: Controller) -> (),
	setVisible: (self: Controller, on: boolean) -> (),
	destroy: (self: Controller) -> (),
	getDebugState: (self: Controller) -> DebugState?,
}

-- The component the playground mounts (module.new(ctx, options)): it shows the fixture presets through DialogueCard.show.
-- options = { onPrimary: ((label: string) -> ())?, preset: string? }. Open it with api.open("dialogue").
function DialogueCard.new(
	ctx: Overlay.Ctx,
	options: { onPrimary: ((label: string) -> ())?, preset: string? }?
): Controller
	local opts = options or {}
	local presetName = opts.preset or "DustyLocked"
	local current: Handle? = nil
	local destroyed = false
	local controller: Controller
	controller = {
		root = nil,
		open = function(_self: Controller, _returnTo: GuiObject?)
			if destroyed or (current and current:isOpen()) then
				return
			end
			local spec = DialogueFixtures.preset(presetName)
			if not spec then
				return
			end
			-- the fixture is plain data; the card needs its two actions to report to the harness
			local data = spec :: any
			local primary = data.primary or {}
			local label = primary.label or "GOT IT!"
			data.primary = {
				label = label,
				onActivate = function()
					if opts.onPrimary then
						opts.onPrimary(label)
					end
				end,
			}
			if data.ready and data.ready.primary then
				local readyLabel = data.ready.primary.label or "GO!"
				data.ready.primary = {
					label = readyLabel,
					onActivate = function()
						if opts.onPrimary then
							opts.onPrimary(readyLabel)
						end
					end,
				}
			end
			local handle = DialogueCard.show(ctx.layer, data :: Spec)
			current = handle
			controller.root = handle.root
		end,
		close = function(_self: Controller)
			if current then
				current:close()
			end
		end,
		isOpen = function(_self: Controller): boolean
			return current ~= nil and current:isOpen()
		end,
		setPreset = function(_self: Controller, name: string): boolean
			if not DialogueFixtures.preset(name) then
				return false
			end
			presetName = name
			return true
		end,
		setProgress = function(_self: Controller, value: number, target: number?)
			if current then
				current:setProgress(value, target)
			end
		end,
		getHandle = function(_self: Controller): Handle?
			return current
		end,
		layout = function(_self: Controller) end,
		setVisible = function(_self: Controller, on: boolean)
			local handle = current
			if handle and handle:isOpen() then
				handle.root.Visible = on
			end
		end,
		destroy = function(_self: Controller)
			destroyed = true
			if current then
				current:close()
			end
		end,
		getDebugState = function(_self: Controller): DebugState?
			return if current then current:getDebugState() else nil
		end,
	}
	return controller
end

return DialogueCard
