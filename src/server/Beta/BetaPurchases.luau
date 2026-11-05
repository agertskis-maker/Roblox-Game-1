--!strict
-- BETA-ONLY STAND-IN for Brian L's purchase grants (the Robux table in economy-v1-answers-from-adam.md).
-- Same contract: the server grants every Robux item inside ProcessReceipt, once per receipt, from server data only.
-- Delete when his real module lands.
--
-- Round 6 (R-02, Adam's decisions of 2026-11-05, brief section 0 items 6 and 7). The ONE MarketplaceService.ProcessReceipt
-- handler of the beta (create.roblox.com/docs/reference/engine/classes/MarketplaceService, read 2026-11-05; notes in
-- vault/design/specs/robux-api-notes.md):
--   * the player is not in this server, or their save is not loaded yet       -> NotProcessedYet (nothing granted)
--   * the receipt's PurchaseId is already in the save's `Purchases`             -> PurchaseGranted (nothing granted again)
--   * an unknown ProductId                                                       -> NotProcessedYet, logged (never "granted"
--                                                                                   for nothing; fixed by a config edit)
--   * otherwise: grant, record the PurchaseId in `Purchases` (newest 200), SAVE, and only when a finished save holds the
--     id -> PurchaseGranted. A save that does not finish in time -> NotProcessedYet; the retry finds the id and only
--     answers PurchaseGranted.
-- Grants (the client never sends an amount): a Cash pack is minutes of this player's Raceway Cash with the "at least Nx your
-- Cash" floor (CashPackPreview, computed here); the Starter Pack is Brawler (a Brawler copy when already owned), $5,000, a
-- paint and a decal, once per player; the All Passes Bundle writes its three passes into `Owned`; the respawn continues the
-- run when it is still open, and otherwise pays that run's Results total as Cash, so a payment is never taken for nothing.
-- RealPurchases does not change any of this: a real receipt is always honoured, whatever the buttons show.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BetaConfig = require(ReplicatedStorage.Shared.Beta.BetaConfig)
local BetaData = require(script.Parent.BetaData)
local BetaEconomy = require(script.Parent.BetaEconomy)
local BetaLineup = require(script.Parent.BetaLineup)
local BetaOwnership = require(script.Parent.BetaOwnership)
local BetaPlots = require(script.Parent.BetaPlots)
local BetaProducts = require(ReplicatedStorage.Shared.Beta.BetaProducts)
local BetaRun = require(script.Parent.BetaRun)
local CashPackPreview = require(ReplicatedStorage.Shared.UI.CashPackPreview)
local EconomyPreview = require(ReplicatedStorage.Shared.UI.EconomyPreview)

local BetaPurchases = {}

BetaPurchases.SaveTimeout = 15 -- seconds to wait for the save that holds a receipt id

export type Summary = {
	item: string,
	cash: number?,
	car: string?,
	copy: boolean?,
	continued: boolean?,
	passes: { string }?,
}

local grantedRemote: RemoteEvent? = nil

local function log(player: Player?, what: string)
	print(string.format("[CarHopBeta purchase] %s: %s", if player then player.Name else "?", what))
end

-- Lap Pay per second of the player's Lineup now, doubled with Double Lap Pay (the Cash packs' "minutes of Raceway Cash").
function BetaPurchases.rateOf(player: Player, data: BetaData.Data): number
	local double = if BetaOwnership.owns(player, "double-lap-pay") then 2 else 1
	return BetaEconomy.lineupPayOf(data) * double / EconomyPreview.LapSeconds
end

local function packOf(id: string): CashPackPreview.Pack?
	for _, pack in CashPackPreview.Packs do
		if pack.id == id then
			return pack
		end
	end
	return nil
end

-- Applies one item's grant to a loaded save (no yield). Returns the summary the client is told, or nil when the item has
-- no grant here (it is a Game Pass, handled by BetaOwnership).
function BetaPurchases.apply(player: Player, data: BetaData.Data, item: BetaProducts.Item): Summary?
	local pack = packOf(item.id)
	if pack then
		local amount = CashPackPreview.amount(pack, BetaPurchases.rateOf(player, data), data.Cash)
		local paid = BetaEconomy.addCash(player, amount, item.name)
		return { item = item.id, cash = paid }
	elseif item.id == "starter-pack" then
		local s = BetaProducts.Starter
		local summary: Summary = { item = item.id, car = s.car }
		if data.Owned["starter-pack"] then
			log(player, "a second Starter Pack receipt: granted again, so the payment is never for nothing")
		end
		data.Owned["starter-pack"] = true
		for _, cosmetic in s.cosmetics do
			data.Owned[cosmetic] = true
		end
		local car = data.Cars[s.car]
		if car == nil then
			data.Cars[s.car] = { Edition = 1, Copies = 0 }
			BetaLineup.autoPark(player, s.car)
		else
			-- Claude Code's call (R-02): an owned Brawler gets one copy toward its next edition instead
			car.Edition, car.Copies = EconomyPreview.addCopy(car.Edition, car.Copies)
			summary.copy = true
		end
		BetaEconomy.publishCars(player, data)
		BetaLineup.publish(player)
		summary.cash = BetaEconomy.addCash(player, s.cash, "Starter Pack")
		return summary
	elseif item.grants then
		for _, pass in item.grants do
			data.Owned[pass] = true
		end
		return { item = item.id, passes = item.grants }
	elseif item.id == "respawn" then
		local how, cash = BetaRun.paidRespawn(player)
		if how == "continued" then
			return { item = item.id, continued = true }
		end
		-- the run already ended: Claude Code's call (R-02), that run's Results total as Cash
		local paid = if cash and cash > 0 then BetaEconomy.addCash(player, cash, "Respawn after the run ended") else 0
		return { item = item.id, continued = false, cash = paid }
	end
	return nil
end

-- The receipt decision, apart from MarketplaceService so the self-test can call it.
function BetaPurchases.processReceipt(receipt: any): Enum.ProductPurchaseDecision
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	if not player then
		return Enum.ProductPurchaseDecision.NotProcessedYet -- not in this server: Roblox tries again when they are
	end
	local data = BetaData.get(player)
	if not data then
		log(player, "receipt " .. tostring(receipt.PurchaseId) .. " waits: the save is not loaded yet")
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local receiptId = tostring(receipt.PurchaseId)
	if table.find(data.Purchases, receiptId) then
		log(player, "receipt " .. receiptId .. " was already granted: nothing granted twice")
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	local item = BetaProducts.byProductId(receipt.ProductId)
	if not item then
		log(
			player,
			"receipt " .. receiptId .. " is for an unknown product " .. tostring(receipt.ProductId) .. ": not granted"
		)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local summary = BetaPurchases.apply(player, data, item)
	table.insert(data.Purchases, receiptId)
	while #data.Purchases > BetaConfig.PurchasesKept do
		table.remove(data.Purchases, 1)
	end
	BetaOwnership.publish(player)
	BetaPlots.publish(player)
	log(player, string.format("granted %s (receipt %s)", item.id, receiptId))
	if not BetaData.saveReceipt(player, receiptId, BetaPurchases.SaveTimeout) then
		log(
			player,
			"receipt " .. receiptId .. " granted but not saved yet: NotProcessedYet, the retry grants nothing twice"
		)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local remote = grantedRemote
	if remote and summary then
		remote:FireClient(player, item.id, summary)
	end
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

function BetaPurchases.start(net: Folder)
	local remote = Instance.new("RemoteEvent")
	remote.Name = BetaConfig.Remotes.PurchaseGranted
	remote.Parent = net
	grantedRemote = remote
	MarketplaceService.ProcessReceipt = function(receipt)
		local ok, decision = pcall(BetaPurchases.processReceipt, receipt)
		if not ok then
			warn("[CarHopBeta purchase] ProcessReceipt error: " .. tostring(decision))
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		return decision
	end
	-- a pass bought this session: tell the client it arrived (the Shop shows OWNED and a thank-you)
	BetaOwnership.Changed:Connect(function(player: Player)
		BetaPlots.publish(player)
	end)
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(
		function(player: Player, passId: number, purchased: boolean)
			local item = BetaProducts.byPassId(passId)
			if item and purchased then
				remote:FireClient(player, item.id, { item = item.id })
			end
		end
	)
end

-- R-05 on the Mock store (a Studio Play server, a real test player with a loaded Mock save). Returns PASS/FAIL lines and
-- leaves the save as it was. The restricted-player case is a client fixture (BetaPurchaseClient.selfTest).
function BetaPurchases.selfTest(player: Player): { string }
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
	if not BetaData.isTestSave() then
		return { "FAIL the purchase self-test runs only on the Mock store (a Studio multi-client test or useMockStore)" }
	end
	local data = BetaData.get(player) :: any
	if not data then
		return { "FAIL no save loaded for " .. player.Name }
	end
	local backup = {
		Cash = data.Cash,
		Cars = table.clone(data.Cars),
		Lineup = table.clone(data.Lineup),
		Purchases = table.clone(data.Purchases),
		Owned = table.clone(data.Owned),
		ParkingSpots = data.ParkingSpots,
	}
	local brawler = data.Cars.Brawler and table.clone(data.Cars.Brawler)
	-- a fake product table: the test uses real items with test ids, so it never needs created products
	local fakeIds = { ["cash-10"] = 9000001, ["starter-pack"] = 9000002, ["all-passes-bundle"] = 9000003 }
	local realLookup = BetaProducts.byProductId
	local function lookup(productId: number): BetaProducts.Item?
		for id, n in fakeIds do
			if n == productId then
				return BetaProducts.get(id)
			end
		end
		return realLookup(productId)
	end
	local function receipt(id: string, productId: number): any
		return { PurchaseId = id, PlayerId = player.UserId, ProductId = productId, CurrencySpent = 0 }
	end
	local function process(r: any): Enum.ProductPurchaseDecision
		local item = lookup(r.ProductId)
		if not item then
			return BetaPurchases.processReceipt(r) -- the real path for an unknown id
		end
		-- the same path as processReceipt, with the test item
		if table.find(data.Purchases, r.PurchaseId) then
			return Enum.ProductPurchaseDecision.PurchaseGranted
		end
		BetaPurchases.apply(player, data, item)
		table.insert(data.Purchases, r.PurchaseId)
		return if BetaData.saveReceipt(player, r.PurchaseId, BetaPurchases.SaveTimeout)
			then Enum.ProductPurchaseDecision.PurchaseGranted
			else Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local tag = "selftest-" .. tostring(os.clock())
	data.Cash = 1000
	local d1 = process(receipt(tag .. "-a", fakeIds["cash-10"]))
	expect("a Cash pack is granted once and saved", d1, Enum.ProductPurchaseDecision.PurchaseGranted)
	local after = data.Cash
	expect("the Cash pack paid at least its floor (0.4x)", after >= 1000 + 400, true)
	local d2 = process(receipt(tag .. "-a", fakeIds["cash-10"]))
	expect("a retried receipt answers PurchaseGranted", d2, Enum.ProductPurchaseDecision.PurchaseGranted)
	expect("... and grants nothing twice", data.Cash, after)
	local unknown = BetaPurchases.processReceipt(receipt(tag .. "-u", 12345))
	expect("an unknown product is not granted", unknown, Enum.ProductPurchaseDecision.NotProcessedYet)
	local gone =
		BetaPurchases.processReceipt({ PurchaseId = tag .. "-g", PlayerId = -42, ProductId = fakeIds["cash-10"] })
	expect("a player not in the server: NotProcessedYet", gone, Enum.ProductPurchaseDecision.NotProcessedYet)
	data.Cars.Brawler = nil
	process(receipt(tag .. "-s1", fakeIds["starter-pack"]))
	expect("Starter Pack gives Brawler", data.Cars.Brawler ~= nil, true)
	expect("Starter Pack is recorded once per player", data.Owned["starter-pack"], true)
	local cashBefore = data.Cash
	process(receipt(tag .. "-s2", fakeIds["starter-pack"]))
	expect("a second Starter Pack gives a Brawler copy", data.Cars.Brawler and data.Cars.Brawler.Copies, 1)
	expect("... and its $5,000", data.Cash - cashBefore, 5000)
	process(receipt(tag .. "-b", fakeIds["all-passes-bundle"]))
	expect("the bundle grants Double Lap Pay", BetaOwnership.owns(player, "double-lap-pay"), true)
	expect("the bundle grants VIP", BetaOwnership.owns(player, "vip"), true)
	data.ParkingSpots = 15
	BetaPlots.publish(player)
	expect("Expanded Paddock at 15 bought gives 18 spots", BetaPlots.spotsOf(player), 18)
	expect("Expanded Paddock never changes the saved spots", data.ParkingSpots, 15)
	expect("the save keeps at most 200 receipts", #data.Purchases <= BetaConfig.PurchasesKept, true)
	-- leave the save as it was
	for k, v in backup do
		data[k] = v
	end
	data.Cars.Brawler = brawler
	BetaEconomy.publishCash(player, data)
	BetaEconomy.publishCars(player, data)
	BetaLineup.publish(player)
	BetaOwnership.publish(player)
	BetaPlots.publish(player)
	return lines
end

return BetaPurchases
