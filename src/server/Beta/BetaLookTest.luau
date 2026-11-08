--!strict
-- BETA-ONLY, STUDIO-ONLY: the server half of the end-to-end look test (Round 8, C-02 and C-03). The client half is
-- src/client/Beta/BetaLookTest. Run it in a Studio Play server, on a TEST save only (the Mock store, or Studio with no DataStore
-- access): ServerStorage.CarHopBetaSelfTest:Invoke("look", player), or, from a tool that cannot call that BindableFunction, set the
-- Player attribute BetaSelfTest = "look" on the server (the answer is printed as "[CarHopBeta selftest] look: ..." and written to
-- the Player attribute BetaSelfTestResult as JSON).
--
-- The server only prepares the save (test Cash, a second car to ride, nothing worn), asks the client for the real-path run, waits
-- (bounded) for its report and puts the save back. A report that never comes is a FAIL line, never a pass. It is not in the list
-- of tests that run by themselves, because it starts a real run.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local BetaConfig = require(ReplicatedStorage.Shared.Beta.BetaConfig)
local BetaData = require(script.Parent.BetaData)
local BetaEconomy = require(script.Parent.BetaEconomy)
local BetaRide = require(script.Parent.BetaRide)
local BetaStyle = require(script.Parent.BetaStyle)
local RosterFixtures = require(ReplicatedStorage.Shared.UI.RosterFixtures)

local BetaLookTest = {}

local TEST_CASH = 5000000
local WAIT_SECONDS = 150
local running = false

function BetaLookTest.run(player: Player): { string }
	if not RunService:IsStudio() then
		return { "FAIL the look test runs in Studio only" }
	end
	if running then
		return { "FAIL the look test is already running" }
	end
	local data = BetaData.get(player)
	if not data then
		return { "FAIL no save loaded for " .. player.Name }
	end
	if not BetaData.isTestSave() then
		return {
			"FAIL the look test changes the save, so it runs on a test save only (the Mock store or no DataStore access)",
		}
	end
	local net = ReplicatedStorage:FindFirstChild(BetaConfig.NetName)
	if not net then
		return { "FAIL no CarHopBetaNet folder" }
	end
	running = true
	local saved = {
		Cash = data.Cash,
		Owned = table.clone(data.Owned),
		Equipped = table.clone(data.Equipped),
		Cars = table.clone(data.Cars),
		RideCar = data.RideCar,
	}
	-- the test save: Cash to buy the four items, Putter and Pizza Runner to ride, nothing owned or worn, Putter picked
	data.Cash = TEST_CASH
	data.Owned = {}
	data.Equipped = table.clone(BetaConfig.Template.Equipped)
	data.Cars = { Putter = { Edition = 1, Copies = 0 }, ["Pizza Runner"] = { Edition = 1, Copies = 0 } }
	data.RideCar = BetaRide.Default
	BetaEconomy.publishCash(player, data)
	BetaEconomy.publishCars(player, data)
	BetaStyle.publish(player)
	BetaRide.publish(player)

	local report = Instance.new("RemoteEvent")
	report.Name = "BetaLookTestReport"
	report.Parent = net
	local nonce = HttpService:GenerateGUID(false)
	local lines: { string }? = nil
	local conn = report.OnServerEvent:Connect(function(from: Player, gotNonce: any, json: any)
		if from ~= player or gotNonce ~= nonce or type(json) ~= "string" or #json > 60000 then
			return
		end
		local ok, decoded = pcall(function()
			return HttpService:JSONDecode(json)
		end)
		if ok and type(decoded) == "table" then
			lines = decoded
		end
	end)
	player:SetAttribute("BetaLookTestRequest", nonce)
	local t0 = os.clock()
	while lines == nil and os.clock() - t0 < WAIT_SECONDS and player.Parent == Players do
		task.wait(0.25)
	end
	conn:Disconnect()
	report:Destroy()
	player:SetAttribute("BetaLookTestRequest", nil)

	-- the save as it was
	local data2 = BetaData.get(player)
	if data2 then
		data2.Cash, data2.Owned, data2.Equipped, data2.Cars, data2.RideCar =
			saved.Cash, saved.Owned, saved.Equipped, saved.Cars, saved.RideCar
		BetaEconomy.publishCash(player, data2)
		BetaEconomy.publishCars(player, data2)
		BetaStyle.publish(player)
		BetaRide.publish(player)
	end
	running = false
	if lines == nil then
		return {
			string.format(
				"FAIL no report from the client within %d s (the run never started, or the client test errored)",
				WAIT_SECONDS
			),
		}
	end
	return lines :: { string }
end

-- A tool that cannot call the BindableFunction sets the Player attribute BetaSelfTest on the server (Studio only).
function BetaLookTest.start()
	if not RunService:IsStudio() then
		return
	end
	local function watch(player: Player)
		-- Studio test saves only: BetaTestGrantCar = "Pizza Runner" puts that car in the Garage (for frames of the car pick)
		player:GetAttributeChangedSignal("BetaTestGrantCar"):Connect(function()
			local id = player:GetAttribute("BetaTestGrantCar")
			local data = BetaData.get(player)
			if type(id) == "string" and data and BetaData.isTestSave() and RosterFixtures.byId(id) then
				data.Cars[id] = { Edition = 1, Copies = 0 }
				BetaEconomy.publishCars(player, data)
				player:SetAttribute("BetaTestGrantCar", nil)
			end
		end)
		player:GetAttributeChangedSignal("BetaSelfTest"):Connect(function()
			local which = player:GetAttribute("BetaSelfTest")
			if which ~= "look" then
				return
			end
			player:SetAttribute("BetaSelfTest", nil)
			task.spawn(function()
				local lines = BetaLookTest.run(player)
				local failed = 0
				for _, line in lines do
					print("[CarHopBeta selftest] look: " .. line)
					if not string.find(line, "^PASS") and not string.find(line, "^NOTE") then
						failed += 1
					end
				end
				print(string.format("[CarHopBeta selftest] look done: %d lines, %d not PASS", #lines, failed))
				player:SetAttribute("BetaSelfTestResult", HttpService:JSONEncode(lines))
			end)
		end)
	end
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	Players.PlayerAdded:Connect(watch)
end

return BetaLookTest
