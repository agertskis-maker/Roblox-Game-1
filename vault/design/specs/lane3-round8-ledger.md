---
title: Lane 3 Round 8 ledger
tags: [lane3, round8, ledger]
---

# Lane 3 Round 8 ledger

Brief: [[lane3-round8]] (copy of `Car-Hop-Art/review/round8/BRIEF-ROUND8.md`). Contracts: [[lane3-round8-contracts]].
Decision: [[0044-lane3-round8]]. Evidence types: self-test, Studio Play, frame, reviewer (Sonnet), Opus review. "Not done" is
never written as a pass. Started 2026-11-08 by the lead (Claude Code, Opus 5.5).

## Setup (lead)

| ID | Status | Evidence |
|---|---|---|
| R8-S01 | done | Brief, GENERATION-NOTES, memories, board, Round 7 records read by the lead; each builder reads its own sections and images (COMMON.md). |
| R8-S02 | done | Board claim pushed to `main` (`fed3c63`, fixed in `1f26257`); worktree `Roblox-Game-1-round8` on `feature/lane3-round8` (from `feature/lane3-round7`); `integration/beta-6` (from `integration/beta-5`, worktree `Roblox-Game-1-beta6`); `feature/lane1-round8-from-adam` from `feature/lane1-round7-from-adam` (PR #17 not merged). All pushed. |
| R8-S03 | done | `CarHop-Beta-6-local.rbxl` copied from Beta 5, backup `CarHop-Beta-5-local.backup-2026-11-08.rbxl`; Rojo `beta.project.json` on port 34900 from the stage checkout `Roblox-Game-1-stage`, connected by the lead. |
| R8-S04 | asked | Clicks given to Adam in the first message (MCP Permissions: Money & monetization on, Publish & manage assets on, upload folder `Car-Hop-Art`; PR #15 Ready + Merge). Verified before asking: in the live "Car Hop Beta" Studio, `open_cloud_invoke` GET universe 200, GET developer products 200 (empty list), asset scope accepted; upload refused only for the folder. No Open Cloud key needed. |
| R8-S05 | in progress | This ledger, the contracts file, decision 0044. |
| R8-S07 | recorded | The Figma MCP is connected in this session. The lead skipped the Figma layout step: it would be one serial step in front of 14 parallel builders, and GENERATION-NOTES already gives measured LAYOUT SPEC tables (positions, radii, outlines, hex) for the cards and the button. Recorded as a deviation from Adam's standing preference. |
| R8-S07b | in progress | `layers\` still empty on 2026-11-08 (checked by the lead): every art piece is made by the builders (see the agent map). |
| R8-S08 | in progress | Agent map below. |

### Lead's calls (recorded)

1. **Every builder branches from `integration/beta-6`**, not `feature/lane3-round8` (contracts section 1): Round 7's Lane 3 work and the Beta folders live only on beta-5. The lead copies Lane 3 paths to `feature/lane3-round8` and run paths to `feature/lane1-round8-from-adam` at the end.
2. **Decision number 0044**, not 0043: Brian L's unmerged `feature/lane2-luck-in-beta` already has `0043-official-name-car-catchers.md`.
3. **Brian L's luck branch (2026-11-08) is not integrated.** It has its own LUCK kiosk and a proposed name "Car Catchers" that needs Adam's agreement (0037 stands). The brief keeps the Lucky Clover; both luck systems are listed for Adam and Brian L to choose between (note N-02). It is not a vault Replies section, so it does not override the brief.
4. **Studio stage checkout:** one Studio, one Rojo; a builder holding `STUDIO_LOCK.txt` checks out its own branch in `Roblox-Game-1-stage` so Rojo shows its work, then puts `integration/beta-6` back.
5. **Live place window:** the live "Car Hop Beta" place is open in a second Studio only for `open_cloud_invoke` (uploads, products). No Rojo, no edits, no publish from it. A Rojo pop-up there offered the stale Beta-2 server (port 34872); the lead pressed Dismiss.
6. **Stale Rojo servers** on 34872, 34885 and 34890 (Rounds 2, 6, 7): stopping them was refused by the session's permission check, so they keep running; nothing connects to them.
7. **WS split:** H-06 moved to WS-9 (the clover stand and the Pit Stop sign live in the same `PadParts.luau`); the Style Shop's Wheels and Trails tab UI (W-04, T-09 screen parts) moved to WS-3 (one `StyleStudio.luau`); trails split into visuals (WS-5a) and run moments (WS-5b); paint and decals split into WS-2a and WS-2b; upgrade cards split into Raceway + kit (WS-6a) and Parking (WS-6b). The font sweep (O-09) runs after the merges.

## Agent map (R8-S08)

Builders: Sonnet 5.5 (`model: sonnet`), each in its own worktree on `agent/r8-<ws>` from `integration/beta-6`. Reviewers: one
Sonnet 5.5 per workstream after its builder. Opus 5.5: one reviewer over everything, plus fixers.

| WS | IDs | Builder | Branch | Sonnet reviewer | Opus verdict |
|---|---|---|---|---|---|
| WS-1 Car look core | C-01, C-02, C-03 | r8-ws1 (Sonnet 5.5) | agent/r8-ws1 | pending | pending |
| WS-2a Paint audit | C-04, O-09 Galaxy | r8-ws2a (Sonnet 5.5) | agent/r8-ws2a | pending | pending |
| WS-2b Decal audit | C-05 | r8-ws2b (Sonnet 5.5) | agent/r8-ws2b | pending | pending |
| WS-3 Style Shop | C-06, C-07, W-04 (screen), T-09 (screen) | r8-ws3 (Sonnet 5.5) | agent/r8-ws3 | pending | pending |
| WS-4 Wheels | W-01, W-02, W-03, W-05, wheel icons | r8-ws4 (Sonnet 5.5) | agent/r8-ws4 | pending | pending |
| WS-5a Trail visuals | T-01, T-02, T-06, T-07, T-08, T-10, T-11, T-12, trail icons | r8-ws5a (Sonnet 5.5) | agent/r8-ws5a | pending | pending |
| WS-5b Trail moments | T-03, T-04, T-05 | r8-ws5b (Sonnet 5.5) | agent/r8-ws5b | pending | pending |
| WS-6a Raceway card + kit | U-01, U-03, U-04, U-05, U-06 | r8-ws6a (Sonnet 5.5) | agent/r8-ws6a | pending | pending |
| WS-6b Parking card | U-02, U-03, U-04, U-06 | r8-ws6b (Sonnet 5.5) | agent/r8-ws6b | pending | pending |
| WS-7 Home plots | H-01, H-02, H-03 | r8-ws7 (Sonnet 5.5) | agent/r8-ws7 | pending | pending |
| WS-8 Hubs and Roxy | H-04, H-05, H-07 | r8-ws8 (Sonnet 5.5) | agent/r8-ws8 | pending | pending |
| WS-9 Lucky Clover | L-01, L-02, H-06 | r8-ws9 (Sonnet 5.5) | agent/r8-ws9 | pending | pending |
| WS-10 Hop guidance | R-01, R-02, R-03, R-04 | r8-ws10 (Sonnet 5.5) | agent/r8-ws10 | pending | pending |
| WS-11 Round 7 UI list | O-09 | r8-ws11 (Sonnet 5.5) | agent/r8-ws11 | pending | pending |
| WS-12 Measurements | O-06, O-07, O-08 | phase 2 | | | |
| Lead | S, O-01 to O-05, N, V, F | lead (Opus 5.5) | | | |

## Requirement status

Filled in as workstreams finish. Every MUST in H, U, C, W, T, L, R, O, N, V, F gets a row with its real evidence.

8. **Fewer agents (Adam, 2026-11-09):** "start using less agents from now on ... way too much usage". From then on the lead did
   the rest alone: no more Sonnet reviewers, no Opus overall reviewer, no new agents. The paused builders were not resumed; their
   committed work was merged as it stood and its gaps are listed below as partial.
9. **Shop pass art reverted (Adam's fallback):** the Round 7 Starter Pack, VIP, Double Lap Pay and Paddock pictures are whole
   painted scenes; no clean cut-out could be made with the tools on this laptop (no image library), so the cards are back on the
   transparent pre-Round 7 icons (`GameIcons.Alias`).
10. **Decals:** Adam allowed covering the car; designs may spread 2.4x the measured door panel's length and 2x its height
    (`DecalArt.DRAMA`), clipped to the body side.

## Close (2026-11-09, lead)

### Agents that actually ran

| Model | Role | Count | Notes |
|---|---|---|---|
| Sonnet 5.5 | builders | 14 | ws1, ws2a, ws2b, ws3, ws4, ws5a, ws5b, ws6a, ws6b, ws7, ws8, ws9, ws10, ws11; all branches merged into `integration/beta-6` |
| Sonnet 5.5 | reviewers | 7 started, 2 finished | finished: ws1 (2 MUST blockers, fixed by fix1), ws5b (0 blockers, T-03/T-04 not evidenced); ws2a, ws4, ws6a, ws8, ws11 stopped at the usage limit and were not resumed (call 8) |
| Opus 5.5 | fixer | 1 | r8-fix1 (ws1 review D1, D2), merged |
| Opus 5.5 | overall reviewer | 0 | not run (call 8); the lead did one hard-rule pass instead (below) |

### Lead's review pass (hard rules, whole round diff)

New client-to-server traffic: `PickRideCar` (server checks type, length, ownership, cooldown) and `StartRun`'s car argument (used
only when owned); the look-test report remote exists only in Studio. `RealPurchases = false`; FreePurchases and BetaGrantCash
only in Studio. No countdown, streak or scarcity wording added. Every changed Luau file starts with `--!strict`; `check.ps1` passes.

### Requirement status

| ID | Status | Evidence |
|---|---|---|
| C-01 | done | CarLookApplier merged; look test |
| C-02 | done | end-to-end look test on the merged build, 40 of 40 PASS (paint, decal, wheels, trail on the run car; trail follows a real hop) |
| C-03 | done desktop, partial phone | ws1 report; ride self-test 16 PASS |
| C-04 | partial | ws2a report |
| C-05 | done (code), bolder after playtest | ws2b merged; decals 2.4x / 2x (call 10); Style Shop frames |
| C-06 | partial | ws3: tiles show the selected car (seen first pass) |
| C-07 | partial | ws3 |
| W-01, W-02, W-05 | done | ws4; 22 rim models uploaded |
| W-03 | partial | ws4 |
| W-04 | done | 17 wheel icons uploaded (assets.md) |
| T-01, T-07, T-10, T-11 | partial | ws5a |
| T-02 | done | ws5a, exhaust points per car |
| T-03, T-04 | code merged, not evidenced | ws5b review |
| T-05 (SHOULD) | not evidenced | ws5b review |
| T-06, T-08 | code done, not seen | ws5a |
| T-09 | partial | ws3 |
| T-12 | done | 19 ParticleFX flipbooks and 5 beam textures uploaded; sources in Trails.luau and assets.md |
| U-01 to U-06 | partial | ws6a/ws6b code and art merged, 26 card images uploaded; no side-by-side after upload |
| H-01 | code merged | ws7 headshot fix (root cause in ws7 report) |
| H-02 | code merged | ws7 |
| H-03 | done | lead, Studio: ghosts and EMPTY tags on the lot lines after a layout change; paint reads from the walkway; tags never overlap |
| H-04, H-05, H-07 | done | ws8, seen in Studio |
| H-06 | code merged, not measured | ws9 |
| L-01 | modelled and uploaded | ws9; 10 clover files |
| L-02 | code merged, not seen | ws9 |
| R-01 to R-04 | code merged; HOP button seen in a run | ws10; 11 HOP art images uploaded |
| O-02 | done | Roxy cut-out uploaded |
| O-03 | self-tests only | purchases self-test 15 PASS; no real prompts (RealPurchases false) |
| O-06, O-07, O-08 | not done | measurements not run (call 8) |
| O-09 | partial | ws11 items 1-6 coded, font chosen (Fredoka One), sweep not done |
| N-01, N-02 | done | `lane3-round8-for-brian-r.md`, `lane3-round8-for-brian-l.md` |
| Playtest asks (2026-11-09) | done | run declutter, ghost alignment, shop icons, bolder decals: Studio screenshots |
| F (publish) | waiting for Adam | clicks in RESULT.md |
