# Brief: Lane 3 Speedway upgrade looks (2026-10-28)

From Adam (Lane 3 owner, repository owner). Read this whole file before doing anything. Treat it as the specification for this session. Everything in it is required unless it says "proposal" or "optional". My notes are the minimum: research, go further, and make the track look like it belongs in a top Roblox game, while keeping it buildable and fast on phones.

## 0. Where this work happens

- Worktree: `C:\Users\agert\Documents\Roblox-Game-1-island`. The island lives on `feature/lane3-island-environment` (pushed, not merged to main). Create a new branch **`feature/lane3-speedway-upgrades` from `feature/lane3-island-environment`**, not from main, because the Speedway, the plots and `src/client/Home/Island/TrackMotion.client.luau` only exist on the island branch. Open a draft PR to main at the end that says it builds on the island branch.
- Read first: `AGENTS.md`, `vault/tasks/BOARD.md`, the island ledger and decision notes for the island work (including 0018), `vault/design/ui/plot-track-signs.md`, `vault/design/visual-direction.md`, the Speedway section of `vault/design/car-hop-outline-v2.md` (section 08) and the two reference pictures `vault/design/references/speedway-progress-01-start-dirt-oval.png` and `speedway-progress-02-end-elevated-loop.png`.
- Copy this brief into the repo as `vault/design/specs/speedway-upgrade-looks.md` on the new branch and commit it.
- Find the existing Speedway first: where the track, its recipe or kit, its lap path and the old Income Tier visuals live ("Income Tier off" was set in Task 4 WIP 6), and what `TrackMotion.client.luau` does. Build on what exists. Do not make a parallel second track system.
- My private island test place only (`CarHop-Island-Test`). Never the shared Team Create place. Respect `STUDIO_LOCK.txt` (the HUD close-out session may be running at the same time) and the 4 GB free-memory floor.
- Finish as much as possible in one go. One review stop at the end. Batch every click I must make (mesh imports) into one guided moment.

## 1. What is decided and what is not

**Decided by Adam (2026-10-28):**
- The Speedway gets **10 to 15 upgrade levels**, not the outline's 5 Income Tiers. It starts as a plain dirt track and improves a little at every level, getting cooler and cooler, ending at a spectacular track like the second reference picture (elevated, with a loop).
- Every level must be **visible**: a player walking past a plot can tell roughly what level it is. That is the "island shows progress" pillar.
- Adam wants crowds, bleachers, a referee-style flag official and similar life as the track grows.
- This supersedes the 2026-10-21 rule that the base track already has yellow lines, flags, a checkered line and banners. Those now arrive at later levels. Record the change in the ledger and the decision note.

**Recommended by Claude (Adam can overrule):** **12 levels.** That is enough for a new visible change at every level, inside Adam's range, without the art and phone cost of 15. Section 3 also lists three extra levels to slot in if the team picks 15.

**Not decided, and not yours to decide (Brian L, Lane 2):** the final number of levels, the price of each level, how much each level raises Lap Pay, whether this ladder replaces the Income Tier in the save data, and how it relates to Slots. **Build looks only.** No prices, no multipliers, no Cash, no save fields, no remotes. Anywhere a price would show, use a clearly labelled preview placeholder. Write a proposal message for Brian L (section 6).

**Assumption to record:** Slots (parking bays in the Paddock) stay a separate ladder and are not part of these levels. The Paddock is not redesigned in this task, except where a level must not block it.

## 2. Rules for every level

1. **Additive kit.** Each level adds pieces and sometimes swaps a piece for a better one (bleachers become a grandstand). Never 12 separate track models. One module takes a plot and a level number 1 to 12 and assembles everything for that level. Going down a level (for testing) must also work cleanly.
2. **Same lap timing at every level.** Lineup cars lap in about 15 seconds at every level, and Lap Pay is timed by the server, not by the car crossing a line. When the track gets longer (overpass, loop), the visual car speed adjusts so a lap still takes the same time and the car still crosses the finish line when the Lap Pay pops. Never let the track shape change the earning rhythm. Check this with numbers at every level.
3. **Fits the plot.** Every level stays inside the plot's bounds and the room that was reserved for upgrades. It must never block the plot gate, the paths, the Paddock bays, the nameplate, or the view of the track from the central plaza. Measure it.
4. **Visitors stay safe.** Visitors can walk onto any Speedway. Raised sections, the loop and the overpass must not trap, launch or wedge a player; add railings or invisible guards where needed, and keep walkable routes. Lineup cars still drive through characters harmlessly.
5. **Island style.** Same look as the approved island: bright, stylized, smooth faceted low-poly, no Roblox studs anywhere, nothing blocky, kid-friendly, vibrant, symmetric and cohesive where props are placed (Adam likes symmetry and predictable prop placement; trees may stay random). No real brands, logos or sponsors: any banners use our own fictional names (for example Pip's Pops, Comet Cola, Haul Buddy Tires).
6. **Readable from the plaza.** Each level's main addition should be recognisable from the plaza at normal camera distance. Small details are for close-up.
7. **Phones first.** Six plots can each be at the top level at once. Use distance detail: plots far from the viewer show a simplified version (big shapes only, no crowd figures, no small props, no moving parts). Bake details into a few meshes per level rather than hundreds of parts. Set realistic budgets per level and for "six plots at the top level", measure them in Studio (instances, triangles, draw calls, frame time) and label every number as a desktop measurement (no phone test available).
8. **Life is cheap.** Crowds are simple stylized figures made from a few meshes with colour variety, animated in code (bob, cheer, wave), not full Roblox avatars or skinned rigs. The flag official is a rigid-part character animated in code (arm tween), not a skinned rig. Rigid props and UI are animated in code per the animation pipeline rules.
9. **Reduce Motion.** Crowd waves, fireworks, flashing lights and the upgrade reveal all have calm versions under Reduce Motion (fades instead of shakes and flashes).
10. **Sound.** Quiet, layered ambience that grows with the level (birds and wind at level 1, a small crowd murmur later, a cheer on special laps, an announcer horn at the top). Free sounds we are allowed to use only (Roblox Creator Store sounds licensed for experiences, or ones we make). List every asset id. Keep it under the music and never annoying when standing on your plot for a long time.

## 3. The level ladder (recommended: 12)

Each level: what it adds or replaces, and the signature thing a passer-by notices. Treat the details as a strong starting point: improve them, keep the idea.

1. **Backyard Dirt Track.** Packed dirt oval with tyre ruts and dust puffs behind every car. Edges made of hay bales and old tyres. A chalk start line. A hand-painted wooden sign with the owner's name ("Adam's Speedway" style, from the player's display name, filtered as Roblox requires). One wonky flag on a stick, a rusty little shed, a lemonade stand, one folding chair. Charming and humble, never ugly.
2. **Raked and Roped.** The dirt is smoothed, the ruts are gone. A rope-and-stake fence replaces half the hay bales. A painted wooden start and finish board with a checkered stripe. A string of triangle pennants across the main straight. A water barrel and a wheelbarrow.
3. **First Fans.** Small wooden bleachers (three rows) along the main straight with a few crowd figures who bob and clap. A snack cart. A hand-flipped lap counter board.
4. **Paved.** The dirt becomes smooth asphalt with yellow edge lines. Red and white curbs on the corners. The hay bales become a neat painted tyre wall. The rusty shed gets fixed and painted.
5. **The Flag Official.** A small striped podium at the finish line with a referee-style flag official who waves the checkered flag every time a car crosses the line (in sync with the Lap Pay pop when both are visible). A proper painted checkered line. A start light tree. A row of flags along the fence.
6. **Pit Row.** A pit garage with two bays and roll-up doors, a tool chest, stacked tyres, a mechanic figure who spins a wrench, and a painted pit lane.
7. **The Grandstand.** A covered grandstand replaces the bleachers, with a bigger crowd that cheers and stands up whenever a Rare or rarer car crosses the line. An announcer booth with horn speakers.
8. **Lights and Big Screen.** Four floodlight towers with soft light, a start and finish gantry arch over the line with a checkered top and lights, and a big screen showing the Lineup's car names and their Lap Pay (fed by preview data now; Lane 2 data later). The outline's tier 4 screen lives here.
9. **Banked Turns.** The corners become banked with raised outer walls and catch fencing, and the Lineup cars visibly tilt through them. Fictional banners along the walls.
10. **The Overpass.** The track rises onto a raised section that crosses over the infield on supports, with guardrails and orange barriers like the second reference picture.
11. **Jump and Blimp.** A small jump hump where cars catch a little air, flame decals on the run-up (not arrows or chevrons, which belong to the Hop), and a slow fictional Car Hop blimp circling overhead.
12. **Loop of Legends.** A full loop-the-loop on the raised section, a champion statue of the owner's rarest car on a pedestal (outline tier 5), a partial stadium roof, confetti cannons and soft fireworks whenever a Legendary car finishes a lap, and gold trim on the gantry. This is the screenshot level: it should look as good as the second reference.

**If the team picks 15 levels**, slot these in (and say where they fit best): a **Night Lights Show** (coloured light strips that pulse on special laps), a **Second Grandstand** on the far straight with a mascot, and a **Monorail or Sky Tram** that glides around the outside of the plot.

## 4. The upgrade moment and the next-level preview

- **Reveal when a level is bought (about 1.5 seconds):** a puff of construction dust, the new pieces drop or grow into place with a springy bounce, a short confetti burst, the crowd (if any) cheers, and a banner "SPEEDWAY LEVEL 5: THE FLAG OFFICIAL!" in the HUD style. Then normal play. Nothing blocks the player. Reduce Motion version: pieces fade in, no shake. Build it in the preview with a level-up button only.
- **Next-level preview at the Paddock kiosk:** an in-world upgrade board (like the dino game's sign, our own design) showing the current level, the next level's name, a small picture of what it adds, and a price placeholder clearly marked as preview. The next level's main piece can also appear as a faint ghost outline on the plot so kids see what they are working toward. Check this does not clutter the plot.

## 5. Process

1. Find and read the existing Speedway and island code and records (section 0).
2. Plan the module and the kit: which meshes are new, which pieces are reused, the per-level part and triangle budget. Put it in the ledger.
3. Build **levels 1, 6 and 12 first** and compare them against both reference pictures and the island's look. Fix what does not match before building the rest. This is a self-check, not a stop for Adam.
4. Build the remaining levels, the reveal and the kiosk preview.
5. Model new pieces in Blender through Blender MCP (safe mode on), export with the Roblox-safe settings, and upload them. **Creator:** if Adam has given the Car Hop Roblox group's id in chat by then, upload with the group as Creator. If not, ask once, keep building with preview meshes, and do the upload in the end guided moment. Uploading your own Blender meshes for this task is covered by Adam's standing approval: list every asset name and id for review. Do not upload anything else.
6. Also prepare (do not run without the group id) the re-import of the island's 97 Task 4 kit meshes with the group as Creator, the same way the HUD session does the B2 kit, and list it as waiting.
7. Measure performance (section 2, rule 7) and lap timing (rule 2) at every level.

## 6. Message for Brian L (through the vault)

Write `vault/design/specs/speedway-levels-for-brian-l.md` and add an "Up next" row for him on the board (both on main; vault-only commit, then return to the branch). Plain language. Include:
- Adam's decision: 10 to 15 visible Speedway levels, 12 recommended, and the level names from section 3.
- What Lane 3 needs from him: the final level count, the price and Lap Pay effect of each level (his economy model), the save field for the level (propose an integer `SpeedwayLevel` starting at 1), and whether this ladder replaces the outline's Income Tier.
- The look module's interface Lane 3 will expose (a function that takes the plot and the level and assembles it, plus the level-up reveal), so his code only has to send the level number.
- A Replies section for his AI to answer in.

## 7. Review page and finish

- A review page (`Car-Hop-Art\review\speedway-upgrades\index.html`) with: a still of every level from the plaza, a three-quarter view and a close-up; a real-time video with sound going from level 1 to 12 using the level-up reveal; side-by-side frames against both reference pictures; the flag official and the crowd reacting in real time; the kiosk preview; the performance table and the lap timing table; every uploaded asset with its id; what you decided for Adam (reversible) and what needs Adam or Brian L.
- Test in Studio Play in the private island place on desktop and the landscape phone and tablet frames. Separate clearly what you tested in Studio from what you only checked by reading code.
- Run `./scripts/check.ps1` and fix any failures inside my task. Commit, push the branch, open the draft PR (it builds on `feature/lane3-island-environment`), update the board and add my log entry. Do not merge.
- End with: (1) the 12 levels in one line each; (2) what is waiting on Adam; (3) what is waiting on Brian L; (4) the measured cost of six plots at the top level.

**STOP** after the review page for Adam's review.

Read the installed copy at C:\Users\agert\Documents\Car-Hop-Art\briefs\02-speedway-upgrade-looks.md. Original requirements above remain intact; the added sections below apply throughout, including before the final STOP. The reference copy committed to the repository uses the exact path required in section 0.

## Added execution details, apply throughout the brief

These details implement the requirements above. They do not replace an approval, change a fixed value or authorize another lane's work. If a genuine conflict remains, report both passages in the initial question batch and defer only dependent actions. Continue other authorized work. Keep Adam's decisions labeled as decisions and new implementation choices labeled as reversible choices.

### Shared resources and concurrent sessions

- Resolve STUDIO_LOCK.txt using the project's existing shared locking convention. Separate worktree-local copies do not coordinate two sessions. Verify both windows are looking at the same authoritative lock before either controls Studio. Do not silently invent a competing lock system or seize a held lock.
- Record the lock owner, task, intended private place and current action. Acquire it before scene changes, playtests, importer work or connecting Rojo. Verify the actual open place and source server each time ownership changes. Release only your own lock after saving. Never overwrite an unrelated open scene.
- Concurrent rojo serve processes must have distinguishable working directories and supported non-conflicting connection settings. Check the existing configuration instead of inventing a port. Start your task's server in the background as instructed, but do not connect/reconnect Studio until you own the lock. Tell Adam the exact server/place to select, one click at a time.
- Serialize shared live Blender access too. Workers may prepare independent source recipes, but cannot mutate one Blender scene at once. Keep safe mode enabled. Check the combined memory burden before running heavy operations. The 4 GB floor is a whole-system constraint, not a separate allowance per window. Pause heavy work below it without killing unrelated processes.
- Serialize shared main-worktree changes and main pushes. First inspect status, branch, upstream, existing worktrees and the other session's activity. Perform the required main pull and vault-only commits through a clean main checkout. Do not switch a dirty feature checkout, reset, stash someone else's work, include code in a vault-only commit, or force-push.
- Re-read the latest board and preserve concurrent rows/replies. If another normal push advances main, update safely, reconcile only your own changes and retry normally. Do not resolve a conflict by replacing the whole board. The branch-from instructions above remain exact, regardless of main's newer commit.
- Use normal Git operations for the specifically authorized pulls/branches/commits. Do not merge a feature branch or PR. Never include place binaries, generated dependencies, source art or unrelated changes in a commit.
- Before allocating a decision number, inspect every accessible local/remote branch as instructed and refresh remote references where available. Coordinate numbering with the other active session. If full visibility is unavailable, report that limitation rather than claiming collision-free allocation. Do not reuse an existing decision number or rewrite someone else's decision.

### Agent usage and repeatable delivery

- One lead owns integration, manifests, shared files, Git and live applications. At most two Sonnet workers may run concurrently for substantial independent tasks with disjoint files. Do not create workers merely to fill slots or repeat research.
- Explicitly select Sonnet for workers. If the client cannot select or verify their model, use the lead instead. No Opus subagents without Adam's approval. No nested agent spawning or duplicate research teams.
- Use one fresh Sonnet reviewer near completion, preferably after workers finish. Give it the brief, relevant real images/clips and concise evidence, not the whole accumulated conversation. It returns concrete defects by requirement and location. Fix material findings yourself. Re-review only consequential fixes or unresolved material issues. If independent review is unavailable, label the structured self-review honestly.
- Track requirements with status, source, affected file and acceptance evidence. Keep a compact resume note at logical boundaries. Do not repeatedly re-read unchanged large files or produce long progress transcripts.
- Keep the exact lane boundaries stated above. Reading another lane is not editing permission. A preview copy of another lane's system does not authorize changing its production behavior. Communicate only through the specific vault messages and PR comment authorized by this package; do not add unsolicited chats, emails or other PR comments.
- Compare important before/after views from the same camera, place state and graphics settings. Report Studio Play, Studio Edit, Blender/concept images, static code checks and untested behavior separately. Virtual phone frames are layout checks, not physical phone measurements.
- Capture actual motion at normal speed with the required audio. Still frames cannot prove smooth animation, synchronized sound or working cleanup. Keep clips reproducible and labeled.
- Complete the specified repository checks after final edits, update the board/log/ledger/manifest before final scoped commits, and verify push/PR outcomes. Keep current results distinct from dated historical reports. Leave accepted work intact except where this brief explicitly changes it.

## Added Speedway design, motion and verification details

### Twelve preview looks, one maintainable system

Build the recommended 12-look preview while keeping the final team/economy count undecided. The conditional extra three levels remain documented options. Do not label the recommendation as Brian L's approved final progression. Prices, multipliers, Cash, save fields and remotes remain outside this task; `SpeedwayLevel` remains a proposal in the message only.

Use one shared design grammar with level-specific additions/replacements. Preserve the existing track-motion system and approved plot coordinates. Track source state by level so rebuilding, repeated assignment, downgrading and upgrading remove obsolete pieces, effects, sounds and listeners cleanly. No duplicate grandstands, buried dirt under flickering asphalt, abandoned crowd figures, old lights or growing connection counts after cycling the levels.

Give every level a clear plaza-distance signature: surface/edge improvement early, visible spectator capacity in the middle, then elevated silhouette and the loop at the top. Keep the early levels charming with deliberate texture, placement and material choices. They should feel cared for, not broken. The top level should look like a plausible composed miniature stadium, not every prop piled onto an oval.

Use a stable main-straight/finish identity through the ladder. Group functional details around their use: pit equipment at the bays, snack seating near the stand, flags at track boundaries, announcer above the grandstand. Repeat trim profiles, curb style, neutral materials and fictional-sign typography. Keep the late-stage silhouette supported: overpass columns meet the ground, barriers follow deck edges, roof/gantry supports connect, and the loop has a convincing base. Finish backs/undersides seen from the plaza, infield and adjacent plots.

Early dirt dust remains bounded and appropriate to the surface. Paving should remove the old dirt effect. Hay, rope and tyre replacements must follow the specified sequence rather than appearing all at level one. Do not add arrows/chevrons to the jump run-up; retain the requested flame treatment and Hop visual separation.

### Lap timing and server authority

Inspect the existing visual path and timing contract first. Changing path length must not change the approximately 15-second cycle or drive server rewards. Use a distance-aware presentation path so long/curved/elevated sections are traversed coherently while the visual car returns to the finish at the expected phase. Avoid abrupt artificial speed changes at joins, banking flips, upside-down discontinuities in the loop and snapping across the jump.

The visual jump/loop is cosmetic: it cannot propel players, alter real vehicle physics, grant rewards or create new network ownership. Bank/loop orientation should be continuous relative to the path, with a controlled transition back to flat road. Keep car pivots and scale consistent using existing allowed previews/assets; never modify Brian L's car source.

Synchronize the finish-crossing, flag wave and visible Lap Pay cue through existing supplied timing/event data. Do not implement a server pay timer or trigger money from a collision. If no authoritative event is currently wired, demonstrate a clearly labeled synchronized fixture and record the integration need; do not report production pay synchronization as tested.

For each level, report measured cycle duration and visible crossing-to-pop offset using a documented method, and compare to the existing required cadence. Do not invent a new timing tolerance or call unmeasured timing exact. Repeated lap behavior and reset matter as much as one carefully aligned recording. Preserve per-car phase offsets where the existing lineup uses them.

### Visitor safety and fit

Measure against plot/reservation bounds for each level, including blimp motion, loop height, roof, signs, raised deck, particle envelope and ghost preview. Check the Paddock, gate, nameplate, path network and plaza view with actual placements. Do not squeeze props into a protected route just to fit the inventory.

Walk into, around and underneath raised structures in Play. Test beside supports, loop bases, banking boundaries and the transition while a visitor is present. No trapping, launching, wedging, invisible walls across normal paths or unintended car collisions. Decorative tiny parts use appropriate interaction/collision settings; guard geometry must protect visitors without blocking required access. Do not change another lane's physics or reward services to pass these checks.

### Crowd, effects and six-plot cost

Use rigid code-animated figures and props as required. Spectator reaction should be localized and bounded, not a stadium-wide permanent cheering loop. Ordinary laps, Rare-or-better reactions and Legendary effects follow supplied rarity/timing fixture data only. Coalesce overlapping celebrations across cars, respect Reduce Motion and stop hidden/distant effects. Quiet ambient layers should not multiply into a loud wall when six plots are nearby.

Distance detail preserves each level's main silhouette. Far plots omit crowds, small props and motion as required, without leaving floating signs or opening holes in the main track. Avoid repeated detail switching at the same distance boundary and keep the active animation workload bounded. Inspect transitions from a walking camera, not only static screenshots.

Measure every level and six simultaneous top-level plots under a reproducible workload, including populated lineups and a representative celebration. Record available instances, mesh complexity, draw-call/profiler data and frame times with camera/settings/sample method. If a metric cannot be measured by the available tool, mark it unavailable rather than fabricate it. Every result is a desktop measurement; a phone-sized viewport does not turn it into a phone-device benchmark. Set proposed budgets from inspected baseline evidence, not invented measured numbers. Explain tradeoffs if a budget fails.

### Upgrade presentation and record

The level-up preview button drives cosmetic assembly only. Reveal effects must not block input, create falling physical hazards or leave half-built scenery after rapid clicks/reset. Downgrading for inspection is clean and does not imply a player can sell/refund progression. Ghost preview is clearly prospective, nonblocking and visually quieter than the active track, and turns off for final clean captures.

The kiosk uses child-readable current/next names, a useful original picture and a clearly labeled preview price, without an invented currency amount. At the highest preview level, show a sensible completed-preview state instead of an invalid next level. The visible look module contract remains a proposal until coordinated; Brian L owns the eventual save/economy connection.

For the source-art message, preserve the 10-to-15 decision, 12 recommendation, Slots separation assumption and all requested questions. Add the Replies section without writing an answer for Brian L. Use the required vault-only main delivery and preserve concurrent rows. Record the island's 97-mesh group re-import as prepared/waiting as instructed, and do not interpret this wording as an order to upload other assets or transfer an experience.

Honor the final STOP. The final review includes all level views, actual motion with sound, every required cost/timing row, comparison to both references, imports and remaining team decisions. Independent reviewer critique should focus on plaza readability, coherent progression, motion joins, visitor safety and proof of the six-plot test, not arbitrary extra decoration.
