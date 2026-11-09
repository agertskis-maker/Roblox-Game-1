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

-- id = the MeshPart.MeshId read from the uploaded Model (the lead uploaded each FBX as a group-owned Model; Open Cloud cannot upload
-- an FBX as a Mesh). WheelKit builds its MeshParts with AssetService:CreateMeshPartAsync from this mesh id. The Model asset id is
-- kept in `source` for vault/design/assets.md. The importer scaled every mesh 100x (1 authoring unit = 100 studs): WheelKit
-- stretches each MeshPart to a stored bounding box, so that does not matter.
local function mesh(source: string, id: number, modelId: number): Types.Entry
	return { kind = "Mesh", id = id, source = source .. " [Model " .. tostring(modelId) .. "]" }
end

local function icon(source: string): Types.Entry
	return { kind = "Image", size = Vector2.new(512, 512), source = source }
end

local ICON = "Blender render of the matching rim and tyre at the R8-IMG-17 angle (render_lib.py)"

local entries: { [string]: Types.Entry } = {
	r8_wheel_tyre = mesh(TYRE, 125179403241224, 124857025094084),

	r8_wheel_rim_multi_spoke = mesh(RIM, 102735017060484, 125504426562937),
	r8_wheel_rim_deep_dish = mesh(RIM, 80243484843738, 88717095234294),
	r8_wheel_rim_turbine = mesh(RIM, 139293538472163, 122960180503681),
	r8_wheel_rim_mesh = mesh(RIM, 108147398216858, 75517488781557),
	r8_wheel_rim_split_five = mesh(RIM, 89923646801240, 92149868851132),
	r8_wheel_rim_star_spoke = mesh(RIM, 130060773619318, 74688785527155),
	r8_wheel_rim_gold_crown = mesh(RIM, 75368748511491, 96885416514862),
	r8_wheel_rim_chrome_mirror = mesh(RIM, 136711870753733, 92392429003061),
	r8_wheel_rim_carbon = mesh(RIM, 128880424828005, 106732430216662),
	r8_wheel_rim_white_wall = mesh(RIM, 101072850283782, 124053847861471),
	r8_wheel_rim_stripe_tyre = mesh(RIM, 94246489666126, 78127483655652),
	r8_wheel_rim_neon_ring = mesh(RIM, 114980660399245, 128819161000080),
	r8_wheel_rim_glowing_hub = mesh(RIM, 103605653651608, 120296929524849),
	r8_wheel_rim_glowing_tread = mesh(RIM, 103351042921290, 84316462177829),
	r8_wheel_rim_flame_spoke = mesh(RIM, 104075588918375, 132786344976355),
	r8_wheel_rim_galaxy_disc = mesh(RIM, 90632201469912, 123631386811251),

	-- the Neon layers (slow pulse) and the drifting Galaxy stars
	r8_wheel_glow_neon_ring = mesh(RIM, 113187492368652, 122055383987543),
	r8_wheel_glow_glowing_hub = mesh(RIM, 101349091542908, 127129733890383),
	r8_wheel_glow_glowing_tread = mesh(
		TYRE .. ": a glow layer in the tyre's own frame",
		93577858648469,
		122300017552806
	),
	r8_wheel_glow_flame_spoke = mesh(RIM, 138589394711358, 101624421773865),
	r8_wheel_stars_galaxy_disc = mesh(RIM, 100059540451644, 79565884928927),

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
