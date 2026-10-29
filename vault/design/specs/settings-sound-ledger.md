---
title: Settings sound controls - requirement ledger
tags:
  - design
  - audio
  - ledger
date: 2026-10-29
---

# Settings sound controls: requirement ledger (Part A)

Session brief: Adam, 2026-10-29 ("Lane 3 Settings sound controls and Worlds follow-ups", Part A and Design 7). Branch
`feature/lane3-hud-downtown-lookdev`, draft PR #2. Build spec `vault/design/ui/settings-sound.md` (task-scoped Figma
exception chosen by Adam on 2026-10-29: spec plus Studio build, **awaiting his visual approval**). Evidence column filled at
the end of the session; "PASS" lines are the playground's own property checks in Studio Play (`scenarios/SettingsSound.luau`
and the older Music / Mix scenarios), not listening tests.

| ID | Requirement (brief) | Where | Status / evidence |
|---|---|---|---|
| SS-1 | MUSIC and SOUND EFFECTS sliders 0 to 100, mute at the left, default 100 | `Home/SettingsPanel.luau`, `Store.luau` | **built, Play-tested** (property checks): defaults 100 / 100 unmuted PASS; real mouse click on MUSIC mute; stills on six frames |
| SS-2 | Fold Music On / Off into the MUSIC mute (one state, no contradiction); Haptics row kept in order | `Home/MusicSetting.luau`, `Home/LeftMenu.luau` (unchanged code, same state) | **built, Play-tested**: Home switch Off reads MUTED in the card, On restores the kept level PASS (decision 0028) |
| SS-3 | Two SoundGroups, Music and Effects, control every sound in each category; inventory, no duplicates | `AudioMix.luau`, `Sounds.luau`, `Music.luau` | see the routing table **built, Play-tested with the mouse only**: real mouse drag clamps to 100 far outside the card, ends on release, camera did not turn; scripted pointer left of the card clamps to 0 PASS. **Touch, multi-touch and window-focus loss not tested** (no touch device in Studio)|
| SS-4 | A change applies at once, never restarts music | `MusicSetting.luau` (mute no longer stops the loop) | **built, Play-tested**: groups nested, no duplicates PASS; new effect heard = Volume x 0.6 x player PASS; World switch loop routed through Music PASS; inventory **partly**: Left / Right on a selected slider 5 points (100 -> 85 -> 90, real key presses). Up / Down navigation by injected keys did not move the selection: **not verified**; gamepad not tested. **Open:** 2 of 4 recorded takes the music loop did not follow the MUSIC level for its first ~19 s (decision 0028 Open) |
| SS-5 | Soft preview tick on the Effects slider (40 to 80 ms, one per 150 ms, release only if not redundant, silent at 0, no overlap) | `Sounds.luau` hook `VolumeTick`, `SettingsPanel._tick` | **built, Play-tested**: one loop, never recreated, TimePosition 2.50 -> 3.75 -> 4.57 -> 5.38 -> 6.42 s across 20 slider moves, mute, unmute, 0 and back PASS; Music mute / unmute keep the same Sound PASS |
| SS-6 | Remember on this device | none: BLOCKED (no documented experience-level device storage); session only | **checked on one client**: the server has no SoundGroups. **Two-client isolation not tested**|
| SS-7 | Message to Brian L proposing a settings save field | `vault/design/specs/settings-sound-for-brian-l.md` (on main) | Desktop, Tablet and the four phone frames are **simulated device frames in Studio Play** (no real phone). Clip with game audio: take 2 (`settings-sound-play-2.mp4`)|
| SS-8 | Design 7 layout: 80 px rows, 12 gap, 16 padding, 18 / 16 px text, 10 px track, navy surround, cream / teal, 24 px knob, 48 px targets, track width used on phones | `SettingsPanel.luau` | **built, Play-tested**: real mouse drag: ticks 150 to 200 ms apart, each 60 to 74 ms, never two at once; scripted drag 9 ticks, min gap 0.150 s; none at 0 PASS. Not listened to by Adam |
| SS-9 | Mute: slash and "MUTED", not red; lastNonZero per category this session; slider above 0 unmutes; no fill at 0 | `SettingsPanel.luau`, `MusicSetting.luau` | **blocked** (done (below)); session kept through close / reopen PASS and respawn (server LoadCharacter) checked; clean rejoin starts at 100 (checked) |
| SS-10 | Mouse drag, touch drag, tap; one pointer owns a drag; clamps outside the card; cleans up on close; no card scroll or camera turn | `SettingsPanel.luau` | **written** (`settings-sound-for-brian-l.md`, on main) |
| SS-11 | Keyboard / gamepad 5-point steps, no focus trap | `SettingsPanel.luau` | **built, awaiting Adam's visual approval**: measured on PhoneSmall: mute 48 x 48, slider hit 232 x 48, knob 24, card 258 / 300 px. Labels 18 px beside 24 px rows (Adam to choose) |
| SS-12 | Per player, local only | `AudioMix.luau` (client-made groups) | two-client test not run (see the log) |
| SS-13 | Tests: desktop and all landscape frames, clip with sound | playground | **built, Play-tested**: slider to 0 shows slash, MUTED, no fill, kept 50% PASS; unmute restores 50% PASS; unmute with nothing kept goes to 100 PASS |
| SS-14 | List anything not routed, including the Raceway branch | this file | below |

## Routing inventory (2026-10-29, read from the code on both Lane 3 branches)
| Sound | Made by | Category | Routed here? |
|---|---|---|---|
| Every HUD effect hook (clicks, Cash, Keys chimes, fanfares, warnings, Results tally, the new VolumeTick) | `Sounds.luau` spawn (one Sound per voice, `SoundGroup = Lane3PreviewUI`) | Effects | yes |
| World music loops and the tension layer (Downtown, Dusty Highway, Summit Pass) | `Music.luau` (`Lane3Music_Base` / `_Tension` under `Lane3PreviewMusic`) | Music | yes (the Worlds place uses the same modules) |
| Island ambience (duck quack and others) | `src/client/Home/Island/Ambience.client.luau`, its own SoundGroup | Effects | **no: not in this checkout** (island branch) |
| Portal sounds | `src/client/Home/Island/Portals.client.luau` (a Sound per portal, no group) | Effects | **no: other branch** |
| Raceway (Speedway) ambience, cheers, level-up | `src/client/Home/Island/Speedway/Sound.luau`, its own SoundGroup | Effects | **no: branch `feature/lane3-speedway-upgrades`, now in use by the Raceway round 2 session** |
| Newer audio objects (AudioPlayer, AudioEmitter, Wire) | none found on either branch (only a comment mentions AudioPlayer) | | nothing to integrate |
| Roblox's own sounds (character footsteps, jump) | Roblox's default character scripts, not ours | | not routed (Roblox's; would need a fork of the default sound script) |

Proposed island and Raceway integration (not merged here): when those branches meet this one, each of their SoundGroups
sets `Parent = AudioMix.group("Effects")` once (the island ambience group, the Speedway group), and the Portal Sounds get
`SoundGroup = ` a small island mix group under Effects. Their own authored levels stay; only the player's level multiplies.
