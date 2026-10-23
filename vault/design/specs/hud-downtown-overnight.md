---
title: HUD build + Downtown look development (overnight) — ledger and plan
tags: [design, spec, ledger, lane3]
status: in progress
date: 2026-10-22
---
# HUD build + Downtown look development (overnight, 2026-10-22)

Source: Adam's overnight prompt (pasted 2026-10-22 about 00:55, kept verbatim in the session
scratchpad; the requirements below quote it by section). Owner: Adam (Lane 3). Builder: Claude
Code (lead) with subagents. Silent run: no messages; status lives in this file, the board, the log
and the review page.

## Authority (task-scoped; does not change [[lane3-delegation]])

- "Approved: autonomously build the isolated HUD prototype and three Downtown visual studies
  described here, make reversible presentation decisions, run verification, use subagents,
  commit this task's changes, push its feature branch, and open one draft PR. Do not merge or
  publish an experience. Asset-upload permission is limited to the original images specified
  below."
- One-night UI preview exception: Studio-first, unapproved visual prototypes in the two task
  places only (typography, touch sizes, screens, icon art, motion). Not a production approval;
  does not change the Figma-first workflow ([[0012-figma-ui-workflow]]); no Downtown direction is
  selected.
- Does NOT approve Island Rework Task 3 (still waiting for "Approved: island rework").
- Uploads: original images under peskaface only, kept Restricted where the setting allows;
  mesh imports that need a click stay pending.

## Existing approvals that win (read 2026-10-22)

- Run HUD revision 4 approved 2026-10-20 ([[visual-direction]]): Cash top left, Distance top
  centre (option B, flag + outlined number), Heat bottom centre (ENGINE HEAT panel,
  [[0008-heat-critical-meltdown]]), ScreenInsets CoreUISafeInsets, scale = short side / 390
  clamped 1.0–1.5, Fredoka One 36/24/18/16, touch 48/56, Reduce Motion = GuiService plus the
  preview-only override, Cash format (Format.cash, truncating, three significant digits).
- Conflict C1: the prompt puts Heat at top left as a segmented bar during a run, replacing Cash.
  The approved layout keeps Heat bottom centre. Resolution: the approved layout is the default in
  the prototype; the prompt's segmented top-left Heat bar is built as a labelled PROPOSAL variant
  (toggle), not a replacement. Adam chooses.
- Conflict C2: the outline's Downtown look says "Lots of 90-degree shapes"; direction A asks for
  softened facades. Both are shown; A keeps rectilinear massing with soft trims (recorded).

## Requirement ledger

Status: planned → built → tested (Studio) / rendered (Blender) / code-checked / blocked / not done.
Owners: L = lead, H = HUD workers, D = Downtown workers, R = reviewers. Evidence paths are under
`Car-Hop-Art/review/hud-downtown/` unless noted.

| ID | Requirement (prompt section) | Owner | Depends | Acceptance evidence | Status |
|---|---|---|---|---|---|
| HD-01 | Silent run; files only (§1) | L | — | no messages; review page on disk | done |
| HD-02 | Isolated worktree from origin/main, branch feature/lane3-hud-downtown-lookdev (§2) | L | — | `git worktree list` | done |
| HD-03 | Board claim (§2) | L | — | main 6309e5a | done |
| HD-04 | Ledger + plan in files (§2) | L | — | this file | done |
| HD-05 | Four bounded research notes (§4, §5) | R | — | vault/design/research/*.md | done |
| HD-06 | Synthesis: preserved / new / excluded / implications (§5) | L | HD-05 | section "Synthesis" here | done |
| HD-07 | Preview bootstrap requires Studio AND a playground config; production entrypoints never load it (§3) | L | — | code + leak test | built, code-checked; integration review passed the gate (review-integration-1.md) |
| HD-08 | Preview adapters + fixtures; proposed interfaces documented (§3) | L | — | "Interfaces" here | built (proposed interfaces below) |
| HD-09 | State store, modes, event dedupe (§10) | L | — | Store.luau + tests | built |
| HD-10 | Shared motion vocabulary + reduced motion live (§7) | L | — | Motion.luau + video | built |
| HD-11 | Typed UI sound hooks via preview SoundGroup (§7) | L | — | Sounds.luau | built |
| HD-12 | Virtual device screens: desktop, phone L/P, tablet with insets and reserved zones (§6) | L | — | Screen.luau + captures | built, Studio-tested (layout emulation, not devices) |
| HD-13 | Cash + earning line: icon fixed, number grows right, formats, exact value 2 s, gain/spend chips, coalescing, big-gain policy (§8) | H1 | HD-09 | video gains/spends | built, Studio-tested (video) |
| HD-14 | Left menu: Garage/Index, Shop, Missions, Settings; badges 0/1/many; long labels; reflow (§8) | H1 | — | captures 4 sizes | built, Studio-tested |
| HD-15 | Tutorial banner, states, completion, chevron route; toasts (max 2, 2.5 s, queue, merge) (§8) | H1 | — | video | built, Studio-tested (video) |
| HD-16 | Lap Pay billboards from fixture cars (≤120 studs, 1.2 s, capped) (§8) | H3 | — | video | built, Studio-tested (video; billboards not in MCP stills) |
| HD-17 | Custom prompts on dummy Garage/kiosk/portal: keyboard, touch, gamepad cues, hold (§8) | H3 | — | captures | built, Studio-tested (stills: keyboard, gamepad, touch-hold) |
| HD-18 | Car card: rarity frame/label/pips, family icon, quirk, ViewportFrame turn, static mode, all states (§8) | H2 | — | card sheet | built, Studio-tested (proxy cars) |
| HD-19 | Settings panel: music/SFX volume, reduced motion, close/back, focus return (§8) | H1 | HD-11 | video | built, Studio-tested (video) |
| HD-20 | Mocks over gameplay: Garage, Portal card, Welcome Back, Shop (price pending) (§8) | H2 | HD-18 | captures | built, Studio-tested (video) |
| HD-21 | Run adapter: distance, coins, heat/stage, ride, keys, hop, dash, milestones, run end (§9) | L | HD-09 | adapter + docs | built (synthetic adapter) |
| HD-22 | Distance top centre (approved option B) + coins secondary (§9) | H3 | — | captures | built, Studio-tested |
| HD-23 | Heat: approved panel (default) + segmented top-left PROPOSAL variant; low/mid/near-full/rapid (§9, C1) | H3 | — | captures + video | built, Studio-tested (both variants) |
| HD-24 | Current ride chip top right under options (no pause implied) (§9) | H3 | — | captures | built, Studio-tested |
| HD-25 | Keys ring lower centre, HOLD ON, pending vs confirmed (§9) | H3 | HD-21 | video | built, Studio-tested |
| HD-26 | Confirmed capture celebration; compact ribbon if landing area covered; deferred card (§9) | H3 | HD-18 | video | built, Studio-tested (card desktop, ribbon phones) |
| HD-27 | Already-owned: JOYRIDE BONUS (corrected 2026-10-22: the GDD marks the Joyride Bonus Decided; first draft wrongly said not in live design) (§9) | H3 | — | capture | built: JOYRIDE BONUS, synthetic +$50 (GDD: decided) |
| HD-28 | Hop ring world treatment (available/unavailable/timing) + phone Hop button, cooldown sweep, preview intent only (§9) | H3 | — | video | built, Studio-tested (desktop/phone); phone Timing/cooldown not captured |
| HD-29 | Foot Dash arc + DASH cue; milestones (§9) | H3 | — | video | built, Studio-tested (video) |
| HD-30 | Results: rows, NEW BEST, claimed cars, count-up, RETRY/GO HOME, no rewards / many / long names, scroll, skip, no double transitions (§9) | H2 | HD-18 | video | built, Studio-tested (video) |
| HD-31 | Stunt Circuit mock (§9) | H2 | — | capture | built, Studio-tested (video) |
| HD-32 | Playground: fixture selector, scripted playback, hide controls, reset (§10) | L | all H | video | built, Studio-tested |
| HD-33 | Edge cases exercised (§10 list) | L | HD-32 | test log | partly: rapid gains, mode change, reduced motion mid-effect, repeated Retry, extreme balances, long names, empty results exercised; respawn, orientation change, badge 99+ not exercised |
| HD-34 | Frame times: representative vs stress, warm-up, sampling; host vs device (§10) | L | HD-32 | table | done (desktop host only; devices unverified) |
| HD-35 | Four device layouts inspected: clipping, hitboxes, safe areas, thumb zones, contrast (§10) | L | HD-12 | table + captures | partly (4 profiles captured; reserved-zone overlay on phone landscape) |
| HD-36 | Figma candidate frames or "Figma transfer and owner approval pending" (§2) | L | — | figma-reads | pending: Figma transfer and owner approval pending |
| HD-37 | Downtown common fixture: same road, camera path, car scale, hazards (§11) | D | — | fixture spec | done (spec) |
| HD-38 | Study A Sunny Toy City incl. donut bakery (§11) | D | HD-37 | renders + Studio | built, Studio + Blender |
| HD-39 | Study B Bright Real City incl. corner theater (§11) | D | HD-37 | renders + Studio | built, Studio + Blender |
| HD-40 | Study C Big Bright Metropolis incl. elevated train (§11) | D | HD-37 | renders + Studio | built, Studio + Blender |
| HD-41 | ≥4 original business signs per direction; construction group, pothole, oil slick (§11) | D | — | captures | built (6-7 signs per direction) |
| HD-42 | Ambient accents, bounded, reduced-motion aware (§11) | D | — | video | built (Ambient.luau; edit-mode run only) |
| HD-43 | Blender recipes in safe mode / headless, modular kit, palette strategy (§11) | D | — | assets/downtown | built (headless Blender, no MCP) |
| HD-44 | Per-direction costs and moving-camera frame times (§11) | L | HD-38..40 | table | done (edit-mode chase pass; Play not measured) |
| HD-45 | vault/design/downtown-plan.md production plan (§12) | L | HD-38..40 | file | done |
| HD-46 | Fresh HUD, Downtown and integration reviews; fixes; rechecks (§13) | R | all | review files | done: HUD, Downtown and integration reviews written; fixes and rechecks listed on the review page |
| HD-47 | Checks, places saved, lock released, helpers stopped, board/log/ledger/decisions, commit, push, one draft PR (§14) | L | all | git | see review page |
| HD-48 | One local review page + Markdown fallback, sections 1–10 + the tested/read answer (§14) | L | all | index.html | done |

## Plan (short)

1. Core prototype modules (lead): PreviewTokens, Motion, Sounds, Store, Screen, Gloss — done.
2. Fan out: H1 home HUD, H2 cards/mocks/results, H3 run HUD + world feedback + prompts; D1
   Blender city kit + renders; D2 Studio look-dev builder. Workers write only their own folders.
3. Lead: playground bootstrap + adapters + scenarios; build places with `rojo build`; open in
   Studio; test, capture, record; fix.
4. Reviews (HUD, Downtown, integration) → fixes → rechecks.
5. Handoff, PR, review page.

## Interfaces (proposed, not agreed)

The prototype reads one display state (src/client/UI/Prototype/Store.luau) filled by preview
adapters from synthetic fixtures (playground/hud/scripts/Scenarios.luau). For production these
would be supplied by the owning lanes; nothing below is agreed, and the HUD never computes or
grants any of it. No outgoing teammate messages were sent; this is the draft for the board.

| Field / event | Type and unit | Optional | Lifecycle | Authoritative owner |
|---|---|---|---|---|
| cash | whole dollars, server balance | no | replicated on join and on every change | Brian L (Lane 2) |
| CashGain / CashSpend event | { id, amount (dollars), worldPosition? } | worldPosition optional (only when a real world source exists) | fired once per server-confirmed change; id unique per change (dedupe) | Brian L |
| earningPerLap | dollars per lap (rate, units and formula TBD) | yes | while on the island | Brian L |
| garage { owned, total, unseen } | counts | unseen optional | replicated; unseen cleared when viewed (client request) | Brian L |
| missionsClaimable | count of earned free claims | yes | replicated | Brian L |
| tutorial { step, steps, objective, count, goal, hint?, state } | strings and counts | hint optional | replicated per step | onboarding owner (TBD; Lane 2 likely) |
| Toast event | { id, text, tone: Success / Info / Unlock } | — | fired by the owning system; dedupe by id | each owning lane |
| run.distance | metres (Lane 1 unit; studs and metres not interchangeable) | no | 10 Hz is enough for display | Brian R (Lane 1) |
| run.coins | count | no | on change | Brian R / Brian L |
| run.heat, run.stage | 0..1; Calm / Warning / Critical / Meltdown | stage optional (HUD derives Calm/Warning/Critical, never Meltdown) | on change | Brian R |
| run.ride | car id → CarRef display data | no | on hop | Brian R (who is ridden), Brian L (car data) |
| run.keys { target, progress, status } | car id; 0..1; Holding / Pending / Confirmed / Lost | while a claim is possible | progress 1 alone is NOT ownership; Pending until the server confirms | Brian R (hold), Brian L (ownership) |
| KeysConfirmed event | { id, car } | — | exactly once per confirmed claim; dedupe by id | Brian L |
| AlreadyOwned event (Joyride Bonus) | { id, car, amount? } (amount in dollars, server-computed) | amount optional: without it the note says "Already in your Garage" | once per claim on an owned car; each traffic car instance pays once (outline) | Brian L |
| run.hop, hopCooldown01 | Available / Unavailable / Timing; 0..1 | — | on change; HUD never picks a target or judges a landing | Brian R |
| Hop intent (from the Hop button) | a client request with no arguments | — | the server validates everything | Brian R |
| run.dash | remaining 0..1 | nil when not dashing | on change | Brian R |
| Milestone event | { id, text } | — | once per milestone | Brian R |
| results { distance, coins, best, newBest, claimed, earnings, joyride?, milestones? } | metres, counts, dollars, car ids; joyride in dollars; milestones a count | claimed may be empty; joyride/milestones optional | once at run end; the HUD shows it, never computes it | Brian R + Brian L |
| Lap Pay feedback | { carPart, amount } | — | once per server-paid lap; capped and combined on screen | Brian L |

Car card data needed from Brian L: canonical id, display name, rarity, variant, family, quirk,
model reference and its bounding size (for camera fit and consistent scale).

## Synthesis of the research (HD-06)

Notes: [[hud-ref-roblox-ui]], [[hud-ref-mobile-racing]], [[hud-ui-engineering]],
[[downtown-ref-environment]] (sources, dates and observation/inference split are in each).

- **Preserved from approved references** (`vault/design/references/`, approved HUD rev 4):
  floating icon + number with no panel for Cash; heavy rounded numerals and a strong dark
  outline; saturated colour per element; chunky original icons that may overhang a button edge;
  the yellow top-centre tutorial banner with a tab and inline counter; a confirmation line under
  it; ground chevron trails; Cash top left, Distance option B top centre, ENGINE HEAT bottom
  centre; the approved Cash format, font sizes, touch targets, scale rule and Reduce Motion rule.
- **New inspirations (all preview proposals for Adam):** word labels under menu icons; a thin
  progress strip on the banner; one-sentence toasts coloured by category (never red); a muted
  earning line under Cash; an in-world Hop target ring as the main hop cue with teal reserved for
  Hop; gauges in the gap between the thumbs and controls in the corners; state shown on the car
  for captures (ribbon) rather than a blocking card; a segmented top-left Heat bar (C1 variant).
- **Deliberate exclusions:** no red badge on Shop or for urgency; no equal-weight Robux prices,
  paid boost rows, timers, streaks, "limited" or offers on Results; no copied logos, icons,
  fonts, layouts, cars or characters; no strobe, shake or full-screen flash; nothing in the
  lower-centre landing view; no night setting, real brands, emergency vehicles or boardwalk in
  Downtown.
- **Implementation implications:** one ScreenInsets application (the virtual device frame
  applies assumed insets once; production uses CoreUISafeInsets and never adds GetGuiInset);
  UIScale per widget root, no UIStroke thickness tweens; gradients built once; small fixed
  CanvasGroups only; ViewportFrames limited (≤ 6 spinning, one shared ticker, explicit
  Ambient/LightColor/LightDirection, no shadows or post); custom ProximityPrompt UI via
  PromptShown/Hidden and hold events; reduced motion has no change signal, so it is polled at
  0.5 s plus the override attribute; Fredoka One confirmed, BuilderSans as the readable label
  candidate. Downtown: three depth bands, quiet facades near gameplay elements, base/middle/top
  modules on a 12-stud bay, palette swaps over one shared swatch layout, hazards contrasted
  against shadow (oil glossy with a sheen ring).
