--!strict
-- AMBIENT ACCENTS for the Downtown look-dev studies (Lane 3 preview). Started by the playground
-- bootstrap in Play (client-local; nothing replicates) and safe to start in edit mode too.
-- A few cheap, bounded touches, all off the carriageway:
--   pigeons   up to 8 tiny part birds on the sidewalks; they hop, and flutter away (outward,
--             away from the road) when the camera or the proxy car comes within 22 studs
--   flags     a cloth Beam per flagpole mesh (or 3 look-dev poles), waved with CurveSize
--   steam     one low-rate ParticleEmitter per food-cart mesh (or one proxy cart)
--   birds     a loose flock of 5 circling high over the left midground
--   blimp     optional fictional blimp drifting along the skyline band
--   train     direction C only: the decorative train crosses the elevated rail every ~12 s
--             (one reused model; TweenService drives its pivot)
-- Street-level accents pause when more than 250 studs from the camera. The sky accents (birds,
-- blimp) are distant by design, so they use a 900-stud radius instead. Reduced motion
-- (GuiService.ReducedMotionEnabled or the preview-only LocalPlayer attribute
-- Lane3ReducedMotionOverride) calms everything: pigeons stay put, flags barely move, steam
-- thins, birds glide, the blimp holds still and the train runs slower and less often.
-- No NPC navigation, no traffic AI, no remotes.

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Fixture = require(script.Parent.Fixture)
local Parts = require(script.Parent.Parts)
local Trove = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Trove"))

local Ambient = {}

export type Options = {
	pigeons: number?, -- 0..8 (default 8)
	flags: boolean?,
	steam: boolean?,
	birds: boolean?,
	blimp: boolean?, -- default true
	train: boolean?, -- default: only when the built study is direction C
	railHeight: number?, -- override the train's rail top
}
export type Stats = {
	running: boolean,
	reducedMotion: boolean,
	pigeons: number,
	flags: number,
	steamEmitters: number,
	birds: number,
	blimp: boolean,
	train: string,
	animatedObjects: number,
	parts: number,
	transparentEffects: number,
}

local FOLDER = "Lane3_DowntownAmbient"
local NEAR = 250
local SKY_NEAR = 900
local FLEE_RADIUS = 22
local MAX_PIGEONS = 8

type Pigeon = {
	model: Model,
	parts: { BasePart },
	offsets: { CFrame },
	wings: { BasePart },
	home: CFrame,
	at: CFrame,
	outward: Vector3,
	state: string, -- "idle" | "hop" | "flee" | "away"
	t: number,
	nextHop: number,
	from: CFrame,
	to: CFrame,
}
type Flag = { beam: Beam, centre: Vector3, phase: number }
type Emitter = { emitter: ParticleEmitter, centre: Vector3 }
type Bird = { left: BasePart, right: BasePart, offset: Vector3, phase: number }

local state: {
	trove: any,
	folder: Folder?,
	stats: Stats,
	reduced: boolean,
}? = nil

local function reducedMotion(): boolean
	local player = Players.LocalPlayer
	if player and player:GetAttribute("Lane3ReducedMotionOverride") == true then
		return true
	end
	return GuiService.ReducedMotionEnabled
end

local function builtRoot(): Instance?
	return Workspace:FindFirstChild("Lane3_DowntownLookDev")
end

-- Kit parts whose Mesh attribute matches all `include` and none of `exclude` patterns.
local function findMeshes(include: { string }, exclude: { string }?, limit: number): { BasePart }
	local found = {}
	local root = builtRoot()
	if not root then
		return found
	end
	for _, d in root:GetDescendants() do
		local mesh = d:GetAttribute("Mesh")
		if d:IsA("BasePart") and type(mesh) == "string" and d:GetAttribute("Missing") == nil then
			local l = string.lower(mesh)
			local ok = false
			for _, p in include do
				if string.find(l, p, 1, true) then
					ok = true
				end
			end
			for _, p in exclude or {} do
				if string.find(l, p, 1, true) then
					ok = false
				end
			end
			if ok then
				table.insert(found, d)
				if #found >= limit then
					break
				end
			end
		end
	end
	return found
end

local function focusPoints(): { Vector3 }
	local points = {}
	local camera = Workspace.CurrentCamera
	if camera then
		table.insert(points, camera.CFrame.Position)
	end
	local chase = Workspace:FindFirstChild("Lane3_DowntownChase")
	local car = chase and chase:FindFirstChild("Proxy_Puglet")
	if car and car:IsA("Model") then
		table.insert(points, car:GetPivot().Position)
	end
	return points
end

local function nearest(points: { Vector3 }, at: Vector3): number
	local best = math.huge
	for _, p in points do
		best = math.min(best, (p - at).Magnitude)
	end
	return best
end

-- Pigeons --------------------------------------------------------------------------------------

local PIGEON_SPOTS = { -- (s, d): small groups on both sidewalks, clear of the carriageway
	{ 52, 31 },
	{ 54.5, 33.5 },
	{ 57, 30.5 },
	{ 96, -31 },
	{ 98.5, -33 },
	{ 178, 32 },
	{ 181, 34 },
	{ 212, -32.5 },
}

local function makePigeon(parent: Instance, s: number, d: number, index: number): Pigeon
	local model = Instance.new("Model")
	model.Name = "Pigeon"
	model.Parent = parent
	local grey = Color3.fromRGB(128, 132, 146)
	local partsList: { BasePart } = {}
	local offsets: { CFrame } = {}
	local function add(name: string, size: Vector3, offset: CFrame, colour: Color3, shape: Enum.PartType?): BasePart
		local p = Parts.block(model, name, size, offset, colour, shape)
		p.CastShadow = false
		table.insert(partsList, p)
		table.insert(offsets, offset)
		return p
	end
	add("Body", Vector3.new(0.5, 0.5, 0.5), CFrame.new(0, 0.38, 0), grey, Enum.PartType.Ball)
	add(
		"Chest",
		Vector3.new(0.36, 0.36, 0.36),
		CFrame.new(0, 0.42, -0.2),
		Color3.fromRGB(112, 142, 150),
		Enum.PartType.Ball
	)
	add(
		"Head",
		Vector3.new(0.28, 0.28, 0.28),
		CFrame.new(0, 0.7, -0.3),
		Color3.fromRGB(100, 104, 120),
		Enum.PartType.Ball
	)
	add("Beak", Vector3.new(0.06, 0.06, 0.14), CFrame.new(0, 0.68, -0.48), Color3.fromRGB(232, 180, 120))
	add(
		"Tail",
		Vector3.new(0.26, 0.06, 0.34),
		CFrame.new(0, 0.36, 0.36) * CFrame.Angles(0.3, 0, 0),
		Color3.fromRGB(90, 94, 108)
	)
	local wings = {
		add("WingL", Vector3.new(0.5, 0.05, 0.34), CFrame.new(-0.18, 0.5, 0), Color3.fromRGB(104, 108, 124)),
		add("WingR", Vector3.new(0.5, 0.05, 0.34), CFrame.new(0.18, 0.5, 0), Color3.fromRGB(104, 108, 124)),
	}
	local road = Fixture.frame(s, d, Fixture.CURB_HEIGHT)
	local yaw = (index * 2.39) % (2 * math.pi)
	local home = CFrame.new(road.Position) * CFrame.Angles(0, yaw, 0)
	local outward = road.RightVector * (if d >= 0 then 1 else -1)
	return {
		model = model,
		parts = partsList,
		offsets = offsets,
		wings = wings,
		home = home,
		at = home,
		outward = outward,
		state = "idle",
		t = 0,
		nextHop = 1 + (index % 4) * 0.7,
		from = home,
		to = home,
	}
end

local function posePigeon(p: Pigeon, flap: number)
	local cfs = table.create(#p.parts)
	for i, part in p.parts do
		local offset = p.offsets[i]
		if part == p.wings[1] then
			offset = CFrame.new(-0.18, 0.5, 0) * CFrame.Angles(0, 0, -flap) * CFrame.new(-0.2, 0, 0)
		elseif part == p.wings[2] then
			offset = CFrame.new(0.18, 0.5, 0) * CFrame.Angles(0, 0, flap) * CFrame.new(0.2, 0, 0)
		end
		cfs[i] = p.at * offset
	end
	Workspace:BulkMoveTo(p.parts, cfs, Enum.BulkMoveMode.FireCFrameChanged)
end

local function setPigeonVisible(p: Pigeon, visible: boolean)
	for _, part in p.parts do
		part.Transparency = if visible then 0 else 1
	end
end

local function updatePigeon(p: Pigeon, dt: number, near: number, reduced: boolean)
	p.t += dt
	if p.state == "idle" then
		if near < FLEE_RADIUS and not reduced then
			p.state, p.t = "flee", 0
			p.from = p.at
			local away = p.outward * 26 + Vector3.new(0, 16 + (p.nextHop % 1) * 8, 0)
			p.to = CFrame.lookAt(p.at.Position + away, p.at.Position + away + p.outward)
		elseif not reduced and p.t >= p.nextHop then
			p.state, p.t = "hop", 0
			p.from = p.at
			local jitter = Vector3.new(math.random() - 0.5, 0, math.random() - 0.5) * 1.6
			local target = p.home.Position + jitter
			if Fixture.onCarriageway(target, 1) then
				target = p.home.Position
			end
			p.to = CFrame.new(target) * CFrame.Angles(0, math.random() * 2 * math.pi, 0)
		end
	elseif p.state == "hop" then
		local a = math.min(p.t / 0.32, 1)
		local lift = math.sin(a * math.pi) * 0.45
		p.at = p.from:Lerp(p.to, a) + Vector3.new(0, lift, 0)
		posePigeon(p, lift * 2)
		if a >= 1 then
			p.state, p.t = "idle", 0
			p.nextHop = 1.4 + math.random() * 2.6
		end
		return
	elseif p.state == "flee" then
		local a = math.min(p.t / 2.2, 1)
		local eased = 1 - (1 - a) * (1 - a)
		p.at = p.from:Lerp(p.to, eased)
		posePigeon(p, math.sin(p.t * 28) * 0.9)
		if a >= 1 then
			p.state, p.t = "away", 0
			setPigeonVisible(p, false)
		end
		return
	elseif p.state == "away" then
		if p.t > 8 and near > 45 then
			p.at = p.home
			p.state, p.t = "idle", 0
			setPigeonVisible(p, true)
			posePigeon(p, 0)
		end
		return
	end
	-- idle: a small peck now and then
	local peck = if reduced then 0 else math.max(0, math.sin(p.t * 5)) * 0.12
	local cf = p.at
	p.at = cf * CFrame.Angles(-peck, 0, 0)
	posePigeon(p, 0)
	p.at = cf
end

-- Flags ----------------------------------------------------------------------------------------

local WIND = Vector3.new(1, 0, 0.35).Unit
local FLAG_COLOURS = {
	A = { Color3.fromRGB(255, 128, 110), Color3.fromRGB(255, 222, 120) },
	B = { Color3.fromRGB(40, 150, 150), Color3.fromRGB(255, 240, 214) },
	C = { Color3.fromRGB(70, 170, 235), Color3.fromRGB(250, 252, 255) },
}

local function addFlag(
	trove: any,
	parent: Instance,
	holder: BasePart,
	top: Vector3,
	colours: { Color3 },
	phase: number
): Flag
	local normal = -WIND:Cross(Vector3.yAxis).Unit
	local a0 = Instance.new("Attachment")
	a0.Name = "FlagRoot"
	a0.WorldCFrame = CFrame.fromMatrix(top, normal, Vector3.yAxis)
	a0.Parent = holder
	local a1 = Instance.new("Attachment")
	a1.Name = "FlagTip"
	a1.Parent = holder
	a1.WorldCFrame = CFrame.fromMatrix(top + WIND * 4.5, normal, Vector3.yAxis)
	trove:Add(a0)
	trove:Add(a1)
	local beam = Instance.new("Beam")
	beam.Name = "FlagCloth"
	beam.Attachment0 = a0
	beam.Attachment1 = a1
	beam.FaceCamera = false
	beam.Segments = 12
	beam.Width0 = 2.6
	beam.Width1 = 2.6
	beam.LightInfluence = 1
	beam.Transparency = NumberSequence.new(0)
	beam.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, colours[1]),
		ColorSequenceKeypoint.new(0.49, colours[1]),
		ColorSequenceKeypoint.new(0.51, colours[2]),
		ColorSequenceKeypoint.new(1, colours[2]),
	})
	beam.Parent = parent
	return { beam = beam, centre = top, phase = phase }
end

-- Steam ----------------------------------------------------------------------------------------

local function addSteam(holder: BasePart, at: Vector3): ParticleEmitter
	local attachment = Instance.new("Attachment")
	attachment.Name = "SteamOrigin"
	attachment.Parent = holder
	attachment.WorldPosition = at
	local e = Instance.new("ParticleEmitter")
	e.Name = "CartSteam"
	e.Texture = "rbxasset://textures/particles/smoke_main.dds"
	e.Rate = 3
	e.Lifetime = NumberRange.new(1.8, 2.8)
	e.Speed = NumberRange.new(0.8, 1.6)
	e.SpreadAngle = Vector2.new(12, 12)
	e.Acceleration = Vector3.new(0.3, 0.5, 0)
	e.Rotation = NumberRange.new(0, 360)
	e.RotSpeed = NumberRange.new(-20, 20)
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 1.8) })
	e.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.6),
		NumberSequenceKeypoint.new(0.3, 0.7),
		NumberSequenceKeypoint.new(1, 1),
	})
	e.Color = ColorSequence.new(Color3.fromRGB(255, 252, 246))
	e.LightEmission = 0
	e.LightInfluence = 1
	e.Parent = attachment
	return e
end

local function proxyCart(parent: Instance): BasePart
	local at = Fixture.frame(82, Fixture.HALF_WIDTH + Fixture.CURB_WIDTH + 7, Fixture.CURB_HEIGHT)
		* CFrame.Angles(0, math.pi / 2, 0)
	local model = Instance.new("Model")
	model.Name = "ProxyFoodCart"
	model:SetAttribute("Proxy", "part-built food cart for the steam accent (look-dev)")
	model.Parent = parent
	local body = Parts.block(
		model,
		"CartBody",
		Vector3.new(4.2, 2.4, 2.4),
		at * CFrame.new(0, 1.9, 0),
		Color3.fromRGB(255, 244, 220)
	)
	Parts.block(
		model,
		"CartStripe",
		Vector3.new(4.25, 0.5, 2.45),
		at * CFrame.new(0, 2.4, 0),
		Color3.fromRGB(255, 138, 31)
	)
	for _, x in { -1.4, 1.4 } do
		Parts.block(
			model,
			"CartWheel",
			Vector3.new(0.3, 1.2, 1.2),
			at * CFrame.new(x, 0.6, 1.25) * CFrame.Angles(0, math.pi / 2, 0),
			Color3.fromRGB(44, 48, 58),
			Enum.PartType.Cylinder
		)
	end
	Parts.block(
		model,
		"UmbrellaPole",
		Vector3.new(0.2, 4, 0.2),
		at * CFrame.new(1.6, 5, 0),
		Color3.fromRGB(96, 102, 116)
	)
	Parts.disc(model, "Umbrella", 5, 0.3, at * CFrame.new(1.6, 7, 0), Color3.fromRGB(63, 182, 216)).CastShadow = true
	return body
end

-- Birds and blimp ------------------------------------------------------------------------------

local FLOCK_CENTRE = Fixture.point(180, -110, 95)
local FLOCK_RADIUS = 70

local function makeBirds(parent: Instance): { Bird }
	local birds = {}
	local colour = Color3.fromRGB(70, 76, 92)
	for i = 1, 5 do
		local left = Parts.block(parent, "BirdWing", Vector3.new(1.4, 0.1, 0.5), CFrame.new(FLOCK_CENTRE), colour)
		local right = Parts.block(parent, "BirdWing", Vector3.new(1.4, 0.1, 0.5), CFrame.new(FLOCK_CENTRE), colour)
		left.CastShadow, right.CastShadow = false, false
		local row = math.ceil((i - 1) / 2)
		local side = if i % 2 == 0 then 1 else -1
		table.insert(birds, {
			left = left,
			right = right,
			offset = Vector3.new(side * row * 3.2, (i % 3) * 1.2, row * 3.6),
			phase = i * 0.7,
		})
	end
	return birds
end

local function makeBlimp(parent: Instance): Model
	local m = Instance.new("Model")
	m.Name = "Blimp"
	m:SetAttribute("Proxy", "fictional blimp (look-dev ambient)")
	m.Parent = parent
	local hull = Color3.fromRGB(250, 246, 236)
	local band = Color3.fromRGB(30, 42, 74)
	Parts.block(m, "Hull", Vector3.new(30, 12, 12), CFrame.Angles(0, math.pi / 2, 0), hull, Enum.PartType.Cylinder)
	Parts.block(m, "Nose", Vector3.new(12, 12, 12), CFrame.new(0, 0, -15), hull, Enum.PartType.Ball)
	Parts.block(m, "Tail", Vector3.new(11, 11, 11), CFrame.new(0, 0, 15), hull, Enum.PartType.Ball)
	Parts.block(
		m,
		"Band",
		Vector3.new(2.4, 12.3, 12.3),
		CFrame.new(0, 0, -4) * CFrame.Angles(0, math.pi / 2, 0),
		band,
		Enum.PartType.Cylinder
	)
	Parts.block(m, "Gondola", Vector3.new(3, 2, 7), CFrame.new(0, -6.6, -2), band)
	Parts.block(m, "FinV", Vector3.new(0.4, 6, 4), CFrame.new(0, 5, 19), Color3.fromRGB(255, 138, 31))
	Parts.block(m, "FinH", Vector3.new(10, 0.4, 4), CFrame.new(0, 0, 19), Color3.fromRGB(255, 138, 31))
	m.WorldPivot = CFrame.identity
	return m
end

-- Train ----------------------------------------------------------------------------------------

local function proxyTrain(parent: Instance): Model
	local m = Instance.new("Model")
	m.Name = "ProxyTrain"
	m:SetAttribute("Proxy", "part-built decorative train (look-dev)")
	m.Parent = parent
	local shell = Color3.fromRGB(238, 244, 248)
	local stripe = Color3.fromRGB(63, 182, 216)
	local glass = Color3.fromRGB(44, 62, 88)
	for i = 0, 2 do
		local z = (i - 1) * 17
		Parts.block(m, "TrainCar", Vector3.new(4.6, 4.4, 16), CFrame.new(0, 2.6, z), shell)
		Parts.block(m, "TrainWindows", Vector3.new(4.7, 1.3, 14), CFrame.new(0, 3.2, z), glass)
		Parts.block(m, "TrainStripe", Vector3.new(4.7, 0.5, 15.6), CFrame.new(0, 1.7, z), stripe)
		Parts.block(m, "TrainBogie", Vector3.new(3.6, 0.6, 12), CFrame.new(0, 0.3, z), Color3.fromRGB(60, 64, 74))
	end
	m.WorldPivot = CFrame.identity
	return m
end

-- Start / stop ---------------------------------------------------------------------------------

function Ambient.stop()
	if state then
		state.trove:Destroy()
		state = nil
	end
end

function Ambient.stats(): Stats
	if state then
		return table.clone(state.stats)
	end
	return {
		running = false,
		reducedMotion = reducedMotion(),
		pigeons = 0,
		flags = 0,
		steamEmitters = 0,
		birds = 0,
		blimp = false,
		train = "off",
		animatedObjects = 0,
		parts = 0,
		transparentEffects = 0,
	}
end

function Ambient.start(options: Options?): Stats
	Ambient.stop()
	local opts = options or {}
	local trove = Trove.new()
	local folder = Instance.new("Folder")
	folder.Name = FOLDER
	folder:SetAttribute("Note", "Lane 3 Downtown look-dev ambient accents (preview, local)")
	folder.Parent = Workspace
	trove:Add(folder)
	local root = builtRoot()
	local direction = root and root:GetAttribute("Direction")
	local dir = if type(direction) == "string" then direction else "A"
	local stats: Stats = {
		running = true,
		reducedMotion = reducedMotion(),
		pigeons = 0,
		flags = 0,
		steamEmitters = 0,
		birds = 0,
		blimp = false,
		train = "off",
		animatedObjects = 0,
		parts = 0,
		transparentEffects = 0,
	}
	local current = { trove = trove, folder = folder, stats = stats, reduced = stats.reducedMotion }
	state = current

	-- pigeons
	local pigeons: { Pigeon } = {}
	local count = math.clamp(opts.pigeons or MAX_PIGEONS, 0, MAX_PIGEONS)
	for i = 1, count do
		local spot = PIGEON_SPOTS[i]
		local p = makePigeon(folder, spot[1], spot[2], i)
		posePigeon(p, 0)
		table.insert(pigeons, p)
	end
	stats.pigeons = #pigeons

	-- flags: a cloth on each flagpole mesh, or three look-dev poles at the frontage line
	local flags: { Flag } = {}
	if opts.flags ~= false then
		local colours = FLAG_COLOURS[dir] or FLAG_COLOURS.A
		local poles = findMeshes({ "flagpole", "flag_pole", "flag-pole" }, nil, 6)
		for i, pole in poles do
			local top = pole.Position + Vector3.new(0, pole.Size.Y / 2 - 1.6, 0)
			table.insert(flags, addFlag(trove, folder, pole, top, colours, i * 1.3))
		end
		if #poles == 0 then
			for i, spot in { { 70, 1 }, { 130, -1 }, { 300, 1 } } do
				local base = Fixture.frame(spot[1], spot[2] * (Fixture.FRONTAGE - 0.6), Fixture.CURB_HEIGHT)
				local pole = Parts.block(
					folder,
					"LookDevFlagpole",
					Vector3.new(0.35, 16, 0.35),
					CFrame.new(base.Position + Vector3.new(0, 8, 0)),
					Color3.fromRGB(214, 222, 232)
				)
				table.insert(
					flags,
					addFlag(trove, folder, pole, base.Position + Vector3.new(0, 14.6, 0), colours, i * 1.3)
				)
			end
		end
	end
	stats.flags = #flags

	-- steam
	local emitters: { Emitter } = {}
	if opts.steam ~= false then
		local carts = findMeshes({ "cart" }, nil, 3)
		if #carts == 0 then
			table.insert(carts, proxyCart(folder))
		end
		for _, cart in carts do
			local top = cart.Position + Vector3.new(0, cart.Size.Y / 2 + 0.2, 0)
			table.insert(emitters, { emitter = addSteam(cart, top), centre = top })
		end
		trove:Add(function()
			for _, e in emitters do
				local attachment = e.emitter.Parent
				if attachment then
					attachment:Destroy()
				end
			end
		end)
	end
	stats.steamEmitters = #emitters

	-- birds
	local birds: { Bird } = {}
	if opts.birds ~= false then
		birds = makeBirds(folder)
	end
	stats.birds = #birds

	-- blimp
	local blimp: Model? = nil
	local blimpS = -120
	if opts.blimp ~= false then
		blimp = makeBlimp(folder)
		stats.blimp = true
	end

	-- train (direction C)
	local trainValue: CFrameValue? = nil
	local trainModel: Model? = nil
	local trainPath: { a: CFrame, b: CFrame, centre: Vector3 }? = nil
	local restoreTrain: { { part: BasePart, parent: Instance?, cf: CFrame } } = {}
	if opts.train == true or (opts.train == nil and dir == "C") then
		local rails = findMeshes({ "rail", "viaduct", "trainbridge", "train_bridge" }, { "guardrail", "handrail" }, 8)
		local railTop = opts.railHeight
		local centre = Fixture.point(Fixture.LANDMARK.C.s)
		local axis = Fixture.frame(Fixture.LANDMARK.C.s).RightVector
		local best: BasePart? = nil
		for _, r in rails do
			if not best or (r.Position - centre).Magnitude < (best.Position - centre).Magnitude then
				best = r
			end
		end
		if best then
			local top = best:GetAttribute("RailTop")
			railTop = railTop or (if type(top) == "number" then top else best.Position.Y + best.Size.Y / 2)
			axis = if best.Size.X >= best.Size.Z then best.CFrame.RightVector else best.CFrame.LookVector
			axis = Vector3.new(axis.X, 0, axis.Z).Unit
			centre = Vector3.new(best.Position.X, 0, best.Position.Z)
		end
		railTop = railTop or (Fixture.TRAIN_CLEARANCE + 2)
		-- the layout's own train cars, grouped into one reusable model; else a proxy train
		local cars = findMeshes({ "train" }, { "rail", "station", "bridge", "viaduct", "track" }, 6)
		local model: Model
		if #cars > 0 then
			-- grouped under the study folder (not the ambient folder, which is cleaned first)
			model = Instance.new("Model")
			model.Name = "LayoutTrain"
			model.Parent = root or folder
			local pivot = cars[1].Position
			for _, part in cars do
				table.insert(restoreTrain, { part = part, parent = part.Parent, cf = part.CFrame })
				part.Parent = model
			end
			local at = Vector3.new(pivot.X, railTop :: number, pivot.Z)
			model.WorldPivot = CFrame.lookAt(at, at + axis)
			stats.train = "layout train (" .. #cars .. " parts)"
		else
			model = proxyTrain(folder)
			stats.train = "proxy train"
		end
		local half = 260
		local y = Vector3.new(0, railTop :: number, 0)
		local a = CFrame.lookAt(centre + y - axis * half, centre + y + axis)
		local b = CFrame.lookAt(centre + y + axis * half, centre + y + axis * (half + 1))
		trainPath = { a = a, b = b, centre = centre + y }
		trainModel = model
		local value = Instance.new("CFrameValue")
		value.Value = a - Vector3.new(0, 600, 0) -- parked out of sight between passes
		trainValue = value
		trove:Add(value)
		trove:Connect(value.Changed, function(v: CFrame)
			model:PivotTo(v)
		end)
		model:PivotTo(value.Value)
		trove:Add(function()
			for _, r in restoreTrain do
				r.part.Parent = r.parent
				r.part.CFrame = r.cf
			end
			if model.Name == "LayoutTrain" then
				model:Destroy()
			end
		end)
	end

	-- reduced motion follows the setting live
	local function refreshReduced()
		current.reduced = reducedMotion()
		stats.reducedMotion = current.reduced
		for _, e in emitters do
			e.emitter.Rate = if current.reduced then 1.2 else 3
			e.emitter.Speed = if current.reduced then NumberRange.new(0.4, 0.8) else NumberRange.new(0.8, 1.6)
		end
	end
	trove:Connect(GuiService:GetPropertyChangedSignal("ReducedMotionEnabled"), refreshReduced)
	local player = Players.LocalPlayer
	if player then
		trove:Connect(player:GetAttributeChangedSignal("Lane3ReducedMotionOverride"), refreshReduced)
	end
	refreshReduced()

	-- the train loop: one pass every 12 s (20 s, slower, in reduced motion)
	if trainValue and trainPath and trainModel then
		local value = trainValue
		local path = trainPath
		trove:Add(task.spawn(function()
			while true do
				local reduced = current.reduced
				local speed = if reduced then 38 else 75
				local period = if reduced then 20 else 12
				local duration = (path.a.Position - path.b.Position).Magnitude / speed
				if nearest(focusPoints(), path.centre) <= NEAR then
					value.Value = path.a
					local tween =
						TweenService:Create(value, TweenInfo.new(duration, Enum.EasingStyle.Linear), { Value = path.b })
					tween:Play()
					tween.Completed:Wait()
					value.Value = path.a - Vector3.new(0, 600, 0)
				end
				task.wait(math.max(period - duration, 1))
			end
		end))
	end

	-- one update loop for everything else
	local clock = 0
	local accumulator = 0
	trove:Connect(RunService.Heartbeat, function(dt: number)
		clock += dt
		accumulator += dt
		local reduced = current.reduced
		local points = focusPoints()
		for _, p in pigeons do
			local near = nearest(points, p.at.Position)
			if near <= NEAR or p.state ~= "idle" then
				updatePigeon(p, dt, near, reduced)
			end
		end
		local amp = if reduced then 0.25 else 0.8
		local speed = if reduced then 1 else 2.4
		for _, f in flags do
			if nearest(points, f.centre) <= NEAR then
				f.beam.CurveSize0 = amp * math.sin(clock * speed + f.phase)
				f.beam.CurveSize1 = amp * 1.4 * math.sin(clock * speed + f.phase + 1.6)
			end
		end
		-- steam and sky accents only need a few updates a second
		if accumulator < 0.1 then
			return
		end
		local step = accumulator
		accumulator = 0
		for _, e in emitters do
			e.emitter.Enabled = nearest(points, e.centre) <= NEAR
		end
		if #birds > 0 and nearest(points, FLOCK_CENTRE) <= SKY_NEAR then
			local turn = clock * (if reduced then 0.05 else 0.11)
			local lead = FLOCK_CENTRE + Vector3.new(math.cos(turn), 0, math.sin(turn)) * FLOCK_RADIUS
			local heading = Vector3.new(-math.sin(turn), 0, math.cos(turn))
			local frame = CFrame.lookAt(lead, lead + heading)
			local partsList, cfs = {}, {}
			for _, b in birds do
				local flap = if reduced then 0.12 else 0.12 + math.max(0, math.sin(clock * 9 + b.phase)) * 0.5
				local at = frame * CFrame.new(b.offset)
				table.insert(partsList, b.left)
				table.insert(cfs, at * CFrame.Angles(0, 0, flap) * CFrame.new(-0.7, 0, 0))
				table.insert(partsList, b.right)
				table.insert(cfs, at * CFrame.Angles(0, 0, -flap) * CFrame.new(0.7, 0, 0))
			end
			Workspace:BulkMoveTo(partsList, cfs, Enum.BulkMoveMode.FireCFrameChanged)
		end
		if blimp then
			if not reduced then
				blimpS += step * 4
				if blimpS > 520 then
					blimpS = -160
				end
			end
			local at = Fixture.frame(blimpS, 430, 170)
			blimp:PivotTo(at)
		end
	end)

	-- counts
	local partCount = 0
	for _, d in folder:GetDescendants() do
		if d:IsA("BasePart") then
			partCount += 1
		end
	end
	stats.parts = partCount
	stats.transparentEffects = #flags + #emitters
	stats.animatedObjects = #pigeons
		+ #flags
		+ #emitters
		+ #birds
		+ (if blimp then 1 else 0)
		+ (if trainModel then 1 else 0)
	return table.clone(stats)
end

return Ambient
