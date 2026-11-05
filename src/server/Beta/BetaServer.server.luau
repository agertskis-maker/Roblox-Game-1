--!strict
-- CAR HOP BETA 1 server bootstrap. Off unless ReplicatedStorage.CarHopBeta exists (beta.project.json).
-- Round 5 (decision 0039): the loop's stand-ins (Cash, Lap Pay, the run report, purchases) start here too. They all hang off
-- one remote folder, ReplicatedStorage.CarHopBetaNet, made complete before it is parented so a client never sees half of it.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BetaConfig = require(ReplicatedStorage.Shared.Beta.BetaConfig)
local BetaRunNet = require(ReplicatedStorage.Shared.Beta.BetaRunNet)
if not BetaConfig.enabled() then
	return
end

local BetaData = require(script.Parent.BetaData)
local BetaEconomy = require(script.Parent.BetaEconomy)
local BetaLapPay = require(script.Parent.BetaLapPay)
local BetaLineup = require(script.Parent.BetaLineup)
local BetaMissions = require(script.Parent.BetaMissions)
local BetaOwnership = require(script.Parent.BetaOwnership)
local BetaPurchases = require(script.Parent.BetaPurchases)
local BetaPlots = require(script.Parent.BetaPlots)
local BetaRun = require(script.Parent.BetaRun)
local BetaShop = require(script.Parent.BetaShop)
local EconomyPreview = require(ReplicatedStorage.Shared.UI.EconomyPreview)
local StudioTestService = game:GetService("StudioTestService")
local RunService = game:GetService("RunService")

-- With no SpawnLocation a player appears at the world's centre, which is inside the fountain (Adam, 2026-11-02: spawn in
-- front of it). On the plaza, facing the fountain and the portals beyond it.
local spawnPad = Instance.new("SpawnLocation")
spawnPad.Name = "CarHopBetaSpawn"
spawnPad.Size = Vector3.new(10, 0.2, 10)
spawnPad.CFrame = CFrame.lookAt(Vector3.new(0, 0.1, -30), Vector3.new(0, 0.1, 0))
spawnPad.Anchored = true
spawnPad.CanCollide = false
spawnPad.CanTouch = false
spawnPad.CanQuery = false
spawnPad.Transparency = 1
spawnPad.Neutral = true
spawnPad.Duration = 0
local decal = spawnPad:FindFirstChildOfClass("Decal")
if decal then
	decal:Destroy()
end
spawnPad.Parent = workspace

-- A Studio multi-client test (BetaMultiTest) plays on the Mock store, so tests never touch a real beta save.
if RunService:IsStudio() then
	local ok, args = pcall(function()
		return StudioTestService:GetTestArgs()
	end)
	if ok and type(args) == "table" and (args :: any).suite ~= nil then
		BetaData.useMockStore()
	end
end

local net = Instance.new("Folder")
net.Name = BetaConfig.NetName
-- Round 6 (E-04): the run remotes under Brian L's names, in his folder name (BetaRunNet, a stand-in for EconomyPreviewNet)
local runNet = Instance.new("Folder")
runNet.Name = BetaRunNet.FolderName
BetaShop.start(net)
BetaLineup.start(net)
BetaRun.startRemotes(net, runNet)
BetaLapPay.start(net)
BetaPurchases.start(net) -- Round 6 (R-02): the one ProcessReceipt handler
BetaMissions.start(net) -- Round 6 (G-01): Missions on real events (after BetaShop, which makes BetaResult)
runNet.Parent = ReplicatedStorage
net.Parent = ReplicatedStorage

BetaEconomy.start()
BetaPlots.start()
BetaOwnership.start()
BetaData.start()

-- Studio only: the self-tests run inside the game's OWN module copies (a command-bar require gets fresh copies with no
-- loaded saves). ServerStorage.CarHopBetaSelfTest:Invoke("economy" | "lappay" | "shop" | "run", player?) -> { lines }.
if RunService:IsStudio() then
	local hook = Instance.new("BindableFunction")
	hook.Name = "CarHopBetaSelfTest"
	local function selfTest(which: string, player: Player?): { string }
		if which == "preview" then
			return EconomyPreview.selfTest() -- failures only: an empty list is a pass
		elseif which == "economy" then
			return BetaEconomy.selfTest()
		elseif which == "lappay" then
			return BetaLapPay.selfTest()
		elseif which == "lineup" then
			return BetaLineup.selfTest()
		elseif which == "shop" and player then
			return BetaShop.selfTest(player)
		elseif which == "run" and player then
			return BetaRun.selfTest(player)
		elseif which == "purchases" and player then
			return BetaPurchases.selfTest(player)
		elseif which == "missions" and player then
			return BetaMissions.selfTest(player)
		end
		return { "unknown test " .. tostring(which) }
	end
	hook.OnInvoke = selfTest
	hook.Parent = game:GetService("ServerStorage")

	-- Round 6: the Studio MCP in Adam's Studio cannot call the hook above (it lacks the capability), so in a Studio Play
	-- server every self-test also runs once by itself, a few seconds after the first save loads, on a test save only
	-- (the Mock store, or Studio with no DataStore access). Lines go to Output as "[CarHopBeta selftest] PASS ...".
	local ran = false
	BetaData.Loaded:Connect(function(player: Player)
		if ran or not BetaData.isTestSave() then
			return
		end
		ran = true
		task.delay(6, function()
			for _, which in { "preview", "economy", "lineup", "lappay", "run", "shop", "missions", "purchases" } do
				local ok, lines = pcall(selfTest, which, player)
				local list = if ok and type(lines) == "table" then lines else { "FAIL error: " .. tostring(lines) }
				local failed = 0
				for _, line in list do
					print("[CarHopBeta selftest] " .. which .. ": " .. tostring(line))
					if not string.find(tostring(line), "^PASS") then
						failed += 1
					end
				end
				print(string.format("[CarHopBeta selftest] %s done: %d lines, %d not PASS", which, #list, failed))
			end
		end)
	end)
end
