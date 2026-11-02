--!strict
-- Part-built PROXIES for the Downtown B city (Lane 3 preview). Used for every module whose B2
-- kit mesh does not exist (yet), so a route always reads at chase speed: lots, landmarks, road
-- pieces, props, spans, hazard previews and street pieces. Each proxy is a Model built at the
-- origin with WorldPivot at its placement pivot and attribute Proxy, so it can be pooled and
-- moved with PivotTo. Anchored, no collision, no query, no touch; no Transparency on scenery.
--
-- Local frames:
--   lot / landmark  facade faces local -Z at z = 0, footprint x 0..width, z 0..depth, y up;
--                   pivot (0,0,0) = the front-left corner (the building's own left)
--   road piece      pivot = the start socket, travel toward -Z (Route.localFrame)
--   prop            stands at the origin, its front (-Z) toward the road

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Parts = require(script.Parent.Parent.Parts)
local Route = require(script.Parent.Route)
local Tokens = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UI"):WaitForChild("Tokens"))

local Proxies = {}

export type Geometry = {
	lanes: number,
	laneWidth: number,
	shoulder: number,
	halfRoad: number,
	kerb: number,
	sidewalk: number,
}

export type Look = { wall: Color3, trim: Color3, accent: Color3, roof: Color3 }

local ASPHALT = Color3.fromRGB(78, 82, 92)
local PAINT = Color3.fromRGB(244, 242, 234)
local KERB = Color3.fromRGB(196, 192, 184)
local WALK = Color3.fromRGB(220, 214, 202)
local GLASS = Color3.fromRGB(58, 74, 98)
local GREEN = Color3.fromRGB(112, 168, 98)
local LEAF = Color3.fromRGB(86, 150, 84)
local TRUNK = Color3.fromRGB(110, 84, 64)
local STEEL = Color3.fromRGB(96, 102, 116)
local STONE = Color3.fromRGB(206, 200, 186)
local WATER = Color3.fromRGB(70, 146, 176)
local CREAM = Color3.fromRGB(250, 244, 228)
local NAVY = Color3.fromRGB(30, 42, 74)
local KERB_HEIGHT = 0.6 -- kerb and sidewalk top, as in the look-dev fixture

local function model(name: string, note: string): Model
	local m = Instance.new("Model")
	m.Name = name
	m:SetAttribute("Proxy", note)
	return m
end

local function finish(m: Model): Model
	m.WorldPivot = CFrame.identity
	return m
end

local function box(parent: Instance, name: string, size: Vector3, cf: CFrame, colour: Color3, shadow: boolean?): Part
	local p = Parts.block(parent, name, size, cf, colour)
	p.CastShadow = shadow ~= false
	return p
end

-- Text on one face of a part (SurfaceGui, pixels per stud). rotation -90 runs text up a tall
-- board.
function Proxies.text(part: BasePart, face: Enum.NormalId, text: string, colour: Color3?, rotation: number?)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Text" .. face.Name
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 24
	gui.LightInfluence = 1
	gui.MaxDistance = 600
	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.BackgroundTransparency = 1
	label.TextScaled = true
	label.FontFace = Tokens.font()
	label.TextColor3 = colour or NAVY
	label.Text = text
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.fromScale(0.5, 0.5)
	if rotation and math.abs(rotation) == 90 then
		-- the face's canvas is (width, height); a rotated label swaps them
		local size = part.Size
		local w, h
		if face == Enum.NormalId.Left or face == Enum.NormalId.Right then
			w, h = size.Z, size.Y
		else
			w, h = size.X, size.Y
		end
		label.Size = UDim2.fromScale(h / w * 0.92, w / h * 0.8)
		label.Rotation = rotation
	else
		label.Size = UDim2.fromScale(0.92, 0.8)
	end
	label.Parent = gui
	gui.Parent = part
end

-- Updates every text label under `root` (pooled signs reuse their boards).
function Proxies.setText(root: Instance, text: string)
	for _, d in root:GetDescendants() do
		if d:IsA("TextLabel") and d.Name == "Label" then
			d.Text = text
		end
	end
end

local function tree(parent: Instance, at: Vector3, scale: number)
	box(parent, "Trunk", Vector3.new(0.8, 6, 0.8) * scale, CFrame.new(at + Vector3.new(0, 3 * scale, 0)), TRUNK)
	local canopy = Parts.block(
		parent,
		"Canopy",
		Vector3.new(7, 7, 7) * scale,
		CFrame.new(at + Vector3.new(0, 8.5 * scale, 0)),
		LEAF,
		Enum.PartType.Ball
	)
	canopy.CastShadow = true
end

-- Lots ----------------------------------------------------------------------------------------

export type LotSpec = {
	name: string,
	kind: string,
	width: number,
	depth: number,
	height: number,
	orientation: string,
	finish: string,
	shop: boolean,
}

function Proxies.lot(spec: LotSpec, look: Look, label: boolean): Model
	local m = model("PROXY_" .. spec.name, "part-built lot proxy for " .. spec.name .. " (B2 mesh missing)")
	local w, d, h = spec.width, spec.depth, spec.height
	if spec.kind == "park" or spec.name == "GAP" then
		local pad = box(
			m,
			"Ground",
			Vector3.new(w, 0.4, d),
			CFrame.new(w / 2, 0.2, d / 2),
			if spec.name == "GAP" then STONE else GREEN,
			false
		)
		if spec.name == "GAP" then
			box(m, "Planter", Vector3.new(math.min(w - 1, 6), 1.6, 3), CFrame.new(w / 2, 0.8, 2.5), STEEL)
			tree(m, Vector3.new(w / 2, 1.6, 2.5), 0.6)
		else
			tree(m, Vector3.new(w * 0.3, 0.4, d * 0.4), 1)
			tree(m, Vector3.new(w * 0.72, 0.4, d * 0.7), 1.15)
			box(m, "Bench", Vector3.new(5, 1.2, 1.6), CFrame.new(w * 0.6, 1, 3), Color3.fromRGB(150, 104, 70))
			box(m, "Path", Vector3.new(3, 0.45, d), CFrame.new(w * 0.5, 0.22, d / 2), STONE, false)
		end
		if label then
			Parts.label(pad, spec.name, 4)
		end
		return finish(m)
	end
	local body = box(m, "Body", Vector3.new(w, h, d), CFrame.new(w / 2, h / 2, d / 2), look.wall)
	box(m, "Cornice", Vector3.new(w + 0.8, 1.6, 1.4), CFrame.new(w / 2, h - 0.8, -0.3), look.trim)
	box(m, "Roof", Vector3.new(w - 1, 0.4, d - 1), CFrame.new(w / 2, h + 0.2, d / 2), look.roof)
	local glassy = spec.finish == "glass"
	if spec.shop then
		box(m, "Storefront", Vector3.new(w - 2, 9, 0.3), CFrame.new(w / 2, 5, -0.1), GLASS)
		box(m, "SignBand", Vector3.new(w - 1, 2.4, 0.5), CFrame.new(w / 2, 11.4, -0.2), look.trim)
		box(m, "Awning", Vector3.new(w - 4, 0.4, 3), CFrame.new(w / 2, 10, -1.6), look.accent)
	else
		box(m, "Entrance", Vector3.new(math.min(8, w / 3), 9, 0.3), CFrame.new(w / 2, 4.5, -0.1), GLASS)
	end
	local y = if spec.shop then 18 else 14
	while y + 5 < h - 2 do
		box(m, "Windows", Vector3.new(w - 4, if glassy then 8 else 4.5, 0.3), CFrame.new(w / 2, y, -0.12), GLASS)
		y += 12
	end
	if spec.orientation == "corner-L" or spec.orientation == "corner-R" then
		-- the dressed return on the corner side (left = x 0, right = x width)
		local x = if spec.orientation == "corner-L" then -0.12 else w + 0.12
		box(m, "ReturnPilaster", Vector3.new(0.5, h, 1.6), CFrame.new(x, h / 2, 0.8), look.trim)
		local wy = 18
		while wy + 5 < h - 2 do
			box(m, "ReturnWindows", Vector3.new(0.3, 4.5, d - 6), CFrame.new(x, wy, d / 2), GLASS)
			wy += 12
		end
		box(m, "ReturnStorefront", Vector3.new(0.3, 9, d - 6), CFrame.new(x, 5, d / 2), GLASS)
	end
	if spec.kind == "courtyard" then
		box(m, "CourtWall", Vector3.new(w, 2.4, 0.8), CFrame.new(w / 2, 1.2, -0.4), look.trim)
	end
	if label then
		Parts.label(body, spec.name, h / 2 + 3)
	end
	return finish(m)
end

-- A paved forecourt in front of a set-back (courtyard) lot: x 0..width, z -setback..0.
function Proxies.forecourt(width: number, setback: number): Model
	local m = model("PROXY_Forecourt", "courtyard forecourt paving")
	box(m, "Paving", Vector3.new(width, 0.5, setback), CFrame.new(width / 2, 0.35, -setback / 2), STONE, false)
	tree(m, Vector3.new(width * 0.25, 0.6, -setback * 0.5), 0.8)
	tree(m, Vector3.new(width * 0.75, 0.6, -setback * 0.5), 0.8)
	return finish(m)
end

-- Landmarks -----------------------------------------------------------------------------------

export type LandmarkSpec = {
	id: string,
	name: string,
	label: string,
	width: number,
	depth: number,
	height: number,
}

local function signBoard(parent: Instance, text: string, size: Vector3, cf: CFrame, colour: Color3, both: boolean?)
	local board = box(parent, "SignBoard", size, cf, colour)
	Proxies.text(board, Enum.NormalId.Front, text)
	if both then
		Proxies.text(board, Enum.NormalId.Back, text)
	end
	return board
end

function Proxies.landmark(spec: LandmarkSpec, look: Look, label: boolean, geometry: Geometry): Model
	local m = model("PROXY_" .. spec.name, "part-built landmark proxy for " .. spec.name .. " (B2 mesh missing)")
	m:SetAttribute("Landmark", spec.id)
	local w, d, h = spec.width, spec.depth, spec.height
	local anchor: BasePart
	if spec.id == "Theater" then
		anchor = box(m, "Body", Vector3.new(w, h, d), CFrame.new(w / 2, h / 2, d / 2), look.wall)
		box(m, "Cornice", Vector3.new(w + 1, 2, 1.6), CFrame.new(w / 2, h - 1, -0.4), look.trim)
		box(m, "Lobby", Vector3.new(w - 8, 10, 0.3), CFrame.new(w / 2, 5, -0.1), GLASS)
		local marquee = box(m, "Marquee", Vector3.new(w - 6, 4, 10), CFrame.new(w / 2, 13, -5), CREAM)
		Proxies.text(marquee, Enum.NormalId.Front, spec.label)
		-- vertical blade sign facing the approach (perpendicular to the facade)
		local blade =
			box(m, "BladeSign", Vector3.new(0.8, 28, 7), CFrame.new(w - 7, h + 2, -3.5), Color3.fromRGB(200, 60, 64))
		Proxies.text(blade, Enum.NormalId.Left, spec.label, CREAM, -90)
		Proxies.text(blade, Enum.NormalId.Right, spec.label, CREAM, 90)
	elseif spec.id == "CityHall" then
		local back = 14
		box(m, "Plaza", Vector3.new(w, 0.5, back), CFrame.new(w / 2, 0.35, back / 2 - 0.0), STONE, false)
		anchor = box(m, "Hall", Vector3.new(w, 30, d - back), CFrame.new(w / 2, 15, back + (d - back) / 2), look.wall)
		box(m, "Pediment", Vector3.new(w * 0.5, 6, 2), CFrame.new(w / 2, 33, back + 0.5), look.trim)
		for i = 0, 5 do
			box(m, "Column", Vector3.new(1.6, 24, 1.6), CFrame.new(w * 0.27 + i * w * 0.092, 12, back - 1.2), CREAM)
		end
		box(m, "Tower", Vector3.new(12, 64, 12), CFrame.new(w / 2, 32, back + 8), look.wall)
		box(m, "TowerCap", Vector3.new(14, 3, 14), CFrame.new(w / 2, 65.5, back + 8), look.trim)
		box(m, "Spire", Vector3.new(4, 14, 4), CFrame.new(w / 2, 74, back + 8), look.roof)
		Parts.disc(m, "ClockFace", 8, 0.4, CFrame.new(w / 2, 56, back + 1.8) * CFrame.Angles(math.pi / 2, 0, 0), CREAM)
		box(m, "ClockHand", Vector3.new(0.5, 3.4, 0.2), CFrame.new(w / 2, 57.4, back + 1.5), NAVY)
		tree(m, Vector3.new(8, 0.6, 6), 1)
		tree(m, Vector3.new(w - 8, 0.6, 6), 1)
		signBoard(m, spec.label, Vector3.new(16, 2.4, 0.4), CFrame.new(w / 2, 27, back - 0.3), look.trim)
	elseif spec.id == "HarborBridge" then
		-- towers over the deck ends with a crossbeam well above the span clearance
		local half = geometry.halfRoad + 10
		anchor = box(m, "Anchor", Vector3.new(1, 1, 1), CFrame.new(0, -4, 0), STEEL, false)
		for _, u in { -w / 2 + 30, w / 2 - 30 } do
			for _, side in { -1, 1 } do
				box(m, "Tower", Vector3.new(5, 60, 5), CFrame.new(side * half, 30, -u), look.wall)
			end
			local beam = box(m, "Crossbeam", Vector3.new(half * 2 + 5, 5, 4), CFrame.new(0, 52, -u), look.wall)
			Proxies.text(beam, Enum.NormalId.Back, spec.label, CREAM)
			Proxies.text(beam, Enum.NormalId.Front, spec.label, CREAM)
		end
		for _, side in { -1, 1 } do
			box(m, "Cable", Vector3.new(0.6, 0.6, w - 60), CFrame.new(side * half, 58, 0), STEEL)
		end
	elseif spec.id == "Fountain" then
		anchor = box(m, "Plaza", Vector3.new(w, 0.5, d), CFrame.new(w / 2, 0.35, d / 2), STONE, false)
		Parts.disc(m, "Basin", 20, 2.4, CFrame.new(w / 2, 1.2, d / 2), look.trim).CastShadow = true
		Parts.disc(m, "Water", 18, 0.3, CFrame.new(w / 2, 2.3, d / 2), WATER)
		box(m, "Column", Vector3.new(2, 8, 2), CFrame.new(w / 2, 5, d / 2), look.trim)
		Parts.disc(m, "Bowl", 7, 1, CFrame.new(w / 2, 8.5, d / 2), look.trim)
		Parts.disc(m, "Spray", 2.6, 4, CFrame.new(w / 2, 10.5, d / 2) * CFrame.Angles(0, 0, 0), WATER)
		tree(m, Vector3.new(5, 0.6, d - 5), 1.1)
		tree(m, Vector3.new(w - 5, 0.6, d - 5), 1.2)
		signBoard(m, spec.label, Vector3.new(14, 2.4, 0.6), CFrame.new(w / 2, 1.6, 0.5), look.accent)
	elseif spec.id == "Stadium" then
		anchor = Parts.block(
			m,
			"Bowl",
			Vector3.new(h, w, d),
			CFrame.new(w / 2, h / 2, d / 2) * CFrame.Angles(0, 0, math.pi / 2),
			look.wall:Lerp(Color3.fromRGB(205, 224, 238), 0.35),
			Enum.PartType.Cylinder
		)
		Parts.block(
			m,
			"Rim",
			Vector3.new(4, w + 6, d + 6),
			CFrame.new(w / 2, h + 1, d / 2) * CFrame.Angles(0, 0, math.pi / 2),
			look.trim:Lerp(Color3.fromRGB(205, 224, 238), 0.35),
			Enum.PartType.Cylinder
		)
	elseif spec.id == "CarWash" or spec.id == "ServiceCanopy" then
		anchor = box(m, "Kiosk", Vector3.new(w * 0.3, 12, 8), CFrame.new(w * 0.8, 6, d - 4), look.wall)
		box(m, "Canopy", Vector3.new(w, 2, d - 2), CFrame.new(w / 2, h - 1, d / 2), look.trim)
		box(m, "Fascia", Vector3.new(w, 3, 0.6), CFrame.new(w / 2, h - 1.5, 0.7), look.accent)
		for _, x in { 2, w - 2 } do
			for _, z in { 3, d - 3 } do
				box(m, "Post", Vector3.new(1, h - 2, 1), CFrame.new(x, (h - 2) / 2, z), STEEL)
			end
		end
		if spec.id == "CarWash" then
			for _, x in { w * 0.3, w * 0.55 } do
				Parts.block(
					m,
					"Brush",
					Vector3.new(3, 10, 3),
					CFrame.new(x, 5.5, d * 0.55),
					Color3.fromRGB(70, 150, 220),
					Enum.PartType.Cylinder
				)
			end
		end
		signBoard(m, spec.label, Vector3.new(w - 6, 2.6, 0.4), CFrame.new(w / 2, h - 1.5, 0.3), look.accent)
	elseif spec.id == "DonutBakery" then
		anchor = box(m, "Body", Vector3.new(w, 22, d), CFrame.new(w / 2, 11, d / 2), look.wall)
		box(m, "Storefront", Vector3.new(w - 4, 9, 0.3), CFrame.new(w / 2, 5, -0.1), GLASS)
		-- a rooftop donut on two posts (structural sign)
		for _, x in { w / 2 - 4, w / 2 + 4 } do
			box(m, "Post", Vector3.new(0.8, 6, 0.8), CFrame.new(x, 25, d / 2), STEEL)
		end
		Parts.disc(
			m,
			"Donut",
			12,
			3,
			CFrame.new(w / 2, h - 6, d / 2) * CFrame.Angles(math.pi / 2, 0, 0),
			Color3.fromRGB(240, 150, 190)
		).CastShadow =
			true
		Parts.disc(
			m,
			"DonutHole",
			4,
			3.2,
			CFrame.new(w / 2, h - 6, d / 2) * CFrame.Angles(math.pi / 2, 0, 0),
			Color3.fromRGB(150, 98, 70)
		)
		signBoard(m, spec.label, Vector3.new(w - 4, 2.6, 0.4), CFrame.new(w / 2, 11.5, -0.3), look.trim)
	else -- DeliveryDepot and anything new from the kit
		anchor = box(m, "Body", Vector3.new(w, h, d), CFrame.new(w / 2, h / 2, d / 2), look.wall)
		for i = 0, 2 do
			box(m, "Door", Vector3.new(w / 4, 10, 0.3), CFrame.new(w * (0.2 + i * 0.3), 5, -0.1), STONE)
		end
		signBoard(m, spec.label, Vector3.new(w * 0.6, 3, 0.4), CFrame.new(w / 2, h - 4, -0.3), look.accent)
	end
	if label then
		Parts.label(anchor, "LANDMARK " .. spec.name, h / 2 + 6)
	end
	return finish(m)
end

-- Road pieces ---------------------------------------------------------------------------------

export type RoadSpec = {
	kind: string,
	length: number,
	bend: number,
	radius: number,
	crossAt: number?,
	waterStart: boolean?, -- BridgeDeck: quay edge at the start
	waterEnd: boolean?,
}

local CURVE_STEP = 10

-- A band between offsets dLo..dHi over u0..u1 with its top at yTop.
local function band(
	parent: Instance,
	name: string,
	spec: RoadSpec,
	dLo: number,
	dHi: number,
	u0: number,
	u1: number,
	yTop: number,
	thickness: number,
	colour: Color3
)
	if u1 - u0 < 0.05 then
		return
	end
	local dMid, width = (dLo + dHi) / 2, dHi - dLo
	if spec.bend == 0 then
		local p = box(
			parent,
			name,
			Vector3.new(width, thickness, u1 - u0),
			Route.localFrame(0, spec.radius, (u0 + u1) / 2, dMid, yTop - thickness / 2),
			colour,
			false
		)
		p.CastShadow = false
		return
	end
	local n = math.max(1, math.ceil((u1 - u0) / CURVE_STEP))
	local step = (u1 - u0) / n
	-- size the pieces for the band's outer edge, so they meet there and overlap inside
	local stretch =
		math.max(Route.sideFactor(spec.bend, spec.radius, dLo), Route.sideFactor(spec.bend, spec.radius, dHi))
	for k = 0, n - 1 do
		box(
			parent,
			name,
			Vector3.new(width, thickness, step * stretch + 0.02),
			Route.localFrame(spec.bend, spec.radius, u0 + (k + 0.5) * step, dMid, yTop - thickness / 2),
			colour,
			false
		)
	end
end

function Proxies.road(spec: RoadSpec, g: Geometry, label: boolean): Model
	local m = model("PROXY_Road_" .. spec.kind, "part-built road piece (B2 road mesh missing); preview widths")
	local L = spec.length
	local half = g.halfRoad
	local laneHalf = g.lanes * g.laneWidth / 2
	local walkOuter = half + g.sidewalk
	band(m, "Asphalt", spec, -half, half, 0, L, 0, 1, ASPHALT)
	-- the main road's kerbs and sidewalks stop for the cross street carriageway
	local pieces: { { number } } = { { 0, L } }
	local cross = spec.crossAt
	if spec.kind == "Intersection" and cross then
		pieces = { { 0, cross - 15 }, { cross + 15, L } }
	end
	for _, piece in pieces do
		for _, side in { -1, 1 } do
			local function sided(lo: number, hi: number): (number, number)
				if side > 0 then
					return lo, hi
				end
				return -hi, -lo
			end
			local eLo, eHi = sided(laneHalf - 0.3, laneHalf + 0.3)
			band(m, "EdgeLine", spec, eLo, eHi, piece[1], piece[2], 0.04, 0.1, PAINT)
			local kLo, kHi = sided(half, half + g.kerb)
			band(m, "Kerb", spec, kLo, kHi, piece[1], piece[2], KERB_HEIGHT, 1.4, KERB)
			local wLo, wHi = sided(half + g.kerb, walkOuter)
			band(m, "Sidewalk", spec, wLo, wHi, piece[1], piece[2], KERB_HEIGHT, 1.4, WALK)
			if spec.kind == "BridgeDeck" then
				local pLo, pHi = sided(walkOuter - 1, walkOuter)
				band(m, "Parapet", spec, pLo, pHi, piece[1], piece[2], 3.4, 2.8, STONE)
			end
		end
	end
	-- dashed lane lines (kept clear of the cross street and its zebra)
	for lane = 1, g.lanes - 1 do
		local d = -laneHalf + g.laneWidth * lane
		local u = 0
		while u + 10 <= L + 0.01 do
			local mid = u + 5
			local clear = true
			if cross and math.abs(mid - cross) < 28 then
				clear = false
			end
			if spec.kind == "Transition" and math.abs(mid - L / 2) < 10 then
				clear = false
			end
			if clear then
				box(
					m,
					"LaneDash",
					Vector3.new(0.5, 0.1, 10),
					Route.localFrame(spec.bend, spec.radius, mid, d, 0.03),
					PAINT,
					false
				)
			end
			u += 20
		end
	end
	-- zebra crossings (before the cross street; mid-block on a transition)
	local zebraAt: number? = if cross then cross - 15 - 6 elseif spec.kind == "Transition" then L / 2 else nil
	if zebraAt then
		local bars = math.floor(2 * half / 6)
		for i = 1, bars do
			local d = -half + (2 * half / bars) * (i - 0.5)
			box(m, "Zebra", Vector3.new(2.5, 0.1, 8), Route.localFrame(0, spec.radius, zebraAt, d, 0.03), PAINT, false)
		end
	end
	if spec.kind == "Intersection" and cross then
		local reach = 400
		local c = Route.localFrame(0, spec.radius, cross, 0, 0)
		box(m, "CrossAsphalt", Vector3.new(reach * 2, 1, 30), c * CFrame.new(0, -0.51, 0), ASPHALT, false)
		for _, sideF in { -1, 1 } do
			for _, sideR in { -1, 1 } do
				local length = reach - walkOuter
				local x = sideR * (walkOuter + length / 2)
				box(
					m,
					"CrossKerb",
					Vector3.new(length, 1.4, g.kerb),
					c * CFrame.new(x, KERB_HEIGHT - 0.7, -sideF * (15 + g.kerb / 2)),
					KERB,
					false
				)
				box(
					m,
					"CrossSidewalk",
					Vector3.new(length, 1.4, 12 - g.kerb),
					c * CFrame.new(x, KERB_HEIGHT - 0.7, -sideF * (15 + g.kerb + (12 - g.kerb) / 2)),
					WALK,
					false
				)
			end
		end
	end
	if spec.kind == "BridgeDeck" then
		-- girder under the deck and the river below, across the whole view
		box(
			m,
			"Girder",
			Vector3.new(2 * walkOuter, 5, L),
			Route.localFrame(0, spec.radius, L / 2, 0, -3.5),
			Color3.fromRGB(120, 128, 140),
			false
		)
		box(m, "River", Vector3.new(1990, 1, L + 0.2), Route.localFrame(0, spec.radius, L / 2, 0, -0.6), WATER, false)
		for _, edge in { { spec.waterStart, 0 }, { spec.waterEnd, L } } do
			if edge[1] then
				box(
					m,
					"Quay",
					Vector3.new(1990, 1.6, 3),
					Route.localFrame(0, spec.radius, edge[2] :: number, 0, 0.2),
					STONE,
					false
				)
			end
		end
	end
	if label then
		local marker = m:FindFirstChild("Asphalt")
		if marker and marker:IsA("BasePart") then
			Parts.label(marker, "PROXY ROAD " .. spec.kind, 6)
		end
	end
	return finish(m)
end

-- Props ---------------------------------------------------------------------------------------

function Proxies.prop(kind: string): Model
	local m = model("PROXY_" .. kind, "part-built street prop (B2 mesh missing)")
	if kind == "lamp" or kind == "bridgeLamp" then
		box(m, "Pole", Vector3.new(0.5, 16, 0.5), CFrame.new(0, 8, 0), STEEL)
		box(m, "Arm", Vector3.new(0.4, 0.4, 3), CFrame.new(0, 15.8, -1.5), STEEL)
		box(m, "Head", Vector3.new(1.4, 0.6, 2), CFrame.new(0, 15.5, -3), CREAM)
	elseif kind == "tree" then
		box(m, "Grate", Vector3.new(3, 0.2, 3), CFrame.new(0, 0.1, 0), STEEL, false)
		tree(m, Vector3.zero, 1.1)
	elseif kind == "bench" then
		box(m, "Seat", Vector3.new(5, 0.5, 1.6), CFrame.new(0, 1.6, 0), Color3.fromRGB(150, 104, 70))
		box(m, "Back", Vector3.new(5, 1.4, 0.3), CFrame.new(0, 2.6, 0.7), Color3.fromRGB(150, 104, 70))
		box(m, "Legs", Vector3.new(4.4, 1.4, 1.2), CFrame.new(0, 0.7, 0), STEEL)
	elseif kind == "bin" then
		Parts.block(
			m,
			"Bin",
			Vector3.new(3, 1.6, 1.6),
			CFrame.new(0, 1.5, 0) * CFrame.Angles(0, 0, math.pi / 2),
			Color3.fromRGB(46, 110, 92),
			Enum.PartType.Cylinder
		)
	elseif kind == "hydrant" then
		Parts.block(
			m,
			"Hydrant",
			Vector3.new(2.4, 1.1, 1.1),
			CFrame.new(0, 1.2, 0) * CFrame.Angles(0, 0, math.pi / 2),
			Color3.fromRGB(230, 186, 60),
			Enum.PartType.Cylinder
		)
	elseif kind == "bikeRack" then
		for i = -1, 1 do
			box(m, "Hoop", Vector3.new(0.2, 2.4, 2), CFrame.new(i * 1.2, 1.2, 0), STEEL)
		end
	elseif kind == "planter" then
		box(m, "Box", Vector3.new(4, 1.6, 2.4), CFrame.new(0, 0.8, 0), Color3.fromRGB(150, 140, 126))
		box(m, "Flowers", Vector3.new(3.6, 0.8, 2), CFrame.new(0, 2, 0), Color3.fromRGB(226, 120, 140))
	elseif kind == "busStop" then
		box(m, "Roof", Vector3.new(9, 0.4, 4), CFrame.new(0, 8.2, 0.4), Color3.fromRGB(46, 96, 140))
		box(m, "Back", Vector3.new(9, 7, 0.3), CFrame.new(0, 4.4, 2.2), GLASS)
		box(m, "Post", Vector3.new(0.4, 8, 0.4), CFrame.new(-4.3, 4, 2), STEEL)
		box(m, "Post", Vector3.new(0.4, 8, 0.4), CFrame.new(4.3, 4, 2), STEEL)
		box(m, "Bench", Vector3.new(6, 0.5, 1.4), CFrame.new(0, 1.6, 1.3), Color3.fromRGB(150, 104, 70))
	elseif kind == "cactus" then
		-- Dusty Highway / World 2: a saguaro with two arms (labelled proxy until DH_Prop_Cactus exists)
		local green = Color3.fromRGB(78, 148, 92)
		Parts.block(
			m,
			"Trunk",
			Vector3.new(11, 3, 3),
			CFrame.new(0, 5.5, 0) * CFrame.Angles(0, 0, math.pi / 2),
			green,
			Enum.PartType.Cylinder
		)
		for _, side in { -1, 1 } do
			box(m, "ArmOut", Vector3.new(2.6, 1.5, 1.5), CFrame.new(side * 2.2, 4.6 + (side + 1) * 0.5, 0), green)
			box(m, "ArmUp", Vector3.new(1.5, 4, 1.5), CFrame.new(side * 3.2, 6.4 + (side + 1) * 0.5, 0), green)
		end
	elseif kind == "rock" then
		local stone = Color3.fromRGB(158, 132, 112)
		box(m, "Boulder", Vector3.new(4.4, 2.8, 3.6), CFrame.new(0, 1.4, 0) * CFrame.Angles(0, 0.4, 0), stone)
		box(
			m,
			"Chip",
			Vector3.new(2.4, 1.8, 2.4),
			CFrame.new(1.8, 0.9, 1) * CFrame.Angles(0, -0.5, 0),
			stone:Lerp(Color3.new(1, 1, 1), 0.12)
		)
	elseif kind == "barrel" then
		Parts.block(
			m,
			"Barrel",
			Vector3.new(3.2, 2.4, 2.4),
			CFrame.new(0, 1.6, 0) * CFrame.Angles(0, 0, math.pi / 2),
			Color3.fromRGB(128, 92, 62),
			Enum.PartType.Cylinder
		)
		Parts.block(
			m,
			"Band",
			Vector3.new(0.4, 2.6, 2.6),
			CFrame.new(0, 1.6, 0) * CFrame.Angles(0, 0, math.pi / 2),
			STEEL,
			Enum.PartType.Cylinder
		)
	elseif kind == "fencePost" then
		local wood = Color3.fromRGB(140, 100, 70)
		box(m, "Post", Vector3.new(0.5, 3.2, 0.5), CFrame.new(0, 1.6, 0), wood)
		box(m, "Rail", Vector3.new(6, 0.3, 0.25), CFrame.new(3, 2.5, 0), wood)
		box(m, "Rail2", Vector3.new(6, 0.3, 0.25), CFrame.new(3, 1.5, 0), wood)
	elseif kind == "pine" then
		-- Summit Pass / World 3: a stacked pine with snow caps (labelled proxy until SP_Prop_Pine exists)
		local needles = Color3.fromRGB(46, 104, 78)
		box(m, "Trunk", Vector3.new(0.9, 3, 0.9), CFrame.new(0, 1.5, 0), Color3.fromRGB(104, 72, 52))
		for i, size in { 5.4, 4.2, 3 } do
			local y = 3.4 + (i - 1) * 2.1
			box(m, "Tier", Vector3.new(size, 2.2, size), CFrame.new(0, y, 0), needles)
			box(
				m,
				"Snow",
				Vector3.new(size + 0.2, 0.35, size + 0.2),
				CFrame.new(0, y + 1.1, 0),
				Color3.fromRGB(240, 246, 252)
			)
		end
	elseif kind == "snowman" then
		local snow = Color3.fromRGB(244, 248, 252)
		Parts.block(m, "Base", Vector3.new(3.6, 3.6, 3.6), CFrame.new(0, 1.8, 0), snow, Enum.PartType.Ball)
		Parts.block(m, "Middle", Vector3.new(2.7, 2.7, 2.7), CFrame.new(0, 4.5, 0), snow, Enum.PartType.Ball)
		Parts.block(m, "Head", Vector3.new(1.9, 1.9, 1.9), CFrame.new(0, 6.3, 0), snow, Enum.PartType.Ball)
		box(m, "Nose", Vector3.new(0.3, 0.3, 1), CFrame.new(0, 6.3, -1.1), Color3.fromRGB(232, 128, 40))
	else
		box(m, "Unknown", Vector3.new(2, 2, 2), CFrame.new(0, 1, 0), STEEL)
	end
	return finish(m)
end

-- Spans (WELCOME TO DOWNTOWN, bunting): poles on both sidewalks, the underside at clearance.
function Proxies.span(kind: string, text: string, width: number, clearance: number): Model
	local m = model("PROXY_Span_" .. kind, "part-built " .. kind .. " span (preview clearance)")
	local top = clearance + 7
	for _, side in { -1, 1 } do
		box(m, "Pole", Vector3.new(0.8, top, 0.8), CFrame.new(side * width / 2, top / 2, 0), STEEL)
	end
	if kind == "welcome" then
		local board = box(m, "Banner", Vector3.new(width - 4, 5, 0.4), CFrame.new(0, clearance + 2.5, 0), NAVY)
		Proxies.text(board, Enum.NormalId.Front, text, CREAM)
		Proxies.text(board, Enum.NormalId.Back, text, CREAM)
	else
		box(m, "Rope", Vector3.new(width, 0.2, 0.2), CFrame.new(0, clearance + 4, 0), STEEL, false)
		local colours = {
			Color3.fromRGB(40, 150, 150),
			Color3.fromRGB(250, 236, 200),
			Color3.fromRGB(200, 70, 80),
			Color3.fromRGB(240, 200, 70),
			Color3.fromRGB(70, 130, 200),
		}
		local count = math.floor(width / 4)
		for i = 1, count do
			local x = -width / 2 + (i - 0.5) * width / count
			local flag = Instance.new("WedgePart")
			flag.Name = "Pennant"
			flag.Anchored = true
			flag.CanCollide = false
			flag.CanQuery = false
			flag.CanTouch = false
			flag.CastShadow = false
			flag.Size = Vector3.new(0.1, 3, 2.4)
			flag.CFrame = CFrame.new(x, clearance + 2.4, 0)
				* CFrame.Angles(math.pi, 0, 0)
				* CFrame.Angles(0, math.pi / 2, 0)
			flag.Color = colours[(i - 1) % #colours + 1]
			flag.Material = Enum.Material.SmoothPlastic
			flag.Parent = m
		end
	end
	return finish(m)
end

-- Hazard previews: scenery only, labelled; gameplay hazards belong to Lane 1.
function Proxies.hazard(kind: string, length: number, laneWidth: number, label: boolean): Model
	local m = model("PROXY_Hazard_" .. kind, "hazard PREVIEW (scenery only, not gameplay)")
	m:SetAttribute("Hazard", kind)
	local anchor: BasePart
	if kind == "construction" then
		local orange = Color3.fromRGB(255, 122, 26)
		anchor = box(m, "Barrier", Vector3.new(laneWidth - 2, 2.4, 0.5), CFrame.new(0, 1.6, length / 2), orange)
		box(m, "BarrierStripe", Vector3.new(laneWidth - 1.8, 0.6, 0.7), CFrame.new(0, 1.8, length / 2), CREAM)
		for i = 0, 5 do
			local z = length / 2 - 3 - i * (length - 4) / 5
			for _, x in { -laneWidth / 2 + 1.5, laneWidth / 2 - 1.5 } do
				Parts.block(
					m,
					"Cone",
					Vector3.new(2.2, 1.2, 1.2),
					CFrame.new(x, 1.1, z) * CFrame.Angles(0, 0, math.pi / 2),
					orange,
					Enum.PartType.Cylinder
				)
				box(m, "ConeBand", Vector3.new(1.0, 0.4, 1.0), CFrame.new(x, 1.5, z), CREAM)
			end
		end
		local sign = box(m, "Sign", Vector3.new(5, 3.2, 0.3), CFrame.new(0, 4.6, length / 2 + 0.6), orange)
		Proxies.text(sign, Enum.NormalId.Back, "ROAD WORK")
	elseif kind == "oil" then
		Parts.disc(m, "OilRim", 6.6, 0.06, CFrame.new(0, 0.03, 0), Color3.fromRGB(70, 150, 160))
		anchor = Parts.disc(m, "Oil", 6, 0.08, CFrame.new(0, 0.05, 0), Color3.fromRGB(22, 24, 30))
		anchor.Reflectance = 0.15
	else
		Parts.disc(m, "Rim", 4.6, 0.36, CFrame.new(0, 0.18, 0), Color3.fromRGB(128, 130, 136))
		anchor = Parts.disc(m, "Hole", 3.4, 0.38, CFrame.new(0, 0.2, 0), Color3.fromRGB(34, 36, 42))
	end
	if label then
		Parts.label(anchor, "HAZARD PREVIEW " .. kind, 5)
	end
	return finish(m)
end

-- Street-life pieces ----------------------------------------------------------------------------

function Proxies.cart(): (Model, BasePart)
	local m = model("PROXY_FoodCart", "part-built food cart (street life)")
	local body = box(m, "CartBody", Vector3.new(4.2, 2.4, 2.4), CFrame.new(0, 1.9, 0), CREAM)
	box(m, "CartStripe", Vector3.new(4.25, 0.5, 2.45), CFrame.new(0, 2.4, 0), Color3.fromRGB(40, 150, 150))
	for _, x in { -1.4, 1.4 } do
		Parts.block(
			m,
			"CartWheel",
			Vector3.new(0.3, 1.2, 1.2),
			CFrame.new(x, 0.6, 1.25) * CFrame.Angles(0, math.pi / 2, 0),
			Color3.fromRGB(44, 48, 58),
			Enum.PartType.Cylinder
		)
	end
	box(m, "UmbrellaPole", Vector3.new(0.2, 4, 0.2), CFrame.new(1.6, 5, 0), STEEL)
	Parts.disc(m, "Umbrella", 5, 0.3, CFrame.new(1.6, 7, 0), Color3.fromRGB(63, 182, 216)).CastShadow = true
	return finish(m), body
end

function Proxies.flagpole(): (Model, BasePart)
	local m = model("PROXY_Flagpole", "part-built flagpole (street life)")
	local pole = box(m, "Pole", Vector3.new(0.35, 16, 0.35), CFrame.new(0, 8, 0), Color3.fromRGB(214, 222, 232))
	return finish(m), pole
end

-- A generic block (midground / skyline masses, ground tiles); resized on every reuse.
function Proxies.block(name: string): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	return p
end

-- A sign board (band on a facade, or a blade sticking out from it); text set on placement.
function Proxies.sign(style: string): Model
	local m = model("PROXY_Sign_" .. style, "fictional shop sign (no real logos)")
	if style == "blade" then
		local board = box(m, "Board", Vector3.new(0.4, 5, 9), CFrame.new(0, 0, 0), CREAM)
		Proxies.text(board, Enum.NormalId.Left, "")
		Proxies.text(board, Enum.NormalId.Right, "")
		box(m, "Bracket", Vector3.new(0.3, 0.3, 9.6), CFrame.new(0, 2.8, 0), STEEL)
	else
		local board = box(m, "Board", Vector3.new(16, 2.2, 0.3), CFrame.new(0, 0, 0), CREAM)
		Proxies.text(board, Enum.NormalId.Front, "")
	end
	return finish(m)
end

-- World build V2: a free-standing wayfinding board on two posts (a fictional district plaque, "LOOKOUT", "CANYON BRIDGE
-- AHEAD"); its front (local -Z) carries the text, set on placement; pivot at the foot of the board's centre.
function Proxies.board(width: number, height: number): Model
	local m = model("PROXY_Board", "fictional wayfinding board (no real logos or road shields)")
	local rise = 4
	local board = box(m, "Board", Vector3.new(width, height, 0.5), CFrame.new(0, rise + height / 2, 0), CREAM)
	Proxies.text(board, Enum.NormalId.Front, "", Color3.fromRGB(120, 60, 36))
	for _, x in { -width / 2 + 0.8, width / 2 - 0.8 } do
		box(m, "Post", Vector3.new(0.7, rise + height, 0.7), CFrame.new(x, (rise + height) / 2, 0.1), STEEL)
	end
	return finish(m)
end

return Proxies
