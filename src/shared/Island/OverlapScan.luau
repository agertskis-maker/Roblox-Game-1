--!strict
-- DEVELOPMENT DIAGNOSTIC (Lane 3). Finds surfaces that flicker in any scene: visible faces that
-- share a plane and overlap. Run it on demand from Studio (Edit or Play); it is never required by
-- game code and never runs per frame.
--
--   local Scan = require(game.ReplicatedStorage.Shared.Island.OverlapScan)
--   local report = Scan.run({ roots = { workspace.Lane3_IslandPreview } })
--   print(Scan.text(report))
--   Scan.mark(report)         -- a tall neon beam at each flicker finding
--   Scan.clearMarkers()
--   Scan.selfTest()           -- the tiny diagnostic scene (M1-04a), expected versus observed
--
-- How it works: every visible static surface is collected once. A 2D grid over world bounds, grown
-- by the plane tolerance, gives nearby pairs; each pair is deduplicated by index. The narrow phase
-- compares real face polygons, so a WedgePart contributes its slope and triangles, not the six
-- faces of its box. Only faces pointing the SAME way can fight: of two faces back to back, each
-- one's back is culled, so a shared interior wall is never visible flicker.
--
-- What it cannot see. MeshPart bounds and hulls are not the visible triangles, so a MeshPart never
-- proves or clears a coplanar face here: those, Unions, Balls and SpecialMeshes are counted under
-- `manual` and need a source mesh check or a grazing camera. Curved cylinder walls likewise. Terrain
-- is treated only as something that buries a face.

local OverlapScan = {}

-- abs(dot) at or above this counts as parallel
local PARALLEL = 0.9998
local FLICKER_DIST = 0.02
local NEAR_DIST = 0.05
local MIN_AREA = 0.01
local MIN_AREA_FRACTION = 0.001
local CELL = 32
local MAX_CELLS = 400
local CYLINDER_SIDES = 16
local YIELD_EVERY = 4000

export type Severity = "flicker" | "near" | "sameLook" | "hidden" | "underside"

export type Finding = {
	severity: Severity,
	a: string,
	b: string,
	position: Vector3,
	area: number,
	distance: number,
	thin: boolean,
	exception: string?,
}

export type Exception = { pattern: string, reason: string }

export type Options = {
	roots: { Instance },
	-- true leaves the part out of the scan altogether (moving props, effects)
	ignore: ((BasePart) -> boolean)?,
	-- a Lua pattern tested against "pathA|pathB"; a match is listed under its reason, not counted
	exceptions: { Exception }?,
	-- false skips the terrain burial test (no terrain in the scene)
	terrain: boolean?,
}

export type Report = {
	surfaces: number,
	pairsChecked: number,
	narrowFaces: number,
	seconds: number,
	findings: { Finding },
	counts: { [string]: number },
	manual: { [string]: number },
	excepted: { Finding },
}

type Face = {
	normal: Vector3,
	points: { Vector3 },
	area: number,
}

type Surface = {
	part: BasePart,
	path: string,
	min: Vector3,
	max: Vector3,
	faces: { Face },
	solid: boolean,
	moved: boolean?,
}

local function polygonArea3(points: { Vector3 }, normal: Vector3): number
	local sum = Vector3.zero
	for i = 1, #points do
		sum += points[i]:Cross(points[i % #points + 1])
	end
	return math.abs(sum:Dot(normal)) / 2
end

-- `outward` is a local direction on the outer side of the face, needed for a slope that passes
-- through the part's own centre.
local function face(cf: CFrame, locals: { Vector3 }, outward: Vector3): Face
	local points = table.create(#locals)
	for i, p in locals do
		points[i] = cf:PointToWorldSpace(p)
	end
	local normal = (points[2] - points[1]):Cross(points[3] - points[1]).Unit
	if normal:Dot(cf:VectorToWorldSpace(outward)) < 0 then
		normal = -normal
	end
	return { normal = normal, points = points, area = polygonArea3(points, normal) }
end

local function blockFaces(cf: CFrame, x: number, y: number, z: number): { Face }
	local function v(a: number, b: number, c: number): Vector3
		return Vector3.new(a * x, b * y, c * z)
	end
	return {
		face(cf, { v(1, -1, -1), v(1, 1, -1), v(1, 1, 1), v(1, -1, 1) }, Vector3.xAxis),
		face(cf, { v(-1, -1, -1), v(-1, 1, -1), v(-1, 1, 1), v(-1, -1, 1) }, -Vector3.xAxis),
		face(cf, { v(-1, 1, -1), v(1, 1, -1), v(1, 1, 1), v(-1, 1, 1) }, Vector3.yAxis),
		face(cf, { v(-1, -1, -1), v(1, -1, -1), v(1, -1, 1), v(-1, -1, 1) }, -Vector3.yAxis),
		face(cf, { v(-1, -1, 1), v(1, -1, 1), v(1, 1, 1), v(-1, 1, 1) }, Vector3.zAxis),
		face(cf, { v(-1, -1, -1), v(1, -1, -1), v(1, 1, -1), v(-1, 1, -1) }, -Vector3.zAxis),
	}
end

-- WedgePart: low edge at -Z, tall back wall at +Z (checked by raycast in selfTest).
local function wedgeFaces(cf: CFrame, x: number, y: number, z: number): { Face }
	local a, b = Vector3.new(-x, -y, -z), Vector3.new(x, -y, -z)
	local c, d = Vector3.new(x, -y, z), Vector3.new(-x, -y, z)
	local e, f = Vector3.new(-x, y, z), Vector3.new(x, y, z)
	return {
		face(cf, { a, b, c, d }, -Vector3.yAxis),
		face(cf, { d, c, f, e }, Vector3.zAxis),
		face(cf, { a, b, f, e }, Vector3.new(0, z, -y)),
		face(cf, { a, d, e }, -Vector3.xAxis),
		face(cf, { b, c, f }, Vector3.xAxis),
	}
end

-- CornerWedgePart: square base, apex above the (+X, -Z) corner (checked by raycast in selfTest).
local function cornerWedgeFaces(cf: CFrame, x: number, y: number, z: number): { Face }
	local a, b = Vector3.new(-x, -y, -z), Vector3.new(x, -y, -z)
	local c, d = Vector3.new(x, -y, z), Vector3.new(-x, -y, z)
	local apex = Vector3.new(x, y, -z)
	return {
		face(cf, { a, b, c, d }, -Vector3.yAxis),
		face(cf, { b, c, apex }, Vector3.xAxis),
		face(cf, { a, b, apex }, -Vector3.zAxis),
		face(cf, { d, a, apex }, Vector3.new(-y, x, 0)),
		face(cf, { c, d, apex }, Vector3.new(0, z, y)),
	}
end

local function cylinderEnds(cf: CFrame, x: number, y: number, z: number): { Face }
	local r = math.min(y, z)
	local faces = {}
	for _, side in { 1, -1 } do
		local ring = table.create(CYLINDER_SIDES)
		for i = 1, CYLINDER_SIDES do
			local a = (i - 1) / CYLINDER_SIDES * 2 * math.pi
			ring[i] = Vector3.new(side * x, math.cos(a) * r, math.sin(a) * r)
		end
		table.insert(faces, face(cf, ring, Vector3.xAxis * side))
	end
	return faces
end

local function bounds(part: BasePart): (Vector3, Vector3)
	local cf = part.CFrame
	local s = part.Size / 2
	local r, u, l = cf.RightVector, cf.UpVector, cf.LookVector
	local e = Vector3.new(
		math.abs(r.X) * s.X + math.abs(u.X) * s.Y + math.abs(l.X) * s.Z,
		math.abs(r.Y) * s.X + math.abs(u.Y) * s.Y + math.abs(l.Y) * s.Z,
		math.abs(r.Z) * s.X + math.abs(u.Z) * s.Y + math.abs(l.Z) * s.Z
	)
	return cf.Position - e, cf.Position + e
end

local function hasSpecialMesh(part: BasePart): boolean
	return part:FindFirstChildWhichIsA("SpecialMesh") ~= nil
end

-- The real faces of a part, or nil and a `manual` bucket name when it has none we can trust.
local function facesOf(part: BasePart): ({ Face }?, string?)
	if part:IsA("MeshPart") then
		return nil, "meshParts"
	end
	if part:IsA("UnionOperation") or part:IsA("NegateOperation") then
		return nil, "unions"
	end
	if hasSpecialMesh(part) then
		return nil, "specialMeshes"
	end
	local cf = part.CFrame
	local s = part.Size / 2
	if part:IsA("WedgePart") then
		return wedgeFaces(cf, s.X, s.Y, s.Z), nil
	end
	if part:IsA("CornerWedgePart") then
		return cornerWedgeFaces(cf, s.X, s.Y, s.Z), nil
	end
	if part:IsA("Part") then
		local shape = part.Shape
		if shape == Enum.PartType.Block then
			return blockFaces(cf, s.X, s.Y, s.Z), nil
		elseif shape == Enum.PartType.Cylinder then
			return cylinderEnds(cf, s.X, s.Y, s.Z), nil
		elseif shape == Enum.PartType.Wedge then
			return wedgeFaces(cf, s.X, s.Y, s.Z), nil
		elseif shape == Enum.PartType.CornerWedge then
			return cornerWedgeFaces(cf, s.X, s.Y, s.Z), nil
		end
		return nil, "balls"
	end
	return nil, "other"
end

local function signedArea(poly: { Vector2 }): number
	local sum = 0
	for i = 1, #poly do
		local a, b = poly[i], poly[i % #poly + 1]
		sum += a.X * b.Y - b.X * a.Y
	end
	return sum / 2
end

-- Sutherland-Hodgman: the part of convex `subject` inside convex counter-clockwise `clipper`.
local function clip(subject: { Vector2 }, clipper: { Vector2 }): { Vector2 }
	local output = subject
	for i = 1, #clipper do
		if #output == 0 then
			break
		end
		local a, b = clipper[i], clipper[i % #clipper + 1]
		local edge = b - a
		local function inside(p: Vector2): boolean
			return edge.X * (p.Y - a.Y) - edge.Y * (p.X - a.X) >= -1e-9
		end
		local input = output
		output = {}
		for k = 1, #input do
			local p, q = input[k], input[k % #input + 1]
			local pIn, qIn = inside(p), inside(q)
			if pIn then
				table.insert(output, p)
			end
			if pIn ~= qIn then
				local d = q - p
				local den = edge.X * d.Y - edge.Y * d.X
				if math.abs(den) > 1e-12 then
					local t = (edge.Y * (p.X - a.X) - edge.X * (p.Y - a.Y)) / den
					table.insert(output, p + d * t)
				end
			end
		end
	end
	return output
end

local function basis(normal: Vector3): (Vector3, Vector3)
	local helper = if math.abs(normal.Y) < 0.9 then Vector3.yAxis else Vector3.xAxis
	local u = normal:Cross(helper).Unit
	return u, normal:Cross(u)
end

local function project(points: { Vector3 }, origin: Vector3, u: Vector3, v: Vector3): { Vector2 }
	local out = table.create(#points)
	for i, p in points do
		local d = p - origin
		out[i] = Vector2.new(d:Dot(u), d:Dot(v))
	end
	if signedArea(out) < 0 then
		local n = #out
		for i = 1, math.floor(n / 2) do
			out[i], out[n - i + 1] = out[n - i + 1], out[i]
		end
	end
	return out
end

-- Overlap of two parallel same-way faces: area, centroid and thinness, or nil.
local function overlap(a: Face, b: Face): (number, Vector3?, boolean)
	local origin = a.points[1]
	local u, v = basis(a.normal)
	local inter = clip(project(b.points, origin, u, v), project(a.points, origin, u, v))
	if #inter < 3 then
		return 0, nil, false
	end
	local area = math.abs(signedArea(inter))
	local sum = Vector2.zero
	local minX, maxX, minY, maxY = math.huge, -math.huge, math.huge, -math.huge
	for _, p in inter do
		sum += p
		minX, maxX = math.min(minX, p.X), math.max(maxX, p.X)
		minY, maxY = math.min(minY, p.Y), math.max(maxY, p.Y)
	end
	sum /= #inter
	local thin = math.min(maxX - minX, maxY - minY) < 0.25 and math.max(maxX - minX, maxY - minY) > 2
	return area, origin + u * sum.X + v * sum.Y, thin
end

local function sameLook(p: BasePart, q: BasePart): boolean
	local a, b = p.Color, q.Color
	return p.Material == q.Material
		and p.Transparency == q.Transparency
		and p.Reflectance == q.Reflectance
		and math.abs(a.R - b.R) < 0.004
		and math.abs(a.G - b.G) < 0.004
		and math.abs(a.B - b.B) < 0.004
end

local function insideBlock(s: Surface, p: Vector3): boolean
	local part = s.part
	local q = part.CFrame:PointToObjectSpace(p)
	local h = part.Size / 2
	return math.abs(q.X) < h.X and math.abs(q.Y) < h.Y and math.abs(q.Z) < h.Z
end

local function cellKey(x: number, z: number): number
	return (x + 40000) * 100000 + (z + 40000)
end

local function underTerrain(p: Vector3): boolean
	local half = Vector3.new(2, 2, 2)
	local region = Region3.new(p - half, p + half):ExpandToGrid(4)
	local materials, occupancy = workspace.Terrain:ReadVoxels(region, 4)
	local m = materials[1] and materials[1][1] and materials[1][1][1]
	local o = occupancy[1] and occupancy[1][1] and occupancy[1][1][1]
	return m ~= nil and m ~= Enum.Material.Air and m ~= Enum.Material.Water and (o or 0) >= 1
end

local function shortPath(part: Instance): string
	local path = part:GetFullName()
	return (string.gsub(path, "^Workspace%.", ""))
end

function OverlapScan.run(options: Options): Report
	local started = os.clock()
	local useTerrain = options.terrain ~= false
	local manual: { [string]: number } = {
		meshParts = 0,
		unions = 0,
		specialMeshes = 0,
		balls = 0,
		other = 0,
		cylinderWalls = 0,
	}
	local surfaces: { Surface } = {}
	for _, root in options.roots do
		local list = root:GetDescendants()
		table.insert(list, root)
		for _, d in list do
			if d:IsA("BasePart") and d.Transparency < 1 and not (d:IsA("Terrain")) then
				if options.ignore and options.ignore(d) then
					continue
				end
				local faces, bucket = facesOf(d)
				if faces then
					local lo, hi = bounds(d)
					local p = d :: any
					local shape = if d:IsA("Part") then p.Shape else nil
					if shape == Enum.PartType.Cylinder then
						manual.cylinderWalls += 1
					end
					table.insert(surfaces, {
						part = d,
						path = "",
						min = lo,
						max = hi,
						faces = faces,
						solid = shape == Enum.PartType.Block and d.Transparency < 0.05,
					})
				elseif bucket then
					manual[bucket] += 1
				end
			end
		end
	end

	-- grid over world XZ bounds, grown by the near tolerance
	local grid: { [number]: { number } } = {}
	local big: { number } = {}
	local pad = Vector3.one * (NEAR_DIST + 0.01)
	for i, s in surfaces do
		local x0, x1 = math.floor((s.min.X - pad.X) / CELL), math.floor((s.max.X + pad.X) / CELL)
		local z0, z1 = math.floor((s.min.Z - pad.Z) / CELL), math.floor((s.max.Z + pad.Z) / CELL)
		if (x1 - x0 + 1) * (z1 - z0 + 1) > MAX_CELLS then
			table.insert(big, i)
		else
			for x = x0, x1 do
				for z = z0, z1 do
					local key = cellKey(x, z)
					local bucket = grid[key]
					if bucket then
						table.insert(bucket, i)
					else
						grid[key] = { i }
					end
				end
			end
		end
	end

	local findings: { Finding } = {}
	local excepted: { Finding } = {}
	local counts: { [string]: number } =
		{ flicker = 0, near = 0, sameLook = 0, hidden = 0, underside = 0, excepted = 0 }
	local seen: { [number]: boolean } = {}
	local pairsChecked, narrowFaces = 0, 0
	local n = #surfaces
	local work = 0

	local function solidsNear(p: Vector3): { number }?
		return grid[cellKey(math.floor(p.X / CELL), math.floor(p.Z / CELL))]
	end

	local function buried(p: Vector3, i: number, j: number): boolean
		local near = solidsNear(p)
		if near then
			for _, k in near do
				if k ~= i and k ~= j then
					local s = surfaces[k]
					if s.solid and insideBlock(s, p) then
						return true
					end
				end
			end
		end
		for _, k in big do
			if k ~= i and k ~= j then
				local s = surfaces[k]
				if s.solid and insideBlock(s, p) then
					return true
				end
			end
		end
		return useTerrain and underTerrain(p)
	end

	local function classify(a: Surface, b: Surface, i: number, j: number, fa: Face, fb: Face)
		local dot = fa.normal:Dot(fb.normal)
		if dot < PARALLEL then
			return
		end
		narrowFaces += 1
		local worst = 0
		for _, p in fb.points do
			worst = math.max(worst, math.abs((p - fa.points[1]):Dot(fa.normal)))
			if worst > NEAR_DIST then
				return
			end
		end
		local area, centre, thin = overlap(fa, fb)
		local floor = math.max(MIN_AREA, MIN_AREA_FRACTION * math.min(fa.area, fb.area))
		if not centre or (area <= floor and not (thin and area > MIN_AREA)) then
			return
		end
		local severity: Severity
		if fa.normal.Y < -0.7 then
			severity = "underside"
		elseif sameLook(a.part, b.part) then
			severity = "sameLook"
		elseif buried(centre + fa.normal * 0.08, i, j) then
			severity = "hidden"
		elseif worst <= FLICKER_DIST then
			severity = "flicker"
		else
			severity = "near"
		end
		if a.path == "" then
			a.path = shortPath(a.part)
		end
		if b.path == "" then
			b.path = shortPath(b.part)
		end
		local finding: Finding = {
			severity = severity,
			a = a.path,
			b = b.path,
			position = centre,
			area = math.round(area * 1000) / 1000,
			distance = math.round(worst * 1000) / 1000,
			thin = thin,
			exception = nil,
		}
		if options.exceptions and (severity == "flicker" or severity == "near") then
			local key = a.path .. "|" .. b.path
			for _, ex in options.exceptions do
				if string.find(key, ex.pattern) then
					finding.exception = ex.reason
					table.insert(excepted, finding)
					counts.excepted += 1
					return
				end
			end
		end
		counts[severity] += 1
		table.insert(findings, finding)
	end

	local function test(i: number, j: number)
		if i == j then
			return
		end
		if i > j then
			i, j = j, i
		end
		local key = i * (n + 1) + j
		if seen[key] then
			return
		end
		seen[key] = true
		local a, b = surfaces[i], surfaces[j]
		local e = NEAR_DIST + 0.01
		if
			a.max.X + e < b.min.X
			or b.max.X + e < a.min.X
			or a.max.Y + e < b.min.Y
			or b.max.Y + e < a.min.Y
			or a.max.Z + e < b.min.Z
			or b.max.Z + e < a.min.Z
		then
			return
		end
		pairsChecked += 1
		for _, fa in a.faces do
			for _, fb in b.faces do
				classify(a, b, i, j, fa, fb)
			end
		end
		work += 1
		if work % YIELD_EVERY == 0 then
			task.wait()
		end
	end

	for _, bucket in grid do
		for x = 1, #bucket do
			for y = x + 1, #bucket do
				test(bucket[x], bucket[y])
			end
		end
	end
	for _, i in big do
		for j = 1, n do
			test(i, j)
		end
	end

	table.sort(findings, function(a, b)
		return a.area > b.area
	end)
	return {
		surfaces = n,
		pairsChecked = pairsChecked,
		narrowFaces = narrowFaces,
		seconds = math.round((os.clock() - started) * 100) / 100,
		findings = findings,
		counts = counts,
		manual = manual,
		excepted = excepted,
	}
end

-- Reduces a path to its recipe: digits gone, so PlotNN and repeats group together.
local function signature(path: string): string
	local parts = string.split(path, ".")
	local tail = parts[#parts]
	local prev = parts[#parts - 1] or ""
	return (string.gsub(prev .. "." .. tail, "%d+", "#"))
end

function OverlapScan.text(report: Report, limit: number?): string
	local lines = {
		string.format(
			"Surfaces %d, candidate pairs %d, parallel face tests %d, %.2f s",
			report.surfaces,
			report.pairsChecked,
			report.narrowFaces,
			report.seconds
		),
		string.format(
			"FLICKER %d | near %d | same look %d | hidden %d | underside %d | listed exceptions %d",
			report.counts.flicker,
			report.counts.near,
			report.counts.sameLook,
			report.counts.hidden,
			report.counts.underside,
			report.counts.excepted
		),
		string.format(
			"Not provable here (manual): MeshParts %d, Unions %d, SpecialMeshes %d, Balls %d, cylinder walls %d",
			report.manual.meshParts,
			report.manual.unions,
			report.manual.specialMeshes,
			report.manual.balls,
			report.manual.cylinderWalls
		),
	}
	local groups: { [string]: { n: number, area: number, sample: Finding } } = {}
	local order: { string } = {}
	for _, f in report.findings do
		if f.severity == "flicker" or f.severity == "near" then
			local sigA, sigB = signature(f.a), signature(f.b)
			if sigA > sigB then
				sigA, sigB = sigB, sigA
			end
			local key = f.severity .. "  " .. sigA .. " x " .. sigB
			local g = groups[key]
			if g then
				g.n += 1
				g.area += f.area
			else
				groups[key] = { n = 1, area = f.area, sample = f }
				table.insert(order, key)
			end
		end
	end
	table.sort(order, function(a, b)
		return groups[a].area > groups[b].area
	end)
	for i, key in order do
		if i > (limit or 40) then
			table.insert(lines, string.format("... and %d more groups", #order - i + 1))
			break
		end
		local g = groups[key]
		local p = g.sample.position
		table.insert(
			lines,
			string.format("%4d x %s  total %.2f sq, e.g. (%.1f, %.1f, %.1f)", g.n, key, g.area, p.X, p.Y, p.Z)
		)
	end
	for _, f in report.excepted do
		table.insert(lines, string.format("exception: %s | %s: %s", f.a, f.b, f.exception or ""))
	end
	return table.concat(lines, "\n")
end

local MARKER_ROOT = "Lane3_OverlapMarkers"

function OverlapScan.clearMarkers()
	local old = workspace:FindFirstChild(MARKER_ROOT)
	if old then
		old:Destroy()
	end
end

-- Temporary beams for screenshots: flicker red, near orange. Clear them before saving a place.
function OverlapScan.mark(report: Report, limit: number?): number
	OverlapScan.clearMarkers()
	local folder = Instance.new("Folder")
	folder.Name = MARKER_ROOT
	local made = 0
	for _, f in report.findings do
		if (f.severity == "flicker" or f.severity == "near") and made < (limit or 400) then
			local beam = Instance.new("Part")
			beam.Anchored = true
			beam.CanCollide = false
			beam.CanQuery = false
			beam.CanTouch = false
			beam.CastShadow = false
			beam.Material = Enum.Material.Neon
			beam.Color = if f.severity == "flicker" then Color3.fromRGB(255, 40, 40) else Color3.fromRGB(255, 160, 40)
			beam.Size = Vector3.new(0.4, 30, 0.4)
			beam.Position = f.position + Vector3.new(0, 15, 0)
			beam.Parent = folder
			made += 1
		end
	end
	folder.Parent = workspace
	return made
end

-- Is anything solid under the model's footprint? Rays from several footprint points, not only the
-- pivot, so a bench with one leg on a kerb is still supported. Returns the smallest gap between the
-- model's underside and what lies below it (negative when the base is sunk), or nil if nothing is
-- below at all. Buried foundations are not floating errors: callers test gap > their tolerance.
function OverlapScan.supportGap(model: Model | BasePart, params: RaycastParams): number?
	local cf: CFrame, size: Vector3
	if model:IsA("Model") then
		cf, size = model:GetBoundingBox()
	else
		cf, size = model.CFrame, model.Size
	end
	local h = size / 2
	local best: number? = nil
	for _, s in { { 0, 0 }, { 0.8, 0.8 }, { -0.8, 0.8 }, { 0.8, -0.8 }, { -0.8, -0.8 } } do
		local top = cf:PointToWorldSpace(Vector3.new(h.X * s[1], 0, h.Z * s[2]))
		local base = top.Y - h.Y
		local hit = workspace:Raycast(top + Vector3.new(0, h.Y + 1, 0), Vector3.new(0, -(size.Y + 60), 0), params)
		if hit then
			local gap = base - hit.Position.Y
			best = if best then math.min(best, gap) else gap
		end
	end
	return best
end

function OverlapScan.tiltDegrees(cf: CFrame): number
	return math.deg(math.acos(math.clamp(cf.UpVector.Y, -1, 1)))
end

-- The tiny diagnostic scene (M1-04a), built high above the map and removed again. Each case names
-- the worst class it should produce. Returns lines for the ledger.
function OverlapScan.selfTest(): { string }
	local folder = Instance.new("Folder")
	folder.Name = "Lane3_OverlapSelfTest"
	folder.Parent = workspace
	local base = CFrame.new(0, 900, 0)
	local red, blue = Color3.fromRGB(220, 40, 40), Color3.fromRGB(40, 60, 220)
	local function block(parent: Instance, size: Vector3, cf: CFrame, colour: Color3): Part
		local p = Instance.new("Part")
		p.Anchored = true
		p.CanCollide = true
		p.Size = size
		p.CFrame = cf
		p.Color = colour
		p.Material = Enum.Material.SmoothPlastic
		p.Parent = parent
		return p
	end
	local function case(name: string): (Model, CFrame)
		local m = Instance.new("Model")
		m.Name = name
		m.Parent = folder
		return m, base * CFrame.new(#folder:GetChildren() * 60, 0, 0)
	end
	type Expect = { name: string, want: string }
	local cases: { Expect } = {}
	local function want(name: string, expected: string)
		table.insert(cases, { name = name, want = expected })
	end

	local m, at = case("DuplicateSlabs")
	block(m, Vector3.new(10, 1, 10), at, red)
	block(m, Vector3.new(10, 1, 10), at, blue)
	want("DuplicateSlabs", "flicker")

	m, at = case("Offset001")
	block(m, Vector3.new(10, 1, 10), at, red)
	block(m, Vector3.new(10, 1, 10), at * CFrame.new(3, 0.01, 0), blue)
	want("Offset001", "flicker")

	m, at = case("Clear01")
	block(m, Vector3.new(10, 1, 10), at, red)
	block(m, Vector3.new(6, 1, 6), at * CFrame.new(1, 0.1, 0), blue)
	want("Clear01", "none")

	m, at = case("RotatedOverlap")
	local tilt = at * CFrame.Angles(math.rad(23), math.rad(40), math.rad(11))
	block(m, Vector3.new(10, 1, 10), tilt, red)
	block(m, Vector3.new(6, 1, 6), tilt * CFrame.new(2, 0, 1) * CFrame.Angles(0, math.rad(30), 0), blue)
	want("RotatedOverlap", "flicker")

	m, at = case("WedgeDiagonal")
	for i, colour in { red, blue } do
		local w = Instance.new("WedgePart")
		w.Anchored = true
		w.Size = Vector3.new(8, 4, 8)
		w.CFrame = at * CFrame.new(if i == 1 then 0 else 2, 0, 0)
		w.Color = colour
		w.Material = Enum.Material.SmoothPlastic
		w.Parent = m
	end
	want("WedgeDiagonal", "flicker")

	m, at = case("CleanButtJoint")
	block(m, Vector3.new(10, 1, 10), at, red)
	block(m, Vector3.new(10, 1, 10), at * CFrame.new(10, 0, 0), blue)
	want("CleanButtJoint", "none")

	m, at = case("LayeredTrim")
	block(m, Vector3.new(10, 1, 10), at, red)
	block(m, Vector3.new(4, 0.1, 10), at * CFrame.new(0, 0.55 + 0.06, 0), blue)
	want("LayeredTrim", "none")

	m, at = case("MeshBoundsOnly")
	local mesh = Instance.new("MeshPart")
	mesh.Anchored = true
	mesh.Size = Vector3.new(10, 1, 10)
	mesh.CFrame = at
	mesh.Parent = m
	block(m, Vector3.new(10, 1, 10), at * CFrame.new(3, 0, 0), blue)
	want("MeshBoundsOnly", "manual")

	m, at = case("InteriorBackToBack")
	block(m, Vector3.new(10, 4, 10), at, red)
	block(m, Vector3.new(10, 4, 10), at * CFrame.new(0, 4, 0), blue)
	want("InteriorBackToBack", "none")

	-- which end of a wedge is tall, from the engine, not from memory
	local probeHit = "?"
	do
		local w = Instance.new("WedgePart")
		w.Anchored = true
		w.Size = Vector3.new(4, 4, 4)
		w.CFrame = base * CFrame.new(0, 300, 0)
		w.Parent = folder
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Include
		params.FilterDescendantsInstances = { w }
		local from = w.CFrame:PointToWorldSpace(Vector3.new(0, 10, 1.5))
		local hit = workspace:Raycast(from, Vector3.new(0, -20, 0), params)
		probeHit = if hit then string.format("%.2f", w.CFrame:PointToObjectSpace(hit.Position).Y) else "miss"
		w:Destroy()
	end
	local cornerProbe: { string } = {}
	do
		local w = Instance.new("CornerWedgePart")
		w.Anchored = true
		w.Size = Vector3.new(4, 4, 4)
		w.CFrame = base * CFrame.new(0, 340, 0)
		w.Parent = folder
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Include
		params.FilterDescendantsInstances = { w }
		for _, s in { { 1.8, 1.8 }, { 1.8, -1.8 }, { -1.8, 1.8 }, { -1.8, -1.8 } } do
			local from = w.CFrame:PointToWorldSpace(Vector3.new(s[1], 10, s[2]))
			local hit = workspace:Raycast(from, Vector3.new(0, -20, 0), params)
			local y = if hit then w.CFrame:PointToObjectSpace(hit.Position).Y else -99
			table.insert(cornerProbe, string.format("(%g,%g)=%.2f", s[1], s[2], y))
		end
		w:Destroy()
	end

	local lines = {}
	for _, c in cases do
		local model = folder:FindFirstChild(c.name) :: Model
		local report = OverlapScan.run({ roots = { model }, terrain = false })
		local got = "none"
		if report.counts.flicker > 0 then
			got = "flicker"
		elseif report.counts.near > 0 then
			got = "near"
		elseif report.manual.meshParts > 0 then
			got = "manual"
		end
		table.insert(
			lines,
			string.format(
				"%s  %-20s expected %-8s observed %s",
				if got == c.want then "PASS" else "FAIL",
				c.name,
				c.want,
				got
			)
		)
	end
	table.insert(lines, "probe: wedge top at z=+1.5 of a 4-stud wedge reads y=" .. probeHit)
	table.insert(lines, "probe: corner wedge top heights " .. table.concat(cornerProbe, " "))
	folder:Destroy()
	return lines
end

return OverlapScan
