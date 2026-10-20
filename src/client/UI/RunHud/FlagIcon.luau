--!strict
-- Original finish-flag icon for Distance (Lane 3), drawn in the Cash icon's
-- visual language: chunky silhouette, strong dark outline, restrained
-- upper-left shine, slight tilt and a faint shadow. Four large checks only;
-- no fine checkerboard, so it stays readable at phone size.
--
-- Centred in its square holder by its visible artwork (IconGeometry), the
-- same convention as the Cash icon.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local IconGeometry = require(script.Parent.Parent.IconGeometry)
local Tokens = require(ReplicatedStorage.Shared.UI.Tokens)

local FlagIcon = {}

local OUTLINE = 2
local ROTATION = -8
-- Scale chosen so the visible artwork is about 1.25 times the visible digit
-- height of the Distance number (32 px Fredoka One with its outline).
local SCALE = 0.795
local SHADOW_OFFSET = Vector2.new(1, 2)

-- Frame-coordinate layout (design px before SCALE).
local FRAME = Vector2.new(32, 42)
local KNOB = { x = 0, y = 0, d = 9 }
local POLE = { x = 2, y = 6, w = 5, h = 36 }
local CLOTH = { x = 7, y = 6, w = 25, h = 18 }

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

local function shapes(): { IconGeometry.Shape }
	return {
		{ x = KNOB.x - OUTLINE, y = KNOB.y - OUTLINE, w = KNOB.d + 2 * OUTLINE, h = KNOB.d + 2 * OUTLINE, r = 99 },
		{
			x = POLE.x - OUTLINE,
			y = POLE.y - OUTLINE,
			w = POLE.w + 2 * OUTLINE,
			h = POLE.h + 2 * OUTLINE,
			r = 2 + OUTLINE,
		},
		{
			x = CLOTH.x - OUTLINE,
			y = CLOTH.y - OUTLINE,
			w = CLOTH.w + 2 * OUTLINE,
			h = CLOTH.h + 2 * OUTLINE,
			r = 3 + OUTLINE,
		},
		{ x = CLOTH.x + SHADOW_OFFSET.X, y = CLOTH.y + SHADOW_OFFSET.Y, w = CLOTH.w, h = CLOTH.h, r = 3 },
	}
end

local ART_SIZE, ART_CENTRE = IconGeometry.bounds(shapes(), FRAME, ROTATION, SCALE)
local SIDE = math.ceil(math.max(ART_SIZE.X, ART_SIZE.Y)) + 2

FlagIcon.Size = Vector2.new(SIDE, SIDE)
FlagIcon.ArtSize = ART_SIZE

local function rect(parent: Instance, name: string, spec: any, color: Color3, radius: number, z: number): Frame
	local f = make("Frame", {
		Name = name,
		Position = UDim2.fromOffset(spec.x, spec.y),
		Size = UDim2.fromOffset(spec.w, spec.h),
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		ZIndex = z,
		Parent = parent,
	})
	make("UICorner", { CornerRadius = UDim.new(0, radius), Parent = f })
	return f
end

function FlagIcon.build(parent: Instance, palette: Tokens.Palette): Frame
	local root = make("Frame", {
		Name = "FlagIcon",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(SIDE, SIDE),
		BackgroundTransparency = 1,
		Parent = parent,
	})
	local art = make("Frame", {
		Name = "Art",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5 - ART_CENTRE.X / SIDE, 0.5 - ART_CENTRE.Y / SIDE),
		Size = UDim2.fromOffset(FRAME.X, FRAME.Y),
		Rotation = ROTATION,
		BackgroundTransparency = 1,
		Parent = root,
	})
	make("UIScale", { Scale = SCALE, Parent = art })

	local shadow = rect(
		art,
		"Shadow",
		{ x = CLOTH.x + SHADOW_OFFSET.X, y = CLOTH.y + SHADOW_OFFSET.Y, w = CLOTH.w, h = CLOTH.h },
		palette.CashShadow,
		3,
		1
	)
	shadow.BackgroundTransparency = 0.75

	local pole = rect(art, "Pole", POLE, palette.Chrome, 2, 2)
	make("UIStroke", { Color = palette.CashOutline, Thickness = OUTLINE, Parent = pole })

	local cloth = rect(art, "Cloth", CLOTH, palette.FloatText, 3, 3)
	make("UIStroke", { Color = palette.CashOutline, Thickness = OUTLINE, Parent = cloth })
	-- Two large dark checks (upper-left and lower-right), rounded like the
	-- cloth so they never poke past its corners.
	for i, spot in { Vector2.new(0, 0), Vector2.new(0.5, 0.5) } do
		local check = make("Frame", {
			Name = "Check" .. i,
			Position = UDim2.fromScale(spot.X, spot.Y),
			Size = UDim2.fromScale(0.5, 0.5),
			BackgroundColor3 = palette.CashOutline,
			BorderSizePixel = 0,
			ZIndex = 4,
			Parent = cloth,
		})
		make("UICorner", { CornerRadius = UDim.new(0, 3), Parent = check })
	end
	-- Restrained shine on the upper-left (dark) check.
	local shine = make("Frame", {
		Name = "Shine",
		Position = UDim2.fromOffset(3, 3),
		Size = UDim2.fromOffset(6, 3),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.35,
		BorderSizePixel = 0,
		ZIndex = 5,
		Parent = cloth,
	})
	make("UICorner", { CornerRadius = Tokens.Radius.Pill, Parent = shine })

	-- Gold knob on top of the pole.
	local knob = rect(art, "Knob", { x = KNOB.x, y = KNOB.y, w = KNOB.d, h = KNOB.d }, palette.BillBand, 99, 3)
	make("UIStroke", { Color = palette.CashOutline, Thickness = OUTLINE, Parent = knob })
	return root
end

return FlagIcon
