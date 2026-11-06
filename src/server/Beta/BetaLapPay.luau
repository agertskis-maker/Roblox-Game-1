--!strict
-- BETA-ONLY STAND-IN for Brian L's LapPay (src/server/EconomyPreview/LapPay.luau on feature/lane2-economy-preview).
-- Same contract: each Lineup car pays its Lap Pay once a lap, on the server, while the owner is in the server.
-- Delete when his real module lands.
--
-- ONE scheduler for every plot (L-02): a single loop, ten times a second, walks the owners. Slot s of a plot pays at the
-- LapClock moments epoch + offset(s) + k * lap (src/shared/UI/LapClock). Whatever car is in slot s AT that moment is paid,
-- once; a swap, a removal or a re-add never adds a lap, and a slow server pays at most one lap per slot per check (a long
-- stall skips laps rather than paying a burst). The plot carries the epoch and lap length (BetaLapEpoch, BetaLapSeconds),
-- so the client draws the cars on the same clock. Lap Pay does not need a car model: it reads only the save.
-- Every client gets BetaLapPaid(plotIndex, slot, carId, amount) for the pop above that car; only the owner's copy carries
-- newCash. Stops the moment the owner leaves.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local BetaConfig = require(ReplicatedStorage.Shared.Beta.BetaConfig)
local BetaData = require(script.Parent.BetaData)
local BetaEconomy = require(script.Parent.BetaEconomy)
local BetaEvents = require(script.Parent.BetaEvents)
local BetaOwnership = require(script.Parent.BetaOwnership)
local BetaPlots = require(script.Parent.BetaPlots)
local EconomyPreview = require(ReplicatedStorage.Shared.UI.EconomyPreview)
local LapClock = require(ReplicatedStorage.Shared.UI.LapClock)
local Signal = require(ReplicatedStorage.Packages.Signal)

local BetaLapPay = {}

BetaLapPay.Lap = Signal.new() -- (player, slot, carId, amount), the same as his LapPay.Lap plus the slot

type Entry = { epoch: number, due: { [number]: number } }
local entries: { [Player]: Entry } = {}
local remote: RemoteEvent? = nil
local MAX_SLOTS = 18

local function now(): number
	return Workspace:GetServerTimeNow()
end

function BetaLapPay.begin(player: Player)
	local plot = BetaPlots.plotOf(player)
	if not plot then
		return
	end
	local epoch = now()
	entries[player] = { epoch = epoch, due = {} }
	plot:SetAttribute(BetaConfig.LapEpochAttribute, epoch)
	plot:SetAttribute(BetaConfig.LapSecondsAttribute, EconomyPreview.LapSeconds)
end

function BetaLapPay.stop(player: Player)
	entries[player] = nil
end

-- One pass of the scheduler at server time `t`. Returns the payouts made (for tests and the T-04 cost measure).
function BetaLapPay.tick(t: number): number
	local paid = 0
	local lap = EconomyPreview.LapSeconds
	for player, entry in entries do
		local data = BetaData.get(player)
		local plot = BetaPlots.plotOf(player)
		if not (data and plot) then
			continue
		end
		local plotIndex = player:GetAttribute(BetaConfig.HomePlotAttribute)
		for slot = 1, MAX_SLOTS do
			local due = entry.due[slot]
			if due == nil then
				entry.due[slot] = LapClock.nextDue(t, entry.epoch, slot, lap)
				continue
			end
			if t < due then
				continue
			end
			entry.due[slot] = LapClock.nextDue(t, entry.epoch, slot, lap) -- one payout, even after a stall
			local carId = data.Lineup[slot]
			if carId == nil then
				continue
			end
			-- Round 6 (R-04): Double Lap Pay doubles every Lap Pay on the server
			local amount = BetaEconomy.lapPayOf(data, carId)
				* (if BetaOwnership.owns(player, "double-lap-pay") then 2 else 1)
			if amount <= 0 then
				continue
			end
			BetaEconomy.addCash(player, amount, "Lap")
			paid += 1
			BetaLapPay.Lap:Fire(player, slot, carId, amount)
			BetaEvents.fire(player, "lap", { carId = carId, amount = amount }) -- Round 6 (G-01)
			if remote then
				for _, other in Players:GetPlayers() do
					remote:FireClient(other, plotIndex, slot, carId, amount, if other == player then data.Cash else nil)
				end
			end
		end
	end
	return paid
end

BetaLapPay.lastTickSeconds = 0 -- the cost of the last pass (T-04)

function BetaLapPay.start(net: Folder)
	local event = Instance.new("RemoteEvent")
	event.Name = BetaConfig.Remotes.LapPaid
	event.Parent = net
	remote = event
	BetaPlots.Assigned:Connect(BetaLapPay.begin)
	BetaData.Releasing:Connect(BetaLapPay.stop)
	Players.PlayerRemoving:Connect(BetaLapPay.stop)
	task.spawn(function()
		while true do
			task.wait(0.1)
			local c0 = os.clock()
			BetaLapPay.tick(now())
			BetaLapPay.lastTickSeconds = os.clock() - c0
		end
	end)
end

-- Pure checks of the schedule rules on a fake owner (no remotes, no save).
function BetaLapPay.selfTest(): { string }
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
	for _, f in LapClock.selfTest() do
		table.insert(lines, "FAIL LapClock " .. f)
	end
	-- a slot pays once per lap whatever happens to its car in between
	local lap, epoch = 15, 1000
	local due = LapClock.nextDue(epoch, epoch, 1, lap)
	expect("slot 1 first pays one lap after the epoch", due, 1015)
	local afterStall = LapClock.nextDue(1015 + 61, epoch, 1, lap)
	expect("a 61 s stall pays once, then waits for the next crossing", afterStall, 1090)
	local swapDue = LapClock.nextDue(1014.9, epoch, 1, lap)
	expect("a swap 0.1 s before the line keeps the same crossing", swapDue, 1015)
	return lines
end

return BetaLapPay
