---
title: "0012: Figma-first workflow for Lane 3 UI"
date: 2026-10-20
tags:
  - decision
  - ui
  - workflow
status: accepted
---

# 0012: Figma-first workflow for Lane 3 UI

## Decision (approved by Adam, Lane 3 owner and repository owner, 2026-10-20)
"Approved: Figma-first UI workflow for Lane 3."

Every **new or changed** Lane 3 screen, panel, HUD element or popup follows this order:
1. **Plan the screen**: purpose, entry and exit, every state (loading, empty, locked, can't afford, pending, success, error) and what every button does, to the standard in `claude-context/04_VISUAL_UI_AND_GAME_FEEL.md`.
2. **Mock it in Figma**, in one shared file named **"Car Hop UI"**: one page per screen, with frames for phone portrait, phone landscape and 1080p desktop. A panel opened during play is drawn as an overlay on a gameplay view. Colours, spacing, corner radius and stroke are Figma variables that match the shared UI token module, `src/shared/UI/Tokens.luau`.
3. **Write the build spec at the same time**, in the repository at `vault/design/ui/<screen-name>.md`: every size, position, colour token, font, state, button behaviour and animation timing, plus the Figma link. The build reads this file, not Figma.
4. **Review**: Adam gets the Figma link and a summary, and approves or asks for changes. The approval is recorded in `vault/design/visual-direction.md`.
5. **Read from Figma only if Adam says he edited the mockup by hand.** Before any read, report how many reads this month have been used ([[figma-reads]]).
6. **Build in Luau by hand from the spec.** Figma's generated code targets websites and iPhone apps, not Roblox, so it is never pasted into the game.
7. **Images**: any image drawn in Figma that the game needs is exported, listed in the asset manifest (`vault/design/assets.md`), and uploaded only with Adam's approval. Asset IDs are never invented. The visual-reference rules in `AGENTS.md` apply (style traits yes; copied logos, characters, icons or near-identical screens no).

Scope: Lane 3 UI work only. Lane 1 and Lane 2 teammates do not need a Figma account; they read the spec files in `vault/design/ui/`. Work approved before this decision (the run HUD, revision 4, approved 2026-10-20) is not redrawn now; it goes through this workflow the next time it changes.

## Why
- Better, more consistent UI: every screen is designed against the same tokens, at the same three sizes, before any code exists.
- Adam can review a design visually, and change it, before anything is built.
- The repository spec keeps the build reproducible and readable by every teammate and tool without a Figma account.

## Plan limits and how this workflow avoids them
Source: Figma's official Claude Code plugin, version 2.2.157, README (installed 2026-10-20).
- **Reads are capped.** "Rate limits apply to Figma MCP server tools that read data from Figma. Some tools, such as those that write to Figma files, are exempt." On the Starter (free) plan the cap is "up to 6 tool calls per month."
- **How the workflow stays under it:** the build reads the spec in the repository, never Figma. No read is used to check a write; Adam checks the mockup by opening the Figma link. Figma's own skills suggest taking a screenshot after drawing; `get_screenshot` is a read, so it is not used. A read happens only after Adam says he edited the mockup by hand, and the running count in [[figma-reads]] is reported first.
- **Which tools count as reads** is not listed tool by tool. Until Figma documents it, treat every tool that returns file content as a read: `get_design_context`, `get_metadata`, `get_screenshot`, `get_variable_defs`, `get_libraries`, `search_design_system`, `get_figjam`, the Code Connect "get" tools, `whoami`, and any `use_figma` script that only inspects the file.
- **Writing is free only during the beta.** The same README: "The write to canvas feature will eventually be a usage-based paid feature, but is currently available for free during the beta period." Nothing is bought and the plan is not upgraded without Adam.
- Other free-plan limits (file and page counts) were not checked.

## Revisit when
- the read cap is hit, or the workflow needs more reads than the cap allows;
- Figma's pricing or limits change, including writes becoming paid;
- a teammate needs access to the Figma file (sharing, seats or a team plan).

## Consequences
- The Figma file belongs to Adam's own Figma account. The repository spec is the build source; if the two disagree, the spec wins until Adam says otherwise.
- `src/shared/UI/Tokens.luau` stays the source of truth for tokens. Figma variables mirror its names and values; a token change is made in the module first (by the build), then mirrored in Figma.
- The Figma MCP server is registered on Adam's machine only, through the plugin `figma@claude-plugins-official` (user scope, local Claude Code configuration, not in Git).
- Skills changed: `project-visual-direction` and `project-feature-delivery` (and their Codex copies in `.agents/skills/`). Rule line in `AGENTS.md`, "Visual references and UI styling".
