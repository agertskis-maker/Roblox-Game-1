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
RunConfig.GAP_START = 50
RunConfig.GAP_END = 24
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

-- Sizes (a stampede-style herd mixes small and huge animals; here, cars). Rolled from the seed.
export type Size = "Tiny" | "Normal" | "Big" | "Giant"
RunConfig.SIZE_ORDER = table.freeze({ "Giant", "Big", "Tiny", "Normal" } :: { Size })
RunConfig.SIZE_CHANCE = table.freeze({ Giant = 0.03, Big = 0.12, Tiny = 0.12, Normal = 1 } :: { [Size]: number })
RunConfig.SIZE_SCALE = table.freeze({ Tiny = 0.72, Normal = 1, Big = 1.3, Giant = 1.6 } :: { [Size]: number })
RunConfig.SIZE_LABEL =
	table.freeze({ Tiny = "TINY ", Normal = "", Big = "BIG ", Giant = "GIANT " } :: { [Size]: string })

-- Rider Level gate (PROPOSED, session-only in the prototype): every car shows "Needs N". Below
-- that level you can still ride it, but the Keys meter will not fill and it overheats faster.
-- Each new model claimed raises the level, like filling a collection book. Real progression
-- (where the level comes from and what raises it) belongs to Lane 2 and needs team agreement.
RunConfig.START_RIDER_LEVEL = 10
RunConfig.LEVEL_PER_NEW_MODEL = 6
RunConfig.NEEDS_BASE = table.freeze({ Common = 4, Rare = 18, Epic = 40, Legendary = 80 } :: { [Rarity]: number })
RunConfig.NEEDS_SIZE = table.freeze({ Tiny = 0.5, Normal = 1, Big = 1.6, Giant = 2.6 } :: { [Size]: number })
RunConfig.TOO_STRONG_HEAT = 1.6

-- Revives: free retries of the same run, landing back on traffic with fresh Heat.
RunConfig.FREE_REVIVES = 3

-- Variants (outline section 07, Decided): only for models the player already owns.
export type Variant = "None" | "Gold" | "Chrome" | "Rainbow"
RunConfig.VARIANT_CHANCE = table.freeze({ Rainbow = 0.004, Chrome = 0.02, Gold = 0.05 } :: { [string]: number })

-- Herd motion: every car weaves gently inside its lane on a seeded rhythm.
RunConfig.SWAY_AMPLITUDE = 1.6
RunConfig.SWAY_RATE = 0.9

-- Rare-spawn alert: a banner when one of these appears ahead.
RunConfig.ALERT_RARITY = "Legendary"

-- Chase camera (outline section 06), pulled a little higher and wider so the rider on the roof
-- and the herd around them read like a stampede.
RunConfig.CAMERA_BACK = 15
RunConfig.CAMERA_UP = 8.5
RunConfig.CAMERA_LOOK_AHEAD = 34
RunConfig.CAMERA_FOV = 70
RunConfig.CAMERA_FOV_FAST = 80
RunConfig.CAMERA_HOP_PUNCH = 6
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

-- Rider Level a car of this rarity and size needs before its Keys meter will fill.
function RunConfig.needsFor(rarity: Rarity, size: Size): number
	return math.ceil(RunConfig.NEEDS_BASE[rarity] * RunConfig.NEEDS_SIZE[size])
end

-- Sideways weave of a traffic car at run time t (seeded phase, so the server gets the same).
function RunConfig.swayAt(phase: number, t: number): number
	return math.sin(t * RunConfig.SWAY_RATE + phase) * RunConfig.SWAY_AMPLITUDE
end

return table.freeze(RunConfig)
