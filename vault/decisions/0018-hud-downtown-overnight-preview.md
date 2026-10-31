---
title: Overnight HUD prototype and Downtown look development — preview architecture
tags: [decision, lane3, ui, downtown]
status: proposed (preview; nothing here is a production approval)
date: 2026-10-22
---
# 0018 Overnight HUD prototype and Downtown look development (preview)

Numbered 0018 because 0016 and 0017 are taken on the island branch (not merged yet).

## Context
Adam's overnight brief (2026-10-22) approved building an isolated HUD prototype and three
Downtown visual studies, Studio-first, under a one-night UI preview exception (not a production
approval, not a change to [[0012-figma-ui-workflow]], no Downtown direction selected).

## Decisions (reversible)
1. **Isolation by marker, not by deletion.** The prototype lives in `src/client/UI/Prototype/`
   (ModuleScripts that do nothing unless required) and starts only from
   `playground/hud/scripts/HudPlayground.client.luau`, which needs Studio AND
   `ReplicatedStorage.Lane3Playground` with `Kind = "hud"`. That marker and the playground scripts
   exist only in `playground/hud.project.json`; `default.project.json` maps neither. Same for
   `playground/downtown`.
2. **Virtual device frames instead of the Studio device emulator.** The emulator needs clicks;
   the prototype lays itself out inside a device-sized frame (Desktop 1920×1080, phone
   844×390 / 390×844, tablet 1180×820) with assumed insets and reserved touch zones applied once.
   Layout evidence only; no device performance.
3. **Reuse the approved HUD unchanged.** CurrencyCounter, CashIcon, Distance option B and the
   ENGINE HEAT panel are reused as-is; new looks are additive preview tokens
   (`Prototype/PreviewTokens.luau`). The top-left segmented Heat bar is a toggleable PROPOSAL.
4. **One state store with explicit modes and deduplicated events** (`Prototype/Store.luau`),
   filled by preview adapters from synthetic fixtures (`playground/hud/scripts/Scenarios.luau`).
   Interfaces for the owning lanes are proposed, not agreed (ledger "Interfaces").
5. **Harness captions are hidden from the player-facing view.** "PROXY", "Preview values",
   "placeholder times", "Pass concept (not approved)" and preview-only button results go to a
   harness layer (captions toggle, debug panel, output log); a watermark outside the device frame
   says "preview".
6. **Downtown kit mirrors the island pipeline.** Headless Blender recipes in
   `assets/downtown/kit/` → JSON mesh data in `Car-Hop-Art/downtown-kit/` → an edit-mode Studio
   builder using EditableMesh previews (`src/lookdev/Downtown/Builder.luau`). No upload overnight;
   previews do not reach a playtest, so Play-mode performance of the studies is not measured.
7. **No audio inserted.** UI sound hooks are typed and silent until a verified, permitted sound
   is configured and Adam has listened.

## Consequences
Everything can be deleted by removing the folders above and `playground/`. Promoting any part to
production needs a Figma spec, owner approval and the owning lanes' contracts.
