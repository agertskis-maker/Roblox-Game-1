---
title: Dusty Highway and Summit Pass - message for Brian R
tags:
  - design
  - worlds
  - lane1
  - lane3
status: sent
---

# Dusty Highway and Summit Pass: message for Brian R (Lane 1)

From Adam (Lane 3), sent through the vault on 2026-10-28. Written by Claude Code from Adam's brief (`vault/design/specs/worlds-dusty-summit-build.md`, copied on the branch `feature/lane3-worlds-dusty-summit`). Please answer in the Replies section at the bottom (you or your AI). Nothing here asks you to change code today: it lists what Lane 3 is building as a look preview, and the contracts only you can set.

## What Lane 3 is doing (so you know what you will see)

Adam approved the redesign of the two Worlds on 2026-10-28. The plans are `vault/design/specs/world-plan-dusty-highway.md` and `world-plan-summit-pass.md`; they are not on `main` yet, so read them on the branch `feature/lane3-hud-downtown-lookdev` (the plans) or `feature/lane3-worlds-dusty-summit` (the plans with Adam's dated answers at the end of each). Lane 3 is making both look as dense and polished as Downtown: layered mountains and mesas behind the road, a real canyon gorge, a lake, a glacier tunnel, a lodge, and so on.

- **Preview only.** All of it lives in `src/lookdev/Downtown/**` and the Blender recipes in `assets/downtown/kit/**` on the branch `feature/lane3-worlds-dusty-summit` (it builds on `feature/lane3-hud-downtown-lookdev`). It is scenery. It has no collision, no gameplay, no remotes and no saved data.
- **We did not touch** `src/client/Run`, `src/shared/Run`, the road meshes, lanes, hazards, hop rules or the camera. Every number below that says "preview" is a number Lane 3 chose so the scenery can be drawn; it is yours to accept or change.
- Scenery never uses the hazard look (orange and white stripes, cones) and never looks like the Hop ring, the trail chevrons or the Keys ring.

## How to read each item

Each item says: **what we need from you**, **benefit**, **risk**, **how to test**, and **what Lane 3 does in the meantime**.

## Dusty Highway

### D1. Canyon Bridge: the gorge (Adam chose the real gorge, "Option A")
- **Need from you:** (a) who owns the ground: today the look-dev draws the ground as big flat slabs, and for the gorge it cuts a hole under the bridge; (b) what happens to a car that leaves the deck: falling, respawn, or a hard wall; (c) the kerb or parapet wall and its collision; (d) hop height and length near the bridge (can a hop cross the gorge, should it be blocked); (e) who streams the ground and the walls.
- **Benefit:** the bridge finally reads as a bridge over a canyon, the biggest "wow" moment of Dusty Highway, instead of a road in a trench.
- **Risk:** a gorge next to a road makes players wonder if they can fall in; if the physics does not match what they see, it feels like a bug. The ground exception also touches how the world floor is built.
- **How to test:** in Studio Play, drive the bridge at several speeds and try to leave the deck sideways with a hop; check the camera at the chase and high views; check the kerb height against the car.
- **Lane 3 meanwhile:** a look-only gorge: the ground is cut 62 studs each side of the centre line for the length of the bridge (about 416 studs), a floor 70 studs below deck level, terraced walls, and truss supports standing on the floor. No collision at all (nothing stops a car or catches it). Details: `world-plan-dusty-highway.md` section 6.4.

### D2. A drive-through arch (proposal, NOT built)
- **Need from you:** the hop apex and the camera line (see S2/D4), and whether the team wants a gate the road passes through.
- **Benefit:** a gateway moment you drive through.
- **Risk:** a structure over the road can hide hazards and clash with the hop arc and the camera. Adam approved the safe version only: a thick arch beside the road (no part within 50 studs of the road edge).
- **How to test:** sweep the hop arc and both chase cameras through the opening at several speeds.
- **Lane 3 meanwhile:** builds the thick arch beside the road, turned toward oncoming cars, plus a small second arch. The drive-through version is only this note (plan section 6.3, "Option B": legs outside the verge, clearance of at least 60 studs).

### D3. Real speed, hop height and length
- **Need:** the real speed curve, and the hop height and length.
- **Benefit:** landmark spacing and approach views are tuned to real seconds, not the 70 studs per second fixture.
- **Risk:** if the real run is much faster or slower, landmarks may look too rare or too crowded.
- **How to test:** run the preview chase at the real speeds and re-time the approach (about 3.6 s for the last 250 studs at 70 studs per second).
- **Lane 3 meanwhile:** uses 70 studs per second (preview) and the plan's spacing of 300 to 440 studs between landmarks.

### D4. Scenery collision and the kerb wall
- **Need:** whether any scenery is solid, and the kerb or wall rule at the road edge.
- **Benefit:** the world edge feels real and consistent.
- **Risk:** invisible collision on rocks or cacti would feel unfair; no edge at all lets cars wander into scenery.
- **How to test:** drive along the verge at speed in Play.
- **Lane 3 meanwhile:** all scenery has no collision (preview).

### D5. Streaming owner and radius, and ground ownership
- **Need:** who builds and removes the scenery as the car moves (the active window), and how far.
- **Benefit:** a steady frame rate on phones; no pop-in.
- **Risk:** too small a radius shows pop-in; too large costs frames.
- **How to test:** run a long loop with the performance stats open; check the memory trend over three cycles.
- **Lane 3 meanwhile:** 1 road piece behind and 6 ahead, far mountains 2 behind and 14 ahead (preview), measured against the 8.2 ceilings in the plan.

### D6. Hazards: what they look like and the warning contract
- **Need:** the real hazard visuals and rules for the sinkhole, the sand drift and the rockslide, and whether warning boards ahead of a hazard are wanted.
- **Benefit:** hazards are readable on a pale desert.
- **Risk:** orange terrain makes hazard orange fragile; the pale sand drift is nearly the colour of the road.
- **How to test:** each hazard at five spots per district, camera 12 behind and 6 up; the hazard should keep at least 1.5 to 1 contrast against the road and the background.
- **Lane 3 meanwhile:** scenery previews of the three hazards with a dark rim on the drift, an orange-and-white wind-sock marker and a warning board 120 or more studs ahead (hazard-only look).

### D7. Traffic density
- **Need:** how many traffic cars and how big a share of the frame budget.
- **Benefit:** scenery and cars fit the phone budget together.
- **Risk:** the outline expects about 18 visible cars at 20 to 40 parts each (360 to 720 parts); scenery must leave that room.
- **How to test:** the performance run with traffic on.
- **Lane 3 meanwhile:** keeps scenery inside its ceilings (plan section 8.2).

## Summit Pass

### S1. Ski lift "Option M": chairs that pass over the road (proposal)
- **Need:** the hop apex number (how high a hop goes).
- **Benefit:** a moving lift crossing the road is the signature sight of the ridge.
- **Risk:** a moving object over the road at hop height could hide a hazard or look like a collision.
- **How to test:** sweep hop arcs under the crossing; run the preview with the crossing at 64, 72 and 80 studs high.
- **Lane 3 meanwhile (Adam's default):** the crossing span is **static**, at least 64 studs above the deck (the 26-stud span clearance is a preview value). Chairs only move on the legs at least 60 studs from the road edge.

### S2. Hop arc, run camera
- **Need:** the hop apex and arc, and the real run camera.
- **Benefit:** every overhead thing (spans, the lift, bunting) can be placed with confidence.
- **Risk:** an overhead piece too low would be hit by the hop arc in the camera's eyes.
- **How to test:** same sweep as S1 with the real camera.
- **Lane 3 meanwhile:** the preview chase cameras (12 behind and 6 up, FOV 70; high 18 and 10) and a 26-stud span clearance.

### S3. A tunnel segment type
- **Need:** whether the glacier tunnel is a real road segment type (wall, roof, bay length) and who owns its collision.
- **Benefit:** the tunnel is a real place, not a skin on a bridge.
- **Risk:** a roof and walls close to the road hide the way ahead and interact with the camera and hop.
- **How to test:** drive through at speed and hop inside it; check the camera against the roof.
- **Lane 3 meanwhile:** a look-only gallery of twelve 32-stud bays (116 studs clear across, at least 26 studs of clearance over the whole road) with sky windows and gallery openings; opaque, no collision.

### S4. Kerb wall and scenery collision
- **Need:** same as D4 for the snow: berms, rock cuts and fences at the road edge.
- **Benefit and risk:** as D4. **Test:** drive the berms and rock cuts at speed.
- **Lane 3 meanwhile:** no collision.

### S5. Streaming radius and the loop (lap)
- **Need:** the same streaming answer as D5, and the loop contract: what the HUD shows when the lodge ends and the village starts again.
- **Benefit:** the endless run has no visible seam.
- **Risk:** a seam at the loop point breaks the "endless" feel.
- **How to test:** run two full laps and look at the lodge-to-village join.
- **Lane 3 meanwhile:** the lodge flows straight into Pine Village (no arch or wall after the lodge). The "WELCOME TO SUMMIT PASS" span is on the first lap only; later laps show "KEEP CLIMBING!".

### S6. Hazards near a tunnel portal
- **Need:** whether a hazard may sit on the straight just before a portal.
- **Benefit and risk:** the portal's dark mouth can hide a hazard.
- **How to test:** place each hazard at 30, 60 and 120 studs before the portal.
- **Lane 3 meanwhile:** a "calm zone": no bunting and no glare patch within 24 studs of the road for 120 studs before any hazard; the planner never puts a hazard on the tunnel deck.

### S7. Real hazard rules for the frost crack, the ice patch and the snowbank
- **Need:** the real rules and visuals.
- **Benefit:** hazards read clearly against snow and ice.
- **Risk:** the lake and the glacier are big pale shapes that must not mimic the ice patch.
- **How to test:** desaturate and shrink ten frames; a reviewer who did not build them picks out the hazards.
- **Lane 3 meanwhile:** the ice patch is a crisp shape lighter than the road by at least 15 value points with a dark rim; the lake is matte and its cracks are pale on blue (the reverse of the hazard); orange appears only on the snowbank stakes.

### S8. Two-direction road
- Not proposed. Mentioned only so you know the plans assume one direction.

## Not for Brian R (Lane 2 items, listed so nothing is lost)
Adam will bring these to Brian L separately; they are not asked of you: district and World ids and display names in the shared catalogue (the district names also appear in `WorldRoutes.luau`, `Icons2.luau` and `Store.luau`), scenery vehicles (a later item that would use Brian L's finished cars), and car bounds and colours against snow.

## Replies

### Brian R
(Your AI answers here: for each item D1 to D7 and S1 to S8, accept, change or defer, and say what the real number is where one is asked.)
