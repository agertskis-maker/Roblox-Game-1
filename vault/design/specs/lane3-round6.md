# Catch A Car!: Lane 3 Round 6 (merge everything, make it look cooler, real goals, Stunt Circuit screens, Robux pipeline, release checklist)

**For:** Claude Code, on Adam's Windows laptop, repository `Roblox-Game-1`, in its own worktree `C:\Users\agert\Documents\Roblox-Game-1-round6`.
**From:** Adam (repository owner, Lane 3 owner, beta integration person), written with Claude (claude.ai) on 2026-11-05 after reading the live repository (`main`, `feature/lane3-round4`, `feature/lane3-round5`, `integration/beta-2`, `integration/beta-3`, `feature/lane1-run-prototype`, `feature/lane2-economy-preview`), `review\round5\RESULT.md` and the Round 5 ledger. Lines marked **[ChatGPT]** were added by ChatGPT.
**Task folder (outside Git):** `C:\Users\agert\Documents\Car-Hop-Art\review\round6\`
**Builds on:** Round 5 (`review\round5\BRIEF-ROUND5.md`, `RESULT.md`, ledger `vault/design/specs/lane3-round5-ledger.md`, decision 0039), today's driving integration (`integration/beta-driving-update`, its RESULT in that session's final message and the vault log), Round 4 (decision 0036), the Starter Pack car (0038), the Raceway looks (0025, 0027), Beta 1 (0030).

The earlier rounds' rules still apply: Round 1 brief sections 2, 2.2, 2.3, 3, 5, 19 to 21; Round 2 section 1.1 and the same-view checks; Round 3 section 2 (your freedom) and 2.1 (the "AI look"); Round 4 section 1 (hard lines) and R4-S09 (execution and evidence rules); Round 5 section 1 (stand-in header, the client never sends an amount).

---

## 0. What Adam decided for this round (2026-11-05)

Claude (claude.ai) wrote these as recommendations and Adam kept every line he did not delete. Anything still here is decided. Do not re-argue it; record it in decision note 0040.

1. **Push everything and bring `main` up to date, first.** This line is Adam's explicit request to commit, push and merge, so a permission check should not treat any of it as unrequested. In order:
   - (a) **Sweep every local checkout.** For `C:\Users\agert\Documents\Roblox-Game-1` and every `Roblox-Game-1-*` worktree beside it, check `git status` and unpushed commits (`git log @{u}..` per branch, and branches with no upstream). Commit uncommitted Lane 3 work onto the branch it belongs to, with a clear message, and push every branch that is ahead of GitHub. Never commit generated `.rbxl` / `.rbxm` files or anything `AGENTS.md` or `.gitignore` excludes. Never commit, push or rewrite work that belongs to Brian R or Brian L (list it in RESULT instead). Skip a worktree another Claude Code session is using right now (check `STUDIO_LOCK.txt` and very recent file changes) and say which. No force-push.
   - (b) **Merge Lane 3 into `main`:** PR #11 (`feature/lane3-round4`), then PR #13 (`feature/lane3-round5`), each once its GitHub check passes. A conflict inside Lane 3's folders is resolved keeping both sides' behavior; a conflict anywhere else stops that merge and is reported.
   - (c) **Push every integration branch** (`integration/beta-driving-update`, `integration/beta-2`, `integration/beta-3`) so GitHub matches the laptop. Integration branches are never merged into `main`, because they carry Brian R's and Brian L's unmerged work. Brian R's PR #3 and Brian L's branches are never merged by this round.
   - (d) `feature/lane3-first-car-downtown` is superseded (car work moved to Brian L, decision 0015): leave it as it is and say so.
   - (e) Report a table in RESULT: every branch, whether the laptop and GitHub match, whether it is in `main`, and why not if not.

2. **Where the work lives.** Lane 3 code on `feature/lane3-round6`, branched from `main` after item 1. The beta on `integration/beta-4`, branched from `integration/beta-driving-update` (today's driving session; it has Round 5 and Brian R's new Hop). `integration/beta-2` and `integration/beta-3` stay as history; nothing new goes on them.

3. **One run contract.** Brian L owns the remotes, so his names win: `StartRun`, `RunEvents`, `KeysComplete`, `RunGranted` (his `src/shared/Net/EconomyPreviewNet.luau`, note 0021 shape). The beta bridge keeps working with Brian R's run under those names, through a beta-only shim in `src/shared/Beta` or `src/server/Beta` (Lane 3 never edits `src/shared/Net`). The old `Beta*` names stay accepted for one round, then go.

4. **The beta paces sensibly.** The beta keeps Adam's car list (9 cars per World, same rarity shape in each World, Loaners Putter, Rustbucket and Commuter; `economy-v1-answers-from-adam.md`) and adopts Claude's candidate numbers as PREVIEW in `src/shared/UI/EconomyPreview.luau` only: Lap Pay by rarity inside a World $10 / $25 / $60 / $150 / $400, claim bonus 10x and Joyride Bonus 3x Lap Pay, a World pay factor Downtown x1, Dusty Highway x40, Summit Pass x1,600 (on Lap Pay, claim bonus and Joyride Bonus; Milestones keep their own per-World pay, which already scales), everything else (Raceway prices and multipliers, spot prices, World unlock prices, edition ladder) unchanged. Brian L's numbers replace these the moment he answers; his review is in `economy-preview-review-for-brian-l.md`.

5. **`Copies` becomes the lifetime total** (Brian L's meaning), and REMOVE in the Lineup leaves the spot empty (no auto-refill of a spot the player emptied; auto-park only places new claims). Both are what Lane 3 recommended to Brian L; if his reply says otherwise before you reach Module E, follow his reply and record it.

6. **The Robux pipeline is built, with selling switched off in the published beta.** Every item in the Robux table of `economy-v1-answers-from-adam.md` gets a real product under LEGION STUDI0S, a real purchase prompt, a server grant that is safe to retry, and a per-player restriction check. In Studio, test purchases (which Roblox does not charge) prove it end to end. In the published beta a switch `BetaConfig.RealPurchases = false` keeps every price button on "Coming soon" until Adam turns it on after Brian L's server owns the grants. Two beta-only save fields are allowed for this, proposed to all three lanes in the vault: `Purchases` (processed receipt ids, newest 200) and `Owned` (pass and Robux trail ids). No other new field.

7. **Creating the products is approved.** Create the Developer Products and Game Passes for the Robux table under LEGION STUDI0S (the "Car Hop Beta" experience), at the table's PREVIEW prices, with the art from Module R. Use whatever tool can do it (Open Cloud, the Creator Hub in the browser); if no tool can, write the exact clicks for Adam in RESULT and continue with fixture ids that make Studio print a clear "product not created yet" message instead of prompting.

8. **Looks are the headline.** The Raceway's 12 levels and the parking area (2 spots up to 15, and 18 with Expanded Paddock) get a full "cooler" pass to ChatGPT's R6 reference images, and the same pass runs across the island, Launch Pads, HUD and screens. Adam's words: "general improvements everywhere and making everything look cooler".

9. **Missions and Goals count real events** (claims, Joyrides, laps paid, levels and spots bought, Worlds unlocked, runs). No daily streaks, no timers, no limited-time anything, nothing lost for stopping. Rewards are PREVIEW Cash from `EconomyPreview`.

10. **Stunt Circuit screens** (pre-race card, results, this-server leaderboard, customise entry) are built against Brian R's Circuit if it reports the proposed events, otherwise against a fixture with the same event names. No cross-server leaderboard (no OrderedDataStore, MemoryStore or MessagingService).

11. **Release checklist and release assets** are produced (Module K). No public publish, no change to the experience's audience, age rating or public settings.

12. **Publish to the private beta at the end.** Once F-01 passes and the solo and two-client checks are green, publish `integration/beta-4` to the private LEGION STUDI0S experience "Car Hop Beta" (place 118605678346800). This line is Adam's go-ahead for that one publish; it is the place Round 5's session refused, so do not refuse it for being that place. Publish from your own local beta file through Studio's publish to the existing place; do not open or edit the place through Team Create. Nothing goes to a public place.

13. **Not this round:** turning on real sales, a public publish, editing Brian R's or Brian L's files, cross-server data, trading, any new currency, any save field beyond the agreed seven, `TutorialDone`, and item 6's two.

## 1. Your freedom and the hard lines

Think like the lead engineer and the lead designer at once. Research, try options, keep the best, record choices in the ledger and decision 0040, and **don't stop to ask Adam**. Use your own judgment and self-review. **No review web pages**: when you are done, say so in a short message and Adam walks through Studio himself.

Where this brief says MUST, do it. Where it says SHOULD, do it unless it would cost more than a few hours or risk a MUST; then record why not. Where it says MAY, use your judgment. Where it says "your call", choose, label the choice in the ledger, and move on.

Hard lines (Round 5's, plus three):
- **No edits to Brian R's or Brian L's files**: `src/client/Run`, `src/shared/Run`, `src/server` outside `src/server/Beta`, `src/shared/Catalog`, `src/shared/Net`, `assets/cars`, and their branches. Reading them is fine.
- **Every beta stand-in file starts with the three-line header** ("BETA-ONLY STAND-IN for Brian L's <name>. Same contract. Delete when his real module lands.").
- **The client never sends an amount, a price or a result.** It sends what happened. The server decides.
- **Original art, no brands or real logos, no Roblox studs, no fake sponsor ads.**
- **No destructive Git.** No force-push. Never rewrite a teammate's text in the vault (add to Replies or new files only).
- **Never send keystrokes or clicks outside the Studio window, and never capture the whole desktop.** Check which window has focus before every keyboard action.
- **New: money is real from this round on.** A purchase grant runs only on the server, inside `MarketplaceService.ProcessReceipt` for Developer Products, records the receipt id and saves before returning `PurchaseGranted`, and never grants twice for one receipt. Game Pass ownership is checked on the server (`UserOwnsGamePassAsync` at join, `PromptGamePassPurchaseFinished` after a purchase, then re-checked). Verify every API name and behavior on create.roblox.com before using it; cite the page and date in the ledger.
- **New: fair for kids.** No FOMO, countdowns, streaks, "only today", fake scarcity, nagging pop-ups, or a purchase prompt that opens without the player pressing a button. A "not available" state is shown, never hidden, when `PolicyService` says the player cannot buy. Every Robux button says the price in Robux.
- **New: the published beta never takes real Robux this round** (section 0 item 6).

## 2. Setup

**R6-S01 Read first:**
- `AGENTS.md`, `vault/tasks/BOARD.md`, the newest log entries (2026-11-03 onward).
- Decisions 0030, 0035, 0036, 0037, 0038, 0039, note 0021, and the driving integration's decision or log entry.
- `review\round5\RESULT.md`, the Round 5 ledger, `vault/design/specs/performance-budget.md`.
- `vault/design/specs/economy-v1-answers-from-adam.md` (main) and `economy-v1.md` (`git show origin/feature/lane2-economy-preview:vault/design/specs/economy-v1.md`).
- This folder's `economy-preview-review-for-brian-l.md`, `lane3-round6-for-brian-r.md`, `economy-pacing-sim.py`, and `chatgpt-images\` with `GENERATION-NOTES.md`.
- `vault/design/specs/speedway-upgrade-looks.md`, `raceway-round2.md`, decision 0025 and 0027 (what each Raceway level already has).
- `vault/design/ui-style-guide.md`.
- Any reply the Brians added to a vault file since 2026-11-03 (`git log --all -- vault` and the Replies sections). A reply that answers something in this brief wins over this brief's recommendation; record it.
- `review\round5\PHONE-NOTES.md` and `review\round6\PHONE-NOTES.md` if either exists (Adam's notes from playing the published beta on his phone). Each line becomes an N-item in Module N.

**R6-S02 Branches and worktree.** Create the worktree `Roblox-Game-1-round6`. Do section 0 item 1's merges, then `feature/lane3-round6` from `main` and `integration/beta-4` from `integration/beta-driving-update` (fetch first; if that branch does not exist or its session reported failure, branch from `integration/beta-2`, merge `main`, and record why). Claim the task on the board.

**R6-S03 Studio.** Respect `STUDIO_LOCK.txt`. Make a fresh local beta file `Car-Hop-Art\CarHop-Beta-4-local.rbxl` and a dated backup before any big change. `rojo serve beta.project.json`. If the Rojo plugin needs a Connect click, ask for it once in your first message and never again.

**R6-S04 Audio recorder.** Round 5's videos were blocked by Windows Application Control. Before any video work, check whether `Car-Hop-Art\tools\audio-capture\ProcessAudioCapture.exe` now runs or "Stereo Mix" is on. If neither, record the videos silent and labelled, and keep going.

**R6-S05 Ledger and decision.** Ledger `vault/design/specs/lane3-round6-ledger.md` (copy this brief to `vault/design/specs/lane3-round6.md`), decision `vault/decisions/0040-lane3-round6.md`. Evidence types as in Round 5 (code, self-test, solo Play, frame, multi-client, published). "Not done" is never written as a pass.

**R6-S06 Order of work and what to drop.** Work in this order: S, E, V, R, G, C, K, N, H, F. If time runs short, drop in this order, recording each: N-04, C-04, V-05, K-03, G-03, C-03. Never drop a MUST in E, R or F.

## 3. Module E: economy alignment in the beta (MUST)

**E-01 Candidate numbers (MUST).** Put section 0 item 4's numbers into `src/shared/UI/EconomyPreview.luau` with a `WorldPayFactor` table and one function every screen and stand-in uses, so a World's car shows and pays its World factor. Every screen still reads one module. Add a self-test that recomputes three hand-checked values: a Downtown Common at level 1 ($10 a lap), a Dusty Highway Rare at level 3 ($60 x 40 x 3.5 = $8,400 a lap), a Summit Pass Legendary Joyride ($1,200 x 1,600 = $1,920,000). Run `economy-pacing-sim.py`'s candidate case and paste its output in the ledger.

**E-02 Lifetime `Copies` (MUST).** Switch the edition ladder to the lifetime total (25 Gold, 250 Diamond, 2,500 Rainbow, 25,000 Galaxy). The card text reads "12 / 25 copies to GOLD", then "37 / 250 copies to DIAMOND". Convert existing beta saves once, on load, with a beta-only marker attribute so it never runs twice (no new save field: convert in place and log it). Self-test both a fresh save and a converted Round 5 save.

**E-03 REMOVE leaves the spot empty (MUST).** The Lineup has no gaps (cars slide left), a removed car's spot stays empty until the player fills it or a new claim auto-parks, and the panel shows the empty spot as "PICK A CAR". Test: remove, rejoin, still removed.

**E-04 One run contract (MUST).** Section 0 item 3. The beta server listens on Brian L's names; a shim accepts the old `Beta*` names for one round and logs a deprecation line once per server. Brian R's run, through today's adapter, still completes a full run, claim and Results in Play.

**E-05 Run checks hold (MUST).** Confirm by self-test that the beta still rejects: a `d` beyond reach on any event (not only the end), a far Hop (and that it never calls the sequence for that distance), Keys over the bolt cap, a Keys event faster than the Keys time, and an unknown run id. Add a Cash cap of 1e15 in the beta's `addCash` with a self-test, and record it as Lane 3's proposal for Brian L's question.

**E-06 Round 5's unwalked loop (MUST).** Walk in Play: buy a Raceway level, earn to 5 Downtown cars, unlock Dusty Highway, run there, catch a car, see it pay with the World factor. Use `BetaGrantCash` only to skip waiting, and say where you used it.

## 4. Module V: make it look cooler (MUST for V-01 to V-03)

Use ChatGPT's `R6-IMG-01` to `R6-IMG-04` and `GENERATION-NOTES.md` for direction. They are direction, not pixels: keep the game's existing style, scale, and everything decisions 0025 and 0027 fixed (the climbing far turn, the hump at 11, the loop at 12, no sponsors, "Raceway" in every player-facing word). Build new meshes in Blender through the Blender MCP where a part-built version looks cheap; upload under LEGION STUDI0S (Adam allowed Claude Code to upload its own meshes without per-item approval; list every new id in `vault/design/assets.md`).

**V-01 The Raceway ladder (MUST).** Every one of the 12 levels must look clearly better than the one before from the plot entrance and from the run's return view, and the jump at levels 4, 8 and 12 must feel like an event. Specific asks: richer ground and kerbs early (levels 1 to 3 should already look charming, not empty), crowd and bleachers that fill up as levels rise, a referee-style figure and track officials (Adam asked on 2026-10-28), lighting that gets showier at the top (floodlights, light strips, a level 12 night-time glow that also reads in daylight). Keep within the performance budget: six plots at level 12 must stay under the Round 5 baseline plus 15% parts and render CPU; measure and record.

**V-02 The parking ladder (MUST).** Today the parking bays mostly appear one by one. Make the parking area itself upgrade in visible tiers as spots are bought: tier 1 (2 to 4 spots) a painted gravel lot with cones; tier 2 (5 to 8) asphalt with bright bay lines and numbered bays; tier 3 (9 to 12) a covered paddock with a canopy, lights and a sign; tier 4 (13 to 15) a showroom paddock with a glossy floor, light strips and a turntable for the best car; Expanded Paddock (16 to 18) its own gold-trimmed extension. Use `Parking.bay(i, expanded)` for every position. The "buy a spot" moment gets a short reveal like the level-up (about 1 s, skippable, Reduce Motion version). Your call on exact tier breakpoints if the images suggest better ones.

**V-03 The "cooler everywhere" pass (MUST).** One pass over the island hub, the three Launch Pads, the HUD, Garage, Shop, Results, Lineup panel and Settings, judged against the R6 images, `ui-style-guide.md` and Round 3's "AI look" list. Two fresh Sonnet reviewers score each surface 1 to 5 at desktop, tablet and phone frames from a bounded screenshot set (at most 12 shots each, as R4-S09); anything under 4 gets fixed and re-scored, three rounds maximum. Record before and after frames.

**V-04 Round 5 visual leftovers (SHOULD).** Upload `review\round5\art\art_pass_starter.png` and `art_pass_paddock.png` under LEGION STUDI0S and wire their ids; capture the two missing Reduce Motion stills (HUD at Heat Critical, the Keys capture).

**V-05 Moments (MAY).** Your call on up to three small "feel" upgrades that make a moment land (a claim, a level-up, an edition reaching Gold), each reversible, each with a Reduce Motion version.

## 5. Module R: the Robux pipeline (MUST except R-07)

Read the Robux table and the "Recommendation for how to build them" list in `economy-v1-answers-from-adam.md` first; that is the spec. Verify every API on create.roblox.com (developer products, game passes, `ProcessReceipt`, `PolicyService:GetPolicyInfoForPlayerAsync`, `MarketplaceService:GetProductInfo` for the player's price) and cite pages and dates.

**R-01 Products exist (MUST).** Section 0 item 7. One config module `src/shared/Beta/BetaProducts.luau`: every item, its kind (Developer Product or Game Pass, your call for each with a reason; the All Passes Bundle needs a way to grant three passes, so make it a Developer Product that writes `Owned`, and treat "owns the Game Pass OR has it in `Owned`" as ownership), its id, its PREVIEW price, its art id.

**R-02 Server grants (MUST).** A beta stand-in `src/server/Beta/BetaPurchases.luau`: one `ProcessReceipt` handler, receipt id recorded in `Purchases` and saved before `PurchaseGranted`, a repeated receipt returns `PurchaseGranted` without granting again, a receipt for a player whose profile is not loaded returns `NotProcessedYet`. Grants: Cash packs use the scaling rule in the table (minutes of Raceway Cash with the "at least Nx your Cash" floor), the Starter Pack grants Brawler (or, if already owned, one Brawler copy, recorded as your call), $5,000, the paint and the decal, once per player; the respawn continues the run if it is still active, and if it is not, grants Cash equal to that run's Results total (your call; record it) so a payment is never taken for nothing.

**R-03 Prompts and states (MUST).** Every Robux button in the Shop, Results, Garage trails, HUD VIP and the parking card's GET MORE SPOTS calls one client module that checks `RealPurchases` (published beta: "Coming soon"), the player's restriction (`PolicyService`; show "Not available for your account" and never prompt), and ownership (show OWNED). Prices on buttons come from the product's own info when available, else the PREVIEW number with a PREVIEW tag.

**R-04 Passes do what they say (MUST).** Double Lap Pay doubles Lap Pay on the server; Expanded Paddock gives 3 more bays up to 18 (`ExpandedPaddock = true`, `ParkingSpots` published as bought + 3); VIP gives its paints, name tag, lounge access and 12 hours of offline earnings; Robux trails are owned and equippable.

**R-05 Tests (MUST).** Self-tests on Mock: grant once, retried receipt, unknown product, profile not loaded, Starter Pack twice, Expanded Paddock at 15 bought, restricted player (fixture). Studio test purchases of one Cash pack, the Starter Pack, one pass and the respawn, solo, then the two-client suite with one player buying while the other watches the Raceway.

**R-06 Proposal for the two fields (MUST).** `vault/design/specs/robux-fields-for-brian-l.md`: the exact shape of `Purchases` and `Owned`, why, and a Replies section.

**R-07 Product art (SHOULD).** Thumbnails for every product and pass from ChatGPT's `R6-IMG-08` set or built from the game's icon family; no car on any pass art except the Starter Pack's Brawler, which is true (decision 0038).

## 6. Module G: Missions and Goals on real events (MUST for G-01 and G-02)

**G-01 One event feed (MUST).** A Lane 3 module listens to the beta server's real events (claim, Joyride, lap paid, level bought, spot bought, World unlocked, run ended with metres) and drives the existing goal pill and Missions screen. No fake progress anywhere.

**G-02 A first set (MUST).** About 15 missions in three tiers that teach the loop in order (catch your first car, park it, earn $500, buy a spot, reach Raceway level 3, own 5 Downtown cars, unlock Dusty Highway, a Gold edition, and so on). Each has a PREVIEW Cash reward from `EconomyPreview` scaled to that stage, a clear one-line goal a 5-year-old can follow, and a claim button. Progress uses only the agreed save fields plus what the server can count live (record which missions reset on rejoin because nothing saves their progress; propose a `Missions` field to Brian L in the same R-06 style file instead of adding it).

**G-03 Goal pill polish (SHOULD).** The pill always shows the next most useful step, never more than one line, dismissible, comes back after the next run.

## 7. Module C: Stunt Circuit screens (MUST for C-01 and C-02)

**C-01 Contract proposal (MUST).** Read Brian R's Circuit code. If it reports a start, checkpoints and a finish, use what it has; if not, use the fixture events in `lane3-round6-for-brian-r.md` question 5 and keep them in one adapter.

**C-02 Pre-race card and results (MUST).** Pre-race: the car, its customisation, the track name, a big START. Results: time or distance, best this session, "NEW BEST!" moment, RETRY and HOME, Robux respawn per R-03. Both match the R6 images and the style guide at all three sizes.

**C-03 This-server leaderboard (SHOULD).** Best times of players in this server only, live, with the player's own row highlighted. Say "This server" on the board.

**C-04 Customise entry (MAY).** A button from the pre-race card into the Garage's Style screen with the selected car.

## 8. Module K: release checklist and assets (MUST for K-01 and K-02)

**K-01 Checklist (MUST).** `vault/design/specs/release-checklist.md`, every line with owner (Adam, Brian R, Brian L, Claude Code), status, and the official source page and date. At least: the group's eligibility and audience status in Creator Hub (Adam checks; Claude Code cannot see his account), the maturity and compliance questionnaire, the Experience Guidelines, icon and thumbnail rules, the description and its honesty, server size (6 players, one per plot), supported devices (phone landscape, tablet, PC), Robux items and paid-randomness status (none), `PolicyService` handling, real `DataStore` saves replacing Mock and beta stand-ins (Brian L's server), asset and audio permissions under the group, Studio API access settings, removing beta switches and PREVIEW tags, a real multi-day playtest with kids, and the publishing evaluation path for new games (check the current rule; do not repeat `07_RESEARCH_AND_POLICY.md` as if it were current).

**K-02 Store assets (MUST).** A 512x512 icon and three 1920x1080 thumbnails captured from the real game in Studio (Raceway at level 12 with cars, a mid-Hop moment in Downtown, the Garage with editions), composed and lettered in the game's style; ChatGPT's `R6-IMG-07` is direction only. Honest: every thumbnail shows something a player really sees. A draft description (under 1,000 characters, plain, no all-caps hype, no promises of rewards) in `review\round6\release\`.

**K-03 Maturity questionnaire draft (SHOULD).** Your best draft answers with a reason per answer, for Adam to submit himself.

## 9. Module N: notes, tests and leftovers (MUST for N-01 and N-02)

**N-01 Adam's phone notes (MUST if the file exists).** Each line of `PHONE-NOTES.md` is fixed or answered in the ledger.

**N-02 Tests (MUST).** The two-client suite and the rejoin suite on `integration/beta-4` with everything above in; the six-client suite with Chrome and other windows closed (SHOULD reach 6).

**N-03 Videos (SHOULD).** Four short real-time clips with game audio if R6-S04 allows (Raceway level-up, parking tier reveal, a mission claim, a Studio test purchase), loudness measured with one stated method; otherwise silent and labelled.

**N-04 Performance (SHOULD).** Re-run the Round 5 baseline (parts, flicker scan, server frame with six clients) after V-01 and V-02 and record the change.

## 10. Module H: handoffs (MUST)

- **H-01** Commit `economy-preview-review-for-brian-l.md` from this folder to `vault/design/specs/` exactly as written (it is Adam's message). Before committing, if Brian L has already answered any point in a vault file, add a one-line note at the top saying which.
- **H-02** Commit `lane3-round6-for-brian-r.md` to `vault/design/specs/`. First update its first section ("What happened with your driving update") so it matches what today's driving session really did (merged, published or not); change nothing else.
- **H-03** `robux-fields-for-brian-l.md` (R-06) and the Missions field proposal (G-02).
- **H-04** Board lines under Up next for each message, decision 0040, the log entry.

## 11. Module F: finish (MUST)

- **F-01** `./scripts/check.ps1` exit 0 on `feature/lane3-round6` and `integration/beta-4`.
- **F-02** Push both branches; open a pull request for `feature/lane3-round6` to `main` and keep `integration/beta-4`'s draft PR current. Then run section 0 item 1 (a)'s sweep again so nothing on the laptop is left unpushed, and update the branch table.
- **F-03** Merge `feature/lane3-round6` into `main` only if every MUST passed (Adam requests this merge under that condition); otherwise leave it as a draft and say why.
- **F-04** Publish per section 0 item 12, then join the published place once as a check (portal, run, claim, park, a price button shows "Coming soon"), and record the place version.
- **F-05** Write `review\round6\RESULT.md`: the MUST table, what changed per module, your calls, open items with the next action for each, and a ten-item Studio walk-through for Adam in loop order (plain words, where each button is). Give the MUST table and the walk-through in your final message too.

## 12. Not in this round (visible, not forgotten)

Real sales on (after Brian L's server owns grants), public publish, Brian L's real server replacing the stand-ins, Brian R wiring Brian L's remotes, cross-server leaderboards, trading, the Rider Level gate (Deferred), HOP STREAK, decorations, live race lobbies, Galaxy look approval (Brian L), a real multi-day playtest with kids.
