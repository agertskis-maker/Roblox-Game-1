--!strict
-- ShopArt: the large glossy art on the Shop's cards (Lane 3, BRIEF M10-03, 2026-11-01). Every piece is composed from
-- the code-drawn icon family (ShopKit.icon -> Icons2) on a soft halo with a ground shadow: no image, no asset id, no
-- copied art. A missing icon becomes the kit's solid "?" glyph (the "missing art" fixture forces it), never a hole.
--
--   ShopArt.build(parent, key, px, options) -> Art
--       parent   any GuiObject; the art is a px x px Frame placed by the caller through Art.root
--       key      the offer's `art` field in ShopPreviewCatalog ("starter-pack", "vip", "cash-chest", ...)
--       options  { z, missing (force the fallback glyph), tint (re-colour the car on Style cards) }
--
-- Art.setTint(colour?) re-colours the car on the Style cards (the small live preview on a car silhouette).

local Prototype = script.Parent.Parent.Parent
local Arcade = require(Prototype.Arcade)
local PreviewTokens = require(Prototype.PreviewTokens)
local ShopKit = require(Prototype.ShopKit)

local A = PreviewTokens.Arcade
local make = Arcade.make
local WHITE = Color3.new(1, 1, 1)

local ShopArt = {}

type Piece = { name: string, x: number, y: number, s: number, tilt: number?, tint: Color3?, tintable: boolean? }

local GOLD = Color3.fromRGB(255, 204, 48)
local GREY_GOLD = Color3.fromRGB(150, 158, 182)
local CAR_RED = Color3.fromRGB(238, 58, 78)
local CAR_CYAN = Color3.fromRGB(48, 206, 248)

-- Back pieces first, the hero piece last.
local COMPOSITIONS: { [string]: { Piece } } = {
	["starter-pack"] = {
		{ name = "PaintBucket", x = 0.18, y = 0.26, s = 0.34, tilt = -12 },
		{ name = "CashStack", x = 0.84, y = 0.24, s = 0.36, tilt = 8 },
		{ name = "Decal", x = 0.2, y = 0.76, s = 0.32, tilt = 10 },
		{ name = "Wheel", x = 0.82, y = 0.76, s = 0.34 },
		{ name = "StarterPack", x = 0.5, y = 0.54, s = 0.7, tilt = -6 },
	},
	["vip"] = {
		{ name = "Car", x = 0.5, y = 0.62, s = 0.68, tint = GOLD },
		{ name = "VipCrown", x = 0.5, y = 0.2, s = 0.4, tilt = -8 },
	},
	["double-lap-pay"] = {
		{ name = "CashStack", x = 0.72, y = 0.74, s = 0.46, tilt = 6 },
		{ name = "DoubleLapPay", x = 0.42, y = 0.5, s = 0.74, tilt = -6 },
	},
	["expanded-paddock"] = {
		{ name = "Car", x = 0.74, y = 0.78, s = 0.44, tint = CAR_CYAN },
		{ name = "Paddock", x = 0.44, y = 0.48, s = 0.74 },
	},
	["all-passes-bundle"] = {
		{ name = "DoubleLapPay", x = 0.2, y = 0.42, s = 0.4, tilt = -10 },
		{ name = "Paddock", x = 0.8, y = 0.42, s = 0.4, tilt = 10 },
		{ name = "VipCrown", x = 0.5, y = 0.2, s = 0.36 },
		{ name = "Bundle", x = 0.5, y = 0.68, s = 0.62 },
	},
	["style-paint"] = {
		{ name = "PaintBucket", x = 0.78, y = 0.3, s = 0.4, tilt = 8 },
		{ name = "Car", x = 0.46, y = 0.64, s = 0.8, tint = CAR_RED, tintable = true },
	},
	["style-decal"] = {
		{ name = "Car", x = 0.5, y = 0.64, s = 0.8, tint = WHITE },
		{ name = "Decal", x = 0.24, y = 0.28, s = 0.38, tilt = -8, tintable = true },
	},
	["style-wheel"] = {
		{ name = "Car", x = 0.74, y = 0.8, s = 0.42, tint = CAR_RED },
		{ name = "Wheel", x = 0.44, y = 0.5, s = 0.76, tintable = true },
	},
	["style-gold"] = {
		{ name = "Trophy", x = 0.46, y = 0.5, s = 0.7, tint = GREY_GOLD },
		{ name = "Lock", x = 0.76, y = 0.74, s = 0.36 },
	},
	["free-legion"] = {
		{ name = "Group", x = 0.76, y = 0.3, s = 0.4 },
		{ name = "Gift", x = 0.4, y = 0.56, s = 0.64 },
	},
	-- Cash packs grow in capacity with distinct silhouettes (M10-07a): a small stack, a sack, a chest, a vault.
	["cash-pocket"] = { { name = "CashStack", x = 0.5, y = 0.56, s = 0.6 } },
	["cash-bag"] = { { name = "CashBag", x = 0.5, y = 0.54, s = 0.7 } },
	["cash-chest"] = { { name = "CashChest", x = 0.5, y = 0.54, s = 0.8 } },
	["cash-vault"] = { { name = "CashVault", x = 0.5, y = 0.52, s = 0.9 } },
}

export type ArtOptions = {
	z: number?,
	missing: boolean?,
	tint: Color3?,
}
export type Art = {
	root: Frame,
	setTint: (Color3?) -> (),
	pieces: number,
}

function ShopArt.build(parent: Instance, key: string, px: number, options: ArtOptions?): Art
	local o: ArtOptions = options or {}
	local z = o.z or 8
	local root: Frame = make("Frame", {
		Name = "Art_" .. key,
		Size = UDim2.fromOffset(px, px),
		BackgroundTransparency = 1,
		ZIndex = z,
		Parent = parent,
	})
	-- soft halo and ground shadow: two translucent circles and a flat ellipse
	local halo: Frame = make("Frame", {
		Name = "Halo",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.52),
		Size = UDim2.fromOffset(px * 0.96, px * 0.96),
		BackgroundColor3 = WHITE,
		BackgroundTransparency = 0.86,
		BorderSizePixel = 0,
		ZIndex = z,
		Parent = root,
	})
	Arcade.corner(halo, px)
	local core: Frame = make("Frame", {
		Name = "HaloCore",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.52),
		Size = UDim2.fromOffset(px * 0.7, px * 0.7),
		BackgroundColor3 = WHITE,
		BackgroundTransparency = 0.8,
		BorderSizePixel = 0,
		ZIndex = z,
		Parent = root,
	})
	Arcade.corner(core, px)
	local shadow: Frame = make("Frame", {
		Name = "Shadow",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.93),
		Size = UDim2.fromOffset(px * 0.62, px * 0.09),
		BackgroundColor3 = A.Ink,
		BackgroundTransparency = 0.7,
		BorderSizePixel = 0,
		ZIndex = z,
		Parent = root,
	})
	Arcade.corner(shadow, px)

	local pieces = COMPOSITIONS[key] or {}
	local carHolder: Frame? = nil
	local carPiece: Piece? = nil
	local function place(piece: Piece, tint: Color3?): Frame
		local side = math.max(math.floor(px * piece.s), 16)
		local holder: Frame = make("Frame", {
			Name = "Piece_" .. piece.name,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(piece.x, piece.y),
			Size = UDim2.fromOffset(side, side),
			BackgroundTransparency = 1,
			ZIndex = z + 1,
			Parent = root,
		})
		local name = if o.missing then "__missing__" else piece.name
		ShopKit.icon(holder, name, { tint = tint or piece.tint, tilt = piece.tilt })
		return holder
	end
	for _, piece in pieces do
		local holder = place(piece, nil)
		if piece.tintable then
			carHolder, carPiece = holder, piece
		end
	end
	-- the VIP podium sits under the car (three flat steps; the crown floats above)
	if key == "vip" then
		local slab: Frame = make("Frame", {
			Name = "Podium",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.88),
			Size = UDim2.fromOffset(px * 0.72, px * 0.13),
			BackgroundColor3 = WHITE,
			BorderSizePixel = 0,
			ZIndex = z,
			Parent = root,
		})
		Arcade.corner(slab, 8)
		Arcade.outline(slab, "Button")
		make("UIGradient", { Color = ShopKit.fill("Violet"), Rotation = 90, Parent = slab })
	end

	local art: Art
	art = {
		root = root,
		pieces = #pieces,
		setTint = function(colour: Color3?)
			local holder, piece = carHolder, carPiece
			if not holder or not piece then
				return
			end
			for _, child in holder:GetChildren() do
				child:Destroy()
			end
			local name = if o.missing then "__missing__" else piece.name
			ShopKit.icon(holder, name, { tint = colour or piece.tint, tilt = piece.tilt })
		end,
	}
	if o.tint then
		art.setTint(o.tint)
	end
	return art
end

return ShopArt
