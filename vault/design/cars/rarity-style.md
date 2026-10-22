---
title: Vehicle rarity style guide
tags:
  - design
  - visual
  - vehicles
status: proposed
---

# Vehicle rarity style guide (proposed, pending Adam's review)

> [!warning] Proposal
> Nothing here is approved yet. The five-tier ladder, the Uncommon tier and its numbers, and the roster in [[roster]] are proposals from 2026-10-20. Economy values also need Brian L (Lane 2); rig and running gear need Brian R (Lane 1). The approved direction is in [[0010-vehicle-direction]].

## 1. The rule in one line
Quality stays constant; desirability rises. Every car, including the cheapest Common, is a finished, shaped, attractive car. Higher tiers are cooler in silhouette, stance, surfaces, wheels, lamps and paint, never just busier.

## 2. Quality floor (every tier)
- A continuous, shaped body: lofted cross-sections, not stacked boxes. Sides have a belly, a shoulder above the doors and a sill tuck; the plan view tapers at both ends.
- Hood with a crown across its width; sloped windscreen and rear glass; roof narrower than the body (72-82% of body width on cars) with inward-leaning side glass and a crowned roof.
- Wheels fill their arches with a small even gap; the arch is cut into the fender with a soft lip, never a black ring painted on a box.
- Designed front and rear: original lamp outlines with a dark housing and one or two inner elements; bumpers that wrap the corners; restrained panel lines.
- Dark glass, readable pillars, two mirrors.
- Reads as a car in plain grey; reads from behind and above at phone size.
- Low-poly by intent: broad surfaces, a few deliberate creases, no photographic noise, no accidental dents or streaks.

## 3. Tier ladder

| Tier | Badge | Treatment | Not allowed |
|---|---|---|---|
| Common | grey | Well-shaped stock body, solid paint, simple good-looking wheels, clear lamps, little clutter | Performance aero, stripes plus contrast roof, wide body |
| Uncommon (new) | green | One coordinated trim idea: a stripe or a contrasting roof (not both by default), a more distinctive wheel, a small lip spoiler where it fits, more individual lamps | Racing wings, liveries, wide arches |
| Rare | blue | Obvious performance or specialist identity: stronger arches, wider stance, purposeful scoop or vents, a wing where it belongs, technical wheels, one coherent original livery | Every feature at once |
| Epic | purple | A special silhouette: exotic or dramatic architecture, purposeful negative spaces and vents, a clear hero feature, restrained palette | Upgraded everyday car with stickers |
| Legendary | gold | One unforgettable idea plus two supporting features and at most one proposed signature animation; the coolest vehicle in its World, clearly above the Epic | Piles of wings, flames, neon and gold paint |

Each step up should improve several of: silhouette, stance and proportion, surface sophistication, wheel character, front and rear identity, paint and graphics, one signature feature. More triangles, objects or neon is not a step up.

## 4. Archetype exceptions
- Vans, buses, big rigs and plain sedans stay Common or Uncommon and are attractive through proportion and surfacing.
- Pickups and trophy trucks keep clearance and useful tyres; never slammed.
- Motorcycles, tracked or ski vehicles and six-wheelers need their own running-gear exception (see [[roster]] "Rig").
- Long vehicles (bus, rig, RV, Eldorado-length cruisers) need a game-length cap agreed with Lane 1's lane width and spacing.

## 5. Palette and materials
- Colour roles: BodyPrimary, BodySecondary, Trim, Glass, Headlamp, Taillamp, Plate, Tire, WheelMetal. Recolouring changes role colours only, never geometry.
- Saturated paint, dark charcoal trim, dark blue-grey glass, near-black tyres, restrained silver wheels, warm-white headlamps, red tail lamps with a small clear section.
- No Loaner (the most-ridden cars) is painted red: Critical uses red emphasis on the ridden car.
- Starter swatches (provisional): body #2878E8, glass #1B293E, trim #242A32, tyre #171B21, wheel #AAB4C0, headlamp #FFF0CD, tail lamp #E83D45.
- Roblox materials: SmoothPlastic with a little Reflectance on paint and glass; opaque glass (no interior, no sorting issues). PBR is optional and would need texture uploads (not proposed now).

## 6. Provisional budgets (full car, after triangulation, all wheels)

| Tier | Triangles |
|---|---|
| Common | 3,000-5,000 |
| Uncommon | 4,000-6,000 |
| Rare | 5,000-8,000 |
| Epic | 6,000-10,000 |
| Legendary | up to about 12,000 |

About 8-16 mesh pieces per car; one shared wheel mesh; no lights; at most one effect emitter. These are planning ceilings, not quotas, and not proof of phone performance. Roblox's 20,000-triangle import limit per mesh is an import limit, not a target.

## 7. Variants and accents
- Gold, Chrome and Rainbow stay Variant finishes. No base car is fully gold, chrome or rainbow; Legendary does not mean gold paint. Small chrome trim is fine.
- Proposed (not decided) rarity accents for Rare and above: a thin tier-coloured line in the tail-lamp bar or wheel centre caps. Must be checked against Heat danger red and the HUD before use; cars must read without any glow.

## 8. Graphics and content
- No taxi signs, ever, unless a taxi is explicitly requested.
- No real logos, badges, wordmarks, plates or sponsors; parody names follow `AGENTS.md` "Vehicles".
- Child-appropriate graphics only: original stripes, numbers, stars, lightning and flames. No weapons, skulls, adult themes, police, military or emergency liveries.

## 9. Chase and phone readability
- The rear carries identity: roof-to-glass break, broad shoulders, an original tail-lamp signature, a readable bumper.
- Tail lamps at least 4 px tall on a 359 px-wide phone; paint stays the largest colour area.
- Check every car in the chase view at phone portrait, phone landscape and 1920 x 1080.

## 10. Heat compatibility
- The car's Critical and Meltdown emphasis reads the shared AlarmClock and peaks with the HUD panel (wave(0)), so it adds no visible peaks; combined ceiling 2.5 per second.
- Emphasis is localized: tail lamps pulse and the paint shifts at most about 30% toward Danger red; recovery restores the exact colours and materials.
- One hood-smoke emitter at HeatSteam (Roblox's built-in smoke texture), drifting back over the car, away from the lane ahead.
- Reduced motion: steady emphasis, no pulsing, no smoke.

## 11. Evidence required before a car is called finished
Grey form and painted stills (front 3/4, rear 3/4, side, front, rear, top, chase, close-ups), a real-time turntable and side-to-rear video, a Studio chase-distance view, phone portrait, phone landscape and 1920 x 1080 checks, measured triangle, mesh and material counts, Heat states with recovery, paint swaps, and a clean rebuild with no duplicates.

## 12. Economy (proposal for Brian L; not in code)
The outline's values are Tunable proposals and the Cash economy is not yet approved, so these are not approved numbers.

| Tier | Keys claim | Lap Pay | Joyride |
|---|---|---|---|
| Common (outline) | 3 s | $5 | $3 |
| **Uncommon (proposed)** | **3.5 s** | **$8** | **$5** |
| Rare (outline) | 4 s | $12 | $8 |

Uncommon values are geometric midpoints (sqrt(5 x 12) = 7.7, sqrt(3 x 8) = 4.9) because each outline tier pays about 2.4-2.7 times the one below; claim time takes half the usual 1-second step. Spawn tendency: between Common and Rare (Lanes 1 and 2 to define). Heat-to-spare check: with the roster in [[roster]] every claim leaves at least 3 seconds of Heat; a Legendary Compact would not (8 s - 6 s), so each Legendary stays in the Special slot (Adam, 2026-10-20).

## 13. Reference observations (low-rarity quality bar)
Two screenshots of a blue rally-style four-door sedan from another Roblox game, kept outside Git in `C:\Users\agert\Documents\Car-Hop-Art\references\`. They set the modelling quality bar for Commons; the wing, hood scoop and rally attitude belong to Rare and above.

| Visible in the screenshots | Our use | Not established by them |
|---|---|---|
| Continuous body with broad, softly faceted panels and soft highlights | Lofted body sections with smoothing by angle | Topology, triangle count |
| Rear body much wider than the roof; strong lean-in of the side glass; large raked rear glass | Roof 72-82% of body width; leaning glass | Exact dimensions |
| Swollen rear quarters and front fenders; wheels filling the arches | Fender volume over each axle; even arch gap | Wheel construction |
| Hood that changes shape across its width (raised centre with a scoop) | Hood crown (scoop only on Rare+) | Materials, shaders |
| Swept headlamps with dark inner parts; boomerang tail lamps, red over clear with round elements | Original lamp shapes with housing and inner elements | Any rights to the shapes |
| Bumpers wrapping the corners, lower intake, plate recess | Wrap-around bumpers, intake, blank plate | Plate artwork |
| Mirrors, dark pillars, door handles, restrained panel lines | Mirrors, pillars, a few seams | |
| Large rear wing, hood scoop, taxi roof sign, game UI | Not copied (wing and scoop are Rare+ ideas; taxi sign never) | |

## Sources (guidance, not templates)
- BMW design layers: https://www.press.bmwgroup.com/usa/article/detail/T0125234EN_US/design-that-moves-the-bmw-design-dna
- Mazda surfaces and light: https://www.mazda.com/en/innovation/monozukuri/design/
- Porsche shoulders and stance: https://newsroom.porsche.com/en_US/products/taycan/exterior-design-18551.html
- Roblox mesh specifications: https://create.roblox.com/docs/art/modeling/specifications
- Roblox model import: https://create.roblox.com/docs/parts/models
- Roblox rendering optimisation: https://create.roblox.com/docs/performance-optimization/improve
- RenderFidelity: https://create.roblox.com/docs/reference/engine/enums/RenderFidelity
- Designing for performance: https://create.roblox.com/docs/performance-optimization/design
