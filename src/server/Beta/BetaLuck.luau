--!strict
-- The Luck Shop in the Car Hop Beta (Lane 2, Brian L, 2026-11-08; vault/design/specs/luck-station-proposal.md).
-- The LUCK kiosk on every Launch Pad (Lane 3's PadParts.kiosks) opens the LUCK SHOP card (LaunchPad/LuckPanel). Its BUY
-- fires BuyLuckLevel with no arguments; the server picks the next level and its PREVIEW price (src/shared/Catalog/
-- LuckTable), checks the save, the cooldown, the top level and the Cash, and changes it with no yield in between. Every
-- request gets one BetaResult reply (what, ok, reason, missing Cash), the same as the other shops. The run then uses the
-- level's multiplier (BetaRun.start).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BetaConfig = require(ReplicatedStorage.Shared.Beta.BetaConfig)
local BetaData = require(script.Parent.BetaData)
local BetaEconomy = require(script.Parent.BetaEconomy)
local BetaEvents = require(script.Parent.BetaEvents)
local LuckTable = require(ReplicatedStorage.Shared.Catalog.LuckTable)

local BetaLuck = {}

local COOLDOWN = 0.75 -- seconds between buys per player
local WHAT = "BuyLuckLevel"

local lastBuy: { [Player]: number } = {}

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

-- After BetaShop.start, which makes the BetaResult remote in `net`.
function BetaLuck.start(net: Folder)
	local buyRemote = Instance.new("RemoteEvent")
	buyRemote.Name = BetaConfig.Remotes.BuyLuckLevel
	buyRemote.Parent = net
	local result = net:FindFirstChild(BetaConfig.Remotes.Result)
	-- No arguments are read: whatever a client sends is ignored, and the server decides the level and the price.
	buyRemote.OnServerEvent:Connect(function(player: Player)
		local ok, reason, missing = BetaLuck.buy(player)
		if result and result:IsA("RemoteEvent") then
			result:FireClient(player, WHAT, ok, reason, missing)
		end
		if ok then
			BetaEvents.fire(player, WHAT)
		else
			print(
				string.format(
					"[CarHopBeta] %s refused for %s (%d): %s",
					WHAT,
					player.Name,
					player.UserId,
					reason or "?"
				)
			)
		end
	end)
	BetaData.Loaded:Connect(function(player: Player, data: BetaData.Data)
		publish(player, data)
	end)
	Players.PlayerRemoving:Connect(function(player: Player)
		lastBuy[player] = nil
	end)
end

return BetaLuck
