--!strict
-- GarageMock: a navigable Garage / Index mock drawn over gameplay (Lane 3 HUD prototype, PREVIEW only; no ownership,
-- purchase or save logic). HUD rebuild (2026-10-22, H-15): restyled into the arcade family (Style.luau + the kit): deep
-- panel, Garage-blue header band, kit tabs and buttons, white outlined text; no cream.
--
--   local garage = GarageMock.new(ctx, { onDrive = function(car) end, onClose = fn?, cars = list?, infoOf = fn?, acquired = map? })
--   garage:open(returnTo?)  garage:close()  garage:isOpen()
--   garage:selectTab("Downtown" | "Dusty" | "Summit")
--   garage:selectCar(id)    -- also opens the detail view on phones
--   garage:setSort("Rarest" | "LapPay" | "Newest" | nil)   garage:getSort()   -- nil = the collection order
--   garage:setSource(cars?, infoOf?, acquired?)   -- replace the listed collection (nil = the preview fixtures)
--   garage:setLoading(on)   -- the loading case for the current tab
--   garage:layout()  garage:setVisible(on)  garage:destroy()  garage:getDebugState()
--
-- Content (synthetic): Downtown lists Fixtures.Cars, the three Variant examples, the long-name and missing-asset cases;
-- Dusty Highway is the EMPTY case; Summit Pass is the LOADING case (it stays loading in this mock). The collection total
-- comes from store.garage ("3 / 12", synthetic). "Drive" only calls options.onDrive(car) for an owned car.
-- Back (Escape / gamepad B): closes the phone detail view first, then the Garage.
--
-- ROUND 3 (R3-GA): the large cards and the World tabs are the browsing system. No small copy of a card is drawn here.
-- * SORT (R3 sort controls): RAREST (Legendary, Epic, Rare, Uncommon, Common; then name A to Z, then id), LAP PAY
--   (the supplied per-lap number, highest first) and NEWEST (the supplied acquisition number, newest first). A car with
--   no supplied number is always last, in the collection order; ties keep the collection order. The sort works on a COPY:
--   the collection array and the catalog are never touched. The active sort is shown by text AND shape: its button turns
--   into the selected tab (fill and thick boundary), gets an underline and a check mark, and the row says
--   which order is active ("Rarest first", ... or "Collection order" when none is). Tap the active sort again to go back to the collection order.
--   On a short phone frame the three buttons become one button that steps through them. The sort is local preview state:
--   it is not saved, and it survives closing and reopening the Garage only while the screen stays built.
-- * Lap Pay and the acquisition number of a car the player does not own are unknown (nothing about an unowned car leaks,
--   not even through the sort order): LAP_SORT_HIDES_UNOWNED below.
-- * The detail is the six-fact panel (Screens/CardDetail.Facts): image, full name, full rarity word, World, Lap Pay, the
--   three finishes owned or not. No quirk words, no family, no Heat, no per-second figure, no how-to-get line.
-- * Finishes come from the collection itself: a finish is OWNED when the collection lists an owned car of that base id
--   with that finish, NOT OWNED otherwise (a car the player does not own owns no finish).

local Prototype = script.Parent.Parent
local Arcade = require(Prototype.Arcade)
local CarCard = require(Prototype.Cards.CarCard)
local CardGrid = require(Prototype.Cards.CardGrid)
local Fixtures = require(Prototype.Fixtures)
local Overlay = require(script.Parent.Overlay)
local CardDetail = require(script.Parent.CardDetail)
local PreviewTokens = require(Prototype.PreviewTokens)
local Style = require(script.Parent.Style)
local TradingCard = require(Prototype.Cards.TradingCard)

local make = Arcade.make
local Facts = CardDetail.Facts

local GarageMock = {}

-- TOKEN CANDIDATE: collection chip width in the header.
local CHIP_W = 124
-- TOKEN CANDIDATE: sort buttons (design px): the row height is the touch minimum; the width is clamped around the free room.
local SORT_H = 48
local SORT_MIN_W = 104
local SORT_MAX_W = 168
local SORT_GAP = 8
-- TOKEN CANDIDATE: the room the fixed DRIVE / BACK bar takes at the bottom of the detail (button 58 + gaps).
local BAR_H = 76
-- A car the player does not own has no Lap Pay and no acquisition number for the sort (see the header). One switch.
local LAP_SORT_HIDES_UNOWNED = true

export type CarRef = CarCard.CarRef
export type Tab = "Downtown" | "Dusty" | "Summit"
export type SortMode = CardGrid.SortMode

export type Options = {
	onDrive: ((CarRef) -> ())?,
	onClose: (() -> ())?,
	cars: { CarRef }?, -- the collection to list (default: the synthetic Downtown fixtures); read only, never sorted in place
	infoOf: ((CarRef) -> TradingCard.Info?)?, -- supplied per-car data: Lap Pay, World, finishes (default: the preview data)
	acquired: { [string]: number }?, -- supplied acquisition number per car id, larger = newer (for NEWEST)
}

export type SortButtonState = {
	id: string,
	active: boolean,
	checkVisible: boolean,
	underlineVisible: boolean,
	text: string,
	visible: boolean,
}

export type DebugState = {
	open: boolean,
	kind: string,
	tab: Tab,
	selectedId: string?,
	detailOpen: boolean,
	collection: string,
	driveEnabled: boolean,
	driveVisible: boolean,
	driveCalls: number,
	sort: string, -- "Rarest" | "LapPay" | "Newest" | "None"
	sortStatus: string,
	sortForm: string, -- "Row" (three buttons) | "Cycle" (one button, short phone frame)
	sortButtons: { SortButtonState },
	sortCycle: SortButtonState,
	order: { string }, -- the car ids in the order the cards are laid out
	sourceCount: number,
	grid: CardGrid.DebugState,
	detailCard: CarCard.DebugState?,
	facts: { [string]: any }?,
	detailGapToBar: number, -- the facts scroll area's bottom to the top of the fixed bar (never negative)
	detailScrolls: boolean, -- the facts content is taller than its scroll area
	instances: number,
}

export type Garage = {
	root: Frame,
	layout: (self: Garage) -> (),
	setVisible: (self: Garage, on: boolean) -> (),
	open: (self: Garage, returnTo: GuiObject?) -> (),
	close: (self: Garage) -> (),
	isOpen: (self: Garage) -> boolean,
	selectTab: (self: Garage, tab: Tab) -> (),
	selectCar: (self: Garage, id: string) -> (),
	setSort: (self: Garage, mode: SortMode?) -> (),
	getSort: (self: Garage) -> SortMode?,
	setSource: (
		self: Garage,
		cars: { CarRef }?,
		infoOf: ((CarRef) -> TradingCard.Info?)?,
		acquired: { [string]: number }?
	) -> (),
	setLoading: (self: Garage, on: boolean) -> (),
	destroy: (self: Garage) -> (),
	getDebugState: (self: Garage) -> DebugState,
}

local TABS: { { id: Tab, long: string, short: string } } = {
	{ id = "Downtown", long = "Downtown", short = "Downtown" },
	{ id = "Dusty", long = "Dusty Highway", short = "Dusty Hwy" },
	{ id = "Summit", long = "Summit Pass", short = "Summit" },
}

local SORTS: { { id: SortMode, label: string, status: string } } = {
	{ id = "Rarest", label = "RAREST", status = "Rarest first" },
	{ id = "LapPay", label = "LAP PAY", status = "Highest Lap Pay first" },
	{ id = "Newest", label = "NEWEST", status = "Newest first" },
}
local NO_SORT_STATUS = "Collection order"

-- SYNTHETIC preview acquisition numbers (larger = newer), for NEWEST in the playground. The real number is the player's own
-- collection data; NEWEST never reads the array position or an asset time. Cars without an entry have no date.
GarageMock.PreviewAcquired = table.freeze({
	fishbowl = 1,
	puglet = 2,
	waffle = 3,
	["puglet-gold"] = 4,
	["rev6-chrome"] = 6,
}) :: { [string]: number }

-- The Downtown list for the mock (synthetic; one Variant marked unseen for the NEW tag).
function GarageMock.downtownCars(): { CarRef }
	local list: { CarRef } = {}
	for _, c in Fixtures.Cars do
		table.insert(list, c)
	end
	local chrome = table.clone(Fixtures.Variants.Chrome)
	chrome.unseen = true
	table.insert(list, Fixtures.Variants.Gold)
	table.insert(list, chrome)
	table.insert(list, Fixtures.Variants.Rainbow)
	table.insert(list, Fixtures.LongName)
	table.insert(list, Fixtures.Missing)
	return list
end

-- "puglet-gold" -> "puglet" (the id convention the fixtures use for a finish of the same car)
local function baseOf(id: string): string
	return (string.gsub(id, "%-.*$", ""))
end

function GarageMock.new(ctx: Overlay.Ctx, options: Options?): Garage
	local opts: Options = options or {}
	local tab: Tab = "Downtown"
	local selected: CarRef? = nil
	local downtownSelection: CarRef? = nil -- what Downtown had selected before another World tab was opened
	local detailOpen = false
	local driveCalls = 0
	local driveEnabled = false
	local loadingOverride = false
	local source: { CarRef } = opts.cars or GarageMock.downtownCars()
	local customInfo = opts.infoOf
	local acquired: { [string]: number } = opts.acquired
		or (if opts.cars == nil then GarageMock.PreviewAcquired else {})
	local sortMode: SortMode? = nil
	local sortForm = "Row"
	local garage: Garage

	local overlay = Overlay.new(ctx, { name = "GarageMock" })
	local trove = overlay.trove
	local content = overlay.content

	local shell = Style.panel(content, { name = "Panel", z = 3 })
	local panel = shell.body

	-- header band: icon + GARAGE, the collection chip, CLOSE
	local header = Style.header(panel, { fill = "Garage", title = "GARAGE", icon = "Garage" })
	local countChip = Style.well(panel, "Collection", 12)
	countChip.Size = UDim2.fromOffset(CHIP_W, 40)
	local countIcon: Frame = make("Frame", {
		Name = "Icon",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 4, 0.5, 0),
		Size = UDim2.fromOffset(34, 34),
		BackgroundTransparency = 1,
		ZIndex = 13,
		Parent = countChip,
	})
	Arcade.icon(countIcon, "Car")
	local countText = Style.text(countChip, "0 / 0", "Value", {
		name = "Count",
		italic = true,
		face = "Cars",
		size = 26,
		xAlign = Enum.TextXAlignment.Center,
		z = 13,
	})
	countText.AnchorPoint = Vector2.new(0, 0.5)
	countText.Position = UDim2.new(0, 40, 0.5, 0)
	countText.Size = UDim2.new(1, -44, 0, 32)
	local closeButton = Overlay.closeButton(panel, function()
		garage:close()
	end)
	trove:Add(closeButton.trove)
	closeButton.root.AnchorPoint = Vector2.new(1, 0.5)
	closeButton.root.ZIndex = 12

	-- tabs
	type TabEntry = { id: Tab, tab: Style.Tab }
	local tabs: { TabEntry } = {}
	for i, def in TABS do
		local t = Style.tab(panel, {
			name = "Tab_" .. def.id,
			label = def.long,
			onActivate = function()
				garage:selectTab(def.id)
			end,
		})
		t.root.LayoutOrder = i
		trove:Add(t.trove)
		table.insert(tabs, { id = def.id, tab = t })
	end

	-- sort controls: a row of three buttons, or one button that steps through them (short phone frame)
	local sortRow: Frame = make("Frame", { Name = "SortRow", BackgroundTransparency = 1, ZIndex = 6, Parent = panel })
	local sortCaption = Arcade.text(sortRow, {
		text = "SORT",
		role = "Small",
		name = "Caption",
		colour = Style.TextSoft,
		xAlign = Enum.TextXAlignment.Left,
		z = 8,
	})
	local sortStatus = Arcade.text(sortRow, {
		text = NO_SORT_STATUS,
		role = "Small",
		name = "Status",
		colour = Style.TextSoft,
		xAlign = Enum.TextXAlignment.Left,
		z = 8,
	})

	-- the selected mark: a check at the corner and an underline under the word (text and shape, not colour alone)
	local function marks(t: Style.Tab): (Frame, Frame)
		local check: Frame = make("Frame", {
			Name = "Check",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(1, -12, 0, 4),
			Size = UDim2.fromOffset(22, 22),
			BackgroundTransparency = 1,
			Visible = false,
			ZIndex = 14,
			Parent = t.root,
		})
		Arcade.icon(check, "Check")
		local underline: Frame = make("Frame", {
			Name = "Underline",
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 35),
			Size = UDim2.new(0.6, 0, 0, 4),
			BackgroundColor3 = Color3.new(1, 1, 1),
			BorderSizePixel = 0,
			Visible = false,
			ZIndex = 13,
			Parent = t.root,
		})
		Arcade.corner(underline, 2)
		return check, underline
	end

	type SortEntry = { id: SortMode, label: string, tab: Style.Tab, check: Frame, underline: Frame }
	local sortButtons: { SortEntry } = {}
	for _, def in SORTS do
		local t = Style.tab(sortRow, {
			name = "Sort_" .. def.id,
			label = def.label,
			onActivate = function()
				garage:setSort(if sortMode == def.id then nil else def.id)
			end,
		})
		trove:Add(t.trove)
		local check, underline = marks(t)
		table.insert(sortButtons, { id = def.id, label = def.label, tab = t, check = check, underline = underline })
	end
	local cycleTab = Style.tab(panel, {
		name = "Sort_Cycle",
		label = "SORT",
		onActivate = function()
			-- none -> Rarest -> Lap Pay -> Newest -> none
			local nextIndex = 1
			for i, def in SORTS do
				if def.id == sortMode then
					nextIndex = i + 1
				end
			end
			garage:setSort(if nextIndex > #SORTS then nil else SORTS[nextIndex].id)
		end,
	})
	trove:Add(cycleTab.trove)
	local cycleCheck, cycleUnderline = marks(cycleTab)

	-- grid
	local gridHolder = Style.well(panel, "GridHolder", 4)
	gridHolder.ClipsDescendants = true
	local grid = CardGrid.new(gridHolder, {
		cell = Vector2.new(200, 280),
		onSelect = function(car: CarRef)
			garage:selectCar(car.id)
		end,
	})
	trove:Add(function()
		grid:destroy()
	end)

	-- detail: the six facts in a scrolling area that ends above the fixed DRIVE / BACK bar
	local detail = Style.well(panel, "Detail", 6)
	local detailEmpty =
		Overlay.text(detail, "Pick a car to see it here", 18, Style.TextSoft, Enum.TextXAlignment.Center, 7)
	local detailScroll = Style.scroll(detail, "FactsScroll", 7)
	make("UIPadding", {
		PaddingLeft = UDim.new(0, 4),
		PaddingRight = UDim.new(0, 8),
		PaddingTop = UDim.new(0, 6),
		PaddingBottom = UDim.new(0, 8),
		Parent = detailScroll,
	})
	local facts = Facts.new(detailScroll, "SixFacts")
	trove:Add(function()
		facts:destroy()
	end)

	local driveButton = Arcade.button(detail, {
		name = "Drive",
		label = "DRIVE",
		fill = "Green",
		size = "Custom",
		width = 180,
		height = 58,
		onActivate = function()
			if driveEnabled and selected and opts.onDrive then
				driveCalls += 1
				opts.onDrive(selected)
			end
		end,
	})
	trove:Add(driveButton.trove)
	driveButton.root.ZIndex = 12
	local backButton = Arcade.button(detail, {
		name = "Back",
		label = "BACK",
		fill = "Garage",
		size = "Custom",
		width = 116,
		height = 48,
		sound = "Close",
		onActivate = function()
			if detailOpen then
				detailOpen = false
				garage:layout()
			end
		end,
	})
	trove:Add(backButton.trove)
	backButton.root.ZIndex = 12

	---------------------------------------------------------------------------------------------
	-- data: the supplied per-car info, the finishes from the collection, the sort keys
	---------------------------------------------------------------------------------------------

	local function infoFor(car: CarRef): TradingCard.Info
		local info: TradingCard.Info
		if customInfo then
			info = customInfo(car) or {}
		else
			local base = baseOf(car.id)
			info = table.clone(Fixtures.cardInfo(base) or {}) :: TradingCard.Info
			-- a finish is owned when the collection lists an owned car of this base with that finish
			local flags = { Gold = false, Chrome = false, Rainbow = false } :: { [string]: boolean }
			for _, c in source do
				if baseOf(c.id) == base and c.owned == true and c.variant ~= "None" then
					flags[c.variant] = true
				end
			end
			info.variants = flags :: any
		end
		return info
	end

	local function lapPayOf(car: CarRef): number?
		if LAP_SORT_HIDES_UNOWNED and car.owned == false then
			return nil
		end
		return infoFor(car).lapPay
	end

	local function acquiredOf(car: CarRef): number?
		if LAP_SORT_HIDES_UNOWNED and car.owned == false then
			return nil
		end
		local number = acquired[car.id]
		if number ~= nil then
			return number
		end
		return infoFor(car).acquiredAt
	end

	local function displayed(): { CarRef }
		return CardGrid.sortCars(source, sortMode, { lapPay = lapPayOf, acquired = acquiredOf })
	end

	---------------------------------------------------------------------------------------------
	-- state to screen
	---------------------------------------------------------------------------------------------

	local function updateCollection()
		local g = ctx.store:get().garage
		-- an unknown total is shown as the owned count alone, never an invented total
		countText.Text = if g.total ~= nil
			then string.format("%d / %d", g.owned, g.total)
			else string.format("%d", g.owned)
	end
	trove:Add(ctx.store:subscribe("garage", function()
		updateCollection()
	end))
	updateCollection()

	local function applySortUI()
		local statusText = NO_SORT_STATUS
		local activeLabel = "SORT"
		for _, s in sortButtons do
			local on = s.id == sortMode
			s.tab.set(on)
			s.check.Visible = on
			s.underline.Visible = on
		end
		for _, def in SORTS do
			if def.id == sortMode then
				statusText = def.status
				activeLabel = def.label
			end
		end
		cycleTab.set(sortMode ~= nil)
		cycleTab.setText(activeLabel)
		cycleCheck.Visible = sortMode ~= nil
		cycleUnderline.Visible = sortMode ~= nil
		sortStatus.Text = statusText
	end

	local function updateDetail()
		local car = selected
		facts.root.Visible = car ~= nil
		detailScroll.Visible = car ~= nil
		detailEmpty.Visible = car == nil
		if not car then
			facts:setVisible(false)
			driveEnabled = false
			driveButton.root.Visible = false
			return
		end
		facts:setCar(car, infoFor(car))
		facts:setVisible(overlay:isOpen())
		driveButton.root.Visible = car.owned
		driveEnabled = car.owned and car.model ~= nil
		driveButton.setEnabled(driveEnabled)
	end

	local function setSelected(car: CarRef?)
		selected = car
		if tab == "Downtown" and car ~= nil then
			downtownSelection = car
		end
	end

	local function applyTab()
		for _, t in tabs do
			t.tab.set(t.id == tab)
		end
		if tab == "Downtown" and not loadingOverride then
			grid:setCars(displayed())
			local keep = selected or downtownSelection
			if keep and not table.find(source, keep) then
				keep = nil
			end
			if not keep then
				for _, c in source do
					if c.owned then
						keep = c
						break
					end
				end
			end
			setSelected(keep)
			grid:select(if keep then keep.id else nil)
		elseif tab == "Dusty" and not loadingOverride then
			grid:setEmptyText("No Dusty Highway cars yet. Open the Dusty Highway portal to start collecting!")
			grid:setCars({})
			selected = nil
		else
			grid:setLoading(true)
			selected = nil
		end
		detailOpen = false
		updateDetail()
	end

	---------------------------------------------------------------------------------------------
	-- layout
	---------------------------------------------------------------------------------------------

	local function placeSortRow(x: number, y: number, w: number)
		sortRow.Position = UDim2.fromOffset(x, y)
		sortRow.Size = UDim2.fromOffset(w, SORT_H)
		local captionW = if w >= 460 then 56 else 0
		local statusW = if w >= 700 then 220 else 0
		local free = w - captionW - statusW - SORT_GAP * 2 - (if statusW > 0 then SORT_GAP else 0)
		local bw = math.clamp(math.floor(free / 3), SORT_MIN_W, SORT_MAX_W)
		sortCaption.Visible = captionW > 0
		sortCaption.Position = UDim2.fromOffset(0, 0)
		sortCaption.Size = UDim2.fromOffset(math.max(captionW, 1), SORT_H)
		for i, s in sortButtons do
			s.tab.root.Position = UDim2.fromOffset(captionW + (i - 1) * (bw + SORT_GAP), 0)
			s.tab.root.Size = UDim2.fromOffset(bw, SORT_H)
		end
		sortStatus.Visible = statusW > 0
		local statusX = captionW + 3 * bw + 2 * SORT_GAP + SORT_GAP
		sortStatus.Position = UDim2.fromOffset(statusX, 0)
		sortStatus.Size = UDim2.fromOffset(math.max(w - statusX, 1), SORT_H)
	end

	-- the facts scroll area inside a detail well of `w` x `h` design px (the bar takes BAR_H at the bottom)
	local function layoutDetail(w: number, h: number)
		local scrollH = h - 8 - BAR_H
		detailScroll.Position = UDim2.fromOffset(4, 4)
		detailScroll.Size = UDim2.fromOffset(w - 8, math.max(scrollH, 40))
		local innerW = w - 8 - 8 - 4 - 8 -- the scroll frame, its bar and its padding
		local cardSize, compact = Facts.fit(innerW, scrollH - 14)
		facts:layout(innerW, cardSize, compact)
		detailEmpty.Position = UDim2.new(0, 0, 0.5, -12)
	end

	local function layoutNow()
		overlay:applyScale()
		local ds = overlay:designSize()
		local kind = Overlay.kindFor(ds)
		local pw, ph
		if kind == "Wide" then
			pw, ph = math.min(ds.X - 24, 1120), math.min(ds.Y - 20, 680)
		elseif kind == "Short" then
			pw, ph = ds.X - 24, ds.Y - 18
		else
			pw, ph = ds.X - 16, ds.Y - 18
		end
		shell.root.Size = UDim2.fromOffset(pw, ph)
		shell.root.Position = UDim2.new(0.5, 0, 0.5, -2)
		local short = kind == "Short"
		local tall = kind == "Tall"
		local headH = if short then Style.HeaderHeightShort else Style.HeaderHeight
		header.setHeight(headH)
		closeButton.root.Position = UDim2.new(1, -8, 0, headH / 2)
		-- the chip sits in the band on wide / short screens, under it on phone portrait
		local chipY = if tall then headH + 8 else math.floor((headH - 40) / 2)
		countChip.AnchorPoint = Vector2.new(1, 0)
		countChip.Position = UDim2.new(1, if tall then -10 else -(8 + Overlay.CloseWidth + 10), 0, chipY)
		local rightUsed = if tall then Overlay.CloseWidth + 16 else Overlay.CloseWidth + 18 + CHIP_W + 10
		local titleLeft = header.title.Position.X.Offset
		header.title.Size =
			UDim2.new(1, -titleLeft - rightUsed, 0, math.min(PreviewTokens.Arcade.Text.Display + 8, headH - 6))
		for _, t in tabs do
			local def = TABS[t.tab.root.LayoutOrder]
			t.tab.setText(if kind ~= "Wide" then def.short else def.long)
		end
		local tabsY = headH + 10 + (if tall then 48 else 0)
		local bodyX, bodyY, bodyW, bodyH
		local wide = kind == "Wide"
		local desktop = wide and pw >= 1000
		sortForm = if short then "Cycle" else "Row"
		sortRow.Visible = not short
		cycleTab.root.Visible = short
		if wide then
			for i, t in tabs do
				t.tab.root.Position = UDim2.fromOffset(14 + (i - 1) * 178, tabsY)
				t.tab.root.Size = UDim2.fromOffset(168, 48)
			end
			if desktop then
				-- beside the tabs
				local sortX = 14 + 3 * 178 + 8
				placeSortRow(sortX, tabsY, pw - sortX - 14)
				bodyX, bodyY = 12, tabsY + 48 + 10
			else
				-- a row of its own under the tabs
				placeSortRow(14, tabsY + 48 + 8, pw - 28)
				bodyX, bodyY = 12, tabsY + 48 + 8 + SORT_H + 10
			end
			bodyW, bodyH = pw - 24, ph - bodyY - 12
		elseif short then
			for i, t in tabs do
				t.tab.root.Position = UDim2.fromOffset(12, tabsY + (i - 1) * 56)
				t.tab.root.Size = UDim2.fromOffset(136, 48)
			end
			-- the one sort button sits under the tabs (a row would take 56 px from the cards)
			cycleTab.root.Position = UDim2.fromOffset(12, tabsY + 3 * 56)
			cycleTab.root.Size = UDim2.fromOffset(136, SORT_H)
			bodyX, bodyY = 156, headH + 10
			bodyW, bodyH = pw - 168, ph - bodyY - 10
		else
			local tw = math.floor((pw - 24 - 16) / 3)
			for i, t in tabs do
				t.tab.root.Position = UDim2.fromOffset(12 + (i - 1) * (tw + 8), tabsY)
				t.tab.root.Size = UDim2.fromOffset(tw, 48)
			end
			placeSortRow(12, tabsY + 48 + 8, pw - 24)
			bodyX, bodyY = 8, tabsY + 48 + 8 + SORT_H + 10
			bodyW, bodyH = pw - 16, ph - bodyY - 10
		end
		-- grid cell per layout (CarCard switches to its compact layout below 196 wide); widths
		-- leave room for the 8 px scroll bar so the column count never drops
		local cell = if wide
			then (if desktop then Vector2.new(200, 280) else Vector2.new(170, 238))
			elseif short then Vector2.new(140, 196)
			else Vector2.new(150, 210)
		grid:setCell(cell)
		if wide then
			local dw = if desktop then 360 else 330
			gridHolder.Visible = true
			gridHolder.Position = UDim2.fromOffset(bodyX, bodyY)
			gridHolder.Size = UDim2.fromOffset(bodyW - dw - 12, bodyH)
			detail.Visible = true
			detail.Position = UDim2.fromOffset(bodyX + bodyW - dw, bodyY)
			detail.Size = UDim2.fromOffset(dw, bodyH)
			backButton.root.Visible = false
			driveButton.root.AnchorPoint = Vector2.new(0.5, 1)
			driveButton.root.Position = UDim2.new(0.5, 0, 1, -12)
			layoutDetail(dw, bodyH)
		else
			gridHolder.Visible = not detailOpen
			gridHolder.Position = UDim2.fromOffset(bodyX, bodyY)
			gridHolder.Size = UDim2.fromOffset(bodyW, bodyH)
			detail.Visible = detailOpen
			detail.Position = UDim2.fromOffset(bodyX, bodyY)
			detail.Size = UDim2.fromOffset(bodyW, bodyH)
			backButton.root.Visible = true
			driveButton.root.AnchorPoint = Vector2.new(1, 1)
			driveButton.root.Position = UDim2.new(1, -14, 1, -10)
			backButton.root.AnchorPoint = Vector2.new(1, 1)
			backButton.root.Position = UDim2.new(1, -14 - 180 - 16, 1, -10)
			layoutDetail(bodyW, bodyH)
		end
		grid:refresh()
	end

	local function back()
		if detailOpen and overlay:kind() ~= "Wide" then
			detailOpen = false
			layoutNow()
			local body = grid:firstBody()
			overlay:focus(body)
		else
			garage:close()
		end
	end
	overlay:setBack(back)

	trove:Connect(ctx.screen.Changed, function()
		layoutNow()
	end)

	local function sortState(s: SortEntry): SortButtonState
		return {
			id = s.id,
			active = s.id == sortMode,
			checkVisible = s.check.Visible,
			underlineVisible = s.underline.Visible,
			text = s.tab.label.Text,
			visible = sortRow.Visible,
		}
	end

	garage = {
		root = overlay.root,
		layout = function(_self: Garage)
			layoutNow()
		end,
		setVisible = function(_self: Garage, on: boolean)
			overlay.root.Visible = on and overlay:isOpen()
			facts:setVisible(on and overlay:isOpen() and selected ~= nil)
			grid:refresh()
		end,
		open = function(_self: Garage, returnTo: GuiObject?)
			layoutNow()
			overlay:open(grid:firstBody() or tabs[1].tab.root, returnTo)
			facts:setVisible(selected ~= nil)
			facts:setSpinning(true)
			task.defer(function()
				grid:refresh()
			end)
		end,
		close = function(_self: Garage)
			if not overlay:isOpen() then
				return
			end
			detailOpen = false
			overlay:close()
			-- stop every turntable once the panel is hidden (the grid re-checks visibility)
			facts:setSpinning(false)
			task.delay(PreviewTokens.Motion.PanelOut + 0.05, function()
				grid:refresh()
			end)
			if opts.onClose then
				opts.onClose()
			end
		end,
		isOpen = function(_self: Garage): boolean
			return overlay:isOpen()
		end,
		selectTab = function(_self: Garage, t: Tab)
			if tab == "Downtown" and selected ~= nil then
				downtownSelection = selected
			end
			tab = t
			loadingOverride = false
			applyTab()
			layoutNow()
		end,
		selectCar = function(_self: Garage, id: string)
			for _, c in source do
				if c.id == id then
					setSelected(c)
				end
			end
			if selected and selected.id == id then
				grid:select(id)
				if overlay:kind() ~= "Wide" then
					detailOpen = true
				end
				updateDetail()
				layoutNow()
				overlay:focus(if driveEnabled then driveButton.body else backButton.body)
			end
		end,
		setSort = function(_self: Garage, mode: SortMode?)
			sortMode = mode
			applySortUI()
			-- the same cars in a new order: the selection, the World tab and an open detail stay as they are
			if tab == "Downtown" and not loadingOverride then
				grid:setCars(displayed())
				grid:select(if selected then selected.id else nil)
			end
		end,
		getSort = function(_self: Garage): SortMode?
			return sortMode
		end,
		setSource = function(
			_self: Garage,
			cars: { CarRef }?,
			infoOf: ((CarRef) -> TradingCard.Info?)?,
			newAcquired: { [string]: number }?
		)
			source = cars or GarageMock.downtownCars()
			customInfo = infoOf
			acquired = newAcquired or (if cars == nil then GarageMock.PreviewAcquired else {})
			applyTab()
			layoutNow()
		end,
		setLoading = function(_self: Garage, on: boolean)
			loadingOverride = on
			applyTab()
			layoutNow()
		end,
		destroy = function(_self: Garage)
			overlay:destroy()
		end,
		getDebugState = function(_self: Garage): DebugState
			local gridState = grid:getDebugState()
			local buttons: { SortButtonState } = {}
			for _, s in sortButtons do
				table.insert(buttons, sortState(s))
			end
			local factsState = facts:getDebugState()
			local scrollBottom = detailScroll.AbsolutePosition.Y + detailScroll.AbsoluteSize.Y
			local barTop = driveButton.root.AbsolutePosition.Y
			return {
				open = overlay:isOpen(),
				kind = overlay:kind(),
				tab = tab,
				selectedId = if selected then selected.id else nil,
				detailOpen = detailOpen,
				collection = countText.Text,
				driveEnabled = driveEnabled,
				driveVisible = driveButton.root.Visible,
				driveCalls = driveCalls,
				sort = if sortMode then sortMode else "None",
				sortStatus = sortStatus.Text,
				sortForm = sortForm,
				sortButtons = buttons,
				sortCycle = {
					id = "Cycle",
					active = sortMode ~= nil,
					checkVisible = cycleCheck.Visible,
					underlineVisible = cycleUnderline.Visible,
					text = cycleTab.label.Text,
					visible = cycleTab.root.Visible,
				},
				order = gridState.order,
				sourceCount = #source,
				grid = gridState,
				detailCard = if selected then factsState.card else nil,
				facts = if selected then factsState else nil,
				detailGapToBar = barTop - scrollBottom,
				detailScrolls = detailScroll.AbsoluteCanvasSize.Y > detailScroll.AbsoluteSize.Y + 0.5,
				instances = #overlay.root:GetDescendants(),
			}
		end,
	}

	applySortUI()
	applyTab()
	layoutNow()
	return garage
end

return GarageMock
