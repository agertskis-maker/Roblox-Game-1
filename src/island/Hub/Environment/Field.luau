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

local Field = {}

Field.VERSION = "island-env-1"
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
		heights = { 300, 192, 146, 140 },
		left = { 62, 66, 88, 92 }, -- widens into the cliff band round the falls
		right = { 46, 52, 76, 80 },
		profile = 1.7,
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
Field.Pool = { centre = Vector2.new(-120, -268), radius = 10, floor = -6 }
Field.Fall = { x = -120, cliffY = -280, lip = 118, notchHalf = 8, width = 16 }
Field.Creek = { y0 = -282, y1 = -360, rise = 0.08, depth = 2.5 }
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
}

-- Height and water at a plan point (before gullies, which need the whole grid).
function Field.sample(nz: Noise, p: Vector2): Sample
	local dF = Field.hubDistance(p)
	local e = Field.lakeE(p)
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
	local h = smax(math.max(near, 0), m, 18)

	-- lake shores ramp in, except at the waterfall, where a cliff stands behind a narrow bank
	local wLake = smoothstep(1.08, 1.5, e)
	local cliffSide = smoothstep(95, 60, math.abs(x - Field.Fall.x))
	local cliff = smoothstep(Field.Fall.cliffY + 3, Field.Fall.cliffY - 1, y)
	h *= wLake + (cliff - wLake) * cliffSide

	local sample: Sample = { h = h, water = nil, lake = false, bank = false, channel = false, hub = dF <= 0, far = 0 }
	sample.far = smoothstep(-430, -600, y) + smoothstep(640, 820, math.abs(x)) * 0.6

	-- lake basin and banks
	if e < 1 then
		sample.h = Field.LakeLevel - Field.Lake.depth * (1 - e * e) ^ 0.6
		sample.water = Field.LakeLevel
		sample.lake = true
		return sample
	elseif e < 1.1 and sample.h < 3 then
		sample.bank = true
	end

	-- plunge pool below the falls
	local pool = Field.Pool
	local dp = (p - pool.centre).Magnitude
	if dp < pool.radius then
		sample.h = pool.floor + (Field.LakeLevel - pool.floor) * (dp / pool.radius) ^ 3
		sample.water = Field.LakeLevel
		sample.lake = true
		return sample
	end

	-- notch and creek above the falls
	local fall = Field.Fall
	local creek = Field.Creek
	if math.abs(x - fall.x) < fall.notchHalf and y <= creek.y0 + 2 and y > creek.y1 then
		local floor = fall.lip + (creek.y0 - y) * creek.rise
		if sample.h > floor then
			sample.h = floor
			-- the creek water stops a little short of the lip; the falling sheets carry it over
			if y < creek.y0 - 2 then
				sample.water = floor + creek.depth
			end
			sample.channel = true
		end
	end

	-- outlet gorge draining east from the lake's east end
	local outlet = Field.Outlet
	local dO, along = Field.polylineDistance(outlet.points, p)
	if dO < outlet.half + 30 then
		local floor = outlet.floor0 + (outlet.floor1 - outlet.floor0) * along
		if dO < outlet.half then
			sample.h = floor
			sample.water = math.min(Field.LakeLevel, floor + 2.5)
			sample.channel = true
		else
			sample.h = math.min(sample.h, floor + (dO - outlet.half) * 1.4)
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
