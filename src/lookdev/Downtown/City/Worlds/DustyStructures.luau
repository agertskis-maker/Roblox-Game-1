--!strict
-- DUSTY HIGHWAY structures (Lane 3, big round M6): the supporting buildings that make each district a
-- place. Part-built, original and shared across districts by a few construction rules, so a drive reads
-- as real settlements without new mesh uploads. Each recipe returns a Model centred on its footprint
-- with its front (local -Z) toward the road, at ground y = 0. Anchored, no collision, no query.
--
--   Structures.build(id)  -> Model
--   Structures.Sites      -> where each one stands, as district, fraction along it, side and lateral

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SignKit = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Island"):WaitForChild("SignKit"))

local Structures = {}

local rgb = Color3.fromRGB

local SAND = rgb(232, 196, 142)
local CREAM = rgb(246, 234, 204)
local TURQ = rgb(54, 176, 170)
local CORAL = rgb(226, 104, 92)
local CHARCOAL = rgb(58, 54, 58)
local WOOD = rgb(140, 92, 60)
local WOOD_DARK = rgb(92, 60, 42)
local BARN = rgb(170, 52, 44)
local TIN = rgb(150, 150, 150)
local ROCK = rgb(190, 120, 82)
local ADOBE = rgb(214, 150, 108)
local GLASS = rgb(76, 136, 158)
local PALE = rgb(226, 214, 190)
local OCHRE = rgb(196, 146, 72)
local BLUE = rgb(110, 150, 176)
local LIME = rgb(160, 190, 90)

local function box(m: Model, name: string, size: Vector3, at: Vector3, colour: Color3, material: Enum.Material?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = size.Y > 3
	p.Size = size
	p.CFrame = CFrame.new(at)
	p.Color = colour
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = m
	return p
end

local function cylinder(m: Model, name: string, radius: number, tall: number, at: Vector3, colour: Color3): Part
	local p = box(m, name, Vector3.new(tall, radius * 2, radius * 2), at, colour)
	p.Shape = Enum.PartType.Cylinder
	p.CFrame = CFrame.new(at) * CFrame.Angles(0, 0, math.pi / 2)
	return p
end

local function wedge(m: Model, name: string, size: Vector3, cf: CFrame, colour: Color3): WedgePart
	local p = Instance.new("WedgePart")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = true
	p.Size = size
	p.CFrame = cf
	p.Color = colour
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = m
	return p
end

-- A pitched roof over a w x d box, ridge along X, standing on height y.
local function gable(m: Model, w: number, d: number, y: number, rise: number, colour: Color3, cx: number?)
	local x = cx or 0
	for _, s in { 1, -1 } do
		wedge(
			m,
			"Roof",
			Vector3.new(w + 1, rise, d / 2 + 0.6),
			CFrame.new(x, y + rise / 2, s * (d / 4 + 0.3)) * CFrame.Angles(0, if s > 0 then 0 else math.pi, 0),
			colour
		)
	end
end

-- A row of dark windows standing just proud of the front wall at z = -d/2.
local function windows(m: Model, w: number, y: number, frontZ: number, count: number, colour: Color3, tall: number?)
	local h = tall or 2.2
	for k = 1, count do
		box(m, "Window", Vector3.new(2, h, 0.14), Vector3.new(-w / 2 + k * w / (count + 1), y, frontZ - 0.08), colour)
	end
end

local function door(m: Model, x: number, frontZ: number, colour: Color3)
	box(m, "Door", Vector3.new(2.4, 4.6, 0.14), Vector3.new(x, 2.4, frontZ - 0.08), colour)
end

local function shell(m: Model, w: number, d: number, h: number, colour: Color3): number
	box(m, "Walls", Vector3.new(w, h, d), Vector3.new(0, h / 2, 0), colour)
	return -d / 2
end

-- A post-and-roof shade: four posts under a slab.
local function ramada(m: Model, w: number, d: number, h: number, posts: Color3, roof: Color3)
	for _, sx in { 1, -1 } do
		for _, sz in { 1, -1 } do
			box(m, "Post", Vector3.new(0.6, h, 0.6), Vector3.new(sx * (w / 2 - 0.6), h / 2, sz * (d / 2 - 0.6)), posts)
		end
	end
	box(m, "Shade", Vector3.new(w + 1, 0.5, d + 1), Vector3.new(0, h + 0.25, 0), roof)
end

local function tower(m: Model, spread: number, h: number, colour: Color3)
	for _, sx in { 1, -1 } do
		for _, sz in { 1, -1 } do
			box(m, "Leg", Vector3.new(0.7, h, 0.7), Vector3.new(sx * spread, h / 2, sz * spread), colour)
		end
	end
	for _, y in { h * 0.35, h * 0.7 } do
		box(m, "Brace", Vector3.new(spread * 2 + 0.7, 0.4, 0.4), Vector3.new(0, y, -spread), colour)
		box(m, "Brace", Vector3.new(spread * 2 + 0.7, 0.4, 0.4), Vector3.new(0, y, spread), colour)
	end
end

local function faceRoad(at: Vector3): CFrame
	return CFrame.new(at) * CFrame.Angles(0, math.pi, 0)
end

local RECIPES: { [string]: (Model) -> () } = {}

-- Cactus Flats: red barn, ranch and trading post
function RECIPES.BigBarn(m)
	local f = shell(m, 34, 24, 15, BARN)
	gable(m, 34, 24, 15, 8, CHARCOAL)
	box(m, "BarnDoor", Vector3.new(11, 11, 0.2), Vector3.new(0, 5.6, f - 0.1), CREAM)
	box(m, "BarnDoorInset", Vector3.new(9.6, 9.6, 0.1), Vector3.new(0, 5.6, f - 0.26), BARN)
	box(m, "HayDoor", Vector3.new(5, 4, 0.14), Vector3.new(0, 15.5, f - 0.08), CREAM)
	box(m, "Lean", Vector3.new(14, 10, 18), Vector3.new(24, 5, 2), BARN:Lerp(CHARCOAL, 0.15))
	box(m, "LeanRoof", Vector3.new(15, 0.6, 19), Vector3.new(24, 10.3, 2), CHARCOAL)
end

function RECIPES.TradingPost(m)
	local f = shell(m, 26, 16, 10, WOOD)
	box(m, "FalseFront", Vector3.new(26, 5, 0.8), Vector3.new(0, 12.5, f + 0.2), WOOD_DARK)
	ramada(m, 26, 6, 8.5, WOOD_DARK, WOOD)
	m:FindFirstChild("Shade"):PivotTo(CFrame.new(0, 8.75, f - 3.2))
	for _, c in m:GetChildren() do
		if c.Name == "Post" then
			(c :: BasePart).Position =
				Vector3.new((c :: BasePart).Position.X, 4.25, f - 3.2 + math.sign((c :: BasePart).Position.Z) * 2.4)
		end
	end
	door(m, 0, f, WOOD_DARK)
	windows(m, 26, 3.6, f, 2, GLASS)
	SignKit.sign(
		m,
		faceRoad(Vector3.new(0, 12.5, f - 0.3)),
		{ style = "Trading", text = "TRADING POST", width = 20, height = 3.6 }
	)
end

function RECIPES.HayShelter(m)
	ramada(m, 20, 12, 8, WOOD_DARK, TIN)
	for x = -6, 6, 4 do
		box(m, "Hay", Vector3.new(3.6, 2.6, 8), Vector3.new(x, 1.3, 0), rgb(226, 190, 96))
	end
	box(m, "Hay", Vector3.new(3.6, 2.6, 8), Vector3.new(-2, 3.9, 0), rgb(232, 200, 110))
end

function RECIPES.CorralGate(m)
	for _, x in { -12, 12 } do
		box(m, "GatePost", Vector3.new(1.2, 11, 1.2), Vector3.new(x, 5.5, 0), WOOD_DARK)
	end
	box(m, "GateBeam", Vector3.new(26, 1.2, 1.2), Vector3.new(0, 10.6, 0), WOOD_DARK)
	for _, y in { 1.6, 3.2 } do
		for _, s in { 1, -1 } do
			box(m, "Rail", Vector3.new(14, 0.5, 0.4), Vector3.new(s * 19, y, 0), WOOD)
		end
	end
	for _, s in { 1, -1 } do
		box(m, "Post", Vector3.new(0.7, 4, 0.7), Vector3.new(s * 26, 2, 0), WOOD_DARK)
	end
end

function RECIPES.TroughShelter(m)
	ramada(m, 14, 8, 6, WOOD, TIN)
	box(m, "Trough", Vector3.new(10, 1.4, 2.6), Vector3.new(0, 0.7, 0), rgb(120, 124, 130))
	box(m, "TroughWater", Vector3.new(9, 0.2, 1.8), Vector3.new(0, 1.42, 0), rgb(84, 170, 190))
end

function RECIPES.TankStand(m)
	tower(m, 3.6, 16, WOOD_DARK)
	cylinder(m, "Tank", 5.4, 7, Vector3.new(0, 19.5, 0), WOOD)
	box(m, "TankBand", Vector3.new(11.2, 0.4, 11.2), Vector3.new(0, 17.2, 0), CHARCOAL)
	box(m, "TankCap", Vector3.new(8, 0.8, 8), Vector3.new(0, 23.4, 0), CHARCOAL)
end

function RECIPES.RanchShedA(m)
	local f = shell(m, 16, 12, 8, PALE)
	gable(m, 16, 12, 8, 4, WOOD_DARK)
	door(m, -3, f, WOOD_DARK)
	windows(m, 16, 4, f, 1, GLASS)
end

function RECIPES.RanchShedB(m)
	local f = shell(m, 20, 12, 7, ADOBE)
	box(m, "FlatRoof", Vector3.new(21, 0.6, 13), Vector3.new(0, 7.3, 0), CHARCOAL)
	door(m, 8, f, TURQ)
	windows(m, 20, 4, f, 2, GLASS)
end

function RECIPES.ProduceKiosk(m)
	box(m, "Stall", Vector3.new(12, 3, 6), Vector3.new(0, 1.5, 0), WOOD)
	ramada(m, 12, 6, 7, WOOD_DARK, CORAL)
	box(m, "Crate", Vector3.new(4.6, 1, 2.2), Vector3.new(-2.4, 3.5, 0), rgb(226, 120, 60))
	box(m, "Crate", Vector3.new(4.6, 1, 2.2), Vector3.new(2.4, 3.5, 0), LIME)
end

-- Diner Strip: motel, fuel, a general store, the drive-in
function RECIPES.MotelWing(m)
	local f = shell(m, 46, 14, 8, CREAM)
	box(m, "Upper", Vector3.new(46, 7, 14), Vector3.new(0, 11.5, 0), TURQ:Lerp(CREAM, 0.55))
	box(m, "Balcony", Vector3.new(46, 0.5, 3), Vector3.new(0, 8.2, f - 1.5), CORAL)
	box(m, "BalconyRail", Vector3.new(46, 1.4, 0.3), Vector3.new(0, 9.4, f - 2.8), TURQ)
	box(m, "RoofSlab", Vector3.new(48, 0.7, 16), Vector3.new(0, 15.3, 0), CHARCOAL)
	for k = 0, 5 do
		local x = -19 + k * 7.6
		door(m, x, f, TURQ)
		box(m, "Door", Vector3.new(2.4, 4.2, 0.14), Vector3.new(x, 10.6, f - 0.08), CORAL)
	end
end

function RECIPES.MotelOffice(m)
	local f = shell(m, 16, 12, 8, CREAM)
	box(m, "Canopy", Vector3.new(18, 0.6, 16), Vector3.new(0, 8.4, -2), CORAL)
	door(m, 0, f, GLASS)
	windows(m, 16, 4, f, 2, GLASS)
	box(m, "SignPole", Vector3.new(1, 24, 1), Vector3.new(-12, 12, f - 2), CHARCOAL)
	SignKit.sign(
		m,
		faceRoad(Vector3.new(-12, 20, f - 2.6)),
		{ style = "Motel", text = "MOTEL", width = 11, height = 4.6, icon = "bed" }
	)
end

function RECIPES.PoolEnclosure(m)
	box(m, "PoolDeck", Vector3.new(26, 0.4, 16), Vector3.new(0, 0.2, 0), PALE)
	box(m, "Pool", Vector3.new(20, 0.2, 10), Vector3.new(0, 0.5, 0), rgb(70, 196, 214))
	for _, s in { 1, -1 } do
		box(m, "Fence", Vector3.new(26, 3, 0.3), Vector3.new(0, 1.9, s * 8), TURQ:Lerp(CREAM, 0.3))
		box(m, "Fence", Vector3.new(0.3, 3, 16), Vector3.new(s * 13, 1.9, 0), TURQ:Lerp(CREAM, 0.3))
	end
	box(m, "Umbrella", Vector3.new(0.4, 6, 0.4), Vector3.new(-9, 3.4, 0), CREAM)
	cylinder(m, "UmbrellaTop", 3.4, 0.4, Vector3.new(-9, 6.6, 0), CORAL)
end

function RECIPES.FuelCanopy(m)
	ramada(m, 30, 14, 10, CREAM, CREAM)
	box(m, "CanopyBand", Vector3.new(31.6, 1.4, 15.6), Vector3.new(0, 10.9, 0), TURQ)
	for _, x in { -7, 7 } do
		box(m, "PumpIsland", Vector3.new(6, 0.5, 3), Vector3.new(x, 0.25, 0), PALE)
		box(m, "Pump", Vector3.new(1.6, 3.6, 1.2), Vector3.new(x, 2.3, 0), CORAL)
	end
	SignKit.sign(m, faceRoad(Vector3.new(0, 10.9, -8.1)), { style = "Fuel", icon = "drop", width = 5, height = 1.5 })
end

function RECIPES.GeneralStore(m)
	local f = shell(m, 22, 14, 9, ADOBE:Lerp(CREAM, 0.4))
	box(m, "FalseFront", Vector3.new(22, 4, 0.8), Vector3.new(0, 11, f + 0.2), CORAL)
	box(m, "Awning", Vector3.new(22, 0.4, 3.4), Vector3.new(0, 7, f - 1.7), TURQ)
	door(m, 0, f, GLASS)
	windows(m, 22, 4, f, 2, GLASS, 3)
end

function RECIPES.RepairShed(m)
	local f = shell(m, 20, 14, 10, TIN)
	gable(m, 20, 14, 10, 3, CHARCOAL)
	box(m, "RollDoor", Vector3.new(12, 8, 0.16), Vector3.new(-2, 4, f - 0.09), rgb(96, 100, 110))
	for y = 1.5, 7.5, 2 do
		box(m, "DoorRib", Vector3.new(12, 0.14, 0.1), Vector3.new(-2, y, f - 0.2), CHARCOAL)
	end
	cylinder(m, "Tyre", 1.5, 1, Vector3.new(9, 1.5, f - 2), CHARCOAL)
end

function RECIPES.WaterTower(m)
	tower(m, 5.6, 34, TURQ:Lerp(CHARCOAL, 0.35))
	cylinder(m, "Tank", 9, 10, Vector3.new(0, 39, 0), TURQ)
	box(m, "TankCap", Vector3.new(12, 1.4, 12), Vector3.new(0, 44.7, 0), CREAM)
	box(m, "TankBand", Vector3.new(18.4, 0.7, 18.4), Vector3.new(0, 34.3, 0), CORAL)
end

function RECIPES.DriveInBooth(m)
	local f = shell(m, 8, 8, 7, CREAM)
	box(m, "BoothRoof", Vector3.new(11, 0.6, 11), Vector3.new(0, 7.3, 0), CORAL)
	windows(m, 8, 4, f, 1, GLASS)
	for _, s in { -1, 1 } do
		box(m, "ScreenLeg", Vector3.new(2, 26, 2), Vector3.new(s * 20, 13, 26), CHARCOAL)
	end
	box(m, "Screen", Vector3.new(50, 22, 1), Vector3.new(0, 24, 26), CREAM)
	box(m, "ScreenBack", Vector3.new(52, 24, 0.8), Vector3.new(0, 24, 27), CHARCOAL)
end

-- Red Rock Arches: a kid-friendly old mining settlement
function RECIPES.MineEntrance(m)
	box(m, "Hill", Vector3.new(32, 16, 16), Vector3.new(0, 8, 4), ROCK)
	box(m, "HillTop", Vector3.new(22, 7, 10), Vector3.new(0, 19, 5), ROCK:Lerp(ADOBE, 0.4))
	box(m, "MineDark", Vector3.new(10, 9, 0.2), Vector3.new(0, 4.5, -4.1), rgb(36, 28, 26))
	for _, s in { 1, -1 } do
		box(m, "MinePost", Vector3.new(1.4, 11, 1.4), Vector3.new(s * 6, 5.5, -4.6), WOOD_DARK)
	end
	box(m, "MineLintel", Vector3.new(14.6, 1.6, 1.6), Vector3.new(0, 11.6, -4.6), WOOD_DARK)
	for _, s in { 1, -1 } do
		box(m, "Rail", Vector3.new(0.4, 0.3, 14), Vector3.new(s * 1.8, 0.2, -11), CHARCOAL)
	end
	box(m, "CartBody", Vector3.new(5, 2.6, 4), Vector3.new(0, 2.2, -12), CHARCOAL)
	box(m, "CartLoad", Vector3.new(4, 1, 3), Vector3.new(0, 3.9, -12), rgb(120, 110, 104))
	SignKit.sign(
		m,
		faceRoad(Vector3.new(0, 13.8, -5.4)),
		{ style = "Mine", text = "OLD MINE", width = 10, height = 2.4 }
	)
end

function RECIPES.OreShed(m)
	local f = shell(m, 18, 12, 9, WOOD)
	gable(m, 18, 12, 9, 3.6, TIN)
	box(m, "Chute", Vector3.new(3, 1, 8), Vector3.new(6, 6, f - 3.6), WOOD_DARK).Orientation = Vector3.new(24, 0, 0)
	door(m, -4, f, WOOD_DARK)
end

function RECIPES.CartPlatform(m)
	ramada(m, 22, 10, 6, WOOD_DARK, WOOD)
	box(m, "Deck", Vector3.new(22, 0.6, 10), Vector3.new(0, 3, 0), WOOD)
	box(m, "CartBody", Vector3.new(5, 2.6, 3.4), Vector3.new(-5, 4.6, 0), CHARCOAL)
	box(m, "CartLoad", Vector3.new(4, 1, 2.6), Vector3.new(-5, 6.2, 0), rgb(120, 110, 104))
end

function RECIPES.ElevatedTank(m)
	tower(m, 3, 20, WOOD_DARK)
	box(m, "Tank", Vector3.new(9, 7, 9), Vector3.new(0, 23.5, 0), WOOD)
	gable(m, 9, 9, 27, 2.4, TIN)
end

function RECIPES.TrestleRun(m)
	for k = 0, 5 do
		local x = -30 + k * 12
		for _, s in { 1, -1 } do
			box(m, "Bent", Vector3.new(0.8, 18, 0.8), Vector3.new(x, 9, s * 2.4), WOOD_DARK)
		end
		box(m, "Cap", Vector3.new(0.9, 0.7, 6.4), Vector3.new(x, 18, 0), WOOD_DARK)
	end
	box(m, "Deck", Vector3.new(72, 0.7, 6), Vector3.new(0, 18.6, 0), WOOD)
	for _, s in { 1, -1 } do
		box(m, "Rail", Vector3.new(72, 0.3, 0.4), Vector3.new(0, 19.1, s * 1.6), CHARCOAL)
	end
end

function RECIPES.SurveyCabin(m)
	local f = shell(m, 14, 10, 7, WOOD)
	gable(m, 14, 10, 7, 3.4, WOOD_DARK)
	door(m, -3, f, WOOD_DARK)
	windows(m, 14, 4, f, 1, GLASS)
end

function RECIPES.StoneWorkshop(m)
	local f = shell(m, 20, 12, 8, rgb(170, 140, 116))
	box(m, "RoofSlab", Vector3.new(21, 0.6, 13), Vector3.new(0, 8.3, 0), WOOD_DARK)
	box(m, "Chimney", Vector3.new(2.4, 7, 2.4), Vector3.new(7, 11.6, 3), rgb(150, 122, 100))
	door(m, 0, f, WOOD_DARK)
	windows(m, 20, 4, f, 2, GLASS)
end

function RECIPES.LookoutShelter(m)
	tower(m, 3.4, 10, WOOD_DARK)
	box(m, "Deck", Vector3.new(10, 0.5, 10), Vector3.new(0, 10.2, 0), WOOD)
	ramada(m, 9, 9, 5, WOOD_DARK, TIN)
	for _, c in m:GetChildren() do
		if c.Name == "Shade" then
			(c :: BasePart).Position = Vector3.new(0, 15.7, 0)
		end
	end
end

-- Canyon Bridge: everything stands on the safe banks, away from the bridge view
function RECIPES.OverlookA(m)
	box(m, "Deck", Vector3.new(18, 0.6, 12), Vector3.new(0, 0.3, 0), PALE)
	ramada(m, 12, 8, 7, WOOD_DARK, ROCK)
	box(m, "Rail", Vector3.new(17, 2.4, 0.5), Vector3.new(0, 1.7, 5.5), rgb(170, 140, 116))
end

function RECIPES.OverlookB(m)
	box(m, "Deck", Vector3.new(14, 0.6, 14), Vector3.new(0, 0.3, 0), PALE)
	cylinder(m, "Roof", 8, 0.5, Vector3.new(0, 7.6, 0), TURQ)
	box(m, "Mast", Vector3.new(0.7, 7.4, 0.7), Vector3.new(0, 3.7, 0), WOOD_DARK)
end

function RECIPES.MaintHut(m)
	local f = shell(m, 12, 10, 7, OCHRE)
	box(m, "RoofSlab", Vector3.new(13, 0.5, 11), Vector3.new(0, 7.3, 0), CHARCOAL)
	door(m, 0, f, CHARCOAL)
end

function RECIPES.RidgePlatform(m)
	tower(m, 5, 16, rgb(120, 110, 104))
	box(m, "Deck", Vector3.new(16, 0.7, 16), Vector3.new(0, 16.3, 0), CREAM)
	box(m, "Rail", Vector3.new(16, 2, 0.4), Vector3.new(0, 17.7, -8), CHARCOAL)
end

function RECIPES.ViaductRemnant(m)
	for k = 0, 2 do
		local x = -24 + k * 24
		box(m, "Pier", Vector3.new(6, 26, 8), Vector3.new(x, 13, 0), rgb(180, 150, 124))
	end
	box(m, "Span", Vector3.new(58, 4, 8), Vector3.new(0, 28, 0), rgb(196, 166, 138))
end

function RECIPES.StairSilhouette(m)
	for k = 0, 7 do
		box(m, "Step", Vector3.new(6, 0.8, 3), Vector3.new(0, 1 + k * 2, k * 2.6), WOOD_DARK)
		box(m, "StairPost", Vector3.new(0.5, 3, 0.5), Vector3.new(3, 2 + k * 2, k * 2.6), WOOD_DARK)
	end
end

function RECIPES.PumpHouse(m)
	local f = shell(m, 10, 8, 7, PALE)
	gable(m, 10, 8, 7, 3, ROCK)
	door(m, 0, f, TURQ)
	cylinder(m, "Pipe", 0.8, 14, Vector3.new(0, 1, -8), CHARCOAL).CFrame = CFrame.new(0, 1, -11)
		* CFrame.Angles(0, math.pi / 2, 0)
end

function RECIPES.ServiceDepot(m)
	local f = shell(m, 28, 14, 9, CREAM)
	box(m, "RoofSlab", Vector3.new(29, 0.6, 15), Vector3.new(0, 9.3, 0), ROCK)
	for _, x in { -7, 7 } do
		box(m, "RollDoor", Vector3.new(9, 7, 0.16), Vector3.new(x, 3.5, f - 0.09), BLUE)
	end
end

-- Mirage Dunes: a visitor stop and a small research outpost
function RECIPES.VisitorCenter(m)
	local f = shell(m, 30, 16, 9, CREAM)
	box(m, "Canopy", Vector3.new(34, 0.7, 24), Vector3.new(0, 9.5, -3), BLUE)
	box(m, "GlassFront", Vector3.new(20, 6, 0.16), Vector3.new(0, 4, f - 0.09), GLASS)
	for _, x in { -14, 14 } do
		box(m, "CanopyPost", Vector3.new(1, 9, 1), Vector3.new(x, 4.6, f - 6), CREAM)
	end
	SignKit.sign(
		m,
		faceRoad(Vector3.new(0, 11.8, f - 0.6)),
		{ style = "Trail", text = "VISITORS", width = 16, height = 3.2 }
	)
end

function RECIPES.ShadePavilion(m)
	ramada(m, 22, 14, 8, WOOD, SAND)
	for _, x in { -5, 5 } do
		box(m, "Table", Vector3.new(5, 0.4, 2.6), Vector3.new(x, 2.4, 0), WOOD_DARK)
		box(m, "TableLeg", Vector3.new(0.5, 2.2, 0.5), Vector3.new(x, 1.1, 0), WOOD_DARK)
	end
end

function RECIPES.RadioDish(m)
	local f = shell(m, 12, 10, 6, PALE)
	door(m, 0, f, BLUE)
	box(m, "Mast", Vector3.new(1.6, 16, 1.6), Vector3.new(0, 14, 0), CHARCOAL)
	local dish = cylinder(m, "Dish", 8, 1.2, Vector3.new(0, 22, 0), CREAM)
	dish.CFrame = CFrame.new(0, 22, 0) * CFrame.Angles(math.rad(-60), 0, math.pi / 2)
	dish:SetAttribute("SpinAxis", "Y")
	box(m, "Feed", Vector3.new(0.5, 6, 0.5), Vector3.new(0, 24, -1), CHARCOAL)
end

function RECIPES.ObservatoryDome(m)
	cylinder(m, "Drum", 13, 14, Vector3.new(0, 7, 0), CREAM)
	local dome = box(m, "Dome", Vector3.new(26, 26, 26), Vector3.new(0, 14, 0), rgb(236, 240, 244))
	dome.Shape = Enum.PartType.Ball
	box(m, "Slit", Vector3.new(4, 12, 0.5), Vector3.new(0, 21, -11.6), BLUE).Orientation = Vector3.new(-28, 0, 0)
end

function RECIPES.SolarCanopy(m)
	for k = 0, 2 do
		local x = -14 + k * 14
		box(m, "Leg", Vector3.new(0.5, 4, 0.5), Vector3.new(x, 2, 0), TIN)
		box(m, "Panel", Vector3.new(12, 0.4, 7), Vector3.new(x, 4.6, 0), rgb(40, 64, 110)).Orientation =
			Vector3.new(-18, 0, 0)
	end
end

function RECIPES.RestShelter(m)
	ramada(m, 12, 8, 6.5, CREAM, BLUE)
	box(m, "Bench", Vector3.new(8, 0.5, 1.4), Vector3.new(0, 1.6, 2), WOOD)
end

function RECIPES.TurbineHut(m)
	local f = shell(m, 10, 8, 6, PALE)
	door(m, 0, f, BLUE)
	box(m, "TurbineMast", Vector3.new(2, 46, 2), Vector3.new(16, 23, 4), CREAM)
	box(m, "Nacelle", Vector3.new(3, 3, 6), Vector3.new(16, 46, 3), CREAM)
	for k = 0, 2 do
		local blade = box(m, "Blade", Vector3.new(1.2, 18, 0.3), Vector3.new(16, 46, 0), CREAM)
		blade.CFrame = CFrame.new(16, 46, 0) * CFrame.Angles(0, 0, k * math.pi * 2 / 3) * CFrame.new(0, 9, 0)
	end
end

function RECIPES.ResearchShed(m)
	local f = shell(m, 14, 10, 7, CREAM)
	box(m, "RoofSlab", Vector3.new(15, 0.5, 11), Vector3.new(0, 7.3, 0), LIME)
	windows(m, 14, 4, f, 2, GLASS)
end

function Structures.build(id: string): Model
	local recipe = RECIPES[id]
	assert(recipe, "no structure " .. id)
	local m = Instance.new("Model")
	m.Name = "DH_Structure_" .. id
	m:SetAttribute("Structure", id)
	recipe(m)
	m.WorldPivot = CFrame.identity
	return m
end

export type Site = { id: string, district: string, t: number, side: number, lateral: number, size: Vector3 }

local function site(id: string, district: string, t: number, side: number, lateral: number, w: number, h: number): Site
	return { id = id, district = district, t = t, side = side, lateral = lateral, size = Vector3.new(w, h, w) }
end

-- Where they stand. Sides are staggered, so something new is on one side or the other every couple of
-- seconds at run speed; a landmark stands clear of its neighbours; nothing is nearer the road than the
-- frontage lots. Canyon Bridge's stand on the banks either side of the crossing, never beside it.
Structures.Sites = {
	site("TradingPost", "CactusFlats", 0.1, 1, 72, 26, 17),
	site("CorralGate", "CactusFlats", 0.22, -1, 78, 52, 12),
	site("BigBarn", "CactusFlats", 0.34, 1, 96, 40, 23),
	site("HayShelter", "CactusFlats", 0.46, -1, 70, 21, 9),
	site("TankStand", "CactusFlats", 0.56, 1, 82, 11, 24),
	site("RanchShedA", "CactusFlats", 0.66, -1, 84, 16, 12),
	site("TroughShelter", "CactusFlats", 0.76, 1, 70, 14, 7),
	site("RanchShedB", "CactusFlats", 0.86, -1, 76, 20, 8),
	site("ProduceKiosk", "CactusFlats", 0.95, 1, 68, 12, 8),
	site("MotelWing", "DinerStrip", 0.08, -1, 82, 48, 16),
	site("MotelOffice", "DinerStrip", 0.2, -1, 70, 18, 26),
	site("PoolEnclosure", "DinerStrip", 0.31, -1, 78, 26, 7),
	site("FuelCanopy", "DinerStrip", 0.42, 1, 70, 31, 12),
	site("GeneralStore", "DinerStrip", 0.56, -1, 74, 22, 13),
	site("RepairShed", "DinerStrip", 0.66, 1, 76, 20, 13),
	site("WaterTower", "DinerStrip", 0.76, -1, 96, 18, 46),
	site("DriveInBooth", "DinerStrip", 0.9, 1, 86, 52, 36),
	site("OreShed", "RedRockArches", 0.1, -1, 72, 18, 13),
	site("CartPlatform", "RedRockArches", 0.2, 1, 76, 22, 7),
	site("MineEntrance", "RedRockArches", 0.34, -1, 80, 32, 23),
	site("ElevatedTank", "RedRockArches", 0.46, 1, 78, 9, 30),
	site("TrestleRun", "RedRockArches", 0.58, -1, 86, 72, 20),
	site("SurveyCabin", "RedRockArches", 0.7, 1, 70, 14, 11),
	site("StoneWorkshop", "RedRockArches", 0.8, -1, 72, 20, 15),
	site("LookoutShelter", "RedRockArches", 0.92, 1, 84, 10, 16),
	site("MaintHut", "CanyonBridge", 0.02, 1, 70, 12, 8),
	site("OverlookA", "CanyonBridge", 0.06, -1, 76, 18, 8),
	site("ServiceDepot", "CanyonBridge", 0.1, 1, 88, 29, 10),
	site("RidgePlatform", "CanyonBridge", 0.97, -1, 84, 16, 20),
	site("OverlookB", "CanyonBridge", 0.94, 1, 76, 16, 8),
	site("PumpHouse", "CanyonBridge", 0.9, -1, 72, 10, 10),
	site("StairSilhouette", "CanyonBridge", 0.88, 1, 90, 7, 16),
	site("ViaductRemnant", "CanyonBridge", 0.5, 1, 330, 58, 30),
	site("VisitorCenter", "MirageDunes", 0.12, 1, 78, 34, 14),
	site("ShadePavilion", "MirageDunes", 0.22, 1, 66, 23, 9),
	site("RestShelter", "MirageDunes", 0.34, -1, 68, 12, 7),
	site("SolarCanopy", "MirageDunes", 0.46, -1, 84, 40, 6),
	site("RadioDish", "MirageDunes", 0.58, 1, 86, 16, 30),
	site("TurbineHut", "MirageDunes", 0.68, -1, 82, 30, 56),
	site("ResearchShed", "MirageDunes", 0.78, 1, 74, 14, 8),
	site("ObservatoryDome", "MirageDunes", 0.9, -1, 110, 26, 28),
} :: { Site }

return Structures
