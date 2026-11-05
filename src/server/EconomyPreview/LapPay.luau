--!strict
-- Lap Pay on a server timer (Lane 2, PREVIEW). Each Lineup car pays once every LapSeconds; the
-- cars are staggered so payouts arrive at different moments. Pays while the player is anywhere
-- in the server, including mid-run. Also pays offline earnings on join.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Catalog = require(ReplicatedStorage.Shared.Catalog.EconomyPreview)
local Signal = require(ReplicatedStorage.Packages.Signal)
local Trove = require(ReplicatedStorage.Packages.Trove)
local Data = require(script.Parent.Data)
local Economy = require(script.Parent.Economy)

local LapPay = {}

local troves: { [Player]: any } = {}

-- Fires on the server for every lap paid: (player, carId, amount). Lane 3's Lap Pay pop and
-- flag official will need these on the client later (a contract still to agree).
LapPay.Lap = Signal.new()

function LapPay.payOffline(player: Player)
	local data = Data.get(player)
	if not data then
		return
	end
	local now = os.time()
	if data.LastSeen > 0 and now > data.LastSeen then
		local amount = Catalog.offlinePay(Economy.lineupPayPerLap(player), now - data.LastSeen)
		if amount > 0 then
			Economy.addCash(player, amount, "Offline")
			player:SetAttribute("OfflineEarned", amount)
		end
	end
	data.LastSeen = now
end

function LapPay.start(player: Player)
	LapPay.stop(player)
	local trove = Trove.new()
	troves[player] = trove
	trove:Add(task.spawn(function()
		local slot = 0
		while true do
			local data = Data.get(player)
			if not data then
				return
			end
			local count = #data.Lineup
			if count == 0 then
				task.wait(1)
			else
				task.wait(Catalog.LapSeconds / count)
				data = Data.get(player)
				if not data or #data.Lineup == 0 then
					continue
				end
				slot = slot % #data.Lineup + 1
				local id = data.Lineup[slot]
				local amount = Economy.lapPayFor(player, id)
				if amount > 0 then
					Economy.addCash(player, amount, "Lap")
					LapPay.Lap:Fire(player, id, amount)
				end
				data.LastSeen = os.time()
			end
		end
	end))
end

function LapPay.stop(player: Player)
	local trove = troves[player]
	if trove then
		troves[player] = nil
		trove:Destroy()
	end
end

return LapPay
