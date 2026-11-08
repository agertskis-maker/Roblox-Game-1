--!strict
-- BETA-ONLY TEST HELPER for the multi-client Studio tests (Round 5, T-02 to T-04; decision 0039).
-- Same contract as a player: it acts only through the game's own remotes, panels and the Studio run driver.
-- Delete with the beta stand-ins.
--
-- Studio only, and idle unless the server's test harness (BetaMultiTest) sets this player's attribute BetaTestCmd (it only
-- does so inside a StudioTestService session). Each command is answered once on CarHopBetaNet.BetaTestAck (id, JSON).
-- The client never reads GetTestArgs (documented to fail from a client).

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

if not RunService:IsStudio() then
	return
end
-- looked up after the Studio check: a live game client cannot get this service (2026-11-05, an error on every live join)
local StudioTestService = game:GetService("StudioTestService")
local BetaConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Beta"):WaitForChild("BetaConfig"))
if not BetaConfig.enabled() then
	return
end

local player = Players.LocalPlayer
local net = ReplicatedStorage:WaitForChild(BetaConfig.NetName, 30)
if not net then
	return
end

-- what this client has seen of Lap Pay pops, per plot: all of them, and those that carried newCash (only the owner's)
local pops: { [number]: { all: number, withCash: number } } = {}
local lapPaid = net:WaitForChild(BetaConfig.Remotes.LapPaid, 10)
if lapPaid and lapPaid:IsA("RemoteEvent") then
	lapPaid.OnClientEvent:Connect(function(plotIndex: any, _slot: any, _carId: any, _amount: any, newCash: any)
		if type(plotIndex) == "number" then
			local p = pops[plotIndex] or { all = 0, withCash = 0 }
			p.all += 1
			if newCash ~= nil then
				p.withCash += 1
			end
			pops[plotIndex] = p
		end
	end)
end

local function control(): BindableFunction?
	local c = player:WaitForChild("PlayerGui"):WaitForChild("CarHopBetaControl", 10)
	return if c and c:IsA("BindableFunction") then c else nil
end

-- the text the run HUD's Cash counter shows now (PlayerGui.RunHud, Lane 3)
local function hudCash(): string?
	local gui = player.PlayerGui:FindFirstChild("RunHud")
	if not gui then
		return nil
	end
	for _, d in gui:GetDescendants() do
		if d:IsA("TextLabel") and string.match(d.Text, "^%$[%d,%.KMBTQa]+$") then
			return d.Text
		end
	end
	return nil
end

local function plotModel(index: number): Instance?
	local root = Workspace:FindFirstChild("Lane3_IslandPreview")
	local plots = root and root:FindFirstChild("Island") and root.Island:FindFirstChild("Plots")
	return plots and plots:FindFirstChild(string.format("Plot%02d", index))
end

local handlers: { [string]: (any) -> any } = {}

handlers.ping = function()
	return { ok = true }
end

handlers.setSlot = function(arg: any)
	local r = net:FindFirstChild(BetaConfig.Remotes.SetLineupSlot) :: RemoteEvent
	r:FireServer(arg.slot, arg.car)
	return { ok = true }
end

-- a hostile client: extra and malformed arguments naming another player's plot and UserId
handlers.forge = function(arg: any)
	local r = net:FindFirstChild(BetaConfig.Remotes.SetLineupSlot) :: RemoteEvent
	r:FireServer(1, nil, arg.plot, arg.userId)
	task.wait(0.4)
	r:FireServer(arg.plot, "Minnow", arg.userId)
	task.wait(0.4)
	r:FireServer({ plot = arg.plot, owner = arg.userId }, { slot = 1 })
	task.wait(0.4)
	r:FireServer(math.huge, string.rep("x", 200))
	return { ok = true }
end

handlers.goPlot = function(index: any)
	local plot = plotModel(index)
	local r = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local bearing = plot and plot:GetAttribute("BearingDeg")
	if r and type(bearing) == "number" then
		-- the plot's track centre is 441 studs out along its bearing; stand at its gate side, 360 out
		local a = math.rad(bearing)
		local at = Vector3.new(math.sin(a) * 360, 6, -math.cos(a) * 360)
		r.CFrame = CFrame.new(at)
	end
	return { ok = true }
end

handlers.resetSeen = function()
	table.clear(pops)
	return { ok = true }
end

handlers.report = function(index: any)
	local cars = 0
	local folder = Workspace:FindFirstChild("Lane3_RacewayLineup")
	local owner: Player? = nil
	local plot = plotModel(index)
	local ownerId = plot and plot:GetAttribute("Owner")
	if type(ownerId) == "number" then
		owner = Players:GetPlayerByUserId(ownerId)
	end
	if folder and owner then
		-- the cars this client built for that owner's Lineup (RacewayLineup builds one per Lineup entry)
		cars = #BetaConfig.splitList(owner:GetAttribute(BetaConfig.LineupAttribute))
		local models = 0
		for _, m in folder:GetChildren() do
			if m:IsA("Model") then
				models += 1
			end
		end
		cars = math.min(cars, models)
	end
	local p = pops[index] or { all = 0, withCash = 0 }
	return { carsOnPlot = cars, pops = p.all, popsWithCash = p.withCash }
end

handlers.run = function(world: any)
	-- a run can only start from the island once the loading screen is gone
	local t0 = os.clock()
	while player:GetAttribute("Lane3LoadingDone") ~= true and os.clock() - t0 < 40 do
		task.wait(0.25)
	end
	task.wait(2)
	local c = control()
	if not c then
		return { ok = false }
	end
	c:Invoke("autopilot", true)
	return { ok = true, phase = c:Invoke("launch", world) }
end

handlers.state = function()
	local c = control()
	local s = if c then c:Invoke("state") else nil
	return {
		runId = s and s.runId,
		metres = s and s.metres,
		mode = s and s.mode,
		tally = s and s.tally,
		hudCash = hudCash(),
		cash = player:GetAttribute(BetaConfig.CashAttribute),
	}
end

handlers.leave = function()
	task.delay(0.3, function()
		pcall(function()
			StudioTestService:LeaveTest()
		end)
	end)
	return { ok = true }
end

local ack = net:WaitForChild("BetaTestAck", 600) :: RemoteEvent?
if not ack then
	return
end
-- client-made attributes never reach the server, so "ready" is said on the ack channel
ack:FireServer("ready", "{}")
player:GetAttributeChangedSignal("BetaTestCmd"):Connect(function()
	local text = player:GetAttribute("BetaTestCmd")
	if type(text) ~= "string" then
		return
	end
	local ok, msg = pcall(function()
		return HttpService:JSONDecode(text)
	end)
	if not ok or type(msg) ~= "table" then
		return
	end
	local handler = handlers[msg.cmd]
	task.spawn(function()
		local done, result = pcall(function()
			return if handler then handler(msg.arg) else { error = "unknown command " .. tostring(msg.cmd) }
		end)
		local reply = if done then result else { error = tostring(result) }
		ack:FireServer(msg.id, HttpService:JSONEncode(reply))
	end)
end)
