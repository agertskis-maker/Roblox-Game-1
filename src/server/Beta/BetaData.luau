--!strict
-- CAR HOP BETA 1: the one owner of player profiles in the beta (ProfileStore, the vendored copy).
-- Pattern from AGENTS.md: one store, StartSessionAsync on join, kick when it returns nil, AddUserId
-- and Reconcile, kick on OnSessionEnd, EndSession on leave (BindToClose is handled by ProfileStore).
-- Stand-in for Lane 2's real lifecycle module; the template is BetaConfig.Template.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local BetaConfig = require(ReplicatedStorage.Shared.Beta.BetaConfig)
local ProfileStore = require(ServerScriptService.Server.vendor.ProfileStore) :: any
local Signal = require(ReplicatedStorage.Packages.Signal)

export type Data = { RacewayLevel: number, ParkingSpots: number }

local BetaData = {}

BetaData.Loaded = Signal.new() -- (player, data)

local store = ProfileStore.New(BetaConfig.StoreName, BetaConfig.Template)
local profiles: { [Player]: any } = {}

function BetaData.get(player: Player): Data?
	local profile = profiles[player]
	return if profile and profile:IsActive() then profile.Data :: Data else nil
end

local function load(player: Player)
	local profile = store:StartSessionAsync(tostring(player.UserId), {
		Cancel = function()
			return player.Parent ~= Players
		end,
	})
	if profile == nil then
		player:Kick("Your save could not be loaded. Please rejoin.")
		return
	end
	profile:AddUserId(player.UserId)
	profile:Reconcile()
	profile.OnSessionEnd:Connect(function()
		profiles[player] = nil
		player:Kick("Your save was opened somewhere else. Please rejoin.")
	end)
	if player.Parent ~= Players then
		profile:EndSession()
		return
	end
	profiles[player] = profile
	BetaData.Loaded:Fire(player, profile.Data)
end

function BetaData.start()
	ProfileStore.OnError:Connect(function(message: string, storeName: string, key: string)
		warn(string.format("[CarHopBeta] save error (%s, %s): %s", storeName, key, message))
	end)
	for _, player in Players:GetPlayers() do
		task.spawn(load, player)
	end
	Players.PlayerAdded:Connect(load)
	Players.PlayerRemoving:Connect(function(player: Player)
		local profile = profiles[player]
		profiles[player] = nil
		if profile then
			profile:EndSession()
		end
	end)
end

return BetaData
