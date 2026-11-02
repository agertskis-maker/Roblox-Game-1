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
end

function Economy.addCash(player: Player, amount: number, reason: string)
	local data = Data.get(player)
	if not data or amount ~= amount or amount <= 0 or amount == math.huge then
		return
	end
	data.Cash += math.floor(amount)
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

-- Fills the Lineup with the owned cars that pay most, up to the parking spots owned. The real
-- game lets the player pick (the proposed SetLineupSlot remote); the preview has no picker UI.
function Economy.refreshLineup(player: Player)
	local data = Data.get(player)
	if not data then
		return
	end
	local owned: { string } = {}
	for id in data.Cars do
		if Cars.exists(id) then
			table.insert(owned, id)
		end
	end
	table.sort(owned, function(a, b)
		local pa, pb = lapPayOf(data, a), lapPayOf(data, b)
		if pa ~= pb then
			return pa > pb
		end
		return a < b
	end)
	local lineup: { string } = {}
	for i = 1, math.min(#owned, data.ParkingSpots) do
		lineup[i] = owned[i]
	end
	data.Lineup = lineup
	Economy.PlotChanged:Fire(player)
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
	Economy.refreshLineup(player)
	return true
end

-- A Joyride on an owned car (server-checked by the run report before this is called): pays the
-- Joyride Bonus and adds copies, which merge into the next edition every CopiesPerEdition.
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
