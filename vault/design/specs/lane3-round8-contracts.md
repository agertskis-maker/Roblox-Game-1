---
title: Lane 3 Round 8 shared contracts (frozen by the lead)
tags: [lane3, round8, contracts]
---

# Lane 3 Round 8: shared contracts

Frozen by the lead (Claude Code, Opus 5.5) on 2026-11-08 before any builder started (R8-S08). A builder that needs a change asks
the lead; only the lead edits this file. Brief: `vault/design/specs/lane3-round8.md`. Ledger and agent map:
`vault/design/specs/lane3-round8-ledger.md`. Decision: [[0044-lane3-round8]] (0043 is taken by Brian L's proposed name note on
`feature/lane2-luck-in-beta`).

## 1. Where the work happens (lead's call, recorded)

- Round 7 put most Lane 3 work straight onto `integration/beta-5`; `feature/lane3-round7` lacks the Beta folders, Brian R's run
  and several Round 7 files (LuckPanel, PadParts, StyleStudio). Every Round 8 change needs Studio testing in the beta, so **every
  builder branches from `integration/beta-6`** as `agent/r8-<ws>`. The lead merges agent branches into `integration/beta-6`, then
  at the end copies the Lane 3 paths (`src/client/UI`, `src/client/Home`, `src/shared/UI`, `src/shared/Style`, `src/island`,
  `src/lookdev`, `vault`) onto `feature/lane3-round8` and the run paths (`src/client/Run`, `src/shared/Run`) onto
  `feature/lane1-round8-from-adam` (Brian R's PR #17 is not merged; `src/client/Run` and `src/shared/Run` on beta-5 equal
  `feature/lane1-round7-from-adam`).
- **Studio:** one Studio, file `Car-Hop-Art/CarHop-Beta-6-local.rbxl`, synced by `rojo serve beta.project.json --port 34900`
  from the **stage checkout** `C:\Users\agert\Documents\Roblox-Game-1-stage`. To test your branch: take `STUDIO_LOCK.txt`
  (your agent name and the time; at most 20 minutes), commit, run `git -C C:/Users/agert/Documents/Roblox-Game-1-stage checkout
  --detach agent/r8-<ws>`, wait about 5 seconds for Rojo, test, then `git -C ... checkout --detach integration/beta-6` and
  delete the lock. Never connect Rojo to the "Car Hop Beta" Studio window (the live place); never press Publish.
- **Blender:** `C:\Users\agert\Documents\Car-Hop-Art\BLENDER_LOCK.txt`, same rules. Safe mode stays on.

## 2. CarLook (C-01)

- Data: `src/shared/Style/CarLook.luau` (frozen, written by the lead). `Look = { car, paint?, decal?, wheels?, trail?, matchPaint? }`,
  ids from `CosmeticPreviewCatalog`; nil means factory paint, no decal, stock wheels, no trail.
- **Per player:** the save's `Equipped` (one id per tab) is the player's look; it applies to whichever car they ride or display.
  In a run, caught cars keep their own look; only the trail follows the player (C-02).
- Applier: `src/client/UI/Prototype/Style/CarLookApplier.luau` (API frozen; WS-1 builds the body).
  `apply(model, look, options) -> Handle`; `h:update(look)`, `h:setTrailSpeed(0..1)`, `h:burst("leap"|"dive"|"catch"|"flare")`,
  `h:moveTrailTo(model)`, `h:setWheelSpin(radians)`, `h:destroy()`. Options: `ghost`, `ghostTransparency` (0.65), `outline`,
  `lod` ("full" | "low"), `trail`, `reduceMotion`. Every user (Style Shop, tiles, launch card, Garage, Raceway cars, ghosts, run
  car) goes through it. It calls into Style.BodyPaint (WS-2a), Style.DecalArt (WS-2b), Style.WheelKit (WS-4, new) and
  Style.TrailFx (WS-5a); each of those keeps its current public API and may add to it, never break it.
- Per-car data (`src/shared/Style/Anchors/`, types in `Anchors/Types.luau`, keyed by Normal model name, positions relative to
  `Model:GetPivot()` at unscaled size): `Wheels` (WS-4: four hub CFrames +X out, radius, width, hideParts), `Exhausts` (WS-5a:
  one or two points +Z backwards, wheelSmoke), `DecalPanels` (WS-2b: left, right, size), `PaintParts` (WS-2a: body, never, mask).
- Server: the client only asks. `EquipStyle(tab, id)` and `BuyStyle(tab, id)` unchanged. New remote **`PickRideCar(carId)`**
  (name in `BetaConfig.Remotes`): server checks ownership, saves the beta field **`RideCar`** (template default "Putter"; listed
  for Brian L), publishes Player attribute **`BetaRideCar`**, answers `BetaResult("PickRideCar", ok, reason)`. `StartRun` uses the
  client's `startCarId` only if owned, else `RideCar`. WS-1 owns this.

## 3. Asset registry

- `src/shared/Style/AssetIds/init.luau` (frozen): `AssetIds.image(key)`, `entry`, `has`, `uploaded`, `UseUploaded`. One
  sub-module per workstream: `UpgradeCards` (WS-6a/6b), `HopButton` (WS-10), `Wheels` (WS-4), `Trails` (WS-5a), `Clover` (WS-9),
  `Hubs` (WS-8), `Plots` (WS-7), `Misc` (WS-11). Keys are lowercase `r8_<area>_<name>`.
- Builders put art as PNG in `C:\Users\agert\Documents\Car-Hop-Art\upload-round8\<key>.png` (meshes `<key>.fbx`, sounds
  `<key>.ogg`) and add the key with `id = nil`. **Only the lead uploads** (group LEGION STUDI0S, 74306252) and fills ids, and
  lists every asset in `vault/design/assets.md` (owner, source, licence). For Studio previews before upload, copy the PNG into
  `%LOCALAPPDATA%\Roblox\Versions\<current version>\content\carhop\r8\` (the local-art path only works in Studio with
  `ReplicatedStorage.Lane3_LocalArt`). Every user of art keeps a code-drawn fallback for `""`.

## 4. Shared UI pieces

- `src/client/UI/Prototype/R8Kit/GlossButton.luau` (API frozen; WS-6a builds the art and states): the one glossy action button
  and the one cannot-afford treatment (grey, "NEED $X MORE", green "+") for every card. States `buy | need | max | busy |
  disabled`; `Pressed`, `PlusPressed`. The amount shown comes from the server's `BetaResult` missing value or the server's Cash
  attribute minus the server-published price; the client never sends an amount.
- `src/client/UI/Prototype/R8Kit/` also holds WS-6a's card kit (KerbFrame, RibbonTitle, PreviewWindow, Pips). WS-6b uses them.
- **DialogueCard** (H-05): `src/client/UI/Prototype/Screens/DialogueCard.luau` is the one Roxy card (WS-8).
- **HopButton** (R-03): `src/client/UI/Prototype/Run/HopButton.luau` (WS-10).
- **Game font (O-09):** the bold rounded font already on most screens; WS-11 picks it after counting, records it, and applies it
  last (phase 2, after the other merges) through `src/shared/UI/Tokens.luau`.

## 5. File ownership (an agent edits only its own rows; anything else goes through the lead)

| WS | Agent | IDs | Owns (may edit) |
|---|---|---|---|
| WS-1 | Car look core | C-01, C-02, C-03, C-09 | `Style/CarLookApplier.luau`, `src/client/Beta/BetaRun.client.luau`, `src/server/Beta/BetaStyle.luau`, `src/server/Beta/BetaRun.luau` (StartRun car only), `src/server/Beta/BetaData.luau` (RideCar only), new `src/server/Beta/BetaRide.luau`, `RealCar.luau`, `Screens/GarageMock.luau` and the launch card files in `src/client/UI/LaunchPad/` except `PadParts.luau`, `src/client/Run/CarVisual.luau` (look hook only), new self-test |
| WS-2a | Paint mask audit | C-04, O-09 Galaxy paint | `Style/BodyPaint.luau`, `Style/PaintMasks.luau`, `Anchors/PaintParts.luau`, paint audit tool, `assets/cars` (only to split glass from body; each edit listed for Brian L) |
| WS-2b | Decal audit | C-05 | `Style/DecalArt.luau`, `Anchors/DecalPanels.luau`, decal audit tool |
| WS-3 | Style Shop | C-06, C-07, W-04 (tab UI, wheel cam), T-09 (tab UI, treadmill) | `Screens/StyleStudio.luau`, `StyleState.luau`, new files under `Style/Shop/` |
| WS-4 | Wheels | W-01, W-02, W-03, W-05 | new `Style/WheelKit.luau`, `Anchors/Wheels.luau`, `AssetIds/Wheels.luau`, the Wheels items in `CosmeticPreviewCatalog.luau` |
| WS-5a | Trail visuals | T-01, T-02, T-06, T-07, T-08, T-10, T-11, T-12 | `Style/TrailFx.luau` and new `Style/Trails/`, `Anchors/Exhausts.luau`, `AssetIds/Trails.luau`, the Trails items in `CosmeticPreviewCatalog.luau` |
| WS-5b | Trail moments | T-03, T-04, T-05 | new `src/client/Run/TrailMoments.luau`; one-line hooks in `RunController.luau` (coordinate with WS-10 through the lead) |
| WS-6a | Raceway card + kit | U-01, U-03, U-04, U-05, U-06 (Raceway) | `R8Kit/*`, new `src/client/Home/Island/Speedway/UpgradeCard/RacewayCard.luau`, `ShopPanel.luau`, `PreviewPanel.luau`, `Reveal.luau`, `AssetIds/UpgradeCards.luau` (raceway keys) |
| WS-6b | Parking card | U-02, U-03, U-04, U-06 (Parking) | new `UpgradeCard/ParkingCard.luau`, `AssetIds/UpgradeCards.luau` (parking keys only, after WS-6a's first commit) |
| WS-7 | Home plots | H-01, H-02, H-03 | `PlotOwners.client.luau`, `RichestRacers.client.luau`, `ParkingLook.luau`, new `ParkingGhosts.client.luau`, `AssetIds/Plots.luau` |
| WS-8 | Hubs and Roxy | H-04, H-05, H-07 | `CircuitComingSoon.client.luau`, `StuntCircuit.luau`, `Screens/DialogueCard.luau`, `Screens/PortalCardMock.luau`, `Portals.client.luau` (Roxy card only), HUD layout files for Missions and Settings, `AssetIds/Hubs.luau` |
| WS-9 | Lucky Clover | L-01, L-02, H-06 | `src/client/UI/LaunchPad/PadParts.luau`, `LuckPanel.luau` (kiosk art only), `AssetIds/Clover.luau`, Blender files outside the repo |
| WS-10 | Hop guidance | R-01, R-02, R-03, R-04 | `src/client/Run/*` except `CarVisual.luau` and `TrailMoments.luau`, `Prototype/Run/HopButton.luau`, `AssetIds/HopButton.luau` |
| WS-11 | Round 7 UI list | O-09 (except Galaxy paint) | `Screens/ResultsCard.luau`, Pit Stop panel files, `LuckPanel.luau` (odds text), `src/island` hydrant; phase 2: fonts across `src/client/UI` |
| WS-12 | Measurements | O-06, O-07, O-08 | no game files; reports in `Car-Hop-Art/review/round8/` |
| Lead | | S, O-01 to O-05, N, V, F | Git merges, `vault/` records, `BetaConfig.luau`, `assets.md`, locks, uploads, products, publish |

## 6. Hard lines every agent keeps

The client never sends an amount, price, odds or result; the server owns Cash, luck, stamina, prices, grants and what is owned.
ProfileStore only (Mock in tests). No countdowns, streaks, fake scarcity or unprompted purchase prompts; every Robux button states
its price. Original art only: no brands, logos, studs, fake sponsors; vehicle rules in AGENTS.md. `--!strict`, Trove, Signal,
Promise, `task` library. No destructive Git, no force-push, never edit `Packages`, `ServerPackages` or `src/server/vendor`.
Never send input outside the Studio window; never capture the desktop. Performance per `vault/design/specs/performance-budget.md`.
Agents never ask Adam anything: they ask the lead.
