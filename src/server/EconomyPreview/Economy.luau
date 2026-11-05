--!strict
-- Cash, cars, editions and the Lineup on the server (Lane 2, PREVIEW). Every amount is computed
-- here from the Catalog; nothing comes from a client. State is shown read-only: the player
-- attributes "Cash" (number) and "CashText" (for example "$1.2K"), plus a leaderstats entry so
-- the preview has a Cash read-out before Lane 3's HUD is connected.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Catalog = require(ReplicatedStorage.Shared.Catalog.EconomyPreview)
local Signal = require(ReplicatedStorage.Packages.Signal)
local Cars = require(script.Parent.Cars)
local Data = require(script.Parent.Data)

local Economy = {}

-- Fires (player) whenever a player's Raceway, parking or Lineup changes.
Economy.PlotChanged = Signal.new()

local function publishCash(player: Player, data: Data.SaveData)
	player:SetAttribute("Cash", data.Cash)
	local text = Catalog.formatCash(data.Cash)
	player:SetAttribute("CashText", text)
	local stats = player:FindFirstChild("leaderstats")
	local value = stats and stats:FindFirstChild("Cash")
	if value and value:IsA("StringValue") then
		value.Value = text
	end
end

function Economy.setup(player: Player, data: Data.SaveData)
	local stats = Instance.new("Folder")
	stats.Name = "leaderstats"
	local cash = Instance.new("StringValue")
	cash.Name = "Cash"
	cash.Parent = stats
	stats.Parent = player
	publishCash(player, data)
	player:SetAttribute("WorldsUnlocked", Economy.worldsText(player))
end

function Economy.addCash(player: Player, amount: number, reason: string)
	local data = Data.get(player)
	if not data or amount ~= amount or amount <= 0 or amount == math.huge then
		return
	end
	data.Cash = math.min(data.Cash + math.floor(amount), Catalog.MaxCash)
	publishCash(player, data)
	if reason ~= "Lap" then
		print(string.format("[EconomyPreview] %s +%s (%s)", player.Name, Catalog.formatCash(amount), reason))
	end
end

-- Takes `price` if the player can afford it. Returns whether it was paid.
function Economy.trySpend(player: Player, price: number): boolean
	local data = Data.get(player)
	if not data or data.Cash < price then
		return false
	end
	data.Cash -= price
	publishCash(player, data)
	return true
end

local function lapPayOf(data: Data.SaveData, id: string): number
	local rarity = Cars.rarity(id)
	local car = data.Cars[id]
	if not rarity or not car then
		return 0
	end
	return Catalog.lapPay(rarity, car.Edition, data.RacewayLevel)
end

-- Keeps the Lineup valid: drops cars that are not owned or do not exist and trims it to the parking
-- spots owned, with no gaps. The player's choices stay as they are, so a spot the player emptied
-- stays empty (Adam's review A3, agreed by Brian L on 2026-11-05). Only `newCar`, a car just
-- claimed, is placed automatically, in the first free spot if there is one.
function Economy.refreshLineup(player: Player, newCar: string?)
	local data = Data.get(player)
	if not data then
		return
	end
	local lineup: { string } = {}
	local used: { [string]: boolean } = {}
	for _, id in data.Lineup do
		if #lineup < data.ParkingSpots and data.Cars[id] and Cars.exists(id) and not used[id] then
			table.insert(lineup, id)
			used[id] = true
		end
	end
	if newCar and #lineup < data.ParkingSpots and data.Cars[newCar] and Cars.exists(newCar) and not used[newCar] then
		table.insert(lineup, newCar)
	end
	data.Lineup = lineup
	Economy.PlotChanged:Fire(player)
end

-- Puts an owned car into Lineup spot `slot` (1 to the parking spots owned). If the car already
-- drives in another spot, the two swap. `id = nil` takes the car in `slot` out and the cars after
-- it move up. Returns whether anything changed.
function Economy.setLineupSlot(player: Player, slot: number, id: string?): boolean
	local data = Data.get(player)
	if not data or slot ~= math.floor(slot) or slot < 1 then
		return false
	end
	if id == nil then
		if slot > #data.Lineup then
			return false
		end
		table.remove(data.Lineup, slot)
		Economy.refreshLineup(player)
		return true
	end
	if not data.Cars[id] or not Cars.exists(id) then
		return false
	end
	if slot > math.min(data.ParkingSpots, #data.Lineup + 1) then
		return false
	end
	local current = table.find(data.Lineup, id)
	if current == slot then
		return false
	end
	if current then
		data.Lineup[current] = data.Lineup[slot]
	end
	data.Lineup[slot] = id
	Economy.refreshLineup(player)
	return true
end

-- How many cars the player owns from one World (unique models, editions do not count extra).
function Economy.ownedInWorld(player: Player, worldId: string): number
	local data = Data.get(player)
	local count = 0
	if data then
		for id in data.Cars do
			if Catalog.CarWorld[id] == worldId then
				count += 1
			end
		end
	end
	return count
end

-- Unlocks the next World: it must exist, be locked, follow an unlocked World, and the player must
-- own enough cars from the World before it and afford its price.
function Economy.unlockWorld(player: Player, worldId: string): boolean
	local data = Data.get(player)
	local info, index = Catalog.world(worldId)
	if not data or not info or not index or index == 1 or data.WorldsUnlocked[worldId] then
		return false
	end
	local previous = Catalog.Worlds[index - 1]
	if not data.WorldsUnlocked[previous.id] then
		return false
	end
	if Economy.ownedInWorld(player, previous.id) < info.carsNeeded then
		return false
	end
	if not Economy.trySpend(player, info.price) then
		return false
	end
	data.WorldsUnlocked[worldId] = true
	player:SetAttribute("WorldsUnlocked", Economy.worldsText(player))
	print(string.format("[EconomyPreview] %s unlocked %s", player.Name, worldId))
	return true
end

-- Read-only list for the client, for example "Downtown,DustyHighway".
function Economy.worldsText(player: Player): string
	local data = Data.get(player)
	local list: { string } = {}
	if data then
		for _, info in Catalog.Worlds do
			if data.WorldsUnlocked[info.id] then
				table.insert(list, info.id)
			end
		end
	end
	return table.concat(list, ",")
end

function Economy.lineupPayPerLap(player: Player): number
	local data = Data.get(player)
	if not data then
		return 0
	end
	local total = 0
	for _, id in data.Lineup do
		total += lapPayOf(data, id)
	end
	return total
end

function Economy.lapPayFor(player: Player, id: string): number
	local data = Data.get(player)
	return if data then lapPayOf(data, id) else 0
end

-- A new car claimed in a run (server-checked by the run report before this is called).
function Economy.claimCar(player: Player, id: string): boolean
	local data = Data.get(player)
	local rarity = Cars.rarity(id)
	if not data or not rarity or data.Cars[id] then
		return false
	end
	data.Cars[id] = { Edition = 1, Copies = 0 }
	Economy.addCash(player, Catalog.Rarities[rarity].claimBonus, "Claim " .. id)
	Economy.refreshLineup(player, id)
	return true
end

-- A Joyride on an owned car (server-checked by the run report before this is called): pays the
-- Joyride Bonus and adds copies, which merge into the next edition at the Catalog's EditionCopies totals.
function Economy.joyride(player: Player, id: string, copies: number?)
	local data = Data.get(player)
	local rarity = Cars.rarity(id)
	local car = data and data.Cars[id]
	if not data or not rarity or not car then
		return
	end
	local count = math.max(1, math.floor(copies or 1))
	Economy.addCash(player, Catalog.joyrideBonus(rarity, car.Edition) * count, "Joyride " .. id)
	local before = car.Edition
	car.Edition, car.Copies = Catalog.addCopies(car.Edition, car.Copies, count)
	if car.Edition ~= before then
		print(string.format("[EconomyPreview] %s's %s is now %s", player.Name, id, Catalog.editionName(car.Edition)))
		Economy.refreshLineup(player)
	end
end

return Economy
