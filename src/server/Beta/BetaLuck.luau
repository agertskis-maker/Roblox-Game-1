--!strict
-- The Luck Station in the Car Hop Beta (Lane 2, Brian L, 2026-11-08; vault/design/specs/luck-station-proposal.md).
-- One server-made stand in the hub. Holding E (or tapping the prompt) buys the next Luck level with the beta's Cash at
-- the PREVIEW prices of src/shared/Catalog/LuckTable. The run then uses that level's multiplier (BetaRun.start).
--
-- No remote: the ProximityPrompt fires on the server, Roblox checks the distance, and the server picks the level and the
-- price itself. Each player sees their own level and next price on a sign only they can see (a BillboardGui in their
-- PlayerGui). A plain stand-in look; Lane 3 owns any real station model.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local BetaConfig = require(ReplicatedStorage.Shared.Beta.BetaConfig)
local BetaData = require(script.Parent.BetaData)
local BetaEconomy = require(script.Parent.BetaEconomy)
local LuckTable = require(ReplicatedStorage.Shared.Catalog.LuckTable)

local BetaLuck = {}

local MARKER_NAME = "LuckStationMarker"
-- Between the HOME portal and the CARS stand in the Car Hop Beta hub (Brian L, Studio Play, 2026-11-05).
local DEFAULT_SPOT = Vector3.new(5982, 1200, 4.5)
local GREEN = Color3.fromRGB(70, 210, 110)
local GOLD = Color3.fromRGB(255, 200, 40)
local COOLDOWN = 0.75 -- seconds between buys per player
local SIGN_NAME = "LuckStationSign"

local lastBuy: { [Player]: number } = {}
local clover: BasePart? = nil

local function short(n: number): string
	local units = { { 1e12, "T" }, { 1e9, "B" }, { 1e6, "M" }, { 1e3, "K" } }
	for _, u in units do
		if n >= u[1] then
			local v = n / u[1]
			local text = if v >= 100 then string.format("%d", math.floor(v)) else string.format("%.3g", v)
			return "$" .. text .. u[2]
		end
	end
	return "$" .. tostring(math.floor(n))
end

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

-- The player's own sign: their level, multiplier and next price, plus the last buy's result line.
local function showSign(player: Player, note: string?)
	local data = BetaData.get(player)
	local gui = player:FindFirstChildOfClass("PlayerGui")
	if not data or not gui or not clover then
		return
	end
	local sign = gui:FindFirstChild(SIGN_NAME)
	if not sign then
		local b = Instance.new("BillboardGui")
		b.Name = SIGN_NAME
		b.ResetOnSpawn = false
		b.Size = UDim2.fromOffset(260, 110)
		b.StudsOffset = Vector3.new(0, 5, 0)
		b.MaxDistance = 120
		b.AlwaysOnTop = false
		local text = Instance.new("TextLabel")
		text.Name = "Text"
		text.Size = UDim2.fromScale(1, 1)
		text.BackgroundTransparency = 1
		text.Font = Enum.Font.FredokaOne
		text.TextScaled = true
		text.TextColor3 = Color3.new(1, 1, 1)
		text.TextStrokeTransparency = 0.2
		text.Parent = b
		b.Parent = gui
		sign = b
	end
	if not sign or not sign:IsA("BillboardGui") then
		return
	end
	sign.Adornee = clover
	local level = data.LuckLevel
	local nextPrice = LuckTable.price(level + 1)
	local lines = {
		"LUCK STATION (PREVIEW)",
		string.format("Level %d/%d  ·  Luck x%.2f", level, LuckTable.MaxLevel, LuckTable.multiplier(level)),
		if nextPrice then "Next level: " .. short(nextPrice) else "Top level!",
	}
	if note then
		table.insert(lines, note)
	end
	local label = sign:FindFirstChild("Text")
	if label and label:IsA("TextLabel") then
		label.Text = table.concat(lines, "\n")
	end
end

local function publish(player: Player, data: BetaData.Data)
	player:SetAttribute(BetaConfig.LuckAttribute, data.LuckLevel)
end

-- Buys one level. Returns ok, the reason line and the missing Cash. Checked and changed with no yield in between, so a
-- double press can never charge twice or go past the top level.
function BetaLuck.buy(player: Player): (boolean, string?, number?)
	local data = BetaData.get(player)
	if not data then
		return false, "Your save is still loading.", nil
	end
	local now = os.clock()
	if now - (lastBuy[player] or -math.huge) < COOLDOWN then
		return false, "One moment, try again.", nil
	end
	lastBuy[player] = now
	if data.LuckLevel >= LuckTable.MaxLevel then
		return false, "Your luck is at the top level.", nil
	end
	local price = LuckTable.price(data.LuckLevel + 1)
	if not price then
		return false, "Not for sale.", nil
	end
	local paid, missing = BetaEconomy.trySpend(player, price)
	if not paid then
		return false, "Not enough Cash.", missing
	end
	data.LuckLevel = LuckTable.clampLevel(data.LuckLevel + 1)
	publish(player, data)
	print(
		string.format(
			"[CarHopBeta] %s bought Luck level %d (x%.2f)",
			player.Name,
			data.LuckLevel,
			LuckTable.multiplier(data.LuckLevel)
		)
	)
	return true, nil, nil
end

-- The run's multiplier for this player (1 when no save is loaded).
function BetaLuck.multiplierFor(player: Player): number
	local data = BetaData.get(player)
	return if data then LuckTable.multiplier(data.LuckLevel) else 1
end

local function build(): Model
	local model = Instance.new("Model")
	model.Name = "LuckStation_PREVIEW"
	local base = spot()
	local pad = block(model, "Pad", Vector3.new(10, 1, 10), base, GREEN)
	pad.Material = Enum.Material.Neon
	pad.Transparency = 0.3
	local post = block(model, "Post", Vector3.new(2, 6, 2), base * CFrame.new(0, 3.5, 0), Color3.fromRGB(40, 48, 70))
	local ball = block(model, "Clover", Vector3.new(3, 3, 3), base * CFrame.new(0, 8, 0), GOLD)
	ball.Shape = Enum.PartType.Ball
	ball.Material = Enum.Material.Neon
	clover = ball

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "BuyLuckPrompt"
	prompt.ActionText = "Buy Luck"
	prompt.ObjectText = "More Rare, Epic and Legendary cars"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0.3
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = post
	prompt.Triggered:Connect(function(player: Player)
		local ok, reason, missing = BetaLuck.buy(player)
		local note = if ok
			then "Bought!"
			elseif missing and missing > 0 then string.format("Need %s more Cash", short(missing))
			else reason
		showSign(player, note)
	end)

	model.PrimaryPart = pad
	model.Parent = Workspace
	return model
end

-- Studio self-test on the player's live test save; puts the save back afterwards. `startRun` is BetaRun.start, passed in
-- so this module does not require BetaRun.
function BetaLuck.selfTest(player: Player, startRun: (Player, any, any) -> any): { string }
	local data = BetaData.get(player)
	if not data then
		return { "FAIL no save loaded for " .. player.Name }
	end
	local lines: { string } = {}
	local function expect(label: string, got: any, want: any)
		table.insert(
			lines,
			string.format(
				"%s %s: got %s, want %s",
				if got == want then "PASS" else "FAIL",
				label,
				tostring(got),
				tostring(want)
			)
		)
	end
	local cfg = ReplicatedStorage:FindFirstChild("CarHopBeta")
	local free = cfg and cfg:GetAttribute(BetaConfig.FreePurchasesAttribute)
	if cfg then
		cfg:SetAttribute(BetaConfig.FreePurchasesAttribute, false)
	end
	local savedCash, savedLevel = data.Cash, data.LuckLevel

	data.LuckLevel, data.Cash = 1, 4_999
	lastBuy[player] = nil
	local ok, why, missing = BetaLuck.buy(player)
	expect("level 2 at $4,999 is refused", ok, false)
	expect("... and names the missing $1", missing, 1)
	expect("... reason", why, "Not enough Cash.")
	data.Cash = 5_000
	lastBuy[player] = nil
	ok = BetaLuck.buy(player)
	expect("level 2 at $5,000 is bought", ok and data.LuckLevel == 2 and data.Cash == 0, true)
	expect("the attribute follows", player:GetAttribute(BetaConfig.LuckAttribute), 2)
	data.Cash = 1_000_000
	ok, why = BetaLuck.buy(player)
	expect("a second press inside the cooldown buys nothing", ok == false and data.LuckLevel == 2, true)
	data.LuckLevel, data.Cash = LuckTable.MaxLevel, 1e15
	lastBuy[player] = nil
	ok, why = BetaLuck.buy(player)
	expect("past level 10 is refused", why, "Your luck is at the top level.")
	expect("... and charges nothing", data.Cash, 1e15)
	expect("level 10 is x2.25", LuckTable.multiplier(LuckTable.MaxLevel), 2.25)
	expect("a NaN level reads as 1", LuckTable.clampLevel(0 / 0), 1)
	expect("a level of 99 reads as 10", LuckTable.clampLevel(99), 10)

	data.LuckLevel = 7
	local run = startRun(player, "Downtown", nil)
	expect("a run started at level 7 carries x1.75", run and run.luck, 1.75)
	expect("... and its traffic was built with it", run and run.sequence and run.sequence.luck, 1.75)
	data.LuckLevel = 1
	run = startRun(player, "Downtown", nil)
	expect("a run at level 1 has no extra luck", run and run.luck, 1)

	data.Cash, data.LuckLevel = savedCash, savedLevel
	publish(player, data)
	lastBuy[player] = nil
	if cfg then
		cfg:SetAttribute(BetaConfig.FreePurchasesAttribute, free)
	end
	return lines
end

function BetaLuck.start()
	build()
	BetaData.Loaded:Connect(function(player: Player, data: BetaData.Data)
		publish(player, data)
		showSign(player, nil)
	end)
	Players.PlayerRemoving:Connect(function(player: Player)
		lastBuy[player] = nil
	end)
end

return BetaLuck
