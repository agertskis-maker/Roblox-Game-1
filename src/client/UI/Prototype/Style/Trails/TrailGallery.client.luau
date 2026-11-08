--!strict
-- Trails.TrailGallery (Round 8, WS-5a): a Studio-only frame stage for the trail art. It does NOTHING in a real game: it runs only when
-- a Folder named "WS5A_GalleryRequest" exists in Workspace (an agent makes it in Edit mode before pressing Play; no player and no
-- published place has one). Mode attribute on that folder:
--   "trails"   (default) 18 cars in a row, each driving along -Z with its catalog trail on a dark floor; the camera follows the car
--              numbered by the folder's Focus attribute (CamOffset, CamAim, Fov, Speed, Running and Quality are read every frame)
--   "exhausts" all 27 cars in a 9 x 3 grid with a small red marker on each exhaust point of Anchors.Exhausts; Row (1..3) picks the view
-- Everything it makes lives in workspace.WS5A_Stage and goes when the folder does.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local Lighting = game:GetService("Lighting")

local request = workspace:FindFirstChild("WS5A_GalleryRequest")
if not request or not RunService:IsStudio() then
	return
end

local Catalog =
	require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UI"):WaitForChild("CosmeticPreviewCatalog"))
local Exhausts = require(ReplicatedStorage.Shared.Style.Anchors.Exhausts)
local TrailFx = require(script.Parent.Parent.TrailFx)

task.wait(3) -- let the beta's own client scripts finish starting
pcall(function()
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, false)
end)
local player = Players.LocalPlayer
local mode = request:GetAttribute("Mode") or "trails"
local CAR = request:GetAttribute("Car") or "Apex"

local stage = Instance.new("Folder")
stage.Name = "WS5A_Stage"
stage.Parent = workspace
Lighting.ClockTime = if request:GetAttribute("Day") then 14 else 0
Lighting.Ambient = Color3.fromRGB(70, 74, 90)
Lighting.Brightness = 1

local floor = Instance.new("Part")
floor.Name = "Floor"
floor.Anchored = true
floor.Size = Vector3.new(1400, 1, 700)
floor.Position = Vector3.new(500, 499.5, -100)
floor.Color = if request:GetAttribute("Day") then Color3.fromRGB(70, 74, 82) else Color3.fromRGB(8, 9, 14)
floor.Material = Enum.Material.SmoothPlastic
floor.Parent = stage

local function anchorAll(m: Model)
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
		end
	end
end

local cars: { Model } = {}
local fxs: { any } = {}
local items: { any } = {}

if mode == "measure" then
	-- T-11: one car at run speed with each trail in turn, full and phone quality; frame cost from the engine's own Stats
	local Stats = game:GetService("Stats")
	local camera = workspace.CurrentCamera
	camera.CameraType = Enum.CameraType.Scriptable
	local car = ReplicatedStorage.Cars[CAR]:Clone()
	anchorAll(car)
	car.Parent = stage
	local function stat(name: string): number?
		local ok, v = pcall(function()
			return (Stats :: any)[name]
		end)
		return if ok and type(v) == "number" then v else nil
	end
	local function run(id: string?, quality: string): string
		local fx = TrailFx.attachModel(car, { quality = quality, reduceMotion = false })
		fx:set(if id then Catalog.byId("Trails", id) else nil)
		fx:setSpeed(1)
		car:PivotTo(CFrame.new(0, 500, 0))
		fx:clear()
		local z, t0 = 0, os.clock()
		local n, sum = 0, 0
		local acc = { FrameTime = { 0, 0 }, RenderCPUFrameTime = { 0, 0 }, RenderGPUFrameTime = { 0, 0 } }
		while os.clock() - t0 < 2.5 do
			local dt = RunService.RenderStepped:Wait()
			z -= 16 * dt
			if z < -500 then
				z = 0
				fx:clear()
			end
			car:PivotTo(CFrame.new(0, 500, z))
			camera.CFrame = CFrame.lookAt(Vector3.new(0, 509, z + 19), Vector3.new(0, 500, z + 3))
			if os.clock() - t0 > 0.7 then
				n += 1
				sum += dt
				for name, a in acc do
					local v = stat(name)
					if v then
						a[1] += v
						a[2] += 1
					end
				end
			end
		end
		local s = fx:stats()
		fx:destroy()
		return string.format(
			"%-14s %-5s dt %.2f ms  FrameTime %.2f  RenderCPU %.2f  RenderGPU %.2f | tier %d emitters %d alive %.0f beams %d ribbons %d",
			id or "(no trail)",
			quality,
			sum / math.max(n, 1) * 1000,
			acc.FrameTime[1] / math.max(acc.FrameTime[2], 1),
			acc.RenderCPUFrameTime[1] / math.max(acc.RenderCPUFrameTime[2], 1),
			acc.RenderGPUFrameTime[1] / math.max(acc.RenderGPUFrameTime[2], 1),
			s.tier,
			s.emitters,
			s.alive,
			s.beams,
			s.ribbons
		)
	end
	task.spawn(function()
		local lines = require(script.Parent.TrailSelfTest).run()
		print("WS5A_SELFTEST\n" .. table.concat(lines, "\n"))
		local out = { run(nil, "full") }
		for _, id in
			{
				"neon_ribbon",
				"bubble_pop",
				"drift_smoke",
				"frost_bite",
				"retro_grid",
				"lightning",
				"galaxy",
				"flame_rush",
				"vip_gradient",
			}
		do
			table.insert(out, run(id, "full"))
			table.insert(out, run(id, "phone"))
		end
		table.insert(out, run(nil, "full"))
		print("WS5A_MEASURE\n" .. table.concat(out, "\n"))
		request:SetAttribute("Done", true)
	end)
	return
end

if mode == "exhausts" then
	local names = {}
	for name in Exhausts do
		table.insert(names, name)
	end
	table.sort(names)
	for i, name in names do
		local source = ReplicatedStorage.Cars:FindFirstChild(name)
		if source then
			local col, row = (i - 1) % 9, (i - 1) // 9
			local m = (source :: Model):Clone()
			anchorAll(m)
			m.Parent = stage
			local at = CFrame.new(col * 16, 500, -row * 22)
			m:PivotTo(at)
			table.insert(cars, m)
			for _, point in Exhausts[name].points do
				local dot = Instance.new("Part")
				dot.Shape = Enum.PartType.Ball
				dot.Size = Vector3.one * 0.55
				dot.Material = Enum.Material.Neon
				dot.Color = Color3.fromRGB(255, 40, 40)
				dot.Anchored = true
				dot.CanCollide = false
				dot.CFrame = at * point
				dot.Parent = stage
			end
		end
	end
else
	local ids = {
		"neon_ribbon",
		"bubble_pop",
		"pixel_blast",
		"drift_smoke",
		"petal_storm",
		"frost_bite",
		"toxic_slime",
		"retro_grid",
		"aurora_veil",
		"lightning",
		"money_rain",
		"galaxy",
		"golden_glory",
		"flame_rush",
		"confetti_party",
		"rainbow_runway",
		"comet_tail",
		"vip_gradient",
	}
	for i, id in ids do
		local item = Catalog.byId("Trails", id)
		items[i] = item
		local m = ReplicatedStorage.Cars[CAR]:Clone()
		m.Name = "Car" .. i
		anchorAll(m)
		m.Parent = stage
		m:PivotTo(CFrame.new(i * 24, 500, 10))
		local fx = TrailFx.attachModel(m, { quality = request:GetAttribute("Quality") or "full", reduceMotion = false })
		fx:set(item)
		fx:setSpeed(1)
		cars[i], fxs[i] = m, fx
	end
	local lines = {}
	for i, fx in fxs do
		local s = fx:stats()
		table.insert(
			lines,
			string.format(
				"%02d %-15s tier %d emitters %2d alive %.0f beams %d ribbons %d sounds %d glows %d",
				i,
				items[i].id,
				s.tier,
				s.emitters,
				s.alive,
				s.beams,
				s.ribbons,
				s.sounds,
				s.glows
			)
		)
	end
	print("WS5A_STATS\n" .. table.concat(lines, "\n"))
end

request:SetAttribute("Ready", true)
local camera = workspace.CurrentCamera
local quality = request:GetAttribute("Quality") or "full"
RunService:BindToRenderStep("WS5A_Camera", Enum.RenderPriority.Camera.Value + 20, function(dt: number)
	if not request.Parent then
		return
	end
	camera.CameraType = Enum.CameraType.Scriptable
	if mode == "exhausts" then
		local row = (request:GetAttribute("Row") or 1) :: number
		local at = Vector3.new(64, 500, -(row - 1) * 22)
		local off = (request:GetAttribute("CamOffset") or Vector3.new(0, 7, 20)) :: Vector3
		camera.CFrame = CFrame.lookAt(at + off, at + Vector3.new(0, 1.5, 0))
		camera.FieldOfView = (request:GetAttribute("Fov") or 62) :: number
		return
	end
	local running = request:GetAttribute("Running")
	local speed = (request:GetAttribute("Speed") or 16) :: number
	local wanted = request:GetAttribute("Quality") or "full"
	if wanted ~= quality then
		quality = wanted
		for _, fx in fxs do
			fx:setQuality(quality)
		end
	end
	for i, m in cars do
		local z = m:GetPivot().Position.Z
		if running ~= false then
			z -= speed * dt
			if z < -150 then
				z = 10
				m:PivotTo(CFrame.new(i * 24, 500, z))
				fxs[i]:clear()
			else
				m:PivotTo(CFrame.new(i * 24, 500, z))
			end
		end
	end
	local m = cars[(request:GetAttribute("Focus") or 1) :: number]
	if m then
		local p = m:GetPivot().Position
		local off = (request:GetAttribute("CamOffset") or Vector3.new(0, 6.5, 13)) :: Vector3
		local aim = (request:GetAttribute("CamAim") or Vector3.new(0, 0.5, 4)) :: Vector3
		camera.CFrame = CFrame.lookAt(p + off, p + aim)
		camera.FieldOfView = (request:GetAttribute("Fov") or 55) :: number
	end
end)

task.spawn(function()
	while request.Parent do
		local gui = if player then player:FindFirstChildOfClass("PlayerGui") else nil
		if gui then
			for _, g in gui:GetChildren() do
				if g:IsA("ScreenGui") then
					g.Enabled = false
				end
			end
		end
		task.wait(0.5)
	end
	RunService:UnbindFromRenderStep("WS5A_Camera")
	for _, fx in fxs do
		fx:destroy()
	end
	stage:Destroy()
end)
