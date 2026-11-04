--!strict
-- CashPackPreview: the PREVIEW maths of the scaling Cash packs (Lane 3, Round 3 N5; Adam's decision 2026-11-02). DISPLAY ONLY.
-- A pack is "N minutes of your Raceway earnings", with a floor from the Cash you hold, so a pack stays worth having
-- however far you have come ("If I have $1,000 I can buy $5,000. At $1 million, $5 million.").
--
--   amount = rounded( max( earningsPerSecond x 60 x minutes, currentCash x floor, minutes x BASE_PER_MINUTE ) )
--
-- Nothing here grants anything. The real grant must be computed BY THE SERVER, at purchase time, from server data, inside
-- ProcessReceipt, once per receipt: the client's number is never trusted (vault/design/specs/lane3-round3-for-brian-l.md).
-- Every price and floor is a proposal for Brian L. No paid randomness: a pack always gives exactly what the card says.
--
--   CashPackPreview.Packs                                 the five packs, smallest first
--   CashPackPreview.amount(pack, rate, cash) -> number    one pack's live amount
--   CashPackPreview.list(rate, cash) -> { Row }           every pack, with `best` true on the one that truly gives most per Robux
--   CashPackPreview.timeLabel(minutes) -> string          "30 MIN", "1 HOUR", "3 HOURS"
--   CashPackPreview.FixtureRate                           the PREVIEW earnings rate until real data exists ($ per second)

local CashPackPreview = {}

export type Pack = {
	id: string,
	minutes: number,
	robux: number, -- PREVIEW
	floor: number, -- at least this many times the player's current Cash
	art: string,
	family: string,
}

export type Row = {
	pack: Pack,
	amount: number,
	label: string,
	best: boolean,
}

CashPackPreview.BASE_PER_MINUTE = 50 -- a brand new Raceway still gets a pack worth buying
CashPackPreview.FixtureRate = 30

-- Each step gives more per Robux than the last, in earnings and in the floor, so a bigger pack never quietly loses value.
CashPackPreview.Packs = table.freeze({
	table.freeze({ id = "cash-10", minutes = 10, robux = 49, floor = 0.4, art = "art_cash1", family = "CashBlue" }),
	table.freeze({ id = "cash-30", minutes = 30, robux = 99, floor = 1, art = "art_cash2", family = "CashTeal" }),
	table.freeze({ id = "cash-60", minutes = 60, robux = 179, floor = 1.9, art = "art_cash3", family = "CashGold" }),
	table.freeze({ id = "cash-180", minutes = 180, robux = 449, floor = 5, art = "art_cash4", family = "CashPurple" }),
	table.freeze({ id = "cash-480", minutes = 480, robux = 899, floor = 12, art = "art_cash5", family = "CashVault" }),
} :: { Pack })

-- Rounds down to three significant figures: tidy numbers that never promise more than the sum.
local function tidy(n: number): number
	if n < 1000 then
		return math.floor(n / 10) * 10
	end
	local unit = 10 ^ (math.floor(math.log10(n)) - 2)
	return math.floor(n / unit) * unit
end

function CashPackPreview.amount(pack: Pack, rate: number, cash: number): number
	local earned = math.max(rate, 0) * 60 * pack.minutes
	local floor = math.max(cash, 0) * pack.floor
	local base = pack.minutes * CashPackPreview.BASE_PER_MINUTE
	return tidy(math.max(earned, floor, base))
end

function CashPackPreview.timeLabel(minutes: number): string
	if minutes < 60 then
		return string.format("%d MIN", minutes)
	end
	local hours = math.floor(minutes / 60)
	return string.format("%d HOUR%s", hours, if hours == 1 then "" else "S")
end

-- BEST VALUE goes only to the pack that truly gives the most Cash per Robux for this player right now.
function CashPackPreview.list(rate: number, cash: number): { Row }
	local rows: { Row } = {}
	local bestIndex, bestValue = 0, -1
	for i, pack in CashPackPreview.Packs do
		local amount = CashPackPreview.amount(pack, rate, cash)
		table.insert(
			rows,
			{ pack = pack, amount = amount, label = CashPackPreview.timeLabel(pack.minutes), best = false }
		)
		local value = amount / pack.robux
		if value > bestValue then
			bestIndex, bestValue = i, value
		end
	end
	if bestIndex > 0 then
		rows[bestIndex].best = true
	end
	return rows
end

return CashPackPreview
