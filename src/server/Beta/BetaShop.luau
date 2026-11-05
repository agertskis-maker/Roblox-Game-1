--!strict
-- CAR HOP BETA 1: the two Raceway purchases (the shop's BUY and the parking sign's BUY). Free in the
-- beta: there is no Cash yet (the economy is Brian L's and propose-first), so a purchase only raises
-- the caller's own saved number by one. The client sends no arguments; the server checks that the
-- player has a loaded save and a plot, the limits (level 12, 15 spots) and a short cooldown.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BetaConfig = require(ReplicatedStorage.Shared.Beta.BetaConfig)
local BetaData = require(script.Parent.BetaData)
local BetaPlots = require(script.Parent.BetaPlots)
local Ladder = require(ReplicatedStorage.Shared.Island.Speedway.Ladder)
local Parking = require(ReplicatedStorage.Shared.Island.Speedway.Parking)

local BetaShop = {}

local COOLDOWN = 0.75 -- seconds between purchases per player (the panel also locks BUY until the reveal ends)

local lastBuy: { [Player]: number } = {}

local function allowed(player: Player): boolean
	local now = os.clock()
	if now - (lastBuy[player] or -math.huge) < COOLDOWN then
		return false
	end
	if not (BetaData.get(player) and BetaPlots.plotOf(player)) then
		return false
	end
	lastBuy[player] = now
	return true
end

function BetaShop.start()
	local net = Instance.new("Folder")
	net.Name = BetaConfig.NetName
	local buyLevel = Instance.new("RemoteEvent")
	buyLevel.Name = BetaConfig.Remotes.BuyRacewayLevel
	buyLevel.Parent = net
	local buySpot = Instance.new("RemoteEvent")
	buySpot.Name = BetaConfig.Remotes.BuyParkingSpot
	buySpot.Parent = net
	net.Parent = ReplicatedStorage

	buyLevel.OnServerEvent:Connect(function(player: Player)
		if not allowed(player) then
			return
		end
		local data = BetaData.get(player) :: BetaData.Data
		if data.RacewayLevel < Ladder.MaxLevel then
			data.RacewayLevel = Ladder.clamp(data.RacewayLevel + 1)
			BetaPlots.publish(player)
		end
	end)
	buySpot.OnServerEvent:Connect(function(player: Player)
		if not allowed(player) then
			return
		end
		local data = BetaData.get(player) :: BetaData.Data
		if data.ParkingSpots < Parking.MaxSpots then
			data.ParkingSpots = Parking.clamp(data.ParkingSpots + 1)
			BetaPlots.publish(player)
		end
	end)
	Players.PlayerRemoving:Connect(function(player: Player)
		lastBuy[player] = nil
	end)
end

return BetaShop
