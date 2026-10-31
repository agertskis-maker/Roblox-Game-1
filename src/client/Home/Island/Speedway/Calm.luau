--!strict
-- Reduce Motion for the Speedway (Lane 3, approved rule 2026-10-19): Roblox's own setting
-- (GuiService.ReducedMotionEnabled) plus the preview-only, never-saved LocalPlayer attribute
-- "Lane3ReducedMotionOverride".

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
