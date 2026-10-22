--!strict
-- Downtown look-development comparison fixture (Lane 3 preview, 2026-10-22). The one fixed
-- test road used identically by all three visual studies; values are the PREVIEW numbers in
-- vault/design/specs/downtown-lookdev-fixture.md, for Brian R to confirm. This is NOT segment
-- generation and not Lane 1's road contract: nothing outside src/lookdev may require it.
--
-- Road frame: +X right, the car drives toward -Z, ground y = 0. `s` is distance along the road
-- centre line from z = 0; `d` is the signed offset to the right of it (lane 2 centre: d -6.25).
--   s 0..140    straight A along -Z
--   s 140..240  constant radius 300 bending right (+X), centre of curvature (300, 0, -140)
--   s 240..     straight B along the curve's exit heading (about 19 degrees right of -Z)
-- Values outside 0..360 extrapolate along the end straights, so cameras can look past the ends.

local Fixture = {}

Fixture.LENGTH = 360
Fixture.CURVE_START = 140
Fixture.CURVE_END = 240
Fixture.RADIUS = 300
Fixture.LANES = 4
Fixture.LANE_WIDTH = 12.5
Fixture.HALF_WIDTH = 25 -- carriageway 50 studs, one direction
Fixture.EDGE_LINE = 0.6
Fixture.LANE_LINE = 0.5
Fixture.DASH_ON = 10
Fixture.DASH_OFF = 10
Fixture.CURB_WIDTH = 0.8
Fixture.CURB_HEIGHT = 0.6
Fixture.SIDEWALK = 12 -- beyond the curb
Fixture.FRONTAGE = 25 + 0.8 + 12 -- 37.8 from the centre line: the sidewalk's outer edge
Fixture.INTERSECTION_S = 265
Fixture.CROSS_WIDTH = 30
Fixture.ZEBRA_S = 245
Fixture.CAR_LANE = 2
Fixture.SPEED = 50 -- studs per second (7.2 s pass)
Fixture.CAR_SIZE = Vector3.new(5.66, 4.71, 12.47) -- Puglet reference, width x height x length
Fixture.COMPARISON_FRAMES = table.freeze({ 30, 115, 200, 262 })
Fixture.FRAME_LABELS = table.freeze({ [30] = "start", [115] = "construction", [200] = "oil", [262] = "intersection" })
-- landmark anchors (s, side) as in D1's assets/downtown/kit/fixture.py
Fixture.LANDMARK = table.freeze({
	A = { s = 150, side = 1 },
	B = { s = 228, side = 1 },
	C = { s = 320, side = -1 },
})
Fixture.TRAIN_CLEARANCE = 44 -- underside of the crossing span

local THETA_END = (Fixture.CURVE_END - Fixture.CURVE_START) / Fixture.RADIUS
Fixture.CURVE_ANGLE = THETA_END -- radians, about 19.1 degrees

-- Centre line offset of a lane, 1 (left) .. 4 (right).
function Fixture.laneCentre(lane: number): number
	return -Fixture.HALF_WIDTH + Fixture.LANE_WIDTH * (lane - 0.5)
end

local function forwardAt(theta: number): Vector3
	return Vector3.new(math.sin(theta), 0, -math.cos(theta))
end

local function curvePoint(theta: number, d: number): Vector3
	local r = Fixture.RADIUS - d
	return Vector3.new(Fixture.RADIUS - r * math.cos(theta), 0, -Fixture.CURVE_START - r * math.sin(theta))
end

-- Heading angle (radians to the right of -Z) at s.
function Fixture.heading(s: number): number
	if s <= Fixture.CURVE_START then
		return 0
	elseif s <= Fixture.CURVE_END then
		return (s - Fixture.CURVE_START) / Fixture.RADIUS
	end
	return THETA_END
end

-- The road frame at (s, d), lifted by y: LookVector is the driving direction, RightVector +d.
function Fixture.frame(s: number, d: number?, y: number?): CFrame
	local offset = d or 0
	local pos: Vector3
	if s <= Fixture.CURVE_START then
		pos = Vector3.new(offset, 0, -s)
	elseif s <= Fixture.CURVE_END then
		pos = curvePoint((s - Fixture.CURVE_START) / Fixture.RADIUS, offset)
	else
		pos = curvePoint(THETA_END, offset) + forwardAt(THETA_END) * (s - Fixture.CURVE_END)
	end
	pos += Vector3.new(0, y or 0, 0)
	return CFrame.lookAt(pos, pos + forwardAt(Fixture.heading(s)))
end

function Fixture.point(s: number, d: number?, y: number?): Vector3
	return Fixture.frame(s, d, y).Position
end

-- The nearest road coordinates (s, d) of a world position (plan view).
function Fixture.project(position: Vector3): (number, number)
	local flat = Vector3.new(position.X, 0, position.Z)
	local candidates: { number } = {}
	-- straight A (allows s < 0)
	table.insert(candidates, math.min(-flat.Z, Fixture.CURVE_START))
	-- curve
	local v = flat - Vector3.new(Fixture.RADIUS, 0, -Fixture.CURVE_START)
	local theta = math.clamp(math.atan2(-v.Z, -v.X), 0, THETA_END)
	table.insert(candidates, Fixture.CURVE_START + theta * Fixture.RADIUS)
	-- straight B (allows s > 360)
	local exit = Fixture.frame(Fixture.CURVE_END)
	table.insert(candidates, Fixture.CURVE_END + math.max((flat - exit.Position):Dot(exit.LookVector), 0))
	local bestS, bestDist = 0, math.huge
	for _, s in candidates do
		-- each candidate is the nearest centre-line point within its piece; keep the closest
		local dist = (flat - Fixture.point(s)).Magnitude
		if dist < bestDist then
			bestS, bestDist = s, dist
		end
	end
	local frame = Fixture.frame(bestS)
	return bestS, (flat - frame.Position):Dot(frame.RightVector)
end

-- True if a world position is over the main carriageway or the cross street.
function Fixture.onCarriageway(position: Vector3, margin: number?): boolean
	local m = margin or 0
	local s, d = Fixture.project(position)
	if math.abs(d) <= Fixture.HALF_WIDTH + m and s >= -60 and s <= Fixture.LENGTH + 80 then
		return true
	end
	return math.abs(s - Fixture.INTERSECTION_S) <= Fixture.CROSS_WIDTH / 2 + m
end

return table.freeze(Fixture)
