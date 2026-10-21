--!strict
-- Island environment terrain (Lane 3, build-time, Studio edit mode only). Samples the height
-- field on the 4-stud voxel grid inside the recorded box, carves gullies along steepest
-- descent (so they follow drainage), picks materials by slope, height and water, and writes
-- Smooth Terrain in bounded chunks with WriteVoxelChannels. It clears and writes only inside
-- the box, and it refuses to write into a box that already holds terrain it did not write.

local Stats = game:GetService("Stats")

local Cascade = require(script.Parent.Cascade)
local Field = require(script.Parent.Field)

local TerrainWriter = {}

local CELL = Field.Cell
local BOX = Field.Box
local NX = (BOX.maxX - BOX.minX) // CELL -- 440 columns east-west
local NZ = (BOX.maxZ - BOX.minZ) // CELL -- 385 columns north-south
local CHUNK = 16 -- columns per chunk side (64 studs)
local SURFACE_OFFSET = 2
TerrainWriter.NX, TerrainWriter.NZ = NX, NZ

export type Grid = {
	h: { number }, -- surface height per column, index (iz - 1) * NX + ix
	water: { number }, -- water surface, or -math.huge
	flags: { number }, -- bit 1 lake, 2 bank, 4 channel, 8 hub, 16 gully, 32 wet rock
	zone: { string }, -- lake bed or shore zone (Field.Sample.zone)
	far: { number },
	slope: { number },
	material: { Enum.Material },
	seed: number,
}

local LAKE, BANK, CHANNEL, HUB, GULLY, WET = 1, 2, 4, 8, 16, 32

local function index(ix: number, iz: number): number
	return (iz - 1) * NX + ix
end

-- World centre of column (ix, iz) and its plan point.
function TerrainWriter.columnPlan(ix: number, iz: number): Vector2
	local x = BOX.minX + (ix - 0.5) * CELL
	local z = BOX.minZ + (iz - 0.5) * CELL
	return Vector2.new(x, -z)
end

function TerrainWriter.memoryMb(): number
	return math.round(Stats:GetTotalMemoryUsageMb())
end

-- Bilinear surface height at a plan point (for placing props on the terrain).
function TerrainWriter.heightAt(grid: Grid, p: Vector2): number
	local fx = (p.X - BOX.minX) / CELL + 0.5
	local fz = (-p.Y - BOX.minZ) / CELL + 0.5
	local ix = math.clamp(math.floor(fx), 1, NX - 1)
	local iz = math.clamp(math.floor(fz), 1, NZ - 1)
	local tx = math.clamp(fx - ix, 0, 1)
	local tz = math.clamp(fz - iz, 0, 1)
	local h = grid.h
	local a = h[index(ix, iz)] + (h[index(ix + 1, iz)] - h[index(ix, iz)]) * tx
	local b = h[index(ix, iz + 1)] + (h[index(ix + 1, iz + 1)] - h[index(ix, iz + 1)]) * tx
	return a + (b - a) * tz
end

function TerrainWriter.slopeAt(grid: Grid, p: Vector2): number
	local ix = math.clamp(math.floor((p.X - BOX.minX) / CELL) + 1, 1, NX)
	local iz = math.clamp(math.floor((-p.Y - BOX.minZ) / CELL) + 1, 1, NZ)
	return grid.slope[index(ix, iz)]
end

function TerrainWriter.flagsAt(grid: Grid, p: Vector2): number
	local ix = math.clamp(math.floor((p.X - BOX.minX) / CELL) + 1, 1, NX)
	local iz = math.clamp(math.floor((-p.Y - BOX.minZ) / CELL) + 1, 1, NZ)
	return grid.flags[index(ix, iz)]
end
TerrainWriter.Flags = { LAKE = LAKE, BANK = BANK, CHANNEL = CHANNEL, HUB = HUB, GULLY = GULLY, WET = WET }

-- The water surface over the column under p, or -math.huge where there is none.
function TerrainWriter.waterAt(grid: Grid, p: Vector2): number
	local ix = math.clamp(math.floor((p.X - BOX.minX) / CELL) + 1, 1, NX)
	local iz = math.clamp(math.floor((-p.Y - BOX.minZ) / CELL) + 1, 1, NZ)
	return grid.water[index(ix, iz)]
end

-- The surface material classify() chose for the column under p.
function TerrainWriter.materialAt(grid: Grid, p: Vector2): Enum.Material
	local ix = math.clamp(math.floor((p.X - BOX.minX) / CELL) + 1, 1, NX)
	local iz = math.clamp(math.floor((-p.Y - BOX.minZ) / CELL) + 1, 1, NZ)
	return grid.material[index(ix, iz)]
end

function TerrainWriter.zoneAt(grid: Grid, p: Vector2): string
	local ix = math.clamp(math.floor((p.X - BOX.minX) / CELL) + 1, 1, NX)
	local iz = math.clamp(math.floor((-p.Y - BOX.minZ) / CELL) + 1, 1, NZ)
	return grid.zone[index(ix, iz)]
end

-- Sample the field on every column.
local function sampleGrid(seed: number, stream: { Vector2 }, progress: (string, number) -> ()): Grid
	local nz = Field.noiseFor(seed)
	TerrainWriter.FlowFitWorst = Field.fitFlows(nz)
	local grid: Grid = { h = {}, water = {}, flags = {}, zone = {}, far = {}, slope = {}, material = {}, seed = seed }
	for iz = 1, NZ do
		for ix = 1, NX do
			local p = TerrainWriter.columnPlan(ix, iz)
			local s = Field.sample(nz, p)
			if s.hub or Field.hubDistance(p) < 40 then
				Field.applyStream(s, stream, p)
			end
			local i = index(ix, iz)
			grid.h[i] = s.h
			grid.water[i] = s.water or -math.huge
			grid.far[i] = s.far
			grid.flags[i] = (if s.lake then LAKE else 0)
				+ (if s.bank then BANK else 0)
				+ (if s.channel then CHANNEL else 0)
				+ (if s.hub then HUB else 0)
				+ (if s.wet then WET else 0)
			grid.zone[i] = s.zone
		end
		if iz % 16 == 0 then
			progress("sample", iz / NZ)
			task.wait()
		end
	end
	return grid
end

-- Gullies: start below ridge crests and follow the steepest way down, carving a V that
-- deepens mid-way and fades out at the foot. Deterministic from the seed.
local function carveGullies(grid: Grid, progress: (string, number) -> ()): number
	local rng = Random.new(grid.seed + 7)
	local h = grid.h
	local starts: { Vector2 } = {}
	local carved = 0
	local tries = 0
	while #starts < 64 and tries < 6000 do
		tries += 1
		local ix, iz = rng:NextInteger(3, NX - 2), rng:NextInteger(3, NZ - 2)
		local hs = h[index(ix, iz)]
		local p = TerrainWriter.columnPlan(ix, iz)
		local wanted = hs > 120 and hs < 320 and (p.Y < -300 or math.abs(p.X) > 620)
		if wanted then
			for _, q in starts do
				if (q - p).Magnitude < 55 then
					wanted = false
					break
				end
			end
		end
		if wanted then
			table.insert(starts, p)
			local path = {}
			local cx, cz = ix, iz
			for _ = 1, 140 do
				table.insert(path, { cx, cz })
				local here = h[index(cx, cz)]
				local bx, bz, bh = cx, cz, here
				for dz = -1, 1 do
					for dx = -1, 1 do
						local nx, nzc = cx + dx, cz + dz
						if nx >= 1 and nx <= NX and nzc >= 1 and nzc <= NZ then
							local nh = h[index(nx, nzc)]
							if nh < bh then
								bx, bz, bh = nx, nzc, nh
							end
						end
					end
				end
				if bx == cx and bz == cz or bh < 30 or bit32.band(grid.flags[index(bx, bz)], LAKE + HUB) ~= 0 then
					break
				end
				cx, cz = bx, bz
			end
			local maxDepth = math.clamp(hs * 0.055, 4, 12)
			for k, cell in path do
				local f = k / #path
				local depth = maxDepth * math.sin(math.pi * f) ^ 0.7
				local radius = 1.5 + 1.5 * f -- cells
				local r = math.ceil(radius)
				for dz = -r, r do
					for dx = -r, r do
						local nx, nzc = cell[1] + dx, cell[2] + dz
						if nx >= 1 and nx <= NX and nzc >= 1 and nzc <= NZ then
							local d = math.sqrt(dx * dx + dz * dz) / radius
							if d < 1 then
								local i = index(nx, nzc)
								local cut = depth * (1 - d) ^ 1.3
								if cut > 0.5 and bit32.band(grid.flags[i], LAKE + HUB + CHANNEL) == 0 then
									h[i] -= cut
									if cut > 1.5 then
										grid.flags[i] = bit32.bor(grid.flags[i], GULLY)
									end
								end
							end
						end
					end
				end
			end
			carved += 1
		end
		if tries % 200 == 0 then
			progress("gullies", #starts / 64)
			task.wait()
		end
	end
	return carved
end

-- Slope and surface material per column.
local function classify(grid: Grid, seed: number, progress: (string, number) -> ())
	local nz = Field.noiseFor(seed + 3)
	local h = grid.h
	for iz = 1, NZ do
		for ix = 1, NX do
			local i = index(ix, iz)
			local hx = h[index(math.min(ix + 1, NX), iz)] - h[index(math.max(ix - 1, 1), iz)]
			local hz = h[index(ix, math.min(iz + 1, NZ))] - h[index(ix, math.max(iz - 1, 1))]
			local slope = math.sqrt(hx * hx + hz * hz) / (2 * CELL)
			grid.slope[i] = slope
			local p = TerrainWriter.columnPlan(ix, iz)
			local flags = grid.flags[i]
			local n = math.noise(p.X / 38 + nz.ox, p.Y / 38 + nz.oy, nz.oz[1])
			local far = grid.far[i] + 0.25 * math.noise(p.X / 90 + nz.ox, p.Y / 90 + nz.oy, nz.oz[2])
			local rock = if far > 0.5 then Enum.Material.Slate else Enum.Material.Rock
			local snowLine = 228 + 36 * math.noise(p.X / 85 + nz.ox, p.Y / 85 + nz.oy, nz.oz[3])
			local m: Enum.Material
			local zone = grid.zone[i]
			local wet = bit32.band(flags, WET) ~= 0
			-- by the falls, dry rock is slate (no wrapped banding) and wet rock is dark basalt
			local nearFalls = math.abs(p.X - Cascade.X) < 110 and p.Y > -340 and p.Y < -255
			if nearFalls then
				rock = Enum.Material.Slate
			end
			if bit32.band(flags, LAKE) ~= 0 then
				if zone == "deep" then
					m = Enum.Material.Basalt
				elseif zone == "marsh" then
					m = Enum.Material.Mud
				elseif zone == "rocky" then
					m = if n > -0.2 then Enum.Material.Basalt else Enum.Material.Limestone
				elseif zone == "shelf" then
					m = if n > 0.3 then Enum.Material.Limestone else Enum.Material.Sand
				else
					m = Enum.Material.Sand
				end
			elseif bit32.band(flags, CHANNEL) ~= 0 then
				m = if wet or zone == "ledge" then Enum.Material.Basalt else Enum.Material.Limestone
			elseif bit32.band(flags, BANK) ~= 0 then
				if zone == "damp" then
					m = if n > 0.35 then Enum.Material.Limestone else Enum.Material.Mud
				elseif zone == "rocky" then
					m = if n > 0 then Enum.Material.Basalt else Enum.Material.Rock
				elseif zone == "beach" then
					m = Enum.Material.Sand
				else
					m = if n > 0.25 then Enum.Material.Rock else Enum.Material.Limestone
				end
			elseif wet then
				-- spray zone: dark wet rock on the faces, moss on the sheltered ledges
				m = if slope < 0.6 and n > -0.3 then Enum.Material.LeafyGrass else Enum.Material.Basalt
			elseif zone == "ledge" then
				m = if slope < 0.7 then Enum.Material.LeafyGrass else rock
			elseif
				h[i] > snowLine and slope < 1.3 + (h[i] - snowLine) / 120
				or (h[i] > snowLine - 45 and slope < 0.75 and n > 0.1)
			then
				m = Enum.Material.Snow
			elseif bit32.band(flags, GULLY) ~= 0 then
				m = if h[i] > snowLine - 20 and n > 0 then Enum.Material.Snow else rock
			elseif slope > 1.35 then
				m = rock
			elseif slope > 1.0 then
				m = if n > 0.2 then rock else Enum.Material.Grass
			elseif h[i] > 25 and math.noise(p.X / 160 + nz.ox, p.Y / 160 + nz.oy, nz.oz[4]) > 0.28 then
				m = Enum.Material.Ground -- forest floor patches
			else
				m = Enum.Material.Grass
			end
			grid.material[i] = m
		end
		if iz % 32 == 0 then
			progress("classify", iz / NZ)
			task.wait()
		end
	end
end

function TerrainWriter.compute(seed: number, stream: { Vector2 }, progress: (string, number) -> ()): (Grid, number)
	local grid = sampleGrid(seed, stream, progress)
	local gullies = carveGullies(grid, progress)
	classify(grid, seed, progress)
	return grid, gullies
end

local function chunkRegion(cx: number, cz: number, top: number): (Region3, number, number, number, number)
	local ix0 = (cx - 1) * CHUNK + 1
	local iz0 = (cz - 1) * CHUNK + 1
	local ix1 = math.min(ix0 + CHUNK - 1, NX)
	local iz1 = math.min(iz0 + CHUNK - 1, NZ)
	local min = Vector3.new(BOX.minX + (ix0 - 1) * CELL, BOX.minY, BOX.minZ + (iz0 - 1) * CELL)
	local max = Vector3.new(BOX.minX + ix1 * CELL, top, BOX.minZ + iz1 * CELL)
	return Region3.new(min, max), ix0, iz0, ix1, iz1
end

local function chunkCounts(): (number, number)
	return math.ceil(NX / CHUNK), math.ceil(NZ / CHUNK)
end

-- Is there terrain in the box? One full-height column every 32 studs. Used before a first write.
function TerrainWriter.boxHasTerrain(): boolean
	local terrain = workspace.Terrain
	for x = BOX.minX, BOX.maxX - CELL, 32 do
		for z = BOX.minZ, BOX.maxZ - CELL, 32 do
			local region = Region3.new(Vector3.new(x, BOX.minY, z), Vector3.new(x + CELL, BOX.maxY, z + CELL))
			local channels = terrain:ReadVoxelChannels(region, CELL, { "SolidOccupancy", "LiquidOccupancy" })
			local solid, liquid = channels.SolidOccupancy[1], channels.LiquidOccupancy[1]
			for y = 1, #solid do
				if solid[y][1] > 0 or liquid[y][1] > 0 then
					return true
				end
			end
		end
		task.wait()
	end
	return false
end

-- Clears the whole box, chunk by chunk (never terrain outside it).
function TerrainWriter.clear(progress: (string, number) -> ())
	local terrain = workspace.Terrain
	local cxN, czN = chunkCounts()
	for cz = 1, czN do
		for cx = 1, cxN do
			terrain:FillRegion((chunkRegion(cx, cz, BOX.maxY)), CELL, Enum.Material.Air)
		end
		progress("clear", cz / czN)
		task.wait()
	end
end

-- 3D shapes a height field cannot make (Cascade.volumes): added rock blends in by its own
-- signed distance, carved space removes rock and water. Arrays are [x][layer][z] for `region`.
local VOLUMES = Cascade.volumes()
local function applyVolumes(region: Region3, mats: { any }, solids: { any }, liquids: { any })
	local min = region.CFrame.Position - region.Size / 2
	local max = region.CFrame.Position + region.Size / 2
	for _, v in VOLUMES do
		local lo, hi = v.centre - v.radii - Vector3.one * CELL, v.centre + v.radii + Vector3.one * CELL
		if lo.X < max.X and hi.X > min.X and lo.Y < max.Y and hi.Y > min.Y and lo.Z < max.Z and hi.Z > min.Z then
			local r = math.min(v.radii.X, v.radii.Y, v.radii.Z)
			for ix = 1, #solids do
				for l = 1, #solids[ix] do
					for iz = 1, #solids[ix][l] do
						local c = min + Vector3.new((ix - 0.5) * CELL, (l - 0.5) * CELL, (iz - 0.5) * CELL)
						local rel = c - v.centre
						local d = (rel / v.radii).Magnitude
						-- the shape's own radius along this direction, so the soft edge is about one voxel
						local along = if d > 1e-6 then rel.Magnitude / d else r
						if (d - 1) * along < CELL then
							local f = math.clamp(0.5 - (d - 1) * along / CELL, 0, 1)
							if v.kind == "add" then
								if f > solids[ix][l][iz] then
									solids[ix][l][iz] = f
									mats[ix][l][iz] = v.material or Enum.Material.Basalt
									liquids[ix][l][iz] = if f >= 1 then 0 else liquids[ix][l][iz]
								end
							else
								solids[ix][l][iz] = math.min(solids[ix][l][iz], 1 - f)
								if solids[ix][l][iz] <= 0 then
									mats[ix][l][iz] = Enum.Material.Air
								end
							end
						end
					end
				end
			end
		end
	end
end

export type WriteStats = { chunks: number, voxels: number, peakMb: number }

function TerrainWriter.write(grid: Grid, progress: (string, number) -> ()): WriteStats
	local terrain = workspace.Terrain
	local cxN, czN = chunkCounts()
	local stats: WriteStats = { chunks = 0, voxels = 0, peakMb = TerrainWriter.memoryMb() }
	local AIR = Enum.Material.Air
	local ROCK = Enum.Material.Rock
	for cz = 1, czN do
		for cx = 1, cxN do
			-- height of the chunk's highest surface or water, rounded up to the grid
			local _, ix0, iz0, ix1, iz1 = chunkRegion(cx, cz, BOX.maxY)
			local top = BOX.minY + CELL
			for iz = iz0, iz1 do
				for ix = ix0, ix1 do
					local i = index(ix, iz)
					top = math.max(top, grid.h[i], grid.water[i])
				end
			end
			top = math.min(BOX.maxY, math.ceil((top + 1) / CELL) * CELL + CELL)
			local region = chunkRegion(cx, cz, top)
			local layers = (top - BOX.minY) // CELL
			local mats, solids, liquids = {}, {}, {}
			for ix = ix0, ix1 do
				local mx, sx, lx = {}, {}, {}
				for l = 1, layers do
					local yb = BOX.minY + (l - 1) * CELL
					local my, sy, ly = {}, {}, {}
					for iz = iz0, iz1 do
						local i = index(ix, iz)
						local h = grid.h[i]
						-- Measured in Studio (probes, 2026-10-21): over a full voxel the rendered
						-- solid surface sits at the top voxel's bottom + 2 + 4 x occupancy, so solid
						-- occupancy is taken from (height - 2); water renders at bottom + 4 x
						-- occupancy, so liquid needs no offset.
						local solid = math.clamp((h - SURFACE_OFFSET - yb) / CELL, 0, 1)
						local liquid = if solid < 1 then math.clamp((grid.water[i] - yb) / CELL, 0, 1) else 0
						local m = AIR
						if solid > 0 then
							-- the surface material runs three layers deep: a half-filled surface voxel over a full
							-- rock voxel otherwise shows rock patches through grass (seen in Studio, 2026-10-21)
							m = if h - yb < 3 * CELL then grid.material[i] else ROCK
						end
						table.insert(my, m)
						table.insert(sy, solid)
						table.insert(ly, liquid)
					end
					mx[l], sx[l], lx[l] = my, sy, ly
				end
				table.insert(mats, mx)
				table.insert(solids, sx)
				table.insert(liquids, lx)
			end
			applyVolumes(region, mats, solids, liquids)
			terrain:WriteVoxelChannels(
				region,
				CELL,
				{ SolidMaterial = mats, SolidOccupancy = solids, LiquidOccupancy = liquids }
			)
			stats.chunks += 1
			stats.voxels += (ix1 - ix0 + 1) * (iz1 - iz0 + 1) * layers
		end
		stats.peakMb = math.max(stats.peakMb, TerrainWriter.memoryMb())
		progress("write", cz / czN)
		task.wait()
	end
	return stats
end

return TerrainWriter
