---
title: Speedway upgrade board, level-up banner and preview panel
tags: [design, ui, speedway]
status: draft
---

# Speedway upgrade board, level-up banner and preview panel

- **Workflow:** task-scoped Studio-first exception to the Figma-first rule (`AGENTS.md`, [[0012-figma-ui-workflow]]), approved by Adam on 2026-10-28 for this task only ("Studio-first exception"): specified here, built in the preview marked PREVIEW, reviewed by Adam at the final review. A Figma mock can follow if Adam wants one. Not a workflow change.
- Approval: pending (Adam, final review of the Speedway upgrade looks task).
- Fonts and touch targets from the approved tokens (`src/shared/UI/Tokens.luau`): Fredoka One, 36 display / 24 value / 18 label / 16 minimum; touch targets 48 px minimum. No other font or size is introduced.
- Colours from the island and HUD palette: navy `#243A62` panels, cream `#FFF6E0` text, yellow `#FACE46` headings, mint `#80D8BD` PREVIEW tags, coral `#F47F70` accents, near-black navy `#141B33` outlines.

## 1. Kiosk upgrade board (world sign, every plot)
- Where: a standing board beside the Paddock kiosk, plot frame x 31.6, u 252.4, facing the park; 4.6 x 5 studs on two cream posts, navy face with a red-orange cap. Built by `Props.kioskBoard`, filled by `Home/Island/Speedway/Kiosk`.
- Content, top to bottom: "SPEEDWAY LEVEL n" (yellow), the current level's name (cream), "NEXT: NAME" (cream), a picture of what the next level adds (the next level's main piece in a ViewportFrame, seen from the plaza side), one line of what it adds, and "PRICE: PREVIEW" (mint). No currency amount: prices are Lane 2's.
- Top level: "TOP LEVEL!" and "Every look is built." with the PREVIEW tag, never an invalid next level.
- Nothing to press; it is a sign. Purchases and prompts belong to Lane 2.

## 2. Level-up banner (HUD, on a level-up of your own plot)
- Text: `SPEEDWAY LEVEL 5: THE FLAG OFFICIAL!` (Ladder.banner), Fredoka One 36, cream with a near-black navy outline, on a navy pill with a coral border, top centre (14 % down), above the gameplay HUD.
- Motion: scales in with a small bounce (0.45 s), holds about 2.7 s, fades (0.4 s). Reduce Motion: fades in and out in place.
- Never blocks input (no button, no modal).

## 3. Ghost preview (world, your plot only)
- The next level's main piece as a faint light-blue outline (82 % transparent, no text, no figures, no lights, no collision), so kids see what they are working toward. Your plot only, so other plots stay clean. Off for clean captures (preview panel "Ghost").

## 4. Preview panel (Studio playtests only)
- Bottom left, navy panel: "SPEEDWAY PREVIEW · Plot n · Level n", then buttons "-" and "+" (56 x 48), "Plot" (cycles the plot it drives) and "All" (every plot at this level), then "Ghost", "Calm" (the preview-only Reduce Motion override) and "Hide". All buttons at least 48 px tall, Fredoka 18.
- Only in Studio (`RunService:IsStudio()`); it sets LocalPlayer attributes only. Never part of the game.
