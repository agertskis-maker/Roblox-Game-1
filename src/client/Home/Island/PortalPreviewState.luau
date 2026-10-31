--!strict
-- PREVIEW lock state for the island's World portals (Lane 3, client only). This is a stand-in
-- until the real replicated unlock state is agreed with Lanes 1 and 2: it decides only how this
-- player's portals LOOK. It grants nothing, changes no shared state or collision, and is not
-- security; access control belongs to the gameplay and server systems.
--
-- Default: Downtown open, Dusty Highway and Summit Pass locked. In Studio only, a LocalPlayer
-- attribute "Lane3PortalLocked_<World>" (true or false) overrides a World, for testing lock and
-- unlock; outside Studio the attributes are ignored. Example (command bar, Play, client):
--   game.Players.LocalPlayer:SetAttribute("Lane3PortalLocked_DustyHighway", false)

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local PortalPreviewState = {}

PortalPreviewState.Source = "preview (Studio test toggle); real unlock state not agreed yet"

local DEFAULT: { [string]: boolean } = { Downtown = false, DustyHighway = true, SummitPass = true }
local PREFIX = "Lane3PortalLocked_"

function PortalPreviewState.isLocked(world: string): boolean
	if RunService:IsStudio() then
		local v = Players.LocalPlayer:GetAttribute(PREFIX .. world)
		if type(v) == "boolean" then
			return v
		end
	end
	local d = DEFAULT[world]
	return if d == nil then true else d
end

-- Calls back with (world) whenever a Studio test toggle changes; returns the connection.
function PortalPreviewState.onChanged(callback: (string) -> ()): RBXScriptConnection
	return Players.LocalPlayer.AttributeChanged:Connect(function(name)
		if RunService:IsStudio() and string.sub(name, 1, #PREFIX) == PREFIX then
			callback(string.sub(name, #PREFIX + 1))
		end
	end)
end

return PortalPreviewState
