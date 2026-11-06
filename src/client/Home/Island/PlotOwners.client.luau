--!strict
-- Whose Raceway is this? (Lane 3; Adam: "a transparent picture of my avatar above the raceway".)
-- Round 7 (A-02, Adam: "I see the map from anywhere on the map"): a big floating badge high over each owned plot, with the owner's
-- avatar headshot and username, readable from every point of the island, behind buildings too (AlwaysOnTop). Its size is in
-- pixels (Offset), so a far badge stays readable instead of shrinking to nothing. Your own badge is gold-rimmed and says
-- "YOUR RACEWAY"; other players' badges are white-rimmed. An empty plot shows nothing.
--
-- It reads only the plot's replicated Owner and OwnerDisplayName attributes (set by the server) and changes nothing. The anchors are
-- small client-only parts placed from the plots' own marker positions, so streaming can never take one away. Badges hide while the
-- player is away from the island (on a Launch Pad or in a run), where they would float over the wrong world.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Trove = require(game:GetService("ReplicatedStorage").Packages.Trove)

local HEIGHT = 92 -- studs above the ground, over the middle of the Raceway: above every island building
local MIDDLE = 144 -- studs from the entrance marker to the middle of the Raceway
local SHOW_WITHIN = 4000 -- studs; the island's diagonal is about 700, so every plot shows from every point
local ISLAND_RADIUS = 900 -- the player counts as "on the island" inside this distance of its centre, below ISLAND_TOP
local ISLAND_TOP = 300
local BADGE = Vector2.new(196, 88) -- pixels
local GOLD = Color3.fromRGB(255, 196, 46)
local WHITE = Color3.fromRGB(255, 255, 255)
local NAVY = Color3.fromRGB(24, 36, 72)
local CREAM = Color3.fromRGB(255, 248, 232)
local FONT = Font.new("rbxasset://fonts/families/FredokaOne.json")
local RETRIES = 3

local player = Players.LocalPlayer
local trove = Trove.new()
local boards: { BillboardGui } = {}
local onIsland = true
local function onIslandNow(): boolean
	return onIsland
end

-- Headshots, one fetch per UserId. A placeholder shows until (or unless) Roblox answers.
local headshots: { [number]: string } = {}
local fetching: { [number]: boolean } = {}
local function headshot(userId: number, done: (string) -> ())
	local known = headshots[userId]
	if known then
		done(known)
		return
	end
	if fetching[userId] then
		return
	end
	fetching[userId] = true
	task.spawn(function()
		for attempt = 1, RETRIES do
			local ok, content, ready = pcall(function()
				return Players:GetUserThumbnailAsync(
					userId,
					Enum.ThumbnailType.HeadShot,
					Enum.ThumbnailSize.Size150x150
				)
			end)
			if ok and type(content) == "string" and content ~= "" then
				headshots[userId] = content
				fetching[userId] = nil
				done(content)
				if ready then
					return
				end
			end
			task.wait(attempt * 2)
		end
		fetching[userId] = nil
	end)
end

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

local function make(className: string, props: { [string]: any }, parent: Instance?): any
	local inst = Instance.new(className)
	for k, v in props do
		(inst :: any)[k] = v
	end
	if parent then
		inst.Parent = parent
	end
	return inst
end

local function watch(plot: Model)
	local board: BillboardGui? = nil
	local anchor = make("Part", {
		Name = "Lane3PlotOwnerAnchor",
		Anchored = true,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		Transparency = 1,
		Size = Vector3.one,
	})
	trove:Add(anchor)
	local function clear()
		if board then
			local i = table.find(boards, board)
			if i then
				table.remove(boards, i)
			end
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
		local mine = owner == player.UserId
		local rim = if mine then GOLD else WHITE
		anchor.Position = middleOf(plot)
		anchor.Parent = Workspace
		local gui = make("BillboardGui", {
			Name = "Lane3PlotOwner",
			Adornee = anchor,
			Size = UDim2.fromOffset(BADGE.X, BADGE.Y + (if mine then 22 else 0)),
			MaxDistance = SHOW_WITHIN,
			AlwaysOnTop = true,
			LightInfluence = 0,
			ResetOnSpawn = false,
			ClipsDescendants = false,
		})
		local card = make("Frame", {
			Name = "Badge",
			BackgroundColor3 = NAVY,
			BackgroundTransparency = 0.08,
			Size = UDim2.fromOffset(BADGE.X, BADGE.Y),
		}, gui)
		make("UICorner", { CornerRadius = UDim.new(0, 22) }, card)
		make("UIStroke", { Color = rim, Thickness = if mine then 5 else 3 }, card)
		local ring = make("Frame", {
			Name = "Ring",
			BackgroundColor3 = rim,
			Position = UDim2.fromOffset(8, 8),
			Size = UDim2.fromOffset(BADGE.Y - 16, BADGE.Y - 16),
		}, card)
		make("UICorner", { CornerRadius = UDim.new(1, 0) }, ring)
		local face = make("ImageLabel", {
			Name = "Headshot",
			BackgroundColor3 = CREAM,
			Position = UDim2.fromOffset(4, 4),
			Size = UDim2.new(1, -8, 1, -8),
			Image = "rbxasset://textures/ui/GuiImagePlaceholder.png",
		}, ring)
		make("UICorner", { CornerRadius = UDim.new(1, 0) }, face)
		headshot(owner, function(content: string)
			if face.Parent and plot:GetAttribute("Owner") == owner then -- the plot may have changed hands meanwhile
				face.Image = content
			end
		end)
		local display = plot:GetAttribute("OwnerDisplayName")
		make("TextLabel", {
			Name = "OwnerName",
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(BADGE.Y, 10),
			Size = UDim2.new(1, -BADGE.Y - 10, 1, -20),
			FontFace = FONT,
			TextScaled = true,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = if mine then GOLD else WHITE,
			Text = if type(display) == "string" then display else "", -- Roblox display names are already text-filtered
		}, card)
		if mine then
			local tag = make("TextLabel", {
				Name = "YourRaceway",
				AnchorPoint = Vector2.new(0.5, 0),
				Position = UDim2.new(0.5, 0, 0, BADGE.Y - 4),
				Size = UDim2.fromOffset(150, 26),
				BackgroundColor3 = GOLD,
				FontFace = FONT,
				TextScaled = true,
				TextColor3 = NAVY,
				Text = "YOUR RACEWAY",
			}, gui)
			make("UICorner", { CornerRadius = UDim.new(1, 0) }, tag)
			make("UIPadding", { PaddingTop = UDim.new(0, 3), PaddingBottom = UDim.new(0, 3) }, tag)
		end
		gui.Enabled = onIslandNow()
		gui.Parent = player:WaitForChild("PlayerGui")
		board = gui
		table.insert(boards, gui)
	end

	trove:Connect(plot:GetAttributeChangedSignal("Owner"), refresh)
	trove:Connect(plot:GetAttributeChangedSignal("OwnerDisplayName"), refresh)
	trove:Add(clear)
	refresh()
end

-- Badges only while the player is on the island (not on a Launch Pad far away, and not in a run above it).
local lastCheck = 0
trove:Connect(RunService.Heartbeat, function()
	local now = os.clock()
	if now - lastCheck < 0.25 then
		return
	end
	lastCheck = now
	local character = player.Character
	local r = character and character:FindFirstChild("HumanoidRootPart")
	local here = true
	if r and r:IsA("BasePart") then
		local p = r.Position
		here = Vector2.new(p.X, p.Z).Magnitude < ISLAND_RADIUS and p.Y < ISLAND_TOP
	end
	if here ~= onIsland then
		onIsland = here
		for _, b in boards do
			b.Enabled = here
		end
	end
end)

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
