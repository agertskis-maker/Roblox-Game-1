# Worked example (validation case)

Illustration only. It does not approve the egg concept or any rule below.

## Input (excerpt of a ChatGPT-written prompt)

> Build the Rain Region egg loop. Players grab eggs from nests and carry them
> back to their base. Other players can steal eggs you are carrying. Owned
> progress is always safe and nothing a player earns can ever be lost. Add a
> shiny rainbow egg that costs 50 Robux for better luck. The shop should feel
> like Grow a Garden.

## Expected intake output (abridged)

Player outcome: a player braves the rain, grabs an egg, and feels tension
carrying it home; reaching the base feels like relief and reward.

| ID | Requirement | Req/Opt | Acceptance evidence | Status |
|---|---|---|---|---|
| R1 | Server grants an egg claim from a nest to one player | Required | Two clients claim the same egg; exactly one wins | open |
| R2 | Carried egg is banked on reaching the base | Required | Runtime test: carry, enter base, inventory +1 | blocked by Q1 |
| R3 | Other players can steal a carried egg | Required | | blocked by C1 |
| R4 | Paid "rainbow egg" improves luck | Optional | | blocked by Q2 |
| R5 | Shop visual style references Grow a Garden | Optional | Visual review vs approved reference | needs reference image |

Contradictions:
- C1: "Other players can steal eggs you are carrying" vs "nothing a player earns
  can ever be lost". Blocks R3 and the save rule for R2.

Questions:
1. Is a carried, unbanked egg "earned"? If no: stealing only affects unbanked
   eggs and saves stay simple. If yes: stealing conflicts with the safety
   promise and needs a recovery rule.
2. Paid luck is blocked (stated as a constraint: it needs an approved team
   design and current Roblox policy, and none exists). Do you want a proposal
   drafted (player benefit, cost, risk, test) for the team to approve? If not,
   R4 is deferred. If yes, it also needs disclosed odds and per-player
   eligibility checks before any build.
3. Which Grow a Garden screens should the shop resemble? Please attach images.

Concept check: this belongs to candidate C (storm-region eggs), which the team
has not selected: `GDD.md` says `concept: undecided` and no selection decision
note exists. The bare "Build" gets this intake and then a plan; no feature
build until the concept is selected. The ProfileStore lifecycle module is
listed as a separate concept-agnostic foundation (F1) that may start, with its
own plan and go-ahead because it touches saved data.

Choices I made: ledger IDs, file placement for the eventual spec.

First slice (conditional plan, once the concept is selected and Q1 is
answered): one nest, one egg type, claim, carry, bank, inventory count,
verified with two clients. What happens once each answer arrives: Q1 answered
unbanked-only → stealing becomes a propose-first item; Q2 answered "draft a
proposal" → the paid-luck proposal is presented; Q3 answered with images → hand
the shop to visual direction. No implementation until the preconditions are met. Deferred: stealing (needs Q1),
paid eggs (needs Q2), shop styling (needs references).

## Pass criteria for this example

The output keeps every requirement, flags C1 with both quotes, asks every
question whose answer changes the result in one batch with no fixed cap, asks
nothing the project rules already settle (paid luck is a stated constraint, not
a question) and nothing that is a reversible detail, refuses to start building
an unselected concept, lists the ProfileStore lifecycle module as a separate
foundation instead of building it or folding it into the slice, gives the first
slice as a conditional plan (what happens once each answer arrives), does no
implementation, and treats the missing reference images as missing.
