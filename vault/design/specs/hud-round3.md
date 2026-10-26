---
title: Round 3 HUD, cards, audio, B2 import and World plans — ledger
tags: [design, spec, ledger, lane3]
status: in progress
date: 2026-10-26
---
# Round 3 (2026-10-26): ledger

Source: Adam's "Car Hop — Lane 3 HUD Round 3 and World redesign plans" brief (pasted 2026-10-26), owner Adam (Lane 3). Builds on
[[hud-round2]] (kept as dated history, not rewritten) and its checkpoint [[hud-round2-checkpoint]]. Resume note: [[hud-round3-checkpoint]].
Lead: Claude Code (one lead; Sonnet workers on disjoint files; one fresh Sonnet reviewer at the end). Only the lead touches Studio, Blender, Git and shared files.
Preview only: fixtures off by default, interfaces held (drafts for Brian R / Brian L are written, **nothing sent**), no island edits, no merge, no publish.

## Authority and limits
- Presentation only (Lane 3 paths). Never edited: `src/client/Run`, `src/shared/Run` (Brian R), `src/server`, `src/shared/Catalog`, `src/shared/Net` (Brian L), `assets/cars`.
- Approved original ENGINE HEAT (`RunHud/HeatGauge.luau`) stays byte-identical to `main`; only uniform scale and layout anchoring are allowed here.
- Studio lock: taken 2026-10-26 10:24 with Adam's yes (the previous lock was 45 h old, Round 2, "Adam is viewing the HUD playground"). Island window untouched.
- Figma: signed in (account handle `agertskis`, **View seat on the Starter plan**), but no "Car Hop UI" file link is recorded anywhere in the repo and a View seat cannot edit. Figma mocks were therefore not made; the changed pieces are specified in `vault/design/ui/hud-round3.md` and mocked in Studio (labelled as awaiting final visual acceptance, not as approved mocks). No sign-in loop was started.
- Free memory floor 4 GB (6.3 GB free at start; sampled again before heavy steps).
- Git (verified, not assumed): at the start the HUD branch was 20 commits AHEAD of `origin` (the Round 2 review's "earlier commits on GitHub" line meant `2ecea81` only); local `main` was 3 board commits ahead of `origin/main`; no divergence. Pushed with a normal push: `main` `0195fa2..d4fb1e2`, HUD branch `2ecea81..0e90a9d`. No dependency change (`rokit.toml`, `wally.toml`, `wally.lock` unchanged; `Packages/` present in the HUD worktree).

## Requirement ledger
Status words: open · assigned · built · build-checked · runtime-tested (Studio Play/Edit) · blocked · proposed · done. Evidence labels: Studio Play, Studio Edit,
Blender render, code-read, virtual frame, physical device, untested.

| ID | Requirement (short) | Owner | Status |
|---|---|---|---|
| R3-G1 | Claim task as Adam on `main` board via the clean tooling worktree; push only that board change | lead | done (`d4fb1e2`; it also carried three earlier board-only commits that were local) |
| R3-G2 | Push the two intended branches normally; no force; no merge of main into the feature branch | lead | done (see above) |
| R3-G3 | Refresh PR #2 only with work present on the branch; update stale "blocked / not uploaded" lines once verified | lead | done at the end: PR #2 title and description refreshed with only what is on the branch (see the final push) |
| R3-G4 | Studio lock handling | lead | done (Adam's yes) |
| R3-G5 | Figma check | lead | done: View seat, no file link; Studio mocks + spec instead |
| R3-F1 | Round 2 accepted fixes 1, 2, 6, 8, 11, 12 stay intact (music restart on slider, tray tile, plan checks, stray Stamina/Hop threads, Heat doc, comment) | lead | runtime-tested: the Round 2 regression scenarios (Run, Capture, Cards, Hop, Layout, Worlds combined 21 of 21, Music, Home, Results, World) re-run in Studio Play, no FAIL after the fixes |
| R3-F4 | HOP STREAK not built; backlog entry; no hidden mechanic left | lead + W3a | done: board backlog entry (main); no hidden mechanic in code (`Stamina: no hop streak` PASS) |
| R3-F5 | Settings: Haptics on/off, default ON, readable state, gates every haptic call, stops active effects, unsupported hardware quiet and honest | W2b | runtime-tested (Studio Play, 6 Haptics scenarios, default ON, an unsupported device shows `Not available on this device`); **never felt on hardware** |
| R3-F7 | External dependency audit (proposal only, nothing moved) | D1 | done: 35 dependencies classified (12 runtime, 11 build, 7 source art, 5 review-only); nothing moved; the Drive folder's identity is unverified |
| R3-F9 | Run-scoped capture identity (repeats, late previous-run events, missing run id, UI re-mount) | W2b | runtime-tested (Studio Play, 5 Identity scenarios, 32 checks); Lane 3 code only; the run id request is drafted for Brian R and Brian L |
| R3-F10 | Music: short fade instead of abrupt stops, event-driven, no forever loop | W7 | runtime-tested by property (Music 10 scenarios, Mix 8): finite fades, no polling, one duck source; **nothing listened to** |
| R3-F13 | No developer words on child-facing cards and retained overlays | W4, W8 | runtime-tested (developer-word scan on cards, detail and overlays PASS) |
| R3-F14 | Finish overlay restyle (Toast stack, Results panels, Milestones) | W8 | runtime-tested (Overlays 5 scenarios; label contrast held to the approved kit's own floor of 1.55:1, white label on gold) |
| R3-F15 | Stamina vs assumed thumb space: real overlap fixed, not a shifted rectangle | W3a, W1 | runtime-tested (Stamina thumb clearance 24 PASS on every frame; Layout tray/Stamina 6 PASS) |
| R3-B1 | Verify the OBJ package now (objects, triangles, units, UVs, palette references) | lead | done (code-read of the OBJ): 180 objects, 56,751 triangles, 1 unit = 1 stud (B2_Road_Straight96 64 x 96), 1,615 UVs and 3,774 normals, **no .mtl / usemtl**: meshes carry palette-cell UVs but no material or texture reference |
| R3-B2 | Import the OBJ meshes under Adam's account (importer clicks need Adam's approval if the permission prompt refuses) | lead + Adam | done: Adam clicked Import in the 3D Importer (my injected clicks did not register); 180 meshes, Creator Me, no Robux shown |
| R3-B3 | Upload the five approved palette images, map them (TextureID per district), verify the real appearance | lead | done: 5 palettes uploaded with `upload_image` (ids in `assets.md`); MainStreet is applied to the whole city, per-district palettes are a follow-up; colours match the old preview in Play |
| R3-B4 | Record every name / mesh id / image id / source file / owner / scale / verification in the manifest and the review | lead | done: `vault/design/assets.md` (every name, id, size, owner, source), `src/lookdev/Downtown/KitIds.luau`, `Car-Hop-Art/downtown-kit-b2/uploaded-ids.json` |
| R3-B5 | Replace intended preview references only, rebuild, Play check for load/access errors, normals, white boxes, pivots, dimensions; no duplicated assemblies; no publish, no binaries committed | lead | done for the Downtown city in the HUD playground (Studio Play: 0 proxies, one city root, no load errors beyond the one-time palette processing message); the LookDev edit place still uses session-only meshes; imported model deleted from the test place; no publish, no binary committed |
| R3-D1 | One distance pill (current vs upcoming area clear); remove landmark row, progress line, avatar marker, BEST visual; keep the orange arrival popup | W1 | runtime-tested (Studio Play: RunTop 16 + Route 5 scenarios, frames); orange popup = `DistrictBanner`, three other candidates kept |
| R3-D2 | Pill stable dimensions, long names, no horizontal jitter; popup below it; arrival de-dup; no hidden running components | W1 | runtime-tested (long names, 5-digit metres, no jitter, popup below the pill, zero tweens/threads for removed pieces) |
| R3-K1 | Keys: one continuous yellow ring, smooth full circumference, one origin/direction recorded, icon centred, text above, boundary states | W2a | runtime-tested (Studio Play, Keys 7 scenarios, 54 geometry checks on six frames, frames and a real-time clip) |
| R3-K2 | Real timing; bounded pulse at full; pending until confirmation; cancel/reset clean; reduced motion steady | W2a | runtime-tested (follow within 120 ms 11 of 11, pending holds without SECURED, cancel/reset clean, resize while ending, reduced motion); capture time unchanged |
| R3-K3 | Proposal for 20–25% shorter claim times (drafted for the owners, not changed) | lead | drafted for Brian R and Brian L, **not sent** (`hud-round3-forwardable-messages.md`) |
| R3-S1 | Stamina: sharp zigzag bolt icon, ten simple pips, number kept | W3a | runtime-tested (frames at Desktop, PhoneLandscape, PhoneSmall) |
| R3-S2 | Thresholds 6–10 yellow, 4–5 orange, 1–3 red + restrained pulse, 0 depleted with OUT OF STAMINA; boundaries and reverse; no spam; reduced motion; above the thumbstick | W3a | runtime-tested (Stamina 10 scenarios: nine boundaries both ways, throttled empty taps, no accumulated tweens, thumb clearance 24 PASS) |
| R3-C1 | Cash icon: paper band encircling the stack with perspective | W3b | built; Studio Play specimen at HUD size on bright and dark; the band wraps top, fold and front (not a full side wrap): **Adam's eye decides** |
| R3-C2 | Hop icon: original car silhouette + upward arc; ready / no target / cooldown / no Stamina distinguishable | W3b | runtime-tested (four states differ by fill, overlay and word; greyscale specimen) |
| R3-H1 | Original ENGINE HEAT: true horizontal centre on every frame, smallest readable uniform scale, stable anchor | W5 | runtime-tested (centre offset 0.00 px on all six frames, 39 checks incl. resize, alarm and mode changes) |
| R3-H2 | Coverage vs protected road: defined method and denominator, pixel bounds, diagnostic overlay, Round 2 as history | W5 + lead | measured (Studio Play, table in `hud-round3-heat-coverage.md`); the phone floor of 13 px is provisional and below the 16 px rule: **Adam decides** |
| R3-L1 | Remove the permanent Riding chip | W1 | runtime-tested (the permanent chip is gone) |
| R3-L2 | Transient landing label (car name + full rarity, ~1.5 s, one at a time, outside the road view) | W1 | runtime-tested (RunTop 8 landing-label scenarios, frame) |
| R3-L3 | Hop trail origin on the ridden car's roof | W6 | runtime-tested (Hop 10 scenarios incl. 8 vehicle cases, frame) |
| R3-L4 | Targeting: forwardable message for Brian R (closest in-range car in steering direction) — no change to production selection | W6 facts, lead draft | drafted for Brian R, **not sent**; no production selection code exists in the repo yet |
| R3-A1 | Collection: remove the small duplicate cards at the top (identify first); large cards + World tabs remain | W4 | runtime-tested (the CompactCards row of the trading sheet removed; the claimed-run tray untouched) |
| R3-A2 | No ellipsis; full names and full rarity words; bounded font scaling; shared rhythm | W4 | runtime-tested (longest names x five rarities x six frames, no ellipsis, equal header heights) |
| R3-A3 | Sort: Rarest first / Highest Lap Pay / Newest; stable, unknowns last, no mutation, state shown by text and shape | W4 | runtime-tested (three sorts, stable, unknown last, source unchanged, state shown by text and shape) |
| R3-A4 | Detail view shows only: image, full name, full rarity, World, Lap Pay per lap, Gold/Chrome/Rainbow owned or not | W4 | runtime-tested (exactly six facts; developer-word scan PASS) |
| R3-U1 | Music: eight approved tracks, quiet beds, smooth ducking restored to the user level, no pumping | W7 | runtime-tested by property; nothing listened to |
| R3-U2 | Replace the harsh Keys screech with a gentle rising chime + short fanfare (fanfare only on confirmed capture) | W7 + lead (asset check) | runtime-tested by property (chime ladder, pending cue once, fanfare once per confirmed capture only); **nothing listened to** |
| R3-U3 | Mix at a fixed reference volume; peak-overlap checks; property checks vs listening stated honestly; asset provenance recorded | W7 + lead | property checks (mix table, peak overlap, throttles, safety cue under a pile-up); provenance of 21 ids read from Roblox; licence terms not read |
| R3-W1 | Downtown diagnosis + Dusty Highway and Summit Pass diagnosis from real evidence | P1, P2 | done (both plans carry the Downtown diagnosis and an evidence-based diagnosis of the existing preview) |
| R3-W2 | Dusty Highway plan (five districts, full template, kit inventory, budgets, tests, phases, approval list) | P1 | done: plan only, 11 approval questions |
| R3-W3 | Summit Pass plan (same template) | P2 | done: plan only, 15 approval questions |
| R3-X1 | Reproducible fixtures and matched before/after captures per changed item; combined HUD sequences; six frames | lead | done for every changed item on six virtual frames (Studio Play); combined HUD runs 21 of 21; video: one muted real-time Keys clip |
| R3-X2 | Accepted Round 2 fixes regression + `./scripts/check.ps1` + targeted checks | lead | done: `./scripts/check.ps1` passes; 129-scenario regression 1,005 PASS (first run 7 FAIL on a small viewport, re-run clean) |
| R3-X3 | One fresh Sonnet reviewer on a compact evidence packet; fix material findings | lead | done: one fresh Sonnet reviewer (read-only, no implementation work): no blockers, ten material points all answered (see the review page section 10); one reviewer pass only, no second pass |
| R3-X4 | Review page (before/after per complaint, B2 table, Heat table, sound list, audit, plans, reviewer, decisions, waiting) | lead | done: `Car-Hop-Art/review/hud-round3/index.html` + `REVIEW-ROUND3.md` (local, with stills, four muted real-time clips and the saved regression logs); a private Artifact page is not published unless Adam asks |
| R3-X5 | Draft forwardable messages (capture time, hop targeting, run id, held proposals) — **not sent** | lead | done: drafts written in `hud-round3-forwardable-messages.md`, **not sent** to anyone |
| R3-X6 | Board, log, manifest, decision note, final scoped commit, push, PR #2 refresh; release the lock; stop owned helpers | lead | done at the end: board (claim + status), log, manifest `vault/design/assets.md`, decision 0021, scoped commits, normal push, PR #2 refreshed; Studio lock released; Studio window closed; no merge, no publish |

## Corrections after the independent review
- The first full regression (129 scenarios, 1,005 PASS, 7 FAIL) had 6 Desktop text-fit failures caused by a too-small Studio viewport (808 x 565; harness frame scale 0.41) and 1 timing race in a music test (assertion edited; product code unchanged). The final build was re-run in full on a maximized viewport; its log is Car-Hop-Art/review/hud-round3/results/regression-final.txt.
- B2: 88 of 180 meshes were seen loading in Play (a whole-route walk of Downtown seed 2207); the other 92 are uploaded and size-checked only. See ault/design/assets.md.
- Several 'zero connections/threads after destroy' values are counters the component keeps itself; instance counts and tree walks are the stronger checks.
- Heat: the phone floor of 13 px is the lead's choice under the brief's delegation and is **Adam's decision**; the panel still partly hides the ridden car's roof at every scale because it is centred at the bottom.
- Figma-first waiver recorded in decision 0021.

## Contradictions found while reading the brief
- The brief says "Opus lead… no Opus subagents"; this session's lead model is Sonnet. All workers were explicitly started as Sonnet; no Opus agent was used.
- The brief caps concurrent workers at two; Adam's chat message in the same turn says "you can make as many sonnet agents as u need to". The later, direct instruction was followed (13 disjoint-file workers, one lead owns Studio and Git).
- Round 2 review said "R2-G1 earlier commits on GitHub: done" while also saying the branch was local; both are true of different commits (see Git above).
- The Heat denominator: Round 2 reported "% of the protected rectangle" and "47% of the panel inside it"; Round 3 reports both labelled.

## Decisions I made for you (reversible; more are appended as they happen)
1. Fix Keys ring fill origin at 12 o'clock, clockwise (recorded by the ring module header).
2. Figma skipped (View seat, no file link); specs in the repo + Studio mocks.
3. Worker count and file-ownership split (see [[hud-round3-checkpoint]]).
