--!strict
-- Round 7 (A-04, decision 0042 item 5): the island board that showed Stunt Circuit times is now RICHEST RACERS: the top ten Cash
-- totals of the players in THIS server, live, your own row highlighted, avatar headshots, Cash in the game's K/M/B/T format, and
-- "This server" in small text. It reads only the server's RichestRacers attribute (BetaEconomy.publishRichest): real players
-- only, unused rows blank, never an invented name. Beta only (the attribute exists only where the beta server runs).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local BetaConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Beta"):WaitForChild("BetaConfig"))
if not BetaConfig.enabled() then
	return
end
local Format = require(ReplicatedStorage.Shared:WaitForChild("UI"):WaitForChild("Format"))

local player = Players.LocalPlayer
local GOLD = Color3.fromRGB(255, 196, 46)
local HIGHLIGHT = Color3.fromRGB(255, 232, 150)

local env = Workspace:WaitForChild("Lane3_IslandEnvironment", 60)
local destinations = env and env:WaitForChild("Destinations", 30)
local stand = destinations and destinations:WaitForChild("LeaderboardStunt", 30)
local face = stand and stand:WaitForChild("SignFace_Leaderboard", 30)
local surface = face and face:WaitForChild("Face", 30)
local board = surface and surface:WaitForChild("Board", 30)
local net = ReplicatedStorage:WaitForChild(BetaConfig.NetName, 60)
if not (board and net) then
	return
end

local function set(path: { string }, text: string)
	local node: Instance? = board
	for _, name in path do
		node = node and node:FindFirstChild(name)
	end
	if node and node:IsA("TextLabel") then
		node.Text = text
	end
end

-- the header and column labels once
set({ "Header", "Side" }, "RICHEST RACERS")
set({ "Header", "Letters" }, "RICHEST RACERS")
set({ "Labels", "Value" }, "CASH")
local labels = board:FindFirstChild("Labels")
local preview = labels and labels:FindFirstChild("PreviewTag")
if preview and preview:IsA("GuiObject") then
	preview.Visible = false
end
local pill = labels and labels:FindFirstChild("WeeklyPill")
if pill then
	for _, d in pill:GetDescendants() do
		if d:IsA("TextLabel") then
			d.Text = "This server"
		end
	end
end

-- each row keeps its own look; a headshot goes in front of the name, the original colours are kept for the highlight's undo
type Row = { frame: Frame, name: TextLabel?, value: TextLabel?, face: ImageLabel, colour: Color3, transparency: number }
local rows: { Row } = {}
for i = 1, BetaConfig.RichestRows do
	local frame = board:FindFirstChild("Row" .. i)
	if frame and frame:IsA("Frame") then
		local name = frame:FindFirstChild("Name")
		local value = frame:FindFirstChild("Value")
		local faceImg = Instance.new("ImageLabel")
		faceImg.Name = "Headshot"
		faceImg.BackgroundTransparency = 1
		faceImg.AnchorPoint = Vector2.new(1, 0.5)
		faceImg.SizeConstraint = Enum.SizeConstraint.RelativeYY
		faceImg.Size = UDim2.fromScale(0.86, 0.86)
		if name and name:IsA("TextLabel") then
			faceImg.Position = UDim2.new(name.Position.X.Scale, name.Position.X.Offset - 4, 0.5, 0)
		end
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(1, 0)
		corner.Parent = faceImg
		faceImg.Parent = frame
		table.insert(rows, {
			frame = frame,
			name = if name and name:IsA("TextLabel") then name else nil,
			value = if value and value:IsA("TextLabel") then value else nil,
			face = faceImg,
			colour = frame.BackgroundColor3,
			transparency = frame.BackgroundTransparency,
		})
	end
end

local function refresh()
	local text = net:GetAttribute(BetaConfig.RichestAttribute)
	local entries = {}
	if type(text) == "string" then
		for chunk in string.gmatch(text, "[^;]+") do
			local id, name, cash = string.match(chunk, "^(%d+)|([^|]*)|(%d+)$")
			if id then
				table.insert(entries, { userId = tonumber(id) :: number, name = name, cash = tonumber(cash) :: number })
			end
		end
	end
	for i, row in rows do
		local e = entries[i]
		if row.name then
			row.name.Text = if e then e.name :: string else ""
		end
		if row.value then
			row.value.Text = if e then Format.cash(e.cash) else ""
		end
		row.face.Visible = e ~= nil
		if e then
			row.face.Image = string.format("rbxthumb://type=AvatarHeadShot&id=%d&w=150&h=150", e.userId)
		end
		local mine = e ~= nil and e.userId == player.UserId
		row.frame.BackgroundColor3 = if mine then HIGHLIGHT else row.colour
		row.frame.BackgroundTransparency = if mine then 0 else row.transparency
		if row.name then
			row.name.TextColor3 = if mine then Color3.fromRGB(24, 36, 72) else row.name.TextColor3
		end
		local stroke = row.frame:FindFirstChild("MineStroke")
		if mine and not stroke then
			local s = Instance.new("UIStroke")
			s.Name = "MineStroke"
			s.Color = GOLD
			s.Thickness = 4
			s.Parent = row.frame
		elseif not mine and stroke then
			stroke:Destroy()
		end
	end
end

net:GetAttributeChangedSignal(BetaConfig.RichestAttribute):Connect(refresh)
refresh()
