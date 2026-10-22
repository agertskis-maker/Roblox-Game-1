--!strict
-- An original, part-built SCALE PROXY car for the HUD prototype's cards and world fixtures
-- (Lane 3 preview). Labelled as a proxy wherever it is shown: it stands in for finished cars,
-- which Brian L owns (decision 0015). Proportions follow the family; length comes from the
-- fixture (the Puglet reference is 12.47 x 5.66 x 4.71 studs). Built once per use and reused;
-- never cloned per frame.

local ProxyCar = {}

local function part(
	parent: Instance,
	name: string,
	size: Vector3,
	cf: CFrame,
	colour: Color3,
	shape: Enum.PartType?
): Part
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
	if shape then
		p.Shape = shape
	end
	p.Parent = parent
	return p
end

local FAMILY: { [string]: { width: number, height: number, cabin: number, cabinAt: number } } = {
	Compact = { width = 0.45, height = 0.37, cabin = 0.5, cabinAt = -0.05 },
	Sedan = { width = 0.42, height = 0.3, cabin = 0.45, cabinAt = 0 },
	Sports = { width = 0.48, height = 0.24, cabin = 0.35, cabinAt = 0.05 },
	Special = { width = 0.48, height = 0.26, cabin = 0.38, cabinAt = 0.02 },
	Van = { width = 0.42, height = 0.5, cabin = 0.85, cabinAt = 0 },
	Bus = { width = 0.34, height = 0.42, cabin = 0.95, cabinAt = 0 },
	Pickup = { width = 0.42, height = 0.36, cabin = 0.4, cabinAt = -0.18 },
	Motorcycle = { width = 0.22, height = 0.5, cabin = 0.3, cabinAt = 0 },
}

-- Builds the proxy at the origin, front toward -Z. Returns the Model (PrimaryPart = body).
function ProxyCar.build(car: { name: string, family: string, paint: Color3?, length: number?, variant: string? }): Model
	local m = Instance.new("Model")
	m.Name = "Proxy_" .. car.name
	m:SetAttribute("Proxy", "original part-built scale proxy (not a finished car)")
	local f = FAMILY[car.family] or FAMILY.Compact
	local L = car.length or 12.5
	local W = math.max(L * f.width, 2.4)
	local H = math.max(L * f.height, 2.4)
	local paint = car.paint or Color3.fromRGB(40, 120, 232)
	if car.variant == "Gold" then
		paint = Color3.fromRGB(230, 182, 60)
	elseif car.variant == "Chrome" then
		paint = Color3.fromRGB(205, 214, 226)
	end
	local wheelR = math.clamp(L * 0.085, 0.9, 2.2)
	local bodyH = H * 0.55
	local body = part(m, "Body", Vector3.new(W, bodyH, L), CFrame.new(0, wheelR + bodyH / 2 - 0.2, 0), paint)
	if car.variant == "Chrome" then
		body.Material = Enum.Material.Metal
		body.Reflectance = 0.25
	end
	-- the greenhouse: a roof block with raked glass wedges front and back, so the silhouette
	-- reads as a car rather than two stacked boxes
	local cabinL = L * f.cabin
	local cabinH = H * 0.42
	local cabinY = wheelR + bodyH + cabinH / 2 - 0.25
	local cabinZ = L * f.cabinAt
	local rake = math.min(cabinL * 0.28, cabinH * 1.1)
	local glassColour = Color3.fromRGB(40, 56, 84)
	local roof = part(
		m,
		"Roof",
		Vector3.new(W * 0.84, cabinH, math.max(cabinL - 2 * rake, 0.4)),
		CFrame.new(0, cabinY, cabinZ),
		paint:Lerp(Color3.new(1, 1, 1), 0.1)
	)
	local sideGlass = part(
		m,
		"SideGlass",
		Vector3.new(W * 0.86, cabinH * 0.62, math.max(cabinL - 2 * rake, 0.4)),
		roof.CFrame * CFrame.new(0, -0.05, 0),
		glassColour
	)
	sideGlass.Material = Enum.Material.Glass
	for _, dir in { -1, 1 } do
		-- a WedgePart slopes down toward +Z; turned so each slope faces away from the roof
		local w = Instance.new("WedgePart")
		w.Name = if dir < 0 then "Windscreen" else "RearGlass"
		w.Anchored = true
		w.CanCollide = false
		w.CanQuery = false
		w.CanTouch = false
		w.Size = Vector3.new(W * 0.84, cabinH, rake)
		w.CFrame = CFrame.new(0, cabinY, cabinZ + dir * (cabinL / 2 - rake / 2))
			* CFrame.Angles(0, if dir < 0 then 0 else math.pi, 0)
		w.Color = glassColour
		w.Material = Enum.Material.Glass
		w.Parent = m
	end
	-- bumpers and a skirt in a darker trim tone
	local trim = paint:Lerp(Color3.new(0, 0, 0), 0.55)
	for _, dir in { -1, 1 } do
		part(
			m,
			"Bumper",
			Vector3.new(W * 1.01, bodyH * 0.28, 0.5),
			CFrame.new(0, wheelR + 0.15, dir * (L / 2 - 0.2)),
			trim
		)
	end
	part(m, "Skirt", Vector3.new(W * 1.01, bodyH * 0.18, L * 0.7), CFrame.new(0, wheelR - bodyH * 0.25, 0), trim)
	if car.variant == "Rainbow" then
		local stripes = {
			Color3.fromRGB(255, 90, 90),
			Color3.fromRGB(255, 200, 60),
			Color3.fromRGB(90, 220, 120),
			Color3.fromRGB(80, 160, 255),
			Color3.fromRGB(190, 110, 255),
		}
		for i, c in stripes do
			part(
				m,
				"Stripe" .. i,
				Vector3.new(W + 0.05, bodyH * 0.12, L * 0.9),
				body.CFrame * CFrame.new(0, -bodyH * 0.3 + i * bodyH * 0.12, 0),
				c
			)
		end
	end
	local wheelColour = Color3.fromRGB(34, 36, 44)
	local wheels = if car.family == "Motorcycle"
		then { { 0, -1 }, { 0, 1 } }
		else { { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } }
	for _, w in wheels do
		local x = w[1] * (W / 2 - 0.1)
		local z = w[2] * (L / 2 - wheelR * 1.4)
		part(
			m,
			"Wheel",
			Vector3.new(0.9, wheelR * 2, wheelR * 2),
			CFrame.new(x, wheelR, z),
			wheelColour,
			Enum.PartType.Cylinder
		)
	end
	-- lamps: pale front, red rear (orientation cue)
	part(
		m,
		"Headlamps",
		Vector3.new(W * 0.7, 0.35, 0.1),
		CFrame.new(0, wheelR + bodyH * 0.65, -L / 2 - 0.02),
		Color3.fromRGB(255, 246, 210)
	).Material =
		Enum.Material.Neon
	part(
		m,
		"TailLamps",
		Vector3.new(W * 0.7, 0.35, 0.1),
		CFrame.new(0, wheelR + bodyH * 0.65, L / 2 + 0.02),
		Color3.fromRGB(220, 40, 50)
	).Material =
		Enum.Material.Neon
	m.PrimaryPart = body
	return m
end

return ProxyCar
