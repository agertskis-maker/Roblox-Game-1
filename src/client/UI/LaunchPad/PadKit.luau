--!strict
-- PadKit: the building blocks of a Launch Pad (Lane 3, Launch Pad redesign), and its three skins. Every helper places in the pad's own
-- space: `origin` is the centre of the floor, +Z south, -Z north toward the ramp, y = 0 the walking floor. Decoration never collides.
-- Cylinders stand on their Y axis here (a Part cylinder's axis is its X).
--
--   local k = PadKit.new(folder, origin)
--   k:box(name, size, cf, colour, material?, solid?)    k:neon(...)    k:ball(name, diameter, cf, colour, material?)
--   k:cyl(name, diameter, height, cf, colour, material?, solid?)       k:wedge(name, size, cf, colour, material?, solid?)
--   k:mesh(name, id, palette?, size, cf)                k:model(name) -> a builder that places into a new Model
--   PadKit.Themes[world]

local PadKit = {}
PadKit.__index = PadKit

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

export type Theme = {
	title: string,
	roof: string, -- "Awning" | "Canopy" | "Chalet"
	sign: string, -- a SignKit style
	floor: Color3,
	floorMaterial: Enum.Material,
	panel: Color3,
	rim: Color3,
	under: Color3,
	stripeA: Color3,
	stripeB: Color3,
	pillar: Color3,
	trim: Color3,
	glow: Color3,
	kiosk: { [string]: { Color3 } }, -- per kiosk: main, second
	world: Color3,
	worldMaterial: Enum.Material,
	lighting: any,
	portal: Color3,
}

PadKit.Themes = {
	Downtown = {
		title = "DOWNTOWN LAUNCH PAD",
		roof = "Awning",
		sign = "Race",
		floor = rgb(36, 44, 92),
		floorMaterial = Enum.Material.SmoothPlastic,
		panel = rgb(58, 92, 168),
		rim = rgb(196, 204, 222),
		under = rgb(44, 50, 84),
		stripeA = rgb(255, 136, 30),
		stripeB = rgb(255, 196, 70),
		pillar = rgb(244, 232, 206),
		trim = rgb(240, 186, 60),
		glow = rgb(70, 190, 255),
		kiosk = {
			Cars = { rgb(255, 136, 30), rgb(250, 240, 222) },
			Trails = { rgb(40, 110, 220), rgb(250, 240, 222) },
			Paint = { rgb(232, 64, 92), rgb(250, 240, 222) },
		},
		world = rgb(36, 46, 78),
		worldMaterial = Enum.Material.SmoothPlastic,
		portal = rgb(64, 190, 255),
		lighting = {
			props = {
				ClockTime = 18.45,
				Brightness = 1.7,
				Ambient = rgb(92, 84, 130),
				OutdoorAmbient = rgb(128, 112, 160),
				EnvironmentDiffuseScale = 1,
				EnvironmentSpecularScale = 0.7,
				ExposureCompensation = 0.1,
				GlobalShadows = true,
				ShadowSoftness = 0.3,
				GeographicLatitude = 30,
				ColorShift_Top = rgb(255, 196, 150),
				ColorShift_Bottom = rgb(40, 30, 70),
			},
			atmosphere = {
				density = 0.32,
				offset = 0.2,
				colour = rgb(226, 150, 150),
				decay = rgb(92, 70, 150),
				haze = 1.8,
			},
			grade = { brightness = 0.02, contrast = 0.1, saturation = 0.2, tint = rgb(255, 240, 246) },
		},
	},
	DustyHighway = {
		title = "DUSTY HIGHWAY LAUNCH PAD",
		roof = "Canopy",
		sign = "Fuel",
		floor = rgb(226, 184, 136),
		floorMaterial = Enum.Material.Slate,
		panel = rgb(240, 208, 164),
		rim = rgb(250, 232, 200),
		under = rgb(156, 92, 64),
		stripeA = rgb(214, 70, 62),
		stripeB = rgb(52, 138, 138),
		pillar = rgb(250, 236, 208),
		trim = rgb(214, 70, 62),
		glow = rgb(255, 170, 70),
		kiosk = {
			Cars = { rgb(214, 70, 62), rgb(250, 236, 208) },
			Trails = { rgb(52, 138, 138), rgb(250, 236, 208) },
			Paint = { rgb(240, 150, 50), rgb(250, 236, 208) },
		},
		world = rgb(206, 124, 84),
		worldMaterial = Enum.Material.Sand,
		portal = rgb(90, 210, 240),
		lighting = {
			props = {
				ClockTime = 17.35,
				Brightness = 2.2,
				Ambient = rgb(132, 104, 92),
				OutdoorAmbient = rgb(186, 150, 120),
				EnvironmentDiffuseScale = 1,
				EnvironmentSpecularScale = 0.5,
				ExposureCompensation = 0,
				GlobalShadows = true,
				ShadowSoftness = 0.25,
				GeographicLatitude = 33,
				ColorShift_Top = rgb(255, 214, 160),
				ColorShift_Bottom = rgb(60, 30, 20),
			},
			atmosphere = {
				density = 0.26,
				offset = 0.22,
				colour = rgb(244, 190, 140),
				decay = rgb(200, 120, 110),
				haze = 1.7,
			},
			grade = { brightness = 0.02, contrast = 0.08, saturation = 0.18, tint = rgb(255, 242, 226) },
		},
	},
	SummitPass = {
		title = "SUMMIT PASS LAUNCH PAD",
		roof = "Chalet",
		sign = "Lodge",
		floor = rgb(150, 98, 62),
		floorMaterial = Enum.Material.WoodPlanks,
		panel = rgb(170, 116, 76),
		rim = rgb(244, 248, 255),
		under = rgb(120, 130, 150),
		stripeA = rgb(255, 150, 60),
		stripeB = rgb(248, 244, 236),
		pillar = rgb(116, 72, 42),
		trim = rgb(70, 44, 28),
		glow = rgb(255, 196, 110),
		kiosk = {
			Cars = { rgb(116, 72, 42), rgb(244, 248, 255) },
			Trails = { rgb(116, 72, 42), rgb(244, 248, 255) },
			Paint = { rgb(116, 72, 42), rgb(244, 248, 255) },
		},
		world = rgb(232, 240, 250),
		worldMaterial = Enum.Material.Snow,
		portal = rgb(110, 210, 255),
		lighting = {
			props = {
				ClockTime = 11,
				Brightness = 2.3,
				Ambient = rgb(122, 134, 156),
				OutdoorAmbient = rgb(168, 184, 208),
				EnvironmentDiffuseScale = 1,
				EnvironmentSpecularScale = 0.6,
				ExposureCompensation = -0.1,
				GlobalShadows = true,
				ShadowSoftness = 0.2,
				GeographicLatitude = 46,
				ColorShift_Top = rgb(255, 246, 232),
				ColorShift_Bottom = Color3.new(0, 0, 0),
			},
			atmosphere = {
				density = 0.24,
				offset = 0.2,
				colour = rgb(216, 232, 250),
				decay = rgb(140, 176, 216),
				haze = 1.4,
			},
			grade = { brightness = 0.02, contrast = 0.06, saturation = 0.12, tint = rgb(250, 252, 255) },
		},
	},
} :: { [string]: Theme }

function PadKit.new(parent: Instance, origin: CFrame): any
	return setmetatable({ parent = parent, origin = origin }, PadKit)
end

-- A builder over the same space that places into a new Model, so a group of pieces can move as one.
function PadKit.model(self: any, name: string): (any, Model)
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = self.parent
	return setmetatable({ parent = m, origin = self.origin }, PadKit), m
end

local function finish(self: any, p: BasePart, name: string, colour: Color3, material: Enum.Material?, solid: boolean?)
	p.Name = name
	p.Anchored = true
	p.CanCollide = solid == true
	p.CanQuery = solid == true
	p.CanTouch = false
	p.Color = colour
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CastShadow = p.Size.Magnitude > 3 and p.Material ~= Enum.Material.Neon
	p.Parent = self.parent
end

function PadKit.box(
	self: any,
	name: string,
	size: Vector3,
	cf: CFrame,
	colour: Color3,
	material: Enum.Material?,
	solid: boolean?
): Part
	local p = Instance.new("Part")
	p.Size = size
	p.CFrame = self.origin * cf
	finish(self, p, name, colour, material, solid)
	return p
end

function PadKit.neon(self: any, name: string, size: Vector3, cf: CFrame, colour: Color3): Part
	return self:box(name, size, cf, colour, Enum.Material.Neon)
end

function PadKit.ball(
	self: any,
	name: string,
	diameter: number,
	cf: CFrame,
	colour: Color3,
	material: Enum.Material?
): Part
	local p = Instance.new("Part")
	p.Shape = Enum.PartType.Ball
	p.Size = Vector3.one * diameter
	p.CFrame = self.origin * cf
	finish(self, p, name, colour, material)
	return p
end

function PadKit.cyl(
	self: any,
	name: string,
	diameter: number,
	height: number,
	cf: CFrame,
	colour: Color3,
	material: Enum.Material?,
	solid: boolean?
): Part
	local p = Instance.new("Part")
	p.Shape = Enum.PartType.Cylinder
	p.Size = Vector3.new(height, diameter, diameter)
	p.CFrame = self.origin * cf * CFrame.Angles(0, 0, math.pi / 2)
	finish(self, p, name, colour, material, solid)
	return p
end

function PadKit.wedge(
	self: any,
	name: string,
	size: Vector3,
	cf: CFrame,
	colour: Color3,
	material: Enum.Material?,
	solid: boolean?
): WedgePart
	local p = Instance.new("WedgePart")
	p.Size = size
	p.CFrame = self.origin * cf
	finish(self, p, name, colour, material, solid)
	return p
end

-- A kit mesh on a plain part, sized so it culls with what it draws. `size` is the size drawn for a unit mesh, or a scale for a sized one.
function PadKit.mesh(
	self: any,
	name: string,
	id: string,
	palette: string?,
	size: Vector3,
	cf: CFrame,
	bounds: Vector3?
): Part
	local p = Instance.new("Part")
	p.Size = bounds or size
	p.CFrame = self.origin * cf
	p.Transparency = 0
	finish(self, p, name, Color3.new(1, 1, 1))
	p.CastShadow = false
	local m = Instance.new("SpecialMesh")
	m.MeshType = Enum.MeshType.FileMesh
	m.MeshId = id
	m.TextureId = palette or ""
	m.Scale = size
	m.Parent = p
	return p
end

return PadKit
