---
title: "0011: eight plots per island server"
date: 2026-10-20
tags:
  - decision
  - island
  - design
status: accepted
---

# 0011: eight plots per island server

## Decision
Adam (repository owner and Lane 3 owner) decided on 2026-10-20 that the island has **8 plots instead of 12**, and that a server holds **at most 8 players**. Each plot is a 45 degree slice. The island keeps roughly layout option A's footprint (about 515 to 600 studs across at the water), and the room freed by the four removed plots goes to bigger Speedways. The walking target stays: any plot gate to any shared plaza destination in under 8 seconds.

The plot count is **one config value**. In the shared island it is the `PlotCount` attribute on `Workspace.Island` (draft contract: [[plot-marker-contract]]), and Lane 3's builder reads it from one `Layout.PlotCount` constant. Lane 2 code reads the attribute and never hard-codes 8.

Recorded by Claude Code from Adam's message in the island session. The measured 8-plot layout is in [[island-base]] (revision 2); it still needs Adam's go-ahead before Stage A.

## Supersedes
- [[car-hop-outline-v2]] section 04, "Delegated server size: 12 players per server, 12 plots", and "Twelve plots ring the plaza". The "about 20 seconds" crossing was already replaced by the under-8-seconds gate-to-destination target.
- [[car-hop-outline-v2]] section 15 (Stage 0, "island greybox with 12 plots"), section 17 open decision 7 ("12 proposed"), section 18's "12-player servers", and [[GDD]] (M0 row "island greybox with 12 plots"; open item "Server size (12 proposed)"). Those notes are left unedited; this decision takes precedence over them on plot count and server size.
- Layout option A's twelve 30 degree plots in revision 1 of [[island-base]].

## Why
- Adam's call: a smaller server, with room to make each player's Speedway a bigger, better track to watch.
- Measured (revision 2, computed, not yet built): at the same island size, each Speedway's lap grows from 250 to about 427 studs and the track widens from 11 to 16. The most cars a track holds at option A's spacing (a gap of at least 4.2) rises from 15 to 25. Each infield is about 8,600 square studs, with room for later tiers.

## Consequences
- **Lane 2 (Brian L):** plot assignment loops over `PlotCount`. The place's Max Players setting (set when publishing) must not exceed it; a start-up check is proposed in the contract. ProfileStore and the save schema are unaffected.
- **Lanes 1 and 2:** at a 15 second lap, a 427-stud path means about 28.5 studs/s. Lap time is Tunable, so they decide whether to keep 15 s or lengthen it. Lineup cars on 8 plots (up to 120 at 15 each) are the main performance cost: see the performance plan in [[island-base]].
- **Lane 3:** Stage A builds 8 plots. Shared destinations (Garage, portals, Stunt gate, leaderboards) stay on the plaza, on dividers.
- Social density is lower: at most 8 players. Revisit after the first multiplayer test, as outline open decision 7 already intended. Changing the count again means a new layout and `LayoutVersion`, not a code change in Lane 2.

## Reverting
Set `PlotCount` and the layout back to 12 slices and re-run the layout checks. Speedways would shrink back to about option A's 250-stud ovals at this island size.
