--!strict
-- BETA-ONLY STAND-IN for the Stunt Circuit timing Brian R's Circuit and Brian L's server will own (Round 6, C-01, C-03).
-- Same contract: the client says what happened (CircuitStart, CircuitCheckpoint, CircuitFinish, CircuitEnd); the SERVER
-- keeps the clock and decides the time. Delete when his real module lands.
--
-- The events are Lane 3's proposal to Brian R (vault/design/specs/lane3-round6-for-brian-r.md, question 5), names only, no
-- amounts. His Circuit does not report them yet, so today the client's StuntCircuitFeed drives them from a PREVIEW lap.
--   CircuitEvent (RemoteEvent, client -> server): (kind: string, index: number?)
--     "CircuitStart"                 starts this player's lap clock (a restart replaces the lap)
--     "CircuitCheckpoint", index     must be the next checkpoint in order, at least MIN_SPLIT seconds after the last
--     "CircuitFinish"                counts only after every checkpoint and at least MIN_LAP seconds; time = server clock
--     "CircuitEnd"                   a crash or a quit: the lap ends with no time
--   CircuitResult (RemoteEvent, server -> client): (finished: boolean, time: number?, bestBefore: number?)
-- This server's board (C-03): the best time of each player in THIS server only, live, published as the CarHopBetaNet
-- attribute CircuitBoard = "userId|name|time;..." fastest first (at most 10). It forgets a player who leaves. No
-- cross-server data (no OrderedDataStore, MemoryStore or MessagingService), and no reward is paid from a time.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BetaConfig = require(ReplicatedStorage.Shared.Beta.BetaConfig)

local BetaCircuit = {}

BetaCircuit.open = BetaConfig.CircuitOpen -- Round 7 (A-03): false, the Circuit is Coming soon (the self-test opens it briefly)

BetaCircuit.EventRemote = "CircuitEvent"
BetaCircuit.ResultRemote = "CircuitResult"
BetaCircuit.BoardAttribute = "CircuitBoard"
BetaCircuit.Checkpoints = 5 -- the PREVIEW lap's checkpoints (Brian R's course sets the real number)
BetaCircuit.MinSplit = 1.0 -- seconds between checkpoints (Tunable)
BetaCircuit.MinLap = 8.0 -- seconds for a whole lap (Tunable)
BetaCircuit.MaxLap = 600

type Lap = { started: number, next: number, last: number }

local laps: { [Player]: Lap } = {}
local bests: { [Player]: number } = {}
local lastEvent: { [Player]: number } = {}
local net: Folder? = nil
local resultRemote: RemoteEvent? = nil
local quiet = false -- the self-test: its fake laps never reach the player's screen

local function log(player: Player, what: string)
	print(string.format("[CarHopBeta circuit] %s (%d): %s", player.Name, player.UserId, what))
end

function BetaCircuit.publish()
	local rows = {}
	for player, time in bests do
		if player.Parent == Players then
			table.insert(rows, { player = player, time = time })
		end
	end
	table.sort(rows, function(a, b)
		return a.time < b.time
	end)
	local parts = {}
	for i = 1, math.min(#rows, 10) do
		local row = rows[i]
		local name = string.gsub(row.player.DisplayName, "[|;]", " ")
		table.insert(parts, string.format("%d|%s|%.2f", row.player.UserId, name, row.time))
	end
	if net then
		net:SetAttribute(BetaCircuit.BoardAttribute, table.concat(parts, ";"))
	end
end

-- One event (apart from the remote so the self-test can call it, with `now` given). Returns a short status.
function BetaCircuit.event(player: Player, kind: any, index: any, now: number): string
	if not BetaCircuit.open then
		return "closed: the Stunt Circuit is Coming soon (Round 7, A-03)"
	end
	if type(kind) ~= "string" then
		return "bad kind"
	end
	local lap = laps[player]
	if kind == "CircuitStart" then
		laps[player] = { started = now, next = 1, last = now }
		return "started"
	end
	if not lap then
		return "no lap"
	end
	if kind == "CircuitCheckpoint" then
		if type(index) ~= "number" or index ~= lap.next then
			return "checkpoint out of order"
		end
		if now - lap.last < BetaCircuit.MinSplit then
			return "checkpoint too soon"
		end
		lap.next += 1
		lap.last = now
		return "checkpoint " .. index
	elseif kind == "CircuitFinish" then
		laps[player] = nil
		local time = now - lap.started
		if lap.next <= BetaCircuit.Checkpoints then
			return "finish before every checkpoint"
		end
		if time < BetaCircuit.MinLap or time > BetaCircuit.MaxLap then
			return "lap time out of range"
		end
		time = math.floor(time * 100) / 100
		local before = bests[player]
		if before == nil or time < before then
			bests[player] = time
			if not quiet then
				BetaCircuit.publish()
			end
		end
		if resultRemote and not quiet then
			resultRemote:FireClient(player, true, time, before)
		end
		return string.format("finished %.2f", time)
	elseif kind == "CircuitEnd" then
		laps[player] = nil
		if resultRemote and not quiet then
			resultRemote:FireClient(player, false, nil, bests[player])
		end
		return "ended"
	end
	return "unknown kind"
end

function BetaCircuit.start(folder: Folder)
	net = folder
	local remote = Instance.new("RemoteEvent")
	remote.Name = BetaCircuit.EventRemote
	remote.Parent = folder
	local result = Instance.new("RemoteEvent")
	result.Name = BetaCircuit.ResultRemote
	result.Parent = folder
	resultRemote = result
	folder:SetAttribute(BetaCircuit.BoardAttribute, "")
	remote.OnServerEvent:Connect(function(player: Player, kind: any, index: any)
		local now = os.clock()
		if now - (lastEvent[player] or -math.huge) < 0.2 then
			log(player, "too many Circuit events: dropped")
			return
		end
		lastEvent[player] = now
		local status = BetaCircuit.event(player, kind, index, now)
		if status ~= "started" and string.sub(status, 1, 10) ~= "checkpoint" then
			log(player, tostring(kind) .. ": " .. status)
		end
	end)
	Players.PlayerRemoving:Connect(function(player: Player)
		laps[player] = nil
		bests[player] = nil
		lastEvent[player] = nil
		BetaCircuit.publish()
	end)
end

function BetaCircuit.selfTest(player: Player): { string }
	local wasOpen = BetaCircuit.open
	local closedStatus = BetaCircuit.event(player, "start", nil, os.clock())
	BetaCircuit.open = true
	local ok, lines = pcall(BetaCircuit.selfTestOpen, player)
	BetaCircuit.open = wasOpen
	local out: { string } = if ok then lines else { "FAIL error: " .. tostring(lines) }
	table.insert(
		out,
		1,
		(if wasOpen or string.sub(closedStatus, 1, 6) == "closed" then "PASS" else "FAIL")
			.. " A-03 a closed Circuit refuses a lap start: "
			.. closedStatus
	)
	return out
end

function BetaCircuit.selfTestOpen(player: Player): { string }
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
	local savedBest = bests[player]
	bests[player] = nil
	quiet = true
	expect("a finish with no start is refused", BetaCircuit.event(player, "CircuitFinish", nil, 0), "no lap")
	BetaCircuit.event(player, "CircuitStart", nil, 100)
	expect(
		"a checkpoint out of order is refused",
		BetaCircuit.event(player, "CircuitCheckpoint", 2, 102),
		"checkpoint out of order"
	)
	expect(
		"a checkpoint too soon is refused",
		BetaCircuit.event(player, "CircuitCheckpoint", 1, 100.2),
		"checkpoint too soon"
	)
	expect(
		"an early finish is refused",
		BetaCircuit.event(player, "CircuitFinish", nil, 103),
		"finish before every checkpoint"
	)
	BetaCircuit.event(player, "CircuitStart", nil, 200)
	for i = 1, BetaCircuit.Checkpoints do
		BetaCircuit.event(player, "CircuitCheckpoint", i, 200 + i * 3)
	end
	expect(
		"a whole lap is timed by the server",
		BetaCircuit.event(player, "CircuitFinish", nil, 219.456),
		"finished 19.45"
	)
	expect("the best is kept", bests[player], 19.45)
	BetaCircuit.event(player, "CircuitStart", nil, 300)
	expect("a crash ends the lap", BetaCircuit.event(player, "CircuitEnd", nil, 301), "ended")
	expect("a wrong kind is refused", BetaCircuit.event(player, { 1 }, nil, 302), "bad kind")
	bests[player] = savedBest
	quiet = false
	BetaCircuit.publish()
	return lines
end

return BetaCircuit
