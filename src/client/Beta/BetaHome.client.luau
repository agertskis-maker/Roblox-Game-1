--!strict
-- CAR HOP BETA 2: the whole Lane 3 home UI in the beta (HomeShell). Only the beta glue knows there is a beta: this script
-- starts the shell, and BetaRun tells it when a run starts and ends through the attribute below. Off unless
-- ReplicatedStorage.CarHopBeta exists. The tutorial is for first-time players only (Adam, 2026-11-02): the beta save's
-- TutorialDone flag decides, and if the save never answers the player is not shown it. The attribute HomeJoinMode on
-- CarHopBeta ("new" or "returning") overrides that, for testing in Studio.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local BetaConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Beta"):WaitForChild("BetaConfig"))
if not BetaConfig.enabled() then
	return
end

local UI = script.Parent.Parent:WaitForChild("UI")
local HomeShell = require(UI:WaitForChild("HomeShell"))
local LaunchPad = require(UI:WaitForChild("LaunchPad"))

-- the Roblox player list would sit over the HUD's Settings button; the beta has few players
pcall(function()
	game:GetService("StarterGui"):SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)
end)

local player = Players.LocalPlayer

-- Round 6 (V-03): harness captions (GuiObjects with the attribute PreviewCaption) are review labels, not words for players;
-- the playground hides them in player-facing captures, so the beta hides them too. Two reviewers found them covering text
-- (the Garage's World tab and reward). PersistentPreview stamps and the Shop's PREVIEW footer are not captions and stay.
local function hideCaption(d: Instance)
	if d:IsA("GuiObject") and d:GetAttribute("PreviewCaption") == true then
		d.Visible = false
		d:GetPropertyChangedSignal("Visible"):Connect(function()
			if d.Visible then
				d.Visible = false
			end
		end)
	end
end
local playerGui = player:WaitForChild("PlayerGui")
for _, d in playerGui:GetDescendants() do
	hideCaption(d)
end
-- deferred: a screen sets the attribute just after it parents the label
playerGui.DescendantAdded:Connect(function(d: Instance)
	task.defer(hideCaption, d)
end)
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

LaunchPad.attachShell(shell)

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
		shell:runEnded(false)
	end
end)

-- Studio test driver (Round 7): the Studio MCP cannot press a button, so CarHopHomeCmd = "open:missions" (any panel key)
-- opens a panel the way its button does, and "tab:Racer" picks a Missions tab. Nothing here exists outside Studio.
if RunService:IsStudio() then
	player:GetAttributeChangedSignal("CarHopHomeCmd"):Connect(function()
		local text = player:GetAttribute("CarHopHomeCmd")
		if type(text) ~= "string" or text == "" then
			return
		end
		player:SetAttribute("CarHopHomeCmd", "")
		local command, arg = string.match(text, "^(%a+):(.+)$")
		if command == "open" and arg then
			shell.userPanel(arg)
		elseif command == "tab" and arg then
			local panel = shell.components and shell.components.missions
			if panel and panel.selectTab then
				panel:selectTab(arg)
			end
		end
	end)
end
