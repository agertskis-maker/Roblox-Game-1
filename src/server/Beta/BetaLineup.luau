--!strict
-- CATCH A CAR! BETA (Round 4, C-10): the BETA-ONLY STAND-IN for Brian L's agreed remote SetLineupSlot (slot, carId), to be
-- replaced by his real one. Same name and arguments as the contract (economy v1 section 13, decision 0036); it reads and
-- writes only the agreed fields Cars, Lineup and ParkingSpots of the caller's own beta save.
--
-- The player is the server-supplied sender, never an argument. Every argument is checked as hostile:
--   slot    an integer from 1 to the caller's ParkingSpots, and no further than the end of the Lineup + 1 (no holes: a saved
--           array with gaps does not survive the DataStore, so a car always goes into the next free slot or a filled one)
--   carId   nil (take the car in that slot out; the cars behind it move up one) or a string naming a car in the roster that
--           the caller owns (Cars[carId]) and that is not already in another slot of the Lineup
-- plus a short per-player cooldown. A refused request changes nothing. The Lineup is replicated read-only as the player
-- attribute BetaLineup ("Putter,Minnow").

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BetaConfig = require(ReplicatedStorage.Shared.Beta.BetaConfig)
local BetaData = require(script.Parent.BetaData)
local BetaPlots = require(script.Parent.BetaPlots)
local RosterFixtures = require(ReplicatedStorage.Shared.UI.RosterFixtures)

local BetaLineup = {}

local COOLDOWN = 0.3
local lastSet: { [Player]: number } = {}

type Save = { ParkingSpots: number, Cars: { [string]: any }, Lineup: { string } }

local function publish(player: Player, data: Save)
	player:SetAttribute(BetaConfig.LineupAttribute, table.concat(data.Lineup, ","))
end

-- The checks, apart from the remote so a test can call them: returns ok and a reason.
-- `spots` (optional) is the plot's spot count when it differs from the saved one (the Expanded Paddock pass adds 3).
function BetaLineup.apply(data: Save, slot: any, carId: any, spots: number?): (boolean, string)
	if type(slot) ~= "number" or slot ~= slot or slot % 1 ~= 0 then
		return false, "slot is not a whole number"
	end
	if slot < 1 or slot > (spots or data.ParkingSpots) then
		return false, "slot outside the owned parking spots"
	end
	local lineup = data.Lineup
	if slot > #lineup + 1 then
		return false, "slot leaves a gap"
	end
	if carId == nil then
		if lineup[slot] == nil then
			return false, "slot already empty"
		end
		table.remove(lineup, slot)
		return true, "removed"
	end
	if type(carId) ~= "string" or #carId > 64 or RosterFixtures.byId(carId) == nil then
		return false, "unknown car"
	end
	if data.Cars[carId] == nil then
		return false, "car not owned"
	end
	local at = table.find(lineup, carId)
	if at ~= nil and at ~= slot then
		return false, "car already in the Lineup"
	end
	lineup[slot] = carId
	return true, "placed"
end

function BetaLineup.start(net: Folder)
	local remote = Instance.new("RemoteEvent")
	remote.Name = BetaConfig.Remotes.SetLineupSlot
	remote.Parent = net
	BetaData.Loaded:Connect(function(player: Player, data: any)
		publish(player, data :: Save)
	end)
	remote.OnServerEvent:Connect(function(player: Player, slot: any, carId: any)
		local now = os.clock()
		if now - (lastSet[player] or -math.huge) < COOLDOWN then
			return
		end
		lastSet[player] = now
		local data = BetaData.get(player) :: any
		if not data then
			return
		end
		local ok, why = BetaLineup.apply(data :: Save, slot, carId, BetaPlots.spotsOf(player))
		if ok then
			publish(player, data :: Save)
		else
			print(string.format("[CarHopBeta] SetLineupSlot refused for %s: %s", player.Name, why))
		end
	end)
	Players.PlayerRemoving:Connect(function(player: Player)
		lastSet[player] = nil
	end)
end

-- From the command bar: print(require(game.ServerScriptService.Server.Beta.BetaLineup).selfTest())
function BetaLineup.selfTest(): { string }
	local failures: { string } = {}
	local function case(name: string, data: Save, slot: any, carId: any, wantOk: boolean, wantLineup: string)
		local ok = BetaLineup.apply(data, slot, carId)
		local got = table.concat(data.Lineup, ",")
		if ok ~= wantOk or got ~= wantLineup then
			table.insert(failures, string.format("%s: ok=%s lineup=%s", name, tostring(ok), got))
		end
	end
	local function save(): Save
		return { ParkingSpots = 3, Cars = { Putter = {}, Minnow = {} }, Lineup = { "Putter" } }
	end
	case("place owned in next slot", save(), 2, "Minnow", true, "Putter,Minnow")
	case("unowned car", save(), 2, "Bolt", false, "Putter")
	case("unknown car", save(), 2, "Hyperion", false, "Putter")
	case("duplicate", save(), 2, "Putter", false, "Putter")
	case("same car same slot", save(), 1, "Putter", true, "Putter")
	case("slot beyond spots", save(), 4, "Minnow", false, "Putter")
	case("gap", save(), 3, "Minnow", false, "Putter")
	case("not integer", save(), 1.5, "Minnow", false, "Putter")
	case("NaN", save(), 0 / 0, "Minnow", false, "Putter")
	case("string slot", save(), "1", "Minnow", false, "Putter")
	case("table car", save(), 2, {}, false, "Putter")
	case("remove", save(), 1, nil, true, "")
	case("remove empty", save(), 2, nil, false, "Putter")
	return failures
end

return BetaLineup
