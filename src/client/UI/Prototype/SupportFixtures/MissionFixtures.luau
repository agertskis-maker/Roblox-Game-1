--!strict
-- PREVIEW fixtures for the Missions and Goals panel and the Home tracker (big round M13). The template list is a Lane 3
-- DISPLAY fixture (BRIEF M13-03). Progress, reward amounts, claim results and the daily refresh are Brian L's: every
-- number here is made up, every reward is labelled "PREVIEW reward" where it shows, and nothing is ever granted.
--
-- THE SEAM FOR BRIAN L (the M18 message asks for this shape):
--   load             "Loading" | "Ready" | "Error"
--   missions[]       up to three active: { id, text, sub?, icon, target, progress?, format, reward, claim }
--                    progress nil = unknown (shown as "Checking...", never 0); claim = the server's claim state
--   goals[]          the six one-time milestones: { id, text, icon, done, progress?, target? }; a goal never un-completes
--   claim            a claim request goes out through options.onClaim(id); the answer comes back through
--                    panel:resolveClaim(id, "Success" | "Error"); the reward, the replacement mission and the daily
--                    refresh are the server's (the preview replaces a claimed card once, and refreshes only on an
--                    explicit fixture switch, never on a timer)

local MissionFixtures = {}

MissionFixtures.Source = "PREVIEW fixture: missions, rewards, progress and refresh come from the game (Brian L)"

export type ClaimState = "None" | "Pending" | "Claimed" | "Error"
export type Format = "count" | "cash"

export type Mission = {
	id: string,
	text: string,
	sub: string?,
	icon: string,
	target: number,
	progress: number?, -- nil = unknown
	format: Format,
	reward: number, -- PREVIEW dollars
	claim: ClaimState,
}

export type Goal = {
	id: string,
	text: string,
	icon: string,
	done: boolean,
	progress: number?,
	target: number?,
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
		sub = "In one run",
		icon = "HopCar",
		target = 15,
		format = "count",
		reward = 250,
	},
	{
		id = "rare1",
		text = "Claim a Rare car",
		sub = "From any World",
		icon = "Car",
		target = 1,
		format = "count",
		reward = 500,
	},
	{
		id = "reach1000",
		text = "Reach 1,000 m",
		sub = "Dusty Highway",
		icon = "Track",
		target = 1000,
		format = "count",
		reward = 400,
	},
	{
		id = "lappay500",
		text = "Earn $500 from Lap Pay",
		sub = "On your Raceway",
		icon = "Coin",
		target = 500,
		format = "cash",
		reward = 300,
	},
	{
		id = "stuntvan",
		text = "Finish the Stunt Circuit",
		sub = "In a Van",
		icon = "Flag",
		target = 1,
		format = "count",
		reward = 600,
	},
	{
		id = "hop30",
		text = "Hop 30 times",
		sub = "In one run",
		icon = "HopCar",
		target = 30,
		format = "count",
		reward = 450,
	},
})

-- The six approved milestone names (BRIEF M13-01b).
MissionFixtures.GoalNames = table.freeze({
	{ id = "own5", text = "Own 5 cars", icon = "Car" },
	{ id = "ownDowntown", text = "Own every Downtown car", icon = "GarageBook" },
	{ id = "firstVariant", text = "Claim your first Variant", icon = "Star" },
	{ id = "raceway2", text = "Reach Raceway level 2", icon = "Track" },
	{ id = "bronze", text = "Earn a Bronze medal", icon = "Medal" },
	{ id = "unlockDusty", text = "Unlock Dusty Highway", icon = "Portal" },
})

local function mission(template: number, progress: number?, claim: ClaimState?): Mission
	local t = MissionFixtures.Templates[template]
	return {
		id = t.id,
		text = t.text,
		sub = t.sub,
		icon = t.icon,
		target = t.target,
		progress = progress,
		format = t.format :: Format,
		reward = t.reward,
		claim = claim or "None",
	}
end

local function goals(done: number, progress: { [string]: number }?): { Goal }
	local out: { Goal } = {}
	for i, g in MissionFixtures.GoalNames do
		local target = if g.id == "own5" then 5 elseif g.id == "ownDowntown" then 8 else 1
		local p = if progress then progress[g.id] else nil
		table.insert(out, {
			id = g.id,
			text = g.text,
			icon = g.icon,
			done = i <= done,
			progress = if i <= done then target else p,
			target = target,
		})
	end
	return out
end

local function pool(): { Mission }
	return { mission(4, 0), mission(5, 0), mission(6, 0), mission(1, 0) }
end

local function state(load: Load, missions: { Mission }, goalList: { Goal }): State
	return { source = MissionFixtures.Source, load = load, missions = missions, goals = goalList, pool = pool() }
end

local presets: { [string]: () -> State } = {
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
		return state("Ready", { mission(1, 8), mission(2, 0), mission(3, 620) }, goals(6))
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
