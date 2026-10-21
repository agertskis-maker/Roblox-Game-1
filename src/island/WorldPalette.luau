--!strict
-- Island environment colours (Lane 3). Separate from the HUD tokens in Shared.UI.Tokens,
-- which are unchanged. Starting swatches from Adam's brief, to be tuned under Studio
-- lighting in the Stage B sample. Helper colours are Stage A greybox only.

local rgb = Color3.fromRGB

return {
	DeepWater = rgb(22, 142, 188),
	ShallowWater = rgb(81, 215, 209),
	Sand = rgb(243, 215, 166),
	Paving = rgb(244, 230, 203),
	Grass = rgb(121, 200, 109),
	Foliage = rgb(59, 149, 110),
	Rock = rgb(130, 150, 162),
	RockHighlight = rgb(188, 199, 201),
	Navy = rgb(32, 52, 77),
	Coral = rgb(244, 127, 112),
	Mint = rgb(128, 216, 189),
	Yellow = rgb(247, 206, 88),
	Cream = rgb(255, 244, 220),

	-- Hub greybox placeholders (revision 3). Portal colours are one swatch per World,
	-- proposed for the environment task, not approved.
	PortalDowntown = rgb(186, 92, 255),
	PortalDustyHighway = rgb(255, 150, 60),
	PortalSummitPass = rgb(110, 210, 255),
	Snow = rgb(244, 248, 252),
	Bark = rgb(122, 86, 60),
	Chain = rgb(120, 124, 132),
	Checker = rgb(28, 28, 32),
	HelperBase = rgb(128, 216, 189),

	-- Stage A helpers (hidden or removed after review)
	HelperCentre = rgb(247, 206, 88),
	HelperClearance = rgb(255, 138, 31),
	HelperReserve = rgb(178, 73, 62),
	HelperDivider = rgb(255, 244, 220),
	Promenade = rgb(233, 215, 180),
	Court = rgb(249, 223, 160),
	Turntable = rgb(188, 199, 201),
	BayReserved = rgb(220, 226, 230),
}
