--!strict
-- Car footprints and PROXY car models for the Downtown B city preview (Lane 3). Brian L owns
-- cars and car data; these are the HUD prototype's synthetic fixtures, used for scale only.
--
-- Sources, in order: the HUD prototype modules src/client/UI/Prototype/Fixtures.luau and
-- ProxyCar.luau when the place maps them (the Downtown playground maps both, read-only, to
-- ReplicatedStorage.LookDevCars; in Play the client copy under PlayerScripts is also found),
-- else the built-in copy below of the same fixture lengths and ProxyCar family proportions.
-- Footprint: width = max(length x family width ratio, 2.4), as ProxyCar draws it; the Puglet
-- reference uses its measured 12.47 x 5.66 x 4.71 studs (provisional 1 stud = 0.28 m).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")

local Parts = require(script.Parent.Parent.Parts)

local Cars = {}

Cars.PUGLET = table.freeze({ length = 12.47, width = 5.66, height = 4.71 })

export type Car = {
	id: string,
	name: string,
	family: string,
	length: number,
	width: number,
	height: number,
	paint: Color3,
}

-- ProxyCar's family proportions (width and height as a share of length).
local FAMILY: { [string]: { width: number, height: number } } = {
	Compact = { width = 0.45, height = 0.37 },
	Sedan = { width = 0.42, height = 0.3 },
	Sports = { width = 0.48, height = 0.24 },
	Special = { width = 0.48, height = 0.26 },
	Van = { width = 0.42, height = 0.5 },
	Bus = { width = 0.34, height = 0.42 },
	Pickup = { width = 0.42, height = 0.36 },
	Motorcycle = { width = 0.22, height = 0.5 },
}

local BUILT_IN = {
	{ "puglet", "Puglet", "Compact", 12.5, Color3.fromRGB(40, 120, 232) },
	{ "fishbowl", "Fishbowl Express", "Bus", 26, Color3.fromRGB(0, 166, 180) },
	{ "waffle", "Citrine Waffle Van", "Van", 15, Color3.fromRGB(194, 24, 91) },
	{ "rangy", "Rangy", "Pickup", 16, Color3.fromRGB(232, 179, 58) },
	{ "rev6", "Revolution 6", "Sedan", 14.5, Color3.fromRGB(30, 86, 200) },
	{ "zoomurai", "Zoomurai", "Motorcycle", 7, Color3.fromRGB(244, 194, 13) },
	{ "hurrikan", "Hurrikan", "Sports", 14, Color3.fromRGB(139, 203, 44) },
	{ "hyperion", "Hyperion", "Special", 14.5, Color3.fromRGB(238, 241, 245) },
}

local function findPrototype(name: string): ModuleScript?
	local mapped = ReplicatedStorage:FindFirstChild("LookDevCars")
	local found = mapped and mapped:FindFirstChild(name)
	if found and found:IsA("ModuleScript") then
		return found
	end
	local roots: { Instance } = {}
	local player = Players.LocalPlayer
	local playerScripts = player and player:FindFirstChildOfClass("PlayerScripts")
	if playerScripts then
		table.insert(roots, playerScripts)
	end
	local starter = StarterPlayer:FindFirstChildOfClass("StarterPlayerScripts")
	if starter then
		table.insert(roots, starter)
	end
	for _, root in roots do
		local client = root:FindFirstChild("Client")
		local ui = client and client:FindFirstChild("UI")
		local prototype = ui and ui:FindFirstChild("Prototype")
		local module = prototype and prototype:FindFirstChild(name)
		if module and module:IsA("ModuleScript") then
			return module
		end
	end
	return nil
end

local proxyCarModule: any = nil
local proxyCarTried = false

local function proxyCar(): any
	if not proxyCarTried then
		proxyCarTried = true
		local module = findPrototype("ProxyCar")
		if module then
			local ok, value = pcall(require, module)
			if ok then
				proxyCarModule = value
			end
		end
	end
	return proxyCarModule
end

local function footprint(id: string, family: string, length: number): (number, number, number)
	if id == "puglet" then
		return Cars.PUGLET.length, Cars.PUGLET.width, Cars.PUGLET.height
	end
	local f = FAMILY[family] or FAMILY.Compact
	return length, math.max(length * f.width, 2.4), math.max(length * f.height, 2.4)
end

local cached: { Car }? = nil

-- The fixture cars with their footprints (studs).
function Cars.list(): { Car }
	if cached then
		return cached
	end
	local out: { Car } = {}
	local module = findPrototype("Fixtures")
	local ok, fixtures = false, nil
	if module then
		ok, fixtures = pcall(require, module)
	end
	if ok and type(fixtures) == "table" and type(fixtures.Cars) == "table" then
		for _, c in fixtures.Cars do
			local length, width, height = footprint(c.id, c.family, c.length or 12.5)
			table.insert(out, {
				id = c.id,
				name = c.name,
				family = c.family,
				length = length,
				width = width,
				height = height,
				paint = c.paint or Color3.fromRGB(40, 120, 232),
			})
		end
	end
	if #out == 0 then
		for _, row in BUILT_IN do
			local id, family = row[1] :: string, row[3] :: string
			local length, width, height = footprint(id, family, row[4] :: number)
			table.insert(out, {
				id = id,
				name = row[2] :: string,
				family = family,
				length = length,
				width = width,
				height = height,
				paint = row[5] :: Color3,
			})
		end
	end
	cached = out
	return out
end

function Cars.byId(id: string): Car
	for _, c in Cars.list() do
		if c.id == id then
			return c
		end
	end
	return Cars.list()[1]
end

local function simpleProxy(car: Car): Model
	local m = Instance.new("Model")
	local body = Parts.block(
		m,
		"Body",
		Vector3.new(car.width, car.height * 0.55, car.length),
		CFrame.new(0, 0.9 + car.height * 0.275, 0),
		car.paint
	)
	Parts.block(
		m,
		"Cabin",
		Vector3.new(car.width * 0.84, car.height * 0.4, car.length * 0.5),
		CFrame.new(0, 0.9 + car.height * 0.55 + car.height * 0.2, 0),
		Color3.fromRGB(44, 62, 88)
	)
	for _, x in { -1, 1 } do
		for _, z in { -1, 1 } do
			Parts.block(
				m,
				"Wheel",
				Vector3.new(0.9, 1.8, 1.8),
				CFrame.new(x * (car.width / 2 - 0.3), 0.9, z * (car.length / 2 - 2)),
				Color3.fromRGB(34, 36, 44),
				Enum.PartType.Cylinder
			)
		end
	end
	local plate = Parts.block(
		m,
		"ProxyPlate",
		Vector3.new(2, 0.6, 0.05),
		CFrame.new(0, 1.6, car.length / 2 + 0.05),
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
	text.Text = "PROXY"
	text.Parent = gui
	gui.Parent = plate
	m.PrimaryPart = body
	return m
end

-- A proxy car at the origin, front toward -Z, pivot at its ground centre. Uses the HUD
-- prototype's ProxyCar when available, else a simple labelled part proxy.
function Cars.build(car: Car): Model
	local builder = proxyCar()
	local m: Model? = nil
	if builder and type(builder.build) == "function" then
		local ok, value = pcall(builder.build, {
			name = car.name,
			family = car.family,
			paint = car.paint,
			length = car.length,
		})
		if ok and typeof(value) == "Instance" and value:IsA("Model") then
			m = value
		end
	end
	local model = m or simpleProxy(car)
	model.Name = "PROXY_" .. car.name
	model:SetAttribute("Proxy", "part-built scale proxy (not a finished car; Brian L owns cars)")
	model:SetAttribute("CarId", car.id)
	model:SetAttribute("Footprint", Vector3.new(car.width, car.height, car.length))
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			d.CastShadow = false -- moving objects: no shadows (performance guidance)
		end
	end
	model.WorldPivot = CFrame.identity
	return model
end

return Cars
