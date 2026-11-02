---
title: Lane 3 Round 2 ledger
tags:
  - spec
---

# Lane 3 Round 2 ledger

Brief: [[lane3-round2]]. Allowed evidence statuses from N16-01a are used in the Evidence column: verified in Studio, checked in code only, fixture demonstration, blocked, not tested.

| ID | Requirement (short) | Status | Evidence | Choice made / note |
|---|---|---|---|---|
| N1-01 | Find the root cause first and write it in the ledger. The same overlaps survived Round 1, ... | todo | | |
| N1-02 | One road network per plot and level. Build the track, the pit lane, the side road and the ... | todo | | |
| N1-03 | Pit lane and side road: they split from and rejoin the track at a shallow angle, at the sa... | todo | | |
| N1-04 | Paddock, parking and walkways: the concrete paddock and the parking area are flush with an... | todo | | |
| N1-05 | Double lines: where a wall and an edge line run side by side (`r2-04`), there is exactly o... | todo | | |
| N1-06 | Line checker: add checks (extend `SpeedwayChecks` or the M1 overlap scanner) that fail whe... | todo | | |
| N1-07 | Done when: the checks are zero everywhere, and before and after pairs from Adam's views (`... | todo | | |
| N1-01a | Network construction and diagnosis | todo | | |
| N1-02a | Use plot-local 2D coordinates for ground roads. Each edge records its centerline, width, e... | todo | | |
| N1-02b | Generate boundary paint after surfaces, from the final external boundary and tagged mouth ... | todo | | |
| N1-03a | Proposed starting geometry: 15 to 25 degrees for a pit fork; widen turns enough for the cu... | todo | | |
| N1-06a | Classify comparisons. A paint line necessarily overlaps its own supporting asphalt in plan... | todo | | |
| N1-06b | Keep a single surface-height convention and place paint relative to the local road normal.... | todo | | |
| N1-07a | Done when: reproduce known-bad crossing, duplicate-paint and grass-gap fixtures and prove ... | todo | | |
| N2-01 | Research how real stunt loops on tracks are built (for example toy-car loops, stunt-show l... | todo | | |
| N2-02 | Geometry: where the loop stands, widen the straight to at least two full track widths with... | todo | | |
| N2-03 | Cars through the loop: the decorative lap cars follow the loop centerline with the correct... | todo | | |
| N2-04 | Fits the levels: the loop appears at the levels where Round 1 put it (keep the level ladde... | todo | | |
| N2-05 | Done when: a Studio Play recording (with game audio) shows at least three cars going throu... | todo | | |
| N2-01a | Research, actual scale and a buildable method | todo | | |
| N2-02a | Verified local baseline: Track.luau uses Path.HalfWidth = 8, so the ordinary ribbon is 16 ... | todo | | |
| N2-02b | Proposed starting envelope for the stated 9 to 12 stud car length: loop road width 16 stud... | todo | | |
| N2-02c | Construct a smooth closed-turn vertical centerline in a local forward/up plane. One defens... | todo | | |
| N2-02d | Add lateral offset D*f(t), with t in [0,1] and f(t) = 6*t^5 - 15*t^4 + 10*t^3. Its first a... | todo | | |
| N2-03a | At every sample derive tangent T from the curve derivative. Derive a reference inward norm... | todo | | |
| N2-03b | Car wheels must sit on the same sampled surface used to create the ribbon. Derive the pivo... | todo | | |
| N2-03c | Keep Lap Pay and authoritative lap timing unchanged. If adding visual speed variation, cho... | todo | | |
| N2-05a | Adaptive tessellation starts with a 0.1-stud chord-error target and at most 3-degree tange... | todo | | |
| N3-01 | Barriers: the white wall blocks along the track edge form one even, continuous wall (no un... | todo | | |
| N3-02 | Props: keep race props in their zones (Round 1 M4-05). A concession cart is fine near the ... | todo | | |
| N3-03 | Walk every plot at levels 1, 6, 9 and 12 and fix anything else that looks unfinished: gaps... | todo | | |
| N3-03a | Physical polish checks | todo | | |
| N4-01 | Fastest Stunt Circuit board (`r2-05`): rotate it to face the center of the island (toward ... | todo | | |
| N4-02 | The low cyan info board near the portal pillar (`r2-05`, left): if it is lying flat or til... | todo | | |
| N4-03 | Trees (`r2-06`): no tree or bush may intersect another tree, bush, sign, gate, lamp or bui... | todo | | |
| N4-04 | Round 1 leftovers on the island: convert the island signposts to the sign family (Round 1 ... | todo | | |
| N4-04a | Readable signs and planted space | todo | | |
| N5-01 | Use ChatGPT's original icons from `chatgpt-images\` (`icon-*.png`, or cut them out of `IMG... | todo | | |
| N5-02 | Upload (R-05), then wire the icons into the UI kit: one icon module where each icon name m... | todo | | |
| N5-03 | Replace every icon in the game: Home menu, HUD, Shop (including every Starter Pack item an... | todo | | |
| N5-04 | Before the upload lands: the screens must still look finished. Use the best available exis... | todo | | |
| N5-05 | The "2x": Double Lap Pay's 2x is drawn into the icon art (a bold, rounded "2x" on a gold c... | todo | | |
| N5-01a | Asset preparation and verified upload paths | todo | | |
| N5-02a | Official Open Cloud limits: one asset per create request, up to 20 MB, image dimensions st... | todo | | |
| N5-02b | Read the key without printing it. Confirm its resource permissions authorize the intended ... | todo | | |
| N5-02c | Upload limits differ from usable texture resolution: Roblox documents a maximum texture re... | todo | | |
| N5-02d | Manual package procedure: open Studio's Asset Manager from Window or Home, then its import... | todo | | |
| N5-02e | Assets must pass moderation before use. Show the fallback while approval or loading is pen... | todo | | |
| N6-01 | Color: much more saturated and vibrant, like the reference: hot pink, electric purple, cya... | todo | | |
| N6-02 | Moving gradients everywhere it matters: the Shop button already cycles through a rainbow; ... | todo | | |
| N6-03 | BEST DEAL back on (section 2), with "SAVE X%" computed from the PREVIEW catalog and the st... | todo | | |
| N6-04 | Layout check against the reference: the first screen (Featured) must be as exciting as the... | todo | | |
| N6-05 | Fix the Round 1 gaps: wire the Raceway parking panel entry point ("Get more spots" opens E... | todo | | |
| N6-06 | Keep: no real purchases, no paid randomness, the honesty rules, PREVIEW prices, "Coming so... | todo | | |
| N6-02a | Motion system, hierarchy and phone budget | todo | | |
| N6-02b | Proposed motion recipes, measured in seconds, not frames: | todo | | |
| N6-02c | Initial phone limits: at most 6 continuously animated gradient instances and 1 breathing b... | todo | | |
| N6-03a | Compute savings only for identical included quantities and the same fixture currency: comp... | todo | | |
| N6-06a | Exercise every entry point, all tabs, scrolling, owned, pending, unavailable, preview buy,... | todo | | |
| N7-01 | Inventory first: watch both videos and write, in the ledger, a list of every HUD element a... | todo | | |
| N7-02 | One look across all panels: restyle Settings, Missions, Garage, the portal card and the ot... | todo | | |
| N7-03 | Phone landscape first: check every element at the phone landscape frame for thumb reach, s... | todo | | |
| N7-04 | Motion and sound: pills slide in and out, buttons pop on press, numbers count up, badges p... | todo | | |
| N7-05 | Done when: frames of the home HUD at the three sizes, plus one Play recording with audio, ... | todo | | |
| N7-01a | Reference inventory already completed | todo | | |
| N7-03a | Car Hop layout derived from the references | todo | | |
| N7-03b | Present Cash as a server-backed balance; format compactly while allowing full value in det... | todo | | |
| N7-04a | Proposed feedback: press 0.06/0.10 s, toast enter 0.18 s and exit 0.14 s, 2.5 s readable d... | todo | | |
| N7-05a | Required checks: longest car/world names; zero, large and unavailable balances; 0/24 and c... | todo | | |
| N8-01 | Icons that make sense: every step's icon clearly shows its action. "Go to Downtown!" uses ... | todo | | |
| N8-02 | Banner layout: the green instruction bar sits exactly centered under the headline inside t... | todo | | |
| N8-03 | Character guidance (optional, your call): use the dialogue card (N11) with a friendly mech... | todo | | |
| N8-04 | Run it for real in the beta (N13): a full playthrough from join to "You're ready!" in the ... | todo | | |
| N8-05 | After the tutorial: on later joins, a short chevron trail and goal pill point to the most ... | todo | | |
| N8-01a | Exact tutorial copy and icon mapping | todo | | |
| N8-02a | The green bar is centered within the banner body below the title, with identical left/righ... | todo | | |
| N8-04a | Steps 2 through 5 complete only through existing run adapter evidence, 7 through 9 through... | todo | | |
| N9-02 | The scene is alive: a looping animated scene of the player's own cars (or the placeholder ... | todo | | |
| N9-03 | CLAIM flies coins into the Cash counter (visual only; the amount comes from the server lat... | todo | | |
| N9-02a | Proposed scene storyboard and claim behavior | todo | | |
| N9-03a | Current WelcomeBackMock treats the supplied reward as already credited and the button as a... | todo | | |
| N9-04a | States: checking uses "Checking your Raceway..." and disabled claim; unavailable uses "Ear... | todo | | |
| N10-01a | Collection structure and states | todo | | |
| N10-02a | Preserve current sorting Rarest, Lap Pay and Newest, including stable tie handling and no ... | todo | | |
| N10-02b | Completion rewards are PREVIEW proposals, not new claim remotes. States are Incomplete, Co... | todo | | |
| N10-02c | Check all 3 worlds, empty/partial/full collection, long names, every sort, owned/unowned s... | todo | | |
| N11-01 | Dialogue card (reference B and `IMG-10-npc-dialogue.png`): a title bar with an icon and an... | todo | | |
| N11-02 | Update Log ("What's new"): a small panel on join (once per new version) listing recent cha... | todo | | |
| N11-01a | Dialogue layout and behavior | todo | | |
| N11-02a | Update Log: one compact header, up to 4 verified shipped changes with original icons, opti... | todo | | |
| N12-01 | Stop work on the course (`src/lookdev/Stunt`); leave it intact and hand it over in Brian R... | todo | | |
| N12-02 | Results card (redesign): follow `IMG-06-stunt-results.png`: a "FINISH!" ribbon, a huge med... | todo | | |
| N12-03 | Customization (paint, decals, wheels): follow `IMG-05-customize-garage.png`, inspired by t... | todo | | |
| N12-04 | Pre-race card and leaderboard: restyle into the new family. | todo | | |
| N12-03a | Cosmetic research and proposal boundaries | todo | | |
| N12-03b | The following is a complete PREVIEW catalog proposal for Brian L. It expands the earlier s... | todo | | |
| N12-03c | Cheap paint rendering and interaction | todo | | |
| N12-03d | Separate Previewed from Equipped. Clicking a card previews immediately; an owned item expo... | todo | | |
| N12-03e | Brian L's calibration task: compare price / verified net Cash per minute at early, middle ... | todo | | |
| N12-02a | Results: fit medal and key time into the top half, then ghost difference and three target ... | todo | | |
| N12-04a | Pre-race presents chosen car, supplied stats, selected course and existing start action, w... | todo | | |
| N13-02 | Real data where it exists (beta Raceway level and parking spots from the beta save, plot o... | todo | | |
| N13-03 | Test the whole join flow in the local beta file as a new player and as a returning player:... | todo | | |
| N13-01a | Exact join and modal queue contract | todo | | |
| N13-01b | Use one home modal coordinator, distinct from the existing lightweight notification Priori... | todo | | |
| N13-01c | Priority: transition/safety UI first, existing run results next, explicit user interaction... | todo | | |
| N13-01d | Loading is not a fabricated progress percentage. Show actual milestones or an indeterminat... | todo | | |
| N13-03a | Test join matrix: new player, returning with positive offline reward, returning with verif... | todo | | |
| N14-01a | Prevent weaker checks from hiding unfinished work | todo | | |
| N15-01 | Brian R: the Stunt Circuit is now his (Adam's decision, 2026-11-01). Hand over the Round 1... | todo | | |
| N15-02 | Brian L: the cosmetic tiers and PREVIEW prices (paint, decals, wheels), the Index completi... | todo | | |
| N15-01a | Dependency handoff contents | todo | | |
| N16-01a | Evidence and acceptance matrix | todo | | |
| N16-03a | Two reviewer agents may run concurrently, within the two-worker cap. Give each the origina... | todo | | |
| N16-04a | A finished-looking static frame is insufficient for moving cars, animation cleanup, popup ... | todo | | |
