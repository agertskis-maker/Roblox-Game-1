--!strict
-- Economy PREVIEW save data (Lane 2). The only profile owner while the preview runs. It uses
-- ProfileStore.Mock ONLY: nothing reaches a real DataStore, and data lasts for one Studio
-- server. The template is the proposal in vault/design/specs/economy-v1.md section 13 and is
-- not the game's agreed save layout.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local ProfileStore = require(ServerScriptService.Server.vendor.ProfileStore)
local Signal = require(ReplicatedStorage.Packages.Signal)

export type CarSave = {
	Edition: number,
	Copies: number,
}

export type SaveData = {
	Cash: number,
	Cars: { [string]: CarSave },
	Lineup: { string },
	RacewayLevel: number,
	ParkingSpots: number,
	WorldsUnlocked: { [string]: boolean },
	LastSeen: number,
}

-- Reversible pick (Claude): the starter car, a Common from Brian L's showroom.
local STARTER_CAR = "Rustbucket"

local TEMPLATE: SaveData = {
	Cash = 0,
	Cars = {},
	Lineup = {},
	RacewayLevel = 1,
	ParkingSpots = 2,
	WorldsUnlocked = { Downtown = true },
	LastSeen = 0,
}

local store = ProfileStore.New("CarHopEconomyPreview", TEMPLATE)
local profiles: { [Player]: any } = {}

local Data = {}

-- Fires (player, data) once a profile is loaded and ready.
Data.Loaded = Signal.new()
-- Fires (player) just before a profile is released.
Data.Releasing = Signal.new()

function Data.get(player: Player): SaveData?
	local profile = profiles[player]
	return if profile then profile.Data :: SaveData else nil
end

local function onPlayerAdded(player: Player)
	local profile = store.Mock:StartSessionAsync(tostring(player.UserId), {
		Cancel = function()
			return player.Parent ~= Players
		end,
	})
	if profile == nil then
		player:Kick("Your preview data could not load. Please rejoin.")
		return
	end
	profile:AddUserId(player.UserId)
	profile:Reconcile()
	profile.OnSessionEnd:Connect(function()
		profiles[player] = nil
		player:Kick("Your preview session ended. Please rejoin.")
	end)
	if player.Parent ~= Players then
		profile:EndSession()
		return
	end
	local data = profile.Data :: SaveData
	if next(data.Cars) == nil then
		data.Cars[STARTER_CAR] = { Edition = 1, Copies = 0 }
	end
	profiles[player] = profile
	Data.Loaded:Fire(player, data)
end

local function release(player: Player)
	local profile = profiles[player]
	if profile then
		Data.Releasing:Fire(player)
		profiles[player] = nil
		profile:EndSession()
	end
end

function Data.start()
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(release)
	game:BindToClose(function()
		for _, player in Players:GetPlayers() do
			release(player)
		end
	end)
end

return Data
