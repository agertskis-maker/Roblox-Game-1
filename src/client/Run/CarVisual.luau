--!strict
-- Greybox stand-in cars for the Lane 1 run prototype. Original part-built shapes, labelled as
-- proxies, sized by family. Finished cars belong to Brian L (decision 0015); the run will load
-- those through one shared car rig once it is agreed. Built front toward -Z, pivot at the
-- centre of the body's footprint on the road surface.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Families = require(ReplicatedStorage.Shared.Run.Families)
local RunConfig = require(ReplicatedStorage.Shared.Run.RunConfig)

local CarVisual = {}

local PAINTS: { Color3 } = {
	Color3.fromRGB(236, 92, 76),
	Color3.fromRGB(54, 132, 232),
	Color3.fromRGB(250, 196, 64),
	Color3.fromRGB(86, 196, 128),
	Color3.fromRGB(240, 240, 236),
	Color3.fromRGB(64, 70, 84),
	Color3.fromRGB(246, 140, 52),
	Color3.fromRGB(150, 104, 220),
	Color3.fromRGB(64, 200, 210),
	Color3.fromRGB(232, 120, 168),
	Color3.fromRGB(176, 186, 196),
	Color3.fromRGB(120, 84, 60),
}

CarVisual.RARITY_COLOR = table.freeze({
	Common = Color3.fromRGB(160, 166, 176),
	Rare = Color3.fromRGB(60, 140, 255),
	Epic = Color3.fromRGB(170, 90, 240),
	Legendary = Color3.fromRGB(255, 196, 40),
} :: { [RunConfig.Rarity]: Color3 })

local GLASS = Color3.fromRGB(28, 36, 52)
local TYRE = Color3.fromRGB(30, 30, 34)

export type CarModel = Model & { Body: Part }

local function part(parent: Instance, name: string, size: Vector3, cf: CFrame, colour: Color3): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = true
	p.Size = size
	p.CFrame = cf
	p.Color = colour
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

function CarVisual.paint(index: number): Color3
	return PAINTS[((index - 1) % #PAINTS) + 1]
end

function CarVisual.build(familyName: string, rarity: RunConfig.Rarity, paintIndex: number): CarModel
	local f = Families.get(familyName)
	local m = Instance.new("Model")
	m.Name = "Proxy_" .. familyName .. "_" .. rarity
	m:SetAttribute("Proxy", "Lane 1 greybox stand-in, not a finished car")
	m:SetAttribute("Family", familyName)
	m:SetAttribute("Rarity", rarity)

	local paint = CarVisual.paint(paintIndex)
	local L, W, H = f.length, f.width, f.height
	local wheel = math.min(H * 0.42, 2.6)
	local isBike = familyName == "Motorcycle"

	local bodyH = if isBike then H * 0.35 else H * 0.5
	local bodyY = wheel * 0.55 + bodyH / 2
	local body = part(m, "Body", Vector3.new(W, bodyH, L), CFrame.new(0, bodyY, 0), paint)
	m.PrimaryPart = body

	if isBike then
		part(m, "Seat", Vector3.new(W * 0.8, 0.6, L * 0.35), CFrame.new(0, bodyY + bodyH / 2 + 0.3, 0.4), GLASS)
		part(m, "Bars", Vector3.new(W * 1.6, 0.4, 0.4), CFrame.new(0, bodyY + bodyH / 2 + 1.2, -L * 0.38), TYRE)
	else
		local cabinL = if familyName == "Van" or familyName == "Truck"
			then L * 0.82
			elseif familyName == "Pickup" then L * 0.42
			else L * 0.55
		local cabinZ = if familyName == "Pickup" then -L * 0.12 elseif familyName == "Truck" then L * 0.06 else L * 0.04
		local cabinH = H - bodyY - bodyH / 2
		local cabin = part(
			m,
			"Cabin",
			Vector3.new(W * 0.9, cabinH, cabinL),
			CFrame.new(0, bodyY + bodyH / 2 + cabinH / 2, cabinZ),
			GLASS
		)
		cabin.Transparency = 0.15
		part(
			m,
			"Roof",
			Vector3.new(W * 0.92, 0.3, cabinL * 0.96),
			CFrame.new(0, bodyY + bodyH / 2 + cabinH + 0.15, cabinZ),
			paint
		)
	end

	-- Rarity band: a thin glowing strip along the top so rarity reads from behind and above.
	local band = part(
		m,
		"RarityBand",
		Vector3.new(math.max(W * 0.25, 0.8), 0.25, L * 0.6),
		CFrame.new(0, H + 0.15, 0),
		CarVisual.RARITY_COLOR[rarity]
	)
	band.Material = if rarity == "Common" then Enum.Material.SmoothPlastic else Enum.Material.Neon

	local wheelZ = L / 2 - wheel * 0.9
	local wheelX = if isBike then 0 else W / 2 - 0.4
	local positions: { Vector3 } = if isBike
		then { Vector3.new(0, 0, -wheelZ), Vector3.new(0, 0, wheelZ) }
		else {
			Vector3.new(-wheelX, 0, -wheelZ),
			Vector3.new(wheelX, 0, -wheelZ),
			Vector3.new(-wheelX, 0, wheelZ),
			Vector3.new(wheelX, 0, wheelZ),
		}
	for i, p in positions do
		local w = part(
			m,
			"Wheel" .. i,
			Vector3.new(if isBike then 0.8 else 1.2, wheel, wheel),
			CFrame.new(p.X, wheel / 2, p.Z),
			TYRE
		)
		w.Shape = Enum.PartType.Cylinder
	end

	m.WorldPivot = CFrame.new()
	return m :: any
end

-- Tints the body toward red as Heat rises (0 to 1). Presentation only.
function CarVisual.setHeat(model: Model, paintIndex: number, heat: number)
	local body = model:FindFirstChild("Body")
	if body and body:IsA("BasePart") then
		local a = math.clamp((heat - RunConfig.HEAT_WARNING) / (1 - RunConfig.HEAT_WARNING), 0, 1) * 0.6
		body.Color = CarVisual.paint(paintIndex):Lerp(Color3.fromRGB(220, 40, 30), a)
	end
end

return CarVisual
