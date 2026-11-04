# Catch A Car!: Lane 3 Round 4 (economy decisions in every Lane 3 screen, Round 3 and Launch Pad close-out, two-player test)

**For:** Claude Code, on Adam's Windows laptop, repository `Roblox-Game-1`.
**From:** Adam (repository owner, Lane 3 owner), written with Claude (claude.ai) on 2026-11-02. Lines marked **[ChatGPT]** were added by ChatGPT.
**Task folder (outside Git):** `C:\Users\agert\Documents\Car-Hop-Art\review\round4\`
**Builds on:** Round 3 (`review\round3\BRIEF-ROUND3.md`, `review\round3\RESULT.md`, decision 0033), the Launch Pads (`review\hubs\BRIEF-HUBS.md`, `review\hubs\RESULT.md`, decision 0035), real cars on Lane 3 screens (decision 0034). PR #8 was merged into `main` on 2026-11-02 at 20:50, so this round starts from `main`.

The earlier rounds' rules still apply: Round 1 brief sections 2, 2.2, 2.3, 3, 5, 19 to 21; Round 2 section 1.1 and the same-view checks; Round 3 section 2 (your freedom) and 2.1 (the "AI look").

---

## 0. What Adam decided today (2026-11-02, 22:40, his words, lightly cleaned)

These answer the open items in Brian L's economy proposal (`vault/design/specs/economy-v1.md` on branch `feature/lane2-economy-design`, sections 11 to 13).

> "As for the car list, you can use Brian's showroom for 25 cars and 5 rarities, and just split that up between the 3 worlds using your best judgment."

> "For the Rider level gate, I want you to just use your own best recommendation and go ahead with that."

> "For how the big numbers display, how you put it there is accurate. You could use the abbreviations."

> "The proposed save fields, we all agree to them."

> "No, we definitely are going to have the 19 Robux respawn, and we're going to have all the Robux purchases. That's non-negotiable."

How Claude (claude.ai) turned these into decisions, with Adam's delegation:

1. **Car list: Brian L's showroom, five rarities, split 9 per World.** Adam said 25 cars. The showroom actually has **27 built cars** in `assets/cars/` (29 planned; Polytruck and Sparkster are not built yet). All 27 are used, because 27 splits evenly into 9 per World and every built car gets a home. The split is in section 4, table E-03. If Adam meant to drop two cars, that's a one-line change in the fixture.
2. **Rider Level gate: not at launch.** Recommendation, decided under Adam's delegation. Reasons:
   - The game already has three things that hold a player back: World unlocks (Cash plus cars from the World before), longer Keys times for rarer cars, and the 5-bolt Stamina limit per run (decision 0035).
   - A fourth gate is a wall for young players.
   - Brian R's version (you can ride, but the Keys never fill and Heat rises 1.6x faster) breaks the "readable danger" pillar. A child can't tell why the Keys stopped.
   - It would need a new saved stat, prices and UI.

   It stays on the Deferred list, so it isn't lost. Stamina remains the per-run limit.
3. **Big numbers: the existing Lane 3 rule, plus "Qa".** `src/shared/UI/Format.luau` already does this:
   - Exact dollars below $10,000.
   - From $10,000: at most three significant digits with K, M, B or T, truncated and never rounded up ("$12.4K", "$1.2M", "$3.45B").

   Brian L's economy reaches trillions ($2T for Raceway level 12) and billions a minute, so add **Qa** (quadrillion) above T.
4. **Save fields: Agreed by all three lanes** (relayed by Adam on 2026-11-02): `Cash`, `Cars { [carId]: { Edition, Copies } }`, `Lineup`, `RacewayLevel`, `ParkingSpots`, `WorldsUnlocked`, `LastSeen`, exactly as in economy v1 section 13. The four remotes (`BuyRacewayLevel`, `BuyParkingSpot`, `SetLineupSlot`, `UnlockWorld`) are part of that contract.
5. **Robux: the 19 Robux respawn and every planned Robux purchase are decided and in the launch scope.** This overrules Brian L's recommendation in economy v1 section 11. It also overrules the older outline lines "No Developer Products (Cash packs) at launch" and "Paid passes never change Heat, Keys or race performance" as far as the respawn goes. Adam was told on 2026-11-02 that the respawn helps a run, and he kept it. Do not argue it again; record it.
   - Brian L's rule that **cars and editions are never sold for Robux** still stands. Adam did not change it.
   - Everything stays **PREVIEW with "Coming soon"** in Lane 3 until Brian L's server grants exist. A real sale needs his server-checked grant.

## 1. Your freedom and the hard lines

Same as Round 3: think like the lead designer. Research, try options, keep the best, invent small touches that help kids enjoy the game, record choices in the ledger and the decision note, and **don't stop to ask Adam**. Use your own judgment and self-review. **No review web pages**: when you're done, say so in a short message and Adam walks through Studio himself.

Hard lines:
- **No edits to Brian R's or Brian L's files.** That means `src/client/Run`, `src/shared/Run`, `src/server` (except the existing beta glue in `src/server/Beta`, which is Adam's integration code), `src/shared/Catalog`, `src/shared/Net`, `assets/cars`, and their branches.
- **No new saved data** outside the Agreed save fields. The beta's stand-in save may use those agreed fields only.
- **PREVIEW prices and "Coming soon" for every Robux item.** No real `MarketplaceService` prompts in this round.
- **No publishing.** No Team Create place.
- **Original art, no brands or real logos. No Roblox studs.**
- **No destructive Git.** No force-push. Never rewrite a teammate's text in the vault.
- **Never send keystrokes or clicks outside the Studio window, and never capture the whole desktop.** Last round, keystrokes meant for a Save As window landed in Adam's browser. Check which window has focus before every keyboard action; if it isn't Studio, stop typing and use another route.

## 2. Setup

**R4-S01 Read first:**
- `AGENTS.md`
- `vault/tasks/BOARD.md`
- the newest log entries
- decisions 0033, 0034 and 0035
- `review\round3\RESULT.md` and `review\hubs\RESULT.md`
- both ledgers (`vault/design/specs/lane3-round3-ledger.md`, `lane3-launchpads-ledger.md`)
- Brian L's `economy-v1.md` (read it from his branch with `git show origin/feature/lane2-economy-design:vault/design/specs/economy-v1.md`; do not check that branch out for editing)
- the showroom roster (`git show origin/feature/lane2-ev-roster:vault/design/cars/showroom-roster.md`)
- every `## Replies` section in `vault/design/specs/*-for-brian-*.md`, in case a teammate answered

**R4-S02 Branch:**
- Use the worktree `C:\Users\agert\Documents\Roblox-Game-1-biground`. Pull `main` there and create **`feature/lane3-round4`** from the latest `origin/main`.
- Keep **`integration/beta-2`** (worktree `Roblox-Game-1-beta2`, draft PR #9) current by merging the feature branch into it after each module.
- If `rokit.toml` or `wally.lock` changed in the pull, run `rokit install` and `wally install`.

**R4-S03 Claim:** add a board row "Lane 3: Round 4 (economy decisions in Lane 3 screens, Round 3 and Launch Pad close-out, two-player test) - Adam, with Claude Code, 2026-11-0X" naming the branch and this brief. Commit and push only that board change to `main`.

**R4-S04 Records:**
- Copy this brief to `vault/design/specs/lane3-round4.md`.
- Create `vault/design/specs/lane3-round4-ledger.md` with one row per requirement ID in this brief (ID, what, status, evidence, notes). Update it after every module.
- Reserve **0036** in `Car-Hop-Art\DECISION_NUMBERS.txt` (0035 is the last used) for `vault/decisions/0036-lane3-round4.md`. If 0036 is already taken, use the next free number and say so.

**R4-S05 Places:** dated backups before overwriting any place file.
- `Car-Hop-Art\CarHop-Beta-2-local.rbxl` is the **main place for this round**: every final check and the two-player test.
- `Car-Hop-Art\CarHop-BigRound-HUD.rbxl` is for fast UI iteration only.
- The private island test place is for island-only flicker fixes.
- **Save the beta yourself at the end of every module.** Use the Studio MCP if it can save; otherwise use Ctrl+S, only when Studio has focus. Last round's beta needed Adam's Ctrl+S because the island was built in the open window and never saved. Don't leave that to him this time. Check the file's LastWriteTime changed.

**R4-S06 Rojo:** `rojo serve beta.project.json` for the beta, and the usual project file for the HUD place. Never connect Rojo to the Team Create place.

**R4-S07 Figma:** for the new UI pieces (E-06 edition ladder, C-06 loading progress, C-03 full-parking state), use Figma first if the free plan still has usage left; otherwise design straight in Studio and say which you did.

**R4-S08 References:** ChatGPT's images for this round are in `review\round4\chatgpt-images\` (`R4-IMG-01` to `R4-IMG-05`, plus `GENERATION-NOTES.md`). They show direction, not exact pixels. Match the game's existing style first (the Garage Index in `review\real-cars\phone-garage.jpg`, the Shop in `review\round3\evidence\shop-desktop-final.jpg`). If an image is missing, work from its text in `review\round4\CHATGPT-R4.md`.

### [ChatGPT] R4-S09 Execution and evidence rules
[ChatGPT] Research checked 2026-11-03. The notes below clarify implementation. Section 0 and section 1 remain unchanged. Mockups are references, not evidence that anything works.
[ChatGPT] Use one lead. Use at most two Sonnet reviewers concurrently for C-05. Give reviewers bounded screenshot sets, not the full repository. No agent-created agent trees. Keep C-05's fresh-review requirement and three-round limit. Do other work yourself unless a specific independent task justifies help.
[ChatGPT] Work without mid-task questions. Record blockers and finish independent items. Do not invent approvals, asset IDs, test results, or missing economy values. End with one consolidated report.
[ChatGPT] Check current worktree status and active Studio ownership before changing branches or connecting Rojo. Never disturb another session's checkout. Confirm the beta project file exists in the worktree that serves the beta. Do not copy an obsolete mapping from the HUD worktree.
[ChatGPT] R4-S03's main-only board commit is a separate docs operation. Do not mix it into the feature checkout or accidentally commit unrelated changes. Preserve teammate edits and identify the actual branch and commit in the ledger.
[ChatGPT] Use the established desktop, tablet and phone-landscape test presets. Record actual viewport pixels, inset settings, commit, place file and fixture state. A smaller desktop window is a layout test, not measured phone performance.
[ChatGPT] Read GENERATION-NOTES.md before implementing the images. Preserve Garage's existing responsive detail-page behavior, CLAIM ALL, collection reward footer and approved navigation. The mockup does not authorize removing them. Do not recreate generated top-bar icons as Roblox CoreGui.


### [ChatGPT] R4-NAME Official title update approved by Adam, 2026-11-03
[ChatGPT] The official game name is **Catch A Car!**, including the exclamation mark. All-uppercase logo lettering is **CATCH A CAR!**. This supersedes the former working title Car Hop wherever it is player-facing. Section 0's gameplay, economy and purchase decisions remain unchanged.
[ChatGPT] During this build audit title screens, loading screen text or baked logo images, Launch Pad title signs, hub signage and player-facing tutorial or menu branding. Update the display title in Lane 3 paths. Preserve other labels such as Garage Index, Raceway and the Hop action.
[ChatGPT] The current R4-IMG-01 and R4-IMG-03 reference files now show the new name. The other three images contain no former game title. Older references are historical style guidance; never copy their old title back into a new asset.
[ChatGPT] Read vault/decisions/0037-official-name-catch-a-car.md. Keep paths such as Car-Hop-Art, CarHop-Beta-2-local.rbxl and existing repository names unchanged. Do not change save-store names, remote identifiers, model paths or game IDs. Do not rename or publish the live Roblox experience in this round.
[ChatGPT] Done when a player-facing title-string search is reviewed, title-bearing screens and signs show Catch A Car! at phone and desktop sizes, and no old baked title remains in newly used artwork. Historical filenames and source comments are not failures.
**Order of work:** E (economy decisions) → C (close-out) → M (two-player test, last, so it tests everything) → F (finish).

---

## 3. Module E: put Adam's economy decisions into every Lane 3 screen

Everything here is **display**. Real Cash, ownership and purchases come from Brian L's server later. Every number from economy v1 is Brian L's proposal and keeps a **PREVIEW** tag until his server supplies it. Keep each value in one fixture module so his real data can replace it in one place.

**E-01 Decision note `vault/decisions/0036-lane3-round4.md`.** Record:
- Each of section 0's five decisions, with Adam's words, the date, and "decided by Adam (repository owner); items 1 to 3 delegated to Claude and chosen as written".
- The 27-car split (E-03).
- The outline lines that the Robux decision overrules.
- Where each change shows up in Lane 3.
- What would justify revisiting each one (for the Rider Level gate: playtests where skilled players claim every car in one run even with 5 bolts).

**E-02 Answers for Brian L, on `main` (docs only).**
- Create `vault/design/specs/economy-v1-answers-from-adam.md` with:
  - Adam's answer to each item in economy v1 sections 11, 12 and 13, in the same order, with the 27-car split table
  - the Robux product list (E-10)
  - the Expanded Paddock question (C-03)
  - the "Qa" display rule (E-07)
  - a `## Replies` section with a "Brian L" heading
- Add one line under "Up next" on the board pointing Brian L to it.
- **Do not commit to his branch or edit `economy-v1.md`.**
- Write it as plain answers. Don't add persuasion or re-argue the Robux decision.

**E-03 The roster, by World.** All 27 built cars, 9 per World, with the same rarity shape in each World: 2 Common, 2 Uncommon, 3 between Rare and Epic, 2 Legendary. The first car in each World is its **Loaner**, the starting car for that World.

| World | Common | Uncommon | Rare | Epic | Legendary |
|---|---|---|---|---|---|
| **Downtown** (city) | **Putter** (Loaner), Pizza Runner | Minnow, Surf Wagon | Bolt, Brawler | Executive | Street Kid, Cruiser |
| **Dusty Highway** (desert) | **Rustbucket** (Loaner), Old Faithful | Beach Bug, Workhorse | Thunder | Desert King, Night Rider | Viper Strike, Apex |
| **Summit Pass** (mountains) | **Commuter** (Loaner), Family Hauler | Trailblazer, Sunny Camper | Rally Dog | Monarch, Velvet | Zip, Phantom |

Why these placements:
- City cars, delivery and luxury go Downtown.
- Junkers, the dune buggy, muscle cars, the desert truck and the speed-record hypercar go to the desert.
- Family, ski, rally and 4x4 cars go to the mountains.
- The two yellow and purple wedge supercars are split up, so no World has two look-alike Legendaries.
- Each World's Legendary pair contrasts with its scenery: blue and purple in the city, green and silver in the desert, yellow and dark grey on the snow.

When they're built, **Sparkster** (Epic, electric roadster) goes to Downtown and **Polytruck** (Rare, electric pickup) goes to Dusty Highway, giving 10, 10 and 9. Brian L can change any placement; his Catalog wins.

Adam chose a Fiat 500 parody as the Downtown starter (2026-10-21). **Look at Putter and Rustbucket in Studio.** Whichever reads more like a classic tiny Italian city car is the Downtown Loaner, and the other one takes the other slot. Record which and why.

**[ChatGPT] E-03a Fixed-roster clarification.**
[ChatGPT note] The starter-swap paragraph conflicts with Adam's instruction to preserve the E-03 split. For this round keep Putter in Downtown, Rustbucket in Dusty Highway and Commuter in Summit Pass. Inspect their appearance, but report any mismatch to Brian L without swapping them. The tutorial uses Putter. A future Catalog disagreement needs an explicit mapping and a recorded reconciliation, not a silent reassignment.
[ChatGPT] Validate exactly 27 unique base IDs, nine per World, one Loaner per World, and the exact names and rarities in E-03. Editions do not increase the base-car count. Do not create Sparkster or Polytruck cards yet. Match model IDs to the live showroom roster instead of generating IDs from display names.
[ChatGPT] Decision 0034 records pivot and saved-scale differences. Reuse its display-copy correction through RealCar. Do not alter source car files. Check all 27 thumbnails for grounded wheels, consistent apparent scale, complete silhouettes and no cropped roofs or spoilers.

**E-04 One roster fixture for every Lane 3 screen.**
- Find where Lane 3 screens get their car list today: the real-cars work from decision 0034 (`RealCar.luau` and the Car stall), and the old fixtures that still show **PROXY** cars and invented names like "Puglet", "Fishbowl Express" and "Citrine Waffle Van" in the Garage Index (`review\real-cars\phone-garage.jpg`).
- Make **one** Lane 3 fixture (for example `src/client/UI/Prototype/SupportFixtures/RosterFixtures.luau`) holding, per car: id, display name, rarity (5 tiers), World, Loaner flag, and the model name in `ReplicatedStorage.Cars`.
- Its header names it a stand-in for Brian L's Catalog.
- Every Lane 3 screen reads from it. No screen keeps its own list.

**E-05 Every screen shows the real 27 cars, in the right World.** Go screen by screen and record each in the ledger with a still:
- **Garage Index:**
  - World tabs show 9 cars each, with real showroom models instead of PROXY cars and the real names.
  - The progress line reads "Downtown: 6 / 9".
  - The header count becomes "Unlocked N / 27".
  - Unowned cars stay dark silhouettes with "???" and the rarity badge visible.
  - Sorting (Rarest, Lap Pay, Newest) still works.
  - Keep the layout and style exactly as approved ("Garage/Index restyle kept as is"); only the data and car images change.
- **Card detail:** World, rarity, Lap Pay (economy v1 numbers, E-08), the edition ladder (E-06), and PUT ON RACEWAY.
- **Portals and their lock signs:** World 2 needs "5 / 5 Downtown cars" plus the Cash; World 3 needs "5 / 5 Dusty Highway cars" plus the Cash. Use economy v1's $5M and $1B. The Peek view shows that World's 9 silhouettes.
- **Launch Pad CARS kiosk, turntable and Start-in picker:** only that World's cars. The Loaner is always available. Owned cars are listed first.
- **Launch card, Car stall, Style or Customize car picker, Results claimed cards, and Raceway Lineup picker:** real names and models.
- **Tutorial:** the first claim target and the first parked car are the Downtown Loaner, Putter (or Rustbucket, per E-03).
- **Missions and goals** that name a car or a World use the real names (MissionFixtures).
- **Run nameplates** (Lane 3's `World/Nameplates.luau`, if they show a fixture name): real names and the five rarity colors.

**E-06 The edition ladder (display of the Agreed `Cars` field).**
- Economy v1 section 4 has five editions: **Normal x1, Gold x3, Diamond x10, Rainbow x50, Galaxy x250**. Every **25 copies** at one edition merge into the next.
- The Garage cards already show five small dots under each name. Make sure they mean editions, in order, and are labelled in the card detail.
- In the card detail, show:
  - a horizontal ladder of five edition badges, reached ones lit and the next one outlined
  - a progress bar "12 / 25 copies to GOLD"
  - one plain line saying how copies are earned: "Fill the Keys on this car again to get a copy."
  - the Lap Pay multiplier of the best edition reached
- Use the PREVIEW numbers.
- Galaxy's look is Brian L's to approve. Use a placeholder Galaxy badge (deep purple with small stars) and label it PREVIEW.
- No "buy" button anywhere near editions: editions are never sold.
- Reference: `R4-IMG-01` and `R4-IMG-02`.

**[ChatGPT] E-06a Edition states and layout.**
[ChatGPT] Use the existing fonts and tokens. Keep rarity and edition as separate facts: Executive stays Epic whether its edition is Normal or Gold. Give every edition a text label and state indicator, not color alone. Avoid the Stamina bolt as the final edition symbol.
[ChatGPT] Test Normal with 0 copies, one copy short of a merge, a merge boundary, Gold progressing toward Diamond, unowned car, and highest edition. Read the meaning of Copies from economy v1 before displaying progress. Never interpret total lifetime copies as current-tier remainder without evidence. Missing semantics are a Lane 2 question, not a new save field.
[ChatGPT] At Galaxy, show the reached state without inventing another tier or a misleading 0/25 bar. Galaxy art remains PREVIEW. Earned editions must not resemble purchasable offers.
[ChatGPT] The image's Executive $6,000/lap is an illustrative Gold calculation from $2,000 base times x3 before any other multiplier. Runtime text must use the same fixture formula as all other screens. Do not hard-code the mockup value. Verify which Raceway multiplier applies.
[ChatGPT] Done when the five names, selected edition, next target and copy count are readable at actual phone size, with no overlap with PUT ON RACEWAY. Preserve the phone's existing detail page and Back action instead of shrinking five unreadable labels into the desktop composition.

**E-07 Big numbers.**
1. Add **Qa** above T in `src/shared/UI/Format.luau`, keeping the truncate-never-round-up contract.
2. Values at or above 1,000 Qa show whole Qa with commas. The economy caps far below Roblox's exact-integer limit (about 9 quadrillion), so this should never be reached.
3. Add tests for the boundaries:
   - $9,999
   - $10,000
   - $999,999 ("$999K")
   - $1,000,000
   - $999,999,999,999 ("$999B")
   - $1T
   - $2T
   - $999.99T
   - $1Qa
   - NaN and negative values
4. **Audit every place a money or count number is drawn** (search for `Format.` and also for `tostring(` and `string.format` near Cash, Lap Pay, prices and counts). Make every one use `Format`:
   - HUD Cash
   - Shop prices and struck-through prices
   - Raceway stats board and level prices
   - parking prices
   - portal requirements
   - Results count-up
   - Welcome back
   - Missions rewards
   - Garage Lap Pay
   - floating Lap Pay pops
5. Affordability checks always compare the real numbers, never the text.
6. Count-up animations always end on the exact value given.

**[ChatGPT] E-07a Boundary checks and precision note.**
[ChatGPT] Expected Cash strings include $9,999; $10K; $999K for 999,999; $1M; $999B for 999,999,999,999; $1T; $2T; $999T for 999.99T; and $1Qa. Test either side of every suffix boundary and $1.23Qa. Keep the existing sanitization of invalid or negative amounts. Counts, distance and Robux are separate formats, not dollar amounts.
[ChatGPT note] 1,000 Qa is above the exact-integer range of a Luau number. A prettier formatter cannot restore lost precision. Preserve the requested whole-Qa display fallback, but do not claim exact accounting at that magnitude or invent an economy cap. Confirm the actual cap with Brian L. This round changes presentation, not the agreed storage schema.
[ChatGPT] Audit ShopMock's local money helper, which currently groups full dollars, as well as calls to Format. Capture the largest fixture values in the Shop, parking, Garage, HUD and Results. For count-up, verify the final numeric source and its formatted text match the source value without upward rounding.

**E-08 Economy v1 numbers in the PREVIEW fixtures.** Replace the outline-era numbers with economy v1's, all still PREVIEW:
- Lap Pay per rarity: $10, $50, $250, $2,000, $25,000.
- New-claim bonus and Joyride Bonus per rarity.
- The 12 Raceway level prices and multipliers (the shopkeeper's stats board and the upgrade panel).
- Parking spot prices for spots 3 to 15.
- World unlock Cash.
- Road coin and Milestone values per World.
- Welcome back: 50% of the normal rate, 8-hour cap.

Check the numbers stay readable at their biggest. Raceway level 12 costs $2T and a level-12 Lap Pay pop can be in the millions; nothing may overflow its box at phone size. Brian L can change any value; that's one fixture edit.

**E-09 Rider Level gate: not at launch.**
- Search Lane 3 code and fixtures for any "Needs N", "Rider Level" or requirement readout. Remove it from Lane 3 screens, or leave it switched off with a comment pointing to 0036.
- Stamina (5 bolts, 1 per hop, 2 back on respawn, 8 in the tutorial run) is unchanged.
- Add "Rider Level gate" to the board's Deferred list with the revisit condition from E-01.

**E-10 Robux: every planned Robux item, consistent everywhere.**
- List every Robux item Lane 3 shows today. At least these:
  - the **19 Robux respawn** (after the free revives)
  - **Robux Cash packs** that scale with the player's Raceway earnings, with current Cash as the floor
  - **flashy Robux trails** (cheap trails stay Cash)
  - the passes **Double Lap Pay**, **Expanded Paddock** and **VIP**
  - anything else in the Shop fixtures
- For each, check one source of truth: name, PREVIEW Robux price, what it does in one kid-readable line, where it's sold, and "Coming soon" on press.
- Fix any screen that disagrees with another. Remove any text that calls the respawn "proposed" or "under review"; it's decided (keep the PREVIEW price tag).
- Put the list in the E-02 answers file as **"Robux products for Lane 2 to build"**, with this recommendation for Brian L to verify against the current official Roblox docs (don't state anything as fact without checking):
  - Consumables (respawn, Cash packs) are Developer Products, granted on the server in `MarketplaceService.ProcessReceipt`. Make the grant safe to repeat: record the purchase id so a retried receipt never grants twice.
  - Permanent items (passes, Robux trails) are Game Passes, or Developer Products with saved ownership. Check ownership on the server when the player joins and after a purchase.
  - Check per-player purchase restrictions with `PolicyService` before showing a purchase prompt, and show a clear "not available" state when they apply.
  - Nothing involves paid randomness.
- Never call the respawn "free" or "no advantage"; describe it honestly as "Keep your run going".

**[ChatGPT] E-10a Official purchase checklist for Brian L, not Lane 3 implementation.**
[ChatGPT] Repeatable respawns and Cash packs fit Developer Products. Grant them through the server receipt handler, never from PromptProductPurchaseFinished or a client success callback. Roblox's developer-product guide requires receipt processing. [Developer Products](https://create.roblox.com/docs/production/monetization/developer-products).
[ChatGPT] Permanent privileges fit passes. Verify ownership on the server with UserOwnsGamePassAsync and handle failures; do not trust a local Owned label. Resolve already-owned and duplicate-purchase cases. [Passes](https://create.roblox.com/docs/production/monetization/passes).
[ChatGPT] ProcessReceipt must handle retries, unavailable players and duplicate receipts. Return PurchaseGranted only after durable fulfillment, otherwise NotProcessedYet. Use PurchaseId as the deduplication identity. Current API reference lists GetProductInfoAsync; GetProductInfo is deprecated even though older guide examples still use it. Verify installed engine support. [MarketplaceService API](https://create.roblox.com/docs/reference/engine/classes/MarketplaceService).
[ChatGPT note] A durable receipt ledger or purchased-trail entitlement may need fields beyond the agreed list. Brian L must resolve that contract before real sales. Do not add receipt fields to the Lane 3 beta or hide them inside Cars.
[ChatGPT] Brian L needs a recoverable policy for a paid revive receipt arriving after timeout, disconnection or a later run. Never consume the payment without delivering the promised value. Keep the 19 Robux decision. Define late fulfillment before enabling sales; this round demonstrates only the preview.
[ChatGPT] PolicyService:GetPolicyInfoForPlayerAsync is not a universal CanBuyRobuxItems check. ArePaidRandomItemsRestricted concerns paid randomness; IsEligibleToPurchaseCommerceProduct concerns commerce products. Apply only relevant returned policies and handle lookup errors. Do not treat either field as a blanket pass/respawn permission. [PolicyService](https://create.roblox.com/docs/reference/engine/classes/PolicyService).
[ChatGPT] Current regional-pricing guidance requires dynamic displayed prices when managed pricing applies. Preserve 19 as this brief's approved preview/default price. Brian L must align eventual product settings and the displayed player-specific price with the purchase prompt. Never invent a discount. [Regional pricing](https://create.roblox.com/docs/production/monetization/regional-pricing).
[ChatGPT] Roblox has parental spending controls. Do not try to bypass a platform refusal or repeatedly reopen a dismissed purchase prompt. These controls are not proof that every in-game purchase is allowed or blocked. [Parental Controls Overview](https://en.help.roblox.com/hc/en-us/articles/30428310121620-Parental-Controls-Overview).
[ChatGPT] Project recommendation for young players: show price and benefit together, a clear close/decline action, truthful savings and no fake scarcity. Do not sell cars or editions through a bundle illustration. Starter-pack art must not imply an included car if the pack contains only Cash or cosmetics.
[ChatGPT] Keep paid randomness out of these offers. Roblox's rules also cover indirect paid randomness through currency bought with Robux, not just direct Robux rolls. Do not add a random trail or paid-Cash mystery reward. [Paid random items policy](https://create.roblox.com/docs/production/monetization/paid-random-items).
[ChatGPT] Lane 3 acceptance: each offer has one fixture identity, price, benefit and destination. Every price press ends in Coming soon, with no Marketplace prompt, entitlement change or real charge. Capture free-revive and 19-Robux preview states separately. The five-second ring must reflect a real offer window, not a looping urgency effect. Keep No thanks usable throughout. A future real purchase flow must suspend expiry while its platform prompt is pending.

**E-11 Done when:**
- No PROXY car or invented car name appears on any Lane 3 screen in the beta.
- Every screen in E-05 has a still at desktop, tablet and phone landscape.
- The Format tests pass.
- The answers file is on `main`.
- Decision 0036 is written.

---

## 4. Module C: close out Round 3 and the Launch Pads

Each item below was left partial or untested last round. Do each one fully, or say exactly what stopped it.

**C-01 Flicker scan of the whole game, re-run.** Round 3's flicker scan wasn't re-run after the portal path change, and Round 2's scenario checks weren't re-run either.
- Re-run the overlap or flicker scan (the OverlapScan tool from the Launch Pad round) over:
  - the island
  - the Raceway at all 12 levels
  - Downtown, Dusty Highway and Summit Pass (several seeds each)
  - the three Launch Pads, the portals, the Garage, the Stunt Circuit gate
  - PIT ROW and every other building Adam named on 2026-11-01
- Fix every flicker in Lane 3's paths. Coplanar faces: offset or delete the hidden one. Overlapping parts: merge or trim. Don't hide them with transparency.
- Then re-run Round 2's scenario checks, and update their expectations only where a screen was deliberately rebuilt (say which).
- **Done when:** 0 flicker findings everywhere, with before and after frames for every fix. If a finding is inside a teammate's model, list it for them.

**[ChatGPT] C-01a Reproducible flicker evidence.**
[ChatGPT] Use at least three recorded seeds per World as a starting sample. Inspect the same arrival, chase and orbit views before and after each fix. Separate an overlap detector candidate from a visible defect. A legitimate contact or bounding-box overlap is not automatically z-fighting.
[ChatGPT] Keep an explicit disposition for every candidate: fixed, intentional with evidence, or teammate-owned. Report zero unresolved visible Lane 3 flicker defects across the tested views. Do not claim all possible seeds are clear from this sample.

**C-02 A real claim in a real run, in every World.** Round 3 reached "Hold on!" but never "It's yours!" in a test run. Tests also crashed at about 50 m because nobody was steering.
- Build a **beta-only test driver** in Lane 3's beta glue (not in Brian R's files). It steers to keep the Hop target in front and taps Hop when the ring is steady, using only the inputs a player has, so it tests the real flow.
- Use it to reach the full capture sequence in each World: landing → Keys ring → "Hold on!" → "It's yours!" banner with keys and confetti → card → claimed tray → Results claimed card → the car appears in the Garage (beta stand-in save).
- If the driver can't avoid the crash at about 50 m, find out why (traffic speed, camera, or no steering in the first run) and write the cause and a proposed fix in Brian R's message instead of changing his code.
- **Done when:** "It's yours!" is captured in all three Worlds, the claimed car shows on Results and in the Garage, and Output has no new errors. If a World can't reach it, show where it stops and why.

**[ChatGPT] C-02a A bounded input-only driver.**
[ChatGPT] First inspect the actual player bindings and Hop behavior. A key name or timing from an old brief is not reliable. Prefer Studio MCP's client-targeted user_keyboard_input and user_mouse_input where available. The inspected tool schema supports keyDown, keyUp, keyPress and waits, targeting a specific Studio ID and Client data model.
[ChatGPT] Keep the test controller outside production gameplay. Use short steer pulses, release them, observe the real target/ring state, then issue the actual Hop input. Start with 50-150 ms pulses and tune to the existing control response. If hopping requires a hold/release, reproduce that binding. Release all held inputs on timeout, run end and tool failure.
[ChatGPT] A beta observer may record visible HUD state and timestamps. It must not call capture helpers, fire reward remotes, set Keys to full, teleport onto a car, alter speed, disable collisions or write the claimed car into inventory. Those would bypass the test.
[ChatGPT] An ordinary in-game LocalScript has no assumed supported OS-key injection API. Do not add executor APIs or VirtualInputManager workarounds. If available tools cannot drive the genuine input path, record the limitation and retain a short manual recipe.
[ChatGPT] Allow a small bounded tuning pass, initially three attempts per World. Log World, seed, bindings, target car, distance, input times and failure stage. If the same early crash repeats, investigate and hand off instead of spending the session in a retry loop.
[ChatGPT] Done means one continuous, unforced sequence per World from landing to Garage ownership, with matching base-car ID in the banner, Results and beta stand-in. Capture video if available. A forced fixture screenshot can validate layout only and must be labelled as such.

**C-03 "Get more spots", pressed for real, plus the full-parking state.**
- In the beta, buy parking spots (free PREVIEW purchases) up to the maximum, 15.
- Check the panel at 2, 3, 14 and 15 spots: price shown, can afford, can't afford, and the maximum.
- At 15, "Get more spots" must appear and open the Shop on **Expanded Paddock**. Press it by hand in Play and capture each step.
- Design the full state so it reads as an achievement ("Raceway full! 15 / 15"), not as a dead end, then offers the pass. Reference: `R4-IMG-04`.
- **The open question for Brian L:** economy v1 says the maximum is 15. The outline's Expanded Paddock adds 3 spots above the maximum. Recommendation: **the pass raises the maximum from 15 to 18**, because a pass that adds nothing at the maximum would be a broken purchase.
  - Show it that way in the PREVIEW ("+3 spots: up to 18").
  - Put the question and the recommendation in the E-02 answers file.
  - Make the number one fixture value.
- **Done when:** frames show 2, 14 and 15 spots, the button press, and the Shop opening on the pass, at phone landscape and desktop.

**[ChatGPT] C-03a Capacity is not occupancy.**
[ChatGPT] Distinguish purchased slots from cars parked. The 15/15 capacity achievement can trigger when 15 bays are owned, but only fill a bay's car icon if the corresponding Lineup slot contains a car. The reference image illustrates the fully occupied case; never invent 15 parked cars.
[ChatGPT] Test 2, 3, 14 and 15 owned slots with both sparse and full Lineups. At the cap, hide the invalid next-spot price and ordinary buy action. GET MORE SPOTS opens Shop through its existing openExpandedPaddock route, with that pass fully visible.
[ChatGPT] Close Shop and return to the expected parking context without duplicate overlays. Repeated taps open one Shop. Pressing the pass shows Coming soon and does not grant three slots. The 18-slot value remains the explicit PREVIEW recommendation pending Brian L.
[ChatGPT] Reuse the parking panel in src/client/Home/Island/Speedway/ShopPanel.luau. It is not in Prototype/Screens. Respect its single-flight press behavior and preview adapter.

**C-04 Settings, looked at in Studio.** The Replay Tutorial button was fixed in code but never seen.
- Open Settings in Play at desktop, tablet and phone landscape.
- Check that Replay Tutorial is centered in its top bar and that every row (MUSIC and SOUND EFFECTS sliders and mutes, Haptics, Replay Tutorial, anything else) shares one left edge, one row height and even gaps.
- Press each control once.
- **Done when:** three frames show the panel aligned, and each control was pressed with no error.

**[ChatGPT] C-04a Interaction evidence.**
[ChatGPT] Check slider minimum, midpoint and maximum, mute then unmute, close then reopen, and Replay Tutorial during a safe hub state. Confirm each row's clickable region matches its visible control. Distinguish a mute icon changing from audible output changing. No cross-session setting persistence is claimed without the agreed backend.
[ChatGPT] At all three sizes, require no clipped label, no hidden action and no panel extending behind reserved Roblox controls. Record any existing phone-specific layout rather than forcing desktop proportions.

**C-05 The Shop reaches 4 out of 5, judged fresh.** The Shop scored 3 to 4 on the "AI look" check and 2 to 3 against the reference shop. The target is 4 and 4 at all three sizes. Adam: "The whole point of the game is monetization, so the shop needs to be absolutely perfect."
1. Capture every Shop tab at desktop, tablet and phone landscape, in Play, with the real cars from E-05.
2. Run **two fresh reviewers**: new sub-agents that have seen none of this work. Give them only:
   - the frames
   - the reference shop frames in `review\map-fixes\references\`
   - Round 3's style guide and section 2.1 (the "AI look")
   - the scoring questions below

   Each reviewer scores 1 to 5 and lists the three changes that would raise the score most:
   - **(a) "AI look":** does it look designed by a person for this game, or generic?
   - **(b) Against the reference:** as vibrant, enticing and easy to buy from?
   - **(c) Clarity for a 7-year-old:** can they tell what each item does and what it costs?
3. Fix the top findings that both reviewers agree on first.
4. Re-score with two **new** fresh reviewers. Repeat up to three rounds.

Things to check yourself before the first review:
- every price button the same green
- every deal stamp the same red and gold
- one clear hero
- card sizes varied on purpose
- no empty or half-loaded art (see C-06)
- prices use `Format` (E-07)
- PREVIEW tags small and consistent, not shouting
- the Robux items match E-10
- hover lift and outline glow on desktop
- a press state on touch
- nothing hidden under Roblox's own top-bar buttons at phone size

Also re-score the items Round 3 never scored (Props and the Update Log), and re-score the Launch Pads after the round rainbow loop, from all views, not only the arrival view.

**Done when:** the Shop scores at least 4 on (a), (b) and (c) from two fresh reviewers at all three sizes, or after three rounds you report the honest final scores and the reviewers' remaining top items.

**[ChatGPT] C-05a Ten specific lessons from the supplied shop contact sheet.**
[ChatGPT] These are observations from review/map-fixes/references/shop-contact-sheet.jpg and the supplied frames, translated into original Car Hop design. They do not authorize copying item art, names or paid-random mechanics.
[ChatGPT] 1. A persistent title and compact category tabs establish where the player is. Keep the active tab visibly selected while scrolling.
[ChatGPT] 2. One large offer anchors the first view, with smaller offers beside it. Keep one hero instead of equally loud tiles.
[ChatGPT] 3. Product art occupies a large share of each card. Enlarge Car Hop's existing Cash, pit-garage and trail art without cropping the benefit or price.
[ChatGPT] 4. Distinct section colors group related products. Use consistent product-family colors over the existing blue frame, not a different neon gradient on every card.
[ChatGPT] 5. Price buttons share a strong green treatment. Keep the entire price and currency symbol inside a predictable button region.
[ChatGPT] 6. Clear section headings separate a long catalog. Keep headings readable and prevent sticky navigation from covering the first row after a tab jump.
[ChatGPT] 7. Offer labels sit near the item they explain. Put each benefit beside its art rather than in a detached wall of text.
[ChatGPT] 8. Larger currency bundles show visibly larger piles and larger quantities. Scale Car Hop's art and numbers consistently with the fixture amounts.
[ChatGPT] 9. A glimpse of the next section invites scrolling. Show a deliberate edge of content, never a clipped primary price or an apparently broken card.
[ChatGPT] 10. Small status/count labels support the main offer instead of competing with it. PREVIEW, owned and unavailable states should remain readable but secondary.
[ChatGPT] Motion is unverified from the still frames. For Car Hop, prefer one restrained hero motion, a short button press and occasional shine. These are proposed treatments, not claims about the reference's animation.
[ChatGPT] Fix the price clipping visible in shop-phone-cash.jpg before adding decoration. Keep item name, benefit, amount and action in a clear scan order. Test the last Cash row and all scroll extremes.
[ChatGPT] Reviewer rubric: 1 is broken or unreadable; 2 has major hierarchy/clipping faults; 3 is usable with visible inconsistencies; 4 is cohesive and clear with only minor polish left; 5 is exceptional across every supplied state. Ask reviewers for concrete screenshot coordinates or named controls. Scores are design opinions, not proof of conversion or child comprehension.
[ChatGPT] A missing price, misleading included item, inaccessible close button, or clipped primary action blocks a 4 regardless of attractive art. Compare the same viewport and state in each review round. Use the requested two independent reviewers, at most two Sonnet agents at once, not an Opus swarm.

**C-06 Preload images during the loading screen.** Today each Shop and HUD image downloads the first time it appears, so screens open with blank or placeholder art.
- In `src/client/UI/Loading/LoadingScreen.luau`, preload the HUD icons, Shop art, Garage card art and the Launch Pad kiosk icons at join. First check in the current official Roblox docs how `ContentProvider:PreloadAsync` behaves today: its callback, what it accepts, and what happens on failure.
- Show a real progress bar ("Loading cars... 34 / 120") that moves as items finish. Reference: `R4-IMG-03`.
- **Never block forever.** Cap the wait (start at 8 seconds and tune). After the cap, continue into the game, and keep loading the rest in the background.
- Keep the clean placeholder shapes for anything not loaded yet. Never show a half-loaded image.
- Measure join-to-playable time before and after, in Play, three times each, and record it.
- **Done when:** the Shop and Garage open with every image already showing on first open after the loading screen, the cap works when an asset fails (test with one deliberately bad id in a test-only list, then remove it), and the times are in the ledger.

**[ChatGPT] C-06a Extend the existing loading system.**
[ChatGPT] LoadingScreen.luau is the view. LoadingController.luau already handles progress, readiness, late callbacks and a bounded optional-art wait. src/replicatedfirst/LoadingBoot.client.luau currently supplies a tiny manifest. Extend that structure; do not create a second loader in a UI view or require the full game before its bootstrap appears.
[ChatGPT] Official API: PreloadAsync takes a content list and an optional callback, and yields. Supported usage includes asset-bearing instances and content IDs. The callback receives contentId and Enum.AssetFetchStatus. Completion is not proof that every fetch succeeded. There is no timeout parameter or cancellation token in this signature. Wrap invocation errors and inspect individual statuses. [ContentProvider](https://create.roblox.com/docs/reference/engine/classes/ContentProvider).
[ChatGPT] Project design: build a deduplicated manifest from actual used assets. Include immediate HUD icons, visible Shop cards, Garage thumbnails or their actual mesh/texture dependencies, and kiosk art. Warm remaining tabs in small background batches. Do not preload Workspace or every mesh in all Worlds. A model's name is not an asset ID.
[ChatGPT] Use known manifest IDs as the denominator. Count each ID once. Track success, failure and unresolved separately. A completed failure can advance an honestly labelled checked-items counter but cannot be described as successfully loaded art. The image's 72/120 is an example asset count, not a promise or the car roster size.
[ChatGPT] Start the art deadline with the preload attempt. Use 8 seconds as the initial optional-art budget. Essential readiness still requires the actual player, scene and controls to be ready. If those are not ready, show an honest connecting/recovery state. Do not drop the player into an unusable game because art's timer expired.
[ChatGPT] At the deadline, stop blocking on optional art. Keep the network work bounded and ignore callbacks targeting a destroyed view. Do not restart the same batch on every Shop open. Preserve cleanup and the existing loading-complete handoff to Welcome back.
[ChatGPT] Use placeholder silhouettes until an image is ready. If unavailable, keep a clean stable fallback and a plain retry/unavailable state where needed. An optional blurred background must not become a dependency for displaying the loading bar.
[ChatGPT] Validation: three before and three after timings, with machine, cache condition, manifest count, ready time, art deadline, success/failure counts and first-open result. Warm-cache Studio results are not cold-network evidence.
[ChatGPT note] C-06's perfect-art first-open check and failure/timeout check are different cases. Under normal successful loading, require visible art on first open. Under forced failure or delay, require a responsive screen and honest placeholders, not an impossible all-assets-success claim.
[ChatGPT] Inject one invalid ID into a test-only manifest, then remove it. Separately simulate a delayed callback in LoadingFixtures to test the deadline, since a bad ID can fail immediately. Also test duplicate callbacks, cancellation, empty manifest and late completion. Do not mark an untested real-network timeout as proven by the fixture.

**C-07 Launch Pad performance.** Downtown's pad is 627 parts in all and about 418 on the platform, against the Round 3 limit of 389 for a pad. Dusty Highway is 412 and Summit Pass 460. The Dusty run was never measured.
- Bring every pad's **platform** to **389 parts or fewer** and every **whole pad** (platform plus backdrop) to **500 or fewer**, without visible loss.
- Use the same method as before: laptop, Studio Play, 3-second frame average, live part count.
- Merge repeated small parts into meshes (rails, lights, signs), replace part-built detail with decals or textures, and simplify the World-below diorama where it's out of focus. New meshes go in one group-upload package (LEGION STUDI0S, 74306252, as Creator) with a manifest, or through Open Cloud if `ROBLOX_OPEN_CLOUD_KEY` exists. Never print, log or commit the key.
- Also measure the Dusty Highway run, the island and each World run with the same method, and record all of them in one table.
- **Done when:** the table shows every pad under both budgets at about 60 fps on the laptop, with before and after frames of the same views showing no visible loss.

**[ChatGPT] C-07a Optimize the measured bottleneck.**
[ChatGPT] Reuse mesh and texture assets, reduce needless frame callbacks and clean up resources. Turning tiny trim into shared mesh geometry or texture detail can reduce instances, but triangles, material changes and transparency still cost rendering time. Disable unnecessary shadows on small decoration and verify the same view. [Performance guidance](https://create.roblox.com/docs/performance-optimization/improve).
[ChatGPT] Project application: merge static rail sections, rivets and light housings by small reusable assembly. Keep moving kiosks, rotating cars, collision surfaces and separately controlled lights independent. Do not replace a hundred small parts with an enormous dense mesh merely to satisfy the count.
[ChatGPT] Use RenderFidelity.Automatic as the starting mesh setting and compare distance views. Choose simple CollisionFidelity where collision is needed; visual-only meshes should not collide. Inspect the exact property support on each instance class before assigning it. Never simplify the walkable platform into holes or block a kiosk trigger.
[ChatGPT] Preserve arrival silhouette, colored edge ring, all three kiosks, start gantry, safety rail and recognizable World backdrop. Use textures for flat marks, not for objects whose depth matters from the orbit camera. Compare arrival, low orbit, maximum zoom and countdown views.
[ChatGPT] StreamingEnabled is an edit-time Workspace setting. ReplicatedStorage does not gain Workspace streaming, and locally created scenery is not automatically unloaded like server-streamed map geometry. Keep explicit pad cleanup. [Instance streaming](https://create.roblox.com/docs/workspace/streaming).
[ChatGPT] Record current streaming settings. Do not toggle them simply to hit the budget. If a change is justified, retest portal arrivals, floor availability, avatars and return paths with missing/late geometry. Do not set every model Persistent as a shortcut.
[ChatGPT] In Studio, Ctrl+F6 opens the MicroProfiler. Sixty FPS corresponds to about 16.67 ms per frame; average FPS alone hides stalls. [MicroProfiler](https://create.roblox.com/docs/performance-optimization/microprofiler).
[ChatGPT] Keep the original three-second average for comparison. Add three 10-second observations after settling, with mean frame time, p95 frame time and worst frame. Compute overall FPS from frame count divided by elapsed time, not the average of instantaneous reciprocal samples. Separate asset-loading spikes from steady-state measurements.
[ChatGPT] Record laptop, graphics quality, resolution, client count and camera route. A frame cap can conceal headroom. Record CPU/GPU scope evidence when accessible. Do not call laptop emulation a real phone benchmark.
[ChatGPT] Count BaseParts under named platform and whole-pad roots, including MeshParts. Report backdrop separately and count lights, emitters and active animations too. Capture both counts while the pad is present. Keep the existing <=389 platform and <=500 whole-pad limits.
[ChatGPT] New uploads remain limited to C-07's authorized group package. Confirm creator and manifest, never log a key. Local visual success does not prove the published group can load Brian L's user-owned car assets. Publishing stays prohibited.

**C-08 Videos with game audio, without touching Adam's other windows.**
- Record short walkthrough videos (30 to 60 seconds each) at a phone-landscape-sized Studio window, with game audio:
  - the Shop
  - the Garage with the edition ladder
  - a full run in each World ending in "It's yours!" (from C-02)
  - each Launch Pad countdown
  - the parking "Get more spots" flow
  - the loading screen
- Record only the Studio window, never the desktop.
- If the audio recorder is blocked by Windows Application Control (it was last round), record without audio and say so. Don't try to get around the block.
- Also measure loudness for the three Launch Pad ambient sounds and the start beeps, and balance them against the World music. No sound should be much louder than the rest. Nobody has listened to them yet.
- **Done when:** the videos are in `review\round4\videos\` with a one-line list in RESULT.md.

**[ChatGPT] C-08a Honest motion and audio verification.**
[ChatGPT] Use Studio-only video capture. Record the viewport, not Adam's desktop or other windows. If capture is unavailable, label stills as stills. Do not call a screenshot a video.
[ChatGPT] If output audio can be captured, compare equal-length segments at fixed game and system volume. Note peak level, clipping and relative loudness. Sound.Volume alone is not measured loudness. Listen to the mix if playback is available; otherwise mark listening unverified. Keep start beeps audible without overwhelming music.
[ChatGPT] The 30-60 second target applies to walkthrough clips. If a genuine capture run needs longer, keep the full continuous evidence rather than cutting away the decisive gameplay.

**C-09 Launch Pad loose ends.**
- Test RETRY in Downtown and Dusty Highway (only Summit was tested).
- Open every kiosk in all three pads in Play (Dusty's weren't opened).
- Orbit the camera at the zoom limit in a phone-landscape window in each pad.
- Scroll the Car stall to the end with 27 cars.
- Open the F4 camera tuner panel once in the beta.
- Check that the Downtown tree-top fix (white tops) is really visible.
- The TRAILS kiosk and the launch card still open Trails. Make sure they open the same Trails tab in Customize that the Garage uses, so there's one Trails screen, not two.
- **Done when:** each item has a frame or a one-line result in the ledger.

**[ChatGPT] C-09a Filter and cleanup clarification.**
[ChatGPT note] The 27-car scroll check applies to a global picker. A World-specific Car stall must show its nine cars, as E-05 requires. Check the last item in all three nine-car lists and any global 27-car picker without mixing Worlds.
[ChatGPT] Repeat pad -> run -> retry -> home five times. Verify one active kiosk panel, one countdown, one appropriate music mix and no accumulating pad models or connections. RETRY in one client must not reset another client's pad.
[ChatGPT] Decision 0035 removes a pad when its local player starts. In M-02, verify that this cannot remove another player's shared support surface or hide that other player's avatar unexpectedly.

**C-10 Tutorial "Park" step, through the agreed contract.** The tutorial's Park step is skipped because there's no park control yet.
- The Agreed contract now names `SetLineupSlot (slot, carId)`. In the beta only, wire the Raceway Lineup picker to a **beta stand-in** with that exact name and arguments, in `src/server/Beta` (Adam's integration glue). It validates like the contract says: slot within `ParkingSpots`, car owned, not already in the Lineup.
- Turn the tutorial's Park step back on: an arrow to the Paddock → the Lineup panel with the claimed car highlighted → tap → the car drives out and laps → the first Lap Pay pop.
- Mark the stand-in clearly as beta-only, to be replaced by Brian L's real remote.
- **Done when:** a fresh beta profile plays the tutorial from "Go to Downtown" to "Done" with Park included and no errors, captured in frames.

**[ChatGPT] C-10a Contract and tutorial checks.**
[ChatGPT] Inspect the beta's existing server adapter first. Do not create a second remote with the same name or extend its signature. Reject non-integer/out-of-range slots, unknown/unowned IDs and duplicate placement. The requesting player is the server-supplied sender, never an owner ID provided by the client.
[ChatGPT] Test rapid duplicate taps and failed placement. Advance the tutorial only after the accepted placement is reflected in the beta state. A button animation alone is not completion. Check leaving/reopening the panel and replaying the tutorial without duplicate grants.
[ChatGPT] Keep the stand-in guarded for the private beta and its mock store. A successful beta flow is not proof that Brian L's future authoritative integration exists.

**C-11 Reduce Motion on the new screens.** Turn on Roblox's Reduce Motion (or the game's own switch if that's what the screens read) and check:
- the Shop's moving gradients and shine
- the Launch Pad countdown
- the edition ladder
- the loading bar
- the "It's yours!" celebration

Each must calm down (no shake, no flashing faster than 3 per second, shine sweeps off) and still read clearly.
**Done when:** a frame of each with Reduce Motion on.

**[ChatGPT] C-11a Motion needs temporal evidence.**
[ChatGPT] Keep the requested stills, then add a short comparison clip or observed animation-state record. A still cannot prove shake or flashing stopped. Test changing Reduce Motion while a panel is open, not only before opening it. Progress and countdown information must remain accurate with animation removed.

**C-12 Things that aren't Lane 3's: write them down, don't fix them.**
- Brian R's floating car labels piling up at the horizon, and the "Lane 1 run prototype" label still on screen.
- The crash at about 50 m with no steering, if C-02 confirms it.
- Pizza Runner's white and red reading as an ambulance (Brian L).

Put each in the round's message for its owner (F-04), with a frame.

---

## 5. Module M: two-player test of the shared island

Nobody has ever seen two players in the game at once. Round 3 and the Launch Pad round were tested alone.

**M-01 Start a local server with 2 players** in the beta file.
- Check the current official Roblox docs for how Studio's multi-client test works today (Test tab, Clients and Servers, Local Server, number of players) and whether the Studio MCP can start it and read each client's Output.
- If it can, drive it yourself. If a click is needed that you can't make inside Studio, write the exact clicks in RESULT.md and continue with everything else.
- Use the beta's mock or stand-in save, never live data.

**[ChatGPT] M-01a Verified current Studio controls.**
[ChatGPT] Official current workflow: in the left mezzanine's testing dropdown select Server & Clients, choose 2 clients, then press Play or F7. Studio opens a server session and separate client sessions. Up to eight clients are supported; this game's six-player test is within that tool limit. End Session from a simulation window closes the simulated server and clients. This differs from older Test-tab wording. [Studio testing modes](https://create.roblox.com/docs/studio/testing-modes).
[ChatGPT] Open Output separately in the server window and each client window. Use Studio's Window menu to locate Output if it is hidden; confirm the installed UI label before clicking. Record server, client A and client B logs independently. Solo Client/Server toggling is not a two-player test.
[ChatGPT] The MCP schema inspected for this brief exposes start_stop_play(is_start, studio_id), with no client-count argument. It does not establish automated multi-client startup. Inspect Claude's actual tools at runtime. Do not invent a player-count argument, a command-line launch flag or an undocumented StudioService API.
[ChatGPT] If controls are available through Studio-only automation, select the mode and count there. Otherwise report the exact dropdown -> Server & Clients -> 2 -> Play steps for Adam and complete independent work. Game-input MCP calls target a running Client data model and are not evidence that they can operate Studio chrome.
[ChatGPT] Identify the beta place, server session and both client identities before driving inputs. Check whether the tool can attach to each new session and retrieve its Output. An absent attachment means that client's checks are unverified, not silently passed.
[ChatGPT] Before starting, verify the beta uses mock data and cannot reach the live profile store. Record this from configuration and runtime evidence. Keep live API access unnecessary for the test.

**M-02 Check from both clients**, side by side, with a frame from each player's screen:
1. **Plots:** each player gets a different plot, spawns at their own gate, and sees their own name on their nameplate and the other's name on theirs.
2. **Owner avatars over the Raceways:** each player's see-through avatar and name float over their own Raceway, and the other player sees it too.
3. **Visiting:** player 2 walks onto player 1's Raceway.
   - The lapping cars pass through them harmlessly (nobody gets launched).
   - Tapping or clicking a car shows a read-only card.
   - Player 2 cannot buy, park or upgrade on player 1's plot: the shop, kiosk and parking prompts don't open, or say "This is Player1's Raceway".
4. **Independent progress:** player 1 buys a Raceway level and a parking spot (PREVIEW). Player 2 sees player 1's track change looks, but the level-up banner and sounds play only for player 1. Player 2's plot is unchanged.
5. **Personal screens stay personal:** Shop, Garage, Settings, Missions, toasts, the Welcome back card and the group reward popup open only for the player who triggered them.
6. **Portals and Launch Pads:**
   - Both players enter different portals at the same moment.
   - Then both enter the **same** portal: both appear in that Launch Pad and can see each other.
   - Each player's launch card, countdown and kiosks are their own.
   - Each run is private: neither sees the other's traffic.
   - RETRY and HOME work for each without moving the other.
7. **Audio:** music doesn't double, and one player's level-up or claim fanfare doesn't play loudly for the other.
8. **Tutorial:** a fresh profile on each client gets its own tutorial; one player's banner never shows on the other's screen.
9. **Leaderboards** show both players.
10. **Leave and rejoin:**
    - Player 2 leaves. Their plot is freed and cleaned (no leftover cars or avatar).
    - Player 2 rejoins, gets a plot, and their stand-in save comes back.
    - Closing a client **mid-run** leaves no server errors and frees the plot.
11. **Output:** server and both clients have no new errors or warnings. Old known lines (asset 203785492) are noted, not counted.

**[ChatGPT] M-02a Extra shared-world checks and evidence format.**
[ChatGPT] Use a matrix with row ID, client A action/result, client B observation, server result, screenshot/log path and status. Test each role in both directions. Label identities on evidence, not by window position alone.
[ChatGPT] Give the two mock profiles visibly different car selections, parking counts and Raceway levels. Then an accidental shared fixture or broadcast is obvious. Prepare test data through the beta mock harness before the test, not by faking a successful UI action.
[ChatGPT] Late arrival: after A upgrades and parks, B joins and sees the current A plot without replaying A's private celebration. B's own profile must stay unchanged.
[ChatGPT] Near-simultaneous actions: both claim separate plots, buy a preview spot and open Garage. Verify no duplicate plot assignment, crossed Lineups or camera ownership.
[ChatGPT] Visitor denial needs beta server validation as well as hidden prompts. With the agreed arguments, a visitor cannot nominate another owner. Record any missing owner enforcement as a failure.
[ChatGPT] Same-pad presence: verify both actual replicated avatars occupy the same physical location, not separate locally staged clones. Check the floor exists on both clients, each sees the other moving, and one launch does not remove the other's floor or countdown.
[ChatGPT] Private runs: check traffic, labels, camera, HUD, results and audio on both clients while one runs and the other stays home. Repeat with both running in the same World. Hiding a label alone does not establish isolation.
[ChatGPT] Shared visuals must be reconstructed from each plot owner's state, not LocalPlayer state. If Lane 2 state replication is missing, report that dependency rather than creating a new shared contract.
[ChatGPT] Disconnect during a countdown, an open Lineup panel and a run. Verify cleanup after each. On return, verify exactly one plot and no duplicate avatar, sounds or lapping models.
[ChatGPT note] Mock persistence depends on the actual implementation and player identity. A newly launched local client can have a different test UserId, and restarting the server can clear memory-only data. Record original and returning UserIds and store lifetime. Do not claim durable rejoin persistence unless the same identity and supported mock lifetime were tested. Do not turn on live saves to make this check pass.
[ChatGPT] Record expected injected-test warnings separately from unexpected warnings. Treat asset 203785492 as known only when the exact warning matches the documented issue. Do not suppress all asset-load warnings.
[ChatGPT] If a check cannot run, mark BLOCKED with owner and reproduction steps. Keep it distinct from PASS and from a code-reading assessment.

**M-03 Full server.** If the laptop can handle it, repeat a short version with **6 players** (the server maximum). Check:
- all six plots taken
- six owner avatars
- frame rate on one client

Record the number. If the laptop can't run 6, run as many as it can and say how many.

**M-04 Fix and report.**
- Fix every failure inside Lane 3's paths and the beta glue, then re-test that check.
- Failures inside Lane 1 or Lane 2 code go in their message with steps to reproduce, what you expected and what happened.

**Done when:** every check in M-02 has a pass, a fix-and-pass, or a clear owner and reason, with frames from both clients.

---

## 6. Module F: finish

**[ChatGPT] F-00 Completion evidence and scope.**
[ChatGPT] A source-code change, a fixture run, a solo Play test and a two-client test are four different evidence types. Record the actual type for every claim. Never upgrade one to another in RESULT.md.
[ChatGPT] Preserve the explicit merge authorization and its conditions in F-03. Report unresolved integration risks prominently in the PR and RESULT, even when the module is honestly partial. Do not claim launch readiness from a green code check.
[ChatGPT] Before saving a place, confirm the exact open private file. Save persistent edit-mode changes after stopping Play; Play-only transient instances are not durable scene edits. Runtime recipes should rebuild correctly on a fresh Play. File LastWriteTime proves a write occurred, not that the right content was saved, so reopen or re-test the intended file when possible.
[ChatGPT] Final verification includes all requested image filenames, updated source/spec paths, no unintended teammate-file diff, the feature and beta commit IDs, real check exit codes, and an itemized list of manual actions remaining. No review website.

**F-01** Run `./scripts/check.ps1` and fix any failures in this task.
- Exit 0 means every check ran and passed.
- Exit 1 means a check failed or a tool is missing.
- Exit 2 means the OS blocked a tool, so a check didn't run. That's **not** a pass: say so and rely on the GitHub check.

**F-02** Commit in clear steps (one per module is fine), push `feature/lane3-round4`, and open a pull request to `main` with `gh`. Describe what changed, what was actually tested in Studio (and how), what wasn't, and anything a teammate must do after pulling. Merge the feature branch into `integration/beta-2` and update draft PR #9.

**F-03 Merge into `main`.** Adam wants the team to see his work on `main`. Once the GitHub check passes on the new PR, and every module is done or honestly marked partial in the ledger, merge it into `main`. Don't merge if the check fails or anything touches a teammate's files. *(Adam: delete this item if you'd rather click Merge yourself.)*

**F-04 Records:**
- Update the board row and add a log entry.
- Finish the ledger and decision 0036.
- Write `vault/design/specs/lane3-round4-for-brian-r.md`: C-02's crash cause if found, C-12's run items, and M-04's run failures. Include a `## Replies` section.
- Brian L's items go in the E-02 answers file plus any M-04 failures. Don't make a second file for him.
- Don't rewrite earlier messages.

**F-05 RESULT.md** in `review\round4\`, short and plain, in this order:
1. What to open and try.
2. Status per module, one line each.
3. Choices you made.
4. Steps that need Adam (as few as possible, with exact clicks).
5. Known issues.
6. The performance table.
7. What wasn't tested.

**F-06 Final message to Adam:** a few lines only. Say it's ready, what to open, the one or two things that need him, and the PR link. No review pages.
