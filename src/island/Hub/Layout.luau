--!strict
-- Island hub layout, revision 3: six plots on a half circle facing a park and the portal row
-- (Lane 3, build-time data). Pure geometry, no instances. The numbers come from HubData,
-- which is generated from assets/island/rework/island-layout.js; this module adds the
-- frames, the oval lap path, bays and pit-lane points the recipes and markers need.
--
-- Frames:
--   Plan frame: x east, y north toward the plots, origin at the fountain centre. Bearings
--   are clockwise from north. Roblox world: X = x, Z = -y (north is -Z).
--   Plot frame: x (v) to the right when facing outward, y (u) outward along the plot's
--   centre line, origin at the fountain centre.

local Data = require(script.Parent.HubData)

local Layout = {}

Layout.Data = Data
Layout.PlotCount = Data.plotCount -- the only plot count; written to Island.PlotCount
Layout.ContractVersion = "0-draft"
Layout.LayoutVersion = "rev3-hub"
Layout.SurfaceY = 0
-- The park's height layers (big round M1). No two surfaces of different colour share a height, so
-- where they overlap the higher one simply wins and nothing flickers. 0.06 apart at the least.
Layout.PathTop = Layout.SurfaceY + 0.08 -- avenues, ring, approaches, walks, bridges' path ends
Layout.PadBorderTop = Layout.SurfaceY + 0.14
Layout.PromenadeTop = Layout.SurfaceY + 0.16
Layout.PadTop = Layout.SurfaceY + 0.2
Layout.PlazaTop = Layout.SurfaceY + 0.24
Layout.HalfSectorDeg = Data.sectorDeg / 2
Layout.BufferPerSide = Data.bufferPerSide

local plot = Data.plot
local track = Data.track
Layout.EntranceRadius = plot.entranceRadius
Layout.SpawnU = plot.entranceRadius + 4
Layout.GateHalfWidth = 7
-- The nameplate sits on top of the gate lintel, above the view from the spawn toward the portals.
Layout.NameplateY = 11.45

local SIN_H, COS_H = math.sin(math.rad(Layout.HalfSectorDeg)), math.cos(math.rad(Layout.HalfSectorDeg))

-- Frame conversions
function Layout.plotBearing(index: number): number
	return Data.bearings[index]
end

function Layout.planToWorld(p: Vector2, y: number?): Vector3
	return Vector3.new(p.X, y or Layout.SurfaceY, -p.Y)
end

function Layout.worldToPlan(v: Vector3): Vector2
	return Vector2.new(v.X, -v.Z)
end

function Layout.plotToPlan(bearingDeg: number, p: Vector2): Vector2
	local b = math.rad(bearingDeg)
	return Vector2.new(p.X * math.cos(b) + p.Y * math.sin(b), -p.X * math.sin(b) + p.Y * math.cos(b))
end

function Layout.planToPlot(bearingDeg: number, p: Vector2): Vector2
	local b = math.rad(bearingDeg)
	return Vector2.new(p.X * math.cos(b) - p.Y * math.sin(b), p.X * math.sin(b) + p.Y * math.cos(b))
end

function Layout.plotToWorld(bearingDeg: number, p: Vector2, y: number?): Vector3
	return Layout.planToWorld(Layout.plotToPlan(bearingDeg, p), y)
end

function Layout.polar(bearingDeg: number, radius: number): Vector2
	local b = math.rad(bearingDeg)
	return Vector2.new(radius * math.sin(b), radius * math.cos(b))
end

-- Distance inside the plot's sector from the nearer sector ray (plot frame).
function Layout.rayClear(p: Vector2): number
	return p.Y * SIN_H - math.abs(p.X) * COS_H
end

-- Lap path: a stadium oval, long axis outward. Counter-clockwise in the plot frame: up the
-- right straight, round the far curve, down the left straight toward the park, round the near curve.
export type Segment = {
	kind: "arc" | "line",
	s0: number,
	length: number,
	from: Vector2,
	to: Vector2,
	center: Vector2,
	a0: number,
}

local R = track.turnRadius
local L = track.straight
local uS = plot.straightsStart
Layout.TurnRadius = R
Layout.Straight = L
Layout.StraightsStart = uS
Layout.HalfWidth = track.width / 2
Layout.ClearanceOffset = track.clearance

local segments: { Segment } = {}
do
	local s = 0
	local function line(from: Vector2, to: Vector2)
		local length = (to - from).Magnitude
		table.insert(
			segments,
			{ kind = "line", s0 = s, length = length, from = from, to = to, center = Vector2.zero, a0 = 0 }
		)
		s += length
	end
	local function arc(center: Vector2, a0: number)
		local length = math.pi * R
		local from = center + Vector2.new(math.cos(a0), math.sin(a0)) * R
		local to = center - Vector2.new(math.cos(a0), math.sin(a0)) * R
		table.insert(
			segments,
			{ kind = "arc", s0 = s, length = length, from = from, to = to, center = center, a0 = a0 }
		)
		s += length
	end
	line(Vector2.new(R, uS), Vector2.new(R, uS + L))
	arc(Vector2.new(0, uS + L), 0)
	line(Vector2.new(-R, uS + L), Vector2.new(-R, uS))
	arc(Vector2.new(0, uS), math.pi)
	Layout.PathLength = s
end
Layout.Segments = segments
Layout.RightStraight = segments[1]
Layout.LeftStraight = segments[3]

-- Position and unit tangent at distance s along the lap (wraps round the loop).
function Layout.pointAt(s: number): (Vector2, Vector2)
	s = s % Layout.PathLength
	for _, seg in segments do
		if s <= seg.s0 + seg.length + 1e-9 then
			local ds = s - seg.s0
			if seg.kind == "line" then
				local dir = (seg.to - seg.from).Unit
				return seg.from + dir * ds, dir
			end
			local a = seg.a0 + ds / R
			return seg.center + Vector2.new(math.cos(a), math.sin(a)) * R, Vector2.new(-math.sin(a), math.cos(a))
		end
	end
	return segments[1].from, Vector2.new(0, 1)
end

-- Outward (right-of-travel) normal for the counter-clockwise loop.
function Layout.outward(tangent: Vector2): Vector2
	return Vector2.new(tangent.Y, -tangent.X)
end

-- Start / finish on the left straight, a quarter of the way from the near end, cars heading
-- toward the park (the gantry reservation is centred on the same line).
Layout.StartS = Layout.LeftStraight.s0 + 0.75 * L
Layout.StartU = uS + 0.25 * L
Layout.SampleCount = track.sampleCount

-- Round fillets where the paths meet the plaza circle (Task 4 review J7), plan frame. Each
-- fillet of radius `radius` (half the path width) touches the path edge at `t1` and the plaza
-- circle at `t2`; `centre` is its circle's centre, out on the lawn. The paved corner is bounded
-- by the edge from `corner` (where the edge crosses the plaza circle) to `t1`, the fillet arc to
-- `t2`, and the plaza circle back to `corner`. The Park recipe paves it; the dressing keeps off.
export type Fillet = { corner: Vector2, centre: Vector2, radius: number, t1: Vector2, t2: Vector2 }
local function nearestDir(points: { Vector2 }, p: Vector2): Vector2
	local best, dir = math.huge, Vector2.new(1, 0)
	for i = 1, #points - 1 do
		local a, b = points[i], points[i + 1]
		local ab = b - a
		if ab.Magnitude > 1e-6 then
			local t = math.clamp((p - a):Dot(ab) / ab:Dot(ab), 0, 1)
			local d = (p - (a + ab * t)).Magnitude
			if d < best then
				best, dir = d, ab.Unit
			end
		end
	end
	return dir
end
local fillets: { Fillet } = {}
do
	local plazaR = Data.park.plazaRadius
	for _, path in Data.park.paths do
		local pts = path.points
		local h = path.width / 2
		local r = h
		for _, e in { pts[1], pts[#pts] } do
			if math.abs(e.Magnitude - plazaR) < 1.5 then
				local dir = nearestDir(pts, e)
				if dir:Dot(e) < 0 then
					dir = -dir
				end
				local n = Vector2.new(-dir.Y, dir.X)
				-- the outward root of |b + dir t| = radius
				local function outward(b: Vector2, radius: number): number?
					local bd = b:Dot(dir)
					local disc = bd * bd - b:Dot(b) + radius * radius
					if disc < 0 then
						return nil
					end
					return -bd + math.sqrt(disc)
				end
				for _, s in { 1, -1 } do
					local edge = e + n * s * h
					local tc = outward(edge, plazaR)
					local line = e + n * s * (h + r)
					local to = outward(line, plazaR + r)
					if tc and to and to > tc then
						local centre = line + dir * to
						table.insert(fillets, {
							corner = edge + dir * tc,
							centre = centre,
							radius = r,
							t1 = edge + dir * to,
							t2 = centre * (plazaR / (plazaR + r)),
						})
					end
				end
			end
		end
	end
end
Layout.PlazaFillets = fillets

-- True when p lies on a plaza fillet's paving, grown by `margin`.
function Layout.onPlazaFillet(p: Vector2, margin: number): boolean
	local plazaR = Data.park.plazaRadius
	if p.Magnitude < plazaR - margin then
		return false
	end
	for _, f in fillets do
		-- inside the corner's bounding triangle (corner, t1, t2) grown by the margin, and outside
		-- the fillet circle shrunk by it
		local d = (p - f.centre).Magnitude
		if d > f.radius - margin then
			local u = f.t1 - f.corner
			local v = f.t2 - f.corner
			local w = p - f.corner
			local den = u.X * v.Y - u.Y * v.X
			if math.abs(den) > 1e-6 then
				local a = (w.X * v.Y - w.Y * v.X) / den
				local b = (u.X * w.Y - u.Y * w.X) / den
				local grow = margin / math.max(1, math.min(u.Magnitude, v.Magnitude))
				if a >= -grow and b >= -grow and a + b <= 1 + grow then
					return true
				end
			end
		end
	end
	return false
end

-- The stage forecourt, between the plaza and the stage walk across the portal row. Its sides run
-- along the outer edges of the two side portal approaches (Adam's screenshot 10: a square block
-- used to run out past the approaches and left hard-edged grass shapes in the paving).
Layout.ForecourtEdgeY = Data.park.portal.frontY + 3 + 5 -- the stage walk's plaza-side edge
local function forecourtSpan(): (number, number, number)
	local plazaR = Data.park.plazaRadius
	for _, path in Data.park.paths do
		if path.kind == "ApproachDustyHighway" then
			local a, b = path.points[1], path.points[2]
			local dir = (b - a).Unit
			local n = Vector2.new(-dir.Y, dir.X)
			if n.X < 0 then
				n = -n
			end
			local e = a + n * path.width / 2
			local bd = e:Dot(dir)
			local t = -bd - math.sqrt(math.max(0, bd * bd - e:Dot(e) + plazaR * plazaR))
			local top = e + dir * t
			local run = (Layout.ForecourtEdgeY - top.Y) / dir.Y
			return top.X, top.Y, top.X + dir.X * run
		end
	end
	error("no ApproachDustyHighway path")
end
Layout.ForecourtTopX, Layout.ForecourtTopY, Layout.ForecourtBottomX = forecourtSpan()

function Layout.onForecourt(p: Vector2, margin: number): boolean
	if p.Y > Layout.ForecourtTopY + margin or p.Y < Layout.ForecourtEdgeY - margin then
		return false
	end
	local t = (Layout.ForecourtTopY - p.Y) / (Layout.ForecourtTopY - Layout.ForecourtEdgeY)
	return math.abs(p.X) <= Layout.ForecourtTopX + (Layout.ForecourtBottomX - Layout.ForecourtTopX) * t + margin
end

local function polylineDistance(points: { Vector2 }, p: Vector2): number
	local best = math.huge
	for i = 1, #points - 1 do
		local a, b = points[i], points[i + 1]
		local ab = b - a
		local t = if ab.Magnitude > 1e-6 then math.clamp((p - a):Dot(ab) / ab:Dot(ab), 0, 1) else 0
		best = math.min(best, (p - (a + ab * t)).Magnitude)
	end
	return best
end

-- True when p lies on any paving (plaza, its fillets, the forecourt, a path, a pad), grown by
-- `margin`. Everything scattered on the lawns asks this, so nothing grows through the paving.
function Layout.onPaved(p: Vector2, margin: number): boolean
	if p.Magnitude <= Data.park.plazaRadius + margin then
		return true
	end
	if Layout.onPlazaFillet(p, margin) or Layout.onForecourt(p, margin) then
		return true
	end
	for _, path in Data.park.paths do
		if polylineDistance(path.points, p) <= path.width / 2 + margin then
			return true
		end
	end
	for _, b in Data.park.buildings do
		if b.id == "Gazebo" then
			if (p - b.centre).Magnitude <= math.max(b.width, b.depth) / 2 + 4 + margin then
				return true
			end
		elseif b.id == "SnackCornerEast" or b.id == "SnackCornerWest" then
			local side = Vector2.new(-b.facing.Y, b.facing.X)
			local d = p - b.centre
			if
				math.abs(d:Dot(side)) <= b.width / 2 + 1 + margin
				and math.abs(d:Dot(b.facing)) <= b.depth / 2 + 1 + margin
			then
				return true
			end
		end
	end
	return false
end

-- True when plan point p lies within `margin` of a hub building's box (the Garage and Stunt
-- boxes run on 14 studs in front for their forecourt and apron) or a leaderboard. Scatter
-- outside the park (ground cover) keeps off these (Task 4 review N2: tall grass on the apron).
local FORECOURT = { Garage = 14, StuntGate = 14 }
function Layout.inDestination(p: Vector2, margin: number): boolean
	local park = Data.park :: any
	local function inBox(centre: Vector2, facing: Vector2, width: number, depth: number, front: number): boolean
		local side = Vector2.new(-facing.Y, facing.X)
		local q = p - (centre + facing * front / 2)
		return math.abs(q:Dot(side)) < width / 2 + margin and math.abs(q:Dot(facing)) < (depth + front) / 2 + margin
	end
	for _, b in park.buildings do
		if inBox(b.centre, b.facing, b.width, b.depth, FORECOURT[b.id] or 0) then
			return true
		end
	end
	for _, b in park.boards do
		if inBox(b.centre, b.facing or Vector2.new(0, 1), b.width, b.depth, 0) then
			return true
		end
	end
	-- the portal gates (their plinths run back about 12 from the portal front line)
	local portal = park.portal
	for _, q in park.portals do
		if inBox(Vector2.new(q.x, portal.frontY - 6), Vector2.new(0, 1), portal.width + 6, 14, 0) then
			return true
		end
	end
	return false
end

-- ---------------------------------------------------------------- path ends (big round N1-01, N1-02)
-- Park lays every path as square-ended strips. A strip used to run on past the path's last point by 15 %
-- of the path's width whatever it met there. That tucks a path under the paving it arrives at, which
-- hides the lens at a curved edge, but at a free end it is a rectangular stub (the garden ring's two
-- tails, the promenade's two tips), and at an oblique join the square end puts a corner out past the
-- paving it joins (each side approach ran 4.5 studs south of the stage walk, a spike under its portal).
--
-- PathEnds[i].run is how far the strip runs past the path's last point (negative: stops short of it);
-- PathEndRuns[kind] is the same for Park.polyline. Judged against the other paving (the other paths'
-- segments, the plaza, the buildings with their forecourts, the pads):
--   nothing at the end point      stops dead on the last point
--   a narrower path ends there    the tip of the wider path: stops dead
--   a path as wide ends there     a bend between two paths: tucks as before
--   anything else                 tucks as before, but is drawn back until no corner of its end shows
--                                 outside the paving it joins (or as near as it can get)
export type Cut = { at: Vector2, half: number }
export type PlanStrip = { a: Vector2, b: Vector2 }
export type EndRuns = { start: number, finish: number }
export type Rect = { id: string, a: Vector2, b: Vector2, half: number } -- a-b grown sideways by half, ends flush
export type Disc = { id: string, centre: Vector2, radius: number }
export type PathEnd = {
	kind: string,
	atStart: boolean,
	point: Vector2, -- the path's own last point
	outward: Vector2, -- unit, away from the path
	width: number,
	run: number,
	host: string, -- the paving at the point ("" for none)
	why: string,
}

local TUCK = 0.15 -- of the width: how far a square end runs on under the paving it arrives at
local ON_PAVING = 0.05 -- a point this close to paving is on it
local END_SAMPLES = 10 -- points along an end line, corners included
local RUN_STEP = 0.05
local RUN_TOLERANCE = 0.05 -- a run this close to the best is as good: take the longest
local MAX_HIDDEN = 3 -- the most an end line may stand out and still count as joined
local EQUAL_WIDTH = 0.5

-- Studs from q to the rectangle of segment a-b grown sideways by half (0 on it).
function Layout.rectGap(q: Vector2, a: Vector2, b: Vector2, half: number): number
	local ab = b - a
	local length = ab.Magnitude
	if length < 1e-6 then
		return (q - a).Magnitude
	end
	local dir = ab / length
	local d = q - a
	local s = d:Dot(dir)
	local t = d:Dot(Vector2.new(-dir.Y, dir.X))
	return Vector2.new(math.max(-s, s - length, 0), math.max(math.abs(t) - half, 0)).Magnitude
end

-- Studs from q to the nearest of the shapes (0 on one), and which one.
function Layout.gapTo(q: Vector2, rects: { Rect }, discs: { Disc }): (number, string)
	local best, id = math.huge, ""
	for _, r in rects do
		local g = Layout.rectGap(q, r.a, r.b, r.half)
		if g < best then
			best, id = g, r.id
		end
	end
	for _, c in discs do
		local g = math.max(0, (q - c.centre).Magnitude - c.radius)
		if g < best then
			best, id = g, c.id
		end
	end
	return best, id
end

-- The paving that is not a path: the plaza, the buildings (the Garage and Stunt gate with their
-- forecourts) and the pads under the snack corners and the gazebo (Park.buildPads).
local structureRects: { Rect } = {}
local structureDiscs: { Disc } = { { id = "plaza", centre = Vector2.zero, radius = Data.park.plazaRadius } }
for _, b in (Data.park :: any).buildings do
	local f: Vector2 = b.facing.Unit
	if b.id == "Gazebo" then
		table.insert(structureDiscs, {
			id = "GazeboPad",
			centre = b.centre,
			radius = (math.max(b.width, b.depth) + 6) / 2 + 1,
		})
	elseif b.id == "SnackCornerEast" or b.id == "SnackCornerWest" then
		table.insert(structureRects, {
			id = b.id .. "Pad",
			a = b.centre - f * (b.depth / 2 + 1),
			b = b.centre + f * (b.depth / 2 + 1),
			half = b.width / 2 + 1,
		})
	else
		table.insert(structureRects, {
			id = b.id,
			a = b.centre - f * (b.depth / 2),
			b = b.centre + f * (b.depth / 2 + (FORECOURT[b.id] or 0)),
			half = b.width / 2,
		})
	end
end
Layout.StructureRects = structureRects
Layout.StructureDiscs = structureDiscs

local pathRects: { Rect } = {}
for _, path in Data.park.paths do
	for i = 1, #path.points - 1 do
		table.insert(pathRects, { id = path.kind, a = path.points[i], b = path.points[i + 1], half = path.width / 2 })
	end
end

local function endRun(path: typeof(Data.park.paths[1]), atStart: boolean): (number, string, string)
	local pts = path.points
	local point = if atStart then pts[1] else pts[#pts]
	local inner = if atStart then pts[2] else pts[#pts - 1]
	local d = (point - inner).Unit
	local n = Vector2.new(-d.Y, d.X)
	local w = path.width
	local tuck = w * TUCK
	-- only the paving within reach can matter
	local reach = w + 30
	local rects: { Rect } = {}
	for _, list in { pathRects, structureRects } do
		for _, r in list do
			if r.id ~= path.kind and Layout.rectGap(point, r.a, r.b, r.half) < reach then
				table.insert(rects, r)
			end
		end
	end
	local g0, host = Layout.gapTo(point, rects, structureDiscs)
	if g0 > ON_PAVING then
		return 0, "", "free"
	end
	local partner: typeof(path)? = nil
	for _, other in Data.park.paths do
		if other.kind ~= path.kind then
			local op = other.points
			if (op[1] - point).Magnitude <= ON_PAVING or (op[#op] - point).Magnitude <= ON_PAVING then
				partner = other
			end
		end
	end
	if partner then
		if partner.width < w - EQUAL_WIDTH then
			return 0, host, "tip"
		elseif math.abs(partner.width - w) <= EQUAL_WIDTH then
			return tuck, host, "bend"
		end
	end
	-- how far the end line at `run` stands out of the paving
	local function standOut(run: number): number
		local e = point + d * run
		local worst = 0
		for k = 0, END_SAMPLES do
			local q = e + n * (-w / 2 + w * k / END_SAMPLES)
			worst = math.max(worst, (Layout.gapTo(q, rects, structureDiscs)))
		end
		return worst
	end
	local runs: { number } = {}
	local outs: { number } = {}
	local best = math.huge
	local run = tuck
	while run >= -w do
		local out = standOut(run)
		table.insert(runs, run)
		table.insert(outs, out)
		best = math.min(best, out)
		run -= RUN_STEP
	end
	if best > MAX_HIDDEN then
		return 0, host, "unhidden"
	end
	for i, r in runs do
		if outs[i] <= best + RUN_TOLERANCE then
			return r, host, if i == 1 then "tucked" else "drawn back"
		end
	end
	return 0, host, "unhidden"
end

local pathEnds: { PathEnd } = {}
local pathEndRuns: { [string]: EndRuns } = {}
for _, path in Data.park.paths do
	local runs: EndRuns = { start = 0, finish = 0 }
	for _, atStart in { true, false } do
		local pts = path.points
		local point = if atStart then pts[1] else pts[#pts]
		local inner = if atStart then pts[2] else pts[#pts - 1]
		local run, host, why = endRun(path, atStart)
		if atStart then
			runs.start = run
		else
			runs.finish = run
		end
		table.insert(pathEnds, {
			kind = path.kind,
			atStart = atStart,
			point = point,
			outward = (point - inner).Unit,
			width = path.width,
			run = run,
			host = host,
			why = why,
		})
	end
	pathEndRuns[path.kind] = runs
end
Layout.PathEnds = pathEnds
Layout.PathEndRuns = pathEndRuns

-- How far a strip runs past a joint so the outer edges meet in a clean mitre (Adam's screenshots
-- 08 and 09: square strip ends left saw-tooth notches at every bend).
local function mitre(width: number, u: Vector2, v: Vector2): number
	local cosT = math.clamp(u:Dot(v), -1, 1)
	return math.min(width / 2 * math.tan(math.acos(cosT) / 2) + 0.02, width)
end

-- The strips along a polyline as plan segments a to b; `cuts` leave gaps (where a bridge deck crosses
-- open water). A joint gets its mitre. A path's free end runs on by ends.start / ends.finish
-- (PathEndRuns), or by 15 % of the width without them; an end at a bridge cut stops exactly at the deck.
function Layout.stripsAlong(points: { Vector2 }, width: number, cuts: { Cut }?, ends: EndRuns?): { PlanStrip }
	local out: { PlanStrip } = {}
	for i = 1, #points - 1 do
		local a, b = points[i], points[i + 1]
		local length = (b - a).Magnitude
		local dir = (b - a) / length
		-- pieces of [0, length] that stay after the cuts
		local pieces = { { 0, length } }
		for _, cut in cuts or {} do
			local s = (cut.at - a):Dot(dir)
			local off = math.abs((cut.at - a):Dot(Vector2.new(-dir.Y, dir.X)))
			if off < 3 then
				local kept = {}
				for _, piece in pieces do
					local c0, c1 = s - cut.half, s + cut.half
					if c1 <= piece[1] or c0 >= piece[2] then
						table.insert(kept, piece)
					else
						if c0 > piece[1] then
							table.insert(kept, { piece[1], c0 })
						end
						if c1 < piece[2] then
							table.insert(kept, { c1, piece[2] })
						end
					end
				end
				pieces = kept
			end
		end
		local before = if i > 1 then mitre(width, (a - points[i - 1]).Unit, dir) elseif ends then ends.start else width * 0.15
		local after = if i < #points - 1
			then mitre(width, dir, (points[i + 2] - b).Unit)
			elseif ends then ends.finish
			else width * 0.15
		for _, piece in pieces do
			if piece[2] - piece[1] > 0.05 then
				local s0 = if piece[1] <= 0 then -before else piece[1]
				local s1 = if piece[2] >= length then length + after else piece[2]
				if s1 - s0 > 0.05 then
					table.insert(out, { a = a + dir * s0, b = a + dir * s1 })
				end
			end
		end
	end
	return out
end

-- Reservations by id (plot frame polygons).
export type Reservation = typeof(Data.reservations[1])
local byId: { [string]: Reservation } = {}
for _, r in Data.reservations do
	byId[r.id] = r
end
function Layout.reservation(id: string): Reservation
	local r = byId[id]
	assert(r, "no reservation " .. id)
	return r
end

-- Axis-aligned bounds of a plot-frame polygon: x0, u0, x1, u1.
function Layout.bounds(poly: { Vector2 }): (number, number, number, number)
	local x0, u0, x1, u1 = math.huge, math.huge, -math.huge, -math.huge
	for _, p in poly do
		x0, x1 = math.min(x0, p.X), math.max(x1, p.X)
		u0, u1 = math.min(u0, p.Y), math.max(u1, p.Y)
	end
	return x0, u0, x1, u1
end

-- Paddock: row A 7 bays nearest the park, a 10-stud aisle, row B 8 bays; bays 9 x 16.
local r0 = plot.entranceRadius
Layout.Paddock = { bayWidth = 9, bayDepth = 16, rowA = 7, rowB = 8 }
Layout.RowA = { r0 + 16, r0 + 32 }
Layout.Aisle = { r0 + 32, r0 + 42 }
Layout.RowB = { r0 + 42, r0 + 58 }
Layout.AisleMidU = r0 + 37

export type Bay = { index: number, row: string, x: number, u: number, initial: boolean, facing: number }
local function centreOut(count: number): { number }
	local offsets = {}
	for i = 1, count do
		table.insert(offsets, i - (count + 1) / 2)
	end
	table.sort(offsets, function(a, b)
		if math.abs(a) ~= math.abs(b) then
			return math.abs(a) < math.abs(b)
		end
		return a < b
	end)
	return offsets
end
local bays: { Bay } = {}
-- cars back in from the aisle, so row A faces the park (-u) and row B faces the oval (+u)
for _, k in centreOut(Layout.Paddock.rowA) do
	table.insert(bays, { index = 0, row = "A", x = k * 9, u = r0 + 24, initial = false, facing = -1 })
end
for _, k in centreOut(Layout.Paddock.rowB) do
	table.insert(bays, { index = 0, row = "B", x = k * 9, u = r0 + 50, initial = false, facing = 1 })
end
for i, bay in bays do
	bay.index = i
	bay.initial = i <= 3
end
Layout.Bays = bays

-- Pit lanes (plot frame, ordered in the direction cars drive): the way-points of the road network's
-- lanes (Shared/Island/Speedway/RoadNet draws them, per client, with the track). Out leaves the aisle's
-- right end for the right straight; In leaves the left straight for the aisle's left end.
local laneV = plot.outerClearance + 5.5
Layout.PitOut = {
	Vector2.new(33, Layout.AisleMidU),
	Vector2.new(36, Layout.AisleMidU),
	Vector2.new(43.07, Layout.AisleMidU + 2.93),
	Vector2.new(46, Layout.AisleMidU + 10),
	Vector2.new(46, 300),
	Vector2.new(laneV - 2.75, 317.5),
	Vector2.new(laneV, 335),
	Vector2.new(laneV, 345),
	Vector2.new(44.75, 375),
	Vector2.new(38, 405),
}
Layout.PitIn = table.create(#Layout.PitOut)
for i = #Layout.PitOut, 1, -1 do
	local p = Layout.PitOut[i]
	table.insert(Layout.PitIn, Vector2.new(-p.X, p.Y))
end
Layout.PitLaneWidth = 10

return Layout
