--!strict
-- DEVELOPMENT PREVIEW BUILD (Lane 3). Builds the island environment (terrain, water, lighting,
-- near and middle planting, waterfall) in Studio edit mode, in Adam's private island test
-- place only. Not part of the game.
--
--   local I = game.ServerStorage.Island:Clone()
--   local Env = require(I.Hub.Environment.EnvironmentBuild)
--   Env.build({ preset = "ClearAlpine" })   -- or "SoftHaze"; seed defaults to Env.Seed
--   Env.setPreset("SoftHaze")               -- switch lighting only
--   Env.cleanup()                           -- clears its terrain box, restores every saved setting
--
-- State lives on Workspace.Lane3_IslandEnvironment (a Folder): the generator version, seed and
-- box, the saved original look, and the planting and waterfall. The hub parts
-- (Workspace.Lane3_IslandPreview) are rebuilt without the greybox backdrop afterwards.

local RunService = game:GetService("RunService")

local Field = require(script.Parent.Field)
local Flora = require(script.Parent.Flora)
local HubBuild = require(script.Parent.Parent.HubBuild)
local Layout = require(script.Parent.Parent.Layout)
local GroundCover = require(script.Parent.GroundCover)
local LakeDressing = require(script.Parent.LakeDressing)
local Look = require(script.Parent.Look)
local ParkDressing = require(script.Parent.ParkDressing)
local TerrainWriter = require(script.Parent.TerrainWriter)
local Waterfall = require(script.Parent.Waterfall)
local WildlifeKit = require(script.Parent.WildlifeKit)

local EnvironmentBuild = {}

EnvironmentBuild.Seed = 20261021
local STATE_NAME = "Lane3_IslandEnvironment"

export type Options = { seed: number?, preset: string? }

local function guard()
	assert(RunService:IsStudio(), "EnvironmentBuild runs only in Studio")
	assert(not RunService:IsRunning(), "EnvironmentBuild runs in edit mode, not during a playtest")
end

function EnvironmentBuild.state(): Folder?
	return workspace:FindFirstChild(STATE_NAME) :: Folder?
end

local function boxText(): string
	local b = Field.Box
	return string.format("x %d..%d, y %d..%d, z %d..%d", b.minX, b.maxX, b.minY, b.maxY, b.minZ, b.maxZ)
end

function EnvironmentBuild.build(options: Options?): { [string]: any }
	guard()
	local o: Options = options or {}
	local seed = o.seed or EnvironmentBuild.Seed
	local started = os.clock()
	local report: { [string]: any } = { memoryStartMb = TerrainWriter.memoryMb(), seed = seed, version = Field.VERSION }
	local phases: { [string]: number } = {}
	local last = os.clock()
	local function phase(name: string)
		phases[name] = math.round((os.clock() - last) * 100) / 100
		last = os.clock()
	end

	local state = EnvironmentBuild.state()
	if not state then
		if TerrainWriter.boxHasTerrain() then
			error("The environment box already holds terrain this build did not write; nothing was changed")
		end
		phase("ownershipCheck")
		local created = Instance.new("Folder")
		created.Name = STATE_NAME
		created.Parent = workspace
		state = created
	end
	local s = state :: Folder
	s:SetAttribute("GeneratorVersion", Field.VERSION)
	s:SetAttribute("Seed", seed)
	s:SetAttribute("Box", boxText())
	s:SetAttribute("PreviewOf", "Lane 3 island environment (Task 2, step 1)")
	local function progress(name: string, fraction: number)
		s:SetAttribute("Phase", name)
		s:SetAttribute("Progress", math.round(fraction * 1000) / 1000)
	end

	Look.capture(s)
	for _, child in s:GetChildren() do
		child:Destroy()
	end
	if s:GetAttribute("TerrainWritten") then
		TerrainWriter.clear(progress)
		s:SetAttribute("TerrainWritten", false)
		phase("clear")
	end

	local grid, gullies = TerrainWriter.compute(seed, Layout.Data.park.stream, progress)
	report.memoryAfterGridMb = TerrainWriter.memoryMb()
	phase("compute")
	s:SetAttribute("TerrainWritten", true)
	local written = TerrainWriter.write(grid, progress)
	report.memoryAfterWriteMb = TerrainWriter.memoryMb()
	phase("write")

	Look.applyTerrain()
	Look.applyPreset(s, o.preset or "ClearAlpine")
	phase("look")

	local counts = Flora.build(s, grid, seed)
	Waterfall.build(s)
	phase("planting")
	report.lake = LakeDressing.build(s, seed)
	report.groundCover = GroundCover.build(s, grid, seed)
	report.park = ParkDressing.build(s, grid, seed)
	report.wildlifeKit = WildlifeKit.build(s)
	phase("dressing")

	local hub = HubBuild.build()
	phase("hubParts")
	progress("done", 1)

	local parts = 0
	for _, d in s:GetDescendants() do
		if d:IsA("BasePart") then
			parts += 1
		end
	end
	report.phasesSeconds = phases
	report.seconds = math.round((os.clock() - started) * 100) / 100
	report.chunks = written.chunks
	report.voxelsWritten = written.voxels
	report.peakMemoryDuringWriteMb = written.peakMb
	report.memoryEndMb = TerrainWriter.memoryMb()
	report.gullies = gullies
	report.flowFloorAboveGround = (TerrainWriter :: any).FlowFitWorst
	report.flora = counts
	report.environmentParts = parts
	report.hubParts = hub.parts
	report.box = boxText()
	return report
end

function EnvironmentBuild.setPreset(name: string): string
	guard()
	local s = EnvironmentBuild.state()
	assert(s, "Build the environment first")
	Look.applyPreset(s, name)
	return "preset " .. name
end

-- Rebuilds the lake dressing, ground cover and park dressing (and the hub, so its placeholders
-- hide under the park dressing), without touching the terrain or the trees.
function EnvironmentBuild.redress(): { [string]: any }
	guard()
	local s = EnvironmentBuild.state()
	assert(s and s:GetAttribute("TerrainWritten"), "Build the environment first")
	local seed = s:GetAttribute("Seed") :: number
	local grid = TerrainWriter.compute(seed, Layout.Data.park.stream, function() end)
	local lake = LakeDressing.build(s, seed)
	local ground = GroundCover.build(s, grid, seed)
	local park = ParkDressing.build(s, grid, seed)
	local wildlife = WildlifeKit.build(s)
	local hub = HubBuild.build()
	return { lake = lake, groundCover = ground, park = park, wildlifeKit = wildlife, hubParts = hub.parts }
end

-- Replaces the planting only, on the terrain already written by build(): the grid is recomputed
-- (not rewritten), the old forest floor patches are returned to grass, and Flora is rebuilt.
function EnvironmentBuild.replant(): { [string]: any }
	guard()
	local s = EnvironmentBuild.state()
	assert(s and s:GetAttribute("TerrainWritten"), "Build the environment first")
	assert(s:GetAttribute("GeneratorVersion") == Field.VERSION, "The terrain is from another generator version")
	local started = os.clock()
	local seed = s:GetAttribute("Seed") :: number
	local grid = TerrainWriter.compute(seed, Layout.Data.park.stream, function() end)
	local old = s:FindFirstChild("Flora")
	Flora.revertFloor(s, grid)
	if old then
		old:Destroy()
	end
	local counts = Flora.build(s, grid, seed)
	-- the understory follows the trees
	GroundCover.build(s, grid, seed)
	return { flora = counts, seconds = math.round((os.clock() - started) * 100) / 100 }
end

function EnvironmentBuild.cleanup(): string
	guard()
	local s = EnvironmentBuild.state()
	if not s then
		return "nothing to clean up"
	end
	if s:GetAttribute("TerrainWritten") then
		TerrainWriter.clear(function() end)
	end
	Look.restore(s)
	s:Destroy()
	return "cleared the environment box and restored the saved look; rebuild the hub for the greybox backdrop"
end

return EnvironmentBuild
