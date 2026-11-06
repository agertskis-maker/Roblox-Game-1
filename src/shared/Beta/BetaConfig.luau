--!strict
-- CAR HOP BETA 1 (Adam approved on 2026-10-31: one place, may save, may be incomplete). Shared names
-- for the beta glue. Every beta script is off unless ReplicatedStorage.CarHopBeta exists; only
-- beta.project.json creates it, so default.project.json (the team's game) is unchanged.
-- Stand-ins, not Lane 2's contracts: the save fields, the remotes and the purchases here are
-- replaced by Brian L's real economy and save layout (vault/decisions/0030-car-hop-beta-1.md, 0039).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BetaConfig = {}

BetaConfig.MarkerName = "CarHopBeta"
BetaConfig.NetName = "CarHopBetaNet"
BetaConfig.Remotes = {
	BuyRacewayLevel = "BuyRacewayLevel", -- no arguments: the server raises the caller's own Raceway by one, for Cash
	BuyParkingSpot = "BuyParkingSpot", -- no arguments: the server adds one spot to the caller's own Paddock, for Cash
	TutorialDone = "TutorialDone", -- no arguments: the server remembers the caller finished or skipped the tutorial
	-- (slot: integer, carId: string?): BETA STAND-IN for Brian L's agreed remote of the same name and arguments (decision
	-- 0036). Puts one of the caller's own cars in one of the caller's own Paddock slots, or takes it out (carId nil).
	SetLineupSlot = "SetLineupSlot",
	-- Round 5 (decision 0039). Agreed name and argument: (worldId: string). The server checks Cash and cars owned.
	UnlockWorld = "UnlockWorld",
	-- Stamina Shop (Adam, 2026-11-05; beta-only, a proposal for Brian L): no arguments. The server raises the caller's own
	-- StaminaLevel by one, for Cash at EconomyPreview.staminaPrice.
	BuyStaminaLevel = "BuyStaminaLevel",
	-- Round 7 (P-04, beta-only, a proposal for Brian L): no arguments. The server raises the caller's own LuckLevel by one, for Cash
	-- at EconomyPreview.luckPrice, unless PolicyService says paid random items are restricted for that player (R7-S09).
	BuyLuckLevel = "BuyLuckLevel",
	-- Server -> client: (what: string, ok: boolean, reason: string?, missing: number?) after every purchase or Lineup
	-- request, so a refusal shows the server's reason and the server's missing amount. The client never computes either.
	Result = "BetaResult",
	-- The run report (note 0021 shape). Round 6 (E-04): StartRun, RunEvents, KeysComplete and RunGranted use Brian L's names
	-- in src/shared/Beta/BetaRunNet (folder ReplicatedStorage.EconomyPreviewNet); the Round 5 Beta* names are accepted for
	-- one round. These two stay beta-only (his contract has no close-and-total remote yet):
	RunEnd = "BetaRunEnd", -- (runId: string, cause: string)
	RunResults = "BetaRunResults", -- server -> client: (runId, totals)
	-- Round 6 (R-02): server -> client after a receipt is granted and saved: (itemId: string, summary: { [string]: any })
	PurchaseGranted = "BetaPurchaseGranted",
	LapPaid = "BetaLapPaid", -- server -> client: (plotIndex, slot, carId, amount, newCash?) newCash only to the owner
	-- Round 7 (P-01): no arguments. Credits the caller's own Welcome back amount, which the server computed on load and holds;
	-- once only (a second press credits nothing). Leaving without pressing it credits it too.
	CollectWelcome = "CollectWelcome",
}

-- ProfileStore store and template. A beta-only store, so the real game's saves start clean.
BetaConfig.StoreName = "CarHopBeta1"
BetaConfig.Template = {
	RacewayLevel = 1,
	ParkingSpots = 2,
	TutorialDone = false, -- Adam, 2026-11-02: the tutorial is for first-time players only
	-- Round 4: two of the AGREED save fields (economy v1 section 13, decision 0036), with their agreed start values: the
	-- Downtown Loaner, Normal, 0 copies, and the Loaner in the Lineup.
	Cars = { Putter = { Edition = 1, Copies = 0 } },
	Lineup = { "Putter" },
	-- Round 5: the last three AGREED fields (decision 0036 item 4, decision 0039). No other field is added.
	Cash = 0,
	WorldsUnlocked = { Downtown = true },
	LastSeen = 0, -- Unix time; 0 means "never stamped" and never pays offline credit
	-- Stamina Shop upgrades bought, 0 to EconomyPreview.StaminaMaxLevel. NOT an agreed field: Adam approved it for the beta on
	-- 2026-11-05; Brian L decides whether his save takes it (vault/design/specs/stamina-shop-for-brian-l.md).
	StaminaLevel = 0,
	-- Round 6 (R-02, Adam's decision of 2026-11-05, brief section 0 item 6): the two beta-only Robux fields, proposed to all
	-- three lanes in vault/design/specs/robux-fields-for-brian-l.md. No other field is added.
	Purchases = {}, -- processed Developer Product receipt ids (PurchaseId strings), newest last, at most 200
	Owned = {}, -- { [id]: true }: passes the All Passes Bundle granted, the Starter Pack (once per player) and its cosmetics
	-- Round 7 (P-04, decision 0042 item 10): Lucky Clover levels bought, 0 to EconomyPreview.LuckMaxLevel. Beta-only, a proposal
	-- for Brian L (vault/design/specs/lane3-round7-for-brian-l.md).
	LuckLevel = 0,
}
BetaConfig.PurchasesKept = 200

-- Round 6 (R-03): false in the published beta, so every Robux button says "Coming soon" and no prompt opens. In Studio,
-- prompts are free test purchases and open whatever this says. Adam turns it on only after Brian L's server owns the
-- grants (brief section 0 item 6). The CarHopBeta attribute of the same name overrides it (beta.project.json).
BetaConfig.RealPurchases = false
BetaConfig.OwnedAttribute = "BetaOwned" -- Player: "vip,double-lap-pay" (read only; the server writes it)
BetaConfig.StaminaAttribute = "BetaStaminaLevel" -- Player: the saved StaminaLevel (read only; the server writes it)
BetaConfig.LuckAttribute = "BetaLuckLevel" -- Player: the saved LuckLevel (read only; the server writes it)
-- Player: true when PolicyService says paid random items are restricted for this player (the Lucky Clover BUY is then replaced by
-- "Not available for your account"); nil while the check is running. Read only; the server writes it.
BetaConfig.LuckRestrictedAttribute = "BetaLuckRestricted"
BetaConfig.LineupAttribute = "BetaLineup" -- Player: the Lineup as "Putter,Minnow" (read only; the server writes it)
BetaConfig.CashAttribute = "BetaCash" -- Player: the saved Cash (read only; the server writes it)
BetaConfig.WorldsAttribute = "BetaWorldsUnlocked" -- Player: "Downtown,DustyHighway" (read only)
-- Player: the Cars field as "Putter:1:0,Minnow:2:12" (id:edition:copies), read only, for the Garage and the Lineup panel
BetaConfig.CarsAttribute = "BetaCars"
-- Player: the Welcome back credit already paid on this load (number), and the seconds away it covers. Set once on load,
-- after the credit is in the save; the card only reads them and never asks for a payment.
BetaConfig.WelcomeAmountAttribute = "BetaWelcomeAmount"
BetaConfig.WelcomeSecondsAttribute = "BetaWelcomeSeconds"
-- Round 7 (P-01): the seconds the credit counts (the time away, capped at 24 h, or 30 h with VIP), for the card
BetaConfig.WelcomeCappedAttribute = "BetaWelcomeCapped"
-- Studio-only cheat (L-07): the SERVER sets this Player attribute to a number from the command bar; the beta adds it to Cash
-- and clears it. A client cannot set it (client-made attributes never replicate), and outside Studio it is ignored.
BetaConfig.GrantCashAttribute = "BetaGrantCash"
-- CarHopBeta attribute: true makes purchases free again (the old beta mode, for testing). Default false.
BetaConfig.FreePurchasesAttribute = "FreePurchases"
-- Player attribute (true while the tutorial holds the tutorial run's claims in the Garage instead of auto-parking them).
BetaConfig.HoldClaimsAttribute = "BetaHoldClaims"
-- Plot attributes for the Lap Pay clock (src/shared/UI/LapClock): the server time slot phases count from, and the lap length.
BetaConfig.LapEpochAttribute = "BetaLapEpoch"
BetaConfig.LapSecondsAttribute = "BetaLapSeconds"
-- Round 7 (A-04): CarHopBetaNet attribute, the RICHEST RACERS board: "userId|displayName|cash;..." for the top ten Cash totals of
-- the players in THIS server (no cross-server data), highest first, ties by lower UserId. Read only; the server writes it.
BetaConfig.RichestAttribute = "RichestRacers"
BetaConfig.RichestRows = 10
-- Round 7 (A-03, decision 0042 item 5): the Stunt Circuit is "Coming soon". Its gate is closed and the server refuses every
-- Circuit event while this is false. Its screens stay in the code, switched off.
BetaConfig.CircuitOpen = false

-- Attributes the server sets. Plot: Owner (UserId), OwnerDisplayName, SpeedwayLevel, ParkingSpots
-- (the names Lane 3's Raceway looks already read). Player: HomePlot (plot number).
BetaConfig.HomePlotAttribute = "HomePlot"
BetaConfig.TutorialDoneAttribute = "TutorialDone" -- Player: nil until the save has loaded, then true or false

function BetaConfig.enabled(): boolean
	return ReplicatedStorage:FindFirstChild(BetaConfig.MarkerName) ~= nil
end

-- Whether Robux buttons may prompt outside Studio (R-03): the CarHopBeta attribute RealPurchases, else the default above.
function BetaConfig.realPurchases(): boolean
	local marker = ReplicatedStorage:FindFirstChild(BetaConfig.MarkerName)
	local value = marker and marker:GetAttribute("RealPurchases")
	return if type(value) == "boolean" then value else BetaConfig.RealPurchases
end

-- "Putter:1:0,Minnow:2:12" <-> { [id]: { Edition, Copies } }. Ids never contain ":" or "," (RosterFixtures model names).
function BetaConfig.encodeCars(cars: { [string]: { Edition: number, Copies: number } }): string
	local ids = {}
	for id in cars do
		table.insert(ids, id)
	end
	table.sort(ids)
	local parts = {}
	for _, id in ids do
		local c = cars[id]
		table.insert(parts, string.format("%s:%d:%d", id, c.Edition, c.Copies))
	end
	return table.concat(parts, ",")
end

function BetaConfig.decodeCars(text: any): { [string]: { Edition: number, Copies: number } }
	local out = {}
	if type(text) ~= "string" then
		return out
	end
	for id, edition, copies in string.gmatch(text, "([^:,]+):(%d+):(%d+)") do
		out[id] = { Edition = tonumber(edition) :: number, Copies = tonumber(copies) :: number }
	end
	return out
end

function BetaConfig.splitList(text: any): { string }
	local out = {}
	if type(text) == "string" then
		for item in string.gmatch(text, "[^,]+") do
			table.insert(out, item)
		end
	end
	return out
end

return BetaConfig
