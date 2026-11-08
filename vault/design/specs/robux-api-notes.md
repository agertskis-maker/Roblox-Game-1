# Robux purchase pipeline: verified API notes

Research only. Every fact below was read on **2026-11-05** from the source listed in its row or bullet. Source keys like [MS] are defined in the table at the bottom. Nothing here is a design decision; monetization in this project still needs an approved team design (AGENTS.md, CLAUDE.md).

## Surprises and contradictions with common assumptions

There is now a **second receipt API**, `MarketplaceService:BindReceiptHandler(Enum.ReceiptType.DeveloperProduct, handler, {productIds}?)`. Its handler returns `Enum.ReceiptDecision.Processed / NotProcessedYet`, not `ProductPurchaseDecision`. You can register several handlers (filtered per product ID, plus one catch-all), and anything left unmatched falls through to the legacy `ProcessReceipt` [MS]. "Only one handler per server" now applies only to `ProcessReceipt` itself. `ProcessReceipt` has **no time-based retry** and **no timeout**: it re-fires only on rejoin or on the next purchase [MS]. If no callback is set, receipts are **auto-acknowledged and lost** [MS]. Developer products can also be bought **outside the game**: on the Store tab, from the Roblox homepage, from search, and on the post-Robux-purchase page. Those purchases arrive as receipts when the player next joins [DP][Shop]. Every game also gets a **Roblox-generated in-game Shop** by default (`MarketplaceService:OpenShop`) [MS][Shop]. **Managed pricing (regional pricing) is ON by default for all passes and for newly created items**, so a player's price can be 30 to 100% of the default price. Any hard-coded price in the UI will be wrong, and the player-specific price must be read on the client with `GetProductInfoAsync` [RP][MP]. `GetProductInfo` is **deprecated**; use `GetProductInfoAsync` [MS]. **Open Cloud CAN create and update developer products and game passes.** The endpoints are BETA and there is no delete [OCDP][OCGP]. The Studio MCP `open_cloud_invoke` tool can call them with no API key, but only if the user grants the high-risk "Money & monetization" permission [MCP]. Studio's own Experience Settings > Monetization can create developer products, but its docs list no pass creation there [ES]. **PolicyService has no "cannot buy at all" field.** Parental monthly spending limits are enforced by Roblox at checkout, and no API exposes them to the game.

---

## 1. Receipts for developer products

### 1a. `MarketplaceService.ProcessReceipt` (legacy callback) [MS]

- Signature: `MarketplaceService.ProcessReceipt(receiptInfo: Dictionary): Enum.ProductPurchaseDecision`. Server only. Capability: Monetization.
- Set it **once, in a single server Script**, and have it handle every developer product. The doc sample's comment says it "can only be done once by one script on the server".
- `receiptInfo` fields: `PurchaseId` (unique per purchase), `PlayerId` (UserId), `ProductId`, `PlaceIdWherePurchased` (may differ from the current place), `CurrencySpent`, `CurrencyType` (always `Enum.CurrencyType.Robux`), `ProductPurchaseChannel`.
- `Enum.ProductPurchaseChannel` [Enum-PPC]: `InExperience`=1, `ExperienceDetailsPage`=2 (Store tab), `AdReward`=3 (rewarded video ad), `CommerceProduct`=4.
- `Enum.ProductPurchaseDecision` [Enum-PPD]: `NotProcessedYet`=0, `PurchaseGranted`=1. No other values.
- **When it is called**, for all unresolved purchases: when a purchase completes, when a successful purchase prompt appears, and when the user joins the server.
- **Retries:** "ProcessReceipt has no time-based retry mechanism." After `NotProcessedYet`, it is called again only when the user starts another developer product purchase or rejoins any server of the experience.
- **No timeout:** the callback "can yield for as long as the server is running", and the result is still accepted.
- **Limitations, as the docs list them:**
  - With no callback set, receipts are auto-acknowledged and cannot be recovered.
  - Multiple pending receipts arrive in a non-deterministic order.
  - The user must be on the server for the callback to fire. The result is recorded even if the user has left.
  - The same purchase can run on **two servers at once** if the user joins a second server before the first callback returns.
  - Even after `PurchaseGranted` is returned, the backend can fail to record it, so the purchase stays unresolved and will be redelivered.
- Unresolved purchases "are not removed or refunded after the escrow period expires."
- **Idempotency guidance.** The official sample keys an `UpdateAsync` on `PurchaseId` in a "PurchaseHistory" store. It says one duplicate-grant case is unavoidable: the grant succeeds, then recording it fails. The fix it recommends is an in-memory record plus **session locking** around the player data [MS][PDP].
- **Player data not loaded.** The sample returns `NotProcessedYet` when the player is not in the server. The player-data guide [PDP] says: "If the player's data hasn't loaded yet (which is expected when a player joins a game), wait for the player's data to load." It then:
  1. checks that the `PurchaseId` is not already in the player's in-memory data;
  2. grants the product;
  3. stores the `PurchaseId` in player data;
  4. saves;
  5. returns `PurchaseGranted` only if the save succeeds, otherwise `NotProcessedYet`.
  - On a later call, step 1 catches a save that landed late.
  - Fit for this project (inference, not from the docs): ProfileStore's session lock is the "session locking" the guide asks for, so the processed-PurchaseId list belongs in the profile.
- The Developer Products guide says grant handlers "must return true" for the transaction to succeed [DP]. Roblox keeps no per-user purchase history, so storing it is the developer's job [DP].
- **External sales:** a **Listed** developer product can be sold outside the game. Roblox "checks your ProcessReceipt implementation on an ongoing basis". If it finds a problem, the product is flagged in Creator Hub > Monetization > Shop and drops off external surfaces until it is fixed, but in-game purchase flows keep working [DP][Shop].
- Since 2026-05-30, cross-game developer product and pass sales are disabled [DP][PA].

### 1b. `MarketplaceService:BindReceiptHandler` (newer) [MS][Enum-RD]

- Signature: `BindReceiptHandler(transactionType: Enum.ReceiptType, handler: Function, filter: Array?): RBXScriptConnection`. Capability: Monetization.
- Receipt types: `DeveloperProduct`, `RobuxTransferSender`, `RobuxTransferReceiver`.
- Filtered handler: pass a list of product IDs. Catch-all handler: omit the filter. A bound handler takes precedence, and anything unmatched falls through to `ProcessReceipt`.
- Return `Enum.ReceiptDecision.Processed` (=1) or `NotProcessedYet` (=0). Returning `NotProcessedYet` means the receipt is "redelivered ... later, either during their existing session or the next time they join a server".
- Receipt fields: `PurchaseId`, `PlayerId`, `PlaceIdWherePurchased`, `ReceiptType`, `ProductId`, `CurrencyType`, `CurrencySpent`, and `TransferRequestId` (transfers only).
- It throws if a handler already exists for the same type and product ID, or if a catch-all already exists for the type.
- The official dev-product sample grants idempotently with `UpdateAsync` keyed on `PurchaseId`. If the player's stats are not ready, the transform returns `nil`, so nothing is written and the handler returns `NotProcessedYet`.

---

## 2. Prompts, finished events and ownership

| API | Exact signature / notes | Source |
|---|---|---|
| `PromptProductPurchase` | `(player: Instance, productId: int64, equipIfPurchased?: boolean, currencyType?: CurrencyType): ()`. The last two parameters are **"Ignored."** You can only prompt products that belong to the current game. In Studio, mocked purchases skip that check, so verify the IDs before you publish. Capability: PromptExternalPurchase. | [MS] |
| `PromptGamePassPurchase` | `(player: Instance, gamePassId: int64): ()`. `gamePassId` is the `TargetId` from product info with `InfoType.GamePass`, "not the pass's asset ID and not its ProductId". The same current-game rule and Studio caveat apply. | [MS] |
| `PromptGamePassPurchaseFinished` | `(player: Instance, gamePassId: int64, wasPurchased: boolean)`. It fires when the prompt closes. Listen to it **on the server only**: on the client, its "values should not be relied on for validation or game logic". When it fires it updates the `UserOwnsGamePassAsync` cache. The Passes guide grants pass benefits from it on the server. | [MS][PA] |
| `PromptProductPurchaseFinished` | `(userId: int64, productId: int64, isPurchased: boolean)`. It passes a **UserId**, not a Player. The docs say: "Do **not** use ... to process purchases." `isPurchased = true` does not prove the purchase succeeded, because the backend can still fail (for example a system outage, or a price change that leaves too few Robux). Use it only to drive UI. | [MS][DP] |
| `UserOwnsGamePassAsync` | `(userId, gamePassId: int64): boolean`. Yields, and works on client and server. Capability: AssetRead. **Results are cached.** The cache updates when `PromptGamePassPurchaseFinished` fires. A pass bought outside the experience mid-session can take "several minutes" to show up. On a user's first entry to a server after buying, it "always returns true". It supports transparent batching (several `task.spawn` calls are combined). Wrap it in `pcall`. | [MS] |
| `OpenShop` | `(player: Player): ()`. Opens Roblox's built-in Shop overlay, which lists the game's passes and developer products. "A default Shop is generated automatically for every game." Passes are **always listed** in it and cannot be unlisted. Developer products can be Listed or Unlisted. | [MS][Shop] |

## 3. Product info and the player-specific price

- `GetProductInfo(assetId, infoType)` is **Deprecated**, "superseded by GetProductInfoAsync()" [MS]. The guide pages still show the old name in their samples [DP][PA].
- `GetProductInfoAsync(assetId: int64, infoType?: Enum.InfoType = Asset): Dictionary`. It yields, **throws if the item does not exist**, and supports transparent batching. Capability: AssetRead [MS].
- `Enum.InfoType` [Enum-IT]: `Asset`=0, `Product`=1, `GamePass`=2, `Subscription`=3, `Bundle`=4. Use `Product` for developer products and `GamePass` for passes. (The Price optimization page writes `Enum.InfoType.GamePasses`, which is a typo; the enum item is `GamePass`.)
- Fields: `Name`, `Description` (can be nil), `PriceInRobux`, `UserBasePriceInRobux`, `PriceDiscountDetails` (each entry has `Type`, for example `"RobloxPlusSubscription"`, plus `AmountInRobux` and `Percent`), `ProductId` (Product), `TargetId`, `IconImageAssetId`, `IsForSale`, `Created`, `Updated`, `Creator{CreatorType, CreatorTargetId, HasVerifiedBadge, Name}`, `CanBeSoldInThisGame`, and others. The docs say "not all information is provided or necessarily relevant" for every type [MS]. Both the pass and product guides check `productInfo.IsForSale` before prompting [DP][PA].
- **The price differs per player.** Price discounts (Roblox Plus) make `PriceInRobux` user-specific [MS]. Managed pricing makes it region-specific [RP].
- `GetDeveloperProductsAsync(): Pages` lists all of the game's products. Use it "to display the regional price for all developer products" [MS][RP].
- **Regional pricing / managed pricing** [RP][MP]:
  - It is **on by default for all new and existing passes** and for "new games and newly created items". Developer products need the "Enable Managed Pricing" action, which is preceded by a dynamic-price check.
  - Regional prices stay between 30% and 100% of the default price and never exceed it.
  - The player's "economic location" decides the price, using signals such as VPN use, billing history and account history.
  - **To show the correct price:** call `GetProductInfoAsync` / `GetDeveloperProductsAsync` **from client code at runtime**. The guides say "make sure the script runs on the client so that users see personalized product prices" [DP][PA].
  - A hard-coded price label shows the wrong number while the player is charged the regional price [RP].
  - Creator Hub > Monetization > Managed Pricing > **Dynamic Price Check** pins fake prices for up to 5 test accounts so you can find hard-coded labels [PO].
- `receiptInfo.CurrencySpent` holds "the exact Robux amount the user paid", including during price tests [DP].
- `GetUsersPriceLevelsAsync(userIds: Array): {PriceLevelInfo{UserId, PriceLevel}}` returns a price level from 1 to 1000 (1000 = full global price). It is meant for gift and trade arbitrage checks. Call it at player join and do not cache it across sessions [MS][RP].
- Price optimization tests need about 60,000 transactions in 30 days, so they will not apply to a beta [PO].

## 4. PolicyService

- `PolicyService:GetPolicyInfoForPlayerAsync(player: Instance): Dictionary`. It yields; wrap it in `pcall`. On the client it works only for the local player. It errors if called more than 100 times before an HTTP response comes back [PS].

| Field | Type | Relevance to selling products and passes |
|---|---|---|
| `ArePaidRandomItemsRestricted` | bool | **Yes, if anything paid is random.** When true, the player "can not interact with paid random item generators", whether bought with Robux directly or with Robux-bought currency. [PS][PRI] |
| `IsPaidItemTradingAllowed` | bool | **Yes, if paid items can be traded.** When false, the player must not trade paid items. [PS][PRI] |
| `AreAdsAllowed` | bool | Only for immersive ads. [PS] |
| `IsSubjectToChinaPolicies` | bool | For experiences available in China. [PS] |
| `AllowedExternalLinkReferences` | array | "Legacy field. It always returns an empty array." [PS] |
| `IsContentSharingAllowed`, `IsEndlessContentLoadAllowed`, `IsEndlessContentAutoplayAllowed`, `IsPhotoToAvatarAllowed` | bool | Not purchase-related. [PS] |
| `IsEligibleToPurchaseSubscription` | bool | Gates **subscriptions** only. [PS] |
| `IsEligibleToPurchaseCommerceProduct` | bool | Gates **commerce (physical) products** only. [PS] |

- **No field says "this player cannot buy developer products or passes".** The only purchase-eligibility flags cover subscriptions and commerce products [PS].
- Community Standards say that failing to use the required PolicyService APIs to declare features covered by policy is a violation ("Misusing Roblox Systems") [CS].
- Studio: Test > **Player Emulator** > Enable Test Profile > Region emulates the policy values [TM].
- **Parental spending controls.** Parents can set a monthly spending limit for children under 13 in most regions, from 0 to 10,000 (default: no limit), in Settings > Parental controls > Spending restrictions. It resets monthly, does not cover gift-card redemptions, and may not apply on some consoles. High-spend alert notifications are on by default for parents [HC-SL][HC-PC].
  - These figures come from Help Center search snippets. The articles block automated fetching (HTTP 403), so confirm them by eye.
  - The engine docs reviewed expose no API for spending limits. Roblox enforces the limit at checkout, and the prompt simply does not complete, so a game must never assume a prompt leads to a purchase.

## 5. Studio test purchases

- The current engine reference calls them "**mocked purchases**" in Studio, and says mocked purchases do not check that the product or pass belongs to the current game [MS].
- No current create.roblox.com page states the "not charged" rule outright. The original staff announcement ("Mock Purchases in Studio", Seranok, 2016-07-12) says "you won't be charged for in-game purchases made in Studio". It also says purchases are simulated locally, a developer product purchase invokes `ProcessReceipt`, and "mock purchases will not persist between Studio sessions" [DF-Mock].
- **Known incident:** in July 2026, Studio **game pass** test purchases charged real Robux. Roblox staff acknowledged it on 2026-07-22 and said on 2026-08-05: "We've fixed the issue and refunded purchases that occurred from studio" [DF-GP].
- Staff also said in 2025-12 that the Studio prompt shows a fake balance above 2 billion with no visible "test" indicator. They called this "expected for now" [DF-Prompt].
- A June 2026 bug report says Studio **subscription** tests use the real purchase path. That is not relevant unless we sell subscriptions [search result, not verified].
- **Practical gotchas** (inference): mock pass ownership resets each Studio session, and `UserOwnsGamePassAsync` with mocks has historically been unreliable [DF-Mock]. Watch the Robux balance on the first pass test, given the July 2026 incident.

## 6. Creating developer products and passes

### 6a. Creator Hub (works for group-owned games)

- **Prerequisite:** "make sure your game has been published and is accessible on Roblox" [DP][PA].
- **Developer product:** Creations > select game > **Monetization > Developer Products** > **Create developer product** [DP]. Then:
  1. Upload an icon (see Icon rules below).
  2. Enter a name and a description.
  3. Pick a category, which organises the in-game Shop.
  4. Set the price: minimum 1 Robux, maximum 1,000,000,000 Robux.
  5. Click Save Changes.
  - To get the ID, use ⋯ > **Copy Asset ID**.
- **Pass:** Monetization > **Passes** > **Create pass** [PA]. Then:
  1. Upload an icon.
  2. Enter a name and a description.
  3. Pick a category.
  4. Click Create pass.
  - **No price step appears in the documented creation flow.** Price and sale settings come after creation (managed pricing views appear on the pass's **Sales** page [RP]).
  - To get the ID, use ⋯ > Copy Asset ID.
- **Icon rules (both):** "doesn't exceed 512x512 pixels", in `.jpg`, `.png` or `.bmp`. The icon is cropped to a circle, so keep important content inside it [DP][PA]. Products without a custom icon show a default icon on external surfaces [DP]. Uploaded images go through asset moderation [Icons]. Pass promotion on the Buy Robux page needs a thumbnail, a price of 50 to 800 Robux if on sale, and no paid random items [PA].
- **Required fields:** the docs do not mark which fields are required. Open Cloud requires only `name` [OCDP][OCGP].
- **Group-owned:** Creator Hub permissions follow your group role [Groups].

### 6b. Open Cloud: supported (BETA)

All endpoints live on `https://apis.roblox.com`. Auth is an API key (`x-api-key`), OAuth 2.0, or cookie (not recommended) [OCDP][OCGP].

| Action | Endpoint | Scope | Rate limit |
|---|---|---|---|
| Create developer product | `POST /developer-products/v2/universes/{universeId}/developer-products` (multipart/form-data) | `developer-product:write` | 3/s per key owner |
| Update developer product | `PATCH /developer-products/v2/universes/{universeId}/developer-products/{productId}` (only the fields you send change) | `developer-product:write` | 3/s |
| List / get developer products | `GET .../developer-products/creator`, `GET .../developer-products/{productId}/creator` | `developer-product:read` | 10/s |
| Create game pass | `POST /game-passes/v1/universes/{universeId}/game-passes` (multipart) | `game-pass:write` | 5/s |
| Update game pass | `PATCH /game-passes/v1/universes/{universeId}/game-passes/{gamePassId}` | `game-pass:write` | 5/s |
| List / get game passes | `GET .../game-passes/creator`, `GET .../game-passes/{gamePassId}/creator` | `game-pass:read` | 10/s |

- **Create body:** `name` (required), `description`, `isForSale`, `price` (default price), `imageFile` (binary), `isRegionalPricingEnabled`, `isManagedPricingEnabled`. Developer product PATCH also accepts `storePageEnabled` [OCDP][OCGP].
- **Response** `DeveloperProductConfigV2`: `productId`, `name`, `description`, `iconImageAssetId`, `universeId`, `isForSale`, `storePageEnabled`, `priceInformation{defaultPriceInRobux, enabledFeatures[]}`, `isImmutable`, timestamps, `isManagedPricingEnabled`. `PricingFeature` values: `PriceOptimization`, `UserFixedPrice`, `RegionalPricing` [OCDP].
- Error codes include `DuplicateProductName`, `InvalidImageFile`, `InvalidPrice`, `PendingProductsLimitExceeded` and `UnauthorizedUniverseAccess` [OCDP].
- **There is no DELETE endpoint** for products or passes. Localized name, description and icon endpoints exist under `legacy-game-internationalization` (scope `legacy-developer-product:manage` / `legacy-game-pass:manage`, EXPERIMENTAL) [OCDP][OCGP].
- **Group-owned universe:**
  - A user-owned API key "can generally access any resource the user has permissions for, including ... group-owned games where they have the appropriate role" [AK].
  - For group automation, Roblox "**strongly recommend[s]**" a dedicated alternate account invited to the group with a minimal role, and creating the key on that account [AK].
  - Keys auto-expire after 60 days without use [AK].
  - The docs reviewed do not list group ownership as a restriction on these endpoints.
- Project rule: keys never go in the repo, and we do not read credentials unless the user asks (CLAUDE.md).

### 6c. Studio

- **Studio Experience Settings > Monetization > Developer Products:** "Lets you create and manage all developer products for your game". The same tab lists Badges, Paid Access and Private Servers, but **not passes** [ES] (page last updated 2026-07-30).
- **Studio MCP server** (`open_cloud_invoke` tool): this calls Open Cloud with Studio's token, so no API key is needed. Rules [MCP]:
  - The "**Money & monetization**" permission (`developer-product:*`, `game-pass:*`) must be enabled per game, per person, in Studio > MCP > MCP Permissions. It is not in the default "Balanced" level.
  - Roblox warns that this permission "can cost Robux".
  - The game must be published. For a group-owned game, "your group role must allow the actions you grant".
  - Some endpoints "reject the token Studio uses, even when the matching scope is enabled".
  - All `legacy-*` scopes, which include the localization endpoints, cannot be granted to MCP.

---

## Sources (all read 2026-11-05)

| Key | URL |
|---|---|
| MS | https://create.roblox.com/docs/reference/engine/classes/MarketplaceService |
| Enum-PPD | https://create.roblox.com/docs/reference/engine/enums/ProductPurchaseDecision |
| Enum-PPC | https://create.roblox.com/docs/reference/engine/enums/ProductPurchaseChannel |
| Enum-RD | https://create.roblox.com/docs/reference/engine/enums/ReceiptDecision |
| Enum-IT | https://create.roblox.com/docs/reference/engine/enums/InfoType |
| DP | https://create.roblox.com/docs/production/monetization/developer-products |
| PA | https://create.roblox.com/docs/production/monetization/passes |
| Shop | https://create.roblox.com/docs/production/monetization/shop |
| RP | https://create.roblox.com/docs/production/monetization/regional-pricing |
| MP | https://create.roblox.com/docs/production/monetization/managed-pricing |
| PO | https://create.roblox.com/docs/production/monetization/price-optimization |
| PRI | https://create.roblox.com/docs/production/monetization/paid-random-items |
| PDP | https://create.roblox.com/docs/cloud-services/data-stores/player-data-purchasing |
| PS | https://create.roblox.com/docs/reference/engine/classes/PolicyService |
| TM | https://create.roblox.com/docs/studio/testing-modes |
| ES | https://create.roblox.com/docs/studio/experience-settings |
| MCP | https://create.roblox.com/docs/studio/mcp-open-cloud |
| OCDP | https://create.roblox.com/docs/cloud/reference/features/developer-products |
| OCGP | https://create.roblox.com/docs/cloud/reference/features/game-passes |
| AK | https://create.roblox.com/docs/cloud/auth/api-keys |
| Icons | https://create.roblox.com/docs/production/publishing/experience-icons |
| Groups | https://create.roblox.com/docs/projects/groups |
| CS | https://about.roblox.com/community-standards |
| HC-SL | https://en.help.roblox.com/hc/en-us/articles/4409125091348-Monthly-Spending-Limits (blocked automated fetching with HTTP 403; facts are from search snippets) |
| HC-PC | https://en.help.roblox.com/hc/en-us/articles/30428310121620-Parental-Controls-Overview (same caveat) |
| DF-Mock | https://devforum.roblox.com/t/mock-purchases-in-studio/26974 (2016 announcement) |
| DF-GP | https://devforum.roblox.com/t/bought-gamepass-in-studio-and-still-got-charged-on-roblox/4749186 (staff replies 2026-07-21 to 2026-08-05) |
| DF-Prompt | https://devforum.roblox.com/t/roblox-studio-test-purchase-issue/4054772 (staff reply 2025-12-01) |
