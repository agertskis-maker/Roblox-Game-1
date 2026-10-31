--!strict
-- Test scenery for the Lane 1 run prototype: an endless sunny canyon highway streamed in ahead and
-- recycled behind (asphalt, lane markings, rumble strips, guard rails, grass verges, trees,
-- boulders and stepped rock walls). Lane 3 owns the real World looks (Adam's Downtown kit and the
-- other Worlds); this only gives the driving a readable, good-looking place to be judged in.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RunConfig = require(ReplicatedStorage.Shared.Run.RunConfig)
local Trove = require(ReplicatedStorage.Packages.Trove)

local RunRoad = {}
RunRoad.__index = RunRoad

local SEGMENT = 200
local AHEAD = 1100
local BEHIND = 220
local DASH = 12
local DASH_GAP = 24

local ASPHALT = Color3.fromRGB(64, 68, 78)
local SHOULDER = Color3.fromRGB(122, 124, 132)
local PAINT = Color3.fromRGB(246, 246, 238)
local YELLOW = Color3.fromRGB(250, 206, 60)
local RUMBLE_A = Color3.fromRGB(236, 72, 64)
local RUMBLE_B = Color3.fromRGB(246, 246, 238)
local GRASS = Color3.fromRGB(116, 190, 92)
local SAND = Color3.fromRGB(232, 196, 140)
local ROCK: { Color3 } = {
	Color3.fromRGB(214, 128, 82),
	Color3.fromRGB(226, 150, 96),
	Color3.fromRGB(198, 112, 74),
	Color3.fromRGB(236, 170, 112),
}
local LEAVES: { Color3 } = {
	Color3.fromRGB(72, 168, 84),
	Color3.fromRGB(96, 186, 76),
	Color3.fromRGB(58, 146, 92),
}
local TRUNK = Color3.fromRGB(124, 86, 56)
local RAIL = Color3.fromRGB(206, 210, 218)

export type RunRoad = {
	folder: Folder,
	update: (self: RunRoad, along: number) -> (),
	destroy: (self: RunRoad) -> (),
	_trove: any,
	_segments: { [number]: Model },
	_seed: number,
	_scenery: RunConfig.Scenery,
}

local function part(
	parent: Instance,
	size: Vector3,
	cf: CFrame,
	colour: Color3,
	material: Enum.Material?,
	shadow: boolean?
): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = shadow == true
	p.Size = size
	p.CFrame = cf
	p.Color = colour
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

-- World frame for a point on the road: `along` studs forward, `lateral` studs right, `up` above.
function RunRoad.frame(along: number, lateral: number, up: number): CFrame
	return RunConfig.ORIGIN * CFrame.new(lateral, up, -along)
end

function RunRoad.new(parent: Instance, seed: number, scenery: RunConfig.Scenery?): RunRoad
	local trove = Trove.new()
	local folder = trove:Add(Instance.new("Folder"))
	folder.Name = "Road"
	folder.Parent = parent
	local self = setmetatable({
		folder = folder,
		_trove = trove,
		_segments = {},
		_seed = seed,
		_scenery = scenery or "Canyon",
	}, RunRoad)
	return (self :: any) :: RunRoad
end

local function tree(m: Model, rng: Random, along: number, lateral: number)
	local h = rng:NextNumber(10, 18)
	part(m, Vector3.new(1.6, h, 1.6), RunRoad.frame(along, lateral, h / 2), TRUNK, Enum.Material.Wood, true)
	local leaves = LEAVES[rng:NextInteger(1, #LEAVES)]
	local r = rng:NextNumber(7, 11)
	local ball =
		part(m, Vector3.new(r, r, r), RunRoad.frame(along, lateral, h + r * 0.3), leaves, Enum.Material.Grass, true)
	ball.Shape = Enum.PartType.Ball
	local r2 = r * 0.7
	local ball2 = part(
		m,
		Vector3.new(r2, r2, r2),
		RunRoad.frame(along + r * 0.3, lateral + r * 0.3, h + r * 0.8),
		leaves,
		Enum.Material.Grass,
		true
	)
	ball2.Shape = Enum.PartType.Ball
end

local function boulder(m: Model, rng: Random, along: number, lateral: number)
	local s = rng:NextNumber(4, 9)
	local rock = part(
		m,
		Vector3.new(s * rng:NextNumber(1, 1.6), s, s * rng:NextNumber(1, 1.5)),
		RunRoad.frame(along, lateral, s * 0.35)
			* CFrame.Angles(rng:NextNumber(-0.3, 0.3), rng:NextNumber(0, 6), rng:NextNumber(-0.3, 0.3)),
		ROCK[rng:NextInteger(1, #ROCK)],
		Enum.Material.Slate,
		true
	)
	rock.Name = "Boulder"
end

local KERB_RED = Color3.fromRGB(226, 38, 44)
local KERB_WHITE = Color3.fromRGB(248, 248, 248)
local TRACK = Color3.fromRGB(52, 54, 60)
local GRAVEL = Color3.fromRGB(214, 200, 168)
local TYRE = Color3.fromRGB(26, 26, 30)
local FENCE = Color3.fromRGB(150, 156, 166)
local SEAT_COLOURS: { Color3 } = {
	Color3.fromRGB(226, 52, 52),
	Color3.fromRGB(40, 110, 220),
	Color3.fromRGB(250, 200, 40),
	Color3.fromRGB(240, 240, 240),
	Color3.fromRGB(60, 170, 90),
}

local function boardText(p: BasePart, face: Enum.NormalId, text: string, colour: Color3)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 20
	gui.LightInfluence = 0.3
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextScaled = true
	label.FontFace = Font.fromName("FredokaOne")
	label.TextColor3 = colour
	label.Parent = gui
	gui.Parent = p
end

-- A racing circuit: wide smooth track with no lane paint, red and white kerbs, grass run-off,
-- a gravel trap, a tyre wall, an armco barrier and catch fence, grandstands and start gantries.
local function buildCircuit(self: RunRoad, m: Model, index: number)
	local from = index * SEGMENT
	local mid = from + SEGMENT / 2
	local half = RunConfig.ROAD_HALF_WIDTH
	local rng = Random.new(self._seed * 7919 + index)

	part(m, Vector3.new(half * 2, 1, SEGMENT), RunRoad.frame(mid, 0, -0.5), TRACK, Enum.Material.Asphalt)
	-- Faint lane hints (racing lines), so players can still read where traffic will be.
	for lane = 1, RunConfig.LANES - 1 do
		local x = -RunConfig.LANES * RunConfig.LANE_WIDTH / 2 + lane * RunConfig.LANE_WIDTH
		local hint = part(m, Vector3.new(0.4, 0.05, SEGMENT), RunRoad.frame(mid, x, 0.02), Color3.fromRGB(80, 82, 90))
		hint.Transparency = 0.4
	end
	for side = -1, 1, 2 do
		part(
			m,
			Vector3.new(0.8, 0.08, SEGMENT),
			RunRoad.frame(mid, side * (half - RunConfig.SHOULDER - 0.4), 0.04),
			KERB_WHITE
		)
		local z = from
		local i = index * 20
		while z < from + SEGMENT do
			part(
				m,
				Vector3.new(RunConfig.SHOULDER, 0.35, 10),
				RunRoad.frame(z + 5, side * (half - RunConfig.SHOULDER / 2), 0.12),
				if i % 2 == 0 then KERB_RED else KERB_WHITE
			)
			z += 10
			i += 1
		end
		part(m, Vector3.new(26, 1, SEGMENT), RunRoad.frame(mid, side * (half + 13), -0.55), GRASS, Enum.Material.Grass)
		part(m, Vector3.new(24, 1, SEGMENT), RunRoad.frame(mid, side * (half + 38), -0.5), GRAVEL, Enum.Material.Pebble)
		-- Tyre wall with a red and white face, then the barrier and a see-through catch fence.
		part(
			m,
			Vector3.new(3, 3, SEGMENT),
			RunRoad.frame(mid, side * (half + 51.5), 1.5),
			TYRE,
			Enum.Material.Rubber,
			true
		)
		part(
			m,
			Vector3.new(3.1, 1, SEGMENT),
			RunRoad.frame(mid, side * (half + 51.5), 2.2),
			if side < 0 then KERB_RED else KERB_WHITE
		)
		part(
			m,
			Vector3.new(0.6, 3.5, SEGMENT),
			RunRoad.frame(mid, side * (half + 54), 1.75),
			RAIL,
			Enum.Material.Metal,
			true
		)
		local fence = part(
			m,
			Vector3.new(0.2, 12, SEGMENT),
			RunRoad.frame(mid, side * (half + 54.5), 9.5),
			FENCE,
			Enum.Material.Metal
		)
		fence.Transparency = 0.75
		part(m, Vector3.new(140, 1, SEGMENT), RunRoad.frame(mid, side * (half + 125), -0.6), GRASS, Enum.Material.Grass)
		-- Advertising boards on the barrier (our own title only, no real brands).
		local bz = from + 30
		while bz < from + SEGMENT do
			local board = part(
				m,
				Vector3.new(0.4, 3, 24),
				RunRoad.frame(bz, side * (half + 53.6), 5),
				SEAT_COLOURS[rng:NextInteger(1, #SEAT_COLOURS)]
			)
			boardText(
				board,
				if side < 0 then Enum.NormalId.Right else Enum.NormalId.Left,
				"CAR HOP",
				Color3.new(1, 1, 1)
			)
			bz += 70
		end
	end

	-- Grandstand on one side of most segments.
	if index % 3 ~= 2 then
		local side = if index % 2 == 0 then -1 else 1
		local len = SEGMENT * 0.8
		local x0 = half + 62
		for tier = 0, 5 do
			part(
				m,
				Vector3.new(6, 3 + tier * 3, len),
				RunRoad.frame(mid, side * (x0 + tier * 6 + 3), (3 + tier * 3) / 2),
				Color3.fromRGB(200, 204, 212),
				Enum.Material.Concrete,
				true
			)
			part(
				m,
				Vector3.new(5.6, 0.8, len),
				RunRoad.frame(mid, side * (x0 + tier * 6 + 3), 3 + tier * 3 + 0.4),
				SEAT_COLOURS[(tier + index) % #SEAT_COLOURS + 1]
			)
		end
		local roofX = side * (x0 + 18)
		part(
			m,
			Vector3.new(44, 1, len),
			RunRoad.frame(mid, roofX, 26),
			Color3.fromRGB(236, 238, 242),
			Enum.Material.Metal,
			true
		)
		for pz = -1, 1 do
			part(
				m,
				Vector3.new(1, 26, 1),
				RunRoad.frame(mid + pz * len * 0.45, side * (x0 + 38), 13),
				RAIL,
				Enum.Material.Metal
			)
		end
	end

	-- Start gantry every fifth segment: two towers, a beam over the track and five red lights.
	if index % 5 == 0 then
		for side = -1, 1, 2 do
			part(
				m,
				Vector3.new(3, 30, 3),
				RunRoad.frame(from + 4, side * (half + 3), 15),
				Color3.fromRGB(40, 44, 54),
				Enum.Material.Metal,
				true
			)
		end
		local beam = part(
			m,
			Vector3.new(half * 2 + 9, 6, 3),
			RunRoad.frame(from + 4, 0, 27),
			Color3.fromRGB(40, 44, 54),
			Enum.Material.Metal,
			true
		)
		boardText(beam, Enum.NormalId.Back, "CAR HOP CIRCUIT", Color3.fromRGB(255, 214, 70))
		for l = -2, 2 do
			local light = part(
				m,
				Vector3.new(2.2, 2.2, 0.6),
				RunRoad.frame(from + 5.8, l * 6, 22.5),
				Color3.fromRGB(255, 40, 40),
				Enum.Material.Neon
			)
			light.Shape = Enum.PartType.Ball
		end
		-- Chequered strip across the track.
		for c = 0, math.floor(half * 2 / 4) - 1 do
			for r = 0, 1 do
				part(
					m,
					Vector3.new(4, 0.06, 4),
					RunRoad.frame(from + 2 + r * 4, -half + 2 + c * 4, 0.03),
					if (c + r) % 2 == 0 then Color3.new(1, 1, 1) else Color3.new(0.08, 0.08, 0.08)
				)
			end
		end
	end
end

local function buildSegment(self: RunRoad, index: number): Model
	local m = Instance.new("Model")
	if self._scenery == "Circuit" then
		m.Name = "Segment" .. index
		buildCircuit(self, m, index)
		m.Parent = self.folder
		return m
	end
	m.Name = "Segment" .. index
	local from = index * SEGMENT
	local mid = from + SEGMENT / 2
	local half = RunConfig.ROAD_HALF_WIDTH
	local laneSpan = RunConfig.LANES * RunConfig.LANE_WIDTH

	-- Road surface, shoulders and markings.
	part(m, Vector3.new(laneSpan, 1, SEGMENT), RunRoad.frame(mid, 0, -0.5), ASPHALT, Enum.Material.Asphalt)
	for side = -1, 1, 2 do
		part(
			m,
			Vector3.new(RunConfig.SHOULDER, 1, SEGMENT),
			RunRoad.frame(mid, side * (laneSpan / 2 + RunConfig.SHOULDER / 2), -0.45),
			SHOULDER,
			Enum.Material.Concrete
		)
		part(
			m,
			Vector3.new(0.7, 0.1, SEGMENT),
			RunRoad.frame(mid, side * (laneSpan / 2 - 0.6), 0.05),
			if side < 0 then YELLOW else PAINT
		)
		-- Rumble strip on the outer edge of each shoulder.
		local z = from
		local i = 0
		while z < from + SEGMENT do
			part(
				m,
				Vector3.new(1.2, 0.25, 8),
				RunRoad.frame(z + 4, side * (half - 0.6), 0.1),
				if i % 2 == 0 then RUMBLE_A else RUMBLE_B
			)
			z += 8
			i += 1
		end
		-- Guard rail.
		part(
			m,
			Vector3.new(0.4, 0.9, SEGMENT),
			RunRoad.frame(mid, side * (half + 1.2), 2.2),
			RAIL,
			Enum.Material.Metal,
			true
		)
		local post = from + 5
		while post < from + SEGMENT do
			part(
				m,
				Vector3.new(0.5, 2.6, 0.5),
				RunRoad.frame(post, side * (half + 1.2), 1.3),
				RAIL,
				Enum.Material.Metal
			)
			post += 20
		end
		-- Grass verge, then sand at the foot of the canyon walls.
		part(m, Vector3.new(60, 1, SEGMENT), RunRoad.frame(mid, side * (half + 30), -0.6), GRASS, Enum.Material.Grass)
		part(m, Vector3.new(120, 1, SEGMENT), RunRoad.frame(mid, side * (half + 120), -0.7), SAND, Enum.Material.Sand)
	end
	for lane = 1, RunConfig.LANES - 1 do
		local x = -laneSpan / 2 + lane * RunConfig.LANE_WIDTH
		local z = from + DASH / 2
		while z < from + SEGMENT do
			part(m, Vector3.new(0.5, 0.1, DASH), RunRoad.frame(z, x, 0.05), PAINT)
			z += DASH + DASH_GAP
		end
	end

	-- Scenery, the same for a given seed and segment.
	local rng = Random.new(self._seed * 7919 + index)
	for side = -1, 1, 2 do
		local z = from + rng:NextNumber(0, 20)
		while z < from + SEGMENT do
			local lateral = side * (half + rng:NextNumber(8, 52))
			if rng:NextNumber() < 0.7 then
				tree(m, rng, z, lateral)
			else
				boulder(m, rng, z, lateral)
			end
			z += rng:NextNumber(14, 34)
		end
		-- Stepped canyon walls: two or three tiers of warm rock, taller further out.
		local wz = from
		while wz < from + SEGMENT do
			local len = rng:NextNumber(30, 60)
			local base = half + 150 + rng:NextNumber(0, 30)
			for tier = 0, 2 do
				local h = rng:NextNumber(30, 50) + tier * 34
				local depth = 40
				local x = side * (base + tier * 28 + depth / 2)
				part(
					m,
					Vector3.new(depth, h, len + 1),
					RunRoad.frame(wz + len / 2, x, h / 2 - 1),
					ROCK[rng:NextInteger(1, #ROCK)],
					Enum.Material.Sandstone
				)
				-- A darker band near the top of each tier gives the rock its layered look.
				part(
					m,
					Vector3.new(depth + 0.4, 3, len + 1.4),
					RunRoad.frame(wz + len / 2, x, h - 6),
					Color3.fromRGB(176, 96, 64),
					Enum.Material.Sandstone
				)
			end
			wz += len
		end
	end

	m.Parent = self.folder
	return m
end

function RunRoad.update(self: RunRoad, along: number)
	local first = math.floor((along - BEHIND) / SEGMENT)
	local last = math.floor((along + AHEAD) / SEGMENT)
	for index, model in self._segments do
		if index < first or index > last then
			model:Destroy()
			self._segments[index] = nil
		end
	end
	for index = math.max(first, -1), last do
		if not self._segments[index] then
			self._segments[index] = buildSegment(self, index)
		end
	end
end

function RunRoad.destroy(self: RunRoad)
	for _, model in self._segments do
		model:Destroy()
	end
	table.clear(self._segments)
	self._trove:Destroy()
end

return RunRoad
