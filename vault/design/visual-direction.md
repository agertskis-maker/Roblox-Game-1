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
- HUD review contact sheet, first version (real Studio captures): https://claude.ai/artifact/GuedwiFiS5F8rSd3tUUqmG
- HUD review, revision 2 (ENGINE HEAT panel; real Studio captures): https://claude.ai/artifact/KBtMAZdsTca42dgsaDycqK
Both pages are private to Adam until he shares them.

## Approvals recorded (Adam, 2026-10-19)
- **Pip direction approved**: name, silhouette and colours from the checkpoint sketch (described exactly below). The built model needs its own review.
- **Fredoka One** for game text; sizes 36 display / 24 value / 18 label / 16 minimum. Verified loading in Studio on 2026-10-19 (text measured; an unknown family failed).
- **Touch targets** 48 px minimum, 56 px for primary buttons.
- **Scaling rule**: viewport short side / 390, clamped 1.0 to 1.75; cap lowered to **1.5** on 2026-10-19 (HUD revision).
- **HUD revision approvals (2026-10-19, Adam):** stronger Critical stripes; smaller stage growth in portrait with the panel and its effects at least 24 px inside the safe area; no visible Meltdown timer and the ENGINE HEAT panel design (decision 0008 amendment). The Warning glow against the road is deferred to the Downtown scene review.
- **Reduced motion**: follow Roblox's setting, `GuiService.ReducedMotionEnabled` (verified available), plus a preview-only override that is never saved.
- **HUD ownership**: Lane 3 owns the run HUD's presentation; Lanes 1 and 2 supply its state.
- No references were provided; the direction continues from the outline and the checkpoint.

## Direction
Labels: (outline), (approved) by Adam, (my proposal, pending review), (constraint).

- **Emotion:** playful, confident, energetic, easy to read (brief).
- **Shapes:** chunky blocks with chamfers, short overhangs, oversized wheels (outline). Detail goes into silhouette, wheel stance, lamps, hazards (my proposal).
- **Materials:** SmoothPlastic; Metal only on wheel hubs; Glass for tinted windows; no textures, no Neon on cars (outline + my proposal).
- **UI palette** (my proposal, pending review; values live in `src/shared/UI/Tokens.luau`): card `#FFF4DC`, inset `#F6E6BF`, navy text and strokes `#1E2A4A`, secondary text `#4A5578`, primary orange `#FF8A1F` (pressed `#D96A00`), success `#3DBE6C`, danger `#E5484D` (danger only), coin `#FFC83D`.
- **Heat temperature scale** (stops approved, values my proposal): Calm `#3FB6D8` at 0% and held to 30%, Warning `#FFB81C` at 60%, HeatOrange `#FF8F2A` at 72.5%, Danger `#E5484D` at 85%, DangerDeep `#C9303A` at 100%. One function, `Tokens.heatColor`, feeds both the bar and the thermometer. Holding blue to 30% keeps the cool range blue; a teal-green tint still appears around 40-50% between blue and yellow.
- **Alarm and instrument colours** (my proposal): AlarmTint `#FFD6D2`, SirenOff `#F2C4C2`, Glass `#EAF6FB`, Chrome `#D6DEE8`, ChromeShade `#8C98AA`, smoke `#969AA8` / `#C6CAD6`, stripe light `#FFF8EC`.
- **Downtown** (my proposal, not built): asphalt `#625D59`, lane dashes `#FFD23F`, edge lines `#FFF1D0`, buildings coral `#F2A08E` / mint `#9FDCC3` / cream `#F8E9C8` (lower saturation than gameplay objects), teal Atmosphere tint; barrier orange `#FF8A1F` with `#FFF8EC` stripes on navy; pothole rim `#B7ADA3`, hole `#2A2523`. Scenery never uses hazard orange.
- **Type:** Fredoka One only (approved); hierarchy by size and colour.
- **Surfaces** (my proposal): radius 8 / 14 / 20 / pill; stroke 2 / 3 / 4; spacing 4, 8, 12, 16, 24, 32; shadow navy at 80% transparency, offset 0, 4, no blur.
- **Icons:** built from frames (coin, thermometer, puffs, clock); no uploaded images.
- **Motion** (my proposal): frame-rate-independent smoothing (Heat 10/s, effects 6/s), label cross-fade 0.15 s, bump 0.6 s. One shared alarm clock: Critical 0.8 rising to 1.3 cycles per second, Meltdown 1.4. One cycle = one panel peak; the right siren peaks half a cycle later, so all visible peaks combined are at most 2.8 per second, under the three-per-second ceiling (decision 0008).
- **Spectacle:** the player car and hazards. Scenery and HUD stay calm.

## The run HUD (revision 2 built, pending review)
- Cash top left, Distance top centre, Heat bottom centre, inside Roblox's safe area (`ScreenInsets = CoreUISafeInsets`). Cash and Distance unchanged and calm.
- Fixed widget sizes; Distance digits right-aligned with the unit in its own slot; on narrow screens Distance slides right to clear Cash.
- Scaling: one `UIScale` per widget root (cap 1.5); gaps to the edge scaled in code. The Heat panel and its halo stay at least 24 px inside the safe area at the bottom and sides; in portrait it also sits one touch row higher and its stage growth is capped by the screen width (measured 1.01 at 401 px wide). Stage growth elsewhere: 1.0 / 1.05 / 1.10 / 1.12.
- **ENGINE HEAT panel:** a constant-size cream title tab on the top edge; a radiator-themed thermometer (thick navy glass tube, shine streak, ticks, bulb, chrome radiator cap); the stage label in a fixed-width area with a short cross-fade; the bar as a fixed temperature scale revealed from the left with tick marks at the provisional 60% and 85%.
- **Effects ease in with Heat:** bulb glow, bubbles and heat lines from Hot; at Too hot! a controlled rattle, cap jiggle, stronger stripes and the panel alarm (cream to light alarm red, halo, slightly thicker border, two siren lights alternating). At Losing control! the bar stays full under a red wash, the cap lifts and tilts, cracks show, seven reusable smoke puffs rise in a bounded area (less drift in portrait), and **HOP NOW!** (red outlined text with an arrow, not a button) sits beside the label. No escape timer is shown.
- **Hop reset:** a drop to Cool clears every alarm and Meltdown effect in the same frame and returns the cap and instrument to rest.
- **Bump:** `jolt()` plays a 0.6 s jolt and liquid slosh that settles; it changes no Heat.
- **Reduced motion:** steady light-red panel, solid sirens, static stripes, no halo growth, no rattle, jolt, slosh, bubbles, heat lines or cross-fade, a still smoke cloud; fill, colour, labels and HOP NOW! still update.
- HUD art does not capture input (verified with taps on the panel, title, HOP NOW! and Cash).
- Number display unchanged: `Format.cash` and `Format.distance`.
- Instances: whole HUD 160, Heat gauge 138 (smoke 28, sirens 16, stripes 17, cap 9, HOP NOW! 7, bubbles 6, heat lines 4, cracks 3, halo 2, bulb glow 2). About 0.12 ms per frame on one desktop; no phone measurement.
- Optional alternative title (not built): "HEAT GAUGE". ENGINE HEAT is the implemented choice because it names what is overheating.

## Audio (proposals only; nothing inserted or played)
1. **Rising engine pressure hiss** from about 60%: a soft looping hiss whose volume and pitch follow Heat (smoothed), silent below Hot.
2. **Critical warning beep** fired from the HUD's `AlarmPeak` cue, so it stays in step with the panel: one short, soft two-note beep per alarm cycle (at most 1.3 per second), low in the mix.
3. **Meltdown warning** with an escaping-steam hiss: a slightly stronger beep on the same cue plus a steam burst at Meltdown start.
- Avoiding irritation: never more than one beep per cycle; beeps only while Critical or Meltdown; a short fade-out on Hop; volume under the music bus; no beep for the first Critical entry of a run if the player Hops within 0.5 s. Every cue already has a visual twin, so no information is audio-only.
- Assets: candidates found in the Creator Store search but **not auditioned and not inserted**. The only licensed library candidate is "Air Regulator Scuba Tank 4 (SFX)" by ProSoundEffects, `9113073932` (https://create.roblox.com/store/asset/9113073932), a possible Meltdown steam hiss. Other results were anonymous uploads, several citing YouTube as their source; they are not suitable for a children's game without clear rights. Selection pending: listen in Studio's Toolbox, prefer Roblox-licensed libraries, check the experience owner can play them, and record each choice in `vault/design/assets.md`.
- Hook: `RunHud.HeatCue` (Signal) fires `("Stage", stage)` and `("AlarmPeak", stage)`.

## Provisional interfaces (need Lane 1 and Lane 2 agreement, decision 0007)
- **HUD state** (`src/client/UI/RunHud/init.luau`): `{ cash: number, distance: number, heat: number (0..1), stage: "Calm" | "Warning" | "Critical" | "Meltdown"? }`. Lane 2 supplies `cash` (server-owned, read-only on the client). Lane 1 supplies the rest. `meltdownRemaining01` is no longer used and is ignored if supplied (0008 amendment). If `stage` is missing the gauge derives Calm, Warning or Critical from its provisional thresholds and never infers Meltdown.
- **Presentation calls for Lane 1 (Brian R):** `hud:jolt(strength?)` on a bump (presentation only); `hud.HeatCue` for future audio. Lane 1 keeps Heat, the Meltdown window, steering, escape and crash.
- **Shared alarm clock** (`src/client/UI/AlarmClock.luau`): `subscribe(fn(dt, phase)) -> stop`, `wave(offset?)`, `getPhase()`; the Heat panel sets the rate. Pip's Critical and Meltdown emphasis must read this clock rather than run its own loop.
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
- Localized Critical and Meltdown red emphasis on the car that never overwrites `ColorRole` or the original colours; restore the exact original appearance when the effect clears. Drive its pulse from `AlarmClock` (same phase as the HUD panel) and count its peaks in the combined three-per-second ceiling.
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
| Run HUD revision 1 (countdown version) | yes, 2026-10-19 | first contact sheet | not approved; revised |
| Run HUD revision 2: ENGINE HEAT panel, progression 0-95% and Meltdown, alarm, HOP NOW!, reduced motion, grey | yes, 2026-10-19 | revision 2 page | pending Adam |
| Revision 2 at desktop 1919 x 1079, phone portrait 401 x 778, phone landscape 750 x 381 | yes | revision 2 page | pending Adam; on landscape phones the panel covers the lower part of the view, to judge with the real chase camera in the Downtown scene |
| Pip on the shared rig | no | not captured | |
| Downtown road slice with pothole and barrier | no | not captured | |

Sample approved by: _pending_ (HUD), _pending_ (Pip), _pending_ (Downtown scene).

## Choices I made (reversible)
- Cream roof and navy trim on Pip repeat the UI's cream and navy so car and HUD read as one game.
- Hazard orange is not used in scenery.
- Distance moves right instead of shrinking on narrow screens; the gauge rises one touch row in portrait.
- Stills in the contact sheet are taken with reduced motion so a frame shows the stage, not a pulse phase.
