--!strict
-- The real outlines of the kit flower beds (Lane 3, build-time), in mesh coordinates: a point is
-- Vector2(x, z) in the bed mesh's own frame. Numbers are the recipe's (KitManifest meta). Used by
-- the planting rule and by the park checks, so a flower is tested against the bed's true shape and
-- never against its bounding box.
--   soil(name, q)     > 0 inside the planted soil, by how many studs; <= 0 on the kerb or outside
--   outline(name)     points round the kerb's outer edge
--   toPlan / toLocal  mesh frame to plan frame for a bed placed at `at`, turned `yaw`

local BedShapes = {}

local function arcSoil(q: Vector2, ring: number, half: number, sweepDeg: number, inset: number): number
	local c = Vector2.new(0, -ring)
	local d = q - c
	local rho = d.Magnitude
	local theta = math.atan2(d.X, d.Y)
	local across = half - inset - math.abs(rho - ring)
	local along = (math.rad(sweepDeg / 2) - math.abs(theta)) * ring - inset - 0.5
	return math.min(across, along)
end

local function cornerSoil(q: Vector2): number
	local s, t = q.X, -q.Y
	local depth = math.min(s - 2.2, t - 2.2, 13.75 - Vector2.new(s, t).Magnitude)
	if s < 8 and t < 8 then
		depth = math.min(depth, 5.75 - (Vector2.new(s, t) - Vector2.new(8, 8)).Magnitude)
	end
	return depth
end

function BedShapes.soil(name: string, q: Vector2): number
	if name == "BedFountainArc" then
		return arcSoil(q, 49, 4, 16.37, 1.25)
	elseif name == "BedAvenueArc" then
		return arcSoil(q, 178, 3.5, 5.794, 1)
	elseif name == "BedCornerFillet" then
		return cornerSoil(q)
	elseif name == "BedJunctionRound" then
		return 7.75 - q.Magnitude
	end
	error("no outline for " .. name)
end

local function arcOutline(ring: number, half: number, sweepDeg: number): { Vector2 }
	local pts = {}
	local c = Vector2.new(0, -ring)
	local a = math.rad(sweepDeg / 2)
	for _, r in { ring + half, ring - half } do
		for k = 0, 10 do
			local b = -a + 2 * a * k / 10
			table.insert(pts, c + Vector2.new(math.sin(b), math.cos(b)) * r)
		end
	end
	return pts
end

function BedShapes.outline(name: string): { Vector2 }
	if name == "BedFountainArc" then
		return arcOutline(49, 4.05, 16.37)
	elseif name == "BedAvenueArc" then
		return arcOutline(178, 3.55, 5.794)
	elseif name == "BedCornerFillet" then
		local pts = {}
		for k = 0, 12 do
			local b = k / 12 * math.pi / 2
			table.insert(pts, Vector2.new(math.cos(b) * 15, -math.sin(b) * 15))
		end
		for k = 0, 8 do
			local b = math.pi + k / 8 * math.pi / 2
			table.insert(pts, Vector2.new(8 + math.cos(b) * 7.05, -(8 + math.sin(b) * 7.05)))
		end
		return pts
	elseif name == "BedJunctionRound" then
		local pts = {}
		for k = 0, 23 do
			local b = k / 24 * math.pi * 2
			table.insert(pts, Vector2.new(math.cos(b), math.sin(b)) * 9.05)
		end
		return pts
	end
	error("no outline for " .. name)
end

-- Plan offset of mesh point q on a bed turned `yaw` about Y (plan y is world -z).
function BedShapes.toPlan(at: Vector2, yaw: number, q: Vector2): Vector2
	local c, s = math.cos(yaw), math.sin(yaw)
	return at + Vector2.new(q.X * c + q.Y * s, q.X * s - q.Y * c)
end

function BedShapes.toLocal(at: Vector2, yaw: number, p: Vector2): Vector2
	local d = p - at
	local c, s = math.cos(yaw), math.sin(yaw)
	return Vector2.new(d.X * c + d.Y * s, d.X * s - d.Y * c)
end

return BedShapes
