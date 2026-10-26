---
title: Round 3 HUD, cards, audio, B2 import and World plans — choices
tags: [decision, lane3, ui, audio, assets]
status: accepted for this task (preview; not a production approval). Several items await Adam's confirmation, listed below.
date: 2026-10-26
---
# 0021 Round 3 (preview)

Ledger [[hud-round3]]; spec `vault/design/ui/hud-round3.md`; follows [[0020-hud-round2-presentation]].

## Decisions made by the lead (all reversible)
1. **Figma skipped, again.** Figma is signed in (handle `agertskis`) but on a **View** seat of a Starter plan and no "Car Hop UI" file link is recorded in the repo, so no mock could be written. The changed pieces are specified in the repo and drawn in Studio; they are *awaiting final visual acceptance*, not approved mocks. [[0012-figma-ui-workflow]] is unchanged. Basis: Adam's Round 3 brief (section 4) allows Studio mocks and specs when Figma cannot be used and says not to start a sign-in loop; the independent reviewer noted that this is a waiver of a Figma-first rule, so it is recorded here. If Adam wants these redone in Figma first, say so.
2. **One pill, two lines.** "821 m | Cactus Flats / Next in 73 m" instead of one line (one line needs about 440 px). "You are here" when nothing lies ahead, so a current area is never shown as the next one.
3. **Keys ring** fills clockwise from 12 o'clock, drawn from frames and strokes (no upload), eases to the supplied progress in 0.07 s and never changes capture time.
4. **Landing label replaces the permanent Riding chip** and yields to the capture nameplate: the nameplate wins.
5. **Heat floor 13 px (provisional).** The project's 16 px minimum text rule would keep every phone frame at scale 1.0 (measured 39 to 49% of the protected road rectangle, title tab included). Round 3 uses a floor of 13 real px: scale 0.8125 on phones and 0.667 on Desktop and Tablet. It is one constant (`RunLayout.HeatTextFloor`); setting it to 16 restores the stricter rule. **Needs Adam's confirmation** (AGENTS.md: sizes other than the approved ones are propose-first).
6. **Run-scoped capture identity** lives in the preview Store (`run.runId`, or a synthetic per-run key). Stale events are shown as nothing but are still recorded, flagged, so a permanent reward is never lost on the other lane's side.
7. **Haptics** default ON, gated by one function; unsupported hardware shows "Not available on this device".
8. **Audio:** `KeysTick` retired (it stacked on the chime); the old looped riser with a pitch ramp is replaced by at most four discrete chime notes per capture; the fanfare plays once per confirmed capture; the Warning, KeysCapture, NewBest and Milestone cues are priority cues that the voice cap never silences; the music bed is 8 dB under Cash; fades are finite tweens, never a polling loop.
9. **Garage:** no default sort (collection order); the grid cards keep their family and quirk lines, only the detail dropped them; synthetic acquisition numbers in the harness make NEWEST visible; Lap Pay and acquisition number of an unowned car count as unknown for sorting.
10. **B2 import:** OBJ package under Adam's user account (Creator "Me"), the five palette images uploaded through the approved `upload_image` path from a temporary local-only web server (stopped afterwards). The group Adam is creating did not exist in the importer's Creator list; assets cannot move from a user to a group, so a group-owned kit means a re-import (see `vault/design/assets.md`).
11. **Workers:** 13 Sonnet workers on disjoint files (Adam's chat message allowed "as many as needed"; the brief said two); the lead alone ran Studio, Git, shared files and integration; no Opus agent was used.
12. **Test driver:** harness commands added for review (`setMode`, `setKeysState`, `setStaminaValue`, `setRide`, `setHeatFloor`, `useUploadedKit`, `scenarioList`, `scenarioBusy`).

## Found only by looking at real Studio frames or running the scenarios (fixed)
- The Keys ring restarted its ease on every store update, so it trailed the supplied value; it now keeps its own timeline.
- A screen resize while a capture was ending left the ring on screen for good, with a live connection (`layout()` re-showed an ended capture and cancelled its own hide).
- The World name in the Garage detail was clipped by 4 px.
- Toast and Results text fit; Results plate contrast raised to the approved kit's own floor; a voice cap overrun; ducking lost under a full voice cap; the warning sound silenced by the overlap cap.

## Not decided here
HOP STREAK (backlog, proposal only). Reducing claim times (draft for Brian R and Brian L, nothing sent). The Dusty Highway and Summit Pass redesigns (plans only, waiting for Adam).
