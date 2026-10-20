--!strict
-- DEVELOPMENT PREVIEW ONLY (Lane 3). Not part of the game.
--
-- Shows the Downtown Common starter car on a neutral, clearly labelled preview
-- fixture so its shape, wheels, colour roles and Heat presentation can be
-- reviewed in Studio. Nothing runs unless someone calls start() during a
-- Studio playtest; outside Studio every entry point returns at once. No
-- driving, steering, Hop, claiming, Heat timing, crash logic, seating or
-- saving: the car only moves along a fixed preview rail, and the Heat stage is
-- chosen by this fixture, standing in for Lane 1.
--
-- The mesh comes from the private test place: the FBX built by
-- assets/vehicles/downtown-starter/build.py is imported (Upload to Roblox off)
-- into ReplicatedStorage.Lane3_VehicleSamples.DowntownStarter. See
-- assets/vehicles/downtown-starter/README.md.
--
-- Start it from the Studio command bar (or MCP) during a playtest, client side:
--   require(game.Players.LocalPlayer.PlayerScripts.Client.Home.CarPreview).start()
--
-- Provisional rig for Brian R's review (Root on the ground under the car's
-- centre; forward -Z, up +Y, right +X; wheels named from the seated driver's
-- point of view; every wheel spins about the Root's X axis through its own
-- axle). The car's Heat emphasis reads the shared AlarmClock phase and peaks
-- with the HUD panel (wave(0)), so it adds no visible peaks of its own.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local AlarmClock = require(script.Parent.Parent.UI.AlarmClock)
local RunHud = require(script.Parent.Parent.UI.RunHud)
local Tokens = require(ReplicatedStorage.Shared.UI.Tokens)
local Trove = require(ReplicatedStorage.Packages.Trove)

type HeatStage = RunHud.HeatStage
type MotionMode = "Follow" | "Reduced" | "Full"
export type CameraMode =
	"Turntable"
	| "SideToRear"
	| "Chase"
	| "Front34"
	| "Rear34"
	| "Side"
	| "Front"
	| "Rear"
	| "Top"
	| "Wheel"
	| "LampsFront"
	| "LampsRear"

local SAMPLE_FOLDER = "Lane3_VehicleSamples"
local MODEL_NAME = "DowntownStarter"
local PREVIEW_NAME = "Lane3_CarPreview"
local HUD_NAME = "Lane3_CarPreviewHud"
local SMOKE_TEXTURE = "rbxasset://textures/particles/smoke_main.dds" -- built into Roblox, nothing uploaded

-- Provisional colour roles (Adam's swatches; tuned under Studio light).
local PALETTE: { [string]: Color3 } = {
	BodyPrimary = Color3.fromHex("#2878E8"),
	BodySecondary = Color3.fromHex("#F2F4F7"),
	Trim = Color3.fromHex("#242A32"),
	Glass = Color3.fromHex("#1B293E"),
	Headlamp = Color3.fromHex("#FFF0CD"),
	Taillamp = Color3.fromHex("#E83D45"),
	Plate = Color3.fromHex("#E9E4D6"),
	Tire = Color3.fromHex("#171B21"),
	WheelMetal = Color3.fromHex("#AAB4C0"),
}

local MATERIALS: { [string]: Enum.Material } = {
	BodyPrimary = Enum.Material.SmoothPlastic,
	BodySecondary = Enum.Material.SmoothPlastic,
	Trim = Enum.Material.SmoothPlastic,
	Glass = Enum.Material.SmoothPlastic, -- opaque: no sorting problems, no empty interior
	Headlamp = Enum.Material.SmoothPlastic,
	Taillamp = Enum.Material.SmoothPlastic,
	Plate = Enum.Material.SmoothPlastic,
	Tire = Enum.Material.SmoothPlastic,
	WheelMetal = Enum.Material.SmoothPlastic,
}

local REFLECTANCE: { [string]: number } = {
	BodyPrimary = 0.06,
	Glass = 0.08,
}

-- Attachment positions relative to Root (studs), measured from the recipe in
-- assets/vehicles/downtown-starter/starter_spec.py. Provisional.
local ANCHORS: { [string]: Vector3 } = {
	SeatAnchor = Vector3.new(-1.0, 1.9, 0.3),
	HeadlightL = Vector3.new(-1.58, 2.18, -6.08),
	HeadlightR = Vector3.new(1.58, 2.18, -6.08),
	HeatSteam = Vector3.new(0, 2.98, -4.6),
	HopRing = Vector3.new(0, 0.05, 0),
	KeysMeter = Vector3.new(0, 6.7, 0),
	TrailL = Vector3.new(-2.2, 1.0, 6.2),
	TrailR = Vector3.new(2.2, 1.0, 6.2),
}

local WHEEL_KEYS = { "FL", "FR", "RL", "RR" }
local DRIVE_SPEED = 45 -- studs per second along the preview rail
local RAIL_LENGTH = 1600

type Wheel = {
	model: Model,
	axle: CFrame, -- relative to Root
	radius: number,
}

type Session = {
	trove: any,
	folder: Folder,
	car: Model,
	root: BasePart,
	body: Model,
	wheels: { [string]: Wheel },
	parts: { [BasePart]: string }, -- part -> colour role
	base: { [string]: Color3 }, -- role -> current base colour (paint swaps change this)
	smoke: ParticleEmitter,
	hud: any?,
	stage: HeatStage,
	heat: number,
	motion: MotionMode,
	cameraMode: CameraMode,
	driving: boolean,
	railZ: number,
	yaw: number,
	clock: number,
	camera: { [string]: any },
}

local CarPreview = {}
local session: Session? = nil

local function samplesFolder(): Folder?
	return ReplicatedStorage:FindFirstChild(SAMPLE_FOLDER) :: Folder?
end

local function removeLeftovers()
	local old = Workspace:FindFirstChild(PREVIEW_NAME)
	if old then
		old:Destroy()
	end
	local player = Players.LocalPlayer
	if player then
		local gui = player:FindFirstChild("PlayerGui")
		local hud = gui and gui:FindFirstChild(HUD_NAME)
		if hud then
			hud:Destroy()
		end
	end
end

local function overrideFor(mode: MotionMode): boolean?
	if mode == "Reduced" then
		return true
	elseif mode == "Full" then
		return false
	end
	return nil
end

local function roleOf(name: string): (string, string?)
	local key, role = string.match(name, "Wheel_(%u%u)_(%a+)$")
	if key and role then
		return role, key
	end
	local plain = string.match(name, "(%a+)$")
	return plain or name, nil
end

local function make(className: string, props: { [string]: any }): any
	local instance = Instance.new(className)
	local parent = props.Parent
	for key, value in props do
		if key ~= "Parent" then
			(instance :: any)[key] = value
		end
	end
	instance.Parent = parent
	return instance
end

local function quiet(part: BasePart)
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.Massless = true
end

-- Neutral fixture: a light ground with faint cross stripes (so motion reads)
-- and a label. Not the Downtown scene.
local function buildFixture(folder: Folder)
	local ground = make("Part", {
		Name = "PreviewGround",
		Size = Vector3.new(400, 1, RAIL_LENGTH + 400),
		CFrame = CFrame.new(0, -0.5, 0),
		Color = Color3.fromRGB(214, 218, 222),
		Material = Enum.Material.SmoothPlastic,
		Parent = folder,
	})
	quiet(ground)
	ground.CanQuery = true
	for z = -RAIL_LENGTH / 2, RAIL_LENGTH / 2, 24 do
		local stripe = make("Part", {
			Name = "Stripe",
			Size = Vector3.new(60, 0.02, 1.2),
			CFrame = CFrame.new(0, 0.01, z),
			Color = Color3.fromRGB(190, 195, 201),
			Material = Enum.Material.SmoothPlastic,
			Parent = folder,
		})
		quiet(stripe)
	end
end

local function buildRig(folder: Folder): (Model, BasePart, Model, { [string]: Wheel }, { [BasePart]: string })
	local samples = samplesFolder()
	local source = samples and samples:FindFirstChild(MODEL_NAME)
	assert(source, "Import the starter into ReplicatedStorage." .. SAMPLE_FOLDER .. "." .. MODEL_NAME .. " first")
	local copy = source:Clone()

	local meshes: { MeshPart } = {}
	for _, d in copy:GetDescendants() do
		if d:IsA("MeshPart") then
			table.insert(meshes, d)
		end
	end
	-- Ground point under the car's centre, from the imported geometry.
	local minV = Vector3.new(math.huge, math.huge, math.huge)
	local maxV = Vector3.new(-math.huge, -math.huge, -math.huge)
	for _, m in meshes do
		local half = m.Size / 2
		minV = minV:Min(m.Position - half)
		maxV = maxV:Max(m.Position + half)
	end
	local centre = (minV + maxV) / 2
	local rootCF = CFrame.new(centre.X, minV.Y, centre.Z)

	local car = make("Model", { Name = MODEL_NAME, Parent = folder })
	local root = make("Part", {
		Name = "Root",
		Size = Vector3.new(1, 0.2, 1),
		CFrame = rootCF,
		Transparency = 1,
		Parent = car,
	})
	quiet(root)
	car.PrimaryPart = root
	local body = make("Model", { Name = "Body", Parent = car })
	local parts: { [BasePart]: string } = {}
	local wheelParts: { [string]: { MeshPart } } = {}
	for _, m in meshes do
		local role, key = roleOf(m.Name)
		quiet(m)
		parts[m] = role
		if key then
			wheelParts[key] = wheelParts[key] or {}
			table.insert(wheelParts[key], m)
		else
			m.Parent = body
		end
	end
	body.WorldPivot = rootCF

	local wheels: { [string]: Wheel } = {}
	for _, key in WHEEL_KEYS do
		local list = wheelParts[key]
		assert(list, "missing wheel " .. key)
		local model = make("Model", { Name = "Wheel_" .. key, Parent = car })
		local axlePos: Vector3? = nil
		local radius = 1
		for _, m in list do
			m.Parent = model
			if parts[m] == "Tire" then
				axlePos = m.Position
				radius = m.Size.Y / 2
			end
		end
		local axleWorld = CFrame.new(axlePos :: Vector3) * (rootCF - rootCF.Position)
		model.WorldPivot = axleWorld
		wheels[key] = { model = model, axle = rootCF:ToObjectSpace(axleWorld), radius = radius }
	end

	-- Attachments (presentation anchors), all on Root.
	for name, pos in ANCHORS do
		local att = Instance.new("Attachment")
		att.Name = name
		att.Position = pos
		att.Parent = root
	end
	for _, key in WHEEL_KEYS do
		local att = Instance.new("Attachment")
		att.Name = "Axle_" .. key
		att.CFrame = wheels[key].axle
		att.Parent = root
	end
	-- One simple invisible proxy for later hop-target queries (provisional).
	local proxy = make("Part", {
		Name = "CollisionProxy",
		Size = Vector3.new(maxV.X - minV.X - 0.2, 3.6, maxV.Z - minV.Z),
		CFrame = rootCF * CFrame.new(0, 2.6, 0),
		Transparency = 1,
		Parent = car,
	})
	quiet(proxy)
	proxy.CanQuery = true
	copy:Destroy()
	return car, root, body, wheels, parts
end

local function applyColours(s: Session, emphasis: number, lampPulse: number)
	local danger = Tokens.Color.Danger
	for part, role in s.parts do
		local base = s.base[role] or PALETTE[role]
		local colour = base
		if role == "BodyPrimary" and emphasis > 0 then
			colour = base:Lerp(danger, emphasis)
		elseif role == "Taillamp" and lampPulse > 0 then
			colour = base:Lerp(Color3.fromRGB(255, 120, 124), lampPulse)
		end
		part.Color = colour
	end
end

local function restoreAppearance(s: Session)
	for part, role in s.parts do
		part.Color = s.base[role] or PALETTE[role]
		part.Material = MATERIALS[role] or Enum.Material.SmoothPlastic
		part.Reflectance = REFLECTANCE[role] or 0
	end
end

local function isReduced(s: Session): boolean
	if s.motion == "Reduced" then
		return true
	elseif s.motion == "Full" then
		return false
	end
	if s.hud then
		return s.hud:isReducedMotion()
	end
	return false
end

local function updateHeat(s: Session)
	local reduced = isReduced(s)
	local wave = if reduced then 0.5 else AlarmClock.wave(0)
	if s.stage == "Critical" then
		applyColours(s, if reduced then 0.16 else 0.06 + 0.14 * wave, if reduced then 0.5 else wave)
	elseif s.stage == "Meltdown" then
		applyColours(s, if reduced then 0.26 else 0.14 + 0.16 * wave, if reduced then 0.7 else wave)
	else
		applyColours(s, 0, 0)
	end
	local smoking = s.stage == "Meltdown" or s.stage == "Critical"
	s.smoke.Enabled = smoking and not reduced
	s.smoke.Rate = if s.stage == "Meltdown" then 9 else 3
end

local function setCamera(s: Session)
	local cam = Workspace.CurrentCamera
	local rootCF = s.root.CFrame
	local focus = rootCF.Position + Vector3.new(0, 1.9, 0)
	local mode = s.cameraMode
	local function look(offset: Vector3, target: Vector3, fov: number)
		cam.FieldOfView = fov
		cam.CFrame = CFrame.lookAt(focus + offset, target)
	end
	if mode == "Turntable" or mode == "Front34" then
		look(Vector3.new(-13, 6.5, -17), focus, 30)
	elseif mode == "Rear34" then
		look(Vector3.new(13, 7, 17), focus, 30)
	elseif mode == "Side" then
		look(Vector3.new(-40, 0.6, 0), focus, 22)
	elseif mode == "Front" then
		look(Vector3.new(0, 0.6, -40), focus, 12)
	elseif mode == "Rear" then
		look(Vector3.new(0, 0.6, 40), focus, 12)
	elseif mode == "Top" then
		cam.FieldOfView = 22
		cam.CFrame = CFrame.lookAt(focus + Vector3.new(0, 42, 0.01), focus)
	elseif mode == "Wheel" then
		look(Vector3.new(-6.5, -0.4, -5.2), rootCF.Position + Vector3.new(-2.4, 1.1, -3.7), 30)
	elseif mode == "LampsFront" then
		look(Vector3.new(-3.8, 1.2, -11), rootCF.Position + Vector3.new(-1.0, 2.0, -6.2), 30)
	elseif mode == "LampsRear" then
		look(Vector3.new(4.2, 1.6, 11), rootCF.Position + Vector3.new(1.0, 2.4, 6.2), 30)
	elseif mode == "SideToRear" then
		-- Slow orbit from the left side round to the rear and back (20 s cycle).
		local t = (math.sin(s.clock * math.pi / 10 - math.pi / 2) + 1) / 2
		local angle = math.rad(-90 + 90 * t)
		local offset = Vector3.new(math.sin(angle) * 16, 4.5, math.cos(angle) * 16)
		look(offset, focus, 30)
	elseif mode == "Chase" then
		-- Representative chase camera (Lane 1 owns the real one): 14 studs
		-- behind the car's centre, 7 above the ground, looking 10 studs ahead.
		cam.FieldOfView = 70
		local eye = rootCF:PointToWorldSpace(Vector3.new(0, 7, 14))
		local target = rootCF:PointToWorldSpace(Vector3.new(0, 1.5, -10))
		cam.CFrame = CFrame.lookAt(eye, target)
	end
end

local function step(s: Session, dt: number)
	s.clock += dt
	local reduced = isReduced(s)
	local speed = 0
	if s.driving then
		speed = DRIVE_SPEED
		s.railZ -= speed * dt
		if s.railZ < -RAIL_LENGTH / 2 + 50 then
			s.railZ = RAIL_LENGTH / 2 - 50
		end
	end
	if s.cameraMode == "Turntable" and not reduced then
		s.yaw += math.rad(15) * dt
		speed = math.max(speed, 6)
	end
	local cf = CFrame.new(0, 0, s.railZ) * CFrame.Angles(0, s.yaw, 0)
	s.root.CFrame = cf
	s.body:PivotTo(cf)
	for _, wheel in s.wheels do
		local spin = -(s.clock * speed) / wheel.radius
		if speed == 0 then
			spin = 0
		end
		wheel.model:PivotTo(cf * wheel.axle * CFrame.Angles(spin, 0, 0))
	end
	updateHeat(s)
	setCamera(s)
end

local function pushHud(s: Session)
	if s.hud then
		s.hud:setState({ cash = 1250, distance = 320, heat = s.heat, stage = s.stage })
	end
end

function CarPreview.start(options: { hud: boolean?, motion: MotionMode?, camera: CameraMode? }?): boolean
	if not RunService:IsStudio() or not RunService:IsRunning() then
		return false
	end
	CarPreview.stop()
	removeLeftovers()
	local opts = options or {}
	local trove = Trove.new()
	local folder = make("Folder", { Name = PREVIEW_NAME, Parent = Workspace })
	trove:Add(folder)
	buildFixture(folder)
	local car, root, body, wheels, parts = buildRig(folder)

	local smoke = Instance.new("ParticleEmitter")
	smoke.Name = "HoodSmoke"
	smoke.Texture = SMOKE_TEXTURE
	smoke.Color = ColorSequence.new(Color3.fromRGB(150, 154, 168), Color3.fromRGB(96, 100, 112))
	smoke.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 2.2) })
	smoke.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.55),
		NumberSequenceKeypoint.new(0.5, 0.7),
		NumberSequenceKeypoint.new(1, 1),
	})
	smoke.Lifetime = NumberRange.new(1.0, 1.6)
	smoke.Speed = NumberRange.new(2.5, 4)
	smoke.SpreadAngle = Vector2.new(12, 12)
	smoke.Acceleration = Vector3.new(0, 0.6, 3) -- drifts back over the car, away from the lane ahead
	smoke.RotSpeed = NumberRange.new(-30, 30)
	smoke.LightInfluence = 0.7
	smoke.Enabled = false
	smoke.Parent = root:FindFirstChild("HeatSteam") :: Attachment

	local cam = Workspace.CurrentCamera
	local s: Session = {
		trove = trove,
		folder = folder,
		car = car,
		root = root,
		body = body,
		wheels = wheels,
		parts = parts,
		base = table.clone(PALETTE),
		smoke = smoke,
		hud = nil,
		stage = "Calm",
		heat = 0.2,
		motion = opts.motion or "Follow",
		cameraMode = opts.camera or "Turntable",
		driving = false,
		railZ = 0,
		yaw = 0,
		clock = 0,
		camera = {
			CameraType = cam.CameraType,
			CFrame = cam.CFrame,
			FieldOfView = cam.FieldOfView,
			CameraSubject = cam.CameraSubject,
		},
	}
	restoreAppearance(s)
	cam.CameraType = Enum.CameraType.Scriptable
	if opts.hud ~= false then
		s.hud = RunHud.new((Players.LocalPlayer :: Player):WaitForChild("PlayerGui"), {
			name = HUD_NAME,
			reducedMotionOverride = overrideFor(s.motion),
		})
		pushHud(s)
	end
	trove:Add(AlarmClock.subscribe(function(dt: number, _phase: number)
		step(s, dt)
	end))
	session = s
	return true
end

function CarPreview.setCamera(mode: CameraMode)
	local s = session
	if s then
		s.cameraMode = mode
		if mode ~= "Turntable" then
			s.yaw = 0
		end
	end
end

function CarPreview.setDriving(on: boolean)
	local s = session
	if s then
		s.driving = on
		s.yaw = 0
		s.railZ = if on then RAIL_LENGTH / 2 - 50 else 0
	end
end

-- Heat stage chosen by this fixture (stands in for Lane 1).
function CarPreview.setHeat(stage: HeatStage)
	local s = session
	if not s then
		return
	end
	s.stage = stage
	s.heat = if stage == "Meltdown"
		then 1
		elseif stage == "Critical" then 0.93
		elseif stage == "Warning" then 0.7
		else 0.2
	pushHud(s)
	if stage ~= "Critical" and stage ~= "Meltdown" then
		s.smoke:Clear()
		restoreAppearance(s)
	end
end

function CarPreview.setMotion(mode: MotionMode)
	local s = session
	if not s then
		return
	end
	s.motion = mode
	if s.hud then
		s.hud:setReducedMotionOverride(overrideFor(mode))
	end
end

-- Temporary paint swap (role BodyPrimary); nil restores the starter's blue.
function CarPreview.setPaint(colour: Color3?)
	local s = session
	if s then
		s.base.BodyPrimary = colour or PALETTE.BodyPrimary
		restoreAppearance(s)
	end
end

function CarPreview.debug(): { [string]: any }
	local s = session
	if not s then
		return { running = false }
	end
	local meshCount, partCount, seats = 0, 0, 0
	for _, d in s.car:GetDescendants() do
		if d:IsA("MeshPart") then
			meshCount += 1
		end
		if d:IsA("BasePart") then
			partCount += 1
		end
		if d:IsA("Seat") or d:IsA("VehicleSeat") then
			seats += 1
		end
	end
	local colliding = 0
	for _, d in s.folder:GetDescendants() do
		if d:IsA("BasePart") and (d.CanCollide or d.CanTouch) then
			colliding += 1
		end
	end
	local colours: { [string]: string } = {}
	for part, role in s.parts do
		colours[role] = part.Color:ToHex()
	end
	local anchors: { [string]: Vector3 } = {}
	for _, a in s.root:GetChildren() do
		if a:IsA("Attachment") then
			anchors[a.Name] = a.Position
		end
	end
	local size = s.car:GetExtentsSize()
	return {
		running = true,
		meshParts = meshCount,
		baseParts = partCount,
		seats = seats,
		collidingOrTouching = colliding,
		stage = s.stage,
		reduced = isReduced(s),
		alarmRate = AlarmClock.getRate(),
		smokeEnabled = s.smoke.Enabled,
		colours = colours,
		anchors = anchors,
		extents = size,
		cameraMode = s.cameraMode,
		hud = s.hud ~= nil,
	}
end

function CarPreview.stop()
	local s = session
	session = nil
	if s then
		local cam = Workspace.CurrentCamera
		s.trove:Destroy()
		if s.hud then
			s.hud:destroy()
		end
		cam.CameraType = s.camera.CameraType
		cam.CFrame = s.camera.CFrame
		cam.FieldOfView = s.camera.FieldOfView
		cam.CameraSubject = s.camera.CameraSubject
	end
	removeLeftovers()
end

return CarPreview
