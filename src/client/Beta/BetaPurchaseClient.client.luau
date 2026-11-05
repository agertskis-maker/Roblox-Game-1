--!strict
-- CATCH A CAR! BETA (Round 6, R-03): the beta's Robux purchase flow, set as RobuxSeam's provider so every Robux button (Shop,
-- Results respawn, Garage trails, HUD VIP, GET MORE SPOTS) goes through it. Off unless ReplicatedStorage.CarHopBeta exists.
--
-- The client never grants, never sends an amount and never says what it owns: it opens Roblox's own prompt after the player
-- pressed a button, and waits for the SERVER's word (BetaPurchaseGranted after ProcessReceipt saved the receipt, or the
-- server-published BetaOwned list for a pass). Facts checked on create.roblox.com on 2026-11-05
-- (vault/design/specs/robux-api-notes.md):
--   * prices: MarketplaceService:GetProductInfoAsync per product, on the client, because regional pricing can give this
--     player a lower price than the default; the PREVIEW number (tagged PREVIEW) is shown only when that fails.
--   * restriction: PolicyService:GetPolicyInfoForPlayerAsync has no "cannot buy at all" field. ArePaidRandomItemsRestricted
--     and IsPaidItemTradingAllowed apply only to paid random or tradable items, and no item here is either, so no beta
--     item is restricted by them; a failed policy lookup shows "Try later" (unknown is never "Available"). Studio fixture:
--     the LocalPlayer attribute BetaPolicyRestricted = true shows the "Not available for your account" state (R-05).
--   * Studio: purchases are test purchases (mocked; nothing is charged), so prompts open there whatever RealPurchases says.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local PolicyService = game:GetService("PolicyService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local BetaConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Beta"):WaitForChild("BetaConfig"))
if not BetaConfig.enabled() then
	return
end

local BetaProducts = require(ReplicatedStorage.Shared.Beta:WaitForChild("BetaProducts"))
local RobuxSeam = require(script.Parent.Parent:WaitForChild("UI"):WaitForChild("RobuxSeam"))

local player = Players.LocalPlayer
local GRANT_WAIT = 30 -- seconds to wait for the server's grant after Roblox says the purchase went through

-- POLICY ------------------------------------------------------------------------------------------------------------------
local policy: "unknown" | "ok" | "failed" = "unknown"
task.spawn(function()
	for attempt = 1, 3 do
		local ok, info = pcall(function()
			return PolicyService:GetPolicyInfoForPlayerAsync(player)
		end)
		if ok and type(info) == "table" then
			policy = "ok"
			RobuxSeam.Changed:Fire()
			return
		end
		warn(string.format("[CarHopBeta] PolicyService lookup failed (try %d): %s", attempt, tostring(info)))
		task.wait(2 * attempt)
	end
	policy = "failed"
	RobuxSeam.Changed:Fire()
end)

local function restricted(_item: BetaProducts.Item): boolean
	-- no beta item is paid-random or tradable, so no policy field applies (see the header); the Studio fixture tests the state
	return RunService:IsStudio() and player:GetAttribute("BetaPolicyRestricted") == true
end

-- PRICES ------------------------------------------------------------------------------------------------------------------
local prices: { [string]: number } = {}
local function fetchPrices()
	for _, item in BetaProducts.Items do
		if BetaProducts.created(item) and prices[item.id] == nil then
			local infoType = if item.kind == "GamePass" then Enum.InfoType.GamePass else Enum.InfoType.Product
			local ok, info = pcall(function()
				return (MarketplaceService :: any):GetProductInfoAsync(item.robloxId, infoType)
			end)
			if ok and type(info) == "table" and type(info.PriceInRobux) == "number" then
				prices[item.id] = info.PriceInRobux
			end
		end
	end
	RobuxSeam.Changed:Fire()
end
task.spawn(fetchPrices)

-- OWNERSHIP (server-published, read only) ---------------------------------------------------------------------------------
local function owned(id: string): boolean
	local text = player:GetAttribute(BetaConfig.OwnedAttribute)
	if type(text) ~= "string" then
		return false
	end
	for each in string.gmatch(text, "[^,]+") do
		if each == id then
			return true
		end
	end
	return false
end
player:GetAttributeChangedSignal(BetaConfig.OwnedAttribute):Connect(function()
	RobuxSeam.Changed:Fire()
end)
player:GetAttributeChangedSignal("BetaPolicyRestricted"):Connect(function()
	RobuxSeam.Changed:Fire()
end)

local function prompting(): boolean
	return RunService:IsStudio() or BetaConfig.realPurchases()
end

local function state(id: string): RobuxSeam.State
	local item = BetaProducts.get(id)
	if not item then
		return "ComingSoon"
	end
	if (item.kind == "GamePass" or item.oncePerPlayer) and owned(id) then
		return "Owned"
	end
	if item.grants then
		local all = true
		for _, pass in item.grants do
			all = all and owned(pass)
		end
		if all then
			return "Owned" -- never sell a bundle whose passes are all owned already
		end
	end
	if restricted(item) then
		return "Unavailable"
	end
	if policy == "failed" then
		return "Error"
	end
	if not prompting() then
		return "ComingSoon"
	end
	if not BetaProducts.created(item) then
		return "NotCreated"
	end
	return "Available"
end

-- BUYING --------------------------------------------------------------------------------------------------------------
local net = ReplicatedStorage:WaitForChild(BetaConfig.NetName, 30)
local grantedRemote = net and net:WaitForChild(BetaConfig.Remotes.PurchaseGranted, 10) :: RemoteEvent?
local waiting: { [string]: (summary: any) -> () } = {}
if grantedRemote then
	grantedRemote.OnClientEvent:Connect(function(itemId: any, summary: any)
		local fn = type(itemId) == "string" and waiting[itemId]
		if fn then
			waiting[itemId] = nil
			fn(summary)
		end
	end)
end

local function buy(id: string, done: (RobuxSeam.Result) -> ()): (() -> ())?
	local item = BetaProducts.get(id) :: BetaProducts.Item
	if not BetaProducts.created(item) then
		print(
			string.format(
				"[CarHopBeta] %s: product not created yet (BetaProducts id 0). Nothing was prompted.",
				item.name
			)
		)
		done({ status = "NotCreated", offerId = id })
		return nil
	end
	local finished = false
	local conns: { RBXScriptConnection } = {}
	local function finish(result: RobuxSeam.Result)
		if finished then
			return
		end
		finished = true
		waiting[id] = nil
		for _, c in conns do
			c:Disconnect()
		end
		done(result)
	end
	waiting[id] = function(summary: any)
		finish({ status = "Purchased", offerId = id, summary = summary })
	end
	if item.kind == "DevProduct" then
		table.insert(
			conns,
			MarketplaceService.PromptProductPurchaseFinished:Connect(
				function(userId: number, productId: number, bought: boolean)
					if userId == player.UserId and productId == item.robloxId and not bought then
						finish({ status = "Cancelled", offerId = id })
					end
				end
			)
		)
		MarketplaceService:PromptProductPurchase(player, item.robloxId)
	else
		table.insert(
			conns,
			MarketplaceService.PromptGamePassPurchaseFinished:Connect(
				function(who: Player, passId: number, bought: boolean)
					if who == player and passId == item.robloxId and not bought then
						finish({ status = "Cancelled", offerId = id })
					end
				end
			)
		)
		MarketplaceService:PromptGamePassPurchase(player, item.robloxId)
	end
	-- the server's grant never came (it will be granted on the next join or purchase): say so plainly, charge nothing more
	task.delay(GRANT_WAIT + 60, function()
		finish({ status = "Error", offerId = id, message = "Your purchase is being checked. It arrives soon." })
	end)
	return function()
		finish({ status = "Cancelled", offerId = id })
	end
end

RobuxSeam.setProvider({
	state = state,
	price = function(id: string): number?
		return prices[id]
	end,
	buy = buy,
})
