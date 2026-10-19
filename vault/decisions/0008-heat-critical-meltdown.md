---
title: "0008: Heat Critical and Meltdown replace Blowout and Sputter"
date: 2026-10-19
tags:
  - decision
  - design
  - run
status: accepted
---

# 0008: Heat Critical and Meltdown replace Blowout and Sputter

## Decision
Decided by Adam (Lane 3 owner, repository owner) on 19 October 2026. It replaces the outline's earlier 100% Heat **Blowout** with its 1-second **Sputter** window ([[car-hop-outline-v2]] v2.0, section 06). That text is superseded; v2.1 of the outline and the [[GDD]] carry the new rule.

### Stages
| Internal stage | Heat | Player label |
|---|---|---|
| `Calm` | 0 to below 60% | Cool |
| `Warning` | 60% to below 85% | Hot |
| `Critical` | 85% to below 100% | Too hot! |
| `Meltdown` | 100% (escape window running) | Losing control! |

The thresholds 60% and 85% remain the outline's Proposed, Tunable values. The labels are the player-facing words; there are exactly four stages. Code uses the PascalCase names above as string values.

### Critical (85% to below 100%) - Decided
- The ridden car and the Heat gauge show escalating danger with **localized** red emphasis.
- Flashing speeds up as Heat approaches 100% and never exceeds **three flashes per second**. That is a ceiling, not a target, and not proof of accessibility. A restrained red pulse is preferred to hard on/off flashing.
- Never flash the whole screen; no red full-screen overlay. This replaces the outline's earlier "soft heat shimmer" at the screen edge.
- With reduced motion on: steady red emphasis, a warning label or icon, and stripes. No flashing, shaking, or pulsing.

### Meltdown (begins at 100%) - Decided
- Reaching 100% does not immediately eject the player or end the run.
- The car becomes difficult to control during a brief escape window.
- Hop stays available for the whole window.
- If a Keys meter completes during Meltdown, the car is still claimed.
- If the player does not escape before the window ends, the car crashes and the run ends.
- Escaping to another car clears the old car's Meltdown presentation, and the new car follows the existing rule: Heat resets on every Hop.

### Meltdown driving details - Proposed and Tunable, owned by Brian R (Lane 1)
- A three-second window.
- Sluggish or delayed steering.
- Increasing wobble and unintended sideways drift.
- Gradually falling speed.
- A final spinout.
- Controls are never inverted.

### Presentation (Lane 3)
- At Meltdown, Heat is shown as full and overheated, and the gauge bar turns into a clearly labelled **escape countdown** draining from full to empty, so it cannot be read as cooling down. It uses a smoke icon, danger stripes, and the "Losing control!" label, with the same localized flashing ceiling as Critical. With reduced motion, the countdown stays readable with steady styling.
- Proposed HUD input: `stage` may be `"Meltdown"`, and `meltdownRemaining01` is the remaining escape time normalized from 1 (start) to 0 (expired). The HUD only displays it.

## Responsibilities
- **Brian R (Lane 1, Driving):** Heat, the Meltdown timer, steering degradation, wobble and drift, speed loss, the spinout, Hop, and deciding escape or crash. The HUD never owns the real countdown or decides whether a player escaped.
- **Adam (Lane 3, World, UI & Feel):** HUD presentation and car-effect presentation (red emphasis, hood smoke, labels, countdown display). Lane 3 implements no driving, Hop, claiming, failure timers, or crash logic.
- **Brian L (Lane 2, Data & Economy):** authority over economy, ownership (a claim completed during Meltdown is still granted by the server), and all authoritative state.
- **Interfaces stay provisional** (HUD state fields, stage names as values, any car-effect call) until all three lanes agree, per [[0007-concept-car-hop-and-lanes]].

## Why
A hard stop at 100% with one second of Sputter punishes a near miss. A short, readable escape window keeps the tension (the car fights you) while giving the Hop a dramatic last chance, which suits a mainly young audience: failure stays readable and fair.

## Consequences
- Run-end causes now read "Meltdown escape window expired" instead of "Sputter window missed".
- The outline's acceptance criteria and test list gain: a claim completes during Meltdown; an escape cancels Meltdown presentation; reduced motion removes flashing, shaking, and pulsing.
