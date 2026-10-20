---
name: project-team-handoff
description: Closes out a unit of work in this Roblox project so a teammate or the next agent can resume without the chat history, using facts read from git, the board, a dated vault log entry, decision notes for non-obvious choices, an honest configured-versus-actually-run record, post-pull steps for teammates, and suggested commit groups. Use when finishing, pausing, or switching work, or before committing, pushing, or opening a pull request.
when_to_use: Also for "write the handoff", "update the board", "log this", "what do teammates need to do after pulling", "prepare the commits", or when a session is ending or lost its connection mid-task.
argument-hint: "[task name or board item]"
---

# Team handoff

Leave the repository, board, and log in a state someone else can resume from
without reading the chat. Record what is true, from git and command output, not
from memory. A handoff documents work; it never authorizes pushing, merging, or
publishing.

## 1. Gather facts first

Before writing a word, run and read:

- `git status --short`, `git branch -vv`, `git log --oneline -n 10`,
  `git diff --stat` (and `--cached`). Note base commit and current commit.
- If the remote is reachable, `git fetch` (updates remote-tracking refs only,
  changes no working files), then `git log HEAD..origin/<branch> --oneline` for
  teammate commits you lack. If you skip it, say the remote state is unknown.
- Today's date from the system (`Get-Date -Format yyyy-MM-dd`), not assumed.
- The result of checks you ran this session, with exit codes. Re-run a check
  rather than quote an earlier summary.

Anything you cannot establish is written as "unknown" with the reason.

If another session already wrote board or log entries for this work, read them
first and merge rather than duplicate: add only what they lack, never rewrite
their text, and say in your entry that you built on them.

## 2. Update `vault/tasks/BOARD.md`

- Read the live file first; teammates edit it.
- Move only the items this work touched. **Keep the original owner's name** on
  an item even when someone else finished it; who did the work goes in the log.
- Done items link the log date and any decision note, as the existing rows do.
- Never reword, reorder, or delete another person's item. Follow-ups go under
  "Up next" without an owner.
- Move to Done only when the acceptance evidence exists; otherwise leave the
  row where it is, unedited, and put what remains in the log plus a new
  unowned item under "Up next".

## 3. Append to `vault/log/YYYY-MM-DD.md`

- File exists: append a new section at the end. Do not rewrite, reorder, or tidy
  earlier entries; they belong to other people and sessions, including any
  entries another session wrote for this work (see section 1).
- File missing: create it with `title`, `date`, and `tags: [log]` frontmatter.
  File exists without `date` or section headings: append your level-2 section
  anyway and leave its frontmatter alone.
- Heading names the task and who did the work. Body is the handoff in
  `references/handoff-template.md`, condensed to what a reader needs.
- `vault/00_INDEX.md` lists log days and decision notes: append the link for
  any you add, and change nothing else in it.

## 4. Decision notes only for non-obvious choices

Add `vault/decisions/NNNN-short-title.md` (next unused number, format of
`0001`/`0002`) when a future teammate would plausibly question or undo the
choice: a picked option over another, a deviation from a default or skill, an
accepted limitation. Not for file lists, routine edits, or what git history
already shows. Link it from the log and the board row.

## 5. Separate configured from actually run

Every claim in the handoff has one of these levels, and the level is written:

| Level | Meaning |
|---|---|
| configured | the file or setting exists; nothing executed it |
| reported | another person or earlier session says it ran; you did not re-run it |
| ran | command executed this session; exit code and key output quoted |
| verified | observed in the real environment (Studio playtest, GitHub run) |

Use the status words of `project-studio-verification`. A `check.ps1` exit code
of 2 is "blocked tool, not a pass". A workflow file is "configured"; CI is
"verified" only after the remote run is observed (`gh run watch`). Each
not-run item gets a reason and the smallest next step.

## 6. What teammates do after pulling

List only steps the diff makes necessary, and say "none" when none apply:

| The pull changes | Teammate does |
|---|---|
| `rokit.toml` | `rokit install` |
| `wally.toml` or `wally.lock` | `wally install` |
| `default.project.json` or the `src/` layout | restart `rojo serve`, press Connect in the Rojo plugin |
| Rojo version | reinstall the plugin (`rojo plugin install`, or place `Rojo.rbxm` in `%LOCALAPPDATA%\Roblox\Plugins`), restart Studio |
| Studio MCP needed | from the repo folder, once per machine: `codex mcp add Roblox_Studio -- cmd.exe /c "cd /d %LOCALAPPDATA%\Roblox && .\mcp.bat"`; check with `codex mcp get Roblox_Studio` |
| `.agents/skills/` | open a new Codex session in the repo folder; check `/skills` |
| `.vscode/extensions.json` | install the recommended editor extensions |

## 7. Suggest commit groups; never push on your own

- Group by purpose, each reviewable alone and passing checks where it can:
  tooling and CI, skills, docs, vault records, game source. Do not mix feature
  code with tooling.
- Per group give the message, exact paths, and why they belong together. Flag
  paths that must not be committed: build outputs, `Packages/`,
  `ServerPackages/`, per-user Obsidian state (`workspace.json`,
  `workspace-mobile.json`, `graph.json`, as `.gitignore` lists them),
  `.claude/settings.local.json`, anything that looks like a key. Shared vault
  config (`app.json`, `appearance.json`, `core-plugins.json`) is committable.
- Show the groups and wait. Commit only after the user agrees. Push, merge,
  open a pull request, or publish only after separate explicit authorization;
  approval to commit is not approval to push.
- Branches: docs, vault, skills, and tooling may go to `main`. For game code
  (`src/`), suggest a feature branch and a pull request merged only after the
  GitHub check passes (`AGENTS.md`).
- Never force-push, reset, amend others' commits, or discard teammates'
  uncommitted work to get a clean tree.

## Report

Fill every field of `references/handoff-template.md`; write "none" or "unknown"
instead of skipping. End with the exact next useful action and who owns it.

Worked example: `references/example.md`.
