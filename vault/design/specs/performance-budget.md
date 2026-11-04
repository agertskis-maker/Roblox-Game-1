---
title: Performance budget, laptop baseline (Round 5, P-02)
tags:
  - lane3
  - performance
---

# Performance budget: the laptop baseline

Measured 2026-11-03 in Studio Play on Adam's laptop, local file `CarHop-Beta-2-multitest.rbxl` (integration/beta-2, Round 5), one client, the Studio viewport at 841x568 (not 1920x1080: Studio's own window, recorded as found). **This is a laptop number, not a phone number.** It is the baseline Adam's real-phone test is compared with. Method: `Stats.FrameTime`, `Stats.RenderCPUFrameTime` and `Stats.RenderGPUFrameTime` averaged every frame over the window shown; part counts from the instances. Draw calls were not read: the Render Stats panel (Shift+F2) did not open from the Studio MCP input, so no draw-call or triangle figure is claimed.

## Where Roblox's guidance points

- [Improve performance](https://create.roblox.com/docs/performance-optimization/improve): reuse the same mesh, material and texture so the engine can instance them; overlapping transparency, decals and particle emitters cost the most on phones. Identity reuse makes batching possible; it is not a one-to-one rule.
- [Performance optimization](https://create.roblox.com/docs/performance-optimization): identify, improve, monitor. The community "about 150 UI draw calls" figure is a heuristic, not a Roblox limit.

## Measured

| Where | Frame mean / worst (ms) | Render CPU / GPU (ms) | Parts (BaseParts / MeshParts / unique mesh ids) |
|---|---|---|---|
| Plaza centre (4 s) | 16.7 / 22.8 | 6.4 / 6.4 | island 5,224 / 419 / 36, environment 3,727 / 3,064 / 224 |
| Home plot gate (4 s) | 16.7 / 21.0 | 6.0 / 7.0 | same island |
| Downtown pad (1.5 s) | 16.7 / 19.8 | 5.3 / 4.7 | 595 / 24 / 5 (was 634 / 27 / 12 before P-01) |
| Dusty Highway pad (1.5 s) | 16.7 / 20.3 | 5.2 / 5.4 | 408 / 24 / 5 |
| Summit Pass pad (1.5 s) | 16.7 / 25.5 | 5.9 / 5.4 | 456 / 24 / 5 |
| Downtown run, 359 m (2 s) | 16.6 / 25.9 | 5.2 / 5.3 | World under the road 691 / 59 / 20 |
| Dusty Highway run, 502 m (2 s) | 16.7 / 22.7 | 5.6 / 4.5 | 507 / 40 / 21 |
| Summit Pass run, 308 m (2 s) | 16.7 / 31.7 | 6.6 / 5.6 | 188 / 100 / 43 |
| Server, 6 clients, 12 Lineup cars (20 s) | 18.0 mean / 190 worst | n/a | Lap Pay scheduler 0.30 ms mean per pass, 64 ms worst (one machine-wide hitch with 7 Studio windows open) |

Studio caps the frame at 60 fps, so every client row reads 16.7 ms: the render times show the headroom (about 10 ms a frame on this laptop).

## The three worst offenders, one fix each

1. **The island environment: 3,064 MeshParts with 224 unique meshes** (trees, rocks, plants). Fix: keep repeating the same few meshes (the kit already does) and let far plants go (render fidelity Automatic, or culling by distance); check on a phone first. Not done this round: needs a phone measurement to justify it.
2. **Downtown's Launch Pad: 634 parts**, the largest pad (the Round 3 limit was about 600). Fixed this round (P-01): sign checker caps 6 tiles to 4 parts and kiosk awnings 3 stripes to 2 slabs a side, **634 -> 595**, same look, now under the limit.
3. **Summit Pass's worst frame (31.7 ms) and 43 unique meshes in 188 parts** under the road. Fix: reuse the Dusty and Downtown kit meshes where Summit has a near-copy, and check the WorldLife skaters (moving figures, 432 overlapping face pairs between their own pieces, invisible while moving but drawn twice). Not done: a World art change, for the next Worlds pass.
