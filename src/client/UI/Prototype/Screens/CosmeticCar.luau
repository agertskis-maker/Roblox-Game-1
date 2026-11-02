--!strict
-- CosmeticCar: the preview CAR and the card THUMBNAILS for the customization screen (Lane 3, Round 2 N12-03c; PREVIEW).
-- It draws the paint, decals and wheels of CosmeticPreviewCatalog onto ONE disposable part-built turntable car (a neutral
-- ProxyCar, never one of Brian L's models) and as static 2D thumbnails for the item cards.
--
--   CosmeticCar.newRig(parent) -> Rig                  -- the stage (platform + marks) and the car, built once
--   CosmeticCar.setPaint(rig, item?, phase?)           -- a paint item (nil = plain blue); only changed colours are written
--   CosmeticCar.tickPaint(rig, phase)                  -- animated paints only: one shared phase in 0..1, about 12 times a second
--   CosmeticCar.setDecal(rig, item?)  CosmeticCar.setWheels(rig, item?)
--   CosmeticCar.drawThumb(holder, item)                -- a static thumbnail in a square holder (no ViewportFrame per card)
--   CosmeticCar.isAnimated(item?) -> boolean           CosmeticCar.sample(colours, t, cyclic) -> Color3
--   CosmeticCar.flatteringPhase                        -- the frozen phase used under reduced motion
--
-- HOW PAINT IS RENDERED (N12-03c): a UIGradient cannot paint a 3D car, so a body-only region (the lower body box) carries SIX thin
-- band parts that are recoloured; glass, lamps, tyres and trim are excluded (trim just follows the main colour). Solid and metallic
-- paints colour the body box directly; pearl and two-tone are a six-step blend front to rear; animated paints sample a cyclic
-- palette (one shared phase, updated by the screen at 10 to 15 Hz while it is shown and moving). These are colour CYCLES and
-- six-band blends, not shaders or textures: "Galaxy Drift" has no stars, "Lava Cruise" no lava pattern, a pearl has no real sheen.
-- A part count is bounded: 6 bands, at most about 60 decal parts and 70 wheel parts for the whole car.
--
-- DECALS and WHEELS are data (DESIGNS and WHEEL_DESIGNS below) drawn from the same description in 3D and in 2D, so the card always
-- shows what the car shows. A decal design lives in a 1.6 : 1 rectangle laid on the hood (stripes, bolts) or on each door side
-- (mirrored to both sides, never stretched over glass or lamps); the one swatch-only design is "Dust Devil" (a curl needs curved
-- geometry), and the screen says "Card preview only" for it.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Prototype = script.Parent.Parent
local Arcade = require(Prototype.Arcade)
local Catalog = require(ReplicatedStorage.Shared.UI.CosmeticPreviewCatalog)
local ProxyCar = require(Prototype.ProxyCar)

local make = Arcade.make

local CosmeticCar = {}

CosmeticCar.flatteringPhase = 0.18
local BANDS = 6
local ASPECT = 1.6 -- every decal design is a 1.6 : 1 rectangle
local CAR_LENGTH = 12.5

type Item = Catalog.Item

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

-- COLOUR ---------------------------------------------------------------------------------------------------------------------

-- A colour from a palette at t in 0..1 (the ends are the first and last colour), or around a loop when `cyclic`.
function CosmeticCar.sample(cols: { Color3 }, t: number, cyclic: boolean): Color3
	local n = #cols
	if n == 0 then
		return Color3.new(1, 1, 1)
	elseif n == 1 then
		return cols[1]
	end
	if cyclic then
		local x = (t % 1) * n
		local i = math.floor(x)
		return cols[i % n + 1]:Lerp(cols[(i + 1) % n + 1], x - i)
	end
	local x = math.clamp(t, 0, 1) * (n - 1)
	local i = math.floor(x)
	if i >= n - 1 then
		return cols[n]
	end
	return cols[i + 1]:Lerp(cols[i + 2], x - i)
end

function CosmeticCar.isAnimated(item: Item?): boolean
	return item ~= nil and item.kind == "animated"
end

local function colourSequence(cols: { Color3 }, cyclic: boolean): ColorSequence
	local n = #cols
	if n == 1 then
		return ColorSequence.new(cols[1])
	end
	local points: { ColorSequenceKeypoint } = {}
	local last = if cyclic then n else n - 1
	for i = 1, n do
		table.insert(points, ColorSequenceKeypoint.new((i - 1) / last, cols[i]))
	end
	if cyclic then
		table.insert(points, ColorSequenceKeypoint.new(1, cols[1]))
	end
	return ColorSequence.new(points)
end

-- DESIGNS: DECALS ----------------------------------------------------------------------------------------------------------------

type Prim = { s: string, x: number, y: number, w: number, h: number, r: number?, c: number }

-- x, y, w, h are fractions of the 1.6 : 1 design rectangle (w of its width, h of its height); a "disc" or "ring" takes its DIAMETER in
-- w as a fraction of the rectangle HEIGHT; r is a clockwise turn in degrees; c is an index into the item's accent colours.
local function slab(x: number, y: number, w: number, h: number, r: number?, c: number?): Prim
	return { s = "slab", x = x, y = y, w = w, h = h, r = r, c = c or 1 }
end
local function disc(x: number, y: number, d: number, c: number?): Prim
	return { s = "disc", x = x, y = y, w = d, h = d, c = c or 1 }
end
local function ring(x: number, y: number, d: number, c: number?): Prim
	return { s = "ring", x = x, y = y, w = d, h = d, c = c or 1 }
end
local function cross(list: { Prim }, x: number, y: number, arm: number, c: number)
	table.insert(list, slab(x, y, arm / ASPECT, arm * 0.26, nil, c))
	table.insert(list, slab(x, y, arm * 0.26 / ASPECT, arm, nil, c))
end

type Design = { surface: string, prims: { Prim } }

local function build(surface: string, fn: (list: { Prim }) -> ()): Design
	local list: { Prim } = {}
	fn(list)
	return { surface = surface, prims = list }
end

local DESIGNS: { [string]: Design } = {
	twin_sprint = build("hood", function(l)
		table.insert(l, slab(0.33, 0.5, 0.2, 1, nil, 1))
		table.insert(l, slab(0.68, 0.56, 0.2, 0.88, nil, 1))
	end),
	side_slash = build("side", function(l)
		table.insert(l, slab(0.5, 0.45, 0.8, 0.2, -22, 1))
		table.insert(l, slab(0.5, 0.72, 0.6, 0.08, -22, 2))
	end),
	checker_corner = build("side", function(l)
		table.insert(l, slab(0.5, 0.5, 0.74, 0.62, nil, 1))
		for r = 0, 2 do
			for c = 0, 3 do
				if (r + c) % 2 == 0 then
					table.insert(l, slab(0.13 + 0.185 * (c + 0.5), 0.2 + 0.2 * (r + 0.5), 0.185, 0.2, nil, 2))
				end
			end
		end
	end),
	lucky_seven = build("side", function(l)
		table.insert(l, disc(0.5, 0.5, 0.82, 1))
		table.insert(l, slab(0.5, 0.33, 0.26, 0.1, nil, 2))
		table.insert(l, slab(0.52, 0.58, 0.07, 0.44, 16, 2))
	end),
	comet_tail = build("hood", function(l)
		table.insert(l, slab(0.42, 0.4, 0.3, 0.16, 18, 1))
		table.insert(l, slab(0.56, 0.5, 0.28, 0.11, 18, 1))
		table.insert(l, slab(0.7, 0.6, 0.22, 0.08, 18, 2))
		table.insert(l, slab(0.82, 0.69, 0.14, 0.05, 18, 2))
		table.insert(l, disc(0.24, 0.3, 0.3, 1))
		table.insert(l, disc(0.24, 0.3, 0.12, 2))
	end),
	zigzag_charge = build("hood", function(l)
		table.insert(l, slab(0.5, 0.18, 0.45, 0.2, 26, 1))
		table.insert(l, slab(0.5, 0.5, 0.45, 0.2, -26, 1))
		table.insert(l, slab(0.5, 0.82, 0.45, 0.2, 26, 1))
	end),
	friendly_fangs = build("hood", function(l)
		table.insert(l, slab(0.5, 0.09, 0.96, 0.14, nil, 2))
		for i = 0, 5 do
			table.insert(l, slab(0.1 + i * 0.16, 0.24, 0.1, 0.16, 45, 1))
		end
	end),
	bubble_burst = build("side", function(l)
		table.insert(l, disc(0.38, 0.55, 0.55, 1))
		table.insert(l, disc(0.58, 0.4, 0.4, 2))
		table.insert(l, disc(0.66, 0.64, 0.32, 1))
	end),
	summit_steps = build("side", function(l)
		table.insert(l, slab(0.5, 0.82, 0.8, 0.2, nil, 1))
		table.insert(l, slab(0.5, 0.6, 0.6, 0.2, nil, 2))
		table.insert(l, slab(0.5, 0.38, 0.4, 0.2, nil, 1))
		table.insert(l, slab(0.5, 0.16, 0.2, 0.2, nil, 2))
	end),
	dust_devil = build("side", function(l)
		table.insert(l, ring(0.5, 0.5, 0.86, 1))
		table.insert(l, ring(0.52, 0.5, 0.56, 2))
		table.insert(l, disc(0.5, 0.5, 0.22, 1))
	end),
	star_scatter = build("hood", function(l)
		cross(l, 0.2, 0.2, 0.3, 1)
		cross(l, 0.72, 0.28, 0.2, 2)
		cross(l, 0.42, 0.6, 0.26, 1)
		cross(l, 0.84, 0.78, 0.22, 1)
		cross(l, 0.16, 0.84, 0.16, 2)
	end),
	circuit_lines = build("hood", function(l)
		table.insert(l, slab(0.3, 0.3, 0.4, 0.07, nil, 1))
		table.insert(l, slab(0.5, 0.52, 0.04, 0.46, nil, 1))
		table.insert(l, slab(0.72, 0.75, 0.4, 0.07, nil, 1))
		table.insert(l, disc(0.1, 0.3, 0.16, 2))
		table.insert(l, disc(0.5, 0.28, 0.14, 2))
		table.insert(l, disc(0.92, 0.75, 0.16, 2))
	end),
	solar_flare = build("side", function(l)
		table.insert(l, slab(0.34, 0.62, 0.5, 0.22, -8, 1))
		table.insert(l, slab(0.4, 0.46, 0.4, 0.16, -14, 2))
		table.insert(l, slab(0.46, 0.3, 0.28, 0.12, -20, 3))
		table.insert(l, slab(0.26, 0.82, 0.34, 0.14, -6, 1))
	end),
	night_orbit = build("side", function(l)
		table.insert(l, ring(0.5, 0.5, 0.74, 1))
		table.insert(l, disc(0.27, 0.4, 0.13, 2))
		table.insert(l, disc(0.73, 0.6, 0.1, 2))
		table.insert(l, disc(0.58, 0.18, 0.08, 2))
	end),
	checkered_comet = build("hood", function(l)
		for r = 0, 1 do
			for c = 0, 2 do
				table.insert(
					l,
					slab(0.16 + 0.12 * c, 0.12 + 0.15 * r, 0.12, 0.15, nil, if (r + c) % 2 == 0 then 2 else 1)
				)
			end
		end
		table.insert(l, slab(0.55, 0.5, 0.3, 0.14, 20, 3))
		table.insert(l, slab(0.7, 0.62, 0.26, 0.1, 20, 3))
		table.insert(l, slab(0.84, 0.74, 0.2, 0.07, 20, 1))
	end),
}

-- DESIGNS: WHEELS ----------------------------------------------------------------------------------------------------------------

-- Radii are fractions of the TYRE radius. disc: d = diameter. spokes: n of them, len, w (width), rot (start), sweep (a turn that makes
-- them swept). dots: n small discs on a circle of radius r with diameter d. treads: n blocks on the tyre, h tall (kept small: the
-- tyre size never changes), wd wide. ring: a coloured disc of diameter d whose inner part (diameter d minus twice thick) is colour ic.
type Layer = {
	s: string,
	d: number?,
	c: number,
	n: number?,
	len: number?,
	w: number?,
	rot: number?,
	sweep: number?,
	r: number?,
	h: number?,
	wd: number?,
	thick: number?,
	ic: number?,
	neon: boolean?,
}

local function L(s: string, c: number, fields: { [string]: any }): Layer
	local layer: any = table.clone(fields)
	layer.s = s
	layer.c = c
	return layer :: Layer
end

local WHEEL_DESIGNS: { [string]: { Layer } } = {
	stock_five = {
		L("disc", 1, { d = 0.66 }),
		L("spokes", 2, { n = 5, len = 0.5, w = 0.2 }),
		L("disc", 3, { d = 0.22 }),
	},
	rally_block = {
		L("disc", 2, { d = 0.72 }),
		L("spokes", 1, { n = 4, len = 0.6, w = 0.3, rot = 45 }),
		L("disc", 3, { d = 0.2 }),
	},
	classic_disc = {
		L("disc", 1, { d = 0.74 }),
		L("dots", 2, { n = 6, r = 0.4, d = 0.1 }),
		L("disc", 3, { d = 0.2 }),
		L("disc", 2, { d = 0.1 }),
	},
	split_six = {
		L("disc", 2, { d = 0.7 }),
		L("spokes", 1, { n = 6, len = 0.58, w = 0.09, rot = -9 }),
		L("spokes", 1, { n = 6, len = 0.58, w = 0.09, rot = 9 }),
		L("disc", 3, { d = 0.2 }),
	},
	trail_chunk = {
		L("treads", 3, { n = 8, h = 0.07, wd = 0.3 }),
		L("disc", 2, { d = 0.6 }),
		L("spokes", 1, { n = 6, len = 0.46, w = 0.14 }),
		L("disc", 3, { d = 0.18 }),
	},
	star_runner = {
		L("disc", 2, { d = 0.7 }),
		L("spokes", 1, { n = 5, len = 0.62, w = 0.34 }),
		L("disc", 3, { d = 0.3 }),
	},
	golden_turbine = {
		L("disc", 2, { d = 0.7 }),
		L("spokes", 1, { n = 10, len = 0.62, w = 0.1, sweep = 24 }),
		L("disc", 3, { d = 0.2 }),
	},
	neon_halo = {
		L("ring", 3, { d = 0.84, thick = 0.07, ic = 1 }),
		L("spokes", 2, { n = 5, len = 0.4, w = 0.12 }),
		L("disc", 3, { d = 0.16 }),
	},
	moon_dish = {
		L("disc", 1, { d = 0.78 }),
		L("disc", 2, { d = 0.52 }),
		L("disc", 3, { d = 0.2 }),
	},
	monster_mini = {
		L("treads", 3, { n = 10, h = 0.09, wd = 0.28 }),
		L("disc", 2, { d = 0.5 }),
		L("spokes", 1, { n = 5, len = 0.4, w = 0.16 }),
		L("disc", 3, { d = 0.18 }),
	},
}

-- THE RIG -----------------------------------------------------------------------------------------------------------------------

export type Rig = {
	stage: Model,
	car: Model,
	body: BasePart,
	roof: BasePart,
	trim: { BasePart },
	bands: { Part },
	decals: Folder,
	wheelTrim: Folder,
	wheels: { BasePart },
	length: number,
	width: number,
	bodyHeight: number,
	hood: { z: number, len: number, w: number, y: number },
	side: { len: number, h: number, y: number, x: number },
	paint: Item?,
	decal: Item?,
	wheel: Item?,
	decalParts: number,
	wheelParts: number,
}

local function plainPart(
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
	p.CastShadow = false
	p.Size = size
	p.CFrame = cf
	p.Color = colour
	p.Material = Enum.Material.SmoothPlastic
	if shape then
		p.Shape = shape
	end
	p.Parent = parent
	return p
end

function CosmeticCar.newRig(parent: Instance): Rig
	local stage = Instance.new("Model")
	stage.Name = "Stage"
	stage.WorldPivot = CFrame.identity -- turn the stage about the middle of the platform, never about its bounding box
	local flat = CFrame.Angles(0, 0, math.pi / 2)
	plainPart(
		stage,
		"Platform",
		Vector3.new(0.6, 24, 24),
		CFrame.new(0, -0.3, 0) * flat,
		rgb(70, 84, 130),
		Enum.PartType.Cylinder
	)
	local rim = plainPart(
		stage,
		"NeonRim",
		Vector3.new(0.3, 25.4, 25.4),
		CFrame.new(0, -0.55, 0) * flat,
		rgb(60, 200, 255),
		Enum.PartType.Cylinder
	)
	rim.Material = Enum.Material.Neon
	for i = 0, 3 do
		-- four marks round the rim, so the turn can be seen
		local a = i * math.pi / 2
		plainPart(
			stage,
			"StageMark" .. i,
			Vector3.new(1.4, 0.06, 3.2),
			CFrame.new(math.sin(a) * 10, 0.03, math.cos(a) * 10) * CFrame.Angles(0, a, 0),
			rgb(247, 200, 58)
		)
	end
	local car = ProxyCar.build({
		name = "Preview",
		family = "Sedan",
		paint = rgb(40, 120, 232),
		length = CAR_LENGTH,
	})
	car.Parent = stage
	local body = car:FindFirstChild("Body") :: BasePart
	local roof = car:FindFirstChild("Roof") :: BasePart
	local trim: { BasePart } = {}
	local wheels: { BasePart } = {}
	for _, d in car:GetChildren() do
		if d:IsA("BasePart") then
			if d.Name == "Bumper" or d.Name == "Skirt" then
				table.insert(trim, d)
			elseif d.Name == "Wheel" then
				table.insert(wheels, d)
			end
		end
	end
	-- six thin bands over the body box (not the bumpers): the only things a blended or animated paint recolours
	local bands: { Part } = {}
	local segment = (CAR_LENGTH - 1) / BANDS
	for i = 1, BANDS do
		local z = -CAR_LENGTH / 2 + 0.5 + (i - 0.5) * segment
		local b = plainPart(
			car,
			"PaintBand" .. i,
			Vector3.new(body.Size.X + 0.08, body.Size.Y + 0.08, segment + 0.02),
			CFrame.new(0, body.Position.Y, z),
			body.Color
		)
		b.Transparency = 1
		table.insert(bands, b)
	end
	local decals = Instance.new("Folder")
	decals.Name = "Decals"
	decals.Parent = stage
	local wheelTrim = Instance.new("Folder")
	wheelTrim.Name = "WheelTrim"
	wheelTrim.Parent = stage
	stage.Parent = parent
	local bodyTop = body.Position.Y + body.Size.Y / 2 + 0.04
	local frontZ = -CAR_LENGTH / 2 + 0.9
	local cabinFront = -CAR_LENGTH * 0.24
	return {
		stage = stage,
		car = car,
		body = body,
		roof = roof,
		trim = trim,
		bands = bands,
		decals = decals,
		wheelTrim = wheelTrim,
		wheels = wheels,
		length = CAR_LENGTH,
		width = body.Size.X,
		bodyHeight = body.Size.Y,
		hood = { z = (frontZ + cabinFront) / 2, len = cabinFront - frontZ, w = body.Size.X * 0.8, y = bodyTop },
		side = {
			len = CAR_LENGTH * 0.46,
			h = body.Size.Y * 0.8,
			y = body.Position.Y + 0.05,
			x = body.Size.X / 2 + 0.07,
		},
		paint = nil,
		decal = nil,
		wheel = nil,
		decalParts = 0,
		wheelParts = 0,
	}
end

-- PAINT ---------------------------------------------------------------------------------------------------------------------------

local function setBody(rig: Rig, colour: Color3, material: Enum.Material, reflectance: number)
	rig.body.Color = colour
	rig.body.Material = material
	rig.body.Reflectance = reflectance
	for _, t in rig.trim do
		t.Color = colour:Lerp(Color3.new(0, 0, 0), 0.55)
	end
end

local function setRoof(rig: Rig, colour: Color3, material: Enum.Material)
	rig.roof.Color = colour
	rig.roof.Material = material
end

local function showBands(rig: Rig, on: boolean, material: Enum.Material?, reflectance: number?)
	for _, b in rig.bands do
		b.Transparency = if on then 0 else 1
		if on then
			b.Material = material or Enum.Material.SmoothPlastic
			b.Reflectance = reflectance or 0
		end
	end
end

-- Recolours the bands of an animated paint at `phase` (0..1). Cheap: six colours, no instances created.
function CosmeticCar.tickPaint(rig: Rig, phase: number)
	local item = rig.paint
	if not item or item.kind ~= "animated" then
		return
	end
	local cols = item.colours
	for i, b in rig.bands do
		b.Color = CosmeticCar.sample(cols, phase + (i - 0.5) / BANDS, true)
	end
	local base = CosmeticCar.sample(cols, phase, true)
	setBody(rig, base, Enum.Material.SmoothPlastic, 0.05)
	setRoof(rig, CosmeticCar.sample(cols, phase + 0.5, true), Enum.Material.SmoothPlastic)
end

function CosmeticCar.setPaint(rig: Rig, item: Item?, phase: number?)
	rig.paint = item
	local plastic = Enum.Material.SmoothPlastic
	if item == nil then
		showBands(rig, false)
		setBody(rig, rgb(40, 120, 232), plastic, 0)
		setRoof(rig, rgb(40, 120, 232):Lerp(Color3.new(1, 1, 1), 0.1), plastic)
		return
	end
	local cols = item.colours
	local kind = item.kind or "solid"
	if kind == "solid" then
		showBands(rig, false)
		setBody(rig, cols[1], plastic, 0)
		setRoof(rig, cols[1]:Lerp(Color3.new(1, 1, 1), 0.1), plastic)
	elseif kind == "metallic" then
		showBands(rig, false)
		setBody(rig, cols[2], Enum.Material.Metal, 0.2)
		setRoof(rig, cols[1], Enum.Material.Metal)
	elseif kind == "pearl" or kind == "gradient" then
		showBands(rig, true, plastic, if kind == "pearl" then 0.1 else 0)
		for i, b in rig.bands do
			b.Color = CosmeticCar.sample(cols, (i - 0.5) / BANDS, false)
		end
		local mid = CosmeticCar.sample(cols, 0.5, false)
		setBody(rig, mid, plastic, 0)
		setRoof(rig, mid:Lerp(Color3.new(1, 1, 1), if kind == "pearl" then 0.3 else 0.1), plastic)
	else
		showBands(rig, true, plastic, 0.05)
		CosmeticCar.tickPaint(rig, phase or CosmeticCar.flatteringPhase)
	end
end

-- DECALS ---------------------------------------------------------------------------------------------------------------------------

local DECAL_THICK = 0.05

-- One flat part on the hood (surface "hood", the plane is X by Z) or on the door sides (the plane is Z by Y, mirrored on both sides).
-- ux, vy are studs from the design's centre; rot is a clockwise turn in degrees; a disc is a cylinder lying on the surface.
local function lay(
	rig: Rig,
	surface: string,
	cx: number,
	cy: number,
	lenU: number,
	lenV: number,
	rot: number,
	colour: Color3,
	asDisc: boolean,
	neon: boolean?
)
	local thick = DECAL_THICK
	if surface == "hood" then
		local h = rig.hood
		local cf = CFrame.new(cx, h.y + thick / 2, h.z + cy) * CFrame.Angles(0, -math.rad(rot), 0)
		local part: Part
		if asDisc then
			part = plainPart(
				rig.decals,
				"Decal",
				Vector3.new(thick, lenU, lenU),
				cf * CFrame.Angles(0, 0, math.pi / 2),
				colour,
				Enum.PartType.Cylinder
			)
		else
			part = plainPart(rig.decals, "Decal", Vector3.new(lenU, thick, lenV), cf, colour)
		end
		if neon then
			part.Material = Enum.Material.Neon
		end
		rig.decalParts += 1
	else
		local s = rig.side
		for _, sign in { 1, -1 } do
			-- viewed from outside, the design's right is -Z on the +X side and +Z on the -X side, so it reads the same on both
			local z = -sign * cx
			local cf = CFrame.new(sign * s.x, s.y - cy, z) * CFrame.Angles(-sign * math.rad(rot), 0, 0)
			local part: Part
			if asDisc then
				part =
					plainPart(rig.decals, "Decal", Vector3.new(thick, lenU, lenU), cf, colour, Enum.PartType.Cylinder)
			else
				part = plainPart(rig.decals, "Decal", Vector3.new(thick, lenV, lenU), cf, colour)
			end
			if neon then
				part.Material = Enum.Material.Neon
			end
			rig.decalParts += 1
		end
	end
end

function CosmeticCar.setDecal(rig: Rig, item: Item?)
	rig.decal = item
	rig.decals:ClearAllChildren()
	rig.decalParts = 0
	if item == nil or item.isNone or item.render == "swatch" then
		return
	end
	local design = DESIGNS[item.id]
	if not design then
		return
	end
	local cols = item.colours
	-- the design rectangle fits the surface: it never grows past it
	local regionW, regionH
	if design.surface == "hood" then
		regionW, regionH = rig.hood.w, rig.hood.len
	else
		regionW, regionH = rig.side.len, rig.side.h
	end
	local s = math.min(regionH, regionW / ASPECT)
	for _, p in design.prims do
		local colour = cols[math.min(p.c, #cols)]
		local ux = (p.x - 0.5) * ASPECT * s
		local vy = (p.y - 0.5) * s
		if p.s == "slab" then
			lay(rig, design.surface, ux, vy, p.w * ASPECT * s, p.h * s, p.r or 0, colour, false)
		elseif p.s == "disc" then
			lay(rig, design.surface, ux, vy, p.w * s, p.w * s, 0, colour, true)
		else
			-- a ring is ten short blocks round a circle
			local radius = p.w * s / 2
			local count = 10
			local arc = 2 * math.pi * radius / count * 1.18
			for k = 0, count - 1 do
				local phi = k * 2 * math.pi / count
				lay(
					rig,
					design.surface,
					ux + radius * math.cos(phi),
					vy + radius * math.sin(phi),
					arc,
					s * 0.07,
					math.deg(phi) + 90,
					colour,
					false
				)
			end
		end
	end
end

-- WHEELS --------------------------------------------------------------------------------------------------------------------------

function CosmeticCar.setWheels(rig: Rig, item: Item?)
	rig.wheel = item
	rig.wheelTrim:ClearAllChildren()
	rig.wheelParts = 0
	local layers = if item then WHEEL_DESIGNS[item.id] else nil
	if item == nil or layers == nil then
		return
	end
	local cols = item.colours
	for _, w in rig.wheels do
		local side = if w.Position.X >= 0 then 1 else -1
		local radius = w.Size.Y / 2
		local thick = w.Size.X
		local origin = w.Position
		for index, layer in layers do
			local colour = cols[math.min(layer.c, #cols)]
			local x = origin.X + side * (thick / 2 + 0.02 + (index - 1) * 0.045)
			local centre = CFrame.new(x, origin.Y, origin.Z)
			local function put(name: string, size: Vector3, cf: CFrame, c: Color3, round: boolean, neon: boolean?)
				local p = plainPart(rig.wheelTrim, name, size, cf, c, if round then Enum.PartType.Cylinder else nil)
				if neon then
					p.Material = Enum.Material.Neon
				end
				rig.wheelParts += 1
			end
			if layer.s == "disc" then
				local d = (layer.d or 0.5) * radius * 2
				put("Disc", Vector3.new(0.05, d, d), centre, colour, true)
			elseif layer.s == "ring" then
				local d = (layer.d or 0.8) * radius * 2
				put("RingOuter", Vector3.new(0.05, d, d), centre, colour, true, true)
				local inner = cols[math.min(layer.ic or 1, #cols)]
				local di = d - 2 * (layer.thick or 0.06) * radius * 2
				put("RingInner", Vector3.new(0.05, di, di), centre * CFrame.new(side * 0.03, 0, 0), inner, true)
			elseif layer.s == "spokes" then
				local n = layer.n or 5
				local length = (layer.len or 0.5) * radius
				for k = 0, n - 1 do
					local a = math.rad((layer.rot or 0) + k * 360 / n)
					-- a swept spoke starts a little off the hub and leans: it is not radial
					local lean = math.rad(layer.sweep or 0)
					local start = if layer.sweep then radius * 0.12 else 0
					local cf = centre
						* CFrame.Angles(a, 0, 0)
						* CFrame.new(0, start, 0)
						* CFrame.Angles(lean, 0, 0)
						* CFrame.new(0, length / 2, 0)
					put("Spoke", Vector3.new(0.05, length, (layer.w or 0.16) * radius * 2), cf, colour, false)
				end
			elseif layer.s == "dots" then
				local n = layer.n or 6
				for k = 0, n - 1 do
					local a = k * 2 * math.pi / n
					local dd = (layer.d or 0.1) * radius * 2
					local cf = centre * CFrame.Angles(a, 0, 0) * CFrame.new(0, (layer.r or 0.3) * radius, 0)
					put("Dot", Vector3.new(0.05, dd, dd), cf, colour, true)
				end
			elseif layer.s == "treads" then
				local n = layer.n or 8
				local h = (layer.h or 0.07) * radius
				for k = 0, n - 1 do
					local a = k * 2 * math.pi / n
					local cf = CFrame.new(origin.X, origin.Y, origin.Z)
						* CFrame.Angles(a, 0, 0)
						* CFrame.new(0, radius + h / 2 - 0.02, 0)
					put("Tread", Vector3.new(thick * 0.92, h, (layer.wd or 0.25) * radius), cf, colour, false)
				end
			end
		end
	end
end

-- THUMBNAILS (static, 2D) --------------------------------------------------------------------------------------------------------------

local function frame(
	parent: Instance,
	name: string,
	x: number,
	y: number,
	w: number,
	h: number,
	colour: Color3,
	z: number,
	round: boolean?,
	rotation: number?
): Frame
	local f: Frame = make("Frame", {
		Name = name,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(x, y),
		Size = UDim2.fromOffset(w, h),
		Rotation = rotation or 0,
		BackgroundColor3 = colour,
		BorderSizePixel = 0,
		ZIndex = z,
		Parent = parent,
	})
	if round then
		make("UICorner", { CornerRadius = UDim.new(0.5, 0), Parent = f })
	end
	return f
end

local function drawPaintThumb(holder: Frame, item: Item, z: number)
	local swatch: Frame = make("Frame", {
		Name = "PaintSwatch",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		ZIndex = z,
		Parent = holder,
	})
	local cols = item.colours
	local kind = item.kind or "solid"
	if kind == "solid" then
		swatch.BackgroundColor3 = cols[1]
	elseif kind == "metallic" then
		-- a bright sweep reads as metal even in grey
		swatch.BackgroundColor3 = cols[2]
		make("UIGradient", {
			Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, cols[2]),
				ColorSequenceKeypoint.new(0.35, cols[1]),
				ColorSequenceKeypoint.new(0.6, cols[2]),
				ColorSequenceKeypoint.new(1, cols[1]:Lerp(cols[2], 0.4)),
			}),
			Rotation = 45,
			Parent = swatch,
		})
	elseif kind == "pearl" then
		make("UIGradient", { Color = colourSequence(cols, false), Rotation = 35, Parent = swatch })
		-- a pearl shine: a soft white sweep
		local shine: Frame = make("Frame", {
			Name = "Shine",
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = Color3.new(1, 1, 1),
			BorderSizePixel = 0,
			ZIndex = z + 1,
			Parent = swatch,
		})
		make("UIGradient", {
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(0.4, 0.55),
				NumberSequenceKeypoint.new(0.6, 1),
				NumberSequenceKeypoint.new(1, 1),
			}),
			Rotation = 60,
			Parent = shine,
		})
	elseif kind == "gradient" then
		-- two-tone: a clear split with a short blend
		make("UIGradient", {
			Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, cols[1]),
				ColorSequenceKeypoint.new(0.42, cols[1]),
				ColorSequenceKeypoint.new(0.58, cols[2]),
				ColorSequenceKeypoint.new(1, cols[2]),
			}),
			Rotation = 40,
			Parent = swatch,
		})
	else
		make("UIGradient", { Color = colourSequence(cols, true), Rotation = 30, Parent = swatch })
	end
end

local function drawDecalThumb(holder: Frame, item: Item, px: number, z: number)
	local back: Frame = make("Frame", {
		Name = "DecalBack",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = rgb(54, 84, 168),
		BorderSizePixel = 0,
		ClipsDescendants = true,
		ZIndex = z,
		Parent = holder,
	})
	if item.isNone then
		-- the cleared state: a ring with a slash, never an empty tile
		frame(back, "Ring", px / 2, px / 2, px * 0.54, px * 0.54, rgb(176, 188, 224), z + 1, true)
		frame(back, "Hole", px / 2, px / 2, px * 0.4, px * 0.4, rgb(54, 84, 168), z + 2, true)
		frame(back, "Slash", px / 2, px / 2, px * 0.08, px * 0.76, rgb(176, 188, 224), z + 3, false, 40)
		return
	end
	local design = DESIGNS[item.id]
	if not design then
		return
	end
	local rectW = px * 0.9
	local rectH = rectW / ASPECT
	local x0 = (px - rectW) / 2
	local y0 = (px - rectH) / 2
	-- a panel of "paint" under the design, so white designs show
	local panel = frame(back, "Panel", px / 2, px / 2, rectW + 4, rectH + 4, rgb(30, 50, 120), z + 1, false)
	Arcade.corner(panel, 4)
	local cols = item.colours
	for i, p in design.prims do
		local colour = cols[math.min(p.c, #cols)]
		local cx = x0 + p.x * rectW
		local cy = y0 + p.y * rectH
		if p.s == "slab" then
			frame(
				back,
				"P" .. i,
				cx,
				cy,
				math.max(p.w * rectW, 1.5),
				math.max(p.h * rectH, 1.5),
				colour,
				z + 2,
				false,
				p.r
			)
		elseif p.s == "disc" then
			local d = p.w * rectH
			frame(back, "P" .. i, cx, cy, d, d, colour, z + 2, true)
		else
			local d = p.w * rectH
			local r: Frame = frame(back, "P" .. i, cx, cy, d, d, colour, z + 2, true)
			r.BackgroundTransparency = 1
			make("UIStroke", {
				Thickness = math.max(2, d * 0.1),
				Color = colour,
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				Parent = r,
			})
		end
	end
end

local function drawWheelThumb(holder: Frame, item: Item, px: number, z: number)
	local back: Frame = make("Frame", {
		Name = "WheelBack",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = rgb(46, 62, 120),
		BorderSizePixel = 0,
		ClipsDescendants = true,
		ZIndex = z,
		Parent = holder,
	})
	local layers = WHEEL_DESIGNS[item.id]
	if not layers then
		return
	end
	local cols = item.colours
	local radius = px * 0.4
	local cx, cy = px / 2, px / 2
	local tyre = frame(back, "Tyre", cx, cy, radius * 2, radius * 2, rgb(20, 24, 38), z + 1, true)
	Arcade.outline(tyre, "Minor")
	for i, layer in layers do
		local colour = cols[math.min(layer.c, #cols)]
		local zi = z + 2 + i
		if layer.s == "disc" then
			local d = (layer.d or 0.5) * radius * 2
			frame(back, "Disc", cx, cy, d, d, colour, zi, true)
		elseif layer.s == "ring" then
			local d = (layer.d or 0.8) * radius * 2
			frame(back, "RingOuter", cx, cy, d, d, colour, zi, true)
			local di = d - 2 * (layer.thick or 0.06) * radius * 2
			frame(back, "RingInner", cx, cy, di, di, cols[math.min(layer.ic or 1, #cols)], zi, true)
		elseif layer.s == "spokes" then
			local n = layer.n or 5
			local length = (layer.len or 0.5) * radius
			for k = 0, n - 1 do
				local start = math.rad((layer.rot or 0) + k * 360 / n)
				local lean = math.rad(layer.sweep or 0)
				local off = if layer.sweep then radius * 0.12 else 0
				-- a spoke points along an angle measured clockwise from "up"; a swept one starts off the hub and leans
				local a = start + lean
				local px2 = cx + math.sin(start) * off + math.sin(a) * length / 2
				local py2 = cy - math.cos(start) * off - math.cos(a) * length / 2
				frame(
					back,
					"Spoke",
					px2,
					py2,
					math.max((layer.w or 0.16) * radius * 2, 2),
					length,
					colour,
					zi,
					false,
					math.deg(a)
				)
			end
		elseif layer.s == "dots" then
			local n = layer.n or 6
			local dd = math.max((layer.d or 0.1) * radius * 2, 2)
			for k = 0, n - 1 do
				local a = k * 2 * math.pi / n
				local rr = (layer.r or 0.3) * radius
				frame(back, "Dot", cx + math.sin(a) * rr, cy - math.cos(a) * rr, dd, dd, colour, zi, true)
			end
		elseif layer.s == "treads" then
			local n = layer.n or 8
			local h = (layer.h or 0.07) * radius
			for k = 0, n - 1 do
				local a = k * 2 * math.pi / n
				local rr = radius + h / 2 - 1
				frame(
					back,
					"Tread",
					cx + math.sin(a) * rr,
					cy - math.cos(a) * rr,
					math.max((layer.wd or 0.25) * radius, 3),
					math.max(h, 3),
					colour,
					zi,
					false,
					math.deg(a)
				)
			end
		end
	end
end

-- A static thumbnail of `item` filling the square `holder`. `px` is the holder's side in design px (for the shape sizes).
function CosmeticCar.drawThumb(holder: Frame, item: Item, px: number)
	holder:ClearAllChildren()
	local z = holder.ZIndex + 1
	if item.tab == "Paint" then
		drawPaintThumb(holder, item, z)
	elseif item.tab == "Decals" then
		drawDecalThumb(holder, item, px, z)
	else
		drawWheelThumb(holder, item, px, z)
	end
	-- the artwork is cut to the tile's own rounded corners (a child frame never follows its parent's corner)
	for _, child in holder:GetChildren() do
		if child:IsA("Frame") then
			make("UICorner", { CornerRadius = UDim.new(0, 7), Parent = child })
			for _, inner in child:GetChildren() do
				if inner:IsA("Frame") and inner.Name == "Shine" then
					make("UICorner", { CornerRadius = UDim.new(0, 7), Parent = inner })
				end
			end
		end
	end
end

return CosmeticCar
