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
	Shed = Vector2.new(68, 470),
	Lemonade = Vector2.new(60, 420),
	Chair = Vector2.new(59.6, 414.6),
	Barrel = Vector2.new(62.6, 461.5),
	Barrow = Vector2.new(63.5, 478),
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
		return ctx.owner .. "'s Speedway"
	end
	return "Your Speedway"
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

function Props.shed(folder: Folder, ctx: Ctx, painted: boolean)
	local shed = Ctx.place(ctx, folder, if painted then "SwPaintedShed" else "SwRustyShed", A.Shed.X, A.Shed.Y, WEST)
	if shed then
		shed.CanCollide = true
		shed.CanQuery = true
	end
end

function Props.lemonade(folder: Folder, ctx: Ctx)
	local base = Ctx.face(ctx, A.Lemonade.X, A.Lemonade.Y, WEST)
	local stand = Kit.place("SwLemonadeStand", base)
	if stand then
		stand.Parent = folder
		local face = meshFace(folder, "SwLemonadeStand", "face", base)
		if face then
			label(surface(face, 60), "LEMONADE", { 0.02, 0.05, 0.96, 0.9 }, 40, Color3.fromRGB(250, 222, 80))
		end
	end
	Ctx.place(ctx, folder, "SwFoldingChair", A.Chair.X, A.Chair.Y, Vector2.new(-1, 0.35).Unit)
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

function Props.barrelBarrow(folder: Folder, ctx: Ctx)
	Ctx.place(ctx, folder, "SwWaterBarrel", A.Barrel.X, A.Barrel.Y, WEST)
	Ctx.place(ctx, folder, "SwWheelbarrow", A.Barrow.X, A.Barrow.Y, Vector2.new(-1, -0.4).Unit)
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
		table.insert(rows, { z = meta[k .. "seat_z"], y = meta[k .. "y"], x0 = meta[k .. "x0"], x1 = meta[k .. "x1"] })
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

function Props.pitGarage(major: Folder, ctx: Ctx)
	local base = Ctx.face(ctx, A.PitGarage.X, A.PitGarage.Y, WEST)
	local garage = Kit.place("SwPitGarage", base)
	if garage then
		garage.CanCollide = true
		garage.CanQuery = true
		garage.Parent = major
		local face = meshFace(major, "SwPitGarage", "face", base)
		if face then
			label(surface(face, 50), "PIT ROW", { 0.02, 0.05, 0.96, 0.9 }, 56)
		end
	end
	-- one bay's door rolled down, the other rolled up (open to the pit lane)
	for k, x in { -4.5, 4.5 } do
		local lift = if k == 1 then 3.6 else 0
		local door = Kit.place("SwRollDoor", base * CFrame.new(x, lift, 4.9))
		if door then
			door.Parent = major
		end
	end
end

function Props.pitProps(folder: Folder, ctx: Ctx)
	Ctx.place(ctx, folder, "SwToolChest", 59.6, 362.6, WEST)
	Ctx.place(ctx, folder, "SwTyreStackTall", 59.4, 377.6, WEST)
	Ctx.place(ctx, folder, "SwTyreStackTall", 60.8, 379.6, WEST)
end

-- Painted pit lanes: white edge lines along both pit lanes (Hub/Layout PitOut / PitIn).
Props.PitOut = {
	Vector2.new(33, 284.187),
	Vector2.new(31, 305.187),
	Vector2.new(51.5, 340.187),
	Vector2.new(51.5, 388.187),
	Vector2.new(40, 403.187),
}
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
				Kit.slab(
					folder,
					Ctx.at(ctx, pa.X, pa.Y, 0.175),
					Ctx.at(ctx, pb.X, pb.Y, 0.175),
					Vector3.yAxis,
					0.35,
					0.03,
					{
						name = "PitLine",
						color = Color3.new(1, 1, 1),
						castShadow = false,
					},
					0.35
				)
			end
		end
	end
end

function Props.mechanic(life: Folder, ctx: Ctx)
	local base = Ctx.face(ctx, 58.4, A.PitGarage.Y, WEST)
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

-- The big screen: the Lineup's names and Lap Pay (PREVIEW fixture rows now; Lane 2 data later).
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
	label(bg, "LINEUP", { 0.04, 0.03, 0.62, 0.18 }, 40, Color3.fromRGB(250, 206, 70))
	label(bg, "PREVIEW", { 0.66, 0.05, 0.3, 0.14 }, 22, Color3.fromRGB(128, 216, 189))
	local list = Instance.new("Frame")
	list.Name = "Rows"
	list.BackgroundTransparency = 1
	list.Position = UDim2.fromScale(0.04, 0.24)
	list.Size = UDim2.fromScale(0.92, 0.72)
	list.Parent = bg
	face:SetAttribute("LineupScreen", true)
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
	local extras = {}
	-- the side faces stand on the envelope's flanks (meta plane_x, normal +-x; centre along the
	-- envelope and up)
	local m = Kit.info("SwBlimp").meta
	for _, key in { "face_left", "face_right" } do
		local px = m[key .. ".plane_x"]
		local face: Part? = nil
		if px then
			local side = if px < 0 then -1 else 1
			local p = base:PointToWorldSpace(
				Vector3.new(px + side * 0.05, m[key .. ".centre.2"] or 0, -(m[key .. ".centre.1"] or 0))
			)
			local normal = base:VectorToWorldSpace(Vector3.new(side, 0, 0))
			face = facePart(major, CFrame.lookAt(p, p + normal), m[key .. ".size.1"] or 9, m[key .. ".size.2"] or 2)
		end
		if face then
			label(surface(face, 30), "CAR HOP", { 0.02, 0.1, 0.96, 0.8 }, 60, Color3.fromRGB(234, 88, 50), CREAM)
			table.insert(extras, face)
		end
	end
	local model = figure(major, "Blimp", "Blimp", blimp, extras, base)
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
