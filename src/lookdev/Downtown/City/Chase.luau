--!strict
-- Private deterministic CHASE HARNESS for the Downtown B city (Lane 3 preview). Not the run
-- camera (Brian R owns that) and no steering: a Puglet-size proxy follows a lane of the planned
-- route at a fixed fixture speed, the camera follows it with a labelled composition, and every
-- step moves the Assembler's active window.
--
-- Cameras (both FIXTURE values, labelled on screen, never shipped):
--   FIXTURE  12 behind, 6 above the car's centre, looking 20 ahead at y 1.5, FOV 70
--            (the overnight fixture camera)
--   HIGH     alternative composition: 18 behind, 10 up, looking 24 ahead, FOV 75
-- Speed 70 studs/s by default. Distance is shown in studs and in PROVISIONAL metres
-- (1 stud = 0.28 m from the cars README; studs and game metres are never equated).
-- Edit mode: Heartbeat drives the Studio camera. Play (client): a RenderStep binding.

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Cars = require(script.Parent.Cars)
local Route = require(script.Parent.Route)
local Sequencer = require(script.Parent.Sequencer)
local Util = require(script.Parent.Util)
local Trove = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Trove"))

local Chase = {}
Chase.__index = Chase

export type CameraSpec = {
	name: string,
	behind: number,
	up: number,
	look: number,
	lookY: number,
	fov: number,
	note: string,
}

Chase.CAMERAS = table.freeze({
	FIXTURE = table.freeze({
		name = "FIXTURE",
		behind = 12,
		up = 6,
		look = 20,
		lookY = 1.5,
		fov = 70,
		note = "fixture camera (preview, not the run camera)",
	}),
	HIGH = table.freeze({
		name = "HIGH",
		behind = 18,
		up = 10,
		look = 24,
		lookY = 1.5,
		fov = 75,
		note = "alternative composition, higher and wider (preview)",
	}),
})
Chase.DEFAULT_SPEED = 70
Chase.DEFAULT_LANE = 2

export type Options = {
	plan: Sequencer.Plan,
	parent: Instance,
	setStation: (number) -> (), -- moves the active window (the Assembler)
	speed: number?,
	lane: number?,
	camera: string?, -- "FIXTURE" (default) or "HIGH"
	loop: boolean?, -- restart at s 0 at the route end (default true)
	label: boolean?, -- on-screen review label (default true)
	controlCamera: boolean?, -- default true; false keeps the caller's camera (HUD playground)
}

export type Stats = {
	running: boolean,
	paused: boolean,
	station: number,
	distanceStuds: number,
	distanceMetresProvisional: number,
	speed: number,
	camera: string,
	laps: number,
	district: string,
}

type Fields = {
	plan: Sequencer.Plan,
	folder: Folder,
	setStationFn: (number) -> (),
	speed: number,
	laneD: number,
	camera: CameraSpec,
	loop: boolean,
	controlCamera: boolean,
	car: Model,
	carCentreY: number,
	station: number,
	travelled: number,
	laps: number,
	running: boolean,
	paused: boolean,
	runTrove: any,
	trove: any,
	gui: ScreenGui?,
	labelText: TextLabel?,
	labelClock: number,
	saved: { cf: CFrame, fov: number, kind: Enum.CameraType }?,
	onFrame: ((dt: number, station: number) -> ())?,
	finished: BindableEvent?,
}

export type Chase = typeof(setmetatable({} :: Fields, Chase))

local function laneCentre(plan: Sequencer.Plan, lane: number): number
	return -plan.lanes * plan.laneWidth / 2 + plan.laneWidth * (lane - 0.5)
end

function Chase.new(options: Options): Chase
	local plan = options.plan
	local trove = Trove.new()
	local folder = Instance.new("Folder")
	folder.Name = "ChaseRig"
	folder:SetAttribute("Note", "Lane 3 Downtown city chase harness (preview; not the run camera)")
	folder.Parent = options.parent
	trove:Add(folder)
	local puglet = Cars.byId("puglet")
	local car = Cars.build(puglet)
	car.Name = "PROXY_ChaseCar_Puglet"
	car.Parent = folder
	local self: Fields = {
		plan = plan,
		folder = folder,
		setStationFn = options.setStation,
		speed = options.speed or Chase.DEFAULT_SPEED,
		laneD = laneCentre(plan, math.clamp(options.lane or Chase.DEFAULT_LANE, 1, plan.lanes)),
		camera = (Chase.CAMERAS :: any)[options.camera or "FIXTURE"] or Chase.CAMERAS.FIXTURE,
		loop = options.loop ~= false,
		controlCamera = options.controlCamera ~= false,
		car = car,
		carCentreY = puglet.height / 2,
		station = 0,
		travelled = 0,
		laps = 0,
		running = false,
		paused = false,
		runTrove = trove:Extend(),
		trove = trove,
		gui = nil,
		labelText = nil,
		labelClock = 0,
		saved = nil,
		onFrame = nil,
		finished = nil,
	}
	local obj = setmetatable(self, Chase)
	if options.label ~= false then
		local parent = Util.guiParent()
		if parent then
			local old = parent:FindFirstChild("Lane3_CityChaseLabel")
			if old then
				old:Destroy()
			end
			local gui = Instance.new("ScreenGui")
			gui.Name = "Lane3_CityChaseLabel"
			gui.ResetOnSpawn = false
			gui.IgnoreGuiInset = false
			gui.DisplayOrder = 50
			local label = Instance.new("TextLabel")
			label.Name = "Readout"
			label.AnchorPoint = Vector2.new(0, 1)
			label.Position = UDim2.new(0, 12, 1, -12)
			label.Size = UDim2.fromOffset(620, 74)
			label.BackgroundColor3 = Color3.fromRGB(30, 42, 74)
			label.BackgroundTransparency = 0.25
			label.TextColor3 = Color3.fromRGB(255, 244, 220)
			label.TextXAlignment = Enum.TextXAlignment.Left
			label.TextYAlignment = Enum.TextYAlignment.Top
			label.TextSize = 16
			label.Font = Enum.Font.GothamMedium
			label.TextWrapped = true
			label.Text = ""
			local pad = Instance.new("UIPadding")
			pad.PaddingLeft = UDim.new(0, 8)
			pad.PaddingTop = UDim.new(0, 6)
			pad.Parent = label
			label.Parent = gui
			local ok = pcall(function()
				gui.Parent = parent
			end)
			if ok then
				trove:Add(gui)
				self.gui = gui
				self.labelText = label
			else
				gui:Destroy() -- no writable GUI container here; the readout stays in stats()
			end
		end
	end
	trove:Add(function()
		obj:restoreCamera()
	end)
	obj:place(0)
	return obj
end

function Chase.districtAt(self: Chase, s: number): Sequencer.DistrictSpan?
	for _, d in self.plan.districts do
		if s >= d.startS and s < d.endS then
			return d
		end
	end
	return self.plan.districts[#self.plan.districts]
end

local function updateLabel(self: Chase)
	local label = self.labelText
	if not label then
		return
	end
	local c = self.camera
	local d = self:districtAt(self.station)
	label.Text = string.format(
		"%s CAMERA (preview): %d behind, %d up, look %d ahead, FOV %d, %d studs/s\n"
			.. "Distance %s studs  (about %s m PROVISIONAL, 1 stud = 0.28 m)  station %s\n"
			.. "%s%s  seed %d%s",
		c.name,
		c.behind,
		c.up,
		c.look,
		c.fov,
		math.floor(self.speed + 0.5),
		Util.commas(self.travelled),
		Util.commas(self.travelled * Sequencer.STUDS_TO_METRES),
		Util.commas(self.station),
		if d then d.name else "?",
		if d then string.format(" (cycle %d)", d.cycle) else "",
		self.plan.seed,
		if self.paused then "  PAUSED" else ""
	)
end

function Chase.saveCamera(self: Chase)
	local camera = Workspace.CurrentCamera
	if camera and not self.saved then
		self.saved = { cf = camera.CFrame, fov = camera.FieldOfView, kind = camera.CameraType }
	end
end

function Chase.restoreCamera(self: Chase)
	local camera = Workspace.CurrentCamera
	local saved = self.saved
	if camera and saved then
		camera.CameraType = saved.kind
		camera.FieldOfView = saved.fov
		camera.CFrame = saved.cf
	end
	self.saved = nil
end

function Chase.cameraCFrame(self: Chase, s: number): CFrame
	local c = self.camera
	local segments = self.plan.segments
	local eye = Route.point(segments, s - c.behind, self.laneD, self.carCentreY + c.up)
	local target = Route.point(segments, s + c.look, self.laneD, c.lookY)
	return CFrame.lookAt(eye, target)
end

-- Car (and camera) at route distance s; also moves the active window.
function Chase.place(self: Chase, s: number)
	self.station = s
	self.setStationFn(s)
	self.car:PivotTo(Route.frame(self.plan.segments, s, self.laneD))
	if self.controlCamera then
		local camera = Workspace.CurrentCamera
		if camera then
			self:saveCamera()
			camera.CameraType = Enum.CameraType.Scriptable
			camera.FieldOfView = self.camera.fov
			local cf = self:cameraCFrame(s)
			camera.CFrame = cf
			camera.Focus = cf * CFrame.new(0, 0, -self.camera.look)
		end
	end
	updateLabel(self)
end

function Chase.setCamera(self: Chase, name: string)
	self.camera = (Chase.CAMERAS :: any)[name] or Chase.CAMERAS.FIXTURE
	self:place(self.station)
end

function Chase.carPosition(self: Chase): Vector3
	return self.car:GetPivot().Position
end

function Chase.isRunning(self: Chase): boolean
	return self.running
end

function Chase.pause(self: Chase)
	self.paused = true
	updateLabel(self)
end

function Chase.resume(self: Chase)
	self.paused = false
end

function Chase.stop(self: Chase)
	if not self.running then
		return
	end
	self.running = false
	self.runTrove:Clean()
	local finished = self.finished
	self.finished = nil
	if finished then
		finished:Fire()
		finished:Destroy()
	end
end

export type RunOptions = {
	seconds: number?, -- stop after this long (default: run until stop())
	from: number?, -- start station (default: where the car is)
	async: boolean?, -- default true: return immediately
	onFrame: ((dt: number, station: number) -> ())?, -- sampling hook
}

-- Starts the chase. With async = false it yields until it ends.
function Chase.run(self: Chase, options: RunOptions?)
	local opts = options or {}
	if self.running then
		self:stop()
	end
	self.running = true
	self.paused = false
	self.onFrame = opts.onFrame
	local elapsed = 0
	local limit = opts.seconds
	local length = self.plan.length
	self:place(opts.from or self.station)
	local finished = Instance.new("BindableEvent")
	self.finished = finished
	local function step(dt: number)
		if not self.running then
			return
		end
		if not self.folder.Parent then
			self:stop()
			return
		end
		elapsed += dt
		if not self.paused then
			local s = self.station + self.speed * dt
			self.travelled += self.speed * dt
			if s > length - 20 then
				if self.loop then
					s = 0
					self.laps += 1
				else
					s = length - 20
					self:stop()
				end
			end
			self:place(s)
		end
		local hook = self.onFrame
		if hook then
			hook(dt, self.station)
		end
		if limit and elapsed >= limit then
			self:stop()
		end
	end
	if RunService:IsRunning() and RunService:IsClient() then
		self.runTrove:BindToRenderStep("Lane3CityChase", Enum.RenderPriority.Camera.Value + 1, step)
	else
		self.runTrove:Connect(RunService.Heartbeat, step)
	end
	if opts.async == false then
		if self.running then
			finished.Event:Wait()
		end
	end
end

-- Runs for `seconds` and returns frame-time statistics (yields).
function Chase.sample(self: Chase, seconds: number?): Util.Sample
	local duration = seconds or 20
	local times: { number } = {}
	self:run({
		seconds = duration,
		async = false,
		onFrame = function(dt: number)
			table.insert(times, dt)
		end,
	})
	if #times > 1 then
		table.remove(times, 1) -- the first delta includes setup work
	end
	local result = Util.summarise(times, duration)
	print("[Lane3City] sample " .. HttpService:JSONEncode(result))
	return result
end

function Chase.stats(self: Chase): Stats
	local d = self:districtAt(self.station)
	return {
		running = self.running,
		paused = self.paused,
		station = Util.round(self.station),
		distanceStuds = Util.round(self.travelled),
		distanceMetresProvisional = Util.round(self.travelled * Sequencer.STUDS_TO_METRES),
		speed = self.speed,
		camera = self.camera.name,
		laps = self.laps,
		district = if d then d.name else "?",
	}
end

function Chase.destroy(self: Chase)
	self:stop()
	self.trove:Destroy()
end

return Chase
