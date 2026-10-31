--!strict
-- CAR HOP BETA 1: gives each joining player one free island plot and frees it when they leave. The
-- plot's attributes are what Lane 3's Raceway looks already read: Owner (UserId), OwnerDisplayName,
-- SpeedwayLevel and ParkingSpots; the player gets HomePlot (the plot number). Stand-in for Lane 2's
-- plot service (board row "server code that gives a joining player a plot").

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local BetaConfig = require(ReplicatedStorage.Shared.Beta.BetaConfig)
local BetaData = require(script.Parent.BetaData)
local Ladder = require(ReplicatedStorage.Shared.Island.Speedway.Ladder)
local Parking = require(ReplicatedStorage.Shared.Island.Speedway.Parking)

local BetaPlots = {}

local owners: { [Model]: Player } = {}

local function plotsFolder(): Instance?
	local root = Workspace:FindFirstChild("Lane3_IslandPreview")
	local island = root and root:FindFirstChild("Island")
	return island and island:FindFirstChild("Plots")
end

local function plotIndex(plot: Instance): number?
	return tonumber(string.match(plot.Name, "^Plot(%d+)$"))
end

-- the free plot with the lowest number
local function freePlot(): Model?
	local folder = plotsFolder()
	if not folder then
		warn("[CarHopBeta] no island plots (Workspace.Lane3_IslandPreview.Island.Plots); bake the island first")
		return nil
	end
	local best: Model?, bestIndex = nil, math.huge
	for _, plot in folder:GetChildren() do
		local index = plotIndex(plot)
		if plot:IsA("Model") and index and not owners[plot] and index < bestIndex then
			best, bestIndex = plot, index
		end
	end
	return best
end

function BetaPlots.plotOf(player: Player): Model?
	for plot, owner in owners do
		if owner == player then
			return plot
		end
	end
	return nil
end

-- writes the saved numbers onto the player's plot (called on load and after each purchase)
function BetaPlots.publish(player: Player)
	local plot = BetaPlots.plotOf(player)
	local data = BetaData.get(player)
	if not (plot and data) then
		return
	end
	plot:SetAttribute("SpeedwayLevel", Ladder.clamp(data.RacewayLevel))
	plot:SetAttribute("ParkingSpots", Parking.clamp(data.ParkingSpots))
end

local function release(player: Player)
	local plot = BetaPlots.plotOf(player)
	if not plot then
		return
	end
	owners[plot] = nil
	for _, name in { "Owner", "OwnerDisplayName", "SpeedwayLevel", "ParkingSpots" } do
		plot:SetAttribute(name, nil)
	end
end

function BetaPlots.start()
	BetaData.Loaded:Connect(function(player: Player)
		local plot = freePlot()
		if not plot then
			return
		end
		owners[plot] = player
		plot:SetAttribute("Owner", player.UserId)
		plot:SetAttribute("OwnerDisplayName", player.DisplayName)
		player:SetAttribute(BetaConfig.HomePlotAttribute, plotIndex(plot))
		BetaPlots.publish(player)
	end)
	Players.PlayerRemoving:Connect(release)
end

return BetaPlots
