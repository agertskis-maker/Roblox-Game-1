--!strict
-- One hub plot's front (Task 3, 2026-10-22; Task 4 gate): front to back the entrance court and
-- gate with its nameplate, the upgrade kiosk, the Paddock with 15 marked bay placeholders, the
-- walkway and the pit lanes. The Speedway itself (track, edges, stands and everything that grows)
-- is assembled per client for the plot's level by the Speedway look module
-- (ReplicatedStorage.Shared.Island.Speedway.Look; Home/Island/SpeedwayLooks): the Task 3 base
-- track moved there and now arrives at level 4 (Adam, 2026-10-28; decision 0025). Visuals only:
-- no ownership, saved data or gameplay.

local KitAssets = require(script.Parent.Parent.Environment.KitAssets)
local Kit = require(script.Parent.Parent.Parent.Kit)
local Layout = require(script.Parent.Parent.Layout)
local Palette = require(script.Parent.Parent.Parent.WorldPalette)
local Signs = require(script.Parent.Parent.Environment.Signs)

local PlotRecipe = {}

local SURFACE = Layout.SurfaceY
-- The preview level each plot shows until Lane 2 supplies a real one (Tunable, preview only):
-- one plot per stage of the ladder, so the plaza view shows the progression.
PlotRecipe.PreviewLevels = { 1, 3, 5, 8, 10, 12 }

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
	visual.Parent = plot
	plot:SetAttribute("SpeedwayPreviewLevel", PlotRecipe.PreviewLevels[(index - 1) % #PlotRecipe.PreviewLevels + 1])
end

return PlotRecipe
