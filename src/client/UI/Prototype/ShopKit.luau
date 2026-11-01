--!strict
-- ShopKit: the reusable UI kit upgrades the Shop and the tutorial need (Lane 3, BRIEF M9-04, 2026-11-01). Built ONCE on
-- the arcade kit (Arcade, PreviewTokens, Motion, Sounds): the same outline, the same fonts (Fredoka for text, the
-- Nunito italic for numbers; no new font), the same reduced-motion mechanism (Motion.reduced / onReducedChanged).
--
--   ShopKit.icon(holder, name, opts?) -> boolean              family art with a solid "?" fallback (never a blank hole)
--   ShopKit.fill(name) -> ColorSequence                        a Shop or arcade fill by name
--   ShopKit.label(parent, text, size, opts?) -> TextLabel      outlined text that shrinks to fit (>= 16)
--   ShopKit.paragraph(parent, text, size, opts?) -> TextLabel  wrapped outlined copy that grows downward
--   ShopKit.chip(parent, spec) -> Frame                        a small coloured tag ("2x LAP PAY")
--   ShopKit.stamp(parent, spec) -> Frame                       a tilted tag ("NEW", "SALE")
--   ShopKit.ribbon(parent, spec) -> Ribbon                     a diagonal corner ribbon ("BEST DEAL")
--   ShopKit.panel(parent, spec) -> Frame                       a dark outlined container
--   ShopKit.pattern(parent, size, z, transparency?) -> Frame   a subtle repeating wheel / diamond motif
--   ShopKit.card(parent, spec) -> Card                         a gradient card with a pattern, lift, press and focus ring
--   ShopKit.priceButton(parent, spec) -> PriceButton           a glossy price button with every state
--   ShopKit.squareButton(parent, spec) -> SquareButton         the big red close X / green plus
--   ShopKit.tab(parent, spec) -> Tab                           a pill tab (green when active)
--   ShopKit.spinner(parent, px, z) -> Spinner                  the pending ring
--   ShopKit.shine(parent, spec) -> Shine                       one clipped highlight sweep (650 ms)
--   ShopKit.sparkles(parent, spec) -> Sparkles                 4 to 6 small stars over 600 ms
--   ShopKit.hand(parent, spec) -> Hand                         the pointing hand (the tutorial uses it)
--   ShopKit.pulseRing(parent, spec) -> PulseRing               a pulsing highlight ring (the tutorial uses it)
--   ShopKit.mask(parent, spec) -> Mask                         a dim mask that cuts out one target (the tutorial uses it)
--   ShopKit.countUp(label, opts?) -> CountUp                   number count-up text, visual only
--
-- Rules every part keeps: hit regions never move when the art moves (the art scales inside a fixed slot); hover is
-- mouse-only; press is strong for touch; reduced motion means a short fade or nothing and final numbers at once;
-- nothing loops while hidden (loops are finite tweens a scheduler starts, except the pending spinner, which a hidden
-- shop switches off); every connection belongs to a Trove the caller owns; a missing sound is silent and logged.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextService = game:GetService("TextService")
local UserInputService = game:GetService("UserInputService")

local Arcade = require(script.Parent.Arcade)
local Motion = require(script.Parent.Motion)
local PreviewTokens = require(script.Parent.PreviewTokens)
local Sounds = require(script.Parent.Sounds)
local Tokens = require(ReplicatedStorage.Shared.UI.Tokens)
local Trove = require(ReplicatedStorage.Packages.Trove)

local A = PreviewTokens.Arcade
local S = PreviewTokens.Shop
local M = S.Motion
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

-- Family art with a tint; falls back to the kit's neutral "?" glyph, so a missing icon is never a hole.
function ShopKit.icon(holder: Frame, name: string, opts: IconOptions?): boolean
	if Icons2 and Icons2.draw then
		local ok, drawn = pcall(Icons2.draw, holder, name, opts)
		if ok and drawn then
			return true
		end
	end
	return Arcade.icon(holder, name)
end

function ShopKit.fill(name: string): ColorSequence
	local shop = (S.Fill :: any)[name]
	if shop then
		return shop
	end
	local arcade = (A.Fill :: any)[name]
	if arcade then
		return arcade
	end
	return S.Fill.Violet
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
		Position = UDim2.fromOffset(side * (if right then 0.675 else 0.325), side * 0.325),
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
	make("UIGradient", { Color = S.Fill.Well, Rotation = 90, Parent = frame })
	return frame
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
			goal = if lastInputIsTouch() then M.PressScaleTouch else (parts.press or M.PressScale)
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
		applyScale(if down then M.PressSeconds else M.ReleaseSeconds)
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
	make("UIGradient", { Color = ShopKit.fill(spec.fill), Rotation = spec.rotation or 90, Parent = face })
	if spec.pattern then
		ShopKit.pattern(face, Vector2.new(spec.size.X, spec.size.Y - lipHeight), z + 3, 0.9)
	end
	local sheen: Frame = make("Frame", {
		Name = "Sheen",
		Position = UDim2.fromOffset(3, 3),
		Size = UDim2.new(1, -6, 0.4, 0),
		BackgroundColor3 = WHITE,
		BackgroundTransparency = 0.55,
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
	size: Vector2, -- design px, height at least 48
	z: number,
	trove: Trove.Trove,
	fill: string?, -- the idle fill (default Green)
	onActivate: (() -> ())?,
	sound: Sounds.Hook?,
}
export type PriceButton = {
	root: Frame,
	body: TextButton,
	face: Frame,
	label: TextLabel,
	setState: (state: PriceState, label: string?) -> (),
	getState: () -> PriceState,
	getLabel: () -> string,
	setLoops: (on: boolean) -> (),
	bounce: () -> (),
	isHover: () -> boolean,
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
	local w, h = spec.size.X, math.max(spec.size.Y, Tokens.Touch.Minimum)
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
	-- the idle bounce lives on its own wrapper (one UIScale per object), so it never fights hover or press
	local bouncer: Frame = make("Frame", {
		Name = "Bouncer",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(w / 2, h / 2),
		Size = UDim2.fromOffset(w, h),
		BackgroundTransparency = 1,
		ZIndex = z + 1,
		Parent = root,
	})
	local bounceScale: UIScale = make("UIScale", { Name = "Bounce", Parent = bouncer })
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
		Color = ShopKit.fill(spec.fill or "Green"),
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
		local fillName = STATE_FILL[newState] or spec.fill or "Green"
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
			Motion.cancelAll(bounceScale)
			bounceScale.Scale = 1
		end
	end

	-- one soft bounce (finite); the scheduler decides when, and never during hover, press or hidden
	local function bounce()
		if not loops or Motion.reduced() or state ~= "Idle" or wiring.isHover() then
			return
		end
		local t = Motion.tween(bounceScale, "bounce", Motion.info(M.BounceSeconds * 0.45), { Scale = 1.05 })
		t.Completed:Once(function(playback)
			if playback == Enum.PlaybackState.Completed then
				Motion.tween(
					bounceScale,
					"bounce",
					Motion.info(M.BounceSeconds * 0.55, Enum.EasingStyle.Bounce),
					{ Scale = 1 }
				)
			end
		end)
	end

	trove:Add(function()
		Motion.cancelAll(bounceScale)
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
		setLoops = setLoops,
		bounce = bounce,
		isHover = wiring.isHover,
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
	local h = height or S.Layout.TabHeight
	return math.ceil(12 + (h - 12) + 6 + textWidth(label, TAB_LABEL_SIZE) * 1.12 + 22)
end

-- A pill tab: an icon and a word; the active one is a bright green pill with a thicker outline (state is never
-- colour alone: the label turns white and outlined too).
function ShopKit.tab(parent: Instance, spec: TabSpec): Tab
	local h = spec.height or S.Layout.TabHeight
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
		Color = A.Fill.Green,
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
		colour = S.Color.TextSoft,
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
		label.TextColor3 = if on then WHITE else S.Color.TextSoft
	end
	setActive(false)
	return { root = root, width = width, setActive = setActive }
end

-- SHINE --------------------------------------------------------------------------------------------------------

export type ShineSpec = { radius: number, z: number, trove: Trove.Trove }
export type Shine = { root: CanvasGroup, play: () -> boolean }

-- One soft highlight band that crosses the card in 650 ms. The band lives in a CanvasGroup so it follows the card's
-- rounded corners; it is a plain Frame (never Active), so it never takes a press. Reduced motion: no sweep.
function ShopKit.shine(parent: GuiObject, spec: ShineSpec): Shine
	local group: CanvasGroup = spec.trove:Add(make("CanvasGroup", {
		Name = "Shine",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = spec.z,
		Parent = parent,
	}))
	Arcade.corner(group, spec.radius)
	local band: Frame = make("Frame", {
		Name = "Band",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(-0.3, 0.5),
		Size = UDim2.fromScale(0.2, 1.8),
		Rotation = 18,
		BackgroundColor3 = WHITE,
		BorderSizePixel = 0,
		Visible = false,
		ZIndex = spec.z + 1,
		Parent = group,
	})
	make("UIGradient", {
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.5, 0.4),
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
		band.Visible = true
		local tween = Motion.tween(
			band,
			"sweep",
			TweenInfo.new(M.ShineSeconds, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut),
			{ Position = UDim2.fromScale(1.3, 0.5) }
		)
		tween.Completed:Once(function()
			band.Visible = false
		end)
		return true
	end
	return { root = group, play = play }
end

-- SPARKLES -----------------------------------------------------------------------------------------------------

export type SparkleSpec = {
	z: number,
	trove: Trove.Trove,
	count: number?,
	region: { number }?, -- x0, y0, x1, y1 as fractions of the parent
	seed: number?,
}
export type Sparkles = { root: Frame, burst: () -> boolean, clear: () -> () }

-- 4 to 6 small four-point stars that grow and fade over about 600 ms, then are destroyed. Never a full-screen flash,
-- never a loop (the scheduler fires one burst at a time). Reduced motion: none.
function ShopKit.sparkles(parent: GuiObject, spec: SparkleSpec): Sparkles
	local layer: Frame = spec.trove:Add(make("Frame", {
		Name = "Sparkles",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = spec.z,
		Parent = parent,
	}))
	local rng = Random.new(spec.seed or 11)
	local region = spec.region or { 0.1, 0.1, 0.9, 0.9 }
	local function clear()
		layer:ClearAllChildren()
	end
	spec.trove:Add(clear)
	local function burst(): boolean
		if Motion.reduced() or not layer.Parent then
			return false
		end
		ShopKit.noteSoundDependency("ShopSparkle")
		local count = math.clamp(spec.count or M.SparkleCount, 4, 6)
		for _ = 1, count do
			local star: Frame = make("Frame", {
				Name = "Star",
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(rng:NextNumber(region[1], region[3]), rng:NextNumber(region[2], region[4])),
				Size = UDim2.fromOffset(18, 18),
				Rotation = rng:NextNumber(-20, 20),
				BackgroundTransparency = 1,
				ZIndex = spec.z,
				Parent = layer,
			})
			local scale: UIScale = make("UIScale", { Scale = 0, Parent = star })
			for _, dims in { Vector2.new(18, 5), Vector2.new(5, 18) } do
				local bar: Frame = make("Frame", {
					Name = "Bar",
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.fromScale(0.5, 0.5),
					Size = UDim2.fromOffset(dims.X, dims.Y),
					BackgroundColor3 = Color3.fromRGB(255, 246, 176),
					BorderSizePixel = 0,
					ZIndex = spec.z,
					Parent = star,
				})
				Arcade.corner(bar, 3)
			end
			local up = M.SparkleSeconds * 0.4
			local info =
				TweenInfo.new(up, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, false, rng:NextNumber(0, 0.2))
			local grow = Motion.tween(scale, "star", info, { Scale = 1 })
			grow.Completed:Once(function(playback)
				if playback ~= Enum.PlaybackState.Completed then
					star:Destroy()
					return
				end
				local fade = Motion.tween(scale, "star", Motion.info(M.SparkleSeconds * 0.6), { Scale = 0 })
				fade.Completed:Once(function()
					star:Destroy()
				end)
			end)
		end
		return true
	end
	return { root = layer, burst = burst, clear = clear }
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
