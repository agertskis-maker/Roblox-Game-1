---
title: HUD arcade rebuild — UI spec (preview)
tags: [design, ui, lane3, preview]
status: preview — task-scoped Studio-first exception; owner review pending
date: 2026-10-22
---
# HUD arcade rebuild — UI spec (preview, 2026-10-22)

**Scope of the Figma exception.** Adam, 2026-10-22: "Skip Figma for this task. I authorize Studio
mocks and implementation of these Lane 3 previews without the normal intermediate Figma
approval." This spec covers only this task's Lane 3 preview screens in the task's local test
places. [[0012-figma-ui-workflow]] still applies to everything else and to promoting any of this
to production. Decision: [[0019-hud-arcade-rebuild-preview]]. Ledger: [[hud-rebuild-downtown-b]].
Supersedes the visual parts of [[hud-prototype-overnight]] for the rebuilt components only.

All values live in `src/client/UI/Prototype/PreviewTokens.luau` (`Arcade` block) and are preview
values measured from the two new references ([[hud-ref-arcade-translation]]). Design px at scale
1.0; 1080p = ×1.5 (approved scale rule).

## Type
| Role | Face | Size | Outline |
|---|---|---|---|
| Display (headings) | Fredoka One (approved) | 36 | 2.5 near-black navy |
| Button label | Fredoka One | 28 (shrinks to fit, ≥ 16) | 2.5 |
| Settings label | Fredoka One | 18 | 1.75 |
| Cash | approved CurrencyCounter (Fredoka One, green gradient) | 40 (approved) | 3.5 (approved) |
| Car count | Nunito Black Italic (candidate: verified installed, weight 900 = Heavy) | 40 | 2.5 |
| Earning line, timers | Nunito Black Italic | 22 | 1.75 |
| Labels / minimum | Fredoka One | 18 / 16 | 1.75 |
Italic is a task-level candidate (no approved italic exists; Fredoka One has no italic face). No
row is rotated to fake italics.

## Buttons
Wide 150 × 60 (≈ 2.5:1), compact 124 × 50 (phones), Settings 84 × 40 visual with a 48 hit box;
corner 5; boundary 3 near-black; shallow 4 px dark lip; narrow gloss band (22% of height);
fills: Shop rainbow (drifts slowly sideways, stops in reduced motion), Garage cyan→blue, Missions
orange, Settings red, RETRY orange, GO HOME teal. Icons 0.74 × height on the left, inside the
edge, with a slight tilt; label right, dominant. Faint original bolt/tread motif on large buttons
only. Badges: red 26 px circles with a dark outline pinned outside the top-right corner on the
non-scaling root (earned items only; Shop only for actual free fixture claims).

## Home composition
Left-centre column: Settings (red, labelled, centred on the stack) → Shop → Garage → Missions →
Music toggle. Bottom left, no panels: car count (cyan icon + italic cyan number; inert "+" inside
the emblem), Cash (approved counter, re-anchored), italic white earning line "Speedway: +$120 /
lap" (PREVIEW). Optional timer stack bottom right is a proposal, off by default. No right-side
squares, no hotbar. Phones: compact column; stats above/beside the thumbstick zone; portrait has
its own compact arrangement.

## Run composition
Top centre district strip (rolling window, avatar head + distance); entry banner below it;
bottom-centre Heat (dark frame, segmented, flame); Keys beside the rider; left-middle claimed
tray; bottom-left compact Cash/count; Hop bottom right. Protected road-ahead region kept clear.
Screen-slot priority: Safety > Capture > District > Reward > Ambient (`Prototype/Priority.luau`).

## Keys capture
Gold 8-segment ring (proposal; brief range 8–12), dark boundary, key-in-lock centre, percentage
secondary, HOLD ON → ALMOST! (once at 75%) → SECURING… (pending) → lock opens on confirmation →
side ribbon YOU GOT THE KEYS! + car + Keep going! (≈ 1.6 s) → tray stamp. Cancel: ring fractures
and fades with a truthful reason. Rarity colour only as an accent; gold = capture, teal = Hop.

Exact component specs, states and timings are in each module's header (the source of truth for
this preview) and summarised on the review page.
