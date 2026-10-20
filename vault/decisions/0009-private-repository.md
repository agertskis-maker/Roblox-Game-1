---
title: "0009: the repository is private"
date: 2026-10-20
tags:
  - decision
  - workflow
  - github
status: accepted
---

# 0009: the repository is private

## Decision
Adam (repository owner) made `agertskis-maker/Roblox-Game-1` private on 2026-10-20. `gh repo view --json visibility` returns `PRIVATE`. The account is on GitHub Free: the branch protection API answers "Upgrade to GitHub Pro or make this repository public to enable this feature."

## Why
The Lane 3 design references in `vault/design/references/` are screenshots of other developers' Roblox games, one showing another player's avatar. They are inspiration only, and a public repository would have redistributed them. Keeping the repository private lets the team keep them in Git beside the visual direction.

## Consequences
- **Branch protection does not apply to `main` on GitHub Free.** Private repositories on Free cannot use branch protection rules or rulesets, and GitHub returns 403 for both. None had been configured before (`AGENTS.md`: "Branch protection settings are not enforced yet"); now none can be configured without a paid plan or making the repository public again. Our rules (no force-push to shared branches; merge game code to `main` only by pull request after the GitHub check passes; [[0004-workflow-rules]] A5; the handoff skill's "Never force-push") are enforced only by our own workflow, not by GitHub.
- **GitHub Actions:** Actions stay enabled (all actions allowed). Standard GitHub-hosted runners were free for the public repository. Private repositories on GitHub Free include 2,000 minutes a month and 500 MB of artifact and package storage. Without a payment method, Actions stop when the quota runs out. "Project checks" takes about 15-25 s per run, so each run likely counts as one minute (not confirmed). It runs on every push and every pull request event, so one push to a branch with an open pull request uses two runs.
- **Access:** only collaborators can see or clone the repository. On 2026-10-20 the collaborator list had two accounts: the owner and one teammate. Every teammate needs collaborator access.
- **Artifacts shared from the repository** (review pages, links in the vault) are unaffected; they were already private to Adam until shared.

## Revisit
If the team needs GitHub to enforce the `main` rules, upgrade to GitHub Pro or Team, or make the repository public again after removing third-party images from its history.
