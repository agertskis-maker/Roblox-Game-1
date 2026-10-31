--!strict
-- CAR HOP BETA 1 server bootstrap. Off unless ReplicatedStorage.CarHopBeta exists (beta.project.json).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BetaConfig = require(ReplicatedStorage.Shared.Beta.BetaConfig)
if not BetaConfig.enabled() then
	return
end

local BetaData = require(script.Parent.BetaData)
local BetaPlots = require(script.Parent.BetaPlots)
local BetaShop = require(script.Parent.BetaShop)

BetaShop.start()
BetaPlots.start()
BetaData.start()
