---
title: Round 2 HUD, original Heat, capture drama, collectible cards and three-world presentation — ledger
tags: [design, spec, ledger, lane3]
status: in progress
date: 2026-10-23
---
# Round 2 (2026-10-23): ledger

Source: Adam's brief "Car Hop — Round 2 HUD, original Heat, capture drama, collectible cards and
three-world presentation" (pasted 2026-10-23). Owner: Adam (Lane 3). Builder: Claude Code, one lead,
at most one fresh reviewer. Builds on [[hud-rebuild-downtown-b]] and [[0019-hud-arcade-rebuild-preview]];
their text is not rewritten. Plan: `C:\Users\agert\.claude\plans\cosmic-prancing-jellyfish.md`
(outside the repo). Resume note: [[hud-round2-checkpoint]]. Heat evidence: [[hud-round2-heat-inventory]].
Decision: [[0020-hud-round2-presentation]]. UI spec: `vault/design/ui/hud-round2.md`.

## Authority and limits
- Presentation only. Lane 1 (Brian R) owns Heat/gameplay rules, Hop, steering, traffic, Stamina rules,
  camera, road width and segment contracts. Lane 2 (Brian L) owns Cash, ownership, Lap Pay, upgrades,
  saved data. Interfaces stay **held**: proposals live here and on the board only; nothing is sent.
- Task-scoped Studio-mock exception to the Figma step continues (Adam: "Skip Figma for this task");
  [[0012-figma-ui-workflow]] is unchanged.
- Private places only: `CarHop-HUD-Playground.rbxl` (Play) and `CarHop-Downtown-LookDev.rbxl` (edit).
  No island edits, no publishing, no merging, no forced push.
- Every gameplay-like behaviour (Stamina, HOP STREAK, restoring pickups, record, loop, best-window,
  countdown) is a typed local fixture, **off by default** in shared paths.

## Supersessions and contradictions
| # | Earlier | Round 2 | Resolution |
|---|---|---|---|
| S1 | Portrait supported (PhonePortrait frame, portrait layouts) | Landscape only | Round 2 wins; portrait code removed from task-owned HUD (WP3) |
| S2 | Separate run coin counter ("Coins") | Cash is the single currency | Round 2 wins; road coins are Cash pickups (+$X cue, Results source row) |
| S3 | Run Cash/count bottom-left | Run Cash top-left; owned count moves into Garage | Round 2 wins |
| S4 | Segmented bottom-centre Heat bar (brief 2026-10-22 §8) | Original ENGINE HEAT panel | Round 2 wins; see [[hud-round2-heat-inventory]] |
| S5 | District strip | Subway-style route line | Round 2 wins |
| C1 | "Ride continues at 0 Stamina" | Heat resets only on Hop (decision 0008) | Not a contradiction in the UI, a gameplay consequence: documented in the heat inventory note; no balance chosen |

## Requirement ledger
Status: open · in progress · built · build-checked · runtime-tested (Studio Play/Edit) · fixture-only ·
blocked · deferred. Evidence labels: Studio Edit / Studio Play / Blender render / synthetic fixture /
live-read integration / untested.

| ID | Requirement (short) | WP | Status |
|---|---|---|---|
| R2-G1 | Earlier commits on GitHub before implementation | 1 | done: `git ls-remote` 2026-10-23 14:20, HUD `2ecea81`, main `0195fa2` |
| R2-H1 | Inventory of the original Heat (path/revision, visual vs logic, inputs, thresholds, active, author) | 2 | open |
| R2-H2 | Proven explanation of why the playground uses another bar, at the top of the review page | 2 | open |
| R2-H3 | Use the original visual component directly; adapt inputs; do not copy logic | 5 | open |
| R2-H4 | Baseline original behaviour + equivalent input sequence after integration; label fixture accurately | 2, 5 | open |
| R2-H5 | Heat bottom-centre; tested with Stamina/Keys/route on phone landscape, tablet, desktop | 5 | open |
| R2-O1 | Landscape-only (`StarterGui.ScreenOrientation = LandscapeSensor`), both sides; remove portrait branches | 3 | open |
| R2-O2 | Layout matrix: small phone ≈844×390 or smaller, tablet, 1920×1080; notch sides; record sizes | 3 | open |
| R2-O3 | Emulator vs physical rotation stated honestly | 3 | open |
| R2-C1 | Remove run coin counter; Cash pickups as +$X cue; Results "Road coins +$X" row without double count | 4 | open |
| R2-C2 | Tests: clustered, during count-up, run-end coincidence, delayed, zero, reset | 4 | open |
| R2-HM1 | Remove car-plus icon and owned count; Garage "12 / 24 CARS" pill with truthful fallbacks | 4 | open |
| R2-HM2 | Shop seamless rainbow, sparse glints, NEW only from a supplied flag, reduced motion, paused when hidden | 4 | open |
| R2-HM3 | Restyle all retained run overlays into the arcade family | 4 | open |
| R2-S1 | Stamina demo: 10, −1 per accepted hop, none at 0, ride continues; meter, low/zero states; restore pickups off by default; HOP STREAK off by default | 6 | open |
| R2-S2 | Gameplay conflict analysis from the real Heat rules | 2 | open |
| R2-R1 | Subway route line: five stations per World, marker, callout, honest units | 7 | open |
| R2-R2 | Record badge, record marker only inside the interval, NEW BEST once, cycle with LAP tag and monotonic distance | 7 | open |
| R2-P1 | Hop: target arc, reticle, ring, rim; state precedence; figure icon; best-window with hysteresis; whoosh throttle | 8 | open |
| R2-K1 | Capture escalation tiers, capped pulse, ALMOST, visual-only shudder, countdown only with trusted data, SECURING | 9 | open |
| R2-V1 | SECURED reveal on confirmed identity only; protected-rectangle placement; compact on phones; tray hand-off | 9 | open |
| R2-V2 | Haptic: best effort, off by default, never claimed tested | 9 | open |
| R2-T1 | Tray: thumbnails, 3–4 + "+N more", independent of Stamina | 9 | open |
| R2-T2 | Collectible card: compact / reward / detail, rarity rim, foil, truthful stats, unowned, detail view | 9 | open |
| R2-D1 | Downtown B refinement: mixed 4–6 storeys, skyline, trees/lamps, no collidable median, route ≥3,000 studs | 11 | open |
| R2-W1 | Common World method: same road template, joins, deterministic seeds, validators incl. 400-stud sign spacing | 10 | open |
| R2-W2 | ≥3,000-stud recorded travel per World, second traversal/reset, Edit vs Play labelled | 12 | open |
| R2-DH1 | Dusty Highway: five districts and landmarks, nature, hazards (gaps only in a test area) | 12 | open |
| R2-SP1 | Summit Pass: five districts and landmarks, atmosphere, hazards (gaps only in a test area) | 12 | open |
| R2-A1 | Eight verified music candidates (2 per World + 2 tension) or named gaps | 13 | open |
| R2-A2 | One loop at a time, mute/volume preserved, tension tied to supplied progress, single duck source | 13 | open |
| R2-E1 | Strict Luau, typed adapters, no live DataStores/remotes, bounded pools, cleanup | all | open |
| R2-E2 | B2 upload via one guided batch (existing owner, Restricted); Dusty/Summit kits prepared, not uploaded | 14 | open |
| R2-E3 | Performance with workload, median/p95/max, memory, counts; emulator ≠ phone | 14 | open |
| R2-X1 | One fresh reviewer, concise packets; fixes; recapture | 15 | open |
| R2-X2 | Review page + local Markdown; verified-private link or named limitation | 15 | open |
| R2-X3 | Final answer: what was tested in Studio vs read in code | 15 | open |

## Held interfaces (proposed, not sent)
Unchanged from [[hud-rebuild-downtown-b]]: `run.districtPlan`, `DistrictEnter`, `KeysStart/Canceled/Confirmed`,
`RunWarning`, `Dismounted/RunEnded`, traffic display, hop target, steering. **New in Round 2** (all fixtures here):

| Field / event | Shape | Owner |
|---|---|---|
| `run.stamina` + `HopAccepted` / `HopRejected{reason}` / `StaminaPickup` | `{value,max}`; spend only on an accepted hop | Brian R (rules), Brian L (upgrades) |
| `run.recordM` + verified-record flag | personal-best distance before the run | Brian L |
| `CashPickup{id,amount}`, `results.sources.roadCoins`, `results.totalIncludesPickups` | pickup events and the breakdown flag | Brian L |
| `keys.remainingSeconds` + `keys.timingTrusted` | countdown only when trustworthy | Brian R |
| hop `window` ("Best"/nil) and optional trajectory | best-timing cue; arc stays a direction cue without a trajectory | Brian R |
| `collection{owned,total?}` | Garage pill | Brian L |
| `shop.newItem` | NEW ribbon flag | Brian L |
| `StarterGui.ScreenOrientation = LandscapeSensor` in `default.project.json` | one-line addition for the team (Adam chose playground projects only for this task) | team |

## Removed paths (portrait) — filled in during WP3
(none yet)

## Waiting for you (expected)
Sound listening; guided B2 import clicks if the importer cannot be driven; permission to upload the Dusty/Summit
kits; confirm the Heat-panel phone scale; optional physical-device rotation/haptic test; push and PR #2 refresh;
held team contracts.

## Decisions I made (reversible, preview)
Recorded in [[0020-hud-round2-presentation]] and on the review page.
