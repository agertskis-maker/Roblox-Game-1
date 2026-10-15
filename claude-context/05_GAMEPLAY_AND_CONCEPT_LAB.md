# Gameplay principles and tentative concept lab

All concepts below remain candidates. Enhancements are proposals from this pack, not approved requirements. Do not blend the three into a single project by default.

## Common design questions

State the player's fantasy in one sentence. Identify the repeated action, the immediate feedback, the meaningful choice, the reward, and the next goal. Explain why repeating the action remains interesting after the novelty wears off. A reward schedule cannot rescue an interaction that feels bad.

Design a first session that teaches through a successful action, reveals a near-term improvement, and shows a desirable future possibility. Initial playtest hypotheses might be: the player understands the action within 30 seconds, receives a meaningful first success within 60–90 seconds, and identifies their next goal within three minutes. These are proposed test targets, not industry benchmarks or a requirement to interrupt the player with tutorials.

Provide short, medium, and long goals with different kinds of payoff. Expand choices or expressive possibilities rather than only multiplying prices. Make friends relevant through showing, comparing, helping, or competing as the concept supports. Do not require a populated server before a new player can enjoy the basic loop.

## Candidate A — visible growth through eating

**User's seed:** begin by eating something small, perhaps a cow, then grow toward settlements, worlds, and ultimately cosmic-scale targets. Becoming visibly larger than other players is a major part of the appeal. Exact sequence and theme are unconfirmed.

**Candidate loop:** find a valid target, consume it, gain server-calculated growth, visibly evolve, and unlock a new scale of environment. Decide whether the fun is route optimization, movement skill, collection, competition, destruction spectacle, or some deliberate combination.

**Potential signature:** a scale transition reframes the familiar world. A former landmark becomes a small prop; the player reaches a new horizon with a transformed silhouette and sound palette. This is more expressive than merely increasing a number beside the same avatar.

**Functional realization:** use bounded playable size tiers, controlled camera changes, and appropriately scaled environments. Cosmic fantasy can be represented through staged scenes, miniatures, or separate progression spaces; it does not require a literal universe-sized physics simulation. Validate the chosen approach before committing. Do not assume teleportation or multiple places are necessary.

**Questions before building:** Can players consume other players? Are consumables shared or personal? What happens when two players claim the same object? Does growth reset? What is the collision/camera limit? Is the tone cartoonish absorption or destruction? Who owns the visual assets for each scale?

**First slice:** one small environment, a handful of target classes, one growth threshold, and a satisfying transformation. Test navigation before and after growth, target eligibility, contested claims, visibility around other players, and whether players immediately want the next tier.

**Failure to avoid:** exponential stat escalation with no new play, huge avatars trapping others, camera clipping, expensive destruction fragments, and excessive content demands for every size tier.

## Candidate B — monster breeding, income, battles, and worlds

**User's seed:** breed monsters to produce better monsters that earn more money, battle, catch monsters in different worlds, level up, and potentially include luck mechanics and game passes.

**Candidate loop:** obtain a creature, choose how to use or develop it, earn resources, make a meaningful breeding or upgrade decision, and pursue a new discovery. Choose the core first: collection, breeding strategy, combat, or production. All four at launch would create substantial interconnected scope.

**Potential signature:** offspring visibly express a small, understandable combination of parent traits, with a reveal that celebrates an actual new form. A habitat reflects the player's collection and gives creatures recognizable behavior. Propose a bounded trait system before promising arbitrary combinations.

**Functional realization:** use stable species IDs, constrained inheritance rules, a manageable visual library, and server-determined outcomes. Cosmetic modularity and mechanical traits can evolve separately. Preserve space for future content without designing an unlimited genetics engine upfront.

**Questions before building:** Are parents consumed? Can breeding fail? Are results deterministic or random? How do duplicates remain useful? Is combat active, turn-based, or automatic? Does income accrue offline, and under what cap? Can creatures be traded? Which features are paid, and do payments affect random outcomes?

**First slice:** a few creatures, one clear acquisition method, one breeding interaction, and one useful outcome. If combat is the central fantasy, replace peripheral breeding depth with one complete battle first. Test whether the player understands why the outcome happened and what to do next.

**Failure to avoid:** combinatorial art scope, an economy that compounds beyond all sinks, paid luck without proper disclosure/restrictions, duplicate creatures with no purpose, and trading added before ownership consistency is solved.

## Candidate C — eggs across storm regions

**User's seed:** strength unlocks or helps traverse increasingly difficult weather areas such as rain, snow, and hail. Each region has different eggs to collect and hatch, with a possible stealing element. The exact target of theft is unresolved.

**Candidate loop:** prepare, enter a region, navigate its hazard, secure an egg, return or bank it, hatch it, and improve the ability to reach another region. Keep the danger legible and the route choice meaningful.

**Potential signature:** each storm has a recognizable movement challenge and a distinctive egg presentation. A return journey with a valuable unbanked egg produces tension; reaching shelter gives relief and a strong reward moment. This interpretation is a proposal, not confirmation that eggs are carried or can be lost.

**Functional realization:** strength can influence a bounded movement or resistance parameter while local visuals create the weather. Server logic validates eligibility and hazard outcomes. Regions need distinct decisions rather than only different particle colors. A safe hub can showcase hatched discoveries if the team approves that structure.

**Questions before building:** Are eggs stolen from NPC nests, neutral spawns, or other players? Is theft temporary or permanent? Does carrying an egg change movement? Can stronger players grief weaker ones? What happens on death, leaving, server shutdown, or a full inventory? Does strength remove challenge entirely or open new options?

**First slice:** a safe area, one hazard region, one egg acquisition, one return or banking rule, and one hatch outcome. Test threat readability, success/failure recovery, duplicate claims, latency, and repeated trips on a phone.

**Failure to avoid:** unreadable storm effects, client-controlled rewards, high-strength players bypassing all interesting play, permanent loss rules introduced accidentally, and generic hatching disconnected from the storm fantasy.

## Choosing on Sunday

Compare the concepts on the strength of their first playable interaction, distinctiveness, ability to communicate the fantasy in a short clip, content workload, multiplayer complexity, asset needs, and how quickly the team can test its biggest uncertainty. Have each teammate explain what they would enjoy actually doing for ten minutes, not just what systems sound exciting on paper.

Record a one-sentence pitch, a first slice, the intended audience/devices, a signature moment, and what is explicitly deferred. Do not assign fake numerical scores without evidence. If the team remains split, a small prototype of the uncertain interaction can provide more useful evidence than a longer feature list.

## Economy and progression specification

For every resource, identify sources, sinks, ownership, caps, persistence, and rounding. For every upgrade, identify cost, benefit, diminishing returns if used, and whether it changes play. Model early, typical, and extreme progression before relying on compounding multipliers. Treat formulas and initial values as tunable design assumptions, not validated balance.

Account for offline accrual, capacity, duplicates, disconnects, failed transactions, and prestige/reset semantics when those features are actually in scope. Never add a reset simply because other games have one. Show what is lost and retained before a destructive action.

For randomness, define the complete outcome distribution, duplicate handling, modifiers, pity if any, and the authoritative roll location. Test that the configuration and displayed odds agree. Do not advertise rare outcomes that cannot actually occur or hide the effect of paid modifiers.

## Testing whether the idea works

Observe players without coaching: what do they try first, where do they hesitate, what do they think they earned, and what do they want next? Combine playtest observations with carefully defined events such as first action, first successful reward, first upgrade, and first region unlock. Document event meaning and avoid unnecessary personal data.

Return visits, session enjoyment, social play, and completion of meaningful goals are evidence to investigate. No single metric proves fun. Do not set invented industry thresholds or assume popular-game mechanics transfer automatically to a different audience.
