--!strict
-- The Raceway shop cards (Lane 3, client presentation only; Raceway round 2, Adam 2026-10-29): the
-- RACEWAY UPGRADES card and the PARKING SPOTS card, one ScreenGui "Lane3RacewayPanel" with one card
-- open at a time. Each card shows the level (or parking count) the world shows now, what the next
-- one gives, a fixed "PRICE: SET BY ECONOMY" strip and a BUY button.
--
-- Purchases exist only in the Studio preview: the owner of the prompt passes a `buy` function that
-- raises a LocalPlayer preview attribute. Outside the preview `buy` is nil, so BUY is drawn Disabled
-- and the STUDIO PREVIEW marker and the "No Cash spent" line are hidden. There is no remote, no Cash,
-- no price and no saving here; a price and the server check are Brian L's (Lane 2). The card only
-- reads the level it is given (`current`) and never replays the Raceway reveal or the banner.
--
-- Specs (approved by Adam 2026-10-29, built by hand from them):
--   vault/design/ui/raceway-upgrade-panel.md and vault/design/ui/raceway-parking-panel.md.
-- Padding is 20 on desktop and tablet and 16 on a phone (short side under 500 px). Sizes are design
-- pixels scaled once by a UIScale (Tokens.uiScaleFor); a box is its OUTER size, so a 196 x 40 tile
-- with a 2 px stroke is a 192 x 36 frame with the stroke drawn outside it.
--
-- BUY is single-flight, Idle -> Locked -> Idle. A click is accepted only when Idle, `buy` exists, the
-- shown value equals `current()`, it is below the maximum and the world is not busy. Accepting sets
-- Locked at once, then asks for shown + 1. Locked ends when `current()` equals the target and `busy()`
-- is false (the texts then cross-fade to the new value), or after 6 s (back to Idle, re-read).

local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Speedway = Shared:WaitForChild("Island"):WaitForChild("Speedway")
local Ladder = require(Speedway:WaitForChild("Ladder"))
local Parking = require(Speedway:WaitForChild("Parking"))
local Tokens = require(Shared:WaitForChild("UI"):WaitForChild("Tokens"))
local Trove = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Trove"))
local Calm = require(script.Parent.Calm)

local ShopPanel = {}

export type Kind = "upgrade" | "parking"

export type Source = {
	kind: Kind,
	plot: Model,
	-- the prompt's part: the card closes when the local character is farther than CloseDistance from it
	anchor: BasePart,
	-- the level (1..12) or owned spots (2..15) the world shows now
	current: () -> number,
	-- true while the world's reveal for a change is still running
	busy: () -> boolean,
	-- nil = no enabled purchase action (runtime outside the Studio preview)
	buy: ((target: number) -> ())?,
}

ShopPanel.CloseDistance = 15

-- Layout numbers from the specs (design px).
local CARD_W = 520
local CARD_H_UPGRADE = 360
local CARD_H_PARKING = 300
local MIN_CARD_H = 230 -- never shorter than this, so the scrolling body keeps a usable window
local PAD_DESKTOP = 20
local PAD_PHONE = 16
local PHONE_SHORT_SIDE = 500
local HEADER_H = 48
local BODY_TOP = 60 -- the first row under the header (48 + a 12 gap)
local ROW_GAP = 8
local BUY_H = 56
local PREVIEW_LINE_H = 20
local MARKER_W = 172
local MARKER_H = 40
local TILE_ROW_W = 480 -- 196 + 8 + 28 + 8 + 240
local FADE_MARGIN = 12 -- room around the card inside the fade group for its stroke and shadow
local LIP = 5 -- the BUY button's lower lip
local ARROW_STROKE = 4.5

-- Rows under the header, in canvas pixels measured from BODY_TOP.
local UPGRADE_ROWS = { hero = 56, newLine = 108, price = 140, canvas = 172 }
local PARKING_ROWS = { price = 80, canvas = 112 }

-- Timing and opacity.
local LOCK_TIMEOUT = 6 -- seconds before a Locked BUY gives up and re-reads the world
local LOCKED_TRANSPARENCY = 0.45 -- 55% opacity
local SCRIM_TRANSPARENCY = 0.55
local POP_FROM = 0.96
local CALM_FADE = 0.1 -- Reduced Motion: opacity only
local GLOSS_TRANSPARENCY = 0.62 -- a white strip at 38% opacity
local DISPLAY_ORDER = 18 -- below the level banner at 20

local ACTION_NAME = "Lane3RacewayPanelClose"

local C = Tokens.Color
local FONT = Tokens.font()
local MINT = Color3.fromRGB(128, 216, 189) -- #80D8BD, the island palette's mint (preview marker)
local DISABLED = Color3.fromRGB(216, 210, 196) -- #D8D2C4 flat Disabled BUY

type Layout = { scale: number, pad: number, cardW: number, cardH: number }
type Fadable = { label: TextLabel, stroke: UIStroke? }

type Panel = {
	source: Source,
	kind: Kind,
	min: number,
	max: number,
	root: Trove.Trove, -- everything the panel made
	live: Trove.Trove, -- connections and the input binding (cleaned when the panel starts to leave)
	content: Trove.Trove, -- the card contents (rebuilt on a layout or structure change)
	gui: ScreenGui,
	scrim: Frame,
	holder: Frame,
	viewScale: UIScale,
	group: CanvasGroup,
	pop: UIScale,
	card: Frame,
	shadow: Frame,
	layout: Layout,
	shown: number,
	locked: boolean,
	completing: boolean,
	fading: boolean,
	recheck: boolean,
	target: number,
	lockedAt: number,
	tweens: { [Tween]: boolean },
	fadeDriver: NumberValue,
	fadables: { Fadable },
	refs: { [string]: TextLabel },
	buyGroup: CanvasGroup?,
	buyButton: TextButton?,
	buyFace: Frame?,
	buyGloss: Frame?,
	buyLabel: TextLabel?,
	closeButton: TextButton?,
	buyEnabled: boolean,
	scrolls: boolean,
	destroyed: boolean,
}

local active: Panel? = nil -- the open card
local leaving: Panel? = nil -- a card fading out (at most one)

----------------------------------------------------------------------------------------------------
-- Small builders
----------------------------------------------------------------------------------------------------

local function make(className: string, props: { [string]: any }): any
	local instance = Instance.new(className)
	local parent = props.Parent
	for key, value in props do
		if key ~= "Parent" then
			(instance :: any)[key] = value
		end
	end
	instance.Parent = parent
	return instance
end

local function corner(parent: Instance, radius: UDim)
	make("UICorner", { CornerRadius = radius, Parent = parent })
end

local function stroke(parent: Instance, thickness: number, color: Color3, mode: Enum.ApplyStrokeMode): UIStroke
	return make("UIStroke", { Color = color, Thickness = thickness, ApplyStrokeMode = mode, Parent = parent })
end

-- A plain frame at an offset position and size; transparent when no colour is given.
local function frame(parent: Instance, name: string, x: number, y: number, w: number, h: number, fill: Color3?): Frame
	return make("Frame", {
		Name = name,
		Position = UDim2.fromOffset(x, y),
		Size = UDim2.fromOffset(w, h),
		BackgroundColor3 = fill or C.Card,
		BackgroundTransparency = if fill then 0 else 1,
		BorderSizePixel = 0,
		Parent = parent,
	})
end

-- A filled box whose OUTER extent is (x, y, w, h): the returned frame is smaller by the stroke on
-- every side, and the stroke is drawn outside it.
local function box(
	parent: Instance,
	name: string,
	x: number,
	y: number,
	w: number,
	h: number,
	fill: Color3?,
	thickness: number,
	radius: UDim?,
	strokeColor: Color3?
): Frame
	local f = frame(parent, name, x + thickness, y + thickness, w - 2 * thickness, h - 2 * thickness, fill)
	if radius then
		corner(f, radius)
	end
	if thickness > 0 then
		stroke(f, thickness, strokeColor or C.Stroke, Enum.ApplyStrokeMode.Border)
	end
	return f
end

-- A single line of Fredoka One text filling its parent. `outline` is a navy Contextual UIStroke.
local function text(
	parent: Instance,
	name: string,
	value: string,
	size: number,
	color: Color3,
	outline: number
): TextLabel
	local label: TextLabel = make("TextLabel", {
		Name = name,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		FontFace = FONT,
		TextSize = size,
		TextColor3 = color,
		Text = value,
		TextWrapped = false,
		TextTruncate = Enum.TextTruncate.AtEnd,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextYAlignment = Enum.TextYAlignment.Center,
		Parent = parent,
	})
	if outline > 0 then
		stroke(label, outline, C.Stroke, Enum.ApplyStrokeMode.Contextual)
	end
	return label
end

-- TextScaled between a minimum and a maximum size (tile text never clips, never grows past its role).
local function scaled(label: TextLabel, minSize: number, maxSize: number)
	label.TextScaled = true
	label.TextTruncate = Enum.TextTruncate.None
	make("UITextSizeConstraint", { MinTextSize = minSize, MaxTextSize = maxSize, Parent = label })
end

-- A rounded line between two points (a rotated frame; the round ends stand in for round caps).
local function lineBetween(
	parent: Instance,
	name: string,
	ax: number,
	ay: number,
	bx: number,
	by: number,
	thickness: number,
	color: Color3
): Frame
	local dx, dy = bx - ax, by - ay
	local bar = make("Frame", {
		Name = name,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset((ax + bx) / 2, (ay + by) / 2),
		Size = UDim2.fromOffset(math.sqrt(dx * dx + dy * dy) + thickness, thickness),
		Rotation = math.deg(math.atan2(dy, dx)),
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		Parent = parent,
	})
	corner(bar, UDim.new(0.5, 0))
	return bar
end

-- The right arrow, 28 x 20 (shape, not colour, says "next"): a shaft and two head strokes.
local function rightArrow(parent: Instance, name: string): Frame
	local arrow = frame(parent, name, 0, 0, 28, 20, nil)
	lineBetween(arrow, "Shaft", 3, 10, 22, 10, ARROW_STROKE, C.Stroke)
	lineBetween(arrow, "HeadUp", 15, 3, 23, 10, ARROW_STROKE, C.Stroke)
	lineBetween(arrow, "HeadDown", 23, 10, 15, 17, ARROW_STROKE, C.Stroke)
	return arrow
end

-- The up-arrow cue, 22 x 26: solid teal with a 2 px navy outline.
local function upArrow(parent: Instance, name: string): Frame
	local cue = frame(parent, name, 0, 0, 22, 26, nil)
	-- the fill: the stem, then the head in thin slices (the outline hides their stepped edge)
	frame(cue, "Stem", 7.5, 13, 7, 10.5, C.Teal)
	local slices = 11
	local sliceH = 10.5 / slices
	for i = 0, slices - 1 do
		local top = 2.5 + i * sliceH
		local half = 8.5 * (top + sliceH / 2 - 2.5) / 10.5
		frame(cue, "Head", 11 - half, top, half * 2, sliceH + 0.3, C.Teal)
	end
	local path = {
		Vector2.new(11, 2.5),
		Vector2.new(19.5, 13),
		Vector2.new(14.5, 13),
		Vector2.new(14.5, 23.5),
		Vector2.new(7.5, 23.5),
		Vector2.new(7.5, 13),
		Vector2.new(2.5, 13),
		Vector2.new(11, 2.5),
	}
	for i = 2, #path do
		lineBetween(cue, "Outline", path[i - 1].X, path[i - 1].Y, path[i].X, path[i].Y, 2, C.Stroke)
	end
	return cue
end

-- The close X: two 4.5 px strokes in a 20 x 20 area.
local function closeX(parent: Instance): Frame
	local icon = frame(parent, "X", 0, 0, 20, 20, nil)
	lineBetween(icon, "Down", 4, 4, 16, 16, ARROW_STROKE, C.Stroke)
	lineBetween(icon, "Up", 16, 4, 4, 16, ARROW_STROKE, C.Stroke)
	return icon
end

-- A dashed 2 px navy outline (a UIStroke cannot dash): about 6 px dashes with 4 px gaps along the
-- four edges and one short diagonal dash on each rounded corner.
local function dashedOutline(parent: Instance, w: number, h: number)
	local t, r, dash, gap = 2, 8, 6, 4
	local function run(x: number, y: number, length: number, horizontal: boolean)
		local count = math.max(1, math.floor((length + gap) / (dash + gap) + 0.5))
		local size = if count == 1 then length else dash
		local space = if count == 1 then 0 else (length - count * size) / (count - 1)
		for i = 0, count - 1 do
			local o = i * (size + space)
			if horizontal then
				frame(parent, "Dash", x + o, y, size, t, C.Stroke)
			else
				frame(parent, "Dash", x, y + o, t, size, C.Stroke)
			end
		end
	end
	run(r, 0, w - 2 * r, true)
	run(r, h - t, w - 2 * r, true)
	run(0, r, h - 2 * r, false)
	run(w - t, r, h - 2 * r, false)
	local reach = (r - t / 2) * 0.7071
	for _, c in
		{
			{ x = r - reach, y = r - reach, angle = -45 },
			{ x = w - r + reach, y = r - reach, angle = 45 },
			{ x = w - r + reach, y = h - r + reach, angle = -45 },
			{ x = r - reach, y = h - r + reach, angle = 45 },
		}
	do
		local piece = frame(parent, "Dash", c.x, c.y, 4, t, C.Stroke)
		piece.AnchorPoint = Vector2.new(0.5, 0.5)
		piece.Rotation = c.angle
	end
end

----------------------------------------------------------------------------------------------------
-- Panel helpers
----------------------------------------------------------------------------------------------------

local function tweenInfo(seconds: number): TweenInfo
	return TweenInfo.new(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
end

local function clampValue(p: Panel, value: number): number
	return math.clamp(math.floor(value), p.min, p.max)
end

-- The world's value, or what the card shows if the callback fails.
local function safeCurrent(p: Panel): number
	local ok, value = pcall(p.source.current)
	if ok and type(value) == "number" then
		return clampValue(p, value)
	end
	return p.shown
end

-- A failing check counts as busy: the card then waits, and the 6 s timeout ends the wait.
local function safeBusy(p: Panel): boolean
	local ok, value = pcall(p.source.busy)
	return not ok or value == true
end

-- A tween the panel owns: cancelled when the panel closes; `onDone` runs only if it completed.
local function play(p: Panel, instance: Instance, info: TweenInfo, goals: { [string]: any }, onDone: (() -> ())?): Tween
	local tween = TweenService:Create(instance, info, goals)
	p.tweens[tween] = true
	tween.Completed:Once(function(state: Enum.PlaybackState)
		p.tweens[tween] = nil
		tween:Destroy()
		if state == Enum.PlaybackState.Completed and onDone then
			onDone()
		end
	end)
	tween:Play()
	return tween
end

local function cancelTweens(p: Panel)
	local running: { Tween } = {}
	for tween in p.tweens do
		table.insert(running, tween)
	end
	for _, tween in running do
		tween:Cancel()
	end
end

local function fadable(p: Panel, label: TextLabel)
	table.insert(p.fadables, { label = label, stroke = label:FindFirstChildOfClass("UIStroke") })
end

-- 0 = fully shown, 1 = hidden: the cross-fade of the value texts.
local function applyFade(p: Panel, amount: number)
	for _, item in p.fadables do
		item.label.TextTransparency = amount
		if item.stroke then
			item.stroke.Transparency = amount
		end
	end
end

local function selectionInside(p: Panel): boolean
	local selected = GuiService.SelectedObject
	return selected ~= nil and selected:IsDescendantOf(p.gui)
end

-- Gamepad: BUY is selected by default (Close when there is no enabled BUY).
local function selectDefault(p: Panel)
	local target: GuiObject? = if p.buyEnabled then p.buyButton else p.closeButton
	if target then
		GuiService.SelectedObject = target
	end
end

local function destroyPanel(p: Panel)
	if p.destroyed then
		return
	end
	p.destroyed = true
	cancelTweens(p)
	p.live:Clean()
	if selectionInside(p) then
		GuiService.SelectedObject = nil
	end
	p.root:Destroy()
	if active == p then
		active = nil
	end
	if leaving == p then
		leaving = nil
	end
end

-- Closes the open card: fades out (0.2 s, or 0.1 s opacity only with Reduced Motion). `instant`
-- destroys at once (used when ownership changes); either way a Locked state is dropped and a late
-- result is ignored, and closing never changes any value.
function ShopPanel.close(instant: boolean?)
	local p = active
	if p == nil then
		if instant == true and leaving then
			destroyPanel(leaving)
		end
		return
	end
	active = nil
	p.locked = false
	p.completing = false
	p.live:Clean()
	cancelTweens(p)
	if selectionInside(p) then
		GuiService.SelectedObject = nil
	end
	if leaving then
		destroyPanel(leaving)
	end
	if instant == true then
		destroyPanel(p)
		return
	end
	leaving = p
	local calm = Calm()
	local info = tweenInfo(if calm then CALM_FADE else Tokens.Motion.Panel)
	play(p, p.scrim, info, { BackgroundTransparency = 1 })
	if not calm then
		play(p, p.pop, info, { Scale = POP_FROM })
	end
	play(p, p.group, info, { GroupTransparency = 1 }, function()
		destroyPanel(p)
	end)
end

----------------------------------------------------------------------------------------------------
-- BUY: Idle -> Locked -> Idle
----------------------------------------------------------------------------------------------------

local function lock(p: Panel, target: number)
	p.locked = true
	p.completing = false
	p.target = target
	p.lockedAt = os.clock()
	if p.buyGroup then
		p.buyGroup.GroupTransparency = LOCKED_TRANSPARENCY
	end
end

-- Pressed (0.1 s): the face takes the lip colour, the gloss goes, the label drops 3 px; it then
-- eases back. Reduced Motion: the colour change only.
local function pressVisual(p: Panel)
	local face, gloss, label = p.buyFace, p.buyGloss, p.buyLabel
	if face == nil or gloss == nil or label == nil then
		return
	end
	local calm = Calm()
	local info = tweenInfo(Tokens.Motion.Press)
	face.BackgroundColor3 = C.PrimaryPressed
	gloss.BackgroundTransparency = 1
	play(p, face, info, { BackgroundColor3 = C.Primary })
	play(p, gloss, info, { BackgroundTransparency = GLOSS_TRANSPARENCY })
	if not calm then
		label.Position = UDim2.fromOffset(0, 3)
		play(p, label, info, { Position = UDim2.fromOffset(0, 0) })
	end
end

local function onBuy(p: Panel)
	-- Idle only; a text fade still running means the shown value is not final yet
	if active ~= p or p.locked or p.fading then
		return
	end
	local buy = p.source.buy
	if buy == nil then
		return
	end
	local current = safeCurrent(p)
	if p.shown ~= current or current >= p.max or safeBusy(p) then
		return
	end
	local target = p.shown + 1
	-- Locked before the request runs, so a second click in the same frame can never get through
	lock(p, target)
	pressVisual(p)
	local ok, err = pcall(buy, target)
	if not ok then
		warn("Raceway shop: the purchase request failed: " .. tostring(err))
	end
end

----------------------------------------------------------------------------------------------------
-- Card contents
----------------------------------------------------------------------------------------------------

-- The texts that change with the value (the rest of the card is fixed).
type UpgradeTexts = { current: string, nextTile: string, lapNow: string, lapNext: string, newLine: string }
type ParkingTexts = { owned: string, nextSpot: string }

local function upgradeTexts(level: number): UpgradeTexts
	return {
		current = string.format("CURRENT LEVEL %d", level),
		nextTile = string.format("NEXT LEVEL %d", level + 1),
		lapNow = Ladder.lapPayText(level),
		lapNext = Ladder.lapPayText(level + 1),
		newLine = Ladder.newText(level + 1) or "",
	}
end

local function parkingTexts(owned: number): ParkingTexts
	return {
		owned = string.format("%d / %d", owned, Parking.MaxSpots),
		nextSpot = tostring(owned + 1),
	}
end

local function setText(p: Panel, key: string, value: string)
	local label = p.refs[key]
	if label then
		label.Text = value
	end
end

local function applyTexts(p: Panel)
	if p.kind == "upgrade" then
		local t = upgradeTexts(p.shown)
		setText(p, "current", t.current)
		setText(p, "nextTile", t.nextTile)
		setText(p, "lapNow", t.lapNow)
		setText(p, "lapNext", t.lapNext)
		setText(p, "newLine", t.newLine)
	else
		local t = parkingTexts(p.shown)
		setText(p, "owned", t.owned)
		setText(p, "nextSpot", t.nextSpot)
	end
end

-- The Y-only scrolling body between the header and the BUY row. The bar shows only when the rows
-- overflow (a very short window); at the normal sizes nothing scrolls.
local function scrollBody(parent: Instance, y: number, w: number, viewH: number, canvasH: number): ScrollingFrame
	local overflow = canvasH > viewH + 0.5
	return make("ScrollingFrame", {
		Name = "Body",
		Position = UDim2.fromOffset(0, y),
		-- when it scrolls, the frame reaches 10 px into the card's right padding and the bar sits
		-- there (inset), so it never covers the NEXT tile or the hero (Studio, 2026-10-29)
		Size = UDim2.fromOffset(if overflow then w + 10 else w, viewH),
		CanvasSize = UDim2.fromOffset(0, canvasH),
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ElasticBehavior = Enum.ElasticBehavior.Never,
		ScrollBarThickness = if overflow then 6 else 0,
		ScrollBarImageColor3 = C.Stroke,
		VerticalScrollBarInset = if overflow then Enum.ScrollBarInset.ScrollBar else Enum.ScrollBarInset.None,
		ScrollingEnabled = overflow,
		Selectable = false,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Parent = parent,
	})
end

local function buildHeader(p: Panel, inner: Frame, width: number)
	local title = text(
		inner,
		"Title",
		if p.kind == "upgrade" then "RACEWAY UPGRADES" else "PARKING SPOTS",
		Tokens.TextSize.Value,
		C.Text,
		0
	)
	title.Size = UDim2.fromOffset(width - Tokens.Touch.Minimum - Tokens.Space.S, HEADER_H)
	title.TextXAlignment = Enum.TextXAlignment.Left

	-- the 48 x 48 hit area; the visible 48 x 48 box sits inside it
	local close: TextButton = make("TextButton", {
		Name = "Close",
		Position = UDim2.fromOffset(width - Tokens.Touch.Minimum, 0),
		Size = UDim2.fromOffset(Tokens.Touch.Minimum, Tokens.Touch.Minimum),
		BackgroundTransparency = 1,
		AutoButtonColor = false,
		Text = "",
		Parent = inner,
	})
	local face = box(
		close,
		"Face",
		0,
		0,
		Tokens.Touch.Minimum,
		Tokens.Touch.Minimum,
		C.CardInset,
		Tokens.Stroke.Regular,
		Tokens.Radius.Card
	)
	local icon = closeX(face)
	icon.AnchorPoint = Vector2.new(0.5, 0.5)
	icon.Position = UDim2.fromScale(0.5, 0.5)
	p.closeButton = close
	p.content:Connect(close.Activated, function()
		ShopPanel.close()
	end)
end

local function buildPriceStrip(parent: Instance, y: number, width: number)
	local strip = frame(parent, "PriceStrip", 0, y, width, 32, nil)
	dashedOutline(strip, width, 32)
	text(strip, "Text", "PRICE: SET BY ECONOMY", Tokens.TextSize.Label, C.Text, 0)
end

local function buildUpgradeRows(p: Panel, body: Frame, width: number)
	local texts = upgradeTexts(p.shown)
	local x0 = math.floor((width - TILE_ROW_W) / 2)

	-- row 2: CURRENT tile, arrow, NEXT tile (the stronger one)
	local currentTile = box(body, "CurrentTile", x0, 4, 196, 40, C.CardInset, Tokens.Stroke.Thin, Tokens.Radius.Card)
	local currentText = text(currentTile, "Text", texts.current, Tokens.TextSize.Label, C.Text, 0)
	scaled(currentText, Tokens.TextSize.Minimum, Tokens.TextSize.Label)
	rightArrow(body, "Arrow").Position = UDim2.fromOffset(x0 + 196 + 8, 14)
	local nextTile = box(body, "NextTile", x0 + 240, 0, 240, 48, C.Teal, Tokens.Stroke.Thick, Tokens.Radius.Card)
	local nextText = text(nextTile, "Text", texts.nextTile, Tokens.TextSize.Value, C.Card, 2)
	scaled(nextText, Tokens.TextSize.Minimum, Tokens.TextSize.Value)

	-- row 3: the hero stat, "LAP PAY x1.35 -> x1.50"
	local hero = box(body, "Hero", 0, UPGRADE_ROWS.hero, width, 48, C.Track, Tokens.Stroke.Regular, Tokens.Radius.Card)
	local row = frame(hero, "Row", 0, 0, 0, 0, nil)
	row.Size = UDim2.fromScale(1, 1)
	make("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = row,
	})
	local order = 0
	local function nextOrder(): number
		order += 1
		return order
	end
	local function item(child: GuiObject)
		child.LayoutOrder = nextOrder()
	end
	local function spacer(w: number)
		local gap = frame(row, "Gap", 0, 0, w, 1, nil)
		item(gap)
	end
	local function bigNumber(name: string, value: string, color: Color3): TextLabel
		local label = text(row, name, value, Tokens.TextSize.Display, color, 0)
		label.AutomaticSize = Enum.AutomaticSize.X
		label.Size = UDim2.fromOffset(0, 42)
		item(label)
		return label
	end
	local caption = text(row, "Caption", "LAP PAY", Tokens.TextSize.Label, C.Text, 0)
	caption.AutomaticSize = Enum.AutomaticSize.X
	caption.Size = UDim2.fromOffset(0, 42)
	item(caption)
	spacer(12)
	local lapNow = bigNumber("LapNow", texts.lapNow, C.Text)
	spacer(10)
	item(rightArrow(row, "Arrow"))
	spacer(10)
	item(upArrow(row, "Cue"))
	spacer(4)
	local lapNext = bigNumber("LapNext", texts.lapNext, C.Teal)

	-- row 4: what the next level adds
	local newLine = text(body, "NewLine", texts.newLine, Tokens.TextSize.Label, C.Text, 0)
	newLine.Position = UDim2.fromOffset(0, UPGRADE_ROWS.newLine)
	newLine.Size = UDim2.fromOffset(width, 24)

	-- row 5: the fixed price label
	buildPriceStrip(body, UPGRADE_ROWS.price, width)

	p.refs.current, p.refs.nextTile = currentText, nextText
	p.refs.lapNow, p.refs.lapNext, p.refs.newLine = lapNow, lapNext, newLine
	for _, label in { currentText, nextText, lapNow, lapNext, newLine } do
		fadable(p, label)
	end
end

local function buildParkingRows(p: Panel, body: Frame, width: number)
	local texts = parkingTexts(p.shown)
	local x0 = math.floor((width - TILE_ROW_W) / 2)

	-- row 2: OWNED tile, arrow, NEXT SPOT tile (two lines each: a label, then a 36 value)
	local owned = box(body, "OwnedTile", x0, 0, 196, 72, C.CardInset, Tokens.Stroke.Thin, Tokens.Radius.Card)
	local ownedTop = math.floor((68 - 60) / 2)
	local ownedLabel = text(owned, "Label", "OWNED", Tokens.TextSize.Label, C.Text, 0)
	ownedLabel.Position, ownedLabel.Size = UDim2.fromOffset(0, ownedTop), UDim2.new(1, 0, 0, 20)
	scaled(ownedLabel, Tokens.TextSize.Minimum, Tokens.TextSize.Label)
	local ownedValue = text(owned, "Value", texts.owned, Tokens.TextSize.Display, C.Text, 0)
	ownedValue.Position, ownedValue.Size = UDim2.fromOffset(0, ownedTop + 20), UDim2.new(1, 0, 0, 40)
	scaled(ownedValue, Tokens.TextSize.Minimum, Tokens.TextSize.Display)

	rightArrow(body, "Arrow").Position = UDim2.fromOffset(x0 + 196 + 8, 26)

	local nextSpot = box(body, "NextSpotTile", x0 + 240, 0, 240, 72, C.Teal, Tokens.Stroke.Thick, Tokens.Radius.Card)
	local nextTop = math.floor((64 - 60) / 2)
	local nextLabel = text(nextSpot, "Label", "NEXT SPOT", Tokens.TextSize.Label, C.Card, 1)
	nextLabel.Position, nextLabel.Size = UDim2.fromOffset(0, nextTop), UDim2.new(1, 0, 0, 20)
	scaled(nextLabel, Tokens.TextSize.Minimum, Tokens.TextSize.Label)
	local nextValue = text(nextSpot, "Value", texts.nextSpot, Tokens.TextSize.Display, C.Card, 2)
	nextValue.Position, nextValue.Size = UDim2.fromOffset(0, nextTop + 20), UDim2.new(1, 0, 0, 40)
	scaled(nextValue, Tokens.TextSize.Minimum, Tokens.TextSize.Display)

	-- row 3: the fixed price label
	buildPriceStrip(body, PARKING_ROWS.price, width)

	p.refs.owned, p.refs.nextSpot = ownedValue, nextValue
	fadable(p, ownedValue)
	fadable(p, nextValue)
end

-- The top state: two tiles centred in the body under the header; no price, no BUY.
local function buildMaxBody(p: Panel, inner: Frame, width: number, height: number)
	local viewH = height - HEADER_H
	local contentH = 84 + 12 + 56
	local body = scrollBody(inner, HEADER_H, width, viewH, contentH)
	p.scrolls = contentH > viewH + 0.5
	local top = math.max(0, math.floor((viewH - contentH) / 2))
	local x = math.floor((width - 440) / 2)
	local bigTile = box(body, "MaxTile", x, top, 440, 84, C.Teal, Tokens.Stroke.Thick, Tokens.Radius.Card)
	local big = text(
		bigTile,
		"Text",
		if p.kind == "upgrade" then "MAX LEVEL" else "ALL SPOTS OWNED",
		Tokens.TextSize.Display,
		C.Card,
		3
	)
	local infoTile = box(body, "InfoTile", x, top + 96, 440, 56, C.CardInset, Tokens.Stroke.Thin, Tokens.Radius.Card)
	local info = text(
		infoTile,
		"Text",
		if p.kind == "upgrade"
			then string.format("RACEWAY LEVEL %d", p.shown)
			else string.format("OWNED %d / %d", p.shown, Parking.MaxSpots),
		Tokens.TextSize.Value,
		C.Text,
		0
	)
	fadable(p, big)
	fadable(p, info)
end

-- The BUY row (a 56 high button, left of the STUDIO PREVIEW marker) and the preview line.
local function buildFooter(p: Panel, inner: Frame, width: number, y: number)
	local previewing = p.source.buy ~= nil
	p.buyEnabled = previewing
	local w = if previewing then width - MARKER_W - Tokens.Space.S else width

	-- the CanvasGroup carries the Locked opacity for the whole button, stroke included
	local group: CanvasGroup = make("CanvasGroup", {
		Name = "BuyGroup",
		Position = UDim2.fromOffset(0, y),
		Size = UDim2.fromOffset(w, BUY_H),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		GroupTransparency = if p.locked then LOCKED_TRANSPARENCY else 0,
		Parent = inner,
	})
	local button: TextButton = make("TextButton", {
		Name = "Buy",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		AutoButtonColor = false,
		Text = "",
		Interactable = previewing,
		Parent = group,
	})
	-- the base is the lip colour (or the flat Disabled fill); the face covers all but the last 5 px
	local base = box(
		button,
		"Base",
		0,
		0,
		w,
		BUY_H,
		if previewing then C.PrimaryPressed else DISABLED,
		Tokens.Stroke.Thick,
		Tokens.Radius.Card
	)
	if previewing then
		local face = frame(base, "Face", 0, 0, 0, 0, C.Primary)
		face.Size = UDim2.new(1, 0, 1, -LIP)
		corner(face, Tokens.Radius.Card)
		local gloss = frame(face, "Gloss", 12, 4, w - 2 * Tokens.Stroke.Thick - 24, 10, Color3.new(1, 1, 1))
		gloss.BackgroundTransparency = GLOSS_TRANSPARENCY
		corner(gloss, Tokens.Radius.Small)
		p.buyFace, p.buyGloss = face, gloss
	else
		p.buyFace, p.buyGloss = nil, nil
	end
	local label = text(base, "Label", "BUY", Tokens.TextSize.Display, if previewing then C.Text else C.TextSecondary, 0)
	label.ZIndex = 3
	p.buyGroup, p.buyButton, p.buyLabel = group, button, label
	p.content:Connect(button.Activated, function()
		onBuy(p)
	end)

	if previewing then
		local marker = box(
			inner,
			"Marker",
			w + Tokens.Space.S,
			y + (BUY_H - MARKER_H) / 2,
			MARKER_W,
			MARKER_H,
			C.Stroke,
			Tokens.Stroke.Thin,
			Tokens.Radius.Pill,
			MINT
		)
		text(marker, "Text", "STUDIO PREVIEW", Tokens.TextSize.Minimum, MINT, 0)
		local line = text(
			inner,
			"PreviewLine",
			"No Cash spent. Progress is not saved.",
			Tokens.TextSize.Minimum,
			C.TextSecondary,
			0
		)
		line.Position = UDim2.fromOffset(0, y + BUY_H + Tokens.Space.XS)
		line.Size = UDim2.fromOffset(width, PREVIEW_LINE_H)
	end
end

-- Builds (or rebuilds) everything inside the card for the shown value and the current layout.
local function buildContent(p: Panel)
	local reselect = selectionInside(p)
	p.content:Clean()
	table.clear(p.fadables)
	table.clear(p.refs)
	p.buyGroup, p.buyButton, p.buyFace, p.buyGloss, p.buyLabel, p.closeButton = nil, nil, nil, nil, nil, nil
	p.buyEnabled = false
	p.scrolls = false

	local layout = p.layout
	local width = layout.cardW - 2 * layout.pad
	local height = layout.cardH - 2 * layout.pad
	local inner = frame(p.card, "Inner", layout.pad, layout.pad, width, height, nil)
	p.content:Add(inner)

	buildHeader(p, inner, width)
	if p.shown >= p.max then
		buildMaxBody(p, inner, width, height)
	else
		local rows = if p.kind == "upgrade" then UPGRADE_ROWS else PARKING_ROWS
		-- rows 2 to 5 scroll if the card is shorter than they need; the BUY row and the preview line
		-- stay at the bottom, fixed
		local needed = BODY_TOP + rows.canvas + ROW_GAP + BUY_H + Tokens.Space.XS + PREVIEW_LINE_H
		local buyY = BODY_TOP + rows.canvas + ROW_GAP - math.max(0, needed - height)
		local viewH = buyY - ROW_GAP - BODY_TOP
		local body = scrollBody(inner, BODY_TOP, width, viewH, rows.canvas)
		p.scrolls = rows.canvas > viewH + 0.5
		if p.kind == "upgrade" then
			buildUpgradeRows(p, body, width)
		else
			buildParkingRows(p, body, width)
		end
		buildFooter(p, inner, width, buyY)
	end

	-- gamepad: Up and Down move between Close and BUY and stay inside the card
	local close = p.closeButton
	local buy = if p.buyEnabled then p.buyButton else nil
	if close then
		close.NextSelectionLeft, close.NextSelectionRight, close.NextSelectionUp = close, close, close
		close.NextSelectionDown = buy or close
	end
	if buy then
		buy.NextSelectionLeft, buy.NextSelectionRight, buy.NextSelectionDown = buy, buy, buy
		buy.NextSelectionUp = close
	end

	applyFade(p, p.fadeDriver.Value)
	if reselect then
		selectDefault(p)
	end
end

----------------------------------------------------------------------------------------------------
-- Changing the shown value
----------------------------------------------------------------------------------------------------

-- Shows `value`: the changing texts cross-fade over Motion.LabelFade (out for half, in for half;
-- Reduced Motion snaps). Reaching or leaving the top rebuilds the body at the middle of the fade.
local function showValue(p: Panel, value: number, animated: boolean, onDone: (() -> ())?)
	local function finish()
		p.fading = false
		if onDone then
			onDone()
		end
		-- the world changed again while this fade ran (refresh asked for a recheck)
		if p.recheck and not p.destroyed then
			p.recheck = false
			if active == p and not p.locked then
				local latest = safeCurrent(p)
				if latest ~= p.shown then
					showValue(p, latest, true)
				end
			end
		end
	end
	if value == p.shown then
		finish()
		return
	end
	local wasTop = p.shown >= p.max
	local isTop = value >= p.max
	local function commit()
		p.shown = value
		if wasTop ~= isTop then
			buildContent(p)
		else
			applyTexts(p)
		end
	end
	if not animated or Calm() then
		commit()
		applyFade(p, 0)
		finish()
		return
	end
	p.fading = true
	local half = tweenInfo(Tokens.Motion.LabelFade / 2)
	play(p, p.fadeDriver, half, { Value = 1 }, function()
		commit()
		applyFade(p, 1)
		play(p, p.fadeDriver, half, { Value = 0 }, finish)
	end)
end

-- Back to Idle: the button returns to full opacity (eased unless Reduced Motion).
local function unlock(p: Panel)
	if p.destroyed then
		return
	end
	p.locked = false
	p.completing = false
	local group = p.buyGroup
	if group then
		if Calm() then
			group.GroupTransparency = 0
		else
			play(p, group, tweenInfo(Tokens.Motion.Press), { GroupTransparency = 0 })
		end
	end
end

-- The world reached the target and finished its reveal: show it, then go back to Idle.
local function complete(p: Panel, value: number)
	p.completing = true
	showValue(p, value, true, function()
		unlock(p)
	end)
end

-- The 6 s safety net: back to Idle, then re-read the world.
local function abandonLock(p: Panel)
	p.locked = false
	p.completing = false
	p.fading = false
	if p.buyGroup then
		p.buyGroup.GroupTransparency = 0
	end
	local latest = safeCurrent(p)
	if latest ~= p.shown then
		showValue(p, latest, false)
	end
end

local function pollLock(p: Panel)
	local elapsed = os.clock() - p.lockedAt
	if elapsed >= LOCK_TIMEOUT then
		abandonLock(p)
		return
	end
	-- the press feedback lasts at least its own 0.1 s, which also gives the world a frame to start
	if elapsed < Tokens.Motion.Press or p.fading then
		return
	end
	local latest = safeCurrent(p)
	if latest == p.target and not safeBusy(p) then
		complete(p, latest)
	end
end

local function tooFar(p: Panel): boolean
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root == nil or not root:IsA("BasePart") then
		return false -- nothing to measure (between lives): the other close rules still apply
	end
	-- the anchor's last position is used even if the world rebuilt the part during a purchase
	return (root.Position - p.source.anchor.Position).Magnitude > ShopPanel.CloseDistance
end

local function step(p: Panel)
	if active ~= p then
		return
	end
	if tooFar(p) then
		ShopPanel.close()
		return
	end
	if p.locked and not p.completing then
		pollLock(p)
	end
end

----------------------------------------------------------------------------------------------------
-- Layout
----------------------------------------------------------------------------------------------------

local function computeLayout(p: Panel): Layout
	local camera = Workspace.CurrentCamera
	local viewport = if camera then camera.ViewportSize else p.gui.AbsoluteSize
	local scale = Tokens.uiScaleFor(viewport)
	local pad = if math.min(viewport.X, viewport.Y) < PHONE_SHORT_SIDE then PAD_PHONE else PAD_DESKTOP
	local safeHeight = p.gui.AbsoluteSize.Y
	if safeHeight <= 0 then
		safeHeight = viewport.Y
	end
	local wanted = if p.kind == "upgrade" then CARD_H_UPGRADE else CARD_H_PARKING
	local cardH = math.max(MIN_CARD_H, math.floor(math.min(wanted, safeHeight / scale - 32)))
	return { scale = scale, pad = pad, cardW = CARD_W, cardH = cardH }
end

local function applyLayout(p: Panel)
	local layout = p.layout
	local m = FADE_MARGIN
	local edge = Tokens.Stroke.Thick
	p.viewScale.Scale = layout.scale
	p.holder.Size = UDim2.fromOffset(layout.cardW + 2 * m, layout.cardH + 2 * m)
	p.card.Position = UDim2.fromOffset(m, m)
	p.card.Size = UDim2.fromOffset(layout.cardW, layout.cardH)
	-- a navy copy of the card (stroke included), 4 px lower
	p.shadow.Position = UDim2.fromOffset(m - edge, m - edge + Tokens.Shadow.OffsetY)
	p.shadow.Size = UDim2.fromOffset(layout.cardW + 2 * edge, layout.cardH + 2 * edge)
end

-- The viewport or the safe area changed while open.
local function relayout(p: Panel)
	if p.destroyed or active ~= p then
		return
	end
	local fresh = computeLayout(p)
	local old = p.layout
	if fresh.scale == old.scale and fresh.pad == old.pad and fresh.cardH == old.cardH then
		return
	end
	p.layout = fresh
	applyLayout(p)
	if fresh.pad ~= old.pad or fresh.cardH ~= old.cardH then
		buildContent(p)
	end
end

----------------------------------------------------------------------------------------------------
-- Public interface
----------------------------------------------------------------------------------------------------

local function rangeOf(kind: Kind): (number, number)
	if kind == "upgrade" then
		return Ladder.MinLevel, Ladder.MaxLevel
	end
	return Parking.StartSpots, Parking.MaxSpots
end

local function createPanel(source: Source, playerGui: PlayerGui): Panel
	local root = Trove.new()
	local minValue, maxValue = rangeOf(source.kind)
	local gui: ScreenGui = make("ScreenGui", {
		Name = "Lane3RacewayPanel",
		ResetOnSpawn = false,
		ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets,
		DisplayOrder = DISPLAY_ORDER,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = playerGui,
	})
	root:Add(gui)

	-- the scrim is visual only: Active false, so it never swallows a touch meant for the thumbstick
	local scrim = frame(gui, "Scrim", 0, 0, 0, 0, C.Stroke)
	scrim.Size = UDim2.fromScale(1, 1)
	scrim.BackgroundTransparency = SCRIM_TRANSPARENCY
	scrim.Active = false

	local holder = frame(gui, "Holder", 0, 0, CARD_W, CARD_H_UPGRADE, nil)
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Position = UDim2.fromScale(0.5, 0.5)
	local viewScale: UIScale = make("UIScale", { Parent = holder })

	-- the fade group is larger than the card so its stroke and shadow are not clipped
	local group: CanvasGroup = make("CanvasGroup", {
		Name = "Fade",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Parent = holder,
	})
	local pop = frame(group, "Pop", 0, 0, 0, 0, nil)
	pop.AnchorPoint = Vector2.new(0.5, 0.5)
	pop.Position = UDim2.fromScale(0.5, 0.5)
	pop.Size = UDim2.fromScale(1, 1)
	local popScale: UIScale = make("UIScale", { Parent = pop })

	local shadow = frame(pop, "Shadow", 0, 0, 0, 0, C.Shadow)
	shadow.BackgroundTransparency = Tokens.Shadow.Transparency
	shadow.ZIndex = 1
	corner(shadow, UDim.new(0, Tokens.Radius.Panel.Offset + Tokens.Stroke.Thick))
	local card = frame(pop, "Card", 0, 0, 0, 0, C.Card)
	card.ZIndex = 2
	card.Active = true -- a tap on the card is not a tap on the world behind it
	corner(card, Tokens.Radius.Panel)
	stroke(card, Tokens.Stroke.Thick, C.Stroke, Enum.ApplyStrokeMode.Border)

	local driver = Instance.new("NumberValue")
	root:Add(driver)

	local p: Panel = {
		source = source,
		kind = source.kind,
		min = minValue,
		max = maxValue,
		root = root,
		live = Trove.new(),
		content = Trove.new(),
		gui = gui,
		scrim = scrim,
		holder = holder,
		viewScale = viewScale,
		group = group,
		pop = popScale,
		card = card,
		shadow = shadow,
		layout = { scale = 1, pad = PAD_DESKTOP, cardW = CARD_W, cardH = CARD_H_UPGRADE },
		shown = minValue,
		locked = false,
		completing = false,
		fading = false,
		recheck = false,
		target = minValue,
		lockedAt = 0,
		tweens = {},
		fadeDriver = driver,
		fadables = {},
		refs = {},
		buyGroup = nil,
		buyButton = nil,
		buyFace = nil,
		buyGloss = nil,
		buyLabel = nil,
		closeButton = nil,
		buyEnabled = false,
		scrolls = false,
		destroyed = false,
	}
	root:Add(p.live)
	root:Add(p.content)
	root:Connect(driver.Changed, function(value: number)
		applyFade(p, value)
	end)
	return p
end

-- Builds and shows the card for `source`, replacing any open card (no fade-in then, and nothing is
-- replayed). The card only reads `source.current()`; it never changes the world except through `buy`.
function ShopPanel.open(source: Source)
	local player = Players.LocalPlayer
	local playerGui = player and player:FindFirstChildOfClass("PlayerGui")
	if playerGui == nil then
		return
	end
	local replacing = active ~= nil
	ShopPanel.close(true)

	local p = createPanel(source, playerGui)
	active = p
	p.shown = safeCurrent(p)
	p.layout = computeLayout(p)
	applyLayout(p)
	buildContent(p)

	-- input and watchers, all dropped when the card starts to close
	p.live:Connect(RunService.Heartbeat, function()
		step(p)
	end)
	local camera = Workspace.CurrentCamera
	if camera then
		p.live:Connect(camera:GetPropertyChangedSignal("ViewportSize"), function()
			relayout(p)
		end)
	end
	p.live:Connect(p.gui:GetPropertyChangedSignal("AbsoluteSize"), function()
		relayout(p)
	end)
	ContextActionService:BindActionAtPriority(
		ACTION_NAME,
		function(_name: string, inputState: Enum.UserInputState, _input: InputObject): Enum.ContextActionResult
			if inputState == Enum.UserInputState.Begin then
				ShopPanel.close()
			end
			return Enum.ContextActionResult.Sink
		end,
		false,
		Enum.ContextActionPriority.High.Value,
		Enum.KeyCode.Escape,
		Enum.KeyCode.ButtonB
	)
	p.live:Add(function()
		ContextActionService:UnbindAction(ACTION_NAME)
	end)

	-- the world is still showing the last change: wait for it before BUY can be pressed
	if p.shown < p.max and p.buyEnabled and safeBusy(p) then
		lock(p, p.shown)
	end
	if UserInputService.GamepadEnabled then
		selectDefault(p)
	end

	-- open: fade the card (0.2 s) with a 0.96 -> 1 scale, no overshoot; Reduced Motion: opacity
	-- only, 0.1 s
	if replacing then
		return
	end
	local calm = Calm()
	local info = tweenInfo(if calm then CALM_FADE else Tokens.Motion.Panel)
	p.group.GroupTransparency = 1
	p.scrim.BackgroundTransparency = 1
	play(p, p.group, info, { GroupTransparency = 0 })
	play(p, p.scrim, info, { BackgroundTransparency = SCRIM_TRANSPARENCY })
	if not calm then
		p.pop.Scale = POP_FROM
		play(p, p.pop, info, { Scale = 1 })
	end
end

function ShopPanel.isOpen(): boolean
	return active ~= nil
end

-- The plot of the open card.
function ShopPanel.openPlot(): Model?
	local p = active
	return if p then p.source.plot else nil
end

-- Re-reads `source.current()` and redraws the texts (the world calls it when the level or the spot
-- count changes). A Locked card ignores it: its own wait shows the new value when the world is done.
function ShopPanel.refresh()
	local p = active
	if p == nil then
		return
	end
	if p.fading then
		p.recheck = true
		return
	end
	if p.locked then
		return
	end
	local latest = safeCurrent(p)
	if latest ~= p.shown then
		showValue(p, latest, true)
	end
end

-- For Studio tests.
function ShopPanel.state(): { [string]: any }
	local p = active
	if p == nil then
		return {
			open = false,
			shown = 0,
			locked = false,
			buyEnabled = false,
			layout = { scale = 0, padding = 0, cardSize = Vector2.zero },
		}
	end
	return {
		open = true,
		kind = p.kind,
		shown = p.shown,
		max = p.max,
		locked = p.locked,
		target = p.target,
		buyEnabled = p.buyEnabled and p.shown < p.max, -- BUY is drawn enabled (Locked still counts)
		previewMarker = p.source.buy ~= nil and p.shown < p.max,
		scrolls = p.scrolls,
		layout = {
			scale = p.layout.scale,
			padding = p.layout.pad,
			cardSize = Vector2.new(p.layout.cardW, p.layout.cardH),
		},
	}
end

return ShopPanel
