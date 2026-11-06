--!strict
-- WORLDS UNDER THE REAL ROAD (Lane 3, big round M8; Round 2, Adam 2026-11-02: "replace Brian R's placeholder
-- background with the 3 maps ... keep his gameplay and game mechanics"). A run in the beta plays on Brian R's road, with
-- his cars, rules and camera, in the World of the portal the player walked into. Beta integration only: the beta glue
-- (Client.Beta.BetaRun) calls prepareAll and attach when ReplicatedStorage.CarHopBeta has WorldScenery = true; nothing else
-- in the game requires this module. It needs ReplicatedStorage.LookDev, which only beta.project.json maps.
--
-- What it reads from the run, and nothing else:
--   RunConfig.ORIGIN              the road's start: y up, travel toward -Z, centre line x = 0
--   RunConfig.ROAD_HALF_WIDTH     half the road, shoulders included
--   run:getDebugState().along     distance travelled, in studs (a temporary read, not a contract)
--   run.Ended                     when to stop
--   Workspace.Lane1_RunZone.Road  the segments his RunRoad streams
-- His files are not edited, and the road, lanes, traffic, hazards and camera are not touched. The run has no scenery off
-- option yet (the message to Brian R asks for one), so this does it from outside: with ReplaceRoadside = true, every part
-- of a segment that is wider than the road or stands above it is removed as the segment arrives. Only his road surface, its
-- kerbs and its markings stay. That happens only once the World is standing, so the road is never left in empty sky.
--
-- A World takes about 20 s to load in Studio, and a run can be over sooner, so all three are prepared in the background
-- after join and kept for the session. A run started before its World is ready begins with his scenery and swaps when
-- the World arrives.
--
-- Round 7 (R-08, Adam: "if you play the game for long enough, the map actually just disappears"): a World is one route of
-- about 9,000 studs at fixed positions, and his road goes on for ever, so past the route's end the car drove on bare road.
-- Now the route repeats in laps: lap k is the same World built again with its origin k route-lengths further down the road,
-- made in the background halfway through the lap before, shown ahead of the car before it gets there, and freed once the car
-- is well past it. Lap 0 is the prepared one and is kept for the next run; later laps are destroyed.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Trove = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Trove"))

local RunScenery = {}

local PUSH_BESIDE = 96 -- with his scenery kept: every roadside lateral moves out past his stands
local ROUTE = 9000 -- about two minutes at run speed; the window wraps past it
local SEED = 2207
local ROAD_MARGIN = 0.7 -- a part may reach this far past the road's edge and still be the road
local WORLDS = { "Downtown", "DustyHighway", "SummitPass" }

export type RunLike = {
	getDebugState: (self: any) -> { along: number },
	Ended: any,
}

export type Handle = { destroy: (self: Handle) -> () }

type Prepared = { city: any, folder: Folder }

local prepared: { [string]: Prepared } = {}
local preparing: { [string]: boolean } = {}

local function config(): Instance?
	return ReplicatedStorage:FindFirstChild("CarHopBeta")
end

function RunScenery.enabled(): boolean
	local c = config()
	return c ~= nil and c:GetAttribute("WorldScenery") == true and ReplicatedStorage:FindFirstChild("LookDev") ~= nil
end

local function replaces(): boolean
	local c = config()
	return c ~= nil and c:GetAttribute("ReplaceRoadside") == true
end

-- The uploaded group-owned meshes: the B2 kit plus the World's own, and the World's palette image.
local function kitFor(world: string): ({ [string]: string }, string?)
	local downtown = (ReplicatedStorage :: any).LookDev.Downtown
	local b2 = (require :: any)(downtown.KitIds)
	local ids: { [string]: string } = table.clone(b2.meshes)
	local worlds = (require :: any)(downtown.WorldsKitIds)
	local own = worlds[world]
	if own then
		for k, v in own.meshes do
			ids[k] = v
		end
	end
	return ids, if own then own.palette else b2.palette
end

-- Builds one lap of a World out of sight (the folder is not in the Workspace): lap 0 starts at the road's origin, lap k
-- "shift" studs further down the road.
local function buildLap(world: string, shift: number): Prepared?
	local RunConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Run"):WaitForChild("RunConfig"))
	local City = (require :: any)((ReplicatedStorage :: any).LookDev.Downtown.City)
	local folder = Instance.new("Folder")
	folder.Name = "Lane3_WorldUnderRoad"
	local ids, palette = kitFor(world)
	local made: Prepared? = nil
	local ok, err = pcall(function()
		local city = City.new({
			world = world,
			parent = folder,
			preview = true,
			seed = SEED,
			length = ROUTE,
			sceneryOnly = true,
			origin = RunConfig.ORIGIN * CFrame.new(0, 0, -shift),
			frontagePush = if replaces() then 0 else PUSH_BESIDE,
			controlCamera = false,
			lighting = false,
			meshIds = ids,
			textureId = palette,
		})
		city:build(0)
		made = { city = city, folder = folder }
	end)
	if not ok then
		warn("[RunScenery] " .. world .. " failed: " .. tostring(err))
		folder:Destroy()
	end
	return made
end

-- Builds lap 0 of one World and keeps it for the session.
local function prepare(world: string)
	if prepared[world] or preparing[world] then
		return
	end
	preparing[world] = true
	prepared[world] = buildLap(world, 0)
	preparing[world] = false
end

-- Prepares every World in the background, each on its own, so a slow one holds no other up.
function RunScenery.prepareAll()
	for _, world in WORLDS do
		task.spawn(prepare, world)
	end
end

function RunScenery.ready(world: string): boolean
	return prepared[world] ~= nil
end

-- Leaves only his road in a segment: its surface, kerbs and markings.
local function trim(segment: Instance, originY: number, half: number): number
	local removed = 0
	for _, d in segment:GetDescendants() do
		if d:IsA("BasePart") then
			local reach = math.abs(d.Position.X) + d.Size.X / 2
			local top = d.Position.Y + d.Size.Y / 2
			if reach > half + ROAD_MARGIN or top > originY + 1 then
				d:Destroy()
				removed += 1
			end
		end
	end
	return removed
end

-- Shows the World for one run. Safe to call for any World name the portals use.
function RunScenery.attach(world: string, run: RunLike): Handle
	local trove = Trove.new()
	local RunConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Run"):WaitForChild("RunConfig"))
	local City = (require :: any)((ReplicatedStorage :: any).LookDev.Downtown.City)
	local stopped = false
	local shown: Prepared? = nil
	local laps: { [number]: Prepared | false } = {} -- lap k > 0: false while it is being built
	local function stop()
		if stopped then
			return
		end
		stopped = true
		if shown then
			shown.folder.Parent = nil -- kept for the next run
			shown = nil
		end
		for _, lap in laps do
			if lap then
				lap.city:destroy()
				lap.folder:Destroy()
			end
		end
		table.clear(laps)
		City.restoreLighting() -- never leave one World's light behind
		trove:Destroy()
	end
	local function show(p: Prepared)
		shown = p
		local length = p.city.plan.length
		p.city:applyLighting()
		local function lapOf(k: number): Prepared?
			if k == 0 then
				return p
			end
			local lap = laps[k]
			return if lap then lap else nil
		end
		local function ensure(k: number)
			if k <= 0 or laps[k] ~= nil then
				return
			end
			laps[k] = false
			task.spawn(function()
				local made = buildLap(world, k * length)
				if stopped or laps[k] ~= false then
					if made then
						made.city:destroy()
						made.folder:Destroy()
					end
					return
				end
				laps[k] = made or nil
			end)
		end
		local function step()
			local along = run:getDebugState().along
			local k = math.max(math.floor(along / length), 0)
			local into = along - k * length
			if k >= 2 then
				p.folder.Parent = nil -- lap 0 is far behind now
			end
			-- the lap under the car, and the next one ahead of it once the car is 80% of the way through
			for j = k - 1, k + 1 do
				local lap = lapOf(j)
				if lap then
					local wanted = j == k or (j == k + 1 and into > length * 0.8) or (j == k - 1 and into < 400)
					if wanted then
						lap.city:setStation(along - j * length)
						lap.folder.Parent = Workspace
					else
						lap.folder.Parent = nil
					end
				end
			end
			if into > length * 0.5 then
				ensure(k + 1)
			end
			-- a lap well behind the car is freed (lap 0 is kept for the next run)
			for j, lap in laps do
				if lap and j < k - 1 then
					lap.city:destroy()
					lap.folder:Destroy()
					laps[j] = nil
				end
			end
		end
		step()
		trove:Connect(RunService.Heartbeat, step)
		if not replaces() then
			return
		end
		local zone = Workspace:FindFirstChild("Lane1_RunZone")
		local road = zone and zone:FindFirstChild("Road")
		if not road then
			return
		end
		local originY = RunConfig.ORIGIN.Position.Y
		local half = RunConfig.ROAD_HALF_WIDTH
		for _, segment in road:GetChildren() do
			trim(segment, originY, half)
		end
		trove:Connect(road.ChildAdded, function(segment: Instance)
			trim(segment, originY, half)
		end)
	end
	trove:Add(run.Ended:Connect(stop))
	trove:Add(task.spawn(function()
		prepare(world)
		while not prepared[world] and preparing[world] and not stopped do
			task.wait(0.1)
		end
		local p = prepared[world]
		if p and not stopped then
			show(p)
		end
	end))
	return {
		destroy = function(_self)
			stop()
		end,
	}
end

return RunScenery
