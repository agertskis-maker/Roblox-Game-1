--!strict
-- Starts the island walking boost for the local character (Lane 3). Everything lives in the
-- WalkBoost module next to this script; the one switch is WalkBoost.ENABLED there. This script
-- creates nothing when the switch is off, and nothing in a place without the island's boost
-- lanes (Workspace.Lane3_IslandEnvironment.BoostLanes): it waits for them, with no polling loop.
-- Spec: vault/design/specs/walk-boost.md.

local WalkBoost = require(script.Parent.WalkBoost)

local function start()
	-- lives as long as the player's scripts; per-character state is cleaned on every respawn
	WalkBoost.new({ publish = true })
end

if WalkBoost.ENABLED then
	local env = workspace:FindFirstChild("Lane3_IslandEnvironment")
	if env and env:FindFirstChild("BoostLanes") then
		start()
	else
		-- the island streams in or is built later: start once its boost lanes appear
		local connection: RBXScriptConnection
		connection = workspace.DescendantAdded:Connect(function(d)
			if d.Name == "BoostLanes" and d.Parent and d.Parent.Name == "Lane3_IslandEnvironment" then
				connection:Disconnect()
				start()
			end
		end)
	end
end
