# Verification report template

## Environment (as observed, not assumed)

- Repo path and commit:
- Rojo: serving? Studio connected?
- Studio MCP: available? tools seen:
- Target place (name / studio_id):
- Tools blocked (for example StyLua by Application Control):

## Results

| Req ID | Check | Status | Evidence |
|---|---|---|---|
| R1 | | runtime-tested | Output line "...", screenshot ... |
| R2 | | untested | reason |

Status vocabulary: implemented, inspected, build-checked, runtime-tested,
visually-reviewed, blocked, untested. Pick the strongest one you actually have
evidence for.

## Errors seen

| When | Message (exact) | New or pre-existing | Action |
|---|---|---|---|

## Not tested and why

- <item>: <reason>. Smallest next step: <step>.

## Manual steps for the user

1. <one action per step, with where to click or what to run>

## Cleanup

Temporary files and instances removed: <list, confirmed on disk and in Studio>
