--!strict
-- CardGrid: a scrolling grid of CarCards (Lane 3 HUD prototype, PREVIEW only). HUD rebuild
-- (2026-10-22): dark kit wells for the loading tiles, white outlined empty text (no cream).
--
--   local grid = CardGrid.new(parent, { cell = Vector2.new(200, 280), onSelect = fn })
--   grid.root                      -- a Frame; size and place it like any frame
--   grid:setCars(cars)             -- {} shows the empty message; the SAME cars in a new order (a sort) keep their
--                                     cards (models, selection) and only reorder
--   CardGrid.sortCars(cars, mode?, keys?) -> new array   -- "Rarest" | "LapPay" | "Newest" (pure, see below)
--   grid:setLoading(true)          -- grey skeleton tiles with "Loading cars"
--   grid:setEmptyText(text)
--   grid:select(id?)               -- marks one card selected (ring + lift), nil clears
--   grid:setCell(Vector2)          -- re-lays out every card (models kept)
--   grid:refresh()                 -- re-checks what is on screen (call after showing the grid)
--   grid:getDebugState()           -- { cards, built, spinning, ... }
--
-- Shared rhythm (Round 3): every card of a grid has the SAME header height. The grid measures every car name at the
-- cell width and gives all cards the largest header (2 lines normally, 3 or 4 only when a name needs them at 16 px),
-- so one long name never makes one card differ from its neighbours. Names are never cut (see CarCard).
--
-- Performance rules: cards are created lazily (no model) and a card's proxy is built only when
-- the card comes within one row of the visible area, once. At most `maxSpinning` (default 6)
-- cards spin: the selected card first if it is visible, then the visible cards in order; all
-- others stay at the static 3/4 angle. The CarCard ticker additionally pauses anything that is
-- off screen or hidden.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Prototype = script.Parent.Parent
local CarCard = require(script.Parent.CarCard)
local Arcade = require(Prototype.Arcade)
local PreviewTokens = require(Prototype.PreviewTokens)
local Style = require(Prototype.Screens.Style)
local Tokens = require(ReplicatedStorage.Shared.UI.Tokens)
local Trove = require(ReplicatedStorage.Packages.Trove)

local make = Arcade.make

local CardGrid = {}

CardGrid.MaxSpinning = 6
CardGrid.Gap = Vector2.new(18, 22)
CardGrid.Padding = 14 -- room for the selected ring and lift

export type CarRef = CarCard.CarRef

export type Options = {
	cell: Vector2?,
	maxSpinning: number?,
	onSelect: ((CarRef) -> ())?,
	emptyText: string?,
	loadingText: string?,
	skeletons: number?,
}

export type DebugState = {
	cards: number,
	built: number,
	spinning: number,
	active: number,
	loading: boolean,
	empty: boolean,
	selectedId: string?,
	cell: { number }, -- {w, h} (JSON-safe)
	canvasY: number,
	order: { string }, -- the car ids in the order the cards are laid out
	nameLines: number, -- the header lines every card shares
	headerHeights: { number }, -- each card's header box height (all equal)
}

export type Grid = {
	root: Frame,
	scroll: ScrollingFrame,
	setCars: (self: Grid, cars: { CarRef }) -> (),
	setLoading: (self: Grid, loading: boolean) -> (),
	setEmptyText: (self: Grid, text: string) -> (),
	select: (self: Grid, id: string?) -> (),
	selected: (self: Grid) -> CarRef?,
	setCell: (self: Grid, cell: Vector2) -> (),
	cards: (self: Grid) -> { CarCard.Card },
	firstBody: (self: Grid) -> GuiObject?,
	refresh: (self: Grid) -> (),
	destroy: (self: Grid) -> (),
	getDebugState: (self: Grid) -> DebugState,
}

---------------------------------------------------------------------------------------------
-- Sorting (pure: a new array every time, the source is never touched)
---------------------------------------------------------------------------------------------

export type SortMode = "Rarest" | "LapPay" | "Newest"
export type SortKeys = {
	lapPay: ((CarRef) -> number?)?, -- the supplied Lap Pay NUMBER of a car (nil = unknown)
	acquired: ((CarRef) -> number?)?, -- the supplied acquisition number of a car, larger = newer (nil = no date)
}

CardGrid.SortModes = table.freeze({ "Rarest", "LapPay", "Newest" })

local RARITY_RANK: { [string]: number } = {}
for index, name in PreviewTokens.RarityOrder do
	RARITY_RANK[name] = index -- Common 1 .. Legendary 5; an unknown rarity word ranks 0 (last)
end

type Entry = { car: CarRef, index: number, rank: number, value: number?, name: string, id: string }

local function finiteNumber(v: any): number?
	if type(v) == "number" and v == v then
		return v
	end
	return nil
end

-- known numbers first, larger first; unknown last; every tie keeps the source order
local function byNumber(a: Entry, b: Entry): boolean
	local av, bv = a.value, b.value
	if av ~= nil and bv ~= nil and av ~= bv then
		return av > bv
	end
	if (av == nil) ~= (bv == nil) then
		return av ~= nil
	end
	return a.index < b.index
end

-- rarest first; then name A to Z (not case sensitive); then car id; then the source order
local function byRarity(a: Entry, b: Entry): boolean
	if a.rank ~= b.rank then
		return a.rank > b.rank
	end
	if a.name ~= b.name then
		return a.name < b.name
	end
	if a.id ~= b.id then
		return a.id < b.id
	end
	return a.index < b.index
end

-- Returns a NEW array of the same cars in the order for `mode` (nil = the source order). Rarest: Legendary, Epic, Rare,
-- Uncommon, Common. LapPay and Newest read the numbers the caller supplies (never a formatted string, never the array
-- position, never an asset time): a car without a number goes after every car with one.
function CardGrid.sortCars(cars: { CarRef }, mode: SortMode?, keys: SortKeys?): { CarRef }
	local out: { CarRef } = {}
	if mode == nil then
		for _, car in cars do
			table.insert(out, car)
		end
		return out
	end
	local supplied: SortKeys = keys or {}
	local entries: { Entry } = {}
	for i, car in cars do
		local value: number? = nil
		if mode == "LapPay" and supplied.lapPay then
			value = finiteNumber(supplied.lapPay(car))
		elseif mode == "Newest" and supplied.acquired then
			value = finiteNumber(supplied.acquired(car))
		end
		table.insert(entries, {
			car = car,
			index = i,
			rank = RARITY_RANK[car.rarity] or 0,
			value = value,
			name = string.lower(car.name),
			id = car.id,
		})
	end
	table.sort(entries, if mode == "Rarest" then byRarity else byNumber)
	for _, entry in entries do
		table.insert(out, entry.car)
	end
	return out
end

local function overlaps(a: GuiObject, b: GuiObject, margin: number): boolean
	local ap, as = a.AbsolutePosition, a.AbsoluteSize
	local bp, bs = b.AbsolutePosition, b.AbsoluteSize
	return ap.X < bp.X + bs.X + margin
		and ap.X + as.X > bp.X - margin
		and ap.Y < bp.Y + bs.Y + margin
		and ap.Y + as.Y > bp.Y - margin
end

-- In the game, every GuiObject ancestor visible, and the ScreenGui enabled. A closed screen
-- therefore builds no models and spins nothing.
local function visibleChain(g: GuiObject): boolean
	if not g:IsDescendantOf(game) then
		return false
	end
	local node: Instance? = g
	while node do
		if node:IsA("GuiObject") then
			if not (node :: GuiObject).Visible then
				return false
			end
		elseif node:IsA("LayerCollector") then
			return (node :: LayerCollector).Enabled
		end
		node = node.Parent
	end
	return false
end

function CardGrid.new(parent: Instance, options: Options?): Grid
	local opts: Options = options or {}
	local trove = Trove.new()
	local cardTrove = trove:Extend()
	local skeletonTrove = trove:Extend()
	local cell = opts.cell or CarCard.BaseSize
	local maxSpinning = opts.maxSpinning or CardGrid.MaxSpinning
	local cards: { CarCard.Card } = {}
	local selectedId: string? = nil
	local loading = false
	local scheduled = false
	local destroyed = false
	local rhythmToken = 0
	local sharedLines = 2

	local root: Frame = trove:Add(make("Frame", {
		Name = "CardGrid",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ClipsDescendants = false,
	}))
	local scroll: ScrollingFrame = make("ScrollingFrame", {
		Name = "Scroll",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ScrollBarThickness = 8,
		ScrollBarImageColor3 = Color3.new(1, 1, 1),
		ScrollBarImageTransparency = 0.3,
		VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar,
		Selectable = false,
		ZIndex = 2,
		Parent = root,
	})
	make("UIPadding", {
		PaddingTop = UDim.new(0, CardGrid.Padding),
		PaddingBottom = UDim.new(0, CardGrid.Padding + 6),
		PaddingLeft = UDim.new(0, CardGrid.Padding),
		PaddingRight = UDim.new(0, CardGrid.Padding),
		Parent = scroll,
	})
	local gridLayout: UIGridLayout = make("UIGridLayout", {
		CellSize = UDim2.fromOffset(cell.X, cell.Y),
		CellPadding = UDim2.fromOffset(CardGrid.Gap.X, CardGrid.Gap.Y),
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		Parent = scroll,
	})

	-- empty message
	local empty = make("Frame", {
		Name = "Empty",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		AutomaticSize = Enum.AutomaticSize.Y, -- grows with the message, so a long line is never cut
		Size = UDim2.new(1, -32, 0, 0),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 3,
		Parent = root,
	})
	local emptyIcon = make("Frame", {
		Name = "Icon",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.fromOffset(52, 52),
		BackgroundTransparency = 1,
		ZIndex = 4,
		Parent = empty,
	})
	Arcade.icon(emptyIcon, "Car")
	local emptyText = make("TextLabel", {
		Name = "Text",
		Position = UDim2.fromOffset(0, 60),
		AutomaticSize = Enum.AutomaticSize.Y,
		Size = UDim2.fromScale(1, 0),
		BackgroundTransparency = 1,
		FontFace = Tokens.font(),
		Text = opts.emptyText or "No cars here yet",
		TextSize = Tokens.TextSize.Label,
		TextWrapped = true,
		TextColor3 = Style.TextSoft,
		ZIndex = 4,
		Parent = empty,
	})
	Arcade.outline(emptyText, "Minor")

	-- loading skeleton
	local skeleton = make("Frame", {
		Name = "Loading",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		Visible = false,
		ZIndex = 3,
		Parent = root,
	})
	make("UIPadding", {
		PaddingTop = UDim.new(0, CardGrid.Padding),
		PaddingLeft = UDim.new(0, CardGrid.Padding),
		PaddingRight = UDim.new(0, CardGrid.Padding),
		Parent = skeleton,
	})
	local skeletonLayout: UIGridLayout = make("UIGridLayout", {
		CellSize = UDim2.fromOffset(cell.X, cell.Y),
		CellPadding = UDim2.fromOffset(CardGrid.Gap.X, CardGrid.Gap.Y),
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		Parent = skeleton,
	})

	local function buildSkeleton()
		skeletonTrove:Clean()
		for i = 1, opts.skeletons or 6 do
			local tile = skeletonTrove:Add(make("Frame", {
				Name = "Skeleton" .. i,
				LayoutOrder = i,
				BackgroundColor3 = Style.Well,
				BackgroundTransparency = Style.WellTransparency,
				BorderSizePixel = 0,
				ZIndex = 4,
				Parent = skeleton,
			}))
			Arcade.corner(tile, 8)
			Arcade.outline(tile, "Button")
			local tileText = make("TextLabel", {
				Name = "Text",
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.new(1, -12, 0, 24),
				BackgroundTransparency = 1,
				FontFace = Tokens.font(),
				Text = opts.loadingText or "Loading cars",
				TextSize = Tokens.TextSize.Minimum,
				TextColor3 = Style.TextSoft,
				TextTruncate = Enum.TextTruncate.None,
				ZIndex = 5,
				Parent = tile,
			})
			Arcade.outline(tileText, "Minor")
		end
	end

	local function updateMode()
		local isEmpty = not loading and #cards == 0
		scroll.Visible = not loading and not isEmpty
		empty.Visible = isEmpty
		skeleton.Visible = loading
	end

	local function runRefresh()
		scheduled = false
		if destroyed or loading then
			return
		end
		local visibleCards: { CarCard.Card } = {}
		local selectedCard: CarCard.Card? = nil
		local shown = visibleChain(scroll)
		for _, card in cards do
			if shown and overlaps(card.root, scroll, card.root.AbsoluteSize.Y) then
				card:loadModel()
			end
			if shown and overlaps(card.root, scroll, 0) then
				table.insert(visibleCards, card)
				if card:car().id == selectedId then
					selectedCard = card
				end
			end
		end
		local spin: { [CarCard.Card]: boolean } = {}
		local count = 0
		if selectedCard then
			spin[selectedCard] = true
			count = 1
		end
		for _, card in visibleCards do
			if count >= maxSpinning then
				break
			end
			if not spin[card] then
				spin[card] = true
				count += 1
			end
		end
		for _, card in cards do
			card:setSpinning(spin[card] == true)
		end
	end

	local function schedule()
		if scheduled or destroyed then
			return
		end
		scheduled = true
		task.defer(runRefresh)
	end

	-- One header height for the whole grid: the largest line count any name needs at this cell width (2 unless a name
	-- cannot fit two lines at 16 px). A late or failed measurement leaves the cards as they are.
	local function harmonise()
		rhythmToken += 1
		local token = rhythmToken
		local names: { string } = {}
		for _, card in cards do
			table.insert(names, card:car().name)
		end
		local width = cell.X
		task.spawn(function()
			local most = 2
			for _, name in names do
				local solved = CarCard.solveName(name, width, 2)
				if destroyed or token ~= rhythmToken or solved == nil then
					return
				end
				most = math.max(most, solved.lines)
			end
			sharedLines = most
			for _, card in cards do
				card:setNameLines(most)
			end
		end)
	end

	trove:Connect(scroll:GetPropertyChangedSignal("CanvasPosition"), schedule)
	trove:Connect(scroll:GetPropertyChangedSignal("AbsoluteSize"), schedule)
	trove:Connect(scroll:GetPropertyChangedSignal("AbsolutePosition"), schedule)
	trove:Add(function()
		destroyed = true
	end)

	local grid: Grid
	grid = {
		root = root,
		scroll = scroll,
		setCars = function(self: Grid, cars_: { CarRef })
			-- the same cars in a new order (a sort): keep every card, its model and the selection; only reorder
			if #cars_ == #cards and #cards > 0 then
				local byCar: { [CarRef]: CarCard.Card } = {}
				for _, card in cards do
					byCar[card:car()] = card
				end
				local used: { [CarCard.Card]: boolean } = {}
				local reordered: { CarCard.Card } = {}
				for i, car in cars_ do
					local card = byCar[car]
					if card == nil or used[card] then
						break
					end
					used[card] = true
					card.root.LayoutOrder = i
					table.insert(reordered, card)
				end
				if #reordered == #cars_ then
					table.clear(cards)
					for _, card in reordered do
						table.insert(cards, card)
					end
					scroll.CanvasPosition = Vector2.zero
					schedule()
					return
				end
			end
			cardTrove:Clean()
			table.clear(cards)
			sharedLines = 2 -- the new list decides again (harmonise)
			for i, car in cars_ do
				local card = CarCard.new(scroll, car, {
					size = cell,
					lazy = true,
					spinning = false,
					nameLines = sharedLines,
					selected = car.id == selectedId,
					onActivate = function(c: CarRef)
						self:select(c.id)
						if opts.onSelect then
							opts.onSelect(c)
						end
					end,
				})
				card.root.LayoutOrder = i
				cardTrove:Add(function()
					card:destroy()
				end)
				table.insert(cards, card)
			end
			loading = false
			updateMode()
			scroll.CanvasPosition = Vector2.zero
			harmonise()
			schedule()
		end,
		setLoading = function(_self: Grid, on: boolean)
			loading = on
			if on then
				buildSkeleton()
			else
				skeletonTrove:Clean()
			end
			updateMode()
			schedule()
		end,
		setEmptyText = function(_self: Grid, text: string)
			emptyText.Text = text
		end,
		select = function(_self: Grid, id: string?)
			selectedId = id
			for _, card in cards do
				card:setSelected(card:car().id == id)
			end
			schedule()
		end,
		selected = function(_self: Grid): CarRef?
			for _, card in cards do
				if card:car().id == selectedId then
					return card:car()
				end
			end
			return nil
		end,
		setCell = function(_self: Grid, newCell: Vector2)
			if newCell == cell then
				return
			end
			cell = newCell
			gridLayout.CellSize = UDim2.fromOffset(cell.X, cell.Y)
			skeletonLayout.CellSize = UDim2.fromOffset(cell.X, cell.Y)
			sharedLines = 2 -- a new width may need fewer or more lines
			for _, card in cards do
				card:setNameLines(2)
				card:setSize(cell)
			end
			harmonise()
			schedule()
		end,
		cards = function(_self: Grid): { CarCard.Card }
			return table.clone(cards)
		end,
		firstBody = function(_self: Grid): GuiObject?
			local first = cards[1]
			return if first then first.body else nil
		end,
		refresh = function(_self: Grid)
			schedule()
		end,
		destroy = function(_self: Grid)
			if not destroyed then
				trove:Destroy()
			end
		end,
		getDebugState = function(_self: Grid): DebugState
			local built, spinning, active = 0, 0, 0
			local order: { string } = {}
			local headers: { number } = {}
			for _, card in cards do
				local s = card:getDebugState()
				table.insert(order, s.id)
				table.insert(headers, s.nameHeight)
				if s.hasModel then
					built += 1
				end
				if s.spinning then
					spinning += 1
				end
				if s.active then
					active += 1
				end
			end
			return {
				cards = #cards,
				built = built,
				spinning = spinning,
				active = active,
				loading = loading,
				empty = not loading and #cards == 0,
				selectedId = selectedId,
				cell = { cell.X, cell.Y },
				canvasY = scroll.CanvasPosition.Y,
				order = order,
				nameLines = sharedLines,
				headerHeights = headers,
			}
		end,
	}
	root.Parent = parent
	updateMode()
	return grid
end

return CardGrid
