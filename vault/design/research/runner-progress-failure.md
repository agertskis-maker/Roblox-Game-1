---
title: Runner progress, failure reasons, nameplates and rare reveals
tags: [research, ui, lane3]
date: 2026-10-22
---

# Runner progress, failure reasons, nameplates and rare reveals

Research only. Nothing here is approved. Numbers marked **(reversible)** are my own starting guesses for a prototype, not decisions. Heat stages, labels and flash limits come from [[0008-heat-critical-meltdown]] and are not reopened here.

## Sources

| # | Source | Kind | What I used it for |
|---|---|---|---|
| L1 | `Car-Hop-Art\references\dino-game\dino-ref-frame-08.jpg`, `-27.jpg`, `-56.jpg` (opened and looked at) | Local frames, a Roblox dino-taming runner, desktop window 1440 px wide | Biome strip, avatar head marker, best marker, zone banner, nameplates |
| L2 | `Car-Hop-Art\references\dino-game\11_REFERENCE_DINO_STAMPEDE_ANALYSIS.md` | Local analysis (team-written) | The "STOMPED!" warn-then-fail sequence (section 2.3), nameplate clutter (section 7) |
| E1 | https://en.wikipedia.org/wiki/Subway_Surfers | Encyclopedia | Crash ends the run; continue with keys or an ad; setting rotates by "World Tour" update |
| E2 | https://en.wikipedia.org/wiki/Temple_Run_2 | Encyclopedia | Fall or obstacle ends the run; short rescue window; continue with gems |
| E3 | https://www.gamezebo.com/2016/12/12/hill-climb-racing-2-tips-cheats-strategies/ | Guide (2016) | Hill Climb Racing 2: one yellow number is distance-to-goal in Cups but distance-travelled in Adventure |
| D | create.roblox.com engine reference (links in section 3) | Official docs, fetched 2026-10-22 | BillboardGui, Camera, WorldRoot.Raycast, ScreenGui |

The local game is not named here; I identify it only by what is visible. No popularity claims are made. The Hill Climb Racing 2 fan wiki (`hillclimbracing2.fandom.com/wiki/Adventures`) refused automated fetches (HTTP 402), so nothing from it is used.

## 1. Progress presentation in long and endless runners

### Observed in the local reference (L1)
- **Strip:** top centre, right of the Roblox core buttons. Ten square picture tiles in one row, each with its zone name in a small white outlined label across the top: Plains, Forest, Desert, Jungle, Snow, Giant Forest, Abyss Ocean, Volcano, Extinction, Cosmic. Each tile is a little landscape painting of its zone, so the tiles are readable by colour alone. Tiles touch, with thin dark borders. Strip is about 540 px wide in a 1440 px window (about 54 px per tile).
- **Avatar head marker:** a round portrait of the player's avatar in a white ring with a dark outline, hanging just below the tiles, with the distance in a dark pill under it: "99 m" (frame 08, under Plains), "905 m" (frame 27, under the left half of Forest), "2,131 m" (frame 56, under the right half of Forest). The number uses thousands separators.
- **Best marker:** a small "BEST 1,169 m" label printed in yellow inside the Forest tile, with a small yellow diamond pointer at the bottom edge of the tile (frames 08, 27). In frame 56 it reads "BEST 2,137 m" and sits almost on top of the head marker at 2,131 m; the two overlap and are hard to read.
- **Zone entry banner (frame 27):** a slim, full-width, translucent dark band across the upper third of the screen, below the strip, with a yellow smiley icon and the zone name "Forest" in pale bold text. No distance, no subtitle. It overlays the world rather than the strip.
- **Nameplates bleed through the HUD:** in frame 27 world nameplate words ("Uncommon", "Common") are visible poking above and behind the strip tiles.
- **Inferred, not proven:** the head moves from about the left of Forest at 905 m to its right edge at 2,131 m, while Plains holds 0 to roughly 900 m. So the tiles are equal on screen but probably not equal in metres, or the mapping is not linear. The strip is finite: Cosmic is the last tile, which tells the player the world ends there. That suits a game with a final zone; it would be wrong for an endless run.

### External examples (E1 to E3)
- **Subway Surfers (E1).** Observed in source: a crash gives game over; the player may continue with keys or by watching an ad; the setting changes per "World Tour" update every three to four weeks. Inferred: the city theme rotates between updates, not inside a run, so there is no in-run zone strip to imitate.
- **Hill Climb Racing 2 (E3).** Observed in source: the same yellow number means "distance to the goal" in Cups and "distance travelled" in Adventure. Inferred lesson: for an open-ended run, show distance travelled only; any "to go" number implies a finish line.
- **Temple Run 2 (E2).** Observed in source: new obstacle types (zip-lines, mine tracks, waterfalls, fire jets); a fall or hit ends the run with a short rescue window; continuing costs gems. The article does not describe in-run zone indicators, so I make no claim about them.

### Patterns that keep an endless strip from implying an end
1. **Rolling window:** show only previous (dimmed, partly cut off), current (large) and next (normal) tiles, and slide the row left as the player crosses a boundary. The right edge is never "the last tile".
2. **Cycle with a lap badge:** when the five districts repeat, the next tile after Skyline Park is Main Street again, with a small badge "Lap 2". The strip never shows a closing cap or a finish flag.
3. **Fade the far edge:** a soft gradient on the right edge says "more beyond" (the dino strip has a hard right border).
4. **Best marker outside the window:** when the best distance is not in the visible tiles, show a small edge chip "BEST 2.1 km ▸" instead of a pin. When the head passes best, swap the chip for a one-time "New best!" pulse.
5. **Avoid the best/head collision seen in frame 56:** put the best pin above the tiles and the head below them, never on the same row.

## 2. Failure explanation

### Observed (L2, section 2.3)
The dino reference uses a full warn-then-fail sequence: a red "!" triangle and "Not enough stamina" above the player, the animal tints red, the player is bucked off in a tumble, then a big "STOMPED!" banner with a reason line "Stamina 20 / 60 needed", then return to base with "GREAT RUN!". The reason line names the number that mattered.

### Car Hop already has the warn stage
[[0008-heat-critical-meltdown]] already defines Hot (60%), Too hot! (85%), Losing control! plus HOP NOW! during the Meltdown escape window, with localized red only, no full-screen red, and a flash ceiling of 2.5 peaks per second. What is still open is the **reason moment** after the crash. Suggested sequence (Lane 1 owns timing and the crash; Lane 3 shows it):
1. Spinout and cartoon crash (Lane 1), camera holds on the car.
2. Reason banner, about 1.5 s **(reversible)**: headline "OVERHEATED!" and one reason line naming the cause and the fix, for example "The engine got too hot. Hop sooner to cool down!" Optional small icon: the same thermometer with its cap off.
3. Results panel (already in the HUD prototype). Show what was kept first ("Cars claimed: 2", distance), the reason second.

### Failures that cannot be warned honestly
Some ends happen in one frame: missing a Hop and landing on the road, being hit from outside the camera, falling off a bridge. A fake warning would be dishonest. For these:
- Show the reason **after** the fact with a still or short slow-down at the moment of failure, and a reason line ("Missed the hop!", "Fell off the bridge!").
- Make the warning visible **before the attempt** instead: the Hop ring or target nameplate turns grey or shows "Too far" when a Hop would fail. That is a real warning, not a fake one.
- Every failure cause gets its own headline; never a generic "GAME OVER".

### Child-friendly tone (recommendations, not cited rules)
- Blame the situation, not the player: "The engine got too hot!" rather than "You failed".
- One short line of advice the child can act on next run. No numbers they cannot change.
- Bright, cartoon framing (smoke puff, wobbly letters), no harsh buzzer, no screen-wide red, no shaking with reduced motion on.
- Keep the banner short and skippable by tap after about 0.5 s **(reversible)**.
- No paid continue. E1 and E2 both sell continues (keys, ads, gems); that is monetization, propose-first in AGENTS.md, and a pressure pattern for children. Do not copy it.
- Flashing stays under the project ceiling; for background see WCAG 2.3.1, https://www.w3.org/WAI/WCAG22/Understanding/three-flashes-or-below-threshold.html.

## 3. World nameplates over many moving targets

### Observed (L1, L2)
Frame 08 shows one large, readable nameplate ("Common / Pachycephalosaur / Required: ⚡10") for the nearest animal, a second giant copy of the same text clipped at the bottom right (the big reveal), and four or five distant plates stacked into an unreadable pile ("Common", "Uncommon Terror Bird", "TINY", "new!"). L2 section 7 lists this pile as something to avoid.

### Roblox facts (official docs, fetched 2026-10-22)
BillboardGui: https://create.roblox.com/docs/reference/engine/classes/BillboardGui
- **Size:** "the offset components work the same, the scale components are used as stud sizes in 3D space." So offset = fixed pixels on screen at any distance; scale = studs, which shrink as the car moves away.
- **MaxDistance:** "how far from the camera the BillboardGui will be displayed before it stops rendering"; 0 or inf (default) means no limit. It is a hard cut, not a fade.
- **AlwaysOnTop:** when true it "always renders on top of 3D content", colours match a ScreenGui and LightInfluence is treated as 0. When false, buildings and cars hide the plate, which gives occlusion for free.
- **DistanceLowerLimit / DistanceUpperLimit:** marked **Deprecated** on the current page. Do not use.
- **DistanceStep:** not deprecated; "the size CurrentDistance increments and decrements in studs". A changed event fires for CurrentDistance only when DistanceStep is more than 0.
- **Caching:** the page says a BillboardGui's appearance is cached until it or a descendant changes, then recomputed next frame. Inferred: changing text or transparency every frame on many plates defeats the cache, so change them only when a value actually changes.
- **LightInfluence** 0 to 1; set 0 so plates do not darken in shade.

Camera: https://create.roblox.com/docs/reference/engine/classes/Camera
- **WorldToScreenPoint** accounts for the GUI inset (top bar) and returns a Vector3 (X, Y in pixels; Z = depth in studs) plus a boolean "within the bounds of the screen". Use this one to place or test against ScreenGui elements.
- **WorldToViewportPoint** does **not** account for the inset; same returns. Use it only with `IgnoreGuiInset` on.
- **ViewportSize** is the device safe area, includes the top bar area, excludes notches.

Raycast: https://create.roblox.com/docs/reference/engine/classes/WorldRoot
- Returns a RaycastResult or nil; the direction vector's length is the ray length; maximum length 15,000 studs. Default params test all parts.
- The docs give **no cost figures**. Inferred: cost grows with ray length and the number of parts tested, so keep rays short (camera to plate anchor only) and use a RaycastParams include-list of building geometry.

### Recommended manager (all values reversible)
- **One client manager owns all plates**; cars never create their own logic. Pool BillboardGuis (about 8) and re-parent them to cars, instead of creating and destroying.
- **Update at 10 to 15 Hz**, not every frame. Per tick: score candidates, pick winners, set visibility. Smooth fades in a cheap per-frame tween on only the visible plates.
- **Priority:** 1) the Hop target (selected), 2) the ridden car (or hide it, since the HUD already shows it), 3) Rare or better, or NEW! (not owned), 4) nearest others. Ties break by distance.
- **Cap:** at most 4 plates on phone, 6 on desktop, including the target.
- **Screen-space overlap suppression:** project each candidate with WorldToScreenPoint, build its pixel rectangle, and accept in priority order, skipping any that overlap an already accepted rectangle by more than about 30%. Also reject plates that overlap the top strip, the Heat gauge or the Hop button rectangles (this is the bleed seen in frame 27).
- **Hysteresis:** a plate needs a score above `enter` to appear and drops only below a lower `exit`; keep a minimum on-screen time of 0.6 s and a minimum hidden time of 0.3 s before it may return. The Hop target bypasses this.
- **Legibility floor:** size plates in offset (pixels) so text never drops below the project's 16 px minimum (Tokens). Fade out between about 70 and 90 studs and set MaxDistance just past the fade end as a safety net, not as the fade.
- **Occlusion:** default AlwaysOnTop = false so buildings hide plates without any raycast. Only the Hop target uses AlwaysOnTop = true (or a screen-space marker) so the player can always find it. If a raycast check is ever needed, budget at most 4 short rays per tick, round-robin.

## 4. Rare-arrival announcements
L1 frame 08 shows a large lower-screen reveal for a nearby animal ("Common / Pachycephalosaur"), drawn even for Common, clipped by the screen edge. Inferred: no filter by rarity and no edge clamp.
- **Dedupe by identity**, never by model name: the server gives each spawned car a unique id; announce each id at most once per run. Two Rare cars of the same model are two events; the same car leaving and re-entering view is one.
- **Threshold:** announce Rare and above only, plus NEW! (never owned) if the team wants.
- **Cooldown:** a global gap of about 6 s between reveals.
- **Queue:** at most one waiting reveal; a higher rarity replaces a lower one; drop a queued reveal if its car despawned, left the screen or is more than about 2 s old.
- **Quiet times:** never during Meltdown, the failure banner, Results or the first Hop tutorial; Meltdown wins.
- **Reduced motion:** fade in and out only, no scale punch or slide.
- **Placement:** a small side ribbon that points toward the car, kept inside the safe area, not a giant centre text over the road.
- **Children:** no "hurry" or countdown wording; the reveal says what it is ("A Rare car is nearby!"), not "Don't miss it!".

## 5. Phone layouts of a top strip
- The local frames are desktop only; I found no phone captures of a top zone strip, so this section is design inference.
- ScreenGui https://create.roblox.com/docs/reference/engine/classes/ScreenGui: `ScreenInsets = CoreUISafeInsets` keeps UI clear of the Roblox top bar buttons and screen cutouts; use it for the strip.
- At 54 px per tile, a ten-tile strip is about 540 px, too wide beside the phone top bar. A compact layout: current district tile (larger, with name), next tile (smaller, no name or a short name), head marker and distance under the current tile, and the lap badge. About 160 to 200 px wide.
- Keep distance as a separate number pill so it stays readable if the tiles are hidden.
- The project outline already places Distance top centre ([[car-hop-outline-v2]] HUD line); the strip should replace or contain that number, not add a second one.

## Actionable findings
1. **District strip:** rolling window of previous (dimmed), current and next tiles over the loop Main Street, City Hall, Harbor Bridge, Midtown, Skyline Park, Main Street..., with no end cap, a soft right-edge fade and a "Lap 2" badge after the first loop. Owner check needed for the badge word.
2. **District strip, phone:** compact current + next only, inside CoreUISafeInsets, about 160 to 200 px wide; the distance pill replaces the outline's separate Distance readout.
3. **District strip, best:** best pin above the tiles and head below, so they never collide (frame 56 problem); out-of-window best shows as an edge chip; passing it gives one "New best!" pulse.
4. **District strip, data:** each district needs a start distance from Lane 1's segment contract; do not assume equal lengths (the reference appears not to use them).
5. **Entry banner:** slim translucent band below the strip with a district icon and name, about 2 s; suppressed during Critical and Meltdown and queued until the player is Cool or Hot.
6. **OVERHEATED reason screen:** after the Meltdown crash, "OVERHEATED!" plus one fix line ("Hop sooner to cool down!"), about 1.5 s, tap to skip, then Results with what was kept shown first. Follows 0008 (no screen-wide red, 2.5 peaks/s ceiling, reduced-motion version).
7. **Unwarnable failures:** each gets its own headline and reason line after the fact; the real warning moves to the Hop ring ("Too far") before the attempt. No paid continue.
8. **Nameplate manager:** one pooled client manager at 10 to 15 Hz; priority target > Rare/NEW! > nearest; cap 4 phone / 6 desktop; overlap suppression with WorldToScreenPoint rectangles, including HUD rectangles.
9. **Nameplate legibility:** offset-sized plates, 16 px text floor, fade 70 to 90 studs, MaxDistance as a backstop; avoid deprecated DistanceLowerLimit/UpperLimit; only update properties when values change (cache).
10. **Nameplate occlusion:** AlwaysOnTop false by default (free occlusion), true only for the Hop target; no per-frame raycasts, and at most 4 short include-list rays per tick if ever needed.
11. **Rare reveal:** dedupe by server car id, Rare and above, 6 s global cooldown, one-slot queue with rarity replace and 2 s staleness drop, silent during Meltdown/failure/Results/tutorial, side ribbon not centre text.
12. **Interfaces stay provisional:** district list, distance feed, car id, rarity and failure cause are cross-lane inputs ([[0007-concept-car-hop-and-lanes]]); propose them as HUD input fields before building.
