--!strict
-- Original cash-stack icon built from UI shapes (Lane 3). Style inspired by
-- the currency-counter reference (chunky, outlined, saturated, tilted, a
-- band around the middle); no artwork is traced or reused.
--
-- Three offset bills with dark outlines, a lighter inset border and a simple
-- circle emblem on the top bill, a gold band around the middle, a small
-- upper-left shine, and a soft shadow, tilted about 10 degrees. Built for
-- about 36 px high at scale 1.0; the inset border and emblem are the first
-- details to drop if it is ever shown below 32 px.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Tokens = require(ReplicatedStorage.Shared.UI.Tokens)

local CashIcon = {}

-- Holder size at scale 1.0. Measured in Studio on 2026-10-19: the stack
-- artwork scaled by STACK_SCALE is about 1.2 times the visible numeral
-- height of 40 px Fredoka One, and the holder width leaves about 8 px of
-- clear space between the artwork and the number.
CashIcon.Size = Vector2.new(59, 44)
local STACK_SCALE = 1.12

local BILL = Vector2.new(34, 18)
local OUTLINE = 2

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

local function bill(
	parent: Instance,
	name: string,
	x: number,
	y: number,
	color: Color3,
	palette: Tokens.Palette,
	z: number
): Frame
	local f = make("Frame", {
		Name = name,
		Position = UDim2.fromOffset(x, y),
		Size = UDim2.fromOffset(BILL.X, BILL.Y),
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		ZIndex = z,
		Parent = parent,
	})
	make("UICorner", { CornerRadius = UDim.new(0, 3), Parent = f })
	make("UIStroke", { Color = palette.CashOutline, Thickness = OUTLINE, Parent = f })
	return f
end

-- Builds the icon inside `parent` and returns its root frame (CashIcon.Size).
function CashIcon.build(parent: Instance, palette: Tokens.Palette): Frame
	local root = make("Frame", {
		Name = "CashIcon",
		Size = UDim2.fromOffset(CashIcon.Size.X, CashIcon.Size.Y),
		BackgroundTransparency = 1,
		Parent = parent,
	})
	local stack = make("Frame", {
		Name = "Stack",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(42, 30),
		Rotation = -10,
		BackgroundTransparency = 1,
		Parent = root,
	})
	make("UIScale", { Name = "StackScale", Scale = STACK_SCALE, Parent = stack })

	-- Soft shadow beneath the stack.
	local shadow = make("Frame", {
		Name = "Shadow",
		Position = UDim2.fromOffset(7, 14),
		Size = UDim2.fromOffset(BILL.X, BILL.Y),
		BackgroundColor3 = palette.CashShadow,
		BackgroundTransparency = 0.65,
		BorderSizePixel = 0,
		ZIndex = 1,
		Parent = stack,
	})
	make("UICorner", { CornerRadius = UDim.new(0, 4), Parent = shadow })

	bill(stack, "BillBottom", 6, 10, palette.BillDark, palette, 2)
	bill(stack, "BillMiddle", 3, 6, palette.BillFace:Lerp(palette.BillDark, 0.35), palette, 3)
	local top = bill(stack, "BillTop", 0, 2, palette.BillFace, palette, 4)
	make("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.new(0.82, 0.86, 0.82)),
		Parent = top,
	})

	-- Lighter inset border and a simple circle emblem on the top bill.
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
	local emblem = make("Frame", {
		Name = "Emblem",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(9, BILL.Y / 2),
		Size = UDim2.fromOffset(8, 8),
		BackgroundColor3 = palette.BillDark,
		BorderSizePixel = 0,
		ZIndex = 6,
		Parent = top,
	})
	make("UICorner", { CornerRadius = Tokens.Radius.Pill, Parent = emblem })
	make("UIStroke", { Color = palette.BillLight, Thickness = 1.5, Parent = emblem })

	-- Gold band around the middle of the whole stack.
	local band = make("Frame", {
		Name = "Band",
		Position = UDim2.fromOffset(19, 0),
		Size = UDim2.fromOffset(8, 30),
		BackgroundColor3 = palette.BillBand,
		BorderSizePixel = 0,
		ZIndex = 7,
		Parent = stack,
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
		Position = UDim2.fromOffset(3, 3),
		Size = UDim2.fromOffset(9, 3),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.25,
		BorderSizePixel = 0,
		ZIndex = 8,
		Parent = top,
	})
	make("UICorner", { CornerRadius = Tokens.Radius.Pill, Parent = shine })

	return root
end

return CashIcon
