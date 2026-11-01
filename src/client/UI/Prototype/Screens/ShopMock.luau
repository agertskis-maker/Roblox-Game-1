--!strict
-- ShopMock: the Shop (Lane 3, BRIEF M10, 2026-11-01). PREVIEW only: nothing here can be bought. There is no
-- MarketplaceService call, no product id, no pass id and no grant anywhere in this screen: every price button goes
-- through ShopPurchaseAdapter, shows "Checking..." for about 0.4 s, then a friendly "Coming soon!" card. The adapter keeps
-- the counters (adapter:stats()) that prove zero Marketplace calls and zero grants.
--
--   local shop = ShopMock.new(ctx, { onClose = fn?, adapter = A?, autoAdvance = true?, blur = true?, cash = false?,
--                                    previewValue = false? })
--   shop:open(returnTo?)                     -- starts at Featured
--   shop:openAt(sectionId?, offerId?, returnTo?)   -- parking-full entry: openAt("passes", "expanded-paddock", button)
--   shop:close()  shop:isOpen()  shop:layout()  shop:setVisible(on)  shop:destroy()
--   shop:scrollTo(sectionId, animate?)       -- "featured" | "passes" | "cash" | "style" | "free"
--   shop:getDebugState()
--
-- FIXTURES (preview only; how a reviewer or a test exercises every state):
--   shop:forceState(offerId, "owned" | "unavailable" | "error" | "pending" | nil)
--   shop:setFixture("owned" | "unavailable" | "error" | "pending", id | { ids } | "*", on?)   -- the same, many ids
--   shop:setFixture("hold", true)            -- requests never answer: stays "Checking..." until the shop closes
--   shop:setFixture("cash", true)            -- show the hidden Cash section and its tab
--   shop:setFixture("previewValue", true)    -- BEST DEAL / SAVE x% / struck-through sum, marked PREVIEW VALUE
--   shop:setFixture("longText", true)        -- every name and line 30 percent longer
--   shop:setFixture("missingArt", true)      -- every icon replaced by the solid fallback glyph
--   shop:setFixture("cashAmountsPending", true)   -- the Cash packs show "Amount pending"
--   shop:setFixture("cashValue", 123456789)  -- a large Cash counter (nil clears)
--   shop:resetFixtures()  shop:pressOffer(offerId)  shop:setSlide(n)  shop:getAdapter()
--
-- Layout (BRIEF M10-01b, M10-14a, M10-14b) is computed from the safe design size every time the viewport changes
-- (Shop/ShopLayout): Desktop, Tablet and Phone landscape reflow live with the scroll position kept. One vertical scroll
-- container; the header stays; tabs scroll to their section and highlight as you scroll, without fighting a programmed
-- scroll. The game keeps running behind (the dim is a darkening and a slight blur, never black).
--
-- Loops (carousel, shine, sparkles, price-button bounce, the pending spinner, the blur) belong to ONE scheduler thread
-- and a few finite tweens that exist only while the shop is open and visible; closing or hiding cleans them all up. A
-- close during "Checking..." cancels the request, restores focus and never reopens the shop later.

local Debris = game:GetService("Debris")
local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Prototype = script.Parent.Parent
local Arcade = require(Prototype.Arcade)
local Motion = require(Prototype.Motion)
local PreviewTokens = require(Prototype.PreviewTokens)
local ShopKit = require(Prototype.ShopKit)
local ShopPurchaseAdapter = require(Prototype.ShopPurchaseAdapter)
local Sounds = require(Prototype.Sounds)
local Overlay = require(script.Parent.Overlay)
local ShopArt = require(script.Parent.Shop.ShopArt)
local ShopCards = require(script.Parent.Shop.ShopCards)
local ShopLayout = require(script.Parent.Shop.ShopLayout)
local Catalog = require(ReplicatedStorage.Shared.UI.ShopPreviewCatalog)
local Format = require(ReplicatedStorage.Shared.UI.Format)
local Tokens = require(ReplicatedStorage.Shared.UI.Tokens)

local A = PreviewTokens.Arcade
local S = PreviewTokens.Shop
local M = S.Motion
local make = Arcade.make
local WHITE = Color3.new(1, 1, 1)

local ShopMock = {}

ShopMock.StateNames = { "owned", "unavailable", "error", "pending" }
ShopMock.FixtureNames = {
	"owned",
	"unavailable",
	"error",
	"pending",
	"hold",
	"cash",
	"previewValue",
	"longText",
	"missingArt",
	"cashAmountsPending",
	"cashValue",
}

export type Options = {
	onClose: (() -> ())?,
	adapter: ShopPurchaseAdapter.Adapter?,
	autoAdvance: boolean?, -- default true (pauses on hover, press, focus and for 14 s after any manual move)
	blur: boolean?, -- default true
	cash: boolean?, -- the Cash section; default false (hidden until Brian L and Adam approve Developer Products)
	previewValue: boolean?, -- the PREVIEW VALUE deal-claim fixture; default false
}

export type DebugState = { [string]: any }

export type Shop = {
	root: Frame,
	layout: (self: Shop) -> (),
	setVisible: (self: Shop, on: boolean) -> (),
	open: (self: Shop, returnTo: GuiObject?) -> (),
	openAt: (self: Shop, sectionId: string?, offerId: string?, returnTo: GuiObject?) -> (),
	close: (self: Shop) -> (),
	isOpen: (self: Shop) -> boolean,
	destroy: (self: Shop) -> (),
	scrollTo: (self: Shop, sectionId: string, animate: boolean?) -> (),
	setFixture: (self: Shop, name: string, value: any, on: boolean?) -> (),
	forceState: (self: Shop, offerId: string, state: string?) -> (),
	resetFixtures: (self: Shop) -> (),
	pressOffer: (self: Shop, offerId: string) -> (),
	setSlide: (self: Shop, index: number) -> (),
	getAdapter: (self: Shop) -> ShopPurchaseAdapter.Adapter,
	getDebugState: (self: Shop) -> DebugState,
}

type FixtureState = {
	cash: boolean,
	previewValue: boolean,
	longText: boolean,
	missingArt: boolean,
	cashAmountsPending: boolean,
	cashValue: number?,
	forcedPending: { [string]: boolean },
}

type SoonRefs = {
	root: Frame,
	card: ShopKit.Card,
	artHolder: Frame,
	artPx: number,
	name: TextLabel,
	button: ShopKit.PriceButton,
	pop: UIScale,
}

local function lastInputIsGamepad(): boolean
	return UserInputService:GetLastInputType().Name:sub(1, 7) == "Gamepad"
end

-- "30 percent longer": the fixture appends the first third of the string to itself (a stress test, not copy).
local function stretch(text: string): string
	return text .. " " .. text:sub(1, math.ceil(#text * 0.3))
end

function ShopMock.new(ctx: Overlay.Ctx, options: Options?): Shop
	local opts: Options = options or {}
	local shop: Shop

	local overlay = Overlay.new(ctx, { name = "ShopMock", dimTransparency = 0.5, slide = false })
	local trove = overlay.trove
	local adapter: ShopPurchaseAdapter.Adapter = opts.adapter or ShopPurchaseAdapter.new()
	if opts.adapter == nil then
		trove:Add(function()
			adapter:destroy()
		end)
	end
	local buildTrove = trove:Extend() -- the page, header and cards: rebuilt on every layout
	local openTrove = trove:Extend() -- everything that exists only while the shop is open and visible

	local fixtures: FixtureState = {
		cash = opts.cash == true,
		previewValue = opts.previewValue == true,
		longText = false,
		missingArt = false,
		cashAmountsPending = false,
		cashValue = nil,
		forcedPending = {},
	}

	local destroyed = false
	local shopOpen = false
	local visible = true
	local openToken = 0
	local pendingId: string? = nil
	local pendingHandle: ShopPurchaseAdapter.Handle? = nil
	local soonOpen = false
	local lastSource: GuiObject? = nil
	local views: { [string]: { ShopCards.View } } = {}
	local hero: ShopCards.Hero? = nil
	local layoutInfo: ShopLayout.Layout? = nil
	local page: ScrollingFrame? = nil
	local popScale: UIScale? = nil
	local closeBody: GuiObject? = nil
	local cue: GuiObject? = nil
	local tip: Frame? = nil
	local tipThread: thread? = nil
	local tabScroll: ScrollingFrame? = nil
	local tabs: { [string]: ShopKit.Tab } = {}
	local sectionY: { [string]: number } = {}
	local sectionOrder: { string } = {}
	local activeSection = "featured"
	local scrollMax = 0
	local programmaticUntil = 0
	local collectionSet: ((number, string) -> ())? = nil
	local cashCount: ShopKit.CountUp? = nil
	local soon: SoonRefs? = nil
	local blur: BlurEffect? = nil
	local schedulerThread: thread? = nil
	local relayoutQueued = false
	local stylePick: { [string]: number } = {}
	local counters = { ticks = 0, shines = 0, bursts = 0, advances = 0, builds = 0, bounces = 0 }
	local footerText = ""

	local refreshViews: () -> ()
	local buildAll: (preserveScroll: boolean) -> ()
	local startLoops: () -> ()
	local stopLoops: () -> ()
	local showComingSoon: (offerId: string) -> ()
	local closeSoon: () -> ()
	local requestRelayout: () -> ()
	local scrollTo: (sectionId: string, animate: boolean?) -> ()

	local function cashValue(): number
		return fixtures.cashValue or ctx.store:get().cash
	end

	-- STATE ------------------------------------------------------------------------------------------------------

	local function ownsPartOf(offer: Catalog.Offer): boolean
		for _, id in offer.includes or {} do
			if adapter:ownership(id) then
				return true
			end
		end
		return false
	end

	-- What every card shows for an offer. The exact copy is the brief's (M10-08a).
	local function stateOf(offerId: string): ShopCards.ViewState
		local offer = Catalog.get(offerId)
		if not offer then
			return { kind = "Disabled", label = "Unavailable right now" }
		end
		if offer.kind == "Medal" then
			return { kind = "Locked", label = offer.lockedText or "Locked" }
		end
		if pendingId == offerId or fixtures.forcedPending[offerId] then
			return { kind = "Pending", label = "Checking..." }
		end
		if adapter:ownership(offerId) then
			return { kind = "Owned", label = "OWNED" }
		end
		if offer.kind == "Bundle" and ownsPartOf(offer) then
			return { kind = "Blocked", label = "You already own part of this bundle" }
		end
		local availability = adapter:availability(offerId)
		if availability == "Error" then
			return { kind = "Error", label = "Could not load this item. Try again." }
		elseif availability == "Unavailable" then
			return { kind = "Unavailable", label = "Unavailable right now" }
		end
		return { kind = "Idle", label = Catalog.priceLabel(offer) }
	end

	local function setViewLoops(on: boolean)
		for _, list in views do
			for _, view in list do
				local button = view.button
				if button then
					button.setLoops(on)
				end
			end
		end
	end

	refreshViews = function()
		for id, list in views do
			local state = stateOf(id)
			for _, view in list do
				view.apply(state)
			end
		end
		local set = collectionSet
		if set then
			local owned = 0
			for _, id in Catalog.PassIds do
				if adapter:ownership(id) then
					owned += 1
				end
			end
			set(owned / #Catalog.PassIds, string.format("%d / %d owned", owned, #Catalog.PassIds))
		end
	end

	-- A local Style look: the car (or decal, or wheel) takes the next swatch. Never a purchase, never the adapter.
	local function swatch(offerId: string, colour: Color3?)
		for _, view in views[offerId] or {} do
			local tint = view.setTint
			if tint then
				tint(colour)
			end
		end
	end
	local function stylePreview(offerId: string)
		local offer = Catalog.get(offerId)
		if not offer or not offer.swatches then
			return
		end
		local count = #offer.swatches
		stylePick[offerId] = ((stylePick[offerId] or 0) % count) + 1
		swatch(offerId, offer.swatches[stylePick[offerId]])
	end

	-- THE ONE PRESS PATH: every price button and every card goes through here, then through the adapter.
	local function press(offerId: string, source: GuiObject?)
		if destroyed or not shopOpen or soonOpen then
			return
		end
		local offer = Catalog.get(offerId)
		if not offer then
			return
		end
		if offer.kind == "Style" then
			stylePreview(offerId)
			return
		end
		local state = stateOf(offerId)
		if pendingId ~= nil or state.kind == "Pending" then
			return -- rapid repeated presses and a second item while one is being checked do nothing
		end
		if state.kind ~= "Idle" and state.kind ~= "Error" then
			return -- owned, unavailable, blocked and locked cards do not start anything
		end
		lastSource = source
		pendingId = offerId
		refreshViews()
		local token = openToken
		pendingHandle = adapter:request(offerId, function(result: ShopPurchaseAdapter.Result)
			if destroyed or token ~= openToken or not shopOpen then
				return -- the shop was closed (or reopened) meanwhile: this answer is dropped, never shown
			end
			pendingId = nil
			pendingHandle = nil
			refreshViews()
			if result.status == "ComingSoon" and adapter:availability(offerId) == "Available" then
				showComingSoon(offerId)
			end
		end)
	end

	local env: ShopCards.Env = {
		trove = buildTrove,
		tier = "Desktop",
		fixtures = fixtures,
		stateOf = stateOf,
		press = press,
		register = function(offerId: string, view: ShopCards.View)
			local list = views[offerId]
			if not list then
				list = {}
				views[offerId] = list
			end
			table.insert(list, view)
		end,
		swatch = swatch,
		text = function(text: string): string
			if fixtures.longText then
				return stretch(text)
			end
			return text
		end,
		owned = function(offerId: string): boolean
			return adapter:ownership(offerId)
		end,
	}

	-- TABS AND SCROLL ----------------------------------------------------------------------------------------------

	local function setActiveTab(id: string)
		activeSection = id
		for tabId, tab in tabs do
			tab.setActive(tabId == id)
		end
		local scroller = tabScroll
		local tab = tabs[id]
		if scroller and tab and scroller.CanvasSize.X.Offset > scroller.AbsoluteSize.X then
			-- a scrollable tab row: keep the active pill in view
			local left = tab.root.AbsolutePosition.X - scroller.AbsolutePosition.X + scroller.CanvasPosition.X
			local viewW = scroller.AbsoluteSize.X
			local x = scroller.CanvasPosition.X
			if left < x then
				x = left - 6
			elseif left + tab.root.AbsoluteSize.X > x + viewW then
				x = left + tab.root.AbsoluteSize.X - viewW + 6
			end
			scroller.CanvasPosition = Vector2.new(math.max(x, 0), 0)
		end
	end

	scrollTo = function(sectionId: string, animate: boolean?)
		local p = page
		local y = sectionY[sectionId]
		if not p or y == nil then
			return
		end
		local goal = math.clamp(y, 0, scrollMax)
		setActiveTab(sectionId)
		if animate and not Motion.reduced() then
			programmaticUntil = os.clock() + M.TabScrollSeconds + 0.15
			Motion.tween(
				p,
				"scroll",
				Motion.info(M.TabScrollSeconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{ CanvasPosition = Vector2.new(0, goal) }
			)
		else
			programmaticUntil = os.clock() + 0.1
			Motion.cancelAll(p)
			p.CanvasPosition = Vector2.new(0, goal)
		end
	end

	-- Highlights the tab of the section under the top of the page as the player scrolls. A programmed scroll (a tab
	-- press, an entry point) is left alone until it lands, so the highlight never fights it.
	local function onScroll()
		local p = page
		if not p then
			return
		end
		local y = p.CanvasPosition.Y
		local scrollCue = cue
		if scrollCue then
			scrollCue.Visible = y < 30 and scrollMax > 60
		end
		if os.clock() < programmaticUntil then
			return
		end
		local pick = sectionOrder[1] or "featured"
		for _, id in sectionOrder do
			if sectionY[id] <= y + 30 then
				pick = id
			end
		end
		if scrollMax > 0 and y >= scrollMax - 4 then
			pick = sectionOrder[#sectionOrder] or pick
		end
		if pick ~= activeSection then
			setActiveTab(pick)
		end
	end

	-- BUILDING -----------------------------------------------------------------------------------------------------

	local function sectionHeader(parent: Frame, section: Catalog.Section, L: ShopLayout.Layout, rightReserve: number)
		local hh = L.sectionHeaderH
		local iconPx = hh - 14
		local holder: Frame = make("Frame", {
			Name = "Icon",
			Position = UDim2.fromOffset(4, 7),
			Size = UDim2.fromOffset(iconPx, iconPx),
			BackgroundTransparency = 1,
			ZIndex = 9,
			Parent = parent,
		})
		ShopKit.icon(holder, if fixtures.missingArt then "__missing__" else section.icon)
		local titleSize = if L.tier == "Desktop" then 36 elseif L.tier == "Tablet" then 30 else 26
		local x = iconPx + 14
		local title = ShopKit.label(parent, section.title, titleSize, { name = "SectionTitle", z = 9, outline = 3 })
		title.Position = UDim2.fromOffset(x, 2)
		title.Size = UDim2.new(1, -x - rightReserve, 0, titleSize + 8)
		if section.subtitle then
			local subtitle = ShopKit.label(parent, section.subtitle, 17, {
				name = "Subtitle",
				colour = S.Color.Grey,
				z = 9,
			})
			subtitle.Position = UDim2.fromOffset(x, 2 + titleSize + 8)
			subtitle.Size = UDim2.new(1, -x - rightReserve, 0, 22)
		end
	end

	local function newPlan(w: number, orientation: "Tall" | "Wide", extra: { [string]: any }?): ShopCards.Plan
		local plan: ShopCards.Plan = {
			w = w,
			h = 0,
			z = 9,
			orientation = orientation,
			showDetail = false,
		}
		for key, value in extra or {} do
			(plan :: any)[key] = value
		end
		return plan
	end

	-- A grid of cards (Style, Cash): four tall columns on Desktop, two wide columns elsewhere. Rows share a height.
	local function placeGrid(frame: Frame, ids: { string }, top: number, L: ShopLayout.Layout): number
		local cols = L.gridCols
		local orientation: "Tall" | "Wide" = if L.gridHorizontal then "Wide" else "Tall"
		local rows = math.ceil(#ids / cols)
		local y = top
		for r = 0, rows - 1 do
			local rowH = if L.gridHorizontal then L.gridH else 0
			for c = 1, cols do
				local offer = Catalog.get(ids[r * cols + c] or "")
				if offer then
					rowH = math.max(rowH, ShopCards.measure(env, offer, newPlan(L.gridW, orientation)))
				end
			end
			for c = 1, cols do
				local offer = Catalog.get(ids[r * cols + c] or "")
				if offer then
					local plan = newPlan(L.gridW, orientation, { h = rowH })
					local view = ShopCards.offer(env, frame, offer, plan)
					view.root.Position = UDim2.fromOffset((c - 1) * (L.gridW + L.gap), y)
				end
			end
			y += rowH + L.gap
		end
		return y - L.gap
	end

	local function buildFeatured(frame: Frame, L: ShopLayout.Layout): number
		local heroCard = ShopCards.hero(env, frame, Vector2.new(L.heroW, L.heroH), 9)
		heroCard.root.Position = UDim2.fromOffset(0, 0)
		hero = heroCard
		local sideIds = { "vip", "double-lap-pay" }
		for i, id in sideIds do
			local offer = Catalog.get(id)
			if offer then
				local plan = newPlan(L.sideW, "Wide", {
					h = L.sideH,
					showTag = false,
					artSide = L.sideH - 30,
					stamp = true,
					name = "Side_" .. id,
				})
				local view = ShopCards.offer(env, frame, offer, plan)
				if L.sideStacked then
					view.root.Position = UDim2.fromOffset(L.heroW + L.gap, (i - 1) * (L.sideH + L.gap))
				else
					view.root.Position = UDim2.fromOffset((i - 1) * (L.sideW + L.gap), L.heroH + L.gap)
				end
			end
		end
		if L.sideStacked then
			return L.heroH
		end
		return L.heroH + L.gap + L.sideH
	end

	local function buildPasses(frame: Frame, section: Catalog.Section, L: ShopLayout.Layout): number
		local rightW = if L.tier == "Phone" then 250 else 330
		sectionHeader(frame, section, L, rightW + 10)
		-- the collection bar: "Collection  0 / 3 owned"
		local box: Frame = make("Frame", {
			Name = "Collection",
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, 0, 0, 12),
			Size = UDim2.fromOffset(rightW, 36),
			BackgroundTransparency = 1,
			ZIndex = 9,
			Parent = frame,
		})
		local word = ShopKit.label(box, "Collection", 18, { name = "CollectionLabel", z = 9 })
		word.Position = UDim2.fromOffset(0, 3)
		word.Size = UDim2.fromOffset(100, 30)
		local track, set = Overlay.progress(box, "Green", 9)
		track.Position = UDim2.fromOffset(106, 5)
		track.Size = UDim2.new(1, -106, 0, 26)
		collectionSet = set

		local pad = L.panelPad
		local top = L.sectionHeaderH + 6
		local bundle = Catalog.get("all-passes-bundle")
		local passIds = { "double-lap-pay", "expanded-paddock", "vip" }
		local panelH = 0
		local placements: { { offer: Catalog.Offer, plan: ShopCards.Plan, x: number, y: number } } = {}
		if bundle then
			if L.passMode == "Row" then
				local rowH = ShopCards.measure(env, bundle, newPlan(L.bundleW, "Wide", { big = true }))
				for _, id in passIds do
					local offer = Catalog.get(id)
					if offer then
						rowH = math.max(
							rowH,
							ShopCards.measure(env, offer, newPlan(L.passW, "Tall", { showDetail = true }))
						)
					end
				end
				table.insert(placements, {
					offer = bundle,
					plan = newPlan(L.bundleW, "Wide", { big = true, h = rowH }),
					x = pad,
					y = pad,
				})
				for i, id in passIds do
					local offer = Catalog.get(id)
					if offer then
						table.insert(placements, {
							offer = offer,
							plan = newPlan(L.passW, "Tall", { showDetail = true, h = rowH, stamp = false }),
							x = pad + L.bundleW + L.passGap + (i - 1) * (L.passW + L.passGap),
							y = pad,
						})
					end
				end
				panelH = rowH + 2 * pad
			elseif L.passMode == "Grid" then
				local bundleH = ShopCards.measure(env, bundle, newPlan(L.bundleW, "Wide", { big = true }))
				table.insert(placements, {
					offer = bundle,
					plan = newPlan(L.bundleW, "Wide", { big = true, h = bundleH }),
					x = pad,
					y = pad,
				})
				local rowH = 0
				for _, id in passIds do
					local offer = Catalog.get(id)
					if offer then
						rowH = math.max(
							rowH,
							ShopCards.measure(env, offer, newPlan(L.passW, "Tall", { showDetail = true }))
						)
					end
				end
				for i, id in passIds do
					local offer = Catalog.get(id)
					if offer then
						table.insert(placements, {
							offer = offer,
							plan = newPlan(L.passW, "Tall", { showDetail = true, h = rowH }),
							x = pad + (i - 1) * (L.passW + L.passGap),
							y = pad + bundleH + L.passGap,
						})
					end
				end
				panelH = 2 * pad + bundleH + L.passGap + rowH
			else
				local y = pad
				local order = { "all-passes-bundle", "double-lap-pay", "expanded-paddock", "vip" }
				for _, id in order do
					local offer = Catalog.get(id)
					if offer then
						local isBundle = id == "all-passes-bundle"
						local planExtra: { [string]: any } = { showDetail = true, big = isBundle }
						local height = ShopCards.measure(env, offer, newPlan(L.bundleW, "Wide", planExtra))
						planExtra.h = height
						table.insert(placements, {
							offer = offer,
							plan = newPlan(L.bundleW, "Wide", planExtra),
							x = pad,
							y = y,
						})
						y += height + L.passGap
					end
				end
				panelH = y - L.passGap + pad
			end
		end
		local panel = ShopKit.panel(frame, {
			name = "PassesPanel",
			position = UDim2.fromOffset(0, top),
			size = UDim2.fromOffset(L.contentW, panelH),
			z = 8,
		})
		for _, placement in placements do
			local view = ShopCards.offer(env, panel, placement.offer, placement.plan)
			view.root.Position = UDim2.fromOffset(placement.x, placement.y)
		end
		return top + panelH
	end

	local function buildGridSection(frame: Frame, section: Catalog.Section, L: ShopLayout.Layout): number
		sectionHeader(frame, section, L, 0)
		return placeGrid(frame, section.offers, L.sectionHeaderH + 6, L)
	end

	local function buildFree(frame: Frame, section: Catalog.Section, L: ShopLayout.Layout): number
		sectionHeader(frame, section, L, 0)
		local offer = Catalog.get("free-legion")
		local top = L.sectionHeaderH + 6
		if not offer then
			return top
		end
		local plan = newPlan(L.contentW, "Wide", { buttonRight = true })
		local height = math.max(ShopCards.measure(env, offer, plan), L.freeH)
		plan.h = height
		local view = ShopCards.offer(env, frame, offer, plan)
		view.root.Position = UDim2.fromOffset(0, top)
		return top + height
	end

	-- The coming soon card: hidden until a press finishes "Checking...". Built with the page so it follows the layout.
	local function buildSoon(shell: Frame, L: ShopLayout.Layout)
		local root: Frame = make("Frame", {
			Name = "ComingSoon",
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Visible = false,
			ZIndex = 60,
			Parent = shell,
		})
		local scrim: TextButton = make("TextButton", {
			Name = "Scrim",
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = A.Ink,
			BackgroundTransparency = 0.45,
			AutoButtonColor = false,
			Text = "",
			Selectable = false,
			ZIndex = 60,
			Parent = root,
		})
		buildTrove:Connect(scrim.Activated, function()
			closeSoon()
		end)
		local phone = L.tier == "Phone"
		local w = math.min(L.size.X - 40, if phone then 520 else 460)
		local artPx = if phone then 84 else 120
		local h = if phone then math.min(L.size.Y - 16, 280) else 360
		local card = ShopKit.card(root, {
			name = "SoonCard",
			size = Vector2.new(w, h),
			fill = "Violet",
			z = 61,
			trove = buildTrove,
			pattern = true,
			interactive = false,
		})
		card.root.AnchorPoint = Vector2.new(0.5, 0.5)
		card.root.Position = UDim2.fromScale(0.5, 0.5)
		local pop: UIScale = make("UIScale", { Name = "SoonPop", Parent = card.root })
		local column: Frame = make("Frame", {
			Name = "Column",
			Size = UDim2.new(1, -24, 1, -24),
			Position = UDim2.fromOffset(12, 10),
			BackgroundTransparency = 1,
			ZIndex = 66,
			Parent = card.content,
		})
		make("UIListLayout", {
			Padding = UDim.new(0, 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Parent = column,
		})
		local headline = ShopKit.label(
			column,
			"Coming soon!",
			if phone then 34 else 44,
			{ name = "Headline", z = 66, xAlign = Enum.TextXAlignment.Center }
		)
		headline.Size = UDim2.new(1, 0, 0, if phone then 44 else 54)
		headline.LayoutOrder = 1
		local artHolder: Frame = make("Frame", {
			Name = "Art",
			Size = UDim2.fromOffset(artPx, artPx),
			BackgroundTransparency = 1,
			LayoutOrder = 2,
			ZIndex = 66,
			Parent = column,
		})
		local name = ShopKit.label(column, "", 24, { name = "ItemName", z = 66, xAlign = Enum.TextXAlignment.Center })
		name.Size = UDim2.new(1, 0, 0, 30)
		name.LayoutOrder = 3
		local message = ShopKit.paragraph(column, "This will be ready in the real game", 18, {
			name = "Message",
			z = 66,
			xAlign = Enum.TextXAlignment.Center,
		})
		message.LayoutOrder = 4
		local button = ShopKit.priceButton(column, {
			name = "Back",
			label = "Back to Shop",
			size = Vector2.new(math.min(w - 60, 240), 52),
			z = 67,
			trove = buildTrove,
			onActivate = function()
				closeSoon()
			end,
		})
		button.root.LayoutOrder = 5
		soon = {
			root = root,
			card = card,
			artHolder = artHolder,
			artPx = artPx,
			name = name,
			button = button,
			pop = pop,
		}
	end

	buildAll = function(preserveScroll: boolean)
		-- remember where the player is: the section that was active and how far below its top they had scrolled
		local anchorId = activeSection
		local anchorDelta = 0
		local oldPage = page
		if oldPage then
			anchorDelta = oldPage.CanvasPosition.Y - (sectionY[anchorId] or 0)
		end
		buildTrove:Clean()
		table.clear(views)
		table.clear(tabs)
		table.clear(sectionY)
		table.clear(stylePick)
		table.clear(sectionOrder)
		hero = nil
		page = nil
		cue = nil
		tip = nil
		tabScroll = nil
		cashCount = nil
		collectionSet = nil
		soon = nil
		closeBody = nil
		counters.builds += 1
		overlay:applyScale()

		local ds = overlay:designSize()
		local sections = Catalog.sections(fixtures.cash)
		local tier0 = ShopLayout.tierFor(ds)
		local closeSize0 = ShopLayout.closeSizeFor(tier0)
		local titleSize0 = ShopLayout.titleSizeFor(tier0)
		local titleW = math.ceil(ShopKit.textWidth("SHOP", titleSize0)) + 24
		local tabsW = 0
		for _, section in sections do
			tabsW += ShopKit.tabWidth(section.title, S.Layout.TabHeight) + 4
		end
		local numSize = if tier0 == "Desktop" then 28 else 24
		local numW = math.clamp(math.ceil(ShopKit.textWidth(Format.cash(cashValue()), numSize)) + 12, 84, 170)
		local plusSize = math.max(closeSize0 - 8, Tokens.Touch.Minimum)
		local cashIconPx = closeSize0 - 14
		local cashW = 12 + cashIconPx + 6 + numW + 6 + plusSize + 8
		local L = ShopLayout.compute({ size = ds, titleW = titleW, tabsW = tabsW + 16, cashW = cashW })
		layoutInfo = L
		env.tier = L.tier

		local shell: Frame = buildTrove:Add(make("Frame", {
			Name = "Shop",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			ZIndex = 3,
			Parent = overlay.content,
		}))
		popScale = make("UIScale", { Name = "ShopPop", Parent = shell })

		-- PAGE ---------------------------------------------------------------------------------------------------
		local pageFrame: ScrollingFrame = make("ScrollingFrame", {
			Name = "Page",
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(L.pageX, L.pageY),
			Size = UDim2.fromOffset(L.pageW, L.pageH),
			CanvasSize = UDim2.fromOffset(0, L.pageH),
			AutomaticCanvasSize = Enum.AutomaticSize.None,
			ScrollingDirection = Enum.ScrollingDirection.Y,
			ScrollBarThickness = 8,
			ScrollBarImageColor3 = WHITE,
			ScrollBarImageTransparency = 0.25,
			VerticalScrollBarInset = Enum.ScrollBarInset.None,
			ClipsDescendants = true,
			Selectable = false,
			ZIndex = 6,
			Parent = shell,
		})
		page = pageFrame
		local y = 6
		for _, section in sections do
			table.insert(sectionOrder, section.id)
			sectionY[section.id] = if section.id == "featured" then 0 else y
			local frame: Frame = make("Frame", {
				Name = "Section_" .. section.id,
				Position = UDim2.fromOffset(0, y),
				Size = UDim2.fromOffset(L.contentW, 10),
				BackgroundTransparency = 1,
				ZIndex = 7,
				Parent = pageFrame,
			})
			local height: number
			if section.id == "featured" then
				height = buildFeatured(frame, L)
			elseif section.id == "passes" then
				height = buildPasses(frame, section, L)
			elseif section.id == "free" then
				height = buildFree(frame, section, L)
			else
				height = buildGridSection(frame, section, L)
			end
			frame.Size = UDim2.fromOffset(L.contentW, height)
			y += height + L.sectionGap
		end
		-- the honest footer: a harness caption (hidden in the player-facing view), never a sales line
		footerText = "Preview shop: every price is a proposal and nothing can be bought in this build."
		local footer = ShopKit.paragraph(pageFrame, footerText, 16, {
			name = "PreviewNote",
			colour = S.Color.Grey,
			xAlign = Enum.TextXAlignment.Center,
			z = 8,
		})
		footer.Position = UDim2.fromOffset(0, y)
		footer.Size = UDim2.fromOffset(L.contentW, 40)
		footer:SetAttribute("PreviewCaption", true)
		y += L.footerH
		pageFrame.CanvasSize = UDim2.fromOffset(0, y)
		scrollMax = math.max(y - L.pageH, 0)
		buildTrove:Connect(pageFrame:GetPropertyChangedSignal("CanvasPosition"), onScroll)

		-- the scroll cue: a calm chip while there is more below (never cutting a primary button in half)
		local scrollCue =
			ShopKit.chip(shell, { text = "Scroll for more", fill = "Steel", size = 16, z = 12, name = "ScrollCue" })
		scrollCue.AnchorPoint = Vector2.new(0.5, 1)
		scrollCue.Position = UDim2.new(0.5, 0, 0, L.pageY + L.pageH - 6)
		cue = scrollCue

		-- HEADER -------------------------------------------------------------------------------------------------
		local z = 20
		local header: Frame = make("Frame", {
			Name = "Header",
			Size = UDim2.new(1, 0, 0, L.headerH),
			BackgroundTransparency = 1,
			ZIndex = z,
			Parent = shell,
		})
		local rowCentre = L.topPad + L.rowH / 2
		local title = ShopKit.label(header, "SHOP", L.titleSize, {
			name = "Title",
			outline = if L.tier == "Desktop" then 6 else 4,
			z = z + 1,
		})
		title.AnchorPoint = Vector2.new(0, 0.5)
		title.Position = UDim2.fromOffset(L.margin, rowCentre)
		title.Size = UDim2.fromOffset(titleW, L.titleSize + 14)

		local closeButton = ShopKit.squareButton(header, {
			name = "Close",
			size = L.closeSize,
			fill = "Red",
			icon = "Close",
			z = z + 1,
			trove = buildTrove,
			sound = "Close",
			onActivate = function()
				shop:close()
			end,
		})
		closeButton.root.AnchorPoint = Vector2.new(1, 0.5)
		closeButton.root.Position = UDim2.fromOffset(L.margin + L.contentW, rowCentre)
		closeBody = closeButton.body

		local cashBox: Frame = make("Frame", {
			Name = "Cash",
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.fromOffset(L.margin + L.contentW - L.closeSize - L.gap, rowCentre),
			Size = UDim2.fromOffset(cashW, L.closeSize),
			BackgroundColor3 = WHITE,
			BorderSizePixel = 0,
			ZIndex = z + 1,
			Parent = header,
		})
		Arcade.corner(cashBox, L.closeSize)
		Arcade.outline(cashBox, "Button")
		make("UIGradient", { Color = S.Fill.Well, Rotation = 90, Parent = cashBox })
		local cashIcon: Frame = make("Frame", {
			Name = "Icon",
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 10, 0.5, 0),
			Size = UDim2.fromOffset(cashIconPx, cashIconPx),
			BackgroundTransparency = 1,
			ZIndex = z + 2,
			Parent = cashBox,
		})
		ShopKit.icon(cashIcon, if fixtures.missingArt then "__missing__" else "CashStack")
		local numLabel = ShopKit.label(cashBox, "", numSize, {
			name = "Amount",
			italic = true,
			face = "Cash",
			z = z + 2,
		})
		numLabel.AnchorPoint = Vector2.new(0, 0.5)
		numLabel.Position = UDim2.new(0, 12 + cashIconPx + 6, 0.5, 0)
		numLabel.Size = UDim2.fromOffset(numW, numSize + 8)
		local counter = ShopKit.countUp(numLabel, { format = Format.cash, startValue = cashValue() })
		cashCount = counter
		buildTrove:Add(function()
			counter.destroy()
		end)
		local plus = ShopKit.squareButton(cashBox, {
			name = "Plus",
			size = plusSize,
			fill = "Green",
			icon = "Plus",
			z = z + 2,
			trove = buildTrove,
			onActivate = function()
				if fixtures.cash then
					scrollTo("cash", true)
					return
				end
				-- Cash is off: open Featured with a small honest explanation, not an empty section (M10-03a)
				scrollTo("featured", true)
				local bubble = tip
				if bubble then
					bubble.Visible = true
					local previous = tipThread
					if previous then
						pcall(task.cancel, previous)
					end
					tipThread = task.delay(3.2, function()
						bubble.Visible = false
					end)
				end
			end,
		})
		plus.root.AnchorPoint = Vector2.new(1, 0.5)
		plus.root.Position = UDim2.new(1, -6, 0.5, 0)

		local bubble: Frame = make("Frame", {
			Name = "CashTip",
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.fromOffset(L.margin + L.contentW - L.closeSize - L.gap, L.topPad + L.rowH + 4),
			Size = UDim2.fromOffset(math.min(300, L.contentW - 20), 30),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundColor3 = WHITE,
			BorderSizePixel = 0,
			Visible = false,
			ZIndex = z + 10,
			Parent = header,
		})
		Arcade.corner(bubble, 10)
		Arcade.outline(bubble, "Button")
		make("UIGradient", { Color = S.Fill.Well, Rotation = 90, Parent = bubble })
		make("UIPadding", {
			PaddingLeft = UDim.new(0, 8),
			PaddingRight = UDim.new(0, 8),
			PaddingTop = UDim.new(0, 6),
			PaddingBottom = UDim.new(0, 6),
			Parent = bubble,
		})
		ShopKit.paragraph(
			bubble,
			"Cash packs are not available yet. Drive to earn Cash!",
			16,
			{ name = "Text", z = z + 11 }
		)
		tip = bubble

		-- the pill tab bar: centred on the first row when it fits, its own scrollable row otherwise
		local barW, barX, barY
		if L.tabsInline then
			barW = tabsW + 16
			local freeLeft = L.margin + titleW + L.gap
			local freeRight = L.margin + L.contentW - L.closeSize - L.gap - cashW - L.gap
			barX = freeLeft + math.max(math.floor((freeRight - freeLeft - barW) / 2), 0)
			barY = rowCentre - (L.tabH + 10) / 2
		else
			barW = L.contentW
			barX = L.margin
			barY = L.topPad + L.rowH + L.tabGap
		end
		local bar: Frame = make("Frame", {
			Name = "TabBar",
			Position = UDim2.fromOffset(barX, barY),
			Size = UDim2.fromOffset(barW, L.tabH + 10),
			BackgroundColor3 = WHITE,
			BorderSizePixel = 0,
			ZIndex = z + 1,
			Parent = header,
		})
		Arcade.corner(bar, L.tabH + 10)
		Arcade.outline(bar, "Button")
		make("UIGradient", { Color = S.Fill.Well, Rotation = 90, Parent = bar })
		local scroller: ScrollingFrame = make("ScrollingFrame", {
			Name = "Tabs",
			Position = UDim2.fromOffset(6, 0),
			Size = UDim2.new(1, -12, 1, 0),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			CanvasSize = UDim2.fromOffset(tabsW + 4, 0),
			AutomaticCanvasSize = Enum.AutomaticSize.None,
			ScrollingDirection = Enum.ScrollingDirection.X,
			ScrollBarThickness = 0,
			ClipsDescendants = true,
			Selectable = false,
			ZIndex = z + 2,
			Parent = bar,
		})
		tabScroll = scroller
		make("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, 4),
			SortOrder = Enum.SortOrder.LayoutOrder,
			Parent = scroller,
		})
		for order, section in sections do
			local tab = ShopKit.tab(scroller, {
				name = "Tab_" .. section.id,
				label = section.title,
				icon = if fixtures.missingArt then "__missing__" else section.icon,
				z = z + 3,
				trove = buildTrove,
				height = L.tabH,
				onActivate = function()
					scrollTo(section.id, true)
				end,
			})
			tab.root.LayoutOrder = order
			tabs[section.id] = tab
		end

		buildSoon(shell, L)
		refreshViews()
		setViewLoops(shopOpen and visible)
		if preserveScroll then
			local target = if sectionY[anchorId] ~= nil then anchorId else (sectionOrder[1] or "featured")
			local goal = math.clamp((sectionY[target] or 0) + anchorDelta, 0, scrollMax)
			programmaticUntil = os.clock() + 0.1
			pageFrame.CanvasPosition = Vector2.new(0, goal)
			activeSection = target
		end
		setActiveTab(if sectionY[activeSection] ~= nil then activeSection else (sectionOrder[1] or "featured"))
		onScroll()
		if soonOpen then
			soonOpen = false -- a relayout while the card was up: it simply closes (the press already ended)
		end
	end

	-- LOOPS ------------------------------------------------------------------------------------------------------

	local function addBlur()
		if opts.blur == false or blur ~= nil then
			return
		end
		local effect = Instance.new("BlurEffect")
		effect.Name = "ShopBlur"
		effect.Size = 0
		effect.Parent = workspace.CurrentCamera or game:GetService("Lighting")
		blur = effect
		if Motion.reduced() then
			effect.Size = M.Blur
		else
			Motion.tween(effect, "blur", Motion.info(M.OpenSeconds), { Size = M.Blur })
		end
	end
	local function removeBlur()
		local effect = blur
		blur = nil
		if not effect then
			return
		end
		Debris:AddItem(effect, 1) -- never leaves a stray blur behind, whatever happens to the tween
		if Motion.reduced() then
			effect:Destroy()
		else
			local tween = Motion.tween(effect, "blur", Motion.info(M.CloseSeconds), { Size = 0 })
			tween.Completed:Once(function()
				effect:Destroy()
			end)
		end
	end
	trove:Add(function()
		local effect = blur
		blur = nil
		if effect then
			effect:Destroy()
		end
	end)

	local function heroInView(): boolean
		local h, p = hero, page
		if not h or not p then
			return false
		end
		local top = h.root.AbsolutePosition.Y
		local bottom = top + h.root.AbsoluteSize.Y
		return bottom > p.AbsolutePosition.Y + 8 and top < p.AbsolutePosition.Y + p.AbsoluteSize.Y - 8
	end

	startLoops = function()
		openTrove:Clean()
		if destroyed or not shopOpen or not visible then
			return
		end
		addBlur()
		setViewLoops(true)
		-- the ONE scheduler: carousel, shine, sparkles and the idle bounce, each finite, all paused when nothing is on screen
		local rng = Random.new(os.clock() * 1000)
		schedulerThread = task.spawn(function()
			local now0 = os.clock()
			local nextShine = now0 + 3
			local nextBounce = now0 + 2
			local nextAdvance = now0 + M.CarouselSeconds
			local pausedUntil = now0
			while true do
				task.wait(0.25)
				counters.ticks += 1
				local h = hero
				if not shopOpen or not visible or soonOpen or not h or Motion.reduced() then
					continue
				end
				local now = os.clock()
				if h.isEngaged() or pendingId ~= nil then
					pausedUntil = now + M.CarouselPause
				end
				local inView = heroInView()
				if
					opts.autoAdvance ~= false
					and inView
					and h.count() > 1
					and now >= pausedUntil
					and now >= nextAdvance
				then
					h.advance()
					counters.advances += 1
					nextAdvance = now + M.CarouselSeconds
				end
				if inView and now >= nextShine then
					nextShine = now + rng:NextNumber(M.ShineEveryMin, M.ShineEveryMax)
					if h.shine.play() then
						counters.shines += 1
						if h.sparkles.burst() then
							counters.bursts += 1
						end
					end
				end
				if inView and now >= nextBounce then
					nextBounce = now + M.BounceEvery
					local button = h.button()
					if button then
						button.bounce()
						counters.bounces += 1
					end
				end
			end
		end)
		openTrove:Add(schedulerThread :: thread)
		openTrove:Add(Motion.onReducedChanged(function()
			if shopOpen then
				refreshViews()
			end
		end))
		openTrove:Add(ctx.store:subscribe("cash", function(value: any)
			local counter = cashCount
			if counter and fixtures.cashValue == nil and type(value) == "number" then
				counter.set(value, true)
			end
		end))
		openTrove:Connect(adapter.Changed, function()
			if shopOpen then
				refreshViews()
			end
		end)
		-- gamepad: a focused card scrolls into view
		openTrove:Connect(GuiService:GetPropertyChangedSignal("SelectedObject"), function()
			local p = page
			local selected = GuiService.SelectedObject
			if not p or not selected or not selected:IsDescendantOf(p) or not selected:IsA("GuiObject") then
				return
			end
			local gui = selected :: GuiObject
			local relTop = gui.AbsolutePosition.Y - p.AbsolutePosition.Y + p.CanvasPosition.Y
			local relBottom = relTop + gui.AbsoluteSize.Y
			local y = p.CanvasPosition.Y
			local viewH = p.AbsoluteSize.Y
			if relTop < y + 4 then
				y = relTop - 12
			elseif relBottom > y + viewH - 4 then
				y = relBottom - viewH + 12
			end
			programmaticUntil = os.clock() + 0.2
			p.CanvasPosition = Vector2.new(0, math.clamp(y, 0, scrollMax))
		end)
	end

	stopLoops = function()
		openTrove:Clean()
		schedulerThread = nil
		setViewLoops(false)
		removeBlur()
	end

	-- COMING SOON ----------------------------------------------------------------------------------------------------

	showComingSoon = function(offerId: string)
		local s = soon
		local offer = Catalog.get(offerId)
		if not s or not offer then
			return
		end
		for _, child in s.artHolder:GetChildren() do
			child:Destroy()
		end
		ShopArt.build(s.artHolder, offer.art, s.artPx, { z = 66, missing = fixtures.missingArt })
		s.name.Text = offer.name
		s.root.Visible = true
		soonOpen = true
		ShopKit.noteSoundDependency("ShopComingSoon")
		Sounds.play("Toast")
		Motion.cancelAll(s.pop)
		if Motion.reduced() then
			s.pop.Scale = 1
		else
			s.pop.Scale = 0.9
			Motion.tween(
				s.pop,
				"pop",
				Motion.info(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
				{ Scale = 1 }
			)
		end
		if lastInputIsGamepad() then
			GuiService.SelectedObject = s.button.body
		end
	end

	closeSoon = function()
		local s = soon
		if not s or not soonOpen then
			return
		end
		soonOpen = false
		Motion.cancelAll(s.pop)
		s.root.Visible = false
		local source = lastSource
		if source and source:IsDescendantOf(game) and lastInputIsGamepad() then
			GuiService.SelectedObject = source
		elseif GuiService.SelectedObject and GuiService.SelectedObject:IsDescendantOf(s.root) then
			GuiService.SelectedObject = nil
		end
	end

	-- OPEN, CLOSE -----------------------------------------------------------------------------------------------------

	local function popIn()
		local scale = popScale
		if not scale then
			return
		end
		Motion.cancelAll(scale)
		if Motion.reduced() then
			scale.Scale = 1
		else
			scale.Scale = M.OpenFrom
			Motion.tween(
				scale,
				"pop",
				Motion.info(M.OpenSeconds, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
				{ Scale = 1 }
			)
		end
	end

	-- Brings an offer to the player's eye (the parking-full entry): a steady ring for a moment, and gamepad focus.
	local function focusOffer(offerId: string)
		local list = views[offerId]
		local view = list and list[#list]
		if not view then
			return
		end
		local target: GuiObject = view.root
		local ring = ShopKit.pulseRing(target, { padding = 4, radius = 16, z = 40, trove = openTrove })
		ring.setActive(true)
		openTrove:Add(task.delay(2.6, function()
			ring.destroy()
		end))
		local focus = if view.button then view.button.body else view.hit
		if focus and lastInputIsGamepad() then
			GuiService.SelectedObject = focus
		end
	end

	local function openShop(returnTo: GuiObject?, sectionId: string?, offerId: string?)
		if destroyed or overlay:isOpen() then
			return
		end
		shopOpen = true
		openToken += 1
		pendingId = nil
		soonOpen = false
		buildAll(false)
		overlay:open(closeBody, returnTo)
		overlay.root.Visible = visible
		startLoops()
		popIn()
		local p = page
		if sectionId and sectionY[sectionId] ~= nil then
			scrollTo(sectionId, false)
		elseif p then
			p.CanvasPosition = Vector2.zero
			setActiveTab(sectionOrder[1] or "featured")
		end
		if offerId then
			focusOffer(offerId)
		end
	end

	local function closeShop()
		if not shopOpen or not overlay:isOpen() then
			return
		end
		-- close during "Checking..." cancels the request here, and nothing it answers later can reopen anything
		openToken += 1
		local handle = pendingHandle
		pendingHandle = nil
		pendingId = nil
		if handle then
			handle:cancel()
		end
		adapter:cancelAll()
		soonOpen = false
		shopOpen = false
		local scale = popScale
		if scale then
			Motion.cancelAll(scale)
			if not Motion.reduced() then
				Motion.tween(
					scale,
					"pop",
					Motion.info(M.CloseSeconds, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
					{
						Scale = 0.96,
					}
				)
			end
		end
		stopLoops()
		overlay:close()
		refreshViews() -- a reopened shop shows idle buttons, never a stale "Checking..."
		if opts.onClose then
			opts.onClose()
		end
	end

	overlay:setBack(function()
		if soonOpen then
			closeSoon()
		else
			closeShop()
		end
	end)

	requestRelayout = function()
		if not shopOpen or relayoutQueued then
			return
		end
		relayoutQueued = true
		task.defer(function()
			relayoutQueued = false
			if destroyed or not shopOpen then
				return
			end
			buildAll(true)
		end)
	end
	trove:Connect(ctx.screen.Changed, function()
		requestRelayout()
	end)
	trove:Connect(overlay.root:GetPropertyChangedSignal("AbsoluteSize"), function()
		requestRelayout()
	end)

	-- FIXTURES -----------------------------------------------------------------------------------------------------

	local function eachId(value: any, fn: (id: string) -> ())
		if type(value) == "string" then
			fn(value)
		elseif type(value) == "table" then
			for _, id in value do
				if type(id) == "string" then
					fn(id)
				end
			end
		end
	end

	local function afterFixture(rebuild: boolean)
		if shopOpen then
			if rebuild then
				buildAll(true)
			else
				refreshViews()
			end
		end
	end

	local function clearStates(id: string)
		adapter:setOwned(id, false)
		adapter:setUnavailable(id, false)
		adapter:setError(id, false)
		fixtures.forcedPending[id] = nil
	end

	shop = {
		root = overlay.root,
		layout = function(_self: Shop)
			if shopOpen then
				buildAll(true)
			end
		end,
		setVisible = function(_self: Shop, on: boolean)
			visible = on
			overlay.root.Visible = on and overlay:isOpen()
			if on and shopOpen then
				startLoops()
			elseif not on then
				stopLoops()
			end
		end,
		open = function(_self: Shop, returnTo: GuiObject?)
			openShop(returnTo, nil, nil)
		end,
		openAt = function(_self: Shop, sectionId: string?, offerId: string?, returnTo: GuiObject?)
			openShop(returnTo, sectionId, offerId)
		end,
		close = function(_self: Shop)
			closeShop()
		end,
		isOpen = function(_self: Shop): boolean
			return overlay:isOpen()
		end,
		scrollTo = function(_self: Shop, sectionId: string, animate: boolean?)
			scrollTo(sectionId, animate)
		end,
		setFixture = function(_self: Shop, name: string, value: any, on: boolean?)
			local flag = if on == nil then true else on
			if name == "owned" or name == "unavailable" or name == "error" then
				eachId(value, function(id: string)
					if name == "owned" then
						adapter:setOwned(id, flag)
					elseif name == "unavailable" then
						adapter:setUnavailable(id, flag)
					else
						adapter:setError(id, flag)
					end
				end)
				afterFixture(name == "owned" and (value == "starter-pack" or value == "*"))
			elseif name == "pending" then
				eachId(value, function(id: string)
					fixtures.forcedPending[id] = if flag then true else nil
				end)
				afterFixture(false)
			elseif name == "hold" then
				adapter:holdPending(value == true)
			elseif name == "cash" then
				fixtures.cash = value == true
				afterFixture(true)
			elseif name == "previewValue" then
				fixtures.previewValue = value == true
				afterFixture(true)
			elseif name == "longText" then
				fixtures.longText = value == true
				afterFixture(true)
			elseif name == "missingArt" then
				fixtures.missingArt = value == true
				afterFixture(true)
			elseif name == "cashAmountsPending" then
				fixtures.cashAmountsPending = value == true
				afterFixture(true)
			elseif name == "cashValue" then
				fixtures.cashValue = if type(value) == "number" then value else nil
				local counter = cashCount
				if counter then
					counter.set(cashValue(), true)
				end
			else
				warn("[ShopMock] unknown fixture: " .. tostring(name))
			end
		end,
		forceState = function(_self: Shop, offerId: string, state: string?)
			clearStates(offerId)
			if state == "owned" then
				adapter:setOwned(offerId, true)
			elseif state == "unavailable" then
				adapter:setUnavailable(offerId, true)
			elseif state == "error" then
				adapter:setError(offerId, true)
			elseif state == "pending" then
				fixtures.forcedPending[offerId] = true
			end
			afterFixture(offerId == "starter-pack")
		end,
		resetFixtures = function(_self: Shop)
			adapter:clearFixtures()
			table.clear(fixtures.forcedPending)
			fixtures.cash = opts.cash == true
			fixtures.previewValue = opts.previewValue == true
			fixtures.longText = false
			fixtures.missingArt = false
			fixtures.cashAmountsPending = false
			fixtures.cashValue = nil
			afterFixture(true)
		end,
		pressOffer = function(_self: Shop, offerId: string)
			local list = views[offerId]
			local view = list and list[1]
			press(offerId, if view then view.hit else nil)
		end,
		setSlide = function(_self: Shop, index: number)
			local h = hero
			if h then
				h.setIndex(index)
			end
		end,
		getAdapter = function(_self: Shop): ShopPurchaseAdapter.Adapter
			return adapter
		end,
		destroy = function(_self: Shop)
			if destroyed then
				return
			end
			destroyed = true
			shopOpen = false
			local handle = pendingHandle
			if handle then
				handle:cancel()
			end
			local thread = tipThread
			if thread then
				pcall(task.cancel, thread)
			end
			overlay:destroy()
		end,
		getDebugState = function(_self: Shop): DebugState
			local prices: { string } = {}
			local buttons: { { [string]: any } } = {}
			for id, list in views do
				for index, view in list do
					local button = view.button
					if button then
						table.insert(
							buttons,
							{ id = id, view = index, state = button.getState(), label = button.getLabel() }
						)
						if button.getState() == "Idle" then
							table.insert(prices, button.getLabel())
						end
					end
				end
			end
			table.sort(buttons, function(a, b)
				if a.id ~= b.id then
					return a.id < b.id
				end
				return a.view < b.view
			end)
			local claims = { bestDeal = 0, save = 0, strike = 0, previewValue = 0, previewLine = 0 }
			local badges, hits, minHit, spinners = 0, 0, math.huge, 0
			for _, d in overlay.root:GetDescendants() do
				if not d:IsA("GuiObject") then
					continue
				end
				local shown = true
				local node: Instance? = d
				while node and node ~= overlay.root do
					if node:IsA("GuiObject") and not (node :: GuiObject).Visible then
						shown = false
						break
					end
					node = node.Parent
				end
				if not shown then
					continue
				end
				if d.Name == "Badge" then
					badges += 1
				elseif d.Name == "BestDealRibbon" then
					claims.bestDeal += 1
				elseif d.Name == "SaveChip" then
					claims.save += 1
				elseif d.Name == "StrikePrice" then
					claims.strike += 1
				elseif d.Name == "PreviewValueTag" then
					claims.previewValue += 1
				elseif d.Name == "PreviewLine" then
					claims.previewLine += 1
				elseif d.Name == "Spinner" then
					spinners += 1
				end
				if d:IsA("TextButton") and d.Name ~= "Scrim" and d.Name ~= "Dim" then
					local height = d.Size.Y.Offset
					if height > 0 then
						hits += 1
						minHit = math.min(minHit, height)
					end
				end
			end
			local p = page
			local h = hero
			local adapterStats = adapter:stats()
			local info = layoutInfo
			return {
				open = overlay:isOpen(),
				kind = overlay:kind(),
				passes = #Catalog.PassIds,
				prices = prices,
				labels = { footerText },
				badges = badges,
				instances = #overlay.root:GetDescendants(),
				tier = if info then info.tier else nil,
				designSize = { x = overlay:designSize().X, y = overlay:designSize().Y }, -- JSON-safe: the harness encodes every debug state
				sections = sectionOrder,
				section = activeSection,
				cashSection = fixtures.cash,
				previewValue = fixtures.previewValue,
				fixtures = {
					longText = fixtures.longText,
					missingArt = fixtures.missingArt,
					cashAmountsPending = fixtures.cashAmountsPending,
					cashValue = fixtures.cashValue,
				},
				slide = if h then h.index() else 0,
				slides = if h then h.count() else 0,
				scrollY = if p then p.CanvasPosition.Y else 0,
				scrollMax = scrollMax,
				pendingId = pendingId,
				comingSoon = soonOpen,
				adapter = adapterStats,
				claims = claims,
				buttons = buttons,
				hits = hits,
				minHit = if minHit == math.huge then 0 else minHit,
				loops = {
					scheduler = schedulerThread ~= nil and coroutine.status(schedulerThread) ~= "dead",
					ticks = counters.ticks,
					shines = counters.shines,
					sparkleBursts = counters.bursts,
					advances = counters.advances,
					bounces = counters.bounces,
					spinners = spinners,
					blur = blur ~= nil,
				},
				builds = counters.builds,
				reduced = Motion.reduced(),
				visible = visible,
			}
		end,
	}

	return shop
end

return ShopMock
