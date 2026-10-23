---
title: HUD prototype architecture (overnight preview)
tags: [design, spec, ui, lane3]
status: preview
date: 2026-10-22
---
# HUD prototype architecture (overnight preview, not production)

All prototype code lives in `src/client/UI/Prototype/` (modules only). Nothing in the game's
normal entrypoints requires it. The only thing that starts it is the playground bootstrap in
`playground/hud/` which Rojo maps only through `playground/hud.project.json`; the bootstrap
checks `RunService:IsStudio()` AND `ReplicatedStorage.Lane3Playground` (a Configuration with
attribute `Kind = "hud"`) that exists only in that project. `default.project.json` maps neither.

## Core (lead; do not edit from a worker)
- `PreviewTokens` — additive preview colours, rarity ladder (label + pips 1–5), sizes, motion.
- `Motion` — `tween(instance, key, info, goal)` (cancels the previous tween on the same key),
  `cancelAll(instance)`, `reduced()`, `onReducedChanged(fn) -> disconnect`, `pop(gui, scale?)`,
  `press(gui, down)`, `info(seconds, style?, dir?)`.
- `Sounds` — `play(hook)`; hooks: Tap Open Close CashGain CashBig CashSpend Toast TutorialDone
  Unlock LapPay KeysTick KeysCapture Hop Dash Milestone ResultsCount NewBest. Silent unless
  configured; counted.
- `Store` — `get()`, `set(key, value)`, `subscribe(key, fn) -> disconnect`, `setMode(mode) ->
  boolean` (Home→Run, Run→Results|Home, Results→Home|Run), `emit(event) -> boolean` (dedupe by
  id), signals `Changed(key, state)`, `ModeChanged(mode, from)`, `Event(event)`. Types `State`,
  `CarRef`, `RunState`, `Results`, `Event` are exported.
- `Screen` — virtual device frame: `root`, `safe`, `uiScale()`, `profile()`, `Changed(profile)`,
  `rectOf(gui) -> (pos, size)` in device px, `overlapsReserved(pos, size) -> zoneName?`.
  Profiles Desktop 1920×1080, PhoneLandscape 844×390, PhonePortrait 390×844, Tablet 1180×820.
- `Gloss` — `make`, `corner`, `stroke`, `gradient`, `shadow`, `highlight`, `panel`, `title`,
  `label`, `badge`/`setBadge`, `button(parent, spec) -> Button` (press, hover ring = selection
  ring, debounce, sound hook, disabled grey).
- `Fixtures` — synthetic cars (roster names, proposed), balances, tutorial steps; `ProxyCar`
  builds an original part-built scale proxy car Model (labelled proxy) from a CarRef.

## Component contract (workers)
Each component is a ModuleScript returning `{ new = function(ctx: Ctx): Component }`:

```
Ctx = {
  store: Store.StoreObject,
  screen: Screen.ScreenObject,
  layer: Frame,      -- a full-size transparent Frame inside screen.safe for this component's layer
  world: Folder,     -- Workspace folder for world-space pieces (billboards, rings)
}
Component = {
  root: GuiObject?,                 -- the component's top GuiObject (has UIScale "HudScale")
  layout: (self) -> (),             -- re-place for screen:profile(); called on Screen.Changed
  setVisible: (self, boolean) -> (),
  destroy: (self) -> (),            -- disconnect everything (Trove), cancel tweens
  -- plus any typed methods the playground scenarios call (documented in the module header)
}
```
Rules: `--!strict`; Trove for every connection/instance; no RenderStepped per component unless
animating (connect while animating, disconnect when idle); never clone models per frame; reduced
motion read through `Motion.reduced()` at the moment of each effect and on
`Motion.onReducedChanged`; set `HudScale.Scale = ctx.screen:uiScale()` in `layout`; sizes in
design px; no remotes, DataStore, MarketplaceService, TeleportService or server code; preview
buttons only call the callbacks they are given. Fredoka One via `Tokens.font()`; minimum text 16.
Colour is never the only signal (labels, pips, segments, icons).
