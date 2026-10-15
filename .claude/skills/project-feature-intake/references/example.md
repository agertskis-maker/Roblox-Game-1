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
2. Paid luck: has the team approved monetization? If not, R4 is deferred. If
   yes, it needs current Roblox paid-random policy, disclosed odds, and
   per-player eligibility checks before any build.
3. Which Grow a Garden screens should the shop resemble? Please attach images.

Concept check: this belongs to candidate C (storm-region eggs), which the team
has not selected. Intake only; no build until the concept is chosen.

Choices I made: ledger IDs, file placement for the eventual spec.

First slice (once approved): one nest, one egg type, claim, carry, bank,
inventory count, verified with two clients. Deferred: stealing (needs Q1),
paid eggs (needs Q2), shop styling (needs references).

## Pass criteria for this example

The output keeps every requirement, flags C1 with both quotes, asks no more than
three questions, refuses to start building an unselected concept, and treats the
missing reference images as missing.
