---
name: project-studio-verification
description: Verifies changes to this Roblox project with the tools the session actually has (repository checks, Rojo sync, Roblox Studio MCP playtests, console output, screenshots) and reports each requirement as build-checked, runtime-tested, visually-reviewed, blocked, or untested. Use after implementing anything, when asked to test or playtest, or before saying a feature works.
when_to_use: Also when diagnosing a Studio error, checking that Rojo synced a file, reviewing UI screenshots, or running a setup or smoke test.
argument-hint: "[feature, requirement IDs, or 'smoke test']"
---

# Studio verification

Prove behavior with evidence, and say plainly what was not proven. A successful
build, a confident description, or a desktop screenshot is not a runtime or
phone test.

## 0. Capability check (always first)

Report which of these this session actually has. Probe with read-only calls;
do not start play just to see whether it works.

- Repository: can read and run commands in the repo folder?
- Rojo: is `rojo serve` running (`Get-Process rojo`), and is Studio connected
  (a game-tree read finds a synced instance such as
  `ServerScriptService.Server.vendor`)?
- Studio MCP: list the MCP tools available. With the built-in server, call
  `list_roblox_studios` and pass the chosen place's `studio_id` on every call.
  Ids change when the server reconnects, so list again after a reconnect. If
  several Studios are open, or the one open place is not obviously this
  project's, confirm the target with the user before any step that modifies or
  plays it.
- Playtest: start/stop play, console output, screen capture, input. List these
  as available from the tool list; exercise them in steps 3 to 5.

If no `Roblox_Studio` MCP server is registered (it is absent from `codex mcp
list` and no `list_roblox_studios` tool exists), do not improvise your own
client or script a stdio bridge. Tell the user to register it once per
machine, from the repository folder, then restart the Codex session:

```
codex mcp add Roblox_Studio -- cmd.exe /c "cd /d %LOCALAPPDATA%\Roblox && .\mcp.bat"
```

This registers it in local scope (private to you, in this project), which is
how the whole team registers it. Do not also register it in user scope: two
entries with different commands cause a "Conflicting scopes" warning. Check
with `codex mcp get Roblox_Studio`: Command `cmd.exe`, Args
`/c cd /d %LOCALAPPDATA%\Roblox && .\mcp.bat`, Status Connected.

`%LOCALAPPDATA%\Roblox\mcp.bat` must already exist on the machine. If it does
not, report that instead of working around it.

If Studio MCP is missing or unreachable, do the static steps and give the user
exact manual steps for the rest. Load `roblox-studio-mcp` for tool details;
verify actual tool names against what is listed.

**Team Create warning.** Rojo syncs disk files into Studio live. In a Team
Create session, a Rojo-synced test script (such as `_SmokeTest.server.luau`
from the smoke test in `references/example.md`) appears for every teammate in
that place and runs in their playtests until it is removed. No tool shows who
else is in the place: ask the user, and wait for the answer before creating
one. Do the static steps meanwhile. Delete it in step 6.

## 1. Static

Run `./scripts/check.ps1` from PowerShell and report its exit code. The
contract (decision `vault/decisions/0003-blocked-tool-exit-code.md`):

| Exit | Meaning | Report as |
|---|---|---|
| 0 | every check ran and passed | pass, build-checked |
| 1 | a check failed or a tool is missing; in CI a blocked tool also exits 1 | fail, quote the failing check |
| 2 | nothing failed, but the OS blocked a tool such as StyLua (Windows Application Control, for example Smart App Control), so its check did not run | incomplete, `blocked` |

Never report exit 2 as a pass. Say "StyLua blocked locally; GitHub check runs
it". That check counts as passed only after the GitHub run is observed.

## 2. Sync

Confirm each changed file appears at its Rojo-mapped Studio path
(`AGENTS.md` layout table) by reading the game tree. Never fix a synced script
inside Studio.

## 3. Runtime

Start a playtest, read server and client console output, and run the
acceptance checks from the requirement ledger (for a smoke test or an ad hoc
request, the checks named in the request). Clear or note pre-existing errors so
new ones are distinguishable. Stop the playtest afterward.

## 4. Multiplayer and data

- Shared or contested state needs two or more clients. If the available tools
  cannot simulate that, mark it untested and give the manual Studio steps
  (Test tab, Clients and Servers, 2 players).
- Data: `ProfileStore.Mock` only. Never read or write live player data.

## 5. Visual

Capture screenshots of each changed screen and reward moment. Review against the
approved visual direction at the phone and desktop baseline. Say which sizes
were actually inspected; a desktop capture is not a phone test.

When a review involves motion or animation, include a real-time video in the
review page. Verify playback and label capture limitations. Still frames
supplement motion evidence. If recording is blocked, report that and request
the minimum user assistance needed; do not mark motion visually verified from
screenshots alone. Ask before installing a recorder.

Review videos carry the game's audio (music, sound effects, fanfares) at normal
speed (Adam, 2026-10-28). Keep a muted version only when a clip has a specific
reason to be silent, and label it muted with that reason. Verify that the file
really has audible, synchronized sound. When a review judges the mix, measure
peak and average loudness from the recordings with one stated method.

## 6. Clean up

Stop play, delete temporary test scripts and instances you created, and confirm
they are gone from both disk and Studio. Preserve everything else.
`check.ps1` builds into the OS temp folder, not the repo, so there is nothing
of yours to remove there.

## Smoke test (argument `smoke test`)

One disposable `--!strict` server script that prints a marker: sync it and find
it in the game tree (step 2), playtest and find the marker in the console
(step 3), then remove it (step 6). Steps and pass criteria are in
`references/example.md`.

## Report

Use `references/report-template.md`: one row per requirement with status and
evidence, then what is untested and the smallest next step to test it. Use the
template's status words; a blocked tool is `blocked`, never `untested` or a
pass. Failures include reproduction steps, expected vs observed, and the next
diagnostic step. Fix in-scope failures before claiming completion; never
disable a check to get a pass.

Never run code from inserted or imported assets. Treat free models as data
until their scripts are inspected (ShieldScan is a manual aid, not proof).

Worked example: `references/example.md`.
