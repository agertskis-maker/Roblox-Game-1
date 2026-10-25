--!strict
-- Stand-in cars for the Lane 1 run prototype: original part-built shapes per family (no real
-- makes, badges or signature designs), labelled as proxies. Finished cars belong to Brian L
-- (decision 0015); the run will load those through one shared car rig once it is agreed.
-- Built front toward -Z, pivot on the road surface under the centre of the car. About 20 to 30
-- parts each, inside the outline's 20 to 40 part budget.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Families = require(ReplicatedStorage.Shared.Run.Families)
local RunConfig = require(ReplicatedStorage.Shared.Run.RunConfig)

local CarVisual = {}

local PAINTS: { Color3 } = {
	Color3.fromRGB(236, 82, 70),
	Color3.fromRGB(48, 128, 236),
	Color3.fromRGB(252, 196, 52),
	Color3.fromRGB(78, 196, 120),
	Color3.fromRGB(244, 244, 240),
	Color3.fromRGB(58, 64, 80),
	Color3.fromRGB(248, 134, 44),
	Color3.fromRGB(146, 96, 222),
	Color3.fromRGB(52, 200, 214),
	Color3.fromRGB(236, 112, 168),
	Color3.fromRGB(172, 184, 196),
	Color3.fromRGB(140, 92, 60),
}

CarVisual.RARITY_COLOR = table.freeze({
	Common = Color3.fromRGB(170, 176, 186),
	Rare = Color3.fromRGB(60, 150, 255),
	Epic = Color3.fromRGB(176, 92, 246),
	Legendary = Color3.fromRGB(255, 200, 40),
} :: { [RunConfig.Rarity]: Color3 })

CarVisual.VARIANT_COLOR = table.freeze({
	Gold = Color3.fromRGB(240, 190, 60),
	Chrome = Color3.fromRGB(214, 222, 232),
	Rainbow = Color3.fromRGB(255, 120, 200),
} :: { [string]: Color3 })

local GLASS = Color3.fromRGB(34, 46, 66)
local TYRE = Color3.fromRGB(28, 28, 32)
local RIM = Color3.fromRGB(200, 204, 212)
local TRIM = Color3.fromRGB(46, 48, 56)
local HEADLIGHT = Color3.fromRGB(255, 246, 206)
local TAILLIGHT = Color3.fromRGB(255, 44, 44)

export type Options = {
	family: string,
	rarity: RunConfig.Rarity,
	size: RunConfig.Size?,
	paint: number,
	variant: RunConfig.Variant?,
}

export type Dimensions = { length: number, width: number, height: number }

local function part(parent: Instance, name: string, size: Vector3, cf: CFrame, colour: Color3, className: string?): any
	local p = Instance.new(className or "Part") :: BasePart
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

local function paintPart(
	parent: Instance,
	name: string,
	size: Vector3,
	cf: CFrame,
	colour: Color3,
	className: string?
): BasePart
	local p = part(parent, name, size, cf, colour, className)
	p:SetAttribute("Paint", true)
	return p
end

local function neon(p: BasePart): BasePart
	p.Material = Enum.Material.Neon
	p.CastShadow = false
	return p
end

function CarVisual.paint(index: number): Color3
	return PAINTS[((index - 1) % #PAINTS) + 1]
end

function CarVisual.dimensions(familyName: string, size: RunConfig.Size?): Dimensions
	local f = Families.get(familyName)
	local s = RunConfig.SIZE_SCALE[(size or "Normal") :: RunConfig.Size]
	return { length = f.length * s, width = f.width * s, height = f.height * s }
end

local function wheels(m: Model, L: number, W: number, r: number, bike: boolean)
	local z = L / 2 - r * 1.15
	local xs: { number } = if bike then { 0 } else { -(W / 2 - 0.35), W / 2 - 0.35 }
	local i = 0
	for _, zz in { -z, z } do
		for _, x in xs do
			i += 1
			local tyre =
				part(m, "Tyre" .. i, Vector3.new(if bike then 0.7 else 1.1, r * 2, r * 2), CFrame.new(x, r, zz), TYRE)
			tyre.Shape = Enum.PartType.Cylinder
			local rim = part(
				m,
				"Rim" .. i,
				Vector3.new(if bike then 0.75 else 1.18, r * 1.15, r * 1.15),
				CFrame.new(x, r, zz),
				RIM
			)
			rim.Shape = Enum.PartType.Cylinder
			rim.Material = Enum.Material.Metal
		end
	end
end

-- Lights, bumpers and grille on a box body whose front is at z = -L/2.
local function trim(m: Model, L: number, W: number, y: number, h: number, tall: boolean)
	part(m, "BumperFront", Vector3.new(W + 0.2, h * 0.32, 0.7), CFrame.new(0, y - h * 0.32, -L / 2 - 0.2), TRIM)
	part(m, "BumperRear", Vector3.new(W + 0.2, h * 0.32, 0.7), CFrame.new(0, y - h * 0.32, L / 2 + 0.2), TRIM)
	part(m, "Grille", Vector3.new(W * 0.42, h * 0.3, 0.3), CFrame.new(0, y + h * 0.05, -L / 2 - 0.05), TRIM)
	local lightY = y + (if tall then h * 0.2 else h * 0.1)
	for side = -1, 1, 2 do
		neon(
			part(
				m,
				"Headlight",
				Vector3.new(W * 0.2, h * 0.2, 0.3),
				CFrame.new(side * W * 0.34, lightY, -L / 2 - 0.08),
				HEADLIGHT
			)
		)
		neon(
			part(
				m,
				"Taillight",
				Vector3.new(W * 0.18, h * 0.18, 0.3),
				CFrame.new(side * W * 0.36, lightY, L / 2 + 0.08),
				TAILLIGHT
			)
		)
	end
end

-- A glass cabin with a painted roof, a sloped windscreen in front and a sloped rear window.
local function cabin(
	m: Model,
	colour: Color3,
	W: number,
	baseY: number,
	h: number,
	frontZ: number,
	backZ: number,
	slope: number
)
	local len = backZ - frontZ
	local midZ = (frontZ + backZ) / 2
	part(m, "Cabin", Vector3.new(W * 0.86, h, len), CFrame.new(0, baseY + h / 2, midZ), GLASS)
	paintPart(m, "Roof", Vector3.new(W * 0.9, 0.35, len + 0.1), CFrame.new(0, baseY + h + 0.17, midZ), colour)
	part(
		m,
		"Windscreen",
		Vector3.new(W * 0.86, h, slope),
		CFrame.new(0, baseY + h / 2, frontZ - slope / 2),
		GLASS,
		"WedgePart"
	)
	part(
		m,
		"RearWindow",
		Vector3.new(W * 0.86, h, slope * 0.7),
		CFrame.new(0, baseY + h / 2, backZ + slope * 0.35) * CFrame.Angles(0, math.pi, 0),
		GLASS,
		"WedgePart"
	)
	for side = -1, 1, 2 do
		paintPart(
			m,
			"Mirror",
			Vector3.new(0.5, 0.45, 0.7),
			CFrame.new(side * (W / 2 + 0.2), baseY + h * 0.2, frontZ - slope * 0.4),
			colour
		)
	end
end

local function buildCar(m: Model, family: string, colour: Color3, L: number, W: number, H: number)
	local r = math.min(H * 0.2, 1.6 * L / 13)
	local floor = r * 0.9
	if family == "Van" then
		local bodyH = H - floor - 0.3
		paintPart(m, "Body", Vector3.new(W, bodyH, L), CFrame.new(0, floor + bodyH / 2, 0), colour)
		for side = -1, 1, 2 do
			part(
				m,
				"SideWindows",
				Vector3.new(0.1, bodyH * 0.28, L * 0.62),
				CFrame.new(side * (W / 2 + 0.03), floor + bodyH * 0.74, L * 0.06),
				GLASS
			)
		end
		part(
			m,
			"Windscreen",
			Vector3.new(W * 0.86, bodyH * 0.3, 0.12),
			CFrame.new(0, floor + bodyH * 0.74, -L / 2 - 0.05),
			GLASS
		)
		paintPart(m, "Roof", Vector3.new(W * 0.92, 0.3, L * 0.9), CFrame.new(0, floor + bodyH + 0.15, 0), colour)
		trim(m, L, W, floor + bodyH * 0.3, bodyH * 0.5, true)
	elseif family == "Truck" then
		local cabL = L * 0.26
		local cabH = H * 0.62
		paintPart(m, "Cab", Vector3.new(W, cabH, cabL), CFrame.new(0, floor + cabH / 2, -L / 2 + cabL / 2), colour)
		part(
			m,
			"Windscreen",
			Vector3.new(W * 0.84, cabH * 0.35, 0.12),
			CFrame.new(0, floor + cabH * 0.72, -L / 2 - 0.05),
			GLASS
		)
		local boxL = L * 0.7
		local boxH = H - floor - 0.3
		part(
			m,
			"Trailer",
			Vector3.new(W * 1.02, boxH, boxL),
			CFrame.new(0, floor + boxH / 2 + 0.2, L / 2 - boxL / 2),
			Color3.fromRGB(236, 236, 230)
		)
		paintPart(
			m,
			"TrailerStripe",
			Vector3.new(W * 1.04, boxH * 0.16, boxL * 0.9),
			CFrame.new(0, floor + boxH * 0.45, L / 2 - boxL / 2),
			colour
		)
		trim(m, L, W, floor + cabH * 0.3, cabH * 0.5, true)
	elseif family == "Pickup" then
		local bodyH = H * 0.4
		paintPart(m, "Body", Vector3.new(W, bodyH, L), CFrame.new(0, floor + bodyH / 2, 0), colour)
		cabin(m, colour, W, floor + bodyH, H - floor - bodyH - 0.35, -L * 0.18, L * 0.08, L * 0.12)
		for side = -1, 1, 2 do
			paintPart(
				m,
				"BedWall",
				Vector3.new(0.4, bodyH * 0.55, L * 0.36),
				CFrame.new(side * (W / 2 - 0.2), floor + bodyH * 1.27, L * 0.3),
				colour
			)
		end
		paintPart(
			m,
			"Tailgate",
			Vector3.new(W, bodyH * 0.55, 0.4),
			CFrame.new(0, floor + bodyH * 1.27, L / 2 - 0.2),
			colour
		)
		part(m, "BedFloor", Vector3.new(W - 0.8, 0.2, L * 0.36), CFrame.new(0, floor + bodyH + 0.1, L * 0.3), TRIM)
		trim(m, L, W, floor + bodyH * 0.5, bodyH, false)
	else
		-- Compact, Sedan, Sports, Special: body, hood and a glass cabin.
		local bodyH = if family == "Sports" then H * 0.42 else H * 0.38
		paintPart(m, "Body", Vector3.new(W, bodyH, L), CFrame.new(0, floor + bodyH / 2, 0), colour)
		local cabinH = H - floor - bodyH - 0.35
		local frontZ, backZ, slope
		if family == "Compact" then
			frontZ, backZ, slope = -L * 0.12, L * 0.3, L * 0.16
		elseif family == "Sports" then
			frontZ, backZ, slope = -L * 0.02, L * 0.2, L * 0.24
		elseif family == "Special" then
			frontZ, backZ, slope = -L * 0.2, L * 0.28, L * 0.1
		else
			frontZ, backZ, slope = -L * 0.08, L * 0.22, L * 0.14
		end
		cabin(m, colour, W, floor + bodyH, cabinH, frontZ, backZ, slope)
		trim(m, L, W, floor + bodyH * 0.5, bodyH, false)
		if family == "Sports" then
			paintPart(
				m,
				"Wing",
				Vector3.new(W * 0.9, 0.25, L * 0.1),
				CFrame.new(0, floor + bodyH + 1.1, L / 2 - L * 0.06),
				colour
			)
			for side = -1, 1, 2 do
				part(
					m,
					"WingStand",
					Vector3.new(0.3, 1, 0.4),
					CFrame.new(side * W * 0.3, floor + bodyH + 0.55, L / 2 - L * 0.06),
					TRIM
				)
			end
		elseif family == "Special" then
			-- A party roof: a glittering ball on a short stand (original, not an emergency light).
			local ball = part(
				m,
				"PartyBall",
				Vector3.new(1.6, 1.6, 1.6),
				CFrame.new(0, H + 0.9, L * 0.12),
				Color3.fromRGB(230, 236, 255)
			)
			ball.Shape = Enum.PartType.Ball
			ball.Material = Enum.Material.Foil
			ball.Reflectance = 0.4
		end
	end
	wheels(m, L, W, r, false)
end

local function buildBike(m: Model, colour: Color3, L: number, W: number, H: number)
	local r = H * 0.22
	paintPart(m, "Tank", Vector3.new(W * 0.55, H * 0.2, L * 0.3), CFrame.new(0, r * 2.1, -L * 0.08), colour)
	part(m, "Frame", Vector3.new(W * 0.3, H * 0.14, L * 0.7), CFrame.new(0, r * 1.6, 0), TRIM)
	part(
		m,
		"Seat",
		Vector3.new(W * 0.55, H * 0.08, L * 0.3),
		CFrame.new(0, r * 2.15, L * 0.18),
		Color3.fromRGB(30, 30, 34)
	)
	part(
		m,
		"Fork",
		Vector3.new(0.3, H * 0.4, 0.3),
		CFrame.new(0, r * 1.7, -L / 2 + r * 1.3) * CFrame.Angles(math.rad(-20), 0, 0),
		RIM
	)
	part(m, "Bars", Vector3.new(W * 1.1, 0.25, 0.25), CFrame.new(0, H * 0.72, -L * 0.3), TRIM)
	neon(part(m, "Headlight", Vector3.new(0.6, 0.6, 0.3), CFrame.new(0, H * 0.58, -L / 2 + 0.2), HEADLIGHT))
	neon(part(m, "Taillight", Vector3.new(0.5, 0.3, 0.2), CFrame.new(0, r * 2.2, L / 2 - 0.3), TAILLIGHT))
	paintPart(m, "Fender", Vector3.new(W * 0.4, 0.25, L * 0.3), CFrame.new(0, r * 2.05, L / 2 - r), colour)
	wheels(m, L, W, r, true)
end

function CarVisual.build(options: Options): Model
	local f = Families.get(options.family)
	local size: RunConfig.Size = options.size or "Normal"
	local dims = CarVisual.dimensions(options.family, size)
	local L, W, H = dims.length, dims.width, dims.height
	local m = Instance.new("Model")
	m.Name = "Proxy_" .. options.family .. "_" .. options.rarity
	m:SetAttribute("Proxy", "Lane 1 stand-in, not a finished car")
	m:SetAttribute("Family", options.family)
	m:SetAttribute("Rarity", options.rarity)
	m:SetAttribute("Size", size)
	m:SetAttribute("PaintIndex", options.paint)

	local colour = CarVisual.paint(options.paint)
	if f.name == "Motorcycle" then
		buildBike(m, colour, L, W, H)
	else
		buildCar(m, f.name, colour, L, W, H)
	end

	-- Rarity underglow: a soft coloured light under every Rare or better car, readable in traffic.
	if options.rarity ~= "Common" then
		local glow = neon(
			part(
				m,
				"Underglow",
				Vector3.new(W * 0.9, 0.1, L * 0.85),
				CFrame.new(0, 0.12, 0),
				CarVisual.RARITY_COLOR[options.rarity]
			)
		)
		glow.Transparency = 0.25
		local light = Instance.new("PointLight")
		light.Color = CarVisual.RARITY_COLOR[options.rarity]
		light.Range = math.max(L, 10)
		light.Brightness = 1.5
		light.Parent = glow
	end

	CarVisual.applyVariant(m, options.variant or "None")
	m.WorldPivot = CFrame.new()
	return m
end

function CarVisual.applyVariant(m: Model, variant: RunConfig.Variant)
	m:SetAttribute("Variant", variant)
	if variant == "None" then
		return
	end
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") and d:GetAttribute("Paint") then
			if variant == "Gold" then
				d.Color = CarVisual.VARIANT_COLOR.Gold
				d.Material = Enum.Material.Foil
				d.Reflectance = 0.25
			elseif variant == "Chrome" then
				d.Color = CarVisual.VARIANT_COLOR.Chrome
				d.Material = Enum.Material.Metal
				d.Reflectance = 0.55
			end
		end
	end
	-- A glowing trail so a Variant is spotted from far away (outline section 07).
	local body = m:FindFirstChild("Body") or m:FindFirstChild("Cab") or m:FindFirstChild("Tank")
	if body and body:IsA("BasePart") then
		local a0 = Instance.new("Attachment")
		a0.Position = Vector3.new(-body.Size.X * 0.4, 0, body.Size.Z / 2)
		a0.Parent = body
		local a1 = Instance.new("Attachment")
		a1.Position = Vector3.new(body.Size.X * 0.4, 0, body.Size.Z / 2)
		a1.Parent = body
		local trail = Instance.new("Trail")
		trail.Attachment0 = a0
		trail.Attachment1 = a1
		trail.Lifetime = 0.6
		trail.LightEmission = 1
		trail.FaceCamera = true
		trail.Color = if variant == "Rainbow"
			then ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 80, 80)),
				ColorSequenceKeypoint.new(0.33, Color3.fromRGB(255, 230, 60)),
				ColorSequenceKeypoint.new(0.66, Color3.fromRGB(70, 220, 120)),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(80, 140, 255)),
			})
			else ColorSequence.new(CarVisual.VARIANT_COLOR[variant])
		trail.Transparency = NumberSequence.new(0.2, 1)
		trail.Parent = body
	end
end

-- Per-frame look: Heat tint (0 to 1) on the painted parts, and the Rainbow colour cycle.
function CarVisual.update(m: Model, heat: number, t: number)
	local variant = m:GetAttribute("Variant")
	local base: Color3
	if variant == "Rainbow" then
		base = Color3.fromHSV((t * 0.25) % 1, 0.75, 1)
	elseif variant == "Gold" or variant == "Chrome" then
		base = CarVisual.VARIANT_COLOR[variant :: string]
	else
		base = CarVisual.paint((m:GetAttribute("PaintIndex") :: number?) or 1)
	end
	local a = math.clamp((heat - RunConfig.HEAT_WARNING) / (1 - RunConfig.HEAT_WARNING), 0, 1) * 0.6
	local colour = base:Lerp(Color3.fromRGB(222, 40, 28), a)
	for _, d in m:GetChildren() do
		if d:IsA("BasePart") and d:GetAttribute("Paint") then
			d.Color = colour
		end
	end
end

-- Height of the roof (where the rider sits) for a car of this family and size.
function CarVisual.roofHeight(familyName: string, size: RunConfig.Size?): number
	local dims = CarVisual.dimensions(familyName, size)
	if familyName == "Motorcycle" then
		return dims.height * 0.5
	end
	return dims.height
end

return CarVisual
