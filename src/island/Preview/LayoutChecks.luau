--!strict
-- DEVELOPMENT CHECKS (Lane 3). Reads the built preview and reports the Stage A fit
-- checks from the instances themselves (markers, parts), not from the plan's numbers.
--
--   require(game.ServerStorage.Island.Preview.LayoutChecks).run()

local StarterPlayer = game:GetService("StarterPlayer")

local Layout = require(script.Parent.Parent.Layout)

local LayoutChecks = {}

local function round(n: number, places: number?): number
	local m = 10 ^ (places or 2)
	return math.round(n * m) / m
end

local function plazaPoint(v: Vector3): Vector2
	return Vector2.new(v.X, -v.Z)
end

-- Plaza-frame point into a plot's frame (x right when facing outward, u outward).
local function toPlotFrame(bearingDeg: number, p: Vector2): Vector2
	local b = math.rad(bearingDeg)
	local u = p.X * math.sin(b) + p.Y * math.cos(b)
	local x = p.X * math.cos(b) - p.Y * math.sin(b)
	return Vector2.new(x, u)
end

function LayoutChecks.run(): { [string]: any }
	local root = workspace:FindFirstChild("Lane3_IslandPreview")
	assert(root, "Build the preview first")
	local island = root:FindFirstChild("Island") :: Model
	local plotCount = island:GetAttribute("PlotCount") :: number
	local plots = island:FindFirstChild("Plots") :: Folder
	local report: { [string]: any } = {}
	report.plotCountAttribute = plotCount
	report.plotModels = #plots:GetChildren()

	local perPlot = {}
	local reference: { [string]: CFrame } = {}
	local worstDeviation = 0
	local worstRay, worstRadius, minPathLength, maxPathLength = math.huge, 0, math.huge, 0
	for index = 1, plotCount do
		local plot = plots:FindFirstChild(string.format("Plot%02d", index)) :: Model
		local markers = plot:FindFirstChild("Markers") :: BasePart
		local bearing = plot:GetAttribute("BearingDeg") :: number
		local speedway = markers:FindFirstChild("Speedway") :: Attachment
		local sampleCount = speedway:GetAttribute("PathSampleCount") :: number

		-- every marker in the plot's own frame must match Plot01's
		for _, a in markers:GetChildren() do
			if a:IsA("Attachment") then
				local relative = a.CFrame
				if index == 1 then
					reference[a.Name] = relative
				elseif reference[a.Name] then
					local d = (reference[a.Name].Position - relative.Position).Magnitude
					worstDeviation = math.max(worstDeviation, d)
				end
			end
		end

		-- path from the built samples: length, and the outer clearance edge against dividers and the outer limit
		local samples: { Vector2 } = {}
		for i = 1, sampleCount do
			local a = markers:FindFirstChild(string.format("Path%03d", i)) :: Attachment
			samples[i] = toPlotFrame(bearing, plazaPoint(a.WorldPosition))
		end
		local length = 0
		for i = 1, sampleCount do
			local p, q = samples[i], samples[i % sampleCount + 1]
			length += (q - p).Magnitude
			local tangent = (q - p).Unit
			local edge = (p + q) / 2 + Layout.outward(tangent) * Layout.OuterOffset
			worstRay = math.min(worstRay, Layout.rayClear(edge))
			worstRadius = math.max(worstRadius, edge.Magnitude)
		end
		minPathLength = math.min(minPathLength, length)
		maxPathLength = math.max(maxPathLength, length)

		local spawn = markers:FindFirstChild("GateSpawn") :: Attachment
		local flatLook = Vector3.new(spawn.WorldCFrame.LookVector.X, 0, spawn.WorldCFrame.LookVector.Z).Unit
		local toCentre = Vector3.new(-spawn.WorldPosition.X, 0, -spawn.WorldPosition.Z).Unit

		local bays, initial = 0, 0
		for i = 1, 15 do
			local bay = markers:FindFirstChild(string.format("Bay%02d", i)) :: Attachment?
			if bay then
				bays += 1
				if bay:GetAttribute("Initial") then
					initial += 1
				end
			end
		end
		local pits = 0
		for _, a in markers:GetChildren() do
			if string.match(a.Name, "^Pit") then
				pits += 1
			end
		end
		perPlot[index] = {
			bearing = bearing,
			samples = sampleCount,
			sampledPathLength = round(length, 1),
			spawnFacingDot = round(flatLook:Dot(toCentre), 4),
			spawnRadius = round(Vector2.new(spawn.WorldPosition.X, spawn.WorldPosition.Z).Magnitude, 2),
			bays = bays,
			initialBays = initial,
			pitPoints = pits,
		}
	end
	report.perPlot = perPlot
	report.markerDeviationFromPlot01 = round(worstDeviation, 4)
	report.sampledPathLength =
		{ min = round(minPathLength, 1), max = round(maxPathLength, 1), plan = round(Layout.Path.length, 1) }
	report.outerClearanceEdge = {
		minDividerClear = round(worstRay, 2),
		maxRadius = round(worstRadius, 2),
		required = "divider clear >= 2.5, radius <= 241.5",
	}

	-- swept car in the tightest turn (rigid rectangle, centre on the centreline)
	local car = Layout.Car
	local r = Layout.MinTurnRadius
	local outerSweep = math.sqrt((r + car.width / 2) ^ 2 + (car.length / 2) ^ 2) - r
	report.sweptCar = {
		tightestRadius = r,
		outerCornerOffset = round(outerSweep),
		clearOutside = round(Layout.Track.width / 2 - outerSweep),
		clearInside = round(Layout.Track.width / 2 - car.width / 2),
	}

	-- turntables: built platform diameter against the car's turning diagonal
	local diagonal = math.sqrt(car.length ^ 2 + car.width ^ 2)
	local turntables = {}
	local plazaModel = island:FindFirstChild("Plaza")
	local garage = plazaModel and plazaModel:FindFirstChild("Garage")
	local tt = garage and garage:FindFirstChild("Turntables")
	if tt then
		for _, p in tt:GetChildren() do
			if p:IsA("BasePart") and string.match(p.Name, "Platform$") then
				local d = math.min(p.Size.Y, p.Size.Z)
				table.insert(turntables, { name = p.Name, diameter = d, sparePerSide = round((d - diagonal) / 2) })
			end
		end
	end
	report.turntables = { carDiagonal = round(diagonal), built = turntables }

	-- bridge clearance over the track
	local plot1 = plots:FindFirstChild("Plot01") :: Model
	local visual = plot1:FindFirstChild("Visual")
	local bridgeFolder = visual and visual:FindFirstChild("Bridge")
	local deck = bridgeFolder and bridgeFolder:FindFirstChild("Deck")
	if deck and deck:IsA("BasePart") then
		local underside = deck.Position.Y - deck.Size.Y / 2
		report.bridge = {
			deckTop = round(deck.Position.Y + deck.Size.Y / 2),
			clearOverTrack = round(underside - (Layout.SurfaceY + 0.2)),
			carHeight = car.height,
		}
	end

	-- part and instance counts
	local function count(instance: Instance?): { parts: number, attachments: number, guis: number }
		local parts, attachments, guis = 0, 0, 0
		if instance then
			for _, d in instance:GetDescendants() do
				if d:IsA("BasePart") then
					parts += 1
				elseif d:IsA("Attachment") then
					attachments += 1
				elseif d:IsA("BillboardGui") then
					guis += 1
				end
			end
		end
		return { parts = parts, attachments = attachments, guis = guis }
	end
	report.counts = {
		plots = count(plots),
		onePlot = count(plot1),
		plaza = count(island:FindFirstChild("Plaza")),
		scenery = count(island:FindFirstChild("Scenery")),
		helpers = count(root:FindFirstChild("Helpers")),
		whole = count(root),
	}

	report.walkSpeed = StarterPlayer.CharacterWalkSpeed
	report.streamingEnabled = workspace.StreamingEnabled
	return report
end

return LayoutChecks
