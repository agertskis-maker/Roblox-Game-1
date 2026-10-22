--!strict
-- Starts the island walking boost for the local character (Lane 3). Everything lives in the
-- WalkBoost module next to this script; the one switch is WalkBoost.ENABLED there. This script
-- creates nothing when the switch is off. Spec: vault/design/specs/walk-boost.md.

local WalkBoost = require(script.Parent.WalkBoost)

if WalkBoost.ENABLED then
	-- lives as long as the player's scripts; per-character state is cleaned on every respawn
	WalkBoost.new({ publish = true })
end
