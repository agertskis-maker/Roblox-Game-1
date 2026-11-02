--!strict
-- CAR HOP BETA 2: the whole Lane 3 home UI in the beta (HomeShell). Only the beta glue knows there is a beta: this script
-- starts the shell, and BetaRun tells it when a run starts and ends through the attribute below. Off unless
-- ReplicatedStorage.CarHopBeta exists. The tutorial is for first-time players only (Adam, 2026-11-02): the beta save's
-- TutorialDone flag decides, and if the save never answers the player is not shown it. The attribute HomeJoinMode on
-- CarHopBeta ("new" or "returning") overrides that, for testing in Studio.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BetaConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Beta"):WaitForChild("BetaConfig"))
if not BetaConfig.enabled() then
	return
end

local HomeShell = require(script.Parent.Parent:WaitForChild("UI"):WaitForChild("HomeShell"))

-- the Roblox player list would sit over the HUD's Settings button; the beta has few players
pcall(function()
	game:GetService("StarterGui"):SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)
end)

local player = Players.LocalPlayer
local config = ReplicatedStorage:FindFirstChild(BetaConfig.MarkerName) :: Instance

local function joinMode(): string
	local forced = config:GetAttribute("HomeJoinMode")
	if forced == "new" or forced == "returning" then
		return forced
	end
	local t0 = os.clock()
	while player:GetAttribute(BetaConfig.TutorialDoneAttribute) == nil and os.clock() - t0 < 10 do
		task.wait(0.1)
	end
	return if player:GetAttribute(BetaConfig.TutorialDoneAttribute) == false then "new" else "returning"
end

local shell = HomeShell.start({
	joinMode = joinMode(),
	cashPreview = true,
	onTutorialDone = function()
		local net = ReplicatedStorage:FindFirstChild(BetaConfig.NetName)
		local remote = net and net:FindFirstChild(BetaConfig.Remotes.TutorialDone)
		if remote and remote:IsA("RemoteEvent") then
			remote:FireServer()
		end
	end,
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
