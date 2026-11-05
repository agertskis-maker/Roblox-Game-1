--!strict
-- Raceway level and parking spot purchases (Lane 2, PREVIEW). Two ways in, both handled here:
-- the argument-less remotes (for Lane 3's shop panel once it is connected) and two server-made
-- ProximityPrompts on the owner's plot gate, so the preview can be bought without client code.
-- Every purchase checks: profile loaded, not at the maximum, enough Cash, cooldown.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Catalog = require(ReplicatedStorage.Shared.Catalog.EconomyPreview)
local Net = require(ReplicatedStorage.Shared.Net.EconomyPreviewNet)
local Data = require(script.Parent.Data)
local Economy = require(script.Parent.Economy)
local Plots = require(script.Parent.Plots)
local Runs = require(script.Parent.Runs)

local COOLDOWN = 0.75

type PromptSet = { level: ProximityPrompt, spot: ProximityPrompt }

local Shop = {}

local lastBuy: { [Player]: number } = {}
local prompts: { [Player]: PromptSet } = {}

local function cooled(player: Player): boolean
	local now = os.clock()
	local last = lastBuy[player]
	if last and now - last < COOLDOWN then
		return false
	end
	lastBuy[player] = now
	return true
end

local function label(price: number?, action: string, maxed: string): (string, boolean)
	if price then
		return action .. " " .. Catalog.formatCash(price), true
	end
	return maxed, false
end

function Shop.refreshPrompts(player: Player)
	local data = Data.get(player)
	local set = prompts[player]
	if not data or not set then
		return
	end
	local levelText, levelOk = label(Catalog.racewayPrice(data.RacewayLevel + 1), "Level up", "Raceway maxed")
	set.level.ActionText = levelText
	set.level.ObjectText = "Raceway level " .. data.RacewayLevel .. " (PREVIEW)"
	set.level.Enabled = levelOk
	local spotText, spotOk = label(Catalog.parkingSpotPrice(data.ParkingSpots + 1), "Buy spot", "All spots owned")
	set.spot.ActionText = spotText
	set.spot.ObjectText = "Parking " .. data.ParkingSpots .. " / " .. Catalog.MaxParkingSpots .. " (PREVIEW)"
	set.spot.Enabled = spotOk
end

function Shop.publish(player: Player)
	local data = Data.get(player)
	if data then
		Plots.publish(player, data.RacewayLevel, data.ParkingSpots)
	end
	Shop.refreshPrompts(player)
end

function Shop.buyRacewayLevel(player: Player): boolean
	local data = Data.get(player)
	if not data or not cooled(player) then
		return false
	end
	local price = Catalog.racewayPrice(data.RacewayLevel + 1)
	if not price or not Economy.trySpend(player, price) then
		return false
	end
	data.RacewayLevel += 1
	print(string.format("[EconomyPreview] %s bought Raceway level %d", player.Name, data.RacewayLevel))
	Shop.publish(player)
	return true
end

function Shop.buyParkingSpot(player: Player): boolean
	local data = Data.get(player)
	if not data or not cooled(player) then
		return false
	end
	local price = Catalog.parkingSpotPrice(data.ParkingSpots + 1)
	if not price or not Economy.trySpend(player, price) then
		return false
	end
	data.ParkingSpots += 1
	print(string.format("[EconomyPreview] %s bought parking spot %d", player.Name, data.ParkingSpots))
	Economy.refreshLineup(player)
	Shop.publish(player)
	return true
end

local function makePrompt(parent: BasePart, key: Enum.KeyCode, offset: Vector2): ProximityPrompt
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "EconomyPreviewPrompt"
	prompt.KeyboardKeyCode = key
	prompt.UIOffset = offset
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt.Parent = parent
	return prompt
end

function Shop.addPrompts(player: Player)
	Shop.removePrompts(player)
	local plot = Plots.of(player)
	local anchor = plot and plot:FindFirstChild("Markers")
	if not anchor or not anchor:IsA("BasePart") then
		return
	end
	local set: PromptSet = {
		level = makePrompt(anchor, Enum.KeyCode.E, Vector2.new(0, 0)),
		spot = makePrompt(anchor, Enum.KeyCode.F, Vector2.new(0, 72)),
	}
	-- Triggered runs on the server for the player in range; only the plot's owner can buy.
	set.level.Triggered:Connect(function(who: Player)
		if who == player then
			Shop.buyRacewayLevel(who)
		end
	end)
	set.spot.Triggered:Connect(function(who: Player)
		if who == player then
			Shop.buyParkingSpot(who)
		end
	end)
	prompts[player] = set
	Shop.refreshPrompts(player)
end

function Shop.removePrompts(player: Player)
	local set = prompts[player]
	if set then
		prompts[player] = nil
		set.level:Destroy()
		set.spot:Destroy()
	end
	lastBuy[player] = nil
end

function Shop.createRemotes()
	local folder = Instance.new("Folder")
	folder.Name = Net.FolderName
	local level = Instance.new("RemoteEvent")
	level.Name = Net.Remotes.BuyRacewayLevel
	level.Parent = folder
	local spot = Instance.new("RemoteEvent")
	spot.Name = Net.Remotes.BuyParkingSpot
	spot.Parent = folder
	-- Both remotes take no arguments; anything a client sends is ignored.
	level.OnServerEvent:Connect(function(player: Player)
		Shop.buyRacewayLevel(player)
	end)
	spot.OnServerEvent:Connect(function(player: Player)
		Shop.buyParkingSpot(player)
	end)

	local function remote(name: string): RemoteEvent
		local r = Instance.new("RemoteEvent")
		r.Name = name
		r.Parent = folder
		return r
	end

	remote(Net.Remotes.UnlockWorld).OnServerEvent:Connect(function(player: Player, worldId: unknown)
		if typeof(worldId) == "string" and #worldId <= 40 and cooled(player) then
			if Economy.unlockWorld(player, worldId) then
				Shop.publish(player)
			end
		end
	end)
	remote(Net.Remotes.SetLineupSlot).OnServerEvent:Connect(function(player: Player, slot: unknown, carId: unknown)
		if typeof(slot) == "number" and typeof(carId) == "string" and #carId <= 60 and cooled(player) then
			Economy.setLineupSlot(player, slot, carId)
		end
	end)

	local startRun = Instance.new("RemoteFunction")
	startRun.Name = Net.Remotes.StartRun
	startRun.OnServerInvoke = function(player: Player, worldId: unknown): any
		return Runs.start(player, worldId)
	end
	startRun.Parent = folder

	-- At most BATCH_LIMIT run messages a second per player; the rest are dropped.
	local BATCH_LIMIT = 12
	local window: { [Player]: { at: number, count: number } } = {}
	local function allowRunMessage(player: Player): boolean
		local now = os.clock()
		local w = window[player]
		if not w or now - w.at >= 1 then
			window[player] = { at = now, count = 1 }
			return true
		end
		w.count += 1
		return w.count <= BATCH_LIMIT
	end
	remote(Net.Remotes.RunEvents).OnServerEvent:Connect(function(player: Player, runId: unknown, events: unknown)
		if allowRunMessage(player) then
			Runs.report(player, runId, events)
		end
	end)
	remote(Net.Remotes.KeysComplete).OnServerEvent:Connect(function(player: Player, runId: unknown, event: unknown)
		if allowRunMessage(player) then
			Runs.report(player, runId, { event })
		end
	end)
	local granted = remote(Net.Remotes.RunGranted)
	Runs.Granted:Connect(function(player: Player, result: { [string]: any })
		granted:FireClient(player, result)
	end)
	Players.PlayerRemoving:Connect(function(player: Player)
		window[player] = nil
	end)

	folder.Parent = ReplicatedStorage
end

return Shop
