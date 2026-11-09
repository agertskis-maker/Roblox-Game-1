--!strict
-- BETA-ONLY: the car a player starts a run on (Round 8, C-03; decision 0044). A proposal for Brian L's save: one new field,
-- `RideCar` (a car id = its model name, default "Putter", the Downtown Loaner; listed in vault/design/specs/lane3-round8-for-brian-l.md).
--
-- The client only asks. PickRideCar(carId) carries one short string; the server checks the car is a real roster car the caller owns
-- (or a World's Loaner, which is always theirs), saves it as `RideCar`, publishes it read only as the Player attribute BetaRideCar
-- and answers with one BetaResult ("PickRideCar", ok, reason). StartRun (BetaRun) then starts the run on the client's startCarId only
-- if it is owned and belongs to that World, else on the saved RideCar, else on the World's Loaner: the run car is always a car the
-- server has checked. The client never sends a price, an amount or a result.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BetaConfig = require(ReplicatedStorage.Shared.Beta.BetaConfig)
local BetaData = require(script.Parent.BetaData)
local RosterFixtures = require(ReplicatedStorage.Shared.UI.RosterFixtures)

local BetaRide = {}

BetaRide.Attribute = "BetaRideCar" -- Player: the saved RideCar (read only; the server writes it)
BetaRide.Default = "Putter"

local COOLDOWN = 0.4
local MAX_ID = 64

local last: { [Player]: number } = {}
local resultRemote: RemoteEvent? = nil

local function reply(player: Player, ok: boolean, reason: string?)
	if resultRemote then
		resultRemote:FireClient(player, "PickRideCar", ok, reason, nil)
	end
	if not ok then
		print(
			string.format("[CarHopBeta] PickRideCar refused for %s (%d): %s", player.Name, player.UserId, reason or "?")
		)
	end
end

-- Does the player own this car, as a real roster car? A World's Loaner is always theirs.
function BetaRide.owns(player: Player, carId: any): boolean
	if type(carId) ~= "string" or #carId == 0 or #carId > MAX_ID then
		return false
	end
	local car = RosterFixtures.byId(carId)
	if not car then
		return false
	end
	if car.loaner then
		return true
	end
	local data = BetaData.get(player)
	return data ~= nil and data.Cars[carId] ~= nil
end

-- The saved RideCar, or the default when it is gone or no longer owned.
function BetaRide.rideCar(player: Player): string
	local data = BetaData.get(player)
	local saved = data and data.RideCar
	if type(saved) == "string" and BetaRide.owns(player, saved) then
		return saved
	end
	return BetaRide.Default
end

-- The car a run in `world` starts on (BetaRun.start): the car the client asked for if it is owned and of this World, else the saved
-- RideCar if that is of this World, else the World's Loaner.
function BetaRide.startCarFor(player: Player, world: string, requested: any): string
	local function usable(id: any): boolean
		if not BetaRide.owns(player, id) then
			return false
		end
		local car = RosterFixtures.byId(id :: string)
		return car ~= nil and car.world == world
	end
	if usable(requested) then
		return requested :: string
	end
	local saved = BetaRide.rideCar(player)
	if usable(saved) then
		return saved
	end
	local loaner = RosterFixtures.loaner(world)
	return if loaner then loaner.id else BetaRide.Default
end

function BetaRide.publish(player: Player)
	if BetaData.get(player) then
		player:SetAttribute(BetaRide.Attribute, BetaRide.rideCar(player))
	end
end

-- Saves the pick. Returns ok and a reason line for a refusal.
function BetaRide.pick(player: Player, carId: any): (boolean, string?)
	local data = BetaData.get(player)
	if not data then
		return false, "Your save is still loading."
	end
	if type(carId) ~= "string" or #carId == 0 or #carId > MAX_ID or not RosterFixtures.byId(carId) then
		return false, "That car isn't in the game."
	end
	if not BetaRide.owns(player, carId) then
		return false, "You don't own that car yet."
	end
	data.RideCar = carId
	BetaRide.publish(player)
	print(string.format("[CarHopBeta] %s will ride %s", player.Name, carId))
	return true, nil
end

function BetaRide.start(net: Folder)
	local remote = Instance.new("RemoteEvent")
	remote.Name = BetaConfig.Remotes.PickRideCar
	remote.Parent = net
	resultRemote = net:FindFirstChild(BetaConfig.Remotes.Result) :: RemoteEvent?
	remote.OnServerEvent:Connect(function(player: Player, carId: any)
		local now = os.clock()
		if now - (last[player] or -math.huge) < COOLDOWN then
			-- review D12: a request inside the cooldown is dropped without a reply or a log line, so spamming the remote costs the
			-- server nothing; an honest client never sends one (RidePick waits COOLDOWN between asks and answers itself)
			return
		end
		last[player] = now
		local ok, reason = BetaRide.pick(player, carId)
		reply(player, ok, reason)
	end)
	BetaData.Loaded:Connect(function(player: Player)
		BetaRide.publish(player)
	end)
	Players.PlayerRemoving:Connect(function(player: Player)
		last[player] = nil
	end)
end

-- From the self-test runner in a Studio Play server (works on the player's live save, then puts it back).
function BetaRide.selfTest(player: Player): { string }
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
	local savedCars, savedRide = table.clone(data.Cars), data.RideCar
	-- review N6: the save is put back on every path, also when a check below errors
	local ran, err = pcall(function()
	data.Cars = { Putter = { Edition = 1, Copies = 0 }, ["Pizza Runner"] = { Edition = 1, Copies = 0 } }
	local ok = BetaRide.pick(player, "Pizza Runner")
	expect("C-03 an owned car can be picked", ok, true)
	expect("... and is saved as RideCar", data.RideCar, "Pizza Runner")
	expect("... and published as the BetaRideCar attribute", player:GetAttribute(BetaRide.Attribute), "Pizza Runner")
	ok = BetaRide.pick(player, "Cruiser")
	expect("C-03 a car not owned is refused", ok, false)
	expect("... and the pick stays", data.RideCar, "Pizza Runner")
	ok = BetaRide.pick(player, 42)
	expect("a number for a car id is refused", ok, false)
	ok = BetaRide.pick(player, string.rep("x", 200))
	expect("an over-long car id is refused", ok, false)
	ok = BetaRide.pick(player, "No Such Car")
	expect("a car that is not in the roster is refused", ok, false)
	ok = BetaRide.pick(player, { "Putter" })
	expect("a table for a car id is refused", ok, false)
	ok = BetaRide.pick(player, "Rustbucket")
	expect("a World's Loaner is always yours to pick", ok, true)
	data.RideCar = "Pizza Runner"
	expect(
		"StartRun uses the car the client asks for when owned",
		BetaRide.startCarFor(player, "Downtown", "Putter"),
		"Putter"
	)
	expect("... else the saved RideCar", BetaRide.startCarFor(player, "Downtown", "Cruiser"), "Pizza Runner")
	expect("... a number is no car: the saved RideCar", BetaRide.startCarFor(player, "Downtown", 7), "Pizza Runner")
	local dusty = RosterFixtures.loaner("DustyHighway")
	expect(
		"... and a World's own Loaner when the pick is of another World",
		BetaRide.startCarFor(player, "DustyHighway", "Pizza Runner"),
		if dusty then dusty.id else "?"
	)
	data.Cars = { Putter = { Edition = 1, Copies = 0 } }
	expect("a car given up falls back to the default", BetaRide.rideCar(player), BetaRide.Default)
	local bad = { RideCar = "Not A Car", Cars = { Putter = { Edition = 1, Copies = 0 } } } :: any
	for k, v in BetaConfig.Template do
		if bad[k] == nil then
			bad[k] = if type(v) == "table" then table.clone(v) else v
		end
	end
	BetaData.sanitize(bad)
	expect("an unknown saved RideCar goes back to Putter", bad.RideCar, "Putter")
	end)
	data.Cars, data.RideCar = savedCars, savedRide
	if not ran then
		table.insert(lines, "FAIL the ride self-test stopped: " .. tostring(err))
	end
	BetaRide.publish(player)
	return lines
end

return BetaRide
