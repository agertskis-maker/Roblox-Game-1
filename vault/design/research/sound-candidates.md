---
title: Sound candidates for the Lane 3 HUD (not listened)
tags: [research, audio, lane3]
date: 2026-10-22
---

# Sound candidates for the Lane 3 HUD

Research only, checked on 2026-10-22. Nothing here is approved, inserted, or listened to. Every asset ID below came back from a Roblox API response in this session; none is guessed. Each one is "candidate, not listened" until someone hears it in a private test place.

## A. Policy: what the official sources say, and what I infer

**Stated in docs or official announcements (quoted):**

1. Creator Store audio is free to use. `create.roblox.com/docs/audio/assets` (source `Roblox/creator-docs` `content/en-us/audio/assets.md`): the Creator Store "contains a wide variety of free-to-use audio assets made by Roblox and the Roblox community for creators to use within their games, including more than 100,000 professionally-produced sound effects and music tracks from top audio and music partners."
2. The partners and the public rule (2022). DevForum announcement "[Action Needed] Upcoming Changes to Asset Privacy for Audio", BitFist, 2022-03-09 (`devforum.roblox.com/t/1701697`): "more than 100,000 new professionally-produced SFX from top audio and music partners like APM, Monstercat, Pro Sound Effects, Nettwerk Music Group and Position Music". It also says "All of the Roblox official licensed catalog of Music and SFX will remain Public and usable by developers in any of their experiences."
3. The privacy change and the 6-second rule. Same post: "On March 22, all new audio uploaded will be Private and all existing audio longer than 6 seconds will be set to Private". It continues: "the audio assets in your experience will stop working if they were not uploaded by the same user or Group who created the experience."
4. Pro Sound Effects naming. Follow-up "[Update] Changes to Asset Privacy for Audio", 2022-03-16 (`devforum.roblox.com/t/1715717`): "over 100,000 professional SFX ... in partnership with Pro Sound Effects. These assets will be available for public use in the marketplace tonight, and can be found by searching for '[name] (SFX)'." The same post says "This release is specifically targeting music" and that a team was "working to keep many SFX public, even if the asset is longer than 6 seconds."
5. Sharing private audio. `devforum.roblox.com/t/2725248` (2023-12-01) and `/t/3269446` (2024-11-22): private audio can be shared with friends and groups. Experiences that already use a shared asset keep access after it is revoked.
6. The Asset Privacy setting does not cover audio. `create.roblox.com/docs/projects/assets/privacy`: "Asset Privacy controls only the default privacy state assigned to Images, Decals, and Meshes"; "Audio, Video, Models, MeshParts, Animations, and Packages ... have their own creation defaults".
7. Upload limits (our own uploads only). `audio/assets.md`: files must be "less than 20 MB in size and 7 minutes in duration", with a sample rate of 48 kHz or less. The limit is 2,000 uploads per 30 days if ID-verified and 100 if not. You also need "the legal rights to that audio asset."
8. Volume and SoundGroups. `create.roblox.com/docs/sound/groups`: `SoundGroup.Volume` is "a volume multiplier between 0 and 10". A Sound at 0.5 in a group at 0.5 plays at 0.25. Ducking uses `CompressorSoundEffect`, and the reference mix gives **GUI Notifications** high priority. `sound/objects.md`: "you likely don't need to increase the volume to more than 2". The "Play interface audio" section uses a `Sound` in `SoundService` played on `GuiButton.Activated`.
9. Sound versus AudioPlayer. `audio/assets.md`: "`Sound` objects don't have the same dynamic functionality as `AudioPlayer` objects." Our `Sounds.luau` uses `Sound`. That is fine for one-shot UI sounds; this is a note for later, not a change.

**Inferred (not stated anywhere I found):**

- Assets owned by **Roblox (user 1)** and listed free in the Creator Store are the safest picks. They are first-party, `IsPublicDomain=True`, and listed free.
- I believe **APMOfficial (7462718749)** and **ProSoundEffects (7462895450)** are the partner accounts, but nothing official says so. Evidence for: the asset descriptions end "Courtesy of APM Music." / "Courtesy of Pro Sound Effects."; the PSE titles use the announced "(SFX)" suffix; the toolbox API marks both as `isVerifiedCreator: true`; and each account owns thousands of uploads. Evidence against: `users.roblox.com/v1/users/{id}` shows `hasVerifiedBadge: False` and `created: 2024-10-14` for both accounts, but their assets date from 2018 and 2022. I infer the assets were moved to these accounts in October 2024, but I found no announcement of that move.
- I found no doc giving a numeric "UI sound volume" guideline. The mix levels below are my proposals.
- Not verified: whether the partner licences allow use outside Roblox (trailers, store videos). Treat that as **no** until checked.

## Method and which APIs worked

| Endpoint | Result |
|---|---|
| `apis.roblox.com/toolbox-service/v1/marketplace/10?keyword=coin` | 200, but category 10 returns **Models** (typeId 10), not audio. Not usable. |
| `.../v1/marketplace/1?...` | 400 `"The value '1' is invalid."` |
| `.../v1/marketplace/3?keyword=coin&num=10` | 200, audio (type 3), IDs only |
| `.../v2/assets:search?searchCategoryType=Audio&query=Q&maxPageSize=30&userId=U` | **Used.** 200, with creator, `durationSeconds`, `audioType` and `createTime`. The `userId=` filter works; `creatorTargetId=` and `creatorId=` were silently ignored. |
| `.../v1/items/details?assetIds=...` | **Used for verification.** Returns creator name, id, type and `isVerifiedCreator`; `typeId=3`; `duration` (whole seconds); `audioDetails`; description; `fiatProduct.isFree` |
| `economy.roblox.com/v2/assets/ID/details` | **Used for verification.** `Creator.Name`/`Id`/`CreatorType`, `IsPublicDomain`, `IsForSale` |

No login, no Studio, no purchases. The API's `duration` is a whole number. The PSE and APM descriptions give finer values, and one disagrees with it: APM 1842335078 reads "Duration: 2 seconds" while the API says 3. Treat the API seconds as approximate; 0 means under about 1 s.

Gaps: searches under user 1 for "fanfare", "chime", "success", "tick", "warning", "cash" and "money" found nothing. Those categories use partner assets or the nearest Roblox-owned sound.

## B and C. Listening table (16 candidates, all verified)

All 16 returned `typeId=3`, `fiatProduct.isFree=True` from items/details, and `IsPublicDomain=True`, `IsForSale=False` from economy v2. Creator type is User (`type=1`) for every row. Evidence URL pattern: `https://apis.roblox.com/toolbox-service/v1/items/details?assetIds=<id>` and `https://economy.roblox.com/v2/assets/<id>/details`. Volume is the per-`Sound` value; it is multiplied by the group "Lane3PreviewUI" (0.6 today).

| Category | Asset id | Title | Creator (name, id, type) | Key fields | Duration | Proposed Volume | Trigger in our HUD | Status |
|---|---|---|---|---|---|---|---|---|
| Button pop/click | 15675032796 | Roblox_UI_Small_Click | Roblox, 1, User | created 2023-12-18; audioType SoundEffect | 0 s (API) | 0.35 | `Tap`, `Close` (Gloss buttons, CarCard, Prompts, Overlay) | candidate, not listened |
| Button pop/click | 15675059323 | Roblox_UI_Bright_Click | Roblox, 1, User | created 2023-12-18 | 0 s (API) | 0.35 | `Open` (Overlay, Settings) | candidate, not listened |
| Cash ding/coin | 127645268874265 | CoinTransfer_01 | Roblox, 1, User | created 2024-10-28 | 2 s (API) | 0.3 | `CashGain`; `LapPay` (already throttled to 0.25 s) | candidate, not listened |
| Cash ding/coin | 9126073001 | Synth Sparkle Tone High Pitch Bell Tone Ding (SFX) | ProSoundEffects, 7462895450, User | "Duration: 1.2 seconds ... Category: User Interface ... Courtesy of Pro Sound Effects." | 1.2 s (desc) | 0.3 | `CashGain` (alternative) | candidate, not listened |
| Capture riser | 16480578169 | Audio/Roblox_Pinball_8Bit_Riser_01 | Roblox, 1, User | created 2024-02-22 | 2 s (API) | 0.3 | Keys hold (`KeysTick` quarters, or one riser at Holding start; this needs a hook decision) | candidate, not listened |
| Capture riser | 9117885256 | Power Up Sweeteners 10 (SFX) | ProSoundEffects, 7462895450, User | "Duration: 1.1 seconds ... Category: Switches" | 1.1 s (desc) | 0.3 | same as above | candidate, not listened |
| Capture fanfare | 12222253 | victory.wav | Roblox, 1, User | created 2009-06-24; desc `\sounds\victory.wav` (old, check quality) | 1 s (API) | 0.45 | `KeysCapture` (CaptureCelebration) | candidate, not listened |
| Capture fanfare | 1842335078 | Cartoon Fanfare (c) | APMOfficial, 7462718749, User | "Trumpet announcement. Duration: 2 seconds ... KPM 1000 LP Series ... Courtesy of APM Music." audioType SoundEffect | 2 s (desc), 3 s (API) | 0.4 | `KeysCapture`; maybe `NewBest` | candidate, not listened |
| Toast/tutorial chime | 17208361335 | Roblox GUI - Notification High | Roblox, 1, User | created 2024-04-19 | 2 s (API) | 0.3 | `Toast` (ToastStack, AlreadyOwned), `Milestone` | candidate, not listened |
| Toast/tutorial chime | 15675043410 | Roblox_UI_Tonal_Stinger | Roblox, 1, User | created 2023-12-18 | 1 s (API) | 0.35 | `TutorialDone` (TutorialBanner) | candidate, not listened |
| Warning blip | 17208353912 | Roblox GUI - Negative | Roblox, 1, User | created 2024-04-19 | 0 s (API) | 0.25 | no hook yet (would need a new `Warning` hook) | candidate, not listened |
| Warning blip | 16480580213 | Audio/Roblox_Pinball_8Bit_Blip_01 | Roblox, 1, User | created 2024-02-22 | 1 s (API) | 0.25 | same | candidate, not listened |
| Cartoon bonk/boing | 12222124 | Short spring sound.wav | Roblox, 1, User | created 2009-06-24 (old) | 1 s (API) | 0.35 | `Hop` (HopButton via Gloss `sound = "Hop"`) or a future blocked/bump hook | candidate, not listened |
| Cartoon bonk/boing | 9113854234 | Comic Boinks 1 (SFX) | ProSoundEffects, 7462895450, User | "Comic Boinks, Synth Tone Bursts, Springy, Funny ... Duration: 1.1 seconds ... Category: Stings" | 1.1 s (desc) | 0.35 | same | candidate, not listened |
| Results tick | 16480579910 | Audio/Roblox_Pinball_8Bit_Blip_03 | Roblox, 1, User | created 2024-02-22 | 0 s (API) | 0.2 | `ResultsCount`, if made a throttled per-step tick (today it fires once at count start) | candidate, not listened |
| Results tick | 16480554151 | Audio/Roblox_Pinball_Scoreboard_Tally_Loop_01 | Roblox, 1, User | created 2024-02-22; a **loop** | 5 s (API), over 2 s | 0.2 | `ResultsCount` as a loop stopped when the count ends (needs stop support in `Sounds.luau`) | candidate, not listened |

Excluded on purpose: `Roblox GUI - Purchase` (17208380755) and `RBLX UI Purchase (SFX)` (10066947742). A purchase-like chime on a cash gain could read as a Robux purchase to children. All APM "Win"/"Winner"/"Jackpot" stings were also left out: they are 3 to 10 s long and some have casino names (for example "Jackpot Mania"), which does not fit our audience.

## Listening checklist (owner)

- Listen in a **private test place** only. Each cue needs a short attack, no harsh high end, and nothing that sounds like a Roblox platform notification (inference: several "Roblox GUI" sounds may be the ones Roblox's own app chrome uses).
- Check loudness against each other at the proposed Volumes, inside the 0.6 group. Lower any that stand out rather than raising the others.
- Confirm the true length in Studio (`Sound.TimeLength`). The API values are rounded.
- Before shipping, record each chosen ID and its evidence in a decision note, as `Sounds.configure` asks ("record its source").

## Existing big-gain cash sound: what is actually in the repo

Searched `src` on 2026-10-22 for `rbxassetid` and `SoundId`:

- `rbxassetid` appears only in `src/lookdev/Downtown/Builder.luau` (lines 54 and 164), for a texture palette. It is not audio.
- `SoundId` appears once, at `src/client/UI/Prototype/Sounds.luau:86`, which assigns whatever ID was passed to `Sounds.configure`. No caller in `src` calls `Sounds.configure`, so **no sound asset is inserted anywhere**. The file header says so: "No sound asset is inserted overnight ... every hook is silent by default".
- The big-gain sound is the `CashBig` hook. `CashLine._apply` (`src/client/UI/Prototype/Home/CashLine.luau:541-556`) plays `CashBig` when gain ≥ `max(BigGainFraction × previous, BigGainMinimum)` and at least `BigGainCooldown` seconds have passed since the last big gain. Otherwise it plays `CashGain`. The values are `PreviewTokens.luau:103-105`: fraction 0.1, minimum 500, cooldown 8 s.

So "preserve the approved big-gain audio" means **keep the `CashBig` hook, its threshold and its 8 s throttle**. There is no asset to keep or replace. `CashBig` stays unassigned in this note: the table offers cash-ding candidates for `CashGain`. A `CashBig` sound needs its own listening pass and owner choice, for example a brighter variant at about +2 dB (Volume about 0.4).

---

# Round 3 (R3-A, 2026-10-26): the Keys screech, the chime ladder, the fanfare, the mix

Written by worker W7. **Nothing here was listened to.** Every statement below is about properties (which sample, which
Volume, how many voices, what spacing) or about code, never about how anything sounds. No new asset id was added: every id is
from the verified list above.

## What made the screech (read from `Prototype/Sounds.luau` before Round 3)
- `KeysLock` called `Sounds.rise("KeysRise", progress)` on every progress update. `rise` made ONE **looped** voice (`Looped = true`)
  of the candidate `Roblox_Pinball_8Bit_Riser_01` (16480578169, a 2 s sample that itself sweeps upward) and rewrote its
  `PlaybackSpeed` on every call, from 0.9 to 1.25 of the sample speed (a 5.7 semitone range, up to +3.9 above the sample's pitch).
- So the sound was a sample that already rises (judged from its title and 2 s length, not from listening), looped (by
  construction the sweep restarts every two seconds), with its pitch pushed up on top, and driven by progress ticks that can arrive
  every frame. That is a sustained rising tone rather than a cue. Turning its Volume down would keep that shape; that is why the fix
  replaces the shape.
- `KeysTick` (a throttled 8-bit blip per lit segment from 50%) was layered on it: stacked voices.

## What replaced it
| Part | Round 3 behaviour |
|---|---|
| Progress cue (`Sounds.rise`) | A **ladder of at most 4 discrete notes**, one per quarter of the supplied progress, never closer than 0.25 s, each a fresh one-shot (`Looped = false`) trimmed to 0.55 s with a 0.15 s fade-out. One sample, played at fixed `PlaybackSpeed` set once at creation: 0.749, 0.841, 0.944, 1.000 (semitones -5, -3, -1, 0: five semitones in all, never above the sample's own pitch). No per-frame property write; at most 2 note voices alive. |
| Cancel / replace / run end (`Sounds.stopRise`) | Ringing notes fade out in 0.12 s and the ladder resets. A ring-full note that sounded under 0.55 s ago is left to finish unless `stopRise(hook, true)`. |
| Ring full, answer pending (`KeysPending`) | The ladder's last note, quiet (Volume 0.17 against 0.22 for the other notes), once per capture. No fanfare, no victory. |
| Confirmed capture (`KeysCapture`, once via `Sounds.fanfare(key)`) | The short sting `Cartoon Fanfare (c)`, trimmed to 1.8 s with a 0.3 s smooth tail; it ducks the music (one source, floor 0.6). Plays only when the caller says the capture is CONFIRMED. |
| `KeysTick` | Retired (silent). It would stack on the notes; progress sounds are sparse by design. |

## Used ids after Round 3 (every id is on the verified list above; "not listened" for all)
| Asset id | Name | Creator (id) | Verified status in this note | Where it is used |
|---|---|---|---|---|
| 9126073001 | Synth Sparkle Tone High Pitch Bell Tone Ding (SFX) | ProSoundEffects (7462895450) | free, `IsPublicDomain`, not for sale (table B/C); partner account is an inference | **Keys chime notes** (`KeysRise`, `KeysPending`) as category "Note" candidate 1; also Cash candidate 2 (A/B only) |
| 15675043410 | Roblox_UI_Tonal_Stinger | Roblox (1) | same | "Note" candidate 2 (A/B only; a stinger may not be a single pitched note, so pitch steps may sound odd) and "Chime" candidate 2 |
| 1842335078 | Cartoon Fanfare (c) | APMOfficial (7462718749) | same; the API says 3 s, the description 2 s | `KeysCapture` (and `NewBest` at a lower Volume), trimmed to 1.8 s |
| 12222253 | victory.wav | Roblox (1) | same; old, quality unknown | "Fanfare" candidate 2 (A/B only) |
| 15675032796 | Roblox_UI_Small_Click | Roblox (1) | same | `Tap`, `Open`, `Close` |
| 15675059323 | Roblox_UI_Bright_Click | Roblox (1) | same | "Click" candidate 2 (A/B only) |
| 127645268874265 | CoinTransfer_01 | Roblox (1) | same | `CashGain`, `LapPay` |
| 16480578169 | Roblox_Pinball_8Bit_Riser_01 | Roblox (1) | same | `HopLock` only (a one-shot lock-on whoosh, 0.6 s throttle). **No longer used for Keys.** |
| 9117885256 | Power Up Sweeteners 10 (SFX) | ProSoundEffects (7462895450) | same | "Rise" candidate 2 (A/B only) |
| 17208361335 | Roblox GUI - Notification High | Roblox (1) | same | `Toast`, `Milestone`, `TutorialDone`, `Unlock` |
| 16480580213 | Audio/Roblox_Pinball_8Bit_Blip_01 | Roblox (1) | same | `Warning` (candidate 1); "Tick" candidate 2 (A/B only) |
| 17208353912 | Roblox GUI - Negative | Roblox (1) | same | "Warning" candidate 2 (A/B only) |
| 9113854234 | Comic Boinks 1 (SFX) | ProSoundEffects (7462895450) | same | `Bonk`, `Hop` |
| 12222124 | Short spring sound.wav | Roblox (1) | same; old | "Bonk" candidate 2 (A/B only) |
| 16480579910 | Audio/Roblox_Pinball_8Bit_Blip_03 | Roblox (1) | same | `ResultsTick`; "Tally" candidate 2 (A/B only) |
| 16480554151 | Audio/Roblox_Pinball_Scoreboard_Tally_Loop_01 | Roblox (1) | same; a designed loop | `ResultsCount` (the Results count-up loop). Before Round 3 the loop played the 0-1 s blip above with `Looped = true` (a buzz); this loop was only a second candidate. |

The eight APMOfficial run-music tracks are unchanged and APPROVED (Adam, Round 3): see [[run-music-candidates]].
"Copyrighted" does not mean unusable: these are licensed catalogue items offered free in the Creator Store for use inside
experiences; whether any may be used in video outside Roblox is still **not** established (treat as no).

## The mix (one table, `Sounds.MIX`; relative levels, property checks only)
Reference groups: effects `Lane3PreviewUI` 0.6, music `Lane3PreviewMusic` 0.5 (the Settings defaults). Reference effect Volume
0.3 (Cash). Per-hook target Volume (before the group): Tap/Open 0.26, Close 0.20, CashGain 0.30, LapPay 0.20, Toast 0.24,
TutorialDone/Unlock/Milestone 0.28, Warning 0.32, Bonk 0.30, Hop 0.20, HopLock 0.16, chime notes 0.22, ring-full cue 0.17,
**fanfare 0.36**, NewBest 0.30, ResultsTick/ResultsCount 0.16. Caps: no effect above 0.40; all live effects together at most 0.90
(a new sound is scaled to the headroom, or dropped if under half of itself would fit); 6 voices at once, 2 per hook;
throttles per hook as before (Results tick now 0.12 s). **Music bed: -8 dB under Cash**, in effective terms (Volume x group):
bed Volume 0.143 x 0.5 = 0.072 against Cash 0.3 x 0.6 = 0.18; the tension layer adds at most 0.8 of the bed and dips the base
by 35%, so all music voices together stay under 0.22 before the player's own level. A fanfare ducks the bed another 0.6.
All of this is checked by `scenarios/Mix.luau` as property sums and counts. The levels are proposals; they need a listening pass.

## Needs lead: search briefs (only if the listening pass rejects the current picks)
1. **Gentle chime note.** A single soft pitched note, glockenspiel / celesta / marimba / soft bell, 0.3 to 0.8 s, clear fundamental
   pitch (so it can be pitch-shifted down up to 5 semitones), quick attack, natural decay, **no noise tail, no reverb wash, no
   vibrato, no sweep**, no brand sting. Creator Roblox (1) or a partner account, free, `IsPublicDomain`, not a "Roblox GUI" notification sound.
2. **Short celebratory fanfare.** 1 to 2 s, brass and bell in a major key, ends cleanly (no long reverb tail), friendly and
   bright, not a casino or "jackpot" sting, not a siren, no vocals. Same licence checks.
Both would replace a Round 3 candidate through the "Note" and "Fanfare" categories without any other code change.

## Not verified
Nothing about how any of this sounds: not the chime pitch steps on this sample, not the fanfare trim point, not the levels, not whether
the 0.55 s trim cuts the bell tail unpleasantly. Whether the sample at -5 semitones keeps a recognisable bell character is unknown.
