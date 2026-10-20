--!strict
-- Original cash-stack icon built from UI shapes (Lane 3). Style inspired by
-- the currency-counter reference (chunky, outlined, saturated, tilted, a
-- band around the bills); no artwork is traced or reused.
--
-- Three fanned bills with dark outlines, a lighter inset border on the top
-- bill, a gold band across the middle of the top bill, a small upper-left
-- shine, and a faint shadow, tilted 10 degrees. The inset border is the
-- first detail to drop if the icon is ever shown below 32 px.
--
-- Alignment (revision 4):
--   * The band is a child of the top bill, centred in the bill's own rotated
--     coordinates, so it stays centred at every size and rotation.
--   * The visible bounds of the whole composition (rotated bills, outlines,
--     band overhang and shadow) are computed from the geometry below and the
--     stack is offset so their centre is the centre of the square holder.
--   * CashIcon.ArtSize is that visible size; the counter uses it to place the
--     icon 8 px from the digits and centred on their visible height.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local IconGeometry = require(script.Parent.Parent.IconGeometry)
local Tokens = require(ReplicatedStorage.Shared.UI.Tokens)

local CashIcon = {}

local BILL = Vector2.new(34, 18)
local FAN = Vector2.new(3, 4) -- each lower bill sits this far right and down
local RADIUS = 3
local OUTLINE = 2
local BAND_WIDTH = 8
local BAND_OVERHANG = 2 -- the band wraps slightly past the bill's edges
local SHADOW_OFFSET = Vector2.new(1, 2) -- under the bottom bill
local ROTATION = -10
-- Scale chosen so the visible artwork is about 1.25 times the visible digit
-- height of 40 px Fredoka One with its outline (33.6 px, measured in Studio).
local STACK_SCALE = 1.25

-- Stack frame: the unrotated union of the three bills (outlines excluded).
local STACK = Vector2.new(BILL.X + 2 * FAN.X, BILL.Y + 2 * FAN.Y)

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

-- Every visible shape in stack coordinates, outlines included.
local function shapes(): { IconGeometry.Shape }
	local list: { IconGeometry.Shape } = {}
	-- Shadow (no outline).
	table.insert(list, {
		x = 2 * FAN.X + SHADOW_OFFSET.X,
		y = 2 * FAN.Y + SHADOW_OFFSET.Y,
		w = BILL.X,
		h = BILL.Y,
		r = RADIUS,
	})
	-- Bills with outlines.
	for i = 0, 2 do
		table.insert(list, {
			x = i * FAN.X - OUTLINE,
			y = i * FAN.Y - OUTLINE,
			w = BILL.X + 2 * OUTLINE,
			h = BILL.Y + 2 * OUTLINE,
			r = RADIUS + OUTLINE,
		})
	end
	-- Band on the top bill, with its overhang and outline.
	table.insert(list, {
		x = (BILL.X - BAND_WIDTH) / 2 - OUTLINE,
		y = -BAND_OVERHANG - OUTLINE,
		w = BAND_WIDTH + 2 * OUTLINE,
		h = BILL.Y + 2 * BAND_OVERHANG + 2 * OUTLINE,
		r = 2 + OUTLINE,
	})
	return list
end

local ART_SIZE, ART_CENTRE = IconGeometry.bounds(shapes(), STACK, ROTATION, STACK_SCALE)
local SIDE = math.ceil(math.max(ART_SIZE.X, ART_SIZE.Y)) + 2

-- Square holder size at scale 1.0, and the visible artwork size inside it
-- (centred in the holder).
CashIcon.Size = Vector2.new(SIDE, SIDE)
CashIcon.ArtSize = ART_SIZE

local function bill(parent: Instance, name: string, index: number, color: Color3, palette: Tokens.Palette): Frame
	local f = make("Frame", {
		Name = name,
		Position = UDim2.fromOffset(index * FAN.X, index * FAN.Y),
		Size = UDim2.fromOffset(BILL.X, BILL.Y),
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		ZIndex = 4 - index,
		Parent = parent,
	})
	make("UICorner", { CornerRadius = UDim.new(0, RADIUS), Parent = f })
	make("UIStroke", { Color = palette.CashOutline, Thickness = OUTLINE, Parent = f })
	return f
end

-- Builds the icon inside `parent` and returns its root frame (CashIcon.Size).
function CashIcon.build(parent: Instance, palette: Tokens.Palette): Frame
	local root = make("Frame", {
		Name = "CashIcon",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(SIDE, SIDE),
		BackgroundTransparency = 1,
		Parent = parent,
	})
	-- The stack rotates about its own centre; it is offset (in the scale
	-- component, so sub-pixel values are kept) so the composition's visible
	-- centre lands on the holder's centre.
	local stack = make("Frame", {
		Name = "Stack",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5 - ART_CENTRE.X / SIDE, 0.5 - ART_CENTRE.Y / SIDE),
		Size = UDim2.fromOffset(STACK.X, STACK.Y),
		Rotation = ROTATION,
		BackgroundTransparency = 1,
		Parent = root,
	})
	make("UIScale", { Name = "StackScale", Scale = STACK_SCALE, Parent = stack })

	-- Faint shadow just under the bottom bill, so it does not pull the
	-- perceived centre down.
	local shadow = make("Frame", {
		Name = "Shadow",
		Position = UDim2.fromOffset(2 * FAN.X + SHADOW_OFFSET.X, 2 * FAN.Y + SHADOW_OFFSET.Y),
		Size = UDim2.fromOffset(BILL.X, BILL.Y),
		BackgroundColor3 = palette.CashShadow,
		BackgroundTransparency = 0.75,
		BorderSizePixel = 0,
		ZIndex = 1,
		Parent = stack,
	})
	make("UICorner", { CornerRadius = UDim.new(0, RADIUS), Parent = shadow })

	bill(stack, "BillBottom", 2, palette.BillDark, palette)
	bill(stack, "BillMiddle", 1, palette.BillFace:Lerp(palette.BillDark, 0.35), palette)
	local top = bill(stack, "BillTop", 0, palette.BillFace, palette)
	make("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.new(0.82, 0.86, 0.82)),
		Parent = top,
	})

	-- Lighter inset border on the top bill.
	local inset = make("Frame", {
		Name = "Inset",
		Position = UDim2.fromOffset(3, 3),
		Size = UDim2.new(1, -6, 1, -6),
		BackgroundTransparency = 1,
		ZIndex = 5,
		Parent = top,
	})
	make("UICorner", { CornerRadius = UDim.new(0, 2), Parent = inset })
	make("UIStroke", { Color = palette.BillLight, Thickness = 1.5, Parent = inset })

	-- Gold band across the middle of the top bill, in the bill's own
	-- coordinates (centred by anchor, not by a measured offset).
	local band = make("Frame", {
		Name = "Band",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(0, BAND_WIDTH, 1, 2 * BAND_OVERHANG),
		BackgroundColor3 = palette.BillBand,
		BorderSizePixel = 0,
		ZIndex = 7,
		Parent = top,
	})
	make("UICorner", { CornerRadius = UDim.new(0, 2), Parent = band })
	make("UIStroke", { Color = palette.CashOutline, Thickness = OUTLINE, Parent = band })
	make("UIGradient", {
		Color = ColorSequence.new(palette.BillBand, palette.BillBandShade),
		Parent = band,
	})

	-- Restrained shine near the upper-left of the top bill.
	local shine = make("Frame", {
		Name = "Shine",
		Position = UDim2.fromOffset(4, 4),
		Size = UDim2.fromOffset(7, 3),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.25,
		BorderSizePixel = 0,
		ZIndex = 8,
		Parent = top,
	})
	make("UICorner", { CornerRadius = Tokens.Radius.Pill, Parent = shine })

	return root
end

-- Geometry for the preview's alignment guides (preview only).
function CashIcon.debugGeometry(): { [string]: any }
	return {
		side = SIDE,
		artSize = ART_SIZE,
		artCentreFromStackCentre = ART_CENTRE,
		stackScale = STACK_SCALE,
		rotation = ROTATION,
		stack = STACK,
		bill = BILL,
	}
end

return CashIcon
