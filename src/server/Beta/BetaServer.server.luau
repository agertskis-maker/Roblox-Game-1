--!strict
-- CAR HOP BETA 1 server bootstrap. Off unless ReplicatedStorage.CarHopBeta exists (beta.project.json).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BetaConfig = require(ReplicatedStorage.Shared.Beta.BetaConfig)
if not BetaConfig.enabled() then
	return
end

-- Beta 3: with Brian L's economy preview on, it owns saves, plots and purchases (one owner), so this server stands down.
-- This replaces switching this script off by hand in the place.
if workspace:GetAttribute("Lane2EconomyPreview") == true then
	require(script.Parent.BetaEconomyBridge).start()
	return
end

local BetaData = require(script.Parent.BetaData)
local BetaPlots = require(script.Parent.BetaPlots)
local BetaShop = require(script.Parent.BetaShop)

-- With no SpawnLocation a player appears at the world's centre, which is inside the fountain (Adam, 2026-11-02: spawn in
-- front of it). On the plaza, facing the fountain and the portals beyond it.
local spawnPad = Instance.new("SpawnLocation")
spawnPad.Name = "CarHopBetaSpawn"
spawnPad.Size = Vector3.new(10, 0.2, 10)
spawnPad.CFrame = CFrame.lookAt(Vector3.new(0, 0.1, -30), Vector3.new(0, 0.1, 0))
spawnPad.Anchored = true
spawnPad.CanCollide = false
spawnPad.CanTouch = false
spawnPad.CanQuery = false
spawnPad.Transparency = 1
spawnPad.Neutral = true
spawnPad.Duration = 0
local decal = spawnPad:FindFirstChildOfClass("Decal")
if decal then
	decal:Destroy()
end
spawnPad.Parent = workspace

BetaShop.start()
BetaPlots.start()
BetaData.start()
