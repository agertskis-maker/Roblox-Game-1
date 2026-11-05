# 0040: Beta driving update: Brian R's newest run in the beta, the Stamina Shop, Brian L's cars on the road

Date: 2026-11-05. Owner: Adam (Lane 3, repository owner, beta integration person).
Status: decided by Adam in chat on 2026-11-05 (quoted below); build choices are Claude's and are listed in [[beta-driving-update-ledger]].
Branch `integration/beta-driving-update` (from `integration/beta-2`). Handoffs: [[beta-driving-update-for-brian-r]], [[stamina-shop-for-brian-l]].

## What Adam decided

1. **Base.** The update is built from `integration/beta-2` (Round 5 and its run bridge), not `integration/beta-1` or `integration/beta-3`. Brian L's `Lane2EconomyPreview` stays off for this publish.
2. **Brian R's run joins the Round 5 bridge** with an adapter outside `src/client/Run` and `src/shared/Run`. His files are not edited.
3. **The Rider Level "Needs" gate is not at launch.** It is switched off in the beta from outside his files (session level 999, his "Needs" tag lines and the "Rider Level" corner label hidden).
4. **Stamina.** 5 bolts by default, 1 bolt per hop. A Stamina Shop where the player buys more: 10 levels, prices rising exponentially and in line with the rest of the economy (PREVIEW). Adam approved the saved field and the prices: "Approved, go ahead", and "10 bolts". Publish once, with the shop. No Figma mockup for this panel ("Skip Figma").
5. **Bolt colours.** To declutter the board: a red bolt counts as 2 bolts and a hop takes half of it; a purple bolt counts as 3. Special effects round the bolts; the shop should look cool.
6. **Placement.** The Stamina Shop stands in the World hubs (the Launch Pads) before a run, not on the main island: "if u need to move some things around to make it look not awkward then do it but just relocate it". The bolt on top should look like a real lightning bolt.
7. **Fixes asked for:** Raceway cars ran backwards and floated; the tutorial Park arrow covered the button that parks the cars; the HOME portal in the hubs should face the centre; coming back to the island put the player inside the floor; the run's road cars should be Brian L's cars, not the placeholders.
8. **Publish** to the private Car Hop Beta place (118605678346800) only. Adam confirmed the overwrite on 2026-11-05 after being told the place had changed on 2026-11-04.

## Why

- The beta is where the team plays the whole loop; Brian R's easier Circuit and better Hop should be felt there, paid through the same bridge.
- A Stamina upgrade gives a long-term goal that is earned with in-game Cash only (no Robux, no paid luck, no timers), which suits a mostly young audience.

## Limits recorded

- `StaminaLevel` is a beta-only save field, not an Agreed field. Brian L decides whether it becomes one ([[stamina-shop-for-brian-l]]).
- The road-car dressing, the pop-up renaming and the owned-list seeding are adapters around Brian R's run. They are deleted when his run spawns Brian L's cars itself.
