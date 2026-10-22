# Downtown B city grammar (Lane 3 preview)

Private look-development harness for Downtown direction B (ledger
`vault/design/specs/hud-rebuild-downtown-b.md`, IDs D-02, D-04..D-06, D-08..D-12, D-17, D-20).
Not game content: `default.project.json` never maps `src/lookdev`, and every entry point
asserts Roblox Studio. Lane 1 (Brian R) owns roads, segments, lanes, hazards as gameplay, the run
camera and streaming; every number here is a PREVIEW value for him to accept or change.

## Files

| File | Role |
|---|---|
| `init.luau` | Entry: command-bar API (one default city) and `City.new(...)` for embedding |
| `Catalog.luau` | Districts, palettes, lot modules, landmarks, props, sign family; built-in fallback, merged with the B2 kit manifest when present |
| `Route.luau` | Pure geometry: segment frames, sockets, per-side arc-length maps |
| `Sequencer.luau` | Pure deterministic planner: `plan(seed, options)`, `describe(plan)`, `check(plan)`, `boundaries(plan)` |
| `Assembler.luau` | Builds a plan in a bounded active window with pooling; stats; client-safe |
| `Proxies.luau` | Part-built proxies for every module whose mesh is missing |
| `Chase.luau` | Deterministic chase harness with two labelled cameras and frame-time sampling |
| `RoadWidthStudy.luau` | Lane widths 12.5 / 16 / 17 / 18 side by side with fixture car footprints |
| `StreetLife.luau` | Pigeons, flags, cart steam, birds, blimp: bounded, off-road, reduced-motion aware |
| `Traffic.luau` | A few proxy cars in lanes for scale, with subtle exhaust |
| `Cars.luau` | Fixture car footprints and proxy models (HUD prototype ProxyCar when mapped) |
| `Util.luau` | Reduced motion, GUI parent, frame-time summary |

## Command bar (Studio edit mode, Downtown look-dev place)

```lua
local City = require(game.ReplicatedStorage.LookDev.Downtown.City)
City.run({ seed = 2207, length = 2400 })  -- plan, build, print the sequence, start the chase
City.build({ seed = 2207 })               -- plan and build, camera at s 0
City.plan({ seed = 9 })                   -- plan only: prints the sequence and the checks
City.chase({ camera = "HIGH" })  City.stop()  City.pause()  City.resume()
City.camera("FIXTURE")   City.frame(1450)   City.sample(20)   -- sample yields, prints JSON
City.widthStudy()   City.stats()   City.describe()   City.boundaries()
City.reset()   City.reset({ lighting = true })   -- the second also restores the place lighting
```

A stale module copy: Studio may cache the command bar's `require`. `City.reset()` removes the
city by name, so `require(...City:Clone())` is safe after a resync.

In Play (client), the playground bootstrap takes `city run|sample|stats|stop|camera|frame|width|reset`
through the `LookDevCommand` marker attribute (see `LookDevPlayground.client.luau`).

## Embedding (HUD playground backdrop, client in Play)

```lua
local City = require(ReplicatedStorage.LookDev.Downtown.City)
local city = City.new({
	parent = folder,                                  -- where Lane3_DowntownCity is created
	kit = ReplicatedStorage.Lane3_DowntownKitB2,      -- mesh JSON (ModuleScripts or StringValues)
	kitData = ReplicatedStorage.Lane3_DowntownKitB2Data, -- optional manifest / swatches
	seed = 2207,
	preview = true,          -- explicit opt-in (otherwise a Lane3Playground marker is required)
	lighting = false,        -- keep the HUD place's lighting (default true: B daylight)
	controlCamera = true,    -- false: drive the window yourself with city:setStation(s)
})
city:build()       -- yields while kit templates are made
city:chase()       -- async; or city:setStation(s) each frame
city:sample(20)    -- frame times + all stats (yields)
city:stats()  city:destroy()
```

## Contract and conventions

- Road frame: +X right, travel toward -Z, ground y = 0, centre line x = 0. `s` = distance
  along the centre line (studs), `d` = offset to the right.
- Segments: Straight 96 / 192, CurveL / CurveR (radius 360, 16 degrees, arc 100.53),
  Intersection 96 (30-wide cross street at u 48; no frontage within 27 of its centre),
  BridgeDeck 192 (straight), Transition 96 (district gateway glue). Start socket at the
  origin facing -Z; end socket `Route.localFrame(bend, 360, length, 0, 0)`. Road meshes are
  named `B2_Road_<Kind><length>_L4W17` (curves `B2_Road_CurveL_L4W17`); a mesh whose
  `meta.sockets.end` disagrees with the contract by more than 0.5 stud is listed in
  `stats().assembler.socketMismatches`.
- Road width: 4 lanes x 17 (PREVIEW, reversible; see the width study) + 2 x 4 shoulders =
  76; sidewalk 12 from the road edge (kerb 0.8 inside it); frontage line 50 from the centre.
- Lots: facade faces local -Z, footprint x 0..width, z 0..depth, pivot = the front-left
  corner (the building's own left). Widths 24 / 36 / 48, depth up to 24, height classes low /
  mid / tall. Kit lot meshes are FITTED by their bounds (centred in the slot, front face on the
  frontage line), so only their facing matters: `meta.facing` = "-Z" (default), "+X", "-X"
  or "+Z". Corner lots come as separate L and R variants (mirroring = choosing the variant,
  never rotating); a lot's facade always faces the road.
- Courtyard lots set back 8 / 12 / 16 with a paved forecourt; pocket parks and corner plazas
  are treatments every few lots. Bands: frontage 0-25 from the road edge, midground masses
  60-140, skyline blocks 300-900.
- Mesh names follow `B2_<family>_<variant>` (`B2_Lot_Shop24_brick`, `B2_Lot_Corner24L_stone`,
  `B2_LM_Theater`, `B2_Furn_Lamp`). Anything missing becomes a labelled proxy, so the lead
  can rerun as the kit lands: `City.build()` picks up whatever subset exists.

## Seed, determinism and checks

One `Random.new(seed)` stream drives every choice in route order; default seed 2207. The same
seed, options and catalogue give the same plan (the B2 manifest adds modules, so the plan with
and without the kit differs). Districts repeat Main Street -> City Hall -> Harbor Bridge ->
Midtown -> Skyline Park with fixture targets 528 / 576 / 528 / 624 / 672 studs; the realised
boundary table is `City.boundaries()` (studs plus PROVISIONAL metres) for the HUD strip. With
`completeDistrict` (default) the route ends at the first boundary at or after `length`, so the
default route shows all five districts (about 3,000 studs). `describe()` prints the seed, the
boundaries, the segment and lot sequences, landmarks, signs, spans and the check results
(immediate repeats, identical left/right pairs, palette and orientation violations, landmark
spacing and conflicts, segment join error).

## Active window

The window keeps 1 segment behind and 6 ahead (skyline masses 2 behind, 14 ahead; ground tiles
3 x 3 cells of 2,000 around the camera and 1,200 ahead). Leaving items go to a pool keyed by
module (nil-parented, never rendered) and are reused; up to 300 items are placed per step
during a chase. `stats()` reports live, pooled, created, reused and released items, unique
meshes, triangles placed, EditableMesh count and an estimated EditableMesh memory.

## Fixture / provisional values

Chase cameras FIXTURE (12 behind, 6 up, look 20, FOV 70) and HIGH (18 behind, 10 up, look 24,
FOV 75); speed 70 studs/s; lane 2; span clearance 26; landmark spacing 500-700; hazard
previews (scenery only); 1 stud = 0.28 m is PROVISIONAL and only ever shown as such.

## Limits and risks

EditableMesh: 20,000 triangles / 60,000 vertices per mesh, a per-device memory budget
(`CreateEditableMesh` can return nil; handled as a proxy), session-only content, and published
games need the Mesh / Image API setting. The preview builder caps templates at 160
(`maxEditableMeshes`). Production scenery should be uploaded MeshParts (see the research note
`vault/design/research/modular-city-composition.md`).
