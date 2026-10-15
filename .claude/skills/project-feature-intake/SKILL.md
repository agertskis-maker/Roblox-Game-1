---
name: project-feature-intake
description: Turns a brain dump, a long ChatGPT/Codex build prompt, or a reference-heavy request for this Roblox project into a traceable requirement ledger, exposes contradictions, and asks only the questions that change the result. Use before building any multi-part feature or when asked to review a prompt.
when_to_use: Also when a prompt conflicts with AGENTS.md or the vault, mentions an undecided game concept, mixes required and optional ideas, or asks for review rather than implementation.
argument-hint: "[prompt text or path to a prompt file]"
---

# Feature intake

Turn the request into an actionable requirement ledger without losing the
owner's ambition. Intake is review: implementation starts only when the current
request authorizes it, and then continues in `project-feature-delivery`.

## Read first

- `AGENTS.md`, `CLAUDE.md` (audience and monetization rules),
  `vault/design/GDD.md`, `vault/tasks/BOARD.md`, and recent `vault/decisions/`.
  Live files beat uploaded snapshots in `claude-context/`;
  `claude-context/10_DECISION_REGISTER.md` shows which decisions were open when
  the pack was written.
- `claude-context/02_TEAM_AND_CREATIVE_BRIEF.md` for creative authority and
  `claude-context/05_GAMEPLAY_AND_CONCEPT_LAB.md` when a concept is involved.
- If `$ARGUMENTS` is a file path, read that file as the prompt.

A candidate concept or earlier suggestion is not an approved feature. If no
concept has been selected, say which candidate the request concerns and do not
choose, merge, or build one. Name a candidate only when the request or a vault
note ties it there; otherwise say the request is unmapped and list the
candidates it could be.

## Produce, scaled to the request

1. **Player outcome:** the action, the intended feeling, a before/after example.
2. **Requirement ledger** (template in `references/ledger-template.md`): stable
   ID, exact behavior, required/optional, source quote or section, acceptance
   evidence, dependency, status. Merge passages that say the same thing into
   one ID; never merge passages that disagree. A passage written as required
   that policy or an approved decision blocks stays Required with status
   `blocked`, citing the rule; never demote it to Optional to unblock it.
3. **Contradictions:** each conflict between two passages, or between the prompt
   and AGENTS.md / an approved decision, with both quotes and what it blocks.
4. **Material questions:** at most a small batch. Ask only about choices that
   change ownership, loss, economy, monetization, fairness, data, the core
   fantasy, or integration. For each, say what each answer would change.
5. **Delegated details:** reversible presentation and implementation choices you
   will make yourself within the approved direction, labelled as yours.
6. **First playable slice:** one complete player journey with its verification,
   then the stages that reach the full requested finish. Keep deferred ambition
   visible as "not yet", never silently removed.

Continue independent authorized work while questions are open. If every item is
gated on an open question, say so and stop. Missing images or links stay
missing evidence; do not invent their contents.

## Hand-offs

- Requests with a look or reference images: `project-visual-direction`.
- Approved build work: `project-feature-delivery`.
- Save the ledger in `vault/design/` (for example `vault/design/specs/<feature>.md`)
  when the owner wants it kept.

## Common failures

- Replacing a detailed specification with a generic summary.
- Burying a core unknown (loss rules, who owns what) inside generated code.
- Asking the owner to approve margins and variable names.

Worked example: `references/example.md`.
