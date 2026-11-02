--!strict
-- STUNT CIRCUIT COURSE RECIPE (Lane 3, big round M17-01). Builds the whole lap as a place from plain Parts: the road with
-- seven sections in the brief's order, a stadium with a gantry, a checkered line, bleachers with a crowd, flags and light
-- towers, a city backdrop, a warning sign before every obstacle and a numbered arch at every checkpoint. It reads every number
-- from StuntData, so the scenery and Brian R's data proposal are one source.
--
-- OBSTACLES ARE LOOKS ONLY. The slalom barriers, potholes, tunnel, swinging arms and bridge are flagged VisualOnly and
-- NonColliding; the arms have an idle swing (StuntIdle) and nothing else. Only the road surface (slabs, ramps, corner pads and
-- the bridge deck) collides, so a character or a test car can stand on it; every other part has CanCollide, CanQuery and
-- CanTouch off. Driving, collisions, checkpoint logic, timing, ghosts, stats and rewards are Brian R's and Brian L's.
--
-- FROM THE STUDIO COMMAND BAR (edit mode, a private test place with ReplicatedStorage.LookDev mapped):
--   local Course = require(game.ReplicatedStorage.LookDev.Stunt.StuntCourse)
--   local model = Course.build(workspace)        -- the whole lap, about a second
--   print(Course.stats(model))                    -- part counts, collidable parts, the budget
--   print(Course.report())                        -- the data proposal: sections, checkpoints, warnings
--   local idle = Course.idle(model)               -- arms swing, flags sway (idle.stop() to rest them)
--   Course.reset(workspace)                       -- removes the course
--   require(game.ReplicatedStorage.LookDev.Stunt.StuntFly).go("Slalom")      -- approach cameras per section
--   require(game.ReplicatedStorage.LookDev.Stunt.StuntFly).run({ speed = 1 })  -- the timed flythrough (0.8, 1, 1.2)
--
--   Course.build(parent: Instance?) -> Model       Course.stats(model) -> Stats       Course.check() -> { string }
--   Course.idle(model) -> StuntIdle.Handle         Course.reset(parent?)              Course.report() -> string

local Workspace = game:GetService("Workspace")

local Obstacles = require(script.Parent.StuntObstacles)
local Road = require(script.Parent.StuntRoad)
local Signs = require(script.Parent.StuntSigns)
local Stadium = require(script.Parent.StuntStadium)
local StuntData = require(script.Parent.StuntData)
local StuntIdle = require(script.Parent.StuntIdle)

local StuntCourse = {}

StuntCourse.Name = "StuntCourse"
StuntCourse.PartBudget = 1500 -- the brief's ceiling for the whole course ("about 1,500")

export type Stats = {
	parts: number,
	budget: number,
	underBudget: boolean,
	collidable: number,
	queryable: number,
	touchable: number,
	castingShadow: number,
	perGroup: { [string]: number },
	sections: number,
	checkpoints: number,
	warnings: number,
	obstacles: number,
}

function StuntCourse.build(parent: Instance?): Model
	local home = parent or Workspace
	StuntCourse.reset(home)
	local root = Instance.new("Model")
	root.Name = StuntCourse.Name
	root:SetAttribute("Status", StuntData.Status)
	root:SetAttribute("Units", StuntData.Units)
	root:SetAttribute("LapStuds", StuntData.Length)
	root:SetAttribute("NominalSeconds", StuntData.NominalSeconds)
	root:SetAttribute("NominalSpeed", StuntData.NominalSpeed)
	root:SetAttribute("VisualOnlyObstacles", true)
	Road.build(root)
	Obstacles.build(root)
	Signs.build(root)
	Stadium.build(root)
	root.Parent = home
	root:SetAttribute("PartCount", StuntCourse.stats(root).parts)
	return root
end

function StuntCourse.reset(parent: Instance?)
	local home = parent or Workspace
	for _, child in home:GetChildren() do
		if child.Name == StuntCourse.Name and child:IsA("Model") then
			child:Destroy()
		end
	end
end

function StuntCourse.stats(model: Instance): Stats
	local perGroup: { [string]: number } = {}
	local parts, collidable, queryable, touchable, shadows = 0, 0, 0, 0, 0
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			parts += 1
			if d.CanCollide then
				collidable += 1
			end
			if d.CanQuery then
				queryable += 1
			end
			if d.CanTouch then
				touchable += 1
			end
			if d.CastShadow then
				shadows += 1
			end
			-- the group is the first folder or model under the course
			local top: Instance = d
			while true do
				local up = top.Parent
				if up == nil or up == model then
					break
				end
				top = up
			end
			perGroup[top.Name] = (perGroup[top.Name] or 0) + 1
		end
	end
	return {
		parts = parts,
		budget = StuntCourse.PartBudget,
		underBudget = parts <= StuntCourse.PartBudget,
		collidable = collidable,
		queryable = queryable,
		touchable = touchable,
		castingShadow = shadows,
		perGroup = perGroup,
		sections = #StuntData.Sections,
		checkpoints = #StuntData.Checkpoints,
		warnings = #StuntData.Warnings,
		obstacles = #StuntData.Obstacles,
	}
end

-- Starts the idle loop (arms swing, flags sway); the handle's stop() puts every model back at rest.
function StuntCourse.idle(model: Instance): StuntIdle.Handle
	return StuntIdle.start(model)
end

-- The data proposal's own invariants (an empty list means all hold).
function StuntCourse.check(): { string }
	return StuntData.check()
end

function StuntCourse.report(): string
	return StuntData.report()
end

return StuntCourse
