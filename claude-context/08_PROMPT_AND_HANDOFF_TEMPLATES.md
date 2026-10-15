# Detailed prompt and handoff templates

These templates define the structure for future work. They do not start implementation on their own. Expand relevant sections until the builder has enough detail to act and verify. Omit irrelevant sections rather than filling them with boilerplate. Use explicit values where approved and named open decisions where not.

## Full feature specification format

### 1. Task identity and destination

Name the feature, selected game concept, current project state, and requested action: review, prototype, implement, polish, or diagnose. State that this is a natural-language instruction for Claude. Identify the repository and any known Studio place context without inventing access or IDs.

### 2. Player outcome

Describe what the player should be able to do and what they should feel. Give a concrete before/after example. Explain why this feature belongs in the core fantasy. Identify a signature moment and what makes it understandable during ordinary gameplay.

### 3. Confirmed requirements and boundaries

List approved behavior, mandatory references, existing interfaces, and constraints. Mark the difference between required functionality and optional enhancement. Explicitly name decisions that remain open. Clarify what must be preserved in existing work.

### 4. Player journey and state transitions

Walk from entry to completion, including return visits. For each step specify the visible information, available actions, validation, resulting state, and feedback. Include cancellation, failure, retry, leaving, and re-entry where applicable. Describe the actual state machine when timing or ownership is important.

### 5. Visual and spatial direction

Describe composition, silhouette, palette roles, lighting, material treatment, spacing, typography hierarchy, icon meaning, and world/UI relationship. Name which reference properties are mandatory. Explain how the design changes across device sizes and how it stays readable around other players.

### 6. Screen and control inventory

For every screen or panel: entry, layout, data source, action, loading, empty, error, locked, selected, and disabled states. For every button: label, enabled condition, requested action, pending state, server result, and feedback. Include focus and back/close behavior. Specify any destructive confirmation.

### 7. Motion, sound, and effects

Describe the event sequence, timing proposal, easing character, audio priority, camera treatment, interruption rules, reduced-motion alternative, cleanup, and crowded-scene fallback. Tie every effect to an event; do not request ambient visual noise without a purpose.

### 8. Gameplay and economy rules

Specify authoritative inputs, formulas or configuration references, cost, reward, capacity, rarity, cooldown, eligibility, loss conditions, persistence, and interaction with existing systems. Distinguish illustrative values from approved balance. If paid outcomes are involved, include the policy dependency and supported grant flow.

### 9. Engineering integration

Identify likely existing modules to inspect, file destinations, shared contracts, server/client responsibility, remotes, data schema, cleanup, and asset ownership. Require inspection before committing to invented paths. Describe how Rojo and scene authoring responsibilities are separated.

### 10. Adversarial and edge conditions

Cover duplicate input, simultaneous players, malformed remote values, insufficient resources, stale state, latency, full inventory, missing assets, session loss, respawn, and server shutdown as relevant. State the desired outcome, not just “handle edge cases.”

### 11. Milestones and evidence

Break the work into complete playable increments. Give each increment a clear result and acceptance check. Include visual evidence and runtime tests where relevant. Preserve the full intended finish level; do not silently redefine success as a rough prototype.

### 12. Final response contract

Require changed files, implemented requirements, actual verification, unresolved issues, and any manual step. Ask for at most a few high-value optional improvements with benefit, cost, and test approach. Require clear labels for any code the human must execute.

## Example acceptance checks: contested egg claim

This is an illustration, not approval of the egg concept or its rules.

- Given two players request the same available egg, when the server resolves the requests, exactly one receives the claim and the other receives a clear unavailable result.
- Given a request references an egg outside the permitted interaction distance, the server rejects it without changing inventory or currency.
- Given a player taps repeatedly while the first request is pending, the interface remains responsive and no duplicate grant occurs.
- Given the winner leaves during an approved carrying phase, the outcome follows the documented ownership/recovery rule; the test cannot be written correctly until that rule is chosen.
- Given a low-effects setting, the weather remains understandable and the collection target remains visible without relying on dense particles.

## Prompt review message

Review the following specification against our project context and current repository. Extract its mandatory requirements, identify contradictions and material missing decisions, and check whether its APIs, asset assumptions, and tool expectations are supported. Recommend concrete improvements with player benefit and implementation cost. Do not implement during this review. Ask only the questions that would materially change the result, and distinguish blockers from reversible details you can choose within our approved direction.

## Implementation message

Implement the approved specification below using our project context and live repository rules. First inspect existing relevant systems and current changes, claim the task, and identify any blocking contradiction. Continue authorized independent work while awaiting necessary clarification. Deliver in playable increments and preserve the specified final polish. Verify each meaningful requirement with appropriate evidence; report tests you cannot run accurately. Update the board and leave a handoff. Do not silently introduce optional systems or substitute a prototype for the requested finished feature.

## Reference-image message

Use the attached reference as visual evidence for the feature described below. First identify its observable composition, hierarchy, palette, typography, shapes, materials, lighting, and density. Separate visible properties from inferred behavior. Preserve the qualities I explicitly name, adapt them to Roblox and the target screens, and propose compatible improvements. Do not infer hidden mechanics or asset rights from the image. Show or capture a representative result for visual comparison before multiplying the style across the feature.

## Handoff format

- Task and owner:
- Branch/base commit and current commit if available:
- Requirement statuses:
- Files and interfaces changed:
- Relevant design/architecture decision:
- Assets or manual Studio steps:
- Tests run and observed results:
- Tests not run and reason:
- Known limitations or open questions:
- Exact next useful action:

## Prompt length rule

The owner wants exceptional detail. Spend that detail on interactions, visual decisions, state behavior, integration, and evidence. Avoid repeating the same demand for quality in dozens of forms. If a specification exceeds a practical message size, split it into numbered modules with a requirement ledger and explicit dependency order. Do not remove essential requirements just to shorten it, and do not claim that length makes mistakes impossible.
