---
title: Round 2 — original Heat: inventory, why the playground used another bar, reconnection, Stamina conflict
tags: [design, spec, heat, lane3]
status: baseline captured; integration pending (WP5)
date: 2026-10-23
---
# Original Heat (R2-H1…H5, R2-S2)

Ledger [[hud-round2]]. Written **before any Heat change**. Evidence: `Car-Hop-Art/review/hud-round2/heat/`
(`baseline-original.json`, `baseline-original-sheet.jpg`, `baseline-segmented-sheet.jpg`) and
`video/heat-baseline-original-normal.mp4`, `video/heat-baseline-segmented-round1.mp4`.

## Plain answer
The approved ENGINE HEAT panel was never mounted in the HUD playground. The round-1 build followed Adam's
2026-10-22 brief, which described a different bar (§8: "strong dark frame, segmented fill, readable flame icon,
stage labels/marks, yellow/orange/red ramp"), and replaced the Heat look **inside the prototype only**. Nothing was
broken, and the round-1 handoff did not say that the approved panel had been bypassed. Round 2 restores it.

## 1. Inventory
| Path @ revision | Kind | Inputs / outputs | Status |
|---|---|---|---|
| `src/client/UI/RunHud/HeatGauge.luau` (e65374f 2026-10-19 → e2678f9 → d5628ef → 5a8fa76 "revision 4"; on `main` via PR #1) | **Visual only.** ENGINE HEAT panel: thermometer, temperature-scale bar, mirrored sirens, smoke, HOP NOW!; 320 × 92 design px | in: `set(heat01, stage)`, `snap(heat01, stage)`, `jolt(strength?)`, `setReducedMotion(bool)`, `setLayout(maxStageScale, smokeScale)`; out: `Cue` Signal (`"Stage"`, `"AlarmPeak"`) | Approved by Adam at rev 4 (2026-10-20). Used by `RunHud` and `Preview/RunHudPreview`. **Not mounted in the playground.** |
| `src/client/UI/RunHud/init.luau` | host: Cash, Distance, Heat; scale and safe-area rules; `setState{cash,distance,heat,stage}` | | active (production path) |
| `src/client/UI/AlarmClock.luau`, `src/shared/UI/Tokens.luau` (`heatColor`, `heatColorSequence`, `Motion.*`) | shared alarm clock (≤1.25 cycles/s), colour stops, smoothing | | active |
| `vault/decisions/0008-heat-critical-meltdown.md` (+2 amendments), `vault/design/car-hop-outline-v2.md` §Heat | rules of record | | Decided / Proposed as marked |
| `Prototype/Run/HeatBarProposal.luau` (cbe92d7 overnight; deleted in bc229f8) | overnight top-left segmented PROPOSAL variant | | not the original |
| `Prototype/Run/HeatBar.luau` (bc229f8; edited ae8c21c, c2bdef0) | round-1 segmented bottom-centre bar; imports `HeatGauge` only for `Thresholds` | | mounted until WP5 |
| **Gameplay Heat logic** | **none exists.** `git grep` over every remote branch found no Heat code in `src/server`, `src/shared` (except UI Tokens) or non-UI `src/client` | | Lane 1 (Brian R) owns it; not built |

Every commit carries the single account `agertskis-maker`; Git cannot tell which person designed what, so no
authorship claim is made.

## 2. Why the playground used another bar — proven vs ruled out
**Proven (from files):**
1. The 2026-10-22 brief §8 specified the segmented bar; `HeatBar.luau`'s header says it "replaces the overnight run
   Heat look inside the prototype only; `src/client/UI/RunHud` (the approved production HUD) is not touched".
2. The overnight task (decision 0018; ledger C1) already kept ENGINE HEAT as the default and built a segmented
   top-left bar as a labelled PROPOSAL.
3. `HudPlayground.client.luau` mounts only `Prototype/*` components; `api.setRunHudVisible` toggles only those.
   `RunHud` and `RunHudPreview` are never started in the playground.

**Ruled out:** a broken import (`HeatBar` requires `HeatGauge` successfully and `check.ps1` builds), a missing source
or unavailable branch (`HeatGauge` is on `main` and on this branch). Intentional preview decoupling and a separate
fixture component are **true**, both by instruction.

## 3. Smallest reconnection
A new `Prototype/Run/HeatPanel.luau` adapter that instantiates `HeatGauge` **unmodified** and binds the store to it:
`snap` on the first state or mode entry, `set` afterwards, `jolt` on a bump event, `setReducedMotion` from `Motion`,
`setLayout` from `RunLayout.heatRect`. `HeatGauge`, `RunHud`, `AlarmClock` and `Tokens` stay byte-identical. The
segmented `HeatBar` stays in the repo, unmounted, behind a debug-only variant switch (default Original). No server
code is required, no sessions or DataStores are touched.

**Fit (measured in Studio).** The panel is 320 × 92 (+10 px effect margin). Scale steps 1.0 → 0.92 → 0.89 (label ≥ 16.0 design px). Desktop fits at 1.0; phone landscape 844 × 390 fits clear of the thumbstick zone and Hop at 0.92 (label 16.6 px, no stage growth). Tablet (design scale 1.5) and PhoneSmall 740 × 360 are as tight as a phone: they use 0.89 with the panel against Hop and up to 60 px into the assumed (conservative) thumbstick zone, reported as `ThumbstickSoft`. The title tab text is about 14.2–14.7 px (not primary text).

## 4. Baseline of the original (Studio Play, synthetic fixture)
`HEAT_SEQ`: snap(0) → t1 set(0.30, Calm) → t3 set(0.60, Warning) → t5 set(0.85, Critical) → t7 set(1.00, Meltdown)
→ t11 set(0, Calm) (the Hop reset). Numbers every 0.25 s are summarised in `baseline-original.json`:

| Stage | Label | shownHeat | alarm | rattle | melt | stageScale | alarm Hz |
|---|---|---|---|---|---|---|---|
| Calm 0.30 | Cool | 0.300 | 0 | 0 | 0 | 1.000 | 0 |
| Warning 0.60 | Hot | 0.600 | 0 | 0 | 0 | 1.049 | 0 |
| Critical 0.85 | Too hot! | 0.850 | 0.600 | 0.400 | 0 | 1.100 | 0.6 |
| Meltdown 1.00 | Losing control! | 1.000 | 1.000 | 1.000 | 1.000 | 1.120 | 1.2 |

At the Hop reset every alarm and Meltdown effect clears on the first sample; the level eases back to zero in about
0.8 s. Meltdown peaks 1.2 cycles/s × 2 = 2.4 flashes/s, under the 2.5/s ceiling (0008 amendment 2). The same
sequence on the round-1 segmented bar lights 3 / 6 / 8 / 10 of 10 segments. These inputs were chosen here; the
thresholds (`HeatGauge.Thresholds`, 0.6 / 0.85) are a provisional copy of Lane 1's. **This is a fixture using the
original configuration, not a live integrated run.**

## 5. Rules of record and the Stamina conflict (analysis only; no balance chosen)
**Rules** (outline §Heat, decision 0008): each family has a Heat Capacity **in seconds** (the outline's family table,
`car-hop-outline-v2.md`, gives 8 to 14 s per family, Tunable; the card fixtures use those values; there is no Heat code); Heat fills 0 → 100% while ridden; **it resets to zero on every Hop**; bumps add 15% (side scrape) / 30%
(rear-end); Calm < 60%, Warning 60–85%, Critical 85–<100%, Meltdown at 100% (thresholds Proposed / Tunable); the
3-second escape window is Proposed (Lane 1); Hop stays available in Meltdown; a Keys meter that completes in Meltdown
still claims; if the player has not escaped when the window ends the car crashes and the run ends. A tap with no
target is a short hop in place that lands on the same car.

**The proposal under test** (Adam's brief): 10 Stamina per run, one spent per **successful** hop, no hop at zero while
the current ride continues.

**Interaction.** Hopping is also the only cooling. At zero Stamina the current car's Heat can no longer be reset, so
"the ride continues" lasts only until that car reaches 100% and its Meltdown window runs out. Zero Stamina is therefore
not an open-ended state, it is a countdown the player cannot answer by hopping.

**Risks (no choice made):**
- a forced ending the player cannot counter (the run ends after the remaining Capacity plus the Meltdown window);
- stalled pacing followed by an abrupt end, instead of a clear lose condition;
- reduced access to rare cars: claims last longer for rarer cars and may overlap the final Meltdown;
- misleading readouts or double punishment: OUT OF STAMINA shown while Heat keeps climbing;
- the original panel's **HOP NOW!** at Meltdown contradicts a blocked Hop. The adapter hides the panel's `HopNow`
  child while Stamina is zero (presentation only, labelled; `HeatGauge` is untouched).
- Does a no-target tap spend? Not treated as a successful hop here (no spend); Lane 1 should state this.

**Options (not chosen):** restoring pickups reachable by steering alone; reserving the last unit for a Meltdown escape;
changing Heat behaviour at zero (a Lane 1 rule, not ours); a clearer "why the run ended" line; upgrades or purchases
(unresolved; nothing is sold or proposed here).

**Small future test for Lane 1:** over about 20 playtests, count the runs in which Stamina reaches zero before the run
would otherwise have ended, and what happened next.

## 6. Open points
- If Adam meant only the bar and not the thermometer, the wrapper can hide the thermometer; the full panel is the default.
- A palette-level restyle toward the arcade family is possible through the `palette` argument without editing
  `HeatGauge`; the default keeps the approved cream panel until Adam asks.

## 7. Integration result (Stage 2, WP5; Studio Play)
`Prototype/Run/HeatPanel.luau` mounts the unmodified `HeatGauge`. Replaying `HEAT_SEQ` through it reproduces the baseline:
identical stages, labels, steady values and alarm rates. Eased values differ at the first sample after an input (largest
gap 0.12 of full scale on the Critical alarm build at +0.27 s, at most 0.03 on the other quantities), at most 0.02 from
+0.53 s and at most 0.005 at +0.8 s; sampling jitter is about 0.13 s
(`Car-Hop-Art/review/hud-round2/heat/integration-equivalence.md`, `before-after-sheet.jpg`). Independent review caught an
earlier "within 0.03" wording that the table did not support. `HeatGauge`, `RunHud`,
`AlarmClock` and `Tokens` are byte-identical to `main` (git diff is empty for them). Label is: fixture using the original
thresholds, not a live Lane 1 run.
