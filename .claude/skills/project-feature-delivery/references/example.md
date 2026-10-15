# Worked example (validation case)

Illustration of the delivery shape, using a neutral feature that does not belong
to any candidate concept. Not a request to build it.

## Input

"Approved: add a 'Claim daily coins' button. Once every 20 hours, the player
gets 100 coins. Show a countdown when it's not ready. Save the last claim time."

## Expected delivery plan (abridged)

Preconditions checked: approved by owner in this message; board task claimed;
`git status` clean in `src/`; no player-data module exists yet, so the board's
"Build the player data module on ProfileStore" task is a dependency. Delivery
pauses to ask whether to build that module first or whether a teammate owns it.

Contract:

| Remote | Direction | Arguments | Server validation | Result | Rate limit |
|---|---|---|---|---|---|
| `DailyReward.Claim` | client to server (RemoteFunction or event + reply) | none | profile loaded; now >= lastClaim + 20h | `{ok, nextClaimAt}` or `{ok=false, reason}` | 1 per 2 s |

Server computes the 100 coins and the time; the client never sends an amount
or a timestamp. Data: `Coins: number` (default 0), `LastDailyClaim: number`
(default 0, server `os.time()`), added to the template; Mock test covers new
player, ready, not ready, and double request.

Client states: loading (profile not ready), ready (button enabled), pending
(button shows spinner, ignores repeat taps), success (coin pop, value ends on
the server number), not ready (countdown from server `nextClaimAt`), rejected
(message, refreshes state).

Failure rows filled: double tap → one grant; clock skew → server time only;
leave during claim → grant saved or not granted, never half; save failure →
ProfileStore session rules.

Increments: (1) server claim + Mock test; (2) button with all states;
(3) polish: coin animation, sound, reduced motion.

Then: `check.ps1`, Studio verification, handoff.

## Pass criteria

Server-only amounts and time; every remote argument validated; dependency on the
data module surfaced instead of quietly creating a second save path; all client
states listed; failure table filled with outcomes; increments are playable.
