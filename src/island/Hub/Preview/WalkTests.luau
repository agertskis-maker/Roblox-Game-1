--!strict
-- DEVELOPMENT MEASUREMENTS (Lane 3). Server side, during a Studio playtest of the private
-- island place only. For one destination, six test walkers (default R15 rigs made for the test,
-- removed after it) start at every plot's GateSpawn at the same time and walk the planned
-- route at the default WalkSpeed with Humanoid:MoveTo. Each walker aims at the next waypoint
-- before it arrives, so it does not stop at every point. Nothing here changes a player's
-- WalkSpeed, adds teleports for players or assigns plots; only the test walkers' own WalkSpeed
-- changes, in the boost preview. The playtest discards the walkers and the group.
--
--   local Walk = require(game.ServerStorage.Island.Hub.Preview.WalkTests)
--   Walk.run("Downtown")   -- Fountain, SummitPass, Downtown, DustyHighway, Garage, StuntGate
--   Walk.run("Garage", { boost = true })   -- with the avenue boost (the players' numbers and ease)

local PhysicsService = game:GetService("PhysicsService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local BoostLanes = require(script.Parent.Parent.Environment.BoostLanes)
local Layout = require(script.Parent.Parent.Layout)
local Promise = require(ReplicatedStorage.Packages.Promise)
local Trove = require(ReplicatedStorage.Packages.Trove)
local WalkBoostLogic = require(ReplicatedStorage.Shared.Island.WalkBoostLogic)

local WalkTests = {}

local GROUP = "Lane3WalkTesters"
local MAX_LEG = 40 -- MoveTo gives up after 8 s, so long legs are split
local ARRIVE = 3
local FINISH = 1.5
local TIMEOUT = 60

local function r2(n: number): number
	return math.round(n * 100) / 100
end

local function plotMarkers(index: number): BasePart
	local root = workspace:FindFirstChild("Lane3_IslandPreview")
	assert(root, "Build the hub preview first")
	local plots = (root :: Instance):FindFirstChild("Island"):FindFirstChild("Plots") :: Folder
	return (plots:FindFirstChild(string.format("Plot%02d", index)) :: Model):FindFirstChild("Markers") :: BasePart
end

local function waypoints(points: { Vector2 }): { Vector3 }
	local out: { Vector3 } = {}
	for i = 2, #points do
		local a, b = points[i - 1], points[i]
		local pieces = math.max(1, math.ceil((b - a).Magnitude / MAX_LEG))
		for k = 1, pieces do
			table.insert(out, Layout.planToWorld(a:Lerp(b, k / pieces), Layout.SurfaceY))
		end
	end
	return out
end

local function flat(v: Vector3): Vector2
	return Vector2.new(v.X, v.Z)
end

local function makeWalker(trove: any, name: string, at: CFrame): (Model, Humanoid, BasePart)
	local model =
		Players:CreateHumanoidModelFromDescription(Instance.new("HumanoidDescription"), Enum.HumanoidRigType.R15)
	model.Name = name
	local humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.CollisionGroup = GROUP
		end
	end
	local lift = humanoid.HipHeight + root.Size.Y / 2 + 0.2
	model:PivotTo(at + Vector3.new(0, lift, 0))
	model.Parent = workspace
	root:SetNetworkOwner(nil)
	trove:Add(model)
	return model, humanoid, root
end

-- Boost for the test walkers: with options.boost, a walker on an avenue boost strip follows the
-- same state machine as the players' boost (ReplicatedStorage.Shared.Island.WalkBoostLogic:
-- 1.5 x on a strip, held 0.5 s after stepping off, then eased back over 0.5 s); it never stacks
-- (one state per walker) and starts from the walker's own default WalkSpeed. Plan test only
-- (the walkers stay on the avenue surface).
local strips = BoostLanes.strips()
local function onStrip(p: Vector2): boolean
	return WalkBoostLogic.onStripPlan(p, strips, BoostLanes.HalfWidth)
end

-- Walks one walker along its waypoints; resolves with reached, seconds, studs walked and the
-- seconds spent boosted.
local function walk(humanoid: Humanoid, root: BasePart, points: { Vector3 }, boost: boolean)
	return Promise.new(function(resolve)
		local trove = Trove.new()
		local i = 1
		local travelled = 0
		local last = root.Position
		local started = os.clock()
		local issued = started
		local base = humanoid.WalkSpeed
		local boostState, boostedTime, lastTick = WalkBoostLogic.newState(), 0, started
		humanoid:MoveTo(points[1])
		trove:Connect(RunService.Heartbeat, function()
			local p = root.Position
			travelled += (flat(p) - flat(last)).Magnitude
			last = p
			local now = os.clock()
			if boost then
				local m = WalkBoostLogic.step(boostState, now, onStrip(Vector2.new(p.X, -p.Z)))
				local boosted = m > 1
				humanoid.WalkSpeed = if boosted then base * m else base
				if boosted then
					boostedTime += now - lastTick
				end
			end
			lastTick = now
			local final = i == #points
			local distance = (flat(p) - flat(points[i])).Magnitude
			if final and distance < FINISH then
				trove:Destroy()
				humanoid.WalkSpeed = base
				resolve(true, now - started, travelled, boostedTime)
				return
			end
			if not final and distance < ARRIVE then
				i += 1
				humanoid:MoveTo(points[i])
				issued = now
			elseif now - issued > 4 then
				humanoid:MoveTo(points[i]) -- re-issue before MoveTo's own 8 s timeout
				issued = now
			end
			if now - started > TIMEOUT then
				trove:Destroy()
				humanoid.WalkSpeed = base
				resolve(false, now - started, travelled, boostedTime)
			end
		end)
	end)
end

function WalkTests.run(destination: string, options: { boost: boolean? }?): { [string]: any }
	local boost = (options and options.boost) == true
	assert(
		RunService:IsStudio() and RunService:IsServer() and RunService:IsRunning(),
		"Run during a Studio playtest, server side"
	)
	if not PhysicsService:IsCollisionGroupRegistered(GROUP) then
		PhysicsService:RegisterCollisionGroup(GROUP)
	end
	PhysicsService:CollisionGroupSetCollidable(GROUP, GROUP, false)

	local trove = Trove.new()
	local starts = {}
	local rows = {}
	for _, route in Layout.Data.routes do
		if route.destination == destination then
			local spawnCFrame = (plotMarkers(route.plot):FindFirstChild("GateSpawn") :: Attachment).WorldCFrame
			-- the planned route starts at the gate; the walker starts at the spawn just inside it
			local points = table.clone(route.points)
			points[1] = Layout.worldToPlan(spawnCFrame.Position)
			local _, humanoid, root = makeWalker(trove, string.format("Walker%02d", route.plot), spawnCFrame)
			local planned = 0
			for k = 2, #points do
				planned += (points[k] - points[k - 1]).Magnitude
			end
			local row = {
				plot = route.plot,
				walkSpeed = humanoid.WalkSpeed,
				plannedStuds = r2(planned),
				layoutStuds = r2(route.studs),
				layoutSeconds = r2(route.studs / Layout.Data.walkSpeed),
			}
			table.insert(rows, row)
			table.insert(starts, function()
				return walk(humanoid, root, waypoints(points), boost):andThen(
					function(reached: boolean, seconds: number, studs: number, boosted: number)
						row.reached = reached
						row.seconds = r2(seconds)
						row.studsWalked = r2(studs)
						row.boostedSeconds = r2(boosted)
					end
				)
			end)
		end
	end
	assert(#starts > 0, "No routes for " .. destination)
	task.wait(1) -- let the walkers settle on the ground, then start them together
	local jobs = {}
	for _, start in starts do
		table.insert(jobs, start())
	end
	Promise.all(jobs):expect()
	trove:Destroy()

	table.sort(rows, function(a, b)
		return a.plot < b.plot
	end)
	local best, worst = math.huge, 0
	for _, row in rows do
		if row.reached then
			best = math.min(best, row.seconds)
			worst = math.max(worst, row.seconds)
		end
	end
	return {
		destination = destination,
		boost = if boost then WalkBoostLogic.Multiplier else false,
		plots = rows,
		best = r2(best),
		worst = r2(worst),
		spread = r2(worst - best),
	}
end

return WalkTests
