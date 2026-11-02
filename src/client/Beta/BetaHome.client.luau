--!strict
-- CAR HOP BETA 2: the whole Lane 3 home UI in the beta (HomeShell). Only the beta glue knows there is a beta: this script
-- starts the shell, and BetaRun tells it when a run starts and ends through the two attributes below. Off unless
-- ReplicatedStorage.CarHopBeta exists. The attribute HomeJoinMode on that object says which join to show ("new", the
-- default, or "returning"): nothing saved says so yet, and the beta adds no save field for it.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BetaConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Beta"):WaitForChild("BetaConfig"))
if not BetaConfig.enabled() then
	return
end

local HomeShell = require(script.Parent.Parent:WaitForChild("UI"):WaitForChild("HomeShell"))

local player = Players.LocalPlayer
local config = ReplicatedStorage:FindFirstChild(BetaConfig.MarkerName) :: Instance
local joinMode = config:GetAttribute("HomeJoinMode")

local shell = HomeShell.start({
	joinMode = if joinMode == "returning" then "returning" else "new",
	cashPreview = true,
	onLog = function(text: string)
		print("[CarHopBeta home] " .. text)
	end,
})

local OWNER = "CarHopBetaRun"
local running = false
player:GetAttributeChangedSignal("MovementSpeedOwner"):Connect(function()
	local now = player:GetAttribute("MovementSpeedOwner") == OWNER
	if now == running then
		return
	end
	running = now
	if now then
		shell:runStarted()
	else
		shell:runEnded(true)
	end
end)
