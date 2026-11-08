--!strict
-- TrailMoments (Lane 3 Round 8, T-03, T-04, T-05; to R8-IMG-19 and R8-IMG-22): the equipped trail reacts to the run. It listens to
-- the run, drives the run car's CarLookApplier handle and plays TrailBursts (src/client/UI/Prototype/Style/TrailBursts.luau).
-- Cosmetic only: it never touches the run's rules, Heat, Stamina, saves or the server.
--
-- THE SEAM (agreed with the lead; WS-1 calls it, the code that owns the handle):
--
--   local moments = TrailMoments.attach(handle, run, options?)     moments:destroy()
--       handle   the run car's CarLookApplier handle (needs .model, .look, :setTrailSpeed(0..1), :moveTrailTo(model))
--       run      the RunController (or anything with the same signals): .Boarded(model), .Bonk(kind, at),
--                .Moment(kind, model?) with kind "leap" | "dive", :getSpeed01() -> 0..1, and optionally .Ended()
--       options  { reduceMotion: boolean? } nil follows the player's Reduce Motion setting
--   Call it once the handle exists (before or after run:start(); a Boarded that arrives before the first leap is ignored: the code
--   that made the handle decides where the trail starts). destroy() it with the handle, when the run ends.
--
-- WHAT IT DOES
--   T-03 speed:  every frame it works out one number, 0..1, from the run speed and calls handle:setTrailSpeed(number). Low speed
--                (launch card, Raceway: not this module, they call setTrailSpeed(TrailMoments.SPEED_IDLE)) is a short gentle
--                trail; in a run the number climbs from CURVES[tier].lo at the start to .hi at top speed (the run ramps from
--                START_SPEED to TOP_SPEED in RAMP_TIME seconds); a flare (top speed, or right after a dive) lifts it to 1 for
--                FLARE_SECONDS and plays TrailBursts "flare". One curve per rarity tier, values below.
--   T-04 moments: leap = ring burst from the car you leave, the thin stream starts from the avatar; dive = a bright streak; catch
--                = flash over the new car, the trail moves to it (handle:moveTrailTo) and the stream ends.
--   T-05 chain:  every hop in a row (leap, then caught) that does not touch the road adds one step, up to 3: the speed number
--                gets CHAIN_LIFT[step] and TrailBursts.chain adds bigger, brighter, denser layers on the car (values in
--                TrailBursts.CHAIN). A bump, a bonk or a throw resets it to 0. A catch after a drop or a revive does not add a step.
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
	moveTrailTo: (self: any, model: Model) -> (),
}

export type Source = {
	Boarded: any, -- Signal(model: Model)
	Bonk: any, -- Signal(kind: string, at: CFrame)
	Moment: any?, -- Signal(kind: "leap" | "dive", model: Model?)
	Ended: any?, -- Signal(results)
	getSpeed01: ((self: any) -> number)?,
}

export type Options = { reduceMotion: boolean? }

export type State = {
	mode: string, -- "ride" | "float" | "dive" | "recover"
	chain: number,
	speed: number, -- the last number sent to setTrailSpeed
	flare: number, -- 1 right after a flare, falling to 0
	model: Model?, -- the car the trail is on
}

export type Moments = {
	destroy: (self: Moments) -> (),
	getState: (self: Moments) -> State,
	flare: (self: Moments) -> (),
}

-- T-03 (recorded values) -------------------------------------------------------------------------------------------------------------
-- The number handed to setTrailSpeed(0..1) while riding: lo + (hi - lo) * u, u = run speed from START (0) to TOP (1); one pair per
-- rarity tier of the trail (the catalog's trail tier -> rarity). A cheaper tier stays a little shorter so the busiest scene stays
-- inside the particle budget; the flare closes the gap (it always lifts the number to 1).
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
TrailMoments.FLARE_SECONDS = 0.8 -- how long a flare's lift takes to fall back
TrailMoments.AFTER_DIVE_FLARE_DELAY = 0.12 -- seconds after the catch before the tail flare burst
-- T-05 (recorded values): added to the speed number at chain step 0 to 3
TrailMoments.CHAIN_LIFT = table.freeze({ 0, 0.05, 0.10, 0.15 })
local MAX_STEP = 3
local SMOOTH = 8 -- per second: how fast the sent number follows its target

-- The speed number for a rarity, run speed u (0..1), chain step and flare (0..1). Pure; the previews can use it too.
function TrailMoments.valueFor(rarity: string, u: number, step: number, flare: number): number
	local curve = (TrailMoments.CURVES :: any)[rarity] or DEFAULT_CURVE
	local s = curve.lo + (curve.hi - curve.lo) * math.clamp(u, 0, 1)
	s += TrailMoments.CHAIN_LIFT[math.clamp(math.floor(step), 0, MAX_STEP) + 1]
	s = s + (1 - s) * math.clamp(flare, 0, 1)
	return math.clamp(s, 0, 1)
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
local burstsCache: any? = nil
local burstsTried = false
local function loadBursts(): any?
	if burstsTried then
		return burstsCache
	end
	burstsTried = true
	local client = script.Parent.Parent
	local ui = client:FindFirstChild("UI")
	local proto = ui and ui:FindFirstChild("Prototype")
	local style = proto and proto:FindFirstChild("Style")
	local module = style and style:FindFirstChild("TrailBursts")
	if module and module:IsA("ModuleScript") then
		local ok, loaded = pcall(require, module)
		if ok then
			burstsCache = loaded
		else
			warn("[TrailMoments] TrailBursts could not load: " .. tostring(loaded))
		end
	end
	return burstsCache
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

function TrailMoments.attach(handle: TrailHandle, source: Source, options: Options?): Moments
	local opts: Options = options or {}
	local trove = Trove.new()
	local bursts = loadBursts()
	local startedAt = os.clock()

	local st = {
		mode = "ride",
		chain = 0,
		speed = TrailMoments.SPEED_IDLE,
		flare = 0,
		model = handle.model :: Model?,
		started = false, -- true from the first leap: only then does a Boarded move the trail
		airborne = false, -- leapt and not landed yet
		dropped = false, -- fell to the road (or was thrown) and not landed yet
		topFlared = false,
		sent = -1,
	}
	local stream: any = nil
	local aura: any = nil
	local destroyed = false

	if source.Moment == nil then
		warn(
			"[TrailMoments] the run has no Moment signal: leaps and dives will not show (RunController needs the Round 8 hook)"
		)
	end

	local function look(): CarLook.Look
		return handle.look
	end
	local function hasTrail(): boolean
		return look().trail ~= nil
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
	local function setAura(step: number, target: Instance?)
		if not bursts or not hasTrail() then
			return
		end
		if not aura and step > 0 and target then
			safe("chain", function()
				aura = bursts.chain(target, look(), opts.reduceMotion)
			end)
		end
		if aura then
			aura:setTarget(target)
			aura:setStep(step)
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
		local trail = look().trail or ""
		if trail ~= rarityFor then
			rarityFor = trail
			rarity = rarityOf(look())
		end
		return TrailMoments.valueFor(rarity, u, st.chain, st.flare)
	end

	local function send(value: number)
		st.speed = value
		if hasTrail() and math.abs(value - st.sent) >= 0.01 then
			st.sent = value
			safe("setTrailSpeed", function()
				handle:setTrailSpeed(value)
			end)
		end
	end

	local function flare()
		st.flare = 1
		if st.mode == "ride" then
			play(st.model, "flare")
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
		setAura(st.chain, nil)
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
			return -- the start of the run: the code that made the handle put the trail where it wants it
		end
		local viaHop = st.airborne and not st.dropped
		local afterDive = st.mode == "dive"
		st.airborne = false
		st.dropped = false
		st.mode = "ride"
		st.chain = if viaHop then math.min(st.chain + 1, MAX_STEP) else 0
		dropStream()
		if hasTrail() then
			if model ~= st.model then
				safe("moveTrailTo", function()
					handle:moveTrailTo(model)
				end)
			end
			st.model = model
			play(model, "catch")
			setAura(st.chain, model)
		else
			st.model = model
		end
		st.sent = -1
		if afterDive then
			-- right after a dive: the trail flares (T-03), a beat after the flash
			st.flare = 1
			task.delay(TrailMoments.AFTER_DIVE_FLARE_DELAY, function()
				if not destroyed and st.mode == "ride" and st.model == model then
					play(model, "flare")
				end
			end)
		end
		send(goalSpeed(speed01()))
	end

	local function onBonk(kind: string)
		st.chain = 0
		if aura then
			aura:setStep(0)
		end
		if kind == "Bump" then
			return -- still riding: only the chain is lost
		end
		-- a bonk on the road or a throw: you are off the car until the run puts you on the next one
		st.dropped = true
		st.airborne = false
		st.mode = "recover"
		dropStream()
		setAura(0, nil)
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
		if aura then
			aura:destroy()
			aura = nil
		end
	end
	if source.Ended then
		trove:Connect(source.Ended, function()
			self:destroy()
		end)
	end

	function self.getState(_self: Moments): State
		return { mode = st.mode, chain = st.chain, speed = st.speed, flare = st.flare, model = st.model }
	end

	function self.flare(_self: Moments)
		flare()
	end

	-- once a frame: the speed number, smoothed, and the top-speed flare
	trove:Connect(RunService.Heartbeat, function(dt: number)
		st.flare = math.max(st.flare - dt / TrailMoments.FLARE_SECONDS, 0)
		local u = speed01()
		if not st.topFlared and u >= TrailMoments.TOP_AT then
			st.topFlared = true
			flare()
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

return TrailMoments
