--!strict
-- AssetIds.Clover (Round 8, WS-9 Lucky Clover): this workstream's art. Key -> Entry (see AssetIds/init.luau). Builders add keys with
-- id = nil and drop the file into Car-Hop-Art/upload-round8/<key>.<ext>; only the lead fills in `id` after a group-owned upload
-- (LEGION STUDI0S). Meshes are FBX from Blender (blender-round8/build_clover.py), all textured by the one palette image.
-- Each FBX is one mesh, origin at its bounding-box centre, 1 Blender unit = 1 stud, the front toward Blender -Y (so it faces +Z in
-- Roblox: CloverMeshes.FACING turns it around). Upload each FBX as a Mesh asset (no texture; the palette PNG is the texture).
local Types = require(script.Parent.Types)

local entries: { [string]: Types.Entry } = {
	-- uploaded 2026-11-08 by the lead (group 74306252, Approved): the palette is an Image asset, the FBX went up as Model assets
	-- (the Model asset ids are in the comments; each mesh's `id` is its Model's MeshPart.MeshId, read in Studio)
	r8_clover_palette = {
		id = 72951135578149,
		kind = "Image",
		size = Vector2.new(256, 128),
		source = "upload-round8/r8_clover_palette.png",
	},
	r8_clover_body = { kind = "Mesh", source = "upload-round8/r8_clover_body.fbx" }, -- mascot: leaves, stem, face, coin badge
	r8_clover_eye = { kind = "Mesh", source = "upload-round8/r8_clover_eye.fbx" }, -- used for both eyes
	r8_clover_hat = { kind = "Mesh", source = "upload-round8/r8_clover_hat.fbx" }, -- bowler with the gold band
	r8_clover_arm_l = { kind = "Mesh", source = "upload-round8/r8_clover_arm_l.fbx" }, -- arm and white glove
	r8_clover_arm_r = { kind = "Mesh", source = "upload-round8/r8_clover_arm_r.fbx" },
	r8_clover_sign = { kind = "Mesh", source = "upload-round8/r8_clover_sign.fbx" }, -- the big roof clover
	r8_clover_coin = { kind = "Mesh", source = "upload-round8/r8_clover_coin.fbx" }, -- gold coin with the clover emboss
	r8_clover_horseshoe = { kind = "Mesh", source = "upload-round8/r8_clover_horseshoe.fbx" },
	r8_clover_awning = { kind = "Mesh", source = "upload-round8/r8_clover_awning.fbx" }, -- striped, scalloped
}

return entries
