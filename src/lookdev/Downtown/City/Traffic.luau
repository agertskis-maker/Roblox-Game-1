--!strict
-- PROXY TRAFFIC for the Downtown B city preview (Lane 3). A handful of labelled proxy cars
-- moving at constant speeds in their lanes, for scale only: presentation, not traffic
-- behaviour (no lane changes, no avoidance, no physics; Brian R owns traffic). The cars stay
-- out of the chase lane, are slower than the chase so they are overtaken, and are recycled
-- ahead when they fall behind (a fixed pool; nothing accumulates). Each has a subtle exhaust
-- puff that thins under reduced motion and stops when far from the camera.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Cars = require(script.Parent.Cars)
local Route = require(script.Parent.Route)
local Sequencer = require(script.Parent.Sequencer)
local Util = require(script.Parent.Util)
local Trove = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Trove"))

local Traffic = {}
Traffic.__index = Traffic

Traffic.DEFAULT_COUNT = 6
Traffic.ROSTER = { "fishbowl", "rev6", "waffle", "rangy", "hurrikan", "zoomurai", "hyperion", "puglet" }

export type Options = {
	parent: Instance,
	plan: Sequencer.Plan,
	getStation: () -> number,
	count: number?, -- default 6, max 12
	lanes: { number }?, -- default every lane except the chase lane
	chaseLane: number?, -- default 2
	exhaust: boolean?, -- default true
}

export type Stats = {
	cars: number,
	exhaustEmitters: number,
	emittersOn: number,
	reducedMotion: boolean,
	recycled: number,
}

type CarState = {
	model: Model,
	car: Cars.Car,
	lane: number,
	s: number,
	speed: number,
	emitter: ParticleEmitter?,
}

type Fields = {
	plan: Sequencer.Plan,
	folder: Folder,
	trove: any,
	cars: { CarState },
	rng: Random,
	getStation: () -> number,
	reduced: boolean,
	recycled: number,
}

export type Traffic = typeof(setmetatable({} :: Fields, Traffic))

local function laneCentre(plan: Sequencer.Plan, lane: number): number
	return -plan.lanes * plan.laneWidth / 2 + plan.laneWidth * (lane - 0.5)
end

local function addExhaust(model: Model, car: Cars.Car): ParticleEmitter?
	local body = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")
	if not body then
		return nil
	end
	local attachment = Instance.new("Attachment")
	attachment.Name = "Exhaust"
	attachment.Parent = body
	attachment.WorldCFrame = model:GetPivot()
		* CFrame.new(car.width * 0.25, 0.9, car.length / 2 + 0.2)
		* CFrame.Angles(0, math.pi, 0)
	local e = Instance.new("ParticleEmitter")
	e.Name = "ExhaustPuff"
	e.Texture = "rbxasset://textures/particles/smoke_main.dds"
	e.EmissionDirection = Enum.NormalId.Back
	e.Rate = 3
	e.Lifetime = NumberRange.new(0.5, 0.9)
	e.Speed = NumberRange.new(1, 2)
	e.SpreadAngle = Vector2.new(10, 10)
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.25), NumberSequenceKeypoint.new(1, 0.8) })
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.72), NumberSequenceKeypoint.new(1, 1) })
	e.Color = ColorSequence.new(Color3.fromRGB(236, 236, 240))
	e.LightInfluence = 1
	e.Parent = attachment
	return e
end

function Traffic.new(options: Options): Traffic
	local plan = options.plan
	local trove = Trove.new()
	local folder = Instance.new("Folder")
	folder.Name = "ProxyTraffic"
	folder:SetAttribute("Note", "PROXY traffic for scale (presentation only, not traffic behaviour)")
	folder.Parent = options.parent
	trove:Add(folder)
	local chaseLane = options.chaseLane or 2
	local lanes = options.lanes
	if not lanes then
		local list = {}
		for lane = 1, plan.lanes do
			if lane ~= chaseLane then
				table.insert(list, lane)
			end
		end
		lanes = list
	end
	local rng = Random.new(plan.seed + 17)
	local self: Fields = {
		plan = plan,
		folder = folder,
		trove = trove,
		cars = {},
		rng = rng,
		getStation = options.getStation,
		reduced = Util.reducedMotion(),
		recycled = 0,
	}
	local obj = setmetatable(self, Traffic)
	local count = math.clamp(options.count or Traffic.DEFAULT_COUNT, 0, 12)
	local station = options.getStation()
	local laneList = lanes :: { number }
	for i = 1, count do
		local car = Cars.byId(Traffic.ROSTER[(i - 1) % #Traffic.ROSTER + 1])
		local model = Cars.build(car)
		model.Parent = folder
		local state: CarState = {
			model = model,
			car = car,
			lane = laneList[(i - 1) % #laneList + 1],
			s = station + 40 + (i - 1) * 75 + rng:NextNumber(0, 20),
			speed = rng:NextNumber(46, 60),
			emitter = if options.exhaust ~= false then addExhaust(model, car) else nil,
		}
		table.insert(self.cars, state)
	end
	local function refresh()
		self.reduced = Util.reducedMotion()
		for _, c in self.cars do
			if c.emitter then
				c.emitter.Rate = if self.reduced then 1 else 3
			end
		end
	end
	for _, signal in Util.reducedMotionSignals() do
		trove:Connect(signal, refresh)
	end
	refresh()
	obj:place()
	return obj
end

-- A free station in `lane` near `want` (keeps a body gap of at least 14 studs).
local function freeStation(self: Traffic, c: CarState, want: number): number
	for attempt = 0, 6 do
		local s = want + attempt * 30
		local ok = true
		for _, other in self.cars do
			if other ~= c and other.lane == c.lane then
				if math.abs(other.s - s) < (other.car.length + c.car.length) / 2 + 14 then
					ok = false
				end
			end
		end
		if ok then
			return s
		end
	end
	return want + 240
end

function Traffic.place(self: Traffic)
	local segments = self.plan.segments
	for _, c in self.cars do
		c.model:PivotTo(Route.frame(segments, c.s, laneCentre(self.plan, c.lane)))
	end
end

function Traffic.step(self: Traffic, dt: number)
	local station = self.getStation()
	local camera = Workspace.CurrentCamera
	local eye = if camera then camera.CFrame.Position else nil
	for _, c in self.cars do
		c.s += c.speed * dt
		if c.s < station - 120 or c.s > station + 900 then
			-- recycled ahead of the camera, out of the near view
			c.s = freeStation(self, c, station + self.rng:NextNumber(380, 560))
			self.recycled += 1
		end
		if c.emitter and eye then
			c.emitter.Enabled = (c.model:GetPivot().Position - eye).Magnitude < 140
		end
	end
	self:place()
end

function Traffic.start(self: Traffic)
	self.trove:Connect(RunService.Heartbeat, function(dt: number)
		if self.folder.Parent then
			self:step(dt)
		end
	end)
end

function Traffic.stats(self: Traffic): Stats
	local emitters, on = 0, 0
	for _, c in self.cars do
		if c.emitter then
			emitters += 1
			if c.emitter.Enabled then
				on += 1
			end
		end
	end
	return {
		cars = #self.cars,
		exhaustEmitters = emitters,
		emittersOn = on,
		reducedMotion = self.reduced,
		recycled = self.recycled,
	}
end

function Traffic.destroy(self: Traffic)
	self.trove:Destroy()
	table.clear(self.cars)
end

return Traffic
