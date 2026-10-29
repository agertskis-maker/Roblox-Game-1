---
title: Round 2 HUD, original Heat, capture drama, collectible cards and three Worlds — preview scope
tags: [decision, lane3, ui, downtown, heat]
status: accepted for this task (preview; not a production approval)
date: 2026-10-23
---
# 0020 Round 2 presentation (preview)

Ledger [[hud-round2]]. Follows [[0019-hud-arcade-rebuild-preview]].

## Context
Adam's Round 2 brief restores the approved ENGINE HEAT panel, moves the HUD to landscape only, makes
capture and collecting feel substantial, and asks for Dusty Highway and Summit Pass at Downtown B's standard.

## Decisions
1. **Task-scoped Figma exception continues** (Adam: "Skip Figma for this task"). UI specs are still written
   (`vault/design/ui/hud-round2.md`). [[0012-figma-ui-workflow]] and earlier approvals are unchanged.
2. **Original Heat is used, not re-drawn.** `src/client/UI/RunHud/HeatGauge.luau` (approved rev 4, merged via PR #1)
   is instantiated unmodified by a new prototype adapter; the round-1 segmented bar stays in the repo, unmounted,
   as a debug-only variant. Evidence and the proven reason it was bypassed: [[hud-round2-heat-inventory]].
3. **Landscape only.** `StarterGui.ScreenOrientation = LandscapeSensor` is written to the two playground Rojo
   projects only (Adam's choice, 2026-10-23); the one-line addition for `default.project.json` is recorded in the
   ledger for the team. Portrait paths in task-owned HUD code are removed (listed in the ledger); shared input
   infrastructure is untouched.
4. **Cash is the single currency.** The run coin counter is removed; road coins are Cash pickups shown as a
   coalesced +$N cue and a Results source row (not added twice). Amounts are fixtures; the UI never grants Cash.
5. **Stamina, HOP STREAK, restoring pickups, personal-best record, route looping, best-timing window, capture
   countdown** are presentation-only fixtures, off by default in shared paths, with harness switches and held
   proposals in the ledger. No production input blocking, server deduction, pricing, saving or spawn logic.
6. **No collidable median** in the hopping corridor and no oncoming traffic; a labelled alternate boulevard
   sample and a dependency note for Brian R replace it.
7. **Canyon / collapsed-bridge gaps** are shown only in a marked hazard test area, never in the main preview route.
8. **Music:** metadata-screened candidates only, never claimed to sound good; muted exports unless external
   rights are established (the Roblox licensed-music help page could not be read: HTTP 403).
9. **B2 upload authorized** as one guided batch under the existing owner (Restricted where supported); Dusty and
   Summit kits are prepared but not uploaded until Adam grants it.

## Consequences
Removing `src/client/UI/Prototype/Run/{HeatPanel,StaminaMeter,RouteLine,SecuredReveal}.luau`, the new
`World/LandingReticle.luau`, `Cards/TradingCard.luau`, `City/Worlds/`, the new kit recipes and the playground
changes removes the round-2 work. Promotion to production needs the normal workflow and the owning lanes.

## Amendments after the independent review (2026-10-23)
10. **A claimed-tray tile opens the non-blocking claims review**, never a full-screen card detail, because a full-screen overlay
    swallows Hop and touches under a live ride. Card detail is for stopped screens (Results, Garage).
11. **On phones the display-only Stamina meter may sink into the top of the assumed thumbstick zone** (8.2 px on PhoneLandscape,
    20.7 px on PhoneSmall, limit 24) so the tappable tray stays clear of it and of the Cash. Reversible; reported as `staminaSoft`.
12. **Plan checks fail** when a district lacks its signature landmark or a `required` landmark was not placed.
13. **The Heat panel's overlap with the protected road rectangle on small frames is declared** (22 to 30%); the choice (hide the
    title tab on phones or accept) is Adam's.
14. **HOP STREAK is not built** until Adam says yes. The haptic cue is wired once per confirmed claim, with no Settings row yet.
15. **B2 upload blocked**: the OBJ (meshes only) is the package to import; the FBX is x100 scale and embeds an image. Palette
    images need a separate yes; Dusty Highway and Summit Pass uploads are not authorized.
