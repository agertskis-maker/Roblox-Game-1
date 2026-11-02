--!strict
-- The Speedway's road network on the ground, per plot (Lane 3, presentation only; Round 2 N1). The
-- track, both pit lanes and the plot walk are one network: pit lanes are centre lines with a width, and
-- where a lane meets the track there is one junction: a single flat polygon that replaces the track
-- between two cross-sections, so no road piece lies on another. Every edge line, barrier gap and curb
-- end is worked out here, from the same geometry, so nothing can disagree with the road it belongs to.
-- Before this, the lanes, their paint and the barrier gaps were three separate hand-placed lists with
-- rectangles overlapping at the joint, which is why lines crossed and stopped in the wrong place.
--
-- Plan coordinates are the plot frame of Hub/Layout: (x, u), x to the right facing outward, u outward
-- from the fountain. The right lane (side 1) is drawn in the direction cars drive it, from the aisle to
-- the track; the left lane (side -1) is its mirror image. The ground is flat: the near turn has no bank
-- at any level, so every surface here has its top at Path.TrackTop.

local Path = require(script.Parent.Path)

local RoadNet = {}

RoadNet.LaneWidth = 10 -- the Paddock aisle's own width, so the lane leaves it at full width
RoadNet.LineInset = 0.6 -- the track's edge line stands this far in from the road's edge
RoadNet.LineWidth = 0.3
RoadNet.Top = Path.TrackTop
RoadNet.EndChord = 4 -- the length of the track ribbon's last slab at a junction

local R = Path.TurnRadius
local HALF = Path.HalfWidth
local uS = Path.StraightsStart
local NEAR = Vector2.new(0, uS) -- the near turn's centre
local AISLE_MID = 284.187 -- Hub/Layout.AisleMidU
local AISLE_END = 36 -- the Paddock's side edge
local LANE_OUT = 51.5 -- the pit row stretch (Hub/Layout laneV)
local MERGE_END = 405 -- where the lane's outer edge has become the track's outer edge

-- ------------------------------------------------------------------ lane centre line

type Turtle = { p: Vector2, d: Vector2, out: { Vector2 } }

local function rot(v: Vector2, a: number): Vector2
	local c, s = math.cos(a), math.sin(a)
	return Vector2.new(v.X * c - v.Y * s, v.X * s + v.Y * c)
end

local function line(t: Turtle, length: number)
	t.p += t.d * length
	table.insert(t.out, t.p)
end

local function arc(t: Turtle, radius: number, turn: number, chord: number)
	local sign = if turn >= 0 then 1 else -1
	local centre = t.p + Vector2.new(-t.d.Y, t.d.X) * radius * sign
	local n = math.max(2, math.ceil(radius * math.abs(turn) / chord))
	local start = t.p - centre
	for k = 1, n do
		t.p = centre + rot(start, turn * k / n)
		table.insert(t.out, t.p)
	end
	t.d = rot(t.d, turn).Unit
end

-- moves the line `shift` to the left of travel over `length` forward
local function sbend(t: Turtle, shift: number, length: number)
	local phi = 2 * math.atan(math.abs(shift) / length)
	local radius = length / (2 * math.sin(phi))
	local sign = if shift >= 0 then 1 else -1
	arc(t, radius, sign * phi, 5)
	arc(t, radius, -sign * phi, 5)
end

local function buildCentre(): { Vector2 }
	local halfLane = RoadNet.LaneWidth / 2
	local start = Vector2.new(AISLE_END, AISLE_MID)
	local t: Turtle = { p = start, d = Vector2.new(1, 0), out = { start } }
	line(t, 1) -- a straight first piece, so the lane's end edge is the aisle's edge
	arc(t, 9, math.pi / 2, 2) -- out of the aisle, along the Paddock's side
	line(t, 300 - t.p.Y)
	sbend(t, 46 - LANE_OUT, 35) -- out to the pit row stretch
	line(t, 345 - t.p.Y)
	sbend(t, LANE_OUT - (R + HALF - halfLane), MERGE_END - 345) -- the merge: about 25 degrees at its steepest
	return t.out
end

local CENTRE = buildCentre()

-- Points offset `off` to the left of travel from a polyline (each vertex on the mean normal).
local function offsetLine(points: { Vector2 }, off: number): { Vector2 }
	local out = table.create(#points)
	for i, p in points do
		local a = points[math.max(i - 1, 1)]
		local b = points[math.min(i + 1, #points)]
		local d = (b - a).Unit
		table.insert(out, p + Vector2.new(-d.Y, d.X) * off)
	end
	return out
end

-- ------------------------------------------------------------------ the track's outer boundary

local PATH = Path.forLevel(1)
local ARC_START = Path.StartU - uS -- lap distance where the near turn begins
local ARC_LENGTH = math.pi * R
local ARC_END = ARC_START + ARC_LENGTH
RoadNet.ArcStart, RoadNet.ArcEnd = ARC_START, ARC_END

-- Mirror a right-hand lap distance to the left side of the near turn.
local function mirrorS(s: number): number
	return ARC_START + ARC_END - s
end

-- The point `off` to the right of travel at lap distance s.
function RoadNet.trackPoint(s: number, off: number): Vector2
	local p, d = Path.planPoint(PATH, s)
	return p + Vector2.new(d.Y, -d.X) * off
end

-- Signed distance of p from the boundary `off` out from the track's centre (right side): negative on
-- the road side. Only used around the right end of the near turn.
local function pastBoundary(p: Vector2, off: number): number
	if p.Y < uS then
		return (p - NEAR).Magnitude - (R + off)
	end
	return p.X - (R + off)
end

-- Where the polyline first crosses into the boundary at `off`: the crossing point and its distance back
-- along the polyline's index (a fractional index).
local function firstCrossing(points: { Vector2 }, off: number): (Vector2, number)
	for i = 2, #points do
		local a, b = points[i - 1], points[i]
		local da, db = pastBoundary(a, off), pastBoundary(b, off)
		if da > 0 and db <= 0 then
			local lo, hi = 0, 1
			for _ = 1, 30 do
				local mid = (lo + hi) / 2
				if pastBoundary(a:Lerp(b, mid), off) > 0 then
					lo = mid
				else
					hi = mid
				end
			end
			return a:Lerp(b, hi), i - 1 + hi
		end
	end
	error("RoadNet: the lane never reaches the track")
end

-- The arc distance on the near turn of a point on it.
local function arcDistance(p: Vector2): number
	local v = p - NEAR
	-- apex of the turn (nearest the park) is straight down from NEAR; the right end is toward +x
	return ARC_START + ARC_LENGTH / 2 + math.atan2(v.X, -v.Y) * R
end

-- Part of a polyline between two fractional indices, the end points included.
local function slice(points: { Vector2 }, from: number, to: number): { Vector2 }
	local function at(k: number): Vector2
		local i = math.clamp(math.floor(k), 1, #points - 1)
		return points[i]:Lerp(points[i + 1], k - i)
	end
	local out = { at(from) }
	for i = math.floor(from) + 1, math.ceil(to) - 1 do
		table.insert(out, points[i])
	end
	table.insert(out, at(to))
	return out
end

-- A fractional index `distance` back from index k along a polyline.
local function backBy(points: { Vector2 }, k: number, distance: number): number
	local left = distance
	local i = math.floor(k)
	local here = points[i]:Lerp(points[i + 1], k - i)
	while i >= 1 do
		local step = (here - points[i]).Magnitude
		if step >= left then
			return i
				+ (
					if (points[i + 1] - points[i]).Magnitude > 1e-6
						then (here - points[i]).Magnitude * (1 - left / step) / (points[i + 1] - points[i]).Magnitude
						else 0
				)
		end
		left -= step
		here = points[i]
		i -= 1
	end
	return 1
end

local function bezier(a: Vector2, c: Vector2, b: Vector2, n: number): { Vector2 }
	local out = {}
	for k = 1, n - 1 do
		local t = k / n
		table.insert(out, a * (1 - t) ^ 2 + c * (2 * t * (1 - t)) + b * (t * t))
	end
	return out
end

-- ------------------------------------------------------------------ triangles

local function area(poly: { Vector2 }): number
	local sum = 0
	for i, p in poly do
		local q = poly[i % #poly + 1]
		sum += p.X * q.Y - q.X * p.Y
	end
	return sum / 2
end

local function cross(o: Vector2, a: Vector2, b: Vector2): number
	return (a.X - o.X) * (b.Y - o.Y) - (a.Y - o.Y) * (b.X - o.X)
end

local function segmentsCross(a: Vector2, b: Vector2, c: Vector2, d: Vector2): boolean
	local d1, d2 = cross(a, b, c), cross(a, b, d)
	local d3, d4 = cross(c, d, a), cross(c, d, b)
	return d1 * d2 < -1e-9 and d3 * d4 < -1e-9
end

-- Throws if the polygon crosses itself or repeats a vertex: a bad polygon must never reach the world.
local function validate(poly: { Vector2 }, label: string)
	local n = #poly
	for i = 1, n do
		local a, b = poly[i], poly[i % n + 1]
		assert((b - a).Magnitude > 1e-3, "RoadNet: repeated vertex in " .. label)
		for j = i + 2, n do
			if not (i == 1 and j == n) then
				local c, d = poly[j], poly[j % n + 1]
				assert(not segmentsCross(a, b, c, d), "RoadNet: " .. label .. " crosses itself")
			end
		end
	end
end

-- Ear clipping of a simple polygon, preferring the fattest ear so no sliver triangles appear.
function RoadNet.triangulate(input: { Vector2 }): { { Vector2 } }
	local poly = table.clone(input)
	if area(poly) < 0 then
		local reversed = table.create(#poly)
		for i = #poly, 1, -1 do
			table.insert(reversed, poly[i])
		end
		poly = reversed
	end
	local tris = {}
	while #poly > 3 do
		local best, bestScore = 0, -math.huge
		local n = #poly
		for i = 1, n do
			local a, b, c = poly[(i - 2) % n + 1], poly[i], poly[i % n + 1]
			local twice = cross(a, b, c)
			if twice > 1e-6 then
				local clear = true
				for _, p in poly do
					if p ~= a and p ~= b and p ~= c then
						if cross(a, b, p) >= -1e-9 and cross(b, c, p) >= -1e-9 and cross(c, a, p) >= -1e-9 then
							clear = false
							break
						end
					end
				end
				if clear then
					-- the smallest height of the triangle: bigger is a better ear
					local longest = math.max((b - a).Magnitude, (c - b).Magnitude, (a - c).Magnitude)
					local score = twice / longest
					if score > bestScore then
						best, bestScore = i, score
					end
				end
			end
		end
		if best == 0 then
			-- only collinear vertices left: drop the flattest
			for i = 1, n do
				if math.abs(cross(poly[(i - 2) % n + 1], poly[i], poly[i % n + 1])) < 1e-3 then
					best = i
					break
				end
			end
			assert(best ~= 0, "RoadNet: could not triangulate")
			table.remove(poly, best)
		else
			local n2 = #poly
			table.insert(tris, { poly[(best - 2) % n2 + 1], poly[best], poly[best % n2 + 1] })
			table.remove(poly, best)
		end
	end
	if math.abs(cross(poly[1], poly[2], poly[3])) > 1e-6 then
		table.insert(tris, { poly[1], poly[2], poly[3] })
	end
	return tris
end

function RoadNet.pointInPoly(p: Vector2, poly: { Vector2 }): boolean
	local inside = false
	local j = #poly
	for i = 1, #poly do
		local a, b = poly[i], poly[j]
		if (a.Y > p.Y) ~= (b.Y > p.Y) and p.X < (b.X - a.X) * (p.Y - a.Y) / (b.Y - a.Y) + a.X then
			inside = not inside
		end
		j = i
	end
	return inside
end

-- ------------------------------------------------------------------ the junction

export type Chain = { name: string, points: { Vector2 } }
export type Junction = {
	side: number,
	s0: number, -- lap distances between which this junction replaces the track
	s1: number,
	polygon: { Vector2 },
	triangles: { { Vector2 } },
	laneStrip: { Vector2 }, -- the lane's centre line from the aisle to the junction's cross-section
	laneMouth: { Vector2 }, -- the two ends of that cross-section
	lines: { Chain }, -- the paint of this side of the network
	dashes: { { Vector2 } }, -- the short dashed merge marking, one pair of ends per dash
	nose: Vector2,
	gap: { number }, -- lap distances where the outer barrier stands open
	s0Line: number, -- the track's outer line stops and starts here (right-hand order)
	s1Line: number,
}

local TIP_BACK = 4 -- how far back from the nose its rounding starts, each way

local function buildRight(): Junction
	local halfLane = RoadNet.LaneWidth / 2
	local leftEdge = offsetLine(CENTRE, halfLane)
	local rightEdge = offsetLine(CENTRE, -halfLane)
	local nose, noseK = firstCrossing(leftEdge, HALF)
	-- the grass tip is rounded off, so it is a neat point, not a long spike
	local backK = backBy(leftEdge, noseK, TIP_BACK)
	local noseS = arcDistance(nose)
	local s0 = noseS - TIP_BACK
	-- the junction's edges are the exact end edges of the slabs that meet it: a slab ends square to its
	-- own chord, not to the curve, so these corners come from the last chord of each road
	local chord = RoadNet.EndChord
	local trackA, trackB = RoadNet.trackPoint(s0 - chord, 0), RoadNet.trackPoint(s0, 0)
	local trackDir = (trackB - trackA).Unit
	local trackOut = Vector2.new(trackDir.Y, -trackDir.X)
	local onTrack = trackB + trackOut * HALF
	local onTrackIn = trackB - trackOut * HALF
	local laneStrip = slice(CENTRE, 1, backK)
	local laneEnd = laneStrip[#laneStrip]
	local laneDir = (laneEnd - laneStrip[#laneStrip - 1]).Unit
	local laneLeft = Vector2.new(-laneDir.Y, laneDir.X)
	local onLane = laneEnd + laneLeft * halfLane
	local mouthRight = laneEnd - laneLeft * halfLane
	local s1 = ARC_END + (MERGE_END + 2 - uS)

	-- the boundary, going round: along the inner edge from s0 to s1, then back along the outside
	local poly: { Vector2 } = {}
	local inner: { number } = {}
	do
		local arcSteps = math.max(2, math.ceil((ARC_END - s0) / 4))
		for k = 0, arcSteps do
			table.insert(inner, s0 + (ARC_END - s0) * k / arcSteps)
		end
		table.insert(inner, s1)
	end
	table.insert(poly, onTrackIn)
	for i = 2, #inner do
		table.insert(poly, RoadNet.trackPoint(inner[i], -HALF))
	end
	table.insert(poly, RoadNet.trackPoint(s1, HALF))
	-- the lane's outer edge, from its end back to the cross-section at the rounded nose
	local lastK = #rightEdge
	local mouthK = math.floor(backK)
	for i = lastK, mouthK + 1, -1 do
		table.insert(poly, rightEdge[i])
	end
	table.insert(poly, mouthRight)
	table.insert(poly, onLane)
	for _, p in bezier(onLane, nose, onTrack, 5) do
		table.insert(poly, p)
	end
	table.insert(poly, onTrack)
	validate(poly, "pit junction")

	-- paint: the lines stand LineInset in from the road's edge. The track's outer line turns the corner
	-- round the grass tip and carries on as the lane's near edge line, in one chain. The lane's far edge
	-- line runs on into the track's outer line.
	local inset = RoadNet.LineInset
	local nearLine = offsetLine(CENTRE, halfLane - inset)
	local farLine = offsetLine(CENTRE, -(halfLane - inset))
	local corner, cornerK = firstCrossing(nearLine, HALF - inset)
	local cornerBack = TIP_BACK + 0.8
	local nearBackK = backBy(nearLine, cornerK, cornerBack)
	local cornerS = arcDistance(corner)
	local lineS0 = cornerS - cornerBack
	local lineFrom = RoadNet.trackPoint(lineS0, HALF - inset)
	local nearTo = slice(nearLine, nearBackK, nearBackK + 1e-3)[1]
	local chainNear: { Vector2 } = {}
	do
		local steps = math.max(1, math.ceil((lineS0 - s0) / 3))
		for k = 0, steps do
			table.insert(chainNear, RoadNet.trackPoint(s0 + (lineS0 - s0) * k / steps, HALF - inset))
		end
		table.insert(chainNear, lineFrom)
		for _, p in bezier(lineFrom, corner, nearTo, 6) do
			table.insert(chainNear, p)
		end
		local rest = slice(nearLine, 1, nearBackK)
		for i = #rest, 1, -1 do
			table.insert(chainNear, rest[i])
		end
	end
	if (chainNear[1] - chainNear[2]).Magnitude < 1e-3 then
		table.remove(chainNear, 1)
	end
	local chainFar = table.clone(farLine)
	table.insert(chainFar, RoadNet.trackPoint(s1, HALF - inset))
	-- the track's inner line through the junction
	local chainInner: { Vector2 } = {}
	for _, s in inner do
		table.insert(chainInner, RoadNet.trackPoint(s, -(HALF - inset)))
	end

	-- the dashed merge marking: the track's own outer edge line, carried across the mouth in short
	-- dashes from the corner until the lane's far line has come within a metre of it
	local dashes = {}
	local dashOn, dashOff = 2.4, 2.6
	local start = cornerS + 2.5
	local stopU = MERGE_END - 8
	local s = start
	while true do
		local a = RoadNet.trackPoint(s, HALF - inset)
		local b = RoadNet.trackPoint(s + dashOn, HALF - inset)
		if b.Y > stopU then
			break
		end
		table.insert(dashes, { a, b })
		s += dashOn + dashOff
	end

	-- the barrier's opening runs from just before the grass tip to the merge's end
	local gap = { s0 - 9, s1 } -- the tyres stop before the grass nose gets thin
	return {
		side = 1,
		s0 = s0,
		s1 = s1,
		polygon = poly,
		triangles = RoadNet.triangulate(poly),
		laneStrip = laneStrip,
		laneMouth = { onLane, mouthRight },
		lines = {
			{ name = "EdgeLine", points = chainNear },
			{ name = "EdgeLine", points = chainFar },
			{ name = "EdgeLine", points = chainInner },
		},
		dashes = dashes,
		nose = nose,
		gap = gap,
		s0Line = s0,
		s1Line = s1,
	}
end

local function mirrorPoints(points: { Vector2 }): { Vector2 }
	local out = table.create(#points)
	for _, p in points do
		table.insert(out, Vector2.new(-p.X, p.Y))
	end
	return out
end

local function buildLeft(right: Junction): Junction
	local poly = mirrorPoints(right.polygon)
	local tris = {}
	for _, t in right.triangles do
		table.insert(tris, mirrorPoints(t))
	end
	local lines = {}
	for _, c in right.lines do
		table.insert(lines, { name = c.name, points = mirrorPoints(c.points) })
	end
	local dashes = {}
	for _, d in right.dashes do
		table.insert(dashes, mirrorPoints(d))
	end
	return {
		side = -1,
		s0 = mirrorS(right.s1),
		s1 = mirrorS(right.s0),
		polygon = poly,
		triangles = tris,
		laneStrip = mirrorPoints(right.laneStrip),
		laneMouth = mirrorPoints(right.laneMouth),
		lines = lines,
		dashes = dashes,
		nose = Vector2.new(-right.nose.X, right.nose.Y),
		gap = { mirrorS(right.gap[2]), mirrorS(right.gap[1]) },
		s0Line = mirrorS(right.s1Line),
		s1Line = mirrorS(right.s0Line),
	}
end

local RIGHT = buildRight()
local LEFT = buildLeft(RIGHT)
RoadNet.Right, RoadNet.Left = RIGHT, LEFT
RoadNet.Junctions = { LEFT, RIGHT }

-- ------------------------------------------------------------------ the walk's gate

local APEX = ARC_START + ARC_LENGTH / 2
RoadNet.WalkHalfWidth = 3
local GATE_HALF = RoadNet.WalkHalfWidth + 1.5 -- the opening in the barrier, each way from the walk's centre

-- Barrier gaps as lap distances, in lap order (the two pit mouths and the walk's gate).
RoadNet.Gaps = {
	{ LEFT.gap[1], LEFT.gap[2] },
	{ APEX - GATE_HALF * R / (R + HALF), APEX + GATE_HALF * R / (R + HALF) },
	{ RIGHT.gap[1], RIGHT.gap[2] },
}

-- True when lap distance s (with `margin` either way) falls in a barrier opening.
function RoadNet.barrierOpen(s: number, margin: number?): boolean
	local m = margin or 0
	for _, gap in RoadNet.Gaps do
		if s > gap[1] - m and s < gap[2] + m then
			return true
		end
	end
	return false
end

-- The walkway polygon from the Paddock to the track's outer edge: its far end is the road's own edge,
-- point for point, so the paving meets the road with nothing between them.
function RoadNet.walkPolygon(fromU: number): { Vector2 }
	local w = RoadNet.WalkHalfWidth
	local r = R + HALF
	local function edgeU(x: number): number
		return uS - math.sqrt(r * r - x * x)
	end
	local poly = { Vector2.new(-w, fromU), Vector2.new(w, fromU) }
	-- the track's slabs are chords of the true circle by at most 0.15, so this edge is laid just inside
	-- their ends: the paving stops at the road and no surface lies on another
	table.insert(poly, Vector2.new(w, edgeU(w) - 0.02))
	table.insert(poly, Vector2.new(0, edgeU(0) - 0.02))
	table.insert(poly, Vector2.new(-w, edgeU(w) - 0.02))
	return poly
end

-- Pieces of [a, b] left after taking out the junctions (road ribbons stop exactly at their edges).
function RoadNet.cutRanges(a: number, b: number): { { number } }
	local out = {}
	local from = a
	for _, j in RoadNet.Junctions do
		if j.s1 > from and j.s0 < b then
			if j.s0 > from then
				table.insert(out, { from, j.s0 })
			end
			from = math.max(from, j.s1)
		end
	end
	if from < b then
		table.insert(out, { from, b })
	end
	return out
end

-- The lane's plan polygon and the whole road's outline, for the checks.
function RoadNet.laneEdges(j: Junction): ({ Vector2 }, { Vector2 })
	local half = RoadNet.LaneWidth / 2
	return offsetLine(j.laneStrip, half), offsetLine(j.laneStrip, -half)
end

RoadNet.Centre = CENTRE

return RoadNet
