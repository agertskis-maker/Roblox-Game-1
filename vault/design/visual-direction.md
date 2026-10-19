---
title: Visual direction
tags:
  - design
  - visual
status: draft
---

# Visual direction (draft, pending review)

> [!warning] Draft, pending Adam's review
> The HUD sample is built and waiting for Adam's review ("Approved: HUD"). Pip and the Downtown scene are not built. Approving a plan or a direction does not approve a finished look; each sample needs its own approval line at the bottom before the style spreads.

## Scope
Lane 3 (World, UI & Feel, owner Adam) visual sample for Car Hop ([[GDD]], [[car-hop-outline-v2]] sections 06, 07, 09, 13; [[0008-heat-critical-meltdown]]). Order: HUD (built, in review), then Pip, then the Downtown scene, each stopping for Adam's approval.
- Proposal sketches (not Studio captures): https://claude.ai/artifact/JYVRazaaENWAkiDXw5qBTS
- HUD review contact sheet (real Studio captures): https://claude.ai/artifact/GuedwiFiS5F8rSd3tUUqmG
Both pages are private to Adam until he shares them.

## Approvals recorded (Adam, 2026-10-19)
- **Pip direction approved**: name, silhouette and colours from the checkpoint sketch (described exactly below). The built model needs its own review.
- **Fredoka One** for game text; sizes 36 display / 24 value / 18 label / 16 minimum. Verified loading in Studio on 2026-10-19 (text measured; an unknown family failed).
- **Touch targets** 48 px minimum, 56 px for primary buttons.
- **Scaling rule**: viewport short side / 390, clamped 1.0 to 1.75.
- **Reduced motion**: follow Roblox's setting, `GuiService.ReducedMotionEnabled` (verified available), plus a preview-only override that is never saved.
- **HUD ownership**: Lane 3 owns the run HUD's presentation; Lanes 1 and 2 supply its state.
- No references were provided; the direction continues from the outline and the checkpoint.

## Direction
Labels: (outline), (approved) by Adam, (my proposal, pending review), (constraint).

- **Emotion:** playful, confident, energetic, easy to read (brief).
- **Shapes:** chunky blocks with chamfers, short overhangs, oversized wheels (outline). Detail goes into silhouette, wheel stance, lamps, hazards (my proposal).
- **Materials:** SmoothPlastic; Metal only on wheel hubs; Glass for tinted windows; no textures, no Neon on cars (outline + my proposal).
- **UI palette** (my proposal, pending review; values live in `src/shared/UI/Tokens.luau`): card `#FFF4DC`, inset `#F6E6BF`, navy text and strokes `#1E2A4A`, secondary text `#4A5578`, primary orange `#FF8A1F` (pressed `#D96A00`), success `#3DBE6C`, danger `#E5484D` (danger only), coin `#FFC83D`.
- **Heat colours** (my proposal): Calm `#3FB6D8`, Warning `#FFB81C`, Critical and Meltdown `#E5484D`; smoke `#969AA8`; stripe light `#FFF8EC`.
- **Downtown** (my proposal, not built): asphalt `#625D59`, lane dashes `#FFD23F`, edge lines `#FFF1D0`, buildings coral `#F2A08E` / mint `#9FDCC3` / cream `#F8E9C8` (lower saturation than gameplay objects), teal Atmosphere tint; barrier orange `#FF8A1F` with `#FFF8EC` stripes on navy; pothole rim `#B7ADA3`, hole `#2A2523`. Scenery never uses hazard orange.
- **Type:** Fredoka One only (approved); hierarchy by size and colour.
- **Surfaces** (my proposal): radius 8 / 14 / 20 / pill; stroke 2 / 3 / 4; spacing 4, 8, 12, 16, 24, 32; shadow navy at 80% transparency, offset 0, 4, no blur.
- **Icons:** built from frames (coin, thermometer, puffs, clock); no uploaded images.
- **Motion** (my proposal): press 0.1 s, panel 0.2 s, gauge fill 0.15 s, Heat reset 0.25 s, Warning pulse 1.1 per second, Critical 1.0 rising to 2.5, Meltdown 2.5; ceiling under 3 (decision 0008).
- **Spectacle:** the player car and hazards. Scenery and HUD stay calm.

## The run HUD (built, pending review)
- Cash top left, Distance top centre, Heat bottom centre, inside Roblox's safe area (`ScreenInsets = CoreUISafeInsets`).
- Fixed widget sizes so an extra digit never resizes the HUD; Distance digits right-aligned with the unit in its own slot.
- On narrow screens Distance slides right just enough to clear Cash. In portrait the gauge sits one touch row (56 + 24 px, scaled) higher so both bottom corners stay free for touch controls.
- Scaling: one `UIScale` per widget root; only the gap to the screen edge is multiplied in code. The gauge's inner `StageScale` (1.0 / 1.08 / 1.16 / 1.16) is design emphasis, not device scaling.
- Heat stages show five cues besides colour: fill, size, word, puffs (0 / 1 white / 2 white / 3 grey smoke), stripes in Critical and Meltdown. Tick marks at the outline's proposed 60% and 85%.
- Meltdown: track turns navy, cream-on-red stripes drain from full to empty, clock plus "ESCAPE TIME", thermometer full, red label "Losing control!". The gauge only displays `meltdownRemaining01`; it runs no timer that decides anything.
- HUD art does not capture input (verified: clicks on it reach the game).
- Number display: `Format.cash` ($12,480; from $1,000,000 three truncated significant digits: $1.99M, $1.99B) and `Format.distance` (1,240 m; from 10,000 m: 12.4 km). Display only.
- Desktop at 1.75 gives value text of about 42 px; Cash covers about 15% of the width. Recommendation: keep 1.75 for now; if Adam finds desktop too large, lower the maximum to 1.5 (about 36 px text, still at least 48 px targets).

## Provisional interfaces (need Lane 1 and Lane 2 agreement, decision 0007)
- **HUD state** (`src/client/UI/RunHud/init.luau`): `{ cash: number, distance: number, heat: number (0..1), stage: "Calm" | "Warning" | "Critical" | "Meltdown"?, meltdownRemaining01: number? (1 -> 0, Meltdown only) }`. Lane 2 supplies `cash` (server-owned, read-only on the client). Lane 1 supplies the rest. If `stage` is missing the gauge derives Calm, Warning or Critical from its provisional thresholds and never infers Meltdown.
- **Stage values** are PascalCase strings; player labels are Cool, Hot, Too hot!, Losing control!.
- **Preview** (`src/client/UI/Preview/RunHudPreview.luau`) is internal and not a contract.

## Pip, approved sketch (for the Pip session)
Approved by Adam on 2026-10-19 as a direction; the built model still needs review.
- **Silhouette:** two-box hatchback. Length 9.6 studs, body width 5.4, width across tires 6.0, total height about 4.4, wheelbase 5.6. Wheels 2.4 studs across (about 1.3 times realistic), 0.9 wide, poking past the body. Chamfered lower body; cabin set back with a sloped windscreen and a near-vertical rear hatch; cream roof cap; two round headlights and a short dark grille slot in front (friendly, no eyes or mouth); taillights and a cream plate at the rear; navy bumpers; dark arches behind the wheels; light hubs with a dark cross so spin is visible.
- **Colours:** body `#3E9BFF` SmoothPlastic; roof `#FFF1D0`; trim `#1E2A4A`; glass `#1B2A45` (Glass, slight transparency); headlights `#FFF4C2`; taillights `#FF7A66`; tire `#20232E`; hub `#E8EEF8` Metal. No light objects.
- **Budget:** about 32 parts, no unions, no meshes, no scripts from outside.
- **Rig (provisional, for Brian R's review):** `Root` invisible part at ground under the car centre, model PrimaryPart, facing -Z, +Y up; every part Anchored (kinematic, moved with PivotTo; no Seat, no Humanoid, no welds needed). `Wheel_FL`, `Wheel_FR`, `Wheel_RL`, `Wheel_RR` models with pivots at axle centres, spin about local X. Attachments: `SeatAnchor` (rider position, faces forward; placement only), `HeadlightL`, `HeadlightR`, `HeatSteam` (hood), `HopRing` (ground centre), `KeysMeter` (above roof), `TrailL`, `TrailR` (rear corners). Every visible part carries a `ColorRole` attribute (Body, Roof, Trim, Glass, LampFront, LampRear, Tire, Hub); finishes are role-to-colour maps. Model attribute `RigVersion = "0-provisional"`.

## Next session: Pip (do not start before "Approved: HUD")
- Git-tracked construction recipe that builds Pip at runtime through the agreed preview launcher (a module under `src/client/Home/`, Studio-only guard, rerunnable, one named container).
- Keep the approved silhouette, colours, rig and attachment names.
- Localized Critical and Meltdown red emphasis on the car that never overwrites `ColorRole` or the original colours; restore the exact original appearance when the effect clears.
- One small hood-smoke emitter at `HeatSteam`, visible against bright Downtown without hiding the car or the target area.
- Propose a minimal presentation-only effect interface for Brian R (for example `setHeatStage(car, stage)`), marked provisional.
- Show chase-camera and side views at phone and desktop sizes; report real part and emitter counts; review Normal, Critical, Meltdown and recovery.
- Stop for "Approved: Pip".

## Following session: Downtown scene (after "Approved: Pip")
- Git-tracked recipe for the road slice, the pothole and the construction barrier; combine with the approved HUD and Pip.
- A clearly labelled preview-only Meltdown wobble, separate from real steering and crash logic; reduced motion disables the wobble and flashing but keeps the danger cues.
- Check hazard readability from a representative chase camera; restore transforms, lighting and camera on cleanup.
- Stop for "Approved: Downtown scene".

## Representative sample

| Sample | Built? | Screenshot | Review notes |
|---|---|---|---|
| Run HUD: Calm, Warning, Critical, Meltdown, reset after Hop, short and long values, grey, reduced motion | yes, 2026-10-19 | contact sheet above | pending Adam |
| HUD at phone landscape 801 x 413, phone portrait 413 x 814, desktop 1919 x 1079 | yes | contact sheet above | pending Adam |
| Pip on the shared rig | no | not captured | |
| Downtown road slice with pothole and barrier | no | not captured | |

Sample approved by: _pending_ (HUD), _pending_ (Pip), _pending_ (Downtown scene).

## Choices I made (reversible)
- Cream roof and navy trim on Pip repeat the UI's cream and navy so car and HUD read as one game.
- Hazard orange is not used in scenery.
- Distance moves right instead of shrinking on narrow screens; the gauge rises one touch row in portrait.
- Stills in the contact sheet are taken with reduced motion so a frame shows the stage, not a pulse phase.
