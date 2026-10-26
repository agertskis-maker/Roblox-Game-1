--!strict
-- The HUD prototype's state store (Lane 3 preview). Display state plus a feedback event stream,
-- with explicit mode transitions. Preview adapters write to it from synthetic fixtures; the
-- components only read and subscribe. Nothing here is authoritative: in production the owning
-- lanes would supply this state through agreed contracts (proposed, not agreed:
-- vault/design/specs/hud-downtown-overnight.md, "Interfaces").
--
--   local store = Store.new()
--   store:get()                         -- the current state (treat as read-only)
--   store:set("cash", 9450)             -- one top-level key; fires store.Changed(key, state)
--   store:subscribe("cash", fn)         -- fn(value, state) on change; returns a disconnect
--   store:setMode("Run")                -- checked transitions; fires store.ModeChanged
--   store:emit({ id = "gain-1", kind = "CashGain", amount = 120 })   -- deduplicated by id
--
-- ROUND 3 (R3-F9) run-scoped capture identity (VISUAL/EVENT IDENTITY ONLY). The store keeps one "run scope" at a time:
--   store:runScope()                    -- { key, synthetic, startedAt, seq }; key = run.runId, else a synthetic key
--   store.RunChanged                    -- fires (scope, previous) at each run START; widgets clear run-local state then
--   store:classify(event)               -- "Current" | "Stale" (an event of an earlier run)
--   store:remember(name, event)         -- "Fresh" | "Duplicate" | "Stale": run-scoped dedupe by captureId, per consumer
--   store:remembered(name)              -- the ids a consumer remembered this run, in order (a re-created widget restores)
--   store:runBucket(name)               -- a run-scoped table that survives a widget being destroyed and re-mounted
--   store:confirmations()               -- the record of every confirmation seen (stale ones included, flagged)
-- Rules (documented once, here):
--   * Same run + same capture id again: Duplicate, ignored.
--   * An event whose runId differs from the active run's id, or whose issuedAt is older than the run start: Stale.
--     A stale event is NOT presented (no SECURED card, no tray +1) but IS still recorded in store:confirmations() and
--     still reaches every subscriber flagged event.stale = true: the permanent reward belongs to another lane
--     (Lane 2) and is never discarded here; only its presentation in the wrong run is.
--   * An event with NO runId belongs to the active run (fallback) and is deduplicated by capture id inside it.
--   * With no run id anywhere (state.run.runId is nil) the scope is SYNTHETIC: a new key at every run start (the mode
--     entering Run), so ids are never assumed unique across runs. An id that arrives later is adopted by the same run.
--   * Memory is cleared ONLY at run start. A widget destroyed and re-mounted mid-run keeps it (it lives here).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Signal = require(ReplicatedStorage.Packages.Signal)

local Store = {}
Store.__index = Store

export type Mode = "Home" | "Run" | "Results"

export type Rarity = "Common" | "Uncommon" | "Rare" | "Epic" | "Legendary"
export type Variant = "None" | "Gold" | "Chrome" | "Rainbow"

export type CarRef = {
	id: string,
	name: string,
	rarity: Rarity,
	variant: Variant,
	family: string, -- family label, e.g. "Hatch", "Truck"
	quirk: string, -- one short line
	-- authoritative ownership as supplied; nil = unknown (never shown as NEW!). Treat only
	-- `owned == false` as unowned.
	owned: boolean?,
	unseen: boolean?, -- earned but not looked at yet (Garage badge)
	model: string?, -- a model under ReplicatedStorage.Cars, or nil (loading / unavailable)
}

-- A district inside one World run (fixture). Lengths are explicit boundary data in metres (the
-- HUD unit); they are proposals for Lane 1, never equal spans invented by the HUD.
export type District = {
	id: string, -- a District_<id> icon name, e.g. "MainStreet", "CactusFlats", "PineVillage"
	name: string,
	short: string?, -- label for phones (about 7 characters); the first word of name when nil
	length: number, -- metres
}
-- The World a route belongs to (Round 2, fixture): its colour paints the travelled part of the route line.
export type WorldInfo = { id: string, name: string, colour: Color3 }
export type DistrictPlan = {
	districts: { District },
	repeats: boolean, -- true: the cycle starts again after the last district (endless run)
	world: WorldInfo?, -- nil = Downtown colours
}

-- A confirmed claim this run (the tray shows these; count = #claims).
export type Claim = {
	id: string, -- capture id (dedupe key)
	car: CarRef,
}

export type Tutorial = {
	step: number,
	steps: number,
	objective: string,
	count: number,
	goal: number,
	hint: string?,
	state: "Active" | "Hint" | "Done",
}

export type KeysState = {
	id: string?, -- capture id (identity for ordering and dedupe); fixtures always supply one
	target: CarRef,
	progress: number, -- 0..1 as supplied; 1 alone is NOT ownership
	-- Holding: filling; Pending: full, waiting for confirmation (SECURING…); Confirmed: only after
	-- a KeysConfirmed event; Lost / Canceled: ended without a claim (reason optional)
	status: "Holding" | "Pending" | "Confirmed" | "Lost" | "Canceled",
	reason: string?, -- truthful short reason for Canceled, e.g. "You hopped off"
	-- Round 2 (FIXTURES; Brian R owns the capture timing): the remaining capture duration in seconds, shown ONLY when
	-- timingTrusted is true (the source guarantees the number and its meaning). Never derived from progress.
	remainingSeconds: number?,
	timingTrusted: boolean?,
}

-- An advance warning, only when the owning lane really supplies one.
export type Warning = {
	id: string,
	reason: string, -- "TooHot" | ... (mapped to display text with a truthful fallback)
}

-- Stamina DEMO (R2-S1; proposal for Brian R / Brian L, off by default: nil = no meter). 10 per run, one spent per
-- ACCEPTED hop, no Hop at 0 while the current ride continues. The UI only displays it; a fixture adapter
-- (playground StaminaFixture) is the stand-in for the rule owner.
export type StaminaState = {
	value: number,
	max: number,
	lowAt: number?, -- at or below this the meter turns amber (default 3)
	restore: boolean?, -- the restoring-pickup fixture is switched on
}

export type RunState = {
	distance: number, -- metres (Lane 1 unit)
	cashPickups: number?, -- FIXTURE: road-coin Cash picked up so far this run (Results source row); Brian L owns the real value
	stamina: StaminaState?, -- Stamina demo; nil = off (default)
	hopStreak: number?, -- HOP STREAK demo (presentation only, off by default): shown from 2 (x2, x3)
	heat: number, -- 0..1
	stage: "Calm" | "Warning" | "Critical" | "Meltdown",
	ride: CarRef?,
	keys: KeysState?,
	hop: "Unavailable" | "Available" | "Timing", -- Timing = the best-timing window (the HUD filters its flicker)
	hopCooldown01: number, -- 0 ready .. 1 just used
	-- Round 2 Hop cues (FIXTURES; Brian R owns the target, the window and any trajectory):
	hopTargetId: string?, -- identity of the ONE selected target (retarget = a new id; nil = none)
	hopWindowId: string?, -- event identity of one best-timing window (the gold accent plays once per id)
	dash: number?, -- remaining 0..1 while a Foot Dash runs, nil otherwise
	best: number,
	-- Round 2 route line (FIXTURES; Brian L owns the record, Brian R the distance and district boundaries):
	recordM: number?, -- the personal-best distance BEFORE this run, metres; nil = no prior best
	recordVerified: boolean?, -- false = the record is not confirmed: no NEW BEST moment (nil counts as verified)
	-- identity of this run (NEW BEST fires once per run; Round 3: also scopes capture de-duplication, see the header).
	-- Brian R / Brian L supply the real one; nil = the store uses a synthetic key that changes at every run start.
	runId: string?,
	districtPlan: DistrictPlan?, -- explicit boundaries (fixture); nil hides the route line
	claims: { Claim }?, -- confirmed this run, in arrival order
	pendingClaim: Claim?, -- shown as a distinct pending slot; never counted
	warning: Warning?, -- nil when no advance warning exists
}

export type Results = {
	distance: number,
	-- Round 2: Cash is the single currency. Road coins are Cash pickups, shown as a SOURCE row. The amount
	-- is part of `earnings` when `totalIncludesPickups` is true (the default fixture), so the row is never
	-- added to the total a second time. nil or 0 hides the row (FIXTURE; Brian L owns the real breakdown).
	roadCoins: number?,
	totalIncludesPickups: boolean?,
	best: number,
	newBest: boolean,
	claimed: { CarRef },
	earnings: number,
	endReason: string?, -- "Overheated" | ... ; nil = ended normally / unknown
	joyride: number?, -- dollars, synthetic fixture
	milestones: number?,
}

export type State = {
	mode: Mode,
	cash: number,
	exactCash: number, -- the supplied value, for the exact-value detail
	earningPerLap: number?, -- FIXTURE (Brian L owns the real rate and its units)
	-- Garage pill "owned / total CARS": total nil = unknown (the pill shows the owned count alone).
	-- FIXTURE values; Brian L owns the real collection definition.
	garage: { owned: number, total: number?, unseen: number },
	-- Shop NEW ribbon: only from a supplied item-change flag, never a timer.
	shop: { newItem: boolean }?,
	missionsClaimable: number,
	tutorial: Tutorial?,
	-- local preview settings; musicOn is the Home toggle row (a real local setting, not saved)
	-- haptics: Round 3, the Settings "Haptics" switch: ON by default (nil counts as ON, false = off). Best effort and
	-- local preview state only; never claimed felt on hardware (Run/Haptics)
	settings: { music: number, sfx: number, musicOn: boolean?, haptics: boolean? },
	-- off-by-default proposals shown only in captioned review captures
	proposals: { timers: boolean }?,
	run: RunState?,
	results: Results?,
}

export type Event = {
	id: string,
	kind: string, -- "CashGain" | "CashSpend" | "CashPickup" (road coin = Cash pickup; amount) | "Toast" | "LapPay" | "Milestone" | "KeysConfirmed"
	-- | "AlreadyOwned" | "TutorialComplete" | "Unlock"
	-- | "KeysStart" | "KeysCanceled" | "DistrictEnter" | "RareArrival" | "RunWarning"
	-- | "Dismounted" | "RunEnded" | "ArrivedHome" | "HeatBump" (amount = jolt strength)
	-- | "HopAccepted" | "HopRejected" (reason) | "StaminaPickup" (worldPosition?)  -- Stamina demo fixtures
	-- KeysStart / KeysConfirmed / KeysCanceled / AlreadyOwned carry `captureId` (the identity
	-- of one capture); the event `id` stays unique per delivery for dedupe.
	captureId: string?,
	-- Round 3 (PROPOSAL for Brian R / Brian L; fixtures only): the run the event belongs to. An event whose runId is not
	-- the active run's id is "stale" (a late delivery from an earlier run). nil = belongs to the active run.
	runId: string?,
	-- Round 3 (PROPOSAL): when the owning lane issued the event, in the same os.clock() time base as the store. Older than
	-- the active run's start = stale. nil = unknown. (`at` below is the DELIVERY time the store stamps itself.)
	issuedAt: number?,
	-- set by the store at delivery on KeysConfirmed / AlreadyOwned events judged to belong to an earlier run
	stale: boolean?,
	reason: string?, -- KeysCanceled, RunWarning, Dismounted, RunEnded
	district: string?, -- DistrictEnter: District.id
	cycle: number?, -- DistrictEnter: fixture-local cycle index (1 = first pass)
	instanceId: string?, -- RareArrival: traffic car instance identity
	amount: number?,
	lapPay: number?, -- KeysConfirmed: the supplied Lap Pay of the claimed car, dollars (nil = none supplied)
	text: string?,
	tone: string?, -- toasts: "Success" | "Info" | "Unlock"
	car: CarRef?,
	worldPosition: Vector3?, -- a world source, only when one really exists
	at: number?,
}

-- Round 3 run identity (see the header). A consumer is one named presenter ("ribbon", "tray"): each keeps its own memory.
export type CaptureVerdict = "Fresh" | "Duplicate" | "Stale"
export type Standing = "Current" | "Stale"
export type RunMemo = { id: string, car: CarRef?, kind: string }
export type RunScope = {
	key: string, -- the run id (state.run.runId), or a synthetic key while the owner supplies none
	synthetic: boolean,
	startedAt: number, -- os.clock() when this run began
	seq: number, -- 1, 2, 3 ... per run start
	carried: string?, -- internal: the PREVIOUS run's id still sitting in state.run when this scope began (never adopted)
	memory: { [string]: { order: { string }, byId: { [string]: RunMemo } } }, -- internal
	buckets: { [string]: { any } }, -- internal
}
-- The record of one confirmation event (stale ones included). Display-side bookkeeping only: the permanent reward record
-- belongs to Lane 2 and is never decided here.
export type Confirmation = {
	captureId: string,
	kind: string, -- "KeysConfirmed" | "AlreadyOwned"
	eventId: string,
	runId: string?, -- the run the event claimed, when it carried one
	scopeKey: string, -- the active run's key when the event was delivered
	stale: boolean,
	car: CarRef?,
	at: number,
}

local RUN_MEMORY = 64 -- remembered capture ids per consumer per run (oldest dropped first)
local CONFIRMATION_MEMORY = 200 -- confirmations kept in the record

local TRANSITIONS: { [string]: { [string]: boolean } } = {
	Home = { Run = true },
	Run = { Results = true, Home = true },
	Results = { Home = true, Run = true },
}

function Store.baseline(): State
	return {
		mode = "Home",
		cash = 9450,
		exactCash = 9450,
		earningPerLap = 120,
		garage = { owned = 12, total = 24, unseen = 1 },
		shop = { newItem = false },
		missionsClaimable = 1,
		tutorial = nil,
		settings = { music = 0.5, sfx = 0.6, musicOn = true, haptics = true }, -- Round 3: Haptics default ON
		proposals = { timers = false },
		run = nil,
		results = nil,
	}
end

local function makeScope(seq: number, key: string?, carried: string?): RunScope
	return {
		key = key or ("synthetic-run-" .. tostring(seq)),
		synthetic = key == nil,
		startedAt = os.clock(),
		seq = seq,
		carried = carried,
		memory = {},
		buckets = {},
	}
end

function Store.new(initial: State?)
	local self = setmetatable({}, Store)
	self._state = initial or Store.baseline()
	self.Changed = Signal.new()
	self.ModeChanged = Signal.new()
	self.Event = Signal.new()
	self.RunChanged = Signal.new() -- (scope: RunScope, previous: RunScope?) at each run START
	self._seen = {} :: { [string]: boolean }
	self._seenOrder = {} :: { string }
	self._runSeq = 1
	self._scope = makeScope(1, nil, nil) :: RunScope
	self._confirmations = {} :: { Confirmation }
	return self
end

export type StoreObject = typeof(Store.new())

function Store.get(self: StoreObject): State
	return self._state
end

-- A new run begins: a fresh scope (empty identity memory) and one RunChanged for the widgets. `key` nil = synthetic;
-- `carried` is the previous run's id still sitting in state.run (so it is never adopted as this run's own).
local function beginRun(self: StoreObject, key: string?, carried: string?)
	local previous = self._scope :: RunScope
	self._runSeq += 1
	local scope = makeScope(self._runSeq, key, carried)
	self._scope = scope
	self.RunChanged:Fire(scope, previous)
end

-- The active run scope, refreshed from state.run.runId first: an id that arrives after the run started is ADOPTED by that
-- run (its memory is kept); a different id after a real one is a new run.
function Store.runScope(self: StoreObject): RunScope
	local scope = self._scope :: RunScope
	local run = self._state.run
	local id = if run then run.runId else nil
	if type(id) == "string" and id ~= "" and id ~= scope.key and id ~= scope.carried then
		if scope.synthetic then
			scope.key = id
			scope.synthetic = false
		else
			beginRun(self, id, nil)
		end
	end
	return self._scope :: RunScope
end

function Store.set(self: StoreObject, key: string, value: any)
	local state = self._state :: any
	state[key] = value
	if key == "run" then
		Store.runScope(self) -- a new run id starts a new scope BEFORE any subscriber sees the new run state
	end
	self.Changed:Fire(key, self._state)
end

function Store.subscribe(self: StoreObject, key: string, fn: (any, State) -> ()): () -> ()
	local c = self.Changed:Connect(function(changed: string, state: State)
		if changed == key then
			fn((state :: any)[key], state)
		end
	end)
	return function()
		c:Disconnect()
	end
end

-- Returns false (and changes nothing) for a transition the flow does not allow, so a repeated
-- click on Retry or Go Home cannot run a transition twice.
function Store.setMode(self: StoreObject, mode: Mode): boolean
	local from = self._state.mode
	if from == mode or not (TRANSITIONS[from] and TRANSITIONS[from][mode]) then
		return false
	end
	self._state.mode = mode
	if mode == "Run" then
		-- a run STARTS here (only Home or Results lead into Run): run-scoped identity memory begins empty. The run
		-- state still holds the previous run's id until the owner replaces it, so that id is marked as carried.
		local run = self._state.run
		beginRun(self, nil, if run then run.runId else nil)
	end
	self.ModeChanged:Fire(mode, from)
	return true
end

-- Whether an event of the capture family belongs to the active run (see the header for the rules).
function Store.classify(self: StoreObject, event: Event): Standing
	local scope = Store.runScope(self)
	local runId = event.runId
	if runId ~= nil and not scope.synthetic and runId ~= scope.key then
		return "Stale" -- another run's id
	end
	local issuedAt = event.issuedAt
	if issuedAt ~= nil and issuedAt < scope.startedAt then
		return "Stale" -- issued before this run began
	end
	return "Current"
end

-- Run-scoped de-duplication for one presenter. Fresh = first time in this run (now remembered); Duplicate = this capture
-- id was already remembered by `name` in this run; Stale = another run's event (not remembered, not to be presented).
function Store.remember(self: StoreObject, name: string, event: Event): CaptureVerdict
	if Store.classify(self, event) == "Stale" then
		return "Stale"
	end
	local scope = self._scope :: RunScope
	local memory = scope.memory[name]
	if not memory then
		memory = { order = {}, byId = {} }
		scope.memory[name] = memory
	end
	local id = event.captureId or event.id
	if memory.byId[id] then
		return "Duplicate"
	end
	memory.byId[id] = { id = id, car = event.car, kind = event.kind }
	table.insert(memory.order, id)
	if #memory.order > RUN_MEMORY then
		memory.byId[table.remove(memory.order, 1) :: string] = nil
	end
	return "Fresh"
end

-- What `name` remembered in the active run, oldest first (a re-created widget restores its count from this).
function Store.remembered(self: StoreObject, name: string): { RunMemo }
	local scope = Store.runScope(self)
	local out: { RunMemo } = {}
	local memory = scope.memory[name]
	if memory then
		for _, id in memory.order do
			table.insert(out, memory.byId[id])
		end
	end
	return out
end

-- A run-scoped table by name: empty at every run start, untouched by a widget being destroyed and re-mounted.
function Store.runBucket(self: StoreObject, name: string): { any }
	local scope = Store.runScope(self)
	local bucket = scope.buckets[name]
	if not bucket then
		bucket = {}
		scope.buckets[name] = bucket
	end
	return bucket
end

-- Every KeysConfirmed / AlreadyOwned delivered, stale ones flagged (a copy; the last 200).
function Store.confirmations(self: StoreObject): { Confirmation }
	return table.clone(self._confirmations)
end

local function recordConfirmation(self: StoreObject, event: Event)
	local stale = Store.classify(self, event) == "Stale"
	if stale then
		event.stale = true
	end
	table.insert(self._confirmations, {
		captureId = event.captureId or event.id,
		kind = event.kind,
		eventId = event.id,
		runId = event.runId,
		scopeKey = (self._scope :: RunScope).key,
		stale = stale,
		car = event.car,
		at = event.at or os.clock(),
	})
	if #self._confirmations > CONFIRMATION_MEMORY then
		table.remove(self._confirmations, 1)
	end
end

-- Deduplicated by id (the last 200 ids are remembered). Returns false for a duplicate.
function Store.emit(self: StoreObject, event: Event): boolean
	if self._seen[event.id] then
		return false
	end
	self._seen[event.id] = true
	table.insert(self._seenOrder, event.id)
	if #self._seenOrder > 200 then
		self._seen[table.remove(self._seenOrder, 1) :: string] = nil
	end
	event.at = os.clock()
	if event.kind == "KeysConfirmed" or event.kind == "AlreadyOwned" then
		-- recorded BEFORE delivery, stale or not: this module never discards a confirmation, it only judges which run
		-- a presentation belongs to
		recordConfirmation(self, event)
	end
	self.Event:Fire(event)
	return true
end

function Store.reset(self: StoreObject, state: State?)
	self._state = state or Store.baseline()
	table.clear(self._seen)
	table.clear(self._seenOrder)
	table.clear(self._confirmations)
	beginRun(self, nil, nil) -- a clean slate is a new run scope too
	Store.runScope(self) -- the new state may already carry its run id: adopt it
	for _, key in
		{
			"mode",
			"cash",
			"exactCash",
			"earningPerLap",
			"garage",
			"missionsClaimable",
			"tutorial",
			"settings",
			"proposals",
			"run",
			"results",
		}
	do
		self.Changed:Fire(key, self._state)
	end
	self.ModeChanged:Fire(self._state.mode, nil)
end

function Store.destroy(self: StoreObject)
	self.Changed:Destroy()
	self.ModeChanged:Destroy()
	self.Event:Destroy()
	self.RunChanged:Destroy()
end

return Store
