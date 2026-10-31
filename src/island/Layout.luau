--!strict
-- Island layout, revision 2: eight plots, track first (Lane 3, build-time data).
--
-- Pure geometry, no instances. Every number here is the measured plan in
-- vault/design/island-base.md; the build recipes and the layout checks read
-- them from this one place. Units are studs.
--
-- Frames:
--   Plaza frame: x east, y north, origin at the island centre. Bearings are
--   clockwise from north. Roblox world: X = x, Z = -y (north is -Z).
--   Plot frame: x to the right when facing outward, u outward along the plot's
--   centre line, origin at the island centre.

local Layout = {}

Layout.PlotCount = 8 -- the only plot count; written to Island.PlotCount (decision 0011)
Layout.ContractVersion = "0-draft"
Layout.LayoutVersion = "rev2-stageA"
Layout.SurfaceY = 0

Layout.Car = { length = 12.5, width = 5.7, height = 4.7 }

Layout.Plaza = {
	plazaRadius = 52,
	courtRadius = 16,
	promenadeOuter = 62,
	gateRadius = 62,
	gateHalfWidth = 7,
	spawnU = 66,
}

Layout.Track = {
	width = 16,
	barrier = 1,
	curb = 1,
	margin = 2,
	rayClear = 2.5,
	radii = { hairpin = 35, back = 30, sweeper = 140 },
	sweeperRise = 6,
	outerLimit = 241.5,
	sampleCount = 86,
	lapSeconds = 15, -- outline 08, Tunable; lap speed is open for Lanes 1 and 2
}

Layout.Paddock = { bayWidth = 9, bayDepth = 16, aisle = 10, rowA = 7, rowB = 8, edgeMargin = 2 }

Layout.Bridge = {
	deckTop = 8,
	deckThickness = 1,
	width = 10,
	landingDepth = 3.5,
	landingWidth = 18,
	rampWidth = 5,
	rearRampRun = 20,
}

Layout.Garage = {
	roofInner = 28,
	roofOuter = 50,
	floorInner = 30,
	floorOuter = 48,
	wallRadius = 47,
	span = 55,
	doorHalfWidth = 5,
	passages = { -18, 18 },
	passageHalfWidth = 3,
	heroRadius = 20,
	flankRadius = 38,
	flanks = { -40, 40 },
	crest = 22,
	turntablePlatform = 17,
	turntableRim = 18,
}

Layout.Portals = {
	lineY = -38,
	xs = { 21, 0, -21 },
	names = { "Downtown", "DustyHighway", "SummitPass" },
	outerWidth = 17,
	opening = 11,
	depth = 5,
	height = 16,
}
Layout.Stunt = { bearing = 270, radius = 40, outerWidth = 28, opening = 18, depth = 6, height = 14 }
Layout.Boards = { bearings = { 78, 102 }, radius = 44, width = 9, depth = 4, height = 16 }

Layout.Shore =
	{ base = 266, lobe = 12, ripple = 3, rippleShift = 30, scenicBearing = 135, scenicExtra = 18, scenicWidth = 24 }
Layout.BuildRadius = 247.5
Layout.TerrainRegion = { half = 320, bottom = -16, top = 4, waterLevel = -3, seabed = -12 }

local HALF = 180 / Layout.PlotCount
local SIN_H, COS_H = math.sin(math.rad(HALF)), math.cos(math.rad(HALF))
Layout.HalfSectorDeg = HALF

export type Sample = { position: Vector2, tangent: Vector2, s: number }
export type Segment = {
	kind: "arc" | "line",
	s0: number,
	length: number,
	from: Vector2,
	to: Vector2,
	center: Vector2,
	radius: number,
	a0: number,
	sweep: number,
}
export type Corner = { radius: number, sweep: number, t1: Vector2, t2: Vector2, center: Vector2 }
export type Path = { segments: { Segment }, corners: { Corner }, length: number }

local function unit(v: Vector2): Vector2
	return v / v.Magnitude
end

-- Fillets a closed polygon with one radius per vertex; the result is a loop of arcs and straights.
local function fillet(vertices: { Vector2 }, radii: { number }): Path
	local n = #vertices
	local corners: { Corner } = {}
	for i = 1, n do
		local p = vertices[i]
		local a = vertices[(i - 2) % n + 1]
		local b = vertices[i % n + 1]
		local d1, d2 = unit(p - a), unit(b - p)
		local sweep = math.atan2(d1.X * d2.Y - d1.Y * d2.X, d1:Dot(d2))
		local r = radii[i]
		local t = r * math.tan(math.abs(sweep) / 2)
		local t1 = p - d1 * t
		local sign = if sweep >= 0 then 1 else -1
		local center = t1 + Vector2.new(-d1.Y, d1.X) * r * sign
		corners[i] = { radius = r, sweep = sweep, t1 = t1, t2 = p + d2 * t, center = center }
	end
	local segments: { Segment } = {}
	local s = 0
	for i = 1, n do
		local c = corners[i]
		local a0 = math.atan2(c.t1.Y - c.center.Y, c.t1.X - c.center.X)
		local arcLength = c.radius * math.abs(c.sweep)
		table.insert(segments, {
			kind = "arc",
			s0 = s,
			length = arcLength,
			from = c.t1,
			to = c.t2,
			center = c.center,
			radius = c.radius,
			a0 = a0,
			sweep = c.sweep,
		})
		s += arcLength
		local nextCorner = corners[i % n + 1]
		local lineLength = (nextCorner.t1 - c.t2).Magnitude
		table.insert(segments, {
			kind = "line",
			s0 = s,
			length = lineLength,
			from = c.t2,
			to = nextCorner.t1,
			center = Vector2.zero,
			radius = 0,
			a0 = 0,
			sweep = 0,
		})
		s += lineLength
	end
	return { segments = segments, corners = corners, length = s }
end

-- Position and unit tangent at distance s along the path (wraps around the loop).
function Layout.pointAt(path: Path, s: number): (Vector2, Vector2)
	s = s % path.length
	for _, seg in path.segments do
		if s <= seg.s0 + seg.length + 1e-9 then
			local ds = s - seg.s0
			if seg.kind == "line" then
				local dir = if seg.length > 0 then unit(seg.to - seg.from) else Vector2.new(1, 0)
				return seg.from + dir * ds, dir
			end
			local sign = if seg.sweep >= 0 then 1 else -1
			local a = seg.a0 + sign * ds / seg.radius
			local pos = seg.center + Vector2.new(math.cos(a), math.sin(a)) * seg.radius
			return pos, Vector2.new(-math.sin(a), math.cos(a)) * sign
		end
	end
	local last = path.segments[#path.segments]
	return last.to, unit(last.to - last.from)
end

-- Outward (right-of-travel) normal for a counter-clockwise loop.
function Layout.outward(tangent: Vector2): Vector2
	return Vector2.new(tangent.Y, -tangent.X)
end

function Layout.rayClear(p: Vector2): number
	return math.min(p.Y * SIN_H - p.X * COS_H, p.Y * SIN_H + p.X * COS_H)
end

local track = Layout.Track
local halfWidth = track.width / 2
Layout.OuterOffset = halfWidth + track.barrier + track.margin -- 11
Layout.InnerOffset = halfWidth + track.curb + track.margin -- 11
local dSide = track.rayClear + Layout.OuterOffset

local function sideX(u: number): number
	return (u * SIN_H - dSide) / COS_H
end

local function makeTrack(uK: number): Path
	local uB = uK - track.sweeperRise
	local apexU = dSide / SIN_H
	return fillet({
		Vector2.new(0, apexU),
		Vector2.new(sideX(uB), uB),
		Vector2.new(0, uK),
		Vector2.new(-sideX(uB), uB),
	}, { track.radii.hairpin, track.radii.back, track.radii.sweeper, track.radii.back })
end

local function offsetPoints(path: Path, offset: number, step: number): { Vector2 }
	local points = {}
	local count = math.ceil(path.length / step)
	for i = 0, count - 1 do
		local p, t = Layout.pointAt(path, i * path.length / count)
		table.insert(points, p + Layout.outward(t) * offset)
	end
	return points
end

local function maxRadius(points: { Vector2 }): number
	local r = 0
	for _, p in points do
		r = math.max(r, p.Magnitude)
	end
	return r
end

-- Back apex as far out as the outer limit allows.
local lo, hi = 150, 260
for _ = 1, 50 do
	local mid = (lo + hi) / 2
	if maxRadius(offsetPoints(makeTrack(mid), Layout.OuterOffset, 1)) > track.outerLimit then
		hi = mid
	else
		lo = mid
	end
end
Layout.Path = makeTrack(lo)
Layout.BackApexU = lo
Layout.MinTurnRadius = math.min(track.radii.hairpin, track.radii.back, track.radii.sweeper)

local outerPoints = offsetPoints(Layout.Path, Layout.OuterOffset, 1)
local innerPoints = offsetPoints(Layout.Path, -Layout.InnerOffset, 1)
Layout.OuterEdge = outerPoints
Layout.InnerEdge = innerPoints

local frontTip, infieldFront, infieldBack = math.huge, math.huge, -math.huge
for _, p in outerPoints do
	frontTip = math.min(frontTip, p.Y)
end
for _, p in innerPoints do
	infieldFront = math.min(infieldFront, p.Y)
	infieldBack = math.max(infieldBack, p.Y)
end
Layout.FrontTipU = frontTip
Layout.InfieldFrontU = infieldFront
Layout.InfieldBackU = infieldBack

-- Half width of the infield (inside the inner clearance edge) at a given u.
function Layout.infieldHalfWidthAt(u: number): number
	local best = 0
	local n = #innerPoints
	for i = 1, n do
		local a, b = innerPoints[i], innerPoints[i % n + 1]
		if (a.Y - u) * (b.Y - u) <= 0 and a.Y ~= b.Y then
			best = math.max(best, a.X + (u - a.Y) * (b.X - a.X) / (b.Y - a.Y))
		end
	end
	return best
end

-- Start / finish: two thirds along the left side straight (the last straight), just before the hairpin.
local lastLine = Layout.Path.segments[#Layout.Path.segments]
Layout.StartS = lastLine.s0 + lastLine.length * 2 / 3
Layout.RightStraight = Layout.Path.segments[2]
Layout.LeftStraight = lastLine

-- Paddock in the infield, as far out as it fits.
local paddock = Layout.Paddock
local halfA = paddock.rowA * paddock.bayWidth / 2
local halfB = paddock.rowB * paddock.bayWidth / 2
local function fitsRow(u0: number, u1: number, half: number): boolean
	local u = u0
	while u <= u1 + 1e-9 do
		if Layout.infieldHalfWidthAt(u) < half + paddock.edgeMargin then
			return false
		end
		u += 0.5
	end
	return true
end
local padEnd = infieldBack
while
	not (
		fitsRow(padEnd - paddock.bayDepth, padEnd, halfB)
		and fitsRow(padEnd - 2 * paddock.bayDepth - paddock.aisle, padEnd - paddock.bayDepth - paddock.aisle, halfA)
	)
do
	padEnd -= 0.5
end
Layout.RowB = { padEnd - paddock.bayDepth, padEnd }
Layout.Aisle = { padEnd - paddock.bayDepth - paddock.aisle, padEnd - paddock.bayDepth }
Layout.RowA = { Layout.Aisle[1] - paddock.bayDepth, Layout.Aisle[1] }
Layout.AisleMidU = (Layout.Aisle[1] + Layout.Aisle[2]) / 2
Layout.AisleHalfSpan = Layout.infieldHalfWidthAt(Layout.AisleMidU) - 1

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
for _, k in centreOut(paddock.rowA) do
	-- row A backs in from the aisle, so a parked car faces the bridge (-u)
	table.insert(bays, {
		index = 0,
		row = "A",
		x = k * paddock.bayWidth,
		u = (Layout.RowA[1] + Layout.RowA[2]) / 2,
		initial = false,
		facing = -1,
	})
end
for _, k in centreOut(paddock.rowB) do
	table.insert(bays, {
		index = 0,
		row = "B",
		x = k * paddock.bayWidth,
		u = (Layout.RowB[1] + Layout.RowB[2]) / 2,
		initial = false,
		facing = 1,
	})
end
for i, bay in bays do
	bay.index = i
	bay.initial = i <= 3
end
Layout.Bays = bays

-- Viewing bridge over the hairpin.
local bridge = Layout.Bridge
Layout.DeckU = { frontTip - 2, infieldFront + 2 }
Layout.LandingU = { frontTip - 2 - bridge.landingDepth, frontTip - 2 }
Layout.FrontRamps = {
	{ from = Vector2.new(-21, 64.5), to = Vector2.new(-6.5, Layout.LandingU[1] + bridge.landingDepth / 2) },
	{ from = Vector2.new(21, 64.5), to = Vector2.new(6.5, Layout.LandingU[1] + bridge.landingDepth / 2) },
}
Layout.RearRamp = { from = Vector2.new(0, Layout.DeckU[2] + bridge.rearRampRun), to = Vector2.new(0, Layout.DeckU[2]) }

-- Space kept for later tiers (feasibility only).
local reserveU0 = Layout.DeckU[2] + bridge.rearRampRun + 2
local reserveU1 = Layout.RowA[1] - 2
Layout.LoopReserve = { centerU = (reserveU0 + reserveU1) / 2, width = 34, depth = 38, spanU = { reserveU0, reserveU1 } }
Layout.RampReserve = { s0 = Layout.RightStraight.s0 + 3, length = 72, width = 18 }

-- Pit lanes, plot frame: in from the right straight to the aisle's right end, out from its left end.
do
	local am = Layout.AisleMidU
	local span = Layout.AisleHalfSpan
	local function onStraight(seg: Segment, u: number, inset: number): Vector2
		local dir = unit(seg.to - seg.from)
		local t = (u - seg.from.Y) / dir.Y
		local p = seg.from + dir * t
		return p - Layout.outward(dir) * inset
	end
	Layout.PitIn = {
		onStraight(Layout.RightStraight, am - 34, 0),
		onStraight(Layout.RightStraight, am - 20, 6),
		Vector2.new(span + 3, am - 6),
		Vector2.new(span - 4, am),
	}
	Layout.PitOut = {
		Vector2.new(-span + 4, am),
		Vector2.new(-span - 3, am - 6),
		onStraight(Layout.LeftStraight, am - 20, 6),
		onStraight(Layout.LeftStraight, am - 34, 0),
	}
end

-- Plot bearing and frame conversions.
function Layout.plotBearing(index: number): number
	return (360 / Layout.PlotCount) * (index - 0.5)
end

function Layout.plazaToWorld(p: Vector2, y: number?): Vector3
	return Vector3.new(p.X, y or Layout.SurfaceY, -p.Y)
end

function Layout.plotToPlaza(bearingDeg: number, p: Vector2): Vector2
	local b = math.rad(bearingDeg)
	return Vector2.new(p.Y * math.sin(b) + p.X * math.cos(b), p.Y * math.cos(b) - p.X * math.sin(b))
end

function Layout.plotToWorld(bearingDeg: number, p: Vector2, y: number?): Vector3
	return Layout.plazaToWorld(Layout.plotToPlaza(bearingDeg, p), y)
end

function Layout.polar(bearingDeg: number, radius: number): Vector2
	local b = math.rad(bearingDeg)
	return Vector2.new(radius * math.sin(b), radius * math.cos(b))
end

function Layout.waterline(bearingDeg: number): number
	local shore = Layout.Shore
	local r = shore.base
		+ shore.lobe * math.cos(math.rad(Layout.PlotCount * (bearingDeg - HALF)))
		+ shore.ripple * math.cos(math.rad(2 * Layout.PlotCount * bearingDeg + shore.rippleShift))
	local dd = ((bearingDeg - shore.scenicBearing + 540) % 360) - 180
	return r + shore.scenicExtra * math.exp(-(dd * dd) / (2 * (shore.scenicWidth / 2) ^ 2))
end

return Layout
