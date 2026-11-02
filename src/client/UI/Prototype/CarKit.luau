--!strict
-- CarKit: the one UI kit of the Round 3 screens (vault/design/ui-style-guide.md). A screen asks here for its fonts, colours,
-- cards, price buttons, stamps and image slots instead of choosing its own, so screens stop drifting apart.
--
--   CarKit.display() / CarKit.body()                the two fonts
--   CarKit.title(parent, text, px, opts?)           Display text: heavy miter stroke, optional top-lit gradient, drop shadow
--   CarKit.text(parent, text, px, opts?)            Readable text
--   CarKit.art(parent, key, opts?)                  an image in a fixed frame; a calm placeholder until it has loaded
--   CarKit.slot(parent, key, px, opts?)             an icon in a fixed square slot, from the slot sizes only
--   CarKit.pattern(parent, name, opts?)             a tinted, tiled motif (checker, speed, rays, tread, halftone, chevron, stripes)
--   CarKit.board(parent, opts?)                     a pit board: navy plate, ink line, chrome inner edge
--   CarKit.card(parent, family, opts?)              a product card in its family colour, with its motif
--   CarKit.button(parent, opts)                     Secondary, Retry, Home and friends; ink line, lip, press onto the lip
--   CarKit.price(parent, opts)                      THE green price button
--   CarKit.stamp(parent, top, bottom, px, opts?)    the red and gold deal seal
--   CarKit.setStrokeScale(scale)                    the screen's scale: strokes do not follow a UIScale
--
-- Nothing here reads a price or an amount: callers pass what they show.

local ContentProvider = game:GetService("ContentProvider")

local Prototype = script.Parent
local Arcade = require(Prototype.Arcade)
local GameIcons = require(Prototype.GameIcons)
local Motion = require(Prototype.Motion)
local Sounds = require(Prototype.Sounds)

local CarKit = {}

-- An instance from properties, parented last.
function CarKit.make(className: string, props: { [string]: any }, parent: Instance?): any
	local inst = Instance.new(className)
	for key, value in props do
		(inst :: any)[key] = value
	end
	if parent then
		inst.Parent = parent
	end
	return inst
end

local make = CarKit.make

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

local function seq(top: Color3, bottom: Color3): ColorSequence
	return ColorSequence.new(top, bottom)
end

CarKit.Ink = rgb(10, 14, 34)
CarKit.White = rgb(255, 255, 255)
CarKit.Soft = rgb(204, 218, 244)
CarKit.BezelTop = rgb(26, 40, 78)
CarKit.BezelBottom = rgb(13, 22, 48)
CarKit.Well = rgb(9, 15, 34)
CarKit.ChromeTop = rgb(226, 234, 248)
CarKit.ChromeBottom = rgb(102, 116, 146)
CarKit.Green = rgb(60, 224, 74)
CarKit.GreenDeep = rgb(20, 160, 44)
CarKit.GreenLip = rgb(8, 92, 30)
CarKit.CashText = rgb(112, 255, 120)
CarKit.Red = rgb(224, 32, 44)
CarKit.Gold = rgb(255, 210, 60)
CarKit.Orange = rgb(255, 138, 20)
CarKit.Yellow = rgb(255, 214, 40)

export type Family = {
	top: Color3,
	bottom: Color3,
	motif: string,
	motifColor: Color3,
	motifAlpha: number, -- transparency of the motif, higher is calmer
	edge: Color3,
}

-- One signature colour per product family (style guide).
CarKit.Family = table.freeze({
	Starter = {
		top = rgb(255, 168, 28),
		bottom = rgb(196, 56, 8),
		motif = "speed",
		motifColor = rgb(255, 232, 150),
		motifAlpha = 0.45,
		edge = rgb(255, 214, 110),
	},
	Vip = {
		top = rgb(52, 44, 26),
		bottom = rgb(14, 12, 12),
		motif = "chevron",
		motifColor = rgb(255, 198, 41),
		motifAlpha = 0.9,
		edge = rgb(255, 214, 80),
	},
	Lap = {
		top = rgb(40, 132, 255),
		bottom = rgb(12, 48, 170),
		motif = "speed",
		motifColor = rgb(170, 220, 255),
		motifAlpha = 0.6,
		edge = rgb(150, 210, 255),
	},
	Paddock = {
		top = rgb(24, 214, 186),
		bottom = rgb(6, 104, 120),
		motif = "stripes",
		motifColor = rgb(170, 255, 236),
		motifAlpha = 0.9,
		edge = rgb(150, 255, 230),
	},
	Bundle = {
		top = rgb(38, 56, 100),
		bottom = rgb(14, 22, 52),
		motif = "checker",
		motifColor = rgb(160, 186, 230),
		motifAlpha = 0.92,
		edge = rgb(216, 228, 248),
	},
	Cash = {
		top = rgb(52, 214, 96),
		bottom = rgb(6, 112, 62),
		motif = "rays",
		motifColor = rgb(200, 255, 190),
		motifAlpha = 0.72,
		edge = rgb(150, 255, 150),
	},
	CashBlue = {
		top = rgb(34, 136, 240),
		bottom = rgb(8, 44, 120),
		motif = "rays",
		motifColor = rgb(190, 230, 255),
		motifAlpha = 0.76,
		edge = rgb(120, 200, 255),
	},
	CashTeal = {
		top = rgb(16, 170, 130),
		bottom = rgb(4, 74, 76),
		motif = "rays",
		motifColor = rgb(190, 255, 230),
		motifAlpha = 0.76,
		edge = rgb(110, 240, 190),
	},
	CashGold = {
		top = rgb(250, 176, 28),
		bottom = rgb(150, 74, 6),
		motif = "rays",
		motifColor = rgb(255, 240, 180),
		motifAlpha = 0.72,
		edge = rgb(255, 216, 100),
	},
	CashPurple = {
		top = rgb(134, 62, 240),
		bottom = rgb(50, 16, 130),
		motif = "rays",
		motifColor = rgb(226, 200, 255),
		motifAlpha = 0.76,
		edge = rgb(200, 150, 255),
	},
	CashVault = {
		top = rgb(232, 38, 38),
		bottom = rgb(120, 8, 18),
		motif = "rays",
		motifColor = rgb(255, 214, 120),
		motifAlpha = 0.66,
		edge = rgb(255, 214, 60),
	},
	Paint = {
		top = rgb(255, 84, 170),
		bottom = rgb(160, 14, 104),
		motif = "halftone",
		motifColor = rgb(255, 200, 236),
		motifAlpha = 0.84,
		edge = rgb(255, 170, 220),
	},
	Decal = {
		top = rgb(255, 204, 40),
		bottom = rgb(208, 112, 6),
		motif = "checker",
		motifColor = rgb(255, 244, 190),
		motifAlpha = 0.9,
		edge = rgb(255, 234, 140),
	},
	Wheel = {
		top = rgb(132, 86, 255),
		bottom = rgb(50, 20, 158),
		motif = "tread",
		motifColor = rgb(210, 190, 255),
		motifAlpha = 0.84,
		edge = rgb(190, 170, 255),
	},
	Trail = {
		top = rgb(240, 70, 214),
		bottom = rgb(104, 16, 150),
		motif = "speed",
		motifColor = rgb(255, 210, 246),
		motifAlpha = 0.6,
		edge = rgb(255, 170, 240),
	},
	Free = {
		top = rgb(150, 232, 48),
		bottom = rgb(36, 132, 40),
		motif = "rays",
		motifColor = rgb(240, 255, 200),
		motifAlpha = 0.74,
		edge = rgb(210, 255, 150),
	},
} :: { [string]: Family })

CarKit.Rarity = table.freeze({
	Common = rgb(166, 176, 196),
	Uncommon = rgb(70, 220, 110),
	Rare = rgb(60, 150, 255),
	Epic = rgb(176, 92, 246),
	Legendary = rgb(255, 200, 40),
})

-- Button colours: top, bottom, lip.
CarKit.ButtonTone = table.freeze({
	Green = { CarKit.Green, CarKit.GreenDeep, CarKit.GreenLip },
	Orange = { rgb(255, 170, 44), rgb(238, 92, 12), rgb(128, 40, 4) },
	Blue = { rgb(64, 168, 255), rgb(20, 92, 232), rgb(8, 44, 130) },
	Navy = { rgb(38, 56, 104), rgb(20, 32, 68), rgb(6, 10, 26) },
	Red = { rgb(255, 84, 84), rgb(214, 24, 40), rgb(112, 8, 22) },
	Grey = { rgb(112, 124, 150), rgb(70, 80, 104), rgb(34, 40, 58) },
} :: { [string]: { Color3 } })

local TILE: { [string]: { size: number, uri: string } } = {
	checker = { size = 64, uri = "fx_checker" },
	chevron = { size = 72, uri = "fx_chevron" },
	stripes = { size = 64, uri = "fx_stripes" },
	halftone = { size = 96, uri = "fx_halftone" },
	tread = { size = 72, uri = "fx_tread" },
}

local strokeScale = 1

function CarKit.setStrokeScale(scale: number)
	strokeScale = scale
end

function CarKit.strokeScale(): number
	return strokeScale
end

function CarKit.display(): Font
	return Font.new("rbxasset://fonts/families/Bangers.json", Enum.FontWeight.Regular)
end

function CarKit.body(): Font
	return Font.new("rbxasset://fonts/families/FredokaOne.json", Enum.FontWeight.Regular)
end

export type TextOptions = {
	color: Color3?,
	top: Color3?, -- with `bottom`: a top-lit vertical gradient on the letters
	bottom: Color3?,
	stroke: number?, -- px; 0 for none
	shadow: boolean?, -- a hard drop shadow down and right (default true for titles)
	align: Enum.TextXAlignment?,
	alignY: Enum.TextYAlignment?,
	size: UDim2?,
	position: UDim2?,
	anchor: Vector2?,
	z: number?,
	wrap: boolean?,
	name: string?,
	rotation: number?,
	rich: boolean?,
}

local function baseLabel(parent: Instance, text: string, px: number, font: Font, o: TextOptions): TextLabel
	return make("TextLabel", {
		Name = o.name or "Text",
		BackgroundTransparency = 1,
		FontFace = font,
		Text = text,
		TextSize = px,
		TextColor3 = o.color or CarKit.White,
		TextXAlignment = o.align or Enum.TextXAlignment.Left,
		TextYAlignment = o.alignY or Enum.TextYAlignment.Center,
		TextWrapped = o.wrap == true,
		RichText = o.rich == true,
		Size = o.size or UDim2.fromScale(1, 1),
		Position = o.position or UDim2.new(),
		AnchorPoint = o.anchor or Vector2.zero,
		ZIndex = o.z or 1,
		Rotation = o.rotation or 0,
	}, parent)
end

-- Display text. The shadow is a darker copy behind; the stroke uses miter joins so the letters stay sharp and chunky.
function CarKit.title(parent: Instance, text: string, px: number, options: TextOptions?): TextLabel
	local o: TextOptions = options or {}
	local z = o.z or 1
	local stroke = o.stroke or math.max(1.5, px / 13)
	local label = baseLabel(parent, text, px, CarKit.display(), o)
	label.ZIndex = z + 1
	make("UIStroke", {
		Thickness = stroke * strokeScale,
		Color = CarKit.Ink,
		LineJoinMode = Enum.LineJoinMode.Miter,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
	}, label)
	if o.top and o.bottom then
		label.TextColor3 = CarKit.White
		make("UIGradient", { Rotation = 90, Color = seq(o.top, o.bottom) }, label)
	end
	if o.shadow ~= false then
		local shift = math.max(1, math.round(px / 24))
		local base = o.position or UDim2.new()
		local shadow = baseLabel(parent, text, px, CarKit.display(), o)
		shadow.Name = (o.name or "Text") .. "Shadow"
		shadow.TextColor3 = CarKit.Ink
		shadow.Position = base + UDim2.fromOffset(shift, shift + 1)
		shadow.ZIndex = z
		make("UIStroke", {
			Thickness = stroke * strokeScale,
			Color = CarKit.Ink,
			LineJoinMode = Enum.LineJoinMode.Miter,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
		}, shadow)
		label:GetPropertyChangedSignal("Text"):Connect(function()
			shadow.Text = label.Text
		end)
		label:GetPropertyChangedSignal("Visible"):Connect(function()
			shadow.Visible = label.Visible
		end)
	end
	return label
end

function CarKit.text(parent: Instance, text: string, px: number, options: TextOptions?): TextLabel
	local o: TextOptions = options or {}
	local label = baseLabel(parent, text, px, CarKit.body(), o)
	if o.stroke and o.stroke > 0 then
		make("UIStroke", {
			Thickness = o.stroke * strokeScale,
			Color = CarKit.Ink,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
		}, label)
	end
	return label
end

export type ArtOptions = {
	size: UDim2?,
	position: UDim2?,
	anchor: Vector2?,
	z: number?,
	placeholder: boolean?, -- default true: a calm rounded shape until the image has loaded
	color: Color3?,
	rotation: number?,
	transparency: number?,
	name: string?,
	fallbackIcon: string?, -- an Icons2 painter name to draw when there is no art here at all
}

-- An image in a fixed frame, centred with Fit. It stays clear until IsLoaded, then fades in, so nothing half loaded shows.
function CarKit.art(parent: Instance, key: string, options: ArtOptions?): Frame
	local o: ArtOptions = options or {}
	local z = o.z or 1
	local holder = make("Frame", {
		Name = o.name or ("Art_" .. key),
		BackgroundTransparency = 1,
		Size = o.size or UDim2.fromScale(1, 1),
		Position = o.position or UDim2.fromScale(0.5, 0.5),
		AnchorPoint = o.anchor or Vector2.new(0.5, 0.5),
		ZIndex = z,
		Rotation = o.rotation or 0,
	}, parent) :: Frame
	local uri = GameIcons.uri(key)
	if not uri then
		if o.fallbackIcon then
			Arcade.icon(holder, o.fallbackIcon)
		end
		return holder
	end
	local target = o.transparency or 0
	local shape: Frame? = nil
	if o.placeholder ~= false then
		local s = make("Frame", {
			Name = "Placeholder",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0.6, 0.6),
			BackgroundColor3 = CarKit.White,
			BackgroundTransparency = 0.88,
			ZIndex = z,
		}, holder) :: Frame
		make("UICorner", { CornerRadius = UDim.new(0.2, 0) }, s)
		shape = s
	end
	local image = make("ImageLabel", {
		Name = "Image",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ScaleType = Enum.ScaleType.Fit,
		ResampleMode = Enum.ResamplerMode.Default,
		ImageColor3 = o.color or CarKit.White,
		ImageTransparency = 1,
		Image = uri,
		ZIndex = z + 1,
	}, holder) :: ImageLabel
	local function show()
		if shape then
			shape:Destroy()
			shape = nil
		end
		if Motion.reduced() then
			image.ImageTransparency = target
		else
			Motion.tween(image, "CarKitLoad", Motion.info(0.12), { ImageTransparency = target })
		end
	end
	-- a clear image is never drawn, so it never loads by itself: fetch it, then reveal it
	task.spawn(function()
		pcall(function()
			ContentProvider:PreloadAsync({ image })
		end)
		if image.Parent then
			show()
		end
	end)
	return holder
end

CarKit.SlotSizes = table.freeze({ 24, 32, 48, 64, 96 })

export type SlotOptions = {
	position: UDim2?,
	anchor: Vector2?,
	z: number?,
	fallback: string?, -- an Icons2 painter name when there is no art here
}

-- An icon in a fixed square slot. The padding is baked into the art, so a row shares optical size and baseline.
function CarKit.slot(parent: Instance, key: string, px: number, options: SlotOptions?): Frame
	local o: SlotOptions = options or {}
	return CarKit.art(parent, key, {
		size = UDim2.fromOffset(px, px),
		position = o.position,
		anchor = o.anchor,
		z = o.z,
		fallbackIcon = o.fallback,
		name = "Slot_" .. key,
	})
end

export type PatternOptions = {
	color: Color3?,
	transparency: number?,
	z: number?,
	tile: number?,
	size: UDim2?,
	position: UDim2?,
	anchor: Vector2?,
}

-- A tinted motif. Tiles repeat; "speed" and "rays" are single images that crop to the frame's shape.
function CarKit.pattern(parent: Instance, name: string, options: PatternOptions?): ImageLabel?
	local o: PatternOptions = options or {}
	local tile = TILE[name]
	local uri = GameIcons.uri(if tile then tile.uri else "fx_" .. name)
	if not uri then
		return nil
	end
	local label = make("ImageLabel", {
		Name = "Motif_" .. name,
		BackgroundTransparency = 1,
		Image = uri,
		ImageColor3 = o.color or CarKit.White,
		ImageTransparency = o.transparency or 0.85,
		Size = o.size or UDim2.fromScale(1, 1),
		Position = o.position or UDim2.new(),
		AnchorPoint = o.anchor or Vector2.zero,
		ZIndex = o.z or 1,
		ScaleType = if tile then Enum.ScaleType.Tile else Enum.ScaleType.Crop,
	}, parent) :: ImageLabel
	if tile then
		label.TileSize = UDim2.fromOffset(o.tile or tile.size, o.tile or tile.size)
	end
	return label
end

export type BoardOptions = {
	size: UDim2?,
	position: UDim2?,
	anchor: Vector2?,
	z: number?,
	radius: number?,
	name: string?,
	top: Color3?,
	bottom: Color3?,
	bolts: boolean?,
}

-- Outer ink line plus a chrome inner edge.
function CarKit.edges(frame: GuiObject, radius: number, chrome: boolean?, edge: Color3?)
	make("UICorner", { CornerRadius = UDim.new(0, radius) }, frame)
	make(
		"UIStroke",
		{ Thickness = 3 * strokeScale, Color = CarKit.Ink, ApplyStrokeMode = Enum.ApplyStrokeMode.Border },
		frame
	)
	if chrome ~= false then
		local inner = make("Frame", {
			Name = "ChromeEdge",
			BackgroundTransparency = 1,
			Size = UDim2.new(1, -4, 1, -4),
			Position = UDim2.fromOffset(2, 2),
			ZIndex = frame.ZIndex + 40,
		}, frame)
		make("UICorner", { CornerRadius = UDim.new(0, math.max(radius - 2, 2)) }, inner)
		local line = make("UIStroke", {
			Thickness = 2 * strokeScale,
			Color = CarKit.White,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		}, inner)
		make("UIGradient", {
			Rotation = 90,
			Color = seq(edge or CarKit.ChromeTop, CarKit.ChromeBottom),
		}, line)
	end
end

function CarKit.board(parent: Instance, options: BoardOptions?): Frame
	local o: BoardOptions = options or {}
	local z = o.z or 1
	local board = make("Frame", {
		Name = o.name or "Board",
		BackgroundColor3 = CarKit.White,
		Size = o.size or UDim2.fromScale(1, 1),
		Position = o.position or UDim2.new(),
		AnchorPoint = o.anchor or Vector2.zero,
		ZIndex = z,
	}, parent) :: Frame
	make("UIGradient", { Rotation = 90, Color = seq(o.top or CarKit.BezelTop, o.bottom or CarKit.BezelBottom) }, board)
	CarKit.edges(board, o.radius or 14)
	if o.bolts then
		for _, corner in { { 0, 0 }, { 1, 0 }, { 0, 1 }, { 1, 1 } } do
			local bolt = make("Frame", {
				Name = "Bolt",
				AnchorPoint = Vector2.new(corner[1], corner[2]),
				Position = UDim2.new(
					corner[1],
					if corner[1] == 0 then 8 else -8,
					corner[2],
					if corner[2] == 0 then 8 else -8
				),
				Size = UDim2.fromOffset(8, 8),
				BackgroundColor3 = CarKit.ChromeBottom,
				ZIndex = z + 2,
			}, board)
			make("UICorner", { CornerRadius = UDim.new(1, 0) }, bolt)
			make("UIStroke", { Thickness = 1, Color = CarKit.Ink }, bolt)
		end
	end
	return board
end

export type CardOptions = {
	size: UDim2?,
	position: UDim2?,
	anchor: Vector2?,
	z: number?,
	radius: number?,
	name: string?,
}

-- A product card: family gradient, its motif rounded to the card, ink line and chrome edge. Nothing clips, so art may
-- overlap the card's edge on purpose.
function CarKit.card(parent: Instance, familyName: string, options: CardOptions?): (Frame, Family, UIGradient)
	local o: CardOptions = options or {}
	local family = (CarKit.Family :: any)[familyName] :: Family
	local z = o.z or 1
	local radius = o.radius or 14
	local card = make("Frame", {
		Name = o.name or ("Card" .. familyName),
		BackgroundTransparency = 1,
		Size = o.size or UDim2.fromScale(1, 1),
		Position = o.position or UDim2.new(),
		AnchorPoint = o.anchor or Vector2.zero,
		ZIndex = z,
	}, parent) :: Frame
	local clip = make("Frame", {
		Name = "Fill",
		BackgroundColor3 = CarKit.White,
		Size = UDim2.fromScale(1, 1),
		ZIndex = z,
	}, card) :: Frame
	make("UICorner", { CornerRadius = UDim.new(0, radius) }, clip)
	local gradient = make("UIGradient", { Rotation = 100, Color = seq(family.top, family.bottom) }, clip) :: UIGradient
	local motif = CarKit.pattern(card, family.motif, {
		color = family.motifColor,
		transparency = family.motifAlpha,
		z = z + 1,
	})
	if motif then
		make("UICorner", { CornerRadius = UDim.new(0, radius) }, motif)
	end
	local line = make("Frame", {
		Name = "Lines",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ZIndex = z + 30,
	}, card)
	CarKit.edges(line :: GuiObject, radius, true, family.edge)
	return card, family, gradient
end

export type ButtonOptions = {
	text: string,
	tone: string?, -- a ButtonTone key
	px: number?,
	size: UDim2?,
	position: UDim2?,
	anchor: Vector2?,
	z: number?,
	icon: string?,
	iconPx: number?,
	onPress: (() -> ())?,
	name: string?,
	radius: number?,
	sound: string?,
	breathe: boolean?,
}

export type Button = {
	root: TextButton,
	face: Frame,
	label: TextLabel,
	setText: (text: string) -> (),
	setTone: (tone: string) -> (),
	setEnabled: (on: boolean) -> (),
}

local LIP = 4

-- A chunky button: a face on a darker lip. It lifts on hover and presses down onto the lip.
function CarKit.button(parent: Instance, o: ButtonOptions): Button
	local z = o.z or 1
	local radius = o.radius or 12
	local tone = CarKit.ButtonTone[o.tone or "Navy"]
	local root = make("TextButton", {
		Name = o.name or o.text,
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false,
		Size = o.size or UDim2.fromOffset(160, 56),
		Position = o.position or UDim2.new(),
		AnchorPoint = o.anchor or Vector2.zero,
		ZIndex = z,
		Selectable = true,
	}, parent) :: TextButton
	local lip = make("Frame", {
		Name = "Lip",
		BackgroundColor3 = tone[3],
		Size = UDim2.new(1, 0, 1, 0),
		ZIndex = z,
	}, root) :: Frame
	make("UICorner", { CornerRadius = UDim.new(0, radius) }, lip)
	make(
		"UIStroke",
		{ Thickness = 3 * strokeScale, Color = CarKit.Ink, ApplyStrokeMode = Enum.ApplyStrokeMode.Border },
		lip
	)
	local face = make("Frame", {
		Name = "Face",
		BackgroundColor3 = CarKit.White,
		Size = UDim2.new(1, 0, 1, -LIP),
		ZIndex = z + 1,
	}, root) :: Frame
	make("UICorner", { CornerRadius = UDim.new(0, radius) }, face)
	local gradient = make("UIGradient", { Rotation = 90, Color = seq(tone[1], tone[2]) }, face) :: UIGradient
	local gloss = make("Frame", {
		Name = "Gloss",
		BackgroundColor3 = CarKit.White,
		BackgroundTransparency = 0.72,
		Position = UDim2.new(0, 5, 0, 3),
		Size = UDim2.new(1, -10, 0.34, 0),
		ZIndex = z + 2,
	}, face)
	make("UICorner", { CornerRadius = UDim.new(0, math.max(radius - 4, 3)) }, gloss)
	local px = o.px or 26
	local inner = make("Frame", {
		Name = "Row",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ZIndex = z + 3,
	}, face)
	make("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, inner)
	if o.icon then
		local slot = CarKit.slot(inner, o.icon, o.iconPx or math.round(px * 1.25), { z = z + 3 })
		slot.LayoutOrder = 1
	end
	local labelHost = make("Frame", {
		Name = "LabelHost",
		BackgroundTransparency = 1,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, px * 1.2),
		LayoutOrder = 2,
		ZIndex = z + 3,
	}, inner)
	local label = baseLabel(labelHost, o.text, px, CarKit.display(), {
		size = UDim2.new(0, 0, 1, 0),
		z = z + 3,
		name = "Label",
	})
	label.AutomaticSize = Enum.AutomaticSize.X
	make("UIStroke", {
		Thickness = math.max(1.5, px / 11) * strokeScale,
		Color = CarKit.Ink,
		LineJoinMode = Enum.LineJoinMode.Miter,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
	}, label)

	local enabled = true
	local function place(y: number)
		if Motion.reduced() then
			face.Position = UDim2.fromOffset(0, 0)
			return
		end
		Motion.tween(face, "CarKitPress", Motion.info(0.08), { Position = UDim2.fromOffset(0, y) })
	end
	root.MouseEnter:Connect(function()
		if enabled then
			place(-2)
		end
	end)
	root.MouseLeave:Connect(function()
		place(0)
	end)
	root.MouseButton1Down:Connect(function()
		if enabled then
			place(LIP - 1)
		end
	end)
	root.MouseButton1Up:Connect(function()
		place(0)
	end)
	root.Activated:Connect(function()
		if enabled and o.onPress then
			pcall(function()
				Sounds.play(o.sound or "Press")
			end)
			o.onPress()
		end
	end)
	return {
		root = root,
		face = face,
		label = label,
		setText = function(text: string)
			label.Text = text
		end,
		setTone = function(name: string)
			local t = CarKit.ButtonTone[name]
			lip.BackgroundColor3 = t[3]
			gradient.Color = seq(t[1], t[2])
		end,
		setEnabled = function(on: boolean)
			enabled = on
			root.Active = on
		end,
	}
end

export type PriceOptions = {
	amount: number?, -- nil: `text` alone
	word: string?, -- "Robux"
	text: string?,
	px: number?,
	size: UDim2?,
	position: UDim2?,
	anchor: Vector2?,
	z: number?,
	onPress: (() -> ())?,
	name: string?,
	tone: string?,
}

-- THE price button: the same green everywhere. The number in Display, the small word beside it.
function CarKit.price(parent: Instance, o: PriceOptions): Button
	local px = o.px or 30
	local text = o.text or tostring(o.amount or "")
	local button = CarKit.button(parent, {
		text = text,
		tone = o.tone or "Green",
		px = px,
		size = o.size,
		position = o.position,
		anchor = o.anchor,
		z = o.z,
		onPress = o.onPress,
		name = o.name or "Price",
	})
	if o.word then
		local host = button.label.Parent :: Frame
		local row = host.Parent :: Frame
		local word = make("Frame", {
			Name = "WordHost",
			BackgroundTransparency = 1,
			Size = UDim2.fromOffset(0, px * 1.2),
			AutomaticSize = Enum.AutomaticSize.X,
			LayoutOrder = 3,
			ZIndex = button.label.ZIndex,
		}, row)
		local small = baseLabel(word, o.word, math.max(12, math.round(px * 0.46)), CarKit.body(), {
			size = UDim2.new(0, 0, 1, 0),
			z = button.label.ZIndex,
			alignY = Enum.TextYAlignment.Bottom,
			name = "Word",
		})
		small.AutomaticSize = Enum.AutomaticSize.X
		make("UIStroke", {
			Thickness = 1.5 * strokeScale,
			Color = CarKit.Ink,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
		}, small)
	end
	return button
end

export type StampOptions = {
	position: UDim2?,
	anchor: Vector2?,
	z: number?,
	rotation: number?,
}

-- The red and gold seal, always the same. Two short lines of live text sit on the art.
function CarKit.stamp(parent: Instance, top: string, bottom: string?, px: number, options: StampOptions?): Frame
	local o: StampOptions = options or {}
	local z = o.z or 1
	local holder = CarKit.art(parent, "stamp_seal", {
		size = UDim2.fromOffset(px, px),
		position = o.position,
		anchor = o.anchor,
		z = z,
		rotation = o.rotation or -10,
		placeholder = false,
		name = "Stamp",
	})
	if not GameIcons.has("stamp_seal") then
		local disc = make("Frame", {
			Size = UDim2.fromScale(0.86, 0.86),
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = CarKit.Red,
			ZIndex = z,
		}, holder)
		make("UICorner", { CornerRadius = UDim.new(1, 0) }, disc)
		make("UIStroke", { Thickness = 3, Color = CarKit.Gold }, disc)
	end
	local textPx = math.round(px * (if bottom then 0.27 else 0.32))
	local h = textPx * 1.02
	CarKit.title(holder, top, textPx, {
		align = Enum.TextXAlignment.Center,
		size = UDim2.new(1, 0, 0, h),
		position = UDim2.new(0, 0, 0.5, if bottom then -h else -h / 2),
		z = z + 2,
		top = CarKit.White,
		bottom = CarKit.Gold,
		stroke = 2,
		shadow = false,
	})
	if bottom then
		CarKit.title(holder, bottom, textPx, {
			align = Enum.TextXAlignment.Center,
			size = UDim2.new(1, 0, 0, h),
			position = UDim2.new(0, 0, 0.5, 0),
			z = z + 2,
			top = CarKit.White,
			bottom = CarKit.Gold,
			stroke = 2,
			shadow = false,
		})
	end
	return holder
end

return CarKit
