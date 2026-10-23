---
title: HUD rebuild, capture feedback and Downtown B production start — ledger and plan
tags: [design, spec, ledger, lane3]
status: in progress
date: 2026-10-22
---
# HUD rebuild, run presentation and Downtown B production start (2026-10-22)

Source: Adam's prompt "Car Hop — HUD rebuild, unmistakable capture feedback, and Downtown B"
(pasted 2026-10-22 about 09:15; file
`C:\Users\agert\.codex\visualizations\2026\10\15\01a13fea-fe40-7753-b010-abaf2ed22b0d\Car-Hop-HUD-Rebuild-Downtown-B-Expanded-Prompt.md`,
outside the repo). Requirements below quote it by section (§). Owner: Adam (Lane 3). Builder:
Claude Code (lead) with subagents. Builds on the overnight task ([[hud-downtown-overnight]],
[[hud-prototype-architecture]], [[downtown-plan]], [[0018-hud-downtown-overnight-preview]]);
its text is not rewritten. Checkpoint for context changes: [[hud-rebuild-checkpoint]].

## Authority (task-scoped)

- Adam's decisions in §1 are fixed: Downtown direction **B (Bright Real City) is selected**; the
  new HUD references supersede conflicting old HUD references; Cash and car count move to the
  bottom left; Heat stays bottom centre; Keys stays beside the rider; Settings is a labelled
  small red rectangle; the approved big-gain celebration is preserved; interfaces are on hold
  (documented locally, no messages, requests or packages to Brian R or Brian L; one board note
  about free steering is allowed); sound candidates may be inserted for Adam's listening test;
  the run moves toward free A/D and thumbstick steering, owned by Brian R.
- **Task-scoped Figma exception (§1):** "Skip Figma for this task. I authorize Studio mocks and
  implementation of these Lane 3 previews without the normal intermediate Figma approval." Scope:
  the Lane 3 preview screens of this task, in the task's two local test places only. It does not
  change [[0012-figma-ui-workflow]], `AGENTS.md`, or any earlier approval record. UI specs are
  still written (`vault/design/ui/hud-arcade-rebuild.md`). Recorded in
  [[0019-hud-arcade-rebuild-preview]].
- One final owner-review stop (§1). Clicks that truly need Adam are batched.
- Not authorized: production integration, remotes, saves, rewards, purchases, new stats, event
  systems, Lane 1 road/steering/camera code, island edits, publishing, merging.

## Existing approvals and rules that win

- Run HUD revision 4 (2026-10-20, [[visual-direction]]): the CurrencyCounter + CashIcon, its
  gain behaviour (count-up about 0.35 s, 12% punch, 16% for big gains when the gain is at least
  max($1,000, 25% of the previous value), icon pop, 2–3 sparkles, rising "+$N" label), Format.cash
  rounding, Fredoka One 36/24/18/16, touch 48/56, scale = short side / 390 clamped 1.0–1.5,
  Reduce Motion = GuiService plus the preview-only override. **Its old top-left position is
  superseded by §1** (Cash bottom left).
- GDD: claiming is permanent immediately, even if the run then fails (Decided); Joyride Bonus on
  an owned car (Decided; amount Tunable, so +$50 stays a synthetic fixture). Four rarities are
  Proposed; the five-tier ladder with Uncommon is a proposal ([[rarity-style]]). The fixture keeps
  the five-tier ladder labelled as the live preview vocabulary; nothing here confirms Uncommon.
- `AGENTS.md`: vehicles have no police, military or emergency-service liveries (hence §16's
  delivery depot instead of a fire station); no real logos; children's audience (no FOMO,
  manufactured urgency or paid-luck presentation).
- Lane 3 delegation ([[lane3-delegation]], island branch): Studio lock, 4 GB memory floor, honest
  three-group reporting, independent review before stopping, uploads only under peskaface,
  free licensed-partner audio allowed for testing once Adam is told to listen.

## Contradictions and how they are resolved

| # | Passage A | Passage B / rule | Resolution |
|---|---|---|---|
| C1 | Dino analysis §3: "Our Cash stays top left" | §1/§2: "Cash/car count move to bottom-left"; "The study's old 'Cash stays top-left' statement is superseded" | Bottom left (Adam's explicit decision). |
| C2 | Dino analysis §5/§16 base prompt: fire station + ladder truck | `AGENTS.md` vehicle rule 5: no emergency-service vehicles or liveries | §16 already resolves it: a fictional delivery depot / roadside service workshop. Recorded here. |
| C3 | HUD refs show Gear, Slow Mode, hotbar, right-side squares, timers | §5: no fake features; timer stack is an off-by-default proposal; no hotbar | Only real local settings (Music toggle); timers off by default, PREVIEW captioned. |
| C4 | "Preserve the approved big-gain celebration" | the overnight CashLine added preview-only extras (merging chip, 6 bill sparks, 8 s cooldown) that were never approved | The approved rev-4 CurrencyCounter behaviour is reused unchanged; the overnight preview extras are kept as they were (not redesigned) and listed as preview. Regression = overnight reel 1 at 1.5 s (baseline) against the new recording. |
| C5 | Overnight Settings: 48 px gear without label | §1: Settings has a visible text label, small red rectangle | §1 wins (new references supersede). |
| C6 | Red reserved for danger/badges in the overnight synthesis ("no red badge on Shop") | §4: red Settings and earned red badges are explicitly requested; Shop badges only for actual free fixture claims | Red Settings + earned badges allowed; run danger made distinct by icon, reason text, location and transience. |
| C7 | Old fixture road 4 × 12.5 studs | §13: preview 4 lanes of 16–18 studs | New study compares widths; old value kept only for the old studies. |

## Requirement ledger

Status values: open · in progress · built · build-checked · runtime-tested (Studio) ·
visually-reviewed · rendered (Blender only) · blocked · deferred.
Owners: L lead · HA HUD art/kit · HH home HUD · HS screens · HR run HUD · HW world/feedback ·
DK Downtown kit (Blender operator) · DC Downtown city grammar (Studio) · RV reviewers.

### Process and references (§1–§3)
| ID | Requirement | Owner | Acceptance evidence | Status |
|---|---|---|---|---|
| R-01 | Work in `Roblox-Game-1-hud` on the branch; inspect git and notes first; no island or teammate changes (§1) | L | git log; island worktree untouched | in progress |
| R-02 | Ledger + plan recorded in the task documents (§1) | L | this file | built |
| R-03 | Read both HUD images, the dino analysis and all 11 frames (01 04 08 15 19 27 29 30 56 57 60) (§2) | L | reference comparison doc | done (lead read all) |
| R-04 | Reference comparison doc: visible / inferred / preserve / change; no game identification; no motion/metric claims from stills (§2) | L | `vault/design/research/hud-rebuild-reference-comparison.md` | done |
| R-05 | Copy study material into the references convention without duplicate binaries; provenance (§2) | L | provenance index | done |
| R-06 | Parallel bounded research: HUD translation, capture feedback, runner progress/failure, modular city; official docs for APIs and audio (§3) | RV | `vault/design/research/*.md` (5 notes) | done |
| R-07 | Delegated build with explicit owned files; lead owns tokens, integration, ledger, manifest, review page (§3) | L | "Component boundaries" below | built |
| R-08 | Respect the Studio lock; recheck about every 10 min; never seize; one Studio and one Blender operator; Blender safe mode; 4 GB floor (§3) | L | lock log in checkpoint; memory log | in progress |
| R-09 | Compact checkpoint (§3) | L | [[hud-rebuild-checkpoint]] | built |

### Visual system (§4)
| ID | Requirement | Owner | Acceptance evidence | Status |
|---|---|---|---|---|
| V-01 | One specimen sheet in Studio over real world backdrops: Shop/Garage/Missions/Settings, earned badge, car count, Cash, earning line, Heat, one Keys state, car card; compared against both images before propagation (§4) | L | specimen capture + comparison notes | runtime-tested: specimen over Downtown B captured; compared against both references by the lead (stills/specimen*, desktop-home) |
| V-02 | Heavy rounded typography, strong dark outlines, open counters; italic numbers/timers via a verified font (no rotated rows) (§4) | HA | specimen; font record | runtime-tested (Fredoka One labels, Nunito Black Italic numbers rendered in Studio) |
| V-03 | Consistent text/stroke/icon/spacing tokens; major outlines 3–4 px at 1080p; lighter outlines for subordinate text; no blobs, clipping, grey shadows (§4) | L | `Prototype/Arcade.luau` tokens; zoomed captures | runtime-tested (zoomed captures); Studio reading: UIStroke follows UIScale |
| V-04 | Buttons: strong fill, controlled gradient, narrow gloss, shallow depth; faint original motor pattern on large buttons only (§4) | HA | specimen zoom | runtime-tested |
| V-05 | Near-black/navy outlines; Cash green, cars cyan, Keys gold, Hop teal/white, Heat yellow→orange→red; teal reserved for targeting except the requested teal GO HOME (§4) | L | token table | runtime-tested |
| V-06 | Rarity and variants separate fields; rarity vocabulary as live preview (Uncommon proposed) (§4) | L | fixture + cards | runtime-tested (card sheet) |
| V-07 | Red Settings and earned red badges kept; danger distinct by icon/reason/location/transience; Shop badge only for actual free fixture claims (§4) | HH | captures | runtime-tested |
| V-08 | Components judged on ratio, label weight, icon balance, spacing, silhouette, reference proximity, bright scenery (§4) | RV | HUD reviewer report | reviewed by the independent reviewer (REVIEW.md) |

### Home HUD (§5)
| ID | Requirement | Owner | Acceptance evidence | Status |
|---|---|---|---|---|
| H-01 | Compact red labelled "Settings" rectangle above the stack, centred on it; no Gear (§5) | HH | captures 4 sizes | runtime-tested |
| H-02 | Shop: wide rainbow button, original gift/cart icon left, large label; readable bands; slow drift only, stopped in reduced motion; no purchase bait (§5) | HH/HA | capture + video | runtime-tested (drift visible in video; RM stop is code-checked) |
| H-03 | Garage: cyan→blue, car-book/garage icon, earned-unseen badge top right that survives press scaling (§5) | HH/HA | press-state capture | runtime-tested |
| H-04 | Missions: orange, clipboard icon, earned-claim badge; equal widths, aligned icon centres, deliberate gaps; ~2:1–2.4:1 starting ratio (§5) | HH | measurements | runtime-tested |
| H-05 | Toggle row: only a real local setting (Music) with obvious state and label; close the gap if absent (§5) | HH | video toggling | runtime-tested (Music toggle scenario) |
| H-06 | Bottom-left stats, no panels: cyan car icon + count; inert "+" as part of the collection symbol, never a buy affordance (§5) | HH/HA | capture | runtime-tested |
| H-07 | Cash: original cash stack, large green amount, dark outline, no panel; icon anchor fixed as digits grow (§5) | HH | extreme-balance captures | runtime-tested |
| H-08 | Approved big-gain celebration preserved: baseline recording + regression comparison; anchor relocated only; reduced-motion accessibility fix only, recorded (§5, C4) | HH | baseline vs new video | runtime-tested: video regression vs the overnight reel (biggain/new-grid vs base-grid) |
| H-09 | Earning line: smaller white slightly italic "Speedway: +$120 / lap", PREVIEW, units/wording Lane 2's (§5) | HH | capture | runtime-tested |
| H-10 | Number format: commas + K/M/B/T with consistent rounding and promotion (no "1000K", no flicker, no shifting icon, no truncated suffix); full value via tap/focus/hover (§5) | HH | boundary test table | runtime-tested (format boundary scenario run; values logged) |
| H-11 | Timer stack: optional proposal, off by default, italic outlined timer + original event icon, no real clock, never shown to ordinary players (§5) | HH | proposal capture (captioned) | built; off by default; not captured this pass |
| H-12 | No right-side square buttons, no Daily/Goals, no hotbar (§5) | HH | captures | runtime-tested |
| H-13 | Tutorial restyled (yellow banner/tab, outlined); objective > progress > hint hierarchy; toasts max 2, queue limit, coalescing, reserved space (§5) | HH | video | runtime-tested (tutorial + toasts video) |
| H-14 | Settings panel: real local-preview volume/reduced-motion, clear close/back; no new schemas (§5) | HH | video | built; restyled panel not captured this pass |
| H-15 | Garage, portal picker, Welcome Back, Shop mocks restyled into the new family (restyle only) (§5) | HS | captures | built; Garage/Portal/Welcome/Shop restyle not captured this pass (card sheet captured) |

### World presentation modules (§6)
| ID | Requirement | Owner | Acceptance evidence | Status |
|---|---|---|---|---|
| W-01 | Parameterised destination label: glossy colour/white lettering, dark outline, controlled depth; max range, scaling bounds, occlusion policy; samples GARAGE, STUNT CIRCUIT and the three World names on test fixtures (§6) | HW | captures near/far/occluded | runtime-tested (labels near/far/occluded; TextSize bug found and fixed in Studio) |
| W-02 | Ground interaction marker: coloured centre + crisp white ring, grounded, no flicker, sized to the interaction area; inactive quiet; distinct from the dashed teal Hop ring (§6) | HW | captures | runtime-tested (fixtures video) |
| W-03 | Base fixtures: Lineup rarity/name label, Lap Pay label, Paddock upgrade board (current/next tier, preview price), padlock/progress plaque, first-session START/ground guidance, return-to-plot arrival sparkle — visual only (§6) | HW | captures + sparkle video | runtime-tested (fixtures video) |
| W-04 | Local note for future island adoption; no island change, no message (§6) | L | "Island adoption note" below | done (ledger note) |

### Responsive layout (§7)
| ID | Requirement | Owner | Acceptance evidence | Status |
|---|---|---|---|---|
| L-01 | Test 1920×1080, ~844×390, 390×844, a tablet; record viewport/inset settings; analyse the playable viewport (§7) | L | matrix with settings | runtime-tested: four virtual device frames (desktop 1920x1080, tablet 1180x820, phone 844x390, 390x844), not physical devices |
| L-02 | Responsive constraints, not one global scale; ~44–48 px provisional hitboxes; primaries larger; live approved sizes (§7) | L | hitbox measurements | runtime-tested |
| L-03 | Safe areas without double-counted insets; controls or a labelled reserved-zone overlay; phone currency above/beside the thumbstick; compact run menu (§7) | L | overlay captures | runtime-tested (reserved-zone overlay) |
| L-04 | Heat bottom centre, compact, outside thumb zones, room above for rider and Keys; Hop bottom right; purpose-built portrait (§7) | HR | captures | runtime-tested (Heat bottom centre on all four after fixes) |
| L-05 | Protected road-ahead region from the preview camera; banners/cards/toasts kept out (§7) | L | region overlay capture | runtime-tested (protected region used by Keys/Heat solvers) |
| L-06 | Priority system: safety > capture > district > rewards > ambient (§7) | L | `Prototype/Priority.luau` + coincidence video | runtime-tested (coincidence scenarios) |

### Run HUD (§8)
| ID | Requirement | Owner | Acceptance evidence | Status |
|---|---|---|---|---|
| U-01 | Top-centre district strip: original illustrated tiles from real district landmarks, names, current highlight, avatar head + distance; visited/current/upcoming without locks/rewards; stable layout (§8) | HR/HA | captures + video | runtime-tested |
| U-02 | Phone: compact current + adjacent/next tile; fallback avatar icon while the head loads (§8) | HR | phone captures | runtime-tested |
| U-03 | Endless: repeating cycle or rolling window from explicit boundary data; cycle index local to the fixture; proposals to Lane 1 (§8) | HR | cycle video | runtime-tested (LAP 2 badge, rolling window) |
| U-04 | District entry banner below the strip; one icon/name; never stacks with tutorial/toasts; deferred by critical warnings (§8) | HR | coincidence video | runtime-tested |
| U-05 | Bottom-centre Heat: dark frame, segmented fill, flame icon, stage marks, ramp; one brief stage emphasis; no invented thresholds shown as rules (§8) | HR | video | runtime-tested |
| U-06 | Cash/count compact during driving; left-middle "claimed this run" tray with count, bounded thumbnails, overflow count; pending slot never increases the count (§8) | HR | many-claims capture | runtime-tested |
| U-07 | Hop button: original car-jump symbol, input labels (Space / touch / gamepad), ready/disabled/cooldown not by colour alone; preview intent only (§8) | HR | captures | runtime-tested for keyboard (Space); touch/gamepad labels code-checked |
| U-08 | Foot Dash / milestones kept and aligned with the hierarchy (§8) | HR | video | built; Foot Dash/milestones not captured this pass |

### Traffic information and Hop target (§9)
| ID | Requirement | Owner | Acceptance evidence | Status |
|---|---|---|---|---|
| T-01 | Nameplates: rarity, name, NEW! only when authoritative unowned, variant when relevant; unknown never NEW! (§9) | HW | fixture captures | runtime-tested |
| T-02 | Priority (ridden, selected, nearby notable), count cap, screen-space overlap suppression, hysteresis/fades (§9) | HW | crowding video | runtime-tested (18 tracked, 3 shown, 3 overlap-suppressed) |
| T-03 | No unreadable specks (fade after min size); occlusion policy; rarity text/symbol not colour-only (§9) | HW | captures | runtime-tested |
| T-04 | Rare-or-better arrival reveal: brief side ribbon outside the road region; dedupe by identity; cooldown/queue (§9) | HW | dedupe video | runtime-tested (2 shown, 2 deduped, 4 dropped) |
| T-05 | Hop ring: one target, dashed teal/white, grounded, scaled to footprint, no clipping; clean retarget; disabled state by structure/brightness (§9) | HW | captures | runtime-tested |
| T-06 | Thin arc-preview telegraph from target data, labelled not ballistic; pointing pose optional only if cheap (§9) | HW | video | runtime-tested (arc visible; reads as a thin beam from behind) |
| T-07 | Reduced motion: stable ring/arc; all cues clean up on despawn/retarget/run end/reset (§9) | HW | video + debug counts | runtime-tested for retarget/despawn; RM ring code-checked |

### Keys capture (§10)
| ID | Requirement | Owner | Acceptance evidence | Status |
|---|---|---|---|---|
| K-01 | Full redesign; rider-relative placement kept; stable tracking, size limits, safe clamp, offscreen/despawn handling, no jitter (§10) | HR | video | runtime-tested |
| K-02 | Bold gold segmented ring (8–12 proposal), dark boundary, restrained inner shadow, original key-in-lock centre, percentage secondary (§10) | HR/HA | zoom capture | runtime-tested |
| K-03 | Rarity colour on the car outline/accent/final reveal only; gold = capture; teal = Hop (§10) | HR/HW | captures with Rare car | runtime-tested |
| K-04 | States: idle; start (rarity outline, sparse particles, CAPTURING plate, HOLD ON); progress (segments, key turns, glow, rising sound; ALMOST once near 75%); pending (SECURING…, no ownership claim); confirmed (lock opens, burst, YOU GOT THE KEYS! + identity + Keep going!, compact side ribbon while driving); tray arrival (+1 once, stamp; delayed confirmation into Results); canceled (fracture, truthful reason, no loss) (§10) | HR/HW | state video | runtime-tested (all states in video) |
| K-05 | Identity/dedupe/ordering: duplicates, delays, out-of-order cannot duplicate, replay or reverse (§10) | HR | scripted event test log | runtime-tested (state log: monotonic, 3 duplicates ignored) |
| K-06 | Owned car: silver Joyride presentation, JOYRIDE BONUS only on a supplied confirmed event, +$50 synthetic (§10) | HR | capture | built; Joyride row seen in Results; ring not captured this pass |
| K-07 | Motion/audio hierarchy: release 100–200 ms, burst, ribbon 1–2 s, tray settle; capped edge accent; warning wins; reduced motion calm path (§10) | HR | video RM on/off | runtime-tested (RM capture) |
| K-08 | Acceptance: a new viewer can tell which car, how close, pending, secured, without losing the next target (§10) | RV | run reviewer | open |

### Warn, eject, explain, recover (§11)
| ID | Requirement | Owner | Acceptance evidence | Status |
|---|---|---|---|---|
| E-01 | Driven by explicit events (warning reason, dismount, run-end reason, Results); never inferred from tint or Heat; instant failures explained immediately; prior-warning dependency recorded for Lane 1 (§11) | HR | scenario log | runtime-tested |
| E-02 | One controlled red car emphasis, ! symbol, TOO HOT reason; no strobe/loud repeats; material restored (§11) | HW | video | runtime-tested (car parts unchanged after warning) |
| E-03 | Safe fixture proxy cartoon tumble; no real physics/camera change; labelled placeholder; child-friendly (§11) | HW | video | runtime-tested (tumble proxy, real character untouched) |
| E-04 | OVERHEATED! heading + "Heat full" line, then Results; reason mapping with truthful fallback; claimed cars stay (§11) | HR | video | runtime-tested |
| E-05 | No stacking of fanfare/warning/banner/Results; capture at run end preserved in Results (§11) | L/HR | coincidence video | runtime-tested (capture at run end preserved) |
| E-06 | Results: fixed footer RETRY (orange) / GO HOME (teal); scroll region; correct card bounds; Revolution 6 and longer names readable; no-claim/one/many; no double transitions (§11) | HS | captures + video | runtime-tested (no/one/many, repeated taps = 1 transition) |
| E-07 | Return-to-home fixture: restrained arrival sparkle around a stand-in plot gate (§11) | HW | video | runtime-tested (fixtures video) |

### Sound (§12)
| ID | Requirement | Owner | Acceptance evidence | Status |
|---|---|---|---|---|
| S-01 | Candidates from permitted Roblox licensed-partner sources, each verified (source, access, usage); no fabricated IDs (§12) | RV/L | `vault/design/research/sound-candidates.md` | done (16 ids verified via Roblox APIs) |
| S-02 | Categories: pop, cash ding, (big gain preserved), capture rise, confirmation fanfare, toast/tutorial chime, warning blip, cartoon bonk, Results ticks; consistent loudness (§12) | L | listening table | built (routes per category) |
| S-03 | UI SoundGroup routing + volume setting; voice caps; tick throttling; clamped capture pitch stopped on cancel/destroy (§12) | L | Sounds.luau + debug counts | code-checked (voice caps, throttles, stopRise) |
| S-04 | Listening table; inserted in the private preview; listening vs verified properties stated (§12) | L | review page | inserted; all 16 load in Studio with verified lengths; NOT listened |
| S-05 | Original icon/thumbnail art with source files; uploads only under existing permission (peskaface, logged), else batched approval (§12) | HA | asset manifest | built, build-checked; Studio pending |

### Downtown B (§13–§16)
| ID | Requirement | Owner | Acceptance evidence | Status |
|---|---|---|---|---|
| D-01 | Preserve B's look; no studs, crude boxes, photoreal noise; no drift to A or C (§13) | DK | renders vs overnight B | runtime-tested (Studio edit mode + Play merge) |
| D-02 | Reusable art, recipes, modules, documented sockets; private deterministic assembly/chase harness excluded from production (§13) | DK/DC | files + harness | runtime-tested |
| D-03 | Fix the theater's chase silhouette; remove hazard-like orange striped awnings; cut needless triangles (§13) | DK | before/after chase frames + counts | rendered + Studio (theater blade/marquee in route) |
| D-04 | Road study: 4 lanes × 16–18 studs + shoulders; real car dimensions; side-by-side widths; chosen reversible value (§13) | DC | width comparison frames | runtime-tested (width study table) |
| D-05 | Clear shoulders + scenery setback; visual clearance only; A/D and thumbstick untouched (§13) | DC | frames | runtime-tested (visual clearance only) |
| D-06 | Camera labelled (FOV/height/offset/speed) and alternatives; no shipped camera change (§13) | DC | camera table | runtime-tested (fixture camera labelled on screen) |
| D-07 | Modules: units, pivots, named start/end sockets, road-edge alignment, curvature, setback, bounds, detail levels (§14) | L/DK/DC | kit contract below + manifest | runtime-tested (0 socket mismatches, join error 0) |
| D-08 | ≥2,000-stud route of reused segments: straights, gentle curves, intersections, district transitions; seams, markings, sidewalks, horizon correct; compatible orientation families (§14) | DC | 2,000-stud chase video | runtime-tested: 3,300+ studs chase video |
| D-09 | Variation: frontage widths, rooflines, palettes, storefront/door/window/cornice, roof equipment, signs, courtyards/pocket parks/corners, landmark rhythm (§14) | DK/DC | sequence printout + frames | runtime-tested |
| D-10 | Deterministic seed; no immediate repeats; no identical L/R pairs; district palettes; seed + sequence shown (§14) | DC | review printout | runtime-tested (0 repeats; printout saved) |
| D-11 | Bounded active window with clean reuse; second pass/reset for duplicates, memory, lighting (§14) | DC | counts + memory log | runtime-tested (created 371 / released 368 / reused 158; rebuild x3 identical) |
| D-12 | Distance units: studs vs metres kept separate; provisional conversion labelled (§14) | DC/HR | fixture note | runtime-tested (provisional metres on screen) |
| D-13 | Five districts with silhouettes, signature material/colour, thumbnail landmark and measured transitions: Main Street (REEL WHEELS theater, blade sign + marquee), City Hall (clock tower with base/roof, plaza, trees, lamps), Harbor Bridge (river crossing, parapets, waterfront glimpses, continuous deck), Midtown (taller midground, selective glass, grids, roof tanks, distant stadium), Skyline Park (setbacks, verges, fountain, skyline) (§15) | DK/DC | per-district frames | runtime-tested partly: districts read; clock tower, fountain and stadium not clearly visible from the chase |
| D-14 | Landmark family with hierarchy: theater, car wash (calm brushes off-lane), service canopy, city hall/clock tower, harbor bridge, park fountain, donut bakery (sign structural), distant stadium, **delivery depot / roadside service workshop** (C2); approach/passing/rear views or a labelled gallery (§16) | DK | route frames + gallery | partly: theater, city hall, service canopy, car wash in route; fountain/depot/bakery/stadium gallery is Blender only |
| D-15 | Bunting / WELCOME TO DOWNTOWN spans: sparse, supported, above clearance (§16) | DK/DC | frames | runtime-tested |
| D-16 | Small fictional sign family (WHEEL GOOD PIZZA, BRAKE-FAST DINER, LUG NUTS HARDWARE + originals); no real logos (§16) | DK | sign sheet | runtime-tested |
| D-17 | Street life off-road, bounded, reduced motion: pigeons, flags, cart steam, birds/blimp; subtle exhaust only (§16) | DC | video | runtime-tested (pigeons, flags, steam, blimp present) |
| D-18 | Construction language reserved for hazards; readable cones; crane outside clearance (§16) | DK | frames | runtime-tested (construction proxies) |
| D-19 | Potholes recessed with rim/depth at chase angle; oil dark sheen with controlled iridescent edge; scenery only (§16) | DK | chase frames | runtime-tested (kit pothole/oil) |
| D-20 | Frontage/midground/skyline separated by scale/contrast/haze; no haze hiding pop-in; bright day; no shiny brick or random scatter (§16) | DK/DC | frames | runtime-tested |

### Engineering, performance, verification, handoff (§17–§18)
| ID | Requirement | Owner | Acceptance evidence | Status |
|---|---|---|---|---|
| X-01 | Strict Luau, typed APIs, Trove/Signal/Promise conventions, Rojo source of truth, one style system with scoped new tokens (§17) | all | check.ps1 | build-checked (check.ps1 passes) |
| X-02 | Preview adapters drive everything; hooks documented in the held ledger only; no remotes/data/saves/purchases/events (§17) | L | "Held interfaces" below | built, build-checked; Studio pending |
| X-03 | Bootstrap needs the dedicated playground marker + Studio; never production or island (§17) | L | leak check | built (inherited marker gate) |
| X-04 | Bounded pools/queues, capped particles/nameplates, shared scheduling, cleanup, hidden shine paused, cheap labels over ViewportFrames (§17) | all | debug counts | runtime-tested (counts in debug state) |
| X-05 | Blender import manifest, stable names/pivots/materials, one batch import package; verify IDs and access (§17) | DK/L | `assets/downtown/kit-b/MANIFEST.md` | built; import NOT done (EditableMesh previews used) |
| X-06 | Frame times with documented method: typical + stress, with HUD/traffic/names/capture active; parts, meshes, tris, textures, emitters, UI elements, memory trend; 30 fps provisional floor (§17) | L | perf table | runtime-tested on the desktop host (see evidence index) |
| X-07 | Fixtures and recordings for the §18 list | L | review page | done (evidence index) |
| X-08 | Fresh reviewers: HUD/reference, run, city, integration; findings with requirement/location/severity/fix; fixes rechecked (§18) | RV | review files | open |
| X-09 | Update draft PR #2 after checks; check.ps1; commit task-owned changes; push; release lock; stop owned helpers (§18) | L | PR + git | open |
| X-10 | Review page leading with HUD and city, with every §18 section incl. "Decisions I made for you", "Waiting for you", honest separation; final answer on Studio-tested vs code-read (§18) | L | `Car-Hop-Art/review/hud-rebuild/index.html` | open |
| X-11 | Free-steering direction recorded for Brian R on the board (allowed note) (§1, §13) | L | board line | open |

## Component boundaries (who writes what)

Shared core, **lead only**: `Prototype/PreviewTokens.luau` (new `Arcade` block), `Prototype/Arcade.luau`
(the arcade kit: outlined text, numbers, buttons, badges, toggles, motor pattern), `Prototype/Store.luau`
(state and event types), `Prototype/Priority.luau` (screen-slot arbiter), `Prototype/Sounds.luau`,
`playground/hud/scripts/HudPlayground.client.luau`, `playground/hud/scripts/Scenarios.luau`,
`playground/hud/scripts/Backdrop.luau`, this ledger, the checkpoint, the UI spec, the manifest,
the review page. Workers never edit these; they ask the lead in their report.

| Worker | Owns (create/edit only these) |
|---|---|
| HA HUD art | `Prototype/Icons2.luau` (illustrated icons + district tile art), `Prototype/Specimen.luau` |
| HH Home HUD | `Prototype/Home/*` (LeftMenu, StatsStack, CashLine, TimerStack, TutorialBanner, ToastStack, SettingsPanel, Layout, Types, Fade, TutorialRoute), `playground/hud/scripts/scenarios/Home.luau` |
| HS Screens | `Prototype/Screens/*`, `Prototype/Cards/*`, `playground/hud/scripts/scenarios/Screens.luau` |
| HR Run HUD | `Prototype/Run/*` (DistrictStrip, DistrictBanner, HeatBar, ClaimTray, HopButton, KeysLock, CaptureRibbon, RunEnd, existing Run files), `playground/hud/scripts/scenarios/Run.luau` |
| HW World + feedback | `Prototype/World/*` (Nameplates, RareReveal, HopRing, Arc, CaptureFx, WarnFx, TumbleProxy, DestinationLabel, GroundMarker, BaseFixtures, ArrivalSparkle, existing World files), `playground/hud/scripts/scenarios/World.luau` |
| DK Downtown kit (only Blender operator) | `assets/downtown/kit/` B files and new `kit_b2*.py`, `assets/downtown/kit-b/` docs; output `Car-Hop-Art/downtown-kit-b2/` |
| DC Downtown city | `src/lookdev/Downtown/City/*`, `playground/downtown/scripts/*`, `playground/downtown.project.json` |

Scenario convention ([[hud-rebuild-worker-guide]]): each `playground/hud/scripts/scenarios/<Area>.luau` returns
`{ [scenarioName] = function(host) ... end }`; the lead's Scenarios host loads them and adds the
names to the list. `host` gives `store`, `api`, `wait(seconds)` (cancellable), `emit(kind, fields)`,
`runPatch(patch)`, `car(id)`.

## Downtown kit contract (lead; DK and DC build to it)

- Units: studs. Road frame: +X right, travel toward −Z, ground y = 0, road centre line x = 0.
- **Segment** = one ModuleScript-described road piece with `length` (straights 96 or 192 studs),
  `kind` (Straight, CurveL, CurveR, Intersection, BridgeDeck, Transition), `startSocket` at the
  origin facing −Z, `endSocket` CFrame (straight: (0,0,−length); curve: arc of radius R = 360,
  angle 16°), road width parameter `laneWidth` × `lanes` + 2 × shoulder.
- **Lot** = a frontage module placed along a segment edge: pivot at the front-left corner of its
  footprint at ground level, facade facing the road (+X for left-side lots after placement,
  never its rear); widths from the 12-stud bay family {24, 36, 48}; depth ≤ 24; height classes
  low (2 storeys) / mid (3–4) / tall (5–7, Midtown). Orientation families: `front`, `corner-L`,
  `corner-R`; a lot is mirrored only by choosing its mirrored mesh variant, never by rotation.
- Setback from the road edge: sidewalk 12 + 0 frontage line (courtyard lots add 8–16).
- Bands: frontage 0–25 from the road edge, midground 60–140, skyline 300–900.
- Mesh names: `B2_<family>_<variant>` (e.g. `B2_Lot_Shop24_brick`, `B2_Lot_Tall36_glass`,
  `B2_LM_Theater`, `B2_Road_Straight96_L4W17`); every mesh JSON gets `meta.sockets` (named
  CFrames as {x,y,z,yaw}), `meta.bounds`, `meta.lod` ("near"|"mid"|"far"), `meta.district`.
- Districts (fixture order, repeating): Main Street → City Hall → Harbor Bridge → Midtown →
  Skyline Park; each 480–720 studs in the fixture (explicit boundaries in a data table, not equal
  spans); transitions blend over 2–3 lots per side.

## Held interfaces (proposed, not sent)

Extends the overnight table ([[hud-downtown-overnight]] "Interfaces"); nothing below is agreed or
sent. New this task:

| Field / event | Type and unit | Lifecycle | Owner |
|---|---|---|---|
| run.districtPlan | `{ districts = { {id, name, length (m)} }, repeats }` explicit boundaries | at run start | Brian R |
| DistrictEnter event | `{ id, district, cycle }` | once per boundary crossing | Brian R |
| KeysStart / KeysCanceled | `{ id (capture id), car }` / `{ id, reason }` | once each per capture id; monotonic | Brian R |
| KeysConfirmed (already proposed) | `{ id, car }` | exactly once; may arrive after run end | Brian L |
| RunWarning | `{ id, reason ("TooHot" ...), until? }` | only when an advance warning truly exists | Brian R |
| Dismounted / RunEnded | `{ id, reason }` | once; reason mapping with a truthful fallback | Brian R |
| traffic car display | `{ instanceId, carId, rarity, variant, owned: boolean? (nil = unknown) }` | on spawn/despawn | Brian R (spawn), Brian L (ownership) |
| hop target | `{ instanceId, footprint (studs) }` | on change | Brian R |
| steering | free left/right, A/D + thumbstick (direction recorded for Brian R; not implemented here) | — | Brian R |

## Island adoption note (W-04, local only)

DestinationLabel, GroundMarker and the base fixtures are written as parameterised modules that a
future island task could adopt; nothing on the island branch or in the island place is changed
by this task, and its operator is not messaged.

## Plan

1. Lead: ledger, checkpoint, decision 0019, research launch (done), core contracts
   (PreviewTokens Arcade block, Arcade kit, Store types, Priority) — before workers start.
2. Workers in parallel, owned files only: HA, HH, HS, HR, HW (HUD) and DK, DC (Downtown).
   DK is the only Blender operator (headless, safe mode, memory floor).
3. Lead integrates scenarios, wires sounds, builds both places with `rojo build`.
4. Studio phase (after the island lock is released): specimen sheet and comparison first, then
   propagate fixes; record all §18 fixtures; Downtown chase and perf; batched clicks for Adam
   (mesh import, device emulator if needed).
5. Fresh reviewers (HUD/reference, run, city, integration) on real captures; fixes; rechecks.
6. Checks, commits, push, draft PR #2 update, review page, log, board; lock released.

## Decisions I made (reversible, preview)
Recorded as they happen in [[hud-rebuild-checkpoint]] and on the review page.

## Independent review and fixes (2026-10-23)
One fresh reviewer (did not build anything) reviewed the Studio evidence from stills and frame
grabs: `Car-Hop-Art/review/hud-rebuild/REVIEW.md` (35 findings). The lead fixed the material ones
and re-captured each fix on the final build (index: `EVIDENCE-INDEX.md`, "After the independent
review"). No second review was requested: no material issue stayed unresolved without an owner
decision.

| Finding | Status after the fix pass |
|---|---|
| R1 capture target cues disagree (blocker) | fixed, Studio-verified: the backdrop rides the captured car; ridden plate follows `run.ride`; CAPTURING plate, chip, ring and ribbon name one car |
| R2 teal beam points at nothing | fixed, Studio-verified: arc drawn from 30% of the curve, even dashes to the target; now subtle (the dashed ring is the main target cue) |
| H1 Keys ring under HOP on phone landscape; SECURING twice (blocker) | fixed, Studio-verified (fallback scan; one SECURING) |
| H4 / R7 plates under the strip, distance, chip, banner | fixed, Studio-verified (HUD blocker rects; 58 px viewport-inset bug found and fixed) |
| H3 stray dark bar top right | fixed: Roblox health bar of the harness character, hidden in the playground |
| H9 empty RUN OVER fallback, grey buttons | fixed, Studio-verified (intro line; colours kept during the reveal) |
| H8 red wash / strobe | measured from the mp4: no strobe (≤ 3 flashes/s; held tint) |
| H7 warning hairline, TOO HOT! mid-road | fixed, Studio-verified (stronger tint, chip above Heat) |
| H14 HOP NOW! after OVERHEATED | fixed, Studio-verified; the ~11 px words are the approved 16 design px drawn at the small Studio viewport's 0.53 scale |
| H5a unlabelled pill | fixed: "RIDING" tag |
| C1 no water/arch at Harbor Bridge | fixed, Studio-verified |
| C2 no fountain in Skyline Park | fixed, Studio-verified (signature post-pass) |
| C3 stadium invisible | fixed, Studio-verified (setback 90 + frontage view gap); seen while passing, not far ahead |
| C5 sign names repeat; checker blind | fixed: no name twice within 400 studs, checker counts by name and distance (seed 2207: 15 signs, 0 repeats) |
| R8 strip out of sync | fixed earlier (city-driven distance); re-captures agree at the bridge, Midtown and Skyline Park |
| H12 destination labels unverified | re-captured after the size fix (stills/dest-labels-after-grid.jpg) |
| H2 phone ribbon | partly: one line and full name now; still overlaps the cash line and strip during its hold |
| H5b Coins counter, H6 stats off bottom-left on phones | owner decisions (Waiting for you) |
| H16 run overlays use a second (dark card) style | open: needs a restyle pass toward the button grammar |
| C6 flat skyline boxes, C4 clock tower, C7 road width, C8 oil vs pothole, H10, H11, H13, H15, R3, R5, C9 | open (minor), listed on the review page |
