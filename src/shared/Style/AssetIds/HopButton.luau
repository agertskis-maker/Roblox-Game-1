--!strict
-- AssetIds.HopButton (Round 8, WS-10, R-02 and R-03): the HOP / DIVE button and the dive-guidance art. Key -> Entry (see
-- AssetIds/init.luau). Builders add keys with id = nil and drop the PNG into Car-Hop-Art/upload-round8/<key>.png; only the lead
-- fills in `id` after a group-owned upload (LEGION STUDI0S). Every PNG is text-free: the words HOP, DIVE, SPACE and A are live
-- TextLabels. Every user keeps a code-drawn fallback for "" (HopButton.luau, HopGuide.luau).
--
--   discs      512 x 512, glossy round button faces with the navy outline (R8-IMG-28): HOP orange, DIVE yellow, the two pressed
--              looks (pushed in, darker), NO TARGET (the DIVE look dimmed to mustard), NO STAMINA (grey)
--   arrow      256 x 256, the chunky white UP arrow with a dark outline; DIVE turns it round (Rotation 180), so there is one file
--   bolt_empty 256 x 256, the small empty bolt on the NO STAMINA disc
--   glow       512 x 512, the soft yellow halo ring that pulses behind DIVE
--   shadow     256 x 256, the soft drop shadow under the disc
--   chevron    128 x 128, one small white chevron with a yellow edge, tip down (the dive path and the landing ring's markers)
local Types = require(script.Parent.Types)

local entries: { [string]: Types.Entry } = {
	r8_hop_disc_hop = {
		id = nil,
		size = Vector2.new(512, 512),
		source = "upload-round8/r8_hop_disc_hop.png (SVG, WS-10)",
	},
	r8_hop_disc_hop_pressed = {
		id = nil,
		size = Vector2.new(512, 512),
		source = "upload-round8/r8_hop_disc_hop_pressed.png (SVG, WS-10)",
	},
	r8_hop_disc_dive = {
		id = nil,
		size = Vector2.new(512, 512),
		source = "upload-round8/r8_hop_disc_dive.png (SVG, WS-10)",
	},
	r8_hop_disc_dive_pressed = {
		id = nil,
		size = Vector2.new(512, 512),
		source = "upload-round8/r8_hop_disc_dive_pressed.png (SVG, WS-10)",
	},
	r8_hop_disc_notarget = {
		id = nil,
		size = Vector2.new(512, 512),
		source = "upload-round8/r8_hop_disc_notarget.png (SVG, WS-10)",
	},
	r8_hop_disc_nostamina = {
		id = nil,
		size = Vector2.new(512, 512),
		source = "upload-round8/r8_hop_disc_nostamina.png (SVG, WS-10)",
	},
	r8_hop_arrow = { id = nil, size = Vector2.new(256, 256), source = "upload-round8/r8_hop_arrow.png (SVG, WS-10)" },
	r8_hop_bolt_empty = {
		id = nil,
		size = Vector2.new(256, 256),
		source = "upload-round8/r8_hop_bolt_empty.png (SVG, WS-10)",
	},
	r8_hop_glow = { id = nil, size = Vector2.new(512, 512), source = "upload-round8/r8_hop_glow.png (SVG, WS-10)" },
	r8_hop_shadow = { id = nil, size = Vector2.new(256, 256), source = "upload-round8/r8_hop_shadow.png (SVG, WS-10)" },
	r8_hop_chevron = {
		id = nil,
		size = Vector2.new(128, 128),
		source = "upload-round8/r8_hop_chevron.png (SVG, WS-10)",
	},
}

return entries
