---
title: "0007: Car Hop selected as the concept; three-lane split"
date: 2026-10-19
tags:
  - decision
  - concept
  - workflow
status: accepted
---

# 0007: Car Hop selected as the concept; three-lane split

## Decision
1. **The concept is Car Hop** (working title). The team selected it at the 18 October 2026 meeting. The repository owner confirmed on 2026-10-19: "The team approved the Car Hop concept at the 18 October 2026 meeting. Approved, go ahead." That satisfies the selection rule in `AGENTS.md`: [[GDD]] now has `status: selected` and `concept: Car Hop`, and this note is the decision note.
2. **The approved outline is [[car-hop-outline-v2]].** [[car-hopping-game-outline]] (v1) stays as history. The outline's labels carry over into the GDD: Decided, Proposed (the outline's "Delegated"), Tunable, Deferred, Open. Only Decided items are settled; nothing Proposed or Tunable becomes a hard requirement by this note.
3. **Work is split into three lanes** with disjoint paths:

| Lane | Owner | Paths |
|---|---|---|
| 1 Driving | TBD | `src/client/Run`, `src/shared/Run` |
| 2 Data & Economy | TBD | `src/server`, `src/shared/Catalog`, `src/shared/Net` |
| 3 World, UI & Feel | the repository owner (name to be filled in) | `src/client/UI`, `src/client/Home`, `src/shared/UI`, and the shared place's Workspace |

4. **Shared contracts** (the catalog, the remotes, the save layout) are owned by Lane 2. They change only when all three lanes agree.
5. **Rojo connects only to a private Studio test place.** Each developer uses their own, never the shared Team Create place. The one exception is a single integration person (TBD), who may connect Rojo to the shared place.
6. **Area owners.** Until Lane 1 and Lane 2 have named owners, "owner" in `AGENTS.md` means the repository owner for those lanes. Once named, the lane owner approves samples and plans for the lane.

## What this does not approve
Selecting the concept is not approval of any propose-first item in `AGENTS.md`. Each needs benefit, cost, risk and a test presented, an explicit approval, and its own decision note before it is built:
- **Cash and the economy**, including every currency or economy field in the save (Cash, Lap Pay, Slots, Income Tier, last-seen time for offline earnings).
- **Paid items**: the three game passes. Monetization also needs an approved team design and a current Roblox policy check (`CLAUDE.md`).
- **Cross-server data**: the weekly leaderboards (OrderedDataStore) and shared ghost recordings are out of scope until approved.
- Anything touching saved data or shared contracts still needs a posted plan and an explicit go-ahead before coding.

## Why
- **Disjoint paths** keep merge conflicts rare for three people working in parallel, and each lane has one reviewer who knows the area.
- **One owner for contracts.** The catalog, the remotes and the save layout are what all three lanes depend on. A single owner, with all-lane agreement to change, stops two people changing a contract differently.
- **Private test places.** Rojo fully controls four folders (`Packages`, `Shared`, `Server`, `Client`) and deletes anything in them that is not on disk. Pointing three people's Rojo at one shared place would let one sync remove another's work, and a Rojo-synced test script appears for everyone in that place. The Workspace is not Rojo-managed, so Lane 3 builds the world in the shared place by hand in Studio.

## Open (boundaries nobody has decided)
These sit between lanes. They are questions, not rulings:
- **Who owns the run HUD** (Heat gauge, Keys meter, Hop icon)? It is UI (Lane 3) but driven by run state (Lane 1).
- **Plot assignment.** The code that gives a joining player a plot runs on the server (Lane 2); the plots themselves are in the Workspace (Lane 3). The names of the plot markers need agreeing.
- **Who builds the cars, road segments and scenery** (the World art), and the shared car rig, which Lane 1 and Lane 3 both touch.
- **Unowned paths.** `src/client` entry scripts, `src/shared` helpers, `wally.toml`, `default.project.json`, `AGENTS.md`, tooling and `vault/` have no lane. Raise a change on the board first.
- **How all-lane agreement is recorded** for a contract change. Suggestion only: a one-line "Agreed" from each lane owner on the board or in a decision note.
- **Who the integration person is**, and who owners of Lanes 1 and 2 are.

## Reverting
Set `status: draft` and `concept: undecided` in the GDD and mark this note superseded. The lane split can be changed on its own by a new decision note.
