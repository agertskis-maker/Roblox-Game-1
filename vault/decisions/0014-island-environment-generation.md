---
title: "0014: Island environment generation"
date: 2026-10-21
tags:
  - decision
  - island
  - terrain
  - lighting
status: accepted
---

# 0014: Island environment generation

> [!note] Accepted 2026-10-21 (Adam)
> "Approved: island environment with the changes below. Approved: continue dressing." with "Use Atmosphere A: Clear Alpine, bright daytime. This approval also accepts decision 0014." The note below is the one approved (same file, same title); the revision that follows (waterfall system, lake, vegetation) extends it and is recorded under "Revision" when it lands.

> [!note] Proposed with the environment review
> Written by Claude Code for Adam (Lane 3 owner) on 2026-10-21, with island rework Task 2, step 1. It records how the environment is generated and why. It is accepted with "Approved: island environment, continue dressing."; until then the method may change at the review.

## Decision
- **Smooth Terrain from a seeded height field**, not hand sculpting and not meshes. `src/island/Hub/Environment/Field.luau` (version `island-env-1`, seed 20261021) defines ridges as spines: a polyline with a height and a left and right flank width at every node, and a flank exponent (1.7 to 2.0 for the main peaks, 2.2 to 2.4 for foothills, so their lower slopes are gentle). Spines join through a smooth maximum that fills the crease where two ridges overlap but adds nothing over flat ground. Ridged noise roughens crests in proportion to height.
- **Gullies follow drainage**: 64 seeds below the crests trace steepest descent on the grid and carve a V that deepens mid-way and fades at the foot.
- **Materials by slope, height and water**: grass on gentle ground, rock (near) or slate (far, lighter) on steep faces, a grass and rock mix between, snow above a noisy snow line that reaches steeper ground the higher it is, sand lake bed, limestone banks and stream beds, ground under forest patches. The surface material runs three voxels deep.
- **Written with `Terrain:WriteVoxelChannels`** (solid material, solid occupancy, liquid occupancy) in 700 chunks of 64 x 64 studs inside one recorded box (x -880 to 880, y -24 to 360, z -760 to 780). Rebuilds clear only that box. The first build refuses to write if the box holds terrain it did not write.
- **The waterfall is a visual**, not terrain water: layered glass sheets in the cliff notch, two side sheets turned toward the end plots, streaks moved by the client, foam rings, and foam and mist particles with the built-in texture. The creek above and the plunge pool are terrain water.
- **Place-wide look**: terrain colours, water, Lighting, an Atmosphere, Clouds, a ColorCorrection and SunRays (named `Lane3_Env*`), and the existing Bloom. Every original value is saved on `Workspace.Lane3_IslandEnvironment` first, and `cleanup()` restores them. The existing ColorGrading effect is not changed. Two presets: ClearAlpine and SoftHaze.

## Why (and what was found)
- **Measured surface offset** (probe in Studio, 2026-10-21): over a full voxel, the rendered solid surface sits at the top voxel's bottom + 2 + 4 x occupancy. Occupancy computed straight from height drew every surface 2 studs high and buried the paths. Solid occupancy is taken from (height - 2); water renders at bottom + 4 x occupancy and needs no offset.
- **Material depth**: a half-filled grass voxel over a full rock voxel showed rock patches through the hub's grass; three voxels of surface material fixed it.
- **Sun to the north** (`GeographicLatitude` -30): players face south toward the range. With the sun in the south every face they see was in shadow.
- **`Enum.Material.Pebble` is not a terrain material** (GetMaterialColor fails); limestone is used for banks.
- **`Lighting.Technology` cannot be read or set from this context**, so it was left as it is; `Terrain.Decoration` does not exist in this Studio build.
- **Stream re-route**: the Task 1 stream met Avenue 2 at about 24 degrees and ran beside it, so terrain water would show under the paving. It now arcs round the plaza at r about 95 and crosses every path at 79 to 89 degrees (8 bridges, one per crossing); the gazebo moved from (-138, 80) to (-144, 62). Recorded in `island-layout.js`.
- **Distant terrain draws a few seconds after a rewrite**: captures taken at once miss the far range; wait about 10 to 15 s.

## Reverting
`EnvironmentBuild.cleanup()` clears the box and restores the saved look; `HubBuild.build()` then brings back the greybox backdrop. To return to the Task 1 stream, restore the old waypoint line in `island-layout.js` (git history) and re-run `export-luau.js`.
