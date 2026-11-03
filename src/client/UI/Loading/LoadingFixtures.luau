--!strict
-- Test scenarios for the loading screen (big round M15-03b). SELF-CONTAINED like the rest of the folder. Each scenario builds
-- a FAKE Env (no network, no real asset) around a virtual clock that runs `timeScale` times faster than real time, so the
-- 12 second watchdog can be checked in about a second, and feeds the real LoadingController. Nothing here is a game rule and
-- no asset id is used (the "assets" are made-up strings that only the fake preload ever sees).
--
--   local run = LoadingFixtures.run("SlowOptionalImage", { timeScale = 12, sink = LoadingScreen.sinkFor(view, 0.3) })
--   run.handle.summary()   run.log   (every sink call, in order, with the virtual time)   run.cancel()
--   LoadingFixtures.Names  -- the scenarios
--
-- The one scenario that cannot live here is "missing shared module": it is the boot script's own branch (it requires the
-- Loading modules inside pcall; if they are not there it leaves Roblox's default loading screen alone and returns). Test it
-- by renaming the mapped Loading folder in Studio before a Play session.

local LoadingController = require(script.Parent.LoadingController)

local LoadingFixtures = {}

export type Entry = { at: number, kind: string, value: any }

export type Run = {
	handle: LoadingController.Handle,
	log: { Entry },
	cancel: () -> (),
	lateCallbacks: () -> number, -- stale callbacks delivered after finish
	rejoinPresses: () -> number,
	staleSinkCalls: () -> number, -- sink calls that arrived after finish (must stay 0)
}

type Spec = {
	describe: string,
	manifest: { string },
	config: { requireReadyFlag: boolean? }?,
	build: (
		clock: () -> number,
		wait: (number) -> ()
	) -> {
		loadedAt: number?, -- virtual seconds until game:IsLoaded is true (nil = never)
		characterAt: number?,
		readyAt: number?, -- the readiness flag turns true then (nil = flag not in use)
		preload: (ids: { string }, onItem: (string, string) -> ()) -> (),
	},
}

local FAKE = { "fixture://first-view-art", "fixture://button-click", "fixture://logo-hero" }

local SPECS: { [string]: Spec } = {
	InstantReady = {
		describe = "everything is ready at once and every asset succeeds: finishes in a poll or two",
		manifest = FAKE,
		build = function(_clock, _wait)
			return {
				loadedAt = 0,
				characterAt = 0,
				preload = function(ids, onItem)
					for _, id in ids do
						onItem(id, "Success")
					end
				end,
			}
		end,
	},
	SlowOptionalImage = {
		describe = "ready at 1 s, but one optional image never answers: dismissed at the 12 s watchdog (ReadyBackground)",
		manifest = FAKE,
		build = function(_clock, wait)
			return {
				loadedAt = 0.5,
				characterAt = 1,
				preload = function(ids, onItem)
					wait(0.6)
					onItem(ids[1], "Success")
					wait(0.6)
					onItem(ids[2], "Success")
					wait(1000) -- the third never settles in time (the fetch is not cancelled by the watchdog)
					onItem(ids[3], "Success")
				end,
			}
		end,
	},
	FailedSound = {
		describe = "one asset fails: the screen says so honestly and still finishes when the rest settle",
		manifest = FAKE,
		build = function(_clock, wait)
			return {
				loadedAt = 0,
				characterAt = 0.4,
				preload = function(ids, onItem)
					wait(0.3)
					onItem(ids[1], "Success")
					onItem(ids[2], "Failure")
					wait(0.3)
					onItem(ids[3], "Success")
				end,
			}
		end,
	},
	UnavailableImage = {
		describe = "an image is unavailable (TimedOut): counted as resolved but not successful",
		manifest = FAKE,
		build = function(_clock, wait)
			return {
				loadedAt = 0,
				characterAt = 0.2,
				preload = function(ids, onItem)
					wait(0.4)
					onItem(ids[1], "TimedOut")
					onItem(ids[2], "Success")
					onItem(ids[3], "Success")
				end,
			}
		end,
	},
	EmptyManifest = {
		describe = "no assets to preload: an indeterminate bar and stage labels only, never a percentage",
		manifest = {},
		build = function(_clock, _wait)
			return {
				loadedAt = 0.3,
				characterAt = 0.8,
				preload = function(_ids, _onItem) end,
			}
		end,
	},
	NoNetworkCompletion = {
		describe = "nothing ever completes: at 12 s the screen says Still connecting... and offers Rejoin, never 100 percent",
		manifest = FAKE,
		build = function(_clock, wait)
			return {
				loadedAt = nil,
				characterAt = nil,
				preload = function(_ids, _onItem)
					wait(100000)
				end,
			}
		end,
	},
	LateCallbackAfterClose = {
		describe = "the screen finishes, then stale preload callbacks arrive: they touch nothing",
		manifest = FAKE,
		build = function(_clock, wait)
			return {
				loadedAt = 0,
				characterAt = 0,
				preload = function(ids, onItem)
					wait(0.2)
					onItem(ids[1], "Success")
					onItem(ids[2], "Success")
					onItem(ids[3], "Success")
					wait(3)
					-- late and duplicated deliveries after the screen has gone
					onItem(ids[1], "Failure")
					onItem(ids[3], "Failure")
				end,
			}
		end,
	},
	WaitsForGameReady = {
		describe = "the game has loaded and the character exists, but the readiness flag arrives only at 4 s",
		manifest = FAKE,
		config = { requireReadyFlag = true },
		build = function(_clock, wait)
			return {
				loadedAt = 0,
				characterAt = 0.5,
				readyAt = 4,
				preload = function(ids, onItem)
					wait(0.5)
					for _, id in ids do
						onItem(id, "Success")
					end
				end,
			}
		end,
	},
}

LoadingFixtures.Names = table.freeze({
	"InstantReady",
	"SlowOptionalImage",
	"FailedSound",
	"UnavailableImage",
	"EmptyManifest",
	"NoNetworkCompletion",
	"LateCallbackAfterClose",
	"WaitsForGameReady",
})

function LoadingFixtures.describe(name: string): string?
	local spec = SPECS[name]
	return if spec then spec.describe else nil
end

-- A sink that only records (no view): { at, kind, value } for every call.
function LoadingFixtures.recordingSink(log: { Entry }, clock: () -> number): LoadingController.Sink
	local function add(kind: string, value: any)
		table.insert(log, { at = clock(), kind = kind, value = value })
	end
	return {
		stage = function(text: string)
			add("stage", text)
		end,
		count = function(text: string?)
			add("count", text)
		end,
		progress = function(fraction: number?)
			add("progress", fraction)
		end,
		note = function(text: string?)
			add("note", text)
		end,
		status = function(text: string?)
			add("status", text)
		end,
		action = function(label: string?, _onPress: (() -> ())?)
			add("action", label)
		end,
		finish = function(reason: string, _summary: LoadingController.Summary)
			add("finish", reason)
		end,
	}
end

-- Plays one scenario. `options.sink` is an optional extra sink (for example a real view's); every call is also recorded.
function LoadingFixtures.run(name: string, options: { timeScale: number?, sink: LoadingController.Sink? }?): Run?
	local spec = SPECS[name]
	if not spec then
		return nil
	end
	local opts = options or {}
	local scale = math.max(opts.timeScale or 1, 0.01)
	local start = os.clock()
	local function clock(): number
		return (os.clock() - start) * scale
	end
	local function wait(seconds: number)
		task.wait(seconds / scale)
	end
	local fake = spec.build(clock, wait)
	local log: { Entry } = {}
	local rejoins = 0
	local stale = 0
	local lateCalls = 0
	local finished = false
	local recording = LoadingFixtures.recordingSink(log, clock)
	local extra = opts.sink
	local function both(): LoadingController.Sink
		local function twice(kind: string): (any, any) -> ()
			return function(a: any, b: any)
				if finished then
					stale += 1
					return
				end
				if kind == "finish" then
					finished = true
				end
				(recording :: any)[kind](a, b)
				if extra then
					(extra :: any)[kind](a, b)
				end
			end
		end
		return {
			stage = twice("stage"),
			count = twice("count"),
			progress = twice("progress"),
			note = twice("note"),
			status = twice("status"),
			action = twice("action"),
			finish = twice("finish"),
		} :: any
	end
	local env: LoadingController.Env = {
		isLoaded = function(): boolean
			return fake.loadedAt ~= nil and clock() >= fake.loadedAt
		end,
		hasCharacter = function(): boolean
			return fake.characterAt ~= nil and clock() >= fake.characterAt
		end,
		gameReady = function(): boolean?
			if fake.readyAt == nil then
				return nil
			end
			return clock() >= fake.readyAt
		end,
		preload = function(ids, onItem)
			fake.preload(ids, function(id: string, status: string)
				if finished then
					lateCalls += 1
				end
				onItem(id, status)
			end)
		end,
		now = clock,
		wait = wait,
		spawn = function(fn: () -> ())
			task.spawn(fn)
		end,
		rejoin = function()
			rejoins += 1
		end,
	}
	local handle = LoadingController.start(env, {
		manifest = spec.manifest,
		requireReadyFlag = if spec.config then spec.config.requireReadyFlag else nil,
	}, both())
	return {
		handle = handle,
		log = log,
		cancel = handle.cancel,
		lateCallbacks = function(): number
			return lateCalls
		end,
		rejoinPresses = function(): number
			return rejoins
		end,
		staleSinkCalls = function(): number
			return stale
		end,
	}
end

return LoadingFixtures
