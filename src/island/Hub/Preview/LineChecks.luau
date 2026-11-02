--!strict
-- DEVELOPMENT PREVIEW ONLY (Lane 3, Round 2 N1-06). Road, line and barrier checks on the built look, in
-- Studio edit mode on the island hub (Adam's private island place only):
--
--   local I = game.ServerStorage.Island:Clone(); I.Parent = game.ServerStorage
--   local C = require(I.Hub.Preview.LineChecks)
--   print(C.selfTest())                     -- proves each check catches a known-bad case
--   print(C.text(C.run()))                  -- every plot at every level: a plot by level matrix
--
-- Paint is judged by ownership, not by "touches a road": a line always lies on its own road. It fails
-- only where it stands well inside a road surface it does not edge.
--   crossing   solid paint more than Margin inside a junction polygon, a lane or the track
--   overlap    two paint pieces lying on each other, other than one chain's own end-to-end joints
--   freeEnd    a line that stops inside a road instead of at an edge
--   walk       the plot walk's far end more than 0.5 from the road, or a barrier across its opening
--   floats     a paved surface whose top is off the road height by more than 0.1
--   wallStep   the largest height step between neighbouring wall caps
--   tyreOnWall barrier pieces standing on a wall's end marker
-- Missing a problem is worse than a false alarm here, so everything is measured on the placed parts.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Layout = require(script.Parent.Parent.Layout)

local LineChecks = {}

local MARGIN = 1.2
local PAINT = { EdgeLine = true, MergeDash = true, PitLine = true }
local R = 35
local HALF = 8
local uS = 389.187
local uF = 492.781

type Rect = { a: Vector2, b: Vector2, width: number, name: string, part: BasePart? }
export type Counts = { [string]: number }

local function shared(): any
	local s = ReplicatedStorage:FindFirstChild("Shared") :: any
	assert(s, "ReplicatedStorage.Shared is not synced")
	return s:Clone()
end

-- Distance from p to the segment a-b.
local function toSegment(p: Vector2, a: Vector2, b: Vector2): number
	local ab = b - a
	local len = ab:Dot(ab)
	if len < 1e-9 then
		return (p - a).Magnitude
	end
	local t = math.clamp((p - a):Dot(ab) / len, 0, 1)
	return (p - (a + ab * t)).Magnitude
end

local function toLine(p: Vector2, points: { Vector2 }): number
	local best = math.huge
	for i = 1, #points - 1 do
		best = math.min(best, toSegment(p, points[i], points[i + 1]))
	end
	return best
end

-- How deep inside the polygon p stands (0 when outside).
local function depth(p: Vector2, poly: { Vector2 }, RoadNet: any): number
	if not RoadNet.pointInPoly(p, poly) then
		return 0
	end
	local closed = table.clone(poly)
	table.insert(closed, poly[1])
	return toLine(p, closed)
end

-- The distance of p from the oval's centre line.
local function fromTrack(p: Vector2): number
	if p.Y <= uS then
		return math.abs((p - Vector2.new(0, uS)).Magnitude - R)
	elseif p.Y >= uF then
		return math.abs((p - Vector2.new(0, uF)).Magnitude - R)
	end
	return math.abs(math.abs(p.X) - R)
end

local function paintRects(look: Instance, bearing: number, names: { [string]: boolean }): { Rect }
	local rects: { Rect } = {}
	for _, d in look:GetDescendants() do
		if d:IsA("BasePart") and names[d.Name] and d.Position.Y < 1 and math.abs(d.CFrame.UpVector.Y) > 0.99 then
			local half = d.CFrame.LookVector * d.Size.Z / 2
			local a = Layout.planToPlot(bearing, Layout.worldToPlan(d.Position - half))
			local b = Layout.planToPlot(bearing, Layout.worldToPlan(d.Position + half))
			table.insert(rects, { a = a, b = b, width = d.Size.X, name = d.Name, part = d })
		end
	end
	return rects
end

local function samplesOf(r: Rect): { Vector2 }
	return { r.a:Lerp(r.b, 0.1), r.a:Lerp(r.b, 0.5), r.a:Lerp(r.b, 0.9) }
end

-- Two rects overlap along their middles, other than one chain's end-to-end joint.
local function layered(x: Rect, y: Rect): boolean
	local dx, dy = x.b - x.a, y.b - y.a
	local lx, ly = dx.Magnitude, dy.Magnitude
	if lx < 0.05 or ly < 0.05 then
		return false
	end
	local ux, uy = dx / lx, dy / ly
	local reach = (x.width + y.width) / 2
	-- the overlap of y's span on x's axis
	local p0, p1 = (y.a - x.a):Dot(ux), (y.b - x.a):Dot(ux)
	local lo, hi = math.max(0, math.min(p0, p1)), math.min(lx, math.max(p0, p1))
	local parallel = math.abs(ux:Dot(uy)) > 0.95
	if parallel then
		local gap = math.min(toSegment(y.a, x.a, x.b), toSegment(y.b, x.a, x.b), toSegment((y.a + y.b) / 2, x.a, x.b))
		return gap < reach * 0.8 and hi - lo > 0.6
	end
	-- crossing lines: the two centre lines cross away from both pieces' ends
	local function side(o: Vector2, a: Vector2, b: Vector2): number
		return (a.X - o.X) * (b.Y - o.Y) - (a.Y - o.Y) * (b.X - o.X)
	end
	local cross = side(x.a, x.b, y.a) * side(x.a, x.b, y.b) < 0 and side(y.a, y.b, x.a) * side(y.a, y.b, x.b) < 0
	if not cross then
		return false
	end
	local endNear = math.min((x.a - y.a).Magnitude, (x.a - y.b).Magnitude, (x.b - y.a).Magnitude, (x.b - y.b).Magnitude)
	return endNear > 0.6
end

local function checkLook(look: Instance, plot: Instance, bearing: number, RoadNet: any): { [string]: { string } }
	local found: { [string]: { string } } = {
		crossing = {},
		overlap = {},
		freeEnd = {},
		walk = {},
		floats = {},
		tyreOnWall = {},
	}
	local function add(kind: string, text: string)
		if #found[kind] < 200 then
			table.insert(found[kind], text)
		end
	end
	local rects = paintRects(look, bearing, PAINT)
	local laneStrips = { RoadNet.Left, RoadNet.Right }
	local inJunctionOrLane = function(p: Vector2): (string?, number)
		for _, j in RoadNet.Junctions do
			local d = depth(p, j.polygon, RoadNet)
			if d > 0 then
				return "junction", d
			end
		end
		for _, j in laneStrips do
			local d = RoadNet.LaneWidth / 2 - toLine(p, j.laneStrip)
			if d > 0 then
				return "lane", d
			end
		end
		return nil, 0
	end
	for _, r in rects do
		if r.name ~= "MergeDash" then
			for _, p in samplesOf(r) do
				local where, d = inJunctionOrLane(p)
				-- the line turning the corner round a grass nose stands a little deeper: that is its job
				local byNose = false
				for _, j in RoadNet.Junctions do
					byNose = byNose or (p - j.nose).Magnitude < 6
				end
				if where and d > MARGIN and not byNose then
					add("crossing", string.format("%s inside %s at (%.1f, %.1f)", r.name, where :: string, p.X, p.Y))
					break
				end
				if not where and fromTrack(p) < HALF - MARGIN - 0.6 then
					add("crossing", string.format("%s inside the track at (%.1f, %.1f)", r.name, p.X, p.Y))
					break
				end
			end
		end
	end
	for i = 1, #rects do
		for k = i + 1, #rects do
			local x, y = rects[i], rects[k]
			if math.abs(x.a.X - y.a.X) < 30 and math.abs(x.a.Y - y.a.Y) < 30 and layered(x, y) then
				add("overlap", string.format("%s and %s at (%.1f, %.1f)", x.name, y.name, x.a.X, x.a.Y))
			end
		end
	end
	-- a free end: no other line piece within 0.6 of it
	for i, r in rects do
		if r.name ~= "MergeDash" then
			for _, p in { r.a, r.b } do
				local joined = false
				for k, o in rects do
					if k ~= i and toSegment(p, o.a, o.b) < 0.6 + o.width then
						joined = true
						break
					end
				end
				if not joined then
					local where, d = inJunctionOrLane(p)
					if (where and d > MARGIN) or (not where and fromTrack(p) < HALF - MARGIN - 0.6) then
						add("freeEnd", string.format("%s stops at (%.1f, %.1f)", r.name, p.X, p.Y))
					end
				end
			end
		end
	end
	-- the plot walk reaches the road and its opening is clear
	local walkMax = -math.huge
	local visual = plot:FindFirstChild("Visual")
	if visual then
		for _, d in visual:GetDescendants() do
			if d:IsA("BasePart") and d.Name == "Walkway" then
				local half = d.Size / 2
				for _, sy in { -1, 1 } do
					for _, sz in { -1, 1 } do
						-- a wedge has no corner at top back: its bounding box is not its shape
						if not (d:IsA("WedgePart") and sy > 0 and sz < 0) then
							local w = d.CFrame:PointToWorldSpace(Vector3.new(0, sy * half.Y, sz * half.Z))
							walkMax = math.max(walkMax, Layout.planToPlot(bearing, Layout.worldToPlan(w)).Y)
						end
					end
				end
			end
		end
	end
	local edge = uS - (R + HALF)
	if walkMax == -math.huge then
		add("walk", "no Walkway parts")
	elseif math.abs(edge - walkMax) > 0.5 then
		add("walk", string.format("walk ends at u %.2f, the road's edge is at %.2f", walkMax, edge))
	end
	for _, d in look:GetDescendants() do
		if d:IsA("BasePart") and not string.find(d.Name, "WalkGate") and d.Transparency < 1 then
			local p = Layout.planToPlot(bearing, Layout.worldToPlan(d.Position))
			if
				math.abs(p.X) < RoadNet.WalkHalfWidth + 0.2
				and p.Y > edge - 2
				and p.Y < edge - 0.05
				and d.Position.Y > 0.5
			then
				add("walk", d.Name .. " stands in the walk's opening")
			end
		end
	end
	-- every road surface of the look sits at the road's height
	for _, d in look:GetDescendants() do
		if d:IsA("BasePart") and d.Name == "Surface" and d.Parent and math.abs(d.CFrame.UpVector.Y) > 0.999 then
			local top = d.Position.Y + d.Size.Y / 2
			if d:IsA("WedgePart") then
				top = d.Position.Y + d.Size.X / 2
			end
			local p = Layout.planToPlot(bearing, Layout.worldToPlan(d.Position))
			if p.Y < 405 and math.abs(top - RoadNet.Top) > 0.1 then
				add("floats", string.format("surface top %.2f at (%.1f, %.1f)", top, p.X, p.Y))
			end
		end
	end
	-- barrier pieces on a wall end marker
	local ends = {}
	for _, d in look:GetDescendants() do
		if d:IsA("BasePart") and d.Name == "BankWallEnd" then
			table.insert(ends, d)
		end
	end
	for _, d in look:GetDescendants() do
		if d:IsA("BasePart") and (d.Name == "SwTyreWall" or d.Name == "RunCap") then
			for _, e in ends do
				if (d.Position - e.Position).Magnitude < 1 + d.Size.X / 2 then
					add("tyreOnWall", d.Name)
				end
			end
		end
	end
	return found
end

-- The largest height step between neighbouring wall cap ends, on the placed parts.
local function wallStep(look: Instance): number
	local ends: { Vector3 } = {}
	local owner: { Instance } = {}
	for _, d in look:GetDescendants() do
		if d:IsA("BasePart") and d.Name == "BankWallCap" then
			local top = d.CFrame * CFrame.new(0, d.Size.Y / 2, 0)
			for _, sz in { -0.5, 0.5 } do
				table.insert(ends, (top * CFrame.new(0, 0, sz * d.Size.Z)).Position)
				table.insert(owner, d)
			end
		end
	end
	local worst = 0
	for i, p in ends do
		for k, q in ends do
			if owner[i] ~= owner[k] then
				local flat = Vector2.new(p.X - q.X, p.Z - q.Z).Magnitude
				if flat < 0.9 then
					worst = math.max(worst, math.abs(p.Y - q.Y))
				end
			end
		end
	end
	return worst
end

function LineChecks.run(options: { plots: { number }?, levels: { number }? }?): { [string]: any }
	assert(RunService:IsStudio() and not RunService:IsRunning(), "edit mode in Studio only")
	local o = options or {}
	local root = workspace:FindFirstChild("Lane3_IslandPreview") :: any
	assert(root, "build the island hub first")
	local S = shared()
	local Look = (require :: any)(S.Island.Speedway.Look)
	local RoadNet = (require :: any)(S.Island.Speedway.RoadNet)
	local plots = o.plots or { 1, 2, 3, 4, 5, 6 }
	local levels = o.levels or { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12 }
	local matrix: { [string]: any } = {}
	local totals: Counts = {}
	local examples: { string } = {}
	local worstStep = 0
	for _, index in plots do
		local plot = root.Island.Plots:FindFirstChild(string.format("Plot%02d", index)) :: Model
		local bearing = Layout.plotBearing(index)
		for _, level in levels do
			Look.clear(plot)
			Look.apply(plot, level, { index = index, bearing = bearing, owner = "" })
			local look = plot:FindFirstChild("SpeedwayLook") :: Folder
			local found = checkLook(look, plot, bearing, RoadNet)
			local sum = 0
			for kind, list in found do
				totals[kind] = (totals[kind] or 0) + #list
				sum += #list
				if #list > 0 and #examples < 16 then
					table.insert(examples, string.format("P%d L%d %s: %s", index, level, kind, list[1]))
				end
			end
			worstStep = math.max(worstStep, wallStep(look))
			matrix[string.format("P%dL%d", index, level)] = sum
			Look.clear(plot)
			task.wait()
		end
	end
	return {
		totals = totals,
		matrix = matrix,
		examples = examples,
		wallStep = worstStep,
		plots = plots,
		levels = levels,
	}
end

function LineChecks.text(r: { [string]: any }): string
	local out = {}
	local head = "      "
	for _, level in r.levels do
		head ..= string.format("L%-3d", level)
	end
	table.insert(out, head)
	for _, index in r.plots do
		local row = string.format("P%d    ", index)
		for _, level in r.levels do
			row ..= string.format("%-4d", r.matrix[string.format("P%dL%d", index, level)] or -1)
		end
		table.insert(out, row)
	end
	local kinds = {}
	for k, v in r.totals do
		table.insert(kinds, k .. "=" .. v)
	end
	table.sort(kinds)
	table.insert(out, table.concat(kinds, " "))
	table.insert(out, string.format("largest wall cap step %.3f", r.wallStep))
	for _, e in r.examples do
		table.insert(out, e)
	end
	return table.concat(out, "\n")
end

-- Round 2 N4-03: no plant's crown inside another's, or within 2 of a sign, lamp or gate piece. Crowns are
-- measured on the placed meshes (whole-plant bounds, the same plant's parts excluded): bounds are the
-- cautious first pass, irregular crowns are then looked at by eye.
function LineChecks.canopies(): { [string]: any }
	local env = workspace:FindFirstChild("Lane3_IslandEnvironment")
	assert(env, "build the environment first")
	type Plant = { model: Instance, p: Vector2, r: number, lo: number, hi: number }
	local plants: { Plant } = {}
	local objects: { { name: string, p: Vector2, r: number } } = {}
	for _, d in env:GetDescendants() do
		if d:IsA("Model") and d:GetAttribute("Family") ~= nil then
			local crown = d:FindFirstChild("Canopy") or d:FindFirstChild("Foliage")
			if crown and crown:IsA("BasePart") then
				table.insert(plants, {
					model = d,
					p = Vector2.new(crown.Position.X, crown.Position.Z),
					r = math.max(crown.Size.X, crown.Size.Z) / 2,
					lo = crown.Position.Y - crown.Size.Y / 2,
					hi = crown.Position.Y + crown.Size.Y / 2,
				})
			end
		elseif d:IsA("BasePart") and d.Transparency < 1 then
			local parent = d.Parent and d.Parent.Name or ""
			if parent == "Lamps" or parent == "Signs" or parent == "Signposts" or parent == "Pieces" then
				table.insert(objects, {
					name = parent .. "/" .. d.Name,
					p = Vector2.new(d.Position.X, d.Position.Z),
					r = math.max(d.Size.X, d.Size.Z) / 2,
				})
			end
		end
	end
	table.sort(plants, function(a, b)
		return a.p.X < b.p.X
	end)
	local between, withObjects = 0, 0
	local worst = {}
	for i, a in plants do
		for k = i + 1, #plants do
			local b = plants[k]
			if b.p.X - a.p.X > a.r + b.r + 1 then
				break
			end
			local gap = (a.p - b.p).Magnitude - a.r - b.r
			if gap < 0 and a.hi > b.lo and b.hi > a.lo then
				between += 1
				if #worst < 8 then
					table.insert(
						worst,
						string.format("%s / %s gap %.1f at (%.0f, %.0f)", a.model.Name, b.model.Name, gap, a.p.X, a.p.Y)
					)
				end
			end
		end
		for _, o in objects do
			if (a.p - o.p).Magnitude - a.r - o.r < 0 then
				withObjects += 1
				if #worst < 12 then
					table.insert(worst, string.format("%s / %s at (%.0f, %.0f)", a.model.Name, o.name, a.p.X, a.p.Y))
				end
			end
		end
	end
	return {
		plants = #plants,
		objects = #objects,
		crownsTouching = between,
		crownsOnObjects = withObjects,
		examples = worst,
	}
end

-- Known-bad cases: each must be caught, or the zero above means nothing.
function LineChecks.selfTest(): { [string]: number }
	assert(RunService:IsStudio() and not RunService:IsRunning(), "edit mode in Studio only")
	local root = workspace:FindFirstChild("Lane3_IslandPreview") :: any
	local S = shared()
	local Look = (require :: any)(S.Island.Speedway.Look)
	local RoadNet = (require :: any)(S.Island.Speedway.RoadNet)
	local index = 3
	local plot = root.Island.Plots.Plot03 :: Model
	local bearing = Layout.plotBearing(index)
	Look.clear(plot)
	Look.apply(plot, 6, { index = index, bearing = bearing, owner = "" })
	local look = plot:FindFirstChild("SpeedwayLook") :: Folder
	local function at(x: number, u: number): Vector3
		return Layout.plotToWorld(bearing, Vector2.new(x, u), 0.3)
	end
	local function line(a: Vector3, b: Vector3): Part
		local p = Instance.new("Part")
		p.Name = "EdgeLine"
		p.Anchored = true
		p.Size = Vector3.new(0.3, 0.12, (b - a).Magnitude)
		p.CFrame = CFrame.lookAt((a + b) / 2, b)
		p.Parent = look
		return p
	end
	local out: { [string]: number } = {}
	local base = checkLook(look, plot, bearing, RoadNet)
	out.clean = #base.crossing + #base.overlap + #base.freeEnd + #base.walk
	-- 1: a line across a junction's mouth, the old fault
	local bad = line(at(38, 385), at(30, 395))
	out.crossingCaught = #checkLook(look, plot, bearing, RoadNet).crossing
	bad:Destroy()
	-- 2: paint laid twice along the same edge
	local copy: BasePart? = nil
	for _, d in look:GetDescendants() do
		if d:IsA("BasePart") and d.Name == "EdgeLine" and d.Size.Z > 3 and d.Position.Y < 1 then
			copy = d
			break
		end
	end
	local double = (copy :: BasePart):Clone()
	double.CFrame = (copy :: BasePart).CFrame * CFrame.new(0.1, 0, 0)
	double.Parent = look
	out.overlapCaught = #checkLook(look, plot, bearing, RoadNet).overlap
	double:Destroy()
	-- 3: a line that stops in the middle of the track
	local stop = line(at(35, 440), at(35, 446))
	out.freeEndCaught = #checkLook(look, plot, bearing, RoadNet).freeEnd
	stop:Destroy()
	-- 4: the walk pulled back from the road, the old gap
	local walks = {}
	for _, d in (plot :: any).Visual:GetDescendants() do
		if d:IsA("BasePart") and d.Name == "Walkway" then
			table.insert(walks, { d, d.CFrame })
			d.CFrame -= Layout.plotToWorld(bearing, Vector2.new(0, 3), 0) - Layout.plotToWorld(bearing, Vector2.zero, 0)
		end
	end
	out.walkCaught = #checkLook(look, plot, bearing, RoadNet).walk
	for _, w in walks do
		w[1].CFrame = w[2]
	end
	Look.clear(plot)
	return out
end

return LineChecks
