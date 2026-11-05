--!strict
-- Remote names for the economy PREVIEW (Lane 2). The server creates them under
-- ReplicatedStorage.EconomyPreviewNet. The client asks; the server decides every price, amount
-- and result and checks every argument. The real remotes are the proposal in
-- vault/design/specs/economy-v1.md section 13 and need "Agreed" from all three lanes.
--
--   BuyRacewayLevel   RemoteEvent     no arguments
--   BuyParkingSpot    RemoteEvent     no arguments
--   BuyLuckLevel      RemoteEvent     no arguments
--   UnlockWorld       RemoteEvent     worldId: string
--   SetLineupSlot     RemoteEvent     slot: number, carId: string? (nil takes the car out)
--   StartRun          RemoteFunction  worldId: string -> { runId: string, seed: number, luck: number }?
--                                     (build the run with RunSequence.new(seed, profile, luck))
--   RunEvents         RemoteEvent     runId: string, events: { Event } (decision 0021 shape)
--   KeysComplete      RemoteEvent     runId: string, event: Event (sent at once, not batched)
--   RunGranted        RemoteEvent     server -> client only: what a run event paid

local EconomyPreviewNet = {}

EconomyPreviewNet.FolderName = "EconomyPreviewNet"

EconomyPreviewNet.Remotes = {
	BuyRacewayLevel = "BuyRacewayLevel",
	BuyParkingSpot = "BuyParkingSpot",
	BuyLuckLevel = "BuyLuckLevel",
	UnlockWorld = "UnlockWorld",
	SetLineupSlot = "SetLineupSlot",
	StartRun = "StartRun",
	RunEvents = "RunEvents",
	KeysComplete = "KeysComplete",
	RunGranted = "RunGranted",
}

return EconomyPreviewNet
