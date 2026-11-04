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

local BetaRunMap = require(ReplicatedStorage.Shared.Beta:WaitForChild("BetaRunMap"))
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

local unbridge: (cause: string) -> ()

local function stopRun(again: boolean?)
	local run = current
	current = nil
	if run then
		local state = run:getDebugState()
		unbridge(if again then "Retry" else (state.cause or "Quit"))
	end
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
	-- a retry goes straight into another run: the tutorial must not read it as coming home
	if not again and player:GetAttribute("MovementSpeedOwner") == OWNER then
		player:SetAttribute("MovementSpeedOwner", nil)
	end
end

-- Round 5 (L-03, decision 0039): the run report bridge. THE RUN REPORT IS CLIENT-TRUSTED IN THE BETA: Brian R's run is
-- client-only, so the server accepts what is reported here inside hard caps and logs it; this is scaffolding for a private
-- playtest, deleted when Lane 1 reports through the server and Lane 2 checks it. The server hands out the seed, so it can
-- rebuild the run's traffic itself. This bridge listens to the run's own report signals (RunReport.Batch and .Urgent, made
-- "for whoever wires them") and never changes the run. It sends what happened, never an amount: the events as note 0021
-- shapes them, plus the beta-only `betaModel` beside a KeysComplete. The server's grants come back and are counted for the
-- Results card (LaunchPad's runTally); a claim not yet answered counts as pending ("Checking...").
local live: { runId: string?, world: string, tally: any, conns: { RBXScriptConnection } }? = nil

local function netRemote(name: string): Instance?
	local net = ReplicatedStorage:FindFirstChild(BetaConfig.NetName)
	return net and net:FindFirstChild(name)
end

local function newTally(): any
	return { cars = {}, claimCash = 0, joyrideCash = 0, milestoneCash = 0, total = 0, pending = 0, waiting = {} }
end

local function bridge(run: any, world: string, runId: string)
	local state = { runId = runId, world = world, tally = newTally(), conns = {} }
	live = state
	local events = netRemote(BetaConfig.Remotes.RunEvents) :: RemoteEvent?
	local keys = netRemote(BetaConfig.Remotes.KeysComplete) :: RemoteEvent?
	local report = run._report
	if not (report and events and keys) then
		warn("[CarHopBeta] run report bridge not available: this run is not paid")
		return
	end
	table.insert(
		state.conns,
		report.Batch:Connect(function(batch: { any })
			events:FireServer(runId, batch)
		end)
	)
	table.insert(
		state.conns,
		report.Urgent:Connect(function(e: any)
			if e.kind ~= "KeysComplete" then
				return
			end
			local spawn = run._sequence and run._sequence:get(e.index)
			local betaModel = if spawn then BetaRunMap.carFor(world, spawn.family, spawn.rarity) else nil
			local t = state.tally
			if not t.waiting[e.index] then
				t.waiting[e.index] = true
				t.pending += 1
			end
			keys:FireServer(runId, e.index, betaModel)
			-- an answer that never comes is given up after 3 s (the card then shows what is known)
			task.delay(3, function()
				if t.waiting[e.index] then
					t.waiting[e.index] = nil
					t.pending -= 1
				end
			end)
		end)
	)
end

unbridge = function(cause: string)
	local state = live
	if not state then
		return
	end
	for _, c in state.conns do
		c:Disconnect()
	end
	state.conns = {}
	local finish = netRemote(BetaConfig.Remotes.RunEnd) :: RemoteEvent?
	if finish and state.runId then
		finish:FireServer(state.runId, cause)
	end
end

task.spawn(function()
	local granted = ReplicatedStorage:WaitForChild(BetaConfig.NetName, 15)
	local remote = granted and granted:WaitForChild(BetaConfig.Remotes.RunGranted, 5)
	if remote and remote:IsA("RemoteEvent") then
		remote.OnClientEvent:Connect(function(runId: any, grant: any)
			local state = live
			if not (state and state.runId == runId and type(grant) == "table") then
				return
			end
			local t = state.tally
			if type(grant.index) == "number" and t.waiting[grant.index] then
				t.waiting[grant.index] = nil
				t.pending -= 1
			end
			if grant.kind == "claim" then
				table.insert(t.cars, { carId = grant.carId, parked = grant.parked })
				t.claimCash += grant.amount
			elseif grant.kind == "joyride" then
				t.joyrideCash += grant.amount
			elseif grant.kind == "milestone" then
				t.milestoneCash += grant.amount
			end
			t.total = t.claimCash + t.joyrideCash + t.milestoneCash
		end)
	end
end)

local function startRun(world: string): RunController.RunController
	player:SetAttribute("MovementSpeedOwner", OWNER)
	-- the server's seed and run id (a short wait; with no answer the run still plays, unpaid, and says so in Output)
	local seed: number? = nil
	local runId: string? = nil
	local startFn = netRemote(BetaConfig.Remotes.RunStart)
	if startFn and startFn:IsA("RemoteFunction") then
		local ok, reply = pcall(function()
			return startFn:InvokeServer(world, nil)
		end)
		if ok and type(reply) == "table" and type(reply.seed) == "number" and type(reply.runId) == "string" then
			seed, runId = reply.seed, reply.runId
		else
			warn("[CarHopBeta] the server did not start a run for " .. world .. ": this run is not paid")
		end
	end
	local run = RunController.new({ session = session, profile = "Circuit", seed = seed })
	current = run
	if runId then
		bridge(run, world, runId)
	else
		live = { runId = nil, world = world, tally = newTally(), conns = {} }
	end
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
	runTally = function(): any
		return if live then live.tally else newTally()
	end,
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
	local atLocked = false
	for _, carrier in fields:GetChildren() do
		-- the middle carrier of each field is named "<World>Field"
		if carrier:IsA("BasePart") and string.sub(carrier.Name, -5) == "Field" then
			local world = string.sub(carrier.Name, 1, -6)
			local p = carrier.CFrame:PointToObjectSpace(r.Position)
			local half = carrier.Size / 2
			if math.abs(p.X) < half.X and math.abs(p.Y) < half.Y + 3 and math.abs(p.Z) < ENTER + 2 then
				if PortalPreviewState.isLocked(world) then
					atLocked = true
					LaunchPad.lockedPortal(world)
				elseif math.abs(p.Z) < ENTER then
					LaunchPad.enter(world, backTo(carrier, r))
					return
				end
			end
		end
	end
	if not atLocked then
		LaunchPad.lockedAway()
	end
end)

-- Studio test driver (Round 5, L-07 and the multi-client suites): PlayerGui.CarHopBetaControl:Invoke(command, arg).
--   "launch" world   stand on the World's pad and press START (LaunchPad.debug)
--   "autopilot" on   a simple driver: steer round the car ahead, hop when the Keys are done or Heat is high (the same rule
--                    as Brian R's playground driver, written here; his files are not touched)
--   "state"          the run's debug state, the server's tally for this run and the Launch Pad phase
--   "retry" / "home" press the Results card's buttons
-- Nothing here exists outside Studio.
if RunService:IsStudio() then
	local autopilot = false
	local lastHop = 0
	local control = Instance.new("BindableFunction")
	control.Name = "CarHopBetaControl"
	control.OnInvoke = function(command: string, arg: any): any
		if command == "launch" then
			LaunchPad.debug("enter", arg)
			task.wait(3.5)
			return LaunchPad.debug("start")
		elseif command == "autopilot" then
			autopilot = arg == true
			if not autopilot and current then
				current:setSteerOverride(nil)
			end
			return autopilot
		elseif command == "state" then
			local s = if current then current:getDebugState() else nil
			return {
				phase = LaunchPad.phase(),
				mode = s and s.mode,
				metres = s and s.metres,
				claimed = s and s.claimed,
				joyrides = s and s.joyrides,
				runId = live and live.runId,
				tally = live and live.tally,
			}
		elseif command == "retry" or command == "home" then
			return LaunchPad.debug(command)
		end
		return "unknown command " .. tostring(command)
	end
	control.Parent = player:WaitForChild("PlayerGui")
	RunService.Heartbeat:Connect(function()
		local run = current
		if not (autopilot and run) then
			return
		end
		local s = run:getDebugState()
		if s.mode == "Riding" then
			local blocked = s.aheadGap ~= nil and (s.aheadGap :: number) < 90
			run:setSteerOverride(if blocked then (if s.lateral > 0 then -1 else 1) else 0)
			local keysDone = s.keysNeed == nil
			local wantHop = (keysDone and s.heat > 0.3) or s.heat > 0.8 or (blocked and (s.aheadGap :: number) < 8)
			if wantHop and s.target and os.clock() - lastHop > 0.8 then
				lastHop = os.clock()
				run:requestHop()
			end
		elseif s.mode == "FootDash" and s.target then
			run:requestHop()
		end
	end)
end
