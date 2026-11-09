---
title: "0044: Lane 3 Round 8 (Adam's decisions of 2026-11-08 and the lead's calls)"
tags: [decision, lane3, round8]
date: 2026-11-08
---

# 0044: Lane 3 Round 8

Numbered 0044 because `0043-official-name-car-catchers.md` already exists on Brian L's unmerged `feature/lane2-luck-in-beta`.
Brief: [[lane3-round8]]; ledger and agent map: [[lane3-round8-ledger]]; contracts: [[lane3-round8-contracts]].

## Adam's decisions (brief section 0, decided, recorded here as asked)

1. Many Sonnet 5.5 builder agents, a Sonnet reviewer per workstream, one Opus 5.5 reviewer over all of it with Opus fixers.
2. Every Round 7 leftover is in this round (permissions, group uploads, Robux products and test purchases, PR merges, the publish, long runs, Heat measurement, 360-degree Launch Pad check, the Round 7 reviewers' list).
3. Push everything first; merge PR #15 once its check passes; PR #18 merges with Round 8 under the F-02 rule.
4. Lane 3 code on `feature/lane3-round8`, the beta on `integration/beta-6`, run changes on `feature/lane1-round8-from-adam` with a pull request into Brian R's branch; never merge Brian R's or Brian L's branches.
5. Round 7's permission to edit every lane carries on for the brief's items; a teammate's Replies section wins.
6. The Raceway and Parking upgrade screens keep the racetrack frame and are built almost exactly like ChatGPT's images.
7. The Lucky Clover stand is run by a proper four-heart-leaf clover mascot.
8. Your cosmetics show on your car in the run.
9. Picking a car gives a clear confirmation.
10. The Stunt Circuit's outer sign and cones are deleted; the inside preview sign stays.
11. Robux selling stays off in the published beta (`RealPurchases = false`); products are created once the permission works.
12. Publish to the private beta (place 118605678346800) at the end.
13. ParticleFX Studio's free flipbooks are used for trails and other effects (free downloads only, uploaded under LEGION STUDI0S, each listed in `assets.md`).
14. Not this round: real sales, a public publish, cross-server leaderboards, trading, new currencies, new Worlds, limited-time anything, paid luck.
15. (Added 2026-11-08 mid-review) No guidance arrows while riding; a landing ring and a chevron dive path only during the float; the button flips HOP to DIVE.

## The lead's calls

See the ledger's "Lead's calls" list. The ones that change how the code is organised:
- The look belongs to the player (Round 7 rule kept): `Equipped` applies to whichever car you ride or display; caught cars keep their own look; your trail follows you.
- One `CarLook` data shape (`src/shared/Style/CarLook.luau`) and one client applier (`CarLookApplier`) for every car display.
- A new beta save field `RideCar` and remote `PickRideCar(carId)` for the car-pick confirmation (C-03), listed for Brian L.
- One art registry `src/shared/Style/AssetIds` (per-workstream sub-modules) with a code-drawn fallback, so a missing upload never shows a blank image and the live game never asks for a laptop-only file.
- One shared glossy button and cannot-afford treatment (`R8Kit/GlossButton`) for every card.
