---
title: Capture feedback - Keys meter, pending and celebration research
tags: [research, ui, lane3]
date: 2026-10-22
---

# Capture feedback: Keys meter, pending state and celebration

Research for the Keys redesign. Checked on **2026-10-22**. Roblox facts come from the official creator-docs source (`github.com/Roblox/creator-docs`, `main`, the reference YAML and guide pages that build `create.roblox.com/docs`). This note approves nothing. Timings and counts marked **proposal** are reversible suggestions for the Lane 3 owner. Nothing here was tested in Studio. The game rules come from `vault/design/car-hop-outline-v2.md`: Keys time is 3/4/5/6 s by rarity, hopping off resets the meter, and the server re-derives and confirms the claim.

## 1. Capture patterns in other games

I make no popularity claims. Several wiki hosts (Fandom, Bulbapedia, Zelda Dungeon, StrategyWiki) refused automated fetches, so some rows rely on search summaries. The confidence column says which.

| Game and mechanic | Directly observable (source) | Inferred (not verified) | Lesson for Keys |
|---|---|---|---|
| **Shadow of the Colossus**: hold on to a moving creature | "Wander has a limited stamina gauge that decreases as he hangs onto the colossus"; the colossus "thrashes about in an attempt to dislodge him" ([Wikipedia](https://en.wikipedia.org/wiki/Shadow_of_the_Colossus)). A search summary of [StrategyWiki](https://strategywiki.org/wiki/Shadow_of_the_Colossus/Controls) and [Giant Bomb](https://www.giantbomb.com/games/3030-6522/) says it is a pink circle in the bottom-right corner (page not fetched). | The circle sits in a fixed corner, not on the creature, so the player's eyes stay on the action. | It is the closest match to Car Hop. A single circle meter stays readable while the world moves, but our meter fills up rather than drains. |
| **Zelda: Breath of the Wild**: tame a horse | Search summary of [Zelda Dungeon wiki](https://www.zeldadungeon.net/wiki/Horse_(Breath_of_the_Wild)) (page fetch refused): soothe presses while stamina drains, about 15 for most horses, more for strong ones. If stamina runs out, the player is thrown off. | The stamina wheel near the character works as the "time left" meter. | Taming is a meter plus a physical struggle. The failure is a clear physical event (thrown off), not a text message. |
| **Minecraft**: tame a horse by riding it | "An adult horse can be tamed by repeatedly mounting it until the horse stops bucking the player off." "After repeated mountings, hearts appear above the horse, indicating that it is tamed." On failure, "Horse neighs angrily" ([Minecraft Wiki](https://minecraft.wiki/w/Horse)). | There is no meter at all. Progress is hidden and only the outcome is shown in the world. | Success appears on the object itself (hearts over the horse). Failure is shown by a sound and a physical event, never by a "FAILED" banner. |
| **Pokémon GO**: catch ring | "The colour of the circle denotes the capture rate ... green being the highest and red the lowest." "This increased chance is at its highest when the circle is at its smallest." ([Nintendo Life guide](https://www.nintendolife.com/guides/pokemon-go-how-to-catch-pokemon-throwing-tips-poke-balls-and-capture-rates)) | The ball shakes before the result. I found **no source for GO**. In the mainline games the ball "shakes up to three times" ([Gamer Guides, BDSP](https://www.gamerguides.com/pokemon-brilliant-diamond-and-shining-pearl/guide/how-to-play/pokemon-battles/how-to-catch-pokemon)). | A suspense beat between "done" and "result" is a familiar pattern. Our Pending state can borrow the rhythm, but it must never imply chance (see section 3). |
| **Skyrim**: lockpicking | "rotate the lockpick in the correct position in a 180 degree arc"; "As the lockpick gets closer to the correct spot, the lock will turn more and more"; "When the lockpick is in the wrong spot, it will jiggle and eventually break" ([UESP](https://en.uesp.net/wiki/Skyrim:Lockpicking)). | Turning the lock acts as the progress bar, so the metaphor carries the meter. | Shows that a key or lock *turning* reads as progress. Its ring is a skill check that blocks the screen, which we must not copy. |

## 2. Complete vs pending vs confirmed vs failed

**General guidance (sources):**
- Optimistic UI shows the expected result before the server answers. React's `useOptimistic` "lets you optimistically update the UI". On failure, "the UI shows what it showed before the optimistic update. You can catch the error to show a message to the user" ([react.dev](https://react.dev/reference/react/useOptimistic)). The **risk** is the revert: the player sees something, then it is taken away.
- Games predict on the client and reconcile with an authoritative server: the client renders inputs "as if they had succeded", but "Because the server is authoritative, the client must move the character back" ([Gambetta, client-side prediction](https://www.gabrielgambetta.com/client-side-prediction-server-reconciliation.html)).
- Response-time limits ([NN/g](https://www.nngroup.com/articles/response-times-3-important-limits/)):
  - Under 0.1 s feels "instantaneous".
  - Up to 1 s keeps the "flow of thought" unbroken.
  - Past 1 s, show that work is happening.
  - 10 s is the limit for attention.

**Applied to Keys.** This splits what can be optimistic from what must wait. It is inferred from the sources above.
- **Optimistic is fine:** the meter filling, segment ticks, and the "full" moment. These are a local mirror of time aboard, and the server re-derives the same thing from the run seed.
- **Must wait for the server:** anything that says *you own it*: "YOU GOT THE KEYS!", the car card, the Garage count, and rarity fanfare. Taking back a celebrated reward from a child reads as theft or a bug. Delaying a celebration by up to 1 s costs little.

**Four visual states:**

| State | What the player sees (proposal) |
|---|---|
| Capturing | The ring fills segment by segment; the key slides into the lock |
| Pending ("Confirming…") | The ring is full and steady, and the key turns slowly. No sparkle, no rarity colour burst, no sound sting |
| Confirmed | The lock opens, a burst plays, the celebration tier runs (section 3), and the Garage count updates |
| Canceled (hopped off, server rejected, timed out) | The ring fades in 200 ms. No red X and no "FAILED". The outline says rejects are "dropped silently and logged", so no blame text |

- If Pending lasts more than 1 s, keep the turn loop running; never show a spinner or a percentage.
- **Proposal:** after 8 s with no answer, go to Canceled and leave a late Confirmed to section 5.
- Pending must not suggest a dice roll. In Pokémon the shake is chance. Ours is only network latency, and the audience is children (AGENTS.md bans paid-luck and coercive patterns).

## 3. Celebration hierarchy that does not block play

- **Tier 0: in-ring tick** (every segment). A segment locks with a 120 ms scale pop, 1.0 to 1.08 (**proposal**).
- **Tier 1: side ribbon** (Confirmed during a run, phones and tablets). It slides in from the edge outside the landing view, 220 ms in, about 1800 ms hold, 250 ms out (**proposal**). It must not take input, must not pause, and must stay out of the middle 40 % width × 45 % height already kept clear in `vault/design/ui/hud-prototype-overnight.md`.
- **Tier 2: full card.** Only where the outline already pauses Heat (first claim: "the car card slides in for two seconds"), otherwise deferred to Results. This matches the overnight spec.
- One celebration at a time. Queue ribbons and drop stale ones; never stack two cards.

**Reduced motion:**
- [WCAG 2.3.3](https://www.w3.org/WAI/WCAG22/Understanding/animation-from-interactions.html) (AAA): "Motion animation triggered by interaction can be disabled, unless the animation is essential". Rationale: "Vestibular (inner ear) disorder reactions include dizziness, nausea and headaches."
- [WCAG 2.3.1](https://www.w3.org/WAI/WCAG22/Understanding/three-flashes-or-below-threshold.html): nothing "flashes more than three times in any one second period". This applies to the Confirmed flash and outline pulses in every motion mode.
- [Roblox accessibility guide](https://create.roblox.com/docs/production/publishing/accessibility#reduced-motion): "A value of `true` indicates the player wants motion effects through UI animations/tweens to be reduced or completely removed". It suggests tween time `0`, or "switches to fade‑in ... without positional movement".
- [Apple HIG Motion](https://developer.apple.com/design/human-interface-guidelines/motion): "Make motion optional ... avoid using it as the only way to communicate important information". Also: "when a game displays a succinct animation that's precisely tied to a successful action, players can instantly get the message without being distracted from their gameplay."
- **Keys reduced-motion map (proposal):**
  - Segment pop becomes a colour change.
  - The key turn becomes a static key icon plus the "Confirming…" text.
  - The ribbon slide becomes a 150 ms fade.
  - No particle burst; the lock-open icon swaps instantly.
  - The outline pulse becomes a steady outline.

## 4. Roblox engine facts (official docs)

- **Highlight** ([class](https://create.roblox.com/docs/reference/engine/classes/Highlight), [guide](https://create.roblox.com/docs/effects/highlighting)):
  - Limit: "Studio only displays 255 simultaneous `Highlight` instances on the client at a time ... the additional instances are silently ignored." A disabled one "still takes one of the 255 available slots".
  - `DepthMode`: `AlwaysOnTop` displays "regardless if there are objects between the camera and the highlighted object"; `Occluded` "Hides the highlight if there are objects between".
  - `OutlineTransparency`: "between **0** (opaque) and **1** (transparent)". `Adornee` applies it "outside of a child/parent relationship".
  - Performance: "Adding or removing a `Highlight` can cause a geometry rebuilding step that might lead to performance spikes ... changing any property ... is lightweight". "The first `Highlight` rendered on the screen incurs most of the performance cost (up to 1 millisecond of GPU time on mobile devices)". "On mobile devices, highlights are more costly ... when they cover more of the screen". Hidden or fully transparent ones "incur no performance cost". Keep objects that carry a Highlight out of parent/child relationships with each other.
- **ParticleEmitter** ([class](https://create.roblox.com/docs/reference/engine/classes/ParticleEmitter), [guide](https://create.roblox.com/docs/effects/particle-emitters)):
  - `Emit(particleCount)` "will cause the `ParticleEmitter` to instantly emit the given number of particles" (default 16). No documented cap on one `Emit` burst.
  - Rate cap: "A single particle emitter can create up to 400 particles per second (100 per second on mobile)".
  - "Particles have a maximum lifetime of 20 seconds."
  - "Particle size can impact performance due to fill-rate" and count "due to overdraw".
  - "The visual quality of your particles can change depending on the graphic settings on the player's device". Test at the lowest and highest Editor Quality Level.
  - It must be parented to a BasePart or Attachment.
- **BillboardGui** ([class](https://create.roblox.com/docs/reference/engine/classes/BillboardGui)):
  - Size: "the **offset** components work the same, the **scale** components are used as stud sizes in 3D space". Use offset for a constant-pixel ring and scale for a ring that shrinks with distance.
  - `AlwaysOnTop` false (default) "is occluded by other 3D objects". When true, it "always renders on top", colours "match how they appear inside a `ScreenGui`", and `LightInfluence` is treated as `0`.
  - `MaxDistance`: `0` or `inf` means no limit. Set it high enough to minimise "the sudden pop‑in/out effect".
  - `LightInfluence` ranges 0–1 ("`0` means that the lighting has no effect").
  - `StudsOffset` is relative to camera orientation; `StudsOffsetWorldSpace` uses global axes.
  - Buttons inside it receive input only if the BillboardGui is under PlayerGui.
- **GuiService.ReducedMotionEnabled** ([class](https://create.roblox.com/docs/reference/engine/classes/GuiService)): "Returns `true` if the player has enabled reduced motion ... maps to the **Reduce Motion** toggle". It is ReadOnly and NotReplicated; listen with `GetPropertyChangedSignal`, as `RunHud` already does.
- **Camera:WorldToViewportPoint** ([class](https://create.roblox.com/docs/reference/engine/classes/Camera)):
  - It returns X and Y in pixels from the viewport's top-left, and Z as "depth ... (in studs)", plus an on-screen boolean.
  - It "does not take in account the current GUI inset ... Unless you are using `ScreenGui.IgnoreGuiInset`, this position is not appropriate for placing GUI elements". `WorldToScreenPoint` accounts for the inset.
  - The boolean "will be `true` regardless of whether the point is obscured" (no raycast).
  - Safe area: `GuiService:GetInsetArea(screenInsets)` returns a Rect "relative to the `CoreUISafeInsets` area". `ScreenGui.ScreenInsets` defaults to `CoreUISafeInsets`, "clear of the Roblox top bar buttons and other screen cutouts like the device's camera notch".
  - **Derived, verify in Studio:**
    1. Put the ring in a ScreenGui with `ScreenInsets = None`, so viewport pixels map directly.
    2. Let `n = GetInsetArea(None)`. The core-safe rect in viewport pixels starts at `-n.Min`.
    3. Clamp the ring centre to that rect, shrunk by the ring radius.
    4. Hide the ring when `Z <= 0` (behind the camera).
- **CanvasGroup** ([class](https://create.roblox.com/docs/reference/engine/classes/CanvasGroup)):
  - "consumes extra texture memory ... When exceeding the memory cap, `CanvasGroup` will render as a blank texture."
  - "recommended to use `CanvasGroup` with static sizes". It always clips descendants.
  - It flattens only when `ZIndexBehavior` is `Sibling`.
  - A ring that scale-pops inside a CanvasGroup works against "static sizes". Pop a child with `UIScale` inside a fixed-size group instead.
- **UIStroke** ([class](https://create.roblox.com/docs/reference/engine/classes/UIStroke), [guide](https://create.roblox.com/docs/ui/appearance-modifiers)):
  - `ApplyStrokeMode` decides whether a stroke on a text object goes "to the object's border instead of the text itself" (`Contextual` vs `Border`).
  - `Thickness` is in pixels by default. `StrokeSizingMode.ScaledSize` makes it "relative to minimum parent width or height. If stroke is on text, thickness is relative to font size."
  - "Avoid tweening the `Thickness` ... applied to **text** objects. This renders and stores many glyph sizes each frame".
  - **UIScale:** the docs do not state it. The [DevForum release thread](https://devforum.roblox.com/t/studio-beta-uistroke-improvements-scaling-offsets-and-more/3958036) says "BorderOffsets should scale the same way as Thickness does when using UIScale" and was "fully released" on Dec 4, 2025. That implies UIScale now scales Thickness. **Unverified: check in Studio** before tuning our 2/3/4 px strokes.
- **Font.new with italic** ([datatype](https://create.roblox.com/docs/reference/engine/datatypes/Font)):
  - `Font.new(family, weight = Regular, style = Normal)`, where style is "Whether the text is normal or italic", and family is an `rbxasset://` or `rbxassetid://` id. Fredoka One is `rbxasset://fonts/families/FredokaOne.json`.
  - The docs do not list which weights or styles each family contains, or what happens when Italic is missing. **Unverified**: whether Fredoka One has a true italic face. Test before relying on it. Italic is also outside the approved type rules, so it is propose-first.

## 5. Event ordering and dedupe (recommendation)

**Identity key:** `(runId, carInstanceId, attempt)`. `attempt` rises each time the player boards that instance, because hopping off resets the meter. The server echoes the key in its Confirmed or Rejected message.

**Rank:** Idle 0 < Capturing 1 < Pending 2 < Confirmed or Canceled 3. Only move up. The one exception is late server truth (row 7).

| # | From | Event (same key unless noted) | To | Presentation |
|---|---|---|---|---|
| 1 | Idle | board an unowned car | Capturing | show the ring at 0 |
| 2 | Capturing | local progress `p` | Capturing | `fill = max(fill, p)`; never move backwards |
| 3 | Capturing | local full | Pending | lock the segments, start the key turn, start an 8 s timeout |
| 4 | Capturing or Pending | Confirmed | Confirmed | snap to full if needed, then celebrate **once** (record the key in `celebrated`) |
| 5 | Capturing or Pending | hop off, Rejected, or timeout | Canceled | 200 ms fade, no blame text |
| 6 | Confirmed | Confirmed again (duplicate) | Confirmed | ignore (the key is in `celebrated`) |
| 7 | Canceled | late Confirmed | Confirmed | **server wins**: Tier-1 ribbon only, update the Garage, no card |
| 8 | Confirmed | late Rejected | Confirmed | ignore and log a warning (the server contract is broken) |
| 9 | any | event with an old `runId` or older `attempt` | unchanged | ignore; a stale Confirmed still updates the Garage count, which comes from server state, never from the event |

- Only one key is active at a time. Its board event starts a new attempt; earlier attempts can still reach state 3 through rows 7 and 9, but never show the ring again.
- The Garage count and ownership are read-only replicated state (AGENTS.md: "Replicate state to the client as read-only"). The presentation machine only decides *how* to celebrate; it never decides ownership.

## Actionable findings for our Keys redesign

- **Use 4 segments for every rarity (proposal).** One segment is 0.75 s for Common (3 s) and 1.5 s for Legendary (6 s). At the researched ring size of about 55 px (`hud-ref-mobile-racing.md`), a 173 px circumference leaves about 40 px per segment with gaps, which stays legible on phones. Six segments drops to about 27 px. Let rarity show in colour and duration, not segment count.
- **The key-in-lock metaphor fits our states**: insert = Capturing, turn = Pending, open = Confirmed. Make the key silhouette the hero. A lone padlock can read as "locked" or "not allowed" (inferred).
- **Celebrate only on the server's Confirmed.** Fill and "full" may be optimistic; no "YOU GOT THE KEYS!", card, sound sting or Garage change before Confirmed.
- **Pending under 1 s looks seamless.** Keep the turn loop running until the 8 s timeout (proposal). No spinners, percentages or dice-like suspense.
- **Failure is quiet**: fade the ring in 200 ms. No red X or "FAILED". This matches the silent drop on the server.
- **Highlight: at most one, reused.** Keep one Highlight per client, change `Adornee` and transparency instead of creating or destroying it (the docs warn of rebuild spikes), and set `Enabled=false` when idle. Prefer outline-only (`FillTransparency = 1`) because the ridden car covers a lot of a phone screen. Pulse no more than 3 times per second (WCAG 2.3.1).
- **Particles**: one Attachment emitter with an `Emit(≤12)` burst on Confirmed (the overnight spec), with small particles because fill rate is the mobile cost. Check at the lowest quality level.
- **Ring placement**: use a screen-space ring with `WorldToViewportPoint` in a `ScreenInsets = None` ScreenGui, clamped to the `CoreUISafeInsets` rect, hidden when `Z <= 0`. Prefer it over a BillboardGui when the ring must avoid the landing view. If you use a BillboardGui, set `AlwaysOnTop = true` and size it in offset.
- **Reduced motion**: swap motion for colour and fade, per the map in section 3, with no particle burst. Read `ReducedMotionEnabled` live.
- **Avoid**:
  - tweening `UIStroke.Thickness` on text
  - CanvasGroups that change size
  - a full card during a run on phones
  - two stacked celebrations
  - a celebration triggered by the client
  - any wording or rhythm that implies chance
- **Verify in Studio before building:** whether UIScale scales UIStroke thickness, whether Fredoka One has an italic face, and the safe-rect conversion.
