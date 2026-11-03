--!strict
-- Whose Raceway is this? (Lane 3; Adam: "a transparent picture of my avatar above the raceway".) A see-through picture of the owner's
-- avatar floats over each owned plot, with their name under it, so every player can tell the Raceways apart. It reads only the plot's
-- replicated Owner and OwnerDisplayName attributes (set by the server) and changes nothing. An empty plot shows nothing.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local Trove = require(game:GetService("ReplicatedStorage").Packages.Trove)

local HEIGHT = 46 -- studs above the plot's centre, over the Raceway's signs
local PICTURE = 30 -- studs
local SEE_THROUGH = 0.3
local SHOW_WITHIN = 420 -- studs

local trove = Trove.new()

local function watch(plot: Model)
	local board: BillboardGui? = nil

	local function clear()
		if board then
			board:Destroy()
			board = nil
		end
	end

	local function refresh()
		clear()
		local owner = plot:GetAttribute("Owner")
		if type(owner) ~= "number" then
			return
		end
		local gui = Instance.new("BillboardGui")
		gui.Name = "Lane3PlotOwner"
		gui.Adornee = plot.PrimaryPart or plot:FindFirstChildWhichIsA("BasePart", true)
		gui.Size = UDim2.fromScale(PICTURE, PICTURE + 5)
		gui.StudsOffsetWorldSpace = Vector3.new(0, HEIGHT, 0)
		gui.MaxDistance = SHOW_WITHIN
		gui.LightInfluence = 0
		gui.ResetOnSpawn = false

		local picture = Instance.new("ImageLabel")
		picture.Name = "Avatar"
		picture.BackgroundTransparency = 1
		picture.Image = ("rbxthumb://type=Avatar&id=%d&w=420&h=420"):format(owner)
		picture.ImageTransparency = SEE_THROUGH
		picture.Size = UDim2.fromScale(1, 0.86)
		picture.Parent = gui

		local name = Instance.new("TextLabel")
		name.Name = "OwnerName"
		name.BackgroundTransparency = 1
		name.AnchorPoint = Vector2.new(0.5, 1)
		name.Position = UDim2.fromScale(0.5, 1)
		name.Size = UDim2.fromScale(1, 0.14)
		name.Font = Enum.Font.FredokaOne
		name.TextScaled = true
		name.TextColor3 = Color3.new(1, 1, 1)
		name.TextStrokeTransparency = 0.2
		local display = plot:GetAttribute("OwnerDisplayName")
		name.Text = if type(display) == "string" then display else "" -- Roblox display names are already text-filtered
		name.Parent = gui

		gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
		board = gui
	end

	trove:Connect(plot:GetAttributeChangedSignal("Owner"), refresh)
	trove:Connect(plot:GetAttributeChangedSignal("OwnerDisplayName"), refresh)
	trove:Add(clear)
	refresh()
end

local root = Workspace:WaitForChild("Lane3_IslandPreview", 60)
local island = root and root:WaitForChild("Island", 30)
local plots = island and island:WaitForChild("Plots", 30)
if plots then
	for _, plot in plots:GetChildren() do
		if plot:IsA("Model") then
			watch(plot)
		end
	end
	trove:Connect(plots.ChildAdded, function(plot: Instance)
		if plot:IsA("Model") then
			watch(plot)
		end
	end)
end
