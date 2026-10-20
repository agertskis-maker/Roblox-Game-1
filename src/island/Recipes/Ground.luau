--!strict
-- Ground: the level build surface (one flat disc, r 247.5), the plot dividers, and the
-- Smooth Terrain coast and water written inside one measured box. The terrain write
-- refuses to run if that box already holds terrain that this preview did not write.

local Kit = require(script.Parent.Parent.Kit)
local Layout = require(script.Parent.Parent.Layout)
local Palette = require(script.Parent.Parent.WorldPalette)

local Ground = {}

local SURFACE = Layout.SurfaceY
local RES = 4

function Ground.region(): Region3
	local t = Layout.TerrainRegion
	return Region3.new(Vector3.new(-t.half, t.bottom, -t.half), Vector3.new(t.half, t.top, t.half)):ExpandToGrid(RES)
end

function Ground.build(scenery: Model)
	Kit.disc(
		scenery,
		Vector3.zero,
		Layout.BuildRadius * 2,
		4,
		SURFACE,
		{ name = "BuildSurface", color = Palette.Grass, collide = true, castShadow = false }
	)
	local dividers = Instance.new("Folder")
	dividers.Name = "Dividers"
	for i = 1, Layout.PlotCount do
		local bearing = Layout.plotBearing(i) - Layout.HalfSectorDeg
		Kit.strip(
			dividers,
			Layout.plazaToWorld(Layout.polar(bearing, Layout.Plaza.promenadeOuter)),
			Layout.plazaToWorld(Layout.polar(bearing, Layout.Track.outerLimit + 3)),
			2,
			0.05,
			SURFACE + 0.05,
			{ name = "Divider", color = Palette.HelperDivider, castShadow = false },
			0
		)
	end
	dividers.Parent = scenery
end

-- True when the box holds any terrain at all.
function Ground.regionHasTerrain(): boolean
	local _, occupancies = workspace.Terrain:ReadVoxels(Ground.region(), RES)
	for _, plane in occupancies do
		for _, column in plane do
			for _, value in column do
				if value > 0 then
					return true
				end
			end
		end
	end
	return false
end

-- Coast: grass then sand sloping from the build surface (0) to the water line (-3);
-- water out to the box edge over a seabed that rises into a shallow shelf near the shore.
function Ground.writeTerrain()
	local t = Layout.TerrainRegion
	local region = Ground.region()
	local size = region.Size / RES
	local nx, ny, nz = size.X, size.Y, size.Z
	local minCorner = region.CFrame.Position - region.Size / 2
	local materials: { { { Enum.Material } } } = {}
	local occupancies: { { { number } } } = {}
	local innerEdge = Layout.BuildRadius - 4
	for ix = 1, nx do
		local mPlane: { { Enum.Material } } = {}
		local oPlane: { { number } } = {}
		local x = minCorner.X + (ix - 0.5) * RES
		for iy = 1, ny do
			mPlane[iy] = table.create(nz, Enum.Material.Air)
			oPlane[iy] = table.create(nz, 0)
		end
		for iz = 1, nz do
			local z = minCorner.Z + (iz - 0.5) * RES
			local north = -z
			local r = math.sqrt(x * x + north * north)
			local bearing = math.deg(math.atan2(x, north)) % 360
			local water = Layout.waterline(bearing)
			for iy = 1, ny do
				local y0 = minCorner.Y + (iy - 1) * RES
				local material = Enum.Material.Air
				local occupancy = 0
				if r <= innerEdge then
					-- under the build surface disc: leave empty
					material = Enum.Material.Air
				elseif r <= water then
					local f = math.clamp((r - innerEdge) / (water - innerEdge), 0, 1)
					local top = SURFACE + (t.waterLevel - SURFACE) * f
					occupancy = math.clamp((top - y0) / RES, 0, 1)
					material = if f < 0.35 then Enum.Material.Grass else Enum.Material.Sand
				else
					local shelf = 1 - math.clamp((r - water) / 22, 0, 1)
					local seabed = t.seabed + (t.waterLevel - 1.5 - t.seabed) * shelf
					if y0 + RES <= seabed then
						material, occupancy = Enum.Material.Sand, 1
					elseif y0 < seabed then
						material, occupancy = Enum.Material.Sand, (seabed - y0) / RES
					else
						occupancy = math.clamp((t.waterLevel - y0) / RES, 0, 1)
						material = if occupancy > 0 then Enum.Material.Water else Enum.Material.Air
					end
				end
				if occupancy <= 0 then
					material = Enum.Material.Air
					occupancy = 0
				end
				mPlane[iy][iz] = material
				oPlane[iy][iz] = occupancy
			end
		end
		materials[ix] = mPlane
		occupancies[ix] = oPlane
	end
	workspace.Terrain:WriteVoxels(region, RES, materials, occupancies)
end

function Ground.clearTerrain()
	local region = Ground.region()
	workspace.Terrain:FillBlock(region.CFrame, region.Size, Enum.Material.Air)
end

return Ground
