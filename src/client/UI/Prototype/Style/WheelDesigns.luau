--!strict
-- WheelDesigns (Round 8, W-01, W-03): the data behind the sixteen rim designs. WheelKit reads it; nothing here makes an instance.
--
--   * rim / glow / stars: AssetIds.Wheels mesh keys (one rim mesh per design, a Neon glow layer for the glowing designs, drifting
--     stars for the Galaxy Disc). The tyre is shared (r8_wheel_tyre).
--   * BBOX: the exact bounding box of every mesh in the authoring frame (tyre radius 1, tyre half width 0.44, game axes: X is the
--     axle, the rim face looks toward +X). WheelKit stretches each MeshPart to that box times the car's tyre radius, so the
--     result does not depend on the scale the FBX importer picks. Written by Car-Hop-Art/blender-round8/build_all.py (stats.json).
--   * fallback: how WheelKit builds the design from plain parts while a mesh is not uploaded yet (or failed to load).

export type Fallback = {
	spokes: number,
	spokeWidth: number, -- fraction of the tyre radius
	spoke: Color3,
	rim: Color3, -- the lip
	hub: Color3,
	disc: Color3?, -- the face under the spokes
	solidFace: boolean?, -- no spokes: a whole domed face (white wall, galaxy)
	whiteWall: boolean?,
	stripe: Color3?,
	glowRing: boolean?,
	glowHub: boolean?,
	glowTread: boolean?,
	neonSpokes: boolean?,
}

export type Design = {
	id: string,
	name: string,
	rim: string, -- mesh key
	glow: string?, -- Neon layer mesh key
	glowFrame: ("rim" | "tyre")?, -- the layer lives in the rim's frame (default) or in the tyre's own frame
	stars: string?, -- drifting stars mesh key
	material: Enum.Material, -- the rim's own material (the glow layer is always Neon)
	reflectance: number,
	rimColor: Color3, -- Part.Color when vertex colours are off
	glowColor: Color3?,
	pulse: number?, -- seconds for one slow glow pulse
	flicker: boolean?, -- the pulse is a faster, uneven flicker (flames)
	drift: number?, -- radians per second the stars turn against the wheel
	animated: boolean, -- the pricier tiers: moves or glows
	fallback: Fallback,
}

export type Box = { number } -- xmin, xmax, ymin, ymax, zmin, zmax

local function c(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

local SILVER = c(204, 208, 219)
local STEEL = c(160, 166, 178)
local GUN = c(76, 80, 94)
local DARK = c(30, 33, 42)
local CYAN = c(30, 235, 255)
local GOLD = c(255, 200, 66)

local designs: { [string]: Design } = {
	multi_spoke = {
		id = "multi_spoke",
		name = "Multi-Spoke",
		rim = "r8_wheel_rim_multi_spoke",
		material = Enum.Material.Metal,
		reflectance = 0.05,
		rimColor = SILVER,
		animated = false,
		fallback = { spokes = 10, spokeWidth = 0.05, spoke = SILVER, rim = SILVER, hub = STEEL, disc = c(40, 42, 50) },
	},
	deep_dish = {
		id = "deep_dish",
		name = "Deep Dish",
		rim = "r8_wheel_rim_deep_dish",
		material = Enum.Material.Metal,
		reflectance = 0.05,
		rimColor = c(224, 229, 240),
		animated = false,
		fallback = {
			spokes = 5,
			spokeWidth = 0.15,
			spoke = GUN,
			rim = c(226, 230, 242),
			hub = STEEL,
			disc = c(28, 30, 38),
		},
	},
	turbine = {
		id = "turbine",
		name = "Turbine",
		rim = "r8_wheel_rim_turbine",
		material = Enum.Material.Metal,
		reflectance = 0.05,
		rimColor = SILVER,
		animated = false,
		fallback = { spokes = 12, spokeWidth = 0.09, spoke = SILVER, rim = SILVER, hub = STEEL, disc = c(40, 42, 50) },
	},
	mesh = {
		id = "mesh",
		name = "Mesh",
		rim = "r8_wheel_rim_mesh",
		material = Enum.Material.Metal,
		reflectance = 0.05,
		rimColor = c(224, 228, 238),
		animated = false,
		fallback = {
			spokes = 16,
			spokeWidth = 0.045,
			spoke = c(224, 228, 238),
			rim = SILVER,
			hub = STEEL,
			disc = c(40, 42, 50),
		},
	},
	split_five = {
		id = "split_five",
		name = "Split Five",
		rim = "r8_wheel_rim_split_five",
		material = Enum.Material.Metal,
		reflectance = 0.05,
		rimColor = SILVER,
		animated = false,
		fallback = { spokes = 10, spokeWidth = 0.07, spoke = SILVER, rim = SILVER, hub = STEEL, disc = c(40, 42, 50) },
	},
	star_spoke = {
		id = "star_spoke",
		name = "Star Spoke",
		rim = "r8_wheel_rim_star_spoke",
		material = Enum.Material.Metal,
		reflectance = 0.05,
		rimColor = c(214, 220, 232),
		animated = false,
		fallback = {
			spokes = 5,
			spokeWidth = 0.2,
			spoke = c(214, 220, 232),
			rim = SILVER,
			hub = STEEL,
			disc = c(40, 42, 50),
		},
	},
	gold_crown = {
		id = "gold_crown",
		name = "Gold Crown",
		rim = "r8_wheel_rim_gold_crown",
		material = Enum.Material.Metal,
		reflectance = 0.25,
		rimColor = GOLD,
		animated = false,
		fallback = { spokes = 7, spokeWidth = 0.09, spoke = GOLD, rim = GOLD, hub = GOLD, disc = c(60, 44, 16) },
	},
	chrome_mirror = {
		id = "chrome_mirror",
		name = "Chrome Mirror",
		rim = "r8_wheel_rim_chrome_mirror",
		material = Enum.Material.Metal,
		reflectance = 0.5,
		rimColor = c(236, 242, 255),
		animated = false,
		fallback = {
			spokes = 5,
			spokeWidth = 0.2,
			spoke = c(236, 242, 255),
			rim = c(236, 242, 255),
			hub = c(210, 220, 240),
			disc = c(60, 66, 84),
		},
	},
	carbon = {
		id = "carbon",
		name = "Carbon",
		rim = "r8_wheel_rim_carbon",
		material = Enum.Material.SmoothPlastic,
		reflectance = 0.04,
		rimColor = c(60, 62, 72),
		animated = false,
		fallback = {
			spokes = 5,
			spokeWidth = 0.17,
			spoke = c(46, 48, 58),
			rim = STEEL,
			hub = SILVER,
			disc = c(20, 20, 26),
		},
	},
	white_wall = {
		id = "white_wall",
		name = "White Wall",
		rim = "r8_wheel_rim_white_wall",
		material = Enum.Material.Metal,
		reflectance = 0.45,
		rimColor = c(236, 242, 255),
		animated = false,
		fallback = {
			spokes = 0,
			spokeWidth = 0,
			spoke = SILVER,
			rim = c(236, 242, 255),
			hub = c(236, 242, 255),
			disc = c(226, 232, 246),
			solidFace = true,
			whiteWall = true,
		},
	},
	stripe_tyre = {
		id = "stripe_tyre",
		name = "Stripe Tyre",
		rim = "r8_wheel_rim_stripe_tyre",
		material = Enum.Material.Metal,
		reflectance = 0.05,
		rimColor = c(96, 102, 116),
		animated = false,
		fallback = {
			spokes = 5,
			spokeWidth = 0.15,
			spoke = c(96, 102, 116),
			rim = SILVER,
			hub = STEEL,
			disc = DARK,
			stripe = c(228, 30, 40),
		},
	},
	neon_ring = {
		id = "neon_ring",
		name = "Neon Ring",
		rim = "r8_wheel_rim_neon_ring",
		glow = "r8_wheel_glow_neon_ring",
		material = Enum.Material.Metal,
		reflectance = 0.05,
		rimColor = c(60, 63, 74),
		glowColor = CYAN,
		pulse = 2.6,
		animated = true,
		fallback = {
			spokes = 5,
			spokeWidth = 0.1,
			spoke = c(60, 63, 74),
			rim = c(54, 57, 68),
			hub = c(70, 74, 86),
			disc = DARK,
			glowRing = true,
		},
	},
	glowing_hub = {
		id = "glowing_hub",
		name = "Glowing Hub",
		rim = "r8_wheel_rim_glowing_hub",
		glow = "r8_wheel_glow_glowing_hub",
		material = Enum.Material.Metal,
		reflectance = 0.05,
		rimColor = SILVER,
		glowColor = CYAN,
		pulse = 2.2,
		animated = true,
		fallback = {
			spokes = 6,
			spokeWidth = 0.1,
			spoke = SILVER,
			rim = SILVER,
			hub = DARK,
			disc = c(40, 42, 50),
			glowHub = true,
		},
	},
	glowing_tread = {
		id = "glowing_tread",
		name = "Glowing Tread",
		rim = "r8_wheel_rim_glowing_tread",
		glow = "r8_wheel_glow_glowing_tread",
		glowFrame = "tyre",
		material = Enum.Material.Metal,
		reflectance = 0.05,
		rimColor = c(88, 92, 106),
		glowColor = CYAN,
		pulse = 2.8,
		animated = true,
		fallback = {
			spokes = 5,
			spokeWidth = 0.15,
			spoke = c(88, 92, 106),
			rim = STEEL,
			hub = SILVER,
			disc = DARK,
			glowTread = true,
		},
	},
	flame_spoke = {
		id = "flame_spoke",
		name = "Flame Spoke",
		rim = "r8_wheel_rim_flame_spoke",
		glow = "r8_wheel_glow_flame_spoke",
		material = Enum.Material.Metal,
		reflectance = 0.05,
		rimColor = c(80, 82, 92),
		glowColor = c(255, 120, 24),
		pulse = 1.1,
		flicker = true,
		animated = true,
		fallback = {
			spokes = 8,
			spokeWidth = 0.13,
			spoke = c(255, 120, 24),
			rim = GUN,
			hub = SILVER,
			disc = c(44, 14, 8),
			neonSpokes = true,
		},
	},
	galaxy_disc = {
		id = "galaxy_disc",
		name = "Galaxy Disc",
		rim = "r8_wheel_rim_galaxy_disc",
		stars = "r8_wheel_stars_galaxy_disc",
		material = Enum.Material.Metal,
		reflectance = 0.05,
		rimColor = c(120, 70, 230),
		glowColor = c(230, 220, 255),
		drift = 0.18,
		animated = true,
		fallback = {
			spokes = 0,
			spokeWidth = 0,
			spoke = SILVER,
			rim = SILVER,
			hub = c(255, 150, 240),
			disc = c(96, 48, 200),
			solidFace = true,
		},
	},
}

-- authoring-frame bounding boxes (xmin, xmax, ymin, ymax, zmin, zmax); filled in from stats.json
local BBOX: { [string]: Box } = {
	r8_wheel_glow_flame_spoke = { 0.282, 0.317, -0.6555, 0.6555, -0.6555, 0.6555 },
	r8_wheel_glow_glowing_hub = { 0.2965, 0.3577, -0.4013, 0.4013, -0.4334, 0.4334 },
	r8_wheel_glow_glowing_tread = { -0.26, 0.4476, -1.012, 1.012, -1.012, 1.012 },
	r8_wheel_glow_neon_ring = { 0.2792, 0.417, -0.6417, 0.6417, -0.6417, 0.6417 },
	r8_wheel_rim_carbon = { -0.07, 0.44, -0.7654, 0.7654, -0.7654, 0.7654 },
	r8_wheel_rim_chrome_mirror = { -0.07, 0.44, -0.7654, 0.8013, -0.774, 0.7654 },
	r8_wheel_rim_deep_dish = { -0.07, 0.456, -0.7654, 0.7654, -0.7654, 0.7654 },
	r8_wheel_rim_flame_spoke = { -0.07, 0.44, -0.7654, 0.7654, -0.7654, 0.7654 },
	r8_wheel_rim_galaxy_disc = { 0.3, 0.466, -0.7654, 0.7654, -0.7654, 0.7654 },
	r8_wheel_rim_glowing_hub = { -0.07, 0.44, -0.7654, 0.7654, -0.7654, 0.7654 },
	r8_wheel_rim_glowing_tread = { -0.07, 0.44, -0.7654, 0.7654, -0.7654, 0.7654 },
	r8_wheel_rim_gold_crown = { -0.07, 0.44, -0.7654, 0.7654, -0.7654, 0.7654 },
	r8_wheel_rim_mesh = { -0.07, 0.454, -0.7654, 0.7654, -0.7654, 0.7654 },
	r8_wheel_rim_multi_spoke = { -0.07, 0.44, -0.7654, 0.7654, -0.7654, 0.7654 },
	r8_wheel_rim_neon_ring = { -0.07, 0.44, -0.7654, 0.7654, -0.7654, 0.7654 },
	r8_wheel_rim_split_five = { -0.07, 0.44, -0.7654, 0.7654, -0.7654, 0.7654 },
	r8_wheel_rim_star_spoke = { -0.07, 0.44, -0.7654, 0.7654, -0.7654, 0.7654 },
	r8_wheel_rim_stripe_tyre = { -0.07, 0.4472, -0.94, 0.94, -0.94, 0.94 },
	r8_wheel_rim_turbine = { -0.07, 0.44, -0.7654, 0.7654, -0.7654, 0.7654 },
	r8_wheel_rim_white_wall = { 0.27, 0.454, -0.935, 0.935, -0.935, 0.935 },
	r8_wheel_stars_galaxy_disc = { 0.3449, 0.3691, -0.6688, 0.6679, -0.678, 0.667 },
	r8_wheel_tyre = { -0.44, 0.44, -1, 1, -1, 1 },
}

return {
	TYRE = "r8_wheel_tyre",
	HALF_WIDTH = 0.44, -- authored tyre half width (tyre radius = 1)
	designs = designs,
	BBOX = BBOX,
}
