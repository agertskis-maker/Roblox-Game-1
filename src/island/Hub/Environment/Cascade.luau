--!strict
-- The waterfall system's geometry (Lane 3, build-time, pure). One connected flow:
--   snowfield creek + side tarn stream -> upper falls (free fall off a projecting lip) and a
--   side horsetail sliding down a rock chute -> shared ledge basin -> lower falls split into
--   three unequal streams by rock projections -> plunge pool -> lake current -> park stream.
-- The cliff is a stepped face: an upper face, an uneven ledge terrace, a lower face, with
-- drainage grooves cut into both faces, a projecting lip, a grotto behind the lower falls.
-- Plan frame (x east, y north); heights are studs above the hub surface. Every channel
-- floor descends toward its outlet (checked by Cascade.check()).

local Cascade = {}

Cascade.X = -120 -- falls centre line
Cascade.Band = { full = 72, fade = 105 } -- half widths of the cliff band (in x) and its blend
Cascade.UpperFaceY = -292
Cascade.LowerFaceY = -276
Cascade.LipHeight = 168.5 -- water leaves the lip here
Cascade.LipEdgeY = -289 -- the projecting lip's north edge
Cascade.Ledge = { height = 82, basin = Vector2.new(-118, -284), basinRadius = 9.5, basinFloor = 76.5, water = 81.2 }
Cascade.LowerLip = { height = 81.2, y = -276 }
Cascade.Pool = { centre = Vector2.new(-121, -267), radius = 14, floor = -8 }
Cascade.Tarn = { centre = Vector2.new(-74, -338), radius = 9, floor = 149.5, water = 153.5 }

export type FlowPoint = { p: Vector2, h: number }

-- Main creek: snowfield to the lip notch (floor heights descend).
Cascade.Creek = {
	{ p = Vector2.new(-158, -508), h = 262 },
	{ p = Vector2.new(-148, -468), h = 244 },
	{ p = Vector2.new(-138, -428), h = 226 },
	{ p = Vector2.new(-131, -388), h = 210 },
	{ p = Vector2.new(-126, -350), h = 195 },
	{ p = Vector2.new(-122, -318), h = 181 },
	{ p = Vector2.new(-120, -300), h = 171.5 },
	{ p = Vector2.new(-120, -292), h = 168.5 },
} :: { FlowPoint }
Cascade.CreekHalf = 3.6

-- Side stream: tarn outlet to the top of the horsetail chute.
Cascade.SideStream = {
	{ p = Vector2.new(-79, -329), h = 152.5 },
	{ p = Vector2.new(-87, -316), h = 146 },
	{ p = Vector2.new(-95, -305), h = 136 },
} :: { FlowPoint }
Cascade.SideHalf = 2.6

-- Horsetail chute: the water slides on the rock, with bumps and small steps.
Cascade.Horsetail = {
	{ p = Vector2.new(-95, -305), h = 136 },
	{ p = Vector2.new(-99, -300), h = 122 },
	{ p = Vector2.new(-103, -295.5), h = 109 },
	{ p = Vector2.new(-106, -292), h = 98 },
	{ p = Vector2.new(-108.5, -289), h = 89 },
	{ p = Vector2.new(-111, -287), h = 82.5 },
} :: { FlowPoint }
Cascade.ChuteHalf = 4.5

-- Lower falls: three unequal streams from the lower lip, converging on the pool.
Cascade.LowerStreams = {
	{ x = -131, width = 6 },
	{ x = -120.5, width = 9.5 },
	{ x = -110.5, width = 4.5 },
}
Cascade.LowerSplits = { -126.2, -114.6 } -- rock projections between the streams

local function smoothstep(a: number, b: number, x: number): number
	local t = math.clamp((x - a) / (b - a), 0, 1)
	return t * t * (3 - 2 * t)
end

local function gauss(x: number, c: number, w: number): number
	return math.exp(-((x - c) / w) ^ 2)
end

-- Drainage grooves and crevices recede the faces (more negative y) at fixed places.
local UPPER_GROOVES = { { -168, 4.5, 3 }, { -147, 3, 2.2 }, { -99, 5, 2.6 }, { -78, 3.5, 3 }, { -57, 4, 2 } }
local LOWER_GROOVES = { { -160, 3.5, 2.5 }, { -140, 4, 2 }, { -96, 3, 2.4 }, { -70, 4.5, 3 } }

function Cascade.upperFaceY(x: number): number
	local y = Cascade.UpperFaceY
	for _, g in UPPER_GROOVES do
		y -= g[2] * gauss(x, g[1], g[3])
	end
	-- the face swings back a little away from the falls, so it is not one straight wall
	return y - 0.0016 * (x - Cascade.X) ^ 2
end

function Cascade.lowerFaceY(x: number): number
	local y = Cascade.LowerFaceY
	for _, g in LOWER_GROOVES do
		y -= g[2] * gauss(x, g[1], g[3])
	end
	return y - 0.0011 * (x - Cascade.X) ^ 2
end

-- Ledge terrace height: unequal steps along x, rising away from the falls.
function Cascade.ledgeHeight(x: number): number
	local dx = math.abs(x - Cascade.X)
	local step = 0
	if x < Cascade.X - 22 then
		step = 6 + 7 * smoothstep(40, 50, dx)
	elseif x > Cascade.X + 16 then
		step = 4 + 9 * smoothstep(34, 46, dx)
	end
	return Cascade.Ledge.height + step
end

local function along(points: { FlowPoint }, p: Vector2): (number, number, number)
	-- distance to the polyline, height interpolated at the nearest point, and segment slope
	local best, bestH, bestSlope = math.huge, 0, 0
	for i = 1, #points - 1 do
		local a, b = points[i], points[i + 1]
		local ab = b.p - a.p
		local t = math.clamp((p - a.p):Dot(ab) / ab:Dot(ab), 0, 1)
		local d = (p - (a.p + ab * t)).Magnitude
		if d < best then
			best = d
			bestH = a.h + (b.h - a.h) * t
			bestSlope = (a.h - b.h) / ab.Magnitude
		end
	end
	return best, bestH, bestSlope
end
Cascade.along = along

export type Shape = { h: number, water: number?, channel: boolean, wetRock: boolean, ledge: boolean }

-- Reshapes the terrain height `h` (the mountains before the lake ramp) inside the cascade zone.
-- Returns nil outside it.
function Cascade.shape(p: Vector2, h: number): Shape?
	local x, y = p.X, p.Y
	if x < -260 or x > 10 or y > -262 or y < -540 then
		return nil
	end
	local dx = math.abs(x - Cascade.X)
	local band = 1 - smoothstep(Cascade.Band.full, Cascade.Band.fade, dx)
	local out: Shape = { h = h, water = nil, channel = false, wetRock = false, ledge = false }

	-- stepped cliff: upper plateau, ledge terrace, then the shore below the lower face
	if band > 0 then
		local yU, yL = Cascade.upperFaceY(x), Cascade.lowerFaceY(x)
		if y <= yU then
			-- a broad cliff-top shelf behind the upper face, so the faces are wide stepped walls
			-- rather than the tip of a cone; it merges back into the mountain further south
			local top = Cascade.LipHeight + 16 - 0.0065 * dx * dx + 2.5 * math.sin(x * 0.21)
			local behind = 1 - smoothstep(26, 52, yU - y)
			out.h = math.max(h, h + (top - h) * band * behind)
		elseif y <= yL then
			local ledge = Cascade.ledgeHeight(x)
			out.h = h + (ledge - h) * band
			out.ledge = band > 0.5
		else
			out.h = h * (1 - band)
		end
		out.wetRock = dx < 34 and y > -300
	end

	-- the ledge basin
	local db = (p - Cascade.Ledge.basin).Magnitude
	if db < Cascade.Ledge.basinRadius then
		local f = db / Cascade.Ledge.basinRadius
		out.h = Cascade.Ledge.basinFloor + (Cascade.Ledge.water + 0.6 - Cascade.Ledge.basinFloor) * f ^ 2
		out.water = Cascade.Ledge.water
		out.channel = true
	end

	-- the tarn on the east shoulder
	local dt = (p - Cascade.Tarn.centre).Magnitude
	if dt < Cascade.Tarn.radius + 5 then
		local tarn = Cascade.Tarn
		if dt < tarn.radius then
			out.h = tarn.floor + (tarn.water + 0.8 - tarn.floor) * (dt / tarn.radius) ^ 2
			out.water = tarn.water
			out.channel = true
		else
			out.h = math.max(out.h, tarn.water + 1.5) -- a rim, so the tarn holds its water
		end
	end

	-- creek and side stream: a channel with a rock bed and sloping banks
	for _, stream in { { Cascade.Creek, Cascade.CreekHalf }, { Cascade.SideStream, Cascade.SideHalf } } do
		local pts = stream[1] :: { FlowPoint }
		local half = stream[2] :: number
		local d, floor = along(pts, p)
		if d < half + 9 then
			local bank = floor + 1.6 + math.max(0, d - half) * 1.1
			if d < half then
				out.h = math.min(out.h, floor)
				out.water = floor + 1.3
				out.channel = true
			else
				out.h = math.min(out.h, bank)
				out.wetRock = out.wetRock or d < half + 3
			end
		end
	end

	-- horsetail chute: a buttress whose top carries the slide, with walls either side
	local dc, chuteH = along(Cascade.Horsetail, p)
	local inBasin = db < Cascade.Ledge.basinRadius
	if dc < Cascade.ChuteHalf + 6 and not inBasin then
		local bumps = 1.1 * math.sin(chuteH * 0.55) + 0.6 * math.sin(chuteH * 1.7)
		local surface = chuteH + bumps
		local wall = surface + math.max(0, dc - Cascade.ChuteHalf) * 2.6
		local cap = h -- never higher than the mountain behind it
		out.h = math.min(cap, if dc < Cascade.ChuteHalf then surface else math.max(out.h, wall))
		out.wetRock = true
	end

	return out
end

export type Volume = { kind: "add" | "carve", centre: Vector3, radii: Vector3, material: Enum.Material? }

-- 3D shapes that a height field cannot make: the projecting lip, the rock projections that
-- split the lower falls, an overhang above the ledge, and the grotto behind the lower falls.
-- World studs (X = x, Z = -y).
function Cascade.volumes(): { Volume }
	local X = Cascade.X
	local vols: { Volume } = {
		{
			kind = "add",
			centre = Vector3.new(X, Cascade.LipHeight - 1.6, -(Cascade.UpperFaceY + 1.6)),
			radii = Vector3.new(9, 2.2, 3.4),
			material = Enum.Material.Basalt,
		},
		{
			kind = "add",
			centre = Vector3.new(X - 26, 118, -(Cascade.UpperFaceY + 1.5)),
			radii = Vector3.new(11, 5, 4),
			material = Enum.Material.Basalt,
		},
		{
			kind = "add",
			centre = Vector3.new(X + 24, 132, -(Cascade.UpperFaceY + 1.2)),
			radii = Vector3.new(8, 4, 3.2),
			material = Enum.Material.Basalt,
		},
		{
			kind = "carve",
			centre = Vector3.new(X + 10, 9, -(Cascade.LowerFaceY - 3)),
			radii = Vector3.new(9, 8.5, 5.5),
		},
	}
	for _, sx in Cascade.LowerSplits do
		table.insert(vols, {
			kind = "add",
			centre = Vector3.new(sx, Cascade.LowerLip.height - 1.5, -(Cascade.LowerLip.y + 0.6)),
			radii = Vector3.new(2.1, 4.2, 3.4),
			material = Enum.Material.Basalt,
		})
		table.insert(vols, {
			kind = "add",
			centre = Vector3.new(sx + 0.6, Cascade.LowerLip.height - 14, -(Cascade.LowerLip.y + 1.4)),
			radii = Vector3.new(1.6, 9, 2.4),
			material = Enum.Material.Basalt,
		})
	end
	return vols
end

-- Flow checks: every channel descends toward its outlet.
function Cascade.check(): { [string]: any }
	local function descending(points: { FlowPoint }): boolean
		for i = 2, #points do
			if points[i].h > points[i - 1].h then
				return false
			end
		end
		return true
	end
	return {
		creekDescends = descending(Cascade.Creek),
		sideStreamDescends = descending(Cascade.SideStream),
		horsetailDescends = descending(Cascade.Horsetail),
		creekEndsAtLip = math.abs(Cascade.Creek[#Cascade.Creek].h - Cascade.LipHeight) < 0.01,
		sideJoinsChute = (Cascade.SideStream[#Cascade.SideStream].p - Cascade.Horsetail[1].p).Magnitude < 0.01,
		chuteEndsInBasin = (Cascade.Horsetail[#Cascade.Horsetail].p - Cascade.Ledge.basin).Magnitude
			< Cascade.Ledge.basinRadius,
		upperDrop = Cascade.LipHeight - Cascade.Ledge.water,
		lowerDrop = Cascade.LowerLip.height - -1,
		totalDrop = Cascade.LipHeight - -1,
	}
end

return Cascade
