---
title: Visual direction
tags:
  - design
  - visual
status: draft
---

# Visual direction (draft; HUD approved, Pip and Downtown pending)

> [!warning] Draft: HUD approved, the rest pending
> Adam approved the HUD sample (revision 4) on 2026-10-20. Pip and the Downtown scene are not built, so the direction as a whole stays draft. Approving a plan or a direction does not approve a finished look; each sample needs its own approval line at the bottom before the style spreads.

## Scope
Lane 3 (World, UI & Feel, owner Adam) visual sample for Car Hop ([[GDD]], [[car-hop-outline-v2]] sections 06, 07, 09, 13; [[0008-heat-critical-meltdown]]). Order: HUD (approved 2026-10-20), then Pip, then the Downtown scene, each stopping for Adam's approval.
- Proposal sketches (not Studio captures): https://claude.ai/artifact/JYVRazaaENWAkiDXw5qBTS
- HUD review contact sheet, first version (real Studio captures): https://claude.ai/artifact/GuedwiFiS5F8rSd3tUUqmG
- HUD review, revision 2 (ENGINE HEAT panel; real Studio captures): https://claude.ai/artifact/KBtMAZdsTca42dgsaDycqK
- HUD review, revision 3 (thermometer fit, sirens, Heat colours, Cash counter; real-time videos and stills): https://claude.ai/artifact/HvuLfq2QqDoXGqq7a6xfBC
- HUD review, revision 4 (HOP NOW! pulse, centred Cash icon, clean gain fade, Meltdown hazard bar, billowing smoke, Distance B, narrow layout, input pass-through; real-time videos at three sizes): https://claude.ai/artifact/B9BR7TLBSW2qyQqA9zwo89
These pages are private to Adam until he shares them.

## Approvals recorded (Adam, 2026-10-19)
- **Pip direction approved**: name, silhouette and colours from the checkpoint sketch (described exactly below). The built model needs its own review.
- **Fredoka One** for game text; sizes 36 display / 24 value / 18 label / 16 minimum. Verified loading in Studio on 2026-10-19 (text measured; an unknown family failed).
- **Touch targets** 48 px minimum, 56 px for primary buttons.
- **Scaling rule**: viewport short side / 390, clamped 1.0 to 1.75; cap lowered to **1.5** on 2026-10-19 (HUD revision).
- **HUD revision approvals (2026-10-19, Adam):** stronger Critical stripes; smaller stage growth in portrait with the panel and its effects at least 24 px inside the safe area; no visible Meltdown timer and the ENGINE HEAT panel design (decision 0008 amendment). The Warning glow against the road is deferred to the Downtown scene review.
- **Reduced motion**: follow Roblox's setting, `GuiService.ReducedMotionEnabled` (verified available), plus a preview-only override that is never saved.
- **HUD ownership**: Lane 3 owns the run HUD's presentation; Lanes 1 and 2 supply its state.
- **HUD revision 3 direction (Adam, 2026-10-19; the HUD itself is still pending):** the thermometer fits inside the panel; sirens mirrored on the top border; the Heat colour stops below; combined alarm flashes at most **2.5 per second**; a floating Cash counter with original cash-stack art; Distance option A stays the default and option B is shown as a proposal only. Audio is approved in principle; choosing, inserting and playing sounds waits for a separate listening session.
- **Distance option B selected (Adam, 2026-10-19, revision 4 request):** "Approved: Distance Option B — floating outlined number with an original flag icon." It is now the only Distance presentation; option A (the cream pill) is removed. The overall HUD is still pending.
- **Reference (inspiration only):** `vault/design/references/ui-currency-counters-and-menu-buttons.png` (Adam asked on 2026-10-20 to commit the eight images in that folder as Lane 3 design references; see [[2026-10-20]] for whether they are pushed). Qualities taken from it: a floating icon plus number, heavy rounded numerals, a strong dark outline, saturated colour, chunky currency art, a slight highlight and shadow. Nothing in it is traced, cropped, reused or uploaded; all art here is original. Its Shop and Index buttons are future work and are not built.

## Approvals recorded (Adam, 2026-10-20)
- **HUD approved:** "Approved: HUD (revision 4, review page B9BR7TLBSW2qyQqA9zwo89)." Adam played a clip on the review page and it worked.
- **Figma-first UI workflow for Lane 3 approved:** "Approved: Figma-first UI workflow for Lane 3." Every new or changed Lane 3 screen, panel, HUD element or popup is planned, mocked in the Figma file "Car Hop UI", specified in `vault/design/ui/<screen-name>.md`, approved here, then built from the spec ([[0012-figma-ui-workflow]]). Screen approvals under this workflow are recorded in this section with the Figma link.
- **Accepted as built:** the narrow-screen rule (Distance moves to its own row below about 378 px of usable width); the Distance flag at 1.33 times the digit height (an accepted exception to the 1.25 icon guide); Distance option B as the only Distance presentation.
- **Still open, not passed** (not tested in this review):
  - real phones and phone performance (only the Device Simulator was used);
  - the player's own Roblox Reduce Motion setting (only the preview override was used);
  - the 378 to 398 px one-row range (calculated, not seen on screen);
  - the HUD over the real road and chase camera (Downtown scene review).

## Approvals recorded (Adam, 2026-10-28, round 3 review)
Source: Adam's round 3 close-out brief (`vault/design/specs/hud-round3-closeout.md`, section 1).
- **ENGINE HEAT size, confirmed final:** the smallest Heat text (the title tab) is at least 14 real px on phones (scale 0.875) and 17 real px on Desktop and Tablet (scale 0.708 = 17 / (16 x HudScale 1.5)). Constants `RunLayout.HeatTextFloor` (14) and `RunLayout.HeatTextFloorLarge` (17) in `src/client/UI/Prototype/Run/RunLayout.luau`. This is an approved exception to the 16 px minimum for the Heat panel only; measured coverage is in `vault/design/specs/hud-round3-heat-coverage.md`.
- **Cash icon band, approved as built** (round 3, R3-C1: the paper band wraps the top, the fold and the front of the stack). No changes.
- **Hop button:** the car stays; the arrow is redone (round 3 close-out, four candidates). Not approved yet.
- **Review videos carry game audio** (music, sound effects, fanfares) from 2026-10-28; see the "Motion review evidence" rule in `CLAUDE.md`.

## Direction
Labels: (outline), (approved) by Adam, (my proposal, pending review), (constraint).

- **Emotion:** playful, confident, energetic, easy to read (brief).
- **Shapes:** chunky blocks with chamfers, short overhangs, oversized wheels (outline). Detail goes into silhouette, wheel stance, lamps, hazards (my proposal).
- **Materials:** SmoothPlastic; Metal only on wheel hubs; Glass for tinted windows; no textures, no Neon on cars (outline + my proposal).
- **UI palette** (my proposal, pending review; values live in `src/shared/UI/Tokens.luau`): card `#FFF4DC`, inset `#F6E6BF`, navy text and strokes `#1E2A4A`, secondary text `#4A5578`, primary orange `#FF8A1F` (pressed `#D96A00`), success `#3DBE6C`, danger `#E5484D` (danger only), coin `#FFC83D`.
- **Heat temperature scale** (revision 3 stops from Adam, exact values my proposal): Calm blue `#3FB6D8` at 0%, HeatMist `#C9D5EE` at 18%, HeatCream `#F8E6BC` at 35%, Warning yellow `#FFB81C` at 60%, HeatOrange `#FF8F2A` at 75%, Danger red `#E5484D` at 85%, DangerDeep `#C9303A` at 100%. **No green anywhere in Heat**: HeatMist (pale periwinkle) is there because a straight blue-to-cream blend passes through a pale aqua that reads green. Measured in Studio: 40% is `#F9DC9C` (pale yellow) and 50% is `#FCCA5B` (yellow-orange). One function, `Tokens.heatColor`, feeds both the bar (fixed full-width gradient revealed by the fill) and the thermometer liquid, so the liquid matches the bar tip. Because cream is pale on the glass and white track, the liquid has a navy surface line and the bar a navy tip marker.
- **Cash colours** (my proposal; green belongs to Cash, never to Heat): numerals a vertical gradient from CashTop `#2EE65A` to CashBottom `#A0F6B8`; outline and shadow CashOutline `#141B33`; bills BillFace `#34B45A`, BillLight `#96E4A5`, BillDark `#1F7A3C`; band BillBand `#FFB828` to BillBandShade `#E07B12`; sparkles `#D6FFDE`.
- **Alarm and instrument colours** (my proposal): AlarmTint `#FFD6D2`, SirenOff `#F2C4C2`, Glass `#EAF6FB`, Chrome `#D6DEE8`, ChromeShade `#8C98AA`, smoke rims `#C6CAD6` with a charcoal core `#565A68`. Meltdown hazard bar (revision 4): MeltdownBar `#E61E28`, MeltdownStripe `#8C0C18`, MeltdownGlow `#FFAA3C`.
- **Distance colours** (revision 4, option B approved): number a vertical gradient from FloatText `#FFFFFF` to FloatTextCream `#FFECC4`; outline and shadow the same as Cash (`#141B33`, 3.5 px, shadow 3 px below at 35% transparency). White/cream keeps Distance distinct from green Cash.
- **Downtown** (my proposal, not built): asphalt `#625D59`, lane dashes `#FFD23F`, edge lines `#FFF1D0`, buildings coral `#F2A08E` / mint `#9FDCC3` / cream `#F8E9C8` (lower saturation than gameplay objects), teal Atmosphere tint; barrier orange `#FF8A1F` with `#FFF8EC` stripes on navy; pothole rim `#B7ADA3`, hole `#2A2523`. Scenery never uses hazard orange.
- **Type:** Fredoka One only (approved); hierarchy by size and colour.
- **Surfaces** (my proposal): radius 8 / 14 / 20 / pill; stroke 2 / 3 / 4; spacing 4, 8, 12, 16, 24, 32; shadow navy at 80% transparency, offset 0, 4, no blur.
- **Icons:** built from frames (cash stack, thermometer, puffs, flag); no uploaded images. See **Icon style** below.
- **Motion** (my proposal): frame-rate-independent smoothing (Heat 10/s, effects 6/s), label cross-fade 0.15 s, bump 0.6 s. One shared alarm clock: Critical 0.6 rising to 1.0 cycles per second, Meltdown 1.2, hard cap 1.25. Each cycle has two visible peaks: at phase 0 the panel tint, the left siren, the Meltdown bar's edge glow and the HOP NOW! scale pulse (1.00 to 1.08) peak together (counted as one peak); at phase 0.5 the right siren peaks. The Meltdown hazard stripes travel one stripe spacing per cycle at constant speed, so the bar's average brightness stays flat and they add no peak (measured in recordings: whole-bar brightness 74-76 of 255). So combined visible peaks are 2 x the cycle rate: 2.4 per second in Meltdown and 1.2 to 2.0 in Critical, under Adam's **2.5 per second** ceiling (lowered from three on 2026-10-19; decision 0008 amendment 2).

## Icon style (draft, pending review)
- **Outline:** near-black navy `#141B33`, 2 px at the 32-48 px sizes (about 4-6% of the icon height), thicker in proportion at larger sizes; every shape has one.
- **Shine:** one small, soft white highlight near the upper left of the front shape, about 25% transparent; never more than one.
- **Tilt:** a slight anticlockwise tilt: about 10 degrees for the cash stack, 8 for the Distance flag; upright for instruments.
- **Shadow:** a faint navy copy of the back shape, offset 1-2 px down and right, 75% transparent, no blur, kept small so it does not pull the perceived centre down (revision 4; was 15% offset and 65%).
- **Centring (revision 4):** each icon sits in a square holder and is centred by its visible bounds (all shapes rotated, with outlines), computed from its geometry. Beside a number, the icon's centre sits on the visible digit midpoint (measured Fredoka One metrics, not the TextLabel box), its height is about 1.25 times the outlined digit height (the Distance flag is 1.33 times, accepted by Adam on 2026-10-20), and the gap from the artwork to the first ink is about 8 px at scale 1.0. Animations scale icons about their centre and numbers about their digit centre line, so alignment holds while animating.
- **Standard sizes:** 32, 48, 64 and 96 px at scale 1.0. The Cash icon's artwork is about 59 x 42 px; the flag about 31 x 36 px.
- **Detail drop-off:** at 32 px, drop inset borders and secondary shading first; keep the silhouette, outline and main colour. At 64-96 px everything is shown. (The Cash bill's small emblem was removed in revision 4: beside a centred band it made the bill lopsided.)
- **UI shapes vs images:** build icons from frames, corners, strokes and gradients first. Use an uploaded image only when shapes cannot give a clean result, and only after Adam approves the upload; never substitute an image silently.
- **Notification badge (described, not built):** a small red `#E5484D` circle with a white "!" and a navy outline, on the upper right of a button. The symbol carries the meaning, so it reads in grey too. It is for real new content only, never for pressure or countdowns.

## Interface status
- **Cash counter:** built in revision 3, revised in revision 4, approved with the HUD on 2026-10-20.
- **Distance (option B):** selected by Adam; built in revision 4 as the only Distance presentation; approved with the HUD on 2026-10-20.
- **Shop button, Garage/Index button:** deferred; not built (seen in the reference only).
- **Additional currencies and rebirth:** not approved; not designed.
- **Spectacle:** the player car and hazards. Scenery and HUD stay calm.

## The run HUD (revision 4, approved by Adam 2026-10-20)
- Cash top left, Distance top centre, Heat bottom centre, inside Roblox's safe area (`ScreenInsets = CoreUISafeInsets`), clear of Roblox's top bar.
- **Revision 4 changes** (2026-10-19; measurements and videos on the revision 4 page):
  - **HOP NOW!** No arrow (instance, space and animation removed). Right-aligned, vertically centred with the stage label, pulses 1.00 to 1.08 on the shared clock's panel peak, anchored at its right edge (measured 0.00 px right-edge movement); steady with reduced motion. Clear of the label (44-78 px), the bar glow (7.5-12.6 px) and the smoke.
  - **Cash icon:** band centred in the top bill's own rotated space (child of the bill); square holder; composition centred by visible bounds; centred on the visible digits, 8 px from the "$" ink. Measured: band vs bill centre 0.13 px, composition vs holder 0.04 px, icon vs digit midpoint 0.13 px, height 1.24 times the digits, gap 7.9 px. The icon pops 1.08 about its centre instead of bouncing up.
  - **Gain label:** text, outline, shadow and the shadow's outline fade from one value; pooled labels fully reset. Frame-by-frame, the area is identical to the empty background from the first frame after the fade.
  - **Meltdown bar:** solid saturated red, darker-red diagonal stripes sliding one spacing per alarm cycle (seamless repeat, constant speed), a bright edge glow peaking with the panel. Reduced motion: same red and stripes, stationary, steady glow.
  - **Smoke:** same budget (7 puffs, 28 instances): varied sizes, irregular spacing, growth, overlap, a leftward lean and wobble, charcoal cores with light rims, fading toward the top. At least 8 px from the left siren's glow at every size (cap 8.0 / 9.0 / 13.4 px; smoke itself 17.5 / 20.2 px and more).
  - **Distance B:** flag icon + white-to-cream number + smaller unit on the same baseline; left-aligned after the flag like Cash, so the 8 px gap holds for every value. Rich text was not used: Roblox drew a much thinner outline on it.
  - **Narrow screens:** Distance centred; the Cash punch is lowered to keep 12 px; below 0.06 punch Distance moves right; if even no punch fits (safe width under about 378 px), Distance moves to its own row under Cash at the right edge and Cash keeps its full punch. Text never shrinks. Measured at 359 px: 16.7 px vertical gap with $1,000T at punch 1.16.
  - **First mount:** the first supplied state shows with no gain, pop, punch, entrance fill, cross-fade or stage cue; an initial Critical or Meltdown alarm still runs.
  - **Input:** six spots (Cash icon and number, Distance flag and number, title tab, HOP NOW!) pass mouse (desktop) and simulated touch (phone) to a preview-only ContextActionService receiver.
  - Instances: HUD 237, Cash 56, Distance 37, Heat 143, smoke 28 (unchanged).
- **Revision 3 thermometer:** about 18% smaller (tube 15 x 38, bulb 24, cap 22 wide) with 3 px strokes; panel height 92. Measured worst frames including strokes, rattle, jiggle and jolt (rendered px): Cool 13.0 top / 9.0 bottom / 23.0 to the text; Hot 12.6 / 7.4 / 15.2; Too hot! 13.2 / 7.7 / 14.8 (target at least 6). In Meltdown only the lifted cap and smoke leave the panel; they drift up and left and stayed 9.0 px from the left siren's glow and 49 px from the title tab.
- **Revision 3 sirens:** identical 22 x 18 lights, mirrored about the centre 10 px either side of the title tab, both from the same layout values, and kept centred on the top border as it thickens. Measured: 91.00 / 91.00 px from the centre at rest and 101.92 / 101.92 at the brightest pulse (scale 1.12); 0.00 px off the border line.
- **Cash counter (revision 3):** one reusable component (`src/client/UI/CurrencyCounter`), floating with no card: the original cash-stack icon on the left, the value on the right, about 8 px apart (measured 8.4) and optically centred (centres within 0.3 px). 40 px Fredoka One numerals with the green-to-mint gradient, a 3.5 px near-black navy outline (Contextual, so no box) and a navy shadow 3 px below; the `$` is styled like the digits. The icon is about 1.26 times the outlined numeral height, shadow included. One `UIScale` per widget (cap 1.5). The width is reserved for the widest compact value plus the punch, so Distance never moves while the number changes.
  - Gain: about 0.35 s count-up, 12% punch (16% for big gains, capped; lower on narrow screens), an icon pop about its centre (a bounce until revision 4), 2-3 sparkles and a rising, fading `+$amount` label below the number. Spend: a quick 0.18 s count-down, no celebration. First mount: no animation.
  - Updates during an animation continue from the shown value, the newest value wins and the count lands exactly on it; gains within 0.25 s share one label showing the real total. Two labels and three sparkles are pooled and reused.
  - Reduced motion: the value snaps, and decoration already playing is cancelled at once.
  - Formatting (`Format.cash`): full number with commas below 10,000; from 10,000 compact with up to three significant digits and no trailing zeros (`$12.4K`, `$116K`, `$1.2M`, `$3.45B`), truncated so it never shows `$1000K`. The supplied value itself stays exact. 23 checks in `src/client/UI/Preview/FormatChecks.luau`.
- **Distance options (revision 3 history):** A, the cream pill, was the default and B a proposal. Adam selected B for revision 4; A is removed.
- Fixed widget sizes, reserved for the widest values; the narrow-screen rule is in the revision 4 notes above.
- Scaling: one `UIScale` per widget root (cap 1.5); gaps to the edge scaled in code. The Heat panel and its halo stay at least 24 px inside the safe area at the bottom and sides; in portrait it also sits one touch row higher and its stage growth is capped by the screen width (measured 1.01 at 401 px wide). Stage growth elsewhere: 1.0 / 1.05 / 1.10 / 1.12.
- **ENGINE HEAT panel:** a constant-size cream title tab on the top edge; a radiator-themed thermometer (thick navy glass tube, shine streak, ticks, bulb, chrome radiator cap); the stage label in a fixed-width area with a short cross-fade; the bar as a fixed temperature scale revealed from the left with tick marks at the provisional 60% and 85%.
- **Effects ease in with Heat:** bulb glow, bubbles and heat lines from Hot; at Too hot! a controlled rattle, cap jiggle, stronger stripes and the panel alarm (cream to light alarm red, halo, slightly thicker border, two siren lights alternating). At Losing control! the bar stays full as a red hazard bar (revision 4), the cap lifts and tilts, cracks show, seven reusable smoke puffs billow in a bounded area (less drift in portrait), and **HOP NOW!** (red outlined text, no arrow since revision 4, not a button) sits beside the label. No escape timer is shown.
- **Hop reset:** a drop to Cool clears every alarm and Meltdown effect in the same frame and returns the cap and instrument to rest.
- **Bump:** `jolt()` plays a 0.6 s jolt and liquid slosh that settles; it changes no Heat.
- **Reduced motion:** steady light-red panel, solid sirens, static stripes, no halo growth, no rattle, jolt, slosh, bubbles, heat lines or cross-fade, a still smoke cloud; fill, colour, labels and HOP NOW! still update.
- HUD art does not capture input (revision 4: verified with a preview-only receiver, mouse and simulated touch, on six spots; driving integration not tested).
- Number display unchanged: `Format.cash` and `Format.distance`.
- Instances (revision 3, measured): whole HUD 208, Heat gauge 140, Cash counter 58 including its 5 pooled transients (20 instances), all allocated once at build and reused; at rest none of the transients are visible. Revision 2 measured about 0.12 ms per frame on one desktop; no phone measurement.
- Optional alternative title (not built): "HEAT GAUGE". ENGINE HEAT is the implemented choice because it names what is overheating.

## Audio (approved in principle; nothing inserted or played)
Adam approved the audio direction in principle on 2026-10-19. Choosing, inserting and playing sounds are deferred to a separate listening session. The `HeatCue` hooks stay in place.
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

## Next session: Pip (HUD approved 2026-10-20; start only when Adam asks)
- Git-tracked construction recipe that builds Pip at runtime through the agreed preview launcher (a module under `src/client/Home/`, Studio-only guard, rerunnable, one named container).
- Keep the approved silhouette, colours, rig and attachment names.
- Localized Critical and Meltdown red emphasis on the car that never overwrites `ColorRole` or the original colours; restore the exact original appearance when the effect clears. Drive its pulse from `AlarmClock` (same phase as the HUD panel) and count its peaks in the combined 2.5-per-second ceiling.
- One small hood-smoke emitter at `HeatSteam`, visible against bright Downtown without hiding the car or the target area.
- Propose a minimal presentation-only effect interface for Brian R (for example `setHeatStage(car, stage)`), marked provisional.
- Show chase-camera and side views at phone and desktop sizes; report real part and emitter counts; review Normal, Critical, Meltdown and recovery.
- Stop for "Approved: Pip".

## Following session: Downtown scene (after "Approved: Pip")
- Git-tracked recipe for the road slice, the pothole and the construction barrier; combine with the approved HUD and Pip.
- A clearly labelled preview-only Meltdown wobble, separate from real steering and crash logic; reduced motion disables the wobble and flashing but keeps the danger cues.
- Check hazard readability from a representative chase camera; restore transforms, lighting and camera on cleanup.
- **Landscape HUD composition** against the real road and chase camera: how much of the lower view the Heat panel covers on landscape phones, and whether the Cash and Distance row competes with the road ahead (deferred here from the HUD review; clipping, safe areas and overlap were already checked).
- Warning glow against the road (deferred from HUD revision 2).
- Stop for "Approved: Downtown scene".

## Representative sample

| Sample | Built? | Screenshot | Review notes |
|---|---|---|---|
| Run HUD revision 1 (countdown version) | yes, 2026-10-19 | first contact sheet | not approved; revised |
| Run HUD revision 2: ENGINE HEAT panel, progression 0-95% and Meltdown, alarm, HOP NOW!, reduced motion, grey | yes, 2026-10-19 | revision 2 page | pending Adam |
| Revision 2 at desktop 1919 x 1079, phone portrait 401 x 778, phone landscape 750 x 381 | yes | revision 2 page | not approved; revised |
| Run HUD revision 3: thermometer fit, mirrored sirens, no-green Heat colours, 2.5 per second alarm, Cash counter, Distance A/B | yes, 2026-10-19 | revision 3 page (videos and stills) | pending Adam |
| Run HUD revision 4: HOP NOW! pulse, centred Cash icon, clean gain fade, Meltdown hazard bar, billowing smoke, Distance B only, narrow layout, first mount, input pass-through | yes, 2026-10-19 | revision 4 page (real-time videos at 1920 x 1080, 359 x 690 and 677 x 338, stills, measurements) | approved by Adam, 2026-10-20 |
| Pip on the shared rig | no | not captured | |
| Downtown road slice with pothole and barrier | no | not captured | |

Sample approved by: Adam, 2026-10-20 (HUD, revision 4; open items listed under "Approvals recorded (Adam, 2026-10-20)"), _pending_ (Pip), _pending_ (Downtown scene).

## Choices I made (reversible)
- Cream roof and navy trim on Pip repeat the UI's cream and navy so car and HUD read as one game.
- Hazard orange is not used in scenery.
- On narrow screens the Cash punch shrinks first, then Distance moves right, then (under about 378 px safe width) Distance takes its own row; text never shrinks. The gauge rises one touch row in portrait.
- Stills in the contact sheet are taken with reduced motion so a frame shows the stage, not a pulse phase. From revision 3, motion is reviewed in real-time video, with stills as a supplement.
- The Cash gain label sits below the number (the reserved area), so it never runs into Roblox's top bar.
- Compact Cash values are truncated, not rounded, so a shown balance is never more than the real one.
