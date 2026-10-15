# Engineering and verification

The live AGENTS.md is authoritative for repository-specific rules. File 09 is its uploadable snapshot. This file adds review questions and implementation expectations; it does not authorize new frameworks or dependency upgrades.

## Existing structure

Luau scripts live in src/server, src/client, and src/shared. Rojo maps them into the corresponding server, player-script, and replicated locations. Wally packages and the vendored ProfileStore must be used according to AGENTS.md. Inspect the actual version and source contract before writing integration code. Do not assume an API from another similarly named library applies.

Keep modules cohesive. Avoid one enormous gameplay script and avoid a framework whose complexity exceeds the feature. Define module API types. Put authoritative calculations on the server and presentation on the client. Shared modules must not expose server secrets or imply shared execution grants trust.

## Remote boundary

A request expresses intent: interact with this target, select this item, request this upgrade. The server determines eligibility, price, reward, ownership, cooldown, and outcome. Validate types, finite numeric values when accepted, lengths, allowed IDs, current state, distance where relevant, and per-player rate limits. Validate instance ancestry when accepting instance references. Do not trust an apparently valid object merely because the client can reference it.

For contested actions, validate and reserve ownership without a yielding gap that allows two winners. Define the behavior for duplicate requests, stale targets, simultaneous claims, leaving during an action, and failed persistence. Client debouncing is presentation assistance, not a security boundary.

Visual prediction may improve responsiveness, but authoritative rejection must reconcile the display without granting the reward. Local changes to a replicated value must not affect server-owned state.

## Persistence

One server module owns ProfileStore session lifecycle. Features use its documented interface. Keep data serializable, add template fields deliberately, and define migrations when reconciliation alone is insufficient. Adding a default does not automatically migrate renamed fields or changed value semantics.

Use ProfileStore.Mock for tests. Never experiment on live profiles. Handle session loss, join/leave races, shutdown, and incomplete initialization. Do not retain a reference that lets a delayed callback mutate a closed profile. Do not create a second direct DataStore path from feature code.

For transactions with several dependent effects, describe the consistency strategy and recovery behavior. Cross-player trades and offline transfers require a deliberate design; do not pretend two separate profile mutations are an atomic durable transaction. Defer such systems until they are approved and can be verified.

## Purchases and randomness

Before implementing purchases, consult current official Roblox documentation for the product type, grant mechanism, and policy requirements. A purchase UI closing or client success message is not evidence that a durable grant should occur. Design grants to tolerate retries and duplicate delivery using the supported server flow, with a documented persistence/recovery strategy.

Paid random outcomes, paid currency used for randomness, and luck modifiers require the policy review in file 07. Check the relevant per-player eligibility and handle lookup failure explicitly. A hidden button is not sufficient server enforcement. Keep displayed effective odds aligned with the actual configuration and modifiers.

## Cleanup and performance

Use Trove for managed lifetimes, Promise for asynchronous flow/retries, and Signal for custom events as required by this project. Make cleanup ownership explicit for player sessions, spawned creatures, menus, effects, and temporary interactions. Bound repeated work and cancel work when its owner disappears. Avoid infinite polling when an event or controlled scheduler fits.

Measure representative devices before declaring a performance target met. A proposed starting target is stable 30 FPS on a representative lower-end phone and 60 FPS on the intended desktop class; this is a provisional team target, not a guarantee or Roblox requirement. Capture the device, scene, player count, graphics settings, and measurement method.

Stress the expensive moments: many creatures, large avatars, simultaneous hatches, multiple storms, crowded hubs, and long sessions. Limit cosmetic particles, physics debris, unnecessary replication, and repeated UI reconstruction. Consider distance-based presentation and pooled temporary effects where measurements justify them. A visual fallback must preserve gameplay information.

## Verification matrix

| Area | Evidence required when relevant |
|---|---|
| Static correctness | Review changed code and use available lint/type/build tools; report tool availability |
| Rojo integration | Confirm mapping and build/sync behavior; a successful build alone does not prove gameplay |
| Runtime | Exercise the feature in Studio and inspect client/server errors |
| Multiplayer | Two or more clients contesting or sharing the same state |
| Persistence | Mock profile loading, reconciliation/migration, session end, leave/rejoin, failure handling |
| Economy | Boundary values, insufficient funds, duplicates, concurrent attempts, server rejection |
| UI | Visual inspection on selected sizes, long content, loading/empty/failure states, correct input |
| Lifecycle | Respawn, repeated opening/closing, object removal, disconnect, shutdown |
| Performance | Representative normal and crowded scenes, with actual measurements |
| Assets | Ownership permissions, loading failures, fallbacks, temporary asset inventory |

Choose tests proportionate to the change. A spacing adjustment does not require a new automated test suite. Currency, inventory, persistence, and transactions need adversarial checks that could actually catch a harmful defect.

## Completion language

Use precise statuses: implemented, inspected, build-checked, runtime-tested, visually-reviewed, or blocked. Explain unrun tests and the minimum next verification step. Do not say “fully working” because code was generated, and do not claim phone testing from a desktop screenshot. A feature can be locally implemented while still awaiting shared-branch integration or asset permissions.

When reporting a failure, include reproduction conditions, expected behavior, observed behavior, and the next diagnostic step. Fix the underlying cause rather than suppressing the error or disabling the feature to make a test appear successful.
