--!strict
-- BETA-ONLY STAND-IN for Brian L's EconomyPreviewNet (src/shared/Net/EconomyPreviewNet.luau, feature/lane2-economy-preview).
-- Same contract: his run remote names, in a folder with his name. Delete when his real module lands.
--
-- Round 6 (E-04, Adam's decision of 2026-11-05, brief section 0 item 3): ONE run contract. Brian L owns the remotes, so his
-- names win: StartRun, RunEvents, KeysComplete, RunGranted, under ReplicatedStorage.EconomyPreviewNet. Lane 3 never edits
-- src/shared/Net, so the beta copies the names here. The beta server makes these remotes only when his server is not
-- running (his server makes the same folder itself).
--
--   StartRun      RemoteFunction  (worldId: string, startCarId: string?) -> { runId: string, seed: number }?
--   RunEvents     RemoteEvent     (runId: string, events: { Event })   note 0021 shape, about once a second
--   KeysComplete  RemoteEvent     (runId: string, event: Event)        sent at once; the beta also takes (runId, index)
--   RunGranted    RemoteEvent     server -> client only: (runId, grant)
--
-- The Round 5 names (BetaRunStart, BetaRunEvents, BetaKeysComplete, BetaRunGranted in CarHopBetaNet) are still accepted
-- for Round 6 only, and the first use of one logs a deprecation line once per server. Round 7 deletes them.
-- BetaRunEnd and BetaRunResults stay beta-only: Brian L's contract has no "close the run and send the totals" remote yet.

local BetaRunNet = {}

BetaRunNet.FolderName = "EconomyPreviewNet"
BetaRunNet.Remotes = table.freeze({
	StartRun = "StartRun",
	RunEvents = "RunEvents",
	KeysComplete = "KeysComplete",
	RunGranted = "RunGranted",
})
-- new name -> the Round 5 name it replaces (accepted for one round)
BetaRunNet.Deprecated = table.freeze({
	StartRun = "BetaRunStart",
	RunEvents = "BetaRunEvents",
	KeysComplete = "BetaKeysComplete",
	RunGranted = "BetaRunGranted",
})

return table.freeze(BetaRunNet)
