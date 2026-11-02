---
title: Lane 3 Round 3 ledger
date: 2026-11-02
tags:
  - design
  - lane3
---

# Lane 3 Round 3 ledger

Brief [[lane3-round3]], decision [[0033-lane3-round3]]. Evidence: `Car-Hop-Art/review/round3/evidence/`.

## Where the blur came from (N2-01)
Icons were cut from one sheet, then shown from 96 px previews through EditableImage, stretched up to 100 to 150 px on screen with no mip maps. The art itself was fine; the delivery was the fault.

## First five minutes (N12), run on the local beta
| Minute | What a new kid sees and does | Confusion or boredom | Result |
|---|---|---|---|
| 0:00 | Loads, spawns facing the fountain and portals. Slim pill, yellow arrows straight to Downtown | Arrows cross the fountain's edge | Fine: they hide inside solids and resume |
| 0:30 | Walks in. Title wipe. Stands on the pad facing the ramp | Stalls could distract | Pill says "Walk up the ramp" |
| 0:45 | Steps on ramp, card opens, pill says "Press START!" | None | Good |
| 1:00 | Run. "Hop to a car!" | Crashes fast: 46 to 50 m runs happened in tests with no steering | So Close card, tip, Retry. Needs first-run traffic help from Brian R |
| 2:00 | Hops, "Hold on!" | Keys take 5 s or more; a kid may hop off | Hint at 8 s |
| 3:00 | Results, HOME | None | Good |
| 3:30 | Back at the portal, Park step skipped in the beta | "Park" can't run: no control exists | Needs Brian L's lineup |
| 4:00 | "You're ready!", then free play; first hint after a trip home | None | Good |

## Status
| ID | Requirement | Status | Evidence | Note |
|---|---|---|---|---|
| S-01 | Branches updated | done | main merged | |
| S-02 | Board claim | done | ac6a22c on main | |
| S-03 | Ledger, brief copy, 0033 | done | this file | |
| S-04 | Style guide | done | `vault/design/ui-style-guide.md` | |
| S-05 | Upload route | done | no key set; package ready | |
| N1-01 | Portal path spikes | done | path-dusty-spike-before/after, PathEndChecks 0 failures of 61 | Summit is the mirror; Downtown 0.1 lip removed |
| N1-02 | Path ends | done | path-ring-before/after | 42 ends scanned; ring trimmed |
| N1-03 | Summit order by hand | done | 8 seeds at 3000 and 2 at 9000 pass all checks in Studio | Majors 521 to 664 apart |
| N1-04 | After-shots and checks | partial | spike and ring shots; flicker scan not re-run after the path change | Strips only got shorter |
| N2-01 | Why icons blur | done | above | |
| N2-02 | New assets | done | 44 processed; art tools in `review/round3/art/tools` | art-decal-pack fringe not re-cut |
| N2-03 | Fixed slots | done | CarKit.slot, boxArt | |
| N2-04 | Load behaviour | partial | images reveal after fetch, placeholders; loading-screen preload not wired | Each image fetches on first show |
| N2-05 | Crisp 2x | done | shop-desktop-beta | Printed in the art |
| N2-06 | One upload | done | `art/upload` 132 items | Needs Adam |
| N3-01 to 05 | Shop rebuilt | done | shop-* frames | Scores in RESULT |
| N3-06 | Honesty | done | deal math derived, PREVIEW footer, no timers | |
| N3-07 | Get more spots | partial | code wired; not pressed in Studio | Appears only when all spots are owned |
| N3-08 | Reviewer scores | see RESULT | | |
| N4-01 | Style works | done | Paint, decal, wheel, trail applied in Play, one implementation | Stunt screen shares it |
| N4-02 | Decals | done | 14 baked | Lightning and Comet need a look at full size |
| N4-03 | Wheels | done | 10 meshes | |
| N4-04 | Paint tiers | done | Galaxy seen; others by code | |
| N4-05 | Trails | done | 9 trails; moves on the turntable | Added: moving preview (Adam) |
| N4-06 | Play recording | partial | stills at both sizes; see RESULT for video | |
| N5-01 to 03 | Scaling packs | done | shop-phone-cash, CashPackPreview | Rate is a fixture |
| N6-01 | Three themes | done | pad-* frames | Plain Roblox materials; Dusty and Summit good, Downtown darkest |
| N6-02 | Placement | done | x 6000 to 8800, parented only in use | |
| N6-03 | Launch flow | done | Real run, respawn, HOME, RETRY | Trail on the rider, not the car |
| N6-04 | Stalls | done | Trails and Paint open; Car stall not opened in Studio | |
| N6-05 | Tutorial path | done | "Walk up the ramp", "Press START!" seen | |
| N6-06 | Whole loop | done | Portal to HOME with no errors | |
| N7-01 to 02 | Tuner, preset | done | Higher in real runs; F4 panel not opened in Studio | |
| N7-04 | Send Brian R | done | message | |
| N8 | Results | done | results frames | Count-up seen in stills only |
| N9-01 | Six steps | done | Real play reached step 3, then Go Home path | Park skipped: no control |
| N9-02 | Banner | done | 46 px, was 92 | |
| N9-03 | Straight arrows | done | home frame, ray per chevron | |
| N9-04 | Real test | partial | Reached "Hold on!", and home via HOME | "It's yours" not reached in a test run |
| N10-01 | Buttons mid-left | done | home-desktop | Slides up on phones for the thumbstick |
| N10-02 | Bigger Cash | done | home-desktop | 1.4 times |
| N10-03 | HUD to style guide | partial | Nav tiles kept | |
| N11-01 | Missions | done | missions frames, CLAIM with confetti in Play | |
| N11-02 | Settings | partial | fixed in code; not looked at in Studio | |
| N12 Summit | Worlds on road | done | summit-run-world | |
| N12 Verge | Downtown ground | see RESULT | helper | |
| N12 Re-score | Round 2's weakest | see RESULT | reviewers | |
| N12 Perf | Measured | done | Below | |
| N12 Roxy | Locked portals | done | locked-portal-roxy | Beta portals are open; test switch |
| N12 Join | Rare cases | partial | A network dropout mid-test showed Worlds failing softly; failed art falls back by code | Not run on purpose |
| N12 Five minutes | Script | done | above | |
| N13 | Messages | done | both specs | |
| N14 | Reviews | see RESULT | | |
| N15 | Finish | see RESULT | | |
| Live | Art fits, Extra Parking, moving trails, Robux respawn, stamina | done | frames | Adam, mid-round |

## Performance (one method)
Local beta, Studio Play, laptop on mains, 1527 x 1080 window, seed random. Live BasePart count in Workspace, 3 s average frame rate, after 25 s of preparation.

| Scene | Parts | FPS |
|---|---|---|
| Island at spawn | 10,054 | 60 |
| Downtown pad | 389 of its own; pads now leave the world when unused | 60 |
| Dusty pad | 185 | not measured alone |
| Summit pad | 349 | not measured alone |
| Downtown run | 654 World + 1,632 road | 60 |
| Summit run | 191 World + 1,544 road | 60 |
| Dusty run | not measured | |

Laptop in Studio only. Not a phone number.
