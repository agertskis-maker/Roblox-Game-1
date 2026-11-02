--!strict
-- The obstacles of the Stunt Circuit as LOOKS (Lane 3, M17-01): slalom barriers, potholes, the tunnel, the swinging arms and
-- the narrow bridge. Every one is flagged VisualOnly and NonColliding; the arms carry attributes for an IDLE loop (StuntIdle)
-- and nothing else. An idle animation is not obstacle logic: timing, hit rules and effects are Brian R's.
--
--   Obstacles.build(root: Model) -> ()
--
-- Readability (M17-01c): a pothole has a bright rim round a dark core, the barriers are orange and white like the run's
-- hazard boards and always leave one half of the road open, the tunnel is lit by neon strips and has no roof shadow, and the
-- arms are striped. Nothing hides a hazard behind a crest, a sign or darkness.

local Parts = require(script.Parent.StuntParts)
local StuntData = require(script.Parent.StuntData)

local Obstacles = {}

local P = Parts.Palette
local GROUND = StuntData.Road.groundY
local HALF = StuntData.Road.totalWidth / 2
local PAINT = 0.12

local function leg(s: number): StuntData.Leg
	return StuntData.legOf(s)
end

-- SLALOM ---------------------------------------------------------------------------------------------------------------

local function buildSlalom(root: Folder)
	local folder = Parts.folder(root, "Slalom")
	for _, o in StuntData.Obstacles do
		if o.kind == "SlalomBarrier" then
			local l = leg(o.s)
			local b = o.artBounds
			local u0, u1 = b.s0 - l.s0, b.s1 - l.s0
			local model = Parts.model(folder, o.id)
			Parts.flagVisualOnly(model, o.id, "slalom barrier, looks only")
			Parts.along(model, "Body", l.origin, l.heading, u0, u1, b.lat0, b.lat1, 0, 4.4, P.Orange)
			Parts.along(model, "Cap", l.origin, l.heading, u0, u1, b.lat0, b.lat1, 4.4, 5, P.White)
			-- six white stripes on the face the driver sees, 0.12 proud of it
			local width = b.lat1 - b.lat0
			for i = 0, 5 do
				local centre = b.lat0 + (i + 0.5) * width / 6
				Parts.along(model, "Stripe", l.origin, l.heading, u0 - PAINT, u0, centre - 1.7, centre + 1.7, 0, 4.4, P.White)
			end
		end
	end
end

-- POTHOLES -------------------------------------------------------------------------------------------------------------

local function buildPotholes(root: Folder)
	local folder = Parts.folder(root, "Potholes")
	for _, o in StuntData.Obstacles do
		if o.kind == "Pothole" then
			local at = StuntData.frame(o.s, o.lateral, 0).Position
			local model = Parts.model(folder, o.id)
			Parts.flagVisualOnly(model, o.id, "pothole, looks only")
			-- layer 1: a bright rim 11 across; layer 2: the dark core 9 across, 0.12 above the rim paint
			Parts.disc(model, "Rim", 11, PAINT, at, PAINT, P.Gold)
			Parts.disc(model, "Core", 9, PAINT, at, PAINT * 2, P.PitFloor)
		end
	end
end

-- TUNNEL ---------------------------------------------------------------------------------------------------------------

local function buildTunnel(root: Folder)
	local folder = Parts.folder(root, "Tunnel")
	local r = StuntData.Structures.Tunnel
	local l = leg(r.s0)
	local a0, a1 = r.s0 - l.s0, r.s1 - l.s0
	local wall, roofTop = 4, 23
	Parts.flagVisualOnly(folder, "TUNNEL", "tunnel shell, looks only; the potholes are inside it")
	for _, side in { -1, 1 } do
		local lat0 = if side > 0 then HALF else -HALF - wall
		local lat1 = if side > 0 then HALF + wall else -HALF
		Parts.along(folder, "Wall", l.origin, l.heading, a0, a1, lat0, lat1, GROUND, 20, P.Concrete)
		-- a gold stripe along the inside of each wall (0.12 proud of it)
		local face = if side > 0 then HALF - PAINT else -HALF
		Parts.along(folder, "WallStripe", l.origin, l.heading, a0, a1, face, face + PAINT, 3, 4, P.Gold)
	end
	-- no roof shadow: the inside stays bright so nothing hides in the dark
	Parts.along(folder, "Roof", l.origin, l.heading, a0, a1, -HALF - wall, HALF + wall, 20, roofTop, P.ConcreteDark)
	for _, lat in { -25, 0, 25 } do
		Parts.along(
			folder,
			"LightStrip",
			l.origin,
			l.heading,
			a0 + 4,
			a1 - 4,
			lat - 0.8,
			lat + 0.8,
			19.7,
			20,
			P.NeonCyan,
			{ material = Enum.Material.Neon }
		)
	end
	-- the two portals: a navy frame 4 deep standing just outside each end, edge to edge with the shell
	for i, ends in { { a0 - 4, a0 }, { a1, a1 + 4 } } do
		local u0, u1 = ends[1], ends[2]
		for _, side in { -1, 1 } do
			local lat0 = if side > 0 then HALF + wall else -HALF - wall - wall
			local lat1 = if side > 0 then HALF + wall + wall else -HALF - wall
			Parts.along(folder, "PortalPost" .. i, l.origin, l.heading, u0, u1, lat0, lat1, GROUND, 27, P.Navy)
		end
		Parts.along(
			folder,
			"PortalLintel" .. i,
			l.origin,
			l.heading,
			u0,
			u1,
			-HALF - wall,
			HALF + wall,
			20,
			27,
			P.Navy
		)
		-- a gold band on the face the driver sees (the entrance faces the road behind; the exit faces away)
		local faceU0 = if i == 1 then u0 - PAINT else u1
		Parts.along(
			folder,
			"PortalBand" .. i,
			l.origin,
			l.heading,
			faceU0,
			faceU0 + PAINT,
			-HALF - wall,
			HALF + wall,
			22,
			24,
			P.Gold
		)
	end
end

-- SWINGING ARMS ----------------------------------------------------------------------------------------------------------

local function buildArms(root: Folder)
	local folder = Parts.folder(root, "Arms")
	for _, o in StuntData.Obstacles do
		local idle = o.idle
		if o.kind == "SwingingArm" and idle then
			local l = leg(o.s)
			local side = if idle.pivotLateral < 0 then -1 else 1
			local hub = StuntData.frame(idle.pivotS, idle.pivotLateral, idle.pivotY)
			local across = -side * l.heading:Cross(Vector3.yAxis) -- from the post toward the road
			local model = Parts.model(folder, o.id)
			Parts.flagVisualOnly(model, o.id, "swinging arm, looks and an idle swing only")
			model:SetAttribute("IdleKind", idle.kind)
			model:SetAttribute("IdlePeriod", idle.periodSeconds)
			model:SetAttribute("IdleSweepDegrees", idle.sweepDegrees)
			model:SetAttribute("IdlePhase", idle.phase)
			-- the static mast, then the arm model that turns about the hub
			Parts.box(
				folder,
				o.id .. "Mast",
				Vector3.new(3.4, 10.5, 3.4),
				CFrame.new(hub.Position.X, GROUND + 5.25, hub.Position.Z),
				P.Steel,
				{ attributes = { VisualOnly = true } }
			)
			local pivot = CFrame.lookAt(hub.Position, hub.Position + across) -- LookVector points along the arm at rest
			Parts.cylinder(
				model,
				"Hub",
				5,
				5,
				CFrame.new(hub.Position) * CFrame.Angles(0, 0, math.pi / 2),
				P.Orange
			)
			local reach = idle.lengthStuds - 2.5
			local segment = reach / 6
			for i = 0, 5 do
				local colour = if i % 2 == 0 then P.Orange else P.White
				Parts.box(
					model,
					"ArmSegment" .. i,
					Vector3.new(2.4, 3.5, segment),
					pivot * CFrame.new(0, 0, -(2.5 + (i + 0.5) * segment)),
					colour
				)
			end
			local tip = Parts.box(
				model,
				"TipLamp",
				Vector3.new(2.6, 2.6, 2.6),
				pivot * CFrame.new(0, 0, -(idle.lengthStuds + 1.3)),
				P.Red,
				{ material = Enum.Material.Neon }
			)
			tip.Shape = Enum.PartType.Ball
			Parts.box(model, "Counterweight", Vector3.new(3, 3, 5), pivot * CFrame.new(0, 0, 5), P.Steel)
			model.WorldPivot = pivot
		end
	end
end

-- NARROW BRIDGE ----------------------------------------------------------------------------------------------------------

-- A wall standing on the slab, set at an angle: from lateral `fromLat` at s `s0` to `toLat` at `s1`.
local function angledWall(
	parent: Instance,
	name: string,
	s0: number,
	s1: number,
	fromLat: number,
	toLat: number,
	colour: Color3
)
	local l = leg(s0)
	local a = l.origin + l.heading * (s0 - l.s0)
	local b = l.origin + l.heading * (s1 - l.s0)
	local right = l.heading:Cross(Vector3.yAxis)
	local pa, pb = a + right * fromLat, b + right * toLat
	local mid = (pa + pb) / 2 + Vector3.new(0, 1.5, 0)
	Parts.box(parent, name, Vector3.new(2, 3, (pb - pa).Magnitude), CFrame.lookAt(mid, mid + (pb - pa)), colour)
	Parts.box(
		parent,
		name .. "Cap",
		Vector3.new(2.6, 0.4, (pb - pa).Magnitude),
		CFrame.lookAt(mid + Vector3.new(0, 1.7, 0), mid + Vector3.new(0, 1.7, 0) + (pb - pa)),
		P.Gold
	)
end

local function buildBridge(root: Folder)
	local folder = Parts.folder(root, "Bridge")
	Parts.flagVisualOnly(folder, "BRIDGE", "narrow bridge parapets and funnel, looks only")
	local deck: StuntData.Piece? = nil
	for _, piece in StuntData.Pieces do
		if piece.kind == "Deck" then
			deck = piece
		end
	end
	assert(deck, "the surface has no bridge deck")
	local l = leg(deck.s0)
	local a0, a1 = deck.s0 - l.s0, deck.s1 - l.s0
	for _, side in { -1, 1 } do
		local lat0 = if side > 0 then 17 else -19
		local lat1 = if side > 0 then 19 else -17
		Parts.along(folder, "Parapet", l.origin, l.heading, a0, a1, lat0, lat1, 0, 3, P.Navy)
		Parts.along(folder, "ParapetCap", l.origin, l.heading, a0, a1, lat0 - 0.5, lat1 + 0.5, 3, 3.4, P.Gold)
		-- three lamp posts on each parapet
		for k = 1, 3 do
			local u = a0 + k * (a1 - a0) / 4
			local lat = side * 18
			Parts.along(folder, "LampPost", l.origin, l.heading, u - 0.4, u + 0.4, lat - 0.4, lat + 0.4, 3.4, 10, P.Steel)
			Parts.along(
				folder,
				"LampHead",
				l.origin,
				l.heading,
				u - 1,
				u + 1,
				lat - 1,
				lat + 1,
				10,
				12,
				P.Lamp,
				{ material = Enum.Material.Neon }
			)
		end
	end
	-- the funnel: angled walls guide the full-width road onto the deck, and back out again
	local fin, fout = StuntData.Structures.BridgeFunnelIn, StuntData.Structures.BridgeFunnelOut
	angledWall(folder, "FunnelInLeft", fin.s0, fin.s1, -HALF + 1, -19, P.Navy)
	angledWall(folder, "FunnelInRight", fin.s0, fin.s1, HALF - 1, 19, P.Navy)
	angledWall(folder, "FunnelOutLeft", fout.s0, fout.s1, -19, -HALF + 1, P.Navy)
	angledWall(folder, "FunnelOutRight", fout.s0, fout.s1, 19, HALF - 1, P.Navy)
end

-- ENTRY ------------------------------------------------------------------------------------------------------------------

function Obstacles.build(root: Model)
	local folder = Parts.folder(root, "Obstacles")
	folder:SetAttribute("VisualOnly", true)
	folder:SetAttribute("NonColliding", true)
	folder:SetAttribute("Note", "looks and idle motion only; no collision, no gameplay (Brian R owns obstacle behaviour)")
	buildSlalom(folder)
	buildPotholes(folder)
	buildTunnel(folder)
	buildArms(folder)
	buildBridge(folder)
end

return Obstacles
