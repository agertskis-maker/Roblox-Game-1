---
title: HUD rebuild — worker guide (component contract)
tags: [design, spec, ui, lane3]
status: live
date: 2026-10-22
---
# HUD rebuild worker guide

Read with: `AGENTS.md`, the ledger [[hud-rebuild-downtown-b]] (your IDs and the "Component
boundaries" table), [[hud-prototype-architecture]] (the existing component contract — still
valid), and the research notes in `vault/design/research/` (hud-ref-arcade-translation,
capture-feedback, runner-progress-failure, sound-candidates). Look at the two references yourself:
`C:\Users\agert\Documents\Car-Hop-Art\references\hud\hud-ref-03-shop-index-stats-halloween.png`,
`...\hud-ref-04-rainbow-shop-timers.png`, and the current (rejected) look in
`C:\Users\agert\Documents\Car-Hop-Art\review\hud-downtown\hud\shots\`.

## The look (Adam's words, binding)
- Wide compact rectangular buttons, limited corner rounding, thick dark boundaries, strong white
  outlined labels. Icons with clear silhouette and a little illustrated depth, not tiny line
  icons. Large brightly coloured numbers on the world view, **no enclosing cards**. Crisp hard
  separation, energetic colours, purposeful asymmetry in icon poses. Lower-left stats, compact left
  menu, open space around the avatar/road. World labels read as destinations.
- NOT: pale cream dashboard, minimalist website, glassmorphism, thin outlines, pill-shaped
  everything, floating panels behind every number. NOT copying studs, game assets, exact
  composition, labels for nonexistent features, full-screen clutter.
- The rebuilt result must visibly change. Reuse correct behaviour and sound engineering, not weak
  visuals.

## Use the kit, never re-invent it
`src/client/UI/Prototype/Arcade.luau` (lead-owned): `Arcade.text`, `Arcade.button`,
`Arcade.badge`, `Arcade.toggle`, `Arcade.icon`, `Arcade.outline`, `Arcade.gloss`,
`Arcade.motorPattern`, `Arcade.make`, `Arcade.corner`. Tokens: `PreviewTokens.Arcade`
(sizes, fills, faces, outlines, Keys values). Never hard-code a colour/size that has a token;
when you need a new one, define it as a local constant at the top of your module with a comment
"TOKEN CANDIDATE" and list it in your report. The lead may retune token values after measuring;
your code must follow them. Text roles: Display/Button/ButtonSmall/Value/ValueRun/Earning/Label/
Small/Badge/Timer; `italic = true` for numbers/timers/earning line (Nunito Black Italic).
Minimum text 16 design px. Touch ≥ 48 design px (primary 56).

## Contract (unchanged from the overnight architecture)
Component module returns `{ new = function(ctx, options?) -> Component }`.
`ctx = { store, screen, layer, world, priority }` — `priority` is the screen-slot arbiter
(`Prototype/Priority.luau`): request "Center"/"Upper"/"Side" at a level (Safety > Capture >
District > Reward > Ambient) before showing anything large; release when done; handle `revoke`.
Component: `root`, `layout(self)`, `setVisible(self, on)`, `destroy(self)`, `getDebugState(self)`
(JSON-safe table with counts of live instances/connections/queued items, for leak checks), plus
typed methods your scenarios call. `--!strict`; Trove for every connection/instance; no
RenderStepped unless animating (connect while animating, disconnect when idle); reduced motion via
`Motion.reduced()` at the moment of each effect and `Motion.onReducedChanged`; `HudScale` UIScale
on your root set from `ctx.screen:uiScale()` in `layout`; `ctx.screen:profile().name` is
"Desktop" | "PhoneLandscape" | "PhonePortrait" | "Tablet"; `ctx.screen:overlapsReserved(pos,size)`
reports reserved touch zones. Sounds only through `Sounds.play(hook)`.
No remotes, DataStore, MarketplaceService, TeleportService, server code, saving, rewards or real
purchases. Preview buttons only call the callbacks they are given.

## State (lead-owned `Prototype/Store.luau`)
Read the types there: `CarRef.owned` is `boolean?` (nil = unknown; only `owned == false` may show
NEW!), `RunState.districtPlan / claims / pendingClaim / warning`, `KeysState.id / status
("Holding"|"Pending"|"Confirmed"|"Lost"|"Canceled") / reason`, `Results.endReason / joyride /
milestones`, `settings.musicOn`, `proposals.timers`. Event kinds incl. KeysStart, KeysConfirmed,
KeysCanceled, AlreadyOwned (with `captureId`), DistrictEnter (`district`, `cycle`), RareArrival
(`instanceId`, `car`), RunWarning (`reason`), Dismounted, RunEnded (`reason`), ArrivedHome. The
store deduplicates by event `id`; your component must ALSO be idempotent per `captureId` /
`instanceId` (duplicates, late and out-of-order deliveries never duplicate or reverse a state).
If you need a new field or event, do not edit Store: use a local typed shape, document it, and
list it in your report.

## Scenarios
Write your scenarios in `playground/hud/scripts/scenarios/<Area>.luau` (your file only):
```lua
--!strict
return {
	["Run: Keys full sequence"] = function(host) ... end,
}
```
`host` = `{ store, api, wait(seconds), emit(kind, fields) -> boolean, runPatch(patch), car(id),
enterRun(), log(text) }` (`wait` is cancellable; `api.components.<key>` gives mounted components).
The lead loads every file and adds the names to the debug panel list. Name scenarios after the
§18 fixture list.

## Done means
Selene and StyLua pass on your files (`selene <paths>`, `stylua <paths>`; Rokit tools are in
`~/.rokit/bin`), every requirement ID you own has code and a scenario, and your report lists:
files, public API (method signatures), the mount line the lead should add to `HudPlayground`
(`mount(key, {folder, Module}, layer, options)`), new token candidates, store additions you needed,
what is preview/synthetic, and what you could not do. You cannot run Studio; never claim anything
was tested.
