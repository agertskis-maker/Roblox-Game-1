--!strict
-- The park destinations (Lane 3, build-time, the same for every player): the Garage (brief
-- section 9), the Stunt Circuit entrance (section 10) and the two leaderboards (section 12), from
-- the Task 4 `garage` and `stunt` kit families (Car-Hop-Art/review/task4/concepts/{garage,stunt}/
-- README.md, "Production"). Every piece stands at its recorded placement in the kit meta, in the
-- frame of its HubData park.buildings / park.boards entry (origin on the ground at the entry's
-- centre, mesh front, local +Z, toward `facing`).
--
--   Destinations.build(parent)   -- (re)builds parent.Destinations; returns a small report
--
-- One Folder "Destinations" holds four Models (Garage, StuntGate, LeaderboardGarage,
-- LeaderboardStunt). Each Model carries Frame (its CFrame), EnvelopeMin / EnvelopeMax (frame-local
-- bounds) and Source ("preview" while any of its meshes is a session-only preview; such a mesh
-- does not reach a playtest, so the client then shows the colliders as simple stand-in blocks).
--
-- Text is live SurfaceGui text on thin transparent SignFace parts laid on the recorded mesh text
-- faces, per the pending sign spec (vault/design/ui/island-task4-signs.md sections 3, 5 and 6;
-- PENDING Adam's approval, nothing there is approved). Every made-up value carries a PREVIEW tag.
-- No texture from the spec is uploaded; each face has a one-line hook where its approved texture
-- id would go.
--
-- Presentation (turntable spin, the start-light preview countdown, the "Open Garage" reply) is on
-- each client: src/client/Home/Island/Destinations.client.luau. Nothing here sends, saves or
-- reads player data, and the prompt has no server handler.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AssetIds = require(script.Parent.AssetIds)
local KitAssets = require(script.Parent.KitAssets)
local Layout = require(script.Parent.Parent.Layout)

local Destinations = {}

Destinations.FolderName = "Destinations"
Destinations.Version = "task4-destinations-1"

local park = Layout.Data.park
local SURFACE = Layout.SurfaceY
local FONT = Font.fromName("FredokaOne")
local hex = Color3.fromHex

-- Colours: tokens from src/shared/UI/Tokens.luau, and the sign spec's proposals (not tokens yet).
local NAVY = hex("1E2A4A") -- Color.Text
local INK = hex("141B33") -- Color.CashOutline
local GOLD = hex("FFC83D") -- Color.Coin
local CHROME = hex("D6DEE8") -- Color.Chrome
local CALM = hex("3FB6D8") -- Color.Calm
local BAND_SHADE = hex("E07B12") -- Color.BillBandShade
local YELLOW = hex("F7CE58") -- WorldPalette.Yellow
local CREAM = hex("FFF6E0") -- proposal
local PREVIEW_MAGENTA = hex("C2187A") -- proposal
local ROW_STRIPE = hex("24335A") -- proposal
local BRONZE = hex("D98A4A") -- proposal
local GARAGE_RED_ORANGE = hex("E8562A") -- proposal
local GARAGE_SIDE = hex("8C2A14") -- proposal
local GARAGE_BADGE_RED = hex("D9503F")
local BULB_WARM = hex("FFE9A8")
local LIGHT_PANEL = hex("FFF1D6")
local GLASS = Color3.fromRGB(196, 222, 232)
local WARM_LIGHT = Color3.fromRGB(255, 224, 182)
local SHOWROOM_LIGHT = Color3.fromRGB(255, 240, 222)
local PAVING = Color3.fromRGB(206, 202, 194)
local BAY_LINE = Color3.fromRGB(246, 244, 238)
local PROXY_GREY = Color3.fromRGB(170, 178, 190)

-- Stand-in colours (Play fallback only, while the meshes are previews)
local STAND_CREAM = Color3.fromRGB(240, 232, 212)
local STAND_STONE = Color3.fromRGB(222, 214, 196)
local STAND_TYRE = Color3.fromRGB(44, 44, 50)

local THICK = 0.04 -- SignFace part thickness
local PROUD = 0.02 -- its Front face sits this far in front of the recorded face

-- Rarity rings (PREVIEW; tiers are undecided Lane 2 data). The owner brief asks for gold, purple
-- and blue rings; the team's proposed rarity guide (vault/design/cars/rarity-style.md) and the
-- RarityRing meta proposal give gold to legendary, purple to epic and blue to rare, so the three
-- turntables preview those three tiers with the meta's proposal colours. Reversible.
-- Rest yaw: the car's yaw (car rig convention: -Z forward) at the reduced-motion three-quarter
-- pose, chosen so every nose points out toward the front approach. Reversible.
type SlotStyle = { rarity: string, ring: Color3, restYaw: number, plaque: "floor" | "riser" }
local SLOTS: { SlotStyle } = {
	{ rarity = "legendary", ring = Color3.fromRGB(246, 196, 60), restYaw = 135, plaque = "floor" }, -- front
	{ rarity = "epic", ring = Color3.fromRGB(160, 110, 220), restYaw = 225, plaque = "riser" }, -- back left
	{ rarity = "rare", ring = Color3.fromRGB(80, 140, 230), restYaw = 135, plaque = "riser" }, -- back right
}
local DEG_PER_S_DEFAULT = 6

-- PREVIEW sample rows (sign spec section 3): invented names with spaces, which Roblox usernames
-- cannot have. Not real data, not connected to anything.
local CARS_ROWS = {
	{ "Zippy Zebra", "42" },
	{ "Captain Vroom", "37" },
	{ "Pickle Pop", "33" },
	{ "Sunny Sprocket", "29" },
	{ "Maple Muffin", "26" },
	{ "Professor Beep", "22" },
	{ "Wobbly Wheels", "19" },
	{ "Lemon Drop", "15" },
	{ "Pixel Pup", "12" },
	{ "Biscuit Boost", "9" },
}
local STUNT_ROWS = {
	{ "Pickle Pop", "0:38.4" },
	{ "Biscuit Boost", "0:39.9" },
	{ "Zippy Zebra", "0:41.2" },
	{ "Sunny Sprocket", "0:43.6" },
	{ "Lemon Drop", "0:45.0" },
	{ "Captain Vroom", "0:46.8" },
	{ "Pixel Pup", "0:48.5" },
	{ "Maple Muffin", "0:50.1" },
	{ "Wobbly Wheels", "0:51.9" },
	{ "Professor Beep", "0:53.5" },
}

-- The stunt placements in StuntGantry meta `layout.placements` (positions and turns are read
-- from the manifest; the generated manifest drops the string `mesh` field, so the mesh of each
-- recorded index is listed here, in the recorded order, and checked against the count).
local STUNT_MESHES = {
	"StuntGantry",
	"StuntApron",
	"StuntGridMarkings",
	"StuntEndBarrier",
	"StuntStartLightHousing",
	"StuntStartLightLens",
	"StuntStartLightHousing",
	"StuntStartLightLens",
	"StuntStartLightHousing",
	"StuntStartLightLens",
	"StuntStartLightHousing",
	"StuntStartLightLens",
	"StuntStartLightHousing",
	"StuntStartLightLens",
	"StuntTireRow",
	"StuntTireRow",
	"StuntTireRow",
	"StuntTireRow",
	"StuntTireRow",
	"StuntLoop",
	"StuntPodium",
	"StuntCone",
	"StuntCone",
	"StuntCone",
	"StuntCone",
	"StuntFlag",
	"StuntFlag",
	"StuntSignFaceLettering",
	"StuntSignFaceLettering",
	"StuntSignFaceBoard",
	"StuntSignFaceBoard",
	"StuntSignFaceComingSoon",
}

-- Garage pieces sharing the garage origin, and the placed pieces that stand on the forecourt.
local GARAGE_AT_ORIGIN = {
	"GarageShell",
	"GarageStructure",
	"GarageGlazing",
	"GarageInterior",
	"GarageLights",
	"GarageSign",
	"CheckeredBand",
	"ForecourtCurb",
}
local FORECOURT_PIECES: { [string]: boolean } = {
	ForecourtCurb = true,
	TireStack = true,
	OilCanDisplay = true,
	DrumRed = true,
	DrumTeal = true,
	AirPump = true,
	GarageBench = true,
	Planter = true,
	ParkingArrow = true,
}
local GARAGE_GROUP: { [string]: string } = {
	CarLift = "Workshop",
	ToolWall = "Workshop",
	TireRack = "Workshop",
	ToolCart = "Workshop",
	HazardStrip = "Workshop",
	MarqueeBulb = "Sign",
	RoofVent = "Roof",
	GarageFlagpole = "Roof",
	WrenchTireSculpture = "Roof",
	WallLight = "Building",
	Bollard = "Building",
}

-- Light points (GarageShell meta light_points): brightness, range, colour. Warm and modest.
type LightSpec = { brightness: number, range: number, colour: Color3 }
local GARAGE_LIGHTS: { [string]: LightSpec } = {
	workshop_front = { brightness = 1.1, range = 16, colour = WARM_LIGHT },
	workshop_lift = { brightness = 1.3, range = 16, colour = WARM_LIGHT },
	workshop_back = { brightness = 1.0, range = 16, colour = WARM_LIGHT },
	showroom_entrance = { brightness = 0.9, range = 14, colour = SHOWROOM_LIGHT },
	canopy_workshop = { brightness = 0.7, range = 12, colour = WARM_LIGHT },
	canopy_showroom = { brightness = 0.7, range = 12, colour = WARM_LIGHT },
	entrance_hood = { brightness = 0.7, range = 10, colour = WARM_LIGHT },
	pylon_slot = { brightness = 0.5, range = 10, colour = WARM_LIGHT },
	showroom_Front = { brightness = 1.1, range = 16, colour = SHOWROOM_LIGHT },
	showroom_BackLeft = { brightness = 1.1, range = 16, colour = SHOWROOM_LIGHT },
	showroom_BackRight = { brightness = 1.1, range = 16, colour = SHOWROOM_LIGHT },
	wall_light_1 = { brightness = 0.6, range = 9, colour = WARM_LIGHT },
	wall_light_2 = { brightness = 0.6, range = 9, colour = WARM_LIGHT },
	wall_light_3 = { brightness = 0.6, range = 9, colour = WARM_LIGHT },
	wall_light_4 = { brightness = 0.6, range = 9, colour = WARM_LIGHT },
	wall_light_5 = { brightness = 0.6, range = 9, colour = WARM_LIGHT },
}

-- Proposed data hook for Brian L (not a shared ownership contract): what one showroom slot
-- offers a car model. Read it with Destinations.slots(); the Attachments carry the same values.
export type ShowroomSlot = {
	id: string, -- "Slot1".."Slot3", "LiftSlot"
	kind: string, -- "Turntable" or "Lift"
	seat: CFrame, -- the car model's pivot (bottom centre, -Z forward) goes here
	labelPoint: Vector3?, -- a point 6.2 above the seat for a name label (turntables only)
	rarity: string?, -- PREVIEW tier name for the ring colour (turntables only)
	centre: Vector3?, -- the turntable's spin centre on its top (turntables only)
}

type Report = { [string]: any }

-- ---------------------------------------------------------------- helpers

local function entryOf(list: { any }, id: string): any
	for _, e in list do
		if e.id == id then
			return e
		end
	end
	error("HubData has no park entry " .. id)
end

-- The frame of a HubData entry: on the ground at its centre, mesh front (+Z) toward `facing`.
local function frameOf(centre: Vector2, facing: Vector2): CFrame
	local yaw = math.atan2(facing.X, -facing.Y)
	return CFrame.new(Layout.planToWorld(centre, SURFACE)) * CFrame.Angles(0, yaw, 0)
end

local function plain(name: string, size: Vector3, cf: CFrame, parent: Instance): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Transparency = 1
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Size = size
	p.CFrame = cf
	p.Parent = parent
	return p
end

local function folder(name: string, parent: Instance): Folder
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end

-- A box from frame-local min / max corners (Roblox mesh-local axes).
local function box(name: string, frame: CFrame, lo: Vector3, hi: Vector3, parent: Instance): Part
	return plain(name, hi - lo, frame * CFrame.new((lo + hi) / 2), parent)
end

-- Kit meta and README ranges are in Blender axes (x right, y back, z up); Roblox mesh-local is
-- (x, z, -y). A box from Blender ranges, as frame-local min / max.
local function blenderBox(x1: number, x2: number, y1: number, y2: number, z1: number, z2: number): (Vector3, Vector3)
	return Vector3.new(x1, z1, -y2), Vector3.new(x2, z2, -y1)
end

-- An invisible collider that a client shows as a stand-in block in Play while the meshes are
-- previews (they do not reach a playtest).
local function collider(name: string, frame: CFrame, lo: Vector3, hi: Vector3, colour: Color3, parent: Instance): Part
	local p = box(name, frame, lo, hi, parent)
	p.CanCollide = true
	p.CanQuery = true
	p.Color = colour
	p:SetAttribute("Collider", true)
	p:SetAttribute("StandInColour", colour)
	return p
end

-- Places one kit mesh with its origin at `cf`; counts triangles and preview sources.
type Tally = { triangles: number, parts: number, preview: boolean }
local function kit(name: string, cf: CFrame, parent: Instance, tally: Tally, label: string?): MeshPart
	local part = KitAssets.place(name, cf, 1)
	part.Name = label or name
	part:SetAttribute("Piece", name)
	part.Parent = parent
	tally.triangles += KitAssets.info(name).triangles
	tally.parts += 1
	if KitAssets.sources()[name] == "preview" then
		tally.preview = true
	end
	return part
end

local function recolour(part: MeshPart, colour: Color3, material: Enum.Material?)
	part.TextureID = "" -- the swatch would tint the colour; the meta says clear it, then colour
	part.Color = colour
	if material then
		part.Material = material
	end
end

local function needPoint(name: string, key: string): Vector3
	local p = KitAssets.info(name).points[key]
	assert(p, name .. " has no recorded point " .. key)
	return p
end

local function needMeta(name: string, key: string): number
	local v = KitAssets.info(name).meta[key]
	assert(v, name .. " has no recorded meta " .. key)
	return v
end

-- A thin transparent part whose Front face lies on a recorded text face (centre and outward
-- normal in the mesh frame `frame`), PROUD in front of it. Its SurfaceGui goes on Face = Front.
-- FaceMesh / FaceKey name the recorded face so DestinationChecks can recompute it.
local function signFace(
	name: string,
	frame: CFrame,
	centre: Vector3,
	normal: Vector3,
	size: Vector2,
	parent: Instance,
	mesh: string?,
	key: string?
): Part
	local c = frame:PointToWorldSpace(centre)
	local n = frame:VectorToWorldSpace(normal).Unit
	local up = frame.UpVector
	if math.abs(n:Dot(up)) > 0.98 then
		up = frame.LookVector -- a flat face: text top toward the back, read from the front
	end
	local at = c + n * (PROUD - THICK / 2)
	local p = plain("SignFace_" .. name, Vector3.new(size.X, size.Y, THICK), CFrame.lookAt(at, at + n, up), parent)
	p:SetAttribute("SignFace", name)
	if mesh and key then
		p:SetAttribute("FaceMesh", mesh)
		p:SetAttribute("FaceKey", key)
	end
	return p
end

local function surfaceGui(face: BasePart, pps: number, lightInfluence: number, spec: string): SurfaceGui
	local g = Instance.new("SurfaceGui")
	g.Name = "Face"
	g.Face = Enum.NormalId.Front
	g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	g.PixelsPerStud = pps
	g.LightInfluence = lightInfluence
	g.MaxDistance = 0
	g.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	g:SetAttribute("Spec", spec .. " (pending Adam's approval)")
	g.Parent = face
	return g
end

local function frame(
	parent: Instance,
	name: string,
	pos: UDim2,
	size: UDim2,
	colour: Color3,
	anchor: Vector2?,
	corner: number?
): Frame
	local f = Instance.new("Frame")
	f.Name = name
	f.AnchorPoint = anchor or Vector2.zero
	f.Position = pos
	f.Size = size
	f.BackgroundColor3 = colour
	f.BorderSizePixel = 0
	if corner then
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0, corner)
		c.Parent = f
	end
	f.Parent = parent
	return f
end

type TextOptions = {
	size: number,
	colour: Color3,
	align: Enum.TextXAlignment?,
	stroke: Color3?,
	strokeThickness: number?,
	scaledMin: number?, -- TextScaled down to this size if the line does not fit
	anchor: Vector2?,
	z: number?,
}
local function label(parent: Instance, name: string, text: string, pos: UDim2, size: UDim2, o: TextOptions): TextLabel
	local t = Instance.new("TextLabel")
	t.Name = name
	t.BackgroundTransparency = 1
	t.FontFace = FONT
	t.Text = text
	t.TextColor3 = o.colour
	t.TextSize = math.min(100, o.size) -- TextSize stops at 100 px
	t.TextXAlignment = o.align or Enum.TextXAlignment.Center
	t.TextYAlignment = Enum.TextYAlignment.Center
	t.AnchorPoint = o.anchor or Vector2.zero
	t.Position = pos
	t.Size = size
	t.ZIndex = o.z or 2
	if o.scaledMin then
		t.TextScaled = true
		local c = Instance.new("UITextSizeConstraint")
		c.MaxTextSize = math.min(100, o.size)
		c.MinTextSize = o.scaledMin
		c.Parent = t
	end
	t.TextTruncate = Enum.TextTruncate.AtEnd
	if o.stroke then
		local s = Instance.new("UIStroke")
		s.Color = o.stroke
		s.Thickness = o.strokeThickness or 2
		s.Parent = t
	end
	t.Parent = parent
	return t
end

-- The PREVIEW tag (sign spec rules): white, a 2 px magenta stroke (UIStroke has no dashes),
-- magenta Fredoka One text.
local function previewTag(parent: Instance, textSize: number, pos: UDim2, anchor: Vector2): Frame
	local w, h = math.floor(textSize * 5.0), math.floor(textSize * 1.45)
	local f = frame(parent, "PreviewTag", pos, UDim2.fromOffset(w, h), Color3.new(1, 1, 1), anchor, math.floor(h / 3))
	f.ZIndex = 4
	local s = Instance.new("UIStroke")
	s.Color = PREVIEW_MAGENTA
	s.Thickness = 2
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = f
	label(f, "Text", "PREVIEW", UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), {
		size = textSize,
		colour = PREVIEW_MAGENTA,
		z = 5,
	})
	return f
end

-- Big lettering with a drop "side face" and an ink outline, fitted to its box (two layers).
local function lettering(
	parent: Instance,
	text: string,
	centre: Vector2,
	width: number,
	textSize: number,
	letter: Color3,
	side: Color3,
	drop: number,
	outline: number
)
	for _, layer in { "Side", "Letters" } do
		local isSide = layer == "Side"
		label(
			parent,
			layer,
			text,
			UDim2.fromOffset(centre.X, centre.Y + (if isSide then drop else 0)),
			-- taller than the line so only the width limits TextScaled
			UDim2.fromOffset(width, textSize * 1.5),
			{
				size = textSize,
				scaledMin = math.floor(textSize * 0.6),
				colour = if isSide then side else letter,
				stroke = INK,
				strokeThickness = outline,
				anchor = Vector2.new(0.5, 0.5),
				z = if isSide then 2 else 3,
			}
		)
	end
end

-- ---------------------------------------------------------------- Garage

type Placement = { mesh: string, index: number, at: Vector3, yaw: number }

-- Every GarageShell `placements` entry, in a stable order.
local function garagePlacements(): { Placement }
	local shell = KitAssets.info("GarageShell")
	local out: { Placement } = {}
	for key, at in shell.points do
		local mesh: string?, index: number?, yawKey: string?
		local m, i = string.match(key, "^placements%.(%w+)%.(%d+)%.position$")
		if m and i then
			mesh, index, yawKey = m, tonumber(i), "placements." .. m .. "." .. i .. ".yaw"
		else
			m, i = string.match(key, "^placements%.(%w+)%.(%d+)$")
			if m and i then
				mesh, index, yawKey = m, tonumber(i), "placements." .. m .. "." .. i .. ".yaw"
			else
				m = string.match(key, "^placements%.(%w+)%.position$")
				if m then
					mesh, index, yawKey = m, 1, "placements." .. m .. ".yaw"
				end
			end
		end
		if mesh and index and yawKey then
			table.insert(out, { mesh = mesh, index = index, at = at, yaw = shell.meta[yawKey] or 0 })
		end
	end
	table.sort(out, function(a, b)
		if a.mesh ~= b.mesh then
			return a.mesh < b.mesh
		end
		return a.index < b.index
	end)
	return out
end

local function placed(base: CFrame, at: Vector3, yawDeg: number): CFrame
	return base * CFrame.new(at) * CFrame.Angles(0, math.rad(yawDeg), 0)
end

-- A checkered flag cloth on a GarageFlagpole (the cloth is render-only in the kit): 3 x 2,
-- 0.5 squares, flying along the pole's local +x.
local function flagCloth(pole: CFrame, parent: Instance)
	local info = KitAssets.info("GarageFlagpole")
	local bottom, top = info.meta.flag_bottom or 3.95, info.meta.flag_top or 5.95
	local length = 3
	local cloth = plain(
		"FlagCloth",
		Vector3.new(length, top - bottom, 0.05),
		pole * CFrame.new(0.3 + length / 2, (bottom + top) / 2, 0),
		parent
	)
	cloth.Transparency = 0
	cloth.Color = CREAM
	local pps = 20
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		local g = surfaceGui(cloth, pps, 1, "checkered flag cloth")
		g.Face = face
		local cols, rows = math.floor(length / 0.5), math.floor((top - bottom) / 0.5)
		for cx = 0, cols - 1 do
			for cy = 0, rows - 1 do
				if (cx + cy) % 2 == 0 then
					frame(g, "Square", UDim2.fromOffset(cx * 10, cy * 10), UDim2.fromOffset(10, 10), INK)
				end
			end
		end
	end
end

-- A preview car on a seat: a clone of a Brian L car model (never edited) when ReplicatedStorage.
-- Cars has one, else a neutral proxy box. Pivot at the bottom centre on the seat, -Z forward.
local function previewCar(seat: CFrame, index: number, parent: Instance): Model
	local cars: { Model } = {}
	local source = ReplicatedStorage:FindFirstChild("Cars")
	if source then
		for _, c in source:GetChildren() do
			if c:IsA("Model") then
				table.insert(cars, c)
			end
		end
		table.sort(cars, function(a, b)
			return a.Name < b.Name
		end)
	end
	local model: Model
	if #cars > 0 then
		model = cars[(index - 1) % #cars + 1]:Clone()
		for _, d in model:GetDescendants() do
			if d:IsA("BaseScript") or d:IsA("ModuleScript") then
				d:Destroy() -- a display copy: nothing runs
			elseif d:IsA("BasePart") then
				d.Anchored = true
				d.CanCollide = false
				d.CanTouch = false
				d.CanQuery = false
			end
		end
		model:SetAttribute("PreviewCarOf", model.Name)
		model.Name = "PreviewCar"
		model:PivotTo(seat)
		-- settle the lowest point on the seat, centred over it
		local lowest = math.huge
		for _, d in model:GetDescendants() do
			if d:IsA("BasePart") then
				local r = d.CFrame
				local half = 0.5
					* (
						math.abs(r.RightVector.Y) * d.Size.X
						+ math.abs(r.UpVector.Y) * d.Size.Y
						+ math.abs(r.LookVector.Y) * d.Size.Z
					)
				lowest = math.min(lowest, d.Position.Y - half)
			end
		end
		local bbox = model:GetBoundingBox()
		local shift = Vector3.new(seat.X - bbox.X, seat.Y - lowest, seat.Z - bbox.Z)
		model:PivotTo(model:GetPivot() + shift)
	else
		model = Instance.new("Model")
		model.Name = "PreviewCarProxy"
		-- 13 long x 6 wide x 4.5 tall, the approved car scale; a body and a cabin
		local body = plain("Body", Vector3.new(6, 2.6, 13), seat * CFrame.new(0, 1.3, 0), model)
		local cabin = plain("Cabin", Vector3.new(5.2, 1.9, 6.4), seat * CFrame.new(0, 2.6 + 0.95, 0.6), model)
		for _, p in { body, cabin } do
			p.Transparency = 0
			p.Color = PROXY_GREY
			p.CastShadow = true
		end
		model.WorldPivot = seat -- no PrimaryPart, so the pivot stays at the bottom centre
	end
	model:SetAttribute("Preview", true)
	model.Parent = parent
	return model
end

-- A small navy plaque with a PREVIEW tag (sign spec section 6: 3 x 0.8, live text).
local function previewPlaque(name: string, cf: CFrame, parent: Instance): Part
	local p = plain(name, Vector3.new(3, 0.8, 0.08), cf, parent)
	p.Transparency = 0
	p.Color = NAVY
	p:SetAttribute("SignFace", name)
	p:SetAttribute("OwnFace", true)
	local g = surfaceGui(p, 100, 0.6, "sign spec section 6, turntable plaque")
	previewTag(g, 40, UDim2.fromScale(0.5, 0.5), Vector2.new(0.5, 0.5))
	return p
end

local function garageSign(face: Part, size: Vector2, capitals: number)
	local pps = 10 -- 6.5-stud capitals need about 87 px; TextSize stops at 100
	local g = surfaceGui(face, pps, 0.6, "vault/design/ui/island-task4-signs.md section 6, GARAGE sign")
	local w, h = size.X * pps, size.Y * pps
	-- Texture hook: garage-sign.png (spec section 6), once approved and uploaded, goes here as an
	-- ImageLabel under the live letters.
	local panel = frame(g, "Panel", UDim2.fromScale(0, 0), UDim2.fromOffset(w, h), GARAGE_RED_ORANGE)
	lettering(
		panel,
		"GARAGE",
		Vector2.new(w / 2, h / 2),
		w - 8,
		math.floor(capitals / 0.75 * pps),
		CREAM,
		GARAGE_SIDE,
		4,
		2
	)
end

local function buildGarage(root: Instance, report: Report): Model
	local entry = entryOf(park.buildings, "Garage")
	local base = frameOf(entry.centre, entry.facing)
	local model = Instance.new("Model")
	model.Name = "Garage"
	model:SetAttribute("Frame", base)
	model:SetAttribute("EnvelopeMin", Vector3.new(-31, -0.5, -20))
	model:SetAttribute("EnvelopeMax", Vector3.new(31, 34, 20))
	-- forecourt pieces may stand in front of the envelope (garage README: y -28 to -20)
	model:SetAttribute("ForecourtMin", Vector3.new(-31, -0.5, -20))
	model:SetAttribute("ForecourtMax", Vector3.new(31, 4.6, 28))
	model:SetAttribute("Spec", "brief section 9; concepts/garage/README.md Production")
	local tally: Tally = { triangles = 0, parts = 0, preview = false }
	local groups: { [string]: Folder } = {}
	local function group(name: string): Folder
		local f = groups[name]
		if not f then
			f = folder(name, model)
			groups[name] = f
		end
		return f
	end

	-- the building meshes, all on the garage origin
	for _, name in GARAGE_AT_ORIGIN do
		local part = kit(name, base, group(if name == "ForecourtCurb" then "Forecourt" else "Building"), tally)
		if FORECOURT_PIECES[name] then
			part:SetAttribute("Zone", "Forecourt")
		end
		if name == "GarageGlazing" then
			recolour(part, GLASS, Enum.Material.Glass)
			part.Transparency = 0.55 -- the meta's value; verify in Play at graphics levels 1 and 10
			part.CastShadow = false
		elseif name == "GarageLights" then
			recolour(part, LIGHT_PANEL, Enum.Material.Neon)
			part.CastShadow = false
		end
	end

	-- the doors: A closed, B half open (recorded travel), the loading door closed
	local shell = KitAssets.info("GarageShell")
	for _, id in { "A", "B", "Loading" } do
		local at = needPoint("GarageShell", "doors." .. id .. ".position")
		local door =
			kit("RollUpDoor", placed(base, at, shell.meta["doors." .. id .. ".yaw"] or 0), group("Workshop"), tally)
		door.Name = "Door" .. id
		door:SetAttribute("Door", id)
		door:SetAttribute("State", if id == "B" then "HalfOpen" else "Closed")
		if id == "B" then
			door:SetAttribute("Travel", shell.meta["doors.travel.half_open"] or 5)
			door:SetAttribute(
				"ClosedPosition",
				base:PointToWorldSpace(needPoint("GarageShell", "doors.B.closed_position"))
			)
		end
	end

	-- every other recorded placement
	local flagFolder = group("Roof")
	for _, p in garagePlacements() do
		if p.mesh == "TurntableDisc" or p.mesh == "RarityRing" then
			continue -- built per slot below
		end
		local where = if FORECOURT_PIECES[p.mesh] then "Forecourt" else (GARAGE_GROUP[p.mesh] or "Building")
		local cf = placed(base, p.at, p.yaw)
		local part = kit(p.mesh, cf, group(where), tally, p.mesh .. (if p.index > 1 then tostring(p.index) else ""))
		if FORECOURT_PIECES[p.mesh] then
			part:SetAttribute("Zone", "Forecourt")
		end
		if p.mesh == "MarqueeBulb" then
			recolour(part, BULB_WARM, Enum.Material.Neon) -- steady: the spec has no chase
			part.CastShadow = false
		elseif p.mesh == "GarageFlagpole" then
			flagCloth(cf, flagFolder)
		end
	end

	-- the forecourt: smooth walkable paving (to the wall line) and the bay B lines
	local forecourt = group("Forecourt")
	-- top 0.01: the painted ParkingArrow meshes (0 to 0.03) and the bay lines stay above it
	local lo, hi = blenderBox(-31, 31, -28, -17, -0.2, 0.01)
	local paving = collider("Paving", base, lo, hi, PAVING, forecourt)
	paving.Transparency = 0
	paving:SetAttribute("Zone", "Forecourt")
	paving:SetAttribute("Walkable", true)
	local bx1 = shell.meta["forecourt.bays.1.x.1"] or -16.9
	local bx2 = shell.meta["forecourt.bays.1.x.2"] or -7.9
	local by1 = shell.meta["forecourt.bays.1.y.1"] or -28
	local by2 = shell.meta["forecourt.bays.1.y.2"] or -20
	for i, x in { bx1, bx2 } do
		local l1, h1 = blenderBox(x - 0.15, x + 0.15, by1, by2, 0.01, 0.04)
		local line = box("BayLine" .. i, base, l1, h1, forecourt)
		line.Transparency = 0
		line.Color = BAY_LINE
		line:SetAttribute("Zone", "Forecourt")
	end

	-- the showroom turntables, rings and preview cars, and the data hook for Brian L
	local showroom = group("Showroom")
	local slots = folder("ShowroomSlots", model)
	slots:SetAttribute("Proposal", "data hook for Brian L, not a shared contract; see Destinations.ShowroomSlot")
	local anchor = plain("SlotAnchor", Vector3.one, base, slots)
	local degPerS = shell.meta["turntable_motion.deg_per_s"] or DEG_PER_S_DEFAULT
	for i, style in SLOTS do
		local centre = needPoint("GarageShell", "turntables." .. i .. ".centre")
		local seat = needPoint("GarageShell", "turntables." .. i .. ".car_seat")
		local labelPoint = needPoint("GarageShell", "turntables." .. i .. ".label_point")
		local turntable = Instance.new("Model")
		turntable.Name = "Turntable" .. i
		local rest = base * CFrame.new(centre) * CFrame.Angles(0, math.rad(style.restYaw), 0)
		local seatCf = base * CFrame.new(seat) * CFrame.Angles(0, math.rad(style.restYaw), 0)
		local disc = kit("TurntableDisc", rest, turntable, tally, "Disc")
		disc:SetAttribute("Spin", true)
		local ring = kit("RarityRing", base * CFrame.new(centre), turntable, tally, "Ring")
		recolour(ring, style.ring, Enum.Material.SmoothPlastic)
		local car = previewCar(seatCf, i, turntable)
		car:SetAttribute("Spin", true)
		local spinTop = base:PointToWorldSpace(seat)
		turntable:SetAttribute("Turntable", i)
		turntable:SetAttribute("Centre", spinTop)
		turntable:SetAttribute("RestYawDeg", style.restYaw)
		turntable:SetAttribute("DegPerSec", degPerS)
		turntable:SetAttribute("Rarity", style.rarity)
		turntable:SetAttribute("RarityPreview", true)
		turntable.Parent = showroom

		local a = Instance.new("Attachment")
		a.Name = "Slot" .. i
		a.CFrame = base:ToObjectSpace(seatCf)
		a:SetAttribute("Kind", "Turntable")
		a:SetAttribute("Seat", seatCf)
		a:SetAttribute("LabelPoint", base:PointToWorldSpace(labelPoint))
		a:SetAttribute("Centre", spinTop)
		a:SetAttribute("Rarity", style.rarity)
		a:SetAttribute("RarityPreview", true)
		a:SetAttribute("RingColour", style.ring)
		a:SetAttribute("CarConvention", "pivot at the bottom centre, -Z forward, +Y up")
		a.Parent = anchor

		-- the PREVIEW plaque: on the floor in front of the front disc, on the stage riser for the
		-- back two (the riser face is at Blender y 1.6, z 0.6 to 2.6)
		if style.plaque == "floor" then
			local at = base:PointToWorldSpace(Vector3.new(centre.X, centre.Y + 0.04, 15.5))
			previewPlaque("PreviewPlaque" .. i, CFrame.lookAt(at, at + base.UpVector, base.LookVector), turntable)
		else
			local at = base:PointToWorldSpace(Vector3.new(centre.X, 1.6, -1.6 + 0.04))
			local n = base:VectorToWorldSpace(Vector3.new(0, 0, 1))
			previewPlaque("PreviewPlaque" .. i, CFrame.lookAt(at, at + n, base.UpVector), turntable)
		end
	end
	do
		local liftAt = needPoint("GarageShell", "lift_car_point")
		-- nose toward the door (+Z, the front): the -Z-forward car turned half round
		local liftSeat = base * CFrame.new(liftAt) * CFrame.Angles(0, math.pi, 0)
		local a = Instance.new("Attachment")
		a.Name = "LiftSlot"
		a.CFrame = base:ToObjectSpace(liftSeat)
		a:SetAttribute("Kind", "Lift")
		a:SetAttribute("Seat", liftSeat)
		a:SetAttribute("CarConvention", "pivot at the bottom centre, -Z forward, +Y up")
		a.Parent = anchor
		previewCar(liftSeat, 4, group("Workshop"))
	end

	-- the lights: PointLights at the recorded light points
	local rig = plain("LightRig", Vector3.one, base, model)
	for key, spec in GARAGE_LIGHTS do
		local at = shell.points["light_points." .. key]
		if at then
			local a = Instance.new("Attachment")
			a.Name = key
			a.Position = at
			local l = Instance.new("PointLight")
			l.Brightness = spec.brightness
			l.Range = spec.range
			l.Color = spec.colour
			l.Shadows = false
			l.Parent = a
			a.Parent = rig
		end
	end

	-- the GARAGE sign on its recorded face (GarageShell text_faces.1)
	local signs = group("Signs")
	local faceSize =
		Vector2.new(needMeta("GarageShell", "text_faces.1.size.1"), needMeta("GarageShell", "text_faces.1.size.2"))
	local face = signFace(
		"Garage",
		base,
		needPoint("GarageShell", "text_faces.1.centre"),
		needPoint("GarageShell", "text_faces.1.normal"),
		faceSize,
		signs,
		"GarageShell",
		"text_faces.1"
	)
	garageSign(face, faceSize, shell.meta["sign.face.capitals"] or 6.5)

	-- the "Open Garage" prompt at the recorded PromptPoint, outside the entrance. Preview only:
	-- each client shows "Not connected yet" to whoever pressed it (Destinations.client.luau).
	local promptAt = needPoint("GarageShell", "PromptPoint.position")
	local promptPart = plain("PromptPoint", Vector3.one, base * CFrame.new(promptAt), model)
	promptPart:SetAttribute("Zone", "Forecourt")
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "OpenGarage"
	prompt.ActionText = "Open Garage"
	prompt.ObjectText = "Garage (preview)"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 10 -- spec proposal
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute("PressedText", "Not connected yet")
	prompt:SetAttribute("PressedSeconds", 3)
	-- Production hook: the Garage screen opens here once it exists. It is new screen UI, so it goes
	-- through vault/decisions/0012-figma-ui-workflow.md; until then nothing is sent or saved.
	prompt:SetAttribute("ProductionHook", "open the Garage screen (not built; 0012 Figma workflow)")
	prompt.Parent = promptPart

	-- colliders: the three volumes (simple boxes); the forecourt paving is walkable
	local colliders = group("Colliders")
	local cl, ch = blenderBox(-30.6, -5.6, -17, 19.4, 0, 21.5)
	collider("Workshop", base, cl, ch, STAND_CREAM, colliders)
	cl, ch = blenderBox(-6.6, 30.6, -16, 19.4, 0, 26)
	collider("Showroom", base, cl, ch, STAND_CREAM, colliders)
	cl, ch = blenderBox(19.4, 30.9, -17.35, 19.4, 0, 30.6)
	collider("Pylon", base, cl, ch, STAND_STONE, colliders)

	model:SetAttribute("Source", if tally.preview then "preview" else "uploaded")
	model.Parent = root
	report.garage = { parts = tally.parts, triangles = tally.triangles, source = model:GetAttribute("Source") }
	return model
end

-- ---------------------------------------------------------------- Stunt Circuit entrance

local function beamLettering(face: Part, size: Vector2)
	local pps = 25 -- 2.5-stud capitals need about 83 px
	local g = surfaceGui(face, pps, 0.6, "vault/design/ui/island-task4-signs.md section 5, STUNT CIRCUIT")
	local w, h = size.X * pps, size.Y * pps
	-- Texture hook: stunt-beam-lettering.png (spec section 5), once approved and uploaded, goes here
	-- as an ImageLabel under the live letters.
	local panel = frame(g, "Panel", UDim2.fromScale(0, 0), UDim2.fromOffset(w, h), NAVY)
	lettering(
		panel,
		"STUNT CIRCUIT",
		Vector2.new(w / 2, h / 2),
		w - 16,
		math.floor(2.5 / 0.75 * pps),
		YELLOW,
		BAND_SHADE,
		3,
		2
	)
end

local function medal(parent: Instance, rank: number, centre: Vector2, radius: number, textSize: number)
	local colours = { GOLD, CHROME, BRONZE }
	local m = frame(
		parent,
		"Medal",
		UDim2.fromOffset(centre.X, centre.Y),
		UDim2.fromOffset(radius * 2, radius * 2),
		colours[rank],
		Vector2.new(0.5, 0.5),
		radius
	)
	m.ZIndex = 3
	label(m, "Rank", tostring(rank), UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), {
		size = textSize,
		colour = INK,
		z = 4,
	})
end

local function yourBest(face: Part, size: Vector2)
	local pps = 100
	local g = surfaceGui(face, pps, 0.6, "vault/design/ui/island-task4-signs.md section 5, YOUR BEST")
	local w, h = size.X * pps, size.Y * pps
	-- Texture hook: stunt-board-your-best-bg.png (spec section 5) goes here once approved.
	local panel = frame(g, "Panel", UDim2.fromScale(0, 0), UDim2.fromOffset(w, h), NAVY)
	local strip = frame(panel, "Header", UDim2.fromScale(0, 0), UDim2.fromOffset(w, 56), CALM)
	label(strip, "Title", "YOUR BEST", UDim2.fromOffset(20, 0), UDim2.fromOffset(w - 200, 56), {
		size = 40,
		colour = NAVY,
		align = Enum.TextXAlignment.Left,
	})
	previewTag(strip, 22, UDim2.fromOffset(w - 14, 28), Vector2.new(1, 0.5))
	label(panel, "Time", "0:42.7", UDim2.fromOffset(w / 2, 116), UDim2.fromOffset(w - 40, 110), {
		size = 100,
		colour = GOLD,
		stroke = INK,
		strokeThickness = 4,
		anchor = Vector2.new(0.5, 0.5),
	})
	label(panel, "Caption", "best stunt lap time", UDim2.fromOffset(w / 2, 196), UDim2.fromOffset(w - 40, 34), {
		size = 26,
		colour = CHROME,
		anchor = Vector2.new(0.5, 0.5),
	})
end

local function weeklyTop(face: Part, size: Vector2)
	local pps = 100
	local g = surfaceGui(face, pps, 0.6, "vault/design/ui/island-task4-signs.md section 5, WEEKLY TOP")
	local w, h = size.X * pps, size.Y * pps
	-- Texture hook: stunt-board-weekly-top-bg.png (spec section 5) goes here once approved.
	local panel = frame(g, "Panel", UDim2.fromScale(0, 0), UDim2.fromOffset(w, h), NAVY)
	local strip = frame(panel, "Header", UDim2.fromScale(0, 0), UDim2.fromOffset(w, 56), YELLOW)
	label(strip, "Title", "WEEKLY TOP", UDim2.fromOffset(20, 0), UDim2.fromOffset(w - 200, 56), {
		size = 40,
		colour = INK,
		align = Enum.TextXAlignment.Left,
	})
	previewTag(strip, 22, UDim2.fromOffset(w - 14, 28), Vector2.new(1, 0.5))
	for i = 1, 3 do
		local y = 64 + (i - 1) * 54
		local row = frame(panel, "Row" .. i, UDim2.fromOffset(0, y), UDim2.fromOffset(w, 50), NAVY)
		row.BackgroundTransparency = 1
		medal(row, i, Vector2.new(40, 25), 20, 26)
		label(row, "Name", STUNT_ROWS[i][1], UDim2.fromOffset(76, 0), UDim2.fromOffset(330, 50), {
			size = 40,
			scaledMin = 26,
			colour = CREAM,
			align = Enum.TextXAlignment.Left,
		})
		label(row, "Value", STUNT_ROWS[i][2], UDim2.fromOffset(w - 15, 0), UDim2.fromOffset(170, 50), {
			size = 40,
			colour = GOLD,
			align = Enum.TextXAlignment.Right,
			anchor = Vector2.new(1, 0),
		})
	end
end

local function comingSoon(face: Part, size: Vector2)
	local pps = 40
	local g = surfaceGui(face, pps, 0.6, "vault/design/ui/island-task4-signs.md section 5, COMING SOON")
	local w, h = size.X * pps, size.Y * pps
	-- Texture hook: stunt-coming-soon.png (spec section 5) goes here once approved.
	local border = frame(g, "Border", UDim2.fromScale(0, 0), UDim2.fromOffset(w, h), YELLOW)
	local s = Instance.new("UIStroke")
	s.Color = NAVY
	s.Thickness = 3
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = border
	local inset = 20 -- 0.5 stud border
	local panel = frame(
		border,
		"Panel",
		UDim2.fromOffset(inset, inset),
		UDim2.fromOffset(w - 2 * inset, h - 2 * inset),
		CREAM,
		nil,
		6
	)
	local iw, ih = w - 2 * inset, h - 2 * inset
	label(panel, "Title", "COMING SOON", UDim2.fromOffset(iw / 2, ih * 0.36), UDim2.fromOffset(iw - 20, ih * 0.62), {
		size = math.floor(1.15 / 0.75 * pps),
		scaledMin = 30,
		colour = NAVY,
		anchor = Vector2.new(0.5, 0.5),
	})
	previewTag(panel, 18, UDim2.fromOffset(iw / 2, ih * 0.82), Vector2.new(0.5, 0.5))
end

local function buildStunt(root: Instance, report: Report): Model
	local entry = entryOf(park.buildings, "StuntGate")
	local base = frameOf(entry.centre, entry.facing)
	local model = Instance.new("Model")
	model.Name = "StuntGate"
	model:SetAttribute("Frame", base)
	model:SetAttribute("EnvelopeMin", Vector3.new(-18.5, -0.35, -20))
	model:SetAttribute("EnvelopeMax", Vector3.new(18.5, 18, 20))
	-- the loop's sightline-clear box in the right side strip (stunt README): x 13.4..18.3,
	-- Blender y -10..2, top 12.9 or less
	local lo, hi = blenderBox(13.4, 18.3, -10, 2, -0.35, 12.9)
	model:SetAttribute("LoopBoxMin", lo)
	model:SetAttribute("LoopBoxMax", hi)
	model:SetAttribute("Spec", "brief section 10; concepts/stunt/README.md Production")
	model:SetAttribute(
		"LightSequence",
		"preview only: lights 1 to 5 come on red one per second, hold 1 s, all off, 3 s pause; reduced motion: all unlit and steady"
	)
	local gantryInfo = KitAssets.info("StuntGantry")
	local gantryY = gantryInfo.meta["gantry.centre_y"] or -17
	local gantryPoint = base:PointToWorldSpace(Vector3.new(0, 0, -gantryY))
	model:SetAttribute("GantryPoint", gantryPoint)
	local gantryPlan = (park :: any).gantry :: Vector2?
	if gantryPlan then
		model:SetAttribute("GantryOffsetFromLayout", (Layout.worldToPlan(gantryPoint) - gantryPlan).Magnitude)
	end
	local tally: Tally = { triangles = 0, parts = 0, preview = false }
	local pieces = folder("Pieces", model)
	local lights = folder("StartLights", model)
	local signs = folder("Signs", model)

	assert(
		gantryInfo.points["layout.placements." .. #STUNT_MESHES .. ".at"]
			and not gantryInfo.points["layout.placements." .. (#STUNT_MESHES + 1) .. ".at"],
		"StuntGantry layout.placements no longer has " .. #STUNT_MESHES .. " entries; update STUNT_MESHES"
	)
	local light = 0
	local placementsOf: { [number]: CFrame } = {}
	for i, mesh in STUNT_MESHES do
		local at = gantryInfo.points["layout.placements." .. i .. ".at"]
		local rotZ = gantryInfo.meta["layout.placements." .. i .. ".rot_z"] or 0
		local rotX = gantryInfo.meta["layout.placements." .. i .. ".rot_x"] or 0
		local cf = base * CFrame.new(at) * CFrame.Angles(0, math.rad(rotZ), 0) * CFrame.Angles(math.rad(rotX), 0, 0)
		placementsOf[i] = cf
		if mesh == "StuntStartLightHousing" then
			light += 1
			local housing = kit(mesh, cf, lights, tally, "Housing" .. light)
			housing:SetAttribute("Light", light)
		elseif mesh == "StuntStartLightLens" then
			local lens = kit(mesh, cf, lights, tally, "Lens" .. light)
			lens:SetAttribute("Light", light)
			lens:SetAttribute("Lens", true)
			lens.CastShadow = false
			-- Play stand-in lamps (the lens mesh is a preview until imported): two balls per light
			for k = 1, 2 do
				local c = gantryInfo.points["lights." .. light .. ".lens_centres." .. k]
				if c then
					local ball =
						plain("LampStandIn" .. light .. "_" .. k, Vector3.one * 0.9, base * CFrame.new(c), lights)
					ball.Shape = Enum.PartType.Ball
					ball:SetAttribute("Light", light)
					ball:SetAttribute("LampStandIn", true)
				end
			end
		else
			local part = kit(mesh, cf, pieces, tally)
			if mesh == "StuntGantry" or mesh == "StuntLoop" or mesh == "StuntPodium" then
				part.Name = string.sub(mesh, 6) -- Gantry, Loop, Podium
			end
		end
	end

	-- text on the recorded faces (StuntGantry meta text_faces)
	local function faceOf(key: string): (Vector3, Vector3, Vector2)
		return needPoint("StuntGantry", "text_faces." .. key .. ".centre"),
			needPoint("StuntGantry", "text_faces." .. key .. ".normal"),
			Vector2.new(
				needMeta("StuntGantry", "text_faces." .. key .. ".size.1"),
				needMeta("StuntGantry", "text_faces." .. key .. ".size.2")
			)
	end
	for _, side in { "lettering_front", "lettering_back" } do
		local c, n, size = faceOf(side)
		beamLettering(signFace(side, base, c, n, size, signs, "StuntGantry", "text_faces." .. side), size)
	end
	do
		local c, n, size = faceOf("YOUR BEST")
		yourBest(signFace("YourBest", base, c, n, size, signs, "StuntGantry", "text_faces.YOUR BEST"), size)
		c, n, size = faceOf("WEEKLY TOP")
		weeklyTop(signFace("WeeklyTop", base, c, n, size, signs, "StuntGantry", "text_faces.WEEKLY TOP"), size)
		c, n, size = faceOf("COMING SOON")
		comingSoon(signFace("ComingSoon", base, c, n, size, signs, "StuntGantry", "text_faces.COMING SOON"), size)
	end

	-- colliders: pillars (stone base and shaft), the pedestal and the tyre walls only
	local colliders = folder("Colliders", model)
	local g = gantryInfo.meta
	local bx1, bx2 = g["gantry.base.x.1"] or 11, g["gantry.base.x.2"] or 18.3
	local by1, by2 = g["gantry.base.y.1"] or -20, g["gantry.base.y.2"] or -14.55
	local baseTop = g["gantry.base.top"] or 3
	local sx1, sx2 = g["gantry.pillar_inner_x"] or 11, g["gantry.pillar_outer_x"] or 14.5
	local sy1, sy2 = g["gantry.shaft.y.1"] or -18.75, g["gantry.shaft.y.2"] or -15.25
	local shaftTop = g["gantry.beam.underside"] or 10
	for _, s in { -1, 1 } do
		local tag = if s < 0 then "Left" else "Right"
		local x1, x2 = math.min(s * bx1, s * bx2), math.max(s * bx1, s * bx2)
		local cl, ch = blenderBox(x1, x2, by1, by2, -0.2, baseTop)
		collider("PillarBase" .. tag, base, cl, ch, STAND_STONE, colliders)
		x1, x2 = math.min(s * sx1, s * sx2), math.max(s * sx1, s * sx2)
		cl, ch = blenderBox(x1, x2, sy1, sy2, baseTop, shaftTop)
		collider("PillarShaft" .. tag, base, cl, ch, NAVY, colliders)
	end
	local barrier = KitAssets.info("StuntEndBarrier").meta
	local pl, ph = blenderBox(
		barrier["pedestal.x.1"] or -8,
		barrier["pedestal.x.2"] or 8,
		barrier["pedestal.y.1"] or 14.2,
		barrier["pedestal.y.2"] or 19.8,
		-0.2,
		barrier["pedestal.top"] or 4.4
	)
	collider("Pedestal", base, pl, ph, NAVY, colliders)
	local tyre = KitAssets.info("StuntTireRow")
	local tyreCentre = (tyre.min + tyre.max) / 2
	local k = 0
	for i, mesh in STUNT_MESHES do
		if mesh == "StuntTireRow" then
			k += 1
			local c = plain("TyreWall" .. k, tyre.max - tyre.min, placementsOf[i] * CFrame.new(tyreCentre), colliders)
			c.CanCollide = true
			c.CanQuery = true
			c.Color = STAND_TYRE
			c:SetAttribute("Collider", true)
			c:SetAttribute("StandInColour", STAND_TYRE)
		end
	end

	model:SetAttribute("Source", if tally.preview then "preview" else "uploaded")
	model.Parent = root
	report.stunt = {
		parts = tally.parts,
		triangles = tally.triangles,
		source = model:GetAttribute("Source"),
		gantryOffsetFromLayout = model:GetAttribute("GantryOffsetFromLayout"),
	}
	return model
end

-- ---------------------------------------------------------------- leaderboards

local function leaderboardGui(face: Part, kind: "cars" | "stunt", accent: Color3)
	local info = KitAssets.info("LeaderboardFrame").meta
	local pps = info["text_face.canvas.ppstud"] or 50
	local g = surfaceGui(face, pps, 0.4, "vault/design/ui/island-task4-signs.md section 3, revision 2")
	local W, H = 900, 550
	local root = frame(g, "Board", UDim2.fromScale(0, 0), UDim2.fromOffset(W, H), NAVY)
	local edge = Instance.new("UIStroke")
	edge.Color = NAVY
	edge.Thickness = 4
	edge.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	edge.Parent = root

	-- header band, 0 to 112.5 px. Texture hook: leaderboard-header-most-cars.png /
	-- leaderboard-header-fastest-stunt.png (spec section 3) replace this band once approved.
	local header = frame(root, "Header", UDim2.fromScale(0, 0), UDim2.fromOffset(W, 112), NAVY)
	local rim = Instance.new("UIStroke")
	rim.Color = accent
	rim.Thickness = 6
	rim.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	rim.Parent = header
	frame(header, "BaseLine", UDim2.fromOffset(0, 108), UDim2.fromOffset(W, 4), GOLD)
	local badge =
		frame(header, "Badge", UDim2.fromOffset(64, 56), UDim2.fromOffset(96, 96), accent, Vector2.new(0.5, 0.5), 48)
	local icon = Instance.new("ImageLabel")
	icon.Name = "Icon"
	icon.BackgroundTransparency = 1
	icon.AnchorPoint = Vector2.new(0.5, 0.5)
	icon.Position = UDim2.fromScale(0.5, 0.5)
	icon.Size = UDim2.fromOffset(72, 72)
	icon.Image = if kind == "cars" then AssetIds.SignArt.IconGarage else AssetIds.SignArt.IconStunt
	icon.ZIndex = 3
	icon.Parent = badge
	local title = if kind == "cars" then "MOST CARS OWNED" else "FASTEST STUNT CIRCUIT"
	local capitals = if kind == "cars" then 1.17 else 0.92 -- spec section 3 (studs)
	lettering(
		header,
		title,
		Vector2.new(127 + 773 / 2, 54),
		760,
		math.floor(capitals / 0.75 * pps),
		GOLD,
		BAND_SHADE,
		3,
		3
	)

	-- label row, 112.5 to 140
	local labels = frame(root, "Labels", UDim2.fromOffset(0, 112), UDim2.fromOffset(W, 28), NAVY)
	local labelText: TextOptions = { size = 20, colour = CHROME, align = Enum.TextXAlignment.Left }
	label(labels, "Rank", "#", UDim2.fromOffset(30, 0), UDim2.fromOffset(30, 28), {
		size = 20,
		colour = CHROME,
		anchor = Vector2.new(0.5, 0),
	})
	label(labels, "Player", "PLAYER", UDim2.fromOffset(64, 0), UDim2.fromOffset(90, 28), labelText)
	label(
		labels,
		"Value",
		if kind == "cars" then "CARS" else "BEST TIME",
		UDim2.fromOffset(880, 0),
		UDim2.fromOffset(160, 28),
		{
			size = 20,
			colour = CHROME,
			align = Enum.TextXAlignment.Right,
			anchor = Vector2.new(1, 0),
		}
	)
	previewTag(labels, 16, UDim2.fromOffset(660, 14), Vector2.new(1, 0.5))
	if kind == "stunt" then
		local pill = frame(
			labels,
			"WeeklyPill",
			UDim2.fromOffset(160, 14),
			UDim2.fromOffset(96, 23),
			YELLOW,
			Vector2.new(0, 0.5),
			11
		)
		label(pill, "Text", "WEEKLY", UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), { size = 18, colour = INK })
	end

	-- ten rows from 142 at a 40 px pitch (0.8 studs)
	local rows = if kind == "cars" then CARS_ROWS else STUNT_ROWS
	for i, r in rows do
		local row = frame(
			root,
			"Row" .. i,
			UDim2.fromOffset(4, 142 + (i - 1) * 40),
			UDim2.fromOffset(W - 8, 39),
			if i % 2 == 1 then ROW_STRIPE else NAVY
		)
		if i <= 3 then
			medal(row, i, Vector2.new(26, 19.5), 16, 22)
		else
			label(row, "Rank", tostring(i), UDim2.fromOffset(26, 0), UDim2.fromOffset(40, 39), {
				size = 26,
				colour = CREAM,
				anchor = Vector2.new(0.5, 0),
			})
		end
		label(row, "Name", r[1], UDim2.fromOffset(60, 0), UDim2.fromOffset(620, 39), {
			size = 36,
			scaledMin = 26,
			colour = CREAM,
			align = Enum.TextXAlignment.Left,
		})
		label(row, "Value", r[2], UDim2.fromOffset(876, 0), UDim2.fromOffset(180, 39), {
			size = 36,
			colour = if i <= 3 then GOLD else CREAM,
			align = Enum.TextXAlignment.Right,
			anchor = Vector2.new(1, 0),
		})
	end
end

local function buildBoard(root: Instance, id: string, kind: "cars" | "stunt", report: Report): Model
	local entry = entryOf(park.boards, id)
	local base = frameOf(entry.centre, entry.facing or Vector2.new(0, 1))
	local model = Instance.new("Model")
	model.Name = id
	model:SetAttribute("Frame", base)
	model:SetAttribute("EnvelopeMin", Vector3.new(-9, -0.25, -2))
	model:SetAttribute("EnvelopeMax", Vector3.new(9, 15, 2))
	model:SetAttribute("Board", kind)
	model:SetAttribute("Spec", "brief section 12; sign spec section 3 revision 2")
	local tally: Tally = { triangles = 0, parts = 0, preview = false }
	local accent = if kind == "cars" then GARAGE_BADGE_RED else YELLOW
	local frameInfo = KitAssets.info("LeaderboardFrame")

	local body = kit("LeaderboardFrame", base, model, tally, "Frame")
	body:SetAttribute("MirrorPair", true) -- the pair stands mirrored about park.axisX
	kit(
		"LeaderboardTextFace",
		base * CFrame.new(needPoint("LeaderboardFrame", "layout.2.at")),
		model,
		tally,
		"TextFace"
	)
	local rail = kit(
		"LeaderboardCapRail",
		base * CFrame.new(needPoint("LeaderboardFrame", "layout.3.at")),
		model,
		tally,
		"CapRail"
	)
	recolour(rail, accent)
	local lens = kit("LeaderboardLampLens", base, model, tally, "LampLens")
	recolour(lens, LIGHT_PANEL, Enum.Material.Neon)
	lens.CastShadow = false

	-- the front light: a soft SpotLight from the lamp toward the face
	local lightAt = needPoint("LeaderboardFrame", "light.position")
	local lightDir = needPoint("LeaderboardFrame", "light.direction")
	local lamp = plain("LampRig", Vector3.one, base, model)
	local a = Instance.new("Attachment")
	a.Name = "FrontLight"
	a.CFrame = CFrame.lookAt(lightAt, lightAt + lightDir)
	local spot = Instance.new("SpotLight")
	spot.Face = Enum.NormalId.Front
	spot.Brightness = 1.2
	spot.Range = 14
	spot.Angle = 75
	spot.Color = SHOWROOM_LIGHT
	spot.Shadows = false
	spot.Parent = a
	a.Parent = lamp

	local size =
		Vector2.new(needMeta("LeaderboardFrame", "text_face.size.1"), needMeta("LeaderboardFrame", "text_face.size.2"))
	local face = signFace(
		"Leaderboard",
		base,
		needPoint("LeaderboardFrame", "text_face.centre"),
		needPoint("LeaderboardFrame", "text_face.normal"),
		size,
		model,
		"LeaderboardFrame",
		"text_face"
	)
	leaderboardGui(face, kind, accent)

	local lo, hi = blenderBox(-9, 9, -0.6, 0.6, 0, frameInfo.meta["text_face.z.2"] or 14.5)
	collider("Collider", base, lo, hi, NAVY, model)

	model:SetAttribute("Source", if tally.preview then "preview" else "uploaded")
	model.Parent = root
	report[id] = { parts = tally.parts, triangles = tally.triangles, source = model:GetAttribute("Source") }
	return model
end

-- ---------------------------------------------------------------- API

function Destinations.build(parent: Instance): Report
	-- idempotent: any earlier set under this parent goes first (only ours)
	local old = parent:FindFirstChild(Destinations.FolderName)
	while old do
		old:Destroy()
		old = parent:FindFirstChild(Destinations.FolderName)
	end
	local root = Instance.new("Folder")
	root.Name = Destinations.FolderName
	root:SetAttribute("Version", Destinations.Version)
	root:SetAttribute(
		"PreviewOf",
		"Lane 3 Task 4 destinations (brief sections 9, 10, 12); sign spec pending Adam's approval"
	)
	local report: Report = {}
	buildGarage(root, report)
	buildStunt(root, report)
	buildBoard(root, "LeaderboardGarage", "cars", report)
	buildBoard(root, "LeaderboardStunt", "stunt", report)
	root.Parent = parent
	local parts = 0
	for _, d in root:GetDescendants() do
		if d:IsA("BasePart") then
			parts += 1
		end
	end
	report.parts = parts
	return report
end

-- The showroom slots as typed data (the proposed hook for Brian L).
function Destinations.slots(destinations: Instance): { ShowroomSlot }
	local out: { ShowroomSlot } = {}
	local garage = destinations:FindFirstChild("Garage")
	local slots = garage and garage:FindFirstChild("ShowroomSlots")
	local anchor = slots and slots:FindFirstChild("SlotAnchor")
	if not anchor then
		return out
	end
	for _, a in anchor:GetChildren() do
		if a:IsA("Attachment") then
			local kind = a:GetAttribute("Kind")
			table.insert(out, {
				id = a.Name,
				kind = if kind == "Lift" then "Lift" else "Turntable",
				seat = a:GetAttribute("Seat") :: CFrame,
				labelPoint = a:GetAttribute("LabelPoint") :: Vector3?,
				rarity = a:GetAttribute("Rarity") :: string?,
				centre = a:GetAttribute("Centre") :: Vector3?,
			})
		end
	end
	table.sort(out, function(x, y)
		return x.id < y.id
	end)
	return out
end

return Destinations
