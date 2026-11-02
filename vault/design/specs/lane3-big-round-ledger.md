---
title: Lane 3 big round ledger
tags:
  - lane3
---

# Lane 3 big round ledger

Brief: `lane3-big-round.md`. Resume at the first row that is not done. Evidence is in `Car-Hop-Art/review/map-fixes/evidence/`. Tags on notes: OBSERVED, VERIFIED, PROPOSED, UNVERIFIED.

| ID | Requirement (short) | Status | Evidence | Choice made / note |
|---|---|---|---|---|
| B-01 | Start of session. Read `AGENTS.md` and `vault/tasks/BOARD.md`. Switch to `main` and pull. ... | done |  | Tooling unchanged on main; rokit and wally run in the worktree |
| B-02 | Branch and worktree. Create the feature branch `feature/lane3-big-round` from `main` (all ... | done |  | Worktree Roblox-Game-1-biground, new branch from main; root checkout left alone with its own uncommitted changes |
| B-03 | Claim. Add a board row "Lane 3: Big round (polish, Worlds, Shop, Tutorial and the rest of ... | done | 7605ce9 | Board row on main |
| B-04 | Places. Work only in private places: the island test place for M1 to M5, the Downtown look... | done |  | Private island place, local files only; published beta untouched |
| B-05 | Figma. Check whether Figma (the connected tool or Adam's free plan) still has usage left. ... | done |  | Figma not used; straight to Studio (decision 0031) |
| B-06 | Integration test branch. Tutorial run steps, Worlds under the road and the beta checks nee... | done | Roblox-Game-1-beta2 | integration/beta-2 from beta-1 plus this branch |
| B-02a | Preserve any active session's working tree. Check branch, changes, worktrees and lock owne... | done |  | Separate worktree per branch; no lock file existed; Studio was closed at the start |
| B-06a | Use one lead agent. At most two Sonnet subagents may be active at once, with narrow tasks ... | done |  | One lead, at most two Sonnet builders at once |
| M1-01 | Build a reusable checker (Lane 3 code, for example `src/island/Hub/Preview/OverlapChecks.l... | done | OverlapScan.luau, OverlapChecks.luau | Run: see the header of src/shared/Island/OverlapScan.luau |
| M1-02 | Fix at the source. Every fix goes into the recipe or kit code that generates the geometry ... | done |  | All fixes in recipes |
| M1-03 | Scope: island (park, plaza, plots at Raceway levels 1 to 12, portals, Garage, Stunt gate, ... | partial |  | Island, Raceway, Worlds scanned. Internal mesh flicker is not provable by the scanner (about 4,900 MeshParts on the island) |
| M1-04 | Done when: the checker reports zero flicker-severity findings in every scene (or a justifi... | partial | see RESULT.md | Zero supported-surface findings; slow Play walk past every building not done |
| M1-01a | Build an editor/test diagnostic, not a permanent per-frame scanner. Collect eligible visib... | done | 1.5 s for 10,591 surfaces | Grid of 32-stud cells, on demand only |
| M1-01b | Narrow phase for block Parts: transform their actual six face polygons and normals to worl... | done | selfTest | Real wedge and corner wedge faces, confirmed by raycast probes |
| M1-01c | MeshParts: their bounds and collision hulls are not the visible triangles. Bounds can flag... | done |  | MeshParts counted as manual, never cleared |
| M1-01d | False-positive control: ignore invisible helpers by explicit role; keep intentional water,... | partial |  | Same-way faces only; support tested at five footprint points. No exception list was needed |
| M1-04a | Verify the checker on a tiny diagnostic scene: exact duplicate slabs, a 0.01-stud offset, ... | done | 9 of 9 after one test fix | Expected versus observed from Scan.selfTest() |
| M2-01 | Paths and plaza surfaces. Rebuild the path and plaza surfaces so that: every surface sits ... | done | OverlapChecks floorHoles 0 | Mitred joints, forecourt fan, height layers |
| M2-02 | Nothing growing through paving. No grass tufts, flowers, rocks or clutter on any walkable ... | done | grassOnPaving 0 | Layout.onPaved |
| M2-03 | Flower beds placement. Each bed is either parallel to the path it borders with one consist... | done | bedsTooCloseToPaving 0 | One 2-stud clearance |
| M2-04 | Flowers inside beds. Place flowers using each bed's real outline (oval, leaf, wedge, round... | done | flowersOutsideRim 0 of 422 | Footprint corners against the true outline |
| M2-05 | Loose flower patches on the lawn (screenshots 01, 10, 13) are removed, or turned into a fe... | done |  | Removed |
| M2-06 | Benches. Fewer benches. Benches only along path edges, set back the same distance, facing ... | done | 24 benches, 0 in beds, 0 off path | Pairs across the avenues |
| M2-07 | Lamp posts stand along path edges at a regular rhythm, matched on both sides where the lay... | done | 48 lamps, 0 off path | Matched pairs |
| M2-08 | Trees and fruit. Apples and other fruit sit inside or on the surface of the leaf mass, nev... | done | fruitTrees 0, treesNearStructures 0 | Fruit trees removed |
| M2-09 | Other props found in the screenshots: the loose black wheel on the plaza floor (screenshot... | partial | tippedOrFloating 0 | Loose wheel gone with the old fountain. Light tower is upright. Not re-seen from screenshot cameras |
| M2-10 | Plot gates and plaza edges: the plot gate areas and the paths into each plot should look a... | partial |  | Paddock and pit surfaces rebuilt; gate court unchanged |
| M2-11 | Done when: the M1 inside checks report zero problems on the island; before and after frame... | partial | checks zero; after-park-*.jpg | Exact same-camera after frames not captured: the screenshots carry no camera data |
| M2-11a | Keep the half-circle hub, six plots, river and boost lanes. Verify paired props using mirr... | partial | mirrorMismatches 0 | Same note |
| M3-01 | Remove the sunken car from the basin. Build a centerpiece: a polished, slightly larger-tha... | done | after-11-fountain.jpg | Gold statue on a pedestal |
| M3-02 | Nothing intersects: the statue, pedestal, water, jets and basin rim are clean, with no fli... | done | scan 0 |  |
| M3-03 | If the statue cannot look good with the available tools, delete it and make a classic tier... | done |  | Statue kept |
| M3-01a | The pedestal supplies the structure: clearly visible above the water, centered in the basi... | partial | two approaches viewed | Front and quarter views checked; all four not captured |
| M4-01 | One line system on every level. Choose one clear marking language and apply it to the whol... | done | scan L1 to L12 | White edge lines, inside curbs |
| M4-02 | Clean joints. Wherever two road or concrete pieces meet (plot road to paddock, paddock to ... | done |  | Same asphalt and mitres |
| M4-03 | Pit lane. The side road becomes a proper pit lane: it leaves and rejoins the track at a sh... | done | after-07-pit-row.jpg | Shallow joins; pit lines on top |
| M4-04 | The loop. Rebuild the loop so it is part of the track: widen the straight where it stands ... | done | after-06-loop-wheelheight.jpg | Loop built on the cars own path |
| M4-05 | Props make sense. Remove the lemonade stand, chair, shed, wheelbarrow, barrels and other u... | done |  | Clutter features removed; each level still adds something |
| M4-06 | PIT ROW building. Make it a real pit building: varied rooflines or a canopy, numbered gara... | done | after-07-pit-row.jpg | Sign text only shows in Play, not in Studio Edit view |
| M4-07 | Paddock and parking keep working with the parking spots purchase preview (2 to 15 spots) a... | partial | SpeedwayChecks ran | Parking unchanged; purchase preview not exercised |
| M4-08 | Done when: levels 1 to 12 on every plot are checked with `SpeedwayChecks` plus M1, frames ... | partial | scan levels 1 to 12 | Scan covers every plot and level; frames only for some |
| M4-08a | Capture a 6-plot by 12-level automated placement matrix, then visually inspect levels 1, 5... | partial |  | Matrix by scan; car through the loop not filmed |
| M5-01 | Design a small family of sign styles that share one visual language (thick outlines, chunk... | done | after-signs-family-play.jpg | SignKit |
| M5-02 | Fewer signs. Delete repetitive or meaningless signs; keep the ones that name a landmark or... | done |  | Shop boards off in Dusty and Summit |
| M5-03 | Readable from where players actually look: the walking camera on the island, the run chase... | partial |  | Readable in Play close up; not tested at run speed |
| M5-04 | All names are original and kid-friendly. No sponsor names or ads, no real brands. | done |  |  |
| M5-05 | Done when: every sign in the island, the Raceway, Dusty Highway and Summit Pass belongs to... | partial |  | Island signposts and Downtown not restyled |
| M5-01a | Shared construction: one dark outline color, the established HUD display lettering, real b... | done |  |  |
| M5-01b | Race: horizontal chamfered enamel plate; navy body, warm yellow header, ivory letters, a s... | done |  |  |
| M5-01c | Park/plaza: softly rounded enamel on paired dark posts or a painted wood frame. Teal body,... | partial |  | Park style exists; island signposts keep their earlier art |
| M5-01d | Dusty: diner uses a rounded turquoise/pink outline and cream letters; motel uses a tall ar... | done |  | Diner, motel, trading, fuel, mine |
| M5-01e | Summit: broad dark timber boards, warm cream lettering, moss-green enamel trail markers, a... | done |  | Lodge and trail |
| M5-02a | Delete labels that merely describe an obvious prop, duplicate the same name within one cam... | partial |  | Three names at run speed not tested |
| M6-01 | Fewer tumbleweeds. Cut the rolling dust balls to an occasional accent (for example a few p... | done |  | 2 tumbleweeds |
| M6-02 | Districts with real structures. Turn the drive into a sequence of distinct, readable distr... | done | dusty-chase-silent.mp4 | 41 structures |
| M6-03 | Fill the layers. Near layer (within about 30 to 80 studs of the shoulder): buildings, fenc... | partial | video | Power lines and a train not added |
| M6-04 | Canyon Bridge. Make the gorge read as deep and dramatic from the run camera: widen it (bey... | partial | after-dusty-canyon-bridge-s2150.jpg | Wider gorge and cliffs; floor cannot be seen from the run camera |
| M6-05 | Life: subtle motion that does not distract: windmill blades, a turning radio dish, birds c... | partial |  | Existing life kept; one static turbine and dish |
| M6-06 | Signs follow M5 (Dusty style), fewer of them. | done |  |  |
| M6-07 | Assets: reuse the group-owned Dusty Highway kit and the B2 kit first; add new Blender mesh... | done |  | No upload needed |
| M6-08 | Done when: a real-time chase video (with the World music) of at least one full loop shows ... | partial | dusty-chase-silent.mp4 | Video has no audio: Studio Edit plays no sound |
| M6-02a | Retain the plan's five district IDs and order. Enrich their content rather than silently r... | done |  | Five district ids kept |
| M6-02b | Cactus Flats: landmark is a broad red barn with a windmill silhouette. Palette: sand, warm... | done |  |  |
| M6-02c | Diner Strip: landmark is an original rounded diner with a cup sign and a shaded patio. Pal... | done | after-dusty-diner-strip-s980.jpg |  |
| M6-02d | Red Rock Arches: landmark is the existing natural arch, framed by a small old mining settl... | done |  |  |
| M6-02e | Canyon Bridge: the gorge remains the landmark. Palette: burnt orange rim, muted violet low... | done | after-dusty-canyon-bridge-s2150.jpg |  |
| M6-02f | Mirage Dunes: landmark is a large original roadside cactus sculpture with an observatory b... | done | after-dusty-mirage-s2800.jpg |  |
| M6-03a | Pace from actual speed v, not a guessed meters/studs conversion: a supporting visual beat ... | partial |  | Distance-stamped shot list not written |
| M6-04a | Canyon evidence: decision 0029 found the broad deck hides most of the previous gorge. Star... | partial |  | Only the 2x width compared |
| M6-08a | Check seeds 2207, 11, 77, 101 and 314, plus the wrap transition. Preserve the checked-in p... | partial | seeds 2207, 11, 77, 101, 314 | Live parts peak 463 against the 400 Edit ceiling; triangles 24,535 against 35,000; 92 unique meshes against 110 |
| M7-01 | Spacing rule: allow a longer gap next to the glacier tunnel (decision 0029 option 1), so t... | done |  | longGapBeside |
| M7-02 | Bell tower: fit it back into Pine Village, for example set further out from the road or in... | done | evidence summit frame | Pin at 108 studs |
| M7-03 | Signs follow M5 (Summit style), fewer of them. | done |  |  |
| M7-04 | General polish: check Summit Pass against the same quality bar as Dusty Highway (layers, l... | partial | summit-chase-silent.mp4 | Viewed; no further changes |
| M7-05 | Done when: the self-checks pass on several seeds, a chase video shows the tunnel, Pine Vil... | partial | summit-chase-silent.mp4 | No audio; seed 314 as above |
| M7-01a | Encode the tunnel-gap permission as one named interval exception, not a global relaxation ... | partial | checks | Seed 314 fails landmark-majors; longest gap 527 |
| M7-02a | First try the bell tower farther out in Pine Village, with a visible base and a clear gap ... | partial | one distance | Three approach distances not compared |
| M8-01 | Investigate (read only): how `RunRoad` and `RunController` build and stream the road, what... | done | for-brian-r section 1 |  |
| M8-02 | Build a Lane 3 scenery adapter (Lane 3 code, for example under `src/client/UI` or a new La... | done | RunScenery.luau | One switch |
| M8-03 | Hide or replace his test scenery only through options his API already offers (for example ... | blocked | for-brian-r R1 | His scenery has no off option |
| M8-04 | Test in the local beta-2 file (B-06): each portal starts a run in the right World, the sce... | partial | beta2-dusty-real-run.jpg | Real runs in Dusty and Summit; the World loads about 20 s in Studio; no video; AI cannot steer, so runs lasted about 40 m |
| M8-05 | Message Brian R (M18) with a proposed scenery contract (road centerline and width source, ... | done | lane3-big-round-for-brian-r.md |  |
| M8-06 | If something important cannot be done without his change, say exactly what in the final me... | done |  |  |
| M8-02a | Before wiring, record actual public methods, coordinate origin, forward direction, width u... | partial |  | Start, end and home, two runs, world switch tested. Death by revive not tested |
| M9-01 | One icon family, original art, consistent light direction, outline weight and saturation. ... | done | IconsFamily.luau |  |
| M9-02 | Build method, your choice: code-drawn (the existing `IconGeometry` and `IconArt` approach)... | done |  | Code-drawn, no upload |
| M9-03 | Replace the old icons everywhere they appear (Home menu, HUD, Garage, Results, Settings, R... | done |  | Old names forward to the new family |
| M9-04 | Kit upgrades that the Shop and tutorial need, built once and reused: ribbon and stamp comp... | done | ShopKit.luau |  |
| M9-05 | Done when: an icon sheet frame shows every icon at 48 px and 96 px on light and dark backg... | partial | iconsSheet mounted | Sheet not captured at 48 and 96 px |
| M9-04a | Reuse Prototype/Arcade, PreviewTokens, Overlay, Motion and Sounds where appropriate. Make ... | done |  |  |
| M10-01 | Frame. A full-screen overlay over the dimmed and blurred game (a slight blur and darkening... | done | shop-desktop-first-open.jpg |  |
| M10-02 | Tabs and sections (proposal; adjust the names): Featured, Passes, Cash (only if Cash packs... | done |  |  |
| M10-03 | Featured, the first thing a player sees. It must be the most exciting part of the screen. | partial |  | Bundle lives in the Passes row, no separate banner |
| M10-04 | Passes section. An icon, the title "Passes", a grey subtitle ("Forever yours · use them in... | done |  |  |
| M10-05 | Starter Pack (proposal for Brian L): a one-time offer for new players, shown as the first ... | done |  |  |
| M10-06 | Style section: paint colors and packs, decals and wheel styles as colorful cards with a sm... | done | shop-desktop-style-free.jpg |  |
| M10-07 | Cash section (behind a flag): pack cards that grow visually (small stack, sack, chest, vau... | partial |  | Built; flag on not captured |
| M10-08 | Interaction states for every card and button: idle, hover (lift about 4 to 6 %, an outline... | partial |  | Owned, unavailable, coming soon seen. Gamepad order untuned |
| M10-09 | Buy flow in this round: pressing a price button shows the pending state, then a friendly "... | done | marketplaceCalls 0, grants 0 |  |
| M10-10 | Data. All offers, art references, benefit text and PREVIEW prices live in one display cata... | done | ShopPreviewCatalog.luau |  |
| M10-11 | Honesty rules (the audience is mostly children; these keep the shop enticing and fair): | done | claims 0 in normal view |  |
| M10-12 | Entry points (enticing, not nagging): the Shop button in the Home menu (with a small "!" b... | partial |  | Home menu and plus work. Raceway parking panel and Results card not wired |
| M10-13 | Sound: an open whoosh, a hover tick, a press pop, a sparkle for the best deal, routed thro... | partial |  | Reuses Tap and Toast; sparkle silent; asset dependency logged |
| M10-14 | Layout at all three sizes: on a phone in landscape the hero stays big and the side stack m... | partial | shop-phone-landscape.jpg | Desktop and phone seen; tablet not |
| M10-15 | Figma: if available (B-05), design the Featured view, a Passes row and the phone layout th... | done |  | Figma skipped |
| M10-16 | Done when: the shop opens from every entry point, every state is exercised in Studio Play ... | partial |  | See M19 |
| M10-01a | OBSERVED reference: the 1280-wide frames use a content region about 87% of the view width,... | done |  |  |
| M10-01b | Desktop starting composition at 1920x1080: centered content 88-92% of safe width, header a... | done |  |  |
| M10-14a | Tablet starting layout at 1024x768: 92-95% safe width, hero/side split 62/38 while benefit... | partial |  |  |
| M10-14b | Start tall pass cards around 0.8:1 width:height on desktop/tablet; use wide horizontal car... | done |  |  |
| M10-03a | Featured order: Starter Pack hero; VIP upper side card; Double Lap Pay lower side card. Ne... | done |  |  |
| M10-04a | Exact proposed card copy: Double Lap Pay title; tag '2x LAP PAY'; body 'Your cars earn twi... | done |  |  |
| M10-05a | Starter Pack copy: 'STARTER PACK', 'A fresh look for your first laps.', contents 'Starter ... | done |  |  |
| M10-06a | Style cards: 'PAINT PACK' / 'Give your car a fresh coat.' / 'Preview colors'; 'DECAL PACK'... | done |  |  |
| M10-07a | Hidden Cash fixtures: 'POCKET CASH', 'CASH BAG', 'CASH CHEST', 'CASH VAULT'; each shows th... | partial |  |  |
| M10-08a | State copy: pending 'Checking...' for about 0.4 seconds in the preview, then 'Coming soon!... | done | shop-coming-soon.jpg |  |
| M10-08b | Motion starting values: open scale 0.94 to 1 over 200 ms with a gentle Back Out, close 140... | partial |  | Set in code; not reviewed on video |
| M10-13a | Proposed sound palette, not copied audio: opening is a soft 180-250 ms airy whoosh; hover ... | partial |  |  |
| M10-10a | Price research, checked 2026-11-01: there is no verified market-wide typical price or conv... | done |  |  |
| M10-10b | PREVIEW recommendations for Brian L, deliberately below some mature-game examples because ... | done |  |  |
| M10-11a | [ChatGPT note] The original unconditional BEST DEAL ribbon conflicts with the original hon... | done |  |  |
| M10-11b | Official guidance says 'avoid using pushy or urgent messages when interacting with minors'... | done |  |  |
| M10-03b | Research translation: BIG Games' own PS99 posts tie area gates, rank quests and rewards to... | done |  |  |
| M10-09a | Verified purchase categories for the handoff, not implementation: Roblox describes passes ... | done | for-brian-l |  |
| M10-09b | PolicyService official signature: 'PolicyService:GetPolicyInfoForPlayerAsync(player:Instan... | done | for-brian-l |  |
| M10-09c | Gifting: the documented standard API is 'MarketplaceService:PromptGamePassPurchase(player:... | done |  | No gift button |
| M10-10c | Robux symbol: community examples use U+E002, but a current official symbol-use rule and fo... | done |  | Word Robux |
| M10-16a | Acceptance: at each target size capture Featured at scroll zero, Passes, Style, Free and t... | partial | 20 open-close cycles, 4,212 instances before and after | Rapid press and close-during-pending not run |
| M10-03c | Additional primary-source comparisons: Grow a Garden describes a simple buy/plant/grow/col... | done |  |  |
| M11-01 | Steps exactly as in the outline (0 Let's get a car!, 1 Go to Downtown!, 2 Steer!, 3 Hop to... | todo |  |  |
| M11-02 | Top banner: a pill at top center in the reference style (`hud-tutorial-reference.png` plus... | todo |  |  |
| M11-03 | Ground guidance: a white chevron trail on the ground (the existing `TutorialRoute`) that f... | todo |  |  |
| M11-04 | UI guidance: a pointing hand that taps on the exact button to press, with a light dim mask... | todo |  |  |
| M11-05 | Timed hint: if the player has not done the step for about 8 seconds (tunable), the arrow g... | todo |  |  |
| M11-06 | Never block play. The player can always walk, explore, open menus and come back. If they w... | todo |  |  |
| M11-07 | Skip: a small "Skip" button beside the banner (44 px touch target), with a confirm card ("... | todo |  |  |
| M11-08 | Run steps (2 to 5) listen to the run through a Lane 3 adapter. On `main`, the adapter uses... | todo |  |  |
| M11-09 | Island steps (0, 1, 6 to 11) use Lane 3 events: portal field entered, the Paddock and park... | todo |  |  |
| M11-10 | Progress: session-only in this round. Propose `TutorialStep` and `TutorialDone` save field... | todo |  |  |
| M11-11 | Accessibility and feel: icons carry the meaning (a kid who cannot read can follow), every ... | todo |  |  |
| M11-12 | Done when: a full playthrough in the local beta-2 file goes from spawn to "You're ready!" ... | todo |  |  |
| M11-01a | Official design basis: Roblox recommends 'Teach the essentials' and 'Get to the fun quickl... | todo |  |  |
| M11-01b | Step 0: 'Let's get a car!' / 'Follow the arrows.' Show a car and route icon; advance after... | todo |  |  |
| M11-01c | Step 2: 'Steer!' / 'Move left, then right.' Show the current device's actual steering cont... | todo |  |  |
| M11-01d | Step 4: 'Hold on!' / 'Stay until the Keys ring fills.' After a confirmed new-car claim: 'I... | todo |  |  |
| M11-01e | Step 6: 'Go home!' / 'Tap Home on the results.' Guide the actual working Home/return route... | todo |  |  |
| M11-01f | Step 8: 'Cars earn cash!' / 'Watch your car finish a lap.' Show the lap cue and Cash desti... | todo |  |  |
| M11-01g | Step 10: 'Check the Shop!' / 'Open the Shop. Take a look!' Opening it completes the step; ... | todo |  |  |
| M11-02a | Layout and pacing: use the reference's dark pill, strong headline, simple icon and one sho... | todo |  |  |
| M11-10a | [ChatGPT note] The original 'started, completed, skipped' wording describes useful analyti... | todo |  |  |
| M11-10b | Roblox states 'Events can only be sent from the server and in published games.' ([Funnel e... | todo |  |  |
| M11-12a | Acceptance: full successful route; fail the first hop then recover; end a run before colle... | todo |  |  |
| M12-01 | In-world plaque on each portal: the World name, its icon, a lock or "OPEN" state, and the ... | partial |  | Existing gate crest and plaques kept, not restyled |
| M12-02 | Portal card (restyle and finish `PortalCardMock`): opens when the player walks up to a por... | done | portal-card-locked-fixture.jpg |  |
| M12-03 | Data: unlock rules, prices and owned cars come from Brian L. Use a PREVIEW state fixture (... | done |  |  |
| M12-04 | Done when: the locked and unlocked states and Peek and Start In look right at all sizes, w... | partial |  | Locked seen at desktop; walking into a portal still starts the run |
| M12-02a | Card hierarchy: World name and emblem, wide scene preview, then two independent requiremen... | done |  |  |
| M12-03a | [ChatGPT note] The introductory example names Dusty cars as an unlock requirement; the rev... | done |  |  |
| M12-04a | Check zero owned cars, only Loaner, many owned cars, both requirements unmet, one met, all... | partial |  | Fixtures not all driven |
| M13-01 | Panel opened from the Missions button in the Home menu: two tabs, Missions and Goals. Miss... | done | missions.jpg |  |
| M13-02 | HUD tracker: a compact tracker for the top mission on the home island, never during runs, ... | partial |  | Mounted; not captured |
| M13-03 | Data: template list as a Lane 3 display fixture; progress, rewards and refresh are Brian L... | done |  |  |
| M13-04 | Done when: every card state (in progress, completed, claimed, refreshed) is exercised with... | partial |  | Card states not all driven in Play |
| M13-01a | Show three active mission cards with one clear objective each. Starting examples: 'Hop 15 ... | done |  |  |
| M13-01b | Goals use the six approved milestone names, a completion tick and one highlighted next goa... | partial |  | Goals tab not captured |
| M13-03a | [ChatGPT note] 'Replaced instantly when completed' and a CLAIM button need an explicit vis... | done |  |  |
| M13-04a | Verify empty/loading/error, all three in progress, one ready, pending then success/error, ... | partial |  |  |
| M14-01 | Finish `WelcomeBackMock` into a polished card: the player's Raceway (or a miniature) with ... | done | welcome-back.jpg |  |
| M14-02 | Shown once on join when there is something to show, after the loading screen, never during... | partial |  | Queue built; join flow not wired |
| M14-03 | Data: offline amount and time are Brian L's (PREVIEW fixture now). | done |  |  |
| M14-01a | Use one focused card: 'Welcome back!', miniature Lineup, large '+$[amount]', 'Earned while... | done |  |  |
| M14-01b | [ChatGPT note] Cash is already credited when this card appears. Keep the requested COLLECT... | done |  |  |
| M14-03a | Data unavailable is not $0 earned. Use a neutral waiting/error state, suppress the reward ... | partial |  |  |
| M15-01 | A branded Car Hop loading screen: the logo or title art, a lively looping scene (for examp... | partial |  | Built; never seen on a real join |
| M15-02 | Mapping: a loading screen normally runs from `ReplicatedFirst`, which is not mapped in `de... | done | beta.project.json |  |
| M15-03 | Done when: it appears on join in the local beta-2 file, hides cleanly when loading is done... | partial |  | A Studio Play did not fail; visual not reviewed |
| M15-01a | Starting design: warm sky background, Car Hop wordmark, a small three-car hop silhouette, ... | partial |  |  |
| M15-02a | Official loading guidance says both implementations 'utilize ReplicatedFirst' ([Loading sc... | done |  |  |
| M15-01b | Preload only a small deduplicated list needed for the first playable view and immediate co... | partial |  | Only two sound ids preloaded |
| M15-03a | PreloadAsync has no timeout argument in that signature. Implement a separate watchdog, sta... | partial |  |  |
| M15-03b | Test instant readiness, slow optional image, failed sound, unavailable image, empty manife... | partial |  |  |
| M16-01 | Pop-up and Shop card: an exciting but small pop-up ("Join the group, get a FREE reward!") ... | partial | group-popup.jpg | Pop-up done; Shop card not placed |
| M16-02 | Flow: check the current official Roblox documentation for the supported way to prompt a pl... | done |  |  |
| M16-03 | Timing and caps: shown once after the tutorial finishes, then at most once per day on join... | partial |  | Session cap only |
| M16-02a | Verified API: 'GroupService:PromptJoinAsync(groupId:number):Enum.GroupMembershipStatus' ([... | done |  |  |
| M16-02b | Handle each documented [GroupMembershipStatus](https://create.roblox.com/docs/reference/en... | done |  |  |
| M16-02c | Policy research: official group guidance says groups 'must follow Roblox's Community Stand... | done | for-brian-l |  |
| M16-03a | [ChatGPT note] A once-per-day cap across sessions needs persistent state or a supplied ser... | done |  |  |
| M16-01a | Reward-preview copy must remain conspicuous next to 'Join the group, get a FREE reward!' b... | done |  | Note now always visible |
| M17-01 | Course build as a Lane 3 recipe in a private test place (choose the folder, for example `s... | todo |  |  |
| M17-02 | Data for Brian R: a centerline and width data module (a list of points and widths, checkpo... | todo |  |  |
| M17-03 | Stunt gate on the island: keep its position (Adam). Add the best-time and weekly-top-time ... | todo |  |  |
| M17-04 | Screens (finish `StuntMock` and add the rest): race HUD (lap timer, checkpoint counter, gh... | todo |  |  |
| M17-05 | Customization screen: a turntable with the car, tabs Paint, Decals and Wheels, color swatc... | todo |  |  |
| M17-06 | Done when: a camera flythrough video of the whole lap (with music) shows a fun, readable c... | todo |  |  |
| M17-01a | Use a 75-second target lap as a starting visual pacing model. Convert each section duratio... | todo |  |  |
| M17-01b | Ordered sections: slalom 0-12 s (840 studs at example speed); ramp gap 12-22 s (700); tunn... | todo |  |  |
| M17-01c | Start with three readable slalom changes, a single wide first jump, two separated pothole ... | todo |  |  |
| M17-02a | Include units, origin, forward/up axes, centerline points, widths, section IDs, warning po... | todo |  |  |
| M17-04a | Race presentation: timer is stable at the top, checkpoint counter secondary, ghost gap onl... | todo |  |  |
| M17-04b | Keep medal thresholds as named PREVIEW values until measured with the real car physics. Do... | todo |  |  |
| M17-05a | Customization keeps the approved 8 free paints, 8 Cash-priced preview paints, earned medal... | todo |  |  |
| M17-06a | Acceptance separates visual course completeness, UI fixture correctness and real gameplay ... | todo |  |  |
| M18-01a | Each teammate proposal includes an exact module/adapter name, fields read, events needed, ... | done |  |  |
| M19-01 | Automated: run `./scripts/check.ps1` (Selene, StyLua and the rest; exit 0 means pass, 2 me... | todo |  |  |
| M19-02 | Studio Play: walk the whole island at normal and boosted speed, every plot at Raceway leve... | todo |  |  |
| M19-03 | Independent reviewers: spawn fresh reviewer subagents who did not build the work: one for ... | todo |  |  |
| M19-04 | Fix every blocker and material finding, then re-run the affected checks. Repeat until a re... | todo |  |  |
| M19-05 | Evidence: save after-frames, short videos (with game audio; Adam judges sound by ear) and ... | todo |  |  |
| M19-05a | Use one evidence index keyed to ledger IDs. It must distinguish code checks, fixture tests... | todo |  |  |
| M20-01 | Run `./scripts/check.ps1` and fix failures inside the task. | todo |  |  |
| M20-02 | Commit with clear messages in logical steps, push `feature/lane3-big-round`, and open a dr... | todo |  |  |
| M20-03 | Push `integration/beta-2` (B-06) and open it as a draft PR for Adam, noting it contains Br... | todo |  |  |
| M20-04 | Update the board row and add the log entry for today (build on any entries other sessions ... | todo |  |  |
| M20-05 | Save the place files you changed (keep the previous versions as dated backups in `Car-Hop-... | todo |  |  |
| M20-05a | Before close-out, verify no Brian R/Brian L source files, default.project.json, saved-data... | todo |  |  |
| M21-01a | In the final message name the three largest visual improvements, the exact private file Ad... | todo |  |  |
