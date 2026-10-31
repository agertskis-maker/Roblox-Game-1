--!strict
-- STREET LIFE for the Downtown B city preview (Lane 3). Bounded, off-road, reduced-motion aware;
-- patterns follow ../Ambient.luau (which stays unedited) but ride along the planned route:
--   pigeons  2 groups of 4 on the sidewalks at the plan's pigeon spots; they peck and hop, and
--            flutter away from the road when the camera or chase car comes within 22 studs
--   flags    up to 4 cloth Beams on poles at the plan's flag spots (City Hall, bridge towers,
--            district gateways)
--   carts    up to 2 food carts with a low-rate steam ParticleEmitter at the plan's cart spots
--   birds    one flock of 5 circling high over the midground ahead
--   blimp    one fictional blimp drifting along the skyline band ahead
-- Fixed pools re-home to the next planned spots as the station advances; nothing is created
-- per frame. Street-level accents only update within 250 studs of the camera (the sky accents
-- within 900). Reduced motion (GuiService.ReducedMotionEnabled or the preview-only
-- Lane3ReducedMotionOverride attribute): pigeons stay put, flags barely move, steam thins,
-- birds glide, the blimp holds still.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Parts = require(script.Parent.Parent.Parts)
local Proxies = require(script.Parent.Proxies)
local Route = require(script.Parent.Route)
local Sequencer = require(script.Parent.Sequencer)
local Util = require(script.Parent.Util)
local Trove = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Trove"))

local StreetLife = {}
StreetLife.__index = StreetLife

local NEAR = 250
local SKY_NEAR = 900
local FLEE_RADIUS = 22
local AHEAD = 450
local BEHIND = 60
local WIND = Vector3.new(1, 0, 0.35).Unit

export type Options = {
	parent: Instance,
	plan: Sequencer.Plan,
	getStation: () -> number,
	getFocus: (() -> { Vector3 })?, -- default: the current camera position
	pigeons: boolean?,
	flags: boolean?,
	carts: boolean?,
	birds: boolean?,
	blimp: boolean?,
}

export type Stats = {
	running: boolean,
	reducedMotion: boolean,
	pigeons: number,
	pigeonsVisible: number,
	flags: number,
	flagsPlaced: number,
	steamEmitters: number,
	steamOn: number,
	birds: number,
	blimp: boolean,
	parts: number,
}

type Pigeon = {
	parts: { BasePart },
	offsets: { CFrame },
	wings: { BasePart },
	home: CFrame,
	at: CFrame,
	outward: Vector3,
	state: string, -- idle | hop | flee | away
	t: number,
	nextHop: number,
	from: CFrame,
	to: CFrame,
}
type Group = { pigeons: { Pigeon }, spot: Sequencer.LifeSpot?, visible: boolean }
type Flag = { model: Model, beam: Beam, root: Attachment, tip: Attachment, spot: Sequencer.LifeSpot?, phase: number }
type Cart = { model: Model, emitter: ParticleEmitter, spot: Sequencer.LifeSpot? }
type Bird = { left: BasePart, right: BasePart, offset: Vector3, phase: number }

type Fields = {
	plan: Sequencer.Plan,
	folder: Folder,
	trove: any,
	getStation: () -> number,
	getFocus: () -> { Vector3 },
	groups: { Group },
	flags: { Flag },
	carts: { Cart },
	birds: { Bird },
	blimp: Model?,
	blimpDrift: number,
	reduced: boolean,
	clock: number,
	accumulator: number,
	rng: Random,
	running: boolean,
}

export type StreetLife = typeof(setmetatable({} :: Fields, StreetLife))

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

-- Pigeons ---------------------------------------------------------------------------------------

local function makePigeon(parent: Instance): Pigeon
	local grey = Color3.fromRGB(128, 132, 146)
	local list: { BasePart } = {}
	local offsets: { CFrame } = {}
	local function add(name: string, size: Vector3, offset: CFrame, colour: Color3, shape: Enum.PartType?): BasePart
		local p = Parts.block(parent, name, size, offset, colour, shape)
		p.CastShadow = false
		table.insert(list, p)
		table.insert(offsets, offset)
		return p
	end
	add("Body", Vector3.new(0.5, 0.5, 0.5), CFrame.new(0, 0.38, 0), grey, Enum.PartType.Ball)
	add(
		"Chest",
		Vector3.new(0.36, 0.36, 0.36),
		CFrame.new(0, 0.42, -0.2),
		Color3.fromRGB(112, 142, 150),
		Enum.PartType.Ball
	)
	add(
		"Head",
		Vector3.new(0.28, 0.28, 0.28),
		CFrame.new(0, 0.7, -0.3),
		Color3.fromRGB(100, 104, 120),
		Enum.PartType.Ball
	)
	add("Beak", Vector3.new(0.06, 0.06, 0.14), CFrame.new(0, 0.68, -0.48), Color3.fromRGB(232, 180, 120))
	add(
		"Tail",
		Vector3.new(0.26, 0.06, 0.34),
		CFrame.new(0, 0.36, 0.36) * CFrame.Angles(0.3, 0, 0),
		Color3.fromRGB(90, 94, 108)
	)
	local wings = {
		add("WingL", Vector3.new(0.5, 0.05, 0.34), CFrame.new(-0.18, 0.5, 0), Color3.fromRGB(104, 108, 124)),
		add("WingR", Vector3.new(0.5, 0.05, 0.34), CFrame.new(0.18, 0.5, 0), Color3.fromRGB(104, 108, 124)),
	}
	return {
		parts = list,
		offsets = offsets,
		wings = wings,
		home = CFrame.identity,
		at = CFrame.identity,
		outward = Vector3.xAxis,
		state = "idle",
		t = 0,
		nextHop = 1,
		from = CFrame.identity,
		to = CFrame.identity,
	}
end

local function posePigeon(p: Pigeon, flap: number)
	local cfs = table.create(#p.parts)
	for i, part in p.parts do
		local offset = p.offsets[i]
		if part == p.wings[1] then
			offset = CFrame.new(-0.18, 0.5, 0) * CFrame.Angles(0, 0, -flap) * CFrame.new(-0.2, 0, 0)
		elseif part == p.wings[2] then
			offset = CFrame.new(0.18, 0.5, 0) * CFrame.Angles(0, 0, flap) * CFrame.new(0.2, 0, 0)
		end
		cfs[i] = p.at * offset
	end
	Workspace:BulkMoveTo(p.parts, cfs, Enum.BulkMoveMode.FireCFrameChanged)
end

local function setVisible(parts: { BasePart }, visible: boolean)
	for _, part in parts do
		part.Transparency = if visible then 0 else 1
	end
end

local function updatePigeon(p: Pigeon, dt: number, near: number, reduced: boolean, rng: Random)
	p.t += dt
	if p.state == "idle" then
		if near < FLEE_RADIUS and not reduced then
			p.state, p.t = "flee", 0
			p.from = p.at
			local away = p.outward * 26 + Vector3.new(0, 16 + rng:NextNumber(0, 8), 0)
			p.to = CFrame.lookAt(p.at.Position + away, p.at.Position + away + p.outward)
		elseif not reduced and p.t >= p.nextHop then
			p.state, p.t = "hop", 0
			p.from = p.at
			-- hop within the sidewalk, never toward the road
			local jitter = Vector3.new(rng:NextNumber(-0.8, 0.8), 0, rng:NextNumber(-0.8, 0.8))
			local target = p.home.Position + jitter
			if (target - p.home.Position):Dot(p.outward) < -0.5 then
				target = p.home.Position
			end
			p.to = CFrame.new(target) * CFrame.Angles(0, rng:NextNumber(0, 2 * math.pi), 0)
		end
	elseif p.state == "hop" then
		local a = math.min(p.t / 0.32, 1)
		local lift = math.sin(a * math.pi) * 0.45
		p.at = p.from:Lerp(p.to, a) + Vector3.new(0, lift, 0)
		posePigeon(p, lift * 2)
		if a >= 1 then
			p.state, p.t = "idle", 0
			p.nextHop = 1.4 + rng:NextNumber(0, 2.6)
		end
		return
	elseif p.state == "flee" then
		local a = math.min(p.t / 2.2, 1)
		local eased = 1 - (1 - a) * (1 - a)
		p.at = p.from:Lerp(p.to, eased)
		posePigeon(p, math.sin(p.t * 28) * 0.9)
		if a >= 1 then
			p.state, p.t = "away", 0
			setVisible(p.parts, false)
		end
		return
	elseif p.state == "away" then
		return
	end
	local peck = if reduced then 0 else math.max(0, math.sin(p.t * 5)) * 0.12
	local cf = p.at
	p.at = cf * CFrame.Angles(-peck, 0, 0)
	posePigeon(p, 0)
	p.at = cf
end

local function homeGroup(group: Group, spot: Sequencer.LifeSpot, plan: Sequencer.Plan, rng: Random)
	group.spot = spot
	group.visible = true
	local road = Route.frame(plan.segments, spot.station)
	local outward = road.RightVector * spot.side
	for i, p in group.pigeons do
		local offset = Vector3.new(rng:NextNumber(-1.6, 1.6), 0, (i - 2.5) * 1.3)
		local position = spot.cframe:PointToWorldSpace(offset)
		p.home = CFrame.new(position) * CFrame.Angles(0, (i * 2.39) % (2 * math.pi), 0)
		p.at = p.home
		p.outward = outward
		p.state, p.t = "idle", 0
		p.nextHop = 1 + (i % 4) * 0.7
		setVisible(p.parts, true)
		posePigeon(p, 0)
	end
end

-- Flags -------------------------------------------------------------------------------------------

local FLAG_COLOURS = { Color3.fromRGB(40, 150, 150), Color3.fromRGB(255, 240, 214) }

local function makeFlag(parent: Instance, phase: number): Flag
	local model, pole = Proxies.flagpole()
	model.Parent = parent
	local normal = -WIND:Cross(Vector3.yAxis).Unit
	local root = Instance.new("Attachment")
	root.Name = "FlagRoot"
	root.Parent = pole
	local tip = Instance.new("Attachment")
	tip.Name = "FlagTip"
	tip.Parent = pole
	root.WorldCFrame = CFrame.fromMatrix(Vector3.new(0, 14.6, 0), normal, Vector3.yAxis)
	tip.WorldCFrame = CFrame.fromMatrix(Vector3.new(0, 14.6, 0) + WIND * 4.5, normal, Vector3.yAxis)
	local beam = Instance.new("Beam")
	beam.Name = "FlagCloth"
	beam.Attachment0 = root
	beam.Attachment1 = tip
	beam.FaceCamera = false
	beam.Segments = 12
	beam.Width0 = 2.6
	beam.Width1 = 2.6
	beam.LightInfluence = 1
	beam.Transparency = NumberSequence.new(0)
	beam.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, FLAG_COLOURS[1]),
		ColorSequenceKeypoint.new(0.49, FLAG_COLOURS[1]),
		ColorSequenceKeypoint.new(0.51, FLAG_COLOURS[2]),
		ColorSequenceKeypoint.new(1, FLAG_COLOURS[2]),
	})
	beam.Parent = model
	return { model = model, beam = beam, root = root, tip = tip, spot = nil, phase = phase }
end

-- Construction ----------------------------------------------------------------------------------

function StreetLife.new(options: Options): StreetLife
	local trove = Trove.new()
	local folder = Instance.new("Folder")
	folder.Name = "StreetLife"
	folder:SetAttribute("Note", "Lane 3 Downtown street life (preview, bounded, off-road)")
	folder.Parent = options.parent
	trove:Add(folder)
	local self: Fields = {
		plan = options.plan,
		folder = folder,
		trove = trove,
		getStation = options.getStation,
		getFocus = options.getFocus or defaultFocus,
		groups = {},
		flags = {},
		carts = {},
		birds = {},
		blimp = nil,
		blimpDrift = 0,
		reduced = Util.reducedMotion(),
		clock = 0,
		accumulator = 0,
		rng = Random.new(options.plan.seed + 31),
		running = false,
	}
	local obj = setmetatable(self, StreetLife)
	if options.pigeons ~= false then
		for _ = 1, 2 do
			local group: Group = { pigeons = {}, spot = nil, visible = false }
			for _ = 1, 4 do
				local model = Instance.new("Model")
				model.Name = "Pigeon"
				model.Parent = folder
				local p = makePigeon(model)
				setVisible(p.parts, false)
				table.insert(group.pigeons, p)
			end
			table.insert(self.groups, group)
		end
	end
	if options.flags ~= false then
		for i = 1, 4 do
			local flag = makeFlag(folder, i * 1.3)
			flag.model:PivotTo(CFrame.new(0, -500, 0))
			table.insert(self.flags, flag)
		end
	end
	if options.carts ~= false then
		for _ = 1, 2 do
			local model, body = Proxies.cart()
			model.Parent = folder
			local attachment = Instance.new("Attachment")
			attachment.Name = "SteamOrigin"
			attachment.Position = Vector3.new(0, 1.4, 0)
			attachment.Parent = body
			local e = Instance.new("ParticleEmitter")
			e.Name = "CartSteam"
			e.Texture = "rbxasset://textures/particles/smoke_main.dds"
			e.Rate = 3
			e.Lifetime = NumberRange.new(1.8, 2.8)
			e.Speed = NumberRange.new(0.8, 1.6)
			e.SpreadAngle = Vector2.new(12, 12)
			e.Acceleration = Vector3.new(0.3, 0.5, 0)
			e.Rotation = NumberRange.new(0, 360)
			e.RotSpeed = NumberRange.new(-20, 20)
			e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 1.8) })
			e.Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.6),
				NumberSequenceKeypoint.new(0.3, 0.7),
				NumberSequenceKeypoint.new(1, 1),
			})
			e.Color = ColorSequence.new(Color3.fromRGB(255, 252, 246))
			e.LightInfluence = 1
			e.Enabled = false
			e.Parent = attachment
			model:PivotTo(CFrame.new(0, -500, 0))
			table.insert(self.carts, { model = model, emitter = e, spot = nil })
		end
	end
	if options.birds ~= false then
		local colour = Color3.fromRGB(70, 76, 92)
		for i = 1, 5 do
			local left = Parts.block(folder, "BirdWing", Vector3.new(1.4, 0.1, 0.5), CFrame.new(0, -500, 0), colour)
			local right = Parts.block(folder, "BirdWing", Vector3.new(1.4, 0.1, 0.5), CFrame.new(0, -500, 0), colour)
			left.CastShadow, right.CastShadow = false, false
			local row = math.ceil((i - 1) / 2)
			local side = if i % 2 == 0 then 1 else -1
			table.insert(self.birds, {
				left = left,
				right = right,
				offset = Vector3.new(side * row * 3.2, (i % 3) * 1.2, row * 3.6),
				phase = i * 0.7,
			})
		end
	end
	if options.blimp ~= false then
		local m = Instance.new("Model")
		m.Name = "Blimp"
		m:SetAttribute("Proxy", "fictional blimp (street life)")
		local hull = Color3.fromRGB(250, 246, 236)
		local band = Color3.fromRGB(30, 42, 74)
		Parts.block(m, "Hull", Vector3.new(30, 12, 12), CFrame.Angles(0, math.pi / 2, 0), hull, Enum.PartType.Cylinder)
		Parts.block(m, "Nose", Vector3.new(12, 12, 12), CFrame.new(0, 0, -15), hull, Enum.PartType.Ball)
		Parts.block(m, "Tail", Vector3.new(11, 11, 11), CFrame.new(0, 0, 15), hull, Enum.PartType.Ball)
		Parts.block(m, "Gondola", Vector3.new(3, 2, 7), CFrame.new(0, -6.6, -2), band)
		Parts.block(m, "FinV", Vector3.new(0.4, 6, 4), CFrame.new(0, 5, 19), Color3.fromRGB(40, 150, 150))
		for _, d in m:GetDescendants() do
			if d:IsA("BasePart") then
				d.CastShadow = false
			end
		end
		m.WorldPivot = CFrame.identity
		m.Parent = folder
		self.blimp = m
	end
	local function refresh()
		self.reduced = Util.reducedMotion()
		for _, c in self.carts do
			c.emitter.Rate = if self.reduced then 1.2 else 3
			c.emitter.Speed = if self.reduced then NumberRange.new(0.4, 0.8) else NumberRange.new(0.8, 1.6)
		end
	end
	for _, signal in Util.reducedMotionSignals() do
		trove:Connect(signal, refresh)
	end
	refresh()
	return obj
end

-- Spot assignment ----------------------------------------------------------------------------------

local function assign(self: StreetLife, station: number)
	local plan = self.plan
	local taken: { [Sequencer.LifeSpot]: boolean } = {}
	local function stale(spot: Sequencer.LifeSpot?): boolean
		return spot == nil or spot.station < station - BEHIND or spot.station > station + AHEAD
	end
	for _, g in self.groups do
		if not stale(g.spot) then
			taken[g.spot :: Sequencer.LifeSpot] = true
		end
	end
	for _, f in self.flags do
		if not stale(f.spot) then
			taken[f.spot :: Sequencer.LifeSpot] = true
		end
	end
	for _, c in self.carts do
		if not stale(c.spot) then
			taken[c.spot :: Sequencer.LifeSpot] = true
		end
	end
	local function nextSpot(kind: string): Sequencer.LifeSpot?
		for _, spot in plan.life do
			if spot.kind == kind and not taken[spot] and not stale(spot) then
				taken[spot] = true
				return spot
			end
		end
		return nil
	end
	for _, g in self.groups do
		if stale(g.spot) then
			local spot = nextSpot("pigeons")
			if spot then
				homeGroup(g, spot, plan, self.rng)
			elseif g.visible then
				g.spot = nil
				g.visible = false
				for _, p in g.pigeons do
					setVisible(p.parts, false)
				end
			end
		end
	end
	for _, f in self.flags do
		if stale(f.spot) then
			local spot = nextSpot("flag")
			f.spot = spot
			f.model:PivotTo(if spot then CFrame.new(spot.cframe.Position) else CFrame.new(0, -500, 0))
		end
	end
	for _, c in self.carts do
		if stale(c.spot) then
			local spot = nextSpot("cart")
			c.spot = spot
			c.model:PivotTo(if spot then spot.cframe else CFrame.new(0, -500, 0))
			c.emitter.Enabled = spot ~= nil
		end
	end
end

function StreetLife.step(self: StreetLife, dt: number)
	local station = self.getStation()
	local points = self.getFocus()
	self.clock += dt
	self.accumulator += dt
	local reduced = self.reduced
	for _, g in self.groups do
		if g.visible then
			for _, p in g.pigeons do
				local near = nearest(points, p.at.Position)
				if near <= NEAR or p.state ~= "idle" then
					updatePigeon(p, dt, near, reduced, self.rng)
				end
			end
		end
	end
	local amp = if reduced then 0.25 else 0.8
	local speed = if reduced then 1 else 2.4
	for _, f in self.flags do
		if f.spot and nearest(points, f.root.WorldPosition) <= NEAR then
			f.beam.CurveSize0 = amp * math.sin(self.clock * speed + f.phase)
			f.beam.CurveSize1 = amp * 1.4 * math.sin(self.clock * speed + f.phase + 1.6)
		end
	end
	if self.accumulator < 0.1 then
		return
	end
	local step = self.accumulator
	self.accumulator = 0
	assign(self, station)
	for _, c in self.carts do
		if c.spot then
			c.emitter.Enabled = nearest(points, c.model:GetPivot().Position) <= NEAR
		end
	end
	local segments = self.plan.segments
	if #self.birds > 0 then
		local centre = Route.point(segments, station + 260, -170, 95)
		if nearest(points, centre) <= SKY_NEAR then
			local turn = self.clock * (if reduced then 0.05 else 0.11)
			local lead = centre + Vector3.new(math.cos(turn), 0, math.sin(turn)) * 70
			local heading = Vector3.new(-math.sin(turn), 0, math.cos(turn))
			local frame = CFrame.lookAt(lead, lead + heading)
			local list, cfs = {}, {}
			for _, b in self.birds do
				local flap = if reduced then 0.12 else 0.12 + math.max(0, math.sin(self.clock * 9 + b.phase)) * 0.5
				local at = frame * CFrame.new(b.offset)
				table.insert(list, b.left)
				table.insert(cfs, at * CFrame.Angles(0, 0, flap) * CFrame.new(-0.7, 0, 0))
				table.insert(list, b.right)
				table.insert(cfs, at * CFrame.Angles(0, 0, -flap) * CFrame.new(0.7, 0, 0))
			end
			Workspace:BulkMoveTo(list, cfs, Enum.BulkMoveMode.FireCFrameChanged)
		end
	end
	if self.blimp then
		if not reduced then
			self.blimpDrift = (self.blimpDrift + step * 4) % 400
		end
		self.blimp:PivotTo(Route.frame(segments, station + 600 + self.blimpDrift - 200, 430, 170))
	end
end

function StreetLife.start(self: StreetLife)
	if self.running then
		return
	end
	self.running = true
	assign(self, self.getStation())
	self.trove:Connect(RunService.Heartbeat, function(dt: number)
		if self.folder.Parent then
			self:step(dt)
		end
	end)
end

function StreetLife.stats(self: StreetLife): Stats
	local visible, placed, steamOn, parts = 0, 0, 0, 0
	local pigeons = 0
	for _, g in self.groups do
		pigeons += #g.pigeons
		if g.visible then
			visible += #g.pigeons
		end
	end
	for _, f in self.flags do
		if f.spot then
			placed += 1
		end
	end
	for _, c in self.carts do
		if c.emitter.Enabled then
			steamOn += 1
		end
	end
	for _, d in self.folder:GetDescendants() do
		if d:IsA("BasePart") then
			parts += 1
		end
	end
	return {
		running = self.running,
		reducedMotion = self.reduced,
		pigeons = pigeons,
		pigeonsVisible = visible,
		flags = #self.flags,
		flagsPlaced = placed,
		steamEmitters = #self.carts,
		steamOn = steamOn,
		birds = #self.birds,
		blimp = self.blimp ~= nil,
		parts = parts,
	}
end

function StreetLife.destroy(self: StreetLife)
	self.running = false
	self.trove:Destroy()
end

return StreetLife
