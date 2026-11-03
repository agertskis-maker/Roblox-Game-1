--!strict
-- LoadingController: the logic of the Car Hop loading screen (big round M15). SELF-CONTAINED on purpose: it requires no
-- module of the game (no Trove, no Tokens, no Signal), because it runs from ReplicatedFirst before any of them arrives.
-- Everything it touches in the engine goes through an injectable Env, so every path can be driven from a script
-- (see LoadingFixtures) without a real network or a real asset.
--
--   local handle = LoadingController.start(env, { manifest = { "rbxassetid://..." }, optionalSeconds = 12 }, sink)
--   handle.cancel()   handle.summary()   handle.isDone()
--
-- WHAT "READY" MEANS. Essential readiness = the game has loaded (game:IsLoaded) AND the local character has a root part AND,
-- when the readiness flag is in use, the game has said it is ready (a LocalPlayer attribute the lead's code sets once
-- streaming, the profile and the controls are up). game.Loaded alone is not proof of any of those and is never treated
-- as such. The ASSETS (a small deduplicated manifest of the first view's art and sounds) are optional: the screen waits for
-- them, but only up to `optionalSeconds` (12 s) once essential readiness is met; a timeout does not cancel the underlying
-- fetch (PreloadAsync has no timeout argument), it just stops waiting for it.
--
-- WHAT IT SHOWS. Stage text always. A bar fraction only against a KNOWN checklist: (assets resolved + essential gates met)
-- over (manifest size + number of gates), and none (an indeterminate bar) when the manifest is empty; never a fake percent.
-- "Resolved" counts every callback; "succeeded" only Success; a failure is shown honestly ("1 item couldn't load").
-- If essential readiness is not met after `optionalSeconds`, the screen says "Still connecting..." with the elapsed time and,
-- when the Env can rejoin, a working "Rejoin" button; it never shows a fake 100 percent and never ends as a frozen splash.
--
-- LATE CALLBACKS. A PreloadAsync callback that arrives after the screen was dismissed or cancelled is ignored and touches
-- nothing (the sink is never called again after finish or cancel).

local LoadingController = {}

LoadingController.OptionalSeconds = 12

export type Env = {
	isLoaded: () -> boolean,
	hasCharacter: () -> boolean,
	-- nil = the readiness flag is not in use; true / false = the game's own "playable" answer
	gameReady: () -> boolean?,
	-- starts ContentProvider:PreloadAsync(ids, callback) and returns when it returns (it yields). `onItem` gets each asset
	-- id and the final AssetFetchStatus name ("Success", "Failure", "TimedOut", "None").
	preload: (ids: { string }, onItem: (id: string, status: string) -> ()) -> (),
	now: () -> number,
	wait: (seconds: number) -> (),
	spawn: (fn: () -> ()) -> (),
	rejoin: (() -> ())?, -- a working recovery route (a teleport back to this place), when one exists
}

export type Config = {
	manifest: { string },
	optionalSeconds: number?,
	pollSeconds: number?,
	requireReadyFlag: boolean?,
}

export type Summary = {
	reason: string, -- "Running" | "Ready" | "ReadyBackground" | "Cancelled"
	elapsed: number,
	assetsTotal: number,
	resolved: number,
	succeeded: number,
	failed: number,
	loaded: boolean,
	character: boolean,
	ready: boolean?,
	stage: string,
	statusShown: boolean,
}

export type Sink = {
	stage: (text: string) -> (),
	count: (text: string?) -> (),
	progress: (fraction: number?) -> (),
	note: (text: string?) -> (),
	status: (text: string?) -> (),
	action: (label: string?, onPress: (() -> ())?) -> (),
	finish: (reason: string, summary: Summary) -> (),
}

export type Handle = {
	cancel: () -> (),
	summary: () -> Summary,
	isDone: () -> boolean,
}

-- a short, deduplicated list of non-empty strings (the manifest is small by design: only what the first view needs)
function LoadingController.dedupe(list: { any }): { string }
	local out: { string } = {}
	local seen: { [string]: boolean } = {}
	for _, item in list do
		if type(item) == "string" and item ~= "" and not seen[item] then
			seen[item] = true
			table.insert(out, item)
		end
	end
	return out
end

function LoadingController.start(env: Env, config: Config, sink: Sink): Handle
	local manifest = LoadingController.dedupe(config.manifest)
	local total = #manifest
	local inManifest: { [string]: boolean } = {}
	for _, id in manifest do
		inManifest[id] = true
	end
	local optionalSeconds = config.optionalSeconds or LoadingController.OptionalSeconds
	local poll = config.pollSeconds or 0.1
	local flagRequired = config.requireReadyFlag == true
	local gateCount = if flagRequired then 3 else 2

	local resolved, succeeded, failed = 0, 0, 0
	local seen: { [string]: boolean } = {}
	local preloadDone = total == 0
	local done = false
	local cancelled = false
	local t0 = env.now()
	local statusShown = false
	local lastStage = ""
	local reason = "Running"
	local loaded, character = false, false
	local flag: boolean? = nil

	local function summary(): Summary
		return {
			reason = reason,
			elapsed = env.now() - t0,
			assetsTotal = total,
			resolved = resolved,
			succeeded = succeeded,
			failed = failed,
			loaded = loaded,
			character = character,
			ready = flag,
			stage = lastStage,
			statusShown = statusShown,
		}
	end

	local function active(): boolean
		return not done and not cancelled
	end

	local function readLoaded()
		loaded = env.isLoaded()
		character = env.hasCharacter()
		flag = env.gameReady()
	end

	local function essentialReady(): boolean
		return loaded and character and (not flagRequired or flag == true)
	end

	local function describe()
		local stage: string
		if not loaded then
			stage = "Connecting..."
		elseif total > 0 and not preloadDone then
			stage = "Loading assets"
		elseif not character then
			stage = "Getting your car ready..."
		elseif flagRequired and flag ~= true then
			stage = "Almost there..."
		else
			stage = "Ready!"
		end
		lastStage = stage
		sink.stage(stage)
		-- numbers only where they are real: the asset count of a known manifest
		if total > 0 then
			sink.count(string.format("%d / %d", resolved, total))
			local gates = (if loaded then 1 else 0)
				+ (if character then 1 else 0)
				+ (if flagRequired and flag == true then 1 else 0)
			sink.progress(math.clamp((resolved + gates) / (total + gateCount), 0, 1))
		else
			sink.count(nil)
			sink.progress(nil) -- an empty manifest has no known denominator: an indeterminate bar, not a percentage
		end
		if failed > 0 then
			sink.note(if failed == 1 then "1 item couldn't load" else string.format("%d items couldn't load", failed))
		else
			sink.note(nil)
		end
	end

	local function finish(why: string)
		if done or cancelled then
			return
		end
		reason = why
		done = true
		local s = summary()
		sink.finish(why, s)
	end

	-- the preload runs in its own task; a late callback after dismissal is ignored
	if total > 0 then
		env.spawn(function()
			env.preload(manifest, function(id: string, status: string)
				if not active() then
					return
				end
				if not inManifest[id] or seen[id] then
					return
				end
				seen[id] = true
				resolved += 1
				if status == "Success" then
					succeeded += 1
				else
					failed += 1
				end
			end)
			if not active() then
				return
			end
			-- PreloadAsync returned: every asset is settled, whatever the callbacks reported
			resolved = total
			failed = total - succeeded
			preloadDone = true
		end)
	end

	env.spawn(function()
		while active() do
			readLoaded()
			describe()
			local elapsed = env.now() - t0
			local ready = essentialReady()
			if ready and (preloadDone or elapsed >= optionalSeconds) then
				finish(if preloadDone then "Ready" else "ReadyBackground")
				return
			end
			if not ready and elapsed >= optionalSeconds then
				-- essential readiness failed to arrive: an honest status and a working way out, never a fake 100 percent
				statusShown = true
				sink.status(string.format("Still connecting... %d s", math.floor(elapsed)))
				if env.rejoin then
					sink.action("Rejoin", env.rejoin)
				end
			end
			env.wait(poll)
		end
	end)

	return {
		cancel = function()
			if not done then
				cancelled = true
				reason = "Cancelled"
			end
		end,
		summary = summary,
		isDone = function(): boolean
			return done or cancelled
		end,
	}
end

return LoadingController
