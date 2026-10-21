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
