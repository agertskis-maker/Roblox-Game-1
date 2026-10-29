--!strict
-- PLAYGROUND ONLY (Lane 3 preview). A neutral, independent gameplay backdrop for the HUD
-- prototype: a plain four-lane road with a few proxy cars, a grass lot with dummy Garage, kiosk
-- and portal objects (for prompts and Lap Pay), and a chase camera for run mode. It does not
-- load or alter the island scene. Built on this client only; destroyed with the playground.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Client = Players.LocalPlayer:WaitForChild("PlayerScripts"):WaitForChild("Client")
local Prototype = Client:WaitForChild("UI"):WaitForChild("Prototype")
local Fixtures = require(Prototype:WaitForChild("Fixtures"))
local ProxyCar = require(Prototype:WaitForChild("ProxyCar"))
local Trove = require(ReplicatedStorage.Packages.Trove)

local Backdrop = {}

local ROAD_LENGTH = 1400
local LANE = 12.5

local function part(
	parent: Instance,
	name: string,
	size: Vector3,
	cf: CFrame,
	colour: Color3,
	material: Enum.Material?
): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = colour
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

export type Backdrop = {
	folder: Folder,
	world: Folder,
	homeSpot: CFrame,
	props: { garage: BasePart, kiosk: BasePart, portal: BasePart },
	lapCars: { BasePart },
	traffic: { Model },
	trafficCars: { Fixtures.CarRef },
	ride: Model,
	target: Model,
	setRunCamera: (on: boolean) -> (),
	setPath: (((number, number, number) -> CFrame)?, number?, ((number) -> ())?) -> (),
	setNeutralRoad: (on: boolean) -> (),
	hold: (at: number?) -> (),
	station: () -> number,
	restart: () -> (),
	destroy: () -> (),
}

function Backdrop.build(): Backdrop
	local trove = Trove.new()
	local folder = trove:Add(Instance.new("Folder"))
	folder.Name = "Lane3_HudPlaygroundBackdrop"
	local world = Instance.new("Folder")
	world.Name = "HudWorld"
	world.Parent = folder

	-- ground and road (the road runs along -Z from z = 0)
	part(
		folder,
		"Grass",
		Vector3.new(900, 1, ROAD_LENGTH + 200),
		CFrame.new(0, -0.5, -ROAD_LENGTH / 2),
		Color3.fromRGB(104, 178, 86),
		Enum.Material.Grass
	)
	local roadW = LANE * 4
	part(
		folder,
		"Asphalt",
		Vector3.new(roadW, 0.2, ROAD_LENGTH),
		CFrame.new(0, 0.1, -ROAD_LENGTH / 2),
		Color3.fromRGB(62, 66, 76),
		Enum.Material.Asphalt
	)
	for _, side in { -1, 1 } do
		part(
			folder,
			"EdgeLine",
			Vector3.new(0.6, 0.05, ROAD_LENGTH),
			CFrame.new(side * (roadW / 2 - 0.8), 0.22, -ROAD_LENGTH / 2),
			Color3.new(1, 1, 1)
		)
		part(
			folder,
			"Curb",
			Vector3.new(0.8, 0.6, ROAD_LENGTH),
			CFrame.new(side * (roadW / 2 + 0.4), 0.3, -ROAD_LENGTH / 2),
			Color3.fromRGB(220, 220, 214)
		)
		part(
			folder,
			"Sidewalk",
			Vector3.new(12, 0.5, ROAD_LENGTH),
			CFrame.new(side * (roadW / 2 + 6.8), 0.25, -ROAD_LENGTH / 2),
			Color3.fromRGB(206, 200, 190),
			Enum.Material.Concrete
		)
	end
	for lane = 1, 3 do
		local x = -roadW / 2 + lane * LANE
		for z = 0, ROAD_LENGTH - 20, 20 do
			part(folder, "Dash", Vector3.new(0.5, 0.05, 10), CFrame.new(x, 0.22, -z - 5), Color3.new(1, 1, 1))
		end
	end
	-- simple roadside blocks for depth (neutral backdrop, not a Downtown direction)
	local rng = Random.new(7)
	for z = 40, ROAD_LENGTH, 70 do
		for _, side in { -1, 1 } do
			local h = rng:NextNumber(24, 60)
			part(
				folder,
				"Block",
				Vector3.new(30, h, 50),
				CFrame.new(side * (roadW / 2 + 40), h / 2, -z),
				Color3.fromHSV(rng:NextNumber(0, 1), 0.18, 0.92)
			)
		end
	end

	-- everything so far is the neutral road and blocks: hidden when the Downtown B city is the
	-- backdrop (HUD rebuild V-01: real world backdrops)
	local neutral: { BasePart } = {}
	for _, child in folder:GetChildren() do
		if child:IsA("BasePart") then
			table.insert(neutral, child)
		end
	end
	-- the Home lot: dummy Garage, kiosk and portal beside the start of the road
	local lot = CFrame.new(-120, 0, 40)
	part(
		folder,
		"LotPaving",
		Vector3.new(120, 0.4, 90),
		lot * CFrame.new(0, 0.2, 0),
		Color3.fromRGB(236, 226, 206),
		Enum.Material.Concrete
	)
	local garage = part(
		folder,
		"DummyGarage",
		Vector3.new(36, 20, 4),
		lot * CFrame.new(-30, 10, -30),
		Color3.fromRGB(70, 190, 230)
	)
	local kiosk =
		part(folder, "DummyKiosk", Vector3.new(8, 7, 6), lot * CFrame.new(10, 3.5, -20), Color3.fromRGB(255, 160, 60))
	local portal = part(
		folder,
		"DummyPortal",
		Vector3.new(14, 20, 1),
		lot * CFrame.new(40, 10, -28),
		Color3.fromRGB(186, 92, 255),
		Enum.Material.Neon
	)
	portal.Transparency = 0.3
	for _, p in { garage, kiosk, portal } do
		p:SetAttribute("Dummy", "playground prop for prompt presentation only")
	end
	-- ProxyCar's pivot is its Body part, not the wheels: place the bounding-box bottom on the
	-- surface instead (HUD rebuild fix; cars sat about 2 studs into the road).
	local function seat(m: Model, cf: CFrame)
		m:PivotTo(cf)
		local box, size = m:GetBoundingBox()
		local bottom = box.Position.Y - size.Y / 2
		m:PivotTo(cf + Vector3.new(0, cf.Position.Y - bottom, 0))
	end
	-- local-owned fixture cars parked on the lot (Lap Pay sources)
	local lapCars = {}
	for i = 1, 3 do
		local c = Fixtures.Cars[i]
		local m = ProxyCar.build(c)
		seat(m, lot * CFrame.new(18 + i * 9, 0.4, 14) * CFrame.Angles(0, math.rad(20), 0))
		m.Parent = folder
		table.insert(lapCars, m.PrimaryPart :: BasePart)
	end

	-- traffic for run mode: the ridden car, a Hop target ahead and a few more
	local function carOnRoad(c: Fixtures.CarRef, lane: number, z: number): Model
		local m = ProxyCar.build(c)
		seat(m, CFrame.new(-roadW / 2 + (lane - 0.5) * LANE, 0.2, z))
		m.Parent = folder
		return m
	end
	-- the ridden car is Revolution 6, the car the Keys scenarios capture (the capture is of the car
	-- being ridden); the Hop target ahead is a Puglet
	local ride = carOnRoad(Fixtures.Cars[5], 2, -40)
	local target = carOnRoad(Fixtures.Cars[1], 3, -75)
	local traffic = { ride, target }
	-- the car data for each traffic model, same order (nameplates use "traffic-<index>" ids,
	-- because model names repeat)
	local trafficCars: { Fixtures.CarRef } = { Fixtures.Cars[5], Fixtures.Cars[1] }
	for i, lane in { 1, 4, 2, 3 } do
		local c = Fixtures.Cars[((i + 2) % #Fixtures.Cars) + 1]
		table.insert(traffic, carOnRoad(c, lane, -110 - i * 45))
		table.insert(trafficCars, c)
	end
	for i, m in traffic do
		m:SetAttribute("PreviewInstanceId", "traffic-" .. i)
	end

	folder.Parent = Workspace

	-- run mode: the whole traffic group rolls forward and the camera chases the ridden car
	local runConn: RBXScriptConnection? = nil
	local speed = 55
	local starts: { [Model]: CFrame } = {}
	for _, m in traffic do
		starts[m] = m:GetPivot()
	end
	local travelled = 0
	-- optional path (the Downtown B route): fn(s, x, y) -> CFrame along the road, with its length;
	-- onStation(s) lets the city move its active window with the ridden car
	local path: ((number, number, number) -> CFrame)? = nil
	local pathLength = ROAD_LENGTH
	local onStation: ((number) -> ())? = nil
	-- review captures: hold the traffic at one travelled distance (nil = moving)
	local heldAt: number? = nil
	local function setRunCamera(on: boolean)
		local camera = Workspace.CurrentCamera
		if runConn then
			runConn:Disconnect()
			runConn = nil
		end
		if not on then
			camera.CameraType = Enum.CameraType.Custom
			return
		end
		camera.CameraType = Enum.CameraType.Scriptable
		camera.FieldOfView = 70
		runConn = RunService.RenderStepped:Connect(function(dt)
			-- re-asserted every frame: the default camera can reclaim Custom (seen in Studio captures)
			camera.CameraType = Enum.CameraType.Scriptable
			travelled = if heldAt then heldAt :: number else (travelled + speed * dt) % (pathLength - 300)
			for i, m in traffic do
				local rate = if i <= 2 then 1 else 0.85 + 0.04 * i
				local start = starts[m]
				if path then
					local s = (-start.Position.Z + travelled * rate) % (pathLength - 1)
					m:PivotTo((path :: any)(s, start.Position.X, start.Position.Y))
				else
					m:PivotTo(start * CFrame.new(0, 0, -travelled * rate))
				end
			end
			if onStation then
				(onStation :: any)(-starts[ride].Position.Z + travelled)
			end
			-- FIXTURE chase camera: 12 behind, 6 up, looking 20 ahead (labelled in the review)
			-- heading from the direction of travel (the proxy car's pivot part does not face forward)
			local p = ride:GetPivot().Position
			local look = Vector3.new(0, 0, -1)
			if path then
				local start = starts[ride]
				local s = (-start.Position.Z + travelled) % (pathLength - 1)
				local ahead = (path :: any)(s + 4, start.Position.X, start.Position.Y).Position
				local flat = Vector3.new(ahead.X - p.X, 0, ahead.Z - p.Z)
				if flat.Magnitude > 1e-3 then
					look = flat.Unit
				end
			end
			camera.CFrame = CFrame.lookAt(p - look * 12 + Vector3.new(0, 6, 0), p + look * 20 + Vector3.new(0, 1.5, 0))
		end)
	end
	trove:Add(function()
		setRunCamera(false)
	end)

	local function setPath(fn: ((number, number, number) -> CFrame)?, length: number?, station: ((number) -> ())?)
		path = fn
		pathLength = if fn then math.max(length or ROAD_LENGTH, 400) else ROAD_LENGTH
		onStation = station
		travelled = 0
		if not fn then
			for _, m in traffic do
				m:PivotTo(starts[m])
			end
		end
	end
	-- route distance of the ridden car (studs); restart puts the traffic back at the start
	local function station(): number
		return -starts[ride].Position.Z + travelled
	end
	local function restart()
		travelled = 0
	end
	local function hold(at: number?)
		heldAt = at
		if at then
			travelled = at
		end
	end
	local function setNeutralRoad(on: boolean)
		for _, p in neutral do
			p.Transparency = if on then 0 else 1
			p.CanCollide = on
			p.CanQuery = on
		end
	end

	return {
		folder = folder,
		world = world,
		homeSpot = lot * CFrame.new(0, 3, 42),
		props = { garage = garage, kiosk = kiosk, portal = portal },
		lapCars = lapCars,
		traffic = traffic,
		trafficCars = trafficCars,
		ride = ride,
		target = target,
		setRunCamera = setRunCamera,
		setPath = setPath,
		setNeutralRoad = setNeutralRoad,
		hold = hold,
		station = station,
		restart = restart,
		destroy = function()
			trove:Destroy()
		end,
	}
end

return Backdrop
