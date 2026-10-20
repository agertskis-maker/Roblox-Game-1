# Delivery checklist

## Before writing code

- [ ] Spec or ledger approved; concept selected
- [ ] Task claimed on the board
- [ ] `git status`, branch, ahead/behind, teammate changes inspected
- [ ] Existing modules and Rojo mapping inspected
- [ ] Shared contract written if another module or teammate depends on it

## Remote contract (one row per remote)

| Remote | Direction | Arguments (types, limits) | Server validation | Result sent back | Rate limit |
|---|---|---|---|---|---|

## Data changes

| Field | Type | Default (template) | Migration needed? | Mock test |
|---|---|---|---|---|

## Failure table (state the outcome, not "handle it")

| Condition | Desired outcome | How tested |
|---|---|---|
| Duplicate tap while pending | No double grant; UI stays responsive | |
| Two players act on the same target | Exactly one succeeds; other sees clear result | |
| Malformed or out-of-range argument | Rejected, no state change, logged | |
| Insufficient resources | Rejected with clear UI message | |
| Stale target (gone or changed) | Rejected, UI refreshes | |
| High latency | Pending state, then reconcile to server result | |
| Player leaves mid-action | Outcome follows the documented rule | |
| Respawn / character reset | State and UI consistent | |
| Server shutdown | Profiles end cleanly via BindToClose | |
| Save fails or session lost | Player kicked or retried per ProfileStore rules; no silent loss | |

## UI state inventory (per screen)

Loading, populated, empty, unavailable, locked (with reason), affordable,
unaffordable (not color alone), pending, success, rejected, retry, long names,
large numbers, narrow phone screen, controller focus if in scope.

## Done means

- [ ] Every required ledger item implemented or explicitly deferred
- [ ] `./scripts/check.ps1` run (report any blocked tool, never as a pass)
- [ ] Studio verification done and reported by status
- [ ] Placeholders listed
- [ ] Handoff written
