--!strict
-- Speedway props by level (Lane 3, presentation only): everything placed around the track, at
-- plot-frame positions inside the plot's reserved bands (HubData reservations: BleachersL / R,
-- Grandstand, PitBuilding, ScreenPad, Flood pads, Gantry, Statue, Fireworks, SignBand). Functional
-- details are grouped by use: pit equipment at the bays, snacks beside the stands, flags at the
-- track boundary, the announcer beside the grandstand. Signs show fictional names only.
--
-- Figures (fans, the flag official, the mechanic) are rigid kit meshes in a Model whose attributes
-- the client animates (SpeedwayLife): BaseCFrame on the model, ShoulderL / ShoulderR offsets.

local Ctx = require(script.Parent.Ctx)
local Kit = require(script.Parent.Kit)
local KitIds = require(script.Parent.KitIds)
local Path = require(script.Parent.Path)
local SignKit = require(script.Parent.Parent.SignKit)

local Tokens = require(script.Parent.Parent.Parent.UI.Tokens)

local Props = {}

type Ctx = Ctx.Ctx

local FONT = Tokens.font()
local CREAM = Color3.fromRGB(255, 246, 224)
local INK = Color3.fromRGB(59, 42, 30)
local NAVY = Color3.fromRGB(36, 58, 98)
local WEST = Vector2.new(-1, 0) -- toward -x
local EAST = Vector2.new(1, 0)
local PARKWARD = Vector2.new(0, -1) -- toward the fountain

-- plot-frame anchors (u from the fountain centre); reservations from HubData
local MAIN_X = -Path.TurnRadius -- the main (left) straight's centre line
local START_U = Path.StartU
Props.Anchors = {
	OwnerSign = Vector2.new(-13, 339.5),
	WonkyFlag = Vector2.new(-20.5, 340.5),
	StartBoard = Vector2.new(-48.4, START_U),
	PennantU = 455,
	Bleachers = Vector2.new(-52.6, 438),
	SnackCart = Vector2.new(-57, 474),
	LapBoard = Vector2.new(-48.2, 423.5),
	Podium = Vector2.new(-19.8, START_U), -- clear of the gantry leg (outer edge x -22.8)
	StartLights = Vector2.new(-46.8, 407),
	PitGarage = Vector2.new(70, 370),
	GrandstandX = -55.6,
	GrandstandU = { 427, 441, 455 },
	Announcer = Vector2.new(-56.5, 467.5),
	-- floodlight towers close enough to frame the track (they read as part of it, not as field poles)
	Floods = { Vector2.new(60, 394), Vector2.new(60, 488), Vector2.new(-60, 394), Vector2.new(-60, 488) },
	Screen = Vector2.new(-70, 380),
	Statue = Vector2.new(0, 385),
	Cannons = { Vector2.new(-23.6, START_U - 6.5), Vector2.new(-23.6, START_U + 6.5) },
	Fireworks = { Vector2.new(-11, 489.8), Vector2.new(11, 489.8) },
	KioskBoard = Vector2.new(31.6, 252.4),
	BlimpCentre = Vector2.new(0, 441),
}
local A = Props.Anchors

-- ------------------------------------------------------------------ helpers

-- A thin invisible face part for a SurfaceGui: at `cf` (its Front face is the CFrame's look).
local function facePart(parent: Instance, cf: CFrame, w: number, h: number, name: string?): Part
	return Kit.part(parent, Vector3.new(w, h, 0.02), cf, {
		name = name or "SignFace",
		transparency = 1,
		castShadow = false,
	})
end

local function surface(part: BasePart, pixelsPerStud: number): SurfaceGui
	local g = Instance.new("SurfaceGui")
	g.Name = "Face"
	g.Face = Enum.NormalId.Front
	g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	g.PixelsPerStud = pixelsPerStud
	g.LightInfluence = 1
	g.MaxDistance = 400
	g.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	g.Parent = part
	return g
end
Props.surface = surface

-- Outlined Fredoka text over a fraction rect { x, y, w, h } of the face.
local function label(
	parent: Instance,
	text: string,
	rect: { number },
	sizePx: number,
	colour: Color3?,
	outline: Color3?
): TextLabel
	local t = Instance.new("TextLabel")
	t.Name = "Text"
	t.BackgroundTransparency = 1
	t.Position = UDim2.fromScale(rect[1], rect[2])
	t.Size = UDim2.fromScale(rect[3], rect[4])
	t.FontFace = FONT
	t.Text = text
	t.TextColor3 = colour or CREAM
	-- scaled to fit the board (a long owner name wraps instead of clipping), up to twice sizePx
	t.TextSize = sizePx
	t.TextWrapped = true
	t.TextScaled = true
	local limit = Instance.new("UITextSizeConstraint")
	limit.MaxTextSize = sizePx * 2
	limit.Parent = t
	local stroke = Instance.new("UIStroke")
	stroke.Color = outline or INK
	stroke.Thickness = math.max(2, math.floor(sizePx / 12))
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	stroke.Parent = t
	t.Parent = parent
	return t
end
Props.label = label

-- A sign face recorded in a mesh's meta under `key` ({centre [x, z], size [w, h], plane_y} in
-- recipe axes; the text faces the recipe's -y, the mesh's front), for a mesh placed at `base`.
-- `back` puts the face on the other side (plane_y on the back, facing +y).
local function meshFace(parent: Instance, mesh: string, key: string, base: CFrame, back: boolean?): Part?
	if not Kit.has(mesh) then
		return nil
	end
	local m = Kit.info(mesh).meta
	local cx, cz = m[key .. ".centre.1"], m[key .. ".centre.2"]
	local w, h = m[key .. ".size.1"], m[key .. ".size.2"]
	local py = m[key .. ".plane_y"]
	if not (cx and cz and w and h and py) then
		return nil
	end
	-- recipe (x, y, z) -> Roblox mesh-local (x, z, -y); the front (-y) is local +Z
	local out = if back then -0.03 else 0.03
	local p = base:PointToWorldSpace(Vector3.new(cx, cz, -py + out))
	local toward = base:VectorToWorldSpace(Vector3.new(0, 0, if back then -1 else 1))
	return facePart(parent, CFrame.lookAt(p, p + toward), w, h)
end

local function ownerText(ctx: Ctx): string
	if ctx.owner ~= "" then
		return ctx.owner .. "'s Raceway"
	end
	return "Your Raceway"
end

-- A figure model: the body as PrimaryPart plus parts. The animator works in the placement frame
-- (BaseCFrame; its axes are the recipe's, whatever turn an uploaded mesh carries): every part
-- records its Rest CFrame in that frame, arms their Shoulder pivot.
local function figure(
	parent: Instance,
	name: string,
	kind: string,
	body: MeshPart,
	extras: { BasePart },
	frame: CFrame
): Model
	local model = Instance.new("Model")
	model.Name = name
	body.Parent = model
	body:SetAttribute("Rest", frame:ToObjectSpace(body.CFrame))
	for _, e in extras do
		e.Parent = model
		if e:GetAttribute("Rest") == nil then
			e:SetAttribute("Rest", frame:ToObjectSpace(e.CFrame))
		end
	end
	model.PrimaryPart = body
	model:SetAttribute("Figure", kind)
	model:SetAttribute("BaseCFrame", frame)
	model.Parent = parent
	return model
end

-- An arm hung from `shoulder` (a world point) on a body placed at `base`; the arm's rest offset
-- from the body is recorded so the animator can swing it about the shoulder.
local function arm(mesh: string, base: CFrame, shoulder: Vector3): MeshPart?
	local pivot = CFrame.new(shoulder) * (base - base.Position)
	return Kit.place(mesh, pivot)
end

-- ------------------------------------------------------------------ level 1

function Props.ownerSignWood(folder: Folder, ctx: Ctx)
	local base = Ctx.face(ctx, A.OwnerSign.X, A.OwnerSign.Y, PARKWARD)
	local sign = Kit.place("SwOwnerSign", base)
	if sign then
		sign.CanCollide = true
		sign.CanQuery = true
		sign.Parent = folder
		local face = meshFace(folder, "SwOwnerSign", "face", base)
		if face then
			local g = surface(face, 50)
			label(g, ownerText(ctx), { 0.05, 0.08, 0.9, 0.84 }, 48, Color3.fromRGB(122, 64, 40), CREAM)
		end
	end
end

-- The painted owner banner (level 4 on) replaces the wooden sign at the same spot.
function Props.ownerBanner(folder: Folder, ctx: Ctx)
	local at = A.OwnerSign
	local bottom, height, width = 3, 3, 12
	local centre = Ctx.at(ctx, at.X, at.Y, bottom + height / 2)
	local toward = centre + Ctx.dir(ctx, PARKWARD)
	local board = Kit.part(folder, Vector3.new(width, height, 0.3), CFrame.lookAt(centre, toward), {
		name = "OwnerBanner",
		color = NAVY,
		castShadow = true,
	})
	Kit.part(folder, Vector3.new(width + 0.4, 0.3, 0.45), board.CFrame * CFrame.new(0, height / 2 + 0.1, 0), {
		name = "OwnerBannerTrim",
		color = Color3.fromRGB(236, 184, 58),
	})
	for _, x in { -1, 1 } do
		local foot = Ctx.at(ctx, at.X + x * (width / 2 - 1), at.Y + 0.35, (bottom + height) / 2)
		Kit.part(folder, Vector3.new(0.5, bottom + height, 0.5), CFrame.lookAt(foot, foot + Ctx.dir(ctx, PARKWARD)), {
			name = "OwnerBannerPost",
			color = Color3.fromRGB(244, 236, 214),
			collide = true,
		})
	end
	local face = facePart(folder, board.CFrame * CFrame.new(0, 0, -0.17), width - 0.4, height - 0.4)
	local g = surface(face, 40)
	label(g, string.upper(ownerText(ctx)), { 0.04, 0.12, 0.92, 0.76 }, 60)
end

-- One wonky flag on a stick (levels 1 to 4): a beam cloth TrackMotion waves.
function Props.wonkyFlag(folder: Folder, ctx: Ctx)
	local base = Ctx.face(ctx, A.WonkyFlag.X, A.WonkyFlag.Y, PARKWARD)
	local stick = Kit.place("SwWonkyStick", base)
	if not stick then
		return
	end
	stick.Parent = folder
	local top = Kit.point("SwWonkyStick", "flag_top", base) or base.Position + Vector3.yAxis * 5.8
	local bottom = Kit.point("SwWonkyStick", "flag_bottom", base) or base.Position + Vector3.yAxis * 4.6
	local host = Kit.part(
		folder,
		Vector3.one * 0.2,
		CFrame.new(top),
		{ name = "FlagHost", transparency = 1, castShadow = false }
	)
	local side = base.RightVector
	local bend = base.LookVector
	local mid = (top + bottom) / 2
	local a0 = Instance.new("Attachment")
	a0.CFrame = host.CFrame:ToObjectSpace(CFrame.fromMatrix(mid + side * 0.1, bend, Vector3.yAxis))
	a0.Parent = host
	local a1 = Instance.new("Attachment")
	a1.CFrame = host.CFrame:ToObjectSpace(CFrame.fromMatrix(mid + side * 2.4, bend, Vector3.yAxis))
	a1.Parent = host
	local b = Instance.new("Beam")
	b.Name = "Flag"
	b.Attachment0, b.Attachment1 = a0, a1
	b.Color = ColorSequence.new(Color3.fromRGB(214, 66, 58))
	b.Width0, b.Width1 = (top - bottom).Magnitude, 0.3
	b.FaceCamera = false
	b.Segments = 8
	b.LightInfluence = 1
	b:SetAttribute("FlagWave", ctx.index * 0.9)
	b:SetAttribute("FlagAmplitude", 0.45)
	b.Parent = host
end

-- ------------------------------------------------------------------ level 2

function Props.startBoard(folder: Folder, ctx: Ctx)
	local base = Ctx.face(ctx, A.StartBoard.X, A.StartBoard.Y, EAST)
	local board = Kit.place("SwStartBoard", base)
	if board then
		board.Parent = folder
		local face = meshFace(folder, "SwStartBoard", "face", base)
		if face then
			label(surface(face, 50), "START  FINISH", { 0.02, 0.1, 0.96, 0.8 }, 40)
		end
	end
end

-- A string of triangle pennants across the main straight on two striped poles.
function Props.pennants(folder: Folder, ctx: Ctx)
	local u = A.PennantU
	local tops: { Vector3 } = {}
	for _, x in { MAIN_X - 10.4, MAIN_X + 10.4 } do
		local base = Ctx.face(ctx, x, u, EAST)
		local pole = Kit.place("SwPennantPole", base)
		if pole then
			pole.Parent = folder
		end
		table.insert(tops, Kit.point("SwPennantPole", "eye", base) or Ctx.at(ctx, x, u, 7.6))
	end
	local host = Kit.part(
		folder,
		Vector3.one * 0.2,
		CFrame.new(tops[1]),
		{ name = "PennantHost", transparency = 1, castShadow = false }
	)
	local down = Vector3.new(0, -1, 0)
	local lateral = Ctx.dir(ctx, Vector2.new(0, 1))
	local function attach(p: Vector3): Attachment
		local a = Instance.new("Attachment")
		a.CFrame = host.CFrame:ToObjectSpace(CFrame.fromMatrix(p, down, lateral))
		a.Parent = host
		return a
	end
	local b = Instance.new("Beam")
	b.Name = "Bunting"
	b.Attachment0, b.Attachment1 = attach(tops[1]), attach(tops[2])
	b.Texture = KitIds.Textures.Pennants
	b.TextureMode = Enum.TextureMode.Wrap
	b.TextureLength = 6
	b.Width0, b.Width1 = 1.4, 1.4
	b.FaceCamera = true
	b.Segments = 16
	b.CurveSize0, b.CurveSize1 = 1.6, -1.6
	b.LightInfluence = 1
	b:SetAttribute("BuntingSag", 1.6)
	b.Parent = host
end

-- ------------------------------------------------------------------ fans

local FAN_VARIANTS = { "A", "B", "C", "D" }

-- Seats fans on a seating mesh's rows (meta rows.N.seat_z / y / x0 / x1) at `base`: `count` fans
-- spread over the rows with a deterministic pattern per plot.
local function seatFans(parent: Folder, ctx: Ctx, mesh: string, base: CFrame, count: number, seed: number)
	if not Kit.has(mesh) then
		return
	end
	local meta = Kit.info(mesh).meta
	local rows = {}
	local r = 1
	while meta[string.format("rows.%d.seat_z", r)] do
		local k = string.format("rows.%d.", r)
		table.insert(rows, {
			z = meta[k .. "seat_z"],
			y = meta[k .. "y"],
			x0 = meta[k .. "x0"],
			x1 = meta[k .. "x1"],
			-- the grandstand's central aisle (its rails): no fan within 0.8 of it
			a0 = meta[k .. "aisle.1"],
			a1 = meta[k .. "aisle.2"],
		})
		r += 1
	end
	if #rows == 0 then
		return
	end
	local rng = Random.new(ctx.index * 101 + seed)
	local perRow = math.ceil(count / #rows)
	local placed = 0
	for ri, row in rows do
		local span = row.x1 - row.x0
		local slots = math.max(1, math.floor(span / 1.6))
		local taken: { [number]: boolean } = {}
		for _ = 1, perRow do
			if placed >= count then
				break
			end
			local slot = rng:NextInteger(0, slots - 1)
			local tries = 0
			while taken[slot] and tries < slots do
				slot = (slot + 1) % slots
				tries += 1
			end
			if taken[slot] then
				break
			end
			taken[slot] = true
			local x = row.x0 + (slot + 0.5) * span / slots
			if row.a0 and row.a1 and x > row.a0 - 0.8 and x < row.a1 + 0.8 then
				continue
			end
			local v = FAN_VARIANTS[rng:NextInteger(1, #FAN_VARIANTS)]
			-- recipe (x, y, z) -> mesh-local (x, z, -y); the fan faces the mesh front (+Z local)
			local seat = base * CFrame.new(x, row.z, -row.y)
			local body = Kit.place("SwFan" .. v, seat)
			if body then
				local extras = {}
				for _, side in { "l", "r" } do
					local shoulder = Kit.point("SwFan" .. v, "shoulder_" .. side, seat)
					if shoulder then
						local a = arm("SwFanArm" .. v, seat, shoulder)
						if a then
							a.Name = if side == "l" then "ArmL" else "ArmR"
							a:SetAttribute("Rest", seat:ToObjectSpace(a.CFrame))
							a:SetAttribute("Shoulder", seat:PointToObjectSpace(shoulder))
							table.insert(extras, a)
						end
					end
				end
				local fan = figure(parent, "Fan", "Fan", body, extras, seat)
				fan:SetAttribute("Phase", rng:NextNumber() * math.pi * 2)
				fan:SetAttribute("Row", ri)
				placed += 1
			end
		end
	end
end

-- ------------------------------------------------------------------ level 3

function Props.bleachers(major: Folder, life: Folder, ctx: Ctx)
	local base = Ctx.face(ctx, A.Bleachers.X, A.Bleachers.Y, EAST)
	local stand = Kit.place("SwBleachers", base)
	if stand then
		stand.CanCollide = true
		stand.CanQuery = true
		stand.Parent = major
	end
	seatFans(life, ctx, "SwBleachers", base, 9, 3)
end

function Props.snackCart(folder: Folder, ctx: Ctx)
	Ctx.place(ctx, folder, "SwSnackCart", A.SnackCart.X, A.SnackCart.Y, EAST)
end

function Props.lapBoard(folder: Folder, ctx: Ctx)
	local base = Ctx.face(ctx, A.LapBoard.X, A.LapBoard.Y, EAST)
	local board = Kit.place("SwLapBoard", base)
	if board then
		board.Parent = folder
		local face = meshFace(folder, "SwLapBoard", "face", base)
		if face then
			local g = surface(face, 60)
			local t = label(g, "LAP 1", { 0.04, 0.1, 0.92, 0.8 }, 44, INK, CREAM)
			t.Name = "LapCount"
			face:SetAttribute("LapCounter", true)
		end
	end
end

-- ------------------------------------------------------------------ level 5

function Props.official(major: Folder, ctx: Ctx)
	local base = Ctx.face(ctx, A.Podium.X, A.Podium.Y, WEST)
	local podium = Kit.place("SwOfficialPodium", base)
	if podium then
		podium.CanCollide = true
		podium.CanQuery = true
		podium.Parent = major
	end
	local stand = Kit.point("SwOfficialPodium", "stand", base) or base.Position + Vector3.yAxis * 2.4
	local at = CFrame.new(stand) * (base - base.Position)
	local body = Kit.place("SwOfficialBody", at)
	if not body then
		return
	end
	local extras = {}
	local shoulder = Kit.point("SwOfficialBody", "shoulder_r", at)
	if shoulder then
		local a = arm("SwOfficialArm", at, shoulder)
		if a then
			a.Name = "ArmR"
			a:SetAttribute("Rest", at:ToObjectSpace(a.CFrame))
			a:SetAttribute("Shoulder", at:PointToObjectSpace(shoulder))
			table.insert(extras, a)
		end
	end
	figure(major, "FlagOfficial", "Official", body, extras, at)
end

-- The start light tree: five lamp rows, lit by the animator (neon caps over the dark lenses).
function Props.startLights(folder: Folder, ctx: Ctx)
	local base = Ctx.face(ctx, A.StartLights.X, A.StartLights.Y, Vector2.new(1, 1).Unit)
	local tree = Kit.place("SwStartLights", base)
	if not tree then
		return
	end
	tree.Parent = folder
	for k = 1, 5 do
		local p = Kit.point("SwStartLights", string.format("lamps.%d", k), base)
		if p then
			local lamp = Kit.part(
				folder,
				Vector3.new(0.9, 0.5, 0.06),
				CFrame.lookAt(p, p - base.LookVector) * CFrame.new(0, 0, -0.04),
				{
					name = "StartLamp",
					color = Color3.fromRGB(60, 64, 76),
					material = Enum.Material.SmoothPlastic,
					castShadow = false,
				}
			)
			lamp:SetAttribute("StartLamp", k)
		end
	end
end

-- The base flag line in the outer sign band (Task 3, moved from Hub/Recipes/Plot): nine poles
-- with cloth flags and pennant bunting between them, along the far boundary.
function Props.flagLine(folder: Folder, ctx: Ctx)
	local u = 546.8 -- the SignBand's centre line (HubData: u 540.8 to 552.8)
	local cloths = { "FlagChecker", "FlagStripesA", "FlagStar", "FlagStripesB" }
	local host = Kit.part(
		folder,
		Vector3.one,
		CFrame.new(Ctx.at(ctx, 0, u, 0)),
		{ name = "BeamHost", transparency = 1, castShadow = false }
	)
	local function attach(pos: Vector3, x: Vector3, y: Vector3): Attachment
		local a = Instance.new("Attachment")
		a.CFrame = host.CFrame:ToObjectSpace(CFrame.fromMatrix(pos, x, y))
		a.Parent = host
		return a
	end
	local along = Ctx.dir(ctx, Vector2.new(1, 0))
	local lateral = along:Cross(Vector3.yAxis).Unit
	local tops = {}
	for k = -4, 4 do
		local base = Ctx.at(ctx, k * 20, u, 0)
		Kit.part(folder, Vector3.new(0.45, 10, 0.45), CFrame.new(base + Vector3.yAxis * 5), {
			name = "FlagPole",
			color = Color3.fromRGB(246, 242, 236),
			collide = true,
		})
		Kit.part(folder, Vector3.new(0.6, 0.6, 0.6), CFrame.new(base + Vector3.yAxis * 10.1), {
			name = "FlagPoleKnob",
			color = Color3.fromRGB(200, 158, 66),
			shape = Enum.PartType.Ball,
		})
		local top = base + Vector3.yAxis * 9.6
		table.insert(tops, top)
		local mid = top - Vector3.yAxis
		local b = Instance.new("Beam")
		b.Name = "Flag"
		b.Attachment0 = attach(mid + along * 0.25, lateral, Vector3.yAxis)
		b.Attachment1 = attach(mid + along * 4.2, lateral, Vector3.yAxis)
		b.Texture = (KitIds.Textures :: any)[cloths[(k + 4) % #cloths + 1]]
		b.TextureMode = Enum.TextureMode.Stretch
		b.TextureLength = 1
		b.Width0, b.Width1 = 2, 2
		b.FaceCamera = false
		b.Segments = 12
		b.LightInfluence = 1
		b:SetAttribute("FlagWave", (k + 4) * 0.7)
		b.Parent = host
	end
	for i = 1, #tops - 1 do
		local b = Instance.new("Beam")
		b.Name = "Bunting"
		b.Attachment0 = attach(tops[i] - Vector3.yAxis * 2.6, Vector3.new(0, -1, 0), lateral)
		b.Attachment1 = attach(tops[i + 1] - Vector3.yAxis * 2.6, Vector3.new(0, -1, 0), lateral)
		b.Texture = KitIds.Textures.Pennants
		b.TextureMode = Enum.TextureMode.Wrap
		b.TextureLength = 6
		b.Width0, b.Width1 = 1.4, 1.4
		b.FaceCamera = true
		b.Segments = 16
		b.CurveSize0, b.CurveSize1 = 2.2, -2.2
		b.LightInfluence = 1
		b:SetAttribute("BuntingSag", 2.2)
		b.Parent = host
	end
end

-- ------------------------------------------------------------------ level 6

-- PIT ROW (M4-06): a real pit building, drawn with parts in the plot's PitBuilding reservation. Three
-- numbered bays open to the pit lane, one door up, one half up, one down; a canopy over the apron,
-- an office block breaking the roofline, racks inside the bays. In local terms z points at the
-- lane, x runs along the building. Every surface here is inset or stepped from its neighbour by at
-- least 0.08, so nothing shares a plane. The mesh SwPitGarage is no longer used.
local PIT = {
	Wall = Color3.fromRGB(226, 222, 212),
	Trim = Color3.fromRGB(30, 50, 104),
	Accent = Color3.fromRGB(247, 200, 58),
	Door = Color3.fromRGB(150, 158, 170),
	Dark = Color3.fromRGB(58, 62, 72),
	Glass = Color3.fromRGB(120, 196, 232),
}

function Props.pitGarage(major: Folder, ctx: Ctx)
	local base = Ctx.face(ctx, A.PitGarage.X, A.PitGarage.Y, WEST)
	local function box(
		name: string,
		size: Vector3,
		x: number,
		y: number,
		z: number,
		colour: Color3,
		collide: boolean?
	): Part
		return Kit.part(major, size, base * CFrame.new(x, y, z), { name = name, color = colour, collide = collide })
	end
	local length, depth, tall = 29, 16, 9
	box("PitFloor", Vector3.new(length + 1, 0.3, depth + 7), 0, 0.09, -2.5 + 3.5, Color3.fromRGB(206, 200, 190), true)
	box("PitBack", Vector3.new(length, tall, 0.6), 0, tall / 2 + 0.24, -depth / 2, PIT.Wall, true)
	for _, sx in { 1, -1 } do
		box(
			"PitSide",
			Vector3.new(0.7, tall - 0.2, depth - 0.8),
			sx * (length / 2 - 0.35),
			(tall - 0.2) / 2 + 0.24,
			0.1,
			PIT.Wall,
			true
		)
	end
	for _, x in { -length / 6, length / 6 } do
		box("PitPier", Vector3.new(0.9, tall - 0.2, depth - 1), x, (tall - 0.2) / 2 + 0.24, 0, PIT.Trim, true)
	end
	-- the roof, the fascia and the canopy over the apron
	box("PitRoof", Vector3.new(length + 1.6, 0.6, depth + 5.4), 0, tall + 0.54, 2.7, PIT.Wall, true)
	box("PitFascia", Vector3.new(length + 2.2, 1.1, 0.5), 0, tall + 0.34, depth / 2 + 5.6, PIT.Trim)
	box("PitFasciaTrim", Vector3.new(length + 2.6, 0.2, 0.7), 0, tall + 0.97, depth / 2 + 5.6, PIT.Accent)
	for _, sx in { 1, -1 } do
		box(
			"PitCanopyPost",
			Vector3.new(0.5, tall - 0.2, 0.5),
			sx * (length / 2 + 0.2),
			(tall - 0.2) / 2 + 0.24,
			depth / 2 + 5,
			PIT.Trim,
			true
		)
	end
	-- the office block breaks the roofline; a stair of glass faces the lane
	box("PitOffice", Vector3.new(12, 3.4, 7), -4, tall + 2.54, -3, PIT.Wall, true)
	box("PitOfficeRoof", Vector3.new(13, 0.4, 8), -4, tall + 4.44, -3, PIT.Trim)
	box("PitOfficeGlass", Vector3.new(10.6, 1.8, 0.2), -4, tall + 2.74, 0.58, PIT.Glass).Material = Enum.Material.Glass

	local bay = length / 3
	for k, x in { -bay, 0, bay } do
		-- the roll-up door: its top rolled into a drum, its bottom at the height it stands open
		local openTo = ({ 0, 3.4, 6.8 } :: { number })[k]
		local doorZ = depth / 2 - 1
		local doorTop = tall - 0.2
		if openTo < 6.8 then
			local h = doorTop - 0.24 - openTo
			box("PitDoor", Vector3.new(bay - 1.3, h, 0.24), x, 0.24 + openTo + h / 2, doorZ, PIT.Door)
			for y = 0.24 + openTo + 0.9, doorTop - 0.3, 1.2 do
				box("PitDoorRib", Vector3.new(bay - 1.4, 0.12, 0.08), x, y, doorZ + 0.16, PIT.Dark)
			end
		end
		box("PitDrum", Vector3.new(bay - 1.2, 0.7, 0.7), x, doorTop + 0.12, doorZ - 0.1, PIT.Dark)
		-- the rack on the back wall of each bay
		for _, y in { 2, 3.6, 5.2 } do
			box("PitShelf", Vector3.new(bay - 2.6, 0.14, 1.1), x, y, -depth / 2 + 0.9, PIT.Dark)
		end
		for j, t in { -2, 0.4, 2.4 } do
			box(
				"PitBin",
				Vector3.new(1.2, 0.8, 0.8),
				x + t,
				2 + (j % 2) * 1.6 + 0.47,
				-depth / 2 + 0.9,
				if j == 2 then PIT.Accent else Color3.fromRGB(214, 62, 56)
			)
		end
		-- the numbered bay plate on the fascia
		local plateAt = base * CFrame.new(x, tall + 0.34, depth / 2 + 5.85) * CFrame.Angles(0, math.pi, 0)
		SignKit.sign(major, plateAt, { style = "Race", text = string.format("%02d", k), width = 2.6, height = 0.9 })
	end
	-- the one primary name, above the canopy
	local signAt = base * CFrame.new(5, tall + 3.1, depth / 2 + 2.6) * CFrame.Angles(0, math.pi, 0)
	SignKit.sign(
		major,
		signAt,
		{ style = "Race", text = "PIT ROW", width = 15, height = 3.4, bulbs = true, backlight = true }
	)
	box("PitSignStay", Vector3.new(11, 0.4, 0.4), 5, tall + 1.05, depth / 2 + 2.3, PIT.Trim)

	-- the pit wall: a low wall between the apron and the lane, with a gap at each end for cars
	local wallZ = A.PitGarage.X - 57
	box("PitWall", Vector3.new(26, 1.2, 0.8), 0, 0.84, wallZ, Color3.fromRGB(236, 232, 224), true)
	box("PitWallCap", Vector3.new(26.2, 0.16, 0.96), 0, 1.52, wallZ, PIT.Accent)
	for x = -11.25, 11.25, 7.5 do
		box("PitWallPanel", Vector3.new(3.6, 0.7, 0.08), x, 0.84, wallZ + 0.46, PIT.Trim)
	end
end

-- The pit zone only: tool chests in the bays' mouths, tyre stacks on the apron, a fuel rig at each
-- end of the pit wall (M4-05). Nothing race-related stands anywhere else.
function Props.pitProps(folder: Folder, ctx: Ctx)
	Ctx.place(ctx, folder, "SwToolChest", 62.6, 361, WEST)
	Ctx.place(ctx, folder, "SwToolChest", 62.6, 379, WEST)
	Ctx.place(ctx, folder, "SwTyreStackTall", 61.2, 365.6, WEST)
	Ctx.place(ctx, folder, "SwTyreStackTall", 61.2, 374.4, WEST)
	for _, u in { 354.4, 385.6 } do
		Kit.part(folder, Vector3.new(1.3, 2.6, 1), CFrame.new(Ctx.at(ctx, 60.4, u, 1.54)), {
			name = "FuelRig",
			color = Color3.fromRGB(214, 62, 56),
			collide = true,
		})
		Kit.part(folder, Vector3.new(1.5, 0.2, 1.2), CFrame.new(Ctx.at(ctx, 60.4, u, 2.94)), {
			name = "FuelRigCap",
			color = Color3.fromRGB(247, 200, 58),
		})
	end
end

-- Pit lanes painted in the track's language: white edge lines both sides, and a pit entry and exit
-- line across the lane where it meets the track (Hub/Layout PitOut / PitIn).
Props.PitOut = {
	Vector2.new(33, 284.187),
	Vector2.new(31, 305.187),
	Vector2.new(51.5, 340.187),
	Vector2.new(51.5, 364.187),
	Vector2.new(46, 392.187),
	Vector2.new(41.5, 406.187),
}
local PIT_LINE_TOP = 0.29 -- over the road's own paint where a lane meets the track
function Props.pitPaint(folder: Folder, ctx: Ctx)
	for _, sign in { 1, -1 } do
		local pts = {}
		for _, p in Props.PitOut do
			table.insert(pts, Vector2.new(p.X * sign, p.Y))
		end
		for i = 1, #pts - 1 do
			local a, b = pts[i], pts[i + 1]
			local d = (b - a).Unit
			local n = Vector2.new(-d.Y, d.X)
			for _, off in { -4.1, 4.1 } do
				local pa, pb = a + n * off, b + n * off
				local before = if i > 1
					then math.tan(math.acos(math.clamp((a - pts[i - 1]).Unit:Dot(d), -1, 1)) / 2) * 4.1
					else 0
				local after = if i < #pts - 1
					then math.tan(math.acos(math.clamp(d:Dot((pts[i + 2] - b).Unit), -1, 1)) / 2) * 4.1
					else 0
				Kit.slab(
					folder,
					Ctx.at(ctx, (pa - d * before).X, (pa - d * before).Y, PIT_LINE_TOP),
					Ctx.at(ctx, (pb + d * after).X, (pb + d * after).Y, PIT_LINE_TOP),
					Vector3.yAxis,
					0.3,
					0.2,
					{
						name = "PitLine",
						color = Color3.new(1, 1, 1),
						castShadow = false,
					},
					0
				)
			end
		end
		-- the pit entry or exit line: where the lane leaves the track's outer line
		local a, b = pts[#pts - 1], pts[#pts]
		local d = (b - a).Unit
		local mid = b - d * 3
		local n = Vector2.new(-d.Y, d.X)
		Kit.slab(
			folder,
			Ctx.at(ctx, (mid - n * 4.1).X, (mid - n * 4.1).Y, PIT_LINE_TOP),
			Ctx.at(ctx, (mid + n * 4.1).X, (mid + n * 4.1).Y, PIT_LINE_TOP),
			Vector3.yAxis,
			0.5,
			0.2,
			{ name = "PitLine", color = Color3.new(1, 1, 1), castShadow = false },
			0
		)
	end
end

function Props.mechanic(life: Folder, ctx: Ctx)
	local base = Ctx.face(ctx, 60.8, A.PitGarage.Y, WEST) -- on the apron, clear of the pit wall
	local body = Kit.place("SwMechanic", base)
	if not body then
		return
	end
	local extras = {}
	local hand = Kit.point("SwMechanic", "hand_r", base)
	if hand then
		local w = Kit.place("SwWrench", CFrame.new(hand) * (base - base.Position))
		if w then
			w.Name = "Wrench"
			w:SetAttribute("Shoulder", base:PointToObjectSpace(hand))
			table.insert(extras, w)
		end
	end
	figure(life, "Mechanic", "Mechanic", body, extras, base)
end

-- ------------------------------------------------------------------ level 7

function Props.grandstand(major: Folder, life: Folder, ctx: Ctx)
	for k, u in A.GrandstandU do
		local base = Ctx.face(ctx, A.GrandstandX, u, EAST)
		local bay = Kit.place("SwGrandstandBay", base)
		if bay then
			bay.CanCollide = true
			bay.CanQuery = true
			bay.Parent = major
		end
		seatFans(life, ctx, "SwGrandstandBay", base, 12, 10 + k)
	end
	-- two mirrored coral end caps on the fascia at the stand's outer ends (Raceway round 2; the
	-- bay mesh repeats, so the caps are placed once here)
	local us = A.GrandstandU
	local half = Kit.meta("SwGrandstandBay", "module.1", 14) / 2
	local y = Kit.meta("SwGrandstandBay", "fascia.y", -5.5)
	local tall = Kit.meta("SwGrandstandBay", "fascia.height", 1.4)
	for _, side in { -1, 1 } do
		local u = if side < 0 then us[1] - half + 0.3 else us[#us] + half - 0.3
		local base = Ctx.face(ctx, A.GrandstandX, u, EAST)
		Kit.part(major, Vector3.new(0.6, tall + 0.12, 0.5), base * CFrame.new(0, (tall + 0.12) / 2, -y + 0.1), {
			name = "GrandstandEndCap",
			color = Color3.fromRGB(244, 127, 112),
		})
	end
end

function Props.announcer(major: Folder, ctx: Ctx)
	local booth = Ctx.place(ctx, major, "SwAnnouncerBooth", A.Announcer.X, A.Announcer.Y, EAST)
	if booth then
		booth.CanCollide = true
		booth.CanQuery = true
	end
end

-- ------------------------------------------------------------------ level 8

function Props.floodlights(major: Folder, ctx: Ctx)
	for _, p in A.Floods do
		local toward = (Vector2.new(0, 441) - p).Unit
		local base = Ctx.face(ctx, p.X, p.Y, toward)
		local tower = Kit.place("SwFloodTower", base)
		if tower then
			tower.CanCollide = true
			tower.CanQuery = true
			tower.Parent = major
			local lamp = Kit.point("SwFloodTower", "lamp_centre", base) or base.Position + Vector3.yAxis * 38
			local lens = Kit.part(
				major,
				Vector3.new(5.4, 3.2, 0.1),
				CFrame.lookAt(lamp, lamp + base:VectorToWorldSpace(Vector3.new(0, -0.25, 1))) * CFrame.new(0, 0, -0.35),
				{
					name = "FloodLens",
					color = Color3.fromRGB(255, 244, 214),
					material = Enum.Material.Neon,
					transparency = 0.35,
					castShadow = false,
				}
			)
			lens:SetAttribute("FloodLens", true)
			local light = Instance.new("SpotLight")
			light.Brightness = 0.6
			light.Range = 60
			light.Angle = 70
			light.Face = Enum.NormalId.Front
			light.Color = Color3.fromRGB(255, 240, 210)
			light.Shadows = false
			light.Parent = lens
		end
	end
end

function Props.gantry(major: Folder, minor: Folder, ctx: Ctx, gold: boolean)
	local base = Ctx.face(ctx, MAIN_X, START_U, Vector2.new(0, 1))
	if gold then
		local trim = Kit.place("SwGantryGold", base)
		if trim then
			trim.Parent = major
		end
		return
	end
	local gantry = Kit.place("SwGantry", base)
	if gantry then
		-- the mesh's box would close the road under the arch: invisible colliders on the legs only
		gantry.Parent = major
		for _, key in { "legs_x.1", "legs_x.2" } do
			local x = Kit.meta("SwGantry", key, 0)
			local height = Kit.meta("SwGantry", "clear_height", 16)
			Kit.part(major, Vector3.new(2.8, height, 3), base * CFrame.new(x, height / 2, 0), {
				name = "GantryLegCollider",
				transparency = 1,
				collide = true,
				castShadow = false,
			})
		end
		for _, key in { "face", "face_back" } do
			local face = meshFace(major, "SwGantry", key, base, key == "face_back")
			if face then
				label(surface(face, 40), "START  ·  FINISH", { 0.02, 0.06, 0.96, 0.88 }, 60)
			end
		end
		-- the light row under the beam (lit by the animator on each finish)
		local lights = Kit.part(minor, Vector3.new(18, 0.35, 0.12), base * CFrame.new(0, 15.6, 1.05), {
			name = "GantryLights",
			color = Color3.fromRGB(255, 220, 120),
			material = Enum.Material.Neon,
			transparency = 0.5,
			castShadow = false,
		})
		lights:SetAttribute("GantryLights", true)
	end
end

-- The big screen (Raceway round 2, approved by Adam 2026-10-29; speedway-upgrade-board.md R3): one
-- calm "RACEWAY LEVEL n" in cream with a small teal underline, no ads, rows or payouts. Near and Far
-- are both built; the client shows the words near and only the broad bar far (Kiosk.screenDetail),
-- and fills the level (Kiosk.fillScreen).
function Props.bigScreen(major: Folder, ctx: Ctx)
	local facing = (Vector2.new(-10, 330) - A.Screen).Unit
	local base = Ctx.face(ctx, A.Screen.X, A.Screen.Y, facing)
	local screen = Kit.place("SwBigScreen", base)
	if not screen then
		return
	end
	screen.CanCollide = true
	screen.CanQuery = true
	screen.Parent = major
	local face = meshFace(major, "SwBigScreen", "face", base)
	if not face then
		return
	end
	local g = surface(face, 25)
	local bg = Instance.new("Frame")
	bg.Size = UDim2.fromScale(1, 1)
	bg.BackgroundColor3 = Color3.fromRGB(20, 27, 51)
	bg.BorderSizePixel = 0
	bg.Parent = g
	local function layer(name: string, visible: boolean): Frame
		local f = Instance.new("Frame")
		f.Name = name
		f.Size = UDim2.fromScale(1, 1)
		f.BackgroundTransparency = 1
		f.Visible = visible
		f.Parent = bg
		return f
	end
	local function underline(parent: Instance)
		local u = Instance.new("Frame")
		u.BorderSizePixel = 0
		u.BackgroundColor3 = Tokens.Color.Teal
		u.Position = UDim2.fromScale(170 / 500, 150 / 275)
		u.Size = UDim2.fromScale(160 / 500, 8 / 275)
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0, 4)
		c.Parent = u
		u.Parent = parent
	end
	local near = layer("Near", true)
	local t = Instance.new("TextLabel")
	t.Name = "ScreenLevel"
	t.BackgroundTransparency = 1
	t.Position = UDim2.fromScale(0, 78 / 275)
	t.Size = UDim2.fromScale(1, 60 / 275)
	t.FontFace = FONT
	t.Text = "RACEWAY LEVEL " .. ctx.level
	t.TextColor3 = CREAM
	t.TextScaled = true
	local limit = Instance.new("UITextSizeConstraint")
	limit.MaxTextSize = 48
	limit.MinTextSize = 28
	limit.Parent = t
	t.Parent = near
	underline(near)
	local far = layer("Far", false)
	local cream = Instance.new("Frame")
	cream.BorderSizePixel = 0
	cream.BackgroundColor3 = CREAM
	cream.Position = UDim2.fromScale(95 / 500, 92 / 275)
	cream.Size = UDim2.fromScale(310 / 500, 40 / 275)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 10)
	c.Parent = cream
	cream.Parent = far
	underline(far)
	face:SetAttribute("RacewayScreen", true)
end

-- ------------------------------------------------------------------ levels 11 and 12

function Props.blimp(major: Folder, ctx: Ctx)
	local c = A.BlimpCentre
	local at = Ctx.at(ctx, c.X + 52, c.Y, 58)
	local base = CFrame.lookAt(at, at + Ctx.dir(ctx, Vector2.new(0, 1)))
	local blimp = Kit.place("SwBlimp", base)
	if not blimp then
		return
	end
	-- plain painted envelope, no lettering (Raceway round 2, Adam 2026-10-29)
	local model = figure(major, "Blimp", "Blimp", blimp, {}, base)
	model:SetAttribute("Centre", Ctx.at(ctx, c.X, c.Y, 58))
	model:SetAttribute("Radius", 52)
end

function Props.statue(major: Folder, ctx: Ctx)
	local base = Ctx.face(ctx, A.Statue.X, A.Statue.Y, PARKWARD)
	local pedestal = Kit.place("SwStatuePedestal", base)
	if pedestal then
		pedestal.CanCollide = true
		pedestal.CanQuery = true
		pedestal.Parent = major
		local face = meshFace(major, "SwStatuePedestal", "face", base)
		if face then
			label(surface(face, 50), "CHAMPION", { 0.02, 0.08, 0.96, 0.84 }, 40, Color3.fromRGB(250, 206, 70))
		end
	end
	local top = Kit.meta("SwStatuePedestal", "height", 4)
	local car = Kit.place("SwStatueCar", base * CFrame.new(0, top, 0))
	if car then
		car.Parent = major
		car:SetAttribute("Placeholder", "statue of the owner's rarest car: Lane 2 data and Brian L's car model later")
	end
end

function Props.roof(major: Folder, ctx: Ctx)
	local roof = Ctx.place(ctx, major, "SwRoofSection", A.GrandstandX, A.GrandstandU[2], EAST)
	if roof then
		roof.CanCollide = true
		roof.CanQuery = true
	end
end

function Props.cannons(folder: Folder, ctx: Ctx)
	for _, p in A.Cannons do
		local cannon = Ctx.place(ctx, folder, "SwConfettiCannon", p.X, p.Y, WEST)
		if cannon then
			cannon:SetAttribute("ConfettiCannon", true)
		end
	end
	for _, p in A.Fireworks do
		local rack = Ctx.place(ctx, folder, "SwFireworkRack", p.X, p.Y, PARKWARD)
		if rack then
			rack:SetAttribute("FireworkRack", true)
		end
	end
end

-- ------------------------------------------------------------------ Raceway shop (all levels)

-- The Raceway shop (Raceway round 2, Adam 2026-10-29) replaces the plot's kiosk booth in the Kiosk
-- reservation (HubData: x 19..29, u 250.187..258.187, height 9): the SwRacewayShop booth (9 x 7 x
-- 8.5 with the awning, 0.5 inside the reservation), its fascia face for the sign, and the
-- shopkeeper, a rigid figure (body and two arms) the client animates (Home/Island/Speedway/Keeper).
-- Only the booth's body collides (an invisible box); the awning, the keeper and the counter props
-- never do, so nobody is pushed or trapped.
Props.ShopCentre = Vector2.new(24, 254.187)

function Props.shop(major: Folder, life: Folder, ctx: Ctx)
	local base = Ctx.face(ctx, Props.ShopCentre.X, Props.ShopCentre.Y, PARKWARD)
	local booth = Kit.place("SwRacewayShop", base)
	if not booth then
		return
	end
	booth.Parent = major
	local x0, x1 = Kit.meta("SwRacewayShop", "collider.x.1", -4.5), Kit.meta("SwRacewayShop", "collider.x.2", 4.5)
	local y0, y1 = Kit.meta("SwRacewayShop", "collider.y.1", -2), Kit.meta("SwRacewayShop", "collider.y.2", 3.5)
	local top = Kit.meta("SwRacewayShop", "collider.z.2", 7.9)
	-- recipe (x, y, z) -> mesh-local (x, z, -y)
	Kit.part(major, Vector3.new(x1 - x0, top, y1 - y0), base * CFrame.new((x0 + x1) / 2, top / 2, -(y0 + y1) / 2), {
		name = "ShopCollider",
		transparency = 1,
		collide = true,
		castShadow = false,
	})
	local fascia = meshFace(major, "SwRacewayShop", "fascia", base)
	if fascia then
		fascia.Name = "ShopFascia"
		fascia:SetAttribute("ShopFascia", true)
		-- one cream sign, navy "RACEWAY UPGRADES" (speedway-upgrade-board.md R4): the mesh is the cream
		-- board, so the face draws only the thin navy inner line and the words
		local g = surface(fascia, 50)
		local line = Instance.new("Frame")
		line.BackgroundTransparency = 1
		line.Position = UDim2.fromOffset(5, 5)
		line.Size = UDim2.new(1, -10, 1, -10)
		local stroke = Instance.new("UIStroke")
		stroke.Color = NAVY
		stroke.Thickness = 2
		stroke.Parent = line
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 6)
		corner.Parent = line
		line.Parent = g
		local t = Instance.new("TextLabel")
		t.BackgroundTransparency = 1
		t.Size = UDim2.fromScale(1, 1)
		t.FontFace = FONT
		t.Text = "RACEWAY UPGRADES"
		t.TextColor3 = NAVY
		t.TextScaled = true
		local limit = Instance.new("UITextSizeConstraint")
		limit.MaxTextSize = 38
		limit.MinTextSize = 24
		limit.Parent = t
		t.Parent = g
	end
	-- where the owner's prompt sits: over the counter front, at chest height
	local counter = Kit.meta("SwRacewayShop", "counter_top", 3)
	local anchor = Kit.part(major, Vector3.one * 0.4, base * CFrame.new(0, counter + 0.6, -y0 + 0.4), {
		name = "ShopPromptAnchor",
		transparency = 1,
		castShadow = false,
	})
	anchor:SetAttribute("ShopPromptAnchor", true)

	local feet = Kit.point("SwRacewayShop", "keeper", base)
	if not feet then
		return
	end
	local at = CFrame.new(feet) * (base - base.Position)
	local body = Kit.place("SwKeeperBody", at)
	if not body then
		return
	end
	local extras = {}
	for _, side in { "l", "r" } do
		local shoulder = Kit.point("SwKeeperBody", "shoulder_" .. side, at)
		if shoulder then
			local a = arm("SwKeeperArm", at, shoulder)
			if a then
				a.Name = if side == "l" then "ArmL" else "ArmR"
				a:SetAttribute("Rest", at:ToObjectSpace(a.CFrame))
				a:SetAttribute("Shoulder", at:PointToObjectSpace(shoulder))
				table.insert(extras, a)
			end
		end
	end
	local keeper = figure(life, "Shopkeeper", "Keeper", body, extras, at)
	keeper:SetAttribute("Phase", ctx.index * 1.7) -- no two plots' keepers bob in step
end

-- ------------------------------------------------------------------ kiosk board (all levels)

-- The upgrade board beside the Paddock kiosk: current level, the next level's name and a picture
-- of what it adds, and a price placeholder marked PREVIEW (no amount: prices are Lane 2's). The
-- client fills the texts and the picture for the plot's level (SpeedwayLooks).
function Props.kioskBoard(folder: Folder, ctx: Ctx)
	local at = A.KioskBoard
	local bottom, height, width = 1.6, 5, 4.6
	local centre = Ctx.at(ctx, at.X, at.Y, bottom + height / 2)
	local cf = CFrame.lookAt(centre, centre + Ctx.dir(ctx, PARKWARD))
	local _board =
		Kit.part(folder, Vector3.new(width, height, 0.3), cf, { name = "KioskBoard", color = NAVY, collide = true })
	Kit.part(folder, Vector3.new(width + 0.3, 0.35, 0.45), cf * CFrame.new(0, height / 2 + 0.1, 0), {
		name = "KioskBoardTrim",
		color = Color3.fromRGB(234, 88, 50),
	})
	for _, x in { -1, 1 } do
		local foot = Ctx.at(ctx, at.X + x * (width / 2 - 0.4), at.Y + 0.3, (bottom + height) / 2)
		Kit.part(folder, Vector3.new(0.4, bottom + height, 0.4), CFrame.lookAt(foot, foot + Ctx.dir(ctx, PARKWARD)), {
			name = "KioskBoardPost",
			color = Color3.fromRGB(244, 236, 214),
			collide = true,
		})
	end
	local face = facePart(folder, cf * CFrame.new(0, 0, -0.17), width - 0.3, height - 0.3, "KioskBoardFace")
	face:SetAttribute("KioskBoard", true)
	surface(face, 50)
end

return Props
