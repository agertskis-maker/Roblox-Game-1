---
title: "0006: Studio MCP rules"
date: 2026-10-18
tags:
  - decision
  - tooling
  - studio
status: accepted
---

# 0006: Studio MCP rules

> [!note] Accepted 2026-10-21, with changes
> Proposed by Claude Code at the repository owner's request on 2026-10-18. Adam approved it on 2026-10-21 ("Approved: the AGENTS.md \"Studio MCP\" section and decision 0006, with these changes"). The rules in force are the "Studio MCP" section of `AGENTS.md`, quoted under "Accepted rules" below; the proposal table is kept as history.

## Accepted rules (2026-10-21)
- The Roblox Studio MCP tools are used for inspection, playtests, console output and screenshots in your own private test place only, never the shared Team Create place.
- Never use `multi_edit` or `execute_luau` to create or change scripts that Rojo syncs. The files under `src/` are the only source of truth.
- No `generate_mesh`, `generate_material`, `generate_procedural_model`, `insert_asset` or `upload_image` without the owner's approval.
- Never publish the game or any shared place. A private personal test place (Team Create off, experience private) may be published only with the owner's explicit approval; record its place ID only in that person's own project file kept out of git, never in `default.project.json`.
- Rojo auto-reconnect only works in a published place (place ID not 0). A local `.rbxl` file always needs a manual Connect.
- Register the Studio MCP server per machine at user scope; the repository has no `.mcp.json`. Studio may sit behind other windows; screenshots come back blank while Studio is minimized (tested 2026-10-21).

Differences from the proposal: proposed rule 3's asset log and proposed rule 4 (no live player data) were not part of the approved text. Rule 4 is already covered by `AGENTS.md` ("Use `ProfileStore.Mock` for tests"). The publishing and auto-reconnect rules are new.

Why the publishing exception exists: Rojo 7.7.1 saves a reconnect address per place ID and skips place ID 0 (`plugin/src/ignorePlaceIds.lua`), so a local `.rbxl` file can never auto-reconnect.

## Proposal (2026-10-18, history)

For this and every future session that uses the Roblox Studio MCP tools:

| # | Proposed rule | Relation to existing rules |
|---|---|---|
| 1 | Never use `multi_edit` or `execute_luau` to create or change scripts in Studio. Every script, including a temporary test script, is a file under `src/` that Rojo syncs. | Extends `AGENTS.md` ("Rojo is the source of truth") and the `CLAUDE.md` override, which today cover Rojo-managed scripts only. |
| 2 | Use `execute_luau` and the other Studio tools only for reading the place, playtesting, screenshots, and (later, once approved) world building. | New. World building needs its own approval and is not granted by this note. |
| 3 | Never insert Creator Store assets, generate meshes, or upload images without asking the owner first. Log every asset used, with its source and rights. | New. Fits the `CLAUDE.md` rule not to assume asset permissions. |
| 4 | Never test against live player data. | Restates the `AGENTS.md` rule to use `ProfileStore.Mock`, and applies it to Studio playtests of a published place. |

Wording choices made by Claude, reversible, change them if you disagree:
- Rule 3 is read as covering every tool that adds outside content to the place: `insert_asset`, `generate_mesh`, `generate_texture`, `generate_material`, `generate_procedural_model`, and `upload_image`. You wrote "generate meshes"; this is the wider reading.
- "Log" in rule 3 means a line in that day's `vault/log/` entry (asset id or name, source, license or rights).

## Why
- A script changed inside Studio is overwritten by the next Rojo sync, skips Selene and StyLua, and never reaches Git or review.
- `execute_luau` and `multi_edit` can change anything in the open place. If that place is the shared Team Create place, teammates see it immediately. The tools do not enforce any limit, so the rule is the only guard.
- Creator Store, generated, and uploaded assets carry rights, moderation, and child-safety questions, and an upload leaves the machine. The team should choose each one.
- Live player data is real children's progress. Tests must not read or change it.

## Limits
- These are conventions followed by the agent, not tool permissions. Nothing stops a call; a reviewer reading the session catches a breach.
- Whether Studio can reach live DataStores for a published place depends on a game setting ("Studio access to API services") that this session did not read. Check it before any data work.

## Applied
2026-10-21: the "Studio MCP" section added to `AGENTS.md` and `status` set to `accepted`. Not yet done: refreshing `claude-context/09_PROJECT_RULES_SNAPSHOT.md` and `10_DECISION_REGISTER.md` (both already behind `AGENTS.md`), and changing `project-studio-verification`, whose setup command still registers the server at local scope.

## Reverting
Delete this note. If it was approved and applied, also remove the `AGENTS.md` section.
