--!strict
-- The Launch Pads' world (Lane 3, Round 3 N6): one layout, three themes. Each is a compact space the player crosses in a few seconds:
-- arrival in the south, a glowing ramp in the north, the Car stall west, the Trail stall east, the Paint corner beside the ramp and
-- a portal home in the south-west. Built on the client when first needed, far from the island and the run road, so it never shows
-- from either. Decoration never collides; only the floor and the edge walls do. Local +Z is south, -Z is north, y = 0 is the floor.
--
--   Build.build(world, origin) -> Pad
--   Pad = { folder, arrival: CFrame, ramp: { centre, half }, home: Vector3, stalls = { Cars = Part, Trails = Part, Paint = Part } }

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SignKit = require(ReplicatedStorage.Shared.Island.SignKit)
local RealCar = require(script.Parent.Parent.Prototype.RealCar)
local StyleState = require(script.Parent.Parent.Prototype.StyleState)

local Build = {}

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

export type Pad = {
	folder: Folder,
	arrival: CFrame,
	rampCentre: Vector3,
	rampHalf: Vector2,
	home: Vector3,
	stalls: { [string]: BasePart },
	destroy: (self: Pad) -> (),
}

type Theme = {
	name: string,
	floor: Color3,
	floorMaterial: Enum.Material,
	tile: Color3,
	wall: Color3,
	frame: Color3,
	neonA: Color3,
	neonB: Color3,
	ground: Color3,
	groundMaterial: Enum.Material,
	road: Color3,
	sign: string,
}

local THEMES: { [string]: Theme } = {
	Downtown = {
		name = "DOWNTOWN GARAGE",
		floor = rgb(120, 126, 138),
		floorMaterial = Enum.Material.Concrete,
		tile = rgb(96, 102, 116),
		wall = rgb(66, 86, 136),
		frame = rgb(34, 44, 78),
		neonA = rgb(255, 148, 30),
		neonB = rgb(50, 190, 255),
		ground = rgb(150, 156, 166),
		groundMaterial = Enum.Material.Concrete,
		road = rgb(52, 56, 66),
		sign = "Downtown",
	},
	DustyHighway = {
		name = "DUSTY GAS STOP",
		floor = rgb(188, 160, 122),
		floorMaterial = Enum.Material.Concrete,
		tile = rgb(166, 138, 100),
		wall = rgb(150, 66, 46),
		frame = rgb(238, 226, 200),
		neonA = rgb(255, 90, 70),
		neonB = rgb(60, 220, 210),
		ground = rgb(216, 176, 122),
		groundMaterial = Enum.Material.Sand,
		road = rgb(74, 68, 66),
		sign = "Fuel",
	},
	SummitPass = {
		name = "SUMMIT LODGE",
		floor = rgb(168, 138, 104),
		floorMaterial = Enum.Material.WoodPlanks,
		tile = rgb(146, 116, 84),
		wall = rgb(96, 62, 38),
		frame = rgb(62, 38, 24),
		neonA = rgb(255, 196, 96),
		neonB = rgb(120, 210, 255),
		ground = rgb(240, 246, 252),
		groundMaterial = Enum.Material.Snow,
		road = rgb(84, 92, 108),
		sign = "Lodge",
	},
}

function Build.build(world: string, origin: CFrame): Pad
	local theme = THEMES[world] or THEMES.Downtown
	local folder = Instance.new("Folder")
	folder.Name = "Lane3_LaunchPad_" .. world

	local function box(
		name: string,
		size: Vector3,
		at: CFrame,
		colour: Color3,
		material: Enum.Material?,
		solid: boolean?
	): Part
		local p = Instance.new("Part")
		p.Name = name
		p.Anchored = true
		p.CanCollide = solid == true
		p.CanTouch = false
		p.CanQuery = solid == true
		p.CastShadow = size.Magnitude > 8
		p.Size = size
		p.CFrame = origin * at
		p.Color = colour
		p.Material = material or Enum.Material.SmoothPlastic
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.Parent = folder
		return p
	end

	local function neon(name: string, size: Vector3, at: CFrame, colour: Color3): Part
		return box(name, size, at, colour, Enum.Material.Neon)
	end

	local function pyramid(at: CFrame, w: number, h: number, colour: Color3, material: Enum.Material?)
		-- four corner wedges: a crisp faceted cone
		for i = 0, 3 do
			local p = Instance.new("CornerWedgePart")
			p.Name = "Facet"
			p.Anchored = true
			p.CanCollide = false
			p.CanTouch = false
			p.CanQuery = false
			p.Size = Vector3.new(w / 2, h, w / 2)
			local a = CFrame.Angles(0, i * math.pi / 2, 0)
			p.CFrame = origin * at * a * CFrame.new(w / 4, h / 2, w / 4)
			p.Color = colour
			p.Material = material or Enum.Material.SmoothPlastic
			p.Parent = folder
		end
	end

	-- the ground around everything, and the floor with its tile lines
	box("Ground", Vector3.new(900, 4, 900), CFrame.new(0, -2.6, -260), theme.ground, theme.groundMaterial, true)
	box("Floor", Vector3.new(76, 2, 62), CFrame.new(0, -1, 0), theme.floor, theme.floorMaterial, true)
	for i = -3, 3 do
		box("Seam", Vector3.new(0.14, 0.04, 62), CFrame.new(i * 10.8, 0.02, 0), theme.tile)
	end
	for i = -2, 2 do
		box("Seam", Vector3.new(76, 0.04, 0.14), CFrame.new(0, 0.02, i * 12.2), theme.tile)
	end

	-- hazard lines that lead the eye to the ramp
	for _, s in { 1, -1 } do
		box("Lane", Vector3.new(0.7, 0.05, 30), CFrame.new(s * 9.6, 0.04, -14), theme.neonA)
	end
	box("Lane", Vector3.new(20, 0.05, 0.7), CFrame.new(0, 0.04, 1), theme.neonA)

	-- the ramp, out through the north gap, onto the road
	local rampLen = 22
	local rise = 3.4
	local ramp = Instance.new("WedgePart")
	ramp.Name = "Ramp"
	ramp.Anchored = true
	ramp.CanCollide = true
	ramp.CanTouch = false
	ramp.Size = Vector3.new(18, rise, rampLen)
	ramp.CFrame = origin * CFrame.new(0, rise / 2, -31 - rampLen / 2) * CFrame.Angles(0, math.pi, 0)
	ramp.Color = theme.neonA:Lerp(rgb(30, 30, 40), 0.55)
	ramp.Material = Enum.Material.SmoothPlastic
	ramp.Parent = folder
	box(
		"Road",
		Vector3.new(18, 2, 460),
		CFrame.new(0, rise - 1, -31 - rampLen - 230),
		theme.road,
		Enum.Material.Asphalt,
		true
	)
	for i = 1, 16 do
		box(
			"RoadLine",
			Vector3.new(0.5, 0.05, 11),
			CFrame.new(0, rise + 0.03, -31 - rampLen - 8 - i * 26),
			rgb(248, 214, 90)
		)
	end
	local slope = math.atan2(rise, rampLen)
	local along = CFrame.new(0, rise / 2 + 0.12, -31 - rampLen / 2) * CFrame.Angles(slope, 0, 0)
	for _, s in { 1, -1 } do
		neon("RampEdge", Vector3.new(1.4, 0.8, rampLen + 2), along * CFrame.new(s * 8.2, 0.2, 0), theme.neonA)
	end
	for i = 1, 3 do
		local c = along * CFrame.new(0, 0.1, rampLen / 2 - i * 5.2)
		for _, s in { 1, -1 } do
			neon(
				"Chevron",
				Vector3.new(7.6, 0.16, 1.9),
				c * CFrame.new(s * 3, 0, 0) * CFrame.Angles(0, s * math.rad(-32), 0),
				rgb(255, 240, 170)
			)
		end
	end
	for _, s in { 1, -1 } do
		box("ArchPost", Vector3.new(1.4, 12, 1.4), CFrame.new(s * 10.4, 6, -27), theme.frame)
		neon("ArchStrip", Vector3.new(0.4, 11, 0.4), CFrame.new(s * 9.5, 6, -26.6), theme.neonA)
	end
	box("ArchHead", Vector3.new(22, 2.6, 1.4), CFrame.new(0, 13, -27), theme.frame)
	SignKit.sign(folder, origin * CFrame.new(0, 13, -26.2) * CFrame.Angles(0, math.pi, 0), {
		style = "Race",
		text = "START",
		width = 15,
		height = 2.4,
	})
	-- a soft pool of light on the ramp, so it reads from anywhere on the pad
	local lamp = Instance.new("PointLight")
	lamp.Color = theme.neonA
	lamp.Range = 34
	lamp.Brightness = 2.4
	lamp.Parent = ramp

	-- the Home portal, south-west
	local homeAt = CFrame.new(-28, 0, 22) * CFrame.Angles(0, math.rad(-135), 0)
	box("HomeBase", Vector3.new(16, 0.6, 12), homeAt * CFrame.new(0, 0.3, 0), theme.frame)
	for _, s in { 1, -1 } do
		box("HomePost", Vector3.new(2, 12, 2.4), homeAt * CFrame.new(s * 6, 6.5, 0), theme.frame)
		neon("HomeStrip", Vector3.new(0.3, 10, 0.5), homeAt * CFrame.new(s * 4.9, 6.5, 0), theme.neonB)
	end
	box("HomeHead", Vector3.new(14, 2.4, 2.4), homeAt * CFrame.new(0, 13.2, 0), theme.frame)
	local field = neon("HomeField", Vector3.new(9.6, 10.6, 0.3), homeAt * CFrame.new(0, 6.4, 0), theme.neonB)
	field.Transparency = 0.25
	SignKit.sign(folder, origin * homeAt * CFrame.new(0, 13.2, -1.4), {
		style = "Race",
		text = "HOME",
		width = 11,
		height = 2,
	})

	local stalls: { [string]: BasePart } = {}

	local function stall(key: string, label: string, at: CFrame, accent: Color3): CFrame
		-- a counter with a sign above; `at` faces the player (local -Z toward the middle of the pad)
		box("Pad", Vector3.new(20, 0.4, 13), at * CFrame.new(0, 0.2, 0), theme.tile)
		neon("PadEdge", Vector3.new(20.4, 0.12, 0.5), at * CFrame.new(0, 0.42, -6.6), accent)
		box("Back", Vector3.new(22, 11, 1), at * CFrame.new(0, 5.5, 6.8), theme.wall)
		box("Roof", Vector3.new(22, 1, 14), at * CFrame.new(0, 11.4, 0), theme.frame)
		neon("Strip", Vector3.new(21, 0.3, 0.3), at * CFrame.new(0, 10.7, -6.8), accent)
		for _, s in { 1, -1 } do
			box("Post", Vector3.new(1, 11, 1), at * CFrame.new(s * 10.6, 5.5, -6.2), theme.frame)
		end
		local counter = box("Counter", Vector3.new(8, 3, 2.2), at * CFrame.new(5.6, 1.5, -3.2), theme.frame)
		box("CounterTop", Vector3.new(8.4, 0.3, 2.6), at * CFrame.new(5.6, 3.15, -3.2), accent)
		SignKit.sign(folder, origin * at * CFrame.new(0, 13.6, -6.9), {
			style = theme.sign,
			text = label,
			width = 15,
			height = 3.6,
			accent = accent,
		})
		local light = Instance.new("PointLight")
		light.Color = accent
		light.Range = 26
		light.Brightness = 1.6
		light.Parent = box("Lamp", Vector3.new(1, 0.4, 1), at * CFrame.new(0, 10.6, 0), accent, Enum.Material.Neon)
		stalls[key] = counter
		return at
	end

	local carAt = stall("Cars", "CARS", CFrame.new(-29, 0, -4) * CFrame.Angles(0, math.rad(-90), 0), theme.neonB)
	local trailAt = stall("Trails", "TRAILS", CFrame.new(29, 0, -4) * CFrame.Angles(0, math.rad(90), 0), theme.neonB)
	local paintAt = stall("Paint", "PAINT", CFrame.new(-23, 0, -24) * CFrame.Angles(0, math.rad(-22), 0), theme.neonA)

	-- the car on show
	local carRig = RealCar.mount(folder, { length = 8, height = 6.5 })
	carRig:pivotTo(origin * carAt * CFrame.new(-3.4, 0.45, 0.4) * CFrame.Angles(0, math.rad(62), 0))
	carRig:setCar(StyleState.car())
	local carWatch = StyleState.Changed:Connect(function()
		carRig:setCar(StyleState.car())
	end)

	-- three trail swatches on the wall of the Trail stall
	for i, c in { rgb(255, 80, 60), rgb(255, 214, 60), rgb(120, 90, 255) } do
		neon(
			"TrailSwatch",
			Vector3.new(6, 0.5, 0.3),
			trailAt * CFrame.new(-4, 3 + i * 1.7, 6.1) * CFrame.Angles(0, 0, math.rad(12)),
			c
		)
	end
	for i = 1, 3 do
		neon("TrailPad", Vector3.new(2.6, 0.2, 2.6), trailAt * CFrame.new(-7 + i * 3.4, 0.5, 2), theme.neonB)
	end
	-- a paint wall
	local swatches = {
		rgb(230, 50, 60),
		rgb(255, 140, 30),
		rgb(255, 214, 50),
		rgb(70, 210, 100),
		rgb(50, 160, 255),
		rgb(150, 90, 240),
	}
	for i, c in swatches do
		box("Swatch", Vector3.new(2.4, 5, 0.3), paintAt * CFrame.new(-8.2 + i * 2.7, 5, 6.2), c, Enum.Material.Neon)
	end

	-- theme dressing
	if world == "Downtown" then
		-- the garage: a frame round the north gap with a roll-up door above it, and the city behind
		for _, s in { 1, -1 } do
			box("Wall", Vector3.new(27, 26, 2), CFrame.new(s * 24.5, 13, -31), theme.wall)
			neon("DoorStrip", Vector3.new(0.5, 16, 0.5), CFrame.new(s * 10.8, 8, -30), theme.neonA)
			box("Pier", Vector3.new(2, 26, 3), CFrame.new(s * 11, 13, -31), theme.frame)
			box("Side", Vector3.new(2, 26, 62), CFrame.new(s * 38, 13, 0), theme.wall)
			box("Beam", Vector3.new(76, 1.4, 1.4), CFrame.new(0, 24, s * 14 - 2), theme.frame)
		end
		box("Lintel", Vector3.new(22, 8, 2), CFrame.new(0, 22, -31), theme.frame)
		for i = 0, 6 do
			box("RollUp", Vector3.new(21, 0.9, 0.5), CFrame.new(0, 17 + i * 1, -29.6), rgb(150, 156, 170))
		end
		local colours = { rgb(70, 110, 190), rgb(60, 90, 160), rgb(92, 130, 210), rgb(120, 150, 215) }
		for i = 1, 22 do
			local x = -240 + i * 22
			local h = 60 + (i * 37 % 120)
			if math.abs(x) > 16 then
				local z = -210 - (i * 53 % 120)
				local c = colours[i % 4 + 1]
				box("Tower", Vector3.new(18, h, 18), CFrame.new(x, h / 2 + 3, z), c)
				box("TowerTop", Vector3.new(10, 5, 10), CFrame.new(x, h + 5.5, z), c:Lerp(Color3.new(1, 1, 1), 0.2))
				for row = 1, math.floor(h / 14) do
					box(
						"Windows",
						Vector3.new(15, 5, 0.4),
						CFrame.new(x, row * 14, z + 9.2),
						c:Lerp(Color3.fromRGB(190, 225, 255), 0.55)
					)
				end
			end
		end
		for _, s in { 1, -1 } do
			for i = 1, 4 do
				box("Kerb", Vector3.new(2, 1, 60), CFrame.new(s * 10, 3.8, -60 - i * 60), rgb(190, 194, 204))
			end
		end
	elseif world == "DustyHighway" then
		-- a canopy over the middle of the pad, pumps, a tall sign, and mesas on the horizon
		for _, sx in { 1, -1 } do
			box("CanopyPost", Vector3.new(1.6, 14, 1.6), CFrame.new(sx * 13, 7, -18), theme.frame)
			box("CanopyPost", Vector3.new(1.6, 14, 1.6), CFrame.new(sx * 13, 7, 4), theme.frame)
		end
		box("Canopy", Vector3.new(36, 1.6, 34), CFrame.new(0, 15, -7), theme.frame)
		box("CanopyBand", Vector3.new(37, 1.2, 35), CFrame.new(0, 13.8, -7), theme.wall)
		neon("CanopyNeon", Vector3.new(37.4, 0.3, 0.3), CFrame.new(0, 13.1, 10.6), theme.neonA)
		for _, s in { 1, -1 } do
			box("Pump", Vector3.new(2, 4.6, 1.4), CFrame.new(s * 13, 2.3, -8), theme.wall)
			box("PumpFace", Vector3.new(1.4, 1.6, 0.1), CFrame.new(s * 13, 3.2, -7.3), theme.neonB, Enum.Material.Neon)
			box("Island", Vector3.new(4, 0.4, 7), CFrame.new(s * 13, 0.2, -8), theme.tile)
		end
		box("SignPole", Vector3.new(1.4, 34, 1.4), CFrame.new(32, 17, 26), theme.frame)
		SignKit.sign(folder, origin * CFrame.new(32, 34, 25) * CFrame.Angles(0, 0, 0), {
			style = "Fuel",
			text = "GAS",
			width = 16,
			height = 6,
			backlight = true,
		})
		local rock = { rgb(186, 106, 66), rgb(170, 90, 56), rgb(204, 130, 84) }
		for i, m in
			{
				{ -210, -320, 150, 90 },
				{ -80, -420, 200, 120 },
				{ 110, -390, 170, 80 },
				{ 250, -300, 120, 110 },
				{ -330, -210, 110, 70 },
				{ 340, -200, 130, 60 },
			}
		do
			box(
				"Mesa",
				Vector3.new(m[3], m[4], m[3] * 0.7),
				CFrame.new(m[1], m[4] / 2, m[2]),
				rock[i % 3 + 1],
				Enum.Material.Rock
			)
			box(
				"MesaCap",
				Vector3.new(m[3] * 0.82, m[4] * 0.3, m[3] * 0.56),
				CFrame.new(m[1], m[4] * 1.15, m[2]),
				rock[(i + 1) % 3 + 1],
				Enum.Material.Rock
			)
		end
		for i, c in { { -40, -60 }, { 46, -70 }, { -62, -120 }, { 70, -130 } } do
			local h = 8 + i % 3 * 3
			box("Cactus", Vector3.new(1.4, h, 1.4), CFrame.new(c[1], h / 2, c[2]), rgb(70, 130, 80))
		end
	else
		-- the lodge wall, warm windows, a big roof and pines in the snow
		for _, s in { 1, -1 } do
			box("Wall", Vector3.new(27, 16, 2), CFrame.new(s * 24.5, 8, -31), theme.wall, Enum.Material.WoodPlanks)
			for i = 0, 1 do
				neon("Window", Vector3.new(7, 7, 0.4), CFrame.new(s * (17 + i * 11), 8.2, -29.9), theme.neonA)
				box("WindowBar", Vector3.new(0.4, 7, 0.5), CFrame.new(s * (17 + i * 11), 8.2, -29.8), theme.frame)
				box("WindowBar", Vector3.new(7, 0.4, 0.5), CFrame.new(s * (17 + i * 11), 8.2, -29.8), theme.frame)
			end
			for i = 0, 7 do
				box(
					"Log",
					Vector3.new(27.6, 0.7, 0.8),
					CFrame.new(s * 24.5, 0.7 + i * 2.2, -29.9),
					theme.frame,
					Enum.Material.WoodPlanks
				)
			end
			box(
				"Roof",
				Vector3.new(29, 2, 26),
				CFrame.new(s * 22, 21, -28) * CFrame.Angles(0, 0, s * math.rad(-28)),
				rgb(236, 242, 250),
				Enum.Material.Snow
			)
		end
		box("Lintel", Vector3.new(22, 3, 2.4), CFrame.new(0, 15, -31), theme.frame, Enum.Material.WoodPlanks)
		local warm = Instance.new("PointLight")
		warm.Color = theme.neonA
		warm.Range = 40
		warm.Brightness = 1.2
		warm.Parent = box("Glow", Vector3.new(1, 1, 1), CFrame.new(0, 10, -24), theme.neonA)
		local greens = { rgb(44, 96, 76), rgb(36, 84, 70), rgb(56, 110, 84) }
		for i, t in
			{
				{ -46, -48 },
				{ 46, -44 },
				{ -62, -20 },
				{ 62, -16 },
				{ -56, 22 },
				{ 58, 26 },
				{ -30, -70 },
				{ 32, -74 },
				{ -70, -60 },
				{ 74, -62 },
			}
		do
			local w = 12 + i % 3 * 3
			local g = greens[i % 3 + 1]
			box("Trunk", Vector3.new(1.6, 6, 1.6), CFrame.new(t[1], 3, t[2]), rgb(84, 58, 40))
			pyramid(CFrame.new(t[1], 5, t[2]), w, 10, g)
			pyramid(CFrame.new(t[1], 11, t[2]), w * 0.78, 9, g)
			pyramid(CFrame.new(t[1], 17, t[2]), w * 0.54, 8, rgb(226, 236, 244), Enum.Material.Snow)
		end
		for i, m in { { -200, -340, 220, 170 }, { 40, -420, 300, 240 }, { 260, -330, 230, 180 } } do
			pyramid(
				CFrame.new(m[1], 0, m[2]),
				m[3],
				m[4],
				rgb(120 + i * 8, 136 + i * 8, 164 + i * 6),
				Enum.Material.Rock
			)
			pyramid(
				CFrame.new(m[1], m[4] * 0.62, m[2]),
				m[3] * 0.38,
				m[4] * 0.38,
				rgb(240, 246, 252),
				Enum.Material.Snow
			)
		end
	end

	-- keep the player on the pad: clear walls on every open edge, and a gap only on the ramp
	for _, wall in
		{
			{ Vector3.new(2, 40, 66), CFrame.new(-39, 20, 0) },
			{ Vector3.new(2, 40, 66), CFrame.new(39, 20, 0) },
			{ Vector3.new(80, 40, 2), CFrame.new(0, 20, 32) },
			{ Vector3.new(30, 40, 2), CFrame.new(-25, 20, -32) },
			{ Vector3.new(30, 40, 2), CFrame.new(25, 20, -32) },
			{ Vector3.new(2, 40, 26), CFrame.new(-10, 20, -44) },
			{ Vector3.new(2, 40, 26), CFrame.new(10, 20, -44) },
			{ Vector3.new(22, 40, 2), CFrame.new(0, 20, -54) },
		}
	do
		local p = box("Edge", wall[1], wall[2], rgb(0, 0, 0), Enum.Material.SmoothPlastic, true)
		p.Transparency = 1
	end

	folder.Parent = workspace

	local pad: any = {
		folder = folder,
		arrival = origin * CFrame.new(0, 3.2, 18),
		rampCentre = (origin * CFrame.new(0, 1, -40)).Position,
		rampHalf = Vector2.new(8.5, 11),
		home = (origin * homeAt).Position,
		stalls = stalls,
	}
	function pad.destroy(self: Pad)
		carWatch:Disconnect()
		carRig:destroy()
		self.folder:Destroy()
	end
	return pad :: Pad
end

return Build
