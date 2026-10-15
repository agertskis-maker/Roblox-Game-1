# Worked example (validation case): closing out a cut-off tooling session

A previous session lost its connection before writing a handoff. The work
changes tooling, skills, and docs only; it changes no game code. Run this as a
dry run: gather facts and draft the text, but do not edit, commit, or push.

## Input

"/project-team-handoff finish the setup work from the session that dropped"

## Starting state the facts should show

- Branch `main`, same commit as `origin/main`; working tree has modified
  tracked files (`AGENTS.md`, `CLAUDE.md`, `.gitignore`, the board) and many
  untracked paths: `.github/`, `scripts/`, `.vscode/`, `.codex/`, `docs/`,
  `claude-context/`, `context/`, `.claude/skills/project-*`, `vault/.obsidian/`.
- `vault/tasks/BOARD.md` has an in-progress row owned by someone else
  ("... — Codex").
- Today's `vault/log/YYYY-MM-DD.md` already exists with another session's entry,
  and the dropped session had already written a board follow-up and a log
  section for this same work.
- `./scripts/check.ps1` exits 2: StyLua is blocked by Windows Application
  Control; Selene and the Rojo build pass.
- A GitHub Actions workflow file exists; it has not run remotely.
- No `.agents/skills/` folder; the Studio MCP server is registered locally only.

## Expected output (abridged)

Facts first: the commands above, with branch, commits, and the list of changed
and untracked paths grouped by area. Date taken from the system.

Board: the in-progress row keeps "— Codex". It moves to Done only if its
acceptance evidence exists; here CI has not run, so it stays in progress with
"remaining: confirm the GitHub run, StyLua check". Nothing else on the board is
reworded or reordered.

Log: a new section appended below the existing entry, with the earlier text
untouched. It names the task and who did the work. The dropped session's board
follow-up and log section are read first and merged, not duplicated or
rewritten: the new entry adds only what they lack and says it built on them.

Decision note: one, for the non-obvious choice "a blocked local StyLua exits 2
and is never reported as a pass". No notes for file lists or routine config.

Configured versus run:

| Item | Level |
|---|---|
| Selene, Rojo build | ran, exit 0 portions of check.ps1 |
| StyLua | blocked locally, not a pass |
| GitHub workflow | configured, not verified until the run is observed |
| Studio MCP server | configured on this machine, ran `list_roblox_studios` |

Teammate steps after pulling: `rokit install` (new Selene and StyLua pins),
install recommended editor extensions, register the Studio MCP server with the
exact `claude mcp add` command, open a new Claude Code session to load the
skills. `wally install` and Rojo reconnect: "none" (manifest and project file
unchanged), said explicitly.

Commit groups (shown, not executed):

| # | Message | Paths |
|---|---|---|
| 1 | Add shared lint, format, and CI checks | `.github/`, `scripts/`, `.vscode/`, `.gitignore` |
| 2 | Add project workflow skills | `.claude/skills/project-*` |
| 3 | Document skills, Claude context, and team rules | `docs/`, `claude-context/`, `context/`, `AGENTS.md`, `CLAUDE.md` |
| 4 | Update board, log, and vault config | `vault/` (not `workspace.json` or `graph.json`) |

These groups contain no game code, so they may go to `main`. Game code would
go on a feature branch with a pull request merged after the GitHub check passes.

Ends with "awaiting your OK to commit; nothing pushed" and the next action.

## Pass criteria

Facts come from git output, not recall; the original owner's name is kept; the
existing log entry is not rewritten; entries another session already wrote for
this work are read first, merged rather than duplicated, left unedited, and
acknowledged as built on; exactly the non-obvious choice becomes a
decision note; a blocked tool is reported blocked, never passed (a clean exit 0
is reported as ran, noting that no Luau was linted when none exists); the
workflow is "configured" until a remote run is observed; every post-pull step is listed or
explicitly "none"; commits are grouped by purpose, game code (if any) is
steered to a feature branch and pull request, and nothing is committed, pushed,
or merged without authorization.
