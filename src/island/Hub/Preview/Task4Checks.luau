--!strict
-- DEVELOPMENT CHECKS (Lane 3, Task 4). Deterministic checks on the built island, each failure
-- naming the object and its position:
--   shore     decision 0018 §5, as stated: every point of a dry-land piece's footprint is at
--             least LakeMargin (3) studs from the lake waterline and RiverMargin (4) from the
--             river edge. A point fails when it lies inside the lake grown by 3 studs (the
--             irregular shoreline, Field.lakeShape, plus the plunge pool, Cascade.Pool), or within
--             streamWidth / 2 + 4 of the river centre line (Field.riverDistance). The lake
--             distance is measured on rings 0.25 apart in 48 directions, refined by bisection;
--             each failure gives the piece, its worst point and that point's measured distance.
--             Footprint: the bottom face's centre, corners and edge points at most 4 apart.
--             Pieces: ParkDressing, Destinations and Portals (environment) and the river Bridges
--             (hub preview). Exempt: Wet = true, anything under LakeDressing, Waterfall or
--             Fountain, invisible parts, the PortalKit templates; a tree (ParkDressing.Trees)
--             tests only its trunk base, as its canopy may lean over the water. Bridges: the
--             abutments, the mid-span piles and their cap beam are the only pieces allowed in
--             the water (they are the supports); the posts are carried on the deck; the pieces
--             that span the river (deck, fascias, rails, a bridge mesh) test the corners of their
--             two ends (the deck must land on dry bank); every other bridge piece is a full
--             footprint. Flora, GroundCover and LakeDressing (reeds, shore grass) are not tested.
--   beach     (decided with the shore check, Task 4 review J10; reversible) no built piece stands
--             on the dry beach sand: the band between the lake waterline and Field.sample's bank
--             limit (lake e < 1.12) in the beach zone, where the terrain is Sand. The beach is
--             kept open (LakeDressing and GroundCover keep off it too), and a building, board or
--             forecourt on it reads as standing at the water's edge. When the terrain is written
--             a point counts only if the terrain under it really is Sand. A piece meant for the
--             beach sets BeachOk = true (none does today). Failures give the lake distance.
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
--   C.shore()          -- the shore and beach failures only
--   C.snapshot()       -- counts per top folder, for a before / after rebuild comparison

local Cascade = require(script.Parent.Parent.Environment.Cascade)
local Field = require(script.Parent.Parent.Environment.Field)
local KitManifest = require(script.Parent.Parent.Environment.KitManifest)
local Layout = require(script.Parent.Parent.Layout)

local Task4Checks = {}

Task4Checks.GroundTolerance = 0.35 -- studs between a base and the support under it
Task4Checks.BuryTolerance = 1.6 -- studs a base may sit below the ground at its lowest corner
Task4Checks.MirrorTolerance = 0.05
Task4Checks.LakeMargin = 3 -- decision 0018 §5: studs from the lake waterline to any footprint point
Task4Checks.RiverMargin = 4 -- decision 0018 §5: studs from the river edge to any footprint point

-- Pieces allowed over water: they carry Wet = true, or live under these folders. The Bridges are
-- not here: only their supports may stand in the water (BRIDGE_SUPPORTS).
local WET_FOLDERS = { LakeDressing = true, Waterfall = true, Fountain = true }
-- Bridges (Environment/Bridges.luau part names): the supports stand in the water by design; the
-- intermediate posts stand on the deck; the span pieces cross the river and test their ends.
local BRIDGE_SUPPORTS = { Abutment1 = true, Abutment2 = true, Pile1 = true, Pile2 = true, PierCap = true }
local BRIDGE_CARRIED = { Post = true }
local BRIDGE_SPANS = {
	Deck = true,
	Fascia1 = true,
	Fascia2 = true,
	TopRail1 = true,
	TopRail2 = true,
	MidRail1 = true,
	MidRail2 = true,
	Mesh = true,
}
-- Field.sample's lake bank band: e < 1.12 outside the shoreline is bank, Sand in the beach zone.
local BEACH_E = 1.12
local RING_STEP = 0.25
local RING_DIRS = 48
local BEACH_REACH = 16 -- how far the lake distance is measured for a beach failure
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

-- The bottom face of a part as plan points: centre, corners, and edge points at most 4 apart.
local function footprint(part: BasePart): { Vector2 }
	local h = part.Size / 2
	local out = { plan(part.CFrame:PointToWorldSpace(Vector3.new(0, -h.Y, 0))) }
	local nx = math.max(1, math.ceil(part.Size.X / 4))
	local nz = math.max(1, math.ceil(part.Size.Z / 4))
	for i = 0, nx do
		local x = -h.X + part.Size.X * i / nx
		for _, z in { -h.Z, h.Z } do
			table.insert(out, plan(part.CFrame:PointToWorldSpace(Vector3.new(x, -h.Y, z))))
		end
	end
	for k = 1, nz - 1 do
		local z = -h.Z + part.Size.Z * k / nz
		for _, x in { -h.X, h.X } do
			table.insert(out, plan(part.CFrame:PointToWorldSpace(Vector3.new(x, -h.Y, z))))
		end
	end
	return out
end

-- Lake water: the irregular shoreline, or the plunge pool below the falls (joined to the lake;
-- the same test as Field.sample).
local function inLake(p: Vector2): boolean
	if Field.lakeShape(p) then
		return true
	end
	local pool = Cascade.Pool
	local rel = p - pool.centre
	return (rel.X / pool.rx) ^ 2 + (rel.Y / pool.ry) ^ 2 < 1 and p.Y > Cascade.lowerFaceY(p.X) + 0.5
end

local RING: { Vector2 } = {}
for k = 0, RING_DIRS - 1 do
	local a = k / RING_DIRS * math.pi * 2
	table.insert(RING, Vector2.new(math.cos(a), math.sin(a)))
end
local LAKE_MIN_R = math.min(Field.Lake.rx, Field.Lake.ry)
local POOL_R = math.max(Cascade.Pool.rx, Cascade.Pool.ry)

-- Studs from p to the nearest lake water, measured up to `reach`: 0 inside the water, math.huge
-- when there is none within reach. The ellipse value e changes by at most 1 / min(rx, ry) per
-- stud and the lake lies inside e = 1, so a point with e - 1 > reach / min(rx, ry) (and far from
-- the pool) is skipped. Otherwise rings RING_STEP apart in RING_DIRS directions find the first
-- water, and a bisection along that direction refines it to about 0.01 stud.
local function lakeGap(p: Vector2, reach: number): number
	if inLake(p) then
		return 0
	end
	if Field.lakeE(p) - 1 > reach / LAKE_MIN_R and (p - Cascade.Pool.centre).Magnitude > POOL_R + reach then
		return math.huge
	end
	local r = RING_STEP
	while r <= reach + 1e-6 do
		local best = math.huge
		for _, dir in RING do
			if inLake(p + dir * r) then
				local lo, hi = r - RING_STEP, r
				for _ = 1, 5 do
					local mid = (lo + hi) / 2
					if inLake(p + dir * mid) then
						hi = mid
					else
						lo = mid
					end
				end
				best = math.min(best, hi)
			end
		end
		if best < math.huge then
			return best
		end
		r += RING_STEP
	end
	return math.huge
end

local river = Field.river(park.stream, park.streamWidth, (park :: any).riverLoop == true)

-- Studs from p to the river's water edge (negative inside the water).
local function riverGap(p: Vector2): number
	return Field.riverDistance(river, p) - river.half
end

-- On the dry beach sand (see the header): outside the lake, inside Field.sample's bank band, in
-- the beach zone, and, when the terrain is written, on Sand.
local terrainOnly = RaycastParams.new()
terrainOnly.FilterType = Enum.RaycastFilterType.Include
terrainOnly.IgnoreWater = true
local function onBeach(p: Vector2): boolean
	local wet, _, zone = Field.lakeShape(p)
	if wet or zone ~= "beach" or Field.lakeE(p) >= BEACH_E then
		return false
	end
	-- the ground is the terrain or the hub's paving (the portal stage, paths): a piece on paving laid
	-- over the sand band does not stand on the beach
	local ground: { Instance } = { workspace.Terrain }
	local preview = workspace:FindFirstChild("Lane3_IslandPreview")
	if preview then
		table.insert(ground, preview)
	end
	terrainOnly.FilterDescendantsInstances = ground
	local hit = workspace:Raycast(Vector3.new(p.X, 80, -p.Y), Vector3.new(0, -160, 0), terrainOnly)
	return hit == nil or (hit.Instance == workspace.Terrain and hit.Material == Enum.Material.Sand)
end

local function round2(n: number): number
	return math.round(n * 100) / 100
end

-- The pieces the shore rule covers, with how each is tested: "footprint", "trunk", "span".
local function shorePieces(env: Instance): ({ { part: BasePart, role: string } }, number)
	local out = {}
	local supports = 0
	-- the park dressing, the Garage / Stunt / leaderboard destinations and the portal gates
	-- (architecture review M6: the first version tested the dressing only)
	for _, name in { "ParkDressing", "Destinations", "Portals" } do
		local folder = env:FindFirstChild(name)
		if folder then
			for _, d in folder:GetDescendants() do
				if
					d:IsA("BasePart")
					and d.Transparency < 1
					and not wetAllowed(d)
					and not d:FindFirstAncestor("PortalKit")
				then
					-- a tree may lean over the water: only its trunk base must stand on land
					local tree = d:FindFirstAncestor("Trees") ~= nil
					if not tree then
						table.insert(out, { part = d, role = "footprint" })
					elseif d.Name == "Trunk" then
						table.insert(out, { part = d, role = "trunk" })
					end
				end
			end
		end
	end
	-- the river bridges (hub preview, Recipes/Park): see BRIDGE_SUPPORTS
	local preview = workspace:FindFirstChild("Lane3_IslandPreview")
	local bridges = preview and preview:FindFirstChild("Bridges", true)
	if bridges then
		for _, d in bridges:GetDescendants() do
			if d:IsA("BasePart") and d.Transparency < 1 and d:GetAttribute("Wet") ~= true then
				if BRIDGE_SUPPORTS[d.Name] then
					supports += 1
				elseif BRIDGE_SPANS[d.Name] then
					table.insert(out, { part = d, role = "span" })
				elseif not BRIDGE_CARRIED[d.Name] then
					table.insert(out, { part = d, role = "footprint" })
				end
			end
		end
	end
	return out, supports
end

-- Shore and beach failures, the number of pieces tested, and the bridge supports exempted.
local function shoreRun(): ({ any }, number, number)
	local fails = {}
	local env = workspace:FindFirstChild("Lane3_IslandEnvironment")
	if not (env and env:FindFirstChild("ParkDressing")) then
		return { { check = "shore", problem = "no ParkDressing folder" } }, 0, 0
	end
	local pieces, supports = shorePieces(env)
	local lakeNeed, riverNeed = Task4Checks.LakeMargin, Task4Checks.RiverMargin
	for _, piece in pieces do
		local d = piece.part
		local points: { Vector2 }
		if piece.role == "trunk" then
			points = { plan(d.Position) }
		elseif piece.role == "span" then
			points = {}
			local deckWidth = d.Parent and d.Parent:GetAttribute("DeckWidth")
			if d.Name == "Mesh" and type(deckWidth) == "number" then
				-- the kit bridge mesh's bounds take in the wing walls that flare at the abutments
				-- (abutments may stand in the bank): its deck ends are tested at the deck's width
				for _, x in { -d.Size.X / 2, d.Size.X / 2 } do
					for _, z in { -deckWidth / 2, deckWidth / 2 } do
						table.insert(points, plan(d.CFrame:PointToWorldSpace(Vector3.new(x, -d.Size.Y / 2, z))))
					end
				end
			else
				for _, c in corners(d) do
					table.insert(points, plan(c))
				end
			end
		else
			points = footprint(d)
		end
		-- the worst point: the largest shortfall against its margin
		local worst: { [string]: any }? = nil
		local worstShort = 0
		local beachAt: Vector2? = nil
		for _, p in points do
			local lake = lakeGap(p, lakeNeed)
			if lake < lakeNeed and lakeNeed - lake > worstShort then
				worstShort = lakeNeed - lake
				worst = { water = "lake", distance = lake, need = lakeNeed, point = p }
			end
			local rv = riverGap(p)
			if rv < riverNeed and riverNeed - rv > worstShort then
				worstShort = riverNeed - rv
				worst = { water = "river", distance = rv, need = riverNeed, point = p }
			end
			if beachAt == nil and lake > 0 and onBeach(p) then
				beachAt = p
			end
		end
		if worst then
			local pt = worst.point :: Vector2
			table.insert(fails, {
				check = "shore",
				object = d:GetFullName(),
				at = fmt(d.Position),
				point = string.format("(%.1f, %.1f)", pt.X, -pt.Y), -- world X, Z
				water = worst.water,
				distance = round2(worst.distance), -- studs to the water's edge; 0 or less is in it
				need = worst.need,
				tested = piece.role,
			})
		end
		if beachAt and not d:GetAttribute("BeachOk") then
			local gap = lakeGap(beachAt, BEACH_REACH)
			local shown: any = string.format("> %d", BEACH_REACH)
			if gap < math.huge then
				shown = round2(gap)
			end
			table.insert(fails, {
				check = "beach",
				object = d:GetFullName(),
				at = fmt(d.Position),
				point = string.format("(%.1f, %.1f)", beachAt.X, -beachAt.Y),
				lakeDistance = shown, -- studs from that point to the lake waterline
				tested = piece.role,
			})
		end
	end
	return fails, #pieces, supports
end

function Task4Checks.shore(): { any }
	return (shoreRun())
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

-- No tree trunk inside a hub building, a wing forecourt (14 in front) or a leaderboard (Task 4:
-- a lakeside willow stood in the Garage forecourt).
function Task4Checks.treesOnBuildings(): { any }
	local fails = {}
	local env = workspace:FindFirstChild("Lane3_IslandEnvironment")
	if not env then
		return fails
	end
	local boxes = {}
	for _, b in park.buildings do
		local fore = if b.id == "Garage" or b.id == "StuntGate" then 14 else 0
		table.insert(
			boxes,
			{ id = b.id, c = b.centre + b.facing * fore / 2, f = b.facing, w = b.width, d = b.depth + fore }
		)
	end
	for _, b in park.boards do
		table.insert(boxes, { id = b.id, c = b.centre, f = b.facing or Vector2.new(0, 1), w = b.width, d = b.depth })
	end
	for _, d in env:GetDescendants() do
		if d:IsA("BasePart") and d.Name == "Trunk" then
			local p = plan(d.Position)
			for _, b in boxes do
				local side = Vector2.new(-b.f.Y, b.f.X)
				local q = p - b.c
				if math.abs(q:Dot(side)) < b.w / 2 and math.abs(q:Dot(b.f)) < b.d / 2 then
					table.insert(
						fails,
						{ check = "treeOnBuilding", object = d:GetFullName(), at = fmt(d.Position), building = b.id }
					)
				end
			end
		end
	end
	return fails
end

-- Every fence segment end meets the next segment's end (within 0.3) or an end post (within 0.4):
-- no gaps and no bare ends in a run (movement review M8).
function Task4Checks.fences(): ({ any }, number)
	local fails = {}
	local env = workspace:FindFirstChild("Lane3_IslandEnvironment")
	local folder = env and env:FindFirstChild("Fences", true)
	if not folder then
		return fails, 0
	end
	local ends: { { p: Vector2, part: BasePart } } = {}
	local posts: { Vector2 } = {}
	for _, d in folder:GetChildren() do
		if d:IsA("BasePart") and d.Name == "FenceSegment" then
			local half = (KitManifest :: any).FenceSegment.meta.length / 2
			for _, x in { -half, half } do
				table.insert(ends, { p = plan(d.CFrame:PointToWorldSpace(Vector3.new(x, 0, 0))), part = d })
			end
		elseif d:IsA("BasePart") and d:GetAttribute("FenceEnd") then
			table.insert(posts, plan(d.Position))
		end
	end
	for i, e in ends do
		local met = false
		for j, o in ends do
			if j ~= i and o.part ~= e.part and (o.p - e.p).Magnitude <= 0.3 then
				met = true
				break
			end
		end
		if not met then
			for _, q in posts do
				if (q - e.p).Magnitude <= 0.4 then
					met = true
					break
				end
			end
		end
		if not met then
			table.insert(
				fails,
				{ check = "fence", object = e.part:GetFullName(), at = string.format("(%.1f, %.1f)", e.p.X, -e.p.Y) }
			)
		end
	end
	return fails, #ends // 2
end

-- Every signpost carries a board for each destination (movement review M2).
function Task4Checks.signposts(): ({ any }, number)
	local fails = {}
	local posts = 0
	local env = workspace:FindFirstChild("Lane3_IslandEnvironment")
	for _, d in (env and env:GetDescendants() or {}) do
		if d:IsA("BasePart") and d.Name == "SignpostPost" then
			posts += 1
			local n, want = d:GetAttribute("Boards"), d:GetAttribute("BoardsWanted")
			if type(want) == "number" and (type(n) ~= "number" or n < want) then
				table.insert(fails, { check = "signpost", object = d:GetFullName(), at = fmt(d.Position), boards = n })
			end
		end
	end
	return fails, posts
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
	local s, shoreChecked, bridgeSupports = shoreRun()
	add(s)
	add(Task4Checks.turtle())
	add(Task4Checks.treesOnBuildings())
	local g, grounded = Task4Checks.grounding()
	add(g)
	local m, mirrored = Task4Checks.mirror()
	add(m)
	local sp, posts = Task4Checks.signposts()
	add(sp)
	local fe, segments = Task4Checks.fences()
	add(fe)
	return {
		failures = failures,
		summary = {
			failures = #failures,
			signposts = posts,
			fenceSegments = segments,
			shoreChecked = shoreChecked, -- pieces the shore and beach checks tested
			bridgeSupportsExempt = bridgeSupports, -- abutments, piles and pile caps (in the water)
			groundingChecked = grounded,
			mirrorPieces = mirrored,
		},
	}
end

return Task4Checks
