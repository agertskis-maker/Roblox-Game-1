--!strict
-- Whose Raceway is this? (Lane 3; Adam: "a transparent picture of my avatar above the raceway".)
-- Round 7 (A-02): a badge floating over each owned plot with the owner's avatar headshot and name. Round 8 (H-01, H-02; to
-- R8-IMG-08): the badge is a round headshot in a rim, the name on a cream plate under it, and for YOUR plot a gold ribbon
-- "YOUR RACEWAY". Yours is big and gold-rimmed and draws on top of everything (AlwaysOnTop), readable from every point of the
-- island. Other players' badges are about 58% of its size with a white rim, no ribbon, a little lower in the air, and they are
-- NOT on top of the world: they show from the island centre and fade out beyond OTHERS_FROM studs, so they never shout across the
-- map and can never cover your own badge. An empty plot shows nothing. When a player leaves, the badge goes at once (the server
-- clears the plot's Owner; the leave itself also hides it without waiting for that); a new owner gets a new face, never the old one.
--
-- It reads only the plot's replicated Owner and OwnerDisplayName attributes (set by the server) and changes nothing. The anchors are
-- small client-only parts placed from the plots' own marker positions, so streaming can never take one away. Badges hide while the
-- player is away from the island (on a Launch Pad or in a run), where they would float over the wrong world. The face itself comes
-- from Headshot.luau (H-01: why it was blank, and the fix).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Trove = require(ReplicatedStorage.Packages.Trove)
local Tokens = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UI"):WaitForChild("Tokens"))
local Headshot = require(script.Parent.Headshot)

local HEIGHT_MINE = 92 -- studs above the ground, over the middle of the Raceway: above every island building
local HEIGHT_OTHERS = 82 -- a little lower than yours
local MIDDLE = 144 -- studs from the entrance marker to the middle of the Raceway
local MINE_FROM = 4000 -- yours shows from everywhere on the island (the island's diagonal is about 700)
local OTHERS_FROM = 520 -- studs: the island centre is about 400 from every badge, the plot across the map 700 to 800
local ISLAND_RADIUS = 900 -- the player counts as "on the island" inside this distance of its centre, below ISLAND_TOP
local ISLAND_TOP = 300
local OTHERS_SCALE = 0.58 -- the size of another player's badge against yours
local GOLD_LIGHT = Color3.fromRGB(255, 232, 140)
local GOLD_DEEP = Color3.fromRGB(226, 150, 24)
local WHITE = Color3.fromRGB(255, 255, 255)
local WHITE_SHADE = Color3.fromRGB(214, 224, 242)
local NAVY = Color3.fromRGB(20, 33, 63)
local CREAM = Color3.fromRGB(255, 244, 218)

local player = Players.LocalPlayer
local trove = Trove.new()
local boards: { BillboardGui } = {}
local onIsland = true

-- The pieces of a badge, in pixels at scale 1 (yours). Another player's badge multiplies every number by OTHERS_SCALE.
local AVATAR = 132
local RING = 10
local PLATE = Vector2.new(214, 46)
local PLATE_OVERLAP = 22
local RIBBON = Vector2.new(196, 32)

local function px(n: number, s: number): number
	return math.max(1, math.floor(n * s + 0.5))
end

local function make(className: string, props: { [string]: any }, parent: Instance?): any
	local inst = Instance.new(className)
	if inst:IsA("GuiObject") then
		inst.BorderSizePixel = 0
	end
	for k, v in props do
		(inst :: any)[k] = v
	end
	if parent then
		inst.Parent = parent
	end
	return inst
end

local function outline(parent: Instance, thickness: number, colour: Color3)
	make("UIStroke", { Color = colour, Thickness = thickness, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, parent)
end

-- The RIM: a round ring (gold for yours, white for the others) with the face inside it. Returns the holder the face goes in.
local function avatar(parent: Instance, s: number, mine: boolean): Frame
	local size = px(AVATAR, s)
	local ring = make("Frame", {
		Name = "Ring",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.fromOffset(size, size),
		BackgroundColor3 = WHITE, -- the gradient below gives the colours (a gradient multiplies the fill)
	}, parent)
	make("UICorner", { CornerRadius = UDim.new(1, 0) }, ring)
	outline(ring, px(4, s), NAVY)
	make("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new(if mine then GOLD_LIGHT else WHITE, if mine then GOLD_DEEP else WHITE_SHADE),
	}, ring)
	local inner = px(AVATAR - 2 * RING, s)
	local holder = make("Frame", {
		Name = "Face",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(inner, inner),
		BackgroundColor3 = CREAM,
		BorderSizePixel = 0,
		ClipsDescendants = true,
	}, ring)
	make("UICorner", { CornerRadius = UDim.new(1, 0) }, holder)
	outline(holder, px(3, s), NAVY)
	return holder
end

local function nameLabel(parent: Instance, s: number, text: string): TextLabel
	local label = make("TextLabel", {
		Name = "OwnerName",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(px(12, s), px(3, s)),
		Size = UDim2.new(1, -2 * px(12, s), 1, -2 * px(3, s)),
		FontFace = Tokens.font(),
		TextScaled = true,
		TextColor3 = NAVY,
		Text = text, -- Roblox display names are already text-filtered
	}, parent)
	make("UITextSizeConstraint", { MaxTextSize = px(28, s), MinTextSize = 8 }, label)
	return label
end

local function middleOf(plot: Model, height: number): Vector3
	-- The Raceway runs out from the plot's entrance marker along its bearing. The plot's own bounds grow as the track is built on
	-- this client, so they cannot say where the middle is.
	local marker = plot:FindFirstChild("Markers")
	local bearing = plot:GetAttribute("BearingDeg")
	if marker and marker:IsA("BasePart") and type(bearing) == "number" then
		local b = math.rad(bearing)
		return marker.Position + Vector3.new(math.sin(b), 0, -math.cos(b)) * MIDDLE + Vector3.yAxis * height
	end
	return plot:GetBoundingBox().Position + Vector3.yAxis * height
end

type Shown = { gui: BillboardGui, owner: number, name: string, label: TextLabel, cancelFace: () -> () }

local function watch(plot: Model)
	local shown: Shown? = nil
	local gone: number? = nil -- an owner who has left: no badge for that id until the plot's Owner changes or the player returns
	local anchor = make("Part", {
		Name = "Lane3PlotOwnerAnchor",
		Anchored = true,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		CastShadow = false,
		Transparency = 1,
		Size = Vector3.one,
	})
	trove:Add(anchor)

	local function clear()
		local current = shown
		if current then
			shown = nil
			current.cancelFace()
			local i = table.find(boards, current.gui)
			if i then
				table.remove(boards, i)
			end
			current.gui:Destroy()
		end
		anchor.Parent = nil
	end

	local function build(owner: number, name: string)
		local mine = owner == player.UserId
		local s = if mine then 1 else OTHERS_SCALE
		local avatarSize = px(AVATAR, s)
		local plateW, plateH = px(PLATE.X, s), px(PLATE.Y, s)
		local plateY = avatarSize - px(PLATE_OVERLAP, s)
		local ribbonY = plateY + plateH - px(6, s)
		local width = math.max(avatarSize, plateW) + px(40, s)
		local height = if mine then ribbonY + px(RIBBON.Y, s) + px(8, s) else plateY + plateH + px(4, s)
		anchor.Position = middleOf(plot, if mine then HEIGHT_MINE else HEIGHT_OTHERS)
		anchor.Parent = Workspace
		local gui = make("BillboardGui", {
			Name = "Lane3PlotOwner",
			Adornee = anchor,
			Size = UDim2.fromOffset(width, height),
			MaxDistance = if mine then MINE_FROM else OTHERS_FROM,
			AlwaysOnTop = mine, -- yours draws over everything, so another badge can never cover it
			LightInfluence = 0,
			ResetOnSpawn = false,
			ClipsDescendants = false,
		})
		local root = make("Frame", {
			Name = "Badge",
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.fromScale(0.5, 0),
			Size = UDim2.fromOffset(width, height),
		}, gui)
		local holder = avatar(root, s, mine)
		-- the ribbon's two tails sit behind the plate and the ribbon
		if mine then
			for _, side in { -1, 1 } do
				local tail = make("Frame", {
					Name = "RibbonTail",
					AnchorPoint = Vector2.new(0.5, 0),
					Position = UDim2.new(0.5, side * (px(RIBBON.X, s) / 2 + px(2, s)), 0, ribbonY + px(7, s)),
					Size = UDim2.fromOffset(px(40, s), px(RIBBON.Y - 2, s)),
					BackgroundColor3 = GOLD_DEEP,
					Rotation = side * 6,
				}, root)
				make("UICorner", { CornerRadius = UDim.new(0, px(6, s)) }, tail)
				outline(tail, px(3, s), NAVY)
			end
		end
		local plate = make("Frame", {
			Name = "Plate",
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, plateY),
			Size = UDim2.fromOffset(plateW, plateH),
			BackgroundColor3 = CREAM,
		}, root)
		make("UICorner", { CornerRadius = UDim.new(1, 0) }, plate)
		outline(plate, px(4, s), NAVY)
		local label = nameLabel(plate, s, name)
		if mine then
			local ribbon = make("Frame", {
				Name = "YourRaceway",
				AnchorPoint = Vector2.new(0.5, 0),
				Position = UDim2.new(0.5, 0, 0, ribbonY),
				Size = UDim2.fromOffset(px(RIBBON.X, s), px(RIBBON.Y, s)),
				BackgroundColor3 = WHITE, -- coloured by the gradient below
				ZIndex = 2,
			}, root)
			make("UICorner", { CornerRadius = UDim.new(0, px(8, s)) }, ribbon)
			outline(ribbon, px(3, s), NAVY)
			make("UIGradient", { Rotation = 90, Color = ColorSequence.new(GOLD_LIGHT, GOLD_DEEP) }, ribbon)
			make("TextLabel", {
				BackgroundTransparency = 1,
				Size = UDim2.fromScale(1, 1),
				FontFace = Tokens.font(),
				TextScaled = true,
				TextColor3 = NAVY,
				Text = "YOUR RACEWAY",
				ZIndex = 3,
			}, ribbon)
			make("UIPadding", { PaddingTop = UDim.new(0, 5), PaddingBottom = UDim.new(0, 5) }, ribbon)
		end
		gui.Enabled = onIsland
		gui.Parent = player:WaitForChild("PlayerGui")
		table.insert(boards, gui)
		-- recorded before the face is asked for: a face that is already known arrives at once, inside attach
		local record: Shown = { gui = gui, owner = owner, name = name, label = label, cancelFace = function() end }
		shown = record
		record.cancelFace = Headshot.attach(holder, owner, name, function(): boolean
			-- the plot may have changed hands (or the player left) while the face was on its way
			return shown == record and plot:GetAttribute("Owner") == owner
		end)
	end

	local function refresh()
		local owner = plot:GetAttribute("Owner")
		if type(owner) ~= "number" or owner == gone then
			if type(owner) ~= "number" then
				gone = nil
			end
			clear()
			return
		end
		local display = plot:GetAttribute("OwnerDisplayName")
		local name = if type(display) == "string" then display else ""
		local current = shown
		if current and current.owner == owner then
			-- the same owner (Owner and OwnerDisplayName arrive one after the other): only the name may differ
			if current.name ~= name then
				current.name = name
				current.label.Text = name
			end
			return
		end
		clear()
		build(owner, name)
	end

	trove:Connect(plot:GetAttributeChangedSignal("Owner"), refresh)
	trove:Connect(plot:GetAttributeChangedSignal("OwnerDisplayName"), refresh)
	-- Leaving: the server clears the plot's Owner, but the badge must not wait for that
	trove:Connect(Players.PlayerRemoving, function(leaving: Player)
		if plot:GetAttribute("Owner") == leaving.UserId then
			gone = leaving.UserId
			clear()
		end
	end)
	trove:Connect(Players.PlayerAdded, function(joining: Player)
		if gone == joining.UserId then
			gone = nil
			refresh()
		end
	end)
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
