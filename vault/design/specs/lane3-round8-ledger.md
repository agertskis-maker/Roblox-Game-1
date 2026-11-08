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
