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

## 6. Hop (R2-P1)
The concept is a CHARACTER leaping from roof to roof; the car does not jump and nothing here changes a pose, velocity, collision or camera
(Lane 1 owns them). The button icon is **HopFigure**: a figure over a dotted arc between two simplified roofs; the silhouette reads first at phone size.

**One coordinated target** (Run/HopCue drives all of it from the run state): the dashed teal footprint ring says where; a small roof reticle
(four corner brackets, anchored to the model bounds, a seat-height anchor for open vehicles) says the landing spot; a thin teal rim outlines the
target; one brief HOP word appears when a target locks on. The arc is a **narrow chevron stream** (9 pooled chevrons, never more than 12, depth-tested,
brighter toward the landing, flowing toward the target, a steady arc in reduced motion). It is a **target-direction cue, not a ballistic path**: no
trajectory is claimed until Lane 1 supplies one. Retarget swings the stream to the new target at once; nothing of the old one remains.

**State precedence** (explicit and tested): OutOfStamina > Cooldown > NoTarget > BestTiming > Ready. An unavailable or empty state never advertises best timing.

| State | Button | Target cues |
|---|---|---|
| Ready | teal, HopFigure, HOP | ring, chevrons, reticle, rim |
| BestTiming | steady gold ring, one brief pop | reticle tightens to 72% and turns gold, chevrons warm to gold, ring tightens |
| Cooldown | dark sweep, WAIT | grey ring only |
| NoTarget | grey, hatched | nothing |
| OutOfStamina | grey, red slash across the icon, empty-bolt badge | grey ring only |

**Best window**: filtered (enter after 80 ms, exit after 180 ms) so a value at the boundary cannot flash; the gold accent is one event per window (not within
0.6 s of the last one, never twice for the same window id). The soft lock-on whoosh is throttled to once per 0.6 s. Reduced motion: steady arc, reticle, ring and
button; no pop, flow or tightening animation. Cues clear on mode exit, target loss and a missing run.

## 7. Capture, SECURED and the tray (R2-K1, R2-V1, R2-V2, R2-T1)
**Escalation** (Keys ring, rider-relative as approved; this pass strengthens it): 0-50% HOLD ON (stable ring, restrained glow); 50-75% brighter
segments and glow, subtle progress clicks, the riser keeps rising; 75-100% a larger ALMOST! that appears once and settles, ONE capped pulse of the
glow and the transparent rarity edges at 1.0 cycle a second (with the Heat alarm at 1.25 a second the two stay under 2.5 peaks a second), sparse sparks
(at most 3 a second), a thicker rarity accent. Critical Heat and input warnings outrank all of it. The countdown shows ONLY when the source supplies
the remaining seconds with trusted timing (otherwise the percentage and ALMOST! say it). 100% is SECURING until the confirmation event: no fanfare,
no ownership, no count from progress. **The car shudder is deferred** (no vehicle, seat, character root or camera is moved; documented).

**SECURED**: confirmed identity only (dedupe, late and out-of-order confirmations, a run end during the reveal keeps the claim for Results). The tray count
changes ONCE, when the presentation starts; the flight to the count is only presentation. Wide screens: the full collectible card (TradingCard Reward:
SECURED stamp, name, rarity, family icon, NEW on a supplied flag, supplied Lap Pay) about 1.7 s, right of the protected road view only where it
clears everything; rays, one bloom and at most 24 confetti behind it (32 pooled pieces, cap 40), a Legendary adds one gold shockwave inside the same time.
Phones, and wherever no clear place exists: the compact SECURED stack (thumbnail, name, NEW, Lap Pay) in the column right of the road view under the route
line (where the riding chip sits, which steps aside), same sound and identity. The full card is for Results and the detail view. Reduced motion: a steady
card or stack, no zoom, rays, confetti, shockwave or flight. Haptics: one best-effort cue, OFF by default, never claimed felt (untested on hardware).

**Tray**: static ViewportFrame thumbnails (at most four alive, no spin), a thin rarity edge, NEW, the name (16 px, truncated; wrapped in the review),
three or four tiles then "+N"; a tapped car tile opens its card detail; independent of the Stamina meter.

## 8. Collectible cards (R2-T2)
One reusable card extending CarCard: **Compact** (grids: image, name, rarity, NEW), **Reward** (the reveal and Results: plus family icon, World scene
and badge, SECURED stamp, Lap Pay plate) and the landscape **Detail** view (Screens/CardDetail) with the fine print: Lap Pay, a per-second row only with a
defined lap duration (otherwise "unavailable (proposed)"), Heat capacity (the outline family table, seconds, scale 0-14 s), the quirk with one truthful line,
finishes (owned / not owned / unknown are three states), a flavour line and the footer (World, collection number, claimed date only when supplied).
Unowned: silhouette and "?" with no leaked finishes, number or date. Epic and Legendary get one slow masked foil sheen over the art only (text sits on
its own dark panels), static in reduced motion, at most four live. Placeholder art is a labelled proxy model; flavour lines and Lap Pay values are
preview fixtures. A fixed action bar (BACK, DRIVE) sits below the scrolling fine print, so nothing scrolls behind the buttons.
