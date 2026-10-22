---
title: Island walking boost (1.5x)
tags:
  - design
  - island
  - movement
  - lane3
status: built, not tested in Studio
---

# Island walking boost (1.5x)

> [!note] Authorized, built, waiting for a Studio test
> Adam authorized the boost in the Task 4 brief (2026-10-22): "an isolated module with one enable switch, a takeover path for Brian R, no stacking, ease back over about 0.5 s; tests for respawn/disable/cleanup; wind/trail feedback with a calm reduced-motion variant; document it for Brian R on the board." Ledger row IRW-155 in [[island-rework]]. Built by Claude Code on `feature/lane3-island-environment`. **No Studio run has been done yet**; the checks below are written, not passed. Movement speed belongs to Lane 1 (Brian R); this is a small, isolated stand-in he can take over.

## Purpose
The avenue boost lanes (glowing chevron strips on the six plot avenues, IRW-84) now really speed a walker up, so the walk from a plot to the fountain and the portals is shorter. Walking only: nothing is saved, nothing is bought, nothing goes to the server.

## Behaviour and numbers

| What | Value | Where |
|---|---|---|
| Multiplier on a strip | 1.5 (WalkSpeed 16 to 24) | `WalkBoostLogic.Multiplier` |
| Held after stepping off | 0.5 s at full boost | `WalkBoostLogic.Linger` (Tunable) |
| Ease back | 0.5 s smoothstep to exactly the base | `WalkBoostLogic.Ease` (Tunable) |
| Strip half-width | 2.1 studs (from the built model's `StripHalfWidth`) | `BoostLanes.HalfWidth` |
| Height band of the root over the strip | -1 to +10 studs (a standing root is about +3, a jump peaks about +9.4) | `WalkBoostLogic.MinAbove` / `MaxAbove` (Tunable) |
| Feedback | two wind trails at the feet, stretched speed streaks behind (moving only), a faint steady glow at the feet | `WalkBoost.luau` |

- **On a strip**: the HumanoidRootPart's plan position (x = world X, y = -world Z) is within the half-width of a strip's centre segment and its height is inside the band. Strips are read from the built island (the inlay beam of each strip in `Workspace.Lane3_IslandEnvironment.BoostLanes`, broken at bridge decks), so a bridge above an avenue is not a strip.
- **No stacking**: the multiplier is a level, not a product. Re-entering, many samples in one frame, or two overlapping strips all give 1.5, never more. Re-entering during the ease returns straight to 1.5. (Rise is instant; a reversible detail chosen by Claude.)
- **Base speed kept**: the speed goes through `SpeedModifiers` (one source, `IslandBoostLane`). If anyone else sets WalkSpeed while the boost is active, their value becomes the base; when the boost ends, their value is what comes back, not 16.
- **Respawn**: each new character gets a fresh state and one fresh set of effects; death and character removal clean everything for the old one.

## Files

| File | What |
|---|---|
| `src/shared/Island/WalkBoostLogic.luau` | Pure logic: numbers, strip geometry, height band, the state machine (multiplier as a function of time and on-strip samples). One source of truth, also used by the preview walkers. |
| `src/shared/Movement/SpeedModifiers.luau` | The speed layer: per humanoid, named sources, largest wins, clamped to 1.5, exact base restore, holds nothing when idle. |
| `src/client/Home/Island/WalkBoost.luau` | The client controller: switch, takeover, strip reading, character binding, effects, reduced motion. |
| `src/client/Home/Island/WalkBoostStarter.client.luau` | Starts one controller for the local player when the switch is on. |
| `src/client/Home/Island/WalkBoostTests.luau` | The tests (below). Nothing requires it. |
| `src/island/Hub/Preview/WalkTests.luau` | Preview walkers now use `WalkBoostLogic` (so they also ease back; earlier boosted walk tables used a hard cut-off). |
| `src/island/Hub/Environment/BoostLanes.luau` | Build now tags each inlay `BoostStrip` and the model `StripHalfWidth` (needs a rebuild; until then the client falls back to the inlay names and 2.1). |

## The switch
- **Code switch (the one switch)**: `WalkBoost.ENABLED` in `src/client/Home/Island/WalkBoost.luau`. `false` turns the boost off everywhere: the starter creates nothing.
- **Run-time off**: LocalPlayer attribute `Lane3WalkBoostEnabled = false` (client side). The exact base speed comes back at once, the effects and every per-character connection are removed. Removing the attribute (or `true`) turns it back on. It is a client attribute, so it is a testing and debugging aid, not access control.
- Read-only status: the live controller writes LocalPlayer attribute `IslandBoostMultiplier` (1 to 1.5 while bound; absent when off).

## Takeover path for Brian R (Lane 1)
The boost does not need a movement system today. When Lane 1 builds one, pick either path; neither needs Lane 3 to change anything first.

1. **Keep the island boost, own the speed layer.** Replace `src/shared/Movement/SpeedModifiers.luau` with the movement system's own modifier code behind the same API: `set(humanoid, source, multiplier)`, `clear(humanoid, source)`, `clearAll(humanoid)`, `multiplier(humanoid)`, `base(humanoid)`. The island boost keeps calling `set(humanoid, "IslandBoostLane", m)` each frame it is boosted (m from 1.5 easing to 1) and `clear` when it is done. This is the contract proposed in IRW-84 with two changes: the humanoid is an argument (testable without a character), and the linger and ease are computed by the source, so there is no `seconds` argument.
2. **Own the speed outright.** The movement system sets the LocalPlayer attribute `MovementSpeedOwner` to its name (any non-empty string) whenever it owns walking speed (a run, a race, driving, or always). The island boost then stands aside completely: it clears its source (exact base back), removes its effects, drops its frame loop and per-character connections, and does nothing until the attribute is removed. To still honour the lanes, the movement system can run `WalkBoost.new({ write = false, respectTakeover = false })` and read `controller.multiplier()` or `controller.Changed` (1 to 1.5), then apply that its own way; `effects = false` turns the island's feedback off too.

Open for Brian R: whether a walking boost on the hub needs any server-side check beyond Roblox's own movement (Lane 3 assumes not: it is client-side presentation of the player's own walking speed, with no economy or saved state).

## Reduced motion
Follows `GuiService.ReducedMotionEnabled`, plus the preview-only LocalPlayer attribute `Lane3ReducedMotionOverride` (never saved), the same rule as the other island scripts. Reduced motion: no trails and no particles (existing ones are cleared), only the faint steady glow at the feet, which follows the boost level. A change applies at once, mid-boost, without waiting for a frame. The speed boost itself is the same in both modes.

## Tests
`WalkBoostTests.run(options)` returns a report table (`passed`, `failed`, `skipped`, `failures`, `results`); `WalkBoostTests.text(report)` makes it printable.

- **logic** (any mode): numbers; multiplier at fixed times (linger, ease midpoint 1.25, exact 1 at the end); monotonic, bounded ease; the state machine (enter, repeated samples, re-entry during the ease, older samples, reset); 200 seeded random sample sequences against an independent model, never above 1.5 or below 1; a 60 Hz walk across a strip (full for 0.5 s after leaving, base at 1.0 s); strip geometry, half-width edge, end caps, the world Z flip, the height band, overlapping strips.
- **modifiers** (any mode, on a stand-alone Humanoid): largest wins, no product, clamp; exact base restore; float read-back not mistaken for someone else's change; someone else's base kept; no state or connections left when idle or destroyed.
- **character** (Play mode, client): the live boost is switched off for the run and its effects are checked gone; then on the real character with test strips and a test clock: enter (24), repeats and overlap (24), effects in full motion, reduced motion mid-boost (no trails or particles, glow kept), linger and ease (24 at +0.5 s, about 20 at +0.75 s, exactly 16 at +1.0 s), re-entry while easing, someone else's base, takeover (stands aside, exact base, idle connections only, consumer mode reports 1.5 without writing), runtime disable mid-boost (exact base at once, idle connections only, no effects), destroy (zero connections); then one strip of the built island (on, off 8 studs to the side, off 30 studs above). With `{ respawn = true }`: reset from the client, then the new character is bound with the same connection count, one set of effects, fresh state, and the boost works.

Run in Studio, Play mode, through the MCP `execute_luau` tool with `datamodel_type` "Client":

```lua
local T = require(game.Players.LocalPlayer.PlayerScripts.Client.Home.Island.WalkBoostTests)
return T.text(T.run({ respawn = true }))
```

Every attribute it changes, the root's anchoring and the character's position are restored after the run. If the client-side reset does not respawn the character in Studio, the respawn rows fail with "a new character within 20 s": run again without `respawn` and reset from the server instead.

## Not done
- Not run in Studio (no playtest, no screenshots, no motion video). The feedback look (trail width, streak count, glow) is unreviewed and Tunable.
- The island needs a rebuild for the new strip attributes; the client works without them.
- Other players do not see someone else's boost effects (client-only, by design; a reversible choice).
