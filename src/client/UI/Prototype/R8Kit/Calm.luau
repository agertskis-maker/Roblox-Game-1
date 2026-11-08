--!strict
-- R8Kit.Calm (Lane 3 Round 8): Reduce Motion for the upgrade cards. Roblox's own setting (GuiService.ReducedMotionEnabled) plus the
-- preview-only, never-saved LocalPlayer attribute "Lane3ReducedMotionOverride" (the same rule as Speedway/Calm, copied here so the
-- kit has no dependency on the Home folder).
--
--   Calm() -> boolean      true when decorative motion must be skipped (shine sweeps, pops, confetti, spinning, camera moves)

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")

local OVERRIDE = "Lane3ReducedMotionOverride"

return function(): boolean
	local player = Players.LocalPlayer
	local override = player and player:GetAttribute(OVERRIDE)
	if type(override) == "boolean" then
		return override
	end
	return GuiService.ReducedMotionEnabled
end
