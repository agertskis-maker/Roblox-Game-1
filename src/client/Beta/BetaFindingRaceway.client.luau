--!strict
-- Round 7 (A-01): before the server has given the player a plot, they wait by the island centre and a short line says so. It goes
-- the moment the HomePlot attribute arrives (the server then moves them to their own Raceway), or after 20 seconds. Beta only.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BetaConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Beta"):WaitForChild("BetaConfig"))
if not BetaConfig.enabled() then
	return
end

local player = Players.LocalPlayer
if player:GetAttribute(BetaConfig.HomePlotAttribute) ~= nil then
	return
end

local gui = Instance.new("ScreenGui")
gui.Name = "CarHopFindingRaceway"
gui.ResetOnSpawn = false
gui.DisplayOrder = 40
local label = Instance.new("TextLabel")
label.AnchorPoint = Vector2.new(0.5, 0)
label.Position = UDim2.new(0.5, 0, 0, 72)
label.Size = UDim2.fromOffset(320, 44)
label.BackgroundColor3 = Color3.fromRGB(24, 36, 72)
label.BackgroundTransparency = 0.1
label.FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json")
label.TextSize = 24
label.TextColor3 = Color3.fromRGB(255, 248, 232)
label.Text = "Finding your Raceway..."
label.Parent = gui
local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(1, 0)
corner.Parent = label
gui.Parent = player:WaitForChild("PlayerGui")

local t0 = os.clock()
while
	player:GetAttribute(BetaConfig.HomePlotAttribute) == nil
	and player:GetAttribute("BetaNoPlot") == nil
	and os.clock() - t0 < 20
do
	task.wait(0.2)
end
if player:GetAttribute("BetaNoPlot") then
	label.Text = "Every Raceway is taken in this server"
	task.wait(4)
end
gui:Destroy()
