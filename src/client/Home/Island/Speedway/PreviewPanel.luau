--!strict
-- PREVIEW ONLY (Lane 3, Studio playtests of the private island place): a small panel to step a
-- plot's Speedway look up and down. It only sets LocalPlayer attributes that SpeedwayLooks reads;
-- there is no remote, price, Cash or save. Never shown outside Studio. Spec:
-- vault/design/ui/speedway-upgrade-board.md (section "Preview panel").
--
-- Attributes (LocalPlayer, session only):
--   Lane3SpeedwayPreviewHome           the plot the panel drives (default 3)
--   Lane3SpeedwayPreviewLevel_PlotNN   that plot's preview level
--   Lane3SpeedwayPreviewLevel          one level for every plot (the "All" toggle)
--   Lane3SpeedwayGhost                 the next level's ghost outline (default on)
--   Lane3ReducedMotionOverride         the preview-only Reduce Motion override
--   Lane3SpeedwayPreviewPanel          false hides this panel (clean captures)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Tokens = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UI"):WaitForChild("Tokens"))

local PreviewPanel = {}

local NAVY = Color3.fromRGB(36, 58, 98)
local CREAM = Color3.fromRGB(255, 246, 224)
local CORAL = Color3.fromRGB(244, 127, 112)
local INK = Color3.fromRGB(20, 27, 51)

local function button(parent: Instance, text: string, width: number, order: number): TextButton
	local b = Instance.new("TextButton")
	b.Name = text
	b.LayoutOrder = order
	b.Size = UDim2.fromOffset(width, Tokens.Touch.Minimum)
	b.BackgroundColor3 = CORAL
	b.AutoButtonColor = true
	b.FontFace = Tokens.font()
	b.TextSize = Tokens.TextSize.Label
	b.TextColor3 = CREAM
	b.Text = text
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 12)
	c.Parent = b
	local s = Instance.new("UIStroke")
	s.Color = INK
	s.Thickness = 2
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	s.Parent = b
	b.Parent = parent
	return b
end

local function row(parent: Instance, order: number): Frame
	local f = Instance.new("Frame")
	f.LayoutOrder = order
	f.BackgroundTransparency = 1
	f.Size = UDim2.fromOffset(300, Tokens.Touch.Minimum)
	local l = Instance.new("UIListLayout")
	l.FillDirection = Enum.FillDirection.Horizontal
	l.Padding = UDim.new(0, 6)
	l.SortOrder = Enum.SortOrder.LayoutOrder
	l.VerticalAlignment = Enum.VerticalAlignment.Center
	l.Parent = f
	f.Parent = parent
	return f
end

-- `levelOf(index)` returns a plot's current look level; `plotCount` the number of plots.
-- Returns a cleanup function and a refresh function (both nil outside Studio).
function PreviewPanel.mount(
	levelOf: (number) -> number,
	plotCount: number,
	maxLevel: number
): ((() -> ())?, (() -> ())?)
	-- the preview panel is a Studio tool; the beta (Car Hop Beta 1) shows the real saved levels instead
	if not RunService:IsStudio() or ReplicatedStorage:FindFirstChild("CarHopBeta") then
		return nil, nil
	end
	local player = Players.LocalPlayer
	local function home(): number
		local h = player:GetAttribute("Lane3SpeedwayPreviewHome")
		return if type(h) == "number" then h else 3
	end
	local screen = Instance.new("ScreenGui")
	screen.Name = "Lane3SpeedwayPreview"
	screen.ResetOnSpawn = false
	screen.DisplayOrder = 15
	local panel = Instance.new("Frame")
	panel.AnchorPoint = Vector2.new(0, 1)
	panel.Position = UDim2.new(0, 12, 1, -12)
	panel.AutomaticSize = Enum.AutomaticSize.XY
	panel.BackgroundColor3 = NAVY
	panel.BackgroundTransparency = 0.1
	panel.Parent = screen
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 14)
	corner.Parent = panel
	local pad = Instance.new("UIPadding")
	for _, k in { "PaddingLeft", "PaddingRight", "PaddingTop", "PaddingBottom" } do
		(pad :: any)[k] = UDim.new(0, 8)
	end
	pad.Parent = panel
	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 6)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = panel
	local title = Instance.new("TextLabel")
	title.LayoutOrder = 0
	title.BackgroundTransparency = 1
	title.Size = UDim2.fromOffset(300, 26)
	title.FontFace = Tokens.font()
	title.TextSize = Tokens.TextSize.Label
	title.TextColor3 = CREAM
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Parent = panel

	local r1 = row(panel, 1)
	local down = button(r1, "-", 56, 1)
	local up = button(r1, "+", 56, 2)
	local plotButton = button(r1, "Plot", 80, 3)
	local allButton = button(r1, "All", 80, 4)
	local r2 = row(panel, 2)
	local ghostButton = button(r2, "Ghost", 96, 1)
	local calmButton = button(r2, "Calm", 96, 2)
	local hideButton = button(r2, "Hide", 96, 3)

	local function refresh()
		local h = home()
		local all = player:GetAttribute("Lane3SpeedwayPreviewLevel")
		title.Text =
			string.format("RACEWAY PREVIEW  ·  Plot %d  ·  Level %d%s", h, levelOf(h), if all then " (all)" else "")
		ghostButton.Text = if player:GetAttribute("Lane3SpeedwayGhost") == false then "Ghost: off" else "Ghost: on"
		calmButton.Text = if player:GetAttribute("Lane3ReducedMotionOverride") == true then "Calm: on" else "Calm: off"
	end
	local function setLevel(level: number)
		local h = home()
		local l = math.clamp(level, 1, maxLevel)
		if player:GetAttribute("Lane3SpeedwayPreviewLevel") ~= nil then
			player:SetAttribute("Lane3SpeedwayPreviewLevel", l)
		end
		player:SetAttribute(string.format("Lane3SpeedwayPreviewLevel_Plot%02d", h), l)
	end
	down.Activated:Connect(function()
		setLevel(levelOf(home()) - 1)
	end)
	up.Activated:Connect(function()
		setLevel(levelOf(home()) + 1)
	end)
	plotButton.Activated:Connect(function()
		player:SetAttribute("Lane3SpeedwayPreviewHome", home() % plotCount + 1)
	end)
	allButton.Activated:Connect(function()
		if player:GetAttribute("Lane3SpeedwayPreviewLevel") ~= nil then
			player:SetAttribute("Lane3SpeedwayPreviewLevel", nil)
		else
			player:SetAttribute("Lane3SpeedwayPreviewLevel", levelOf(home()))
		end
	end)
	ghostButton.Activated:Connect(function()
		player:SetAttribute("Lane3SpeedwayGhost", player:GetAttribute("Lane3SpeedwayGhost") == false)
	end)
	calmButton.Activated:Connect(function()
		player:SetAttribute(
			"Lane3ReducedMotionOverride",
			not (player:GetAttribute("Lane3ReducedMotionOverride") == true)
		)
	end)
	hideButton.Activated:Connect(function()
		player:SetAttribute("Lane3SpeedwayPreviewPanel", false)
	end)
	local connections = {
		player.AttributeChanged:Connect(function(name)
			if name == "Lane3SpeedwayPreviewPanel" then
				screen.Enabled = player:GetAttribute(name) ~= false
			end
			refresh()
		end),
	}
	screen.Enabled = player:GetAttribute("Lane3SpeedwayPreviewPanel") ~= false
	screen.Parent = player:WaitForChild("PlayerGui")
	refresh()
	return function()
		for _, c in connections do
			c:Disconnect()
		end
		screen:Destroy()
	end, refresh
end

return PreviewPanel
