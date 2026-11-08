--!strict
-- AssetIds.Clover (Round 8): this workstream's art. Key -> Entry (see AssetIds/init.luau). Builders add keys with id = nil and drop
-- the PNG into Car-Hop-Art/upload-round8/<key>.png; only the lead fills in `id` after a group-owned upload (LEGION STUDI0S).
local Types = require(script.Parent.Types)

local entries: { [string]: Types.Entry } = {}

return entries
