---
title: Settings sound rows (MUSIC and SOUND EFFECTS volume)
tags:
  - design
  - ui
  - audio
status: built, approved by Adam on 2026-10-31
date: 2026-10-29
---

# Settings sound rows: build spec (Lane 3 preview)

Ledger [[settings-sound-ledger]]. Builds Adam's Design 7 (2026-10-29 session brief) into the existing Settings card
(`src/client/UI/Prototype/Home/SettingsPanel.luau`). **No Figma mock**: making the "Car Hop UI" file needs a Figma read,
and the read rule in [[0012-figma-ui-workflow]] allows reads only after a hand edit. Adam chose, on 2026-10-29, a
task-scoped exception for this card only: this spec plus a Studio build, approved or changed by Adam from the review page.
**Approved by Adam on 2026-10-31** ("everything looks good", after trying it in Studio Play); the labels stay 18 px as built. This is not a workflow change.

The numbers below are Adam's Design 7 proposals unless marked LEAD CHOICE (reversible).

## 1. What changes
- The two old rows (Music slider and Sound effects slider, label column on the left, 10% steps, green fill) become two
  **audio rows**: a mute button on the left, the label, a right-aligned whole-number percentage, and the slider beneath.
- The levels are now the player's own **0 to 100 volume** for each category, default **100**. At 100 the game sounds
  exactly as the approved mix did before (the mix levels moved into child groups, see section 5).
- **Music On / Off is folded into the MUSIC mute button** (Adam's choice). The Home screen's Music switch stays where it
  is and shows the same state: switching it Off is the same as pressing MUSIC mute, and the two can never disagree.
- Reduce motion and Haptics are unchanged and keep their order (rows 3 and 4).
- The harness caption becomes "Preview: kept this session, not saved".

## 2. Layout (design px, inside the card's UIScale)
| Item | NORMAL (Desktop, Tablet) | COMPACT (the four phone frames, safe height under 400) |
|---|---|---|
| Card width | min(620, safe width - 24), unchanged | same |
| Side padding | 16 (was 20) | 16 |
| Audio rows | stacked, full inner width, 80 high, 12 gap | **side by side**, two columns of (inner - 24) / 2 (24 px apart: at 12 the MUSIC "MUTED" read as part of the SOUND EFFECTS row in the PhoneLandscape still), 80 high (LEAD CHOICE: four stacked rows need 338 px against 300 on PhoneSmall; side by side keeps every control at full size with no scrolling) |
| Then | Reduce motion 60, Haptics 60, gaps 12 | Reduce motion 52, Haptics 52, gaps 4 (unchanged), 8 under the audio rows |
| Card height | 70 + 80 + 12 + 80 + 12 + 60 + 12 + 60 + 48 = 434 (tablet safe 495) | 52 + 80 + 8 + 52 + 4 + 52 + 10 = 258 (PhoneSmall safe 300) |

One audio row (x from the row's left, y from its top):
- **Mute button** 48 x 48 at (0, 0): kit segment surface (unchosen fill, Button outline, kit radius), the icon 30 x 30
  centred. MUSIC uses the existing original **note** icon (`Music`), SOUND EFFECTS the existing original **speaker**
  icon (`Speaker`). Muted: a navy-outlined cream **slash** across the icon (corner to corner, 4 px bar, 3 px outline) and
  the button body darkens to navy. Never red, never colour alone.
- **Label** at x 56, 48 high, 18 px (`Tokens.TextSize.Label`), left aligned, white outlined: "Music", "Sound effects"
  (LEAD CHOICE: sentence case like the other two rows).
- **Percentage** right aligned to the row's right edge, 48 high, 16 px (`Tokens.TextSize.Minimum`), tabular whole
  numbers "0%" to "100%"; when muted it reads **"MUTED"** instead.
- **Slider** from x 56 to the right edge, hit box 48 high centred at y 64 (y 40 to 88: inside the 12 px gap, never over
  the next row and never over the mute button). Visual track 10 high: a navy (`Tokens.Color.Stroke`) recessed surround
  16 high (3 px each side), cream (`Tokens.Color.Card`) inactive portion, teal filled portion (`Tokens.Color.Calm`,
  the approved blue-teal; no new colour). Knob 24 circle, cream, 2 px navy outline. At 0 (or muted) the fill is hidden:
  no sliver. The knob's centre runs between the track ends.

## 3. Behaviour
State per category, in the preview store `settings`: `music` / `sfx` = the level 0..1, `musicOn` / `sfxOn` = false while
muted. While muted, the level holds the **last non-zero value** of this session.
- **Mute** (button, Home switch Off): effective level 0; the level is kept. **Unmute**: back to that level, or 100 if none.
- **Slider above 0** unmutes. **Slider to 0** is muted (slash, "MUTED"), and the level kept for unmute is the value
  the drag started from (or the step before 0 on a key press).
- **Pointer**: mouse drag, touch drag and a tap on the track. A drag owns the one pointer that started it until that
  pointer ends or is cancelled (another finger lifting does not end it; the window losing focus does). Positions outside
  the card clamp to 0 and 100. Closing the card ends the drag and cleans it up. The card does not scroll, and a drag that
  started on a slider is sunk by the GUI, so it does not turn the camera.
- **Keyboard / gamepad**: Up / Down move between controls in this order: MUSIC mute, MUSIC slider, SOUND EFFECTS mute,
  SOUND EFFECTS slider, Reduce motion, Haptics, Close (COMPACT: MUSIC row, then SOUND EFFECTS row, same order). Left /
  Right on a selected slider moves it by **5**; on a mute button they move to its slider and back. Selection never
  leaves the card and nothing is trapped (Up from the first control goes to Close, as before).
- **Sound follows at once**: each change sets the category group's Volume with a 0.05 s linear ramp (no clicks). The
  MUSIC mute / unmute keeps the approved Round 3 0.3 s fade. Nothing ever seeks, restarts, duplicates or reloads music:
  mute no longer stops the music loop, it only silences the group (the loop keeps time underneath).
- **Preview tick** (SOUND EFFECTS slider only): the existing verified click (`Roblox_UI_Small_Click`, Roblox) trimmed to
  70 ms, played through Effects at the new level: at most one every 150 ms while dragging, one on release only when the
  level moved since the last tick, and never at 0. A tick never overlaps the next (150 ms gap, 70 ms sound).

## 4. Remembering the setting
- **Kept for the whole client session**: closing and reopening the card, respawning, switching World, and every new
  sound (new sounds join the groups at the current level).
- **Not remembered across launches (BLOCKED).** Roblox documents no experience-level way to keep data on the device
  (checked 2026-10-29 in the Creator Docs: data stores only, which are account data). `UserGameSettings` is Roblox's own
  and takes no game fields. A rejoin starts at 100.
- Saving to the player's profile is Brian L's save data: proposal in `vault/design/specs/settings-sound-for-brian-l.md`.
  That would be **account** persistence (every device), a different scope from "this device".

## 5. Audio routing (`src/client/UI/Prototype/AudioMix.luau`)
Two player category groups in SoundService, created by the client (so they are this player's own; one player's sliders
never change anyone else's sound): **`Music`** and **`Effects`**, Volume = the player's effective level (0..1). The
approved mix groups are nested under them and keep their levels:
```
SoundService
  Music   (player level)  -> Lane3PreviewMusic 0.5 -> Lane3Music_Duck -> Lane3Music_Base, Lane3Music_Tension
  Effects (player level)  -> Lane3PreviewUI 0.6   (every Sounds.play hook, the preview tick)
```
Each Sound keeps its own Volume, position and rolloff; membership is `Sound.SoundGroup`. Other code joins a category with
`AudioMix.group("Music" | "Effects")` (as the parent of its own mix group). Not routed in this branch: listed in the
ledger (the Raceway / island sounds live on another branch).

## 6. Debug hooks
`SettingsPanel:getControls()` adds `musicMute`, `sfxMute`; `getDebugState()` reports the slider values, percentages as
shown, mute state, the category group Volumes and the drag owner. `AudioMix.getDebugState()` lists both groups, their
children and Volumes.
