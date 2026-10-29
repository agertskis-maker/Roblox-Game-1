--!strict
-- The Speedway look ladder (Lane 3, presentation only). Adam decided 10 to 15 visible levels on
-- 2026-10-28; 12 is Claude's recommendation, built as a PREVIEW. The final count, the price and
-- Lap Pay effect of each level, the save field and the relation to Slots are Brian L's (Lane 2),
-- so nothing here holds a price, multiplier or Cash amount. Brief:
-- vault/design/specs/speedway-upgrade-looks.md section 3.

local Ladder = {}

export type Level = {
	level: number,
	name: string,
	-- what a passer-by notices (the kiosk preview line and the reveal banner)
	adds: string,
	-- the piece the kiosk picture shows and the ghost preview outlines
	signature: string,
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

-- The reveal banner text, for example "SPEEDWAY LEVEL 5: THE FLAG OFFICIAL!".
function Ladder.banner(level: number): string
	local l = Ladder.get(level)
	return string.format("SPEEDWAY LEVEL %d: %s!", l.level, string.upper(l.name))
end

return Ladder
