--!strict
-- The road of the Stunt Circuit (Lane 3, M17-01): ground and water, the road surface piece by piece, its paint and the
-- barriers. Everything is built from StuntData.Pieces, which are contiguous, so a join is always edge to edge: no gaps, and no
-- two surfaces overlap on one plane. Rules used throughout (M1): paint sits 0.12 above what it is painted on, a second paint
-- layer another 0.12 above that, and faces that meet back to back (a slab end against a barrier end) never face the same way.
--
--   Road.build(root: Model) -> ()
--
-- The road is a 4 stud causeway standing on the ground (StuntData.Road.groundY), so a gap in the road is a real pit with a
-- dark painted floor. Only the road surface collides; paint, barriers and every other part never do.

local Parts = require(script.Parent.StuntParts)
local StuntData = require(script.Parent.StuntData)

local Road = {}

local P = Parts.Palette
local ROAD = StuntData.Road
local HALF = ROAD.totalWidth / 2 -- 38
local GROUND = ROAD.groundY
local PAINT = 0.12
local RAMP_COLOUR = Color3.fromRGB(104, 118, 158)
local STRIPE_ORANGE = P.Orange

-- BARRIER GAPS: the stretches where the standard edge barrier stops (a jump, the tunnel, the bridge) --------------------

local BARRIER_GAPS: { StuntData.Range } = {
	{ s0 = 1180, s1 = 1320 },
	{ s0 = 1880, s1 = 2170 },
	{ s0 = 3540, s1 = 3960 },
	{ s0 = 4440, s1 = 4740 },
}

-- The leg that holds the whole range s0..s1.
local function legIn(s0: number, s1: number): StuntData.Leg
	for _, leg in StuntData.Legs do
		if s0 >= leg.s0 - 1e-6 and s1 <= leg.s1 + 1e-6 then
			return leg
		end
	end
	error(string.format("no single leg holds s %.1f to %.1f", s0, s1))
end

-- GROUND ---------------------------------------------------------------------------------------------------------------

local function buildGround(folder: Folder)
	local w = StuntData.Structures.Water
	local legD = StuntData.Legs[4]
	local x0 = legD.origin.X + (w.s0 - legD.s0) -- the water's west bank
	local x1 = legD.origin.X + (w.s1 - legD.s0) -- and its east bank
	local zc = legD.origin.Z
	local zA, zB = zc - w.halfWidth, zc + w.halfWidth
	local west, east = -1500, 700
	local north, south = -1300, 1800
	local function plate(name: string, xa: number, xb: number, za: number, zb: number)
		Parts.box(
			folder,
			name,
			Vector3.new(xb - xa, 20, zb - za),
			CFrame.new((xa + xb) / 2, GROUND - 10, (za + zb) / 2),
			P.Ground
		)
	end
	-- four plates around the pond, so the water sits in a real trench (the banks are the plates' own sides)
	plate("GroundWest", west, x0, north, south)
	plate("GroundEast", x1, east, north, south)
	plate("GroundNorthOfPond", x0, x1, north, zA)
	plate("GroundSouthOfPond", x0, x1, zB, south)
	Parts.box(
		folder,
		"Water",
		Vector3.new(x1 - x0, 2, zB - zA),
		CFrame.new((x0 + x1) / 2, w.y - 1, zc),
		P.Water,
		{ attributes = { Note = "pond under the narrow bridge (visual only)" } }
	)
	-- the infield lawn, painted 0.12 above the ground and kept clear of the pond
	local lawnY = GROUND + PAINT / 2
	local function lawn(name: string, xa: number, xb: number, za: number, zb: number)
		Parts.box(
			folder,
			name,
			Vector3.new(xb - xa, PAINT, zb - za),
			CFrame.new((xa + xb) / 2, lawnY, (za + zb) / 2),
			P.Grass
		)
	end
	local inA, inB = -840, -44
	lawn("InfieldLawnNorth", inA, inB, -580, zA)
	lawn("InfieldLawnSouthWest", inA, x0, zA, 1085)
	lawn("InfieldLawnSouthEast", x1, inB, zA, 1085)
	-- bridge piers stand on the water plate and carry the deck
	for i, s in { 3740, 3830 } do
		local at = StuntData.frame(s, 0, 0).Position
		Parts.box(
			folder,
			"Pier" .. i,
			Vector3.new(8, 5, 24),
			CFrame.new(at.X, (w.y + GROUND) / 2, at.Z),
			P.ConcreteDark,
			{ shadow = true }
		)
	end
end

-- ROAD SURFACE -----------------------------------------------------------------------------------------------------------

-- A patch of paint lying on a ramp, between two surface fractions, `lat0..lat1` across. It follows the slope.
local function rampPaint(
	folder: Folder,
	name: string,
	leg: StuntData.Leg,
	piece: StuntData.Piece,
	t0: number,
	t1: number,
	lat0: number,
	lat1: number,
	colour: Color3
)
	local function surface(t: number): Vector3
		local s = piece.s0 + (piece.s1 - piece.s0) * t
		local y = piece.y0 + (piece.y1 - piece.y0) * t
		return leg.origin + leg.heading * (s - leg.s0) + Vector3.new(0, y, 0)
	end
	local a, b = surface(t0), surface(t1)
	local mid = (a + b) / 2
	local along = CFrame.lookAt(mid, mid + (b - a).Unit)
	Parts.box(
		folder,
		name,
		Vector3.new(lat1 - lat0, PAINT, (b - a).Magnitude),
		along * CFrame.new((lat0 + lat1) / 2, PAINT / 2, 0),
		colour
	)
end

local function buildRamp(road: Folder, paint: Folder, piece: StuntData.Piece, index: number)
	local leg = legIn(piece.s0, piece.s1)
	local length = piece.s1 - piece.s0
	local rising = piece.y1 > piece.y0
	local low = math.min(piece.y0, piece.y1)
	local height = math.abs(piece.y1 - piece.y0)
	local mid = leg.origin + leg.heading * ((piece.s0 + piece.s1) / 2 - leg.s0)
	-- the support block under the slope, then the wedge on top of it
	Parts.along(
		road,
		"RampBase" .. index,
		leg.origin,
		leg.heading,
		piece.s0 - leg.s0,
		piece.s1 - leg.s0,
		-HALF,
		HALF,
		GROUND,
		low,
		P.Asphalt,
		{ collide = true }
	)
	-- the wedge's low edge is at local -Z and its tall wall at +Z, so +Z must point at the high end
	local wedgeMid = Vector3.new(mid.X, low + height / 2, mid.Z)
	local toward = if rising then -leg.heading else leg.heading
	Parts.wedge(
		road,
		"RampSlope" .. index,
		Vector3.new(ROAD.totalWidth, height, length),
		CFrame.lookAt(wedgeMid, wedgeMid + toward),
		RAMP_COLOUR,
		{ collide = true, attributes = { Ramp = true, RiseStuds = piece.y1 - piece.y0 } }
	)
	if rising then
		-- a clear contrasting launch edge: a gold strip then a dark one, on the last 4.4 studs of the slope
		local t = 1 - 1.2 / length
		local t0 = 1 - 3.2 / length
		rampPaint(paint, "LaunchEdgeGold" .. index, leg, piece, t0, t, -HALF, HALF, P.Gold)
		rampPaint(paint, "LaunchEdgeInk" .. index, leg, piece, t, 1, -HALF, HALF, P.Ink)
	else
		-- an obvious landing: three white bars across the safe landing slope
		for i, span in { { 0.12, 0.22 }, { 0.42, 0.52 }, { 0.72, 0.82 } } do
			rampPaint(paint, "LandingBar" .. index .. "_" .. i, leg, piece, span[1], span[2], -HALF, HALF, P.White)
		end
	end
end

local function buildPit(paint: Folder, piece: StuntData.Piece, index: number)
	local leg = legIn(piece.s0, piece.s1)
	local a0, a1 = piece.s0 - leg.s0, piece.s1 - leg.s0
	Parts.along(
		paint,
		"PitFloor" .. index,
		leg.origin,
		leg.heading,
		a0,
		a1,
		-HALF,
		HALF,
		GROUND,
		GROUND + PAINT,
		P.PitFloor
	)
	-- two orange rim stripes across the pit floor (a second layer, 0.12 above the floor paint)
	for k, at in { a0 + 1, a1 - 2.5 } do
		Parts.along(
			paint,
			"PitStripe" .. index .. "_" .. k,
			leg.origin,
			leg.heading,
			at,
			at + 1.5,
			-HALF,
			HALF,
			GROUND + PAINT,
			GROUND + PAINT * 2,
			STRIPE_ORANGE
		)
	end
end

-- Lines and dashes on a stretch of road at height `top`: solid edge lines and dashed lane lines.
local function laneMarks(paint: Folder, leg: StuntData.Leg, piece: StuntData.Piece, narrow: boolean)
	local a0, a1 = piece.s0 - leg.s0, piece.s1 - leg.s0
	local top = piece.y0
	local edge = if narrow then 16.2 else 33.4
	for _, side in { -1, 1 } do
		Parts.along(
			paint,
			"EdgeLine",
			leg.origin,
			leg.heading,
			a0,
			a1,
			side * edge - 0.6,
			side * edge + 0.6,
			top,
			top + PAINT,
			P.LineWhite
		)
	end
	local lanes = if narrow then { 0 } else { -17, 0, 17 }
	for _, lat in lanes do
		local at = a0 + 14
		while at + 18 <= a1 - 14 do
			Parts.along(
				paint,
				"LaneDash",
				leg.origin,
				leg.heading,
				at,
				at + 18,
				lat - 0.45,
				lat + 0.45,
				top,
				top + PAINT,
				P.LineWhite
			)
			at += 60
		end
	end
end

local function buildSurface(road: Folder, paint: Folder)
	local rampIndex, pitIndex = 0, 0
	for _, piece in StuntData.Pieces do
		if piece.kind == "Flat" then
			local leg = legIn(piece.s0, piece.s1)
			Parts.along(
				road,
				"Road",
				leg.origin,
				leg.heading,
				piece.s0 - leg.s0,
				piece.s1 - leg.s0,
				-HALF,
				HALF,
				GROUND,
				piece.y0,
				P.Asphalt,
				{ collide = true }
			)
			laneMarks(paint, leg, piece, false)
			if piece.y0 > 0 then
				-- the raised landing: a white bar along its front edge says "land here"
				Parts.along(
					paint,
					"PlatformEdge",
					leg.origin,
					leg.heading,
					piece.s0 - leg.s0,
					piece.s0 - leg.s0 + 2.5,
					-32.8,
					32.8,
					piece.y0,
					piece.y0 + PAINT,
					P.White
				)
			end
		elseif piece.kind == "Deck" then
			local leg = legIn(piece.s0, piece.s1)
			Parts.along(
				road,
				"BridgeDeck",
				leg.origin,
				leg.heading,
				piece.s0 - leg.s0,
				piece.s1 - leg.s0,
				-19,
				19,
				GROUND,
				piece.y0,
				P.Asphalt,
				{ collide = true }
			)
			laneMarks(paint, leg, piece, true)
		elseif piece.kind == "Ramp" then
			rampIndex += 1
			buildRamp(road, paint, piece, rampIndex)
		elseif piece.kind == "Gap" then
			pitIndex += 1
			buildPit(paint, piece, pitIndex)
		end
	end
	-- the four corner pads, square, edge to edge with the legs on either side
	for _, c in StuntData.Corners do
		Parts.box(
			road,
			"CornerPad" .. c.id,
			Vector3.new(c.pad, -GROUND, c.pad),
			CFrame.new(c.centre.X, GROUND / 2, c.centre.Z),
			P.Asphalt,
			{ collide = true }
		)
	end
end

-- START / FINISH LINE AND START GRID -----------------------------------------------------------------------------------

local function buildLine(paint: Folder)
	local leg = StuntData.Legs[1]
	local half = 32 -- inside the edge lines (they start at 32.8), so no paint of one layer overlaps another
	-- white base (layer 1), black tiles on it (layer 2, 0.12 higher): a checkered line 8 deep across the drivable road
	Parts.along(
		paint,
		"FinishLineBase",
		leg.origin,
		leg.heading,
		-4,
		4,
		-half,
		half,
		0,
		PAINT,
		P.LineWhite,
		{ attributes = { Note = "start and finish line" } }
	)
	local tile = 4
	for col = 0, 15 do
		local row = if col % 2 == 0 then 0 else 1
		local a0 = if row == 0 then 0 else -tile
		Parts.along(
			paint,
			"FinishTile",
			leg.origin,
			leg.heading,
			a0,
			a0 + tile,
			-half + col * tile,
			-half + (col + 1) * tile,
			PAINT,
			PAINT * 2,
			P.Ink
		)
	end
	-- the start grid: four slots, one per lane, behind the line
	local grid = StuntData.StartGrid
	local behind = StuntData.Length - grid.s -- studs behind the line
	for _, lane in grid.lanes do
		local lat = StuntData.laneCentre(lane)
		local a1 = -behind + grid.length / 2
		local a0 = a1 - grid.length
		Parts.along(
			paint,
			"GridSlot" .. lane,
			leg.origin,
			leg.heading,
			a0,
			a1,
			lat - grid.width / 2,
			lat + grid.width / 2,
			0,
			PAINT,
			P.LineWhite
		)
		Parts.along(
			paint,
			"GridSlotInner" .. lane,
			leg.origin,
			leg.heading,
			a0 + 1.2,
			a1 - 1.2,
			lat - grid.width / 2 + 1.2,
			lat + grid.width / 2 - 1.2,
			PAINT,
			PAINT * 2,
			P.Asphalt
		)
	end
end

-- BARRIERS -----------------------------------------------------------------------------------------------------------------

-- Subtracts the barrier gaps from [u0, u1] (leg-local), returning the remaining pieces.
local function remaining(leg: StuntData.Leg, u0: number, u1: number): { { number } }
	local pieces: { { number } } = { { u0, u1 } }
	for _, gap in BARRIER_GAPS do
		local g0, g1 = gap.s0 - leg.s0, gap.s1 - leg.s0
		local kept: { { number } } = {}
		for _, p in pieces do
			if g1 <= p[1] or g0 >= p[2] then
				table.insert(kept, p)
			else
				if g0 > p[1] then
					table.insert(kept, { p[1], g0 })
				end
				if g1 < p[2] then
					table.insert(kept, { g1, p[2] })
				end
			end
		end
		pieces = kept
	end
	return pieces
end

-- The wall is navy with a gold cap and stands outside the road edge, down to the ground. The right-hand wall of every leg is
-- the outside of the left turns, so it runs through the corner pad's outside edges; the left-hand wall stops at each pad's
-- inner corner. The overlap is zero: each piece starts exactly where its neighbour ends.
local function buildBarriers(folder: Folder)
	local legs = StuntData.Legs
	local count = 0
	for i, leg in legs do
		local len = leg.s1 - leg.s0
		local startsAtCorner = i > 1
		local endsAtCorner = i < #legs
		local ranges = {
			{ side = -1, u0 = if startsAtCorner then HALF + 2 else 0, u1 = if endsAtCorner then len - HALF else len },
			{ side = 1, u0 = if startsAtCorner then -HALF else 0, u1 = if endsAtCorner then len + HALF + 2 else len },
		}
		for _, r in ranges do
			for _, p in remaining(leg, r.u0, r.u1) do
				count += 1
				local lat0 = if r.side > 0 then HALF else -HALF - 2
				local lat1 = if r.side > 0 then HALF + 2 else -HALF
				Parts.along(folder, "Barrier", leg.origin, leg.heading, p[1], p[2], lat0, lat1, GROUND, 3, P.Navy)
				Parts.along(
					folder,
					"BarrierCap",
					leg.origin,
					leg.heading,
					p[1],
					p[2],
					lat0 - 0.5,
					lat1 + 0.5,
					3,
					3.4,
					P.Gold
				)
			end
		end
	end
	folder:SetAttribute("PieceCount", count)
end

-- ENTRY -----------------------------------------------------------------------------------------------------------------------

function Road.build(root: Model)
	local ground = Parts.folder(root, "Ground")
	local road = Parts.folder(root, "Road")
	road:SetAttribute("Note", "the only collidable parts: the road surface, its ramps and corner pads")
	local paint = Parts.folder(root, "Paint")
	local barriers = Parts.folder(root, "Barriers")
	buildGround(ground)
	buildSurface(road, paint)
	buildLine(paint)
	buildBarriers(barriers)
end

return Road
