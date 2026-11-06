--!strict
-- PadDressing: the life on a Launch Pad (Round 7, A-06; to R7-IMG-04 and R7-IMG-05). Adam on Downtown: "everything is just a shape
-- ... the bushes are a sphere of grass on a block". Low-poly faceted bushes with clumpy leaves and flowers, trees, street furniture
-- for each World, bunting over the walking lines, and a road-closed set past the START gantry with an invisible wall behind it, so the
-- road that climbs into the sky never looks walkable or unfinished. Original shapes in the pad's own palette; everything stays clear of
-- the kiosks, the ramp lanes, the arrival pad and the HOME portal (PadParts' layout).
--
--   PadDressing.bush(k, x, z, scale?, seed?)    PadDressing.dress(k, theme, world)

local PadParts = require(script.Parent.PadParts)

local PadDressing = {}

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

local LEAVES = { rgb(64, 150, 70), rgb(86, 178, 82), rgb(46, 122, 60), rgb(110, 190, 90) }
local FLOWERS = { rgb(255, 110, 160), rgb(255, 214, 70), rgb(255, 255, 255), rgb(240, 80, 70), rgb(170, 120, 255) }
local WOOD = rgb(132, 88, 54)
local STEEL = rgb(60, 66, 82)
local INK = rgb(20, 24, 40)

-- A clumpy faceted bush: tilted blocks in three greens round a core, with a few flowers on top. Same seed, same bush.
function PadDressing.bush(k: any, x: number, z: number, scale: number?, seed: number?, flowers: boolean?)
	local s = scale or 1
	local rng = Random.new(seed or (x * 31 + z * 17))
	local base = CFrame.new(x, 0, z)
	k:box("BushCore", Vector3.new(3.2, 2.4, 3.2) * s, base * CFrame.new(0, 1.3 * s, 0), LEAVES[3])
	for i = 1, 6 do
		local a = i / 6 * math.pi * 2 + rng:NextNumber(0, 0.6)
		local size = Vector3.new(rng:NextNumber(1.8, 2.6), rng:NextNumber(1.6, 2.4), rng:NextNumber(1.8, 2.6)) * s
		local at = base
			* CFrame.new(math.cos(a) * 1.4 * s, (1.2 + rng:NextNumber(0, 1.2)) * s, math.sin(a) * 1.4 * s)
			* CFrame.Angles(rng:NextNumber(-0.5, 0.5), rng:NextNumber(0, math.pi), rng:NextNumber(-0.5, 0.5))
		k:box("BushLeaf", size, at, LEAVES[rng:NextInteger(1, #LEAVES)])
	end
	k:box(
		"BushTop",
		Vector3.new(2.4, 1.8, 2.4) * s,
		base * CFrame.new(0, 2.9 * s, 0) * CFrame.Angles(0.3, rng:NextNumber(0, math.pi), 0.2),
		LEAVES[4]
	)
	if flowers ~= false then
		for _ = 1, 5 do
			local a = rng:NextNumber(0, math.pi * 2)
			local r = rng:NextNumber(0.6, 1.9) * s
			k:ball(
				"Flower",
				0.6 * s,
				base * CFrame.new(math.cos(a) * r, (2.6 + rng:NextNumber(0, 1)) * s, math.sin(a) * r),
				FLOWERS[rng:NextInteger(1, #FLOWERS)]
			)
		end
	end
end

-- A tree like the island's: a trunk and three faceted crowns.
local function tree(k: any, x: number, z: number, world: string)
	local base = CFrame.new(x, 0, z)
	if world == "SummitPass" then
		-- a pine: three stacked tilted cones of blocks, with snow on the top one
		k:cyl("Trunk", 1.4, 4, base * CFrame.new(0, 2, 0), WOOD)
		for i, w in { 9, 7, 4.6 } do
			for j = 0, 2 do
				k:box(
					"Pine",
					Vector3.new(w, 2.6, w),
					base * CFrame.new(0, 3.4 + i * 2.6, 0) * CFrame.Angles(0, j * math.pi / 6, 0),
					rgb(44, 104, 76)
				)
			end
		end
		k:box(
			"PineSnow",
			Vector3.new(3.4, 1, 3.4),
			base * CFrame.new(0, 12.6, 0),
			rgb(248, 252, 255),
			Enum.Material.Snow
		)
		return
	end
	k:cyl("Trunk", 1.6, 9, base * CFrame.new(0, 4.5, 0), WOOD)
	local rng = Random.new(x * 7 + z * 13)
	for i, at in { Vector3.new(0, 11, 0), Vector3.new(1.8, 9.4, 1), Vector3.new(-1.6, 9.6, -1.2) } do
		k:box(
			"Crown",
			Vector3.new(6.4, 5, 6.4) - Vector3.new(i, i * 0.6, i),
			base * CFrame.new(at) * CFrame.Angles(rng:NextNumber(-0.3, 0.3), rng:NextNumber(0, math.pi), 0.2),
			if world == "DustyHighway" then rgb(120, 150, 70) else LEAVES[i]
		)
	end
end

local function lamp(k: any, x: number, z: number, face: number, glow: Color3)
	local base = CFrame.new(x, 0, z) * CFrame.Angles(0, face, 0)
	k:cyl("LampFoot", 1.6, 0.6, base * CFrame.new(0, 0.3, 0), STEEL)
	k:cyl("LampPost", 0.6, 11, base * CFrame.new(0, 5.8, 0), STEEL)
	k:box("LampArm", Vector3.new(0.4, 0.4, 2.6), base * CFrame.new(0, 11, -1.1), STEEL)
	local bulb = k:neon("LampBulb", Vector3.new(1.2, 0.8, 1.2), base * CFrame.new(0, 10.5, -2.2), glow)
	local light = Instance.new("PointLight")
	light.Color = glow
	light.Range = 16
	light.Brightness = 1.2
	light.Shadows = false
	light.Parent = bulb
end

local function bench(k: any, x: number, z: number, face: number)
	local base = CFrame.new(x, 0, z) * CFrame.Angles(0, face, 0)
	k:box("BenchSeat", Vector3.new(5, 0.4, 1.6), base * CFrame.new(0, 1.6, 0), WOOD)
	k:box("BenchBack", Vector3.new(5, 1.4, 0.3), base * CFrame.new(0, 2.6, 0.75), WOOD)
	for _, s in { -2, 2 } do
		k:box("BenchLeg", Vector3.new(0.3, 1.6, 1.4), base * CFrame.new(s, 0.8, 0), STEEL)
	end
end

local function hydrant(k: any, x: number, z: number)
	k:cyl("Hydrant", 1.2, 2.2, CFrame.new(x, 1.1, z), rgb(226, 54, 54))
	k:ball("HydrantCap", 1.2, CFrame.new(x, 2.3, z), rgb(226, 54, 54))
	k:cyl("HydrantNozzle", 0.5, 1.8, CFrame.new(x, 1.4, z) * CFrame.Angles(0, 0, 0), rgb(240, 200, 60))
end

local function crate(k: any, x: number, z: number, size: number, turn: number)
	local at = CFrame.new(x, size / 2, z) * CFrame.Angles(0, turn, 0)
	k:box("Crate", Vector3.new(size, size, size), at, rgb(168, 116, 64), Enum.Material.WoodPlanks)
	k:box("CrateBand", Vector3.new(size + 0.1, 0.3, size + 0.1), at * CFrame.new(0, size * 0.3, 0), rgb(110, 72, 40))
end

local function tyres(k: any, x: number, z: number, count: number)
	for i = 1, count do
		local t = k:cyl("Tyre", 3, 1.1, CFrame.new(x, 0.55 + (i - 1) * 1.1, z), INK)
		t.Material = Enum.Material.SmoothPlastic
		k:cyl("TyreHub", 1.4, 1.14, CFrame.new(x, 0.55 + (i - 1) * 1.1, z), rgb(170, 170, 176))
	end
end

-- Bunting: little flags hung in a line between two points.
local function bunting(k: any, a: Vector3, b: Vector3, colours: { Color3 })
	local n = math.max(math.floor((b - a).Magnitude / 2.2), 2)
	local dir = (b - a).Unit
	for i = 0, n do
		local t = i / n
		local sag = math.sin(t * math.pi) * 1.6
		local p = a:Lerp(b, t) - Vector3.new(0, sag, 0)
		k:wedge(
			"Bunting",
			Vector3.new(0.1, 1.2, 1),
			CFrame.lookAt(p, p + dir) * CFrame.Angles(math.pi, math.pi / 2, 0),
			colours[i % #colours + 1]
		)
	end
end

-- A road-closed set across the road past the START gantry, and an invisible wall behind it (A-06: "I don't want you to be able to
-- walk further on this road").
local function roadClosed(k: any, theme: any)
	local foot, len, rise, wide = PadParts.RampFoot, PadParts.RampLength, PadParts.RampRise, PadParts.RampWidth
	local z = foot - len - 3 -- on the deck, past the gantry
	local y = rise
	for _, s in { -1, 1 } do
		k:box("BarrierLeg", Vector3.new(0.8, 3, 0.8), CFrame.new(s * (wide / 2 - 1.2), y + 1.5, z), STEEL)
	end
	local stripes = { rgb(240, 60, 50), rgb(255, 255, 255) }
	local segments = 8
	for i = 0, segments - 1 do
		local x = -wide / 2 + 1 + (i + 0.5) * (wide - 2) / segments
		k:box(
			"BarrierBoard",
			Vector3.new((wide - 2) / segments, 1.2, 0.5),
			CFrame.new(x, y + 2.6, z),
			stripes[i % 2 + 1]
		)
	end
	for i = 1, 5 do
		local x = -wide / 2 + i * wide / 6
		local cone = CFrame.new(x, y, z + 3)
		k:cyl("ConeBase", 2.6, 0.4, cone * CFrame.new(0, 0.2, 0), rgb(255, 120, 30))
		k:cyl("Cone", 1.4, 3.4, cone * CFrame.new(0, 2, 0), rgb(255, 120, 30))
		k:cyl("ConeStripe", 1.5, 0.6, cone * CFrame.new(0, 2.2, 0), rgb(255, 255, 255))
	end
	local board = k:box("ClosedSign", Vector3.new(16, 6, 0.4), CFrame.new(0, y + 8, z - 0.2), theme.trim)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Back
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 30
	gui.LightInfluence = 0
	gui.Parent = board
	local label = Instance.new("TextLabel")
	label.BackgroundColor3 = rgb(250, 200, 40)
	label.Size = UDim2.fromScale(1, 1)
	label.FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json")
	label.TextScaled = true
	label.TextColor3 = INK
	label.Text = "ROAD CLOSED\nRUNS START AT THE RAMP"
	local inset = Instance.new("UIPadding")
	inset.PaddingLeft = UDim.new(0.04, 0)
	inset.PaddingRight = UDim.new(0.04, 0)
	inset.PaddingTop = UDim.new(0.06, 0)
	inset.PaddingBottom = UDim.new(0.06, 0)
	inset.Parent = label
	label.Parent = gui
	for _, s in { -1, 1 } do
		k:box("SignPost", Vector3.new(0.5, 5, 0.5), CFrame.new(s * 6.5, y + 2.5, z - 0.2), STEEL)
	end
	-- the invisible wall: as wide as the road and tall enough that no jump clears it
	local wall = k:box("RoadClosedWall", Vector3.new(wide + 8, 40, 1), CFrame.new(0, y + 20, z - 3), INK, nil, true)
	wall.Transparency = 1
	wall.CanQuery = false
end

function PadDressing.dress(k: any, theme: any, world: string)
	-- foliage everywhere: bushes in the free spaces, two trees at the back
	for i, p in { { -20, -30 }, { 20, -30 }, { -40, 12 }, { -24, 32 }, { 22, 32 }, { 40, -2 }, { -12, 40 }, { 12, 40 } } do
		PadDressing.bush(k, p[1], p[2], if i <= 2 then 1.2 else 1, i * 101, world ~= "SummitPass" or i % 2 == 0)
	end
	tree(k, -32, 26, world)
	tree(k, 30, -30, world)
	-- lamps beside the ramp's foot and by the arrival pad
	local glow = if world == "DustyHighway"
		then rgb(255, 196, 120)
		elseif world == "SummitPass" then rgb(200, 226, 255)
		else rgb(255, 240, 200)
	lamp(k, -11, -40, 0, glow)
	lamp(k, 11, -40, 0, glow)
	lamp(k, -12, 26, math.pi, glow)
	lamp(k, 12, 26, math.pi, glow)
	bench(k, -20, 38, math.rad(200))
	bench(k, 20, 38, math.rad(160))
	-- bunting over the walking lines, between the lamps
	local flags = if world == "DustyHighway"
		then { rgb(220, 70, 60), rgb(250, 200, 70), rgb(80, 150, 200) }
		elseif world == "SummitPass" then { rgb(232, 64, 72), rgb(255, 255, 255), rgb(60, 150, 240) }
		else { rgb(255, 90, 90), rgb(255, 214, 70), rgb(80, 200, 255), rgb(120, 220, 120) }
	bunting(k, Vector3.new(-11, 10.8, -40), Vector3.new(-12, 10.8, 26), flags)
	bunting(k, Vector3.new(11, 10.8, -40), Vector3.new(12, 10.8, 26), flags)
	if world == "Downtown" then
		hydrant(k, -16, -36)
		hydrant(k, 16, 22)
	elseif world == "DustyHighway" then
		crate(k, -38, -16, 3, 0.3)
		crate(k, -36, -19, 2.4, 0.9)
		crate(k, -37, -17.5, 2, 0.5)
		tyres(k, 38, -24, 3)
		tyres(k, 36, -28, 2)
	else
		crate(k, -38, -16, 2.6, 0.4)
		tyres(k, 38, -24, 2)
	end
	roadClosed(k, theme)
end

return PadDressing
