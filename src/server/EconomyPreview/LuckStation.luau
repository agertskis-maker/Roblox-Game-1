--!strict
-- The Luck Station for the economy PREVIEW (Lane 2): one server-made stand in the hub where a
-- player buys Luck levels with Cash (vault/design/specs/luck-station-proposal.md). A plain
-- stand-in look; Lane 3 owns the real station model and its panel. It goes where Workspace has a
-- part named LuckStationMarker, or else at the spot Brian L picked in the Car Hop Beta hub on
-- 2026-11-05. Price and level text per player are on the player attributes LuckLevel and
-- LuckNextPriceText (Shop.publish); the prompt itself is the same for everyone.

local Workspace = game:GetService("Workspace")

local Shop = require(script.Parent.Shop)

local LuckStation = {}

local MARKER_NAME = "LuckStationMarker"
-- Between the HOME portal and the CARS stand in the Car Hop Beta hub (Brian L, Studio Play).
local DEFAULT_SPOT = Vector3.new(5982, 1200, 4.5)
local GREEN = Color3.fromRGB(70, 210, 110)
local GOLD = Color3.fromRGB(255, 200, 40)

local function block(parent: Instance, name: string, size: Vector3, cframe: CFrame, colour: Color3): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cframe
	p.Color = colour
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function spot(): CFrame
	local marker = Workspace:FindFirstChild(MARKER_NAME, true)
	if marker and marker:IsA("BasePart") then
		return marker.CFrame
	end
	return CFrame.new(DEFAULT_SPOT)
end

function LuckStation.build(): Model
	local model = Instance.new("Model")
	model.Name = "LuckStation_PREVIEW"
	local base = spot()
	local pad = block(model, "Pad", Vector3.new(10, 1, 10), base, GREEN)
	pad.Material = Enum.Material.Neon
	pad.Transparency = 0.3
	local post = block(model, "Post", Vector3.new(2, 6, 2), base * CFrame.new(0, 3.5, 0), Color3.fromRGB(40, 48, 70))
	local clover = block(model, "Clover", Vector3.new(3, 3, 3), base * CFrame.new(0, 8, 0), GOLD)
	clover.Shape = Enum.PartType.Ball
	clover.Material = Enum.Material.Neon

	local sign = Instance.new("BillboardGui")
	sign.Size = UDim2.fromOffset(220, 60)
	sign.StudsOffset = Vector3.new(0, 4, 0)
	sign.MaxDistance = 120
	sign.Parent = clover
	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.Font = Enum.Font.FredokaOne
	text.TextScaled = true
	text.TextColor3 = Color3.new(1, 1, 1)
	text.TextStrokeTransparency = 0.2
	text.Text = "LUCK STATION (PREVIEW)"
	text.Parent = sign

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "BuyLuckPrompt"
	prompt.ActionText = "Buy Luck"
	prompt.ObjectText = "More Rare, Epic and Legendary cars"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = post
	-- Triggered runs on the server; the server picks the price and checks the Cash.
	prompt.Triggered:Connect(function(player: Player)
		Shop.buyLuckLevel(player)
	end)

	model.PrimaryPart = pad
	model.Parent = Workspace
	return model
end

return LuckStation
