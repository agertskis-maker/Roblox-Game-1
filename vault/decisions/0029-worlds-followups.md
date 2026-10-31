---
title: "0029: Worlds follow-ups - S8 snowmen row moved, canyon read limited by the envelope"
date: 2026-10-29
tags:
  - decision
  - worlds
  - lookdev
status: accepted for the preview; open questions for Adam below
---

# 0029: Worlds follow-ups

Brief: Adam, 2026-10-29, Part B. Ledger rows F1 to F4 in [[worlds-dusty-summit-ledger]]. Builds on [[0026-world-plans-approved]].

## Decisions
1. **S8, Adam's decision (2026-10-29), confirmed in the question batch:** the snowmen row moves to the next district, which
   after Summit Lodge is Pine Village across the route's loop. The cycle reads observatory, lodge, snowmen row, chalet
   cluster. Implemented as: ordered districts are placed before the sweep as anchors (gaps 300 to 440 from the World data),
   Pine Village opens with forward `leadLandmarks` (snowmen row, then chalet cluster) measured from the lodge across the
   wrap, and the sweep resumes after any anchor it reaches. Downtown and Dusty take the same code path with no anchors and
   plan identically (5 seeds checked).
2. **The authoritative spacing test is the World's own length (one loop, wrap included).** The 3600-stud preview length used
   for review videos has a partial second lap cut by the route end; its failures there are reported, not hidden.
3. **The tests stay strict.** `landmark-spacing` and `landmark-majors` fail on pairs that predate S8 (listed in the ledger).
   They were not weakened. *Alternative:* scope them to the S8 districts only (rejected: it would hide real breaks).
4. **Canyon composition (lead's choice inside Design 8):** a cream lip, a brown-mauve shade skirt and an opaque teal river,
   13 non-colliding parts. The first tune (r_shadow 112, 50, 42) read as red paint on the rail and was replaced. A camera
   preset `RUN_DRAFT` reproduces Brian R's draft run-camera numbers for comparable stills; it is not his code.

## Measured limit (why the canyon still reads weakly)
The deck (101.7 wide) covers 82% of the approved 124-stud gorge. From the run camera (about 13.5 up, any lane) a ray over the
balustrade reaches only 1 to 2 studs below the rim, so no ledge, wall or floor can be seen from the deck. Composition inside
this envelope can only mark the edge.

## Open for Adam
- Summit rules: with the glacier tunnel fixed at s2226, "every gap 300 to 440" plus "majors 500 apart" needs about ten
  landmarks per 3,081-stud loop with about 80 studs of slack. Options: allow a longer gap next to the glacier tunnel; drop
  the majors minimum where a minor cannot fit; or accept the listed pairs.
- Canyon: a deep read from the deck needs one of: a wider gorge (beyond 124), a gorge that crosses the road (the classic
  canyon view on the approach), lower or open balustrades (a safety-edge change, Brian R's), or a higher run camera (Brian
  R's). Each changes an approved size or another lane's contract.
- The bell tower no longer fits in Pine Village on lap 1.

## Review (one fresh Sonnet reviewer, 2026-10-29)
No crash, loop or nil-index bug; no new path changes Downtown or Dusty. Fixed (check and preview fixes, plans unchanged):
the spacing, majors and cycle checks can no longer pass with no landmarks; the minor-near-major test now looks across the
loop; `City.lane` redraws at once; one type annotation; the river no longer overhangs the floor ends. **Known, not fixed**
(each would change Summit plans and needs its own pass and re-check): (1) when the sweep "passes" an anchor it can leave a
gap over 440 before that anchor (worst case about 740; in Summit the glacier tunnel usually sits in that gap); (2) an
ordered district whose anchors all fail to fit still draws a random jump instead of the old 96-stud step.
