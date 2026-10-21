--!strict
-- One hub plot, greybox: front to back the entrance court and gate, kiosk, Paddock with 15
-- bays, the walkway, the pit lanes and the base Speedway oval (surface, barrier, curb,
-- yellow edge lines, checkered start / finish line, barrier banners) and the base flag line
-- in the sign band. Everything later (bleachers, grandstand, floodlights, gantry, loop, signs)
-- is reserved space only and drawn by the reservation overlay. No ownership or gameplay.

local Kit = require(script.Parent.Parent.Parent.Kit)
local Layout = require(script.Parent.Parent.Layout)
local Palette = require(script.Parent.Parent.Parent.WorldPalette)

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

local function buildSpeedway(visual: Folder, bearing: number)
	local track = Instance.new("Folder")
	track.Name = "Speedway"
	track.Parent = visual
	ring(
		track,
		bearing,
		0,
		HALF_W * 2,
		0.4,
		TRACK_TOP,
		{ name = "Surface", color = Palette.Navy, collide = true, castShadow = false },
		2
	)
	for _, side in { -1, 1 } do
		ring(
			track,
			bearing,
			side * (HALF_W - 0.9),
			0.5,
			0.05,
			TRACK_TOP + 0.03,
			{ name = "YellowLine", color = Palette.Yellow, castShadow = false },
			0.3
		)
	end
	ring(
		track,
		bearing,
		HALF_W + 0.5,
		1,
		2,
		TRACK_TOP + 2,
		{ name = "Barrier", color = Palette.Cream, collide = true, castShadow = false },
		0.6,
		Layout.inPitGap
	)
	ring(
		track,
		bearing,
		-HALF_W - 0.5,
		1,
		0.35,
		TRACK_TOP + 0.15,
		{ name = "Curb", color = Color3.new(1, 1, 1), collide = true, castShadow = false },
		0.4
	)

	-- Checkered start / finish line: 8 tiles across, 2 rows
	local sp, st = Layout.pointAt(Layout.StartS)
	local n = Layout.outward(st)
	local tile = HALF_W * 2 / 8
	for row = 0, 1 do
		for k = 0, 7 do
			local c = sp + n * (-HALF_W + tile * (k + 0.5)) + st * (row - 0.5) * tile
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

	-- Banners on the barrier's outer face along both straights
	local colours = { Palette.Coral, Palette.Mint, Palette.Yellow }
	for side, seg in { Layout.RightStraight, Layout.LeftStraight } do
		local dir = (seg.to - seg.from).Unit
		local out = Layout.outward(dir)
		local count = 4
		for k = 1, count do
			local mid = seg.from + dir * (seg.length * (k - 0.5) / count) + out * (HALF_W + 1.06)
			Kit.part(
				track,
				Vector3.new(0.1, 1.6, 10),
				CFrame.lookAt(
					Layout.plotToWorld(bearing, mid, TRACK_TOP + 1.1),
					Layout.plotToWorld(bearing, mid + dir, TRACK_TOP + 1.1)
				),
				{ name = "Banner", color = colours[(k + side) % 3 + 1], castShadow = false }
			)
		end
	end
end

-- Base flag line in the outer sign band (replaced by signs at tier 2, a later upgrade).
local function buildFlags(visual: Folder, bearing: number)
	local flags = Instance.new("Folder")
	flags.Name = "FlagLine"
	flags.Parent = visual
	local _, u0, _, u1 = Layout.bounds(Layout.reservation("SignBand").poly)
	local u = (u0 + u1) / 2
	local colours = { Palette.Coral, Palette.Yellow, Palette.Mint, Color3.new(1, 1, 1) }
	for k = -4, 4 do
		local x = k * 20
		Kit.part(
			flags,
			Vector3.new(0.5, 12, 0.5),
			CFrame.new(Layout.plotToWorld(bearing, Vector2.new(x, u), SURFACE + 6)),
			{ name = "FlagPole", color = Palette.Cream, collide = true }
		)
		local a = Layout.plotToWorld(bearing, Vector2.new(x, u), SURFACE + 10.5)
		local b = Layout.plotToWorld(bearing, Vector2.new(x + 1, u), SURFACE + 10.5)
		Kit.part(
			flags,
			Vector3.new(4, 2.5, 0.2),
			CFrame.lookAt(a, a + (a - b):Cross(Vector3.yAxis)) * CFrame.new(2.2, 0, 0),
			{ name = "Flag", color = colours[(k + 4) % 4 + 1], castShadow = false }
		)
	end
end

local function buildFront(visual: Folder, bearing: number)
	local r0 = Layout.EntranceRadius
	local W = function(x: number, u: number, y: number?): Vector3
		return Layout.plotToWorld(bearing, Vector2.new(x, u), y)
	end
	local front = Instance.new("Folder")
	front.Name = "Front"
	front.Parent = visual

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

	-- Gate arch at the promenade's outer edge, facing the park, with a blank nameplate
	local half = Layout.GateHalfWidth
	for _, side in { -1, 1 } do
		Kit.part(
			front,
			Vector3.new(1.5, 9, 1.5),
			CFrame.new(W(side * (half + 0.75), r0, SURFACE + 4.5)),
			{ name = "GatePost", color = Palette.Coral, collide = true }
		)
	end
	Kit.strip(
		front,
		W(-half - 1.5, r0),
		W(half + 1.5, r0),
		1.5,
		1.2,
		SURFACE + 9.6,
		{ name = "GateLintel", color = Palette.Coral },
		0
	)
	Kit.part(
		front,
		Vector3.new(10, 2.5, 0.4),
		CFrame.lookAt(W(0, r0 - 0.8, SURFACE + 7), W(0, r0 - 2, SURFACE + 7)),
		{ name = "Nameplate", color = Palette.Cream, castShadow = false }
	)

	local kx0, ku0, kx1, ku1 = Layout.bounds(Layout.reservation("Kiosk").poly)
	box(front, bearing, kx0 + 1, ku0 + 1, kx1 - 1, ku1 - 1, 6, { name = "Kiosk", color = Palette.Mint, collide = true })

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

	-- Paddock: floor, aisle, bays (Bay01 to Bay03 shown in yellow), pit lanes
	local paddock = Instance.new("Folder")
	paddock.Name = "Paddock"
	paddock.Parent = visual
	local px0, pu0, px1, pu1 = Layout.bounds(Layout.reservation("Paddock").poly)
	rect(
		paddock,
		bearing,
		px0,
		pu0,
		px1,
		pu1,
		SURFACE + 0.1,
		0.2,
		{ name = "Floor", color = Palette.Paving, collide = true, castShadow = false }
	)
	rect(
		paddock,
		bearing,
		px0,
		Layout.Aisle[1],
		px1,
		Layout.Aisle[2],
		SURFACE + 0.12,
		0.2,
		{ name = "Aisle", color = Palette.Promenade, collide = true, castShadow = false }
	)
	for _, bay in Layout.Bays do
		local rowU = if bay.row == "A" then Layout.RowA else Layout.RowB
		local tile =
			rect(paddock, bearing, bay.x - 4.2, rowU[1] + 0.3, bay.x + 4.2, rowU[2] - 0.3, SURFACE + 0.16, 0.06, {
				name = string.format("Bay%02d", bay.index),
				color = if bay.initial then Palette.Yellow else Palette.BayReserved,
				transparency = if bay.initial then 0 else 0.35,
				castShadow = false,
			})
		if tile then
			tile:SetAttribute("BayIndex", bay.index)
		end
	end
	polyline(
		paddock,
		bearing,
		Layout.PitOut,
		Layout.PitLaneWidth,
		SURFACE + 0.13,
		{ name = "PitOut", color = Palette.Promenade, castShadow = false }
	)
	polyline(
		paddock,
		bearing,
		Layout.PitIn,
		Layout.PitLaneWidth,
		SURFACE + 0.13,
		{ name = "PitIn", color = Palette.Promenade, castShadow = false }
	)
end

function PlotRecipe.build(plot: Model, index: number)
	local bearing = Layout.plotBearing(index)
	local visual = Instance.new("Folder")
	visual.Name = "Visual"
	buildFront(visual, bearing)
	buildSpeedway(visual, bearing)
	buildFlags(visual, bearing)
	visual.Parent = plot
end

return PlotRecipe
