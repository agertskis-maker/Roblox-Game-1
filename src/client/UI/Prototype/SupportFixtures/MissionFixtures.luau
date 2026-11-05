--!strict
-- PREVIEW fixtures for the Missions and Goals panel and the Home tracker (big round M13). The template list is a Lane 3
-- DISPLAY fixture (BRIEF M13-03). Progress, reward amounts, claim results and the daily refresh are Brian L's: every
-- number here is made up, every reward is labelled "PREVIEW reward" where it shows, and nothing is ever granted.
--
-- THE SEAM FOR BRIAN L (the M18 message asks for this shape):
--   load             "Loading" | "Ready" | "Error"
--   missions[]       up to fifteen active: { id, text, sub?, icon, target, progress?, format, reward, claim }
--                    progress nil = unknown (shown as "Checking...", never 0); claim = the server's claim state
--   goals[]          the one-time milestones: { id, text, icon, done, progress?, target?, reward? }; a goal never un-completes
--   claim            a claim request goes out through options.onClaim(id); the answer comes back through
--                    panel:resolveClaim(id, "Success" | "Error"); the reward, the replacement mission and the daily
--                    refresh are the server's (the preview replaces a claimed card once, and refreshes only on an
--                    explicit fixture switch, never on a timer)

local MissionFixtures = {}

MissionFixtures.Source = "PREVIEW fixture: missions, rewards, progress and refresh come from the game (Brian L)"

export type ClaimState = "None" | "Pending" | "Claimed" | "Error"
export type Format = "count" | "cash"
-- What the reward is. nil means Cash, the amount in `reward`. A cosmetic reward (the preview shows its art and its word, not
-- an amount) keeps a `reward` number only so every template carries one; the screen does not show it.
export type RewardKind = "Cash" | "Paint" | "Decal" | "Wheel" | "Trail"
-- How hard a mission is. The harder it is, the more it pays (Adam, 2026-11-02); the amounts are PREVIEW proposals for Brian L.
export type Tier = "Easy" | "Medium" | "Hard" | "Expert" | "Legend"

export type Mission = {
	id: string,
	text: string,
	sub: string?,
	icon: string,
	target: number,
	progress: number?, -- nil = unknown
	format: Format,
	reward: number, -- PREVIEW dollars
	rewardKind: RewardKind?, -- PREVIEW: nil = Cash
	claim: ClaimState,
}

type Template = {
	id: string,
	text: string,
	sub: string,
	icon: string,
	target: number,
	format: Format,
	reward: number,
	rewardKind: RewardKind?,
	tier: Tier,
}

export type Goal = {
	id: string,
	text: string,
	icon: string,
	done: boolean,
	progress: number?,
	target: number?,
	reward: number?, -- PREVIEW dollars
}

export type Load = "Loading" | "Ready" | "Error"

export type State = {
	source: string,
	load: Load,
	missions: { Mission },
	goals: { Goal },
	pool: { Mission }, -- the fixture replacements, used in order (cycling), one per claimed card
}

-- The display templates (BRIEF section M13, the outline's examples), scaled to the player's current World in the real
-- game. Reward amounts are PREVIEW values.
MissionFixtures.Templates = table.freeze({
	{
		id = "hop15",
		text = "Hop 15 times",
		sub = "Across your runs",
		icon = "HopCar",
		target = 15,
		format = "count",
		reward = 250,
		tier = "Easy",
	},
	{
		id = "rare1",
		text = "Claim a Rare car",
		sub = "From any World",
		icon = "Car",
		target = 1,
		format = "count",
		reward = 500,
		rewardKind = "Paint",
		tier = "Medium",
	},
	{
		id = "reach1000",
		text = "Reach 1,000 m",
		sub = "Dusty Highway",
		icon = "Track",
		target = 1000,
		format = "count",
		reward = 400,
		rewardKind = "Decal",
		tier = "Medium",
	},
	{
		id = "lappay500",
		text = "Earn $500 from Lap Pay",
		sub = "On your Raceway",
		icon = "Coin",
		target = 500,
		format = "cash",
		reward = 300,
		tier = "Easy",
	},
	{
		id = "stuntvan",
		text = "Finish the Stunt Circuit",
		sub = "In a Van",
		icon = "Flag",
		target = 1,
		format = "count",
		reward = 600,
		rewardKind = "Wheel",
		tier = "Medium",
	},
	{
		id = "hop30",
		text = "Hop 30 times",
		sub = "Across your runs",
		icon = "HopCar",
		target = 30,
		format = "count",
		reward = 450,
		rewardKind = "Trail",
		tier = "Medium",
	},
	{
		id = "hop5",
		text = "Hop 5 times",
		sub = "In one run",
		icon = "HopCar",
		target = 5,
		format = "count",
		reward = 150,
		tier = "Easy",
	},
	{
		id = "drive300",
		text = "Drive 300 m",
		sub = "In one run",
		icon = "Track",
		target = 300,
		format = "count",
		reward = 200,
		tier = "Easy",
	},
	{
		id = "runs3",
		text = "Play 3 runs",
		sub = "In any World",
		icon = "Flag",
		target = 3,
		format = "count",
		reward = 250,
		tier = "Easy",
	},
	{
		id = "keys1",
		text = "Fill your Keys once",
		sub = "In any run",
		icon = "Keys",
		target = 1,
		format = "count",
		reward = 300,
		tier = "Easy",
	},
	{
		id = "drive800",
		text = "Drive 800 m",
		sub = "In one run",
		icon = "Track",
		target = 800,
		format = "count",
		reward = 750,
		tier = "Medium",
	},
	{
		id = "hop10",
		text = "Use all 10 bolts",
		sub = "In one run",
		icon = "HopCar",
		target = 10,
		format = "count",
		reward = 1000,
		tier = "Medium",
	},
	{
		id = "runs10",
		text = "Play 10 runs",
		sub = "In any World",
		icon = "Flag",
		target = 10,
		format = "count",
		reward = 1000,
		tier = "Medium",
	},
	{
		id = "lappay2000",
		text = "Earn $2,000 from Lap Pay",
		sub = "On your Raceway",
		icon = "Coin",
		target = 2000,
		format = "cash",
		reward = 1200,
		tier = "Medium",
	},
	{
		id = "keys5",
		text = "Fill your Keys 5 times",
		sub = "Across your runs",
		icon = "Keys",
		target = 5,
		format = "count",
		reward = 1500,
		tier = "Medium",
	},
	{
		id = "drive2000",
		text = "Drive 2,000 m",
		sub = "In one run",
		icon = "Track",
		target = 2000,
		format = "count",
		reward = 3000,
		tier = "Hard",
	},
	{
		id = "total10k",
		text = "Drive 10,000 m",
		sub = "Across your runs",
		icon = "Track",
		target = 10000,
		format = "count",
		reward = 4000,
		tier = "Hard",
	},
	{
		id = "hop100",
		text = "Hop 100 times",
		sub = "Across your runs",
		icon = "HopCar",
		target = 100,
		format = "count",
		reward = 5000,
		tier = "Hard",
	},
	{
		id = "lappay25k",
		text = "Earn $25,000 from Lap Pay",
		sub = "On your Raceway",
		icon = "Coin",
		target = 25000,
		format = "cash",
		reward = 5000,
		tier = "Hard",
	},
	{
		id = "epic1",
		text = "Claim an Epic car",
		sub = "From any World",
		icon = "Car",
		target = 1,
		format = "count",
		reward = 6000,
		tier = "Hard",
	},
	{
		id = "summit3000",
		text = "Reach 3,000 m",
		sub = "Summit Pass",
		icon = "Track",
		target = 3000,
		format = "count",
		reward = 10000,
		tier = "Expert",
	},
	{
		id = "hop500",
		text = "Hop 500 times",
		sub = "Across your runs",
		icon = "HopCar",
		target = 500,
		format = "count",
		reward = 12000,
		tier = "Expert",
	},
	{
		id = "legendary1",
		text = "Claim a Legendary car",
		sub = "From any World",
		icon = "Car",
		target = 1,
		format = "count",
		reward = 15000,
		tier = "Expert",
	},
	{
		id = "allworlds",
		text = "Reach 1,000 m in every World",
		sub = "All 3 Worlds",
		icon = "Portal",
		target = 3,
		format = "count",
		reward = 20000,
		tier = "Expert",
	},
	{
		id = "drive5000",
		text = "Reach 5,000 m",
		sub = "Summit Pass",
		icon = "Track",
		target = 5000,
		format = "count",
		reward = 40000,
		tier = "Legend",
	},
	{
		id = "total100k",
		text = "Drive 100,000 m",
		sub = "Across your runs",
		icon = "Track",
		target = 100000,
		format = "count",
		reward = 50000,
		tier = "Legend",
	},
	{
		id = "hop2000",
		text = "Hop 2,000 times",
		sub = "Across your runs",
		icon = "HopCar",
		target = 2000,
		format = "count",
		reward = 75000,
		tier = "Legend",
	},
} :: { Template })

-- The ladder of milestones, easiest first. The first six names are the approved ones (BRIEF M13-01b); the rest and every reward
-- are Adam's 2026-11-02 extension, PREVIEW: the harder the milestone, the more it pays.
MissionFixtures.GoalNames = table.freeze({
	{ id = "own5", text = "Own 5 cars", icon = "Car", target = 5, reward = 500 },
	{ id = "raceway2", text = "Reach Raceway level 2", icon = "Track", target = 1, reward = 1000 },
	{ id = "bronze", text = "Earn a Bronze medal", icon = "Medal", target = 1, reward = 1500 },
	{ id = "firstVariant", text = "Claim your first Variant", icon = "Star", target = 1, reward = 2500 },
	{ id = "unlockDusty", text = "Unlock Dusty Highway", icon = "Portal", target = 1, reward = 4000 },
	{ id = "ownDowntown", text = "Own every Downtown car", icon = "GarageBook", target = 9, reward = 5000 },
	{ id = "own10", text = "Own 10 cars", icon = "Car", target = 10, reward = 6000 },
	{ id = "raceway3", text = "Reach Raceway level 3", icon = "Track", target = 1, reward = 7500 },
	{ id = "silver", text = "Earn a Silver medal", icon = "Medal", target = 1, reward = 8000 },
	{ id = "run2000", text = "Drive 2,000 m in one run", icon = "Track", target = 1, reward = 10000 },
	{ id = "unlockSummit", text = "Unlock Summit Pass", icon = "Portal", target = 1, reward = 12000 },
	{ id = "own25", text = "Own 25 cars", icon = "Car", target = 25, reward = 15000 },
	{ id = "raceway5", text = "Reach Raceway level 5", icon = "Track", target = 1, reward = 20000 },
	{ id = "gold", text = "Earn a Gold medal", icon = "Medal", target = 1, reward = 25000 },
	{ id = "ownDusty", text = "Own every Dusty Highway car", icon = "GarageBook", target = 9, reward = 30000 },
	{ id = "run5000", text = "Drive 5,000 m in one run", icon = "Track", target = 1, reward = 40000 },
	{ id = "firstLegendary", text = "Claim your first Legendary car", icon = "Star", target = 1, reward = 50000 },
	{ id = "own50", text = "Own 20 cars", icon = "Car", target = 20, reward = 75000 },
	{ id = "raceway10", text = "Reach Raceway level 10", icon = "Track", target = 1, reward = 100000 },
	{ id = "ownSummit", text = "Own every Summit Pass car", icon = "GarageBook", target = 9, reward = 150000 },
	{ id = "raceway12", text = "Reach Raceway level 12", icon = "Track", target = 1, reward = 200000 },
	{ id = "platinum", text = "Earn a medal in every World", icon = "Medal", target = 3, reward = 250000 },
	{ id = "own75", text = "Get a car to Diamond", icon = "Star", target = 1, reward = 300000 },
	{ id = "ownAll", text = "Own all 27 cars", icon = "GarageBook", target = 27, reward = 500000 },
})

-- The full board: three missions of each difficulty, easiest first. The other templates wait in the pool.
local BOARD: { string } = {
	"hop5",
	"drive300",
	"hop15",
	"drive800",
	"hop10",
	"lappay2000",
	"drive2000",
	"total10k",
	"hop100",
	"summit3000",
	"hop500",
	"legendary1",
	"drive5000",
	"total100k",
	"hop2000",
}
-- How far along a preview board is, by difficulty.
local BOARD_PROGRESS: { [Tier]: number } = { Easy = 0.6, Medium = 0.4, Hard = 0.2, Expert = 0.1, Legend = 0 }

local function mission(template: number, progress: number?, claim: ClaimState?): Mission
	local t = MissionFixtures.Templates[template]
	return {
		id = t.id,
		text = t.text,
		sub = t.tier .. " · " .. t.sub,
		icon = t.icon,
		target = t.target,
		progress = progress,
		format = t.format,
		reward = t.reward,
		rewardKind = t.rewardKind,
		claim = claim or "None",
	}
end

local function goals(done: number, progress: { [string]: number }?): { Goal }
	local out: { Goal } = {}
	for i, g in MissionFixtures.GoalNames do
		local target = g.target
		local p = if progress then progress[g.id] else nil
		table.insert(out, {
			id = g.id,
			text = g.text,
			icon = g.icon,
			done = i <= done,
			progress = if i <= done then target else p,
			target = target,
			reward = g.reward,
		})
	end
	return out
end

local function pool(): { Mission }
	return { mission(4, 0), mission(5, 0), mission(6, 0), mission(1, 0) }
end

local function templateIndex(id: string): number
	for i, t in MissionFixtures.Templates do
		if t.id == id then
			return i
		end
	end
	error("no mission template " .. id)
end

local function boardMissions(): { Mission }
	local out: { Mission } = {}
	for _, id in BOARD do
		local i = templateIndex(id)
		local t = MissionFixtures.Templates[i]
		table.insert(out, mission(i, math.floor(t.target * BOARD_PROGRESS[t.tier])))
	end
	out[1].progress = out[1].target -- one is always ready to claim on the preview board
	return out
end

-- The templates not on the board, in order: what a claimed mission is replaced with.
local function boardPool(): { Mission }
	local out: { Mission } = {}
	for i, t in MissionFixtures.Templates do
		if not table.find(BOARD, t.id) then
			table.insert(out, mission(i, 0))
		end
	end
	return out
end

local function state(load: Load, missions: { Mission }, goalList: { Goal }): State
	return { source = MissionFixtures.Source, load = load, missions = missions, goals = goalList, pool = pool() }
end

local presets: { [string]: () -> State } = {
	-- what a player sees: the full ladder, easy to Legend, and the milestones
	Board = function(): State
		local board =
			state("Ready", boardMissions(), goals(0, { own5 = 3, ownDowntown = 4, own10 = 3, own25 = 3, own50 = 3 }))
		board.pool = boardPool()
		return board
	end,
	-- the three starting examples of BRIEF M13-01a: 8 / 15, 0 / 1, 620 / 1,000
	InProgress3 = function(): State
		return state(
			"Ready",
			{ mission(1, 8), mission(2, 0), mission(3, 620) },
			goals(0, { own5 = 3, ownDowntown = 4 })
		)
	end,
	OneReady = function(): State
		return state("Ready", { mission(1, 15), mission(2, 0), mission(3, 620) }, goals(1, { ownDowntown = 4 }))
	end,
	AllReady = function(): State
		return state("Ready", { mission(1, 15), mission(2, 1), mission(3, 1000) }, goals(2))
	end,
	-- claim sent, answer not back yet
	Pending = function(): State
		return state("Ready", { mission(1, 15, "Pending"), mission(2, 0), mission(3, 620) }, goals(1))
	end,
	-- the answer was an error: the card goes back to CLAIM with a message
	ClaimError = function(): State
		return state("Ready", { mission(1, 15, "Error"), mission(2, 0), mission(3, 620) }, goals(1))
	end,
	-- already claimed (waiting to be replaced)
	Claimed = function(): State
		return state("Ready", { mission(1, 15, "Claimed"), mission(2, 0), mission(3, 620) }, goals(1))
	end,
	-- progress unknown: "Checking...", never zero
	Checking = function(): State
		return state("Ready", { mission(1, nil), mission(2, nil), mission(3, nil) }, goals(0))
	end,
	Loading = function(): State
		return state("Loading", {}, {})
	end,
	LoadError = function(): State
		return state("Error", {}, {})
	end,
	Empty = function(): State
		return state("Ready", {}, goals(0))
	end,
	GoalsAllDone = function(): State
		return state("Ready", { mission(1, 8), mission(2, 0), mission(3, 620) }, goals(#MissionFixtures.GoalNames))
	end,
	-- bad source values: the bar clamps for drawing and the panel logs the bad value
	InvalidValues = function(): State
		local list = { mission(1, -4), mission(2, 0 / 0), mission(3, 99999) }
		return state("Ready", list, goals(0))
	end,
	-- 30 percent longer strings
	LongStrings = function(): State
		local list = { mission(1, 8), mission(2, 0), mission(4, 120) }
		list[1].text = "Hop onto fifteen different cars"
		list[1].sub = "In one single run without stopping"
		list[2].text = "Claim a Rare car from any World"
		list[3].text = "Earn $500 from Lap Pay on your Raceway"
		local g = goals(2)
		g[3].text = "Claim your very first Variant car"
		return state("Ready", list, g)
	end,
}

MissionFixtures.PresetNames = table.freeze({
	"Board",
	"InProgress3",
	"OneReady",
	"AllReady",
	"Pending",
	"ClaimError",
	"Claimed",
	"Checking",
	"Loading",
	"LoadError",
	"Empty",
	"GoalsAllDone",
	"InvalidValues",
	"LongStrings",
})

function MissionFixtures.preset(name: string): State?
	local make = presets[name]
	if not make then
		return nil
	end
	return make()
end

-- One fresh mission from the template list (index cycles); for the explicit fixture refresh and the replacement.
function MissionFixtures.fromTemplate(index: number): Mission
	local n = #MissionFixtures.Templates
	return mission(((index - 1) % n) + 1, 0)
end

-- The display state of a mission, derived from its numbers and its claim state (never from a timer):
--   Checking (progress unknown), Claimed, Pending, Ready (target reached; Error keeps it Ready with a message), InProgress.
export type Visual = "Checking" | "InProgress" | "Ready" | "Pending" | "Claimed"

function MissionFixtures.visual(m: Mission): Visual
	if m.claim == "Claimed" then
		return "Claimed"
	elseif m.claim == "Pending" then
		return "Pending"
	end
	local p = m.progress
	if p == nil then
		return "Checking"
	end
	local have = p :: number
	if have ~= have or have < 0 or m.target <= 0 or m.target ~= m.target then
		return "InProgress" -- an invalid value never counts as ready
	end
	if have >= m.target then
		return "Ready"
	end
	return "InProgress"
end

-- The mission the Home tracker shows: the first one ready to claim, otherwise the first in progress.
function MissionFixtures.top(missions: { Mission }): Mission?
	local fallback: Mission? = nil
	for _, m in missions do
		local v = MissionFixtures.visual(m)
		if v == "Ready" then
			return m
		elseif (v == "InProgress" or v == "Pending") and fallback == nil then
			fallback = m
		end
	end
	return fallback
end

return MissionFixtures
