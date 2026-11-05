--!strict
-- BETA-ONLY STAND-IN for Brian L's Economy (src/server/EconomyPreview/Economy.luau on feature/lane2-economy-preview).
-- Same contract: the server computes every amount from the preview numbers; nothing comes from a client.
-- Delete when his real module lands.
--
-- Cash, cars, editions and the Welcome back credit on the beta save. Function names follow his preview (addCash, trySpend,
-- lapPayFor, lineupPayPerLap, claimCar, joyride, payOffline) so his module drops in one for one. Every number comes from
-- src/shared/UI/EconomyPreview (PREVIEW). State is replicated read-only as player attributes: BetaCash, BetaCars,
-- BetaWorldsUnlocked, BetaLineup (BetaLineup.publish), BetaWelcomeAmount / BetaWelcomeSeconds.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local BetaConfig = require(ReplicatedStorage.Shared.Beta.BetaConfig)
local BetaData = require(script.Parent.BetaData)
local EconomyPreview = require(ReplicatedStorage.Shared.UI.EconomyPreview)
local RosterFixtures = require(ReplicatedStorage.Shared.UI.RosterFixtures)

local BetaEconomy = {}

local WELCOME_MIN_SECONDS = 60 -- Tunable: under a minute away earns nothing and shows no card
-- Seen this server session (memory only, never saved): a rejoin into the same server earns no Welcome back credit.
local seenThisServer: { [string]: boolean } = {}

local function finite(n: number): boolean
	return n == n and n ~= math.huge and n ~= -math.huge
end

function BetaEconomy.publishCash(player: Player, data: BetaData.Data)
	player:SetAttribute(BetaConfig.CashAttribute, data.Cash)
end

function BetaEconomy.publishCars(player: Player, data: BetaData.Data)
	player:SetAttribute(BetaConfig.CarsAttribute, BetaConfig.encodeCars(data.Cars))
end

function BetaEconomy.publishWorlds(player: Player, data: BetaData.Data)
	local worlds = {}
	for _, world in RosterFixtures.Worlds do
		if data.WorldsUnlocked[world] then
			table.insert(worlds, world)
		end
	end
	player:SetAttribute(BetaConfig.WorldsAttribute, table.concat(worlds, ","))
end

-- Round 6 (E-05): the most Cash a save may hold, $1,000 Qa (1e15). Luau numbers stay exact up to about 9e15, so every sum
-- below the cap is exact. Lane 3's proposal for Brian L's "largest Cash value" question; Cash over the cap is not paid.
BetaEconomy.CashCap = 1e15

-- The whole amount that fits under the cap (pure, for the self-test).
function BetaEconomy.capped(cash: number, amount: number): number
	return math.max(0, math.min(math.floor(amount), BetaEconomy.CashCap - cash))
end

-- Adds a whole, positive, finite amount, up to the Cash cap. Returns the amount added (0 when refused or at the cap).
function BetaEconomy.addCash(player: Player, amount: number, reason: string): number
	local data = BetaData.get(player)
	if not data or not finite(amount) or amount <= 0 then
		return 0
	end
	local whole = BetaEconomy.capped(data.Cash, amount)
	if whole < math.floor(amount) then
		print(
			string.format("[CarHopBeta] %s is at the Cash cap: $%d of $%d paid", player.Name, whole, math.floor(amount))
		)
	end
	data.Cash += whole
	BetaEconomy.publishCash(player, data)
	if reason ~= "Lap" then
		print(string.format("[CarHopBeta] %s +$%d (%s), Cash $%d", player.Name, whole, reason, data.Cash))
	end
	return whole
end

-- Takes `price` if the player can afford it; returns whether it was paid and, when not, the missing amount.
-- Free when the Studio test switch FreePurchases is on. No yield between the check and the change.
function BetaEconomy.trySpend(player: Player, price: number): (boolean, number)
	local data = BetaData.get(player)
	if not data or not finite(price) or price < 0 then
		return false, 0
	end
	local config = ReplicatedStorage:FindFirstChild(BetaConfig.MarkerName)
	if config and config:GetAttribute(BetaConfig.FreePurchasesAttribute) == true then
		return true, 0
	end
	if data.Cash < price then
		return false, price - data.Cash
	end
	data.Cash -= price
	BetaEconomy.publishCash(player, data)
	return true, 0
end

function BetaEconomy.lapPayOf(data: BetaData.Data, id: string): number
	local car = RosterFixtures.byId(id)
	local save = data.Cars[id]
	if not car or not save then
		return 0
	end
	return math.floor(EconomyPreview.lapPay(car.rarity, save.Edition, data.RacewayLevel, car.world))
end

function BetaEconomy.lapPayFor(player: Player, id: string): number
	local data = BetaData.get(player)
	return if data then BetaEconomy.lapPayOf(data, id) else 0
end

function BetaEconomy.lineupPayOf(data: BetaData.Data): number
	local total = 0
	for _, id in data.Lineup do
		total += BetaEconomy.lapPayOf(data, id)
	end
	return total
end

function BetaEconomy.lineupPayPerLap(player: Player): number
	local data = BetaData.get(player)
	return if data then BetaEconomy.lineupPayOf(data) else 0
end

export type Grant = {
	kind: string, -- "claim" | "joyride"
	carId: string,
	amount: number,
	edition: number,
	copies: number,
	rose: boolean, -- the edition went up
}

-- The pure decision for one accepted KeysComplete, on a save table: unowned = claim (new car at Normal, 0 copies, plus the
-- rarity's claim bonus), owned = Joyride (one copy on the edition ladder, plus the Joyride Bonus at the car's edition).
function BetaEconomy.keysOutcome(data: BetaData.Data, carId: string): Grant?
	local car = RosterFixtures.byId(carId)
	if not car then
		return nil
	end
	local save = data.Cars[carId]
	if save == nil then
		data.Cars[carId] = { Edition = 1, Copies = 0 }
		local bonus = math.floor(EconomyPreview.claimBonus(car.rarity, car.world))
		return { kind = "claim", carId = carId, amount = bonus, edition = 1, copies = 0, rose = false }
	end
	-- Round 6: the Joyride Bonus carries the car's World factor; Copies is the lifetime total (EconomyPreview.addCopy)
	local amount = math.floor(EconomyPreview.joyrideBonus(car.rarity, save.Edition, car.world))
	local edition, copies, rose = EconomyPreview.addCopy(save.Edition, save.Copies)
	save.Edition, save.Copies = edition, copies
	return { kind = "joyride", carId = carId, amount = amount, edition = edition, copies = copies, rose = rose }
end

-- The Welcome back credit for a save loaded with `priorLastSeen` at Unix time `now` (pure; L-06).
function BetaEconomy.welcomeCredit(data: BetaData.Data, priorLastSeen: number, now: number): (number, number)
	if priorLastSeen <= 0 then
		return 0, 0 -- never stamped (a new or pre-Round 5 save): no invented absence
	end
	local away = now - priorLastSeen
	if away < WELCOME_MIN_SECONDS then
		return 0, math.max(away, 0) -- also covers a clock in the future (negative)
	end
	return EconomyPreview.offlineCredit(BetaEconomy.lineupPayOf(data), away), away
end

-- On load: pays the Welcome back credit and stamps LastSeen in one step (no yield), BEFORE the card can show.
function BetaEconomy.payOffline(player: Player, data: BetaData.Data, priorLastSeen: number)
	local now = os.time()
	local key = BetaData.keyOf(player)
	local amount, away = 0, 0
	if not seenThisServer[key] then
		amount, away = BetaEconomy.welcomeCredit(data, priorLastSeen, now)
	end
	seenThisServer[key] = true
	amount = BetaEconomy.capped(data.Cash, amount)
	if amount > 0 then
		data.Cash += amount
		print(string.format("[CarHopBeta] %s Welcome back +$%d for %d s away", player.Name, amount, away))
	end
	data.LastSeen = now
	player:SetAttribute(BetaConfig.WelcomeAmountAttribute, amount)
	player:SetAttribute(BetaConfig.WelcomeSecondsAttribute, if amount > 0 then away else 0)
end

function BetaEconomy.start()
	BetaData.Loaded:Connect(function(player: Player, data: BetaData.Data, priorLastSeen: number)
		BetaEconomy.payOffline(player, data, priorLastSeen)
		BetaEconomy.publishCash(player, data)
		BetaEconomy.publishCars(player, data)
		BetaEconomy.publishWorlds(player, data)
	end)
	-- the Studio-only cash cheat (L-07): a SERVER-side attribute, ignored outside Studio
	local function watchCheat(player: Player)
		player:GetAttributeChangedSignal(BetaConfig.GrantCashAttribute):Connect(function()
			local n = player:GetAttribute(BetaConfig.GrantCashAttribute)
			if n == nil then
				return
			end
			player:SetAttribute(BetaConfig.GrantCashAttribute, nil)
			if RunService:IsStudio() and type(n) == "number" then
				BetaEconomy.addCash(player, n, "BetaGrantCash (Studio cheat)")
			end
		end)
	end
	for _, player in Players:GetPlayers() do
		watchCheat(player)
	end
	Players.PlayerAdded:Connect(watchCheat)
end

-- From the command bar: print(require(game.ServerScriptService.Server.Beta.BetaEconomy).selfTest())
function BetaEconomy.selfTest(): { string }
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
	local function save(): BetaData.Data
		return {
			RacewayLevel = 1,
			ParkingSpots = 2,
			TutorialDone = true,
			Cars = { Putter = { Edition = 1, Copies = 0 }, Executive = { Edition = 2, Copies = 0 } },
			Lineup = { "Putter", "Executive" },
			Cash = 0,
			WorldsUnlocked = { Downtown = true },
			LastSeen = 0,
		}
	end
	local d = save()
	expect("Lap Pay Putter L1", BetaEconomy.lapPayOf(d, "Putter"), 10)
	expect("Lap Pay Executive Gold L1", BetaEconomy.lapPayOf(d, "Executive"), 450)
	d.RacewayLevel = 2
	expect("Lap Pay Putter L2 (x1.9, floored)", BetaEconomy.lapPayOf(d, "Putter"), 19)
	expect("Lap Pay unowned", BetaEconomy.lapPayOf(d, "Bolt"), 0)
	-- E-01: a World's car pays its World factor (Thunder is Dusty Highway's Rare: $60 x 40 x 3.5 at level 3)
	d.RacewayLevel = 3
	d.Cars.Thunder = { Edition = 1, Copies = 0 }
	expect("E-01 Dusty Highway Rare L3", BetaEconomy.lapPayOf(d, "Thunder"), 8400)
	d = save()
	expect("Lineup pay per lap", BetaEconomy.lineupPayOf(d), 460)
	-- the edition ladder (lifetime Copies, E-02)
	d = save()
	local g = BetaEconomy.keysOutcome(d, "Minnow") :: Grant
	expect("new model is a claim", g.kind, "claim")
	expect("claim bonus Uncommon (10x $25)", g.amount, 250)
	g = BetaEconomy.keysOutcome(d, "Minnow") :: Grant
	expect("second of a model is a joyride", g.kind .. g.copies, "joyride1")
	expect("joyride bonus Uncommon Normal (3x $25)", g.amount, 75)
	d.Cars.Minnow.Copies = 24
	g = BetaEconomy.keysOutcome(d, "Minnow") :: Grant
	expect(
		"25th copy makes Gold, Copies keeps counting",
		string.format("%d/%d/%s", g.edition, g.copies, tostring(g.rose)),
		"2/25/true"
	)
	g = BetaEconomy.keysOutcome(d, "Minnow") :: Grant
	expect("Gold joyride pays x3", g.amount, 225)
	expect("unknown car", BetaEconomy.keysOutcome(d, "Hyperion"), nil)
	d.Cars.Phantom = { Edition = 1, Copies = 0 }
	g = BetaEconomy.keysOutcome(d, "Phantom") :: Grant
	expect("E-01 Summit Pass Legendary Joyride", g.amount, 1920000)
	d.Cars.Thunder = nil
	g = BetaEconomy.keysOutcome(d, "Thunder") :: Grant
	expect("Dusty Highway Rare claim (10x $60 x 40)", g.amount, 24000)
	-- E-05: the Cash cap
	expect("cap: room left is paid", BetaEconomy.capped(1e15 - 5, 100), 5)
	expect("cap: nothing past the cap", BetaEconomy.capped(1e15, 100), 0)
	expect("cap: below it pays in full", BetaEconomy.capped(0, 1234.9), 1234)
	-- the Welcome back credit
	d = save() -- 460 a lap
	expect("never stamped pays nothing", (BetaEconomy.welcomeCredit(d, 0, 1e9)), 0)
	expect("30 s away pays nothing", (BetaEconomy.welcomeCredit(d, 1e9 - 30, 1e9)), 0)
	expect("future LastSeen pays nothing", (BetaEconomy.welcomeCredit(d, 1e9 + 500, 1e9)), 0)
	expect("1 h away", (BetaEconomy.welcomeCredit(d, 1e9 - 3600, 1e9)), 55200)
	expect("over 8 h is capped", (BetaEconomy.welcomeCredit(d, 1e9 - 86400, 1e9)), 441600)
	d.Lineup = {}
	expect("empty Lineup earns nothing", (BetaEconomy.welcomeCredit(d, 1e9 - 3600, 1e9)), 0)
	-- sanitize
	local bad: any = save()
	bad.Cash = 0 / 0
	bad.WorldsUnlocked = false
	bad.Lineup = { "Putter", "Bolt", "Putter" }
	local fixed = BetaData.sanitize(bad)
	expect("NaN Cash repaired", bad.Cash, 0)
	expect("WorldsUnlocked=false repaired", bad.WorldsUnlocked.Downtown, true)
	expect("unowned and duplicate Lineup entries dropped", table.concat(bad.Lineup, ","), "Putter")
	expect("repairs reported", #fixed >= 3, true)
	local empty: any = save()
	empty.WorldsUnlocked = {}
	BetaData.sanitize(empty)
	expect("empty WorldsUnlocked gains Downtown", empty.WorldsUnlocked.Downtown, true)
	local missing: any = { Cars = { Putter = { Edition = 1, Copies = 0 } }, Lineup = { "Putter" } }
	for k, v in BetaConfig.Template do
		if missing[k] == nil then
			missing[k] = if type(v) == "table" then table.clone(v) else v
		end
	end
	expect("old save gets Cash 0 and LastSeen 0", string.format("%d/%d", missing.Cash, missing.LastSeen), "0/0")
	-- E-02: the one-time Copies conversion (a fresh save and a Round 5 save)
	local fresh: any = save()
	local freshMeta = {}
	expect("fresh save: nothing to convert", BetaData.migrateCopies(fresh, freshMeta), 0)
	expect("fresh save: marker set", freshMeta[BetaData.CopiesMarker], true)
	local r5: any = save() -- Executive Gold with 0 copies at Gold in Round 5's reading
	r5.Cars.Executive.Copies = 12
	r5.Cars.Minnow = { Edition = 1, Copies = 7 }
	local meta = {}
	expect("Round 5 save: one car converted", BetaData.migrateCopies(r5, meta), 1)
	expect("Round 5 Gold 12 becomes 37", r5.Cars.Executive.Copies, 37)
	expect("Round 5 Normal 7 stays 7", r5.Cars.Minnow.Copies, 7)
	expect("never runs twice", BetaData.migrateCopies(r5, meta), 0)
	expect("still 37 after a second load", r5.Cars.Executive.Copies, 37)
	return lines
end

return BetaEconomy
