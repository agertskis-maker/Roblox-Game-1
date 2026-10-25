--!strict
-- Greybox endless road for the Lane 1 run prototype: straight segments streamed in ahead and
-- recycled behind, with lane markings and plain blocks for scenery. Lane 3 owns the real world
-- look (Adam's Downtown kit); this only gives the driving something to be judged on.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RunConfig = require(ReplicatedStorage.Shared.Run.RunConfig)
local Trove = require(ReplicatedStorage.Packages.Trove)

local RunRoad = {}
RunRoad.__index = RunRoad

local SEGMENT = 240
local AHEAD = 1000
local BEHIND = 240
local DASH = 12
local DASH_GAP = 28

local ASPHALT = Color3.fromRGB(58, 62, 70)
local SHOULDER = Color3.fromRGB(110, 114, 122)
local PAINT = Color3.fromRGB(240, 240, 232)
local GRASS = Color3.fromRGB(110, 178, 96)
local BUILDINGS: { Color3 } = {
	Color3.fromRGB(240, 170, 150),
	Color3.fromRGB(150, 210, 196),
	Color3.fromRGB(250, 226, 170),
	Color3.fromRGB(176, 196, 232),
	Color3.fromRGB(226, 226, 220),
}

export type RunRoad = {
	folder: Folder,
	update: (self: RunRoad, along: number) -> (),
	destroy: (self: RunRoad) -> (),
	_trove: any,
	_segments: { [number]: Model },
	_seed: number,
}

local function part(parent: Instance, size: Vector3, cf: CFrame, colour: Color3, material: Enum.Material?): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
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

local function buildSegment(self: RunRoad, index: number): Model
	local m = Instance.new("Model")
	m.Name = "Segment" .. index
	local from = index * SEGMENT
	local mid = from + SEGMENT / 2
	local half = RunConfig.ROAD_HALF_WIDTH
	local laneSpan = RunConfig.LANES * RunConfig.LANE_WIDTH

	part(m, Vector3.new(laneSpan, 1, SEGMENT), RunRoad.frame(mid, 0, -0.5), ASPHALT, Enum.Material.Asphalt)
	for side = -1, 1, 2 do
		local x = side * (laneSpan / 2 + RunConfig.SHOULDER / 2)
		part(
			m,
			Vector3.new(RunConfig.SHOULDER, 1, SEGMENT),
			RunRoad.frame(mid, x, -0.45),
			SHOULDER,
			Enum.Material.Concrete
		)
		part(m, Vector3.new(0.6, 0.1, SEGMENT), RunRoad.frame(mid, side * laneSpan / 2, 0.05), PAINT)
		part(m, Vector3.new(160, 1, SEGMENT), RunRoad.frame(mid, side * (half + 80), -0.6), GRASS, Enum.Material.Grass)
	end
	for lane = 1, RunConfig.LANES - 1 do
		local x = -laneSpan / 2 + lane * RunConfig.LANE_WIDTH
		local z = from + DASH / 2
		while z < from + SEGMENT do
			part(m, Vector3.new(0.5, 0.1, DASH), RunRoad.frame(z, x, 0.05), PAINT)
			z += DASH + DASH_GAP
		end
	end

	-- Scenery blocks, the same for a given seed and segment.
	local rng = Random.new(self._seed * 7919 + index)
	for side = -1, 1, 2 do
		local z = from + rng:NextNumber(0, 30)
		while z < from + SEGMENT do
			local w = rng:NextNumber(24, 48)
			local d = rng:NextNumber(24, 44)
			local h = rng:NextNumber(18, 70)
			local x = side * (half + 14 + w / 2 + rng:NextNumber(0, 20))
			part(
				m,
				Vector3.new(w, h, d),
				RunRoad.frame(z + d / 2, x, h / 2),
				BUILDINGS[rng:NextInteger(1, #BUILDINGS)],
				Enum.Material.SmoothPlastic
			)
			z += d + rng:NextNumber(10, 40)
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
