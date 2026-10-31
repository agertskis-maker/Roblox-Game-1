--!strict
-- Island walking boost, pure logic (Lane 3). No instances, no services, no clock of its own:
-- every function here is a plain function of its arguments, so it is unit-tested without a
-- character (Home/Island/WalkBoostTests) and shared by the live client boost
-- (Home/Island/WalkBoost) and the server preview walkers (Hub/Preview/WalkTests). This is the
-- one source of truth for the boost numbers. Spec: vault/design/specs/walk-boost.md.
--
-- Speeds (Adam, Raceway round 2, 2026-10-29): every player on the home island walks at
-- IslandBase (exactly 32; Roblox's default is 16). Over an avenue boost strip the speed is the
-- island base x Multiplier: 32 x 1.5 = 48, TopSpeed. The boost multiplies the island base; it is not
-- a maximum and not a cap on the base (speed() is the one formula).
--
-- Behaviour: while the walker is over an avenue boost strip the multiplier is Multiplier (1.5,
-- WalkSpeed 32 to 48). After stepping off it stays at Multiplier for Linger seconds, then eases
-- back to exactly 1 over Ease seconds (smoothstep). Stepping back on at any point returns it to
-- Multiplier straight away. The multiplier is a level, never a product: re-entering, standing
-- on two overlapping strips or sampling many times a frame can never take it above Multiplier.
--
-- State guard (review M1): being over a strip only counts while the humanoid is walking. gait()
-- sorts a HumanoidStateType (plus the Sit and PlatformStand flags) into four gaits:
--   walk  Running, RunningNoPhysics, Landed: counts.
--   air   Jumping, Freefall: counts for AirGrace seconds after leaving the ground, so a hop on a
--         strip keeps the boost; a longer fall stops counting and the normal linger and ease run.
--   off   Climbing, PlatformStanding, Physics, Ragdoll, FallingDown, GettingUp and every other
--         state: does not count; the normal linger and ease run.
--   drop  Seated (or Sit, or a SeatPart), Swimming, Dead: the boost is reset to exactly 1 at once.
-- stepGated() applies the gait and then runs step(). The preview walkers call step() directly.
--
-- Feedback (Adam's Design 6): no speed effect at normal walking. Only while the walker is moving
-- along a boost lane, a low dust puff behind the feet, at most 4 a second (PuffInterval), never under
-- Reduced Motion or at low graphics detail. puffWanted() and puffDue() are the pure rules; the
-- client (Home/Island/WalkBoost) emits the particles.
--
-- Plan frame: x east, y north. Roblox world X = x, world Z = -y.

local WalkBoostLogic = {}

WalkBoostLogic.IslandBase = 32 -- WalkSpeed of every player on the home island (Adam, 2026-10-29)
WalkBoostLogic.Multiplier = 1.5 -- approved by Adam (Task 4 brief, 2026-10-22)
WalkBoostLogic.Linger = 0.5 -- seconds at full boost after stepping off (Tunable)
WalkBoostLogic.Ease = 0.5 -- seconds to ease back to the base speed after the linger (Tunable)
WalkBoostLogic.HalfWidth = 2.1 -- default strip half-width; the built lanes carry their own
-- Height band of the walker's reference point (the HumanoidRootPart centre) over the strip
-- surface. A standing R15 or R6 root sits about 3 studs up; a normal jump peaks about 6.4
-- studs higher, so MaxAbove keeps the boost through a jump and the linger covers the rest.
-- Anything on a bridge or roof far above an avenue is outside the band (Tunable).
WalkBoostLogic.MinAbove = -1
WalkBoostLogic.MaxAbove = 10
-- Seconds in the air (Jumping or Freefall) that still count as walking. A default jump is about
-- 0.55 s from take-off to landing, so a hop on a strip or a short drop is covered (Tunable).
WalkBoostLogic.AirGrace = 1
-- Dust puffs on a boost lane (Adam's Design 6; Tunable within his limits): at most 4 a second, each
-- lasting 0.25 s, 0.15 to 0.35 stud across. A walker slower than PuffMinSpeed studs/s is at rest.
-- LowGraphicsMax: UserGameSettings.SavedQualityLevel 1 to this value counts as low detail (0 is
-- Automatic, which is not treated as low).
WalkBoostLogic.PuffInterval = 0.25
WalkBoostLogic.PuffLifetime = 0.25
WalkBoostLogic.PuffSizeMin = 0.15
WalkBoostLogic.PuffSizeMax = 0.35
WalkBoostLogic.PuffMinSpeed = 2
WalkBoostLogic.LowGraphicsMax = 3

-- A strip in plan coordinates; y is the strip's surface height in world studs, when known.
export type Strip = { from: Vector2, to: Vector2, y: number? }

-- The boost state of one walker: the last time it was seen over a strip, and (stepGated only)
-- when its current spell in the air began.
export type State = { lastOnStrip: number?, airSince: number? }

-- How the humanoid is moving, for the state guard (see the header).
export type Gait = "walk" | "air" | "off" | "drop"

-- World position to plan point.
function WalkBoostLogic.toPlan(position: Vector3): Vector2
	return Vector2.new(position.X, -position.Z)
end

-- Plan distance from p to the strip's centre segment.
function WalkBoostLogic.distanceToStrip(p: Vector2, strip: Strip): number
	local ab = strip.to - strip.from
	local len2 = ab:Dot(ab)
	if len2 < 1e-9 then
		return (p - strip.from).Magnitude
	end
	local t = math.clamp((p - strip.from):Dot(ab) / len2, 0, 1)
	return (p - (strip.from + ab * t)).Magnitude
end

-- True when the plan point is within halfWidth of any strip (plan only, no height test).
function WalkBoostLogic.onStripPlan(p: Vector2, strips: { Strip }, halfWidth: number?): boolean
	local hw = halfWidth or WalkBoostLogic.HalfWidth
	for _, s in strips do
		if WalkBoostLogic.distanceToStrip(p, s) <= hw then
			return true
		end
	end
	return false
end

-- True when a world position (the root part's centre) is over a strip: within the half-width in
-- plan and, for strips with a known surface height, inside the height band above it.
function WalkBoostLogic.overStrip(position: Vector3, strips: { Strip }, halfWidth: number?): boolean
	local hw = halfWidth or WalkBoostLogic.HalfWidth
	local p = WalkBoostLogic.toPlan(position)
	for _, s in strips do
		local y = s.y
		local inBand = y == nil
			or (position.Y - y >= WalkBoostLogic.MinAbove and position.Y - y <= WalkBoostLogic.MaxAbove)
		if inBand and WalkBoostLogic.distanceToStrip(p, s) <= hw then
			return true
		end
	end
	return false
end

local TIME_EPSILON = 1e-9 -- seconds; absorbs float error in clock arithmetic at the boundaries

local function smoothstep(x: number): number
	x = math.clamp(x, 0, 1)
	return x * x * (3 - 2 * x)
end

-- The multiplier at time now, given the last time the walker was over a strip (nil: never).
-- Full boost until Linger after lastOnStrip, a smooth ease to exactly 1 over Ease, then 1.
function WalkBoostLogic.multiplierAt(now: number, lastOnStrip: number?): number
	if lastOnStrip == nil then
		return 1
	end
	local m = WalkBoostLogic.Multiplier
	local since = now - lastOnStrip
	if since <= WalkBoostLogic.Linger + TIME_EPSILON then
		return m -- also covers a clock that went backwards
	end
	local u = (since - WalkBoostLogic.Linger) / WalkBoostLogic.Ease
	if u >= 1 - TIME_EPSILON then
		return 1 -- exactly, so the base speed comes back exactly
	end
	return m - (m - 1) * smoothstep(u)
end

function WalkBoostLogic.newState(): State
	return { lastOnStrip = nil, airSince = nil }
end

-- One sample: records whether the walker is over a strip now and returns the multiplier.
-- Samples may come at any rate; the result depends only on the times the walker was on a strip.
function WalkBoostLogic.step(state: State, now: number, onStrip: boolean): number
	if onStrip then
		local last = state.lastOnStrip
		-- keep the latest time (a late, older sample never shortens the boost)
		if last == nil or now > last then
			state.lastOnStrip = now
		end
	end
	return WalkBoostLogic.multiplierAt(now, state.lastOnStrip)
end

-- Forget the walker (respawn, disable, takeover, a drop gait).
function WalkBoostLogic.reset(state: State)
	state.lastOnStrip = nil
	state.airSince = nil
end

local GAITS: { [Enum.HumanoidStateType]: Gait } = {
	[Enum.HumanoidStateType.Running] = "walk",
	[Enum.HumanoidStateType.RunningNoPhysics] = "walk",
	[Enum.HumanoidStateType.Landed] = "walk",
	[Enum.HumanoidStateType.Jumping] = "air",
	[Enum.HumanoidStateType.Freefall] = "air",
	[Enum.HumanoidStateType.Seated] = "drop",
	[Enum.HumanoidStateType.Swimming] = "drop",
	[Enum.HumanoidStateType.Dead] = "drop",
}

-- The gait for a humanoid state. seated (Humanoid.Sit or a SeatPart) is a drop whatever the state
-- says; platformStand (Humanoid.PlatformStand) is off unless the state is a drop. Any state not
-- listed above is off.
function WalkBoostLogic.gait(stateType: Enum.HumanoidStateType, seated: boolean?, platformStand: boolean?): Gait
	if seated then
		return "drop"
	end
	local g = GAITS[stateType]
	if g == "drop" then
		return g
	end
	if g == nil or platformStand then
		return "off"
	end
	return g
end

-- True when being over a strip counts for this gait, airTime seconds into a spell in the air.
function WalkBoostLogic.counts(gait: Gait, airTime: number?): boolean
	if gait == "walk" then
		return true
	elseif gait == "air" then
		return (airTime or 0) <= WalkBoostLogic.AirGrace + TIME_EPSILON
	end
	return false
end

-- One guarded sample: step() with the on-strip sample gated by the gait. Returns the multiplier
-- and whether this sample counted as on a strip. A drop gait resets the state and returns
-- exactly 1. Air time runs from the first air sample of a spell in the air (Jumping then
-- Freefall is one spell) and restarts after any other gait.
function WalkBoostLogic.stepGated(state: State, now: number, overStrip: boolean, gait: Gait): (number, boolean)
	if gait == "drop" then
		WalkBoostLogic.reset(state)
		return 1, false
	end
	local airTime = 0
	if gait == "air" then
		local since = state.airSince
		if since == nil then
			state.airSince = now
		else
			airTime = now - since
		end
	else
		state.airSince = nil
	end
	local counted = overStrip and WalkBoostLogic.counts(gait, airTime)
	return WalkBoostLogic.step(state, now, counted), counted
end

-- 0 at no boost, 1 at full boost.
function WalkBoostLogic.intensity(multiplier: number): number
	local span = WalkBoostLogic.Multiplier - 1
	if span <= 0 then
		return 0
	end
	return math.clamp((multiplier - 1) / span, 0, 1)
end

-- The fastest WalkSpeed a lane boost produces: the island base x the multiplier (32 x 1.5 = 48).
function WalkBoostLogic.topSpeed(): number
	return WalkBoostLogic.IslandBase * WalkBoostLogic.Multiplier
end

-- WalkSpeed for a base speed and a boost multiplier: the boost multiplies the base, never above
-- TopSpeed, so a foreign base (someone else's WalkSpeed) is still held to 48; a base already at or
-- above TopSpeed is left as it is (a boost never slows anyone). A multiplier of 1 or less
-- scales the base with no cap. SpeedModifiers.target is the same formula.
function WalkBoostLogic.speed(base: number, multiplier: number): number
	if multiplier > 1 then
		return math.max(base, math.min(base * multiplier, WalkBoostLogic.topSpeed()))
	end
	return base * multiplier
end

-- True for a UserGameSettings.SavedQualityLevel value (its EnumItem .Value) that is low detail.
function WalkBoostLogic.lowGraphics(level: number): boolean
	return level >= 1 and level <= WalkBoostLogic.LowGraphicsMax
end

-- True when a dust puff may be made: the walker is walking (gait "walk") along a boost lane
-- (onLane: counted as over a strip this sample) faster than PuffMinSpeed studs/s horizontally, and
-- neither Reduced Motion (calm) nor low graphics detail applies. Off the lane, at rest, in the air,
-- seated or after leaving the lane there is none.
function WalkBoostLogic.puffWanted(onLane: boolean, gait: Gait, speed: number, calm: boolean, low: boolean): boolean
	return onLane and gait == "walk" and speed > WalkBoostLogic.PuffMinSpeed and not calm and not low
end

-- True when the next puff is allowed: none made yet (last nil), a clock that went backwards, or
-- PuffInterval seconds since the last. Calling this and recording `now` on true gives at most
-- 1 / PuffInterval = 4 puffs a second, whatever the frame rate.
function WalkBoostLogic.puffDue(last: number?, now: number): boolean
	return last == nil or now < last or now - last >= WalkBoostLogic.PuffInterval - TIME_EPSILON
end

return WalkBoostLogic
