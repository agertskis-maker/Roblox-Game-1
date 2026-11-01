--!strict
-- ShopPreviewCatalog: the ONE display catalog for the Shop preview (Lane 3, BRIEF M10-10, 2026-11-01).
--
-- Everything here is a PREVIEW fixture: names, benefit copy, art references and the Robux PREVIEW price proposals
-- (BRIEF M10-10b: Double Lap Pay 199, VIP 299, Expanded Paddock 149, Starter Pack 79, All Passes Bundle 549).
-- They are reversible design proposals for Brian L, never configured prices, never a real product, and nothing here
-- carries a product id or an asset id. The shape is meant to be replaced by real data from src/shared/Catalog:
-- keep the field names, change where the values come from.
--
--   Catalog.get(id) -> Offer?                       -- one offer by id
--   Catalog.list(kind) -> { Offer }                 -- offers of one kind, in display order
--   Catalog.sections() -> { Section }               -- Featured, Passes, Cash (flag), Style, Free, in page order
--   Catalog.priceLabel(offer) -> string             -- "PREVIEW · 199 Robux" (the word, never a symbol)
--   Catalog.bundleMath(bundleId) -> BundleMath?     -- component sum, saving and percent from the real fixture prices
--   Catalog.PreviewValueTag                         -- "PREVIEW VALUE": the mark every deal claim carries in fixtures
--
-- Honesty (BRIEF M10-11 / M10-11a): a deal claim (BEST DEAL, SAVE x%, a struck-through sum) is only ever DERIVED from
-- the component prices here, never typed in, and the Shop suppresses all three in its normal preview presentation:
-- they show only as a test fixture marked PREVIEW VALUE. No countdowns, no "LIMITED", no player counts, no paid
-- randomness, no gift, no real purchase.

local Catalog = {}

export type Kind = "Pass" | "Bundle" | "Starter" | "Style" | "Medal" | "Free" | "Cash"

export type Offer = {
	id: string,
	kind: Kind,
	name: string,
	tag: string?, -- the short coloured benefit tag
	body: string, -- one line, exactly what the player gets
	detail: string?, -- one more line (limits, offline caps)
	contents: string?, -- Starter Pack: what it is said to contain
	previewLine: string?, -- the conspicuous PREVIEW line
	icon: string, -- Icons2 name for the small tile
	art: string, -- ShopArt composition key
	fill: string, -- PreviewTokens.Shop.Fill key
	price: number?, -- Robux PREVIEW price, nil = none proposed
	includes: { string }?, -- Bundle: offer ids it names
	stamp: string?, -- NEW (the stamp is a catalog field, never a timer)
	actionLabel: string?, -- the button words when there is no price
	lockedText: string?, -- Medal cards: how it is earned
	note: string?, -- a calm line under the card
	amount: number?, -- Cash packs: the PREVIEW amount; nil shows "Amount pending"
	swatches: { Color3 }?, -- Style cards: the colours the live preview cycles through
}

export type Section = {
	id: string,
	title: string,
	subtitle: string?,
	icon: string,
	flag: string?, -- "cash": only present when the Cash flag is on
	offers: { string },
}

export type BundleMath = {
	componentSum: number,
	price: number,
	saving: number,
	percent: number, -- whole percent, rounded down so it never claims more than the math
	isBetter: boolean, -- true only when the bundle really costs less than its parts
	components: { string },
}

Catalog.PriceWord = "Robux"
Catalog.PreviewValueTag = "PREVIEW VALUE"
Catalog.PreviewNote = "PREVIEW: contents and price proposed"
Catalog.CashPreviewNote = "PREVIEW: amount and price proposed"
Catalog.StyleNote = "Looks only. Same driving stats."

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

local offers: { Offer } = {
	-- FEATURED -------------------------------------------------------------------------------------------------
	{
		id = "starter-pack",
		kind = "Starter",
		name = "STARTER PACK",
		tag = "FEATURED",
		body = "A fresh look for your first laps.",
		contents = "Starter paint + decal + car cosmetic + Cash boost",
		previewLine = Catalog.PreviewNote,
		icon = "StarterPack",
		art = "starter-pack",
		fill = "Hero",
		price = 79,
	},
	{
		id = "vip",
		kind = "Pass",
		name = "VIP",
		tag = "YOUR VIP LOOK",
		body = "VIP paints, a name tag and your own lounge.",
		detail = "Offline earnings can build for up to 12 hours. No boost to driving or racing.",
		icon = "VipCrown",
		art = "vip",
		fill = "Violet",
		price = 299,
		stamp = "NEW",
	},
	{
		id = "double-lap-pay",
		kind = "Pass",
		name = "Double Lap Pay",
		tag = "2x LAP PAY",
		body = "Your cars earn twice as much on your Raceway.",
		detail = "Online and offline. No change to race stats, Heat or Keys.",
		icon = "DoubleLapPay",
		art = "double-lap-pay",
		fill = "Teal",
		price = 199,
		stamp = "NEW",
	},
	-- PASSES ---------------------------------------------------------------------------------------------------
	{
		id = "expanded-paddock",
		kind = "Pass",
		name = "Expanded Paddock",
		tag = "+3 PARKING SPOTS",
		body = "Make room for three more favorites.",
		detail = "Extra spots above the normal maximum, plus a pit garage. Each car earns at its normal rate.",
		icon = "Paddock",
		art = "expanded-paddock",
		fill = "Sky",
		price = 149,
	},
	{
		id = "all-passes-bundle",
		kind = "Bundle",
		name = "ALL PASSES BUNDLE",
		tag = "THREE PASSES",
		body = "Three passes. One collection.",
		icon = "Bundle",
		art = "all-passes-bundle",
		fill = "Orange",
		price = 549,
		includes = { "double-lap-pay", "expanded-paddock", "vip" },
	},
	-- STYLE ----------------------------------------------------------------------------------------------------
	{
		id = "style-paint",
		kind = "Style",
		name = "PAINT PACK",
		body = "Give your car a fresh coat.",
		icon = "PaintBucket",
		art = "style-paint",
		fill = "Pink",
		actionLabel = "Preview colors",
		note = Catalog.StyleNote,
		swatches = {
			rgb(238, 58, 78),
			rgb(255, 146, 28),
			rgb(255, 214, 40),
			rgb(56, 204, 92),
			rgb(48, 206, 248),
			rgb(168, 98, 255),
		},
	},
	{
		id = "style-decal",
		kind = "Style",
		name = "DECAL PACK",
		body = "Pick your finishing touch.",
		icon = "Decal",
		art = "style-decal",
		fill = "Yellow",
		actionLabel = "Preview decals",
		note = Catalog.StyleNote,
		swatches = { rgb(255, 255, 255), rgb(255, 214, 40), rgb(48, 206, 248), rgb(255, 92, 186) },
	},
	{
		id = "style-wheel",
		kind = "Style",
		name = "WHEEL STYLE",
		body = "A new look for your wheels.",
		icon = "Wheel",
		art = "style-wheel",
		fill = "Sky",
		actionLabel = "Preview wheels",
		note = Catalog.StyleNote,
		swatches = { rgb(206, 216, 232), rgb(255, 204, 48), rgb(238, 58, 78), rgb(56, 204, 92) },
	},
	{
		id = "style-gold",
		kind = "Medal",
		name = "GOLD FINISH",
		body = "Earn Gold in the Stunt Circuit.",
		icon = "Trophy",
		art = "style-gold",
		fill = "Locked",
		lockedText = "Win Gold to unlock",
		note = "Earned, never bought.",
	},
	-- FREE -----------------------------------------------------------------------------------------------------
	{
		id = "free-legion",
		kind = "Free",
		name = "LEGION PAINT",
		body = "A community reward preview.",
		icon = "Gift",
		art = "free-legion",
		fill = "Violet",
		actionLabel = "See reward",
	},
	-- CASH (hidden behind a flag until Brian L and Adam approve Developer Products; no recommended prices) ------
	{
		id = "cash-pocket",
		kind = "Cash",
		name = "POCKET CASH",
		body = "A small top-up.",
		icon = "CashStack",
		art = "cash-pocket",
		fill = "Lime",
		amount = 500,
		previewLine = Catalog.CashPreviewNote,
	},
	{
		id = "cash-bag",
		kind = "Cash",
		name = "CASH BAG",
		body = "A bigger top-up.",
		icon = "CashBag",
		art = "cash-bag",
		fill = "Teal",
		amount = 2500,
		previewLine = Catalog.CashPreviewNote,
	},
	{
		id = "cash-chest",
		kind = "Cash",
		name = "CASH CHEST",
		body = "A chest of Cash.",
		icon = "CashChest",
		art = "cash-chest",
		fill = "Orange",
		amount = 10000,
		previewLine = Catalog.CashPreviewNote,
	},
	{
		id = "cash-vault",
		kind = "Cash",
		name = "CASH VAULT",
		body = "A vault of Cash.",
		icon = "CashVault",
		art = "cash-vault",
		fill = "Steel",
		amount = 50000,
		previewLine = Catalog.CashPreviewNote,
	},
}

local byId: { [string]: Offer } = {}
for _, offer in offers do
	byId[offer.id] = offer
end

local SECTIONS: { Section } = {
	{
		id = "featured",
		title = "Featured",
		icon = "Star",
		offers = { "starter-pack", "vip", "double-lap-pay" },
	},
	{
		id = "passes",
		title = "Passes",
		subtitle = "Forever yours · use them in every World",
		icon = "VipCrown",
		offers = { "all-passes-bundle", "double-lap-pay", "expanded-paddock", "vip" },
	},
	{
		id = "cash",
		title = "Cash",
		subtitle = "Preview only: amounts and prices are proposals",
		icon = "CashStack",
		flag = "cash",
		offers = { "cash-pocket", "cash-bag", "cash-chest", "cash-vault" },
	},
	{
		id = "style",
		title = "Style",
		subtitle = Catalog.StyleNote,
		icon = "PaintBucket",
		offers = { "style-paint", "style-decal", "style-wheel", "style-gold" },
	},
	{
		id = "free",
		title = "Free",
		subtitle = "Rewards for joining in",
		icon = "Gift",
		offers = { "free-legion" },
	},
}

-- The hero carousel order (M10-03): Starter Pack first for a player who does not own it, then VIP, Double Lap Pay and
-- the bundle.
Catalog.HeroOrder = { "starter-pack", "vip", "double-lap-pay", "all-passes-bundle" }
-- The passes the collection bar counts (M10-04: "Collection 0 / 3 owned").
Catalog.PassIds = { "double-lap-pay", "expanded-paddock", "vip" }

function Catalog.get(id: string): Offer?
	return byId[id]
end

function Catalog.list(kind: Kind): { Offer }
	local out: { Offer } = {}
	for _, offer in offers do
		if offer.kind == kind then
			table.insert(out, offer)
		end
	end
	return out
end

function Catalog.all(): { Offer }
	return table.clone(offers)
end

-- Sections in page order. `cashOn` keeps the Cash section (M10-02, M10-03a: with the flag off the section and its tab
-- do not exist at all).
function Catalog.sections(cashOn: boolean?): { Section }
	local out: { Section } = {}
	for _, section in SECTIONS do
		if section.flag ~= "cash" or cashOn == true then
			table.insert(out, section)
		end
	end
	return out
end

local function comma(n: number): string
	local digits = string.format("%d", math.floor(math.max(n, 0)))
	local out = digits:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	if out:sub(1, 1) == "," then
		out = out:sub(2)
	end
	return out
end
Catalog.comma = comma

-- "199 Robux" (the word; never a symbol, never a dollar sign or the Cash coin: M10-10c).
function Catalog.priceText(price: number): string
	return comma(price) .. " " .. Catalog.PriceWord
end

-- The label a price button carries in this build: "PREVIEW · 199 Robux", or the action words when no price is proposed.
function Catalog.priceLabel(offer: Offer): string
	local price = offer.price
	if price ~= nil then
		return "PREVIEW · " .. Catalog.priceText(price)
	end
	if offer.kind == "Cash" then
		return "PREVIEW · price pending"
	end
	return offer.actionLabel or "Coming soon"
end

-- Component sum, saving and percent from the fixture prices (nil for anything that is not a priced bundle).
function Catalog.bundleMath(bundleId: string): BundleMath?
	local bundle = byId[bundleId]
	if not bundle or bundle.kind ~= "Bundle" or bundle.price == nil or bundle.includes == nil then
		return nil
	end
	local sum = 0
	local components: { string } = {}
	for _, id in bundle.includes do
		local part = byId[id]
		if not part or part.price == nil then
			return nil -- one unpriced part: no claim at all, never a partial sum
		end
		sum += part.price
		table.insert(components, id)
	end
	local saving = sum - bundle.price
	local percent = if sum > 0 and saving > 0 then math.floor(saving / sum * 100) else 0
	return {
		componentSum = sum,
		price = bundle.price,
		saving = math.max(saving, 0),
		percent = percent,
		isBetter = saving > 0,
		components = components,
	}
end

-- Names of the included passes, for the bundle card ("Double Lap Pay, Expanded Paddock and VIP").
function Catalog.includedNames(bundleId: string): { string }
	local out: { string } = {}
	local bundle = byId[bundleId]
	if bundle and bundle.includes then
		for _, id in bundle.includes do
			local part = byId[id]
			if part then
				table.insert(out, part.name)
			end
		end
	end
	return out
end

-- True when any pass the bundle includes is in `owned` (the bundle then shows the disabled "already own part" state;
-- it never grants three passes at once and never sells a duplicate entitlement: M10-08a).
function Catalog.ownsPartOf(bundleId: string, owned: { [string]: boolean }): boolean
	local bundle = byId[bundleId]
	if not bundle or not bundle.includes then
		return false
	end
	for _, id in bundle.includes do
		if owned[id] then
			return true
		end
	end
	return false
end

return Catalog
