--!strict
-- AssetIds.Wheels (Round 8): this workstream's art. Key -> Entry (see AssetIds/init.luau). Builders add keys with id = nil and drop
-- the PNG into Car-Hop-Art/upload-round8/<key>.png; only the lead fills in `id` after a group-owned upload (LEGION STUDI0S).
--
-- WS-4 (W-01, W-04): the wheel meshes and the wheel icons. Everything was modelled and rendered from one script
-- (Car-Hop-Art/blender-round8/build_all.py, Blender 5.2, run headless: the Blender MCP could not connect), FBX in
-- Car-Hop-Art/upload-round8/<key>.fbx. One shared tyre, one rim mesh per design, and a glow (or stars) mesh for the designs that
-- glow or move (Neon material, slow pulse; the Galaxy stars drift). Mesh keys are r8_wheel_tyre, r8_wheel_rim_<design>,
-- r8_wheel_glow_<design> and r8_wheel_stars_galaxy_disc. Icon keys are r8_wheel_icon_<catalogId> (the Wheels item id in
-- CosmeticPreviewCatalog), 512x512 transparent PNGs at the R8-IMG-17 three-quarter angle.
local Types = require(script.Parent.Types)

local TYRE = "Blender script wl_designs.py build_tyre (original; shared by every design)"
local RIM = "Blender script wl_designs.py (original design after R8-IMG-17)"

local function mesh(source: string): Types.Entry
	return { kind = "Mesh", source = source }
end

local function icon(source: string): Types.Entry
	return { kind = "Image", size = Vector2.new(512, 512), source = source }
end

local ICON = "Blender render of the matching rim and tyre at the R8-IMG-17 angle (render_lib.py)"

local entries: { [string]: Types.Entry } = {
	r8_wheel_tyre = mesh(TYRE),

	r8_wheel_rim_multi_spoke = mesh(RIM),
	r8_wheel_rim_deep_dish = mesh(RIM),
	r8_wheel_rim_turbine = mesh(RIM),
	r8_wheel_rim_mesh = mesh(RIM),
	r8_wheel_rim_split_five = mesh(RIM),
	r8_wheel_rim_star_spoke = mesh(RIM),
	r8_wheel_rim_gold_crown = mesh(RIM),
	r8_wheel_rim_chrome_mirror = mesh(RIM),
	r8_wheel_rim_carbon = mesh(RIM),
	r8_wheel_rim_white_wall = mesh(RIM),
	r8_wheel_rim_stripe_tyre = mesh(RIM),
	r8_wheel_rim_neon_ring = mesh(RIM),
	r8_wheel_rim_glowing_hub = mesh(RIM),
	r8_wheel_rim_glowing_tread = mesh(RIM),
	r8_wheel_rim_flame_spoke = mesh(RIM),
	r8_wheel_rim_galaxy_disc = mesh(RIM),

	-- the Neon layers (slow pulse) and the drifting Galaxy stars
	r8_wheel_glow_neon_ring = mesh(RIM),
	r8_wheel_glow_glowing_hub = mesh(RIM),
	r8_wheel_glow_glowing_tread = mesh(TYRE .. ": a glow layer in the tyre's own frame"),
	r8_wheel_glow_flame_spoke = mesh(RIM),
	r8_wheel_stars_galaxy_disc = mesh(RIM),

	-- icons: one per Wheels catalog id
	r8_wheel_icon_stock_five = icon(ICON),
	r8_wheel_icon_split_five = icon(ICON),
	r8_wheel_icon_star_spoke = icon(ICON),
	r8_wheel_icon_white_wall = icon(ICON),
	r8_wheel_icon_multi_spoke = icon(ICON),
	r8_wheel_icon_mesh_lace = icon(ICON),
	r8_wheel_icon_stripe_racer = icon(ICON),
	r8_wheel_icon_deep_dish = icon(ICON),
	r8_wheel_icon_turbine = icon(ICON),
	r8_wheel_icon_carbon = icon(ICON),
	r8_wheel_icon_chrome_disc = icon(ICON),
	r8_wheel_icon_gold_star = icon(ICON),
	r8_wheel_icon_neon_ring = icon(ICON),
	r8_wheel_icon_glow_hub = icon(ICON),
	r8_wheel_icon_glowing_tread = icon(ICON),
	r8_wheel_icon_flame_spoke = icon(ICON),
	r8_wheel_icon_galaxy_disc = icon(ICON),
}

return entries
