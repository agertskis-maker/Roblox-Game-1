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
> Drafted by Claude Code for Adam (Lane 3) on 2026-10-20. It is not an approved shared interface. Shared contracts change only when all three lanes agree ([[0007-concept-car-hop-and-lanes]]). Decision draft: [[draft-plot-marker-contract]]. No existing plot contract was found on `main` or `feature/lane3-first-car-downtown` on 2026-10-20.

## Purpose
Lane 3 builds the island and places the markers. Lane 2's server code reads them to give a joining player a plot, spawn them at its gate, and later drive Lineup visuals and bays. This note fixes names, classes, transforms and who may change what, so neither lane has to guess.

## Hierarchy
```
Workspace
└─ Island                       Model    production root (the private preview builds the same tree under Workspace.Lane3_IslandPreview)
   ├─ Plots                     Folder
   │  └─ Plot01 … Plot12        Model    the name is the stable ID
   │     ├─ Markers             Part     invisible anchor that holds every marker Attachment
   │     │  ├─ GateSpawn        Attachment
   │     │  ├─ NameplateAnchor  Attachment
   │     │  ├─ Speedway         Attachment  (parametric path definition)
   │     │  ├─ Path001 … Path050 Attachment  (ordered samples of the same path)
   │     │  ├─ Bay01 … Bay15    Attachment
   │     │  ├─ PitIn01 … PitIn04, PitOut01 … PitOut04  Attachment  (ordered lane points, visual guidance)
   │     └─ Visual              Folder   cosmetic geometry
   ├─ Plaza                     Model    shared destinations (visual; their own markers come later)
   └─ Scenery                   Model    landscape, shoreline, water dressing
```

## Classes, names and attributes
| Instance | Class | Attributes (type) | Notes |
|---|---|---|---|
| `Island` | Model | `ContractVersion` (string, `"0-draft"`), `LayoutVersion` (string), `PlotCount` (number, 12), `SurfaceY` (number) | pivot at the island centre on the walking surface |
| `Plots` | Folder | none | contains exactly the plot models, nothing else |
| `PlotNN` | Model | `PlotIndex` (number 1 to 12), `BearingDeg` (number) | `NN` is two digits. Index and name never change with owner or colour |
| `Markers` | Part | none | Anchored, Transparency 1, CanCollide, CanQuery and CanTouch false, Size 1 x 1 x 1, CFrame = the plot frame (below) |
| `GateSpawn` | Attachment | none | WorldCFrame on the walking surface at the gate; LookVector toward the plaza centre |
| `NameplateAnchor` | Attachment | none | centre of the nameplate face; LookVector out of the face toward the plaza |
| `Speedway` | Attachment | `TurnRadius`, `StraightLength`, `PathLength`, `TrackWidth` (numbers), `Direction` (string, `"CounterClockwise"` seen from above) | at the oval centre on the track surface; LookVector along the long axis, outward |
| `PathNNN` | Attachment | `PathIndex` (number), `Distance` (number, studs from the start line) | `Path001` is the start line; travel order; closed loop (`Path050` returns to `Path001`); LookVector = travel direction |
| `BayNN` | Attachment | `BayIndex` (number 1 to 15), `Row` (string `"A"` or `"B"`), `Initial` (boolean, true only for Bay01 to Bay03) | bay centre on the paddock surface; LookVector = a parked car's forward (toward the aisle) |
| `PitInNN`, `PitOutNN` | Attachment | `LaneIndex` (number) | ordered points; In leaves the right straight for the aisle, Out joins the left straight |

Instance references are by stable name, never as attributes. If Lane 2 later needs a reference to be stored, it uses an ObjectValue.

## Coordinate system
- World studs, +Y up. North is -Z (Roblox's default forward); bearings are measured clockwise from north, toward +X.
- `PlotNN` sits on bearing `15 + 30 x (NN - 1)` degrees, numbered clockwise.
- Plot frame (`Markers.CFrame`): origin at the gate centre on the walking surface; LookVector toward the plaza centre; UpVector +Y.
- Consumers read `Attachment.WorldCFrame` and never derive positions from bearings themselves; the bearings are documentation.

## Spawn
`GateSpawn` is a marker, not a SpawnLocation; nothing spawns a player there by itself. Proposal for Brian L: on `CharacterAdded`, the server pivots the character to `GateSpawn.WorldCFrame` raised by the character's hip height, facing the plaza. The alternative is twelve non-neutral SpawnLocations driven by `Player.RespawnLocation`; neutral SpawnLocations would put players at random plots. Lane 2 chooses; Lane 3 adds SpawnLocations only if asked.

## Speedway path
- `PathLength` 250, `TurnRadius` 13, `StraightLength` 84.16, `TrackWidth` 11 (layout option A). The parametric attributes are authoritative; the 50 samples (about 5 studs apart) are a convenience derived from them.
- Direction counter-clockwise from above. The start line is mid-way along the left straight (seen from the gate, looking outward), with cars heading toward the plaza.
- A path marker is geometry only. It is not driving behaviour, speed, lap timing or Lap Pay, which belong to Lanes 1 and 2.

## Bays
- Fifteen bays per plot, always present as markers. `Initial = true` marks the three shown from the start (Bay01 to Bay03, the row A centre). Bays 04 to 15 are reserved space, not visible slots, prices or an entitlement.
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
| Names, classes, attribute names and types, plot count, bay count and order, path direction and start, coordinate conventions | shared | all-lane agreement, `ContractVersion` bump |
| Marker transforms, `PathLength`, plot bearings, bay spacing | Lane 3, with notice | tell Lane 2 before merging; bump `LayoutVersion` |
| Plot assignment, spawning, Lineup and bay state, any runtime attributes | Lane 2 | Lane 2's code; proposal: the server may write `OwnerUserId` (number) on `PlotNN` for the nameplate to read. The preview writes no ownership or saved state |

## Read-only example (Lane 2, server)
```lua
--!strict
local island = workspace:FindFirstChild("Island")
assert(island, "Workspace.Island is missing")
local plots = island:FindFirstChild("Plots") :: Folder
local plot = plots:FindFirstChild("Plot07") :: Model
local markers = plot:FindFirstChild("Markers") :: BasePart

local spawnCFrame = (markers:FindFirstChild("GateSpawn") :: Attachment).WorldCFrame

local bays: { Attachment } = {}
for index = 1, 15 do
	bays[index] = markers:FindFirstChild(string.format("Bay%02d", index)) :: Attachment
end
local initialBays = { bays[1], bays[2], bays[3] }
```

## Open questions for Brian L
1. Spawn by pivoting to `GateSpawn`, or SpawnLocations per plot?
2. Should the server publish `OwnerUserId` on `PlotNN`, or keep assignment only in its own state and send the client what it needs?
3. Does Lap Pay timing need the parametric path, the samples, or neither (server timer only)?
4. Is 15 the right reserved bay count, given that the pass is unapproved and Slots are Tunable?
5. Who builds the production island into the shared place, and when (the integration person is still TBD)?
6. Does anything need the markers on the client under StreamingEnabled?
