---
title: "0002: roblox-brain skill pack"
date: 2026-10-15
tags:
  - decision
  - tooling
  - agents
status: accepted
---

# 0002: roblox-brain skill pack

## Decision
Commit the **roblox-brain** agent skill pack into the repo at `.claude/skills/` so every teammate's agent gets the same Roblox guidance without installing anything. It is a verbatim, flattened copy of upstream, pinned to one commit.

| | |
|---|---|
| Upstream | https://github.com/TabooHarmony/roblox-brain |
| Release / commit | v2.3.1, `ceee4aaa5004502e2a51d78b3c33bba44d84742b` (2026-10-14) |
| Contents | 29 skills, each `SKILL.md` + `references/full.md` (60 files incl. license and source note) |
| License | MIT, copied to `.claude/skills/roblox-brain-LICENSE` (required when redistributing) |
| Copied by | plain `cp -r`, not `npx skills add`, so no third-party installer code runs |

## Audit (2026-10-15)
Read before installing. Findings:
- **Pure Markdown.** Under `skills/` there is nothing but `SKILL.md` and `references/full.md`. No plugin code, no executables, no symlinks.
- **No execution hooks.** Frontmatter uses only `name`, `description`, `when_to_use`, `last_reviewed`, `sources`. No `allowed-tools`, `hooks`, `context: fork`, or `` !`cmd` `` injection.
- **Nothing hidden.** No zero-width/bidi characters, no HTML-comment instructions, no encoded blobs, no curl/wget/pipe-to-shell, no instructions to hide actions from the user.
- **Links** are documentation sites only (create.roblox.com, devforum.roblox.com, luau.org, GitHub raw docs).
- **Upstream scripts are not installed.** `scripts/*.py` are contributor validators (they fetch public docs and, in CI, run `luau-compile` on code fences). They are not part of the skills and are not copied here.
- **Provenance.** Single maintainer, 152 commits, MIT, repo created 2026-05-27. It changes fast (several releases on 2026-10-15), which is why we pin.

Two things worth knowing, neither a blocker:
- `roblox-collaboration-mode` tells the agent to load first on every Roblox task and sets how much initiative to take. It is conservative (high-risk work needs explicit approval), but it does shape behaviour. `AGENTS.md` states that project rules win over any skill.
- The same skill says to check "documented credential stores" for an API key before asking the user again, while never printing the value. Keep real keys out of the repo regardless.

## Consequences
- **We own updates.** Nothing upgrades this automatically. To update: clone upstream at the new tag/commit into a scratch directory, re-read the diff against `.claude/skills/` (new files and frontmatter keys especially), replace the `roblox-*` folders, update the commit in this note and in `.claude/skills/roblox-brain-SOURCE.md`.
- **Do not edit the copied skills.** Local guidance goes in `AGENTS.md`. If a skill ever needs a patch, list it here so the next update does not drop it.
- Skills can disagree with our rules (they describe generic Roblox practice; we require ProfileStore-only saving). `AGENTS.md` wins.
- The pack is ~1 MB of text. Agents load only the short `SKILL.md` descriptions up front and open `references/full.md` on demand.

## Reverting
Delete `.claude/skills/roblox-*`, `.claude/skills/roblox-brain-*`, and the "Agent skills" section of `AGENTS.md`.
