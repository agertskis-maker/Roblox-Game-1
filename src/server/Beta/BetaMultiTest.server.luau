--!strict
-- BETA-ONLY TEST HARNESS for the multi-client Studio tests (Round 5, T-02 to T-04; decision 0039).
-- Same contract as everything it tests: it drives the beta stand-ins only through their own functions and the clients only
-- through PlayerGui test commands. Delete with the beta stand-ins.
--
-- Runs only in Studio AND only when StudioTestService:GetTestArgs() returns { suite, nonce, clients } (read on the server;
-- the documented client-side GetTestArgs failure is avoided). An ordinary Play has no args and does nothing. Started by the
-- local plugin CatchACar-MultiTest (Car-Hop-Art\tools\multitest-plugin.lua). Every wait is bounded; a timeout is a FAIL
-- with its reason, never a pass. Evidence is collected before EndTest(result) ends the session.
--
-- Clients act on a server command: the Player attribute BetaTestCmd = JSON { id, cmd, arg } is read by the beta client
-- helper (src/client/Beta/BetaMultiTestClient), which answers on the RemoteEvent CarHopBetaNet.BetaTestAck (id, JSON).

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ScriptContext = game:GetService("ScriptContext")
local StudioTestService = game:GetService("StudioTestService")

if not RunService:IsStudio() then
	return
end
local okArgs, args = pcall(function()
	return StudioTestService:GetTestArgs()
end)
if not (okArgs and type(args) == "table" and type((args :: any).suite) == "string") then
	return
end
local suite: string = (args :: any).suite
local nonce: string = tostring((args :: any).nonce)
local expected: number = tonumber((args :: any).clients) or 1

local BetaConfig = require(ReplicatedStorage.Shared.Beta.BetaConfig)
if not BetaConfig.enabled() then
	return
end
local BetaData = require(script.Parent.BetaData)
local BetaEconomy = require(script.Parent.BetaEconomy)
local BetaLapPay = require(script.Parent.BetaLapPay)
local BetaLineup = require(script.Parent.BetaLineup)
local BetaPlots = require(script.Parent.BetaPlots)
local BetaShop = require(script.Parent.BetaShop)
local EconomyPreview = require(ReplicatedStorage.Shared.UI.EconomyPreview)
local RosterFixtures = require(ReplicatedStorage.Shared.UI.RosterFixtures)
local Format = require(ReplicatedStorage.Shared.UI.Format)

local started = os.clock()
local checks: { { name: string, pass: boolean, detail: string } } = {}
local errors: { string } = {}
local notes: { string } = {}

ScriptContext.Error:Connect(function(message: string, trace: string)
	if #errors < 30 then
		table.insert(errors, message .. " | " .. string.sub(trace, 1, 200))
	end
end)

local function check(name: string, pass: boolean, detail: any)
	table.insert(checks, { name = name, pass = pass, detail = tostring(detail) })
	print(string.format("[MultiTest] %s %s: %s", if pass then "PASS" else "FAIL", name, tostring(detail)))
end

local function waitFor(seconds: number, fn: () -> boolean): boolean
	local t0 = os.clock()
	while os.clock() - t0 < seconds do
		if fn() then
			return true
		end
		task.wait(0.2)
	end
	return fn()
end

-- the ack channel
local net = ReplicatedStorage:WaitForChild(BetaConfig.NetName, 20) :: Folder
local ack = Instance.new("RemoteEvent")
ack.Name = "BetaTestAck"
ack.Parent = net
local replies: { [string]: any } = {}
local readyPlayers: { [Player]: boolean } = {}
ack.OnServerEvent:Connect(function(player: Player, id: any, json: any)
	if id == "ready" then
		readyPlayers[player] = true
		return
	end
	if type(id) == "string" and type(json) == "string" and #json < 20000 then
		local ok, value = pcall(function()
			return HttpService:JSONDecode(json)
		end)
		replies[id] = if ok then value else { error = "bad json from " .. player.Name }
	end
end)

local cmdCount = 0
local busyPlayers: { [Player]: boolean } = {}
-- sends one command to a client and waits (bounded) for its answer; nil on timeout. One command per player at a time: a
-- client sees only the last value of an attribute changed twice in one frame.
local function command(player: Player, cmd: string, arg: any?, timeout: number?): any
	local t0 = os.clock()
	while busyPlayers[player] and os.clock() - t0 < 90 do
		task.wait(0.1)
	end
	busyPlayers[player] = true
	cmdCount += 1
	local id = string.format("%s-%d", nonce, cmdCount)
	player:SetAttribute("BetaTestCmd", HttpService:JSONEncode({ id = id, cmd = cmd, arg = arg }))
	local got = waitFor(timeout or 15, function()
		return replies[id] ~= nil
	end)
	local reply = replies[id]
	replies[id] = nil
	busyPlayers[player] = nil
	if not got then
		table.insert(notes, string.format("no answer from %s to %s", player.Name, cmd))
	end
	return reply
end

local function ready(player: Player): boolean
	return BetaData.get(player) ~= nil
		and player:GetAttribute(BetaConfig.HomePlotAttribute) ~= nil
		and readyPlayers[player] == true
end

local function waitPlayers(n: number, timeout: number): { Player }
	waitFor(timeout, function()
		local count = 0
		for _, p in Players:GetPlayers() do
			if ready(p) then
				count += 1
			end
		end
		return count >= n
	end)
	local list = {}
	for _, p in Players:GetPlayers() do
		if ready(p) then
			table.insert(list, p)
		end
	end
	table.sort(list, function(a, b)
		return (a:GetAttribute(BetaConfig.HomePlotAttribute) :: number)
			< b:GetAttribute(BetaConfig.HomePlotAttribute) :: number
	end)
	return list
end

local function plotOf(player: Player): Model?
	return BetaPlots.plotOf(player)
end

-- a test save shape: owned cars and a Lineup, set through the save (the same table the stand-ins use) and republished
local function giveCars(player: Player, ids: { string }, park: { string })
	local data = BetaData.get(player) :: BetaData.Data
	for _, id in ids do
		data.Cars[id] = data.Cars[id] or { Edition = 1, Copies = 0 }
	end
	data.Lineup = table.clone(park)
	data.TutorialDone = true
	player:SetAttribute(BetaConfig.TutorialDoneAttribute, true)
	BetaEconomy.publishCars(player, data)
	BetaLineup.publish(player)
end

local function finish()
	local passCount, failCount = 0, 0
	for _, c in checks do
		if c.pass then
			passCount += 1
		else
			failCount += 1
		end
	end
	local result = {
		suite = suite,
		nonce = nonce,
		build = "integration/beta-2 + local pull",
		expectedClients = expected,
		seconds = math.floor((os.clock() - started) * 10) / 10,
		pass = failCount == 0 and #checks > 0 and #errors == 0,
		passed = passCount,
		failed = failCount,
		checks = checks,
		serverErrors = errors,
		notes = notes,
	}
	print("[MultiTest] " .. HttpService:JSONEncode(result))
	task.wait(1)
	StudioTestService:EndTest(result)
end

local suites: { [string]: () -> () } = {}

suites.smoke = function()
	local list = waitPlayers(expected, 180)
	check("clients joined with a save and a plot", #list == expected, #list .. " of " .. expected)
	for _, p in list do
		local r = command(p, "ping")
		check("client " .. p.Name .. " answers", r ~= nil and r.ok == true, if r then r.ok else "timeout")
	end
end

suites.two = function()
	local list = waitPlayers(2, 180)
	check("two clients joined with a save and a plot", #list == 2, #list)
	if #list < 2 then
		return
	end
	local A, B = list[1], list[2]
	-- 1. different plots, owner names
	local plotA, plotB = plotOf(A), plotOf(B)
	check(
		"1 different plots",
		plotA ~= nil and plotB ~= nil and plotA ~= plotB,
		string.format("%s / %s", tostring(plotA), tostring(plotB))
	)
	check(
		"1 nameplates name each owner",
		plotA ~= nil
			and plotB ~= nil
			and plotA:GetAttribute("OwnerDisplayName") == A.DisplayName
			and plotB:GetAttribute("OwnerDisplayName") == B.DisplayName,
		string.format(
			"%s=%s, %s=%s",
			tostring(plotA and plotA:GetAttribute("OwnerDisplayName")),
			A.DisplayName,
			tostring(plotB and plotB:GetAttribute("OwnerDisplayName")),
			B.DisplayName
		)
	)
	table.insert(
		notes,
		"spawn: both players spawn on the plaza in front of the fountain (Adam's decision 2026-11-02), not at a gate"
	)
	-- 2. A parks a car through the real remote; B (no Lineup, so no income of its own) stands at A's track
	giveCars(A, { "Putter", "Minnow" }, { "Putter" })
	giveCars(B, { "Putter" }, {})
	command(A, "setSlot", { slot = 2, car = "Minnow" })
	local parked = waitFor(5, function()
		return A:GetAttribute(BetaConfig.LineupAttribute) == "Putter,Minnow"
	end)
	check("2 A parks Minnow through SetLineupSlot", parked, tostring(A:GetAttribute(BetaConfig.LineupAttribute)))
	command(B, "goPlot", A:GetAttribute(BetaConfig.HomePlotAttribute))
	local bCash0 = BetaData.get(B) and (BetaData.get(B) :: any).Cash
	command(B, "resetSeen")
	task.wait(17) -- more than one lap: every slot crosses once
	local seen = command(B, "report", A:GetAttribute(BetaConfig.HomePlotAttribute))
	check(
		"2 B sees A's two cars driving",
		seen ~= nil and seen.carsOnPlot == 2,
		if seen then seen.carsOnPlot else "no report"
	)
	check(
		"2 B gets A's Lap Pay pops (world), without A's newCash",
		seen ~= nil and seen.pops > 0 and seen.popsWithCash == 0,
		if seen then string.format("pops %d, with newCash %d", seen.pops, seen.popsWithCash) else "no report"
	)
	local bCash1 = BetaData.get(B) and (BetaData.get(B) :: any).Cash
	check(
		"2 B's own Cash does not change from A's laps",
		bCash0 == bCash1,
		string.format("%s -> %s", tostring(bCash0), tostring(bCash1))
	)
	-- 3. B tries to change A's Lineup: extra and malformed arguments naming A's plot and UserId
	local aBefore = A:GetAttribute(BetaConfig.LineupAttribute)
	local bBefore = B:GetAttribute(BetaConfig.LineupAttribute)
	command(B, "forge", { plot = A:GetAttribute(BetaConfig.HomePlotAttribute), userId = A.UserId })
	task.wait(1.5)
	check(
		"3 B's forged requests leave A's Lineup alone",
		A:GetAttribute(BetaConfig.LineupAttribute) == aBefore,
		string.format(
			"A %s -> %s, B %s -> %s",
			tostring(aBefore),
			tostring(A:GetAttribute(BetaConfig.LineupAttribute)),
			tostring(bBefore),
			tostring(B:GetAttribute(BetaConfig.LineupAttribute))
		)
	)
	-- 4. both run at once, in different Worlds
	local dataB = BetaData.get(B) :: BetaData.Data
	dataB.WorldsUnlocked.DustyHighway = true
	BetaEconomy.publishWorlds(B, dataB)
	local carsA0 = BetaConfig.encodeCars((BetaData.get(A) :: BetaData.Data).Cars)
	local carsB0 = BetaConfig.encodeCars(dataB.Cars)
	task.spawn(command, A, "run", "Downtown", 60)
	task.spawn(command, B, "run", "DustyHighway", 60)
	task.wait(30)
	local stA = command(A, "state")
	local stB = command(B, "state")
	check(
		"4 both runs started on the server",
		stA ~= nil and stB ~= nil and stA.runId ~= nil and stB.runId ~= nil and stA.runId ~= stB.runId,
		string.format("%s / %s", tostring(stA and stA.runId), tostring(stB and stB.runId))
	)
	check(
		"4 each HUD shows its own distance and the server's Cash",
		stA ~= nil
			and stB ~= nil
			and stA.hudCash ~= nil
			and stA.hudCash == Format.cash(stA.cash or -1)
			and stB.hudCash == Format.cash(stB.cash or -1)
			and stA.metres ~= stB.metres,
		string.format(
			"A hud %s (own Cash %s, save %s), B hud %s (own Cash %s, save %s), metres %s / %s",
			tostring(stA and stA.hudCash),
			tostring(stA and stA.cash),
			tostring((BetaData.get(A) :: any).Cash),
			tostring(stB and stB.hudCash),
			tostring(stB and stB.cash),
			tostring((BetaData.get(B) :: any).Cash),
			tostring(stA and stA.metres),
			tostring(stB and stB.metres)
		)
	)
	local carsA1 = BetaConfig.encodeCars((BetaData.get(A) :: BetaData.Data).Cars)
	local carsB1 = BetaConfig.encodeCars((BetaData.get(B) :: BetaData.Data).Cars)
	-- every car new to a save must be one of that player's OWN claims this run (from the server's grants to that client)
	local function onlyOwn(before: string, after: string, st: any): boolean
		local own = {}
		for _, c in (st and st.tally and st.tally.cars) or {} do
			own[c.carId] = true
		end
		local b = BetaConfig.decodeCars(before)
		for id in BetaConfig.decodeCars(after) do
			if not b[id] and not own[id] then
				return false
			end
		end
		return true
	end
	check(
		"4 a claim by A never lands in B's Garage (and the other way)",
		onlyOwn(carsA0, carsA1, stA) and onlyOwn(carsB0, carsB1, stB),
		string.format("A %s -> %s | B %s -> %s", carsA0, carsA1, carsB0, carsB1)
	)
	-- 7. A's private toast and newCash stay A's
	local aSeen = command(A, "report", A:GetAttribute(BetaConfig.HomePlotAttribute))
	check(
		"7 A's own payouts carry newCash to A only",
		aSeen ~= nil and aSeen.popsWithCash > 0,
		if aSeen then string.format("A pops %d with newCash %d", aSeen.pops, aSeen.popsWithCash) else "no report"
	)
	-- 5. B leaves mid-run
	local plotIndexB = B:GetAttribute(BetaConfig.HomePlotAttribute)
	local aCash0 = (BetaData.get(A) :: any).Cash
	local errorsBefore = #errors
	command(B, "leave", nil, 3)
	local freedAt = os.clock()
	local freed = waitFor(10, function()
		return plotB ~= nil and plotB:GetAttribute("Owner") == nil
	end)
	check("5 B's plot is freed after B leaves", freed, string.format("%.1f s", os.clock() - freedAt))
	task.wait(16)
	local aCash1 = BetaData.get(A) and (BetaData.get(A) :: any).Cash
	check(
		"5 A's Lap Pay continues after B leaves",
		aCash1 ~= nil and aCash1 > aCash0,
		string.format("%s -> %s", tostring(aCash0), tostring(aCash1))
	)
	check("5 no server error when B left", #errors == errorsBefore, #errors - errorsBefore)
	-- 6. a new player takes the freed plot
	StudioTestService:AddPlayers(1)
	local C: Player? = nil
	waitFor(60, function()
		for _, p in Players:GetPlayers() do
			if p ~= A and ready(p) then
				C = p
				return true
			end
		end
		return false
	end)
	check(
		"6 the added player gets the freed plot",
		C ~= nil and C:GetAttribute(BetaConfig.HomePlotAttribute) == plotIndexB and plotOf(C) ~= plotOf(A),
		string.format(
			"C %s plot %s, freed %s",
			tostring(C and C.Name),
			tostring(C and C:GetAttribute(BetaConfig.HomePlotAttribute)),
			tostring(plotIndexB)
		)
	)
end

suites.rejoin = function()
	local list = waitPlayers(1, 180)
	check("one client joined", #list >= 1, #list)
	if #list < 1 then
		return
	end
	local A = list[1]
	local key = BetaData.keyOf(A)
	-- E-03 (Round 6): REMOVE through the real remote leaves the spot empty, and it stays empty after the rejoin
	giveCars(A, { "Putter", "Minnow" }, { "Putter", "Minnow" })
	command(A, "setSlot", { slot = 2 })
	local removed = waitFor(5, function()
		return A:GetAttribute(BetaConfig.LineupAttribute) == "Putter"
	end)
	check("E-03 REMOVE empties the spot (no refill)", removed, tostring(A:GetAttribute(BetaConfig.LineupAttribute)))
	local launched = command(A, "run", "Downtown", 60)
	check("A's run launched", launched ~= nil and launched.ok == true, if launched then launched.phase else "no answer")
	-- the run until it has paid something, then the leave (mid-run)
	local paid = waitFor(110, function()
		local st = command(A, "state", nil, 3)
		return st ~= nil and st.tally ~= nil and (st.tally.total or 0) > 0
	end)
	local data = BetaData.get(A) :: BetaData.Data
	local snapshot = {
		cash = data.Cash,
		cars = BetaConfig.encodeCars(data.Cars),
		lineup = table.concat(data.Lineup, ","),
	}
	check(
		"A was paid during the run before leaving",
		paid,
		string.format("Cash %d, cars %s", snapshot.cash, snapshot.cars)
	)
	local userA = A.UserId
	BetaData.setNextJoinKey(key)
	command(A, "leave", nil, 3)
	local released = BetaData.waitReleased(key, 15)
	check("A's profile is released after the leave", released, key)
	StudioTestService:AddPlayers(1)
	local C: Player? = nil
	waitFor(60, function()
		for _, p in Players:GetPlayers() do
			if ready(p) then
				C = p
				return true
			end
		end
		return false
	end)
	if not C then
		check("the replacement client joined", false, "timeout")
		return
	end
	local c = C :: Player
	table.insert(
		notes,
		string.format(
			"synthetic same-profile rejoin: UserId %d left, UserId %d joined on mock key %s",
			userA,
			c.UserId,
			key
		)
	)
	local d2 = BetaData.get(c) :: BetaData.Data
	check(
		"the reloaded save holds the Cash granted before the leave",
		d2.Cash >= snapshot.cash,
		string.format("%d >= %d", d2.Cash, snapshot.cash)
	)
	check(
		"the reloaded save holds the cars",
		BetaConfig.encodeCars(d2.Cars) == snapshot.cars,
		BetaConfig.encodeCars(d2.Cars)
	)
	check(
		"the Lineup is rebuilt on the new plot",
		c:GetAttribute(BetaConfig.LineupAttribute) == snapshot.lineup and plotOf(c) ~= nil,
		string.format("%s on %s", tostring(c:GetAttribute(BetaConfig.LineupAttribute)), tostring(plotOf(c)))
	)
	check(
		"E-03 the removed car is still out of the Lineup after the rejoin",
		table.find(d2.Lineup, "Minnow") == nil and d2.Cars.Minnow ~= nil,
		table.concat(d2.Lineup, ",")
	)
	check("LastSeen is stamped", d2.LastSeen > 0 and os.time() - d2.LastSeen < 120, d2.LastSeen)
	check(
		"no Welcome back pay for an absence under 60 s",
		c:GetAttribute(BetaConfig.WelcomeAmountAttribute) == 0,
		tostring(c:GetAttribute(BetaConfig.WelcomeAmountAttribute))
	)
	local schedulers = 0
	for _, p in Players:GetPlayers() do
		if p.UserId == userA then
			schedulers += 1
		end
	end
	check("no scheduler or player left over from the old client", schedulers == 0, schedulers)
end

suites.six = function()
	local list = waitPlayers(6, 120)
	check("six clients joined, each with a plot", #list == 6, #list)
	local plots = {}
	for _, p in list do
		plots[p:GetAttribute(BetaConfig.HomePlotAttribute) :: number] = true
		p:SetAttribute(BetaConfig.GrantCashAttribute, 1000)
		giveCars(p, { "Putter", "Minnow" }, { "Putter", "Minnow" })
	end
	local distinct = 0
	for _ in plots do
		distinct += 1
	end
	check("all six plots taken, no two players on one", distinct == #list, distinct)
	-- the cost of the one Lap Pay scheduler with 12 cars on 6 plots, and the server's frame time, over 20 s
	local ticks, worst, sum = 0, 0, 0
	local frames, frameSum, frameWorst = 0, 0, 0
	local conn = RunService.Heartbeat:Connect(function(dt: number)
		frames += 1
		frameSum += dt
		frameWorst = math.max(frameWorst, dt)
		local t = BetaLapPay.lastTickSeconds
		ticks += 1
		sum += t
		worst = math.max(worst, t)
	end)
	task.wait(20)
	conn:Disconnect()
	table.insert(
		notes,
		string.format(
			"server over 20 s: %d frames, mean %.1f ms, worst %.1f ms; Lap Pay pass mean %.3f ms, worst %.3f ms (12 cars, 6 plots)",
			frames,
			frameSum / math.max(frames, 1) * 1000,
			frameWorst * 1000,
			sum / math.max(ticks, 1) * 1000,
			worst * 1000
		)
	)
	check("the Lap Pay scheduler stays under 1 ms a pass", worst < 0.001, string.format("%.3f ms", worst * 1000))
	-- a seventh player
	StudioTestService:AddPlayers(1)
	local seventh: Player? = nil
	waitFor(60, function()
		for _, p in Players:GetPlayers() do
			if p:GetAttribute("BetaNoPlot") == true then
				seventh = p
				return true
			end
		end
		return false
	end)
	check(
		"a seventh player gets no plot and is told so (Max Players is 6)",
		seventh ~= nil,
		if seventh then seventh.Name .. " BetaNoPlot" else "no seventh player seen"
	)
	table.insert(notes, "active clients at the end: " .. #Players:GetPlayers())
end

-- E-06 (Round 6): Round 5's unwalked loop, walked by one client through the real stand-ins and the real run. Cash is only
-- topped up with the Studio cheat BetaGrantCash, and each top-up is listed in the notes. Started as suite "smoke" with the
-- Workspace attribute CatchACarMultiTestVariant = "loop", because the installed plugin only knows its four suite names
-- until Studio restarts with the updated copy in Car-Hop-Art\tools.
suites.loop = function()
	local list = waitPlayers(1, 180)
	check("one client joined", #list >= 1, #list)
	if #list < 1 then
		return
	end
	local A = list[1]
	local data = BetaData.get(A) :: BetaData.Data
	data.TutorialDone = true
	A:SetAttribute(BetaConfig.TutorialDoneAttribute, true)
	local function topUp(missing: number?, why: string)
		if type(missing) == "number" and missing > 0 then
			A:SetAttribute(BetaConfig.GrantCashAttribute, missing)
			waitFor(3, function()
				return (BetaData.get(A) :: BetaData.Data).Cash >= missing
			end)
			table.insert(notes, string.format("BetaGrantCash +$%s to skip waiting for %s", Format.group(missing), why))
		end
	end
	-- 1. a Raceway level
	local level = data.RacewayLevel
	local ok, _, missing = BetaShop.buyRacewayLevel(A)
	if not ok then
		topUp(missing, "Raceway level " .. (level + 1))
		task.wait(1.2) -- the shop's cooldown
		ok = BetaShop.buyRacewayLevel(A)
	end
	check("1 a Raceway level is bought", ok == true and data.RacewayLevel == level + 1, data.RacewayLevel)
	-- 2. runs in Downtown until 5 Downtown cars
	local function runOnce(world: string): boolean
		local launched = command(A, "run", world, 60)
		if not (launched and launched.ok) then
			table.insert(notes, world .. " run did not launch")
			return false
		end
		local ended = waitFor(240, function()
			local st = command(A, "state", nil, 3)
			return st ~= nil and st.mode == "Ended"
		end)
		task.wait(2)
		command(A, "home", nil, 10)
		waitFor(20, function()
			local st = command(A, "state", nil, 3)
			return st ~= nil and st.phase == "island"
		end)
		task.wait(2)
		return ended
	end
	local runs = 0
	while BetaShop.carsFrom(data, "Downtown") < 5 and runs < 8 do
		runs += 1
		runOnce("Downtown")
	end
	local earned = BetaShop.carsFrom(data, "Downtown")
	check("2 five Downtown cars caught in runs", earned >= 5, string.format("%d cars after %d runs", earned, runs))
	-- 3. unlock Dusty Highway (the real rule: 5 Downtown cars and the price)
	local unlocked, reason, short = BetaShop.unlockWorld(A, "DustyHighway")
	if not unlocked and short then
		topUp(short, "the Dusty Highway unlock")
		task.wait(1.2)
		unlocked, reason = BetaShop.unlockWorld(A, "DustyHighway")
	end
	check("3 Dusty Highway is unlocked", unlocked == true, reason or "ok")
	-- 4. a run there that catches a Dusty Highway car
	local dustyRuns = 0
	while BetaShop.carsFrom(data, "DustyHighway") < 1 and dustyRuns < 4 and unlocked do
		dustyRuns += 1
		runOnce("DustyHighway")
	end
	local dustyCar: string? = nil
	for id in data.Cars do
		local car = RosterFixtures.byId(id)
		if car and car.world == "DustyHighway" then
			dustyCar = id
		end
	end
	check(
		"4 a Dusty Highway car is caught",
		dustyCar ~= nil,
		string.format("%s after %d runs", tostring(dustyCar), dustyRuns)
	)
	-- 5. it pays with the World factor
	if dustyCar then
		local car = RosterFixtures.byId(dustyCar) :: any
		local entry = data.Cars[dustyCar]
		local pay = BetaEconomy.lapPayOf(data, dustyCar)
		local want = EconomyPreview.lapPay(car.rarity, entry.Edition, data.RacewayLevel, "DustyHighway")
		local home = EconomyPreview.lapPay(car.rarity, entry.Edition, data.RacewayLevel, "Downtown")
		check(
			"5 the Dusty Highway car pays its World factor (x40)",
			pay == want and pay >= home * 39,
			string.format("%s %s: $%d a lap (the same car in Downtown: $%d)", dustyCar, car.rarity, pay, home)
		)
		table.insert(notes, "Lineup at the end: " .. table.concat(data.Lineup, ","))
	end
end

if suite == "smoke" and workspace:GetAttribute("CatchACarMultiTestVariant") == "loop" then
	suite = "loop"
end

task.spawn(function()
	local run = suites[suite]
	if not run then
		check("known suite", false, suite)
	else
		local ok, err = pcall(run)
		if not ok then
			check("suite ran to the end", false, err)
		end
	end
	finish()
end)
