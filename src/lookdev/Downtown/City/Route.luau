--!strict
-- Route geometry for the Downtown B city grammar (Lane 3 preview). Pure maths: no instances.
-- Frame (kit contract): +X right, travel toward -Z, ground y = 0, road centre line x = 0 at
-- every segment's start socket. `s` is distance along the route centre line (studs); `d` is the
-- signed offset to the right of it (left side negative).
--
-- Segment kinds: Straight (96 or 192), CurveL / CurveR (radius 360, 16 degrees, arc about
-- 100.53 studs), Intersection (96, a 30-stud cross street centred at u 48), BridgeDeck (192,
-- straight), Transition (96, straight, a district-boundary glue piece). A segment's end socket is
-- `start * Route.localFrame(bend, radius, length, 0, 0)`.

local Route = {}

Route.RADIUS = 360
Route.CURVE_DEGREES = 16
Route.CURVE_LENGTH = Route.RADIUS * math.rad(Route.CURVE_DEGREES) -- about 100.53
Route.INTERSECTION_LENGTH = 96
Route.TRANSITION_LENGTH = 96
Route.BRIDGE_LENGTH = 192
Route.CROSS_WIDTH = 30 -- cross street carriageway
Route.CROSS_SIDEWALK = 12
Route.MOUTH = Route.CROSS_WIDTH / 2 + Route.CROSS_SIDEWALK -- 27: no frontage within this of the cross centre

export type Kind = "Straight" | "CurveL" | "CurveR" | "Intersection" | "BridgeDeck" | "Transition"

export type Segment = {
	index: number,
	kind: Kind,
	length: number,
	startS: number,
	endS: number,
	start: CFrame, -- start socket (world)
	finish: CFrame, -- end socket (world)
	bend: number, -- -1 left, 0 straight, 1 right
	radius: number,
	heading: number, -- degrees right of the route's initial heading, at the start socket
	district: string,
	span: number, -- index into Plan.districts
	cycle: number,
	mesh: string, -- kit mesh name for this road piece (a proxy is built when missing)
	crossAt: number?, -- local u of the cross street centre (Intersection only)
}

function Route.bendOf(kind: Kind): number
	if kind == "CurveR" then
		return 1
	elseif kind == "CurveL" then
		return -1
	end
	return 0
end

-- The frame at local distance u along a segment (relative to its start socket), offset d to
-- the right and lifted by y. LookVector is the direction of travel.
function Route.localFrame(bend: number, radius: number, u: number, d: number, y: number): CFrame
	if bend == 0 then
		return CFrame.new(d, y, -u)
	end
	local theta = u / radius
	if bend > 0 then
		return CFrame.new(radius, 0, 0) * CFrame.Angles(0, -theta, 0) * CFrame.new(-radius + d, y, 0)
	end
	return CFrame.new(-radius, 0, 0) * CFrame.Angles(0, theta, 0) * CFrame.new(radius + d, y, 0)
end

-- How much longer (> 1) or shorter (< 1) a line at offset d is than the centre line.
function Route.sideFactor(bend: number, radius: number, d: number): number
	if bend == 0 then
		return 1
	end
	return (radius - bend * d) / radius
end

-- Index of the segment containing s (clamped to the first / last segment).
function Route.find(segments: { Segment }, s: number): number
	local lo, hi = 1, #segments
	if hi == 0 then
		return 0
	end
	if s <= segments[1].startS then
		return 1
	end
	if s >= segments[hi].startS then
		return hi
	end
	while lo < hi do
		local mid = (lo + hi + 1) // 2
		if segments[mid].startS <= s then
			lo = mid
		else
			hi = mid - 1
		end
	end
	return lo
end

-- World frame at route distance s, offset d, height y. Beyond either end the route continues
-- straight along the end tangent, so cameras can look past the ends.
function Route.frame(segments: { Segment }, s: number, d: number?, y: number?): CFrame
	local offset, lift = d or 0, y or 0
	local n = #segments
	if n == 0 then
		return CFrame.new(offset, lift, -s)
	end
	local first = segments[1]
	if s < first.startS then
		return first.start * CFrame.new(offset, lift, -(s - first.startS))
	end
	local last = segments[n]
	if s > last.endS then
		return last.finish * CFrame.new(offset, lift, -(s - last.endS))
	end
	local seg = segments[Route.find(segments, s)]
	return seg.start * Route.localFrame(seg.bend, seg.radius, s - seg.startS, offset, lift)
end

function Route.point(segments: { Segment }, s: number, d: number?, y: number?): Vector3
	return Route.frame(segments, s, d, y).Position
end

-- A per-side arc-length map: lots are packed along their own side's frontage line, so lots on
-- the inside of a curve never overlap and lots on the outside never leave gaps.
export type SideMap = {
	side: number,
	d: number,
	rows: { { s0: number, t0: number, factor: number, length: number } },
	total: number,
}

function Route.sideMap(segments: { Segment }, side: number, d: number): SideMap
	local rows = {}
	local t = 0
	for _, seg in segments do
		local factor = Route.sideFactor(seg.bend, seg.radius, d)
		table.insert(rows, { s0 = seg.startS, t0 = t, factor = factor, length = seg.length })
		t += seg.length * factor
	end
	return { side = side, d = d, rows = rows, total = t }
end

function Route.tToS(map: SideMap, t: number): number
	local rows = map.rows
	if #rows == 0 then
		return t
	end
	local lo, hi = 1, #rows
	while lo < hi do
		local mid = (lo + hi + 1) // 2
		if rows[mid].t0 <= t then
			lo = mid
		else
			hi = mid - 1
		end
	end
	local row = rows[lo]
	return row.s0 + (t - row.t0) / row.factor
end

function Route.sToT(map: SideMap, s: number): number
	local rows = map.rows
	if #rows == 0 then
		return s
	end
	local lo, hi = 1, #rows
	while lo < hi do
		local mid = (lo + hi + 1) // 2
		if rows[mid].s0 <= s then
			lo = mid
		else
			hi = mid - 1
		end
	end
	local row = rows[lo]
	return row.t0 + (s - row.s0) * row.factor
end

return table.freeze(Route)
