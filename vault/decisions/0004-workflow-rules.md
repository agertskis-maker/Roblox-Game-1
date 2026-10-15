---
title: "0004: workflow rules for approvals, planning, and visual references"
date: 2026-10-15
tags:
  - decision
  - workflow
  - agents
status: accepted
---

# 0004: workflow rules for approvals, planning, and visual references

## Decision
The repository owner answered twelve open workflow questions raised while dry-running the project skills. The answers are rules for people and agents alike. The shared rules are in `AGENTS.md` ("Approvals and planning", "Visual references and UI styling"); skill text carries the detail.

| # | Rule | Applied in |
|---|---|---|
| 1 | A one-line "Approved: ..." counts when it clearly refers to a specific request, spec, or ledger. If it is ambiguous which, ask. | AGENTS.md; feature-intake; feature-delivery |
| 2 | Concept-agnostic foundations may proceed before the concept is chosen, starting with the ProfileStore lifecycle module. Keep the data template minimal, with no concept-specific fields, until the concept is selected. | AGENTS.md; feature-delivery |
| 3 | Propose-first items (a new currency and the others listed in AGENTS.md) need owner approval after Claude presents player benefit, cost, risk, and a test. Each approved item is recorded as a decision note. | AGENTS.md; feature-delivery |
| 4 | Delivery always posts a short plan (ledger IDs, files, checks) before coding. It waits for a go-ahead only when the work touches saved data or schemas, the economy, monetization, or shared contracts or interfaces; otherwise it proceeds. | AGENTS.md; feature-delivery |
| 5 | Intake uses the visual-direction question rule: ask every question whose answer changes the result, in one batch, no fixed cap; decide reversible details yourself. | AGENTS.md; feature-intake and its example |
| 6 | "Make it like this" is strong guidance, not a mandate for the whole reference. Claude lists the qualities it plans to preserve and the owner confirms them in the same question batch. | AGENTS.md; visual-direction; feature-intake |
| 7 | Allowed: imitating style traits (shape language, outlines, rounded panels, palette mood, layout patterns). Not allowed: copying logos, characters, item art, icons, unlicensed fonts, names, or a near-identical recreation of a distinctive screen. | AGENTS.md; visual-direction hard limits |
| 8 | The representative sample is approved by the project owner or the teammate who owns that area; the approval is recorded in `vault/design/visual-direction.md`. | AGENTS.md; visual-direction; brief template |
| 9 | A design-only brief needs a one-line board claim. | AGENTS.md; visual-direction |
| 10 | Fonts and touch-target size are undecided. Visual direction proposes them after the concept is chosen and the owner approves. Do not hard-code values yet. | AGENTS.md; visual-direction; brief template |
| 11 | UI style tokens (colors, fonts, spacing, corner radius, stroke) live in a shared module in `src/shared`, not the Studio Style Editor, because Style Editor data lives in the place file and is not in Git. Provisional until the concept's visual direction is approved. | AGENTS.md; visual-direction |
| 12 | `claude-context/04_VISUAL_UI_AND_GAME_FEEL.md` matches the skill's representative-sample guidance. | `claude-context/04` |

## Why
These answers settle gaps that the skills could not resolve alone. Agents found each one while following a skill literally; leaving them open meant every agent would guess differently. Rule 11 has a stated reason: Style Editor data is stored in the place file, which is not under version control.

## Consequences
- Rules 1 to 4 loosen earlier skill wording that said to stop and ask (approval, missing ProfileStore module) and tighten it elsewhere (a plan is always posted; saved data, economy, monetization, and shared contracts still wait for a go-ahead).
- Paid items and paid luck remain subject to the audience rules in `CLAUDE.md`: an approved team design and current Roblox policy.
- Rule 10 means the shared token module has no fixed font or touch-target values until the owner approves them.
- `claude-context/09_PROJECT_RULES_SNAPSHOT.md` is a snapshot of `AGENTS.md` and is now behind it. Refresh it when the context pack is re-uploaded.

## Reverting
Remove the two new sections from `AGENTS.md`, the matching lines in the skills, and the bullet in `CLAUDE.md`.

## Addendum 2026-10-15 (round 2): gates, owner, concept selection, branches
The repository owner answered the four questions the dry runs kept hitting, plus the smaller items.

| # | Rule | Applied in |
|---|---|---|
| A1 | Gates stack. Foundations such as the ProfileStore lifecycle module may start before the concept is chosen, but anything touching saved data still needs the plan posted and an explicit go-ahead. | AGENTS.md; feature-delivery and example; guide |
| A2 | "Owner" means the repository owner until the team assigns area owners on the board at the concept meeting. Area owners then approve samples and plans for their area. One reply may grant both a propose-first approval and a plan go-ahead if it says both, for example "Approved, go ahead." | AGENTS.md; delivery; visual-direction; brief template; guide |
| A3 | A concept counts as selected only when `vault/design/GDD.md` has its status set to selected with the concept named, plus a decision note. An "Approved:" on a feature never selects a concept. | AGENTS.md; intake; delivery; `GDD.md` gains `concept: undecided` |
| A4 | Any currency or economy field, including `LastDailyClaim` in the daily-reward example, is propose-first, not a foundation. A bare "Build X" gets a short intake, then the plan. | AGENTS.md; intake; delivery; both examples |
| A5 | Branch policy: `main` is fine until a second person writes game code. From the first game-code task onward, each person works on a feature branch and merges to `main` by pull request only after the GitHub check passes. Recorded; branch protection settings are not enforced yet. | AGENTS.md "Branches"; delivery step 7; handoff section 7; `claude-context/03` |
| A6 | A shop or panel opened during gameplay is reviewed as an overlay on the gameplay view. | AGENTS.md; visual-direction; brief template; example; `claude-context/04` |
| A7 | The intake threshold for long or mixed prompts is judgment. No rule. | none |
| A8 | The reduced-motion mechanism is decided with the visual direction after the concept is chosen. Open item. | AGENTS.md; visual-direction; board Backlog |
| A9 | `claude-context/09` is refreshed from the current `AGENTS.md`, and `claude-context/10` reflects decisions 0003 and 0004. | `claude-context/` |

Interpretation to confirm: the branch answer has two overlapping sentences ("until a second person writes game code" and "from the first game-code task onward"). `AGENTS.md` applies the stricter second one: feature branches start with the first game-code task, and `main` stays fine for docs, vault, skills, and tooling.

Open items: reduced-motion mechanism; fonts and touch-target size; assigning area owners at the concept meeting.
