--!strict
-- Lake dressing (Lane 3, build-time): aquatic plants and lake scenery from the island kit, placed
-- by habitat on the lake the terrain writer built (Field.lakeShape: bed height and zone).
--   shallow margins (water 0.3 to 2 deep): reeds, cattails, rushes, arrowhead and irises, in
--     stands, never in the beach's open shallows or the portal view's foreground;
--   lily pads (1.2 to 5 deep, calm water only): colonies of three sizes with a few white and pink
--     flowers, none in the falls' turbulence, the outflow current or the open deep middle;
--   duckweed only in the sheltered marsh and coves;
--   wet-banded part-submerged rocks on the rocky shore, half-sunk driftwood, a line of stepping
--     stones across a marsh shallow (off every walking route), floating leaves and petals on
--     the current toward the outlet;
--   a small dock with a tied rowboat on the north-west shore, outside every corridor and path
--     (scenery only, not transport).
-- Also writes WildlifeAnchors: Attachments the client wildlife script reads (duck routes, frog
-- pads, fish shallows, dragonfly reeds, floating debris).

local Cascade = require(script.Parent.Cascade)
local Field = require(script.Parent.Field)
local KitAssets = require(script.Parent.KitAssets)
local Layout = require(script.Parent.Parent.Layout)

local LakeDressing = {}

local LEVEL = Field.LakeLevel
local lake = Field.Lake
local park = Layout.Data.park

type Ctx = {
	root: Folder,
	anchors: BasePart,
	folders: { [string]: Folder },
	counts: { [string]: number },
	triangles: number,
	rng: Random,
	taken: { { p: Vector2, r: number } },
}

local function folder(ctx: Ctx, name: string): Folder
	local f = ctx.folders[name]
	if not f then
		f = Instance.new("Folder")
		f.Name = name
		f.Parent = ctx.root
		ctx.folders[name] = f
	end
	return f
end

local function free(ctx: Ctx, p: Vector2, r: number): boolean
	for _, t in ctx.taken do
		if (t.p - p).Magnitude < t.r + r then
			return false
		end
	end
	return true
end

local function put(
	ctx: Ctx,
	category: string,
	name: string,
	p: Vector2,
	y: number,
	yaw: number,
	scale: number
): MeshPart
	local base = CFrame.new(p.X, y, -p.Y) * CFrame.Angles(0, yaw, 0)
	local part = KitAssets.place(name, base, scale)
	part.Parent = folder(ctx, category)
	ctx.counts[name] = (ctx.counts[name] or 0) + 1
	ctx.triangles += KitAssets.info(name).triangles
	return part
end

local function anchor(ctx: Ctx, kind: string, at: Vector3, data: { [string]: any }?): Attachment
	local a = Instance.new("Attachment")
	a.Name = kind
	a.Position = at
	for k, v in data or {} do
		a:SetAttribute(k, v)
	end
	a.Parent = ctx.anchors
	return a
end

-- Plan point on the lake at ellipse angle theta (degrees) and radius fraction e.
local function lakePoint(theta: number, e: number): Vector2
	local t = math.rad(theta)
	return lake.centre + Vector2.new(math.cos(t) * lake.rx * e, math.sin(t) * lake.ry * e)
end

local function depthAt(p: Vector2): (number, string)
	local inLake, bed, zone = Field.lakeShape(p)
	if not inLake then
		return 0, zone
	end
	return LEVEL - bed, zone
end

-- Water within this distance of the falls pool or the outlet current is turbulent or flowing.
local function turbulent(p: Vector2): boolean
	if (p - Cascade.Pool.centre).Magnitude < 70 then
		return true
	end
	local outlet = Field.Outlet.points[1]
	return (p - outlet).Magnitude < 60
end

-- The plaza's view of the falls crosses the north shore here; keep it open.
local function portalView(p: Vector2): boolean
	return math.abs(p.X) < 80 and p.Y > lake.centre.Y
end

local function onPath(p: Vector2, margin: number): boolean
	for _, path in park.paths do
		local pts = (path :: any).points
		if pts then
			for i = 1, #pts - 1 do
				local a, b = pts[i], pts[i + 1]
				local ab = b - a
				local t = math.clamp((p - a):Dot(ab) / math.max(ab:Dot(ab), 1e-6), 0, 1)
				if (p - (a + ab * t)).Magnitude < ((path :: any).width or 8) / 2 + margin then
					return true
				end
			end
		end
	end
	return false
end

-- ---------------------------------------------------------------- margins
local MARGIN_KINDS = {
	shelf = { Reeds = 3, Rushes = 2, Cattails = 2, Irises = 1, Arrowhead = 1 },
	marsh = { Cattails = 3, Rushes = 3, Reeds = 2, Arrowhead = 2, Irises = 2 },
	rocky = { Rushes = 2, Reeds = 1 },
	deep = { Reeds = 1 },
}

local function weighted(rng: Random, weights: { [string]: number }): string
	local keys, total = {}, 0
	for k, w in weights do
		table.insert(keys, k)
		total += w
	end
	table.sort(keys)
	local roll = rng:NextNumber() * total
	for _, k in keys do
		roll -= weights[k]
		if roll <= 0 then
			return k
		end
	end
	return keys[#keys]
end

local function buildMargins(ctx: Ctx)
	local stands = 0
	for k = 0, 179 do
		local theta = k * 2 + ctx.rng:NextNumber(-0.8, 0.8)
		-- march in from the shore to the first shallow-margin water
		for e = 1.0, 0.8, -0.01 do
			local p = lakePoint(theta, e)
			local depth, zone = depthAt(p)
			if depth > 0.3 and depth < 1.8 then
				local skip = zone == "beach" or portalView(p) or turbulent(p) or ctx.rng:NextNumber() < 0.35
				if not skip and free(ctx, p, 4) then
					local kinds = MARGIN_KINDS[zone] or MARGIN_KINDS.shelf
					local kind = weighted(ctx.rng, kinds)
					local n = ctx.rng:NextInteger(2, 4)
					for j = 1, n do
						local q = p + Vector2.new(ctx.rng:NextNumber(-3, 3), ctx.rng:NextNumber(-3, 3))
						local d = depthAt(q)
						if d > 0.2 and d < 2.0 then
							put(
								ctx,
								"Margins",
								kind,
								q,
								LEVEL,
								ctx.rng:NextNumber(0, 6.28),
								ctx.rng:NextNumber(0.85, 1.2)
							)
							if j == 1 and (kind == "Reeds" or kind == "Cattails") and stands % 4 == 0 then
								anchor(ctx, "DragonflyReeds", Vector3.new(q.X, LEVEL + 2.5, -q.Y))
							end
						end
					end
					table.insert(ctx.taken, { p = p, r = 4 })
					stands += 1
				end
				break
			end
		end
	end
	ctx.counts.marginStands = stands
end

-- ---------------------------------------------------------------- lily pads and duckweed
local function buildLilies(ctx: Ctx)
	local colonies = 0
	local tries = 0
	while colonies < 14 and tries < 600 do
		tries += 1
		local theta = ctx.rng:NextNumber(-180, 180)
		local e = ctx.rng:NextNumber(0.7, 0.93)
		local p = lakePoint(theta, e)
		local depth, zone = depthAt(p)
		if depth > 1.2 and depth < 5 and zone ~= "deep" and zone ~= "beach" and not turbulent(p) then
			if free(ctx, p, 9) then
				colonies += 1
				local n = ctx.rng:NextInteger(7, 14)
				for j = 1, n do
					local q = p + Vector2.new(ctx.rng:NextNumber(-6, 6), ctx.rng:NextNumber(-4, 4))
					local d = depthAt(q)
					if d > 0.9 then
						local roll = ctx.rng:NextNumber()
						local name = if roll < 0.1
							then "LilyFlowerWhite"
							elseif roll < 0.16 then "LilyFlowerPink"
							elseif roll < 0.45 then "LilyPadS"
							elseif roll < 0.8 then "LilyPadM"
							else "LilyPadL"
						local pad = put(ctx, "Lilies", name, q, LEVEL - 0.04, ctx.rng:NextNumber(0, 6.28), 1)
						if name == "LilyPadL" and j % 3 == 0 then
							anchor(ctx, "FrogPad", pad.Position + Vector3.new(0, 0.1, 0))
						end
					end
				end
				table.insert(ctx.taken, { p = p, r = 8 })
			end
		end
	end
	ctx.counts.lilyColonies = colonies
	-- duckweed: still sheltered corners only (the marsh and the two quiet coves)
	for _, spot in { { -2, 0.9 }, { 10, 0.92 }, { 22, 0.88 }, { 160, 0.92 } } do
		local p = lakePoint(spot[1], spot[2])
		local depth = depthAt(p)
		if depth > 0.2 and not turbulent(p) then
			put(ctx, "Lilies", "Duckweed", p, LEVEL - 0.02, ctx.rng:NextNumber(0, 6.28), ctx.rng:NextNumber(1.2, 1.8))
		end
	end
end

-- ---------------------------------------------------------------- rocks, driftwood, stones
local function buildShore(ctx: Ctx)
	local rocks = 0
	for k = 0, 47 do
		local theta = -140 + k * 1.1 + ctx.rng:NextNumber(-0.5, 0.5)
		for e = 1.02, 0.88, -0.01 do
			local p = lakePoint(theta, e)
			local depth, zone = depthAt(p)
			if depth > 0.4 and zone == "rocky" then
				if ctx.rng:NextNumber() < 0.45 and free(ctx, p, 2.5) then
					local big = ctx.rng:NextNumber() < 0.35
					local s = ctx.rng:NextNumber(0.8, 1.3)
					-- set so the water line crosses the rock's wet band
					put(
						ctx,
						"Shore",
						if big then "WetRockB" else "WetRockA",
						p,
						LEVEL - 0.3,
						ctx.rng:NextNumber(0, 6.28),
						s
					)
					rocks += 1
					table.insert(ctx.taken, { p = p, r = 2.5 })
				end
				break
			end
		end
	end
	ctx.counts.wetRocks = rocks
	-- half-sunk driftwood at the marsh edge and the west cove
	for _, spot in { { 18, 0.97 }, { 165, 0.96 }, { -40, 0.97 } } do
		local p = lakePoint(spot[1], spot[2])
		put(ctx, "Shore", "Driftwood", p, LEVEL - 0.15, math.rad(spot[1] + 90), 1)
	end
	-- stepping stones across a marsh shallow, kept off the walks
	local a, b = lakePoint(2, 0.985), lakePoint(14, 0.985)
	for j = 0, 5 do
		local p = a:Lerp(b, j / 5) + Vector2.new(0, ctx.rng:NextNumber(-0.6, 0.6))
		if not onPath(p, 3) then
			put(
				ctx,
				"Shore",
				"SteppingStone",
				p,
				LEVEL - 0.05,
				ctx.rng:NextNumber(0, 6.28),
				ctx.rng:NextNumber(0.9, 1.1)
			)
		end
	end
	-- floating leaves and petals along the current from the falls to the outlet
	local from, to = Cascade.Pool.centre + Vector2.new(30, 30), Field.Outlet.points[1]
	for j = 1, 9 do
		local p = from:Lerp(to, j / 10) + Vector2.new(ctx.rng:NextNumber(-12, 12), ctx.rng:NextNumber(-12, 12))
		if depthAt(p) > 0.5 then
			local leaf = put(
				ctx,
				"Debris",
				if j % 3 == 0 then "FloatingPetal" else "FloatingLeaf",
				p,
				LEVEL - 0.02,
				ctx.rng:NextNumber(0, 6.28),
				1
			)
			leaf:SetAttribute("DriftTo", Vector3.new(to.X, LEVEL - 0.02, -to.Y))
			anchor(ctx, "FloatingDebris", leaf.Position)
		end
	end
end

-- ---------------------------------------------------------------- dock and rowboat
local function buildDock(ctx: Ctx): Vector2?
	local reasons = {}
	for _, theta in { 132, 140, 124, 148, 116, 156, 108, 36, 44, 172, -168 } do
		-- the shore point at this angle
		local shore: Vector2? = nil
		for e = 0.85, 1.05, 0.005 do
			local p = lakePoint(theta, e)
			if depthAt(p) <= 0.05 then
				shore = p
				break
			end
		end
		if not shore then
			table.insert(reasons, theta .. ":noShore")
		elseif portalView(shore) then
			table.insert(reasons, theta .. ":view")
		else
			-- the shore end may meet a walk; the part over the water must stay off every path
			local inward = (lake.centre - shore).Unit
			local start = shore - inward * 2
			local length = KitAssets.info("Dock").meta.length or 18
			local tip = start + inward * length
			local mid = start:Lerp(tip, 0.5)
			local why = if depthAt(tip) <= 1.2
				then "shallowTip"
				elseif turbulent(tip) then "turbulent"
				elseif onPath(mid, 1) or onPath(tip, 1) then "path"
				elseif not free(ctx, mid, 10) then "taken"
				else nil
			if why then
				table.insert(reasons, theta .. ":" .. why)
			else
				put(ctx, "Dock", "Dock", start, LEVEL, math.atan2(inward.Y, inward.X), 1)
				local side = Vector2.new(-inward.Y, inward.X)
				local boatAt = start + inward * (length - 4) + side * 5
				local boat = put(ctx, "Dock", "Rowboat", boatAt, LEVEL - 0.1, math.atan2(inward.Y, inward.X) + 0.25, 1)
				boat:SetAttribute("Bob", 0.08)
				table.insert(ctx.taken, { p = start:Lerp(tip, 0.5), r = 11 })
				return start
			end
		end
	end
	ctx.root:SetAttribute("DockRejected", table.concat(reasons, " "))
	return nil
end

-- ---------------------------------------------------------------- wildlife anchors on the water
local function buildWaterAnchors(ctx: Ctx)
	-- one duck family route: a loop on calm shelf water off the north-east shore
	local route = {}
	for k = 0, 7 do
		local theta = 30 + 22 * math.sin(k / 8 * math.pi * 2)
		local e = 0.74 + 0.08 * math.cos(k / 8 * math.pi * 2)
		local p = lakePoint(theta, e)
		table.insert(route, Vector3.new(p.X, LEVEL, -p.Y))
	end
	for i, v in route do
		anchor(ctx, "DuckRoute", v, { Index = i })
	end
	-- fish in a few shallows
	for _, spot in { { 60, 0.9 }, { 150, 0.88 }, { -30, 0.85 }, { 100, 0.86 } } do
		local p = lakePoint(spot[1], spot[2])
		if depthAt(p) > 0.8 then
			anchor(ctx, "FishShallows", Vector3.new(p.X, LEVEL - 0.6, -p.Y), { Radius = 7 })
		end
	end
end

export type Report = { counts: { [string]: number }, triangles: number, dock: Vector2?, seconds: number }

function LakeDressing.build(parent: Instance, seed: number): Report
	local started = os.clock()
	local old = parent:FindFirstChild("LakeDressing")
	if old then
		old:Destroy()
	end
	local root = Instance.new("Folder")
	root.Name = "LakeDressing"
	local anchors = Instance.new("Part")
	anchors.Name = "WildlifeAnchors"
	anchors.Anchored = true
	anchors.CanCollide = false
	anchors.CanQuery = false
	anchors.CanTouch = false
	anchors.Transparency = 1
	anchors.Size = Vector3.one
	anchors.CFrame = CFrame.new()
	anchors.Parent = root
	local ctx: Ctx = {
		root = root,
		anchors = anchors,
		folders = {},
		counts = {},
		triangles = 0,
		rng = Random.new(seed + 505),
		taken = {},
	}
	local dock = buildDock(ctx)
	buildShore(ctx)
	buildMargins(ctx)
	task.wait()
	buildLilies(ctx)
	buildWaterAnchors(ctx)
	if dock then
		root:SetAttribute("DockAt", Vector3.new(dock.X, LEVEL, -dock.Y))
	end
	root.Parent = parent
	return {
		counts = ctx.counts,
		triangles = ctx.triangles,
		dock = dock,
		seconds = math.round((os.clock() - started) * 100) / 100,
	}
end

return LakeDressing
