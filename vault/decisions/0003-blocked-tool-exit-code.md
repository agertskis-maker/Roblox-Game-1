---
title: "0003: blocked local tools exit 2, not 0"
date: 2026-10-15
tags:
  - decision
  - tooling
  - checks
status: accepted
---

# 0003: blocked local tools exit 2, not 0

## Decision
`./scripts/check.ps1` exits **2** when nothing failed but a tool (for example StyLua) was blocked by the operating system and its check did not run. Exit 0 means every check ran and passed. Exit 1 means a check failed or a tool is missing. In CI (`GITHUB_ACTIONS` or `CI` set) a blocked tool is a failure (exit 1).

Approved by the repository owner during the setup session on 2026-10-15.

## Why
StyLua is blocked on at least one teammate machine by Windows Application Control (Smart App Control). The script's blocked-tool probe caught it, so the formatting check never ran locally. Reporting that as a pass would hide an unrun check.

Alternatives rejected:
- **Exit 0 with a warning.** A blocked tool reads as a pass in the terminal, in scripts, and in agent reports.
- **Exit 1.** The script would be unusable on a machine where one tool is blocked, hiding the Selene and Rojo results that did run.

## Consequences
- A local exit 2 means "incomplete, not a pass". Say so in handoffs and verification reports (`project-studio-verification`, `project-team-handoff`).
- The GitHub "Project checks" run is the authority for blocked tools. The workflow has to be observed passing before the check is called verified.
- Anyone changing the exit codes must update the header of `scripts/check.ps1`, the two skills above, and this note.

## Reverting
Make the blocked branch in `scripts/check.ps1` exit 0. Not recommended: it removes the signal that a check did not run.
