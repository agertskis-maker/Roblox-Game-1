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

-- Pit lanes (plot frame, ordered in the direction cars drive). Out leaves the aisle's right end
-- for the right straight; In leaves the left straight for the aisle's left end.
local uF = plot.frontEnd
local laneV = plot.outerClearance + 5.5
Layout.PitOut = {
	Vector2.new(33, Layout.AisleMidU),
	Vector2.new(31, r0 + 58),
	Vector2.new(laneV, uF + 3),
	Vector2.new(laneV, uS - 1),
	Vector2.new(R + 5, uS + 14),
}
Layout.PitIn = {
	Vector2.new(-R - 5, uS + 14),
	Vector2.new(-laneV, uS - 1),
	Vector2.new(-laneV, uF + 3),
	Vector2.new(-31, r0 + 58),
	Vector2.new(-33, Layout.AisleMidU),
}
Layout.PitLaneWidth = 9
-- The barrier opens where the pit lanes join the straights.
function Layout.inPitGap(p: Vector2): boolean
	return math.abs(p.X) > R + 5 and p.Y > uS - 2 and p.Y < uS + 17
end

return Layout
