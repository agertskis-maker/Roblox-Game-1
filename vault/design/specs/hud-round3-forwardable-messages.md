---
title: Round 3 messages from Adam to Brian R and Brian L
tags: [design, proposal, lane3, messages]
status: sent through the vault by Adam on 2026-10-28
date: 2026-10-28
---
# Messages from Adam (Lane 3) to Brian R and Brian L

Brian R, Brian L: this is from me, Adam. Your AI reads `AGENTS.md` and `vault/tasks/BOARD.md` at the start of every session, so I am sending these through the vault. Please read the sections meant for you (listed below), then write your answers under your own heading in **Replies** at the end of this file. Each message is plain language, with the source paths, the benefit, the risk and how to test. Nothing here is decided for your lane; these are my requests and proposals.

Agreed changes are separate from older held proposals. Lane 3 changed nothing in `src/client/Run`, `src/shared/Run`, `src/server`, `src/shared/Catalog` or `src/shared/Net`.

**Which sections are for whom**
- **Brian R:** sections 0, 1 (capture timing), 2 (hop target), 3 (run identity), 4 (held proposals).
- **Brian L:** sections 1 (capture timing), 3 (run identity), 4 (held proposals and the optional `RideTop` attachment), 5 (car uploads with the group as Creator).

These were first written on 2026-10-26 as drafts and sent on 2026-10-28. Where your PR #3 has since changed a fact, a dated note says so; the original details are kept.

## 0. For Brian R: your notes 0021 and 0022 (2026-10-28)
- **Note 0021 (what a run reports to the server) is Agreed** by me and by Brian L (Brian L agreed in person; I relayed it on 2026-10-28). It is posted on your PR #3. You merge after the GitHub check passes, per `AGENTS.md`. (On 2026-10-28 the PR's "Lint, format, and Rojo build" check was failing.)
- **Note 0022 is not decided as a whole.** My answers on its parts, 2026-10-28:
  1. **Circuit profile** (a crash ends the run, Keys take 5 to 8 seconds): **declined.** It conflicts with the decided rule that bumps add Heat instead of ending the run, and with my request for faster capture (section 1 below).
  2. **Rider Level gate:** **not decided.** Brian L and I will decide it together, because it touches the economy.
  3. **Free revives:** **deferred to later, not rejected.**
  The rest of note 0022 is not answered here. I did not edit your branch.

## 1. For Brian L (and Brian R for the timing): make capture a little shorter
**What we noticed.** In the Keys capture preview, holding on to a car feels slightly too long: my words were "a bit too long". The HUD only shows the time it is given; it does not set it.
**Where the current numbers are.** On 2026-10-26 I could not find a claim-time field in any code or Catalog (none exists in `src/shared/Catalog` today). The only written values are design documents:
`vault/design/car-hop-outline-v2.md` lines 337-340 (Common 3 s, Rare 4 s, Epic 5 s, Legendary 6 s) and `vault/design/cars/rarity-style.md` lines 92-96 (Uncommon 3.5 s, proposed).
*Note 2026-10-28:* Brian R's PR #3 now has these as code: `src/shared/Run/RunConfig.luau` `KEYS_TIME` and the `Highway` profile's `keysTime` (Common 3, Rare 4, Epic 5, Legendary 6; no Uncommon). The proposal below applies to those values.
**Proposal (a suggestion, not a decision).** New time = about 0.75 to 0.80 of the current one, keeping the order Common < Uncommon < Rare < Epic < Legendary and a floor of roughly 2.2 s so the three warning tiers and the "almost" moment still have time to read:

| Rarity | Today (design doc) | Proposed range |
|---|---|---|
| Common | 3.0 s | 2.3 to 2.4 s |
| Uncommon | 3.5 s (proposed) | 2.6 to 2.8 s |
| Rare | 4.0 s | 3.0 to 3.2 s |
| Epic | 5.0 s | 3.8 to 4.0 s |
| Legendary | 6.0 s | 4.5 to 4.8 s |

**Benefit.** Less waiting while the car is moving and Heat is running; more hops per run; children stay engaged. **Heat rule.** The outline says every family's Heat Capacity leaves at least 3 s to spare for a Legendary claim; a shorter claim only adds spare time.
**Risks to check.** The Stamina and Heat interaction (zero Stamina means Heat can no longer be reset by a hop), reward pacing (cars per run, Cash per minute), and fairness for rarer cars (the gap between tiers should stay obvious).
**How to test.** Run the same route with the old and new times; count claims per run; watch whether the warning tier colours and the "almost" word are still readable on a phone; ask three players if it feels "quick", "right" or "rushed".

## 2. For Brian R: hop target = closest car in range in the steering direction
**What existed on 2026-10-26.** `src/client/Run` and `src/shared/Run` were not in the repository yet (no branch had them), so there was no production selection code to read. The only selection is a Lane 3 playground stand-in, `playground/hud/scripts/HudPlayground.client.luau` lines 834-848 (`api.setHopTarget(index)`), which picks by traffic index and has no distance, steering or eligibility rules. It is a fixture and has no authority over production.
*Note 2026-10-28:* your PR #3 now has a selector, `findTarget` in `src/client/Run/RunController.luau` (around line 503), and a `HopRing` part. I have not reviewed or changed it; the questions below are about it.
**The design intent already written** (`vault/design/car-hop-outline-v2.md`, "The Hop"): the target is the nearest car within Hop range in the steering direction, straight ahead when not steering; one ring under it; no target means no ring and a harmless hop in place; range per family.
**Proposal.** Select the closest car in range **in the direction the player is steering**, with a stable tie-break and a little hysteresis so the ring does not flicker between two cars.
**Questions that change the answer:**
1. Are "forward, left, right" relative to the car's heading or to the road axis?
2. What counts as neutral steering (a dead-zone size), and is the direction a cone angle or a lateral shift?
3. Which cars are eligible: only same-direction traffic, never the ridden car, cars behind, cars mid-lane-change, cars across a gap? Is range centre to centre or horizontal only, and is the per-family range applied when selecting?
4. How are ties broken (equal distance, then smallest lateral error, then a stable id)?
5. What hysteresis keeps the target stable: a minimum hold time, a challenger must be closer by X studs or percent, a lock during the best-timing window? Which target is latched at the tap?
6. Does Foot Dash use the same selector from the avatar?
7. What does the selector output and how often (a `hopTargetId` and the car's footprint; `nil` at once or after a short grace)?
**What the HUD needs from you.** A single `hopTargetId` (and optionally a window id) that changes rarely; the HUD retargets immediately and only throttles the lock-on sound to once per 0.6 s, so any flicker would have to be removed in the selector.
**Benefit / risk / test.** Benefit: the ring always points at the car the player means. Risk: edge cases at lane changes and traffic gaps. Test: replay a recorded steering run and count target changes per second (a flicker shows as more than 3 changes per second with no steering input).
**What I did NOT do.** I did not change or copy any selection into production, did not add a remote, and did not touch range or timing.

## 3. For Brian R and Brian L (owners of the run and capture events): run identity for capture events
**What we found (Round 2 review, finding 9).** The HUD remembered which capture ids it had already shown so a repeated message could not show a car twice, but it never cleared that memory between runs, so it silently assumed capture ids are unique across runs. A late message from the previous run could also be shown as part of the new run.
**What Lane 3 did (presentation only, `src/client/UI/Prototype/Store.luau` and the capture widgets).** The preview store now keys its memory by the run: repeated callbacks in one run are ignored; a message whose run id differs from the active run, or that was issued before the run started, is shown as nothing (no tray +1, no SECURED card) while the store still records it flagged `stale` so a permanent reward is never lost on the Lane 2 side; a message with no run id belongs to the active run; a re-mounted tray restores its count from the store without replaying; memory clears only when a new run starts.
**Request.** Capture and confirmation events (`KeysStart`, `KeysConfirmed`, `KeysCanceled`, `AlreadyOwned`) should carry `runId` (a string, new for every run) and ideally an `issuedAt` time, and the run state should expose `run.runId`. Until then the HUD uses a per-run synthetic key, which works but cannot tell a late message from an old run if it has neither field.
*Note 2026-10-28:* note 0021 (now Agreed) has the server reply with a `runId` at run start, which covers the first half of this request; the capture events themselves still need to carry it.
**Owner.** Brian R (the run and its events) and Brian L (the confirmation event that carries the reward). Lane 3 will not edit either. **Benefit:** no wrong car or wrong count after a quick restart. **Risk:** low; one extra field. **Test:** end a run while a confirmation is in flight, start a new run, and check that the tray starts at zero and the late message does nothing visible.

## 4. For Brian R and Brian L: held proposals from earlier rounds (NOT new urgent requests)
These were written down earlier and are still **held**: Stamina events and rules (`HopAccepted`, `HopRejected{reason}`, `StaminaPickup`), the personal-best record and route loop, Cash pickup events and breakdown flag, capture countdown timing fields, `districtPlan.world`, the two-direction road and median contract, `collection{owned,total?}`, `shop.newItem`, the hop window and trajectory, `settings.haptics`. Full table: `vault/design/specs/hud-round2.md` section "Held interfaces" (on my branch `feature/lane3-hud-downtown-lookdev`). Nothing in Round 3 changes them, except that run identity (3) and the optional `RideTop` attachment on car models (below) are new.
**Optional for Brian L (car models):** an Attachment named `RideTop` at the roof centre of each finished car lets the HUD start the hop trail exactly on the roof. Without it the HUD measures the roof from the model's bounding box.

## 5. For Brian L: upload car meshes with the Car Hop group as Creator
I am creating a Roblox group to own the game. **When you upload car meshes, please upload them with the new Car Hop Roblox group as the Creator** once the group exists (in Studio's importer or upload dialog, choose the group instead of your own account), so they never need a re-import later. Assets do not move from a user account to a group; a user-owned mesh would have to be uploaded again under the group.
**To discuss, not an order:** `vault/decisions/0015-car-modeling-to-brian-l.md` says car meshes go under your account. If you have already uploaded car meshes under your own account, tell me in Replies which ones, and we will decide together whether to re-upload them under the group. I do not know whether you have uploaded any. (The 14 test car meshes from 2026-10-20, before the handover, are under my account `peskaface`, not yours; they are test uploads and will be redone for the published game.)
I will post the group's name and id on the board when it exists. Until then, keep uploading as you do now.

## Replies
Write your answers here, under your own heading, with the date. Please say which section each answer is for.

### Brian R

### Brian L
