# Claude skills: provenance, review, and precedence

Reviewed 2026-10-15. This file is the single place that explains which agent
skills the repository ships, where they came from, and how conflicts with
project rules are resolved.

## What is installed

| Group | Location | Owner | Count |
|---|---|---|---|
| Project workflows | `.claude/skills/project-*` | This team | 5 |
| roblox-brain domain skills | `.claude/skills/roblox-*` | Third party (MIT) | 29 |

Third-party source: https://github.com/TabooHarmony/roblox-brain, release
v2.3.1, commit `ceee4aaa5004502e2a51d78b3c33bba44d84742b`. License copied to
`.claude/skills/roblox-brain-LICENSE`; provenance in
`.claude/skills/roblox-brain-SOURCE.md`; install decision and update procedure
in `vault/decisions/0002-roblox-brain-skill-pack.md`. The upstream files are
unchanged. Do not edit them; project adaptations live in `AGENTS.md`,
`CLAUDE.md`, and this file.

Correction: an earlier draft of this file described an 11-skill subset that
omitted roblox-data, roblox-server-data, and roblox-collaboration-mode. The
committed state (decision 0002) is the full 29-skill pack. The conflicts that
motivated omitting those skills are handled by the precedence table below
instead of by deleting files. Removing a skill later is a reversible team choice.

## Precedence

1. The user's current instruction (within platform rules).
2. `AGENTS.md`, then `CLAUDE.md`.
3. Approved decisions in `vault/` (GDD, decisions, board).
4. Project workflow skills (`project-*`).
5. roblox-brain domain skills (`roblox-*`): API knowledge and patterns only.

A roblox-brain skill never decides process, initiative, scope, or monetization
for this team. `roblox-collaboration-mode` states that it "wins over domain-skill
framing"; in this repository it ranks below items 1 to 4 and is used only for its
risk classification (high-risk work needs explicit approval), which agrees with
our rules.

## Known conflicts and the project rule that applies

| Skill | Upstream guidance | Project rule |
|---|---|---|
| roblox-collaboration-mode | Load first on every task; sets initiative | Initiative follows `claude-context/02` creative authority and the project skills |
| roblox-collaboration-mode | Check "documented credential stores" for API keys | Never search for or read credentials unless the user asks; keys never enter the repo |
| roblox-data | Direct DataStore / UpdateAsync recipes; mentions ProfileService, DataStore2 | ProfileStore (vendored) is the only player-save path, one lifecycle module, Mock for tests |
| roblox-server-data | OrderedDataStore, MessagingService, MemoryStore recipes | Cross-server features are out of scope until approved; any DataStore call goes through a pcall wrapper module |
| roblox-studio-mcp | `multi_edit` / Edit-context script writes | Rojo-mapped scripts are edited on disk only; MCP is for inspection, playtests, and approved unsynced scene work |
| roblox-luau-types | Allows `--!nonstrict` / `--!nocheck` | Every first-party file starts with `--!strict` |
| several references | Legacy `wait()` / `spawn()` in examples | Use the `task` library; adapt cleanup to Trove, async to Promise, events to Signal |
| roblox-building | Blank uploaded assets usually mean Restricted permissions | Read the actual Output error and check permissions; do not assume |
| roblox-growth-design | FOMO and "real scarcity" products | Audience is mainly children: no coercive scarcity, FOMO, or dark patterns; monetization needs team approval |
| roblox-player-psychology | Streak hooks, gamepass price ladders, paid RNG tiers | Propose only, with player benefit and fairness; paid randomness follows current Roblox policy and per-player eligibility |
| roblox-monetization | Purchase implementation recipes | No purchases until the team approves a monetization design |
| roblox-publish-checklist | Release gates | Useful as a checklist; does not authorize publishing |
| roblox-game-design | Concept and loop design guidance | The game concept is undecided until the team chooses; do not pick or merge candidates |

Optional cross-references between skills are pointers, not evidence that a skill
was loaded or its checks performed. API names, limits, and MCP tool names in any
skill must be checked against current Roblox docs and the connected tools.

## Security review summary

The 29 upstream skills are Markdown only (`SKILL.md` plus `references/full.md`).
No hooks, `allowed-tools`, `!command` injection, executables, installers, or
MCP configuration were copied. Links point to documentation sites. This is a
scoped review of the pinned commit, not certification of every example or of
future upstream revisions.

## Updating

Review the upstream diff from the pinned commit before replacing any skill.
Preserve references and the license, update the commit here, in
`roblox-brain-SOURCE.md`, and in decision 0002, then re-run the skill probe in
`docs/SKILLS_GUIDE.md`. Re-check this conflict table after every update.
