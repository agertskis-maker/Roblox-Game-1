--!strict
-- Speedway road, edges and raised structure by level (Lane 3, presentation only). Each function
-- builds one feature of the look ladder (Look.Features) into its folder. The road follows the
-- level's lap path (Path), so the cars and the road always agree. The asphalt layers are the
-- island's approved Task 3 base track (moved here from Hub/Recipes/Plot), which now arrives at
-- level 4 (Adam, 2026-10-28; decision 0025).

local Ctx = require(script.Parent.Ctx)
local Kit = require(script.Parent.Kit)
local KitIds = require(script.Parent.KitIds)
local Path = require(script.Parent.Path)

local Track = {}

type Ctx = Ctx.Ctx
type LapPath = Path.LapPath

local HALF_W = Path.HalfWidth
local R = Path.TurnRadius
local uS = Path.StraightsStart

-- colours (the Task 3 base track's, plus the early dirt and the raised deck)
Track.Colours = {
	Asphalt = Color3.fromRGB(58, 62, 70),
	Racing = Color3.fromRGB(46, 49, 56),
	LineYellow = Color3.fromRGB(246, 200, 60),
	White = Color3.new(1, 1, 1),
	CurbRed = Color3.fromRGB(214, 62, 56),
	StripeA = Color3.fromRGB(104, 178, 84),
	StripeB = Color3.fromRGB(88, 160, 72),
	Dirt = Color3.fromRGB(186, 128, 80), -- packed dirt, warm (reference 1)
	DirtRaked = Color3.fromRGB(198, 144, 96),
	Rut = Color3.fromRGB(150, 100, 62),
	Chalk = Color3.fromRGB(250, 248, 240),
	Wall = Color3.fromRGB(246, 246, 242),
	WallCap = Color3.fromRGB(36, 58, 98), -- navy
	DeckBody = Color3.fromRGB(36, 58, 98),
	DeckStripe = Color3.fromRGB(238, 140, 44), -- orange edge (reference 2)
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
		layer(folder, ctx, path, samples(path, 0, path.length), off, 0.18, 0.02, 0.01, {
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
		layer(folder, ctx, path, samples(path, 0, path.length), off, 0.9, 0.03, 0.01, {
			name = "Rut",
			color = C.Rut,
			castShadow = false,
		}, 0.4)
	end
end

local function startLine(folder: Folder, ctx: Ctx, colour: Color3, name: string)
	local cf = Ctx.onPath(ctx, Path.forLevel(1), 0, 0, 0.02)
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

-- The approved Task 3 base asphalt (surface, racing line, double yellow inside line, white outer
-- line, dashed centre line, red / white curbs on the turns) along `path` between s0 and s1.
local function asphalt(folder: Folder, ctx: Ctx, path: LapPath, ranges: { { number } })
	for _, range in ranges do
		local list = samples(path, range[1], range[2])
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
				if onArc(path, s) then
					-- wide on the straights, crossing to the inside at each turn's apex
					for _, seg in path.segments do
						if seg.kind == "arc" and s >= seg.s0 and s <= seg.s0 + seg.length then
							return 3 - 7 * math.sin(math.pi * (s - seg.s0) / seg.length)
						end
					end
				end
				return 3
			end,
			3.5,
			0.04,
			0.01,
			{
				name = "RacingLine",
				color = C.Racing,
				material = Enum.Material.Asphalt,
				castShadow = false,
			},
			0.8
		)
		for _, off in { -(HALF_W - 0.75), -(HALF_W - 1.35) } do
			layer(folder, ctx, path, list, off, 0.3, 0.04, 0.03, {
				name = "YellowLine",
				color = C.LineYellow,
				castShadow = false,
			}, 0.2)
		end
		layer(folder, ctx, path, list, HALF_W - 0.6, 0.3, 0.04, 0.03, {
			name = "WhiteLine",
			color = C.White,
			castShadow = false,
		}, 0.2)
		layer(folder, ctx, path, list, -HALF_W - 0.5, 1, 0.3, 0.12, function(i, s)
			return {
				name = "Curb",
				color = if onArc(path, s) and i % 2 == 0 then C.CurbRed else C.White,
				collide = true,
				castShadow = false,
			}
		end, 0.3)
		-- dashed centre line: 3 studs painted, 3 open
		local s = range[1]
		while s < range[2] - 3 do
			local dash = samples(path, s, s + 3, 1)
			layer(folder, ctx, path, dash, 0, 0.3, 0.04, 0.03, {
				name = "LaneDash",
				color = C.LineYellow,
				castShadow = false,
			}, 0.05)
			s += 6
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
-- landing through the finish, the near turn and the right straight up to the spiral).
function Track.groundRanges(path: LapPath): { { number } }
	local d = path.marks.descent
	local sp = path.marks.spiral
	return { { d[2], path.length }, { 0, sp[1] + 2 } }
end

function Track.asphaltGround(folder: Folder, ctx: Ctx)
	local path = Path.forLevel(10)
	asphalt(folder, ctx, path, Track.groundRanges(path))
end

-- Checkered start / finish line: 8 tiles across, 3 rows (Task 3 base track).
function Track.checker(folder: Folder, ctx: Ctx)
	local path = Path.forLevel(4)
	local tile = HALF_W * 2 / 8
	local base = Ctx.onPath(ctx, path, 0, 0, 0.05)
	for row = 0, 2 do
		for k = 0, 7 do
			Kit.part(
				folder,
				Vector3.new(tile, 0.06, tile),
				base * CFrame.new(-HALF_W + tile * (k + 0.5), -0.03, -(row - 1) * tile),
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

-- Raised outer walls on a banked turn (white with a navy cap), catch fencing on top (minor
-- detail) and fictional banners on the wall's inner face. `turn` is "near" or "far".
function Track.bankWalls(major: Folder, minor: Folder, ctx: Ctx, turn: string)
	local path = Path.forLevel(9)
	local seg = if turn == "near" then path.segments[2] else path.segments[4]
	local a, b = seg.s0 - Path.BankEase, seg.s0 + seg.length + Path.BankEase
	-- the near turn faces the plaza: a lower lip and no catch fence, so the track reads over it
	local lip = if turn == "near" then 0.9 else 2.2
	local list = samples(path, a, b, 3)
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
			Kit.slab(major, wa, wb, Vector3.yAxis, 0.9, height, {
				name = "BankWall",
				color = C.Wall,
				collide = true,
				castShadow = false,
			}, 0.5)
			Kit.slab(major, wa + Vector3.yAxis * 0.16, wb + Vector3.yAxis * 0.16, Vector3.yAxis, 1.15, 0.16, {
				name = "BankWallCap",
				color = C.WallCap,
				castShadow = false,
			}, 0.5)
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
			local top = Path.TrackTop + 2 * HALF_W * math.sin(bank) + lip + 0.16
			Ctx.place(ctx, minor, "SwCatchFence", at.X, at.Y, -out, top)
		end
	end
	-- three fictional banners on each turn wall's inner face (flat boards, the wall curves gently)
	local arts = { "BannerA", "BannerB", "BannerC", "BannerD" }
	for k, f in { 0.25, 0.5, 0.75 } do
		local s = seg.s0 + seg.length * f
		local p, d = Path.planPoint(path, s)
		local out = Vector2.new(d.Y, -d.X)
		local at = p + out * (HALF_W + 0.35)
		local bank = math.rad(Path.bank(path, s))
		local tall = math.min(1.5, lip - 0.15)
		local y = Path.TrackTop + 2 * HALF_W * math.sin(bank) + 0.05 + tall / 2
		local centre = Ctx.at(ctx, at.X, at.Y, y)
		local board =
			Kit.part(major, Vector3.new(tall * 6, tall, 0.08), CFrame.lookAt(centre, centre - Ctx.dir(ctx, out)), {
				name = "Banner",
				color = C.Wall,
				castShadow = false,
			})
		local art = (KitIds.Textures :: any)[arts[(k + ctx.index) % #arts + 1]]
		if art then
			local decal = Instance.new("Decal")
			decal.Texture = art
			decal.Face = Enum.NormalId.Front
			decal.Parent = board
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
	if math.abs(p.X - R) < reach and p.Y < Path.SpiralStartU + 4 then
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
				0.5,
				0.04,
				0.03,
				{
					name = "DeckStripe",
					color = C.DeckStripe,
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
					return side * (widthAt(s) / 2 + 0.2)
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
					Vector3.new(w + 0.8, under, len + 0.6),
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

local function loopWidth(path: LapPath): (number) -> number
	-- the S-bends either side of the loop narrow the road from 16 to the loop's 10
	local lo = Path.Loop
	local m = path.marks.loop
	local inA, inB = m[1] - lo.Runout - lo.SBend, m[1] - lo.Runout
	local outA, outB = m[2] + lo.Runout, m[2] + lo.Runout + lo.SBend
	return function(s: number): number
		local f = 0
		if s > inA and s < inB then
			f = (s - inA) / (inB - inA)
		elseif s >= inB and s <= outA then
			f = 1
		elseif s > outA and s < outB then
			f = 1 - (s - outA) / (outB - outA)
		end
		f = f * f * (3 - 2 * f)
		return HALF_W * 2 + (lo.Width - HALF_W * 2) * f
	end
end

function Track.spiral(major: Folder, minor: Folder, ctx: Ctx)
	local path = Path.forLevel(10)
	local m = path.marks.spiral
	Track.deck(major, minor, ctx, path, m[1], m[2])
end

function Track.raisedStraight(major: Folder, minor: Folder, ctx: Ctx)
	local path = Path.forLevel(10)
	local m = path.marks.raisedStraight
	Track.deck(major, minor, ctx, path, m[1], m[2])
end

function Track.farCurve(major: Folder, minor: Folder, ctx: Ctx)
	local path = Path.forLevel(10)
	local m = path.marks.farCurve
	Track.deck(major, minor, ctx, path, m[1], m[2])
end

function Track.descent(major: Folder, minor: Folder, ctx: Ctx)
	local path = Path.forLevel(10)
	local m = path.marks.descent
	Track.deck(major, minor, ctx, path, m[1], m[2])
end

-- Level 12: the raised straight with the loop. The S-bends and the platform under the loop; the
-- loop track itself is the SwLoopTrack mesh (its own run-outs included), which does not collide:
-- visitors walk across the platform under it, never up the loop.
function Track.raisedStraightLoop(major: Folder, minor: Folder, ctx: Ctx)
	local path = Path.forLevel(12)
	local m = path.marks.raisedStraight
	local lo = Path.Loop
	local l = path.marks.loop
	local width = loopWidth(path)
	Track.deck(major, minor, ctx, path, m[1], l[1] - lo.Runout, { width = width })
	Track.deck(major, minor, ctx, path, l[2] + lo.Runout, m[2], { width = width })
	-- the platform under the loop, between the two run-outs (plot frame)
	local entry = Path.planPoint(path, l[1] - lo.Runout)
	local exit = Path.planPoint(path, l[2] + lo.Runout)
	local top = Path.TrackTop + Path.DeckHeight
	local x0, x1 = entry.X - lo.Width / 2 - 1, exit.X + lo.Width / 2 + 1
	local u0, u1 = entry.Y - 0.3, exit.Y + 0.3
	-- the loop leans past the run-outs by its radius
	u0 = math.min(u0, entry.Y + lo.Runout - lo.Radius - 1)
	u1 = math.max(u1, exit.Y - lo.Runout + lo.Radius + 1)
	local function slab(name: string, colour: Color3, thick: number, rise: number, collide: boolean)
		local a = Ctx.at(ctx, (x0 + x1) / 2, u0, top + rise)
		local b = Ctx.at(ctx, (x0 + x1) / 2, u1, top + rise)
		Kit.slab(major, a, b, Vector3.yAxis, x1 - x0, thick, {
			name = name,
			color = colour,
			material = if name == "LoopPad" then Enum.Material.Asphalt else nil,
			collide = collide,
		}, 0)
	end
	slab("LoopPad", C.Asphalt, 0.4, 0, true)
	slab("LoopPadBody", C.DeckBody, DECK_THICK, -0.4, true)
	-- parapets round the pad, open where the S-bends join
	local function rail(xa: number, ua: number, xb: number, ub: number)
		local a = Ctx.at(ctx, xa, ua, top + 1.25)
		local b = Ctx.at(ctx, xb, ub, top + 1.25)
		Kit.slab(minor, a, b, Vector3.yAxis, 0.4, 1.65, {
			name = "GuardRail",
			color = C.Rail,
			collide = true,
			castShadow = false,
		}, 0)
	end
	rail(x0, u0, x0, u1)
	rail(x1, u0, x1, u1)
	rail(entry.X + lo.Width / 2 + 0.3, u0, x1, u0)
	rail(x0, u1, exit.X - lo.Width / 2 - 0.3, u1)
	-- four columns under the pad corners
	for _, x in { x0 + 1.5, x1 - 1.5 } do
		for _, u in { u0 + 1.5, u1 - 1.5 } do
			local foot = Ctx.at(ctx, x, u, 0)
			local h = top - 0.4 - DECK_THICK
			local base = CFrame.lookAt(foot, foot + Ctx.dir(ctx, Vector2.new(0, 1)))
			local column = Kit.place("SwColumn", base, Vector3.new(1, h - 1.2, 1))
			if column then
				column.CanCollide = true
				column.CanQuery = true
				column.Parent = major
			end
			local cap = Kit.place("SwColumnCap", base + Vector3.yAxis * h)
			if cap then
				cap.Parent = major
			end
		end
	end
end

function Track.loop(major: Folder, ctx: Ctx)
	local path = Path.forLevel(12)
	local l = path.marks.loop
	local pos, look = Path.sample(path, l[1])
	local flat = Vector3.new(look.X, 0, look.Z).Unit
	local wp = Ctx.world(ctx, pos)
	local base = CFrame.lookAt(wp, wp + Ctx.vector(ctx, flat))
	local loop = Kit.place("SwLoopTrack", base)
	if loop then
		loop.Parent = major
	end
end

-- Level 11: the jump on the ground right straight, flame decals on the run-up (flames, never
-- arrows or chevrons: those belong to the Hop), and invisible ramp colliders under the meshes.
function Track.jump(major: Folder, minor: Folder, ctx: Ctx)
	local j = Path.Jump
	local heading = Vector2.new(0, 1)
	local function ramp(name: string, u0: number, u1: number, h0: number, h1: number)
		local mid = (u0 + u1) / 2
		local base = Ctx.at(ctx, R, mid, Path.TrackTop)
		local mesh = Kit.place(name, CFrame.lookAt(base, base + Ctx.dir(ctx, heading)))
		if mesh then
			mesh.Parent = major
		end
		-- the walkable slope: a thin collider along the ramp top, and a block filling under it
		local a = Ctx.at(ctx, R, u0, Path.TrackTop + h0)
		local b = Ctx.at(ctx, R, u1, Path.TrackTop + h1)
		Kit.slab(major, a, b, Vector3.yAxis, 14, 0.5, {
			name = "JumpCollider",
			collide = true,
			transparency = 1,
			castShadow = false,
		}, 0)
		local low = math.min(h0, h1)
		if low > 0.3 then
			local c0, c1 = Ctx.at(ctx, R, u0, Path.TrackTop + low), Ctx.at(ctx, R, u1, Path.TrackTop + low)
			Kit.slab(major, c0, c1, Vector3.yAxis, 14, low, {
				name = "JumpCollider",
				collide = true,
				transparency = 1,
				castShadow = false,
			}, 0)
		end
	end
	ramp("SwJumpRamp", j.KickerU, j.KickerU + j.KickerLength, 0, j.Lip)
	local landU = j.KickerU + j.KickerLength + j.Gap
	ramp("SwJumpLanding", landU, landU + j.LandingLength, j.LandingTop, 0)
	-- flames on the run-up, a pair side by side, pointing along travel
	for _, x in { R - 3.6, R + 3.6 } do
		for _, u in { j.KickerU - 12, j.KickerU - 5 } do
			local at = Ctx.at(ctx, x, u, Path.TrackTop + 0.03)
			local decal = Kit.place("SwFlameDecal", CFrame.lookAt(at, at + Ctx.dir(ctx, heading)))
			if decal then
				decal.Parent = minor
			end
		end
	end
end

return Track
