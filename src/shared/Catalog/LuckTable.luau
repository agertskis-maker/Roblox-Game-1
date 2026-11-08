--!strict
-- Luck Station levels (Lane 2, Brian L; vault/design/specs/luck-station-proposal.md). The same table as
-- src/shared/Catalog/EconomyPreview.luau on feature/lane2-economy-preview, copied here so the Car Hop Beta can use it.
-- PREVIEW numbers: the real table changes only after all three lanes write "Agreed" on the board.
--
-- Level 1 is the start. Multiplier[level] multiplies a run's Rare, Epic and Legendary weights (RunSequence.new luck);
-- Price[level] is the Cash cost to reach that level. Bought with Cash only, never Robux.

local LuckTable = {}

LuckTable.MaxLevel = 10
LuckTable.Multiplier = table.freeze({ 1, 1.1, 1.2, 1.3, 1.45, 1.6, 1.75, 1.9, 2.05, 2.25 })
LuckTable.Price = table.freeze({
	0,
	5_000,
	40_000,
	300_000,
	2_500_000,
	20_000_000,
	150_000_000,
	1_200_000_000,
	10_000_000_000,
	80_000_000_000,
})

-- A whole level from 1 to MaxLevel; anything else (nil, NaN, text, out of range) becomes the nearest valid level.
function LuckTable.clampLevel(level: any): number
	if type(level) ~= "number" or level ~= level then
		return 1
	end
	return math.clamp(math.floor(level), 1, LuckTable.MaxLevel)
end

-- Price of reaching `level` (2 to MaxLevel); nil when that level cannot be bought.
function LuckTable.price(level: number): number?
	if level < 2 or level > LuckTable.MaxLevel or level ~= math.floor(level) then
		return nil
	end
	return LuckTable.Price[level]
end

function LuckTable.multiplier(level: any): number
	return LuckTable.Multiplier[LuckTable.clampLevel(level)]
end

return LuckTable
