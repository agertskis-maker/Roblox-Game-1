---
title: "0001: Where ProfileStore comes from"
date: 2026-10-14
tags:
  - decision
  - dependencies
status: accepted
---

# 0001: Where ProfileStore comes from

## Decision
**ProfileStore is vendored**: a verbatim copy of `ProfileStore.luau` from the upstream repository lives in `src/server/vendor/`. It is not a Wally dependency.

| | |
|---|---|
| Upstream | https://github.com/MadStudioRoblox/ProfileStore |
| Pinned commit | `45c9847cbcf1fc260369c50eb335aba7c35aecdd` (2025-07-31, "Merge pull request #14 from RuizuKun-Dev/patch-1") |
| File | `src/server/vendor/ProfileStore.luau`, 64,654 bytes, LF line endings |
| Git blob SHA | `5b196af86a1eafa2ad5e94ef9398c483e87704ed` (matches GitHub's API for that commit) |
| SHA-256 | `ad43737203688b8e88cab34ebe8c483000c157e53bfb41e35f1b49ee89d0c95f` |
| License | Apache-2.0, copied to `src/server/vendor/LICENSE` |

Upstream has no releases or tags, so "latest" means `main` at the pinned commit.

## History
1. **First choice (2026-10-14):** `lupapi/profilestore@1.0.4` from Wally, a third-party republish, chosen because we believed no official package existed. Its code was verified identical to upstream.
2. **Switched (2026-10-14):** at the team's request, to taking the file straight from the upstream GitHub repository instead of a registry package. `lupapi/profilestore` was removed from `wally.toml`.

## Correction to the first version of this note
The first version said there is no official Wally package. **That was wrong.** `lm-loleris/profilestore` exists in the registry (1.0.0 to 1.0.3, server realm):
- It is published by the GitHub user `LM-loleris`, and its name and version match what upstream's own `wally.toml` declares.
- At 1.0.3 its `ProfileStore.luau` is identical to the pinned upstream commit apart from CRLF line endings.
- It was missed because the original search guessed the scopes `loleris/` and `madstudioroblox/`.

Vendoring is still a valid choice (no registry dependency, we see exactly what we run), but the first-party package is a legitimate alternative.

## Consequences
- **We own updates.** `wally install` will never upgrade ProfileStore. To update: download `ProfileStore.luau` and `LICENSE` from upstream pinned to the new commit, confirm `git hash-object --no-filters` equals the blob SHA GitHub reports, replace both files, update the table above, and test saving in Studio.
- **Do not edit the vendored file.** If we ever need a local patch, list it in this note so the next update does not silently drop it.
- Keep `LICENSE` next to the file (Apache-2.0 requires it when redistributing).
- It sits under `ServerScriptService`, so it is never replicated to clients.

## Reverting to Wally
Add `ProfileStore = "lm-loleris/profilestore@1.0.3"` under `[server-dependencies]` in `wally.toml`, run `wally install`, delete `src/server/vendor/`, and change the require path to `ServerScriptService.ServerPackages.ProfileStore`. The `ServerPackages` mapping in `default.project.json` is already in place (as an optional path).

## Alternatives considered
- **`lm-loleris/profilestore@1.0.3`**: first-party Wally package, see the correction above.
- **`lupapi/profilestore@1.0.4`, `monaleo/profilestore@1.0.3`**: third-party republishes, identical to upstream. An unnecessary middleman now that a first-party package exists.
- **`vyon/profilestore`, `buweyy/profilestore`, `ptekspy/profilestore`**: shared realm and/or modified from upstream. Not used.
