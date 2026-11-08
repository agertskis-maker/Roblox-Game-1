--!strict
-- WheelAudit (Round 8, W-02): a development tool, idle in the real game. It does nothing until the attribute "R8WheelAudit" is set
-- on ReplicatedStorage (the Studio MCP sets it during Play); then the command in the attribute runs:
--   "sheet:<page>"            a full-screen contact sheet of the cars wearing three rims, close on the front wheel (4 cars a page)
--   "real:<car>:<wheelsId>"   one car in the world with that design, camera on the front wheel, wheels turning
--   "off"                     removes whatever it made
-- It also prints PASS/FAIL lines (hubs, mirrored faces, roll direction) so the audit does not depend on looking only.
-- Round 8's contact sheets (Car-Hop-Art/review/round8/frames/wheel-audit) come from here. Safe to delete before a release.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local ATTR = "R8WheelAudit"
local WheelKit = require(script.Parent.WheelKit)
local Trove = require(ReplicatedStorage.Packages.Trove)

local player = Players.LocalPlayer
local CARS = ReplicatedStorage:WaitForChild("Cars")
local SHEET_RIMS = { "multi_spoke", "gold_star", "neon_ring" } -- Catalog ids: Multi-Spoke, Gold Crown, Neon Ring
local PER_PAGE = 4

local trove = Trove.new()

local function carNames(): { string }
	local names: { string } = {}
	for _, car in CARS:GetChildren() do
		if
			car:IsA("Model")
			and not string.find(car.Name, "^Gold ")
			and not string.find(car.Name, "^Diamond ")
			and not string.find(car.Name, "^Rainbow ")
		then
			table.insert(names, car.Name)
		end
	end
	table.sort(names)
	return names
end

local function check(name: string, ok: boolean, detail: string?)
	print(
		string.format(
			"[R8WheelAudit] %s %s%s",
			if ok then "PASS" else "FAIL",
			name,
			if detail then (" " .. detail) else ""
		)
	)
end

-- one car dressed with one design: checks the hubs, the mirrored faces and the roll direction
local function audit(model: Model, id: string, label: string)
	local h = WheelKit.fit(model, id)
	h:setSpin(0.3)
	local folder = model:FindFirstChild("R8Wheels")
	check(label .. " fitted", folder ~= nil)
	if folder then
		local pivot = model:GetPivot()
		for i = 1, 4 do
			local tyre = folder:FindFirstChild("Tyre" .. i) :: BasePart?
			local hub = WheelKit.hub(model, i)
			if tyre and hub then
				local out = tyre.CFrame.RightVector -- the axle: must still point out of the car
				local side = pivot:VectorToObjectSpace(out).X
				local up = tyre.CFrame.UpVector
				local forward = pivot:VectorToObjectSpace(up).Z -- the top of the wheel moves toward -Z when rolling forward
				check(
					label .. " hub " .. i .. " faces out",
					(side > 0) == (pivot:PointToObjectSpace(hub.cframe.Position).X > 0)
				)
				check(label .. " hub " .. i .. " rolls forward", forward < 0, string.format("(top z %.2f)", forward))
				local d = (tyre.Position - hub.cframe.Position).Magnitude
				check(label .. " hub " .. i .. " on the hub", d < 0.05 * hub.radius, string.format("(%.3f)", d))
			else
				check(label .. " hub " .. i .. " parts", false)
			end
		end
	end
	return h
end

local function clear()
	trove:Clean()
end

local function runSheet(page: number)
	clear()
	local gui = Instance.new("ScreenGui")
	gui.Name = "R8WheelAuditSheet"
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 1000
	gui.ResetOnSpawn = false
	gui.Parent = player:WaitForChild("PlayerGui")
	trove:Add(gui)
	local back = Instance.new("Frame")
	back.Size = UDim2.fromScale(1, 1)
	back.BackgroundColor3 = Color3.fromRGB(14, 18, 34)
	back.BorderSizePixel = 0
	back.Parent = gui
	local names = carNames()
	local first = (page - 1) * PER_PAGE + 1
	local rows = math.min(PER_PAGE, #names - first + 1)
	for row = 1, rows do
		local carName = names[first + row - 1]
		for col, id in SHEET_RIMS do
			local source = CARS:FindFirstChild(carName) :: Model
			local vp = Instance.new("ViewportFrame")
			vp.Size = UDim2.new(1 / 3, -4, 1 / PER_PAGE, -4)
			vp.Position = UDim2.new((col - 1) / 3, 2, (row - 1) / PER_PAGE, 2)
			vp.BackgroundColor3 = Color3.fromRGB(34, 44, 74)
			vp.Ambient = Color3.fromRGB(150, 150, 165)
			vp.LightColor = Color3.fromRGB(255, 246, 228)
			vp.LightDirection = Vector3.new(-0.6, -1, -0.5)
			vp.Parent = back
			local model = source:Clone()
			model:PivotTo(CFrame.new(0, 0, 0))
			model.Parent = vp
			local handle = audit(model, id, carName .. " " .. id)
			trove:Add(function()
				handle:destroy()
			end)
			local hub = WheelKit.hub(model, 2)
			local cam = Instance.new("Camera")
			cam.FieldOfView = 38
			if hub then
				local p = hub.cframe.Position
				local axle = hub.cframe.XVector
				cam.CFrame =
					CFrame.lookAt(p + axle * hub.radius * 4.6 + Vector3.new(0, hub.radius * 0.7, -hub.radius * 2.2), p)
			end
			cam.Parent = vp
			vp.CurrentCamera = cam
			local label = Instance.new("TextLabel")
			label.BackgroundTransparency = 0.35
			label.BackgroundColor3 = Color3.new(0, 0, 0)
			label.TextColor3 = Color3.new(1, 1, 1)
			label.Font = Enum.Font.GothamBold
			label.TextScaled = true
			label.Size = UDim2.new(0.6, 0, 0, 22)
			label.Position = UDim2.fromOffset(4, 4)
			label.TextXAlignment = Enum.TextXAlignment.Left
			label.Text = carName .. " / " .. id
			label.Parent = vp
		end
	end
	print("[R8WheelAudit] sheet page " .. page .. " of " .. math.ceil(#names / PER_PAGE) .. " (" .. #names .. " cars)")
end

local function runReal(carName: string, id: string)
	clear()
	local source = CARS:FindFirstChild(carName)
	if not (source and source:IsA("Model")) then
		print("[R8WheelAudit] FAIL no such car " .. carName)
		return
	end
	local model = source:Clone()
	model:PivotTo(CFrame.new(0, 400, 0))
	model.Parent = workspace
	trove:Add(model)
	-- a floor so the shadows and the Neon read
	local floor = Instance.new("Part")
	floor.Anchored = true
	floor.Size = Vector3.new(60, 1, 60)
	floor.Position = Vector3.new(0, 399.5, 0)
	floor.Color = Color3.fromRGB(70, 74, 86)
	floor.Parent = workspace
	trove:Add(floor)
	local handle = audit(model, id, carName .. " " .. id)
	trove:Add(function()
		handle:destroy()
	end)
	local camera = workspace.CurrentCamera
	local hub = WheelKit.hub(model, 2)
	local saved = camera.CameraType
	camera.CameraType = Enum.CameraType.Scriptable
	trove:Add(function()
		camera.CameraType = saved
	end)
	trove:Connect(RunService.RenderStepped, function(dt: number)
		handle:spin(dt * 2.0)
		if hub then
			local p = hub.cframe.Position
			camera.CFrame = CFrame.lookAt(
				p + hub.cframe.XVector * hub.radius * 4.2 + Vector3.new(0, hub.radius * 0.7, -hub.radius * 2),
				p
			)
			camera.FieldOfView = 40
		end
	end)
end

local function dispatch()
	local command = ReplicatedStorage:GetAttribute(ATTR)
	if type(command) ~= "string" then
		return
	end
	local kind, a, b = string.match(command, "^(%a+):?([^:]*):?([^:]*)$")
	if kind == "sheet" then
		runSheet(tonumber(a) or 1)
	elseif kind == "real" then
		runReal(a, b)
	elseif kind == "off" then
		clear()
	end
end

ReplicatedStorage:GetAttributeChangedSignal(ATTR):Connect(dispatch)
dispatch()
