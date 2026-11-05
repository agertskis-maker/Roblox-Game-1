--!strict
-- CAR HOP BETA 1 (Adam approved on 2026-10-31: one place, may save, may be incomplete). Shared names
-- for the beta glue. Every beta script is off unless ReplicatedStorage.CarHopBeta exists; only
-- beta.project.json creates it, so default.project.json (the team's game) is unchanged.
-- Stand-ins, not Lane 2's contracts: the save fields, the remotes and the free purchases here are
-- replaced by Brian L's real economy and save layout (vault/decisions/0030-car-hop-beta-1.md).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BetaConfig = {}

BetaConfig.MarkerName = "CarHopBeta"
BetaConfig.NetName = "CarHopBetaNet"
BetaConfig.Remotes = {
	BuyRacewayLevel = "BuyRacewayLevel", -- no arguments: the server raises the caller's own Raceway by one
	BuyParkingSpot = "BuyParkingSpot", -- no arguments: the server adds one spot to the caller's own Paddock
	TutorialDone = "TutorialDone", -- no arguments: the server remembers the caller finished or skipped the tutorial
	-- (slot: integer, carId: string?): BETA STAND-IN for Brian L's agreed remote of the same name and arguments (decision
	-- 0036). Puts one of the caller's own cars in one of the caller's own Paddock slots, or takes it out (carId nil).
	SetLineupSlot = "SetLineupSlot",
}

-- ProfileStore store and template. A beta-only store, so the real game's saves start clean.
BetaConfig.StoreName = "CarHopBeta1"
BetaConfig.Template = {
	RacewayLevel = 1,
	ParkingSpots = 2,
	TutorialDone = false, -- Adam, 2026-11-02: the tutorial is for first-time players only
	-- Round 4: two of the AGREED save fields (economy v1 section 13, decision 0036), with their agreed start values: the
	-- Downtown Loaner, Normal, 0 copies, and the Loaner in the Lineup. No other field is added.
	Cars = { Putter = { Edition = 1, Copies = 0 } },
	Lineup = { "Putter" },
}
BetaConfig.LineupAttribute = "BetaLineup" -- Player: the Lineup as "Putter,Minnow" (read only; the server writes it)

-- Attributes the server sets. Plot: Owner (UserId), OwnerDisplayName, SpeedwayLevel, ParkingSpots
-- (the names Lane 3's Raceway looks already read). Player: HomePlot (plot number).
BetaConfig.HomePlotAttribute = "HomePlot"
BetaConfig.TutorialDoneAttribute = "TutorialDone" -- Player: nil until the save has loaded, then true or false

function BetaConfig.enabled(): boolean
	return ReplicatedStorage:FindFirstChild(BetaConfig.MarkerName) ~= nil
end

return BetaConfig
