@AGENTS.md

# Claude workflows

Project skills live in `.claude/skills/` and are shared through Git. Use the
matching project workflow; each can also be run by typing its name:

| Skill | Use for |
|---|---|
| `/project-feature-intake` | Turning a brain dump or long build prompt into a requirement ledger |
| `/project-visual-direction` | Reference images, look and feel, UI system, world, lighting, motion, sound |
| `/project-feature-delivery` | Building an approved player journey end to end |
| `/project-studio-verification` | Testing in Studio and reporting what was and was not verified |
| `/project-team-handoff` | Board, log, decision notes, and next steps for teammates |

Usual order for a feature: intake, visual direction (if it has a look), delivery,
verification, handoff. Reference material is in `claude-context/`; read the
relevant file when a skill points to it rather than loading the whole pack.
Full guide: `docs/SKILLS_GUIDE.md`.

## Third-party skill precedence

Order: current user instruction, AGENTS.md, this file, approved vault decisions,
project skills, then roblox-brain skills. roblox-brain skills supply Roblox API
knowledge and patterns; they never set process, initiative, scope, or
monetization here, even where a skill says it wins (roblox-collaboration-mode).
The conflict table is in `docs/CLAUDE_SKILLS_REVIEW.md`. The main overrides:

- Edit Rojo-managed scripts on disk, even if a Studio skill illustrates script
  mutation through MCP. Inspect Studio and test there using available tools.
- ProfileStore is mandatory for player saves. Use the vendored server copy,
  one lifecycle owner, kick on failed acquisition, and Mock for tests. Do not
  implement direct player DataStore examples from generic reference material.
- Every first-party Luau file starts with --!strict. Adapt illustrative manual
  cleanup, retry, and event code to this project's Trove, Promise, and Signal.
- The audience is mainly children. Do not apply FOMO, coercive scarcity, streak
  pressure, or paid-luck tactics from growth or psychology skills; monetization
  and paid randomness need an approved team design and current Roblox policy.
- Do not search for or read credentials unless the user asks. Keys never go in
  the repository.
- Cross-server data (MemoryStore, MessagingService, OrderedDataStore) is out of
  scope until approved; any DataStore call goes through a pcall wrapper module.
- The game concept is undecided until the team chooses. Design skills do not
  authorize picking, merging, or building a candidate concept.
- Confirm the actual tool schemas, engine APIs, place settings, and asset
  permissions. Skill timestamps and example tool names do not prove availability.
  In particular, do not assume blank assets mean Restricted permissions.
- Cross-references to uninstalled skills are optional pointers, not evidence
  that those skills were loaded or their checks performed.
- Skill checklists do not authorize publishing, purchases, data changes, or
  overwriting teammates' work. Report verification evidence accurately.
- Approval, propose-first, plan-before-coding, and question rules are in
  AGENTS.md ("Approvals and planning"). roblox-brain skills do not loosen them.

## Repository checks

Run `./scripts/check.ps1` from PowerShell after meaningful source edits. It checks
strict directives, Selene, StyLua, and a Rojo build without rewriting sources.
Studio behavior needs separate testing. If a tool is blocked or unavailable,
report that limitation; never treat a skipped check as passing.

## Motion review evidence

When a review involves motion or animation, include a real-time video in the
review page. Verify playback and label capture limitations. Still frames
supplement motion evidence. If recording is blocked, report that and request
the minimum user assistance needed; do not mark motion visually verified from
screenshots alone. Ask before installing a recorder.
