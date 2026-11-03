--!strict
-- The stadium and the city of the Stunt Circuit (Lane 3, M17-01): a grandstand with a crowd and a roof beside the start and
-- finish straight, flags along the other side, light towers, and a simple city backdrop on every side, all from plain Parts
-- (no new asset ids). The mock's finish panel is the model: bleachers on the left of the road, a gantry over it, light towers,
-- a skyline behind. The stand sits on the INFIELD side (the left of travel on the start/finish leg, world -X).
--
--   Stadium.build(root: Model) -> ()
--
-- Light by construction: CastShadow is off on everything except the roof, no part collides, and the crowd is 60 large
-- coloured blocks rather than hundreds of heads. Flags are small models with idle attributes; StuntIdle sways them.

local Parts = require(script.Parent.StuntParts)
local StuntData = require(script.Parent.StuntData)

local Stadium = {}

local P = Parts.Palette
local GROUND = StuntData.Road.groundY
local PAINT = 0.12

local rgb = Color3.fromRGB

-- GRANDSTAND -----------------------------------------------------------------------------------------------------------

local STAND_NEAR = -56 -- x of the near edge of the lowest tier (the road edge is at -38, the barrier cap at -40.5)
local TIER_DEPTH = 7.5
local TIERS = 8
local STAND_Z0, STAND_Z1 = -150, 430
local CROWD = {
	rgb(226, 72, 70),
	rgb(247, 200, 58),
	rgb(240, 240, 248),
	rgb(64, 160, 222),
	rgb(255, 122, 26),
	rgb(120, 200, 110),
}

local function tierTop(k: number): number
	return 1 + 3.2 * k
end

local function buildStand(folder: Folder)
	local stand = Parts.folder(folder, "Grandstand")
	local length = STAND_Z1 - STAND_Z0
	local zMid = (STAND_Z0 + STAND_Z1) / 2
	for k = 0, TIERS - 1 do
		local near = STAND_NEAR - k * TIER_DEPTH
		local top = tierTop(k)
		-- the tier is a solid block from the ground to its top; the seat band lies on it, 0.12 up
		Parts.box(
			stand,
			"Tier" .. k,
			Vector3.new(TIER_DEPTH, top - GROUND, length),
			CFrame.new(near - TIER_DEPTH / 2, (top + GROUND) / 2, zMid),
			P.Concrete
		)
		Parts.box(
			stand,
			"SeatBand" .. k,
			Vector3.new(TIER_DEPTH - 1, PAINT, length - 4),
			CFrame.new(near - TIER_DEPTH / 2, top + PAINT / 2, zMid),
			if k % 2 == 0 then P.Navy else rgb(46, 74, 140)
		)
	end
	-- the crowd: six rows of coloured blocks standing on the seat bands (tiers 1 to 6), 10 blocks a row
	local chunks = 10
	local chunkLength = (length - 4) / chunks
	for k = 1, 6 do
		local near = STAND_NEAR - k * TIER_DEPTH
		local top = tierTop(k) + PAINT
		for i = 0, chunks - 1 do
			local colour = CROWD[(i + k * 2) % #CROWD + 1]
			Parts.box(
				stand,
				"Crowd",
				Vector3.new(3, 3, chunkLength - 2),
				CFrame.new(near - 2, top + 1.5, STAND_Z0 + 2 + (i + 0.5) * chunkLength),
				colour
			)
		end
	end
	-- the back wall, the roof and its pillars
	local farX = STAND_NEAR - TIERS * TIER_DEPTH
	Parts.box(
		stand,
		"BackWall",
		Vector3.new(2, 30 - GROUND, length),
		CFrame.new(farX - 1, (30 + GROUND) / 2, zMid),
		P.ConcreteDark
	)
	Parts.box(
		stand,
		"Roof",
		Vector3.new(34, 1.5, length),
		CFrame.new(farX + 15, 30.75, zMid),
		P.Navy,
		{ shadow = true }
	)
	Parts.box(stand, "RoofEdge", Vector3.new(0.6, 1.5, length), CFrame.new(farX + 32.3, 30.75, zMid), P.Gold)
	local tier3Top = tierTop(3)
	local pillarX = STAND_NEAR - 4 * TIER_DEPTH + 0.5 -- on the step between tier 3 and tier 4
	for i = 0, 5 do
		local z = STAND_Z0 + 40 + i * (length - 80) / 5
		Parts.box(
			stand,
			"RoofPillar",
			Vector3.new(2, 30 - tier3Top, 2),
			CFrame.new(pillarX, (30 + tier3Top) / 2, z),
			P.Steel
		)
	end
end

-- LIGHT TOWERS ---------------------------------------------------------------------------------------------------------

local function tower(folder: Folder, x: number, z: number, facing: number)
	local model = Parts.model(folder, "LightTower")
	Parts.box(model, "Pole", Vector3.new(2.4, 64, 2.4), CFrame.new(x, GROUND + 32, z), P.Steel)
	Parts.box(model, "Head", Vector3.new(2, 8, 16), CFrame.new(x, 62, z), P.Ink)
	-- six lamps on the face toward the road (facing = +1 looks along +X, -1 along -X)
	for row = 0, 1 do
		for col = 0, 2 do
			Parts.box(
				model,
				"Lamp",
				Vector3.new(0.5, 3, 4.2),
				CFrame.new(x + facing * 1.25, 63.5 - row * 3.6, z - 5 + col * 5),
				P.Lamp,
				{ material = Enum.Material.Neon }
			)
		end
	end
end

local function buildTowers(folder: Folder)
	local towers = Parts.folder(folder, "LightTowers")
	-- on the infield side they stand behind the stand and look toward it, on the far side they look toward the road
	for _, z in { -100, 150, 400 } do
		tower(towers, STAND_NEAR - TIERS * TIER_DEPTH - 14, z, 1)
	end
	for _, z in { -40, 200, 440 } do
		tower(towers, 78, z, -1)
	end
end

-- FLAGS ------------------------------------------------------------------------------------------------------------------

local function buildFlags(folder: Folder)
	local flags = Parts.folder(folder, "Flags")
	local colours = { P.Navy, P.Gold, P.White, P.Orange }
	for i = 0, 10 do
		local z = -100 + i * 60
		local x = 52
		local model = Parts.model(flags, "Flag" .. i)
		model:SetAttribute("IdleKind", "Flag")
		model:SetAttribute("IdlePhase", (i % 4) / 4)
		model:SetAttribute("Note", "scenery; sways on an idle loop")
		Parts.cylinder(
			model,
			"Pole",
			0.8,
			18,
			CFrame.new(x, GROUND + 9 + 0, z) * CFrame.Angles(0, 0, math.pi / 2),
			P.White
		)
		Parts.box(model, "Cloth", Vector3.new(6.2, 3.6, 0.2), CFrame.new(x - 3.5, 12.4, z), colours[i % #colours + 1])
		local ball = Parts.box(model, "Finial", Vector3.new(1.4, 1.4, 1.4), CFrame.new(x, 14.7, z), P.Gold)
		ball.Shape = Enum.PartType.Ball
		model.WorldPivot = CFrame.new(x, 0, z)
	end
end

-- CITY BACKDROP ----------------------------------------------------------------------------------------------------------

local FACADES = {
	rgb(232, 228, 220),
	rgb(190, 206, 232),
	rgb(238, 198, 160),
	rgb(170, 186, 214),
	rgb(214, 214, 226),
	rgb(244, 214, 150),
	rgb(150, 196, 196),
}
local ROOF = rgb(70, 80, 104)
local GLASS = rgb(130, 182, 224)

-- One building: a body, a roof cap and a glass band on the face toward the track (facing: the world direction the face looks).
local function building(
	folder: Folder,
	rng: Random,
	x: number,
	z: number,
	w: number,
	d: number,
	h: number,
	facing: Vector3
)
	local model = Parts.model(folder, "Building")
	local colour = FACADES[rng:NextInteger(1, #FACADES)]
	local base = GROUND
	Parts.box(model, "Body", Vector3.new(w, h - base, d), CFrame.new(x, (h + base) / 2, z), colour)
	Parts.box(model, "RoofCap", Vector3.new(w + 1.2, 1.4, d + 1.2), CFrame.new(x, h + 0.7, z), ROOF)
	-- the glass band sits 0.12 out from the face and spans most of it
	local across = if math.abs(facing.X) > 0 then d else w
	local depthHalf = if math.abs(facing.X) > 0 then w / 2 else d / 2
	local bandSize = if math.abs(facing.X) > 0
		then Vector3.new(PAINT, (h - base) * 0.5, across * 0.8)
		else Vector3.new(across * 0.8, (h - base) * 0.5, PAINT)
	local bandAt = Vector3.new(x, base + (h - base) * 0.62, z) + facing * (depthHalf + PAINT / 2)
	Parts.box(model, "Windows", bandSize, CFrame.new(bandAt), GLASS)
end

local function buildBackdrop(folder: Folder)
	local city = Parts.folder(folder, "City")
	local rng = Random.new(1701)
	-- east of the road, behind the light towers
	for i = 0, 12 do
		local z = -560 + i * 135
		building(
			city,
			rng,
			140 + rng:NextInteger(0, 60),
			z,
			rng:NextInteger(60, 90),
			rng:NextInteger(70, 100),
			rng:NextInteger(40, 110),
			Vector3.new(-1, 0, 0)
		)
	end
	-- north, beyond the far leg: the tall skyline the flythrough looks down the start straight at
	for i = 0, 6 do
		local x = -900 + i * 160
		if i == 3 then
			-- one stepped tower with a spire, the skyline's landmark
			local m = Parts.model(city, "Landmark")
			local z = -860
			Parts.box(
				m,
				"TowerBase",
				Vector3.new(80, 130 - GROUND, 80),
				CFrame.new(x, (130 + GROUND) / 2, z),
				FACADES[2]
			)
			Parts.box(m, "TowerMid", Vector3.new(56, 70, 56), CFrame.new(x, 165, z), FACADES[1])
			Parts.box(m, "TowerTop", Vector3.new(30, 50, 30), CFrame.new(x, 225, z), FACADES[2])
			Parts.box(m, "Spire", Vector3.new(4, 60, 4), CFrame.new(x, 280, z), P.Steel)
			Parts.box(m, "TowerWindows", Vector3.new(64, 90, PAINT), CFrame.new(x, 80, z + 40 + PAINT / 2), GLASS)
		else
			building(
				city,
				rng,
				x + rng:NextInteger(-20, 20),
				-800 - rng:NextInteger(0, 100),
				rng:NextInteger(70, 100),
				rng:NextInteger(70, 100),
				rng:NextInteger(100, 190),
				Vector3.new(0, 0, 1)
			)
		end
	end
	-- west, beyond the far side of the infield
	for i = 0, 6 do
		building(
			city,
			rng,
			-1040 - rng:NextInteger(0, 60),
			-500 + i * 250,
			rng:NextInteger(70, 100),
			rng:NextInteger(80, 120),
			rng:NextInteger(50, 130),
			Vector3.new(1, 0, 0)
		)
	end
	-- south, past the pond
	for i = 0, 4 do
		building(
			city,
			rng,
			-840 + i * 210,
			1400 + rng:NextInteger(0, 80),
			rng:NextInteger(80, 110),
			rng:NextInteger(70, 100),
			rng:NextInteger(50, 120),
			Vector3.new(0, 0, -1)
		)
	end
end

-- ENTRY ------------------------------------------------------------------------------------------------------------------------

function Stadium.build(root: Model)
	local folder = Parts.folder(root, "Stadium")
	folder:SetAttribute("Note", "scenery only; no collision")
	buildStand(folder)
	buildTowers(folder)
	buildFlags(folder)
	buildBackdrop(Parts.folder(root, "Backdrop"))
end

return Stadium
