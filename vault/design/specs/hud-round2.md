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
| R2-H1 | Inventory of the original Heat (path/revision, visual vs logic, inputs, thresholds, active, author) | 2 | done: hud-round2-heat-inventory.md |
| R2-H2 | Proven explanation of why the playground uses another bar, at the top of the review page | 2 | done (proven cause) |
| R2-H3 | Use the original visual component directly; adapt inputs; do not copy logic | 5 | runtime-tested: HeatPanel uses the unmodified HeatGauge |
| R2-H4 | Baseline original behaviour + equivalent input sequence after integration; label fixture accurately | 2, 5 | runtime-tested: integration-equivalence.md |
| R2-H5 | Heat bottom-centre; tested with Stamina/Keys/route on phone landscape, tablet, desktop | 5 | runtime-tested on six frames; Stamina/Keys/route composition still pending |
| R2-O1 | Landscape-only (`StarterGui.ScreenOrientation = LandscapeSensor`), both sides; remove portrait branches | 3 | runtime-tested: property read in Edit and Play (PlayerGui.ScreenOrientation LandscapeSensor, CurrentScreenOrientation LandscapeLeft) |
| R2-O2 | Layout matrix: small phone ≈844×390 or smaller, tablet, 1920×1080; notch sides; record sizes | 3 | runtime-tested on six virtual frames (virtual, not physical devices) |
| R2-O3 | Emulator vs physical rotation stated honestly | 3 | virtual frames only; no physical or emulator rotation test yet |
| R2-C1 | Remove run coin counter; Cash pickups as +$X cue; Results "Road coins +$X" row without double count | 4 | runtime-tested (pickup cue, Results source row built; Results visual still to capture) |
| R2-C2 | Tests: clustered, during count-up, run-end coincidence, delayed, zero, reset | 4 | partly tested: cluster, duplicate, during count-up, delayed balance; run-end/zero Results pending capture |
| R2-HM1 | Remove car-plus icon and owned count; Garage "12 / 24 CARS" pill with truthful fallbacks | 4 | runtime-tested (pill cases) |
| R2-HM2 | Shop seamless rainbow, sparse glints, NEW only from a supplied flag, reduced motion, paused when hidden | 4 | runtime-tested (seam wrap, NEW flag, reduced motion, hidden); video pending |
| R2-HM3 | Restyle all retained run overlays into the arcade family | 4 | partly: ribbon, warning chip, ride chip, tray review, panels done; cards (WP9) and banner (WP7) pending |
| R2-S1 | Stamina demo: 10, −1 per accepted hop, none at 0, ride continues; meter, low/zero states; restore pickups off by default; HOP STREAK off by default | 6 | runtime-tested (Studio Play, synthetic fixture): 10→0, rejected/no-target/cooldown spend nothing, no negative or over-max, ride continues at 0, reset, off = no UI, reduced motion (8 hops + pickup, no drain/refill/flight animation); HOP STREAK x2/x3 state not yet shown |
| R2-S2 | Gameplay conflict analysis from the real Heat rules | 2 | done: hud-round2-heat-inventory.md §5 (zero Stamina = a countdown Hop cannot answer; HOP NOW! hidden at 0 as presentation only; options not chosen) |
| R2-R1 | Subway route line: five stations per World, marker, callout, honest units | 7 | runtime-tested (Studio Play, synthetic fixture routes): three Worlds × five stations with original tiles, marker from explicit unequal boundaries (schematic equal visual stretches, stated), callout "distance • next district in X m", labels ≥ 16 px, no overlap with Cash or the protected rectangle on six frames; video: r2-route-cycle-desktop.mp4, r2-route-cycle-summit-phoneL.mp4 |
| R2-R2 | Record badge, record marker only inside the interval, NEW BEST once, cycle with LAP tag and monotonic distance | 7 | runtime-tested (Studio Play, synthetic fixture): none / inside / ahead / behind / first-stretch / unverified record, NEW BEST once per World incl. oscillation and a second cycle, total distance monotonic, LAP 2 with sweep back (none in reduced motion), arrivals once per (cycle, district), reordered updates ignored; production loop and verified-record contract are held proposals |
| R2-P1 | Hop: target arc, reticle, ring, rim; state precedence; figure icon; best-window with hysteresis; whoosh throttle | 8 | runtime-tested (Studio Play, synthetic fixture; proxy cars, no real meshes yet): pooled chevron stream (9, cap 12) as a labelled direction cue, roof reticle + rim + one brief HOP word + dashed ring as ONE target (oneTarget, three cues), precedence table 11/11, best-window hysteresis (fast flicker no change; hover one entry; one accent per window; gap and id identity), retarget clean + whoosh throttled, target loss / mode exit leave no cue, reduced motion steady; HopFigure icon; video r2-hop-state-tour-desktop.mp4; sound is a candidate, not listened; the real trajectory, target, window and landing stay Lane 1 (Brian R) |
| R2-K1 | Capture escalation tiers, capped pulse, ALMOST, visual-only shudder, countdown only with trusted data, SECURING | 9 | runtime-tested (Studio Play, synthetic fixture), numbers only so far: tiers 1/2/3, ALMOST once (bigger, then settles), pulse capped at 1.0 Hz, sparks about 3 a second at most, countdown only with trusted timing ("1.2s" vs the percentage), warnings outrank the decoration, reduced motion steady, SECURING until confirmed, the ridden vehicle moved 0.000000 studs across a whole capture. **SHUDDER DEFERRED** (it cannot be separated from the authoritative vehicle in this preview; nothing moves it). Frames on three backgrounds (desert, city, snow) wait for the Worlds (WP12) and an unlocked screen |
| R2-V1 | SECURED reveal on confirmed identity only; protected-rectangle placement; compact on phones; tray hand-off | 9 | runtime-tested (Studio Play, synthetic fixture): the full card on wide screens only where it clears the protected rectangle (200 x 332, right of the road view), SECURED stamp, NEW and Lap Pay only as supplied, count changes once at confirmation, 32 pooled pieces (cap 40), Legendary shockwave inside the same time, reduced motion steady, duplicate / late / out-of-order / run-end identity cases; phones get the compact SECURED stack (thumbnail, name, NEW, Lap Pay) placed clear of the protected rectangle, the tray, Hop, Heat, Settings (the riding chip steps aside); real-time videos r2-reveal-desktop-epic.mp4, r2-secured-phone-stack.mp4. Dramatic-vs-safe comparison page pending |
| R2-V2 | Haptic: best effort, off by default, never claimed tested | 9 | built (Run/Haptics: one UINotification HapticEffect under pcall, only when store.settings.haptics is true; result "requested", never "felt"; UNTESTED ON HARDWARE) |
| R2-T1 | Tray: thumbnails, 3–4 + "+N more", independent of Stamina | 9 | runtime-tested (Studio Play): static ViewportFrame thumbnails (3 alive, limit 4, no spin, none in hidden overlays), thin rarity edge, NEW chip, name truncated at 16 px with the review wrapping long names and a tapped car tile opening its card detail, "+N" for older claims, tray placed independently of the Stamina slot |
| R2-T2 | Collectible card: compact / reward / detail, rarity rim, foil, truthful stats, unowned, detail view | 9 | runtime-tested (Studio Play) for logic and layout: TradingCard (Compact, Reward) extending CarCard, eight family icons (fixture Bus maps to Truck, flagged), World scene and badge, NEW only on a supplied flag, Epic/Legendary foil limited to 4 live and static in reduced motion, Lap Pay as supplied with the per-second row "unavailable (proposed)" without a defined lap duration, unowned "?" with no leaks, finishes owned / not owned / unknown distinct, dates and numbers only when supplied, bars only with a documented scale; CardDetail landscape view with a FIXED action bar (gap to the bar 4.6-6.0 px, nothing scrolls behind it, Revolution 6 case on three frames). Visual sheets pending an unlocked screen. Placeholder art = proxy models |
| R2-D1 | Downtown B refinement: mixed 4–6 storeys, skyline, trees/lamps, no collidable median, route ≥3,000 studs | 11 | open |
| R2-W1 | Common World method: same road template, joins, deterministic seeds, validators incl. 400-stud sign spacing | 10 | runtime-tested (Studio Edit, numbers only): Worlds are DATA (`City/Worlds/{DustyHighway,SummitPass}.luau`, constructors in `Make.luau`, registry and checker in `Worlds/init.luau`) feeding the SAME Sequencer and Assembler (`Catalog.forWorld`, `City.new{world=...}`); Downtown-only rules became district data (`welcome`, `roofTanks`, `cart`, `required`); same 4 x 17 lane template, same road meshes and joins. Both Worlds, seeds 2207 / 11 / 77 / 101 / 314: five districts, segment join error 0.0000, 0 sign repeats inside the 400-stud gap, 0 landmark conflicts, planner checks pass, no Gap hazard in the route. Seed 42 is not used (it repeats a landmark in Dusty Highway). Downtown determinism argued from the diff (same rng draws in the same order) and its own checks still pass; digest recorded 1998226011 for seed 2207 / length 2400. Assembler per-World hooks (light, ground, masses, hazards, bridge floor, extra kit folders) build without error in Edit mode with labelled proxies |
| R2-W2 | ≥3,000-stud recorded travel per World, second traversal/reset, Edit vs Play labelled | 12 | open |
| R2-DH1 | Dusty Highway: five districts and landmarks, nature, hazards (gaps only in a test area) | 12 | in progress: DATA done (5 districts, 23 lot modules, 10 landmarks, 12 sign names, props, hazard names) and planned: route 3,195 studs, tier A all present (windmill, saguaro garden, diner, old pump garage, sandstone arch, canyon bridge, big cactus sign, ghost huts); everything is a labelled PROXY until the Blender kit is authored; kit, hazards in context and atmosphere still to do |
| R2-SP1 | Summit Pass: five districts and landmarks, atmosphere, hazards (gaps only in a test area) | 12 | in progress: DATA done (5 districts, 23 lot modules, 12 landmarks, 12 sign names, props, hazard names) and planned: route 3,099 studs, tier A all present (chalet cluster, ski lift, frozen lake, glacier tunnel, summit lodge, observatory, snowmen); proxies only until the Blender kit is authored |
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
| `event.lapPay` (KeysConfirmed), `keys.remainingSeconds` + `keys.timingTrusted`, `settings.haptics` | the supplied Lap Pay of the claimed car; the capture countdown shown only when trusted; the local haptics switch (default off) | Brian L, Brian R |
| `run.hopTargetId`, `run.hopWindowId` | the one selected target and one best-timing window event (identity for the accent and the lock-on whoosh) | Brian R |
| `run.recordVerified`, `run.runId`, `districtPlan.world{id,name,colour}`, `District.short` | the record flag (false = no NEW BEST), the run identity for once-per-run effects, the World colour and phone labels for the route line | Brian L (record), Brian R (plan) |
| `StarterGui.ScreenOrientation = LandscapeSensor` in `default.project.json` | one-line addition for the team (Adam chose playground projects only for this task) | team |

## Removed paths (portrait), WP3
Screen.Profiles.PhonePortrait; Home/Layout PortraitGrid menu shape, portrait stats placements (Above, AboveJump, block scale), portrait banner and toasts; RunLayout.portrait, PhonePortrait protected fractions, portrait tray row, upper-row and side-slot branches; ClaimTray horizontal layout; SettingsPanel stacked rows; DebugPanel, Home and Run scenario profile lists (now api.profiles); HudPlayground run anchors (setRunAnchor removed from StatsStack). Shared input infrastructure untouched.

## Waiting for you (expected)
Sound listening; guided B2 import clicks if the importer cannot be driven; permission to upload the Dusty/Summit
kits; confirm the Heat-panel phone scale; optional physical-device rotation/haptic test; push and PR #2 refresh;
held team contracts.

## Decisions I made (reversible, preview)
Recorded in [[0020-hud-round2-presentation]] and on the review page.
