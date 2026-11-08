--!strict
-- CloverStand (Round 8, L-01 / L-02, built to R8-IMG-11 and R8-IMG-12): the Lucky Clover stand on every Launch Pad. A charming
-- wooden market stall under a striped green-and-white awning with a scalloped edge, a counter with a gold coin jar and a horseshoe,
-- string lights, a carved "LUCKY CLOVER" sign (live text), the clover mascot behind the counter, and a big four-leaf clover with
-- sparkles and gold coins turning slowly above the roof. The mascot, the roof clover, the coin, the horseshoe and the awning are
-- Blender meshes (CloverMeshes); until the lead uploads them the stand draws a code-built fallback (hearts from parts), so it
-- always looks fine. Presentation only: it reads the player's luck level (a server attribute) and never decides anything.
--
--   CloverStand.build(k, world, life, at) -> { roofTop: number }
--
-- `k` is a PadKit; `at` is the kiosk frame in pad space (the open side faces the middle of the floor, local -Z); `life(fn)` registers
-- motion that runs only while the pad is on show, so nothing here needs cleaning up apart from the pad's own folder.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BetaConfig = require(ReplicatedStorage.Shared.Beta.BetaConfig)
local Tokens = require(ReplicatedStorage.Shared.UI.Tokens)
local CloverMeshes = require(script.Parent.CloverMeshes)
local Motion = require(script.Parent.Parent.Prototype.Motion)

local CloverStand = {}

local rgb = Color3.fromRGB
local V3 = Vector3.new
local CF = CFrame.new
local GOLD = rgb(247, 198, 76)
local INK = rgb(20, 33, 63)
local CREAM = rgb(255, 244, 218)
local LEAF = rgb(73, 200, 87)
local LEAF_DEEP = rgb(36, 140, 56)
local WHITE = rgb(255, 255, 255)
local FACING = CloverMeshes.FACING

type Wood = { light: Color3, mid: Color3, dark: Color3, material: Enum.Material }

-- Lightly themed per World: sun-bleached wood in Dusty Highway, a cosier dark wood in Summit Pass.
local WOODS: { [string]: Wood } = {
	Downtown = {
		light = rgb(212, 156, 98),
		mid = rgb(170, 110, 62),
		dark = rgb(118, 72, 40),
		material = Enum.Material.Wood,
	},
	DustyHighway = {
		light = rgb(238, 216, 182),
		mid = rgb(216, 188, 148),
		dark = rgb(176, 146, 110),
		material = Enum.Material.WoodPlanks,
	},
	SummitPass = {
		light = rgb(166, 112, 70),
		mid = rgb(128, 82, 50),
		dark = rgb(88, 56, 36),
		material = Enum.Material.Wood,
	},
}

local function surfaceGui(part: BasePart, face: Enum.NormalId, pps: number): SurfaceGui
	local g = Instance.new("SurfaceGui")
	g.Face = face
	g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	g.PixelsPerStud = pps
	g.LightInfluence = 0.5
	g.Parent = part
	return g
end

-- A leaf heart from parts, for the fallback: a diamond with a round lobe on each upper edge. `cf` has the leaf's tip at its origin,
-- the leaf axis along +Y and the leaf plane XY; `s` is the leaf height, `t` its thickness.
local function heart(k: any, cf: CFrame, s: number, colour: Color3, t: number)
	local q = 0.72 * s
	k:box("HeartBody", V3(q, q, t), cf * CF(0, q * 0.7071, 0) * CFrame.Angles(0, 0, math.rad(45)), colour)
	for _, sx in { -1, 1 } do
		k:cyl("HeartLobe", 0.64 * s, t, cf * CF(sx * 0.28 * s, 0.68 * s, 0) * CFrame.Angles(math.pi / 2, 0, 0), colour)
	end
end

-- The same four-heart clover as the meshes (fallback): leaves at the four diagonals, tips meeting in the middle.
local function fallbackClover(k: any, cf: CFrame, leaf: number, colour: Color3, t: number)
	for i = 0, 3 do
		local a = math.rad(45 + 90 * i)
		heart(k, cf * CFrame.Angles(0, 0, a - math.pi / 2), leaf, colour:Lerp(WHITE, if i % 2 == 0 then 0.06 else 0), t)
	end
end

-- One placed piece of the mascot or the roof clover: a mesh part, or a fallback model, moved through `set(frame)` with the joint's
-- frame in the world.
type Piece = { set: (self: Piece, frame: CFrame) -> (), mesh: SpecialMesh? }

local function meshPiece(k: any, name: string, partName: string, rest: CFrame): Piece
	local info = CloverMeshes.part(partName)
	local p = k:mesh(
		name,
		CloverMeshes.meshId(info.key),
		CloverMeshes.palette(),
		Vector3.one * CloverMeshes.SCALE,
		rest * CF(info.offset),
		info.size
	)
	local offset = CF(info.offset)
	return {
		mesh = p:FindFirstChildOfClass("SpecialMesh"),
		set = function(_self: Piece, frame: CFrame)
			p.CFrame = frame * offset
		end,
	}
end

local function modelPiece(k: any, name: string, rest: CFrame, build: (any, CFrame) -> ()): Piece
	local bk, model = k:model(name)
	local joint = bk:box("Joint", V3(0.2, 0.2, 0.2), rest, rgb(0, 0, 0))
	joint.Transparency = 1
	model.PrimaryPart = joint
	build(bk, rest)
	return {
		mesh = nil,
		set = function(_self: Piece, frame: CFrame)
			model:PivotTo(frame)
		end,
	}
end

local function ease(x: number): number
	return x * x * (3 - 2 * x)
end

-- A frame sloping up toward +Z (the back of the stall) through `centre`, for roof boards.
local function sloped(centre: Vector3, rise: number, run: number): CFrame
	return CFrame.lookAt(centre, centre + V3(0, rise, run))
end

function CloverStand.build(
	k: any,
	world: string,
	life: (fn: (number, number) -> ()) -> (),
	at: CFrame
): { roofTop: number }
	local wood = WOODS[world] or WOODS.Downtown
	local summit = world == "SummitPass"
	local dusty = world == "DustyHighway"
	local S = at * CF(0, 0, 1) -- the stall's own frame: the open front faces -Z
	local meshes = CloverMeshes.ready()
	local upright = CFrame.Angles(math.pi / 2, 0, 0)

	-- === the floor of the stall, the counter and its carved sign
	k:box("StallDeck", V3(13, 0.25, 8.8), S * CF(0, 0.825, 0), wood.mid, wood.material)
	k:box("CounterBody", V3(11.6, 2.3, 2.4), S * CF(0, 2.1, -2.2), wood.dark, wood.material)
	for i = 0, 6 do
		local board = if i % 2 == 0 then wood.light else wood.mid
		k:box("CounterBoard", V3(1.5, 2.3, 0.14), S * CF(-4.8 + i * 1.6, 2.1, -3.45), board, wood.material)
	end
	k:box("CounterTop", V3(12.4, 0.35, 3.2), S * CF(0, 3.275, -2.3), wood.light, wood.material)
	k:box("CounterTrim", V3(12.5, 0.12, 0.14), S * CF(0, 3.42, -3.92), GOLD, Enum.Material.Metal)
	for _, s in { -1, 1 } do
		k:box("SidePanel", V3(0.3, 2.6, 7.4), S * CF(s * 6.05, 2.25, 0.2), wood.mid, wood.material)
	end
	-- the carved sign: a wooden frame, a cream plate, the words as live text and a little clover at each end
	k:box("SignFrame", V3(8.4, 2.1, 0.3), S * CF(0, 2.15, -3.68), wood.dark, wood.material)
	k:box("SignFrameTop", V3(8.0, 0.2, 0.34), S * CF(0, 3.28, -3.68), GOLD, Enum.Material.Metal)
	local plate = k:box("SignPlate", V3(7.8, 1.7, 0.12), S * CF(0, 2.15, -3.87), CREAM)
	local gui = surfaceGui(plate, Enum.NormalId.Front, 60)
	local words = Instance.new("TextLabel")
	words.Name = "LuckyCloverWords"
	words.BackgroundTransparency = 1
	words.AnchorPoint = Vector2.new(0.5, 0.5)
	words.Position = UDim2.fromScale(0.5, 0.52)
	words.Size = UDim2.fromScale(0.62, 0.92)
	words.FontFace = Tokens.font()
	words.TextScaled = true
	words.Text = "LUCKY\nCLOVER"
	words.TextColor3 = INK
	words.LineHeight = 0.85
	words.Parent = gui
	for _, s in { -1, 1 } do
		local iconAt = S * CF(s * 3.35, 2.15, -3.95)
		if meshes then
			local info = CloverMeshes.part("sign")
			local p = k:mesh(
				"SignIcon",
				CloverMeshes.meshId(info.key),
				CloverMeshes.palette(),
				Vector3.one * 0.3 * CloverMeshes.SCALE,
				iconAt * FACING * CF(info.offset * 0.3),
				info.size * 0.3
			)
			p.CastShadow = false
		else
			fallbackClover(k, iconAt, 0.5, LEAF, 0.16)
		end
	end

	-- === posts, the back wall, the roof and the awning
	for _, sx in { -1, 1 } do
		k:box("FrontPost", V3(0.9, 10.4, 0.9), S * CF(sx * 5.8, 6.15, -3.9), wood.dark, wood.material)
		k:box("RearPost", V3(0.9, 12.2, 0.9), S * CF(sx * 5.8, 7.05, 3.9), wood.dark, wood.material)
		k:ball("PostFinial", 1, S * CF(sx * 5.8, 11.7, -3.9), GOLD, Enum.Material.Metal)
	end
	for i = 0, 10 do
		local stripe = if i % 2 == 0 then rgb(46, 125, 59) else rgb(64, 156, 76)
		k:box("BackBoard", V3(1, 11.8, 0.3), S * CF(-5 + i, 6.85, 4.2), stripe, Enum.Material.SmoothPlastic)
	end
	local rise, run = 2.0, 8.4
	local roofAt = sloped((S * CF(0, 12.1, 0)).Position, rise, run)
	k:box("RoofSlab", V3(13.8, 0.5, math.sqrt(run * run + rise * rise) + 0.6), roofAt, wood.mid, wood.material)
	k:box("RoofBeam", V3(14.2, 0.7, 0.8), S * CF(0, 11.05, -4.3), wood.dark, wood.material)
	k:box("RoofRidge", V3(14.2, 0.5, 0.9), S * CF(0, 13.15, 4.2), wood.dark, wood.material)
	k:box("RoofTrim", V3(14.4, 0.12, 0.2), S * CF(0, 11.42, -4.45), GOLD, Enum.Material.Metal)

	local awningFrame = S * CF(0, 11.3, -4.3) -- the middle of the awning's top edge
	if meshes then
		local info = CloverMeshes.part("awning")
		k:mesh(
			"Awning",
			CloverMeshes.meshId(info.key),
			CloverMeshes.palette(),
			Vector3.one * CloverMeshes.SCALE,
			awningFrame * FACING * CF(info.offset),
			info.size
		)
	else
		-- fallback: eight stripes down a slope, each with a round hem
		for i = 0, 7 do
			local x = -5.6 + i * 1.6
			local c = if i % 2 == 0 then rgb(61, 178, 77) else rgb(255, 248, 238)
			local strip = sloped((awningFrame * CF(x, -0.85, -2.3)).Position, 1.7, 4.6)
			k:box("AwningStripe", V3(1.6, 0.22, 5.0), strip, c)
			k:cyl("AwningHem", 1.6, 0.22, awningFrame * CF(x, -2.2, -4.7) * upright, c)
		end
	end

	-- === string lights under the awning: a swag across the front and one down each side, with a warm glow
	local bulbs: { BasePart } = {}
	local function swag(a: Vector3, b: Vector3, count: number, sag: number)
		for i = 0, count do
			local t = i / count
			local p = a:Lerp(b, t) - V3(0, sag * math.sin(math.pi * t), 0)
			local bulb = k:ball("Bulb", 0.5, CF(p), rgb(255, 224, 140), Enum.Material.Neon)
			bulb.CastShadow = false
			table.insert(bulbs, bulb)
		end
	end
	local function sp(x: number, y: number, z: number): Vector3
		return (S * CF(x, y, z)).Position
	end
	swag(sp(-5.6, 8.1, -4.4), sp(5.6, 8.1, -4.4), 11, 0.9)
	swag(sp(-5.6, 8.1, -4.4), sp(-5.6, 8.1, 3.7), 5, 0.5)
	swag(sp(5.6, 8.1, -4.4), sp(5.6, 8.1, 3.7), 5, 0.5)
	local glow = Instance.new("PointLight")
	glow.Color = rgb(255, 214, 130)
	glow.Range = 16
	glow.Brightness = 1.2
	glow.Parent = bulbs[6]

	-- === the counter: a gold coin jar (viewer's left) and a horseshoe (viewer's right)
	local jarAt = S * CF(4.0, 3.45, -2.2)
	local jar = k:cyl("CoinJar", 2.1, 2.7, jarAt * CF(0, 1.35, 0), rgb(205, 236, 244), Enum.Material.Glass)
	jar.Transparency = 0.55
	k:cyl("CoinJarLid", 2.3, 0.3, jarAt * CF(0, 2.85, 0), GOLD, Enum.Material.Metal)
	for i = 0, 7 do
		k:cyl(
			"JarCoin",
			1.6,
			0.22,
			jarAt * CF(0.08 * (i % 2), 0.2 + i * 0.3, 0.06 * (i % 3)),
			GOLD,
			Enum.Material.Metal
		)
	end
	for i = 0, 2 do
		local c = S * CF(2.0 - i * 0.55, 3.52 + (i % 2) * 0.17, -3.0 + i * 0.35) * CFrame.Angles(0, i, 0)
		k:cyl("CounterCoin", 1.1, 0.16, c, GOLD, Enum.Material.Metal)
	end
	local shoeAt = S * CF(-4.0, 3.45, -2.4)
	k:box("HorseshoeBase", V3(1.8, 0.4, 1.2), shoeAt * CF(0, 0.2, 0), wood.dark, wood.material)
	if meshes then
		local info = CloverMeshes.part("horseshoe")
		k:mesh(
			"Horseshoe",
			CloverMeshes.meshId(info.key),
			CloverMeshes.palette(),
			Vector3.one * 1.2 * CloverMeshes.SCALE,
			shoeAt * CF(0, 1.3, 0) * FACING * CF(info.offset * 1.2),
			info.size * 1.2
		)
	else
		for i = 0, 8 do
			local a = math.rad(-150 + i * 37.5)
			local link = shoeAt * CF(math.sin(a) * 0.95, 1.9 - math.cos(a) * 0.9, 0) * CFrame.Angles(0, 0, -a)
			k:box("HorseshoeLink", V3(0.34, 0.5, 0.3), link, GOLD, Enum.Material.Metal)
		end
	end

	-- === bushes with flowers at the front corners
	for _, sx in { -1, 1 } do
		local base = S * CF(sx * 7.4, 0.7, -5.6)
		for i, off in { V3(0, 0.9, 0), V3(1.1, 0.5, 0.5), V3(-1, 0.55, 0.6), V3(0.2, 0.5, -1) } do
			k:ball("BushBall", 2.4 - i * 0.2, base * CF(off), rgb(58 + i * 6, 170, 66), Enum.Material.Grass)
		end
		for _, off in { V3(0.6, 2, -0.4), V3(-0.7, 1.7, 0.2), V3(0.1, 1.6, -1.3) } do
			k:ball("Flower", 0.5, base * CF(off), rgb(255, 250, 240))
			k:ball("FlowerHeart", 0.2, base * CF(off + V3(0, 0.1, -0.2)), rgb(255, 210, 70))
		end
	end

	-- === Summit Pass: snow on the awning and the roof, icicles under the hem, drifts at the foot
	if summit then
		local snow = rgb(248, 252, 255)
		k:box("RoofSnow", V3(14.2, 0.7, 9), roofAt * CF(0, 0.55, 0), snow, Enum.Material.Snow)
		k:box("RidgeSnow", V3(14.6, 0.8, 1.2), S * CF(0, 13.5, 4.2), snow, Enum.Material.Snow)
		for i = 0, 5 do
			k:ball(
				"AwningSnow",
				2.6,
				awningFrame * CF(-5.4 + i * 2.15, -0.35 - (i % 2) * 0.2, -1.2),
				snow,
				Enum.Material.Snow
			)
		end
		for i = 0, 7 do
			k:ball("AwningSnowLow", 2.1, awningFrame * CF(-5.6 + i * 1.6, -1.55, -3.6), snow, Enum.Material.Snow)
			local ice = k:wedge(
				"Icicle",
				V3(0.3, 1.1 - (i % 3) * 0.25, 0.3),
				awningFrame * CF(-5.6 + i * 1.6, -3.6, -5.6) * CFrame.Angles(math.pi, 0, 0),
				rgb(214, 238, 255),
				Enum.Material.Glass
			)
			ice.Transparency = 0.25
		end
		for i, off in { V3(-6.8, 0.2, -1), V3(7, 0.2, 0), V3(-3, 0.1, -6.2), V3(3.5, 0.1, -6.4), V3(0, 0.1, 6.4) } do
			k:ball("StallDrift", 3.2 + (i % 2), S * CF(off), snow, Enum.Material.Snow)
		end
	end
	-- Dusty Highway: sand drifting against the wood and a small cactus beside the counter
	if dusty then
		for i, off in { V3(-6.8, 0.1, -1), V3(7, 0.1, -3), V3(-2.5, 0.1, -6.4), V3(4, 0.1, -6.5) } do
			k:ball("StallSand", 3 + (i % 2), S * CF(off), rgb(232, 198, 142), Enum.Material.Sand)
		end
		local cactus = S * CF(-8.6, 0.8, -5)
		local green = rgb(86, 156, 98)
		k:cyl("Cactus", 1.3, 3.8, cactus * CF(0, 1.9, 0), green)
		k:ball("CactusTop", 1.3, cactus * CF(0, 3.8, 0), green)
		k:cyl("CactusArm", 0.7, 1.4, cactus * CF(0.95, 2.4, 0) * CFrame.Angles(0, 0, math.pi / 2), green)
	end

	-- === the mascot, behind the counter. Its mesh frame faces +Z; the stall faces -Z, so the rig is turned by FACING.
	local rigAt = S * CF(0, 5.5, 1.2) * FACING
	local P = CloverMeshes.Pivots
	local pivots = if meshes
		then { eyeL = P.eyeL, eyeR = P.eyeR, hat = P.hat, armL = P.armL, armR = P.armR }
		else {
			eyeL = V3(-0.68, 0.5, 0.85),
			eyeR = V3(0.68, 0.5, 0.85),
			hat = V3(0.3, 1.5, 0.3),
			armL = V3(-1.55, -0.4, 0),
			armR = V3(1.55, -0.4, 0),
		}
	local hatRest = if meshes then CloverMeshes.HatRest else CFrame.new()
	local pieces: { [string]: Piece } = {}
	if meshes then
		pieces.body = meshPiece(k, "MascotBody", "body", rigAt)
		pieces.eyeL = meshPiece(k, "MascotEye", "eye", rigAt * CF(pivots.eyeL))
		pieces.eyeR = meshPiece(k, "MascotEye", "eye", rigAt * CF(pivots.eyeR))
		pieces.hat = meshPiece(k, "MascotHat", "hat", rigAt * CF(pivots.hat) * hatRest)
		pieces.armL = meshPiece(k, "MascotArmL", "armL", rigAt * CF(pivots.armL))
		pieces.armR = meshPiece(k, "MascotArmR", "armR", rigAt * CF(pivots.armR))
	else
		-- fallback mascot (front is +Z in this frame): four hearts with a face, a stem, a hat, arms and white gloves
		pieces.body = modelPiece(k, "MascotBody", rigAt, function(bk: any, rest: CFrame)
			for i = 0, 3 do
				local a = math.rad(45 + 90 * i)
				local c = LEAF:Lerp(WHITE, if i % 2 == 0 then 0.06 else 0)
				heart(bk, rest * CFrame.Angles(0, 0, a - math.pi / 2), 1.8, c, 1.4)
			end
			bk:cyl("Stem", 0.7, 1.6, rest * CF(0.2, -2.5, -0.2) * CFrame.Angles(0, 0, math.rad(-12)), LEAF_DEEP)
			bk:cyl("Cheek", 0.7, 0.12, rest * CF(-1.2, -0.2, 0.72) * upright, rgb(247, 135, 140))
			bk:cyl("Cheek", 0.7, 0.12, rest * CF(1.2, -0.2, 0.72) * upright, rgb(247, 135, 140))
			bk:cyl("Mouth", 1.0, 0.12, rest * CF(0, -0.55, 0.74) * upright, rgb(110, 21, 48))
			bk:cyl("Coin", 0.8, 0.14, rest * CF(1.0, -1.0, 0.74) * upright, GOLD, Enum.Material.Metal)
		end)
		for _, side in { "eyeL", "eyeR" } do
			pieces[side] = modelPiece(k, "MascotEye", rigAt * CF(pivots[side]), function(bk: any, rest: CFrame)
				bk:ball("EyeWhite", 0.9, rest, WHITE)
				bk:ball("EyePupil", 0.55, rest * CF(0, 0, 0.28), INK)
			end)
		end
		pieces.hat = modelPiece(k, "MascotHat", rigAt * CF(pivots.hat), function(bk: any, rest: CFrame)
			bk:cyl("HatBrim", 1.8, 0.14, rest * CF(0, 0.07, 0), rgb(24, 112, 52))
			bk:cyl("HatCrown", 1.1, 0.9, rest * CF(0, 0.55, 0), rgb(24, 112, 52))
			bk:cyl("HatBand", 1.16, 0.22, rest * CF(0, 0.3, 0), GOLD, Enum.Material.Metal)
		end)
		for _, side in { "armL", "armR" } do
			local s = if side == "armL" then -1 else 1
			pieces[side] = modelPiece(k, "MascotArm", rigAt * CF(pivots[side]), function(bk: any, rest: CFrame)
				bk:cyl("Arm", 0.34, 1.2, rest * CF(s * 0.5, -0.3, 0) * CFrame.Angles(0, 0, math.rad(60 * s)), LEAF_DEEP)
				bk:ball("Glove", 0.85, rest * CF(s * 1.0, -0.7, 0), WHITE)
			end)
		end
	end

	-- === the big clover over the roof, with sparkles and three gold coins in orbit
	local cloverAt = S * CF(0, 17.1, 0.6) * FACING
	k:cyl("CloverPost", 0.5, 3.2, S * CF(0, 14.7, 0.6), GOLD, Enum.Material.Metal)
	k:cyl("CloverBase", 1.8, 0.4, S * CF(0, 13.35, 0.6), GOLD, Enum.Material.Metal)
	local sign: Piece
	if meshes then
		sign = meshPiece(k, "RoofClover", "sign", cloverAt)
	else
		sign = modelPiece(k, "RoofClover", cloverAt, function(bk: any, rest: CFrame)
			fallbackClover(bk, rest, 2.6, LEAF, 1.1)
		end)
	end
	local core = k:box("CloverCore", Vector3.one * 0.4, cloverAt, INK)
	core.Transparency = 1
	local glitter = Instance.new("ParticleEmitter")
	glitter.Name = "Sparkles"
	glitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	glitter.Rate = 12
	glitter.Lifetime = NumberRange.new(0.9, 1.5)
	glitter.Speed = NumberRange.new(1.5, 3.5)
	glitter.SpreadAngle = Vector2.new(180, 180)
	glitter.LightEmission = 1
	glitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 0) })
	glitter.Color = ColorSequence.new(rgb(255, 238, 120), rgb(150, 255, 150))
	glitter.Parent = core
	local glow2 = Instance.new("PointLight")
	glow2.Color = rgb(150, 255, 150)
	glow2.Range = 18
	glow2.Brightness = 1.4
	glow2.Parent = core
	local coins: { Piece } = {}
	for _ = 1, 3 do
		if meshes then
			table.insert(coins, meshPiece(k, "FloatCoin", "coin", cloverAt))
		else
			table.insert(
				coins,
				modelPiece(k, "FloatCoin", cloverAt, function(bk: any, rest: CFrame)
					bk:cyl("CoinDisc", 1.3, 0.2, rest * upright, GOLD, Enum.Material.Metal)
				end)
			)
		end
	end
	-- the happy spin's burst of gold sparkles
	local burstPart = k:box("MascotBurst", Vector3.one * 0.4, rigAt, INK)
	burstPart.Transparency = 1
	local burst = Instance.new("ParticleEmitter")
	burst.Name = "LuckBurst"
	burst.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	burst.Rate = 0
	burst.Lifetime = NumberRange.new(0.8, 1.4)
	burst.Speed = NumberRange.new(6, 12)
	burst.SpreadAngle = Vector2.new(180, 180)
	burst.LightEmission = 1
	burst.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.9), NumberSequenceKeypoint.new(1, 0) })
	burst.Color = ColorSequence.new(rgb(255, 224, 90), rgb(255, 250, 200))
	burst.Parent = burstPart

	-- === motion: an idle bob, a wave when a player walks up, a happy spin with sparkles when luck is bought, blinks and a look
	-- toward the player. Runs only while the pad is on show; Reduce Motion keeps everything still.
	local world0 = k.origin * rigAt
	local stand = (k.origin * S).Position
	local cloverWorld = k.origin * cloverAt
	local lastLuck = tonumber(Players.LocalPlayer:GetAttribute(BetaConfig.LuckAttribute)) or 0
	local near = false
	local waveStart = -math.huge
	local spinStart = -math.huge
	local nextBlink = 2
	local blinkEnd = 0
	local tick = 0
	local WAVE, SPIN = 2.8, 1.1
	life(function(t: number, dt: number)
		tick += dt
		if tick < 1 / 30 then
			return
		end
		tick = 0
		local still = Motion.reduced()
		-- the luck level going up (the server wrote it) is the happy spin
		local luck = tonumber(Players.LocalPlayer:GetAttribute(BetaConfig.LuckAttribute)) or 0
		if luck > lastLuck and not still then
			spinStart = t
			burst:Emit(36)
		end
		lastLuck = luck
		local character = Players.LocalPlayer.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local lookAt: Vector3? = nil
		if root then
			local flat = V3(root.Position.X - stand.X, 0, root.Position.Z - stand.Z).Magnitude
			if flat < 26 and not near then
				near = true
				if not still then
					waveStart = t
				end
			elseif flat > 34 then
				near = false
			end
			if flat < 45 then
				lookAt = root.Position
			end
		end
		local idle = if still then 0 else t
		local bob = math.sin(idle * 1.7) * 0.12
		local roll = math.sin(idle * 1.1) * math.rad(2)
		local yaw = 0
		local jump = 0
		local armR = math.rad(-4) + math.sin(idle * 1.5) * math.rad(3)
		local armL = math.rad(4) - math.sin(idle * 1.5) * math.rad(3)
		local hatUp = 0
		if t - waveStart < WAVE then
			local u = (t - waveStart) / WAVE
			local lift = math.min(1, u * 6, (1 - u) * 6)
			armR = math.rad(-4)
				+ (math.rad(128) + math.sin((t - waveStart) * 9) * math.rad(16) - math.rad(-4)) * ease(lift)
			roll += math.sin((t - waveStart) * 3) * math.rad(3) * lift
		end
		if t - spinStart < SPIN then
			local u = (t - spinStart) / SPIN
			yaw = math.rad(360) * ease(u)
			jump = math.sin(math.pi * u) * 0.9
			local lift = math.min(1, u * 5, (1 - u) * 5)
			armR = math.rad(-4) + (math.rad(80) - math.rad(-4)) * lift
			armL = math.rad(4) - (math.rad(80) + math.rad(4)) * lift
			hatUp = math.sin(math.pi * u) * 0.6
		end
		local body = world0 * CF(0, bob + jump, 0) * CFrame.Angles(0, yaw, roll)
		pieces.body:set(body)
		-- eyes: a small look toward the player, and a quick blink
		local ex, ey = 0, 0
		if lookAt and not still then
			local rel = body:PointToObjectSpace(lookAt)
			ex = math.clamp(math.atan2(rel.X, math.max(rel.Z, 1)), -0.3, 0.3) * 0.6
			ey = math.clamp(math.atan2(rel.Y - 1, math.max(rel.Z, 1)), -0.25, 0.25) * -0.4
		end
		local blink = if t >= nextBlink and t < blinkEnd then 0.15 else 1
		if t >= blinkEnd and t >= nextBlink then
			blinkEnd = t + 0.13
			nextBlink = t + 3 + math.random() * 2.5
		end
		for _, name in { "eyeL", "eyeR" } do
			pieces[name]:set(body * CF(pivots[name]) * CFrame.Angles(ey, ex, 0))
			local sm = pieces[name].mesh
			if sm then
				sm.Scale = V3(1, blink, 1) * CloverMeshes.SCALE
			end
		end
		pieces.hat:set(body * CF(pivots.hat + V3(0, hatUp, 0)) * hatRest)
		pieces.armR:set(body * CF(pivots.armR) * CFrame.Angles(0, 0, armR))
		pieces.armL:set(body * CF(pivots.armL) * CFrame.Angles(0, 0, armL))
		burstPart.CFrame = body
		-- the roof clover turns slowly and bobs; three gold coins orbit it
		local turn = if still then 0 else t * 0.7
		sign:set(cloverWorld * CFrame.Angles(0, turn, 0) * CF(0, if still then 0 else math.sin(t * 1.3) * 0.25, 0))
		for i, coin in coins do
			local a = if still then i * 2.1 else t * 0.9 + i * 2.1
			local orbit = cloverWorld * CF(math.cos(a) * 4.4, math.sin(a * 1.7 + i) * 0.8, math.sin(a) * 4.4)
			coin:set(orbit * CFrame.Angles(0, if still then 0 else t * 2.2 + i, 0))
		end
		if not still then
			for i, bulb in bulbs do
				bulb.Transparency = 0.15 * (0.5 + 0.5 * math.sin(t * 2 + i))
			end
		end
	end)
	return { roofTop = 13.4 }
end

return CloverStand
