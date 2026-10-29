--!strict
-- PLAYGROUND ONLY (Lane 3 Round 3, R3-F9): run-scoped capture identity. These check VISUAL / EVENT identity only: which run a
-- confirmation is presented in and how often. Every value is a synthetic fixture through the preview store. The rules are
-- written once in Prototype/Store.luau (header): same run + same capture id = ignored; another run's late event (its runId is
-- not the active run's, or it was issued before the run began) = not shown and not counted but still RECORDED; no runId =
-- the active run; no run id anywhere = a synthetic key that changes at every run start; a widget destroyed and re-mounted
-- keeps the memory; only a run start clears it. Each scenario logs PASS / FAIL lines.
--
--   Identity: duplicate callback ignored              the same capture id again in the same run: no replay, no second count
--   Identity: previous-run late event ignored         a late event of the last run (by run id, then by issue time): tray and
--                                                     SECURED untouched, the confirmation still in the store's record
--   Identity: no run id fallback and run scope (store) a private Store: synthetic keys, fallback, adoption, stale rules,
--                                                     the record, RunChanged
--   Identity: UI re-mount mid-run                     tray and ribbon destroyed and created again: nothing replays, the count
--                                                     is restored, the memory is kept, nothing is left behind
--   Identity: new run clears run-local state          the tray, the memory and the Results list start empty and the SAME
--                                                     capture id works again (the old uniqueness assumption is gone)

local Players = game:GetService("Players")

local Prototype = Players.LocalPlayer
	:WaitForChild("PlayerScripts")
	:WaitForChild("Client")
	:WaitForChild("UI")
	:WaitForChild("Prototype")
local Motion = require(Prototype:WaitForChild("Motion"))
local StoreModule = require(Prototype:WaitForChild("Store"))
local RunFolder = Prototype:WaitForChild("Run")
local CaptureRibbon = require(RunFolder:WaitForChild("CaptureRibbon"))
local ClaimTray = require(RunFolder:WaitForChild("ClaimTray"))
local RunBus = require(RunFolder:WaitForChild("RunBus"))

type Host = { [string]: any }

local counter = 0
local function nonce(): string
	counter += 1
	return string.format("%d-%d", math.floor(os.clock() * 1000), counter)
end

local function comp(host: Host, key: string): any
	return host.api.components and host.api.components[key]
end

local function dbg(host: Host, key: string): { [string]: any }
	local c = comp(host, key)
	return if c and c.getDebugState then c:getDebugState() else {}
end

local function verdict(host: Host, name: string, ok: boolean, detail: string)
	host.log(string.format("%s %s: %s", if ok then "PASS" else "FAIL", name, detail))
end

local function send(host: Host, kind: string, fields: { [string]: any }?): boolean
	local e = fields or {}
	e.id = e.id or (kind .. "-" .. nonce())
	return host.emit(kind, e)
end

local function confirm(host: Host, cid: string, car: any, extra: { [string]: any }?): boolean
	local fields: { [string]: any } = { captureId = cid, car = car }
	if extra then
		for k, v in extra do
			fields[k] = v
		end
	end
	return send(host, "KeysConfirmed", fields)
end

local function ownedFalse(host: Host, id: string): any
	local c = table.clone(host.car(id)) :: any
	c.owned = false
	return c
end

-- A clean run: Home, then Run (a run START: new identity scope), the held desktop view the other capture scenarios use.
local function freshRun(host: Host)
	local store = host.store
	Motion.setOverride(nil)
	if store:get().mode == "Run" then
		store:setMode("Home")
	end
	host.enterRun()
	host.wait(0.6)
	host.api.backdrop.hold(0)
end

local function runIdOf(host: Host): string?
	local run = host.store:get().run
	return if run then (run :: any).runId else nil
end

-- the store's record entries for one capture id
local function recordsFor(host: Host, cid: string): { any }
	local out = {}
	for _, c in host.store:confirmations() do
		if c.captureId == cid then
			table.insert(out, c)
		end
	end
	return out
end

local S: { [string]: (Host) -> () } = {}

S["Identity: duplicate callback ignored"] = function(host: Host)
	host.api.setProfile("Desktop")
	host.api.setSpeed(0)
	freshRun(host)
	local tray = comp(host, "tray")
	local count0 = tray:count()
	local plays0 = dbg(host, "reveal").plays
	local before = dbg(host, "ribbon")
	local cid = "dup-" .. nonce()
	confirm(host, cid, ownedFalse(host, "rev6")) -- the first delivery
	host.wait(0.4)
	confirm(host, cid, ownedFalse(host, "rev6")) -- the same capture again (a new event id): a repeated callback
	confirm(host, cid, ownedFalse(host, "rev6"))
	host.wait(2.6)
	local ribbon = dbg(host, "ribbon")
	verdict(
		host,
		"Shown and counted once",
		tray:count() == count0 + 1 and ribbon.shown == before.shown + 1 and dbg(host, "reveal").plays == plays0 + 1,
		string.format(
			"count +%d, ribbon shown +%d, SECURED plays +%d",
			tray:count() - count0,
			ribbon.shown - before.shown,
			dbg(host, "reveal").plays - plays0
		)
	)
	verdict(
		host,
		"The repeats were recognised in this run",
		ribbon.ignoredDuplicates == before.ignoredDuplicates + 2 and ribbon.ignoredStale == before.ignoredStale,
		string.format(
			"duplicates +%d, stale +%d",
			ribbon.ignoredDuplicates - before.ignoredDuplicates,
			ribbon.ignoredStale - before.ignoredStale
		)
	)
	local records = recordsFor(host, cid)
	local anyStale = false
	for _, r in records do
		if r.stale then
			anyStale = true
		end
	end
	verdict(
		host,
		"The store still recorded all three deliveries",
		#records == 3 and not anyStale,
		string.format("%d records for the capture, any stale: %s", #records, tostring(anyStale))
	)
	host.api.setSpeed(nil)
end

S["Identity: previous-run late event ignored"] = function(host: Host)
	host.api.setProfile("Desktop")
	host.api.setSpeed(0)
	freshRun(host)
	local run1 = runIdOf(host)
	local tray = comp(host, "tray")
	confirm(host, "run1-" .. nonce(), ownedFalse(host, "rev6"))
	host.wait(2.6)
	verdict(host, "The first run counted its own claim", tray:count() == 1, "count " .. tostring(tray:count()))
	-- a second run begins
	host.store:setMode("Home")
	host.enterRun()
	host.wait(0.8)
	host.api.backdrop.hold(0)
	local run2 = runIdOf(host)
	verdict(
		host,
		"The new run has its own identity",
		type(run1) == "string" and type(run2) == "string" and run1 ~= run2,
		string.format("%s then %s", tostring(run1), tostring(run2))
	)
	local count0 = tray:count()
	local ribbon0 = dbg(host, "ribbon")
	local reveal0 = dbg(host, "reveal")
	-- 1) a late event that names the PREVIOUS run
	local lateA = "late-run-" .. nonce()
	confirm(host, lateA, ownedFalse(host, "zoomurai"), { runId = run1 })
	host.wait(0.9)
	local ribbon1 = dbg(host, "ribbon")
	local reveal1 = dbg(host, "reveal")
	verdict(
		host,
		"A late event of the previous run: no tray count, no SECURED card",
		tray:count() == count0
			and reveal1.plays == reveal0.plays
			and reveal1.playing == false
			and ribbon1.shown == ribbon0.shown
			and ribbon1.showing == nil
			and ribbon1.ignoredStale == ribbon0.ignoredStale + 1
			and #ribbon1.pendingForResults == #ribbon0.pendingForResults,
		string.format(
			"count %d -> %d, SECURED plays +%d, ribbon shown +%d, stale ignored +%d, kept for Results +%d",
			count0,
			tray:count(),
			reveal1.plays - reveal0.plays,
			ribbon1.shown - ribbon0.shown,
			ribbon1.ignoredStale - ribbon0.ignoredStale,
			#ribbon1.pendingForResults - #ribbon0.pendingForResults
		)
	)
	-- 2) a late event that carries no run id but was issued before this run began
	local lateB = "late-time-" .. nonce()
	confirm(host, lateB, ownedFalse(host, "hurrikan"), { issuedAt = host.store:runScope().startedAt - 5 })
	host.wait(0.9)
	local ribbon2 = dbg(host, "ribbon")
	verdict(
		host,
		"A late event issued before this run began: ignored the same way",
		tray:count() == count0
			and dbg(host, "reveal").plays == reveal0.plays
			and ribbon2.shown == ribbon0.shown
			and ribbon2.ignoredStale == ribbon0.ignoredStale + 2,
		string.format("count %d, stale ignored +%d", tray:count(), ribbon2.ignoredStale - ribbon0.ignoredStale)
	)
	-- 3) a Joyride (AlreadyOwned) of the previous run is ignored too
	send(host, "AlreadyOwned", {
		captureId = "late-joy-" .. nonce(),
		car = host.car("puglet"),
		amount = 50,
		runId = run1,
	})
	host.wait(0.6)
	verdict(
		host,
		"A late Joyride of the previous run: nothing shown",
		dbg(host, "ribbon").shown == ribbon0.shown and dbg(host, "ribbon").ignoredStale == ribbon0.ignoredStale + 3,
		string.format("ribbon shown +%d", dbg(host, "ribbon").shown - ribbon0.shown)
	)
	-- the store did NOT discard them: they are in the record, flagged with the run they named
	local a, b = recordsFor(host, lateA)[1], recordsFor(host, lateB)[1]
	verdict(
		host,
		"The confirmations are still recorded, flagged as earlier-run",
		a ~= nil
			and a.stale == true
			and a.runId == run1
			and a.scopeKey == run2
			and a.kind == "KeysConfirmed"
			and b ~= nil
			and b.stale == true,
		string.format(
			"record A stale=%s names %s in %s; record B stale=%s",
			tostring(a and a.stale),
			tostring(a and a.runId),
			tostring(a and a.scopeKey),
			tostring(b and b.stale)
		)
	)
	-- the current run is unaffected
	confirm(host, "run2-" .. nonce(), ownedFalse(host, "rangy"))
	host.wait(2.6)
	verdict(
		host,
		"The current run still counts its own claim",
		tray:count() == count0 + 1 and dbg(host, "reveal").plays == reveal0.plays + 1,
		string.format("count %d, SECURED plays +%d", tray:count(), dbg(host, "reveal").plays - reveal0.plays)
	)
	host.api.setSpeed(nil)
end

S["Identity: no run id fallback and run scope (store)"] = function(host: Host)
	local s = StoreModule.new()
	local car = host.car("rev6")
	local function ev(id: string, cid: string, extra: { [string]: any }?): any
		local e: { [string]: any } = { id = id, kind = "KeysConfirmed", captureId = cid, car = car }
		if extra then
			for k, v in extra do
				e[k] = v
			end
		end
		return e
	end
	local changes = 0
	local conn = s.RunChanged:Connect(function()
		changes += 1
	end)
	-- no run state at all: a synthetic scope, and nothing is silently dropped
	local k0 = s:runScope()
	verdict(host, "No run id anywhere: a synthetic key", k0.synthetic == true, k0.key)
	verdict(
		host,
		"No runId on the event: Fresh, then the same capture is a Duplicate",
		s:remember("t", ev("e1", "c1")) == "Fresh" and s:remember("t", ev("e2", "c1")) == "Duplicate",
		"never dropped, deduplicated by capture id"
	)
	verdict(
		host,
		"An event naming a run while the store knows none: the fallback keeps it",
		s:remember("t", ev("e3", "c2", { runId = "someone-elses" })) == "Fresh",
		"cannot be compared with a synthetic key, so it belongs to the active run"
	)
	-- a run START (mode enters Run): a new synthetic key, empty memory, one RunChanged
	s:setMode("Run")
	local k1 = s:runScope()
	verdict(
		host,
		"A run start changes the synthetic key and clears the memory",
		k1.key ~= k0.key and k1.synthetic and changes == 1 and s:remember("t", ev("e4", "c1")) == "Fresh",
		string.format("%s then %s, RunChanged x%d: the same capture id is Fresh again", k0.key, k1.key, changes)
	)
	-- the owner's run id arrives after the run started: the same run adopts it and keeps its memory
	s:set("run", { runId = "R1", distance = 0 })
	local k2 = s:runScope()
	verdict(
		host,
		"A run id arriving later is adopted by the same run (memory kept)",
		k2.key == "R1"
			and not k2.synthetic
			and k2.seq == k1.seq
			and changes == 1
			and s:remember("t", ev("e5", "c1")) == "Duplicate",
		string.format("key %s, same run %s, RunChanged x%d", k2.key, tostring(k2.seq == k1.seq), changes)
	)
	-- stale rules
	verdict(
		host,
		"Another run's id is Stale; the active run's id is Current",
		s:classify(ev("e6", "c9", { runId = "R0" })) == "Stale"
			and s:classify(ev("e7", "c9", { runId = "R1" })) == "Current",
		"by run id"
	)
	verdict(
		host,
		"Issued before the run began is Stale; after it is Current",
		s:classify(ev("e8", "c10", { issuedAt = k2.startedAt - 1 })) == "Stale"
			and s:classify(ev("e9", "c10", { issuedAt = k2.startedAt + 1 })) == "Current",
		"by issue time"
	)
	verdict(
		host,
		"remember() reports a stale event as Stale and does not remember it",
		s:remember("t", ev("e10", "c11", { runId = "R0" })) == "Stale"
			and s:remember("t", ev("e11", "c11", { runId = "R1" })) == "Fresh",
		"the same capture id is still Fresh in the right run"
	)
	-- the record: a stale delivery reaches subscribers (flagged) and is recorded
	local seen: { any } = {}
	local sub = s.Event:Connect(function(e: any)
		table.insert(seen, e)
	end)
	local deliveredStale = s:emit(ev("e12", "c12", { runId = "R0" }))
	local deliveredNow = s:emit(ev("e13", "c13"))
	sub:Disconnect()
	local record = s:confirmations()
	local rStale, rNow = record[#record - 1], record[#record]
	verdict(
		host,
		"A stale confirmation is delivered flagged and recorded, never discarded",
		deliveredStale
			and deliveredNow
			and #seen == 2
			and seen[1].stale == true
			and seen[2].stale == nil
			and rStale ~= nil
			and rStale.captureId == "c12"
			and rStale.stale == true
			and rNow ~= nil
			and rNow.captureId == "c13"
			and rNow.stale == false,
		string.format(
			"delivered %d events, first flagged %s, second flagged %s; record %d entries",
			#seen,
			tostring(seen[1] and seen[1].stale),
			tostring(seen[2] and seen[2].stale),
			#record
		)
	)
	-- the NEXT run: its state still holds the previous run's id, which must not be taken as the new run's own
	s:setMode("Results")
	s:setMode("Run")
	local k3 = s:runScope()
	verdict(
		host,
		"A new run does not inherit the previous run's id",
		k3.synthetic and k3.key ~= "R1" and changes == 2,
		string.format("key %s, RunChanged x%d", k3.key, changes)
	)
	s:set("run", { runId = "R2", distance = 0 })
	local k4 = s:runScope()
	verdict(
		host,
		"...and adopts its own when it arrives",
		k4.key == "R2" and k4.seq == k3.seq and changes == 2,
		string.format("key %s, RunChanged x%d", k4.key, changes)
	)
	-- a different id in the middle of Run mode is a new run
	s:set("run", { runId = "R3", distance = 0 })
	verdict(
		host,
		"A different run id begins a new run",
		s:runScope().key == "R3" and changes == 3 and s:remember("t", ev("e14", "c1")) == "Fresh",
		string.format("key %s, RunChanged x%d", s:runScope().key, changes)
	)
	-- a run-scoped bucket and the remembered list follow the same boundary
	local bucket = s:runBucket("list")
	table.insert(bucket, "x")
	local sameBucket = s:runBucket("list") == bucket and #s:remembered("t") == 1
	s:reset()
	verdict(
		host,
		"A reset is a run start too: bucket and memory are empty",
		sameBucket
			and #s:runBucket("list") == 0
			and #s:remembered("t") == 0
			and #s:confirmations() == 0
			and changes == 4,
		string.format("RunChanged x%d", changes)
	)
	conn:Disconnect()
	s:destroy()
end

S["Identity: UI re-mount mid-run"] = function(host: Host)
	host.api.setProfile("Desktop")
	host.api.setSpeed(0)
	freshRun(host)
	local tray0, ribbon0 = comp(host, "tray"), comp(host, "ribbon")
	local trayCtx, ribbonCtx = tray0._ctx, ribbon0._ctx
	local idA = "mount-a-" .. nonce()
	confirm(host, idA, ownedFalse(host, "rev6"), nil)
	host.wait(2.6)
	local plays0 = dbg(host, "reveal").plays
	verdict(
		host,
		"Before the re-mount: one claim counted and shown",
		tray0:count() == 1 and dbg(host, "ribbon").shown >= 1,
		string.format("count %d, shown %d", tray0:count(), dbg(host, "ribbon").shown)
	)
	-- destroy both widgets and create them again on the same contexts, as a screen rebuild would
	tray0:destroy()
	ribbon0:destroy()
	local tray1 = ClaimTray.new(trayCtx)
	local ribbon1 = CaptureRibbon.new(ribbonCtx)
	host.api.components.tray = tray1
	host.api.components.ribbon = ribbon1
	host.wait(0.4)
	local tState, rState = tray1:getDebugState(), ribbon1:getDebugState()
	verdict(
		host,
		"The old widgets are gone and the new ones are the registered ones",
		tray0.root.Parent == nil
			and ribbon0.root.Parent == nil
			and RunBus.get(trayCtx, "tray") == tray1
			and RunBus.get(ribbonCtx, "ribbon") == ribbon1,
		string.format(
			"old roots parented: tray %s, ribbon %s",
			tostring(tray0.root.Parent),
			tostring(ribbon0.root.Parent)
		)
	)
	verdict(
		host,
		"The new tray restores the count without replaying anything",
		tray1:count() == 1 and tState.restoredFromRun == 1 and tState.countText == "1" and tState.stamps == 0,
		string.format(
			"count %d, restored %s, text %s, stamps %s",
			tray1:count(),
			tostring(tState.restoredFromRun),
			tostring(tState.countText),
			tostring(tState.stamps)
		)
	)
	verdict(
		host,
		"The new ribbon starts empty but the run's memory is still there",
		rState.shown == 0 and rState.showing == nil and rState.rememberedThisRun == 1,
		string.format("shown %d, remembered this run %s", rState.shown, tostring(rState.rememberedThisRun))
	)
	-- the same capture delivered again after the re-mount: ignored, no replay
	confirm(host, idA, ownedFalse(host, "rev6"))
	host.wait(1.2)
	local rAfter = ribbon1:getDebugState()
	verdict(
		host,
		"A repeat after the re-mount does not replay",
		rAfter.shown == 0
			and rAfter.showing == nil
			and rAfter.ignoredDuplicates == 1
			and tray1:count() == 1
			and dbg(host, "reveal").plays == plays0
			and dbg(host, "reveal").playing == false,
		string.format(
			"shown %d, duplicates ignored %d, count %d, SECURED plays +%d",
			rAfter.shown,
			rAfter.ignoredDuplicates,
			tray1:count(),
			dbg(host, "reveal").plays - plays0
		)
	)
	-- a NEW capture is presented and counted normally on the re-created widgets
	confirm(host, "mount-b-" .. nonce(), ownedFalse(host, "rangy"))
	host.wait(2.6)
	verdict(
		host,
		"A new capture works on the re-created widgets",
		tray1:count() == 2 and ribbon1:getDebugState().shown == 1 and dbg(host, "reveal").plays == plays0 + 1,
		string.format(
			"count %d, shown %d, SECURED plays +%d",
			tray1:count(),
			ribbon1:getDebugState().shown,
			dbg(host, "reveal").plays - plays0
		)
	)
	host.api.setSpeed(nil)
end

S["Identity: new run clears run-local state"] = function(host: Host)
	host.api.setProfile("Desktop")
	host.api.setSpeed(0)
	freshRun(host)
	local tray = comp(host, "tray")
	local ribbon = comp(host, "ribbon")
	local sharedId = "same-id-" .. nonce()
	local key1 = dbg(host, "ribbon").runKey
	confirm(host, sharedId, ownedFalse(host, "rev6"))
	host.wait(2.6)
	-- a claim kept for Results (it arrives after the run ended)
	host.store:emit({ id = "ended-" .. nonce(), kind = "RunEnded", reason = "Overheated" })
	host.wait(0.2)
	confirm(host, "kept-" .. nonce(), host.car("hurrikan"))
	host.wait(0.3) -- checked well inside the run end's 1.6 s hold, before Results takes the kept cards
	local rBefore = dbg(host, "ribbon")
	verdict(
		host,
		"Run 1 holds a claim, run-scoped memory and a card kept for Results",
		tray:count() >= 1 and rBefore.rememberedThisRun == 2 and #ribbon:pendingCards() >= 1,
		string.format(
			"count %d, remembered %s, kept for Results %d",
			tray:count(),
			tostring(rBefore.rememberedThisRun),
			#ribbon:pendingCards()
		)
	)
	-- run 2
	freshRun(host)
	local rNow = dbg(host, "ribbon")
	verdict(
		host,
		"A new run starts with an empty tray, memory and Results list",
		tray:count() == 0
			and rNow.rememberedThisRun == 0
			and #ribbon:pendingCards() == 0
			and rNow.runKey ~= key1
			and dbg(host, "tray").countText == "0",
		string.format(
			"count %d, remembered %s, kept %d, run %s -> %s",
			tray:count(),
			tostring(rNow.rememberedThisRun),
			#ribbon:pendingCards(),
			tostring(key1),
			tostring(rNow.runKey)
		)
	)
	-- the very same capture id in the new run is a new capture (no cross-run uniqueness assumed)
	local plays0 = dbg(host, "reveal").plays
	local shown0 = dbg(host, "ribbon").shown
	confirm(host, sharedId, ownedFalse(host, "rev6"))
	host.wait(2.6)
	verdict(
		host,
		"The same capture id in the new run is shown and counted again",
		tray:count() == 1 and dbg(host, "reveal").plays == plays0 + 1 and dbg(host, "ribbon").shown == shown0 + 1,
		string.format(
			"count %d, SECURED plays +%d, ribbon shown +%d",
			tray:count(),
			dbg(host, "reveal").plays - plays0,
			dbg(host, "ribbon").shown - shown0
		)
	)
	host.api.setSpeed(nil)
end

return S
