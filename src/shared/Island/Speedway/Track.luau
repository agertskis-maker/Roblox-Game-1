--!strict
-- Speedway road, edges and raised structure by level (Lane 3, presentation only). Each function
-- builds one feature of the look ladder (Look.Features) into its folder. The road follows the
-- level's lap path (Path), so the cars and the road always agree. The asphalt layers are the
-- island's approved Task 3 base track (moved here from Hub/Recipes/Plot), which now arrives at
-- level 4 (Adam, 2026-10-28; decision 0025). The raised part (levels 10 to 12) is a far turn that
-- climbs as it turns and a straight ramp back down; no spiral (Adam: simpler ramps).

local Ctx = require(script.Parent.Ctx)
local Kit = require(script.Parent.Kit)
local Path = require(script.Parent.Path)

local Track = {}

type Ctx = Ctx.Ctx
type LapPath = Path.LapPath

local HALF_W = Path.HalfWidth
local R = Path.TurnRadius
local uS = Path.StraightsStart

-- Height layers above the road surface, so paint never shares a plane with what it lies on and the
-- scanner stays at zero (big round M1). Paint is one coat; the checkered line sits on top of it.
local PAINT = 0.12
local PAINT_THICK = 0.12
local CHECKER_TOP = 0.18

-- colours (the Task 3 base track's, plus the early dirt and the raised deck)
Track.Colours = {
	Asphalt = Color3.fromRGB(58, 62, 70),
	White = Color3.new(1, 1, 1),
	CurbRed = Color3.fromRGB(214, 62, 56),
	StripeA = Color3.fromRGB(104, 178, 84),
	StripeB = Color3.fromRGB(88, 160, 72),
	Dirt = Color3.fromRGB(186, 128, 80), -- packed dirt, warm (reference 1)
	DirtRaked = Color3.fromRGB(198, 144, 96),
	Rut = Color3.fromRGB(150, 100, 62),
	Chalk = Color3.fromRGB(250, 248, 240),
	Wall = Color3.fromRGB(34, 138, 146), -- teal lower band (Raceway round 2)
	WallCap = Color3.fromRGB(244, 236, 214), -- cream upper edge
	WallEnd = Color3.fromRGB(244, 127, 112), -- coral end marker
	DeckBody = Color3.fromRGB(36, 58, 98),
	Rail = Color3.fromRGB(196, 202, 210),
	Concrete = Color3.fromRGB(214, 210, 200),
	Checker = Color3.fromRGB(28, 28, 32),
}
local C = Track.Colours

-- Distances along `path` from s0 to s1 for building strips: whole straights where nothing
-- changes, every `step` studs where the height or bank changes, chord steps on steady arcs.
local function samples(path: LapPath, s0: number, s1: number, step: number?): { number }
	local out = { s0 }
	local fine = step or 3
	local s = s0
	while s < s1 - 1e-6 do
		local probe = s + 0.01
		local seg
		for _, g in path.segments do
			if probe >= g.s0 and probe < g.s0 + g.length then
				seg = g
				break
			end
		end
		local segEnd = if seg then seg.s0 + seg.length else s1
		local stop = math.min(segEnd, s1)
		-- also break at the height and bank knots, so only the easing pieces are sampled finely
		for _, knots in { path.heights, path.banks } do
			for _, knot in knots do
				if knot.s > s + 1e-3 and knot.s < stop then
					stop = knot.s
				end
			end
		end
		local n = 1
		-- whether the height or bank changes over this piece (constant bank is fine at chord steps)
		local varies = false
		local h0, b0 = Path.height(path, s), Path.bank(path, s)
		for k = 1, 8 do
			local q = s + (stop - s) * k / 8
			if math.abs(Path.height(path, q) - h0) > 1e-4 or math.abs(Path.bank(path, q) - b0) > 1e-4 then
				varies = true
				break
			end
		end
		if seg and seg.kind == "arc" then
			local chord = 2 * math.acos(1 - 0.15 / (seg.radius + HALF_W + 1)) * seg.radius
			n = math.ceil((stop - s) / (if varies then math.min(chord, fine) else chord))
		elseif seg and varies then
			n = math.ceil((stop - s) / fine)
		end
		for k = 1, n do
			table.insert(out, s + (stop - s) * k / n)
		end
		s = stop
	end
	return out
end
Track.samples = samples

-- A strip layer along the path between consecutive samples: `offset` to the right of travel,
-- top `rise` off the road surface.
local function layer(
	parent: Instance,
	ctx: Ctx,
	path: LapPath,
	list: { number },
	offset: number | (number) -> number,
	width: number | (number) -> number,
	thickness: number,
	rise: number,
	options: Kit.PartOptions | (number, number) -> Kit.PartOptions,
	overlap: number
)
	for i = 1, #list - 1 do
		local sa, sb = list[i], list[i + 1]
		local oa = if type(offset) == "function" then offset(sa) else offset
		local ob = if type(offset) == "function" then offset(sb) else offset
		local a = Ctx.onPath(ctx, path, sa, oa, rise)
		local b = Ctx.onPath(ctx, path, sb, ob, rise)
		local w = if type(width) == "function" then width((sa + sb) / 2) else width
		local o = if type(options) == "function" then options(i, (sa + sb) / 2) else options
		Kit.slab(parent, a.Position, b.Position, (a.UpVector + b.UpVector) / 2, w, thickness, o, overlap)
	end
end

-- The barrier opens where the pit lanes join the straights (Hub/Layout.inPitGap).
local function inPitGap(p: Vector2): boolean
	return math.abs(p.X) > R + 5 and p.Y > uS - 2 and p.Y < uS + 17
end
Track.inPitGap = inPitGap

local function onArc(path: LapPath, s: number): boolean
	for _, seg in path.segments do
		if seg.kind == "arc" and s >= seg.s0 - 1e-6 and s < seg.s0 + seg.length - 1e-6 then
			return true
		end
	end
	return false
end

-- Edge meshes (hay, tyres, rope, tyre wall) along the path at `offset`, every `spacing`, the
-- mesh's front toward the road. `keep(s, p)` filters positions.
local function runs(
	parent: Instance,
	ctx: Ctx,
	path: LapPath,
	s0: number,
	s1: number,
	offset: number,
	name: string,
	spacing: number,
	keep: ((number, Vector2) -> boolean)?
)
	local count = math.max(1, math.floor((s1 - s0) / spacing + 0.5))
	local step = (s1 - s0) / count
	for k = 0, count - 1 do
		local s = s0 + step * (k + 0.5)
		local p, d = Path.planPoint(path, s)
		local out = Vector2.new(d.Y, -d.X)
		local at = p + out * offset
		if not inPitGap(at) and (not keep or keep(s, at)) then
			Ctx.place(ctx, parent, name, at.X, at.Y, -out)
		end
	end
end

-- ------------------------------------------------------------------ dirt (levels 1 to 3)

local function dirtSurface(folder: Folder, ctx: Ctx, colour: Color3)
	local path = Path.forLevel(1)
	layer(folder, ctx, path, samples(path, 0, path.length), 0, HALF_W * 2, 0.4, 0, {
		name = "Surface",
		color = colour,
		collide = true,
		castShadow = false,
	}, 2)
end

function Track.dirt(folder: Folder, ctx: Ctx)
	dirtSurface(folder, ctx, C.Dirt)
end

function Track.dirtRaked(folder: Folder, ctx: Ctx)
	dirtSurface(folder, ctx, C.DirtRaked)
	-- fine rake lines along the lap: a groomed track
	local path = Path.forLevel(1)
	for _, off in { -5, -2.5, 2.5, 5 } do
		layer(folder, ctx, path, samples(path, 0, path.length), off, 0.18, 0.02, PAINT, {
			name = "RakeLine",
			color = C.Dirt,
			castShadow = false,
		}, 0.2)
	end
end

-- Level 1's tyre ruts: two worn grooves either side of the racing line.
function Track.ruts(folder: Folder, ctx: Ctx)
	local path = Path.forLevel(1)
	for _, off in { -4.2, -1.6, 1.6, 4.2 } do
		layer(folder, ctx, path, samples(path, 0, path.length), off, 0.9, 0.03, PAINT, {
			name = "Rut",
			color = C.Rut,
			castShadow = false,
		}, 0.4)
	end
end

local function startLine(folder: Folder, ctx: Ctx, colour: Color3, name: string)
	local cf = Ctx.onPath(ctx, Path.forLevel(1), 0, 0, CHECKER_TOP)
	Kit.part(folder, Vector3.new(HALF_W * 2, 0.04, 0.7), cf * CFrame.new(0, -0.02, 0), {
		name = name,
		color = colour,
		castShadow = false,
	})
end

function Track.chalkLine(folder: Folder, ctx: Ctx)
	startLine(folder, ctx, C.Chalk, "ChalkLine")
end

function Track.paintedLine(folder: Folder, ctx: Ctx)
	startLine(folder, ctx, C.White, "StartLine")
end

-- Hay bales round the outside (level 1 all round; from level 2 only on the turns, the rope fence
-- takes the straights) and old tyres half-buried round the inside.
function Track.hay(folder: Folder, ctx: Ctx, turnsOnly: boolean)
	local path = Path.forLevel(1)
	local spacing = Kit.meta("SwHayRun", "length", 9.3) + 0.9
	runs(folder, ctx, path, 0, path.length, HALF_W + 1.4, "SwHayRun", spacing, function(s)
		return not turnsOnly or onArc(path, s)
	end)
end

function Track.rope(folder: Folder, ctx: Ctx)
	local path = Path.forLevel(1)
	local spacing = Kit.meta("SwRopeFence", "length", 9) + 0.3
	runs(folder, ctx, path, 0, path.length, HALF_W + 1.2, "SwRopeFence", spacing, function(s)
		return not onArc(path, s)
	end)
end

function Track.tyresInner(folder: Folder, ctx: Ctx)
	local path = Path.forLevel(1)
	local spacing = Kit.meta("SwTyreRun", "length", 8) + 1.2
	runs(folder, ctx, path, 0, path.length, -(HALF_W + 0.9), "SwTyreRun", spacing)
end

-- ------------------------------------------------------------------ asphalt (level 4 on)

-- Level 12: how much wider the ground right straight is, toward the infield, where the loop stands
-- (Adam: "make that part of the track wider so that the loop actually fits"). 0 elsewhere. The
-- extra width blends in and out over a smooth taper, so the loop stands on the road, not on a pad.
local LOOP_WIDEN = 6.8
local function loopWiden(u: number): number
	local lo = Path.Loop
	local a0, a1 = lo.SBendU + 2, lo.SBendU + lo.SBend
	local b1 = lo.SBendU + 2 * lo.SBend + 2 * lo.Runout
	local b0 = b1 - 14
	local function ease(t: number): number
		t = math.clamp(t, 0, 1)
		return t * t * (3 - 2 * t)
	end
	return LOOP_WIDEN * ease((u - a0) / (a1 - a0)) * (1 - ease((u - b0) / (b1 - b0)))
end

-- The one marking language of the whole circuit, on every level from 4 up (M4-01): a white edge
-- line on both sides following the road, red and white curbs only on the inside of the corners, no
-- centre line. The outer line stops where a pit lane joins and the pit lane's own lines take over.
-- `widened` is the level 12 right straight: the road, its inner line and nothing else move.
local function asphalt(folder: Folder, ctx: Ctx, path: LapPath, ranges: { { number } }, widened: boolean?)
	local function extra(s: number): number
		if not widened then
			return 0
		end
		local p = Path.planPoint(path, s)
		return if p.X > 0 and p.Y > uS and p.Y < uS + Path.Straight then loopWiden(p.Y) else 0
	end
	for _, range in ranges do
		local list: { number } = {}
		for _, s in samples(path, range[1], range[2]) do
			local last = list[#list]
			if widened and last then
				local n = math.ceil((s - last) / 1.5)
				for k = 1, n - 1 do
					table.insert(list, last + (s - last) * k / n)
				end
			end
			table.insert(list, s)
		end
		layer(folder, ctx, path, list, 0, HALF_W * 2, 0.4, 0, {
			name = "Surface",
			color = C.Asphalt,
			material = Enum.Material.Asphalt,
			collide = true,
			castShadow = false,
		}, 2)
		layer(
			folder,
			ctx,
			path,
			list,
			function(s)
				return -(HALF_W - 0.6) - extra(s)
			end,
			0.3,
			PAINT_THICK,
			PAINT,
			{
				name = "EdgeLine",
				color = C.White,
				castShadow = false,
			},
			0.2
		)
		local pieces: { { number } } = {}
		local run: { number } = {}
		for _, s in list do
			local p, d = Path.planPoint(path, s)
			local at = p + Vector2.new(d.Y, -d.X) * (HALF_W - 0.6)
			if inPitGap(Vector2.new(at.X + (if at.X > 0 then 5 else -5), at.Y)) then
				if #run > 1 then
					table.insert(pieces, run)
				end
				run = {}
			else
				table.insert(run, s)
			end
		end
		if #run > 1 then
			table.insert(pieces, run)
		end
		for _, piece in pieces do
			layer(folder, ctx, path, piece, HALF_W - 0.6, 0.3, PAINT_THICK, PAINT, {
				name = "EdgeLine",
				color = C.White,
				castShadow = false,
			}, 0.2)
		end
		-- the widening itself: a smooth edge of long thin triangles butted to the road's inner edge,
		-- at the road's own height and in its own asphalt, so the two read as one surface
		if widened then
			local lo = Path.Loop
			local u0, u1 = lo.SBendU, lo.SBendU + 2 * lo.SBend + 2 * lo.Runout
			local x0 = R - HALF_W + 0.02
			local fill = {
				name = "Surface",
				color = C.Asphalt,
				material = Enum.Material.Asphalt,
				collide = true,
				castShadow = false,
			}
			local n = math.ceil((u1 - u0) / 2)
			for k = 0, n - 1 do
				local ua, ub = u0 + (u1 - u0) * k / n, u0 + (u1 - u0) * (k + 1) / n
				local a, b = Ctx.at(ctx, x0, ua), Ctx.at(ctx, x0, ub)
				local c = Ctx.at(ctx, x0 - loopWiden(ub), ub)
				local d = Ctx.at(ctx, x0 - loopWiden(ua), ua)
				Kit.triangle(folder, a, b, c, Path.TrackTop, 0.4, fill)
				Kit.triangle(folder, a, c, d, Path.TrackTop, 0.4, fill)
			end
		end
		-- curbs: one white band round the inside of each corner with red blocks on top of it, so no
		-- two curb faces ever share a plane
		local i = 0
		for k = 1, #list - 1 do
			local sa, sb = list[k], list[k + 1]
			if onArc(path, (sa + sb) / 2) then
				i += 1
				local a = Ctx.onPath(ctx, path, sa, -HALF_W - 0.5, 0.12)
				local b = Ctx.onPath(ctx, path, sb, -HALF_W - 0.5, 0.12)
				local up = (a.UpVector + b.UpVector) / 2
				Kit.slab(folder, a.Position, b.Position, up, 1, 0.3, {
					name = "Curb",
					color = C.White,
					collide = true,
					castShadow = false,
				}, 0.3)
				if i % 2 == 0 then
					local ra = Ctx.onPath(ctx, path, sa, -HALF_W - 0.5, 0.22)
					local rb = Ctx.onPath(ctx, path, sb, -HALF_W - 0.5, 0.22)
					Kit.slab(folder, ra.Position, rb.Position, up, 0.9, 0.08, {
						name = "CurbRed",
						color = C.CurbRed,
						castShadow = false,
					}, 0)
				end
			end
		end
	end
end

function Track.asphaltFlat(folder: Folder, ctx: Ctx)
	local path = Path.forLevel(4)
	asphalt(folder, ctx, path, { { 0, path.length } })
end

function Track.asphaltBanked(folder: Folder, ctx: Ctx)
	local path = Path.forLevel(9)
	asphalt(folder, ctx, path, { { 0, path.length } })
end

-- Levels 10 to 12: the asphalt that stays on the ground (the main straight from the descent's
-- landing through the finish, the near turn and the whole right straight up to the far turn).
function Track.groundRanges(path: LapPath): { { number } }
	local d = path.marks.descent
	local far = path.marks.farCurve
	return { { d[2], path.length }, { 0, far[1] + 2 } }
end

function Track.asphaltGround(folder: Folder, ctx: Ctx, widened: boolean?)
	local path = Path.forLevel(10)
	asphalt(folder, ctx, path, Track.groundRanges(path), widened)
end

-- Checkered start / finish line: 8 tiles across, 3 rows (Task 3 base track).
function Track.checker(folder: Folder, ctx: Ctx)
	local path = Path.forLevel(4)
	local tile = HALF_W * 2 / 8
	local base = Ctx.onPath(ctx, path, 0, 0, CHECKER_TOP)
	for row = 0, 2 do
		for k = 0, 7 do
			Kit.part(
				folder,
				Vector3.new(tile, 0.04, tile),
				base * CFrame.new(-HALF_W + tile * (k + 0.5), -0.02, -(row - 1) * tile),
				{
					name = "Checker",
					color = if (row + k) % 2 == 0 then C.Checker else C.White,
					castShadow = false,
				}
			)
		end
	end
end

-- The mowed-stripe infield (Task 3), clipped to the infield's rounded ends.
function Track.infield(folder: Folder, ctx: Ctx)
	local rr = R - HALF_W + 0.3
	local uNear, uFar = uS, uS + Path.Straight
	local width = 3.25
	local strips = math.floor(2 * rr / width)
	local x0 = -strips * width / 2
	for k = 0, strips - 1 do
		local xa, xb = x0 + k * width, x0 + (k + 1) * width
		local half = math.sqrt(math.max(0, rr * rr - math.min(math.abs(xa), math.abs(xb)) ^ 2))
		local a = Ctx.at(ctx, (xa + xb) / 2, uNear - half, 0.09)
		local b = Ctx.at(ctx, (xa + xb) / 2, uFar + half, 0.09)
		Kit.slab(folder, a, b, Vector3.yAxis, width, 0.08, {
			name = "Stripe",
			color = if k % 2 == 0 then C.StripeA else C.StripeB,
			material = Enum.Material.Grass,
			castShadow = false,
		}, 0)
	end
end

-- The neat painted tyre wall round the outside (replaces hay and rope at level 4).
function Track.tyreWall(folder: Folder, ctx: Ctx, which: string)
	local path = if which == "ground" then Path.forLevel(10) else Path.forLevel(4)
	local spacing = Kit.meta("SwTyreWall", "length", 9) + 0.4
	local ranges: { { number } } = if which == "ground" then Track.groundRanges(path) else { { 0, path.length } }
	for _, range in ranges do
		runs(folder, ctx, path, range[1], range[2], HALF_W + 1.3, "SwTyreWall", spacing, function(s)
			if which == "straights" or which == "ground" then
				return not onArc(path, s)
			end
			return true
		end)
	end
end

-- ------------------------------------------------------------------ banked turns (level 9 on)

-- Raised outer walls on a banked turn and catch fencing on top (minor detail). Raceway round 2
-- (Adam, 2026-10-29; no advertising): a broad teal wall with a cream upper edge and one coral end
-- marker at each end, no banners. `turn` is "near" or "far"; the near turn (facing the plaza)
-- gets only a low lip, so the plaza sees the track over it.
function Track.bankWalls(major: Folder, minor: Folder, ctx: Ctx, turn: string)
	local path = Path.forLevel(9)
	local seg = if turn == "near" then path.segments[2] else path.segments[4]
	local a, b = seg.s0 - Path.BankEase, seg.s0 + seg.length + Path.BankEase
	-- the near turn faces the plaza: a lower lip and no catch fence, so the track reads over it
	local lip = if turn == "near" then 0.4 else 2.2
	local edgeTall = math.min(0.3, lip - 0.05) -- the cream upper edge
	local list = samples(path, a, b, 3)
	local ends: { { a: Vector3, b: Vector3, height: number } } = {}
	for i = 1, #list - 1 do
		local sa, sb = list[i], list[i + 1]
		local pa, da = Path.planPoint(path, sa)
		local pb, db = Path.planPoint(path, sb)
		local oa = pa + Vector2.new(da.Y, -da.X) * (HALF_W + 0.9)
		local ob = pb + Vector2.new(db.Y, -db.X) * (HALF_W + 0.9)
		if not inPitGap((oa + ob) / 2) then
			local bank = math.rad(Path.bank(path, (sa + sb) / 2))
			local edge = Path.TrackTop + 2 * HALF_W * math.sin(bank)
			local height = edge + lip
			local wa, wb = Ctx.at(ctx, oa.X, oa.Y, height), Ctx.at(ctx, ob.X, ob.Y, height)
			Kit.slab(
				major,
				wa - Vector3.yAxis * edgeTall,
				wb - Vector3.yAxis * edgeTall,
				Vector3.yAxis,
				0.9,
				height - edgeTall,
				{
					name = "BankWall",
					color = C.Wall,
					collide = true,
					castShadow = false,
				},
				0.5
			)
			Kit.slab(major, wa, wb, Vector3.yAxis, 1.12, edgeTall, {
				name = "BankWallCap",
				color = C.WallCap,
				collide = true,
				castShadow = false,
			}, 0.5)
			table.insert(ends, { a = wa, b = wb, height = height })
		end
	end
	-- one restrained coral marker at each end of the wall (a short painted block over the wall end)
	if #ends > 0 then
		for _, which in { ends[1], ends[#ends] } do
			local along = (which.b - which.a).Unit
			local tip = if which == ends[1] then which.a + along * 0.6 else which.b - along * 0.6
			Kit.slab(
				major,
				tip - along * 0.7 + Vector3.yAxis * 0.1,
				tip + along * 0.7 + Vector3.yAxis * 0.1,
				Vector3.yAxis,
				1.16,
				which.height + 0.1,
				{
					name = "BankWallEnd",
					color = C.WallEnd,
					castShadow = false,
				},
				0
			)
		end
	end
	-- catch fence runs on the wall top, along the full-bank part of the turn
	local count = if turn == "near" then 0 else math.floor(seg.length / (Kit.meta("SwCatchFence", "length", 9) + 0.1))
	local step = seg.length / math.max(count, 1)
	for k = 0, count - 1 do
		local s = seg.s0 + step * (k + 0.5)
		local p, d = Path.planPoint(path, s)
		local out = Vector2.new(d.Y, -d.X)
		local at = p + out * (HALF_W + 0.9)
		if not inPitGap(at) then
			local bank = math.rad(Path.bank(path, s))
			local top = Path.TrackTop + 2 * HALF_W * math.sin(bank) + lip
			Ctx.place(ctx, minor, "SwCatchFence", at.X, at.Y, -out, top)
		end
	end
end

-- ------------------------------------------------------------------ raised track (level 10 on)

local DECK_THICK = 1.4
local CLEAR = 7 -- below this underside height the deck sits on a solid fill (no gap to crawl into)

-- True when plan point p is on the ground asphalt that stays at levels 10 to 12 (columns never
-- stand on it; the deck spans over it).
local function onGroundRoad(p: Vector2): boolean
	local reach = HALF_W + 1.5
	if p.Y <= uS then
		local r = (p - Vector2.new(0, uS)).Magnitude
		return math.abs(r - R) < reach
	end
	if math.abs(p.X + R) < reach and p.Y < Path.DescentLandU + 3 then
		return true
	end
	if math.abs(p.X - R) < reach and p.Y < uS + Path.Straight + 1 then
		return true
	end
	return false
end
Track.onGroundRoad = onGroundRoad

export type DeckOptions = {
	width: ((number) -> number)?,
	rails: boolean?,
	supports: boolean?,
	stripes: boolean?,
}

-- The raised road between s0 and s1 on `path`: asphalt road, navy deck body, orange edge stripes
-- and parapets (minor detail; they are also the visitors' guard), columns where the
-- underside is high, a solid fill where it is low.
function Track.deck(major: Folder, minor: Folder, ctx: Ctx, path: LapPath, s0: number, s1: number, o: DeckOptions?)
	local opts: DeckOptions = o or {}
	local widthAt = opts.width or function()
		return HALF_W * 2
	end
	local list = samples(path, s0, s1, 4)
	layer(major, ctx, path, list, 0, widthAt, 0.4, 0, {
		name = "DeckRoad",
		color = C.Asphalt,
		material = Enum.Material.Asphalt,
		collide = true,
		castShadow = false,
	}, 0.6)
	layer(
		major,
		ctx,
		path,
		list,
		0,
		function(s)
			return widthAt(s) + 0.8
		end,
		DECK_THICK,
		-0.4,
		{
			name = "DeckBody",
			color = C.DeckBody,
			collide = true,
		},
		0.6
	)
	if opts.stripes ~= false then
		for _, side in { -1, 1 } do
			layer(
				minor,
				ctx,
				path,
				list,
				function(s)
					return side * (widthAt(s) / 2 - 0.45)
				end,
				0.3,
				PAINT_THICK,
				PAINT,
				{
					name = "DeckLine",
					color = C.White,
					castShadow = false,
				},
				0.2
			)
		end
	end
	if opts.rails ~= false then
		-- a solid navy parapet each side (the visitors' guard): one strip per slice, no posts
		for _, side in { -1, 1 } do
			layer(
				minor,
				ctx,
				path,
				list,
				function(s)
					return side * (widthAt(s) / 2 + 0.1)
				end,
				0.4,
				1.65,
				1.25,
				{
					name = "GuardRail",
					color = C.Rail,
					collide = true,
					castShadow = false,
				},
				0.3
			)
		end
	end
	if opts.supports == false then
		return
	end
	-- supports: every ~12 studs, a column under each deck edge where the underside clears CLEAR;
	-- under lower deck, a solid fill down to the ground
	for i = 1, #list - 1 do
		local sa, sb = list[i], list[i + 1]
		local mid = (sa + sb) / 2
		local cf = Ctx.onPath(ctx, path, mid)
		local w = widthAt(mid)
		local bank = math.rad(Path.bank(path, mid))
		local under = cf.Position.Y - 0.4 - DECK_THICK - math.abs(math.sin(bank)) * w / 2
		if under < CLEAR and under > 0.05 then
			local a = Ctx.onPath(ctx, path, sa).Position
			local b = Ctx.onPath(ctx, path, sb).Position
			local flatA, flatB = Vector3.new(a.X, 0, a.Z), Vector3.new(b.X, 0, b.Z)
			local len = (flatB - flatA).Magnitude
			if len > 0.05 then
				local centre = (flatA + flatB) / 2 + Vector3.yAxis * (under / 2)
				Kit.part(
					major,
					Vector3.new(w + 0.4, under, len + 0.6),
					CFrame.lookAt(centre, centre + (flatB - flatA)),
					{
						name = "DeckFill",
						color = C.Concrete,
						collide = true,
					}
				)
			end
		end
	end
	local total = s1 - s0
	local count = math.max(1, math.floor(total / 12))
	for k = 0, count do
		local s = s0 + total * k / count
		local cf = Ctx.onPath(ctx, path, s)
		local w = widthAt(s)
		for _, side in { -1, 1 } do
			local top = cf * CFrame.new(side * (w / 2 - 1.2), -0.4 - DECK_THICK, 0)
			local under = top.Position.Y
			local foot = Vector3.new(top.Position.X, 0, top.Position.Z)
			local localFoot = ctx.frame:Inverse() * foot
			local plan = Vector2.new(localFoot.X, -localFoot.Z)
			if under >= CLEAR and not onGroundRoad(plan) then
				local heading = cf.LookVector * Vector3.new(1, 0, 1)
				if heading.Magnitude > 1e-3 then
					local base = CFrame.lookAt(foot, foot + heading.Unit)
					local column = Kit.place("SwColumn", base, Vector3.new(1, under - 1.2, 1))
					if column then
						column.CanCollide = true
						column.CanQuery = true
						column.Parent = major
					else
						Kit.part(
							major,
							Vector3.new(under - 1.2, 2.2, 2.2),
							base * CFrame.new(0, (under - 1.2) / 2, 0) * CFrame.Angles(0, 0, math.pi / 2),
							{
								name = "Column",
								color = C.Concrete,
								shape = Enum.PartType.Cylinder,
								collide = true,
							}
						)
					end
					local cap = Kit.place(
						"SwColumnCap",
						CFrame.lookAt(foot + Vector3.yAxis * under, foot + Vector3.yAxis * under + heading.Unit)
					)
					if cap then
						cap.Parent = major
					end
				end
			end
		end
	end
end

-- Levels 10 to 12: the far turn climbs from the ground to the deck as it turns.
function Track.farCurve(major: Folder, minor: Folder, ctx: Ctx)
	local path = Path.forLevel(10)
	local m = path.marks.farCurve
	Track.deck(major, minor, ctx, path, m[1], m[2])
end

-- Levels 10 to 12: the straight ramp back down the main straight.
function Track.descent(major: Folder, minor: Folder, ctx: Ctx)
	local path = Path.forLevel(10)
	local m = path.marks.descent
	Track.deck(major, minor, ctx, path, m[1], m[2])
end

-- Level 12: the loop on the widened right straight, built along the cars' own lap path out of
-- the track's own road, lines and curbs, so it reads as part of the circuit and the cars ride it
-- without clipping. The S-bends onto it and off it are painted with lane lines that run out of the
-- road's lines. Visitors walk under it: nothing here collides.
function Track.loop(major: Folder, minor: Folder, ctx: Ctx)
	local path = Path.forLevel(12)
	local lo = Path.Loop
	local l = path.marks.loop
	local halfLane = lo.Width / 2
	local list = {}
	for k = 0, 56 do
		table.insert(list, l[1] + (l[2] - l[1]) * k / 56)
	end
	layer(major, ctx, path, list, 0, lo.Width, 0.4, 0, {
		name = "LoopRoad",
		color = C.Asphalt,
		material = Enum.Material.Asphalt,
		castShadow = true,
	}, 0.5)
	for _, side in { -1, 1 } do
		layer(major, ctx, path, list, side * (halfLane + 0.35), 0.7, 0.7, 0.14, function(i)
			return {
				name = "LoopCurb",
				color = if i % 2 == 0 then C.CurbRed else C.White,
				castShadow = false,
			}
		end, 0)
		layer(minor, ctx, path, list, side * (halfLane - 0.6), 0.3, PAINT_THICK, PAINT, {
			name = "EdgeLine",
			color = C.White,
			castShadow = false,
		}, 0.1)
	end
	local right = path.marks.groundRight
	local into = samples(path, right[1] + (lo.SBendU - uS), l[1], 1.5)
	local outOf = samples(path, l[2], right[2] - (uS + Path.Straight - (lo.SBendU + 2 * lo.SBend + 2 * lo.Runout)), 1.5)
	-- the inner side of each lane is the road's own edge line; this is the line between them
	layer(minor, ctx, path, into, halfLane - 0.6, 0.3, PAINT_THICK, PAINT, {
		name = "LaneLine",
		color = C.White,
		castShadow = false,
	}, 0.1)
	layer(minor, ctx, path, outOf, -(halfLane - 0.6), 0.3, PAINT_THICK, PAINT, {
		name = "LaneLine",
		color = C.White,
		castShadow = false,
	}, 0.1)
end

-- Levels 11 and 12: a low eased hump on the ground right straight (a hop, no gap, no flying),
-- solid underneath and walkable.
function Track.hump(major: Folder, minor: Folder, ctx: Ctx)
	local path = Path.forLevel(11)
	local m = path.marks.hump
	local list = samples(path, m[1], m[2], 1.5)
	layer(major, ctx, path, list, 0, HALF_W * 2, 0.4 + Path.Hump.Height, 0, {
		name = "Hump",
		color = C.Asphalt,
		material = Enum.Material.Asphalt,
		collide = true,
		castShadow = false,
	}, 0.3)
	for _, side in { -1, 1 } do
		layer(minor, ctx, path, list, side * (HALF_W - 0.6), 0.3, PAINT_THICK, PAINT, {
			name = "HumpLine",
			color = C.White,
			castShadow = false,
		}, 0.1)
		-- a red side band so the hump reads from the plaza
		layer(major, ctx, path, list, side * (HALF_W + 0.08), 0.12, 0.4 + Path.Hump.Height, -0.08, {
			name = "HumpSide",
			color = C.CurbRed,
			castShadow = false,
		}, 0.02)
	end
end

return Track
