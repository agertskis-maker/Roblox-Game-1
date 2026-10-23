--!strict
-- TradingSheet: a review sheet of the collectible card variants (Lane 3 Round 2, R2-T2; PREVIEW / harness only, not a
-- player screen). Drawn over gameplay like StatesSheet. Cells (synthetic fixtures; the art is a labelled proxy
-- model, no finished car models exist yet):
--   Compact cards, one per family (the eight family icons are on the Reward cards), Reward cards across rarities
--   (Common to Legendary), the three Worlds, NEW, unowned (silhouette), the Epic and Legendary FOIL, a long name.
-- The cell captions are harness captions (PreviewCaption), so player-facing captures omit them.
--
--   local sheet = TradingSheet.new(ctx)
--   sheet:open(returnTo?)  sheet:close()  sheet:isOpen()
--   sheet:layout()  sheet:setVisible(on)  sheet:destroy()  sheet:getDebugState()

local Prototype = script.Parent.Parent
local Arcade = require(Prototype.Arcade)
local Fixtures = require(Prototype.Fixtures)
local Overlay = require(Prototype.Screens.Overlay)
local Style = require(Prototype.Screens.Style)
local TradingCard = require(script.Parent.TradingCard)

local make = Arcade.make

local TradingSheet = {}

local CELL = Vector2.new(210, 372)

type Spec = { label: string, car: TradingCard.CarRef, info: TradingCard.Info?, variant: string, stamp: string? }

local function byId(id: string): TradingCard.CarRef
	return Fixtures.byId(id) or Fixtures.Cars[1]
end

local function with(base: TradingCard.CarRef, patch: { [string]: any }): TradingCard.CarRef
	local c = table.clone(base) :: any
	for k, v in patch do
		c[k] = v
	end
	return c :: TradingCard.CarRef
end

local function infoFor(id: string, patch: { [string]: any }?): TradingCard.Info
	local base = Fixtures.cardInfo(id) or {}
	local info = table.clone(base) :: any
	if patch then
		for k, v in patch do
			info[k] = v
		end
	end
	return info :: TradingCard.Info
end

function TradingSheet.specs(): { Spec }
	local specs: { Spec } = {}
	-- Compact: one per family (fixture family Bus maps to the Truck icon and is flagged)
	for _, car in Fixtures.Cars do
		table.insert(specs, {
			label = "Compact: " .. car.family .. " (" .. car.rarity .. ")",
			car = with(car, { owned = true }),
			info = infoFor(car.id, { isNew = car.id == "zoomurai" }),
			variant = "Compact",
		})
	end
	-- Reward: rarities, Worlds, states
	table.insert(specs, {
		label = "Reward: Common, Downtown",
		car = with(byId("puglet"), { owned = true }),
		info = infoFor("puglet", { isNew = true }),
		variant = "Reward",
		stamp = "SECURED",
	})
	table.insert(specs, {
		label = "Reward: Rare, Dusty Highway",
		car = with(byId("rev6"), { owned = true }),
		info = infoFor("rev6", { world = "DustyHighway", isNew = true }),
		variant = "Reward",
		stamp = "SECURED",
	})
	table.insert(specs, {
		label = "Reward: Epic foil, Summit Pass",
		car = with(byId("hurrikan"), { owned = true }),
		info = infoFor("hurrikan", { world = "SummitPass", isNew = true }),
		variant = "Reward",
		stamp = "SECURED",
	})
	table.insert(specs, {
		label = "Reward: Legendary foil",
		car = with(byId("hyperion"), { owned = true }),
		info = infoFor("hyperion", { isNew = true }),
		variant = "Reward",
		stamp = "SECURED",
	})
	table.insert(specs, {
		label = "Reward: not owned (silhouette)",
		car = byId("rangy"),
		info = infoFor("rangy"),
		variant = "Reward",
	})
	table.insert(specs, {
		label = "Reward: long name",
		car = with(byId("waffle"), { name = "Citrine Waffle Van Deluxe Edition", owned = true }),
		info = infoFor("waffle"),
		variant = "Reward",
	})
	local noPay = infoFor("fishbowl");
	(noPay :: any).lapPay = nil -- nothing supplied: the plate shows a dash, never an invented amount
	table.insert(specs, {
		label = "Reward: no Lap Pay supplied",
		car = with(byId("fishbowl"), { owned = true }),
		info = noPay,
		variant = "Reward",
	})
	return specs
end

function TradingSheet.new(ctx: Overlay.Ctx)
	local sheet: any = {}
	local overlay = Overlay.new(ctx, { name = "TradingSheet" })
	local trove = overlay.trove
	local content = overlay.content
	local shell = Style.panel(content, { name = "Panel", z = 3 })
	local panel = shell.body
	local header = Style.header(panel, { fill = "Garage", title = "COLLECTIBLE CARDS", icon = "GarageBook" })
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

	local items: { { label: string, card: any } } = {}
	for i, spec in TradingSheet.specs() do
		local cell: Frame = make("Frame", {
			Name = string.format("Cell%02d", i),
			BackgroundTransparency = 1,
			LayoutOrder = i,
			ZIndex = 6,
			Parent = scroll,
		})
		local card = TradingCard.new(cell, spec.car, spec.info, { variant = spec.variant, stamp = spec.stamp })
		card.root.AnchorPoint = Vector2.new(0.5, 0)
		card.root.Position = UDim2.new(0.5, 0, 0, 6)
		trove:Add(function()
			card:destroy()
		end)
		local caption = Overlay.text(cell, spec.label, 16, Style.TextSoft, Enum.TextXAlignment.Center, 7)
		caption:SetAttribute("PreviewCaption", true) -- harness annotation
		caption.AnchorPoint = Vector2.new(0, 1)
		caption.Position = UDim2.fromScale(0, 1)
		caption.Size = UDim2.new(1, 0, 0, 22)
		table.insert(items, { label = spec.label, card = card })
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

	function sheet.layout(_me: any)
		layoutNow()
	end
	function sheet.setVisible(_me: any, on: boolean)
		overlay.root.Visible = on and overlay:isOpen()
		for _, it in items do
			it.card:setVisible(on and overlay:isOpen())
		end
	end
	function sheet.open(_me: any, returnTo: GuiObject?)
		layoutNow()
		overlay:open(items[1] and items[1].card:card().body, returnTo)
		for _, it in items do
			it.card:setVisible(true)
		end
	end
	function sheet.close(_me: any)
		if not overlay:isOpen() then
			return
		end
		for _, it in items do
			it.card:setVisible(false)
		end
		overlay:close()
	end
	function sheet.isOpen(_me: any): boolean
		return overlay:isOpen()
	end
	function sheet.destroy(_me: any)
		overlay:destroy()
	end
	function sheet.getDebugState(_me: any): { [string]: any }
		local states = {}
		local foil = 0
		local animated = 0
		for _, it in items do
			local d = it.card:getDebugState()
			if d.foil then
				foil += 1
			end
			if d.foilAnimated then
				animated += 1
			end
			table.insert(states, { label = it.label, card = d })
		end
		return {
			open = overlay:isOpen(),
			kind = overlay:kind(),
			cards = #items,
			foilCards = foil,
			foilAnimated = animated,
			states = states,
			instances = #overlay.root:GetDescendants(),
		}
	end

	layoutNow()
	return sheet
end

return TradingSheet
