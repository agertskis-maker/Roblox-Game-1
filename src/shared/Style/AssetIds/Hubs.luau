--!strict
-- AssetIds.Hubs (Round 8): this workstream's art. Key -> Entry (see AssetIds/init.luau). Builders add keys with id = nil and drop
-- the PNG into Car-Hop-Art/upload-round8/<key>.png; only the lead fills in `id` after a group-owned upload (LEGION STUDI0S).
local Types = require(script.Parent.Types)

local entries: { [string]: Types.Entry } = {
	-- Coach Roxy's bust portrait, the picture on every Roxy speech card (Screens/DialogueCard, H-05). Owner: group LEGION STUDI0S
	-- (74306252), re-uploaded in Round 8 (O-02), moderation Approved. It replaces the Round 7 upload 106010075891034, which was
	-- under Adam's own account peskaface. DialogueCard no longer types an id: it reads this key, so this is the ONE place to
	-- change the id if the portrait is ever re-uploaded again.
	r8_hubs_roxy_portrait = {
		id = 85738342467843,
		kind = "Image",
		size = Vector2.new(480, 600),
		source = "Car-Hop-Art/upload-round7/art_r7_roxy_portrait.png (R7-IMG-01 cut-out), re-uploaded under the group",
	},
}

return entries
