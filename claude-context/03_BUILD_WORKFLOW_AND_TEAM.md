# Build workflow and team coordination

## Start from evidence

Read the relevant live instructions and inspect the working tree before changing it. Locate existing systems instead of generating parallel replacements. Confirm the current branch and base commit, relevant teammate changes, Rojo mapping, installed dependencies, and the available test tools. If access is missing, name the limitation and request the minimum useful artifact; do not claim you inspected a file you cannot read.

For each incoming prompt, make a short requirement ledger: requirement, implementation destination, acceptance check, and status. Identify hard requirements, optional enhancements, and dependencies. A prompt may be long; the ledger prevents its less exciting requirements from disappearing during implementation.

Claim the task on vault/tasks/BOARD.md. For a shared system, record its owner and agree on a contract before multiple teammates work against it. Do not overwrite another person's uncommitted edits. Do not reset branches or discard changes to obtain a clean workspace. Use focused, reviewable changes. Branch policy (decision 0004): `main` is fine for docs, vault, skills, and tooling; from the first game-code task onward, each person works on a feature branch and merges to `main` by pull request only after the GitHub check passes. Branch protection settings are not enforced yet.

## Clarification that enables progress

Ask when two plausible interpretations materially change the result, and put every such question in one batch with no fixed cap. Good questions identify the consequence: “Does theft transfer a permanently owned pet, or only an unbanked egg? This changes ownership, saving, protection, and recovery.” Avoid vague “anything else?” questions that transfer all design work back to the owner.

When an answer blocks one system, proceed with independent authorized work. Do not resolve a core unknown by burying an assumption in generated code. Do not request permission again for a step the user has already authorized. Keep a concise decision record so future sessions do not re-ask settled questions.

## Delivery stages

**Explore:** assess the player fantasy and the hardest unknown. Offer a small number of strong directions with meaningful tradeoffs. A concept sketch is not a promise that assets or mechanics already exist.

**Prove the interaction:** build the smallest playable version that answers a specific question. Identify temporary assets and test instrumentation. Do not make foundational data or security shortcuts that will later be mistaken for production systems.

**Complete one slice:** connect a real player action to server validation, feedback, reward, progression, and persistence where relevant. Include failure states. Demonstrate it with multiple players if players compete or cooperate.

**Polish to target:** refine the slice using the visual reference, intended device, and actual runtime evidence. Evaluate camera, sound, timing, UI, animation, world scale, and performance together.

**Expand deliberately:** add further zones or content through established patterns. Reuse proven systems without turning every small variation into a new framework. Keep the full ambition in the roadmap; distinguish “not yet” from “removed.”

## Shared interface agreement

Record the owning module, exported types/functions, remote names and direction, allowed arguments, server-side validation, replicated read model, error cases, and cleanup responsibility. Include one caller example if it clarifies integration. Prefer stable IDs to display names. Discuss incompatible changes with affected owners before changing them.

A useful three-way work split can be gameplay/data, presentation/UI, and world/content, but this is only a possible structure. Actual roles must follow the team's decisions and abilities. Shared economy configuration, remote contracts, data schemas, and integration scenes need explicit ownership even when work is split this way.

## Repository and Studio boundaries

Rojo owns mapped scripts. Disk edits must flow into Studio through Rojo. Scene objects and uploaded assets need an explicit source-of-truth plan because the current project mapping does not serialize every Workspace object. Before building a substantial map, establish how its editable source is saved, backed up, and shared. Do not assume a local Studio scene is present on teammates' machines or in GitHub.

Check what is synced before adding or moving instances. A Studio edit to a synced script is not an acceptable shortcut. A generated asset, an uploaded asset, a placed instance, and a saved source asset are different states; report which actually exists. Do not commit generated rbxl/rbxm outputs against the repository rules.

## Handoff and completion

Update the task board and add a brief vault/log entry. Record non-obvious architecture or design decisions in vault/decisions using the next unused number. Include the changed files, affected interfaces, any manual Studio/asset step, tests actually run, unresolved failures, and what the next teammate needs to do.

For long sessions, leave a resumable state: current objective, completed requirements, files touched, pending decisions, exact next action, and test status. Another AI should be able to resume without treating the entire chat history as a specification.

Do not push, merge, publish, purchase, or alter live configuration solely because a local build succeeded. These actions need authorization appropriate to the current task. Avoid repetitive approval questions for ordinary reversible work already within scope.
