--!strict
-- CAR HOP BETA 1: the one owner of player profiles in the beta (ProfileStore, the vendored copy).
-- Pattern from AGENTS.md: one store, StartSessionAsync on join, kick when it returns nil, AddUserId
-- and Reconcile, kick on OnSessionEnd, EndSession on leave (BindToClose is handled by ProfileStore).
-- Stand-in for Lane 2's real lifecycle module; the template is BetaConfig.Template.
--
-- Round 5 (decision 0039): Cash, WorldsUnlocked and LastSeen join the template (the last three agreed fields). After
-- Reconcile every field is checked for its type, because Reconcile only fills MISSING keys (a wrong-typed value stays):
-- a bad value is repaired to the template's start value and logged; valid balances, cars and unlocks are kept.
-- `priorLastSeen` is read BEFORE anything stamps LastSeen, so the Welcome back credit is computed from the real last visit.
--
-- Studio tests only: `BetaData.useMockStore()` sends later sessions through ProfileStore's Mock wrapper, and
-- `BetaData.setTestKey(userId, key)` points a test player at another mock key (T-03's synthetic same-profile rejoin, because
-- StudioTestService cannot reuse a UserId). Both do nothing outside Studio.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local BetaConfig = require(ReplicatedStorage.Shared.Beta.BetaConfig)
local Catalog = require(ReplicatedStorage.Shared.UI.CosmeticPreviewCatalog)
local EconomyPreview = require(ReplicatedStorage.Shared.UI.EconomyPreview)
local ProfileStore = require(ServerScriptService.Server.vendor.ProfileStore) :: any
local RosterFixtures = require(ReplicatedStorage.Shared.UI.RosterFixtures)
local Signal = require(ReplicatedStorage.Packages.Signal)

export type CarSave = { Edition: number, Copies: number }
export type Data = {
	RacewayLevel: number,
	ParkingSpots: number,
	TutorialDone: boolean,
	Cars: { [string]: CarSave }, -- agreed field (Round 4)
	Lineup: { string }, -- agreed field (Round 4)
	Cash: number, -- agreed field (Round 5)
	WorldsUnlocked: { [string]: boolean }, -- agreed field (Round 5)
	LastSeen: number, -- agreed field (Round 5): Unix time, 0 = never stamped
	StaminaLevel: number, -- beta-only (Adam, 2026-11-05): Stamina Shop upgrades bought, not an agreed field
	Purchases: { string }, -- beta-only (Round 6, R-02): processed receipt ids, newest last, at most 200
	Owned: { [string]: boolean }, -- beta-only (Round 6, R-02): bundle passes, the Starter Pack and its cosmetics
	LuckLevel: number, -- beta-only (Round 7, P-04): Lucky Clover levels bought, 0 to 5
	Equipped: { [string]: string }, -- beta-only (Round 7, C-08): the worn Style Shop item per tab
	RideCar: string, -- beta-only (Round 8, C-03): the car a run starts on, an owned car id (default "Putter"), a proposal for Brian L
}

local BetaData = {}

BetaData.Loaded = Signal.new() -- (player, data, priorLastSeen: number)
BetaData.Releasing = Signal.new() -- (player, data) just before the session ends

-- Round 8 (C-03): the template plus the one new field, RideCar (the lead may move it into BetaConfig.Template; this stays the same then)
local TEMPLATE = table.clone(BetaConfig.Template)
if TEMPLATE.RideCar == nil then
	TEMPLATE.RideCar = "Putter"
end
local store = ProfileStore.New(BetaConfig.StoreName, TEMPLATE)
local profiles: { [Player]: any } = {}
local testKeys: { [number]: string } = {}
local useMock = false

function BetaData.get(player: Player): Data?
	local profile = profiles[player]
	return if profile and profile:IsActive() then profile.Data :: Data else nil
end

function BetaData.useMockStore()
	if RunService:IsStudio() then
		useMock = true
	end
end

function BetaData.isMock(): boolean
	return useMock
end

-- Round 6: a save that never reaches a real beta save (the Mock store, or Studio with no DataStore access, where
-- ProfileStore keeps everything in memory). Self-tests that change a save run only on one of these.
function BetaData.isTestSave(): boolean
	return useMock or (RunService:IsStudio() and ProfileStore.DataStoreState ~= "Access")
end

function BetaData.setTestKey(userId: number, key: string?)
	if RunService:IsStudio() and useMock then
		testKeys[userId] = key
	end
end

function BetaData.keyOf(player: Player): string
	return testKeys[player.UserId] or tostring(player.UserId)
end

-- T-03 (Studio, Mock only): the NEXT player to join loads this mock key instead of their own. StudioTestService:AddPlayers
-- takes only a count, so the replacement client's UserId is not known in advance; this is a synthetic same-profile rejoin,
-- not real-account persistence.
local nextJoinKey: string? = nil
function BetaData.setNextJoinKey(key: string?)
	if RunService:IsStudio() and useMock then
		nextJoinKey = key
	end
end

local function finite(n: any): boolean
	return type(n) == "number" and n == n and n ~= math.huge and n ~= -math.huge
end

-- Repairs a reconciled save in place. Returns the list of repairs (empty for a healthy save).
function BetaData.sanitize(data: any): { string }
	local fixed: { string } = {}
	local t = BetaConfig.Template
	local function fix(field: string, value: any)
		data[field] = value
		table.insert(fixed, field)
	end
	if not finite(data.Cash) or data.Cash < 0 then
		fix("Cash", t.Cash)
	else
		data.Cash = math.floor(data.Cash)
	end
	if not finite(data.RacewayLevel) then
		fix("RacewayLevel", t.RacewayLevel)
	end
	if not finite(data.ParkingSpots) then
		fix("ParkingSpots", t.ParkingSpots)
	end
	if type(data.TutorialDone) ~= "boolean" then
		fix("TutorialDone", false)
	end
	if not finite(data.LastSeen) or data.LastSeen < 0 then
		fix("LastSeen", 0)
	end
	if not finite(data.StaminaLevel) then
		fix("StaminaLevel", t.StaminaLevel)
	else
		data.StaminaLevel = math.clamp(math.floor(data.StaminaLevel), 0, EconomyPreview.StaminaMaxLevel)
	end
	-- Round 7 (P-04): a finite whole Lucky Clover level from 0 to 5; a bad value goes back to 0, a good one is kept
	if not finite(data.LuckLevel) then
		fix("LuckLevel", t.LuckLevel)
	else
		data.LuckLevel = math.clamp(math.floor(data.LuckLevel), 0, EconomyPreview.LuckMaxLevel)
	end
	-- Round 7 (C-08): one known item id per Style Shop tab; anything else goes back to the default look
	if type(data.Equipped) ~= "table" then
		fix("Equipped", table.clone(t.Equipped))
	else
		for tab, default in t.Equipped do
			local id = data.Equipped[tab]
			if type(id) ~= "string" or Catalog.byId(tab :: any, id) == nil then
				data.Equipped[tab] = default
				table.insert(fixed, "Equipped." .. tab)
			end
		end
		for tab in data.Equipped do
			if t.Equipped[tab] == nil then
				data.Equipped[tab] = nil
				table.insert(fixed, "Equipped." .. tostring(tab))
			end
		end
	end
	-- Round 6 (R-02): receipt ids are strings, newest last, at most PurchasesKept; Owned is { [string]: true }
	if type(data.Purchases) ~= "table" then
		fix("Purchases", {})
	else
		local ids = {}
		for _, id in data.Purchases do
			if type(id) == "string" then
				table.insert(ids, id)
			end
		end
		while #ids > BetaConfig.PurchasesKept do
			table.remove(ids, 1)
		end
		data.Purchases = ids
	end
	if type(data.Owned) ~= "table" then
		fix("Owned", {})
	else
		for id, on in data.Owned do
			if type(id) ~= "string" or on ~= true then
				data.Owned[id] = nil
				table.insert(fixed, "Owned." .. tostring(id))
			end
		end
	end
	if type(data.WorldsUnlocked) ~= "table" then
		fix("WorldsUnlocked", { Downtown = true })
	else
		data.WorldsUnlocked.Downtown = true -- World 1 is always open
	end
	if type(data.Cars) ~= "table" then
		fix("Cars", table.clone(t.Cars))
	else
		for id, car in data.Cars do
			if type(id) ~= "string" or type(car) ~= "table" or not finite(car.Edition) or not finite(car.Copies) then
				data.Cars[id] = nil
				table.insert(fixed, "Cars." .. tostring(id))
			end
		end
		if next(data.Cars) == nil then
			fix("Cars", { Putter = { Edition = 1, Copies = 0 } })
		end
	end
	if type(data.Lineup) ~= "table" then
		fix("Lineup", {})
	end
	-- a dense list of owned, known, unique cars: a hole or a stranger is dropped, the order is kept
	local keys = {}
	for k in data.Lineup do
		if type(k) == "number" then
			table.insert(keys, k)
		end
	end
	table.sort(keys)
	local clean, seen = {}, {}
	for _, k in keys do
		local id = data.Lineup[k]
		if type(id) == "string" and data.Cars[id] and RosterFixtures.byId(id) and not seen[id] then
			table.insert(clean, id)
			seen[id] = true
		else
			table.insert(fixed, "Lineup." .. tostring(id))
		end
	end
	data.Lineup = clean
	-- Round 8 (C-03): RideCar is a known car the player owns (or a World's Loaner, always theirs); anything else goes back to Putter
	local ride = data.RideCar
	local rideCar = if type(ride) == "string" then RosterFixtures.byId(ride) else nil
	if rideCar == nil or not (rideCar.loaner or data.Cars[rideCar.id]) then
		data.RideCar = "Putter"
		if ride ~= nil then
			table.insert(fixed, "RideCar")
		end
	end
	return fixed
end

-- Round 6 (E-02, Adam's decision of 2026-11-05): Cars[id].Copies is now the LIFETIME total (Brian L's meaning). A save made
-- before Round 6 counted copies at the current edition, so it is converted ONCE, in place, on load. No save field is added:
-- the marker is the profile's RobloxMetaData key below (DataStore key metadata, beta-only), so the conversion never runs
-- twice. Returns how many cars changed (0 for a fresh save or an already-converted one).
BetaData.CopiesMarker = "CarHopBetaCopiesLifetime"
function BetaData.migrateCopies(data: any, meta: any): number
	if type(meta) ~= "table" or meta[BetaData.CopiesMarker] == true then
		return 0
	end
	local changed = 0
	if type(data.Cars) == "table" then
		for _, car in data.Cars do
			local lifetime = EconomyPreview.lifetimeCopies(car.Edition, car.Copies)
			if lifetime ~= car.Copies then
				car.Copies = lifetime
				changed += 1
			end
		end
	end
	meta[BetaData.CopiesMarker] = true
	return changed
end

local function load(player: Player)
	local source = if useMock then store.Mock else store
	if nextJoinKey then
		testKeys[player.UserId] = nextJoinKey
		nextJoinKey = nil
	end
	local profile = source:StartSessionAsync(BetaData.keyOf(player), {
		Cancel = function()
			return player.Parent ~= Players
		end,
	})
	if profile == nil then
		player:Kick("Your save could not be loaded. Please rejoin.")
		return
	end
	profile:AddUserId(player.UserId)
	profile:Reconcile()
	local fixed = BetaData.sanitize(profile.Data)
	if #fixed > 0 then
		warn(string.format("[CarHopBeta] repaired %s's save: %s", player.Name, table.concat(fixed, ", ")))
	end
	local converted = BetaData.migrateCopies(profile.Data, profile.RobloxMetaData)
	if converted > 0 then
		print(string.format("[CarHopBeta] %s's Copies converted to lifetime totals (%d cars)", player.Name, converted))
	end
	local priorLastSeen = (profile.Data :: Data).LastSeen
	profile.OnSessionEnd:Connect(function()
		profiles[player] = nil
		player:Kick("Your save was opened somewhere else. Please rejoin.")
	end)
	if player.Parent ~= Players then
		profile:EndSession()
		return
	end
	profiles[player] = profile
	BetaData.Loaded:Fire(player, profile.Data, priorLastSeen)
end

-- Round 6 (R-02): saves the player's profile now and waits until a finished save contains `receiptId` (ProfileStore's
-- OnAfterSave hands over the data that was saved). Returns false when the profile is gone or no such save came within
-- `timeout` seconds; the caller then answers NotProcessedYet, and the retry finds the receipt id and grants nothing twice.
function BetaData.saveReceipt(player: Player, receiptId: string, timeout: number): boolean
	local profile = profiles[player]
	if not (profile and profile:IsActive()) then
		return false
	end
	local saved = false
	local conn = profile.OnAfterSave:Connect(function(last: any)
		if type(last) == "table" and type(last.Purchases) == "table" and table.find(last.Purchases, receiptId) then
			saved = true
		end
	end)
	profile:Save()
	local t0 = os.clock()
	while not saved and profile:IsActive() and os.clock() - t0 < timeout do
		task.wait(0.1)
	end
	conn:Disconnect()
	return saved
end

-- Ends a player's session now (on leave). Stamps LastSeen first.
function BetaData.release(player: Player)
	local profile = profiles[player]
	profiles[player] = nil
	if profile then
		local data = profile.Data :: Data
		BetaData.Releasing:Fire(player, data)
		data.LastSeen = os.time()
		profile:EndSession()
	end
end

-- True once no session for `key` is open in this server (for the T-03 synthetic rejoin), false after `timeout` seconds.
function BetaData.waitReleased(key: string, timeout: number): boolean
	local t0 = os.clock()
	while os.clock() - t0 < timeout do
		local busy = false
		for _, profile in profiles do
			if profile.Key == key then
				busy = true
			end
		end
		if not busy then
			return true
		end
		task.wait(0.1)
	end
	return false
end

function BetaData.start()
	ProfileStore.OnError:Connect(function(message: string, storeName: string, key: string)
		warn(string.format("[CarHopBeta] save error (%s, %s): %s", storeName, key, message))
	end)
	for _, player in Players:GetPlayers() do
		task.spawn(load, player)
	end
	Players.PlayerAdded:Connect(load)
	Players.PlayerRemoving:Connect(BetaData.release)
end

return BetaData
