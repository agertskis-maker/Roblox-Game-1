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
- *Superseded by the amendment below (no visible timer):* At Meltdown, Heat is shown as full and overheated, and the gauge bar turns into a clearly labelled **escape countdown** draining from full to empty, so it cannot be read as cooling down. It uses a smoke icon, danger stripes, and the "Losing control!" label, with the same localized flashing ceiling as Critical. With reduced motion, the countdown stays readable with steady styling.
- *Superseded by the amendment below:* Proposed HUD input: `stage` may be `"Meltdown"`, and `meltdownRemaining01` is the remaining escape time normalized from 1 (start) to 0 (expired). The HUD only displays it.

## Responsibilities
- **Brian R (Lane 1, Driving):** Heat, the Meltdown timer, steering degradation, wobble and drift, speed loss, the spinout, Hop, and deciding escape or crash. The HUD never owns the real countdown or decides whether a player escaped.
- **Adam (Lane 3, World, UI & Feel):** HUD presentation and car-effect presentation (red emphasis, hood smoke, labels, the alarm; the countdown display was dropped by the amendment below). Lane 3 implements no driving, Hop, claiming, failure timers, or crash logic.
- **Brian L (Lane 2, Data & Economy):** authority over economy, ownership (a claim completed during Meltdown is still granted by the server), and all authoritative state.
- **Interfaces stay provisional** (HUD state fields, stage names as values, any car-effect call) until all three lanes agree, per [[0007-concept-car-hop-and-lanes]].

## Amendment, 2026-10-19 (later the same day): no visible escape timer
Decided by Adam during the Lane 3 HUD review. It supersedes the two Presentation bullets above that describe an escape countdown and `meltdownRemaining01`; those bullets are kept as history.

- **No visible escape timer during Meltdown.** No "ESCAPE TIME" text, no clock icon, no draining bar, and no numeric or visual sign of seconds left. The escape window itself still exists and still belongs to Lane 1 (Brian R); only what the HUD shows changes. The 3-second window, steering, wobble, drift, speed loss and spinout stay Proposed and Tunable with Lane 1.
- **Meltdown presentation:** the Heat bar stays full and joins the localized alarm; the stage label "Losing control!" is joined by the instruction **HOP NOW!**, styled as an instruction, not a button; smoke escapes from the thermometer's lifted cap; the panel alarm is more urgent than Critical but under the same flash ceiling.
- **Continuous Heat display:** the thermometer liquid and the bar follow Heat continuously with frame-rate-independent smoothing. The bar is a fixed blue-to-red temperature scale revealed from the left, so the colour at its tip always equals the liquid colour at the same Heat. Colour stops: Calm blue at 0%, Warning yellow at 60%, an orange in between, Danger red at 85%, staying in the red family to 100%.
- **Critical panel alarm:** the Heat panel itself pulses between cream and a light alarm red, with a restrained halo, a slightly thicker border, stronger stripes and two siren lights. One shared presentation alarm clock drives the panel, the sirens and, later, the car's emphasis, so they stay in phase. All visible peaks combined stay under three per second.
- **Reduced motion:** steady light-red panel, solid siren lights, static stripes, a still smoke cloud, readable labels and HOP NOW!; no flashing, halo growth, shaking, sloshing or cross-fade.
- **Proposed HUD input now:** `{ heat, stage }` (plus Cash and Distance). `meltdownRemaining01` is no longer needed; if supplied it is ignored. Still provisional until the lanes agree.

## Why
A hard stop at 100% with one second of Sputter punishes a near miss. A short, readable escape window keeps the tension (the car fights you) while giving the Hop a dramatic last chance, which suits a mainly young audience: failure stays readable and fair.

## Consequences
- Run-end causes now read "Meltdown escape window expired" instead of "Sputter window missed".
- The outline's acceptance criteria and test list gain: a claim completes during Meltdown; an escape cancels Meltdown presentation; reduced motion removes flashing, shaking, and pulsing.

## Amendment 2 (2026-10-19): flash ceiling 2.5 per second, Heat colours without green

Decided by Adam in the Lane 3 HUD revision 3 review. It narrows two points above; the earlier text is kept as history.

- **Flash ceiling lowered to 2.5 per second.** All visible alarm peaks combined (panel, both sirens, bar emphasis, any flashing instruction, and later the car's emphasis) stay at or under 2.5 per second in Meltdown; Critical stays lower and less urgent. The three-per-second figure above is superseded. The HUD counts two visible peaks per alarm cycle and caps the clock at 1.25 cycles per second (Meltdown 1.2, so 2.4 per second; Critical 1.2 to 2.0 per second).
- **Heat colour stops:** Calm blue at 0%, pale cream at about 35%, Warning yellow at 60%, orange at about 75%, Danger red from 85%. No green anywhere in the Heat scale, explicitly at 40% and 50%. The bar and thermometer still share one mapping.
