---
name: project-feature-delivery
description: Builds an approved player journey in this Roblox project end to end, with server-authoritative logic, validated remotes, client UI feedback for every state, ProfileStore saving where relevant, and explicit failure handling, delivered in playable increments. Use when the user authorizes implementing or changing gameplay, UI wired to gameplay, economy, or saved data.
when_to_use: Also for "build this", "implement the spec", "wire up this screen", "add saving for", or finishing a prototype to the intended standard. Not for reviews (use project-feature-intake) or concept selection.
argument-hint: "[feature name or path to approved spec]"
---

# Playable feature delivery

Deliver a complete player journey: a real action reaches the server, is
validated, changes authoritative state, gives clear feedback, saves when it
should, and fails gracefully. No disconnected buttons, fake data, or untested
saves presented as finished.

## Preconditions (stop and ask if missing)

- An approved spec or intake ledger (`project-feature-intake`). The game concept
  must be selected; do not build an unselected candidate.
- The task is claimed on `vault/tasks/BOARD.md`: a row under In progress with
  your name after it, as the board's header describes (a tool name such as
  Claude is fine).
- You inspected teammates' work in the areas you will touch: `git status`, the
  branch, recent commits, and remote branches after `git fetch` (it updates
  remote-tracking refs only). Work that exists only on another machine is
  invisible, so ask when the board suggests someone is on it. Never overwrite it.
- You read `AGENTS.md` and inspected existing modules before inventing paths.
- If the feature saves data, the single ProfileStore lifecycle module exists.
  If it does not, stop and ask whether to build it first (as its own claimed
  board item) or whether a teammate owns it. Never add a second save path.

## Workflow

1. **Contract first.** For anything another module or teammate will use,
   write the interface: owning module, exported types and functions, remote
   names and direction, allowed arguments, server validation, replicated
   read model, error cases, cleanup owner. Every remote and data field gets a
   contract in the plan. Save it to `vault/design/` before parallel work starts
   when more than one person will build against it; a decision note is for a
   non-obvious choice behind it.
2. **Server.** All amounts, prices, rewards, ownership, cooldowns, and outcomes
   are computed on the server. Validate every remote argument (type, finite
   numbers, length, allowed IDs, current state, distance, per-player rate).
   Resolve contested actions without a yielding gap that allows two winners.
   Time is server time only (`os.time()` for saved timestamps); the client may
   display a server-supplied time and never sends one.
3. **Saving.** Only through the single ProfileStore lifecycle module. Add fields
   to the template; plan migrations when meaning changes. Test with
   `ProfileStore.Mock`. Never touch live profiles.
4. **Client.** Sends intent only. Implements loading, empty, locked,
   affordable/unaffordable, pending, success, rejection, and retry states. Local
   feedback may acknowledge a tap but never confirms ownership or purchase
   before the server does.
5. **Failure handling.** Fill the table in `references/delivery-checklist.md`:
   duplicate input, simultaneous players, malformed values, insufficient
   resources, stale state, latency, leaving mid-action, respawn, shutdown,
   save failure. Keep the filled table in the plan and, once built, in the
   handoff.
6. **Increments.** Core interaction → complete slice → polish to the requested
   standard → expand. Each increment is playable and verified. Placeholders are
   listed as placeholders in the handoff.
7. **Check and verify.** Run `./scripts/check.ps1`, then
   `project-studio-verification`, then `project-team-handoff`.

## Code rules (from AGENTS.md, not optional)

`--!strict` first line; `task` library; `game:GetService`; Trove for cleanup,
Promise for async and retries, Signal for custom events; edit scripts on disk
only (Rojo is the source of truth); never edit `Packages/`, `ServerPackages/`,
or `src/server/vendor/`; no new frameworks or dependencies without approval.

| Code | Destination |
|---|---|
| Server logic, ProfileStore owner | `src/server/` |
| Client UI and input | `src/client/` |
| Shared types, config, remote names | `src/shared/` |

## Propose first, do not just build

New currency, trading, PvP, breeding, permanent loss or theft, paid items or
paid luck, cross-server systems, destructive prestige, a different art style,
or anything that changes the creative premise. Give player benefit, cost, risk,
and a way to test it, then wait for direction.

Load third-party skills for API detail when relevant: roblox-networking,
roblox-security, roblox-luau-core, roblox-luau-types, roblox-gui,
roblox-architecture, roblox-performance. Project rules override their examples.

Checklist and failure table: `references/delivery-checklist.md`.
Worked example: `references/example.md`.
