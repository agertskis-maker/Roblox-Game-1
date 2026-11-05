---
title: "0022: proposal: Circuit run profile and stampede-style run features (Lane 1)"
date: 2026-10-26
tags:
  - decision
  - lane1
  - run
status: proposed
owner: Brian R (Lane 1)
needs: "Agreed" from Adam (owner of the Decided rules below) and Brian L (progression and the run report)
---

# 0022: proposal: Circuit run profile and stampede-style run features

**Status: Proposed.** Built on `feature/lane1-run-prototype` and playable in Brian R's private test place only. The game's default run (`Highway` profile) still follows the outline. Nothing here changes saved data, Cash or remotes.

## Why

Brian R playtested the Stage 1 run and wants it to feel closer to the popular rodeo-style stampede games (riding, a herd of mixed sizes, a catch meter, gates on stronger animals), and to be a tense high-speed weave on a racing circuit. Copying how a game *plays* is fine; no names, art, UI or paid-luck features were copied (paid chest rolls are excluded by our kids rules).

## 1. Circuit run profile (changes Decided rules, so opt-in until agreed)

A second run profile next to the outline's `Highway`, chosen per run and part of what the server needs with the seed (`RunConfig.PROFILES`):

| | Highway (outline) | Circuit (proposed) |
|---|---|---|
| Run speed | outline curve | 1.7x |
| Traffic speed | 0.56 to 0.80 of run speed by lane | 0.40 to 0.64 (cars rush at you; you must cut lanes) |
| Traffic spacing | 1x | 1.35x (a little less traffic) |
| Touching a car | adds Heat (outline, **Decided**) | **ends the run** |
| Keys time | 3 / 4 / 5 / 6 s (outline, **Decided**) | **5 / 6 / 7 / 8 s** ("keep a car only if you stay 5+ seconds") |
| Heat Capacity | 1x | 1.6x, so every claim still has Heat to spare |
| Steering | 1x | 1.6x |
| Scenery (test only) | canyon highway | racing circuit: kerbs, run-off, gravel, tyre walls, grandstands, start gantries |

Decision needed from Adam: keep Circuit as a mode, make it the default, or drop it.

## 2. Stampede-style features (in both profiles)

- **Rider inside the car** (outline already says closed cars hide the rider), with a **V / gamepad Y in-car view**.
- **Sizes**: Tiny, Normal, Big, Giant rolled from the seed (scale 0.72 / 1 / 1.3 / 1.6).
- **Odds tags** over each car: "1 in N" for that model at that size, worked out from the same weights the seed uses.
- **Rider Level gate** (needs Lane 2): each car shows "Needs N"; below it you can ride but the Keys will not fill and Heat rises 1.6x faster. In the prototype the level starts at 10 and each new model claimed adds 6, kept only for the playtest session. Where the level really comes from (and whether it is saved) is Brian L's call and a propose-first economy question.
- **Caught tray** and a "You caught N cars!" end card.
- **3 free revives** per session (no Robux): land back on the nearest car with fresh Heat. Adds a `Revive` event to [[0021-run-report-proposal]].
- **Rare-car alerts** when a Legendary or Giant appears ahead.
- **Variants** (Decided in the outline) appear only on owned models; the seed rolls a number and ownership decides the Variant, so the server can repeat it.

## How to test

Open the private Lane 1 test place built from `lane1-run.project.json` (kept outside the repo, like Lane 3's playgrounds). The command bar control is documented at the top of `src/client/Run/RunPlayground.client.luau`; `c:Invoke("profile", "Highway")` switches back to the outline's run for comparison.

## Not decided by this note

Nothing above is approved. Lane 3 owns the final HUD, labels, effects and sounds (the run's read-outs here are labelled placeholders). Brian L owns progression, ownership and the catalog numbers the run will read. Adam's Round 2 HUD work includes a Stamina demo (decision 0020 on his branch); the Rider Level gate should be reconciled with it before either is built for real.
