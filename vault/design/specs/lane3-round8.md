# Catch A Car!: Lane 3 Round 8 (your car looks the way you made it, everywhere; home plots that read at a glance; upgrade screens that look premium; every Round 7 leftover closed)

**For:** Claude Code, on Adam's Windows laptop, repository `Roblox-Game-1`, in its own worktree `C:\Users\agert\Documents\Roblox-Game-1-round8`.
**From:** Adam (repository owner, beta integration person), written with Claude (claude.ai) on 2026-11-08 from Adam's Studio playtest of the Round 7 beta (`CarHop-Beta-5-local.rbxl`, `integration/beta-5`). His notes are quoted or paraphrased in each item and in full in Appendix A. Lines marked **[ChatGPT]** were added by ChatGPT.
**Task folder (outside Git):** `C:\Users\agert\Documents\Car-Hop-Art\review\round8\`
**Builds on:** Round 7 (`review\round7\RESULT.md`, `vault/design/specs/lane3-round7-ledger.md`, decision 0042), Round 6 (0041), the driving update and Stamina Shop (0040).
**References:** ChatGPT's images in `review\round8\chatgpt-images\` (with `GENERATION-NOTES.md` and `layers\`), last round's images in `review\round7\chatgpt-images\`, Round 7's frames in `review\round7\frames\` (they show what Adam is unhappy with), and the dino reference in `review\round7\references\`.

Every earlier round's rules still apply unless this brief changes them: Round 1 brief sections 2, 2.2, 2.3, 3, 5, 19 to 21; Round 2 section 1.1; Round 3 sections 2 and 2.1 (the "AI look"); Round 4 section 1; Round 5 section 1 (the client never sends an amount); Round 6 section 1; Round 7 sections 1 and R7-S09 (luck disclosure and PolicyService). **Round 4's R4-S09 and Round 7's R7-S08 execution rule ("one lead, at most two Sonnet reviewers") is replaced for this round by section 0 item 1.** Their truth rules stay (see S08).

---

## 0. What Adam decided for this round (2026-11-08)

These are decided. Do not re-argue them; record them in decision note **0043**.

1. **Work with many agents, and have Opus check them.** Adam: "Claude Code can add in as many Sonnet 5.5 agents as it needs to in order to complete the work, because I want it done faster ... delegating an agent to each task, maybe a review agent and just a bunch of different agents ... and then implement one Opus 5.5 agent to review all the work that the Sonnet agents do. And if there's something that needs to be fixed, have the Opus 5.5 agent fix it, or another Opus 5.5 agent fix it." How this works is in R8-S08. It is a MUST, not a suggestion: fan the work out to Sonnet 5.5 builder agents from the start, give each workstream its own Sonnet reviewer, and run one Opus 5.5 reviewer over everything with Opus 5.5 fixers.

2. **Include every Round 7 leftover** (Module O): the two permissions, uploads under the group, Robux products and test purchases, the PR merges, the publish, the long runs, the Heat measurement, the 360-degree Launch Pad check, and the Round 7 reviewers' open list.

3. **Push everything and bring branches up to date first** (Adam's standing request; this sentence is his explicit request to commit, push and merge). Sweep every local checkout exactly as Round 7 section 0 item 2 did. Merge PR #15 (`feature/lane3-round6`) into `main` once its check passes. PR #18 (`feature/lane3-round7`) merges into `main` at the end of this round together with this round's Lane 3 work, under the F-02 rule. Report the branch table.

4. **Where the work lives.** Lane 3 code on `feature/lane3-round8`, made from `feature/lane3-round7` (Round 7 is not in `main` yet). The beta on `integration/beta-6` from `integration/beta-5`. Run changes (cosmetics on the run car, the trail in the run) on `feature/lane1-round8-from-adam`, made from Brian R's branch if he merged PR #17, otherwise from `feature/lane1-round7-from-adam`, with a pull request into his branch. Never merge his or Brian L's branches.

5. **Lanes.** Round 7's permission to edit every lane (Brian R agreed) is carried forward for exactly the items in this brief. If a teammate has written otherwise in a vault Replies section since 2026-11-05, the teammate's reply wins; record it and route that item to a note for them.

6. **The Raceway upgrade and Parking upgrade screens** keep the racetrack-frame idea (red-and-white kerbs, chequered corners) but become far richer and glossier, **built almost exactly like ChatGPT's final reference images** (Module U). For these two screens, the Lucky Clover mascot and stand, and the trail and wheel icons, the images are the spec, not loose direction (R8-S07 explains).

7. **The Lucky Clover stand is run by a cute clover mascot:** a smooth, properly shaped four-leaf clover character with a face, arms and a little hat. Never "four circles" again.

8. **Your cosmetics show on your car in the run.** Paint, decals, wheels and trail must be visible on the car you start the run on. Adam: Round 7 did not do this in his play, even though Round 7 marked it done.

9. **Picking a car gives a clear confirmation** (the launch card's car was right; the confirmation was missing).

10. **The Stunt Circuit's outer sign and cones are deleted.** Keep the Coming soon preview sign that is already inside the Circuit.

11. **Robux selling stays off** in the published beta (`RealPurchases = false`). Products get created this round once the permission works.

12. **Publish to the private beta at the end** (place 118605678346800, LEGION STUDI0S, "Car Hop Beta") from your local beta file. This line is Adam's go-ahead. Nothing goes public.

13. **Use ParticleFX Studio's free effects for the trails (and any other particle effect that benefits).** Adam: "utilize these, I give it all permission." Claude Code has Adam's full permission to browse https://particlefx.studio/roblox, download as many of the **free** Roblox flipbook effects (PNG sprite sheets, 2x2, 4x4 or 8x8, free packs as ZIPs with each effect's settings) as it needs, upload them to Roblox under the group LEGION STUDI0S, and use them in the game. No further approval is needed for any of these steps. Details in T-12. The site's license (checked 2026-11-08): exported effects "may be used in any project, commercial games included, with no credit required"; only reselling the library as an effect pack is not allowed. The paid plan (the ready-made model) is not needed: build the emitters yourself.

14. **Not this round:** turning on real sales, a public publish, cross-server leaderboards, trading, new currencies, new Worlds, limited-time anything, paid luck.

## 1. Your freedom, and the hard lines

Think like the art director, lead designer and lead engineer of a top Roblox simulator. Adam's bar this round is "almost exactly like the reference" for the screens he named, and "perfect on every single car" for cosmetics. Research, try options, keep the best, record choices in the ledger and decision 0043, and **do not stop to ask Adam** except in R8-S04. No review web pages: say when you are done, and Adam walks through Studio himself.

MUST means do it. SHOULD means do it unless it costs more than a few hours or risks a MUST; record why not. MAY and "your call" mean choose, record, move on.

Hard lines (unchanged from Round 7, still binding on every agent):
- **The client never sends an amount, a price, an odds value or a result.** The server decides Cash, luck, stamina, prices, grants and what cosmetics a player owns. The client may only ask "equip item X on car Y"; the server checks ownership.
- **Saves:** the agreed fields plus the beta fields (`StaminaLevel`, `Purchases`, `Owned`, `LuckLevel`, `Style`). If this round needs a new field (for example a chosen car), it gets a line in the vault note to Brian L. ProfileStore only, tested with Mock.
- **Kids and fairness:** no countdowns, streaks, "only today", fake scarcity, nagging pop-ups, or a purchase prompt that opens without a press. Every Robux button states its Robux price.
- **Original art only**, no brands, no real logos, no Roblox studs, no fake sponsors, nothing copied from other games.
- **No destructive Git**, no force-push, never rewrite a teammate's text (add to Replies or new files). No agent edits `Packages`, `ServerPackages` or vendored code.
- **Never send keystrokes or clicks outside the Studio window**, never capture the whole desktop.
- **Performance:** every new effect fits `vault/design/specs/performance-budget.md`. Phone first: measure a mid phone profile and record parts, particles and frame time.

14. **Clearer dive guidance and new HOP and DIVE buttons** (added by Adam on 2026-11-08 mid-review). Adam: "once you hop, the second hop, in order to dive, it needs some kind of indication of where you're diving, more than just the yellow circle ... maybe some subtle arrows"; "the hop button and the dive button just look horrible ... ask ChatGPT for reference images and implement them"; "maybe we should delete the arrows before you hop and change it to the arrows that happen when you dive ... look back at the reference video and decide from that how the arrows should work." Claude (claude.ai) studied the reference stills and decided (details in Module R): **no guidance arrows while you ride; the guidance appears only during the float**, as a landing ring plus a subtle chevron arc showing your dive path; the button itself flips from HOP (up arrow) to DIVE (down arrow), exactly like the reference game's button does.

## 2. Setup

**R8-S01 Read first:** `AGENTS.md`, `vault/tasks/BOARD.md`, the latest log, decisions 0040 to 0042, `review\round7\RESULT.md`, `review\round7\VERIFICATION.md`, the Round 7 ledger, `vault/design/ui-style-guide.md`, `vault/design/specs/performance-budget.md`, every vault Replies section changed since 2026-11-05, this brief, `review\round8\chatgpt-images\GENERATION-NOTES.md`, and every image in `review\round8\chatgpt-images\` and `layers\`. Then look at the Round 7 frames named in each module below so you see what Adam disliked.

**R8-S02 Branches.** Section 0 items 3 and 4. Worktree `Roblox-Game-1-round8`. Claim the task on the board ("Lane 3 Round 8", Adam).

**R8-S03 Studio.** Respect `STUDIO_LOCK.txt`. Adam may still have `CarHop-Beta-5-local.rbxl` open from his review; if Studio is open, ask him to close it in your first message. Fresh local file `Car-Hop-Art\CarHop-Beta-6-local.rbxl` copied from the Beta 5 file, a dated backup, `rojo serve beta.project.json`. If the Rojo plugin needs a Connect click, ask in your first message and never again. Do not resize the Studio window for captures; use the device emulator or `Lane3ScreenProfile`.

**R8-S04 Permissions, asked once (MUST).** Round 7 was blocked on these. In your first message give Adam the exact clicks, numbered, one action per line, plain words, from the real current screens (check current Roblox docs; never guess labels): (a) the Studio MCP or Assistant permission that allows asset upload for this experience, with the creator set to the group LEGION STUDI0S, not Adam's personal account; (b) "Money & monetization" access (developer products and game passes) for this experience; (c) if an Open Cloud key is the better route, how to create one under the group with only the needed scopes, stored outside the repository (never commit a key, never ask Adam to paste it in chat). Also include the Rojo Connect click and the "close Studio" step. Wait for his "done" on these only. Verify each with one test upload and one test product read before relying on it. While waiting, all agents work on everything that needs no upload. Round 7 uploaded Coach Roxy's portrait (106010075891034) under Adam's account peskaface: re-upload it under the group once uploads work and swap the id.

**R8-S05 Ledger and decision.** `vault/design/specs/lane3-round8-ledger.md` (copy this brief to `vault/design/specs/lane3-round8.md`), decision `vault/decisions/0043-lane3-round8.md`. The ledger has an **agent map** (which agent did which IDs, its branch, its reviewer, the Opus verdict). Evidence types as in Round 7: self-test, Studio Play, frame, reviewer, Opus review. "Not done" is never written as a pass.

**R8-S06 Order and what to drop.** Order: S, then in parallel the workstreams in S08, then O, N, V, F. If time runs short, drop in this order and record it: X-08, X-07, X-06, X-05, O-09 items marked "minor". Never drop a MUST in H, U, C, W, T, L, R or F.

**R8-S07 Images: when they are the spec.** For **U-01 to U-05** (upgrade screens), **L-01 and L-02** (clover mascot and stand), **R-02** (HOP and DIVE buttons), and the **wheel and trail icons**, ChatGPT's final images are the spec: match layout, proportions, colours, outlines, gloss, icon style and spacing as closely as Roblox allows. How: build them from the uploaded text-free art pieces in `chatgpt-images\layers\` (frames as 9-slice ImageLabels, buttons as image states), with **live TextLabels** for all text and numbers (never baked-in text), then capture a frame at the reference's size and put it next to the reference in one comparison image. Iterate until the Opus reviewer agrees they match; record remaining differences and why. For everything else the images are direction, as in Round 7. Text always comes from this brief, never from an image (images may misspell). If the Figma MCP is connected in your Claude Code, lay the two upgrade cards and the HOP and DIVE button out in Figma first from the references (Adam's standing preference for UI work); if it is not connected, say so in the ledger and build directly.

**R8-S08 How the work runs: many Sonnet builders, one Opus reviewer (MUST, section 0 item 1).**
- **The lead** is this Claude Code session. It reads everything (S01), then before fanning out it **freezes the shared contracts** in `vault/design/specs/lane3-round8-contracts.md`: the `CarLook` data shape and applier API (C-01), the asset id registry (`vault/design/assets.md` plus a Luau `AssetIds` module), the UI component names (UpgradeCard, DialogueCard, HopButton), and the file ownership table. The lead owns Git merges, `STUDIO_LOCK.txt`, a new `BLENDER_LOCK.txt`, uploads, permissions, publishing and the final report.
- **Builders:** spawn Sonnet 5.5 agents with the Agent tool (`model: sonnet`), **as many as the work needs, at least one per workstream below, all independent workstreams at the same time from the start.** Split a workstream further when it divides cleanly (for example the paint-mask audit by car family). Each builder works in its own git worktree (`isolation: worktree`) on a branch `agent/r8-<workstream>` made from `feature/lane3-round8` (or from `feature/lane1-round8-from-adam` for run code), and gets in its prompt: its requirement IDs, the files it owns, the files it must not touch, the reference images, the acceptance checks, the hard lines from section 1, and AGENTS.md. It returns: what changed (file list), tests run with their real output, frames captured, and open problems. The lead merges finished agent branches one at a time and runs `./scripts/check.ps1` after each merge.
- **Shared tools are single-user.** Only one agent at a time holds Studio (`STUDIO_LOCK.txt`) or Blender (`BLENDER_LOCK.txt`): write your agent name and the time in the file, hold it at most 20 minutes, then release; the lead keeps a queue. Agents without the lock keep working on code, Luau type checks and offline checks. Never open a second Studio or Blender instance.
- **Sonnet reviewers:** when a builder reports done, a separate Sonnet 5.5 review agent checks that workstream against its acceptance checks and reference images (bounded: its own IDs, at most 15 frames). It reports defects; it does not fix.
- **The Opus reviewer:** one Opus 5.5 agent (`model: opus`) reviews **all** Sonnet work: every merged diff, every comparison frame next to its reference image, the self-test output, and the hard lines (server authority, no amounts from the client, ProfileStore with Mock, cleanup of connections and instances, strict Luau, performance budget). It writes a defect list with severity into the ledger. **Fixes:** the Opus reviewer fixes defects itself, or the lead spawns further Opus 5.5 fixer agents (one per defect cluster). The Opus reviewer then re-reviews. Repeat until no MUST defect remains, or the defect is recorded as blocked with evidence. The Opus reviewer's final verdict per workstream goes in the agent map.
- **Workstreams** (suggested split; the lead may refine it and records the final map):
  - WS-1 Home plots: H-01, H-02, H-03.
  - WS-2 Island and hub fixes: H-04, H-05, H-06.
  - WS-3 Upgrade screens: U-01 to U-05.
  - WS-4 Car look pipeline and the run car: C-01, C-02, C-03, C-09 (start first; WS-5 to WS-8 depend on its contract).
  - WS-5 Paint and decals on every car: C-04, C-05 (split by car family if useful; Blender work queues on the lock).
  - WS-6 Style Shop previews: C-06, C-07, C-08.
  - WS-7 Wheels: W-01 to W-05.
  - WS-8 Trails: T-01 to T-12.
  - WS-9 Lucky Clover: L-01 to L-03.
  - WS-10 Run guidance and buttons: R-01 to R-04 (run code, so its branch is `feature/lane1-round8-from-adam`).
  - WS-11 Round 7 leftovers that are code: O-06 to O-09.
  - Lead only: S-items, O-01 to O-05 (permissions, uploads, products, PRs, publish), N, V, F.
- **Truth rules (kept from R4-S09):** no agent asks Adam anything (agents ask the lead; the lead asks Adam only in S04); never invent approvals, uploaded ids, tool access, test results or reviewer scores; if Sonnet 5.5 or Opus 5.5 is unavailable, record it and use the closest available model, never claim a review that did not happen; one consolidated report at the end.
- **Speed:** Adam wants this done faster than Round 7. Parallelism is the main lever: never leave an independent workstream waiting for another.

## 3. Module H: home plots and the island

**H-01 Your avatar on your plot badge (MUST).** Adam: "it doesn't actually have your avatar, it just has an empty picture next to your name." The Round 7 badge (A-02) shows a blank image. Find the real cause before fixing; likely ones: Studio test players with negative UserIds (thumbnails do not exist for them), the thumbnail call failing silently, an image set on the server for a client-only content id, or an AlwaysOnTop/ZIndex problem hiding the ImageLabel. Fix:
- Use the headshot content for the plot owner (`Players:GetUserThumbnailAsync` with HeadShot, or the `rbxthumb://type=AvatarHeadShot&id=<UserId>&w=150&h=150` content string set on the client; verify which is current in Roblox docs), protected call, bounded retry, cached by UserId, re-checked against the plot's current owner when it returns.
- A designed placeholder while loading and for test players with negative ids: the player's first letter on a rarity-coloured circle, never an empty square.
- The same fix for every place that shows a headshot (RICHEST RACERS, Results, Missions if any).
- Acceptance: in Play Solo (real UserId) Adam's own face shows on his badge; in a 3-player local server the placeholder letters show; a frame of each; a note that the published beta shows real faces for everyone (checked in O-05 after publish).

**H-02 Name tags over other players' plots (MUST).** Adam: "we should have name tags above other people's lots, but not as large or prominent as the one on your own lot." Every occupied plot shows its owner's headshot and display name. **Your own:** the current big gold-rimmed badge with "YOUR RACEWAY". **Others:** about 60% of that size, white rim, no "YOUR RACEWAY" line, slightly lower than yours, readable from the island centre but never covering your own badge (yours draws on top). Empty plots show nothing. When a player leaves, their tag goes within 2 seconds; when a new player takes the plot, the new owner shows (never the old face). Test with three clients from the fountain and from each portal; frames.

**H-03 Parking spots show what is in them (MUST).** Adam: "there's no way right now to tell whether a parking spot is filled or not. I want a transparent version of the car that is on the raceway in the parking spot." Rules:
- Each parking spot belongs to one car slot of your Raceway lineup. **Filled spot:** a see-through "ghost" of exactly that car (same model, same paint, decals and wheels through `CarLook`), about 60% transparent, with a soft outline in its rarity colour, a gentle shimmer, and a small floating tag above it with the car name and its "$X/lap". The ghost is visibly not a real parked car (transparent, no collision, no shadow).
- **Empty spot:** clearly empty: the bay lines glow softly, a big "+" and the word "EMPTY" painted on the ground, and a short tag "Catch a car to fill".
- **Locked spot** (not bought yet, if the parking upgrade shows them): a padlock sign with the next price in the K/M/B format.
- Updates the moment a car is added, removed or swapped. Other players see the same ghosts on your plot. Ghosts are client-side visuals built from replicated plot data (no extra server parts per ghost).
- Performance: ghosts use the lowest LOD of the car model, no particles; measure part count with all six plots full.
- Picture: `R8-IMG-07`.

**H-04 Stunt Circuit: delete the outer sign and cones (MUST).** Adam: "there's some kind of sign interwoven that says COMING SOON STUNT CIRCUIT on the outside of the Stunt Circuit. There was already a sign that says coming soon on the inside, like a preview. I don't think it's necessary to have that sign and the cones on the outside, so delete that." Remove the Round 7 outer COMING SOON sign, its banner and the cones (A-03 dressing). Keep the inside preview sign. The gate stays closed on the server and visually (keep the barrier arm only if it is not part of the deleted set; your call, record it). Check nothing invisible is left behind (no stray collision, no floating parts). Frame from the island centre.

**H-05 Coach Roxy's speech card is proportional (MUST).** Adam: at the Dusty Highway and Summit Pass portals, Roxy's text ("Open Dusty Highway first for Summit Pass") is right, "but the text box looks extremely large and white, the text size needs to be larger or correlate with the size of the box, it looks unproportional." He likes Roxy's picture, the cars-needed preview and the Cash preview: keep them. Fix it as one reusable `DialogueCard` component used everywhere Roxy speaks:
- The speech box hugs its text (AutomaticSize on height, a max width of about 55% of the screen, padding about 16 px at 1080p scale), so there is never a large empty white area.
- Text size scales with the screen: TextScaled inside a `UITextSizeConstraint` (about 26 to 40 px at 1080p; record the numbers), bold rounded font, navy on cream (not plain white), a little speech-bubble tail pointing at Roxy's portrait.
- The progress bars and Cash preview sit below the line, same width as the box.
- Same look at Dusty Highway, Summit Pass, the tutorial and Welcome back. Check phone, tablet and desktop profiles; frames of both portals on phone and desktop. Picture: `R8-IMG-09`.

**H-06 Pit Stop floating sign raised (MUST).** Adam: the floating sign above the Pit Stop (current level and next level) "is blocking the lightning bolt icon on top of the Pit Stop shop. Increase its height a little to match the Lucky Clover height." On all three Launch Pads: put the Pit Stop's floating sign at the same height as the Lucky Clover's floating sign (measure the clover sign; match its world height), and check it clears the top of the bolt by at least 2 studs from every normal camera angle. If the clover sign itself is redesigned in L-02, align both to the final height. Frames on each pad. Picture: `R8-IMG-10`.

## 4. Module U: the Raceway and Parking upgrade screens

Adam: "the UI for the raceway upgrades as well as the parking spot upgrades just need a big upgrade. They look very plain right now. Ask for reference images from ChatGPT and implement that almost exactly, like to a T." Section 0 item 6 keeps the racetrack-frame idea, made far richer. Today's card is `review\round7\frames\U01-raceway-card.jpg` and `U01-parking-card.jpg`: flat cream panel, plain pills, a dashed kerb outline, a confusing "BETA" pill, no picture of what you get.

**U-01 Raceway upgrade card, built to `R8-IMG-01` (MUST).** The image is the spec (R8-S07). Expected content (text from here):
- A glossy 3D-looking racetrack frame (red-and-white kerbs with bevel and shine, chequered corners, a little car lapping the frame on hover/open), title ribbon "RACEWAY UPGRADE" with the level "LEVEL 5 / 15" (real numbers from the server).
- A big preview window framed like a trackside screen showing **what the next level adds** (X-01 explains how), with a "NEXT LEVEL" tag.
- A stat row: "LAP PAY x12 -> x23" with big outlined gradient numbers and a lap-pay icon.
- A "NEW AT NEXT LEVEL" row: up to three icons with one or two words each (from the real level data: "Bleachers", "Crowd", "Pit row").
- Level pips (one per level, filled up to now, the next one pulsing).
- The big glossy orange **UPGRADE** button with the Cash icon and price; when you cannot afford it, the same button shape in grey with "NEED $470 MORE" (one rule for every unaffordable button in the game, see O-09); at max level a gold "MAX LEVEL" badge replaces the button.
- The red X in the corner (44 px minimum) and a dark see-through backing behind the card.
- No "BETA" pill. "PREVIEW prices" becomes a small grey line at the bottom only while prices are previews.

**U-02 Parking upgrade card, built to `R8-IMG-05` (MUST).** Same family as U-01: frame of painted asphalt with white bay lines, a "P" parking sign on top, title "PARKING SPOTS", big "6 SPOTS -> 7 SPOTS", a preview of the parking area's next tier, a row of bay pips (filled, empty, next), the orange "BUY SPOT $40.5K" button, red X.

**U-03 States (MUST).** Both cards show every state from `R8-IMG-02` and `R8-IMG-06`: can afford, cannot afford, max level, buying (button pressed, waiting for the server, no double buy), and the **just upgraded** moment: the card flashes, confetti, the level pip fills with a pop, a short fanfare (Reduce Motion version), then the card shows the next level. A failed buy (server says no) shows a short red line and never takes Cash.

**U-04 Phone, tablet, desktop (MUST).** To `R8-IMG-03` and `R8-IMG-06` (phone 1688x780 landscape). Nothing cut off, buttons at least 44 px, text at least the style guide minimum. Comparison frames at all three profiles.

**U-05 Built from art layers (MUST).** Upload the text-free pieces from `chatgpt-images\layers\` (`R8-LAYERS-raceway-card.png`, `R8-LAYERS-parking-card.png`, `R8-LAYERS-buttons.png`; cut them into separate images with transparent backgrounds first, keep them at least 512 px on the long side, power-of-two friendly), set 9-slice centres for frames so they stretch without distorting the kerbs and corners, and list every id in `assets.md`. If uploads are still blocked when everything else is done, build the closest version with UIGradient, UIStroke and UICorner, record it as **partial**, and leave the swap to the uploaded art as one switch in the `AssetIds` module.

## 2. Setup

**R8-S01 Read first:** `AGENTS.md`, `vault/tasks/BOARD.md`, the latest logs, decisions 0040 to 0042, `review\round7\RESULT.md`, the Round 7 ledger (especially C-02, C-05, C-06, C-08, U-01, A-02 and the reviewer list), `review\round7\reference-video-notes.md` and `references\hop-sequence-sheet.jpg`, `vault/design/ui-style-guide.md`, `vault/design/assets.md`, every vault Replies section changed since 2026-11-05 (a teammate's reply wins over this brief; record it), ChatGPT's `review\round8\chatgpt-images\GENERATION-NOTES.md` and every image in that folder, and `review\round8\PHONE-NOTES.md` if Adam wrote one.

**R8-S02 Branches.** Section 0 items 3 and 4. Worktree `Roblox-Game-1-round8`. Claim the task on the board.

**R8-S03 Studio.** Respect `STUDIO_LOCK.txt`. Fresh local file `Car-Hop-Art\CarHop-Beta-6-local.rbxl` copied from `CarHop-Beta-5-local.rbxl`, a dated backup, `rojo serve beta.project.json`. If the Rojo plugin needs a Connect click, ask in your first message and never again. Do not resize the Studio window for captures; use the device emulator or `Lane3ScreenProfile`.

**R8-S04 Permissions, asked once (MUST).** Round 7 was blocked on these again. In your first message, give Adam the exact clicks, numbered, one action per line, in plain words, and wait for his "done" on these only: (a) asset upload for this experience **owned by the group LEGION STUDI0S** (Round 7's only upload, Coach Roxy's portrait 106010075891034, went to Adam's own account peskaface: re-upload it under the group and switch every reference); (b) "Money & monetization" (developer products and game passes) for this experience; (c) if an Open Cloud key is the better route for group uploads, how to create one under the group with only the needed scopes, saved outside the repository (never commit a key). Use the real current screens, not guessed labels. Verify each permission with one real test upload and one real test product read before relying on it. While waiting, every agent keeps working on things that need no upload.

**R8-S05 Ledger and decision.** `vault/design/specs/lane3-round8-ledger.md` (copy this brief to `lane3-round8.md`), decision `vault/decisions/0043-lane3-round8.md`, evidence types as in Round 7 (self-test, Studio Play, frame, reviewer). The ledger also holds the **agent map** (R8-S08). "Not done" is never written as a pass.

**R8-S06 Order and what to drop.** Start in parallel (R8-S08): the C-01 contract first (it blocks the Style Shop, the launch card and the run), then everything else at once. If time runs short, drop in this order and record it: X-04, X-02, X-03, X-01, O-09 items marked SHOULD, T-08, T-05, C-07. Never drop a MUST in H, R, U, C, W, T, L or F.

**R8-S07 How to use the images this round.**
- **Copy almost exactly (the spec):** the Raceway and Parking upgrade cards (R8-IMG-01 to 06 and their layer sheets), the HOP and DIVE buttons (R8-IMG-28 and `layers\R8-LAYERS-hop-dive-buttons.png`), the clover mascot and stand (R8-IMG-11, 12), the wheel and trail icons (`layers\R8-ICONS-wheels.png`, `layers\R8-ICONS-trails.png`). "Almost exactly" means: same layout and proportions, same colours (use the hex values in GENERATION-NOTES), same frame shapes, same icon art, same button shapes and states. Build the UI from ChatGPT's text-free art pieces (uploaded as images, 9-slice where a frame stretches) with **live text and live numbers on top**. Text always comes from this brief and the game's data, never from the picture (images misspell). Make a side-by-side frame of each screen (reference left, Studio right, same size) and keep iterating until the Opus reviewer scores it a match (R8-S08).
- **Direction (match the look, adapt to the game):** everything else.
- Build 3D (the clover mascot, the wheel rims, kiosk parts) in Blender through the Blender MCP; never ship a part-built shape where ChatGPT drew a smooth model. List every uploaded asset id in `vault/design/assets.md` with its owner (must be the group).
- If a Figma MCP is connected in Claude Code, lay the two upgrade cards and the Style Shop tabs out in Figma first from the reference measurements, then build from that (Adam's standing preference). If none is connected, record that and build directly.

**R8-S07b ChatGPT only finished Job 1 (status 2026-11-08, MUST).** ChatGPT ran out of usage. Done: all 28 R8-IMG images and `GENERATION-NOTES.md` with LAYOUT SPEC tables (use those hex values and percentages). **Not done:** the `layers\` folder is empty (no R8-LAYERS, R8-ICONS or R8-TEXTURES sheets), and the brief has no [ChatGPT] research lines. Before you start, check the folder again: if Adam has since added sheets there, use them. For anything still missing, make it yourself, matching the R8-IMG images and their LAYOUT SPEC exactly:
- **UI pieces (card frames, ribbons, buttons, HOP / DIVE layers, pips, chips, close button):** build them as clean art yourself (SVG or code-drawn shapes rendered to transparent PNGs with Python, or carefully cropped and background-removed from the R8-IMG images where a piece sits on a flat background), text-free, 9-slice friendly for frames, then upload. Side-by-side frames against the R8-IMG image still decide "match" (R8-S07, U-06, R-03).
- **Wheel icons:** render each Blender rim (W-01) to a transparent PNG at the same three-quarter angle, scale and lighting as R8-IMG-17. This is preferred anyway: the icon then matches the real rim.
- **Trail icons:** capture each finished trail in Studio on a plain background at the same framing (or crop the matching panel from R8-IMG-20 and 21), key out the background, uniform size.
- **Trail textures:** ParticleFX Studio's free flipbooks first (T-12); make your own only for gaps.
- **Research:** where the brief names an API or policy you are unsure of (rbxthumb, ViewportFrame limits, 9-slice, Trail/Beam/ParticleEmitter properties, group-owned uploads and products, Claude Code subagents and worktrees), check the current official docs yourself (create.roblox.com, code.claude.com or docs.claude.com) and record the date and link in the ledger.
Record in the ledger which pieces came from ChatGPT and which you made.

**R8-S08 Execution: many Sonnet agents, one Opus reviewer, Opus fixers (MUST, section 0 item 1).**
Adam wants this round finished faster by running many agents at once. Do it like this:
1. **The lead** is this Claude Code session. It reads everything (S01), writes the agent map into the ledger, and freezes the shared contracts before anyone builds: the `CarLook` module interface (C-01), the shared UI pieces (card frame, button, `DialogueCard` from H-05), the asset id registry (`vault/design/assets.md`), and the remote names. Only the lead does Git merges into `feature/lane3-round8`, `feature/lane1-round8-from-adam` and `integration/beta-6`, permissions, uploads, Robux products, publishing and the final report.
2. **Builder agents: Sonnet 5.5** (Agent tool, model "sonnet"). Spawn **as many as the work needs, all at once where the work is independent**, at least one per workstream in the table below; split a workstream further when its files separate cleanly (for example the paint mask audit by car family). Each builder works in its **own git worktree** (Agent isolation "worktree") on a branch `agent/r8-<workstream>` made from the right lane branch, so no two agents edit the same file. Each builder's prompt lists: its requirement IDs, the files and folders it owns, files it must not touch, the reference images to match, the acceptance checks, and these hard lines. Each returns: a diff summary, the tests it ran with their real output, the frames it captured, and anything not done.
3. **Studio and Blender are single seats.** An agent that needs Studio or Blender takes `STUDIO_LOCK.txt` or `BLENDER_LOCK.txt` (writes its name and the time), holds it for at most 20 minutes, and releases it. The lead keeps a queue. Agents without the lock work on code, self-tests and offline checks.
4. **Sonnet reviewers.** When a builder reports done, a separate Sonnet 5.5 review agent checks that workstream against its acceptance checks and its reference images (bounded set: the workstream's frames plus its references, at most 15 images). Reviewers report defects with evidence; they do not fix.
5. **One Opus 5.5 reviewer over everything** (Agent tool, model "opus"). After the Sonnet reviews, it reviews **all** the Sonnet work: every merged diff, every side-by-side frame against its reference, the self-test output, and the hard lines (server authority, no client amounts, ProfileStore with Mock, cleanup of connections and instances, strict Luau, performance budget, kids' fairness). It writes one defect list with severity into the ledger.
6. **Opus 5.5 fixers.** The Opus reviewer fixes defects itself, or the lead spawns more Opus 5.5 fixer agents, one per cluster of related defects, each in its own worktree. Then the Opus reviewer re-reviews. Repeat until no MUST defect is open or the defect is recorded as blocked with evidence. The Opus reviewer's final verdict goes in the ledger and RESULT.md.
7. **Agents never ask Adam anything.** They ask the lead. The lead asks Adam only in R8-S04.
8. **Truth rules (from R4-S09, still binding):** never invent approvals, asset ids, tool access, test results or review scores. If a model is unavailable, say so in the ledger and use the closest available; never claim a review that did not happen. One consolidated report at the end.

Suggested workstreams (the lead may split further, never merge two into one agent):

| WS | Agent(s) | Requirements | Needs Studio | Needs Blender |
|---|---|---|---|---|
| WS-1 Car look core | 1 Sonnet (start first) | C-01, C-02, C-03 | yes | no |
| WS-2 Paint and decal audit | 2 or more Sonnet, split by car family | C-04, C-05 | yes | some |
| WS-3 Style Shop previews | 1 Sonnet | C-06, C-07 | yes | no |
| WS-4 Wheels | 1 Sonnet | W-01 to W-05 | yes | yes |
| WS-5 Trails | 2 Sonnet (visuals; preview and run hooks) | T-01 to T-08 | yes | no |
| WS-6 Upgrade screens | 2 Sonnet (Raceway card; Parking card) | U-01 to U-06 | yes | no |
| WS-7 Home plots | 1 Sonnet | H-01 to H-03 | yes | no |
| WS-8 Hubs and NPC text | 1 Sonnet | H-04 to H-07 | yes | no |
| WS-9 Lucky Clover | 1 Sonnet | L-01, L-02 | yes | yes |
| WS-10 Hop guidance and buttons | 1 Sonnet (on the lane 1 branch) | R-01 to R-04 | yes | no |
| WS-11 Round 7 leftovers, UI list | 1 Sonnet | O-09 | yes | no |
| WS-12 Long runs and measurements | 1 Sonnet | O-06, O-07, O-08 | yes | no |
| Lead only | | S, O-01 to O-05, N, F | | |

## 3. Module H: home island and hubs

**H-01 Your real avatar on your Raceway badge (MUST).** Adam: "it doesn't actually have your avatar. It just has like an empty picture next to your name." Find why the headshot is blank (likely causes, check each and record which it was: the thumbnail call failing or never retried; the image set before the BillboardGui exists on the client; a streamed-out adornee; or test players with negative UserIds in a local Studio server, which have no thumbnail). Fix:
- Use the headshot content string `rbxthumb://type=AvatarHeadShot&id=<UserId>&w=150&h=150` on the client (no server round trip), with `Players:GetUserThumbnailAsync` as a fallback, a cache by UserId, and one bounded retry.
- For players with no thumbnail (negative ids in local tests, or a failure), show a styled placeholder (a round badge with the player's initial in the game's font), never an empty square.
- Same fix for the RICHEST RACERS board headshots and any other headshot in the game.
- Acceptance: in Studio Play (real UserId) your face shows on your badge within 3 seconds of joining; in a 3-player local server each badge shows a face or the initial placeholder, never blank; frame from the fountain.

**H-02 Name tags over other players' plots (MUST).** Adam: "we should also have name tags above other people's lots, but it shouldn't be as large or as prominent as the one on your own lot." Every occupied plot shows its owner's headshot and username above its Raceway. Yours stays as today: big, gold rim, "YOUR RACEWAY". Other players' tags: about 55 to 60% of your badge's size, white rim, no "YOUR RACEWAY" line, slightly lower in the air, readable from the island centre but not shouting across the whole map (your call on `AlwaysOnTop` for others; your own keeps it). Each tag shows that plot's owner (it changes when the owner leaves and someone new gets the plot; recheck ownership when a thumbnail returns). Empty plots show nothing. Acceptance: 3-player local server, each client sees its own big gold badge and two smaller white ones; frame from the fountain and from one plot looking at the others.

**H-03 Parking bays show which cars are out racing (MUST).** Adam: "there's no way right now to tell whether a parking spot is filled or not. So I want to add a transparent version of the car that is on the raceway into the parking spot." Build to R8-IMG-07:
- A filled bay (its car is racing on the Raceway) shows a **ghost of exactly that car**: the same model, the player's paint and wheels on it, about 60 to 70% transparent, a soft outline in the car's rarity colour, a faint shimmer, and a small floating tag with the car's name and rarity colour. Ghosts never collide, never cast shadows, and never block walking.
- An empty bay (owned, no car) looks clearly empty: dashed outline, a "+" and "EMPTY" painted on the ground.
- A bay not yet bought (if bays for sale are shown) shows a padlock and the next spot's price, matching the Parking card.
- When a car is added, removed or swapped, its ghost appears or vanishes with a short fade, at once, from the server's plot data (no polling loops).
- Performance: ghosts are client-side visuals, one per filled bay, low detail model if one exists; measure parts and draw calls with all bays full.
- Acceptance: with 2 cars racing and 4 owned bays, Adam sees 2 ghosts and 2 empty bays at a glance; frame.

**H-04 Delete the Stunt Circuit's outer sign and cones (MUST).** Adam: "there's some kind of sign interweaved that says coming soon stunt circuit on the outside ... There was already a sign that says coming soon on the inside ... So I want you to just delete that." Remove the outer COMING SOON sign, its barrier arm and the cones added in Round 7 A-03. Keep the existing Coming soon preview sign inside the Circuit. The Circuit stays closed on the server and to walking (keep or add an invisible wall where the barrier was, so nobody walks in). Frame from the island centre (R8-IMG-24).

**H-05 Coach Roxy's speech box fits its text (MUST).** Adam: "the text box just looks extremely large and white ... the text size needs to either get a little bit larger or somehow correlate with the size of the text box ... make it look proportional and do the same thing for Dusty Highway." He likes the speech, the new Roxy picture, and the preview of how many cars and how much Cash you need: keep all of those. Build one shared `DialogueCard` component used by every Roxy card (Dusty Highway portal, Summit Pass portal, tutorial, Welcome back if she appears there), to R8-IMG-09:
- The bubble sizes itself to the text (`AutomaticSize` with a maximum width of about 46% of the screen), with comfortable padding, so there is never a big empty white area.
- Text is large and bold: about 30 to 36 px at 1080p for the main line (scaled per screen with `UITextSizeConstraint`, minimum 20 px on phones), navy on cream, never tiny in a big box.
- Roxy's portrait overlaps the left edge of the bubble; the bubble has a small tail pointing to her; the progress bars (CARS, CASH) sit under the line, then GOT IT.
- Acceptance: frames of the Dusty Highway and Summit Pass cards at desktop, phone landscape and tablet; the text fills its bubble with even margins at all three.

**H-06 Pit Stop's floating sign sits higher (MUST).** Adam: the floating sign that shows your level and the next level "is kind of blocking the lightning icon on top of the Pit Stop ... increase it in height a little bit to match the Lucky Clover height." On all three Launch Pads, raise the Pit Stop's floating sign to the same height as the Lucky Clover's floating sign, and at least 2 studs clear of the top of the lightning bolt model's bounding box (measure, do not guess). Frame of both kiosks side by side, signs level (R8-IMG-10).

**H-07 Tighter spacing between Missions and Settings (MUST).** Adam: "the spacing between the settings and the missions icon when you're in the hub before you're about to play ... they're very far apart. Just move them a little bit closer together." On the island and the Launch Pads, find the gap between the Missions button and the Settings button in the HUD and bring them closer, so the gap matches the even spacing used between Shop, Garage and Missions (one shared spacing value in the HUD layout, not a hand-placed offset). Check it does not collide with the goal banner, the Cash display or the phone's safe area. Frames at desktop, phone landscape and tablet, before and after (R8-IMG-23 shows the target spacing).

## 4. Module R: hop guidance and the HOP / DIVE button (Brian R's lane, on `feature/lane1-round8-from-adam`)

Keep Brian R's structure and naming; each change gets a line in the vault note to him (N-01).

**What the reference game does (Claude re-checked `hop-sequence-sheet.jpg` and the notes on 2026-11-08):** while you ride, there are **no arrows on the ground**; only a small, faint yellow lock-on mark sits by the animal you are lined up with. When you press once and leap, a **big bright yellow ring** appears on the ground under the target, and the round button bottom right **flips its icon from an UP arrow to a DOWN arrow** (the same button, now meaning "dive"). On PC a small "Space" keycap label sits under the button. The guidance gets loud only at the moment you need it.

**Decision for Catch A Car! (Claude's call from the reference and Adam's notes):** follow the reference's quiet-then-loud pattern, and add the dive arrows Adam asked for, because a car on a road is harder to read at speed than an animal on grass.

**R-01 Delete the pre-hop arrows; quiet lock-on while riding (MUST).** Adam: "right now we have arrows before you hop, but maybe we should just delete those arrows and change it to the arrows that happen when you dive." Remove the arrows shown before the first press. While riding, the best target gets only a **subtle lock-on**: a thin, semi-transparent yellow ring on the road under it (about 40% opacity, slow pulse) and its floating label grows a little. No ring if no car is reachable.

**R-02 Clear dive guidance after the leap (MUST).** Adam: "the second hop, in order to dive, it needs to have some kind of indication of where you're diving, more than just the yellow circle ... maybe some kind of subtle arrows." After the first press, while you float, to R8-IMG-27:
- The lock-on ring becomes the **big bright landing ring** (full opacity, thicker, a gentle pulse, a soft glow on the road), as in the reference.
- A **dive path**: a short curved line of 4 to 6 small chevron arrows from just below the player down to the ring, flowing toward the target (the chevrons slide along the curve), semi-transparent white with a yellow edge. Subtle: thin, never covering the target car or the HUD.
- **Three small chevrons around the ring pointing inward** (a landing marker), rotating slowly.
- The target car gets a soft yellow outline (Highlight or a cheap equivalent) so you see which car, not only which patch of road.
- When you steer the float and the best target changes, the ring and the dive path **swing smoothly** to the new car (about 0.12 s) with a soft tick sound; they never flicker between two cars (add a small hysteresis and record the value).
- If no car is reachable, there is no ring and no path; the DIVE button shows its "no target" state (R-03) and pressing it drops you straight down (current rule).
- In the tutorial and the first two runs the path and ring are a little brighter and "PRESS AGAIN!" flashes on the button (keep Round 7's longer float).
- Reduce Motion: the chevrons stay still, the ring does not pulse.
- Client-side visuals only; the server still validates the dive by time and distance exactly as Round 7 set it.

**R-03 New HOP and DIVE button (MUST).** Adam: "the hop button and then the dive button, they just look horrible ... ask ChatGPT to make reference images for those and just implement them." Build it **almost exactly** to R8-IMG-28 from the text-free art in `layers\R8-LAYERS-hop-dive-buttons.png` (R8-S07):
- One big round glossy button, bottom right, thumb-reachable inside the phone safe area (about 132 px at 1080p desktop, about 15% of screen height on phones; never under 44 px touch target).
- **HOP state:** chunky white UP arrow with a dark outline, the word "HOP" under the arrow, the game's orange "go" colour with a bright rim.
- **DIVE state:** the arrow flips to point DOWN with a quick squash-and-flip animation, the button turns bright yellow with a pulsing glow ring, the word "DIVE".
- **Pressed** state (pushes in, darker), **"no target"** state for DIVE (dimmed), **out of stamina** state (grey with an empty bolt), and a thin ring that drains while you float, showing how long you have left to dive.
- On PC a small keycap "SPACE" label under the button; on gamepad an "A" badge; nothing extra on touch.
- Remove every old hop or dive button art and any duplicate button.
- Acceptance: frames of all states at desktop, phone landscape and tablet next to R8-IMG-28; the Opus reviewer scores them a match.

**R-04 Feel check (MUST).** Play at least 15 hops in Downtown with the new guidance (Studio Play). Record: how often a dive lands on the car the path showed (target: every time the path was shown), whether the path ever pointed at a car you could not reach (target: never), and the frame time with the path visible on the phone profile. Capture a 3-frame sequence (riding with quiet lock-on, floating with the dive path, landing) for the Opus reviewer.

## 5. Module U: the Raceway and Parking upgrade screens (copy almost exactly)

Adam: "the UI for the raceway upgrades as well as the parking spot upgrades ... just need a big upgrade. They just look very plain right now, so I want you to really ask for reference images from ChatGPT and implement that almost exactly ... almost like to a T." Round 7's version is `review\round7\frames\U01-raceway-card.jpg` and `U01-parking-card.jpg`: flat cream box, thin dashed kerb border, plain pills, a confusing "BETA" button. Direction chosen by Adam: **keep the racetrack frame idea, make it far richer and glossier.**

**U-01 Raceway upgrade card (MUST).** Built to R8-IMG-01 (desktop), R8-IMG-02 (states) and R8-IMG-03 (phone), from `layers\R8-LAYERS-raceway-card.png` and `layers\R8-LAYERS-shared-ui.png`. Expected pieces (follow the image where it differs): a thick glossy kerb frame with real depth (bevel, highlight, shadow), chequered corner blocks, a chequered-flag title ribbon across the top with "RACEWAY LEVEL 5" (live number), a large framed **preview window** of the next level (U-04), the stat row "LAP PAY x12 -> x23" as big outlined gradient numbers with icons, a "NEW AT NEXT LEVEL" row of 2 to 4 icon chips naming what the next level adds (from the real level data, not the picture), a row of level pips (filled up to your level, one per level, 10 to 15), a big glossy orange UPGRADE button with the Cash icon and price, and a round red close button that never gets cut by the frame.

**U-02 Parking upgrade card (MUST).** Built to R8-IMG-04 (desktop), R8-IMG-05 (states) and R8-IMG-06 (phone), from `layers\R8-LAYERS-parking-card.png` and the shared pieces: an asphalt-textured frame with painted white bay lines and the same glossy depth, a big blue "P" sign badge on the top edge, title "PARKING SPOTS", "6 -> 7 SPOTS" big, a strip of bay icons (filled bays show a small car silhouette, owned empty bays dashed, the next bay glowing), a preview of the next parking tier if the tier changes the look, and the orange "BUY SPOT" button with price.

**U-03 States (MUST), for both cards, to R8-IMG-02 and R8-IMG-05:** can afford (orange button, gentle shine sweep); cannot afford (the button stays the same shape, turns grey with "NEED $470 MORE", and a small green "+" opens the Cash shop page: the same treatment on every card in the game, fixing Round 7's orange-here-grey-there mismatch); max level (gold "MAX LEVEL" badge replaces the button, pips all gold); buying (button presses in, short spinner on the server round trip, never double-charges); just upgraded (U-05).

**U-04 The next-level preview (MUST, Round 7 U-01 left it out).** In the preview window, show what the next level adds. Recommended: a `ViewportFrame` that renders the actual next-level decoration pieces of the player's own Raceway at small scale, slowly turning, lit to match the reference (your call if a cheaper method looks as good; record it). Also a **PREVIEW ON MY TRACK** button (SHOULD): closes the card for 4 seconds and shows the next level's new pieces as a translucent blue hologram on the real Raceway, then reopens the card.

**U-05 The upgrade moment (MUST).** After a successful upgrade: the card's button bursts into confetti, the pips fill with a pop, the card closes, the camera eases to the Raceway, the new pieces build in with a quick scale-up and dust puff, and the level banner shows only the new level (Adam's 2026-10-29 rule). Sound plus a Reduce Motion version.

**U-06 Exactness check (MUST).** For each card and each state: a side-by-side frame (reference left, Studio right, same pixel size) at desktop and phone landscape, saved in `review\round8\frames\`. The Opus reviewer compares layout, proportions, colours, outlines and icon art and lists every visible difference; the builder fixes until only text differences remain (text comes from the game). Remove the "BETA" button from these cards (Round 7 reviewer: confusing). Keep "PREVIEW prices" small at the bottom if prices are still PREVIEW.

## 6. Module C: your car looks the way you made it, everywhere

**C-01 One `CarLook` source of truth (MUST, WS-1 starts here, contract frozen by the lead before other agents build).** Today paint, decals, wheels and trail are applied in several places by different code, and the run does not show them. Make one shared module (for example `src/shared/Style/CarLook.luau` plus a client applier) that:
- takes a car model and a look (`paint`, `decal`, `wheels`, `trail`, plus the car id) and applies it the same way everywhere: Style Shop turntable, shop tiles (C-06), launch card, Garage, Raceway racing cars, parking ghosts (H-03), and the run car;
- is driven by the server's saved `Style` data; the client asks to equip, the server checks ownership and replicates the look;
- cleans up everything it creates (emitters, beams, decals, wheel models) when the look changes or the car is removed;
- keep Round 7's rule for whether a look belongs to one car or to the player (read the `Style` save); if it is per player, the look applies to whichever car you ride or display. Record which.

**C-02 Your cosmetics in the run (MUST).** Adam: "when I go into a run, I do not see the trail or any of the decals or anything that I did on my car." Round 7 marked this done (C-08, with a frame), so first find out **why the earlier check passed and Adam's play failed** (different spawn path in `integration/beta-5`, a self-test that dressed the car directly instead of going through the real run start, a client that applies the look before the run car exists, streaming, or the place Adam played). Record the root cause. Then, through `CarLook`:
- the car you start the run on wears your paint, decal and wheels from its first frame (no pop-in after a second);
- your trail runs from that car's exhausts, and **the trail follows you to every car you hop onto** in the run (Claude's call: the trail belongs to you; caught cars keep their own paint, decals and wheels because you are catching them as they are; Adam may reverse this);
- an end-to-end self-test goes through the real path: equip a paint, a decal, wheels and a trail through the real remotes, start a run through the real launch-pad START, wait for the run car, then assert on the run car itself (painted body parts have the paint colour or material, the decal instance exists on the right panels, the wheel models match, the trail emitters exist and are enabled), hop once and assert the trail moved to the new car. It fails loudly if any of these is missing.
- Acceptance: a frame from the chase camera in a Downtown run showing all four cosmetics (R8-IMG-26), in all three Worlds.

**C-03 Confirmation when you pick a car (MUST).** Adam: "when you're trying to pick your car right before you start ... it doesn't give me some kind of confirmation for the car that I chose." To R8-IMG-25: after you choose a car (CHANGE CAR on the launch card, or RIDE THIS CAR in the Garage), the launch card's turntable swaps to the new car with a sparkle burst and a short "whoosh", a green check stamps onto the card, a toast says "READY TO RIDE: PIZZA TRUCK" (the real car name), the car name and rarity tag update, the CHANGE CAR button shows a small portrait of the chosen car, and the card's rows list the equipped "PAINT", "DECAL", "WHEELS", "TRAIL". The choice is saved on the server and is the car you start the run on.

**C-04 Paint only on paint, on every car (MUST).** Adam: "when I put on a fresh lime paint on my pizza truck, it's covering the windows and the windshield ... as well as the back windshield ... you need to go over that with every single different car and make sure the decals work really well and that they're perfect." Round 7 left Apex, Viper Strike and the Rainbow editions partial and Putter's top unpainted.
- List every car in the catalog (all Worlds, all rarities, all editions). For each, define which parts are **body paint** and which never change: windows, windshield, rear window, lights, tyres, rims, grille, chrome trim, interior, number plate, sign boards (like a pizza sign), roof racks. Follow R8-IMG-14 (the paint-mask guide).
- Where one mesh mixes body and glass, split it in Blender (one at a time, `BLENDER_LOCK.txt`) or use a mask texture; every edit to Brian L's car models goes in the note to him (N-02).
- An automated audit: for every car, apply a loud test paint (pure magenta), then list every part that changed and flag any part whose name, material or transparency says glass, light, tyre or rim. Zero flags is the pass.
- A **contact sheet** per car family: each car in magenta, then in a gradient and an animated paint, three-quarter front and three-quarter back. Saved in `review\round8\frames\paint-audit\`. Sonnet reviewers check them; the Opus reviewer signs off.

**C-05 Decals perfect on every car (MUST).** Adam likes the decal variety. Make each decal sit on the body panels of every car: never across windows, wheel arches, lights or the gap between doors; mirrored correctly on both sides; scaled to the car's panel size (a tiny compact and a long pizza truck both look right). Per-car decal anchors (attachments or panel faces) where the automatic fit fails. Contact sheet of every car with three decals (stripes, flames, the number "07") at `review\round8\frames\decal-audit\`. R8-IMG-15 shows good placement.

**C-06 Shop tiles show YOUR car (MUST).** Adam: "you don't have the cars under the images ... when I'm looking at the fresh lime color, when I have the pizza truck equipped ... it is showing me the sports car." Every Paint and Decal tile shows the item on **the car you currently have selected**, not a generic sports car (R8-IMG-13). Performance: render each tile once into a static `ViewportFrame` with a low-detail copy of your car (or a cached snapshot), only the hovered or selected tile turns; rebuild the tiles when you change car. Tapping a tile tries it on the big turntable at once (TRY), BUY and EQUIP stay as they are.

**C-07 Style Shop polish (SHOULD).** An "EQUIPPED ON: PIZZA TRUCK" line above the buttons; a toast "Equipped!" with a sparkle on equip; owned items show a green check; the four tabs keep their icons.

## 7. Module W: wheels, rebuilt

Adam: "the rims are still not showing up in the preview ... They look absolutely horrible. The previews aren't even correct. Everything with the wheels needs to be changed, and we just need a big change on that."

**W-01 Real 3D rims (MUST).** Model a rim set in Blender to R8-IMG-17 (16 designs: Multi-Spoke, Deep Dish, Turbine, Mesh, Split Five, Star Spoke, Gold Crown, Chrome Mirror, Carbon, White Wall, Stripe Tyre, Neon Ring, Glowing Hub, Glowing Tread, Flame Spoke, Galaxy Disc). One shared tyre plus a swappable rim mesh per design, smooth and detailed (spokes with depth, a centre cap, a lip), never part-built cylinders. Upload under the group.

**W-02 Fits every car (MUST).** Each car gets four wheel slots (attachments at each hub with the tyre radius and width, added where missing, listed for Brian L). The rim scales to that car's tyre, sits flush, faces outward on both sides (mirrored correctly), and turns with the wheel in the run and on the Raceway. Tyres stay black rubber unless the design says otherwise. Contact sheet: every car with three rims (Multi-Spoke, Gold Crown, Neon Ring), close on the front wheel, at `review\round8\frames\wheel-audit\`.

**W-03 Animated and glowing rims (MUST).** Neon Ring, Glowing Hub and Glowing Tread use Neon material with a slow pulse; Galaxy Disc has drifting stars; animated rims are the pricier tiers. Phone budget measured.

**W-04 Wheel previews that work (MUST).** In the Wheels tab, each tile shows the rim icon from `layers\R8-ICONS-wheels.png` (uploaded), with the name and price. Tapping a tile fits the rims on your car on the turntable and the camera eases in to a close "wheel cam" on the front wheel for 2 seconds, then back out. The Wheels tab layout follows R8-IMG-16.

**W-05 Prices and tiers (MUST).** Keep the Round 7 price ladder style (Cash tiers getting fancier and pricier, the flashiest for Robux where the catalog already says so). New designs slot into the ladder by how flashy they are; list the prices as PREVIEW in the ledger and in the note to Brian L.

## 8. Module T: trails, rebuilt (Adam: "just theorize a bunch of different things of how the trails could look better ... implement all of them")

Adam: "the previews don't look really good at all either. And I just want to just change the trails for the better." Round 7's reviewers also called the Lightning trail weak. Every idea below is part of this round.

**T-01 Every trail is built in layers (MUST).** Follow R8-IMG-19 (trail anatomy). Each trail combines, from each exhaust point:
1. a bright **core** (a thin `Beam` or `Trail` with high `LightEmission`, hot colour);
2. a wider **body** (a `Trail` with a soft animated texture: flame, energy, ribbon, smoke);
3. **particles** (`ParticleEmitter`: sparks, embers, stars, bubbles, confetti, by trail) with `Drag`, `Squash` and `VelocityInheritance` tuned so they fly back and spread;
4. a **fading tail** (transparency and width curves so the end dissolves, never a hard cut);
5. a **road glow** under the car (a soft coloured light or a decal patch), for Epic and up.
Use the transparent texture kit `layers\R8-TEXTURES-trails.png` (cut into separate images and uploaded) for bodies and particles; flipbooks where it helps (`FlipbookLayout`). Research note: ChatGPT adds the current Roblox property guidance in this module.

**T-02 Exhaust points on every car (MUST).** Each car gets one or two exhaust attachments at its real exhaust position (most have two; vans and the pizza truck may have one), added where missing and listed for Brian L. The trail never pours out of the middle of the car or the roof.

**T-03 Trails react to speed (MUST).** At low speed (launch card, Raceway) the trail is a short gentle version; at run speed it stretches long and wide; at top speed or right after a dive it flares brighter for a moment. Emission, length and width scale with speed (one curve per trail, tuned and recorded).

**T-04 Trails react to the hop (MUST), to R8-IMG-22.** On the leap: a burst ring in the trail's colours puffs out from the car you leave. While you float: a thin version of the trail streams from your avatar. On the dive: a bright streak follows you down. On the catch: a flash in the trail's colours washes over the new car and the trail moves to it (C-02).

**T-05 Trails grow with a hop chain (SHOULD).** Each hop in a row without touching the road raises the trail one step (bigger, brighter, more particles) up to 3 steps; a bump or a drop resets it. Purely visual. Record the step values.

**T-06 Rarity tiers you can see (MUST).** Common: a clean ribbon. Uncommon: ribbon plus light particles. Rare: full layers with sparks. Epic: layers plus an animated texture, road glow and its own soft sound. Legendary: everything, plus its own hop burst and a unique sound. Robux trails (and the VIP Gradient): the flashiest, still within budget. Each tier must look obviously better than the one below in a side-by-side frame.

**T-07 The trail list (MUST).** Keep and rebuild Round 7's thirteen: Flame Rush, Comet, Lightning (rebuilt: crackling branching bolts that jump between the exhausts and the road, a blue-white core, flickering light), Neon Ribbon, Galaxy, Rainbow Runway, Bubble Pop, Confetti Party, Pixel Blast, Frost Bite, Toxic Slime, Golden Glory, VIP Gradient. Add five new ones: **Money Rain** (bills and coins flutter out and tumble behind, perfect for a money game), **Aurora Veil** (wavy green-pink curtains of light), **Retro Grid** (a glowing synthwave grid ribbon with a sun-gradient edge), **Petal Storm** (swirling flower petals), **Drift Smoke** (thick tyre smoke clouds, coloured, from the wheels instead of the exhausts). Each looks like R8-IMG-20 and R8-IMG-21. Slot new ones into the price ladder; PREVIEW prices in the ledger.

**T-08 Paint-matched trails (SHOULD).** Neon Ribbon, Comet and Drift Smoke get a "MATCH MY PAINT" toggle that takes the trail colour from your equipped paint.

**T-09 Trail previews that look good (MUST).** In the Trails tab, each tile shows its icon from `layers\R8-ICONS-trails.png` (uploaded). The big preview puts your car on a **treadmill road**: the turntable becomes a short road strip that scrolls under the car with wind lines, so the trail streams behind as it would in a run; tap the preview to fire the hop burst (T-04). Layout to R8-IMG-18.

**T-10 Sound and comfort (MUST).** Soft whoosh loops for Epic and up (Roblox audio library or your own, rights-safe, listed in assets.md), respecting the sound-effect volume setting. Reduce Motion halves particle counts and turns off the screen-filling bursts.

**T-12 Use ParticleFX Studio's free flipbooks (MUST, section 0 item 13).** Adam gave full permission; do not ask him again.
- **Source first:** before drawing or generating any particle texture yourself, go to https://particlefx.studio/roblox and download the free Roblox flipbooks that fit each trail (flames, embers, sparks, smoke, stars, sparkles, lightning, bubbles, confetti, magic, frost, slime, coins, petals, and anything else that helps), plus the free packs (ZIP with each effect's settings). Use any download method that works on the laptop (direct download, `curl`/`Invoke-WebRequest`, or the browser). Keep the originals in `C:\Users\agert\Documents\Car-Hop-Art\assets\particlefx\` (outside Git) with the page link of each effect.
- **Upload** each one you use under LEGION STUDI0S (needs R8-S04), and list it in `vault/design/assets.md` with: asset id, file name, source page link, license line ("ParticleFX Studio free download, commercial use allowed, no credit required, checked 2026-11-08").
- **Build** each `ParticleEmitter` with `FlipbookLayout` matching the sheet (2x2, 4x4 or 8x8) and the effect's included settings as a starting point, then tune for each trail and tier (T-01, T-03, T-06). Combine with your own `Trail` and `Beam` layers for the core, body and tail; the flipbooks fill the particle layer and anything else they fit.
- **Phone budget:** prefer 512 px sheets (256 px for small sparks); 1024 px only where the difference is visible; reuse one texture across trails where it works; record total texture memory in the performance budget.
- **Also allowed** wherever it makes the game better (hop bursts, catch flash, upgrade confetti, Lucky Clover sparkles, portal swirls, Raceway rare-car glows): same rules.
- Use ChatGPT's `layers\R8-TEXTURES-trails.png` only to fill gaps the free library does not cover.
- Never redistribute the downloaded library as a pack (the license's one restriction). The paid plan stays unused.

**T-11 Budget (MUST).** Per tier particle caps, measured on the phone profile with the busiest trail at top speed in Downtown traffic; a phone quality tier that cuts emission by about half. Record numbers in the performance budget file.

## 9. Module L: the Lucky Clover stand

Adam: "the Lucky Clover guy that's operating the stand just looks horrible. The inside, like the clover is just four circles. I want that to definitely be fixed ... extremely detailed and follow it exactly." Round 7's version: `review\round7\frames\L01-clover-stand.jpg` (green balls on a block, a flat green roof, a giant flat clover cut-out).

**L-01 The clover mascot (MUST, copy almost exactly).** Model in Blender to R8-IMG-11: a cute four-leaf clover character. Four true heart-shaped leaves with a centre vein and a soft bevel, arranged as a proper four-leaf clover, forming the head and body, with a short stem; big friendly eyes, a smile, little arms with white gloves, a small green bowler hat with a gold band, maybe a tiny gold coin badge. Smooth stylized 3D, never spheres. Rig it simply (or animate with tweened parts): an idle bob, a wave when you walk up, a happy spin and a burst of gold sparkles when you buy luck. Upload under the group.

**L-02 The stand (MUST, copy almost exactly).** Rebuild the kiosk to R8-IMG-12: a charming wooden market stall with a striped green-and-white awning with a scalloped edge, a counter with a gold coin jar and a horseshoe, a big real four-leaf clover sign (heart-shaped leaves, not circles) that turns slowly above the roof with sparkles, string lights, a "LUCKY CLOVER" sign in the game's font, and the floating level sign at the same height as the Pit Stop's (H-06). On all three Launch Pads, themed lightly per World (snow on the awning in Summit Pass, sun-bleached wood in Dusty Highway).

## 10. Module O: what Round 7 left open (section 0 item 2)

- **O-01 Permissions (MUST):** R8-S04.
- **O-02 Uploads under the group (MUST):** everything in `Car-Hop-Art/upload-round7/` plus this round's art, all owned by LEGION STUDI0S; re-upload Coach Roxy's portrait under the group and switch every reference; list every id in `assets.md`.
- **O-03 Robux products (MUST):** create the products and passes the catalog already defines (off sale or not for sale while `RealPurchases = false`), record their ids, and run Studio test purchases for each (Studio purchases are not charged). Never turn on real sales.
- **O-04 Pull requests (MUST):** merge PR #15 (section 0 item 3); if your session is refused a merge, say so plainly and list the exact PR links and buttons for Adam in RESULT.md. PR #17 stays for Brian R.
- **O-05 Publish (MUST):** section 0 item 12. If your allowed tools cannot press Publish (Round 7 found the Studio MCP cannot), stop at the very end and give Adam the numbered clicks in your final message, then verify the place's "Updated" time if you can.
- **O-06 Long runs (MUST):** 10-minute autopilot runs in each World, recording parts, memory and frame time at 0, 5 and 10 minutes (Round 7 T-04 and R-08).
- **O-07 Heat measurement (MUST):** 20 rides timing Heat to Critical (Round 7 R-02); tune to the 6 to 9 second target if it misses.
- **O-08 Launch Pads 360 (MUST):** a 360-degree turn at ground, normal camera and highest camera on all three Launch Pads; no home island and no empty sky below the horizon (Round 7 A-06).
- **O-09 Round 7 reviewers' open list (MUST unless marked):** a dark backing behind Results; the half-hidden "CARS CAUGHT" label; the Pit Stop bolt icons must match the real hop counts (yellow 1, red 2, purple 3); one cannot-afford treatment everywhere (U-03); the luck odds text made readable (two short lines and a small "ODDS" button for the full table); the Galaxy paint's ragged edges; the plain hydrant replaced with a proper model (SHOULD); the SUV that looks like a police livery goes to Brian L as a note (N-02); **pick one game font** and apply it everywhere (Round 7 left fonts mixed; choose the bold rounded font already on the most screens, record it, and change the rest).

## 11. Module X: Claude's extra recommendations (SHOULD, all reversible, each recorded)

These are Claude's suggestions on top of Adam's notes, kept separate so they never become hidden requirements. Each says why it helps the player, what it costs and how to test it.

- **X-01 Launch hero moment.** At run start, a 1-second camera swing past your car as it launches, with the trail flaring (T-03). Player benefit: you see the look you bought every single run, which is what makes cosmetics worth buying (the Rocket League kickoff feeling). Cost: a camera tween and one burst. Test: 10 run starts, no motion sickness complaint in Reduce Motion (skipped there), no delay to control.
- **X-02 Ghost bay info.** Walking into a filled parking bay (H-03) pops a small card with the car's name, rarity, edition and $/lap. Benefit: the bays become a little collection display, bragging on the home plot. Cost: one small card reusing the Garage card style. Test: two bays, card opens and closes by walking in and out.
- **X-03 "Upgrade ready" marker.** When you can afford the next Raceway or Parking upgrade, a bouncing green up-arrow badge floats over that kiosk (no pop-up, no sound loop). Benefit: the loop "run, earn, upgrade" stays clear for a 5-year-old. Cost: one billboard bound to server Cash. Test: earn past the price, badge appears; spend, it goes.
- **X-04 UI sound pass.** Card open and close whooshes, button clicks, a short fanfare on upgrade, a "ka-ching" on buy, all at the sound-effect volume setting. Benefit: the premium screens feel premium. Cost: a handful of rights-safe sounds listed in assets.md. Test: every new card plays its sounds once, never stacked.

## 12. Module N: notes for the team

- **N-01 Brian R:** `vault/design/specs/lane3-round8-for-brian-r.md`: every run change (R-01 to R-04, the run car's look, the trail following the player), why, and the PR into his branch. He replies in the file.
- **N-02 Brian L:** `vault/design/specs/lane3-round8-for-brian-l.md`: every car model edit (paint splits, wheel slots, exhaust points, decal anchors), any new save field, the new cosmetic items and PREVIEW prices, the police-looking SUV, and the group-owned asset ids.
- **N-03 Board, decision 0043, log entry.**

## 13. Module V: verification (MUST)

- **V-01** `./scripts/check.ps1` passes on every pushed branch.
- **V-02** Every self-test suite passes, including the new C-02 end-to-end cosmetics test and the C-04 paint audit (zero flags).
- **V-03** Two-player and rejoin tests pass (plots, badges, ghosts, looks after a rejoin from the saved `Style`).
- **V-04** Frames for every MUST that has a visual, at desktop, phone landscape and tablet, in `review\round8\frames\`, named by requirement ID. Side-by-side frames for every "copy almost exactly" item.
- **V-05** Sonnet reviews done per workstream; the Opus review and fix loop done (R8-S08); the Opus verdict recorded.
- **V-06** O-06 long runs and the phone-profile performance numbers recorded.

## 14. Module F: finish

- **F-01** Push every branch; open or update PRs: `feature/lane3-round8` into `main`, `feature/lane1-round8-from-adam` into Brian R's branch, `integration/beta-6` as a draft (never merged).
- **F-02** Merge `feature/lane3-round7` and `feature/lane3-round8` into `main` only if every MUST in Rounds 7 and 8 that can be done without Adam is done and the Opus reviewer has no open MUST defect. Otherwise leave them as PRs and say why.
- **F-03** Publish (O-05).
- **F-04** Write `review\round8\RESULT.md`: in short; the MUST table (status: done, partial, not done, blocked, with real evidence); your calls; the agent map and how many agents of each model actually ran; the Opus reviewer's verdict and what it fixed; open items with the next action; the branch table; and a **walk-through for Adam** of about 15 steps in play order, in plain words, covering: his face on his badge and the smaller tags on other plots, the parking ghosts, the new upgrade cards, the Circuit without the outer sign, Roxy's cards, the Pit Stop sign height, the Missions and Settings spacing, the clover mascot, the Style Shop tiles on his own car, wheels, trails on the treadmill preview, the car-pick confirmation, a run showing his look and trail, the quiet lock-on, the dive path, and the new HOP / DIVE button.

## Appendix A: Adam's Round 7 playtest notes (2026-11-08, lightly cleaned up from his voice notes)

1. Spawning at your Raceway works and the "your Raceway" sign is good, but next to the name there is an empty picture instead of my Roblox avatar. (H-01)
2. You can't tell whether a parking spot is filled. Put a transparent version of the car that is on the Raceway into its parking spot. (H-03)
3. The Raceway upgrade and parking spot upgrade UI look very plain. Ask ChatGPT for reference images and implement them almost exactly, to a T. Keep the racetrack frame idea, much richer. (U)
4. Other people's lots should also have name tags, smaller and less prominent than the one on your own lot, each showing that player. (H-02)
5. The Stunt Circuit has an interwoven "Coming soon, Stunt Circuit" sign and cones on the outside; there is already a Coming soon sign inside as a preview. Delete the outside sign and cones. (H-04)
6. Dusty Highway and Summit Pass: Coach Roxy's new picture looks good and her line is good, but the text box is extremely large and white and the text is small. Make it proportional. I like the preview of how many cars and how much Cash you need. (H-05)
7. Downtown hub looks fine. The Style Shop looks good, but the tiles don't show my car: with the pizza truck equipped, the Fresh Lime tile shows a sports car. Fresh Lime on the pizza truck covers the windows, windshield and back windshield. Go over every car and make paint and decals perfect. Decals are looking good and the variety is good. (C-04, C-05, C-06)
8. Rims still don't show in the preview, they look horrible, the previews aren't correct. Everything with wheels needs a big change. (W)
9. Trail previews don't look good. Change the trails for the better, brainstorm many ideas, make AI icons and preview references with ChatGPT, and implement all of it. (T)
10. Pit Stop looks good, but its floating level sign blocks the lightning icon on top. Raise it to match the Lucky Clover sign height. (H-06)
11. The Lucky Clover guy looks horrible: the clover is four circles. Fix it with a detailed reference, followed exactly. A cute clover mascot. (L)
12. Picking a car before the run gives no confirmation of the car I chose. The trail picker works. (C-03)
13. In the run I don't see my trail, decals or anything I did to my car. (C-02)
14. In the run, after the first hop, the dive needs a clearer indication of where you are diving than the yellow circle: subtle arrows. Maybe delete the arrows that show before you hop and use arrows for the dive instead; decide from the reference video. (R-01, R-02)
15. The HOP and DIVE buttons look horrible. Get ChatGPT reference images and implement them. (R-03)
16. In the hub, the Settings and Missions buttons are too far apart. Move them closer. (H-07)
17. Include all Round 7 leftovers. Use as many Sonnet 5.5 agents as needed so it finishes faster, a review agent per task, one Opus 5.5 agent reviewing all the Sonnet work, and Opus 5.5 agents fixing what it finds. (Section 0 items 1 and 2)

## Appendix B: ChatGPT image list for this round

In `review\round8\chatgpt-images\`. Images (direction unless R8-S07 says "copy almost exactly"):
R8-IMG-01 Raceway card desktop · 02 Raceway card states · 03 Raceway card phone · 04 Parking card desktop · 05 Parking card states · 06 Parking card phone · 07 parking bays with ghosts · 08 plot badges · 09 Coach Roxy cards · 10 Pit Stop and Lucky Clover sign heights · 11 clover mascot sheet · 12 Lucky Clover stand · 13 Style Shop paint tab on your car · 14 paint-mask guide · 15 decal placement guide · 16 Wheels tab · 17 rim designs · 18 Trails tab with treadmill preview · 19 trail anatomy · 20 trails sheet A · 21 trails sheet B · 22 trail moments (launch, leap, dive, catch, chain steps) · 23 hub HUD spacing · 24 Stunt Circuit gate without the outer sign · 25 car-pick confirmation · 26 run car wearing the full look · 27 lock-on and dive path · 28 HOP / DIVE button states.
In `layers\` (text-free art to upload): R8-LAYERS-raceway-card · R8-LAYERS-parking-card · R8-LAYERS-shared-ui · R8-LAYERS-hop-dive-buttons · R8-ICONS-wheels · R8-ICONS-trails · R8-TEXTURES-trails.
