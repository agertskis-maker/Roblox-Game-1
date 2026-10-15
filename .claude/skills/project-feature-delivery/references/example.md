# Worked example (validation case)

Illustration of the delivery shape, using a neutral feature that does not belong
to any candidate concept. Not a request to build it.

## Input

"Approved: add a 'Claim daily coins' button. Once every 20 hours, the player
gets 100 coins. Show a countdown when it's not ready. Save the last claim time."

## Expected delivery plan (abridged)

Approval: the "Approved:" line clearly refers to this request, so it counts as
approval of the request. It does not select a concept; none is selected
(`GDD.md` still says `concept: undecided`). Board claim added (a row under In
progress) when work starts, after the go-ahead. `git status` clean in `src/`.

Foundation: no player-data module exists, so the board's "Build the player data
module on ProfileStore" task becomes the first increment (its own claimed item,
unless a teammate owns it), with a minimal template and no concept-specific
fields. It is a foundation, so it may proceed before the concept is chosen.

Propose first: coins would be the project's first currency, and
`LastDailyClaim` is part of that currency's reward, so both are propose-first,
not foundations. Before any coin or claim code, present player benefit, cost,
risk, and a way to test it. The earlier "Approved:" does not satisfy the rule
because it came before that presentation. Record the outcome as a decision
note. One later reply such as "Approved, go ahead" may grant the approval and
the plan go-ahead together.

Plan posted before coding: request lines covered, files to create or change,
checks to run. The work touches saved data and the economy, so delivery waits
for an explicit go-ahead after posting. The gates stack: even increment 0, the
foundation module, touches saved data and waits for the go-ahead.

Contract (draft, applied only after the currency is approved):

| Remote | Direction | Arguments | Server validation | Result | Rate limit |
|---|---|---|---|---|---|
| `DailyReward.Claim` | client to server (RemoteFunction or event + reply) | none | profile loaded; now >= lastClaim + 20h | `{ok, nextClaimAt}` or `{ok=false, reason}` | 1 per 2 s |

Server computes the 100 coins and the time; the client never sends an amount
or a timestamp. Data: `Coins: number` (default 0), `LastDailyClaim: number`
(default 0, server `os.time()`), added to the template only after approval;
Mock test covers new player, ready, not ready, and double request.

Client states: loading (profile not ready), ready (button enabled), pending
(button shows spinner, ignores repeat taps), success (coin pop, value ends on
the server number), not ready (countdown from server `nextClaimAt`), rejected
(message, refreshes state).

Failure rows filled: double tap → one grant; clock skew → server time only;
leave during claim → grant saved or not granted, never half; save failure →
ProfileStore session rules.

Increments: (0) ProfileStore lifecycle module with minimal template and Mock
test; (1) server claim + Mock test; (2) button with all states; (3) polish:
coin animation, sound, reduced motion.

Then: `check.ps1`, Studio verification, handoff.

## Pass criteria

The one-line approval is accepted as referring to this request but does not
select a concept; a short plan (request lines, files, checks) is posted before
any code; delivery waits for an explicit go-ahead because saved data and the
economy are touched, including for the foundation module (gates stack);
`LastDailyClaim` is treated as part of the propose-first currency, not as a
foundation field; the new currency is
presented with benefit, cost, risk, and a test and is not treated as approved
by the earlier line; the missing data module becomes the first increment with a
minimal template instead of a second save path; amounts and time are
server-only; every remote argument is validated; all client states are listed;
the failure table is filled with outcomes; increments are playable.
