--!strict
-- TrailMoments (Lane 3 Round 8, T-03, T-04, T-05; to R8-IMG-19 and R8-IMG-22): the equipped trail reacts to the run. It listens to
-- the run, drives the run car's trail (CarLookApplier handle, TrailFx inside it) and plays TrailBursts
-- (src/client/UI/Prototype/Style/TrailBursts.luau). Cosmetic only: it never touches the run's rules, Heat, Stamina, saves or the
-- server.
--
-- THE SEAM
--   RunController.new() attaches it by itself (one line, Round 8): TrailMoments.attachToRun(run). The handle is whatever
--   CarLookApplier.runHandle() holds at that moment (BetaRun.client sets it with CarLookApplier.setRunHandle when the run's trail
--   exists), so nothing else has to call anything. Outside the beta (Brian R's playground has no Lane 3 UI) it does nothing.
--   The explicit form stays for tests and other owners:
--       local moments = TrailMoments.attach(handle, run, options?)       moments:destroy()
--           handle   a CarLookApplier handle, or a function returning one (or nil): needs .look and :setTrailSpeed(0..1);
--                    :moveTrailTo(model) only when options.moveTrail is true
--           run      the RunController (or anything with the same signals): .Boarded(model), .Bonk(kind, at),
--                    .Moment(kind, model?) with kind "leap" | "dive", :getSpeed01() -> 0..1, and optionally .Ended() and
--                    :getDebugState() (read 4 times a second only while airborne, to notice END RUN in the air)
--           options  { reduceMotion: boolean?, moveTrail: boolean? }  reduceMotion nil follows the player's setting; moveTrail
--                    false (the default) because BetaRun.client already moves the trail to each car you board (C-02): a second
--                    moveTrailTo with another model would put it on the wrong one
--   Do not call attach for a run that RunController already attached.
--
-- WHAT IT DOES
--   T-03 speed:  every frame it works out one number, 0..1, from the run speed and calls handle:setTrailSpeed(number). Low speed
--                (launch card, Raceway: not this module, they call setTrailSpeed(TrailMoments.SPEED_IDLE)) is a short gentle
--                trail; in a run the number climbs from CURVES[tier].lo at the start to .hi at top speed (the run ramps from
--                START_SPEED to TOP_SPEED in RAMP_TIME seconds). The flare (top speed once, and right after a dive) is TrailFx's
--                own: fx:flare(FLARE_SECONDS), a brighter, longer, wider moment (without it: TrailBursts "flare"). One curve per
--                rarity tier, values below.
--   T-04 moments: leap = ring burst from the car you leave, the thin stream starts from the avatar; dive = a bright streak; catch
--                = flash over the new car and the stream ends (the trail itself is moved by the handle's owner, see above).
--   T-05 chain:  every hop in a row (leap, then caught) that does not touch the road adds one step, up to 3, and the trail grows
--                through TrailFx's own fx:setLevel(step) (bigger, brighter, more particles; the values are WS-5a's). A bump, a
--                bonk or a throw resets it to 0. A catch after a drop or a revive does not add a step. The step is applied again
--                whenever the trail is rebuilt on another car.
--   The TrailFx handle is reached through handle:setTrailLevel(step) / handle:flareTrail(seconds) when the handle has them,
--   else through handle:getTrailFx(), else the handle's _trail field (WS-1's CarLookApplier keeps it there).
--
-- Plays the bursts through TrailBursts.play directly (a burst needs to land on the car you left, the avatar or the new car, not on
-- whatever the handle holds); the handle's own :burst stays for previews (the Style Shop).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local CarLook = require(ReplicatedStorage.Shared.Style.CarLook)
local Catalog = require(ReplicatedStorage.Shared.UI.CosmeticPreviewCatalog)
local RunConfig = require(ReplicatedStorage.Shared.Run.RunConfig)
local Trove = require(ReplicatedStorage.Packages.Trove)

local TrailMoments = {}

export type TrailHandle = {
	model: Model,
	look: CarLook.Look,
	setTrailSpeed: (self: any, speed: number) -> (),
	moveTrailTo: ((self: any, model: Model) -> ())?,
	setTrailLevel: ((self: any, step: number) -> ())?,
	flareTrail: ((self: any, seconds: number?) -> ())?,
}

export type HandleGetter = () -> TrailHandle?

export type Source = {
	Boarded: any, -- Signal(model: Model)
	Bonk: any, -- Signal(kind: string, at: CFrame)
	Moment: any?, -- Signal(kind: "leap" | "dive", model: Model?)
	Ended: any?, -- Signal(results)
	getSpeed01: ((self: any) -> number)?,
	getDebugState: ((self: any) -> any)?, -- only read (4 times a second) while airborne, to notice END RUN in the air
}

export type Options = { reduceMotion: boolean?, moveTrail: boolean? }

export type State = {
	mode: string, -- "ride" | "float" | "dive" | "recover"
	chain: number,
	speed: number, -- the last number sent to setTrailSpeed
	flare: number, -- 1 right after a flare, falling to 0 (state only: the look of a flare is TrailFx's)
	model: Model?, -- the car the trail is on
	level: number, -- the last chain step handed to the trail
}

export type Moments = {
	destroy: (self: Moments) -> (),
	getState: (self: Moments) -> State,
	flare: (self: Moments) -> (),
}

-- T-03 (recorded values) -------------------------------------------------------------------------------------------------------------
-- The number handed to setTrailSpeed(0..1) while riding: lo + (hi - lo) * u, u = run speed from START (0) to TOP (1); one pair per
-- rarity tier of the trail (the catalog's trail tier -> rarity). A cheaper tier stays a little shorter so the busiest scene stays
-- inside the particle budget. The flare and the chain steps are TrailFx's own, on top (they are not added to this number).
TrailMoments.CURVES = table.freeze({
	Common = table.freeze({ lo = 0.55, hi = 0.80 }),
	Uncommon = table.freeze({ lo = 0.58, hi = 0.84 }),
	Rare = table.freeze({ lo = 0.60, hi = 0.88 }),
	Epic = table.freeze({ lo = 0.62, hi = 0.92 }),
	Legendary = table.freeze({ lo = 0.65, hi = 0.95 }),
})
local DEFAULT_CURVE = TrailMoments.CURVES.Common
TrailMoments.SPEED_IDLE = 0.2 -- standing still: the launch card, the Raceway, the Style Shop turntable (short and gentle)
TrailMoments.SPEED_FLOAT = 0 -- the trail left on the car you leapt from while you float
TrailMoments.TOP_AT = 0.98 -- u at which the top-speed flare plays (once per run)
TrailMoments.FLARE_SECONDS = 0.8 -- fx:flare(seconds)
TrailMoments.AFTER_DIVE_FLARE_DELAY = 0.12 -- seconds after the catch before the flare (the handle's owner has moved the trail by then)
TrailMoments.MAX_STEP = 3 -- T-05: the longest hop chain that grows the trail
local SMOOTH = 8 -- per second: how fast the sent number follows its target

-- The speed number for a rarity and run speed u (0..1). Pure; the previews can use it too.
function TrailMoments.valueFor(rarity: string, u: number): number
	local curve = (TrailMoments.CURVES :: any)[rarity] or DEFAULT_CURVE
	return math.clamp(curve.lo + (curve.hi - curve.lo) * math.clamp(u, 0, 1), 0, 1)
end

local function rarityOf(look: CarLook.Look): string
	if not look.trail then
		return "Common"
	end
	local item = Catalog.byId("Trails", look.trail)
	local tier = item and Catalog.tierOf("Trails", item.tier)
	return if tier then tier.rarity else "Common"
end

-- The visual side lives in the Lane 3 UI tree; Brian R's playground has none, so it is found by name and optional.
local function loadStyle(name: string): any?
	local client = script.Parent.Parent
	local ui = client:FindFirstChild("UI")
	local proto = ui and ui:FindFirstChild("Prototype")
	local style = proto and proto:FindFirstChild("Style")
	local module = style and style:FindFirstChild(name)
	if module and module:IsA("ModuleScript") then
		local ok, loaded = pcall(require, module)
		if ok then
			return loaded
		end
		warn("[TrailMoments] " .. name .. " could not load: " .. tostring(loaded))
	end
	return nil
end
local burstsCache: any? = nil
local burstsTried = false
local function loadBursts(): any?
	if not burstsTried then
		burstsTried = true
		burstsCache = loadStyle("TrailBursts")
	end
	return burstsCache
end
local applierCache: any? = nil
local applierTried = false
local function loadApplier(): any?
	if not applierTried then
		applierTried = true
		applierCache = loadStyle("CarLookApplier")
	end
	return applierCache
end

local function playerRoot(): BasePart?
	local player = Players.LocalPlayer
	local character = player and player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root
	end
	return nil
end

-- The TrailFx handle inside a run handle (nil when there is none): through the handle's own accessor when it has one.
local function trailFxOf(h: any): any?
	if type(h.getTrailFx) == "function" then
		return h:getTrailFx()
	end
	return h._trail
end

function TrailMoments.attach(handleOrGetter: TrailHandle | HandleGetter, source: Source, options: Options?): Moments
	local opts: Options = options or {}
	local trove = Trove.new()
	local bursts = loadBursts()
	local startedAt = os.clock()

	local function handleNow(): any?
		if type(handleOrGetter) == "function" then
			return (handleOrGetter :: HandleGetter)()
		end
		return handleOrGetter
	end

	local first: any = handleNow()
	local st = {
		mode = "ride",
		chain = 0,
		speed = TrailMoments.SPEED_IDLE,
		flare = 0,
		model = if first then first.model :: Model? else nil,
		level = 0,
		started = false, -- true from the first leap: only then does a Boarded count
		airborne = false, -- leapt and not landed yet
		dropped = false, -- fell to the road (or was thrown) and not landed yet
		topFlared = false,
		sent = -1,
	}
	local stream: any = nil
	local levelFx: any = nil -- the TrailFx handle the chain step was last given to
	local destroyed = false

	if source.Moment == nil then
		warn(
			"[TrailMoments] the run has no Moment signal: leaps and dives will not show (RunController needs the Round 8 hook)"
		)
	end

	local function look(): CarLook.Look?
		local h = handleNow()
		return if h then h.look else nil
	end
	local function hasTrail(): boolean
		local l = look()
		return l ~= nil and l.trail ~= nil
	end
	local function safe(what: string, fn: () -> ())
		local ok, err = pcall(fn)
		if not ok then
			warn("[TrailMoments] " .. what .. " failed: " .. tostring(err))
		end
	end
	local function play(target: Instance?, moment: string)
		if bursts and target and hasTrail() then
			safe(moment, function()
				bursts.play(target, look(), moment, opts.reduceMotion)
			end)
		end
	end
	local function dropStream()
		if stream then
			stream:stop()
			stream = nil
		end
	end

	-- T-05: hand the chain step to the trail (and again whenever the trail is a new TrailFx, after a move or a rebuild).
	local function applyLevel()
		local h = handleNow()
		if not h or not hasTrail() then
			return
		end
		local fx = trailFxOf(h)
		st.level = st.chain
		levelFx = fx
		safe("setLevel", function()
			if type(h.setTrailLevel) == "function" then
				h:setTrailLevel(st.chain)
			elseif fx and fx.setLevel then
				fx:setLevel(st.chain)
			end
		end)
	end

	-- T-03: the trail's own flare; without one, the burst jet from the back of the car.
	local function doFlare()
		st.flare = 1
		local h = handleNow()
		if not h or not hasTrail() or destroyed then
			return
		end
		local fx = trailFxOf(h)
		if type(h.flareTrail) == "function" then
			safe("flare", function()
				h:flareTrail(TrailMoments.FLARE_SECONDS)
			end)
		elseif fx and fx.flare then
			safe("flare", function()
				fx:flare(TrailMoments.FLARE_SECONDS)
			end)
		elseif st.mode == "ride" then
			play(st.model, "flare")
		end
	end

	local function speed01(): number
		local fn = source.getSpeed01
		if fn then
			return fn(source)
		end
		-- a run without getSpeed01: the run speed is a function of run time, close enough to the wall clock
		return math.clamp(
			(RunConfig.speedAt(os.clock() - startedAt) - RunConfig.START_SPEED)
				/ (RunConfig.TOP_SPEED - RunConfig.START_SPEED),
			0,
			1
		)
	end

	local rarityFor = ""
	local rarity = "Common"
	local function goalSpeed(u: number): number
		if st.mode == "float" or st.mode == "dive" or st.mode == "recover" then
			return TrailMoments.SPEED_FLOAT
		end
		local l = look()
		local trail = if l then l.trail or "" else ""
		if l and trail ~= rarityFor then
			rarityFor = trail
			rarity = rarityOf(l)
		end
		return TrailMoments.valueFor(rarity, u)
	end

	local function send(value: number)
		st.speed = value
		local h = handleNow()
		if h and hasTrail() and math.abs(value - st.sent) >= 0.01 then
			st.sent = value
			safe("setTrailSpeed", function()
				h:setTrailSpeed(value)
			end)
		end
	end

	-- T-04 -----------------------------------------------------------------------------------------------------------------------
	local function onLeap(model: Model?)
		if st.mode ~= "ride" then
			return
		end
		st.started = true
		st.mode = "float"
		st.airborne = true
		st.dropped = false
		play(model or st.model, "leap")
		send(TrailMoments.SPEED_FLOAT)
		dropStream()
		local root = playerRoot()
		local b = bursts
		if b and root and hasTrail() then
			safe("stream", function()
				stream = b.stream(root, look(), opts.reduceMotion)
				if stream then
					stream:setStep(st.chain)
					-- the run's own pink float streak (RunFx.setTrail, turned on a moment ago) gives way to the player's trail
					local generic = root:FindFirstChildOfClass("Trail")
					if generic then
						generic.Enabled = false
					end
				end
			end)
		end
	end

	local function onDive()
		if st.mode ~= "float" then
			return
		end
		st.mode = "dive"
		dropStream()
		local root = playerRoot()
		if root then
			play(root, "dive")
		end
	end

	local function onBoarded(model: Model)
		if not st.started and not st.dropped then
			st.model = model -- the start of the run: whoever made the handle put the trail where it wants it
			return
		end
		local viaHop = st.airborne and not st.dropped
		local afterDive = st.mode == "dive"
		st.airborne = false
		st.dropped = false
		st.mode = "ride"
		st.chain = if viaHop then math.min(st.chain + 1, TrailMoments.MAX_STEP) else 0
		dropStream()
		local h = handleNow()
		if h and hasTrail() then
			if opts.moveTrail and model ~= st.model and type(h.moveTrailTo) == "function" then
				safe("moveTrailTo", function()
					h:moveTrailTo(model)
				end)
			end
			st.model = model
			play(model, "catch")
			applyLevel()
		else
			st.model = model
		end
		st.sent = -1
		if afterDive then
			-- right after a dive: the trail flares (T-03), a beat after the flash
			st.flare = 1
			task.delay(TrailMoments.AFTER_DIVE_FLARE_DELAY, function()
				if not destroyed and st.mode == "ride" and st.model == model then
					doFlare()
				end
			end)
		end
		send(goalSpeed(speed01()))
	end

	local function onBonk(kind: string)
		st.chain = 0
		applyLevel()
		if kind == "Bump" then
			return -- still riding: only the chain is lost
		end
		-- a bonk on the road or a throw: you are off the car until the run puts you on the next one
		st.dropped = true
		st.airborne = false
		st.mode = "recover"
		dropStream()
		send(TrailMoments.SPEED_FLOAT)
	end

	if source.Moment then
		trove:Connect(source.Moment, function(kind: string, model: Model?)
			if kind == "leap" then
				onLeap(model)
			elseif kind == "dive" then
				onDive()
			end
		end)
	end
	trove:Connect(source.Boarded, onBoarded)
	trove:Connect(source.Bonk, onBonk)

	local self: any = {}

	function self.destroy(_self: Moments)
		if destroyed then
			return
		end
		destroyed = true
		trove:Destroy()
		dropStream()
	end
	if source.Ended then
		trove:Connect(source.Ended, function()
			self:destroy()
		end)
	end

	function self.getState(_self: Moments): State
		return {
			mode = st.mode,
			chain = st.chain,
			speed = st.speed,
			flare = st.flare,
			model = st.model,
			level = st.level,
		}
	end

	function self.flare(_self: Moments)
		doFlare()
	end

	-- once a frame: the speed number, smoothed, the top-speed flare, and the chain step on a rebuilt trail
	local airClock = 0
	trove:Connect(RunService.Heartbeat, function(dt: number)
		st.flare = math.max(st.flare - dt / TrailMoments.FLARE_SECONDS, 0)
		local h = handleNow()
		if not h or not hasTrail() then
			return
		end
		if st.mode == "float" or st.mode == "dive" then
			-- END RUN pressed in the air ends the run with no Boarded or Bonk: notice it, so the stream does not hang there
			airClock += dt
			local debugState = source.getDebugState
			if airClock >= 0.25 and debugState then
				airClock = 0
				if debugState(source).mode == "Ended" then
					onBonk("Ended")
				end
			end
		end
		local u = speed01()
		if not st.topFlared and u >= TrailMoments.TOP_AT then
			st.topFlared = true
			doFlare()
		end
		-- the trail is a new TrailFx (it moved to another car, or the look was rebuilt): it starts at step 0
		local fx = trailFxOf(h)
		if fx ~= levelFx or st.level ~= st.chain then
			applyLevel()
		end
		local goal = goalSpeed(u)
		local value = st.speed
		-- a car you just landed on, a leap and a drop jump straight to the new number; the rest eases
		if st.sent < 0 or goal == TrailMoments.SPEED_FLOAT then
			value = goal
		else
			value += (goal - value) * (1 - math.exp(-dt * SMOOTH))
		end
		send(value)
	end)

	return self :: Moments
end

-- The run's own attachment (RunController.new): the handle is looked up each time, as CarLookApplier.runHandle() (set by BetaRun
-- while the run's trail exists). Nothing happens when the Lane 3 UI is not there.
function TrailMoments.attachToRun(source: Source, options: Options?): Moments
	local function runHandle(): TrailHandle?
		local applier = loadApplier()
		if applier and type(applier.runHandle) == "function" then
			return applier.runHandle()
		end
		return nil
	end
	return TrailMoments.attach(runHandle, source, options)
end

return TrailMoments
