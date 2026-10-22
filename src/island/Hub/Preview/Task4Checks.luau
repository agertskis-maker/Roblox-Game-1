--!strict
-- DEVELOPMENT CHECKS (Lane 3, Task 4). Deterministic checks on the built island, each failure
-- naming the object and its position:
--   shore     no dry-land piece stands in the lake or the river (whole footprint, 0 margin here;
--             the dressing itself keeps 3 and 4 studs) — the "turtle on a brown pad" rule
--   turtle    no CarTopiary anywhere
--   grounding every placed mesh rests on something: the support below its base (terrain or
--             another part) is within GroundTolerance at the centre or a corner; flags pieces
--             floating above the ground and bases buried deeper than BuryTolerance
--   mirror    every MirrorPair piece has its mirror image (same name) about park.axisX
--   counts    a snapshot of part counts per folder, to compare two rebuilds (idempotency)
--
--   local I = game.ServerStorage.Island:Clone()
--   local C = require(I.Hub.Preview.Task4Checks)
--   C.run()            -- every check; returns { failures = {...}, summary = {...} }
--   C.snapshot()       -- counts per top folder, for a before / after rebuild comparison

local Field = require(script.Parent.Parent.Environment.Field)
local KitManifest = require(script.Parent.Parent.Environment.KitManifest)
local Layout = require(script.Parent.Parent.Layout)

local Task4Checks = {}

Task4Checks.GroundTolerance = 0.35 -- studs between a base and the support under it
Task4Checks.BuryTolerance = 1.6 -- studs a base may sit below the ground at its lowest corner
Task4Checks.MirrorTolerance = 0.05

-- Pieces allowed over water: they carry Wet = true, or live under these folders.
local WET_FOLDERS = { Bridges = true, LakeDressing = true, Waterfall = true, Fountain = true }
-- Not ground-standing: hanging or carried pieces (strings, glass, headers, flowers in beds,
-- canopies, effects).
local NOT_STANDING = {
	BuntingString = true,
	LampGlass = true,
	HeaderBoard = true,
	SignpostBoard = true,
	Parasol = true,
	FountainGrandWater = true,
	PlazaMosaic = true,
}

local park = Layout.Data.park
local AXIS = park.axisX or 0

local function plan(v: Vector3): Vector2
	return Vector2.new(v.X, -v.Z)
end

local function fmt(v: Vector3): string
	return string.format("(%.1f, %.1f, %.1f)", v.X, v.Y, v.Z)
end

local function roots(): { Instance }
	local out = {}
	for _, name in { "Lane3_IslandEnvironment", "Lane3_IslandPreview" } do
		local r = workspace:FindFirstChild(name)
		if r then
			table.insert(out, r)
		end
	end
	return out
end

local function wetAllowed(part: BasePart): boolean
	if part:GetAttribute("Wet") == true then
		return true
	end
	local a: Instance? = part.Parent
	while a and a ~= workspace do
		if WET_FOLDERS[a.Name] then
			return true
		end
		a = a.Parent
	end
	return false
end

local function corners(part: BasePart): { Vector3 }
	local h = part.Size / 2
	local out = {}
	for _, x in { -h.X, h.X } do
		for _, z in { -h.Z, h.Z } do
			table.insert(out, part.CFrame:PointToWorldSpace(Vector3.new(x, -h.Y, z)))
		end
	end
	return out
end

local function inWater(p: Vector2): (boolean, string)
	if Field.lakeShape(p) then
		return true, "lake"
	end
	local d = Field.polylineDistance(park.stream, p)
	if d < park.streamWidth / 2 then
		return true, "river"
	end
	return false, ""
end

function Task4Checks.shore(): { any }
	local fails = {}
	local env = workspace:FindFirstChild("Lane3_IslandEnvironment")
	local dressing = env and env:FindFirstChild("ParkDressing")
	if not dressing then
		return { { check = "shore", problem = "no ParkDressing folder" } }
	end
	for _, d in dressing:GetDescendants() do
		if d:IsA("BasePart") and not wetAllowed(d) and d.Transparency < 1 then
			-- a tree may lean over the water: only its trunk base must stand on land
			local tree = d:FindFirstAncestor("Trees") ~= nil
			if tree and d.Name ~= "Trunk" then
				continue
			end
			local tests = if tree then { d.Position } else { d.Position, table.unpack(corners(d)) }
			for _, c in tests do
				local wet, where = inWater(plan(c))
				if wet then
					table.insert(
						fails,
						{ check = "shore", object = d:GetFullName(), at = fmt(d.Position), water = where }
					)
					break
				end
			end
		end
	end
	return fails
end

function Task4Checks.turtle(): { any }
	local fails = {}
	for _, r in roots() do
		for _, d in r:GetDescendants() do
			if d.Name == "CarTopiary" then
				table.insert(
					fails,
					{ check = "turtle", object = d:GetFullName(), at = fmt((d :: any).Position or Vector3.zero) }
				)
			end
		end
	end
	return fails
end

-- Support distance below a world point (0 when touching, negative when buried), ignoring the
-- piece itself. The ray starts 3 above the point: a ray that starts inside the terrain (a sunk
-- base) never hits it.
-- The ground is the terrain and the paved hub surfaces only, so a tuft under a bench seat or a
-- hedge under a tree is judged by the ground, not by what stands over it.
local function supportGap(at: Vector3, _ignore: Instance): number
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	local ground: { Instance } = { workspace.Terrain }
	local preview = workspace:FindFirstChild("Lane3_IslandPreview")
	if preview then
		table.insert(ground, preview)
	end
	params.FilterDescendantsInstances = ground
	params.IgnoreWater = true
	local hit = workspace:Raycast(at + Vector3.new(0, 3, 0), Vector3.new(0, -43, 0), params)
	if not hit then
		return math.huge
	end
	return at.Y - hit.Position.Y
end

-- How deep a mesh is meant to sit below its ground line (the recipe's sink, or its bounds).
local function sinkOf(part: BasePart): number
	local entry = (KitManifest :: any)[part.Name]
	if not entry then
		return 0
	end
	return math.max(entry.meta.sink or 0, -entry.min.Y)
end

function Task4Checks.grounding(): ({ any }, number)
	local fails = {}
	local checked = 0
	local env = workspace:FindFirstChild("Lane3_IslandEnvironment")
	local dressing = env and env:FindFirstChild("ParkDressing")
	if not dressing then
		return { { check = "grounding", problem = "no ParkDressing folder" } }, 0
	end
	for _, d in dressing:GetDescendants() do
		if
			d:IsA("MeshPart")
			and not NOT_STANDING[d.Name]
			and not d:GetAttribute("Hanging")
			and d.Name ~= "Canopy" -- a tree canopy stands on its trunk, not the ground
			and d.Transparency < 1
			and not d:FindFirstAncestor("Beds")
		then
			checked += 1
			local bottom = d.Position - Vector3.new(0, d.Size.Y / 2, 0)
			local gaps = { supportGap(bottom, d) }
			for _, c in corners(d) do
				table.insert(gaps, supportGap(c, d))
			end
			local lowest = math.huge
			local deepest = -math.huge
			for _, g in gaps do
				lowest = math.min(lowest, g)
				deepest = math.max(deepest, -g)
			end
			if lowest > Task4Checks.GroundTolerance then
				table.insert(
					fails,
					{ check = "floating", object = d:GetFullName(), at = fmt(d.Position), gap = lowest }
				)
			elseif
				deepest > Task4Checks.BuryTolerance + sinkOf(d)
				and not d:GetAttribute("BuriedOk")
				and d.Name ~= "Trunk" -- trunks run into the ground as root anchors (Flora)
				and d.Name ~= "Foliage" -- Flora sets bushes into the ground so no gap shows under them
			then
				table.insert(
					fails,
					{ check = "buried", object = d:GetFullName(), at = fmt(d.Position), depth = deepest }
				)
			end
		end
	end
	return fails, checked
end

function Task4Checks.mirror(): ({ any }, number)
	local fails = {}
	local byName: { [string]: { BasePart } } = {}
	local count = 0
	for _, r in roots() do
		for _, d in r:GetDescendants() do
			if d:IsA("BasePart") and d:GetAttribute("MirrorPair") then
				byName[d.Name] = byName[d.Name] or {}
				table.insert(byName[d.Name], d)
				count += 1
			end
		end
	end
	for name, list in byName do
		for _, a in list do
			local pa = (a:GetAttribute("PlanAt") :: Vector2?) or Vector2.new(a.Position.X, -a.Position.Z)
			local want = Vector2.new(2 * AXIS - pa.X, pa.Y)
			local found = false
			for _, b in list do
				local pb = (b:GetAttribute("PlanAt") :: Vector2?) or Vector2.new(b.Position.X, -b.Position.Z)
				if (pb - want).Magnitude <= Task4Checks.MirrorTolerance then
					found = true
					break
				end
			end
			if not found then
				table.insert(fails, { check = "mirror", object = a:GetFullName(), name = name, at = fmt(a.Position) })
			end
		end
	end
	return fails, count
end

function Task4Checks.snapshot(): { [string]: number }
	local out = {}
	for _, r in roots() do
		for _, child in r:GetChildren() do
			local n = 0
			for _, d in child:GetDescendants() do
				if d:IsA("BasePart") then
					n += 1
				end
			end
			out[r.Name .. "." .. child.Name] = n
		end
	end
	return out
end

function Task4Checks.compare(a: { [string]: number }, b: { [string]: number }): { any }
	local diffs = {}
	for k, v in a do
		if b[k] ~= v then
			table.insert(diffs, { folder = k, first = v, second = b[k] })
		end
	end
	for k, v in b do
		if a[k] == nil then
			table.insert(diffs, { folder = k, first = nil, second = v })
		end
	end
	return diffs
end

function Task4Checks.run(): { [string]: any }
	local failures = {}
	local function add(list: { any })
		for _, f in list do
			table.insert(failures, f)
		end
	end
	add(Task4Checks.shore())
	add(Task4Checks.turtle())
	local g, grounded = Task4Checks.grounding()
	add(g)
	local m, mirrored = Task4Checks.mirror()
	add(m)
	return {
		failures = failures,
		summary = {
			failures = #failures,
			groundingChecked = grounded,
			mirrorPieces = mirrored,
		},
	}
end

return Task4Checks
