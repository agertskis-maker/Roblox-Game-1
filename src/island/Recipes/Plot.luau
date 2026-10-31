--!strict
-- One plot, Stage A greybox: the Speedway (surface, barrier, curb), START / FINISH,
-- the viewing bridge and ramps, the Paddock with its bays and pit lanes, and the gate.
-- Helpers (centreline, clearance edges, reserves, labels) go in a separate folder so
-- they can be hidden after review. No decoration, no ownership, no gameplay.

local Kit = require(script.Parent.Parent.Kit)
local Layout = require(script.Parent.Parent.Layout)
local Palette = require(script.Parent.Parent.WorldPalette)

local PlotRecipe = {}

local SURFACE = Layout.SurfaceY
local TRACK_TOP = SURFACE + 0.2
local HALF_W = Layout.Track.width / 2
local CHORD_ERROR = 0.15

type Node = { s: number, p: Vector2, t: Vector2 }

-- Path nodes: straight ends, and arcs split so the outer barrier's chord error stays within CHORD_ERROR.
local function trackNodes(): { Node }
	local nodes: { Node } = {}
	local path = Layout.Path
	for _, seg in path.segments do
		local pieces = 1
		if seg.kind == "arc" then
			local outerR = seg.radius + HALF_W + Layout.Track.barrier
			local step = 2 * math.acos(1 - CHORD_ERROR / outerR)
			pieces = math.max(1, math.ceil(math.abs(seg.sweep) / step))
		end
		for k = 0, pieces - 1 do
			local s = seg.s0 + seg.length * k / pieces
			local p, t = Layout.pointAt(path, s)
			table.insert(nodes, { s = s, p = p, t = t })
		end
	end
	return nodes
end

local NODES = trackNodes()
PlotRecipe.SegmentCount = #NODES

-- Strips along the loop at a lateral offset (+ outward).
local function ring(
	parent: Instance,
	bearing: number,
	offset: number,
	width: number,
	thickness: number,
	topY: number,
	options: Kit.PartOptions,
	overlap: number
)
	local n = #NODES
	for i = 1, n do
		local a, b = NODES[i], NODES[i % n + 1]
		local pa = a.p + Layout.outward(a.t) * offset
		local pb = b.p + Layout.outward(b.t) * offset
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
)
	local a = Layout.plotToWorld(bearing, Vector2.new((x0 + x1) / 2, u0))
	local b = Layout.plotToWorld(bearing, Vector2.new((x0 + x1) / 2, u1))
	return Kit.strip(parent, a, b, math.abs(x1 - x0), thickness, topY, options, 0)
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

function PlotRecipe.build(plot: Model, helpers: Folder, index: number, withDimensions: boolean)
	local bearing = Layout.plotBearing(index)
	local visual = Instance.new("Folder")
	visual.Name = "Visual"
	local W = function(x: number, u: number, y: number?): Vector3
		return Layout.plotToWorld(bearing, Vector2.new(x, u), y)
	end

	-- Speedway
	local track = Instance.new("Folder")
	track.Name = "Speedway"
	track.Parent = visual
	ring(
		track,
		bearing,
		0,
		Layout.Track.width,
		0.4,
		TRACK_TOP,
		{ name = "Surface", color = Palette.Navy, collide = true, castShadow = false },
		2
	)
	ring(
		track,
		bearing,
		HALF_W + 0.5,
		1,
		2,
		TRACK_TOP + 2,
		{ name = "Barrier", color = Palette.Cream, collide = true, castShadow = false },
		0.6
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

	-- START / FINISH line and gantry footprint
	local sp, st = Layout.pointAt(Layout.Path, Layout.StartS)
	local n = Layout.outward(st)
	Kit.strip(
		track,
		Layout.plotToWorld(bearing, sp - n * HALF_W),
		Layout.plotToWorld(bearing, sp + n * HALF_W),
		1.2,
		0.06,
		TRACK_TOP + 0.04,
		{ name = "StartLine", color = Color3.new(1, 1, 1), castShadow = false },
		0
	)
	for _, side in { -1, 1 } do
		local post = sp + n * side * (HALF_W + 2)
		Kit.part(
			track,
			Vector3.new(1.2, 11, 1.2),
			CFrame.new(Layout.plotToWorld(bearing, post, SURFACE + 5.5)),
			{ name = "GantryPost", color = Palette.Navy, collide = true }
		)
	end
	Kit.strip(
		track,
		Layout.plotToWorld(bearing, sp - n * (HALF_W + 2.6)),
		Layout.plotToWorld(bearing, sp + n * (HALF_W + 2.6)),
		1.5,
		1.5,
		SURFACE + 11.5,
		{ name = "GantryBeam", color = Palette.Navy },
		0
	)

	-- Paddock: floor, aisle (spanning the infield), bays, pit lanes
	local paddock = Instance.new("Folder")
	paddock.Name = "Paddock"
	paddock.Parent = visual
	local halfB = Layout.Paddock.rowB * Layout.Paddock.bayWidth / 2
	rect(
		paddock,
		bearing,
		-halfB - 1,
		Layout.RowA[1] - 1,
		halfB + 1,
		Layout.RowB[2] + 1,
		SURFACE + 0.1,
		0.2,
		{ name = "Floor", color = Palette.Paving, collide = true, castShadow = false }
	)
	rect(
		paddock,
		bearing,
		-Layout.AisleHalfSpan,
		Layout.Aisle[1],
		Layout.AisleHalfSpan,
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
		Layout.PitIn,
		9,
		SURFACE + 0.13,
		{ name = "PitIn", color = Palette.Promenade, castShadow = false }
	)
	polyline(
		paddock,
		bearing,
		Layout.PitOut,
		9,
		SURFACE + 0.13,
		{ name = "PitOut", color = Palette.Promenade, castShadow = false }
	)

	-- Viewing bridge: deck, landing, ramps, rails, pillars (walkable greybox)
	local bridge = Instance.new("Folder")
	bridge.Name = "Bridge"
	bridge.Parent = visual
	local b = Layout.Bridge
	local deckTop = SURFACE + b.deckTop
	rect(
		bridge,
		bearing,
		-b.width / 2,
		Layout.DeckU[1],
		b.width / 2,
		Layout.DeckU[2],
		deckTop,
		b.deckThickness,
		{ name = "Deck", color = Palette.Cream, collide = true }
	)
	rect(
		bridge,
		bearing,
		-b.landingWidth / 2,
		Layout.LandingU[1],
		b.landingWidth / 2,
		Layout.LandingU[2] + 0.5,
		deckTop,
		b.deckThickness,
		{ name = "Landing", color = Palette.Cream, collide = true }
	)
	for _, r in Layout.FrontRamps do
		Kit.ramp(
			bridge,
			Layout.plotToWorld(bearing, r.from, SURFACE),
			Layout.plotToWorld(bearing, r.to, deckTop),
			b.rampWidth,
			{ name = "FrontRamp", color = Palette.Paving, collide = true }
		)
	end
	Kit.ramp(
		bridge,
		Layout.plotToWorld(bearing, Layout.RearRamp.from, SURFACE),
		Layout.plotToWorld(bearing, Layout.RearRamp.to, deckTop),
		b.width,
		{ name = "RearRamp", color = Palette.Paving, collide = true }
	)
	for _, side in { -1, 1 } do
		local x = side * (b.width / 2 - 0.25)
		Kit.wall(
			bridge,
			W(x, Layout.DeckU[1] + 1.5),
			W(x, Layout.DeckU[2]),
			0.5,
			3,
			deckTop,
			{ name = "Rail", color = Palette.Navy, collide = true }
		)
		for _, u in { Layout.DeckU[1] + 1, Layout.DeckU[2] - 1 } do
			Kit.part(
				bridge,
				Vector3.new(1.5, b.deckTop - b.deckThickness, 1.5),
				CFrame.new(W(side * 3.5, u, SURFACE + (b.deckTop - b.deckThickness) / 2)),
				{ name = "Pillar", color = Palette.Cream, collide = true }
			)
		end
	end

	-- Gate posts and lintel (arch footprint); the nameplate itself is Stage B
	local gateU = Layout.Plaza.gateRadius
	for _, side in { -1, 1 } do
		Kit.part(
			visual,
			Vector3.new(1.5, 9, 1.5),
			CFrame.new(W(side * (Layout.Plaza.gateHalfWidth + 0.75), gateU, SURFACE + 4.5)),
			{ name = "GatePost", color = Palette.Coral, collide = true }
		)
	end
	Kit.strip(
		visual,
		W(-Layout.Plaza.gateHalfWidth - 1.5, gateU),
		W(Layout.Plaza.gateHalfWidth + 1.5, gateU),
		1.5,
		1.2,
		SURFACE + 9.6,
		{ name = "GateLintel", color = Palette.Coral },
		0
	)

	visual.Parent = plot

	-- Helpers
	local h = Instance.new("Folder")
	h.Name = string.format("Plot%02d", index)
	local centre = Instance.new("Folder")
	centre.Name = "Centreline"
	centre.Parent = h
	ring(
		centre,
		bearing,
		0,
		0.4,
		0.05,
		TRACK_TOP + 0.08,
		{ name = "Centre", color = Palette.HelperCentre, castShadow = false },
		0.2
	)
	local edges = Instance.new("Folder")
	edges.Name = "ClearanceEdges"
	edges.Parent = h
	ring(
		edges,
		bearing,
		Layout.OuterOffset,
		0.5,
		0.05,
		SURFACE + 0.07,
		{ name = "OuterClearance", color = Palette.HelperClearance, castShadow = false },
		0.3
	)
	ring(
		edges,
		bearing,
		-Layout.InnerOffset,
		0.5,
		0.05,
		SURFACE + 0.07,
		{ name = "InnerClearance", color = Palette.HelperClearance, castShadow = false },
		0.3
	)
	local reserve = Layout.LoopReserve
	rect(
		h,
		bearing,
		-reserve.width / 2,
		reserve.centerU - reserve.depth / 2,
		reserve.width / 2,
		reserve.centerU + reserve.depth / 2,
		SURFACE + 0.09,
		0.05,
		{
			name = "LoopReserve",
			color = Palette.HelperReserve,
			transparency = 0.6,
			castShadow = false,
		}
	)
	local rampStart = Layout.pointAt(Layout.Path, Layout.RampReserve.s0)
	local rampEnd = Layout.pointAt(Layout.Path, Layout.RampReserve.s0 + Layout.RampReserve.length)
	Kit.strip(
		h,
		Layout.plotToWorld(bearing, rampStart),
		Layout.plotToWorld(bearing, rampEnd),
		Layout.RampReserve.width,
		0.05,
		TRACK_TOP + 0.1,
		{
			name = "RampReserve",
			color = Palette.HelperReserve,
			transparency = 0.7,
			castShadow = false,
		},
		0
	)
	Kit.label(h, W(0, reserve.centerU, SURFACE + 16), string.format("PLOT %02d", index), 28)
	if withDimensions then
		local length = math.round(Layout.Path.length * 10) / 10
		Kit.label(
			h,
			W(0, Layout.BackApexU, SURFACE + 10),
			string.format(
				"Speedway %.1f long, %d wide, tightest R %d",
				length,
				Layout.Track.width,
				Layout.MinTurnRadius
			),
			16
		)
		Kit.label(
			h,
			W(0, Layout.DeckU[2] + 2, SURFACE + 13),
			string.format(
				"Bridge deck %d (%.1f clear over the track), ramps 1 in 2.4",
				b.deckTop,
				b.deckTop - b.deckThickness - (TRACK_TOP - SURFACE)
			),
			14
		)
		Kit.label(
			h,
			W(0, (Layout.RowA[1] + Layout.RowB[2]) / 2, SURFACE + 8),
			"Paddock 72 x 42, bays 9 x 16, Bay01-03 yellow",
			14
		)
		Kit.label(h, Layout.plotToWorld(bearing, sp, SURFACE + 14), "START / FINISH", 14)
		Kit.label(h, W(0, reserve.centerU - 10, SURFACE + 6), "Loop reserve 34 x 38", 13)
		Kit.label(h, Layout.plotToWorld(bearing, rampEnd, SURFACE + 6), "Ramp reserve 72", 13)
		Kit.label(h, W(0, Layout.Plaza.gateRadius, SURFACE + 12), "Gate r 62, spawn u 66", 13)
	end
	h.Parent = helpers
end

return PlotRecipe
