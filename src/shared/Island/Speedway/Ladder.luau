--!strict
-- The Speedway look ladder (Lane 3, presentation only). Adam decided 10 to 15 visible levels on
-- 2026-10-28; 12 is Claude's recommendation, built as a PREVIEW. The final count, the price and
-- Lap Pay effect of each level, the save field and the relation to Slots are Brian L's (Lane 2),
-- so nothing here holds a price, multiplier or Cash amount. Brief:
-- vault/design/specs/speedway-upgrade-looks.md section 3.
--
-- Raceway round 2 (Adam, 2026-10-29): the player-facing name is "Raceway"; level names are internal
-- labels only and are never shown (the banner states the level only). Each level carries the
-- "New:" line the stats board and the upgrade panel show, and the Lap Pay multiplier, Adam's
-- PROPOSAL for Brian L, in one table (Ladder.LapPay) so his economy can replace it. Lap time stays
-- about 15 s at every level, so the multiplier is the only earning stat. Specs:
-- vault/design/ui/raceway-upgrade-panel.md, raceway-level-banner.md.

local Ladder = {}

export type Level = {
	level: number,
	name: string, -- internal label only, never shown to players
	-- what a passer-by notices (the kiosk preview line and the reveal banner)
	adds: string,
	-- the piece the ghost preview outlines
	signature: string,
	-- what reaching this level adds, as the board and the panel show it ("New: pit garage")
	new: string?,
}

Ladder.Levels = {
	{
		level = 1,
		name = "Backyard Dirt Track",
		adds = "A dirt oval, hay bales and your own sign",
		signature = "OwnerSign",
	},
	{ level = 2, name = "Raked and Roped", adds = "Smooth dirt, rope fence, pennants", signature = "StartBoard" },
	{ level = 3, name = "First Fans", adds = "Bleachers with cheering fans", signature = "Bleachers" },
	{ level = 4, name = "Paved", adds = "Smooth asphalt, curbs, a tyre wall", signature = "TyreWall" },
	{ level = 5, name = "The Flag Official", adds = "A flag official waves every lap", signature = "Official" },
	{ level = 6, name = "Pit Row", adds = "A pit garage with a mechanic", signature = "PitGarage" },
	{ level = 7, name = "The Grandstand", adds = "A covered grandstand and announcer", signature = "Grandstand" },
	{
		level = 8,
		name = "Lights and Big Screen",
		adds = "Floodlights, a gantry and a big screen",
		signature = "Gantry",
	},
	{ level = 9, name = "Banked Turns", adds = "Tilted turns with high walls", signature = "BankedWalls" },
	{ level = 10, name = "The Overpass", adds = "A raised far turn and a ramp back down", signature = "Raised" },
	{ level = 11, name = "Jump and Blimp", adds = "A hump to hop and a blimp overhead", signature = "Jump" },
	{ level = 12, name = "Loop of Legends", adds = "A loop, a champion statue, fireworks", signature = "Loop" },
} :: { Level }

for level, line in
	{
		[2] = "rope fence, pennants",
		[3] = "bleachers, snack cart",
		[4] = "asphalt, tyre wall",
		[5] = "flag official, start lights",
		[6] = "pit garage",
		[7] = "grandstand, announcer booth",
		[8] = "floodlights, big screen",
		[9] = "banked turns",
		[10] = "raised far turn",
		[11] = "hump, blimp",
		[12] = "loop, champion statue",
	} :: { [number]: string }
do
	Ladder.Levels[level].new = line
end

-- Lap Pay multiplier per level: a PROPOSAL for Brian L (Lane 2), not an agreed economy value.
-- Shown only as "LAP PAY x1.35 -> x1.50"; nothing here pays anything.
Ladder.LapPay = { 1.00, 1.10, 1.20, 1.35, 1.50, 1.70, 1.90, 2.15, 2.40, 2.70, 3.00, 3.50 } :: { number }

Ladder.MaxLevel = #Ladder.Levels
Ladder.MinLevel = 1

-- If the team picks 15 levels (Brian L / Adam): where the three extra looks fit best. Not built.
Ladder.Extras = {
	{ after = 8, name = "Night Lights Show", adds = "Coloured light strips that pulse on special laps" },
	{ after = 9, name = "Second Grandstand", adds = "A grandstand on the far straight with a mascot" },
	{ after = 11, name = "Sky Tram", adds = "A tram that glides round the outside of the plot" },
}

function Ladder.get(level: number): Level
	return Ladder.Levels[math.clamp(math.floor(level), Ladder.MinLevel, Ladder.MaxLevel)]
end

function Ladder.clamp(level: number): number
	return math.clamp(math.floor(level), Ladder.MinLevel, Ladder.MaxLevel)
end

-- The level-up banner text, exactly "RACEWAY LEVEL 5!" (no level name).
function Ladder.banner(level: number): string
	return string.format("RACEWAY LEVEL %d!", Ladder.clamp(level))
end

-- "x1.35": a level's Lap Pay multiplier, always two decimals.
function Ladder.lapPayText(level: number): string
	return string.format("x%.2f", Ladder.LapPay[Ladder.clamp(level)])
end

-- "New: pit garage": what the level adds (nil for level 1).
function Ladder.newText(level: number): string?
	local line = Ladder.get(level).new
	return if line then "New: " .. line else nil
end

return Ladder
