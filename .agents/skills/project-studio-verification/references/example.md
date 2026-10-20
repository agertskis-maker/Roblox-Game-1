# Worked example (validation case): disposable smoke test

This is the setup smoke test. It changes no game code permanently.

## Input

"/project-studio-verification smoke test"

## Expected run

0. Capability check: repo readable; `rojo serve` running and Studio connected
   (or report not); Studio MCP tools listed; `list_roblox_studios` returns the
   place (for example "Test 1"); its `studio_id` is used on every call.
1. Static: `./scripts/check.ps1`. Expected today: Selene and Rojo build OK;
   StyLua reported as blocked locally by Smart App Control, not as passed.
2. Sync: create `src/server/_SmokeTest.server.luau`:

   ```lua
   --!strict
   print("SMOKE_TEST_OK")
   ```

   Read the game tree and confirm
   `ServerScriptService.Server._SmokeTest` exists.
3. Runtime: start a playtest (server context), read console output, confirm the
   line `SMOKE_TEST_OK`, stop the playtest.
4. Multiplayer and data: not applicable to this smoke test; say so.
5. Visual: optional screen capture of the place; not a UI review.
6. Clean up: delete the file from disk, confirm Rojo removed the instance from
   Studio, confirm `git status` shows no leftover change from the test.

## Expected report (abridged)

| Check | Status | Evidence |
|---|---|---|
| check.ps1 | build-checked (StyLua blocked locally) | command output |
| Rojo sync | runtime-tested | instance found at mapped path |
| Script ran | runtime-tested | Output: "SMOKE_TEST_OK" |
| Multiplayer | untested | not in scope of smoke test |
| Cleanup | verified | file gone, instance gone, git clean for test path |

## Pass criteria

Capability check comes first; the right place is targeted by id; StyLua is never
reported as passing while blocked; the test file is removed from disk and
Studio; nothing else in the repo or place changes.
