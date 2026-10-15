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

## Preconditions (no implementation until met)

- Approval: an approved spec or intake ledger (`project-feature-intake`), or a
  one-line "Approved: ..." that clearly refers to a specific request, spec, or
  ledger. If it is ambiguous which, ask. "Owner" is the repository owner until
  the board assigns area owners, who then approve plans for their area. One
  reply may grant both a propose-first approval and a plan go-ahead if it says
  both ("Approved, go ahead").
- Concept: build features only for a selected concept, meaning
  `vault/design/GDD.md` has `status: selected` and `concept:` naming it, plus a
  decision note. An "Approved:" on a feature never selects a concept.
  Concept-agnostic foundations, starting with the ProfileStore lifecycle module
  and a minimal data template with no concept-specific fields, may start before
  the concept is chosen. Any currency or economy field (including a last-claim
  timestamp for a currency reward) is a propose-first item, not a foundation.
  Do not build an unselected candidate.
- The task is claimed on `vault/tasks/BOARD.md`: a row under In progress with
  your name after it, as the board's header describes (a tool name such as
  Claude is fine). Claim it before coding, after any go-ahead the plan needs;
  posting a plan or asking questions is not starting work.
- You inspected teammates' work in the areas you will touch: `git status`, the
  branch, recent commits, and remote branches after `git fetch` (it updates
  remote-tracking refs only; `git ls-remote --heads origin` is the read-only
  alternative, and offline you say the remote state is unknown). Work that
  exists only on another machine is invisible, so ask when the board suggests
  someone is on it. Never overwrite it.
- You read `AGENTS.md` and inspected existing modules before inventing paths.
  While the folder convention is open, follow the `AGENTS.md` layout and list
  each new path in the plan.
- If the feature saves data, the single ProfileStore lifecycle module exists.
  If it does not, it is the first increment: its own claimed board item, with a
  minimal template and no concept-specific fields, unless the board shows a
  teammate owns it. Never add a second save path.
- Propose-first: if the feature includes a propose-first item (listed under
  "Propose first" below; any currency or economy field counts), its player
  benefit, cost, risk, and test were presented and the owner approved after
  that presentation.
- Branch: game code is on a feature branch, starting with the first game-code
  task, and merges to `main` by pull request only after the GitHub check
  passes (`AGENTS.md`). `main` is fine for docs, vault, skills, and tooling.

When a precondition fails, post the questions plus a conditional plan (what you
would do once each answer arrives), and do no implementation until the
precondition is met.

## Plan before coding

Post a short plan first: the ledger IDs (or request lines) covered, the files
you will create or change, and the checks you will run.

- **Wait for an explicit go-ahead** when the work touches saved data or
  schemas, the economy, monetization, or shared contracts or interfaces.
- **Otherwise proceed** once the plan is posted.

The gates stack: a foundation such as the ProfileStore lifecycle module may
start before the concept is chosen, but anything touching saved data still
needs the plan posted and an explicit go-ahead. A bare "Build X" gets a short
intake (`project-feature-intake`), then this plan.

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
   display a server-supplied time and never sends one. For a countdown the
   server sends an absolute server-time target and the client derives the
   remaining time from `Workspace:GetServerTimeNow()`, never from its local
   clock.
3. **Saving.** Only through the single ProfileStore lifecycle module. Add fields
   to the template; plan migrations when meaning changes. Until the concept is
   selected, add no concept-specific fields. Test with `ProfileStore.Mock`.
   Never touch live profiles.
4. **Client.** Sends intent only. Implements loading, empty, locked,
   affordable/unaffordable, pending, success, rejection, and retry states. Local
   feedback may acknowledge a tap but never confirms ownership or purchase
   before the server does.
5. **Failure handling.** Fill the table in `references/delivery-checklist.md`:
   duplicate input, simultaneous players, malformed values, insufficient
   resources, stale state, latency, leaving mid-action, respawn, shutdown,
   save failure. Mark a row N/A with a one-line reason when it cannot apply.
   Keep the filled table in the plan and, once built, in the handoff.
6. **Increments.** Core interaction → complete slice → polish to the requested
   standard → expand. Each increment is playable and verified. Placeholders are
   listed as placeholders in the handoff.
7. **Check and verify.** Run `./scripts/check.ps1`, then
   `project-studio-verification`, then `project-team-handoff`. Game code goes
   on a feature branch and merges to `main` by pull request only after the
   GitHub check passes (`AGENTS.md`).

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
or anything that changes the creative premise. Present player benefit, cost,
risk, and a way to test it. Explicit owner approval after that presentation
satisfies this rule; an "Approved:" given before the presentation does not.
Record each approved item as a decision note.

Load third-party skills for API detail when relevant: roblox-networking,
roblox-security, roblox-luau-core, roblox-luau-types, roblox-gui,
roblox-architecture, roblox-performance. Project rules override their examples.

Checklist and failure table: `references/delivery-checklist.md`.
Worked example: `references/example.md`.
