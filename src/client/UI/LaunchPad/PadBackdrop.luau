--!strict
-- PadBackdrop: the World far below a Launch Pad (Lane 3, Launch Pad redesign). The platform floats 170 studs up, close enough that a
-- phone's short draw distance still shows it. Under it is one wide
-- ground, a ring of its World's own kit pieces, and a far ring that closes the horizon, so no zoom and no angle shows an edge. The kit
-- meshes are the group-owned World kits; with no kit in the place, plain blocks stand in. Clouds drift round the platform.
--
--   PadBackdrop.build(k, world, theme, life)        life(fn(t, dt)) registers an update, called only while the pad is on show

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PadBackdrop = {}

local DEPTH = 170
local WORLD_D = 2040

local function kit(): (any, any)
	local look = ReplicatedStorage:FindFirstChild("LookDev")
	local down = look and look:FindFirstChild("Downtown")
	if not down then
		return nil, nil
	end
	local ok, ids, worlds = pcall(function()
		return (require :: any)(down.KitIds), (require :: any)(down.WorldsKitIds)
	end)
	if ok then
		return ids, worlds
	end
	return nil, nil
end

local function ring(radius: number, a: number): Vector3
	return Vector3.new(math.sin(a) * radius, 0, math.cos(a) * radius)
end

local function downtown(k: any, theme: any, rng: Random)
	local ids = kit()
	local names = {
		"B2_Sky_Tower_1",
		"B2_Sky_Tower_2",
		"B2_Sky_Tower_3",
		"B2_Sky_Slab_1",
		"B2_Sky_Slab_2",
		"B2_Sky_Stepped_1",
		"B2_Sky_Stepped_2",
		"B2_Sky_Wedding_1",
		"B2_Sky_Crown_1",
		"B2_Sky_Needle_1",
	}
	local palette = ids and ids.palettes.Midtown
	local function tower(p: Vector3, w: number, h: number, lit: boolean?)
		local name = names[rng:NextInteger(1, #names)]
		local id = ids and ids.meshes[name]
		local cf = CFrame.new(p.X, -DEPTH + h / 2, p.Z) * CFrame.Angles(0, rng:NextNumber() * math.pi, 0)
		if id then
			k:mesh("CityTower", id, palette, Vector3.new(w, h, w), cf, nil, Vector3.new(0.5, 0.56, 0.78))
		else
			k:box("CityTower", Vector3.new(w, h, w), cf, Color3.fromRGB(70, 90, 150))
		end
		-- lit rooftops: they read as a city at dusk from far up
		k:neon(
			"CityGlow",
			Vector3.new(w * 0.5, 1, w * 0.5),
			CFrame.new(p.X, -DEPTH + h + 0.6, p.Z),
			if rng:NextNumber() < 0.5 then Color3.fromRGB(255, 200, 110) else Color3.fromRGB(120, 200, 255)
		)
		-- bands of lit windows: a tower, not a block
		if lit then
			for _, share in { 0.3, 0.62 } do
				local band = k:box(
					"CityWindows",
					Vector3.new(w * 0.86, h * 0.1, w * 0.86),
					CFrame.new(p.X, -DEPTH + h * share, p.Z) * cf.Rotation,
					Color3.fromRGB(255, 214, 140),
					Enum.Material.Neon
				)
				band.Transparency = 0.25
			end
		end
	end
	for i = 1, 14 do
		tower(ring(rng:NextNumber(90, 240), i * 2.399), rng:NextNumber(20, 34), rng:NextNumber(36, 90), true)
	end
	for i = 1, 16 do
		tower(ring(rng:NextNumber(260, 560), i * 2.399 + 1), rng:NextNumber(34, 60), rng:NextNumber(90, 210), true)
	end
	for i = 1, 24 do
		local a = (i / 24) * math.pi * 2
		tower(ring(rng:NextNumber(860, 930), a), rng:NextNumber(110, 170), rng:NextNumber(240, 460))
	end
	-- parks between the blocks
	for i = 1, 5 do
		local p = ring(rng:NextNumber(120, 420), i * 1.7)
		k:cyl("CityPark", rng:NextNumber(70, 130), 1, CFrame.new(p.X, -DEPTH + 2.4, p.Z), Color3.fromRGB(70, 130, 96))
	end
	-- two lit roads and a river
	k:box(
		"River",
		Vector3.new(140, 1, 1900),
		CFrame.new(-260, -DEPTH + 2.6, 0) * CFrame.Angles(0, 0.3, 0),
		Color3.fromRGB(46, 74, 140)
	)
	for _, r in { 0.9, -0.5 } do
		k:box(
			"CityRoad",
			Vector3.new(26, 1, 1900),
			CFrame.new(90, -DEPTH + 3, -60) * CFrame.Angles(0, r, 0),
			Color3.fromRGB(34, 38, 56)
		)
		k:neon(
			"CityRoadLight",
			Vector3.new(2, 0.4, 1900),
			CFrame.new(90, -DEPTH + 3.7, -60) * CFrame.Angles(0, r, 0),
			theme.stripeB
		)
	end
end

local function dusty(k: any, _theme: any, rng: Random)
	local _, worlds = kit()
	local set = worlds and worlds.DustyHighway
	local palette = set and set.palette
	local walls: { any } = {
		{ "DH_BG_MesaWall_A", Vector3.new(430, 71.5, 81) },
		{ "DH_BG_MesaWall_B", Vector3.new(398, 85.5, 73) },
		{ "DH_BG_MesaWall_C", Vector3.new(396, 105.5, 87) },
		{ "DH_BG_MesaWall_D", Vector3.new(352, 61.4, 69) },
	}
	local function mesa(radius: number, a: number, scale: number)
		local piece = walls[rng:NextInteger(1, #walls)]
		local id = set and (set[piece[1]] or (set.meshes and set.meshes[piece[1]]))
		local p = ring(radius, a)
		local size = piece[2] * scale
		local cf = CFrame.new(p.X, -DEPTH + size.Y / 2, p.Z) * CFrame.Angles(0, a + math.pi / 2, 0)
		if id then
			k:mesh("Mesa", id, palette, Vector3.one * scale, cf, size, Vector3.new(0.92, 0.6, 0.46))
		else
			k:box("Mesa", size, cf, Color3.fromRGB(170, 92, 60))
		end
	end
	for i = 1, 8 do
		mesa(rng:NextNumber(200, 420), i * 2.399, rng:NextNumber(0.5, 0.9))
	end
	for i = 1, 16 do
		mesa(900, (i / 16) * math.pi * 2, 2.4)
	end
	-- the highway across the desert
	k:box(
		"Highway",
		Vector3.new(40, 1, 1900),
		CFrame.new(140, -DEPTH + 3, 0) * CFrame.Angles(0, 0.5, 0),
		Color3.fromRGB(70, 66, 70)
	)
	k:box(
		"Highway",
		Vector3.new(3, 1, 1880),
		CFrame.new(140, -DEPTH + 3.4, 0) * CFrame.Angles(0, 0.5, 0),
		Color3.fromRGB(246, 214, 96)
	)
end

local function summit(k: any, _theme: any, rng: Random)
	local _, worlds = kit()
	local set = worlds and worlds.SummitPass
	local palette = set and set.palette
	local function piece(name: string): string?
		return set and (set[name] or (set.meshes and set.meshes[name]))
	end
	local massifs: { any } = {
		{ "SP_BG_Massif_A", Vector3.new(437, 285, 367) },
		{ "SP_BG_Massif_B", Vector3.new(357, 193, 314) },
		{ "SP_BG_Massif_C", Vector3.new(489, 349, 419) },
		{ "SP_BG_Massif_Horn", Vector3.new(309, 393, 289) },
	}
	for i = 1, 12 do
		local m = massifs[(i % #massifs) + 1]
		local a = (i / 12) * math.pi * 2
		local p = ring(rng:NextNumber(720, 860), a)
		local scale = rng:NextNumber(1.2, 1.7)
		local size = m[2] * scale
		local cf = CFrame.new(p.X, -DEPTH + size.Y / 2, p.Z) * CFrame.Angles(0, a, 0)
		local id = piece(m[1])
		if id then
			k:mesh("Peak", id, palette, Vector3.one * scale, cf, size)
		else
			k:box("Peak", size, cf * CFrame.Angles(0, 0.8, 0), Color3.fromRGB(190, 206, 226))
		end
	end
	local spruce = piece("SP_Fol_Spruce")
	for i = 1, 34 do
		local p = ring(rng:NextNumber(90, 460), i * 2.399)
		local scale = rng:NextNumber(1.6, 2.6)
		local cf = CFrame.new(p.X, -DEPTH + 21 * scale, p.Z)
		if spruce then
			k:mesh("Spruce", spruce, palette, Vector3.one * scale, cf, Vector3.new(17.6, 42, 17.8) * scale)
		else
			k:box("Spruce", Vector3.new(14, 42, 14) * scale, cf, Color3.fromRGB(46, 96, 80))
		end
	end
	-- a ski lift climbing away across the valley
	local tower = piece("SP_LM_LiftTower_B")
	for i = 0, 4 do
		local cf = CFrame.new(-420 + i * 90, -DEPTH + 31, -250 + i * 70)
		if tower then
			k:mesh("LiftTower", tower, palette, Vector3.one, cf, Vector3.new(15.4, 62.8, 15.4))
		end
	end
	k:box(
		"Lake",
		Vector3.new(220, 1, 150),
		CFrame.new(190, -DEPTH + 3, 150),
		Color3.fromRGB(110, 176, 214),
		Enum.Material.Ice
	)
end

local BUILD: { [string]: (any, any, Random) -> () } = { Downtown = downtown, DustyHighway = dusty, SummitPass = summit }

function PadBackdrop.build(k: any, world: string, theme: any, life: (fn: (number, number) -> ()) -> ())
	local rng = Random.new(20261102)
	k:cyl("WorldGround", WORLD_D, 4, CFrame.new(0, -DEPTH, 0), theme.world, theme.worldMaterial)
	local build = BUILD[world] or downtown
	build(k, theme, rng)

	-- clouds: a few soft clumps at platform height and below, on one slow drift
	local cloudKit, clouds = k:model("Clouds")
	local white = if world == "Downtown" then Color3.fromRGB(255, 226, 226) else Color3.fromRGB(252, 250, 248)
	for i = 1, 10 do
		local a = i * 2.399
		local p = ring(rng:NextNumber(120, 420), a)
		local y = rng:NextNumber(-110, -20)
		local base = rng:NextNumber(20, 34)
		for j = -1, 1 do
			local size = base * (if j == 0 then 1 else 0.72)
			cloudKit:puff(
				Vector3.new(size * 1.9, size * 0.6, size * 1.2),
				CFrame.new(p.X + j * base * 0.9, y, p.Z + j * base * 0.3),
				white
			)
		end
	end
	local home = clouds:GetPivot()
	local spin = 0
	life(function(_t: number, dt: number)
		spin += dt * 0.012
		clouds:PivotTo(home * CFrame.Angles(0, spin, 0))
	end)
end

return PadBackdrop
