# Requirement ledger template

Copy, then fill. Omit columns that add nothing for a small request.

## Feature: <name>

Concept: <selected concept, or "undecided: request concerns candidate X">
Requested action: review | prototype | implement | polish | diagnose
(intake itself only reviews; the other actions need the request to authorize them)
Source: <prompt file / message date>

### Player outcome

<one paragraph: action, feeling, before/after>

### Ledger

| ID | Requirement (exact behavior) | Req/Opt | Source | Acceptance evidence | Depends on | Status |
|---|---|---|---|---|---|---|
| R1 | | Required | §2 "quote" | runtime test: ... | | open |
| R2 | | Optional | | visual review: ... | R1 | open |

Status values: open, blocked (needs decision), in progress, implemented,
build-checked, runtime-tested, visually-reviewed, deferred.

### Contradictions

| # | Passage A | Passage B (or rule) | What it blocks |
|---|---|---|---|

### Questions for the owner

1. <question> If A: <consequence>. If B: <consequence>. Blocks: R#.

### Choices I made (reversible)

- <detail> because <reason>.

### First playable slice

Journey: <entry → action → result → next goal>
Verified by: <checks>
Later stages: <stage → what it adds>, ...
Deferred (not removed): <items>
