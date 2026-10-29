---
title: "0028: Settings sound rows - category SoundGroups, mute folds Music On/Off, session-only memory"
date: 2026-10-29
tags:
  - decision
  - audio
  - ui
status: accepted for the preview (the card's look awaits Adam's visual approval)
---

# 0028: Settings sound rows

Brief: Adam, 2026-10-29 (Part A, Design 7). Spec `vault/design/ui/settings-sound.md`, ledger [[settings-sound-ledger]].

## Decisions
1. **Two player category groups, the mix nested underneath** (lead's choice inside the brief). `SoundService.Music` and
   `SoundService.Effects` carry only the player's level (0..1, default 1). The approved mix groups (`Lane3PreviewMusic`
   0.5, `Lane3PreviewUI` 0.6) became their children, so 100 sounds exactly like the approved mix. *Alternative:* write the
   player level into the mix groups (level x 0.5): one fewer group, but the player's level and the mix level could no
   longer be read or changed separately.
2. **Music On / Off folded into the MUSIC mute** (Adam's choice). The Home switch and the mute button write the same
   `musicOn`. The Home switch keeps its place and look (no Home layout change). *Alternative:* remove the Home switch.
3. **Mute no longer stops the music loop** (needed by the brief: "never restart, seek, duplicate or reload"). Round 3
   (R3-A) faded the voices out and destroyed them on Music Off, so Music On restarted the track from the start. Now mute
   only silences the group and the loop keeps time underneath. Cost: a muted track keeps streaming. *Alternative:* stop
   the voices after a long mute (for example 30 s) and accept a restart then.
4. **Phones put the two audio rows side by side** (lead's choice). Four stacked rows at Design 7 sizes need 338 px against
   300 on PhoneSmall; side by side keeps every control full size and needs no scrolling (258 px). Columns are 24 px apart:
   at 12 px the MUSIC "MUTED" read as part of the SOUND EFFECTS row. *Alternative:* a scrolling card.
5. **Labels 18 px as proposed**, so the two audio labels are smaller than "Reduce motion" and "Haptics" (24 px). Left for
   Adam to choose one size.
6. **Remember on this device: blocked.** Roblox documents no experience-level device storage (Creator Docs, 2026-10-29);
   `UserGameSettings` is Roblox's own. Values are kept for the client session only (menu reopen, respawn, World change),
   and a rejoin starts at 100 (tested). A profile field (account-wide, Brian L's save data) is proposed in
   `vault/design/specs/settings-sound-for-brian-l.md`; nothing was added to any save.
7. **Key steps read from UserInputService.** Roblox's GUI navigation marks Left / Right as processed before
   ContextActionService sees them (measured in Studio Play: the old binding never fired), so the panel reads the keys
   itself while one of its sliders is selected.

## Open
- In 2 of 4 recorded Play takes the music loop did not follow the MUSIC level for about its first 19 s although the group
  property did change (the other 2 takes and 4 controlled tests followed exactly; asset loads were failing with network
  errors in that session). Cause not found. Not claimed fixed.
