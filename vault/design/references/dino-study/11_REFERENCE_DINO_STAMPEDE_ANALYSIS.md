# Reference analysis: dinosaur-catching Roblox game (video, 22 Oct 2026)

Source: a 60-second screen recording Adam shared of a Roblox game where you jump between running dinosaurs, tame them, and bring them back to a base where they earn money. It is the closest existing game to Car Hop (dinosaurs instead of cars). This file records everything visible in the video that we could learn from, how it maps to Car Hop, who on the team owns it, and whether to adopt, adapt, or avoid it.

Rules for using this file:
- Copy ideas and qualities, never assets, names, logos, exact layouts or text.
- The video is 60 seconds of one player. Anything not clearly visible is marked "(unclear)".
- Our own look rules still win: no Roblox studs, nothing blocky, bright stylized world, semi-realistic parody cars. This game is built from studded voxel blocks; learn from its layout and feel, not its art style.
- Anything that changes how the game works or what it costs is a proposal for the team, not a decision.

Owner key: **L1** = Brian R (driving, run, physics, camera). **L2** = Brian L (data, economy, cars). **L3** = Adam (world, UI, feel). **Team** = needs agreement.

---

## 1. The core loop, side by side

| Their game | Car Hop equivalent |
|---|---|
| Walk into the "Dino Machine" at your base to start a run | Walk into a World portal |
| A stampede of dinosaurs runs forward across a wide valley | Traffic drives forward down a Downtown road |
| Jump from dino to dino; throw a lasso at the next one | Hop from car to car with the target ring |
| Stay on a new dino while a taming meter fills: "IT'S YOURS!" | Stay aboard while the Keys meter fills: "YOU GOT THE KEYS!" |
| Each dino needs a minimum Stamina; too little and it throws you off ("STOMPED!") | Heat ends a run; there is no per-car requirement yet (see proposal 6.1) |
| Caught dinos go into a "SECURED" list and a hotbar | Claimed cars go to the Garage and Results |
| Run ends, you're sent home: "GREAT RUN!" | Results panel, Retry or Go Home |
| Dinos live in a pen at your base and earn money per second | Cars drive your Speedway and earn Lap Pay |
| Distance-based biome bar: Plains, Forest, Desert ... Cosmic | Our Worlds are separate portals; districts inside a run could use the same bar |

The game proves the loop works on Roblox. Car Hop's differences (permanent cars, laps, three Worlds, the Stunt Circuit) stay.

---

## 2. Run mechanics (physics and feel)

### 2.1 Jumping between rides (L1)
- **What happens:** while riding, the player presses Space (or the big round on-screen button) and leaps in a long, floaty arc toward another animal. Arcs are generous; the player covers wide gaps easily. On landing, the player snaps onto the animal's back in a riding pose.
- **Target marking:** the next possible target gets a **dashed, glowing yellow ring on the ground around it**, which pulses. Only one target is marked at a time.
- **Lasso:** while riding, a yellow lasso loop swings above the player's raised hand, pointing toward the next target. It telegraphs "you can jump now" and where you'll go.
- **On-screen button:** a large round button at the bottom right with an arrow and a "Space" label under it. Its arrow changes direction with context (up arrow, sometimes down arrow; the exact meaning is unclear, possibly jump versus drop down).
- **Car Hop use:** adopt the ground target ring (we already have a teal Hop ring; make it a pulsing dashed ring like this), the generous forgiving arc, and a "ready to hop" telegraph. Our version of the lasso could be a glowing arc preview line from the car you're on to the target car, or the avatar pointing toward it. **Adapt.**

### 2.2 Taming meter (L1 logic, L3 look)
- **What happens:** right after landing on a new dino, two small round meters appear beside the rider at screen center: a larger pie ring filling green and a small pink ring (likely a timer or the dino's resistance; unclear). Once the green ring fills: a hearts burst, sparkles, and a banner on the left: dino icon, "IT'S YOURS!", the dino's name, and "Keep going!".
- **The run never pauses.** The celebration is a side banner, not a blocking card.
- **Two-step confirmation:** right after "IT'S YOURS!" the left counter reads "0 SECURED"; about a second later it reads "1 SECURED" with the dino's icon. So a catch is first "tamed", then "secured" (unclear whether securing needs a timer or a safe moment). This matches our pending-then-confirmed Keys states (the server confirms the claim).
- **Car Hop use:** this confirms our Keys ring placement next to the rider and the phone "ribbon" celebration from the HUD prototype. Add the hearts and sparkle burst equivalent (keys, confetti, stars) and a "Keep going!" line so players don't stop. **Adopt.**

### 2.3 Requirement gate and getting thrown off (L1 logic, L2 numbers, L3 look): the "stamina" mechanic
- **What happens:** every dino shows "Required: ⚡10" (or 8, 12, 60, 160) under its name. The player's Stamina is shown bottom left (20 in the video). If you jump onto a dino that needs more Stamina than you have:
  1. A red "!" warning triangle and small red text "Not enough stamina" pop above you.
  2. The dino flashes and tints **red** while you're on it, a clear "this is about to go wrong" signal.
  3. After a moment it bucks you off. You fly off in a tumble.
  4. A big banner: "STOMPED!" with the reason underneath: "Stamina 20 / 60 needed".
  5. The run ends and you're returned to base.
- The "Not enough stamina" text with a red ring also appears while the player is riding a dino they already tamed, aimed at the next target. It may mean "you can't ride the one you're aiming at", or that Stamina drains while riding (unclear from 60 seconds).
- **Why it's good:** the failure is always explained (this matches our design pillar "readable danger"). Players instantly learn "I need more Stamina for the big ones", which drives upgrades.
- **Car Hop use:**
  - **Adopt now (feel, L1 + L3):** the warn-then-eject sequence. Before any forced dismount (for example full Heat), flash the car, show a "!" and a short reason, then throw the player off with a tumble, then a big reason banner ("TOO HOT!" plus "Heat full"). Never end a run without showing why.
  - **Propose (Team):** a per-car requirement gate like this. See proposal 6.1.

### 2.4 Riding and getting knocked off (L1)
- Riding pose: the avatar sits on the animal's back, one arm raised with the lasso. The animal keeps running; the camera stays behind and above.
- Getting thrown: the avatar is launched sideways and tumbles (ragdoll-like). No screen shake was visible.
- **Car Hop use:** adopt a fun, cartoon tumble when thrown off (kid-friendly, no harsh impact), and a clear riding pose for open vehicles. **Adopt.**

### 2.5 Herd movement (L1)
- Dinos run forward in loose groups at different speeds, kicking up **dust trails** behind them. Bigger dinos are slower and spaced out; small ones dart around.
- **Car Hop use:** traffic in loose packs with different speeds per car family, plus exhaust and road-dust puffs behind cars so motion reads at a glance. **Adopt.**

### 2.6 Camera (L1)
- A high third-person chase camera behind and above the rider, wide field of view, looking slightly down so you see several targets ahead at once.
- **Car Hop use:** confirms a high, wide chase camera that shows upcoming cars. Our Downtown studies used 12 behind, 6 up, 12° down, FOV 70; consider testing higher and wider like this. **Adapt.**

---

## 3. HUD (L3)

Layout seen in the video (desktop window, mobile controls visible):

| Position | Element | Notes for Car Hop |
|---|---|---|
| Top center | **Biome progress bar**: ten tiles (Plains, Forest, Desert, Jungle, Snow, Giant Forest, Abyss Ocean, Volcano, Extinction, Cosmic), the player's avatar head sliding along under it, and the distance under the head ("905 m") | Great progress feel. Use a district strip for each World run (see 4.1). |
| Top center, under the bar | **Zone banner** when entering a new zone: a slim dark bar with an icon and the zone name ("Forest") | Adopt for districts and landmarks. |
| Top center, at base | **Instruction banner**: "Walk into your Dino Machine to jump on!" | Matches our tutorial banner. |
| Over every animal | **Nameplate**: size tag (TINY, BIG, GIANT, SILVER), a red "new!" tag if you've never caught it, the rarity word in its color (Common white, Uncommon green, Rare blue), the name, and "Required: ⚡10" | Adopt: car nameplates over traffic (rarity, name, NEW! if not owned, Variant tag like GOLD or CHROME). Keep them small and fade with distance. |
| Large, lower screen | **Big rarity reveal** text when a notable animal is nearby ("Common / Pachycephalosaur / Required ⚡10"; "new! Rare Velociraptor") | Adapt: a short reveal when a Rare or better car appears, so players notice chances. |
| Bottom left | Stamina (lightning icon, 20) and Cash (money icon, $654) in dark translucent cards | Our Cash stays top left (approved reference). |
| Left, mid | **"SECURED" counter** with icons of caught animals | Adapt: a small "claimed this run" tray during runs. |
| Bottom center | **Hotbar** of 7 slots (Q key) showing caught animals | Not needed for Car Hop. |
| Bottom right | **Timed world events**: a meteor icon "in 5m 29s" and a moon icon "in 4m 13s" | See proposal 6.3. |
| Bottom right | Big round jump button with "Space" label | Matches our Hop button. |
| Right edge | Square paw button (likely the collection index) | Our Garage button covers this. |
| Center, at run end | "STOMPED!" reason banner, then at base "GREAT RUN!" with "Loading..." | Adopt the reason banner; our Results panel is richer. |

HUD lessons:
1. **Information lives on the world, not just the screen.** Names, rarity and requirements float over the animals themselves. Kids read the target, not a corner.
2. **Every failure has a reason line.**
3. **Celebrations never block play** during a run.
4. The bottom-heavy layout works on phones because the top is used only for progress. Keep our thumb zones clear the same way.

---

## 4. Map and world building (L3)

### 4.1 The run map
- A **very wide open valley** (much wider than a road) bounded on both sides by tall cliff walls, so players can't leave but don't feel boxed in. The ground is flat with gentle rises.
- Scenery is sparse near the center (room to see and jump) and denser toward the walls: trees, rocks, crates, bushes.
- **Bunting**: long strings of colorful pennant flags strung across the whole valley at intervals. They mark progress and look festive.
- **Biome changes by distance**: the ground and props shift as you go (Plains to Forest), announced by the zone banner and the top bar.
- **Car Hop use (Downtown):**
  - Keep the road wide with generous room between lanes for hopping, and keep the area around the road clear of clutter; put density at the edges (buildings, trees).
  - String **banners and bunting across the road** at intervals (city festival banners, "WELCOME TO DOWNTOWN" spans) as progress markers.
  - Split each World run into **districts** (for example Downtown: Main Street, Harbor Bridge, Midtown, Skyline Park), each with its own landmark and look, shown on a top progress strip with the player's head and distance. This also fixes "something memorable every few hundred meters" from the Downtown plan.
- **Owner:** L3 for scenery and the strip; road length and district distances need L1's segment contract.

### 4.2 The base
- **Your pen**: a fenced enclosure where your caught dinos stand and earn; each shows floating money labels ("$3/s", "+$2", "$12/s") and its rarity and name above it.
- **Upgrade sign** in the world: a large black sign "Upgrade ... Level 1 > Level 2, $1M" next to the pen.
- **Start zone**: a big painted "START ZONE" strip on the ground with huge white chevrons leading to the Dino Machine (a glowing launch ramp).
- **Stalls** around the base: "SELL DINOS" (striped awning stall) and "AURAS" (cosmetic shop with a colored ring on the ground in front of it), each with a colored circle painted on the ground marking where to stand.
- **Locked area**: "Jurassic Airlines" with a padlock icon and "20 / 200" progress above it.
- **Car Hop use:**
  - Floating Lap Pay labels over cars on your Speedway (already planned) and the **rarity and name over each Lineup car** so visitors can read your collection.
  - A big in-world **upgrade board** at the Paddock kiosk showing the next upgrade and its price (L3 look, L2 numbers).
  - **Colored ground circles** in front of every interactive spot (kiosk, Garage door, portal) so kids know where to stand.
  - Big painted ground chevrons and "START" text leading from your plot toward the portals for the first session.
  - Locked things show a padlock and live progress (matches our portal plaque).
  - **Do not copy "Sell"**: Car Hop cars are permanent, by design.

---

## 5. Animation and effects (L3 with L1)

| Seen | Car Hop version |
|---|---|
| Lasso swinging overhead while riding | Avatar points toward the target, or an arc preview line |
| Hearts and sparkle stars on a tame | Keys, stars and confetti burst on "YOU GOT THE KEYS!" |
| Red tint and "!" before being thrown | Car flashes, "!" and a reason before forced dismount |
| Tumble when thrown off | Cartoon tumble, then a reason banner |
| Dust trails behind running animals | Exhaust puffs and road dust behind traffic |
| Dashed yellow pulsing ring around the target | Our Hop ring: dashed, pulsing, one target at a time |
| Sparkle ring around the player on returning to base | Arrival sparkle at your plot gate after a run |
| Big chevrons on the ground | Our tutorial and boost-lane chevrons |

---

## 6. Proposals for the team (not decisions)

### 6.1 Per-car requirement stat (Team: L1 + L2)
- **Idea:** like "Required ⚡10", each car needs a minimum player stat to claim (for example "Grip"). Too low, and the car bucks you off with a reason. Players raise the stat with Cash.
- **Player benefit:** a clear, readable goal ("I need 60 Grip for that bus"), and a strong reason to come back and upgrade.
- **Cost:** a new stat, upgrade prices and UI; changes the economy.
- **Risk:** frustrating if requirements feel like walls; must never be sold for Robux (this game sells a "Rainbow Aura x4.5 Stamina", a paid power boost we should not copy; our pillar says passes never change Heat, Keys or race performance).
- **Test:** a paper prototype with the economy sheet, then a playtest with two requirement tiers.

### 6.2 District progress strip in runs (L3 + L1)
- **Benefit:** constant sense of progress, a reason to go further, natural landmark spacing.
- **Cost:** a HUD element plus district art; needs distance data from the run.
- **Risk:** low.
- **Test:** add it to the HUD prototype with a fake distance feed.

### 6.3 Timed world events (Team)
- **Idea:** countdowns like the video's meteor and night timers. Car Hop versions: "Rush Hour" (more traffic, more Rares), "Golden Hour" (Gold Variants more common), a parade.
- **Benefit:** reasons to stay and return; server-wide excitement.
- **Cost:** event system, art, balancing.
- **Risk:** must not feel like fake urgency for kids; no paid boosts tied to events.
- **Test:** one event in a playtest build.

### 6.4 "Claimed this run" tray (L3 + L2)
- A small on-screen tray of cars claimed so far in the current run (like "1 SECURED"), so progress during the run is visible. Low cost, adopt in the HUD.

### 6.5 Over-car nameplates in runs (L3 + L1)
- Rarity, name, NEW! tag, Variant tag over each traffic car, fading with distance. High value for readability. Adopt in the HUD and Downtown work.

---

## 7. Avoid

- Studded voxel textures and blocky shapes (against our art rules).
- Selling caught items (our cars are permanent).
- Paid stat boosts ("x4.5 Stamina" aura) and anything pay-to-win.
- Cluttered nameplates everywhere at once (in the video, distant labels overlap into unreadable piles). Fade and cap them.
- Ultra-plain open fields: their valley is mostly flat green; our Downtown should keep the rich detail and landmarks.

---

## 8. Next actions

- **Adam (L3):** add to the HUD and Downtown prompt: over-car nameplates, the district strip and zone banner, the claimed-this-run tray, the warn-then-eject reason banners, a dashed pulsing Hop ring, keys and confetti on claims, colored ground circles at interactive spots, bunting and banners across the road.
- **Brian R (L1):** generous hop arcs, one marked target at a time, the warn-then-eject sequence and tumble, traffic packs with varied speeds, a higher and wider chase camera test.
- **Brian L (L2):** look at proposal 6.1 (requirement stat) and 6.3 (events) for the economy model.
- **Team:** discuss proposals 6.1 and 6.3.

Key frames from the video are saved with this file (frame numbers are seconds into the video): 01 base pen and upgrade sign, 04 start zone, 08 rarity reveal and biome bar, 15 bunting across the valley, 19 and 30 "not enough stamina" red warning, 27 lasso and taming meters, 29 "IT'S YOURS!", 56 thrown off, 57 "STOMPED!" reason banner, 60 "GREAT RUN!" at base.
