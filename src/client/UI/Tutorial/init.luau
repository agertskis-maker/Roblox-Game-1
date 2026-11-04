--!strict
-- Tutorial: the public API of the Car Hop tutorial (Lane 3, BRIEF M11). The folder is src/client/UI/Tutorial; the pieces:
--   TutorialSteps        the 12 steps as data            TutorialStrings   every word, for localization
--   TutorialController   the one state machine           TutorialFunnel    the analytics SPY (intended calls only)
--   TutorialRunAdapter   the run seam (stand-in or real) TutorialIslandAdapter  the island seam (stand-in or real)
--   TutorialWaypoints    the walkable-path graph         TutorialTargets   finds the UI target of the pointing hand
--   TutorialGuide        arrow, glow, hand, mask         TutorialSkipCard  the "Skip tutorial?" confirm
--   TutorialFixture      the HUD playground driver (stand-in events, step by step)
--   Home/TutorialBanner  the banner (the look)           Home/TutorialRoute the white chevron trail
--
-- Progress is for this play session only: nothing is saved, granted or sent. The funnel is a local spy.
--
--   Tutorial.start(ctx, options?) -> Controller   begin (an earlier tutorial is stopped first). ctx = { store, screen, layer, world }
--                                                 options: see TutorialController.Options. mode = "Fixture" (default) or "Real".
--   Tutorial.skip()                               skip NOW, no question (Settings and scripts use it); the Skip button asks first
--   Tutorial.requestSkip()                        open the "Skip tutorial?" card (what the banner's Skip button does)
--   Tutorial.replay()                             start again from step 0 with the same ctx and options (a replay session, kept apart
--                                                 from first-time funnel claims)
--   Tutorial.getDebugState() -> table             one snapshot of everything (status, step, facts, adapters, banner, trail, funnel)
--   Tutorial.attachRun(run)                       REAL mode: observe a RunController-like object (getDebugState and Ended only).
--                                                 Call it right after run:start(); the tutorial detaches when the run ends
--   Tutorial.emitRun(name, data?) / Tutorial.emitIsland(name, data?)   stand-in events (the fixture) or relays from a lane
--   Tutorial.isActive() -> boolean   Tutorial.getController() -> Controller?   Tutorial.getFunnel() -> Funnel
--   Tutorial.onEnded(fn) -> () -> ()              fn("Finished" | "Skipped" | "Stopped"); returns a disconnect

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Controller = require(script.TutorialController)
local Funnel = require(script.TutorialFunnel)
local Signal = require(ReplicatedStorage.Packages.Signal)
local Trove = require(ReplicatedStorage.Packages.Trove)

local Tutorial = {}

local moduleTrove = Trove.new() -- the run observation hand-over; lives as long as the client, by design
local runTrove = moduleTrove:Extend()
local ended = moduleTrove:Add(Signal.new())
local funnel = Funnel.new()
local current: any = nil
local lastCtx: any = nil
local lastOptions: Controller.Options = {}
local firstStarted = false
local pendingRun: any = nil

local function attachPending()
	local c = current
	if c and c:isRunning() and pendingRun ~= nil and c._real then
		c:getRunAdapter():attach(pendingRun)
	end
end

function Tutorial.start(ctx: any, options: Controller.Options?): any
	if current then
		current:stop("Stopped")
		current = nil
	end
	local o: Controller.Options = if options then table.clone(options) else {}
	lastCtx = ctx
	lastOptions = table.clone(o)
	if o.funnel == nil then
		o.funnel = funnel
	end
	if o.session == nil then
		o.session = if firstStarted then "replay" else "first"
	end
	firstStarted = true
	local previousEnded = o.onEnded
	o.onEnded = function(reason: string)
		ended:Fire(reason)
		if previousEnded then
			previousEnded(reason)
		end
	end
	local controller = Controller.new(ctx, o)
	current = controller
	controller:start()
	attachPending()
	return controller
end

function Tutorial.skip()
	local c = current
	if c and c:isRunning() then
		c:skip()
	end
end

function Tutorial.requestSkip()
	local c = current
	if c and c:isRunning() then
		c:requestSkip()
	end
end

function Tutorial.stop()
	local c = current
	if c then
		c:stop("Stopped")
		current = nil
	end
end

function Tutorial.replay(): any
	if not lastCtx then
		return nil
	end
	local o = table.clone(lastOptions)
	o.session = "replay"
	o.startStep = 0
	return Tutorial.start(lastCtx, o)
end

function Tutorial.attachRun(run: any)
	runTrove:Clean()
	pendingRun = run
	local signal: any = if run ~= nil then run.Ended else nil
	if signal ~= nil and type(signal.Connect) == "function" then
		runTrove:Add(signal:Connect(function()
			if pendingRun == run then
				pendingRun = nil -- a finished run is never attached again
			end
		end))
	end
	attachPending()
end

function Tutorial.emitRun(name: string, data: { [string]: any }?)
	local c = current
	if c and c:isRunning() then
		c:emitRun(name, data)
	end
end

function Tutorial.emitIsland(name: string, data: { [string]: any }?)
	local c = current
	if c and c:isRunning() then
		c:emitIsland(name, data)
	end
end

function Tutorial.isActive(): boolean
	local c = current
	return c ~= nil and c:isRunning()
end

function Tutorial.getController(): any
	return current
end

function Tutorial.getFunnel(): any
	return funnel
end

function Tutorial.onEnded(fn: (reason: string) -> ()): () -> ()
	local connection = ended:Connect(fn)
	return function()
		connection:Disconnect()
	end
end

function Tutorial.getDebugState(): { [string]: any }
	local c = current
	if not c then
		return { status = "None", funnel = funnel:getDebugState(), firstStarted = firstStarted }
	end
	local state = c:getDebugState()
	state.firstStarted = firstStarted
	return state
end

return Tutorial
