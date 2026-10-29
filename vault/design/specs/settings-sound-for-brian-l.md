---
title: Settings sound levels - a proposed save field (for Brian L)
tags:
  - design
  - audio
  - save-data
  - message
date: 2026-10-29
status: proposal, waiting for Brian L
---

# Message for Brian L: remembering the sound settings

From Adam (Lane 3), written with Claude Code on 2026-10-29. Nothing here is built in your code or your save data.

## What Lane 3 built
The Settings card now has a **MUSIC** and a **SOUND EFFECTS** volume (0 to 100, default 100) with a mute button each
(spec `vault/design/ui/settings-sound.md`). Players can turn the game down. Today the values are kept only while the
player is in the game: they survive closing Settings, respawning and changing World, but a rejoin starts at 100 again.

## Why it is not remembered yet
- Roblox documents **no way for a game to keep data on the device** (checked in the Creator Docs on 2026-10-29: only
  data stores, which are account data). `UserGameSettings` belongs to Roblox and takes no game fields.
- So "remember it" means the **player's profile**, which is your save data (ProfileStore, one lifecycle owner). That is
  **account** persistence: the same levels on every device the player uses, not "this device only".

## The proposal (needs your yes, and the usual plan and go-ahead before anyone codes it)
Add one small table to the profile template, backfilled by `Reconcile`:

```
Settings = {
	MusicVolume = 100,   -- whole number 0..100
	EffectsVolume = 100, -- whole number 0..100
	MusicMuted = false,
	EffectsMuted = false,
}
```

- **Player benefit:** a child who turned the music down does not get it back at full volume next time.
- **Cost:** four plain values; one remote "SetSoundSettings" (client asks, the server validates: integers 0..100, booleans,
  a rate limit such as one write per second, values clamped) and the server writes the profile. Nothing to do with
  Cash, rewards or purchases.
- **Risk:** low. A bad value can only change the player's own volume. The client never sends anything that touches the
  economy. Haptics (`HapticsOn`) and Reduce motion could join the same table later if you want; not part of this ask.
- **Test:** with `ProfileStore.Mock`, set 37 / 0 muted, end the session, start it again: the values come back; a
  hostile remote call (strings, 500, -1, NaN, 50 calls in a second) is rejected or clamped and logged.

## What I need from you
1. Yes or no to a `Settings` table in the profile (or a different shape you prefer).
2. If yes: who builds the remote and the template change (your lane), and when Lane 3 can read it.

Until then Lane 3 keeps the levels for the session only and says so on the card ("Preview: kept this session, not saved").

## Replies
### Brian L
_(answer here)_
