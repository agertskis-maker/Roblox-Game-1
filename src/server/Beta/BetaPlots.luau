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
local RunService = game:GetService("RunService")
local Signal = require(ReplicatedStorage.Packages.Signal)

local BetaPlots = {}

BetaPlots.Assigned = Signal.new() -- (player, plot) once a joining player has a plot (Round 5: the Lap Pay clock starts)

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

-- Round 4: does this player own the Expanded Paddock pass? A STAND-IN until Brian L's server checks real pass ownership:
-- nobody owns it, except in Studio when ReplicatedStorage.CarHopBeta has the attribute PreviewExpandedPaddock = true (a test
-- switch, so the pass's 3 bays can be seen). The pass's bays are never saved: the saved ParkingSpots stays 2 to 15 and the 3
-- are added on top when the plot is published.
function BetaPlots.hasExpandedPaddock(_player: Player): boolean
	local config = ReplicatedStorage:FindFirstChild(BetaConfig.MarkerName)
	return RunService:IsStudio() and config ~= nil and config:GetAttribute("PreviewExpandedPaddock") == true
end

-- The player's parking spots on the plot: the bought ones plus the pass's 3.
function BetaPlots.spotsOf(player: Player): number
	local data = BetaData.get(player)
	if not data then
		return Parking.StartSpots
	end
	local extra = if BetaPlots.hasExpandedPaddock(player) then Parking.ExpandedSpots else 0
	return Parking.clamp(data.ParkingSpots) + extra
end

-- writes the saved numbers onto the player's plot (called on load and after each purchase)
function BetaPlots.publish(player: Player)
	local plot = BetaPlots.plotOf(player)
	local data = BetaData.get(player)
	if not (plot and data) then
		return
	end
	plot:SetAttribute("SpeedwayLevel", Ladder.clamp(data.RacewayLevel))
	plot:SetAttribute(Parking.ExpandedAttribute, if BetaPlots.hasExpandedPaddock(player) then true else nil)
	plot:SetAttribute("ParkingSpots", BetaPlots.spotsOf(player))
end

local function release(player: Player)
	local plot = BetaPlots.plotOf(player)
	if not plot then
		return
	end
	owners[plot] = nil
	for _, name in
		{
			"Owner",
			"OwnerDisplayName",
			"SpeedwayLevel",
			"ParkingSpots",
			Parking.ExpandedAttribute,
			BetaConfig.LapEpochAttribute,
			BetaConfig.LapSecondsAttribute,
		}
	do
		plot:SetAttribute(name, nil)
	end
end

function BetaPlots.start()
	BetaData.Loaded:Connect(function(player: Player)
		local plot = freePlot()
		if not plot then
			-- Max Players is 6 (draft 0013); a seventh player in a Studio test plays without a plot and is told so
			player:SetAttribute("BetaNoPlot", true)
			print(string.format("[CarHopBeta] no free plot for %s: every plot is taken", player.Name))
			return
		end
		owners[plot] = player
		plot:SetAttribute("Owner", player.UserId)
		plot:SetAttribute("OwnerDisplayName", player.DisplayName)
		player:SetAttribute(BetaConfig.HomePlotAttribute, plotIndex(plot))
		BetaPlots.publish(player)
		BetaPlots.Assigned:Fire(player, plot)
	end)
	Players.PlayerRemoving:Connect(release)
	-- the Studio test switch flips every plot at once
	local config = ReplicatedStorage:FindFirstChild(BetaConfig.MarkerName)
	if config then
		config:GetAttributeChangedSignal("PreviewExpandedPaddock"):Connect(function()
			for _, player in Players:GetPlayers() do
				BetaPlots.publish(player)
			end
		end)
	end
end

return BetaPlots
