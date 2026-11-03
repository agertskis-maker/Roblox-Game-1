# Car Hop: Launch Pad redesign (+ Stamina bolt change)

**For:** Claude Code, on Adam's Windows laptop, repository `Roblox-Game-1`.
**From:** Adam (repository owner, Lane 3 owner), written with Claude (claude.ai) on 2026-11-02. Lines marked **[ChatGPT]** were added by ChatGPT.
**Task folder (outside Git):** `C:\Users\agert\Documents\Car-Hop-Art\review\hubs\`
**Builds on:** Round 3 (`review\round3\BRIEF-ROUND3.md`, its `RESULT.md`, decision `0033-lane3-round3.md`, the Round 3 ledger), branch `feature/lane3-big-round` (draft PR #8) and `integration/beta-2` (draft PR #9).

The earlier rounds' rules still apply: Round 1 brief sections 2, 2.2, 2.3, 3, 5, 19 to 21; Round 2 section 1.1 and the same-view checks; Round 3 section 2 (your freedom) and section 2.1 (the "AI look").

> **Adam's chosen direction: B, "Sky Launch Platform"** (Claude's recommendation). If Adam edits this line to A ("Pit Garage") or C ("Open-Air Plaza"), build that one instead, with the same goals.

---

## 0. What Adam wants
> "I want to make a lot of big edits to the hub that appears when you enter a portal... I still want it to be simple, but it should be a little bit more designed. The portal just looks like a block, so that just needs to be changed... If I scroll out and zoom out, I could see outside of that little box where I spawn... I want that to be fixed... It should look stylistic, cool, and fun for kids."

> "Make it so that lightning bolts, or the stamina, are used up a little bit quicker... two per jump instead of one... or decrease the amount of lightning bolts from ten to five and then still use one per jump."

**Current state** (`review\hubs\current\`): each Launch Pad is a boxy room. It has plain walls, a gridded floor, flat lighting, block-shaped stalls with a flat sign, a parked block car, a block-shaped HOME portal, and a ramp at the back. Zooming out shows empty space outside. Also noticed in `pad-summit.jpg`: inside the Summit Pass pad, the tutorial banner still says "GO TO DOWNTOWN!" (a bug, if it happens outside the first-run tutorial path; check).

**References:** `review\hubs\chatgpt-images\` (`HUB-01` to `HUB-09`, from `review\hubs\CHATGPT-IMAGES-HUB.md`), plus ChatGPT's `GENERATION-NOTES.md` there. If an image is missing, work from the text of `CHATGPT-IMAGES-HUB.md`.

## 1. Your freedom
Same as Round 3: think like the lead designer. Research how popular Roblox games build lobbies and pre-round hubs. Try options, keep the best, and invent small touches that make kids smile. Record choices in the ledger and the decision note. Don't stop to ask Adam. The hard lines are unchanged:
- no edits to Brian R's or Brian L's files
- no new saved data without a plan
- PREVIEW prices only, no real purchases
- no paid gameplay advantage
- no merge or publish
- original art, no brands
- no destructive Git

## 2. Setup
**H-01** Pull `main`, continue on `feature/lane3-big-round`, and keep `integration/beta-2` updated. Claim a board row "Lane 3: Launch Pad redesign and bolt change - Adam, with Claude Code, 2026-11-0X". Commit and push only that board change to `main`.
**H-02** Ledger `vault/design/specs/lane3-launchpads-ledger.md`. Copy this brief to `vault/design/specs/lane3-launchpads.md`. Reserve the next decision number after 0033.
**H-03** Work in the local beta file (`Car-Hop-Art\CarHop-Beta-2-local.rbxl`), with dated backups before saving.

## 3. Goals for the Launch Pads (all three Worlds)

**L-01 Nothing outside is ever visible.** From any camera angle and any zoom, on phone and desktop, the player sees only designed scenery.
- **Direction B:** the platform floats high above a backdrop of its World (a simplified, cheap "World below" diorama or a painted panorama, plus clouds), with a matching sky and lighting while the player is in the pad. The sky and backdrop wrap all 360 degrees, including looking down past the edge.
- Also cap the camera zoom while in a pad (pick a distance that still feels free) and restore the island's camera settings on leaving.
- Prevent falling off the edge with a stylish rail plus invisible walls, and a safe respawn if someone glitches over.

Verify by orbiting the camera fully at maximum zoom in every pad, and save frames.

**L-02 A designed space, still simple.** One clear centerpiece, the **launch ramp and START gantry**, then three themed **kiosks** (CARS, TRAILS, PAINT), the **HOME portal**, and the **arrival pad**. Clean, open walking floor; a short walk (10 to 15 seconds across at most); every element readable at a glance. Follow the reference images for direction B, and adapt where Roblox needs it.

**L-03 The HOME portal is a real portal.** It is a compact version of the island's World portals (decorated pillars, a crest with a house icon, a swirling glowing field, sparkle and glow), never a block. Reuse the island portal rig and kit where you can. Walking in returns the player to the island in front of the portal they came from.

**L-04 Launch gantry and countdown.** A race start gantry over the top of the ramp, with 4 lights and the World name. When the player presses START on the launch card: the lights go red, red, red, green (about 0.4 s each), with a beep per light and a higher beep on green, and the run begins on green. Calm variant under Reduce Motion.

**L-05 Kiosks.** Each is a small themed pavilion with an awning, a chunky sign in the sign family, a floating, slowly bobbing 3D icon (use the uploaded icon art where it fits), and a glowing floor circle where the player stands to open it:
- **CARS** shows a real car on a turntable. Use Brian L's showroom car models (they reached `main` on 2026-11-02), displayed read-only; never edit `assets/cars`.
- **TRAILS** shows a car on a pedestal with a looping trail demo.
- **PAINT** is a spray booth.
Opening each still shows the existing panels (car picker, trails, paints), restyled if they clash.

**L-06 Arrival moment.** A short portal flash, the player appears on the arrival pad, a title banner "<WORLD> LAUNCH PAD" slides in for about 2 seconds, and a short line of yellow chevrons points to the ramp the first few times (and in the tutorial). Keep the HUD minimal in the pad.

**L-07 Themes:**
- **Downtown:** a night or sunset city below, neon accents, polished floor with racing stripes and a central Car Hop emblem.
- **Dusty Highway:** a desert canyon at golden hour below, retro gas-station style ("DUSTY STOP"), sandstone tiles, a vintage pump as decoration.
- **Summit Pass:** snowy peaks and a ski lift below, chalet roofs with snow, warm windows, a little fireplace, gentle snowfall.

One shared layout and code, three skins. Reuse the World kits (group-owned) first; build new Blender meshes only where they make a clear difference, packaged for one group upload (or Open Cloud if a key exists).

**L-08 Life, a little:** the turntable turns, the trail loops, the icons bob, the clouds drift, lights pulse gently, and a light ambient sound per theme. No clutter.

**L-09 Performance:** stay at or under the Round 3 measurements for the pads (185 to 389 parts) plus a sensible budget for the backdrop. Prefer meshes and decals over many parts, and measure with the same method as Round 3.

**L-10 Flicker-free:** run the overlap scanner in every pad, zero findings.

**L-11 The full loop still works:** island portal → pad → kiosks → ramp → launch card → countdown → run → results → RETRY (straight into a run) or HOME (back to the island). Fix the Summit banner text bug if it is real.

## 4. Stamina bolts (Adam's request)
**B-01** Make the bolts run out faster. **Claude's recommendation, used unless Adam changes it: 5 bolts per run, 1 bolt per hop** (simpler for kids than 2 per hop: one bolt equals one hop). Scale the respawn refund to match (for example 2 bolts back instead of 3), and resize the bolt meter so 5 bolts look full and bold.
**B-02** Re-check everything that depends on the bolt count:
- missions ("Hop 15" and "Hop 30" are across runs, keep them that way)
- the tutorial (the first run must still allow a claim; if 5 bolts make the first claim too hard, give the tutorial run a few extra bolts)
- the results screen's "out of bolts" message
Record the numbers as Tunable in the ledger and in Brian R's message (bolts touch his run).

## 5. Verification and finish
**V-01 Same-view comparisons:** for each pad, match the views in `review\hubs\current\`, before and after, plus a full camera orbit at maximum zoom. Save to `review\hubs\evidence\`.
**V-02** Two fresh reviewers. One scores each pad 1 to 5 on "stylish, fun for kids, simple", against the reference images. The other scores 1 to 5 on the "AI look" checklist. Rework anything under 4. Have the last fixes re-scored this time.
**V-03** A Play walkthrough of the full loop in every World, phone landscape and desktop. No errors in Output.
**V-04 Finish:**
- run the checks, commit, push, and update draft PRs #8 and #9 (no merge, no publish)
- update the board, log, ledger, decision note and `vault/design/assets.md`
- save the beta with a dated backup
- send messages to Brian R (bolts) and Brian L (showroom cars used in the pads, read-only)

Then a **short** terminal message and `review\hubs\RESULT.md` covering:
- what to open and try
- the status per goal
- the choices you made
- any steps that need Adam's hands (uploads)
- known issues
