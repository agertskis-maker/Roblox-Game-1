---
title: "0025: Speedway visible levels: one additive look kit assembled per client from a level number"
date: 2026-10-28
tags:
  - decision
  - island
  - speedway
status: proposed
---

# 0025: Speedway visible levels

> [!note] Pending Adam's review
> Written by Claude Code on 2026-10-28 for the Lane 3 Speedway upgrade looks task (brief `vault/design/specs/speedway-upgrade-looks.md`, ledger `vault/design/specs/speedway-upgrade-looks-ledger.md`). Adam's decisions are marked **Decided (Adam)**; everything else is a reversible choice by Claude, pending Adam's review. Number reserved in `Car-Hop-Art/DECISION_NUMBERS.txt` after checking every local and remote branch (0016 to 0023 used, 0024 reserved by the HUD session).

## Decided (Adam, 2026-10-28)
- The Speedway gets **10 to 15 visible upgrade levels**, not the outline's 5 Income Tiers: from a plain dirt track to a spectacular raised track with a loop, a little better at every level.
- Every level is **visible** from outside the plot ("the island shows progress").
- Crowds, bleachers, a flag official and similar life arrive as the track grows.
- **Supersedes the 2026-10-21 base-track rule** (Task 3: the base track already has yellow lines, flags, a checkered line and banners). Those now arrive at later levels: asphalt with its lines at level 4, the checkered line and the flag line at level 5, banners on the banked walls at level 9. The island ledger ([[island-rework]]) points here.
- Not Lane 3's to decide (Brian L, Lane 2): the final count, prices, Lap Pay effects, the save field, Income Tier or not, the relation to Slots. Message: `vault/design/specs/speedway-levels-for-brian-l.md` (on main).
- The overpass: "do whatever is viable", as long as a car can visibly go round the track; Adam warned that an upside-down loop may be hard (2026-10-28, answer to the question batch).
- **Simpler ramps** (2026-10-28, after seeing the first build: "make the ramps a little simpler i dont want them to be too crazy"; asked which ramps, answered "Both"): no spiral and no track over track; the jump becomes a low hump with no gap.
- **Bleachers and grandstand in the painted island style** (2026-10-28: "focus a little more on the bleachers and the style of those"; chose the painted option): seats in navy, coral and cream rows, a navy front panel with a fictional sponsor, hand rails, fans seated properly; the grandstand gets the same look, bigger and roofed.

## Reversible choices (Claude)
1. **12 preview levels**, the brief's recommended ladder (`Shared/Island/Speedway/Ladder`). The three extra looks for a 15-level ladder are recorded, not built.
2. **One additive kit, assembled per client.** `Look.apply(plot, level)` builds the features in range and removes the ones out of range, so upgrade, downgrade and repeat end in the same pieces. The proposed production contract is one integer plot attribute `SpeedwayLevel` set by the server; each client assembles the look (visitors see it too, far plots get a still silhouette, the reveal is local). Reason: no remote and no server cost for looks; distance detail and the reveal belong on the client anyway; edit mode can still assemble the same looks for views and checks (`HubBuild.previewSpeedway`).
3. **The Task 3 base track moved, not duplicated.** The asphalt, its lines, curbs, checker, infield stripes and flag line moved from `Hub/Recipes/Plot` into the look module; the plot recipe now builds only the front (gate, kiosk, Paddock, pit lanes). The lap markers (`Markers`, Path001...) are unchanged.
4. **Lap paths by level, placed by phase.** The lap path changes shape (flat oval 1 to 8, banked turns 9, raised far turn 10 and 11, loop 12), so its length changes (427.1 studs for levels 1 to 11, 494.6 at 12). Cars are placed by their lap phase, so every lap takes the same time and a level change keeps every car's place in the lap; only the visual speed changes (28.5 and 33.0 studs per second at 15 s). Crossings come from the same clock, never from a collision.
5. **The raised track is a climbing far turn** (simplified on Adam's request; the first build's 360 degree spiral and raised right straight are gone). The main straight, the start line, the grandstand, the near turn and the whole right straight stay on the ground; the far turn climbs gently from the ground to the 12-stud deck as it turns (eased, about 1 in 9), and the lap comes back down the main straight on a 1 in 6 ramp that lands 6 studs before the finish. The track never crosses itself; visitors walk under the high part of the far turn and the top of the ramp. Level 11's jump is a low hump (1 stud, 12 long, eased, solid, no gap) on the right straight after the pit lane join. The loop (level 12) stands on the ground right straight between two S-bends (entry x 26, exit x 38, clear of the outer tyre wall), on a wider asphalt pad. The visual cars ride the loop by their path frame (the car's up points at the loop's centre), plain CFrame math, not physics; visitors cannot walk up the loop (its mesh does not collide).
6. **Visitor safety:** solid parapets on every raised edge, columns only where the deck is at least 7 studs up and never on the ground road, a solid fill under lower deck (no gap to crawl into), the hump solid and walkable, decoration that does not collide, and the start gantry colliding only at its legs.
7. **Rigid figures animated in code** (fans, the flag official, the mechanic, the blimp), each animated in its placement frame; only near plots animate. Celebrations follow the preview rarity fixture and are coalesced per plot.
8. **Kit meshes** from a Git-tracked headless Blender recipe (`assets/island/kit/kit_speedway.py`), the island's existing palette only (no new image), previews from mesh data until Adam's guided import.
9. **The near (plaza-side) turn banks 3 degrees with a 0.4-stud white lip** (no cap, catch fence or banners); the far turn keeps 14 degrees and the tall wall. Reason: the brief says never block the plaza's view of the track; at 8 degrees with a 0.9 lip the wall hid most of the lap (independent review, 2026-10-28). Levels 9 to 11 now show 73 to 79% of the lap from a standing eye on the plaza.
10. **The cars follow the new lap path only when the level-up reveal has built the new road** (plot attribute `SpeedwayPathLevel`, set when the reveal ends; at once on a downgrade or a far plot), and falling pieces do not collide until they land.

## Consequences
- The island preview build now shows no track in edit mode until `HubBuild.previewSpeedway()` is called (or Play starts); `clearSpeedway()` before saving the place.
- Anything that reads the Speedway's parts must read the client's assembled look (`Plot.SpeedwayLook`), not the build.
- Lane 2 owns when the level changes; until then the preview uses `SpeedwayPreviewLevel` per plot and the Studio preview panel.
