# Car-Hopping & Racetrack

## 01 / The game at a glance

**High-level concept outline | 18 October 2026 | Version 1.0**

**Working description, not a final game title.** Prepared from the owner's design conversation for the three-person team and Claude to review. This document does not authorize implementation or replace the team's canonical GDD. No game functionality has been built or tested as part of this document.

### The pitch

Jump between moving cars, survive long enough to collect new models, and bring your growing collection to life on your own money-making racetrack. Upgrade your track, unlock new worlds with more desirable cars, and take a favorite car into obstacle races against other players.

The experience combines the excitement of an action run with the satisfaction of a visible collection and an improving home business. Cars are both things to play with and achievements to show off. The world should feel playful, colorful, blocky, and immediately understandable to a young player.

### The central loop

**Drive and hop > secure cars > display cars on your track > earn money > upgrade and unlock worlds > discover better cars.**

Obstacle racing branches from that loop: select an owned car, compete using familiar controls, and return to the hub with another reason to feel proud of the collection.

### What the labels mean

- **Confirmed:** the owner stated or accepted the direction in the design conversation.
- **Recommended:** a proposed way to make the direction coherent or keep the launch manageable. It is not yet a fixed requirement.
- **Open:** the team still needs a choice or a playtest result. Do not invent an answer and call it approved.

### The strongest identity

**Recommended:** build around the connection between active collecting and a visible racetrack. A new car should create three moments of satisfaction: the tense capture, the reveal in the collection, and its first lap at home. Racing then gives that same car another use. This connection is more distinctive than simply adding many currencies, upgrade menus, or unrelated activities.

Popularity is a goal, not a forecast. The first prototype should prove that steering, jumping, and landing are enjoyable before the team commits to a large content roster.

## 02 / The island and first session

### A shared home

**Confirmed:** there is a main island, personal racetrack plots, access to collection roads, and a separate race area. Players should see progress and have opportunities to show off cars.

**Recommended interpretation:** one shared island per server, with a personal plot for each player in that server. This preserves the social feeling without implying that every Roblox player occupies one instance. Plot count and server size remain open.

The layout should make the next action easy to understand: home racetrack, collection entrance, unlocked-world portals, and race entrance. Exact terrain, architecture, and world themes are not selected. An earlier forest environment experiment is not a requirement for this game.

### A tutorial that players actually play

**Confirmed:** use arrows and short guidance rather than a cutscene. Teach through the same actions used in the game, with language and pacing suitable for a young audience.

**Recommended first-session sequence:**

1. Spawn near the assigned plot and see the collection-road entrance.
2. Begin a forgiving run on a starter car and learn steering.
3. Follow one clear cue to jump to a nearby car.
4. Stay aboard long enough to secure it and receive a clear permanent-unlock message.
5. Return home, place that car on the track, and watch it generate money.
6. Preview the next useful upgrade and point out the race entrance.

This is a proposed sequence, not a timed script. The player should understand why collecting matters before being shown several systems at once. Tutorial skip, replay, recovery after failure, and the exact introduction to racing are open.

### Social without constant interference

**Recommended:** make the island social while keeping collection opportunities independent. Other players should not take away the only car a beginner needs or cause unwanted collisions during a collection attempt. Whether players see ghosted runners, separate traffic, or separate run spaces needs a prototype decision.

The competitive outlet is the race area. Visiting tracks, inspecting rare cars, and noticing track expansion can provide quieter forms of comparison. Trading, theft, and collection loss are not part of the agreed core loop.

## 03 / Collection runs

### The player controls

**Confirmed:** the vehicle moves forward automatically. The player steers and times jumps and landings. There is no manual acceleration or braking. Runs start with a default car; the starter rules for later worlds are still open.

The avatar is mostly concealed or seated inside a closed car, and can be visible on a motorcycle or open vehicle. The precise jump presentation is not settled.

**Recommended presentation:** the avatar visibly leaps out of the current car in a short, readable arc, lands on the next car, then settles into its seat. A landing target, brief suspension bounce, and restrained sound cue can communicate success. Keep the camera stable and prioritize readable landing distances over extravagant effects.

Whether landing is automatic after a well-aimed jump or requires another input is open. Touch, keyboard, and controller mappings must be designed deliberately; do not add an extra action just to make controls more complicated.

### Staying too long creates danger

**Confirmed:** a car cannot be ridden indefinitely. Overheating or instability gives a reason to switch. The accepted run-ending defaults are crashing, missing a landing, or staying too long in an overheating car.

**Recommended feedback:** normal driving progresses to a clear warning, then visible sputtering or shaking, then failure if the player remains aboard. The warning must be understandable without reading a paragraph. Color alone should not carry the information.

Car-collection progress and remaining safe ride time are different concepts. Their indicators must not be confused. Every collectible car must provide a fair opportunity to finish securing it before forced failure; exact timing and difficulty scaling require playtesting.

### Securing a car

**Confirmed:** stay aboard a previously unowned model long enough to secure it. Once secured, it belongs to the player permanently and immediately. Crashing afterward does not remove it. Returning safely to the island is not required to bank the unlock.

The language for this action is open: collect, secure, master, or another car-themed word. "Taming" describes the inspiration but need not be the final UI term.

### Failure and retry

**Confirmed:** retrying is free, and secured cars remain owned. Let the player retry the current world or return to the island. Avoid a lengthy failure sequence between attempts.

**Open:** hazard types, road layout, speed curve, run length, traffic generation, camera position, and whether runs eventually end successfully or continue until failure. No numerical balance values are approved yet.

## 04 / Collection, racetrack, and spending

### The accepted ownership defaults

- **Confirmed:** own each car model once. Successfully collecting an already owned model awards bonus money.
- **Confirmed:** the permanent collection can contain more cars than the home track has active slots.
- **Confirmed:** the active track permits one of each owned model. There is no need to maintain duplicate inventory just to fill slots.

A full racetrack must never prevent a new permanent unlock. Selecting the earning lineup is separate from owning the collection. The repeat-reward rules within a run need definition so a player cannot repeatedly trigger the same reward without a new valid collection action.

### Cars visibly earn their keep

**Confirmed:** selected cars drive laps on the home racetrack and generate money according to their quality. Active capacity is limited. Most spending should improve the racetrack.

**Recommended:** keep two clearly explained upgrade tracks:

- **Capacity:** allow more owned cars to participate and make the expanded capacity visible.
- **Income:** improve the track's business earnings, with visible improvements that reflect its level.

Grandstands, pit buildings, track decoration, or additional track sections are possible visual rewards, not a mandatory asset list. The player should be able to tell that a neighbor has progressed by looking at their plot.

**Confirmed:** income upgrades do not automatically increase racing speed. A business upgrade and a vehicle's competitive performance are separate systems.

### What money buys

The principal sinks are track capacity, track income improvements, and access to new worlds. Car customization in the race area is part of the direction; which options cost money remains open.

**Recommended:** start with one shared soft currency for the main economy and race rewards. A second race currency should only be introduced if it has a clear purpose that cannot be served simply by the main currency. Currency names and reward amounts are undecided.

### Online and offline earnings

**Confirmed:** the track earns while the player is in the server and also supports restricted offline earnings. Offline earnings should be substantially reduced or limited by a cap.

**Recommended starting choice:** use a time cap with an easily explained rate. The earlier same-rate-but-capped approach is a proposal, not a settled economic rule. The team can instead choose a reduced rate or combine both if justified.

**Open:** starting slots, maximum capacity, prices, car income, upgrade multipliers, offline duration/rate, claim experience, and which lineup determines offline income. Rejoining must not count the same earnings twice. Avoid choosing arbitrary numbers before the basic loop is tested.

## 05 / Worlds and vehicle progression

### Progress within a run and across the game

**Confirmed direction:** surviving farther should expose the player to more desirable cars and greater challenge. Permanent world unlocks provide longer-term progress. Advanced players can enter an unlocked world directly through a portal rather than repeatedly clearing early areas.

Earlier worlds should remain useful for finishing collections or enjoying their setting. New worlds should add a recognizable reason to visit beyond a larger number on the same car.

**Recommended:** give each world a coherent visual theme, a small set of readable hazards, and a recognizable vehicle family. Introduce only a few new demands at a time so the player can learn through play.

### A car ladder with personality

**Confirmed:** start with humble, toy-like, or low-end vehicles and progress toward more impressive models. Simple, cartoony, blocky art is the chosen direction. Hyperrealism is not the goal.

**Recommended:** use original fictional vehicles with strong silhouettes and playful proportions. Real manufacturers mentioned during brainstorming were examples, not an approved licensed roster. A car should be recognizable at gameplay distance and still look appealing when displayed on the home track.

Rarity, world tier, track earnings, and race performance should be understandable without becoming four competing systems. A rare car can feel special through shape, sound, or a cosmetic effect as well as income. Exact rarity bands, vehicle stats, names, and effects remain open.

### Portals and access

The portal communicates a permanent unlock and an available starting destination. It must clearly show locked versus accessible worlds and explain the next unlock requirement.

**Open technical choice:** worlds may live in the same Roblox place or use separate places. A portal in the design does not itself require a particular teleport technology. Choose the arrangement after considering performance, server flow, loading, and the team's implementation capacity.

### Keep launch content focused

**Recommended:** prove a small, polished set of worlds and cars before expanding. The launch world count, number of cars per world, exact unlock conditions, and economy pacing are not approved. No example number should be treated as a requirement.

Progression must provide worthwhile near-term goals while leaving space for later updates. Adding worlds is useful only if the controls, collection feel, and home-track rewards already work together.

## 06 / Obstacle racing - included at launch

### The mode

**Confirmed:** obstacle racing is playable in the initial release. It is a separate activity where players compare and enjoy their owned cars. Each player selects one owned car and stays in that car for the race.

Movement is automatic forward motion with steering and jumps, matching the collection mode's general control language. Players do not manage acceleration or braking.

**Recommended interpretation:** the entire car jumps over race obstacles while the avatar stays seated. Collection-mode jumps move the avatar between cars. Make that difference visually obvious while keeping the input familiar.

### Competition and fairness

**Confirmed defaults:** better cars may have modest performance advantages, but steering and jump timing should remain important. Players cannot ram or push one another. Physical course obstacles still matter.

**Recommended:** disable collection-style overheating in races because this mode requires staying in one chosen car. Give each obstacle a clear warning and a recoverable failure path. Checkpoints are a useful candidate, but checkpoint placement and penalties are still open.

Do not let a prestige car turn a race into an automatic victory. Conversely, do not promise completely equal performance when the agreed direction permits modest advantages. Choose a small, understandable stat model and test it with players of different skill levels.

### Rewards, customization, and low population

**Confirmed:** the race area supports selecting and customizing cars. The scope of customization remains undecided.

**Recommended launch scope:** one polished obstacle course, a small cosmetic selection such as paint colors, and a simple finish reward with a larger reward for strong placement. These are proposals, not approved counts or payouts. Rewards must not make racing compulsory for players who primarily enjoy collecting.

**Recommended:** provide a solo practice option or another useful activity when too few players are ready. A small new game must still be enjoyable without a full race lobby.

**Open:** race size, queue/start behavior, matchmaking, car stats, obstacles, checkpoints, race duration, ties, disconnects, unfinished runs, rewards, and how to prevent deliberate reward farming. Ranked leagues, elaborate tuning, and multiple competitive currencies are not needed to establish the first playable mode.

## 07 / Launch boundaries and validation

### The initial release must connect these pieces

- A playable arrow-guided tutorial and understandable hub navigation.
- Automatic-forward collection runs with steering, jumping, fair danger warnings, and permanent car unlocks.
- Unique-model ownership, duplicate cash rewards, and a limited active racetrack lineup.
- Visible lap-based track activity, income, track upgrades, and restricted offline earning.
- World progression and direct access to permanently unlocked worlds.
- A separate playable obstacle-race mode with owned-car selection, familiar controls, and customization of an agreed scope.
- A cohesive cartoony, blocky visual style and clear feedback for young players.

These are product goals, not evidence of completed features. Launch content counts, monetization, and detailed balance are still open.

### Recommended production order

1. Prototype automatic driving, steering, hopping, and readable landing feedback.
2. Connect car securing, failure/retry, permanent ownership, and duplicate rewards.
3. Add the track lineup, income, upgrades, and the world-unlock loop.
4. Build the obstacle race using the established movement language.
5. Complete tutorial guidance, art consistency, offline earnings, multiplayer handling, and release verification.

These are development stages within the same launch plan. Stage four is not a suggestion to postpone races until after release.

### What needs to be proven

- A newcomer understands the first car switch and why the newly collected car matters.
- Landing is readable; misses feel understandable rather than arbitrary.
- Securing a car is possible before its danger timer forces failure.
- A crash or rejoin does not remove a secured car; a full track does not block ownership.
- Duplicate rewards occur only for valid repeat collections, and earnings are not counted twice.
- Track upgrades feel visible and useful without automatically raising race speed.
- World unlocks remain available and portals route to the intended destination.
- Obstacle races reward skill, communicate failure clearly, and work with the planned low-population behavior.
- The game remains readable and responsive on the agreed target devices, including a practical mobile test if mobile is supported.

### Keep the first release manageable

**Recommended to defer unless the team explicitly changes scope:** trading, stealing, breeding, merging duplicates, complex tuning, ranked seasons, extensive crafting, and many parallel currencies. They are not part of the agreed launch identity.

The main risks are unclear jump controls, an unrewarding collecting-to-track connection, excessive content demands, and race balance that overwhelms skill. Solve those before investing in a large roster.

## 08 / Decisions before implementation

### Decisions still needed

1. What is the final title and the first world's visual theme?
2. What is the exact jump/landing input, camera, and avatar transition?
3. Are collection runs independent spaces, shared with independent traffic, or another arrangement?
4. How many worlds, cars, active slots, and race courses fit the first release?
5. What are the collection term, danger timings, run structure, and starter-car rules?
6. What determines world unlocks, track prices, income, and duplicate payouts?
7. Which offline rate/cap and claim behavior will be used?
8. Which race stats, matchmaking, recovery rules, rewards, and low-population behavior will be used?
9. How much customization is available at launch, and how is it obtained?
10. What devices, server size, monetization approach, and team ownership split will be supported?

These decisions do not need to be solved all at once. Resolve the ones that affect the controls prototype first; use observations to tune numerical balance later. Monetization is unselected, and the earlier discussion of game passes or lucky mechanics in other concepts is not approval to add them here.

## 09 / Claude review and references

### Message to paste into Claude with this file

Read this game outline as our high-level design direction. Review the concept before implementing anything. Preserve its Confirmed decisions, especially obstacle racing at launch, permanent immediate car collection, unique-model ownership with duplicate cash, limited active track slots, track-focused spending, direct access to unlocked worlds, and simple automatic-forward controls.

First summarize the game in your own words. Then identify the strongest parts, contradictions or missing decisions, and the biggest feasibility or player-experience risks for a three-person team. Separate necessary fixes from optional improvements. Make a small number of high-impact recommendations and explain what each adds, what it costs in scope, and which confirmed decisions it affects. Do not silently promote Recommended or Open items into requirements.

Propose the smallest prototype that can test whether steering, switching cars, collecting, and the racetrack reward loop are fun. Keep obstacle racing in the full initial-release plan. Ask only the most consequential unanswered questions first. Inspect the live repository rules and design notes if you actually have access, explain conflicts with this snapshot, and report any missing tool access honestly. Do not edit game code, choose numerical balance, publish, or overwrite the GDD as part of this review.

### Inspiration and evidence boundaries

Rodeo Stampede is a reference for switching rides, staying aboard to tame a new animal, and a collection connected to a home business. Those broad mechanics inform the comparison; this document proposes an original car-themed game rather than a reproduction of its assets or presentation.

Official reference pages consulted in the design discussion:

- Riding and taming: https://rodeostampede.zendesk.com/hc/en-us/articles/4832109289887-Core-Gameplay-Riding-and-Taming-Wild-Animals
- Zoo and progression: https://rodeostampede.zendesk.com/hc/en-us/articles/4832099137567-Your-Sky-Zoo-Build-Your-Animal-Empire
- Publisher overview: https://www.yodo1.com/rodeo-stampede

The immediate permanent-unlock rule here is the owner's design decision; it should not be presented as a verified statement about every failure or interruption case in Rodeo Stampede. No current popularity ranking, retention statistic, publishing eligibility rule, or commercial-success prediction is established by these references.

### Maintaining this outline

After team review, record approved changes in the live GDD and decision log. Refresh any copy uploaded to Claude when those decisions change. The repository remains the working record; this PDF and its companion Markdown describe the conversation as of the date above.
