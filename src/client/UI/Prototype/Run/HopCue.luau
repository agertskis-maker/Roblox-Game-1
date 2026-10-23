--!strict
-- Hop cue coordinator (Lane 3 preview, Round 2, R2-P1). Not drawn: it reads store.run and makes ONE coordinated
-- decision for every Hop cue, so the player sees one target rather than four competing markers.
--
--   * the display state follows HopState.resolve (OutOfStamina > Cooldown > NoTarget > BestTiming > Ready);
--   * BEST TIMING IS FILTERED (hysteresis): the window must hold for ENTER_SECONDS before it shows and may
--     drop for EXIT_SECONDS before it hides, so a value hovering at the boundary cannot flash the cues. An
--     unavailable or empty state applies at once (it never advertises best timing);
--   * the gold ACCENT is an event: once per window, never within ACCENT_GAP of the last one, and never twice for
--     the same hopWindowId when the source supplies one;
--   * a new target id plays the soft lock-on whoosh at most once per LOCK_GAP (target flicker cannot spam it);
--   * the target cues (ring, arc, reticle) are driven from here and nowhere else, and every one of them points at
--     the same target model (debug oneTarget). Mode exit, target loss and a missing run hide all of them.
-- It never picks a target, judges a landing or changes a pose (Lane 1, Brian R).
--
--   local cue = HopCue.new(ctx)
--   cue:bind({ ring = ring?, arc = arc?, reticle = reticle? })   -- the world cues it drives
--   cue:setTargetModel(model?)                                    -- the model every cue points at
--   cue:display() -> HopState.Display          cue:refresh()
--   cue.Changed (display, previous)   cue.Accent (targetId?)   cue.LockOn (targetId)
--   cue:layout(), cue:setVisible(on), cue:destroy(), cue:getDebugState()

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local HopState = require(script.Parent.HopState)
local RunBus = require(script.Parent.RunBus)
local RunLayout = require(script.Parent.RunLayout)
local Signal = require(ReplicatedStorage.Packages.Signal)
local Sounds = require(script.Parent.Parent.Sounds)
local Trove = require(ReplicatedStorage.Packages.Trove)

local ENTER_SECONDS = 0.08 -- best timing must hold this long before it shows
local EXIT_SECONDS = 0.18 -- ...and may be gone this long before it hides
local ACCENT_GAP = 0.6 -- one gold accent per window, never closer than this
local LOCK_GAP = 0.6 -- the lock-on whoosh, at most this often

local RING: { [string]: string } = { Hidden = "Hidden", Grey = "Unavailable", Ready = "Available", Best = "Timing" }
local ARC: { [string]: string } = { Hidden = "Hidden", Grey = "Hidden", Ready = "Available", Best = "Timing" }
local RETICLE: { [string]: string } = { Hidden = "Hidden", Grey = "Hidden", Ready = "Ready", Best = "Best" }

local HopCue = {}
HopCue.__index = HopCue

export type World = { ring: any?, arc: any?, reticle: any? }

function HopCue.new(ctx: RunLayout.Ctx)
	local self = setmetatable({}, HopCue)
	self._ctx = ctx
	self._trove = Trove.new()
	self._visible = true
	self._raw = "NoTarget" :: HopState.Display
	self._rawSince = os.clock()
	self._display = "NoTarget" :: HopState.Display
	self._targetId = nil :: string?
	self._windowId = nil :: string?
	self._lastAccentWindow = nil :: string?
	self._lastAccent = -math.huge
	self._lastLock = -math.huge
	self._model = nil :: Instance?
	self._world = {} :: World
	self._step = nil :: RBXScriptConnection?
	self._changes = 0
	self._accents = 0
	self._accentsSuppressed = 0
	self._locks = 0
	self._locksSuppressed = 0
	self._targetChanges = 0

	self.Changed = self._trove:Add(Signal.new())
	self.Accent = self._trove:Add(Signal.new())
	self.LockOn = self._trove:Add(Signal.new())

	self._trove:Add(ctx.store:subscribe("run", function()
		self:_onStore()
	end))
	self._trove:Connect(ctx.store.ModeChanged, function()
		self:_onStore()
	end)
	RunBus.register(ctx, "hopCue", self)
	self._trove:Add(function()
		RunBus.unregister(ctx, "hopCue", self)
		self:_stopStep()
	end)
	return self
end

export type HopCue = typeof(HopCue.new((nil :: any) :: RunLayout.Ctx))

function HopCue._stopStep(self: HopCue)
	if self._step then
		self._step:Disconnect()
		self._step = nil
	end
end

function HopCue._applyWorld(self: HopCue)
	local mode: string = if self._visible then HopState.worldMode(self._display) else "Hidden"
	local w = self._world
	if w.ring and w.ring.setState then
		w.ring:setState(RING[mode])
	end
	if w.arc and w.arc.setState then
		w.arc:setState(ARC[mode])
	end
	if w.reticle and w.reticle.setState then
		w.reticle:setState(RETICLE[mode])
	end
end

function HopCue._commit(self: HopCue, nextDisplay: HopState.Display, now: number)
	local previous = self._display
	self._display = nextDisplay
	self._changes += 1
	if nextDisplay == "BestTiming" then
		local sameWindow = self._windowId ~= nil and self._windowId == self._lastAccentWindow
		if now - self._lastAccent >= ACCENT_GAP and not sameWindow then
			self._lastAccent = now
			self._lastAccentWindow = self._windowId
			self._accents += 1
			self.Accent:Fire(self._targetId)
		else
			self._accentsSuppressed += 1
		end
	end
	self:_applyWorld()
	self.Changed:Fire(nextDisplay, previous)
end

function HopCue._evaluate(self: HopCue, now: number)
	local raw, display = self._raw, self._display
	local nextDisplay = display
	local pending = false
	if raw == display then
		nextDisplay = display
	elseif raw == "BestTiming" then
		if now - self._rawSince >= ENTER_SECONDS then
			nextDisplay = "BestTiming"
		else
			pending = true
		end
	elseif raw == "Ready" and display == "BestTiming" then
		if now - self._rawSince >= EXIT_SECONDS then
			nextDisplay = "Ready"
		else
			pending = true
		end
	else
		nextDisplay = raw -- unavailable and empty states apply at once; best timing is never advertised in them
	end
	if nextDisplay ~= display then
		self:_commit(nextDisplay, now)
	end
	if pending and not self._step then
		self._step = RunService.Heartbeat:Connect(function()
			self:_evaluate(os.clock())
		end)
	elseif not pending then
		self:_stopStep()
	end
end

function HopCue._retarget(self: HopCue, id: string?, now: number)
	self._targetId = id
	self._targetChanges += 1
	if id == nil then
		return
	end
	if now - self._lastLock >= LOCK_GAP then
		self._lastLock = now
		self._locks += 1
		Sounds.play("HopLock")
		self.LockOn:Fire(id)
		local reticle = self._world.reticle
		if reticle and reticle.flashCue then
			reticle:flashCue()
		end
	else
		self._locksSuppressed += 1
	end
end

function HopCue._onStore(self: HopCue)
	local state = self._ctx.store:get()
	local run = if state.mode == "Run" then state.run else nil
	local now = os.clock()
	local id = if run then run.hopTargetId else nil
	if id ~= self._targetId then
		self:_retarget(id, now)
	end
	self._windowId = if run then run.hopWindowId else nil
	local raw = HopState.resolve(run)
	if raw ~= self._raw then
		self._raw = raw
		self._rawSince = now
	end
	self:_evaluate(now)
end

function HopCue.bind(self: HopCue, world: World)
	self._world = world
	if self._model then
		self:setTargetModel(self._model)
	end
	self:_applyWorld()
end

function HopCue.setTargetModel(self: HopCue, model: Instance?)
	self._model = model
	local w = self._world
	for _, cue in { w.ring, w.arc, w.reticle } do
		if cue and cue.setTarget then
			cue:setTarget(model)
		end
	end
end

function HopCue.display(self: HopCue): HopState.Display
	return self._display
end

function HopCue.refresh(self: HopCue)
	self:_onStore()
	self:_applyWorld()
end

function HopCue.layout(self: HopCue)
	self:_onStore()
end

function HopCue.setVisible(self: HopCue, on: boolean)
	self._visible = on
	self:_applyWorld()
end

function HopCue.getDebugState(self: HopCue): { [string]: any }
	local w = self._world
	local targets: { [string]: any } = {}
	local named: { string } = {}
	for key, cue in { ring = w.ring, arc = w.arc, reticle = w.reticle } do
		if cue and cue.getDebugState then
			local d = cue:getDebugState()
			targets[key] = d.target
			local shown = if d.shown ~= nil then d.shown else d.inWorld
			if d.target ~= nil and shown == true and d.state ~= "Hidden" then
				table.insert(named, d.target)
			end
		end
	end
	local one = true
	for _, t in named do
		if t ~= named[1] then
			one = false
		end
	end
	return {
		display = self._display,
		raw = self._raw,
		worldMode = HopState.worldMode(self._display),
		targetId = self._targetId,
		windowId = self._windowId,
		changes = self._changes,
		accents = self._accents,
		accentsSuppressed = self._accentsSuppressed,
		locks = self._locks,
		locksSuppressed = self._locksSuppressed,
		targetChanges = self._targetChanges,
		pending = self._step ~= nil,
		targets = targets,
		shownCues = #named,
		oneTarget = one,
	}
end

function HopCue.destroy(self: HopCue)
	self._trove:Destroy()
end

return HopCue
