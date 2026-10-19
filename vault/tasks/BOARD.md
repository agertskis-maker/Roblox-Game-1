---
title: Task Board
tags:
  - tasks
---

# Task Board

Claim a task by putting your name after it. Move it down as it progresses. Link to a decision note if the work involved a non-obvious choice.

## Lanes
Car Hop work is split into three lanes with separate paths ([[0007-concept-car-hop-and-lanes]]). Until a lane has a named owner, the repository owner is its owner (`AGENTS.md`).

| Lane | Owner | Paths |
|---|---|---|
| 1 Driving | TBD | `src/client/Run`, `src/shared/Run` |
| 2 Data & Economy | TBD | `src/server`, `src/shared/Catalog`, `src/shared/Net` |
| 3 World, UI & Feel | the repository owner (name to be filled in) | `src/client/UI`, `src/client/Home`, `src/shared/UI`, and the shared place's Workspace |

- Shared contracts (the catalog, the remotes, the save layout) are owned by Lane 2 and change only when all three lanes agree.
- Each developer connects Rojo only to their own private Studio test place, never to the shared Team Create place, except one integration person (TBD).
- Choosing the concept does not approve any propose-first item (Cash and the economy, paid items, cross-server data). Each still needs its own approval first.

## In progress
- [ ] Local build connection on the repository owner's machine: tools, packages, check, Rojo plugin file and Studio MCP are done and logged; Rojo Connect waits until the owner names their private test place (Rojo goes only to a private place, [[0007-concept-car-hop-and-lanes]]) - Claude Code at the repository owner's request ([[2026-10-18]])

## Up next
- [ ] Name the owners of Lane 1 and Lane 2, fill in the Lane 3 owner's name, and name the one integration person who may connect Rojo to the shared Team Create place ([[0007-concept-car-hop-and-lanes]])
- [ ] Each developer: make your own private Studio test place and connect Rojo only to it. Confirm whether the open "test1" place is the owner's private place or has Team Create on ([[2026-10-18]], [[0007-concept-car-hop-and-lanes]])
- [ ] Approve, change, or reject the proposed Studio MCP rules ([[0006-studio-mcp-rules]])
- [ ] Lane 1 Stage 0 (proposed: the outline's Stage 0 has no driving work): empty `--!strict` module skeletons in `src/client/Run` and `src/shared/Run`, and agree with Lane 2 what a run reports to the server (run seed, Hop, Claim, run end) so Lane 2 can draft the remotes. No gameplay yet; the run prototype is Stage 1 ([[car-hop-outline-v2]] section 15)
- [ ] Lane 2 Stage 0: the ProfileStore lifecycle module (the row below) with save schema v1 and Mock tests in `src/server`. Currency and economy fields are propose-first, and saved data needs a posted plan and an explicit go-ahead before coding ([[0007-concept-car-hop-and-lanes]])
- [ ] Lane 2 Stage 0: catalog skeleton in `src/shared/Catalog` (the shape of a car, World, upgrade price and mission template, placeholder values only) and remote names with argument types in `src/shared/Net`; the server validates every argument
- [ ] Lane 2 Stage 0: server code that gives a joining player a plot and frees it on leave, with the plot marker names agreed with Lane 3
- [ ] Lane 3 Stage 0: greybox island in the shared place's Workspace: central plaza, 12 plot markers with a spawn at each plot gate, a Portal row of three archways, the Garage building and the Stunt Circuit gate, all placeholders
- [ ] Lane 3 Stage 0: propose the visual direction and a representative sample for the owner's approval (fonts, touch-target size and the reduced-motion mechanism are still open); UI tokens go in `src/shared/UI` ([[0004-workflow-rules]])
- [ ] Stage 0 check, integration person TBD: a player joins, gets a plot, saves and loads an empty profile ([[car-hop-outline-v2]] section 15)
- [ ] Each teammate: run `rokit install`, `wally install`, and connect the Rojo plugin (see `AGENTS.md`)
- [ ] Build the player data module on ProfileStore (session start/end, template, kick on session loss)
- [ ] Agree on a naming/folder convention inside `src/shared`, `src/server`, `src/client`
- [ ] Each teammate: register the Studio MCP server, install the recommended editor extensions, open a new Claude Code session (see `docs/SKILLS_GUIDE.md`)
- [ ] At the concept meeting: set `GDD.md` to `status: selected` with `concept:` named and add a decision note, and assign area owners on this board ([[0004-workflow-rules]])
- [ ] Each teammate who will animate: install Blender 5.2 LTS, `uv`, the Blender MCP server and add-on once per machine, with safe mode on (see `docs/ANIMATION_PIPELINE.md` section 3, [[0005-animation-pipeline]])

## Backlog
- [ ] _add ideas here_
- [ ] Decide the reduced-motion mechanism with the visual direction, after the concept is chosen ([[0004-workflow-rules]])
- [ ] Decide where source `.blend` and exported `.fbx` art lives, and which account or group owns animations ([[0005-animation-pipeline]])
- [ ] Re-measure the runtime cost of 10-bone creatures on a phone or other low-end device; 800 copies held 60 fps on one desktop ([[0005-animation-pipeline]])

## Done
- [x] Agree on the game concept and fill in [[GDD]]: Car Hop selected by the team on 2026-10-18; `GDD.md` is `status: selected`, `concept: Car Hop`, summarised from [[car-hop-outline-v2]] - Claude Code at the repository owner's request ([[2026-10-19]], [[0007-concept-car-hop-and-lanes]])
- [x] Prepare car-hopping concept outline as PDF and Markdown for owner/Claude review - Codex; see [[car-hopping-game-outline]] and [[2026-10-18]]
- [x] Squash loop feel check: the repository owner watched the scale rig and the translation-bone rig side by side in a review place and judged the bounce, squish and speed right; a desktop cost check showed no difference up to 800 copies - Claude Code ([[2026-10-15]], [[0005-animation-pipeline]])
- [x] Free animation pipeline: Blender, Blender MCP with safe mode, Mesh2Motion, and a Studio import test, written up in `docs/ANIMATION_PIPELINE.md` - Claude Code at the repository owner's request. Nothing in it is concept-specific ([[2026-10-15]], [[0005-animation-pipeline]])
- [x] Set up shared code checks, editor support, and reviewed Claude skills — Codex; finished by Claude. First GitHub "Project checks" run passed, but no first-party Luau exists yet, so Selene and StyLua checked no files ([[2026-10-15]], [[0003-blocked-tool-exit-code]])
- [x] Create Claude project context pack and downloadable ZIP — Codex; see `claude-context/00_START_HERE.md` ([[2026-10-15]])
- [x] Project scaffold: Rokit, Rojo, Wally, vault ([[2026-10-14]])
- [x] Choose a ProfileStore source ([[0001-profilestore-source]])
