---
title: Round 2 HUD — layout, regions and states (UI spec)
tags: [design, ui, spec, lane3]
status: draft; updated per work package
date: 2026-10-23
---
# Round 2 HUD spec (Lane 3, preview)

Ledger [[hud-round2]]. Builds on [[hud-arcade-rebuild]]. Landscape only; Studio mocks without a Figma step (Adam's
task-scoped exception). Design px inside the virtual device frame; the frame is not the game's final scale.

## 1. Layout matrix (landscape only)
| Frame | Size | Insets (assumed, documented) | Notes |
|---|---|---|---|
| Desktop | 1920 × 1080 | top 58 | no touch zones |
| Tablet | 1180 × 820 | top 58, bottom 20 | touch zones: thumbstick lower-left 40% × 45%, Jump |
| PhoneLandscape | 844 × 390 | top 44, bottom 21, left/right 47 | both notch sides symmetric |
| PhoneSmall | ≈ 740 × 360 | as above | smallest practical viewport |
| PhoneLandscapeLeft / Right | 844 × 390 | notch on one side (asymmetric left/right insets) | assumptions, not measurements |
PhonePortrait is **removed** (S1). The window may be resized; nothing assumes one fixed size.

## 2. Placement (resolved together)
| Region | Home | Run |
|---|---|---|
| Top-left under core UI | — | compact **Cash** (no coin counter, no owned count) |
| Top-centre | tutorial / banner | **route line** (five stations, marker, callout, BEST badge) |
| Top-right | red labelled Settings | Settings + RIDING chip |
| Left menu | Shop / Garage (with `n / total CARS` pill) / Missions / Music | hidden |
| Left-middle above the movement zone | — | **Stamina** (when the demo is on) |
| Left, separate compact region | — | claimed tray |
| Bottom-left | big green **Cash** + earning line | — |
| Bottom-centre | — | **ENGINE HEAT** (the original panel) |
| Bottom-right | — | **Hop** (clear of Jump) |
| Beside the rider | — | **Keys** |
Safe regions to keep clear: the protected road-ahead rectangle, the touch zones, the ridden car, the next target, the
upcoming landing zone and near hazards. The capture ribbon never overlaps Cash. When space runs short, secondary
information compacts (an intentional collapsed tray) instead of shrinking core numbers.

## 3. Surfaces
One arcade family: strong readable outline, coloured surface, purposeful depth; one heavy outline per nesting chain.
Hit targets ≥ 48 design px (56 for primaries); text ≥ 16 design px (Heat's title tab on phones is the one documented exception).

## 4. States and precedence (filled in as built)
- Hop button: **OutOfStamina > Cooldown > NoTarget > BestTiming > Ready** (an unavailable state never advertises best timing).
- Run-time ordering: warning > pending capture > confirmed capture > run end > Results.
- Reduced motion (`GuiService.ReducedMotionEnabled` + the preview-only override): steady states, short fades, no shake, bounce, flight or spin.

## 5. Route line (top centre, R2-R1 / R2-R2)
Replaces the district strip. Subway-style: a callout row (LAP n tag when the route has looped, "distance • next district in X m",
a record label only when a record exists), five station tiles (original Icons2 art; the current one is larger with a white
ring; visited wear a ring in the World colour; upcoming are dimmed), a track row (nodes under each tile, a grey line with the World
colour travelled, the round avatar marker with a pointer, a small checkered marker where the record lies) and the names. The
checkered BEST badge sits at the line’s right end; it is a record badge, not a station. Full size 600 x 161 design px; phones 430 x 109
(short labels from `District.short`, same callout). Names are 16 design px on both.

- **Honest space.** The line is schematic like a subway map (each district owns one equal visual stretch) while the marker moves from the
  plan’s EXPLICIT unequal lengths. The unit is the plan’s metres (a fixture scale: 1 stud = 0.28 m in the Downtown chase; Lane 1 owns the real
  conversion; nothing converts studs). The shown marker is smoothed and clamped to the current district’s stretch, so it never contradicts a banner.
- **Record.** Distance record, not a finish. Inside the shown cycle: a second checkered marker at the mathematically correct place and the label
  "BEST n m". Beyond it: "BEST n m ahead"; behind: "BEST n m behind" (phones "+n m" / "-n m"). No prior best: dimmed badge, no label, no NEW BEST.
  NEW BEST fires once per run on the update that crosses the verified pre-run record, never saved from here, never replayed (oscillation, reorder, later cycles).
- **Cycle.** A repeating plan starts a new cycle after the last district: total distance keeps counting, local progress resets with a short sweep back along
  the line (none in reduced motion) and a "LAP n" tag. This is a **district-route cycle, not a Speedway income lap.** The tag word is a proposal.
- **Arrival.** One short emphasis per (cycle, district) however often a boundary is crossed; the banner is deduped by district + cycle (DistrictBanner).
- **Held:** the production World loop, verified-record flag, run id, plan colour and phone labels are fixtures until the team agrees the contract (ledger table).
