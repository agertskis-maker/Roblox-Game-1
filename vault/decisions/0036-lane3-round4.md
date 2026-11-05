# 0036: Lane 3 Round 4: Adam's economy decisions in the Lane 3 screens

Date: 2026-11-03. Owner: Adam (Lane 3, repository owner).
Status: decided by Adam (repository owner); items 1 to 3 delegated to Claude and chosen as written.
Brief: `vault/design/specs/lane3-round4.md`. Ledger: [[lane3-round4-ledger]]. Answers for Brian L: [[economy-v1-answers-from-adam]].

## The five decisions (Adam, 2026-11-02, 22:40)

These answer Brian L's economy v1 (`vault/design/specs/economy-v1.md` on `feature/lane2-economy-design`, sections 11 to 13).

1. **Car list: Brian L's showroom, five rarities, 9 per World.** Adam: "you can use Brian's showroom for 25 cars and 5 rarities, and just split that up between the 3 worlds using your best judgment." The showroom has 27 built cars, so all 27 are used, 9 per World (table below).
2. **Rider Level gate: not at launch.** Adam: "For the Rider level gate, I want you to just use your own best recommendation and go ahead with that." World unlocks, longer Keys times for rarer cars and the 5-bolt Stamina limit already hold a player back; a fourth gate is a wall for young players, and a Keys bar that silently never fills breaks "readable danger". It moves to the board's Deferred list.
3. **Big numbers: the existing Lane 3 rule plus Qa.** Adam: "how you put it there is accurate. You could use the abbreviations." Exact dollars below $10,000; from $10,000 three significant digits with K, M, B, T, Qa, truncated, never rounded up.
4. **Save fields: Agreed by all three lanes.** Adam: "The proposed save fields, we all agree to them." `Cash`, `Cars { [carId]: { Edition, Copies } }`, `Lineup`, `RacewayLevel`, `ParkingSpots`, `WorldsUnlocked`, `LastSeen`, and the remotes `BuyRacewayLevel`, `BuyParkingSpot`, `SetLineupSlot`, `UnlockWorld`.
5. **Robux: the 19 Robux respawn and every planned Robux purchase are in the launch scope.** Adam: "we definitely are going to have the 19 Robux respawn, and we're going to have all the Robux purchases. That's non-negotiable." He was told on 2026-11-02 that the respawn helps a run, and kept it. Cars and editions are still never sold for Robux (Brian L's rule, unchanged).

## What the Robux decision overrules

- Economy v1 section 11's recommendation to leave the respawn out at launch.
- The outline's "No Developer Products (Cash packs) at launch".
- The outline's "Paid passes never change Heat, Keys or race performance", as far as the respawn goes.

Every Robux item stays PREVIEW with "Coming soon" in Lane 3 until Brian L's server-checked grants exist. No `MarketplaceService` call exists in Lane 3.

## The 27-car split (E-03)

| World | Common | Uncommon | Rare | Epic | Legendary |
|---|---|---|---|---|---|
| Downtown | **Putter** (Loaner), Pizza Runner | Minnow, Surf Wagon | Bolt, Brawler | Executive | Street Kid, Cruiser |
| Dusty Highway | **Rustbucket** (Loaner), Old Faithful | Beach Bug, Workhorse | Thunder | Desert King, Night Rider | Viper Strike, Apex |
| Summit Pass | **Commuter** (Loaner), Family Hauler | Trailblazer, Sunny Camper | Rally Dog | Monarch, Velvet | Zip, Phantom |

Sparkster (Downtown) and Polytruck (Dusty Highway) join when built. Brian L's Catalog wins over this table. The starter swap in the brief was not done: the fixed roster (E-03a) keeps Putter in Downtown; the look check is in the ledger.

## Choices made in Round 4

- **One roster, one economy module.** `src/shared/UI/RosterFixtures.luau` (stand-in for the Catalog) and `src/shared/UI/EconomyPreview.luau` (every economy v1 number, PREVIEW). Every Lane 3 screen reads them; Brian L's data replaces each in one place. They live in `src/shared/UI` so the beta's server glue can check car ids too.
- **Car ids are the model names** in `ReplicatedStorage.Cars` ("Pizza Runner"), exactly as exported. No id was made up.
- **`Edition` read as 1 to 5 (Normal to Galaxy) and `Copies` as copies held at that edition (0 to 24).** Economy v1 does not say; both are questions for Brian L in the answers file, not new fields.
- **The five dots on a Garage card are now editions**, lit up to the best reached in each edition's colour. Rarity stays its word and frame.
- **Lap Pay on a card is the car's own pay at its best edition, before the Raceway level** (the level multiplies every car). The edition ladder shows the multiplier of the best edition ("x3 Lap Pay").
- **Expanded Paddock gives 3 bays on top of the ones bought, up to 18** (a pass that adds nothing at the maximum would be a broken purchase). Built on 2026-11-03 at Adam's request: with the pass the front row becomes 10 evenly spaced bays, mirrored about the centre line and lined up with the back row, on matching floor strips at both ends, the sign moves out, and the saved ParkingSpots stays 2 to 15 (the server adds the 3 when it publishes the plot). One value (`Parking.ExpandedSpots`), a question for Brian L.
- **No paid item shares a word with an earned edition.** The Robux trails "Rainbow Road" and "Galaxy Tail" became Prism Ribbon and Comet Tail, and the Cash paints "Rainbow Flow" and "Galaxy Drift" became Prism Flow and Nebula Drift. "Rainbow Road" was also a well-known track name.
- **The locked-portal card asks for what is still missing.** A World needs cars from the World before and Cash; once the cars are met, Coach Roxy asks for the Cash instead of saying the road is open.
- **The Launch Pad's TRAILS and PAINT open the Garage's Customize panel** at that tab, so there is one Trails screen.

## Where each decision shows up

| Decision | Lane 3 screens |
|---|---|
| Roster | Garage Index and detail, card thumbnails, Launch Pad turntable and Car stall, launch card, run results tray, tutorial, Missions, Welcome back, portal signs and Coach Roxy |
| Rider Level gate | nothing to remove: no Lane 3 screen had a Rider Level readout; Stamina unchanged |
| Big numbers | `Format.cash` everywhere money is drawn (HUD, Shop, Raceway board and panel, parking, portals, Results, Welcome back, Missions, Garage, Lap Pay pops) |
| Save fields | edition ladder (`Edition`, `Copies`), parking (`ParkingSpots`), Raceway (`RacewayLevel`), beta stand-in `SetLineupSlot` |
| Robux | Shop passes, Cash packs and Robux trails, the Results respawn, "GET MORE SPOTS" |

## What would justify revisiting

- **Car split:** Brian L's Catalog places a car differently, or a World plays much harder than the others.
- **Rider Level gate:** playtests where skilled players claim every car of a World in one run even with 5 bolts.
- **Big numbers:** a playtest where children misread K, M, B, T or Qa (then add the word, for example "1.2 million").
- **Save fields:** only by all three lanes again.
- **Robux:** only Adam; a Roblox policy change or a failed policy check would also force it.

## What Round 4 delivered and left open

Later the same day: the Expanded Paddock bays (up to 18) and, by Adam's decision [[0038-starter-pack-rare-car]], Brawler inside the Starter Pack. Built and checked in Studio Play (one client, mock save): the roster and economy modules, the Garage and card detail with the edition ladder, the Car stall per World, the RACEWAY FULL parking state with GET MORE SPOTS, Settings alignment, preloading (134 items, ready in about 4 to 5 s on a warm cache) and the new name on the loading screen and pad floor. Two fresh reviewers scored the Shop 4 / 4 / 3 on desktop and 3 / 3 / 2 to 3 on tablet and phone. The art of the Starter Pack, VIP and Expanded Paddock suggests that a car is included, and needs new art.

Left open (ledger [[lane3-round4-ledger]]): the flicker scan, the run test driver, pad performance, videos and loudness, Reduce Motion stills, the Lineup picker and the tutorial Park step, and the two-player test.
