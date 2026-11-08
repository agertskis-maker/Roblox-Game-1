--!strict
-- DialogueCard: Coach Roxy's speech card, the ONE card every Roxy line goes through (Lane 3, Round 2 N11-01; rebuilt for Round 8
-- H-05 to R8-IMG-09). A big bold navy line in a cream speech bubble that is exactly as big as its text, Roxy's picture
-- overlapping the bubble's left edge with the bubble's little tail pointing at her, the CARS and CASH bars under the line at
-- the bubble's width, and a green GOT IT! beside them. Today the callers are the locked Dusty Highway and Summit Pass portals
-- (LaunchPad.lockedPortal) and the fixtures the playground shows (shopkeeper, tutorial, unknown); every one gets the same look.
--
--   local card = DialogueCard.show(parent, spec) -> Handle
--       spec = { key?, title, icon?, portraitName, portraitImage?, text (string | (remaining) -> string),
--                progress = { label, current, target, cash?, icon? }?, progress2 = { ... }?, primary = { label?, onActivate? }?,
--                ready = { text, primary? }?, onClose? }
--         title and icon are kept in the spec (debug state, the fixtures) but are not drawn: R8-IMG-09 has no title bar, no
--         name plate and no X, just the bubble, the bars and GOT IT!.
--   card:setProgress(current, target?)   -- live update; remaining = max(0, target - current); at 0 the card shows Ready
--   card:setText(text)  card:reveal()  card:close()  card:isOpen()  card:pressPrimary() -> boolean
--   card:getDebugState()  card:touchReport()
--   DialogueCard.isSuppressed(key) / DialogueCard.clearSuppression(key)   -- see "REPEATS" below
--   DialogueCard.new(ctx, options) -> Controller   -- the playground mount: controller:open(), :setPreset(name), :setProgress(n)
--   DialogueCard.layout(designSize, scale, text, rows) -> Geo   -- the pure layout (so a harness can check any viewport)
--   DialogueCard.geometry(designSize, hasProgress, scale?, text?) -> Geo   -- the same with sample bars
--   DialogueCard.Sizes                   -- the numbers below, one table
--
-- PROPORTIONS (H-05, Adam 2026-11-08: "the text box looks extremely large and white ... make it look proportional").
--   * The main line is big and bold: FredokaOne, navy #14213F on cream #FFF4DA. Its on-screen size is the screen's short side
--     times 0.0375, clamped to 22 .. 40 px: about 38 px on a 1920 x 1080 desktop, 28 px on a 1180 x 820 tablet, 22 px on a
--     phone (the brief asks for 26 to 40 px at 1080p and at least 20 px on phones). It is a TextLabel with an explicit TextSize
--     and not TextScaled, because the bubble is measured from the text and a scaled label would feed its own size back.
--   * The bubble hugs the text: the line is wrapped, then the narrowest width that keeps the same number of lines is used (so
--     the lines are even), plus a 16 px (at 1080p) padding on every side. The bubble is a Frame with AutomaticSize XY and a
--     UIPadding, so it can never be smaller than its text. Its widest allowed size is 46% of the screen width (52% on a phone) and never
--     more than 16 text heights, so a short line is a compact bubble, never a big white box. A line longer than about 11 text
--     heights always takes two even lines (the look of the reference).
--   * The bars sit under the bubble at the bubble's width (a bar row is never narrower than its label), GOT IT! beside them
--     (below the bubble when there are no bars). Everything scales from one number, the text size.
--   * Roxy's picture is AssetIds "r8_hubs_roxy_portrait" (never an id typed here), 4:5, in front of nothing but behind the
--     bubble, so the bubble covers a little of her ponytail like the reference.
--
-- BEHAVIOUR (N11-01a). Typewriter at 28 characters a second, never longer than 2.5 s for a short message (4 s for a long one);
-- tapping the speech area reveals all of it (and does nothing else: no purchase can fire from the reveal tap); reduced motion
-- shows the whole message at once. Default controller focus is GOT IT! and closing puts the selection back where it was. A
-- locked-portal card reads what is missing with current / target in the SAME unit; a missing or invalid requirement says
-- "Unlock details aren't available yet." and shows no bars; when the requirement is met while the card is open it switches to
-- Ready and offers only the existing travel action (spec.ready.primary), never a new unlock rule. The shopkeeper variant only
-- points to the existing upgrade panel.
--
-- REPEATS. Dismissing a card with a `key` marks that key suppressed until the caller calls clearSuppression(key) (the player
-- leaving the proximity zone), so standing in the zone does not reopen it at once. The card itself never decides proximity.
--
-- Touch: GOT IT! is at least 56 design px tall. Tapping the dim outside the card, Escape or B closes it too. Hover, press and
-- gamepad selection come from the kit button.

local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Prototype = script.Parent.Parent
local Arcade = require(Prototype.Arcade)
local DialogueFixtures = require(Prototype.SupportFixtures.DialogueFixtures)
local IconArt = require(Prototype.Home.IconArt)
local Motion = require(Prototype.Motion)
local Overlay = require(script.Parent.Overlay)
local Sounds = require(Prototype.Sounds)
local SupportKit = require(script.Parent.SupportKit)
local AssetIds = require(ReplicatedStorage.Shared.Style.AssetIds)
local Format = require(ReplicatedStorage.Shared.UI.Format)
local Tokens = require(ReplicatedStorage.Shared.UI.Tokens)
local Trove = require(ReplicatedStorage.Packages.Trove)

local make = Arcade.make

local DialogueCard = {}

DialogueCard.CharactersPerSecond = 28
DialogueCard.ShortSeconds = 2.5
DialogueCard.LongSeconds = 4
DialogueCard.UnknownText = "Unlock details aren't available yet."

-- the one portrait key (AssetIds/Hubs.luau holds the id; the lead changes it there when the art is re-uploaded under the group)
DialogueCard.PortraitKey = "r8_hubs_roxy_portrait"

-- Every number that sets the proportions, in one table (the report records these).
DialogueCard.Sizes = table.freeze({
	TextFraction = 0.0375, -- main line, on screen px = the screen's short side x this ...
	TextMin = 22, -- ... but never under this (phones; the brief's floor is 20) ...
	TextMax = 40, -- ... and never over this
	BubbleMax = 0.46, -- the bubble is at most this fraction of the screen width ...
	BubbleMaxPhone = 0.52, -- ... on a phone
	LineEms = 16, -- the wrapped line is never wider than this many text heights
	TwoLineEms = 11, -- a line longer than this many text heights takes two even lines
	PadEms = 0.45, -- bubble padding = text size x this, at least 10 (16 px at 1080p)
	LabelRatio = 0.58, -- bar label text = main text x this, at least the 16 px minimum
	PortraitRatio = 1.08, -- the portrait is this much taller than bubble + bars
	PortraitAspect = 0.8, -- 480 x 600
	PortraitOverlap = 0.16, -- the bubble covers this fraction of the portrait's width
	ButtonMinW = 128,
	Stroke = 3, -- the navy outline, design px
	Radius = 22,
	Dim = 0.42,
})

local DEPTH = 4 -- the kit button's lip (PreviewTokens.Arcade.Button.DepthOffset)
local ROW_GAP = 6

-- the palette (GENERATION-NOTES: cream #FFF4DA, navy #14213F, orange #FFB44B to #F47716, green #49C857)
local CREAM = Color3.fromRGB(255, 244, 218)
local NAVY = Color3.fromRGB(20, 33, 63)
local TRACK = Color3.fromRGB(217, 212, 202)
local DIM = Color3.fromRGB(14, 20, 38)
local ORANGE_FILL = ColorSequence.new(Color3.fromRGB(255, 196, 92), Color3.fromRGB(244, 119, 22))
local GREEN_FILL = ColorSequence.new(Color3.fromRGB(122, 226, 112), Color3.fromRGB(46, 170, 66))

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

export type Progress = {
	label: string,
	current: number,
	target: number,
	cash: boolean?, -- numbers drawn with Format.cash
	icon: string?, -- a painter name; default CashStack for cash, Car for cars
}
export type Action = { label: string?, onActivate: (() -> ())? }

export type Spec = {
	key: string?, -- identity for the repeat suppression ("portal:Dusty Highway")
	title: string,
	icon: string?, -- kept for the fixtures and the debug state; not drawn (R8-IMG-09 has no title bar)
	portraitName: string,
	portraitImage: string?, -- overrides the portrait art; nil draws Coach Roxy's (AssetIds) or the UI-shape placeholder
	text: string | ((remaining: number) -> string),
	progress: Progress?,
	-- Round 7 (A-05): a second bar under the first (Coach Roxy's locked portal: CARS and CASH, like the reference's goal card).
	progress2: Progress?,
	primary: Action?, -- default GOT IT! (closes)
	ready: { text: string, primary: Action? }?,
	onClose: (() -> ())?,
}

export type Rect = { x: number, y: number, w: number, h: number }
export type RowText = { label: string, count: string }

export type Geo = {
	fit: SupportKit.Fit,
	scale: number, -- design px to screen px
	textSize: number, -- the main line, design px
	screenTextPx: number, -- the same on screen
	labelSize: number, -- bar labels, design px
	pad: number, -- bubble padding, design px
	radius: number,
	stage: Vector2, -- the whole card
	portrait: Rect,
	bubble: Rect,
	text: Vector2, -- the line's box (centred in the bubble)
	tail: Vector2, -- the tail's centre
	tailSize: number,
	rows: { Rect }, -- the bar panels
	rowPad: number,
	iconPx: number,
	labelH: number,
	barH: number,
	countW: { number },
	button: Rect, -- the GOT IT! face
	buttonBeside: boolean, -- GOT IT! sits beside the bars (else under the bubble)
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
	textSize: number,
	screenTextPx: number,
	bubble: { w: number, h: number },
	textFits: boolean,
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

local function measureW(text: string, size: number): number
	return SupportKit.measure(text, size, 4096).X
end

-- One pass at a fixed main-text size (design px). Everything is derived from that one number.
local function layoutAt(
	ds: Vector2,
	scale: number,
	fit: SupportKit.Fit,
	textSize: number,
	text: string,
	rows: { RowText }
): Geo
	local S = DialogueCard.Sizes
	local screenShort = math.min(ds.X, ds.Y) * scale
	local phone = screenShort < 500
	local pad = math.max(10, math.floor(textSize * S.PadEms + 0.5))
	local gap = math.max(6, math.floor(textSize * 0.2 + 0.5))

	-- the bar rows: [icon] LABEL ........ count, and the bar under the label
	local labelSize = math.max(Tokens.TextSize.Minimum, math.floor(textSize * S.LabelRatio + 0.5))
	local rowPad = math.max(6, math.floor(labelSize * 0.4 + 0.5))
	local labelH = math.floor(labelSize * 1.25 + 0.5)
	local barH = math.max(12, math.floor(labelSize * 0.78 + 0.5))
	local rowH = labelH + 2 + barH + rowPad * 2
	local iconPx = rowH - rowPad * 2 + 6
	local iconGap = 8
	local rowMinW = 0
	local countW: { number } = {}
	for i, r in rows do
		local cw = math.ceil(measureW(r.count, labelSize)) + 6
		countW[i] = cw
		rowMinW = math.max(
			rowMinW,
			rowPad + 2 + iconPx + iconGap + math.ceil(measureW(r.label, labelSize)) + 18 + cw + rowPad
		)
	end

	-- the line: wrap it, then the narrowest width that keeps the same number of lines (even lines, no empty white)
	local lineH = SupportKit.measure("Ag", textSize, 4096).Y
	local natural = measureW(text, textSize)
	local longest = 0
	for word in string.gmatch(text, "%S+") do
		longest = math.max(longest, measureW(word, textSize))
	end
	local maxBubbleW = ds.X * (if phone then S.BubbleMaxPhone else S.BubbleMax)
	local maxTextW = math.max(longest + 6, math.min(maxBubbleW - 2 * pad, S.LineEms * textSize))
	local atMax = SupportKit.measure(text, textSize, maxTextW)
	local lines = math.max(1, math.floor(atMax.Y / lineH + 0.5))
	if natural > S.TwoLineEms * textSize then
		lines = math.max(lines, 2)
	end
	local lo, hi = math.min(longest + 2, maxTextW), maxTextW
	for _ = 1, 12 do
		local mid = (lo + hi) / 2
		if SupportKit.measure(text, textSize, mid).Y <= lines * lineH + 1 then
			hi = mid
		else
			lo = mid
		end
	end
	local fitted = SupportKit.measure(text, textSize, hi)
	local textW = math.ceil(fitted.X) + 6
	local textH = math.ceil(fitted.Y)

	local bubbleW = math.max(textW + 2 * pad, rowMinW)
	local bubbleH = textH + 2 * pad
	local radius = math.min(S.Radius, math.floor(bubbleH * 0.3))

	-- GOT IT!
	local bw = math.max(S.ButtonMinW, math.floor(textSize * 5.2 + 0.5))
	local bh = math.max(Tokens.Touch.Primary, math.floor(textSize * 1.75 + 0.5))

	local n = #rows
	local rowsH = if n > 0 then n * rowH + (n - 1) * ROW_GAP else 0
	local belowH = math.max(rowsH, bh + DEPTH)
	local blockW = bubbleW + (if n > 0 then gap + bw else 0)
	local blockH = bubbleH + gap + belowH

	-- the portrait: a little taller than the block, its right edge under the bubble
	local portraitH = math.floor(blockH * S.PortraitRatio + 0.5)
	local portraitW = math.floor(portraitH * S.PortraitAspect + 0.5)
	local widest = math.floor(bubbleW * 0.6)
	if portraitW > widest then
		portraitW = widest
		portraitH = math.floor(portraitW / S.PortraitAspect + 0.5)
	end
	local overlap = math.floor(portraitW * S.PortraitOverlap + 0.5)
	local stageW = portraitW - overlap + blockW
	local stageH = math.max(portraitH, blockH)
	local bx = portraitW - overlap
	local by = stageH - blockH
	local portraitY = stageH - portraitH

	-- the tail points at her face (about 42% down her picture), kept off the bubble's rounded corners
	local tailSize = math.max(14, math.floor(textSize * 0.55 + 0.5))
	local faceY = portraitY + portraitH * 0.42
	local tailY = math.clamp(faceY, by + bubbleH * 0.32, by + bubbleH * 0.8)

	local rowRects: { Rect } = {}
	for i = 1, n do
		table.insert(rowRects, { x = bx, y = by + bubbleH + gap + (i - 1) * (rowH + ROW_GAP), w = bubbleW, h = rowH })
	end
	local buttonRect: Rect
	if n > 0 then
		buttonRect = { x = bx + bubbleW + gap, y = by + bubbleH + gap + (rowsH - bh) / 2, w = bw, h = bh }
	else
		buttonRect = { x = bx + bubbleW - bw, y = by + bubbleH + gap, w = bw, h = bh }
	end

	return {
		fit = fit,
		scale = scale,
		textSize = textSize,
		screenTextPx = textSize * scale,
		labelSize = labelSize,
		pad = pad,
		radius = radius,
		stage = Vector2.new(stageW, stageH),
		portrait = { x = 0, y = portraitY, w = portraitW, h = portraitH },
		bubble = { x = bx, y = by, w = bubbleW, h = bubbleH },
		text = Vector2.new(textW, textH),
		tail = Vector2.new(bx, tailY),
		tailSize = tailSize,
		rows = rowRects,
		rowPad = rowPad,
		iconPx = iconPx,
		labelH = labelH,
		barH = barH,
		countW = countW,
		button = buttonRect,
		buttonBeside = n > 0,
	}
end

-- The pure layout: a function of the parent's size in design px, the UIScale, the line and the bar texts. The main text size
-- comes from the screen's short side; when the card would not fit the screen it steps down (never under the floor).
function DialogueCard.layout(ds: Vector2, scale: number, text: string, rows: { RowText }): Geo
	local S = DialogueCard.Sizes
	local fit = SupportKit.fitFor(ds)
	local screenShort = math.min(ds.X, ds.Y) * scale
	local screenPx = math.clamp(screenShort * S.TextFraction, S.TextMin, S.TextMax)
	local floorSize = math.ceil(S.TextMin / scale)
	local textSize = math.max(floorSize, math.floor(screenPx / scale + 0.5))
	local geo = layoutAt(ds, scale, fit, textSize, text, rows)
	for _ = 1, 10 do
		if (geo.stage.Y <= ds.Y * 0.9 and geo.stage.X <= ds.X * 0.96) or textSize <= floorSize then
			break
		end
		textSize = math.max(floorSize, textSize - 2)
		geo = layoutAt(ds, scale, fit, textSize, text, rows)
	end
	return geo
end

local SAMPLE_TEXT = "Open Dusty Highway first for Summit Pass!"
local SAMPLE_ROWS: { RowText } = {
	{ label = "DUSTY HIGHWAY CARS", count = "3 / 5" },
	{ label = "CASH", count = "$120M / $1B" },
}

-- Kept for callers of the Round 2 name: the layout with the sample line, and the sample bars when hasProgress.
function DialogueCard.geometry(ds: Vector2, hasProgress: boolean, scale: number?, text: string?): Geo
	return DialogueCard.layout(ds, scale or 1, text or SAMPLE_TEXT, if hasProgress then SAMPLE_ROWS else {})
end

-- THE PORTRAIT --------------------------------------------------------------------------------------------------------

-- The placeholder Coach Roxy: an original friendly mechanic built from shapes in a 100 x 120 unit box (red cap with a wrench
-- mark, golden ponytail, blue overalls, a spanner in her hand). Drawn in fractions of its box, so it scales cleanly and costs
-- about 40 frames, built only when there is no portrait art (AssetIds returns "" and the spec gives no image).
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

local function itemValid(p: Progress?): boolean
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

local function countText(item: Progress): string
	local cur = math.min(math.max(math.floor(item.current), 0), math.max(math.floor(item.target), 0))
	if item.cash then
		return Format.cash(cur) .. " / " .. Format.cash(item.target)
	end
	return string.format("%d / %d", cur, math.floor(item.target))
end

type RowUi = {
	panel: Frame,
	icon: Frame,
	iconName: string,
	label: TextLabel,
	count: TextLabel,
	track: Frame,
	fill: Frame,
	gradient: UIGradient,
}

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
	local geo: Geo = DialogueCard.layout(Vector2.new(750, 325), 1, "", {})
	local handle: Handle
	local S = DialogueCard.Sizes

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
		BackgroundColor3 = DIM,
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

	-- Coach Roxy: her picture (AssetIds, or the spec's own), else the shape placeholder. Behind the bubble.
	local portraitBack: Frame = make("Frame", {
		Name = "Portrait",
		BackgroundTransparency = 1,
		Active = true, -- a tap on her is not a tap on the dim
		ZIndex = 5,
		Parent = stage,
	})
	local portraitImage = spec.portraitImage
		or (if spec.portraitName == "Coach Roxy" then AssetIds.image(DialogueCard.PortraitKey) else "")
	if portraitImage ~= "" then
		make("ImageLabel", {
			Name = "PortraitImage",
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Image = portraitImage,
			ScaleType = Enum.ScaleType.Fit,
			ZIndex = 6,
			Parent = portraitBack,
		})
	else
		drawPortrait(portraitBack, 6)
	end

	-- the speech bubble: its tail is a turned square UNDER the bubble body, and a small cream patch hides the bubble's outline
	-- where the tail joins it, so the tail and the bubble read as one shape
	local bubbleTail: Frame = make("Frame", {
		Name = "Tail",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(18, 18),
		Rotation = 45,
		BackgroundColor3 = CREAM,
		BorderSizePixel = 0,
		ZIndex = 7,
		Parent = stage,
	})
	Arcade.outline(bubbleTail, S.Stroke, NAVY)
	local bubble: Frame = make("Frame", {
		Name = "Bubble",
		BackgroundColor3 = CREAM,
		BorderSizePixel = 0,
		AutomaticSize = Enum.AutomaticSize.XY,
		ZIndex = 8,
		Parent = stage,
	})
	local bubbleCorner = Arcade.corner(bubble, S.Radius)
	Arcade.outline(bubble, S.Stroke, NAVY)
	local bubblePad: UIPadding = make("UIPadding", { Parent = bubble })
	local tailPatch: Frame = make("Frame", {
		Name = "TailJoin",
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = CREAM,
		BorderSizePixel = 0,
		ZIndex = 9,
		Parent = stage,
	})
	local speech: TextLabel = make("TextLabel", {
		Name = "Speech",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		FontFace = Tokens.font(),
		Text = "",
		TextSize = 24,
		TextColor3 = NAVY,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextYAlignment = Enum.TextYAlignment.Center,
		ZIndex = 10,
		Parent = bubble,
	})
	-- tapping the speech area reveals the rest of the text and does NOTHING else
	local speechHit: TextButton = make("TextButton", {
		Name = "SpeechHit",
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false,
		Selectable = false,
		ZIndex = 11,
		Parent = stage,
	})

	-- the bar rows (two are built, shown as needed) -----------------------------------------------------------------------
	local rowUis: { RowUi } = {}
	for i = 1, 2 do
		local panel: Frame = make("Frame", {
			Name = "Row" .. i,
			BackgroundColor3 = CREAM,
			BorderSizePixel = 0,
			Active = true,
			Visible = false,
			ZIndex = 8,
			Parent = stage,
		})
		Arcade.corner(panel, 16)
		Arcade.outline(panel, S.Stroke, NAVY)
		local icon: Frame = make("Frame", { Name = "Icon", BackgroundTransparency = 1, ZIndex = 9, Parent = panel })
		local function ink(name: string, align: Enum.TextXAlignment): TextLabel
			return make("TextLabel", {
				Name = name,
				BackgroundTransparency = 1,
				FontFace = Tokens.font(),
				Text = "",
				TextSize = 18,
				TextColor3 = NAVY,
				TextXAlignment = align,
				TextYAlignment = Enum.TextYAlignment.Center,
				TextWrapped = false,
				TextTruncate = Enum.TextTruncate.AtEnd,
				ZIndex = 10,
				Parent = panel,
			})
		end
		local label = ink("Label", Enum.TextXAlignment.Left)
		local count = ink("Count", Enum.TextXAlignment.Right)
		local track: Frame = make("Frame", {
			Name = "Track",
			BackgroundColor3 = TRACK,
			BorderSizePixel = 0,
			ZIndex = 9,
			Parent = panel,
		})
		make("UICorner", { CornerRadius = UDim.new(0.5, 0), Parent = track })
		Arcade.outline(track, 2, NAVY)
		local fill: Frame = make("Frame", {
			Name = "Fill",
			BackgroundColor3 = Color3.new(1, 1, 1),
			BorderSizePixel = 0,
			Size = UDim2.fromScale(0, 1),
			ZIndex = 10,
			Parent = track,
		})
		make("UICorner", { CornerRadius = UDim.new(0.5, 0), Parent = fill })
		local gradient: UIGradient = make("UIGradient", { Color = ORANGE_FILL, Rotation = 90, Parent = fill })
		table.insert(rowUis, {
			panel = panel,
			icon = icon,
			iconName = "",
			label = label,
			count = count,
			track = track,
			fill = fill,
			gradient = gradient,
		})
	end

	-- the primary button: rebuilt only when its size changes ------------------------------------------------------------------
	local primaryButton: Arcade.Button? = nil
	local buttonTrove = trove:Extend()
	local function buildButton()
		local key = string.format("%dx%d", geo.button.w, geo.button.h)
		if key == builtButton and primaryButton then
			return
		end
		builtButton = key
		buttonTrove:Clean()
		local b = Arcade.button(stage, {
			name = "Primary",
			label = "GOT IT!",
			fill = "Green",
			size = "Custom",
			width = geo.button.w,
			height = geo.button.h,
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
		return itemValid(progress)
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

	-- the bars shown right now: the first needs a sane value (else the card says it does not know), the second too
	local function activeItems(): { Progress }
		local out: { Progress } = {}
		if progress and progressValid() then
			table.insert(out, progress)
			if progress2 and itemValid(progress2) then
				table.insert(out, progress2)
			end
		end
		return out
	end

	local function rowTexts(): { RowText }
		local out: { RowText } = {}
		for _, item in activeItems() do
			table.insert(out, { label = item.label, count = countText(item) })
		end
		return out
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

	-- the bars: texts, fills and colours (the sizes come from layoutNow)
	local function renderRows()
		local items = activeItems()
		for i, ui in rowUis do
			local item = items[i]
			ui.panel.Visible = item ~= nil
			if item then
				local want = item.icon or (if item.cash then "CashStack" else "Car")
				if ui.iconName ~= want then
					ui.iconName = want
					IconArt.draw(ui.icon, { want })
				end
				ui.label.Text = item.label
				ui.count.Text = countText(item)
				local fraction =
					SupportKit.fraction(item.current, item.target, "dialogue:" .. (spec.key or spec.title) .. i)
				local shown = fraction or 0
				ui.fill.Size = UDim2.fromScale(shown, 1)
				ui.fill.Visible = shown > 0
				-- the cars bar is orange until the goal is met, the cash bar is green (R8-IMG-09); a met goal is green
				ui.gradient.Color = if shown >= 1 or item.cash then GREEN_FILL else ORANGE_FILL
			end
		end
	end

	-- LAYOUT -----------------------------------------------------------------------------------------------------------------

	local function applyGeo()
		local g = geo
		stage.Size = UDim2.fromOffset(g.stage.X, g.stage.Y)
		local p = g.portrait
		portraitBack.Position = UDim2.fromOffset(p.x, p.y)
		portraitBack.Size = UDim2.fromOffset(p.w, p.h)
		local b = g.bubble
		bubble.Position = UDim2.fromOffset(b.x, b.y)
		bubble.Size = UDim2.fromOffset(b.w, b.h)
		bubbleCorner.CornerRadius = UDim.new(0, g.radius)
		local pad = UDim.new(0, g.pad)
		bubblePad.PaddingLeft = pad
		bubblePad.PaddingRight = pad
		bubblePad.PaddingTop = pad
		bubblePad.PaddingBottom = pad
		speech.Size = UDim2.fromOffset(g.text.X, g.text.Y)
		speech.TextSize = g.textSize
		speechHit.Position = bubble.Position
		speechHit.Size = bubble.Size
		-- the tail: a turned square half under the bubble, and the cream patch over the bubble's outline where they meet
		local t = g.tailSize
		bubbleTail.Size = UDim2.fromOffset(t, t)
		bubbleTail.Position = UDim2.fromOffset(g.tail.X - t * 0.18, g.tail.Y)
		tailPatch.Size = UDim2.fromOffset(S.Stroke * 2 + 2, math.max(4, t * 1.05 - S.Stroke * 3))
		tailPatch.Position = UDim2.fromOffset(g.tail.X, g.tail.Y)
		-- the bars
		for i, ui in rowUis do
			local r = g.rows[i]
			if r then
				ui.panel.Position = UDim2.fromOffset(r.x, r.y)
				ui.panel.Size = UDim2.fromOffset(r.w, r.h)
				local ix = g.rowPad + 2
				ui.icon.Position = UDim2.fromOffset(ix, (r.h - g.iconPx) / 2)
				ui.icon.Size = UDim2.fromOffset(g.iconPx, g.iconPx)
				local lx = ix + g.iconPx + 8
				local cw = g.countW[i] or 0
				ui.count.TextSize = g.labelSize
				ui.count.Size = UDim2.fromOffset(cw, g.labelH)
				ui.count.Position = UDim2.fromOffset(r.w - g.rowPad - cw, g.rowPad - 1)
				ui.label.TextSize = g.labelSize
				ui.label.Size = UDim2.fromOffset(math.max(10, r.w - lx - g.rowPad - cw - 8), g.labelH)
				ui.label.Position = UDim2.fromOffset(lx, g.rowPad - 1)
				ui.track.Position = UDim2.fromOffset(lx, g.rowPad + g.labelH + 2)
				ui.track.Size = UDim2.fromOffset(r.w - lx - g.rowPad - 2, g.barH)
			end
		end
		buildButton()
		local pb = primaryButton
		if pb then
			pb.root.AnchorPoint = Vector2.zero
			pb.root.Position = UDim2.fromOffset(g.button.x, g.button.y)
		end
	end

	local function layoutNow()
		local s = scaleNow()
		hudScale.Scale = s
		root.Size = UDim2.fromScale(1 / s, 1 / s)
		speech.Text = currentText
		geo = DialogueCard.layout(parentSize() / s, s, currentText, rowTexts())
		applyGeo()
		renderRows()
		local b = primaryButton
		if b then
			b.setLabel(currentPrimary().label or "GOT IT!")
		end
	end

	local function setBubbleText(text: string, retype: boolean)
		currentText = text
		layoutNow()
		if retype then
			startTyping()
		else
			finishTyping()
			totalChars = utf8.len(text) or #text
		end
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
		dim.BackgroundTransparency = S.Dim
		pop.Scale = 1
	else
		dim.BackgroundTransparency = 1
		pop.Scale = 0.94
		Motion.tween(dim, "dim", Motion.info(0.2), { BackgroundTransparency = S.Dim })
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
			local remaining = remainingNow()
			local p = progress
			local togo = ""
			if p and remaining ~= nil then
				togo = if remaining == 0
					then "READY!"
					elseif p.cash then Format.cash(remaining) .. " TO GO"
					else string.format("%d TO GO", remaining)
			end
			local items = activeItems()
			return {
				open = not closed,
				fit = geo.fit,
				title = spec.title,
				portrait = spec.portraitName,
				text = currentText,
				typedChars = if speech.MaxVisibleGraphemes < 0 then totalChars else speech.MaxVisibleGraphemes,
				totalChars = totalChars,
				typing = typing,
				remaining = remaining,
				ready = isReady(),
				progressText = if items[1] then countText(items[1]) else "",
				togoText = togo,
				progressVisible = #items > 0,
				primaryLabel = if b then b.label.Text else "",
				primaryCalls = primaryCalls,
				closeCalls = closeCalls,
				reduced = Motion.reduced(),
				textSize = geo.textSize,
				screenTextPx = geo.screenTextPx,
				bubble = { w = geo.bubble.w, h = geo.bubble.h },
				textFits = speech.TextBounds.X <= speech.AbsoluteSize.X + 1
					and speech.TextBounds.Y <= speech.AbsoluteSize.Y + 1,
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
