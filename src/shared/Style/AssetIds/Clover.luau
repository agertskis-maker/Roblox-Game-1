--!strict
-- AssetIds.Clover (Round 8, WS-9 Lucky Clover): this workstream's art. Key -> Entry (see AssetIds/init.luau). Builders add keys with
-- id = nil and drop the file into Car-Hop-Art/upload-round8/<key>.<ext>; only the lead fills in `id` after a group-owned upload
-- (LEGION STUDI0S). Meshes are FBX from Blender (blender-round8/build_clover.py), all coloured by the one palette image through
-- their UVs. Each FBX is one mesh, origin at its bounding-box centre, 1 Blender unit = 1 stud; Roblox's importer turns Blender
-- (x, y, z) into (-x, z, y), so the mascot faces -Z (measured in Studio on the uploaded models, 2026-11-08).
--
-- Uploaded 2026-11-08 by the lead into group 74306252 (all Approved). The FBX went up as Model assets; each mesh's `id` here is that
-- Model's MeshPart.MeshId, read in Studio under the lock (the Model asset id is in the comment); the palette is an Image asset.
local Types = require(script.Parent.Types)

local entries: { [string]: Types.Entry } = {
	r8_clover_palette = {
		id = 72951135578149,
		kind = "Image",
		size = Vector2.new(256, 128),
		source = "upload-round8/r8_clover_palette.png",
	},
	-- mascot: leaves, stem, face and coin badge (Model 72397830068362)
	r8_clover_body = { id = 136284718969000, kind = "Mesh", source = "upload-round8/r8_clover_body.fbx" },
	-- used for both eyes (Model 72896921587350)
	r8_clover_eye = { id = 139573197847162, kind = "Mesh", source = "upload-round8/r8_clover_eye.fbx" },
	-- bowler with the gold band (Model 81565481551609)
	r8_clover_hat = { id = 112531315636504, kind = "Mesh", source = "upload-round8/r8_clover_hat.fbx" },
	-- arm and white glove (Models 78161338933004 and 138352966827327)
	r8_clover_arm_l = { id = 132706441161701, kind = "Mesh", source = "upload-round8/r8_clover_arm_l.fbx" },
	r8_clover_arm_r = { id = 110222137009566, kind = "Mesh", source = "upload-round8/r8_clover_arm_r.fbx" },
	-- the big roof clover, also the small clovers on the carved sign (Model 118615764681278)
	r8_clover_sign = { id = 89237279519485, kind = "Mesh", source = "upload-round8/r8_clover_sign.fbx" },
	-- gold coin with the clover emboss (Model 84665897643781)
	r8_clover_coin = { id = 82491915784890, kind = "Mesh", source = "upload-round8/r8_clover_coin.fbx" },
	-- (Model 109454175408944)
	r8_clover_horseshoe = { id = 117214933328135, kind = "Mesh", source = "upload-round8/r8_clover_horseshoe.fbx" },
	-- striped, scalloped (Model 87109885230526)
	r8_clover_awning = { id = 129612475244333, kind = "Mesh", source = "upload-round8/r8_clover_awning.fbx" },
}

return entries
