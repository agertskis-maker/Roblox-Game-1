--!strict
-- TutorialController: the tutorial as ONE state machine (BRIEF M11). Exactly one step is active at a time (steps 0 to 11 of
-- TutorialSteps). It listens to two adapters (run and island), keeps a small set of FACTS from their events, decides when the
-- active step is satisfied, and drives the presentation: the banner (through store.tutorial), the white chevron trail, the
-- arrow and glow, the pointing hand, the timed hint, the Skip confirm and the funnel spy. Progress is SESSION ONLY: nothing
-- here saves anything, grants anything or sends anything.
--
-- THE RULES IT KEEPS
--   * Never blocks play. It adds no input sink (the mask is non-modal), never moves the character, never teleports, and
--     reroutes the trail from wherever the player is. Wandering off, opening menus and coming back are all fine.
--   * A step completes only on a real (or clearly labelled stand-in) event. A hop PRESS is not a landing. "It's yours!" is
--     shown only when the run adapter is Real and saw a new claim; otherwise the fixture line "New car preview!". Heat is only
--     ever OBSERVED: step 5 waits for a real warning and is skipped (recorded, never faked) if the run ends first.
--   * A step whose adapter capability is missing is SKIPPED with the reason recorded, never completed by a made-up signal.
--   * A run objective that was not met (the run ended, the player missed) is kept: the tutorial guides back to the portal
--     ("Walk into a portal to try again.") and the step resumes in the next run. Facts of a run reset when the next run starts.
--   * Timed hint: after 8 seconds (tunable) without the step done, ONE hint per step: the arrow grows and pulses, the banner
--     wiggles, then a calm static cue stays.
--   * The tutorial finishes after step 11's 3 second hold. Skip asks first (the confirm card); replay starts again.
--
-- FACTS (reset when a run starts, except the island ones, which count only while their step is active)
--   runActive, resultsShown, heatSeen, steerLeft, steerRight, landed, landedAfterHeat, claim, runEnded, arrivedHome
--
-- PUBLIC (used by init.luau): Controller.new(ctx, options) -> Controller; :start(); :skip(); :requestSkip(); :jump(index, facts?);
--   :emitRun(name, data?); :emitIsland(name, data?); :getRunAdapter(); :getIslandAdapter(); :getDebugState(); :stop(reason)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Prototype = script.Parent.Parent.Prototype
local Sounds = require(Prototype.Sounds)
local TutorialBanner = require(Prototype.Home.TutorialBanner)
local TutorialRoute = require(Prototype.Home.TutorialRoute)
local Funnel = require(script.Parent.TutorialFunnel)
local Guide = require(script.Parent.TutorialGuide)
local IslandAdapter = require(script.Parent.TutorialIslandAdapter)
local RunAdapter = require(script.Parent.TutorialRunAdapter)
local SkipCard = require(script.Parent.TutorialSkipCard)
local Steps = require(script.Parent.TutorialSteps)
local Strings = require(script.Parent.TutorialStrings)
local Targets = require(script.Parent.TutorialTargets)
local Trove = require(ReplicatedStorage.Packages.Trove)
local Waypoints = require(script.Parent.TutorialWaypoints)

local Controller = {}
Controller.__index = Controller

local UPDATE_EVERY = 0.1 -- seconds between state checks
local REROUTE_EVERY = 0.35
local REROUTE_MOVED = 3 -- studs the player must move before the trail is rebuilt (or a second has passed)
local TRAIL_SKIP = 3 -- studs of trail dropped at the player's feet
local ARRIVED = 6 -- studs from the target: the trail ends
local PORTAL_RETRY_SECONDS = 3
local FAST_DONE_SECONDS = 0.5 -- a step that was already satisfied when it started

export type Options = {
	mode: string?, -- "Fixture" (default: stand-in events) or "Real" (the beta)
	banner: any?, -- an existing TutorialBanner to drive (the HUD playground mounts one); else one is created
	route: any?, -- an existing TutorialRoute; else one is created
	menu: any?, -- the LeftMenu (its Shop button is the step 10 target)
	uiTargets: { [string]: () -> GuiObject? }?,
	targets: { [string]: Vector3 }?, -- fixture world targets: DowntownPortal, Shopkeeper, Paddock, Raceway
	nav: ((from: Vector3, to: Vector3) -> { Vector3 })?,
	isShopOpen: (() -> boolean)?,
	lineup: boolean?, -- a Park control exists (Real mode)
	runAdapter: any?,
	islandAdapter: any?,
	funnel: any?,
	session: string?, -- "first" (default) or "replay"
	startStep: number?,
	timings: { hint: number?, done: number?, start: number?, ready: number? }?,
	onEnded: ((reason: string) -> ())?, -- "Finished" or "Skipped"
}

local function deviceKind(): string
	local last = UserInputService:GetLastInputType()
	if last == Enum.UserInputType.Touch then
		return "Touch"
	elseif string.sub(last.Name, 1, 7) == "Gamepad" then
		return "Gamepad"
	end
	return "Keyboard"
end

local function freshFacts(): { [string]: any }
	return {
		runActive = false,
		resultsShown = false,
		heatSeen = false,
		steerLeft = false,
		steerRight = false,
		landed = false,
		missed = false,
		landedAfterHeat = false,
		claim = nil,
		runEnded = false,
		arrivedHome = false,
		portalEntered = false,
		portalEnteredAt = nil,
		world = nil,
		-- island facts: only while their step is active
		parked = false,
		lap = false,
		upgraded = false,
		shopOpened = false,
	}
end

function Controller.new(ctx: any, options: Options?): any
	local o: Options = options or {}
	local self = setmetatable({}, Controller) :: any
	local trove = Trove.new()
	self._trove = trove
	self._ctx = ctx
	self._options = o
	self._mode = o.mode or "Fixture"
	self._real = self._mode == "Real"
	self._status = "Idle"
	self._index = -1
	self._step = nil :: Steps.Step?
	self._phase = "Active"
	self._facts = freshFacts()
	self._hinted = false
	self._enteredAt = 0
	self._doneAt = 0
	self._doneSeconds = 0
	self._completed = {} :: { [number]: string }
	self._skipped = {} :: { [number]: string }
	self._finishedAt = nil :: number?
	self._retryLine = false
	self._groundKey = nil :: string?
	self._lastRouteAt = -math.huge
	self._lastRoutePos = nil :: Vector3?
	self._routeCount = 0
	self._arrived = false
	self._tickAcc = 0
	self._hintCount = 0
	self._device = deviceKind()
	self._timings = {
		hint = (o.timings and o.timings.hint) or Steps.HINT_SECONDS,
		done = (o.timings and o.timings.done) or Steps.DONE_SECONDS,
		start = (o.timings and o.timings.start) or Steps.START_SECONDS,
		ready = (o.timings and o.timings.ready) or Steps.READY_SECONDS,
	}
	self._stepTrove = trove:Extend()
	self._ended = false
	self._lastSig = ""
	self._lastEvent = ""

	-- adapters (owned here unless the caller supplied them)
	self._ownsRun = o.runAdapter == nil
	self._ownsIsland = o.islandAdapter == nil
	self._run = o.runAdapter or RunAdapter.new()
	self._island = o.islandAdapter
		or IslandAdapter.new({
			mode = if self._real then "Real" else "Standin",
			targets = o.targets,
			nav = o.nav,
			isShopOpen = o.isShopOpen,
			lineup = o.lineup,
		})
	self._funnel = o.funnel or Funnel.new()
	self._funnel:setSession(o.session or "first")

	-- presentation parts
	self._ownsBanner = o.banner == nil
	self._ownsRoute = o.route == nil
	local banner = o.banner or TutorialBanner.new(ctx, {})
	local route = o.route or TutorialRoute.new(ctx)
	self._banner = banner
	self._route = route
	self._guide = Guide.new(ctx)
	self._skipCard = SkipCard.new(ctx, {
		topLayer = self._guide:getTopLayer(),
		title = Strings.get("skip.title"),
		yes = Strings.get("skip.yes"),
		no = Strings.get("skip.no"),
		onYes = function()
			self:skip()
		end,
	})
	if self._ownsBanner then
		trove:Add(function()
			banner:destroy()
		end)
	else
		banner:setPinned(true)
		trove:Add(function()
			banner:setPinned(false)
			banner:setSkipHandler(nil)
			banner:setPlacement("Home")
		end)
	end
	if self._ownsRoute then
		trove:Add(function()
			route:destroy()
		end)
	else
		trove:Add(function()
			route:setRoute(nil)
		end)
	end
	trove:Add(function()
		self._guide:destroy()
		self._skipCard:destroy()
		if self._ownsRun then
			self._run:destroy()
		end
		if self._ownsIsland then
			self._island:destroy()
		end
	end)
	banner:setSkipHandler(function()
		self:requestSkip()
	end)

	-- events (one connection each; the whole set is cleaned with the session)
	trove:Add(self._run.Event:Connect(function(name: string, data: any)
		self:_onEvent("run", name, data or {})
	end))
	trove:Add(self._island.Event:Connect(function(name: string, data: any)
		self:_onEvent("island", name, data or {})
	end))
	trove:Connect(UserInputService.LastInputTypeChanged, function()
		local now = deviceKind()
		if now ~= self._device then
			self._device = now
			if self._status == "Running" then
				self:_present()
			end
		end
	end)
	trove:Connect(ctx.screen.Changed, function()
		self._guide:layout()
		self._skipCard:layout()
	end)
	trove:Connect(RunService.Heartbeat, function(dt: number)
		self._tickAcc += dt
		if self._tickAcc < UPDATE_EVERY then
			return
		end
		self._tickAcc = 0
		self:_update()
	end)
	return self
end

-- CAPABILITIES ---------------------------------------------------------------------------------------------------------

function Controller._caps(self: any): { [string]: boolean }
	local caps: { [string]: boolean } = table.clone(self._run:capabilities())
	for k, v in self._island:capabilities() do
		caps[k] = v
	end
	return caps
end

-- FACTS AND EVENTS -----------------------------------------------------------------------------------------------------

function Controller._onEvent(self: any, source: string, name: string, data: { [string]: any })
	if self._status ~= "Running" then
		return
	end
	local f = self._facts
	self._lastEvent = source .. ":" .. name
	if name == "RunStarted" then
		-- a new run: the run facts start again; steps already completed stay completed
		local fresh = freshFacts()
		fresh.runActive = true
		fresh.portalEntered = true
		fresh.world = f.world
		fresh.parked, fresh.lap, fresh.upgraded, fresh.shopOpened = f.parked, f.lap, f.upgraded, f.shopOpened
		self._facts = fresh
		f = fresh
		self._retryLine = false
	elseif name == "RunRevived" then
		f.resultsShown = false
		f.runEnded = false
	elseif name == "SteerLeft" then
		f.steerLeft = true
	elseif name == "SteerRight" then
		f.steerRight = true
	elseif name == "HopLanded" then
		if data.onCar ~= false then
			f.landed = true
			if f.heatSeen then
				f.landedAfterHeat = true
			end
		end
	elseif name == "HopMissed" then
		f.missed = true
	elseif name == "ClaimConfirmed" then
		f.claim = { isNew = data.isNew ~= false, name = data.name }
	elseif name == "HeatWarning" then
		f.heatSeen = true
	elseif name == "RunEnded" then
		f.runEnded = true
		f.endCause = data.cause
	elseif name == "ResultsShown" then
		f.resultsShown = true
	elseif name == "RunClosed" then
		f.runActive = false
		f.resultsShown = false
	elseif name == "PortalEntered" then
		f.portalEnteredAt = os.clock()
		f.world = data.world
		if not self._real and (data.world == nil or data.world == "Downtown") then
			f.portalEntered = true
		end
	elseif name == "ArrivedHome" then
		f.arrivedHome = true
		f.runActive = false
		f.resultsShown = false
	elseif name == "CarParked" then
		if self._step and self._step.key == "Park" then
			f.parked = true
		end
	elseif name == "LapCue" then
		if self._step and self._step.key == "Earn" then
			f.lap = true
		end
	elseif name == "UpgradeConfirmed" then
		if self._step and self._step.key == "Upgrade" then
			f.upgraded = true
		end
	elseif name == "ShopOpened" then
		if self._step and self._step.key == "Shop" then
			f.shopOpened = true
		end
	end
	self:_react(name)
end

-- Is the active step satisfied by the facts? Returns the reason.
function Controller._satisfied(self: any): string?
	local step: Steps.Step? = self._step
	if not step then
		return nil
	end
	local f = self._facts
	local key = step.key
	if key == "Portal" then
		return if f.portalEntered then "portal" else nil
	elseif key == "Steer" then
		return if f.steerLeft and f.steerRight then "steered" else nil
	elseif key == "Hop" then
		return if f.landed then "landed" else nil
	elseif key == "Keys" then
		return if f.claim ~= nil then "claim" else nil
	elseif key == "Heat" then
		if f.landedAfterHeat then
			return "hop"
		elseif f.heatSeen and f.runEnded then
			return "runEnded"
		end
		return nil
	elseif key == "Home" then
		return if f.arrivedHome then "home" else nil
	elseif key == "Park" then
		return if f.parked then "parked" else nil
	elseif key == "Earn" then
		return if f.lap then "lap" else nil
	elseif key == "Upgrade" then
		return if f.upgraded then "upgraded" else nil
	elseif key == "Shop" then
		return if f.shopOpened then "shop" else nil
	end
	return nil
end

-- After any event: wake a waiting step, complete a satisfied one, or refresh what the player sees.
function Controller._react(self: any, name: string)
	local step: Steps.Step? = self._step
	if not step or self._status ~= "Running" then
		return
	end
	local f = self._facts
	if self._phase == "Done" then
		-- an urgent Heat warning does not wait for the celebration of the claim to finish
		if name == "HeatWarning" and step.key == "Keys" then
			self:_advance()
		end
		return
	end
	local key = step.key
	if key == "Heat" then
		if self._phase == "Waiting" then
			if f.heatSeen then
				self._phase = "Active"
				self._enteredAt = os.clock() -- the 8 seconds count from when the instruction appears
				self:_beginActive()
			elseif f.runEnded or not f.runActive then
				self:_skipStep("Heat was not observed before the run ended")
				return
			end
		end
	elseif key == "Home" then
		if self._phase == "Waiting" and f.resultsShown then
			self._phase = "Active"
			self._enteredAt = os.clock()
			self:_beginActive()
		end
	end
	local why = self:_satisfied()
	if why then
		self:_complete(why, false)
		return
	end
	if
		name == "HopMissed"
		or name == "RunEnded"
		or name == "RunClosed"
		or name == "ArrivedHome"
		or name == "ResultsShown"
	then
		self:_beginActive() -- the guidance may change (try again, back to the portal, the results button)
	end
	self:_present()
end

-- STEP FLOW ------------------------------------------------------------------------------------------------------------

function Controller.start(self: any)
	if self._status ~= "Idle" then
		return
	end
	self._status = "Running"
	self._funnel:setSession(self._options.session or "first")
	self:_enter(self._options.startStep or 0)
end

function Controller._enter(self: any, index: number)
	local count = Steps.Count
	local i = index
	local caps = self:_caps()
	local step = Steps.get(i)
	while step do
		local missing: string? = nil
		for _, need in step.needs do
			if caps[need] ~= true then
				missing = need
				break
			end
		end
		if not missing then
			break
		end
		self._skipped[i] = "capability missing: " .. missing
		self._funnel:unavailable(i, step.key, "capability missing: " .. missing)
		i += 1
		step = Steps.get(i)
	end
	if not step or i >= count then
		self:stop("Finished")
		return
	end
	self._stepTrove:Clean()
	self._index = i
	self._step = step
	self._hinted = false
	self._retryLine = false
	self._arrived = false
	self._enteredAt = os.clock()
	local f = self._facts
	f.parked, f.lap, f.upgraded, f.shopOpened = false, false, false, false
	self._phase = "Active"
	self._funnel:started(i, step.key)
	if step.key == "Steer" then
		self._run:resetSteer()
	end
	-- steps that wait for something real before they show their instruction
	if step.key == "Heat" and not f.heatSeen then
		if f.runEnded then
			self:_skipStep("Heat was not observed before the run ended")
			return
		end
		self._phase = "Waiting"
	elseif step.key == "Home" then
		if not f.runActive then
			-- already back on the island (or no run): there is nothing to go home from
			self:_present()
			self:_complete("notInRun", true)
			return
		elseif not f.resultsShown then
			self._phase = "Waiting"
		end
	end
	if self._phase == "Active" then
		self:_beginActive()
	end
	self:_present()
	if step.key == "Start" then
		self._banner:celebrate()
	end
	local why = self:_satisfied()
	if why and self._phase == "Active" then
		self:_complete(why, true)
	end
end

-- The guidance of an active step: the trail and arrow, the hand, or nothing.
function Controller._beginActive(self: any)
	local step: Steps.Step? = self._step
	if not step or self._status ~= "Running" then
		return
	end
	local guide = self._guide
	local ground = step.ground
	local f = self._facts
	-- a run step with no run in progress: lead back to the portal
	if step.where == "Run" and not f.runActive then
		ground = "DowntownPortal"
	end
	self._groundKey = ground
	local pos = if ground then self._island:getTarget(ground) else nil
	guide:setGround(pos, if ground then self._island:getTargetStyle(ground) else nil)
	self._lastRouteAt = -math.huge
	if not ground then
		self._route:setRoute(nil)
	end
	local uiKey = step.ui
	local wantUi = uiKey ~= nil and self._phase == "Active" and (step.where ~= "Run" or f.runActive)
	if uiKey == "Hop" and not (self._options.uiTargets and self._options.uiTargets.Hop) then
		wantUi = false
	end
	if wantUi and uiKey then
		local ctx = self._ctx
		local options = {
			uiTargets = self._options.uiTargets,
			menu = self._options.menu,
			run = self._run,
		}
		guide:setUi(function()
			return Targets.resolve(uiKey, ctx, options)
		end, { mask = step.mask == true })
	else
		guide:setUi(nil)
	end
end

-- What the banner shows right now (written to store.tutorial; the banner only draws it).
function Controller._present(self: any)
	local step: Steps.Step? = self._step
	if not step or self._status ~= "Running" then
		return
	end
	local f = self._facts
	local text = Strings.step(step.index)
	local title, line = text.title, text.line
	local controls: { [string]: any }? = nil
	local state = "Active"
	local placement = if step.where == "Island" then "Home" else "Run"
	local needsRun = step.where == "Run" and not f.runActive

	if self._phase == "Done" then
		state = "Done"
		line = Strings.get("done.line")
		if step.key == "Keys" and f.claim then
			local verified = self._run.mode == "Real" and f.claim.isNew == true
			if verified then
				title = Strings.get("claim.verified.title")
				line = if self._run:capabilities().claimSaved
					then Strings.get("claim.saved.line")
					else Strings.get("claim.verified.line")
			elseif self._run.mode == "Real" then
				title = Strings.get("claim.joyride.title")
				line = Strings.get("claim.joyride.line")
			else
				title = Strings.get("claim.preview.title")
				line = Strings.get("claim.preview.line")
			end
		end
		if step.key == "Ready" then
			line = text.line
		end
	elseif self._phase == "Waiting" then
		if step.key == "Heat" then
			title, line = Strings.get("heat.wait.title"), Strings.get("heat.wait.line")
			controls = { kind = "Hop", device = self._device, done = false }
		else
			title, line = Strings.get("home.wait.title"), Strings.get("home.wait.line")
		end
	else
		if needsRun then
			line = Strings.get("rerun")
		elseif step.key == "Portal" and self._retryLine then
			line = Strings.get("portal.retry")
		elseif step.key == "Hop" and f.missed and not f.landed then
			line = Strings.get("hop.miss")
		elseif step.key == "Home" then
			line = if self._run.homeLabel == "Retry" then Strings.get("home.retry") else Strings.get("home.fixture")
		end
		if step.controls == "Steer" and not needsRun then
			controls = { kind = "Steer", device = self._device, left = f.steerLeft, right = f.steerRight }
		elseif step.controls == "Hop" and not needsRun then
			controls = { kind = "Hop", device = self._device, done = f.landed }
		end
	end
	if self._phase == "Active" and needsRun then
		placement = "Home" -- the player is back on the island, walking to the portal
	end

	local hintNote: string? = nil
	if step.key == "Ready" then
		hintNote = Strings.get("ready.preview")
	end
	local view = {
		step = step.index + 1,
		steps = Steps.Count,
		objective = title,
		instruction = line,
		count = 0,
		goal = 0,
		hint = hintNote,
		state = if step.key == "Ready" then "Done" else state,
		icons = step.icons,
		controls = controls,
		big = step.big == true or step.key == "Ready",
	}
	-- the banner is only rewritten when what it shows changed
	local sig = table.concat({
		placement,
		title,
		line,
		view.state,
		tostring(hintNote),
		if controls
			then (
				controls.kind
				.. tostring(controls.device)
				.. tostring(controls.left)
				.. tostring(controls.right)
				.. tostring(controls.done)
			)
			else "",
	}, "|")
	if sig == self._lastSig and self._ctx.store:get().tutorial ~= nil then
		return
	end
	self._lastSig = sig
	self._banner:setPlacement(placement)
	self._ctx.store:set("tutorial", view)
end

function Controller._complete(self: any, reason: string, fast: boolean)
	local step: Steps.Step? = self._step
	if not step or self._phase == "Done" or self._status ~= "Running" then
		return
	end
	self._completed[step.index] = reason
	self._funnel:completed(step.index, step.key, { reason = reason, real = self._real })
	self._phase = "Done"
	self._doneAt = os.clock()
	self._doneSeconds = if fast then FAST_DONE_SECONDS else self._timings.done
	self._groundKey = nil
	self._guide:clear()
	self._route:setRoute(nil)
	self:_present()
end

function Controller._skipStep(self: any, why: string)
	local step: Steps.Step? = self._step
	if not step then
		return
	end
	self._skipped[step.index] = why
	self._funnel:unavailable(step.index, step.key, why)
	self:_advance()
end

function Controller._advance(self: any)
	if self._status ~= "Running" then
		return
	end
	self._guide:clear()
	self._route:setRoute(nil)
	self:_enter(self._index + 1)
end

-- Test and fixture jump: make `index` the active step (earlier steps count as completed, nothing is logged for them).
function Controller.jump(self: any, index: number, facts: { [string]: any }?)
	if self._status == "Idle" then
		self._status = "Running"
	end
	if self._status ~= "Running" then
		return
	end
	if facts then
		for k, v in facts do
			self._facts[k] = v
		end
	end
	self._guide:clear()
	self._route:setRoute(nil)
	self:_enter(math.clamp(index, 0, Steps.Count - 1))
end

-- UPDATE (10 Hz): timers, the timed hint, the trail, the portal retry ---------------------------------------------------

function Controller._update(self: any)
	if self._status ~= "Running" then
		return
	end
	local step: Steps.Step? = self._step
	if not step then
		return
	end
	local now = os.clock()
	local f = self._facts
	if self._phase == "Done" then
		if step.key == "Ready" then
			return
		end
		if now - self._doneAt >= self._doneSeconds then
			self:_advance()
		end
		return
	end
	if self._phase ~= "Active" then
		return
	end
	-- timers: step 0 (2 s) and step 11 (3 s)
	if step.key == "Start" and now - self._enteredAt >= self._timings.start then
		self:_complete("timer", false)
		return
	elseif step.key == "Ready" then
		if now - self._enteredAt >= self._timings.ready then
			self._completed[step.index] = "timer"
			self._funnel:completed(step.index, step.key, { reason = "timer", real = self._real })
			self:stop("Finished")
		end
		return
	end
	-- the portal did not start a run (Real): say so and keep the step
	if
		step.key == "Portal"
		and self._real
		and f.portalEnteredAt
		and not f.runActive
		and not self._retryLine
		and now - (f.portalEnteredAt :: number) >= PORTAL_RETRY_SECONDS
	then
		self._retryLine = true
		self:_present()
	end
	-- the one timed hint
	if not self._hinted and now - self._enteredAt >= self._timings.hint then
		self._hinted = true
		self._hintCount += 1
		self._guide:pulse()
		self._banner:wiggle()
		Sounds.play("Tap")
	end
	-- the trail follows the player
	if self._groundKey then
		self:_reroute(now)
	end
end

function Controller._reroute(self: any, now: number)
	local key: string = self._groundKey
	local from = self._island:playerPosition()
	local to = self._island:getTarget(key)
	if not from or not to then
		self._route:setRoute(nil)
		return
	end
	local last = self._lastRoutePos
	local moved = if last then (from - last).Magnitude else math.huge
	if now - self._lastRouteAt < REROUTE_EVERY and moved < 20 then
		return
	end
	if last and moved < REROUTE_MOVED and now - self._lastRouteAt < 1.5 then
		return
	end
	self._lastRouteAt = now
	self._lastRoutePos = from
	local flat = Vector3.new(from.X - to.X, 0, from.Z - to.Z).Magnitude
	if flat < ARRIVED then
		self._arrived = true
		self._route:setRoute(nil) -- close enough: the arrow and glow take over
		return
	end
	self._arrived = false
	local points = self._island:route(from, key)
	self._routeCount += 1
	self._route:setRoute(Waypoints.trimStart(points, TRAIL_SKIP))
end

-- SKIP, FINISH, STOP ---------------------------------------------------------------------------------------------------

function Controller.requestSkip(self: any)
	if self._status ~= "Running" then
		return
	end
	self._skipCard:open()
end

function Controller.skip(self: any)
	if self._status ~= "Running" then
		return
	end
	local step: Steps.Step? = self._step
	if step then
		self._funnel:skipped(step.index, step.key) -- Skip is never logged as completion of the remaining steps
	end
	self:stop("Skipped")
end

function Controller.stop(self: any, reason: string)
	if self._ended then
		return
	end
	self._ended = true
	local wasRunning = self._status == "Running"
	self._status = if reason == "Skipped" then "Skipped" elseif reason == "Finished" then "Finished" else "Stopped"
	self._finishedAt = os.clock()
	self._skipCard:close()
	self._guide:clear()
	self._route:setRoute(nil)
	self._ctx.store:set("tutorial", nil)
	if wasRunning and (reason == "Skipped" or reason == "Finished") then
		self._ctx.store:emit({
			id = "tutorial-" .. string.lower(reason) .. "-" .. tostring(os.clock()),
			kind = "Toast",
			text = if reason == "Skipped" then Strings.get("skip.done") else Strings.get("finished"),
			tone = "Info",
		})
	end
	local cb = self._options.onEnded
	if cb then
		task.spawn(cb, reason)
	end
	self._stepTrove:Clean()
	self._trove:Destroy()
end

-- STAND-IN EVENTS (the fixture) -------------------------------------------------------------------------------------------

function Controller.emitRun(self: any, name: string, data: { [string]: any }?)
	self._run:emit(name, data)
end

function Controller.emitIsland(self: any, name: string, data: { [string]: any }?)
	self._island:emit(name, data)
end

function Controller.getRunAdapter(self: any): any
	return self._run
end

function Controller.getIslandAdapter(self: any): any
	return self._island
end

function Controller.getFunnel(self: any): any
	return self._funnel
end

function Controller.getBanner(self: any): any
	return self._banner
end

function Controller.getGuide(self: any): any
	return self._guide
end

function Controller.getSkipCard(self: any): any
	return self._skipCard
end

function Controller.getStepIndex(self: any): number
	return self._index
end

function Controller.isRunning(self: any): boolean
	return self._status == "Running"
end

function Controller.getDebugState(self: any): { [string]: any }
	local step: Steps.Step? = self._step
	local out: { [string]: any } = {
		status = self._status,
		mode = self._mode,
		step = self._index,
		key = if step then step.key else nil,
		phase = self._phase,
		hinted = self._hinted,
		hints = self._hintCount,
		secondsInStep = if self._status == "Running" then os.clock() - self._enteredAt else nil,
		lastEvent = self._lastEvent,
		retryLine = self._retryLine,
		groundKey = self._groundKey,
		trailReroutes = self._routeCount,
		arrivedAtTarget = self._arrived,
		completed = table.clone(self._completed),
		skipped = table.clone(self._skipped),
		device = self._device,
		facts = table.clone(self._facts),
		funnel = self._funnel:getDebugState(),
		timings = table.clone(self._timings),
	}
	if self._status == "Running" then
		out.capabilities = self:_caps()
		out.banner = self._banner:getDebugState()
		out.route = self._route:getDebugState()
		out.guide = self._guide:getDebugState()
		out.skipCard = self._skipCard:getDebugState()
		out.run = self._run:getDebugState()
		out.island = self._island:getDebugState()
	end
	return out
end

return Controller
