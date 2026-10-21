--!strict
-- Ground and backdrop, greybox: the walking surface (a flat grass slab with the lake cut out
-- in rows), the lake as water-coloured rows just below the surface, the waterfall off the
-- portal axis, seven stepped mountain masses and the foothill and forest band round the arc.
-- Parts only, no terrain. All placeholders for the environment task.

local Kit = require(script.Parent.Parent.Parent.Kit)
local Layout = require(script.Parent.Parent.Layout)
local Palette = require(script.Parent.Parent.Parent.WorldPalette)

local Backdrop = {}

local SURFACE = Layout.SurfaceY
local W = Layout.planToWorld
local backdrop = Layout.Data.backdrop

Backdrop.HalfWidth = 820 -- ground reaches past the outer peaks
Backdrop.North = 720
Backdrop.South = -720
local ROW = 10
local GROUND_THICKNESS = 4

local function slab(
	parent: Instance,
	x0: number,
	x1: number,
	y0: number,
	y1: number,
	topY: number,
	options: Kit.PartOptions
)
	if x1 - x0 < 0.1 or y1 - y0 < 0.1 then
		return
	end
	Kit.part(
		parent,
		Vector3.new(x1 - x0, GROUND_THICKNESS, y1 - y0),
		CFrame.new((x0 + x1) / 2, topY - GROUND_THICKNESS / 2, -(y0 + y1) / 2),
		options
	)
end

local function buildGround(model: Model)
	local ground = Instance.new("Folder")
	ground.Name = "Ground"
	ground.Parent = model
	local lake = backdrop.lake
	local shoreN = lake.centre.Y + lake.ry
	local shoreS = lake.centre.Y - lake.ry
	local grass: Kit.PartOptions = { name = "Ground", color = Palette.Grass, collide = true, castShadow = false }
	local water: Kit.PartOptions = { name = "LakeWater", color = Palette.DeepWater, collide = true, castShadow = false }
	local hw = Backdrop.HalfWidth
	slab(ground, -hw, hw, shoreN, Backdrop.North, SURFACE, grass)
	slab(ground, -hw, hw, Backdrop.South, shoreS, SURFACE, grass)
	local y = shoreS
	while y < shoreN - 1e-6 do
		local y1 = math.min(y + ROW, shoreN)
		-- the row's half width is the ellipse's narrower edge, so water never shows past the shore line
		local edge = math.max(math.abs(y - lake.centre.Y), math.abs(y1 - lake.centre.Y)) / lake.ry
		local half = lake.rx * math.sqrt(math.max(0, 1 - edge * edge))
		slab(ground, -hw, lake.centre.X - half, y, y1, SURFACE, grass)
		slab(ground, lake.centre.X + half, hw, y, y1, SURFACE, grass)
		slab(ground, lake.centre.X - half, lake.centre.X + half, y, y1, SURFACE - 1, water)
		y = y1
	end
end

local function buildWaterfall(model: Model)
	local fall = backdrop.waterfall
	local folder = Instance.new("Model")
	folder.Name = "Waterfall"
	folder:SetAttribute("Placeholder", true)
	local top = fall.top
	Kit.part(
		folder,
		Vector3.new(fall.width + 24, fall.height, 30),
		CFrame.new(W(top - Vector2.new(0, 15), SURFACE + fall.height / 2)),
		{ name = "Cliff", color = Palette.Rock, collide = true }
	)
	Kit.part(
		folder,
		Vector3.new(fall.width, fall.height, 1),
		CFrame.new(W(top + Vector2.new(0, 0.8), SURFACE + fall.height / 2)),
		{
			name = "FallingWater",
			color = Palette.ShallowWater,
			material = Enum.Material.Neon,
			transparency = 0.35,
			castShadow = false,
		}
	)
	folder.Parent = model
end

local function stepColour(f: number, height: number): Color3
	if f < 0.25 then
		return Palette.Foliage
	elseif height >= 180 and f >= 0.7 then
		return Palette.Snow
	end
	return Palette.Rock
end

-- A stepped hill: discs shrinking upward.
local function mass(parent: Instance, name: string, centre: Vector2, radius: number, height: number, steps: number)
	local m = Instance.new("Model")
	m.Name = name
	m:SetAttribute("Placeholder", true)
	m:SetAttribute("Height", height)
	for k = 0, steps - 1 do
		local f = k / steps
		local topY = SURFACE + height * (k + 1) / steps
		Kit.disc(
			m,
			W(centre),
			radius * (1 - f * 0.85) * 2,
			height / steps,
			topY,
			{ name = "Step", color = if k == 0 then Palette.Foliage else Palette.Grass, collide = true }
		)
	end
	m.Parent = parent
	return m
end

-- A stepped peak: blocks shrinking upward, as wide as the diagram's ellipse and 0.62 as deep,
-- each step turned a little so the mass reads less regular.
local PEAK_DEPTH = 0.62
local function peak(parent: Instance, name: string, centre: Vector2, radius: number, height: number, steps: number)
	local m = Instance.new("Model")
	m.Name = name
	m:SetAttribute("Placeholder", true)
	m:SetAttribute("Height", height)
	for k = 0, steps - 1 do
		local f = k / steps
		local scale = 1 - f * 0.85
		local h = height / steps
		Kit.part(
			m,
			Vector3.new(radius * 2 * scale * 0.85, h, radius * 2 * PEAK_DEPTH * scale * 0.85),
			CFrame.new(W(centre, SURFACE + h * (k + 0.5))) * CFrame.Angles(0, math.rad((k % 2) * 8 - 4), 0),
			{ name = "Step", color = stepColour(f, height), collide = true }
		)
	end
	m.Parent = parent
	return m
end

local function pine(parent: Instance, at: Vector2, baseY: number, height: number)
	local trunk = height * 0.3
	Kit.part(
		parent,
		Vector3.new(1.5, trunk, 1.5),
		CFrame.new(W(at, baseY + trunk / 2)),
		{ name = "Trunk", color = Palette.Bark, collide = true }
	)
	for k = 0, 1 do
		local d = height * (0.55 - 0.2 * k)
		Kit.disc(
			parent,
			W(at),
			d,
			height * 0.35,
			baseY + trunk + height * 0.35 * (k + 1),
			{ name = "Canopy", color = Palette.Foliage, collide = true }
		)
	end
end

local function buildMountains(model: Model)
	local folder = Instance.new("Folder")
	folder.Name = "Mountains"
	folder.Parent = model
	for i, k in backdrop.peaks do
		peak(folder, string.format("Peak%02d", i), k.centre, k.radius, k.height, 5)
	end
end

local function buildFoothills(model: Model)
	local folder = Instance.new("Folder")
	folder.Name = "Foothills"
	folder.Parent = model
	local foot = backdrop.foothills
	local mid = (foot.inner + foot.outer) / 2
	local spots: { { at: Vector2, height: number } } = {}
	for b = -88, 88, 8 do
		table.insert(spots, { at = Layout.polar(b, mid), height = 30 + 60 * math.abs(math.sin(b * math.pi / 50)) })
	end
	-- the band wraps down both ends toward the mountains, outside the lake
	for _, side in { -1, 1 } do
		for _, p in { Vector2.new(600, -70), Vector2.new(560, -150), Vector2.new(470, -215), Vector2.new(370, -130) } do
			table.insert(spots, { at = Vector2.new(side * p.X, p.Y), height = 55 })
		end
	end
	for i, spot in spots do
		local hill = mass(folder, string.format("Hill%02d", i), spot.at, 50, spot.height, 2)
		local dir = spot.at.Unit
		local across = Vector2.new(-dir.Y, dir.X)
		for _, s in { -1, 1 } do
			pine(hill, spot.at + across * s * 12, SURFACE + spot.height, 22)
		end
	end
end

function Backdrop.build(model: Model)
	buildGround(model)
	buildWaterfall(model)
	buildMountains(model)
	buildFoothills(model)
end

return Backdrop
