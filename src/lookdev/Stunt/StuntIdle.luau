--!strict
-- IDLE ANIMATION for the Stunt Circuit scenery (Lane 3, M17-01). CLIENT-SAFE: no server, no remotes, nothing saved, nothing
-- replicated. It finds models in a built course by their IdleKind attribute and moves them:
--
--   "Swing"  the two swinging arms: yaw = sweepDegrees x sin(2 pi (t / period + phase)) about the hub
--   "Flag"   the flags along the far side of the stand: a gentle 9 degree sway about the pole
--
-- An idle animation is NOT working obstacle logic. The arms do not hit anything and nothing reads their angle: timing, hit
-- rules and effects are Brian R's. The attributes it reads are written by StuntObstacles and StuntStadium from StuntData.
--
-- Reduced motion (Roblox's Reduce Motion setting, plus the preview-only Lane3ReducedMotionOverride attribute, the same
-- mechanism the HUD uses): the arms stop at straight across the road and the flags at rest. Changing the setting while the
-- course is up takes effect at once. Everything is cleaned up by one Trove: stop() restores the rest poses.
--
--   local idle = StuntIdle.start(course)        idle.stop()    idle.stats()    StuntIdle.armYaw(sweep, period, phase, t)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Util = require(script.Parent.Parent.Downtown.City.Util)
local Trove = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Trove"))

local StuntIdle = {}

local FLAG_SWAY_DEGREES = 9
local FLAG_PERIOD = 3.2
local FLAG_STEP = 0.1 -- flags move ten times a second: small and far away, so no more is needed

type Animated = { model: Model, base: CFrame, period: number, amount: number, phase: number }

export type Stats = {
	arms: number,
	flags: number,
	reduced: boolean,
	running: boolean,
	elapsed: number,
	armYaws: { number },
}

export type Handle = {
	stop: () -> (),
	stats: () -> Stats,
}

-- The arm's yaw in degrees at time t (pure, so a test can check it without a model).
function StuntIdle.armYaw(sweepDegrees: number, periodSeconds: number, phase: number, t: number): number
	return sweepDegrees * math.sin(2 * math.pi * (t / math.max(periodSeconds, 1e-3) + phase))
end

local function numberAttr(instance: Instance, name: string, default: number): number
	local value = instance:GetAttribute(name)
	if type(value) == "number" then
		return value
	end
	return default
end

function StuntIdle.start(course: Instance): Handle
	local trove = Trove.new()
	local arms: { Animated } = {}
	local flags: { Animated } = {}
	for _, d in course:GetDescendants() do
		if d:IsA("Model") then
			local kind = d:GetAttribute("IdleKind")
			if kind == "Swing" then
				table.insert(arms, {
					model = d,
					base = d:GetPivot(),
					period = numberAttr(d, "IdlePeriod", 5),
					amount = numberAttr(d, "IdleSweepDegrees", 70),
					phase = numberAttr(d, "IdlePhase", 0),
				})
			elseif kind == "Flag" then
				table.insert(flags, {
					model = d,
					base = d:GetPivot(),
					period = FLAG_PERIOD,
					amount = FLAG_SWAY_DEGREES,
					phase = numberAttr(d, "IdlePhase", 0),
				})
			end
		end
	end

	local reduced = Util.reducedMotion()
	local elapsed = 0
	local flagClock = 0
	local running = true

	local function poseArms()
		for _, a in arms do
			local yaw = if reduced then 0 else StuntIdle.armYaw(a.amount, a.period, a.phase, elapsed)
			a.model:PivotTo(a.base * CFrame.Angles(0, math.rad(yaw), 0))
		end
	end
	local function poseFlags()
		for _, f in flags do
			local yaw = if reduced then 0 else StuntIdle.armYaw(f.amount, f.period, f.phase, elapsed)
			f.model:PivotTo(f.base * CFrame.Angles(0, math.rad(yaw), 0))
		end
	end

	trove:Connect(RunService.Heartbeat, function(dt: number)
		if reduced then
			return
		end
		elapsed += dt
		poseArms()
		flagClock += dt
		if flagClock >= FLAG_STEP then
			flagClock = 0
			poseFlags()
		end
	end)
	for _, signal in Util.reducedMotionSignals() do
		trove:Connect(signal, function()
			reduced = Util.reducedMotion()
			poseArms()
			poseFlags()
		end)
	end
	-- stop when the course goes away, and always put the rest poses back
	trove:Connect(course.Destroying, function()
		running = false
	end)
	trove:Add(function()
		running = false
		for _, list in { arms, flags } do
			for _, a in list do
				if a.model.Parent then
					a.model:PivotTo(a.base)
				end
			end
		end
	end)

	poseArms()
	poseFlags()

	return {
		stop = function()
			trove:Destroy()
		end,
		stats = function(): Stats
			local yaws: { number } = {}
			for _, a in arms do
				table.insert(yaws, if reduced then 0 else StuntIdle.armYaw(a.amount, a.period, a.phase, elapsed))
			end
			return {
				arms = #arms,
				flags = #flags,
				reduced = reduced,
				running = running,
				elapsed = elapsed,
				armYaws = yaws,
			}
		end,
	}
end

return StuntIdle
