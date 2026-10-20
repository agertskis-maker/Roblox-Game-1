---
name: project-feature-intake
description: Turns a brain dump, a long ChatGPT/Codex build prompt, or a reference-heavy request for this Roblox project into a traceable requirement ledger, exposes contradictions, and asks only the questions that change the result. Use before building any multi-part feature or when asked to review a prompt.
when_to_use: Also when a prompt conflicts with AGENTS.md or the vault, mentions an undecided game concept, mixes required and optional ideas, or asks for review rather than implementation.
argument-hint: "[prompt text or path to a prompt file]"
---

# Feature intake

Turn the request into an actionable requirement ledger without losing the
owner's ambition. Intake is review: implementation starts only when the current
request authorizes it, and then continues in `project-feature-delivery`. A
one-line "Approved: ..." authorizes it when it clearly refers to a specific
request, spec, or ledger; if it is ambiguous which, ask. A bare imperative
such as "Build X" gets a short intake, then the delivery plan; it is not an
approval.

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
choose, merge, or build one. A concept counts as selected only when
`vault/design/GDD.md` has `status: selected` and `concept:` naming it, plus a
decision note; an "Approved:" on a feature never selects one. Name a
candidate only when the request, a vault
note, or `claude-context/05_GAMEPLAY_AND_CONCEPT_LAB.md` ties it there;
otherwise say the request is unmapped and list the candidates it could be.

## Produce, scaled to the request

1. **Player outcome:** the action, the intended feeling, a before/after example.
2. **Requirement ledger** (template in `references/ledger-template.md`): stable
   ID, exact behavior, required/optional, source quote or section, acceptance
   evidence, dependency, status. Merge passages that say the same thing into
   one ID; never merge passages that disagree. Wishes ("should feel like",
   "maybe") are Optional; stated behavior is Required. A required passage that
   policy or an approved decision blocks stays Required with status `blocked`,
   citing the rule; never demote it to Optional to unblock it.
3. **Contradictions:** each conflict between two passages, or between the prompt
   and AGENTS.md / an approved decision, with both quotes and what it blocks.
4. **Material questions:** every question whose answer would change the result,
   as one batch, with no fixed cap. Typical ones concern ownership, loss,
   economy, monetization, fairness, data, the core fantasy, or integration. For
   each, say what each answer would change. Do not ask about reversible details
   or about anything `AGENTS.md` or an approved decision already settles; state
   those as constraints. For a propose-first item (see `AGENTS.md`), include
   player benefit, cost, risk, and a test with its questions.
5. **Delegated details:** reversible presentation and implementation choices you
   will make yourself within the approved direction, labelled as yours.
6. **First playable slice:** one complete player journey with its verification,
   then the stages that reach the full requested finish. Keep deferred ambition
   visible as "not yet", never silently removed. List concept-agnostic
   foundations the slice depends on (starting with the ProfileStore lifecycle
   module) as their own items. Write the slice as a conditional plan: what you
   would do once each answer arrives.

Continue independent authorized work while questions are open. When a
precondition fails (no selected concept, an unapproved propose-first item, a
missing approval), post the questions plus the conditional plan and do no
implementation until it is met. If every item is gated on an open question, say
so, post the conditional plan, and stop. Missing images or links stay missing
evidence; do not invent their contents.

## Hand-offs

- Requests with a look or reference images: `project-visual-direction`. "Make
  it like this" is strong guidance, not a mandate for the whole reference. Put
  the qualities you plan to preserve (or, with no image, which qualities of the
  reference matter) in the same question batch, not a second round.
- Approved build work: `project-feature-delivery`.
- Save the ledger in `vault/design/` (for example `vault/design/specs/<feature>.md`)
  when the owner wants it kept. A review that writes nothing needs no board
  claim; claim when you save a ledger.

## Common failures

- Replacing a detailed specification with a generic summary.
- Burying a core unknown (loss rules, who owns what) inside generated code.
- Asking the owner to approve margins and variable names.

Worked example: `references/example.md`.
