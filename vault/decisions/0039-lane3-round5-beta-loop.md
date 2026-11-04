# 0039: Lane 3 Round 5: the first real loop in the beta, on beta-only stand-ins

Date: 2026-11-03. Owner: Adam (Lane 3, repository owner, beta integration person).
Status: decided by Adam (section 0 below, his brief of 2026-11-03); the build choices are Claude's under the brief's "your call" items and are listed in [[lane3-round5-ledger]].
Brief: `vault/design/specs/lane3-round5.md`. Ledger: [[lane3-round5-ledger]]. Handoffs: [[beta-standins-for-brian-l]], [[lane3-round5-for-brian-r]].

## Adam's decisions, verbatim (brief section 0; every line was kept as recommended)

## 0. What Adam decided for this round (2026-11-03)

Claude (claude.ai) wrote these as recommendations and Adam kept every line he did not delete. Anything still here is decided. Do not re-argue it; record it in the decision note.

1. **Round 4 goes into `main` first.** The Round 4 draft pull request (`feature/lane3-round4`) is merged into `main` at the start of this round, once the GitHub check passes, so Round 5 and both teammates build on it. Open items from Round 4 are carried into this brief, not left on the branch.

2. **This round makes the beta's core loop real, with beta-only stand-ins.** Today a player can run, see a claim on the Results panel, and then nothing happens: no car arrives in the Garage, nothing parks, nothing pays. Adam decides that the beta (and only the beta, `beta.project.json`) gets stand-in server code in `src/server/Beta` for the rest of the agreed contract, so the three teammates can play the whole loop for the first time: portal, run, claim, Garage, park on the Raceway, Lap Pay, buy a Raceway level or a parking spot, unlock a World.
   - The stand-ins use **only the Agreed save fields** (decision 0036 item 4): `Cash`, `Cars`, `Lineup`, `RacewayLevel`, `ParkingSpots`, `WorldsUnlocked`, `LastSeen`. The beta template already has `Cars`, `Lineup`, `RacewayLevel`, `ParkingSpots` and `TutorialDone`; `Cash`, `WorldsUnlocked` and `LastSeen` are added now. No other field.
   - The stand-in remotes use the **agreed names and arguments** (`BuyRacewayLevel`, `BuyParkingSpot`, `SetLineupSlot`, `UnlockWorld`) and the run report follows the shape of note 0021 (Agreed by Brian L and Adam on 2026-10-28). Brian L's real modules replace each stand-in one for one; nothing in the client should care which is running.
   - The run report is **client-trusted in the beta.** Brian R's run is client-only, so the server cannot re-derive the sequence yet. The beta accepts what the client reports, inside hard caps (section 3, L-03), and logs it. This is scaffolding for a private playtest among three people. It is deleted when Lane 1 reports through the server and Lane 2 checks it. Write that sentence at the top of the module and in the decision note.
   - Every number (Lap Pay, prices, unlock requirements, edition ladder) comes from `src/shared/UI/EconomyPreview.luau` and stays tagged PREVIEW. Brian L's Catalog replaces it in one place.

3. **The Lineup picker exists and the tutorial's Park step comes back.** A new claim parks itself when a spot is free (toast "Putter joined your Raceway!"), except during the tutorial, where the player parks the first car by hand so the panel is learned (outline section 08, "auto-add" rule). The tutorial step is `Park`, between `Go home` and `Done`.

4. **The two-player and six-player tests run hands-free.** Round 4 was blocked because the Studio MCP's `start_stop_play` starts one client and the Clients and Servers control needs a click. Roblox now has `StudioTestService` (checked 2026-11-03 on create.roblox.com): `ExecuteMultiplayerTestAsync(numPlayers, args)` starts one server plus 1 to 8 clients, callable from a **plugin**; `EndTest(value)` ends it from the server DataModel; `AddPlayers(n)` adds clients mid-session. Build a tiny local plugin for it (section 4, T-01). If the plugin route fails for a reason you can show, write the exact clicks in RESULT and stop that module only; do not stop the round.

5. **Merge into `main` at the end only if every MUST item passes.** Otherwise leave the draft pull request and say why in RESULT. `integration/beta-2` stays current either way.

6. **Publish to the private beta place at the end.** Once F-01 passes and the solo and two-client checks are green, publish the beta to the existing private LEGION STUDI0S experience "Car Hop Beta" (place 118605678346800, the one from decision 0030), so Brian R and Brian L can play it. This is the only publish this round. Nothing goes to a public place.

7. **Shop passes get new art.** The Starter Pack, VIP and Expanded Paddock cards must not show a car (two reviewers read them as "a car is included"). Use ChatGPT's `R5-IMG-03` set if it arrived; otherwise build the art in code from the game's icon family. The Shop target is still 4/5 from two fresh reviewers at all three sizes, three rounds maximum.

8. **Not this round:** anything with `MarketplaceService` or Robux (still PREVIEW and "Coming soon"), the Stunt Circuit course, Missions with real progress, real phones (Adam will test on his phone after the publish), trading, any new currency, any new saved field, any edit to Brian R's or Brian L's files.

## THE RUN REPORT IS CLIENT-TRUSTED IN THE BETA

Brian R's run is client-only, so the server cannot re-derive what the player did. The beta accepts what the client reports, inside hard caps, and logs it. This is scaffolding for a private playtest among three people. It is deleted when Lane 1 reports through the server and Lane 2 checks it.

One thing the beta server does derive itself: it hands out the run's seed (as note 0021 says), rebuilds the run's traffic with Brian R's `RunSequence`, and looks up which car a spawn index is. The beta-only `betaModel` the client adds must match that lookup, or the claim is dropped and logged.

## What each stand-in is, and why it is beta-only

Every file starts with the header "BETA-ONLY STAND-IN for Brian L's <name>. Same contract. Delete when his real module lands." They exist only on `integration/beta-2` (`beta.project.json`); `default.project.json` never loads them.

| Stand-in | Stands in for | Why beta-only |
|---|---|---|
| `src/server/Beta/BetaData.luau` (Round 1, extended) | Brian L's profile lifecycle module | uses the agreed fields only, in the beta store `CarHopBeta1` |
| `src/server/Beta/BetaEconomy.luau` | his `Economy` (preview branch) | Cash, claims, Joyrides, editions, Welcome back credit; numbers from Lane 3's `EconomyPreview` (PREVIEW) |
| `src/server/Beta/BetaLapPay.luau` | his `LapPay` | one scheduler for every plot on the shared `LapClock` |
| `src/server/Beta/BetaRun.luau` | his run report checks (note 0021) | client-trusted inside caps (above) |
| `src/server/Beta/BetaShop.luau` | his `Shop` | purchases charge Cash; `UnlockWorld` |
| `src/server/Beta/BetaLineup.luau` (Round 4, extended) | his `SetLineupSlot` | auto-park and refusal reasons |
| `src/server/Beta/BetaMultiTest.server.luau`, `src/client/Beta/BetaMultiTestClient.client.luau` | nothing (a test harness) | Studio only, idle without StudioTestService test args |

## The caps (Tunable, beta sanity, not security)

| Cap | Value |
|---|---|
| Claims and Joyrides per run | the bolt count: 5, 8 in the tutorial run |
| Events per batch | 30 |
| Batches per second | 3 |
| Distance `d` (studs) | never more than the run's own speed curve (`RunSequence:travelledAt(t)`) plus 1,500 studs; never back more than 5 studs |
| Run clock `t` (seconds) | never more than 3 s ahead of the server's clock for the run |
| Runs | one active run per player; unknown runId ignored; a run closes on BetaRunEnd, a new BetaRunStart, or the player leaving |
| Coins | none are reported by Brian R's run today, so the coin cap has nothing to cap yet |

Over a cap: dropped, logged with the player's UserId, and the run keeps going.

## Other choices recorded here

- Starting Cash $0; a one-time PREVIEW tutorial bonus of $500 is paid on the save's TutorialDone false-to-true change only (finished or skipped), so "Add a spot" ($500) is affordable when the tutorial ends. It cannot repeat: the flag only ever goes to true.
- The edition ladder reads Brian L's 25 / 250 / 2,500 / 25,000 as copies needed AT each edition, Copies starting again at 0 (the brief's wording). Brian L's preview reads them as lifetime totals: his question.
- A World's Loaner is never a run catch (every save starts with it).
- `FreePurchases` (CarHopBeta attribute) defaults to false. `BetaGrantCash` is a server-set Player attribute honoured only when `RunService:IsStudio()`.

## What would justify revisiting

- Brian L's server landing: each stand-in is replaced one for one ([[beta-standins-for-brian-l]]).
- Lane 1 reporting through the server: the client-trusted run report and `betaModel` go.
- A cap that blocks honest play in the playtest: raise that cap (they are Tunable), and say so in the log.
