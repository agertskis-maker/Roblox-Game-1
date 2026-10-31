--!strict
-- DEVELOPMENT PREVIEW BUILD (Lane 3). Builds the Stage A island greybox in Studio edit
-- mode, in the private place CarHop-Island-Test.rbxl only. Not part of the game.
--
--   local Build = require(game.ServerStorage.Island.IslandBuild)
--   Build.build()      -- (re)builds Workspace.Lane3_IslandPreview and the terrain coast
--   Build.cleanup()    -- removes the preview, clears only its terrain box, restores
--                      -- the terrain colours and water settings it changed
--
-- One root: Workspace.Lane3_IslandPreview. Rebuilding cleans up first. It never clears
-- Workspace or Terrain globally, and it refuses to write terrain into a box that already
-- holds terrain it did not write.

local RunService = game:GetService("RunService")

local Ground = require(script.Parent.Recipes.Ground)
local Layout = require(script.Parent.Layout)
local Markers = require(script.Parent.Markers)
local Palette = require(script.Parent.WorldPalette)
local PlazaRecipe = require(script.Parent.Recipes.Plaza)
local PlotRecipe = require(script.Parent.Recipes.Plot)

local IslandBuild = {}

local ROOT_NAME = "Lane3_IslandPreview"
local SAVED_PREFIX = "Saved_"

export type Options = { terrain: boolean?, helpers: boolean? }

local function guard()
	assert(RunService:IsStudio(), "IslandBuild runs only in Studio")
	assert(not RunService:IsRunning(), "IslandBuild runs in edit mode, not during a playtest")
end

local function saveTerrainLook(root: Instance)
	if root:GetAttribute(SAVED_PREFIX .. "Captured") then
		return
	end
	local terrain = workspace.Terrain
	root:SetAttribute(SAVED_PREFIX .. "GrassColor", terrain:GetMaterialColor(Enum.Material.Grass))
	root:SetAttribute(SAVED_PREFIX .. "SandColor", terrain:GetMaterialColor(Enum.Material.Sand))
	root:SetAttribute(SAVED_PREFIX .. "WaterColor", terrain.WaterColor)
	root:SetAttribute(SAVED_PREFIX .. "WaterTransparency", terrain.WaterTransparency)
	root:SetAttribute(SAVED_PREFIX .. "WaterReflectance", terrain.WaterReflectance)
	root:SetAttribute(SAVED_PREFIX .. "WaterWaveSize", terrain.WaterWaveSize)
	root:SetAttribute(SAVED_PREFIX .. "WaterWaveSpeed", terrain.WaterWaveSpeed)
	root:SetAttribute(SAVED_PREFIX .. "Captured", true)
end

local function restoreTerrainLook(root: Instance)
	if not root:GetAttribute(SAVED_PREFIX .. "Captured") then
		return
	end
	local terrain = workspace.Terrain
	terrain:SetMaterialColor(Enum.Material.Grass, root:GetAttribute(SAVED_PREFIX .. "GrassColor") :: Color3)
	terrain:SetMaterialColor(Enum.Material.Sand, root:GetAttribute(SAVED_PREFIX .. "SandColor") :: Color3)
	terrain.WaterColor = root:GetAttribute(SAVED_PREFIX .. "WaterColor") :: Color3
	terrain.WaterTransparency = root:GetAttribute(SAVED_PREFIX .. "WaterTransparency") :: number
	terrain.WaterReflectance = root:GetAttribute(SAVED_PREFIX .. "WaterReflectance") :: number
	terrain.WaterWaveSize = root:GetAttribute(SAVED_PREFIX .. "WaterWaveSize") :: number
	terrain.WaterWaveSpeed = root:GetAttribute(SAVED_PREFIX .. "WaterWaveSpeed") :: number
end

function IslandBuild.root(): Model?
	return workspace:FindFirstChild(ROOT_NAME) :: Model?
end

function IslandBuild.cleanup(): string
	guard()
	local root = IslandBuild.root()
	if not root then
		return "nothing to clean up"
	end
	if root:GetAttribute("TerrainWritten") then
		Ground.clearTerrain()
	end
	restoreTerrainLook(root)
	root:Destroy()
	return "removed the preview, cleared its terrain box and restored terrain colours and water settings"
end

local function countParts(instance: Instance): number
	local n = 0
	for _, d in instance:GetDescendants() do
		if d:IsA("BasePart") then
			n += 1
		end
	end
	return n
end

function IslandBuild.build(options: Options?): { [string]: any }
	guard()
	local o: Options = options or {}
	local withTerrain = o.terrain ~= false
	local started = os.clock()

	-- Rebuild-safe: keep the saved terrain look across a rebuild, then remove the old build.
	local saved: { [string]: any } = {}
	local old = IslandBuild.root()
	if old then
		for name, value in old:GetAttributes() do
			if string.sub(name, 1, #SAVED_PREFIX) == SAVED_PREFIX then
				saved[name] = value
			end
		end
		if old:GetAttribute("TerrainWritten") then
			Ground.clearTerrain()
		end
		old:Destroy()
	end
	if withTerrain and Ground.regionHasTerrain() then
		error("The island terrain box already holds terrain this preview did not write; nothing was built")
	end

	local root = Instance.new("Model")
	root.Name = ROOT_NAME
	for name, value in saved do
		root:SetAttribute(name, value)
	end
	root:SetAttribute("PreviewOf", "Lane 3 Stage A island greybox")
	root:SetAttribute("LayoutVersion", Layout.LayoutVersion)

	local island = Instance.new("Model")
	island.Name = "Island"
	island:SetAttribute("ContractVersion", Layout.ContractVersion)
	island:SetAttribute("LayoutVersion", Layout.LayoutVersion)
	island:SetAttribute("PlotCount", Layout.PlotCount)
	island:SetAttribute("SurfaceY", Layout.SurfaceY)
	island.Parent = root

	local plots = Instance.new("Folder")
	plots.Name = "Plots"
	plots.Parent = island
	local plaza = Instance.new("Model")
	plaza.Name = "Plaza"
	plaza.Parent = island
	local scenery = Instance.new("Model")
	scenery.Name = "Scenery"
	scenery.Parent = island
	local helpers = Instance.new("Folder")
	helpers.Name = "Helpers"
	helpers.Parent = root

	root.Parent = workspace
	task.wait()

	Ground.build(scenery)
	PlazaRecipe.build(plaza, helpers)
	task.wait()

	for index = 1, Layout.PlotCount do
		local plot = Instance.new("Model")
		plot.Name = string.format("Plot%02d", index)
		plot:SetAttribute("PlotIndex", index)
		plot:SetAttribute("BearingDeg", Layout.plotBearing(index))
		Markers.build(plot, index)
		PlotRecipe.build(plot, helpers, index, index == 1)
		plot.Parent = plots
		task.wait()
	end

	if withTerrain then
		saveTerrainLook(root)
		local terrain = workspace.Terrain
		terrain:SetMaterialColor(Enum.Material.Grass, Palette.Grass)
		terrain:SetMaterialColor(Enum.Material.Sand, Palette.Sand)
		terrain.WaterColor = Palette.DeepWater
		Ground.writeTerrain()
		root:SetAttribute("TerrainWritten", true)
	end
	if o.helpers == false then
		helpers.Parent = nil
		helpers:Destroy()
	end
	root:SetAttribute("BuiltWithTerrain", withTerrain)

	return {
		seconds = math.round((os.clock() - started) * 100) / 100,
		parts = {
			total = countParts(root),
			plots = countParts(plots),
			plaza = countParts(plaza),
			scenery = countParts(scenery),
			helpers = if helpers.Parent then countParts(helpers) else 0,
		},
		trackSegmentsPerPlot = PlotRecipe.SegmentCount,
		terrain = withTerrain,
	}
end

return IslandBuild
