---
title: Task Board
tags:
  - tasks
---

# Task Board

Claim a task by putting your name after it. Move it down as it progresses. Link to a decision note if the work involved a non-obvious choice.

## In progress
- [ ] _nothing yet_

## Up next
- [ ] Agree on the game concept and fill in [[GDD]]
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
- [ ] Measure the runtime cost of 10-bone creatures with many on screen, and have a person watch a squash loop and judge its feel ([[0005-animation-pipeline]])

## Done
- [x] Free animation pipeline: Blender, Blender MCP with safe mode, Mesh2Motion, and a Studio import test, written up in `docs/ANIMATION_PIPELINE.md` - Claude Code at the repository owner's request. Nothing in it is concept-specific ([[2026-10-15]], [[0005-animation-pipeline]])
- [x] Set up shared code checks, editor support, and reviewed Claude skills — Codex; finished by Claude. First GitHub "Project checks" run passed, but no first-party Luau exists yet, so Selene and StyLua checked no files ([[2026-10-15]], [[0003-blocked-tool-exit-code]])
- [x] Create Claude project context pack and downloadable ZIP — Codex; see `claude-context/00_START_HERE.md` ([[2026-10-15]])
- [x] Project scaffold: Rokit, Rojo, Wally, vault ([[2026-10-14]])
- [x] Choose a ProfileStore source ([[0001-profilestore-source]])
