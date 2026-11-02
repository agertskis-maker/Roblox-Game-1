--!strict
-- ShopCards: builders for every card on the Shop page (Lane 3, BRIEF M10-03 .. M10-08, 2026-11-01), all made from
-- ShopKit parts and the code-drawn icon family. The page calls these; they never decide what a press MEANS: a press goes
-- through env.press (the screen's one path to the purchase adapter), and a card only shows the ViewState it is given.
--
--   Cards.offer(env, parent, offer, plan) -> View      a pass, bundle, style, free, cash or side card
--   Cards.measure(env, offer, plan) -> number          the height that card needs for its own copy
--   Cards.hero(env, parent, size, z) -> Hero           the Featured carousel
--
-- A card is sized from its content (TextService measures the copy), so a 30 percent longer string makes a taller card
-- instead of clipping; every card in a row then shares the tallest height. Copy is exactly the brief's (M10-04a,
-- M10-05a, M10-06a, M10-07a, M10-08a); the PREVIEW lines stay conspicuous.
--
-- HONESTY (M10-11, M10-11a): BEST DEAL, SAVE x% and a struck-through sum are built only when env.fixtures.previewValue is
-- on, only from Catalog.bundleMath, and always beside a "PREVIEW VALUE" tag. They are named BestDealRibbon, SaveChip,
-- StrikePrice and PreviewValueTag so the debug state can count them (normal preview presentation: all zero).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Prototype = script.Parent.Parent.Parent
local Arcade = require(Prototype.Arcade)
local PreviewTokens = require(Prototype.PreviewTokens)
local ShopKit = require(Prototype.ShopKit)
local ShopArt = require(script.Parent.ShopArt)
local ShopLayout = require(script.Parent.ShopLayout)
local Catalog = require(ReplicatedStorage.Shared.UI.ShopPreviewCatalog)
local Trove = require(ReplicatedStorage.Packages.Trove)

local S = PreviewTokens.Shop
local make = Arcade.make
local WHITE = Color3.new(1, 1, 1)
local LIP = 5 -- the card lip ShopKit.card draws
local BUTTON_H = 52

local Cards = {}

export type ViewState = { kind: ShopKit.PriceState, label: string }

export type Fixtures = {
	missingArt: boolean,
	previewValue: boolean,
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
	showTag: boolean?, -- default true
	showBody: boolean?, -- default true
	artSide: number?, -- override
	buttonRight: boolean?, -- Wide: the button sits at the right edge, vertically centred (the Free card)
	stamp: boolean?, -- show the catalog stamp (NEW)
	name: string?,
}

type Item = { kind: string, h: number, text: string?, size: number? }

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
	local nameSize = if plan.big then 26 else 22
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
	if offer.kind == "Bundle" and env.fixtures.previewValue then
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
		table.insert(items, { kind = "swatches", h = 36 })
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

-- The honest-by-construction deal claims, FIXTURE ONLY: a SAVE chip and a struck-through sum from the real component
-- prices, each beside the PREVIEW VALUE tag. Nothing is built unless the bundle truly costs less than its parts.
local function buildClaims(env: Env, parent: Instance, offer: Catalog.Offer, z: number, order: number)
	if not env.fixtures.previewValue then
		return
	end
	local math_ = Catalog.bundleMath(offer.id)
	if not math_ or not math_.isBetter then
		return
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
		ShopKit.chip(row, { text = "SAVE " .. math_.percent .. "%", fill = "Red", size = 16, z = z, name = "SaveChip" })
	save.LayoutOrder = 1
	local strike: TextLabel = make("TextLabel", {
		Name = "StrikePrice",
		BackgroundTransparency = 1,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 26),
		FontFace = PreviewTokens.Font(),
		RichText = true,
		Text = "<s>" .. Catalog.priceText(math_.componentSum) .. "</s>",
		TextSize = 16,
		TextColor3 = S.Color.TextSoft,
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
		Size = UDim2.new(1, 0, 0, 36),
		LayoutOrder = order,
		ZIndex = z,
		Parent = parent,
	})
	make("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = if centred then Enum.HorizontalAlignment.Center else Enum.HorizontalAlignment.Left,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = row,
	})
	for i, colour in offer.swatches or {} do
		local chip: TextButton = make("TextButton", {
			Name = "Swatch" .. i,
			Size = UDim2.fromOffset(30, 30),
			BackgroundColor3 = colour,
			AutoButtonColor = false,
			Text = "",
			Selectable = true,
			LayoutOrder = i,
			ZIndex = z,
			Parent = row,
		})
		Arcade.corner(chip, 15)
		make("UIStroke", {
			Thickness = 2,
			Color = WHITE,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			Parent = chip,
		})
		env.trove:Connect(chip.Activated, function()
			env.swatch(offer.id, colour)
		end)
	end
end

-- One offer card: art, the text rows and a price button. `plan.orientation` Tall stacks everything centred under the art;
-- Wide puts the art on the left and the copy on the right.
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
	for order, item in items do
		if item.kind == "name" then
			local label = ShopKit.label(
				column,
				item.text or "",
				item.size or 22,
				{ name = "Name", xAlign = xAlign, z = contentZ }
			)
			label.Size = UDim2.new(1, 0, 0, item.h)
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
			buildClaims(env, column, offer, contentZ, order)
		elseif item.kind == "swatches" then
			buildSwatches(env, column, offer, contentZ, order, tall)
		else
			-- body, includes, detail, note, preview: wrapped copy
			local colour = if item.kind == "body"
				then WHITE
				elseif item.kind == "preview" then S.Color.Warn
				else S.Color.TextSoft
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
	-- FIXTURE ONLY: the diagonal BEST DEAL ribbon, only when the bundle really costs less than its parts
	if offer.kind == "Bundle" and env.fixtures.previewValue then
		local bundle = Catalog.bundleMath(offer.id)
		if bundle and bundle.isBetter then
			ShopKit.ribbon(
				content,
				{ text = "BEST DEAL", fill = "Red", size = 108, z = contentZ + 8, name = "BestDealRibbon" }
			)
		end
	end

	view = {
		offerId = offer.id,
		root = card.root,
		hit = card.hit,
		button = button,
		apply = function(viewState: ViewState)
			button.setState(viewState.kind, viewState.label)
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
	shine: ShopKit.Shine,
	sparkles: ShopKit.Sparkles,
	visible: (boolean) -> (),
}

-- The Featured carousel (M10-03): a big gradient card with the pattern, a FEATURED tag, a giant outlined headline, one
-- benefit line, large art on the right, a big green price button, arrows and page dots. The Starter Pack leads for a
-- player who does not own it. It never rotates by itself here: the screen's scheduler calls advance() only while nothing
-- is hovered, pressed or focused (M10-03a).
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
		rotation = 22,
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
	local leftW = math.floor(size.X * (if phone then 0.58 else 0.52)) - 22
	local artPx = math.floor(math.min(visualH - 24, size.X * 0.4))
	local titleSize = if tier == "Desktop" then 54 elseif tier == "Tablet" then 40 else 34
	local bodySize = if tier == "Desktop" then 20 else 17
	local buttonH = if tier == "Desktop" then 56 else BUTTON_H
	local showContents = visualH >= 290

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
		local title = ShopKit.label(column, env.text(offer.name), titleSize, { name = "Headline", z = contentZ + 2 })
		title.Size = UDim2.new(1, 0, 0, titleSize + 8)
		title.LayoutOrder = nextOrder()
		local body = ShopKit.paragraph(column, env.text(offer.body), bodySize, { name = "Benefit", z = contentZ + 2 })
		body.LayoutOrder = nextOrder()
		if showContents and offer.contents then
			local contents = ShopKit.paragraph(
				column,
				offer.contents,
				16,
				{ name = "Contents", colour = S.Color.TextSoft, z = contentZ + 2 }
			)
			contents.LayoutOrder = nextOrder()
		end
		if offer.kind == "Bundle" then
			local text = includesText(offer)
			local includes =
				ShopKit.paragraph(column, text, 16, { name = "Includes", colour = S.Color.TextSoft, z = contentZ + 2 })
			includes.LayoutOrder = nextOrder()
			buildClaims(env, column, offer, contentZ + 2, nextOrder())
		end
		if offer.previewLine then
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
			size = Vector2.new(math.min(leftW, 300), buttonH),
			z = contentZ + 3,
			trove = env.trove,
			onActivate = function()
				env.press(id, view.button and view.button.body or nil)
			end,
		})
		button.root.LayoutOrder = nextOrder()
		buttons[i] = button
		view = {
			offerId = id,
			root = slide,
			hit = card.hit,
			button = button,
			apply = function(viewState: ViewState)
				button.setState(viewState.kind, viewState.label)
			end,
		}
		view.apply(state)
		env.register(id, view)
		if offer.kind == "Bundle" and env.fixtures.previewValue then
			local bundle = Catalog.bundleMath(id)
			if bundle and bundle.isBetter then
				ShopKit.ribbon(
					slide,
					{ text = "BEST DEAL", fill = "Red", size = 108, z = contentZ + 8, name = "BestDealRibbon" }
				)
			end
		end
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
			dot.BackgroundColor3 = if active then WHITE else S.Color.TextSoft
			dot.BackgroundTransparency = if active then 0 else 0.55
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
	end
	local leftArrow = ShopKit.squareButton(controls, {
		name = "Previous",
		size = 48,
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
		size = 48,
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

	local shine = ShopKit.shine(card.face, { radius = 16, z = z + 14, trove = env.trove })
	local sparkles = ShopKit.sparkles(content, {
		z = contentZ + 6,
		trove = env.trove,
		region = { 0.56, 0.1, 0.95, 0.8 },
		seed = 17,
	})
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
		shine = shine,
		sparkles = sparkles,
		visible = function(on: boolean)
			card.root.Visible = on
		end,
	}
	return hero
end

return Cards
