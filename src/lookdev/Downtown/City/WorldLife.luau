--!strict
-- WORLD LIFE for Dusty Highway and Summit Pass (Lane 3, Round 2, R2-DH1 / R2-SP1). Bounded, off-road, reduced-motion
-- aware ambient accents on the same pattern as StreetLife (which stays the Downtown set), driven by the plan:
--   Dusty Highway   tumbleweeds  4 balls rolling along the sidewalk strip beside the road (never on the carriageway)
--                   hawks        3 circling high over the midground ahead
--                   dust devil   1 thin, slow column of sand far off the road, drifting sideways (never near the route)
--   Summit Pass     snowfall     one light emitter following the camera: small slow flakes, no flashing, no full-screen
--                                effect, thinned in reduced motion
--                   smoke        up to 5 chimney emitters on the chalets, the warming hut and the lodge (near only)
--                   birds        one flock of 5 circling high ahead
-- Fixed pools re-home as the station advances; nothing is created per frame. Reduced motion (GuiService.ReducedMotionEnabled
-- or the preview-only Lane3ReducedMotionOverride attribute): tumbleweeds rest, hawks and birds glide, the dust devil and
-- most of the snow stop, smoke thins.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Parts = require(script.Parent.Parent.Parts)
local Route = require(script.Parent.Route)
local Util = require(script.Parent.Util)
local Trove = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Trove"))

local WorldLife = {}
WorldLife.__index = WorldLife

local NEAR = 350
local SKY_NEAR = 900
local AHEAD = 420
local BEHIND = 50

-- chimney tops in each landmark's lot frame (x along the facade from the lot's left corner, y up, z back from the
-- frontage line), read off the kit recipes (kit_summit.py): approximate, labelled as such
local SMOKE: { [string]: { Vector3 } } = {
	ChaletCluster = { Vector3.new(15, 23, 8.7), Vector3.new(36.6, 28.5, 8.7), Vector3.new(55.5, 20.5, 8.7) },
	WarmingHut = { Vector3.new(25, 16.5, 9) },
	SummitLodge = { Vector3.new(14.4, 39, 14), Vector3.new(57.6, 39, 14) },
}

export type Options = {
	parent: Instance,
	plan: any,
	world: any,
	getStation: () -> number,
	getFocus: (() -> { Vector3 })?,
}

export type Stats = {
	world: string,
	running: boolean,
	reducedMotion: boolean,
	tumbleweeds: number,
	flock: number,
	dustDevil: boolean,
	dustDevilOn: boolean,
	snowOn: boolean,
	smokeEmitters: number,
	smokeOn: number,
	parts: number,
}

type Tumbleweed = { part: Part, station: number, side: number, speed: number, phase: number, angle: number }
type Bird = { left: BasePart, right: BasePart, body: BasePart, offset: Vector3, phase: number }
type Smoke = { emitter: ParticleEmitter, part: Part }
-- World build V2: skaters on the lake (two loops), chairs on the lift's far legs (never over the road), a re-homing smoke pool
type Skater = { body: Part, head: Part, loop: number, phase: number, speed: number }
type Chair = { seat: Part, hanger: Part, leg: number, u: number, dir: number, speed: number }
type Loop = { centre: CFrame, radiusX: number, radiusZ: number }
type Leg = { points: { Vector3 }, length: number }
type Skier = { body: Part, skis: Part, route: number, u: number, offset: number, speed: number }
-- World build V2 (Dusty): the windmill wheel (0.1 turns per second), two pennant strings of eight, a far shimmer strip
type Wheel = { hub: Vector3, normal: Vector3, radius: number, blades: { Part }, hubPart: Part }
type PennantString = { a: Vector3, b: Vector3, flags: { Part }, poles: { Part } }
type Shimmer = { part: Part, base: CFrame }

type Fields = {
	id: string,
	plan: any,
	folder: Folder,
	trove: any,
	getStation: () -> number,
	getFocus: () -> { Vector3 },
	tumbleweeds: { Tumbleweed },
	flock: { Bird },
	flockSize: number,
	flockColour: Color3,
	devil: Part?,
	devilEmitter: ParticleEmitter?,
	snow: Part?,
	snowEmitter: ParticleEmitter?,
	smoke: { Smoke },
	chimneys: { Vector3 }, -- every candidate chimney top in the plan (V2): the smoke pool re-homes to the nearest ones
	skaters: { Skater },
	loops: { Loop },
	chairs: { Chair },
	legs: { Leg },
	skiers: { Skier },
	skiRoutes: { Leg },
	wheels: { Wheel },
	strings: { PennantString },
	shimmers: { Shimmer },
	reduced: boolean,
	clock: number,
	accumulator: number,
	rng: Random,
	running: boolean,
}

export type WorldLife = typeof(setmetatable({} :: Fields, WorldLife))

local function defaultFocus(): { Vector3 }
	local camera = Workspace.CurrentCamera
	return if camera then { camera.CFrame.Position } else {}
end

local function nearest(points: { Vector3 }, at: Vector3): number
	local best = math.huge
	for _, p in points do
		best = math.min(best, (p - at).Magnitude)
	end
	return best
end

local function emitter(parent: Instance, name: string): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.Name = name
	e.Texture = "rbxasset://textures/particles/smoke_main.dds"
	e.LightInfluence = 1
	e.Enabled = false
	e.Parent = parent
	return e
end

local function anchoredPart(parent: Instance, name: string, size: Vector3): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.CastShadow = false
	p.Transparency = 1
	p.CFrame = CFrame.new(0, -500, 0)
	p.Parent = parent
	return p
end

function WorldLife.new(options: Options): WorldLife
	local trove = Trove.new()
	local folder = Instance.new("Folder")
	folder.Name = "WorldLife"
	folder:SetAttribute("Note", "Lane 3 World ambient life (preview, bounded, off-road)")
	folder.Parent = options.parent
	trove:Add(folder)
	local id: string = options.world.id
	local self: Fields = {
		id = id,
		plan = options.plan,
		folder = folder,
		trove = trove,
		getStation = options.getStation,
		getFocus = options.getFocus or defaultFocus,
		tumbleweeds = {},
		flock = {},
		flockSize = 0,
		flockColour = Color3.fromRGB(70, 76, 92),
		devil = nil,
		devilEmitter = nil,
		snow = nil,
		snowEmitter = nil,
		smoke = {},
		chimneys = {},
		skaters = {},
		loops = {},
		chairs = {},
		legs = {},
		skiers = {},
		skiRoutes = {},
		wheels = {},
		strings = {},
		shimmers = {},
		reduced = Util.reducedMotion(),
		clock = 0,
		accumulator = 0,
		rng = Random.new(options.plan.seed + 77),
		running = false,
	}
	local obj = setmetatable(self, WorldLife)
	if id == "DustyHighway" then
		for i = 1, 4 do
			local p = Parts.block(
				folder,
				"Tumbleweed",
				Vector3.new(3.6, 3.6, 3.6),
				CFrame.new(0, -500, 0),
				Color3.fromRGB(158, 120, 82),
				Enum.PartType.Ball
			)
			p.Material = Enum.Material.Fabric
			p.CastShadow = false
			table.insert(self.tumbleweeds, {
				part = p,
				station = -1000,
				side = if i % 2 == 0 then 1 else -1,
				speed = 7 + i * 1.3,
				phase = i * 1.7,
				angle = 0,
			})
		end
		self.flockSize = 3
		self.flockColour = Color3.fromRGB(76, 56, 44)
		local devil = anchoredPart(folder, "DustDevil", Vector3.new(6, 1, 6))
		local att = Instance.new("Attachment")
		att.Parent = devil
		local e = emitter(att, "DustColumn")
		e.Rate = 10
		e.Lifetime = NumberRange.new(3, 4.5)
		e.Speed = NumberRange.new(13, 18)
		e.EmissionDirection = Enum.NormalId.Top
		e.SpreadAngle = Vector2.new(7, 7)
		e.Rotation = NumberRange.new(0, 360)
		e.RotSpeed = NumberRange.new(-70, 70)
		e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 3), NumberSequenceKeypoint.new(1, 15) })
		e.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.75),
			NumberSequenceKeypoint.new(0.5, 0.82),
			NumberSequenceKeypoint.new(1, 1),
		})
		e.Color = ColorSequence.new(Color3.fromRGB(226, 190, 140))
		self.devil, self.devilEmitter = devil, e
	elseif id == "SummitPass" then
		self.flockSize = 5
		self.flockColour = Color3.fromRGB(60, 70, 96)
		local snow = anchoredPart(folder, "SnowEmitter", Vector3.new(80, 1, 80))
		local att = Instance.new("Attachment")
		att.Parent = snow
		local e = emitter(att, "Snow")
		e.Shape = Enum.ParticleEmitterShape.Box
		e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
		e.EmissionDirection = Enum.NormalId.Bottom
		e.Rate = 26
		e.Lifetime = NumberRange.new(5, 7)
		e.Speed = NumberRange.new(4, 7)
		e.SpreadAngle = Vector2.new(15, 15)
		e.Acceleration = Vector3.new(1.2, 0, 0.4)
		e.Size = NumberSequence.new(0.4)
		e.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.2),
			NumberSequenceKeypoint.new(0.85, 0.3),
			NumberSequenceKeypoint.new(1, 1),
		})
		e.Color = ColorSequence.new(Color3.fromRGB(252, 253, 255))
		self.snow, self.snowEmitter = snow, e
		for _, lm in options.plan.landmarks do
			local spots = SMOKE[lm.id]
			if spots and lm.placement ~= "bridge" and not options.world.v2 then
				for _, spot in spots do
					if #self.smoke < 5 then
						local part = anchoredPart(folder, "ChimneyOrigin", Vector3.new(1, 1, 1))
						part.CFrame = lm.pivot * CFrame.new(spot)
						local a2 = Instance.new("Attachment")
						a2.Parent = part
						local s = emitter(a2, "ChimneySmoke")
						s.Rate = 4
						s.Lifetime = NumberRange.new(3, 4.5)
						s.Speed = NumberRange.new(2, 3)
						s.EmissionDirection = Enum.NormalId.Top
						s.SpreadAngle = Vector2.new(10, 10)
						s.Acceleration = Vector3.new(0.5, 0.4, 0)
						s.Rotation = NumberRange.new(0, 360)
						s.Size =
							NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 4) })
						s.Transparency = NumberSequence.new({
							NumberSequenceKeypoint.new(0, 0.55),
							NumberSequenceKeypoint.new(0.4, 0.7),
							NumberSequenceKeypoint.new(1, 1),
						})
						s.Color = ColorSequence.new(Color3.fromRGB(238, 242, 248))
						table.insert(self.smoke, { emitter = s, part = part })
					end
				end
			end
		end
	end
	if id == "DustyHighway" and options.world.v2 and options.plan.world and options.plan.world.motion then
		-- World build V2 (decision 0026): the approved Dusty motion, within its limits: one windmill wheel (0.1 turns per
		-- second, on within 600 studs), at most two pennant strings of eight (sway about 6 degrees at 0.4 Hz, on within 350
		-- studs, parallel to the road and never over it) and one far shimmer strip (alpha drift at most 0.4 Hz, within 900)
		local motion = options.plan.world.motion
		for _, w in motion.windmills do
			local hubPart = Parts.block(
				folder,
				"WheelHub",
				Vector3.new(1.8, 1.8, 1.8),
				CFrame.new(0, -500, 0),
				Color3.fromRGB(88, 94, 104),
				Enum.PartType.Ball
			)
			hubPart.CastShadow = false
			local blades: { Part } = {}
			for k = 1, 10 do
				local blade = Parts.block(
					folder,
					"WheelSail",
					Vector3.new(0.3, w.radius * 0.72, 2.2),
					CFrame.new(0, -500, 0),
					if k % 2 == 0 then Color3.fromRGB(160, 92, 56) else Color3.fromRGB(150, 156, 164)
				)
				blade.CastShadow = false
				table.insert(blades, blade)
			end
			table.insert(
				self.wheels,
				{ hub = w.hub, normal = w.normal, radius = w.radius, blades = blades, hubPart = hubPart }
			)
		end
		for _, s in motion.pennants do
			local flags: { Part } = {}
			for k = 1, 8 do
				local flag = Parts.block(
					folder,
					"Pennant",
					Vector3.new(1.6, 1.2, 0.1),
					CFrame.new(0, -500, 0),
					if k % 2 == 0 then Color3.fromRGB(206, 84, 70) else Color3.fromRGB(54, 176, 170)
				)
				flag.CastShadow = false
				table.insert(flags, flag)
			end
			local poles: { Part } = {}
			for _, at in { s.a, s.b } do
				local pole = Parts.block(
					folder,
					"PennantPole",
					Vector3.new(0.4, at.Y, 0.4),
					CFrame.new(at.X, at.Y / 2, at.Z),
					Color3.fromRGB(120, 76, 54)
				)
				pole.CastShadow = false
				table.insert(poles, pole)
			end
			table.insert(self.strings, { a = s.a, b = s.b, flags = flags, poles = poles })
		end
		for _, sh in motion.shimmers do
			local part = Parts.block(
				folder,
				"ShimmerStrip",
				Vector3.new(sh.length, 0.1, sh.width),
				sh.cframe,
				Color3.fromRGB(206, 216, 232)
			)
			part.CastShadow = false
			part.Transparency = 0.55
			part.Material = Enum.Material.SmoothPlastic
			table.insert(self.shimmers, { part = part, base = sh.cframe })
		end
	end
	if id == "SummitPass" and options.world.v2 then
		-- World build V2 (decision 0026): a smoke pool of five that re-homes to the nearest chimneys (plan 5.9), skaters on
		-- two loops on the lake, and chairs that move only on the lift's far legs, never over the road (Option M is a proposal)
		-- the chimney tops come from the kit meshes' roof_a sockets (WorldPlan reads them), already in world space
		for _, p in if options.plan.world then options.plan.world.chimneys or {} else {} do
			table.insert(self.chimneys, p)
		end
		for _ = 1, 5 do
			local part = anchoredPart(folder, "ChimneyOrigin", Vector3.new(1, 1, 1))
			local a2 = Instance.new("Attachment")
			a2.Parent = part
			local s = emitter(a2, "ChimneySmoke")
			s.Rate = 4
			s.Lifetime = NumberRange.new(3, 4.5)
			s.Speed = NumberRange.new(2, 3)
			s.EmissionDirection = Enum.NormalId.Top
			s.SpreadAngle = Vector2.new(10, 10)
			s.Acceleration = Vector3.new(0.5, 0.4, 0)
			s.Rotation = NumberRange.new(0, 360)
			s.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 4) })
			s.Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.55),
				NumberSequenceKeypoint.new(0.4, 0.7),
				NumberSequenceKeypoint.new(1, 1),
			})
			s.Color = ColorSequence.new(Color3.fromRGB(238, 242, 248))
			table.insert(self.smoke, { emitter = s, part = part })
		end
		local world = options.plan.world
		local bunting = { Color3.fromRGB(70, 170, 170), Color3.fromRGB(204, 72, 66), Color3.fromRGB(242, 190, 78) }
		for _, lake in if world then world.lake or {} else {} do
			local mid = (lake.nearEdge + lake.farEdge) / 2
			local across = lake.farEdge - lake.nearEdge
			for k, spec in { { 0.3, 0.32, 0.9 }, { 0.7, 0.26, 0.7 } } do
				local lateral = mid + (spec[1] - 0.5) * across
				local centre = Route.frame(
					options.plan.segments,
					lake.station + (k - 1.5) * lake.along * 0.3,
					lake.side * lateral,
					2
				)
				table.insert(
					self.loops,
					{ centre = centre, radiusX = lake.along * spec[2], radiusZ = across * 0.12 * spec[3] }
				)
				for i = 1, 3 do
					local body = Parts.block(
						folder,
						"Skater",
						Vector3.new(1, 2.6, 1),
						CFrame.new(0, -500, 0),
						bunting[(i + k) % 3 + 1]
					)
					local head = Parts.block(
						folder,
						"SkaterHead",
						Vector3.new(0.9, 0.9, 0.9),
						CFrame.new(0, -500, 0),
						Color3.fromRGB(240, 214, 190),
						Enum.PartType.Ball
					)
					body.CastShadow, head.CastShadow = false, false
					table.insert(
						self.skaters,
						{ body = body, head = head, loop = #self.loops, phase = i * 2.1 + k, speed = 0.07 + 0.02 * i }
					)
				end
			end
		end
		for _, lift in if world then world.lift or {} else {} do
			for _, leg in lift.legs or {} do
				local points: { Vector3 } = leg
				if #points >= 2 then
					local length = 0
					for i = 1, #points - 1 do
						length += (points[i + 1] - points[i]).Magnitude
					end
					table.insert(self.legs, { points = points, length = length })
				end
			end
		end
		if #self.legs > 0 then
			for i = 1, 6 do
				local seat = Parts.block(
					folder,
					"ChairSeat",
					Vector3.new(3, 0.5, 2.2),
					CFrame.new(0, -500, 0),
					if i % 2 == 0 then Color3.fromRGB(204, 72, 66) else Color3.fromRGB(70, 170, 170)
				)
				local hanger = Parts.block(
					folder,
					"ChairHanger",
					Vector3.new(0.3, 4, 0.3),
					CFrame.new(0, -500, 0),
					Color3.fromRGB(60, 62, 70)
				)
				seat.CastShadow, hanger.CastShadow = false, false
				table.insert(self.chairs, {
					seat = seat,
					hanger = hanger,
					leg = (i - 1) % #self.legs + 1,
					u = ((i - 1) // #self.legs) * 0.3 + 0.1,
					dir = if i % 2 == 0 then 1 else -1,
					speed = 3,
				})
			end
		end
	end
	if id == "SummitPass" and options.world.v2 and options.plan.world and options.plan.world.skiPaths then
		-- up to eight distant skiers (two parts each) running down the ski glades' centre lines, 120+ studs from the road,
		-- colours from the bunting set (never orange); at rest in reduced motion
		local colours = {
			Color3.fromRGB(70, 170, 170),
			Color3.fromRGB(204, 72, 66),
			Color3.fromRGB(242, 190, 78),
			Color3.fromRGB(52, 112, 84),
		}
		local made = 0
		for _, path in options.plan.world.skiPaths do
			local length = 0
			for i = 1, #path.points - 1 do
				length += (path.points[i + 1] - path.points[i]).Magnitude
			end
			table.insert(self.skiRoutes, { points = path.points, length = length })
			for k = 1, 4 do
				if made < 8 then
					made += 1
					local body =
						Parts.block(folder, "Skier", Vector3.new(0.9, 2.8, 0.9), CFrame.new(0, -500, 0), colours[k])
					local skis = Parts.block(
						folder,
						"Skis",
						Vector3.new(1.1, 0.2, 4.2),
						CFrame.new(0, -500, 0),
						Color3.fromRGB(60, 62, 70)
					)
					body.CastShadow, skis.CastShadow = false, false
					table.insert(
						self.skiers,
						{
							body = body,
							skis = skis,
							route = #self.skiRoutes,
							u = (k - 1) / 4,
							offset = (k - 2.5) * 4,
							speed = 6 + k,
						}
					)
				end
			end
		end
	end
	for i = 1, self.flockSize do
		local span = if id == "DustyHighway" then 5.2 else 1.6
		local left = Parts.block(folder, "Wing", Vector3.new(span, 0.12, 1.4), CFrame.new(0, -500, 0), self.flockColour)
		local right =
			Parts.block(folder, "Wing", Vector3.new(span, 0.12, 1.4), CFrame.new(0, -500, 0), self.flockColour)
		local body = Parts.block(folder, "Body", Vector3.new(0.7, 0.5, 2.4), CFrame.new(0, -500, 0), self.flockColour)
		left.CastShadow, right.CastShadow, body.CastShadow = false, false, false
		local row = math.ceil((i - 1) / 2)
		local side = if i % 2 == 0 then 1 else -1
		table.insert(self.flock, {
			left = left,
			right = right,
			body = body,
			offset = Vector3.new(side * row * 6, (i % 3) * 2, row * 6.5),
			phase = i * 0.8,
		})
	end
	local function refresh()
		self.reduced = Util.reducedMotion()
		local snow = self.snowEmitter
		if snow then
			snow.Rate = if self.reduced then 8 else 26
			snow.Speed = if self.reduced then NumberRange.new(2, 3.5) else NumberRange.new(4, 7)
		end
		for _, s in self.smoke do
			s.emitter.Rate = if self.reduced then 1.5 else 4
		end
	end
	for _, signal in Util.reducedMotionSignals() do
		trove:Connect(signal, refresh)
	end
	refresh()
	return obj
end

local function rehome(self: Fields, w: Tumbleweed, station: number)
	w.station = station + 90 + self.rng:NextNumber(0, AHEAD - 120)
	w.side = if self.rng:NextNumber() < 0.5 then -1 else 1
end

function WorldLife.step(self: WorldLife, dt: number)
	local station = self.getStation()
	local points = self.getFocus()
	local plan = self.plan
	local segments = plan.segments
	self.clock += dt
	self.accumulator += dt
	local reduced = self.reduced
	local lateral = plan.halfRoad + (plan.kerb or 0.8) + 6
	for _, w in self.tumbleweeds do
		if w.station < station - BEHIND or w.station > station + AHEAD + 60 then
			rehome(self, w, station)
		end
		-- World build V2: a tumbleweed never rolls onto a bridge deck (with a true gorge it would roll on air beside the deck)
		local under = segments[Route.find(segments, w.station)]
		if under and under.kind == "BridgeDeck" then
			w.station = under.endS + 30
		end
		if not reduced then
			w.station += w.speed * dt
			w.angle += w.speed * dt / 1.8
		end
		local hop = if reduced then 0 else math.abs(math.sin(self.clock * 3.1 + w.phase)) * 1.4
		local at = Route.point(segments, w.station, w.side * lateral, 1.9 + hop)
		w.part.CFrame = CFrame.new(at) * CFrame.Angles(w.angle, 0.3 * w.phase, 0)
	end
	if self.accumulator < 0.1 then
		return
	end
	self.accumulator = 0
	if #self.flock > 0 then
		local centre = Route.point(
			segments,
			station + 300,
			if self.id == "DustyHighway" then 190 else -170,
			if self.id == "DustyHighway" then 110 else 95
		)
		if nearest(points, centre) <= SKY_NEAR then
			local turn = self.clock * (if reduced then 0.04 else 0.1)
			local radius = if self.id == "DustyHighway" then 90 else 70
			local lead = centre + Vector3.new(math.cos(turn), 0, math.sin(turn)) * radius
			local heading = Vector3.new(-math.sin(turn), 0, math.cos(turn))
			local frame = CFrame.lookAt(lead, lead + heading)
			local list, cfs = {}, {}
			local half = if self.id == "DustyHighway" then 2.8 else 0.9
			for _, b in self.flock do
				local flap = if reduced
					then 0.1
					else 0.1 + math.max(
						0,
						math.sin(self.clock * (if self.id == "DustyHighway" then 3 else 9) + b.phase)
					) * 0.35
				local at = frame * CFrame.new(b.offset)
				table.insert(list, b.left)
				table.insert(cfs, at * CFrame.Angles(0, 0, flap) * CFrame.new(-half, 0, 0))
				table.insert(list, b.right)
				table.insert(cfs, at * CFrame.Angles(0, 0, -flap) * CFrame.new(half, 0, 0))
				table.insert(list, b.body)
				table.insert(cfs, at)
			end
			Workspace:BulkMoveTo(list, cfs, Enum.BulkMoveMode.FireCFrameChanged)
		end
	end
	local devil, devilEmitter = self.devil, self.devilEmitter
	if devil and devilEmitter then
		local drift = math.sin(self.clock * 0.03) * 70
		local at = Route.point(segments, station + 520, 420 + drift, 1)
		devil.CFrame = CFrame.new(at)
		devilEmitter.Enabled = not reduced and nearest(points, at) <= SKY_NEAR
	end
	local snow, snowEmitter = self.snow, self.snowEmitter
	if snow and snowEmitter then
		local focus = points[1]
		if focus then
			snow.CFrame = CFrame.new(focus + Vector3.new(0, 40, 0))
		end
		snowEmitter.Enabled = focus ~= nil
	end
	-- World build V2: the smoke pool of five re-homes to the nearest chimneys within NEAR of the camera
	local focus0 = points[1]
	if #self.chimneys > 0 and #self.smoke > 0 and focus0 then
		local order: { { d: number, p: Vector3 } } = {}
		for _, p in self.chimneys do
			local d = (p - focus0).Magnitude
			if d <= NEAR then
				table.insert(order, { d = d, p = p })
			end
		end
		table.sort(order, function(a, b)
			return a.d < b.d
		end)
		local chosen: { Vector3 } = {}
		for i = 1, math.min(#self.smoke, #order) do
			table.insert(chosen, order[i].p)
		end
		local function has(list: { { emitter: ParticleEmitter, part: Part } }, p: Vector3): boolean
			for _, s in list do
				if (s.part.Position - p).Magnitude < 0.5 then
					return true
				end
			end
			return false
		end
		local free: { Vector3 } = {}
		for _, p in chosen do
			if not has(self.smoke, p) then
				table.insert(free, p)
			end
		end
		for _, s in self.smoke do
			local keep = false
			for _, p in chosen do
				if (s.part.Position - p).Magnitude < 0.5 then
					keep = true
					break
				end
			end
			if not keep then
				s.part.CFrame = CFrame.new(table.remove(free) or Vector3.new(0, -500, 0))
			end
		end
	end
	for _, s in self.smoke do
		s.emitter.Enabled = nearest(points, s.part.Position) <= NEAR
	end
	-- Summit (V2): distant skiers on the glades, at rest in reduced motion
	if #self.skiers > 0 then
		local list: { BasePart }, cfs: { CFrame } = {}, {}
		for _, sk in self.skiers do
			local route = self.skiRoutes[sk.route]
			if not reduced then
				sk.u = (sk.u + sk.speed * 0.1 / route.length) % 1
			end
			local want = (1 - sk.u) * route.length
			local p = route.points[#route.points]
			local dir = Vector3.new(0, -0.3, -1)
			for i = 1, #route.points - 1 do
				local seg = (route.points[i + 1] - route.points[i]).Magnitude
				if want <= seg then
					p = route.points[i]:Lerp(route.points[i + 1], want / math.max(seg, 1e-3))
					dir = -(route.points[i + 1] - route.points[i]).Unit
					break
				end
				want -= seg
			end
			if nearest(points, p) <= SKY_NEAR then
				local side = dir:Cross(Vector3.yAxis).Unit
				local at = p + side * sk.offset + Vector3.new(0, 1.6, 0)
				local facing = CFrame.lookAt(at, at + dir)
				table.insert(list, sk.body)
				table.insert(cfs, facing)
				table.insert(list, sk.skis)
				table.insert(cfs, facing * CFrame.new(0, -1.5, 0))
			end
		end
		if #list > 0 then
			Workspace:BulkMoveTo(list, cfs, Enum.BulkMoveMode.FireCFrameChanged)
		end
	end
	-- Dusty (V2): the windmill wheel, the pennant strings and the shimmer strip
	for _, w in self.wheels do
		if nearest(points, w.hub) <= 600 then
			local angle = if reduced then 0 else self.clock * 0.1 * math.pi * 2
			local n = w.normal
			local up = (Vector3.yAxis - n * n:Dot(Vector3.yAxis)).Unit
			local side = n:Cross(up)
			local list: { BasePart }, cfs: { CFrame } = { w.hubPart }, { CFrame.new(w.hub) }
			for k, blade in w.blades do
				local a = angle + (k - 1) * math.pi * 2 / #w.blades
				local d = up * math.cos(a) + side * math.sin(a)
				table.insert(list, blade)
				table.insert(cfs, CFrame.fromMatrix(w.hub + d * (w.radius * 0.5), n, d))
			end
			Workspace:BulkMoveTo(list, cfs, Enum.BulkMoveMode.FireCFrameChanged)
		end
	end
	for _, s in self.strings do
		if nearest(points, (s.a + s.b) / 2) <= 350 then
			local list: { BasePart }, cfs: { CFrame } = {}, {}
			local dir = (s.b - s.a).Unit
			local across = dir:Cross(Vector3.yAxis).Unit
			for k, flag in s.flags do
				local u = (k - 0.5) / #s.flags
				local sway = if reduced then 0 else math.rad(6) * math.sin(self.clock * 0.4 * math.pi * 2 + k * 0.7)
				local p = s.a:Lerp(s.b, u) - Vector3.new(0, 2.4 * u * (1 - u) * 4 + 0.7, 0)
				table.insert(list, flag)
				table.insert(cfs, CFrame.lookAt(p, p + across) * CFrame.Angles(sway, 0, 0))
			end
			Workspace:BulkMoveTo(list, cfs, Enum.BulkMoveMode.FireCFrameChanged)
		end
	end
	for _, sh in self.shimmers do
		sh.part.Transparency = if reduced or nearest(points, sh.base.Position) > 900
			then 0.6
			else 0.55 + 0.1 * math.sin(self.clock * 0.25 * math.pi * 2)
	end
	-- skaters: two loops on the lake, at rest in reduced motion
	if #self.skaters > 0 then
		local list: { BasePart }, cfs: { CFrame } = {}, {}
		for _, k in self.skaters do
			local loop = self.loops[k.loop]
			if nearest(points, loop.centre.Position) <= SKY_NEAR then
				local a = k.phase + (if reduced then 0 else self.clock * k.speed * math.pi * 2)
				local at = loop.centre * CFrame.new(math.cos(a) * loop.radiusX, 0, math.sin(a) * loop.radiusZ)
				local ahead = loop.centre
					* CFrame.new(math.cos(a + 0.05) * loop.radiusX, 0, math.sin(a + 0.05) * loop.radiusZ)
				local facing = CFrame.lookAt(at.Position, ahead.Position)
				table.insert(list, k.body)
				table.insert(cfs, facing)
				table.insert(list, k.head)
				table.insert(cfs, facing * CFrame.new(0, 1.7, 0))
			end
		end
		if #list > 0 then
			Workspace:BulkMoveTo(list, cfs, Enum.BulkMoveMode.FireCFrameChanged)
		end
	end
	-- lift chairs: only on the far legs (never over the road); at rest in reduced motion
	if #self.chairs > 0 then
		local list: { BasePart }, cfs: { CFrame } = {}, {}
		for _, c in self.chairs do
			local leg = self.legs[c.leg]
			if not reduced then
				c.u += c.dir * c.speed * 0.1 / leg.length
				if c.u >= 1 then
					c.u, c.dir = 1, -1
				elseif c.u <= 0 then
					c.u, c.dir = 0, 1
				end
			end
			local want = c.u * leg.length
			local p = leg.points[#leg.points]
			for i = 1, #leg.points - 1 do
				local seg = (leg.points[i + 1] - leg.points[i]).Magnitude
				if want <= seg then
					p = leg.points[i]:Lerp(leg.points[i + 1], want / math.max(seg, 1e-3))
					break
				end
				want -= seg
			end
			if nearest(points, p) <= SKY_NEAR then
				table.insert(list, c.hanger)
				table.insert(cfs, CFrame.new(p - Vector3.new(0, 2.2, 0)))
				table.insert(list, c.seat)
				table.insert(cfs, CFrame.new(p - Vector3.new(0, 4.6, 0)))
			end
		end
		if #list > 0 then
			Workspace:BulkMoveTo(list, cfs, Enum.BulkMoveMode.FireCFrameChanged)
		end
	end
end

function WorldLife.start(self: WorldLife)
	if self.running then
		return
	end
	self.running = true
	self.trove:Connect(RunService.Heartbeat, function(dt: number)
		if self.folder.Parent then
			self:step(dt)
		end
	end)
end

function WorldLife.stats(self: WorldLife): Stats
	local smokeOn, parts = 0, 0
	for _, s in self.smoke do
		if s.emitter.Enabled then
			smokeOn += 1
		end
	end
	for _, d in self.folder:GetDescendants() do
		if d:IsA("BasePart") then
			parts += 1
		end
	end
	local devilEmitter, snowEmitter = self.devilEmitter, self.snowEmitter
	return {
		world = self.id,
		running = self.running,
		reducedMotion = self.reduced,
		tumbleweeds = #self.tumbleweeds,
		flock = #self.flock,
		dustDevil = self.devil ~= nil,
		dustDevilOn = devilEmitter ~= nil and devilEmitter.Enabled,
		snowOn = snowEmitter ~= nil and snowEmitter.Enabled,
		smokeEmitters = #self.smoke,
		smokeOn = smokeOn,
		parts = parts,
	}
end

function WorldLife.destroy(self: WorldLife)
	self.running = false
	self.trove:Destroy()
end

return WorldLife
