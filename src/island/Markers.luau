--!strict
-- Plot markers as in the draft contract (vault/design/plot-marker-contract.md).
-- One invisible anchor part per plot holds every marker Attachment. Geometry only:
-- no ownership, saving, spawning or gameplay.

local Layout = require(script.Parent.Layout)

local Markers = {}

local SURFACE = Layout.SurfaceY
local TRACK_TOP = SURFACE + 0.2
local PADDOCK_TOP = SURFACE + 0.15

local function attach(anchor: BasePart, name: string, worldCFrame: CFrame): Attachment
	local a = Instance.new("Attachment")
	a.Name = name
	a.CFrame = anchor.CFrame:ToObjectSpace(worldCFrame)
	a.Parent = anchor
	return a
end

-- World CFrame at a plot-frame point, looking along a plot-frame direction.
local function plotCFrame(bearing: number, p: Vector2, dir: Vector2, y: number): CFrame
	local pos = Layout.plotToWorld(bearing, p, y)
	local ahead = Layout.plotToWorld(bearing, p + dir, y)
	return CFrame.lookAt(pos, ahead)
end

function Markers.build(plot: Model, index: number): BasePart
	local bearing = Layout.plotBearing(index)
	local gate = Vector2.new(0, Layout.Plaza.gateRadius)
	local toPlaza = Vector2.new(0, -1)

	local anchor = Instance.new("Part")
	anchor.Name = "Markers"
	anchor.Anchored = true
	anchor.Transparency = 1
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.CastShadow = false
	anchor.Size = Vector3.new(1, 1, 1)
	anchor.CFrame = plotCFrame(bearing, gate, toPlaza, SURFACE)

	attach(anchor, "GateSpawn", plotCFrame(bearing, Vector2.new(0, Layout.Plaza.spawnU), toPlaza, SURFACE))
	attach(
		anchor,
		"NameplateAnchor",
		plotCFrame(bearing, Vector2.new(0, Layout.Plaza.gateRadius - 0.8), toPlaza, SURFACE + 7)
	)

	local path = Layout.Path
	local count = Layout.Track.sampleCount
	local startPos, startDir = Layout.pointAt(path, Layout.StartS)
	local speedway = attach(anchor, "Speedway", plotCFrame(bearing, startPos, startDir, TRACK_TOP))
	speedway:SetAttribute("PathLength", math.round(path.length * 10) / 10)
	speedway:SetAttribute("TrackWidth", Layout.Track.width)
	speedway:SetAttribute("MinTurnRadius", Layout.MinTurnRadius)
	speedway:SetAttribute("PathSampleCount", count)
	speedway:SetAttribute("Direction", "CounterClockwise")

	for i = 1, count do
		local distance = (i - 1) * path.length / count
		local p, t = Layout.pointAt(path, Layout.StartS + distance)
		local a = attach(anchor, string.format("Path%03d", i), plotCFrame(bearing, p, t, TRACK_TOP))
		a:SetAttribute("PathIndex", i)
		a:SetAttribute("Distance", math.round(distance * 100) / 100)
	end

	for _, bay in Layout.Bays do
		local a = attach(
			anchor,
			string.format("Bay%02d", bay.index),
			plotCFrame(bearing, Vector2.new(bay.x, bay.u), Vector2.new(0, bay.facing), PADDOCK_TOP)
		)
		a:SetAttribute("BayIndex", bay.index)
		a:SetAttribute("Row", bay.row)
		a:SetAttribute("Initial", bay.initial)
	end

	local function lane(prefix: string, points: { Vector2 })
		for i, p in points do
			local nextPoint = points[math.min(i + 1, #points)]
			local dir = if i < #points then nextPoint - p else p - points[i - 1]
			local a = attach(anchor, string.format("%s%02d", prefix, i), plotCFrame(bearing, p, dir.Unit, TRACK_TOP))
			a:SetAttribute("LaneIndex", i)
		end
	end
	lane("PitIn", Layout.PitIn)
	lane("PitOut", Layout.PitOut)

	anchor.Parent = plot
	return anchor
end

return Markers
