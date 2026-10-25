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

function RunRoad.new(parent: Instance, seed: number): RunRoad
	local trove = Trove.new()
	local folder = trove:Add(Instance.new("Folder"))
	folder.Name = "Road"
	folder.Parent = parent
	local self = setmetatable({
		folder = folder,
		_trove = trove,
		_segments = {},
		_seed = seed,
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

local function buildSegment(self: RunRoad, index: number): Model
	local m = Instance.new("Model")
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
