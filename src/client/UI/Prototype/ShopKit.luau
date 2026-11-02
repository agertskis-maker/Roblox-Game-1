--!strict
-- ShopKit: the reusable UI kit upgrades the Shop and the tutorial need (Lane 3, BRIEF M9-04, 2026-11-01). Built ONCE on
-- the arcade kit (Arcade, PreviewTokens, Motion, Sounds): the same outline, the same fonts (Fredoka for text, the
-- Nunito italic for numbers; no new font), the same reduced-motion mechanism (Motion.reduced / onReducedChanged).
--
--   ShopKit.icon(holder, name, opts?) -> boolean              family art with a solid "?" fallback (never a blank hole)
--   ShopKit.fill(name) -> ColorSequence                        a vivid Shop fill (Screens/Shop/ShopPalette), else an arcade fill
--   ShopKit.label(parent, text, size, opts?) -> TextLabel      outlined text that shrinks to fit (>= 16)
--   ShopKit.paragraph(parent, text, size, opts?) -> TextLabel  wrapped outlined copy that grows downward
--   ShopKit.chip(parent, spec) -> Frame                        a small coloured tag ("2x LAP PAY")
--   ShopKit.stamp(parent, spec) -> Frame                       a tilted tag ("NEW", "SALE")
--   ShopKit.ribbon(parent, spec) -> Ribbon                     a diagonal corner ribbon ("BEST DEAL")
--   ShopKit.burst(parent, spec) -> Burst                       a starburst badge ("SAVE 15%")
--   ShopKit.panel(parent, spec) -> Frame                       a deep indigo outlined container
--   ShopKit.plate(parent, spec) -> Frame                       the quiet surface under copy and prices
--   ShopKit.vividBackground(frame, trove?, opts?) -> UIGradient  a vivid moving-gradient background for ANY pop-up
--   ShopKit.pattern(parent, size, z, transparency?) -> Frame   a subtle repeating wheel / diamond motif
--   ShopKit.card(parent, spec) -> Card                         a gradient card with a pattern, lift, press and focus ring
--   ShopKit.priceButton(parent, spec) -> PriceButton           a glossy price button with every state
--   ShopKit.squareButton(parent, spec) -> SquareButton         the big red close X / green plus
--   ShopKit.tab(parent, spec) -> Tab                           a pill tab (green when active), 48 px tall
--   ShopKit.spinner(parent, px, z) -> Spinner                  the pending ring
--   ShopKit.shine(parent, spec) -> Shine                       one clipped highlight sweep (0.7 s), played by ShopMotion
--   ShopKit.hand(parent, spec) -> Hand                         the pointing hand (the tutorial uses it)
--   ShopKit.pulseRing(parent, spec) -> PulseRing               a pulsing highlight ring (the tutorial uses it)
--   ShopKit.mask(parent, spec) -> Mask                         a dim mask that cuts out one target (the tutorial uses it)
--   ShopKit.countUp(label, opts?) -> CountUp                   number count-up text, visual only
--
-- Rules every part keeps: hit regions never move when the art moves (the art scales inside a fixed slot); hover is
-- mouse-only; press is strong for touch; reduced motion means a short fade or nothing and final numbers at once;
-- nothing loops while hidden (continuous motion is ShopMotion's single driver, which exists only while the Shop is open;
-- the one other loop is the pending spinner, which a hidden shop switches off); every connection belongs to a Trove the
-- caller owns; a missing sound is silent and logged. Every touch target is at least 48 px (56 px for a primary button).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextService = game:GetService("TextService")
local UserInputService = game:GetService("UserInputService")

local Arcade = require(script.Parent.Arcade)
local Motion = require(script.Parent.Motion)
local PreviewTokens = require(script.Parent.PreviewTokens)
local ShopMotion = require(script.Parent.ShopMotion)
local ShopPalette = require(script.Parent.Screens.Shop.ShopPalette)
local Sounds = require(script.Parent.Sounds)
local Tokens = require(ReplicatedStorage.Shared.UI.Tokens)
local Trove = require(ReplicatedStorage.Packages.Trove)

local A = PreviewTokens.Arcade
local S = PreviewTokens.Shop
local M = S.Motion
local T = ShopMotion.Timing
local make = Arcade.make
local WHITE = Color3.new(1, 1, 1)
local MIN_TEXT = Tokens.TextSize.Minimum

local ShopKit = {}

-- SOUND DEPENDENCIES (BRIEF M10-13a). No sound id is invented here: the only sounds are the HUD's existing UI hooks
-- (Tap, Open, Close, Toast). Anything the brief asks for beyond them stays silent and is logged ONCE.
ShopKit.SoundDependencies = {
	ShopHoverTick = "no dedicated 30 to 60 ms tick asset; the HUD Tap hook plays quietly instead",
	ShopOpenWhoosh = "no dedicated airy whoosh asset; the Overlay Open hook plays",
	ShopSparkle = "no sparkle bell asset; silent (and never an idle loop)",
	ShopComingSoon = "no two-note cue asset; the HUD Toast chime plays",
}
local loggedDependencies: { [string]: boolean } = {}
function ShopKit.noteSoundDependency(name: string)
	if loggedDependencies[name] then
		return
	end
	loggedDependencies[name] = true
	print("[Shop] sound dependency: " .. name .. ": " .. tostring(ShopKit.SoundDependencies[name]))
end

-- BASICS ------------------------------------------------------------------------------------------------------

local Icons2: any = nil
do
	local module = script.Parent:FindFirstChild("Icons2")
	if module and module:IsA("ModuleScript") then
		local ok, result = pcall(require, module)
		if ok then
			Icons2 = result
		else
			warn("[ShopKit] Icons2 failed to load: " .. tostring(result))
		end
	end
end

export type IconOptions = { tint: Color3?, tilt: number? }

-- THE ICON SEAM (Round 2 N5). Every icon the Shop draws goes through drawIcon below, and nowhere else.
-- To switch the whole Shop to the shared game icons (src/client/UI/Prototype/GameIcons.luau, API
-- `GameIcons.image(parent, key, size, position?) -> ImageLabel`), change USE_GAME_ICONS to true: a name with a key in
-- GAME_ICON_KEYS is then drawn from GameIcons, and anything that has no key (or whose module fails to load) still draws
-- the existing family art, so no icon is ever a hole. The Double Lap Pay art must come from the `doubleLapPay` key:
-- no "2x" is ever typed here. `size` is passed as a UDim2 filling the holder; if GameIcons wants pixels, change that
-- one argument.
local USE_GAME_ICONS = true

-- Icons2 family name -> GameIcons key.
local GAME_ICON_KEYS: { [string]: string } = {
	Star = "shop",
	CashStack = "cash",
	VipCrown = "vip",
	DoubleLapPay = "doubleLapPay",
	StarterPack = "starterPack",
	Bundle = "bundle",
	PaintBucket = "paint",
	Decal = "decal",
	Wheel = "wheel",
	Paddock = "parkingSpot",
	Gift = "freeGift",
	Lock = "lock",
	Close = "close",
	Plus = "plus",
}

local GameIcons: any = nil
if USE_GAME_ICONS then
	local module = script.Parent:FindFirstChild("GameIcons")
	if module and module:IsA("ModuleScript") then
		local ok, result = pcall(require, module)
		if ok then
			GameIcons = result
		else
			warn("[ShopKit] GameIcons failed to load: " .. tostring(result))
		end
	end
end

local function drawIcon(holder: Frame, name: string, opts: IconOptions?): boolean
	local key = GAME_ICON_KEYS[name]
	if GameIcons ~= nil and key ~= nil then
		local ok, image = pcall(GameIcons.image, holder, key, UDim2.fromScale(1, 1))
		if ok and image ~= nil then
			local picture = image :: ImageLabel
			picture.ZIndex = holder.ZIndex + 1
			if opts and opts.tilt then
				picture.Rotation = opts.tilt
			end
			return true
		end
	end
	if Icons2 and Icons2.draw then
		local ok, drawn = pcall(Icons2.draw, holder, name, opts)
		if ok and drawn then
			return true
		end
	end
	return Arcade.icon(holder, name)
end

-- Family art with a tint; falls back to the kit's neutral "?" glyph, so a missing icon is never a hole.
function ShopKit.icon(holder: Frame, name: string, opts: IconOptions?): boolean
	return drawIcon(holder, name, opts)
end

-- A vivid Shop fill by name (ShopPalette), else a Shop fill from the tokens, else an arcade fill, else Violet.
function ShopKit.fill(name: string): ColorSequence
	local vivid = (ShopPalette.Fill :: any)[name]
	if vivid then
		return vivid
	end
	local shop = (S.Fill :: any)[name]
	if shop then
		return shop
	end
	local arcade = (A.Fill :: any)[name]
	if arcade then
		return arcade
	end
	return ShopPalette.Fill.Violet
end

local function lastInputIsTouch(): boolean
	return UserInputService:GetLastInputType() == Enum.UserInputType.Touch
end

local function textWidth(text: string, size: number): number
	local ok, bounds = pcall(function()
		return TextService:GetTextSize(text, size, Enum.Font.FredokaOne, Vector2.new(1024, 128))
	end)
	if ok then
		return (bounds :: Vector2).X
	end
	return #text * size * 0.58
end
ShopKit.textWidth = textWidth

-- The wrapped height of `text` at `size` inside `width` (design px), measured with TextService so a card can be sized
-- from its own copy (a 30 percent longer string simply makes a taller card instead of clipping).
function ShopKit.textHeight(text: string, size: number, width: number): number
	local ok, bounds = pcall(function()
		return TextService:GetTextSize(text, size, Enum.Font.FredokaOne, Vector2.new(math.max(width, 24), 4000))
	end)
	if ok then
		return math.ceil((bounds :: Vector2).Y) + 4
	end
	local charsPerLine = math.max(math.floor(width / (size * 0.55)), 4)
	return math.ceil(#text / charsPerLine) * (size + 2) + 4
end

export type LabelOptions = {
	name: string?,
	colour: Color3?,
	face: Arcade.FaceName?,
	italic: boolean?,
	xAlign: Enum.TextXAlignment?,
	yAlign: Enum.TextYAlignment?,
	outline: Arcade.StrokeRole?,
	fit: boolean?, -- default true: shrink to the box, never below 16
	z: number?,
}

function ShopKit.label(parent: Instance, text: string, size: number, opts: LabelOptions?): TextLabel
	local o: LabelOptions = opts or {}
	local outline: Arcade.StrokeRole = o.outline or (if size >= 30 then 3 else "Minor")
	local label = Arcade.text(parent, {
		text = text,
		role = "Label",
		name = o.name,
		size = size,
		colour = o.colour,
		face = o.face,
		italic = o.italic,
		outline = outline,
		xAlign = o.xAlign or Enum.TextXAlignment.Left,
		yAlign = o.yAlign,
		z = o.z,
	})
	-- dark words on a bright tag carry no outline: a dark stroke round dark letters closes them up
	local tint = o.colour
	if tint and tint.R * 0.3 + tint.G * 0.6 + tint.B * 0.1 < 0.3 then
		local stroke = label:FindFirstChildOfClass("UIStroke")
		if stroke then
			stroke.Enabled = false
		end
	end
	if o.fit ~= false then
		make("UITextSizeConstraint", { MaxTextSize = math.max(size, MIN_TEXT), MinTextSize = MIN_TEXT, Parent = label })
		label.TextScaled = true
	end
	return label
end

export type ParagraphOptions = {
	name: string?,
	colour: Color3?,
	xAlign: Enum.TextXAlignment?,
	z: number?,
}

function ShopKit.paragraph(parent: Instance, text: string, size: number, opts: ParagraphOptions?): TextLabel
	local o: ParagraphOptions = opts or {}
	local label: TextLabel = make("TextLabel", {
		Name = o.name or "Paragraph",
		BackgroundTransparency = 1,
		AutomaticSize = Enum.AutomaticSize.Y,
		Size = UDim2.fromScale(1, 0),
		FontFace = Tokens.font(),
		Text = text,
		TextSize = math.max(size, MIN_TEXT),
		TextWrapped = true,
		TextColor3 = o.colour or WHITE,
		TextXAlignment = o.xAlign or Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		ZIndex = o.z or 6,
		Parent = parent,
	})
	make("UIPadding", {
		PaddingLeft = UDim.new(0, 3),
		PaddingRight = UDim.new(0, 3),
		PaddingTop = UDim.new(0, 2),
		PaddingBottom = UDim.new(0, 2),
		Parent = label,
	})
	Arcade.outline(label, "Minor")
	return label
end

-- CHIPS, STAMPS, RIBBONS ---------------------------------------------------------------------------------------

export type ChipSpec = {
	text: string,
	fill: string?,
	size: number?, -- text size, default 16
	z: number?,
	name: string?,
	rotation: number?,
	dark: boolean?, -- ink text (for a light fill)
	outline: number?,
}

function ShopKit.chip(parent: Instance, spec: ChipSpec): Frame
	local z = spec.z or 8
	local size = math.max(spec.size or MIN_TEXT, MIN_TEXT)
	local height = size + 10
	local frame: Frame = make("Frame", {
		Name = spec.name or "Chip",
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, height),
		Rotation = spec.rotation or 0,
		BackgroundColor3 = WHITE,
		BorderSizePixel = 0,
		ZIndex = z,
		Parent = parent,
	})
	Arcade.corner(frame, 6)
	Arcade.outline(frame, spec.outline or 2)
	make("UIGradient", { Color = ShopKit.fill(spec.fill or "Orange"), Rotation = 90, Parent = frame })
	make("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8), Parent = frame })
	local label = Arcade.text(frame, {
		text = spec.text,
		role = "Badge",
		name = "Text",
		size = size,
		colour = if spec.dark then A.Ink else WHITE,
		outline = "Minor",
		autoWidth = true,
		z = z + 1,
	})
	label.Size = UDim2.fromOffset(0, height)
	if spec.dark then
		-- a dark stroke round dark letters closes them up
		local stroke = label:FindFirstChildOfClass("UIStroke")
		if stroke then
			stroke.Enabled = false
		end
	end
	return frame
end

-- A tilted stamp ("NEW", "SALE"): a chip with a stronger outline and a lean.
function ShopKit.stamp(parent: Instance, spec: ChipSpec): Frame
	local stamp = ShopKit.chip(parent, {
		text = spec.text,
		fill = spec.fill or "Red",
		size = spec.size or 16,
		z = spec.z,
		name = spec.name or "Stamp",
		rotation = spec.rotation or -8,
		dark = spec.dark,
		outline = spec.outline or 2.5,
	})
	return stamp
end

export type RibbonSpec = {
	text: string,
	fill: string?,
	side: "Left" | "Right"?,
	size: number?, -- the corner square the ribbon lives in (default 100)
	z: number?,
	name: string?,
}
export type Ribbon = { root: Frame, label: TextLabel }

-- A diagonal corner ribbon: a rotated band inside a clipped square at the card's corner. It stays clear of the
-- card's rounded corner, so it never pokes out of it.
function ShopKit.ribbon(parent: GuiObject, spec: RibbonSpec): Ribbon
	local z = spec.z or 20
	local side = spec.size or 100
	local right = spec.side ~= "Left"
	local root: Frame = make("Frame", {
		Name = spec.name or "Ribbon",
		AnchorPoint = Vector2.new(if right then 1 else 0, 0),
		Position = UDim2.fromScale(if right then 1 else 0, 0),
		Size = UDim2.fromOffset(side, side),
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		ZIndex = z,
		Parent = parent,
	})
	local band: Frame = make("Frame", {
		Name = "Band",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(side * (if right then 0.6 else 0.4), side * 0.4), -- far enough in that the words fit the corner
		Size = UDim2.fromOffset(side * 1.5, side * 0.27),
		Rotation = if right then 45 else -45,
		BackgroundColor3 = WHITE,
		BorderSizePixel = 0,
		ZIndex = z + 1,
		Parent = root,
	})
	make("UIGradient", { Color = ShopKit.fill(spec.fill or "Red"), Rotation = 90, Parent = band })
	Arcade.outline(band, 2.5)
	local label = ShopKit.label(band, spec.text, 16, { name = "Text", xAlign = Enum.TextXAlignment.Center, z = z + 2 })
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.fromScale(0.5, 0.5)
	label.Size = UDim2.new(0.8, 0, 0, 22)
	return { root = root, label = label }
end

export type PanelSpec = { name: string?, z: number?, size: UDim2?, position: UDim2?, radius: number? }

-- A dark outlined container (the Passes row, the Cash row).
function ShopKit.panel(parent: Instance, spec: PanelSpec): Frame
	local frame: Frame = make("Frame", {
		Name = spec.name or "Panel",
		Size = spec.size or UDim2.fromScale(1, 1),
		Position = spec.position or UDim2.new(),
		BackgroundColor3 = WHITE,
		BorderSizePixel = 0,
		ZIndex = spec.z or 4,
		Parent = parent,
	})
	Arcade.corner(frame, spec.radius or 14)
	Arcade.outline(frame, "Button")
	make("UIGradient", { Color = ShopKit.fill("Well"), Rotation = 90, Parent = frame })
	return frame
end

export type PlateSpec = {
	name: string?,
	z: number,
	position: UDim2?,
	size: UDim2?,
	radius: number?,
	automatic: boolean?, -- grow downward with the content (AutomaticSize Y)
}

-- THE QUIET PLATE (N6-02a): a deep indigo, softly see-through rounded surface that sits under descriptive copy and prices
-- on a glowing card, so the words never fight the gradient. It carries a thin lighter edge, never a heavy outline.
function ShopKit.plate(parent: Instance, spec: PlateSpec): Frame
	local frame: Frame = make("Frame", {
		Name = spec.name or "Plate",
		Position = spec.position or UDim2.new(),
		Size = spec.size or UDim2.fromScale(1, 1),
		AutomaticSize = if spec.automatic then Enum.AutomaticSize.Y else Enum.AutomaticSize.None,
		BackgroundColor3 = ShopPalette.Color.Plate,
		BackgroundTransparency = ShopPalette.PlateTransparency,
		BorderSizePixel = 0,
		ZIndex = spec.z,
		Parent = parent,
	})
	Arcade.corner(frame, spec.radius or 12)
	make("UIStroke", {
		Thickness = 1.5,
		Color = ShopPalette.Color.PlateEdge,
		Transparency = 0.45,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = frame,
	})
	return frame
end

export type VividOptions = { fill: string?, recipe: string?, phase: number?, priority: number? }

-- THE REUSABLE POP-UP BACKGROUND (N6-02): turns `frame` into a vivid, slowly moving gradient surface. The frame gets the
-- named fill (default "Popup": violet to hot pink to orange) and ShopMotion sways its Offset and Rotation while the frame
-- is visible. Reduced Motion keeps the colours and stops the sway. Give it the screen's Trove so the sway is removed with
-- the screen. Any other screen (the group reward pop-up, an offer pop-up) calls this one function. Returns the gradient.
function ShopKit.vividBackground(frame: GuiObject, trove: Trove.Trove?, options: VividOptions?): UIGradient
	local o: VividOptions = options or {}
	frame.BackgroundColor3 = WHITE
	frame.BackgroundTransparency = 0
	local gradient: UIGradient = make("UIGradient", {
		Color = ShopKit.fill(o.fill or "Popup"),
		Rotation = ShopPalette.Angle.Popup,
		Parent = frame,
	})
	local stop = ShopMotion.movingGradient(gradient, {
		recipe = o.recipe or "Popup",
		phase = o.phase,
		host = frame,
		priority = o.priority,
	})
	if trove then
		trove:Add(stop)
	end
	return gradient
end

export type BurstSpec = {
	text: string,
	fill: string?,
	size: number?, -- the badge's side in design px (default 96)
	z: number?,
	name: string?,
	rotation: number?,
}
export type Burst = { root: Frame, label: TextLabel }

-- A starburst badge ("SAVE 15%"): two squares, one turned 45 degrees, outlined together so no inner edge shows, with a
-- bold two-line label. The label shrinks to fit and never goes under the 16 minimum.
function ShopKit.burst(parent: Instance, spec: BurstSpec): Burst
	local side = spec.size or 96
	local z = spec.z or 20
	local root: Frame = make("Frame", {
		Name = spec.name or "Burst",
		Size = UDim2.fromOffset(side, side),
		Rotation = spec.rotation or -8,
		BackgroundTransparency = 1,
		ZIndex = z,
		Parent = parent,
	})
	local body = math.floor(side * 0.74)
	local fillColour = ShopKit.fill(spec.fill or "Red")
	-- the outline pass first (both squares stroked), then the fill pass on top without strokes
	for pass = 1, 2 do
		for _, angle in { 0, 45 } do
			local square: Frame = make("Frame", {
				Name = if pass == 1 then "Edge" else "Fill",
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromOffset(body, body),
				Rotation = angle,
				BackgroundColor3 = if pass == 1 then ShopPalette.Ink else WHITE,
				BorderSizePixel = 0,
				ZIndex = z + pass,
				Parent = root,
			})
			Arcade.corner(square, math.floor(body * 0.12))
			if pass == 1 then
				make("UIStroke", {
					Thickness = 4,
					Color = ShopPalette.Ink,
					ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
					LineJoinMode = Enum.LineJoinMode.Round,
					Parent = square,
				})
			else
				make("UIGradient", { Color = fillColour, Rotation = 90, Parent = square })
			end
		end
	end
	local label = ShopKit.label(root, spec.text, 22, {
		name = "Text",
		xAlign = Enum.TextXAlignment.Center,
		yAlign = Enum.TextYAlignment.Center,
		z = z + 4,
	})
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.fromScale(0.5, 0.5)
	label.Size = UDim2.fromOffset(math.floor(side * 0.74), math.floor(side * 0.46))
	label.TextWrapped = true
	return { root = root, label = label }
end

-- PATTERN ------------------------------------------------------------------------------------------------------

-- A subtle repeating car-themed motif: staggered wheel rings and diamond bolts, white at a high transparency, kept
-- inside a margin so nothing needs clipping. The tile count is capped (PatternMaxTiles) so a big card stays cheap.
function ShopKit.pattern(parent: Instance, size: Vector2, z: number, transparency: number?): Frame
	local alpha = transparency or 0.9
	local holder: Frame = make("Frame", {
		Name = "Pattern",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ZIndex = z,
		Parent = parent,
	})
	local margin = 14
	local w, h = size.X - 2 * margin, size.Y - 2 * margin
	if w <= 0 or h <= 0 then
		return holder
	end
	local spacing = math.max(S.Layout.PatternSpacing, math.sqrt(w * h / S.Layout.PatternMaxTiles))
	local cols = math.max(1, math.floor(w / spacing))
	local rows = math.max(1, math.floor(h / spacing))
	local dx, dy = w / cols, h / rows
	for row = 0, rows - 1 do
		for col = 0, cols - 1 do
			local x = margin + (col + 0.5 + (if row % 2 == 1 then 0.5 else 0)) * dx
			if x > size.X - margin then
				continue
			end
			local y = margin + (row + 0.5) * dy
			if (row + col) % 2 == 0 then
				local ringTile: Frame = make("Frame", {
					Name = "Wheel",
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.fromOffset(x, y),
					Size = UDim2.fromOffset(18, 18),
					BackgroundTransparency = 1,
					ZIndex = z,
					Parent = holder,
				})
				Arcade.corner(ringTile, 9)
				make("UIStroke", {
					Thickness = 2.2,
					Color = WHITE,
					Transparency = alpha,
					ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
					Parent = ringTile,
				})
			else
				local bolt: Frame = make("Frame", {
					Name = "Bolt",
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.fromOffset(x, y),
					Size = UDim2.fromOffset(10, 10),
					Rotation = 45,
					BackgroundColor3 = WHITE,
					BackgroundTransparency = alpha,
					BorderSizePixel = 0,
					ZIndex = z,
					Parent = holder,
				})
				Arcade.corner(bolt, 2)
			end
		end
	end
	return holder
end

-- INTERACTION --------------------------------------------------------------------------------------------------

type WireParts = {
	glow: UIStroke?,
	flash: GuiObject?,
	ring: GuiObject?,
	hover: number?,
	press: number?,
	hoverSound: boolean?,
	cooldown: number?,
	sound: Sounds.Hook?,
}
type Wire = {
	setEnabled: (boolean) -> (),
	isHover: () -> boolean,
	isPressed: () -> boolean,
}

-- Hover (mouse only: a lift, an outline glow and a quiet tick), press (a squash, a bright flash that works without
-- hover on touch) and focus (a ring) on a fixed hit button, moving only `visual`, so the hit region never changes.
local function wire(
	trove: Trove.Trove,
	hit: TextButton,
	visual: GuiObject,
	parts: WireParts,
	onActivate: (() -> ())?
): Wire
	-- ONE UIScale carries hover and press together (a second UIScale under the same parent would not stack reliably):
	-- pressed wins over hover, hover wins over rest.
	local interact: UIScale = make("UIScale", { Name = "Interact", Parent = visual })
	local enabled = true
	local hovering = false
	local pressed = false
	local lastTick = -math.huge
	local lastActivate = -math.huge

	local function setGlow(on: boolean)
		local glow = parts.glow
		if not glow then
			return
		end
		local goal = if on then 0.05 else 1
		if Motion.reduced() then
			glow.Transparency = goal
		else
			Motion.tween(glow, "glow", Motion.info(M.HoverSeconds), { Transparency = goal })
		end
	end
	local function applyScale(seconds: number)
		if Motion.reduced() then
			interact.Scale = 1 -- reduced motion: no lift and no squash, the glow and the flash carry the feedback
			return
		end
		local goal = 1
		if pressed then
			goal = if lastInputIsTouch() then T.PressScaleTouch else (parts.press or T.PressScale)
		elseif hovering then
			goal = parts.hover or M.HoverScale
		end
		Motion.tween(interact, "scale", Motion.info(seconds), { Scale = goal })
	end
	local function setPress(down: boolean)
		pressed = down
		local flash = parts.flash
		if flash then
			flash.Visible = down
		end
		applyScale(if down then T.PressSeconds else T.ReleaseSeconds)
	end

	trove:Connect(hit.MouseEnter, function()
		if lastInputIsTouch() then
			return -- touch has no hover
		end
		hovering = true
		applyScale(M.HoverSeconds)
		setGlow(true)
		local now = os.clock()
		if parts.hoverSound ~= false and now - lastTick > M.HoverSoundGap then
			lastTick = now
			ShopKit.noteSoundDependency("ShopHoverTick")
			Sounds.play("Tap", 0.07)
		end
	end)
	trove:Connect(hit.MouseLeave, function()
		hovering = false
		setGlow(false)
		setPress(false) -- also settles the scale back to rest
	end)
	trove:Connect(hit.MouseButton1Down, function()
		setPress(true)
	end)
	trove:Connect(hit.MouseButton1Up, function()
		setPress(false)
	end)
	trove:Connect(hit.SelectionGained, function()
		local ring = parts.ring
		if ring then
			ring.Visible = true
		end
		setGlow(true)
	end)
	trove:Connect(hit.SelectionLost, function()
		local ring = parts.ring
		if ring then
			ring.Visible = false
		end
		if not hovering then
			setGlow(false)
		end
	end)
	trove:Connect(hit.Activated, function()
		local now = os.clock()
		if not enabled or now - lastActivate < (parts.cooldown or 0.25) then
			return
		end
		lastActivate = now
		Sounds.play(parts.sound or "Tap")
		if onActivate then
			onActivate()
		end
	end)
	trove:Add(function()
		Motion.cancelAll(interact)
		local glow = parts.glow
		if glow then
			Motion.cancelAll(glow)
		end
	end)
	return {
		setEnabled = function(on: boolean)
			enabled = on
		end,
		isHover = function(): boolean
			return hovering
		end,
		isPressed = function(): boolean
			return pressed
		end,
	}
end

-- The shared furniture of a pressable thing: a transparent focus ring (outside the scaled art, a child of the fixed
-- slot), a glow outline and a press flash inside the face. Returns them for wire().
local function furniture(root: GuiObject, face: GuiObject, radius: number, z: number): WireParts
	local ring: Frame = make("Frame", {
		Name = "SelectionRing",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, 12, 1, 12),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = z + 20,
		Parent = root,
	})
	Arcade.corner(ring, radius + 6)
	Arcade.outline(ring, 3, WHITE)
	local glowFrame: Frame = make("Frame", {
		Name = "Glow",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = z + 3,
		Parent = face,
	})
	Arcade.corner(glowFrame, radius)
	local glow: UIStroke = make("UIStroke", {
		Thickness = 4,
		Color = WHITE,
		Transparency = 1,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = glowFrame,
	})
	local flash: Frame = make("Frame", {
		Name = "PressFlash",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = WHITE,
		BackgroundTransparency = 0.78,
		BorderSizePixel = 0,
		Visible = false,
		ZIndex = z + 18,
		Parent = face,
	})
	Arcade.corner(flash, radius)
	return { glow = glow, flash = flash, ring = ring }
end

-- CARD ---------------------------------------------------------------------------------------------------------

export type CardSpec = {
	name: string,
	size: Vector2,
	fill: string,
	z: number,
	trove: Trove.Trove,
	rotation: number?, -- gradient angle (default 90, top to bottom)
	radius: number?,
	pattern: boolean?,
	outline: number?,
	lip: number?,
	interactive: boolean?,
	onActivate: (() -> ())?,
}
export type Card = {
	root: Frame, -- the fixed slot (never scales): place and size this
	visual: Frame, -- what scales on hover and press
	face: Frame,
	gradient: UIGradient, -- the face's colour gradient: ShopMotion sways its Offset and Rotation
	content: Frame, -- put the card's content here (ZIndex above z + 5)
	hit: TextButton?,
	setEnabled: (boolean) -> (),
	isHover: () -> boolean,
}

function ShopKit.card(parent: Instance, spec: CardSpec): Card
	local z = spec.z
	local radius = spec.radius or 16
	local lipHeight = spec.lip or 5
	local root: Frame = spec.trove:Add(make("Frame", {
		Name = spec.name,
		Size = UDim2.fromOffset(spec.size.X, spec.size.Y),
		BackgroundTransparency = 1,
		ZIndex = z,
		Parent = parent,
	}))
	local hit: TextButton? = nil
	if spec.interactive then
		hit = make("TextButton", {
			Name = "Hit",
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			AutoButtonColor = false,
			Text = "",
			Selectable = true,
			ZIndex = z,
			Parent = root,
		})
	end
	local visual: Frame = make("Frame", {
		Name = "Visual",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, -lipHeight / 2),
		Size = UDim2.new(1, 0, 1, -lipHeight),
		BackgroundTransparency = 1,
		ZIndex = z + 1,
		Parent = root,
	})
	local lip: Frame = make("Frame", {
		Name = "Lip",
		Position = UDim2.fromOffset(0, lipHeight),
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = A.Ink,
		BorderSizePixel = 0,
		ZIndex = z + 1,
		Parent = visual,
	})
	Arcade.corner(lip, radius)
	local face: Frame = make("Frame", {
		Name = "Face",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = WHITE,
		BorderSizePixel = 0,
		ZIndex = z + 2,
		Parent = visual,
	})
	Arcade.corner(face, radius)
	Arcade.outline(face, spec.outline or "Button")
	local faceGradient: UIGradient =
		make("UIGradient", { Color = ShopKit.fill(spec.fill), Rotation = spec.rotation or 90, Parent = face })
	if spec.pattern then
		ShopKit.pattern(face, Vector2.new(spec.size.X, spec.size.Y - lipHeight), z + 3, 0.9)
	end
	local sheen: Frame = make("Frame", {
		Name = "Sheen",
		Position = UDim2.fromOffset(3, 3),
		Size = UDim2.new(1, -6, 0.32, 0),
		BackgroundColor3 = WHITE,
		BackgroundTransparency = 0.74,
		BorderSizePixel = 0,
		ZIndex = z + 4,
		Parent = face,
	})
	Arcade.corner(sheen, math.max(radius - 3, 2))
	make("UIGradient", {
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.1),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Rotation = 90,
		Parent = sheen,
	})
	local content: Frame = make("Frame", {
		Name = "Content",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = z + 5,
		Parent = face,
	})
	local wiring: Wire? = nil
	if hit then
		local parts = furniture(root, face, radius, z)
		hit.SelectionImageObject = parts.ring
		wiring = wire(spec.trove, hit, visual, parts, spec.onActivate)
	end
	return {
		root = root,
		visual = visual,
		face = face,
		gradient = faceGradient,
		content = content,
		hit = hit,
		setEnabled = function(on: boolean)
			local w = wiring
			if w then
				w.setEnabled(on)
			end
		end,
		isHover = function(): boolean
			local w = wiring
			return w ~= nil and w.isHover()
		end,
	}
end

-- SPINNER ------------------------------------------------------------------------------------------------------

export type Spinner = { root: Frame, setSpinning: (boolean) -> () }

-- The pending ring: an arc that turns while spinning. Reduced motion keeps the arc still. Hidden = no tween.
function ShopKit.spinner(parent: Instance, px: number, z: number): Spinner
	local f: Frame = make("Frame", {
		Name = "Spinner",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(px, px),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = z,
		Parent = parent,
	})
	Arcade.corner(f, px)
	local stroke: UIStroke = make("UIStroke", {
		Thickness = math.max(2.5, px * 0.16),
		Color = WHITE,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = f,
	})
	make("UIGradient", {
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(0.6, 0),
			NumberSequenceKeypoint.new(0.64, 1),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Parent = stroke,
	})
	local function setSpinning(on: boolean)
		Motion.cancelAll(f)
		f.Visible = on
		f.Rotation = 0
		if on and not Motion.reduced() then
			Motion.tween(
				f,
				"spin",
				TweenInfo.new(0.8, Enum.EasingStyle.Linear, Enum.EasingDirection.Out, -1),
				{ Rotation = 360 }
			)
		end
	end
	return { root = f, setSpinning = setSpinning }
end

-- PRICE BUTTON -------------------------------------------------------------------------------------------------

export type PriceState = "Idle" | "Pending" | "Owned" | "Unavailable" | "Error" | "Blocked" | "Locked" | "Disabled"
export type PriceSpec = {
	name: string,
	label: string,
	size: Vector2, -- design px; the height is at least 56 (48 when `secondary`)
	z: number,
	trove: Trove.Trove,
	fill: string?, -- the idle fill (default Lime: lime is the action colour)
	secondary: boolean?, -- a smaller action: the 48 px minimum instead of the 56 px primary one
	onActivate: (() -> ())?,
	sound: Sounds.Hook?,
}
export type PriceButton = {
	root: Frame,
	body: TextButton,
	face: Frame,
	label: TextLabel,
	breath: UIScale, -- the idle breathing scale: ShopMotion drives it, only for the one primary button
	setState: (state: PriceState, label: string?) -> (),
	getState: () -> PriceState,
	getLabel: () -> string,
	setLoops: (on: boolean) -> (),
	isHover: () -> boolean,
	isPressed: () -> boolean,
}

local STATE_FILL: { [string]: string } = {
	Pending = "Pending",
	Owned = "Owned",
	Unavailable = "Disabled",
	Error = "Red",
	Blocked = "Disabled",
	Locked = "Locked",
	Disabled = "Disabled",
}

function ShopKit.priceButton(parent: Instance, spec: PriceSpec): PriceButton
	local minimum = if spec.secondary then Tokens.Touch.Minimum else Tokens.Touch.Primary
	local w, h = spec.size.X, math.max(spec.size.Y, minimum)
	local z = spec.z
	local lipHeight = 4
	local radius = 10
	local trove = spec.trove
	local root: Frame = trove:Add(make("Frame", {
		Name = spec.name,
		Size = UDim2.fromOffset(w, h + lipHeight),
		BackgroundTransparency = 1,
		ZIndex = z,
		Parent = parent,
	}))
	local body: TextButton = make("TextButton", {
		Name = "Body",
		Size = UDim2.fromOffset(w, h),
		BackgroundTransparency = 1,
		AutoButtonColor = false,
		Text = "",
		Selectable = true,
		ZIndex = z,
		Parent = root,
	})
	-- the idle breathing lives on its own wrapper (one UIScale per object), so it never fights hover or press
	local bouncer: Frame = make("Frame", {
		Name = "Breather",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(w / 2, h / 2),
		Size = UDim2.fromOffset(w, h),
		BackgroundTransparency = 1,
		ZIndex = z + 1,
		Parent = root,
	})
	local breathScale: UIScale = make("UIScale", { Name = "Breath", Parent = bouncer })
	local visual: Frame = make("Frame", {
		Name = "Visual",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = z + 1,
		Parent = bouncer,
	})
	local lip: Frame = make("Frame", {
		Name = "Lip",
		Position = UDim2.fromOffset(0, lipHeight),
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = A.Ink,
		BorderSizePixel = 0,
		ZIndex = z + 1,
		Parent = visual,
	})
	Arcade.corner(lip, radius)
	local face: Frame = make("Frame", {
		Name = "Face",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = WHITE,
		BorderSizePixel = 0,
		ZIndex = z + 2,
		Parent = visual,
	})
	Arcade.corner(face, radius)
	Arcade.outline(face, "Button")
	local gradient: UIGradient = make("UIGradient", {
		Color = ShopKit.fill(spec.fill or "Lime"),
		Rotation = 90,
		Parent = face,
	})
	Arcade.gloss(face)
	-- icon slot (Check for OWNED, Lock for Locked) and the spinner share the left of the face
	local iconPx = h - 16
	local iconHolder: Frame = make("Frame", {
		Name = "Icon",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 10, 0.5, 0),
		Size = UDim2.fromOffset(iconPx, iconPx),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = z + 6,
		Parent = face,
	})
	local spin = ShopKit.spinner(face, iconPx - 4, z + 6)
	spin.root.Position = UDim2.new(0, 10 + iconPx / 2, 0.5, 0)
	local label = ShopKit.label(face, spec.label, 22, {
		name = "Label",
		xAlign = Enum.TextXAlignment.Center,
		outline = "Minor",
		z = z + 7,
	})
	label.AnchorPoint = Vector2.new(0, 0.5)
	label.Position = UDim2.new(0, 6, 0.5, 0)
	label.Size = UDim2.new(1, -12, 0, h - 10)
	-- long state copy ("Could not load this item. Try again.") wraps to two lines and shrinks to fit, never below 16
	label.TextWrapped = true

	local parts = furniture(root, face, radius, z)
	body.SelectionImageObject = parts.ring
	local wiring = wire(trove, body, visual, parts, spec.onActivate)

	local state: PriceState = "Idle"
	local shownLabel = spec.label
	local loops = true
	local iconName: string? = nil

	local function applyIcon(name: string?)
		if name == iconName then
			return
		end
		iconName = name
		for _, child in iconHolder:GetChildren() do
			child:Destroy()
		end
		iconHolder.Visible = name ~= nil
		if name then
			ShopKit.icon(iconHolder, name)
		end
	end

	local function layoutLabel(withLeft: boolean)
		local left = if withLeft then 10 + iconPx + 4 else 6
		label.Position = UDim2.new(0, left, 0.5, 0)
		label.Size = UDim2.new(1, -left - 6, 0, h - 10)
	end

	local function setState(newState: PriceState, newLabel: string?)
		state = newState
		if newLabel then
			shownLabel = newLabel
			label.Text = newLabel
		end
		local fillName = STATE_FILL[newState] or spec.fill or "Lime"
		gradient.Color = ShopKit.fill(fillName)
		local dim = newState == "Unavailable" or newState == "Blocked" or newState == "Disabled"
		label.TextTransparency = if dim then 0.25 else 0
		local clickable = newState == "Idle" or newState == "Error"
		wiring.setEnabled(clickable)
		body.Selectable = clickable or newState == "Pending" or newState == "Owned"
		spin.setSpinning(newState == "Pending" and loops)
		spin.root.Visible = newState == "Pending"
		if newState == "Owned" then
			applyIcon("Check")
		elseif newState == "Locked" then
			applyIcon("Lock")
		else
			applyIcon(nil)
		end
		layoutLabel(newState == "Pending" or newState == "Owned" or newState == "Locked")
	end

	local function setLoops(on: boolean)
		loops = on
		spin.setSpinning(state == "Pending" and on)
		spin.root.Visible = state == "Pending"
		if not on then
			breathScale.Scale = 1
		end
	end

	trove:Add(function()
		spin.setSpinning(false)
	end)
	setState("Idle", spec.label)
	return {
		root = root,
		body = body,
		face = face,
		label = label,
		setState = setState,
		getState = function(): PriceState
			return state
		end,
		getLabel = function(): string
			return shownLabel
		end,
		breath = breathScale,
		setLoops = setLoops,
		isHover = wiring.isHover,
		isPressed = wiring.isPressed,
	}
end

-- SQUARE BUTTON ------------------------------------------------------------------------------------------------

export type SquareSpec = {
	name: string,
	size: number,
	fill: string,
	icon: string,
	z: number,
	trove: Trove.Trove,
	onActivate: (() -> ())?,
	sound: Sounds.Hook?,
}
export type SquareButton = {
	root: Frame,
	body: TextButton,
	setEnabled: (boolean) -> (),
}

-- The big red close X or the green "+": a glossy square with a family icon, a lip, hover, press and a focus ring.
function ShopKit.squareButton(parent: Instance, spec: SquareSpec): SquareButton
	local px = math.max(spec.size, Tokens.Touch.Minimum)
	local z = spec.z
	local lipHeight = 5
	local radius = 12
	local root: Frame = spec.trove:Add(make("Frame", {
		Name = spec.name,
		Size = UDim2.fromOffset(px, px + lipHeight),
		BackgroundTransparency = 1,
		ZIndex = z,
		Parent = parent,
	}))
	local body: TextButton = make("TextButton", {
		Name = "Body",
		Size = UDim2.fromOffset(px, px),
		BackgroundTransparency = 1,
		AutoButtonColor = false,
		Text = "",
		Selectable = true,
		ZIndex = z,
		Parent = root,
	})
	local visual: Frame = make("Frame", {
		Name = "Visual",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(px / 2, px / 2),
		Size = UDim2.fromOffset(px, px),
		BackgroundTransparency = 1,
		ZIndex = z + 1,
		Parent = root,
	})
	local lip: Frame = make("Frame", {
		Name = "Lip",
		Position = UDim2.fromOffset(0, lipHeight),
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = A.Ink,
		BorderSizePixel = 0,
		ZIndex = z + 1,
		Parent = visual,
	})
	Arcade.corner(lip, radius)
	local face: Frame = make("Frame", {
		Name = "Face",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = WHITE,
		BorderSizePixel = 0,
		ZIndex = z + 2,
		Parent = visual,
	})
	Arcade.corner(face, radius)
	Arcade.outline(face, "Button")
	make("UIGradient", { Color = ShopKit.fill(spec.fill), Rotation = 90, Parent = face })
	Arcade.gloss(face)
	local iconSide = math.floor(px * 0.66)
	local iconHolder: Frame = make("Frame", {
		Name = "Icon",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(iconSide, iconSide),
		BackgroundTransparency = 1,
		ZIndex = z + 6,
		Parent = face,
	})
	ShopKit.icon(iconHolder, spec.icon)
	local parts = furniture(root, face, radius, z)
	parts.sound = spec.sound
	body.SelectionImageObject = parts.ring
	local wiring = wire(spec.trove, body, visual, parts, spec.onActivate)
	return { root = root, body = body, setEnabled = wiring.setEnabled }
end

-- TAB ----------------------------------------------------------------------------------------------------------

export type TabSpec = {
	name: string,
	label: string,
	icon: string,
	z: number,
	trove: Trove.Trove,
	height: number?,
	onActivate: (() -> ())?,
}
export type Tab = {
	root: TextButton,
	width: number,
	setActive: (boolean) -> (),
}

local TAB_LABEL_SIZE = 18

-- The width a tab takes: padding, the icon, the word. The screen sums these before it lays the header out.
function ShopKit.tabWidth(label: string, height: number?): number
	local h = math.max(height or S.Layout.TabHeight, Tokens.Touch.Minimum)
	return math.ceil(12 + (h - 12) + 6 + textWidth(label, TAB_LABEL_SIZE) * 1.12 + 22)
end

-- A pill tab: an icon and a word; the active one is a bright green pill with a thicker outline (state is never
-- colour alone: the label turns white and outlined too).
function ShopKit.tab(parent: Instance, spec: TabSpec): Tab
	local h = math.max(spec.height or S.Layout.TabHeight, Tokens.Touch.Minimum)
	local z = spec.z
	local labelSize = TAB_LABEL_SIZE
	local iconPx = h - 12
	local width = ShopKit.tabWidth(spec.label, h)
	local root: TextButton = spec.trove:Add(make("TextButton", {
		Name = spec.name,
		Size = UDim2.fromOffset(width, h),
		BackgroundColor3 = WHITE,
		BackgroundTransparency = 1,
		AutoButtonColor = false,
		Text = "",
		Selectable = true,
		ZIndex = z,
		Parent = parent,
	}))
	Arcade.corner(root, h)
	-- a TextButton is outlined with a Border stroke by hand (Arcade.outline would stroke its text instead)
	local stroke: UIStroke = make("UIStroke", {
		Thickness = A.OutlineButton,
		Color = A.Ink,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		LineJoinMode = Enum.LineJoinMode.Round,
		Parent = root,
	})
	stroke.Transparency = 1
	local gradient: UIGradient = make("UIGradient", {
		Color = ShopKit.fill("Lime"),
		Rotation = 90,
		Enabled = false,
		Parent = root,
	})
	local iconHolder: Frame = make("Frame", {
		Name = "Icon",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 10, 0.5, 0),
		Size = UDim2.fromOffset(iconPx, iconPx),
		BackgroundTransparency = 1,
		ZIndex = z + 1,
		Parent = root,
	})
	ShopKit.icon(iconHolder, spec.icon)
	local label = ShopKit.label(root, spec.label, labelSize, {
		name = "Label",
		colour = ShopPalette.Color.TextSoft,
		z = z + 1,
	})
	label.AnchorPoint = Vector2.new(0, 0.5)
	label.Position = UDim2.new(0, 10 + iconPx + 6, 0.5, 0)
	label.Size = UDim2.new(1, -(10 + iconPx + 6 + 8), 0, h - 14)
	local ring: Frame = make("Frame", {
		Name = "SelectionRing",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, 10, 1, 10),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = z + 2,
		Parent = root,
	})
	Arcade.corner(ring, h)
	Arcade.outline(ring, 3, WHITE)
	root.SelectionImageObject = ring
	local lastActivate = -math.huge
	spec.trove:Connect(root.Activated, function()
		local now = os.clock()
		if now - lastActivate < 0.2 then
			return
		end
		lastActivate = now
		Sounds.play("Tap")
		if spec.onActivate then
			spec.onActivate()
		end
	end)
	spec.trove:Connect(root.MouseEnter, function()
		if lastInputIsTouch() then
			return
		end
		ring.Visible = true
	end)
	spec.trove:Connect(root.MouseLeave, function()
		ring.Visible = false
	end)
	local function setActive(on: boolean)
		root.BackgroundTransparency = if on then 0 else 1
		gradient.Enabled = on
		stroke.Transparency = if on then 0 else 1
		label.TextColor3 = if on then WHITE else ShopPalette.Color.TextSoft
	end
	setActive(false)
	return { root = root, width = width, setActive = setActive }
end

-- SHINE --------------------------------------------------------------------------------------------------------

export type ShineSpec = { radius: number, z: number, trove: Trove.Trove }
export type Shine = { root: CanvasGroup, play: () -> boolean, hide: () -> () }

-- One narrow, translucent, diagonal band that crosses the card in 0.7 s. ShopMotion calls play() once per period (the
-- hero and the deal 3 s apart, so two sweeps never overlap). The band lives in a CanvasGroup so it follows the card's
-- rounded corners; the group is hidden whenever nothing is sweeping, and it is a plain Frame (never Active), so it never
-- takes a press. Reduced motion: no sweep.
function ShopKit.shine(parent: GuiObject, spec: ShineSpec): Shine
	local group: CanvasGroup = spec.trove:Add(make("CanvasGroup", {
		Name = "Shine",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = spec.z,
		Parent = parent,
	}))
	Arcade.corner(group, spec.radius)
	local band: Frame = make("Frame", {
		Name = "Band",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(-0.3, 0.5),
		Size = UDim2.fromScale(0.16, 1.8),
		Rotation = 18,
		BackgroundColor3 = WHITE,
		BorderSizePixel = 0,
		ZIndex = spec.z + 1,
		Parent = group,
	})
	make("UIGradient", {
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.5, 0.45),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Parent = band,
	})
	spec.trove:Add(function()
		Motion.cancelAll(band)
	end)
	local function play(): boolean
		if Motion.reduced() or not group.Parent then
			return false
		end
		band.Position = UDim2.fromScale(-0.3, 0.5)
		group.Visible = true
		local tween = Motion.tween(
			band,
			"sweep",
			TweenInfo.new(T.ShineSeconds, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut),
			{ Position = UDim2.fromScale(1.3, 0.5) }
		)
		tween.Completed:Once(function(playback)
			if playback == Enum.PlaybackState.Completed then
				group.Visible = false
			end
		end)
		return true
	end
	-- the resting state: no band anywhere (called when the card goes offscreen, the Shop closes or Reduced Motion starts)
	local function hide()
		Motion.cancelAll(band)
		group.Visible = false
	end
	return { root = group, play = play, hide = hide }
end

-- HAND ---------------------------------------------------------------------------------------------------------

export type HandDirection = "Up" | "Down" | "Left" | "Right"
export type HandSpec = {
	size: number?,
	direction: HandDirection?,
	z: number?,
	position: UDim2?,
	trove: Trove.Trove?,
}
export type Hand = {
	root: Frame,
	setActive: (boolean) -> (),
	setDirection: (HandDirection) -> (),
	destroy: () -> (),
}

local HAND_ROTATION: { [string]: number } = { Up = 0, Right = 90, Down = 180, Left = -90 }

-- The pointing hand: the family's Hand icon, rotated to aim, bobbing along its pointing axis while active. The tutorial
-- places it above the next target. Reduced motion: still.
function ShopKit.hand(parent: Instance, spec: HandSpec): Hand
	local px = spec.size or 64
	local z = spec.z or 30
	local trove = if spec.trove then spec.trove:Extend() else Trove.new()
	local root: Frame = trove:Add(make("Frame", {
		Name = "Hand",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = spec.position or UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(px, px),
		Rotation = HAND_ROTATION[spec.direction or "Up"],
		BackgroundTransparency = 1,
		ZIndex = z,
		Parent = parent,
	}))
	local bob: Frame = make("Frame", {
		Name = "Bob",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(px, px),
		BackgroundTransparency = 1,
		ZIndex = z + 1,
		Parent = root,
	})
	ShopKit.icon(bob, "Hand")
	local active = false
	local function apply()
		Motion.cancelAll(bob)
		bob.Position = UDim2.fromScale(0.5, 0.5)
		if active and not Motion.reduced() then
			Motion.tween(
				bob,
				"bob",
				TweenInfo.new(0.45, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
				{ Position = UDim2.new(0.5, 0, 0.5, -px * 0.14) }
			)
		end
	end
	trove:Add(Motion.onReducedChanged(function()
		apply()
	end))
	trove:Add(function()
		Motion.cancelAll(bob)
	end)
	return {
		root = root,
		setActive = function(on: boolean)
			active = on
			apply()
		end,
		setDirection = function(direction: HandDirection)
			root.Rotation = HAND_ROTATION[direction]
		end,
		destroy = function()
			trove:Destroy()
		end,
	}
end

-- PULSE RING ---------------------------------------------------------------------------------------------------

export type PulseSpec = {
	padding: number?,
	radius: number?,
	colour: Color3?,
	thickness: number?,
	z: number?,
	trove: Trove.Trove?,
}
export type PulseRing = {
	root: Frame,
	setActive: (boolean) -> (),
	destroy: () -> (),
}

-- A pulsing highlight ring that fills `parent` (usually the target itself) plus a padding: it grows and fades once a
-- second (about one pulse a second, well under 3 flashes a second). Reduced motion: a steady ring.
function ShopKit.pulseRing(parent: Instance, spec: PulseSpec): PulseRing
	local pad = spec.padding or 6
	local trove = if spec.trove then spec.trove:Extend() else Trove.new()
	local root: Frame = trove:Add(make("Frame", {
		Name = "PulseRing",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, pad * 2, 1, pad * 2),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = spec.z or 40,
		Parent = parent,
	}))
	Arcade.corner(root, (spec.radius or 12) + pad)
	local stroke: UIStroke = make("UIStroke", {
		Thickness = spec.thickness or 4,
		Color = spec.colour or Color3.fromRGB(255, 226, 84),
		Transparency = 0.1,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = root,
	})
	local grow: UIScale = make("UIScale", { Name = "Pulse", Parent = root })
	local active = false
	local function apply()
		Motion.cancelAll(grow)
		Motion.cancelAll(stroke)
		grow.Scale = 1
		stroke.Transparency = 0.1
		root.Visible = active
		if active and not Motion.reduced() then
			local info = TweenInfo.new(1.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, -1, false)
			Motion.tween(grow, "pulse", info, { Scale = 1.1 })
			Motion.tween(stroke, "pulse", info, { Transparency = 0.9 })
		end
	end
	trove:Add(Motion.onReducedChanged(function()
		apply()
	end))
	trove:Add(function()
		Motion.cancelAll(grow)
		Motion.cancelAll(stroke)
	end)
	return {
		root = root,
		setActive = function(on: boolean)
			active = on
			apply()
		end,
		destroy = function()
			trove:Destroy()
		end,
	}
end

-- MASK ---------------------------------------------------------------------------------------------------------

export type MaskSpec = {
	target: GuiObject?,
	padding: number?,
	dim: number?, -- background transparency of the dim (default 0.45)
	modal: boolean?, -- true: the dim blocks input outside the cutout; default false: it never intercepts anything
	z: number?,
	trove: Trove.Trove?,
}
export type Mask = {
	root: Frame,
	setTarget: (GuiObject?) -> (),
	setDim: (number) -> (),
	setModal: (boolean) -> (),
	refresh: () -> (),
	destroy: () -> (),
}

-- A dim that leaves ONE target uncovered: four rectangles around it (so the target itself gets every click, tap and
-- gamepad press), a thin ring on the cutout. Positions are fractions of `parent`, so any UIScale above is harmless. By
-- default the rectangles are not Active and never intercept steering or movement; `modal = true` makes them sink
-- input for a real modal moment. Tracking is event driven (property changes), never a per-frame loop.
function ShopKit.mask(parent: GuiObject, spec: MaskSpec): Mask
	local trove = if spec.trove then spec.trove:Extend() else Trove.new()
	local padding = spec.padding or 6
	local dim = spec.dim or 0.45
	local modal = spec.modal == true
	local z = spec.z or 35
	local root: Frame = trove:Add(make("Frame", {
		Name = "Mask",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = z,
		Parent = parent,
	}))
	local rects: { [string]: Frame } = {}
	for _, name in { "Top", "Bottom", "Left", "Right" } do
		rects[name] = make("Frame", {
			Name = name,
			BackgroundColor3 = A.Ink,
			BackgroundTransparency = dim,
			BorderSizePixel = 0,
			Active = modal,
			ZIndex = z,
			Parent = root,
		})
	end
	local hole: Frame = make("Frame", {
		Name = "Hole",
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = z + 1,
		Parent = root,
	})
	Arcade.corner(hole, 10)
	Arcade.outline(hole, 3, WHITE)
	local target: GuiObject? = spec.target
	local targetTrove = trove:Extend()

	local function setRect(r: Frame, x: number, y: number, w: number, h: number)
		r.Position = UDim2.fromScale(x, y)
		r.Size = UDim2.fromScale(math.max(w, 0), math.max(h, 0))
		r.Visible = w > 0 and h > 0
	end
	local function refresh()
		local t = target
		local pa, ps = parent.AbsolutePosition, parent.AbsoluteSize
		if not t or not t.Parent or ps.X <= 0 or ps.Y <= 0 then
			setRect(rects.Top, 0, 0, 1, 1)
			setRect(rects.Bottom, 0, 0, 0, 0)
			setRect(rects.Left, 0, 0, 0, 0)
			setRect(rects.Right, 0, 0, 0, 0)
			hole.Visible = false
			return
		end
		local x0 = math.clamp((t.AbsolutePosition.X - padding - pa.X) / ps.X, 0, 1)
		local y0 = math.clamp((t.AbsolutePosition.Y - padding - pa.Y) / ps.Y, 0, 1)
		local x1 = math.clamp((t.AbsolutePosition.X + t.AbsoluteSize.X + padding - pa.X) / ps.X, 0, 1)
		local y1 = math.clamp((t.AbsolutePosition.Y + t.AbsoluteSize.Y + padding - pa.Y) / ps.Y, 0, 1)
		setRect(rects.Top, 0, 0, 1, y0)
		setRect(rects.Bottom, 0, y1, 1, 1 - y1)
		setRect(rects.Left, 0, y0, x0, y1 - y0)
		setRect(rects.Right, x1, y0, 1 - x1, y1 - y0)
		hole.Position = UDim2.fromScale(x0, y0)
		hole.Size = UDim2.fromScale(x1 - x0, y1 - y0)
		hole.Visible = true
	end
	local function setTarget(newTarget: GuiObject?)
		target = newTarget
		targetTrove:Clean()
		local t = newTarget
		if t then
			targetTrove:Connect(t:GetPropertyChangedSignal("AbsolutePosition"), refresh)
			targetTrove:Connect(t:GetPropertyChangedSignal("AbsoluteSize"), refresh)
			targetTrove:Connect(t:GetPropertyChangedSignal("Parent"), refresh)
		end
		refresh()
	end
	trove:Connect(parent:GetPropertyChangedSignal("AbsoluteSize"), refresh)
	setTarget(spec.target)
	return {
		root = root,
		setTarget = setTarget,
		setDim = function(value: number)
			dim = value
			for _, r in rects do
				r.BackgroundTransparency = value
			end
		end,
		setModal = function(on: boolean)
			modal = on
			for _, r in rects do
				r.Active = on
			end
		end,
		refresh = refresh,
		destroy = function()
			trove:Destroy()
		end,
	}
end

-- COUNT UP -----------------------------------------------------------------------------------------------------

export type CountOptions = {
	format: ((number) -> string)?,
	startValue: number?,
}
export type CountUp = {
	set: (value: number, animate: boolean?) -> (),
	get: () -> number,
	destroy: () -> (),
}

-- Number count-up text: a NumberValue tweened 450 to 700 ms (Quad Out) and shown through `format`. Visual only: the
-- real value is whatever was set last (get), the display floors, so it never shows more than the player has, and it
-- makes no sound per unit. Reduced motion (and an unchanged or tiny change) shows the final number at once.
function ShopKit.countUp(label: TextLabel, opts: CountOptions?): CountUp
	local o: CountOptions = opts or {}
	local format = o.format or function(n: number): string
		return tostring(n)
	end
	local trove = Trove.new()
	local value: NumberValue = trove:Add(Instance.new("NumberValue"))
	value.Value = o.startValue or 0
	local actual = value.Value
	label.Text = format(math.floor(actual))
	trove:Connect(value.Changed, function(v: number)
		label.Text = format(math.floor(v))
	end)
	trove:Add(function()
		Motion.cancelAll(value)
	end)
	local function set(target: number, animate: boolean?)
		local previous = actual
		actual = target
		Motion.cancelAll(value)
		if animate == false or Motion.reduced() or math.abs(target - previous) < 1 then
			value.Value = target
			label.Text = format(math.floor(target))
			return
		end
		local seconds =
			math.clamp(M.CountUpMin + 0.05 * math.log10(math.abs(target - previous) + 1), M.CountUpMin, M.CountUpMax)
		Motion.tween(
			value,
			"count",
			Motion.info(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ Value = target }
		)
	end
	return {
		set = set,
		get = function(): number
			return actual
		end,
		destroy = function()
			trove:Destroy()
		end,
	}
end

return ShopKit
