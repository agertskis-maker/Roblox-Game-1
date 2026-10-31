--!strict
-- DEVELOPMENT PREVIEW ONLY (Lane 3). Not part of the game, and not Lineup code.
--
-- Preview Lineup cars on the plots' Speedways: placeholder preview cars (the SwPreviewCar fixture
-- mesh, or plain blocks) lap each plot along its current look level's lap path (Shared.Island
-- .Speedway.Path: flat oval, banked turns, the raised far turn, the hump and the loop), the way
-- Lineup cars were proposed to run. Every car keeps a lap phase, so a lap takes `lapSeconds` at
-- every level: a longer path only means a faster visual car, and a level change keeps each car's
-- place in the lap. Each car is anchored and moved by CFrame on this client only (one loop,
-- BulkMoveTo, no physics, no collision, nothing replicated). Plots farther than activeRadius from
-- the camera are paused.
--
-- Finish crossings come from the same clock (a car crosses when its phase wraps), never from a
-- collision: LappingPreview.Crossed fires (plot, car, rarity, at) for the flag official, the
-- crowd and the Lap Pay cue. This is a FIXTURE: production Lap Pay is a server timer (Lane 2),
-- and its event would drive these cues instead.
--
--   local Lap = require(game.Players.LocalPlayer.PlayerScripts.Client.Home.Island.LappingPreview)
--   Lap.start({ carsPerPlot = 15 })
--   print(Lap.measure(10))   -- frame time and memory over 10 seconds
--   print(Lap.timing(32))    -- lap cycle and crossing timing per plot
--   Lap.stop()

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Stats = game:GetService("Stats")

local Signal = require(ReplicatedStorage.Packages.Signal)
local Trove = require(ReplicatedStorage.Packages.Trove)

local Speedway = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Island"):WaitForChild("Speedway")
local Kit = require(Speedway:WaitForChild("Kit"))
local Path = require(Speedway:WaitForChild("Path"))

local LappingPreview = {}

export type Options = {
	carsPerPlot: number?,
	plots: { number }?,
	activeRadius: number?,
	lapSeconds: number?,
	-- Optional fixed view for measuring and recording; the camera is restored on stop().
	camera: CFrame?,
	-- plain blocks instead of the preview car mesh (the original performance test)
	blocks: boolean?,
}

-- the preview rarity fixture, by car slot (Tunable; no real cars or rarities are read)
LappingPreview.Rarities = { "Common", "Rare", "Common", "Epic", "Common", "Legendary", "Common", "Rare" }
local TINT = {
	Common = Color3.fromRGB(110, 170, 230),
	Rare = Color3.fromRGB(90, 200, 120),
	Epic = Color3.fromRGB(170, 110, 230),
	Legendary = Color3.fromRGB(250, 190, 60),
}

type Lane = {
	plot: Model,
	index: number,
	frame: CFrame,
	centre: Vector3,
	parts: { BasePart },
	offsets: { CFrame },
	phases: { number },
	rarities: { string },
	lastF: { number },
	dust: { ParticleEmitter },
	level: number,
}

local FOLDER_NAME = "Lane3_LappingPreview"
local CAR_SIZE = Vector3.new(5.7, 4.7, 12.5)

LappingPreview.Crossed = Signal.new() :: Signal.Signal<Model, number, string, number>

local trove: any = nil
local lanes: { Lane } = {}
local frameTimes: { number } = {}
local loopTimes: { number } = {}
local recording = false
local activeLanes = 0
local lapSeconds = 15
local started = 0

local function previewPlots(): Folder
	local root = workspace:FindFirstChild("Lane3_IslandPreview")
	assert(root, "The island preview is not in this place")
	local island = root:FindFirstChild("Island")
	assert(island, "Island model missing")
	return island:FindFirstChild("Plots") :: Folder
end

-- The path the cars follow: SpeedwayPathLevel (set by SpeedwayLooks once a level-up reveal has
-- built the new road), else the assembled look level.
local function levelOf(plot: Model): number
	local l = plot:GetAttribute("SpeedwayPathLevel")
	if type(l) ~= "number" then
		l = plot:GetAttribute("SpeedwayLookLevel")
	end
	return if type(l) == "number" then l else 4
end

local function dustEmitter(part: BasePart): ParticleEmitter
	local a = Instance.new("Attachment")
	a.Name = "Dust"
	a.Position = Vector3.new(0, -part.Size.Y / 2 + 0.3, part.Size.Z / 2 - 0.5)
	a.Parent = part
	local e = Instance.new("ParticleEmitter")
	e.Color = ColorSequence.new(Color3.fromRGB(214, 170, 120))
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.45), NumberSequenceKeypoint.new(1, 1) })
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.8), NumberSequenceKeypoint.new(1, 2.4) })
	e.Lifetime = NumberRange.new(0.6, 0.9)
	e.Rate = 7
	e.Speed = NumberRange.new(0.5, 1.5)
	e.SpreadAngle = Vector2.new(25, 25)
	e.Acceleration = Vector3.new(0, 1, 0)
	e.LightInfluence = 1
	e.LockedToPart = false
	e.Enabled = false
	e.Parent = a
	return e
end

function LappingPreview.start(options: Options?)
	assert(RunService:IsStudio() and RunService:IsClient(), "Studio playtest, client side only")
	LappingPreview.stop()
	local o: Options = options or {}
	local carsPerPlot = o.carsPerPlot or 15
	local activeRadius = o.activeRadius or 260
	lapSeconds = o.lapSeconds or 15
	trove = Trove.new()
	local folder = trove:Add(Instance.new("Folder"))
	folder.Name = FOLDER_NAME
	local plotsFolder = previewPlots()
	local chosen = o.plots
	if not chosen then
		chosen = {}
		for i = 1, #plotsFolder:GetChildren() do
			table.insert(chosen, i)
		end
	end
	local template = if o.blocks then nil else Kit.template("SwPreviewCar")
	lanes = {}
	for _, index in chosen :: { number } do
		local plot = plotsFolder:FindFirstChild(string.format("Plot%02d", index)) :: Model
		local bearing = plot:GetAttribute("BearingDeg") :: number
		local frame = Path.plotFrame(bearing)
		local lane: Lane = {
			plot = plot,
			index = index,
			frame = frame,
			centre = frame * Vector3.new(0, 0, -441),
			parts = {},
			offsets = {},
			phases = {},
			rarities = {},
			lastF = {},
			dust = {},
			level = levelOf(plot),
		}
		for k = 1, carsPerPlot do
			local rarity = LappingPreview.Rarities[(k - 1) % #LappingPreview.Rarities + 1]
			local p: BasePart
			local offset = CFrame.new(0, CAR_SIZE.Y / 2, 0)
			if template then
				-- the car's offset from its ground point (Kit.place puts the mesh origin at the
				-- base; the nose, recipe -y, is the base's +Z, so the base looks backward)
				local car = Kit.place("SwPreviewCar", CFrame.identity) :: MeshPart
				offset = car.CFrame
				car.Color = TINT[rarity]
				p = car
			else
				local block = Instance.new("Part")
				block.Size = CAR_SIZE
				block.Color = TINT[rarity]
				block.Material = Enum.Material.SmoothPlastic
				p = block
			end
			p.Name = string.format("PreviewCar_%02d_%02d", index, k)
			p.Anchored = true
			p.CanCollide = false
			p.CanQuery = false
			p.CanTouch = false
			p:SetAttribute("Rarity", rarity)
			p:SetAttribute("PreviewFixture", "Lineup car placeholder (Lane 2 supplies the real cars)")
			p.Parent = folder
			table.insert(lane.parts, p)
			table.insert(lane.offsets, offset)
			-- staggered so payouts arrive at different moments (outline 08)
			table.insert(lane.phases, (k - 1) / carsPerPlot)
			table.insert(lane.rarities, rarity)
			table.insert(lane.lastF, -1)
			table.insert(lane.dust, dustEmitter(p))
		end
		table.insert(lanes, lane)
	end
	folder.Parent = workspace

	local view = o.camera
	local currentCamera = workspace.CurrentCamera
	if view and currentCamera then
		local previousType = currentCamera.CameraType
		currentCamera.CameraType = Enum.CameraType.Scriptable
		currentCamera.CFrame = view
		trove:Add(function()
			currentCamera.CameraType = previousType
		end)
	end

	started = os.clock()
	local parts: { BasePart } = {}
	local cframes: { CFrame } = {}
	trove:Connect(RunService.RenderStepped, function(dt: number)
		local loopStarted = os.clock()
		if recording then
			table.insert(frameTimes, dt)
		end
		local camera = workspace.CurrentCamera
		local eye = if camera then camera.CFrame.Position else Vector3.zero
		local t = os.clock() - started
		table.clear(parts)
		table.clear(cframes)
		activeLanes = 0
		for _, lane in lanes do
			local level = levelOf(lane.plot)
			local path = Path.forLevel(level)
			local dusty = level <= 3
			if level ~= lane.level then
				lane.level = level
			end
			local active = (lane.centre - eye).Magnitude <= activeRadius
			if active then
				activeLanes += 1
			end
			for k, part in lane.parts do
				local f = (t / lapSeconds + lane.phases[k]) % 1
				-- a wrap of the lap phase is a finish crossing (same clock as the visual)
				if lane.lastF[k] >= 0 and f < lane.lastF[k] then
					LappingPreview.Crossed:Fire(lane.plot, k, lane.rarities[k], os.clock())
				end
				lane.lastF[k] = f
				lane.dust[k].Enabled = active and dusty
				if active then
					local pos, look, up = Path.sample(path, f * path.length)
					local wp = lane.frame * pos
					local base =
						CFrame.lookAt(wp, wp - lane.frame:VectorToWorldSpace(look), lane.frame:VectorToWorldSpace(up))
					table.insert(parts, part)
					table.insert(cframes, base * lane.offsets[k])
				end
			end
		end
		workspace:BulkMoveTo(parts, cframes, Enum.BulkMoveMode.FireCFrameChanged)
		if recording then
			table.insert(loopTimes, os.clock() - loopStarted)
		end
	end)
end

-- The lap phase (0..1) of car k on plot `index` now, and the clock it is measured on.
function LappingPreview.phase(index: number, k: number): number?
	for _, lane in lanes do
		if lane.index == index then
			local p = lane.phases[k]
			if p then
				return ((os.clock() - started) / lapSeconds + p) % 1
			end
		end
	end
	return nil
end

-- Records frame times for `seconds` and returns frame rate, frame time, the lapping loop's
-- own cost per frame (frame rate alone hides headroom under Studio's 60 fps cap) and memory.
function LappingPreview.measure(seconds: number): { [string]: any }
	table.clear(frameTimes)
	table.clear(loopTimes)
	recording = true
	task.wait(seconds)
	recording = false
	local n = #frameTimes
	if n == 0 then
		return { frames = 0 }
	end
	local sorted = table.clone(frameTimes)
	table.sort(sorted)
	local sum = 0
	for _, dt in frameTimes do
		sum += dt
	end
	local function ms(v: number): number
		return math.round(v * 10000) / 10
	end
	local blocks = 0
	for _, lane in lanes do
		blocks += #lane.parts
	end
	local loopSorted = table.clone(loopTimes)
	table.sort(loopSorted)
	local loopSum = 0
	for _, t in loopTimes do
		loopSum += t
	end
	local loops = math.max(1, #loopTimes)
	return {
		seconds = seconds,
		frames = n,
		averageFps = math.round(n / sum * 10) / 10,
		averageFrameMs = ms(sum / n),
		p95FrameMs = ms(sorted[math.max(1, math.ceil(n * 0.95))]),
		worstFrameMs = ms(sorted[n]),
		loopAverageMs = math.round(loopSum / loops * 100000) / 100,
		loopP95Ms = math.round((loopSorted[math.max(1, math.ceil(#loopSorted * 0.95))] or 0) * 100000) / 100,
		blocks = blocks,
		lanes = #lanes,
		activeLanes = activeLanes,
		clientMemoryMb = math.round(Stats:GetTotalMemoryUsageMb()),
		instancesMb = math.round(Stats:GetMemoryUsageMbForTag(Enum.DeveloperMemoryTag.Instances) * 10) / 10,
		graphicsPartsMb = math.round(Stats:GetMemoryUsageMbForTag(Enum.DeveloperMemoryTag.GraphicsParts) * 10) / 10,
	}
end

-- Lap timing over `seconds` (Studio, desktop): per plot, the measured time between successive
-- finish crossings of each car (from the Crossed events, by os.clock), and the car's distance past
-- the finish line in the frame the crossing fired (the visible crossing-to-cue offset, as studs and
-- milliseconds at the level's visual speed). Method: the cue and the crossing come from one clock;
-- the offset is at most one frame of travel.
function LappingPreview.timing(seconds: number): { [string]: any }
	local last: { [string]: number } = {}
	local cycles: { [number]: { number } } = {}
	local offsets: { [number]: { number } } = {}
	local connection = LappingPreview.Crossed:Connect(function(plot: Model, k: number)
		local index = plot:GetAttribute("PlotIndex") :: number
		local now = os.clock()
		local key = index .. ":" .. k
		if last[key] then
			cycles[index] = cycles[index] or {}
			table.insert(cycles[index], now - last[key])
		end
		last[key] = now
		local phase = LappingPreview.phase(index, k)
		if phase then
			local path = Path.forLevel(levelOf(plot))
			-- distance past the line (the phase has just wrapped)
			local past = (if phase > 0.5 then phase - 1 else phase) * path.length
			offsets[index] = offsets[index] or {}
			table.insert(offsets[index], past)
		end
	end)
	task.wait(seconds)
	connection:Disconnect()
	local out = {}
	for _, lane in lanes do
		local c = cycles[lane.index] or {}
		local o = offsets[lane.index] or {}
		local path = Path.forLevel(levelOf(lane.plot))
		local speed = path.length / lapSeconds
		local lo, hi, sum = math.huge, -math.huge, 0
		for _, v in c do
			lo, hi, sum = math.min(lo, v), math.max(hi, v), sum + v
		end
		local olo, ohi = math.huge, -math.huge
		for _, v in o do
			olo, ohi = math.min(olo, v), math.max(ohi, v)
		end
		out[lane.index] = {
			level = levelOf(lane.plot),
			pathLength = math.round(path.length * 10) / 10,
			speed = math.round(speed * 10) / 10,
			cycles = #c,
			cycleMean = if #c > 0 then math.round(sum / #c * 1000) / 1000 else nil,
			cycleMin = if #c > 0 then math.round(lo * 1000) / 1000 else nil,
			cycleMax = if #c > 0 then math.round(hi * 1000) / 1000 else nil,
			crossings = #o,
			offsetStudsMax = if #o > 0 then math.round(ohi * 100) / 100 else nil,
			offsetMsMax = if #o > 0 then math.round(ohi / speed * 10000) / 10 else nil,
			offsetMsMin = if #o > 0 then math.round(olo / speed * 10000) / 10 else nil,
		}
	end
	return out
end

function LappingPreview.running(): boolean
	return trove ~= nil
end

function LappingPreview.stop()
	recording = false
	if trove then
		trove:Destroy()
		trove = nil
	end
	lanes = {}
	activeLanes = 0
end

return LappingPreview
