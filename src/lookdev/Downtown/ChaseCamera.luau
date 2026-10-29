--!strict
-- Scripted CHASE PASS for the Downtown look-dev recordings (Lane 3 preview). Not the run camera
-- (Brian R owns that): a fixed, repeatable camera so the three studies are judged identically.
-- Works in Studio edit mode (moves the Studio camera; pair with screen captures) and in Play on
-- the client (scriptable camera). Rules, matching D1's assets/downtown/kit/fixture.py so Studio
-- frames line up with the Blender renders:
--   car   Puglet-size proxy (12.47 x 5.66 x 4.71) in lane 2 (d -6.25), front toward -Z
--   eye   12 studs behind the car along the lane, 6 above the car's centre
--   look  the lane point 20 ahead of the car at y 1.5 (about 12 degrees down), FOV 70
--   pass  50 studs/s along the lane from s 0 to s 360 (7.2 s)
--   frames  s 30, 115, 200, 262; pedestrian frames on the right sidewalk (eye 5 up) at s 60
--           looking 40 degrees forward-left, and at s 250 looking at the landmark
-- The proxy is labelled (name, attribute, a small rear plate); it stands in for finished cars,
-- which Brian L owns.

local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Fixture = require(script.Parent.Fixture)
local Parts = require(script.Parent.Parts)

local ChaseCamera = {}

ChaseCamera.FOLDER = "Lane3_DowntownChase"
local CAR_NAME = "Proxy_Puglet"
local LANE_D = Fixture.laneCentre(Fixture.CAR_LANE)
local CAR_CENTRE_Y = Fixture.CAR_SIZE.Y / 2
local BEHIND, ABOVE, AHEAD, LOOK_Y, FOV = 12, 6, 20, 1.5, 70
local PED_D = Fixture.HALF_WIDTH + Fixture.CURB_WIDTH + 6 -- middle of the right sidewalk
local PED_Y = Fixture.CURB_HEIGHT + 5
local POP_BLUE = Color3.fromRGB(38, 132, 255)

export type FrameResult = { s: number, label: string, car: CFrame, camera: CFrame }
export type Sample = {
	mode: string,
	seconds: number,
	frames: number,
	meanMs: number,
	p95Ms: number,
	maxMs: number,
	over33ms: number,
	meanFps: number,
	note: string,
}
export type PassOptions = {
	from: number?,
	to: number?,
	speed: number?,
	duration: number?, -- loop the pass until this many seconds have passed
	async: boolean?,
	onFrame: ((dt: number) -> ())?,
}

local running = false
local cancel = false

local function folder(): Folder
	local existing = Workspace:FindFirstChild(ChaseCamera.FOLDER)
	if existing and existing:IsA("Folder") then
		return existing
	end
	local f = Instance.new("Folder")
	f.Name = ChaseCamera.FOLDER
	f:SetAttribute("Note", "Lane 3 Downtown look-dev chase rig (preview)")
	f.Parent = Workspace
	return f
end

local function buildCar(parent: Instance): Model
	local m = Instance.new("Model")
	m.Name = CAR_NAME
	m:SetAttribute("Proxy", "Puglet-size part-built scale proxy (12.47 x 5.66 x 4.71), not a finished car")
	local size = Fixture.CAR_SIZE
	local W, H, L = size.X, size.Y, size.Z
	local wheelR = 1.15
	local bodyBottom, bodyTop = 0.75, 2.95
	local body = Parts.block(
		m,
		"Body",
		Vector3.new(W, bodyTop - bodyBottom, L),
		CFrame.new(0, (bodyBottom + bodyTop) / 2, 0),
		POP_BLUE
	)
	Parts.block(
		m,
		"Glass",
		Vector3.new(W * 0.84, H - bodyTop - 0.3, L * 0.48),
		CFrame.new(0, bodyTop + (H - bodyTop - 0.3) / 2, L * 0.06),
		Color3.fromRGB(44, 62, 88)
	)
	Parts.block(
		m,
		"Roof",
		Vector3.new(W * 0.86, 0.3, L * 0.46),
		CFrame.new(0, H - 0.15, L * 0.07),
		POP_BLUE:Lerp(Color3.new(1, 1, 1), 0.12)
	)
	for _, x in { -1, 1 } do
		for _, z in { -1, 1 } do
			Parts.block(
				m,
				"Wheel",
				Vector3.new(0.9, wheelR * 2, wheelR * 2),
				CFrame.new(x * (W / 2 - 0.35), wheelR, z * (L / 2 - 2.3)),
				Color3.fromRGB(34, 36, 44),
				Enum.PartType.Cylinder
			)
		end
		Parts.block(
			m,
			"Headlight",
			Vector3.new(1.1, 0.5, 0.1),
			CFrame.new(x * (W / 2 - 0.9), 2.2, -L / 2 - 0.03),
			Color3.fromRGB(255, 244, 220)
		)
		Parts.block(
			m,
			"Taillight",
			Vector3.new(1.0, 0.45, 0.1),
			CFrame.new(x * (W / 2 - 0.85), 2.3, L / 2 + 0.03),
			Color3.fromRGB(240, 110, 96)
		)
	end
	local plate = Parts.block(
		m,
		"ProxyPlate",
		Vector3.new(2.0, 0.6, 0.05),
		CFrame.new(0, 1.6, L / 2 + 0.05),
		Color3.fromRGB(255, 244, 220)
	)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Back
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 60
	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.TextScaled = true
	text.TextColor3 = Color3.fromRGB(30, 42, 74)
	text.FontFace = Font.fromName("FredokaOne")
	text.Text = "PROXY"
	text.Parent = gui
	gui.Parent = plate
	m.PrimaryPart = body
	m.WorldPivot = CFrame.identity -- ground centre
	m.Parent = parent
	return m
end

-- The proxy car (built once, reused).
function ChaseCamera.car(): Model
	local f = folder()
	local existing = f:FindFirstChild(CAR_NAME)
	if existing and existing:IsA("Model") then
		return existing
	end
	return buildCar(f)
end

function ChaseCamera.carCFrame(s: number): CFrame
	return Fixture.frame(s, LANE_D)
end

function ChaseCamera.cameraCFrame(s: number): CFrame
	local eye = Fixture.point(s - BEHIND, LANE_D, CAR_CENTRE_Y + ABOVE)
	local target = Fixture.point(s + AHEAD, LANE_D, LOOK_Y)
	return CFrame.lookAt(eye, target)
end

local function saveCamera(camera: Camera)
	local f = folder()
	if f:GetAttribute("SavedCamera") == nil then
		f:SetAttribute("SavedCamera", camera.CFrame)
		f:SetAttribute("SavedFov", camera.FieldOfView)
		f:SetAttribute("SavedType", camera.CameraType.Name)
	end
end

local function applyCamera(cf: CFrame)
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end
	saveCamera(camera)
	camera.CameraType = Enum.CameraType.Scriptable
	camera.FieldOfView = FOV
	camera.CFrame = cf
	camera.Focus = cf * CFrame.new(0, 0, -AHEAD)
end

local function place(s: number)
	ChaseCamera.car():PivotTo(ChaseCamera.carCFrame(s))
	applyCamera(ChaseCamera.cameraCFrame(s))
end

-- Car and camera at a comparison frame (any s works; the fixture frames are 30, 115, 200, 262).
function ChaseCamera.frame(s: number): FrameResult
	place(s)
	return {
		s = s,
		label = Fixture.FRAME_LABELS[s] or "custom",
		car = ChaseCamera.carCFrame(s),
		camera = ChaseCamera.cameraCFrame(s),
	}
end

local function landmarkTarget(): Vector3
	local root = Workspace:FindFirstChild("Lane3_DowntownLookDev")
	if root then
		local lo, hi = Vector3.one * math.huge, -Vector3.one * math.huge
		local found = false
		for _, d in root:GetDescendants() do
			if d:IsA("BasePart") and d:GetAttribute("Landmark") == true then
				local half = d.Size / 2
				lo = lo:Min(d.Position - half)
				hi = hi:Max(d.Position + half)
				found = true
			end
		end
		if found then
			return (lo + hi) / 2
		end
	end
	local direction = root and root:GetAttribute("Direction")
	local anchors = Fixture.LANDMARK :: any
	local anchor = anchors[if type(direction) == "string" then direction else "A"] or anchors.A
	if direction == "C" then
		return Fixture.point(anchor.s, 0, Fixture.TRAIN_CLEARANCE + 2)
	end
	return Fixture.point(anchor.s, anchor.side * (Fixture.FRONTAGE + 12), 22)
end

-- Pedestrian frame 1 (s 60, forward-left) or 2 (s 250, the landmark). The proxy car is parked
-- at s 30 so it does not block the view.
function ChaseCamera.pedestrian(n: number): FrameResult
	local s = if n == 2 then 250 else 60
	local eye = Fixture.point(s, PED_D, PED_Y)
	local target: Vector3
	if n == 2 then
		target = landmarkTarget()
	else
		local road = Fixture.frame(s)
		local a = math.rad(40)
		local dir = road.LookVector * math.cos(a) - road.RightVector * math.sin(a)
		target = eye + dir * 60 + Vector3.new(0, 6, 0)
	end
	ChaseCamera.car():PivotTo(ChaseCamera.carCFrame(30))
	local cf = CFrame.lookAt(eye, target)
	applyCamera(cf)
	return { s = s, label = "pedestrian " .. tostring(n), car = ChaseCamera.carCFrame(30), camera = cf }
end

-- Puts the camera back the way it was before the first frame or pass.
function ChaseCamera.restore()
	local f = Workspace:FindFirstChild(ChaseCamera.FOLDER)
	local camera = Workspace.CurrentCamera
	if not (f and camera) then
		return
	end
	local saved = f:GetAttribute("SavedCamera")
	if typeof(saved) == "CFrame" then
		local typeName = f:GetAttribute("SavedType")
		local ok, cameraType = pcall(function()
			return (Enum.CameraType :: any)[typeName]
		end)
		camera.CameraType = if ok and cameraType then cameraType else Enum.CameraType.Custom
		camera.FieldOfView = (f:GetAttribute("SavedFov") :: number?) or 70
		camera.CFrame = saved
	end
	f:SetAttribute("SavedCamera", nil)
	f:SetAttribute("SavedFov", nil)
	f:SetAttribute("SavedType", nil)
end

function ChaseCamera.stop()
	cancel = true
end

function ChaseCamera.isRunning(): boolean
	return running
end

local function runPass(options: PassOptions)
	local from = options.from or 0
	local to = options.to or Fixture.LENGTH
	local speed = options.speed or Fixture.SPEED
	local duration = options.duration
	local onFrame = options.onFrame
	local s = from
	local elapsed = 0
	local done = false
	local finished = Instance.new("BindableEvent")
	local function step(dt: number)
		if done then
			return
		end
		elapsed += dt
		s += speed * dt
		if s > to then
			if duration and elapsed < duration then
				s = from + (s - to)
			else
				s = to
				done = true
			end
		end
		if duration and elapsed >= duration then
			done = true
		end
		if cancel then
			done = true
		end
		local ok, err = pcall(function()
			place(s)
			if onFrame then
				onFrame(dt)
			end
		end)
		if not ok then
			warn("[Lane3 Downtown] chase step failed: " .. tostring(err))
			done = true
		end
		if done then
			finished:Fire()
		end
	end
	place(from)
	local connection: RBXScriptConnection? = nil
	local bindName = "Lane3DowntownChase"
	local client = RunService:IsRunning() and RunService:IsClient()
	if client then
		RunService:BindToRenderStep(bindName, Enum.RenderPriority.Camera.Value + 1, step)
	else
		connection = RunService.Heartbeat:Connect(step)
	end
	finished.Event:Wait()
	if client then
		RunService:UnbindFromRenderStep(bindName)
	elseif connection then
		connection:Disconnect()
	end
	finished:Destroy()
end

-- Drives the proxy along lane 2 with the chase camera. Yields until done unless async.
function ChaseCamera.pass(options: PassOptions?)
	assert(not running, "a chase pass is already running")
	local opts = options or {}
	running = true
	cancel = false
	local function go()
		local ok, err = pcall(runPass, opts)
		running = false
		if not ok then
			warn("[Lane3 Downtown] chase pass failed: " .. tostring(err))
		end
	end
	if opts.async then
		task.spawn(go)
	else
		go()
	end
end

-- Records frame times during a chase pass (looping the 0..360 pass until `seconds`). In Play on
-- the client the times are RenderStepped deltas; in edit mode they are Heartbeat deltas of the
-- Studio edit session and are labelled as such (not a Play measurement).
function ChaseCamera.sample(seconds: number?): Sample
	local duration = seconds or (Fixture.LENGTH / Fixture.SPEED)
	local times: { number } = {}
	ChaseCamera.pass({
		duration = duration,
		onFrame = function(dt: number)
			table.insert(times, dt)
		end,
	})
	-- the first delta includes the setup work; drop it
	if #times > 1 then
		table.remove(times, 1)
	end
	local n = #times
	local sum, max, over = 0, 0, 0
	for _, dt in times do
		sum += dt
		max = math.max(max, dt)
		if dt > 1 / 30 then
			over += 1
		end
	end
	local sorted = table.clone(times)
	table.sort(sorted)
	local p95 = if n > 0 then sorted[math.clamp(math.ceil(n * 0.95), 1, n)] else 0
	local mean = if n > 0 then sum / n else 0
	local play = RunService:IsRunning() and RunService:IsClient()
	local function ms(x: number): number
		return math.floor(x * 100000 + 0.5) / 100
	end
	local result: Sample = {
		mode = if play then "play-client (RenderStepped)" else "studio-edit (Heartbeat)",
		seconds = duration,
		frames = n,
		meanMs = ms(mean),
		p95Ms = ms(p95),
		maxMs = ms(max),
		over33ms = over,
		meanFps = if mean > 0 then math.floor(10 / mean + 0.5) / 10 else 0,
		note = if play
			then "Play client frame times on this machine; check the kit meshes are visible (EditableMesh previews are session-only and are expected to be blank in Play unless uploaded ids were used)"
			else "Studio edit-mode timing on this machine; not a Play or device measurement",
	}
	print("[Lane3LookDev] sample " .. HttpService:JSONEncode(result))
	return result
end

return ChaseCamera
