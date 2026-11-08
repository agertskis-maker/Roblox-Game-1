--!strict
-- AssetIds.Trails (Round 8, WS-5a): this workstream's art. Key -> Entry (see AssetIds/init.luau). Builders add keys with id = nil and drop
-- the PNG into Car-Hop-Art/upload-round8/<key>.png; only the lead fills in `id` after a group-owned upload (LEGION STUDI0S).
--
-- T-12: the flipbook sheets and beam textures come from ParticleFX Studio's FREE downloads (https://particlefx.studio/roblox, each
-- effect page's ROBLOX button; licence line, checked 2026-11-08: "ParticleFX Studio free download, commercial use allowed, no credit
-- required"). The originals and each page link are in Car-Hop-Art/assets/particlefx/<effect>/sources.md (outside Git). The paid
-- plan is not used. Sheets are 8x8 (frames = 64) unless noted; the PNGs here are scaled to 512 px (1024 px where thin lines show).
-- "own:" sheets fill the gaps the free library does not cover (drawn with HTML canvas, Round 8 WS-5a, original, rights-clean).
local Types = require(script.Parent.Types)

local PAGE = "https://particlefx.studio/effects/"

local function sheet(slug: string, frames: number?, px: number): Types.Entry
	return { id = nil, kind = "Image", size = Vector2.new(px, px), frames = frames, source = PAGE .. slug }
end

local function own(px: Vector2, frames: number?, what: string): Types.Entry
	return { id = nil, kind = "Image", size = px, frames = frames, source = "own: " .. what }
end

local function sound(what: string): Types.Entry
	return { id = nil, kind = "Audio", source = "own: " .. what }
end

local function icon(): Types.Entry
	return {
		id = nil,
		kind = "Image",
		size = Vector2.new(512, 512),
		source = "own: captured in Studio from the finished trail (R8-IMG-20/21 style)",
	}
end

local entries: { [string]: Types.Entry } = {
	-- particle flipbooks from ParticleFX Studio (8x8, 64 frames, FlipbookMode OneShot unless the recipe says Loop)
	r8_trail_fx_smoke_puff = sheet("smoke-poof", 64, 512), -- cartoon puff: Drift Smoke, Flame smoke, Bubble pop dust
	r8_trail_fx_mist = sheet("cold-breath", 64, 512), -- soft grey mist: Frost Bite, Galaxy haze
	r8_trail_fx_backfire = sheet("exhaust-backfire", 64, 512), -- exhaust pop with an orange flash
	r8_trail_fx_stars = sheet("twinkling-stars", 64, 512), -- glitter of white four-point stars (tinted per trail)
	r8_trail_fx_flare = sheet("crackling-spark", 64, 512), -- white glint with soft halo (tinted per trail)
	r8_trail_fx_coin = sheet("spinning-gold-coin", 64, 512), -- a spinning gold coin (Loop)
	r8_trail_fx_ice = sheet("ice-shard-burst", 64, 512), -- ice shards bursting
	r8_trail_fx_snow = sheet("snowflake-swirl", 64, 512), -- a snowflake forming and fading
	r8_trail_fx_slime = sheet("slime-splat", 64, 512), -- a green drop falling and splatting
	r8_trail_fx_galaxy = sheet("spiral-galaxy", 64, 1024), -- a spiral nebula
	r8_trail_fx_bolt = sheet("electrified", 64, 1024), -- a blue crackling bolt
	r8_trail_fx_chain = sheet("chain-lightning", 64, 512), -- orbs joined by arcs
	r8_trail_fx_crown = sheet("vip-crown-sparkle", 64, 512), -- a little gold crown with a burst
	-- seamless beam textures from ParticleFX Studio (one still, runs bottom to top, repeats end to end)
	r8_trail_fx_beam_fire = sheet("fire-stream-beam", nil, 512),
	r8_trail_fx_beam_lightning = sheet("lightning-beam", nil, 512),
	r8_trail_fx_beam_arc = sheet("electric-arc-beam", nil, 512),
	r8_trail_fx_beam_energy = sheet("energy-beam", nil, 512),
	r8_trail_fx_beam_strands = sheet("energy-strands-beam", nil, 512),
	-- gap fillers drawn for this game
	r8_trail_fx_flutter = own(
		Vector2.new(512, 512),
		16,
		"a white paper strip flipping, 4x4 (confetti, streamers; tinted)"
	),
	r8_trail_fx_bill = own(Vector2.new(512, 512), 16, "an unmarked green paper bill flipping, 4x4 (Money Rain)"),
	r8_trail_fx_petal = own(Vector2.new(512, 512), 16, "a pink petal turning in the air, 4x4 (Petal Storm)"),
	r8_trail_fx_bubble = own(Vector2.new(256, 256), nil, "one iridescent soap bubble (Bubble Pop)"),
	r8_trail_fx_grid = own(Vector2.new(512, 512), nil, "white glowing grid lines (Retro Grid ribbon, tinted)"),
	r8_trail_fx_aurora = own(Vector2.new(256, 512), nil, "vertical aurora streaks fading upward (Aurora Veil, tinted)"),
	r8_trail_fx_glow = own(Vector2.new(256, 256), nil, "a soft round glow (road glow, halos, tinted)"),
	-- soft loops for Epic and up (generated with ffmpeg, 6 s, original)
	r8_trail_snd_whoosh = sound("airy whoosh loop from filtered pink noise (Epic)"),
	r8_trail_snd_crackle = sound("electric crackle loop (Lightning)"),
	r8_trail_snd_shimmer = sound("soft shimmer loop (Legendary, Robux, VIP)"),
}

-- one icon per trail, key r8_trail_icon_<catalogId> (T-09 tiles show them; R8-S07)
for _, id in
	{
		"neon_ribbon",
		"bubble_pop",
		"pixel_blast",
		"drift_smoke",
		"petal_storm",
		"frost_bite",
		"toxic_slime",
		"retro_grid",
		"aurora_veil",
		"lightning",
		"money_rain",
		"galaxy",
		"golden_glory",
		"flame_rush",
		"confetti_party",
		"rainbow_runway",
		"comet_tail",
		"vip_gradient",
	}
do
	entries["r8_trail_icon_" .. id] = icon()
end

return entries
