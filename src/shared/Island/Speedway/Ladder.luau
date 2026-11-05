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

local EconomyPreview = require(script.Parent.Parent.Parent.UI.EconomyPreview)

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
		[5] = "flag official, more fans",
		[6] = "pit garage, marshals",
		[7] = "grandstand, announcer booth",
		[8] = "floodlights, light strips",
		[9] = "banked turns",
		[10] = "raised turn, packed stands",
		[11] = "hump, blimp",
		[12] = "loop, statue, sky beams",
	} :: { [number]: string }
do
	Ladder.Levels[level].new = line
end

-- Lap Pay multiplier per level: Brian L's economy v1 proposal (Round 4, E-08), read from the one PREVIEW economy module
-- (src/shared/UI/EconomyPreview) so his real values replace it there. Shown as "LAP PAY x6.5 -> x12"; nothing here pays.
Ladder.LapPay = EconomyPreview.RacewayMultiplier

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

-- "x1.9", "x12", "x1,000": a level's Lap Pay multiplier, no trailing zeros.
function Ladder.lapPayText(level: number): string
	local value = Ladder.LapPay[Ladder.clamp(level)]
	if value >= 1000 then
		return "x" .. string.format("%d,%03d", value // 1000, value % 1000)
	end
	local text = string.format("%.1f", value):gsub("%.0$", "")
	return "x" .. text
end

-- "New: pit garage": what the level adds (nil for level 1).
function Ladder.newText(level: number): string?
	local line = Ladder.get(level).new
	return if line then "New: " .. line else nil
end

return Ladder
