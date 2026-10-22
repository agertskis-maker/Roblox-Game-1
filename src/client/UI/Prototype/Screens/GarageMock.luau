--!strict
-- GarageMock: a navigable Garage / Index mock drawn over gameplay (Lane 3 HUD prototype,
-- PREVIEW only; no ownership, purchase or save logic). HUD rebuild (2026-10-22, H-15): restyled
-- into the arcade family (Style.luau + the kit): deep panel, Garage-blue header band, kit tabs
-- and buttons, white outlined text; no cream.
--
--   local garage = GarageMock.new(ctx, { onDrive = function(car) end, onClose = fn? })
--   garage:open(returnTo?)  garage:close()  garage:isOpen()
--   garage:selectTab("Downtown" | "Dusty" | "Summit")
--   garage:selectCar(id)    -- also opens the detail view on phones
--   garage:setLoading(on)   -- the loading case for the current tab
--   garage:layout()  garage:setVisible(on)  garage:destroy()  garage:getDebugState()
--
-- Content (synthetic): Downtown lists Fixtures.Cars, the three Variant examples, the long-name
-- and missing-asset cases; Dusty Highway is the EMPTY case; Summit Pass is the LOADING case
-- (it stays loading in this mock). The collection total comes from store.garage
-- ("3 / 12", synthetic). "Drive" only calls options.onDrive(car) for an owned car; an unowned
-- car shows how to get it instead of a greyed button.
-- Back (Escape / gamepad B): closes the phone detail view first, then the Garage.
-- Quirk sentences paraphrase outline v2.2 section 07 (delegated, tunable), not final copy.

local Prototype = script.Parent.Parent
local Arcade = require(Prototype.Arcade)
local CarCard = require(Prototype.Cards.CarCard)
local CardGrid = require(Prototype.Cards.CardGrid)
local Fixtures = require(Prototype.Fixtures)
local Overlay = require(script.Parent.Overlay)
local PreviewTokens = require(Prototype.PreviewTokens)
local Style = require(script.Parent.Style)

local make = Arcade.make

local GarageMock = {}

-- TOKEN CANDIDATE: collection chip width in the header.
local CHIP_W = 124

export type CarRef = CarCard.CarRef
export type Tab = "Downtown" | "Dusty" | "Summit"

export type Options = {
	onDrive: ((CarRef) -> ())?,
	onClose: (() -> ())?,
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
	howToGetVisible: boolean,
	driveCalls: number,
	grid: CardGrid.DebugState,
	detailCard: CarCard.DebugState?,
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
	setLoading: (self: Garage, on: boolean) -> (),
	destroy: (self: Garage) -> (),
	getDebugState: (self: Garage) -> DebugState,
}

GarageMock.QuirkText = {
	Nimble = "Quickest lane changes, and it shakes off oil slicks fast.",
	Steady = "Easy to drive and the easiest car to claim.",
	Rugged = "Potholes can't hurt this truck!",
	["Cool Runner"] = "Stays cool the longest: the car to rest in.",
	["Long Jump"] = "Hops much farther, even across gaps.",
	Slipstream = "Slim enough to ride between two cars.",
	Plow = "Smashes through construction barriers.",
	Magnet = "Pulls in road coins from nearby lanes.",
} :: { [string]: string }

GarageMock.HowToGet = "Hop on one during a run and hold on to claim it!"

local TABS: { { id: Tab, long: string, short: string } } = {
	{ id = "Downtown", long = "Downtown", short = "Downtown" },
	{ id = "Dusty", long = "Dusty Highway", short = "Dusty Hwy" },
	{ id = "Summit", long = "Summit Pass", short = "Summit" },
}

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

function GarageMock.new(ctx: Overlay.Ctx, options: Options?): Garage
	local opts: Options = options or {}
	local tab: Tab = "Downtown"
	local selected: CarRef? = nil
	local detailOpen = false
	local driveCalls = 0
	local driveEnabled = false
	local loadingOverride = false
	local downtown = GarageMock.downtownCars()
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

	-- detail
	local detail = Style.well(panel, "Detail", 6)
	local detailCard = CarCard.new(detail, Fixtures.Cars[1], { size = Vector2.new(200, 280), spinning = false })
	trove:Add(function()
		detailCard:destroy()
	end)
	local detailEmpty =
		Overlay.text(detail, "Pick a car to see it here", 18, Style.TextSoft, Enum.TextXAlignment.Center, 7)
	local info: Frame = make("Frame", { Name = "Info", BackgroundTransparency = 1, ZIndex = 7, Parent = detail })
	make("UIListLayout", {
		FillDirection = Enum.FillDirection.Vertical,
		Padding = UDim.new(0, 4),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = info,
	})
	local quirkTitle = Overlay.text(info, "", 22, nil, nil, 7)
	quirkTitle.LayoutOrder = 1
	local quirkLine = Style.paragraph(info, "", 16, true, 7)
	quirkLine.LayoutOrder = 2
	local finishLine = Overlay.text(info, "", 16, Style.TextSoft, nil, 7)
	finishLine.LayoutOrder = 3
	local howToGet = Style.paragraph(info, GarageMock.HowToGet, 18, false, 7)
	howToGet.Name = "HowToGet"
	howToGet.LayoutOrder = 4
	howToGet.Visible = false

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

	local function updateCollection()
		local g = ctx.store:get().garage
		countText.Text = string.format("%d / %d", g.owned, g.total)
	end
	trove:Add(ctx.store:subscribe("garage", function()
		updateCollection()
	end))
	updateCollection()

	local function updateDetail()
		local car = selected
		detailCard.root.Visible = car ~= nil
		detailCard:setVisible(car ~= nil)
		info.Visible = car ~= nil
		detailEmpty.Visible = car == nil
		if not car then
			driveEnabled = false
			driveButton.root.Visible = false
			howToGet.Visible = false
			return
		end
		if detailCard:car() ~= car then
			detailCard:setCar(car)
		end
		local rarity = (PreviewTokens.Rarity :: any)[car.rarity]
		quirkTitle.Text = car.quirk .. "  \u{00B7}  " .. car.family
		quirkLine.Text = GarageMock.QuirkText[car.quirk] or ""
		-- rarity and finish are separate fields: both are named when a finish exists
		local finish = if car.variant ~= "None"
			then rarity.label .. "  \u{00B7}  " .. car.variant .. " finish"
			else rarity.label
		if not car.owned then
			finishLine.Text = finish .. "  \u{00B7}  not owned yet"
		elseif car.model == nil then
			finishLine.Text = finish .. "  \u{00B7}  not ready yet"
		else
			finishLine.Text = finish
		end
		-- an unowned car explains how to get it (no greyed DRIVE)
		howToGet.Visible = not car.owned
		driveButton.root.Visible = car.owned
		driveEnabled = car.owned and car.model ~= nil
		driveButton.setEnabled(driveEnabled)
	end

	local function applyTab()
		for _, t in tabs do
			t.tab.set(t.id == tab)
		end
		if tab == "Downtown" and not loadingOverride then
			grid:setCars(downtown)
			local keep = selected
			if not keep or not table.find(downtown, keep) then
				keep = nil
				for _, c in downtown do
					if c.owned then
						keep = c
						break
					end
				end
			end
			selected = keep
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
		if wide then
			for i, t in tabs do
				t.tab.root.Position = UDim2.fromOffset(14 + (i - 1) * 178, tabsY)
				t.tab.root.Size = UDim2.fromOffset(168, 48)
			end
			bodyX, bodyY = 12, tabsY + 48 + 10
			bodyW, bodyH = pw - 24, ph - bodyY - 12
		elseif short then
			for i, t in tabs do
				t.tab.root.Position = UDim2.fromOffset(12, tabsY + (i - 1) * 56)
				t.tab.root.Size = UDim2.fromOffset(136, 48)
			end
			bodyX, bodyY = 156, headH + 10
			bodyW, bodyH = pw - 168, ph - bodyY - 10
		else
			local tw = math.floor((pw - 24 - 16) / 3)
			for i, t in tabs do
				t.tab.root.Position = UDim2.fromOffset(12 + (i - 1) * (tw + 8), tabsY)
				t.tab.root.Size = UDim2.fromOffset(tw, 48)
			end
			bodyX, bodyY = 8, tabsY + 48 + 10
			bodyW, bodyH = pw - 16, ph - bodyY - 10
		end
		-- grid cell per layout (CarCard switches to its compact layout below 180 wide); widths
		-- leave room for the 8 px scroll bar so the column count never drops
		local desktop = wide and pw >= 1000
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
			if desktop then
				local cardSize = Vector2.new(200, 280)
				detailCard:setSize(cardSize)
				detailCard.root.AnchorPoint = Vector2.new(0.5, 0)
				detailCard.root.Position = UDim2.new(0.5, 0, 0, 16)
				info.Position = UDim2.fromOffset(16, 16 + cardSize.Y + 14)
				info.Size = UDim2.new(1, -32, 0, 120)
			else
				local cardSize = Vector2.new(150, 210)
				detailCard:setSize(cardSize)
				detailCard.root.AnchorPoint = Vector2.zero
				detailCard.root.Position = UDim2.fromOffset(14, 14)
				info.Position = UDim2.fromOffset(14 + cardSize.X + 14, 14)
				info.Size = UDim2.new(1, -(14 + cardSize.X + 14 + 12), 0, cardSize.Y)
			end
			detailEmpty.Position = UDim2.new(0, 0, 0.5, -12)
		else
			gridHolder.Visible = not detailOpen
			gridHolder.Position = UDim2.fromOffset(bodyX, bodyY)
			gridHolder.Size = UDim2.fromOffset(bodyW, bodyH)
			detail.Visible = detailOpen
			detail.Position = UDim2.fromOffset(bodyX, bodyY)
			detail.Size = UDim2.fromOffset(bodyW, bodyH)
			backButton.root.Visible = true
			if short then
				local cardSize = Vector2.new(150, 210)
				detailCard:setSize(cardSize)
				detailCard.root.AnchorPoint = Vector2.zero
				detailCard.root.Position = UDim2.fromOffset(14, math.max(math.floor((bodyH - cardSize.Y) / 2), 8))
				info.Position = UDim2.fromOffset(14 + cardSize.X + 20, 14)
				info.Size = UDim2.new(1, -(14 + cardSize.X + 20 + 14), 0, 110)
				driveButton.root.AnchorPoint = Vector2.new(1, 1)
				driveButton.root.Position = UDim2.new(1, -14, 1, -10)
				backButton.root.AnchorPoint = Vector2.new(1, 1)
				backButton.root.Position = UDim2.new(1, -14 - 180 - 16, 1, -10)
			else
				local cardSize = Vector2.new(200, 280)
				detailCard:setSize(cardSize)
				detailCard.root.AnchorPoint = Vector2.new(0.5, 0)
				detailCard.root.Position = UDim2.new(0.5, 0, 0, 18)
				info.Position = UDim2.fromOffset(16, 18 + cardSize.Y + 16)
				info.Size = UDim2.new(1, -32, 0, 120)
				driveButton.root.AnchorPoint = Vector2.new(1, 1)
				driveButton.root.Position = UDim2.new(1, -14, 1, -12)
				backButton.root.AnchorPoint = Vector2.new(0, 1)
				backButton.root.Position = UDim2.new(0, 14, 1, -12)
			end
			detailEmpty.Position = UDim2.new(0, 0, 0.5, -12)
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

	garage = {
		root = overlay.root,
		layout = function(_self: Garage)
			layoutNow()
		end,
		setVisible = function(_self: Garage, on: boolean)
			overlay.root.Visible = on and overlay:isOpen()
			detailCard:setVisible(on and selected ~= nil)
			grid:refresh()
		end,
		open = function(_self: Garage, returnTo: GuiObject?)
			layoutNow()
			overlay:open(grid:firstBody() or tabs[1].tab.root, returnTo)
			detailCard:setSpinning(true)
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
			detailCard:setSpinning(false)
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
			tab = t
			loadingOverride = false
			applyTab()
			layoutNow()
		end,
		selectCar = function(_self: Garage, id: string)
			for _, c in downtown do
				if c.id == id then
					selected = c
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
		setLoading = function(_self: Garage, on: boolean)
			loadingOverride = on
			applyTab()
			layoutNow()
		end,
		destroy = function(_self: Garage)
			overlay:destroy()
		end,
		getDebugState = function(_self: Garage): DebugState
			return {
				open = overlay:isOpen(),
				kind = overlay:kind(),
				tab = tab,
				selectedId = if selected then selected.id else nil,
				detailOpen = detailOpen,
				collection = countText.Text,
				driveEnabled = driveEnabled,
				driveVisible = driveButton.root.Visible,
				howToGetVisible = howToGet.Visible,
				driveCalls = driveCalls,
				grid = grid:getDebugState(),
				detailCard = if selected then detailCard:getDebugState() else nil,
				instances = #overlay.root:GetDescendants(),
			}
		end,
	}

	applyTab()
	layoutNow()
	return garage
end

return GarageMock
