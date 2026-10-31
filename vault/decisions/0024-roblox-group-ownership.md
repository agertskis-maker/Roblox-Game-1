---
title: "0024: the Car Hop Roblox group owns the game's assets from now on"
date: 2026-10-28
tags: [decision, assets, ownership, lane3]
status: prepared; the group does not exist yet (Adam is creating it, 2026-10-28). The B2 re-import waits for its name and id.
---
# 0024: the Car Hop Roblox group owns the game's assets

Source: Adam's round 3 close-out brief, Part 6 ([[hud-round3-closeout]]): "Adam is creating a Roblox group to own the game." Number checked on every local and remote branch on 2026-10-28 (0016 to 0023 in use; 0018 already appears twice, older) and reserved in `Car-Hop-Art\DECISION_NUMBERS.txt` for the other active Lane 3 session.

## Decided (Adam)
1. A Roblox group owned by Adam will own Car Hop. Adam creates and configures it himself; no session creates or configures it, changes experience settings, transfers anything or publishes.
2. **From now on, every lane uploads with the group as the Creator** (meshes, images, audio, animations), once the group exists. In Studio's Importer the Creator setting picks a user or a group (see sources). Brian L was asked to do this for car meshes through the vault ([[hud-round3-forwardable-messages]] section 5).

## What the documentation says (read 2026-10-28; all pages updated that day)
- An asset never changes owner. A group-owned copy is a **new upload with new ids**; the old user-owned asset stays as it is.
- A group-owned game can use a user-owned asset when it is **Open Use**; a **Restricted** asset needs its owner to grant the group or the game, and a game grant cannot be revoked.
- A user-owned experience can be transferred to a group its owner can publish to; it keeps its ids; the group must accept; public access is removed until it is released again.
- Uploading for a group needs the group permission **Manage development items**; editing group games needs **Edit experiences**; publishing needs **Publish experiences**.
Sources: [Importer](https://create.roblox.com/docs/studio/importer), [Groups](https://create.roblox.com/docs/projects/groups), [Asset privacy](https://create.roblox.com/docs/projects/assets/privacy), [Game ownership transfer](https://create.roblox.com/docs/projects/game-ownership-transfer).

## What is owned where today (2026-10-28)
| Assets | Owner now | Plan |
|---|---|---|
| B2 Downtown kit: 180 meshes and 5 palette images (`src/lookdev/Downtown/KitIds.luau`, `vault/design/assets.md`) | Adam's user `peskaface` (2393473976), private to the creator | **re-import with the group as Creator** (HUD session, branch `feature/lane3-hud-downtown-lookdev`); old ids kept in `assets.md` as "retired, user-owned" |
| Island Task 4 kit: 97 meshes (`feature/lane3-island-environment`, `AssetIds.luau`), plus the 11 Task 3 meshes | Adam's user `peskaface`, Restricted | the Speedway session prepares the 97-mesh re-import; this session does not touch it, so nothing is uploaded twice |
| 14 test car meshes from 2026-10-20 (`feature/lane3-first-car-downtown`, log 2026-10-20) | Adam's user `peskaface` | test uploads; final cars are Brian L's, under the group |
| Brian L's car meshes, if any | **unknown** (0015 says his account, Open Use, Asset Privacy off; none are recorded in this repo) | to discuss with Brian L (vault message section 5); not an order |
| Music and sound ids used by the HUD preview | Roblox, APM and Pro Sound Effects partner accounts (not ours) | nothing to move |

## Places and the future experience
- The private test places (`Car-Hop-Art\CarHop-HUD-Playground.rbxl`, `CarHop-Downtown-LookDev.rbxl`, `CarHop-Island-Test.rbxl`, `CarHop-Lane3-Test.rbxl`) are **local files or private personal places**. They are not the game and are not transferred. A local file has place id 0 and loads its owner's assets in Studio.
- The **future shared experience** should be created by, or transferred to, the group, so it can use group-owned assets without per-asset grants. Which existing place becomes the shared place, and when, is not decided here.
- Adam's island test place was published as a private place on 2026-10-21 ([[0006-studio-mcp-rules]]); it stays under Adam's user unless Adam decides otherwise.

## Not decided here
The group's name and id, its roles for Brian R and Brian L, whether the island and car meshes are re-imported, and which place becomes the shared experience.
