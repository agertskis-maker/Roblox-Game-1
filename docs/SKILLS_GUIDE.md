# Project skills guide

How the team uses the five Claude workflow skills in this repository. For where
the third-party skills came from and how conflicts are resolved, see
`docs/CLAUDE_SKILLS_REVIEW.md`. Rules in `AGENTS.md` win over any skill.

## The five skills

Each skill lives in `.claude/skills/<name>/SKILL.md`. The name below is exactly
what you type after the slash.

| Skill | Activates automatically when | Run it yourself |
|---|---|---|
| `project-feature-intake` | You paste a brain dump or a long ChatGPT/Codex build prompt, ask for a prompt review, or a prompt conflicts with `AGENTS.md`, the vault, or the undecided concept | `/project-feature-intake vault/design/specs/daily-reward-prompt.md` (or paste the prompt text after the name) |
| `project-visual-direction` | A request includes reference images, asks for a look, mood, or style, or adds a new screen, region, or reward moment | `/project-visual-direction shop screen` |
| `project-feature-delivery` | You authorize building or changing gameplay, UI wired to gameplay, economy, or saved data ("build this", "implement the spec", "add saving for") | `/project-feature-delivery vault/design/specs/daily-reward.md` |
| `project-studio-verification` | After implementing anything, when you ask to test or playtest, diagnose a Studio error, or check that Rojo synced a file | `/project-studio-verification smoke test` |
| `project-team-handoff` | You finish, pause, or switch work, or ask for the board, log, post-pull steps, or commits to be prepared | `/project-team-handoff daily reward task` |

Automatic activation is Claude's judgment from each skill's description, so it
can miss. When the workflow matters, type the slash command; it always loads
the skill. The text after the name is passed to the skill as its argument.

## Usual order

1. **Intake** turns a prompt into a requirement ledger and asks the questions
   that change the result.
2. **Visual direction** (only if the feature has a look) turns references into
   one direction and proves it on a small sample.
3. **Delivery** builds the approved player journey in playable increments.
4. **Verification** proves it with the tools the session really has and reports
   what was not tested.
5. **Handoff** updates the board and log, lists what teammates must do, and
   proposes commit groups.

Skip a step that does not apply (a pure logic change has no visual direction).
Verification and handoff are not optional for work you intend to merge.

## Approvals and planning

These rules apply to everyone and live in `AGENTS.md` (reasoning in
`vault/decisions/0004-workflow-rules.md`):

- "Owner" is the repository owner until the team assigns area owners on the
  board at the concept meeting; area owners then approve samples and plans for
  their area.
- A one-line "Approved: ..." counts when it clearly refers to a specific
  request, spec, or ledger; if it is ambiguous which, you will be asked. One
  reply may grant both a propose-first approval and a plan go-ahead if it says
  both, for example "Approved, go ahead."
- A concept is selected only when `vault/design/GDD.md` has `status: selected`
  and `concept:` naming it, plus a decision note. An "Approved:" on a feature
  never selects one.
- Concept-agnostic foundations, starting with the ProfileStore lifecycle
  module, may start before the concept is chosen. Anything touching saved data
  still needs the plan posted and an explicit go-ahead (the gates stack).
- A new currency or other economy field is propose-first: it needs approval
  after the agent presents benefit, cost, risk, and a test. That includes a
  last-claim timestamp for a currency reward.
- Delivery always posts a short plan before coding, and waits for your
  go-ahead only when the work touches saved data or schemas, the economy,
  monetization, or shared contracts or interfaces. A bare "Build X" gets a
  short intake, then the plan.
- Agents ask every question whose answer changes the result, in one batch, and
  decide reversible details themselves.
- When a precondition fails (no selected concept, an unapproved propose-first
  item, a missing approval), the agent posts the questions plus a conditional
  plan (what it would do once each answer arrives) and implements nothing until
  the precondition is met.
- If another session already wrote board or log entries for the same work, the
  agent reads them first, merges rather than duplicates, never rewrites their
  text, and says it built on them.
- Branches: `main` is fine for docs, vault, skills, and tooling. From the first
  game-code task, each person works on a feature branch and merges to `main` by
  pull request after the GitHub check passes. Branch protection is not enforced
  yet.

## Where skills work

- **Claude Code in the terminal**, started inside this repository folder.
- **The Code tab of the Claude desktop app**, opened on this repository folder.

Skills are read from `.claude/skills/` in the working folder, so they do not
exist in a plain claude.ai chat or a claude.ai Project. Those surfaces only see
what you upload; the `claude-context/` pack is the uploadable background for
them and contains no skills.

Check that they loaded by typing `/skills` in a Claude Code session. If a
project skill is missing, you are probably outside the repo folder, or you
pulled new skills and need to open a new session.

## What you get by pulling

Everything below is in Git, so a pull gives it to you:

- The five `project-*` skills and the 29 third-party `roblox-*` skills.
- `AGENTS.md` and `CLAUDE.md` (the rules the skills defer to).
- `claude-context/` reference pack, `docs/`, and the shared vault
  (`vault/tasks/BOARD.md`, `vault/log/`, `vault/decisions/`).
- `scripts/check.ps1`, the GitHub check workflow, and editor settings in
  `.vscode/`.

A pull does not install tools, packages, plugins, or your Studio connection.
Those are per machine (next section).

## What each teammate configures once

| Step | Command or action | Why it is not in Git |
|---|---|---|
| Tools | `rokit install` | Installs the pinned Rojo, Wally, Selene, StyLua on your machine |
| Packages | `wally install` | `Packages/` is generated and git-ignored |
| Rojo plugin | `rojo plugin install`; if it cannot find Studio, put `Rojo.rbxm` from the matching release in `%LOCALAPPDATA%\Roblox\Plugins` and restart Studio | The plugin lives in your Studio |
| Rojo connection | `rojo serve`, then Connect in the plugin | Per Studio session |
| Studio MCP for Claude | In PowerShell, from the repo folder: `claude mcp add Roblox_Studio -- cmd.exe /c "cd /d %LOCALAPPDATA%\Roblox && .\mcp.bat"`, then restart Claude Code | Registered in your local Claude config, private to you and tied to this project |
| Editor extensions | Install the ones in `.vscode/extensions.json` | Per editor install |

Register the Studio MCP server once, in local scope (the default). A second
entry in user scope with a different command causes a "Conflicting scopes"
warning; check yours with `claude mcp get Roblox_Studio`.

Run `./scripts/check.ps1` from PowerShell after meaningful source edits. Exit
codes: **0** every check ran and passed; **1** a check failed or a tool is
missing; **2** nothing failed but the OS blocked a tool such as StyLua, so its
check did not run. Exit 2 is incomplete, never a pass; the GitHub run covers
the blocked check.

In a Team Create session, a Rojo-synced test script appears for everyone in the
place. Tell the others before you create one, and remove it when done.

## Codex

Codex reads `.agents/skills/`, not `.claude/skills/`, and this repository does
not provide that folder. Codex users rely on `AGENTS.md` for the rules, and can
open a project skill's `SKILL.md` directly when they want its workflow. The
shared Studio MCP entry for Codex is in `.codex/config.toml`.
