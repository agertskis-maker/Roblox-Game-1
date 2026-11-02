--!strict
-- DEVELOPMENT CHECKS (Lane 3, big round M1 and M2). The island's own rules on top of the shared
-- OverlapScan: every result here should be zero. Run in edit mode after a build, with the Speedway
-- previewed at the level you want scanned:
--
--   local I = game.ServerStorage.Island:Clone()
--   local C = require(I.Hub.Preview.OverlapChecks)
--   print(C.text(C.run()))
--
-- Flowers are tested by the corners of their whole footprint, leaves and petals included, against
-- the bed's real outline with no margin. Support is tested from several footprint points against
-- anything solid, and a buried base is fine. Mirror pairs are tested by their placement anchors.

local Layout = require(script.Parent.Parent.Layout)
local BedShapes = require(script.Parent.Parent.Environment.BedShapes)

local OverlapChecks = {}

local park = Layout.Data.park
local FLOWERS = {
	TulipsRed = true,
	TulipsYellow = true,
	Daisies = true,
	Poppies = true,
	Lavender = true,
	RosesPink = true,
	RosesRed = true,
	BlueWildflowers = true,
	Clover = true,
	Sunflowers = true,
}
local BED_KINDS = { BedFountainArc = true, BedAvenueArc = true, BedCornerFillet = true, BedJunctionRound = true }
local BED_CLEARANCE = 1.9 -- the rule is 2; a tenth for the outline's chords
local TILT_LIMIT = 3
local FLOAT_LIMIT = 0.25

export type Result = { counts: { [string]: number }, examples: { [string]: { string } } }

local function plan(v: Vector3): Vector2
	return Vector2.new(v.X, -v.Z)
end

local function short(i: Instance): string
	return (string.gsub(i:GetFullName(), "^Workspace%.Lane3_IslandEnvironment%.", ""))
end

local function polylineDistance(points: { Vector2 }, p: Vector2): number
	local best = math.huge
	for i = 1, #points - 1 do
		local a, b = points[i], points[i + 1]
		local ab = b - a
		local t = if ab.Magnitude > 1e-6 then math.clamp((p - a):Dot(ab) / ab:Dot(ab), 0, 1) else 0
		best = math.min(best, (p - (a + ab * t)).Magnitude)
	end
	return best
end

local function pathEdgeDistance(p: Vector2): number
	local best = math.huge
	for _, path in park.paths do
		best = math.min(best, polylineDistance(path.points, p) - path.width / 2)
	end
	return best
end

local function cornersOf(part: BasePart): { Vector2 }
	local h = part.Size / 2
	local out = {}
	for _, x in { -h.X, h.X } do
		for _, z in { -h.Z, h.Z } do
			table.insert(out, plan(part.CFrame:PointToWorldSpace(Vector3.new(x, 0, z))))
		end
	end
	return out
end

function OverlapChecks.run(): Result
	local Scan = (require :: any)(game:GetService("ReplicatedStorage"):WaitForChild("Shared").Island.OverlapScan)
	local counts: { [string]: number } = {
		flowersChecked = 0,
		flowersOutsideRim = 0,
		flowersOffBed = 0,
		bedsTooCloseToPaving = 0,
		benchesChecked = 0,
		benchesOffPath = 0,
		benchesInBeds = 0,
		benchesTooClose = 0,
		lampsChecked = 0,
		lampsOffPath = 0,
		tippedOrFloating = 0,
		grassOnPaving = 0,
		fruitTrees = 0,
		treesNearStructures = 0,
		mirrorMismatches = 0,
		floorHoles = 0,
	}
	local examples: { [string]: { string } } = {}
	local function fail(key: string, what: string)
		counts[key] += 1
		local list = examples[key]
		if not list then
			list = {}
			examples[key] = list
		end
		if #list < 6 then
			table.insert(list, what)
		end
	end

	local env = workspace:FindFirstChild("Lane3_IslandEnvironment")
	assert(env, "Build the environment first")
	local dressing = env:FindFirstChild("ParkDressing")
	assert(dressing, "Build the park dressing first")
	local bedsFolder = dressing:FindFirstChild("Beds")
	local beds: { [string]: BasePart } = {}
	local outlines: { { Vector2 } } = {}
	if bedsFolder then
		for _, d in bedsFolder:GetChildren() do
			if d:IsA("BasePart") and BED_KINDS[d.Name] then
				local at = d:GetAttribute("BedAt") :: Vector2
				local yaw = d:GetAttribute("BedYaw") :: number
				beds[d:GetAttribute("BedId") :: string] = d
				local pts = {}
				for _, q in BedShapes.outline(d.Name) do
					local p = BedShapes.toPlan(at, yaw, q)
					table.insert(pts, p)
					if pathEdgeDistance(p) < BED_CLEARANCE or Layout.onPaved(p, 0) then
						fail("bedsTooCloseToPaving", short(d))
						break
					end
				end
				table.insert(outlines, pts)
			end
		end
		for _, d in bedsFolder:GetChildren() do
			if d:IsA("BasePart") and FLOWERS[d.Name] then
				counts.flowersChecked += 1
				local bed = beds[d:GetAttribute("BedId") :: string]
				if not bed then
					fail("flowersOffBed", short(d))
				else
					local at = bed:GetAttribute("BedAt") :: Vector2
					local yaw = bed:GetAttribute("BedYaw") :: number
					for _, c in cornersOf(d) do
						if BedShapes.soil(bed.Name, BedShapes.toLocal(at, yaw, c)) < 0 then
							fail("flowersOutsideRim", short(d))
							break
						end
					end
				end
			end
		end
	end
	local function inBed(p: Vector2, r: number): boolean
		for _, pts in outlines do
			for _, q in pts do
				if (q - p).Magnitude < r then
					return true
				end
			end
		end
		return false
	end

	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	local excluded: { Instance } = {}
	for _, name in { "Benches", "Lamps", "Signposts" } do
		local f = dressing:FindFirstChild(name)
		if f then
			table.insert(excluded, f)
		end
	end
	rayParams.FilterDescendantsInstances = excluded
	local function upright(part: BasePart)
		local tilt = Scan.tiltDegrees(part.CFrame)
		local flipped = math.abs(tilt - 180) < 1
		if tilt > TILT_LIMIT and not flipped then
			fail("tippedOrFloating", string.format("%s tilted %.1f", short(part), tilt))
		end
		local gap = Scan.supportGap(part, rayParams)
		if gap and gap > FLOAT_LIMIT then
			fail("tippedOrFloating", string.format("%s floats %.2f", short(part), gap))
		end
	end

	local benches = dressing:FindFirstChild("Benches")
	local benchSpots: { Vector2 } = {}
	if benches then
		for _, d in benches:GetChildren() do
			if d:IsA("BasePart") and d.Name == "Bench" then
				counts.benchesChecked += 1
				local p = plan(d.Position)
				table.insert(benchSpots, p)
				if pathEdgeDistance(p) > 3.5 then
					fail("benchesOffPath", short(d))
				end
				for _, corner in cornersOf(d) do
					if inBed(corner, 1) then
						fail("benchesInBeds", short(d))
						break
					end
				end
				upright(d)
			end
		end
	end
	for i, a in benchSpots do
		for k = i + 1, #benchSpots do
			local gap = (a - benchSpots[k]).Magnitude
			-- a pair faces each other across an avenue (16 wide), so it sits about 20 apart
			if gap < 12 then
				fail("benchesTooClose", string.format("%.1f apart at (%.0f, %.0f)", gap, a.X, a.Y))
			end
		end
	end

	local lamps = dressing:FindFirstChild("Lamps")
	if lamps then
		for _, d in lamps:GetChildren() do
			if d:IsA("BasePart") and d.Name == "LampPost" then
				counts.lampsChecked += 1
				if pathEdgeDistance(plan(d.Position)) > 3 then
					fail("lampsOffPath", short(d))
				end
				upright(d)
			end
		end
	end
	local signposts = dressing:FindFirstChild("Signposts")
	if signposts then
		for _, d in signposts:GetChildren() do
			if d:IsA("BasePart") and d.Name == "SignpostPost" then
				upright(d)
			end
		end
	end

	-- nothing grows through paving
	for _, folderName in { "ParkDressing", "GroundCover" } do
		local f = env:FindFirstChild(folderName)
		if f then
			for _, d in f:GetDescendants() do
				if d:IsA("BasePart") and (string.find(d.Name, "Grass") or d.Name == "Clover") then
					if Layout.onPaved(plan(d.Position), 0) then
						fail("grassOnPaving", short(d))
					end
				end
			end
		end
	end

	-- trees: no fruit canopies, and clear of the hub's structures
	for _, folderName in { "ParkDressing", "Flora" } do
		local f = env:FindFirstChild(folderName)
		if f then
			for _, d in f:GetDescendants() do
				if d:IsA("Model") and d:FindFirstChild("Trunk") then
					if d:GetAttribute("Family") == "Fruit" or string.find(d.Name, "Fruit") then
						fail("fruitTrees", short(d))
					end
					local p = plan(d.WorldPivot.Position)
					for _, b in park.buildings do
						if b.id == "Gazebo" and (p - b.centre).Magnitude < 12 then
							fail("treesNearStructures", short(d))
						end
					end
				end
			end
		end
	end

	-- mirror pairs, by their placement anchors
	local anchors: { [string]: { Vector2 } } = {}
	for _, d in dressing:GetDescendants() do
		if d:IsA("BasePart") and d:GetAttribute("MirrorPair") then
			local at = d:GetAttribute("PlanAt")
			if typeof(at) == "Vector2" then
				anchors[d.Name] = anchors[d.Name] or {}
				table.insert(anchors[d.Name], at)
			end
		end
	end
	for name, list in anchors do
		for _, a in list do
			local twin = false
			for _, b in list do
				if (Vector2.new(-a.X, a.Y) - b).Magnitude < 0.1 then
					twin = true
					break
				end
			end
			if not twin then
				fail("mirrorMismatches", string.format("%s at (%.1f, %.1f)", name, a.X, a.Y))
			end
		end
	end

	-- every walkable path has paving under its centre and both edges, all the way along
	local down = Vector3.new(0, -8, 0)
	local solid = RaycastParams.new()
	solid.FilterType = Enum.RaycastFilterType.Exclude
	solid.FilterDescendantsInstances = { workspace.Terrain }
	for _, path in park.paths do
		for i = 1, #path.points - 1 do
			local a, b = path.points[i], path.points[i + 1]
			local d = (b - a).Unit
			local n = Vector2.new(-d.Y, d.X)
			local length = (b - a).Magnitude
			local inset = path.width / 2 - 0.3
			local steps = math.max(1, math.floor(length / 3))
			for k = 0, steps do
				local c = a + d * (length * k / steps)
				for _, off in { 0, inset, -inset } do
					local p = c + n * off
					local hit = workspace:Raycast(Vector3.new(p.X, 3, -p.Y), down, solid)
					if not hit then
						fail("floorHoles", string.format("%s at (%.1f, %.1f)", path.kind, p.X, p.Y))
					end
				end
			end
		end
	end
	return { counts = counts, examples = examples }
end

function OverlapChecks.text(r: Result): string
	local keys = {}
	for k in r.counts do
		table.insert(keys, k)
	end
	table.sort(keys)
	local lines = {}
	for _, k in keys do
		local line = string.format("%-24s %d", k, r.counts[k])
		local ex = r.examples[k]
		if ex then
			line ..= "   e.g. " .. table.concat(ex, "; ")
		end
		table.insert(lines, line)
	end
	return table.concat(lines, "\n")
end

return OverlapChecks
