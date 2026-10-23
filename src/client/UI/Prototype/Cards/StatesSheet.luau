--!strict
-- StatesSheet: a review sheet of every CarCard state in the kit family (Lane 3 HUD rebuild,
-- PREVIEW / harness only; it is not a player screen). Drawn over gameplay like the other mocks.
--
--   local sheet = StatesSheet.new(ctx)
--   sheet:open(returnTo?)  sheet:close()  sheet:isOpen()
--   sheet:layout()  sheet:setVisible(on)  sheet:destroy()  sheet:getDebugState()
--
-- Cells (synthetic fixtures): owned, unowned (silhouette), selected, loading, unavailable, the
-- three finishes (Gold / Chrome / Rainbow, separate from rarity), earned-unseen NEW, the
-- SECURED stamp (a late-confirmed claim), every rarity from Common to Legendary, the long-name
-- rule ("Revolution 6" in a narrow card, "Citrine Waffle Van Deluxe Edition", and a name too
-- long for two lines that keeps its last word) and the 112 x 150 minimum size. The state labels
-- under the cards are harness captions (PreviewCaption). At most 6 cards spin; reduced motion
-- keeps all of them static (the shared CarCard ticker).

local Prototype = script.Parent.Parent
local Arcade = require(Prototype.Arcade)
local CarCard = require(script.Parent.CarCard)
local Fixtures = require(Prototype.Fixtures)
local Overlay = require(Prototype.Screens.Overlay)
local Style = require(Prototype.Screens.Style)

local make = Arcade.make

local StatesSheet = {}

StatesSheet.MaxSpinning = 6
-- TOKEN CANDIDATE (harness only): one sheet cell = the largest card plus its caption.
local CELL = Vector2.new(204, 318)

export type CarRef = CarCard.CarRef

type Spec = {
	label: string,
	car: CarRef,
	size: Vector2?,
	selected: boolean?,
	loading: boolean?,
	stamp: string?,
	spin: boolean?,
	nameLines: number?,
}

export type DebugState = {
	open: boolean,
	kind: string,
	cards: number,
	spinning: number,
	states: { { label: string, card: CarCard.DebugState } },
	instances: number,
}

export type Sheet = {
	root: Frame,
	layout: (self: Sheet) -> (),
	setVisible: (self: Sheet, on: boolean) -> (),
	open: (self: Sheet, returnTo: GuiObject?) -> (),
	close: (self: Sheet) -> (),
	isOpen: (self: Sheet) -> boolean,
	destroy: (self: Sheet) -> (),
	getDebugState: (self: Sheet) -> DebugState,
}

local function byId(id: string): CarRef
	return Fixtures.byId(id) or Fixtures.Cars[1]
end

local function variant(base: CarRef, suffix: string, patch: { [string]: any }): CarRef
	local c = table.clone(base) :: any
	c.id = base.id .. "-" .. suffix
	for k, v in patch do
		c[k] = v
	end
	return c :: CarRef
end

function StatesSheet.specs(): { Spec }
	local rev6 = byId("rev6")
	local waffle = byId("waffle")
	return {
		{ label = "Owned (Common)", car = byId("puglet"), spin = true },
		{ label = "Not owned (Rare)", car = rev6 },
		{
			label = "Selected",
			car = variant(byId("hurrikan"), "owned", { owned = true }),
			selected = true,
			spin = true,
		},
		{ label = "Loading", car = Fixtures.Missing, loading = true },
		{ label = "Unavailable", car = variant(Fixtures.Missing, "na", {}) },
		{ label = "Gold finish (Common)", car = Fixtures.Variants.Gold, spin = true },
		{
			label = "Chrome finish + NEW",
			car = variant(Fixtures.Variants.Chrome, "new", { unseen = true }),
			spin = true,
		},
		{ label = "Rainbow finish (Uncommon)", car = variant(Fixtures.Variants.Rainbow, "owned", { owned = true }) },
		{
			label = "Secured (late claim)",
			car = variant(rev6, "secured", { owned = true }),
			stamp = "SECURED",
			spin = true,
		},
		{ label = "Legendary", car = variant(byId("hyperion"), "owned", { owned = true }), spin = true },
		{ label = "Epic, not owned", car = byId("hurrikan") },
		{
			label = "Long name, narrow card",
			car = variant(rev6, "narrow", { owned = true }),
			size = Vector2.new(124, 172),
			nameLines = 3,
		},
		{
			label = "Long name, two lines",
			car = variant(waffle, "deluxe", { name = "Citrine Waffle Van Deluxe Edition" }),
			size = Vector2.new(176, 236),
		},
		{ label = "Too long: last word kept", car = Fixtures.LongName },
		{ label = "Minimum 112 x 150", car = byId("zoomurai"), size = Vector2.new(112, 150) },
	}
end

function StatesSheet.new(ctx: Overlay.Ctx, _options: any?): Sheet
	local sheet: Sheet
	local overlay = Overlay.new(ctx, { name = "CardStatesSheet" })
	local trove = overlay.trove
	local content = overlay.content

	local shell = Style.panel(content, { name = "Panel", z = 3 })
	local panel = shell.body
	local header = Style.header(panel, { fill = "Garage", title = "CAR CARDS", icon = "Car" })
	local closeButton = Overlay.closeButton(panel, function()
		sheet:close()
	end)
	trove:Add(closeButton.trove)
	closeButton.root.AnchorPoint = Vector2.new(1, 0.5)
	closeButton.root.ZIndex = 12

	local scroll = Style.scroll(panel, "Cells", 5)
	make("UIGridLayout", {
		CellSize = UDim2.fromOffset(CELL.X, CELL.Y),
		CellPadding = UDim2.fromOffset(14, 14),
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		Parent = scroll,
	})
	make("UIPadding", {
		PaddingTop = UDim.new(0, 12),
		PaddingBottom = UDim.new(0, 12),
		PaddingLeft = UDim.new(0, 10),
		PaddingRight = UDim.new(0, 10),
		Parent = scroll,
	})

	type Item = { label: string, card: CarCard.Card, spin: boolean }
	local items: { Item } = {}
	local spinCount = 0
	for i, spec in StatesSheet.specs() do
		local cell: Frame = make("Frame", {
			Name = string.format("Cell%02d", i),
			BackgroundTransparency = 1,
			LayoutOrder = i,
			ZIndex = 6,
			Parent = scroll,
		})
		local card = CarCard.new(cell, spec.car, {
			size = spec.size or CarCard.BaseSize,
			selected = spec.selected,
			loading = spec.loading,
			anchor = Vector2.new(0.5, 0),
			position = UDim2.new(0.5, 0, 0, 10),
			nameLines = spec.nameLines,
		})
		if spec.stamp then
			card:setStamp(spec.stamp)
		end
		trove:Add(function()
			card:destroy()
		end)
		local caption = Overlay.text(cell, spec.label, 16, Style.TextSoft, Enum.TextXAlignment.Center, 7)
		caption:SetAttribute("PreviewCaption", true) -- harness annotation
		caption.AnchorPoint = Vector2.new(0, 1)
		caption.Position = UDim2.fromScale(0, 1)
		caption.Size = UDim2.new(1, 0, 0, 22)
		local spin = spec.spin == true and spinCount < StatesSheet.MaxSpinning
		if spin then
			spinCount += 1
		end
		table.insert(items, { label = spec.label, card = card, spin = spin })
	end

	local function setSpinning(on: boolean)
		for _, it in items do
			it.card:setSpinning(on and it.spin)
		end
	end

	local function layoutNow()
		overlay:applyScale()
		local ds = overlay:designSize()
		local kind = Overlay.kindFor(ds)
		local pw, ph = math.min(ds.X - 24, 1180), ds.Y - 20
		shell.root.Size = UDim2.fromOffset(pw, ph)
		shell.root.Position = UDim2.new(0.5, 0, 0.5, -2)
		local headH = if kind == "Short" then Style.HeaderHeightShort else Style.HeaderHeight
		header.setHeight(headH)
		closeButton.root.Position = UDim2.new(1, -8, 0, headH / 2)
		local titleLeft = header.title.Position.X.Offset
		header.title.Size = UDim2.new(1, -titleLeft - Overlay.CloseWidth - 18, 0, math.min(44, headH - 6))
		scroll.Position = UDim2.fromOffset(8, headH + 8)
		scroll.Size = UDim2.new(1, -16, 1, -(headH + 16))
	end

	overlay:setBack(function()
		sheet:close()
	end)
	trove:Connect(ctx.screen.Changed, function()
		layoutNow()
	end)

	sheet = {
		root = overlay.root,
		layout = function(_self: Sheet)
			layoutNow()
		end,
		setVisible = function(_self: Sheet, on: boolean)
			overlay.root.Visible = on and overlay:isOpen()
			setSpinning(on and overlay:isOpen())
		end,
		open = function(_self: Sheet, returnTo: GuiObject?)
			layoutNow()
			overlay:open(items[1] and items[1].card.body, returnTo)
			setSpinning(true)
		end,
		close = function(_self: Sheet)
			if not overlay:isOpen() then
				return
			end
			setSpinning(false)
			overlay:close()
		end,
		isOpen = function(_self: Sheet): boolean
			return overlay:isOpen()
		end,
		destroy = function(_self: Sheet)
			overlay:destroy()
		end,
		getDebugState = function(_self: Sheet): DebugState
			local states = {}
			local spinning = 0
			for _, it in items do
				local d = it.card:getDebugState()
				if d.spinning then
					spinning += 1
				end
				table.insert(states, { label = it.label, card = d })
			end
			return {
				open = overlay:isOpen(),
				kind = overlay:kind(),
				cards = #items,
				spinning = spinning,
				states = states,
				instances = #overlay.root:GetDescendants(),
			}
		end,
	}

	layoutNow()
	return sheet
end

return StatesSheet
