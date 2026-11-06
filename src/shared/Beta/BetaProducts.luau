--!strict
-- BETA-ONLY STAND-IN for Brian L's product list (the Robux table in vault/design/specs/economy-v1-answers-from-adam.md).
-- Same contract: one entry per Robux item, the server grants from it, the client prompts from it. Delete when his real
-- module lands.
--
-- Round 6 (R-01, Adam's decisions of 2026-11-05, brief section 0 items 6 and 7). Every Robux item, its kind, its Roblox id,
-- its PREVIEW price and its art. Kinds (Claude Code's call, recorded in the Round 6 ledger):
--   * DevProduct: everything used up or granted as Cash or a car (the respawn, the five Cash packs, the Starter Pack), and the
--     All Passes Bundle, because one purchase must grant three passes: it writes them into the save's `Owned` list.
--   * GamePass: everything permanent (Double Lap Pay, Expanded Paddock, VIP, the four Robux trails). Roblox keeps a pass
--     owned for good, so it survives the move from the beta save to Brian L's real save.
-- A player owns a pass when Roblox says they own the Game Pass OR the save's `Owned` list has its id (from the bundle).
--
-- `robloxId` 0 means "not created yet": in Studio a press prints a clear "product not created yet" line instead of
-- prompting, and the published beta shows Coming soon anyway while `BetaConfig.RealPurchases` is false.

export type Kind = "DevProduct" | "GamePass"
export type Item = {
	id: string, -- the Shop / cosmetics id the screens already use
	name: string,
	kind: Kind,
	robloxId: number, -- Developer Product id or Game Pass id (0 = not created yet)
	robux: number, -- PREVIEW price; buttons show the product's own price when Roblox returns it
	art: number?, -- the product icon's image asset id (R-07), nil until uploaded
	grants: { string }?, -- the bundle: the pass ids it grants
	oncePerPlayer: boolean?, -- the Starter Pack
}

local BetaProducts = {}

local items: { Item } = {
	{ id = "respawn", name = "Respawn", kind = "DevProduct", robloxId = 0, robux = 19 },
	{ id = "cash-10", name = "Cash pack, 10 minutes", kind = "DevProduct", robloxId = 0, robux = 49 },
	{ id = "cash-30", name = "Cash pack, 30 minutes", kind = "DevProduct", robloxId = 0, robux = 99 },
	{ id = "cash-60", name = "Cash pack, 1 hour", kind = "DevProduct", robloxId = 0, robux = 179 },
	{ id = "cash-180", name = "Cash pack, 3 hours", kind = "DevProduct", robloxId = 0, robux = 449 },
	{ id = "cash-480", name = "Cash pack, 8 hours", kind = "DevProduct", robloxId = 0, robux = 899 },
	{ id = "starter-pack", name = "Starter Pack", kind = "DevProduct", robloxId = 0, robux = 79, oncePerPlayer = true },
	{
		id = "all-passes-bundle",
		name = "All Passes Bundle",
		kind = "DevProduct",
		robloxId = 0,
		robux = 549,
		grants = { "double-lap-pay", "expanded-paddock", "vip" },
	},
	{ id = "double-lap-pay", name = "Double Lap Pay", kind = "GamePass", robloxId = 0, robux = 199 },
	{ id = "expanded-paddock", name = "Expanded Paddock", kind = "GamePass", robloxId = 0, robux = 149 },
	{ id = "vip", name = "VIP", kind = "GamePass", robloxId = 0, robux = 299 },
	{ id = "flame_rush", name = "Flame Rush trail", kind = "GamePass", robloxId = 0, robux = 99 },
	{ id = "confetti_party", name = "Confetti Party trail", kind = "GamePass", robloxId = 0, robux = 129 },
	{ id = "rainbow_runway", name = "Rainbow Runway trail", kind = "GamePass", robloxId = 0, robux = 199 },
	{ id = "comet_tail", name = "Comet Tail trail", kind = "GamePass", robloxId = 0, robux = 249 },
}

-- The Starter Pack's contents (decision 0038): Brawler (one copy instead when already owned), $5,000, a paint and a decal.
BetaProducts.Starter = table.freeze({ car = "Brawler", cash = 5000, cosmetics = { "taxi_gold", "racing_stripe" } })
-- VIP's paints (PREVIEW names from the cosmetics catalog) and its offline cap.
-- Round 7 (decision 0042 item 12): the VIP pass shows these (the server treats them as owned while the player has VIP).
BetaProducts.VipCosmetics = table.freeze({ "vip_royal", "vip_neon", "vip_gradient" })
BetaProducts.VipOfflineHours = 30 -- Round 7 (decision 0042 item 11): VIP Welcome back cap, same 40% rate (was 12)

-- Ids filled in after the products are created (R-01). Kept apart from the list so one edit updates them.
local ids: { [string]: number } = {}

for _, item in items do
	item.robloxId = ids[item.id] or item.robloxId
	table.freeze(item)
end
BetaProducts.Items = table.freeze(items) :: { Item }

local byId: { [string]: Item } = {}
local byProduct: { [number]: Item } = {}
local byPass: { [number]: Item } = {}
for _, item in items do
	byId[item.id] = item
	if item.robloxId ~= 0 then
		if item.kind == "DevProduct" then
			byProduct[item.robloxId] = item
		else
			byPass[item.robloxId] = item
		end
	end
end

function BetaProducts.get(id: string): Item?
	return byId[id]
end

function BetaProducts.byProductId(productId: number): Item?
	return byProduct[productId]
end

function BetaProducts.byPassId(passId: number): Item?
	return byPass[passId]
end

function BetaProducts.passes(): { Item }
	local out = {}
	for _, item in items do
		if item.kind == "GamePass" then
			table.insert(out, item)
		end
	end
	return out
end

function BetaProducts.created(item: Item): boolean
	return item.robloxId ~= 0
end

return table.freeze(BetaProducts)
