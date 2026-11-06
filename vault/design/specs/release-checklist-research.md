# Release checklist research: raw facts

Research only. Every fact was read on **2026-11-05** from the source listed in its row or bullet. Source keys like [KS] are defined in the table at the bottom. This is not a checklist or a decision. Nothing here authorizes publishing, making the game public, paying fees, or changing settings.

## Surprises and contradictions with common assumptions

Publishing rules changed a lot. There are now three account tiers: **Roblox Kids (5–8)**, **Roblox Select (9–15)** and **Roblox (16+)**. With a plain release ("Content May Vary", first questionnaire question answered "No"), a new game reaches **only age-checked users aged 16 and over** [PUB][KS].

To reach anyone under 16, which is our audience, the **group owner** of a group-owned game must meet several requirements:
- age-check and verify their account (facial age estimation if under 18, government ID if 18 or over);
- enable 2-Step Verification;
- either hold Roblox Plus or Premium for 2 consecutive months, or pay a **refundable 1,000 Robux publishing fee**;
- complete the **whole** Maturity & Compliance questionnaire and get a Minimal, Mild or Moderate rating.

The game must also pass an **evaluation**: a trial phase available only to age-checked users 16+, then **250 unique plays from "highly engaged" age-checked players within 60 days**, plus a safety review. Alternatively, a refundable **50,000 Robux expedited review** is available [KS][PUB]. Kids (5–8) can only see **Minimal or Mild** games [CM][KS].

Other surprises:
- Content maturity labels are now named **Minimal / Mild / Moderate / Restricted / Content May Vary**. An older docs page that is still online, "Experience guidelines", uses the retired labels (All ages / 9+ / 13+ / 17+) and older menu paths. Do not follow it [EG] vs [CM].
- A game with no content maturity information has its playability **restricted for all players** [CM].
- The account-age floor for a 16+ release is **2 days**, not the 30 days the old page cites [PUB] vs [EG].
- A new release is capped at **5 never-released games per day** [PUB].
- Since 2026-05-30, cross-game product and pass sales are disabled [DP].

---

## 1. Eligibility to publish and release

- Publishing (File > Publish in Studio) creates the universe. A new game is visible **only** to the creator, users with Edit access, and group members whose roles allow it, until it is released [PUB].
- **Release to ages 16+ and Trusted Friends** [PUB][KS]:
  - The account must be in good standing and **at least 2 days old**.
  - The owner must complete an **age check** (facial age estimation or government ID).
  - Answer the first questionnaire question (age-restricted content?).
    - **No**: the game gets a **Content May Vary** label and releases only to age-checked users 16+.
    - **Yes**: complete the full questionnaire and get the matching label.
- **Release to all ages (Kids and Select)** needs everything above **plus** [PUB][KS]:
  - Account verification: facial age estimation if under 18, government ID if 18 or over.
  - **2FA** on the account.
  - **One of:** an active Roblox Plus or Premium subscription for **2 consecutive months**, or a refundable **1,000 Robux publishing fee**, paid in Creator Hub > Audience > Reach > "Refundable publishing fee".
  - The **evaluation** must be passed:
    - Trial phase: age-checked users 16+ only.
    - Engagement analysis, evaluated hourly.
    - Safety review.
    - Threshold: **250 unique plays by highly engaged age-checked users within a 60-day window**. Progress shows on the **Audience Reach** dashboard.
  - The **full** Maturity & Compliance questionnaire must be completed with a **Minimal, Mild, or Moderate (9+)** rating.
- **Group-owned games:** the requirements apply to "**group owners** of group-owned games" [KS].
- **"Highly engaged player"** [KS]: the account must meet tenure, playtime and platform-spend requirements. That means a purchase anywhere on Roblox in the last 60 days plus time in your game within the same window. The player does not need to spend in your game.
- **Publishing fee refund**, which the two pages describe differently:
  - [PUB]: refunded "if your game maintains 25 highly engaged players for 60 days without moderation".
  - [KS]: "automatically refunded 90 days after your game becomes eligible", or 90 days after payment if it never becomes eligible.
  - Both pages: the fee is not refunded if the game is permanently removed for Community Standards violations.
- **Expedited review:** a refundable **50,000 Robux** per game, with a 48-hour review. A minor violation restarts the 48-hour clock. A refund can be requested after 90 days if the game stays in good standing with 25 highly engaged players [PUB][KS].
- **A lapsed subscription does not unpublish the game.** The fee or subscription requirement is checked only when you publish a new game or an update for all-ages audiences [KS].
- **Release requirements apply to all release actions:** first release, a new place version on a released game, Publish As to a different game, and audience changes [PUB].
- **Daily cap:** up to **5 never-released games per day**. Re-releasing a game whose public access was revoked does not count toward the cap [PUB].
- **Early testers:** invite up to 10 similar-aged friends (or Trusted Friends) to preview before release via File > Invite early testers. They see a watermark, and testers under 16 cannot preview a game above their parent-allowed maturity [PUB].
- **Audience settings** [PUB]: Creator Hub > game > Publish settings > **Manage Audience** > Manage access.
  - Playtest tab: Early testers, which is always on, and Playtesters (Edit or Playtest access).
  - Public tab: Friends.
  - Optional: Audience > Advanced Settings > "Exclude from recommendations".
- **Age and region gating without a maturity change** [CFG]: Audience > **Access Settings** > Minimum age and Regions.

## 2. Maturity & Compliance questionnaire

- **Location** [CM]: Creator Dashboard > game > **Publish settings > Content rating** > Start (or Restart). Then Save and Continue on each page, then the Preview page (which shows the label, the descriptors and any non-compliant regions), then Submit.
- **Labels** [CM]:
  - **Minimal**: "occasional mild violence and/or light unrealistic blood".
  - **Mild**: repeated mild violence, heavy unrealistic blood, mild fear, mild crude humor.
  - **Moderate**: moderate violence, light realistic blood, moderate fear or crude humor, unplayable gambling content.
  - **Restricted**: 18+ only.
  - **Content May Vary**: age-checked 16+ only.
- **Label to account type** [CM]:
  - Minimal or Mild: eligible for **Kids (5–8)** and Select (9–15).
  - Moderate: Select and 16+.
  - Content May Vary: age-checked 16+.
  - Restricted: age-verified 18+.
- **Question categories** [CM]: Violence (intensity, frequency); Blood; Fear; Crude humor; Unplayable gambling content; Strong language; Romantic themes; Alcohol; Social hangout; Free-form user creation; Sensitive issues; **Paid random items** (and whether you respect `ArePaidRandomItemsRestricted`); **Paid item trading** (and whether you respect `IsPaidItemTradingAllowed`); Media sharing and feeds; **AI interaction**.
- **Car-game notes from [CM]:**
  - Car racing, horse racing and poker chips do **not** count as gambling to report.
  - Implied violence counts as **at least Mild**. Unrealistic consequences (characters vanishing at zero health) count as Mild.
  - Free-form drawing and social hangouts are limited to players 16 and over.
- **Answer for the most extreme content in the game.** If an update changes any answer, you **must** resubmit [CM].
- **Not completed:** "If a game does not have content maturity information, Roblox automatically restricts the playability of the game on the platform for all players" [CM].
- **Inaccurate answers:** Roblox may replace or remove the label and take moderation action. Repeat offences put the game and account at risk. Appeals go through roblox.com/report-appeals [CM].
- **Assets are moderated on their own**, whatever the label says [CM].
- **Stale page warning:** "Experience guidelines" [EG] still describes age recommendations "All ages / 9+ / 13+ / 17+", a 30-day account minimum, and Audience > Maturity & Compliance. It conflicts with [CM], [PUB] and [KS]. Treat it as outdated.

## 3. Community Standards points for a kids' car game with Robux items [CS]

- **Misleading content and metadata:** prohibits "Deceptive, sensational, duplicative, or otherwise misleading content or metadata ... used to drive discoverability, monetization, or engagement", including content "confusingly similar" to other creators' content. It also prohibits repeatedly re-uploading near-identical content.
- **Economy:**
  - Prohibits "Offering virtual content or functionality in exchange for Robux or other payment, and removing functionality for buyers without proper notice." This matters if a paid item is ever changed.
  - Prohibits circumventing Roblox payments, for example by giving indirect benefits for purchases made elsewhere.
  - Off-platform sales of on-platform items are not allowed.
- **Paid random items:**
  - Odds must be "accurately and numerically disclosed ... before the moment of purchase".
  - Odds modifiers must be explained before purchase.
  - "All possible outcomes ... must provide some benefit".
  - A bundle that contains any random item counts as a paid random item.
  - `ArePaidRandomItemsRestricted` must be respected, and `IsPaidItemTradingAllowed` must be respected for trading. The disclosure format is in [PRI]: percentages that sum to 100%, an "Info"/"Details" label rather than a bare (i) icon, and live-updated odds when boosts are active.
- **Gambling:** simulated and actual gambling are prohibited. "No real money, Robux, or in-game items of value may be exchanged" in a game of chance.
- **Contests:** contests where Robux or anything of real money value is the prize are not allowed without Roblox's involvement.
- **Donations:** soliciting donations for causes is prohibited. A "tip jar" is allowed if the user clearly gets nothing in return.
- **Off-platform links:** these are allowed only through Social Links on the detail pages, and only for users 16+ who are age-checked.
- **Advertising Integrations Policy (from 2026-05-04):** non-Roblox ad units need registration, and "Ads may not be personalized for users under the age of 18."
- **Policy APIs:** "Failing to use required PolicyService APIs ... to declare features" is listed under Misusing Roblox Systems.
- **Not found:** the Community Standards text has **no explicit "no pay-to-win" or "no paying for advantage" rule** for a game's own items. The "unfair advantage" wording refers to exploits. It also has **no explicit rule about how often or how hard a game may prompt purchases**. (Project policy is stricter than the platform here: CLAUDE.md bans FOMO, coercive scarcity and paid luck.)

## 4. Icon and thumbnail rules

| Item | Rule | Source |
|---|---|---|
| Game icon | Square, **512×512** template, at least 512×512. It scales down to about 150×150 in places, so preview it small. One icon per locale. It must pass moderation before others see it. Path: Creator Dashboard > game > Configurations > Places > start place > **Icon** > Change. A default icon is generated on first publish. | [IC] |
| Thumbnails count | **Up to 10 images or videos** per game detail page. All are moderated. | [TH] |
| Image thumbnail | **16:9**, ideally **1920×1080**. Formats: `.jpg .gif .png .tga .bmp`. Uploads for personalization must be under 3 MB and at most 1920×1080. Thumbnails are stretched to 16:9 whatever the upload's ratio. Keep key content away from the **bottom**, where the player count can cover it. Path: Configurations > Places > select place > Thumbnails (Home Page tab and Experience Detail Page tab). | [TH] |
| Video thumbnail | Free, but limited to **3 uploads per month**. Not supported on Xbox, PlayStation or VR. All videos are reviewed. **Not allowed:** gameplay, UI or mechanics that are not in the game; artificially enhanced visuals; real-life footage; voice-over, narration, voice chat or **music with lyrics**; advertising or subjective claims such as "50% off" or "Free UGC!". **Allowed:** camera work (freecam is Left Shift + P in solo playtest), minor post-processing, a logo overlay, curated sequences, in-game UI text, and music from the Roblox catalog. Rejected videos still count toward the monthly quota. | [TH] |
| Personalization | Activate 2 to 5 thumbnails, and Roblox picks per user. | [TH] |
| Dev product / pass icons | At most 512×512, `.jpg/.png/.bmp`, circular crop. | [DP][PA] |

## 5. Name, description and metadata

- **Studio File > Publish fields:** icon, thumbnail, Name, Promotional Text (beta), Genre and Subgenre, Description [PUB].
- **Guidance** [PUB]:
  - Keep the name stable; frequent renames make the game harder to find.
  - Do not spam repeated words, which "may result in demotion".
  - Use emoji sparingly.
  - The description's first sentence should summarize the game. Include relevant keywords, but no irrelevant keyword lists (for example other games' names).
- **Length limit:** **not stated in any current official page found.** A community forum answer cites 1,000 characters, which is unverified. The Open Cloud universe update returns "8: New universe name is too long" and "7: New universe name or description has been rejected" [UNI]. Check the field limit by eye in Creator Hub.
- **Strong language:** in-game assets and metadata must never contain it, whatever the label [CFG].

## 6. Server size, devices, Studio security settings

- **Server size:**
  - `Players.MaxPlayers` "can only be set through a specific place's settings on the Creator Dashboard" and cannot be set by script [PL].
  - Studio has the same setting: Experience Settings > Places > ⋯ > **Configure Place** ("maximum number of players") [ES].
  - Open Cloud: the Place field `serverSize` ("maximum number of allowed users in a single server") [PLC].
  - Upper limit: a 2023 staff announcement raised the general maximum to **200**, with 700-player servers in beta [DF-SS]. No current docs page restates the cap.
- **Supported devices:**
  - Studio Experience Settings > Basic Info > **Playable Devices** ("enable each applicable device") [ES].
  - Open Cloud universe fields: `desktopEnabled`, `mobileEnabled`, `tabletEnabled`, `consoleEnabled`, `vrEnabled`, plus `voiceChatEnabled` (changes do not affect active servers) [UNI].
  - Console has its own guidelines page [CP].
- **Allow HTTP Requests** (Studio File > Experience Settings > Security): this lets game servers call remote servers through `HttpService` (`GetAsync`, `PostAsync`, `RequestAsync`). It is **off by default** [HTTP][ES]. The Security tab warns: enable it only if you trust all third-party assets in the game [ES].
- **Enable Studio Access to API Services** (same tab): this lets Studio playtests use DataStores and other API services. "Studio accesses the same data stores as the client application", so the docs say **do not enable it for live games** and suggest a separate test version instead [DS][ES]. The Studio MCP data store tools also require it [MCP].
- **Other Security-tab settings** [ES]:
  - **Allow Third Party Sales**: when off, prompts for assets you do not own fail.
  - **Allow Third Party Teleports**.
  - **Allow Mesh / Image APIs**: EditableImage/EditableMesh in published games, which needs the owner to be 13+ age verified and ID verified.
  - **Secrets**.
- **Communication tab:** Enable Microphone (voice) and Enable Camera [ES].
- **Shutdown All Servers** is in Studio Experience Settings > Other [ES].

## 7. Audio and asset permissions (group-owned)

- **Asset Privacy** (Restricted vs Open Use) [AP]:
  - Its *setting* only changes the creation default of **Images, Decals and Meshes**. Audio, Video, Models, MeshParts, Animations and Packages have their own defaults.
  - A **Restricted** asset loads only if the creator **and the game** have permission. Otherwise "it cannot load in Studio" and is "not visible or audible during runtime", with a clickable error in Output.
  - Your own assets always work in your own games.
  - For a group: "All group members with Edit access can use the asset in games owned by that group" once the group has been granted permission.
  - Granting to a game: Creator Dashboard > game > **Configurations > Permissions** (enter asset IDs), or per asset: Development Items > asset > Permissions > Experiences (enter universe IDs).
  - **Game grants are permanent.** **Open Use is irreversible.**
  - Inserting a restricted asset into a collaborator's game also grants it to that game's owner.
  - Only the **group owner** can turn on group Asset Privacy defaults.
- **Audio uploads** [AU]:
  - You must hold the rights. Formats: `.mp3/.ogg/.wav/.flac`, under 20 MB and 7 minutes, at most 48 kHz, mono or stereo or 5.1.
  - Limit: 100 uploads per 30 days unverified, 2,000 if ID verified.
  - Upload through the Asset Manager, Creator Dashboard, or Open Cloud. Open Cloud can create assets as a group by passing the group ID.
  - Uploaded audio is private to the uploader at first, and other users or games need permission.
  - Creator Store audio is free to use.
- **Practical implication (inference):** audio uploaded by an individual member's account must be granted to the group's game, or uploaded as the group, or it will be silent for players. Check this for every asset in Output during a published-game test.

## 8. DataStore limits worth checking before release [DSL]

| Limit | Value |
|---|---|
| Store, key and scope name length | 50 characters each |
| Value size | 4,194,304 characters per key |
| Per-key throughput | Read 25 MB/min, write 4 MB/min (each request rounds up to 1 KB) |
| Experience storage | 500 MB + 1 MB × lifetime users (compressed size of the latest versions) |
| Experience request budget, standard stores | Read 300 + CCU×40/min; Write 300 + CCU×20/min; List 300 + CCU×2/min; Remove 300 + CCU×40/min. Shared with Open Cloud. `UpdateAsync` uses read **and** write budget. |
| Per-server budget, standard stores | Read and Write: 60 + players×40/min each; List: 5 + players×2/min. Check it with `GetRequestBudgetForRequestType`. |
| Queues | Throttled requests queue up; each queue holds 30. Errors 301–306 mean the request was **dropped**. |

- The ProcessReceipt guidance stores processed `PurchaseId`s in the session-locked player data [PDP].

---

## Sources (all read 2026-11-05)

| Key | URL |
|---|---|
| KS | https://create.roblox.com/docs/production/publishing/kids-and-select |
| PUB | https://create.roblox.com/docs/production/publishing/publish-games-and-places |
| CM | https://create.roblox.com/docs/production/promotion/content-maturity |
| EG | https://create.roblox.com/docs/production/promotion/experience-guidelines (outdated page, still online) |
| CFG | https://create.roblox.com/docs/projects/configure-games |
| CS | https://about.roblox.com/community-standards (the en.help.roblox.com copy blocks automated fetching) |
| PRI | https://create.roblox.com/docs/production/monetization/paid-random-items |
| DP | https://create.roblox.com/docs/production/monetization/developer-products |
| PA | https://create.roblox.com/docs/production/monetization/passes |
| IC | https://create.roblox.com/docs/production/publishing/experience-icons |
| TH | https://create.roblox.com/docs/production/publishing/thumbnails |
| ES | https://create.roblox.com/docs/studio/experience-settings |
| HTTP | https://create.roblox.com/docs/cloud-services/http-service |
| DS | https://create.roblox.com/docs/cloud-services/data-stores |
| DSL | https://create.roblox.com/docs/cloud-services/data-stores/error-codes-and-limits |
| PDP | https://create.roblox.com/docs/cloud-services/data-stores/player-data-purchasing |
| MCP | https://create.roblox.com/docs/studio/mcp-open-cloud |
| PL | https://create.roblox.com/docs/reference/engine/classes/Players |
| PLC | https://create.roblox.com/docs/cloud/reference/features/places |
| UNI | https://create.roblox.com/docs/cloud/reference/features/universes |
| CP | https://create.roblox.com/docs/production/publishing/console-guidelines |
| AP | https://create.roblox.com/docs/projects/assets/privacy |
| AU | https://create.roblox.com/docs/audio/assets |
| DF-SS | https://devforum.roblox.com/t/experience-join-improvements-server-size-join-queues-and-social-slots-reservations/2294621 (staff post, 2023-04-13, updates to 2023-05-11) |
