--!strict
-- BETA-ONLY STAND-IN for Brian L's run report checks (note 0021, Agreed 2026-10-28).
-- Same contract: the client reports what happened (t, d, x, target, index, cause); the server decides and pays.
-- Delete when his real module lands.
--
-- THE RUN REPORT IS CLIENT-TRUSTED IN THE BETA. Brian R's run is client-only, so the server cannot re-check what the
-- player did; it accepts what the client reports, inside the hard caps below, and logs it. This is scaffolding for a
-- private playtest among three people. It is deleted when Lane 1 reports through the server and Lane 2 checks it.
--
-- What the server does derive itself: the seed (BetaRunStart hands it out, as 0021 says), so it rebuilds the run's
-- traffic with Brian R's RunSequence and looks up which car a spawn index is. The client may add `betaModel` (beta-only)
-- to an event; it must match the server's own lookup, or the claim is dropped and logged. The client never sends a car
-- to grant, an amount or a result.
--
-- Hard caps (beta sanity, not security; Tunable, ledger L-03): claims per run at most the bolt count (5, 8 in the tutorial
-- run); 30 events per batch and 3 batches per second (0021: "a maximum number of events per batch and batches per second");
-- `d` (studs) never ahead of the run's own speed curve plus 1,500 studs, never backwards; `t` (seconds) never ahead of the
-- server's clock for the run by more than 3 s; one active run per player; unknown runId ignored. Over a cap: dropped and
-- logged with the UserId; the run keeps going.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BetaConfig = require(ReplicatedStorage.Shared.Beta.BetaConfig)
local BetaData = require(script.Parent.BetaData)
local BetaEconomy = require(script.Parent.BetaEconomy)
local BetaLineup = require(script.Parent.BetaLineup)
local BetaRunMap = require(ReplicatedStorage.Shared.Beta.BetaRunMap)
local EconomyPreview = require(ReplicatedStorage.Shared.UI.EconomyPreview)
local RosterFixtures = require(ReplicatedStorage.Shared.UI.RosterFixtures)
local RunConfig = require(ReplicatedStorage.Shared.Run.RunConfig)
local RunSequence = require(ReplicatedStorage.Shared.Run.RunSequence)

local BetaRun = {}

BetaRun.Caps = table.freeze({
	claims = 5, -- the bolt count (RunStamina.Max)
	tutorialClaims = 8, -- RunStamina.TutorialMax
	eventsPerBatch = 30,
	batchesPerSecond = 3,
	aheadStuds = 1500, -- d may lead the run's speed curve by this much (a hop onto a car far ahead)
	backStuds = 5,
	clockAhead = 3, -- seconds
	maxRunSeconds = 1800,
})
BetaRun.PROFILE = "Circuit" -- the profile the beta plays (BetaRun.client)

export type Grant = {
	kind: string, -- "claim" | "joyride" | "milestone"
	carId: string?,
	amount: number,
	newCash: number,
	parked: string?, -- claim only: "parked" | "full" | "held" | "owned"
	edition: number?,
	copies: number?,
	rose: boolean?,
	index: number?, -- the spawn index (claims and joyrides)
}

export type Totals = {
	metres: number,
	claims: number,
	joyrides: number,
	joyrideCash: number,
	claimCash: number,
	milestoneCash: number,
	total: number,
	cars: { { carId: string, parked: string } },
	cause: string,
	closed: boolean,
}

type Run = {
	id: string,
	player: Player,
	world: string,
	seed: number,
	sequence: any,
	started: number, -- os.clock()
	tutorial: boolean,
	lastD: number,
	lastT: number,
	batchTimes: { number },
	done: { [number]: boolean }, -- spawn indexes already paid this run
	milestones: number,
	totals: Totals,
	closed: boolean,
}

local runs: { [Player]: Run } = {}
local closedRuns: { [string]: Totals } = {} -- a short record so a late RunEnd retry gets the same reply
local closedOrder: { string } = {}
local remotes: { [string]: any } = {}
local nextId = 0

local function log(player: Player, what: string)
	print(string.format("[CarHopBeta run] %s (%d): %s", player.Name, player.UserId, what))
end

local function finite(n: any): boolean
	return type(n) == "number" and n == n and n ~= math.huge and n ~= -math.huge
end

-- The car a spawn index names, from the server's own copy of the run's sequence (d bounds how far it is built).
function BetaRun.carAt(run: Run, index: number, d: number): string?
	if not finite(index) or index % 1 ~= 0 or index < 1 or index > 100000 then
		return nil
	end
	local reach = math.max(d, 0) + run.sequence.profile.spawnAhead + 200
	run.sequence:ensure(math.min(reach, 2e6))
	local spawn = run.sequence:get(index)
	if not spawn then
		return nil
	end
	return BetaRunMap.carFor(run.world, spawn.family, spawn.rarity)
end

local function grantTo(run: Run, grant: Grant)
	local remote = remotes.granted
	if remote then
		remote:FireClient(run.player, run.id, grant)
	end
end

-- Checks t and d of one event against the caps; returns whether it may count. Updates the run's last t and d.
local function plausible(run: Run, t: any, d: any): (boolean, string?)
	if not finite(t) or not finite(d) then
		return false, "t or d is not a finite number"
	end
	local elapsed = os.clock() - run.started
	if t > elapsed + BetaRun.Caps.clockAhead then
		return false, string.format("t %.1f s is ahead of the server clock %.1f s", t, elapsed)
	end
	if t < run.lastT - 0.05 then
		return false, "events out of order"
	end
	if d < run.lastD - BetaRun.Caps.backStuds then
		return false, "d went backwards"
	end
	local most = run.sequence:travelledAt(math.max(t, 0)) + BetaRun.Caps.aheadStuds
	if d > most then
		return false, string.format("d %.0f studs is faster than the run allows (%.0f)", d, most)
	end
	run.lastT = math.max(run.lastT, t)
	run.lastD = math.max(run.lastD, d)
	return true, nil
end

local function milestones(run: Run)
	local step = EconomyPreview.MilestoneMetres
	local pay = EconomyPreview.Milestone[run.world] or 0
	local reached = math.floor(RunConfig.toMetres(run.lastD) / step)
	while run.milestones < reached do
		run.milestones += 1
		local added = BetaEconomy.addCash(run.player, pay, "Milestone " .. run.milestones * step .. " m")
		run.totals.milestoneCash += added
		local data = BetaData.get(run.player)
		grantTo(run, { kind = "milestone", amount = added, newCash = if data then data.Cash else 0 })
	end
end

-- One accepted KeysComplete: the server decides claim or Joyride. Returns the grant (nil when dropped).
function BetaRun.keysComplete(run: Run, index: any, d: number, betaModel: any): Grant?
	local player = run.player
	if run.done[index] then
		log(player, "KeysComplete repeated for spawn " .. tostring(index) .. ": nothing granted twice")
		return nil
	end
	local carId = BetaRun.carAt(run, index, d)
	if not carId then
		log(player, "KeysComplete for an unknown spawn " .. tostring(index) .. ": dropped")
		return nil
	end
	if betaModel ~= nil and betaModel ~= carId then
		log(
			player,
			string.format("betaModel %s does not match spawn %d (%s): dropped", tostring(betaModel), index, carId)
		)
		return nil
	end
	local data = BetaData.get(player)
	if not data then
		return nil
	end
	local cap = if run.tutorial then BetaRun.Caps.tutorialClaims else BetaRun.Caps.claims
	if run.totals.claims + run.totals.joyrides >= cap then
		log(player, "claims over the bolt cap (" .. cap .. "): dropped")
		return nil
	end
	run.done[index] = true
	local outcome = BetaEconomy.keysOutcome(data, carId)
	if not outcome then
		return nil
	end
	local added = BetaEconomy.addCash(player, outcome.amount, outcome.kind .. " " .. carId)
	BetaEconomy.publishCars(player, data)
	local grant: Grant = {
		kind = outcome.kind,
		carId = carId,
		amount = added,
		newCash = data.Cash,
		edition = outcome.edition,
		copies = outcome.copies,
		rose = outcome.rose,
		index = index,
	}
	if outcome.kind == "claim" then
		run.totals.claims += 1
		run.totals.claimCash += added
		grant.parked = BetaLineup.autoPark(player, carId)
		table.insert(run.totals.cars, { carId = carId, parked = grant.parked :: string })
	else
		run.totals.joyrides += 1
		run.totals.joyrideCash += added
		if outcome.rose then
			BetaLineup.publish(player) -- Lap Pay of a parked car changes with its edition
		end
	end
	run.totals.total = run.totals.claimCash + run.totals.joyrideCash + run.totals.milestoneCash
	grantTo(run, grant)
	return grant
end

local function closeRun(run: Run, cause: string)
	if run.closed then
		return
	end
	run.closed = true
	run.totals.cause = cause
	run.totals.closed = true
	run.totals.metres = math.floor(RunConfig.toMetres(run.lastD))
	run.totals.total = run.totals.claimCash + run.totals.joyrideCash + run.totals.milestoneCash
	if runs[run.player] == run then
		runs[run.player] = nil
	end
	closedRuns[run.id] = run.totals
	table.insert(closedOrder, run.id)
	if #closedOrder > 64 then
		closedRuns[table.remove(closedOrder, 1) :: string] = nil
	end
	log(
		run.player,
		string.format(
			"run %s closed (%s): %d m, %d claims, %d joyrides, $%d",
			run.id,
			cause,
			run.totals.metres,
			run.totals.claims,
			run.totals.joyrides,
			run.totals.total
		)
	)
end

-- The handlers, apart from the remotes so the self-test can call them. Each returns a short status string.
function BetaRun.start(player: Player, world: any, _startCarId: any): Run?
	local data = BetaData.get(player)
	if not data or type(world) ~= "string" or RosterFixtures.WorldNames[world] == nil then
		log(player, "RunStart refused: unknown World " .. tostring(world))
		return nil
	end
	if not data.WorldsUnlocked[world] then
		log(player, "RunStart refused: " .. world .. " is locked")
		return nil
	end
	local old = runs[player]
	if old then
		closeRun(old, "Replaced")
	end
	nextId += 1
	local seed = Random.new():NextInteger(1, 2 ^ 30)
	local run: Run = {
		id = string.format("%d-%d", player.UserId, nextId),
		player = player,
		world = world,
		seed = seed,
		sequence = RunSequence.new(seed, RunConfig.profile(BetaRun.PROFILE)),
		started = os.clock(),
		tutorial = data.TutorialDone ~= true,
		lastD = 0,
		lastT = 0,
		batchTimes = {},
		done = {},
		milestones = 0,
		totals = {
			metres = 0,
			claims = 0,
			joyrides = 0,
			joyrideCash = 0,
			claimCash = 0,
			milestoneCash = 0,
			total = 0,
			cars = {},
			cause = "",
			closed = false,
		},
		closed = false,
	}
	runs[player] = run
	log(player, string.format("run %s started in %s (seed %d)", run.id, world, seed))
	return run
end

function BetaRun.events(player: Player, runId: any, events: any): string
	local run = runs[player]
	if not run or run.id ~= runId then
		return "unknown run"
	end
	local now = os.clock()
	local times = run.batchTimes
	while #times > 0 and now - times[1] > 1 do
		table.remove(times, 1)
	end
	if #times >= BetaRun.Caps.batchesPerSecond then
		log(player, "too many batches per second: dropped")
		return "rate"
	end
	table.insert(times, now)
	if type(events) ~= "table" or #events > BetaRun.Caps.eventsPerBatch then
		log(player, "malformed or oversized batch: dropped")
		return "batch"
	end
	local accepted = 0
	for _, e in events do
		if type(e) ~= "table" or type(e.kind) ~= "string" then
			continue
		end
		local ok, why = plausible(run, e.t, e.d)
		if not ok then
			log(player, string.format("%s event dropped: %s", e.kind, why or "?"))
			continue
		end
		accepted += 1
		if e.kind == "KeysComplete" and e.index ~= nil then
			BetaRun.keysComplete(run, e.index, e.d, e.betaModel)
		elseif e.kind == "RunEnd" then
			-- a crash pauses the run; it closes on BetaRunEnd (a revive may follow)
			run.totals.cause = if type(e.cause) == "string" then string.sub(e.cause, 1, 60) else "?"
		end
	end
	milestones(run)
	return string.format("accepted %d", accepted)
end

-- KeysComplete sent at once (0021): (runId, spawnIndex). Its t and d arrive in the next batch, so the urgent copy uses the
-- last accepted d; a later batch copy of the same spawn is ignored by the per-run `done` set.
function BetaRun.keysNow(player: Player, runId: any, index: any, betaModel: any): Grant?
	local run = runs[player]
	if not run or run.id ~= runId then
		return nil
	end
	return BetaRun.keysComplete(run, index, run.lastD, betaModel)
end

function BetaRun.finish(player: Player, runId: any, cause: any): Totals?
	if type(runId) ~= "string" then
		return nil
	end
	local closed = closedRuns[runId]
	if closed then
		return closed -- a repeat or late retry: the same reply, nothing paid again
	end
	local run = runs[player]
	if not run or run.id ~= runId then
		return nil
	end
	closeRun(run, if type(cause) == "string" then string.sub(cause, 1, 60) else "Quit")
	return run.totals
end

function BetaRun.startRemotes(net: Folder)
	local startFn = Instance.new("RemoteFunction")
	startFn.Name = BetaConfig.Remotes.RunStart
	startFn.Parent = net
	local events = Instance.new("RemoteEvent")
	events.Name = BetaConfig.Remotes.RunEvents
	events.Parent = net
	local keys = Instance.new("RemoteEvent")
	keys.Name = BetaConfig.Remotes.KeysComplete
	keys.Parent = net
	local finish = Instance.new("RemoteEvent")
	finish.Name = BetaConfig.Remotes.RunEnd
	finish.Parent = net
	local granted = Instance.new("RemoteEvent")
	granted.Name = BetaConfig.Remotes.RunGranted
	granted.Parent = net
	local results = Instance.new("RemoteEvent")
	results.Name = BetaConfig.Remotes.RunResults
	results.Parent = net
	remotes.granted = granted

	startFn.OnServerInvoke = function(player: Player, world: any, startCarId: any)
		local run = BetaRun.start(player, world, startCarId)
		return if run then { runId = run.id, seed = run.seed } else nil
	end
	events.OnServerEvent:Connect(function(player: Player, runId: any, list: any)
		BetaRun.events(player, runId, list)
	end)
	-- (runId, spawnIndex) as agreed; the beta-only betaModel rides as an optional third value
	keys.OnServerEvent:Connect(function(player: Player, runId: any, index: any, betaModel: any)
		BetaRun.keysNow(player, runId, index, betaModel)
	end)
	finish.OnServerEvent:Connect(function(player: Player, runId: any, cause: any)
		local totals = BetaRun.finish(player, runId, cause)
		if totals then
			results:FireClient(player, runId, totals)
		end
	end)
	Players.PlayerRemoving:Connect(function(player: Player)
		local run = runs[player]
		if run then
			closeRun(run, "Left")
		end
	end)
end

-- A scripted run on a fake player and a test save (Mock store only: the self-test never touches a real save).
-- From the command bar in a Studio Play server: print(table.concat(require(...BetaRun).selfTest(player), "\n"))
function BetaRun.selfTest(player: Player): { string }
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
		return { "FAIL no save loaded for " .. player.Name }
	end
	local run = BetaRun.start(player, "Downtown", nil) :: Run
	-- find two spawns of the same car, and one of another car, in the server's own sequence
	run.sequence:ensure(4000)
	local byCar: { [string]: { number } } = {}
	for i = 1, #run.sequence._spawns do
		local car = BetaRun.carAt(run, i, 0) :: string
		byCar[car] = byCar[car] or {}
		table.insert(byCar[car], i)
	end
	local twice: string? = nil
	for car, list in byCar do
		if #list >= 2 and data.Cars[car] == nil then
			twice = car
		end
	end
	expect("the sequence has an unowned car twice", twice ~= nil, true)
	if not twice then
		return lines
	end
	local a, b = byCar[twice][1], byCar[twice][2]
	local cashBefore = data.Cash
	run.started = os.clock() - 20 -- the run is 20 s old
	local status = BetaRun.events(player, run.id, { { kind = "Hop", t = 10, d = 500, x = 0, target = a } })
	expect("an honest hop is accepted", status, "accepted 1")
	local g1 = BetaRun.keysNow(player, run.id, a, twice)
	expect("first spawn of a new model is a claim", g1 and g1.kind, "claim")
	local again = BetaRun.keysNow(player, run.id, a, twice)
	expect("the same spawn again grants nothing", again, nil)
	local g2 = BetaRun.keysNow(player, run.id, b, twice)
	expect("a second spawn of the same model is a joyride", g2 and g2.kind, "joyride")
	local wrong = BetaRun.keysNow(player, run.id, byCar[twice][3] or 99999, "Hyperion")
	expect("an unknown betaModel is dropped", wrong, nil)
	run.batchTimes = {}
	status = BetaRun.events(player, run.id, { { kind = "Hop", t = 11, d = 1e6, x = 0, target = 0 } })
	expect("an over-speed distance is dropped", status, "accepted 0")
	run.batchTimes = {}
	local big = {}
	for i = 1, 31 do
		big[i] = { kind = "Hop", t = 12, d = 600, x = 0, target = 0 }
	end
	expect("an oversized batch is dropped", BetaRun.events(player, run.id, big), "batch")
	expect("NaN index dropped", BetaRun.keysNow(player, run.id, 0 / 0, nil), nil)
	expect("unknown runId ignored", BetaRun.events(player, "nope", {}), "unknown run")
	local totals = BetaRun.finish(player, run.id, "Quit") :: Totals
	expect("results count one claim and one joyride", string.format("%d/%d", totals.claims, totals.joyrides), "1/1")
	expect(
		"results total is what was paid",
		totals.total,
		(g1 and g1.amount or 0) + (g2 and g2.amount or 0) + totals.milestoneCash
	)
	expect("Cash rose by the total", data.Cash - cashBefore, totals.total)
	local late = BetaRun.finish(player, run.id, "Quit")
	expect("a late RunEnd retry gets the same totals", late, totals)
	-- leave the save as it was (the test claim is removed again)
	data.Cash = cashBefore
	data.Cars[twice] = nil
	local at = table.find(data.Lineup, twice)
	if at then
		table.remove(data.Lineup, at)
	end
	BetaEconomy.publishCash(player, data)
	BetaEconomy.publishCars(player, data)
	BetaLineup.publish(player)
	return lines
end

return BetaRun
