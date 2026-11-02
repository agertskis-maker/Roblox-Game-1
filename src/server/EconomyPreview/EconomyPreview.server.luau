--!strict
-- Starts the economy PREVIEW (Lane 2, Brian L). It runs only in a place whose Workspace has the
-- attribute Lane2EconomyPreview = true (Brian L's private copy), so syncing this branch into any
-- other place does nothing. Saves use ProfileStore.Mock only.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

if Workspace:GetAttribute("Lane2EconomyPreview") ~= true then
	return
end

local Cars = require(script.Parent.Cars)
local Data = require(script.Parent.Data)
local Dev = require(script.Parent.Dev)
local Economy = require(script.Parent.Economy)
local LapPay = require(script.Parent.LapPay)
local Plots = require(script.Parent.Plots)
local Shop = require(script.Parent.Shop)

Cars.load()
Shop.createRemotes()
Dev.expose()

Economy.PlotChanged:Connect(function(player: Player)
	Shop.publish(player)
end)

Data.Loaded:Connect(function(player: Player, data: Data.SaveData)
	Economy.setup(player, data)
	Plots.assign(player)
	Economy.refreshLineup(player)
	LapPay.payOffline(player)
	Shop.addPrompts(player)
	LapPay.start(player)
end)

Data.Releasing:Connect(function(player: Player)
	local data = Data.get(player)
	if data then
		data.LastSeen = os.time()
	end
	LapPay.stop(player)
	Shop.removePrompts(player)
	Plots.release(player)
end)

Players.PlayerRemoving:Connect(function(player: Player)
	-- Data releases the profile on its own PlayerRemoving handler; this clears anything left.
	LapPay.stop(player)
	Shop.removePrompts(player)
	Plots.release(player)
end)

Data.start()
print("[EconomyPreview] started (Mock saves only)")
