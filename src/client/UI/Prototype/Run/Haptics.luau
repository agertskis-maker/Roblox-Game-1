--!strict
-- Haptics (Lane 3 preview; Round 2 R2-V2 cue, Round 3 R3-F5 Settings switch). One short confirmation cue, BEST EFFORT: a
-- HapticEffect (UINotification) created under pcall. No documented API reports whether a device really vibrated, so the
-- result here is "requested", never "felt". It is UNTESTED ON HARDWARE: a desktop or emulator run is not tactile evidence.
-- One cue per call; the caller plays it once per confirmed claim, with no repeated or escalating vibration.
--
-- THE ONE GATE. Every task-owned haptic output in src/ and playground/ goes through Haptics.confirm, and inside this module
-- only through the private `gate` function (nothing else touches HapticService or HapticEffect). The gate answers, in order:
--   * the preference is OFF (store.settings.haptics == false)      -> "off": no call at all, anything running is stopped
--   * the device cannot take a cue (Haptics.isSupported() false)   -> "unsupported": no call at all, no error
--   * otherwise                                                     -> one UINotification effect is started
-- The preference is local preview state in the store (settings.haptics, ON by default, nil counts as ON). It never touches
-- a DataStore. The platform keeps the last word: this module only REQUESTS a cue through the engine, so a system-level
-- vibration switch that is off still wins, and it never writes a motor value above 0 (SetMotor is used only to write 0).
--
-- CAPABILITY is reported honestly. A controller is detected with HapticService:IsVibrationSupported(Gamepad1); a touch
-- device has no documented query, so it counts as capable when UserInputService.TouchEnabled is true and a UINotification
-- effect can be created (nothing is played by the check). A desktop without a controller is "not supported".
--
-- TURNING IT OFF stops what is running: every live effect is stopped and destroyed, and a controller's motors are set to 0.
-- Haptics.setEnabled(store, on) writes the preference and does that; the capture ribbon also calls Haptics.apply when the
-- store's settings change, so a harness that writes the setting directly gets the same behaviour.
--
-- TEST SEAM (playground scenarios only): Haptics.useBackend(Haptics.recorder({ gamepad = false, touch = true }).backend)
-- swaps the real services for a recorder that counts starts, stops and motor resets and makes no engine call;
-- Haptics.useBackend(nil) restores the real ones. useBackend stops anything running first.
--
--   Haptics.confirm(enabled: boolean?) -> "off" | "requested" | "unsupported"   -- nil counts as ON
--   Haptics.isOn(settings) -> boolean        Haptics.setEnabled(store, on)       Haptics.apply(enabled)
--   Haptics.isSupported() -> boolean         Haptics.capability() -> Capability
--   Haptics.stop() -> number                 Haptics.counts() -> Counts
--   Haptics.useBackend(backend?)             Haptics.recorder(support?) -> Recorder

local HapticService = game:GetService("HapticService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Store = require(script.Parent.Parent.Store)

local EFFECT_SECONDS = 1.5 -- a live effect is stopped and destroyed after this

local Haptics = {}

export type Result = "off" | "requested" | "unsupported"
export type Capability = { supported: boolean, gamepad: boolean, touch: boolean, basis: string }
export type Counts = { requested: number, off: number, unsupported: number, stopped: number, active: number }

-- What the module needs from the platform (the seam). The real one is below; a recorder replaces it in scenarios.
export type Backend = {
	gamepad: () -> boolean, -- a controller that can vibrate
	touch: () -> boolean, -- a touch device that can take a UINotification effect
	start: () -> any?, -- play one UINotification effect, returning a handle (nil = it could not be started)
	stop: (handle: any) -> (), -- stop and destroy a handle
	motorsOff: () -> (), -- write 0 to the controller's motors
}

export type Recorder = {
	backend: Backend,
	calls: { string }, -- "start" | "stop" | "motorsOff", in order
	starts: number,
	stops: number,
	motorOffs: number,
	live: number, -- started and not yet stopped
	gamepad: boolean, -- what the stub reports (change these to simulate other hardware)
	touch: boolean,
}

type Live = { handle: any, thread: thread? }

local function realStart(): any?
	local created, effect = pcall(function()
		local e = Instance.new("HapticEffect")
		e.Type = Enum.HapticEffectType.UINotification
		e.Looped = false
		return e
	end)
	if not created then
		return nil
	end
	local e = effect :: HapticEffect
	local played = pcall(function()
		e.Parent = Workspace
		e:Play()
	end)
	if not played then
		pcall(function()
			e:Destroy()
		end)
		return nil
	end
	return e
end

local REAL: Backend = {
	gamepad = function(): boolean
		local ok, supported = pcall(function()
			return HapticService:IsVibrationSupported(Enum.UserInputType.Gamepad1)
		end)
		return ok and supported == true
	end,
	touch = function(): boolean
		if not UserInputService.TouchEnabled then
			return false
		end
		-- the capability check: an effect of the cue's type can be created (it is not played)
		return (
			pcall(function()
				local probe = Instance.new("HapticEffect")
				probe.Type = Enum.HapticEffectType.UINotification
				probe:Destroy()
			end)
		)
	end,
	start = realStart,
	stop = function(handle: any)
		local e = handle :: HapticEffect
		pcall(function()
			e:Stop()
		end)
		pcall(function()
			e:Destroy()
		end)
	end,
	motorsOff = function()
		pcall(function()
			HapticService:SetMotor(Enum.UserInputType.Gamepad1, Enum.VibrationMotor.Large, 0)
			HapticService:SetMotor(Enum.UserInputType.Gamepad1, Enum.VibrationMotor.Small, 0)
		end)
	end,
}

local backend: Backend = REAL
local live: { Live } = {}
local counts = { requested = 0, off = 0, unsupported = 0, stopped = 0 }

local function release(item: Live)
	local i = table.find(live, item)
	if not i then
		return -- already stopped (the timer and an off switch can both arrive)
	end
	table.remove(live, i)
	local timer = item.thread
	if timer ~= nil and timer ~= coroutine.running() then
		pcall(task.cancel, timer)
	end
	backend.stop(item.handle)
	counts.stopped += 1
end

-- Stops everything still running and writes 0 to a controller's motors. Returns how many effects it stopped.
function Haptics.stop(): number
	local n = #live
	for _, item in table.clone(live) do
		release(item)
	end
	if n > 0 and backend.gamepad() then
		backend.motorsOff()
	end
	return n
end

function Haptics.capability(): Capability
	local gamepad = backend.gamepad()
	local touch = backend.touch()
	return {
		supported = gamepad or touch,
		gamepad = gamepad,
		touch = touch,
		basis = if gamepad
			then "controller motor reported by HapticService"
			elseif touch then "touch device (a cue is requested; whether it is felt is not reported)"
			else "none",
	}
end

function Haptics.isSupported(): boolean
	return Haptics.capability().supported
end

-- The preference: ON unless the setting is explicitly false.
function Haptics.isOn(settings: { haptics: boolean? }): boolean
	return settings.haptics ~= false
end

-- THE gate (see the header): the only place that decides whether any haptic output may happen.
local function gate(enabled: boolean?): "off" | "unsupported" | "ok"
	if enabled == false then
		return "off"
	end
	if not Haptics.isSupported() then
		return "unsupported"
	end
	return "ok"
end

function Haptics.confirm(enabled: boolean?): Result
	local verdict = gate(enabled)
	if verdict == "off" then
		counts.off += 1
		Haptics.stop() -- an off preference also silences a cue that is still running
		return "off"
	end
	if verdict == "unsupported" then
		counts.unsupported += 1
		return "unsupported"
	end
	local handle = backend.start()
	if handle == nil then
		counts.unsupported += 1
		return "unsupported"
	end
	counts.requested += 1
	local item: Live = { handle = handle, thread = nil }
	table.insert(live, item)
	item.thread = task.delay(EFFECT_SECONDS, function()
		release(item)
	end)
	return "requested"
end

-- The preference changed: OFF stops whatever is running (ON needs nothing: the next cue is allowed again).
function Haptics.apply(enabled: boolean?)
	if enabled == false then
		Haptics.stop()
	end
end

-- Writes the local preview setting (settings.haptics) and applies it at once.
function Haptics.setEnabled(store: Store.StoreObject, on: boolean)
	local settings = table.clone(store:get().settings) :: any
	settings.haptics = on
	store:set("settings", settings)
	Haptics.apply(on)
end

function Haptics.counts(): Counts
	return {
		requested = counts.requested,
		off = counts.off,
		unsupported = counts.unsupported,
		stopped = counts.stopped,
		active = #live,
	}
end

-- TEST SEAM: swap the platform (nil = the real services). Anything running is stopped first.
function Haptics.useBackend(replacement: Backend?)
	Haptics.stop()
	backend = replacement or REAL
end

-- TEST SEAM: a recording stub. `support` says what hardware it pretends to be (default: a touch device).
function Haptics.recorder(support: { gamepad: boolean?, touch: boolean? }?): Recorder
	local rec: Recorder = {
		backend = REAL,
		calls = {},
		starts = 0,
		stops = 0,
		motorOffs = 0,
		live = 0,
		gamepad = if support then support.gamepad == true else false,
		touch = if support then support.touch == true else true,
	}
	local nextId = 0
	rec.backend = {
		gamepad = function(): boolean
			return rec.gamepad
		end,
		touch = function(): boolean
			return rec.touch
		end,
		start = function(): any?
			nextId += 1
			rec.starts += 1
			rec.live += 1
			table.insert(rec.calls, "start")
			return { id = nextId, stopped = false }
		end,
		stop = function(handle: any)
			if handle.stopped then
				return
			end
			handle.stopped = true
			rec.stops += 1
			rec.live -= 1
			table.insert(rec.calls, "stop")
		end,
		motorsOff = function()
			rec.motorOffs += 1
			table.insert(rec.calls, "motorsOff")
		end,
	}
	return rec
end

return Haptics
