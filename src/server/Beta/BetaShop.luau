--!strict
-- BETA-ONLY STAND-IN for Brian L's Shop (src/server/EconomyPreview/Shop.luau on feature/lane2-economy-preview).
-- Same contract: BuyRacewayLevel and BuyParkingSpot take no arguments, UnlockWorld takes a World id; the server prices.
-- Delete when his real module lands.
--
-- Round 5 (L-05, decision 0039): purchases charge Cash at the PREVIEW prices of src/shared/UI/EconomyPreview, unless the
-- Studio test switch CarHopBeta.FreePurchases is on. Each request is checked (save loaded, plot, cooldown, the limit, the
-- price, for a World the cars owned from the World before) and changed with no yield in between, so a double click can
-- never go below $0 or past a limit. Every request gets one BetaResult reply: what, ok, the reason line, the missing Cash.
-- Also here: the tutorial-done flag, which pays the one-time PREVIEW tutorial bonus on its false -> true change only.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BetaConfig = require(ReplicatedStorage.Shared.Beta.BetaConfig)
local BetaData = require(script.Parent.BetaData)
local BetaEconomy = require(script.Parent.BetaEconomy)
local BetaEvents = require(script.Parent.BetaEvents)
local BetaLineup = require(script.Parent.BetaLineup)
local BetaPlots = require(script.Parent.BetaPlots)
local EconomyPreview = require(ReplicatedStorage.Shared.UI.EconomyPreview)
local Ladder = require(ReplicatedStorage.Shared.Island.Speedway.Ladder)
local Parking = require(ReplicatedStorage.Shared.Island.Speedway.Parking)
local RosterFixtures = require(ReplicatedStorage.Shared.UI.RosterFixtures)

local BetaShop = {}

local COOLDOWN = 0.75 -- seconds between purchases per player (the panel also locks BUY until the reveal ends)

local lastBuy: { [Player]: number } = {}
local resultRemote: RemoteEvent? = nil

local function reply(player: Player, what: string, ok: boolean, reason: string?, missing: number?)
	if resultRemote then
		resultRemote:FireClient(player, what, ok, reason, missing)
	end
	if not ok then
		print(string.format("[CarHopBeta] %s refused for %s (%d): %s", what, player.Name, player.UserId, reason or "?"))
	else
		BetaEvents.fire(player, what) -- Round 6 (G-01): the purchase went through
	end
end

local function cooled(player: Player): boolean
	local now = os.clock()
	if now - (lastBuy[player] or -math.huge) < COOLDOWN then
		return false
	end
	lastBuy[player] = now
	return true
end

-- The handlers, apart from the remotes so a test can call them. Each returns ok, the reason and the missing Cash.
function BetaShop.buyRacewayLevel(player: Player): (boolean, string?, number?)
	local data = BetaData.get(player)
	if not (data and BetaPlots.plotOf(player)) then
		return false, "Your save is still loading.", nil
	end
	if data.RacewayLevel >= Ladder.MaxLevel then
		return false, "Your Raceway is at the top level.", nil
	end
	local price = EconomyPreview.racewayPrice(data.RacewayLevel + 1)
	if not price then
		return false, "Not for sale.", nil
	end
	local paid, missing = BetaEconomy.trySpend(player, price)
	if not paid then
		return false, "Not enough Cash.", missing
	end
	data.RacewayLevel = Ladder.clamp(data.RacewayLevel + 1)
	BetaPlots.publish(player)
	BetaLineup.publish(player)
	return true, nil, nil
end

function BetaShop.buyParkingSpot(player: Player): (boolean, string?, number?)
	local data = BetaData.get(player)
	if not (data and BetaPlots.plotOf(player)) then
		return false, "Your save is still loading.", nil
	end
	if data.ParkingSpots >= Parking.MaxSpots then
		return false, "All spots are bought.", nil
	end
	local price = EconomyPreview.spotPrice(data.ParkingSpots + 1)
	if not price then
		return false, "Not for sale.", nil
	end
	local paid, missing = BetaEconomy.trySpend(player, price)
	if not paid then
		return false, "Not enough Cash.", missing
	end
	data.ParkingSpots = Parking.clamp(data.ParkingSpots + 1)
	BetaPlots.publish(player)
	return true, nil, nil
end

-- Stamina Shop (Adam, 2026-11-05): the server reads the level the save has, prices the next one and raises it by one.
function BetaShop.publishStamina(player: Player, data: BetaData.Data)
	player:SetAttribute(BetaConfig.StaminaAttribute, data.StaminaLevel)
end

function BetaShop.buyStaminaLevel(player: Player): (boolean, string?, number?)
	local data = BetaData.get(player)
	if not data then
		return false, "Your save is still loading.", nil
	end
	if data.StaminaLevel >= EconomyPreview.StaminaMaxLevel then
		return false, "Your Stamina is at the top level.", nil
	end
	local price = EconomyPreview.staminaPrice(data.StaminaLevel + 1)
	if not price then
		return false, "Not for sale.", nil
	end
	local paid, missing = BetaEconomy.trySpend(player, price)
	if not paid then
		return false, "Not enough Cash.", missing
	end
	data.StaminaLevel = math.min(data.StaminaLevel + 1, EconomyPreview.StaminaMaxLevel)
	BetaShop.publishStamina(player, data)
	print(string.format("[CarHopBeta] %s bought Stamina level %d", player.Name, data.StaminaLevel))
	return true, nil, nil
end

-- Base models the save owns from a World (any edition counts once).
function BetaShop.carsFrom(data: BetaData.Data, world: string): number
	local n = 0
	for id in data.Cars do
		local car = RosterFixtures.byId(id)
		if car and car.world == world then
			n += 1
		end
	end
	return n
end

function BetaShop.unlockWorld(player: Player, world: any): (boolean, string?, number?)
	local data = BetaData.get(player)
	if not data then
		return false, "Your save is still loading.", nil
	end
	local rule = if type(world) == "string" then EconomyPreview.WorldUnlock[world] else nil
	if not rule then
		return false, "That World isn't known.", nil
	end
	if data.WorldsUnlocked[world] then
		return true, nil, nil -- already open: a retry is not charged again
	end
	if not data.WorldsUnlocked[rule.from] then
		return false, "Open " .. RosterFixtures.WorldNames[rule.from] .. " first.", nil
	end
	local have = BetaShop.carsFrom(data, rule.from)
	if have < rule.cars then
		return false,
			string.format("Catch %d more cars in %s.", rule.cars - have, RosterFixtures.WorldNames[rule.from]),
			nil
	end
	local paid, missing = BetaEconomy.trySpend(player, rule.cash)
	if not paid then
		return false, "Not enough Cash.", missing
	end
	data.WorldsUnlocked[world] = true
	BetaEconomy.publishWorlds(player, data)
	print(string.format("[CarHopBeta] %s unlocked %s", player.Name, world))
	return true, nil, nil
end

function BetaShop.start(net: Folder)
	local function remote(name: string): RemoteEvent
		local r = Instance.new("RemoteEvent")
		r.Name = name
		r.Parent = net
		return r
	end
	resultRemote = remote(BetaConfig.Remotes.Result)
	local buyLevel = remote(BetaConfig.Remotes.BuyRacewayLevel)
	local buySpot = remote(BetaConfig.Remotes.BuyParkingSpot)
	local unlock = remote(BetaConfig.Remotes.UnlockWorld)
	local tutorialDone = remote(BetaConfig.Remotes.TutorialDone)
	local buyStamina = remote(BetaConfig.Remotes.BuyStaminaLevel)

	-- the tutorial is for first-time players: the client reads this attribute, and says when it is over. No arguments,
	-- and it can only ever set the caller's own flag to true. The PREVIEW bonus is paid on the change only.
	BetaData.Loaded:Connect(function(player: Player, data: BetaData.Data)
		player:SetAttribute(BetaConfig.TutorialDoneAttribute, data.TutorialDone == true)
		BetaShop.publishStamina(player, data)
	end)
	tutorialDone.OnServerEvent:Connect(function(player: Player)
		local data = BetaData.get(player)
		if data and data.TutorialDone ~= true then
			data.TutorialDone = true
			player:SetAttribute(BetaConfig.TutorialDoneAttribute, true)
			player:SetAttribute(BetaConfig.HoldClaimsAttribute, nil)
			BetaEconomy.addCash(player, EconomyPreview.TutorialBonus, "Tutorial bonus (PREVIEW, once)")
		end
	end)

	local function handle(what: string, fn: (Player) -> (boolean, string?, number?))
		return function(player: Player)
			if not cooled(player) then
				reply(player, what, false, "One moment, try again.", nil)
				return
			end
			local ok, reason, missing = fn(player)
			reply(player, what, ok, reason, missing)
		end
	end
	buyLevel.OnServerEvent:Connect(handle("BuyRacewayLevel", BetaShop.buyRacewayLevel))
	buySpot.OnServerEvent:Connect(handle("BuyParkingSpot", BetaShop.buyParkingSpot))
	buyStamina.OnServerEvent:Connect(handle("BuyStaminaLevel", BetaShop.buyStaminaLevel))
	unlock.OnServerEvent:Connect(function(player: Player, world: any)
		handle("UnlockWorld", function(p: Player)
			return BetaShop.unlockWorld(p, world)
		end)(player)
	end)
	Players.PlayerRemoving:Connect(function(player: Player)
		lastBuy[player] = nil
	end)
end

-- From the command bar in a Studio Play server (works on the player's live save, then puts it back).
function BetaShop.selfTest(player: Player): { string }
	local lines: { string } = {}
	local function expect(name: string, got: any, want: any)
		table.insert(
			lines,
			string.format(
				"%s %s: got %s, want %s",
				if got == want then "PASS" else "FAIL",
				name,
				tostring(got),
				tostring(want)
			)
		)
	end
	local data = BetaData.get(player)
	if not data then
		return { "FAIL no save loaded" }
	end
	local saved = {
		Cash = data.Cash,
		Spots = data.ParkingSpots,
		Level = data.RacewayLevel,
		Worlds = data.WorldsUnlocked,
		Stamina = data.StaminaLevel,
	}
	local config = ReplicatedStorage:FindFirstChild(BetaConfig.MarkerName) :: Instance
	local free = config:GetAttribute(BetaConfig.FreePurchasesAttribute)
	config:SetAttribute(BetaConfig.FreePurchasesAttribute, false)
	data.ParkingSpots = 2
	data.Cash = 499
	local ok, why, missing = BetaShop.buyParkingSpot(player)
	expect("spot 3 at $499 is refused", ok, false)
	expect("refusal names the missing $1", missing, 1)
	expect("refusal reason", why, "Not enough Cash.")
	data.Cash = 500
	ok = BetaShop.buyParkingSpot(player)
	expect("spot 3 at $500 is bought", ok, true)
	expect("Cash is now $0", data.Cash, 0)
	ok = BetaShop.buyParkingSpot(player)
	expect("a repeat with $0 is refused (no negative balance)", ok == false and data.Cash == 0, true)
	data.ParkingSpots = Parking.MaxSpots
	data.Cash = 1e15
	ok, why = BetaShop.buyParkingSpot(player)
	expect("past the spot limit is refused", why, "All spots are bought.")
	data.WorldsUnlocked = { Downtown = true }
	data.Cash = 1e15
	ok, why = BetaShop.unlockWorld(player, "SummitPass")
	expect("Summit before Dusty is refused", ok, false)
	ok, why = BetaShop.unlockWorld(player, "Nowhere")
	expect("an unknown World is refused", why, "That World isn't known.")
	local cars = BetaShop.carsFrom(data, "Downtown")
	ok, why = BetaShop.unlockWorld(player, "DustyHighway")
	if cars < 5 then
		expect("Dusty needs 5 Downtown cars", ok, false)
	else
		expect("Dusty with 5 Downtown cars and Cash", ok, true)
		local before = data.Cash
		ok = BetaShop.unlockWorld(player, "DustyHighway")
		expect("an unlock retry is not charged again", ok and data.Cash == before, true)
	end
	-- Stamina Shop
	data.StaminaLevel = 0
	data.Cash = 999
	ok, why, missing = BetaShop.buyStaminaLevel(player)
	expect("stamina 1 at $999 is refused", ok, false)
	expect("stamina refusal names the missing $1", missing, 1)
	data.Cash = 1000
	ok = BetaShop.buyStaminaLevel(player)
	expect("stamina 1 at $1,000 is bought", ok and data.StaminaLevel == 1 and data.Cash == 0, true)
	expect("stamina attribute follows", player:GetAttribute(BetaConfig.StaminaAttribute), 1)
	ok = BetaShop.buyStaminaLevel(player)
	expect("a stamina repeat with $0 is refused", ok == false and data.StaminaLevel == 1 and data.Cash == 0, true)
	data.StaminaLevel = EconomyPreview.StaminaMaxLevel
	data.Cash = 1e15
	ok, why = BetaShop.buyStaminaLevel(player)
	expect("past the top stamina level is refused", why, "Your Stamina is at the top level.")
	expect("a refused top buy charges nothing", data.Cash, 1e15)
	config:SetAttribute(BetaConfig.FreePurchasesAttribute, true)
	data.Cash = 0
	data.ParkingSpots = 2
	ok = BetaShop.buyParkingSpot(player)
	expect("FreePurchases buys with $0", ok and data.Cash == 0, true)
	config:SetAttribute(BetaConfig.FreePurchasesAttribute, free)
	data.Cash, data.ParkingSpots, data.RacewayLevel, data.WorldsUnlocked, data.StaminaLevel =
		saved.Cash, saved.Spots, saved.Level, saved.Worlds, saved.Stamina
	BetaEconomy.publishCash(player, data)
	BetaShop.publishStamina(player, data)
	BetaEconomy.publishWorlds(player, data)
	BetaPlots.publish(player)
	return lines
end

return BetaShop
