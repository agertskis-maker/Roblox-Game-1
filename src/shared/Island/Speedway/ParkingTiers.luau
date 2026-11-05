--!strict
-- The parking area's visible tiers (Lane 3, presentation only; Round 6, V-02). The Paddock itself upgrades as spots are
-- bought, so buying spots feels like building something, not only one more set of lines:
--   tier 1 (2 to 4 spots)    a painted gravel lot with traffic cones at the aisle ends
--   tier 2 (5 to 8)          asphalt, bright white bay lines, a dashed yellow aisle line and a number in every bay
--   tier 3 (9 to 12)         tier 2 under a covered paddock over the back row: a teal canopy on posts, warm light strips
--                            and lamps under it, and a PADDOCK sign on its front edge
--   tier 4 (13 to 15)        the showroom: a glossy pale floor, cyan light strips along both rows, more canopy light and a
--                            glowing STAR CAR podium under bay 1 (the Lineup's first car parks there)
--   Expanded Paddock (pass)  the extension floors get gold trim and a gold EXPANDED PADDOCK plaque
-- Breakpoints are Adam's brief (section V-02); Claude Code kept them (the reference images were not delivered).
-- Everything is anchored decoration: no collision, no query, no touch (the Paddock's own floor stays the walking surface).
-- Every bay position comes from Parking.bay(i, expanded). Part count: tier 4 with the pass is about 60 parts per plot.
--
--   ParkingTiers.tierOf(spots) -> 1..4
--   ParkingTiers.dress(folder, ctx, spots, expanded) -> Folder   (the "Tier" folder, for the reveal to fade in)
--   ParkingTiers.lineColour(tier) -> Color3

local Ctx = require(script.Parent.Ctx)
local Kit = require(script.Parent.Kit)

local ParkingTiers = {}

type Ctx = Ctx.Ctx
type BayLike = { index: number, row: string, x: number, u: number, back: number, mouth: number }

ParkingTiers.Breaks = table.freeze({ 5, 9, 13 }) -- the first spot count of tiers 2, 3 and 4

local R0 = 247.187
local ROW_A = { R0 + 16, R0 + 32 }
local ROW_B = { R0 + 42, R0 + 58 }
local X_EDGE = 36 -- the Paddock's half width without the pass
local AISLE_U = (ROW_A[2] + ROW_B[1]) / 2
local TIER_TOP = 0.235 -- over the Paddock floor (0.2), under the bay lines (0.27)

local GRAVEL = Color3.fromRGB(214, 196, 160)
local ASPHALT = Color3.fromRGB(58, 61, 68)
local GLOSS = Color3.fromRGB(234, 237, 242)
local WHITE = Color3.fromRGB(250, 250, 244)
local YELLOW = Color3.fromRGB(255, 205, 52)
local CONE = Color3.fromRGB(255, 120, 40)
local TEAL = Color3.fromRGB(34, 138, 146)
local WARM = Color3.fromRGB(255, 226, 170)
local CYAN = Color3.fromRGB(90, 220, 255)
local GOLD = Color3.fromRGB(255, 196, 46)
local INK = Color3.fromRGB(28, 32, 52)

function ParkingTiers.tierOf(spots: number): number
	local tier = 1
	for i, at in ParkingTiers.Breaks do
		if spots >= at then
			tier = i + 1
		end
	end
	return tier
end

-- Tier 1 keeps the cream lines of the gravel lot; asphalt and the showroom get bright white ones.
function ParkingTiers.lineColour(tier: number): Color3
	return if tier >= 2 then WHITE else Color3.fromRGB(244, 236, 214)
end

local function deco(options: { [string]: any }): any
	options.castShadow = if options.castShadow == nil then false else options.castShadow
	return options
end

-- A flat floor panel over the Paddock (x0..x1, u0..u1).
local function floor(
	parent: Instance,
	ctx: Ctx,
	x0: number,
	x1: number,
	u0: number,
	u1: number,
	colour: Color3,
	material: Enum.Material,
	name: string
): Part?
	local p = Kit.slab(
		parent,
		Ctx.at(ctx, x0, (u0 + u1) / 2, TIER_TOP),
		Ctx.at(ctx, x1, (u0 + u1) / 2, TIER_TOP),
		Vector3.yAxis,
		u1 - u0,
		0.03,
		deco({ name = name, color = colour, material = material }),
		0
	)
	return p
end

-- A thin strip along x at plan depth u (a line, a light strip or a trim).
local function strip(
	parent: Instance,
	ctx: Ctx,
	x0: number,
	x1: number,
	u: number,
	y: number,
	width: number,
	colour: Color3,
	material: Enum.Material,
	name: string
): Part?
	return Kit.slab(
		parent,
		Ctx.at(ctx, x0, u, y),
		Ctx.at(ctx, x1, u, y),
		Vector3.yAxis,
		width,
		0.06,
		deco({ name = name, color = colour, material = material }),
		0
	)
end

local function label(part: BasePart, face: Enum.NormalId, text: string, colour: Color3, pixels: number)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Label"
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = pixels
	gui.LightInfluence = 0
	gui.MaxDistance = 220
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Size = UDim2.fromScale(1, 1)
	t.Font = Enum.Font.FredokaOne
	t.TextScaled = true
	t.TextColor3 = colour
	t.Text = text
	local stroke = Instance.new("UIStroke")
	stroke.Color = INK
	stroke.Thickness = 3
	stroke.Parent = t
	t.Parent = gui
	gui.Parent = part
end

local function cone(parent: Instance, ctx: Ctx, x: number, u: number)
	local base = Ctx.at(ctx, x, u, 0.2)
	Kit.part(
		parent,
		Vector3.new(1.4, 0.15, 1.4),
		CFrame.new(base + Vector3.new(0, 0.08, 0)),
		deco({ name = "ConeBase", color = CONE })
	)
	local body = Kit.part(
		parent,
		Vector3.new(1.6, 0.9, 0.9),
		CFrame.new(base + Vector3.new(0, 0.95, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		deco({ name = "Cone", color = CONE, shape = Enum.PartType.Cylinder, castShadow = true })
	)
	body:SetAttribute("Cone", true)
	Kit.part(
		parent,
		Vector3.new(0.3, 0.95, 0.95),
		CFrame.new(base + Vector3.new(0, 1.1, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		deco({ name = "ConeBand", color = WHITE, shape = Enum.PartType.Cylinder })
	)
end

-- The bay's number, painted on the ground near its mouth.
local function bayNumber(parent: Instance, ctx: Ctx, bay: BayLike, colour: Color3)
	local inward = if bay.row == "A" then -1 else 1
	local u = bay.mouth + inward * 2.2
	local p = Kit.part(
		parent,
		Vector3.new(3.2, 0.02, 2.2),
		Ctx.face(ctx, bay.x, u, Vector2.new(0, -inward), 0.285),
		deco({ name = "BayNumber", transparency = 1 })
	)
	label(p, Enum.NormalId.Top, tostring(bay.index), colour, 24)
end

local function lamp(parent: Instance, ctx: Ctx, x: number, u: number, y: number, colour: Color3, range: number)
	local holder = Kit.part(
		parent,
		Vector3.new(0.6, 0.2, 0.6),
		CFrame.new(Ctx.at(ctx, x, u, y)),
		deco({ name = "Lamp", color = colour, material = Enum.Material.Neon })
	)
	local light = Instance.new("PointLight")
	light.Color = colour
	light.Range = range
	light.Brightness = 1.2
	light.Shadows = false
	light.Parent = holder
end

-- The covered paddock over row B: posts, roof, light strips, lamps and the sign (tiers 3 and 4).
local function canopy(parent: Instance, ctx: Ctx, showroom: boolean)
	local roofY = 9.6
	for _, x in { -X_EDGE, -12, 12, X_EDGE } do
		for _, u in { ROW_B[1] - 0.6, ROW_B[2] + 0.4 } do
			local foot = Ctx.at(ctx, x, u, 0.2)
			Kit.part(
				parent,
				Vector3.new(0.7, roofY, 0.7),
				CFrame.new(foot + Vector3.new(0, roofY / 2, 0)),
				deco({
					name = "CanopyPost",
					color = Color3.fromRGB(230, 232, 236),
					material = Enum.Material.Metal,
					castShadow = true,
				})
			)
		end
	end
	local roof = Kit.slab(
		parent,
		Ctx.at(ctx, -X_EDGE - 1.2, (ROW_B[1] + ROW_B[2]) / 2, roofY + 0.5),
		Ctx.at(ctx, X_EDGE + 1.2, (ROW_B[1] + ROW_B[2]) / 2, roofY + 0.5),
		Vector3.yAxis,
		ROW_B[2] - ROW_B[1] + 3,
		0.5,
		deco({ name = "CanopyRoof", color = TEAL, material = Enum.Material.Metal, castShadow = true }),
		0
	)
	-- the front fascia, with the sign facing the aisle
	local front = Kit.slab(
		parent,
		Ctx.at(ctx, -X_EDGE - 1.2, ROW_B[1] - 1.5, roofY + 0.9),
		Ctx.at(ctx, X_EDGE + 1.2, ROW_B[1] - 1.5, roofY + 0.9),
		Vector3.yAxis,
		0.3,
		1.6,
		deco({ name = "CanopyFascia", color = INK, material = Enum.Material.SmoothPlastic }),
		0
	)
	if front then
		local sign = Kit.part(
			parent,
			Vector3.new(26, 1.3, 0.05),
			Ctx.face(ctx, 0, ROW_B[1] - 1.68, Vector2.new(0, -1), roofY + 0.1),
			deco({ name = "PaddockSign", transparency = 1 })
		)
		label(
			sign,
			Enum.NormalId.Front,
			if showroom then "THE SHOWROOM" else "THE PADDOCK",
			if showroom then GOLD else WARM,
			20
		)
	end
	for _, u in { ROW_B[1] + 4, ROW_B[2] - 4 } do
		strip(
			parent,
			ctx,
			-X_EDGE,
			X_EDGE,
			u,
			roofY - 0.05,
			0.35,
			if showroom then CYAN else WARM,
			Enum.Material.Neon,
			"CanopyLightStrip"
		)
	end
	for _, x in (if showroom then { -27, -9, 9, 27 } else { -18, 18 }) :: { number } do
		lamp(parent, ctx, x, (ROW_B[1] + ROW_B[2]) / 2, roofY - 0.3, WARM, 18)
	end
	if roof then
		roof:SetAttribute("Canopy", true)
	end
end

-- Dresses the plot's Paddock for `spots` owned bays. Returns the Tier folder (inside `folder`).
function ParkingTiers.dress(
	folder: Instance,
	ctx: Ctx,
	spots: number,
	expanded: boolean,
	bayOf: (number) -> BayLike
): Folder
	local tierFolder = Instance.new("Folder")
	tierFolder.Name = "Tier"
	local tier = ParkingTiers.tierOf(spots)
	tierFolder:SetAttribute("Tier", tier)
	local u0, u1 = ROW_A[1] + 0.05, ROW_B[2] - 0.05
	if tier == 1 then
		floor(tierFolder, ctx, -X_EDGE, X_EDGE, u0, u1, GRAVEL, Enum.Material.Pebble, "GravelLot")
		for _, x in { -X_EDGE + 2, X_EDGE - 2 } do
			cone(tierFolder, ctx, x, AISLE_U - 1.2)
			cone(tierFolder, ctx, x, AISLE_U + 1.2)
		end
	else
		local showroom = tier >= 4
		floor(
			tierFolder,
			ctx,
			-X_EDGE,
			X_EDGE,
			u0,
			u1,
			if showroom then GLOSS else ASPHALT,
			if showroom then Enum.Material.SmoothPlastic else Enum.Material.Asphalt,
			if showroom then "ShowroomFloor" else "Asphalt"
		)
		-- the dashed yellow aisle line
		for x = -X_EDGE + 3, X_EDGE - 3, 6 do
			strip(tierFolder, ctx, x, x + 3, AISLE_U, 0.28, 0.3, YELLOW, Enum.Material.SmoothPlastic, "AisleDash")
		end
		for i = 1, spots do
			bayNumber(tierFolder, ctx, bayOf(i), if showroom then INK else WHITE)
		end
		if tier >= 3 then
			canopy(tierFolder, ctx, showroom)
		end
		if showroom then
			for _, u in { ROW_A[1] + 0.4, ROW_B[2] - 0.4 } do
				strip(tierFolder, ctx, -X_EDGE, X_EDGE, u, 0.3, 0.4, CYAN, Enum.Material.Neon, "FloorLightStrip")
			end
			-- the STAR CAR podium under bay 1 (the Lineup's first car)
			local first = bayOf(1)
			local centre = Ctx.at(ctx, first.x, (first.back + first.mouth) / 2, 0.2)
			local disc = Kit.part(
				tierFolder,
				Vector3.new(0.14, 8.6, 8.6),
				CFrame.new(centre + Vector3.new(0, 0.1, 0)) * CFrame.Angles(0, 0, math.rad(90)),
				deco({ name = "StarPodium", color = Color3.fromRGB(250, 250, 255), shape = Enum.PartType.Cylinder })
			)
			disc:SetAttribute("StarPodium", true)
			Kit.part(
				tierFolder,
				Vector3.new(0.1, 9.2, 9.2),
				CFrame.new(centre + Vector3.new(0, 0.06, 0)) * CFrame.Angles(0, 0, math.rad(90)),
				deco({ name = "StarRing", color = GOLD, material = Enum.Material.Neon, shape = Enum.PartType.Cylinder })
			)
		end
	end
	if expanded then
		for _, span in { { 36, 49.5 }, { -49.5, -36 } } do
			for _, u in { ROW_A[1] + 0.15, ROW_A[2] - 0.15 } do
				strip(tierFolder, ctx, span[1], span[2], u, 0.3, 0.3, GOLD, Enum.Material.Foil, "GoldTrim")
			end
		end
		local plaque = Kit.part(
			tierFolder,
			Vector3.new(7, 1.4, 0.05),
			Ctx.face(ctx, 42.75, ROW_A[2] + 0.4, Vector2.new(0, 1), 1.2),
			deco({ name = "ExpandedPlaque", color = GOLD, material = Enum.Material.Foil })
		)
		label(plaque, Enum.NormalId.Front, "EXPANDED PADDOCK", INK, 18)
	end
	tierFolder.Parent = folder
	return tierFolder
end

return ParkingTiers
