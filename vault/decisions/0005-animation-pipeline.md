---
title: "0005: free animation pipeline (Blender, Mesh2Motion, translation bones)"
date: 2026-10-15
tags:
  - decision
  - animation
  - tooling
status: accepted
---

# 0005: free animation pipeline (Blender, Mesh2Motion, translation bones)

## Decision
The repository owner asked for a free animation pipeline that works without
paid tools and without any game-specific content. Recorded choices:

| # | Choice | Applied in |
|---|---|---|
| 1 | Free tools only: Blender 5.2 LTS for keyframes, Mesh2Motion for rigs and a CC0 animation library, Rojo to build a local test place. No paid animation tools or assets without owner approval. | `AGENTS.md` "Animation"; `docs/ANIMATION_PIPELINE.md` |
| 2 | Rigid props (eggs, chests, pickups, simple pets) and UI are animated in code with tweens or springs. Skinned characters and creatures use keyframed bones. | `docs/ANIMATION_PIPELINE.md` section 1 |
| 3 | Squash and stretch on a skinned creature uses translation-only deform bones, never bone scale. Mesh2Motion rigs need the same extra bones if we want squash on them. | section 4 |
| 4 | Blender MCP always runs with `BLENDER_MCP_SAFE_MODE=1` and `DISABLE_TELEMETRY=true`. If safe mode blocks a step, stop and tell the owner; do not turn it off. Stop the Blender server when unused. | `AGENTS.md`; section 3 |
| 5 | Studio imports use a local test place, with "Upload to Roblox" unticked. Publishing an animation needs owner approval, and the animation must be owned by the user or group that owns the experience. | `AGENTS.md`; sections 6 and 9 |
| 6 | Test files (`.blend`, `.fbx`, `.rbxl`) stay outside the repo until the team decides where source art lives. | section 11 |

## Why
Roblox bones are driven by a `CFrame`, which has no scale. Tested on
2026-10-15 with the real importer: a Blender rig that squashed by scaling a bone
imported with no scale data at all, and the child bones still moved as if the
parent had squashed (a head sank into the body). The same motion rebuilt from
translation bones imported with every key intact and bent the mesh in Roblox.
Details and numbers are in `docs/ANIMATION_PIPELINE.md` section 7.

## Alternatives considered
- Animate scale and accept no squash: rejected, the head dips into the body.
- Squash the whole creature in code with a spring: fine for rigid props, used
  there, but it cannot bend a skinned body.
- One side-bone ring plus a top bone: rejected after a visible ledge on landing
  (largest vertex error about 8% of height, against 3% for two rings).
- Paid or account-linked tools (Roblox Blender plugin, cloud upload APIs):
  not used; they need an account link or API key and upload data.

## Consequences
- Rigs with squash have about 3x the bones and about 3x the keys of a scale
  rig. Runtime cost in Roblox was not measured.
- Skinning needs care: at most 4 influences per vertex, no weight on the root,
  and small parts such as eyes skinned rigidly.
- Mesh2Motion exports must use the **Unity** FBX preset to arrive upright, face
  +Z (turn them 180 degrees for Roblox's -Z front), and need Blender's native
  FBX reader.
- Teammates install Blender, `uv`, the MCP server and the add-on once per
  machine. None of it is in Git.

## Not yet verified
- A person watching the loop and judging feel.
- Runtime cost of many animated creatures.
- Publishing and animation ownership (docs only).
- The Codex MCP setup.

## Reverting
Delete `docs/ANIMATION_PIPELINE.md`, the "Animation" section of `AGENTS.md`,
and this note. Nothing else depends on them.
