--!strict
-- Remote names for the economy PREVIEW (Lane 2). The server creates them under
-- ReplicatedStorage.EconomyPreviewNet. They take no arguments: the client asks, the server
-- decides the price and the result. The real remotes are the proposal in
-- vault/design/specs/economy-v1.md section 13 and need "Agreed" from all three lanes.

local EconomyPreviewNet = {}

EconomyPreviewNet.FolderName = "EconomyPreviewNet"

EconomyPreviewNet.Remotes = {
	BuyRacewayLevel = "BuyRacewayLevel",
	BuyParkingSpot = "BuyParkingSpot",
}

return EconomyPreviewNet
