---
title: HUD arcade rebuild and Downtown B production start — preview scope
tags: [decision, lane3, ui, downtown]
status: accepted for this task (preview; not a production approval)
date: 2026-10-22
---
# 0019 HUD arcade rebuild and Downtown B production start (preview)

Numbered 0019: 0016 and 0017 exist on the island branch, and 0018 exists both here and (for a
different topic) in the island worktree; resolve the duplicate 0018 when the branches meet.

## Context
Adam's brief of 2026-10-22 (ledger [[hud-rebuild-downtown-b]]) rejects the overnight HUD's look,
supplies two new HUD references, selects Downtown direction B, and asks for a capture sequence,
run presentation and a reusable B scenery kit — all as previews in the task's local places.

## Decisions
1. **Task-scoped Figma exception.** Adam: "Skip Figma for this task. I authorize Studio mocks and
   implementation of these Lane 3 previews without the normal intermediate Figma approval."
   Applies to this task's Lane 3 preview screens only. [[0012-figma-ui-workflow]] and every
   earlier approval record are unchanged; the UI spec `vault/design/ui/hud-arcade-rebuild.md`
   is still written.
2. **Supersessions by Adam's explicit decision:** Cash and car count bottom left (was top left in
   rev 4 and the dino study); Settings is a labelled small red rectangle (was a 48 px gear).
   The rev-4 CurrencyCounter and its gain behaviour are reused unchanged, only re-anchored.
3. **Downtown B selected** (Adam). A and C are not developed further; their files stay.
4. **One arcade kit** (`src/client/UI/Prototype/Arcade.luau`) with a scoped `Arcade` token block
   in `PreviewTokens`; the shared `src/shared/UI/Tokens.luau` is not changed by this task.
5. **Fire station replaced** by a fictional delivery depot / roadside service workshop
   (`AGENTS.md` vehicle rule 5).
6. **Interfaces held**: proposals live in the ledger only; nothing is sent to Lane 1 or Lane 2.

## Consequences
Removing `src/client/UI/Prototype/`, `src/lookdev/`, `playground/` and the new kit files removes
the task. Promotion to production needs the normal workflow and the owning lanes' contracts.

## Added 2026-10-23 (Studio phase; all reversible, preview only)
7. **Per-segment mesh merge in Play.** Measured in Studio: a playtest client holds only 8
   EditableMeshes (with or without FixedSize). The city therefore merges each live road segment's
   kit pieces into one EditableMesh in Play (`src/lookdev/Downtown/City/Merge.luau`); edit mode keeps
   one EditableMesh per kit piece. Uploading the kit (3D Importer, `assets/downtown/kit-b/MANIFEST.md`)
   would remove this workaround; it was not done (no upload in this task).
8. **Kit catalogue is kit-first.** When the B2 kit is present the built-in placeholder lots are
   dropped; lot/landmark metadata is read from the mesh files (the manifest has no module/width/
   height class).
9. **Layout rules from Studio captures:** Heat stays bottom centre (avoids Hop and touch zones, not
   the protected region); Keys never enters a touch zone; on phone landscape the ride chip steps
   aside during a capture; run-time Cash/count sit in the top row on phone landscape and tablet and
   above the thumbstick on portrait; portrait Home uses a two-column menu with the stats above the
   Jump zone; the ridden car's nameplate shows only while it is being captured.
10. **City-synced districts in the HUD playground:** over the city, the run distance is the route
    position at the provisional 1 stud = 0.28 m and the district plan is the city's boundary table.

## Added 2026-10-23 (after the independent review; all reversible, preview only)
11. **Viewport vs GUI space.** Measured in Studio: `Camera:WorldToViewportPoint` counts from the
    window top, `AbsolutePosition` counts from below the 58 px Roblox top bar for every ScreenGui,
    `IgnoreGuiInset` or not. World-to-HUD code adds `GuiService:GetGuiInset()` (Nameplates,
    `RunLayout.worldToCanvas`, CashLine's world-pickup origin). Before the fix, plates and the
    Keys rider anchor were judged 58 px lower than drawn.
12. **Nameplates never sit under the run HUD.** The host passes HUD rectangles (strip, coins,
    Settings, ride chip, Heat, Hop, tray, an entry banner, the stats) with 10 device px of
    clearance; a plate that touches one is hidden, the ridden and Hop-target plates included (the
    ring and arc still mark the target).
13. **Keys ring placement falls back to a least-overlap scan** when no preferred spot is clear;
    only one "SECURING…" is on screen at a time (the tray slot stays ghosted without its caption
    while the ring says it).
14. **Every district shows its signature landmark.** The bridge arch is placed first at the deck
    centre; any district still missing its signature gets it at the free frontage nearest its
    centre. Shop names never repeat within 400 studs (either side). Skyline landmarks start 90
    studs behind the frontage line with a 144-stud view gap kept clear of lots and masses (the
    stadium was 565 studs out, never in a forward camera view). Harbour water is a plain part
    under each bridge deck (no EditableMesh).
15. **Playground only:** the backdrop rides a Revolution 6 (the car the Keys scenarios capture)
    and the ridden plate follows `run.ride`; Roblox's health bar is hidden (the "empty dark bar top
    right" was the harness character's health).
