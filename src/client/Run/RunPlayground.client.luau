--!strict
-- PLAYGROUND BOOTSTRAP (Lane 1 run prototype). Runs only in Brian R's private Lane 1 test place:
-- it needs Studio AND ReplicatedStorage.Lane1Playground with attribute Kind == "run", which only
-- the private project file adds (kept outside the repo, like Lane 3's playgrounds). The game's
-- default.project.json never creates that marker, so real players never start this run.
--
-- Control from the Studio command bar or MCP (client side):
--   local c = game.Players.LocalPlayer.PlayerGui:WaitForChild("Lane1RunControl")
--   c:Invoke("debug")            -> JSON of the run state
--   c:Invoke("hop")              -> request a Hop
--   c:Invoke("steer", -1 .. 1)   -> hold a steer value; c:Invoke("steer") gives control back
--   c:Invoke("miss")             -> the next landing misses (Foot Dash check)
--   c:Invoke("retry", seed?)     -> start a new run
--   c:Invoke("revive")           -> use a free revive after a run ends
--   c:Invoke("level", n)         -> set the session Rider Level (testing the Needs gate)
--   c:Invoke("autopilot", true)  -> a simple test driver that steers and hops by itself

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local marker = ReplicatedStorage:FindFirstChild("Lane1Playground")
if not (RunService:IsStudio() and marker and marker:GetAttribute("Kind") == "run") then
	return
end

local RunController = require(script.Parent:WaitForChild("RunController"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local RunConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Run"):WaitForChild("RunConfig"))
-- One playtest session: what was claimed, the Rider Level and free revives. Never saved.
local session: RunController.Session = {
	owned = {},
	level = RunConfig.START_RIDER_LEVEL,
	revives = RunConfig.FREE_REVIVES,
}
-- Brian R's playtest uses the proposed racing-circuit profile (crash ends the run). Switch with
-- c:Invoke("profile", "Highway") to compare with the outline's run.
local profile = "Circuit"
local current: RunController.RunController? = nil
local autopilot = false
local lastAutoHop = 0

local function startRun(seed: number?)
	if current then
		current:destroy()
		current = nil
	end
	local character = player.Character or player.CharacterAdded:Wait()
	character:WaitForChild("HumanoidRootPart")
	local run = RunController.new({ seed = seed, session = session, profile = profile })
	current = run
	run.Ended:Connect(function()
		task.defer(startRun, nil)
	end)
	run:start()
	print(string.format("[Lane1Run] run started, seed %d", run.seed))
end

local control = Instance.new("BindableFunction")
control.Name = "Lane1RunControl"
control.OnInvoke = function(command: string, arg: any): any
	local run = current
	if command == "retry" then
		startRun(if typeof(arg) == "number" then arg else nil)
		return "started"
	elseif command == "profile" then
		profile = if arg == "Highway" then "Highway" else "Circuit"
		startRun(nil)
		return profile
	elseif command == "autopilot" then
		autopilot = arg == true
		if not autopilot and run then
			run:setSteerOverride(nil)
		end
		return autopilot
	end
	if not run then
		return "no run"
	end
	if command == "debug" then
		return HttpService:JSONEncode(run:getDebugState())
	elseif command == "hop" then
		run:requestHop()
		return "hop requested"
	elseif command == "steer" then
		run:setSteerOverride(if typeof(arg) == "number" then arg else nil)
		return "ok"
	elseif command == "revive" then
		return run:revive()
	elseif command == "level" then
		session.level = if typeof(arg) == "number" then arg else session.level
		return session.level
	elseif command == "miss" then
		run:forceMiss()
		return "next landing misses"
	end
	return "unknown command " .. tostring(command)
end
control.Parent = playerGui

-- Test driver for playtests: dodge the car ahead, hop when the Keys are done or Heat is high.
RunService.Heartbeat:Connect(function()
	local run = current
	if not (autopilot and run) then
		return
	end
	local s = run:getDebugState()
	if s.mode == "Riding" then
		local blocked = s.aheadGap ~= nil and (s.aheadGap :: number) < (if profile == "Circuit" then 90 else 25)
		run:setSteerOverride(if blocked then (if s.lateral > 0 then -1 else 1) else 0)
		local keysDone = s.keysNeed == nil
		local wantHop = (keysDone and s.heat > 0.3) or s.heat > 0.8 or (blocked and (s.aheadGap :: number) < 8)
		if wantHop and s.target and os.clock() - lastAutoHop > 0.8 then
			lastAutoHop = os.clock()
			run:requestHop()
		end
	elseif s.mode == "FootDash" and s.target then
		run:requestHop()
	end
end)

startRun(nil)
