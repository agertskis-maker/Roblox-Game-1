--!strict
-- Run tuning for the Lane 1 driving prototype (Stage 1). Every value here is a Tunable starting
-- point for the first playtest, taken from car-hop-outline-v2 section 06 where the outline gives
-- one. Shared so the server can re-derive the same traffic from a run seed later.

export type Rarity = "Common" | "Rare" | "Epic" | "Legendary"

local RunConfig = {}

-- Where runs happen: a private zone far above the island. The road runs toward -Z from here.
RunConfig.ORIGIN = CFrame.new(0, 400, 0)

-- Road shape (Adam's Downtown preview width, decision pending: 4 lanes x 17 studs + 4-stud shoulders).
RunConfig.LANES = 4
RunConfig.LANE_WIDTH = 17
RunConfig.SHOULDER = 4
RunConfig.ROAD_HALF_WIDTH = RunConfig.LANES * RunConfig.LANE_WIDTH / 2 + RunConfig.SHOULDER

-- Run speed in studs per second: ramps from START to TOP over RAMP_TIME seconds, then holds.
RunConfig.START_SPEED = 55
RunConfig.TOP_SPEED = 105
RunConfig.RAMP_TIME = 60

-- Unridden traffic drives at a fraction of the run speed, one fraction per lane (lane 1 is the
-- left lane). One speed per lane means traffic never drives through its own lane-mates.
RunConfig.LANE_SPEED = table.freeze({ 0.56, 0.64, 0.72, 0.8 })

-- Traffic spawning, in studs along the road.
RunConfig.FIRST_CAR = 80
RunConfig.SPAWN_AHEAD = 700
RunConfig.DESPAWN_BEHIND = 160
RunConfig.GAP_START = 75
RunConfig.GAP_END = 32
RunConfig.GAP_RAMP_DISTANCE = 4000

-- The Hop.
RunConfig.HOP_TIME = 0.6
RunConfig.HOP_HEIGHT = 9
RunConfig.HOP_NUDGE = 4.5
RunConfig.HOP_NUDGE_SPEED = 6
RunConfig.LAND_TOLERANCE = 1.2
RunConfig.HOP_BEHIND_ALLOWANCE = 4

-- Foot Dash.
RunConfig.FOOT_DASH_TIME = 2.5
RunConfig.FOOT_SPEED = 0.42
RunConfig.FOOT_STEER = 18
RunConfig.FOOT_SIZE = 2

-- Heat (fractions of 1). Stages follow decision 0008.
RunConfig.HEAT_WARNING = 0.6
RunConfig.HEAT_CRITICAL = 0.85
RunConfig.MELTDOWN_TIME = 3
RunConfig.MELTDOWN_MIN_SPEED = 0.5
RunConfig.MELTDOWN_STEER_LAG = 2.5
RunConfig.BUMP_SIDE = 0.15
RunConfig.BUMP_REAR = 0.3
RunConfig.BUMP_COOLDOWN = 0.8
RunConfig.REAR_SLOW_TIME = 0.6
RunConfig.REAR_SLOW_FACTOR = 0.55

-- Keys: seconds aboard to claim, by rarity.
RunConfig.KEYS_TIME = table.freeze({
	Common = 3,
	Rare = 4,
	Epic = 5,
	Legendary = 6,
} :: { [Rarity]: number })
-- Every family's Heat Capacity must leave this much Heat to spare after its slowest claim.
RunConfig.HEAT_TO_SPARE = 3
RunConfig.KEYS_CARD_TIME = 1.2

-- Chase camera (outline section 06).
RunConfig.CAMERA_BACK = 12
RunConfig.CAMERA_UP = 6
RunConfig.CAMERA_LOOK_AHEAD = 30
RunConfig.CAMERA_FOV = 70
RunConfig.CAMERA_FOLLOW = 9

-- Display.
RunConfig.METRES_PER_STUD = 0.28
RunConfig.MILESTONE_METRES = 500

-- How often the client batches run events for the server (run-report proposal).
RunConfig.EVENT_BATCH_INTERVAL = 1

function RunConfig.laneCenter(lane: number): number
	return -RunConfig.LANES * RunConfig.LANE_WIDTH / 2 + RunConfig.LANE_WIDTH * (lane - 0.5)
end

-- Run speed (studs per second) at run time t.
function RunConfig.speedAt(t: number): number
	local a = math.clamp(t / RunConfig.RAMP_TIME, 0, 1)
	return RunConfig.START_SPEED + (RunConfig.TOP_SPEED - RunConfig.START_SPEED) * a
end

-- Studs the run speed has covered by run time t (the integral of speedAt). Traffic positions
-- are lane speed times this, so the client and the server get the same answer for any t.
function RunConfig.travelledAt(t: number): number
	local r = RunConfig.RAMP_TIME
	local s0, s1 = RunConfig.START_SPEED, RunConfig.TOP_SPEED
	if t <= r then
		return s0 * t + (s1 - s0) * t * t / (2 * r)
	end
	return s0 * r + (s1 - s0) * r / 2 + s1 * (t - r)
end

function RunConfig.toMetres(studs: number): number
	return studs * RunConfig.METRES_PER_STUD
end

return table.freeze(RunConfig)
