---
title: "0016: Frameless World portal rendering"
date: 2026-10-22
tags:
  - decision
  - island
  - portals
  - vfx
status: proposed
---

# 0016: Frameless World portal rendering

> [!note] Proposed with the Task 3 review
> Written by Claude Code for Adam (Lane 3 owner) on 2026-10-22, during island rework Task 3, while Adam was asleep (silent mode). It is accepted with "Approved: island rework"; until then the method may change at the review. Ledger rows IRW-111 to IRW-120 in [[island-rework]]; log [[2026-10-22]].

## Decision
- **The field is layered soft SurfaceGuis on 5 invisible carriers**, spread over about 3.8 studs of depth, plus particles. It is about 20 x 30 studs and floats 2.5 studs above its pad (`src/island/Hub/Environment/PortalRig.luau` places the anchors; `src/client/Home/Island/Portals.client.luau` draws everything on the client).
  - Back: an aura and a soft depth oval.
  - Recess: an unlit band (Brightness 1, not additive), so the rim reads darker and the centre looks recessed.
  - Middle: two cloud bodies, two counter-rotating spirals, a darker counter spiral (the "tunnel"), three inflow rings that shrink toward the core, and a pink accent.
  - Front: a small core and a sliding sheen.
  - The outer carriers carry mirrored sets, so the portal also works from behind.
- **Particles give volume**: soft camera-facing glow, inward motes (LockedToPart on a turning host), sparkles, embers, a burst every 9 to 16 s (open portals only), 3 wide coloured glow-column beams, a ground pool and a point light.
- **Grazing-angle fade**: each flat layer fades out within about 30 degrees of edge-on, so no carrier edge or thin bright sliver shows from the side.
- **Lock pieces are part-built until the mesh import.** The chain, padlock and anchor-post meshes are in `island-kit-task3.obj` but not uploaded. A preview mesh does not reach a playtest, so the lock uses part-built pieces (267 parts per lock, against about 70 with meshes). The Studio attribute `Lane3PortalLockParts` forces the part-built pieces for comparison.
- **The lock is presentation only.** It reads `src/client/Home/Island/PortalPreviewState.luau`, which takes a Studio-only attribute `Lane3PortalLocked_<World>`. It is local to each player. It changes no shared state, saved data or server collision. Lane 2 supplies the real unlock state later.

## Why
- **No frame.** Adam's brief asks for no frame of any kind, including a thick luminous border (IRW-28). A single textured disc or a ring would read as a frame or a flat rectangle.
- **Depth.** One flat sheet looks flat at an angle. The first gate round showed Summit Pass shrinking to a sliver from the side. Layers at different depths give parallax, and the unlit band makes the centre look like an opening.
- **Rear view.** Players can walk round the portals. Mirrored outer sets keep the back from showing a blank or reversed face.
- **The gate reviews shaped the layers.** Round 1 read it as a fireball (no recess, flow outward, no pink). Round 2 still showed an oversized white core and a too-faint band. Round 3 passed items 13, 14, 16 and 18: the core is about 15 % of the height, the rim darker, and the flow goes inward ([[2026-10-22]], `Car-Hop-Art/review/task3/gate-review-1.md`).
- **Part-built fallback.** Without it the locks would be plain white boxes in a playtest until someone clicks the 3D Importer. The importer needs UI clicks, and that step was blocked in this session.
- **Presentation-only lock.** The unlock rule and requirement values are not decided and belong to Lane 2. A local preview state lets Lane 3 build and test the look without inventing a contract.

## Known limits
- Far range is open: from the six entrances (about 270 studs) the portals are small, and the yellow Stunt-gate block and white paths are brighter (gate round 3, `r3-far-e1.jpg`).
- Minor gate findings: the pink reads lilac, the lower rim is slightly smoky, the pool streaks from the side, and the rear was not re-captured after round 3.
- Cost: 5 carriers and several emitters per portal. A camera budget rests a portal beyond 420 studs or off screen beyond 40 (emitters off, 4 Hz updates). Frame time was not measured (Studio unfocused at 15 fps).

## Reverting
The greybox disc, halo, chains, padlock and lock sign in `Hub/Recipes/Park.luau` are skipped only when the park is dressed (the pad stays), so they return with the dressing off. `PortalRig.luau`, `Portals.client.luau` and `PortalPreviewState.luau` are new in Task 3; git history has the state before them.
