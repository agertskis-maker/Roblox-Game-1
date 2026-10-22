--!strict
-- Island walking boost, pure logic (Lane 3). No instances, no services, no clock of its own:
-- every function here is a plain function of its arguments, so it is unit-tested without a
-- character (Home/Island/WalkBoostTests) and shared by the live client boost
-- (Home/Island/WalkBoost) and the server preview walkers (Hub/Preview/WalkTests). This is the
-- one source of truth for the boost numbers. Spec: vault/design/specs/walk-boost.md.
--
-- Behaviour: while the walker is over an avenue boost strip the multiplier is Multiplier (1.5,
-- WalkSpeed 16 to 24). After stepping off it stays at Multiplier for Linger seconds, then eases
-- back to exactly 1 over Ease seconds (smoothstep). Stepping back on at any point returns it to
-- Multiplier straight away. The multiplier is a level, never a product: re-entering, standing
-- on two overlapping strips or sampling many times a frame can never take it above Multiplier.
--
-- Plan frame: x east, y north. Roblox world X = x, world Z = -y.

local WalkBoostLogic = {}

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

-- A strip in plan coordinates; y is the strip's surface height in world studs, when known.
export type Strip = { from: Vector2, to: Vector2, y: number? }

-- The boost state of one walker: the last time it was seen over a strip.
export type State = { lastOnStrip: number? }

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
	return { lastOnStrip = nil }
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

-- Forget the walker (respawn, disable, takeover).
function WalkBoostLogic.reset(state: State)
	state.lastOnStrip = nil
end

-- 0 at no boost, 1 at full boost: drives the feedback strength.
function WalkBoostLogic.intensity(multiplier: number): number
	local span = WalkBoostLogic.Multiplier - 1
	if span <= 0 then
		return 0
	end
	return math.clamp((multiplier - 1) / span, 0, 1)
end

return WalkBoostLogic
