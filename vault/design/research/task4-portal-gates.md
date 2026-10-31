---
title: Task 4 research - World portal gates and lock readability
tags:
  - design
  - island
  - research
  - portals
status: research
date: 2026-10-22
---

# Task 4 research: World portal gates and lock readability

Research only, not approved. Sources are style references for proportion, massing and readability. Do not copy logos, emblems or specific ornament.

Viewed local copies (outside the repo): `C:\Users\agert\Documents\Car-Hop-Art\references\island-task4\portals\`

| File | Source | Licence |
|---|---|---|
| `deco-120-wall.jpg` | [Commons: Doorway 120 Wall St](https://commons.wikimedia.org/wiki/File:Doorway_120_Wall_St_(6216614969).jpg) | CC BY 2.0 |
| `deco-hall-of-state.jpg` | [Commons: Hall of State, Dallas](https://commons.wikimedia.org/wiki/File:Entrance_doorway_to_the_Hall_of_State_at_Fair_Park,_site_of_the_1936_Texas_Centennial_celebration_and_the_Pan-American_Exposition_in_1937_in_Dallas,_Texas_LCCN2015630335.tif) | Public domain |
| `petra-khazneh.jpg` | [Commons: Al Khazneh](https://commons.wikimedia.org/wiki/File:Al_Khazneh.jpg) | CC BY-SA 3.0 |
| `spyro-srt-*` (4 files) | [Spyro Wiki: Portal](https://spyrowiki.com/wiki/Portal), [Winter Tundra](https://spyrowiki.com/wiki/Winter_Tundra), [Crystal Glacier](https://spyrowiki.com/wiki/Crystal_Glacier), [Magic Crafters](https://spyrowiki.com/wiki/Magic_Crafters) (Spyro Reignited Trilogy) | Game screenshots, reference only |
| `zelda-tphd-big-door.png`, `zelda-eow-big-door.png` | [Zelda Wiki: Big Key Locked Door](https://zeldawiki.wiki/wiki/Big_Key_Locked_Door) | Game models, reference only |

All sources were accessed on 2026-10-22. Pixel measurements are approximate. **Inference** marks my reasoning.

**Viewing maths.** Roblox `FieldOfView` is vertical. At FOV 70 the visible height is about 1.40 × distance: 280 studs tall at 200 studs, 378 at 270. **Inference:** a bold rounded letter needs about 12 px cap height on a 720 px tall phone render (1.7% of screen height). That works out to **4.7 studs at 200** and **6.3 studs at 270**. For comfortable reading (2.5%), it needs 7.0 and 9.5 studs.

## Observations

**1. One frame, swapped material** ([Spyro Portal](https://spyrowiki.com/wiki/Portal), `spyro-srt-portal.jpg`)
- **Observed:** stacked stone lower columns, a thick gold faceted frame and a gem keystone. The frame is about 370 × 390 px around an opening about 190 px wide. The wiki describes per-world material variants of the homeworld portals.
- **Inference:** the family reads from one outline. Identity comes from material and the crest object.
- **Apply:** use one template (column footprint, crest outline, field opening, equal column-top and crest-top heights). Vary only the surface: gold steps, sandstone bands, pale stone with crystals.
- **Limitation:** an arch, not two columns plus a crest. The wiki variants were read as text, not viewed.

**2. Crest lettering** (same image)
- **Observed:** "STONE HILL" is extruded gold 3D letters with a dark side face, overlapping the opening's upper shoulder. Cap height is about 45 px: about 24% of the opening width and 11-12% of gate height. The 10 characters span about 73% of the frame width, about 0.6 cap height per character.
- **Inference:** on a 20-stud field that gives a **4.5-5 stud cap**, readable to about 190-210 studs, not 270. Fredoka One is wider (about 0.85-0.9 cap per character, unmeasured), so one line of "DUSTY HIGHWAY" would be about 50 studs wide.
- **Apply:** use two lines (DUSTY / HIGHWAY, SUMMIT / PASS) at a 4.5-5 stud cap, extruded 0.8-1 stud with a darker side face. Make the emblem **8-10 studs** across so it carries identity to 270+.
- **Limitation:** the font width and the 12 px threshold are assumptions to check in Studio.

**3. Stepped deco reveal** ([120 Wall St](https://commons.wikimedia.org/wiki/File:Doorway_120_Wall_St_(6216614969).jpg))
- **Observed:** 3-4 receding granite steps frame the opening. The upper opening is a gold grille, and a dark studded band carries the numerals at transom height. The fine chevrons blur. The step outlines, the gold-versus-dark contrast and the band survive.
- **Inference:** 2-3 low-poly steps of 1-1.5 studs each give lasting shadow lines.
- **Apply:** Downtown columns step back two or three times toward the field and top (a ziggurat cap). Inlaid lights are vertical strips **at least 0.6 stud wide**. Add one dark studded band under the crest.
- **Limitation:** a real building. Take the stepping trait only, not the grille or facade.

**4. Emblem rhythm** ([Hall of State](https://commons.wikimedia.org/wiki/File:Entrance_doorway_to_the_Hall_of_State_at_Fair_Park,_site_of_the_1936_Texas_Centennial_celebration_and_the_Pan-American_Exposition_in_1937_in_Dallas,_Texas_LCCN2015630335.tif))
- **Observed:** one medallion repeats in every cell of a bronze grid. The grid rhythm reads from afar, but the medallion only reads close up.
- **Apply:** optional 2-stud emblem tiles down the columns, as rhythm only, not identity.
- **Limitation:** a low-contrast photo.

**5. Weathered sandstone** ([Al Khazneh](https://commons.wikimedia.org/wiki/File:Al_Khazneh.jpg))
- **Observed:** at facade scale, the relief carvings turn to mush. What reads: column rhythm, horizontal entablature bands, the dark doorway, pink, red and cream rock strata, and softened edges.
- **Inference:** weathering reads as softened silhouettes and colour strata, not small carvings.
- **Apply:** Dusty Highway columns get chamfered or broken corners and **2-3 tone bands**. Make stripe carvings **at least 1 stud wide and 0.4-0.5 stud deep**. Use a broad sun or canyon crest outline.
- **Limitation:** a heritage site. Take the material trait only.

**6. Snow caps** ([Winter Tundra](https://spyrowiki.com/wiki/Winter_Tundra), [Magic Crafters](https://spyrowiki.com/wiki/Magic_Crafters))
- **Observed:** thick rounded slabs on upward faces only, with lobed overhanging drips, and small groups of tapering icicles under ledges.
- **Apply:** column and crest tops get caps **1-1.5 studs thick** with 3-5 drip lobes. Hang 3-cone icicle groups under the crest.
- **Limitation:** Winter Tundra is a night scene, so values will shift in daylight.

**7. Ice crystals** ([Crystal Glacier](https://spyrowiki.com/wiki/Crystal_Glacier))
- **Observed:** clusters of 3-6 faceted prisms with varied heights and tilts, in saturated cyan with lighter facets. They separate from the snow by saturation, not brightness.
- **Inference:** grouping and saturation read at distance. A thin single crystal vanishes.
- **Apply:** use 2-3 clusters per column and one large crest cluster, with the tallest prism **3-5 studs**.
- **Limitation:** the field may also be cyan, so keep the hues distinct.

**8. Chain X** ([Zelda Wiki](https://zeldawiki.wiki/wiki/Big_Key_Locked_Door), `zelda-tphd-big-door.png`)
- **Observed:** dark iron chains form an X plus a horizontal bar into a central lock hub anchored at the frame, dark against a bright gold door. A link is about 11% of the opening width. The hub is about 33%.
- **Inference:** the X-to-centre structure says "sealed" before the lock detail resolves. Links resolve only within about 100 studs; beyond that the chain reads as a band.
- **Apply:** anchor the chains at the column tops and bases, cross them at the field centre, and wrap each column 2-3 times. Make links **2-2.5 studs long** and the band **1.2-1.5 studs** wide, in dark warm grey, never red.
- **Limitation:** a moody dungeon door. Ours must stay friendly in bright light.

**9. Padlock size** (`zelda-tphd-big-door.png`, `zelda-eow-big-door.png`)
- **Observed:** the TPHD hub is about 33% of the opening width. The Echoes of Wisdom shield plate is about 55%, with a big black keyhole as the strongest contrast spot.
- **Inference:** 30-40% of the opening width reads at range, and one dark focal shape gives the eye a target.
- **Apply:** a padlock **6-8 studs wide** (1.6-2.1% of screen height at 270 studs), with a **4-stud** emblem and a dark keyhole. Below it, a "LOCKED" plaque with a cap height of at least 2.5 studs, which says what is needed to unlock.
- **Limitation:** the Zelda locks need keys. Ours unlock by progress.

**10. Lit versus unlit** (`spyro-srt-winter-tundra.jpg`)
- **Observed:** stone pillars carry warm glowing vertical slot inlays that read clearly at mid-distance against darker stone.
- **Inference:** the change reads best if the inlays stay visible but dark when locked, rather than missing.
- **Apply:** locked: dark inlays and a dimmed field. Unlock: the padlock opens, the chains drop or retract, and the inlays light **bottom to top** over about 1-1.5 s. Once open, the field is the brightest element. With `GuiService.ReducedMotionEnabled`, fade to the lit state instead.
- **Limitation:** night exaggerates the glow, so daylight may need Neon. Untested.

## Open checks
- Measure Fredoka One width and confirm that two-line names fit the crest.
- Check that letters, emblem and padlock read at 200 and 270 studs on a phone-sized viewport in Studio.
- Pick distinct hues for the field, crystals and inlays in each world.
