# Car Hop: Lane 3 Round 3 (Shop revamp, Launch Pads, shorter tutorial, run results, and Adam's playtest fixes)

**For:** Claude Code, on Adam's Windows laptop, repository `Roblox-Game-1` (GitHub `agertskis-maker/Roblox-Game-1`).
**From:** Adam (repository owner, Lane 3 owner: World, UI & Feel), written with Claude (claude.ai) on 2026-11-02. Lines marked **[ChatGPT]** were added by ChatGPT.
**Task folder (outside Git):** `C:\Users\agert\Documents\Car-Hop-Art\review\round3\`
**Builds on:** Round 2 (`C:\Users\agert\Documents\Car-Hop-Art\review\round2\BRIEF-ROUND2.md`, its `RESULT.md`, decision `0032-lane3-round2.md`, the Round 2 ledger), still on branch `feature/lane3-big-round` (draft PR #8) and `integration/beta-2` (draft PR #9).

One long, autonomous session. Read this whole brief first, then work through it in the order in section 4.

**The earlier rounds' rules still apply** unless this brief changes them: Round 1 brief sections 2, 2.2, 2.3, 3, 5 and 19 to 21; Round 2 brief sections 1.1 (how to use reference games: heavy inspiration, original pixels) and 2 (same-view verification).

---

## 0. What Adam said after playing Round 2

His full notes are in `review\round3\ADAM-FEEDBACK.txt`. In short:
- **HUD:** move the Shop, Garage and Missions buttons toward the **middle of the left edge**, and make the **Cash display bottom left bigger**.
- **The Shop needs a full revamp.**
  - The icons look blurry, "not fully loaded" and badly spaced.
  - The Starter Pack's paint, money and gift box look cheap.
  - The VIP crown floats too high above a plain car. He wants supercars that look amazing.
  - The 2x on Double Lap Pay is blurry.
  - The fonts and layout "look pretty AI". He wants it unique, vibrant and enticing, "not fancy".
  - The Style tab is broken: the paint pack and preview colors behave oddly, the decals tab has no decals, and the wheels don't work.
  - Icons are misaligned (the Legion paint, gift and group icons are spread apart; the paint and decal flame aren't aligned).
  - **Add Robux Cash packs that scale with progress.**
  - "The whole point of the game is monetization, so the shop needs to be absolutely perfect."
- **Garage:** looks good, keep it.
- **Missions:** looks "AI". The rewards and Claim buttons must look far more enticing.
- **Leaderboard** is fine.
- **Settings** is fine, except the Replay Tutorial button isn't centered in its top bar.
- **Tutorial:**
  - The ground arrows must lead **in a straight line directly to the target**, not along the paths.
  - The top banner is far too big and blocks the game: remove "2 / 12", make it skinnier and smaller.
  - Make the whole tutorial **simpler and shorter**.
- **Run camera:** too low behind the car, things block the view. It should sit higher, somewhat above the car (not straight down). Find a view that feels good. This is Brian R's code (see N7).
- **Run end screen** ("you caught 0 cars"): redesign it entirely, from a ChatGPT reference image.
- **New: a hub between the portal and the run** (a Launch Pad). Keep it simple: a few things to buy (for example a trail), then start your run.
- **Paths:**
  - A sharp spike from the path under the Dusty Highway portal; smooth it.
  - The same under the Summit Pass portal.
  - Near the river at the last bridge, between the last Raceway and the Garage, the path ends in a rectangular outburst by the flower beds. Cut it off cleanly where the path ends, and the same on the other side.
- **Your own judgment:** "Claude Code is limited by our prompts because we're asking it such specific things... Claude Code should have some of its own digression on what it needs to do. If it wants to try to learn something or try to figure something out, it should be able to do that."

### 0.1 Adam's decisions for this round (2026-11-02)
1. **Launch Pads:** one simple layout, themed per World: a Downtown garage, a Dusty Highway gas station, a Summit Pass ski lodge. Make each theme look really good.
2. **Starting a run:** walk onto a glowing launch ramp → a card shows your car and your trail with a big START button → press START to begin the run.
3. **What's sold in the Launch Pad:** choose your starting car, **trails** (a new cosmetic: cheaper ones for Cash, flashy ones for Robux), and a shortcut to paints. **No paid run boosts** (nothing bought may change Heat, Keys, Stamina or race results; that is the game's rule).
4. **Scaling Cash packs:** the amount is based on what the player's Raceway earns (for example "30 minutes of earnings"), with the player's current Cash as a minimum so the packs stay meaningful.
5. **Shorter tutorial:** Go to Downtown → Hop to a car → Hold on / It's yours! → Go home → Park your car → Done. Raceway upgrades and the Shop become one-time hints later.
6. **Run camera:** build a camera tuner in the beta (no edits to Brian R's files) so Adam can try angles live, then send Brian R the best settings.
7. **Summit Pass spacing:** set the landmark order by hand, so the spacing always works.
8. **Icons:** not uploaded yet. Redo the art first, then prepare **one** upload at the end.
9. **Real cars:** cars in shop art are **supercars that look McLaren-class, Lamborghini-class and so on, but with no real logo, badge or name** (the game's parody-car rule; Roblox can remove games that use real brands).

---

## 1. Read first
1. Round 2's `RESULT.md`, its ledger, decision 0032, and both Round 2 teammate messages. Check every `## Replies` section in `vault/design/specs/*-for-brian-*.md` again.
2. `AGENTS.md`, `vault/tasks/BOARD.md`, the latest log entries.
3. `review\round3\ADAM-FEEDBACK.txt` (Adam's full words).
4. **New ChatGPT images** in `review\round3\chatgpt-images\` (mockups, made from `review\round3\CHATGPT-IMAGES-R3.md`) and **new ChatGPT art assets** in `review\round3\chatgpt-assets\` (real images for the game: shop item art and icons). If anything is missing, design from the text of `CHATGPT-IMAGES-R3.md` and say so in the final message.
5. The earlier references are still valid:
   - `review\round2\references\` (HUD videos A and B, their frames)
   - `review\map-fixes\references\` (the shop video and frames)
   - `review\round2\chatgpt-images\`

---

## 2. How much freedom you have (read this twice)

Adam explicitly wants you to **think like a lead designer, not a checklist executor**. This brief tells you the goals, Adam's decisions and the hard lines; how to reach the goals is mostly up to you.
- **You may and should:**
  - research (Roblox docs, how successful Roblox games solve the same problem)
  - prototype two or three options and keep the best
  - throw away your own earlier work when a better approach exists
  - invent small improvements nobody asked for when they clearly help kids enjoy the game or help the Shop sell honestly
  - learn a technique you haven't used before
  - write small tools that make you faster or your checks stronger
  
  Record important choices in the ledger and the decision note, and list the notable ones in the final message under "Choices I made".
- **Where this brief gives numbers or layouts, treat them as starting points** unless they are marked as Adam's decision (section 0.1) or a hard line.
- **The hard lines are unchanged:**
  - no edits to Brian R's or Brian L's files
  - no new saved-data fields beyond the existing beta-only `TutorialDone` without a posted plan (if you truly need one for the beta, add it to the beta-only store and explain why in the final message, as in Round 2)
  - no real purchases or product IDs
  - prices, rewards and Cash amounts are PREVIEW proposals for Brian L
  - no paid randomness
  - no paid gameplay advantage
  - no merge into `main`, no publishing, no Team Create edits
  - original art only, no real brands or logos
  - no destructive Git
- **Never stop to ask Adam.** Decide, record, continue. Things that need his hands go into one numbered list at the end.

### 2.1 Avoid the "AI look" (Adam's main complaint about the Shop and Missions)
Adam says parts of the UI "look pretty AI". Learn to see this and design against it. Typical tells of AI-made UI:
- The same purple-to-pink gradient on everything.
- Every card the same size, the same radius and the same glow.
- Text centered everywhere with no clear hierarchy.
- Generic sparkles and glossy sheen sprinkled on every element.
- Icons of different visual weight and scale, floating at random positions inside their cards.
- Small raster images stretched up until they blur.
- Too many little tags and badges competing.
- One default rounded font for every role.
- Empty decorative space, and copy that sounds like marketing filler.

What good Roblox shops do instead (study the reference videos again with this list):
- **One clear hero per screen**, then a strong, deliberate size hierarchy.
- A **visual motif that belongs to the game.** For Car Hop: racing stripes, checkered flags, tire-tread edges, speed lines, chrome bezels, number plates, pit-board shapes, headlight glows.
- **Crisp art at native resolution** (author images at 2x the largest on-screen size and never upscale; ensure image sizes respect Roblox's upload limits).
- **Fixed icon slots:** every icon sits in the same-size slot, with the same padding and the same optical center.
- **Two fonts, each with a job:** a chunky display font with a heavy stroke for titles and numbers, and a clear, readable font for small text. Reuse the HUD's fonts unless a better Roblox built-in font clearly wins, and record it.
- **Color with purpose:** each product family has its own signature color, the price button is always the same green, and deals always use the same red-and-gold stamp.
- Real texture and depth: subtle stripes, halftone and pattern in backgrounds, inner bevels, and a drop shadow that is consistent in direction.
- Short, punchy, kid-readable copy.

**Add an "AI-look" check to your self-review:** a fresh reviewer gets the list above and scores each screen 1 to 5 on "looks hand-designed and specific to Car Hop". Anything under 4 gets reworked.

---

## 3. Setup
**S-01** Pull `main`, then continue on `feature/lane3-big-round` (merge `main` in if it moved) and keep `integration/beta-2` updated from it. Keep both PRs as drafts.
**S-02** Claim a board row "Lane 3: Round 3 (Shop revamp, Launch Pads, tutorial, run results, playtest fixes) - Adam, with Claude Code, 2026-11-02". Commit and push only that board change to `main`.
**S-03** Ledger: `vault/design/specs/lane3-round3-ledger.md`. Copy this brief to `vault/design/specs/lane3-round3.md`. Reserve the next decision number after 0032 for `vault/decisions/00NN-lane3-round3.md`.
**S-04** **A UI style guide** (recommended by Claude): before revamping screens, write `vault/design/ui-style-guide.md`. It covers fonts and their jobs, the color system per product family, card types and sizes, icon slot sizes and padding, button styles and states, the motif library, motion timings, and the "AI-look" rules from 2.1. Use it for every screen in this round, so the game stops drifting screen by screen. Keep it short and practical.
**S-05** Images and upload: see N2-06. The Open Cloud route from Round 2 still applies if `ROBLOX_OPEN_CLOUD_KEY` exists; otherwise prepare one bulk import at the very end.

## 4. Run order (suggested; change it if you find a better order)
1. N1 quick world fixes (paths, Summit order)
2. N2 art pipeline and icons → N3 Shop revamp → N4 Style tab → N5 Cash packs
3. N6 Launch Pads → N7 camera tuner → N8 run end screen
4. N9 shorter tutorial → N10 HUD changes → N11 Missions and Settings
5. N12 Round 2 leftovers → N13 messages → N14 self-review → N15 finish

---

## N1. Quick world fixes
**N1-01 Portal paths:** under the Dusty Highway portal, a sharp spike sticks out of the path. Find the cause (likely a path segment or wedge overshooting) and fix it in the recipe so the edge is smooth. Do the same under the Summit Pass portal, and check the Downtown portal too.
**N1-02 Path end by the river:** at the last bridge, between the last Raceway plot and the Garage, the path ends with a rectangular outburst next to the flower beds. Cut the path cleanly where it should end (a tidy rounded or square end that matches the path style), and fix the mirrored spot on the other side of the island. Then scan every path end on the island for the same kind of overshoot, and fix them all.
**N1-03 Summit Pass landmark order (Adam: set it by hand):** replace the random landmark placement with a hand-authored, fixed landmark sequence and spacing for the loop that meets every spacing rule, including majors 500 apart. Keep seeded variety only in minor props. Re-run the checks on the five test seeds; all must pass.
**N1-04 Done when:** after-shots from the walking camera at each spot, all path-end and spacing checks pass, and the flicker scanner is zero.

## N2. Art pipeline and icons (fix the blur at its source)
Adam: icons look blurry, "not fully loaded", badly spaced and misaligned.
**N2-01 Find why they blur:** for example small source images stretched up, icons cut from a low-resolution sheet, wrong scale type, or images shown before they load. Write the cause in the ledger.
**N2-02 Use the new ChatGPT assets** in `review\round3\chatgpt-assets\` (individual high-resolution icons and shop item art) as the main source. Clean each one (transparent background, trim, consistent padding, same optical center), and export at the sizes the UI really needs, at 2x. Respect Roblox's image upload size limits (verify them in the current docs). Where an asset is missing or weak, render a replacement in Blender in the same style, or improve it, your call.
**N2-03 Fixed icon slots:** every icon in every screen sits in a slot of a defined size, with defined padding and alignment, from the style guide (S-04). No icon floats, and icons in a row share a baseline and visual weight. Fix the misalignments Adam saw: the Legion paint, gift and group icons spread apart in the Free card; the paint and decal flame not aligned in the Style tab.
**N2-04 Load behavior:** preload the Shop's and HUD's images at join (through the loading screen), and never show a half-loaded image. Show a clean placeholder shape until loaded.
**N2-05 The 2x:** Double Lap Pay's 2x is crisp, drawn into high-resolution art, never stretched text.
**N2-06 One upload at the end:** prepare a single bulk-upload package (the new icons plus the shop art), with a manifest and exact Studio Asset Manager steps (group LEGION STUDI0S, 74306252, as Creator), or upload through Open Cloud if the key exists. The old 37-icon package from Round 2 is replaced by this one. Until then, the local files show the new art.

## N3. Shop revamp (the most important screen in the game)
Adam: "The whole point of the game is monetization... the shop needs to be absolutely perfect." "Not fancy but more vibrant and enticing." References: the shop reference video (`review\map-fixes\references\`), `review\round3\chatgpt-images\R3-IMG-01-shop-featured.png` and `R3-IMG-02-shop-cash.png`, and the style guide.

**N3-01 Rethink it, don't patch it.** Study the reference shop again, Round 2's shop and Adam's complaints, then redesign the Shop with the style guide. Keep the good bones (tabs, hero carousel, deal banner, honesty rules, "Coming soon" buy flow, PREVIEW prices), and rebuild the visuals.
**N3-02 Item art:** every product has a real, detailed, crisp illustration at native resolution, not a small icon blown up.
- **Starter Pack:** a hero supercar (parody, no badge) with flame paint on a glowing podium, with a pile of Cash and the starter decal shown as a sticker. Each item in the pack has a clear, detailed mini-art with its name.
- **VIP:** a sleek supercar with a gold crown that sits **just above or on** the car (not floating high), a VIP name plate, and a gold glow.
- **Double Lap Pay:** a crisp gold "2x" coin over a Raceway lap line, with cars.
- **Expanded Paddock:** a garage with extra parking bays and a plus.
- **All Passes Bundle:** the three pass arts grouped in a treasure crate.
- **Cash packs:** grow visually (small stack, bundle, briefcase, safe, vault).
- **Trails:** a car with a glowing trail.
- **Free gift:** one gift with a "FREE" tag and a small group badge, as one tight composition.
**N3-03 Supercars:** where a car appears in shop art, it is a cool, glossy supercar (McLaren, Lamborghini or Bugatti-class shapes, with no logo, badge or real name), in bright paint, with dramatic lighting. If a car silhouette is clearly a single real model, alter it enough that it is a parody, in line with the project's car rules.
**N3-04 Layout:** a strong hero, then a clear hierarchy. Vary card sizes on purpose: one big hero, medium deal cards, small pass cards. Even spacing on a grid. Price buttons the same green everywhere. Deal stamps the same red and gold everywhere. Fonts as in the style guide. It must look great at phone landscape, tablet and desktop.
**N3-05 Motion:** keep the moving gradients and shine Adam liked, but tasteful, from the style guide: slow color flow on hero and deal cards, a shine sweep every few seconds, the price button breathing, and a hover lift with an outline glow. One update loop while open; calm under Reduce Motion.
**N3-06 Honesty rules unchanged:** true deal labels only (within the PREVIEW catalog), real component sums for struck-through prices, no fake timers, no paid randomness, truthful descriptions.
**N3-07 Wire the missing entry point:** "Get more spots" in the Raceway parking panel opens Expanded Paddock.
**N3-08 Done when:** the Shop scores at least 4 out of 5 on the "AI-look" check and at least 4 out of 5 against the reference shop, from two fresh reviewers, at all three sizes, and every tab works.

## N4. Style tab: make customization actually work
Adam: only some parts work; the paint pack and preview colors work oddly, the decals tab shows no decals, the wheels don't work. "All these styles just need to be improved because they don't even work right now."
**N4-01 Fix the functionality first:**
- Paint, decals and wheels all apply visibly and correctly to the preview car.
- Selecting, previewing, "buying" (PREVIEW) and equipping work for every item.
- Every tab shows its items.
- The preview resets correctly when leaving.
- The Shop's Style tab and the Stunt customization screen share one implementation, so they cannot disagree.
**N4-02 Decals:** real decal images on the car body (flames, lightning, racing stripes, numbers, checkers, stars, shark teeth, comet trail and more; at least 12), crisp, sized and placed per car area, using the method that looks best on Roblox meshes (decals, textures or overlay parts; research and pick).
**N4-03 Wheels:** at least 8 visibly different wheel styles that really swap on the preview car (rim shape, color, glow).
**N4-04 Paint tiers:** Basic, Metallic, Pearl, Two-Tone Gradient, Animated (Rainbow Flow, Galaxy, Lava and more). They look like what they claim; animated paints animate cheaply; prices rise with tier (PREVIEW).
**N4-05 Trails** (new, used by the Launch Pad): at least 8 trails (for example spark, rainbow, flame, star, bubble, neon, smoke ring, confetti), previewed on the turntable car. Cheaper ones for Cash, flashy ones for Robux (PREVIEW). Cosmetic only.
**N4-06 Done when:** a Play recording shows every tab, a paint, a decal, a wheel and a trail applied and equipped, at phone and desktop sizes.

## N5. Scaling Cash packs (Robux)
Adam's decision: pack size scales with progress, based on the player's Raceway earnings, with current Cash as a minimum.
**N5-01 Design** 4 to 6 Cash packs, each defined as "N minutes of your Raceway earnings" (for example 10, 30, 60, 180 and 480 minutes; tune it), with a floor based on current Cash (for example the pack never gives less than X% of the player's current Cash; propose the numbers). The cards show the **live amount** for this player ("+$54,000", "= 30 min of earnings"), recalculated when their rate or Cash changes, and the biggest gets BEST VALUE only if it truly gives the most per Robux.
**N5-02 PREVIEW only:** the formula lives in one Lane 3 display module, so Brian L can move it server-side; the real grant must be calculated by the server at purchase time from server data. Put that rule in his message. PREVIEW Robux prices. "Coming soon" on buy.
**N5-03 Placement:** a Cash tab plus a Cash section on the Featured page; the green "+" next to the HUD's Cash opens it.

## N6. Launch Pads (new hub between the portal and the run)
Adam: "When you walk into a portal I don't want it to directly put you into the gameplay... some kind of hub... buy a trail or something and then go into the gameplay area... It should be very simple." Decisions 1 to 3 in section 0.1. References: `R3-IMG-05a-launchpad-downtown.png`, `R3-IMG-05b-launchpad-dusty.png`, `R3-IMG-05c-launchpad-summit.png`, `R3-IMG-06-launch-card.png`.
**N6-01 One layout, three themes.** A small, compact space, about a 10 to 15 second walk across at most:
- An arrival point from the portal.
- The **launch ramp** in front (glowing, can't miss it).
- A **Car stall** (choose your starting car).
- A **Trail stall** (buy and equip trails).
- A **Paint corner** (opens customization).
- A **portal back** to the island.

Themes:
- **Downtown Garage:** a city auto-garage with roll-up doors, neon, and the skyline behind.
- **Dusty Gas Stop:** a desert gas station with a canopy and a neon sign, with mesas behind.
- **Summit Lodge:** a ski lodge with snow, warm lights and pines.

Simple, clean and very good-looking: few details, done well. Reuse the World kits.
**N6-02 Where it lives:** in the same place as the island and runs (one place, as decided), placed so streaming works, never visible from the island or a run. Decide the exact placement and how the portal brings the player there (walking into the portal field moves them to the Launch Pad, with a short, nice transition), and record it.
**N6-03 Launch flow:** walking onto the ramp opens the **launch card**: the chosen car on a turntable, the equipped trail playing behind it, the World name, and a big START button (plus a small "change car" and "change trail"). START begins the run through the existing beta flow (Brian R's run, his files untouched). After a run, **RETRY** starts again from this Launch Pad's ramp (or straight into the run; pick what feels best) and **HOME** returns to the island. The equipped trail shows behind the player's car during the run through the beta adapter (outside his code); put the trail hook in Brian R's message.
**N6-04 Stalls:** each stall is a simple counter with a sign (the sign family) and a prompt. Opening it shows a compact panel in the Shop style (car picker / trails / paints). PREVIEW prices, "Coming soon" for Robux items, PREVIEW "buy" for Cash items.
**N6-05 Tutorial path:** on the first run the tutorial passes through the Launch Pad. The arrow leads straight to the ramp, and the banner shows "Press START!" as a sub-hint of the "Go to Downtown!" step (not a new numbered step).
**N6-06 Done when:** all three Launch Pads look finished and on-theme in Play, the whole loop works in the local beta (portal → Launch Pad → ramp → START → run → results → RETRY or HOME), and there's no flicker.

## N7. Run camera tuner (decision 6: no edits to Brian R's files)
**N7-01** Find out how Brian R's chase camera can be influenced from outside his code: his public API, options his controller already accepts, or overriding the camera after his update step without fighting it. If there is a clean way, build a **beta-only camera tuner**: a small panel (opened with a key or a debug button) with sliders for distance behind, height, pitch, field of view and look-ahead, plus a few presets ("Higher", "Top-ish", "Classic"). Values apply live during a run, and a "Copy settings" button copies them.
**N7-02** Pick a recommended preset yourself by playing: higher and more above the car than now (Adam: "more on top of the car, not fully on top"), with lanes ahead clearly visible, the target ring readable, and nothing blocking the view. Make it the beta default only if it can be done cleanly from outside his code.
**N7-03** If there is no clean way from outside, build the tuner as a preview that replays a run segment in the HUD place or uses his playground in a copy, and still produce recommended numbers.
**N7-04** Send Brian R the recommended settings, with before and after frames, in his message.

## N8. Run end screen (redesign)
Adam: the "you caught 0 cars" end screen "needs to be fixed entirely". Reference: `R3-IMG-04-run-results.png` (with a "0 cars" variant).
**N8-01** Lane 3 owns the run HUD's presentation. Build a new results card fed by Brian R's run results (his `Ended` signal and results data, observed from outside his code; hide his own overlay in the beta the same way Round 2 hid his hint). It shows:
- distance and personal best
- the cars caught this run, as cards
- Cash earned
- coins and milestones (where data exists)
- a short encouraging line
- RETRY and HOME
**N8-02 The "0 cars" case is a real design moment:** an encouraging message for kids ("So close! Hop sooner to catch one!"), a small tip with an icon, and the best distance highlighted. Never a sad empty screen.
**N8-03** Count-up animations, a celebration for a new best or a new car, calm under Reduce Motion, perfect at phone landscape.
**N8-04** The "Earn faster" Shop card from Round 1 can sit on this screen if it fits without nagging (once per session at most).

## N9. Shorter, simpler tutorial
Adam's decision 5 and his notes.
**N9-01 Steps:**
1. "Go to Downtown!", with the sub-hint "Press START!" on the Launch Pad
2. "Hop to a car!"
3. "Hold on!", then "It's yours!"
4. "Go home!"
5. "Park your car!"
6. Done ("You're ready!")

Raceway upgrade and Shop become **one-time contextual hints** later (for example the first time the player has enough Cash for an upgrade, and the first time they come back home after a few runs). Never block play.
**N9-02 Banner:** much smaller and skinnier.
- Remove the "2 / 12" counter (a thin progress line is fine only if it costs no height).
- Headline in one line, with the green sub-line inside the same compact pill and centered.
- Total height about half of Round 2's, or less.
- It must never cover the run's important areas or block steering.
- Check at phone landscape first.
**N9-03 Arrows:** the chevrons go **in a straight line from the player directly to the target** (portal, ramp, paddock), sitting on the ground height under each chevron (raycast), updating every frame, bright yellow, flowing toward the target. Hide chevrons that would sit inside a solid object. Keep it readable over water and paving.
**N9-04 Test it for real** in the local beta, as far as Brian R's run allows. With the Launch Pad and the new results screen (HOME button) built by Lane 3, the "Go home!" step no longer depends on his missing HOME button. Record how far a real playthrough gets.

## N10. HUD changes
**N10-01** Move the Shop, Garage and Missions buttons to the **middle of the left edge** (vertically centered, a tidy column), keeping thumb reach and clearing Roblox's own buttons and the joystick on phones.
**N10-02** Make the **Cash display bottom left bigger**: a larger icon and number, still balanced with the stack. Check every size.
**N10-03** Re-check the whole HUD against the style guide (S-04) and fix anything off-style.

## N11. Missions and Settings
**N11-01 Missions:** redesign it with the style guide and the "AI-look" rules.
- Rewards look like real prizes (Cash piles, cosmetic previews), not text chips.
- The CLAIM button is the most exciting thing on a finished mission: bright, a pulsing glow, and confetti with a satisfying sound on press.
- Progress bars are chunky and readable.
- Each mission has a strong icon.

Reference: `R3-IMG-07-missions.png`.
**N11-02 Settings:** center the Replay Tutorial button properly in its top bar (and check every Settings row's alignment while there).

## N12. Round 2 leftovers and Claude's recommendations
- **Summit Worlds-on-road:** confirm in a real run, and capture frames.
- **Downtown ground beside the road** is plain grey in places: give it proper sidewalk, verge or curb treatment.
- **Re-score Round 2's weakest areas** with a fresh reviewer: Props, Arrows, Update Log, Customize, Phone layouts (they scored 3, and nobody re-scored them after the fixes).
- **Performance, measured properly:** define one repeatable method (the same seed, the same camera path, the same stand-ins, Play mode, live part count and frame time), and record island, each World and the Launch Pads against the ceilings. Fix the worst offenders (for example merge Dusty's and Downtown's new sign parts into meshes).
- **The dialogue card at locked portals:** trigger Coach Roxy's card when a player walks into a locked portal (Round 2 built it, but it didn't trigger).
- **Rare cases on join:** slow or failed image loads, and no data yet. Check each join screen degrades gracefully.
- **Recommended by Claude:** a short "first five minutes" playtest script in the ledger (what a new kid sees and does, minute by minute). Run it at the end on the local beta, and note every moment of confusion or boredom you notice, fixing what's in Lane 3.

## N13. Teammate messages
- **Brian R:**
  - the camera recommendation (N7) with frames
  - the Launch Pad flow and the START → run hook
  - the trail hook on the player's car
  - the results data the new end screen reads
  - again, briefly: the `"None"` scenery option and the tutorial events
- **Brian L:**
  - the scaling Cash packs formula and the rule that the server computes the grant at purchase time
  - the trails catalog and PREVIEW prices
  - the cosmetic tiers update
  - the Launch Pad purchases
  - links to his open earlier messages

## N14. Self-review (as Round 2, plus)
- Same-view checks for N1 (Adam's spots).
- Two fresh reviewers, two rounds. One gets the "AI-look" list (2.1) and the shop reference; one gets the world and Launch Pad references. All areas must score at least 4, or you explain why not.
- Every screen at phone landscape, tablet and desktop. Hover, press, gamepad and Reduce Motion on the new screens.
- Never call something done that wasn't checked in Studio.

## N15. Finish and final message
As before:
- checks, logical commits, push, update draft PRs #8 and #9 (no merge, no publish)
- update the board, log, ledger, decision note, `vault/design/assets.md` and the style guide
- save the places with dated backups

Then a **short** terminal message and `review\round3\RESULT.md`:
1. What to open first (the local beta file) and what to try.
2. One line of status per N module.
3. "Choices I made", the notable ones.
4. Steps that need Adam's hands (the single upload), with exact clicks.
5. Teammate messages.
6. Known issues and what wasn't tested.
7. Ideas for next round, kept separate.
