---
title: Island base (Lane 3 Stage 0)
tags:
  - design
  - visual
  - island
status: draft
---

# Island base: Car Hop's shared social hub (draft, revision 2, pending Adam)

> [!warning] Proposal only
> Written by Claude Code for Adam (Lane 3) on 2026-10-20. Nothing here is built. Revision 2 follows Adam's decision of eight plots ([[0011-eight-plots-per-server]]); the measured layout below still needs Adam's go-ahead for Stage A. The art direction and the Lane 2 marker contract ([[plot-marker-contract]]) each need their own approval. Approving the layout does not approve the finished art; the Stage B sample needs its own approval line in [[visual-direction]].

Review page (plan, computed drawings and sketches, not Studio captures; private to Adam): https://claude.ai/artifact/U2PgX5PWc9nvqHpxe4q7eh

Sources: Adam's island brief and his 8-plot change (2026-10-20 session), [[GDD]], [[car-hop-outline-v2]] sections 04, 05, 08, 09, 13, 14, 15, [[visual-direction]] (HUD approved), [[0007-concept-car-hop-and-lanes]], [[0010-vehicle-direction]] as context (accepted, on the branch `feature/lane3-first-car-downtown` only), and the Speedway references `vault/design/references/speedway-progress-01-start-dirt-oval.png` and `-02-end-elevated-loop.png` (inspiration only, nothing traced or reused).

## Identity (my proposal)
**A sculpted coastal motoring festival.** A softly lobed island in turquoise water. Eight club Speedways ring a warm paved plaza. Each one has a hairpin right behind its gate, a viewing bridge over the hairpin and the owner's Paddock in the infield. A cream "ribbon-road" Garage pavilion is the island's one hero shape. The three portal arches and the Stunt Circuit gate are the major destinations, supported by leaderboards, signposts, plot gates and planting. Extravagance comes from a few confident silhouettes, not from decoration density.

## Decided by Adam (2026-10-20)
- 8 plots, 45 degree slices, at most 8 players per server; the plot count is one config value ([[0011-eight-plots-per-server]]).
- Island at roughly option A's footprint; the freed room goes to bigger Speedways, with room for the whole upgrade path in the two Speedway references.
- Walking target: any plot gate to any shared plaza destination in under 8 seconds (replaces the outline's 20-second crossing).

## Measured layout (revision 2, recommended: track first)
Plaza frame: island centre at the origin, bearings clockwise from north (north = Roblox -Z). Plot frame: `u` is outward along the plot's centre line, `v` (or `x`) is to the right when facing outward. All values are studs. Computed by a geometry script (Node, scratchpad `layout8.js`), not yet built; Stage A builds it full size and measures it.

### Inputs (assumptions marked)
| Input | Value | Source |
|---|---|---|
| Car envelope | 12.5 x 5.7 (diagonal 13.74) | rounded up from the car session's provisional bounds 12.465 x 5.66 (uncommitted, read only) |
| Lap | about 15 s for every car | outline 08 (Tunable) |
| Lineup | up to 15 cars lapping together, evenly staggered | outline 08: Slots max 12 plus 3 from a proposed pass |
| Walking speed | 16 studs/s **(assumption)** | Roblox default; no override in `src`; read from the place in Stage A |

### Speedway (per plot)
| Item | Value | Option A (superseded) |
|---|---|---|
| Shape | teardrop circuit: hairpin R 35 (135 degrees) right behind the gate, side straights 78.6, two back corners R 30 (108 degrees), back straights 26.4, a sweeper R 140 (9 degrees) | stadium oval |
| **Path length** | **427.1** | 250.0 |
| **Track width** | **16**; 1-stud barrier outside, 1-stud curb inside, 2-stud margins | 11 |
| **Tightest turn radius** | **30** (centreline; the hairpin is 35) | 13 |
| Swept car in the tightest turn (rigid rectangle, centre on the centreline) | outer corner 3.44 outside the centreline: 4.56 clear of the outer edge, 5.15 inside | 1.46 / 2.65 |
| **Most cars lapping together** | **25** at option A's yardstick (gap at least 4.2, a third of a car); gap 4.6 at 25 | 15 |
| Spacing at 15 / 12 cars | 28.5 per car, gap 16.0 / gap 23.1 | gap 4.2 / 8.3 |
| Speed implied by a 15 s lap | 28.5 studs/s (Lane 1 or 2 tuning: keep 15 s, or lengthen the lap) | 16.7 |
| Direction | counter-clockwise from above: out of the hairpin up the right side, across the back, down the left side | same |
| Start / finish line | two thirds along the left side straight, just before the hairpin, cars heading toward the plaza and the bridge; a START / FINISH gantry | mid left straight |
| Fit | outer clearance edge sampled every degree or stud: at least 2.5 from both dividers, at most r 241.5 | same rule |

### Plot (45 degree slice)
| Item | Value |
|---|---|
| Plot bearings | `22.5 + 45 x (n - 1)`; Plot01 to Plot08 clockwise; dividers on multiples of 45 |
| Gate / spawn | gate at r 62 (curved with the promenade, 14 wide); spawn marker at u 66 facing the plaza |
| Entrance court | u 62 to 80.7 (the hairpin's outer clearance edge); 46 wide at the gate. Gate arch with the nameplate, planting |
| Viewing bridge | deck top 10 (9 clear; car 4.7 tall), 10 wide, spans the hairpin from u 80.7 to 102.7 (22). Two curving ramps from the entrance court and one straight ramp into the infield, all 1 in 2.5 (25 long; the infield foot at u 127.7). The deck is the plot's viewing area and the way into the infield |
| Infield | 8,637 square studs; u 102.7 to 218.8; widths 34 / 55 / 71 / 88 at u 110 / 130 / 150 / 170 |
| Paddock (15 bays) | in the infield, as far out as it fits: row A u 173.8 to 189.8 (7 bays, Bay01 to Bay03 at its centre, nearest the bridge), aisle 10, row B u 199.8 to 215.8 (8 bays). Bays 9 x 16 (car clear 1.65 each side, 1.75 each end). Footprint 72 x 42. Cars back in from the aisle, so they face outward like a car show |
| Pit lanes | the aisle spans the infield (107 wide); its right end is pit in from the right straight, its left end pit out onto the left straight |
| Infield reserve | u 129.7 to 171.8 (42 deep, 72 wide at mid): grass and planting now, kept free for a later tier |
| Outer content radius | 241.5 (track clearance edge); width 47.5 at the gate, 184.8 at the outer edge |

### Room for the upgrade path (feasibility only; tiers are economy and not approved)
| Late-tier piece (reference 02) | Needs | Here |
|---|---|---|
| Raised deck over the ground track | deck top 12 (10 clear) | pillars in the margins; the bridge (10) is at the hairpin, away from it |
| Ramp to the deck | 72 at 1 in 6 | right straight 78.6, kept clear of the start line; left straight has 52 before the start line (about 1 in 4.5 down) |
| Vertical loop | radius 16; footprint 38 x 34 including the exit offset; top 34 | infield reserve 42 x 72 |
| Skyline | loop 34 tall | from the plaza centre, a loop 150 out looks about 13 degrees tall; the Garage crest (22) looks about 29 degrees from the court edge, so the Garage stays the hero |

The base path, pit lanes, start line, bridge and Paddock stay put at every tier. Where a raised section crosses over and how the pit lanes join it are designed with the tiers. A tier that changes the lap path needs a path set per tier in the contract (question for Brian L). Starting look: I recommend the base circuit in the dirt look of reference 01 as the first tier (a Stage B question).

### Arrangements compared (same island size)
| Arrangement | Path | Tightest turn | Most cars | Infield | Trade-off |
|---|---|---|---|---|---|
| **Track first, Paddock in the infield (recommended)** | 427 | 30 | 25 | 8,637 | cars race right behind the gate, in view of the promenade; needs the bridge |
| Paddock first (entrance, Paddock, terrace, track) | 342 | 22 | 20 | 4,855 | no bridge; track starts 93 from the gate; side straights 15 (no ramp room) |
| Paddock behind the track, side walkways | about 286 | 24 | 17 | about 3,000 | the Paddock takes the widest part of the slice; rejected |

### Island and plaza
| Item | Value |
|---|---|
| Water line | 8 broad lobes, one behind each Speedway, with coves on the dividers; a scenic headland in the cove at bearing 135 (between Plot03 and Plot04). r 255.6 to 284.7: **diameter about 511 to 569** |
| Level build surface | r 247.5 (6-stud planted setback beyond content) |
| Minimum content-to-water setback | 19.2 (worst at bearing 8.5) |
| Plaza / court / promenade | r 0 to 52 / r 0 to 16 / r 52 to 62 (unchanged) |
| Garage | crescent pavilion r 30 to 48 over bearings -55 to +55; ribbon roof r 28 to 50, crest about 22; passages moved to bearings -18 and +18 (they land 4.9 from the centres of the Plot08 and Plot01 gates) |
| Turntables | platform 17, rim 18; the car's 13.74 turning diagonal leaves 1.63 each side. Hero at bearing 0, r 20; flanks moved to bearings -40 and +40, r 38 (8.1 gap to the hero, 5.2 clear of the passages, outer edge at bearing 53.7, inside the roof span) |
| Portal row, Stunt gate, leaderboards | unchanged: portals on the line 38 south of centre (Downtown east, Dusty Highway, Summit Pass west); Stunt gate bearing 270, r 40; leaderboards at bearings 78 and 102, r 44. All sit on or beside dividers |
| Height hierarchy | Garage crest 22; portals 16; Stunt gate 14; leaderboards 16; plot gate arches about 9; viewing bridges 10 deck plus rails; signposts about 7; trees 10 to 16 kept off sightlines |

### Walking routes (computed polylines at the assumed 16 studs/s; timed in Stage A)
| Route | Studs | Seconds |
|---|---|---|
| Plot03 gate to Downtown (typical) | 38.6 | 2.4 |
| **Plot08 gate to Downtown (longest gate-to-destination, via a Garage passage)** | 109.6 | **6.9** |
| Plot01 gate to Garage door | 38.3 | 2.4 |
| Plot05 gate to Garage hero turntable | 75.0 | 4.7 |
| Plot08 gate to Stunt gate | 64.2 | 4.0 |
| Plot04 gate to leaderboards | 53.8 | 3.4 |
| Plot01 gate to Plot05 gate (opposite) | 126.3 | 7.9 |
| Plot gate to own bridge deck | 50.4 | 3.2 |
| Plot gate to own Paddock aisle (over the bridge) | 160.8 | 10.1 (not a shared destination) |
| Promenade full loop | 358 | 22.4 |
| Shore to shore through the centre | 483 | 30.2 |

Every gate-to-shared-destination route is under 8 s. No sprint, speed pads, teleports or faster WalkSpeed.

### Correction to revision 1
Revision 1's "minimum content-to-water setback 16.3 (worst at bearing 217.5)" came from a script that measured the content profile 15 degrees off. That layout is superseded; revision 2's setback uses the corrected script.

## Construction method (my proposal)
- **No meshes, uploads or Blender.** EditableMesh cannot be the production route: it fails in published games unless the creator is 13+ age-verified and ID-verified with the dashboard toggle on, its content is not saved in the place file, and it does not replicate (creator docs via Context7, 2026-10-20). A later Blender mesh pass for the Garage roof is a follow-up that needs Adam's approval and an upload approval.
- **Terrain** (smooth voxels written with computed occupancy) for the land mass, soft shoulders, sand, coastal rock and water, inside one known preview region. Terrain material colours and water colour are place-wide. The preset captures and restores them; this is an integration point for the shared place, where the Worlds may also use Terrain.
- **Parts** (SmoothPlastic, restrained Metal) for built surfaces and architecture: layered Cylinder discs for the promenade, plaza inlays and turntables; segmented track corners (see the performance plan); Block, Wedge, CornerWedge, Cylinder and Ball pieces for architecture, with cylinder or ball edge pieces for rounded leading edges.
- **Ribbon roof:** about 18 deliberately faceted segments along the arc, each a cream top slab, a navy underside slab, a rounded leading-edge cylinder and an accent strip (about 72 parts, joints about 6 degrees).
- Decorative pieces do not collide or take queries; walkable surfaces are separate collision parts.

## World palette (my proposal; environment only; HUD tokens unchanged)
Roles: deep water `#168EBC`, shallow water `#51D7D1`, pale sand `#F3D7A6`, warm paving `#F4E6CB`, grass `#79C86D`, darker foliage `#3B956E`, coastal rock `#8296A2`, rock highlight `#BCC7C9`, architectural navy `#20344D`, coral accent `#F47F70`, mint accent `#80D8BD`, sunny yellow `#F7CE58`. These are Adam's starting swatches, tuned later under Studio lighting. The approved UI orange (`Tokens.Primary` `#FF8A1F`) is used only for primary actions and the Garage edge accent; danger red (`Tokens.Danger` `#E5484D`) only for danger. Coral never marks a locked or danger state. Rarity colours never mark a plot. Composition target: about 60% calm water, grass and paving, 30% architecture and landscape, 10% focal accents. Values live in `src/client/Home/Island/WorldPalette.luau`, separate from `src/shared/UI/Tokens.luau`.

## Lighting (my proposal)
An explicitly invoked island preset: early-afternoon sun, softly warm, readable shaded faces, light Atmosphere haze for depth and to hide the water edge, no heavy bloom, no depth of field, no colour grading. Every Lighting value it touches is captured on first build and restored on cleanup. No light objects.

## Motion (my proposal)
Slow and event-driven: a Garage door that opens and returns, a Stunt gate boom that lifts and returns, a short chain acknowledgment on locked portals, gentle sway on about six flags, empty turntables turning once per about 40 s. One bounded update loop, tweens cancelled before restarting, every connection in a Trove. Reduced motion follows `GuiService.ReducedMotionEnabled` plus a preview-only override that is never saved (approved mechanism): no sway, shake or turntable spin, a steady acknowledgment instead of a chain rattle, and an immediate gate-state change. Labels and feedback stay. No audio.


## Performance plan for 8 Speedways (estimates; measured in Stages A and C)
| Item | Estimate | Plan |
|---|---|---|
| Track per plot | about 130 to 160 parts | surface, barrier and curb per segment; corners segmented to at most 0.15 chord error on the outer barrier (hairpin about 15 segments, each back corner about 11); barriers and curbs do not cast shadows |
| Rest of a plot | about 150 parts | Paddock floor and bay lines (about 35), bridge and ramps (about 30), gate arch and nameplate (about 20), START / FINISH gantry (about 8), pit lanes (about 8), planting (about 50); one marker Part with about 120 Attachments (no render cost) |
| Eight plots | about 2,300 to 2,500 parts | option A's twelve ovals were about 1,200, because each oval was a few layered discs |
| Plaza, Garage, portals, scenery | about 800 parts | Terrain carries the coast, land and infield grass |
| **Whole base** | **about 3,100 to 3,300 parts** | no light objects, particle emitters or audio (revision 1 estimated about 1,800); decoration has CanCollide, CanQuery and CanTouch off; measured counts in Stage C |
| Later tiers at maximum | plus about 150 to 250 parts per plot | raised deck, pillars, loop segments; only on plots that reach them |
| Lineup cars (Lanes 1 and 2; not built here) | up to 8 x 15 = 120 cars | proposal for the car and Lineup brief: drive them on each client from the path markers (anchored, moved by CFrame in one loop, no physics and nothing replicated per frame); update nearby plots every frame, slow down or pause distant ones, skip plots that are not streamed in. The car's part count decides the real cost (120 cars at 50 parts is 6,000 moving parts): the biggest performance risk |
| Streaming | single place with StreamingEnabled (outline 14) | plot visuals can stream by distance; the server always has every marker; whether plot models need a fixed streaming mode is open for Brian L |

## Requirement ledger (summary)
| ID | Requirement | Req/Opt | Acceptance evidence | Status |
|---|---|---|---|---|
| ISL-01 | Eight plots ring the plaza, face inward, equal footprints; plot count is one config value | Required | 8 containers, unique IDs, rotated copies of one layout; `PlotCount` read from one constant | planned (decided: [[0011-eight-plots-per-server]]) |
| ISL-02 | Each plot: Speedway, 3 visible bays, 15 reserved, nameplate, gate spawn facing the plaza, promenade access | Required | swept-path check, bay envelopes, spawn facing check, 8 spawn approaches walked | planned |
| ISL-03 | Sculpted lobed shoreline with grass, rock, sand and water transition; level build surface | Required | shoreline close-up, no stacked-block coast | planned |
| ISL-04 | Ribbon-road Garage pavilion with 3 integrated empty turntables and a GARAGE sign | Required | Garage stills, diameter vs diagonal | planned |
| ISL-05 | Portal family: Downtown (available preview), Dusty Highway and Summit Pass (chained, locked, placeholder requirements) | Required | portal stills, grey check of locks | planned |
| ISL-06 | Stunt Circuit gate (coming soon), two leaderboards with honest empty states, arrow signposts at decision points | Required | stills, readable signs | planned |
| ISL-07 | Landscape kit: 3 tree types, bushes, planting beds, rock clusters, one scenic outcrop | Required | sightline check | planned |
| ISL-08 | Presentation-only interactions with preview messaging, bounded motion, reduced motion | Required | real-time video, repeat-trigger test | planned |
| ISL-09 | Reproducible from Git recipes; one root; rebuild-safe; cleanup restores Lighting, camera and terrain region | Required | rebuild count, cleanup diff | planned |
| ISL-10 | Draft plot-marker contract for Lane 2 | Required | [[plot-marker-contract]] | drafted (revision 2) |
| ISL-11 | Eight-plot fit proof before decoration | Required | this section, then Stage A build | calculated |
| ISL-12 | Walking: any plot gate to any shared destination under 8 s | Required (Adam, replaces the 20 s crossing) | timed routes in Stage A | calculated (longest 6.9 s) |
| ISL-13 | No economy, saving, assignment, rewards, teleports, remotes, audio, uploads | Required (constraint) | file list, no remotes | constraint |
| ISL-14 | Bigger Speedways with room for the full upgrade path (dirt oval to elevated loop) inside the plot | Required (Adam) | path, width, radius, capacity table; reserve checks | calculated |
| ISL-15 | Leftover plot space makes the plot the player's own (Paddock, viewing area, entrance), no new system | Optional proposals (Adam) | bridge, Paddock and entrance court in Stage A footprints | proposed |
| ISL-16 | Performance plan for 8 Speedways | Required (Adam) | estimates above, measured counts in Stage C | planned |

## Not yet (kept visible)
Income Tier plot buildings, pit garages every third Slot, decorations, Speedway upgrade tiers (the raised deck, the loop and the asphalt look), the full Stunt Circuit, the Downtown run, live leaderboards, plot assignment and saving, Lineup cars on the track, audio, Garage UI.

## Choices I made (reversible)
- Plot01's centre line at bearing 22.5, numbered clockwise; dividers on multiples of 45, so the Garage (centred north), the portal row (south), the Stunt gate (west) and the leaderboards (east) sit on dividers.
- Track first, Paddock in the infield, reached over a viewing bridge; the alternative is the Paddock-first plot (table above).
- Start / finish just before the hairpin, so cars finish facing the bridge and the plaza.
- Starting bays at the centre of the row nearest the bridge; cars backed in, facing outward.
- The shoreline lobes sit behind the Speedways and the coves on the dividers, so every plot gets the same lobe; the scenic headland in the cove at bearing 135 is the one exception, scenery only.
- The Garage entrance is marked by the roof's crest with the hero turntable in front; the two flanking turntables sit under the wings.
