--!strict
-- Shared presentation alarm clock (Lane 3). Presentation only; it decides
-- nothing about gameplay.
--
-- One RenderStepped connection drives every alarm visual: the Heat panel,
-- its siren lights and, later, the car's Critical and Meltdown emphasis
-- (Pip). Effects read the shared phase instead of running their own loops,
-- so the panel and the car stay in step. The connection exists only while
-- at least one subscriber is registered.
--
-- One cycle = one panel peak. wave(0) peaks once per cycle; the right siren
-- uses wave(0.5), half a cycle later. The screen therefore shows two visible
-- peaks per cycle, so the rate is capped at Tokens.Motion.AlarmMaxHz (1.25),
-- keeping all peaks combined at or under 2.5 per second (Adam, 2026-10-19).
-- A later effect that peaks at any other phase adds peaks and must be
-- counted. The rate is set by the Heat presentation; other effects only read
-- the phase.
--
-- Provisional interface for later effects (for example Pip's emphasis):
--   local stop = AlarmClock.subscribe(function(dt, phase) ... end)
--   AlarmClock.wave(offset?) -> 0 (dim) .. 1 (brightest), smooth cosine
--   stop() when the effect is destroyed

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Tokens = require(ReplicatedStorage.Shared.UI.Tokens)

type Listener = (dt: number, phase: number) -> ()

local AlarmClock = {}

local listeners: { [number]: Listener } = {}
local listenerCount = 0
local nextId = 0
local connection: RBXScriptConnection? = nil
local phase = 0
local rate = 0
local cycles = 0

local function step(dt: number)
	if rate > 0 then
		local advanced = phase + dt * rate
		if advanced >= 1 then
			cycles += math.floor(advanced)
		end
		phase = advanced % 1
	end
	for _, listener in listeners do
		listener(dt, phase)
	end
end

-- Registers a per-frame listener. Returns a function that removes it.
function AlarmClock.subscribe(listener: Listener): () -> ()
	nextId += 1
	local id = nextId
	listeners[id] = listener
	listenerCount += 1
	if connection == nil then
		connection = RunService.RenderStepped:Connect(step)
	end
	return function()
		if listeners[id] == nil then
			return
		end
		listeners[id] = nil
		listenerCount -= 1
		if listenerCount == 0 and connection then
			connection:Disconnect()
			connection = nil
			phase = 0
			rate = 0
		end
	end
end

-- Alarm cycles per second. 0 stops the alarm and returns the phase to its
-- dim resting point. Values above the cap are clamped.
function AlarmClock.setRate(hz: number)
	rate = math.clamp(hz, 0, Tokens.Motion.AlarmMaxHz)
	if rate == 0 then
		phase = 0
	end
end

function AlarmClock.getRate(): number
	return rate
end

function AlarmClock.getPhase(): number
	return phase
end

-- 0 at the dim point of the cycle, 1 at the brightest. offset shifts the
-- cycle (0.5 = opposite phase).
function AlarmClock.wave(offset: number?): number
	return 0.5 - 0.5 * math.cos(((phase + (offset or 0)) % 1) * 2 * math.pi)
end

function AlarmClock.stats(): { listeners: number, connected: boolean, rate: number, cycles: number }
	return {
		listeners = listenerCount,
		connected = connection ~= nil,
		rate = rate,
		cycles = cycles,
	}
end

return AlarmClock
