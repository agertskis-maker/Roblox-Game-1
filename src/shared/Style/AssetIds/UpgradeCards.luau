--!strict
-- AssetIds.UpgradeCards (Round 8): this workstream's art. Key -> Entry (see AssetIds/init.luau). Builders add keys with id = nil and drop
-- the PNG into Car-Hop-Art/upload-round8/<key>.png; only the lead fills in `id` after a group-owned upload (LEGION STUDI0S).
--
-- WS-6a (the Raceway card and the shared card kit, src/client/UI/Prototype/R8Kit): the keys below are text-free art made by WS-6a
-- (R8-S07b: ChatGPT's layers/ folder was empty), drawn as SVG/HTML and rendered to transparent PNGs. `size` is the PNG's pixel size and
-- `slice` the 9-slice centre in source pixels where a piece stretches. All words and numbers on the cards are live TextLabels.
-- WS-6b adds the PARKING keys (asphalt frame, bay art ...) in the marked section at the bottom, nothing above it.
local Types = require(script.Parent.Types)

local entries: { [string]: Types.Entry } = {
	-- The racetrack frame: red and white kerb blocks, chequered corners, thin dark outline, cream panel. 9-slice.
	r8_card_kerb_frame = {
		size = Vector2.new(1024, 546),
		slice = Rect.new(160, 160, 864, 386),
		source = "WS-6a SVG, matches R8-IMG-01 frame",
	},
	-- The chequered-flag title ribbon (no text). Not sliced: drawn at its own 6.8 : 1 aspect.
	r8_card_ribbon = { size = Vector2.new(1024, 150), source = "WS-6a SVG, matches R8-IMG-01 ribbon" },
	-- The trackside TV bezel: navy, four chrome bolts, a transparent picture hole with rounded corners. 9-slice.
	r8_card_bezel = {
		size = Vector2.new(512, 432),
		slice = Rect.new(72, 72, 440, 360),
		source = "WS-6a SVG, matches R8-IMG-01 preview bezel",
	},
	-- The cream pill (stat pill, chips) with its thin tan outline. 9-slice.
	r8_card_pill = {
		size = Vector2.new(256, 128),
		slice = Rect.new(48, 48, 208, 80),
		source = "WS-6a SVG, matches R8-IMG-01 stat pill",
	},
	-- The gold tag ("NEXT LEVEL", "MAX LEVEL"). 9-slice.
	r8_card_tag_gold = {
		size = Vector2.new(256, 96),
		slice = Rect.new(44, 40, 212, 56),
		source = "WS-6a SVG, matches R8-IMG-01 NEXT LEVEL tag",
	},
	-- The glossy buttons (text-free): orange (buy), grey (cannot afford), gold (max, ALL SPOTS OWNED), green (NEW SPOT!). 9-slice.
	r8_card_btn_orange = {
		size = Vector2.new(512, 128),
		slice = Rect.new(60, 60, 452, 68),
		source = "WS-6a SVG, matches R8-IMG-01 UPGRADE button",
	},
	r8_card_btn_grey = {
		size = Vector2.new(512, 128),
		slice = Rect.new(60, 60, 452, 68),
		source = "WS-6a SVG, matches R8-IMG-02 NEED button",
	},
	r8_card_btn_gold = {
		size = Vector2.new(512, 128),
		slice = Rect.new(60, 60, 452, 68),
		source = "WS-6a SVG, matches R8-IMG-05 ALL SPOTS OWNED button",
	},
	r8_card_btn_green = {
		size = Vector2.new(512, 128),
		slice = Rect.new(60, 60, 452, 68),
		source = "WS-6a SVG, matches R8-IMG-05 NEW SPOT! button",
	},
	-- The MAX LEVEL rosette (gold disc, ribbon tails, laurels; no text).
	r8_card_badge_max = { size = Vector2.new(512, 256), source = "WS-6a SVG, matches R8-IMG-02 MAX LEVEL badge" },
	-- Round buttons: red close with a white X, green plus.
	r8_card_close = { size = Vector2.new(192, 192), source = "WS-6a SVG, matches R8-IMG-01 close button" },
	r8_card_plus = { size = Vector2.new(160, 160), source = "WS-6a SVG, matches R8-IMG-02 green plus" },
	-- Icons: stopwatch, cash stack, chunky green arrow.
	r8_card_stopwatch = { size = Vector2.new(192, 192), source = "WS-6a SVG, matches R8-IMG-01 stopwatch" },
	r8_card_cash = { size = Vector2.new(256, 192), source = "WS-6a SVG, matches R8-IMG-01 cash stack" },
	r8_card_arrow = { size = Vector2.new(192, 128), source = "WS-6a SVG, matches R8-IMG-01 green arrow" },
	-- The level pips: little flags, gold and grey.
	r8_card_pip_gold = { size = Vector2.new(128, 128), source = "WS-6a SVG, matches R8-IMG-01 gold flag" },
	r8_card_pip_grey = { size = Vector2.new(128, 128), source = "WS-6a SVG, matches R8-IMG-01 grey flag" },
	-- The chip pictures: one sheet, 8 columns x 4 rows of 128 px cells (names in R8Kit/Chip.luau).
	r8_card_chipicons = {
		size = Vector2.new(1024, 512),
		source = "WS-6a SVG, small pictures for the NEW AT NEXT LEVEL chips",
	},

	-- ===== WS-6b: PARKING keys only below this line =====
}

return entries
