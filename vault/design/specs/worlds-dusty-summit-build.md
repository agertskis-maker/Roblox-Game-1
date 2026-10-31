# Brief: Lane 3 Dusty Highway and Summit Pass build (2026-10-28)

From Adam (Lane 3 owner, repository owner). Read this whole file before doing anything. Treat it as the specification for this session. Everything in it is required unless it says "proposal" or "optional". I love Downtown. These two Worlds currently look minimal, basic and disorganized. They must reach the same level of density, detail and polish as Downtown, each true to its own theme.

## 0. Where this work happens

- Worktree: `C:\Users\agert\Documents\Roblox-Game-1-hud`. Run only after the HUD round 3 close-out session has finished and pushed `feature/lane3-hud-downtown-lookdev`. Create the new branch `feature/lane3-worlds-dusty-summit` from `feature/lane3-hud-downtown-lookdev`, and open a draft PR to main at the end that says it builds on that branch.
- Read first: `AGENTS.md`, `vault/tasks/BOARD.md`, both plans `vault/design/specs/world-plan-dusty-highway.md` and `vault/design/specs/world-plan-summit-pass.md` (including their concept images), the round 3 review `Car-Hop-Art\review\hud-round3\REVIEW-ROUND3.md`, the close-out brief `01-hud-round3-closeout.md` and its results, the Downtown kit and its manifest, and `vault/design/assets.md`.
- Copy this brief into the repo as `vault/design/specs/worlds-dusty-summit-build.md` on the new branch and commit it.
- My private task places only. Never the shared Team Create place. Respect `STUDIO_LOCK.txt` (the Speedway session may be running at the same time) and the 4 GB free-memory floor.
- Finish as much as possible in one go. One review stop at the end. Batch every click I must make (mesh imports) into one guided moment.
- Do not touch Brian R's lane (`src/client/Run`, `src/shared/Run`) or Brian L's lane (`src/server`, `src/shared/Catalog`, `src/shared/Net`, `assets/cars`).

## 1. Approval: both plans are approved with Claude's recommended answers

Adam approves both World plans on 2026-10-28 with the answers below. This is the approval both plans asked for. Write the answers and the date into each plan's "Approval requested" section and record a decision note in `vault/decisions/` (next free number after checking every branch, so it does not collide).

### Dusty Highway (answers to the plan's 11 questions)
1. **Direction:** the visual grammar G1 to G10 and the five-district template are approved as written.
2. **Names:** keep all five district names. Do NOT rename Sandstone Arch. DO add the small second arch so "Red Rock Arches" earns its plural.
3. **Canyon Bridge:** Option A, the true gorge. Build it in the Lane 3 look-dev preview. Anything that changes gameplay (falling, collision, hop height or the road and ground contract) is Brian R's: write him a message (section 3) and do not change his code.
4. **Arch:** approve the thick arch beside the road. Write the drive-through version as a proposal for Brian R; do not build it now.
5. **Verge palette swap** (clay verge, road meshes unchanged) and the **sky and light tests** in a private place: approved.
6. **Planner changes** (Lane 3 look-dev code only): all approved: grouped lots, district density weights, irregular pole rhythm, per-district sub-seeds, landmark yaw, tumbleweeds skipping bridges.
7. **Scenery vehicles:** none in v1. Note it as a later item that will use Brian L's finished cars.
8. **Budgets:** accept the provisional targets in 8.2 as ceilings to test against.
9. **Motion:** approve all three: at most two pennant strings, the windmill wheel and the shimmer strip, within the stated limits.
10. **Scope:** build P1 and P2. Build P3 only if the measured performance stays inside the 8.2 ceilings; list any P3 item you skip and why.
11. **Uploads:** guided OBJ batches, Adam clicks the importer. Creator is the Car Hop Roblox group (section 4).

### Summit Pass (answers to the plan's 15 questions)
1. **Direction:** keep the five district names and the bright alpine morning; adopt "backdrop first" and the plan's priority order.
2. **Mountain system:** retire the stacked cones from the visible foreground; adopt far massifs, ridge curtains and spurs, and one recurring summit horn.
3. **Scale:** the deliberate exaggeration in 5.8 is approved (pines 26 to 44, tower 64, lodge hall up to 58).
4. **Frozen Lake:** approved as planned: plane at least 240 x 360 with rim, 40-stud buffer and fence, the small planner companion addition, and no shortcut across it.
5. **Glacier Tunnel:** approved: opaque horseshoe gallery with sky windows and gallery bays, zero transparency, the exit-exposure rule.
6. **Ski lift:** the Default now (static crossing at 64 studs or more, chairs move only off the road). Option M (chairs crossing over the road) is a proposal for Brian R, because it needs his hop apex.
7. **Lodge:** approve the stepped 120-stud lodge, and promote the small festival terrace stage from tier B.
8. **Landmark order and spacing:** approved: observatory, snowmen, lodge hint, 300 to 440 spacing, majors at least 500 apart.
9. **WELCOME span:** "WELCOME TO SUMMIT PASS" on the first loop only; later loops show a different span, "KEEP CLIMBING!", in the same style.
10. **Bunting:** enable it as static roadside garlands in the bunting colours (no orange), none within 120 studs before a hazard.
11. **Name refinements:** all approved: the clock tower label, "Terrace Chalets", and the new sign names LOG PILE BAKERY, YODEL YARN, FIRESIDE BOOKS, GOGGLE GARAGE, LODGE LOG CAFE, SKATE SWAP. District names stay.
12. **Lighting test:** approved: the warm sun tint and the road-contrast retune in a private place.
13. **Budgets:** accept the provisional budgets in 8.2 as ceilings to test against.
14. **Uploads:** the standing approval applies (Claude Code may upload its own Blender meshes and palette images for these two Worlds, listing every asset name and id). OBJ route, Adam clicks the importer. Creator is the Car Hop Roblox group (section 4).
15. **Lane 1 asks:** send Brian R the open contracts from 8.4 through the vault (section 3).

## 2. Build

- Follow each plan's phases (section 8.4 of each). Build Dusty Highway first, then Summit Pass, unless the plans' dependencies say otherwise.
- After the first district of each World, compare it side by side with Downtown at the same camera and the same time in the run. If it does not reach Downtown's density, layering from road to skyline, landmark rhythm, colour and signage, fix it before building the next district. This is a self-check, not a stop for Adam.
- Both Worlds must repeat seamlessly so a run can go on forever, as the plans describe, with no visible seams or obvious repetition.
- Keep the road readable and the hazards distinct, as each plan's rules say. Scenery never looks like the Hop ring, the trail chevrons or the Keys ring.
- Measure performance against each plan's 8.2 ceilings (instances, triangles, draw calls, frame time), labelled as desktop measurements. Fix what goes over before adding P3 items.

## 3. Messages for Brian R (through the vault)

Write `vault/design/specs/worlds-dusty-summit-for-brian-r.md` and add an "Up next" row for him on the board (both on main; vault-only commit, then return to the branch). Plain language, from Adam. Include: the Canyon Bridge gorge and what it needs from his road, ground and falling rules; the drive-through arch proposal; the ski lift Option M proposal and the hop apex it needs; every open Lane 1 contract from both plans' 8.4 sections. For each: benefit, risk, how to test, and what Lane 3 built in the meantime. Add a Replies section for his AI to answer in.

## 4. Uploads under the Car Hop group

- All new meshes and palette images for these two Worlds are uploaded with the Car Hop Roblox group as the Creator, following the group ownership decision note the close-out session wrote. If that note or the group id is missing, ask Adam once, keep building with preview meshes, and do the uploads in the end guided moment.
- When Claude Code's permission prompt asks Adam to allow the importer clicks, he will approve it. Do not work around it any other way.
- List every asset name and id in `vault/design/assets.md` and on the review page. Do not upload anything else.

## 5. Review page and finish

- A review page (`Car-Hop-Art\review\worlds-dusty-summit\index.html`) with: stills of every district of both Worlds from the run camera, before and after against the current previews, and side by side with Downtown; a real-time run video with sound (music included) through each whole World; the performance tables against the 8.2 ceilings; every uploaded asset with its id; any P3 item skipped and why; what you decided for Adam (reversible) and what needs Adam or Brian R.
- Test in Studio Play in the private task places on desktop and the landscape phone and tablet frames. Separate clearly what you tested in Studio from what you only checked by reading code.
- Run `./scripts/check.ps1` and fix any failures inside my task. Commit, push the branch, open the draft PR (it builds on `feature/lane3-hud-downtown-lookdev`), update the board and add my log entry. Do not merge.
- End with: (1) what was built in each World; (2) what is waiting on Adam; (3) what is waiting on Brian R; (4) the measured cost of each World against its ceilings.

**STOP** after the review page for Adam's review.

Read the installed copy at C:\Users\agert\Documents\Car-Hop-Art\briefs\03-worlds-dusty-summit-build.md. Original requirements above remain intact; the added sections below apply throughout, including before the final STOP. The reference copy committed to the repository uses the exact path required in section 0.

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

## Added World build quality and acceptance details

### Translate approved plans faithfully

Read both full plans and their concept images before implementation. Build a ledger mapping every approved answer to its plan section, source asset/module, test and review evidence. Preserve the approval date, exact names, dimensions, motion limits, P1/P2/P3 conditions and budget ceilings. If a referenced plan/section is missing or its content differs materially from the approval text, report that dependency; do not invent G1 to G10, section 8.2 budgets or phase definitions.

The close-out session must be finished, clean and pushed before this session starts in its worktree. Inspect the actual branch and remote result, not only a completed board row. Do not race Session 1, reuse a dirty working tree or start from main instead of the prescribed HUD branch. Keep the new World branch and draft PR lineage exact.

Once the current approvals are recorded, build as authorized. Do not revive the previous plan-only gate or ask Adam to approve the same answers again. The retained end-of-build STOP still applies. A new issue affecting a lane boundary or supplied approval is handled through the prescribed question/vault process, not by silently changing the approval.

### Benchmark Downtown's composition, not its literal assets

Use matching chase camera, vehicle scale and comparable route position for the first-district comparisons. Identify the relevant foreground frame, roadside detail groups, medium landmarks and far silhouette layer in each World. Match Downtown's intentional visual hierarchy and finish while preserving desert/alpine negative space. Density does not mean identical object counts or city buildings transplanted into sand and snow.

Fix first-district composition before spreading its modules. Large silhouettes and readable material masses come before small props. Every major landmark needs a believable approach, passing side and exit view. Finish backs/undersides visible from the route. Use supported forms, controlled trim/material families and deliberate prop clusters. Avoid repetitive cone mountains, random tiny clutter, floating signs, unsupported arches and aggressive glow masking weak geometry.

Dusty Highway must retain Sandstone Arch and the approved small second arch. The thick main arch remains beside the road. No drive-through arch built under the guise of scenery. The gorge is real in the look-dev composition, while gameplay falling/collision/ground changes remain explicitly outside Lane 3. Keep temporary preview safety/route assumptions clearly labeled and document what Brian R must provide. Tumbleweeds skip bridges, motion is limited exactly as approved, and scenery vehicles stay out of v1.

Summit Pass must follow backdrop-first order: broad far massifs, separated ridge curtains/spurs and the recurring horn establish mountain scale before foreground chalet/prop detail. Preserve the approved exaggerated dimensions rather than replacing them with more timid generic assets. Snow/rock/pine materials need distinct readable value groups, without blown-out white flats or indiscriminate shiny ice.

The Frozen Lake's approved plane size, rim, buffer/fence and no-shortcut rule must be measured and shown. The opaque horseshoe gallery keeps zero transparency and the plan's exact exit-exposure rule, not a glass-block substitute. The lift default remains the static crossing at the approved clearance; chairs moving across the road remain Option M only. Distinguish a chair's off-road motion from an unapproved moving over-road crossing. Preserve lodge, terrace promotion, landmark order/spacing, first-loop versus later-loop span text, sign names and bunting exclusions exactly.

### Seamless repetition and actual ceilings

Use deterministic route/module data and repeatable seeds. Inspect a full repeat boundary, joins, skyline continuity, material transitions, sign recurrence and active-window cleanup. The same seed must reproduce the same defect for debugging. Endless presentation cannot accumulate every prior segment indefinitely or repeat a unique hero landmark so often it becomes wallpaper.

Do not alter Brian R's road meshes, lane contract, hop apex, hazard eligibility or gameplay to hide a scenery problem. Keep scenery cues distinct from target/Keys visuals and actual hazard colors. Respect every buffer and exclusion from the plans, including the Summit bunting distance before hazards.

Copy the actual 8.2 ceilings into performance tables with source references. Use identical measurement definitions where comparing against Downtown. Distinguish unique exported meshes from visible instances, total source triangles from visible rendered workload, and sampled frames from inferred performance. Mark unavailable draw-call/profiler measurements honestly. These are desktop measurements, including when a phone viewport is selected.

Measure P1/P2 before adding performance-conditional P3. If a ceiling is exceeded, first fix unnecessary hidden detail, duplicate geometry, unused animations or excessive effects within the approved direction. Do not silently increase a ceiling or remove a required P1/P2 landmark. Report any remaining failure and each skipped P3 item with its measured reason. Conditional scope is not permission to call unbuilt P1/P2 complete.

### Group uploads, messages and final evidence

Verify the exact group note/name/ID and actual Creator before imports. If missing, ask once and continue with clearly labeled previews as instructed. Keep original recipe/export provenance, stable names, pivots, materials and old/new reference mapping. One guided OBJ batch means an organized user-assisted importer flow, not a promise that every tool action is literally one click. Do not automate around a denied permission.

After upload, verify each referenced mesh/palette loads in Studio Play for the intended place/experience context and group permissions. Capture final evidence after references are wired. Blender renders or imported-but-unreferenced files are not proof of in-game completion. No unlisted uploads, group configuration or experience transfer/publishing.

The Brian R vault message must cover every open contract from both plans, not just the headline gorge/lift questions. Preserve benefit, risk, test and temporary Lane 3 choice for each. Keep replies intact and do not fabricate acceptance. Deliver on main through the shared vault procedure, then finish on the correct feature branch.

The final page pairs every district's old/new route views with comparable Downtown evidence, includes whole-World real-time video with actual game audio, performance-versus-ceiling results, asset IDs, skipped P3 scope, reversible choices and waiting items. Clearly label Studio Edit versus Play and untested physical devices. Honor the final STOP for Adam's review and do not merge either prerequisite or new PR.
