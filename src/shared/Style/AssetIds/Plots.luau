--!strict
-- AssetIds.Plots (Round 8): this workstream's art. Key -> Entry (see AssetIds/init.luau). Builders add keys with id = nil and drop
-- the PNG into Car-Hop-Art/upload-round8/<key>.png; only the lead fills in `id` after a group-owned upload (LEGION STUDI0S).
--
-- WS-7 (H-01 to H-03) adds no art keys: the plot badges (round headshot, rims, name plate, ribbon), the letter placeholder and every
-- bay marking (dashed outline, "+", EMPTY, padlock, price, rarity glow) are drawn live in code with the game font, so nothing here
-- waits for an upload and no code-drawn fallback is needed. Add a key here only if a later round swaps one of them for art.
local Types = require(script.Parent.Types)

local entries: { [string]: Types.Entry } = {}

return entries
