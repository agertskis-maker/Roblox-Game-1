--!strict
-- Island environment height field (Lane 3, build-time). Pure and deterministic: the same
-- seed always gives the same heights. No instances, no terrain calls.
--
-- Composition (plan frame: x east, y north toward the plots, origin at the fountain):
--   hub      flat at 0 inside the half disc (r <= 575, y >= -80), so every plot, path and
--            corridor keeps the approved layout;
--   near     modest grassy rises just outside the hub;
--   middle   foothill chains down both sides and a low north rim, front ridges by the lake;
--   far      the main southern range: five distinctive peaks joined by saddles, asymmetric
--            (long north shoulders toward the lake, short south faces), the tallest landmark
--            west of the portal axis with a spur that ends in the waterfall cliff, and a back
--            range showing through the saddles;
--   water    the lake behind the portals, a plunge pool, the park stream, the creek above the
--            falls and an outlet gorge draining east.
-- Ridges are spines with a height and a left and right width at every node; their flanks are
-- concave (steep near the crest, broad at the base) and they join through a smooth maximum,
-- so neighbouring peaks share saddles instead of standing alone.

local Cascade = require(script.Parent.Cascade)

local Field = {}

Field.VERSION = "island-env-2" -- 2: stepped falls cliff, creek, tarn, chute, irregular lake
Field.Cell = 4
Field.LakeLevel = -1
Field.HubRadius = 575
Field.HubSouthY = -80
-- Terrain box in Roblox world studs (plan y = -Z).
Field.Box = { minX = -880, maxX = 880, minY = -24, maxY = 360, minZ = -760, maxZ = 780 }

export type Spine = {
	name: string,
	points: { Vector2 },
	heights: { number },
	left: { number }, -- flank width to the left of travel
	right: { number },
	profile: number, -- flank exponent: higher is steeper near the crest and gentler at the foot
}

-- Main southern range, west to east (left of travel is north, toward the lake).
local SPINES: { Spine } = {
	{
		-- each peak has a long gentle shoulder on one side and a short steep drop on the other
		name = "MainRange",
		points = {
			Vector2.new(-900, -360),
			Vector2.new(-720, -430), -- far-west horn: long west shoulder
			Vector2.new(-560, -505),
			Vector2.new(-510, -490), -- steep east drop
			Vector2.new(-380, -470),
			Vector2.new(-300, -500), -- landmark: long west shoulder
			Vector2.new(-235, -528),
			Vector2.new(-150, -560),
			Vector2.new(-110, -566), -- steep east face
			Vector2.new(-60, -562),
			Vector2.new(40, -555),
			Vector2.new(180, -585), -- east twin summits
			Vector2.new(260, -600),
			Vector2.new(305, -612),
			Vector2.new(360, -632),
			Vector2.new(420, -600), -- steep east drop
			Vector2.new(520, -520),
			Vector2.new(600, -470), -- far-east rounded peak
			Vector2.new(680, -425),
			Vector2.new(760, -385),
			Vector2.new(900, -330),
		},
		heights = {
			110,
			172,
			240,
			200,
			165,
			226,
			270,
			335,
			292,
			240,
			205,
			250,
			285,
			258,
			272,
			222,
			175,
			190,
			205,
			178,
			115,
		},
		left = {
			200,
			220,
			240,
			235,
			230,
			250,
			275,
			300,
			290,
			270,
			250,
			270,
			300,
			290,
			280,
			250,
			220,
			210,
			200,
			190,
			170,
		},
		right = {
			140,
			155,
			170,
			165,
			150,
			165,
			180,
			190,
			185,
			175,
			170,
			175,
			180,
			170,
			160,
			155,
			150,
			155,
			160,
			150,
			140,
		},
		profile = 2.0,
	},
	{
		name = "BackRange",
		points = { Vector2.new(-320, -790), Vector2.new(70, -705), Vector2.new(330, -780) },
		heights = { 190, 250, 185 },
		left = { 150, 160, 150 },
		right = { 90, 90, 90 },
		profile = 1.7,
	},
	{
		-- spur from the landmark peak north to the waterfall cliff (it runs past the cliff line,
		-- which cuts it, so the cliff top keeps the spur's full height)
		name = "WaterfallSpur",
		points = { Vector2.new(-152, -545), Vector2.new(-133, -410), Vector2.new(-121, -300), Vector2.new(-118, -262) },
		heights = { 312, 246, 196, 190 }, -- carries the creek down to a 168-stud lip (Cascade)
		left = { 70, 78, 104, 108 }, -- widens into the cliff band round the falls
		right = { 54, 62, 92, 96 },
		profile = 1.6,
	},
	{
		-- the east shoulder that holds the tarn feeding the horsetail (Cascade)
		name = "TarnShoulder",
		points = { Vector2.new(-82, -392), Vector2.new(-74, -342), Vector2.new(-87, -316), Vector2.new(-97, -302) },
		heights = { 180, 168, 156, 146 },
		left = { 34, 32, 28, 24 },
		right = { 38, 34, 30, 26 },
		profile = 1.5,
	},
	-- foothills: wide and with a more concave profile, so their lower slopes are gentle and grassy
	{
		name = "FrontWest",
		points = { Vector2.new(-640, -250), Vector2.new(-430, -335), Vector2.new(-262, -352) },
		heights = { 118, 132, 100 },
		left = { 190, 200, 160 },
		right = { 190, 200, 170 },
		profile = 2.4,
	},
	{
		name = "FrontEast",
		points = { Vector2.new(330, -345), Vector2.new(470, -305), Vector2.new(545, -300) },
		heights = { 90, 110, 96 },
		left = { 160, 175, 160 },
		right = { 170, 180, 170 },
		profile = 2.4,
	},
	{
		name = "SideEast",
		points = {
			Vector2.new(650, -130),
			Vector2.new(765, 80),
			Vector2.new(805, 320),
			Vector2.new(705, 560),
			Vector2.new(520, 735),
		},
		heights = { 112, 134, 116, 96, 78 },
		left = { 170, 190, 190, 180, 150 },
		right = { 190, 200, 190, 180, 150 },
		profile = 2.2,
	},
	{
		name = "SideWest",
		points = {
			Vector2.new(-655, -190),
			Vector2.new(-790, 10),
			Vector2.new(-765, 270),
			Vector2.new(-660, 525),
			Vector2.new(-470, 715),
		},
		heights = { 138, 152, 121, 101, 82 },
		left = { 200, 200, 190, 180, 150 },
		right = { 180, 190, 190, 180, 150 },
		profile = 2.2,
	},
	{
		name = "NorthRim",
		points = { Vector2.new(-330, 735), Vector2.new(-60, 760), Vector2.new(170, 745), Vector2.new(400, 715) },
		heights = { 66, 58, 74, 62 },
		left = { 110, 110, 110, 110 },
		right = { 130, 140, 130, 130 },
		profile = 2.2,
	},
}
Field.Spines = SPINES

-- Lake, plunge pool, waterfall and channels.
Field.Lake = { centre = Vector2.new(0, -172), rx = 300, ry = 100, depth = 12 }
-- Lake shoreline: inside the approved ellipse only (e < 1), pulled in by an irregular indent with
-- a peninsula, coves, a beach near the plaza, a marsh cove at the east end and a rocky shore by
-- the falls. Angles are in the ellipse's own frame (degrees, 0 = east, 90 = north toward the plaza).
Field.LakeZones = {
	beach = { from = 50, to = 90 },
	marsh = { from = -10, to = 28 },
	rocky = { from = -136, to = -88 },
	peninsula = { at = -58, width = 5, depth = 0.34 },
	spit = { at = -168, width = 4, depth = 0.16 },
	coves = { { at = 8, width = 12 }, { at = 160, width = 10 }, { at = -100, width = 7 } },
}
Field.Outlet = {
	points = {
		Vector2.new(285, -185),
		Vector2.new(400, -198),
		Vector2.new(520, -222),
		Vector2.new(640, -262),
		Vector2.new(780, -322),
	},
	half = 6,
	floor0 = -3.5,
	floor1 = -18,
}
Field.StreamHalf = 5
Field.StreamBank = 8
Field.StreamFloor = -3.5

local function smoothstep(a: number, b: number, x: number): number
	local t = math.clamp((x - a) / (b - a), 0, 1)
	return t * t * (3 - 2 * t)
end
Field.smoothstep = smoothstep

-- Smooth maximum that fills the crease where two ridges overlap (a saddle) but adds nothing
-- where either side is flat ground, so the hub stays exactly at 0.
local function smax(a: number, b: number, k: number): number
	local d = math.abs(a - b)
	local m = math.max(a, b)
	if d >= k then
		return m
	end
	local t = 1 - d / k
	return m + 0.25 * k * t * t * math.clamp(math.min(a, b) / k, 0, 1)
end

export type Noise = { ox: number, oy: number, oz: { number } }

function Field.noiseFor(seed: number): Noise
	local rng = Random.new(seed)
	local oz = {}
	for i = 1, 8 do
		oz[i] = rng:NextNumber() * 1000
	end
	return { ox = rng:NextNumber() * 1000, oy = rng:NextNumber() * 1000, oz = oz }
end

local function n2(nz: Noise, x: number, y: number, scale: number, layer: number): number
	return math.noise(x / scale + nz.ox, y / scale + nz.oy, nz.oz[layer])
end

-- Ridged noise in about [0, 1]: sharp creases where the base noise crosses zero.
local function ridged(nz: Noise, x: number, y: number, scale: number): number
	local sum, amp, norm, s = 0, 1, 0, scale
	for octave = 1, 4 do
		local v = 1 - math.abs(n2(nz, x, y, s, 2 + octave))
		sum += v * v * amp
		norm += amp
		amp *= 0.5
		s *= 0.5
	end
	return sum / norm
end

-- Distance outside the flat hub half disc.
function Field.hubDistance(p: Vector2): number
	local r = p.Magnitude
	local dr = math.max(0, r - Field.HubRadius)
	local dy = math.max(0, Field.HubSouthY - p.Y)
	return math.sqrt(dr * dr + dy * dy)
end

function Field.lakeE(p: Vector2): number
	local lake = Field.Lake
	local dx = (p.X - lake.centre.X) / lake.rx
	local dy = (p.Y - lake.centre.Y) / lake.ry
	return math.sqrt(dx * dx + dy * dy)
end

-- Distance to a polyline and the fraction along it.
function Field.polylineDistance(points: { Vector2 }, p: Vector2): (number, number)
	local best, bestAlong, total = math.huge, 0, 0
	local lengths = {}
	for i = 1, #points - 1 do
		lengths[i] = (points[i + 1] - points[i]).Magnitude
		total += lengths[i]
	end
	local acc = 0
	for i = 1, #points - 1 do
		local a, b = points[i], points[i + 1]
		local ab = b - a
		local t = math.clamp((p - a):Dot(ab) / ab:Dot(ab), 0, 1)
		local d = (p - (a + ab * t)).Magnitude
		if d < best then
			best = d
			bestAlong = (acc + lengths[i] * t) / total
		end
		acc += lengths[i]
	end
	return best, bestAlong
end

local function flank(u: number, profile: number): number
	if u >= 1 then
		return 0
	end
	return (1 - u) ^ profile
end

-- One spine's height at p (largest over its segments).
local function spineHeight(spine: Spine, p: Vector2): number
	local best = 0
	local pts = spine.points
	for i = 1, #pts - 1 do
		local a, b = pts[i], pts[i + 1]
		local ab = b - a
		local len2 = ab:Dot(ab)
		local tRaw = (p - a):Dot(ab) / len2
		local t = math.clamp(tRaw, 0, 1)
		local s = t * t * (3 - 2 * t)
		local h = spine.heights[i] + (spine.heights[i + 1] - spine.heights[i]) * s
		local rel = p - (a + ab * t)
		local d = rel.Magnitude
		local leftSide = ab.X * rel.Y - ab.Y * rel.X > 0
		local wl = spine.left[i] + (spine.left[i + 1] - spine.left[i]) * s
		local wr = spine.right[i] + (spine.right[i + 1] - spine.right[i]) * s
		local w = if leftSide then wl else wr
		if tRaw < 0 or tRaw > 1 then
			w *= 0.8 -- rounded ends
		end
		best = math.max(best, h * flank(d / w, spine.profile))
	end
	return best
end

export type Sample = {
	h: number,
	water: number?, -- water surface height, if any
	lake: boolean,
	bank: boolean,
	channel: boolean,
	hub: boolean,
	far: number, -- 0 near to 1 far, for the lighter far rock
	wet: boolean, -- wet dark rock by the falls and channels
	zone: string, -- lake bed or shore zone: "", "beach", "marsh", "rocky", "shelf", "deep", "damp", "ledge"
}

local function angularGauss(theta: number, at: number, width: number): number
	local d = ((theta - at + 540) % 360) - 180
	return math.exp(-(d / width) ^ 2)
end

-- Is p in the lake (inside the approved ellipse, minus the irregular indent)? Returns the bed
-- height and the bed or shore zone.
function Field.lakeShape(p: Vector2): (boolean, number, string)
	local lake = Field.Lake
	local nx = (p.X - lake.centre.X) / lake.rx
	local ny = (p.Y - lake.centre.Y) / lake.ry
	local e = math.sqrt(nx * nx + ny * ny)
	if e >= 1 then
		local theta = math.deg(math.atan2(ny, nx))
		local z = Field.LakeZones
		local zone = if theta >= z.rocky.from and theta <= z.rocky.to
			then "rocky"
			elseif theta >= z.beach.from and theta <= z.beach.to then "beach"
			else ""
		return false, 0, zone
	end
	local theta = math.deg(math.atan2(ny, nx))
	local z = Field.LakeZones
	local indent = 0.06 + 0.035 * math.sin(math.rad(3 * theta) + 1) + 0.025 * math.sin(math.rad(7 * theta) + 2.3)
	indent += z.peninsula.depth * angularGauss(theta, z.peninsula.at, z.peninsula.width)
	indent += z.spit.depth * angularGauss(theta, z.spit.at, z.spit.width)
	for _, cove in z.coves do
		indent *= 1 - 0.9 * angularGauss(theta, cove.at, cove.width)
	end
	local beach = theta >= z.beach.from and theta <= z.beach.to
	local marsh = theta >= z.marsh.from and theta <= z.marsh.to
	local rocky = theta >= z.rocky.from and theta <= z.rocky.to
	if beach then
		indent = math.min(indent, 0.03)
	end
	local shore = 1 - math.clamp(indent, 0, 0.5)
	if e >= shore then
		return false, 0, if rocky then "rocky" elseif beach then "beach" else ""
	end
	local r = e / shore -- 0 at the middle, 1 at the shore
	if marsh then
		return true, Field.LakeLevel - 0.3 - 1.6 * smoothstep(1, 0.35, r), "marsh"
	end
	local shelfStart = if beach then 0.55 else 0.72
	local shelfDepth = if beach then 2.3 else 3.3
	if r > shelfStart then
		local f = smoothstep(1, shelfStart, r)
		return true,
			Field.LakeLevel - 0.3 - shelfDepth * f,
			if beach then "beach" elseif rocky then "rocky" else "shelf"
	end
	local deep = (shelfStart - r) / shelfStart
	return true, Field.LakeLevel - 0.3 - shelfDepth - 10.5 * deep ^ 0.8, "deep"
end

-- The mountains and near rises at p, before the waterfall system, lake and channels.
function Field.rawHeight(nz: Noise, p: Vector2): number
	local dF = Field.hubDistance(p)
	local x, y = p.X, p.Y
	-- mountains: spines joined by a smooth maximum, with irregular crests and shoulders
	local m = 0
	for _, spine in SPINES do
		m = smax(m, spineHeight(spine, p), 22)
	end
	local wx = x + 45 * n2(nz, x, y, 320, 1)
	local wy = y + 45 * n2(nz, y, x, 320, 1)
	m *= 1 + 0.12 * n2(nz, wx, wy, 420, 2)
	m += (ridged(nz, wx, wy, 170) - 0.55) * 0.24 * m * smoothstep(30, 170, m)
	m = math.max(0, m) * smoothstep(20, 170, dF)

	-- near rises just outside the hub
	local near = (17 + 12 * n2(nz, x, y, 170, 7) + 6 * n2(nz, x, y, 55, 8)) * smoothstep(0, 95, dF)
	return smax(math.max(near, 0), m, 18)
end

-- Fits the cascade channel floors to the real ground once per build: each floor sits just
-- under the mountain, never rises toward its outlet, and the fixed end points stay (the lip,
-- the chute top). Returns the largest amount a floor had to stand above the ground (0 if none).
function Field.fitFlows(nz: Noise): number
	local worst = 0
	for _, list in { Cascade.Creek, Cascade.SideStream } do
		local last = list[#list]
		for i = 1, #list - 1 do
			local fp = list[i]
			local ground = Field.rawHeight(nz, fp.p) - 1.4
			local h = math.min(fp.h, ground)
			if i > 1 then
				local prev = list[i - 1]
				h = math.min(h, prev.h - 0.12 * (fp.p - prev.p).Magnitude)
			end
			local remaining = (last.p - fp.p).Magnitude
			h = math.max(h, last.h + 0.05 * remaining)
			worst = math.max(worst, h - ground)
			fp.h = h
		end
	end
	-- the tarn holds its water just above the side stream it feeds
	local outlet = Cascade.SideStream[1]
	Cascade.Tarn.water = outlet.h + 1.3
	Cascade.Tarn.floor = Cascade.Tarn.water - 4
	return worst
end

-- Height and water at a plan point (before gullies, which need the whole grid).
function Field.sample(nz: Noise, p: Vector2): Sample
	local dF = Field.hubDistance(p)
	local e = Field.lakeE(p)
	local x, y = p.X, p.Y
	local h = Field.rawHeight(nz, p)

	-- the waterfall system reshapes its zone (stepped cliff, ledge basin, creek, tarn, chute)
	local shaped = Cascade.shape(p, h)
	local keep = 0
	if shaped then
		h = shaped.h
		local band = 1 - smoothstep(Cascade.Band.full, Cascade.Band.fade, math.abs(x - Cascade.X))
		if y <= Cascade.lowerFaceY(x) then
			keep = band -- the cliff stands behind a narrow bank instead of ramping to the lake
		end
	end
	local wLake = smoothstep(1.08, 1.5, e)
	h *= wLake + (1 - wLake) * keep

	local sample: Sample = {
		h = h,
		water = shaped and shaped.water or nil,
		lake = false,
		bank = false,
		channel = shaped ~= nil and shaped.channel,
		hub = dF <= 0,
		far = 0,
		wet = shaped ~= nil and shaped.wetRock,
		zone = if shaped and shaped.ledge then "ledge" else "",
	}
	sample.far = smoothstep(-430, -600, y) + smoothstep(640, 820, math.abs(x)) * 0.6

	-- the plunge pool below the falls, joined to the lake
	local pool = Cascade.Pool
	local dp = (p - pool.centre).Magnitude
	if dp < pool.radius then
		sample.h = pool.floor + (Field.LakeLevel - 0.5 - pool.floor) * (dp / pool.radius) ^ 2.2
		sample.water = Field.LakeLevel
		sample.lake = true
		sample.wet = true
		sample.zone = "rocky"
		return sample
	end

	-- the lake: irregular shore inside the approved ellipse, shelves and a deep middle
	local inLake, floor, zone = Field.lakeShape(p)
	if inLake then
		sample.h = floor
		sample.water = Field.LakeLevel
		sample.lake = true
		sample.zone = zone
		return sample
	elseif e < 1.12 and sample.h < 3 and keep < 0.5 then
		sample.bank = true
		sample.zone = if zone == "rocky" then "rocky" elseif zone == "beach" then "beach" else "damp"
	end

	-- outlet gorge draining east from the lake's east end
	local outlet = Field.Outlet
	local dO, along = Field.polylineDistance(outlet.points, p)
	if dO < outlet.half + 30 then
		local outletFloor = outlet.floor0 + (outlet.floor1 - outlet.floor0) * along
		if dO < outlet.half then
			sample.h = outletFloor
			sample.water = math.min(Field.LakeLevel, outletFloor + 2.5)
			sample.channel = true
		else
			sample.h = math.min(sample.h, outletFloor + (dO - outlet.half) * 1.4)
			if dO < outlet.half + 4 then
				sample.bank = true
			end
		end
	end
	return sample
end

-- The park stream (plan points from the layout): a shallow channel with stone banks.
function Field.applyStream(sample: Sample, streamPoints: { Vector2 }, p: Vector2)
	local d = Field.polylineDistance(streamPoints, p)
	local spring = (p - streamPoints[1]).Magnitude
	if d < Field.StreamHalf or spring < 8 then
		sample.h = Field.StreamFloor
		sample.water = Field.LakeLevel
		sample.channel = true
	elseif d < Field.StreamBank or spring < 11 then
		sample.bank = true
	end
end

return Field
