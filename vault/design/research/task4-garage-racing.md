---
title: Task 4 research - garage, start gantry, plot gate, leaderboards
status: research
date: 2026-10-22
task: island rework Task 4
images: C:\Users\agert\Documents\Car-Hop-Art\references\island-task4\garage\ (outside the repo)
---

# Task 4 research: garage, racing gantry, plot gate, leaderboards

Research only; every number is a proposal for the owner. Sources were accessed on 2026-10-22. The photos carry sponsor and brand marks. Only general traits (proportion, rhythm, layout) are used, and no logo, name or signature design is copied.

**Scale (inference):** avatar 5 studs ≈ 1.75 m and car 12.5 ≈ 4.4 m, so 1 stud ≈ 0.35 m. From `island-base.md`: track 16 wide, 1-stud barriers, 2-stud margins, plot gate 14 wide, bays 9 x 16, bridge clear 9.

**Viewing math (inference, same convention as `ui/portal-sign.md`):** at vertical FOV 70, phone landscape (about 380 pt tall) gives **271/D pt per stud** at distance D. With 12 pt capitals for comfortable reading and 8 pt as the minimum: **capital height ≥ 0.044·D comfortable, ≥ 0.03·D minimum**. Desktop 1080p gives about 771/D px per stud, so phones set the limit.

## Sources (all images viewed)

| ID | Source | Shows |
|---|---|---|
| S1 | [Mac's Super Service Station](https://commons.wikimedia.org/wiki/File:Mac%27s_Super_Service_Station.jpg), rossograph 2017, CC BY-SA 4.0 | Art Deco station, three bays, lettered parapet, corner tower |
| S2 | [Roarin' Rohrer postcard](https://commons.wikimedia.org/wiki/File:Roarin%27_Rohrer,_Oklahoma%27s_most_beautiful_station_on_U.S._270,_McAlester,_Okla.,_stream_lined_service_(66892).jpg), c.1930-45, public domain | Streamline station, glass-block tower, round display window with a tire, pump islands |
| S3 | [HABS VA-1413-3 showroom](https://commons.wikimedia.org/wiki/File:View_looking_west_to_east_toward_the_showroom_-_Bob_Peck_Chevrolet,_800_North_Glebe_Road,_Arlington,_Arlington_County,_VA_HABS_VA-1413-3.tif), 2006, public domain | Glazed showroom, thin mullions, folded cantilever roof |
| S4 | [Suspended start, Malaysia 2012](https://commons.wikimedia.org/wiki/File:Suspended_starting_grid_2012_Malaysia.jpg), Morio, CC BY-SA 3.0 | Gantry across the straight, central light cluster |
| S5 | [Super Formula Lights grid, Suzuka 2026-05-24](https://commons.wikimedia.org/wiki/File:Super_Formula_Lights_Grid_Suzuka_24-5-2026.jpg), CC BY 4.0 | Staggered grid boxes, pit wall |
| S6 | [Hot Wheels Unleashed, official Steam screenshots](https://store.steampowered.com/app/1271700/) | Stylized start gate, loops, truss gantries, chevrons |
| S7 | [USSC legibility index (Signs of the Times)](https://signsofthetimes.com/the-usscs-best-practices-standards/); [IJSW review](https://journals.shareok.org/ijsw/article/view/9) | About 30 ft of viewing distance per inch of letter height (real signs) |

Local copies: `macs-super-service-station.jpg`, `rohrer-streamline-station.jpg`, `showroom-habs-va1413.jpg`, `start-gantry-malaysia-2012.jpg`, `grid-suzuka-2026.jpg`, `hwu-steam-1..6.jpg`. No game is claimed to be popular: I found no dated source for Roblox car games.

## Observations

**1. Bay doors well above the car** ([S1]).
- *Observed:* the bays are tall, plain voids between wide tiled piers.
- *Inference:* a 10 x 10 ft door is about 8.7 x 8.7 studs. That is a rule of thumb from a door vendor and forum posts, not a code.
- *Apply:* door clear opening **10 wide x 9 high**, which leaves 2.15 each side of the car. Bottom of the half-open door at **5.5**, so the lift arms and wheels show. Piers **2.5**.
- *Limitation:* the photo has no scale bar.

**2. Height set by the lift** (inference from S1).
- *Inference:* a car lifted about 5 studs has its roof at about 9.7.
- *Apply:* workshop floor-to-floor **14** (12 clear). Showroom upper level **11** (9 clear). Walls **1**, piers and corners **1.5** for a chunky faceted read.
- *Limitation:* the lift travel is assumed.

**3. Lettering in its own parapet band** ([S1], [S2]).
- *Observed:* the words run in one band above the openings, framed by stripes or trim.
- *Apply:* GARAGE capitals at 0.044·D: **6.6 / 8.8 / 11** studs at 150 / 200 / 250. Recommend **9** (the word is about 45 wide). Put a **2-stud** checkered band below it. Minimum at 250: 7.5.
- *Limitation:* assumes the default FOV, phone landscape, no fog and a level view.

**4. One vertical landmark** ([S1], [S2]).
- *Observed:* both stations pair a long low box with a single tower about **1.4 to 1.7 times** the box height, at the corner or the entry.
- *Apply:* the wrench-and-tire sculpture goes over the showroom entry, top at about **1.5 times** the building height. Nothing else on the roof.
- *Limitation:* two buildings only, and S2 is an idealized postcard.

**5. Thin glazing, deep overhang** ([S3]).
- *Observed:* glass from floor to roof, thin evenly spaced mullions, one low transom, and a roof cantilevered well past the glass.
- *Apply:* mullions **0.4** at a **17-stud** pitch, with each 16-diameter turntable centred in its own bay so no mullion crosses a car. The glazed front is then at least 51 wide. Transom at **8** or higher (car 4.7 + turntable 0.6), sill **0.5** or lower, overhang **4 to 6**. The rarity ring is **0.6 wide** on the rim.
- *Limitation:* one oblique photo, and the overhang shades the glass.

**6. Round display window, forecourt pumps** ([S2]).
- *Observed:* a lit window with round ends frames one tire display. The pumps stand on separate islands.
- *Apply:* the showroom corner glass turns in **3 to 4** facets. Light the interior warmer than the facade. Pump island **3 x 8 x 0.6**, pump **2 x 1.5 x 5.5**. Forecourt bays reuse **9 x 16**.
- *Limitation:* the postcard is hand-tinted art.

**7. Beam spans the track, lights central** ([S4]).
- *Observed:* the beam crosses the whole straight. The light cluster is about **10 %** of the span. Beam depth is about **1:12** of the span, measured on the image.
- *Inference:* children on phones need a chunkier beam.
- *Apply:* clear span **22** (16 + 2 x 1 + 2 x 2). Pillars **3.5 x 3.5**, beam depth **4** (1:6), underside at **10**. STUNT CIRCUIT capitals **2.5** (about 22 wide): comfortable at 57 studs, minimum at 83.
- *Limitation:* the image is hazy and full of sponsor marks.

**8. Five housings read as one unit** ([S4], [S6]).
- *Observed:* S4 has five red lights in a row. S6 has a full-width row of large lamps.
- *Apply:* five housings **1.6 x 2.4 x 1.2 deep** at a **2.6 pitch** (cluster about 12 wide, 55 % of the span), on the beam face, never below the 10 underside. Each housing has two lamps of **1.0** diameter.
- *Limitation:* I found no published light size or spacing. The FIA standard gantry height was not found.

**9. Staggered grid, low tire walls** ([S5]).
- *Observed:* each grid box is a bracket open at the rear, staggered left and right.
- *Apply:* boxes **7 x 14** in two staggered columns, row pitch **16**, lines **0.4**. Tire walls are stacks 3 high of tires **2.2 x 0.8**, about 2.4 tall. That stays below eye height (6), so the loop and podium stay visible.
- *Limitation:* real grid spacing was not measured.

**10. Trusses, chevrons, loops** ([S6]).
- *Observed:* red X-braced trusses, chevrons, and a loop with rails in a contrasting color.
- *Apply:* loop sculpture about **18** in diameter, ribbon **3** wide, rails **0.6**, set beside the apron. Chevrons on the pillar faces.
- *Limitation:* S6 is realistic PBR, so take the shape language only. Its orange-track look is distinctive to the brand: use our own palette and profile.

**11. Plot gate: two piers, one nameplate** ([S1], [S4]).
- *Observed:* S1 frames its entry in a dark accent band. S4's beam is one plain sign face.
- *Apply:* clear opening **14 x 11**. Stone bases **4 x 4 x 2.5**, pillars **3 x 3**, lamps **1.2**. Beam depth **3** with name capitals **1.6** (comfortable at 36, minimum at 53). Accent bands **0.6**. Checkered strip **1** high with 1-stud squares, which blur to a tone beyond about 30. Flags at **14 to 16**.
- *Limitation:* this is pedestrian scale. Admitting cars needs a 22-wide opening.

**12. Leaderboard text** ([S7], viewing math).
- *Observed:* real signs need about 30 ft of distance per inch of letter height.
- *Inference:* the game rule is about 16 times larger, because a screen resolves far less than the eye.
- *Apply:* header capitals **2.6**, read from the plaza at 60 (**3.5** at 80). Row capitals **0.7**, read at 15 or closer, so run the path within 15. Row pitch **1.4**, so ten rows take **14**. Display about **18 x 14** with a frame of **1**, bottom at **2**, trophy about **4**. Convert to SurfaceGui text with PixelsPerStud, in Tokens' Fredoka One.
- *Limitation:* the cap-height to TextSize ratio (assumed 0.7) is not measured. Rows beyond 15 studs will not read on a phone, which matches `portal-sign.md`.

## Open questions for the owner
- Viewing distances for GARAGE (150, 200 or 250) and for the leaderboard header and rows.
- Does the STUNT CIRCUIT gantry span the track (22) or a walkway (14)?
- Should forecourt bays reuse the 9 x 16 paddock bay?

[S1]: https://commons.wikimedia.org/wiki/File:Mac%27s_Super_Service_Station.jpg
[S2]: https://commons.wikimedia.org/wiki/File:Roarin%27_Rohrer,_Oklahoma%27s_most_beautiful_station_on_U.S._270,_McAlester,_Okla.,_stream_lined_service_(66892).jpg
[S3]: https://commons.wikimedia.org/wiki/File:View_looking_west_to_east_toward_the_showroom_-_Bob_Peck_Chevrolet,_800_North_Glebe_Road,_Arlington,_Arlington_County,_VA_HABS_VA-1413-3.tif
[S4]: https://commons.wikimedia.org/wiki/File:Suspended_starting_grid_2012_Malaysia.jpg
[S5]: https://commons.wikimedia.org/wiki/File:Super_Formula_Lights_Grid_Suzuka_24-5-2026.jpg
[S6]: https://store.steampowered.com/app/1271700/
[S7]: https://signsofthetimes.com/the-usscs-best-practices-standards/
