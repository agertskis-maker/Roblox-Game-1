--!strict
-- ShopMock: the Shop, rebuilt in Round 3 from the style guide (vault/design/ui-style-guide.md; reference frames in
-- Car-Hop-Art/review/round3/chatgpt-images). PREVIEW only: nothing here can be bought. There is no MarketplaceService call,
-- no product id, no pass id and no grant anywhere in this screen: every price button goes through ShopPurchaseAdapter,
-- shows "Checking..." for about 0.4 s, then a friendly "Coming soon!" card.
--
--   local shop = ShopMock.new(ctx, { onClose = fn?, adapter = A?, onFreeReward = fn?, autoAdvance = true?, blur = true? })
--   shop:open(returnTo?)                       -- starts at Featured
--   shop:openSection(name, returnTo?)          -- "Featured", "Passes", "Cash", "Free"
--   shop:openAt(sectionId?, offerId?, returnTo?)
--   shop:openExpandedPaddock(returnTo?)        -- "Get more spots" in the Raceway's parking panel
--   shop:openDoubleLapPay(returnTo?)           -- "Earn faster"
--   shop:close()  shop:isOpen()  shop:layout()  shop:setVisible(on)  shop:destroy()
--   shop:scrollTo(sectionId, animate?)  shop:setSlide(n)  shop:pressOffer(offerId)  shop:getAdapter()
--   shop:forceState(offerId, "owned" | "unavailable" | "error" | nil)  shop:resetFixtures()  shop:getDebugState()
--
-- The layout comes from the design size on every change, one recipe scaled by `k`, so desktop, tablet and a phone in
-- landscape all get the same page: one hero, two side cards, the deal banner, and the Cash packs peeking in to invite a
-- scroll. Deal claims are derived from the catalog's real sums; BEST VALUE from CashPackPreview's real amounts. Every
-- continuous effect belongs to one ShopMotion animator that runs only while the Shop is open and on screen; Reduce Motion
-- rests them all.

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Prototype = script.Parent.Parent
local CarKit = require(Prototype.CarKit)
local Motion = require(Prototype.Motion)
local Overlay = require(script.Parent.Overlay)
local RealCar = require(Prototype.RealCar)
local ShopKit = require(Prototype.ShopKit)
local ShopMotion = require(Prototype.ShopMotion)
local ShopPurchaseAdapter = require(Prototype.ShopPurchaseAdapter)
local Sounds = require(Prototype.Sounds)
local CashPacks = require(ReplicatedStorage.Shared.UI.CashPackPreview)
local Catalog = require(ReplicatedStorage.Shared.UI.ShopPreviewCatalog)
local Format = require(ReplicatedStorage.Shared.UI.Format)

local make = CarKit.make

local ShopMock = {}

export type Options = {
	onClose: (() -> ())?,
	adapter: ShopPurchaseAdapter.Adapter?,
	onFreeReward: (() -> ())?,
	autoAdvance: boolean?,
	blur: boolean?,
	earningsPerSecond: (() -> number)?, -- the Raceway's rate; default the PREVIEW fixture
}

export type Shop = { [string]: any }

local TABS = {
	{ id = "featured", label = "Featured" },
	{ id = "passes", label = "Passes" },
	{ id = "cash", label = "Cash" },
	{ id = "free", label = "Free" },
}

type Slide = {
	title: string,
	family: string,
	art: string,
	offer: string?, -- buys this offer
	go: string?, -- or goes to this tab
	line: string?,
	button: string?,
}

local SLIDES: { Slide } = {
	{ title = "STARTER PACK!", family = "Starter", art = "art_starter", offer = "starter-pack" },
	{
		title = "CASH VAULT!",
		family = "CashVault",
		art = "art_cash5",
		go = "cash",
		line = "Packs grow as your Raceway grows!",
		button = "GET CASH",
	},
}

-- How far Shop art is zoomed past its box. Adam, 2026-11-02: bigger is better, and a crop at the card edge is fine.
local ART_ZOOM = 1.25
local ART_ZOOM_BY_KEY: { [string]: number } = {
	art_cash5 = 1.55, -- the Cash Vault
	-- Round 5: the pass art is a centred tile now (a crown, a gift, three spots), so it is only nudged past its box
	art_vip = 1.1,
	art_starter = 1.1,
	art_paddock = 1.1,
	art_doublelap = 1.6,
}

-- Round 4 (E-07): every Cash amount in the Shop goes through Format.cash ("$12.4K", "$1.2M", up to Qa), the one display rule
local function money(n: number): string
	return Format.cash(n)
end

local function edgeTint(name: string): Color3
	local f = (CarKit.Family :: any)[name]
	return if f then f.edge else CarKit.White
end

local FOOT = 18 -- the PREVIEW line at the foot of the panel, on every tab

type Plan = {
	tier: string,
	k: number,
	panel: Vector2,
	pad: number,
	headerH: number,
	inner: number,
	pageH: number,
	gap: number,
}

local function plan(D: Vector2): Plan
	local tier = if D.Y < 420 then "Phone" elseif D.X < 1000 then "Tablet" else "Desktop"
	local margin = if tier == "Phone" then 4 else 16
	local panel = Vector2.new(math.min(D.X - margin * 2, 1560), math.min(D.Y - margin * 2, 900))
	local pad = if tier == "Phone" then 8 else 12
	local headerH = if tier == "Phone" then 50 else 68
	local inner = panel.X - pad * 2
	local pageH = panel.Y - headerH - pad * 2 - FOOT
	local k = math.clamp(math.min(inner / 1180, pageH / 620), 0.5, 1.3)
	return {
		tier = tier,
		k = k,
		panel = panel,
		pad = pad,
		headerH = headerH,
		inner = inner,
		pageH = pageH,
		gap = math.max(6, math.round(12 * k)),
	}
end

function ShopMock.new(ctx: Overlay.Ctx, options: Options?): Shop
	local opts: Options = options or {}
	local shop: Shop = {}
	local overlay = Overlay.new(ctx, { name = "ShopMock", dimTransparency = 0.5, slide = false })
	local trove = overlay.trove
	local adapter: ShopPurchaseAdapter.Adapter = opts.adapter or ShopPurchaseAdapter.new()
	if opts.adapter == nil then
		trove:Add(function()
			adapter:destroy()
		end)
	end
	local motion = ShopMotion.new()
	trove:Add(function()
		motion.destroy()
	end)

	local buildTrove = trove:Extend()
	local isShopOpen = false
	local visible = true
	local activeTab = "featured"
	local slide = 1
	local nextAdvance = 0
	local forced: { [string]: string } = {}
	local pendingId: string? = nil
	local pendingHandle: ShopPurchaseAdapter.Handle? = nil
	local sectionY: { [string]: number } = {}
	local buttons: { [string]: { CarKit.Button } } = {}
	local tabButtons: { [string]: any } = {}
	local page: ScrollingFrame? = nil
	local panel: Frame? = nil
	local blur: BlurEffect? = nil
	local soon: Frame? = nil
	local counters = { builds = 0, requests = 0 }
	local cashLabel: TextLabel? = nil
	local cashRow: { { amount: TextLabel, pack: CashPacks.Pack } } = {}
	local heroSlot: Frame? = nil
	local heroTrove = buildTrove:Extend()
	local currentPlan: Plan? = nil
	local builtFor = Vector2.zero
	local build: () -> ()
	local renderHero: () -> ()
	local showTab: (id: string, animate: boolean?) -> ()

	local function rate(): number
		return if opts.earningsPerSecond then opts.earningsPerSecond() else CashPacks.FixtureRate
	end

	local function cash(): number
		return ctx.store:get().cash or 0
	end

	-- STATE -----------------------------------------------------------------------------------------------------

	local function stateOf(id: string): string
		if forced[id] then
			return forced[id]
		end
		if adapter:ownership(id) then
			return "owned"
		end
		local a = adapter:availability(id)
		return if a == "Unavailable" then "unavailable" elseif a == "Error" then "error" else "idle"
	end

	local function paint(id: string, button: CarKit.Button, price: number?)
		local state = stateOf(id)
		local wordHost = button.root:FindFirstChild("WordHost", true) :: Frame?
		local showWord = false
		if pendingId == id then
			button.setText("Checking...")
			button.setTone("Green")
			button.setEnabled(false)
		elseif state == "owned" then
			button.setText("OWNED")
			button.setTone("Grey")
			button.setEnabled(false)
		elseif state == "unavailable" or state == "error" then
			button.setText(if state == "error" then "Try later" else "Not here yet")
			button.setTone("Grey")
			button.setEnabled(false)
		else
			button.setText(if price then Format.group(price) else "")
			button.setTone("Green")
			button.setEnabled(true)
			showWord = true
		end
		if wordHost then
			wordHost.Visible = showWord
		end
	end

	local priceOf: { [string]: number } = {}

	local function refresh()
		for id, list in buttons do
			for _, button in list do
				paint(id, button, priceOf[id])
			end
		end
		if cashLabel then
			cashLabel.Text = money(cash())
		end
		local rows = CashPacks.list(rate(), cash())
		for i, row in cashRow do
			row.amount.Text = "+" .. money(rows[i].amount)
		end
	end

	local function closeSoon()
		if soon then
			soon:Destroy()
			soon = nil
		end
		overlay:setBack(function()
			shop:close()
		end)
	end

	local function showSoon(title: string, art: string?)
		closeSoon()
		local host = overlay.content
		local shade = make("TextButton", {
			Name = "ComingSoon",
			Text = "",
			AutoButtonColor = false,
			BackgroundColor3 = CarKit.Ink,
			BackgroundTransparency = 0.45,
			Size = UDim2.fromScale(1, 1),
			ZIndex = 200,
		}, host) :: any
		soon = shade
		local D = overlay:designSize()
		local w = math.min(D.X - 24, 440)
		local h = math.min(D.Y - 24, 340)
		local card = CarKit.board(shade, {
			size = UDim2.fromOffset(w, h),
			position = UDim2.fromScale(0.5, 0.5),
			anchor = Vector2.new(0.5, 0.5),
			z = 201,
			bolts = true,
			name = "Card",
		})
		if art then
			CarKit.art(card, art, {
				size = UDim2.fromOffset(h * 0.46, h * 0.46),
				position = UDim2.new(0.5, 0, 0, h * 0.27),
				z = 202,
			})
		end
		CarKit.title(card, "COMING SOON!", 40, {
			align = Enum.TextXAlignment.Center,
			size = UDim2.new(1, -24, 0, 44),
			position = UDim2.fromOffset(12, h * 0.5),
			z = 203,
			top = CarKit.White,
			bottom = CarKit.Gold,
		})
		CarKit.text(card, title .. " isn't on sale yet. Nothing was charged.", 17, {
			align = Enum.TextXAlignment.Center,
			wrap = true,
			size = UDim2.new(1, -40, 0, 46),
			position = UDim2.fromOffset(20, h * 0.5 + 46),
			z = 203,
			color = CarKit.Soft,
		})
		local ok = CarKit.button(card, {
			text = "OK",
			tone = "Blue",
			px = 28,
			size = UDim2.fromOffset(160, 54),
			position = UDim2.new(0.5, 0, 1, -14),
			anchor = Vector2.new(0.5, 1),
			z = 203,
			onPress = closeSoon,
			name = "SoonOk",
		})
		overlay:setBack(closeSoon)
		overlay:focus(ok.root)
		Motion.pop(card, 0.94)
	end

	local function press(id: string, title: string, art: string?)
		if pendingId or stateOf(id) ~= "idle" then
			return
		end
		pendingId = id
		counters.requests += 1
		refresh()
		pendingHandle = adapter:request(id, function(result: ShopPurchaseAdapter.Result)
			pendingId = nil
			pendingHandle = nil
			refresh()
			if isShopOpen and result.status == "ComingSoon" then
				showSoon(title, art)
			end
		end)
	end

	local function priceButton(
		parent: Instance,
		id: string,
		title: string,
		art: string?,
		price: number,
		spec: { [string]: any }
	): CarKit.Button
		local button = CarKit.price(parent, {
			amount = price,
			word = Catalog.PriceWord,
			px = spec.px,
			size = spec.size,
			position = spec.position,
			anchor = spec.anchor,
			z = spec.z,
			name = "Buy_" .. id,
			onPress = function()
				press(id, title, art)
			end,
		})
		buttons[id] = buttons[id] or {}
		table.insert(buttons[id], button)
		priceOf[id] = price
		paint(id, button, price)
		return button
	end

	-- PIECES ----------------------------------------------------------------------------------------------------

	local function fontPx(p: Plan, n: number, least: number?): number
		return math.max(math.round(n * p.k), least or 13)
	end

	local function flow(
		owner: any,
		card: Frame,
		gradient: UIGradient,
		recipe: string,
		phase: number,
		shinePhase: number?,
		radius: number
	)
		owner:Add(motion.gradient({ gradient = gradient, recipe = recipe, phase = phase, host = card }).remove)
		if shinePhase then
			local shine = ShopKit.shine(card, { radius = radius, z = 38, trove = owner })
			owner:Add(motion.shine({
				host = card,
				play = shine.play,
				rest = shine.hide,
				period = 7,
				phase = shinePhase,
			}).remove)
		end
	end

	-- Art grows past its box, centred on it. The card crops the overflow, and words and buttons sit in front.
	local function boxArt(
		parent: Instance,
		key: string,
		x: number,
		y: number,
		w: number,
		h: number,
		z: number,
		name: string?
	)
		local border = 3
		local crop = make("Frame", {
			Name = "ArtCrop",
			BackgroundTransparency = 1,
			ClipsDescendants = true,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.new(1, -border * 2, 1, -border * 2),
			ZIndex = z,
		}, parent)
		local zoom = ART_ZOOM_BY_KEY[key] or ART_ZOOM
		return CarKit.art(crop, key, {
			size = UDim2.fromOffset(w * zoom, h * zoom),
			position = UDim2.fromOffset(x + w / 2 - border, y + h / 2 - border),
			z = z,
			name = name or "Art",
		})
	end

	-- FEATURED: the hero. One slide at a time; a new slide replaces the old inside `heroSlot`.
	renderHero = function()
		local p = currentPlan
		local slot = heroSlot
		if not (p and slot) then
			return
		end
		heroTrove:Clean()
		slot:ClearAllChildren()
		local s = SLIDES[slide]
		local k = p.k
		local w, h = slot:GetAttribute("W") :: number, slot:GetAttribute("H") :: number
		local card, family, gradient =
			CarKit.card(slot, s.family, { radius = math.round(16 * math.max(k, 0.6)), z = 2, name = "Hero" })
		-- on a phone the art takes the full height at the left, and the words go beside it
		local phone = p.tier == "Phone"
		local titlePx = if phone then 40 else fontPx(p, 84, 34)
		local inset = if phone then 6 else math.round(10 * k)
		local artW = if phone then math.min(h * 1.3, w * 0.36) else w * 0.56
		local artY = if phone then inset else titlePx * 0.86
		local artH = h - artY - inset
		-- a glow under the art, in the family colour
		CarKit.art(card, "fx_glow", {
			size = UDim2.fromOffset(artW, artH),
			position = UDim2.fromOffset(inset + artW / 2, artY + artH / 2),
			color = family.motifColor,
			transparency = 0.25,
			z = 4,
			placeholder = false,
		})
		boxArt(card, s.art, inset, artY, artW, artH, 6, "HeroArt")
		if not phone then
			CarKit.art(card, "fx_flag", {
				size = UDim2.fromOffset(titlePx * 1.5, titlePx * 0.8),
				position = UDim2.fromOffset(-titlePx * 0.1, titlePx * 0.12),
				anchor = Vector2.zero,
				z = 7,
				rotation = -8,
				placeholder = false,
			})
		end
		local titleX = if phone then artW + inset * 2 else titlePx * 0.62
		CarKit.title(card, s.title, titlePx, {
			position = UDim2.fromOffset(titleX, if phone then 2 else math.round(6 * k)),
			size = UDim2.new(1, -titleX, 0, titlePx * 1.04),
			top = CarKit.White,
			bottom = CarKit.Yellow,
			stroke = math.max(3, titlePx / 13),
			z = 8,
			name = "HeroTitle",
		})
		local right = w - artW - inset * 2
		local offer = s.offer and Catalog.get(s.offer)
		if offer and offer.parts then
			local buyW = if phone then 132 else 0
			local count = #offer.parts
			local tileW = math.floor((right - 20 * k - buyW) / count)
			local plateH = if phone
				then h - titlePx * 1.04 - inset * 2
				else h - titlePx * 0.5 - math.max(84 * k, 52) - math.round(30 * k)
			local plate = CarKit.board(card, {
				size = UDim2.fromOffset(tileW * count + 16 * k, plateH),
				position = if phone
					then UDim2.fromOffset(artW + inset * 2, titlePx * 1.04 + inset)
					else UDim2.new(1, -math.round(10 * k), 0, titlePx * 0.5),
				anchor = if phone then Vector2.zero else Vector2.new(1, 0),
				z = 9,
				radius = math.round(12 * math.max(k, 0.6)),
				top = Color3.fromRGB(20, 26, 50),
				bottom = Color3.fromRGB(10, 14, 30),
				name = "Includes",
			})
			if not phone then
				CarKit.title(plate, "INCLUDES:", fontPx(p, 26, 14), {
					size = UDim2.new(1, -14, 0, fontPx(p, 30, 16)),
					position = UDim2.fromOffset(10, 2),
					z = 11,
					shadow = false,
					stroke = 2,
				})
			end
			local labelPx = fontPx(p, 19, 12)
			local tileTop = if phone then 4 else fontPx(p, 32, 17)
			local tileH = plateH - tileTop - labelPx * 2.1
			for i, part in offer.parts do
				local x = (i - 1) * tileW + 8 * k
				local side = math.min(tileW - 2, tileH * 1.2)
				if part.car then
					-- the car itself (decision 0038): the real model, still, with a RARE chip so the rarity reads at once
					local holder = make("Frame", {
						Name = "CarTile",
						BackgroundTransparency = 1,
						AnchorPoint = Vector2.new(0.5, 0.5),
						Size = UDim2.fromOffset(side * 1.25, side),
						Position = UDim2.fromOffset(x + tileW / 2, tileTop + tileH / 2),
						ZIndex = 12,
					}, plate) :: Frame
					RealCar.thumb(holder, part.car)
					local chipPx = fontPx(p, 16, 11)
					local chip = make("Frame", {
						Name = "RareChip",
						BackgroundColor3 = CarKit.Rarity.Rare,
						AnchorPoint = Vector2.new(0.5, 0),
						Position = UDim2.fromOffset(x + tileW / 2, tileTop - 2),
						Size = UDim2.fromOffset(chipPx * 3.6, chipPx * 1.3),
						ZIndex = 14,
					}, plate) :: Frame
					make("UICorner", { CornerRadius = UDim.new(0.5, 0) }, chip)
					CarKit.text(chip, "RARE", chipPx, {
						align = Enum.TextXAlignment.Center,
						size = UDim2.fromScale(1, 1),
						z = 15,
						stroke = 1.5,
						name = "Rare",
					})
				else
					CarKit.art(plate, part.art :: string, {
						size = UDim2.fromOffset(side, side),
						position = UDim2.fromOffset(x + tileW / 2, tileTop + tileH / 2),
						z = 12,
					})
				end
				CarKit.text(plate, part.label, labelPx, {
					align = Enum.TextXAlignment.Center,
					alignY = Enum.TextYAlignment.Top,
					wrap = true,
					size = UDim2.fromOffset(tileW, labelPx * 2.2),
					position = UDim2.new(0, x, 1, -labelPx * 2.3),
					z = 12,
					name = "PartLabel",
				})
			end
		elseif s.line then
			CarKit.title(card, s.line, fontPx(p, 40, 18), {
				wrap = true,
				size = UDim2.fromOffset(right - 24, h * 0.4),
				position = UDim2.new(1, -12, 0, titlePx * 1.3),
				anchor = Vector2.new(1, 0),
				align = Enum.TextXAlignment.Right,
				alignY = Enum.TextYAlignment.Top,
				z = 9,
				stroke = 3,
			})
		end
		local bw = if phone then 124 else math.round(math.max(236 * k, 150))
		local bh = if phone then 52 else math.round(math.max(84 * k, 52))
		local spec = {
			px = fontPx(p, 54, 28),
			size = UDim2.fromOffset(bw, bh),
			position = if phone
				then UDim2.new(1, -inset, 1, -inset)
				else UDim2.new(1, -math.round(14 * k), 1, -math.round(14 * k)),
			anchor = Vector2.new(1, 1),
			z = 12,
		}
		local cta: CarKit.Button
		if offer and offer.price then
			buttons[offer.id] = nil
			cta = priceButton(card, offer.id, offer.name, s.art, offer.price, spec)
		else
			cta = CarKit.button(card, {
				text = s.button or "SEE",
				tone = "Green",
				px = fontPx(p, 42, 24),
				size = spec.size,
				position = spec.position,
				anchor = spec.anchor,
				z = 12,
				name = "HeroGo",
				onPress = function()
					if s.go then
						showTab(s.go, true)
					end
				end,
			})
		end
		local scale = make("UIScale", { Scale = 1 }, cta.root) :: UIScale
		heroTrove:Add(motion.breathe({ scale = scale, host = cta.root, priority = 1 }).remove)
		-- carousel dots
		local dots = make("Frame", {
			Name = "Dots",
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -4, 0, 2),
			Size = UDim2.fromOffset(#SLIDES * 34, 26),
			ZIndex = 12,
		}, card)
		make("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, 10),
		}, dots)
		for i = 1, #SLIDES do
			local dot = make("TextButton", {
				Name = "Dot" .. i,
				Text = "",
				AutoButtonColor = false,
				BackgroundColor3 = if i == slide then CarKit.Yellow else Color3.fromRGB(130, 140, 170),
				Size = UDim2.fromOffset(16, 16),
				ZIndex = 12,
				Selectable = false,
			}, dots)
			make("UICorner", { CornerRadius = UDim.new(1, 0) }, dot)
			make("UIStroke", { Thickness = 2, Color = CarKit.Ink, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, dot)
			dot.Activated:Connect(function()
				shop:setSlide(i)
				nextAdvance = os.clock() + 14
			end)
		end
		flow(heroTrove, card, gradient, "Hero", 0, 0, math.round(16 * k))
	end

	local function sideCard(
		parent: Instance,
		id: string,
		familyName: string,
		art: string,
		title: string,
		line: string?,
		p: Plan,
		rect: { x: number, y: number, w: number, h: number }
	)
		local offer = Catalog.get(id)
		local k = p.k
		local w, h = rect.w, rect.h
		local card, _, gradient = CarKit.card(parent, familyName, {
			size = UDim2.fromOffset(w, h),
			position = UDim2.fromOffset(rect.x, rect.y),
			radius = math.round(14 * math.max(k, 0.6)),
			z = 2,
			name = "Side_" .. id,
		})
		local px = fontPx(p, 62, 24)
		local inset = math.round(7 * k)
		local buyW = math.round(math.max(132 * k, 108))
		if id == "vip" then
			boxArt(card, art, inset, 0, w - buyW - inset * 3, h - inset, 6)
		else
			px = fontPx(p, 54, 24)
			local side = h - inset
			boxArt(card, art, math.max(inset * 2, w * 0.62 - side / 2), 0, side, side, 6) -- right of the title, so the 2x reads
		end
		CarKit.title(card, title, px, {
			position = UDim2.fromOffset(math.round(12 * k), math.round(4 * k)),
			size = UDim2.new(1, -math.round(16 * k), 0, px * 1.06),
			top = if id == "vip" then CarKit.Gold else CarKit.White,
			bottom = if id == "vip" then Color3.fromRGB(216, 140, 20) else Color3.fromRGB(190, 224, 255),
			stroke = math.max(3, px / 13),
			z = 8,
		})
		local linePx = fontPx(p, 30, 15)
		if line and h - px * 1.04 - math.max(58 * k, 46) - 10 >= linePx * 1.2 then
			CarKit.title(card, line, linePx, {
				align = Enum.TextXAlignment.Right,
				size = UDim2.fromOffset(w * 0.62, linePx * 1.2),
				position = UDim2.new(1, -math.round(12 * k), 0, px * 1.04),
				anchor = Vector2.new(1, 0),
				alignY = Enum.TextYAlignment.Top,
				color = CarKit.Yellow,
				stroke = 2.5,
				z = 8,
			})
		end
		if offer and offer.price then
			priceButton(card, id, offer.name, art, offer.price, {
				px = fontPx(p, 32, 22),
				size = UDim2.fromOffset(buyW, math.round(math.max(50 * k, 46))),
				position = UDim2.new(1, -math.round(10 * k), 1, -math.round(10 * k)),
				anchor = Vector2.new(1, 1),
				z = 12,
			})
		end
		flow(buildTrove, card, gradient, "Card", if id == "vip" then 2 else 4, nil, 14)
		return card
	end

	local function dealBanner(parent: Instance, p: Plan, y: number): number
		local h = math.round(math.max(112 * p.k, 76))
		local k = p.k
		local offer = Catalog.get("all-passes-bundle")
		local sums = Catalog.bundleMath("all-passes-bundle")
		local card, _, gradient = CarKit.card(parent, "Bundle", {
			size = UDim2.fromOffset(p.inner, h),
			position = UDim2.fromOffset(0, y),
			radius = math.round(14 * math.max(k, 0.6)),
			z = 2,
			name = "DealBanner",
		})
		local px = fontPx(p, 68, 28)
		CarKit.art(card, "fx_flag", {
			size = UDim2.fromOffset(px * 1.3, px * 0.7),
			position = UDim2.new(0, 8, 0.5, 0),
			anchor = Vector2.new(0, 0.5),
			z = 7,
			rotation = -8,
			placeholder = false,
		})
		CarKit.title(card, 'ALL PASSES <font color="#FFD23C">BUNDLE</font>', px, {
			position = UDim2.fromOffset(px * 1.3, 0),
			size = UDim2.fromScale(0.5, 1),
			stroke = math.max(3, px / 12),
			rich = true,
			z = 8,
			name = "DealTitle",
		})
		local stampPx = math.round(h * 0.98)
		local dealBuy = math.round(math.max(170 * k, 118)) + math.round(12 * k)
		local stampX = p.inner - dealBuy - 116 - stampPx / 2
		boxArt(card, "art_bundle", stampX - stampPx / 2 - h * 1.1, 5, h * 1.08, h - 10, 6)
		if offer and offer.price then
			priceButton(card, offer.id, "The bundle", "art_bundle", offer.price, {
				px = fontPx(p, 40, 22),
				size = UDim2.fromOffset(math.round(math.max(170 * k, 118)), math.round(math.max(62 * k, 48))),
				position = UDim2.new(1, -math.round(12 * k), 1, -math.round(10 * k)),
				anchor = Vector2.new(1, 1),
				z = 12,
			})
		end
		if sums and sums.isBetter then
			CarKit.stamp(card, "BEST", "DEAL", stampPx, {
				position = UDim2.new(0, stampX, 0.5, 0),
				anchor = Vector2.new(0.5, 0.5),
				z = 14,
			})
			local ribbon = make("Frame", {
				Name = "Save",
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, -math.round(14 * k), 0, math.round(6 * k)),
				Size = UDim2.fromOffset(math.round(math.max(170 * k, 120)), math.round(math.max(34 * k, 24))),
				BackgroundColor3 = CarKit.Red,
				Rotation = -3,
				ZIndex = 13,
			}, card)
			make("UICorner", { CornerRadius = UDim.new(0, 5) }, ribbon)
			make(
				"UIStroke",
				{ Thickness = 2, Color = CarKit.Ink, ApplyStrokeMode = Enum.ApplyStrokeMode.Border },
				ribbon
			)
			CarKit.title(ribbon, ("SAVE %d%%"):format(sums.percent), fontPx(p, 28, 16), {
				align = Enum.TextXAlignment.Center,
				z = 14,
				shadow = false,
				stroke = 2,
			})
			local buyW = math.round(math.max(170 * k, 118)) + math.round(12 * k)
			local strike = make("Frame", {
				Name = "Was",
				BackgroundTransparency = 1,
				AnchorPoint = Vector2.new(1, 1),
				Position = UDim2.new(1, -buyW - 12, 1, -math.round(10 * k)),
				Size = UDim2.fromOffset(math.round(70 * k) + 14, math.round(36 * k) + 6),
				ZIndex = 13,
			}, card)
			CarKit.title(strike, tostring(sums.componentSum), fontPx(p, 30, 17), {
				align = Enum.TextXAlignment.Right,
				color = CarKit.Soft,
				z = 13,
				shadow = false,
				stroke = 2,
			})
			make("Frame", {
				Name = "Line",
				BackgroundColor3 = CarKit.Red,
				BorderSizePixel = 0,
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.fromScale(1, 0.5),
				Size = UDim2.new(0.56, 0, 0, 3),
				Rotation = -6,
				ZIndex = 16,
			}, strike)
			CarKit.text(card, Catalog.PreviewValueTag, fontPx(p, 13, 11), {
				size = UDim2.fromOffset(100, 16),
				position = UDim2.new(1, -buyW - 12, 0, math.round(8 * k)),
				anchor = Vector2.new(1, 0),
				align = Enum.TextXAlignment.Right,
				color = CarKit.Soft,
				z = 13,
			})
		end
		flow(buildTrove, card, gradient, "Deal", 1, 3.5, 14)
		return h
	end

	local function sectionHeader(
		parent: Instance,
		p: Plan,
		y: number,
		icon: string,
		title: string,
		sub: string?
	): number
		local h = fontPx(p, 58, 36)
		CarKit.slot(parent, icon, h, {
			position = UDim2.fromOffset(h / 2, y + h / 2),
			z = 3,
		})
		local px = fontPx(p, 50, 26)
		CarKit.title(parent, title, px, {
			position = UDim2.fromOffset(h + 8, y),
			size = UDim2.fromOffset(p.inner * 0.34, h),
			top = CarKit.White,
			bottom = Color3.fromRGB(190, 224, 255),
			z = 3,
		})
		if sub then
			CarKit.text(parent, sub, fontPx(p, 19, 13), {
				position = UDim2.fromOffset(0, y),
				size = UDim2.new(1, -18, 0, h),
				align = Enum.TextXAlignment.Right,
				color = CarKit.Soft,
				z = 3,
			})
		end
		return h
	end

	local function cashRowBlock(parent: Instance, p: Plan, y: number): number
		table.clear(cashRow)
		local rows = CashPacks.list(rate(), cash())
		local weights = { 1, 1.04, 1.1, 1.18, 1.36 }
		local total = 0
		for _, w in weights do
			total += w
		end
		local avail = p.inner - p.gap * (#rows - 1)
		local tallest = math.round(math.clamp(avail / total * 1.36 * 1.34, 150, 340))
		tallest = math.min(tallest, p.pageH - fontPx(p, 58, 36) - p.gap - 6)
		local x = 0
		for i, row in rows do
			local w = math.floor(avail * weights[i] / total)
			local h = math.round(tallest * (0.82 + 0.18 * (i - 1) / 4))
			local cy = y + tallest - h
			local k = p.k
			local card, _, gradient = CarKit.card(parent, row.pack.family, {
				size = UDim2.fromOffset(w, h),
				position = UDim2.fromOffset(x, cy),
				radius = math.round(12 * math.max(k, 0.6)),
				z = 2,
				name = "Pack_" .. row.pack.id,
			})
			local amountPx = math.min(fontPx(p, 40 + i * 2.5, 19), math.floor(w / 6.4))
			local amount = CarKit.title(card, "+" .. money(row.amount), amountPx, {
				align = Enum.TextXAlignment.Center,
				size = UDim2.new(1, -8, 0, amountPx * 1.1),
				position = UDim2.fromOffset(4, math.round(6 * k)),
				color = CarKit.CashText,
				stroke = math.max(2.5, amountPx / 10),
				z = 8,
				name = "Amount",
			})
			table.insert(cashRow, { amount = amount, pack = row.pack })
			local chipPx = fontPx(p, 17, 12)
			local chip = make("Frame", {
				Name = "Minutes",
				AnchorPoint = Vector2.new(0.5, 0),
				Position = UDim2.new(0.5, 0, 0, amountPx * 1.14 + 6 * k),
				Size = UDim2.new(0.86, 0, 0, chipPx * 1.5),
				BackgroundColor3 = CarKit.Ink,
				BackgroundTransparency = 0.25,
				ZIndex = 8,
			}, card)
			make("UICorner", { CornerRadius = UDim.new(0, 6) }, chip)
			CarKit.text(chip, row.label .. " of earnings", chipPx, {
				align = Enum.TextXAlignment.Center,
				z = 9,
				name = "Label",
			})
			local top = amountPx * 1.14 + chipPx * 1.5 + 8 * k
			local bh = math.round(math.max(50 * k, 44))
			local artH = h - top - bh - 12 * k
			boxArt(card, row.pack.art, 8, top, w - 16, artH, 6)
			priceButton(card, row.pack.id, "This Cash pack", row.pack.art, row.pack.robux, {
				px = fontPx(p, 32, 20),
				size = UDim2.new(1, -math.round(16 * k), 0, bh),
				position = UDim2.new(0.5, 0, 1, -math.round(7 * k)),
				anchor = Vector2.new(0.5, 1),
				z = 12,
			})
			if row.best then
				CarKit.stamp(card, "BEST", "VALUE", math.round(math.max(96 * k, 64)), {
					position = UDim2.new(1, math.round(4 * k), 0, top + 34 * k),
					anchor = Vector2.new(1, 0),
					z = 14,
				})
				flow(buildTrove, card, gradient, "Card", 3, 5, 12)
			end
			x += w + p.gap
		end
		return tallest
	end

	local function passRows(parent: Instance, p: Plan, y: number): number
		local ids = {
			{ "vip", "Vip", "art_vip" },
			{ "double-lap-pay", "Lap", "art_doublelap" },
			{ "expanded-paddock", "Paddock", "art_paddock" },
		}
		local w = math.floor((p.inner - p.gap * 2) / 3)
		local h = math.round(math.clamp(w * 0.78, 200, 340))
		for i, row in ids do
			local offer = Catalog.get(row[1])
			if not offer then
				continue
			end
			local k = p.k
			local card, _, gradient = CarKit.card(parent, row[2], {
				size = UDim2.fromOffset(w, h),
				position = UDim2.fromOffset((i - 1) * (w + p.gap), y),
				radius = math.round(14 * math.max(k, 0.6)),
				z = 2,
				name = "Pass_" .. row[1],
			})
			local px = fontPx(p, 46, 22)
			CarKit.title(card, string.upper(offer.name), px, {
				position = UDim2.fromOffset(math.round(12 * k), 2),
				size = UDim2.new(1, -14, 0, px * 1.1),
				z = 8,
				stroke = math.max(2.5, px / 10),
				top = CarKit.White,
				bottom = edgeTint(row[2]),
			})
			local artY = px * 1.14
			-- Round 4 (C-05): what the pass does sits on its own full-width line above the price, so the price button can
			-- never cover it (on a phone it used to hide half the line)
			local btnH = math.round(math.max(54 * k, 46))
			local bodyPx = fontPx(p, 19, 14)
			local bodyH = math.round(bodyPx * 2.5)
			local bottomH = btnH + bodyH + math.round(16 * k) + 6
			boxArt(card, row[3], 10, artY, w - 20, h - artY - bottomH, 6)
			CarKit.text(card, offer.body, bodyPx, {
				wrap = true,
				align = Enum.TextXAlignment.Center,
				size = UDim2.new(1, -math.round(16 * k), 0, bodyH),
				position = UDim2.new(0.5, 0, 1, -(btnH + math.round(14 * k))),
				anchor = Vector2.new(0.5, 1),
				alignY = Enum.TextYAlignment.Center,
				stroke = 1.5,
				z = 8,
				name = "Body",
			})
			if offer.price then
				priceButton(card, offer.id, offer.name, row[3], offer.price, {
					px = fontPx(p, 34, 22),
					size = UDim2.fromOffset(math.round(math.max(142 * k, 112)), btnH),
					position = UDim2.new(0.5, 0, 1, -math.round(10 * k)),
					anchor = Vector2.new(0.5, 1),
					z = 12,
				})
			end
			flow(buildTrove, card, gradient, "Card", i, nil, 14)
		end
		return h
	end

	local function freeBlock(parent: Instance, p: Plan, y: number): number
		local h = math.round(math.max(190 * p.k, 150))
		local k = p.k
		local card, _, gradient = CarKit.card(parent, "Free", {
			size = UDim2.fromOffset(p.inner, h),
			position = UDim2.fromOffset(0, y),
			radius = 14,
			z = 2,
			name = "FreeCard",
		})
		local artSide = h - 14
		boxArt(card, "art_gift", 12, 7, artSide, artSide, 6)
		local offer = Catalog.get("free-legion")
		local px = fontPx(p, 58, 26)
		CarKit.title(card, offer and offer.name or "FREE GIFT", px, {
			position = UDim2.fromOffset(artSide + 28, math.round(10 * k)),
			size = UDim2.new(0.6, 0, 0, px * 1.1),
			top = CarKit.White,
			bottom = CarKit.Yellow,
			z = 8,
		})
		CarKit.text(card, "Join our group for a free paint. Coming soon!", fontPx(p, 21, 14), {
			position = UDim2.fromOffset(artSide + 28, px * 1.15 + 12 * k),
			size = UDim2.new(0.5, 0, 0, fontPx(p, 54, 34)),
			wrap = true,
			alignY = Enum.TextYAlignment.Top,
			stroke = 1.5,
			z = 8,
		})
		CarKit.button(card, {
			text = "SEE REWARD",
			tone = "Blue",
			px = fontPx(p, 34, 22),
			size = UDim2.fromOffset(math.round(math.max(220 * k, 170)), math.round(math.max(62 * k, 50))),
			position = UDim2.new(1, -math.round(14 * k), 1, -math.round(14 * k)),
			anchor = Vector2.new(1, 1),
			z = 12,
			name = "SeeReward",
			onPress = function()
				if opts.onFreeReward then
					opts.onFreeReward()
				end
			end,
		})
		flow(buildTrove, card, gradient, "Card", 5, nil, 14)
		return h
	end

	-- THE STORE PAGE --------------------------------------------------------------------------------------------

	local function buildPage(host: Frame, p: Plan)
		local bar = if p.tier == "Phone" then 6 else 12
		local scroll = make("ScrollingFrame", {
			Name = "Page",
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = UDim2.fromScale(1, 1),
			ScrollBarThickness = if p.tier == "Phone" then 4 else 8,
			ScrollBarImageColor3 = CarKit.ChromeBottom,
			ScrollingDirection = Enum.ScrollingDirection.Y,
			ClipsDescendants = true,
			ZIndex = 2,
			Selectable = false,
		}, host) :: ScrollingFrame
		page = scroll
		local q: Plan = table.clone(p)
		q.inner = p.inner - bar
		local body = make("Frame", {
			Name = "Body",
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 10),
			ZIndex = 2,
		}, scroll) :: Frame

		local y = 4
		sectionY.featured = 0
		local peek = math.round(math.max((if p.tier == "Desktop" then 190 else 110) * p.k, 60))
		local bannerH = math.round(math.max(112 * p.k, 76))
		local phone = p.tier == "Phone"
		local rowH = if phone
			then math.max(p.pageH - bannerH - p.gap - 26, 150)
			else math.max(p.pageH - bannerH - peek - p.gap * 2 - 8, math.round(230 * p.k))
		local heroW = if phone then q.inner else math.floor(q.inner * 0.645)
		local sideW = q.inner - heroW - p.gap
		local slot = make("Frame", {
			Name = "HeroSlot",
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(0, y),
			Size = UDim2.fromOffset(heroW, rowH),
			ZIndex = 2,
		}, body) :: Frame
		slot:SetAttribute("W", heroW)
		slot:SetAttribute("H", rowH)
		heroSlot = slot
		renderHero()
		local sideH = math.floor((rowH - p.gap) / 2)
		local lapName, lapLine = "DOUBLE LAP PAY", "2x Cash per lap!"
		if phone then
			y += rowH + p.gap
			y += dealBanner(body, q, y) + p.gap
			local halfW = math.floor((q.inner - p.gap) / 2)
			sideCard(body, "vip", "Vip", "art_vip", "VIP", nil, q, { x = 0, y = y, w = halfW, h = 132 })
			sideCard(body, "double-lap-pay", "Lap", "art_doublelap", lapName, lapLine, q, {
				x = halfW + p.gap,
				y = y,
				w = halfW,
				h = 132,
			})
			y += 132 + p.gap * 2
		else
			sideCard(body, "vip", "Vip", "art_vip", "VIP", nil, q, { x = heroW + p.gap, y = y, w = sideW, h = sideH })
			sideCard(body, "double-lap-pay", "Lap", "art_doublelap", lapName, lapLine, q, {
				x = heroW + p.gap,
				y = y + sideH + p.gap,
				w = sideW,
				h = sideH,
			})
			y += rowH + p.gap
			y += dealBanner(body, q, y) + p.gap * 2
		end

		sectionY.cash = y - p.gap
		y += sectionHeader(body, q, y, "cash", "CASH PACKS", "Packs grow as your Raceway grows!") + p.gap
		y += cashRowBlock(body, q, y) + p.gap * 2

		sectionY.passes = y - p.gap
		y += sectionHeader(body, q, y, "vip", "PASSES", "Forever yours, in every World") + p.gap
		y += passRows(body, q, y) + p.gap * 2

		sectionY.free = y - p.gap
		y += sectionHeader(body, q, y, "freeGift", "FREE", nil) + p.gap
		y += freeBlock(body, q, y) + p.gap

		-- Round 4 (C-05): one PREVIEW line only, the panel's own note under the page (this second one repeated it)
		y += 12
		body.Size = UDim2.new(1, 0, 0, y)
		scroll.CanvasSize = UDim2.fromOffset(0, y)
		buildTrove:Connect(scroll:GetPropertyChangedSignal("CanvasPosition"), function()
			local canvasH = scroll.CanvasSize.Y.Offset
			local k = if canvasH > 0 then scroll.AbsoluteCanvasSize.Y / canvasH else 1
			local at = scroll.CanvasPosition.Y / k + 40
			-- Round 4 (C-05): at the bottom of the page the last section cannot reach the top, so the deepest section that is
			-- in view wins (pressing FREE used to leave PASSES lit)
			local bottom = scroll.CanvasPosition.Y >= scroll.AbsoluteCanvasSize.Y - scroll.AbsoluteWindowSize.Y - 2
			if bottom then
				at = (scroll.CanvasPosition.Y + scroll.AbsoluteWindowSize.Y) / k - 60
			end
			local best = "featured"
			for _, id in { "featured", "cash", "passes", "free" } do
				if at >= (sectionY[id] or 0) then
					best = id
				end
			end
			if best ~= activeTab then
				activeTab = best
				for tab, refs in tabButtons do
					refs.paint(tab == best)
				end
			end
		end)
		motion.setViewport(scroll)
	end

	build = function()
		buildTrove:Clean()
		heroTrove = buildTrove:Extend()
		table.clear(buttons)
		table.clear(tabButtons)
		table.clear(cashRow)
		page = nil
		heroSlot = nil
		cashLabel = nil
		motion.clear()
		counters.builds += 1

		local D = overlay:designSize()
		builtFor = D
		local p = plan(D)
		currentPlan = p
		CarKit.setStrokeScale(ctx.screen:uiScale())
		local root = buildTrove:Add(make("Frame", {
			Name = "ShopRoot",
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			ZIndex = 2,
		}, overlay.content)) :: Frame
		local shell = CarKit.board(root, {
			size = UDim2.fromOffset(p.panel.X, p.panel.Y),
			position = UDim2.fromScale(0.5, 0.5),
			anchor = Vector2.new(0.5, 0.5),
			z = 2,
			radius = if p.tier == "Phone" then 12 else 18,
			name = "Panel",
		})
		panel = shell

		CarKit.text(shell, "PREVIEW prices. Nothing can be bought yet.", 13, {
			size = UDim2.new(1, -24, 0, FOOT),
			position = UDim2.new(0, 12, 1, -FOOT - 3),
			align = Enum.TextXAlignment.Center,
			color = CarKit.Soft,
			z = 6,
			name = "PreviewFoot",
		})

		-- header: title, tabs, Cash, close
		local header = make("Frame", {
			Name = "Header",
			BackgroundTransparency = 1,
			Size = UDim2.new(1, -p.pad * 2, 0, p.headerH),
			Position = UDim2.fromOffset(p.pad, 4),
			ZIndex = 5,
		}, shell) :: Frame
		local titlePx = if p.tier == "Desktop" then 62 else 40
		local titleW = math.round(titlePx * 1.75)
		CarKit.title(header, "SHOP", titlePx, {
			position = UDim2.fromOffset(2, 0),
			size = UDim2.fromOffset(titleW, p.headerH),
			top = CarKit.White,
			bottom = Color3.fromRGB(190, 214, 255),
			z = 6,
			name = "ShopTitle",
		})
		local flagW = if p.tier == "Desktop" then titlePx * 1.1 else 0
		if flagW > 0 then
			CarKit.art(header, "fx_flag", {
				size = UDim2.fromOffset(flagW, flagW / 2),
				position = UDim2.fromOffset(titleW + flagW / 2, p.headerH * 0.46),
				z = 6,
				rotation = 8,
				placeholder = false,
			})
		end
		local closePx = if p.tier == "Phone" then 44 else 52
		local close = make("ImageButton", {
			Name = "Close",
			BackgroundTransparency = 1,
			Image = "",
			Size = UDim2.fromOffset(closePx, closePx),
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.fromScale(1, 0.5),
			ZIndex = 8,
		}, header) :: ImageButton
		CarKit.slot(close, "close", closePx, { position = UDim2.fromScale(0.5, 0.5), z = 8, fallback = "Close" })
		close.Activated:Connect(function()
			shop:close()
		end)
		-- the Cash counter with its green plus
		local cashW = if p.tier == "Desktop" then 204 else 140
		local cashBox = CarKit.board(header, {
			size = UDim2.fromOffset(cashW, if p.tier == "Desktop" then 50 else 40),
			position = UDim2.new(1, -closePx - 8, 0.5, 0),
			anchor = Vector2.new(1, 0.5),
			z = 7,
			radius = 10,
			top = CarKit.Well,
			bottom = CarKit.Well,
			name = "CashBox",
		})
		local iconPx = if p.tier == "Desktop" then 48 else 32
		CarKit.slot(cashBox, "cash", iconPx, { position = UDim2.new(0, iconPx / 2 + 2, 0.5, 0), z = 8 })
		cashLabel = CarKit.title(cashBox, money(cash()), if p.tier == "Desktop" then 28 else 20, {
			position = UDim2.fromOffset(iconPx + 4, 0),
			size = UDim2.new(1, -iconPx - 42, 1, 0),
			color = CarKit.CashText,
			shadow = false,
			stroke = 2,
			z = 9,
			name = "CashValue",
		})
		local plus = make("ImageButton", {
			Name = "CashPlus",
			BackgroundTransparency = 1,
			Image = "",
			Size = UDim2.fromOffset(36, 36),
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -2, 0.5, 0),
			ZIndex = 9,
		}, cashBox) :: ImageButton
		CarKit.slot(plus, "plus", 32, { position = UDim2.fromScale(0.5, 0.5), z = 9, fallback = "Plus" })
		plus.Activated:Connect(function()
			showTab("cash", true)
		end)
		-- tabs
		local tabsX = titleW + flagW + 8
		local tabsW = p.inner - tabsX - cashW - closePx - 16
		local gap = 4
		local tabW = math.floor((tabsW - gap * (#TABS - 1)) / #TABS)
		local tabH = if p.tier == "Phone" then 40 else 48
		for i, tab in TABS do
			local px = math.clamp(math.floor(tabW / 3.9), 15, 30)
			local button = make("TextButton", {
				Name = "Tab_" .. tab.id,
				Text = "",
				AutoButtonColor = false,
				BackgroundColor3 = CarKit.Well,
				Position = UDim2.new(0, tabsX + (i - 1) * (tabW + gap), 0.5, -tabH / 2),
				Size = UDim2.fromOffset(tabW, tabH),
				ZIndex = 7,
				Selectable = true,
			}, header) :: TextButton
			make("UICorner", { CornerRadius = UDim.new(0, 9) }, button)
			make(
				"UIStroke",
				{ Thickness = 2, Color = CarKit.ChromeBottom, ApplyStrokeMode = Enum.ApplyStrokeMode.Border },
				button
			)
			local label = CarKit.title(button, tab.label, px, {
				align = Enum.TextXAlignment.Center,
				shadow = false,
				stroke = 2,
				z = 8,
				name = "Label",
			})
			local function paintTab(on: boolean)
				button.BackgroundColor3 = if on then CarKit.Yellow else CarKit.Well
				label.TextColor3 = if on then CarKit.Ink else CarKit.White
				local s = label:FindFirstChildOfClass("UIStroke")
				if s then
					s.Enabled = not on
				end
			end
			paintTab(tab.id == activeTab)
			tabButtons[tab.id] = { paint = paintTab, button = button }
			button.Activated:Connect(function()
				pcall(function()
					Sounds.play("Tap")
				end)
				showTab(tab.id, true)
			end)
		end

		local stage = make("Frame", {
			Name = "Stage",
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(p.pad, p.headerH + 6),
			Size = UDim2.new(1, -p.pad * 2 + 4, 1, -p.headerH - p.pad - 8 - FOOT),
			ZIndex = 3,
		}, shell) :: Frame
		buildPage(stage, p)
		if isShopOpen and visible then
			motion.start()
		end
		refresh()
	end

	showTab = function(id: string, animate: boolean?)
		activeTab = id
		for tab, refs in tabButtons do
			refs.paint(tab == id)
		end
		shop:scrollTo(id, animate)
	end

	-- PUBLIC ----------------------------------------------------------------------------------------------------

	function shop.scrollTo(_self: Shop, id: string, animate: boolean?)
		local scroll = page
		if not scroll then
			return
		end
		-- canvas positions are real pixels; the page is laid out in design pixels
		local canvasH = scroll.CanvasSize.Y.Offset
		local y = (sectionY[id] or 0) * (if canvasH > 0 then scroll.AbsoluteCanvasSize.Y / canvasH else 1)
		if animate and not Motion.reduced() then
			Motion.tween(scroll, "ShopScroll", Motion.info(0.32), { CanvasPosition = Vector2.new(0, y) })
		else
			scroll.CanvasPosition = Vector2.new(0, y)
		end
	end

	function shop.setSlide(_self: Shop, index: number)
		slide = ((index - 1) % #SLIDES) + 1
		renderHero()
		refresh()
	end

	local function setBlur(on: boolean)
		if opts.blur == false then
			return
		end
		if on and not blur then
			local b = Instance.new("BlurEffect")
			b.Name = "ShopBlur"
			b.Size = 10
			b.Parent = Lighting
			blur = b
		elseif not on and blur then
			blur:Destroy()
			blur = nil
		end
	end
	trove:Add(function()
		setBlur(false)
	end)

	function shop.open(self: Shop, returnTo: GuiObject?)
		if isShopOpen then
			return
		end
		isShopOpen = true
		activeTab = "featured"
		slide = 1
		overlay:setBack(function()
			self:close()
		end)
		overlay:applyScale()
		overlay:open(nil, returnTo)
		build()
		setBlur(true)
		motion.start()
		nextAdvance = os.clock() + 9
		if not Motion.reduced() and panel then
			Motion.pop(panel, 0.94)
		end
	end

	function shop.openSection(self: Shop, name: string, returnTo: GuiObject?)
		self:open(returnTo)
		showTab(string.lower(name), false)
	end

	function shop.openAt(self: Shop, sectionId: string?, _offerId: string?, returnTo: GuiObject?)
		self:open(returnTo)
		if sectionId then
			showTab(string.lower(sectionId), false)
		end
	end

	function shop.openExpandedPaddock(self: Shop, returnTo: GuiObject?)
		self:openSection("passes", returnTo)
	end

	function shop.openDoubleLapPay(self: Shop, returnTo: GuiObject?)
		self:openSection("passes", returnTo)
	end

	function shop.close(_self: Shop)
		if not isShopOpen then
			return
		end
		isShopOpen = false
		if pendingHandle then
			pendingHandle:cancel()
			pendingHandle = nil
			pendingId = nil
		end
		closeSoon()
		motion.stop()
		setBlur(false)
		overlay:close()
		if opts.onClose then
			opts.onClose()
		end
	end

	function shop.isOpen(_self: Shop): boolean
		return isShopOpen
	end

	-- a rebuild drops the page's scroll and picks, so only a real size change gets one
	function shop.layout(_self: Shop)
		if isShopOpen and overlay:designSize() ~= builtFor then
			overlay:applyScale()
			build()
		end
	end

	function shop.setVisible(_self: Shop, on: boolean)
		visible = on
		overlay.root.Visible = on and isShopOpen
		if on and isShopOpen then
			motion.start()
		else
			motion.stop()
		end
	end

	function shop.forceState(_self: Shop, id: string, state: string?)
		forced[id] = state
		refresh()
	end

	function shop.resetFixtures(_self: Shop)
		table.clear(forced)
		adapter:clearFixtures()
		refresh()
	end

	function shop.pressOffer(_self: Shop, id: string)
		local offer = Catalog.get(id)
		press(id, if offer then offer.name else id, nil)
	end

	function shop.getAdapter(_self: Shop): ShopPurchaseAdapter.Adapter
		return adapter
	end

	function shop.getDebugState(_self: Shop): { [string]: any }
		return {
			open = isShopOpen,
			tab = activeTab,
			slide = slide,
			builds = counters.builds,
			requests = counters.requests,
			pending = pendingId,
			motion = motion.stats(),
			adapter = adapter:stats(),
			tier = currentPlan and currentPlan.tier,
			k = currentPlan and currentPlan.k,
		}
	end

	function shop.destroy(_self: Shop)
		trove:Destroy()
	end

	shop.root = overlay.root

	trove:Connect(ctx.store.Changed, function(key: string)
		if isShopOpen and key == "cash" then
			refresh()
		end
	end)
	trove:Connect(adapter.Changed, function()
		if isShopOpen then
			refresh()
		end
	end)

	-- carousel and live relayout, only while open
	trove:Add(task.spawn(function()
		while true do
			task.wait(0.5)
			if not isShopOpen or not visible then
				continue
			end
			shop:layout()
			if
				opts.autoAdvance ~= false
				and not Motion.reduced()
				and os.clock() >= nextAdvance
				and not pendingId
				and not soon
			then
				nextAdvance = os.clock() + 9
				shop:setSlide(slide + 1)
			end
		end
	end))

	return shop
end

return ShopMock
