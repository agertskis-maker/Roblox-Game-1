--!strict
-- STUNT CIRCUIT DATA PROPOSAL for Brian R (Lane 3, big round M17-02 and M17-02a). PURE DATA: no instances are made here, the
-- course recipe (StuntCourse) and the screens read the same numbers, so the scenery, the HUD and Brian's driving and
-- checkpoint logic can never disagree. Everything is a PROPOSAL and a visual pacing model, not a measured or approved
-- gameplay value. It does not prove that Brian R's fastest and slowest cars can finish in the target time, and nothing here
-- tunes a vehicle stat.
--
--   UNITS         studs. 1 stud = 0.28 m is PROVISIONAL and never shown as final.
--   ORIGIN        the middle of the start/finish line on the road surface (x 0, y 0, z 0).
--   AXES          forward at s = 0 is -Z (the run's route convention: travel toward -Z), right is +X, up is +Y.
--                 A point at lap distance s, lateral l (+ = right of travel) and height y is StuntData.frame(s, l, y).
--   LAP           a closed loop of 5,250 studs: 5 straight legs joined by four 76 x 76 stud corner pads (all left
--                 turns), start and finish on the same line. Nominal 75 s at 70 studs/s (PREVIEW speed).
--   ROAD          4 lanes x 17 studs = 68 studs drivable, plus a 4 stud shoulder each side = 76 total (the Downtown
--                 city width; a LABELLED PROPOSAL, match RunConfig where a lane metaphor applies).
--   VISUAL ONLY   every obstacle here has a look and, for the swinging arms, an IDLE animation. None collides, none has
--                 a rule. An idle animation is not working obstacle logic: timing, hit rules and effects are Brian R's.
--
-- Separate in this data: ART BOUNDS (what the scenery occupies) and PROPOSED HITBOXES (a starting guess for gameplay, never
-- built as a part). Nothing is built from the hitboxes.
--
--   StuntData.frame(s, lateral?, y?) -> CFrame      StuntData.legOf(s) -> Leg      StuntData.surfaceY(s) -> number?
--   StuntData.drivableWidth(s) -> number            StuntData.sectionOf(s) -> Section
--   StuntData.Centreline  StuntData.Sections  StuntData.Checkpoints  StuntData.Warnings  StuntData.Obstacles  ...
--   StuntData.report() -> string                    StuntData.check() -> { string }   (empty = every invariant holds)

local StuntData = {}

-- TYPES --------------------------------------------------------------------------------------

export type Range = { s0: number, s1: number }

export type Leg = {
	id: string,
	s0: number,
	s1: number,
	origin: Vector3, -- the world position at s0 (a corner centre, or the start line)
	heading: Vector3, -- unit travel direction along the leg
}

export type PieceKind = "Flat" | "Ramp" | "Gap" | "Pad" | "Deck"

-- One stretch of the road surface. The pieces are contiguous from 0 to Length, so the builder cannot leave a gap or an overlap.
export type Piece = {
	kind: PieceKind,
	s0: number,
	s1: number,
	y0: number, -- road top height at s0
	y1: number, -- road top height at s1 (a Ramp rises or falls between them)
	note: string,
}

export type Section = {
	id: string,
	name: string,
	s0: number,
	s1: number,
	approach: Range,
	obstacle: Range?,
	recovery: Range,
	safeRoute: string,
}

export type Bounds = { s0: number, s1: number, lat0: number, lat1: number, y0: number, y1: number }

export type Idle = {
	kind: string,
	pivotS: number,
	pivotLateral: number,
	pivotY: number,
	lengthStuds: number,
	sweepDegrees: number,
	periodSeconds: number,
	phase: number,
	note: string,
}

export type Obstacle = {
	id: string,
	kind: string,
	section: string,
	s: number,
	lateral: number,
	lanes: { number },
	artBounds: Bounds,
	hitbox: Bounds?,
	hitboxNote: string,
	visualOnly: boolean,
	collides: boolean,
	moving: boolean,
	idle: Idle?,
}

export type Checkpoint = {
	index: number,
	id: string,
	s: number,
	nominalSeconds: number,
	nominalS: number,
	shiftStuds: number,
	section: string,
	seconds: number, -- at the nominal speed
	cframe: CFrame, -- the arch plane: LookVector = forward, origin on the centreline at road height
	archHalfSpan: number,
	restart: Range,
	why: string,
}

export type Warning = {
	id: string,
	section: string,
	text: string,
	s: number,
	lateral: number,
	obstacleStartS: number,
	leadStuds: number,
	leadSeconds: number,
	leadSecondsAtSpeed: { [string]: number },
}

export type Point = {
	s: number,
	position: Vector3,
	heading: Vector3,
	width: number, -- drivable width
	section: string,
	airborne: boolean, -- inside a gap: the y shown is the straight line between the two lips
	note: string,
}

export type Corner = { id: string, s: number, centre: Vector3, pad: number, turn: string }

-- LAP ----------------------------------------------------------------------------------------

StuntData.Name = "Stunt Circuit"
StuntData.Status =
	"PROPOSAL for Brian R: a visual pacing model and scenery plan, not an approved or measured gameplay value"
StuntData.Units = "studs"
StuntData.Origin = "middle of the start/finish line, on the road surface"
StuntData.Axes = { forward = "-Z at s = 0", right = "+X", up = "+Y" }
StuntData.Length = 5250
StuntData.NominalSpeed = 70 -- PREVIEW studs per second; the example speed the section lengths were derived from
StuntData.NominalSeconds = 75
StuntData.SpeedScales = table.freeze({ 0.8, 1, 1.2 }) -- the three flythrough speeds the brief asks to test (M17-02a)
StuntData.WarningLeadSeconds = table.freeze({ min = 1.5, max = 2.5 }) -- the readability target (M17-01c), not a collision spacing

StuntData.Road = table.freeze({
	lanes = 4,
	laneWidth = 17,
	shoulder = 4,
	drivableWidth = 68,
	totalWidth = 76,
	surfaceY = 0,
	groundY = -4, -- the road is a 4 stud causeway on this ground, so a gap shows a real pit
	slabThickness = 4,
	cornerPad = 76,
	bridgeDrivableWidth = 34,
	status = "PROPOSAL (Downtown city width, 4 x 17 + 2 x 4)",
})

local PAD = StuntData.Road.cornerPad
local HALF_PAD = PAD / 2

-- Five straight legs. s runs 0..5250 around the loop; the lap ends where it began.
StuntData.Legs = table.freeze({
	{ id = "A1", s0 = 0, s1 = 620, origin = Vector3.new(0, 0, 0), heading = Vector3.new(0, 0, -1) },
	{ id = "B", s0 = 620, s1 = 1500, origin = Vector3.new(0, 0, -620), heading = Vector3.new(-1, 0, 0) },
	{ id = "C", s0 = 1500, s1 = 3245, origin = Vector3.new(-880, 0, -620), heading = Vector3.new(0, 0, 1) },
	{ id = "D", s0 = 3245, s1 = 4125, origin = Vector3.new(-880, 0, 1125), heading = Vector3.new(1, 0, 0) },
	{ id = "A2", s0 = 4125, s1 = 5250, origin = Vector3.new(0, 0, 1125), heading = Vector3.new(0, 0, -1) },
} :: { Leg })

-- The four corners (left turns). The pad is centred on the corner point; legs join it edge to edge, never overlapping it.
StuntData.Corners = table.freeze({
	{ id = "T1", s = 620, centre = Vector3.new(0, 0, -620), pad = PAD, turn = "left" },
	{ id = "T2", s = 1500, centre = Vector3.new(-880, 0, -620), pad = PAD, turn = "left" },
	{ id = "T3", s = 3245, centre = Vector3.new(-880, 0, 1125), pad = PAD, turn = "left" },
	{ id = "T4", s = 4125, centre = Vector3.new(0, 0, 1125), pad = PAD, turn = "left" },
} :: { Corner })

-- The surface, in order, edge to edge. A Ramp rises or falls from y0 to y1 across its length.
StuntData.Pieces = table.freeze({
	{ kind = "Flat", s0 = 0, s1 = 582, y0 = 0, y1 = 0, note = "start straight, slalom, recovery" },
	{ kind = "Pad", s0 = 582, s1 = 658, y0 = 0, y1 = 0, note = "corner T1" },
	{ kind = "Flat", s0 = 658, s1 = 1180, y0 = 0, y1 = 0, note = "approach straight, checkpoint 1, warning" },
	{ kind = "Ramp", s0 = 1180, s1 = 1220, y0 = 0, y1 = 6, note = "first jump, launch ramp (full width)" },
	{ kind = "Gap", s0 = 1220, s1 = 1280, y0 = 0, y1 = 0, note = "first jump, pit (60 studs, visual proposal)" },
	{ kind = "Ramp", s0 = 1280, s1 = 1320, y0 = 3, y1 = 0, note = "first jump, landing ramp (full width)" },
	{ kind = "Flat", s0 = 1320, s1 = 1462, y0 = 0, y1 = 0, note = "recovery straight" },
	{ kind = "Pad", s0 = 1462, s1 = 1538, y0 = 0, y1 = 0, note = "corner T2" },
	{ kind = "Flat", s0 = 1538, s1 = 3207, y0 = 0, y1 = 0, note = "tunnel, arms, checkpoints 2 and 3" },
	{ kind = "Pad", s0 = 3207, s1 = 3283, y0 = 0, y1 = 0, note = "corner T3" },
	{
		kind = "Flat",
		s0 = 3283,
		s1 = 3620,
		y0 = 0,
		y1 = 0,
		note = "bridge approach (full width until the funnel ends)",
	},
	{ kind = "Deck", s0 = 3620, s1 = 3920, y0 = 0, y1 = 0, note = "narrow bridge deck, 34 studs between the rails" },
	{ kind = "Flat", s0 = 3920, s1 = 4087, y0 = 0, y1 = 0, note = "bridge exit, recovery" },
	{ kind = "Pad", s0 = 4087, s1 = 4163, y0 = 0, y1 = 0, note = "corner T4" },
	{ kind = "Flat", s0 = 4163, s1 = 4440, y0 = 0, y1 = 0, note = "approach straight, checkpoint 4, warning" },
	{ kind = "Ramp", s0 = 4440, s1 = 4476, y0 = 0, y1 = 5, note = "double jump, first ramp" },
	{ kind = "Gap", s0 = 4476, s1 = 4516, y0 = 0, y1 = 0, note = "double jump, first pit" },
	{ kind = "Flat", s0 = 4516, s1 = 4616, y0 = 2.5, y1 = 2.5, note = "generous intermediate landing (100 studs)" },
	{ kind = "Ramp", s0 = 4616, s1 = 4652, y0 = 2.5, y1 = 7.5, note = "double jump, second ramp" },
	{ kind = "Gap", s0 = 4652, s1 = 4694, y0 = 0, y1 = 0, note = "double jump, second pit" },
	{ kind = "Ramp", s0 = 4694, s1 = 4740, y0 = 4, y1 = 0, note = "double jump, landing ramp" },
	{ kind = "Flat", s0 = 4740, s1 = 5250, y0 = 0, y1 = 0, note = "recovery, finish straight, stadium, line" },
} :: { Piece })

-- SECTIONS (M17-01b: the order and durations are the brief's; the distances use the nominal speed) --------------

local function range(s0: number, s1: number): Range
	return { s0 = s0, s1 = s1 }
end

StuntData.Sections = table.freeze({
	{
		id = "Slalom",
		name = "Slalom barriers",
		s0 = 0,
		s1 = 840,
		approach = range(0, 287.5),
		obstacle = range(287.5, 452.5),
		recovery = range(452.5, 840),
		safeRoute = "three barriers change sides, right half then left half then right half; the other half is always open",
	},
	{
		id = "RampGap",
		name = "Ramp over a gap",
		s0 = 840,
		s1 = 1540,
		approach = range(840, 1180),
		obstacle = range(1180, 1320),
		recovery = range(1320, 1540),
		safeRoute = "one full-width jump; the landing ramp is striped and 40 studs long",
	},
	{
		id = "Tunnel",
		name = "Tunnel with potholes",
		s0 = 1540,
		s1 = 2380,
		approach = range(1540, 1974.5),
		obstacle = range(1974.5, 2103.5),
		recovery = range(2103.5, 2380),
		safeRoute = "first group fills the left two lanes (right half open), second group fills the right two lanes (left half open)",
	},
	{
		id = "Arms",
		name = "Swinging arms",
		s0 = 2380,
		s1 = 3220,
		approach = range(2380, 2628),
		obstacle = range(2628, 2852),
		recovery = range(2852, 3220),
		safeRoute = "arm one reaches from the left side and never covers lane 4; arm two reaches from the right and never covers lane 1",
	},
	{
		id = "Bridge",
		name = "Narrow bridge",
		s0 = 3220,
		s1 = 3990,
		approach = range(3220, 3540),
		obstacle = range(3540, 3960),
		recovery = range(3960, 3990),
		safeRoute = "a broad 76 stud approach funnels over 80 studs into a 34 stud deck with parapets",
	},
	{
		id = "DoubleRamp",
		name = "Double ramp",
		s0 = 3990,
		s1 = 4830,
		approach = range(3990, 4440),
		obstacle = range(4440, 4740),
		recovery = range(4740, 4830),
		safeRoute = "jump, a 100 stud raised landing, jump again, then a 46 stud landing ramp back to the road",
	},
	{
		id = "Finish",
		name = "Finish straight",
		s0 = 4830,
		s1 = 5250,
		approach = range(4830, 5250),
		obstacle = nil,
		recovery = range(5250, 5250),
		safeRoute = "straight and clear into the stadium; the line is the start line",
	},
} :: { Section })

-- WIDTH: the drivable width by lap distance. The funnel narrows from 68 to 34 over 80 studs and widens again over 40. -----

StuntData.WidthSpans = table.freeze({
	{
		s0 = 3540,
		s1 = 3620,
		from = 68,
		to = 34,
		note = "funnel in (angled barriers; the road under them stays 76 wide)",
	},
	{ s0 = 3620, s1 = 3920, from = 34, to = 34, note = "narrow bridge deck" },
	{ s0 = 3920, s1 = 3960, from = 34, to = 68, note = "funnel out" },
})

-- OBSTACLES: looks and idle motion only (M17-01, M17-02a) ----------------------------------------------------------

local function laneCentre(lane: number): number
	return (lane - 2.5) * StuntData.Road.laneWidth
end
StuntData.laneCentre = laneCentre

local function bounds(s0: number, s1: number, lat0: number, lat1: number, y0: number, y1: number): Bounds
	return { s0 = s0, s1 = s1, lat0 = lat0, lat1 = lat1, y0 = y0, y1 = y1 }
end

local obstacles: { Obstacle } = {}

local function add(o: Obstacle)
	table.insert(obstacles, o)
end

-- three slalom barriers: right half, left half, right half (each 34 wide, 5 deep, 5 high)
for i, spec in
	{
		{ s = 290, lanes = { 3, 4 }, lat0 = 0, lat1 = 34 },
		{ s = 370, lanes = { 1, 2 }, lat0 = -34, lat1 = 0 },
		{ s = 450, lanes = { 3, 4 }, lat0 = 0, lat1 = 34 },
	} :: { { s: number, lanes: { number }, lat0: number, lat1: number } }
do
	add({
		id = "SL" .. i,
		kind = "SlalomBarrier",
		section = "Slalom",
		s = spec.s,
		lateral = (spec.lat0 + spec.lat1) / 2,
		lanes = spec.lanes,
		artBounds = bounds(spec.s - 2.5, spec.s + 2.5, spec.lat0, spec.lat1, 0, 5),
		hitbox = bounds(spec.s - 2, spec.s + 2, spec.lat0, spec.lat1, 0, 4),
		hitboxNote = "PROPOSAL: the art block, 0.5 shorter and lower so a clipped corner is forgiving; not built",
		visualOnly = true,
		collides = false,
		moving = false,
		idle = nil,
	})
end

-- two pothole groups in the tunnel (art rim 11 studs, dark core 9 studs; proposed trigger radius 4)
local potholeId = 0
local function pothole(s: number, lane: number)
	potholeId += 1
	local lat = laneCentre(lane)
	add({
		id = "PH" .. potholeId,
		kind = "Pothole",
		section = "Tunnel",
		s = s,
		lateral = lat,
		lanes = { lane },
		artBounds = bounds(s - 5.5, s + 5.5, lat - 5.5, lat + 5.5, 0, 0.24),
		hitbox = bounds(s - 4, s + 4, lat - 4, lat + 4, -1, 1),
		hitboxNote = "PROPOSAL: a 8 stud square under the dark core only; the yellow rim is a warning, not a hit area",
		visualOnly = true,
		collides = false,
		moving = false,
		idle = nil,
	})
end
for _, p in { { 1980, 1 }, { 1988, 2 }, { 2000, 1 }, { 2008, 2 } } do -- group 1: left half
	pothole(p[1], p[2])
end
for _, p in { { 2070, 4 }, { 2078, 3 }, { 2090, 4 }, { 2098, 3 } } do -- group 2: right half
	pothole(p[1], p[2])
end

-- two swinging arms, staggered, reaching from opposite sides (visual-only; the arm swings on an IDLE loop)
local ARM_LENGTH = 52
local ARM_POST_LATERAL = 43
for i, spec in
	{
		{ s = 2680, side = -1, phase = 0 },
		{ s = 2800, side = 1, phase = 0.5 },
	} :: { { s: number, side: number, phase: number } }
do
	local lat = spec.side * ARM_POST_LATERAL
	add({
		id = "ARM" .. i,
		kind = "SwingingArm",
		section = "Arms",
		s = spec.s,
		lateral = lat,
		lanes = if spec.side < 0 then { 1, 2, 3 } else { 2, 3, 4 },
		artBounds = bounds(
			spec.s - ARM_LENGTH,
			spec.s + ARM_LENGTH,
			-ARM_POST_LATERAL - 1.5,
			ARM_POST_LATERAL + 1.5,
			1.5,
			5
		),
		hitbox = nil,
		hitboxNote = "PROPOSAL: a 52 x 3.5 x 2.4 stud box that follows the arm's angle; timing and hit rules are Brian R's. The idle swing is not logic",
		visualOnly = true,
		collides = false,
		moving = true,
		idle = {
			kind = "Swing",
			pivotS = spec.s,
			pivotLateral = lat,
			pivotY = 3.25,
			lengthStuds = ARM_LENGTH,
			sweepDegrees = 70,
			periodSeconds = 5,
			phase = spec.phase,
			note = "IDLE ANIMATION ONLY: yaw = sweepDegrees x sin(2 pi (t / periodSeconds + phase)) about the vertical pivot; 0 degrees points straight across the road",
		},
	})
end

-- jumps and pits: no surface in the gap; the floor is the 4 stud lower ground
local function jump(id: string, section: string, s0: number, s1: number, y: number)
	add({
		id = id,
		kind = "Pit",
		section = section,
		s = (s0 + s1) / 2,
		lateral = 0,
		lanes = { 1, 2, 3, 4 },
		artBounds = bounds(s0, s1, -38, 38, StuntData.Road.groundY, y),
		hitbox = nil,
		hitboxNote = "PROPOSAL: the pit is simply the absence of road between the two lips; the fall rule is Brian R's",
		visualOnly = true,
		collides = false,
		moving = false,
		idle = nil,
	})
end
jump("PIT1", "RampGap", 1220, 1280, 0)
jump("PIT2", "DoubleRamp", 4476, 4516, 0)
jump("PIT3", "DoubleRamp", 4652, 4694, 0)

-- the bridge: parapet rails and the two funnel walls
add({
	id = "BRIDGE",
	kind = "NarrowBridge",
	section = "Bridge",
	s = 3770,
	lateral = 0,
	lanes = { 2, 3 },
	artBounds = bounds(3540, 3960, -19.5, 19.5, -4, 3.4),
	hitbox = bounds(3620, 3920, -19, 19, 0, 3),
	hitboxNote = "PROPOSAL: the two parapets only (2 studs thick at lateral 17 to 19 each side, 3 high); the funnel walls guide, they are scenery. The drop is Brian R's rule",
	visualOnly = true,
	collides = false,
	moving = false,
	idle = nil,
})

StuntData.Obstacles = table.freeze(obstacles)

-- WARNINGS (M17-01c: 1.5 to 2.5 s of clear view at the nominal speed; measured to the first obstacle of the section) ---

local warnings: { Warning } = {}

local function warning(id: string, section: string, text: string, obstacleStartS: number, lead: number)
	local s = obstacleStartS - lead
	local at: { [string]: number } = {}
	for _, scale in StuntData.SpeedScales do
		at[string.format("%.1fx", scale)] = lead / (StuntData.NominalSpeed * scale)
	end
	table.insert(warnings, {
		id = id,
		section = section,
		text = text,
		s = s,
		lateral = 62, -- the sign's centre, outside the barrier (a wide sign still clears 44)
		obstacleStartS = obstacleStartS,
		leadStuds = lead,
		leadSeconds = lead / StuntData.NominalSpeed,
		leadSecondsAtSpeed = at,
	})
end
warning("W1", "Slalom", "SLALOM", 287.5, 140)
warning("W2", "RampGap", "JUMP", 1180, 140)
warning("W3", "Tunnel", "POTHOLES", 1974.5, 140)
warning("W4", "Arms", "SWINGING ARMS", 2628, 140)
warning("W5", "Bridge", "NARROW BRIDGE", 3540, 140)
warning("W6", "DoubleRamp", "DOUBLE JUMP", 4440, 140)
StuntData.Warnings = table.freeze(warnings)

-- CHECKPOINTS (M17-01b: nominal 15, 30, 45 and 60 s, moved onto a flat safe segment before the next commitment) -------

function StuntData.legOf(s: number): Leg
	local w = s % StuntData.Length
	for _, leg in StuntData.Legs do
		if w >= leg.s0 and w < leg.s1 then
			return leg
		end
	end
	return StuntData.Legs[#StuntData.Legs]
end

-- The CFrame at lap distance s, `lateral` studs to the right and `y` up. LookVector is the direction of travel.
function StuntData.frame(s: number, lateral: number?, y: number?): CFrame
	local w = s % StuntData.Length
	local leg = StuntData.legOf(w)
	local at = leg.origin + leg.heading * (w - leg.s0)
	return CFrame.lookAt(at, at + leg.heading) * CFrame.new(lateral or 0, y or 0, 0)
end

local checkpoints: { Checkpoint } = {}
local function checkpoint(index: number, nominalSeconds: number, s: number, section: string, why: string)
	local nominalS = nominalSeconds * StuntData.NominalSpeed
	table.insert(checkpoints, {
		index = index,
		id = "CP" .. index,
		s = s,
		nominalSeconds = nominalSeconds,
		nominalS = nominalS,
		shiftStuds = s - nominalS,
		section = section,
		seconds = s / StuntData.NominalSpeed,
		cframe = StuntData.frame(s, 0, 0),
		archHalfSpan = 43,
		restart = range(s + 10, s + 50),
		why = why,
	})
end
checkpoint(1, 15, 980, "RampGap", "flat approach straight, 200 studs before the jump, before its warning sign")
checkpoint(2, 30, 2210, "Tunnel", "flat straight just after the tunnel exit, before the arms approach")
checkpoint(3, 45, 3120, "Arms", "flat recovery straight after the arms, 87 studs before corner T3")
checkpoint(4, 60, 4250, "DoubleRamp", "flat approach straight after corner T4, before the double jump warning")
StuntData.Checkpoints = table.freeze(checkpoints)
StuntData.CheckpointTotal = #checkpoints + 1 -- the finish line counts as the last one (the HUD shows 5)

-- The start grid: four slots one lane each, 28 studs behind the line (the same road the finish straight uses).
StuntData.StartGrid = table.freeze({
	s = StuntData.Length - 28,
	lanes = { 1, 2, 3, 4 },
	length = 24,
	width = 14,
	note = "rolling lap time starts at the line; the grid is where cars wait",
})

-- A flat structure that is not part of the road: the tunnel shell (visual only).
StuntData.Structures = table.freeze({
	Tunnel = range(1880, 2170),
	BridgeFunnelIn = range(3540, 3620),
	BridgeFunnelOut = range(3920, 3960),
	Water = { s0 = 3650, s1 = 3890, halfWidth = 200, y = -9 },
	Gantry = { s = 0, note = "start/finish gantry straddles the line" },
})

-- PROFILE, WIDTH AND POINT LOOKUPS -------------------------------------------------------------------------------

function StuntData.pieceAt(s: number): Piece?
	local w = s % StuntData.Length
	for _, p in StuntData.Pieces do
		if w >= p.s0 and w < p.s1 then
			return p
		end
	end
	return nil
end

-- Road top height at s, or nil inside a gap (there is no surface).
function StuntData.surfaceY(s: number): number?
	local p = StuntData.pieceAt(s)
	if not p then
		return nil
	end
	if p.kind == "Gap" then
		return nil
	end
	if p.kind == "Ramp" then
		local t = ((s % StuntData.Length) - p.s0) / (p.s1 - p.s0)
		return p.y0 + (p.y1 - p.y0) * t
	end
	return p.y0
end

function StuntData.drivableWidth(s: number): number
	local w = s % StuntData.Length
	for _, span in StuntData.WidthSpans do
		if w >= span.s0 and w <= span.s1 then
			local t = (w - span.s0) / math.max(span.s1 - span.s0, 1e-6)
			return span.from + (span.to - span.from) * t
		end
	end
	return StuntData.Road.drivableWidth
end

function StuntData.sectionOf(s: number): Section
	local w = s % StuntData.Length
	for _, sec in StuntData.Sections do
		if w >= sec.s0 and w < sec.s1 then
			return sec
		end
	end
	return StuntData.Sections[#StuntData.Sections]
end

-- CENTRELINE: the list of points and widths Brian R's driving and checkpoint logic can follow (M17-02) -----------------
-- Straight between points. Every leg end, corner pad edge and centre, section edge, ramp and gap lip, width change and
-- checkpoint is a point, plus a point every 250 studs so no run is long. A point inside a gap is airborne: its y is the
-- straight line between the lips, not a surface.

local function buildCentreline(): { Point }
	local keys: { [number]: string } = {}
	local function key(s: number, note: string)
		local k = math.floor(s * 100 + 0.5) / 100
		keys[k] = if keys[k] then keys[k] .. "; " .. note else note
	end
	key(0, "start/finish line")
	for _, leg in StuntData.Legs do
		key(leg.s0, "leg " .. leg.id .. " start")
	end
	for _, c in StuntData.Corners do
		key(c.s - HALF_PAD, c.id .. " pad entry")
		key(c.s, c.id .. " pad centre")
		key(c.s + HALF_PAD, c.id .. " pad exit")
	end
	for _, sec in StuntData.Sections do
		key(sec.s0, sec.name .. " start")
	end
	for _, p in StuntData.Pieces do
		if p.kind == "Ramp" or p.kind == "Gap" or p.kind == "Deck" then
			key(p.s0, p.note)
			key(p.s1, p.note)
		end
	end
	for _, cp in StuntData.Checkpoints do
		key(cp.s, cp.id)
	end
	for _, span in StuntData.WidthSpans do
		key(span.s0, "width change")
		key(span.s1, "width change")
	end
	for s = 250, StuntData.Length - 250, 250 do
		key(s, "every 250 studs")
	end
	key(StuntData.Length, "start/finish line (the lap ends where it began)")
	local ordered: { number } = {}
	for k in keys do
		table.insert(ordered, k)
	end
	table.sort(ordered)
	local out: { Point } = {}
	for _, s in ordered do
		local sample = math.min(s, StuntData.Length - 1e-3)
		local leg = StuntData.legOf(sample)
		local piece = StuntData.pieceAt(sample)
		local y = 0
		local airborne = false
		if piece then
			if piece.kind == "Gap" then
				airborne = true
				-- the lips: the end of the previous piece and the start of the next one
				local before = StuntData.surfaceY(piece.s0 - 0.01) or 0
				local after = StuntData.surfaceY(piece.s1 + 0.01) or 0
				y = before + (after - before) * ((s - piece.s0) / (piece.s1 - piece.s0))
			else
				y = StuntData.surfaceY(sample) or 0
			end
		end
		local at = leg.origin + leg.heading * (sample - leg.s0) + Vector3.new(0, y, 0)
		table.insert(out, {
			s = s,
			position = at,
			heading = leg.heading,
			width = StuntData.drivableWidth(sample),
			section = StuntData.sectionOf(sample).id,
			airborne = airborne,
			note = keys[s],
		})
	end
	return out
end
StuntData.Centreline = table.freeze(buildCentreline())

-- Safe restart zones: flat, straight, clear of every obstacle, after each checkpoint and at the start grid.
StuntData.RestartZones =
	table.freeze((function(): { { id: string, s0: number, s1: number, lateralHalf: number, note: string } }
		local out = {}
		table.insert(out, {
			id = "RS0",
			s0 = StuntData.StartGrid.s - 12,
			s1 = StuntData.Length - 4,
			lateralHalf = 30,
			note = "start grid, behind the line",
		})
		for _, cp in StuntData.Checkpoints do
			table.insert(out, {
				id = "RS" .. cp.index,
				s0 = cp.restart.s0,
				s1 = cp.restart.s1,
				lateralHalf = 30,
				note = "flat straight after " .. cp.id,
			})
		end
		return out
	end)())

-- REPORT AND CHECKS ---------------------------------------------------------------------------------------------------

function StuntData.report(): string
	local lines: { string } = {}
	local speed = StuntData.NominalSpeed
	table.insert(
		lines,
		string.format(
			"%s PROPOSAL: %d studs, nominal %d s at %d studs/s (PREVIEW speed, not proof any car can do it)",
			StuntData.Name,
			StuntData.Length,
			StuntData.NominalSeconds,
			speed
		)
	)
	table.insert(lines, "SECTIONS (distance, then time at the nominal speed):")
	for _, sec in StuntData.Sections do
		table.insert(
			lines,
			string.format(
				"  %-10s s %4d-%4d  %3d studs  %4.1f-%4.1f s  (%.1f s)",
				sec.id,
				sec.s0,
				sec.s1,
				sec.s1 - sec.s0,
				sec.s0 / speed,
				sec.s1 / speed,
				(sec.s1 - sec.s0) / speed
			)
		)
	end
	table.insert(lines, "CHECKPOINTS (nominal distance, adjusted distance, shift, time at the nominal speed):")
	for _, cp in StuntData.Checkpoints do
		table.insert(
			lines,
			string.format(
				"  %s  nominal %4d s=%4d  adjusted s=%4d  shift %+4d studs  now %.1f s  flat: %s",
				cp.id,
				cp.nominalSeconds,
				cp.nominalS,
				cp.s,
				cp.shiftStuds,
				cp.seconds,
				cp.why
			)
		)
	end
	table.insert(
		lines,
		"WARNINGS (sign position, studs to the first obstacle, seconds of clear view at 0.8x / 1x / 1.2x):"
	)
	for _, w in StuntData.Warnings do
		table.insert(
			lines,
			string.format(
				"  %s  %-14s sign s=%7.1f  lead %3d studs  %.2f / %.2f / %.2f s",
				w.id,
				w.text,
				w.s,
				w.leadStuds,
				w.leadSecondsAtSpeed["0.8x"],
				w.leadSecondsAtSpeed["1.0x"],
				w.leadSecondsAtSpeed["1.2x"]
			)
		)
	end
	table.insert(
		lines,
		"OBSTACLES: " .. #StuntData.Obstacles .. " (all visual-only and non-colliding; arms have an idle swing only)"
	)
	return table.concat(lines, "\n")
end

local function inRange(s: number, r: Range, pad: number?): boolean
	local p = pad or 0
	return s >= r.s0 - p and s <= r.s1 + p
end

-- Returns a list of broken invariants. Empty means every one holds.
function StuntData.check(): { string }
	local problems: { string } = {}
	local function fail(text: string)
		table.insert(problems, text)
	end
	-- sections are contiguous and total the lap
	local at = 0
	for _, sec in StuntData.Sections do
		if math.abs(sec.s0 - at) > 1e-6 then
			fail("section " .. sec.id .. " does not start where the last one ended")
		end
		at = sec.s1
	end
	if at ~= StuntData.Length then
		fail("sections end at " .. at .. ", not " .. StuntData.Length)
	end
	-- the surface pieces are contiguous
	at = 0
	for i, p in StuntData.Pieces do
		if math.abs(p.s0 - at) > 1e-6 then
			fail("surface piece " .. i .. " leaves a gap or an overlap at s " .. p.s0)
		end
		at = p.s1
	end
	if at ~= StuntData.Length then
		fail("surface ends at " .. at)
	end
	-- the legs chain and close: each leg ends where the next begins, and the last returns to the first origin
	for i, leg in StuntData.Legs do
		local nextLeg = StuntData.Legs[i + 1]
		local endPoint = leg.origin + leg.heading * (leg.s1 - leg.s0)
		if nextLeg then
			if math.abs(nextLeg.s0 - leg.s1) > 1e-6 then
				fail("leg " .. leg.id .. " does not meet the next leg in s")
			end
			if (endPoint - nextLeg.origin).Magnitude > 1e-3 then
				fail("leg " .. leg.id .. " ends away from the next leg's origin")
			end
		elseif (endPoint - StuntData.Legs[1].origin).Magnitude > 1e-3 then
			fail(
				"the loop does not close: the last leg ends "
					.. (endPoint - StuntData.Legs[1].origin).Magnitude
					.. " studs away"
			)
		end
	end
	-- ramps are continuous with their neighbours (no step at a join except across a gap)
	for i = 2, #StuntData.Pieces do
		local a, b = StuntData.Pieces[i - 1], StuntData.Pieces[i]
		if a.kind ~= "Gap" and b.kind ~= "Gap" then
			local ay = if a.kind == "Ramp" then a.y1 else a.y0
			if math.abs(ay - b.y0) > 1e-6 then
				fail(string.format("surface steps from %.2f to %.2f at s %d", ay, b.y0, b.s0))
			end
		end
	end
	-- corner pads sit on a Pad piece and nothing else touches them
	for _, c in StuntData.Corners do
		local found = false
		for _, p in StuntData.Pieces do
			if
				p.kind == "Pad"
				and math.abs((p.s0 + p.s1) / 2 - c.s) < 1e-6
				and math.abs(p.s1 - p.s0 - c.pad) < 1e-6
			then
				found = true
			end
		end
		if not found then
			fail("corner " .. c.id .. " has no matching 76 stud pad piece")
		end
		for _, sec in StuntData.Sections do
			local obs = sec.obstacle
			if obs and inRange(c.s, obs, HALF_PAD) then
				fail("corner " .. c.id .. " sits inside the " .. sec.id .. " obstacle zone")
			end
		end
	end
	-- checkpoints are on a flat piece and outside every obstacle zone, gap and structure
	for _, cp in StuntData.Checkpoints do
		local piece = StuntData.pieceAt(cp.s)
		if not piece or piece.kind ~= "Flat" or piece.y0 ~= 0 then
			fail(cp.id .. " is not on flat road at road height")
		end
		for _, sec in StuntData.Sections do
			if sec.obstacle and inRange(cp.s, sec.obstacle, 60) then
				fail(cp.id .. " is within 60 studs of the " .. sec.id .. " obstacle zone")
			end
		end
		local structures: { [string]: any } = StuntData.Structures
		for name, r in structures do
			if r.s0 and r.s1 and inRange(cp.s, r, 20) then
				fail(cp.id .. " is inside or beside structure " .. name)
			end
		end
		if StuntData.drivableWidth(cp.s) < 68 then
			fail(cp.id .. " is on a narrowed road")
		end
		if math.abs(cp.shiftStuds) > 250 then
			fail(cp.id .. " is more than 250 studs from its nominal time")
		end
	end
	-- warnings: 1.5 to 2.5 s of clear view at 1x, and still at least 1.3 s at 1.2x
	for _, w in StuntData.Warnings do
		local lead = w.leadSeconds
		if lead < StuntData.WarningLeadSeconds.min or lead > StuntData.WarningLeadSeconds.max then
			fail(w.id .. " gives " .. lead .. " s of warning at 1x, outside 1.5 to 2.5 s")
		end
		if w.leadSecondsAtSpeed["1.2x"] < 1.3 then
			fail(w.id .. " gives less than 1.3 s of warning at 1.2x")
		end
		local piece = StuntData.pieceAt(w.s)
		if not piece or piece.kind ~= "Flat" then
			fail(w.id .. " is not on a flat stretch")
		end
	end
	-- obstacles are visual-only and the moving ones are flagged
	for _, o in StuntData.Obstacles do
		if not o.visualOnly or o.collides then
			fail(o.id .. " is not flagged visual-only and non-colliding")
		end
		if o.moving and not o.idle then
			fail(o.id .. " moves but has no idle description")
		end
	end
	return problems
end

return StuntData
