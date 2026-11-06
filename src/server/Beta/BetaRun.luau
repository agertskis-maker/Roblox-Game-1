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
-- Hard caps (beta sanity, not security; Tunable, ledger L-03): claims per run at most the Stamina count (5, plus one per
-- Stamina Shop level bought, since 2026-11-05); 30 events per batch and 3 batches per second (0021: "a maximum number of events per batch and batches per second");
-- `d` (studs) never ahead of the run's own speed curve plus 1,500 studs, never backwards; `t` (seconds) never ahead of the
-- server's clock for the run by more than 3 s; one active run per player; unknown runId ignored. Over a cap: dropped and
-- logged with the UserId; the run keeps going.
--
-- Round 6 (E-04, E-05): the remotes use Brian L's names (src/shared/Beta/BetaRunNet, a stand-in for his EconomyPreviewNet),
-- and the Round 5 Beta* names are accepted for one more round. Every event, the urgent KeysComplete included, passes the t
-- and d checks. A Hop names its target car: the target must already be in the server's built traffic (the server never
-- builds the sequence out to a distance a client names) and within `hopReach` studs of the player. A KeysComplete counts
-- only for the car the last Hop landed on, and only once the profile's Keys time for that car's rarity has passed since
-- that Hop (Brian R's RunConfig keysTime, less `keysTolerance`).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BetaConfig = require(ReplicatedStorage.Shared.Beta.BetaConfig)
local BetaData = require(script.Parent.BetaData)
local BetaEconomy = require(script.Parent.BetaEconomy)
local BetaEvents = require(script.Parent.BetaEvents)
local BetaLineup = require(script.Parent.BetaLineup)
local BetaRunMap = require(ReplicatedStorage.Shared.Beta.BetaRunMap)
local BetaRunNet = require(ReplicatedStorage.Shared.Beta.BetaRunNet)
local EconomyPreview = require(ReplicatedStorage.Shared.UI.EconomyPreview)
local RosterFixtures = require(ReplicatedStorage.Shared.UI.RosterFixtures)
local RunConfig = require(ReplicatedStorage.Shared.Run.RunConfig)
local RunSequence = require(ReplicatedStorage.Shared.Run.RunSequence)

local BetaRun = {}

BetaRun.Caps = table.freeze({
	claims = 5, -- the bolt count (RunStamina.Max)
	tutorialClaims = 5, -- RunStamina.TutorialMax (5 since 2026-11-05, Adam)
	eventsPerBatch = 30,
	batchesPerSecond = 3,
	aheadStuds = 1500, -- d may lead the run's speed curve by this much (a hop onto a car far ahead)
	backStuds = 5,
	clockAhead = 3, -- seconds
	maxRunSeconds = 1800,
	-- Round 6 (E-05, Tunable): studs between the player and a Hop's target car. Brian L's preview uses 90; that is his
	-- question to Brian R (the new Hop reaches further), so the beta allows more until they agree.
	-- Round 7 (R-01): one reach constant for both sides, RunConfig.HOP_REACH_MAX (the float lets you aim, not reach farther). Was 250.
	hopReach = RunConfig.HOP_REACH_MAX,
	keysTolerance = 0.25, -- seconds a KeysComplete may come early (Brian L's 0.25 s question to Brian R)
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
	ride: { index: number, t: number }?, -- the car the last accepted Hop targeted, and the run time of that Hop
	milestones: number,
	-- Round 7 (R-01, R-04, L-02): the bolts this run started with and has left (the server's own count), whether a paid Leap is
	-- waiting for its dive, the run time of the last charged bump (BUMP_GRACE), and the Luck snapshot the traffic was built with
	bolts: number,
	boltsLeft: number,
	leapOpen: boolean,
	lastBump: number,
	luck: number,
	totals: Totals,
	closed: boolean,
}

local deprecatedLogged: { [string]: boolean } = {}
local function deprecated(oldName: string, newName: string)
	if not deprecatedLogged[oldName] then
		deprecatedLogged[oldName] = true
		print(
			string.format(
				"[CarHopBeta run] DEPRECATED: %s was used; use %s (Round 7 removes the old name)",
				oldName,
				newName
			)
		)
	end
end

local runs: { [Player]: Run } = {}
local lastClosed: { [Player]: Totals } = {} -- each player's last closed run (a paid respawn that arrives too late)
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
	BetaEvents.fire(run.player, grant.kind, grant :: any) -- Round 6 (G-01): claim, joyride, milestone, respawn
	-- RunGranted (Brian L's name) and, for Round 6 only, the Round 5 BetaRunGranted. A client listens to one of them.
	for _, key in { "granted", "grantedOld" } do
		local remote = remotes[key]
		if remote then
			remote:FireClient(run.player, run.id, grant)
		end
	end
end

-- E-05: a Hop's target must be a car the server has already built, near the player. Returns nil when it may count.
function BetaRun.hopProblem(run: Run, t: number, d: number, target: any): string?
	if target == 0 then
		return nil -- a hop with no car (onto the road)
	end
	if not finite(target) or target % 1 ~= 0 or target < 1 then
		return "Hop target is not a car index"
	end
	-- only as far as the run has really gone: never as far as a client-named index or distance
	run.sequence:ensure(math.min(run.lastD + run.sequence.profile.spawnAhead + 200, 2e6))
	local spawn = run.sequence:get(target)
	if not spawn then
		return "far Hop: target " .. target .. " is not in the traffic yet"
	end
	local gap = math.abs(run.sequence:alongAt(spawn, t) - d)
	if gap > BetaRun.Caps.hopReach then
		return string.format("far Hop: target %d is %.0f studs away", target, gap)
	end
	return nil
end

-- E-05: whether a KeysComplete at run time `t` comes after the Keys time of the car the last Hop landed on.
function BetaRun.keysProblem(run: Run, index: number, t: number): string?
	local ride = run.ride
	if not ride or ride.index ~= index then
		return "Keys for a car the player did not hop onto"
	end
	local spawn = run.sequence:get(index)
	local need = if spawn then run.sequence.profile.keysTime[spawn.rarity] or 3 else 3
	if t - ride.t < need - BetaRun.Caps.keysTolerance then
		return string.format("Keys after %.2f s, faster than the %.1f s Keys time", t - ride.t, need)
	end
	return nil
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
function BetaRun.keysComplete(run: Run, index: any, d: number, betaModel: any, t: number): Grant?
	local player = run.player
	if run.done[index] then
		log(player, "KeysComplete repeated for spawn " .. tostring(index) .. ": nothing granted twice")
		return nil
	end
	local tooFast = if finite(index) then BetaRun.keysProblem(run, index, t) else "Keys index is not a number"
	if tooFast then
		log(player, "KeysComplete for spawn " .. tostring(index) .. " dropped: " .. tooFast)
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
	-- the bolt count follows the Stamina Shop level the save has (5 to 15 Stamina, one per hop)
	local cap = math.max(
		if run.tutorial then BetaRun.Caps.tutorialClaims else BetaRun.Caps.claims,
		EconomyPreview.staminaFor(data.StaminaLevel)
	)
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
	lastClosed[run.player] = run.totals
	BetaEvents.fire(run.player, "runEnded", {
		world = run.world,
		metres = run.totals.metres,
		claims = run.totals.claims,
		joyrides = run.totals.joyrides,
		cause = cause,
	})
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
	local tutorial = data.TutorialDone ~= true
	local bolts = math.max(
		if tutorial then BetaRun.Caps.tutorialClaims else BetaRun.Caps.claims,
		EconomyPreview.staminaFor(data.StaminaLevel)
	)
	local run: Run = {
		id = string.format("%d-%d", player.UserId, nextId),
		player = player,
		world = world,
		seed = seed,
		-- Round 7 (L-02, R-12): the luck snapshot at run start; a purchase during the run counts from the next run
		sequence = RunSequence.new(seed, RunConfig.profile(BetaRun.PROFILE), EconomyPreview.luckFor(data.LuckLevel)),
		luck = EconomyPreview.luckFor(data.LuckLevel),
		bolts = bolts,
		boltsLeft = bolts,
		leapOpen = false,
		lastBump = -math.huge,
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
		-- Round 7: the server's own bolt count. A Leap costs 1 and opens one dive; a Bump costs 1 unless one was charged in the last
		-- BUMP_GRACE seconds of run time; a Bonk or a throw costs 1. A Leap with no bolts left is dropped, so its dive and Keys pay
		-- nothing. The client never sends how many bolts it has.
		if e.kind == "Leap" then
			if run.boltsLeft <= 0 then
				log(player, "Leap dropped: no bolts left on the server")
				continue
			end
			run.boltsLeft -= 1
			run.leapOpen = true
		elseif e.kind == "Bump" then
			if e.t - run.lastBump >= RunConfig.BUMP_GRACE then
				run.lastBump = e.t
				run.boltsLeft = math.max(run.boltsLeft - 1, 0)
			end
		elseif e.kind == "Bonk" or e.kind == "Thrown" then
			run.boltsLeft = math.max(run.boltsLeft - 1, 0)
		elseif e.kind == "Hop" then
			local problem = BetaRun.hopProblem(run, e.t, e.d, e.target)
			if problem then
				log(player, "Hop dropped: " .. problem)
				continue
			end
			if e.target ~= 0 and (run.ride == nil or (run.ride :: any).index ~= e.target) then
				run.ride = { index = e.target, t = e.t }
			end
			run.leapOpen = false
		end
		accepted += 1
		if e.kind == "KeysComplete" and e.index ~= nil then
			BetaRun.keysComplete(run, e.index, e.d, e.betaModel, e.t)
		elseif e.kind == "RunEnd" then
			-- a crash pauses the run; it closes on BetaRunEnd (a revive may follow)
			run.totals.cause = if type(e.cause) == "string" then string.sub(e.cause, 1, 60) else "?"
		end
	end
	milestones(run)
	return string.format("accepted %d", accepted)
end

-- KeysComplete sent at once. Brian L's shape (Round 6): (runId, event) with the event's own t, d and index, checked like
-- every other event. The Round 5 shape (runId, spawnIndex, betaModel?) has no t or d: it uses the last accepted d and the
-- server's own run clock. A later batch copy of the same spawn is ignored by the per-run `done` set.
function BetaRun.keysNow(player: Player, runId: any, eventOrIndex: any, betaModel: any): Grant?
	local run = runs[player]
	if not run or run.id ~= runId then
		return nil
	end
	if type(eventOrIndex) == "table" then
		local e = eventOrIndex
		local ok, why = plausible(run, e.t, e.d)
		if not ok then
			log(player, "urgent KeysComplete dropped: " .. (why or "?"))
			return nil
		end
		return BetaRun.keysComplete(run, e.index, e.d, e.betaModel, e.t)
	end
	return BetaRun.keysComplete(run, eventOrIndex, run.lastD, betaModel, os.clock() - run.started)
end

-- Round 6 (R-02): a granted Robux respawn. When the player's run is still open (crashed, waiting on the Results card), it
-- continues: the client is told through RunGranted { kind = "respawn" } and revives the run. When it already closed, the
-- caller pays that run's Results total as Cash instead (Claude Code's call), so a payment is never for nothing.
function BetaRun.paidRespawn(player: Player): (string, number?)
	local run = runs[player]
	if run and not run.closed then
		run.totals.cause = ""
		local data = BetaData.get(player)
		grantTo(run, { kind = "respawn", amount = 0, newCash = if data then data.Cash else 0 })
		log(player, "paid respawn: run " .. run.id .. " continues")
		return "continued", nil
	end
	local totals = lastClosed[player]
	return "ended", if totals then totals.total else 0
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

-- `net` is CarHopBetaNet (the beta-only BetaRunEnd and BetaRunResults, and the Round 5 names); `runNet` is the
-- EconomyPreviewNet stand-in folder (Brian L's names, BetaRunNet). Both are parented by BetaServer once complete.
function BetaRun.startRemotes(net: Folder, runNet: Folder)
	local function remote(className: string, name: string, parent: Folder): any
		local r = Instance.new(className)
		r.Name = name
		r.Parent = parent
		return r
	end
	local names, old = BetaRunNet.Remotes, BetaRunNet.Deprecated
	local startFn = remote("RemoteFunction", names.StartRun, runNet)
	local events = remote("RemoteEvent", names.RunEvents, runNet)
	local keys = remote("RemoteEvent", names.KeysComplete, runNet)
	remotes.granted = remote("RemoteEvent", names.RunGranted, runNet)
	local oldStart = remote("RemoteFunction", old.StartRun, net)
	local oldEvents = remote("RemoteEvent", old.RunEvents, net)
	local oldKeys = remote("RemoteEvent", old.KeysComplete, net)
	remotes.grantedOld = remote("RemoteEvent", old.RunGranted, net)
	local finish = remote("RemoteEvent", BetaConfig.Remotes.RunEnd, net)
	local results = remote("RemoteEvent", BetaConfig.Remotes.RunResults, net)

	local function onStart(player: Player, world: any, startCarId: any)
		local run = BetaRun.start(player, world, startCarId)
		-- Round 7: the luck snapshot (L-02, R-12) and the bolts rides along; the client builds the same traffic with them
		return if run then { runId = run.id, seed = run.seed, luck = run.luck, bolts = run.bolts } else nil
	end
	startFn.OnServerInvoke = onStart
	oldStart.OnServerInvoke = function(player: Player, world: any, startCarId: any)
		deprecated(old.StartRun, names.StartRun)
		return onStart(player, world, startCarId)
	end
	events.OnServerEvent:Connect(function(player: Player, runId: any, list: any)
		BetaRun.events(player, runId, list)
	end)
	oldEvents.OnServerEvent:Connect(function(player: Player, runId: any, list: any)
		deprecated(old.RunEvents, names.RunEvents)
		BetaRun.events(player, runId, list)
	end)
	-- (runId, event) in Brian L's shape; the beta-only betaModel rides inside the event
	keys.OnServerEvent:Connect(function(player: Player, runId: any, event: any)
		BetaRun.keysNow(player, runId, event, nil)
	end)
	-- Round 5's (runId, spawnIndex, betaModel?)
	oldKeys.OnServerEvent:Connect(function(player: Player, runId: any, index: any, betaModel: any)
		deprecated(old.KeysComplete, names.KeysComplete)
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
		lastClosed[player] = nil
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
	run.started = os.clock() - 300 -- the run is 300 s old, so every test time below is in the past
	local seq = run.sequence
	-- each step starts from a clean t and d, so one check never depends on another's order
	local function fresh()
		run.lastT, run.lastD, run.batchTimes = 0, 0, {}
	end
	local function along(index: number, t: number): number
		return seq:alongAt(seq:get(index), t)
	end
	local function need(index: number): number
		return seq.profile.keysTime[seq:get(index).rarity] or 3
	end
	local function hop(index: number, t: number): string
		fresh()
		return BetaRun.events(player, run.id, { { kind = "Hop", t = t, d = along(index, t), x = 0, target = index } })
	end
	local function keys(index: number, t: number, model: string?): Grant?
		local event = { kind = "KeysComplete", t = t, d = along(index, t), index = index, betaModel = model }
		return BetaRun.keysNow(player, run.id, event, nil)
	end
	-- a test time when the car is within the run's reach (d no further ahead than the speed curve allows)
	local function timeFor(index: number): number
		local most = BetaRun.Caps.aheadStuds - 50
		for t = 5, 280, 5 do
			if
				along(index, t) <= seq:travelledAt(t) + most
				and along(index, t + 10) <= seq:travelledAt(t + 10) + most
			then
				return t
			end
		end
		return 5
	end
	local ta = timeFor(a)
	expect("an honest hop is accepted", hop(a, ta), "accepted 1")
	expect("E-05 Keys faster than the Keys time is dropped", keys(a, ta + 0.5, twice), nil)
	local g1 = keys(a, ta + need(a) + 0.1, twice)
	expect("first spawn of a new model is a claim", g1 and g1.kind, "claim")
	expect("the same spawn again grants nothing", keys(a, ta + need(a) + 0.2, twice), nil)
	local tb = math.max(timeFor(b), ta + need(a) + 1)
	fresh()
	expect("E-05 Keys for a car never hopped onto is dropped", keys(b, tb + need(b) + 0.1, twice), nil)
	hop(b, tb)
	expect("an unknown betaModel is dropped", keys(b, tb + need(b) + 0.1, "Hyperion"), nil)
	local g2 = keys(b, tb + need(b) + 0.2, twice)
	expect("a second spawn of the same model is a joyride", g2 and g2.kind, "joyride")
	-- E-05: a far Hop is dropped and never makes the server build the traffic out to it
	local far = #seq._spawns + 500
	fresh()
	local status = BetaRun.events(player, run.id, { { kind = "Hop", t = tb, d = along(b, tb), x = 0, target = far } })
	expect("E-05 a Hop onto a car not yet in the traffic is dropped", status, "accepted 0")
	expect("E-05 ... and the sequence was never built out to it", #seq._spawns < far, true)
	local away: number? = nil
	for i = 1, #seq._spawns do
		if i ~= b and math.abs(along(i, tb) - along(b, tb)) > BetaRun.Caps.hopReach + 50 then
			away = i
			break
		end
	end
	fresh()
	status = BetaRun.events(player, run.id, { { kind = "Hop", t = tb, d = along(b, tb), x = 0, target = away or 0 } })
	expect("E-05 a Hop onto a car out of reach is dropped", status, if away then "accepted 0" else "accepted 1")
	-- E-05: a d beyond reach is dropped on any event, the urgent KeysComplete included
	fresh()
	status = BetaRun.events(player, run.id, { { kind = "Hop", t = 11, d = 1e6, x = 0, target = 0 } })
	expect("an over-speed distance is dropped", status, "accepted 0")
	fresh()
	local urgent = { kind = "KeysComplete", t = 20, d = 1e7, index = b }
	expect(
		"E-05 an urgent KeysComplete with d out of reach is dropped",
		BetaRun.keysNow(player, run.id, urgent, nil),
		nil
	)
	-- E-05: Keys over the bolt cap
	local spare: number? = nil
	for i = 1, #seq._spawns do
		if i ~= a and i ~= b and not run.done[i] then
			spare = i
			break
		end
	end
	if spare then
		local claimsBefore = run.totals.claims
		run.totals.claims = 99
		local ts = math.max(timeFor(spare), 1)
		hop(spare, ts)
		expect("E-05 Keys over the bolt cap is dropped", keys(spare, ts + need(spare) + 0.1, nil), nil)
		run.totals.claims = claimsBefore
	end
	fresh()
	local big = {}
	for i = 1, 31 do
		big[i] = { kind = "Hop", t = 12, d = 600, x = 0, target = 0 }
	end
	expect("an oversized batch is dropped", BetaRun.events(player, run.id, big), "batch")
	expect("NaN index dropped", BetaRun.keysNow(player, run.id, 0 / 0, nil), nil)
	expect("E-05 an unknown runId is ignored", BetaRun.events(player, "nope", {}), "unknown run")
	expect("E-05 an urgent Keys for an unknown runId is ignored", BetaRun.keysNow(player, "nope", urgent, nil), nil)
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
	-- Round 7 (T-02): the server's bolt count (R-01, R-04) and the luck snapshot (L-02, R-12)
	local r7 = BetaRun.start(player, "Downtown", nil) :: Run
	expect("R-12 the run keeps the save's luck snapshot", r7.luck, EconomyPreview.luckFor(data.LuckLevel))
	expect("R-12 the traffic is built with that luck", r7.sequence.luck, r7.luck)
	local bolts = r7.bolts
	local tick = 1
	local function send(kind: string): string
		tick += 0.6
		r7.batchTimes = {}
		r7.started = os.clock() - tick - 1
		return BetaRun.events(player, r7.id, { { kind = kind, t = tick, d = RunConfig.travelledAt(tick), x = 0 } })
	end
	for _ = 1, bolts do
		send("Leap")
	end
	expect("R-01 every bolt pays for one Leap", r7.boltsLeft, 0)
	expect("R-01 a Leap with no bolts left is dropped", send("Leap"), "accepted 0")
	r7.boltsLeft = 5
	send("Bump") -- t + 0.6: charged
	send("Bump") -- 0.6 s later: inside the 1.5 s grace, free
	expect("R-04 two bumps 0.6 s apart cost one bolt", r7.boltsLeft, 4)
	tick += 1.5
	send("Bump")
	expect("R-04 a bump after the grace costs another bolt", r7.boltsLeft, 3)
	send("Bonk")
	send("Thrown")
	expect("R-01 a bonk and a throw cost one bolt each", r7.boltsLeft, 1)
	BetaRun.finish(player, r7.id, "Quit")
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
