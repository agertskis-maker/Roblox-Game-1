--!strict
-- ShopPalette: the Shop's vivid colours (Lane 3, BRIEF N6-01 and N6-02a, 2026-11-01). One place for every fill, so no card
-- is ever dull or greyish: hot pink, electric purple, cyan, lime, orange and gold gradients, white headlines with deep
-- navy outlines. PreviewTokens stays untouched; ShopKit.fill reads these first.
--
-- Roles (N6-02a): cyan and purple are the common Shop frame (Page, Well, the tab bar), gold is for value (Gold, the
-- BEST DEAL banner), lime is for action (Lime, every price button), pink and orange are the featured offer (Hero, Pink,
-- Orange). A single card never uses every accent. Prices and descriptive copy sit on the quiet Plate, never straight on
-- a glowing gradient.

local ShopPalette = {}

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

-- Evenly spaced stops, first to last.
local function seq(...: Color3): ColorSequence
	local colours = { ... }
	local points: { ColorSequenceKeypoint } = {}
	for i, colour in colours do
		table.insert(points, ColorSequenceKeypoint.new((i - 1) / (#colours - 1), colour))
	end
	return ColorSequence.new(points)
end

ShopPalette.Ink = rgb(14, 20, 38) -- the deep navy outline

ShopPalette.Color = table.freeze({
	Text = rgb(255, 255, 255),
	TextSoft = rgb(226, 232, 255), -- body copy on a plate
	Grey = rgb(196, 206, 244), -- subtitles on the page (a cool lavender, never a flat grey)
	Warn = rgb(255, 224, 84), -- the PREVIEW lines
	Error = rgb(255, 160, 150),
	Gold = rgb(255, 214, 40),
	Plate = rgb(26, 16, 84), -- the quiet surface under copy and prices (deep indigo)
	PlateEdge = rgb(110, 90, 255),
	Glow = rgb(255, 255, 255),
})

-- The quiet plate: how see-through it is, so the card's colour still shows round it.
ShopPalette.PlateTransparency = 0.22

ShopPalette.Fill = table.freeze({
	-- featured: violet to magenta to hot pink to orange
	Hero = seq(rgb(112, 70, 255), rgb(226, 60, 238), rgb(255, 58, 148), rgb(255, 148, 42)),
	Pink = seq(rgb(255, 126, 206), rgb(255, 50, 160), rgb(206, 24, 128)),
	Violet = seq(rgb(176, 112, 255), rgb(124, 60, 255), rgb(84, 34, 214)),
	Sky = seq(rgb(110, 240, 255), rgb(30, 190, 255), rgb(30, 108, 240)),
	Teal = seq(rgb(112, 255, 214), rgb(18, 218, 172), rgb(8, 148, 172)),
	Lime = seq(rgb(204, 255, 100), rgb(92, 232, 58), rgb(26, 176, 72)),
	Orange = seq(rgb(255, 214, 70), rgb(255, 140, 24), rgb(246, 66, 30)),
	Yellow = seq(rgb(255, 246, 118), rgb(255, 204, 30), rgb(255, 146, 0)),
	-- value: the BEST DEAL banner and the gold accents
	Gold = seq(rgb(255, 238, 110), rgb(255, 196, 24), rgb(255, 134, 0)),
	Red = seq(rgb(255, 112, 100), rgb(240, 36, 60), rgb(176, 14, 46)),
	-- a button the player cannot press yet: saturated indigo, clearly disabled by the dimmed words and the lock
	Locked = seq(rgb(132, 120, 236), rgb(86, 72, 200), rgb(54, 44, 148)),
	Disabled = seq(rgb(160, 156, 214), rgb(122, 118, 186), rgb(92, 88, 150)),
	Steel = seq(rgb(132, 168, 255), rgb(76, 116, 244), rgb(44, 72, 196)),
	Owned = seq(rgb(112, 244, 176), rgb(34, 204, 124), rgb(16, 142, 104)),
	Pending = seq(rgb(216, 255, 124), rgb(130, 220, 70), rgb(70, 166, 64)),
	-- the shop frame: cyan and purple
	Well = seq(rgb(54, 40, 148), rgb(36, 26, 112), rgb(22, 16, 80)),
	Page = seq(rgb(96, 44, 232), rgb(56, 96, 255), rgb(24, 196, 252)),
	-- a pop-up's own background (Coming soon, an offer, the group reward)
	Popup = seq(rgb(130, 70, 255), rgb(236, 62, 214), rgb(255, 120, 60)),
})

-- The base angle of each gradient (degrees). ShopMotion sways Rotation around it.
ShopPalette.Angle = table.freeze({
	Hero = 22,
	Page = 35,
	Gold = 16,
	Popup = 30,
	Card = 62, -- a diagonal sheen: a sway of Offset and Rotation is visible whichever way the engine applies Offset
})

return ShopPalette
