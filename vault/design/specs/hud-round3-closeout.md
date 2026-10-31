# Brief: Lane 3 HUD round 3 close-out (2026-10-28)

From Adam (Lane 3 owner, repository owner). Read this whole file before doing anything. Treat it as the specification for this session. Everything in it is required unless it says "proposal" or "optional".

## 0. Where this work happens

- Worktree: `C:\Users\agert\Documents\Roblox-Game-1-hud`. Branch: `feature/lane3-hud-downtown-lookdev` (continue it; do not make a new branch). Draft PR #2 stays the one place for this work. Do not merge it.
- Read first: `AGENTS.md`, `vault/tasks/BOARD.md`, `Car-Hop-Art\review\hud-round3\REVIEW-ROUND3.md`, the round 3 review page `Car-Hop-Art\review\hud-round3\index.html`, the round 3 ledger `vault/design/specs/hud-round3.md` and `vault/design/specs/hud-round3-forwardable-messages.md`.
- Copy this brief into the repo as `vault/design/specs/hud-round3-closeout.md` on the branch and commit it, so the record does not depend on the Car-Hop-Art folder.
- Private HUD playground place only. Never the shared Team Create place. Respect `STUDIO_LOCK.txt` (another Lane 3 session may be building the Speedway at the same time; only one session holds Studio) and the 4 GB free-memory floor.
- Finish as much as possible without stopping. The only stops allowed are the ones this brief names. Batch everything that needs my click into one guided moment.
- Do not touch Brian R's lane (`src/client/Run`, `src/shared/Run`) or Brian L's lane (`src/server`, `src/shared/Catalog`, `src/shared/Net`, `assets/cars`).

## 1. Decisions from Adam on the round 3 review

1. **ENGINE HEAT size: confirmed final.** Phones 14 px (scale 0.875), Desktop and Tablet 17 px (scale 0.708). Remove "provisional" from the ledger, the decision note (0023) and the Heat coverage table. Do not change the numbers.
2. **Cash icon band: approved as it is.** Mark it approved. No changes.
3. **Hop button car icon: the car stays, the arrow must be redone.** Adam's words: the arrow looks really weird. See Part 2.
4. **Review videos may include music and all game audio from now on.** Adam cannot judge the music otherwise. See Part 3.
5. **Messages for Brian R and Brian L go into the vault**, where their own AI reads them at session start. See Part 4.
6. **Brian R's note 0021 (run report proposal) is Agreed** by Adam and by Brian L. Brian L's agreement was given in person and relayed by Adam on 2026-10-28. See Part 5. Note 0022 is NOT decided yet; leave it alone.
7. **Adam is creating a Roblox group now** to own the game. See Part 6.

## 2. Hop button: redesign the hop arrow (keep the car)

The car part of the icon stays. The arrow is the problem. Research how top mobile and Roblox games draw a "jump" or "hop" action icon, then redesign only the arrow.

Requirements:
- It must read instantly as "the car jumps up and over to another car". It must not read as undo, refresh, upload, back, a U-turn, or a share icon. Test this by asking yourself what each candidate would mean with no context, and say so in the review.
- One clear, chunky curved arc that leaves the car's roof and lands up and to the side, with a bold, simple arrowhead. Same thick dark outline weight and the same gradient and gloss language as the rest of the HUD (the Cash counter and the Garage, Shop and Settings buttons). No thin lines, no gaps in the stroke, no tiny details that vanish at phone size.
- Keep it distinct from the in-world Hop reticle, the dashed ring and the hop trail chevrons, so the button never looks like part of the road overlay.
- It must work in all four existing states (ready, targeting, cooling down or disabled, out of Stamina with the crossed bolt) and at the real button size on PhoneSmall, PhoneLandscape, Tablet and Desktop. The touch target stays at least 44 px.
- Make **four candidate arrows** (for example: a single tall arc; an arc plus two small motion streaks under the car; a short arc with a springy "boing" curl at the start; a car tilted nose-up with a bold arc over it). Show all four side by side at real size, in all four states, on top of a real Downtown gameplay frame (not on a flat background).
- **Pick the one you judge best, implement it, and keep the other three switchable** with one constant so Adam can swap by saying its letter. Explain in two sentences why you picked it.
- Respect Reduce Motion for any press or pulse animation on the button.

## 3. Review media with sound

- From now on, review videos include game audio (music, sound effects, fanfares). Record this as a standing rule wherever the review-video rule already lives (the rule that animated things are reviewed as real-time video), so every future session follows it. Keep muted versions only if a clip has a specific reason to be silent, and label them.
- Find out whether the current capture setup records audio. If it does not, find the smallest free way to record Studio's game audio on Windows (for example ffmpeg with a loopback audio device). Free, reputable tools only. Nothing paid. If a step truly needs Adam (a Windows permission or a device setting), batch it into the guided moment.
- Re-record with sound, at normal speed, and put them at the top of the review page:
  1. each World's music track for about 20 seconds (Downtown, Dusty Highway, Summit Pass, and the island and any other tracks shipped);
  2. a full capture: landing, the Keys ring filling with the chime ladder, the ring pulse, the SECURED reveal and fanfare;
  3. Stamina running from 10 to 0 with its warning cues;
  4. a Heat run from calm to Meltdown;
  5. the new Hop button press with its sound, if it has one.
- After the clips exist, do one more volume balance pass by actually measuring loudness from the recordings (peak and average per sound), not only from property values. Nothing harsh or loud; music stays under the sound effects and ducks under fanfares. Report the measured numbers.

## 4. Messages for Brian R and Brian L, delivered through the vault

Their AI reads `AGENTS.md` and `vault/tasks/BOARD.md` at the start of every session, so that is how they receive these.

- On `main` (vault changes are allowed on main by the branch policy): add `vault/design/specs/hud-round3-forwardable-messages.md` at that same path, rewritten so it speaks to them directly from Adam. Change its status from "drafts, not sent" to "sent through the vault by Adam on 2026-10-28". Remove the "for Adam to forward in his own words" framing. Keep every technical detail, path, table and question. Add a "Replies" section at the end with one heading for Brian R and one for Brian L where their AI writes the answers.
- Add to that same file, for Brian L: **when he uploads car meshes, he should upload them with the new Car Hop Roblox group as the Creator** once the group exists (see Part 6), so they never need a re-import. If he already uploaded cars under his own account, list that as something to discuss, not an order.
- On the board's "Up next" (on main), add one row for Brian R and one for Brian L, each naming the sections of that file meant for them and asking them to answer in its Replies section. Keep them short and plain.
- Commit and push only those vault files to `main`, then return to the feature branch. Do not include any code in that main commit.

## 5. Brian R's PR #3: note 0021 is Agreed

- Do not edit Brian R's branch and do not merge his PR.
- Post one comment on PR #3 with `gh`: "Agreed: vault/decisions/0021-run-report-proposal.md. Adam (Lane 3) and Brian L (Lane 2, relayed by Adam on 2026-10-28). Note 0022 is not decided yet. Brian R merges after the GitHub check passes, per AGENTS.md."
- Record the agreement on the board (on main) next to the Lane 1 row, and in my log entry.
- Look at what PR #3 means for the HUD and write it down for later, without building anything: which read-outs his run prototype already sends to my RunHud (Heat and Distance), which ones are his labelled placeholders that Lane 3 will design (Keys meter, Hop ring, Stamina, nameplates and any others), and which interfaces the HUD will need from him. Put this as a short "Integration with PR #3" section in the ledger. This is the plan for the next HUD round, not work for this session.

## 6. The Roblox group

Adam is creating the group right now.

- At the start of this part, if Adam has not yet given you the group's name and ID in chat, ask him for them once, then keep working on everything else and come back to this part when he answers. If the session reaches the end without an answer, leave this part prepared and list it as waiting.
- Check current official Roblox documentation (Creator Hub) before acting: how to upload meshes and images in Studio with a group as the Creator, what permission Adam needs in the group to do it, whether an existing user-owned experience or place can be transferred to a group today, and whether a group-owned experience can use assets owned by a user. Do not rely on memory. Cite the pages in the review.
- Then, with the group ID: re-import the B2 Downtown kit (180 meshes and 5 palette images) with the group as the Creator, through the same OBJ route as before. When Claude Code's permission prompt asks Adam to allow the importer clicks, he will approve it. Do not work around it any other way. Swap the kit's ids in `src/lookdev/Downtown/KitIds.luau` and `vault/design/assets.md` to the group-owned ones, keep the old user-owned ids listed as "retired, user-owned" in the asset record, play-test, and confirm with screen_capture and the console that the kit still loads. Report how many of the 180 load on the route, as before.
- Write a short group ownership note (`vault/decisions/` with the next free number, after checking every branch so the number does not collide, as you did for 0023): what is owned by the group from now on, that all future uploads by any lane use the group as Creator, what still sits under Adam's account (the island's 97 Task 4 kit meshes on `feature/lane3-island-environment`, which the Speedway session handles) and under Brian L's account, and how the private test places and the future shared place relate to the group.
- Do not publish anything, do not change any experience's settings, and do not create or configure the group yourself.

## 7. Verify and finish

- Test every change in Studio Play on all landscape frames and Desktop. Before and after stills plus clips with sound. Separate clearly what you tested in Studio from what you only checked by reading code.
- Run `./scripts/check.ps1` and fix any failures inside my task.
- Commit, push the branch (no force), and update PR #2: what changed, what was actually tested in Studio, anything a teammate must do after pulling.
- Update my task on the board and add my log entry. If another session wrote board or log entries for this work, merge rather than duplicate.
- End with: (1) the Hop arrow you picked and the letters of the other three; (2) the measured audio table; (3) what is still waiting on Adam; (4) the group status.

Read the installed copy at C:\Users\agert\Documents\Car-Hop-Art\briefs\01-hud-round3-closeout.md. Original requirements above remain intact; the added sections below apply throughout, including before the final STOP. The reference copy committed to the repository uses the exact path required in section 0.

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

## Added close-out quality and acceptance details

### Preserve final decisions and isolate the arrow change

The final Heat values are exactly Phones 14 px (scale 0.875), Desktop and Tablet 17 px (scale 0.708). Do not reinterpret what those values measure from memory. Locate their current implementation and approval record, update the status to confirmed final, and verify the rendered result without changing either number. If a source mismatch exists, report it rather than choosing replacement sizes. The Cash band is approved and must not be repainted or regenerated during this task.

The car in the Hop icon stays unchanged. The example of a tilted car is a concept suggestion, not permission to alter the accepted car artwork. Express motion through the four arrow alternatives while retaining that car. Use clear candidate letters consistently in source, review images and the selection constant. Candidate switching must preserve the four existing action states, hitbox, input behavior and Reduce Motion preference.

Judge each arrow by silhouette first: a visible roof origin, an upward/over arc, then a clearly directional landing arrowhead. Avoid nearly closed circles, symmetric loopbacks and vertical shaft shapes that read as refresh, undo or upload. Make the arc thick enough at native button size without hiding the car or crossing the out-of-Stamina symbol. Maintain intentional negative space between car, arc and border.

Produce the required real-size candidate/state matrix over actual Downtown frames on all named sizes. Supplement with enlarged inspection views if helpful, but do not use those instead of native-size proof. Record the no-context interpretation of each candidate as the lead's judgment, not fabricated user-test results. Explain the selected letter in the requested two sentences. Keep alternate arrow assets and state mapping usable through the one constant, rather than four duplicate button controllers.

### Audio evidence that Adam can judge

Inventory shipped tracks before recording, including alternate selections, island music and any other actually shipped audio. The requested World clips must identify which track and A/B selection is heard. Do not add a nonexistent island track to satisfy a checklist. If the private HUD place cannot access a shipped track from another task, document the missing access and coordinate only through the established lock/permission workflow.

Inspect current recording capability before installing anything. Prefer already available reputable free tools and a supported audio capture device. Verify the tool and Windows capture method in current official documentation. Do not guess device names, API support or installer sources. Batch permission/device actions for Adam, one click at a time; do not bypass a denied prompt. Record only intended game audio, avoiding unrelated microphone/notification audio where the setup supports isolation. Capture a short check and verify the recorded file really has audible synchronized audio before generating all clips.

Measure peak and a clearly defined average loudness metric from the recordings, using the same method, units, capture level and analysis windows. State the metric and method so values are comparable. Do not invent a target number, confuse an application Volume property with measured loudness, or attribute a mixed track's peak to an isolated sound without evidence. Use isolated audition windows where necessary, followed by combined gameplay mix tests. Record music bed, chime/fanfare, warning and other relevant cue measurements, clipping/harshness observations, and the balance changes made.

After balancing, regenerate or clearly supersede outdated top-of-page clips so Adam hears the final mix. Test Music/SFX mute, fanfare duck/recovery, repeated capture, Stamina zero warning, Heat Meltdown and reset. No stuck ducking, simultaneous duplicate tracks or loud startup. Keep the approved media-with-audio rule as written; if a specific asset has a documented usage restriction or a tool cannot record audio, state the concrete blocker and prepare an authorized alternative rather than quietly replacing every clip with a muted version.

### Exact vault delivery and agreement records

Before rewriting the forwardable-messages document, preserve its technical tables, paths and questions. Retain any existing replies and other session text. Address Brian R and Brian L directly from Adam, use the exact sent status/date, and add the requested Replies headings without fabricating their answers. The board must point to this exact file and the sections each person should read. A pushed vault message means delivered to the shared repository, not proof that either teammate read it.

Post the PR #3 comment with the exact text in Part 5. Inspect existing comments first so a resumed run does not post it twice. Use structured text or a temporary body file for gh to preserve punctuation and real newlines. Verify the intended repository/PR before posting. Record the comment result. This authorizes that comment and vault delivery, not editing Brian R's code or deciding note 0022.

Inspect PR #3 and its source read-only to write the Integration section. Distinguish actual Heat/Distance outputs, labeled placeholders, proposed interfaces and unknowns. Do not build the next HUD integration or count the agreement as a code merge.

### Group transition without losing provenance

Ask once for the exact group name and ID if not supplied. Do not infer them from a similar community name or personal account. Verify the upload Creator and permissions against current official documentation and the actual UI before approving a group batch. The 180 meshes and 5 palette images are the required B2 inventory; reconcile actual source/export names against it and report missing items instead of inventing substitutes.

Record each old/new asset mapping and verification status. Keep retired user-owned IDs available in the asset record. Verify dimensions, pivots, material/palette appearance and asset access after replacement, not only successful importer completion. Count which of the 180 actually load on the route and explain unloaded/unreferenced members. Keep an old/new comparison and inspect console plus screen_capture as required. Do not claim re-import transfers ownership of the original asset; record new group-owned asset IDs accurately.

The HUD session handles B2 only. The Speedway session handles preparation of the island's 97 Task 4 mesh re-import. Coordinate that ownership so the same kit is not uploaded twice. The group decision note must preserve unknown Brian L asset ownership as unknown until verified and distinguish personal local test places from future experience ownership. No group creation/configuration, experience settings changes, transfers or publishing occur in this session.
