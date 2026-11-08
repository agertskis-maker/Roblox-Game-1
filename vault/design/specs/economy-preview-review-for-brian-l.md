---
title: Economy preview review - message for Brian L
date: 2026-11-05
tags:
  - lane2
  - lane3
  - economy
  - review
status: sent
---

# Economy preview review: message for Brian L (Lane 2)

From Adam (Lane 3, repository owner), written with Claude (claude.ai) on 2026-11-05. Claude read every file on `feature/lane2-economy-preview` (tip `Economy: Brian L approved the car-to-World list`, 2026-11-03) and `economy-v1.md`, compared them with `main`, Lane 3's beta (`integration/beta-2`) and Brian R's run (`feature/lane1-run-prototype`), and ran a rough pacing model. Nothing in your files was changed. Please answer in the Replies section at the bottom; short answers are fine.

## The short version

The preview is well built. The server decides every amount, every remote argument is type-checked, saves are Mock only, the Dev helpers refuse outside Studio, and the whole thing is switched off unless `Lane2EconomyPreview` is set. That is the right shape.

Before it replaces the beta stand-ins, it needs **four fixes** (two let one message mint billions or freeze the server), **six agreements** where your code and Lane 3's screens read the same thing differently, and **one design change** to the numbers, because neither car list paces the way section 10 of your document says.

## 1. Fixes (please do these first)

**F1. Distance is only checked at RunEnd, so one message can pay thousands of Milestones.** `Runs.report` raises `run.lastD` to any `d` up to 10,000,000 for every event kind, including `Hop` with `target = 0`, before anything checks it. `onEnd` then caps the end distance at `lastD + ...`, which is already huge.
- Example: one `RunEvents` batch `{ {kind="Hop", t=1, d=10000000, target=0}, {kind="RunEnd", t=2, d=10000000} }` gives 10,000,000 studs x 0.28 = 2,800,000 m = 5,600 Milestones: $560K in Downtown, $5.6B in Summit Pass, every run.
- Fix: check `d` on every event before it is used, against how far the run can have gone by time `t` (the traffic sequence's travelled distance at `t` plus a margin), and only raise `lastD` after that check passes. Lane 3's beta already does exactly this in `src/server/Beta/BetaRun.luau` (`travelledAt(t) + Caps.aheadStuds`, plus a "never backwards by more than N studs" check); copy it if it helps.

**F2. A far Hop can freeze the server for everyone.** `onHop` calls `run.sequence:ensure(d + 2_000)` with the client's `d`, so `d = 10,000,000` asks Brian R's sequence to generate traffic for 10 million studs in one server frame. F1's check, placed before `ensure`, fixes this too.

**F3. The 5-bolt Stamina limit is not enforced on the server.** Nothing caps Keys per run, so a modified client can claim or Joyride a car every 3 to 6 seconds for up to an hour. Cap claims plus Joyrides per run at the bolt count (5; Lane 3's tutorial run uses 8) plus any paid respawns, the way `BetaRun.Caps.claims` does.

**F4. There is no Cash cap.** Luau numbers stop being exact at about 9 quadrillion (2^53). Section 12 item 3 says the economy is capped well below that, but `Economy.addCash` has no cap. Please pick the cap (Lane 3 asked this as question 4 in `economy-v1-answers-from-adam.md`) and clamp in `addCash`.

Smaller: `StartRun` has no cooldown (it is cheap, but a cooldown like the shop's 0.75 s costs nothing).

## 2. Agreements needed (your code and Lane 3 disagree)

**A1. What `Copies` means.** Your code stores the lifetime total and never resets it (25 makes Gold, 250 makes Diamond). Lane 3's screens and the beta stand-in store copies at the current edition, starting again at 0 after each step. It is the same agreed save field with two meanings, so the day your server replaces the stand-in, every beta save's ladder reads wrong. **Recommendation: your meaning (lifetime total).** It is simpler and nothing is ever thrown away. Lane 3 will switch its screens and convert beta saves in Round 6 if you agree.

**A2. Which car is in which World.** Your Catalog has 11 / 9 / 7 cars by World tier (all six Commons in Downtown, all six Legendaries plus one Epic in Summit Pass, Rustbucket as the starter, Brawler in Dusty Highway). Adam's answers on `main` (2026-11-03) have 9 per World with the same rarity shape in each World (Putter, Rustbucket and Commuter as the three Loaners, Brawler in Downtown). Lane 3's screens and the beta use Adam's list. Adam's answers say your Catalog wins, so you may keep yours, but the team has to use one list. Section 3 below shows why neither list works with today's numbers on its own.

**A3. Removing a car from the Lineup.** Your `SetLineupSlot` needs a car id, and `refreshLineup` refills every empty spot with the best owned car. Lane 3's Lineup panel has a REMOVE button and the beta treats `carId = nil` as "take the car out". With your server, REMOVE would be undone instantly. **Recommendation:** `carId = nil` removes; the Lineup has no gaps; a spot the player emptied stays empty; auto-fill only places a new claim.

**A4. Run remote names.** Your `EconomyPreviewNet` has `StartRun`, `RunEvents`, `KeysComplete`, `RunGranted`; Lane 3's beta has `BetaRunStart`, `BetaRunEvents`, `BetaKeysComplete`, `BetaRunEnd`. Brian R has now been asked to wire both. **Recommendation: your names win** (you own `src/shared/Net` and the remotes contract). Lane 3 will make its beta bridge use your names in Round 6, so Brian R only ever wires one set. Please confirm.

**A5. Expanded Paddock.** Your `MaxParkingSpots` is 15 and nothing handles the pass. Adam decided the pass adds 3 bays on top of what was bought (up to 18): the saved `ParkingSpots` stays 2 to 15, the server publishes the plot attribute `ParkingSpots` as bought + 3 and sets `ExpandedPaddock = true` (details in `economy-v1-answers-from-adam.md`). Please confirm.

**A6. Robux.** Section 11 of `economy-v1.md` still recommends leaving the 19 Robux respawn out. Adam decided on 2026-11-02 that the respawn and every planned Robux purchase are in (non-negotiable), and the Starter Pack includes Brawler (decision 0038). Please update section 11 so the document matches. Round 6 builds the purchase pipeline as beta stand-ins (receipts, Game Passes, `PolicyService`) in the same "your module replaces it one for one" way as Round 5, with selling switched off in the published beta. It will need two save fields that are not on the agreed list, a receipt history and owned passes and trails. Lane 3 will propose their exact names in the vault; they need your "Agreed".

## 3. The numbers (design)

Claude ran a rough model of a player who alternates runs (3 Keys a run, about 1,500 m) with Lap Pay, buys the cheapest useful level or spot, and unlocks Worlds as soon as possible. Traffic odds come from Brian R's `RunSequence`, and the Common-to-Uncommon and fallback rules come from your `Runs.luau`. It is rough (no Heat, no failed hops, no menus), so read it as a comparison, not a forecast. The script is attached: `economy-pacing-sim.py`.

| Setup | World 2 unlocked | World 3 unlocked | What goes wrong |
|---|---|---|---|
| Your numbers, your list | about 3 h | about 10 to 11 h | Twice as slow as your own targets (1.5 to 2 h, then 2 to 3 h more). Summit Pass has only Monarch below Legendary, so every Common spawn there becomes Monarch. |
| Your numbers, Adam's list | about 15 to 35 min | about 1.5 to 2.5 h | Downtown has two Legendaries at $25,000 a lap, so World 2 opens almost at once. Then income stops growing: a new World adds more cars of the same rarities at the same pay. |
| Candidate: Adam's list, a World pay factor | about 2 h | about 4 h | Hits your targets. Late game still too short (level 12 in about 11 h). |

The candidate keeps your structure and adds one thing: **a World pay factor** (Downtown x1, Dusty Highway x40, Summit Pass x1,600, like your Milestone pay already does) with a **narrower spread inside a World** (Lap Pay $10 / $25 / $60 / $150 / $400 for Common to Legendary, claim bonus 10x and Joyride 3x Lap Pay). Every World then has its own Legendary moment, a later World always pays more, and the Starter Pack's Brawler is a Downtown Rare, not an early World 2 car.

Two things the candidate does not fix, for your spreadsheet:
- **The level 12 price wall.** Level 11 costs $25B and level 12 costs $2T (80 times more) for a multiplier step of 535 to 1,000 (under 2 times). Every earlier step is about 7 to 8 times more for about 1.9 times the pay. Either smooth level 12 or make its reward clearly special.
- **The late game is short in every setup.** "Weeks" (section 10) needs prices that keep climbing after World 3 or a goal that is not Cash (editions already are one).

Lane 3 recommends the candidate for the beta playtest, tagged PREVIEW, so the three of you play something that paces sensibly this week. Your numbers win the moment you send them.

## 4. Smaller notes

- **Keys times live in two places:** `Catalog.Rarities[*].keysSeconds` (unused by the server) and Brian R's `RunConfig.KEYS_TIME`, which the server checks. Pick one owner. Brian R's Circuit profile still uses 5 to 8 s Keys, which Adam declined on 2026-10-28.
- **The starter car is hard-coded** as Rustbucket in `Data.luau`. With either list it should come from the Catalog (the Downtown Loaner).
- **Uncommons from paint numbers** (a third of Common spawns) is a fine stopgap until Brian R answers your question 2.
- **The Galaxy look** is still yours to approve; Lane 3 shows a PREVIEW badge.

## 5. What Lane 3 does next (Round 6), so nothing surprises you

All of this is in `src/server/Beta`, `src/shared/Beta` and Lane 3's own folders, labelled as stand-ins, and none of it edits your files:
- The beta's run checks keep F1 to F3 (they already do).
- If you agree A1, A3 and A4: Lane 3 switches to lifetime `Copies`, the removal rule and your remote names.
- The candidate numbers go into Lane 3's PREVIEW module for the beta only, unless you answer with your own first.
- Robux purchases are built as stand-ins with selling off, and the two new fields are proposed in the vault.

## Replies

### Brian L

Please answer each line (Agree, or what you want instead):

1. F1 to F4 fixed by (date):
2. A1 `Copies` is the lifetime total:
3. A2 which car list:
4. A3 Lineup removal rule:
5. A4 your remote names win:
6. A5 Expanded Paddock to 18:
7. A6 section 11 updated, and OK to propose the two Robux fields:
8. Section 3, candidate numbers for the beta (or yours):
9. Cash cap:

_(your answer here)_
