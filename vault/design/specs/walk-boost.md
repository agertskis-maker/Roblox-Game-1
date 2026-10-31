---
title: Island walking speed (32) and boost lanes (x1.5 = 48)
tags:
  - design
  - island
  - movement
  - lane3
status: built, not yet tested in Studio (round 2 changes)
---

# Island walking speed (32) and boost lanes (x1.5 = 48)

> [!note] Round 2 changes built, not yet tested in Studio
> **Changed 2026-10-29 (Raceway round 2, Adam).** Part 6 and Design 6 of [[raceway-round2]]: every player walks at exactly **32** on the home island (Roblox's default is 16), and the boost lanes multiply that base, so a lane gives exactly **32 x 1.5 = 48**. The lane boost used to take the base 16 to 24 and `SpeedModifiers` capped it at 24 with `max(base, min(base x m, cap))`; with a base of 32 that formula would have given no boost at all, so the cap is now the island top speed (48) and the boost multiplies the base. Also new: explicit home / boost / run ownership (the island releases completely when another system owns the speed and applies 32 once on return), and the old wind trails, speed streaks and foot glow are replaced by a small optional dust puff. The lane boost itself was authorized by Adam in the Task 4 brief (2026-10-22): "an isolated module with one enable switch, a takeover path for Brian R, no stacking, ease back over about 0.5 s; tests for respawn/disable/cleanup; wind/trail feedback with a calm reduced-motion variant; document it for Brian R on the board." Ledger row IRW-155 in [[island-rework]]. Built by Claude Code on `feature/lane3-island-environment`, changed on `feature/lane3-speedway-upgrades`. **History (old numbers 16 and 24):** tested in Studio on 2026-10-23, WalkBoostTests 206 passed, 0 failed (Play, client, with respawn), and a real character walked Plot 1 to Downtown boosted in 13.70 s with a top speed of 24 (`Car-Hop-Art/review/task4/video/boosted-walk-plot1-downtown.mp4`). **None of the round 2 changes below has been run in Studio yet.** Movement speed belongs to Lane 1 (Brian R); this is a small, isolated stand-in he can take over.

## Purpose
Walking on the home island is fast, because the island is big: 32 for everyone, 48 on the avenue boost lanes (glowing chevron strips on the six plot avenues, IRW-84), so the walk from a plot to the fountain and the portals is short. Walking only: nothing is saved, nothing is bought, nothing goes to the server.

## Behaviour and numbers

| What | Value | Where |
|---|---|---|
| Island base WalkSpeed (everyone, on the home island) | exactly 32 (Roblox default 16) | `WalkBoostLogic.IslandBase` |
| Multiplier on a strip | 1.5 | `WalkBoostLogic.Multiplier` |
| Boosted speed | exactly 32 x 1.5 = 48 (top speed) | `WalkBoostLogic.topSpeed()` and `SpeedModifiers.BoostCap` (a test keeps the two equal) |
| Ease midpoint | exactly 40 (multiplier 1.25) | `WalkBoostLogic.speed(32, 1.25)` |
| Held after stepping off | 0.5 s at full boost | `WalkBoostLogic.Linger` (Tunable) |
| Ease back | 0.5 s smoothstep to exactly the base (32) | `WalkBoostLogic.Ease` (Tunable) |
| Strip half-width | 2.1 studs (from the built model's `StripHalfWidth`) | `BoostLanes.HalfWidth` |
| Height band of the root over the strip | -1 to +10 studs (a standing root is about +3, a jump peaks about +9.4) | `WalkBoostLogic.MinAbove` / `MaxAbove` (Tunable) |
| Air grace (state guard) | 1 s of Jumping / Freefall still counts | `WalkBoostLogic.AirGrace` (Tunable) |
| Dust puff rate | at most 4 a second (one per 0.25 s) | `WalkBoostLogic.PuffInterval` (Adam's limit) |
| Dust puff life and size | 0.25 s, 0.15 to 0.35 stud | `WalkBoostLogic.PuffLifetime` / `PuffSizeMin` / `PuffSizeMax` (Adam's limits) |
| Dust: walker at rest below | 2 studs/s (horizontal) | `WalkBoostLogic.PuffMinSpeed` (Tunable) |
| Dust: low graphics detail | `SavedQualityLevel` 1 to 3 | `WalkBoostLogic.LowGraphicsMax` |

- **The formula** (`WalkBoostLogic.speed`, the same in `SpeedModifiers.target`): a multiplier above 1 gives `max(base, min(base x multiplier, 48))`; a multiplier of 1 or less gives `base x multiplier`. The result is always computed from the base, never from the speed written last time, so nothing compounds. A foreign base (someone else's WalkSpeed) is held to 48 (40 x 1.5 gives 48, not 60); a base already above 48 is left as it is, because a boost never slows anyone.
- **On a strip**: the HumanoidRootPart's plan position (x = world X, y = -world Z) is within the half-width of a strip's centre segment and its height is inside the band. Strips are read from the built island (the inlay beam of each strip in `Workspace.Lane3_IslandEnvironment.BoostLanes`, broken at bridge decks), so a bridge above an avenue is not a strip. It only counts while the humanoid is walking (see State guard).
- **Applied once, never stacked**: the multiplier is a level, not a product. Re-entering, many samples in one frame, two or three overlapping strips, a respawn, or a hold released and applied again all give 48, never more. Re-entering during the ease returns straight to 48. (Rise is instant; a reversible detail chosen by Claude.)
- **Base speed kept**: the boost goes through `SpeedModifiers` (one source, `IslandBoostLane`). If anyone else sets WalkSpeed while the boost is active, their value becomes the base (boosted by 1.5, held to 48); when the boost ends, their value is what comes back, not 32.
- **Respawn**: each new character gets a fresh state and the island base once (32 exactly one write); death and character removal clean everything for the old one.

## Island base: who owns WalkSpeed
`WalkBoost` writes 32 **once per character**, when it binds to it (first spawn, respawn, or the player coming back from a takeover), and never again.

1. **Bind**: the WalkSpeed the humanoid has right now is remembered as the **pre-island speed** (usually 16), then 32 is written. Nothing is written if it already is 32. Writes are counted (`status().islandWrites`, one per bind).
2. **While held**: nothing watches or rewrites WalkSpeed. If someone else (not through the takeover attribute) writes a WalkSpeed, **their value becomes the base** from then on: the island does not fight it, a boost multiplies it, and it is held to 48.
3. **Let go** (takeover, a switch turned off, death, character removal, destroy): the boost source is cleared first (the exact base comes back), then the pre-island speed is written back **only if WalkSpeed is still what the island wrote**. A value someone else wrote since is theirs and stays. So Brian R's controller is never overwritten, even if it writes before the island has handled the attribute event.
4. **Toggling a switch** ends the current hold and starts a new one in the same call (restore, then 32 again), so the lane switch can be tested without leaving the island speed.

## Transition ownership: home, boost, run
Three owners of a player's speed, one at a time:

| Owner | When | WalkSpeed |
|---|---|---|
| home | on the island, not in a run, not boosted | 32 |
| boost | home plus over a lane (and the 0.5 s linger and 0.5 s ease) | 32 up to 48, computed from the base |
| run (Brian R) | the LocalPlayer attribute `MovementSpeedOwner` is a non-empty string | whatever the run sets; the island does nothing |

- The agreed signal is the existing one: the LocalPlayer attribute **`MovementSpeedOwner`** (any non-empty string, or `true`). Nothing is guessed from geography. If Lane 1 has not set it up yet, the island behaves as home / boost only.
- **Attribute set**: the island releases completely. It clears the boost, writes the pre-island speed back (16) if WalkSpeed is still its own 32 (or 48 -> 32 -> 16), removes the dust emitter, stops its frame loop and drops every per-character connection (only the four idle connections remain). It writes **nothing** while the attribute is set, however many updates or frames pass.
- **Attribute cleared** (the player is back from a run or a portal): the island binds again and writes 32 **once**. The speed the humanoid has at that moment is remembered as the new pre-island value. No boost is carried over (the state is reset), so a departure during the linger does not come back boosted.
- **For Brian R**: set `MovementSpeedOwner` **before** writing WalkSpeed, and clear it after the run's speed rules end. If WalkSpeed is written before the attribute, a boost that is active would multiply that value for a frame; it is restored cleanly, but set the attribute first. Brian R's run branch (`origin/feature/lane1-run-prototype`) never reads or writes WalkSpeed (the lead checked with `git grep`) and anchors the root while riding, so nothing in the run depends on WalkSpeed staying 16 and the island base does not need his code to change. The attribute is still the contract, in case a later run writes WalkSpeed.

## The switches
Two separate switches, so turning the lanes off does not take the island speed away:

| Switch | Off means |
|---|---|
| Code `WalkBoost.ENABLED` / run time LocalPlayer attribute `Lane3WalkBoostEnabled = false` | The lane boost, its dust puffs and the strip reading are off; the exact base comes back at once. **The island base stays (32).** |
| Code `WalkBoost.ISLAND_BASE_ENABLED` / run time LocalPlayer attribute `Lane3IslandBaseEnabled = false` | WalkSpeed is left as the game has it: the pre-island speed (16) is written back at once and the island writes nothing. Lanes still work and multiply that actual base (16 x 1.5 = 24). |

- **Decision (reversible, Claude):** "off" does not remove the island base, because Adam's speed is a base rule for everyone and the boost is the optional layer on top. To turn everything off, turn both off. Reversal: make `ENABLED = false` imply no base, by checking it in `islandSwitchOn`.
- Both code switches off: `WalkBoostStarter` creates nothing. Removing an attribute (or `true`) turns that switch back on. They are client attributes, so a testing and debugging aid, not access control.
- Read-only status: the live controller writes LocalPlayer attribute `IslandBoostMultiplier` (1 to 1.5, the multiplier, not the speed, while the lane boost is bound; absent when off).

## State guard
Added for the movement review (finding M1, 2026-10-22): being over a strip only counts while the humanoid is walking, so a seated player, a swimmer or a ragdoll on an avenue gets no boost. The rule is `WalkBoostLogic.gait` and `WalkBoostLogic.stepGated` (pure, unit-tested); the client caches the humanoid's state from `Humanoid.StateChanged` and watches `Sit`, both in the per-character Trove, so nothing is polled.

| Gait | Humanoid states | Over a strip |
|---|---|---|
| walk | Running, RunningNoPhysics, Landed | counts |
| air | Jumping, Freefall | counts for the first 1 s of the spell in the air (`AirGrace`), then the normal linger and ease |
| off | Climbing, PlatformStanding (or `PlatformStand`), Physics, Ragdoll, FallingDown, GettingUp, and any other state | does not count: the normal 0.5 s linger and 0.5 s ease |
| drop | Seated (or `Sit`, or a `SeatPart`), Swimming, Dead | exact base (32) at once, no dust, state cleared; applied on the event, without waiting for a frame |

Decisions made by Claude (reversible, labelled):
- **Air grace 1 s.** A default jump is about 0.55 s, so a hop on a strip keeps the full boost; a longer fall stops counting and eases back. Jumping then Freefall is one spell; landing restarts it. Reversal: `AirGrace = 0` makes only the walk states count (the linger still carries a hop).
- **Drop, not ease, for seated, swimming and dead.** A seated driver or a swimmer should not keep 48 for another second, and standing up gives a boost only if still over a strip (nothing is carried from before the sit). Swimming speed follows WalkSpeed, so a fall into the river is not boosted. The island base (32) is not a boost and stays.
- **Ease for the other states.** Climbing, PlatformStand, ragdoll and physics states end the boost the same way stepping off does, which also covers a brief GettingUp after a stumble.
- The preview walkers (`WalkTests`) still use the ungated `step`; they model an ideal walker.

## Feedback: dust puffs only
Adam's Design 6: no speed effect at normal 32 walking, and **no full-screen speed lines, FOV pulse, motion blur or camera shake**. The previous two wind trails, the stretched speed streaks and the foot glow are **removed**. The only effect is an optional low dust puff:

- **When**: the walker is actually walking along a boost lane (`gait` is walk and the root is over a strip this sample) **and** its horizontal speed is above 2 studs/s. `WalkBoostLogic.puffWanted` is the pure rule.
- **How much**: at most one puff per 0.25 s (4 a second), whatever the frame rate (`WalkBoostLogic.puffDue`); each puff is made with `ParticleEmitter:Emit(1)` from an emitter whose Rate is 0 and which is never Enabled, so the limit is exact. It alternates behind the left and right foot.
- **Look**: lifetime 0.25 s, size 0.15 to 0.35 stud (random between the limits), soft sand-cream colour (226, 208, 172), opaque-looking for most of its life (transparency 0.1 to 0.2, gone at the end), a little upward drift, spread behind the character. Texture is the engine's own smoke (`rbxasset://textures/particles/smoke_main.dds`); nothing is uploaded. **The look has not been seen yet** (Edit mode and Play screenshots are still to do).
- **Never**: at rest, at normal walking off a lane, in the air, seated or swimming, **after leaving the lane** (the linger and ease keep the speed, not the dust), under Reduced Motion, or at low graphics detail. It stops at rest and on exit. No HUD, no label, nothing on the camera, no change to jump power, collision or animation.
- **Reduced Motion**: follows `GuiService.ReducedMotionEnabled`, plus the preview-only LocalPlayer attribute `Lane3ReducedMotionOverride` (never saved), the same rule as the other island scripts. A change applies at once and clears the puffs on screen. The speed boost itself is the same in both modes.
- **Low graphics detail**: `UserSettings():GetService("UserGameSettings").SavedQualityLevel` at levels 1 to 3 (`WalkBoostLogic.lowGraphics`; Automatic, level 0, is not treated as low). No earlier pattern for this existed in the code. The preview-only LocalPlayer attribute `Lane3LowGraphicsOverride` (true or false) forces it for tests. The read is guarded by `pcall` and costs one property read while a puff is possible.
- **Decision (reversible, Claude):** Adam's brief also says "one entry label WALK BOOST x1.5 is sufficient". The task for this change said not to add any HUD or label, so none was built. Reversal: a small label in the UI lane, with its own Figma spec first.

## Files

| File | What |
|---|---|
| `src/shared/Island/WalkBoostLogic.luau` | Pure logic: numbers (`IslandBase`, `Multiplier`, `topSpeed`), the speed formula (`speed`), strip geometry, height band, the state machine (multiplier as a function of time and on-strip samples), the state guard (`gait`, `counts`, `stepGated`), the dust rules (`puffWanted`, `puffDue`, `lowGraphics`). One source of truth, also used by the preview walkers. |
| `src/shared/Movement/SpeedModifiers.luau` | The speed layer: per humanoid, named sources, largest wins, computed from the base, `BoostCap` 48 and `target()`, exact base restore, holds nothing when idle. |
| `src/client/Home/Island/WalkBoost.luau` | The client controller: both switches, the island base hold, takeover, strip reading, character binding, dust puffs, reduced motion and low graphics. |
| `src/client/Home/Island/WalkBoostStarter.client.luau` | Starts one controller for the local player when either switch is on and the island's lanes exist. |
| `src/client/Home/Island/WalkBoostTests.luau` | The tests (below). Nothing requires it. |
| `src/island/Hub/Preview/WalkTests.luau` | Preview walkers use `WalkBoostLogic` (ease, and now `speed` so a boost is held to 48); new option `island = true` starts them at 32 as a player would. Default behaviour (16, 24 boosted) is unchanged. |
| `src/island/Hub/Environment/BoostLanes.luau` | Build tags each inlay `BoostStrip` and the model `StripHalfWidth` (needs a rebuild; until then the client falls back to the inlay names and 2.1). |

## Takeover path for Brian R (Lane 1)
The boost does not need a movement system today. When Lane 1 builds one, pick either path; neither needs Lane 3 to change anything first.

1. **Keep the island speed and boost, own the speed layer.** Replace `src/shared/Movement/SpeedModifiers.luau` with the movement system's own modifier code behind the same API: `set(humanoid, source, multiplier)`, `clear(humanoid, source)`, `clearAll(humanoid)`, `multiplier(humanoid)`, `base(humanoid)`. The island boost keeps calling `set(humanoid, "IslandBoostLane", m)` each frame it is boosted (m from 1.5 easing to 1) and `clear` when it is done. The island base (32) is written by `WalkBoost`, not by `SpeedModifiers`, so it stays when this file is replaced; the replacement should compute from the humanoid's base and hold a boost to 48 (`target(base, m)`). This is the contract proposed in IRW-84 with two changes: the humanoid is an argument (testable without a character), and the linger and ease are computed by the source, so there is no `seconds` argument.
2. **Own the speed outright.** The movement system sets the LocalPlayer attribute `MovementSpeedOwner` to its name (any non-empty string) before it writes WalkSpeed, whenever it owns walking speed (a run, a race, driving, or always), and clears it when it hands the player back to the island. The island then stands aside completely (see Transition ownership). To still honour the lanes, the movement system can run `WalkBoost.new({ write = false, respectTakeover = false })` and read `controller.multiplier()` or `controller.Changed` (1 to 1.5), then apply that its own way; `effects = false` turns the island's dust off too. A consumer never writes WalkSpeed, so it never applies the island base.

Open for Brian R: whether a walking boost on the hub needs any server-side check beyond Roblox's own movement (Lane 3 assumes not: it is client-side presentation of the player's own walking speed, with no economy or saved state). The client changes WalkSpeed on its own character, which Roblox accepts from the network owner; a server-side speed check would have to allow 32 and 48 on the island.

## Tests
`WalkBoostTests.run(options)` returns a report table (`passed`, `failed`, `skipped`, `failures`, `results`); `WalkBoostTests.text(report)` makes it printable.

- **logic** (any mode, Edit or Play): numbers (island base 32, 32 x 1.5 = 48); multiplier at fixed times (linger, ease midpoint 1.25 and speed exactly 40, exact 1 and 32 at the end); monotonic, bounded ease; the speed formula (32 to 48, the old 16 to 24, a foreign 20 to 30, 40 held to 48, 48 and 60 not slowed, 500 seeded random bases and multipliers, 100 repeats never compound); the state machine (enter, repeated samples, re-entry during the ease, older samples, reset); 200 seeded random sample sequences against an independent model, never above 1.5 or below 1; a 60 Hz walk across a strip; the state guard (gait of every humanoid state, Sit and PlatformStand flags, air grace edges, `stepGated` for not walking, seated, a 1 s hop, a long fall, a jump onto a strip, and 200 seeded random gait sequences against an independent model); strip geometry, half-width edge, end caps, the world Z flip, the height band, overlapping strips; **dust rules**: the limits (0.25 s, 0.15 to 0.35, 4 a second), low graphics levels 0 to 10, wanted when walking along a lane at speed, none at rest or at the threshold, none at 32 off a lane, none under Reduced Motion, none at low graphics, none in the air, off or seated, `puffDue` first, early, on time and clock-backwards, and a 10 s stream at 30, 60, 144 and 240 Hz with every gap at least 0.25 s and any five puffs taking at least 1 s.
- **modifiers** (any mode, on a stand-alone Humanoid): `BoostCap` equals the island base x multiplier, `target` equals `WalkBoostLogic.speed`; largest wins, no product, clamp; the island base 32 boosted to exactly 48, 100 repeated sets never compound, eased 1.25 gives exactly 40, clear gives exactly 32; the old 16 to 24; exact base restore; float read-back not mistaken for someone else's change; someone else's base kept (20 to 30, 40 held to 48, 60 left alone); no state or connections left when idle or destroyed.
- **character** (Play mode, client): the live boost and island base are switched off for the run (the pre-island 16 comes back) and the effects are checked gone; then on the real character with test strips and a test clock:
  - **island base**: exactly 32 on bind, written once, pre-island 16 remembered, never written again by 50 updates in a frame, a foreign base, many updates or random sequences;
  - **boost**: enter (48), repeats and three overlapping strips (48), linger and ease (48 at +0.5 s, about 40 at +0.75 s, exactly 32 at +1.0 s), re-entry while easing, someone else's base (20 gives 30, 40 held to 48, theirs comes back), 300 seeded random entries, exits and overlaps (never above 48, never below 32);
  - **takeover**: stands aside, exactly 16 back, effects gone, idle connections only; another controller's 23 written and 8 frames of updates later still 23 with no island write counted (and exactly one WalkSpeed change seen, the other controller's own); cleared gives 32 once with the same connection count and boost working; takeover during the linger with the other controller writing before the island saw the event (its 23 is kept, 23 is remembered as the pre-island value on return, no boost carried back); consumer mode reports 1.5 without writing and without an island base;
  - **switches**: lanes off (boost gone, 32 kept, only the island connection, no effects), island off as well (16 back, idle connections only), lanes on with island off (16 x 1.5 = 24), both on again (same connection count, 32, then 48);
  - **state guard** on the real humanoid (`Sit` on a strip: exactly 32 and no dust at once without an update; stand up on the strip: 48; stand up off it: 32; `PlatformStand`: linger, ease, exactly 32; connection count unchanged);
  - **dust**: the emitter's lifetime, size, colour, opacity, Rate 0 and not Enabled; one attachment and one emitter and no trails, streaks or glow; none at rest on the lane, puffs while moving along it (6 to 9 in 2 s, gaps at least 0.25 s, any five at least 1 s), none under Reduced Motion, none at low graphics, back when both are off, none at rest, none after leaving the lane (while the linger still holds 48), none at normal 32 walking off the lane (the speed back to exactly 32);
  - destroy (16 back, zero connections); then one strip of the built island (on, off 8 studs to the side, off 30 studs above, exactly 32 after the ease). With `{ respawn = true }`: reset from the client, then the new character is bound with the same connection count, one set of effects, exactly one island write (counted) and still 32 half a second later, fresh state, the boost works (48), destroy hands back 16.

Run in Studio, Play mode, through the MCP `execute_luau` tool with `datamodel_type` "Client":

```lua
local T = require(game.Players.LocalPlayer.PlayerScripts.Client.Home.Island.WalkBoostTests)
return T.text(T.run({ respawn = true }))
```

Every attribute it changes, the root's anchoring and the character's position are restored after the run, and the live controller then applies 32 again. If the client-side reset does not respawn the character in Studio, the respawn rows fail with "a new character within 20 s": run again without `respawn` and reset from the server instead. In Edit mode only the logic and modifiers groups run (the character group is skipped).

## Not done
- **Not run in Studio** (no playtest, no screenshots, no motion video) for any round 2 change: the island base, the takeover and switch tests, the dust puffs. The tests were written but not run, and nothing was run in a Luau analyzer (only Selene and StyLua).
- The dust look (colour, texture, size, how it reads at 48) is unreviewed and Tunable. Motion review needs a real-time video, per `CLAUDE.md`.
- At 32 and 48 the default Animate script scales the walk and run animation with WalkSpeed. The feet-against-ground check, camera follow, fence, lake and waterfall edges and jump distance at the new speed that Adam asked for in Part 6 are separate tasks and are not covered here; no animation, camera, collision or jump value was changed.
- The island needs a rebuild for the new strip attributes; the client works without them.
- Other players do not see someone else's dust (client-only, by design; a reversible choice).
