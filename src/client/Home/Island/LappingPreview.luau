--!strict
-- DEVELOPMENT PREVIEW ONLY (Lane 3). Not part of the game, and not Lineup code.
--
-- Performance test for the island: plain placeholder blocks lap Speedways along the plot
-- path markers, the way Lineup cars were proposed to run. Each block is anchored and moved
-- by CFrame on this client only (one loop, BulkMoveTo, no physics, nothing replicated).
-- Plots farther than activeRadius from the camera are paused. Nothing runs unless someone
-- calls start() during a Studio playtest of the private island place, client side:
--
--   local Lap = require(game.Players.LocalPlayer.PlayerScripts.Client.Home.Island.LappingPreview)
--   Lap.start({ carsPerPlot = 15 })
--   print(Lap.measure(10))   -- frame time and memory over 10 seconds
--   Lap.stop()

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Stats = game:GetService("Stats")

local Trove = require(ReplicatedStorage.Packages.Trove)

local LappingPreview = {}

export type Options = {
	carsPerPlot: number?,
	plots: { number }?,
	activeRadius: number?,
	lapSeconds: number?,
}

type Lane = {
	center: Vector3,
	points: { Vector3 },
	length: number,
	spacing: number,
	parts: { BasePart },
	offsets: { number },
}

local FOLDER_NAME = "Lane3_LappingPreview"
local CAR_SIZE = Vector3.new(5.7, 4.7, 12.5)

local trove: any = nil
local lanes: { Lane } = {}
local frameTimes: { number } = {}
local recording = false
local activeLanes = 0

local function previewPlots(): Folder
	local root = workspace:FindFirstChild("Lane3_IslandPreview")
	assert(root, "The island preview is not in this place")
	local island = root:FindFirstChild("Island")
	assert(island, "Island model missing")
	return island:FindFirstChild("Plots") :: Folder
end

local function readLane(plot: Model): (Vector3, { Vector3 }, number)
	local markers = plot:FindFirstChild("Markers") :: BasePart
	local speedway = markers:FindFirstChild("Speedway") :: Attachment
	local count = speedway:GetAttribute("PathSampleCount") :: number
	local points = {}
	for i = 1, count do
		points[i] = (markers:FindFirstChild(string.format("Path%03d", i)) :: Attachment).WorldPosition
	end
	local center = Vector3.zero
	for _, p in points do
		center += p
	end
	return center / count, points, speedway:GetAttribute("PathLength") :: number
end

function LappingPreview.start(options: Options?)
	assert(RunService:IsStudio() and RunService:IsClient(), "Studio playtest, client side only")
	LappingPreview.stop()
	local o: Options = options or {}
	local carsPerPlot = o.carsPerPlot or 15
	local activeRadius = o.activeRadius or 260
	local lapSeconds = o.lapSeconds or 15
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
	lanes = {}
	for _, index in chosen :: { number } do
		local plot = plotsFolder:FindFirstChild(string.format("Plot%02d", index)) :: Model
		local center, points, length = readLane(plot)
		local lane: Lane =
			{ center = center, points = points, length = length, spacing = length / #points, parts = {}, offsets = {} }
		for k = 1, carsPerPlot do
			local p = Instance.new("Part")
			p.Name = string.format("Block_%02d_%02d", index, k)
			p.Anchored = true
			p.CanCollide = false
			p.CanQuery = false
			p.CanTouch = false
			p.Size = CAR_SIZE
			p.Color = Color3.fromRGB(255, 138, 31)
			p.Material = Enum.Material.SmoothPlastic
			p.Parent = folder
			table.insert(lane.parts, p)
			table.insert(lane.offsets, (k - 1) * length / carsPerPlot)
		end
		table.insert(lanes, lane)
	end
	folder.Parent = workspace

	local started = os.clock()
	local speedOf = function(lane: Lane): number
		return lane.length / lapSeconds
	end
	local parts: { BasePart } = {}
	local cframes: { CFrame } = {}
	trove:Connect(RunService.RenderStepped, function(dt: number)
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
			if (lane.center - eye).Magnitude <= activeRadius then
				activeLanes += 1
				local n = #lane.points
				for k, part in lane.parts do
					local s = (lane.offsets[k] + t * speedOf(lane)) % lane.length
					local f = s / lane.spacing
					local i = math.floor(f)
					local a = lane.points[i % n + 1]
					local b = lane.points[(i + 1) % n + 1]
					local pos = a:Lerp(b, f - i) + Vector3.new(0, CAR_SIZE.Y / 2, 0)
					table.insert(parts, part)
					table.insert(cframes, CFrame.lookAt(pos, pos + (b - a)))
				end
			end
		end
		workspace:BulkMoveTo(parts, cframes, Enum.BulkMoveMode.FireCFrameChanged)
	end)
end

-- Records frame times for `seconds` and returns frame rate, frame time and client memory.
function LappingPreview.measure(seconds: number): { [string]: any }
	table.clear(frameTimes)
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
	return {
		seconds = seconds,
		frames = n,
		averageFps = math.round(n / sum * 10) / 10,
		averageFrameMs = ms(sum / n),
		p95FrameMs = ms(sorted[math.max(1, math.ceil(n * 0.95))]),
		worstFrameMs = ms(sorted[n]),
		blocks = blocks,
		lanes = #lanes,
		activeLanes = activeLanes,
		clientMemoryMb = math.round(Stats:GetTotalMemoryUsageMb()),
		instancesMb = math.round(Stats:GetMemoryUsageMbForTag(Enum.DeveloperMemoryTag.Instances) * 10) / 10,
		graphicsPartsMb = math.round(Stats:GetMemoryUsageMbForTag(Enum.DeveloperMemoryTag.GraphicsParts) * 10) / 10,
	}
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
