---
title: Plot-marker contract (draft)
tags:
  - design
  - contract
  - island
status: draft
---

# Plot-marker contract (DRAFT, not agreed)

> [!warning] Proposal for Brian L (Lane 2)
> Drafted by Claude Code for Adam (Lane 3) on 2026-10-20; revision 2 the same day for eight plots. It is not an approved shared interface. Shared contracts change only when all three lanes agree ([[0007-concept-car-hop-and-lanes]]). Decision draft: [[draft-plot-marker-contract]]. No existing plot contract was found on `main` or `feature/lane3-first-car-downtown` on 2026-10-20.

> [!note] For Brian L: eight plots, one config value
> Adam decided on 2026-10-20 that the island has **8 plots** and a server holds at most 8 players ([[0011-eight-plots-per-server]]); this supersedes the outline's 12. The count lives in one place, the `PlotCount` attribute on `Workspace.Island`. Lane 2 code reads it and never hard-codes 8 (or 12), so a later change of count is a layout change, not a Lane 2 code change.

## Purpose
Lane 3 builds the island and places the markers. Lane 2's server code reads them to give a joining player a plot, spawn them at its gate, and later drive Lineup visuals and bays. This note fixes names, classes, transforms and who may change what, so neither lane has to guess.

## Hierarchy
```
Workspace
└─ Island                       Model    production root (the private preview builds the same tree under Workspace.Lane3_IslandPreview)
   ├─ Plots                     Folder
   │  └─ Plot01 … PlotNN        Model    NN = 01 to PlotCount; the name is the stable ID
   │     ├─ Markers             Part     invisible anchor that holds every marker Attachment
   │     │  ├─ GateSpawn        Attachment
   │     │  ├─ NameplateAnchor  Attachment
   │     │  ├─ Speedway         Attachment  (path summary)
   │     │  ├─ Path001 … PathNNN Attachment (ordered samples of the lap path; NNN = PathSampleCount)
   │     │  ├─ Bay01 … Bay15    Attachment
   │     │  ├─ PitIn01 … PitIn04, PitOut01 … PitOut04  Attachment  (ordered lane points, visual guidance)
   │     └─ Visual              Folder   cosmetic geometry
   ├─ Plaza                     Model    shared destinations (visual; their own markers come later)
   └─ Scenery                   Model    landscape, shoreline, water dressing
```

## Classes, names and attributes
| Instance | Class | Attributes (type) | Notes |
|---|---|---|---|
| `Island` | Model | `ContractVersion` (string, `"0-draft"`), `LayoutVersion` (string), **`PlotCount` (number, 8)**, `SurfaceY` (number) | pivot at the island centre on the walking surface. `PlotCount` is the only source of the plot count |
| `Plots` | Folder | none | contains exactly `PlotCount` plot models, nothing else |
| `PlotNN` | Model | `PlotIndex` (number 1 to `PlotCount`), `BearingDeg` (number) | `NN` is two digits. Index and name never change with owner or colour |
| `Markers` | Part | none | Anchored, Transparency 1, CanCollide, CanQuery and CanTouch false, Size 1 x 1 x 1, CFrame = the plot frame (below) |
| `GateSpawn` | Attachment | none | WorldCFrame on the walking surface at the gate; LookVector toward the plaza centre |
| `NameplateAnchor` | Attachment | none | centre of the nameplate face on the gate arch; LookVector out of the face toward the plaza |
| `Speedway` | Attachment | `PathLength`, `TrackWidth`, `MinTurnRadius`, `PathSampleCount` (numbers), `Direction` (string, `"CounterClockwise"` seen from above) | on the track surface at the start line; LookVector = travel direction |
| `PathNNN` | Attachment | `PathIndex` (number), `Distance` (number, studs from the start line) | `Path001` is the start line; travel order; closed loop (the last sample returns to `Path001`); LookVector = travel direction |
| `BayNN` | Attachment | `BayIndex` (number 1 to 15), `Row` (string `"A"` or `"B"`), `Initial` (boolean, true only for Bay01 to Bay03) | bay centre on the Paddock surface; LookVector = a parked car's forward, away from the aisle (cars back in, show-room style) |
| `PitInNN`, `PitOutNN` | Attachment | `LaneIndex` (number) | ordered points; In leaves the right side straight for the aisle's right end, Out leaves the aisle's left end onto the left side straight |

Instance references are by stable name, never as attributes. If Lane 2 later needs a reference to be stored, it uses an ObjectValue.

## Coordinate system
- World studs, +Y up. North is -Z (Roblox's default forward); bearings are measured clockwise from north, toward +X.
- `PlotNN` sits on bearing `(360 / PlotCount) x (NN - 0.5)` degrees, numbered clockwise. With 8 plots: 22.5, 67.5, … 337.5.
- Plot frame (`Markers.CFrame`): origin at the gate centre on the walking surface; LookVector toward the plaza centre; UpVector +Y.
- Consumers read `Attachment.WorldCFrame` and never derive positions from bearings themselves; the bearings are documentation.

## Spawn
`GateSpawn` is a marker, not a SpawnLocation; nothing spawns a player there by itself. Proposal for Brian L: on `CharacterAdded`, the server pivots the character to `GateSpawn.WorldCFrame` raised by the character's hip height, facing the plaza. The alternative is one non-neutral SpawnLocation per plot driven by `Player.RespawnLocation`; neutral SpawnLocations would put players at random plots. Lane 2 chooses; Lane 3 adds SpawnLocations only if asked.

## Server size
The place's Max Players setting is set when the place is published (not by Rojo). It must not exceed `PlotCount`, or a ninth player would have no plot. Proposal: Lane 2's server compares `Players.MaxPlayers` with `PlotCount` at start-up and logs a warning on a mismatch.

## Speedway path
- Layout revision 2 (computed, built in Stage A): `PathLength` 427.1, `TrackWidth` 16, `MinTurnRadius` 30 (the hairpin is 35), `PathSampleCount` 86 (about 5 studs apart). The samples are authoritative for the shape; `PathLength` is their exact total.
- Shape: a teardrop circuit with a hairpin right behind the gate, two side straights, two back corners and a gentle back sweeper ([[island-base]]).
- Direction counter-clockwise from above. The start line is two thirds along the left side straight (seen from the gate, looking outward), just before the hairpin, with cars heading toward the plaza.
- A path marker is geometry only. It is not driving behaviour, speed, lap timing or Lap Pay, which belong to Lanes 1 and 2.
- Later Speedway tiers (not approved) may change the lap path. Proposal: each tier then publishes its own path set, decided with the tiers.

## Bays
- Fifteen bays per plot, always present as markers, in the Paddock in the Speedway infield. `Initial = true` marks the three shown from the start (Bay01 to Bay03, the centre of row A, nearest the viewing bridge). Bays 04 to 15 are reserved space, not visible slots, prices or an entitlement.
- Fill order: Bay01 row A centre; Bay02, Bay03 either side; Bay04 to Bay07 outward in row A; Bay08 to Bay15 row B from the centre outward, alternating sides.
- How many bays a player has, and which are shown, is Lane 2 state. Lane 3 draws bays 4 to 15 only when told the Slot count.

## Runtime availability
- Production (proposed): Lane 3 builds the island into the shared place's Workspace from the Git recipes, and it is saved with the place, so `Workspace.Island` exists on the server before any script runs. The Rojo mapping does not cover Workspace. This needs the integration person and Brian L's agreement; nothing is integrated now.
- The private preview builds the same tree under `Workspace.Lane3_IslandPreview` in `CarHop-Island-Test.rbxl` only. A client-only preview would not be visible to the server; the edit-time preview build is, but only inside that private place.
- StreamingEnabled: the server always has every plot; clients may not have distant plots streamed in. Client code should not depend on streamed markers. Whether plot models need a persistent streaming mode is open.

## Ownership
| Item | Owner | Change rule |
|---|---|---|
| Geometry, marker placement, `Visual` contents | Lane 3 | `Visual` changes freely |
| Plot count | Adam decided 8 ([[0011-eight-plots-per-server]]) | changes only by decision; Lane 3 updates `PlotCount` and the layout, bumps `LayoutVersion`; no Lane 2 code change needed |
| Names, classes, attribute names and types, bay count and order, path direction and start, coordinate conventions | shared | all-lane agreement, `ContractVersion` bump |
| Marker transforms, `PathLength`, sample count, plot bearings, bay spacing | Lane 3, with notice | tell Lane 2 before merging; bump `LayoutVersion` |
| Plot assignment, spawning, Lineup and bay state, any runtime attributes | Lane 2 | Lane 2's code; proposal: the server may write `OwnerUserId` (number) on `PlotNN` for the nameplate to read. The preview writes no ownership or saved state |

## Read-only example (Lane 2, server)
```lua
--!strict
local island = workspace:FindFirstChild("Island")
assert(island, "Workspace.Island is missing")
local plotCount = island:GetAttribute("PlotCount")
assert(type(plotCount) == "number", "Island.PlotCount is missing")
local plots = island:FindFirstChild("Plots") :: Folder

for index = 1, plotCount do
	local plot = plots:FindFirstChild(string.format("Plot%02d", index)) :: Model
	local markers = plot:FindFirstChild("Markers") :: BasePart
	local spawnCFrame = (markers:FindFirstChild("GateSpawn") :: Attachment).WorldCFrame
	local bays: { Attachment } = {}
	for bayIndex = 1, 15 do
		bays[bayIndex] = markers:FindFirstChild(string.format("Bay%02d", bayIndex)) :: Attachment
	end
	local initialBays = { bays[1], bays[2], bays[3] }
	-- assignment and spawning are Lane 2's design; this only shows how to find the markers
end
```

## Open questions for Brian L
1. Spawn by pivoting to `GateSpawn`, or SpawnLocations per plot?
2. Should the server publish `OwnerUserId` on `PlotNN`, or keep assignment only in its own state and send the client what it needs?
3. Does Lap Pay timing need the path samples, `PathLength`, or neither (server timer only)?
4. Is 15 the right reserved bay count, given that the pass is unapproved and Slots are Tunable?
5. Who builds the production island into the shared place, and when (the integration person is still TBD)?
6. Does anything need the markers on the client under StreamingEnabled?
7. Should the server warn when `Players.MaxPlayers` exceeds `PlotCount`?
8. If later Speedway tiers change the lap path, how should each tier's path be published (a path set per tier)?
