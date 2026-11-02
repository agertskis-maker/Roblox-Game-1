---
title: 0033 Lane 3 Round 3
status: accepted
date: 2026-11-02
tags:
  - decision
  - lane3
---

# 0033: Lane 3 Round 3

Brief [[lane3-round3]], ledger [[lane3-round3-ledger]]. Builds on [[0032-lane3-round2]]. Adam's own decisions are in the brief, section 0.1; these are the reversible ones made without asking, as the brief told me to.

## Art
- **Why the icons blurred:** they were shown from 96 px previews through EditableImage. Local places now read `rbxasset://carhop/<key>.png` from Studio's content folder, full size, mip-mapped like a real upload. `install-local-art.ps1` puts them there, and only places with `ReplicatedStorage.Lane3_LocalArt` look for them.
- **Fixed padding for icons, tight crops for shop art,** so art fits a box in its card and stays the focus (Adam, 2026-11-02: icons must fit their boxes).
- **Node, not compiled tools:** Application Control blocks new executables, so the art tools are plain JavaScript.
- **Images must be fetched before they're revealed:** a fully clear image is never drawn, so it never loads.

## Shop
- **Bangers for display, Fredoka One for reading.** Tested against Luckiest Guy, Sarpanch, Oswald and Titillium Italic. Bangers slants forward like speed and isn't any Roblox shop's default.
- **Rebuilt, not patched:** ShopCards, ShopArt and ShopLayout are gone. One recipe scaled by `k`, with a separate phone first page.
- **Style and Trails are one screen, StyleStudio.** Stunt Customize is the same screen in its own overlay, and StyleState holds what is owned and worn.
- **Extra Parking** replaces Expanded Paddock on screen (Adam). The offer id stays.

## The preview car
- **An original code-built car** (`art/tools/car.js`): lofted from hand-set curves, no real model, no badge. Fully Lane 3's preview; finished cars stay Brian L's.
- **Paint is the part colour; shells a hair larger carry alpha textures** for paint patterns, decals and details. A part must be at Transparency 0.02 or more for a texture's alpha to show.
- **Decals and details are baked in atlas space from the real surface,** so they run across seams and stop at glass.
- **Card pictures are rendered from the same meshes and textures,** so a card shows what the car shows, with one ViewportFrame on screen.

## Launch Pads
- **Pads stand far from the island and road** (x 6000 to 8800, y 1200), built on the client, and leave the world when nobody's on them.
- **RETRY goes straight into a run.** Speed is the point of retry, and the pad has been seen.
- **A portal closes any open panel.**
- **Portals in the beta stay open.** `TestLockedPortals` on `CarHopBeta` shows the locked cards in Studio.

## Run
- **The camera re-aims one step after Brian R's,** so his smoothing and jolts stay. "Higher" is the beta default.
- **Stamina lives on the run object as a `requestHop` field,** in front of his method. Ten bolts is the Round 2 proposal; a respawn gives 3. This is a stopgap for Brian R.
- **Free revives come first, then a PREVIEW 19 Robux respawn.** Adam asked for the Robux respawn. It touches run outcomes, so it's flagged to Brian L; removal is one line.
- **Results Cash is a PREVIEW formula.**
- **The window scale now covers the run HUD and two cards:** the phone rule made the Heat panel huge on a laptop.

## Tutorial
- **Six steps, Adam's list.** "Press START!" and "Walk up the ramp" are sub-lines of the first.
- **Steering is no longer a step:** his list doesn't have one, and a run teaches it.
- **Park is skipped in the beta:** it needs a Park control that doesn't exist yet.
- **Later hints are goal pills,** after the first and third trips home.

## Island
- **A path end stops according to what it meets** (`Layout.PathEnds`), instead of every end running 15 percent past its last point.
- **The garden ring's last four points each side are gone.** It ran past the outer avenues into a stub by the bridges.

## Summit Pass
- **One hand-set landmark table.** Stations are fixed because district lengths don't change with the seed; hazards bend around landmarks.
- **Pennant poles moved back 8 studs** from the lodge front: they stood within 4 studs of the road.

## Left alone on purpose
- **No audio in videos:** Application Control still blocks the recorder.
- **Figma step skipped:** Adam's brief supplies the mockups and asks for an autonomous round.
- **Icons are not uploaded:** no Open Cloud key. One package is ready.
