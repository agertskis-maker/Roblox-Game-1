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
	id: string, -- "MainStreet" | "CityHall" | "HarborBridge" | "Midtown" | "SkylinePark"
	name: string,
	length: number, -- metres
}
export type DistrictPlan = {
	districts: { District },
	repeats: boolean, -- true: the cycle starts again after the last district (endless run)
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
}

-- An advance warning, only when the owning lane really supplies one.
export type Warning = {
	id: string,
	reason: string, -- "TooHot" | ... (mapped to display text with a truthful fallback)
}

export type RunState = {
	distance: number, -- metres (Lane 1 unit)
	coins: number,
	heat: number, -- 0..1
	stage: "Calm" | "Warning" | "Critical" | "Meltdown",
	ride: CarRef?,
	keys: KeysState?,
	hop: "Unavailable" | "Available" | "Timing",
	hopCooldown01: number, -- 0 ready .. 1 just used
	dash: number?, -- remaining 0..1 while a Foot Dash runs, nil otherwise
	best: number,
	districtPlan: DistrictPlan?, -- explicit boundaries (fixture); nil hides the district strip
	claims: { Claim }?, -- confirmed this run, in arrival order
	pendingClaim: Claim?, -- shown as a distinct pending slot; never counted
	warning: Warning?, -- nil when no advance warning exists
}

export type Results = {
	distance: number,
	coins: number,
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
	garage: { owned: number, total: number, unseen: number },
	missionsClaimable: number,
	tutorial: Tutorial?,
	-- local preview settings; musicOn is the Home toggle row (a real local setting, not saved)
	settings: { music: number, sfx: number, musicOn: boolean? },
	-- off-by-default proposals shown only in captioned review captures
	proposals: { timers: boolean }?,
	run: RunState?,
	results: Results?,
}

export type Event = {
	id: string,
	kind: string, -- "CashGain" | "CashSpend" | "Toast" | "LapPay" | "Milestone" | "KeysConfirmed"
	-- | "AlreadyOwned" | "TutorialComplete" | "Unlock"
	-- | "KeysStart" | "KeysCanceled" | "DistrictEnter" | "RareArrival" | "RunWarning"
	-- | "Dismounted" | "RunEnded" | "ArrivedHome"
	-- KeysStart / KeysConfirmed / KeysCanceled / AlreadyOwned carry `captureId` (the identity
	-- of one capture); the event `id` stays unique per delivery for dedupe.
	captureId: string?,
	reason: string?, -- KeysCanceled, RunWarning, Dismounted, RunEnded
	district: string?, -- DistrictEnter: District.id
	cycle: number?, -- DistrictEnter: fixture-local cycle index (1 = first pass)
	instanceId: string?, -- RareArrival: traffic car instance identity
	amount: number?,
	text: string?,
	tone: string?, -- toasts: "Success" | "Info" | "Unlock"
	car: CarRef?,
	worldPosition: Vector3?, -- a world source, only when one really exists
	at: number?,
}

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
		garage = { owned = 3, total = 12, unseen = 1 },
		missionsClaimable = 1,
		tutorial = nil,
		settings = { music = 0.5, sfx = 0.6, musicOn = true },
		proposals = { timers = false },
		run = nil,
		results = nil,
	}
end

function Store.new(initial: State?)
	local self = setmetatable({}, Store)
	self._state = initial or Store.baseline()
	self.Changed = Signal.new()
	self.ModeChanged = Signal.new()
	self.Event = Signal.new()
	self._seen = {} :: { [string]: boolean }
	self._seenOrder = {} :: { string }
	return self
end

export type StoreObject = typeof(Store.new())

function Store.get(self: StoreObject): State
	return self._state
end

function Store.set(self: StoreObject, key: string, value: any)
	local state = self._state :: any
	state[key] = value
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
	self.ModeChanged:Fire(mode, from)
	return true
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
	self.Event:Fire(event)
	return true
end

function Store.reset(self: StoreObject, state: State?)
	self._state = state or Store.baseline()
	table.clear(self._seen)
	table.clear(self._seenOrder)
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
end

return Store
