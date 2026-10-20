---
title: Island base (Lane 3 Stage 0)
tags:
  - design
  - visual
  - island
status: draft
---

# Island base: Car Hop's shared social hub (draft, pending Adam)

> [!warning] Proposal only
> Written by Claude Code for Adam (Lane 3) on 2026-10-20. Nothing here is approved or built. The layout, the art direction and the Lane 2 marker contract ([[plot-marker-contract]]) each need their own approval. Approving the layout does not approve the finished art; the Stage B sample needs its own approval line in [[visual-direction]].

Review page (plan, computed drawings and sketches, not Studio captures; private to Adam): https://claude.ai/artifact/U2PgX5PWc9nvqHpxe4q7eh

Sources: Adam's island brief (2026-10-20 session), [[GDD]], [[car-hop-outline-v2]] sections 04, 05, 08, 09, 13, 14, 15, [[visual-direction]] (HUD approved), [[0007-concept-car-hop-and-lanes]], and [[0010-vehicle-direction]] as context (accepted, but at the time of writing it is only on the branch `feature/lane3-first-car-downtown`, not on `main`). No island reference images were supplied.

## Identity (my proposal)
**A sculpted coastal motoring festival.** A softly lobed island in turquoise water. Twelve inward-facing club Speedways sit around a warm paved plaza. A cream "ribbon-road" Garage pavilion is the island's one hero shape. The three portal arches and the Stunt Circuit gate are the major destinations, with leaderboards, signposts, plot gates and planting in support. Extravagance comes from a few confident silhouettes, not from decoration density.

## Measured layout (option A, recommended)
Plaza frame: island centre at the origin, bearings clockwise from north (north = Roblox -Z). Plot frame: `u` is outward along the plot's centre line, `v` is to the right when facing outward. All values are studs. Computed by a geometry script and not yet built; Stage A builds it full size.

### Inputs (assumptions marked)
| Input | Value | Source |
|---|---|---|
| Car envelope | 12.5 x 5.7 (diagonal 13.74) | rounded up from the car session's provisional bounds 12.465 x 5.66 (uncommitted `stats.json`, read only; not standardized here). Adam's brief: 12.4 x 5.6, diagonal 13.61 |
| Lap | about 15 s for every car | outline 08 (Tunable) |
| Cars on one Speedway | up to 15 lapping together, evenly staggered | outline 08: Slots max 12 plus 3 from a proposed pass; all Lineup cars lap |
| Walking speed | 16 studs/s **(assumption)** | Roblox default; no override in `src`; the place setting is read in Stage A |

### Speedway (per plot)
| Item | Value |
|---|---|
| Centreline | stadium, turn radius 13, straights 84.2, **path length 250.0** (`2 x 84.2 + 2 x pi x 13`) |
| Track | 11 wide, navy; 1-stud cream barrier outside, 1-stud curb inside; 2-stud outside margin |
| Envelope | 43 x 127.2 (radius 21.5 around both turn centres) |
| Swept car in the turns (rigid rectangle, centre on the centreline) | outer edge 4.04 outside the centreline, inner 2.85 inside; swept width 6.89 |
| Clearance to the track edge | 1.46 outside in the turns, 2.65 inside |
| Spacing at 15 cars | 16.7 per car, **4.2 gap** (a third of a car); at 12 cars 20.8 per car, 8.3 gap |
| Speed implied by a 15 s lap | 16.7 studs/s (about walking pace; a Lane 1 or Lane 2 tuning matter) |
| Direction | counter-clockwise seen from above; start line mid-way down the left straight, cars heading toward the plaza |

### Plot (30 degree sector)
| Item | Value |
|---|---|
| Gate (front boundary) | r = 62, curved with the promenade |
| Spawn marker | u = 66, facing the plaza |
| Inner turn centre / barrier tip | u = 92.7 / 73.2 (set by the oval's width: `(21.5 + 2.5) / sin 15 deg`) |
| Outer turn centre | u = 176.9 |
| Paddock (15 bays reserved) | 74 x 39 at u = 200.4 to 239.4: row A (track side) 7 bays, 9-stud aisle, row B 8 bays; bays 8 x 15; pit lanes 9 wide from both aisle ends to the far turn (in on the right, out on the left) |
| Three initial bays | row A centre three (Bay01 to Bay03), 24 x 15 |
| Outer content radius | 241.5 (paddock back corners) |
| Width at the gate / at the outer edge | 32.1 / 125.0 (chord `2 r sin 15 deg`) |
| Clearance to the shared divider | at least 2.5 everywhere (checked on the rotated envelope, not the chord) |
| Between-plot gardens | beyond about r = 113 the divider zones are free of plot content (landscaping only) |

### Island and plaza
| Item | Value |
|---|---|
| Plaza | r = 0 to 52; open court r = 0 to 16 |
| Ring promenade | r = 52 to 62 (10 wide) |
| Level build surface | r = 247.5 (6-stud planted setback beyond content) |
| Water line | 6 broad lobes (on every other divider) and coves: r = 257 to 283, one scenic headland to 299 |
| Minimum content-to-water setback | 16.3 (worst at bearing 217.5) |
| Overall diameter at the water line | about 515 to 600 |
| Garage | crescent pavilion r = 30 to 48 over bearings -55 to +55; ribbon roof r = 28 to 50, crest about 22 high; footprint about 82 x 34 |
| Turntables | platform 17 across, rim to 18; the car's rotating diagonal is 13.74, leaving 1.63 each side. Hero turntable on the forecourt (bearing 0, r = 20); two flanking under the roof wings (bearings -38 and +38, r = 38). Gap flank-to-hero 7.4 |
| Garage passages | two through-passages at bearings -16 and +16 for the plots behind it; 5.2 clear of the flanking turntables |
| Portal row | three arches 17 wide x 5 deep, openings 11, on a line 38 south of centre; outer corner at r = 50.1. Reading order from the court: Downtown (east), Dusty Highway, Summit Pass (west) |
| Stunt Circuit gate | bearing 270 (west), r = 40, 28 wide, opening 18 |
| Leaderboards | two pillars at bearings 78 and 102, r = 44, 9 x 4 |
| Height hierarchy | Garage crest 22; portals 16; Stunt gate 14; leaderboards 16 (slim); plot gates about 9; signposts about 7; trees 10 to 16 kept off sightlines |

### Walking routes (computed polylines at the assumed 16 studs/s; to be timed in Stage A)
| Route | Studs | Seconds |
|---|---|---|
| Plot04 gate to Downtown (typical) | 42.7 | 2.7 |
| Plot12 gate to Downtown (behind the Garage, via a passage) | 108.9 | 6.8 |
| Plot01 gate to Garage door | 36.4 | 2.3 |
| Plot07 gate to Garage hero turntable | 80.6 | 5.0 |
| Plot01 gate to Plot07 gate (opposite) | 141.1 | 8.8 |
| Promenade full loop | 358 | 22.4 |
| Shore to shore through the centre (paddock to paddock) | 495.5 | 31.0 |

### The 20-second target
The outline's "about 20 seconds across the island" (320 studs at 16 studs/s) cannot hold shore to shore with twelve 250-stud Speedways and 15-bay Paddocks. Even the oval alone needs its inner turn 92.7 from the centre to fit a 30 degree sector. The routes people actually walk (gate to plaza destinations) take 2 to 7 seconds.

| Option | Speedway | Water-line diameter | Shore to shore | Cost |
|---|---|---|---|---|
| **A (recommended)** | path 250, gap 4.2 at 15 cars, bays 8 x 15 | about 515 to 600 | about 31 s | the island is larger than the outline's estimate |
| B tighter | path 220, turn radius 12, gap 2.2 at 15 cars, bays 7.5 x 14 | about 475 to 530 | about 28 s | a nearly bumper-to-bumper train at 15 cars; about 9% smaller |
| C literal 20 s | at most about 150 path | about 320 | 20 s | rejected: 15 cars need at least 187.5 of path just for their lengths, so the cars would overlap |

Recommendation: option A, with the target restated as **"any plot gate to any shared destination in under 8 seconds"** (measured in Stage A). No sprint, speed pads, teleports or faster WalkSpeed.

## Construction method (my proposal)
- **No meshes, uploads or Blender.** EditableMesh cannot be the production route: it fails in published games unless the creator is 13+ age-verified and ID-verified with the dashboard toggle on, its content is not saved in the place file, and it does not replicate (creator docs via Context7, 2026-10-20). A later Blender mesh pass for the Garage roof is a follow-up that needs Adam's approval and an upload approval.
- **Terrain** (smooth voxels written with computed occupancy) for the land mass, soft shoulders, sand, coastal rock and water, inside one known preview region. Terrain material colours and water colour are place-wide. The preset captures and restores them; this is an integration point for the shared place, where the Worlds may also use Terrain.
- **Parts** (SmoothPlastic, restrained Metal) for built surfaces and architecture: layered Cylinder discs for the promenade, plaza inlays, turntables and track turns (about 4 parts per turn instead of dozens of segments); Block, Wedge, CornerWedge, Cylinder and Ball pieces for architecture, with cylinder or ball edge pieces for rounded leading edges.
- **Ribbon roof:** about 18 deliberately faceted segments along the arc, each a cream top slab, a navy underside slab, a rounded leading-edge cylinder and an accent strip (about 72 parts, joints about 6 degrees).
- Decorative pieces do not collide or take queries; walkable surfaces are separate collision parts.

## World palette (my proposal; environment only; HUD tokens unchanged)
Roles: deep water `#168EBC`, shallow water `#51D7D1`, pale sand `#F3D7A6`, warm paving `#F4E6CB`, grass `#79C86D`, darker foliage `#3B956E`, coastal rock `#8296A2`, rock highlight `#BCC7C9`, architectural navy `#20344D`, coral accent `#F47F70`, mint accent `#80D8BD`, sunny yellow `#F7CE58`. These are Adam's starting swatches, tuned later under Studio lighting. The approved UI orange (`Tokens.Primary` `#FF8A1F`) is used only for primary actions and the Garage edge accent; danger red (`Tokens.Danger` `#E5484D`) only for danger. Coral never marks a locked or danger state. Rarity colours never mark a plot. Composition target: about 60% calm water, grass and paving, 30% architecture and landscape, 10% focal accents. Values live in `src/client/Home/Island/WorldPalette.luau`, separate from `src/shared/UI/Tokens.luau`.

## Lighting (my proposal)
An explicitly invoked island preset: early-afternoon sun, softly warm, readable shaded faces, light Atmosphere haze for depth and to hide the water edge, no heavy bloom, no depth of field, no colour grading. Every Lighting value it touches is captured on first build and restored on cleanup. No light objects.

## Motion (my proposal)
Slow and event-driven: a Garage door that opens and returns, a Stunt gate boom that lifts and returns, a short chain acknowledgment on locked portals, gentle sway on about six flags, empty turntables turning once per about 40 s. One bounded update loop, tweens cancelled before restarting, every connection in a Trove. Reduced motion follows `GuiService.ReducedMotionEnabled` plus a preview-only override that is never saved (approved mechanism): no sway, shake or turntable spin, a steady acknowledgment instead of a chain rattle, and an immediate gate-state change. Labels and feedback stay. No audio.

## Requirement ledger (summary)
| ID | Requirement | Req/Opt | Acceptance evidence | Status |
|---|---|---|---|---|
| ISL-01 | Twelve plots ring the plaza, face inward, equal footprints | Required | 12 containers, unique IDs, rotated copies of one layout | planned |
| ISL-02 | Each plot: Speedway oval, 3 visible bays, 15 reserved, nameplate, gate spawn facing the plaza, promenade access | Required | swept-path check, bay envelopes, spawn facing check, 12 spawn approaches walked | planned |
| ISL-03 | Sculpted lobed shoreline with grass, rock, sand and water transition; level build surface | Required | shoreline close-up, no stacked-block coast | planned |
| ISL-04 | Ribbon-road Garage pavilion with 3 integrated empty turntables and a GARAGE sign | Required | Garage stills, diameter vs diagonal | planned |
| ISL-05 | Portal family: Downtown (available preview), Dusty Highway and Summit Pass (chained, locked, placeholder requirements) | Required | portal stills, grey check of locks | planned |
| ISL-06 | Stunt Circuit gate (coming soon), two leaderboards with honest empty states, arrow signposts at decision points | Required | stills, readable signs | planned |
| ISL-07 | Landscape kit: 3 tree types, bushes, planting beds, rock clusters, one scenic outcrop | Required | sightline check | planned |
| ISL-08 | Presentation-only interactions with preview messaging, bounded motion, reduced motion | Required | real-time video, repeat-trigger test | planned |
| ISL-09 | Reproducible from Git recipes; one root; rebuild-safe; cleanup restores Lighting, camera and terrain region | Required | rebuild count, cleanup diff | planned |
| ISL-10 | Draft plot-marker contract for Lane 2 | Required | [[plot-marker-contract]] | drafted |
| ISL-11 | Twelve-plot fit proof before decoration | Required | this section, then Stage A build | calculated |
| ISL-12 | 20-second crossing | Required (outline, Delegated) | measured routes | **conflict**: see options above |
| ISL-13 | No economy, saving, assignment, rewards, teleports, remotes, audio, uploads | Required (constraint) | file list, no remotes | constraint |

## Not yet (kept visible)
Income Tier plot buildings, pit garages every third Slot, decorations, full Stunt Circuit, the Downtown run, live leaderboards, plot assignment and saving, Lineup cars on the track, audio, Garage UI.

## Choices I made (reversible)
- Plot01's centre line at bearing 15, numbered clockwise; dividers on multiples of 30, so the Garage (centred north), the portal row (south), the Stunt gate (west) and the leaderboards (east) sit on dividers, and every gate looks between destinations.
- The Garage entrance is marked by the roof's crest with the hero turntable in front; the two flanking turntables sit under the wings.
- Portal order follows reading order from the court.
- The shoreline lobes sit on every other divider, so each plot gets half a lobe and half a cove (equal for all twelve). The scenic headland at bearing 120 is the one exception, flanking Plot04 and Plot05; it is scenery only.
