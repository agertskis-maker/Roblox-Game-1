---
title: Lane 3 Round 2 ledger
tags:
  - spec
---

# Lane 3 Round 2 ledger

Brief: [[lane3-round2]]. Allowed evidence statuses from N16-01a are used in the Evidence column: verified in Studio, checked in code only, fixture demonstration, blocked, not tested.

| ID | Requirement (short) | Status | Evidence | Choice made / note |
|---|---|---|---|---|
| N1-01 | Find the root cause first and write it in the ledger. The same overlaps survived Round 1, ... | done | evidence/before-r2-01-view.jpg | Root cause: three separate hand-kept geometries. Lanes (Plot.polyline), their paint (Props.PitOut, a copy of the list) and barrier gaps (Track.inPitGap, an axis-aligned box with a +5 fudge) knew nothing of each other. Lanes ended as rectangles under the road at an angle, the paint ran past the road edge, and a cross line was painted over the mouth. Near turn banked 3 degrees, so no flat joint was possible. |
| N1-02 | One road network per plot and level. Build the track, the pit lane, the side road and the ... | done | RoadNet.luau; LineChecks matrix zero | One network, single junction polygons, paint from the network |
| N1-03 | Pit lane and side road: they split from and rejoin the track at a shallow angle, at the sa... | done | evidence/pair-r2-01.jpg, pair-r2-02.jpg | 25.4 degrees at the merge's steepest (brief starts at 15 to 25); lane is the aisle's own 10 wide |
| N1-04 | Paddock, parking and walkways: the concrete paddock and the parking area are flush with an... | done | evidence/pair-r2-04.jpg; LineChecks walk 0 | Court, Paddock, aisle, lanes and walk all top at 0.2; walk ends on the road's edge at a gate |
| N1-05 | Double lines: where a wall and an edge line run side by side (`r2-04`), there is exactly o... | done | evidence/pair-r2-04.jpg | The doubled look was the wall's inner edge against the line; line stands 0.6 in, even all round |
| N1-06 | Line checker: add checks (extend `SpeedwayChecks` or the M1 overlap scanner) that fail whe... | done | LineChecks.run | crossing, overlap, freeEnd, walk, floats, wallStep, tyreOnWall |
| N1-07 | Done when: the checks are zero everywhere, and before and after pairs from Adam's views (`... | done | evidence/pair-r2-01, 02, 03, 04; topdown-junctions-level1, 6, 12; topdown-paddock-level12 | Matrix 6 plots x 12 levels all 0 in Studio Edit; views in Studio Play. r2-01 to 03 re-shot closer to Adam's views after review |
| N1-01a | Network construction and diagnosis | done | r2-01, r2-02, r2-04 reproduced in the old place before any change | Confirmed in Studio |
| N1-02a | Use plot-local 2D coordinates for ground roads. Each edge records its centerline, width, e... | done | RoadNet.triangulate, validate | Ear clip, fattest ear first; rejects self crossing and repeats |
| N1-02b | Generate boundary paint after surfaces, from the final external boundary and tagged mouth ... | done | Studio Edit matrix |  |
| N1-03a | Proposed starting geometry: 15 to 25 degrees for a pit fork; widen turns enough for the cu... | done | RoadNet | End chords share corners exactly; nose rounded |
| N1-06a | Classify comparisons. A paint line necessarily overlaps its own supporting asphalt in plan... | done | LineChecks | Samples 9 points a line; sees the widened road. Loop and raised paint are not line-checked: those are covered by the overlap scan and by eye |
| N1-06b | Keep a single surface-height convention and place paint relative to the local road normal.... | done | Scan on all plots and levels | One height, paint at a fixed 0.12 |
| N1-07a | Done when: reproduce known-bad crossing, duplicate-paint and grass-gap fixtures and prove ... | partial | selfTest catches crossing, double line, free end, widened-road line, walk gap | The top-down views are Plot 3. Rebuild identity not measured |
| N2-01 | Research how real stunt loops on tracks are built (for example toy-car loops, stunt-show l... | done | see Research below | Findings below |
| N2-02 | Geometry: where the loop stands, widen the straight to at least two full track widths with... | partial | Path.Loop, Track.loop, Track.loopApron | Straight widened to 32 (two track widths) with 48-stud tapers (3 x 16). Ribbon 16 at the road, 14 in the loop: 16 throughout needs a 54 taper and does not fit the 103.6 straight with the loop's 38 of forward run |
| N2-03 | Cars through the loop: the decorative lap cars follow the loop centerline with the correct... | done | evidence/raceway-loop-side-silent.mp4 | Upside down at the top, frame from the curve |
| N2-04 | Fits the levels: the loop appears at the levels where Round 1 put it (keep the level ladde... | done | Look features | Hump now level 11 only: the loop takes that straight |
| N2-05 | Done when: a Studio Play recording (with game audio) shows at least three cars going throu... | partial | raceway-loop-side-silent.mp4, raceway-loop-walkway-silent.mp4; scan 0 on Plot 3 level 12 | No audio. Scan on the loop 0 flicker or near |
| N2-01a | Research, actual scale and a buildable method | done | Path.luau | Called a teardrop, not a clothoid. Game proportions, not safety figures |
| N2-02a | Verified local baseline: Track.luau uses Path.HalfWidth = 8, so the ordinary ribbon is 16 ... | done | Track, Path | Old loop was a circular helix with a constant sideways slope at both ends: confirmed source of the sideways snap |
| N2-02b | Proposed starting envelope for the stated 9 to 12 stud car length: loop road width 16 stud... | done | apex radius 14.1, low radius 30.2, height 38.9 | Car measured 5.7 x 4.7 x 12.5. Width 14 up in the loop, gap 2 |
| N2-02c | Construct a smooth closed-turn vertical centerline in a local forward/up plane. One defens... | done | Path LOOP table | Curvature schedule, mirrored, scaled to exactly 180 degrees a half |
| N2-02d | Add lateral offset D*f(t), with t in [0,1] and f(t) = 6*t^5 - 15*t^4 + 10*t^3. Its first a... | done | Path quintic | From 12 to 88 percent of the way round, so ribbons are already a lane apart where they pass |
| N2-03a | At every sample derive tangent T from the curve derivative. Derive a reference inward norm... | done | Path.sample | Tangent and projected inward normal |
| N2-03b | Car wheels must sit on the same sampled surface used to create the ribbon. Derive the pivo... | partial | Path.carLift | Lift by wheelbase^2/8R. Eight-point swept check not done; video shows no clipping |
| N2-03c | Keep Lap Pay and authoritative lap timing unchanged. If adding visual speed variation, cho... | done | Path.distanceAt | 0.85 at the top, 1.1 low, whole lap unchanged; min gap at 15 cars 31 studs |
| N2-05a | Adaptive tessellation starts with a 0.1-stud chord-error target and at most 3-degree tange... | partial | joins 0.0000, 0.39 degrees per 0.1 stud, orthogonal 0.00000 | All plot bearings shown by the shared generator; Reduced Motion and three-lap counts not separately measured |
| N3-01 | Barriers: the white wall blocks along the track edge form one even, continuous wall (no un... | done | evidence/pair-r2-03.jpg; wall step 0.109 | One sloped wall, tyres stop short with an end post |
| N3-02 | Props: keep race props in their zones (Round 1 M4-05). A concession cart is fine near the ... | done | evidence/after-r2-03-view.jpg |  |
| N3-03 | Walk every plot at levels 1, 6, 9 and 12 and fix anything else that looks unfinished: gaps... | partial | evidence/island-flicker-glide-silent.mp4 | Plot 3 by camera only; other plots share the generator |
| N3-03a | Physical polish checks | partial | wall step 0.109, tyreOnWall 0 | On the banked slope, not level ground. Avatar collision not walked |
| N4-01 | Fastest Stunt Circuit board (`r2-05`): rotate it to face the center of the island (toward ... | done | evidence/pair-r2-05.jpg | Both fences removed (there were exactly two). Boards turned about 18 degrees toward the avenue, mirrored |
| N4-02 | The low cyan info board near the portal pillar (`r2-05`, left): if it is lying flat or til... | done | PortalGates | Low tilted plaque removed: the locked portal's dialogue card says it |
| N4-03 | Trees (`r2-06`): no tree or bush may intersect another tree, bush, sign, gate, lamp or bui... | done | 555 plants; 0 on objects (1,990 objects incl. plot props); 5 pairs under the 1-stud margin; 2 overlap by under 0.3 | All seven are far forest, none near a path |
| N4-04 | Round 1 leftovers on the island: convert the island signposts to the sign family (Round 1 ... | partial | island-flicker-glide-silent.mp4, sheet | A 40 s camera glide past Garage, Stunt gate and portals, not an avatar walk: no flicker seen in 13 sampled frames, which cannot prove there is none. Signposts keep the arrow boards |
| N4-04a | Readable signs and planted space | partial | pair-r2-05 | Board facing proved by the view, not by a plan drawing |
| N5-01 | Use ChatGPT's original icons from `chatgpt-images\` (`icon-*.png`, or cut them out of `IMG... | done | icons/png512, png256, contact sheets | 30 cut from the sheet, 7 composed |
| N5-02 | Upload (R-05), then wire the icons into the UI kit: one icon module where each icon name m... | partial | GameIcons.luau, GameIconIds.luau | Module done; ids empty until Adam's import |
| N5-03 | Replace every icon in the game: Home menu, HUD, Shop (including every Starter Pack item an... | partial | Icons2.draw asks GameIcons first | Every screen that uses a painter name gets it. Screens drawing their own art were not audited one by one |
| N5-04 | Before the upload lands: the screens must still look finished. Use the best available exis... | done | Local preview modules; code-drawn fallback |  |
| N5-05 | The "2x": Double Lap Pay's 2x is drawn into the icon art (a bold, rounded "2x" on a gold c... | done | doubleLapPay.png |  |
| N5-01a | Asset preparation and verified upload paths | done | manifest.json |  |
| N5-02a | Official Open Cloud limits: one asset per create request, up to 20 MB, image dimensions st... | blocked | no ROBLOX_OPEN_CLOUD_KEY | Package made instead |
| N5-02b | Read the key without printing it. Confirm its resource permissions authorize the intended ... | blocked | no key |  |
| N5-02c | Upload limits differ from usable texture resolution: Roblox documents a maximum texture re... | done | 512 PNGs, 189 KB typical |  |
| N5-02d | Manual package procedure: open Studio's Asset Manager from Window or Home, then its import... | done | icons/UPLOAD-STEPS.md | Studio labels come from the brief, not the installed Studio |
| N5-02e | Assets must pass moderation before use. Show the fallback while approval or loading is pen... | partial | fallback path works | Fallback to code-drawn art not captured |
| N6-01 | Color: much more saturated and vibrant, like the reference: hot pink, electric purple, cya... | done | ui/*-shop.jpg |  |
| N6-02 | Moving gradients everywhere it matters: the Shop button already cycles through a rainbow; ... | done | 5 gradients moved in Play | Studio Play |
| N6-03 | BEST DEAL back on (section 2), with "SAVE X%" computed from the PREVIEW catalog and the st... | done | 647 vs 549, SAVE 15% |  |
| N6-04 | Layout check against the reference: the first screen (Featured) must be as exciting as the... | partial | ui/Desktop-shop.jpg, ui/PhoneLandscape-shop.jpg | Pass cards are one tab away on desktop |
| N6-05 | Fix the Round 1 gaps: wire the Raceway parking panel entry point ("Get more spots" opens E... | partial | openExpandedPaddock, openDoubleLapPay; beta goal pill | Parking panel entry is Lane 3's ShopPanel, not yet wired to it |
| N6-06 | Keep: no real purchases, no paid randomness, the honesty rules, PREVIEW prices, "Coming so... | partial | Studio Play | Gamepad not exercised |
| N6-02a | Motion system, hierarchy and phone budget | done | ShopMotion.luau |  |
| N6-02b | Proposed motion recipes, measured in seconds, not frames: | partial | ShopMotion Recipes | Timings read from code, not measured |
| N6-02c | Initial phone limits: at most 6 continuously animated gradient instances and 1 breathing b... | partial | One driver, budgets in code | Phone cost not measured: no device |
| N6-03a | Compute savings only for identical included quantities and the same fixture currency: comp... | done | ShopPreviewCatalog.bundleMath |  |
| N6-06a | Exercise every entry point, all tabs, scrolling, owned, pending, unavailable, preview buy,... | partial | Tabs opened in the tour only as Featured | Not every state driven |
| N7-01 | Inventory first: watch both videos and write, in the ledger, a list of every HUD element a... | done | Brief inventory plus HomeHud | The inventory is in the brief |
| N7-02 | One look across all panels: restyle Settings, Missions, Garage, the portal card and the ot... | done | PanelKit; ui frames |  |
| N7-03 | Phone landscape first: check every element at the phone landscape frame for thumb reach, s... | partial | ui/*-home.jpg | Laid out against assumed zones, not a real phone |
| N7-04 | Motion and sound: pills slide in and out, buttons pop on press, numbers count up, badges p... | partial | HomeHud | Sound by level not listened to |
| N7-05 | Done when: frames of the home HUD at the three sizes, plus one Play recording with audio, ... | partial | ui/, ui-tour-silent.mp4 | No audio. Real Cash does not exist in the beta: PREVIEW |
| N7-01a | Reference inventory already completed | done | as N7-01 |  |
| N7-03a | Car Hop layout derived from the references | partial | HomeLayout.luau |  |
| N7-03b | Present Cash as a server-backed balance; format compactly while allowing full value in det... | done | HomeCash | Rate hidden without a real number |
| N7-04a | Proposed feedback: press 0.06/0.10 s, toast enter 0.18 s and exit 0.14 s, 2.5 s readable d... | partial | HomePills |  |
| N7-05a | Required checks: longest car/world names; zero, large and unavailable balances; 0/24 and c... | partial | ui frames | Not every string and balance case driven |
| N8-01 | Icons that make sense: every step's icon clearly shows its action. "Go to Downtown!" uses ... | done | TutorialSteps |  |
| N8-02 | Banner layout: the green instruction bar sits exactly centered under the headline inside t... | done | Studio Play in the beta |  |
| N8-03 | Character guidance (optional, your call): use the dialogue card (N11) with a friendly mech... | partial | DialogueCard exists | Not shown inside the tutorial |
| N8-04 | Run it for real in the beta (N13): a full playthrough from join to "You're ready!" in the ... | partial | Beta Play: tutorial starts, steps 0 to 2 by real run; Home returns and guides back | Later steps not played: the test run crashes at about 40 m before a hop. Needs Brian R's events and a playthrough by hand |
| N8-05 | After the tutorial: on later joins, a short chevron trail and goal pill point to the most ... | partial | ReturnGuide built | Not started in HomeShell: no data for what is affordable or ready |
| N8-01a | Exact tutorial copy and icon mapping | done | TutorialStrings; Tutorial 2 scenario |  |
| N8-02a | The green bar is centered within the banner body below the title, with identical left/righ... | done | 8 s hint in scenario 3 |  |
| N8-04a | Steps 2 through 5 complete only through existing run adapter evidence, 7 through 9 through... | partial | Real mode in the beta |  |
| N9-02 | The scene is alive: a looping animated scene of the player's own cars (or the placeholder ... | partial | Studio Play | Stills only; the loop was not filmed on its own |
| N9-03 | CLAIM flies coins into the Cash counter (visual only; the amount comes from the server lat... | done | WelcomeBackMock; HomeShell cashTarget | Studio: card shown in the beta queue. Coin flight not filmed |
| N9-02a | Proposed scene storyboard and claim behavior | partial | Bounce 3.5 to 5 percent, not 2: 2 was hard to see |  |
| N9-03a | Current WelcomeBackMock treats the supplied reward as already credited and the button as a... | partial | Code; coin flight not filmed |  |
| N9-04a | States: checking uses "Checking your Raceway..." and disabled claim; unavailable uses "Ear... | partial | Code | States not all driven |
| N10-01a | Collection structure and states | done | Studio Play |  |
| N10-02a | Preserve current sorting Rarest, Lap Pay and Newest, including stable tie handling and no ... | done | as N10-02 | Quirk and race stats stay off: they fail the six-facts rule |
| N10-02b | Completion rewards are PREVIEW proposals, not new claim remotes. States are Incomplete, Co... | partial | claimWorld, claimAll | Claim states not driven in Studio |
| N10-02c | Check all 3 worlds, empty/partial/full collection, long names, every sort, owned/unowned s... | partial | Collection scenarios |  |
| N11-01 | Dialogue card (reference B and `IMG-10-npc-dialogue.png`): a title bar with an icon and an... | done | ui/*-dialogue.jpg | Locked portal only in the playground; not triggered at portals in the beta |
| N11-02 | Update Log ("What's new"): a small panel on join (once per new version) listing recent cha... | done | Beta returning join |  |
| N11-01a | Dialogue layout and behavior | partial | Typing seen; progress from one fixture |  |
| N11-02a | Update Log: one compact header, up to 4 verified shipped changes with original icons, opti... | done | HomeShell.Updates | Session only |
| N12-01 | Stop work on the course (`src/lookdev/Stunt`); leave it intact and hand it over in Brian R... | done | src/lookdev/Stunt untouched |  |
| N12-02 | Results card (redesign): follow `IMG-06-stunt-results.png`: a "FINISH!" ribbon, a huge med... | done | ui/*-stuntResults.jpg |  |
| N12-03 | Customization (paint, decals, wheels): follow `IMG-05-customize-garage.png`, inspired by t... | partial | ui/*-stuntCustomize.jpg | Paint tab shown; Decals and Wheels tabs not filmed |
| N12-04 | Pre-race card and leaderboard: restyle into the new family. | done | ui/*-stuntPreRace, stuntBoard |  |
| N12-03a | Cosmetic research and proposal boundaries | done | CosmeticPreviewCatalog |  |
| N12-03b | The following is a complete PREVIEW catalog proposal for Brian L. It expands the earlier s... | done | 33, 15 and 10 |  |
| N12-03c | Cheap paint rendering and interaction | partial | Colour cycle only on animated paints | Recorded in CosmeticCar |
| N12-03d | Separate Previewed from Equipped. Clicking a card previews immediately; an owned item expo... | partial | Code |  |
| N12-03e | Brian L's calibration task: compare price / verified net Cash per minute at early, middle ... | done | lane3-round2-for-brian-l.md |  |
| N12-02a | Results: fit medal and key time into the top half, then ghost difference and three target ... | partial | Fixtures |  |
| N12-04a | Pre-race presents chosen car, supplied stats, selected course and existing start action, w... | partial | Fixtures | No Brian R scene exists |
| N13-02 | Real data where it exists (beta Raceway level and parking spots from the beta save, plot o... | partial | Raceway level and spots are real from the beta save | Cash, cars and missions are labelled PREVIEW |
| N13-03 | Test the whole join flow in the local beta file as a new player and as a returning player:... | partial | New and returning joins with no errors in Output | The full new-player video was not recorded: Application Control blocks audio, and the run ends at 40 m |
| N13-01a | Exact join and modal queue contract | done | Beta Play: new and returning | joinMode is an explicit switch |
| N13-01b | Use one home modal coordinator, distinct from the existing lightweight notification Priori... | done | ModalQueue.selfTest 0 failures; beta log order | User panels go through it; dialogue cards are not yet shown at portals in the beta |
| N13-01c | Priority: transition/safety UI first, existing run results next, explicit user interaction... | todo | | |
| N13-01d | Loading is not a fabricated progress percentage. Show actual milestones or an indeterminat... | todo | | |
| N13-03a | Test join matrix: new player, returning with positive offline reward, returning with verif... | partial | New, returning, duplicate roots 1, queue rules on a fake clock | Delayed data, failed assets, respawn and notification burst not run |
| N14-01a | Prevent weaker checks from hiding unfinished work | partial | All five Summit seeds fail landmark-majors; three also fail spacing, one off-road | Round 1 said four passed. Measured this round on unchanged code, they do not |
| N15-01 | Brian R: the Stunt Circuit is now his (Adam's decision, 2026-11-01). Hand over the Round 1... | done | lane3-round2-for-brian-r.md |  |
| N15-02 | Brian L: the cosmetic tiers and PREVIEW prices (paint, decals, wheels), the Index completi... | done | lane3-round2-for-brian-l.md |  |
| N15-01a | Dependency handoff contents | done | lane3-round2-for-brian-r.md |  |
| N16-01a | Evidence and acceptance matrix | partial | evidence/EVIDENCE-INDEX.md |  |
| N16-03a | Two reviewer agents may run concurrently, within the two-worker cap. Give each the origina... | done | as N16-03 |  |
| N16-04a | A finished-looking static frame is insufficient for moving cars, animation cleanup, popup ... | partial | Not all counts run |  |

## Research (N2-01)

Sources are the two cited in the brief's N2-01a; no new measurements of real loops were made.
- A roller-coaster or stunt loop is tight at the top and broad at the bottom, because the rider's load depends on speed and radius together. A circular loop has one radius and a hard change of curvature where it meets the straight.
- A true clothoid changes curvature linearly with distance. Not every real loop is one; "teardrop" is the honest word for ours.
- What matters for the look is that curvature starts at zero at the road, so the car eases up with no kink.
- Entry and exit side by side is what keeps the two ribbons apart. It is a design choice here, not a rule of nature.
- Full-size stunt-car loop proportions were not verified at this game's scale. Nothing here is a safety figure.
- Our numbers: 38.9 high, 14.1 radius at the top, 30.2 low, 141.7 long, 38.2 of forward run, 16 sideways.
- The footprint does not allow 16 wide all the way and 3 x tapers both ends: see N2-02.
