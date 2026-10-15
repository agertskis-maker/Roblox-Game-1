# Dated Roblox research and policy notes

Checked October 15, 2026. This is a sourced background note, not a live leaderboard, legal opinion, or account eligibility determination. Reopen official sources before a decision that depends on current rules. Design recommendations below are our inferences, not proven causal explanations of commercial success.

## Popular-game reference evidence

Roblox's official charts search result retrieved during this research listed Grow a Garden and Steal a Brainrot. The directly opened charts page provided no usable ranking table. Therefore this pack does not assert an exact current rank or player count. The games are supported as relevant reference examples, with official historical evidence of substantial prominence; a fresh live ranking comparison remains a separate task.

Source: [Roblox charts](https://www.roblox.com/charts). Historical context: [Roblox's 2025 Replay](https://about.roblox.com/newsroom/2025/12/roblox-replay-decoded-search-style), which describes both games as major 2025 hits. Historical prominence is not a forecast for our project.

### Grow a Garden

**Observed from its official listing:** players buy seeds, plant them, wait for growth, harvest for profit, and show discoveries to friends. The description says growth continues offline. [Official game listing](https://www.roblox.com/games/126884695634066/Grow-a-Garden).

**Design inference:** a concrete, easily explained activity reduces onboarding burden; an evolving owned space makes progress visible; discoveries support self-expression; returning can reveal a changed state. These are plausible useful patterns, not evidence that any single mechanic caused its popularity.

**Application proposals:** show growth milestones clearly in the size concept; show a creature collection in a habitat if the monster concept is selected; make storm-region discoveries visibly distinctive. Any offline reward system would need separate approval and economy design.

### Steal a Brainrot

**Observed from its official listing:** purchase or steal collectible characters, generate money, rebirth, and use equipment for player interaction. The listing names desktop, mobile, and tablet support. [Official game listing](https://www.roblox.com/games/109983668079237/Steal-a-Brainrot).

**Design inference:** visible valuable objects and opposing intentions can create understandable social stories. A contested object can generate a memorable moment without a long narrative. The same structure can create frustration, so it is not a universal recommendation.

**Application proposal:** if the egg concept includes competition, test a bounded contest over unbanked resources with clear protection and recovery rules. Do not assume permanent loss, paid theft, or newbie harassment is necessary for tension.

### Unresolved references

The user's “Steal an Egg” reference and “Bubble Gum Sim or something” reference are not uniquely identified. Request the exact game link before making factual claims about their current mechanics. Their role here is to express interest in egg collection, hatching, and visible advancement.

## What platform discovery suggests

Roblox's June 15, 2026 announcement describes expanding recommendation signals toward a 28-day view and emphasizes long-term retention, co-play, and spend as indicators of player value. It does not promise traffic to games that copy a particular loop. [Official discovery announcement](https://about.roblox.com/newsroom/2026/06/optimizing-discovery-great-games-reach-millions-players-roblox).

Our recommendation: prioritize a satisfying repeatable interaction, understandable progression, and enjoyable social play. Use honest thumbnails and a first session that delivers their promise. Treat analytics as evidence for iteration; do not equate forcing longer sessions with improving enjoyment. Revenue is not a justification for confusing or pressuring young players.

## Publishing: correction to the 250-player assumption

The current support guidance says new games in the evaluation process initially reach age-checked users 16+. It describes a typical threshold of **250 unique plays by highly engaged, age-checked users within 60 days**, not 250 concurrent players. Qualifying engagement is evaluated; not every visit counts. All-ages release also has creator, rating, and evaluation requirements. The game/group owner's actual status must be checked in Creator Hub's Eligibility/Audience Reach interface. Meeting a count does not by itself prove the game is available to children.

Sources: [How to Publish Games on Roblox](https://en.help.roblox.com/hc/en-us/articles/203313890-How-to-Publish-Games-on-Roblox) and [Creator Hub publishing documentation](https://create.roblox.com/docs/production/publishing/publish-games-and-places). Fees, alternative review routes, and thresholds can change; verify them before planning or spending. This pack has not inspected your account eligibility.

## Paid randomness and luck

Roblox's policy covers random items obtained directly or indirectly through Robux, including paid currency and probability modifiers. It requires disclosure of possible outcomes and actual numerical odds and describes per-player restrictions using PolicyService. Breeding, paid luck, and eggs can fall within this review depending on how payment connects to the outcome. Recheck the exact design against the full current policy before implementing it. [Official paid random items guidelines](https://create.roblox.com/docs/production/monetization/paid-random-items).

Our production recommendation: prefer transparent, understandable offers; keep free-play progression satisfying; avoid fake scarcity, misleading odds, and repeated purchase interruptions. If paid randomness is selected, document eligibility, effective odds, modifier behavior, server enforcement, and an appropriate unavailable state. Do not assume that renaming a paid currency or selling a luck boost removes the policy issue.

## Research discipline for future prompts

For a new reference game, record the exact title/link, date, evidence source, and what was directly observed. Separate its visible mechanics from explanations of popularity. Compare normal play with special events rather than presenting a record event peak as a normal daily audience. Visits, concurrent players, unique users, retention, and revenue are different measures.

Use official Roblox documentation for API/policy claims. If a page is inaccessible, say so. Do not substitute forum speculation for a confirmed rule. Search snippets can identify leads but should not become precise numerical claims without sufficient verification. Avoid treating a page's generic “no running experiences” fallback as proof that a game has no players.

Refresh this note before launch, monetization work, or any decision that depends on present-day popularity. Keep the checked date attached to every snapshot.
