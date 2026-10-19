# Car Hop (working title): Game Outline

**Version 2.1 | 19 October 2026 | Supersedes "Car-Hopping & Racetrack" v1.0**

> v2.1 change: the 100% Heat "Blowout" and 1-second "Sputter" window of v2.0 are superseded by **Critical and Meltdown** (decision 0008, 19 October 2026). Sections 02, 03, 06, 13, 15 and 18 are updated; nothing else changed.

This is the reference document for what the game is. It is written so that anyone on the team, or Claude in a fresh session, can read it and know exactly what we are building in every area. It is a design outline, not a build log and not the canonical GDD in the repository vault. When the live GDD, AGENTS.md, or the decision register conflicts with this file, the live repository record wins and this file should be refreshed.

No game functionality is claimed as built or tested by this document.

## 00 / How to read this document

Every rule in this document carries one of these labels:

- **Decided:** the owner stated it at or after the 18 October concept meeting. Change it only with the owner.
- **Delegated:** the owner asked Claude to pick the best attainable option. Claude's choice is recorded here. It is reversible, and the owner can overrule any of it at any time without ceremony.
- **Tunable:** a starting value for the first playtest. These numbers exist so the prototype can be built; none of them is approved balance. Expect every one of them to move.
- **Deferred:** intentionally not in the first release. Kept visible so it does not get lost or sneak in by accident.
- **Open:** still needs an owner or team decision. Do not invent an answer and call it approved.

The concept itself is **Decided**: the team selected this game at the 18 October 2026 meeting.

## 01 / The game at a glance

### One-sentence fantasy

You are a fearless kid who leaps from car to car on a never-ending highway, keeps every car you can hold on to, and brings them all home to your own racetrack where they earn you money while you build your dream collection.

### The pitch

Hop between moving cars before the one you are riding overheats. Hang on to a new model long enough and it is yours forever. Back home on your island, your cars do laps on your personal Speedway and pay you every time they cross the line. Spend that money to grow the Speedway, unlock new worlds full of better cars, and chase rare gold, chrome, and rainbow versions of every car you own. When you want to show off, take any car you own into the Stunt Circuit and race for the best time.

### Why this works (the three moments)

Every new car produces three separate moments of satisfaction, and the whole game is built to protect them:

1. **The capture.** Tension in the run: can I hold on long enough before the car overheats or I crash?
2. **The reveal.** The car card flips in the Garage, the collection count ticks up, and the silhouette becomes real.
3. **The first lap.** The car appears on your Speedway, drives its first lap, and pays you. You see it; so does anyone visiting your plot.

Racing then gives the same car a fourth use. Nothing in the game should be added if it weakens this chain.

### Inspiration and boundaries

Rodeo Stampede (Featherweight / Yodo1) is the mechanical reference for hopping between rides, staying aboard to claim a new one, and a home base that earns from your collection. This is an original car-themed game. No assets, names, characters, or presentation are copied. Real car manufacturers mentioned in brainstorming were examples only; every vehicle in the game is fictional with its own name and silhouette.

### Audience, devices, tone

- **Decided:** audience is mainly children. Everything on screen must be understandable without reading a paragraph. No scary failure, no punishing loss, no text-heavy menus.
- **Decided:** phone and PC are both supported. Development happens on laptops and PCs, so phone layouts and touch controls are reviewed in Studio's device emulator throughout, not at the end. Console is not a launch target (Deferred).
- **Delegated tone:** cartoony-cool. Bright, chunky, and energetic rather than cutesy. Think toy cars that take themselves slightly seriously. Humor comes from proportions and animation (a bus that bounces, a scooter that wobbles), not from jokes in text.
- **Decided:** no launch deadline. Quality over speed. The staged plan in section 15 exists to keep the work ordered, not to rush it.

### Working title

**Delegated:** the working title is **Car Hop**. It is short, says the action, fits a kid audience, and looks good on a thumbnail. Alternates if the team dislikes it or it is unavailable on Roblox: **Hop Rod**, **Joyride Jumpers**, **Hop & Keep**. Availability on Roblox has not been checked and must be verified before publishing. The final title is **Open** to the team.

## 02 / Vocabulary

These are the words used in UI and in code. Code identifiers may be longer, but they must map to these names.

| UI word | Meaning |
|---|---|
| **Hop** | Jumping from your current car (or from the road) onto another car. |
| **Heat** | The overheating meter on the car you are riding. Full Heat starts a Meltdown. |
| **Meltdown** | The short escape window after Heat reaches 100%: the car is hard to control and the player must Hop out before it crashes. Shown as "Losing control!". |
| **Keys** | The claim meter. Stay aboard an unowned car until the Keys meter fills and the car is yours. "You got the Keys!" |
| **Claim** | The verb for earning a car permanently. Replaces "tame". |
| **Joyride Bonus** | Cash paid for filling the Keys meter on a car you already own. |
| **Garage** | Your permanent collection and its menu. |
| **Speedway** | Your personal home racetrack on the island where your cars earn Lap Pay. |
| **Lap Pay** | The lump sum a car pays each time it completes a lap on your Speedway. |
| **Lineup** | The set of owned cars currently driving on your Speedway. Limited by Slots. |
| **Slots** | Speedway capacity. One car per slot. |
| **Paddock** | The visible area on your plot where your Lineup's parking bays live. Grows with Slots. |
| **World** | A themed highway you run in. Three at launch. |
| **Portal** | The gate on the island that starts a run in a given World. |
| **Variant** | A Gold, Chrome, or Rainbow version of a model you own. |
| **Stunt Circuit** | The obstacle race mode and its course. |
| **Foot Dash** | The short on-foot sprint after landing on the road instead of a car. |
| **Loaner** | The basic car every run in a World starts in if you have not picked another. |
| **Cash ($)** | The single currency. |

## 03 / Design pillars

1. **Readable danger.** The player always knows why they failed: they did not escape a Meltdown, they missed a Hop, they hit a hazard head-on, or traffic caught them on foot. No arbitrary deaths.
2. **Every car does something.** Each car family changes how the run plays. A car is a tool, a trophy, and an earner, in that order of discovery.
3. **The island shows progress.** You can tell how far a player has come by walking past their plot. Speedway size, Paddock, buildings, and the cars on the track are the scoreboard.
4. **One currency, clear prices.** Cash in, Cash out. Players always know what the next purchase is and what it does.
5. **Fair across devices and wallets.** Touch and keyboard play the same game. Paid passes speed up earning and add cosmetics; they never change Heat, Keys, or race performance.

## 04 / The island (shared hub)

### Structure

- **Decided:** one shared island per server with a personal plot per player. Players can walk onto any plot and any Speedway, but can only change their own.
- **Delegated server size:** 12 players per server, 12 plots. Small enough that a new player's plot is always available and the island feels populated without being chaotic. **Tunable.**
- **Delegated layout:** a circular island. A central plaza holds the shared buildings. Twelve plots ring the plaza like slices of a pie, each facing inward so visitors see the Speedway from the plaza. Walking across the whole island takes about 20 seconds.

### Central plaza contents

- **Garage building.** Walk in (or press the Garage button anywhere) to open the collection. The building's exterior displays the player's three rarest cars on rotating turntables so it doubles as a show-off spot.
- **Portal row.** Three archways side by side: Downtown, Dusty Highway, Summit Pass. Locked portals are visibly closed with a chain and a sign showing both unlock requirements (Cash and cars owned from the previous World) with live progress. Unlocked portals glow and show the World's name and a preview of its cars.
- **Stunt Circuit gate.** A start-line arch leading to the race course. Shows your best time and the current weekly top time.
- **Leaderboard pillars.** Two boards: Most Cars Owned and Fastest Stunt Circuit (weekly). Server-side, read from OrderedDataStores.
- **Signposts.** Big arrow signs with icons, used by the tutorial and useful afterward.

### Plots

- Each plot contains: the Speedway oval, the Paddock with parking bays (one per Slot), the plot's buildings (grow with Income Tier), and a nameplate showing the owner's name, car count, and Income Tier.
- Spawn point: a player always spawns at the gate of their own plot facing the plaza.
- Plot assignment is per server session. Leaving frees the plot. Plots are not persistent locations; the player's Speedway state is persistent and is rebuilt on whichever plot they get.
- Visitors can walk on the Speedway. Lineup cars drive through visitors harmlessly (no collision with characters) so nobody gets launched.
- Tapping or clicking any car on any Speedway opens a read-only car card (name, rarity, family quirk, owner). This is how kids compare collections without a trading system.
- A **Visit** button in the player list teleports you to that player's plot gate.

### What is not on the island

Trading, stealing, collection loss, PvP, and damaging other players' plots are **Deferred** and not part of the game's identity.

## 05 / First session (tutorial)

**Decided:** arrows and short prompts, no cutscene. Teach through the real actions.

**Delegated sequence.** Every step is gated by the player doing the thing, not by a timer. Prompts are one short line plus an icon, shown at the bottom center on phone and PC.

1. **Spawn** at your plot gate. A bouncing arrow points to the Downtown portal. Prompt: "Let's get your first car!" The Speedway is empty but visible.
2. **Enter the portal.** The run starts in the Loaner (Downtown's Common hatchback). For the first run only, traffic is sparse, hazards are off for the first 300 m, and Heat fills at half speed. Prompt: "Steer!" with the touch drag or A/D icon. It disappears after the player steers twice.
3. **First Hop.** A target ring appears under a car just ahead with the Hop icon pulsing. Prompt: "Tap to Hop!" The first Hop target is always a slow, wide car (a van) so the landing is easy.
4. **First Claim.** The Keys meter appears on the van with the prompt "Hold on!" The meter fills; the car flashes; "You got the Keys!" fanfare; the car card slides in for two seconds showing the new car and "Added to your Garage". Heat is paused during this card.
5. **Heat lesson.** Heat resumes. At 60% the warning starts. Prompt: "Too hot! Hop to a new car!" The player hops (or does not; failure here is fine).
6. **Natural run end.** When the run ends (any cause), the results screen appears: distance, cars claimed, cash earned. Buttons: **Retry** and **Go Home**. The Go Home button pulses for the first run.
7. **First lap.** Back at the plot, an arrow points to the Paddock. Prompt: "Put your car on the Speedway!" The Lineup panel opens with the van highlighted. Player taps it; the van drives out of its bay and starts lapping. On its first finish-line crossing, Lap Pay pops up and flies into the Cash counter. Prompt: "Cars pay you every lap!"
8. **First upgrade preview.** The Speedway's upgrade kiosk highlights with the next Slot's price. If the player can afford it (first run should earn enough), prompt: "Add a Slot so more cars can earn!" If not, the kiosk simply shows the price and the arrow fades.
9. **Point to racing.** A final arrow toward the Stunt Circuit gate: "Race any car you own!" No forced entry. Tutorial ends. A small "Goals" checklist (section 11) takes over as the guide.

Tutorial rules:

- Cannot be skipped the first time (it is roughly 90 seconds), but every prompt disappears the moment the action is done.
- After the first claim, all tutorial prompts can be dismissed with any input and never block gameplay.
- If the player fails before the first claim, the run restarts immediately with the same assists. The assists stay on until the first car is claimed.
- Tutorial completion is saved. It never replays unless the player resets it from Settings.
- No mission or upgrade popups fire until the tutorial is complete.

## 06 / Collection runs (the core)

### Where runs happen

**Delegated architecture (technical, reversible after prototype):**

- Each player's run is **private**. Traffic, hazards, and road segments for a run are created on that player's client only, in a run zone far from the island. Other players never see or collide with your traffic. The island stays shared; the run does not. This removes replication cost, griefing, and contested cars, and it is the arrangement most likely to feel good on phones.
- The server issues a **run seed** when the run starts. Client and server generate the same traffic and coin sequence from that seed. The client reports Hops, Claims, Joyride completions, coin pickups, and the run end; the server re-derives the sequence from the seed to confirm the claimed car existed at that point, the time aboard met the Keys requirement, and distance versus elapsed time is plausible for the speed curve. Anything that fails validation is dropped silently and logged.
- Cash, ownership, and all saves are server-authoritative. The client never tells the server "give me this car"; it tells the server what it did, and the server decides.
- All worlds, the island, and the run zones live in **one Roblox place** with StreamingEnabled. No teleports between places at launch. This is the simplest arrangement for a small team and keeps the social island one load away from every run.

### Controls

**Decided:** forward motion is automatic. The player steers and hops. No acceleration or braking.

| Action | Touch | Keyboard | Gamepad (Deferred, mapped anyway) |
|---|---|---|---|
| Steer | Drag left/right anywhere on the lower two-thirds of the screen | A / D or Left / Right arrows | Left stick X |
| Hop | Tap anywhere (a short tap with no drag) | Space | A button |
| Pause | Button top-right | Escape | Start |

- No extra action exists. Steering and hopping are the whole vocabulary, for both run mode and race mode.
- Touch steering is relative drag (move finger left, car moves left), not a virtual joystick, because kids can use it without looking at a control.
- Touch targets anywhere in the UI are at least 44 pixels.

### Camera

**Delegated:** third-person chase camera, about 12 studs behind and 6 above the ridden car, tilted roughly 12 degrees down, with a small look-ahead so the next cars are visible. During a Hop the camera follows the avatar in the air with smoothing, never snaps. No camera roll. The only shake is a short, soft jolt on a crash. Field of view is fixed. The camera must never clip into traffic.

### The road

- Roads are 4 lanes wide (**Tunable**), one direction. **Decided:** all traffic goes the same direction as the player. No oncoming traffic.
- Roads are assembled from straight and gently curved prefab segments, streamed in ahead and recycled behind. Curves are mild so the camera stays readable.
- Side scenery per World is low-detail and decorative (buildings, rocks, trees). Nothing beside the road is interactive.
- Every 500 m (**Tunable**) is a **Milestone**: a chime, a distance banner, and a Cash bonus. Milestones are the run's rhythm and the natural place to escalate difficulty.

### Speed and difficulty curve

**Decided:** runs are endless until failure.

**Delegated curve:**

- Speed ramps from a comfortable starting speed to the World's top speed over the first 60 seconds (**Tunable**), then holds. The player's forward speed is the ridden car's speed; different families drive at slightly different speeds so hopping to a faster car visibly moves you up the road.
- Traffic density increases with distance until a cap that still leaves clear hop targets.
- Hazard frequency increases with distance.
- Rarer cars spawn more often the farther you go. Legendary and Variant cars are rare early and uncommon late.
- The three Worlds do not escalate in difficulty from one to the next (**Decided**: they are variations, not levels). Each World has the same curve shape with its own theme and roster.

### Traffic

- Cars are **kinematic** (moved by CFrame along lanes), not physics vehicles. No suspension simulation, no wheel friction. Bounces and sways are animated. This is the only way to have 15 to 20 cars on screen on a phone reliably, and it looks identical to the player.
- Each traffic car has a lane, a speed, and an occasional lane-change behavior with a visible indicator so lane changes are predictable. Traffic never brakes suddenly.
- Spawn ahead of the player, out of view; despawn behind. Maximum visible traffic is budgeted at about 18 cars (**Tunable** by performance testing).
- The car the player is riding is the same kind of object as traffic; hopping transfers the "ridden" state.

### The Hop

**Decided:** one tap to Hop, auto-targeted like Rodeo Stampede's lasso.

**Delegated details:**

- While riding, the game continuously picks a **Hop target**: the nearest car within Hop range in the direction the player is steering (straight ahead if not steering). A translucent ring sits under the targeted car so the player always knows where a tap will send them. No target in range: no ring, and tapping does a short hop in place that lands back on the same car (harmless, teaches the ring).
- On tap, the avatar visibly leaps out of the car in a readable arc (about 0.6 seconds, **Tunable**), lands on the target's roof, slides into the seat, and the target car bounces on its suspension. Small whoosh on launch, thump on landing. The old car drifts off into traffic.
- Mid-air steering nudges the landing a little for feel, but cannot retarget. If the target car changes lanes out from under you, you land on the road (see Foot Dash). This is the intended skill element: hop early when the ring is steady.
- Hop range is per family (the Long Jump family reaches farther).
- Closed cars hide the avatar once seated (tinted windows). Open vehicles (motorcycle, buggy, convertible) show the avatar riding.

### Foot Dash (landing on the road)

**Decided:** you can land on the road; it should not be too easy.

**Delegated rules:**

- Landing on the road starts a **Foot Dash**: the avatar sprints forward for up to 2.5 seconds (**Tunable**) at a speed slower than traffic, so cars come up from behind.
- During Foot Dash the Hop ring still works, and the player can hop onto any car in range (usually one passing alongside). A thin meter around the Hop icon shows the Foot Dash time left.
- The run ends if the Foot Dash timer expires or a car hits the avatar from behind. Being alongside a car is safe; being in front of one is not.
- A successful hop from foot gives a small "Nice save!" banner and a tiny Cash bonus, so the system reads as a skill moment rather than a punishment.

### Heat

**Decided:** every car overheats if ridden too long; Heat resets to zero on every Hop (each landing starts a fresh Heat timer on the new car). Bumping other cars adds Heat rather than ending the run.

**Delegated details:**

- Each car family has a **Heat Capacity** in seconds. Heat fills from 0 to 100% over that time while ridden.
- Stages:
  - **0 to 60%:** calm. Gauge visible but quiet.
  - **60 to 85%: Warning.** Gauge turns amber and pulses, engine rattle sound begins, small steam puffs from the hood, the Heat icon wobbles.
  - **85% to below 100%: Critical** (player label "Too hot!"). Gauge red, car shakes visibly, horn beep pattern. Still fully steerable. **Decided (0008):** red emphasis is localized to the ridden car and the Heat gauge; flashing speeds up toward 100% but never exceeds three flashes per second (a ceiling, not a target); a restrained red pulse is preferred to hard on/off flashing; never flash the whole screen or add a red full-screen overlay (this replaces v2.0's screen-edge heat shimmer). With reduced motion: steady red emphasis, a warning label or icon, and stripes; no flashing, shaking, or pulsing.
  - **100%: Meltdown** (player label "Losing control!"). **Decided (0008):** reaching 100% does not eject the player or end the run. The car becomes hard to control during a brief escape window; Hop stays available throughout; a Keys meter that completes during Meltdown still claims the car; if the player has not escaped when the window ends, the car crashes and the run ends; escaping clears the old car's Meltdown presentation and the new car's Heat resets as on every Hop. **Proposed, Tunable, owned by Lane 1 (Brian R):** a 3-second window, sluggish or delayed steering, increasing wobble and sideways drift, gradually falling speed, and a final spinout; controls are never inverted.
  - *Superseded (v2.0):* "100%: Blowout" with a 1.0 second Sputter window. Kept here only as history; see decision 0008.
- Color is never the only signal: shape (the gauge grows), motion (shaking), and sound all change with stage. At Meltdown the Heat bar becomes a labelled escape countdown that drains from full to empty, with a smoke icon and danger stripes, so it cannot be read as cooling down.
- **Bumps add Heat:**
  - Side scrape against another car: +15% Heat, sparks, a scrape sound. The car nudges apart.
  - Rear-ending a car ahead: +30% Heat, a jolt, and a brief slowdown that lets traffic behind close in. Not a run end.
  - Pothole: +10% Heat and a jolt (ignored by the Rugged family).
- Heat is paused during the "You got the Keys!" card and during the Hop arc.
- Heat is **off** in the Stunt Circuit.

### Claiming (Keys)

**Decided:** stay aboard an unowned model until claimed; claim time is a few seconds, a little longer for rarer cars; the car is owned permanently and immediately, before the run ends, regardless of what happens afterward.

**Delegated details:**

- Landing on an unowned model shows the **Keys meter** over the car (a key outline filling up). When full, the car is claimed instantly on the server, the card appears, and the Garage count updates.
- Claim time is by rarity, and every family's Heat Capacity is set so that even the Legendary claim completes with at least 3 seconds of Heat to spare if the player lands clean. A fair claim is always possible.
- Bumps during a claim add Heat but do not reset the Keys meter.
- A Keys meter that completes during Meltdown still claims the car (**Decided**, 0008).
- Only one car can be claimed per landing; hopping off resets the Keys meter for that instance.
- A full Speedway never blocks a claim. Claims go to the Garage; the Lineup is a separate choice.

### Joyride Bonus (duplicates)

**Decided:** completing the claim time on an already-owned model pays Cash.

**Delegated rules:**

- Each traffic car instance pays the Joyride Bonus **once**. Hopping off and back on the same car pays nothing. Heat makes camping impossible anyway.
- Bonus scales with rarity, and Variants pay more than base.
- The Joyride Bonus is validated by the server against the seeded traffic sequence like a claim.

### Road coins

**Delegated addition:** Cash coins appear on the road in lines, lane-switching ribbons, and arcs over ramps. They give steering a purpose between hops, make lane choice visible, and give the Magnet family a job. Coins are generated from the run seed and capped per run so the server can validate pickups. Coin value is small relative to Lap Pay so the Speedway stays the main earner.

### Hazards

**Decided:** potholes, oil slicks, construction, and gap jumps. All four exist in every World with themed visuals.

| Hazard | Downtown look | Dusty Highway look | Summit Pass look | Effect | Counter |
|---|---|---|---|---|---|
| **Pothole** | Cracked asphalt pothole | Sinkhole in sand-covered road | Frost crack | +10% Heat, jolt, brief wobble | Steer around; Rugged family ignores it |
| **Slick** | Oil slick | Sand drift | Ice patch | Steering is loose and the car slides for about 1 second | Stop steering until clear; Nimble family recovers faster |
| **Construction** | Barriers, cones, a crane arm over one lane | Rockslide boulders and road crew | Snowbank and plow debris | Blocks one or two lanes; hitting it head-on ends the run | Change lanes or hop over it; Plow family smashes through |
| **Gap** | Open drawbridge with a ramp lane | Washed-out canyon bridge with ramp | Collapsed mountain bridge with ramp | The road ends; one or two lanes have ramps; a car without a ramp falls and the run ends | Get into a ramp lane in time (big warning signs ahead), or hop to a car already on a ramp lane; Long Jump family can hop across to a car on the far side |

Hazard rules:

- Every hazard is signposted ahead with an icon sign and a road marking so there is reaction time at the World's top speed.
- Hazards never spawn inside the first 300 m of any run, and never in the tutorial run until after the first claim.
- Hazards never fully block all lanes; there is always a path.
- Construction and Gaps are the only run-ending hazards, and only on head-on contact or missing the ramp. Potholes and Slicks are Heat and control penalties.

### Run end, results, retry

**Decided:** retry is free; claimed cars are kept; no lengthy failure sequence.

- Run end causes: the Meltdown escape window expired with the player still aboard, Foot Dash expired or hit from behind, head-on hit on Construction, falling at a Gap.
- Failure presentation is under 2 seconds: a soft crash puff, the camera settles, and the **Results** panel slides up: Distance, Cars Claimed (with their cards), Joyride Bonuses, Coins, Milestones, Total Cash. New personal best distance gets a ribbon.
- Buttons: **Retry** (same World, new seed, instant) and **Go Home** (back to your plot gate). Missions that were completed during the run are shown as completed on this screen.
- Cash earned in a run is added to the balance as it happens (server-side) so a disconnect mid-run loses nothing already earned.

### Starting car

**Delegated:** every run in a World starts in that World's **Loaner** (its Common hatchback-type car) by default. Once the player owns other cars from that World, the Portal shows a **Start In** picker where they can choose any owned car from that World's roster to start in. This gives collecting an immediate use in runs and costs almost nothing to build. The Loaner is always available even when unowned, and claiming it works normally.

## 07 / Cars, families, rarities, variants

### Families and quirks

**Decided:** cars have run-affecting quirks per family.

**Delegated family set.** Eight families. Each World has one model per family (section 09), so a family's quirk is learned once and recognized everywhere.

| Family | Quirk name | What it does in a run | Trade-off | Heat Capacity (Tunable) | Avatar visible |
|---|---|---|---|---|---|
| **Compact** (hatchbacks, scooters) | **Nimble** | Fastest lane changes; recovers from Slicks in half the time | Shortest Heat Capacity | 8 s | Scooter yes, hatchback no |
| **Sedan** | **Steady** | Baseline everything; the easiest car to claim from | None, and no special strength | 11 s | No |
| **Pickup / 4x4** | **Rugged** | Potholes add no Heat and cause no jolt | Slightly slower lane changes | 11 s | No |
| **Van / RV** | **Cool Runner** | Longest Heat Capacity; the car to rest in | Slowest lane changes; biggest body to steer | 14 s | No |
| **Sports / Muscle / Rally** | **Long Jump** | Hop range is 50% longer; can reach cars across a Gap | Below-average Heat Capacity | 9 s | No |
| **Motorcycle** | **Slipstream** | Narrow body: can ride between two cars in adjacent lanes without scraping | Any bump is +25% Heat instead of +15% | 9 s | Yes |
| **Truck / Bus / Plow** | **Plow** | Smashes through Construction barriers and cones without ending the run | Slowest lane changes; cannot use Long Jump across Gaps | 12 s | No |
| **Special** (one per World) | **Magnet** | Pulls in road coins from nearby lanes | Average otherwise | 10 s | Depends on model |

Rules:

- Exactly one quirk per family. No stacking, no upgrades to quirks. Quirks are how the run plays, not a progression system.
- Quirks are explained on the car card with one icon and one sentence, and the first time the player rides a family, a one-line tip appears ("Rugged: potholes can't hurt this truck!").
- Quirks do not apply in the Stunt Circuit; races use the three race stats instead (section 10).

### Rarity

**Delegated:** four tiers so a child can hold them in mind.

| Rarity | Color / badge | Keys claim time (Tunable) | Lap Pay base (Tunable) | Joyride Bonus (Tunable) | Spawn tendency |
|---|---|---|---|---|---|
| **Common** | Grey badge | 3 s | $5 | $3 | Everywhere from the start |
| **Rare** | Blue badge | 4 s | $12 | $8 | Frequent after the first few hundred meters |
| **Epic** | Purple badge | 5 s | $30 | $20 | Occasional, more with distance |
| **Legendary** | Gold badge with sparkle | 6 s | $80 | $50 | Rare, mostly late in a run |

Each World's roster: Common for the Loaner and two others, three Rare, one Epic, one Legendary (section 09).

### Variants

**Decided:** Gold, Chrome, and Rainbow variants exist.

**Delegated rules:**

- A Variant is the same model with a different finish and a glow trail, so it is spotted from a distance in traffic. Gold: metallic gold with a sparkle. Chrome: mirror finish with a white gleam. Rainbow: slowly cycling hue with a rainbow trail.
- Variants only spawn for models the player **already owns** (base version). This keeps the first hours focused on the roster and makes old Worlds worth revisiting. Spawn chance rises with distance in a run.
- Claiming a Variant uses the base model's Keys time. It appears as a badge on the model's Garage card, and the model's card shows which of the three the player has.
- Variants pay more Lap Pay: Gold 2x, Chrome 3x, Rainbow 5x the model's base (**Tunable**).
- Variant Joyride Bonus is the base bonus times the same multipliers.
- Variants do **not** count toward World unlock requirements and do **not** change race stats or quirks. They are prestige and income only.
- Rainbow is deliberately very rare. Seeing one in traffic should be an event; a short sparkle sound plays when one spawns in view.

### Car construction standard

- Built from parts (and MeshParts when a teammate models them), roughly 20 to 40 parts per car, no unions. Flat colors, SmoothPlastic and Metal materials, dark tinted glass. Oversized wheels (about 1.3x realistic), short wheelbases, rounded block bodies. A car must be identifiable by silhouette at run distance and attractive on a Speedway turntable.
- One shared rig: body, four wheels that spin, a seat anchor for the avatar, a headlight pair, and attachment points for the Heat steam, Hop ring, Keys meter, and Variant trail. Every car uses the same rig so one script handles all of them.
- Fictional names with personality ("Pip", "Boxcar Bertha", "Nitro Fox"). Names and silhouettes are **Open** for the team to approve from a proposal list before modeling starts.

## 08 / Garage, Speedway, and the economy

### Garage (collection)

- Opens from the Garage building or the Garage button, available everywhere except mid-run.
- Tabs per World. Each World shows its 8 models as cards: owned cards are full color with the car on a turntable; unowned cards are a dark silhouette with the name hidden ("???") and the rarity badge visible, so kids know what rarity they are missing.
- Card detail: name, rarity, family and quirk (one line), Lap Pay with Variant multipliers, race stats (three bars), Variants owned (three badges), where it is found (World), and a **Put on Speedway** button if a Slot is free or a **Swap** button if not.
- A collection counter in the header: "17 / 24 cars, 4 Variants".

### Speedway (home track)

**Decided:** owned cars drive laps and pay a lump sum per lap; rarer cars pay more per lap; Cash goes straight to the balance.

**Delegated details:**

- The Speedway is a stadium-style oval on the plot. Lineup cars drive laps continuously in a staggered line so payouts arrive at different moments. Lap time is about 15 seconds for every car (**Tunable**); all cars lap at the same speed so the Speedway never implies race performance. Speed and spacing are purely visual pacing.
- Each finish-line crossing pays that car's **Lap Pay**, which is: base by rarity × Variant multiplier × Income Tier multiplier (× 2 with the Double Lap Pay pass). The amount pops above the car in big friendly numerals and flies to the Cash counter with a soft cash chime. This is the game's heartbeat; it must feel good every time.
- Lap Pay is computed and credited on the **server** on a timer per car, not by watching the model cross a line. The visual is driven by the same timer so they match.
- The Speedway keeps earning while the player is anywhere in the server, including mid-run. The player returns from a run to a bigger balance.
- A **Lineup** panel (from the Paddock kiosk or the Garage) shows Slots as parking bays. Tap an empty bay to pick a car; tap a filled bay to swap. **Decided:** one of each owned model at most. A bay holding a model displays whichever owned Variant the player picks, defaulting to the highest-paying one.
- When a new model is claimed and a Slot is free, it is added to the Lineup automatically with a toast ("Pip joined your Speedway!"). The tutorial's manual first placement is the exception so the player learns the panel.

### Upgrades

**Decided:** most spending improves the Speedway; income upgrades never affect racing.

Two upgrade ladders, both bought at the Paddock kiosk with clear "what you get" previews:

**Slots (capacity).** Start with 3 Slots. Each purchase adds one Slot and one visible parking bay; every third Slot also extends the Paddock with a new pit garage building so the plot visibly grows. Maximum 12 Slots at launch (**Tunable**), plus 3 more from the Expanded Paddock pass (section 12). Prices rise with each Slot.

**Income Tier.** Five tiers (**Tunable**). Each tier multiplies all Lap Pay on the plot and changes the plot's look so neighbors can read progress from the plaza:

| Tier | Multiplier (Tunable) | What appears on the plot |
|---|---|---|
| 1 | 1.0x | Dirt oval, rope fence, a lemonade stand |
| 2 | 1.5x | Paved track, painted lanes, small bleachers, a flag line |
| 3 | 2.25x | Floodlights, a covered grandstand, a start-finish gantry |
| 4 | 3.4x | Pit building, a big screen that shows the Lineup's names and Lap Pay, crowd sound |
| 5 | 5.0x | A stadium roof section, fireworks on every Legendary lap, a champion statue of the player's rarest car |

**Decorations** (cosmetic plot items for Cash) are **Deferred** to a post-launch update; the Income Tier visuals carry the "show progress" job at launch.

### Offline earnings

**Decided:** restricted offline earnings exist.

**Delegated rule (time cap plus reduced rate):**

- While the player is away, the saved Lineup earns at **50%** of its online Lap Pay rate for up to **8 hours** (**Tunable**). The VIP pass raises the cap to 12 hours.
- On the next join, the server computes elapsed time from the saved last-seen timestamp, credits the amount immediately, and stamps the new last-seen so the same hours can never be paid twice. A rejoin within the same server session pays nothing extra.
- Presentation: a **Welcome back!** card shows the Lineup cars doing a quick lap with the total rolling up. One tap closes it. The Cash is already in the balance when the card appears, so a disconnect cannot lose it.
- Offline earnings respect the Double Lap Pay pass and the Income Tier.

### Currency and sinks

**Delegated:** one currency, **Cash ($)**. No second currency at launch, including for racing. Race rewards pay Cash and cosmetics.

| Source | Sink |
|---|---|
| Lap Pay (main) | Slots |
| Offline earnings | Income Tiers |
| Claims (small Cash on each new claim) and Joyride Bonuses | World unlocks (Cash part) |
| Road coins and Milestones | Paint colors, decals, wheels (section 10) |
| Missions and Goals | (Deferred: decorations) |
| Stunt Circuit finishes and medals | |

### Pacing targets (Tunable, for the first playtest only)

These describe the feel we are aiming for, not approved numbers:

- First Slot purchase affordable at the end of the first or second run.
- All of Downtown's Common and Rare cars claimed within roughly the first 30 to 45 minutes of play.
- Dusty Highway unlock reached after about 1.5 to 2 hours of total play across sessions.
- Summit Pass unlock after a further 2 to 3 hours.
- Income Tier 5 and 12 Slots are long-term goals measured in weeks of casual play, not hours.
- Offline earnings for a typical mid-game Lineup should feel like a nice bonus (roughly one or two Slots' worth of progress overnight), never a reason not to play.

A spreadsheet model of early, typical, and extreme progression will be built before the first economy tuning pass. No price in this document is final.

## 09 / Worlds

**Decided:** three Worlds at launch, variations rather than escalating difficulty: a city, a desert highway, and a mountain pass. Unlock requires Cash plus a number of cars owned from the previous World. Any unlocked World is directly enterable from its Portal.

### World roster template

Each World has 8 models, one per family. Rarity per family slot is fixed so every World has the same shape: Compact (Common, the Loaner), Sedan (Common), Pickup (Common), Van (Rare), Motorcycle (Rare), Truck (Rare), Sports (Epic), Special (Legendary). The Legendary is the World's signature car and uses the Magnet quirk.

### World 1: Downtown

- **Look:** a sunny cartoon city. Teal sky, warm grey asphalt, coral and mint block buildings, yellow crosswalk stripes, billboards with fictional ads. Lots of 90-degree shapes.
- **Hazards:** potholes, oil slicks, construction zones with cones and a crane arm, drawbridge gaps.
- **Roster (proposed names, Open for approval):** Pip (Compact hatchback, Loaner), Comet Cab (Sedan taxi), Haul Buddy (Pickup), Boxcar Bertha (Van, delivery van), Zippy (Motorcycle scooter), Big Red (Truck, city bus), Nitro Fox (Sports coupe), Stretch (Legendary stretch limo with a disco roof).
- **Music:** upbeat brass and bouncy bass.
- **Unlock:** available from the start.

### World 2: Dusty Highway

- **Look:** desert road at golden hour. Orange sand, dusty blue sky, red rock arches, cream-colored road, cacti and tumbleweeds, a roadside diner or two.
- **Hazards:** sinkholes, sand drifts, rockslide crews, canyon bridge gaps.
- **Roster (proposed):** Dusty (Compact dune buggy, Loaner), Mirage (Sedan muscle sedan), Rattler (Pickup lifted 4x4), Roadhouse (Van camper RV), Sidewinder (Motorcycle chopper), Longhaul (Truck big rig), Scorch (Sports muscle car), Thunderfoot (Legendary monster truck).
- **Music:** twangy guitar and hand claps.
- **Unlock (Tunable):** Cash cost plus **5 of 8** Downtown models owned (Variants do not count).

### World 3: Summit Pass

- **Look:** bright alpine morning. White snow, deep blue sky, pine green, grey asphalt with ice patches, wooden chalets, a ski lift crossing overhead.
- **Hazards:** frost cracks, ice patches, snowbank and plow debris, collapsed mountain bridge gaps.
- **Roster (proposed):** Flurry (Compact ski shuttle, Loaner), Glacier (Sedan station wagon), Yeti (Pickup snow 4x4), Lodge (Van ski-resort shuttle), Frostbite (Motorcycle snow bike), Avalanche (Truck snowplow), Blizzard (Sports rally car), Aurora (Legendary luxury SUV with a glowing roof rack).
- **Music:** bells, strings, and a steady kick.
- **Unlock (Tunable):** Cash cost plus **5 of 8** Dusty Highway models owned.

### Portal rules

- Locked Portal: chained gate, two requirement rows with live progress ("$3,200 / $5,000" and "3 / 5 Dusty Highway cars"), and a **Peek** button that shows the World's roster silhouettes.
- Unlocked Portal: open gate with the World's lighting spilling out, the **Start In** car picker, and a **Go** button. Entering is instant (same place, StreamingEnabled).
- A World, once unlocked, is never re-locked.

### Future Worlds

Adding a World means: one road segment set, one scenery set, eight cars, one music track, four hazard skins, and a Portal. No new systems. This is the content pipeline for updates (**Deferred** examples: Boardwalk, Night City, Jungle Road).

## 10 / Stunt Circuit (obstacle racing)

**Decided:** racing is in the first release; players pick one owned car; same steer-and-hop controls; modest car performance differences with skill still mattering; no ramming; rewards can include cosmetics.

### Format at launch

**Delegated:** the launch race is a **ghost time trial**. You race the course alone against up to three translucent ghosts of other players' recorded runs, so you are competing against real people without needing a full lobby, a countdown, or any disconnect handling. Live multi-player lobbies are the first post-launch update (section 14 keeps their spec). This choice keeps "racing against other players at launch" while removing the largest multiplayer risk from the first release.

### The course

- One course at launch: **Stunt Circuit**, a single lap of roughly 60 to 90 seconds (**Tunable**) through a stadium-and-city setting that reuses Downtown's art.
- Sections, in order: slalom barriers, a ramp over a gap, a tunnel with potholes (slow you, no Heat), swinging arms that sweep across the road, a narrow bridge, a double ramp, the finish straight.
- Checkpoints about every 15 seconds. Hitting a wall hard, falling, or missing a ramp resets you to the last checkpoint after a 1 second fade while the clock keeps running. Failure is always recoverable; the penalty is time.
- Every obstacle has a warning sign and the same visual language as run hazards so nothing has to be re-learned.
- Heat is off. Quirks are off.

### How the car matters

**Delegated:** three stats, each shown as 1 to 5 pips on the car card:

- **Speed:** top speed on straights.
- **Jump:** how far and high the whole car hops (the car hops in races; the avatar stays seated).
- **Grip:** how quickly steering responds and how well the car holds on ramps and the narrow bridge.

The fastest car in the game is about 15% faster than the slowest (**Tunable**). Rarity nudges stats up, but every car has a weakness, and a Common with a clean run beats a Legendary that hits three walls. Stats are fixed per model; there is no tuning or upgrading cars (**Deferred** permanently unless the team changes direction).

### Ghosts

- Your own best run is always shown as a ghost.
- Up to two more ghosts: the next-faster time above yours on the weekly board, and a friend's best if a friend has a time.
- Ghosts are recorded as position and rotation samples at 10 per second, compressed, and stored with the time. Top times on the weekly board store their ghost data server-side so other servers can play them back. If shared ghosts prove troublesome in testing, the fallback is your own ghost plus fixed medal times, and the design still works.

### Rewards and farming prevention

- Every finish pays a small Cash reward. The first 5 finishes each day pay full; later finishes pay 25% (**Tunable**). This keeps racing rewarding without making it the best money in the game.
- **Medals** by time: Bronze, Silver, Gold. Each medal pays a one-time Cash bonus **per car**, so there is a reason to race every car you own once, and no way to farm.
- Beating your personal best pays a bonus.
- **Cosmetics** (Decided as possible, Delegated specifics): racing-exclusive paints and decals unlock from medal milestones ("Gold with 5 different cars unlocks the Checkered Flag decal"). These can never be bought, so they signal skill.
- A weekly leaderboard (OrderedDataStore) resets every Monday. Top placements earn a seasonal decal (**Tunable** count).

### Customization

**Decided:** the race area supports selecting and customizing cars.

**Delegated scope at launch:**

- **Paint:** 8 free basic colors, 8 premium colors for Cash, plus medal-unlocked paints. Paint applies to the car everywhere (runs, Speedway, races).
- **Decals:** a small set of stickers (numbers, stripes, flames) for Cash or from medals.
- **Wheels:** 3 wheel styles for Cash.
- Customization is cosmetic only. Nothing affects stats.
- The customization screen is a turntable with the car, three tabs, and a big **Equip** button, usable from the Stunt Circuit gate and from the Garage card.

### Low population

Ghost racing means the mode is complete with one player online. There is no queue and no waiting.

## 11 / Missions and Goals

**Delegated:** yes, lightweight, at launch. This is the main source of short-term direction after the tutorial.

- **Missions:** 3 active missions shown on a small side panel (collapsible on phone). Generated from templates scaled to the player's current World: "Hop 15 times in one run", "Claim a Rare car", "Reach 1,000 m in Dusty Highway", "Earn $500 from Lap Pay", "Finish the Stunt Circuit in a Van", "Ride a Plow through 3 construction zones". Completing one pays Cash and is replaced instantly. All three refresh daily if untouched. No mission currency.
- **Goals:** a one-time milestone list that acts as a long-term checklist: own 5 cars, own every Downtown car, claim your first Variant, reach Income Tier 2, earn a Bronze medal, unlock Dusty Highway, and so on. Each pays Cash once.
- Missions and Goals never require racing to progress in collecting, and never require collecting to progress in racing; they offer both.
- A **daily bonus** (small Cash for the first run each day) is cheap and **Open** to the team; it is not required by the design.

## 12 / Monetization

**Decided:** game passes from the start.

**Delegated pass set (prices Open):**

| Pass | What it does | What it never does |
|---|---|---|
| **Double Lap Pay** | 2x Lap Pay online and offline | Does not change race stats, Heat, or Keys |
| **Expanded Paddock** | +3 Slots above the normal maximum, with a visible extra pit garage | Does not change income per car |
| **VIP** | Exclusive VIP Pearl paint set, a VIP name tag, a VIP lounge building on the plot, offline cap raised to 12 hours | No gameplay advantage in runs or races |

Rules:

- No paid randomness, no loot crates, no luck products of any kind.
- No Developer Products (Cash packs) at launch. **Open** to the team for later; if added, they must respect per-player policy checks.
- Passes are checked server-side on join and on purchase; granting is idempotent.
- Current platform policy and this account's publishing eligibility must be verified before launch. Nothing here assumes eligibility.

## 13 / Art direction, UI, audio, feel

### Visual system

- **Style:** chunky block cartoon. Rounded blocks, big wheels, flat saturated colors, thick dark outlines on UI, no realistic textures. Every World gets its own palette (section 09) while cars, UI, and effects stay consistent.
- **Lighting:** bright daytime in every World; no realism, no heavy post-processing. One lighting preset per World with a matching skybox. Mobile-safe settings (no expensive shadows on traffic).
- **Readability first:** the ridden car, the Hop ring, hazards, and Variant trails get the strongest contrast on screen. Scenery is lower saturation than the road.
- **Avatar:** the player's own Roblox avatar, so kids see themselves. It is hidden in closed cars by tinted glass and visible on open vehicles.

### UI system

- One font, one panel style (cream card, navy text, rounded corners, soft drop shadow), one accent color per action type (orange for go/buy, green for success, red only for danger).
- Big buttons, icon-first labels, numbers large. Minimum 44 px touch targets. Nothing important lives in a corner that a thumb covers on a phone.
- HUD in a run: Cash (top left), Distance (top center), Heat gauge (bottom center, grows with stage; at Meltdown it becomes the escape countdown), Keys meter over the target car, Hop icon (bottom right on touch; hidden on keyboard). Nothing else.
- Every screen is reviewed at phone portrait, phone landscape, and 1080p desktop in Studio's emulator before it is called done.

### Audio

- Music: one loop per World plus an island loop and a Stunt Circuit loop. Volume ducks under fanfares.
- Key sounds, all short: Hop whoosh, landing thump, Keys tick as the meter fills, "You got the Keys!" fanfare (the most satisfying sound in the game), Heat rattle rising by stage, horn beeps at Critical, Meltdown cough and sputter, Lap Pay chime, Milestone chime, Variant sparkle, medal fanfare.
- No sound carries information alone; every cue pairs with a visual.

### Game feel rules

- Hop arc, landing bounce, and camera follow are tuned first and protected from later changes.
- Effects are restrained: steam, sparks, a cash pop, a sparkle trail. No screen-filling particles. Performance budget before spectacle.
- Failure is soft: a puff, a settle, the Results panel. Never a long death animation.

## 14 / Technical shape (architecture level)

This section describes the shape of the implementation so the design and the code agree. Details live in AGENTS.md and the repository.

- **Toolchain:** Rojo-controlled source, strict Luau, Wally packages, Rokit, Studio for testing. Rojo files are the only source of truth for scripts.
- **Single place** with StreamingEnabled: island, run zones per player, Stunt Circuit.
- **Catalog module:** one data module lists every car (id, name, World, family, rarity, Lap Pay base, race stats, model reference, Variant finishes), every World (roster, hazard skins, unlock requirements, music), every upgrade price, and every mission template. Design changes are catalog edits, not code edits.
- **Server authority:** Cash, ownership, Lineup, upgrades, World unlocks, Lap Pay timers, offline computation, medals, passes, leaderboards. The client simulates the run and reports events; the server validates against the run seed.
- **Save data (ProfileStore):** Cash, OwnedCars (model id → owned Variants), Lineup (Slot → model id and chosen Variant), Slots, IncomeTier, WorldsUnlocked, TutorialDone, Missions (active and progress), Goals completed, RaceBests per car, Medals per car, Cosmetics owned and equipped per car, LastSeen, Passes, Settings. Schema versioned from day one; tested with ProfileStore.Mock before any live DataStore use.
- **Remotes:** every remote validates types, ranges, ownership, and rate limits. No remote grants anything directly.
- **Cross-server data:** OrderedDataStores for the two leaderboards; a DataStore for top ghost recordings.
- **Performance budgets (Tunable):** about 18 visible traffic cars, 20 to 40 parts per car, 30 fps target on a mid-range phone with StreamingEnabled, no physics vehicles.
- **Deferred live racing lobbies:** when added, use a race manager with a queue, a start countdown, server-replicated positions, checkpoints, and disconnect handling that awards a finish at the last checkpoint. The design in section 10 already keeps the course and stats compatible.

## 15 / Production plan (stages, not dates)

**Decided:** no deadline. The stages exist to order the work so each layer is proven before the next depends on it. Every stage ends with the checks listed.

**Stage 0: Foundation.** Repo rules confirmed, catalog module skeleton, save schema v1 with Mock tests, island greybox with 12 plots, Portal row, Garage building, Stunt Circuit gate as placeholders. Check: a player joins, gets a plot, saves and loads an empty profile.

**Stage 1: Run prototype.** Downtown road segments, kinematic traffic, chase camera, steer and Hop with the target ring, Foot Dash, Heat with stages, three placeholder cars from three families with their quirks. Check: ten minutes of play feels fun to the team; landing misses are understandable; phone emulator playable.

**Stage 2: Claiming and keeping.** Keys meter, server validation from the run seed, permanent ownership, Joyride Bonus, Results panel, Retry and Go Home, road coins, Milestones. Check: a claim survives a crash and a rejoin; a duplicate pays once per instance; forged events are rejected.

**Stage 3: Speedway and economy.** Lineup, Lap Pay timers, Slots and Income Tiers with visuals, Paddock kiosk, Garage UI, offline earnings, plot visiting and car cards. Check: Lap Pay matches the visual; offline never double-pays; a full Speedway never blocks a claim; neighbors can read progress.

**Stage 4: Worlds and Variants.** Full Downtown roster of 8, Dusty Highway and Summit Pass with hazards, rosters, music, Portal locks and requirements, Start In picker, Variants with trails and multipliers, Missions and Goals. Check: unlocks compute correctly; Variants spawn only for owned models; each World reads as its own place.

**Stage 5: Stunt Circuit.** Course, checkpoints, race stats, ghost recording and playback, medals, finish rewards with daily taper, customization screen, weekly leaderboard. Check: a Common can beat a Legendary with better driving; ghosts play back correctly from another server; farming is capped.

**Stage 6: Tutorial, passes, polish, release.** Tutorial flow with assists, all audio, lighting per World, UI review at all target sizes, game passes with server checks, policy and eligibility verification, performance pass on a phone, analytics events for first claim, first lap, first upgrade, first unlock, first race. Check: a new player completes the tutorial unaided; the full release checklist passes with evidence.

### What must be proven (the test list)

- A newcomer performs the first Hop and understands why the claimed car matters within the tutorial.
- Landings are readable; a miss is traceable to the ring moving or a late tap.
- Every rarity can be claimed with Heat to spare from a clean landing in every family.
- Reaching 100% Heat starts a Meltdown, not an immediate run end; a Hop during Meltdown escapes and clears its presentation; a claim completing during Meltdown is granted; the run ends only when the escape window expires.
- Critical and Meltdown flashing stays localized and at or under three flashes per second; with reduced motion there is no flashing, shaking, or pulsing, and danger still reads.
- A claim survives crash, disconnect, and rejoin; a full Speedway never blocks ownership.
- Joyride Bonus pays once per car instance; offline earnings never pay the same hours twice.
- Lap Pay numbers on screen equal the server's credits.
- Income Tiers change the plot visibly and never change race results.
- Portals route to the intended World; unlock requirements count base models only.
- Stunt Circuit rewards skill, recovers from every failure, and works with one player online.
- Phone portrait and landscape and 1080p desktop are all readable and playable.
- Passes grant correctly, idempotently, and only what they promise.

## 16 / Deferred (visible, not forgotten)

- Live multi-player race lobbies (first post-launch update).
- Plot decorations for Cash.
- Console support and controller focus testing.
- Additional Worlds, additional race courses.
- Developer Products (Cash packs).
- Daily login streaks beyond the optional daily bonus.
- Ghost runners of other players visible during collection runs.
- Trading, stealing, breeding or merging, car tuning, ranked seasons, second currencies: not planned at all unless the team changes the game's identity.

## 17 / Open decisions (owner or team)

1. Final title (Car Hop proposed) and Roblox name availability.
2. Team role split (owner wants to decide this with Claude later).
3. Approval of the proposed car names and silhouettes before modeling.
4. Game pass prices.
5. Whether to add Developer Products later, and the optional daily bonus.
6. Publishing eligibility and current policy verification for this account.
7. Server size confirmation after the first multiplayer test (12 proposed).

## 18 / Decision log for this revision

**Decided by the owner, 18 October 2026:** concept selected; phone and PC; no deadline; cars have family quirks; one-tap auto-targeted Hop; landing on the road allowed and should not be too easy; endless runs; Heat resets on every Hop; claim time a few seconds, longer for rarer cars; same-direction traffic with potholes, oil slicks, construction, and gap jumps; bumps add Heat instead of ending the run; Gold, Chrome, and Rainbow Variants; lump-sum Lap Pay per car scaled by rarity, straight to balance; visitors can walk on any Speedway but change only their own; two or three Worlds as variations (city, desert, mountain pass); World unlocks need Cash plus cars from the previous World; race rewards may include cosmetics; game passes from the start.

**Delegated to Claude and chosen in this revision (all reversible):** working title Car Hop; cartoony-cool tone; 12-player servers and a ring-of-plots island; the tutorial sequence and assists; private client-simulated runs validated by a server seed; single place with streaming; chase camera spec; Foot Dash rules; Heat stages and bump values; eight families and their quirks; four rarities; Variant spawn-only-if-owned rule and multipliers; road coins; Milestones; Start In picker; Speedway lap pacing and auto-add; Slot and Income Tier ladders with visuals; offline at 50% rate with an 8-hour cap and a welcome-back card; single currency; three Worlds with proposed rosters; ghost time trial racing at launch with live lobbies deferred; three race stats with a 15% top-speed spread; medals per car and daily reward taper; customization scope; Missions and Goals at launch; the three-pass set; art, UI, and audio direction; staged production plan.

**Decided by Adam, 19 October 2026 (v2.1, decision 0008):** Critical uses localized red emphasis with a three-flashes-per-second ceiling and a reduced-motion form; 100% Heat starts a Meltdown escape window instead of a Blowout and Sputter. Meltdown driving details are Proposed and Tunable, owned by Lane 1.

## 19 / References

- Rodeo Stampede, riding and taming: https://rodeostampede.zendesk.com/hc/en-us/articles/4832109289887-Core-Gameplay-Riding-and-Taming-Wild-Animals
- Rodeo Stampede, zoo and progression: https://rodeostampede.zendesk.com/hc/en-us/articles/4832099137567-Your-Sky-Zoo-Build-Your-Animal-Empire
- Publisher overview: https://www.yodo1.com/rodeo-stampede

These informed the comparison only. No statistic, ranking, or commercial prediction is established by them, and nothing in this document is a verified claim about Rodeo Stampede's exact rules.

### Maintaining this document

When the team approves a change, update the live GDD and decision register in the repository first, then refresh this file and the copy uploaded to Claude. Version and date the header every time.
