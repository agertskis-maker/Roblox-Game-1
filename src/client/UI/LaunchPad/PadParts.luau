--!strict
-- PadParts: the things that stand on a Launch Pad (Lane 3, Launch Pad redesign): the round platform and its rail, the ramp and START
-- gantry, the HOME portal, the four kiosks (STAMINA since 2026-11-05) and each World's small touches. One measured layout; the theme changes the look only.
-- Every function places through a PadKit and registers its motion with `life`, which runs only while the pad is on show.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SignKit = require(ReplicatedStorage.Shared.Island.SignKit)
local GameIcons = require(script.Parent.Parent.Prototype.GameIcons)
local Motion = require(script.Parent.Parent.Prototype.Motion)
local RealCar = require(script.Parent.Parent.Prototype.RealCar)
local StyleState = require(script.Parent.Parent.Prototype.StyleState)
local CarKit = require(script.Parent.Parent.Prototype.CarKit)

local PadParts = {}

PadParts.Radius = 46
PadParts.RampFoot = -45 -- z of the ramp's foot, just inside the rail gap
PadParts.RampLength = 30
PadParts.RampRise = 9
PadParts.RampWidth = 18

local make = CarKit.make
local R = PadParts.Radius
local GAP = math.rad(14) -- half of the rail's opening for the ramp, seen from the centre
local RAIL_SEGMENTS = 24
local WALL_SIDES = 16
local rgb = Color3.fromRGB
local GOLD = rgb(244, 190, 60)
local SHOWROOM_SECONDS = 5
local SPRAY_SECONDS = 3
local CHROME = rgb(205, 212, 226)
local INK = rgb(26, 34, 56)

local function surface(part: BasePart, face: Enum.NormalId, pps: number): SurfaceGui
	local g = Instance.new("SurfaceGui")
	g.Face = face
	g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	g.PixelsPerStud = pps
	g.LightInfluence = 0.4
	g.Parent = part
	return g
end

-- The round floor, its underside, the lanes to the ramp, the rail and the invisible wall behind it.
function PadParts.platform(k: any, theme: any)
	k:cyl("Floor", R * 2, 2, CFrame.new(0, -1, 0), theme.floor, theme.floorMaterial, true)
	k:cyl("Rim", R * 2 + 3, 1.4, CFrame.new(0, -1.4, 0), theme.rim, Enum.Material.SmoothPlastic)
	k:cyl("RimGlow", R * 2 + 1.4, 0.5, CFrame.new(0, -2.4, 0), theme.glow, Enum.Material.Neon)
	k:cyl("Under", R * 2 - 4, 6, CFrame.new(0, -5.4, 0), theme.under)
	k:cyl("Under", R * 2 - 26, 10, CFrame.new(0, -13, 0), theme.under)
	k:cyl("Under", R * 2 - 56, 12, CFrame.new(0, -23, 0), theme.under)
	k:ball("UnderTip", R, CFrame.new(0, -30, 0), theme.under)
	-- a calm inner circle, so the emblem sits on something
	k:cyl("Panel", R * 2 - 14, 0.1, CFrame.new(0, 0.01, 0), theme.panel, theme.floorMaterial)
	k:cyl("Panel", R * 2 - 18, 0.1, CFrame.new(0, 0.07, 0), theme.floor, theme.floorMaterial)
	k:cyl("Panel", 60, 0.1, CFrame.new(0, 0.13, 0), theme.panel, theme.floorMaterial)
	k:cyl("Panel", 56, 0.1, CFrame.new(0, 0.19, 0), theme.floor, theme.floorMaterial)
	-- two lanes from the arrival pad to the ramp
	for _, s in { 1, -1 } do
		k:box("Lane", Vector3.new(2.8, 0.1, 74), CFrame.new(s * 3.2, 0.25, -9), theme.stripeA)
		k:box("LaneEdge", Vector3.new(0.8, 0.1, 74), CFrame.new(s * 5.6, 0.25, -9), theme.stripeB)
	end

	local step = math.pi * 2 / RAIL_SEGMENTS
	local chord = 2 * R * math.sin(step / 2)
	for i = 0, RAIL_SEGMENTS - 1 do
		local a = (i + 0.5) * step
		if math.abs(math.pi - a) > GAP then
			local at = CFrame.Angles(0, a, 0) * CFrame.new(0, 0, R - 0.8)
			local glass = k:box(
				"RailGlass",
				Vector3.new(chord, 3.1, 0.2),
				at * CFrame.new(0, 2, 0),
				rgb(170, 216, 240),
				Enum.Material.Glass
			)
			glass.Transparency = 0.6
			k:box(
				"RailTop",
				Vector3.new(chord + 0.4, 0.5, 0.5),
				at * CFrame.new(0, 3.8, 0),
				CHROME,
				Enum.Material.Metal
			)
			if i % 2 == 0 then
				k:cyl(
					"RailPost",
					0.5,
					4,
					CFrame.Angles(0, a + step / 2, 0) * CFrame.new(0, 2, R - 0.8),
					CHROME,
					Enum.Material.Metal
				)
			end
		end
	end
	-- the wall nobody sees: a ring of flat sides, open at the ramp
	local side = math.pi * 2 / WALL_SIDES
	for i = 1, WALL_SIDES - 1 do
		local at = CFrame.Angles(0, math.pi + i * side, 0) * CFrame.new(0, 13, R)
		local wall = k:box("EdgeWall", Vector3.new(2 * R * math.tan(side / 2) + 1, 30, 1), at, rgb(0, 0, 0), nil, true)
		wall.Transparency = 1
	end
end

-- The emblem on the floor: one original mark, used on all three Worlds.
function PadParts.emblem(k: any, theme: any)
	k:cyl("EmblemDisc", 32, 0.1, CFrame.new(0, 0.32, 2), INK)
	k:cyl("EmblemRing", 30, 0.1, CFrame.new(0, 0.4, 2), theme.stripeA)
	k:cyl("EmblemFace", 28.6, 0.1, CFrame.new(0, 0.48, 2), rgb(248, 244, 232))
	local face =
		k:box("EmblemArt", Vector3.new(28, 0.04, 28), CFrame.new(0, 0.56, 2) * CFrame.Angles(0, -math.pi / 2, 0), INK)
	face.Transparency = 1
	local g = surface(face, Enum.NormalId.Top, 24)
	g.LightInfluence = 0.8
	local px = 28 * 24
	local root = make("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, g)
	local cols, rows = 8, 6
	local cell = math.floor(px * 0.9 / cols)
	local top = (px - rows * cell) / 2
	local left = (px - cols * cell) / 2
	for row = 0, rows - 1 do
		for col = 0, cols - 1 do
			if (row + col) % 2 == 0 then
				make("Frame", {
					BackgroundColor3 = INK,
					BorderSizePixel = 0,
					Position = UDim2.fromOffset(left + col * cell, top + row * cell),
					Size = UDim2.fromOffset(cell, cell),
				}, root)
			end
		end
	end
	local band = make("Frame", {
		BackgroundColor3 = INK,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(0.8, 0, 0, cell * 2.2),
	}, root)
	make("UICorner", { CornerRadius = UDim.new(0, 40) }, band)
	-- the official name (decision 0037: "Catch A Car!", in capitals on a logo)
	CarKit.title(band, "CATCH A CAR!", math.floor(cell * 1.15), {
		align = Enum.TextXAlignment.Center,
		size = UDim2.fromScale(1, 1),
		top = CarKit.White,
		bottom = CarKit.Yellow,
		shadow = false,
		stroke = 5,
		z = 3,
	})
end

-- Where the player lands: a glowing pad with the World's name, and the chevrons that show the way the first few times.
function PadParts.arrival(k: any, theme: any, name: string): { Part }
	k:cyl("ArrivalBase", 22, 0.3, CFrame.new(0, 0.22, 34), theme.trim)
	k:cyl("ArrivalGlow", 20, 0.3, CFrame.new(0, 0.3, 34), theme.glow, Enum.Material.Neon)
	k:cyl("ArrivalFace", 18.6, 0.3, CFrame.new(0, 0.38, 34), INK)
	local label = k:box(
		"ArrivalArt",
		Vector3.new(3, 0.04, 10.6),
		CFrame.new(0, 0.56, 26.8) * CFrame.Angles(0, -math.pi / 2, 0),
		INK
	)
	label.Transparency = 1
	local g = surface(label, Enum.NormalId.Top, 40)
	CarKit.title(g, name, 52, {
		align = Enum.TextXAlignment.Center,
		size = UDim2.fromScale(1, 1),
		top = CarKit.Yellow,
		bottom = CarKit.Orange,
		shadow = false,
		stroke = 3,
	})
	local chevrons: { Part } = {}
	for i = 1, 4 do
		for _, s in { 1, -1 } do
			local z = 26 - i * 5.6
			local c = k:neon(
				"Chevron",
				Vector3.new(4, 0.08, 1.2),
				CFrame.new(s * 1.5, 0.64, z) * CFrame.Angles(0, s * math.rad(-34), 0),
				rgb(255, 226, 70)
			)
			c:SetAttribute("Step", i)
			c.Transparency = 1
			table.insert(chevrons, c)
		end
	end
	return chevrons
end

-- The ramp, a safe walkway with no way off, and the road that climbs away into the sky.
function PadParts.ramp(k: any, theme: any)
	local foot, len, rise, wide = PadParts.RampFoot, PadParts.RampLength, PadParts.RampRise, PadParts.RampWidth
	local ramp = k:wedge(
		"Ramp",
		Vector3.new(wide, rise, len),
		CFrame.new(0, rise / 2, foot - len / 2) * CFrame.Angles(0, math.pi, 0),
		theme.floor,
		theme.floorMaterial,
		true
	)
	ramp.CanQuery = true
	k:box(
		"RampDeck",
		Vector3.new(wide, 1, 16),
		CFrame.new(0, rise - 0.5, foot - len - 8),
		theme.floor,
		theme.floorMaterial,
		true
	)
	k:box("RampSupport", Vector3.new(wide - 2, 10, len + 12), CFrame.new(0, -5.2, foot - len / 2 - 8), theme.under)
	local slope = math.atan2(rise, len)
	local along = CFrame.new(0, rise / 2, foot - len / 2) * CFrame.Angles(slope, 0, 0)
	for _, s in { 1, -1 } do
		k:neon(
			"RampEdge",
			Vector3.new(1, 0.9, len + 1.4),
			along * CFrame.new(s * (wide / 2 - 0.2), 0.5, 0),
			theme.stripeA
		)
		k:box("RampLane", Vector3.new(2.8, 0.1, len), along * CFrame.new(s * 3.2, 0.1, 0), theme.stripeA)
		local wall = k:box(
			"EdgeWall",
			Vector3.new(1, 30, len + 34),
			CFrame.new(s * (wide / 2 + 1), 13, foot - len / 2 - 8),
			rgb(0, 0, 0),
			nil,
			true
		)
		wall.Transparency = 1
		k:neon(
			"DeckEdge",
			Vector3.new(1, 0.9, 16),
			CFrame.new(s * (wide / 2 - 0.2), rise + 0.45, foot - len - 8),
			theme.stripeA
		)
	end
	local stop = k:box(
		"EdgeWall",
		Vector3.new(wide + 2, 30, 1),
		CFrame.new(0, rise + 12, foot - len - 16),
		rgb(0, 0, 0),
		nil,
		true
	)
	stop.Transparency = 1
	-- the road goes on up into the sky, for the eye only
	local at = CFrame.new(0, rise, foot - len - 16)
	local pitch = 0.03
	for _ = 1, 6 do
		at = at * CFrame.Angles(pitch, 0.05, 0) * CFrame.new(0, 0, -11)
		k:box("SkyRoad", Vector3.new(wide, 0.8, 23), at, theme.floor, theme.floorMaterial)
		for _, s in { 1, -1 } do
			k:neon(
				"SkyRoadEdge",
				Vector3.new(1, 0.9, 22.6),
				at * CFrame.new(s * (wide / 2 - 0.2), 0.5, 0),
				theme.stripeA
			)
		end
		at = at * CFrame.new(0, 0, -11)
		pitch = math.min(pitch + 0.008, 0.09)
	end
end

-- A start light at rest: three deep reds and a green, so the gantry reads as lights before they are lit.
function PadParts.lightIdle(index: number): Color3
	return if index < 4 then rgb(150, 40, 46) else rgb(40, 150, 76)
end

-- The START gantry over the ramp: two towers, the World's name, four lights and the checkered banner.
function PadParts.gantry(k: any, theme: any, world: string): { Part }
	local z = PadParts.RampFoot - 21
	local x = PadParts.RampWidth / 2 + 2.4
	local legColour = if theme.roof == "Awning" then rgb(36, 70, 170) else theme.pillar
	local material = if theme.roof == "Awning" then Enum.Material.Metal else Enum.Material.Wood
	for _, s in { 1, -1 } do
		k:box("GantryLeg", Vector3.new(2.4, 28, 2.4), CFrame.new(s * x, 10, z), legColour, material)
		k:box("GantryFoot", Vector3.new(4.4, 2, 4.4), CFrame.new(s * x, -3, z), theme.trim)
		k:box("GantryCap", Vector3.new(3.4, 1.4, 3.4), CFrame.new(s * x, 24.4, z), GOLD)
		for i = 0, 1 do
			local y = 2 + i * 7
			k:box(
				"GantryBrace",
				Vector3.new(0.6, 8.6, 0.6),
				CFrame.new(s * (x + 0.9), y + 3.6, z) * CFrame.Angles(0, 0, 0.26),
				GOLD
			)
		end
		if theme.roof == "Chalet" then
			k:ball("GantrySnow", 4.4, CFrame.new(s * x, 25.6, z), rgb(248, 252, 255), Enum.Material.Snow)
		end
	end
	k:box("GantryHead", Vector3.new(x * 2 + 2, 4.4, 2.4), CFrame.new(0, 21, z), legColour, material)
	k:box("GantryHeadTrim", Vector3.new(x * 2 + 3, 0.5, 3), CFrame.new(0, 18.2, z), GOLD)
	SignKit.sign(k.parent, k.origin * CFrame.new(0, 25.6, z + 1.4) * CFrame.Angles(0, math.pi, 0), {
		style = theme.sign,
		text = world,
		width = 20,
		height = 3.4,
	})
	SignKit.sign(k.parent, k.origin * CFrame.new(0, 16.2, z + 1.4) * CFrame.Angles(0, math.pi, 0), {
		style = "Race",
		text = "START",
		width = 13,
		height = 3,
	})
	local lights: { Part } = {}
	for i = 1, 4 do
		local cx = (i - 2.5) * 4.6
		k:cyl("LightHousing", 4, 1.2, CFrame.new(cx, 21, z + 1.5) * CFrame.Angles(math.pi / 2, 0, 0), INK)
		local lamp = k:ball("StartLight", 2.9, CFrame.new(cx, 21, z + 2.1), PadParts.lightIdle(i), Enum.Material.Glass)
		lamp.CastShadow = false
		table.insert(lights, lamp)
	end
	return lights
end

-- HOME: a small version of the island's gates round a swirling field. The field's art is the island portal's own (group-owned).
local SWIRL_A = "rbxassetid://97184972304820"
local SWIRL_B = "rbxassetid://121384250907605"
local CORE = "rbxassetid://131487211688936"

function PadParts.homePortal(k: any, theme: any, life: any): Vector3
	-- its face (the HOME sign and the pool) looks at the middle of the floor, as the kiosks do (2026-11-05, Adam: it was
	-- turned about 45 degrees away)
	-- Brian L, 2026-11-08: moved from (-33, 15) to (-26, 23.5) so it no longer clips into the LUCK kiosk (Lane 2 preview)
	local at = CFrame.lookAt(Vector3.new(-26, 0, 23.5), Vector3.new(0, 0, 2))
	local cream = rgb(232, 214, 178)
	k:box("HomeStep", Vector3.new(19, 0.6, 9), at * CFrame.new(0, 0.3, 0), theme.trim)
	k:box("HomeStep", Vector3.new(16, 0.4, 7), at * CFrame.new(0, 0.8, 0), cream)
	for _, s in { 1, -1 } do
		k:box("HomePillarBase", Vector3.new(4, 1.6, 4), at * CFrame.new(s * 6.6, 1.6, 0), theme.trim)
		k:box("HomePillar", Vector3.new(3.2, 11, 3.2), at * CFrame.new(s * 6.6, 7.6, 0), cream)
		k:box("HomeInlay", Vector3.new(1.3, 7, 0.2), at * CFrame.new(s * 6.6, 7.6, -1.65), rgb(40, 70, 150))
		k:box("HomePillarCap", Vector3.new(4, 1, 4), at * CFrame.new(s * 6.6, 13.5, 0), theme.trim)
		k:ball("HomeKnob", 2.4, at * CFrame.new(s * 6.6, 15, 0), GOLD, Enum.Material.Metal)
	end
	k:box("HomeArch", Vector3.new(16, 2.2, 3), at * CFrame.new(0, 14.3, 0), cream)
	-- the crest with a chunky house
	local crest = at * CFrame.new(0, 18.2, 0)
	local upright = CFrame.Angles(math.pi / 2, 0, 0)
	k:cyl("HomeCrestRim", 7, 0.9, crest * CFrame.new(0, 0, 0.1) * upright, GOLD, Enum.Material.Metal)
	k:cyl("HomeCrest", 6, 1.6, crest * CFrame.new(0, 0, -0.1) * upright, rgb(36, 56, 130))
	k:box("HomeHouse", Vector3.new(2.3, 1.7, 0.4), crest * CFrame.new(0, -0.7, -1.05), GOLD)
	k:box(
		"HomeRoof",
		Vector3.new(2.3, 2.3, 0.4),
		crest * CFrame.new(0, 0.3, -1.05) * CFrame.Angles(0, 0, math.rad(45)),
		GOLD
	)
	SignKit.sign(k.parent, k.origin * at * CFrame.new(0, 14.4, -1.7), {
		style = "Race",
		text = "HOME",
		width = 10,
		height = 2.4,
	})
	-- the field
	local carrier =
		k:box("HomeField", Vector3.new(10, 12, 0.1), at * CFrame.new(0, 7, 0), theme.portal, Enum.Material.Neon)
	carrier.Transparency = 0.35
	local g = surface(carrier, Enum.NormalId.Front, 16)
	g.LightInfluence = 0
	local back = surface(carrier, Enum.NormalId.Back, 16)
	back.LightInfluence = 0
	local swirls: { ImageLabel } = {}
	for _, gui in { g, back } do
		for i, id in { SWIRL_A, SWIRL_B, CORE } do
			local image = make("ImageLabel", {
				BackgroundTransparency = 1,
				Image = id,
				ImageColor3 = if i == 3 then rgb(255, 255, 255) else theme.portal,
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromScale(1.5, 1.25),
				ZIndex = i,
			}, gui) :: ImageLabel
			table.insert(swirls, image)
		end
	end
	local sparkle = Instance.new("ParticleEmitter")
	sparkle.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	sparkle.Rate = 10
	sparkle.Lifetime = NumberRange.new(0.8, 1.6)
	sparkle.Speed = NumberRange.new(2, 5)
	sparkle.Size = NumberSequence.new(0.5)
	sparkle.Color = ColorSequence.new(theme.portal)
	sparkle.EmissionDirection = Enum.NormalId.Front
	sparkle.Parent = carrier
	local light = Instance.new("PointLight")
	light.Color = theme.portal
	light.Range = 22
	light.Brightness = 1
	light.Parent = carrier
	k:cyl("HomePool", 13, 0.1, at * CFrame.new(0, 1.05, -4.6), theme.portal, Enum.Material.Neon).Transparency = 0.5
	life(function(t: number, _dt: number)
		if Motion.reduced() then
			return
		end
		for i, image in swirls do
			image.Rotation = t * (if i % 3 == 1 then 30 elseif i % 3 == 2 then -46 else 12)
		end
	end)
	return (k.origin * at * CFrame.new(0, 2, 0)).Position
end

-- One kiosk. Its open side faces the middle of the floor; `stand` is the glowing circle in front of it.
local function kioskShell(k: any, theme: any, key: string, label: string, at: CFrame): (Part, number)
	local colours = theme.kiosk[key]
	local main, second = colours[1], colours[2]
	k:cyl("KioskBase", 17, 0.7, at * CFrame.new(0, 0.35, 1), theme.trim)
	k:cyl("KioskFloor", 15.6, 0.3, at * CFrame.new(0, 0.7, 1), INK)
	for _, sx in { 1, -1 } do
		for _, sz in { 1, -1 } do
			k:cyl(
				"KioskPost",
				1.5,
				9,
				at * CFrame.new(sx * 6.4, 5, 1 + sz * 5.2),
				theme.pillar,
				if theme.roof == "Chalet" then Enum.Material.Wood else nil
			)
		end
	end
	local top = 9.5
	if theme.roof == "Awning" then
		-- a shop awning: straight stripes down four sloped sides, a flat top and a clean edge
		k:box("AwningTop", Vector3.new(9, 0.8, 9), at * CFrame.new(0, top + 2.7, 1), second)
		for side = 0, 3 do
			local face = at * CFrame.new(0, top + 1.4, 1) * CFrame.Angles(0, side * math.pi / 2, 0)
			-- Round 5 (P-01): one slab in the main colour and the middle stripe 0.04 proud of it (was three stripes), the same
			-- look in two parts, with no shared face
			local slope = face * CFrame.new(0, 0, 6.6) * CFrame.Angles(math.rad(26), 0, 0)
			k:box("AwningStripe", Vector3.new(17.1, 0.4, 5.8), slope, main)
			k:box("AwningStripe", Vector3.new(5.7, 0.4, 5.9), slope * CFrame.new(0, 0.04, 0), second) -- ends 0.05 past the slab
			k:box("AwningEdge", Vector3.new(17.2, 1, 0.3), face * CFrame.new(0, -1.9, 9.3), main)
		end
		top += 3.2
	elseif theme.roof == "Canopy" then
		k:cyl("CanopyLip", 18.6, 0.9, at * CFrame.new(0, top + 0.2, 1), main)
		k:cyl("CanopyBand", 17.6, 1, at * CFrame.new(0, top + 1.1, 1), second)
		k:cyl("CanopyTop", 15, 0.8, at * CFrame.new(0, top + 1.9, 1), rgb(52, 138, 138))
		k:wedge("CanopyFin", Vector3.new(1, 4, 8), at * CFrame.new(0, top + 4.2, 4), main)
		top += 2.4
	else
		local run = 8.4
		for _, s in { 1, -1 } do
			local slab = at * CFrame.new(s * 4.7, top + 2.1, 1) * CFrame.Angles(0, 0, s * math.rad(-30))
			k:box("ChaletRoof", Vector3.new(run + 2.4, 0.8, 14.4), slab, main, Enum.Material.Wood)
			k:box(
				"ChaletSnow",
				Vector3.new(run + 2.8, 0.9, 15),
				slab * CFrame.new(0, 0.8, 0),
				rgb(248, 252, 255),
				Enum.Material.Snow
			)
		end
		k:box("ChaletRidge", Vector3.new(1.8, 1.4, 15.6), at * CFrame.new(0, top + 4.6, 1), main, Enum.Material.Wood)
		k:box(
			"ChaletBeam",
			Vector3.new(14.6, 1, 1),
			at * CFrame.new(0, top - 0.1, -4.6),
			theme.trim,
			Enum.Material.Wood
		)
		for _, s in { 1, -1 } do
			k:ball("ChaletLantern", 1.3, at * CFrame.new(s * 7.2, 7, -4.6), rgb(255, 210, 120), Enum.Material.Neon)
		end
		top += 3
	end
	local chalet = theme.roof == "Chalet"
	SignKit.sign(
		k.parent,
		k.origin * at * CFrame.new(0, if chalet then top - 3.6 else top + 1, if chalet then -6 else -5.2),
		{
			style = theme.sign,
			text = label,
			width = 10,
			height = 2.8,
			accent = main,
		}
	)
	-- the circle to stand on
	local stand = k:cyl("KioskRing", 8, 0.1, at * CFrame.new(0, 0.33, -11), main, Enum.Material.Neon)
	k:cyl("KioskRingCore", 6.8, 0.1, at * CFrame.new(0, 0.41, -11), INK)
	local word = k:box(
		"KioskWord",
		Vector3.new(2.4, 0.04, 6.2),
		at * CFrame.new(0, 0.5, -11) * CFrame.Angles(0, math.pi / 2, 0),
		INK
	)
	word.Transparency = 1
	CarKit.title(surface(word, Enum.NormalId.Top, 30), label, 42, {
		align = Enum.TextXAlignment.Center,
		size = UDim2.fromScale(1, 1),
		top = CarKit.White,
		bottom = CarKit.Yellow,
		shadow = false,
		stroke = 2,
	})
	return stand, top
end

local function bobbing(model: Model, life: any, spin: number)
	local home = model:GetPivot()
	local tick = 0
	life(function(t: number, dt: number)
		tick += dt
		if tick < 1 / 20 or Motion.reduced() then
			return
		end
		tick = 0
		model:PivotTo(home * CFrame.new(0, math.sin(t * 1.6) * 0.5, 0) * CFrame.Angles(0, t * spin, 0))
	end)
end

-- One flat triangle, `depth` thick, from two wedges (pad space points). The longest edge is found first so both wedges are right
-- angled on it.
local function triangle(
	k: any,
	name: string,
	a: Vector3,
	b: Vector3,
	c: Vector3,
	depth: number,
	colour: Color3,
	material: Enum.Material?
)
	local ab, ac, bc = b - a, c - a, c - b
	local abd, acd, bcd = ab:Dot(ab), ac:Dot(ac), bc:Dot(bc)
	if abd > acd and abd > bcd then
		c, a = a, c
	elseif acd > bcd and acd > abd then
		a, b = b, a
	end
	ab, ac, bc = b - a, c - a, c - b
	local right = ac:Cross(ab).Unit
	local up = bc:Cross(right).Unit
	local back = bc.Unit
	local height = math.abs(ab:Dot(up))
	k:wedge(
		name,
		Vector3.new(depth, height, math.abs(ab:Dot(back))),
		CFrame.fromMatrix((a + b) / 2, right, up, back),
		colour,
		material
	)
	k:wedge(
		name,
		Vector3.new(depth, height, math.abs(ac:Dot(back))),
		CFrame.fromMatrix((a + c) / 2, -right, up, -back),
		colour,
		material
	)
end

-- The Stamina bolt as a real zigzag (Adam, 2026-11-05: the first one "doesn't look like a real lightning bolt"): the game's own bolt
-- outline (Prototype.Run.StaminaBolt: a leaning top slab and a long tip), in five triangles, neon yellow round a thinner dark copy
-- 10% bigger, so the dark edge shows from both sides as it turns. `at` is its centre, the bolt in at's XY plane, `size` its height.
local BOLT = {
	A = Vector2.new(0.29, 0),
	B = Vector2.new(0.69, 0),
	C = Vector2.new(0.49, 0.40),
	D = Vector2.new(0.78, 0.40),
	E = Vector2.new(0.26, 1.00),
	F = Vector2.new(0.26, 0.58),
	G = Vector2.new(0.00, 0.58),
}
local BOLT_TRIANGLES = { { "A", "B", "C" }, { "A", "C", "F" }, { "A", "F", "G" }, { "C", "D", "E" }, { "C", "E", "F" } }
local BOLT_MIDDLE = Vector2.new(0.4, 0.5)

function PadParts.lightningBolt(k: any, at: CFrame, size: number, colour: Color3): Model
	local bk, model = k:model("StaminaBolt")
	local function point(key: string, grow: number): Vector3
		local p = BOLT_MIDDLE + (BOLT[key] - BOLT_MIDDLE) * grow
		return (at * CFrame.new((p.X - BOLT_MIDDLE.X) * size, (BOLT_MIDDLE.Y - p.Y) * size, 0)).Position
	end
	for _, t in BOLT_TRIANGLES do
		triangle(
			bk,
			"BoltFace",
			point(t[1], 1),
			point(t[2], 1),
			point(t[3], 1),
			size * 0.14,
			colour,
			Enum.Material.Neon
		)
		triangle(bk, "BoltEdge", point(t[1], 1.1), point(t[2], 1.1), point(t[3], 1.1), size * 0.07, INK)
	end
	local core = bk:box("BoltCore", Vector3.one * 0.4, at, INK)
	core.Transparency = 1
	model.PrimaryPart = core
	local light = Instance.new("PointLight")
	light.Color = colour
	light.Range = 20
	light.Brightness = 2
	light.Parent = core
	local sparks = Instance.new("ParticleEmitter")
	sparks.Name = "Sparks"
	sparks.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	sparks.Rate = 16
	sparks.Lifetime = NumberRange.new(0.7, 1.3)
	sparks.Speed = NumberRange.new(2, 5)
	sparks.SpreadAngle = Vector2.new(180, 180)
	sparks.LightEmission = 1
	sparks.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0) })
	sparks.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, rgb(255, 216, 50)),
		ColorSequenceKeypoint.new(0.5, rgb(255, 64, 70)),
		ColorSequenceKeypoint.new(1, rgb(176, 84, 255)),
	})
	sparks.Parent = core
	return model
end

function PadParts.kiosks(k: any, theme: any, life: any, world: string?): ({ [string]: BasePart }, () -> ())
	local centre = Vector3.new(0, 0, 2)
	local function placed(x: number, z: number): CFrame
		return CFrame.lookAt(Vector3.new(x, 0, z), centre)
	end
	local stands: { [string]: BasePart } = {}
	local rigs: { any } = {}

	-- CARS: a real car on a turntable, a little one floating over the roof
	local carsAt = placed(-27.2, -21.2) -- 2026-11-05: was (-29, -19), mirrors PAINT
	local carTop: number
	stands.Cars, carTop = kioskShell(k, theme, "Cars", "CARS", carsAt)
	local shown = RealCar.mount(k.parent, { length = 9.5, height = 6 })
	local mini = RealCar.mount(k.parent, { length = 5.4, height = 3.4 })
	table.insert(rigs, mini)
	-- the turntable is a little showroom: it brings out this World's cars one after another (Round 4: its nine, Loaner first)
	local line = RealCar.forWorld(world or "Downtown")
	local onShow = 1
	local shownAt = 0
	k:cyl("Turntable", 12.6, 0.8, carsAt * CFrame.new(0, 1.2, 1), theme.kiosk.Cars[1])
	k:cyl("TurntableGlow", 13.2, 0.2, carsAt * CFrame.new(0, 0.95, 1), theme.glow, Enum.Material.Neon)
	local turnAt = k.origin * carsAt * CFrame.new(0, 1.6, 1)
	local miniAt = k.origin * carsAt * CFrame.new(0, carTop + 4.6, 0)
	life(function(t: number, _dt: number)
		if Motion.reduced() then
			return
		end
		shown:pivotTo(turnAt * CFrame.Angles(0, t * 0.5, 0))
		if t - shownAt > SHOWROOM_SECONDS and #line > 0 then
			shownAt = t
			onShow = (onShow % #line) + 1
			shown:setCar(line[onShow].name)
		end
		mini:pivotTo(miniAt * CFrame.new(0, math.sin(t * 1.6) * 0.5, 0) * CFrame.Angles(0, t * 0.9, 0))
	end)
	shown:pivotTo(turnAt * CFrame.Angles(0, 0.6, 0))
	mini:pivotTo(miniAt)

	-- TRAILS: the car circles its pedestal with a real trail behind it; a rainbow knot floats over the roof
	local trailAt = placed(28.6, 19.3) -- 2026-11-05: was (33, 13); PAINT, STAMINA and TRAILS now stand 36 degrees apart
	local trailTop: number
	stands.Trails, trailTop = kioskShell(k, theme, "Trails", "TRAILS", trailAt)
	k:cyl("Pedestal", 12.6, 0.8, trailAt * CFrame.new(0, 1.2, 1), theme.kiosk.Trails[1])
	k:cyl("PedestalGlow", 13.2, 0.2, trailAt * CFrame.new(0, 0.95, 1), theme.glow, Enum.Material.Neon)
	local runner = RealCar.mount(k.parent, { length = 5.4, height = 3.6 })
	table.insert(rigs, runner)
	runner:setPaint({ id = "kiosk", kind = "solid", colours = { rgb(50, 190, 255) } } :: any)
	local carrier = k:box("TrailCarrier", Vector3.new(0.2, 0.2, 0.2), trailAt, rgb(0, 0, 0))
	carrier.Transparency = 1
	local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
	a0.Position = Vector3.new(-1.5, 0, 0)
	a1.Position = Vector3.new(1.5, 0, 0)
	a0.Parent = carrier
	a1.Parent = carrier
	local trail = Instance.new("Trail")
	trail.Attachment0 = a0
	trail.Attachment1 = a1
	trail.Lifetime = 2.2
	trail.LightEmission = 0.6
	trail.FaceCamera = false
	trail.TextureMode = Enum.TextureMode.Stretch
	trail.Parent = carrier
	local function trailArt()
		local item = StyleState.item("Trails")
		local key = item and item.key or "rainbow"
		trail.Texture = GameIcons.uri("ribbon_" .. key) or ""
	end
	trailArt()
	local trailHome = k.origin * trailAt * CFrame.new(0, 1.7, 1)
	local function ride(t: number)
		local a = t * 1.1
		local p = trailHome * CFrame.Angles(0, a, 0) * CFrame.new(3.4, 0, 0)
		runner:pivotTo(p)
		carrier.CFrame = runner:tail() * CFrame.new(0, -0.5, 0.4)
	end
	ride(0)
	life(function(t: number, _dt: number)
		if not Motion.reduced() then
			ride(t)
		end
	end)
	local knot, knotModel = k:model("TrailKnot")
	local beads = 16
	local facing = trailAt * CFrame.new(0, trailTop + 2.6, 0) * CFrame.Angles(0, math.rad(45), 0)
	for i = 0, beads - 1 do
		local a = i / beads * math.pi * 2
		local cf = facing * CFrame.Angles(0, 0, a) * CFrame.new(0, 2.5, 0)
		knot:ball("LoopBead", 1.5, cf, Color3.fromHSV(i / beads, 0.85, 1), Enum.Material.Neon)
	end
	bobbing(knotModel, life, 0)

	-- PAINT: a spray booth with shelves of cans; a chunky can floats over the roof
	local paintAt = placed(27.2, -21.2) -- 2026-11-05: was (29, -19), see TRAILS
	local paintTop: number
	stands.Paint, paintTop = kioskShell(k, theme, "Paint", "PAINT", paintAt)
	k:box("BoothWall", Vector3.new(14, 8.4, 0.8), paintAt * CFrame.new(0, 4.9, 6.4), rgb(216, 224, 236))
	k:box("BoothShelf", Vector3.new(11, 0.4, 1.6), paintAt * CFrame.new(0, 3.5, 5.4), theme.trim)
	k:box("BoothShelf", Vector3.new(11, 0.4, 1.6), paintAt * CFrame.new(0, 6.3, 5.4), theme.trim)
	local cans = {
		rgb(232, 64, 72),
		rgb(250, 170, 50),
		rgb(250, 220, 70),
		rgb(70, 200, 110),
		rgb(60, 150, 240),
		rgb(170, 90, 230),
	}
	for i, c in cans do
		local row = if i <= 3 then 3.7 else 6.5
		local x = ((i - 1) % 3 - 1) * 3.2
		k:cyl("Can", 1.3, 1.9, paintAt * CFrame.new(x, row + 0.95, 5.2), c)
	end
	-- a car in the booth, changing colour under the spray
	local sprayed = RealCar.mount(k.parent, { length = 9, height = 5.4 })
	table.insert(rigs, sprayed)
	sprayed:pivotTo(k.origin * paintAt * CFrame.new(0, 0.9, 0) * CFrame.Angles(0, math.rad(70), 0))
	local coat = 0
	local coatAt = -math.huge
	life(function(t: number, _dt: number)
		if t - coatAt > SPRAY_SECONDS then
			coatAt = t
			coat = (coat % #cans) + 1
			sprayed:setPaint({ id = "kiosk", kind = "solid", colours = { cans[coat] } } :: any)
		end
	end)
	local can, canModel = k:model("SprayCan")
	local canAt = paintAt * CFrame.new(0, paintTop + 4.8, 0) * CFrame.Angles(0, 0, math.rad(-18))
	for i, c in { rgb(232, 64, 72), rgb(250, 200, 60), rgb(60, 150, 240) } do
		can:cyl("CanBand", 3, 1.3, canAt * CFrame.new(0, (i - 2) * 1.3, 0), c)
	end
	can:cyl("CanShoulder", 2.2, 0.8, canAt * CFrame.new(0, 2.3, 0), CHROME, Enum.Material.Metal)
	can:cyl("CanNozzle", 1.1, 0.8, canAt * CFrame.new(0, 3, 0), CHROME, Enum.Material.Metal)
	for i, size in { 1.5, 1.1, 0.8 } do
		can:ball(
			"SprayPuff",
			size,
			canAt * CFrame.new(i * 1.4, 3.1 + i * 0.2, 0),
			rgb(255, 150, 200),
			Enum.Material.Neon
		)
	end
	bobbing(canModel, life, 0.6)

	local function sync()
		local name = StyleState.car()
		for _, r in rigs do
			r:setCar(name)
		end
		trailArt()
	end
	-- STAMINA (Adam, 2026-11-05: the Stamina Shop goes in the hubs before a run): a battery tower of the three bolt colours under the
	-- roof, crackling up to a big zigzag bolt that floats and turns over it. Its circle opens the STAMINA SHOP card (StaminaPanel).
	local stamAt = placed(34.5, -1.2)
	local stamTop: number
	stands.Stamina, stamTop = kioskShell(k, theme, "Stamina", "STAMINA", stamAt)
	local cellColours = { rgb(255, 216, 50), rgb(255, 64, 70), rgb(176, 84, 255) }
	k:cyl("BatteryBase", 6, 0.9, stamAt * CFrame.new(0, 1.3, 1), INK)
	local cells: { BasePart } = {}
	for i, colour in cellColours do
		local y = 1.75 + (i - 0.5) * 1.9
		table.insert(cells, k:cyl("BatteryCell", 3.8, 1.6, stamAt * CFrame.new(0, y, 1), colour, Enum.Material.Neon))
		k:cyl("BatteryCap", 4.1, 0.3, stamAt * CFrame.new(0, y + 0.95, 1), INK)
	end
	local terminal = k:cyl("BatteryTerminal", 1.4, 0.8, stamAt * CFrame.new(0, 7.9, 1), CHROME, Enum.Material.Metal)
	local bolt = PadParts.lightningBolt(k, stamAt * CFrame.new(0, stamTop + 6.2, 1), 8, cellColours[1])
	bobbing(bolt, life, 0.9)
	-- two arcs from the terminal up to the bolt, re-bent several times a second
	local from = Instance.new("Attachment")
	from.Parent = terminal
	local to = Instance.new("Attachment")
	to.Parent = bolt.PrimaryPart
	local arcs: { Beam } = {}
	for i = 1, 2 do
		local beam = Instance.new("Beam")
		beam.Attachment0 = from
		beam.Attachment1 = to
		beam.Width0 = 0.45
		beam.Width1 = 0.2
		beam.Segments = 14
		beam.LightEmission = 1
		beam.FaceCamera = true
		beam.Color = ColorSequence.new(cellColours[i * 2 - 1], rgb(255, 255, 255))
		beam.Parent = terminal
		table.insert(arcs, beam)
	end
	local nextArc = 0
	life(function(t: number, _dt: number)
		local still = Motion.reduced()
		for i, cell in cells do
			local wave = if still then 1 else (math.sin(t * 3 - i * 1.1) + 1) / 2
			cell.Color = cellColours[i]:Lerp(rgb(255, 255, 255), 0.35 * wave)
		end
		if t >= nextArc then
			nextArc = t + 0.09 + math.random() * 0.1
			for _, arc in arcs do
				arc.Enabled = not still and math.random() > 0.15
				arc.CurveSize0 = math.random(-5, 5)
				arc.CurveSize1 = math.random(-5, 5)
			end
		end
	end)

	-- LUCK (Lane 2 preview, Brian L 2026-11-08): the Luck Shop, mirroring STAMINA on the other side of the floor. A pot of
	-- gold coins under the roof and a big four-leaf clover that floats and turns over it. Its circle opens the LUCK SHOP card
	-- (LuckPanel). Built with the same kiosk shell as the others; the look is a stand-in for Adam's review.
	local luckAt = placed(-34.5, -1.2)
	local luckTop: number
	stands.Luck, luckTop = kioskShell(k, theme, "Luck", "LUCK", luckAt)
	local cloverGreen = rgb(60, 200, 90)
	k:cyl("LuckPot", 5.6, 2.4, luckAt * CFrame.new(0, 2.5, 1), INK)
	k:cyl("LuckPotRim", 6.2, 0.5, luckAt * CFrame.new(0, 3.8, 1), GOLD, Enum.Material.Metal)
	for i = 1, 7 do
		local a = i * 2.4
		local r = if i == 7 then 0 else 1.6
		k:cyl(
			"LuckCoin",
			1.7,
			0.35,
			luckAt
				* CFrame.new(math.cos(a) * r, 4.2 + (i % 3) * 0.3, 1 + math.sin(a) * r)
				* CFrame.Angles(0.3 * i, 0, 0.5),
			GOLD,
			Enum.Material.Metal
		)
	end
	local ck, clover = k:model("LuckClover")
	local cloverAt = luckAt * CFrame.new(0, luckTop + 6.2, 1)
	for i = 0, 3 do
		local leaf = cloverAt * CFrame.Angles(0, 0, i * math.pi / 2) * CFrame.new(0, 1.55, 0)
		for _, side in { -0.75, 0.75 } do
			ck:ball("CloverLeaf", 2.6, leaf * CFrame.new(side, 0.35, 0), cloverGreen, Enum.Material.Neon)
		end
	end
	ck:cyl("CloverStem", 0.5, 3, cloverAt * CFrame.new(0.6, -2.8, 0) * CFrame.Angles(0, 0, 0.2), rgb(40, 140, 60))
	local cloverCore = ck:ball("CloverCore", 1.4, cloverAt, GOLD, Enum.Material.Neon)
	clover.PrimaryPart = cloverCore
	local cloverLight = Instance.new("PointLight")
	cloverLight.Color = cloverGreen
	cloverLight.Range = 18
	cloverLight.Brightness = 2
	cloverLight.Parent = cloverCore
	bobbing(clover, life, 0.9)

	sync()
	shown:setCar(line[1] and line[1].name)
	return stands, sync
end

-- Each World's small touches, kept to the edge of the floor.
function PadParts.touches(k: any, theme: any, world: string, life: any)
	local function planter(x: number, z: number)
		k:box("Planter", Vector3.new(3.4, 2.4, 3.4), CFrame.new(x, 1.2, z), theme.pillar)
		if world == "DustyHighway" then
			k:cyl("Cactus", 1.5, 4.4, CFrame.new(x, 4.8, z), rgb(70, 140, 90))
			k:ball("CactusTop", 1.5, CFrame.new(x, 7, z), rgb(70, 140, 90))
			k:cyl("CactusArm", 0.9, 1.8, CFrame.new(x + 1.1, 5, z), rgb(70, 140, 90))
		else
			k:ball("Hedge", 4, CFrame.new(x, 4, z), rgb(70, 160, 80), Enum.Material.Grass)
		end
	end
	if world == "Downtown" then
		for _, p in { { -14, -30 }, { 14, -30 } } do
			planter(p[1], p[2])
		end
	elseif world == "DustyHighway" then
		for _, p in { { -14, -30 }, { 14, -30 }, { 18, 34 }, { -18, 34 } } do
			planter(p[1], p[2])
		end
		-- a vintage pump and the DUSTY STOP sign
		local pump = CFrame.new(-16, 0, -14) * CFrame.Angles(0, math.rad(40), 0)
		k:box("PumpBase", Vector3.new(3, 0.6, 2.4), pump * CFrame.new(0, 0.3, 0), theme.pillar)
		k:box("Pump", Vector3.new(2.2, 5.4, 1.6), pump * CFrame.new(0, 3.3, 0), rgb(214, 70, 62))
		k:cyl("PumpDial", 2, 0.5, pump * CFrame.new(0, 6.6, 0) * CFrame.Angles(math.pi / 2, 0, 0), rgb(250, 236, 208))
		k:box("PumpFace", Vector3.new(1.5, 1.6, 0.1), pump * CFrame.new(0, 3.6, -0.84), rgb(250, 236, 208))
		for _, s in { 1, -1 } do
			k:box("SignPost", Vector3.new(0.8, 12, 0.8), CFrame.new(-41 + s * 2.2, 6, -3 + s * 3.4), theme.trim)
		end
		SignKit.sign(k.parent, k.origin * CFrame.new(-41, 13, -3) * CFrame.Angles(0, math.rad(-57), 0), {
			style = "Diner",
			text = "DUSTY STOP",
			width = 15,
			height = 4,
		})
	else
		-- a little fireplace, skis and drifts of snow along the rail
		local fire = CFrame.new(-17, 0, 37) * CFrame.Angles(0, math.rad(200), 0)
		k:box("Hearth", Vector3.new(7, 5.4, 3), fire * CFrame.new(0, 2.7, 0), rgb(130, 130, 138), Enum.Material.Slate)
		k:box("HearthOpen", Vector3.new(4.2, 2.8, 0.3), fire * CFrame.new(0, 1.8, -1.45), rgb(30, 22, 20))
		k:box("Chimney", Vector3.new(3, 6, 2.4), fire * CFrame.new(0, 8, 0.2), rgb(130, 130, 138), Enum.Material.Slate)
		local logs = k:neon("Embers", Vector3.new(3, 0.5, 0.8), fire * CFrame.new(0, 0.8, -1.5), rgb(255, 150, 50))
		local flame = Instance.new("Fire")
		flame.Size = 3
		flame.Heat = 4
		flame.Parent = logs
		local warm = Instance.new("PointLight")
		warm.Color = rgb(255, 170, 90)
		warm.Range = 18
		warm.Brightness = 1.6
		warm.Parent = logs
		for i, c in { rgb(232, 64, 72), rgb(60, 150, 240), rgb(250, 200, 60) } do
			k:box("Ski", Vector3.new(0.6, 8, 0.2), CFrame.new(16 + i * 1.3, 4, 37.6) * CFrame.Angles(0.14, 0, 0), c)
		end
		for i = 1, 14 do
			local a = i / 14 * math.pi * 2 + 0.12
			if math.abs(math.pi - a) > 0.4 then
				k:ball(
					"SnowDrift",
					7,
					CFrame.new(math.sin(a) * (R - 3.4), -0.9, math.cos(a) * (R - 3.4)),
					rgb(248, 252, 255),
					Enum.Material.Snow
				)
			end
		end
		local sky = k:box("SnowSource", Vector3.new(120, 1, 120), CFrame.new(0, 34, 0), rgb(0, 0, 0))
		sky.Transparency = 1
		local snow = Instance.new("ParticleEmitter")
		snow.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		snow.Rate = 24
		snow.Lifetime = NumberRange.new(5, 7)
		snow.Speed = NumberRange.new(4, 7)
		snow.Size = NumberSequence.new(0.3)
		snow.Color = ColorSequence.new(rgb(255, 255, 255))
		snow.EmissionDirection = Enum.NormalId.Bottom
		snow.Parent = sky
		life(function(_t: number, _dt: number)
			snow.Enabled = not Motion.reduced()
		end)
	end
end

return PadParts
