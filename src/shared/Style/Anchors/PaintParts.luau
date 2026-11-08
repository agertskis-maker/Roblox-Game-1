--!strict
-- Anchors.PaintParts (Round 8): per-car data keyed by the car model name under ReplicatedStorage.Cars (Normal edition name; Gold,
-- Diamond and Rainbow editions share it unless a key of their own exists). Shape frozen in
-- vault/design/specs/lane3-round8-contracts.md; only the owning workstream edits this file.
local Types = require(script.Parent.Types)

local data: { [string]: Types.PaintParts } = {}

return data
