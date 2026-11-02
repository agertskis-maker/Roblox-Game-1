--!strict
-- TutorialRunAdapter: the seam between the tutorial and the run (BRIEF M11-08). It turns whatever the run exposes into ONE
-- small stream of named events the controller listens to, and it says exactly what it can and cannot observe.
--
-- TWO MODES
--   Standin (default; main and the HUD playground): nothing is observed. The playground fixture calls adapter:emit(name, data)
--     to stand in for the run, so the steps can be previewed. A stand-in event is never described as real.
--   Real (the beta, integration/beta-2): adapter:attach(run) where `run` is a RunController-like object. ONLY these two
--     things of Brian R's public API are read, nothing of his files is edited:
--       run:getDebugState()  polled about 15 times a second   (the fields listed below)
--       run.Ended            a signal fired when the player presses Retry on his results screen
--     plus ONE look at the screen: PlayerGui.Lane1RunOverlay.Results (his results card) to tell when it is showing and to
--     find its button for the pointing hand.
--
-- EVENTS (Event:Fire(name, data)); the controller decides what each one means for a step
--   RunStarted            attach() was called (the run object exists and has started)
--   SteerLeft/SteerRight  lateral moved at least `steerStuds` (default 6, a third of a 17 stud lane) to that side of where it was
--                         when steering was last armed, while Riding (lateral is negative to the left: lane 1 is the left lane)
--   HopPressed            state.hops went up. A press is NOT a landing. data.onCar = a Hop target existed on the last poll
--   HopLanded             Hopping -> Riding after a press with a target (data.onCar true). A press with no target is an
--                         in-place hop and never counts as landing on a car
--   HopMissed             Hopping -> FootDash (the landing missed)
--   KeysStarted           state.keys became a number (the ring started to fill)
--   KeysCanceled          state.keys went back to nil with no claim (hopped off early)
--   ClaimConfirmed        #state.claimed grew (data.isNew = true, data.name) or events.KeysComplete grew with no new car
--                         (data.isNew = false, a Joyride bonus). This is the run's own SESSION claim; it is not a save.
--   HeatWarning           stage left "Calm" (Warning, Critical or Meltdown) while Riding. Observed only: the tutorial never
--                         raises Heat and never changes its rate
--   RunEnded              mode became "Ended" (data.cause = state.cause)
--   ResultsShown          his results card is on screen (found by name), or 0.6 s after RunEnded when it cannot be found
--   RunRevived            mode left "Ended" (the player used Revive)
--   RunClosed             run.Ended fired (Retry pressed), or the run was destroyed; the beta puts the player back on the island
--
-- WHAT IT CAN NOT OBSERVE (to put in Brian R's message, BRIEF M11-08)
--   * which car the Hop button was aimed at, or an exact landing event: HopLanded is inferred from the mode change at 15 Hz
--   * a "first successful landing" or "first claim" EVENT: only these inferences; no Heat-stage-changed event, no ended reason
--     event, no claim confirmation from a server (nothing is saved in the beta), so "Your new car is saved." is never shown
--   * the run's first-run assists (sparse traffic, no hazards in 300 m, half-speed Heat, a slow wide first target): his to build
--   * the steering input itself (only the resulting lateral position)
--   Missing events to ask for: first hop landed, claim confirmed, Heat stage changed, run ended with reason.
--
-- CAPABILITIES (what the controller may rely on)  adapter:capabilities() -> { steer, hopLand, claim, claimSaved, heat, results, runAvailable }
--   Standin: all true except claimSaved (a stand-in cannot prove a save). Real: true after attach() when getDebugState
--   returns the needed fields; claimSaved is always false in the beta.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Signal = require(ReplicatedStorage.Packages.Signal)
local Trove = require(ReplicatedStorage.Packages.Trove)

local RunAdapter = {}
RunAdapter.__index = RunAdapter

export type RunLike = {
	getDebugState: (self: any) -> { [string]: any },
	Ended: any?,
}

export type Options = { steerStuds: number?, pollHz: number?, overlayName: string? }

export type RunAdapter = typeof(setmetatable(
	{} :: {
		Event: any,
		mode: string,
		active: boolean,
		homeLabel: string,
		_trove: any,
		_runTrove: any,
		_run: RunLike?,
		_last: { [string]: any }?,
		_steerStuds: number,
		_pollEvery: number,
		_overlayName: string,
		_steerBase: number?,
		_steerFired: { left: boolean, right: boolean },
		_lastTarget: boolean,
		_pendingHop: boolean?,
		_pendingOnCar: boolean,
		_endedAt: number?,
		_resultsSent: boolean,
		_heatSent: boolean,
		_counts: { [string]: number },
		_emitted: { [string]: number },
		_polls: number,
		_destroyed: boolean,
	},
	RunAdapter
))

function RunAdapter.new(options: Options?): RunAdapter
	local o = options or {}
	local trove = Trove.new()
	local self = setmetatable({
		Event = trove:Add(Signal.new()),
		mode = "Standin",
		active = false,
		homeLabel = "Home",
		_trove = trove,
		_runTrove = trove:Extend(),
		_run = nil,
		_last = nil,
		_steerStuds = o.steerStuds or 6,
		_pollEvery = 1 / (o.pollHz or 15),
		_overlayName = o.overlayName or "Lane1RunOverlay",
		_steerBase = nil,
		_steerFired = { left = false, right = false },
		_lastTarget = false,
		_pendingHop = nil,
		_pendingOnCar = false,
		_endedAt = nil,
		_resultsSent = false,
		_heatSent = false,
		_counts = {},
		_emitted = {},
		_polls = 0,
		_destroyed = false,
	}, RunAdapter)
	return self
end

function RunAdapter.capabilities(self: RunAdapter): { [string]: boolean }
	local real = self.mode == "Real"
	return {
		steer = true,
		hopLand = true,
		claim = true,
		claimSaved = false,
		heat = true,
		results = true,
		runAvailable = true,
		real = real,
	}
end

local function fire(self: RunAdapter, name: string, data: { [string]: any }?)
	if self._destroyed then
		return
	end
	self._emitted[name] = (self._emitted[name] or 0) + 1
	if name == "RunStarted" or name == "RunRevived" then
		self.active = true
	elseif name == "RunClosed" then
		self.active = false
	end
	self.Event:Fire(name, data or {})
end

-- Stand-in events (the HUD playground fixture), and a hook for any lane that can report a real event itself.
function RunAdapter.emit(self: RunAdapter, name: string, data: { [string]: any }?)
	fire(self, name, data)
end

function RunAdapter.resetSteer(self: RunAdapter)
	self._steerBase = nil
	self._steerFired = { left = false, right = false }
end

local function overlayResults(self: RunAdapter): GuiObject?
	local player = Players.LocalPlayer
	local gui = player and player:FindFirstChild("PlayerGui")
	local overlay = gui and gui:FindFirstChild(self._overlayName)
	local results = overlay and overlay:FindFirstChild("Results")
	if results and results:IsA("GuiObject") and results.Visible then
		return results
	end
	return nil
end

-- His results card has Revive and Retry; Retry ends the run object and BetaRun puts the player back on the island. The
-- button the pointing hand marks: Home when a card has one, otherwise Retry.
function RunAdapter.getResultsButton(self: RunAdapter): GuiObject?
	local results = overlayResults(self)
	if not results then
		return nil
	end
	local retry: GuiObject? = nil
	for _, d in results:GetDescendants() do
		if d:IsA("TextButton") then
			local text = string.lower(d.Text)
			if string.sub(text, 1, 4) == "home" then
				self.homeLabel = "Home"
				return d
			elseif string.sub(text, 1, 5) == "retry" then
				retry = d
			end
		end
	end
	if retry then
		self.homeLabel = "Retry"
	end
	return retry
end

function RunAdapter.detach(self: RunAdapter)
	self._runTrove:Clean()
	self._run = nil
	self._last = nil
	self._pendingHop = nil
	self._endedAt = nil
	self._resultsSent = false
	self._heatSent = false
	RunAdapter.resetSteer(self)
	if self.active then
		self.active = false
	end
end

local function steerStep(self: RunAdapter, s: { [string]: any })
	if s.mode ~= "Riding" then
		self._steerBase = nil -- a hop moves the rider across lanes: measure again after landing
		return
	end
	local lateral = s.lateral
	if type(lateral) ~= "number" then
		return
	end
	local base = self._steerBase
	if base == nil then
		self._steerBase = lateral
		return
	end
	local delta = lateral - base
	if delta <= -self._steerStuds and not self._steerFired.left then
		self._steerFired.left = true
		fire(self, "SteerLeft", { delta = delta })
	elseif delta >= self._steerStuds and not self._steerFired.right then
		self._steerFired.right = true
		fire(self, "SteerRight", { delta = delta })
	end
end

local function claimedCount(s: { [string]: any }?): number
	local claimed = s and s.claimed
	return if type(claimed) == "table" then #claimed else 0
end

local function eventCount(s: { [string]: any }?, name: string): number
	local events = s and s.events
	if type(events) == "table" then
		local n = (events :: any)[name]
		return if type(n) == "number" then n else 0
	end
	return 0
end

local function poll(self: RunAdapter)
	local run = self._run
	if not run then
		return
	end
	local ok, state = pcall(function()
		return run:getDebugState()
	end)
	if not ok or type(state) ~= "table" then
		return
	end
	local s = state :: { [string]: any }
	local prev = self._last
	self._last = s
	self._polls += 1

	local mode = s.mode
	local prevMode = if prev then prev.mode else nil

	-- hops: a press is state.hops going up; it is resolved into a landing or a miss when the mode settles
	local pressed = prev ~= nil and type(s.hops) == "number" and type(prev.hops) == "number" and s.hops > prev.hops
	if pressed then
		self._pendingOnCar = self._lastTarget or prevMode == "FootDash"
		self._pendingHop = true
		fire(self, "HopPressed", { onCar = self._pendingOnCar })
	end
	if self._pendingHop and mode ~= "Hopping" then
		if mode == "Riding" then
			if self._pendingOnCar then
				fire(self, "HopLanded", { onCar = true })
			end
			self._pendingHop = nil
			RunAdapter.resetSteer(self)
		elseif mode == "FootDash" then
			fire(self, "HopMissed", {})
			self._pendingHop = nil
		elseif mode == "Ended" then
			self._pendingHop = nil
		end
	end
	if mode == "Riding" then
		self._lastTarget = s.target ~= nil
	end

	-- steering
	steerStep(self, s)

	-- keys and claims
	if prev then
		if type(s.keys) == "number" and prev.keys == nil then
			fire(self, "KeysStarted", { need = s.keysNeed })
		end
		local grew = claimedCount(s) > claimedCount(prev)
		local completed = eventCount(s, "KeysComplete") > eventCount(prev, "KeysComplete")
		if grew then
			local claimed = s.claimed :: { any }
			fire(self, "ClaimConfirmed", { isNew = true, name = claimed[#claimed] })
		elseif completed then
			fire(self, "ClaimConfirmed", { isNew = false })
		elseif prev.keys ~= nil and s.keys == nil and mode == "Riding" then
			fire(self, "KeysCanceled", {})
		end
	end

	-- heat (observed only)
	local stage = s.stage
	if mode == "Riding" and type(stage) == "string" and stage ~= "Calm" then
		if not self._heatSent then
			self._heatSent = true
			fire(self, "HeatWarning", { stage = stage })
		end
	elseif stage == "Calm" then
		self._heatSent = false
	end

	-- the end of the run and his results card
	if mode == "Ended" and prevMode ~= "Ended" then
		self._endedAt = os.clock()
		self._resultsSent = false
		fire(self, "RunEnded", { cause = s.cause })
	elseif mode ~= "Ended" and prevMode == "Ended" then
		self._endedAt = nil
		self._resultsSent = false
		fire(self, "RunRevived", {})
	end
	if mode == "Ended" and not self._resultsSent then
		local since = os.clock() - (self._endedAt or os.clock())
		if overlayResults(self) ~= nil or since > 0.6 then
			self._resultsSent = true
			fire(self, "ResultsShown", { found = overlayResults(self) ~= nil })
		end
	end
end

-- Real mode: observe `run` (a RunController-like object). Safe to call again for a new run: the old one is detached first.
function RunAdapter.attach(self: RunAdapter, run: RunLike)
	if self._destroyed then
		return
	end
	RunAdapter.detach(self)
	self.mode = "Real"
	self.homeLabel = "Retry"
	self._run = run
	local trove = self._runTrove
	local acc = 0
	trove:Connect(RunService.Heartbeat, function(dt: number)
		acc += dt
		if acc < self._pollEvery then
			return
		end
		acc = 0
		poll(self)
	end)
	local ended = run.Ended
	if ended ~= nil and type((ended :: any).Connect) == "function" then
		trove:Add((ended :: any):Connect(function()
			fire(self, "RunClosed", {})
			RunAdapter.detach(self) -- the run object is about to be destroyed: stop polling it
		end))
	end
	fire(self, "RunStarted", {})
	poll(self)
end

function RunAdapter.getDebugState(self: RunAdapter): { [string]: any }
	return {
		mode = self.mode,
		active = self.active,
		attached = self._run ~= nil,
		listeners = #self.Event:GetConnections(), -- tutorial listeners on this adapter (1 while a tutorial runs)
		homeLabel = self.homeLabel,
		steerStuds = self._steerStuds,
		polls = self._polls,
		emitted = table.clone(self._emitted),
		lastState = if self._last
			then {
				mode = self._last.mode,
				hops = self._last.hops,
				stage = self._last.stage,
				lateral = self._last.lateral,
				keys = self._last.keys,
				claimed = claimedCount(self._last),
			}
			else nil,
		cannotObserve = {
			"exact landing event (inferred from the mode change)",
			"a save of the claim (nothing from a run is saved in the beta)",
			"Heat stage change event (stage read from state)",
			"run-ended reason event (cause read from state)",
			"first-run assists",
		},
	}
end

function RunAdapter.destroy(self: RunAdapter)
	if self._destroyed then
		return
	end
	self._destroyed = true
	self._trove:Destroy()
end

return RunAdapter
