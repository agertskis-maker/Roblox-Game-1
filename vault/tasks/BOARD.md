---
title: Task Board
tags:
  - tasks
---

# Task Board

Claim a task by putting your name after it. Move it down as it progresses. Link to a decision note if the work involved a non-obvious choice.

## Lanes
Car Hop work is split into three lanes with separate paths ([[0007-concept-car-hop-and-lanes]]). Owners named by Adam on 2026-10-19; each lane owner approves samples and plans for their lane (`AGENTS.md`).

| Lane | Owner | Paths |
|---|---|---|
| 1 Driving | Brian R | `src/client/Run`, `src/shared/Run` |
| 2 Data & Economy | Brian L | `src/server`, `src/shared/Catalog`, `src/shared/Net` |
| 3 World, UI & Feel | Adam (repository owner) | `src/client/UI`, `src/client/Home`, `src/shared/UI`, and the shared place's Workspace |

- Lane 3 owns the run HUD's presentation; Lanes 1 and 2 supply its state and keep ownership of gameplay and authoritative data ([[2026-10-19]]).

- Shared contracts (the catalog, the remotes, the save layout) are owned by Lane 2 and change only when all three lanes agree.
- Each developer connects Rojo only to their own private Studio test place, never to the shared Team Create place, except one integration person (TBD).
- Choosing the concept does not approve any propose-first item (Cash and the economy, paid items, cross-server data). Each still needs its own approval first.

## In progress
- [ ] Local build connection on the repository owner's machine: tools, packages, check, Rojo plugin file and Studio MCP are done and logged; Rojo Connect waits until the owner names their private test place (Rojo goes only to a private place, [[0007-concept-car-hop-and-lanes]]) - Claude Code at the repository owner's request ([[2026-10-18]])
- [ ] Lane 3 visual direction sample: first car, Downtown road slice, and responsive HUD - Adam, with Claude Code. Order: HUD first (approved by Adam 2026-10-20, revision 4; merged to `main` by pull request #1), then the first car (in planning: revised vehicle direction, proposed rarity guide and one Common starter car; the earlier Pip direction is superseded, not approved for this car), then the Downtown scene, each stopping for Adam's approval. Covers the Lane 3 Stage 0 visual-direction row; branches `feature/lane3-visual-sample` (HUD, merged) and `feature/lane3-first-car-downtown`; built and tested only in the owner's private test place, never the shared Team Create place ([[0007-concept-car-hop-and-lanes]])
  - [ ] Car session closed without a handoff (seen 2026-10-21, read-only): `feature/lane3-first-car-downtown` (`9347ef2`) is not pushed, and the `Roblox-Game-1` checkout holds uncommitted car work (the `carkit.py` FBX unit-scale fix and two car sections of the 2026-10-20 log, including the 14 uploaded mesh asset IDs). Hand it off in a car session - Adam
    - Update 2026-10-21 (island session, Adam approved): the two files were committed as `f309ea2` and the branch was pushed to origin with all 3 commits. The Figma edits, `.playwright-mcp/` and the place file are still uncommitted there, as Adam asked
- [ ] Lane 3 Stage 0 island base and draft plot-marker contract - Adam, with Claude Code. Measured layout and visual proposal first, then construction only after Adam's go-ahead, in stages (measured layout, representative art sample, full base), each stopping for Adam's review. Covers the "Lane 3 Stage 0: greybox island" row under "Up next", built as a preview from Git-tracked recipes in a private island-only place (`CarHop-Island-Test.rbxl`), never the shared Team Create place. The plot-marker contract is a draft for Brian L (Lane 2) to agree; no plot assignment, saving, economy or gameplay. Branch `feature/lane3-island-base` in the separate worktree `Roblox-Game-1-island`. Status 2026-10-20: Stage A built and measured in the private place, waiting for Adam's review ([[island-base]]). Status 2026-10-21: layout superseded by the island rework below; Stage A stays on this branch as history
- [ ] Lane 3 island rework, Task 1: layout and spatial validation, then a walkable greybox - Adam, with Claude Code. A half-circle hub: six plots facing a central park, three portals across the straight side, lake, waterfall and mountains behind. Layout proposal first; greybox only after "Approved: island layout — build the greybox."; detailed environment only after "Approved: island greybox." Private island place only (`CarHop-Island-Test.rbxl`), never the shared Team Create place; no plot assignment, saving, economy or speed changes. Branch `feature/lane3-island-rework` in the worktree `Roblox-Game-1-island`, from `feature/lane3-island-base` (`7b8e8f5`, not merged). Status 2026-10-21: layout proposal posted, waiting for Adam ([[island-rework]], [[draft-0013-six-plot-half-circle-island]])
  - Status 2026-10-21 (later): Adam approved the layout and the greybox ("Approved: island layout, build the greybox, with 6 plots, in my private place only"); Garage and Stunt gate walking spread accepted as a relaxed Tunable target. Greybox being built in the private place from `src/island/Hub` (the Stage A build stays available as the switch-back)
  - Status 2026-10-21 (13:30): greybox built and walked in the private place (all 36 routes reached; side portals 2.08 and 2.09 s best to worst against 2 s, for Adam). Waiting for Adam's review; detailed environment only after "Approved: island greybox." ([[2026-10-21]])
  - [ ] Brian L (Lane 2): agree to the plot-contract change from 8 to 6 plots (Max Players at most 6, new plot positions and facing, marker names unchanged). **Pending**; Adam sends the message drafted in [[2026-10-21]]. Until Brian agrees, [[0011-eight-plots-per-server]] stands for Lane 2 ([[draft-0013-six-plot-half-circle-island]], [[plot-marker-contract]])
- [ ] Lane 3 island rework, Task 2: environment and base-level dressing - Adam, with Claude Code. Intake only (ledger IRW-30 to IRW-55 in [[island-rework]]); waits for "Approved: island greybox" and the questions in [[2026-10-21]]. Private island place only; no portals, merge, publish or uploads
  - Status 2026-10-21: "Approved: island greybox."; step 1 (environment) in progress on `feature/lane3-island-environment` (from `b8b9ee4`), stopping for "Approved: island environment, continue dressing."
  - Status 2026-10-21 (16:30): environment built and checked in the private place; waiting for "Approved: island environment, continue dressing." ([[2026-10-21]], [[0014-island-environment-generation]])
  - Status 2026-10-21 (evening): Adam approved the environment (Atmosphere A) and decision 0014, and authorised original Blender meshes and images uploaded under peskaface for this task. Revision in progress (waterfall system, lake, vegetation, wildlife, park dressing; ledger IRW-56 to IRW-81); one review at the end, before the representative plot
- [ ] Figma-first UI workflow for Lane 3 (setup and documentation only; no screen designed): decision, skills, `AGENTS.md` line and read counter done; Figma sign-in on the owner's machine pending - Adam, with Claude Code ([[0012-figma-ui-workflow]], [[2026-10-20]])

## Up next
- [ ] Brian R and Brian L: optional hands-free Rojo setup on your own machine with your own private test place (steps in [[2026-10-21]]); publishing that place needs Adam's approval first ([[0006-studio-mcp-rules]])
- [ ] Adam's PC, after the car session is finished: repeat the hands-free setup for `CarHop-Lane3-Test.rbxl` (steps in [[2026-10-21]])
- [ ] Follow-up to [[0006-studio-mcp-rules]] (Adam asked to keep it for later, 2026-10-21): change `project-studio-verification` (both `.claude` and `.agents` copies) to register the Studio MCP server at user scope (`claude mcp add --scope user Roblox_Studio -- cmd.exe /c %LOCALAPPDATA%Robloxmcp.bat`) and point it at the "Studio MCP" section of `AGENTS.md`; refresh `claude-context/09_PROJECT_RULES_SNAPSHOT.md` (verbatim `AGENTS.md`, already behind) and `claude-context/10_DECISION_REGISTER.md`
- [ ] Name the one integration person who may connect Rojo to the shared Team Create place (lane owners are named above) ([[0007-concept-car-hop-and-lanes]])
- [ ] Each developer: make your own private Studio test place and connect Rojo only to it. Confirm whether the open "test1" place is the owner's private place or has Team Create on ([[2026-10-18]], [[0007-concept-car-hop-and-lanes]])
- [ ] Lane 1 Stage 0 (proposed: the outline's Stage 0 has no driving work): empty `--!strict` module skeletons in `src/client/Run` and `src/shared/Run`, and agree with Lane 2 what a run reports to the server (run seed, Hop, Claim, run end) so Lane 2 can draft the remotes. No gameplay yet; the run prototype is Stage 1 ([[car-hop-outline-v2]] section 15)
- [ ] Lane 2 Stage 0: the ProfileStore lifecycle module (the row below) with save schema v1 and Mock tests in `src/server`. Currency and economy fields are propose-first, and saved data needs a posted plan and an explicit go-ahead before coding ([[0007-concept-car-hop-and-lanes]])
- [ ] Lane 2 Stage 0: catalog skeleton in `src/shared/Catalog` (the shape of a car, World, upgrade price and mission template, placeholder values only) and remote names with argument types in `src/shared/Net`; the server validates every argument
- [ ] Lane 2 Stage 0: server code that gives a joining player a plot and frees it on leave, with the plot marker names agreed with Lane 3
- [ ] Lane 3 Stage 0: greybox island in the shared place's Workspace: central plaza, 12 plot markers with a spawn at each plot gate, a Portal row of three archways, the Garage building and the Stunt Circuit gate, all placeholders
- [ ] Stage 0 check, integration person TBD: a player joins, gets a plot, saves and loads an empty profile ([[car-hop-outline-v2]] section 15)
- [ ] Each teammate: run `rokit install`, `wally install`, and connect the Rojo plugin (see `AGENTS.md`)
- [ ] Build the player data module on ProfileStore (session start/end, template, kick on session loss)
- [ ] Agree on a naming/folder convention inside `src/shared`, `src/server`, `src/client`
- [ ] Proposal, needs Brian R, Brian L and Adam to agree: add a shared `ServerStorage` root to `default.project.json` for server-only build data and models, starting with the island build recipes: `"ServerStorage": { "$className": "ServerStorage", "Island": { "$path": "src/island" } }`, as a sibling of `ServerScriptService`. ServerStorage is never sent to players, and Rojo leaves the rest of ServerStorage alone (an entry without `$path` ignores instances it does not know). The car models will need the same server-only home later. Until the team decides, the island session uses a stopgap project file outside the repository (`Car-Hop-Art/island-preview.project.json`) for its private place only, deleted once the team decides ([[island-base]], [[0007-concept-car-hop-and-lanes]])
- [ ] Each teammate: register the Studio MCP server, install the recommended editor extensions, open a new Claude Code session (see `docs/SKILLS_GUIDE.md`)
- [ ] At the concept meeting: set `GDD.md` to `status: selected` with `concept:` named and add a decision note, and assign area owners on this board ([[0004-workflow-rules]])
- [ ] Each teammate who will animate: install Blender 5.2 LTS, `uv`, the Blender MCP server and add-on once per machine, with safe mode on (see `docs/ANIMATION_PIPELINE.md` section 3, [[0005-animation-pipeline]])

- [ ] Lane 3 HUD checks still open after approval (not passed): real phones and phone performance; the player's own Roblox Reduce Motion setting; the 378 to 398 px one-row range on screen; the HUD over the real road and chase camera (Downtown scene review) ([[visual-direction]], [[2026-10-20]])
- [ ] Update the stale header comment in `src/shared/UI/Tokens.luau`: it still says colours, spacing, radii, strokes and motion timings are pending Adam's review, but the HUD was approved on 2026-10-20. Code change, so on a feature branch ([[visual-direction]], [[2026-10-20]])

- [ ] Give every teammate collaborator access to the now-private repository; on 2026-10-20 it listed two accounts, the owner and one teammate ([[0009-private-repository]])

## Backlog
- [ ] _add ideas here_
- [ ] Decide the reduced-motion mechanism with the visual direction, after the concept is chosen ([[0004-workflow-rules]])
- [ ] Decide where source `.blend` and exported `.fbx` art lives, and which account or group owns animations ([[0005-animation-pipeline]])
- [ ] Re-measure the runtime cost of 10-bone creatures on a phone or other low-end device; 800 copies held 60 fps on one desktop ([[0005-animation-pipeline]])

## Done
- [x] Hands-free Rojo syncing and background Studio MCP access on Adam's PC - Adam, with Claude Code. Rojo 7.7.1 (plugin matches); Studio MCP at user scope only; Adam's island test place published as a private place (Team Create off) so Rojo auto-reconnect works; Auto Reconnect on, Confirmation Behavior "Unlisted PlaceId" with the place ID only in Adam's own project file outside Git; zero-click reconnect and live sync tested 2026-10-21. Teammate steps in [[2026-10-21]] ([[0006-studio-mcp-rules]])
- [x] Studio MCP rules: approved by Adam on 2026-10-21 with changes (publishing exception for a private personal test place, auto-reconnect note); now the "Studio MCP" section of `AGENTS.md` ([[0006-studio-mcp-rules]])
- [x] Make the repository private (GitHub Free: no branch protection on `main`; the `main` rules are kept by our own workflow; Actions minutes now count against the private quota) - Adam ([[0009-private-repository]], [[2026-10-20]])
- [x] Lane 3 HUD stage of the visual sample (ENGINE HEAT panel, Cash counter, Distance B), approved by Adam on 2026-10-20 at revision 4; tested in Studio's Device Simulator only, open items are under "Up next" - Adam, with Claude Code ([[2026-10-19]], [[2026-10-20]], [[visual-direction]])
- [x] Agree on the game concept and fill in [[GDD]]: Car Hop selected by the team on 2026-10-18; `GDD.md` is `status: selected`, `concept: Car Hop`, summarised from [[car-hop-outline-v2]] - Claude Code at the repository owner's request ([[2026-10-19]], [[0007-concept-car-hop-and-lanes]])
- [x] Prepare car-hopping concept outline as PDF and Markdown for owner/Claude review - Codex; see [[car-hopping-game-outline]] and [[2026-10-18]]
- [x] Squash loop feel check: the repository owner watched the scale rig and the translation-bone rig side by side in a review place and judged the bounce, squish and speed right; a desktop cost check showed no difference up to 800 copies - Claude Code ([[2026-10-15]], [[0005-animation-pipeline]])
- [x] Free animation pipeline: Blender, Blender MCP with safe mode, Mesh2Motion, and a Studio import test, written up in `docs/ANIMATION_PIPELINE.md` - Claude Code at the repository owner's request. Nothing in it is concept-specific ([[2026-10-15]], [[0005-animation-pipeline]])
- [x] Set up shared code checks, editor support, and reviewed Claude skills — Codex; finished by Claude. First GitHub "Project checks" run passed, but no first-party Luau exists yet, so Selene and StyLua checked no files ([[2026-10-15]], [[0003-blocked-tool-exit-code]])
- [x] Create Claude project context pack and downloadable ZIP — Codex; see `claude-context/00_START_HERE.md` ([[2026-10-15]])
- [x] Project scaffold: Rokit, Rojo, Wally, vault ([[2026-10-14]])
- [x] Choose a ProfileStore source ([[0001-profilestore-source]])
