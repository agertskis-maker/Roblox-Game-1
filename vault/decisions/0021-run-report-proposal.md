---
title: "0021: proposal: what a run reports to the server (Lane 1 to Lane 2)"
date: 2026-10-25
tags:
  - decision
  - lane1
  - run
  - shared-contract
status: proposed
owner: Brian R (Lane 1)
needs: "Agreed" from Brian L (Lane 2) and Adam (Lane 3), because it shapes the remotes
---

# 0021: proposal: what a run reports to the server

**Status: Proposed.** Nothing here is built. It is the starting point for Brian L's remotes in `src/shared/Net`. It follows outline v2 section 06 ("Where runs happen"): the run plays on the player's device, the server hands out a seed, and the server spot-checks what the player reports against that seed. The outline marks this as reversible.

## The one rule

The player's device reports **what happened**. It never sends an amount, a price, a car to give, or a result. The server decides whether something counts and what it pays. Anything that fails a check is dropped silently and logged; the run keeps going and the player is never kicked for it.

## How a run flows

1. **Start.** The client asks to start a run in a World with a chosen starting car. The server checks the World is unlocked and the car is owned (or is that World's Loaner), then replies with a `runId`, a `seed`, the run profile name (`Highway` today; see [[0022-circuit-run-profile-proposal]]) and the tuning version. Seed plus profile fully decide the traffic. The server records the start time on its own clock. One active run per player; starting a new one ends the old one.
2. **During the run.** The client sends small batches of events about once a second. A **Keys complete** event is sent straight away, not batched, so the "You got the Keys!" card is not delayed.
3. **Server replies.** For each accepted event that pays or grants something, the server tells the client what it granted (car claimed, Joyride paid, coins paid, Milestone paid) so the HUD and Results can show real numbers. Cash is added as it happens, so a disconnect loses nothing already earned.
4. **End.** The client sends a run-end event. If the player disconnects, the server closes the run at the last accepted event.

## The shared sequence (what makes checking possible)

A shared module, `src/shared/Run/RunSequence.luau` (built on `feature/lane1-run-prototype`), turns a seed and a run profile into the same list on the client and the server:

- every traffic car, by **spawn index**: model, Variant, lane or x position, spawn distance, speed, and its scheduled lane changes
- every coin, by **coin index**: distance and position
- hazards and Gaps

To keep both sides identical, the sequence must be built only from the seed and distance (or run time), never from the frame rate, the player's input, or `os.clock`. Traffic never reacts to the player. Bump "nudges" are a visual offset that fades out; they never move a car's real path.

## Events the client reports

Every event carries `t` (seconds since run start, client clock) and `d` (distance along the road in studs). Events must arrive in order.

| Event | Extra fields | What the server checks |
|---|---|---|
| **Hop** | `x` (sideways position), `target` (spawn index, or 0 = landed on the road) | The target car exists in the sequence and is within that family's Hop range of (`d`, `x`) at time `t`, with tolerance. A Hop from the road also counts as a "Nice save!" (server decides). |
| **KeysComplete** | `index` (spawn index) | The player landed on this car and has not hopped since; time aboard ≥ that rarity's Keys time (from the Catalog), minus a small tolerance; this car instance has not paid before. The **server** then decides: unowned model = claim, owned model = Joyride Bonus. |
| **Coins** | list of coin indexes | Each coin exists, has not been taken, and was near the player's distance at that time. Capped per run. |
| **RunEnd** | `cause` (Meltdown, FootDash, Crash, Construction, Gap, Quit) | Pauses the run; it closes for good when no Revive follows. |
| **Revive** (added 2026-10-26, only if [[0022-circuit-run-profile-proposal]] keeps free revives) | `target` (spawn index landed on, 0 = a fresh Loaner) | The player has a free revive left; the run continues from the same distance. |

**Derived by the server, not reported:** Milestones (from accepted distance), the "Nice save!" bonus (from a Hop that starts on the road), and the Results totals.

## Plausibility checks on every batch

- **Distance vs time:** `d` can't grow faster than the fastest ridden car allows, with tolerance.
- **Clock:** `t` can't run ahead of the server's own elapsed time for this run by more than a small margin.
- **Heat cap:** no single ride lasts longer than that family's Heat Capacity plus the Meltdown window plus tolerance. The server does not simulate Heat; this one check stops a "never overheat" cheat from stretching a run.
- **Rate:** a maximum number of events per batch and batches per second; unknown `runId` is ignored.

Starting tolerances are Tunable and set during the Stage 1 playtest.

## Stunt Circuit (later, Stage 6)

Race times affect the weekly leaderboard, so they get stricter checks than runs: checkpoint split times reported in order, a minimum time per segment, and a ghost recording the server can sanity-check before a time is posted. Specified when Stage 6 starts; not part of this contract.

## What belongs to whom

- **Lane 1 (Brian R):** `RunSequence` and run tuning in `src/shared/Run`; the client run in `src/client/Run`, which produces the events above.
- **Lane 2 (Brian L):** the remotes in `src/shared/Net`, all server checks, payouts, ownership and logging. Keys times, Heat Capacities, Hop ranges and speeds come from the Catalog.
- **Lane 3 (Adam):** draws the HUD and Results from numbers Lane 1 gives it locally (Heat, Keys progress, distance) and from what the server confirms (Cash, claims).

## Questions for Brian L

1. One batched "run events" remote plus a separate "Keys complete" remote, or one remote for everything?
2. Should the "You got the Keys!" card wait for the server to confirm (safer, about 0.1 to 0.2 s later), or show at once and be corrected if rejected? I suggest waiting; Heat is paused during the card anyway.
3. Where should rejected events be logged so we can tune tolerances in playtests?
4. Does the server re-run `RunSequence` in full for each check, or cache each run's list? (Affects server cost with 12 players.)

## Note from Adam's steering direction

Adam wants free left/right steering (A/D, thumbstick) instead of fixed lanes. This proposal already supports it: the Hop event carries a sideways position `x`, and checks use distance to the target rather than lane numbers.
