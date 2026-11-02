--!strict
-- PREVIEW fixtures for the Stunt Circuit screens (big round M17-04 and M17-05): the race HUD, the pre-race card, the results
-- card, the weekly leaderboard and the customization screen. EVERYTHING in this file is made up for review: the medal targets,
-- the times, the leaderboard names, the car stats, the prices and who owns what. Nothing is measured and nothing is real, and
-- no screen ever grants anything from it. Real values come from Brian R (course, timing, checkpoints, ghosts, medal
-- thresholds measured with the real car physics) and Brian L (car stats, medals, rewards, the leaderboard, customization
-- ownership and prices).
--
-- THE SEAM FOR THEM (the M18 messages ask for this shape):
--   medal targets      { gold, silver, bronze } seconds, "PREVIEW until measured with the real car physics" (M17-04b)
--   a finished run     { finished, time?, best? }: the screen derives the medal and the personal-best text itself
--   the weekly board   { state, entries = { { rank?, name, time } }, you = { time? } }: ties and the player's row are derived
--   a car              { id, name, family, paint, stats = { speed, jump, grip }? }: stats 1 to 5, nil = "not set yet"
--   customization      per item { id, name, group, price?, medal?, owned, unavailable? } and the equipped ids; EQUIP is a local
--                      display change only
--
-- NO FAKE LIVE COMPETITORS: the board's names are plainly placeholders ("Preview Racer 03") and the screens keep a PREVIEW
-- caption on screen at all times.

local Prototype = script.Parent.Parent
local Fixtures = require(Prototype.Fixtures)

local StuntFixtures = {}

StuntFixtures.Source =
	"PREVIEW fixture: times, targets, names, stats, prices and ownership are made up (Brian R and Brian L supply the real ones)"
StuntFixtures.Caption = "PREVIEW"

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

-- TIME ---------------------------------------------------------------------------------------------------------------

-- m:ss.cc, truncated to hundredths (never rounded up, so a display never claims a faster time than the clock).
function StuntFixtures.formatTime(seconds: number): string
	local s = math.max(seconds, 0)
	local m = math.floor(s / 60)
	local rest = s - m * 60
	local cs = math.floor(rest * 100 + 1e-6)
	return string.format("%d:%02d.%02d", m, cs // 100, cs % 100)
end

-- 0.84 -> "0.84s" (a duration difference, never a clock)
function StuntFixtures.formatDelta(seconds: number): string
	return string.format("%.2fs", math.abs(seconds))
end

-- MEDALS -------------------------------------------------------------------------------------------------------------

export type MedalKey = "gold" | "silver" | "bronze"
export type Targets = { gold: number, silver: number, bronze: number }

export type MedalInfo = {
	key: string,
	word: string,
	letter: string,
	colour: Color3,
	deep: Color3,
}

StuntFixtures.MedalOrder = table.freeze({ "gold", "silver", "bronze" } :: { MedalKey })

StuntFixtures.Medals = table.freeze({
	gold = table.freeze({
		key = "gold",
		word = "GOLD",
		letter = "G",
		colour = rgb(255, 210, 74),
		deep = rgb(226, 150, 0),
	}),
	silver = table.freeze({
		key = "silver",
		word = "SILVER",
		letter = "S",
		colour = rgb(206, 214, 226),
		deep = rgb(132, 144, 166),
	}),
	bronze = table.freeze({
		key = "bronze",
		word = "BRONZE",
		letter = "B",
		colour = rgb(214, 140, 70),
		deep = rgb(150, 86, 36),
	}),
} :: { [string]: MedalInfo })

-- PREVIEW targets in seconds: named so, and never presented as balanced. They stay until Brian R measures real laps.
StuntFixtures.MedalTargets = table.freeze({ gold = 70, silver = 82, bronze = 96 } :: Targets)
StuntFixtures.MedalTargetsNote = "PREVIEW targets until measured with the real car physics"

-- The best medal a time earns (a time equal to a target earns it), or nil.
function StuntFixtures.medalFor(time: number, targets: Targets?): MedalKey?
	local t = targets or StuntFixtures.MedalTargets
	if time <= t.gold then
		return "gold"
	elseif time <= t.silver then
		return "silver"
	elseif time <= t.bronze then
		return "bronze"
	end
	return nil
end

-- RESULTS ------------------------------------------------------------------------------------------------------------

export type Result = {
	id: string,
	label: string,
	finished: boolean,
	time: number?,
	best: number?, -- the personal best BEFORE this run; nil = no best yet
}

export type ResultKind = "NewBest" | "FirstTime" | "Matched" | "Slower" | "Incomplete"

export type ResultView = {
	finished: boolean,
	timeText: string,
	medal: MedalKey?,
	medalPrimary: string,
	medalSecondary: string,
	newBest: boolean,
	pbText: string,
	bestText: string,
	kind: ResultKind,
}

StuntFixtures.Results = table.freeze({
	Gold = { id = "Gold", label = "Gold, new best", finished = true, time = 68.42, best = 69.26 },
	Silver = { id = "Silver", label = "Silver, slower than the best", finished = true, time = 77.9, best = 75.1 },
	Bronze = { id = "Bronze", label = "Bronze, first time on the board", finished = true, time = 91.07, best = nil },
	NoMedal = { id = "NoMedal", label = "No medal, slower than the best", finished = true, time = 101.6, best = 99.4 },
	NoMedalBest = { id = "NoMedalBest", label = "No medal but a new best", finished = true, time = 98, best = 104 },
	Matched = { id = "Matched", label = "Silver, matched the best", finished = true, time = 82, best = 82 },
	FirstNoMedal = { id = "FirstNoMedal", label = "First lap, no medal", finished = true, time = 120.5, best = nil },
	Incomplete = { id = "Incomplete", label = "Run not finished", finished = false, time = nil, best = 80.25 },
} :: { [string]: Result })

StuntFixtures.ResultOrder =
	table.freeze({ "Gold", "Silver", "Bronze", "NoMedal", "NoMedalBest", "Matched", "FirstNoMedal", "Incomplete" })

-- The words a result shows. First the time, then the personal-best comparison, then the medal (M17-04a). The wording is the
-- brief's: no medal is "Lap complete!" / "Try again for Bronze."; a personal best is "NEW BEST!" / "0.84s faster" and only
-- when the fixture (or the real data) supports it.
function StuntFixtures.describe(result: Result, targets: Targets?): ResultView
	local t = targets or StuntFixtures.MedalTargets
	if not result.finished or result.time == nil then
		return {
			finished = false,
			timeText = "--:--.--",
			medal = nil,
			medalPrimary = "Run not finished",
			medalSecondary = "Cross the finish line to set a time.",
			newBest = false,
			pbText = "No time to compare",
			bestText = if result.best then "Best " .. StuntFixtures.formatTime(result.best) else "No best yet",
			kind = "Incomplete",
		}
	end
	local time = result.time
	local medal = StuntFixtures.medalFor(time, t)
	local kind: ResultKind
	local pbText: string
	local bestText: string
	local best = result.best
	if best == nil then
		kind = "FirstTime"
		pbText = "First time on the board"
		bestText = "No best yet"
	elseif time < best then
		kind = "NewBest"
		pbText = StuntFixtures.formatDelta(best - time) .. " faster"
		bestText = "Was " .. StuntFixtures.formatTime(best)
	elseif time == best then
		kind = "Matched"
		pbText = "Matched your best"
		bestText = "Best " .. StuntFixtures.formatTime(best)
	else
		kind = "Slower"
		pbText = StuntFixtures.formatDelta(time - best) .. " slower than your best"
		bestText = "Best " .. StuntFixtures.formatTime(best)
	end
	local primary: string
	local secondary: string
	if medal then
		local info = (StuntFixtures.Medals :: { [string]: MedalInfo })[medal]
		primary = info.word .. " MEDAL"
		secondary = "Target " .. StuntFixtures.formatTime((t :: any)[medal])
	else
		primary = "Lap complete!"
		secondary = "Try again for Bronze."
	end
	return {
		finished = true,
		timeText = StuntFixtures.formatTime(time),
		medal = medal,
		medalPrimary = primary,
		medalSecondary = secondary,
		newBest = kind == "NewBest" or kind == "FirstTime",
		pbText = pbText,
		bestText = bestText,
		kind = kind,
	}
end

-- RACE HUD -----------------------------------------------------------------------------------------------------------

export type HudPreset = {
	time: number,
	checkpoint: number,
	total: number,
	ghostGap: number?,
	label: string,
}

StuntFixtures.HudPresets = table.freeze({
	Default = { time = 42.18, checkpoint = 3, total = 5, ghostGap = 0.42, label = "Behind the ghost" },
	AheadOfGhost = { time = 31.6, checkpoint = 2, total = 5, ghostGap = -0.31, label = "Ahead of the ghost" },
	NoGhost = { time = 42.18, checkpoint = 3, total = 5, ghostGap = nil, label = "No ghost data" },
	Start = { time = 0, checkpoint = 0, total = 5, ghostGap = nil, label = "Start line" },
	GoldMissed = { time = 71.3, checkpoint = 4, total = 5, ghostGap = 1.8, label = "Gold already missed" },
	AllMissed = { time = 97.5, checkpoint = 4, total = 5, ghostGap = 6.4, label = "Every medal missed" },
} :: { [string]: HudPreset })

-- PRE-RACE CARS ------------------------------------------------------------------------------------------------------

export type Stats = { speed: number, jump: number, grip: number }

export type PreRaceCar = {
	id: string,
	name: string,
	family: string,
	paint: Color3?,
	stats: Stats?, -- nil = "not set yet": the card shows empty pips and "--", never an invented number
	missingArt: boolean,
}

local function fromFixture(id: string, stats: Stats?): PreRaceCar
	local car = Fixtures.byId(id)
	if not car then
		return { id = id, name = id, family = "Compact", paint = nil, stats = stats, missingArt = true }
	end
	return { id = car.id, name = car.name, family = car.family, paint = car.paint, stats = stats, missingArt = false }
end

-- PREVIEW stats (1 to 5 pips). The real ones are Brian L's.
function StuntFixtures.cars(): { PreRaceCar }
	return {
		fromFixture("puglet", { speed = 2, jump = 3, grip = 4 }),
		fromFixture("fishbowl", { speed = 1, jump = 1, grip = 3 }),
		fromFixture("waffle", { speed = 3, jump = 2, grip = 2 }),
		{
			id = "mystery",
			name = "Mystery Model",
			family = "Sedan",
			paint = nil,
			stats = nil,
			missingArt = true,
		},
	}
end

-- many cars, for the scroll and the long-name checks
function StuntFixtures.manyCars(n: number): { PreRaceCar }
	local base = StuntFixtures.cars()
	local out: { PreRaceCar } = {}
	for i = 1, n do
		local source = base[(i - 1) % #base + 1]
		local copy = table.clone(source)
		copy.id = source.id .. "-" .. i
		copy.name = source.name .. " " .. i
		table.insert(out, copy)
	end
	return out
end

-- a very long name, for the 30 percent longer strings check
function StuntFixtures.longNameCar(): PreRaceCar
	local car = fromFixture("waffle", { speed = 5, jump = 5, grip = 5 })
	car.id = "long"
	car.name = Fixtures.LongName.name
	return car
end

-- LEADERBOARD ----------------------------------------------------------------------------------------------------------

export type Entry = {
	rank: number,
	rankText: string,
	name: string,
	time: number,
	you: boolean,
	tied: boolean,
}

export type BoardState = "Ready" | "Loading" | "Error" | "Empty"

export type Board = {
	id: string,
	label: string,
	state: BoardState,
	entries: { Entry }, -- the top ten
	you: Entry?, -- the local player's own row when they have a time
	youInTop: boolean,
	week: string,
}

-- Competition ranking: equal times share a rank and show "4=" (the next rank skips, so two fourths are followed by a sixth).
local function ranked(times: { number }, names: { string }, youIndex: number?): { Entry }
	local out: { Entry } = {}
	for i, time in times do
		local rank = i
		for j = 1, i do
			if times[j] == time then
				rank = j
				break
			end
		end
		local tied = false
		for j, other in times do
			if j ~= i and other == time then
				tied = true
			end
		end
		table.insert(out, {
			rank = rank,
			rankText = if tied then rank .. "=" else tostring(rank),
			name = names[i],
			time = time,
			you = youIndex == i,
			tied = tied,
		})
	end
	return out
end

local TOP_TIMES = { 64.2, 66.85, 67.4, 68.12, 68.12, 69.9, 71.33, 72.08, 73.5, 75.21 }

local function previewNames(): { string }
	local names: { string } = {}
	for i = 1, 10 do
		table.insert(names, string.format("Preview Racer %02d", i))
	end
	return names
end

local function makeBoard(id: string, label: string, youTime: number?, state: BoardState): Board
	local times = table.clone(TOP_TIMES)
	local names = previewNames()
	local youIndex: number? = nil
	local you: Entry? = nil
	local youInTop = false
	if state == "Ready" and youTime ~= nil then
		-- where would this time fall among the top ten?
		local place = #times + 1
		for i, t in times do
			if youTime <= t then
				place = i
				break
			end
		end
		if place <= 10 then
			table.insert(times, place, youTime)
			table.insert(names, place, "You")
			table.remove(times)
			table.remove(names)
			youIndex = place
			youInTop = true
		end
	end
	local entries: { Entry } = {}
	if state == "Ready" then
		entries = ranked(times, names, youIndex)
	end
	if youTime ~= nil and state == "Ready" then
		if youInTop and youIndex then
			you = entries[youIndex]
		else
			-- outside the top ten: a rank below the tenth (a fixture value, not computed from other players)
			you = { rank = 23, rankText = "23", name = "You", time = youTime, you = true, tied = false }
		end
	end
	return {
		id = id,
		label = label,
		state = state,
		entries = entries,
		you = you,
		youInTop = youInTop,
		week = "This week (PREVIEW)",
	}
end

StuntFixtures.BoardOrder = table.freeze({ "InTop", "Outside", "Tied", "NoTime", "Empty", "Loading", "Error" })

function StuntFixtures.board(name: string): Board
	if name == "InTop" then
		return makeBoard("InTop", "You are in the top ten", 69.5, "Ready")
	elseif name == "Outside" then
		return makeBoard("Outside", "You are outside the top ten", 88.4, "Ready")
	elseif name == "Tied" then
		return makeBoard("Tied", "You tie another time", 68.12, "Ready")
	elseif name == "NoTime" then
		return makeBoard("NoTime", "You have no time yet", nil, "Ready")
	elseif name == "Empty" then
		return makeBoard("Empty", "Nobody has a time this week", nil, "Empty")
	elseif name == "Loading" then
		return makeBoard("Loading", "Loading the board", nil, "Loading")
	elseif name == "Error" then
		return makeBoard("Error", "The board could not load", nil, "Error")
	end
	return makeBoard("NoTime", "You have no time yet", nil, "Ready")
end

-- CUSTOMIZATION --------------------------------------------------------------------------------------------------------

export type Group = "Free" | "Cash" | "Medal"
export type TabId = "Paint" | "Decals" | "Wheels"

export type Item = {
	id: string,
	name: string,
	tab: TabId,
	group: Group,
	colour: Color3,
	price: number?, -- PREVIEW cash price (Cash group only)
	medal: MedalKey?, -- the medal that unlocks it (Medal group only)
	owned: boolean, -- a fixture: the player already has it
	unavailable: boolean?, -- no art or not offered right now (not the same as locked)
}

local function paint(id: string, name: string, group: Group, colour: Color3, price: number?, medal: MedalKey?): Item
	return {
		id = id,
		name = name,
		tab = "Paint",
		group = group,
		colour = colour,
		price = price,
		medal = medal,
		owned = group == "Free",
	}
end

-- Eight free paints, eight Cash-priced preview paints, and the medal paints (M17-05a).
StuntFixtures.Paints = table.freeze({
	paint("cloud", "Cloud White", "Free", rgb(236, 240, 248)),
	paint("cherry", "Cherry Red", "Free", rgb(226, 60, 64)),
	paint("sky", "Sky Blue", "Free", rgb(64, 150, 235)),
	paint("lime", "Lime Green", "Free", rgb(90, 200, 90)),
	paint("sun", "Sun Yellow", "Free", rgb(250, 206, 60)),
	paint("pumpkin", "Pumpkin", "Free", rgb(255, 138, 40)),
	paint("grape", "Grape", "Free", rgb(150, 90, 220)),
	paint("midnight", "Midnight", "Free", rgb(36, 42, 66)),
	paint("bubblegum", "Bubblegum", "Cash", rgb(255, 140, 200), 400),
	paint("mint", "Mint Fizz", "Cash", rgb(120, 230, 190), 400),
	paint("teal", "Ocean Teal", "Cash", rgb(30, 160, 170), 600),
	paint("coral", "Coral Pop", "Cash", rgb(255, 110, 100), 600),
	paint("rush", "Rush Amber", "Cash", rgb(240, 170, 40), 900),
	paint("violet", "Violet Sky", "Cash", rgb(120, 100, 240), 900),
	paint("lava", "Lava", "Cash", rgb(230, 70, 30), 1200),
	paint("frost", "Frost", "Cash", rgb(190, 230, 250), 1200),
	paint("m_bronze", "Bronze Finish", "Medal", rgb(205, 127, 50), nil, "bronze"),
	paint("m_silver", "Silver Finish", "Medal", rgb(200, 208, 220), nil, "silver"),
	paint("m_gold", "Gold Finish", "Medal", rgb(255, 200, 40), nil, "gold"),
} :: { Item })

local function decal(id: string, name: string, group: Group, colour: Color3, price: number?, medal: MedalKey?): Item
	return {
		id = id,
		name = name,
		tab = "Decals",
		group = group,
		colour = colour,
		price = price,
		medal = medal,
		owned = group == "Free",
	}
end

StuntFixtures.Decals = table.freeze({
	decal("none", "No Decal", "Free", rgb(120, 130, 156)),
	decal("stripe", "Racing Stripe", "Free", rgb(246, 246, 240)),
	decal("checker", "Checker Band", "Free", rgb(30, 36, 56)),
	decal("dot", "Star Dot", "Free", rgb(247, 200, 58)),
	decal("bolt", "Bolt Dash", "Cash", rgb(120, 220, 255), 250),
	decal("laurel", "Laurel", "Medal", rgb(255, 200, 40), nil, "gold"),
} :: { Item })

local function wheel(
	id: string,
	name: string,
	group: Group,
	colour: Color3,
	price: number?,
	unavailable: boolean?
): Item
	return {
		id = id,
		name = name,
		tab = "Wheels",
		group = group,
		colour = colour,
		price = price,
		medal = nil,
		owned = group == "Free",
		unavailable = unavailable,
	}
end

-- Three wheel styles.
StuntFixtures.Wheels = table.freeze({
	wheel("street", "Street", "Free", rgb(56, 60, 76)),
	wheel("sport", "Sport", "Free", rgb(200, 206, 222)),
	wheel("classic", "Classic", "Cash", rgb(250, 240, 214), 300),
} :: { Item })

-- Who owns what and who has earned which medal, as a FIXTURE the screen reads and never writes.
export type Ownership = {
	owned: { [string]: boolean }, -- item id -> owned (Cash-group items the player already has)
	medals: { [string]: boolean }, -- medal key -> earned
	unavailable: { [string]: boolean }, -- item id -> not offered right now
}

function StuntFixtures.ownership(): Ownership
	return {
		owned = { mint = true },
		medals = { bronze = true, silver = false, gold = false },
		unavailable = { frost = true },
	}
end

export type Equipped = { Paint: string, Decals: string, Wheels: string }

function StuntFixtures.equipped(): Equipped
	return { Paint = "sky", Decals = "none", Wheels = "street" }
end

function StuntFixtures.itemsFor(tab: TabId): { Item }
	if tab == "Paint" then
		return StuntFixtures.Paints
	elseif tab == "Decals" then
		return StuntFixtures.Decals
	end
	return StuntFixtures.Wheels
end

export type ItemState = "equipped" | "owned" | "locked" | "priced" | "unavailable"

-- The base state of an item: the five states of M17-05a minus "selected" and "previewing", which are the player's pick and
-- depend on what is equipped. A medal paint is locked until its medal is earned; a Cash paint is priced until owned; an item
-- with no art is unavailable (a different thing from locked, with its own look and words).
function StuntFixtures.stateOf(item: Item, ownership: Ownership, equippedId: string): ItemState
	if item.unavailable or ownership.unavailable[item.id] then
		return "unavailable"
	end
	if item.id == equippedId then
		return "equipped"
	end
	if item.group == "Free" or ownership.owned[item.id] then
		return "owned"
	end
	if item.group == "Medal" then
		local medal = item.medal
		if medal and ownership.medals[medal] then
			return "owned"
		end
		return "locked"
	end
	return "priced"
end

-- SELF TEST ----------------------------------------------------------------------------------------------------------------

-- Checks the fixture logic itself (not the screens). Returns the list of failures; an empty list means every check passed.
-- From the command bar: print(require(...SupportFixtures.StuntFixtures).selfTest())
function StuntFixtures.selfTest(): { string }
	local failures: { string } = {}
	local function expect(name: string, got: any, want: any)
		if got ~= want then
			table.insert(failures, string.format("%s: got %s, wanted %s", name, tostring(got), tostring(want)))
		end
	end
	expect("formatTime 68.42", StuntFixtures.formatTime(68.42), "1:08.42")
	expect("formatTime 70", StuntFixtures.formatTime(70), "1:10.00")
	expect("formatTime 0", StuntFixtures.formatTime(0), "0:00.00")
	expect("medal at gold target", StuntFixtures.medalFor(70), "gold")
	expect("medal just over gold", StuntFixtures.medalFor(70.01), "silver")
	expect("medal at bronze target", StuntFixtures.medalFor(96), "bronze")
	expect("medal just over bronze", StuntFixtures.medalFor(96.01), nil)
	local gold = StuntFixtures.describe(StuntFixtures.Results.Gold)
	expect("gold medal", gold.medal, "gold")
	expect("gold new best", gold.newBest, true)
	expect("gold pb text", gold.pbText, "0.84s faster")
	local none = StuntFixtures.describe(StuntFixtures.Results.NoMedal)
	expect("no medal primary", none.medalPrimary, "Lap complete!")
	expect("no medal secondary", none.medalSecondary, "Try again for Bronze.")
	expect("no medal slower", none.kind, "Slower")
	expect("no medal ribbon", none.newBest, false)
	local first = StuntFixtures.describe(StuntFixtures.Results.Bronze)
	expect("first lap kind", first.kind, "FirstTime")
	expect("first lap text", first.pbText, "First time on the board")
	expect("matched kind", StuntFixtures.describe(StuntFixtures.Results.Matched).kind, "Matched")
	local incomplete = StuntFixtures.describe(StuntFixtures.Results.Incomplete)
	expect("incomplete time", incomplete.timeText, "--:--.--")
	expect("incomplete medal", incomplete.medal, nil)
	expect("incomplete ribbon", incomplete.newBest, false)
	-- the board: ties share a rank, the next rank skips, and the player's row sits where the time falls
	local tied = StuntFixtures.board("Tied")
	expect("tied rows", #tied.entries, 10)
	expect("tied rank 4", tied.entries[4].rankText, "4=")
	expect("tied rank 5", tied.entries[5].rankText, "4=")
	expect("tied you in top", tied.youInTop, true)
	local outside = StuntFixtures.board("Outside")
	expect("outside rows", #outside.entries, 10)
	expect("outside you", outside.you ~= nil and outside.you.rankText, "23")
	expect("outside not in top", outside.youInTop, false)
	expect("no time you", StuntFixtures.board("NoTime").you, nil)
	expect("empty rows", #StuntFixtures.board("Empty").entries, 0)
	-- the customization content the brief asks for
	local free, cash, medal = 0, 0, 0
	for _, p in StuntFixtures.Paints do
		if p.group == "Free" then
			free += 1
		elseif p.group == "Cash" then
			cash += 1
			expect("cash paint has a price", p.price ~= nil, true)
		else
			medal += 1
			expect("medal paint has a medal", p.medal ~= nil, true)
		end
	end
	expect("free paints", free, 8)
	expect("cash paints", cash, 8)
	expect("medal paints", medal, 3)
	expect("wheel styles", #StuntFixtures.Wheels, 3)
	local o = StuntFixtures.ownership()
	local e = StuntFixtures.equipped()
	expect("equipped paint state", StuntFixtures.stateOf(StuntFixtures.Paints[3], o, e.Paint), "equipped")
	expect("free paint state", StuntFixtures.stateOf(StuntFixtures.Paints[1], o, e.Paint), "owned")
	expect("cash paint state", StuntFixtures.stateOf(StuntFixtures.Paints[15], o, e.Paint), "priced")
	expect("owned cash paint state", StuntFixtures.stateOf(StuntFixtures.Paints[10], o, e.Paint), "owned")
	expect("unavailable paint state", StuntFixtures.stateOf(StuntFixtures.Paints[16], o, e.Paint), "unavailable")
	expect("earned medal paint state", StuntFixtures.stateOf(StuntFixtures.Paints[17], o, e.Paint), "owned")
	expect("locked medal paint state", StuntFixtures.stateOf(StuntFixtures.Paints[19], o, e.Paint), "locked")
	return failures
end

return StuntFixtures
