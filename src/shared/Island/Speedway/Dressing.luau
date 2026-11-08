--!strict
-- Raceway dressing (Round 6, V-01; Lane 3, presentation only): the small things that make each level look better than
-- the one before. Charm for the early levels (flower planters by the gate, painted kerbs on the dirt turns), track
-- marshals from level 6, light strips from level 8 and the level 12 sky beams that read in daylight (neon, not lights).
-- Each function builds one Look feature into its folder (Look.Features); nothing here pays, prices or saves.
-- Original shapes only: no sponsor boards, no logos, no studs.

local Ctx = require(script.Parent.Ctx)
local Kit = require(script.Parent.Kit)
local Path = require(script.Parent.Path)
local Props = require(script.Parent.Props)
local RoadNet = require(script.Parent.RoadNet)

local Dressing = {}

type Ctx = Ctx.Ctx

local HALF_W = Path.HalfWidth
local R = Path.TurnRadius
local uS = Path.StraightsStart

local RED = Color3.fromRGB(214, 62, 56)
local WHITE = Color3.fromRGB(250, 248, 240)
local WOOD = Color3.fromRGB(176, 118, 74)
local SOIL = Color3.fromRGB(96, 66, 44)
local FLOWERS = {
	Color3.fromRGB(255, 120, 150),
	Color3.fromRGB(255, 214, 72),
	Color3.fromRGB(150, 120, 255),
	Color3.fromRGB(255, 160, 72),
	Color3.fromRGB(255, 255, 255),
}
local STRIP = Color3.fromRGB(64, 224, 255)
local BEAMS = { Color3.fromRGB(255, 204, 64), Color3.fromRGB(255, 96, 176) }

-- Levels 1 to 3: two flower planters either side of the walk gate, on the plaza side of the track.
function Dressing.planters(folder: Folder, ctx: Ctx)
	local w = RoadNet.WalkHalfWidth + 0.6
	local foot = uS - math.sqrt((R + HALF_W) ^ 2 - w * w) - 0.5
	local rng = Random.new(ctx.index * 37 + 5)
	for _, side in { -1, 1 } do
		local centre = Ctx.at(ctx, side * (w + 2.6), foot - 3.6, 0)
		local facing = Ctx.dir(ctx, Vector2.new(0, -1))
		local frame = CFrame.lookAt(centre, centre + facing)
		Kit.part(folder, Vector3.new(2.6, 1, 1.6), frame * CFrame.new(0, 0.5, 0), {
			name = "PlanterBox",
			color = WOOD,
			material = Enum.Material.Wood,
			collide = true,
		})
		Kit.part(folder, Vector3.new(2.3, 0.08, 1.3), frame * CFrame.new(0, 1.02, 0), {
			name = "PlanterSoil",
			color = SOIL,
			castShadow = false,
		})
		for k = 1, 5 do
			local x = -0.85 + (k - 1) * 0.42
			local z = if k % 2 == 0 then 0.25 else -0.25
			Kit.part(folder, Vector3.new(0.7, 0.7, 0.7), frame * CFrame.new(x, 1.35 + rng:NextNumber(0, 0.15), z), {
				name = "PlanterFlower",
				color = FLOWERS[rng:NextInteger(1, #FLOWERS)],
				shape = Enum.PartType.Ball,
				castShadow = false,
			})
		end
	end
end

-- Levels 2 and 3: red and white painted kerb boards round the inside of both dirt turns (the asphalt's curbs take over
-- at level 4). They lie on the dirt like paint, inside the tyres, so nothing new stands in the cars' way.
function Dressing.earlyKerbs(folder: Folder, ctx: Ctx)
	local path = Path.forLevel(1)
	for _, seg in path.segments do
		if seg.kind ~= "arc" then
			continue
		end
		local count = math.max(1, math.floor(seg.length / 4))
		local step = seg.length / count
		for i = 0, count - 1 do
			local cf = Ctx.onPath(ctx, path, seg.s0 + (i + 0.5) * step, -(HALF_W - 0.75), 0.14)
			Kit.part(folder, Vector3.new(1.5, 0.14, step - 0.12), cf * CFrame.new(0, -0.07, 0), {
				name = "PaintedKerb",
				color = if i % 2 == 0 then RED else WHITE,
				castShadow = false,
			})
		end
	end
end

-- Levels 6 to 12: two track marshals (the flag official's figure) on low plinths at the infield edge of the main
-- straight, one near each turn, waving like the official (the client's figure animator).
function Dressing.marshals(folder: Folder, ctx: Ctx)
	local x = -(R - HALF_W) + 3.5
	for k, u in { uS + 11, uS + Path.Straight - 15 } do
		local plinth = Ctx.at(ctx, x, u, 0)
		Kit.part(folder, Vector3.new(1.8, 0.6, 1.8), CFrame.new(plinth + Vector3.yAxis * 0.3), {
			name = "MarshalPlinth",
			color = Color3.fromRGB(255, 140, 40),
			collide = true,
		})
		local base = Ctx.face(ctx, x, u, Vector2.new(-1, 0), 0.6)
		local body = Kit.place("SwOfficialBody", base)
		if not body then
			continue
		end
		local extras = {}
		local shoulder = Kit.point("SwOfficialBody", "shoulder_r", base)
		if shoulder then
			local a = Props.arm("SwOfficialArm", base, shoulder)
			if a then
				a.Name = "ArmR"
				a:SetAttribute("Rest", base:ToObjectSpace(a.CFrame))
				a:SetAttribute("Shoulder", base:PointToObjectSpace(shoulder))
				table.insert(extras, a)
			end
		end
		local marshal = Props.figure(folder, "Marshal", "Official", body, extras, base)
		marshal:SetAttribute("Phase", k * 1.7)
	end
end

-- Levels 8 to 12: a glowing strip along the infield edge of a straight. `side` -1 is the main (start) straight, 1 the
-- back straight (levels 8 to 11 only: level 12's loop apron takes that edge).
function Dressing.lightStrip(folder: Folder, ctx: Ctx, side: number)
	local x = side * (R - HALF_W - 0.9)
	local u0, u1 = uS + 3, uS + Path.Straight - 3
	local a, b = Ctx.at(ctx, x, u0, 0.25), Ctx.at(ctx, x, u1, 0.25)
	Kit.slab(folder, a, b, Vector3.yAxis, 0.35, 0.12, {
		name = "LightStrip",
		color = STRIP,
		material = Enum.Material.Neon,
		castShadow = false,
	}, 0)
end

-- Level 12: four sky beams beside the floodlight towers, leaning outward (clear of the blimp and the loop): a low lamp
-- with a neon lens and a soft Beam that fades as it rises, so it reads in daylight as a glow, not a pole. Nothing moves
-- (Reduce Motion has nothing to stop).
function Dressing.skyBeams(folder: Folder, ctx: Ctx)
	local centre = Vector2.new(0, 441)
	for k, p in Props.Anchors.Floods do
		local inward = (centre - p).Unit
		local foot = p + inward * 6
		local base = Ctx.at(ctx, foot.X, foot.Y, 0)
		local lean = Ctx.dir(ctx, -inward) * math.sin(math.rad(12)) + Vector3.yAxis * math.cos(math.rad(12))
		local colour = BEAMS[(k - 1) % #BEAMS + 1]
		local lamp = Kit.part(
			folder,
			Vector3.new(1.2, 4, 4),
			CFrame.new(base + Vector3.yAxis * 0.6) * CFrame.Angles(0, 0, math.rad(90)),
			{
				name = "SkyBeamBase",
				color = Color3.fromRGB(36, 58, 98),
				shape = Enum.PartType.Cylinder,
				collide = true,
			}
		)
		Kit.part(
			folder,
			Vector3.new(0.2, 3.2, 3.2),
			CFrame.new(base + Vector3.yAxis * 1.25) * CFrame.Angles(0, 0, math.rad(90)),
			{
				name = "SkyBeamLens",
				color = colour,
				material = Enum.Material.Neon,
				shape = Enum.PartType.Cylinder,
				castShadow = false,
			}
		)
		local a0 = Instance.new("Attachment")
		a0.Name = "BeamFoot"
		a0.Parent = lamp
		a0.WorldPosition = base + Vector3.yAxis * 1.3
		local a1 = Instance.new("Attachment")
		a1.Name = "BeamTop"
		a1.Parent = lamp
		a1.WorldPosition = base + Vector3.yAxis * 1.3 + lean * 80
		local beam = Instance.new("Beam")
		beam.Name = "SkyBeam"
		beam.Attachment0 = a0
		beam.Attachment1 = a1
		beam.Color = ColorSequence.new(colour)
		beam.LightEmission = 1
		beam.LightInfluence = 0
		beam.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.15),
			NumberSequenceKeypoint.new(0.6, 0.7),
			NumberSequenceKeypoint.new(1, 1),
		})
		beam.Width0 = 3
		beam.Width1 = 9
		beam.FaceCamera = true
		beam.Segments = 1
		beam.Parent = lamp
	end
end

return Dressing
