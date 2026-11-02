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
local RoadNet = require(script.Parent.RoadNet)

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

local function onArc(path: LapPath, s: number): boolean
	for _, seg in path.segments do
		if seg.kind == "arc" and s >= seg.s0 - 1e-6 and s < seg.s0 + seg.length - 1e-6 then
			return true
		end
	end
	return false
end

-- A tidy end for a barrier run: a low red post just past the run's last piece.
local function runCap(parent: Instance, ctx: Ctx, path: LapPath, s: number, offset: number)
	local p, d = Path.planPoint(path, s)
	local at = p + Vector2.new(d.Y, -d.X) * offset
	local base = Ctx.at(ctx, at.X, at.Y, 0)
	local dir = Ctx.dir(ctx, d)
	Kit.part(
		parent,
		Vector3.new(2, 2.4, 1),
		CFrame.lookAt(base + Vector3.yAxis * 1.2, base + Vector3.yAxis * 1.2 + dir),
		{
			name = "RunCap",
			color = C.CurbRed,
			castShadow = false,
		}
	)
	Kit.part(
		parent,
		Vector3.new(2.2, 0.5, 1.2),
		CFrame.lookAt(base + Vector3.yAxis * 1.75, base + Vector3.yAxis * 1.75 + dir),
		{ name = "RunCapBand", color = C.White, castShadow = false }
	)
end

-- Edge meshes (hay, tyres, rope, tyre wall) along the path at `offset`, every `spacing`, the
-- mesh's front toward the road. `keep(s, p)` filters positions. A piece stands only where its whole
-- length clears the openings of the road network; each run that stops at an opening gets an end post.
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
	local outerSide = offset > 0
	local kept = false
	for k = 0, count - 1 do
		local s = s0 + step * (k + 0.5)
		local p, d = Path.planPoint(path, s)
		local out = Vector2.new(d.Y, -d.X)
		local at = p + out * offset
		local open = outerSide and RoadNet.barrierOpen(s, step / 2 + 1.2)
		local stand = not open and (not keep or keep(s, at))
		if stand then
			Ctx.place(ctx, parent, name, at.X, at.Y, -out)
		end
		if outerSide then
			if stand and not kept and k > 0 then
				runCap(parent, ctx, path, s - step / 2 - 0.5, offset)
			elseif kept and not stand then
				runCap(parent, ctx, path, s - step / 2 + 0.5, offset)
			end
		end
		kept = stand
	end
end

-- ------------------------------------------------------------------ dirt (levels 1 to 3)

-- The road ribbon from a to b, either side of the junctions. Where a piece stops at a junction its last
-- slab is one chord of RoadNet.EndChord with nothing past its end, and that slab's end edge is the
-- junction's edge (RoadNet takes its corners from the same chord), so the two meet exactly.
local function ribbon(folder: Folder, ctx: Ctx, path: LapPath, a: number, b: number, options: Kit.PartOptions)
	local chord = RoadNet.EndChord
	for _, piece in RoadNet.cutRanges(a, b) do
		local from, to = piece[1], piece[2]
		local cutFrom, cutTo = from > a, to < b
		local inFrom = if cutFrom then from + chord else from
		local inTo = if cutTo then to - chord else to
		if inTo > inFrom then
			layer(folder, ctx, path, samples(path, inFrom, inTo), 0, HALF_W * 2, 0.4, 0, options, 2)
		end
		if cutFrom then
			layer(folder, ctx, path, { from, from + chord }, 0, HALF_W * 2, 0.4, 0, options, 0)
		end
		if cutTo then
			layer(folder, ctx, path, { to - chord, to }, 0, HALF_W * 2, 0.4, 0, options, 0)
		end
	end
end

local function dirtSurface(folder: Folder, ctx: Ctx, colour: Color3)
	local path = Path.forLevel(1)
	ribbon(folder, ctx, path, 0, path.length, {
		name = "Surface",
		color = colour,
		collide = true,
		castShadow = false,
	})
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

-- The one marking language of the whole circuit, on every level from 4 up (M4-01): a white edge
-- line on both sides following the road, red and white curbs only on the inside of the corners, no
-- centre line. The lines stop where a junction takes over; its own chains (RoadNet) carry them on, so
-- a line is never drawn twice. `apronPath`: on level 12 the right straight's inner edge moves into the
-- infield (Track.loopApron paints that edge), so the ribbon draws no inner line there.
local function asphalt(folder: Folder, ctx: Ctx, path: LapPath, ranges: { { number } }, apronPath: LapPath?)
	local function onApron(s: number): boolean
		return apronPath ~= nil and s > RoadNet.ArcEnd and s < path.marks.farCurve[1]
	end
	for _, range in ranges do
		ribbon(folder, ctx, path, range[1], range[2], {
			name = "Surface",
			color = C.Asphalt,
			material = Enum.Material.Asphalt,
			collide = true,
			castShadow = false,
		})
		for _, piece in RoadNet.cutRanges(range[1], range[2]) do
			local list = samples(path, piece[1], piece[2])
			layer(folder, ctx, path, list, HALF_W - 0.6, 0.3, PAINT_THICK, PAINT, {
				name = "EdgeLine",
				color = C.White,
				castShadow = false,
			}, 0.1)
			local inner: { number } = {}
			local function flush()
				if #inner > 1 then
					layer(folder, ctx, path, inner, -(HALF_W - 0.6), 0.3, PAINT_THICK, PAINT, {
						name = "EdgeLine",
						color = C.White,
						castShadow = false,
					}, 0.1)
				end
				inner = {}
			end
			for _, s in list do
				if onApron(s) then
					flush()
				else
					table.insert(inner, s)
				end
			end
			flush()
		end
		-- curbs: one white band round the inside of each corner with red blocks on top of it, so no
		-- two curb faces ever share a plane; each end tapers to a point on the road's edge
		local list = samples(path, range[1], range[2])
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
				for _, tip in { { sa, -1 }, { sb, 1 } } do
					local at, dir = tip[1], tip[2]
					if not onArc(path, at + dir * 0.5) and math.abs(Path.bank(path, at)) < 1e-3 then
						local inA = RoadNet.trackPoint(at, -HALF_W)
						local inB = RoadNet.trackPoint(at, -HALF_W - 1)
						local point = RoadNet.trackPoint(at + dir * 5, -HALF_W)
						Kit.triangle(
							folder,
							Ctx.at(ctx, inA.X, inA.Y),
							Ctx.at(ctx, inB.X, inB.Y),
							Ctx.at(ctx, point.X, point.Y),
							Path.TrackTop + 0.12,
							0.3,
							{ name = "CurbTip", color = C.White }
						)
					end
				end
			end
		end
	end
end

-- A chain of painted line along plan points, in the road's own line height.
local function paintChain(folder: Instance, ctx: Ctx, points: { Vector2 }, width: number?, name: string?)
	local options = { name = name or "EdgeLine", color = C.White, castShadow = false }
	for i = 1, #points - 1 do
		local a, b = points[i], points[i + 1]
		Kit.slab(
			folder,
			Ctx.at(ctx, a.X, a.Y, Path.TrackTop + PAINT),
			Ctx.at(ctx, b.X, b.Y, Path.TrackTop + PAINT),
			Vector3.yAxis,
			width or RoadNet.LineWidth,
			PAINT_THICK,
			options,
			0.1
		)
	end
end

-- The pit lanes and their junctions with the track: the road network's surfaces and its paint. On the
-- dirt levels the lanes are dirt too, with no paint.
local function pitRoads(
	folder: Folder,
	ctx: Ctx,
	colour: Color3,
	material: Enum.Material?,
	paint: boolean,
	apron: boolean?
)
	local fill = { name = "Surface", color = colour, material = material, collide = true, castShadow = false }
	local thick = 0.4
	for _, j in RoadNet.Junctions do
		local road = Instance.new("Folder")
		road.Name = if j.side > 0 then "PitOut" else "PitIn"
		road.Parent = folder
		for _, tri in j.triangles do
			Kit.triangle(
				road,
				Ctx.at(ctx, tri[1].X, tri[1].Y),
				Ctx.at(ctx, tri[2].X, tri[2].Y),
				Ctx.at(ctx, tri[3].X, tri[3].Y),
				Path.TrackTop,
				thick,
				fill
			)
		end
		-- the lane: strips with mitred joints; its two ends stop exactly at the aisle and the junction
		local pts = j.laneStrip
		local halfLane = RoadNet.LaneWidth / 2
		local function mitre(u: Vector2, v: Vector2): number
			return math.min(halfLane * math.tan(math.acos(math.clamp(u:Dot(v), -1, 1)) / 2) + 0.02, halfLane)
		end
		for i = 1, #pts - 1 do
			local a, b = pts[i], pts[i + 1]
			local d = (b - a).Unit
			local before = if i > 1 then mitre((a - pts[i - 1]).Unit, d) else 0
			local after = if i < #pts - 1 then mitre(d, (pts[i + 2] - b).Unit) else 0
			local pa, pb = a - d * before, b + d * after
			Kit.slab(
				road,
				Ctx.at(ctx, pa.X, pa.Y, Path.TrackTop),
				Ctx.at(ctx, pb.X, pb.Y, Path.TrackTop),
				Vector3.yAxis,
				RoadNet.LaneWidth,
				thick,
				fill,
				0
			)
		end
		if paint then
			for i, chain in j.lines do
				local points = chain.points
				if apron and j.side > 0 and i == 3 then
					-- the road's inner edge leaves here on level 12: the apron paints it from the turn's end
					points = table.clone(points)
					table.remove(points)
				end
				paintChain(road, ctx, points, nil, chain.name)
			end
			for _, dash in j.dashes do
				paintChain(road, ctx, dash, RoadNet.LineWidth, "MergeDash")
			end
		end
	end
end

function Track.pitRoadsDirt(folder: Folder, ctx: Ctx)
	pitRoads(folder, ctx, C.Dirt, nil, false)
end

function Track.pitRoadsRaked(folder: Folder, ctx: Ctx)
	pitRoads(folder, ctx, C.DirtRaked, nil, false)
end

function Track.pitRoadsAsphalt(folder: Folder, ctx: Ctx, apron: boolean?)
	pitRoads(folder, ctx, C.Asphalt, Enum.Material.Asphalt, true, apron)
end

-- The walk's gate in the track's outer barrier: two white posts and a short open gate, the road's edge
-- just past them. The plot walk (Hub/Recipes/Plot) ends on that edge.
function Track.walkGate(folder: Folder, ctx: Ctx)
	local w = RoadNet.WalkHalfWidth + 0.6
	local foot = uS - math.sqrt((R + HALF_W) ^ 2 - w * w) - 0.5
	local dir = Ctx.dir(ctx, Vector2.new(0, -1))
	for _, side in { -1, 1 } do
		local base = Ctx.at(ctx, side * w, foot, 0)
		Kit.part(folder, Vector3.new(0.7, 3.6, 0.7), CFrame.new(base + Vector3.yAxis * 1.8), {
			name = "WalkGatePost",
			color = C.White,
			collide = true,
		})
		Kit.part(folder, Vector3.new(0.95, 0.3, 0.95), CFrame.new(base + Vector3.yAxis * 3.75), {
			name = "WalkGateCap",
			color = C.CurbRed,
			castShadow = false,
		})
		-- the gate leaf stands open, along the walk's side
		local leaf = base + Vector3.yAxis * 1.3 + dir * 1.7
		for _, y in { 0.4, -0.3 } do
			local at = leaf + Vector3.yAxis * y
			Kit.part(folder, Vector3.new(0.14, 0.2, 2.8), CFrame.lookAt(at, at + dir), {
				name = "WalkGateRail",
				color = C.White,
				castShadow = false,
			})
		end
	end
end

-- Level 12: the widened straight. The road's inner edge moves 16 into the infield (two full track widths
-- in all) over a 48-stud taper from the turn, runs straight past the loop, and comes back along the
-- exit bend's own edge. It is one polygon joined edge to edge to the ribbon at x = R - HALF_W.
function Track.loopApron(folder: Folder, ctx: Ctx)
	local path = Path.forLevel(12)
	local xIn = R - HALF_W
	local extra = 2 * HALF_W
	local taper = 3 * extra
	local bend = path.marks.exitBend
	local farU = uS + Path.Straight
	local function ease(t: number): number
		t = math.clamp(t, 0, 1)
		return t * t * (3 - 2 * t)
	end
	local edge: { Vector2 } = {}
	for k = 1, 16 do
		table.insert(edge, Vector2.new(xIn - extra * ease(k / 16), uS + taper * k / 16))
	end
	for k = 0, 15 do
		local p, d = Path.planPoint(path, bend[1] + (bend[2] - bend[1]) * k / 16)
		table.insert(edge, p + Vector2.new(-d.Y, d.X) * HALF_W)
	end
	local poly: { Vector2 } = { Vector2.new(xIn, uS) }
	for _, p in edge do
		table.insert(poly, p)
	end
	table.insert(poly, Vector2.new(xIn, farU))
	local fill = {
		name = "Surface",
		color = C.Asphalt,
		material = Enum.Material.Asphalt,
		collide = true,
		castShadow = false,
	}
	for _, tri in RoadNet.triangulate(poly) do
		Kit.triangle(
			folder,
			Ctx.at(ctx, tri[1].X, tri[1].Y),
			Ctx.at(ctx, tri[2].X, tri[2].Y),
			Ctx.at(ctx, tri[3].X, tri[3].Y),
			Path.TrackTop,
			0.4,
			fill
		)
	end
	-- the road's inner line follows the new edge, 0.6 in from it, and picks up the ribbon's line
	local lineAt: { Vector2 } = { Vector2.new(xIn + 0.6, uS) }
	for i, p in edge do
		local a = edge[math.max(i - 1, 1)]
		local b = edge[math.min(i + 1, #edge)]
		local d = (b - a).Unit
		table.insert(lineAt, p + Vector2.new(d.Y, -d.X) * 0.6)
	end
	table.insert(lineAt, Vector2.new(xIn + 0.6, farU))
	paintChain(folder, ctx, lineAt)
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

function Track.asphaltGround(folder: Folder, ctx: Ctx, apron: boolean?)
	local path = Path.forLevel(if apron then 12 else 10)
	local ground = Path.forLevel(10)
	asphalt(folder, ctx, ground, Track.groundRanges(ground), apron and path or nil)
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
				if onArc(path, s) then
					return false
				end
				-- stop short of the banked wall that starts before the far turn (level 9)
				local far = path.segments[4]
				local reach = Path.BankEase + spacing / 2 + 1.5
				return which ~= "straights" or s < far.s0 - reach or s > far.s0 + far.length + reach
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
	-- one even wall: every piece runs from the height at its start to the height at its end, so the
	-- top is one continuous slope, not a staircase. The body runs down into the ground. Each stretch
	-- between openings ends in one coral marker.
	local list = samples(path, a, b, 3)
	local function heightAt(s: number): number
		return Path.TrackTop + 2 * HALF_W * math.sin(math.rad(Path.bank(path, s))) + lip
	end
	type Piece = { a: Vector3, b: Vector3, height: number }
	local stretches: { { Piece } } = {}
	local stretch: { Piece }? = nil
	for i = 1, #list - 1 do
		local sa, sb = list[i], list[i + 1]
		if RoadNet.barrierOpen((sa + sb) / 2, 1.5) then
			stretch = nil
		else
			local pa, da = Path.planPoint(path, sa)
			local pb, db = Path.planPoint(path, sb)
			local oa = pa + Vector2.new(da.Y, -da.X) * (HALF_W + 0.9)
			local ob = pb + Vector2.new(db.Y, -db.X) * (HALF_W + 0.9)
			local ha, hb = heightAt(sa), heightAt(sb)
			local wa, wb = Ctx.at(ctx, oa.X, oa.Y, ha), Ctx.at(ctx, ob.X, ob.Y, hb)
			local tall = math.max(ha, hb)
			Kit.slab(
				major,
				wa - Vector3.yAxis * edgeTall,
				wb - Vector3.yAxis * edgeTall,
				Vector3.yAxis,
				0.9,
				tall + 0.4,
				{
					name = "BankWall",
					color = C.Wall,
					collide = true,
					castShadow = false,
				},
				0.5
			)
			Kit.slab(major, wa + Vector3.yAxis * 0.02, wb + Vector3.yAxis * 0.02, Vector3.yAxis, 1.12, edgeTall, {
				name = "BankWallCap",
				color = C.WallCap,
				collide = true,
				castShadow = false,
			}, 0.5)
			local run = stretch
			if not run then
				run = {}
				stretch = run
				table.insert(stretches, run :: { Piece })
			end
			table.insert(run :: { Piece }, { a = wa, b = wb, height = tall })
		end
	end
	-- one restrained coral marker at each end of a stretch (a short painted block over the wall end)
	for _, run in stretches do
		for k, which in { run[1], run[#run] } do
			local along = (which.b - which.a).Unit
			local tip = if k == 1 then which.a - along * 0.2 else which.b + along * 0.2
			Kit.slab(
				major,
				tip - along * 0.7 + Vector3.yAxis * 0.2,
				tip + along * 0.7 + Vector3.yAxis * 0.2,
				Vector3.yAxis,
				1.4,
				which.height + 0.2,
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
		Ctx.place(ctx, minor, "SwCatchFence", at.X, at.Y, -out, heightAt(s))
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

-- Level 12: the teardrop loop, built along the cars' own lap path out of the track's own road, lines
-- and curbs, so it reads as part of the circuit and the wheels stay on it. It is the road's 16 wide
-- where it leaves the ground, so the road's lines run straight onto it, and 14 up in the loop. A blue
-- steel backbone runs behind the road, and four slim steel legs carry it at the ring's widest points.
-- Slices are at most 4 degrees of turn (no facets from the walkway). Visitors walk under it: nothing
-- here collides.
local LOOP_STEEL = Color3.fromRGB(28, 96, 214)
local LOOP_STEEL_DARK = Color3.fromRGB(20, 66, 158)

function Track.loop(major: Folder, minor: Folder, ctx: Ctx)
	local path = Path.forLevel(12)
	local lo = Path.Loop
	local l = path.marks.loop
	local length = l[2] - l[1]
	-- the slices: start where the road has left the surface below it, stop where it comes back
	local list: { number } = {}
	local ds = 0
	while ds < length do
		local height, kappa = Path.loopShape(ds)
		if height >= 0.06 then
			table.insert(list, l[1] + ds)
		end
		ds += math.min(3, math.rad(4) / math.max(kappa, 1e-3))
	end
	local function widthAt(s: number): number
		local t = (s - l[1]) / length
		local f = math.clamp(math.min(t, 1 - t) / 0.1, 0, 1)
		return lo.RoadWidth + (lo.Width - lo.RoadWidth) * f * f * (3 - 2 * f)
	end
	layer(major, ctx, path, list, 0, widthAt, 0.4, 0, {
		name = "LoopRoad",
		color = C.Asphalt,
		material = Enum.Material.Asphalt,
		castShadow = true,
	}, 0.35)
	layer(major, ctx, path, list, 0, function(s)
		return widthAt(s) + 0.5
	end, 0.8, -0.4, { name = "LoopBackbone", color = LOOP_STEEL, castShadow = false }, 0.35)
	-- the curbs start once the road is well off the ground
	local curbs: { number } = {}
	for _, s in list do
		if Path.loopShape(s - l[1]) >= 0.4 then
			table.insert(curbs, s)
		end
	end
	for _, side in { -1, 1 } do
		layer(
			major,
			ctx,
			path,
			curbs,
			function(s)
				return side * (widthAt(s) / 2 + 0.3)
			end,
			0.6,
			0.75,
			0.2,
			function(i)
				return {
					name = "LoopCurb",
					color = if (i // 3) % 2 == 0 then C.CurbRed else C.White,
					castShadow = false,
				}
			end,
			0
		)
		layer(minor, ctx, path, list, function(s)
			return side * (widthAt(s) / 2 - 0.6)
		end, 0.3, PAINT_THICK, PAINT, { name = "EdgeLine", color = C.White, castShadow = false }, 0.1)
	end
	-- the steel: two slim legs under each side of the ring, at its widest points, joined by one low
	-- brace and tied to the backbone by a short strut, so the teardrop itself is what you see. The legs
	-- stand where no car runs on the ground: clear of the other ribbon by construction of the offset.
	local function beam(a: Vector3, b: Vector3, width: number, colour: Color3, name: string)
		Kit.part(major, Vector3.new(width, width, (b - a).Magnitude), CFrame.lookAt((a + b) / 2, b), {
			name = name,
			color = colour,
			castShadow = false,
		})
	end
	local widest = { 0.32, 0.68 } -- of the way round: the ring's front and back
	for _, t in widest do
		local cf = Ctx.onPath(ctx, path, l[1] + length * t, 0, -1.2)
		local legs: { Vector3 } = {}
		for _, side in { -1, 1 } do
			local at = cf * Vector3.new(side * 4.5, 0, 0) - cf.UpVector * 2
			local foot = Vector3.new(at.X, 0, at.Z)
			table.insert(legs, foot)
			beam(foot - Vector3.yAxis * 0.2, at + Vector3.yAxis, 1.6, LOOP_STEEL, "LoopLeg")
			beam(at, at + cf.UpVector * 2, 1, LOOP_STEEL_DARK, "LoopStrut")
			Kit.part(major, Vector3.new(3, 0.3, 3), CFrame.new(foot + Vector3.yAxis * 0.4), {
				name = "LoopFoot",
				color = C.Concrete,
				castShadow = false,
			})
		end
		local low, high = Vector3.yAxis * 2, Vector3.yAxis * 12
		beam(legs[1] + low, legs[2] + high, 0.6, LOOP_STEEL_DARK, "LoopBrace")
		beam(legs[2] + low, legs[1] + high, 0.6, LOOP_STEEL_DARK, "LoopBrace")
		beam(legs[1] + high, legs[2] + high, 0.7, LOOP_STEEL_DARK, "LoopRung")
	end
end

-- Level 11: a low eased hump on the ground right straight (a hop, no gap, no flying),
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
