# Catch A Car!: Lane 3 Round 7 (the game Adam played, made fun: home at your Raceway, the two-press Hop, luck, real cosmetics, cooler everything)

**For:** Claude Code, on Adam's Windows laptop, repository `Roblox-Game-1`, in its own worktree `C:\Users\agert\Documents\Roblox-Game-1-round7`.
**From:** Adam (repository owner, beta integration person), written with Claude (claude.ai) on 2026-11-05 from Adam's playtest of the Round 6 beta (his notes are quoted or paraphrased in each item) and a reference gameplay video he chose. Lines marked **[ChatGPT]** were added by ChatGPT.
**Task folder (outside Git):** `C:\Users\agert\Documents\Car-Hop-Art\review\round7\`
**Builds on:** Round 6 (`review\round6\RESULT.md`, `vault/design/specs/lane3-round6-ledger.md`, decision 0041), the driving update and Stamina Shop (decision 0040), Round 5 (0039), Round 4 (0036).
**Reference:** `reference-video-notes.md` in this folder and the stills in `references\`. Read them before anything else in Modules A and R. Adam: "take heavy inspiration from this gameplay ... make the game play really cohesive and really, honestly, addicting and fun." Copy the feel and structure, never the other game's names, art, UI pixels or monetization tricks.

Every earlier round's rules still apply unless this brief changes them: Round 1 brief sections 2, 2.2, 2.3, 3, 5, 19 to 21; Round 2 section 1.1; Round 3 sections 2 and 2.1 (the "AI look"); Round 4 section 1 and R4-S09 (execution and evidence); Round 5 section 1 (stand-in header; the client never sends an amount); Round 6 section 1.

---

## 0. What Adam decided for this round (2026-11-05)

Adam answered "go with your recommendations for everything". These are decided. Do not re-argue them; record them in decision note **0042**.

1. **Every lane is open this round.** Adam: "I give you permission to edit really any of the lanes, and Brian R agrees to that. Just do whatever you need to do." So Round 7 may edit Brian R's run (`src/client/Run`, `src/shared/Run`) and Brian L's areas (`assets/cars`, `src/shared/Catalog`, `src/shared/Net`, `src/server` outside `src/server/Beta`). How: run changes go on a new branch `feature/lane1-round7-from-adam` made from `feature/lane1-run-prototype`, merged into the beta, with a pull request into Brian R's branch so he reviews and keeps them. Brian L's car models are edited only to make paint work (Module C); every edit is listed in a vault message to him. Nobody's branch is force-pushed, and their pull requests are not merged by this round.

2. **Push everything and bring `main` up to date first** (Adam's standing request; this sentence is his explicit request to commit, push and merge). Sweep every local checkout exactly as Round 6 section 0 item 1 (a) did. Then merge PR #15 (`feature/lane3-round6`) into `main` once its check passes, even though Round 6 left some MUSTs partial (they were blocked on Adam's permissions, which this round fixes). Push every integration branch. Report the branch table.

3. **Where the work lives.** Lane 3 code on `feature/lane3-round7` from `main` after item 2. The beta on `integration/beta-5` from `integration/beta-4`, with `feature/lane1-round7-from-adam` merged in. Changes that touch both (most of them this round) are made on `integration/beta-5`; the Lane 3 files among them are also brought to `feature/lane3-round7` so `main` gets them.

4. **Home is your Raceway.** You spawn at your own plot when you join, and you come back to your own plot after every run, never at the Downtown portal.

5. **The Stunt Circuit is "Coming soon"** this round. Its gate stays closed with a proper Coming soon sign, and the island board that showed fastest Circuit times becomes **RICHEST RACERS**: the most Cash among players in this server (no cross-server data).

6. **World unlock rules.** Dusty Highway needs 5 Downtown cars and $5M. Summit Pass needs 5 Dusty Highway cars and $1B (both PREVIEW). Coach Roxy says exactly what is missing, with progress bars.

7. **Coach Roxy gets a new look:** a confident, stylish adult woman in racing gear (bomber or racing jacket, headset, clipboard), drawn in the game's bright stylized style, from ChatGPT's reference. "GTA style" means attitude and swagger, not GTA's real look or tone: this is a kids' game.

8. **The two-press Hop** from the reference video replaces the current Hop: press once to leap up and float, press again to dive onto the car marked by the ring (Module R).

9. **Stamina stays as decision 0040 set it:** 5 bolts to start, 10 upgrades of +1 up to 15, a red bolt counts as 2 and a purple bolt as 3, Cash only, prices $1K to $20M (PREVIEW). Round 7 makes BUY work and makes the shop look great. New: **bumping a car costs 1 bolt.**

10. **Luck is a new upgrade:** 5 levels, x1.25, x1.5, x2, x3 and x4 on the odds of Rare, Epic and Legendary cars (the rule is in L-02). Cash only, very expensive, each level 10 times the last: $100K, $1M, $10M, $100M, $1B (PREVIEW). Shown with clovers: green, then gold, then purple at the top levels. It must really change what spawns, and a test must prove it (L-04).

11. **Offline earnings:** everyone earns 40% of their Raceway income while away, up to 24 hours. VIP raises the cap to 30 hours (same 40%). The Welcome back money must actually land in your Cash (it does not today).

12. **VIP:** no lounge (Adam does not want to build one). VIP gets an exclusive animated gradient trail (shown in the trail list with a "VIP PASS" tag and its Robux price), a VIP name tag, VIP paints and the 30-hour offline cap.

13. **The free respawn is gone.** There is never a "RESPAWN FREE" button. The 19 Robux respawn stays (Coming soon in the beta).

14. **Paint and the trail stand become one Style Shop** in each Launch Pad, with tabs for Paint, Decals, Wheels and Trails. Everything bought and equipped there shows on the car you actually drive, in the run, at the Raceway and in the Garage. Adam: "That's very important to me."

15. **The Garage Index loses the editions ladder** (Normal, Gold, Diamond, Rainbow, Galaxy) from the car detail. Note for Adam's knowledge (no action): editions still go up through copies (Joyrides), as agreed with Brian L. The card just stops showing the ladder; it still shows the car's current edition badge.

16. **Cars on the road are all one size and bigger**: no car is bigger because it is rarer, and every road car is about 1.25 times today's average size (tune it; record the number).

17. **Robux selling stays off** in the published beta (`RealPurchases = false`). Products get created this round if Adam grants the permission in R7-S04.

18. **Publish to the private beta at the end** (place 118605678346800, LEGION STUDI0S, "Car Hop Beta") from your local beta file, same method as Round 6. This line is Adam's go-ahead. Nothing goes public.

19. **Not this round:** turning on real sales, a public publish, cross-server leaderboards, trading, new currencies, limited-time anything, eggs or paid luck, an offline-earnings upgrade (Adam: "maybe in the future").

## 1. Your freedom, and the hard lines

Think like the lead designer and the lead engineer of a top Roblox simulator. Adam wants the game "addicting and fun", "a thousand times cooler". Research, try options, keep the best, record your choices in the ledger and decision 0042, and **do not stop to ask Adam** except in R7-S04. No review web pages: say when you are done, and Adam walks through Studio himself.

MUST means do it. SHOULD means do it unless it costs more than a few hours or risks a MUST; record why not. MAY and "your call" mean choose, record, move on.

Hard lines:
- **The client never sends an amount, a price, an odds value or a result.** The server decides Cash, luck, stamina, prices and grants. Luck odds are computed on the server from the saved Luck level, and the run seed the client gets already includes them.
- **Saves:** the agreed fields, the beta fields from Rounds 5 and 6 (`StaminaLevel`, `Purchases`, `Owned`), and new beta-only fields `LuckLevel` and `Style` (equipped and owned cosmetics, if `Owned` cannot hold them). Each new field gets a line in the vault message to Brian L. ProfileStore only, tested with Mock.
- **Kids and fairness:** no countdowns, streaks, "only today", fake scarcity, nagging pop-ups, or a purchase prompt that opens without a press. Luck and Stamina are Cash only. Every Robux button states its Robux price.
- **Original art only**, no brands, no real logos, no Roblox studs, no fake sponsors, nothing copied from the reference game.
- **No destructive Git**, no force-push, never rewrite a teammate's text (add to Replies or new files).
- **Never send keystrokes or clicks outside the Studio window**, never capture the whole desktop.
- **Performance:** every new effect (glows, trails, particles, hub detail) fits the budget in `vault/design/specs/performance-budget.md`. Phone first: measure a mid phone profile (Studio's device emulator plus the parts and particle counts) and record it.

## 2. Setup

**R7-S01 Read first:** `AGENTS.md`, `vault/tasks/BOARD.md`, the 2026-11-05 log, decisions 0040 and 0041, `review\round6\RESULT.md`, the Round 6 ledger, `reference-video-notes.md` and the stills in `references\`, `vault/design/ui-style-guide.md`, `economy-v1-answers-from-adam.md`, every vault Replies section changed since 2026-11-03 (a teammate's reply wins over this brief; record it), and `review\round7\PHONE-NOTES.md` if Adam wrote one.

**R7-S02 Branches.** Section 0 items 2 and 3. Worktree `Roblox-Game-1-round7`. Claim the task on the board.

**R7-S03 Studio.** Respect `STUDIO_LOCK.txt`. Fresh local file `Car-Hop-Art\CarHop-Beta-5-local.rbxl` copied from the Round 6 file, a dated backup, `rojo serve beta.project.json`. If the Rojo plugin needs a Connect click, ask in your first message and never again. Fix Round 6's Studio window trouble first: do not resize the Studio window for captures (Round 6 lost its frames that way); use the device emulator or `Lane3ScreenProfile` instead.

**R7-S04 Permissions, asked once (MUST).** Round 6 was blocked twice: uploading images (Coach Roxy, icons, decals, product art all need uploads) and creating Robux products. In your first message, give Adam the exact clicks for each, numbered, in plain words, one action per line, and wait for his "done" on these only: (a) the Studio MCP or Assistant permission that allows asset upload for this experience; (b) "Money & monetization" (developer products and game passes) for this experience; (c) if an Open Cloud key is the better route, how to create one under LEGION STUDI0S with only the scopes needed, saved outside the repository (never commit a key). Verify each permission works with one test upload and one test read before relying on it. While waiting, work on everything that needs no upload.

**R7-S05 Ledger and decision.** `vault/design/specs/lane3-round7-ledger.md` (copy this brief to `lane3-round7.md`), decision `vault/decisions/0042-lane3-round7.md`, evidence types as in Round 6. "Not done" is never written as a pass.

**R7-S06 Order of work and what to drop.** Order: S, A, R, P, L, C, U, K, H, M, N, T, F. If time runs short, drop in this order and record it: T-06, C-09, K-04, H-08, H-07, M-04, K-02, U-08. Never drop a MUST in A, R, P, L, C or F.

**R7-S07 Images.** ChatGPT's 22 reference images are in `review\round7\chatgpt-images\` with `GENERATION-NOTES.md`. They are direction: match the game's established style, keep everything earlier decisions fixed, and use the images for layout, richness and "how much cooler". Build 3D in Blender through the Blender MCP where part-built geometry looks cheap. List every uploaded asset id in `vault/design/assets.md`.

[ChatGPT] R7-S08 Execution and evidence (restates R4-S09): use one lead implementer. Use at most two Sonnet reviewers per review, each assigned a bounded set of no more than 12 relevant screenshots, requirement IDs and a scoring rubric; no implementation-agent swarm, recursive delegation, or duplicate whole-repository audits. Reuse the lead's context and run targeted checks after changes. Reviewers report concrete defects and evidence, not generic praise. If Sonnet is unavailable, record that limitation; never silently substitute multiple Opus agents.
[ChatGPT] R7-S08 continued: decide reversible details, record them in the ledger, and work around blocked dependencies while completing independent tasks. No mid-task questions except the consolidated R7-S04 setup/permissions batch (include the R7-S03 Connect step there). Never invent approvals, uploaded IDs, tool access, successful tests or reviewer scores. One consolidated end report includes decisions made, failed/blocked checks, actual evidence and next actions. These rules do not authorize overriding security restrictions or marking an untested MUST complete.
[ChatGPT] Setup clarification: verify each checkout's branch, dirty files and active task before the requested sweep; preserve other sessions' work. A read-only API check does not demonstrate upload or product-creation rights. Studio tool consent, group roles and API scopes are separate capabilities. Use the real current permission screen in the S04 instructions, not guessed labels; never request secrets in chat. Section 1 prohibits clicking outside Studio, so Adam performs dashboard steps himself.
[ChatGPT] Reference interpretation: read GENERATION-NOTES.md before implementing the 22 images. They are concepts, not game screenshots, measured layouts, engine shaders or asset IDs. Existing server catalogs override sample values in pictures. Reconcile the live UI guide with Round 7's explicit cream/navy, orange action and one bold rounded font direction; do not copy extra decorative controls. Keep all approved numbers and decisions from section 0.
**R7-S09 Claude's notes after ChatGPT's pass (2026-11-05, MUST).**
- **Luck and Roblox's paid random items policy.** ChatGPT's L policy note is right: Roblox's policy names luck boosts as probability modifiers and applies to indirect purchases, and Cash can be bought with Robux (Cash packs, Starter Pack). So, this round: (1) the Lucky Clover panel shows the real numerical odds before purchase, now and after ("Rare or better: 8% -> 12%", and the Rare, Epic and Legendary shares), computed from the same L-02 module the server uses, updated live while luck is active; (2) the server reads `PolicyService:GetPolicyInfoForPlayerAsync` and, for a player with `ArePaidRandomItemsRestricted`, the Lucky Clover BUY is replaced by "Not available for your account" (show it, never hide the stand); (3) add a release-checklist line: before `RealPurchases` is turned on, Adam confirms with Roblox's current policy whether Cash-bought luck needs anything more. Section 0 item 10 is unchanged; this only adds the disclosure and the restriction.
- **Reference images are direction, not spelling.** Copy text from this brief, never from the images. Known image slips: the trails sheet says "PIXEL BL?ST" (the name is PIXEL BLAST); the Double Lap Pay tile shows a blocky avatar (our art has none); the images are about 1,700 px wide, not 1920 (ChatGPT's tool could not make the exact size).

## 3. Module A: home, the island and the hubs

**A-01 Spawn at your Raceway (MUST).** On join, after your plot is assigned, you appear at your own plot's entrance facing your Raceway. After every run (Results closed, HOME pressed, End Run, wreck, leave) you return to the same spot, never in front of the Downtown portal. Before your plot is ready, a waiting spot by the island centre with a "Finding your Raceway..." line, then move. Test with two clients: each spawns at their own plot, on join and after a run.

**A-02 See your home from anywhere (MUST).** Above every plot's Raceway, high in the air, a big floating badge with the owner's avatar headshot (`Players:GetUserThumbnailAsync`, HeadShot) and username, readable from every point of the island, including the centre and behind buildings (BillboardGui, `AlwaysOnTop`, a large `MaxDistance`, size that stays readable at distance). Your own badge is gold-rimmed with "YOUR RACEWAY" under the name; other players' badges are white-rimmed. An empty plot shows nothing. Adam: "I just want to stress that I see the map from anywhere on the map." Check from five fixed points (centre, each portal, the far plot) and record frames.

**A-03 Stunt Circuit: Coming soon (MUST).** The Circuit gate is closed with a bold "COMING SOON" sign in the island's style (a barrier arm, cones, a chequered banner). Nothing behind it can be entered. The Stunt Circuit screens from Round 6 stay in the code, switched off.

**A-04 RICHEST RACERS board (MUST).** The board that showed Circuit times becomes "RICHEST RACERS": the top ten Cash totals of players in this server, live, your row highlighted, avatar headshots, Cash in the game's K/M/B/T format, "This server" in small text. Server-side, reading saved Cash only.

**A-05 Portals and Coach Roxy (MUST).** Section 0 item 6. At a locked portal, Coach Roxy's card shows two progress bars like the reference's goal card ("CARS 3 / 5 from Downtown", "CASH $1.2M / $5M"), a one-line next step ("Catch 2 more Downtown cars!"), and GOT IT. When both bars are full the portal opens with a moment (chains fall, the swirl brightens, a short fanfare, Reduce Motion version). Roxy's new portrait from `R7-IMG-01` (uploaded). Use her in every place she already appears (tutorial, portals, Welcome back if it fits).

**A-06 Launch Pads, much more detail (MUST).** Adam on Downtown: "everything is just a shape. The portal looks like a circle on the floor with a rectangle ... the bushes are a sphere of grass on a block, everything looks extremely plain ... I can even see the home island at some angles." Rebuild all three Launch Pads (Downtown garage, Dusty gas station, Summit ski lodge, as decided on 2026-11-02) to `R7-IMG-04` and `R7-IMG-05`:
- A real 3D portal home arch (stone, steel or neon by World), with the swirling field, edge glow and sparkles; the launch ramp clearly marked, lit, with chevrons.
- Real foliage: low-poly faceted bushes with clumpy leaves and flowers in several varieties, planters, trees (the island's tree style), never spheres on blocks.
- Street furniture by World: lamps, benches, hydrants, crates, tyre stacks, neon signs, bunting.
- **A layout that does not look awkward:** symmetric. The launch ramp in the middle, the Style Shop on one side, the Pit Stop and the Lucky Clover kiosk on the other, the HOME portal facing the centre, clear walking lines between them.
- **The backdrop:** a full skyline or landscape all around, so the home island is never visible from any angle. Use fog and atmosphere, a sky-colour backdrop ring, or far geometry. Check a 360-degree turn at three heights.
- **A barrier after the World sign:** Adam: "I don't want you to be able to walk further on this road ... it looks unfinished." A real road-closed set (barriers, cones, a "RUNS START AT THE RAMP" sign) and an invisible wall behind it.

**A-07 The launch card (MUST).** On the ramp's card: no "hops this run" bolt line (Adam: it should not say how many hops you have). The car is centred in its frame on every screen size. A red X closes it (top right, 44 px minimum), and so does walking away. START stays the big orange button. Layout to `R7-IMG-06`.

**A-08 The island is cooler (SHOULD).** One pass over the island hub with `R7-IMG-22`: richer plazas, path edges, lights, flags, planters, a fountain moment, the RICHEST RACERS board and the plot badges as landmarks. Symmetry for props, randomness only for trees (Adam's 2026-10-22 rule).

[ChatGPT] A-01/A-03 acceptance: test join, close Results, HOME, voluntary End Run, wreck and character reset independently. Resolve the player's current plot at return time, not a stale plot reference; cancel a pending return on disconnect. 'Leave' cannot teleport a disconnected player: the next join uses their newly assigned plot. Close Circuit entry on the server as well as visually, including any old menu or remote path.
[ChatGPT] A-04/A-05 acceptance: show only actual connected players, with deterministic ties and blank unused rows; never invent names to fill ten positions. An unlock is per player: one player's open portal must not grant a second player's access. Test two clients on opposite sides of the requirement, plus insufficient Cash and repeated activation. Inspect the existing unlock transaction before choosing whether Cash is a threshold or a spend; preserve its approved meaning and never silently debit on a progress-bar refresh.
[ChatGPT] A-06/A-08 composition: retain six separate plots and individual raceways. Make the central START ramp the first readable destination, with an unobstructed route to each kiosk and HOME. Symmetric building placement, repeated materials and consistent sign heights unify the hubs; vary foliage clusters without randomizing navigation. Road barriers close the unfinished road, not the HOME route. Check the 360-degree backdrop at ground, normal camera and highest permitted camera positions; do not solve one hub by changing global Lighting for every player.
[ChatGPT] A-07 states: loading selected car, ready, unavailable asset, START pending, closed and walk-away. A stale asynchronous load must not reopen a closed card or replace a newer selection. Preview camera fits the car's bounds including wheels without clipping; it remains centered at all three device profiles.
[ChatGPT] A-02 research verified 2026-11-05: BillboardGui.AlwaysOnTop renders over 3D obstructions and treats LightInfluence as 0; Brightness then has no effect. MaxDistance must cover the measured island diagonal. Offset sizing is screen-space while Scale is in studs, so use a bounded pixel-size badge to avoid unreadably small distant names. Test six overlapping sightlines, not just one badge. [Roblox BillboardGui](https://create.roblox.com/docs/reference/engine/classes/BillboardGui/LightInfluence).
[ChatGPT] A-02 thumbnail/streaming implementation: GetUserThumbnailAsync returns content and readiness; use HeadShot, a neutral placeholder, protected call, bounded retry and a cache by UserId. Recheck ownership when the result returns so an old player's head cannot appear on a reassigned plot. [Roblox Players](https://create.roblox.com/docs/reference/engine/classes/Players#GetUserThumbnailAsync), checked 2026-11-05. AlwaysOnTop cannot render an absent streamed-out adornee; keep a small client badge anchor from replicated plot positions or a narrowly persistent anchor model, not every whole plot.
## 4. Module R: the run (Brian R's lane, opened by section 0 item 1)

Work on `feature/lane1-round7-from-adam`. Keep Brian R's structure and naming; change what Adam asked. Each change gets a line in the vault message to him (H-02) saying what and why.

**R-01 The two-press Hop (MUST).** From the reference video (stills `ref-074s.jpg` to `ref-092s.jpg`, `hop-sequence-sheet.jpg`):
- **Ring:** while you ride, the best car to hop to (in range, ahead, reachable) gets a bright ring on the road under it and its label grows. If no car is in range, no ring.
- **First press (SPACE, the big round HOP button on touch, the gamepad A button):** you leap up off your car and float for about 1 second. The world slows a little (about 0.6x) so you can aim. You can steer the float left and right with A and D or the stick. The ring follows the best target from where you are now.
- **Second press:** you dive onto the ringed car and take it (Keys start, as today).
- **No second press within the float:** you drop. If a car is under you, you land on it. If not, you land on the road: "BONK!", you lose 1 bolt (R-04), and you respawn on the nearest car behind you after a short blink. At 0 bolts the run ends (R-06).
- **First-run help:** in the tutorial and the first two runs, the float lasts longer (about 1.6 s) and a "PRESS AGAIN!" prompt flashes on the button.
- Keep the server checks honest: the server still validates the Hop by time and distance; the float does not let the client claim farther than the server's reach rule (update the reach constant once, on both sides, and record it).
- Tune by playing: a new player lands most hops on purpose; a good player chains hops quickly. Record the numbers.

**R-02 Heat is faster (MUST).** Adam: "far too slow". Raise Heat so a typical ride lasts about 6 to 9 seconds before Heat Critical, measured over at least 20 rides, and keep every claim possible with Heat to spare (Brian R's `HEAT_TO_SPARE` rule). Keep the first-run assist. Add the reference's warning on the car itself: when Heat goes Critical, the car flashes red and a red "!" pops above it for about a second before you are thrown (`ref-047s.jpg`), with a short warning sound.

**R-03 One size, bigger cars (MUST).** Section 0 item 16. Find where road cars are scaled (the road-car dressing adapter from decision 0040, `CarVisual`, or `RunConfig`), remove any size-by-rarity or size-by-family factor for road cars, and set one scale. Check that hop reach, lane width, collision boxes and the camera still feel right with bigger cars, and adjust them together.

**R-04 Bumping a car costs a bolt (MUST).** Driving into a car (not hopping onto it) costs 1 bolt (with red and purple bolts, 1 unit, the same way a hop does), with a "BONK!" pop, a short camera shake, a crunch sound, and 1.5 seconds where another bump costs nothing (so one crash cannot drain three bolts). The server counts bumps the same way it counts hops (the run report already sends what happened; add the bump event; the server checks it against its own bolt count).

**R-05 You are inside the car (MUST).** Adam: "at times you'll spawn on top of the car ... you see yourself on top of the car during the run." Find every path that leaves the avatar visible or perched on the roof (the Hop landing, respawn, run start, the float's end) and fix it so the avatar is always hidden in the driver's seat (or, if the run shows the driver, seated inside). Test 50 hops in a row with a frame check.

**R-06 Wrecked screen (MUST).** When bolts hit 0, a big "WRECKED!" moment (like the reference's STOMPED, `contact-sheet-2.jpg` last row), then Results. The line under it names the fix: "Out of Stamina! Get more bolts at the Pit Stop" with the bolt icons.

**R-07 End Run button (MUST).** A small END RUN button on the run HUD (top right, away from the HOP button, 44 px minimum). It asks "End this run? You keep the cars you caught." with END RUN (red) and KEEP DRIVING. Ending goes to Results and home, like a normal end.

**R-08 The world never runs out (MUST).** Adam: "if you play the game for long enough, the map actually just disappears and you're just on the single road." Scenery must keep generating for the whole run in all three Worlds, however long. Test a 10-minute autopilot run in each World (at least 10 km) and record parts, memory and frames at 0, 5 and 10 minutes.

**R-09 No white world (MUST).** Adam: "everything in the backgrounds is just very white ... it makes me feel like it's not loading in time." Find the cause (meshes not loaded yet, textures still streaming, StreamingEnabled settings, LOD, missing palette textures, the atmosphere settings) and fix it: preload the World's meshes and textures behind the Launch Pad (ContentProvider) before START is enabled, show a short "Warming up..." on the card if needed, keep a coloured haze at the far distance so nothing pops in white, and use far-distance stand-ins for big buildings. Verify on a cold join of the published game, not just in Studio.

**R-10 Rare cars shout (MUST).** Adam: the label "epic executive" on top of the car is too small to make him chase it. Labels like the reference (`ref-064s.jpg`, `ref-086s.jpg`): three lines, the rarity word large and coloured (Common white, Uncommon green, Rare blue, Epic purple, Legendary gold), the car name, and a red "new!" when you do not own it. And by rarity:
- Rare: a blue glow under the car.
- Epic: a purple aura, rising sparkles and a soft chime when it enters view.
- Legendary: a gold pillar of light into the sky visible from far away, a fanfare sting, and an arrow at the screen edge pointing to it while it is off-screen.
- An edition car (Gold, Diamond, Rainbow, Galaxy) on the road shimmers in its edition's look and its label says the edition.
Keep labels readable at speed and never covering the HOP button.

**R-11 The run's feedback (MUST).** From the reference: a burst of hearts or stars and "IT'S YOURS!" sliding in on the left with the car's name and "Keep going!" on each claim; a "SECURED" counter on the left with small portraits of this run's catches; the distance in metres at the top centre; a district banner when you enter a new part of the World ("Downtown: Harbor", your call on names). The goal line at the top of the hub screen (H-01) is hidden in runs.

**R-12 Luck in the run (MUST).** The run uses the server's luck-adjusted odds (L-02). A small clover badge on the run HUD shows "LUCK x2" when luck is above 1.

[ChatGPT] R-01 implementation contract: explicitly model Mounted -> Float -> Dive -> Mounted, Float -> RoadBonk/Recovery, and any active state -> Ended. Accept one first press and one second press per hop; holding a key, repeated touch events or a late packet must not create multiple costs or claims. Revalidate a target that leaves reach or disappears before landing. If no valid target remains, use the documented drop/recovery path. Input through menus must not also hop.
[ChatGPT] R-01/R-04 timing: 0.6x is a per-run effect, never a global slowdown of the server, other players, UI or income. Record which motion and gameplay clocks slow and make server reach checks agree. An impact during Float/Dive must not charge both a landing and duplicate bump for the same event. Apply the 1.5-second invulnerability on the server, reject replayed/out-of-order events and do not accept a client-supplied remaining stamina. If the current beta uses client reports, document what the server can actually validate rather than claiming physics it does not simulate.
[ChatGPT] R-01/R-02/R-03 checks: first-two-run help must use an existing approved counter or a clearly recorded session-only fallback, not an unapproved save field. Measure claim duration plus safety margin against Heat for every relevant car. Use one documented scale policy independent of rarity while retaining original vehicle proportions; retest wheel positions, hit bounds, lane clearance, hop reach and chase-camera framing together.
[ChatGPT] R-05/R-06/R-07 acceptance: avatar visible only during the intended leap/dive and restored correctly after ending, resetting or respawning; preserve accessory transparency and do not permanently hide the character. Wreck, voluntary end and disconnect race to a single server finalization. Results grants and secured cars cannot duplicate when HOME or close is pressed twice. KEEP DRIVING resumes cleanly. Reduced motion uses a stable warning and readable WRECKED card without shake or repeated flashes.
[ChatGPT] R-08 acceptance: recycle scenery in bounded segments with cleanup of models, sounds, events and effects. At 0, 5 and 10 minutes record distance, live segment count, instances, memory, frame timing and graphics profile; verify at least 10 km in each World as requested. No gap at segment seams, no repeated collision leftovers, no unbounded growth after warmup. Autopilot verifies endurance, not human hop quality.
[ChatGPT] R-10/R-11/R-12: gold edge arrow only while the tracked car is genuinely off-screen; clear it when the car despawns or becomes irrelevant. Rarity wording must remain readable without relying on color. R-10's explicit red new! tag is a specific exception to the general red-for-danger convention, not permission to tint whole cards red. IT'S YOURS and SECURED update after authoritative capture completion, never immediately on a successful dive. Deduplicate capture events and distinguish new cars from repeat-copy progress. Snapshot server luck at run start; a mid-run purchase applies to the next run and the HUD displays the current run's snapshot.
[ChatGPT] R-09 research verified 2026-11-05: instance streaming controls Workspace presence; mesh/texture content also loads separately. StreamingMesh is a coarse colored imposter without textures; SLIM is now documented as a higher-quality alternative. Neither distant representation supplies collision/raycast physics. Inspect Model.LevelOfDetail before blaming white/grey scenery only on lighting. [Instance streaming](https://create.roblox.com/docs/workspace/streaming), [ModelLevelOfDetail](https://create.roblox.com/docs/reference/engine/enums/ModelLevelOfDetail). A white distant imposter may reflect pale base colors, while nearby white surfaces may indicate texture fetch, asset permission or material problems; these are hypotheses to distinguish with captures and fetch status, not a diagnosed cause.
[ChatGPT] R-09 preload correction: preload only the selected World's critical start-area content, not all Workspace; log final AssetFetchStatus and use a bounded wait with an honest failed-load state instead of an endless disabled START. RequestQueueSize is not a reliable progress percentage. [Roblox performance guidance](https://create.roblox.com/docs/performance-optimization/improve), checked 2026-11-05.
[ChatGPT] R-09 unresolved official-document discrepancy, checked 2026-11-05: the [ContentProvider reference](https://create.roblox.com/docs/reference/engine/classes/ContentProvider/BaseUrl) says SurfaceAppearance/MaterialVariant are unsupported by PreloadAsync, while [official release notes 668, Dutch](https://create.roblox.com/docs/nl-nl/release-notes/release-notes-668) state support was added. Do not claim either behavior was tested here. Run a tiny probe in the installed Studio/client build and record callbacks plus visible readiness. Preloading does not pin all content in memory or guarantee a streamed-out model exists; keep compatible colored stand-ins and test cold published loading.
## 5. Module P: the economy pieces Adam named

**P-01 Offline earnings (MUST).** Section 0 item 11: `OfflineRate` 0.4, `OfflineCapHours` 24, VIP 30. Find and fix why the Welcome back amount never reaches Cash (`BetaEconomy.payOffline`, the Welcome back card, the save; Adam: "none of it actually goes into your total sum of money"). The card shows the amount and COLLECT; COLLECT plays the cash fly-in and the counter really rises. Test: rejoin suite with `LastSeen` set back 2 hours, 30 hours, and 30 hours with VIP; check the saved Cash each time.

**P-02 Portal rules on the server (MUST).** Section 0 item 6 enforced on the server (cars counted from the save, Cash spent on unlock).

**P-03 Stamina BUY works (MUST).** Adam: "when I press buy, it doesn't actually do anything. It says the shop is closed, so that's unacceptable." Start at `src/client/UI/LaunchPad/StaminaPanel.luau` (the "The shop is closed in this place." line) and the server side from decision 0040. Fix it in Studio and in the published place (the published place is where Adam saw it). Test: buy levels 1 to 3, rejoin, still owned, the run starts with the right bolts.

**P-04 Luck prices and save (MUST).** Section 0 item 10 in `EconomyPreview` (PREVIEW) and `LuckLevel` in the beta save.

[ChatGPT] P-01 acceptance: trace calculation, credit and display separately. One entitlement is credited once, not on load and again on COLLECT. Test rapid COLLECT, rejoin before/after collection, a lost response, empty Lineup, zero/negative elapsed time, clock anomalies, normal 24-hour cap and VIP 30-hour cap. Preserve existing persistence semantics and prove both displayed and saved Cash changed by the expected amount using ProfileStore.Mock. Never edit live LastSeen for testing.
[ChatGPT] P-02/P-03/P-04: count qualifying owned car identities according to the approved collection rule, not five duplicated UI entries. Repeated stamina/luck BUY requests purchase at most one intended next level per accepted transaction, at server price; stale screens refresh instead of granting an unexpected level. Test insufficient funds, cap reached, disconnect and rejoin. Reconcile missing LuckLevel to the approved default; validate finite integer range and preserve legitimate existing progress. Do not invent extra save fields to make tests easier.
## 6. Module L: luck

**L-01 The Lucky Clover kiosk (MUST).** In every Launch Pad (A-06's layout), to `R7-IMG-14`: a small stand with a giant spinning clover, sparkles, a shopkeeper or a clover mascot (your call), and a panel showing the stat now and after ("LUCK x1.5 -> x2"), the price, one BUY button, and what luck does in one kid-readable line ("Rare cars show up more often!"). Clover colour by level: green (x1.25, x1.5), gold (x2, x3), purple (x4). Matches the Pit Stop in quality.

**L-02 The odds rule (MUST).** Luck L multiplies the spawn weight of Legendary and Epic cars by L and of Rare cars by (1 + (L - 1) / 2); Commons (and the Uncommons drawn from them) take what is left, never below 35% of spawns (if they would, scale the others down evenly). Put the rule in one shared module both sides use; the server sends the player's L inside the run start. Write the resulting table (each level, the share of each rarity at the start, middle and late part of a run) into the ledger.

**L-03 Feel (SHOULD).** A green clover sparkle on a car that spawned because of luck is not possible to know honestly, so do not fake it. Instead: the clover badge on the HUD, and a "LUCKY!" pop when a Rare or better spawns while L > 1.

**L-04 Proof (MUST).** A self-test that draws 20,000 spawns at L = 1 and at L = 4 with the real sequence code and checks the Rare-and-better share rose as the table says (within 1 percentage point). Then two real autopilot runs at L = 1 and L = 4 with the counts recorded.

[ChatGPT] L-02 interpretation: the specific formula in L-02 governs the general xL wording in section 0: Rare uses 1 + (L-1)/2, Epic and Legendary use L. Publish actual normalized percentages, not a claim that every final probability is exactly multiplied by L.
[ChatGPT] L-02 algorithm clarification: start from the existing normalized probabilities for that World/stage; multiply the Rare/Epic/Legendary probabilities by their specified factors. If their sum exceeds 0.65, scale those three proportionally to total 0.65. Allocate the remaining mass to Common/Uncommon using their existing relative split. Assert nonnegative finite probabilities summing to 1 and preserve L=1's baseline when it satisfies the 35% floor. If a baseline already violates the floor, record that conflict rather than silently claiming both constraints passed.
[ChatGPT] L-04 test design: use deterministic recorded seeds and the production sequence code, including its World/stage filters. Report expected and observed percentages for each rarity, sample counts, seed and deviations; do not reroll seeds until the check passes. Test all five purchase levels, baseline, clamp boundary and invalid saved input. The two play runs are an integration check, not statistical proof of the probability table.
[ChatGPT] L policy correction, checked 2026-11-05: [Roblox paid random items policy](https://create.roblox.com/docs/production/monetization/paid-random-items) explicitly includes luck/probability modifiers and indirect Robux purchases. Luck bought using currency that can be bought with Robux is not automatically exempt merely because its button says Cash. Purely earned, non-purchasable currency avoids that purchase route, but this brief includes Cash packs and a Cash-bearing Starter Pack. Keep RealPurchases=false as decided; record the future monetization conflict without changing section 0. Before any future sales, audit every paid route to Cash/luck and apply the required numerical odds disclosures and per-player PolicyService restrictions if applicable. Do not create a new currency or silently remove a product in this round. No legal or platform clearance is established by this note.
## 7. Module C: cosmetics that are real

Adam: "If I bought a paint and I equipped it, I expect to see it when I'm doing the run." Everything here must show **on the car you have selected to drive**, in the Style Shop preview, in the run, at the Raceway (if that car is in your Lineup) and in the Garage.

**C-01 Preview on your car (MUST).** Every Style Shop preview (paint, decals, wheels, trails) shows **your selected run car**, not the showroom supercar. A turntable you can rotate with drag, and a "TRY" state before buying.

**C-02 Paint only on paint (MUST).** Adam: white paint puts "a white film over the entire car". Paint must cover only the body panels: never the windows, tyres, rims, lights, grille, chrome, interior or number plates. Inspect Brian L's car models (`assets/cars`) to see how they are built. If the body is a separate part or material, paint only that. If body and glass share one mesh, split the body out in Blender through the Blender MCP for all 27 cars and every edition variant, keeping names and attributes (section 0 item 1 allows this; list every model touched for Brian L). Tag paintable parts with one attribute (`Paintable = true`) so paint, decals and editions all use the same rule. Check every car in a 27-car contact sheet frame.

**C-03 Paints that make you want them (MUST).** To `R7-IMG-08` and `R7-IMG-09`. Tiers, cheapest to dearest, each tier clearly fancier and the prices climbing hard (Adam: "after we go to some cool colours that are moving, galaxy, rainbow, sparkles ... it should really be increasing in price a lot"):
1. Solid (about 8): cheap Cash.
2. Metallic and pearl (about 6): more Cash, real shine (`Reflectance`, `SurfaceAppearance` or a clearcoat look).
3. Two-tone and gradient (about 6): two colours fading across the body.
4. Animated (about 6): colours that move: colour shift, aurora, lava, ocean waves, neon pulse.
5. Legendary Cash paints (about 4): galaxy (stars drifting), rainbow (cycling), sparkle (glitter that twinkles), chrome mirror. Very expensive.
6. Robux paints (about 3): the most insane looks (holographic, molten gold, electric). Plus the VIP paints (section 0 item 12).
Price ladder (PREVIEW, your call within it): tier 1 about $500 to $5K, tier 2 $10K to $100K, tier 3 $250K to $2M, tier 4 $5M to $50M, tier 5 $100M to $2B. Animated paints must run cheaply (one shared animation loop, not one per part).

**C-04 Decals (MUST).** To `R7-IMG-10`. About 20 decals: simple shapes (stripes, chequers, numbers, stars) cheap; flames, lightning, wings, tribal-free swooshes, splatter, circuit lines in the middle; animated gradient decals (shimmering flames, pulsing lightning, scrolling chevrons) dear. Adam: flames "should be way higher in price than checkers". Prices climb like paint. Decals sit on the body panels only, follow the body's curves (decal or texture on the paintable parts, mirrored left and right), and show in the run.

**C-05 Wheels and rims (MUST).** To `R7-IMG-11`. About 14 designs: rims (multi-spoke, deep dish, turbine, mesh, split-five, neon ring, glowing hub, gold, chrome, carbon) and tyre styles (white wall, coloured stripe, glowing tread). Real 3D wheels made in Blender, sized per car (one wheel model scaled to each car's wheel size). They spin with the car's speed.

**C-06 Trails like Rocket League boosts (MUST).** Adam: trails today are "a little blob coming out of the back of the car ... I want them to really be coming out of the back of the car, moving around ... not a 2D image ... the Comet Trail could look a lot cooler." Study how Rocket League's boost trails read (official Rocket League material only for research; copy no names or art): they come out of exhaust points, they are layered (a hot core, a flame or energy body, sparks or particles, a fading tail), they react to speed, and each has a signature shape. To `R7-IMG-12`. At least 12 trails, each built from layered `ParticleEmitter`s, `Beam`s and `Trail`s from two exhaust points:
- **Flame Rush:** licking flames popping out the back, embers and sparks spitting sideways, heat shimmer.
- **Comet:** a glowing head with a long, sweeping tail of light and small chunks of ice breaking off.
- **Lightning:** crackling bolts jumping between the exhausts and the road, blue sparks.
- **Neon Ribbon:** two ribbons of light that twist around each other.
- **Galaxy:** stars and a purple-blue nebula smoke.
- **Rainbow Road:** a rainbow ribbon on the road with sparkles.
- **Bubble Pop:** bubbles that pop into little stars.
- **Confetti Party:** confetti bursts and streamers.
- **Pixel Blast:** retro square particles in arcade colours.
- **Frost Bite:** ice crystals and cold mist.
- **Toxic Slime:** green goo drips and glowing bubbles.
- **Golden Glory:** gold sparks and coins.
- Plus the **VIP gradient trail** (section 0 item 12): an animated gradient ribbon in VIP colours with sparkles, tagged "VIP PASS".
Cheap ones for Cash, flashy ones dear, a few for Robux (the four Robux trails from earlier decisions stay). Every trail shows in the run behind your car (and during the Hop float, from the car you left), and in the Style Shop preview. Budget: count particles at full speed with 6 players on the island and in a run; keep within budget on phone.

**C-07 One Style Shop (MUST).** Section 0 item 14, to `R7-IMG-07` and `R7-IMG-08`: one stand per Launch Pad, a cool garage-boutique look with icons on top for Paint, Decals, Wheels and Trails. The panel has the four tabs, a big preview of your car, owned and equipped states, prices, TRY, BUY and EQUIP.

**C-08 Equipped means visible (MUST).** One `StyleState` (exists from Round 6) that the run car, the Raceway Lineup cars, the Garage and the Launch Pad card all read. Test: buy and equip one of each (paint, decal, wheels, trail), start a run, take frames: all four visible on the run car. Rejoin: still equipped.

**C-09 More pick-me moments (SHOULD).** Your call on small touches: a "NEW!" dot on the Style Shop when you can afford something, a sparkle when you equip, a horn honk when you equip wheels.

[ChatGPT] C-01/C-07 interaction contract: TRY changes only the local preview; cancel, tab change, closing and selecting a different car clear it. BUY is pending until server acknowledgment; EQUIP requires ownership. Keep distinct states for locked, affordable, unaffordable, pending, owned, equipped, unavailable price and failed load. Preview remains the selected owned car in all four tabs. Unknown Robux metadata disables purchase; R$ --- in the mockup is never a live sale price.
[ChatGPT] C-02 delivery: inventory all 27 source models and variants before edits. Preserve a source backup outside Git, rig/attachment names, wheel pivots, bounds, UVs, scale and collision behavior. Paintable tags apply only to body surfaces; windows, lamps, tyres, rims and interiors must remain unchanged under white, dark and animated paint. Validate every model in the contact sheet and spot-check each distinct construction family in motion.
[ChatGPT] C-03/C-04 performance: one client cosmetic animator updates only visible active instances at a measured cadence; pause hidden shop previews and distant effects. Prefer parameter animation to repeated texture uploads or large frame sequences. Record what truly moves on the body versus what merely changes color. Do not present a static gradient plus particles as a completed scrolling decal.
[ChatGPT] C-05 fitting: preserve physical wheel behavior and replace cosmetic geometry only unless the existing rig requires otherwise. Document each wheel center, axle axis, diameter and mirrored side. Test steering and full rotation without clipping the fender or touching glass/body paint masks.
[ChatGPT] C-06 acceptance: each of the 13 trails needs a recognizable silhouette at chase-camera distance, two coherent exhaust origins, a bright compact core and a tapering tail. Do not stack identical cones with different colors. Demonstrate start, full speed, float, stop, preview and cleanup. In a stationary preview, deliberately animate the preview emitter/attachments; a Trail does not grow from a motionless pair. Decorative lightning never changes damage or collisions.
[ChatGPT] C-08 lifetime/replication: one authoritative owned/equipped state drives local rendering adapters for all four contexts. Preserve existing per-car versus account-wide semantics; record the contract before bridging modules. Test equip then remove that car from Lineup, change selected car, stream out/in, rejoin and view another player's car. Dispose emitters, ribbons, sounds and update connections when a model is removed; reset pooled cars before reuse. No leaked effect or previous owner's paint.
[ChatGPT] C-02/C-03 research verified 2026-11-05: SurfaceAppearance.Color is a runtime multiplicative tint; a near-white albedo gives controllable colors. Overlay reveals MeshPart.Color through alpha, while TintMask uses alpha to select tinted regions. A tint mask can preserve non-painted details when authored correctly, but does not replace the requested body separation when glass needs different material/transparency. [Roblox PBR textures](https://create.roblox.com/docs/art/modeling/surface-appearance). Texture-map setters are marked Plugin Security in the [SurfaceAppearance API](https://create.roblox.com/docs/reference/engine/classes/SurfaceAppearance): do not assume a LocalScript can swap every PBR map per frame. Pre-author surfaces and animate supported Color/emissive parameters on the installed build.
[ChatGPT] C-03 material clarification, checked 2026-11-05: MaterialVariant is a reusable tiling material; SurfaceAppearance follows a particular mesh's UVs. Material variants can also affect physical properties. Select a preauthored per-part variant and tint the intended body; do not mutate a shared variant globally to recolor one player's car. [Materials](https://create.roblox.com/docs/parts/materials), [MaterialVariant API](https://create.roblox.com/docs/reference/engine/classes/MaterialVariant). A chrome treatment should use metalness/roughness and the environment's reflections; the concept's perfect mirror is not a promise of scene-accurate mirror rendering.
[ChatGPT] C-04 current API correction, checked 2026-11-05: [Decal](https://create.roblox.com/docs/reference/engine/classes/Decal) now exposes ColorMapContent, Color3, UVOffset, UVScale and Rotation; Texture is marked deprecated. For a cheap genuinely moving supported decal, animate UVOffset over one reusable texture rather than uploading/replacing frames. This is an implementation recommendation, not a benchmark. Decal remains a face-based projection, not an automatic UV wrap across arbitrary curved car panels; prove fit on the actual body and use a properly authored body-only UV surface where projection fails. Cheap color cycling uses tint; it is not equivalent to moving lava or a scrolling chevron. Verify property availability and rendering in the installed client before choosing a fallback.
[ChatGPT] C-06 particle research verified 2026-11-05: FlipbookLayout selects an animated atlas layout; Squash stretches sprite aspect over lifetime; Drag damps motion; VelocityInheritance inherits the parent's velocity at emission; ZOffset biases rendered depth toward/away from camera, not physical exhaust position. LightEmission controls blending, not actual illumination; LightInfluence determines response to environment light. Use attachment orientation, speed/spread, lifetime and transparency to build the plume. For anchored CFrame-driven cars, do not assume parent physics velocity equals visual speed: test and supply the intended visual behavior. [ParticleEmitter API](https://create.roblox.com/docs/reference/engine/classes/ParticleEmitter).
[ChatGPT] C-06 geometry correction: ParticleEmitter particles are 2D sprites placed in 3D space. The requested dimensional effect comes from multiple origins, depth, movement and complementary ribbons; it is not a promise that each particle is a volumetric mesh. [Particle emitters](https://create.roblox.com/docs/effects/particle-emitters), checked 2026-11-05. For Flame Rush, use animated flame silhouettes and rising wisps; no custom screen-refraction/heat-distortion shader was verified, so name any approximation honestly.
[ChatGPT] C-06 Beam/Trail implementation, checked 2026-11-05: a [Beam](https://create.roblox.com/docs/reference/engine/classes/Beam) connects two attachments and supports curvature, endpoint widths, texture scrolling and segment count. Use it for a coherent core/ribbon, with modest segments. A [Trail](https://create.roblox.com/docs/reference/engine/classes/Trail) records moving attachment spans with Lifetime, WidthScale, transparency and length controls; clear it on teleport/reuse so it cannot draw a giant line across the island. Use short lifetime and a narrowing, fading tail, then layer sparse particles around it.
[ChatGPT] C-06 phone guidance verified 2026-11-05: Roblox documents per-emitter limits of 400 particles/second, 100 on mobile; these are ceilings, not a safe scene budget. Large transparent coverage and overlapping layers cost fill-rate. Flipbooks may deactivate under low memory, so reuse small atlases and keep a readable static fallback. [Particle emitters](https://create.roblox.com/docs/effects/particle-emitters). Measure simultaneously visible cars/effects, not only one trail in isolation; track rate times lifetime plus bursts, screen coverage and frame time. Avoid changing every emitter property every frame. [Improve performance](https://create.roblox.com/docs/performance-optimization/improve).
[ChatGPT] C-06 official visual study, checked 2026-11-05: the [Rocket League Season 24 article](https://www.rocketleague.com/news/rocket-league-heads-to-the-streets-in-season-24) (published 2026-09-18) and its linked rear-car effect image show concentrated bright origins, long directional ribbons and a separate spray of small particles; the flame promotional image shows a dense hot body behind the vehicle. Our interpretation: assign each Catch A Car! effect a compact core, characteristic body, sparse breakup particles and a fading tail, then tune color/length with speed. Speed-dependent color change was not verified from these stills; it is our proposed implementation within the requested effect, not a statement about Rocket League's shader. Copy no licensed car, logo, effect art or marketing text.
## 8. Module U: screens

**U-01 Upgrade screens (MUST).** Adam: the Raceway and parking upgrade screens "look really bad". Redesign both to `R7-IMG-02` and `R7-IMG-03`: the Raceway card framed by a racetrack border (kerbs, chequered corners, a little car running around the border), showing level now, level next, what the next level adds (a small preview image or icons), the multiplier, the price, one big BUY. The parking card in a paddock style (bay lines, a parking sign) with spots now and next, the next tier's look, price, BUY. Both at phone, tablet and desktop.

**U-02 Pick a car with confidence (MUST).** In the Garage, tapping a car shows it large with a big "RIDE THIS CAR" (or GO) button; pressing it gives a clear confirmation: a green check, "Ready to ride: <name>!", the card glows, and the Launch Pad card shows it. Adam: "I want some kind of confirmation of what car I'm choosing."

**U-03 Garage Index without editions (MUST).** Section 0 item 15. Remove the Normal / Gold / Diamond / Rainbow / Galaxy ladder from the detail, then recompose the layout so there is no empty space (bigger car, stats in a tidy row, the edition badge on the card corner). To `R7-IMG-21`.

**U-04 Results (MUST).** Remove RESPAWN FREE (`src/client/UI/Prototype/Screens/RunResults.luau`, the `RESPAWN FREE (%d)` line, and every revive path behind it). Fix the white outline that cuts the close button. A "GREAT RUN!" header, distance, cars caught with portraits, Cash earned with a count-up, the 19 Robux respawn (Coming soon), HOME. To `R7-IMG-17`.

**U-05 Missions, many more (MUST).** About 45 missions across five tabs: Starter, Racer (runs, hops, distance), Collector (cars, rarities, editions), Tycoon (Raceway levels, spots, Cash earned), Style (paints, decals, wheels, trails). Creative ones: "Hop 3 cars without touching the road", "Catch a car in every World", "Fill your Raceway with Rare or better", "Bump-free run of 1,000 m", "Own a Gold edition", "Equip a full look". A claimable mission glows green with a pulsing CLAIM; the Missions button shows a red count of claimable missions. No timers, no daily resets, no streaks. Rewards PREVIEW Cash scaled to the stage. To `R7-IMG-19`.

**U-06 Shop fixes (MUST).**
- The Starter Pack icon must not say FREE anywhere (Adam saw it on the gift icon). Replace with the `R7-IMG-20` art.
- VIP: a richer badge (the crown plus the VIP trail swirl and a name tag) and the benefit list from section 0 item 12.
- Double Lap Pay: a full banner, not an empty one (a stopwatch, x2, cash bursting, a car on a track).
- The HUD Cash "+" opens the Shop on the **Cash** tab, not Featured, and the "+" is a little smaller (Adam: "a little bit too big").

**U-07 Stamina and Luck panels (MUST).** Adam: "I want the actual buy screen to look cooler." The Pit Stop (stamina) and Lucky Clover panels to `R7-IMG-13` and `R7-IMG-14`: the bolts or clovers as big shiny icons, now vs next, the price, BUY with a satisfying moment (bolts charge up with electric sparks; clovers burst into leaves).

**U-08 The Round 6 leftovers (SHOULD).** From Round 6's reviewers: the phone HUD Cash counter sits mid-screen; Settings is pastel and off-style; small text under 14 px (Skip, Includes); the Shop's cash pack row is cut off at phone and tablet sizes; the Garage SORT plate is empty. Fix each and re-score (V-03's round 2 that Round 6 could not do).

[ChatGPT] U-01/U-02/U-03: actual next-tier geometry and actual catalog prices replace the image examples. Show MAX explicitly at cap. Disable repeated buys while pending and refresh both displayed values after server success. RIDE THIS CAR confirms only after the selection is accepted; update Launch Pad preview from that state. Remove only the edition ladder UI, never copy progression or saved editions. The reference's illustrative stat names do not authorize a new Boost stat.
[ChatGPT] U-04/U-05: remove free respawn from button, keyboard shortcut, old remote and server grant paths. Coming soon cannot prompt a real purchase. Mission claims are server-validated and idempotent across rejoin; use existing approved persistence for progress and claim IDs. If the permitted schema cannot support a mission safely, record that dependency rather than add an unauthorized field or award it every join. Full look means the four existing cosmetic categories, not the picture's invented fifth slot. Claim-count badge equals claimable unclaimed missions across all tabs.
[ChatGPT] U-06/U-07/U-08: current Starter Pack contents win over old art; no FREE text, hidden price or benefit not granted by the product. Encode stamina as value, not icon count: 7 = purple + purple + yellow; spending one yields 6 = purple + purple. Test every value 0–15. Luck's next-level preview must be visually distinct from levels already owned. Measure 44-pixel hit areas at the actual UI scale, including close controls; verify safe insets, wrapped long names, scrolling to the last item and no overlap with the HOP button.
## 9. Module K: the Raceway shows off

**K-01 Rare cars look special on the Raceway (MUST).** Adam: "maybe it should have some special effects or like a purple glow if it's an epic ... more of an accomplishment, more of a bragging factor." To `R7-IMG-18`:
- Uncommon: a soft green underglow.
- Rare: a blue underglow and a faint shimmer on the body.
- Epic: a purple aura and rising sparkles, a purple light strip on its parking bay.
- Legendary: a gold aura, a gold light pillar over its bay, the crowd cheers and a few fireworks when it crosses the finish line.
- Editions: Gold shines, Diamond glints, Rainbow cycles, Galaxy shows drifting stars.
Other players walking past should see who has the good cars.

**K-02 Money you can see (SHOULD).** From the reference: a small floating "$/lap" tag over each Lineup car, and "+$" pops at the finish line as laps pay. A setting turns the tags off.

**K-03 EQUIP BEST (SHOULD).** In the Lineup panel, one button fills the Lineup with your best-paying cars (the reference's "Equip Best").

**K-04 Bays and badges (MAY).** A name plate on each parked car with its rarity colour.

[ChatGPT] K-01 visual precedence: body paint remains the chosen paint; rarity is communicated primarily by underglow/aura and labels, with edition treatment layered without erasing the purchased appearance. Test ordinary and every edition with cosmetics together. Distance-cull ambient effects and rate-limit cheers/fireworks across cars so six players do not produce continuous flashes.
[ChatGPT] K-02/K-03: display actual per-lap pay, not a per-second approximation or a generated-image number. Visitor effects never grant the visitor money. EQUIP BEST is a server operation using owned eligible cars, actual capacity and a deterministic tie-break; repeated presses cannot reset lap payout timing or create duplicate Lineup entries.
## 10. Module H: the loop, tightened (Claude's recommendations from the reference)

These are recommendations Adam accepted with "go with your recommendations". Each is small; together they make the loop pull.

**H-01 One goal line, always (MUST).** At the top of the hub screen, one short line that always says the most useful next thing ("Catch cars to earn more money!", "Buy Raceway level 3!", "5 Downtown cars opens Dusty Highway!"), driven by the mission feed. Hidden during runs and the tutorial banner.

**H-02 Coach Roxy's next goal (SHOULD).** Tapping Roxy (at the portal plaza) shows her current goal card with a progress bar, like the reference's Captain card (`contact-sheet-2.jpg`, row 1).

**H-03 Kiosk signs (MUST).** Every upgrade kiosk (Pit Stop, Lucky Clover, Raceway shop, parking) has a floating sign readable from 20 studs: name, "now -> next", price.

**H-04 Fast loop (MUST).** From the end of a run to the next START should take under 20 seconds of walking for a player who wants to go again: your plot, then the portal, then the ramp. Measure it; if it is longer, add a boost lane or move things.

**H-05 Failure that teaches (MUST).** Every way a run ends names one upgrade: out of bolts (Pit Stop), overheated (a tip about hopping sooner), wrecked by bumps.

**H-06 Sound (SHOULD).** Distinct sounds for: the ring locking on, the leap, the dive, a claim, a Rare/Epic/Legendary entering view, a bump, a wreck, buying an upgrade, collecting offline Cash.

**H-07 A first five minutes that hooks (SHOULD).** Walk a brand-new save from join to the second run with a timer and record where it drags. Fix the slowest step.

**H-08 Pacing check (SHOULD).** Re-run `economy-pacing-sim.js` with luck and the new offline rule and record World 2 and World 3 times.

[ChatGPT] H-01/H-02/H-03: one goal source controls the hub hint and Roxy card; tutorial/modal/run priority suppresses overlapping instructions. Signs show MAX at cap and exact missing requirements. The earlier Module R parenthetical pointing to H-02 for Brian R's message is a cross-reference error: the handoff requirement is N-01.
[ChatGPT] H-04/H-05/H-06: time real walking from the farthest assigned plot through portal to START; record walking time separately from loading/menu time. Do not demonstrate the limit with a developer teleport or increased test-only speed. Failure text teaches a free skill response (hop sooner, avoid traffic) where appropriate, not an upgrade upsell for every loss. Deduplicate rarity-entry sounds, cap simultaneous voices and preserve mute/reduced-motion settings.
[ChatGPT] H-07/H-08: use a fresh Mock save without seeded money or unlocked Worlds for first-session observations. Record actual seconds to first control, first capture, first payout, first upgrade and second run. A pacing simulation estimates a model; it does not establish player retention or enjoyment.
## 11. Module M: the Robux pipeline, finished

**M-01 Products (MUST if R7-S04 granted).** Create the Developer Products and Game Passes from `BetaProducts.luau` under LEGION STUDI0S, **off sale**, with art; fill the ids. VIP's benefits are section 0 item 12 (no lounge).
**M-02 Studio test purchases (MUST if M-01).** One Cash pack, the Starter Pack, one pass and the respawn, solo, then two clients.
**M-03 Uploads (MUST if R7-S04 granted).** Round 6's `art_pass_starter.png` and `art_pass_paddock.png`, and every new image this round.
**M-04 Product art (SHOULD).** From `R7-IMG-20`.

[ChatGPT] M-01/M-02/M-03 boundaries: section 0 keeps RealPurchases=false. Inspect whether each product type actually exposes an off-sale control; never assume a game-pass toggle exists for Developer Products. Product creation is not permission to turn on purchase prompts. Record the actual configuration and keep all live purchase entry points disabled. Studio test feedback is not proof of a live receipt or real payment.
[ChatGPT] M-02 verification: exercise receipt idempotency, pending retry, duplicate receipt and reconnect using mocks/test paths; grant each entitlement once from server-owned product definitions. Never make a real charge merely to obtain evidence. M-03's upload list needs production-ready isolated assets; these 22 reference sheets are not automatically usable decals, portraits or whole-screen UI. Check old Starter Pack art against U-06 before uploading; do not re-upload obsolete FREE artwork. Record actual asset owner, moderation/availability and ID only after success.
## 12. Module N: messages to the team (MUST)

- **N-01 Brian R** (`vault/design/specs/lane3-round7-for-brian-r.md`): Adam opened every lane this round and Brian R agreed. List every file changed in his folders, what and why (the two-press Hop, Heat, size, bumps, the avatar fix, End Run, the world that never ends, luck in the sequence), the pull request into his branch, and Replies.
- **N-02 Brian L** (`vault/design/specs/lane3-round7-for-brian-l.md`): the car models changed for paint (C-02), the new beta fields (`LuckLevel`, `Style` if used), the luck odds rule, the offline rule, the cosmetic price ladders (all PREVIEW for him to own), and Replies.
- **N-03** Board lines, decision 0042, log entry.

[ChatGPT] N-01/N-02/N-03: append factual handoffs and Replies without rewriting teammate text. Include changed paths, interface/data changes, compatibility risks, actual checks and unverified items. The PR into Brian R's branch remains for him to review, never merged by this round. Keep these requested messages in the vault; no unrelated external messaging is implied.
## 13. Module T: tests

**T-01** `./scripts/check.ps1` exit 0 on every branch you push.
**T-02** Self-tests for every new server rule (luck, bumps, offline, portals, stamina buy, cosmetics ownership).
**T-03** The two-client suite and the rejoin suite with the new spawn, purchases (if M-01) and cosmetics.
**T-04** A 10-minute run in each World (R-08) and a cold join of the published place (R-09).
**T-05** Visual frames at phone, tablet and desktop for every screen in Modules U and C, and two fresh Sonnet reviewers scoring each (at most 12 frames each, as R4-S09), fixing anything under 4, up to three rounds.
**T-06** Six-client suite if memory allows.

[ChatGPT] T evidence contract: each requirement row names its evidence file, exact tested branch/commit, environment and status (pass, fail, partial or blocked). Code inspection, automated self-tests, Studio play, multi-client play and published-client checks are different evidence categories. Studio device emulation is a viewport/input approximation, not proof of mid-phone GPU performance. State the missing real-device evidence honestly.
[ChatGPT] T-02/T-03: include stale UI, duplicate request, invalid argument, insufficient balance, disconnect during operation and rejoin for purchases/claims. Use ProfileStore.Mock and test identities; no live data edits. A two-client test must show each client's independent portal, plot, run and cosmetic state, not two screenshots from a single client.
[ChatGPT] T-05 review rubric: score hierarchy/readability, reference fidelity, geometry/art cohesion, device fit and state correctness separately with file-backed defects. Reuse the same bounded reviewer assignments for correction rounds; every required screen/profile must be covered even if grouped across sets. Unseen screenshots are unreviewed, not 5/5. If a reviewer or capture tool fails, record the gap and continue independent checks.
[ChatGPT] T performance clarification, checked 2026-11-05: [Roblox design-for-performance guidance](https://create.roblox.com/docs/performance-optimization/design) says Studio device emulation helps aspect ratio and controls but does not accurately represent device memory. Record emulator and desktop measurements as such; a real phone check remains separate.
## 14. Module F: finish

- **F-01** Push every branch; open or update pull requests: `feature/lane3-round7` to `main`, `feature/lane1-round7-from-adam` to `feature/lane1-run-prototype` (for Brian R; never merged by this round), `integration/beta-5` draft.
- **F-02** Merge `feature/lane3-round7` into `main` only if every MUST passed (Adam requests the merge under that condition). Run the push sweep again and update the branch table.
- **F-03** Publish per section 0 item 18, then join the published place once if a signed-in Roblox Player is available to you without stealing focus; if not, say so and make it walk-through item 1.
- **F-04** `review\round7\RESULT.md`: the MUST table, your calls, open items with the next action, the branch table, and a fifteen-item walk-through for Adam in play order (plain words, where each button is), covering: spawn at your Raceway, your badge from the island centre, a two-press Hop, a Legendary on the road, a bump, End Run, Results, buying stamina, buying luck, buying and equipping a paint and a trail and seeing them in a run, the Raceway rare-car glow, Welcome back money arriving, Missions claim, Coach Roxy at a locked portal. Give the MUST table and the walk-through in your final message too.

[ChatGPT] F-02/F-03 completion gate: a required published cold-join check cannot be marked passed before the final build is published and tested. If that evidence is unavailable, leave the relevant MUST and merge gate pending; section 0's publication permission does not authorize calling an untested merge ready. Preserve the stated work order and report the dependency explicitly.
[ChatGPT] F-04 closeout: separate what was implemented, what was actually tested and what Adam must still do. Include reversible decisions, asset IDs with ownership, permission blockers, performance measurements, branch/PR states and the fifteen-step walkthrough. No fabricated screenshots, IDs, approvals, device results or promises of flawless output.
## 15. Not in this round (visible, not forgotten)

Real sales on; a public publish; the Stunt Circuit gameplay; cross-server leaderboards; trading; an offline-earnings upgrade; Brian L's real server replacing the stand-ins; a multi-day playtest with kids; the release checklist's Adam-only steps (eligibility, questionnaire, store page upload).
[ChatGPT] Revision note — 2026-11-05. Added implementation states, edge cases, test gates and bounded-agent execution guidance without removing original text or changing section 0, section 1, requirement IDs, priority labels or work order.
[ChatGPT] Verified: official Roblox API/policy/performance documentation linked in the matching modules; official Rocket League promotional stills; the supplied dinosaur reference sheets and available Round 6 evidence; 22 generated PNG files and their recorded actual dimensions. All added brief lines carry this marker.
[ChatGPT] Not verified: installed Studio API behavior, live repository implementation, asset permissions or uploads, real purchases, live data, animation, published gameplay, phone GPU performance or playtest outcomes. The official preload-document conflict needs an installed-version probe. Images are direction and retain illustrative details documented in GENERATION-NOTES.md; the tool did not return the exact requested canvas dimensions. No game implementation or publishing was performed in this editorial task.
[ChatGPT] Reference files (under chatgpt-images):
[ChatGPT] - R7-IMG-01-coach-roxy.png
[ChatGPT] - R7-IMG-02-raceway-upgrade-card.png
[ChatGPT] - R7-IMG-03-parking-upgrade-card.png
[ChatGPT] - R7-IMG-04-downtown-launch-pad.png
[ChatGPT] - R7-IMG-05-dusty-and-summit-launch-pads.png
[ChatGPT] - R7-IMG-06-launch-card.png
[ChatGPT] - R7-IMG-07-style-shop-kiosk.png
[ChatGPT] - R7-IMG-08-style-shop-panel-paint.png
[ChatGPT] - R7-IMG-09-paint-swatches-sheet.png
[ChatGPT] - R7-IMG-10-decals-sheet.png
[ChatGPT] - R7-IMG-11-wheels-and-rims.png
[ChatGPT] - R7-IMG-12-trails-sheet.png
[ChatGPT] - R7-IMG-13-pit-stop-stamina.png
[ChatGPT] - R7-IMG-14-lucky-clover.png
[ChatGPT] - R7-IMG-15-run-hud-and-targets.png
[ChatGPT] - R7-IMG-16-two-press-hop-storyboard.png
[ChatGPT] - R7-IMG-17-results-and-wrecked.png
[ChatGPT] - R7-IMG-18-raceway-rare-glow.png
[ChatGPT] - R7-IMG-19-missions.png
[ChatGPT] - R7-IMG-20-shop-tiles.png
[ChatGPT] - R7-IMG-21-garage-pick.png
[ChatGPT] - R7-IMG-22-island-hub.png
