# Lane 3 Launch Pad redesign and bolt change: ledger

Brief: [[lane3-launchpads]]. Direction B, Sky Launch Platform. Decision: [[0035-lane3-launchpads]]. Evidence: `Car-Hop-Art/review/hubs/evidence/`. Result: `Car-Hop-Art/review/hubs/RESULT.md`.

| ID | What | Status | Evidence | Note |
|---|---|---|---|---|
| H-01 | Setup, board claim on `main` | done | commit on `main` | |
| H-02 | Ledger, brief copy, decision number | done | this file | 0034 went to the real cars note, so this is 0035 |
| H-03 | Local beta file with a dated backup | done | `CarHop-Beta-2-local.2026-11-02-before-launchpads.rbxl` | Rebuilt from `beta.project.json`; the island is built in the open window and needs saving there |
| L-01 | Nothing outside visible | done | `orbit-*.mp4`, Play | Zoom cap 44; rail, invisible walls, safe return tested once by dropping off the edge |
| L-02 | Designed, simple layout | done | stills | Round platform, 92 studs across |
| L-03 | HOME portal | done | Play, three Worlds | Island swirl art on a compact gate; returns to the portal |
| L-04 | Gantry and countdown | done | `countdown.mp4`, Play | Calm variant tested in Dusty; beeps not heard |
| L-05 | Kiosks | done | stills, Play | Stand in the circle to open; Cars turntable shows the line-up |
| L-06 | Arrival moment | done | Play | Wipe, banner, chevrons on the first 3 visits and in the tutorial |
| L-07 | Three themes | done | stills | World kit meshes first; no new meshes or uploads needed |
| L-08 | Life | done | videos | Ambient sounds load and play; not listened to |
| L-09 | Performance | partial | Play, one laptop | See below; over the Round 3 part count |
| L-10 | Flicker-free | done | OverlapScan | 0 flicker in all three pads at last scan; Downtown also 0 near |
| L-11 | Full loop | done | Play | See below |
| B-01 | 5 bolts, 1 per hop, 2 back on respawn | done | Play | Tunable; meter resized |
| B-02 | Dependents | done | code read, Play | Hop missions stay across runs; tutorial run gets 8 bolts; results line unchanged and still true |
| V-01 | Same-view comparisons | partial | `after-*.png`, `review/hubs/current/` | Arrival view matches; other views are new because the layout changed |
| V-02 | Two reviewers | done | scores below | |
| V-03 | Walkthrough | partial | below | Phone-shaped window only, not a real phone |
| V-04 | Finish | done | PRs, board, log, messages | |

## Numbers (Tunable)

| Name | Value | Was |
|---|---|---|
| `RunStamina.Max` | 5 | 10 |
| `RunStamina.ReviveRefill` | 2 | 3 |
| `RunStamina.TutorialMax` | 8 | new |
| Pad camera zoom cap | 44 studs | none |
| Start light | 0.4 s each | new |
| Platform height over the World | 170 studs | new |

## Performance

Same method as Round 3: laptop in Studio Play, 3 s frame average. Not a phone number.

| Pad | Parts, whole pad | Frame rate |
|---|---|---|
| Downtown | 627 | 60 |
| Dusty Highway | 412 | 60 |
| Summit Pass | 460 | 59 |

Round 3 was 185 to 389 before any backdrop. The World below is 57 to 209 of these. Downtown's platform alone is about 418, a little over the limit.

## Loop checked in Play

| World | Portal in | Kiosk | Ramp, card | Countdown | Run, results | RETRY | HOME |
|---|---|---|---|---|---|---|---|
| Downtown | yes | Car stall, trails, paint | yes | yes | yes | not this round | portal home yes |
| Dusty Highway | yes | no | yes, phone shape | calm variant | yes | no | yes |
| Summit Pass | yes | no | yes | yes | yes | yes | yes |

No script errors in Output. The one repeating line is an old wrong-type asset, 203785492, present before this work.

## Reviewer scores

Two fresh reviewers, on stills. Motion was not judged.

| Pad | Stylish / fun / simple, first | Final | AI look, first | Final |
|---|---|---|---|---|
| Downtown | 3 / 3 / 4 | 4 / 4 / 4 | 3 | 4, arrival view only, after the last lighting fix |
| Dusty Highway | 3 / 3 / 4 | 4 / 4 / 4 | 3.5 | 4 |
| Summit Pass | 4 / 3 / 4 | 4 / 4 / 4 | 4 | 4 |

The round rainbow loop came after the final scores and was not re-scored.
