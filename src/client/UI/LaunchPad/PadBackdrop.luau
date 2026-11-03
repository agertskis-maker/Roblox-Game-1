--!strict
-- PadBackdrop: the World far below a Launch Pad (Lane 3, Launch Pad redesign). The platform floats 300 studs up. Under it is one wide
-- ground, a ring of its World's own kit pieces, and a far ring that closes the horizon, so no zoom and no angle shows an edge. The kit
-- meshes are the group-owned World kits; with no kit in the place, plain blocks stand in. Clouds drift round the platform.
--
--   PadBackdrop.build(k, world, theme, life)        life(fn(t, dt)) registers an update, called only while the pad is on show

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PadBackdrop = {}

local DEPTH = 300
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
	local function tower(p: Vector3, w: number, h: number)
		local name = names[rng:NextInteger(1, #names)]
		local id = ids and ids.meshes[name]
		local cf = CFrame.new(p.X, -DEPTH + h / 2, p.Z) * CFrame.Angles(0, rng:NextNumber() * math.pi, 0)
		if id then
			k:mesh("CityTower", id, palette, Vector3.new(w, h, w), cf)
		else
			k:box("CityTower", Vector3.new(w, h, w), cf, Color3.fromRGB(70, 90, 150))
		end
		-- lit rooftops: they read as a city at dusk from far up
		k:neon(
			"CityGlow",
			Vector3.new(w * 0.5, 2, w * 0.5),
			CFrame.new(p.X, -DEPTH + h + 1, p.Z),
			if rng:NextNumber() < 0.5 then Color3.fromRGB(255, 200, 110) else Color3.fromRGB(120, 200, 255)
		)
	end
	for i = 1, 26 do
		tower(ring(rng:NextNumber(150, 520), i * 2.399), rng:NextNumber(26, 52), rng:NextNumber(70, 190))
	end
	for i = 1, 22 do
		local a = (i / 22) * math.pi * 2
		tower(ring(rng:NextNumber(800, 900), a), rng:NextNumber(70, 110), rng:NextNumber(220, 420))
	end
	-- two lit roads and a river
	k:box(
		"River",
		Vector3.new(140, 1, 1900),
		CFrame.new(-260, -DEPTH + 2.6, 0) * CFrame.Angles(0, 0.3, 0),
		Color3.fromRGB(46, 74, 140)
	)
	for _, r in { 0.9, -0.5 } do
		k:neon(
			"CityRoad",
			Vector3.new(12, 1, 1900),
			CFrame.new(90, -DEPTH + 3, -60) * CFrame.Angles(0, r, 0),
			theme.stripeA
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
			k:mesh("Mesa", id, palette, Vector3.one * scale, cf, size)
		else
			k:box("Mesa", size, cf, Color3.fromRGB(170, 92, 60))
		end
	end
	for i = 1, 8 do
		mesa(rng:NextNumber(280, 460), i * 2.399, rng:NextNumber(0.5, 0.9))
	end
	for i = 1, 12 do
		mesa(860, (i / 12) * math.pi * 2, 1.9)
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
		Vector3.new(3, 1, 1900),
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
		local p = ring(rng:NextNumber(130, 620), i * 2.399)
		local scale = rng:NextNumber(1.6, 2.6)
		local cf = CFrame.new(p.X, -DEPTH + 21 * scale, p.Z)
		if spruce then
			k:mesh("Spruce", spruce, palette, Vector3.one * scale, cf, Vector3.new(17.6, 42, 17.8) * scale)
		else
			k:box("Spruce", Vector3.new(14, 42, 14) * scale, cf, Color3.fromRGB(46, 96, 80))
		end
	end
	-- a ski lift climbing out of the valley
	local tower = piece("SP_LM_LiftTower_A")
	for i = 0, 4 do
		local p = Vector3.new(-430 + i * 80, 0, -300 + i * 60)
		local rise = i * 44
		local cf = CFrame.new(p.X, -DEPTH + rise + 80, p.Z)
		if tower then
			k:mesh("LiftTower", tower, palette, Vector3.one * 2, cf, Vector3.new(40, 158, 38))
		end
		k:cyl(
			"LiftBase",
			180 - i * 12,
			rise + 4,
			CFrame.new(p.X, -DEPTH + (rise + 4) / 2, p.Z),
			_theme.world,
			Enum.Material.Snow
		)
	end
	k:box(
		"Lake",
		Vector3.new(260, 1, 180),
		CFrame.new(240, -DEPTH + 3, 200),
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
	local white = if world == "Downtown" then Color3.fromRGB(150, 130, 190) else Color3.fromRGB(250, 248, 246)
	for i = 1, 10 do
		local a = i * 2.399
		local p = ring(rng:NextNumber(120, 420), a)
		local y = rng:NextNumber(-150, -24)
		local base = rng:NextNumber(26, 46)
		for j = -1, 1 do
			local puff = cloudKit:ball(
				"Cloud",
				base * (if j == 0 then 1 else 0.72),
				CFrame.new(p.X + j * base * 0.6, y, p.Z + j * base * 0.2),
				white
			)
			puff.Transparency = 0.18
			puff.CastShadow = false
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
