--!strict
-- WORLDS UNDER THE REAL ROAD (Lane 3, big round M8). Streams a World's roadside scenery beside Brian R's
-- run road, in step with the run. Beta integration only: the beta glue (Client.Beta.BetaRun) calls attach
-- when ReplicatedStorage.CarHopBeta has the attribute WorldScenery = true; that attribute is the one
-- switch, and nothing else in the game requires this module. It needs ReplicatedStorage.LookDev, which
-- only beta.project.json maps.
--
-- What it reads from the run, and nothing else (recorded in vault/design/specs/lane3-big-round-for-brian-r.md):
--   RunConfig.ORIGIN              the road's start: y up, travel toward -Z, centre line x = 0
--   RunConfig.ROAD_HALF_WIDTH     half the road, shoulders included
--   run:getDebugState().along     distance travelled, in studs (a temporary read, not a contract)
--   run.Ended                     when to stop
-- It never touches the road, lanes, traffic, collision or camera. Brian R's own test scenery cannot be
-- turned off through his API (only "Canyon" or "Circuit"), so the World stands outside it: the Circuit's
-- grandstands reach about 140 studs from the centre line, so everything moves out by PUSH.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Trove = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Trove"))

local RunScenery = {}

local PUSH = 96 -- added to every roadside lateral, so the frontage (50) clears the Circuit's stands
local ROUTE = 9000 -- about two minutes at run speed; the window wraps past it
local SEED = 2207

export type RunLike = {
	getDebugState: (self: any) -> { along: number },
	Ended: any,
}

export type Handle = { destroy: (self: Handle) -> () }

function RunScenery.enabled(): boolean
	local config = ReplicatedStorage:FindFirstChild("CarHopBeta")
	return config ~= nil
		and config:GetAttribute("WorldScenery") == true
		and ReplicatedStorage:FindFirstChild("LookDev") ~= nil
end

-- The uploaded group-owned meshes: the B2 kit plus the World's own, and the World's palette image.
local function kitFor(world: string): ({ [string]: string }, string?)
	local downtown = (ReplicatedStorage :: any).LookDev.Downtown
	local ids: { [string]: string } = {}
	local b2 = (require :: any)(downtown.KitIds)
	for k, v in b2.meshes do
		ids[k] = v
	end
	local worlds = (require :: any)(downtown.WorldsKitIds)
	local own = worlds[world]
	if own then
		for k, v in own.meshes do
			ids[k] = v
		end
	end
	return ids, if own then own.palette else b2.palette
end

-- Starts the World's scenery for one run. Safe to call for any World name the portals use.
function RunScenery.attach(world: string, run: RunLike): Handle
	local trove = Trove.new()
	local RunConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Run"):WaitForChild("RunConfig"))
	local City = (require :: any)((ReplicatedStorage :: any).LookDev.Downtown.City)
	local folder = trove:Add(Instance.new("Folder"))
	folder.Name = "Lane3_WorldUnderRoad"
	folder.Parent = Workspace
	local city: any = nil
	local stopped = false
	local ids, palette = kitFor(world)
	local function stop()
		if stopped then
			return
		end
		stopped = true
		if city then
			city:destroy()
			city = nil
		end
		trove:Destroy()
	end
	trove:Add(task.spawn(function()
		local made = City.new({
			world = world,
			parent = folder,
			preview = true,
			seed = SEED,
			length = ROUTE,
			sceneryOnly = true,
			origin = RunConfig.ORIGIN,
			frontagePush = PUSH,
			controlCamera = false,
			lighting = true,
			meshIds = ids,
			textureId = palette,
		})
		if stopped then
			made:destroy()
			return
		end
		made:build(0)
		if stopped then
			made:destroy()
			return
		end
		city = made
		local length = made.plan.length
		trove:Connect(RunService.Heartbeat, function()
			local state = run:getDebugState()
			made:setStation(state.along % length)
		end)
	end))
	trove:Add(run.Ended:Connect(stop))
	return {
		destroy = function(_self)
			stop()
		end,
	}
end

return RunScenery
