--!strict
-- CardKit: the cream "story card" family used by the Round 2 cards (Welcome back, Dialogue, What's new, Stunt results).
-- Lane 3, PREVIEW. Built on the Arcade kit and Style; it adds only what those four cards share and the kit does not have:
-- a blue-bordered cream card with a hard dark lip, an outlined title plate that sits over the card's top edge, navy text
-- without an outline, soft light rays, a gold coin, a layered UI car and a small icon holder that falls back to the kit.
--
--   CardKit.card(parent, spec) -> Card                  -- { root, frame, body, lip }; size and place `root`
--   CardKit.titlePlate(parent, spec) -> Plate           -- an outlined title with an icon, over the card's top edge
--   CardKit.ink(parent, text, size, opts?) -> TextLabel -- navy text with no outline, shrinks to fit (>= 16)
--   CardKit.icon(parent, names, px, z?) -> Frame        -- family art (first name that has art), else the kit's "?"
--   CardKit.rays(parent, spec) -> Rays                  -- soft light rays behind a card (6 bars = 12 rays)
--   CardKit.coin(parent, px, z) -> Frame                -- a gold coin drawn from shapes
--   CardKit.uiCar(parent, spec, z) -> CarArt            -- a layered 2D car (no face), 100 : 56 box
--   CardKit.star(parent, px, z) -> Frame                -- a four-point sparkle (two crossed bars)
--   CardKit.visible(node) -> boolean                    -- true when the node and every parent up to the ScreenGui shows
--
-- Everything here is built from frames and built once; nothing in this file runs a loop. Motion belongs to the screen that
-- owns the card (one scoped animator each) and honours Motion.reduced().

local Prototype = script.Parent.Parent
local Arcade = require(Prototype.Arcade)
local IconArt = require(Prototype.Home.IconArt)
local PreviewTokens = require(Prototype.PreviewTokens)
local Style = require(script.Parent.Style)
local SupportKit = require(script.Parent.SupportKit)

local A = PreviewTokens.Arcade
local make = Arcade.make

local CardKit = {}

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

-- TOKEN CANDIDATES (Round 2, shared by the story cards)
CardKit.Cream = rgb(255, 246, 227)
CardKit.CreamShade = rgb(240, 226, 196)
CardKit.Navy = rgb(22, 36, 63) -- text on cream (the approved Ink role)
CardKit.NavySoft = rgb(52, 66, 99)
CardKit.BorderTop = rgb(96, 160, 255)
CardKit.BorderBottom = rgb(44, 96, 214)
CardKit.PlateTop = rgb(38, 62, 150)
CardKit.PlateBottom = rgb(14, 24, 84)
CardKit.Gold = rgb(255, 208, 64)
CardKit.GoldDeep = rgb(230, 150, 0)
CardKit.Ink = A.Ink

-- CARD ---------------------------------------------------------------------------------------------------------------

export type Card = {
	root: Frame, -- size and place this (its own anchor is the centre)
	frame: Frame, -- the blue border
	body: Frame, -- the cream surface (content goes here)
	lip: Frame,
}

export type CardSpec = {
	name: string?,
	z: number?,
	radius: number?,
	border: number?, -- width of the blue border in px (default 6)
	top: Color3?,
	bottom: Color3?,
	cream: Color3?,
}

function CardKit.card(parent: Instance, spec: CardSpec): Card
	local z = spec.z or 3
	local radius = spec.radius or 16
	local border = spec.border or 6
	local root: Frame = make("Frame", {
		Name = spec.name or "Card",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(560, 340),
		BackgroundTransparency = 1,
		ZIndex = z,
		Parent = parent,
	})
	local lip: Frame = make("Frame", {
		Name = "Lip",
		Position = UDim2.fromOffset(0, 6),
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = A.Ink,
		BorderSizePixel = 0,
		ZIndex = z,
		Parent = root,
	})
	Arcade.corner(lip, radius)
	local frame: Frame = make("Frame", {
		Name = "Frame",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		ZIndex = z,
		Parent = root,
	})
	Arcade.corner(frame, radius)
	Arcade.outline(frame, "Button")
	make("UIGradient", {
		Color = ColorSequence.new(spec.top or CardKit.BorderTop, spec.bottom or CardKit.BorderBottom),
		Rotation = 90,
		Parent = frame,
	})
	local body: Frame = make("Frame", {
		Name = "Body",
		Position = UDim2.fromOffset(border, border),
		Size = UDim2.new(1, -border * 2, 1, -border * 2),
		BackgroundColor3 = spec.cream or CardKit.Cream,
		BorderSizePixel = 0,
		ZIndex = z + 1,
		Parent = frame,
	})
	Arcade.corner(body, math.max(radius - 4, 4))
	Arcade.outline(body, "Minor")
	return { root = root, frame = frame, body = body, lip = lip }
end

-- TITLE PLATE --------------------------------------------------------------------------------------------------------

export type Plate = {
	root: Frame,
	label: TextLabel,
	icon: Frame?,
	-- sets the plate's width to its text (never above `maxWidth`) and returns it
	fit: (self: Plate, maxWidth: number) -> number,
}

export type PlateSpec = {
	text: string,
	icon: string?, -- a painter name ("Moon", "Lock", "Info", "Trophy" ...)
	iconFallback: { string }?,
	size: number?, -- text size, default 36
	height: number?, -- default 52
	face: Arcade.FaceName?, -- default "Keys" (yellow glyphs)
	top: Color3?, -- plate colours (default the deep navy pair)
	bottom: Color3?,
	edge: Color3?, -- the thin bright line inside the dark boundary
	rightInset: number?, -- room kept free on the right for a close X that overlaps the plate (default 14)
	z: number?,
}

-- An outlined title on a deep navy plate with a bright blue edge, like the concept boards' "WELCOME BACK!" strip. The icon
-- sits on the left edge and overhangs it a little. The plate is placed by the caller (centre it on the card's top edge).
function CardKit.titlePlate(parent: Instance, spec: PlateSpec): Plate
	local z = spec.z or 20
	local height = spec.height or 52
	local textSize = spec.size or 36
	local root: Frame = make("Frame", {
		Name = "TitlePlate",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(300, height),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		ZIndex = z,
		Parent = parent,
	})
	Arcade.corner(root, math.floor(height * 0.42))
	Arcade.outline(root, "Button")
	make("UIGradient", {
		Color = ColorSequence.new(spec.top or CardKit.PlateTop, spec.bottom or CardKit.PlateBottom),
		Rotation = 90,
		Parent = root,
	})
	local rightInset = spec.rightInset or 14
	-- a thin bright edge inside the dark boundary
	local edge: Frame = make("Frame", {
		Name = "Edge",
		Position = UDim2.fromOffset(3, 3),
		Size = UDim2.new(1, -6, 1, -6),
		BackgroundTransparency = 1,
		ZIndex = z + 1,
		Parent = root,
	})
	Arcade.corner(edge, math.max(math.floor(height * 0.42) - 3, 4))
	Arcade.outline(edge, 2, spec.edge or rgb(90, 150, 255))
	local iconHolder: Frame? = nil
	local left = 14
	if spec.icon then
		local px = math.floor(height * 1.08)
		local names = { spec.icon }
		for _, extra in spec.iconFallback or {} do
			table.insert(names, extra)
		end
		local holder = CardKit.icon(root, names, px, z + 6)
		holder.AnchorPoint = Vector2.new(0, 0.5)
		holder.Position = UDim2.new(0, -6, 0.5, -2)
		iconHolder = holder
		left = px - 2
	end
	local label = Style.text(root, spec.text, "Display", {
		name = "Title",
		face = spec.face or "Keys",
		size = textSize,
		xAlign = Enum.TextXAlignment.Center,
		z = z + 4,
	})
	label.AnchorPoint = Vector2.new(0, 0.5)
	label.Position = UDim2.new(0, left, 0.5, 0)
	label.Size = UDim2.new(1, -left - rightInset, 0, textSize + 8)
	local plate: Plate
	plate = {
		root = root,
		label = label,
		icon = iconHolder,
		fit = function(_self: Plate, maxWidth: number): number
			local natural = math.ceil(SupportKit.measure(label.Text, textSize).X) + left + rightInset + 14
			local width = math.min(natural, maxWidth)
			root.Size = UDim2.fromOffset(width, height)
			return width
		end,
	}
	plate:fit(4096)
	return plate
end

-- TEXT ---------------------------------------------------------------------------------------------------------------

export type InkOptions = {
	name: string?,
	xAlign: Enum.TextXAlignment?,
	colour: Color3?,
	z: number?,
	wrapped: boolean?, -- wrap instead of shrinking; the caller sizes the box
}

-- Navy text on cream: no outline (a dark outline on a pale card turns the letters to mud). One line shrinks to fit its
-- box down to the approved 16; a wrapped paragraph keeps its size and the caller makes the box tall enough.
function CardKit.ink(parent: Instance, text: string, size: number, opts: InkOptions?): TextLabel
	local o: InkOptions = opts or {}
	local s = math.max(size, 16)
	local label: TextLabel = make("TextLabel", {
		Name = o.name or "Ink",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, s + 6),
		FontFace = Font.fromName("FredokaOne"),
		Text = text,
		TextSize = s,
		TextColor3 = o.colour or CardKit.Navy,
		TextXAlignment = o.xAlign or Enum.TextXAlignment.Center,
		TextYAlignment = Enum.TextYAlignment.Center,
		TextWrapped = o.wrapped == true,
		ZIndex = o.z or 6,
		Parent = parent,
	})
	if o.wrapped ~= true then
		make("UITextSizeConstraint", { MaxTextSize = s, MinTextSize = 16, Parent = label })
		label.TextScaled = true
	end
	return label
end

-- ICONS --------------------------------------------------------------------------------------------------------------

-- A px-square holder with the first of `names` that has family art; the kit's "?" glyph when none has (never a blank).
function CardKit.icon(parent: Instance, names: { string }, px: number, z: number?): Frame
	local holder: Frame = make("Frame", {
		Name = "Icon",
		Size = UDim2.fromOffset(px, px),
		BackgroundTransparency = 1,
		ZIndex = z or 8,
		Parent = parent,
	})
	IconArt.draw(holder, names)
	return holder
end

-- A four-point sparkle: two crossed bars. Returned as one Frame so an animator can size and fade it as a unit.
function CardKit.star(parent: Instance, px: number, z: number): Frame
	local holder: Frame = make("Frame", {
		Name = "Star",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(px, px),
		BackgroundTransparency = 1,
		ZIndex = z,
		Parent = parent,
	})
	for _, bar in { Vector2.new(1, 0.22), Vector2.new(0.22, 1) } do
		local f: Frame = make("Frame", {
			Name = "Bar",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(bar.X, bar.Y),
			BackgroundColor3 = rgb(255, 244, 170),
			BorderSizePixel = 0,
			ZIndex = z,
			Parent = holder,
		})
		Arcade.corner(f, 99)
	end
	local core: Frame = make("Frame", {
		Name = "Core",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.34, 0.34),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		ZIndex = z + 1,
		Parent = holder,
	})
	Arcade.corner(core, 99)
	return holder
end

-- RAYS ---------------------------------------------------------------------------------------------------------------

export type Rays = {
	root: Frame, -- centre it on the card; rotate its Rotation to spin the rays
	setRadius: (self: Rays, radius: number) -> (),
}

export type RaySpec = {
	bars: number?, -- full-diameter bars (each is two rays), default 6
	radius: number?,
	z: number?,
	colour: Color3?,
	transparency: number?, -- at the centre; the ends are always clear (default 0.8)
}

-- Soft light rays: each bar spans the whole diameter, bright near the middle and clear at both ends, so there is no hard
-- edge anywhere. Cheap: `bars` frames, no images.
function CardKit.rays(parent: Instance, spec: RaySpec): Rays
	local bars = spec.bars or 6
	local radius = spec.radius or 260
	local root: Frame = make("Frame", {
		Name = "Rays",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(radius * 2, radius * 2),
		BackgroundTransparency = 1,
		ZIndex = spec.z or 1,
		Parent = parent,
	})
	pcall(function()
		(root :: any).Interactable = false
	end)
	local list: { Frame } = {}
	for i = 1, bars do
		local bar: Frame = make("Frame", {
			Name = "Ray" .. i,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(radius * 0.2, radius * 2),
			Rotation = (i - 1) * 180 / bars,
			BackgroundColor3 = spec.colour or rgb(255, 242, 170),
			BorderSizePixel = 0,
			ZIndex = spec.z or 1,
			Parent = root,
		})
		make("UIGradient", {
			Rotation = 90,
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(0.5, spec.transparency or 0.8),
				NumberSequenceKeypoint.new(1, 1),
			}),
			Parent = bar,
		})
		table.insert(list, bar)
	end
	return {
		root = root,
		setRadius = function(_self: Rays, r: number)
			root.Size = UDim2.fromOffset(r * 2, r * 2)
			for _, bar in list do
				bar.Size = UDim2.fromOffset(r * 0.2, r * 2)
			end
		end,
	}
end

-- COIN ---------------------------------------------------------------------------------------------------------------

-- A gold coin drawn from shapes: a ringed disc with a highlight. Big coins carry a "$"; tiny ones stay plain.
function CardKit.coin(parent: Instance, px: number, z: number): Frame
	local coin: Frame = make("Frame", {
		Name = "Coin",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(px, px),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		ZIndex = z,
		Parent = parent,
	})
	Arcade.corner(coin, px)
	Arcade.outline(coin, if px >= 40 then "Major" else "Minor")
	make("UIGradient", { Color = A.Fill.Gold, Rotation = 90, Parent = coin })
	local ring: Frame = make("Frame", {
		Name = "Ring",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.68, 0.68),
		BackgroundTransparency = 1,
		ZIndex = z + 1,
		Parent = coin,
	})
	Arcade.corner(ring, px)
	make("UIStroke", {
		Thickness = math.max(1.5, px * 0.05),
		Color = CardKit.GoldDeep,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = ring,
	})
	local shine: Frame = make("Frame", {
		Name = "Shine",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.3, 0.26),
		Size = UDim2.fromScale(0.2, 0.2),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.25,
		BorderSizePixel = 0,
		ZIndex = z + 2,
		Parent = coin,
	})
	Arcade.corner(shine, px)
	if px >= 36 then
		local mark = Arcade.text(coin, {
			text = "$",
			role = "Value",
			name = "Mark",
			size = math.floor(px * 0.5),
			colour = CardKit.GoldDeep,
			z = z + 3,
		})
		mark.AnchorPoint = Vector2.new(0.5, 0.5)
		mark.Position = UDim2.fromScale(0.5, 0.52)
		mark.Size = UDim2.fromScale(0.7, 0.7)
		local markStroke = mark:FindFirstChildOfClass("UIStroke")
		if markStroke then
			markStroke.Enabled = false
		end
	end
	return coin
end

-- UI CAR -------------------------------------------------------------------------------------------------------------

export type CarSpec = {
	colour: Color3,
	family: string?, -- "Compact" | "Sedan" | "Pickup" | "Van" | "Sports" ... (any other name draws a Compact)
	name: string?,
}

export type CarArt = {
	root: Frame, -- a 100 : 56 box; size it, anchor it, move it
	shadow: Frame, -- the ground shadow, outside the box's bottom edge
	body: Frame,
}

-- shape of each family in fractions of the 100 x 56 box: body x, y, w, h; cabin x, y, w, h
local SHAPES: { [string]: { number } } = {
	Compact = { 0.04, 0.4, 0.92, 0.36, 0.22, 0.12, 0.5, 0.34 },
	Sedan = { 0.02, 0.42, 0.96, 0.34, 0.2, 0.14, 0.52, 0.32 },
	Sports = { 0.02, 0.46, 0.96, 0.3, 0.3, 0.2, 0.4, 0.28 },
	Pickup = { 0.02, 0.4, 0.96, 0.36, 0.5, 0.1, 0.38, 0.34 },
	Van = { 0.04, 0.3, 0.92, 0.46, 0.08, 0.08, 0.7, 0.34 },
}

-- A layered 2D car: shadow, two wheels, body, cabin with a window, a head lamp and a tail lamp. NO face, eyes or mouth
-- (Brian L's cars never get a face). Colours come from the supplied paint; the family only changes the silhouette.
-- Wheels sit at the bottom of the box so a bounce can lift the box and squash the shadow.
function CardKit.uiCar(parent: Instance, spec: CarSpec, z: number): CarArt
	local shape = SHAPES[spec.family or "Compact"] or SHAPES.Compact
	local root: Frame = make("Frame", {
		Name = "UiCar_" .. (spec.name or "car"),
		AnchorPoint = Vector2.new(0.5, 1),
		Size = UDim2.fromOffset(100, 56),
		BackgroundTransparency = 1,
		ZIndex = z,
		Parent = parent,
	})
	local aspect = 100 / 56
	local shadow: Frame = make("Frame", {
		Name = "Shadow",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 1.02),
		Size = UDim2.fromScale(0.92, 0.14),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.6,
		BorderSizePixel = 0,
		ZIndex = z,
		Parent = root,
	})
	Arcade.corner(shadow, 99)
	local body: Frame = make("Frame", {
		Name = "Body",
		Position = UDim2.fromScale(shape[1], shape[2]),
		Size = UDim2.fromScale(shape[3], shape[4]),
		BackgroundColor3 = spec.colour,
		BorderSizePixel = 0,
		ZIndex = z + 2,
		Parent = root,
	})
	Arcade.corner(body, 99)
	Arcade.outline(body, "Minor")
	make("UIGradient", {
		Color = ColorSequence.new(Color3.new(1, 1, 1), rgb(190, 190, 205)),
		Rotation = 90,
		Parent = body,
	})
	local cabin: Frame = make("Frame", {
		Name = "Cabin",
		Position = UDim2.fromScale(shape[5], shape[6]),
		Size = UDim2.fromScale(shape[7], shape[8]),
		BackgroundColor3 = spec.colour:Lerp(Color3.new(1, 1, 1), 0.12),
		BorderSizePixel = 0,
		ZIndex = z + 1,
		Parent = root,
	})
	Arcade.corner(cabin, 99)
	Arcade.outline(cabin, "Minor")
	local window: Frame = make("Frame", {
		Name = "Window",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.52),
		Size = UDim2.fromScale(0.74, 0.6),
		BackgroundColor3 = rgb(40, 62, 110),
		BorderSizePixel = 0,
		ZIndex = z + 3,
		Parent = cabin,
	})
	Arcade.corner(window, 99)
	-- wheels: circles, so the height scale is the width scale times the box aspect
	for _, x in { 0.27, 0.74 } do
		local d = 0.2
		local wheel: Frame = make("Frame", {
			Name = "Wheel",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(x, 0.8),
			Size = UDim2.fromScale(d, d * aspect),
			BackgroundColor3 = rgb(24, 30, 50),
			BorderSizePixel = 0,
			ZIndex = z + 4,
			Parent = root,
		})
		Arcade.corner(wheel, 99)
		Arcade.outline(wheel, "Minor")
		local hub: Frame = make("Frame", {
			Name = "Hub",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0.46, 0.46),
			BackgroundColor3 = rgb(206, 214, 232),
			BorderSizePixel = 0,
			ZIndex = z + 5,
			Parent = wheel,
		})
		Arcade.corner(hub, 99)
	end
	local lamp: Frame = make("Frame", {
		Name = "Headlamp",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.fromScale(shape[1] + shape[3] - 0.01, shape[2] + shape[4] * 0.38),
		Size = UDim2.fromScale(0.07, 0.07 * aspect),
		BackgroundColor3 = rgb(255, 244, 170),
		BorderSizePixel = 0,
		ZIndex = z + 5,
		Parent = root,
	})
	Arcade.corner(lamp, 99)
	local tail: Frame = make("Frame", {
		Name = "Taillamp",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.fromScale(shape[1] + 0.01, shape[2] + shape[4] * 0.38),
		Size = UDim2.fromScale(0.05, 0.05 * aspect),
		BackgroundColor3 = rgb(240, 70, 80),
		BorderSizePixel = 0,
		ZIndex = z + 5,
		Parent = root,
	})
	Arcade.corner(tail, 99)
	return { root = root, shadow = shadow, body = body }
end

-- VISIBILITY ---------------------------------------------------------------------------------------------------------

-- True when `node` and every GuiObject above it is visible and its ScreenGui is enabled (the test a scoped animator uses to
-- rest while its card is hidden).
function CardKit.visible(node: Instance): boolean
	local current: Instance? = node
	while current do
		if current:IsA("GuiObject") and not current.Visible then
			return false
		elseif current:IsA("LayerCollector") then
			return current.Enabled
		end
		current = current.Parent
	end
	return false
end

return CardKit
