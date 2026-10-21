--!strict
-- DEVELOPMENT PREVIEW BUILD (Lane 3). Builds the island hub greybox (layout revision 3, six
-- plots on a half circle) in Studio edit mode, in Adam's private island test place only.
-- Not part of the game.
--
--   local I = game.ServerStorage.Island:Clone()
--   require(I.Hub.HubBuild).build()      -- (re)builds Workspace.Lane3_IslandPreview
--   require(I.Hub.HubBuild).cleanup()    -- removes it
--
-- One root: Workspace.Lane3_IslandPreview, shared with the Stage A build in IslandBuild. If
-- the root holds the Stage A build, its own cleanup runs first (that clears only the Stage A
-- terrain box and restores the terrain look it saved). The hub writes no terrain and never
-- clears Workspace or Terrain globally. Switching back: require(I.IslandBuild).build().

local RunService = game:GetService("RunService")

local Backdrop = require(script.Parent.Recipes.Backdrop)
local Layout = require(script.Parent.Layout)
local Markers = require(script.Parent.Markers)
local Overlay = require(script.Parent.Preview.ReservationOverlay)
local Park = require(script.Parent.Recipes.Park)
local PlotRecipe = require(script.Parent.Recipes.Plot)
local StageA = require(script.Parent.Parent.IslandBuild)

local HubBuild = {}

local ROOT_NAME = "Lane3_IslandPreview"
local PREVIEW_OF = "Lane 3 island hub greybox (revision 3)"

export type Options = { helpers: boolean? }

local function guard()
	assert(RunService:IsStudio(), "HubBuild runs only in Studio")
	assert(not RunService:IsRunning(), "HubBuild runs in edit mode, not during a playtest")
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

-- Removes whichever preview is there: the Stage A build through its own cleanup, the hub directly.
function HubBuild.cleanup(): string
	guard()
	local root = workspace:FindFirstChild(ROOT_NAME)
	if not root then
		return "nothing to clean up"
	end
	if root:GetAttribute("PreviewOf") ~= PREVIEW_OF then
		return "Stage A: " .. StageA.cleanup()
	end
	root:Destroy()
	return "removed the hub preview"
end

function HubBuild.build(options: Options?): { [string]: any }
	guard()
	local o: Options = options or {}
	local started = os.clock()
	local previous = HubBuild.cleanup()

	local root = Instance.new("Model")
	root.Name = ROOT_NAME
	root:SetAttribute("PreviewOf", PREVIEW_OF)
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

	-- with the environment (Task 2) the terrain replaces the greybox ground and backdrop
	local env = workspace:FindFirstChild("Lane3_IslandEnvironment")
	if not (env and env:GetAttribute("TerrainWritten")) then
		Backdrop.build(scenery)
	end
	task.wait()
	Park.build(plaza)
	task.wait()

	for index = 1, Layout.PlotCount do
		local plot = Instance.new("Model")
		plot.Name = string.format("Plot%02d", index)
		plot:SetAttribute("PlotIndex", index)
		plot:SetAttribute("BearingDeg", Layout.plotBearing(index))
		Markers.build(plot, index)
		PlotRecipe.build(plot, index)
		plot.Parent = plots
		if o.helpers ~= false then
			Overlay.buildPlot(helpers, index, index == 1)
		end
		task.wait()
	end
	if o.helpers ~= false then
		Overlay.buildHub(helpers)
	else
		helpers:Destroy()
	end

	return {
		previous = previous,
		seconds = math.round((os.clock() - started) * 100) / 100,
		parts = {
			total = countParts(root),
			plots = countParts(plots),
			plaza = countParts(plaza),
			scenery = countParts(scenery),
			helpers = if helpers.Parent then countParts(helpers) else 0,
		},
		trackSegmentsPerPlot = PlotRecipe.SegmentCount,
		plotCount = Layout.PlotCount,
	}
end

return HubBuild
