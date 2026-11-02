# Car Hop: Lane 3 Round 2 (fix what Adam found, then make the HUD, Shop and screens look amazing)

**For:** Claude Code, on Adam's Windows laptop, repository `Roblox-Game-1` (GitHub `agertskis-maker/Roblox-Game-1`).
**From:** Adam (repository owner, Lane 3 owner: World, UI & Feel), written with Claude (claude.ai) on 2026-11-01. Lines marked **[ChatGPT]** were added by ChatGPT.
**Task folder (outside Git):** `C:\Users\agert\Documents\Car-Hop-Art\review\round2\`
**Builds on:** Round 1 (`C:\Users\agert\Documents\Car-Hop-Art\review\map-fixes\BRIEF.md`, its `RESULT.md`, branch `feature/lane3-big-round` with draft PR #8, branch `integration/beta-2` with draft PR #9, ledger `vault/design/specs/lane3-big-round-ledger.md`, decision `0031-lane3-big-round.md`).

This is one long, autonomous work session. Read this whole brief once, then work through it in the order in section 4.

**Round 1's rules still apply** unless this brief changes them: read sections 2 (authority and judgment), 2.2 (hard lines), 2.3 (steps that need Adam's hands), 3 (ledger), 5 (quality bar) and 19 to 21 (self-review, finish, final message) of the Round 1 brief before you start.

---

### [ChatGPT] Editorial notes and evidence limits, 2026-11-01

[ChatGPT] This is an additive improvement. Adam's quoted words, original requirement IDs, ownership changes and hard lines remain unchanged. All new dimensions, durations, budgets and preview prices below are design starting values, not verified Roblox limits or competitor prices unless a source is attached. Tune them against the evidence and record the reason. A good-looking reference does not prove a working implementation.

[ChatGPT] Context inspected: the existing Roblox-Game-1-biground checkout, decision 0031, the board and outline; current Raceway path/track implementation and relevant UI implementations; Round 1 brief, result and issues; all six new screenshots; the supplied A/B frame contact sheets and enlarged key panel frames; Round 1 shop contact sheet and tutorial reference; all ten generated reference concepts. Frame sampling can show layout and state changes, but cannot establish exact easing, sound, short transition timing or behavior between samples. Such motion below is a proposal, not a measured property of the reference games. Source frame names in the inventory make the observations auditable.

[ChatGPT note] Generated art corrections: icon-*.png files were not produced; IMG-04 is a labeled sheet, not a transparent atlas. IMG-01's pit angle is still steeper than requested. IMG-02's inset has contradictory arrows and is not a construction diagram. IMG-05 adds an unapproved extra currency counter: do not implement it. IMG-03's bundle art must use the actual three approved pass meanings. Read chatgpt-images/GENERATION-NOTES.md. Written requirements win over these errors.

[ChatGPT note] Preserve current approved tokens. AGENTS.md in the biground checkout specifies Fredoka One and minimum touch targets of 48 px, 56 px for primary actions. The older 44 px text in this brief is inconsistent. Use the stronger existing approved minimum, measured after all UIScale transforms. The inherited task-specific Figma exception permits Studio-first work when Figma is unavailable; it does not repeal the repository-wide rule.

[ChatGPT] This editorial pass changes no repository file, board, branch, Studio place or asset ownership. Claude Code performs the existing setup when it executes the finished brief. Keep the inherited one-lead-agent policy: no Opus worker swarm, at most two narrow Sonnet workers active, no recursive delegation. Reuse two independent reviewer agents for the two required review rounds, giving them fresh final evidence. Only the lead operates Studio, integrates branches or commits.

[ChatGPT note] "No merge" means no PR merge into main. The explicitly requested merges into feature and integration/beta-2 are still part of R-01. Check clean state and worktree occupancy first. Never switch the branch beneath an active Rojo server. No instruction here authorizes editing Brian R's or Brian L's files.

## 0. What Adam said after walking through Round 1 (his words, lightly trimmed)

> "The lines on the racetrack just aren't lining up. At the entrance onto the racetrack from outside, from the parking lot, the lines aren't cohesive. They don't line up at all. Even the pale, brownish-whitish-colored square doesn't even attach to the racetrack, and there are white lines bordering the roads that are just overlapping. It doesn't look clean or right. That all needs to be fixed, and I believe I actually told Claude Code to fix that before, so I'm not sure why that wasn't fixed."

> "The white fences: there are two white fences, one on each side. There's one outside of the fastest stunt circuit sign. I want that sign to be rotated to face in correlation to how the road is facing, more towards the middle, towards the center where the fountain is. I also want to delete the fence outside of it, as well as the same fence on the other side."

> "There are still some trees that are combined into each other, so just separate those and spread them out."

> "The loop... for the last level of the racetrack really needs to be fixed because it still doesn't look wide enough. The cars still look weird going around it in a weird manner... make it wider... research what a racetrack looks like... it just looks horrible right now."

> "For the shop... I just want the colors to be way more vibrant, in the same way that we made the shop icon move in a rainbow. I want the pop-ups in the starter packs and other kinds of things also [to have] moving background[s]: the gradient... in the background of the shop, I want that to be moving. Make it look way more vibrant."

> "The icons are absolutely horrible... In the double lap pay, the 2x button just looks really weird... maybe the font... Some of the icons in the starter pack make no sense at all."

> "For the stunt circuit... I'm not going to be responsible for building that. We're going to have Brian R be responsible for building that."

> "For the stunt customization, like the decals, the paint, and the wheels... the paint costs money and we should have different gradients of paint that cost more and more money. We should have some cool decals... cool different kinds of wheels... take inspiration from... Rocket League customization."

> "[Stunt results pop-up:] There's a bunch of blue space in the middle."

> "The Summit Chase is good. The tutorial is all right... the 'Go to Downtown' one has some weird purple icon. It doesn't make any sense. I feel like that green line, 'Walk into the Downtown Portal,' should be more centered in the black box."

> "For the 'Welcome Back'... there's just a lot of blue space on the screen. It just looks really bad... [the reference] has a cool animated video with the pets jumping around. We could do something just similar to our game. It also has the arrows that point somebody towards something that we would be able to use in a tutorial, or maybe a while after a player joins back."

> "[The HUD in the two reference videos is] just so insanely good... I want to take very, very heavy inspiration... Take factors that you like from both of them, implement them, and tailor it to our own game so it actually makes sense for what our game is."

**The goal of this round:** everything Adam flagged is fixed for real (verified from the same camera views he used); the HUD, Shop, tutorial, welcome-back card, customization and results screens reach the polish of the reference games; and every home screen runs in the beta so Adam can play the real flow.

---

## 1. Read these first

1. Round 1 brief, `RESULT.md`, the Round 1 ledger and decision 0031, and the two teammate messages (`vault/design/specs/lane3-big-round-for-brian-r.md`, `...-for-brian-l.md`). Check every Replies section in `vault/design/specs/*-for-brian-*.md` again: any reply changes what you may do.
2. `AGENTS.md`, `vault/tasks/BOARD.md`, the latest log.
3. **Adam's new screenshots** in `review\round2\screenshots\`. All were taken in Studio Play in `CarHop Island Test (private)`, **Plot 3**:
   - `r2-01-raceway-pit-entry-lines-cross-level6.png`: Level 6. The side road and pit lane meet the track with white lines that run into and across each other, and the track's inner curb line meets the side road badly.
   - `r2-02-raceway-side-road-lines-cross-track-level6.png`: Level 6, close up. The side road's white lines cross the main track surface, its edge line continues into the track, and the tire wall stops abruptly at the junction.
   - `r2-03-raceway-grandstand-barrier-level9.png`: Level 9. The white wall blocks along the track edge step up and down unevenly, the tire wall's red end piece overlaps the wall, and a snack cart stands alone on open grass next to the light tower.
   - `r2-04-raceway-path-not-attached-level12.png`: Level 12. The pale paved path from the parking side stops on the grass short of the track wall, and the track's outer white wall and edge lines double up.
   - `r2-05-stunt-leaderboard-sign-and-fence.png`: the "FASTEST STUNT CIRCUIT" board faces the wrong way, and a white picket fence stands in front of it (another fence stands on the other side). Also visible: a low cyan info board lying almost flat on the ground near the portal pillar.
   - `r2-06-trees-merged-near-stunt-gate.png`: a pink blossom tree and a green bush grow into each other next to the Stunt Circuit gate.
4. **References** in `review\round2\references\`:
   - `hud-ref-A-pet-game.mp4` (109 s, with audio) and `frames-A\a-01.jpg` to `a-36.jpg` (one every 3 s), plus `hud-ref-A-contact-sheet.jpg`. It is the same game as the Round 1 shop reference. Watch for: the **Welcome Back card** at 0:00 to 0:02; the ground chevron trail to the next target; the "UNLOCK!" bubble over a portal; the top notification pills ("3 PETS LEVELED UP!", "NEXT ISLAND READY!" with a progress bar); the left square buttons (Shop, Trade); stacked currencies bottom left with a "+X/s" rate; the right column of round icon buttons; the big bottom-center action button with a floating gain number; and the Settings, Titles, Updates, Height map and Trade panels (clean white cards, colored headers, toggle rows with icons, a red X).
   - `hud-ref-B-dino-game.mp4` (73 s, with audio) and `frames-B\b-01.jpg` to `b-24.jpg`, plus `hud-ref-B-contact-sheet.jpg`. This is the dinosaur-catching game already analysed in project doc `claude/11_REFERENCE_DINO_STAMPEDE_ANALYSIS.md`. Watch for: the wide labeled **Shop and Index** buttons on the left with notification badges; the dark top instruction strip ("Catch more dinos to earn more money!"); the **Update Log** panel on join; the floating world text "You earn $100.8K/Day offline!"; the in-world "$6/s" earnings labels; ground circles and painted "START ZONE" chevrons; the **Index** with world tabs, silhouettes, "Unlocked 4/63", per-world completion rewards and "CLAIM ALL"; the **character dialogue cards** (portrait, typed speech bubble, progress bar "YOUR STAMINA 8 / 250, 86 TO GO", "GOT IT!"); the cosmetic aura cards; and the bottom-right timers.
   - Round 1 references still apply: `review\map-fixes\references\` (shop video and frames, HUD picture, tutorial outline).
5. **ChatGPT reference images** in `review\round2\chatgpt-images\` (made from `CHATGPT-IMAGES.md` in the task folder). Expected files: `IMG-01-raceway-junction.png`, `IMG-02-raceway-loop.png`, `IMG-03-shop-featured.png`, `IMG-04-icon-sheet.png` plus individual `icon-*.png` files, `IMG-05-customize-garage.png`, `IMG-06-stunt-results.png`, `IMG-07-tutorial-banner.png`, `IMG-08-welcome-back.png`, `IMG-09-hud-home.png`, `IMG-10-npc-dialogue.png`. **If an image is missing, design from the text of `CHATGPT-IMAGES.md` and the videos, and say so in the final message.** The images are targets for layout, hierarchy and feel; where an image and this brief disagree, this brief wins.

### 1.1 How to use the reference games (important)
Adam wants **very heavy inspiration**: match the reference games' layout patterns, proportions, button sizes, screen placement, color energy, outline weight, motion and interaction behavior closely, adapted to Car Hop's systems. That is allowed by the project rules (decision 0004: imitating shape language, outlines, rounded panels, palette mood and layout patterns).

What you must **not** do: extract, trace, screenshot-crop or reuse any image, icon, character, logo, name or text from the reference videos, or make a pixel-identical copy of one of their screens. Copying another creator's art can get Car Hop taken down, and the repository rules forbid it. All pixels in Car Hop are Car Hop's own: ChatGPT-made original icons (section N5), Studio-built UI, and Blender meshes. Where a reference uses something Car Hop doesn't have (pets, eggs, rebirths, trading, titles), use the Car Hop equivalent or leave it out.

---

## 2. Authority, judgment and what changed since Round 1

- **Same authority as Round 1:** decide everything reversible yourself, record it, never stop to ask Adam, fix your own mistakes, and show him the result at the end.
- **New:** Round 1 reported the Raceway joints as done, but Adam still found the same problems. In this round, **a fix counts as done only when it is verified from the same camera view Adam used** (section N16): reproduce each screenshot's view (Plot 3, the same Raceway level, a similar camera angle) before and after, put the pairs side by side in `review\round2\evidence\`, and have a fresh reviewer compare them against Adam's screenshot. Automated checks are required but **not sufficient** for visual problems.
- **Stunt Circuit ownership changed (Adam, 2026-11-01):** **Brian R builds the Stunt Circuit course and its gameplay.** Lane 3 keeps only the Stunt Circuit **screens** (pre-race, results, leaderboard, customization) and the **gate and leaderboard sign on the island**. Do no more work on the course look-dev in `src/lookdev/Stunt`. Hand it over in Brian R's message as an optional starting kit he may use, change or discard, and record the change in this round's decision note.
- **Cosmetics cost Cash (Adam's direction):** paint, decals and wheels are bought with in-game Cash, in tiers that get fancier and pricier. Exact prices are Brian L's (economy is propose-first), so show clearly named PREVIEW prices and send the tier proposal to him (N12).
- **BEST DEAL spotlight back on:** Round 1 turned the BEST DEAL ribbon off because prices aren't real. Turn it back on in the preview whenever it is true **within the PREVIEW catalog** (the bundle is cheaper than the sum of its parts in the same fixture). The honesty rules still hold: never label something best value when the numbers in the shop don't show it.

---

## 3. Setup

**R-01** Read `AGENTS.md` and the board. Pull `main`. Continue on **`feature/lane3-big-round`** (draft PR #8): pull it, merge `main` into it if `main` moved, and keep updating PR #8. Keep **`integration/beta-2`** (draft PR #9) up to date by merging the feature branch into it as you go.
**R-02** Claim a board row "Lane 3: Round 2 (Adam's review fixes, HUD, Shop, screens in the beta) - Adam, with Claude Code, 2026-11-0X" with the branches and this brief's path; commit and push only that board change to `main`.
**R-03** Ledger: `vault/design/specs/lane3-round2-ledger.md`, one row per requirement ID below, updated after every module. Copy this brief to `vault/design/specs/lane3-round2.md`. Reserve the next decision number in `Car-Hop-Art\DECISION_NUMBERS.txt` (0031 is the last used) for `vault/decisions/00NN-lane3-round2.md`.
**R-04** Places: `CarHop Island Test (private)` for N1 to N4, the HUD place (`Car-Hop-Art\CarHop-BigRound-HUD.rbxl`) for UI work, and **the local beta file** (`Car-Hop-Art\CarHop-Beta-2-local.rbxl`) for N13 and every final UI check. Save dated backups before overwriting any place.
**R-05** Image uploads (needed for the new icons and any UI art): check first whether an Open Cloud API key with asset-upload permission for the group LEGION STUDI0S (74306252) is available in the environment variable `ROBLOX_OPEN_CLOUD_KEY`. If it is, verify the current official Open Cloud Assets API in the Roblox documentation and upload the images yourself with the group as creator (never print, log or commit the key). If it is not, prepare one bulk-import package (images trimmed, named and listed in a manifest, plus exact click steps for Studio's Asset Manager bulk import with the group selected) and keep working; Adam does that one step at the end. Until uploaded, the UI must still look finished, using the best existing art (see N5-04).

---

## 4. Run order
1. N1 Raceway junctions and lines → N2 Raceway loop → N3 Raceway barriers, paths and props → N4 Island fixes (sign, fences, trees, leftovers)
2. N5 Icons → N6 Shop → N7 HUD → N8 Tutorial → N9 Welcome back → N10 Garage / Index → N11 Dialogue cards and Update Log → N12 Stunt screens and customization
3. N13 Everything running in the beta
4. N14 Round 1 leftovers → N15 Teammate messages → N16 Self-review loop → N17 Finish and final message

Use subagents for non-Studio work in parallel (icon processing, code modules, research, reviews). Only one agent drives Studio at a time.

---

## N1. Raceway junctions and lines (fix for real this time)

Code: `src/shared/Island/Speedway/*` (`Track`, `Path`, `Parking`, `Ladder`, `Props`, `Look`, `Kit`). Reference: `IMG-01-raceway-junction.png`; screenshots `r2-01`, `r2-02`, `r2-04`; Round 1 `ISSUES.md` C6 and screenshot `03`.

**N1-01 Find the root cause first and write it in the ledger.** The same overlaps survived Round 1, so understand why: for example road pieces built as overlapping rectangles, paint lines generated per piece without knowing about neighbours, or junction pieces added after the line pass. Fix the cause, not each symptom.
**N1-02 One road network per plot and level.** Build the track, the pit lane, the side road and the paddock as one connected network: centerlines with widths, explicit junction nodes, and junction surfaces shaped as one polygon (no stacked rectangles). Generate the paint lines from the network: edge lines stop exactly where a junction mouth opens, continue neatly around the junction corners, and never cross another road's surface. A short dashed merge line marks each split and merge. One marking language everywhere (Round 1 M4-01).
**N1-03 Pit lane and side road:** they split from and rejoin the track at a shallow angle, at the same height, with the same asphalt and line style, as in `IMG-01`. Tire walls and white wall blocks end with proper end caps where a road opens. Nothing overlaps.
**N1-04 Paddock, parking and walkways:** the concrete paddock and the parking area are flush with and attached to the roads they serve, with no grass gap, no dark strip and no step. The pale paved path from the parking and plot side (`r2-04`) ends **at** a proper opening or gate in the track's outer wall or fence, touching it, or is rerouted so it joins the paddock. No path dead-ends on grass anywhere on the plot.
**N1-05 Double lines:** where a wall and an edge line run side by side (`r2-04`), there is exactly one clean white line with an even gap to the wall.
**N1-06 Line checker:** add checks (extend `SpeedwayChecks` or the M1 overlap scanner) that fail when a paint line's footprint crosses another road surface, when two paint lines overlap, when a line ends inside a junction polygon, or when a walkway endpoint is more than 0.5 studs from a road, gate or paved area. Run it on **every plot at every level 1 to 12**. Zero findings is required.
**N1-07 Done when:** the checks are zero everywhere, and before and after pairs from Adam's views (`r2-01`, `r2-02`, `r2-04`) plus a straight top-down view of each junction on Plot 3 at levels 1, 6 and 12 are saved in `evidence\`. A fresh reviewer, comparing them to Adam's screenshots and `IMG-01`, finds no crossing, overlapping, floating or disconnected line or surface.

### [ChatGPT] N1-01a Network construction and diagnosis

[ChatGPT] First reproduce r2-01, r2-02 and r2-04 before changing geometry. In Track.luau, inspect inPitGap, splitRuns and per-segment slab overlap. A predicate that filters sampled points can omit the actual mouth boundary or leave paint protruding past it. This is a code-based suspect, not a confirmed runtime diagnosis. Also trace pit/side-road builders outside Track so they cannot independently add a second line across the same opening.

[ChatGPT] N1-02a Use plot-local 2D coordinates for ground roads. Each edge records its centerline, width, elevation, junction ID and allowed markings. For each junction, trim incident road strips back to calculated mouth cross-sections; sort mouth endpoints around the junction; create one simple boundary polygon, then triangulate its interior without overlapping triangles. Share exact endpoint vertices with neighboring road strips. Reject self-intersections, duplicate vertices and near-zero-area triangles before building. Convex-hulling the entire road network would incorrectly fill the grass between roads. Handle individual junctions only.

[ChatGPT] N1-02b Generate boundary paint after surfaces, from the final external boundary and tagged mouth intervals. Subtract each mouth interval analytically from the boundary curve, then sample the remaining intervals. Do not just hide lines whose midpoints fall inside a junction. Add only the explicitly designated dashed merge marking inside the mouth. The same mouth data cuts barriers, curb runs and fence openings. Keep the existing no-centerline decision. IMG-01 contains center dashes that do not override it.

[ChatGPT] N1-03a Proposed starting geometry: 15 to 25 degrees for a pit fork; widen turns enough for the current car envelope; use a filleted or bevelled corner instead of a long acute miter spike. Start at 0.05 stud positional tolerance for matching surface endpoints and 0.1 stud vertical tolerance for a flush pedestrian joint. The existing 0.5 stud checker threshold is a maximum detection limit, not a desirable visible gap. A walkway must reach an actual unobstructed opening, not merely pass within 0.5 studs of a closed wall.

[ChatGPT] N1-06a Classify comparisons. A paint line necessarily overlaps its own supporting asphalt in plan view, so the literal "crosses another road surface" rule needs ownership tags. Fail solid boundary paint inside a junction mouth or unrelated drivable interior; allow its own support, tagged merge dashes and the start/finish marking. Test actual strip polygons, not just center points or broad bounding boxes. Exclude invisible construction helpers by explicit tag, not by swallowing all intersections.

[ChatGPT] N1-06b Keep a single surface-height convention and place paint relative to the local road normal. Retain a consistent tested paint separation; do not stack more asphalt under a seam to hide it. Butt-joint visible surface triangles. Tiny hidden underlap may support collision continuity, but duplicate exposed coplanar faces are not a fix. Roblox spatial bounds queries are broad-phase tools, not proof that arbitrary mesh surfaces overlap: refine candidate pairs with your polygon/plane math and visually inspect meshes. [WorldRoot API](https://create.roblox.com/docs/reference/engine/classes/WorldRoot)

[ChatGPT] N1-07a Done when: reproduce known-bad crossing, duplicate-paint and grass-gap fixtures and prove the checker detects each before testing fixes. Produce a plot-by-level matrix, not just a total of zero. Save Plot 3 junction close-ups with the camera CFrame, FOV, level and code commit; compare the whole junction and the walkway opening. Rebuild twice and verify identical surfaces/markings and no duplicated descendants.

## N2. The Raceway loop (rebuild)

Reference: `IMG-02-raceway-loop.png`; screenshot `r2-04` and Round 1 screenshot `06`. Adam: still not wide enough, and the cars move around it strangely.

**N2-01 Research** how real stunt loops on tracks are built (for example toy-car loops, stunt-show loops and the famous full-size car loops at motor shows), and write 5 to 10 lines of findings in the ledger. Known facts to confirm: a car loop is a **teardrop (clothoid)** shape, tighter at the top than at the bottom, rather than a circle; the **entry and exit are side by side**, offset sideways by about one lane width, so the car comes out next to where it went in; the approach and exit straights are long and straight; the loop surface has walls or curbs on both edges; and supports are clean and regular.
**N2-02 Geometry:** where the loop stands, widen the straight to at least two full track widths with smooth tapers (length at least 3 times the extra width) before and after. Build the loop as a teardrop from a continuous centerline whose sideways offset grows from the entry lane to the exit lane over the loop. The loop surface is one smooth ribbon (enough segments that no facets show from the walkway), the same asphalt, with the track's edge lines and curbs continuing onto it, and it is attached to the track surface at both ends with no step or gap. Add clean blue steel supports and cross braces.
**N2-03 Cars through the loop:** the decorative lap cars follow the loop centerline with the correct orientation all the way around (their roof faces the inside of the loop and they are upside down at the top). The orientation is built from the path's tangent and the loop's inward normal, never by rotating around a fixed axis. They keep a believable speed (slowing slightly on the way up, speeding up on the way down) and never clip through the loop, the walls or each other. Cars that don't take the loop pass beside it on the widened straight.
**N2-04 Fits the levels:** the loop appears at the levels where Round 1 put it (keep the level ladder), and the widened straight looks intentional at every level that has it.
**N2-05 Done when:** a Studio Play recording (with game audio) shows at least three cars going through the loop from the walkway's viewpoint and from the side, plus stills that match `IMG-02` in shape, width and attachment. The M1 scanner reports zero findings on the loop, and a fresh reviewer agrees it looks like part of the track.

### [ChatGPT] N2-01a Research, actual scale and a buildable method

[ChatGPT note] Not every real stunt loop is a clothoid, and a sideways offset of exactly one lane is not a universal engineering rule. The brief's desired teardrop and adjacent entry/exit are Car Hop design choices. Coaster research supports a larger curvature radius low in the loop and smaller radius at the apex, with smooth curvature transitions. A clothoid specifically varies curvature with arc length; an arbitrary oval is not a clothoid. [Published loop-shape study](https://doi.org/10.1088/0031-9120/51/3/030106), [Applied Mechanics loop analysis](https://mechanics.ju.se/Kinetics/RollerCoaster.html). Full-size stunt-car approach lengths and offsets at this game's scale remain unverified. Do not call a game proportion a real-world safety standard.

[ChatGPT] N2-02a Verified local baseline: Track.luau uses Path.HalfWidth = 8, so the ordinary ribbon is 16 studs wide. Path.luau currently has Straight = 103.594, Loop.Radius = 10, Loop.Width = 10, Offset = 12, Runout = 6, SBend = 16; Track adds only 7.5 studs of widening. The current loop is a circular helix with a constant sideways derivative, including at the endpoints. Check that tangent mismatch against the approach: it is a plausible source of the visible sideways snap.

[ChatGPT] N2-02b Proposed starting envelope for the stated 9 to 12 stud car length: loop road width 16 studs or measured car width plus 4 studs, whichever is larger; adjacent loop ribbons offset by ribbon width plus 2 studs so edges do not intersect at their bases; apex height roughly 36 to 48 studs; lower bend radius about 24 to 30 studs and tighter apex around 12 to 16 studs. These are look-development ranges, not a solved curve. Measure actual car width, wheelbase, height and pivot first. Keep at least 2 studs outside the swept car bounds before a support or wall.

[ChatGPT note] Two 16-stud ribbons plus a 2-stud separation already need a 34-stud envelope. Widening from 16 to 34 implies at least 54-stud tapers at each end under N2-02's 3x rule. Two such tapers exceed the current 103.594-stud straight before the loop footprint is included. Do a footprint feasibility pass first. Reorganize Lane 3's local plot geometry within its owned footprint, or document a precise blocked fit if it requires another lane's contract. Do not silently shorten the tapers, shrink cars, move neighboring plots, or claim all constraints fit. A bypass must also fit its own width and clearances.

[ChatGPT] N2-02c Construct a smooth closed-turn vertical centerline in a local forward/up plane. One defensible method integrates a continuous curvature schedule: theta(s) = integral kappa(s) ds, forward(s) = integral cos(theta(s)) ds, height(s) = integral sin(theta(s)) ds. Start/end curvature at zero, use broader transitions below and tighter curvature above, and solve the segment parameters for a total turn of 2*pi, zero endpoint height difference and horizontal matched endpoint tangents. If using cubic/quintic spline approximations instead, call them teardrop approximations and check curvature continuity. Mirroring an unsolved half-curve does not guarantee the correct joins.

[ChatGPT] N2-02d Add lateral offset D*f(t), with t in [0,1] and f(t) = 6*t^5 - 15*t^4 + 10*t^3. Its first and second derivatives vanish at both ends, avoiding a sideways kink. Recompute 3D arc length after adding this offset. Build a cumulative length table, binary-search it for a desired distance, and interpolate within its interval. Uniform parameter increments are not uniform distance. This method and proportions are our implementation proposal.

[ChatGPT] N2-03a At every sample derive tangent T from the curve derivative. Derive a reference inward normal from the unwrapped vertical turning angle, project it perpendicular to T and normalize it to U. At straight transitions, parallel-transport the previous frame and blend toward the known road-up frame; never use world-up alone at a vertical tangent. Form R = T cross U, then U = R cross T. Construct CFrame.fromMatrix(position, R, U, -T), which makes local -Z face travel, or use CFrame.lookAt(position, position + T, U). Apply the car's fixed pivot correction once. Roblox documents both frame constructors. [CFrame reference](https://create.roblox.com/docs/reference/engine/datatypes/CFrame)

[ChatGPT] N2-03b Car wheels must sit on the same sampled surface used to create the ribbon. Derive the pivot-to-contact offset from the model bounds/wheel reference, not a guessed universal half-height. Sample the car's whole swept envelope, including nose and tail on tight bends. The approximate chord sagitta L^2/(8R) explains why a long rigid car may intersect a tight curve even when its pivot is on the centerline. Check at 0%, 12.5%, 25%, 37.5%, 50%, 62.5%, 75%, 87.5% and the seam, plus continuously through three full laps.

[ChatGPT] N2-03c Keep Lap Pay and authoritative lap timing unchanged. If adding visual speed variation, choose a positive speed-weight curve, for example 0.85 near the top and 1.10 low down, integrate travel time ds/v(s), and normalize the whole-lap duration to the existing lap phase. Reuse the same mapping for each car. Maintain enough arc-distance spacing for 12-stud cars plus a starting 2-stud buffer even at the slowest part; if the lineup cannot fit, adjust the visual staging, not income or ownership. Kinematic decorative cars do not need physical adhesion forces. Do not change gravity or Brian R's race physics.

[ChatGPT] N2-05a Adaptive tessellation starts with a 0.1-stud chord-error target and at most 3-degree tangent change per segment, then simplify until the walkway view remains smooth within scene budgets. Test all plot bearings, level 11 to 12 and back, maximum visible cars, two rebuilds, Reduced Motion and three laps. Acceptance: no position discontinuity above 0.05 stud at joins, no abrupt orientation step above 3 degrees at a join, unit orthogonal frame axes, no NaN, no roof/wheel/support penetration, no unexpected sideways flip. Record measured maxima. IMG-02 is a silhouette/color reference only; its inset fails this geometry test.

## N3. Raceway barriers, props and the plot layout around the track

**N3-01 Barriers:** the white wall blocks along the track edge form one even, continuous wall (no uneven steps, as in `r2-03`); tire walls run in tidy straight or curved runs with end caps and never overlap the wall. Check every level.
**N3-02 Props:** keep race props in their zones (Round 1 M4-05). A concession cart is fine near the bleachers if it stands in a clearly made spot (a small paved pad next to the stands, maybe with a second stall and a bench), not alone on open grass by a light tower. Light towers stand upright on a proper base.
**N3-03 Walk every plot at levels 1, 6, 9 and 12** and fix anything else that looks unfinished: gaps, floating pieces, overlapping fences, wrong-facing signs.

### [ChatGPT] N3-03a Physical polish checks

[ChatGPT] Build a wall run from one baseline and cap height, with shared joints. On level ground, adjacent cap heights differ by no more than 0.05 stud; intentional banking follows one continuous profile rather than alternating block heights. End tire runs before the cap footprint. Keep concession pads connected to the pedestrian route, leaving a starting 6-stud clear walking corridor. Group the cart, bin and bench deliberately rather than filling every empty area with props. Verify collision with an avatar, not only a camera.

[ChatGPT] Capture level 9 from r2-03, then walk both directions through every gate. Record the actual plot/level coverage, maximum cap mismatch and remaining intersections. Never declare an unvisited plot visually checked merely because its generator is shared.

## N4. Island fixes

**N4-01 Fastest Stunt Circuit board (`r2-05`):** rotate it to face the center of the island (toward the fountain), lined up with the path it stands beside, so a player walking from the plaza reads it head-on. Remove the white picket fence in front of it **and** the matching fence on the other side of the path. Make sure the board stands on proper ground with a base, and that nothing blocks its view from the plaza.
**N4-02 The low cyan info board near the portal pillar (`r2-05`, left):** if it is lying flat or tilted, stand it up properly or remove it.
**N4-03 Trees (`r2-06`):** no tree or bush may intersect another tree, bush, sign, gate, lamp or building. Add a canopy-spacing check (a minimum distance between canopy bounds plus a margin) to the island checks, and move or remove offenders. Spread trees naturally, keep the park's symmetry where it is designed, and keep the sightlines to the portals and the Stunt gate open. Check the whole island, not only the Stunt gate.
**N4-04 Round 1 leftovers on the island:** convert the island signposts to the sign family (Round 1 M5 was partial), do the slow walk-through past every building looking for flicker (Round 1 M1 was not done), and record the result.

---

### [ChatGPT] N4-04a Readable signs and planted space

[ChatGPT] Aim the leaderboard's front toward the approach from the fountain, using the horizontal vector between its reading position and the plaza approach. Stand at avatar eye height along that approach and confirm the text face, not its back, is visible. Remove both named picket runs, not all island fences. Give the cyan sign a deliberate upright mount or remove the redundant sign entirely; record the choice.

[ChatGPT] Check vegetation at whole-plant bounds, excluding overlaps among parts of the same plant. Start with 1 stud between separate canopy envelopes and 2 studs from signs, lamps and portal frames. Use bounds as a conservative first pass and inspect irregular crowns. Preserve intentional planting groups while removing interpenetration. Verify the blossom/bush pair from r2-06 and inspect portal silhouettes from spawn, plaza and each approach. Walk all building edges slowly in Play to expose flicker; a stationary screenshot cannot pass that check.

## N5. Icons (replace the current family)

Adam: the current icons are "absolutely horrible"; the Double Lap Pay "2x" looks weird (probably the font), and some Starter Pack icons make no sense.

**N5-01 Use ChatGPT's original icons** from `chatgpt-images\` (`icon-*.png`, or cut them out of `IMG-04-icon-sheet.png`) as the new icon family. Process them consistently: trim, square, center with the same padding, remove any background so it is transparent, make sure the outline weight and light direction match, and export at 256 and 512 px. Pack them into atlases only if that is simpler for uploads (Roblox image uploads have size limits; verify them in the current docs). If an icon is missing or weak, make a matching one yourself (a Blender render with the same look) or use the closest good icon, and record which.
**N5-02 Upload** (R-05), then wire the icons into the UI kit: one icon module where each icon name maps to an asset id plus a fallback, used by every screen.
**N5-03 Replace every icon in the game:** Home menu, HUD, Shop (including every Starter Pack item and the Double Lap Pay card), Garage and Index, Missions, Settings, tutorial banner, portal card, dialogue cards, results, customization, welcome back, group pop-up, loading screen. Every icon must clearly mean what it labels; if an item has no clear icon, use its own art (for example a paint swatch for a paint).
**N5-04 Before the upload lands:** the screens must still look finished. Use the best available existing images, or code-drawn shapes in the new style, and swap in the new icons as soon as their ids exist.
**N5-05 The "2x":** Double Lap Pay's 2x is drawn into the icon art (a bold, rounded "2x" on a gold coin), not typed in an unsuitable font. Where text is needed, use the HUD's chunky outlined display font.

### [ChatGPT] N5-01a Asset preparation and verified upload paths

[ChatGPT] The individual icon files are currently missing. The sheet includes labels and a background, so a rectangular crop alone is not production art. Export clean transparent originals with no label fragments or colored matte fringe. Keep approximately 10% internal padding and a consistent light from upper left. Inspect each at 32, 48 and 64 displayed pixels against white and navy. Keep labels as UI text except the requested 2x artwork. Use a manifest with logical key, local filename, dimensions, hash, creator, uploaded asset ID, operation status, moderation/display status and fallback. Do not fabricate IDs.

[ChatGPT] N5-02a Official Open Cloud limits: one asset per create request, up to 20 MB, image dimensions strictly smaller than 8000 by 8000; PNG, JPEG, BMP and TGA are supported. Image/decal content updates are not supported by that upload route, so track replacement uploads explicitly. POST multipart data to https://apis.roblox.com/assets/v1/assets with an x-api-key header, a request JSON field containing assetType Decal, displayName, description, and creationContext.creator.groupId set to string 74306252, plus the image as fileContent. The guide documents this request shape. [Assets usage guide](https://create.roblox.com/docs/cloud/guides/usage-assets)

[ChatGPT] N5-02b Read the key without printing it. Confirm its resource permissions authorize the intended group before upload. Poll the returned operation using the documented Get Operation endpoint until done; record its error or resulting asset ID, not a guessed URL. Do not treat successful submission as successful upload. Use bounded retries for throttling/transient failure, stop on authorization failure, and reuse completed manifest entries to avoid duplicate assets. [Assets API reference](https://create.roblox.com/docs/cloud/reference/features/assets). Confirm the resulting creator and test each resolved image in an ImageLabel; an asset record alone does not prove the intended image loads.

[ChatGPT] N5-02c Upload limits differ from usable texture resolution: Roblox documents a maximum texture resolution of 4096 by 4096. The requested 256/512 PNGs are comfortably within both. Default to individual 512 PNGs; upload one resolution rather than duplicate both unless measurement justifies it. If using an atlas, include padding to avoid neighboring-icon bleed and record every rectangle. [Texture specifications](https://create.roblox.com/docs/art/modeling/texture-specifications)

[ChatGPT] N5-02d Manual package procedure: open Studio's Asset Manager from Window or Home, then its import control and select the prepared PNGs together. Alternatively use File > Import. In the import queue, inspect the Creator column for every file and select LEGION STUDI0S, group 74306252, where offered. Check filenames and enabled rows, then Import. After completion, right-click each imported item and Copy asset ID into the manifest. If the installed UI differs, record the actual labels and stop before uploading to the wrong owner. Viewing a group's inventory is not a substitute for verifying the import creator. [Asset Manager](https://create.roblox.com/docs/projects/assets/manager), [Importer](https://create.roblox.com/docs/studio/importer)

[ChatGPT] N5-02e Assets must pass moderation before use. Show the fallback while approval or loading is pending; never retry by bypassing moderation or silently uploading to Adam's personal account. [Project assets](https://create.roblox.com/docs/projects/assets). The final handoff should say which icons are uploaded and visible, pending, rejected or still local. Scan every listed screen for old icon references, then visually check the replacements; a search alone cannot catch a misleading icon.

## N6. Shop: way more vibrant and alive

Code: `src/client/UI/Prototype/Screens/ShopMock.luau`, `ShopKit.luau`, `Screens/Shop/*`, `src/shared/UI/ShopPreviewCatalog.luau`, `ShopPurchaseAdapter.luau`. References: the Round 1 shop video and frames, and `IMG-03-shop-featured.png`.

**N6-01 Color:** much more saturated and vibrant, like the reference: hot pink, electric purple, cyan, lime, orange and gold gradients, white outlined headlines, deep navy outlines. Each card gets its own strong color. No dull or greyish panels anywhere.
**N6-02 Moving gradients everywhere it matters:** the Shop button already cycles through a rainbow; bring the same life to the shop's page background, the hero card, the Starter Pack card and pop-up, the BEST DEAL banner, the pass cards' glow, and every offer pop-up (Starter Pack after the tutorial, group reward, "Coming soon"). Use slow animated gradient offsets and rotation (a full cycle every 4 to 8 s), a diagonal shine sweep every few seconds on hero and deal cards, gentle sparkles on the best deal, and a soft idle "breathing" scale (about 2 %) on the main price buttons. Performance: animate few properties, drive everything from one update loop that runs only while the shop is open, and stop it on close. Reduce Motion: keep the colors but stop the motion (or slow it to a very slow drift). Never more than 3 flashes per second.
**N6-03 BEST DEAL back on** (section 2), with "SAVE X%" computed from the PREVIEW catalog and the struck-through component sum.
**N6-04 Layout check against the reference:** the first screen (Featured) must be as exciting as the reference's first screen: a big hero carousel, side offer cards, a big deal banner and visible pass cards without scrolling on desktop; on phone landscape, the hero and one deal are visible without scrolling.
**N6-05 Fix the Round 1 gaps:** wire the Raceway parking panel entry point ("Get more spots" opens Expanded Paddock) and the Results "Earn faster" card, and mount the Shop in the beta (N13).
**N6-06 Keep:** no real purchases, no paid randomness, the honesty rules, PREVIEW prices, "Coming soon" on buy, 44 px touch targets, and hover, press, gamepad, owned and pending states.

### [ChatGPT] N6-02a Motion system, hierarchy and phone budget

[ChatGPT] Keep saturation in headers, art wells and offers. Put prices and descriptive copy on quiet contrasting surfaces; N6-01 does not require every square inch to glow. Use cyan/purple as the common Shop frame, gold for value, lime for action, and pink/orange for the featured offer. A single card should not use every accent equally. An unavailable offer stays attractive but visibly disabled.

[ChatGPT] Implement one scoped animator for visible shop effects. Register/unregister effect records on mount, visibility change and teardown. Use elapsed time rather than frame-count increments. Assign shared phases with offsets so neighboring cards are not synchronized. UIGradient exposes Offset and Rotation; keep Color and Transparency sequences stable. Use Offset and Rotation for the baseline; verify availability in the installed engine before using newer gradient properties. [UIGradient](https://create.roblox.com/docs/reference/engine/classes/UIGradient), [Appearance modifiers](https://create.roblox.com/docs/ui/appearance-modifiers). TweenService is appropriate for discrete transitions; don't start a new tween every frame or let two effects compete for the same property. [TweenService](https://create.roblox.com/docs/reference/engine/classes/TweenService)

[ChatGPT] N6-02b Proposed motion recipes, measured in seconds, not frames:

| [ChatGPT] Effect | Starting recipe | Limit and reduced-motion behavior |
|---|---|---|
| Page background | Offset.X = 0.15*sin(2*pi*t/8), Rotation = 12*sin(2*pi*t/8) degrees | One background; freeze at attractive midpoint |
| Hero/Starter card | Offset.X amplitude 0.25 over 6 s, Rotation oscillates 20 degrees around its base angle | One hero plus one secondary animated card on phone |
| BEST DEAL gold | Offset amplitude 0.2 over 5 s | Ribbon text itself stays still |
| Shine | Narrow translucent diagonal band traverses -1.2 to +1.2 over 0.7 s, then waits to next 6 s cycle | Hero and deal offset by 3 s; no simultaneous sweeps |
| Price button | Scale 1 to 1.02 and back over 2.4 s, sine easing | Only primary action; freeze on hover/press and under reduced motion |
| Sparkles | Up to 4 tiny pooled marks, 0.9 s fade/scale envelope, staggered starts | None on reduced motion; no large bright flashes |
| Open/close | 0.18 s opacity plus 0.97 to 1 scale, Quad Out; close 0.12 s | 0.1 s opacity only, keep focus stable |
| Press | Scale 0.97 in 0.06 s, return in 0.10 s | Immediate color/stroke feedback if reduced motion |

[ChatGPT] N6-02c Initial phone limits: at most 6 continuously animated gradient instances and 1 breathing button visible; no animation on offscreen cards; approximately 20 to 30 decorative updates per second through the shared driver, independent of input responsiveness. Target less than 1 ms incremental UI animation work per frame on the tested device, and record actual hardware, frame time and method. This is a project budget, not a Roblox guarantee. If it misses, remove sparkles and secondary motion first. A desktop emulator is a layout check, not a phone performance measurement. After 20 open/close cycles, no extra active animation registrations or connections remain.

[ChatGPT] N6-03a Compute savings only for identical included quantities and the same fixture currency: componentTotal = sum(individual prices * quantities); savings = floor(100*(componentTotal - bundlePrice)/componentTotal). Hide the badge if total is zero, data missing or savings is not positive. Label PREVIEW within the card, not only in a footnote. Do not invent scarcity, ticking deadlines, crossed-out historical prices or an actual purchasing route.

[ChatGPT] N6-06a Exercise every entry point, all tabs, scrolling, owned, pending, unavailable, preview buy, cancel, close, gamepad focus and reopen. The primary action remains visible above the bottom safe area. Keep the current preview adapter; never call purchase services to make the mock look interactive.

## N7. HUD overhaul (heavy inspiration from references A and B)

References: both videos (all frames), `IMG-09-hud-home.png`, Round 1's `hud-tutorial-reference.png`. Existing code: `src/client/UI/Prototype/Home/*` (`LeftMenu`, `CashLine`, `StatsStack`, `TimerStack`, `ToastStack`, `Layout`, `SettingsPanel`), `src/client/UI/RunHud` (the run HUD: keep its approved ENGINE HEAT design and placement; restyle only its chrome where it clashes).

**N7-01 Inventory first:** watch both videos and write, in the ledger, a list of every HUD element and panel you see, with its screen position, size relative to the screen, behavior, and whether Car Hop should adopt it, adapt it, or skip it (and why). Then design Car Hop's home HUD from that list. Suggested result (your call):
- **Left:** big labeled square or wide buttons, Shop (rainbow, with a red "!" badge when something is new), Garage (the car Index) and Missions, as in both references.
- **Bottom left:** stacked currencies with big glossy icons and huge outlined numbers: Cash with a green "+X/s" Raceway rate next to it and a green "+" that opens the Shop's Cash section; the Stamina bolt (if shown on the island); the cars-owned count "17 / 24".
- **Top center:** a notification pill for events ("RACEWAY LEVEL 5!", "NEW CAR!", "3 CARS EARNED $1,250"), and a goal pill with a progress bar for the next goal ("NEXT WORLD READY! Walk into its portal!", "Get 2 more Downtown cars"), as in reference A. They stack neatly and never cover the tutorial banner; while the tutorial runs, the tutorial banner takes this spot.
- **Right side:** a column of round icon buttons: Settings, Leaderboard, Daily or Missions rewards, VIP, Free gift (group reward), each with a badge when something waits.
- **In the world:** a chevron trail toward the next goal shortly after the player joins or returns (reference A); an "UNLOCK!" or "OPEN!" bubble over a portal that just became available; floating "+$X" above Raceway cars when they finish a lap, and "$X/s" labels over the plot's earning sign (reference B); colored ground circles at interactive spots (already proposed in project doc 11).
- **Bottom right:** keep it empty unless Car Hop has a real timer to show (no fake events).
**N7-02 One look across all panels:** restyle Settings, Missions, Garage, the portal card and the other panels into the reference A panel style: a white or light card, a bold colored header with an icon and an outlined title, rows with icons, green toggles, and a red square X; plus the vibrant style for anything that sells.
**N7-03 Phone landscape first:** check every element at the phone landscape frame for thumb reach, safe areas, Roblox's own buttons, and overlap with the movement thumbstick and jump button. Desktop and tablet scale up.
**N7-04 Motion and sound:** pills slide in and out, buttons pop on press, numbers count up, badges pulse gently; a soft sound for each, through the SoundGroups; calmer under Reduce Motion.
**N7-05 Done when:** frames of the home HUD at the three sizes, plus one Play recording with audio, show the new layout working with real (beta) Cash and Raceway data where it exists and PREVIEW fixtures elsewhere, and a fresh reviewer who watched both references agrees it reaches their polish.

### [ChatGPT] N7-01a Reference inventory already completed

[ChatGPT] Positions below use the game viewport, excluding the Windows title bar. Sizes are approximate percentages of viewport width x height, estimated from supplied frames, typically within 3 to 5 percentage points. They are observations, not recommended minimum targets. The contact sheets were reviewed in full, with key panels enlarged. Animation durations and click behavior not visible between sampled frames are unverified. Do not claim to have measured them. A = pet-game reference, B = dino-game reference.

| [ChatGPT] Reference / element | Position and approximate W x H | Visual and observed state/behavior | Car Hop decision |
|---|---|---|---|
| A a01 welcome | Center, 40% x 55% | White/cyan card, bold outlined heading, illustrated night scene, amount and green action | Adapt to owned cars, N9; motion below is proposed |
| A a02-03 goal trail | Ground ahead, perspective-dependent | Repeated bright directional chevrons toward a destination | Adopt as transient route to one real target |
| A a04 egg proximity panel | Upper right, about 27% x 40% | Colorful item art and information beside world interaction | Adapt to portal info only; no egg system |
| A a05-06 hatch/reveal | Center, about 55% x 65% | Enlarged object then creature reveal, name/result presentation | Adapt celebration hierarchy to confirmed new-car capture; no full-screen home interruption |
| A a09 Shop Featured | Center, about 64% x 76% | Saturated hero art, white outlined words, offer cards, category rail, red X | Adapt hierarchy and vividness, original art and preview labels |
| A a10 passes | Same Shop bounds | Distinct colorful pass tiles and green price actions | Adapt to approved Car Hop passes |
| A a11 platform purchase | Center, about 35% x 35% | Native Roblox purchase confirmation over game | Skip recreation and triggering; no real purchases |
| A a12 giveaways | Shop bounds | Promotional cards within same frame | Skip giveaway system; borrow card composition only |
| A a13 tokens/support | Shop bounds | Currency packs and creator-support content | Skip unrelated currencies/support scheme |
| A a14/a16 level-up pill | Top center, about 30% x 8% | Dark outline, bright headline, temporary event state | Adapt to verified Raceway/new-car events |
| A a15 Trade | Center, 31% x 54% | Cyan frame, white player rows, lime/purple tabs, green actions, footer permissions | Skip trading; adapt clean row states for Missions |
| A a17 missions/goal | Right-side information area, roughly 18% x 50% | Compact goal/status rows | Adapt to current Missions, no duplicate permanent drawer |
| A a18-19 next island goal | Top center, 25% x 8% | Dark rounded pill, gold/white heading, green progress | Adapt to next-world readiness; tutorial owns this space first |
| A a19 portal bubble | Over portal, roughly 7% x 5% | Bright UNLOCK text on speech bubble | Adapt to real eligibility; never show OPEN for locked data |
| A a19 height chip | Mid-left, 6% x 4% | Small compact number badge | Skip height; use world context only if useful |
| A a19 Shop/Trade buttons | Mid-left, each about 6% x 9% | Large square glossy icon, bold short caption | Adapt to Shop/Garage/Missions; keep touch size |
| A a19 currency stack | Bottom left, combined 23% x 23% | Huge icons and outlined values; secondary rate and plus buttons | Adapt Cash/rate and owned count; no gems/rebirth currency |
| A a19 central click action | Bottom center, about 9% x 15% | Oversized cursor icon, gain text, adjacent auto-click and pet button | Skip clicker/auto-click mechanics and permanent action |
| A a19-22 profile drawer | Right, about 18% x 64% | Orange header, outlined white cells, statistics and tabs | Adapt data hierarchy inside Garage; don't add a new profile system |
| A a23 native player list | Upper right, roughly 22% x 40% | Roblox native list overlapping world | Leave platform-owned; do not clone or cover |
| A a24-27 Settings | Center, 47% x 68% | White/cyan frame, audio sliders, labeled toggle rows, scrolling categories, footer buttons | Adapt approved settings only; preserve actual toggle behavior |
| A a28-30 Titles | Center, 44% x 54% | Progress/Special tabs, colored locked rows, red X | Skip title progression; borrow locked-row treatment |
| A a32 Updates | Center, 53% x 56% | Large illustration, headline, two feature cards and bullets | Adapt honest beta update summary, no fake event/teleport CTA |
| A a34-35 Height map | Center, 56% x 71% | Illustrated sky/island map, labeled nodes, teleport actions, dark locked nodes | Adapt portal progression clarity, not a new map feature this round |
| A world right shortcuts | Right edge, each about 4% x 7% | Circular colorful rebirth/scroll/bag/crown-style icons | Adapt only existing Settings, leaderboard and eligible gift |
| B b01 Update Log | Center, 44% x 66% | Purple header, dark body, yellow icons, white bullet text, scroll and red X | Adapt compact hierarchy into common Car Hop panel family |
| B persistent instruction | Near top, 100% x 6% | Dark translucent strip, large white text; overlaps panel headers in samples | Adapt instruction prominence, explicitly fix overlap |
| B persistent Shop/Index | Left middle, each 15% x 9% | Wide bright buttons, original art, outlined labels and badges | Adopt labeled navigation pattern, not exact artwork |
| B persistent currency/stamina | Bottom left, combined 17% x 14% | Two bold value rows and green plus controls | Adapt only backed values; stamina not a new home mechanic |
| B persistent hotbar | Bottom center, 42% x 11% | Seven dark square slots, key labels and selected slot | Skip unrelated inventory hotbar |
| B persistent paw action | Right middle, 4% x 8% | Circular paw icon | Skip; no unexplained replacement button |
| B bottom timer | Bottom right, 14% x 4% | Moon icon and countdown | Skip unless Car Hop has a real supplied timer |
| B b02 ENDLESS gate | World overhead, about 22% x 10% | Large mode label over entry | Adapt readable portal signage; do not rename existing modes |
| B b04-05 earnings labels | Above plots, roughly 24% x 13% | Large daily offline amount and smaller per-second rate | Adapt truthful capped/offline semantics; no extrapolated promise |
| B world prompts | Ground/near interaction, variable | Ground circles, start chevrons, press-E prompt | Adapt shared interaction color/shape with touch/gamepad prompts |
| B b07-08 Aura Shop | Center, 60% x 83% | Tall rarity-framed cards, item art, mixed Cash/Robux actions, horizontal overflow | Adapt cosmetic card hierarchy; skip stat boosts and dual purchase currencies |
| B b10 Sell panel | Center, 68% x 78% | Sort rail, three-column selection grid, value total and Sell button | Borrow sorting readability only; no selling or permanent loss |
| B b11-12 Shop | Center, 54% x 60% | Featured offers followed by stamina packs | Adapt featured rhythm; no stamina-sale feature |
| B b14-16 Index | Center, 62% x 62% | Cyan header, rarity frames, silhouette cards, completion/reward controls, right detail, total footer | Adapt N10 with existing Car Hop world tabs |
| B b19/b23 dialogue | Center, 64% x 58% | Portrait at left, cream bubble at right, purple header, progress strip and green GOT IT | Adapt to original mechanic and actual requirements |
| B b22 dialogue transition | Center, smaller intermediate panel | Sample shows opening-scale state; exact timing unverified | Use proposed brief entry animation, not measured claim |
| Both native top controls | Top-left/right platform regions | Roblox menu/chat/player controls and sometimes capture UI | Preserve safe regions; do not draw copies |

[ChatGPT note] B's sampled Index displays world sections in a vertical scroll, not proven side tabs. Side tabs are Car Hop's deliberate adaptation. B's sample dialogue arithmetic is inconsistent: the displayed current/target and remaining amount do not agree. Never copy those numbers. Compute remaining = max(0, target - current) from the same source and unit.

### [ChatGPT] N7-03a Car Hop layout derived from the references

[ChatGPT] IMG-09 is the composition target: island stays visible, left actions are easy to read, Cash is the strongest permanent statistic, and the upper-center space has one clear purpose. Keep the approved Run HUD and ENGINE HEAT placement. Home controls disappear or collapse according to the existing run transition; do not mount both complete HUDs over one another.

| [ChatGPT] Region | Phone landscape, test 844x390 plus 667x375 | Tablet landscape, test 1024x768 | Desktop, test 1920x1080 |
|---|---|---|---|
| Left navigation | 15-19% safe width, three 48-56 px action rows above movement controls; collapse secondary actions to labeled menu if needed | 12-16% width, three 56 px or larger rows | 10-13% width, readable rows; don't stretch to huge tiles |
| Cash/rate/owned | Left upper-lower transition, above thumbstick exclusion; 23-28% width, usually two compact rows | Bottom-left safe region, 20-24% width | Bottom left, 16-21% width |
| Goal/tutorial | Top safe center, 46-56% width; 68-92 px tall when two lines are needed | 40-48% width | 30-40% width, capped for readability |
| Right shortcuts | At most three visible primary shortcuts; overflow menu for secondary actions; stay above jump exclusion | Four or five if real features exist | Compact right rail, not equal visual weight to Shop |
| Modal | 90-96% safe width, near-full safe height; header/footer fixed, content scrolls | 76-88% safe width | Roughly 60-72% safe width with max-width cap |
| World visibility | Keep central travel corridor and both lower control zones clear | Preserve wide central scene | Preserve scene around panel, no unnecessary fullscreen dim |

[ChatGPT] These ranges are starting layouts, subordinate to actual safe areas and 48/56 px target minima. A uniform UIScale reduction is not responsive layout. Reflow labels, hide only optional secondary detail, and move detail views to a second page on phone. Never shrink all text below approved minima to fit. In phone landscape the Cash/rate block may move upward relative to IMG-09 to avoid the thumbstick. Inspect live Roblox controls, safe insets and notch orientation.

[ChatGPT] N7-03b Present Cash as a server-backed balance; format compactly while allowing full value in detail. Show +Cash/s only if the adapter supplies a rate or its computation is approved and uses the same authoritative inputs. Don't turn offline capped totals into a promised daily rate. Missing data is an em dash alternative such as "Loading" or "Unavailable", not zero. Label fixtures PREVIEW adjacent to their value. Cars owned counts unique owned catalog cars, not finishes or duplicates, using the actual denominator. Do not hard-code 24 if the loaded catalog differs.

[ChatGPT] N7-04a Proposed feedback: press 0.06/0.10 s, toast enter 0.18 s and exit 0.14 s, 2.5 s readable dwell, count-up at most 0.45 s with stable final value. Coalesce repeated lap events into one summary within a 1 s window. At most one goal/tutorial banner and one small toast, never overlapping. Badge pulses only for a real unread/claimable state; no permanent urgency animation. Route optional sounds through existing sound groups, never stack a sound for every count-up tick. Reduced motion removes slide, bounce, spin and count-up while preserving final information.

[ChatGPT] N7-05a Required checks: longest car/world names; zero, large and unavailable balances; 0/24 and complete collection; simultaneous tutorial/new-car/world-ready events; Shop open during a toast; respawn, return from run and reconnect to UI data. No text clips at any test size, no invisible hit target covers another action, and tab/gamepad traversal stays inside the active modal until closed. Capture unobstructed HUD and each modal over the actual beta gameplay, not on a blank test backdrop.

## N8. Tutorial fixes

References: `IMG-07-tutorial-banner.png`, the `hud-tutorial-reference.png`, reference A's chevron trail. Code: `src/client/UI/Tutorial/*`, `Home/TutorialBanner.luau`, `Home/TutorialRoute.luau`.

**N8-01 Icons that make sense:** every step's icon clearly shows its action. "Go to Downtown!" uses a glowing portal-arch icon in Downtown colors, not the purple shape. Check all 12 steps.
**N8-02 Banner layout:** the green instruction bar sits exactly centered under the headline inside the dark pill, with even padding on all sides; the icon, the headline and the bar align on one clear grid; the progress strip and Skip button don't crowd it. Match `IMG-07`.
**N8-03 Character guidance (optional, your call):** use the dialogue card (N11) with a friendly mechanic character at one or two moments (for example at the Raceway shopkeeper step, so "who to talk to" is literal).
**N8-04 Run it for real in the beta** (N13): a full playthrough from join to "You're ready!" in the local beta file, with Brian R's real run for the run steps (through the adapter; never edit his files). Record exactly which run events were observable and which still need his events.
**N8-05 After the tutorial:** on later joins, a short chevron trail and goal pill point to the most useful next thing (an affordable Raceway upgrade, a ready portal, an unclaimed mission), as in reference A.

### [ChatGPT] N8-01a Exact tutorial copy and icon mapping

[ChatGPT] Keep the existing stable keys and zero-based indices in TutorialSteps. The table below changes presentation, not progression signals. Braces denote supplied device-aware text or live counts, never literal placeholder copy. Sheet names are semantic keys to map in the icon module, not guessed filenames.

| [ChatGPT] Index/key | Headline | Green instruction | One delayed hint | Icon |
|---|---|---|---|---|
| 0 Start | Welcome to Car Hop! | Collect cars. Build your Raceway. | Follow the arrows to Downtown. | Garage |
| 1 Portal | Go to Downtown! | Walk into the Downtown portal. | Follow the glowing arrows to the portal. | Portal, Downtown colors |
| 2 Steer | Steer your car! | {SteerControl} to move left and right. | Try steering both ways: {done}/2. | Wheel with original directional arrows |
| 3 Hop | Hop to another car! | {HopControl}, then land on a car. | Aim for the next car before you jump. | Stunt Circuit ramp/car glyph |
| 4 Keys | Make this car yours! | Stay aboard until the keys fill. | Keep riding this new car to collect it. | Keys |
| 5 Heat | Watch your ENGINE HEAT! | Hop before the heat fills up. | The heat gauge shows when to switch cars. | Heat |
| 6 Home | Head back home! | Choose HOME on the Results screen. | The HOME button returns you to your island. | Garage, with HOME label |
| 7 Park | Put your car to work! | Add your car to a Raceway spot. | Open your lineup and choose your new car. | Parking spot |
| 8 Earn | Watch your Raceway earn! | Your car earns Cash when it finishes a lap. | Watch your car cross the finish line. | Cash |
| 9 Upgrade | Upgrade your Raceway! | Visit the Raceway shopkeeper. | Follow the arrows to see the next upgrade. | Raceway |
| 10 Shop | Take a look in the Shop! | Open the Shop to see what is available. | Tap the Shop button. No purchase is needed. | Shop |
| 11 Ready | You're ready! | Collect more cars and grow your Raceway! | Downtown is ready whenever you are. | Medal |

[ChatGPT] The sheet has no literal Steer, Hop or Home icons. Use the semantic substitutes listed, adding original simple arrows where necessary, and record replacements. Do not use a random purple badge. If the existing mechanics use different input semantics, resolve {SteerControl}/{HopControl} through the actual input adapter; never promise drag, hold or tap controls that are absent.

[ChatGPT] N8-02a The green bar is centered within the banner body below the title, with identical left/right inset relative to that body. Lay the icon in a separate leading column; reserve Skip and progress regions so they never reduce instruction text to an unreadable sliver. Allow two instruction lines at phone size. After 8 seconds without progress, reveal the one hint; do not repeatedly shake it. Keep the existing completion pause around 0.7 s, with reduced motion static.

[ChatGPT] N8-04a Steps 2 through 5 complete only through existing run adapter evidence, 7 through 9 through their existing lineup/lap/upgrade capabilities. A timer is not proof of a capture, lap or upgrade. Preserve the current explicit skip-with-reason behavior if a required capability is absent, and show an honest developer verification result. Step 9's instruction opens the upgrade context; do not silently change whether the controller requires a completed upgrade. If funds or an event are missing, record the specific blocked/skip case. Never grant Cash or save tutorial progress through a new schema.

## N9. Welcome back card (redesign)

References: reference A at 0:00 to 0:02 (`frames-A\a-01.jpg`) and `IMG-08-welcome-back.png`. Code: `Screens/WelcomeBackMock.luau`.

**N9-01** A compact card with no empty areas: a title outside the card's top edge ("WELCOME BACK!" with a moon and stars icon), a red X, a scene panel, a big coin plus a huge outlined amount, the line "Your cars kept racing for 4h 42m!", and a big green "CLAIM!" button. Soft light rays behind the card.
**N9-02 The scene is alive:** a looping animated scene of the player's own cars (or the placeholder cars until real ones exist) on a night-time mini Raceway: they bounce with little "Zzz" bubbles, coins float up and pop, stars twinkle. Build it with UI elements or a ViewportFrame; pick what looks best and runs cheaply on phones.
**N9-03 CLAIM** flies coins into the Cash counter (visual only; the amount comes from the server later) and closes the card.
**N9-04** Shown on join in the beta when there is something to show (PREVIEW amount until Brian L's offline data exists), after the loading screen, and never on the tutorial's first steps.

### [ChatGPT] N9-02a Proposed scene storyboard and claim behavior

[ChatGPT] Use three lightweight representations of actual owned cars when available; otherwise three clearly identified fixture cars. No new face, eyes or character personality on Brian L's car models. The generated sleepy car image is mood guidance only. Start with layered original 2D art or cloned sanitized visual rigs, choosing the cheaper proven approach. No physics, live scripts or external asset dependencies inside the miniature.

| [ChatGPT] Time / frame at 60 fps | Scene action |
|---|---|
| 0.00 / 0 | Card becomes visible; night track, three cars, final target amount known or loading state shown |
| 0.00-0.18 / 0-11 | Card fades and scales 0.97 to 1; stars and car silhouettes remain legible |
| 0.18-0.60 / 11-36 | Amount counts once from 0 to the supplied total; do not change actual Cash |
| 0.20-1.10 / 12-66 | Car 1 rises by about 2% scene height and settles with a soft sine arc; wheels remain grounded visually through a small shadow squash |
| 0.55-1.45 / 33-87 | Car 2 repeats with a smaller bounce, slightly delayed |
| 0.90-1.80 / 54-108 | Car 3 repeats; avoid synchronized jumping |
| 0.45-2.00 / 27-120 | One Zzz per car rises 6-8% scene height and fades, with staggered phases |
| 1.10-2.10 / 66-126 | Two or three small pooled coins rise near the track and fade; no actual reward event |
| 2.10-3.60 / 126-216 | Quiet interval with one subtle star twinkle; cars settle |
| 3.60 onward | Repeat the scene cycle smoothly; do not replay the card entrance or amount count |

[ChatGPT] These are proposed production timings, not frames measured from A. Limit the phone scene to 3 cars, 3 Zzz labels, 3 decorative coins and 4 stars; stop the animator when hidden. Reduced motion uses a static scene, final amount and no floating particles.

[ChatGPT] N9-03a Current WelcomeBackMock treats the supplied reward as already credited and the button as acknowledgement. Preserve that contract. CLAIM must not credit again. On click, disable repeat activation, animate at most 6 pooled coins toward the actual Cash counter over 0.35-0.55 s, acknowledge exactly once and close. If the HUD counter is hidden, fade coins locally instead of flying to a guessed coordinate. Closing with X also cannot lose or duplicate an already credited reward. Cash only reflects server updates; the animation must not add it locally.

[ChatGPT] N9-04a States: checking uses "Checking your Raceway..." and disabled claim; unavailable uses "Earnings couldn't be checked" with Close and a bounded existing retry; verified zero skips the card; positive verified amount shows the supplied credited duration; fixture shows PREVIEW prominently. Duration means credited time, including any cap, not unbounded absence. Do not invent an offline payout from the timestamp. Test rapid double-click, X during animation, zero, large amount, missing car art, data arriving after dismissal and panel destruction.

## N10. Garage / Index restyle (reference B's Index)

**N10-01** Restyle the Garage into a collection Index in the spirit of reference B: World tabs down the side (Downtown, Dusty Highway, Summit Pass), a grid of car cards (owned in full color, unowned as dark silhouettes with "???" and their rarity frame), a per-World completion bar ("Downtown 5 / 8"), a completion reward box per World (PREVIEW reward, Brian L's to decide), "CLAIM" and "CLAIM ALL" buttons, a total "Unlocked 17 / 24", and a detail panel for the selected car (name, rarity, family quirk, Lap Pay, the three race stats, Variants owned, Put on Raceway).
**N10-02** Keep everything working that Round 1 and earlier rounds built (sorting, the six-fact detail), restyled into the new family.

### [ChatGPT] N10-01a Collection structure and states

[ChatGPT] Desktop/tablet: left world rail about 18% of panel width, center grid about 49%, right detail about 33%, adjusted for padding. Header contains Garage / Index, total owned and Close. World completion sits above the grid; reward strip below it stays compact. Use 3 grid columns at normal desktop size. Phone: world choices become a horizontal strip, grid uses 2 or 3 readable columns, and tapping a car opens a dedicated detail page with Back, not a tiny third column. Keep header and main action fixed; scroll content only.

[ChatGPT] Owned card: original car art, rarity label plus colored frame, short readable name and selected border. Unowned: genuine silhouette of that car with ???, no leaked Lap Pay or stats. Loading uses neutral skeletons without a fake rarity. Missing art keeps name and owned status visible with a garage fallback. Unknown world/category data produces an explicit unavailable state rather than an empty complete collection. Selection is stable across sorting and refreshes; don't reset to the first car on every update.

[ChatGPT] N10-02a Preserve current sorting Rarest, Lap Pay and Newest, including stable tie handling and no mutation of source catalog arrays. Preserve the existing six-fact detail. This new brief expands it with family quirk, race stats and variants; the current GarageMock intentionally omits family/quirk. Add those rows only from supplied approved data or labeled fixtures. Do not make up performance values for Brian L's cars. Unavailable live fields show "Not available yet". Variants count uses owned finishes from its actual source, not a guessed multiplier.

[ChatGPT] N10-02b Completion rewards are PREVIEW proposals, not new claim remotes. States are Incomplete, Complete / preview reward available, Preview claimed this session, and Live data unavailable. CLAIM ALL processes only eligible preview entries in deterministic world order, once per session; it never grants live Cash. Put on Raceway uses the existing lineup adapter. If unavailable, keep a clear disabled action and reason; do not fake successful parking.

[ChatGPT] N10-02c Check all 3 worlds, empty/partial/full collection, long names, every sort, owned/unowned selection, locked reward, preview claim twice, max lineup and a missing adapter. The footer count, world count and progress bar agree with the same source. No "complete" badge when any required catalog entry is unknown.

## N11. Dialogue cards and Update Log

**N11-01 Dialogue card** (reference B and `IMG-10-npc-dialogue.png`): a title bar with an icon and an X, a portrait of an original friendly character (for example "Coach Roxy", a race mechanic; designed by you), a speech bubble with typed-out text, an optional progress bar with "X TO GO", and a big "GOT IT!" button. Use it for **locked portals** (what is needed to open them, with live PREVIEW progress), the Raceway shopkeeper, and optionally the tutorial (N8-03).
**N11-02 Update Log ("What's new"):** a small panel on join (once per new version) listing recent changes with icons, in the reference B style. Content: a short, honest list of what is in the beta now. Dismissible, never during the tutorial's first steps.

### [ChatGPT] N11-01a Dialogue layout and behavior

[ChatGPT] Use an original mechanic portrait, with a distinct Car Hop outfit and simple friendly expression. Treat Coach Roxy as a reversible local name proposal, not an already approved lore character. Keep portrait approximately 25-30% of desktop card width, speech 60-65%, and actions below. On phone, shrink the portrait to a small header portrait and give the text full width. Keep cream speech surface, dark readable text and a colored header within the established family; no floating detached widgets.

[ChatGPT] Proposed typewriter: 28 characters per second, maximum 2.5 s for a short message; activating the speech area reveals all text, then GOT IT closes. Reduced motion displays the full message immediately. No purchase action can fire from the reveal click. Default controller focus goes to GOT IT, and closing restores focus to the prior trigger. Dismissal suppresses immediate reopening while still inside the same proximity zone.

[ChatGPT] Locked portal copy uses actual world name and one explicit requirement, for example "Collect {remaining} more Downtown cars to unlock Dusty Highway." Progress shows current/target in the same unit; remaining = max(0, target-current). Unknown requirement shows "Unlock details aren't available yet." If the requirement completes while open, update the card to Ready and expose only an existing travel action. Never change unlock logic from Lane 3. Shopkeeper dialogue points to the existing upgrade panel; no surprise purchase.

[ChatGPT] N11-02a Update Log: one compact header, up to 4 verified shipped changes with original icons, optional More details scroll, one Close/GOT IT action. No release-date claim or feature shown as live unless it works in this local beta. Derive a local content version from the change list. The no-new-save rule permits once-per-version within this session only; persistent cross-session suppression needs an existing approved storage field or Brian L's follow-up. Do not add one. Put PREVIEW on planned examples rather than mixing them into shipped notes.

[ChatGPT] Test dialogue opening, typing, immediate close, repeated proximity, progress update, missing data, gamepad back and tutorial suppression. The update panel must not cover the tutorial or reappear every time home mounts.

## N12. Stunt Circuit screens and customization (the course itself is Brian R's now)

**N12-01 Stop work on the course** (`src/lookdev/Stunt`); leave it intact and hand it over in Brian R's message (N15).
**N12-02 Results card (redesign):** follow `IMG-06-stunt-results.png`: a "FINISH!" ribbon, a huge medal on the left (gold, silver, bronze or none, with a matching celebration), the time in big outlined numbers, "NEW BEST!" when true, the gap to the ghost, the three medal targets with ticks, a reward row (PREVIEW), a small render of the car, and RETRY and HOME buttons. No large empty areas at any screen size.
**N12-03 Customization (paint, decals, wheels):** follow `IMG-05-customize-garage.png`, inspired by the feel of premium car-customization screens such as Rocket League's (the general feel, not its art). A turntable car under a spotlight; tabs PAINT, DECALS and WHEELS; item cards with rarity-colored frames and Cash prices.
- **Paint tiers** (PREVIEW prices, rising): Basic solids, Metallic, Pearl, Two-Tone Gradient, Animated (for example Rainbow Flow, Galaxy, Lava); a few medal-locked paints ("Win GOLD to unlock").
- **Decals:** at least 12 cool, original designs (flames, lightning, racing stripes, numbers, checkers, stars, shark teeth, comet trail, and so on), as tiers too.
- **Wheels:** at least 8 styles (classic 5-spoke, chunky off-road, neon glow rim, golden turbine, star rim, monster tire, and so on), as tiers.
- Live preview on the turntable car, OWNED / EQUIPPED / LOCKED states, a "BUY $X" then "EQUIP" flow (PREVIEW, nothing saved or charged), and a "not enough Cash" state that links to the Shop.
- Animated paints visibly animate on the preview car (cheaply).
**N12-04 Pre-race card and leaderboard:** restyle into the new family.

---

### [ChatGPT] N12-03a Cosmetic research and proposal boundaries

[ChatGPT] Rocket League separates cosmetic categories such as bodies, decals and wheels from its rarity labels. Its April 2024 official update renamed Common to Base, Uncommon to Sport, Rare to Special, Very Rare to Deluxe and Limited to Luxury; Import, Exotic, Black Market, Premium and Legacy remained. Those labels are not a universal price formula. Use Car Hop's own finish tiers, not copied brand terminology. [Official rarity changes](https://www.rocketleague.com/news/patch-notes-v2-38)

[ChatGPT] Historical pricing evidence, not a current store quote: Rocket League's December 2019 official revision listed Rare at 50-100 Credits, Very Rare at 100-200, Import at 300-500 and Exotic at 700-800, with additional paint/special-edition charges and exceptions. This demonstrates tier plus attribute pricing, not a Cash exchange rate for Car Hop. Current individual offers and prices were not verified. [Dated pricing announcement](https://www.rocketleague.com/news/update-to-item-shop-and-blueprint-pricing)

[ChatGPT] Roblox comparators: Driving Empire promotes deep vehicle customization and car-show appeal; Car Dealership Tycoon promotes appearance choices and separate performance customization; Vehicle Legends promotes vehicle personalization and upgrades. The transferable design inference is visible self-expression, a clear preview, and a reason to show a car to friends. Do not import their licensed branding, performance upgrades, emergency liveries or unrelated currencies. Current paint/wheel price tables and unlock tiers were not verified from their official pages, so no competitor Cash figure is claimed here. [Driving Empire](https://www.roblox.com/games/3351674303/Driving-Empire), [Car Dealership Tycoon](https://www.roblox.com/games/1554960397/Car-Dealership-Tycoon), [Vehicle Legends](https://www.roblox.com/games/4566572536/Vehicle-Legends-Cars)

[ChatGPT] N12-03b The following is a complete PREVIEW catalog proposal for Brian L. It expands the earlier small catalog by Adam's request. These are arbitrary starting Cash amounts for visual and flow testing, not balanced live prices. No new currency, actual debit, persistence or authoritative catalog edit. Price a visual technique consistently; higher price does not increase speed, grip, jump, income or rarity of the underlying car. Use tier names plus color, not color alone.

| [ChatGPT] Paint tier | Named items and PREVIEW Cash each | Visual treatment |
|---|---|---|
| Basic, free | Pit White 0; Asphalt Charcoal 0; Downtown Blue 0; Signal Red 0; Taxi Gold 0; Fresh Lime 0; Bubblegum Pink 0; Cloud Cyan 0 | Eight clean solids, immediately available in preview |
| Basic, additional | Tangerine Pop 250; Plum Punch 250 | Same solid technique, optional hues |
| Metallic | Brushed Steel 750; Copper Sprint 750; Midnight Alloy 900; Cobalt Chrome 900; Rose Metal 1,100 | Controlled highlights, not mirror noise |
| Pearl | Shell Pearl 1,800; Glacier Pearl 1,800; Mint Pearl 2,100; Sunset Pearl 2,100; Lavender Pearl 2,400 | Soft two-color sheen, readable body contours |
| Two-Tone Gradient | Citrus Split 3,500; Candy Horizon 3,500; Ocean Fade 4,000; Dusk Runner 4,000; Peach Skyline 4,500 | Intentional front/rear or lower/upper blend |
| Animated | Rainbow Flow 7,500; Galaxy Drift 9,000; Lava Cruise 10,000; Aurora Ribbon 12,000; Electric Tide 12,000 | Slow body-only color/pattern movement |
| Medal-locked proposal | Bronze Dash 2,500 plus Bronze; Silver Current 5,000 plus Silver; Gold Horizon 10,000 plus Gold | Clearly show both Cash and medal conditions; fixture only |

[ChatGPT] Paint count: 33. Preserve the 8 free options. Medal conditions are proposed presentation states; Brian R supplies achievement evidence and Brian L approves entitlement/economy. Unknown medal status must remain unknown/locked, not unlocked by a fabricated race result.

| [ChatGPT] Decal | PREVIEW Cash | Original design direction |
|---|---:|---|
| Twin Sprint | 400 | Two broad offset hood stripes |
| Side Slash | 500 | One angular door-side stripe |
| Checker Corner | 650 | Small checker patch at one rear quarter |
| Lucky Seven | 650 | Original rounded number 7, no racing sponsor |
| Comet Tail | 900 | Swept star and tapering trail |
| Zigzag Charge | 900 | Bold broken lightning stroke |
| Friendly Fangs | 1,100 | Playful cartoon teeth, no gore |
| Bubble Burst | 1,100 | Three overlapping round bubble marks |
| Summit Steps | 1,400 | Layered mountain-step geometry |
| Dust Devil | 1,400 | Broad curling sand swirl |
| Star Scatter | 1,800 | Sparse varied five-point stars |
| Circuit Lines | 1,800 | Original electronic path pattern |
| Solar Flare | 2,400 | Rounded flame tongues, distinct from reference art |
| Night Orbit | 2,800 | Offset ring and tiny moons |
| Checkered Comet | 3,400 | Checker patch blending into a sweeping tail |

[ChatGPT] Decal count: 15. Keep hood, side and roof coverage explicit per asset. Don't stretch a side design across windows or lamps. Preserve panel readability and permit clearing a decal back to None. An incompatible body shows "Not available for this car" rather than silently distorting the art.

| [ChatGPT] Wheel | PREVIEW Cash | Original style |
|---|---:|---|
| Stock Five | 0 | Simple chunky five-spoke |
| Rally Block | 900 | Squared spokes, dark inset |
| Classic Disc | 1,200 | Clean solid disc with small vent cuts |
| Split Six | 1,600 | Six paired spokes |
| Trail Chunk | 2,000 | Off-road visual tread within existing diameter |
| Star Runner | 2,800 | Broad rounded star hub |
| Golden Turbine | 3,500 | Swept gold spokes |
| Neon Halo | 4,500 | Thin emissive ring, no flashing |
| Moon Dish | 5,000 | Smooth pearlescent dish |
| Monster Mini | 6,000 | Exaggerated tread silhouette within fit envelope |

[ChatGPT] Wheel count: 10. Tire diameter, wheel centers, collision and handling remain unchanged. Monster Mini is a visual treatment, not permission to alter Brian L's rig. If a replacement cannot fit the existing mounts, prototype it on the neutral preview rig and document the dependency.

### [ChatGPT] N12-03c Cheap paint rendering and interaction

[ChatGPT] A UIGradient does not paint a 3D car. On the preview clone, group body-only surfaces, excluding glass, lamps, tires and trim. For simple animated finishes, interpolate a small set of body colors at about 10-15 updates per second using one shared phase. For spatial gradient patterns, use a small number of authored body-region materials/textures or a validated compatible texture approach. Never spawn hundreds of strips/particles to simulate a shader. Don't call a color cycle a moving galaxy texture unless the pattern is actually implemented. Record approximations. Pause offscreen and freeze a flattering phase under reduced motion.

[ChatGPT] Reuse one turntable and one cloned car per open screen; item cards use static thumbnails. No ViewportFrame per catalog card. Turntable auto-rotation starts around 12 degrees per second, pauses for touch/drag and stops under reduced motion. Selection updates only changed appearance; do not reconstruct the entire rig on every hover. If fitting depends on teammate assets, keep their originals read-only and use a disposable visual clone.

[ChatGPT] N12-03d Separate Previewed from Equipped. Clicking a card previews immediately; an owned item exposes EQUIP, which changes the session fixture only. An unowned item exposes "BUY [amount] Cash" within a persistent PREVIEW frame and confirms "Preview only. Nothing is charged or saved." Successful simulated purchase changes only a dedicated fixture balance/inventory, never the real displayed Cash. Show that fixture balance as "PREVIEW Cash". Insufficient fixture balance offers Back and View Shop; View Shop navigates, never opens a real purchase prompt. Locked medal items explain the exact fixture requirement. Reopen behavior is consistent for the session and resets on new Play.

[ChatGPT] N12-03e Brian L's calibration task: compare price / verified net Cash per minute at early, middle and advanced progression; compare cosmetic costs with Raceway upgrades at those points. The aim is affordable self-expression first and optional long-term showpieces later. No target earning-time claim can be validated before his economy inputs exist. Attach this table and the assumptions, not a recommendation to copy competitor prices.

[ChatGPT] N12-02a Results: fit medal and key time into the top half, then ghost difference and three target rows, then reward and actions. Phone stacks medal beside time, not a giant empty illustration column. NEW BEST appears only when the authoritative result says it or the approved adapter can compare verified previous best. Missing ghost data says "No ghost comparison"; unfinished/invalid run says so and does not award a medal. PREVIEW reward remains labeled. RETRY and HOME each fire once and show pending state until the existing transition responds.

[ChatGPT] N12-04a Pre-race presents chosen car, supplied stats, selected course and existing start action, with loading/ready/unavailable states. Leaderboard distinguishes loading, empty, entries, own entry outside visible page and error. Don't invent ranks or world records. Brian R owns course geometry, checkpoint rules and timing. Capture each screen over his actual scene if available; otherwise mark the scene fixture honestly.

## N13. Everything running in the beta (local beta file)

Round 1 left the Shop, tutorial and other home screens running only in the HUD test place. **This round mounts them in the beta** so Adam can play the real flow.

**N13-01** In the `integration/beta-2` branch, mount the full Lane 3 home UI through Adam's beta glue (`src/client/Beta/*`, `beta.project.json`) and Lane 3 folders: the loading screen → Update Log → welcome back → the new HUD → the tutorial for a new player (or the post-join chevron trail for a returning one) → the Shop and every panel → the portal card and dialogue cards at the portals → the group reward pop-up at its allowed moments → the Results "Earn faster" card after a run.
**N13-02 Real data where it exists** (beta Raceway level and parking spots from the beta save, plot ownership, run results), PREVIEW fixtures elsewhere. Nothing new is saved (no schema changes), and no real purchase prompts.
**N13-03 Test the whole join flow** in the local beta file as a new player and as a returning player: no stuck screen, no overlapping pop-ups (one pop-up at a time, queued in a sensible order), everything closable, no errors in the Output window. Record a Play video with audio of a full new-player session (join → tutorial → run → home → Raceway upgrade → shop).
**N13-04** Do not publish and do not touch the Team Create place. Tell Adam in the final message what to do if he wants to publish it.

### [ChatGPT] N13-01a Exact join and modal queue contract

[ChatGPT note] The arrow list in N13-01 describes feature coverage, not permission to show every popup before a first-time player can move. N8/N9/N11 explicitly protect the tutorial's first steps. Mount the HUD behind the queue as soon as essential state is ready, then choose the new-player or returning-player flow below.

| [ChatGPT] Order | New player | Returning player |
|---|---|---|
| 1 Loading | Essential character/UI/adapters ready; bounded optional art loading | Same |
| 2 Resolve session | Determine tutorial eligibility from existing source; unknown is not proof of returning | Same; no new saved flag |
| 3 First active experience | Start tutorial immediately; suppress update, welcome and promotions throughout its active steps | Update Log if eligible and not seen this session/version |
| 4 Next informational popup | After tutorial finish or explicit skip and return to home, optional Update Log | Positive verified Welcome Back, or clearly enabled preview fixture |
| 5 Free movement | Show one meaningful goal/trail when the player is home and no modal is open | Show goal/trail after informational cards dismiss |
| 6 Optional promotion | Group reward or Starter Pack only at inherited allowed moments and after quiet time | Same |
| 7 Player-initiated screens | Shop, Garage, Settings, portals and dialogue on demand | Same |
| 8 Run and return | Run transition clears home prompts; results has priority on finish; Earn faster is an optional results entry | Same |

[ChatGPT] Existing tutorial state, adapters and completion rules win. If no reliable eligibility signal exists, keep the developer new/return fixture selector explicit and record integration as partial. Do not silently infer first-ever join from an empty client table.

[ChatGPT] N13-01b Use one home modal coordinator, distinct from the existing lightweight notification Priority slots. Existing Center/Upper/Side toast ranks are not already a global modal queue. Coordinate existing panels through Lane 3 glue rather than changing teammates' contracts. User-opened panels wait for the active popup to close or explicitly replace it through that coordinator; they must never create a second modal layer.

[ChatGPT] Proposed caps: one blocking panel at a time; at most four pending popup records; deduplicate by semantic key plus content version; at most two automatic informational join cards for a returning player; at most one automatic promotional offer in a session, choosing Group or Starter, not both. Wait at least 30 seconds of free home interaction after informational/tutorial completion before an eligible promotion. No promotion during a run, results, tutorial, teleport transition, loading or another panel. These are local presentation limits, not new saved fields.

[ChatGPT] N13-01c Priority: transition/safety UI first, existing run results next, explicit user interaction next, contextual dialogue next, deferred informational join cards next, promotion last. Do not forcibly interrupt a purchase-preview confirmation or result with a promotion. On capacity, drop the oldest lowest-priority optional item and log the reason. Every pending item rechecks eligibility before opening. Discard stale portal dialogue when the player leaves range and discard stale home promotion on run start. A dismissed item cannot requeue from a repeated subscription update in the same session.

[ChatGPT] N13-01d Loading is not a fabricated progress percentage. Show actual milestones or an indeterminate state. After a proposed 10-second delay, show "Still loading..." and identify optional content separately in diagnostics. Optional image/audio failure falls back; missing essential adapter produces a recoverable unavailable state, not a forever spinner. Do not alter Roblox's connection UI or invent readiness signals.

[ChatGPT] N13-03a Test join matrix: new player, returning with positive offline reward, returning with verified zero, delayed data, failed optional assets, unknown tutorial state, group eligibility unknown, notification burst, respawn, run entry while a promotion is queued, and repeated home mounting. Record popup order and count, queue depth, suppression reason and whether the scenario used real or fixture data. Closing every popup returns input to the world or prior panel. No promotion reopens after dismissal, no duplicated HUD roots, and no balance changes from previews.

## N14. Round 1 leftovers
- Summit seed 314 fails the 500-stud majors rule: fix the rule or the placement so every tested seed passes.
- Dusty Highway part count: get scenery within the ceiling with margin (for example merge structure parts into meshes), and measure the Play ceiling too.
- Mirage Dunes is thin at the end: fill it.
- Downtown signs into the sign family.
- Phone layouts for every screen (Round 1 checked only the Shop and the portal card), plus hover, gamepad selection and Reduce Motion checks on all new screens.
- Videos with game audio: record in Play mode so sound is captured.

### [ChatGPT] N14-01a Prevent weaker checks from hiding unfinished work

[ChatGPT] Summit seed 314: diagnose the actual placement failure before changing the 500-stud criterion. Preserve the approved spacing rule unless a documented design discrepancy justifies a new proposal; do not lower it merely to pass. Report offending pair, spacing and seed before and after. Re-run the existing tested seed set and include 314.

[ChatGPT] Dusty: distinguish scenery counts from rig/system counts using the established SceneStats categories. Report Edit and Play separately against their existing ceilings, with measured headroom. Don't hide excess by changing which scenery is counted. Mirage Dunes end dressing must retain road visibility and clearance; use a few purposeful silhouettes rather than filling all empty sand. Re-run its placement/visibility checks after adding assets.

[ChatGPT] Phone review covers every new/changed panel and every major state, not just one successful Shop frame. Sound recordings must contain actual captured game audio; if the recording tool cannot capture it, label that limitation and perform a separate audible check. Never add an unrelated soundtrack to imply a captured playtest.

## N15. Teammate messages
**N15-01 Brian R:** the Stunt Circuit is now his (Adam's decision, 2026-11-01). Hand over the Round 1 course kit (`src/lookdev/Stunt`, `StuntData` centerline, checkpoints and obstacles) as an optional starting point, and list the Stunt screens Lane 3 keeps and the events they need from his race (start, checkpoint, finish time, ghost gap, medal). Re-ask, briefly, for the `"None"` scenery option, the tutorial run events and the first-run assists, linking his earlier messages.
**N15-02 Brian L:** the cosmetic tiers and PREVIEW prices (paint, decals, wheels), the Index completion rewards, the HUD's data needs (Cash rate per second, cars owned), the Update Log (no data needed), and links to his open earlier messages.

### [ChatGPT] N15-01a Dependency handoff contents

[ChatGPT] Brian R receives the course ownership change, links to the intact optional kit, the exact existing adapter entry points used, and a compact missing-event matrix: event meaning, current payload observed, UI consumer and fallback. Do not declare a new remote contract on his behalf. Include run start/end, checkpoint, finish validity/time, ghost gap, medal, steer/hop/claim/heat tutorial observations and first-run assistance needs.

[ChatGPT] Brian L receives the full PREVIEW catalog, whether preview balances are isolated, required read-only balance/rate/owned-car/variant/medal inputs, and the offline card acknowledgement semantics. Flag persistent Update Log suppression and Index reward claims as future dependencies, not implemented saves. Merge with existing message documents rather than duplicating or erasing replies.

## N16. Self-review loop (stricter this round)
**N16-01** All automated checks (`./scripts/check.ps1`, the M1 overlap scanner, the new line, junction and tree checks, `SpeedwayChecks` on all plots and levels, the Worlds self-checks, `SceneStats`).
**N16-02** **Same-view comparisons:** for each of Adam's screenshots `r2-01` to `r2-06`, capture the same view after the fix and save the pair side by side in `evidence\`.
**N16-03** Two fresh reviewers, **two rounds minimum:** one for the world (given Adam's screenshots, the after-pairs, `IMG-01` and `IMG-02`) and one for the UI (given the reference videos' frames, `IMG-03` to `IMG-10`, and frames at the three sizes). Ask each to rate every area 1 to 5 against its reference and to list blockers. Fix until no blockers remain and every area scores at least 4, or explain in the final message why an area can't get there yet.
**N16-04** Never report something as done that wasn't checked in Studio; say exactly what was checked by reading code only.

### [ChatGPT] N16-01a Evidence and acceptance matrix

[ChatGPT] Create a verification table with requirement ID, scenario, expected result, actual result, evidence path, code revision and status. Allowed statuses: verified in Studio, checked in code only, fixture demonstration, blocked, not tested. A reviewer score never upgrades a fixture to real integration. Use an actual capture path for every image/video claim.

| [ChatGPT] Area | Required evidence before calling it complete |
|---|---|
| Junctions | Known-bad checker fixtures detected, all plot/level results, r2-01/02/04 pairs and top-down joints |
| Loop | Measured footprint/width/clearances, frame-continuity results, three-car Play recording from side and walkway |
| Island | r2-03/05/06 pairs, both fence removals, whole-island canopy check and slow flicker walk |
| Icons | Every logical icon resolves to tested art or recorded fallback; transparent edges inspected small |
| Shop/HUD | Phone/tablet/desktop states, all entry points, preview honesty, reduced motion, input focus and teardown |
| Tutorial | Twelve stable steps logged, real/fixture/skip status per step, full beta walkthrough and exact blockers |
| Welcome | Zero/positive/error/loading cases; no duplicate credit/acknowledgement; loop and cleanup verified |
| Garage/dialogue | Sorting/count consistency, owned/locked/missing states, progress arithmetic and dismissal tested |
| Customization/results | 33 paints, 15 decals, 10 wheels available as preview definitions; render coverage explicit; no gameplay changes |
| Beta | Join queue scenarios and caps, no duplicate roots, no save/schema/purchase changes, Output reviewed |
| Regression | Required repository checks plus world seeds/part budgets; failures listed rather than suppressed |

[ChatGPT] N16-03a Two reviewer agents may run concurrently, within the two-worker cap. Give each the original requirements plus final evidence, not the lead's self-congratulation. World reviewer checks silhouette, construction and all six screenshots; UI reviewer checks the inventory adaptations, small-screen states and motion/reduced motion. Round 1 returns blockers with evidence and specific fixes. Lead fixes them. Round 2 rechecks new evidence and prior blockers. Reuse these two reviewers; no nested agents. Rate each named area separately from 1 to 5 and explain any score under 4. Missing evidence is a blocker or an explicitly incomplete item, not an invitation to infer success.

[ChatGPT] N16-04a A finished-looking static frame is insufficient for moving cars, animation cleanup, popup queues or input. Conversely, don't repeat an expensive full test suite when only a comment changed. Re-run the affected checks after each relevant fix, then the required final suite once against the final revision. Check 20 panel open/close cycles, three scene rebuilds, three loop laps and one full new/return beta journey with connection counts and Output reviewed.

## N17. Finish and final message
Same as Round 1 (sections 20 and 21): run the checks, commit in logical steps, push, update draft PRs #8 and #9 (no merge, no publish), update the board, log, ledger, decision note and `vault/design/assets.md`, and save the places with dated backups. Then write a **short** final message in the terminal (no review page, no artifact) and `review\round2\RESULT.md`, containing:
1. What to open and where to look, starting with **the local beta file**, since that is now the place to experience the whole game flow.
2. Status per N module, one line each.
3. The choices you made that Adam may want to change.
4. Steps that need Adam's hands (the icon upload if R-05 couldn't do it), numbered with exact clicks.
5. Teammate messages and what they unblock.
6. Known issues and what wasn't tested.
