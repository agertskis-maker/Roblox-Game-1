--!strict
-- Whose Raceway is this? (Lane 3; Adam: "a transparent picture of my avatar above the raceway".) A see-through picture of the owner's
-- avatar floats over each owned plot, with their name under it, so every player can tell the Raceways apart. It reads only the plot's
-- replicated Owner and OwnerDisplayName attributes (set by the server) and changes nothing. An empty plot shows nothing.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local Trove = require(game:GetService("ReplicatedStorage").Packages.Trove)

local HEIGHT = 44 -- studs above the ground, over the middle of the Raceway
local MIDDLE = 144 -- studs from the entrance marker to the middle of the Raceway
local PICTURE = 46 -- studs
local SEE_THROUGH = 0.3
local SHOW_WITHIN = 420 -- studs

local trove = Trove.new()

-- The Raceway runs out from the plot's entrance marker along its bearing. The plot's own bounds grow as the track is built on this
-- client, so they cannot say where the middle is.
local function middleOf(plot: Model): Vector3
	local marker = plot:FindFirstChild("Markers")
	local bearing = plot:GetAttribute("BearingDeg")
	if marker and marker:IsA("BasePart") and type(bearing) == "number" then
		local b = math.rad(bearing)
		return marker.Position + Vector3.new(math.sin(b), 0, -math.cos(b)) * MIDDLE + Vector3.yAxis * HEIGHT
	end
	return plot:GetBoundingBox().Position + Vector3.yAxis * HEIGHT
end
local function watch(plot: Model)
	local board: BillboardGui? = nil
	local anchor = Instance.new("Part")
	anchor.Name = "Lane3PlotOwnerAnchor"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = Vector3.one
	trove:Add(anchor)
	local function clear()
		if board then
			board:Destroy()
			board = nil
		end
		anchor.Parent = nil
	end

	local function refresh()
		clear()
		local owner = plot:GetAttribute("Owner")
		if type(owner) ~= "number" then
			return
		end
		anchor.Position = middleOf(plot)
		anchor.Parent = Workspace
		local gui = Instance.new("BillboardGui")
		gui.Name = "Lane3PlotOwner"
		gui.Adornee = anchor
		gui.Size = UDim2.fromScale(PICTURE, PICTURE + 5)
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
