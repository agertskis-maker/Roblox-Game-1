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
-- Round 7 (U-05): forty-five missions in five tabs. New saved facts come from the save's rarities (RosterFixtures), the Stamina
-- level, the Style Shop's Owned and Equipped; new counted facts (hops, the longest hop chain, the longest bump-free run) come
-- from the runEnded event.
-- Missions never use a timer, a streak or a deadline. State is published read-only as the Player attribute BetaMissions,
-- "id=status:progress" joined by ";" (status: before | active | ready | claimed). The claim remote is ClaimMission (id).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BetaConfig = require(ReplicatedStorage.Shared.Beta.BetaConfig)
local BetaData = require(script.Parent.BetaData)
local BetaEconomy = require(script.Parent.BetaEconomy)
local BetaEvents = require(script.Parent.BetaEvents)
local Catalog = require(ReplicatedStorage.Shared.UI.CosmeticPreviewCatalog)
local MissionsPreview = require(ReplicatedStorage.Shared.UI.MissionsPreview)
local RosterFixtures = require(ReplicatedStorage.Shared.UI.RosterFixtures)

local BetaMissions = {}

BetaMissions.Attribute = "BetaMissions"
BetaMissions.ClaimRemote = "ClaimMission"

type Counters = {
	lapCash: number,
	joyrides: number,
	runs: number,
	bestMetres: number,
	hops: number,
	bestChain: number,
	bumpFreeMetres: number,
}
type PlayerState = { counters: Counters, status: { [string]: string }, lastClaim: number }

local states: { [Player]: PlayerState } = {}

local RANK: { [string]: number } = { Common = 1, Uncommon = 2, Rare = 3, Epic = 4, Legendary = 5 }
local styleItems: { [string]: Catalog.Item } = {}
for _, tab in Catalog.Tabs do
	for _, item in Catalog.Items[tab] do
		styleItems[item.id] = item
	end
end
local STYLE_FACT: { [string]: string } = { Paint = "paints", Decals = "decals", Wheels = "wheels", Trails = "trails" }

local function newCounters(): Counters
	return { lapCash = 0, joyrides = 0, runs = 0, bestMetres = 0, hops = 0, bestChain = 0, bumpFreeMetres = 0 }
end
local resultRemote: RemoteEvent? = nil

-- The facts a mission reads, from a save and this visit's counters (pure).
function BetaMissions.factsOf(data: any, counters: Counters): MissionsPreview.Facts
	local cars, carsIn, best = 0, {}, 1
	local rare, epic, legendary = 0, 0, 0
	for id, car in data.Cars do
		cars += 1
		local info = RosterFixtures.byId(id)
		if info then
			carsIn[info.world] = (carsIn[info.world] or 0) + 1
			local rank = RANK[info.rarity] or 1
			rare += if rank >= 3 then 1 else 0
			epic += if rank >= 4 then 1 else 0
			legendary += if rank >= 5 then 1 else 0
		end
		best = math.max(best, car.Edition)
	end
	-- a World counts once a car other than the Loaner was caught there
	local worldsWithCars = 0
	for world, n in carsIn do
		local loaner = RosterFixtures.loaner(world :: any)
		local caught = n - (if loaner and data.Cars[loaner.id] then 1 else 0)
		worldsWithCars += if caught > 0 then 1 else 0
	end
	local lineupRare = if #data.Lineup >= 3 then 1 else 0
	for _, id in data.Lineup do
		local info = RosterFixtures.byId(id)
		if not (info and (RANK[info.rarity] or 1) >= 3) then
			lineupRare = 0
		end
	end
	local style = { paints = 0, decals = 0, wheels = 0, trails = 0 }
	local bought, legendaryPaint = 0, 0
	for id, yes in data.Owned or {} do
		local item = styleItems[id]
		if yes and item and not item.isNone then
			bought += 1
			style[STYLE_FACT[item.tab]] += 1
			legendaryPaint = if item.tab == "Paint" and item.tier == "legendary" then 1 else legendaryPaint
		end
	end
	local defaults = BetaConfig.Template.Equipped :: any
	local fullLook = 1
	for _, tab in Catalog.Tabs do
		local worn = data.Equipped and data.Equipped[tab]
		local item = worn and styleItems[worn]
		if not item or item.isNone or worn == defaults[tab] then
			fullLook = 0
		end
	end
	return {
		cars = cars,
		parked = #data.Lineup,
		racewayLevel = data.RacewayLevel,
		spots = data.ParkingSpots,
		worlds = data.WorldsUnlocked,
		carsIn = carsIn,
		bestEdition = best,
		rare = rare,
		epic = epic,
		legendary = legendary,
		worldsWithCars = worldsWithCars,
		lineupRare = lineupRare,
		staminaLevel = data.StaminaLevel or 0,
		styleBought = bought,
		paints = style.paints,
		decals = style.decals,
		wheels = style.wheels,
		trails = style.trails,
		legendaryPaint = legendaryPaint,
		fullLook = fullLook,
		lapCash = counters.lapCash,
		joyrides = counters.joyrides,
		runs = counters.runs,
		bestMetres = counters.bestMetres,
		hops = counters.hops,
		bestChain = counters.bestChain,
		bumpFreeMetres = counters.bumpFreeMetres,
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
		counters = newCounters(),
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

-- Studio self-tests only: starts the player's missions again from the save as it is now (the tests touch it for a moment).
function BetaMissions.restart(player: Player)
	local data = BetaData.get(player)
	if data then
		begin(player, data)
	end
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
				if info.bumps == 0 then
					c.bumpFreeMetres = math.max(c.bumpFreeMetres, info.metres)
				end
			end
			if type(info.hops) == "number" then
				c.hops += info.hops
			end
			if type(info.bestChain) == "number" then
				c.bestChain = math.max(c.bestChain, info.bestChain)
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
	-- U-05: a run with hops and no bumps feeds the Racer missions
	state.counters = newCounters()
	BetaEvents.fire(player, "runEnded", { metres = 1200, bumps = 0, hops = 4, bestChain = 3 })
	expect("U-05 hops are counted from a run", state.counters.hops, 4)
	expect(
		"U-05 a chain of 3 makes Hop 3 cars ready",
		state.status["chain-3"] == "ready" or state.status["chain-3"] == "claimed",
		true
	)
	expect("U-05 a 1,200 m run with no bumps counts as bump-free", state.counters.bumpFreeMetres, 1200)
	BetaEvents.fire(player, "runEnded", { metres = 3000, bumps = 2, hops = 0, bestChain = 0 })
	expect("U-05 a run with bumps is not bump-free", state.counters.bumpFreeMetres, 1200)
	local look = BetaMissions.factsOf({
		Cars = {},
		Lineup = {},
		RacewayLevel = 1,
		ParkingSpots = 2,
		WorldsUnlocked = {},
		Owned = { galaxy_swirl = true, pit_white = true },
		Equipped = { Paint = "pit_white", Decals = "none", Wheels = "stock_five", Trails = "no_trail" },
	}, newCounters())
	expect("U-05 two bought paints count", look.paints, 2)
	expect("U-05 a Legendary paint counts", look.legendaryPaint, 1)
	expect("U-05 a paint alone is not a full look", look.fullLook, 0)
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
