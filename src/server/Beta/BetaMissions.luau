--!strict
-- BETA-ONLY STAND-IN for Brian L's Missions server (the M18 seam in MissionFixtures, decision 0031).
-- Same contract: the server counts progress from real events, decides when a mission is done, and pays the reward on the
-- player's claim; the client only asks to claim. Delete when his real module lands.
--
-- Round 6 (G-01, G-02). The missions are src/shared/UI/MissionsPreview (Lane 3, PREVIEW rewards). Progress reads the agreed
-- save fields (cars, Lineup, Raceway level, spots, Worlds, editions) plus counters kept for this visit only (Lap Pay
-- earned, Joyrides, runs, the longest run), fed by BetaEvents, the server's own event feed. No save field is added, so:
--   * a SAVED mission already done when the player joins shows as done, with nothing to claim (no reward twice by rejoining);
--   * a COUNTED mission starts again at 0 on a rejoin (a visit's Joyrides are not saved);
--   * a mission finished but not claimed when the player leaves is paid then, into the save: nothing is lost for stopping.
-- Missions never use a timer, a streak or a deadline. State is published read-only as the Player attribute BetaMissions,
-- "id=status:progress" joined by ";" (status: before | active | ready | claimed). The claim remote is ClaimMission (id).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BetaConfig = require(ReplicatedStorage.Shared.Beta.BetaConfig)
local BetaData = require(script.Parent.BetaData)
local BetaEconomy = require(script.Parent.BetaEconomy)
local BetaEvents = require(script.Parent.BetaEvents)
local MissionsPreview = require(ReplicatedStorage.Shared.UI.MissionsPreview)
local RosterFixtures = require(ReplicatedStorage.Shared.UI.RosterFixtures)

local BetaMissions = {}

BetaMissions.Attribute = "BetaMissions"
BetaMissions.ClaimRemote = "ClaimMission"

type Counters = { lapCash: number, joyrides: number, runs: number, bestMetres: number }
type PlayerState = { counters: Counters, status: { [string]: string }, lastClaim: number }

local states: { [Player]: PlayerState } = {}
local resultRemote: RemoteEvent? = nil

-- The facts a mission reads, from a save and this visit's counters (pure).
function BetaMissions.factsOf(data: any, counters: Counters): MissionsPreview.Facts
	local cars, carsIn, best = 0, {}, 1
	for id, car in data.Cars do
		cars += 1
		local info = RosterFixtures.byId(id)
		if info then
			carsIn[info.world] = (carsIn[info.world] or 0) + 1
		end
		best = math.max(best, car.Edition)
	end
	return {
		cars = cars,
		parked = #data.Lineup,
		racewayLevel = data.RacewayLevel,
		spots = data.ParkingSpots,
		worlds = data.WorldsUnlocked,
		carsIn = carsIn,
		bestEdition = best,
		lapCash = counters.lapCash,
		joyrides = counters.joyrides,
		runs = counters.runs,
		bestMetres = counters.bestMetres,
	}
end

local function publish(player: Player, state: PlayerState, facts: MissionsPreview.Facts)
	local parts = {}
	for _, mission in MissionsPreview.List do
		table.insert(
			parts,
			string.format("%s=%s:%d", mission.id, state.status[mission.id], MissionsPreview.progress(mission, facts))
		)
	end
	player:SetAttribute(BetaMissions.Attribute, table.concat(parts, ";"))
end

-- Moves active missions whose target is met to ready, then publishes.
function BetaMissions.refresh(player: Player)
	local state = states[player]
	local data = BetaData.get(player)
	if not (state and data) then
		return
	end
	local facts = BetaMissions.factsOf(data, state.counters)
	for _, mission in MissionsPreview.List do
		if state.status[mission.id] == "active" and MissionsPreview.progress(mission, facts) >= mission.target then
			state.status[mission.id] = "ready"
		end
	end
	publish(player, state, facts)
end

local function begin(player: Player, data: any)
	local state: PlayerState = {
		counters = { lapCash = 0, joyrides = 0, runs = 0, bestMetres = 0 },
		status = {},
		lastClaim = 0,
	}
	local facts = BetaMissions.factsOf(data, state.counters)
	for _, mission in MissionsPreview.List do
		local done = MissionsPreview.saved(mission) and MissionsPreview.progress(mission, facts) >= mission.target
		state.status[mission.id] = if done then "before" else "active"
	end
	states[player] = state
	publish(player, state, facts)
end

-- The claim, apart from the remote so the self-test can call it. Returns ok and the reason.
function BetaMissions.claim(player: Player, id: any): (boolean, string?)
	local state = states[player]
	if not state then
		return false, "Your save is still loading."
	end
	if type(id) ~= "string" or #id > 40 then
		return false, "That mission isn't known."
	end
	local mission = MissionsPreview.get(id)
	if not mission then
		return false, "That mission isn't known."
	end
	local now = os.clock()
	if now - state.lastClaim < 0.3 then
		return false, "One moment, try again."
	end
	state.lastClaim = now
	BetaMissions.refresh(player)
	if state.status[id] ~= "ready" then
		return false, if state.status[id] == "claimed" then "Already claimed." else "Not finished yet."
	end
	state.status[id] = "claimed" -- before paying, so a second request can never pay twice
	BetaEconomy.addCash(player, mission.reward, "Mission " .. id)
	BetaMissions.refresh(player)
	return true, nil
end

function BetaMissions.start(net: Folder)
	local remote = Instance.new("RemoteEvent")
	remote.Name = BetaMissions.ClaimRemote
	remote.Parent = net
	resultRemote = net:FindFirstChild(BetaConfig.Remotes.Result) :: RemoteEvent?
	remote.OnServerEvent:Connect(function(player: Player, id: any)
		local ok, reason = BetaMissions.claim(player, id)
		local result = resultRemote
		if result then
			result:FireClient(player, "ClaimMission", ok, reason, nil)
		end
	end)
	BetaData.Loaded:Connect(begin)
	BetaEvents.Fired:Connect(function(player: Player, kind: string, info: { [string]: any })
		local state = states[player]
		if not state then
			return
		end
		local c = state.counters
		if kind == "lap" and type(info.amount) == "number" then
			c.lapCash += info.amount
		elseif kind == "joyride" then
			c.joyrides += 1
		elseif kind == "runEnded" then
			c.runs += 1
			if type(info.metres) == "number" then
				c.bestMetres = math.max(c.bestMetres, info.metres)
			end
		end
		BetaMissions.refresh(player)
	end)
	-- nothing lost for stopping: a finished, unclaimed mission is paid into the save as the player leaves
	BetaData.Releasing:Connect(function(player: Player, data: any)
		local state = states[player]
		states[player] = nil
		if not state then
			return
		end
		BetaMissions.refreshData(state, data)
		for _, mission in MissionsPreview.List do
			if state.status[mission.id] == "ready" then
				local paid = BetaEconomy.capped(data.Cash, mission.reward)
				data.Cash += paid
				print(
					string.format(
						"[CarHopBeta] %s left with %s unclaimed: +$%d paid into the save",
						player.Name,
						mission.id,
						paid
					)
				)
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(player: Player)
		task.defer(function()
			states[player] = nil
		end)
	end)
end

-- The ready check on a save that is being released (BetaData.get is already empty then).
function BetaMissions.refreshData(state: PlayerState, data: any)
	local facts = BetaMissions.factsOf(data, state.counters)
	for _, mission in MissionsPreview.List do
		if state.status[mission.id] == "active" and MissionsPreview.progress(mission, facts) >= mission.target then
			state.status[mission.id] = "ready"
		end
	end
end

-- On a live test player: a claim before the target is refused, a ready one pays once, a second claim pays nothing, and a
-- saved mission already done at join has nothing to claim. Puts Cash back afterwards.
function BetaMissions.selfTest(player: Player): { string }
	local lines: { string } = {}
	local function expect(name: string, got: any, want: any)
		table.insert(
			lines,
			string.format(
				"%s %s: got %s, want %s",
				if got == want then "PASS" else "FAIL",
				name,
				tostring(got),
				tostring(want)
			)
		)
	end
	local state = states[player]
	local data = BetaData.get(player) :: any
	if not (state and data) then
		return { "FAIL no mission state for " .. player.Name }
	end
	for _, line in MissionsPreview.selfTest() do
		table.insert(lines, "FAIL MissionsPreview " .. line)
	end
	local cash = data.Cash
	local saved = table.clone(state.status)
	local counters = table.clone(state.counters)
	state.status.joyride = "active"
	state.counters.joyrides = 0
	state.lastClaim = 0
	expect("an unfinished mission cannot be claimed", (BetaMissions.claim(player, "joyride")), false)
	BetaEvents.fire(player, "joyride", {})
	expect("a real Joyride event makes it ready", state.status.joyride, "ready")
	state.lastClaim = 0
	local before = data.Cash
	expect("a ready mission is claimed", (BetaMissions.claim(player, "joyride")), true)
	expect(
		"... and pays its PREVIEW reward",
		data.Cash - before,
		BetaEconomy.capped(before, (MissionsPreview.get("joyride") :: any).reward)
	)
	state.lastClaim = 0
	before = data.Cash
	expect("a second claim pays nothing", (BetaMissions.claim(player, "joyride")), false)
	expect("... nothing", data.Cash, before)
	expect("an unknown id is refused", (BetaMissions.claim(player, { "x" })), false)
	local facts = BetaMissions.factsOf(data, state.counters)
	local firstCatch = MissionsPreview.get("first-catch") :: MissionsPreview.Mission
	if MissionsPreview.progress(firstCatch, facts) >= firstCatch.target then
		expect("a saved mission done before this visit has nothing to claim", saved["first-catch"], "before")
	end
	state.status = saved
	state.counters = counters
	data.Cash = cash
	BetaEconomy.publishCash(player, data)
	BetaMissions.refresh(player)
	return lines
end

return BetaMissions
