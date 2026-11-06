--!strict
-- BETA-ONLY: the Style Shop on the server (Round 7, C-07 and C-08; decision 0042 items 12 and 14). A proposal for Brian L's
-- economy (vault/design/specs/lane3-round7-for-brian-l.md).
--
-- The client asks; the server decides. BuyStyle(tab, id) and EquipStyle(tab, id) carry only names: the server looks the item up
-- in the shared catalog (CosmeticPreviewCatalog), takes its PREVIEW Cash price itself, and never sells a Robux item for Cash or
-- a VIP item at all. What a player owns is kept in the save's `Owned` list (with the Robux cosmetics); what they wear is the save's
-- `Equipped` (one id per tab). Both are published read only as the Player attribute BetaStyle (JSON), which every screen and the
-- run car read through StyleState. Every request gets one BetaResult reply: what, ok, the reason line, the missing Cash.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BetaConfig = require(ReplicatedStorage.Shared.Beta.BetaConfig)
local BetaData = require(script.Parent.BetaData)
local BetaEconomy = require(script.Parent.BetaEconomy)
local BetaEvents = require(script.Parent.BetaEvents)
local BetaOwnership = require(script.Parent.BetaOwnership)
local Catalog = require(ReplicatedStorage.Shared.UI.CosmeticPreviewCatalog)

local BetaStyle = {}

local COOLDOWN = 0.3
local TABS: { [string]: boolean } = { Paint = true, Decals = true, Wheels = true, Trails = true }

local last: { [Player]: number } = {}
local resultRemote: RemoteEvent? = nil

local function reply(player: Player, what: string, ok: boolean, reason: string?, missing: number?)
	if resultRemote then
		resultRemote:FireClient(player, what, ok, reason, missing)
	end
	if not ok then
		print(string.format("[CarHopBeta] %s refused for %s (%d): %s", what, player.Name, player.UserId, reason or "?"))
	end
end

-- A tab and id from a remote: two short strings naming a real catalog item, or nil.
local function itemFrom(tab: any, id: any): Catalog.Item?
	if type(tab) ~= "string" or type(id) ~= "string" or #id > 64 or not TABS[tab] then
		return nil
	end
	return Catalog.byId(tab :: any, id)
end

-- Does the player own this item? Free items yes; VIP items while they have VIP; others when bought (Cash or Robux).
function BetaStyle.owns(player: Player, item: Catalog.Item): boolean
	if item.vip then
		return BetaOwnership.owns(player, "vip")
	end
	if item.price == 0 and item.robux == nil then
		return true
	end
	return BetaOwnership.owns(player, item.id)
end

function BetaStyle.publish(player: Player)
	local data = BetaData.get(player)
	if not data then
		return
	end
	local owned = {}
	for _, tab in Catalog.Tabs do
		for _, item in Catalog.Items[tab] do
			if not item.isNone and (item.price > 0 or item.robux or item.vip) and BetaStyle.owns(player, item) then
				table.insert(owned, item.id)
			end
		end
	end
	player:SetAttribute(BetaConfig.StyleAttribute, HttpService:JSONEncode({ o = owned, e = data.Equipped }))
end

function BetaStyle.buy(player: Player, tab: any, id: any): (boolean, string?, number?)
	local data = BetaData.get(player)
	if not data then
		return false, "Your save is still loading.", nil
	end
	local item = itemFrom(tab, id)
	if not item or item.isNone then
		return false, "That item isn't in the shop.", nil
	end
	if BetaStyle.owns(player, item) then
		return false, "You already own this.", nil
	end
	if item.vip then
		return false, "This comes with the VIP pass.", nil
	end
	if item.robux then
		return false, "This one is bought with Robux: coming soon.", nil
	end
	local paid, missing = BetaEconomy.trySpend(player, item.price)
	if not paid then
		return false, "Not enough Cash.", missing
	end
	data.Owned[item.id] = true
	BetaOwnership.publish(player)
	BetaStyle.publish(player)
	BetaEvents.fire(player, "BuyStyle")
	print(string.format("[CarHopBeta] %s bought %s %s for $%d", player.Name, item.tab, item.id, item.price))
	return true, nil, nil
end

function BetaStyle.equip(player: Player, tab: any, id: any): (boolean, string?, number?)
	local data = BetaData.get(player)
	if not data then
		return false, "Your save is still loading.", nil
	end
	local item = itemFrom(tab, id)
	if not item then
		return false, "That item isn't in the shop.", nil
	end
	if not item.isNone and not BetaStyle.owns(player, item) then
		return false, "Buy it first.", nil
	end
	data.Equipped[item.tab] = item.id
	BetaStyle.publish(player)
	BetaEvents.fire(player, "EquipStyle") -- Round 7 (U-05): the full-look mission
	return true, nil, nil
end

function BetaStyle.start(net: Folder)
	local function remote(name: string): RemoteEvent
		local r = Instance.new("RemoteEvent")
		r.Name = name
		r.Parent = net
		return r
	end
	resultRemote = net:FindFirstChild(BetaConfig.Remotes.Result) :: RemoteEvent?
	local buy = remote(BetaConfig.Remotes.BuyStyle)
	local equip = remote(BetaConfig.Remotes.EquipStyle)
	local function handle(what: string, fn: (Player, any, any) -> (boolean, string?, number?))
		return function(player: Player, tab: any, id: any)
			local now = os.clock()
			if now - (last[player] or -math.huge) < COOLDOWN then
				reply(player, what, false, "One moment, try again.", nil)
				return
			end
			last[player] = now
			local ok, reason, missing = fn(player, tab, id)
			reply(player, what, ok, reason, missing)
		end
	end
	buy.OnServerEvent:Connect(handle("BuyStyle", BetaStyle.buy))
	equip.OnServerEvent:Connect(handle("EquipStyle", BetaStyle.equip))
	BetaData.Loaded:Connect(function(player: Player)
		BetaStyle.publish(player)
	end)
	BetaOwnership.Changed:Connect(function(player: Player)
		-- VIP or a Robux trail arrived: re-publish, and take off a VIP item the player no longer has
		local data = BetaData.get(player)
		if data then
			for tab, id in data.Equipped do
				local item = Catalog.byId(tab :: any, id)
				if item and not item.isNone and not BetaStyle.owns(player, item) then
					data.Equipped[tab] = (BetaConfig.Template.Equipped :: any)[tab]
				end
			end
		end
		BetaStyle.publish(player)
	end)
	Players.PlayerRemoving:Connect(function(player: Player)
		last[player] = nil
	end)
end

-- From the self-test runner in a Studio Play server (works on the player's live save, then puts it back).
function BetaStyle.selfTest(player: Player): { string }
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
	local config = ReplicatedStorage:FindFirstChild(BetaConfig.MarkerName)
	local free = config and config:GetAttribute(BetaConfig.FreePurchasesAttribute)
	if config then
		config:SetAttribute(BetaConfig.FreePurchasesAttribute, false)
	end
	-- one Owned list holds every tab, so no two items may share an id
	local seen: { [string]: string } = {}
	local clash = "none"
	for _, tab in Catalog.Tabs do
		for _, item in Catalog.Items[tab] do
			if seen[item.id] and not item.isNone then
				clash = seen[item.id] .. " and " .. tab .. " " .. item.id
			end
			seen[item.id] = tab
		end
	end
	expect("every item id is unique across the four tabs", clash, "none")
	local savedCash, savedOwned, savedEquipped = data.Cash, table.clone(data.Owned), table.clone(data.Equipped)
	data.Owned.pit_white = nil
	data.Cash = 499
	local ok, _, missing = BetaStyle.buy(player, "Paint", "pit_white")
	expect("C-03 Pit White at $499 is refused", ok, false)
	expect("... the refusal names the missing $1", missing, 1)
	data.Cash = 500
	ok = BetaStyle.buy(player, "Paint", "pit_white")
	expect("C-03 Pit White at $500 is bought", ok, true)
	expect("... and costs $500", data.Cash, 0)
	expect("... and is kept in Owned", data.Owned.pit_white, true)
	ok = BetaStyle.buy(player, "Paint", "pit_white")
	expect("buying it again is refused", ok, false)
	data.Cash = 1e12
	ok = BetaStyle.buy(player, "Trails", "flame_rush")
	expect("a Robux trail is never sold for Cash", ok, false)
	expect("... and charges nothing", data.Cash, 1e12)
	ok = BetaStyle.buy(player, "Paint", "vip_royal")
	expect("a VIP paint is never sold", ok, false)
	ok = BetaStyle.buy(player, "Paint", 42)
	expect("a number for an id is refused", ok, false)
	ok = BetaStyle.buy(player, "Hats", "pit_white")
	expect("an unknown tab is refused", ok, false)
	data.Owned.galaxy = nil
	ok = BetaStyle.equip(player, "Paint", "galaxy")
	expect("C-08 equipping a paint not owned is refused", ok, false)
	ok = BetaStyle.equip(player, "Paint", "pit_white")
	expect("C-08 equipping an owned paint works", ok, true)
	expect("... and is saved in Equipped", data.Equipped.Paint, "pit_white")
	ok = BetaStyle.equip(player, "Decals", "none")
	expect("C-08 No decal can always be worn", ok, true)
	local json = player:GetAttribute(BetaConfig.StyleAttribute)
	local decoded = type(json) == "string" and HttpService:JSONDecode(json) or nil
	expect(
		"C-08 the BetaStyle attribute carries the equipped paint",
		decoded and decoded.e and decoded.e.Paint,
		"pit_white"
	)
	local bad = { Equipped = { Paint = "no_such_paint", Hats = "x" } } :: any
	for k, v in BetaConfig.Template do
		if bad[k] == nil then
			bad[k] = if type(v) == "table" then table.clone(v) else v
		end
	end
	BetaData.sanitize(bad)
	expect("an unknown saved paint goes back to Factory Paint", bad.Equipped.Paint, "factory_paint")
	expect("an unknown saved tab is dropped", bad.Equipped.Hats, nil)
	data.Cash, data.Owned, data.Equipped = savedCash, savedOwned, savedEquipped
	if config then
		config:SetAttribute(BetaConfig.FreePurchasesAttribute, free)
	end
	BetaEconomy.publishCash(player, data)
	BetaStyle.publish(player)
	return lines
end

return BetaStyle
