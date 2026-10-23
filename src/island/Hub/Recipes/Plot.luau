--!strict
-- One hub plot at its base tier (Task 3, 2026-10-22): front to back the entrance court and gate
-- with its nameplate, the kiosk placeholder, the Paddock with 15 marked bay placeholders, the
-- walkway, the pit lanes, the base Speedway (asphalt, racing line, painted lines, curbs, low white
-- wall, checkered start / finish, mowed infield, fictional banners) and the base flag line with
-- bunting in the sign band. Everything later (bleachers, grandstand, floodlights, gantry, loop,
-- signs) is reserved space only. Visuals only: no ownership, saved data or gameplay. Task 4
-- replaced the yellow gate arch with the gates family plot gate (buildGate).

local Kit = require(script.Parent.Parent.Parent.Kit)
local KitAssets = require(script.Parent.Parent.Environment.KitAssets)
local Layout = require(script.Parent.Parent.Layout)
local Palette = require(script.Parent.Parent.Parent.WorldPalette)
local Signs = require(script.Parent.Parent.Environment.Signs)

local PlotRecipe = {}

local SURFACE = Layout.SurfaceY
local TRACK_TOP = SURFACE + 0.2
local HALF_W = Layout.HalfWidth
local CHORD_ERROR = 0.15

type Node = { s: number, p: Vector2, t: Vector2 }

-- Lap nodes: straight ends, and arcs split so the outer barrier's chord error stays within CHORD_ERROR.
local function trackNodes(): { Node }
	local nodes: { Node } = {}
	for _, seg in Layout.Segments do
		local pieces = 1
		if seg.kind == "arc" then
			local outerR = Layout.TurnRadius + HALF_W + 1
			pieces = math.ceil(math.pi / (2 * math.acos(1 - CHORD_ERROR / outerR)))
		end
		for k = 0, pieces - 1 do
			local s = seg.s0 + seg.length * k / pieces
			local p, t = Layout.pointAt(s)
			table.insert(nodes, { s = s, p = p, t = t })
		end
	end
	return nodes
end

local NODES = trackNodes()
PlotRecipe.SegmentCount = #NODES

-- Strips along the loop at a lateral offset (+ outward); skip(p) leaves a gap.
local function ring(
	parent: Instance,
	bearing: number,
	offset: number,
	width: number,
	thickness: number,
	topY: number,
	options: Kit.PartOptions,
	overlap: number,
	skip: ((Vector2) -> boolean)?
)
	local n = #NODES
	for i = 1, n do
		local a, b = NODES[i], NODES[i % n + 1]
		local pa = a.p + Layout.outward(a.t) * offset
		local pb = b.p + Layout.outward(b.t) * offset
		if not (skip and skip((pa + pb) / 2)) then
			Kit.strip(
				parent,
				Layout.plotToWorld(bearing, pa),
				Layout.plotToWorld(bearing, pb),
				width,
				thickness,
				topY,
				options,
				overlap
			)
		end
	end
end

-- Flat slab over a plot-frame rectangle.
local function rect(
	parent: Instance,
	bearing: number,
	x0: number,
	u0: number,
	x1: number,
	u1: number,
	topY: number,
	thickness: number,
	options: Kit.PartOptions
): Part?
	local a = Layout.plotToWorld(bearing, Vector2.new((x0 + x1) / 2, u0))
	local b = Layout.plotToWorld(bearing, Vector2.new((x0 + x1) / 2, u1))
	return Kit.strip(parent, a, b, math.abs(x1 - x0), thickness, topY, options, 0)
end

-- Box standing on the surface over a plot-frame rectangle.
local function box(
	parent: Instance,
	bearing: number,
	x0: number,
	u0: number,
	x1: number,
	u1: number,
	height: number,
	options: Kit.PartOptions
): Part?
	return rect(parent, bearing, x0, u0, x1, u1, SURFACE + height, height, options)
end

local function polyline(
	parent: Instance,
	bearing: number,
	points: { Vector2 },
	width: number,
	topY: number,
	options: Kit.PartOptions
)
	for i = 1, #points - 1 do
		Kit.strip(
			parent,
			Layout.plotToWorld(bearing, points[i]),
			Layout.plotToWorld(bearing, points[i + 1]),
			width,
			0.1,
			topY,
			options,
			width * 0.5
		)
	end
end

-- Base-tier Speedway (Task 3, Adam 2026-10-22): dark asphalt with a slightly darker racing line,
-- a double yellow inside line, a dashed yellow lane line, a thin white outer line, red and white
-- curbs on the turns, a mowed-stripe infield, a low clean white wall and fictional banners on the
-- wall's inner face where the entrance sees them. Nothing from later tiers: every piece stays in
-- the Track reservation (barrier height) or lies flat in the infield.
local ASPHALT = Color3.fromRGB(58, 62, 70)
local RACING = Color3.fromRGB(46, 49, 56)
local LINE_YELLOW = Color3.fromRGB(246, 200, 60)
local WALL = Color3.fromRGB(246, 246, 242)
local WALL_CAP = Color3.fromRGB(214, 220, 228)
local CURB_RED = Color3.fromRGB(214, 62, 56)
local STRIPE_A = Color3.fromRGB(104, 178, 84)
local STRIPE_B = Color3.fromRGB(88, 160, 72)

local function onArc(s: number): boolean
	for _, seg in Layout.Segments do
		if seg.kind == "arc" and s >= seg.s0 - 1e-6 and s < seg.s0 + seg.length - 1e-6 then
			return true
		end
	end
	return false
end

-- Lateral offset of the racing line at lap distance s: wide on the straights, crossing to the
-- inside at each turn's apex.
local function racingOffset(s: number): number
	for _, seg in Layout.Segments do
		if s >= seg.s0 - 1e-6 and s <= seg.s0 + seg.length + 1e-6 then
			if seg.kind == "arc" then
				return 3 - 7 * math.sin(math.pi * (s - seg.s0) / seg.length)
			end
			return 3
		end
	end
	return 3
end

local function ringBy(
	parent: Instance,
	bearing: number,
	offsetAt: (Node) -> number,
	width: number,
	thickness: number,
	topY: number,
	options: (number, Node) -> Kit.PartOptions,
	overlap: number
)
	local n = #NODES
	for i = 1, n do
		local a, b = NODES[i], NODES[i % n + 1]
		local pa = a.p + Layout.outward(a.t) * offsetAt(a)
		local pb = b.p + Layout.outward(b.t) * offsetAt(b)
		Kit.strip(
			parent,
			Layout.plotToWorld(bearing, pa),
			Layout.plotToWorld(bearing, pb),
			width,
			thickness,
			topY,
			options(i, a),
			overlap
		)
	end
end

local function buildSpeedway(visual: Folder, bearing: number, index: number)
	local track = Instance.new("Folder")
	track.Name = "Speedway"
	track.Parent = visual
	ring(track, bearing, 0, HALF_W * 2, 0.4, TRACK_TOP, {
		name = "Surface",
		color = ASPHALT,
		material = Enum.Material.Asphalt,
		collide = true,
		castShadow = false,
	}, 2)
	-- the racing line, a shade darker (arcs only vary; the straights hold the outside)
	ringBy(
		track,
		bearing,
		function(node)
			return racingOffset(node.s)
		end,
		3.5,
		0.04,
		TRACK_TOP + 0.01,
		function()
			return { name = "RacingLine", color = RACING, material = Enum.Material.Asphalt, castShadow = false }
		end,
		0.8
	)
	-- double yellow inside line, thin white outer line
	for _, off in { -(HALF_W - 0.75), -(HALF_W - 1.35) } do
		ring(track, bearing, off, 0.3, 0.04, TRACK_TOP + 0.03, {
			name = "YellowLine",
			color = LINE_YELLOW,
			castShadow = false,
		}, 0.2)
	end
	ring(track, bearing, HALF_W - 0.6, 0.3, 0.04, TRACK_TOP + 0.03, {
		name = "WhiteLine",
		color = Color3.new(1, 1, 1),
		castShadow = false,
	}, 0.2)
	-- dashed yellow lane line on the centre: 3 studs painted, 3 studs open
	local dashes = Instance.new("Folder")
	dashes.Name = "LaneDashes"
	dashes.Parent = track
	local s = 0
	while s < Layout.PathLength - 3 do
		local steps = if onArc(s) then 3 else 1
		for k = 0, steps - 1 do
			local pa = Layout.pointAt(s + 3 * k / steps)
			local pb = Layout.pointAt(s + 3 * (k + 1) / steps)
			Kit.strip(
				dashes,
				Layout.plotToWorld(bearing, pa),
				Layout.plotToWorld(bearing, pb),
				0.3,
				0.04,
				TRACK_TOP + 0.03,
				{ name = "LaneDash", color = LINE_YELLOW, castShadow = false },
				0.05
			)
		end
		s += 6
	end
	-- the low clean white outer wall with a pale cap (open at the pit lanes)
	ring(track, bearing, HALF_W + 0.55, 0.8, 1.5, TRACK_TOP + 1.5, {
		name = "Barrier",
		color = WALL,
		collide = true,
		castShadow = false,
	}, 0.6, Layout.inPitGap)
	ring(track, bearing, HALF_W + 0.55, 1.05, 0.14, TRACK_TOP + 1.64, {
		name = "BarrierCap",
		color = WALL_CAP,
		castShadow = false,
	}, 0.6, Layout.inPitGap)
	-- inside curb: red and white on the turns, white on the straights
	ringBy(
		track,
		bearing,
		function()
			return -HALF_W - 0.5
		end,
		1,
		0.3,
		TRACK_TOP + 0.12,
		function(i, node)
			return {
				name = "Curb",
				color = if onArc(node.s) and i % 2 == 0 then CURB_RED else Color3.new(1, 1, 1),
				collide = true,
				castShadow = false,
			}
		end,
		0.3
	)

	-- Checkered start / finish line: 8 tiles across, 3 rows
	local sp, st = Layout.pointAt(Layout.StartS)
	local n = Layout.outward(st)
	local tile = HALF_W * 2 / 8
	for row = 0, 2 do
		for k = 0, 7 do
			local c = sp + n * (-HALF_W + tile * (k + 0.5)) + st * (row - 1) * tile
			Kit.strip(
				track,
				Layout.plotToWorld(bearing, c - st * tile / 2),
				Layout.plotToWorld(bearing, c + st * tile / 2),
				tile,
				0.06,
				TRACK_TOP + 0.05,
				{
					name = "Checker",
					color = if (row + k) % 2 == 0 then Palette.Checker else Color3.new(1, 1, 1),
					castShadow = false,
				},
				0
			)
		end
	end

	-- the mowed-stripe infield: strips along the straights, clipped to the infield's rounded ends
	local infield = Instance.new("Folder")
	infield.Name = "Infield"
	infield.Parent = track
	-- stripes run on under the curb and the asphalt (radius 27.3; the curb starts at 26), so the
	-- track hides their stepped ends round the turns
	local R = Layout.TurnRadius - HALF_W + 0.3
	local uNear, uFar = Layout.RightStraight.from.Y, Layout.RightStraight.to.Y
	local width = 3.25
	local strips = math.floor(2 * R / width)
	local x0 = -strips * width / 2
	for k = 0, strips - 1 do
		local xa, xb = x0 + k * width, x0 + (k + 1) * width
		local half = math.sqrt(math.max(0, R * R - math.min(math.abs(xa), math.abs(xb)) ^ 2))
		Kit.strip(
			infield,
			Layout.plotToWorld(bearing, Vector2.new((xa + xb) / 2, uNear - half)),
			Layout.plotToWorld(bearing, Vector2.new((xa + xb) / 2, uFar + half)),
			width,
			0.08,
			SURFACE + 0.09,
			{
				name = "Stripe",
				color = if k % 2 == 0 then STRIPE_A else STRIPE_B,
				material = Enum.Material.Grass,
				castShadow = false,
			},
			0
		)
	end

	-- fictional banners on the wall's inner face, on the straights only: a flat 10-stud board on
	-- the curved far-turn wall had its ends hidden by the curve ("R'S SPEE", "OPA FI"; Task 4
	-- brief §13). The owner's banner stands on posts in the outer sign band, facing the entrance.
	local banners = Instance.new("Folder")
	banners.Name = "Banners"
	banners.Parent = track
	local right, left = Layout.RightStraight, Layout.LeftStraight
	local placements = {
		{ s = right.s0 + right.length * 0.3, art = "BannerA" },
		{ s = right.s0 + right.length * 0.7, art = "BannerB" },
		{ s = left.s0 + left.length * 0.3, art = "BannerC" },
		{ s = left.s0 + left.length * 0.55, art = "BannerD" },
	}
	for _, pl in placements do
		local p, t = Layout.pointAt(pl.s)
		local out = Layout.outward(t)
		local at = p + out * (HALF_W + 0.12)
		local a = Layout.plotToWorld(bearing, at, TRACK_TOP + 0.78)
		local inward = Layout.plotToWorld(bearing, at - out, TRACK_TOP + 0.78)
		local board = Kit.part(
			banners,
			Vector3.new(10, 1.4, 0.06),
			CFrame.lookAt(a, inward),
			{ name = "Banner", color = WALL, castShadow = false }
		)
		Signs.banner(board, pl.art, index)
	end
	-- the owner's banner: 14 x 3 on two posts in the sign band (the band allows signs under 20),
	-- its face toward the entrance across the infield
	local _, u0, _, u1 = Layout.bounds(Layout.reservation("SignBand").poly)
	local u = (u0 + u1) / 2
	local bottom, height, boardWidth = 5, 3, 14
	local centre = Layout.plotToWorld(bearing, Vector2.new(0, u), SURFACE + bottom + height / 2)
	local toward = Layout.plotToWorld(bearing, Vector2.new(0, u - 1), SURFACE + bottom + height / 2)
	local board = Kit.part(
		banners,
		Vector3.new(boardWidth, height, 0.3),
		CFrame.lookAt(centre, toward),
		{ name = "Banner", color = WALL, castShadow = false }
	)
	board:SetAttribute("OwnerBanner", true)
	for _, x in { -1, 1 } do
		local foot =
			Layout.plotToWorld(bearing, Vector2.new(x * (boardWidth / 2 - 1), u + 0.4), SURFACE + (bottom + height) / 2)
		local post = Kit.part(
			banners,
			Vector3.new(0.5, bottom + height, 0.5),
			CFrame.lookAt(foot, toward + (foot - centre) * Vector3.new(1, 0, 1)),
			{ name = "BannerPost", color = WALL_CAP, collide = true }
		)
		post:SetAttribute("OwnerBanner", true)
	end
	Signs.banner(board, "Owner", index)
end

-- Base flag line in the outer sign band (the band allows flags; tier 2 replaces them with signs):
-- poles with cloth flags (beams the client waves) and pennant bunting sagging between them.
local function buildFlags(visual: Folder, bearing: number)
	local flags = Instance.new("Folder")
	flags.Name = "FlagLine"
	flags:SetAttribute("FlagLine", true)
	flags.Parent = visual
	local _, u0, _, u1 = Layout.bounds(Layout.reservation("SignBand").poly)
	local u = (u0 + u1) / 2
	local cloths = { "FlagChecker", "FlagStripesA", "FlagStar", "FlagStripesB" }
	local host = Kit.part(flags, Vector3.one, CFrame.new(Layout.plotToWorld(bearing, Vector2.new(0, u), SURFACE)), {
		name = "BeamHost",
		transparency = 1,
		castShadow = false,
	})
	local function attach(pos: Vector3, x: Vector3, y: Vector3): Attachment
		local a = Instance.new("Attachment")
		a.CFrame = host.CFrame:ToObjectSpace(CFrame.fromMatrix(pos, x, y))
		a.Parent = host
		return a
	end
	local along = (Layout.plotToWorld(bearing, Vector2.new(1, u)) - Layout.plotToWorld(bearing, Vector2.new(0, u))).Unit
	local lateral = along:Cross(Vector3.new(0, 1, 0)).Unit
	local poleTop = 9.6
	local tops = {}
	for k = -4, 4 do
		local base = Layout.plotToWorld(bearing, Vector2.new(k * 20, u), SURFACE)
		if KitAssets.has("Flagpole") then
			local pole = KitAssets.place("Flagpole", CFrame.lookAt(base, base + lateral), 1, true)
			pole.Parent = flags
			poleTop = KitAssets.info("Flagpole").meta.flag_top or poleTop
		else
			Kit.part(flags, Vector3.new(0.5, 10, 0.5), CFrame.new(base + Vector3.new(0, 5, 0)), {
				name = "FlagPole",
				color = Palette.Cream,
				collide = true,
			})
		end
		local top = base + Vector3.new(0, poleTop, 0)
		table.insert(tops, top)
		-- the flag: a beam from the pole out along the band, 2 tall; the client waves it by
		-- bending the beam sideways (curves bend along the attachments' X, here lateral)
		local flagMid = top - Vector3.new(0, 1, 0)
		local a0 = attach(flagMid + along * 0.25, lateral, Vector3.new(0, 1, 0))
		local a1 = attach(flagMid + along * 4.2, lateral, Vector3.new(0, 1, 0))
		local b = Instance.new("Beam")
		b.Name = "Flag"
		b.Attachment0, b.Attachment1 = a0, a1
		b.Texture = Signs.texture(cloths[(k + 4) % #cloths + 1])
		b.TextureMode = Enum.TextureMode.Stretch
		b.TextureLength = 1
		b.Width0, b.Width1 = 2, 2
		b.FaceCamera = false
		b.Segments = 12
		b.LightInfluence = 1
		b:SetAttribute("FlagWave", (k + 4) * 0.7)
		b.Parent = host
	end
	-- bunting between neighbouring poles, sagging a little under the flags
	for i = 1, #tops - 1 do
		local p0 = tops[i] - Vector3.new(0, 2.6, 0)
		local p1 = tops[i + 1] - Vector3.new(0, 2.6, 0)
		local down = Vector3.new(0, -1, 0)
		local a0 = attach(p0, down, lateral)
		local a1 = attach(p1, down, lateral)
		local b = Instance.new("Beam")
		b.Name = "Bunting"
		b.Attachment0, b.Attachment1 = a0, a1
		b.Texture = Signs.texture("Pennants")
		b.TextureMode = Enum.TextureMode.Wrap
		b.TextureLength = 6
		b.Width0, b.Width1 = 1.4, 1.4
		b.FaceCamera = true
		b.Segments = 16
		b.CurveSize0 = 2.2
		b.CurveSize1 = -2.2
		b.LightInfluence = 1
		b:SetAttribute("BuntingSag", 2.2)
		b.Parent = host
	end
end

-- A thin invisible face part for a SurfaceGui, centred at `at`, its Front face toward `toward`.
local function facePart(parent: Instance, name: string, at: Vector3, toward: Vector3, w: number, h: number): Part
	return Kit.part(parent, Vector3.new(w, h, 0.02), CFrame.lookAt(at, toward), {
		name = name,
		transparency = 1,
		castShadow = false,
	})
end

-- Task 4 plot gate (brief §11; gates family, assets/island/kit/kit_gates.py; concept-review M14):
-- one assembled frame shared by all six plots, stone bases, cream pillars, navy beam, round
-- lamps, checker strips, two flags, a start line and hedge stubs, with only the accent (bands,
-- collars, number discs, flags, the name pill's border) in the plot's colour. Every direct child
-- is named "Gate..." (LayoutChecks treats those as the gate the viewer stands in) or is a
-- transparent sign face. The meshes do not collide; simple invisible boxes keep the 14-wide
-- opening walkable (Task 3: one box collider over the whole arch closed the entrance).
local GATE_PIECES = {
	"PlotGatePillars",
	"PlotGateBeam",
	"PlotGateAccent",
	"PlotGateLamps",
	"PlotGateChecker",
	"PlotGateFlagpoles",
}
local COURT_TOP = SURFACE + 0.1 -- the court slab's top (buildFront)
local LAMP_COLOUR = Color3.fromRGB(255, 212, 150) -- warm globe light (Tunable)
local FLAG_LENGTH = 3 -- studs out from the pole (Tunable; "two modest flags")
local FLAG_TIP = 0.15 -- the flag tapers to this width: a pennant, not a square (review J8)
local CHECKER_SCALE = 0.5 -- of the PlotGateChecker strip height
local CHECKER_TOP = 9.2 -- studs above the gate base: just under the accent collars (from 9.3)

local function buildGate(front: Folder, base: CFrame, index: number)
	local accent = Signs.PlotAccents[(index - 1) % #Signs.PlotAccents + 1]
	front:SetAttribute("GateAccent", accent)
	for _, name in GATE_PIECES do
		local piece = KitAssets.place(name, base, 1)
		piece.Name = "Gate" .. string.sub(name, #"PlotGate" + 1)
		if name == "PlotGateAccent" then
			-- the accent mesh is one neutral swatch: drop the palette texture so the colour shows
			piece.TextureID = ""
			piece.Color = accent
		elseif name == "PlotGateChecker" then
			-- brief §11 "narrow checkered strip": half the recorded height (two rows), raised to sit
			-- just under the pillar collars (Task 4 complaint review J8: the full-height panels
			-- read as checkerboard shafts)
			local info = KitAssets.info(name)
			local oldMid = (info.min.Y + info.max.Y) / 2
			local h = (info.max.Y - info.min.Y) * CHECKER_SCALE
			piece.Size = Vector3.new(piece.Size.X, h, piece.Size.Z)
			piece.CFrame = piece.CFrame + base.UpVector * (CHECKER_TOP - h / 2 - oldMid)
		end
		piece.Parent = front
	end
	-- the start line lies on the court surface between the stone bases; flat, it never collides
	local line = KitAssets.place("PlotGateStartLine", base + Vector3.new(0, COURT_TOP - SURFACE, 0), 1)
	line.Name = "GateStartLine"
	line.Parent = front

	local function collider(localCFrame: CFrame, size: Vector3)
		Kit.part(front, size, base * localCFrame, {
			name = "GateCollider",
			collide = true,
			transparency = 1,
			castShadow = false,
		})
	end
	-- stone bases and pillars from the recorded meta (opening |x| < 7 stays clear)
	local pm = KitAssets.info("PlotGatePillars").meta
	local stoneIn, stoneOut = pm["stone_base.x.1"] or 7, pm["stone_base.x.2"] or 10.6
	local stoneSize = KitAssets.info("PlotGatePillars").points["stone_base.size"] or Vector3.new(3.6, 2.5, 3.6)
	local stoneH, stoneD = math.abs(stoneSize.Y), math.abs(stoneSize.Z)
	local pillarX, pillarW = pm["pillar.x"] or 8.25, pm["pillar.size.1"] or 2.5
	local pillarTop = pm["opening.z.2"] or 10.5
	local joint = pm.hedge_joint_x or stoneOut
	local stub = KitAssets.info("PlotGateHedgeStub").meta.length or 3
	local poles = KitAssets.info("PlotGateFlagpoles").points
	for _, side in { -1, 1 } do
		collider(
			CFrame.new(side * (stoneIn + stoneOut) / 2, stoneH / 2, 0),
			Vector3.new(stoneOut - stoneIn, stoneH, stoneD)
		)
		collider(
			CFrame.new(side * pillarX, (stoneH + pillarTop) / 2, 0),
			Vector3.new(pillarW, pillarTop - stoneH, pillarW)
		)
		-- the hedge stub: origin at its inner end on the stone base's outer face, running outward
		-- (+x; turned half round for the left side)
		local turn = if side < 0 then CFrame.Angles(0, math.pi, 0) else CFrame.identity
		local hedge = KitAssets.place("PlotGateHedgeStub", base * CFrame.new(side * joint, 0, 0) * turn, 1)
		hedge.Name = "GateHedgeStub"
		hedge.Parent = front
		collider(CFrame.new(side * (joint + stub / 2), 1.3, 0), Vector3.new(stub, 2.6, 2.4))
	end
	for i = 1, 2 do
		local top = poles[string.format("flags.%d.top", i)]
		if top then
			collider(CFrame.new(top.X, (top.Y + 0.4) / 2, top.Z), Vector3.new(0.6, top.Y + 0.4, 0.6))
		end
	end

	-- the sign faces recorded on the beam: a thin transparent part on each rectangle, its Front
	-- (LookVector) along the recorded outward normal
	local beam = KitAssets.info("PlotGateBeam")
	local i = 1
	while beam.points[string.format("sign_faces.%d.centre", i)] do
		local key = string.format("sign_faces.%d", i)
		local centre = beam.points[key .. ".centre"]
		local normal = beam.points[key .. ".normal"] or Vector3.new(0, 0, 1)
		local up = beam.points[key .. ".up"] or Vector3.new(0, 1, 0)
		local w, h = beam.meta[key .. ".size.1"] or 2, beam.meta[key .. ".size.2"] or 2
		local name = beam.tags[key .. ".name"] or ("SignFace" .. i)
		local p = base:PointToWorldSpace(centre + normal * 0.03)
		local face = Kit.part(
			front,
			Vector3.new(w, h, 0.02),
			CFrame.lookAt(p, p + base:VectorToWorldSpace(normal), base:VectorToWorldSpace(up)),
			{ name = name, transparency = 1, castShadow = false }
		)
		face:SetAttribute("SignFace", true)
		if string.find(name, "Number") then
			Signs.plotGateNumber(face, index)
		else
			Signs.plotGateName(face, index, accent)
		end
		i += 1
	end

	-- lamps and flags hang from one invisible host part at the gate's foot
	local host = Kit.part(front, Vector3.one, base, { name = "GateFxHost", transparency = 1, castShadow = false })
	local function attach(name: string, world: CFrame): Attachment
		local a = Instance.new("Attachment")
		a.Name = name
		a.CFrame = host.CFrame:ToObjectSpace(world)
		a.Parent = host
		return a
	end
	local lamps = KitAssets.info("PlotGateLamps").points
	for k = 1, 2 do
		local p = lamps[string.format("light_points.%d", k)]
		if p then
			local a = attach("GateLamp", CFrame.new(base:PointToWorldSpace(p)))
			local light = Instance.new("PointLight")
			light.Color = LAMP_COLOUR
			light.Brightness = 1
			light.Range = 12
			light.Shadows = false
			light.Parent = a
		end
	end
	-- the flags: accent cloth beams from each pole outward, 2 tall, waved by TrackMotion (calm
	-- and still under reduced motion). The bend axis (attachment X) is the gate's front-back axis.
	local bendAxis = base:VectorToWorldSpace(Vector3.new(0, 0, 1))
	for k = 1, 2 do
		local top = poles[string.format("flags.%d.top", k)]
		local bottom = poles[string.format("flags.%d.bottom", k)]
		if top and bottom then
			local out = Vector3.new(if top.X < 0 then -1 else 1, 0, 0)
			local mid = (top + bottom) / 2
			local a0 =
				attach("GateFlag0", CFrame.fromMatrix(base:PointToWorldSpace(mid + out * 0.3), bendAxis, base.UpVector))
			local a1 = attach(
				"GateFlag1",
				CFrame.fromMatrix(base:PointToWorldSpace(mid + out * FLAG_LENGTH), bendAxis, base.UpVector)
			)
			local b = Instance.new("Beam")
			b.Name = "GateFlag"
			b.Attachment0, b.Attachment1 = a0, a1
			b.Texture = "" -- texture hook: an approved flag cloth id would go here; plain accent for now
			b.Color = ColorSequence.new(accent)
			b.Transparency = NumberSequence.new(0)
			b.Width0, b.Width1 = top.Y - bottom.Y, FLAG_TIP
			b.FaceCamera = false
			b.Segments = 10
			b.LightInfluence = 1
			b:SetAttribute("FlagWave", index * 1.3 + k * 0.6)
			b:SetAttribute("FlagAmplitude", 0.55)
			b.Parent = host
		end
	end
end

local function buildFront(visual: Folder, bearing: number, index: number)
	local r0 = Layout.EntranceRadius
	local W = function(x: number, u: number, y: number?): Vector3
		return Layout.plotToWorld(bearing, Vector2.new(x, u), y)
	end
	local front = Instance.new("Folder")
	front.Name = "Front"
	front.Parent = visual
	local parkward = (W(0, r0 - 10) - W(0, r0)).Unit

	local cx0, cu0, cx1, cu1 = Layout.bounds(Layout.reservation("EntranceCourt").poly)
	rect(
		front,
		bearing,
		cx0,
		cu0,
		cx1,
		cu1,
		SURFACE + 0.1,
		0.2,
		{ name = "Court", color = Palette.Court, collide = true, castShadow = false }
	)

	-- The plot gate at the promenade's outer edge, its front (mesh +Z) toward the park
	local gateAt = W(0, r0, SURFACE)
	buildGate(front, CFrame.lookAt(gateAt, gateAt - parkward), index)

	-- the upgrade kiosk: a placeholder booth with a blank-for-now panel (no prices or prompts)
	local kx0, ku0, kx1, ku1 = Layout.bounds(Layout.reservation("Kiosk").poly)
	if KitAssets.has("KioskBooth") then
		local at = W((kx0 + kx1) / 2, (ku0 + ku1) / 2, SURFACE)
		local base = CFrame.lookAt(at, at - parkward)
		local kiosk = KitAssets.place("KioskBooth", base, 1, true)
		kiosk.Name = "Kiosk"
		kiosk:SetAttribute("Placeholder", "upgrade kiosk; interactions belong to Lane 2")
		kiosk.Parent = front
		-- the panel face (kit_plot.py): 5.0 x 0.9 at 5.35 up, 2.76 in front of the mesh origin
		local face = base * CFrame.new(0, 5.35, 2.78)
		local panel = facePart(front, "KioskPanel", face.Position, face.Position + parkward, 5, 0.9)
		Signs.kioskPanel(panel)
	else
		box(
			front,
			bearing,
			kx0 + 1,
			ku0 + 1,
			kx1 - 1,
			ku1 - 1,
			6,
			{ name = "Kiosk", color = Palette.Mint, collide = true }
		)
	end

	local wx0, wu0, wx1, wu1 = Layout.bounds(Layout.reservation("PlotWalk").poly)
	rect(
		front,
		bearing,
		wx0,
		wu0,
		wx1,
		wu1,
		SURFACE + 0.1,
		0.2,
		{ name = "Walkway", color = Palette.Paving, collide = true, castShadow = false }
	)

	-- Paddock: floor, aisle, bays (placeholders: painted outlines and numbers; Bay01 to Bay03 are
	-- the starting bays, outlined in yellow), pit lanes
	local paddock = Instance.new("Folder")
	paddock.Name = "Paddock"
	paddock.Parent = visual
	local px0, pu0, px1, pu1 = Layout.bounds(Layout.reservation("Paddock").poly)
	rect(paddock, bearing, px0, pu0, px1, pu1, SURFACE + 0.1, 0.2, {
		name = "Floor",
		color = Color3.fromRGB(206, 200, 190),
		material = Enum.Material.Concrete,
		collide = true,
		castShadow = false,
	})
	rect(paddock, bearing, px0, Layout.Aisle[1], px1, Layout.Aisle[2], SURFACE + 0.12, 0.2, {
		name = "Aisle",
		color = Color3.fromRGB(150, 154, 160),
		material = Enum.Material.Asphalt,
		collide = true,
		castShadow = false,
	})
	for _, bay in Layout.Bays do
		local rowU = if bay.row == "A" then Layout.RowA else Layout.RowB
		local tile =
			rect(paddock, bearing, bay.x - 4.2, rowU[1] + 0.3, bay.x + 4.2, rowU[2] - 0.3, SURFACE + 0.14, 0.04, {
				name = string.format("Bay%02d", bay.index),
				color = if bay.initial then Color3.fromRGB(196, 190, 180) else Color3.fromRGB(214, 210, 202),
				material = Enum.Material.Concrete,
				castShadow = false,
			})
		if tile then
			tile:SetAttribute("BayIndex", bay.index)
			tile:SetAttribute("Placeholder", "bay; car placement belongs to Lane 2")
			Signs.bayNumber(tile, bay.index, bay.initial, bay.facing)
		end
		-- painted outline: two sides and the back line (open toward the aisle)
		local line = {
			name = "BayLine",
			color = if bay.initial then Color3.fromRGB(246, 200, 60) else Color3.new(1, 1, 1),
			castShadow = false,
		}
		local back = if bay.row == "A" then rowU[1] + 0.3 else rowU[2] - 0.3
		local open = if bay.row == "A" then rowU[2] - 0.3 else rowU[1] + 0.3
		for _, sx in { -4.2, 4.2 } do
			Kit.strip(paddock, W(bay.x + sx, back), W(bay.x + sx, open), 0.25, 0.03, SURFACE + 0.17, line, 0)
		end
		Kit.strip(paddock, W(bay.x - 4.2, back), W(bay.x + 4.2, back), 0.25, 0.03, SURFACE + 0.17, line, 0)
	end
	polyline(
		paddock,
		bearing,
		Layout.PitOut,
		Layout.PitLaneWidth,
		SURFACE + 0.13,
		{ name = "PitOut", color = Color3.fromRGB(70, 74, 82), castShadow = false }
	)
	polyline(
		paddock,
		bearing,
		Layout.PitIn,
		Layout.PitLaneWidth,
		SURFACE + 0.13,
		{ name = "PitIn", color = Color3.fromRGB(70, 74, 82), castShadow = false }
	)
end

function PlotRecipe.build(plot: Model, index: number)
	local bearing = Layout.plotBearing(index)
	local visual = Instance.new("Folder")
	visual.Name = "Visual"
	buildFront(visual, bearing, index)
	buildSpeedway(visual, bearing, index)
	buildFlags(visual, bearing)
	visual.Parent = plot
end

return PlotRecipe
