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
}

-- ProfileStore store and template. A beta-only store, so the real game's saves start clean.
BetaConfig.StoreName = "CarHopBeta1"
BetaConfig.Template = {
	RacewayLevel = 1,
	ParkingSpots = 2,
	TutorialDone = false, -- Adam, 2026-11-02: the tutorial is for first-time players only
}

-- Attributes the server sets. Plot: Owner (UserId), OwnerDisplayName, SpeedwayLevel, ParkingSpots
-- (the names Lane 3's Raceway looks already read). Player: HomePlot (plot number).
BetaConfig.HomePlotAttribute = "HomePlot"
BetaConfig.TutorialDoneAttribute = "TutorialDone" -- Player: nil until the save has loaded, then true or false

function BetaConfig.enabled(): boolean
	return ReplicatedStorage:FindFirstChild(BetaConfig.MarkerName) ~= nil
end

return BetaConfig
