# Brief: Lane 3 Raceway round 2 (2026-10-29)

From Adam (Lane 3 owner, repository owner), his review of PR #4. Copied verbatim from the session prompt of 2026-10-29. Ledger: [[raceway-round2-ledger]]. Builds on [[speedway-upgrade-looks]] and [[0025-speedway-visible-levels]].

## Execution clarifications for this session

My name is Adam Gertskis; use Adam on the board. This is implementation within the scope below, not permission to merge PRs, publish, migrate saves or change another lane's contracts. Preserve every existing approval and STOP point.

- Use one lead. At most two explicitly selected Sonnet workers concurrently, only for substantial disjoint tasks. One fresh Sonnet reviewer may review near the end after workers finish. No Opus workers, nested agents or repeated broad audits. If worker model selection cannot be verified, work solo. Only the lead operates Studio or Blender, Git, the shared board and PR updates.
- Inspect status, branch and worktrees first. Never switch a dirty checkout or disturb the other window. If main is checked out elsewhere, perform board-only work in that clean existing main worktree; do not force checkout. Serialize main updates, preserve other people's entries and return to the named feature branch. Pulling main does not authorize merging feature code into main.
- Read the live rules and applicable skills. Post one compact plan with files, ledger IDs and checks. Reuse current approved tokens and layouts. The numerical visual directions below are explicit proposals, not invented evidence of an approved mockup. Follow the current Figma-first rule for changed UI unless a recorded applicable exception exists. Prepare all affected mockups/specs together, batch the required approval, and continue independent allowed work meanwhile. Do not treat self-review as owner approval.
- Read C:\Users\agert\Documents\Car-Hop-Art\references\raceway-2026-10-29\ first if it exists. Missing optional images do not block work: the text below is sufficient. Record sources and licenses for any assets actually used. Reference study does not authorize copying logos, distinctive screens or paid assets. Do not download executable plugins or scripts just to obtain reference pictures.
- Style: bright, smooth faceted low-poly with beveled silhouettes, no studs, no voxel stacks, no photoreal textures. Symmetric shop/track furniture, deliberate aligned margins, restrained detail. Avoid the generic AI look: repeated neon outlines, excessive checkerboard, gratuitous trophies, random signs, floating props, tiny unreadable copy, intersecting trim and identical decoration on every surface. Use the approved island palette and token values; proposed ratios below describe placement, not a new palette.
- Preserve STUDIO_LOCK.txt and the 4 GB free-system-memory floor. Check the lock immediately before Studio use, not only at session start. No other window's processes or lock may be killed or removed as a shortcut. Continue disk-only tasks when Studio is busy. One guided batch for necessary owner clicks, except prerequisite approvals that must happen first.
- Capture real evidence, not fabricated screenshots or metrics. Label Edit mode, Play mode, fixture ownership, simulated device frames, real multi-client tests and untested physical devices distinctly. A browser mock is not a Studio screenshot. Do not pass off added soundtrack as captured game audio.
- Finish with a requirement-to-evidence table, decisions made with reversible alternatives, unresolved blockers and the exact question: "What did you actually test in Studio, and what did you only check by reading the code?"

Start a work session for this task: Lane 3 Raceway round 2 (rename, no ads, kiosk shop with stats and price, parking spots, faster island walking). Read AGENTS.md and vault/tasks/BOARD.md first, then vault/design/specs/speedway-upgrade-looks.md, its ledger vault/design/specs/speedway-upgrade-looks-ledger.md, decision 0025, vault/design/specs/walk-boost.md, the island ledger and decision 0018, and the review page Car-Hop-Art\review\speedway-upgrades\index.html, so you know exactly what was built. Switch to main and pull the latest from GitHub. Claim "Lane 3 Raceway round 2" on the board with my name, then commit and push only that board change to main. Then switch to the existing branch feature/lane3-speedway-upgrades and continue it (PR #4 stays the place for this work). If rokit.toml or wally.lock changed in the pull, run rokit install and wally install. Start rojo serve in the background for my private island test place only, never the shared Team Create place, and tell me if I need to press Connect. Another Claude Code session may be using Studio at the same time: follow STUDIO_LOCK.txt and the 4 GB free-memory floor. Before writing code, tell me which folders you plan to change and confirm they belong to my lane. Finish as much as possible without stopping; batch anything that needs my click into one guided moment at the end.

My review of PR #4: the Raceway looks good. The UI and HUD look good. Make these changes.

## PART 1. Remove every advertisement.

Remove every fictional sponsor, brand or ad from the Raceway at every level: the sponsor hoardings and plates on the bleachers and the grandstand, the banners on the banked walls, the blimp text, the big screen, and anything else with a made-up company name (Pip's Pops, Comet Cola, Haul Buddy Tires and any others). Search the kit recipes (assets/island/kit/kit_speedway.py), the manifest and src for every sponsor name and the word "sponsor", and list what you removed. Do not leave empty holes where they were: replace each with plain race decoration that fits the island style.

### DESIGN 1. A real community raceway, with no advertising.

Use existing navy, coral, cream, teal and yellow palette swatches. Aim for about 70% calm painted surface, 20% structure and 10% accent across these replacements. Keep the already-approved ramps, hump and ground-level loop from PR #4.

- Bleachers: cream front fascia with a navy lower stripe occupying 15% of fascia height. Add one short teal racing stripe at each end, mirrored. Leave the middle plain; no invented sponsor, badge or decorative slogan.
- Grandstand: navy front fascia, cream inset, and two mirrored coral end caps. Keep the owner's name only on its existing dedicated sign, not repeated across the grandstand. One checker strip may sit at the actual start/finish, two rows high, with square cells rather than stretched rectangles.
- Banked walls: keep the safety barrier shape. Paint a cream upper edge and a broad teal lower band, with a restrained coral end marker on each side. No repeated billboards, racing numbers that imply lanes, or yellow warnings unrelated to actual hazards.
- Blimp: cream body, navy underside, teal tail fins and one coral longitudinal stripe on both sides. Remove all lettering and logos. Preserve its existing approved movement; do not add lights, confetti or a second orbit.
- Big screen: use one calm display of "RACEWAY LEVEL [N]" on navy with cream text and a small teal underline. No cycling ads, invented payout numbers, animated stock ticker or flashing border. At distance reduce it to the readable broad color panel.
- Search visible text, textures, mesh recipe lettering, UI strings and spawned instances. Removing a name from source while its baked letters remain in an uploaded mesh is not completion. Identify every affected mesh and required re-export/re-upload; preserve its old working ID until a replacement is verified.
- Before/after evidence uses the same camera, level and lighting. Log removed name, location, replacement and whether runtime geometry or a pending asset upload still contains it.

Reference study: Kenney Racing Kit, https://kenney.nl/assets/racing-kit, is a useful modular racing-prop reference, listed as CC0. Borrow clean silhouettes and economical surface detail, not its complete track layout or palette. Optional search: "Kenney Racing Kit preview"; save a permitted reference as 01-racing-prop-shapes.png in the reference folder. The specification above is my proposed design, not a claim that the reference has these exact decorations.

## PART 2. "Speedway" becomes "Raceway" everywhere a player can read it.

Change every player-facing word "Speedway" to "Raceway": the owner's sign ("Adam's Raceway" style), the level-up banner, the kiosk, the shop panel, the parking sign, tooltips and prompts. Internal code and file names may keep "Speedway" to avoid churn: record that choice in the ledger. Update the vault message for Brian L so it uses "Raceway" and proposes the save field name RacewayLevel instead of SpeedwayLevel.

## PART 3. Level-up banner: level only.

I like the reveal banner. Change its text to state only the new level, with no level title: for example "RACEWAY LEVEL 5!". Remove the level names (like "THE FLAG OFFICIAL") from the banner and from anywhere else a player sees them. Keep the level names in the code and docs as internal labels.

### DESIGN 2. One clear level announcement.

Exact visible sentence: "RACEWAY LEVEL 5!", substituting the resulting level. Use a single line where it fits. On small screens, use two lines "RACEWAY" and "LEVEL 5!" with no additional words. No level titles, old-to-new comparison, sub-line, rarity label or second number badge.

Reuse the approved reveal container. Cream Fredoka One text with the existing navy outline; use the approved 36 px display role and 24 px fallback only if the measured safe-area width requires it. Yellow may accent the level number, but type size and contrast must still make the complete sentence readable. Center it above the gameplay focal area, outside Cash, Heat, prompts and touch controls.

Proposed motion: 0.18 s fade/settle in, 1.10 s hold, 0.22 s fade out, total 1.50 s. Reduced Motion: opacity only, no bounce or scale overshoot. At most one active banner. Cancel stale tweens when preview changes rapidly and show only the latest settled level. Opening/closing a panel must not replay the upgrade.

A new level updates the board, panel and track together from one preview state; the banner cannot announce a level the track did not reach.

## PART 4. The kiosk becomes a shop with a shopkeeper, and shows stats, not a picture.

The small upgrade kiosk booth beside the Raceway (KioskBooth in assets/island/kit/kit_plot.py; its board is drawn by src/client/Home/Island/Speedway/Kiosk.luau) becomes the Raceway shop. If you are not sure that is the booth I mean, show me a screenshot of it in your report.

- Scale the booth up so it reads as a real little shop from the plot entrance, with a counter, an awning and a sign that says "RACEWAY UPGRADES". Keep it inside the Kiosk reservation, never blocking the plot gate, the paths, the parking bays, the nameplate or the plaza view of the track. Measure it.
- Put a friendly shopkeeper character behind the counter: a simple stylized figure made from a few rigid parts (not a full avatar or skinned rig), animated in code (an idle bob and a wave when the plot owner walks up).
- The board stops showing a picture of the next level. Instead it shows what the upgrade gives: the current level and the next level, and the stat change. My stat for each level is a Lap Pay multiplier. Do not change lap time or car speed: lap time stays about 15 seconds at every level (the earlier rule), so the multiplier is the only earning stat. Use this proposed curve, clearly marked as a proposal for Brian L, read from one table so his economy can replace it later:
  Level 1 x1.00, 2 x1.10, 3 x1.20, 4 x1.35, 5 x1.50, 6 x1.70, 7 x1.90, 8 x2.15, 9 x2.40, 10 x2.70, 11 x3.00, 12 x3.50.
  Show it as "LAP PAY x1.35 → x1.50", plus a short line naming the new things the level adds (for example "New: pit garage").
- Buying: the plot owner walks up to the shopkeeper and gets a prompt "Upgrade Raceway". It opens an upgrade panel (in the HUD style: Fredoka One, thick outlines, glossy buttons) showing the current and next level, the Lap Pay change, the price and a big BUY button. Prices are Brian L's economy and are not set yet: show "PRICE: SET BY ECONOMY" in a clearly marked preview style. In Studio preview only, BUY plays the level-up reveal and raises the level. No Cash, no saving, no remotes. Visitors on someone else's plot see the board read-only and get no buy prompt.
- At level 12, the board and panel say "MAX LEVEL" and the BUY button is gone.

### DESIGN 3. A compact, welcoming trackside shop.

First measure the actual Kiosk reservation, avatar size and approach sightline. Proposed outer envelope including awning: 12 studs wide x 8 deep x 10.5 high. This is a maximum design target, not permission to enlarge the reservation. Keep 0.5 stud inside its measured bounds and preserve the full existing path clearance. If it cannot fit with a readable counter and character, report measured options rather than squeeze or invade the Paddock.

Shape: a low, gently pitched navy roof over cream walls; teal corner posts with small bevels, coral counter base and cream counter top. Counter top about 3.0 studs high and 1.2 deep. The broad opening is about 7.5 wide; keep the character visible. A 1.5-stud awning projection uses three broad cream/teal fabric bands, a straight edge with softly rounded corners, no thin scallop clutter. All dimensions include projections.

Sign: one 9 x 1.6 stud cream fascia beneath the roof reading "RACEWAY UPGRADES" in navy. Avoid two competing headers. Keep the stat board beside the counter opening, facing the owner approach, never covering the keeper's face. One small tool tray and one folded cloth at most; no counter merchandise, product ads or piles of tires.

Shopkeeper: an original friendly rigid figure about 4.5 studs tall, approximately 1.25 times normal head-to-body exaggeration. Rounded faceted head, two simple eyes and small smile, navy work shirt, teal apron, cream gloves, coral cap with no logo. Use a small reusable part/mesh set with arm pivots at the shoulders; no fingers, realistic skin texture, full avatar rig or resemblance to a real person.

Idle: torso/head vertical movement no more than 0.05 stud over a 3.2 s cycle, arms otherwise relaxed. Greeting: owner enters the interaction radius, arm lifts about 55 degrees in 0.18 s, makes two 12-degree waves over 0.65 s, returns in 0.22 s. One greeting per approach, rearmed only after leaving; at least 8 s between greetings. No synchronized continuous waving across six plots. Stop animation when culled or removed. Reduced Motion keeps a static welcoming pose with no bob.

Use existing prompt range and owner identity source. Do not greet through walls or show a second prompt on top of another one. The shopkeeper cannot collide with or push visitors.

Optional reference search: "low poly park information kiosk striped awning"; save 02-shop-shape.png if useful. Borrow the counter opening and roof proportions only. Build our own palette, sign and character, not an identifiable vendor mascot.

### DESIGN 4. An upgrade card that a child can understand in one glance.

Extend the existing approved HUD components and shared tokens. Fredoka One, thick navy outline, cream body, restrained glossy button cap. No new UI framework or look. Proposed desktop card is 520 x 360 design pixels; adapt to safe-area bounds and existing UIScale. On landscape phones use the available height without shrinking targets below the approved 48 px minimum and 56 px primary button. Keep close and action controls reachable; scroll the body if necessary.

Hierarchy from top to bottom:

1. Header "RACEWAY UPGRADES" with one close button.
2. A modest "CURRENT LEVEL 4" tile, one right arrow, and a stronger "NEXT LEVEL 5" tile. At narrow widths this remains one compact row.
3. The hero stat: "LAP PAY x1.35 → x1.50", using the exact proposed table. Current value navy, next value teal with a plus/upward shape cue, never color alone. No progress bar: these are discrete levels and a bar would imply fractional progress.
4. One line "New: [actual added feature]" from the existing ladder, for example "New: pit garage" only at the level that really adds it. No internal level titles. Keep to two short physical additions at most.
5. Price strip: "PRICE: SET BY ECONOMY".
6. A wide glossy BUY button, at least 56 px high, with an adjacent persistent "STUDIO PREVIEW" marker and "No Cash spent. Progress is not saved." in preview.

Use the approved 36 display / 24 value / 18 label / 16 minimum roles. Proposed padding 20 px desktop, 16 phone, vertical gaps 8 or 12; reuse approved equivalents where tokens differ. Gloss is a quiet top highlight, not a sweeping animation.

At level 12: replace the comparison and price area with "MAX LEVEL" and "RACEWAY LEVEL 12"; remove BUY and keep close. Do not promise another level. Visitors have the read-only board and no action prompt; ownership changing while open closes the purchasing surface safely.

Preview clicks are accepted once per transition. Rapid clicks cannot skip or buy twice. At runtime outside the explicit Studio preview fixture, unknown prices mean no enabled purchase action. No fake affordability, free claim, player currency, remote or save field is introduced. Document future pending/success/error/unaffordable states for Brian L, without pretending they are connected.

Use simulator-screen traits such as strong hierarchy and chunky buttons, not an exact screen from another game. Show a shop-open mock over the actual island view at desktop, phone landscape and tablet sizes. Record which parts await Figma approval rather than inventing an approval.

## PART 5. Parking spots you can buy.

The Paddock has room for 15 bays. Everyone starts with 2 parking spots. More can be bought one at a time, and each costs more than the last (exponential). The number of parking spots is how many cars can sit on the plot's Raceway lineup.

- Show only the owned spots as usable bays. The next buyable spot shows as a locked bay (a chain or a "FOR SALE" style marker); further ones are hidden or faded so the Paddock never looks empty.
- A parking sign beside the Paddock with a prompt "Buy Parking Spot" opens a small panel in the same style as the upgrade panel: owned spots ("2 / 15"), the next spot's price and a BUY button. Prices are not set yet: "PRICE: SET BY ECONOMY", preview-marked. In Studio preview, BUY unlocks the next bay with a short reveal (barrier lifts, bay lines paint in, small confetti). At 15 it says "ALL SPOTS OWNED".
- Write the proposed price rule into the message for Brian L, clearly as a proposal: each new spot costs about 1.6 times the previous one, starting from a first price he sets. Do not hard-code prices anywhere.
- Parking spots and Raceway levels are two separate upgrades with separate save fields (propose ParkingSpots, starting at 2, max 15, to Brian L). Record that the 2-spot start is Adam's decision.

### DESIGN 5. Owned parking should look welcoming, not like a paywall.

Reuse the actual 15-bay Paddock layout and car clearance. Never resize bays from guessed vehicle dimensions. Make a compact parking sign about 3.2 studs wide x 3.8 total high: cream beveled board on a navy post, teal inset, simple original cream "P" symbol and a small plus. Text reads "PARKING" and "2 / 15", with the live owned count. Keep it inside its existing reservation and away from the gate.

Owned bays have clean cream ground lines and their existing car positioning. Only the next bay shows an unowned state. Use a short navy-and-cream barrier arm at its mouth, about 2.0 studs high, and one understated "ADD SPOT" plaque. Avoid chains across pedestrian routes, aggressive red locks, price balloons, "FOR SALE" ads, arrows everywhere or a forest of cones.

Further bays remain hidden as functional stalls; retain a coherent plain Paddock surface so there are no empty holes. Decorative hidden bays must not retain invisible collision. The next marker moves forward after a successful preview unlock. At 15, remove it entirely.

Unlock timing, total about 0.9 s: immediate button acknowledgement; barrier pivots safely up over 0.25 s; ground lines reveal over 0.30 s; 8 to 12 small cream/teal/coral confetti pieces expire within 0.6 s. No beam, explosion or camera shake. Reduced Motion switches lines and count immediately with a short fade, no confetti. Decorative barrier motion cannot trap or fling avatars.

Parking panel reuses the Raceway card, titled "PARKING SPOTS", with "OWNED 2 / 15", "NEXT SPOT 3", the exact unknown-price label and preview-marked BUY. At 15 show "ALL SPOTS OWNED", remove BUY. No real price calculation: Brian L's proposed rule is price(k) = firstPrice * 1.6^(k-3) for buying spot k, k=3..15; rounding and firstPrice remain his choices. This formula goes in the proposal, not purchase code.

Changing Raceway level cannot alter parking ownership, and unlocking parking cannot change Lap Pay multiplier. Verify both directions, repeated panel reopening and owner/visitor changes.

## PART 6. Faster walking on the home island.

The island is big, so every player walks at twice the normal speed by default on the home island (Roblox's default WalkSpeed is 16, so 32). The walk-boost lanes stay and stack on top of the new speed: their multiplier applies to the new base, so a boost lane now gives 32 x 1.5 = 48. Change src/client/Home/Island/WalkBoost.luau so a boost multiplies the island base instead of taking the maximum, update its tests, and update vault/design/specs/walk-boost.md.

- This applies only on the home island. When a player enters a run or a portal, the run's own speed rules apply (Brian R's lane). Restore the island speed when they come back. Check that his run code does not depend on WalkSpeed staying 16; if it does, write him a message instead of changing his code.
- At the faster speed, make sure the walk animation does not look like sliding, the camera keeps up, and players cannot run off the edge into the lake or waterfall by accident or clip through fences. Check jump distance at the new speed against every fence and gap, and keep it fair (no shortcuts over plot fences).

### DESIGN 6. Faster travel, with controlled animation and boundaries.

Home-island base is exactly 32, boosted speed exactly 48. A boost is applied once, not once per overlapping lane: 32 * 1.5, never exponential stacking. Re-entering a lane, respawning or closing UI cannot multiply speed again.

Use the existing avatar locomotion controller and inspect what it already does before changing animation. Prefer its approved run gait at 32 and proportionally adjusted cadence at 48 if it supports that; do not double animation playback blindly when the controller already scales it. Test supported avatar rigs in the project. Keep feet reasonably synchronized with traveled ground distance without comically rapid legs. No animation upload, replacement avatar or paid run asset.

No speed effects at normal 32 walking. While actually moving along a boost lane, optional low opaque-looking dust puffs behind feet, at most about 4 per second, lifetime 0.25 s, size 0.15 to 0.35 stud. Disable them for Reduced Motion and low-detail settings; stop at rest and on exit. No full-screen speed lines, FOV pulse, motion blur or camera shake. Reuse boost-lane markings; one entry label "WALK BOOST x1.5" is sufficient, never a permanent 48-speed HUD.

Treat movement as explicit home/boost/run transition ownership. Island code releases control when entering a run, does not repeatedly write 32 over Brian R's controller, and restores the island base on return. Use an existing authoritative mode signal if available; if no agreed signal exists, demonstrate with a labeled fixture and put that contract in Brian R's message instead of guessing from geography.

Test 32 and 48 with forward, diagonal and turning movement; jump at boost entry/exit and near each relevant fence, lake edge and waterfall approach; test death/respawn while boosted and departure while the boost timer is active. Do not change jump power, camera behavior, collision contracts or run code to hide a failure. Small Lane 3 boundary corrections must fit the existing style and be documented; larger gameplay changes need the proper owner. Preserve about 15-second decorative car laps independently of player walking.

## PART 7. Messages for Brian L (through the vault).

Update vault/design/specs/speedway-levels-for-brian-l.md on main (vault-only commit, then return to the branch): the rename to Raceway and RacewayLevel; the proposed Lap Pay multiplier table; the parking spots decision (start 2, max 15, bought one at a time, proposed x1.6 price growth, save field ParkingSpots); the purchase flow Lane 3 built (shopkeeper prompt, panels, BUY), so his code only needs to supply prices, check Cash on the server and send the new level or spot count. Keep the Replies section.

## PART 8. Verify and finish.

- Test everything in Studio Play in my private island place: owner and visitor views, every Raceway level 1 to 12 with the new board, buying through all 12 levels and from 2 to 15 parking spots, MAX states, walking speed with and without boost lanes, entering and leaving a portal. Desktop and the landscape phone and tablet frames.
- Review page Car-Hop-Art\review\raceway-round2\index.html: before and after stills for every removed ad; the shop, shopkeeper and both panels; a real-time video with sound of buying an upgrade and a parking spot; a walking comparison at the old and new speeds; what you tested in Studio separated from what you only checked by reading code; what is waiting on me and on Brian L.
- Run ./scripts/check.ps1 and fix any failures inside my task. Commit, push the branch (no force), update PR #4 with gh describing what changed, what was actually tested in Studio, and anything a teammate must do after pulling. Update my task on the board and add my log entry. Do not merge.
- End with what is waiting on me and what is waiting on Brian L.
