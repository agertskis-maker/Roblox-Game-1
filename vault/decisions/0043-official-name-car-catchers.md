# 0043: Official game name is Car Catchers (proposed)

Date: 2026-11-08. Proposed by: Brian L (Lane 2).
Status: **Proposed. Needs Adam's agreement**, because decision 0037 (Adam, 2026-11-03) set the name to Catch A Car!. Until Adam agrees, 0037 stands on `main`.

Brian L's words: "the name is Car Catchers, rename everything in the game that is not that to be that, this is the new official name of the game, Car Catchers".

If agreed:
- The official player-facing name is **Car Catchers**. Logo typography may read **CAR CATCHERS**.
- It replaces Catch A Car! (0037), which replaced the working title Car Hop.
- As in 0037: repository and folder paths, file names, place IDs, package names, remote names, internal identifiers (`CarHopBeta`, `CarHopBetaNet`, ...) and save-store keys stay unchanged. A display-name change must not create a new player-data store or break Rojo mappings.
- Game verbs stay ("Catch a car you already have."): they describe the action, not the name.

Applied on branch `feature/lane2-luck-in-beta` (2026-11-08), player-facing text only:
- Loading screen wordmark: CAR CATCHERS (`src/client/UI/Loading/LoadingScreen.luau`).
- Launch Pad title band: CAR CATCHERS (`src/client/UI/LaunchPad/PadParts.luau`).
- Run road boards: CAR CATCHERS and CAR CATCHERS CIRCUIT (`src/client/Run/RunRoad.luau`, Brian R's file).
- Island fountain statue: two big CAR CATCHERS signs facing the spawn and the portals (`src/island/Hub/Environment/ParkDressing.luau`).

Not changed: the published Roblox experience name and description, the Figma file name, older vault records and screenshots, comments in code. Name availability or legal clearance is not established.
