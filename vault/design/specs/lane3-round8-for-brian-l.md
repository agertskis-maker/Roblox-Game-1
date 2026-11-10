---
title: Lane 3 Round 8, cars, cosmetics and saves for Brian L
tags: [lane3, round8, lane2, handoff]
---

# Round 8 notes for Brian L (N-02)

## Your car models

No file in `assets/cars` was edited. Everything Round 8 needed about each car is data in Lane 3's folder, keyed by your model
names, so your meshes stay as you made them:

- `src/shared/Style/Anchors/PaintParts.luau`: which parts take paint (body) and which never do (glass, lights, tyres, grilles), plus
  mask notes where one mesh mixes body and glass.
- `src/shared/Style/Anchors/Wheels.luau`: hub points, radius and width per car, and the factory wheel parts the new 3D rims hide.
- `src/shared/Style/Anchors/Exhausts.luau`: one or two exhaust points per car (Beach Bug and Desert King set by hand: open rear frames).
- `src/shared/Style/Anchors/DecalPanels.luau`: one side panel per car. Since Adam's playtest the decals may spread 2.4 times the
  panel's length and 2 times its height ("make the decals more dramatic, you can cover the car").

If you change a model's size or part names, these entries need the same change; tell Lane 3 in the Replies.

## New save field

`RideCar` (string, the car the player rides next; default `Putter`) in the beta save template, with the `PickRideCar` remote. The
server checks the car is owned (or a World's Loaner), rate-limits the remote and repairs an unknown value to `Putter`.

## New cosmetic items and PREVIEW prices

Wheels: Stock Five plus 16 rim designs (`CosmeticPreviewCatalog`, tab Wheels). Trails: 13 plus Money Rain, Aurora Veil, Retro Grid,
Petal Storm and Drift Smoke (18). All prices are PREVIEW starting values for you to calibrate. Robux items stay not for sale.

## The SUV that looks like a police livery

Round 7 reviewers flagged one SUV whose black-and-white livery reads as a police car. AGENTS.md rules out police looks; Lane 3 did
not edit it. Please recolour it (or tell Adam which car it is and what you prefer).

## Group-owned asset ids

All Round 8 art is owned by the LEGION STUDI0S group (74306252): 22 wheel models, 10 clover files, Coach Roxy's cut-out and 82
images and sounds. The full list with ids is in `vault/design/assets.md` (Round 8 sections).

## Your luck branch

`feature/lane2-luck-in-beta` (2026-11-08) was not integrated into the beta: it has its own LUCK kiosk and a proposed name that needs
Adam's decision. Nothing on it was changed.

## Replies

