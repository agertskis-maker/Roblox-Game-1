--!strict
-- R8Kit.KerbFrame (Lane 3 Round 8, U-01/U-02): the glossy racetrack frame of the Raceway card (red and white kerb blocks with a
-- bevel, chequered corners, a thin dark outline) and, with kind = "asphalt", the Parking card's asphalt frame with painted bay
-- lines. One 9-slice ImageLabel (AssetIds.UpgradeCards "r8_card_kerb_frame" / "r8_card_asphalt_frame", the cream panel with its
-- subtle grain is part of the art) or, until the art is uploaded, the same look drawn with Frames.
--
--   local f = KerbFrame.new(parent: GuiObject, props: Props) -> KerbFrame
--     Props: { kind: "kerb" | "asphalt"?, size: UDim2?, position: UDim2?, anchor: Vector2?, zIndex: number?,
--              thickness: number? (design px of the kerb ring, 30), radius: number? (outer corner radius, 55),
--              artKey: string? (override the art key), metrics: Metrics? }
--   f.frame: Frame     the whole card rectangle (design px when the card root carries the UIScale). Children are positioned
--                      in it directly, card-relative, so measurements from the reference image apply as they are.
--   f.inner: Frame     the same rectangle inset by the ring thickness (the cream panel area; measuring only)
--   f.content: Frame   a transparent full-card layer drawn ABOVE the frame art: parent the card's pieces here (ZIndex 3 among
--                      the frame's own layers; give the pieces their own ZIndex among themselves)
--   f.usesArt: boolean true when the uploaded art is shown, false for the code-drawn fallback
--   f:destroy()
-- Nothing in the frame takes input.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Trove = require(ReplicatedStorage.Packages.Trove)

local Art = require(script.Parent.Art)
local Build = require(script.Parent.Build)
local Palette = require(script.Parent.Palette)

local KerbFrame = {}

export type Props = {
	kind: ("kerb" | "asphalt")?,
	size: UDim2?,
	position: UDim2?,
	anchor: Vector2?,
	zIndex: number?,
	thickness: number?,
	radius: number?,
	artKey: string?,
	metrics: any?,
}

export type KerbFrame = {
	frame: Frame,
	inner: Frame,
	content: Frame,
	usesArt: boolean,
	destroy: (self: KerbFrame) -> (),
}

local ART_KEYS = { kerb = "r8_card_kerb_frame", asphalt = "r8_card_asphalt_frame" }

local Obj = {}
Obj.__index = Obj

-- The code-drawn ring: a rounded ring in the kerb colour with blocks of the other colour, chequered corner patches.
local function drawFallback(root: Frame, kind: string, thickness: number, radius: number, w: number, h: number)
	local isKerb = kind == "kerb"
	local ring = if isKerb then Palette.Red else Palette.Asphalt
	local block = if isKerb then Palette.White else Palette.White
	local base = Build.make("Frame", {
		Name = "Ring",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = ring,
		BorderSizePixel = 0,
		Parent = root,
	})
	Build.corner(base, UDim.new(0, radius))
	Build.stroke(base, 4, Palette.Navy)
	local panel = Build.make("Frame", {
		Name = "Panel",
		Position = UDim2.fromOffset(thickness, thickness),
		Size = UDim2.new(1, -2 * thickness, 1, -2 * thickness),
		BackgroundColor3 = Palette.Cream,
		BorderSizePixel = 0,
		Parent = root,
	})
	Build.corner(panel, UDim.new(0, math.max(radius - thickness, 8)))
	Build.stroke(panel, 3, Palette.CreamShade)
	-- blocks along the straight parts of the ring
	local inset = radius + 6
	local blockLen = 100
	local function run(x: number, y: number, length: number, horizontal: boolean)
		local n = math.max(math.floor(length / blockLen), 1)
		local step = length / n
		for i = 0, n - 1 do
			if i % 2 == 1 then
				local piece = Build.make("Frame", {
					Name = "Block",
					BackgroundColor3 = block,
					BorderSizePixel = 0,
					Position = if horizontal
						then UDim2.fromOffset(x + i * step, y)
						else UDim2.fromOffset(x, y + i * step),
					Size = if horizontal then UDim2.fromOffset(step, thickness) else UDim2.fromOffset(thickness, step),
					Parent = root,
				})
				if isKerb then
					Build.make("UIGradient", {
						Rotation = if horizontal then 90 else 0,
						Color = ColorSequence.new({
							ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
							ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 248, 238)),
							ColorSequenceKeypoint.new(1, Color3.fromRGB(214, 206, 200)),
						}),
						Parent = piece,
					})
				end
			end
		end
	end
	if isKerb then
		run(inset, 0, w - 2 * inset, true)
		run(inset, h - thickness, w - 2 * inset, true)
		run(0, inset, h - 2 * inset, false)
		run(w - thickness, inset, h - 2 * inset, false)
	else
		-- bay lines: short white dashes across the asphalt
		local dashes = math.max(math.floor((w - 2 * inset) / 70), 2)
		for i = 0, dashes - 1 do
			local x = inset + (i + 0.5) * (w - 2 * inset) / dashes
			for _, y in { thickness * 0.2, h - thickness * 0.8 } do
				Build.make("Frame", {
					Name = "BayLine",
					BackgroundColor3 = block,
					BorderSizePixel = 0,
					Position = UDim2.fromOffset(x - 4, y),
					Size = UDim2.fromOffset(8, thickness * 0.6),
					Parent = root,
				})
			end
		end
	end
	-- chequered corner patches (a 2 x 2 chequer turned 45 degrees at each corner)
	local cell = thickness * 0.62
	for _, c in { { 0.3, 0.3 }, { 0.7, 0.3 }, { 0.3, 0.7 }, { 0.7, 0.7 } } do
		local cx = if c[1] < 0.5 then radius * 0.42 else w - radius * 0.42
		local cy = if c[2] < 0.5 then radius * 0.42 else h - radius * 0.42
		local patch = Build.make("Frame", {
			Name = "Chequer",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(cx, cy),
			Size = UDim2.fromOffset(cell * 2, cell * 2),
			Rotation = 45,
			BackgroundTransparency = 1,
			Parent = root,
		})
		for i = 0, 3 do
			Build.make("Frame", {
				Name = "Cell",
				Position = UDim2.fromOffset((i % 2) * cell, (i // 2) * cell),
				Size = UDim2.fromOffset(cell, cell),
				BackgroundColor3 = if (i % 2 + i // 2) % 2 == 0 then Palette.NavyDeep else Palette.White,
				BorderSizePixel = 0,
				Parent = patch,
			})
		end
	end
end

function KerbFrame.new(parent: GuiObject, props: Props): KerbFrame
	local trove = Trove.new()
	local kind = props.kind or "kerb"
	local thickness = props.thickness or 30
	local radius = props.radius or 55
	local frame: Frame = trove:Add(Build.make("Frame", {
		Name = if kind == "kerb" then "KerbFrame" else "AsphaltFrame",
		Size = props.size or UDim2.fromOffset(988, 527),
		Position = props.position or UDim2.new(),
		AnchorPoint = props.anchor or Vector2.zero,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = props.zIndex or 1,
		Parent = nil,
	}))
	local art: ImageLabel = Build.make("ImageLabel", {
		Name = "Art",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 1,
		Parent = frame,
	})
	local key = props.artKey or ART_KEYS[kind] or ART_KEYS.kerb
	local usesArt = Art.apply(art, key)
	if usesArt then
		Art.fitSlice(trove, art, key, "x")
	else
		local fb: Frame = Build.make("Frame", {
			Name = "Fallback",
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ZIndex = 1,
			Parent = frame,
		})
		local size = props.size or UDim2.fromOffset(988, 527)
		drawFallback(fb, kind, thickness, radius, size.X.Offset, size.Y.Offset)
	end
	local inner: Frame = Build.make("Frame", {
		Name = "Inner",
		Position = UDim2.fromOffset(thickness, thickness),
		Size = UDim2.new(1, -2 * thickness, 1, -2 * thickness),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 2,
		Parent = frame,
	})
	local content: Frame = Build.make("Frame", {
		Name = "Content",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 3,
		Parent = frame,
	})
	frame.Parent = parent
	local self =
		setmetatable({ frame = frame, inner = inner, content = content, usesArt = usesArt, trove = trove }, Obj)
	return (self :: any) :: KerbFrame
end

function Obj.destroy(self: any)
	self.trove:Destroy()
end

return KerbFrame
