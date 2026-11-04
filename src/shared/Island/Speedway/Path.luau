--!strict
-- Speedway lap paths by level (Lane 3, presentation only). The lap is one closed path made of
-- straight lines, flat arcs and (level 12) a vertical loop, with a height profile (ramps) and a
-- bank profile (tilted turns). Lineup cars are placed by distance along the path, so a lap takes
-- the same time at every level: a longer path only means a faster visual car. Nothing here pays,
-- times or decides anything; Lap Pay stays a server timer (outline section 08).
--
-- Frames. Plot frame as in Hub/Layout: x to the right facing outward, u outward from the fountain.
-- "Local" positions below are bearing-0 world coordinates (X = x, Y = height, Z = -u); a plot's
-- world frame is Path.plotFrame(bearing) * local. Every path starts at the start / finish line on
-- the left straight (Layout StartS, cars heading toward the park) at distance 0, like the
-- Speedway markers (Hub/Markers Path001).
--
-- Path families (levels from Ladder):
--   oval     levels 1 to 9: the island's stadium oval (Layout.Segments), flat; banked turns at 9.
--   raised   levels 10 and 11: the near half and the right straight stay on the ground; the far
--            turn climbs gently as it turns, up to the raised deck, and the lap comes back down the
--            main (left) straight on a 1 in 6 ramp that lands 6 studs before the finish line. No
--            spiral and no track over track (Adam, 2026-10-28: "make the ramps a little simpler").
--            Level 11 adds a low hump on the ground right straight (no gap, no flying).
--   loop     level 12: as raised, with a teardrop loop on the ground right straight. The car enters
--            on the road's own line, the loop carries it one lane to the left (toward the infield),
--            and one S-bend brings it back to the road's line before the far turn.

local Path = {}

-- Layout numbers (Hub/Layout, HubData; repeated here because Hub/Layout lives in ServerStorage).
-- Path.check() in the island preview compares them with Layout.
Path.TurnRadius = 35
Path.Straight = 103.594
Path.StraightsStart = 389.187
Path.HalfWidth = 8
Path.TrackTop = 0.2 -- the ground track's top surface above the island surface (Plot recipe)
Path.StartU = Path.StraightsStart + 0.25 * Path.Straight

-- Raised section (levels 10 to 12). Tunable, all visual.
Path.DeckHeight = 12 -- road top of the raised deck above the ground track
Path.DeckHalfWidth = 8 -- the raised road is as wide as the ground road (16)
Path.DescentLandU = 421 -- the descent reaches the ground here, 6 before the finish line
-- degrees, into the turn. The near turn stays flat at every level: the pit lanes join the track on it,
-- and a flat surface is what lets the junction be one flush polygon (Round 2, N1).
Path.Bank = { Near = 0, Ground = 14, Raised = 14 }
Path.BankEase = 12 -- studs over which a bank fades in or out at each turn end
-- Loop (level 12, Round 2 N2). A teardrop, built from a curvature schedule: the curve starts straight,
-- eases into a broad lower bend (Radius LowRadius) and tightens toward the top (Radius TopRadius), then
-- mirrors, so the height ends where it began and both ends are tangent to the road. HalfLength is the
-- plane length of one half. Offset: the sideways shift over the loop, entry lane to exit lane, one
-- quintic from ShiftFrom to ShiftTo of the way round, so both ends carry no sideways kink and the two
-- ribbons are already a full lane apart where they pass each other. The ribbon is the road's own 16
-- wide where it leaves the ground and 14 up in the loop (14 + 2 of gap = the 16 offset). ExitBend: the
-- S-bend length from the loop's exit back to the road's line; it equals 3 x the 16 of extra width.
Path.Loop = {
	LowRadius = 30,
	TopRadius = 14,
	EaseIn = 14,
	HalfLength = 70,
	Offset = 16,
	ShiftFrom = 0.12,
	ShiftTo = 0.88,
	RoadWidth = 16,
	Width = 14,
	ExitBend = 48,
}
-- Hump (level 11 only): a low eased bump on the ground right straight, after the pit lane join.
Path.Hump = { U = 408, Length = 12, Height = 1 }

export type Segment = {
	kind: "line" | "arc" | "loop",
	s0: number,
	length: number,
	-- plan (x, u) start point and unit heading
	p0: Vector2,
	d0: Vector2,
	-- arcs: signed turn (+ left), radius, centre
	turn: number,
	radius: number,
	centre: Vector2,
}

-- linear = true: straight interpolation from this knot to the next (ramps, flight), else eased
export type Knot = { s: number, v: number, linear: boolean? }

export type LapPath = {
	family: string,
	length: number,
	segments: { Segment },
	heights: { Knot }, -- piecewise linear, eased at each knot
	banks: { Knot }, -- degrees, piecewise linear
	-- distance ranges with a feature (for builders): spiral, raised, descent, loop, jump
	marks: { [string]: { number } },
}

local function rot(v: Vector2, a: number): Vector2
	local c, s = math.cos(a), math.sin(a)
	return Vector2.new(v.X * c - v.Y * s, v.X * s + v.Y * c)
end

-- Turtle that lays down tangent-continuous segments.
type Turtle = { p: Vector2, d: Vector2, s: number, segments: { Segment } }

local function turtle(p: Vector2, d: Vector2): Turtle
	return { p = p, d = d.Unit, s = 0, segments = {} }
end

local function line(t: Turtle, length: number)
	table.insert(t.segments, {
		kind = "line",
		s0 = t.s,
		length = length,
		p0 = t.p,
		d0 = t.d,
		turn = 0,
		radius = 0,
		centre = Vector2.zero,
	})
	t.p += t.d * length
	t.s += length
end

-- A flat arc of `radius` turning `turnDeg` (positive = left).
local function arc(t: Turtle, radius: number, turnDeg: number)
	local turn = math.rad(turnDeg)
	local sign = if turn >= 0 then 1 else -1
	local left = Vector2.new(-t.d.Y, t.d.X)
	local centre = t.p + left * radius * sign
	table.insert(t.segments, {
		kind = "arc",
		s0 = t.s,
		length = radius * math.abs(turn),
		p0 = t.p,
		d0 = t.d,
		turn = turn,
		radius = radius,
		centre = centre,
	})
	t.p = centre + rot(t.p - centre, turn)
	t.d = rot(t.d, turn).Unit
	t.s += radius * math.abs(turn)
end

-- An S-bend that moves the line `shift` studs sideways (+ left) over `length` forward.
local function sbend(t: Turtle, shift: number, length: number)
	local half = math.atan(math.abs(shift) / length) -- half of the arc angle phi
	local phi = 2 * half
	local radius = length / (2 * math.sin(phi))
	local sign = if shift >= 0 then 1 else -1
	arc(t, radius, sign * math.deg(phi))
	arc(t, radius, -sign * math.deg(phi))
end

-- The teardrop, tabulated once at a fixed plane step: forward f, height h and turning angle th at each
-- plane distance, then the 3D length after the sideways shift, so a distance along the car's path finds
-- its place by binary search. Uniform plane steps are not uniform 3D distance.
local function smooth(a: number, b: number): number
	local t = math.clamp(a / b, 0, 1)
	return t * t * (3 - 2 * t)
end

local function quintic(t: number): (number, number)
	t = math.clamp(t, 0, 1)
	return t * t * t * (t * (t * 6 - 15) + 10), 30 * t * t * (t - 1) * (t - 1)
end

type LoopTable = {
	step: number,
	f: { number },
	h: { number },
	th: { number },
	side: { number },
	sideSlope: { number },
	len: { number },
	length: number,
	forward: number,
}

local LOOP: LoopTable = (function()
	local lo = Path.Loop
	local step = 0.1
	local half = math.floor(lo.HalfLength / step + 0.5)
	local n = 2 * half
	local kL, kT = 1 / lo.LowRadius, 1 / lo.TopRadius
	local function curvature(s: number): number
		return kL * smooth(s, lo.EaseIn) + (kT - kL) * smooth(s - lo.EaseIn, lo.HalfLength - lo.EaseIn)
	end
	-- scale the schedule so the half turn is exactly 180 degrees (midpoint rule)
	local total = 0
	for i = 1, half do
		total += curvature((i - 0.5) * step) * step
	end
	local scale = math.pi / total
	local kappa = table.create(n, 0)
	for i = 1, half do
		local k = curvature((i - 0.5) * step) * scale
		kappa[i] = k
		kappa[n + 1 - i] = k
	end
	local f, h, th, side, slope, len = { 0 }, { 0 }, { 0 }, { 0 }, { 0 }, { 0 }
	local span = lo.ShiftTo - lo.ShiftFrom
	local plane = n * step
	for i = 1, n do
		local mid = th[i] + kappa[i] * step / 2
		th[i + 1] = th[i] + kappa[i] * step
		f[i + 1] = f[i] + math.cos(mid) * step
		h[i + 1] = h[i] + math.sin(mid) * step
		local q, dq = quintic((i / n - lo.ShiftFrom) / span)
		side[i + 1] = lo.Offset * q
		slope[i + 1] = lo.Offset * dq / (span * plane)
		len[i + 1] = len[i] + math.sqrt((f[i + 1] - f[i]) ^ 2 + (h[i + 1] - h[i]) ^ 2 + (side[i + 1] - side[i]) ^ 2)
	end
	return {
		step = step,
		f = f,
		h = h,
		th = th,
		side = side,
		sideSlope = slope,
		len = len,
		length = len[n + 1],
		forward = f[n + 1],
	}
end)()

Path.LoopLength = LOOP.length
Path.LoopForward = LOOP.forward

local function loopIndex(ds: number): (number, number)
	local len = LOOP.len
	local lo, hi = 1, #len - 1
	while lo < hi do
		local mid = (lo + hi + 1) // 2
		if len[mid] <= ds then
			lo = mid
		else
			hi = mid - 1
		end
	end
	local span = len[lo + 1] - len[lo]
	return lo, if span > 1e-9 then math.clamp((ds - len[lo]) / span, 0, 1) else 0
end

-- Height of the road surface of the loop at `ds` along it, and the curvature (for the car's lift).
function Path.loopShape(ds: number): (number, number, number)
	local i, a = loopIndex(ds)
	local height = LOOP.h[i] + (LOOP.h[i + 1] - LOOP.h[i]) * a
	local kappa = (LOOP.th[i + 1] - LOOP.th[i]) / LOOP.step
	return height, kappa, LOOP.side[i] + (LOOP.side[i + 1] - LOOP.side[i]) * a
end

local function loop(t: Turtle)
	table.insert(t.segments, {
		kind = "loop",
		s0 = t.s,
		length = LOOP.length,
		p0 = t.p,
		d0 = t.d,
		turn = 0,
		radius = 0,
		centre = Vector2.zero,
	})
	-- the loop ends one lane to the left of travel, heading the same way
	local left = Vector2.new(-t.d.Y, t.d.X)
	t.p += t.d * LOOP.forward + left * Path.Loop.Offset
	t.s += LOOP.length
end

local R = Path.TurnRadius
local L = Path.Straight
local uS = Path.StraightsStart
local START = Vector2.new(-R, Path.StartU)
local DOWN = Vector2.new(0, -1)

local function oval(): Turtle
	local t = turtle(START, DOWN)
	line(t, Path.StartU - uS)
	arc(t, R, 180)
	line(t, L)
	arc(t, R, 180)
	line(t, (uS + L) - Path.StartU)
	return t
end

-- Bank knots for a flat-arc turn between distances a and b at `deg`, eased in and out. `inside` starts
-- the ease at the turn itself instead of before it (the raised family: the straight before it is flat).
local function bankTurn(knots: { Knot }, a: number, b: number, deg: number, inside: boolean?)
	if deg == 0 then
		return
	end
	local e = Path.BankEase
	table.insert(knots, { s = if inside then a else a - e, v = 0 })
	table.insert(knots, { s = if inside then a + 2 * e else a + e, v = deg })
	table.insert(knots, { s = b - e, v = deg })
	table.insert(knots, { s = b + e, v = 0 })
end

local function build(level: number): LapPath
	if level < 10 then
		local t = oval()
		local banks: { Knot } = {}
		if level >= 9 then
			local near = true
			for _, seg in t.segments do
				if seg.kind == "arc" then
					bankTurn(banks, seg.s0, seg.s0 + seg.length, if near then Path.Bank.Near else Path.Bank.Ground)
					near = false
				end
			end
		end
		return {
			family = "oval",
			length = t.s,
			segments = t.segments,
			heights = {},
			banks = banks,
			marks = {},
		}
	end
	local t = turtle(START, DOWN)
	local marks: { [string]: { number } } = {}
	local heights: { Knot } = {}
	local banks: { Knot } = {}
	local H = Path.DeckHeight
	line(t, Path.StartU - uS)
	local nearA = t.s
	arc(t, R, 180)
	bankTurn(banks, nearA, t.s, Path.Bank.Near)
	-- the ground right straight (the hump at level 11 and the loop at level 12 sit on it)
	local rightA = t.s
	local farStartU = uS + L
	if level == 11 then
		local h = Path.Hump
		local foot = rightA + (h.U - uS)
		table.insert(heights, { s = foot, v = 0 })
		table.insert(heights, { s = foot + h.Length / 2, v = h.Height })
		table.insert(heights, { s = foot + h.Length, v = 0 })
		marks.hump = { foot, foot + h.Length }
	end
	if level >= 12 then
		local lo = Path.Loop
		line(t, farStartU - lo.ExitBend - LOOP.forward - uS)
		local loopA = t.s
		loop(t)
		marks.loop = { loopA, t.s }
		-- the loop exits one lane to the left: one S-bend back right onto the road's line
		sbend(t, -lo.Offset, lo.ExitBend)
		marks.exitBend = { marks.loop[2], t.s }
	else
		line(t, L)
	end
	marks.groundRight = { rightA, t.s }
	-- the far turn climbs from the ground to the deck as it turns (eased at both ends)
	local farA = t.s
	arc(t, R, 180)
	bankTurn(banks, farA, t.s, Path.Bank.Raised, true)
	table.insert(heights, { s = farA, v = 0 })
	table.insert(heights, { s = t.s, v = H })
	marks.farCurve = { farA, t.s }
	-- the descent down the main straight, landing 6 before the finish line
	local descentA = t.s
	local fall = farStartU - Path.DescentLandU
	line(t, fall)
	table.insert(heights, { s = descentA, v = H })
	table.insert(heights, { s = t.s, v = 0 })
	marks.descent = { descentA, t.s }
	line(t, Path.DescentLandU - Path.StartU)
	-- a closed lap: the turtle is back at the start line
	assert((t.p - START).Magnitude < 0.05, "Speedway path does not close")
	return {
		family = if level >= 12 then "loop" else "raised",
		length = t.s,
		segments = t.segments,
		heights = heights,
		banks = banks,
		marks = marks,
	}
end

local cache: { [number]: LapPath } = {}

-- The lap path used at `level` (1 to 12; levels above 12 use the level 12 path).
function Path.forLevel(level: number): LapPath
	local key = math.clamp(math.floor(level), 1, 12)
	local p = cache[key]
	if not p then
		p = build(key)
		cache[key] = p
	end
	return p
end

-- Smoothstep between knots so ramps start and end gently (no kink at the joins).
local function profile(knots: { Knot }, s: number): number
	local n = #knots
	if n == 0 then
		return 0
	end
	if s <= knots[1].s then
		return knots[1].v
	end
	for i = 1, n - 1 do
		local a, b = knots[i], knots[i + 1]
		if s <= b.s then
			local span = b.s - a.s
			if span <= 1e-6 then
				return b.v
			end
			local f = (s - a.s) / span
			if not a.linear then
				f = f * f * (3 - 2 * f)
			end
			return a.v + (b.v - a.v) * f
		end
	end
	return knots[n].v
end

local function findSegment(path: LapPath, s: number): Segment
	local segs = path.segments
	local lo, hi = 1, #segs
	while lo < hi do
		local mid = (lo + hi + 1) // 2
		if segs[mid].s0 <= s then
			lo = mid
		else
			hi = mid - 1
		end
	end
	return segs[lo]
end

-- Plan position and heading on a flat segment.
local function planAt(seg: Segment, ds: number): (Vector2, Vector2)
	if seg.kind == "arc" then
		local a = ds / seg.radius * (if seg.turn >= 0 then 1 else -1)
		return seg.centre + rot(seg.p0 - seg.centre, a), rot(seg.d0, a)
	end
	return seg.p0 + seg.d0 * ds, seg.d0
end

local function toLocal(p: Vector2, y: number): Vector3
	return Vector3.new(p.X, y, -p.Y)
end

-- Local position and an orthonormal frame (look along travel, up off the road) at distance s.
-- Returns position, look and up; the car's CFrame is CFrame.lookAt(pos, pos + look, up).
function Path.sample(path: LapPath, s: number): (Vector3, Vector3, Vector3)
	s = s % path.length
	local seg = findSegment(path, s)
	local ds = s - seg.s0
	local base = Path.TrackTop + profile(path.heights, s)
	if seg.kind == "loop" then
		-- the frame comes from the curve itself: the tangent, and the inward normal of the turn projected
		-- square to it. No fixed axis, so the car is upside down at the top and nothing flips.
		local i, a = loopIndex(ds)
		local function mix(list: { number }): number
			return list[i] + (list[i + 1] - list[i]) * a
		end
		local th = mix(LOOP.th)
		local fwd = toLocal(seg.d0, 0)
		local left = toLocal(Vector2.new(-seg.d0.Y, seg.d0.X), 0)
		local up = Vector3.yAxis
		local pos = toLocal(seg.p0, base) + fwd * mix(LOOP.f) + up * mix(LOOP.h) + left * mix(LOOP.side)
		local look = (fwd * math.cos(th) + up * math.sin(th) + left * mix(LOOP.sideSlope)).Unit
		local inward = up * math.cos(th) - fwd * math.sin(th)
		return pos, look, (inward - look * inward:Dot(look)).Unit
	end
	local p, d = planAt(seg, ds)
	-- slope from the height profile (central difference)
	local h0 = profile(path.heights, s - 0.5)
	local h1 = profile(path.heights, s + 0.5)
	local look = (toLocal(d, 0) + Vector3.yAxis * (h1 - h0)).Unit
	local bank = math.rad(profile(path.banks, s))
	-- a banked ground turn tilts about its inner edge (the inner edge stays on the ground), so the
	-- centre line rises; a raised deck tilts about its centre line (blended over the first 2 studs)
	local h = profile(path.heights, s)
	base += Path.HalfWidth * math.sin(math.abs(bank)) * math.max(0, 1 - h / 2)
	local right = look:Cross(Vector3.yAxis).Unit
	local up = right:Cross(look).Unit
	if bank ~= 0 then
		-- left turns lean left: the up vector tilts toward the turn centre (the car's left)
		up = (up * math.cos(bank) - right * math.sin(bank)).Unit
	end
	return toLocal(p, base), look, up
end

function Path.height(path: LapPath, s: number): number
	return profile(path.heights, s % path.length)
end

function Path.bank(path: LapPath, s: number): number
	return profile(path.banks, s % path.length)
end

-- The plot's frame: bearing-0 local coordinates to the world (Hub/Layout.plotToWorld).
function Path.plotFrame(bearingDeg: number): CFrame
	return CFrame.Angles(0, -math.rad(bearingDeg), 0)
end

-- Plan helpers for builders (plot frame).
function Path.planPoint(path: LapPath, s: number): (Vector2, Vector2)
	s = s % path.length
	local seg = findSegment(path, s)
	if seg.kind == "loop" then
		local pos, look = Path.sample(path, s)
		return Vector2.new(pos.X, -pos.Z), Vector2.new(look.X, -look.Z)
	end
	return planAt(seg, s - seg.s0)
end

-- Visual speed (studs per second) for a lap of `lapSeconds`.
function Path.speed(path: LapPath, lapSeconds: number): number
	return path.length / lapSeconds
end

-- Cars are placed by lap phase (0..1), so a level change keeps every car's phase and timing. On the
-- loop level a car slows a little up the loop and picks up speed coming down: the phase maps through
-- the lap's time table, and a whole lap still takes the same time (Lap Pay stays a server timer).
local TOP_SPEED = 0.85 -- of the lap's base speed at the top of the loop
local LOW_SPEED = 1.1 -- at its foot
local speedTable: { [LapPath]: { time: { number }, step: number } } = {}

local function loopSpeed(path: LapPath, s: number): number
	local m = path.marks.loop
	if not m or s < m[1] or s > m[2] then
		return 1
	end
	local height = Path.loopShape(s - m[1])
	local foot = smooth(s - m[1], 16) * smooth(m[2] - s, 16)
	local top = height / (2 * Path.Loop.TopRadius + 11)
	return 1 + foot * (LOW_SPEED - 1 + (TOP_SPEED - LOW_SPEED) * math.clamp(top, 0, 1))
end

function Path.distanceAt(path: LapPath, phase: number): number
	phase = phase % 1
	if not path.marks.loop then
		return phase * path.length
	end
	local tab = speedTable[path]
	if not tab then
		local step = 1
		local n = math.floor(path.length / step)
		local time = table.create(n + 2, 0)
		for i = 1, n do
			time[i + 1] = time[i] + step / loopSpeed(path, (i - 0.5) * step)
		end
		time[n + 2] = time[n + 1] + (path.length - n * step) / loopSpeed(path, path.length)
		tab = { time = time, step = step }
		speedTable[path] = tab
	end
	local time = tab.time
	local want = phase * time[#time]
	local lo, hi = 1, #time - 1
	while lo < hi do
		local mid = (lo + hi + 1) // 2
		if time[mid] <= want then
			lo = mid
		else
			hi = mid - 1
		end
	end
	local span = time[lo + 1] - time[lo]
	return math.min((lo - 1 + (want - time[lo]) / span) * tab.step, path.length)
end

-- How far a car's pivot rides off the road at distance s: a rigid car on a tight concave bend stands
-- on its axles, so its middle sits the chord's sag above the surface (wheelbase^2 / 8R).
function Path.carLift(path: LapPath, s: number, wheelbase: number): number
	local m = path.marks.loop
	if not m or s < m[1] or s > m[2] then
		return 0
	end
	local _, kappa = Path.loopShape(s - m[1])
	return wheelbase * wheelbase * kappa / 8
end

return Path
