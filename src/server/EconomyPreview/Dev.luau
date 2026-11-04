--!strict
-- Studio-only test helpers for the economy PREVIEW (Lane 2). They stand in for the run report
-- (claims and Joyrides) until Lane 1's run is connected. A command bar or plugin gets its own
-- copy of every module, so in Studio the preview also exposes these through the BindableFunction
-- ServerStorage.EconomyPreviewDev, which runs them inside the game's server, for example:
--   game.ServerStorage.EconomyPreviewDev:Invoke("giveCar", game.Players:GetPlayers()[1], "Zip")
-- Outside Studio every helper refuses and the BindableFunction is never made.

local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local Data = require(script.Parent.Data)
local Economy = require(script.Parent.Economy)
local LapPay = require(script.Parent.LapPay)
local Runs = require(script.Parent.Runs)
local Shop = require(script.Parent.Shop)

local Dev = {}

local function allowed(): boolean
	if not RunService:IsStudio() then
		warn("[EconomyPreview] Dev helpers only work in Studio")
		return false
	end
	return true
end

-- Claims a car as if it was won in a run (pays the new-claim bonus).
function Dev.giveCar(player: Player, id: string): boolean
	return allowed() and Economy.claimCar(player, id)
end

-- Joyrides an owned car `count` times: pays the bonus and adds copies toward its next edition.
function Dev.joyride(player: Player, id: string, count: number)
	if allowed() then
		Economy.joyride(player, id, count)
	end
end

function Dev.giveCash(player: Player, amount: number)
	if allowed() then
		Economy.addCash(player, amount, "Dev")
	end
end

-- Pretends the player left `seconds` ago, then pays offline earnings as on a rejoin.
function Dev.simulateOffline(player: Player, seconds: number)
	local data = Data.get(player)
	if allowed() and data then
		data.LastSeen = os.time() - seconds
		LapPay.payOffline(player)
	end
end

-- A read-only copy of the player's preview save, for checking results.
function Dev.snapshot(player: Player): Data.SaveData?
	local data = Data.get(player)
	return if allowed() and data then table.clone(data) else nil
end

function Dev.buyRacewayLevel(player: Player): boolean
	return allowed() and Shop.buyRacewayLevel(player)
end

function Dev.buyParkingSpot(player: Player): boolean
	return allowed() and Shop.buyParkingSpot(player)
end

function Dev.unlockWorld(player: Player, worldId: string): boolean
	return allowed() and Economy.unlockWorld(player, worldId)
end

function Dev.setLineupSlot(player: Player, slot: number, id: string): boolean
	return allowed() and Economy.setLineupSlot(player, slot, id)
end

-- A scripted run through the real run report checks: starts a run, rides spawn `index` for
-- `seconds`, sends KeysComplete, then ends the run at `endMetres`. `cheat` sends Keys too early.
function Dev.fakeRun(
	player: Player,
	worldId: string,
	index: number,
	seconds: number,
	cheat: boolean?
): { [string]: any }
	if not allowed() then
		return {}
	end
	local started = Runs.start(player, worldId)
	if not started then
		return { started = false }
	end
	local run = Runs.active(player)
	run.started -= 600 -- pretend the run has been going for 10 minutes, so event times are plausible
	local spawn = run.sequence:ensure(5_000)[index]
	local t0 = 5
	local d0 = run.sequence:alongAt(spawn, t0)
	local t1 = t0 + (if cheat then 0.5 else seconds)
	local d1 = run.sequence:alongAt(spawn, t1)
	Runs.report(player, started.runId, {
		{ kind = "Hop", t = t0, d = d0, target = index },
		{ kind = "KeysComplete", t = t1, d = d1, index = index },
		{ kind = "KeysComplete", t = t1 + 0.1, d = d1, index = index },
		{ kind = "RunEnd", t = t1 + 30, d = d1 + 1_200, cause = "Meltdown" },
	})
	return {
		started = true,
		seed = started.seed,
		rarity = spawn.rarity,
		car = Runs.carFor(worldId, spawn),
	}
end

function Dev.expose()
	if not RunService:IsStudio() then
		return
	end
	local bridge = Instance.new("BindableFunction")
	bridge.Name = "EconomyPreviewDev"
	bridge.OnInvoke = function(name: string, player: Player, ...: any): any
		local fn = (Dev :: any)[name]
		if typeof(fn) ~= "function" or name == "expose" then
			error("unknown Dev helper " .. tostring(name))
		end
		return fn(player, ...)
	end
	bridge.Parent = ServerStorage
end

return Dev
