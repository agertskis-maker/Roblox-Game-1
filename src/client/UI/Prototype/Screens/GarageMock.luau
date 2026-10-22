--!strict
-- GarageMock: a navigable Garage / Index mock drawn over gameplay (Lane 3 HUD prototype,
-- PREVIEW only; no ownership, purchase or save logic).
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
-- ("3 / 12", synthetic). "Drive" only calls options.onDrive(car) for an owned car.
-- Back (Escape / gamepad B): closes the phone detail view first, then the Garage.
-- Quirk sentences paraphrase outline v2.2 section 07 (delegated, tunable), not final copy.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Prototype = script.Parent.Parent
local CarCard = require(Prototype.Cards.CarCard)
local CardGrid = require(Prototype.Cards.CardGrid)
local Fixtures = require(Prototype.Fixtures)
local Gloss = require(Prototype.Gloss)
local Icons = require(Prototype.Icons)
local Overlay = require(script.Parent.Overlay)
local PreviewTokens = require(Prototype.PreviewTokens)
local Tokens = require(ReplicatedStorage.Shared.UI.Tokens)

local C = PreviewTokens.Color
local make = Gloss.make

local GarageMock = {}

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
	driveCalls: number,
	grid: CardGrid.DebugState,
	detailCard: CarCard.DebugState?,
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

	local panel = Gloss.panel(content, {
		name = "Panel",
		size = UDim2.fromOffset(600, 400),
		anchor = Vector2.new(0.5, 0.5),
		position = UDim2.fromScale(0.5, 0.5),
		radius = 20,
		z = 3,
	})
	local panelShadow = content:FindFirstChild("Shadow") :: Frame?

	-- header
	local title = Overlay.title(panel, "GARAGE", 30, C.GarageLight, C.GarageDeep, 6)
	title.Size = UDim2.fromOffset(150, 40)
	local countPill = make("Frame", {
		Name = "Collection",
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 36),
		BackgroundColor3 = C.White,
		BorderSizePixel = 0,
		ZIndex = 6,
		Parent = panel,
	})
	Gloss.corner(countPill, 18)
	Gloss.stroke(countPill, 2)
	make("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 12), Parent = countPill })
	make("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = countPill,
	})
	local countIcon = make("Frame", {
		Name = "Icon",
		Size = UDim2.fromOffset(24, 24),
		BackgroundTransparency = 1,
		LayoutOrder = 1,
		ZIndex = 7,
		Parent = countPill,
	})
	Icons.draw(countIcon, "Garage", C.GarageDeep)
	local countText = make("TextLabel", {
		Name = "Count",
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 30),
		BackgroundTransparency = 1,
		FontFace = Tokens.font(),
		Text = "0 / 0",
		TextSize = Tokens.TextSize.Value - 2,
		TextColor3 = C.Ink,
		LayoutOrder = 2,
		ZIndex = 7,
		Parent = countPill,
	})
	local closeButton = Overlay.closeButton(panel, function()
		garage:close()
	end)
	trove:Add(closeButton.trove)
	closeButton.root.AnchorPoint = Vector2.new(1, 0)

	-- tabs
	type TabButton = { id: Tab, button: TextButton, label: TextLabel, gradient: UIGradient, stroke: UIStroke }
	local tabButtons: { TabButton } = {}
	local function styleTab(t: TabButton)
		local on = t.id == tab
		t.gradient.Enabled = on
		t.button.BackgroundColor3 = if on then C.White else C.Panel
		t.label.TextColor3 = if on then C.White else C.Ink
		t.stroke.Thickness = if on then 3 else 2
		local labelStroke = t.label:FindFirstChildOfClass("UIStroke")
		if labelStroke then
			labelStroke.Enabled = on
		end
	end
	for i, def in TABS do
		local b: TextButton = make("TextButton", {
			Name = "Tab_" .. def.id,
			Size = UDim2.fromOffset(160, 48),
			BackgroundColor3 = C.Panel,
			AutoButtonColor = false,
			Text = "",
			LayoutOrder = i,
			Selectable = true,
			ZIndex = 6,
			Parent = panel,
		})
		Gloss.corner(b, 14)
		local stroke = Gloss.stroke(b, 2)
		local gradient = Gloss.gradient(b, C.GarageLight, C.GarageDeep)
		local label = make("TextLabel", {
			Name = "Text",
			BackgroundTransparency = 1,
			Size = UDim2.new(1, -12, 1, 0),
			Position = UDim2.fromOffset(6, 0),
			FontFace = Tokens.font(),
			Text = def.long,
			TextSize = Tokens.TextSize.Label,
			TextColor3 = C.Ink,
			TextTruncate = Enum.TextTruncate.AtEnd,
			ZIndex = 7,
			Parent = b,
		})
		local ls = Gloss.stroke(label, 2, C.Ink, Enum.ApplyStrokeMode.Contextual)
		ls.Enabled = false
		local t: TabButton = { id = def.id, button = b, label = label, gradient = gradient, stroke = stroke }
		table.insert(tabButtons, t)
		trove:Connect(b.Activated, function()
			garage:selectTab(def.id)
		end)
	end

	-- grid
	local gridHolder = make("Frame", {
		Name = "GridHolder",
		BackgroundColor3 = C.PanelShade,
		BackgroundTransparency = 0.4,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		ZIndex = 4,
		Parent = panel,
	})
	Gloss.corner(gridHolder, 14)
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
	local detail = make("Frame", {
		Name = "Detail",
		BackgroundColor3 = C.Panel,
		BorderSizePixel = 0,
		ZIndex = 6,
		Parent = panel,
	})
	Gloss.corner(detail, 14)
	Gloss.stroke(detail, 2).Transparency = 0.5
	local detailCard = CarCard.new(detail, Fixtures.Cars[1], { size = Vector2.new(200, 280), spinning = false })
	trove:Add(function()
		detailCard:destroy()
	end)
	local detailEmpty = Overlay.text(detail, "Pick a car to see it here", 18, C.InkSoft, Enum.TextXAlignment.Center, 7)
	local info = make("Frame", { Name = "Info", BackgroundTransparency = 1, ZIndex = 7, Parent = detail })
	make("UIListLayout", {
		FillDirection = Enum.FillDirection.Vertical,
		Padding = UDim.new(0, 4),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = info,
	})
	local quirkTitle = Overlay.text(info, "", 22, C.Ink, nil, 7)
	quirkTitle.LayoutOrder = 1
	local quirkLine = Overlay.paragraph(info, "", 16, C.InkSoft, 7)
	quirkLine.LayoutOrder = 2
	local finishLine = Overlay.text(info, "", 16, C.InkSoft, nil, 7)
	finishLine.LayoutOrder = 3

	local driveButton = Gloss.button(detail, {
		name = "Drive",
		size = Vector2.new(180, 56),
		light = C.PrimaryLight,
		deep = C.PrimaryDeep,
		text = "DRIVE",
		textSize = 24,
		onActivate = function()
			if driveEnabled and selected and opts.onDrive then
				driveCalls += 1
				opts.onDrive(selected)
			end
		end,
	})
	trove:Add(driveButton.trove)
	local backButton = Gloss.button(detail, {
		name = "Back",
		size = Vector2.new(112, 48),
		light = C.SettingsLight,
		deep = C.SettingsDeep,
		text = "BACK",
		textSize = 18,
		sound = "Close",
		onActivate = function()
			if detailOpen then
				detailOpen = false
				garage:layout()
			end
		end,
	})
	trove:Add(backButton.trove)

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
			return
		end
		driveButton.root.Visible = true
		if detailCard:car() ~= car then
			detailCard:setCar(car)
		end
		local rarity = (PreviewTokens.Rarity :: any)[car.rarity]
		quirkTitle.Text = car.quirk .. "  \u{00B7}  " .. car.family
		quirkLine.Text = GarageMock.QuirkText[car.quirk] or ""
		local finish = if car.variant ~= "None" then car.variant .. " finish" else rarity.label
		if not car.owned then
			finishLine.Text = finish .. "  \u{00B7}  not owned yet"
		elseif car.model == nil then
			finishLine.Text = finish .. "  \u{00B7}  model unavailable"
		else
			finishLine.Text = finish
		end
		driveEnabled = car.owned and car.model ~= nil
		driveButton.setEnabled(driveEnabled)
	end

	local function applyTab()
		for _, t in tabButtons do
			styleTab(t)
		end
		if tab == "Downtown" and not loadingOverride then
			grid:setCars(downtown)
			local keep = selected
			if not keep or not table.find(downtown, keep) then
				-- pick the first owned car
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
			pw, ph = math.min(ds.X - 24, 1120), math.min(ds.Y - 16, 680)
		elseif kind == "Short" then
			pw, ph = ds.X - 24, ds.Y - 16
		else
			pw, ph = ds.X - 16, ds.Y - 16
		end
		panel.Size = UDim2.fromOffset(pw, ph)
		if panelShadow then
			panelShadow.Size = panel.Size
		end
		closeButton.root.Position = UDim2.new(1, -10, 0, 8)
		title.Position = UDim2.fromOffset(16, 12)
		countPill.Position = UDim2.fromOffset(16 + 150 + 4, 14)
		local tabNames = kind ~= "Wide"
		for _, t in tabButtons do
			local def = TABS[t.button.LayoutOrder]
			t.label.Text = if tabNames then def.short else def.long
		end
		local bodyX, bodyY, bodyW, bodyH
		local wide = kind == "Wide"
		if kind == "Wide" then
			for i, t in tabButtons do
				t.button.Position = UDim2.fromOffset(16 + (i - 1) * 176, 64)
				t.button.Size = UDim2.fromOffset(168, 48)
			end
			bodyX, bodyY, bodyW, bodyH = 12, 122, pw - 24, ph - 134
		elseif kind == "Short" then
			for i, t in tabButtons do
				t.button.Position = UDim2.fromOffset(12, 64 + (i - 1) * 56)
				t.button.Size = UDim2.fromOffset(136, 48)
			end
			bodyX, bodyY, bodyW, bodyH = 156, 60, pw - 168, ph - 68
		else
			local tw = math.floor((pw - 24 - 16) / 3)
			for i, t in tabButtons do
				t.button.Position = UDim2.fromOffset(12 + (i - 1) * (tw + 8), 64)
				t.button.Size = UDim2.fromOffset(tw, 48)
			end
			bodyX, bodyY, bodyW, bodyH = 8, 122, pw - 16, ph - 130
		end
		-- grid cell per layout (CarCard switches to its compact layout below 180 wide); widths
		-- leave room for the 8 px scroll bar so the column count never drops
		local desktop = wide and pw >= 1000
		local cell = if wide
			then (if desktop then Vector2.new(200, 280) else Vector2.new(170, 238))
			elseif kind == "Short" then Vector2.new(140, 196)
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
				-- big card on top, text below, Drive at the bottom
				local cardSize = Vector2.new(200, 280)
				detailCard:setSize(cardSize)
				detailCard.root.AnchorPoint = Vector2.new(0.5, 0)
				detailCard.root.Position = UDim2.new(0.5, 0, 0, 16)
				info.Position = UDim2.fromOffset(16, 16 + cardSize.Y + 14)
				info.Size = UDim2.new(1, -32, 0, 110)
			else
				-- tablet: card on the left, text on the right, Drive below both
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
			if kind == "Short" then
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
			overlay:open(grid:firstBody() or tabButtons[1].button, returnTo)
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
				driveCalls = driveCalls,
				grid = grid:getDebugState(),
				detailCard = if selected then detailCard:getDebugState() else nil,
			}
		end,
	}

	applyTab()
	layoutNow()
	return garage
end

return GarageMock
