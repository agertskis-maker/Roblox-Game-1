# Handoff template

Fill every field. Write "none" or "unknown (reason)" instead of deleting a line.
Base this on the handoff format in `claude-context/08_PROMPT_AND_HANDOFF_TEMPLATES.md`.

## Header

- Task and owner (board row, original owner's name unchanged):
- Done by (person or tool, if different from the owner):
- Date (from the system):
- Branch, base commit, current commit (from `git branch -vv` / `git log`):
- Teammate commits fetched but not merged:

## Requirement statuses

| Req ID | Requirement | Status | Level | Evidence |
|---|---|---|---|---|
| R1 | | implemented / inspected / build-checked / runtime-tested / visually-reviewed / blocked / untested | configured / reported / ran / verified | command and output, screenshot, run URL |

Use the ledger's IDs when one exists; otherwise number the items yourself and
say the source (a brief, a message, a board row).

## Files and interfaces changed

Grouped by area of the `AGENTS.md` layout table. Name any remote, module API,
data template field, or contract another teammate depends on.

## Decisions

- Non-obvious choices and the note that records them (`vault/decisions/NNNN-...`):
- Choices left open and who decides:

## Assets and manual Studio steps

Assets, uploads, or scene edits that exist only in someone's Studio or account,
and who has them. Say "not in git" where that is true.

## Checks and tests

| Check | Command | Result | Level |
|---|---|---|---|
| | | exit code and key output | ran |

### Not run, and why

- <item>: <reason>. Smallest next step: <step>.

## Teammate steps after pulling

- [ ] `rokit install`: needed? yes / no (rokit.toml changed?)
- [ ] `wally install`: needed? yes / no (wally.toml or wally.lock changed?)
- [ ] Restart `rojo serve` and reconnect the Rojo plugin: needed? yes / no
- [ ] Rojo plugin reinstall: needed? yes / no
- [ ] Register the Studio MCP server, from the repo folder (`claude mcp add Roblox_Studio -- cmd.exe /c "cd /d %LOCALAPPDATA%\Roblox && .\mcp.bat"`): needed? yes / no
- [ ] New Claude Code session so skills reload: needed? yes / no
- [ ] Editor extensions (`.vscode/extensions.json`): needed? yes / no

## Known limitations and open questions

-

## Suggested commit groups

| # | Message | Paths | Why together |
|---|---|---|---|
| 1 | | | |

Do not commit: <paths>. Nothing is pushed or merged until the user authorizes it.

## Exact next useful action

<one action, who does it, where>
