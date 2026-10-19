---
title: "0006: Studio MCP rules (PROPOSED, not approved)"
date: 2026-10-18
tags:
  - decision
  - tooling
  - studio
status: proposed
---

# 0006: Studio MCP rules (PROPOSED, not approved)

> [!warning] Not approved
> Proposed by Claude Code at the repository owner's request on 2026-10-18. Until the owner replies with an explicit "Approved", `AGENTS.md` and the skills are unchanged and nothing below is a rule.

## Proposed decision
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

## If approved
Add a short "Studio MCP" section to `AGENTS.md`, refresh `claude-context/09_PROJECT_RULES_SNAPSHOT.md` (verbatim `AGENTS.md`) and `claude-context/10_DECISION_REGISTER.md`, point `project-studio-verification` at it, and change `status` here to `accepted` with the approval date.

## Reverting
Delete this note. If it was approved and applied, also remove the `AGENTS.md` section.
