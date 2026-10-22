--!strict
-- CardGrid: a scrolling grid of CarCards (Lane 3 HUD prototype, PREVIEW only).
--
--   local grid = CardGrid.new(parent, { cell = Vector2.new(200, 280), onSelect = fn })
--   grid.root                      -- a Frame; size and place it like any frame
--   grid:setCars(cars)             -- {} shows the empty message
--   grid:setLoading(true)          -- grey skeleton tiles with "Loading cars..."
--   grid:setEmptyText(text)
--   grid:select(id?)               -- marks one card selected (ring + lift), nil clears
--   grid:setCell(Vector2)          -- re-lays out every card (models kept)
--   grid:refresh()                 -- re-checks what is on screen (call after showing the grid)
--   grid:getDebugState()           -- { cards, built, spinning, ... }
--
-- Performance rules: cards are created lazily (no model) and a card's proxy is built only when
-- the card comes within one row of the visible area, once. At most `maxSpinning` (default 6)
-- cards spin: the selected card first if it is visible, then the visible cards in order; all
-- others stay at the static 3/4 angle. The CarCard ticker additionally pauses anything that is
-- off screen or hidden.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Prototype = script.Parent.Parent
local CarCard = require(script.Parent.CarCard)
local Gloss = require(Prototype.Gloss)
local Icons = require(Prototype.Icons)
local PreviewTokens = require(Prototype.PreviewTokens)
local Tokens = require(ReplicatedStorage.Shared.UI.Tokens)
local Trove = require(ReplicatedStorage.Packages.Trove)

local C = PreviewTokens.Color
local make = Gloss.make

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
	cell: Vector2,
	canvasY: number,
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
		ScrollBarImageColor3 = C.Ink,
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
		Size = UDim2.new(1, -32, 0, 120),
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
	Icons.draw(emptyIcon, "Car", Color3.fromRGB(190, 196, 210))
	local emptyText = make("TextLabel", {
		Name = "Text",
		Position = UDim2.fromOffset(0, 60),
		Size = UDim2.new(1, 0, 0, 56),
		BackgroundTransparency = 1,
		FontFace = Tokens.font(),
		Text = opts.emptyText or "No cars here yet",
		TextSize = Tokens.TextSize.Label,
		TextWrapped = true,
		TextColor3 = C.InkSoft,
		ZIndex = 4,
		Parent = empty,
	})

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
				BackgroundColor3 = Color3.fromRGB(226, 220, 206),
				BorderSizePixel = 0,
				ZIndex = 4,
				Parent = skeleton,
			}))
			Gloss.corner(tile, 16)
			local stroke = Gloss.stroke(tile, 3)
			stroke.Transparency = 0.6
			make("TextLabel", {
				Name = "Text",
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.new(1, -12, 0, 24),
				BackgroundTransparency = 1,
				FontFace = Tokens.font(),
				Text = opts.loadingText or ("Loading cars" .. CarCard.Ellipsis),
				TextSize = Tokens.TextSize.Minimum,
				TextColor3 = C.InkSoft,
				TextTruncate = Enum.TextTruncate.AtEnd,
				ZIndex = 5,
				Parent = tile,
			})
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
			cardTrove:Clean()
			table.clear(cards)
			for i, car in cars_ do
				local card = CarCard.new(scroll, car, {
					size = cell,
					lazy = true,
					spinning = false,
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
			for _, card in cards do
				card:setSize(cell)
			end
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
			for _, card in cards do
				local s = card:getDebugState()
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
				cell = cell,
				canvasY = scroll.CanvasPosition.Y,
			}
		end,
	}
	root.Parent = parent
	updateMode()
	return grid
end

return CardGrid
