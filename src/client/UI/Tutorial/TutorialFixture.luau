--!strict
-- TutorialFixture: the HUD playground driver for the tutorial (BRIEF M11-08, M11-12). It starts the tutorial in Fixture mode
-- on the playground's own components and then plays the part of the run and the island with STAND-IN events, so every one
-- of the twelve steps can be stepped through, fast-forwarded, interrupted, skipped and replayed in the preview. Nothing it
-- does is real: a stand-in claim says "New car preview!", a stand-in lap grants no Cash, and the Heat the fixture shows on
-- the Heat panel is the playground's own preview state (the real tutorial only ever observes Heat).
--
--   Fixture.start(api, options?) -> Controller        api = the playground's api table (components, store, screen, layers, backdrop)
--   Fixture.eventsFor(index) -> { Step }              the stand-in events that complete step `index` (see below)
--   Fixture.complete(api, controller, index, wait?)   play those events for the ACTIVE step (wait(seconds) between them)
--   Fixture.jump(api, controller, index)              make `index` the active step with the playground in the matching mode
--   Fixture.walkthrough(api, controller, wait, hold?) every step in order: hold each for `hold` seconds, then complete it
--   Fixture.enterMode(api, index)                     Home, Run or Results for the step
--
-- Stand-in event table (EVENTS): each entry is { source: "run" | "island", name, data? }.
--   0 none (2 s timer)  1 PortalEntered then RunStarted  2 SteerLeft, SteerRight  3 HopPressed, HopLanded
--   4 KeysStarted, ClaimConfirmed  5 HeatWarning, HopPressed, HopLanded  6 RunEnded, ResultsShown, then ArrivedHome
--   7 CarParked  8 LapCue  9 UpgradeConfirmed  10 ShopOpened  11 none (3 s timer)

local Tutorial = require(script.Parent)
local Steps = require(script.Parent.TutorialSteps)

local Fixture = {}

export type Event = { source: string, name: string, data: { [string]: any }? }

local EVENTS: { [number]: { Event } } = {
	[0] = {},
	[1] = {
		{ source = "island", name = "PortalEntered", data = { world = "Downtown" } },
		{ source = "run", name = "RunStarted" },
	},
	[2] = {
		{ source = "run", name = "SteerLeft" },
		{ source = "run", name = "SteerRight" },
	},
	[3] = {
		{ source = "run", name = "HopPressed", data = { onCar = true } },
		{ source = "run", name = "HopLanded", data = { onCar = true } },
	},
	[4] = {
		{ source = "run", name = "KeysStarted" },
		{ source = "run", name = "ClaimConfirmed", data = { isNew = true, name = "Puglet" } },
	},
	[5] = {
		{ source = "run", name = "HeatWarning", data = { stage = "Warning" } },
		{ source = "run", name = "HopPressed", data = { onCar = true } },
		{ source = "run", name = "HopLanded", data = { onCar = true } },
	},
	[6] = {
		{ source = "run", name = "RunEnded", data = { cause = "Overheated" } },
		{ source = "run", name = "ResultsShown" },
		{ source = "run", name = "RunClosed" },
		{ source = "island", name = "ArrivedHome" },
	},
	[7] = { { source = "island", name = "CarParked" } },
	[8] = { { source = "island", name = "LapCue" } },
	[9] = { { source = "island", name = "UpgradeConfirmed", data = { level = 2 } } },
	[10] = { { source = "island", name = "ShopOpened" } },
	[11] = {},
}

function Fixture.eventsFor(index: number): { Event }
	return EVENTS[index] or {}
end

local function comp(api: any, key: string): any
	return api.components and api.components[key]
end

-- The playground mode that matches a step: the island steps stand at Home, the run steps in the Run HUD, step 6 on the results.
function Fixture.enterMode(api: any, index: number)
	local step = Steps.get(index)
	if not step then
		return
	end
	local state = api.store:get()
	if step.where == "Island" then
		if state.mode ~= "Home" and api.goHome then
			api.goHome()
		end
	elseif step.where == "Run" then
		if state.mode ~= "Run" and api.setMode then
			api.setMode("Run")
		end
	elseif step.where == "Results" then
		if state.mode == "Home" and api.setMode then
			api.setMode("Run")
		end
		if api.store:get().mode == "Run" and api.resultsFromRun then
			api.resultsFromRun("Overheated")
		end
	end
	if api.applyMode then
		api.applyMode()
	end
end

function Fixture.start(api: any, options: { [string]: any }?): any
	local o: { [string]: any } = if options then table.clone(options) else {}
	local props = if api.backdrop then api.backdrop.props else nil
	local ctx = {
		store = api.store,
		screen = api.screen,
		layer = api.layers.Hud,
		world = api.backdrop.world,
	}
	-- the playground lot's ground is at y 0.2: targets stand on it, the arrow floats above
	local function ground(p: Vector3): Vector3
		return Vector3.new(p.X, 0.3, p.Z)
	end
	local targets: { [string]: Vector3 } = {}
	if props then
		targets.DowntownPortal = ground(props.portal.Position)
		targets.Shopkeeper = ground(props.kiosk.Position)
		targets.Paddock = ground(props.garage.Position)
		targets.Raceway = ground(props.kiosk.Position + Vector3.new(0, 0, 24))
	end
	local controllerOptions = {
		mode = "Fixture",
		banner = o.banner or comp(api, "tutorial"),
		route = o.route or comp(api, "route"),
		menu = o.menu or comp(api, "menu"),
		targets = o.targets or targets,
		isShopOpen = o.isShopOpen or function(): boolean
			local shop = comp(api, "shop")
			return shop ~= nil and shop:isOpen()
		end,
		uiTargets = o.uiTargets or {
			Hop = function(): GuiObject?
				local hop = comp(api, "hop")
				-- the round Hop button itself, not its full-layer canvas
				return if hop and hop._body then hop._body :: GuiObject else nil
			end,
		},
		timings = o.timings,
		startStep = o.startStep,
		session = o.session,
		onEnded = o.onEnded,
	}
	Fixture.enterMode(api, o.startStep or 0)
	return Tutorial.start(ctx, controllerOptions :: any)
end

-- Plays the stand-in events of the ACTIVE step (a few tenths of a second apart so each result can be seen).
function Fixture.complete(api: any, controller: any, index: number, wait: ((number) -> ())?)
	local pause = wait or function(_: number) end
	local list = EVENTS[index] or {}
	for i, e in list do
		if not controller:isRunning() or controller:getStepIndex() ~= index then
			return
		end
		-- step 5 and 6 need the playground to look the part
		if e.name == "HeatWarning" and api.patchRun then
			api.patchRun({ heat = 0.7 })
		elseif e.name == "RunEnded" and api.resultsFromRun and api.store:get().mode == "Run" then
			api.resultsFromRun("Overheated")
		elseif e.name == "ArrivedHome" and api.goHome then
			api.goHome()
		end
		if e.source == "run" then
			controller:emitRun(e.name, e.data)
		else
			controller:emitIsland(e.name, e.data)
		end
		if i < #list then
			pause(if e.name == "ResultsShown" then 1.8 else 0.45) -- let "Go home!" be seen on the results
		end
	end
end

function Fixture.jump(api: any, controller: any, index: number)
	local facts: { [string]: any } = {}
	local step = Steps.get(index)
	if step and step.where ~= "Island" then
		facts.runActive = true
		facts.portalEntered = true
	end
	if index == 6 then
		facts.runEnded = true
		facts.resultsShown = true
	end
	Fixture.enterMode(api, index)
	controller:jump(index, facts)
end

-- Every step in order. `wait` is the scenario host's wait (it stops when the scenario is cancelled).
function Fixture.walkthrough(api: any, controller: any, wait: (number) -> (), hold: number?)
	local seconds = hold or 1.4
	for index = 0, Steps.Count - 1 do
		if not controller:isRunning() then
			return
		end
		Fixture.enterMode(api, index)
		if index == 6 then
			-- the ride ends and the results card is up: "Go home!" shows with the hand on the Home button
			controller:emitRun("RunEnded", { cause = "Overheated" })
			controller:emitRun("ResultsShown")
			wait(seconds)
			controller:emitRun("RunClosed")
			if api.goHome then
				api.goHome()
			end
			controller:emitIsland("ArrivedHome")
			wait(0.9)
			continue
		end
		wait(seconds)
		if index == 0 or index == Steps.Count - 1 then
			wait(2.6) -- the two timed steps finish by themselves
		else
			Fixture.complete(api, controller, index, wait)
			wait(0.9)
		end
	end
end

return Fixture
