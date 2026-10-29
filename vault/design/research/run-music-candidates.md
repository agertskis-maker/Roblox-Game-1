---
title: Run music candidates for the HUD preview (metadata-screened, NOT listened)
tags: [research, audio, lane3, music]
date: 2026-10-23
---

# Run music candidates (Round 2, R2-A)

Checked 2026-10-23 with no login, no Studio and no purchase. **Nothing here has been listened to.** No claim is made that any
track sounds good, fits a World, loops without a seam, or sits well under the HUD sounds. Every id came back from a Roblox API
response in this session (none guessed). Music in the preview is **off by default** (`Music.enable(true)` is the audition switch),
and review videos stay **muted** until the rights for video are established.

## Policy basis (see [[sound-candidates]] for the quotes and sources)
- Creator Store audio is free to use inside experiences; the licensed partner catalogue was kept public in 2022 (DevForum, BitFist,
  2022-03-09). These tracks are owned by the **APMOfficial** partner account (`7462718749`, `isVerifiedCreator`).
- Each id was checked on `apis.roblox.com/toolbox-service/v1/items/details` (`fiatProduct.isFree = true`, verified creator) and
  `economy.roblox.com/v2/assets/<id>/details` (`IsPublicDomain = true`, `IsForSale = false`). The search endpoint
  (`toolbox-service/v2/assets:search`, `searchCategoryType=Audio`, `userId=7462718749`) supplied title, artist, album, genre,
  duration and description.
- **Not verified:** whether the partner licence allows use outside Roblox (trailers, store videos, review recordings). Treat that as
  **no**. The licensed-music help page returned HTTP 403 when fetched during planning, so it was not read; this is a recorded
  limitation, not an assumption that it is fine.
- Not claimed: that any of these loops cleanly (they are 24-84 s edits, played with `Sound.Looped`), that any is suitable for
  children beyond the metadata filter (titles, albums and descriptions were screened for violent, holiday-jingle, casino and
  aggressive words), or that the per-World mood matches the brief (Downtown upbeat brass and bouncy bass; Dusty Highway twangy
  guitar and hand-clap rhythm; Summit Pass bells / strings and a steady kick; tension layers light, not ominous).

## The eight candidates (two per World and two tension layers)
Creator for all rows: APMOfficial, 7462718749, User. All free, public domain flag true, not for sale. Status for all: **candidate,
not listened**. "Seconds" is the search API's `durationSeconds`.

| Use | Asset id | Title (artist, library) | Seconds | Genre | Why it is a candidate (metadata only) | Known risk |
|---|---|---|---|---|---|---|
| Downtown A | 9043233916 | On The Double Funk (Bruton, Big Heavy Horn Riffs 3) | 31 | funk-soul-r-b | "Fast paced funk with sliding brass stabs": brass and bounce | "frenetic energy" may crowd the UI |
| Downtown B | 9045963404 | Jazz In Cantina B (MUSICA.IT, Italian Jazz Friends) | 31 | jazz | "Dynamic, lively and bright swing with virtuous guitar, sax and piano solos" | no brass; solos may be busy |
| Dusty Highway A | 9042728995 | That Summer (JGM Music, Arthouse Folk) | 30 | folk-contemporary | "relaxed acoustic guitar picks, warm bass, mellow melodica melody, tumbling percussion" | not twangy; may be too relaxed |
| Dusty Highway B | 9042459623 | Goodnight Ladies (Soho, Americana Acoustic) | 30 | ethnic-folk | "Bouncy hillbilly country western fun ... upbeat jolly happy comedy" | may read as comic or a parody |
| Summit Pass A | 9045486243 | Songbird (a 30) (Ded Good, Baby Acoustic) | 32 | folk-contemporary | fingerpicked guitar, "twinkling glockenspiel" and strings | very gentle; no steady kick |
| Summit Pass B | 1842008042 | Into the Blue Sky (a 30) (Alastair John King, Big Screen: Animation) | 31 | film-score | animation-style uplifting orchestral | no description in the metadata |
| Tension A | 9042246814 | Inquisitive (A1 Stealthy) (KPM Toolkit, Curiosity / Light Tension 2) | 24 | scores-orchestral | "light-footed pizzicato strings and mallets, 120 bpm": a light, sparse layer | short loop: repetition |
| Tension B | 1841766311 | Building Tension b (Tom Howe, Light Tension Beds) | 84 | orchestral-hybrid | a light tension bed | "building" arc may not suit a loop layer |

Searches that found nothing usable: Dusty Highway searches mostly returned score and ambient cues; the two Dusty candidates are the
nearest folk and country items, not a twang-and-clap match. A real match may need a different source or a commissioned track.

## How the preview uses them (what is checked, and what is not)
- **Controller:** `Prototype/Music.luau`. Signal path: `Lane3PreviewMusic` (the Settings level and Home toggle; Music Off is the
  parent at 0 and the controller also stops its voices) -> `Lane3Music_Duck` -> `Lane3Music_Base` (the World loop) and
  `Lane3Music_Tension`. The controller never writes the parent's volume.
- **One World loop at a time.** A World change crossfades over 1.2 s; the same World again is a no-op; rapid changes settle to one voice.
- **Tension layer, not a crossfade** (this is the approach tested; a crossfade variant was not built): nothing below 50% capture
  progress; 0.2 to 0.55 across 50-75%; at ALMOST and while SECURING it holds at a modest 0.8; the base bed sinks 35% under it. It never
  resolves by itself: only the confirmation resolves it (0.8 s); cancel, failure, leaving Run and the run ending fade it (0.4 s).
  It reads only the progress it is handed and changes no timing.
- **One duck source:** floor 0.6, attack about 80 ms, release about 400 ms, ref-counted by id (the same id never stacks). Only the
  KeysCapture, NewBest and Milestone stings duck; Results ticks and counts never do.
- **Checked by property in Studio Play** (scenarios `Music: ...`): off by default, mute and unmute, crossfade voice counts, no duplicate,
  no leak, tension levels and timings, duck level, attack and release, no stacking, and whether each SoundId loaded with a readable
  `TimeLength`. **Not checked:** how anything sounds, loop seams, loudness against the HUD sounds, whether the tracks fit the Worlds.

## Audition script for Adam (private test place only; nothing here is approved)
1. Open the HUD playground, press Play. In the left panel, "Run music (audition)": press **Music: enable**, then **Run**. Listen to
   Downtown; press **Downtown track B** and listen again.
2. Use the World buttons (Dusty Highway, Summit Pass) to hear each World's A and B. Note how the change sounds (crossfade, no gap).
3. Press **Tension: 60% hold**, **ALMOST**, **SECURING** one after another, then **resolve (confirmed)**. Then repeat and press
   **cancel**. Judge: does the layer clash with the loop? Does it stay out of the way of the SECURED sting?
4. Toggle the Home **Music** row to Off while a World is playing: it should stop and stay off.
5. Write down per track: keep, replace, or "does not fit". The table below is for that.

| Track | Heard? | Verdict |
|---|---|---|
| all eight | not yet | pending Adam |

## Round 3 (R3-A, 2026-10-26): approved tracks, event-driven fades, quieter bed
- **Adam approved the eight tracks above.** They are unchanged (same ids, same order). The A/B controls (`Music.useCandidate`)
  stay in the private audition harness only; the Settings panel has Music On/Off and a level, nothing else.
- **No per-frame work.** The controller has no Heartbeat connection and no polling thread. Every change (World, mute, enable,
  tension, duck, candidate) starts a finite `TweenService` tween that removes itself; the duck release is one cancellable
  `task.delay` per duck id. A steady loop writes no property.
- **Short smooth fades:** at most 0.4 s out and 0.3 s in everywhere (World change, first start from 0, Music Off/On, enable, tension
  start, confirm, cancel, an overflowing voice). A voice still fading out when its track is wanted again is revived (same Sound,
  no loop restart). No voice is destroyed in one frame any more.
- **Duck restores the player's level:** the duck is its own group under the player's level and nothing writes the player's level but
  the Settings controls, so a duck always releases to whatever the player set (also if they moved the slider during the duck) and
  Music Off stays Off through any sting.
- **Quieter bed:** every track plays at `Sounds.MIX.musicBed` (Volume 0.143, was 0.5), about -8 dB under Cash in effective terms.
  This is a proposal, not a listening result: raise it in `Sounds.MIX` if it is too quiet.
- Checks: `scenarios/Music.luau` (the 32 Round 2 assertions plus the Round 3 ones) and `scenarios/Mix.luau`. Property checks only.
- Review media: the licensed tracks and the chime / fanfare samples must stay out of exported review videos until the video rights
  are established (unchanged rule).
