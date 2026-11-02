--!strict
-- CAR HOP BETA: the portals and the run. Walking into an open World portal on the island goes to that World's Launch Pad (Lane 3,
-- Client.UI.LaunchPad), and START on the pad's ramp comes back here to start Brian R's run (Client.Run.RunController, the "Circuit"
-- profile he plays). LaunchPad owns everything between runs, including the results card. While a run is on, the takeover
-- attribute MovementSpeedOwner = "CarHopBetaRun" tells the island walking speed to stand aside (vault/design/specs/walk-boost.md).
-- Nothing from a run is saved, and the cars are his placeholder families.
-- Off unless ReplicatedStorage.CarHopBeta exists.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local BetaConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Beta"):WaitForChild("BetaConfig"))
if not BetaConfig.enabled() then
	return
end

local RunConfig = require(ReplicatedStorage.Shared:WaitForChild("Run"):WaitForChild("RunConfig"))
local RunController = require(script.Parent.Parent:WaitForChild("Run"):WaitForChild("RunController"))
local PortalPreviewState =
	require(script.Parent.Parent:WaitForChild("Home"):WaitForChild("Island"):WaitForChild("PortalPreviewState"))
local UI = script.Parent.Parent:WaitForChild("UI")
local RunScenery = require(UI:WaitForChild("WorldsUnderRoad"):WaitForChild("RunScenery"))
local Tutorial = require(UI:WaitForChild("Tutorial"))
local LaunchPad = require(UI:WaitForChild("LaunchPad"))

local player = Players.LocalPlayer
local OWNER = "CarHopBetaRun"
local ENTER = 3 -- studs from a field's plane
local BACK = 14 -- studs in front of the portal where the player comes back

-- one play session's run state (what was claimed, Rider Level, free revives); not saved
local session: RunController.Session = {
	owned = {},
	level = RunConfig.START_RIDER_LEVEL,
	revives = RunConfig.FREE_REVIVES,
}

local current: RunController.RunController? = nil
local scenery: RunScenery.Handle? = nil -- the World beside the road (big round M8)

local function root(): BasePart?
	local character = player.Character
	local r = character and character:FindFirstChild("HumanoidRootPart")
	return if r and r:IsA("BasePart") then r else nil
end

local function stopRun()
	local run = current
	current = nil
	if run then
		run.Ended:Fire() -- what his Retry button fires: the tutorial and the scenery are listening
	end
	if scenery then
		scenery:destroy()
		scenery = nil
	end
	if run then
		run:destroy()
	end
	if player:GetAttribute("MovementSpeedOwner") == OWNER then
		player:SetAttribute("MovementSpeedOwner", nil)
	end
end

local function startRun(world: string): RunController.RunController
	player:SetAttribute("MovementSpeedOwner", OWNER)
	local run = RunController.new({ session = session, profile = "Circuit" })
	current = run
	run:start()
	-- the run's keyboard hint names keys and sits on the Heat panel; phones play too. A label only: nothing else changes.
	local overlay = player.PlayerGui:FindFirstChild("Lane1RunOverlay")
	if overlay then
		for _, d in overlay:GetDescendants() do
			if d:IsA("TextLabel") and string.find(d.Text, "Cut lanes", 1, true) then
				d.Visible = false
			end
		end
	end
	Tutorial.attachRun(run) -- the tutorial's run steps read the run, they never change it
	if RunScenery.enabled() then
		scenery = RunScenery.attach(world, run)
	end
	print(string.format("[CarHopBeta] %s run started (seed %d)", world, run.seed))
	return run
end

LaunchPad.configure({
	startRun = startRun,
	stopRun = stopRun,
	revive = function()
		if current then
			current:revive()
		end
	end,
} :: any)

if RunScenery.enabled() then
	RunScenery.prepareAll() -- the three Worlds load in the background, so a run starts in its World
end
LaunchPad.prepare()

player.CharacterAdded:Connect(function()
	if current then
		stopRun()
	end
	LaunchPad.reset()
end)

-- where a portal puts the player back: the island side of its field, facing it
local function backTo(field: BasePart, r: BasePart): CFrame
	local front = field.CFrame * CFrame.new(0, 0, -BACK)
	local side = if (front.Position - field.Position):Dot(r.Position - field.Position) >= 0
		then front
		else field.CFrame * CFrame.new(0, 0, BACK)
	local ground = side.Position - Vector3.new(0, field.Size.Y / 2 - 3, 0)
	return CFrame.lookAt(ground, Vector3.new(field.Position.X, ground.Y, field.Position.Z))
end

local last = 0
RunService.Heartbeat:Connect(function()
	local now = os.clock()
	if LaunchPad.phase() ~= "island" or now - last < 0.1 then
		return
	end
	last = now
	local r = root()
	local fields = Workspace:FindFirstChild("Lane3_PortalFields")
	if not (r and fields) then
		return
	end
	for _, carrier in fields:GetChildren() do
		-- the middle carrier of each field is named "<World>Field"
		if carrier:IsA("BasePart") and string.sub(carrier.Name, -5) == "Field" then
			local world = string.sub(carrier.Name, 1, -6)
			local p = carrier.CFrame:PointToObjectSpace(r.Position)
			local half = carrier.Size / 2
			if
				math.abs(p.X) < half.X
				and math.abs(p.Y) < half.Y + 3
				and math.abs(p.Z) < ENTER
				and not PortalPreviewState.isLocked(world)
			then
				LaunchPad.enter(world, backTo(carrier, r))
				return
			end
		end
	end
end)
