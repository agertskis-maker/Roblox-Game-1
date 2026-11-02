--!strict
-- ShopCards: builders for every card on the Shop page (Lane 3, BRIEF M10-03 .. M10-08 and Round 2 N6, 2026-11-01), all
-- made from ShopKit parts and the icon family. The page calls these; they never decide what a press MEANS: a press goes
-- through env.press (the screen's one path to the purchase adapter), and a card only shows the ViewState it is given.
--
--   Cards.offer(env, parent, offer, plan) -> View      a pass, bundle, style, free, cash or side card
--   Cards.measure(env, offer, plan) -> number          the height that card needs for its own copy
--   Cards.hero(env, parent, size, z) -> Hero           the Featured carousel
--   Cards.deal(env, parent, size, z) -> View?          the BEST DEAL banner (the All Passes Bundle) under the hero
--
-- A card is sized from its content (TextService measures the copy), so a 30 percent longer string makes a taller card
-- instead of clipping; every card in a row then shares the tallest height. Copy is exactly the brief's (M10-04a,
-- M10-05a, M10-06a, M10-07a, M10-08a); the PREVIEW lines stay conspicuous.
--
-- COLOUR (N6-01, N6-02a): each card has its own strong gradient (the catalog's `fill`), a white headline with a deep navy
-- outline, and its descriptive copy and price on the quiet plate (ShopKit.plate), never straight on the glow.
--
-- MOTION (N6-02, N6-02b): a card registers its effects with env.motion (the Shop's one animator): the gradient sway on
-- the hero, the deal, the side cards and the pass cards, the diagonal shine on the hero and the deal (3 s apart), the
-- breathing price button (the hero's, else the deal's) and the pooled sparkles (the deal first, one on the hero). Nothing
-- here starts its own loop.
--
-- HONESTY (M10-11, N6-03, N6-03a): BEST DEAL, SAVE x% and a struck-through sum are the normal view, built only from
-- Catalog.bundleMath (savings = floor(100 * (componentTotal - bundlePrice) / componentTotal) for the same fixture
-- currency), always beside a PREVIEW VALUE tag and a price that says PREVIEW. They are hidden when the total is zero, a
-- part is unpriced, the saving is not positive, or the bundle cannot be bought as a whole right now. They are named
-- BestDealRibbon, SaveChip, StrikePrice and PreviewValueTag so the debug state can count them.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Prototype = script.Parent.Parent.Parent
local Arcade = require(Prototype.Arcade)
local PreviewTokens = require(Prototype.PreviewTokens)
local ShopKit = require(Prototype.ShopKit)
local ShopMotion = require(Prototype.ShopMotion)
local ShopArt = require(script.Parent.ShopArt)
local ShopLayout = require(script.Parent.ShopLayout)
local ShopPalette = require(script.Parent.ShopPalette)
local Catalog = require(ReplicatedStorage.Shared.UI.ShopPreviewCatalog)
local Tokens = require(ReplicatedStorage.Shared.UI.Tokens)
local Trove = require(ReplicatedStorage.Packages.Trove)

local make = Arcade.make
local WHITE = Color3.new(1, 1, 1)
local LIP = 5 -- the card lip ShopKit.card draws
local BUTTON_H = Tokens.Touch.Primary -- every price button is a primary action: 56 px
local SWATCH = Tokens.Touch.Minimum -- a swatch is a touch target: 48 px

local Cards = {}

export type ViewState = { kind: ShopKit.PriceState, label: string }

export type Fixtures = {
	missingArt: boolean,
	previewValue: boolean, -- BEST DEAL / SAVE x% / the struck-through sum: on by default, a fixture can switch it off
	longText: boolean,
	cashAmountsPending: boolean,
}

export type View = {
	offerId: string,
	root: Frame,
	hit: GuiObject?,
	button: ShopKit.PriceButton?,
	apply: (ViewState) -> (),
	setTint: ((Color3?) -> ())?,
}

export type Env = {
	trove: Trove.Trove,
	tier: ShopLayout.Tier,
	fixtures: Fixtures,
	motion: ShopMotion.Animator,
	stateOf: (offerId: string) -> ViewState,
	press: (offerId: string, source: GuiObject?) -> (),
	register: (offerId: string, view: View) -> (),
	swatch: (offerId: string, colour: Color3?) -> (),
	text: (text: string) -> string, -- the "30 percent longer strings" fixture
	owned: (offerId: string) -> boolean,
}

export type Plan = {
	w: number,
	h: number, -- ignored by measure(); the builder uses it as the final height
	z: number,
	orientation: "Tall" | "Wide",
	showDetail: boolean,
	big: boolean?, -- the bundle: a bigger name
	nameSize: number?, -- override the name's size
	showTag: boolean?, -- default true
	showBody: boolean?, -- default true
	artSide: number?, -- override
	buttonRight: boolean?, -- Wide: the button sits at the right edge, vertically centred (the Free card)
	stamp: boolean?, -- show the catalog stamp (NEW)
	name: string?,
	animate: boolean?, -- register the card's gradient glow with the animator
	priority: number?, -- the animator's budget priority (a lower number is kept first)
}

type Item = { kind: string, h: number, text: string?, size: number? }

-- A steady offset in seconds from an id, so neighbouring cards are never in step.
local function phaseOf(key: string): number
	local sum = 0
	for i = 1, #key do
		sum += string.byte(key, i) * i
	end
	return (sum % 600) / 100
end

local function amountText(env: Env, offer: Catalog.Offer): string
	if offer.amount == nil or env.fixtures.cashAmountsPending then
		return "Amount pending" -- never zero and never an endless spinner (M10-07a)
	end
	return "$" .. Catalog.comma(offer.amount) .. " Cash"
end

local function includesText(offer: Catalog.Offer): string
	local names = Catalog.includedNames(offer.id)
	if #names == 0 then
		return ""
	end
	if #names == 1 then
		return "Includes " .. names[1]
	end
	return "Includes " .. table.concat(names, ", ", 1, #names - 1) .. " and " .. names[#names]
end

-- The deal claim for a bundle, or nil when it must not be shown: the fixture is off, a part is unpriced (bundleMath is
-- nil), the saving is not positive or rounds to 0 percent, or the component total is zero.
local function dealOf(env: Env, offerId: string): Catalog.BundleMath?
	if not env.fixtures.previewValue then
		return nil
	end
	local deal = Catalog.bundleMath(offerId)
	if deal == nil or not deal.isBetter or deal.componentSum <= 0 or deal.percent <= 0 then
		return nil
	end
	return deal
end

-- A saving is only claimed on a bundle the player could buy as a whole right now.
local function claimable(state: ViewState): boolean
	return state.kind == "Idle" or state.kind == "Pending" or state.kind == "Error"
end

local function artSideFor(plan: Plan): number
	if plan.artSide then
		return plan.artSide
	end
	if plan.orientation == "Tall" then
		return math.floor((plan.w - 20) * 0.62)
	end
	return math.min(math.floor(plan.w * 0.3), 150)
end

local function columnWidth(plan: Plan): number
	if plan.orientation == "Tall" then
		return plan.w - 20
	end
	return plan.w - artSideFor(plan) - 34
end

-- The text rows of a card, in order, with their heights. measure() and the builder share this list, so the height a
-- card asks for is the height it builds.
local function itemsFor(env: Env, offer: Catalog.Offer, plan: Plan): { Item }
	local items: { Item } = {}
	local colW = columnWidth(plan)
	local nameSize = plan.nameSize or (if plan.big then 26 else 22)
	table.insert(items, { kind = "name", h = nameSize + 6, text = env.text(offer.name), size = nameSize })
	if offer.tag and plan.showTag ~= false then
		table.insert(items, { kind = "tag", h = 26, text = offer.tag, size = 16 })
	end
	if offer.kind == "Cash" then
		table.insert(items, { kind = "amount", h = 32, text = amountText(env, offer), size = 24 })
	end
	if plan.showBody ~= false then
		local body = env.text(offer.body)
		table.insert(items, { kind = "body", h = ShopKit.textHeight(body, 17, colW - 6), text = body, size = 17 })
	end
	if offer.includes then
		local text = includesText(offer)
		table.insert(items, { kind = "includes", h = ShopKit.textHeight(text, 16, colW - 6), text = text, size = 16 })
	end
	if offer.kind == "Bundle" and dealOf(env, offer.id) ~= nil then
		table.insert(items, { kind = "claims", h = 30 })
	end
	if plan.showDetail and offer.detail then
		local detail = env.text(offer.detail)
		table.insert(items, { kind = "detail", h = ShopKit.textHeight(detail, 16, colW - 6), text = detail, size = 16 })
	end
	if offer.kind == "Medal" and offer.note then
		table.insert(
			items,
			{ kind = "note", h = ShopKit.textHeight(offer.note, 16, colW - 6), text = offer.note, size = 16 }
		)
	end
	if offer.kind == "Cash" and offer.previewLine then
		table.insert(items, {
			kind = "preview",
			h = ShopKit.textHeight(offer.previewLine, 16, colW - 6),
			text = offer.previewLine,
			size = 16,
		})
	end
	if offer.swatches then
		table.insert(items, { kind = "swatches", h = SWATCH })
	end
	return items
end

local function itemsHeight(items: { Item }): number
	local total = 0
	for _, item in items do
		total += item.h
	end
	return total + 4 * math.max(#items - 1, 0)
end

-- The height a card needs: the art, the text rows and the button, with padding.
function Cards.measure(env: Env, offer: Catalog.Offer, plan: Plan): number
	local items = itemsFor(env, offer, plan)
	local text = itemsHeight(items)
	local side = artSideFor(plan)
	if plan.orientation == "Tall" then
		return 10 + side + 6 + text + 8 + (BUTTON_H + 4) + 14 + LIP
	end
	return math.max(side + 24, 10 + text + 8 + (BUTTON_H + 4) + 14) + LIP
end

-- The honest deal claims: a SAVE chip, the struck-through sum and the PREVIEW VALUE tag in one row. Returns the row
-- (so the card can hide it while the bundle cannot be bought) or nil when no claim is allowed.
local function buildClaims(env: Env, parent: Instance, offer: Catalog.Offer, z: number, order: number): Frame?
	local deal = dealOf(env, offer.id)
	if deal == nil then
		return nil
	end
	local row: Frame = make("Frame", {
		Name = "Claims",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 30),
		LayoutOrder = order,
		ZIndex = z,
		Parent = parent,
	})
	make("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = row,
	})
	local save =
		ShopKit.chip(row, { text = "SAVE " .. deal.percent .. "%", fill = "Red", size = 16, z = z, name = "SaveChip" })
	save.LayoutOrder = 1
	local strike: TextLabel = make("TextLabel", {
		Name = "StrikePrice",
		BackgroundTransparency = 1,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 26),
		FontFace = PreviewTokens.Font(),
		RichText = true,
		Text = "<s>" .. Catalog.priceText(deal.componentSum) .. "</s>",
		TextSize = 16,
		TextColor3 = ShopPalette.Color.TextSoft,
		LayoutOrder = 2,
		ZIndex = z,
		Parent = row,
	})
	Arcade.outline(strike, "Minor")
	local tag = ShopKit.chip(row, {
		text = Catalog.PreviewValueTag,
		fill = "Yellow",
		size = 16,
		z = z,
		name = "PreviewValueTag",
		dark = true,
	})
	tag.LayoutOrder = 3
	return row
end

-- A swatch row for a Style card: the live preview recolours the car art (a local look only, never a purchase).
local function buildSwatches(
	env: Env,
	parent: Instance,
	offer: Catalog.Offer,
	z: number,
	order: number,
	centred: boolean
)
	local row: Frame = make("Frame", {
		Name = "Swatches",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, SWATCH),
		LayoutOrder = order,
		ZIndex = z,
		Parent = parent,
	})
	make("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = if centred then Enum.HorizontalAlignment.Center else Enum.HorizontalAlignment.Left,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, 0),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = row,
	})
	for i, colour in offer.swatches or {} do
		-- the button is the 48 px touch target; the 32 px dot inside it is only the picture
		local hit: TextButton = make("TextButton", {
			Name = "Swatch" .. i,
			Size = UDim2.fromOffset(SWATCH, SWATCH),
			BackgroundTransparency = 1,
			AutoButtonColor = false,
			Text = "",
			Selectable = true,
			LayoutOrder = i,
			ZIndex = z,
			Parent = row,
		})
		local chip: Frame = make("Frame", {
			Name = "Dot",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(32, 32),
			BackgroundColor3 = colour,
			ZIndex = z,
			Parent = hit,
		})
		Arcade.corner(chip, 16)
		make("UIStroke", {
			Thickness = 2.5,
			Color = WHITE,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			Parent = chip,
		})
		env.trove:Connect(hit.Activated, function()
			env.swatch(offer.id, colour)
		end)
	end
end

-- The breathing of one primary price button: only while it is idle and untouched (ShopMotion keeps one at a time).
local function breatheButton(env: Env, button: ShopKit.PriceButton, priority: number)
	env.motion.breathe({
		scale = button.breath,
		host = button.root,
		priority = priority,
		frozen = function(): boolean
			return button.getState() ~= "Idle" or button.isHover() or button.isPressed()
		end,
	})
end

-- One offer card: art, the text rows and a price button. `plan.orientation` Tall stacks everything centred under the art;
-- Wide puts the art on the left and the copy on the right. The copy and the button sit on the quiet plate.
function Cards.offer(env: Env, parent: Instance, offer: Catalog.Offer, plan: Plan): View
	local z = plan.z
	local w, h = plan.w, plan.h
	local tall = plan.orientation == "Tall"
	local contentZ = z + 6
	local view: View
	local card = ShopKit.card(parent, {
		name = plan.name or ("Offer_" .. offer.id),
		size = Vector2.new(w, h),
		fill = offer.fill,
		rotation = ShopPalette.Angle.Card,
		z = z,
		trove = env.trove,
		pattern = true,
		interactive = true,
		lip = LIP,
		onActivate = function()
			env.press(offer.id, view.hit)
		end,
	})
	local content = card.content
	local visualH = h - LIP
	local side = artSideFor(plan)
	local colX = if tall then 10 else side + 22
	local colW = columnWidth(plan)

	if plan.animate then
		env.motion.gradient({
			gradient = card.gradient,
			recipe = "Card",
			phase = phaseOf(offer.id),
			host = card.root,
			priority = plan.priority or 5,
		})
	end

	-- the quiet plate under the copy and the price
	local plateLeft = if tall then 6 else colX - 8
	local plateTop = if tall then 10 + side - 4 else 8
	ShopKit.plate(content, {
		name = "CopyPlate",
		position = UDim2.fromOffset(plateLeft, plateTop),
		size = UDim2.fromOffset(w - plateLeft - 6, visualH - plateTop - 6),
		z = contentZ - 1,
	})

	local art = ShopArt.build(content, offer.art, side, { z = contentZ, missing = env.fixtures.missingArt })
	if tall then
		art.root.Position = UDim2.fromOffset(math.floor((w - side) / 2), 10)
	else
		art.root.Position = UDim2.fromOffset(12, math.floor((visualH - side) / 2))
	end

	local column: Frame = make("Frame", {
		Name = "Column",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(colX, if tall then 10 + side + 6 else 10),
		Size = UDim2.fromOffset(colW, 10),
		AutomaticSize = Enum.AutomaticSize.Y,
		ZIndex = contentZ,
		Parent = content,
	})
	make("UIListLayout", {
		Padding = UDim.new(0, 4),
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = if tall then Enum.HorizontalAlignment.Center else Enum.HorizontalAlignment.Left,
		Parent = column,
	})
	local xAlign = if tall then Enum.TextXAlignment.Center else Enum.TextXAlignment.Left

	local items = itemsFor(env, offer, plan)
	if not tall then
		-- a short Wide card (a side card) keeps the button clear of the text: optional rows go first, the benefit last
		local available = visualH - 10 - (BUTTON_H + 4) - 14
		for _, dropKind in { "detail", "note", "claims", "includes", "swatches", "preview", "tag", "body" } do
			if itemsHeight(items) <= available then
				break
			end
			for index, item in items do
				if item.kind == dropKind then
					table.remove(items, index)
					break
				end
			end
		end
	end
	local claimParts: { GuiObject } = {}
	local ribbonOnCard = offer.kind == "Bundle" and dealOf(env, offer.id) ~= nil
	for order, item in items do
		if item.kind == "name" then
			local label = ShopKit.label(
				column,
				item.text or "",
				item.size or 22,
				{ name = "Name", xAlign = xAlign, z = contentZ }
			)
			-- a bundle that wears the BEST DEAL ribbon keeps its name clear of the ribbon in the top corner
			label.Size = UDim2.new(1, if ribbonOnCard and not tall then -64 else 0, 0, item.h)
			label.LayoutOrder = order
		elseif item.kind == "tag" then
			local chip = ShopKit.chip(column, {
				text = item.text or "",
				fill = "Yellow",
				size = 16,
				z = contentZ,
				name = "Tag",
				dark = true,
			})
			chip.LayoutOrder = order
		elseif item.kind == "amount" then
			local label = ShopKit.label(column, item.text or "", 24, {
				name = "Amount",
				xAlign = xAlign,
				italic = true,
				face = "Cash",
				z = contentZ,
			})
			label.Size = UDim2.new(1, 0, 0, item.h)
			label.LayoutOrder = order
		elseif item.kind == "claims" then
			local row = buildClaims(env, column, offer, contentZ, order)
			if row then
				table.insert(claimParts, row)
			end
		elseif item.kind == "swatches" then
			buildSwatches(env, column, offer, contentZ, order, tall)
		else
			-- body, includes, detail, note, preview: wrapped copy
			local colour = if item.kind == "body"
				then WHITE
				elseif item.kind == "preview" then ShopPalette.Color.Warn
				else ShopPalette.Color.TextSoft
			local p = ShopKit.paragraph(column, item.text or "", item.size or 16, {
				name = item.kind,
				colour = colour,
				xAlign = xAlign,
				z = contentZ,
			})
			p.LayoutOrder = order
		end
	end

	-- the price button, anchored to the bottom (Tall) or to the column's foot (Wide)
	local buttonW = math.min(colW, if tall then colW else 300)
	local state = env.stateOf(offer.id)
	local button = ShopKit.priceButton(content, {
		name = "Price",
		label = state.label,
		size = Vector2.new(buttonW, BUTTON_H),
		z = contentZ + 1,
		trove = env.trove,
		onActivate = function()
			env.press(offer.id, view.button and view.button.body or nil)
		end,
	})
	if tall then
		button.root.AnchorPoint = Vector2.new(0.5, 1)
		button.root.Position = UDim2.new(0.5, 0, 0, visualH - 10)
	elseif plan.buttonRight then
		button.root.AnchorPoint = Vector2.new(1, 0.5)
		button.root.Position = UDim2.new(1, -16, 0.5, 0)
	else
		button.root.AnchorPoint = Vector2.new(0, 1)
		button.root.Position = UDim2.fromOffset(colX, visualH - 10)
	end

	if plan.stamp and offer.stamp then
		local stamp = ShopKit.stamp(content, { text = offer.stamp, fill = "Red", size = 16, z = contentZ + 4 })
		stamp.Position = UDim2.fromOffset(10, 10)
	end
	-- the diagonal BEST DEAL ribbon, only when the bundle truly costs less than its parts (N6-03)
	if offer.kind == "Bundle" and dealOf(env, offer.id) ~= nil then
		local ribbon = ShopKit.ribbon(
			content,
			{ text = "BEST DEAL", fill = "Red", size = 84, z = contentZ + 8, name = "BestDealRibbon" }
		)
		table.insert(claimParts, ribbon.root)
	end

	view = {
		offerId = offer.id,
		root = card.root,
		hit = card.hit,
		button = button,
		apply = function(viewState: ViewState)
			button.setState(viewState.kind, viewState.label)
			local show = claimable(viewState)
			for _, part in claimParts do
				part.Visible = show
			end
		end,
		setTint = art.setTint,
	}
	view.apply(state)
	env.register(offer.id, view)
	return view
end

-- HERO ---------------------------------------------------------------------------------------------------------

export type Hero = {
	root: Frame,
	count: () -> number,
	index: () -> number,
	setIndex: (index: number) -> (),
	advance: () -> (),
	isEngaged: () -> boolean,
	button: () -> ShopKit.PriceButton?,
	visible: (boolean) -> (),
}

-- The Featured carousel (M10-03): a big gradient card with the pattern, a FEATURED tag, a giant outlined headline, one
-- benefit line on the quiet plate, large art on the right, a big lime price button, arrows and page dots. The Starter
-- Pack leads for a player who does not own it. It never rotates by itself here: the screen's carousel tick calls
-- advance() only while nothing is hovered, pressed or focused (M10-03a). The gradient sways, one shine sweeps it every
-- 6 s, one sparkle drifts over the art and its price button breathes (all through env.motion).
function Cards.hero(env: Env, parent: Instance, size: Vector2, z: number): Hero
	local ids: { string } = {}
	for _, id in Catalog.HeroOrder do
		if id ~= "starter-pack" or not env.owned(id) then
			table.insert(ids, id)
		end
	end
	local tier = env.tier
	local phone = tier == "Phone"
	local contentZ = z + 6
	local current = 1
	local card: ShopKit.Card
	card = ShopKit.card(parent, {
		name = "Hero",
		size = size,
		fill = "Hero",
		rotation = ShopPalette.Angle.Hero,
		z = z,
		trove = env.trove,
		pattern = true,
		interactive = true,
		lip = LIP,
		onActivate = function()
			env.press(ids[current], card.hit)
		end,
	})
	local content = card.content
	local visualH = size.Y - LIP
	local compact = visualH < (if phone then 150 else 120) -- a short hero: the headline and the button, the benefit only with room
	local leftW = math.floor(size.X * (if phone then 0.58 else 0.52)) - 22
	local artPx = math.floor(math.min(visualH - 24, size.X * 0.4))
	local titleSize = if tier == "Desktop" then 54 elseif tier == "Tablet" then 40 elseif compact then 28 else 34
	local bodySize = if tier == "Desktop" then 20 else 17
	local buttonH = if visualH < 110 then Tokens.Touch.Minimum else BUTTON_H
	local showBenefit = not compact
	local showContents = visualH >= 290

	env.motion.gradient({
		gradient = card.gradient,
		recipe = "Hero",
		phase = 0,
		host = card.root,
		priority = 2,
	})
	local shine = ShopKit.shine(card.face, { radius = 16, z = z + 14, trove = env.trove })
	env.motion.shine({ host = card.root, play = shine.play, rest = shine.hide, phase = 0, priority = 2 })
	env.motion.sparkles({
		parent = content,
		z = contentZ + 6,
		marks = 1,
		region = { 0.6, 0.12, 0.94, 0.7 },
		seed = 17,
		priority = 2,
	})

	local slides: { Frame } = {}
	local buttons: { ShopKit.PriceButton } = {}
	local arts: { Frame } = {}
	for i, id in ids do
		local offer = Catalog.get(id)
		if not offer then
			continue
		end
		local slide: Frame = make("Frame", {
			Name = "Slide_" .. id,
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Visible = i == 1,
			ZIndex = contentZ,
			Parent = content,
		})
		slides[i] = slide
		local art = ShopArt.build(slide, offer.art, artPx, { z = contentZ + 1, missing = env.fixtures.missingArt })
		art.root.AnchorPoint = Vector2.new(1, 0.5)
		art.root.Position = UDim2.new(1, -(if phone then 16 else 26), 0.5, -(if phone then 10 else 0))
		arts[i] = art.root

		local column: Frame = make("Frame", {
			Name = "Copy",
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 22, 0.5, 0),
			Size = UDim2.fromOffset(leftW, 10),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			ZIndex = contentZ + 2,
			Parent = slide,
		})
		make("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = column })
		local order = 0
		local function nextOrder(): number
			order += 1
			return order
		end
		-- on a short phone the tag rides the top right corner instead of costing the copy column a row
		local tag = ShopKit.chip(
			if phone then slide else column,
			{ text = "FEATURED", fill = "Yellow", size = 16, z = contentZ + 3, name = "FeaturedTag", dark = true }
		)
		if phone then
			tag.AnchorPoint = Vector2.new(1, 0)
			tag.Position = UDim2.new(1, -16, 0, 10)
		else
			tag.LayoutOrder = nextOrder()
		end
		local title = ShopKit.label(column, env.text(offer.name), titleSize, {
			name = "Headline",
			z = contentZ + 2,
			outline = if compact then 3 else 4,
		})
		title.Size = UDim2.new(1, 0, 0, titleSize + 8)
		title.LayoutOrder = nextOrder()
		if showBenefit then
			-- the benefit (and, when roomy, what the pack holds) on the quiet plate
			local copyPlate = ShopKit.plate(column, {
				name = "CopyPlate",
				size = UDim2.new(1, 0, 0, 10),
				automatic = true,
				z = contentZ + 1,
			})
			copyPlate.LayoutOrder = nextOrder()
			make("UIPadding", {
				PaddingLeft = UDim.new(0, 8),
				PaddingRight = UDim.new(0, 8),
				PaddingTop = UDim.new(0, 5),
				PaddingBottom = UDim.new(0, 5),
				Parent = copyPlate,
			})
			make(
				"UIListLayout",
				{ Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder, Parent = copyPlate }
			)
			local body =
				ShopKit.paragraph(copyPlate, env.text(offer.body), bodySize, { name = "Benefit", z = contentZ + 2 })
			body.LayoutOrder = 1
			if showContents and offer.contents then
				local contents = ShopKit.paragraph(copyPlate, offer.contents, 16, {
					name = "Contents",
					colour = ShopPalette.Color.TextSoft,
					z = contentZ + 2,
				})
				contents.LayoutOrder = 2
			end
			if offer.kind == "Bundle" then
				local includes = ShopKit.paragraph(copyPlate, includesText(offer), 16, {
					name = "Includes",
					colour = ShopPalette.Color.TextSoft,
					z = contentZ + 2,
				})
				includes.LayoutOrder = 3
			end
		end
		local claimParts: { GuiObject } = {}
		if offer.kind == "Bundle" and showBenefit then
			local row = buildClaims(env, column, offer, contentZ + 2, nextOrder())
			if row then
				table.insert(claimParts, row)
			end
		end
		if offer.previewLine and showBenefit then
			-- the conspicuous PREVIEW line (M10-05a): a bright chip, never a caption the harness can hide
			local line = ShopKit.chip(column, {
				text = offer.previewLine,
				fill = "Yellow",
				size = 16,
				z = contentZ + 2,
				name = "PreviewLine",
				dark = true,
			})
			line.LayoutOrder = nextOrder()
		end
		local state = env.stateOf(id)
		local view: View
		local button = ShopKit.priceButton(column, {
			name = "Price",
			label = state.label,
			size = Vector2.new(math.min(leftW, 320), buttonH),
			secondary = buttonH < BUTTON_H,
			z = contentZ + 3,
			trove = env.trove,
			onActivate = function()
				env.press(id, view.button and view.button.body or nil)
			end,
		})
		button.root.LayoutOrder = nextOrder()
		buttons[i] = button
		breatheButton(env, button, 1)
		if offer.kind == "Bundle" and dealOf(env, id) ~= nil then
			local ribbon = ShopKit.ribbon(
				slide,
				{ text = "BEST DEAL", fill = "Red", size = 84, z = contentZ + 8, name = "BestDealRibbon" }
			)
			table.insert(claimParts, ribbon.root)
		end
		view = {
			offerId = id,
			root = slide,
			hit = card.hit,
			button = button,
			apply = function(viewState: ViewState)
				button.setState(viewState.kind, viewState.label)
				local show = claimable(viewState)
				for _, part in claimParts do
					part.Visible = show
				end
			end,
		}
		view.apply(state)
		env.register(id, view)
	end

	-- arrows and page dots, bottom right, above the art
	local controls: Frame = make("Frame", {
		Name = "Controls",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -14, 1, -(LIP + 10)),
		Size = UDim2.fromOffset(10, 52),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundTransparency = 1,
		ZIndex = contentZ + 10,
		Parent = content,
	})
	make("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = controls,
	})
	local dots: { Frame } = {}
	local function paintDots()
		for i, dot in dots do
			local active = i == current
			dot.BackgroundColor3 = if active then WHITE else ShopPalette.Color.TextSoft
			dot.BackgroundTransparency = if active then 0 else 0.45
			dot.Size = UDim2.fromOffset(if active then 18 else 10, 10)
		end
	end
	local function setIndex(index: number)
		local count = #ids
		if count == 0 then
			return
		end
		current = ((index - 1) % count) + 1
		for i, slide in slides do
			slide.Visible = i == current
		end
		paintDots()
		env.motion.rescan() -- the new slide's button may breathe at once, the old one rests
	end
	local leftArrow = ShopKit.squareButton(controls, {
		name = "Previous",
		size = Tokens.Touch.Minimum,
		fill = "Steel",
		icon = "Back",
		z = contentZ + 10,
		trove = env.trove,
		onActivate = function()
			setIndex(current - 1)
		end,
	})
	leftArrow.root.LayoutOrder = 1
	local dotRow: Frame = make("Frame", {
		Name = "Dots",
		Size = UDim2.fromOffset(10, 20),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundTransparency = 1,
		LayoutOrder = 2,
		ZIndex = contentZ + 10,
		Parent = controls,
	})
	make("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = dotRow,
	})
	for i = 1, #ids do
		local dot: Frame = make("Frame", {
			Name = "Dot" .. i,
			Size = UDim2.fromOffset(10, 10),
			BackgroundColor3 = WHITE,
			BorderSizePixel = 0,
			LayoutOrder = i,
			ZIndex = contentZ + 10,
			Parent = dotRow,
		})
		Arcade.corner(dot, 10)
		Arcade.outline(dot, 1.5)
		dots[i] = dot
	end
	local rightArrow = ShopKit.squareButton(controls, {
		name = "Next",
		size = Tokens.Touch.Minimum,
		fill = "Steel",
		icon = "Back",
		z = contentZ + 10,
		trove = env.trove,
		onActivate = function()
			setIndex(current + 1)
		end,
	})
	rightArrow.root.LayoutOrder = 3
	local arrowIcon = rightArrow.root:FindFirstChild("Icon", true)
	if arrowIcon and arrowIcon:IsA("GuiObject") then
		arrowIcon.Rotation = 180 -- the family has one arrow (Back); turned round it points forward
	end
	paintDots()

	local hero: Hero = {
		root = card.root,
		count = function(): number
			return #ids
		end,
		index = function(): number
			return current
		end,
		setIndex = setIndex,
		advance = function()
			setIndex(current + 1)
		end,
		isEngaged = function(): boolean
			local button = buttons[current]
			return card.isHover() or (button ~= nil and button.isHover())
		end,
		button = function(): ShopKit.PriceButton?
			return buttons[current]
		end,
		visible = function(on: boolean)
			card.root.Visible = on
		end,
	}
	return hero
end

-- DEAL ---------------------------------------------------------------------------------------------------------

-- The BEST DEAL banner (IMG-03): the All Passes Bundle across the page, under the hero. On a desktop it shows the diagonal
-- BEST DEAL ribbon, the name, the three pass icons (each from its own icon, never typed text), a SAVE x% burst and, on
-- the quiet plate, the struck-through sum above a big lime PREVIEW price button. On a phone the burst and the sum become a
-- row of chips under the name. The claims come only from Catalog.bundleMath and are hidden when they would not be true.
function Cards.deal(env: Env, parent: Instance, size: Vector2, z: number): View?
	local offer = Catalog.get("all-passes-bundle")
	if offer == nil then
		return nil
	end
	local tier = env.tier
	local phone = tier == "Phone"
	local contentZ = z + 6
	local deal = dealOf(env, offer.id)
	local card: ShopKit.Card
	card = ShopKit.card(parent, {
		name = "Deal",
		size = size,
		fill = "Gold",
		rotation = ShopPalette.Angle.Gold,
		z = z,
		trove = env.trove,
		pattern = true,
		interactive = true,
		lip = LIP,
		onActivate = function()
			env.press(offer.id, card.hit)
		end,
	})
	local content = card.content
	local visualH = size.Y - LIP
	local claimParts: { GuiObject } = {}

	env.motion.gradient({ gradient = card.gradient, recipe = "Deal", phase = 1.2, host = card.root, priority = 3 })
	local shine = ShopKit.shine(card.face, { radius = 16, z = z + 14, trove = env.trove })
	env.motion.shine({ host = card.root, play = shine.play, rest = shine.hide, phase = 3, priority = 3 })
	env.motion.sparkles({
		parent = content,
		z = contentZ + 6,
		marks = 3,
		region = { 0.12, 0.1, 0.62, 0.9 },
		seed = 29,
		priority = 1,
	})

	local ribbonSide = if phone then 72 elseif tier == "Tablet" then 88 else 96
	local plateW = if phone then 214 elseif tier == "Tablet" then 290 else 316
	local plateX = size.X - plateW - 10
	local textX = ribbonSide + 8

	-- the quiet plate with the price (and, off a phone, the struck-through sum above it)
	local plateTop = if phone then 4 else 6
	local plateH = visualH - 2 * plateTop
	ShopKit.plate(content, {
		name = "PricePlate",
		position = UDim2.fromOffset(plateX, plateTop),
		size = UDim2.fromOffset(plateW, plateH),
		z = contentZ,
	})
	local state = env.stateOf(offer.id)
	local button: ShopKit.PriceButton
	button = ShopKit.priceButton(content, {
		name = "Price",
		label = state.label,
		size = Vector2.new(plateW - 20, if visualH >= 70 then BUTTON_H else Tokens.Touch.Minimum),
		secondary = visualH < 70,
		z = contentZ + 2,
		trove = env.trove,
		onActivate = function()
			env.press(offer.id, button.body)
		end,
	})
	button.root.AnchorPoint = Vector2.new(0.5, 1)
	button.root.Position = UDim2.fromOffset(plateX + plateW / 2, plateTop + plateH - 4)
	breatheButton(env, button, 2)

	if deal ~= nil and not phone then
		-- the top of the plate: the PREVIEW VALUE tag beside the struck-through sum of the parts
		local claimRow: Frame = make("Frame", {
			Name = "ClaimRow",
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.fromOffset(plateX + plateW / 2, plateTop + 4),
			Size = UDim2.fromOffset(plateW - 12, 26),
			BackgroundTransparency = 1,
			ZIndex = contentZ + 2,
			Parent = content,
		})
		make("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
			Parent = claimRow,
		})
		local previewTag = ShopKit.chip(claimRow, {
			text = Catalog.PreviewValueTag,
			fill = "Yellow",
			size = 16,
			z = contentZ + 3,
			name = "PreviewValueTag",
			dark = true,
		})
		previewTag.LayoutOrder = 1
		local strike: TextLabel = make("TextLabel", {
			Name = "StrikePrice",
			BackgroundTransparency = 1,
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromOffset(0, 26),
			FontFace = PreviewTokens.Font(),
			RichText = true,
			Text = "<s>" .. Catalog.priceText(deal.componentSum) .. "</s>",
			TextSize = 18,
			TextColor3 = ShopPalette.Color.TextSoft,
			LayoutOrder = 2,
			ZIndex = contentZ + 3,
			Parent = claimRow,
		})
		Arcade.outline(strike, "Minor")
		table.insert(claimParts, claimRow)
		local burstSide = if tier == "Tablet" then 84 else 96
		local burst = ShopKit.burst(content, {
			text = "SAVE " .. deal.percent .. "%",
			fill = "Red",
			size = burstSide,
			z = contentZ + 4,
			name = "SaveChip",
		})
		burst.root.AnchorPoint = Vector2.new(1, 0.5)
		burst.root.Position = UDim2.fromOffset(plateX - 8, visualH / 2)
		table.insert(claimParts, burst.root)
	end

	-- the name and, off a phone, the three pass icons; on a phone the claim chips
	local titleSize = if phone then (if visualH < 70 then 20 else 24) elseif tier == "Tablet" then 30 else 36
	local titleH = titleSize + 8
	local burstRoom = if phone then 0 elseif tier == "Tablet" then 96 else 108
	local leftW = plateX - textX - 10 - burstRoom
	local title = ShopKit.label(content, env.text(offer.name), titleSize, {
		name = "Headline",
		z = contentZ + 2,
		outline = 4,
	})
	title.Position = UDim2.fromOffset(textX, if phone then 4 else 8)
	title.Size = UDim2.fromOffset(math.max(leftW, 120), titleH)

	if phone then
		if deal ~= nil then
			local row: Frame = make("Frame", {
				Name = "Claims",
				Position = UDim2.fromOffset(textX, 4 + titleH + 2),
				Size = UDim2.fromOffset(math.max(leftW, 120), 26),
				BackgroundTransparency = 1,
				ZIndex = contentZ + 2,
				Parent = content,
			})
			make("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				Padding = UDim.new(0, 6),
				SortOrder = Enum.SortOrder.LayoutOrder,
				Parent = row,
			})
			local save = ShopKit.chip(row, {
				text = "SAVE " .. deal.percent .. "%",
				fill = "Red",
				size = 16,
				z = contentZ + 3,
				name = "SaveChip",
			})
			save.LayoutOrder = 1
			local strike: TextLabel = make("TextLabel", {
				Name = "StrikePrice",
				BackgroundTransparency = 1,
				AutomaticSize = Enum.AutomaticSize.X,
				Size = UDim2.fromOffset(0, 26),
				FontFace = PreviewTokens.Font(),
				RichText = true,
				Text = "<s>" .. Catalog.priceText(deal.componentSum) .. "</s>",
				TextSize = 16,
				TextColor3 = WHITE,
				LayoutOrder = 2,
				ZIndex = contentZ + 3,
				Parent = row,
			})
			Arcade.outline(strike, "Minor")
			local tag = ShopKit.chip(row, {
				text = Catalog.PreviewValueTag,
				fill = "Yellow",
				size = 16,
				z = contentZ + 3,
				name = "PreviewValueTag",
				dark = true,
			})
			tag.LayoutOrder = 3
			table.insert(claimParts, row)
		end
	else
		local iconSide = math.min(52, visualH - (8 + titleH + 4) - 6)
		local row: Frame = make("Frame", {
			Name = "Includes",
			Position = UDim2.fromOffset(textX, 8 + titleH + 4),
			Size = UDim2.fromOffset(math.max(leftW, 120), iconSide),
			BackgroundTransparency = 1,
			ZIndex = contentZ + 2,
			Parent = content,
		})
		make("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
			Parent = row,
		})
		local order = 0
		for index, partId in offer.includes or {} do
			local part = Catalog.get(partId)
			if part == nil then
				continue
			end
			if index > 1 then
				order += 1
				local plus = ShopKit.label(row, "+", 28, {
					name = "Plus",
					xAlign = Enum.TextXAlignment.Center,
					z = contentZ + 2,
				})
				plus.Size = UDim2.fromOffset(22, iconSide)
				plus.LayoutOrder = order
			end
			order += 1
			local holder: Frame = make("Frame", {
				Name = "Pass_" .. partId,
				Size = UDim2.fromOffset(iconSide, iconSide),
				BackgroundTransparency = 1,
				LayoutOrder = order,
				ZIndex = contentZ + 2,
				Parent = row,
			})
			ShopKit.icon(holder, if env.fixtures.missingArt then "__missing__" else part.icon)
		end
	end

	if deal ~= nil then
		local ribbon = ShopKit.ribbon(content, {
			text = "BEST DEAL",
			fill = "Red",
			side = "Left",
			size = ribbonSide,
			z = contentZ + 8,
			name = "BestDealRibbon",
		})
		table.insert(claimParts, ribbon.root)
	end

	local view: View
	view = {
		offerId = offer.id,
		root = card.root,
		hit = card.hit,
		button = button,
		apply = function(viewState: ViewState)
			button.setState(viewState.kind, viewState.label)
			local show = claimable(viewState)
			for _, part in claimParts do
				part.Visible = show
			end
		end,
	}
	view.apply(state)
	env.register(offer.id, view)
	return view
end

return Cards
