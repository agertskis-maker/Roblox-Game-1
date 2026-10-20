--!strict
-- DEVELOPMENT MEASUREMENTS (Lane 3). Server side, during a Studio playtest of the private
-- island place only. Places the test character at each plot's GateSpawn and walks it along
-- the planned routes with Humanoid:MoveTo, timing each walk at the place's own WalkSpeed.
-- It does not change WalkSpeed, add teleports for players, or assign plots.
--
--   local Walk = require(game.ServerStorage.Island.Preview.WalkTests)
--   Walk.spawnApproaches()   -- all plots: GateSpawn facing check and a walk to the court
--   Walk.routes()            -- timed gate-to-destination routes

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Layout = require(script.Parent.Parent.Layout)
local Promise = require(ReplicatedStorage.Packages.Promise)
local Trove = require(ReplicatedStorage.Packages.Trove)

local WalkTests = {}

local function character(): (Model, Humanoid, BasePart)
	assert(
		RunService:IsStudio() and RunService:IsServer() and RunService:IsRunning(),
		"Run during a Studio playtest, server side"
	)
	local player = Players:GetPlayers()[1]
	assert(player, "No test player")
	local model = player.Character or player.CharacterAdded:Wait()
	local humanoid = model:WaitForChild("Humanoid") :: Humanoid
	local root = model:WaitForChild("HumanoidRootPart") :: BasePart
	return model, humanoid, root
end

local function standHeight(humanoid: Humanoid, root: BasePart): number
	return humanoid.HipHeight + root.Size.Y / 2
end

local function place(model: Model, humanoid: Humanoid, root: BasePart, at: Vector3, facing: Vector3)
	local pos = Vector3.new(at.X, Layout.SurfaceY + standHeight(humanoid, root) + 0.2, at.Z)
	local look = Vector3.new(facing.X, pos.Y, facing.Z)
	model:PivotTo(CFrame.lookAt(pos, look))
	root.AssemblyLinearVelocity = Vector3.zero
	task.wait(1)
end

-- Walks through the waypoints; returns reached, seconds, studs travelled (horizontal).
local function walk(humanoid: Humanoid, root: BasePart, waypoints: { Vector3 }): (boolean, number, number)
	local trove = Trove.new()
	local travelled = 0
	local last = root.Position
	trove:Connect(RunService.Heartbeat, function()
		local p = root.Position
		travelled += Vector2.new(p.X - last.X, p.Z - last.Z).Magnitude
		last = p
	end)
	local started = os.clock()
	local ok = true
	for _, w in waypoints do
		humanoid:MoveTo(w)
		local reached = Promise.fromEvent(humanoid.MoveToFinished)
			:timeout(10)
			:catch(function()
				return false
			end)
			:expect()
		if not reached then
			ok = false
			break
		end
	end
	local seconds = os.clock() - started
	trove:Destroy()
	return ok, seconds, travelled
end

local function r2(n: number): number
	return math.round(n * 100) / 100
end

local function plotMarkers(index: number): BasePart
	local root = workspace:FindFirstChild("Lane3_IslandPreview")
	assert(root, "Build the preview first")
	local plots = (root :: Instance):FindFirstChild("Island"):FindFirstChild("Plots") :: Folder
	local plot = plots:FindFirstChild(string.format("Plot%02d", index)) :: Model
	return plot:FindFirstChild("Markers") :: BasePart
end

function WalkTests.spawnApproaches(): { any }
	local model, humanoid, root = character()
	local results = {}
	for index = 1, Layout.PlotCount do
		local spawnCFrame = (plotMarkers(index):FindFirstChild("GateSpawn") :: Attachment).WorldCFrame
		place(model, humanoid, root, spawnCFrame.Position, spawnCFrame.Position + spawnCFrame.LookVector)
		local look = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z).Unit
		local toCentre = Vector3.new(-root.Position.X, 0, -root.Position.Z).Unit
		local target = Layout.plazaToWorld(Layout.polar(Layout.plotBearing(index), Layout.Plaza.courtRadius + 4))
		local ok, seconds, studs = walk(humanoid, root, { target })
		table.insert(results, {
			plot = index,
			facingDot = r2(look:Dot(toCentre)),
			reachedCourt = ok,
			seconds = r2(seconds),
			studs = r2(studs),
		})
	end
	return results
end

local function gate(index: number): Vector2
	return Layout.polar(Layout.plotBearing(index), Layout.Plaza.gateRadius + 0.5)
end

function WalkTests.routeList(): { { name: string, points: { Vector3 } } }
	local P = Layout.polar
	local W = function(p: Vector2, y: number?): Vector3
		return Layout.plazaToWorld(p, y)
	end
	local downtown = Vector2.new(Layout.Portals.xs[1], Layout.Portals.lineY + Layout.Portals.depth / 2 + 4)
	local function plotPoints(index: number, pts: { Vector2 }, ys: { number }?): { Vector3 }
		local out = {}
		for i, p in pts do
			out[i] = Layout.plotToWorld(Layout.plotBearing(index), p, if ys then ys[i] else nil)
		end
		return out
	end
	local deck = Layout.SurfaceY + Layout.Bridge.deckTop
	local toDeck =
		{ Vector2.new(0, 62.5), Vector2.new(-21, 64.5), Layout.FrontRamps[1].to, Vector2.new(0, Layout.DeckU[1] + 6) }
	local toDeckY = { 0, 0, deck, deck }
	local toPaddock = table.clone(toDeck)
	local toPaddockY = table.clone(toDeckY)
	for _, extra in
		{
			{ Vector2.new(0, Layout.DeckU[2] - 1), deck },
			{ Vector2.new(0, Layout.DeckU[2] + Layout.Bridge.rearRampRun + 2), 0 },
			{ Vector2.new(0, Layout.AisleMidU), 0 },
		}
	do
		table.insert(toPaddock, extra[1] :: Vector2)
		table.insert(toPaddockY, extra[2] :: number)
	end
	return {
		{ name = "Plot03 gate to Downtown (typical)", points = { W(gate(3)), W(P(125, 55)), W(downtown) } },
		{
			name = "Plot08 gate to Downtown (longest, via the west Garage passage)",
			points = {
				W(gate(8)),
				W(P(-18, 56)),
				W(P(-18, 46)),
				W(P(-18, 30)),
				W(P(-40, 24)),
				W(Vector2.new(-4, -12)),
				W(downtown),
			},
		},
		{
			name = "Plot01 gate to Garage front",
			points = { W(gate(1)), W(P(18, 56)), W(P(18, 46)), W(P(8, 31)), W(P(0, 30)) },
		},
		{
			name = "Plot05 gate to Garage hero turntable",
			points = { W(gate(5)), W(P(210, 54)), W(P(225, 46)), W(Vector2.new(-14, -20)), W(Vector2.new(-10, 6)) },
		},
		{ name = "Plot08 gate to Stunt gate", points = { W(gate(8)), W(P(-30, 56)), W(P(-62, 52)), W(P(270, 46)) } },
		{ name = "Plot04 gate to leaderboards", points = { W(gate(4)), W(P(140, 55)), W(P(110, 50)), W(P(102, 48)) } },
		{ name = "Plot02 gate to own bridge deck", points = plotPoints(2, toDeck, toDeckY) },
		{ name = "Plot02 gate to own Paddock aisle (over the bridge)", points = plotPoints(2, toPaddock, toPaddockY) },
	}
end

function WalkTests.routes(): { any }
	local model, humanoid, root = character()
	local results = {}
	for _, route in WalkTests.routeList() do
		local first, second = route.points[1], route.points[2]
		place(model, humanoid, root, first, second)
		local planned = 0
		for i = 2, #route.points do
			local a, b = route.points[i - 1], route.points[i]
			planned += Vector2.new(b.X - a.X, b.Z - a.Z).Magnitude
		end
		local remaining = table.move(route.points, 2, #route.points, 1, {})
		local ok, seconds, studs = walk(humanoid, root, remaining)
		table.insert(results, {
			route = route.name,
			reached = ok,
			seconds = r2(seconds),
			studsWalked = r2(studs),
			studsPlanned = r2(planned),
		})
	end
	return { walkSpeed = humanoid.WalkSpeed, routes = results }
end

return WalkTests
