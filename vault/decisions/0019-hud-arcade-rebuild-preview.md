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
