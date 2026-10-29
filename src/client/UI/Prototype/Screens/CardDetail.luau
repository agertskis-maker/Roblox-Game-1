--!strict
-- CardDetail: the landscape detail view of one collectible card (Lane 3 preview, Round 3). Presentation only: it shows
-- the supplied car and card data and never grants, buys or equips anything.
--
--   local detail = CardDetail.new(ctx, { onDrive = function(car) end? })
--   detail:open(car, info?, returnTo?)   detail:close()   detail:isOpen()
--   detail:layout()   detail:setVisible(on)   detail:destroy()   detail:getDebugState()
--
--   local facts = CardDetail.Facts.new(parent, name?)       -- the six facts as a reusable panel (the Garage uses it)
--   facts:setCar(car, info?)   facts:layout(width, cardSize) -> contentHeight   facts:setSpinning(on)   facts:setVisible(on)
--   facts:card()   facts:getDebugState()   facts:destroy()
--
-- ROUND 3: THE SIX FACTS. The detail shows these and nothing else: (1) the car image, (2) its full name, (3) its full
-- rarity word (name and word are on the card, with the rarity pips), (4) the World where it is found, (5) its Lap Pay
-- per lap, (6) Gold, Chrome and Rainbow finishes, each clearly OWNED or NOT OWNED. No per-second figure, no Heat
-- capacity, no family or quirk words, no race stats, no flavour line, no number or date. The facts come from
-- TradingCard.detailFacts, so the same data gives the same words everywhere. An unowned car keeps its silhouette,
-- shows "?" for Lap Pay and NOT OWNED for every finish (nothing leaks). A finish whose state was not supplied shows "?".
-- A finish chip is a label and an icon, not a button: nothing here offers a purchase or an unlock.
--
-- Layout: the plain card (image, name, rarity word) on the left and the three rows on the right when the width allows
-- (stacked below the card otherwise), inside a SCROLLING area; a FIXED action bar underneath (BACK, DRIVE). The scrolling
-- area ends above the bar and clips its content, so nothing can scroll behind the buttons; the debug state reports the
-- gap. Back (Escape or gamepad B) and CLOSE close it; the gamepad selection starts on BACK and returns to where it was.

local Prototype = script.Parent.Parent
local Arcade = require(Prototype.Arcade)
local CarCard = require(Prototype.Cards.CarCard)
local Overlay = require(script.Parent.Overlay)
local Style = require(script.Parent.Style)
local TradingCard = require(Prototype.Cards.TradingCard)

local make = Arcade.make

local CardDetail = {}

export type Options = { onDrive: ((TradingCard.CarRef) -> ())? }

-- TOKEN CANDIDATE: the facts rows (design px).
local FINISH_LABEL_H = 24
local CAPTION_W = 84 -- the row captions (WORLD, LAP PAY) at 16 px
local WORLD_TAG_LEFT = 8 + CAPTION_W + 8 + 8 -- caption column, gaps and the right margin; the World tag takes the rest of the row
local STACK_CHIP_H = 36 -- a chip when the three are stacked: the name left, the state right
local COLUMN_GAP = 16 -- card to rows when side by side
local STACK_GAP = 12 -- card to rows when stacked
local SIDE_COLUMN = 300 -- the least width the rows need beside the card
local MIN_COLUMN = 318 -- three chips side by side need about 100 px each for NOT OWNED at 16 px; narrower, they stack

-- row height, chip height and the gap between rows (design px); `compact` is for a short phone frame
local function metrics(compact: boolean): (number, number, number)
	if compact then
		return 42, 50, 4
	end
	return 46, 54, 6
end
-- TOKEN CANDIDATE: finish chip fills (OWNED), the dark NOT OWNED fill and the "?" fill.
local FINISH_FILL: { [string]: ColorSequence } = {
	Gold = ColorSequence.new(Color3.fromRGB(255, 226, 120), Color3.fromRGB(214, 150, 20)),
	Chrome = ColorSequence.new(Color3.fromRGB(236, 241, 248), Color3.fromRGB(122, 136, 158)),
	Rainbow = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 96, 96)),
		ColorSequenceKeypoint.new(0.25, Color3.fromRGB(255, 200, 60)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(96, 214, 120)),
		ColorSequenceKeypoint.new(0.75, Color3.fromRGB(80, 156, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(186, 110, 255)),
	}),
}
local NOT_OWNED_FILL = Color3.fromRGB(26, 36, 78)
local UNKNOWN_FILL = Color3.fromRGB(52, 66, 116)
local WORLD_UNKNOWN_FILL = Color3.fromRGB(70, 82, 120)

CardDetail.FactKeys = table.freeze({ "Image", "Name", "Rarity", "World", "LapPay", "Finishes" })
CardDetail.RowLabels = table.freeze({ "WORLD", "LAP PAY", "FINISHES" })

local STATE_WORD: { [string]: string } = { Owned = "OWNED", NotOwned = "NOT OWNED", Unknown = "?" }

----------------------------------------------------------------------------------------------
-- The six-fact panel

local Facts = {}
Facts.__index = Facts
CardDetail.Facts = Facts

type Chip = { frame: Frame, fill: UIGradient, finish: TextLabel, state: TextLabel, check: Frame }

function Facts.new(parent: Instance, name: string?)
	local self = setmetatable({}, Facts)
	self._car = nil :: any
	self._info = nil :: any
	self._card = nil :: any
	self._spinning = false
	self._side = false
	self._across = true
	self._height = 0
	self._cardSize = Vector2.new(200, 280)
	self._width = 0
	local root: Frame = make("Frame", {
		Name = name or "SixFacts",
		BackgroundTransparency = 1,
		ZIndex = 4,
		Parent = parent,
	})
	self.root = root
	local rows: Frame = make("Frame", { Name = "Rows", BackgroundTransparency = 1, ZIndex = 5, Parent = root })
	self._rows = rows

	-- WORLD: a label on the left, the World name in a tag on the right
	local worldRow = Style.well(rows, "WorldRow", 6)
	self._worldRow = worldRow
	local worldCaption = Arcade.text(worldRow, {
		text = CardDetail.RowLabels[1],
		role = "Small",
		name = "Label",
		colour = Style.TextSoft,
		xAlign = Enum.TextXAlignment.Left,
		z = 8,
	})
	worldCaption.AnchorPoint = Vector2.new(0, 0.5)
	worldCaption.Position = UDim2.new(0, 8, 0.5, 0)
	worldCaption.Size = UDim2.fromOffset(CAPTION_W, 24)
	local worldTag: Frame = make("Frame", {
		Name = "WorldTag",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -8, 0.5, 0),
		-- fills the room right of the caption (never an AutomaticSize tag: its width came out a few px short of the text)
		Size = UDim2.new(1, -WORLD_TAG_LEFT, 0, 30),
		BackgroundColor3 = WORLD_UNKNOWN_FILL,
		BorderSizePixel = 0,
		ZIndex = 7,
		Parent = worldRow,
	})
	Arcade.corner(worldTag, 15)
	Arcade.outline(worldTag, "Minor")
	local worldValue = Arcade.text(worldTag, { text = "?", role = "Label", name = "Value", z = 9, outline = "Minor" })
	worldValue.Size = UDim2.fromScale(1, 1)
	self._worldTag, self._worldValue, self._worldCaption = worldTag, worldValue, worldCaption

	-- LAP PAY: a label on the left, "$220 / lap" (or "?") on the right
	local payRow = Style.well(rows, "LapPayRow", 6)
	self._payRow = payRow
	local payCaption = Arcade.text(payRow, {
		text = CardDetail.RowLabels[2],
		role = "Small",
		name = "Label",
		colour = Style.TextSoft,
		xAlign = Enum.TextXAlignment.Left,
		z = 8,
	})
	payCaption.AnchorPoint = Vector2.new(0, 0.5)
	payCaption.Position = UDim2.new(0, 8, 0.5, 0)
	payCaption.Size = UDim2.fromOffset(CAPTION_W, 24)
	local payValue = Arcade.text(payRow, {
		text = "?",
		role = "Value",
		name = "Value",
		size = 22,
		face = "Cash",
		italic = true,
		xAlign = Enum.TextXAlignment.Right,
		z = 8,
	})
	payValue.AnchorPoint = Vector2.new(1, 0.5)
	payValue.Position = UDim2.new(1, -6, 0.5, 0)
	self._payValue, self._payCaption = payValue, payCaption

	-- FINISHES: a label, then Gold, Chrome and Rainbow chips side by side
	local finishRow: Frame =
		make("Frame", { Name = "FinishRow", BackgroundTransparency = 1, ZIndex = 6, Parent = rows })
	self._finishRow = finishRow
	local finishCaption = Arcade.text(finishRow, {
		text = CardDetail.RowLabels[3],
		role = "Small",
		name = "Label",
		colour = Style.TextSoft,
		xAlign = Enum.TextXAlignment.Left,
		z = 8,
	})
	finishCaption.Position = UDim2.fromOffset(4, 0)
	finishCaption.Size = UDim2.new(1, -8, 0, FINISH_LABEL_H)
	self._finishCaption = finishCaption
	local chips: { Chip } = {}
	for _, finish in TradingCard.Finishes do
		local frame: Frame = make("Frame", {
			Name = "Chip_" .. finish,
			BackgroundColor3 = Color3.new(1, 1, 1),
			BorderSizePixel = 0,
			ZIndex = 7,
			Parent = finishRow,
		})
		Arcade.corner(frame, 6)
		Arcade.outline(frame, "Minor")
		local fill: UIGradient = make("UIGradient", { Rotation = 90, Parent = frame })
		local finishLabel = Arcade.text(frame, {
			text = string.upper(finish),
			role = "Small",
			name = "Finish",
			xAlign = Enum.TextXAlignment.Left,
			z = 8,
		})
		finishLabel.Position = UDim2.fromOffset(4, 3)
		finishLabel.Size = UDim2.new(1, -8, 0, 22)
		local stateLabel = Arcade.text(frame, {
			text = "?",
			role = "Small",
			name = "State",
			xAlign = Enum.TextXAlignment.Left,
			z = 8,
		})
		stateLabel.Position = UDim2.fromOffset(4, 28)
		stateLabel.Size = UDim2.new(1, -8, 0, 22)
		local check: Frame = make("Frame", {
			Name = "Check",
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -5, 0, 29),
			Size = UDim2.fromOffset(20, 20),
			BackgroundTransparency = 1,
			Visible = false,
			ZIndex = 9,
			Parent = frame,
		})
		Arcade.icon(check, "Check")
		table.insert(chips, { frame = frame, fill = fill, finish = finishLabel, state = stateLabel, check = check })
	end
	self._chips = chips
	self._states = { "Unknown", "Unknown", "Unknown" } :: { string }
	return self
end

export type FactsPanel = typeof(Facts.new(Instance.new("Folder")))

function Facts.card(self: FactsPanel): CarCard.Card?
	return self._card
end

function Facts.setCar(self: FactsPanel, car: TradingCard.CarRef, info: TradingCard.Info?)
	self._car = car
	self._info = info or {}
	local size = self._cardSize
	if self._card then
		-- the same car again (a sort, a relayout): keep the model and its turn
		if self._card:car() ~= car then
			self._card:setCar(car)
		end
	else
		self._card =
			CarCard.new(self.root, car, { plain = true, size = size, spinning = self._spinning, name = "DetailCar" })
	end
	local facts = TradingCard.detailFacts(car, self._info)
	-- World
	local world = TradingCard.Worlds[(self._info :: TradingCard.Info).world or ""]
	self._worldValue.Text = facts.world
	self._worldTag.BackgroundColor3 = if world then world.tag else WORLD_UNKNOWN_FILL
	-- Lap Pay
	self._payValue.Text = facts.lapPay
	-- Finishes
	for i, entry in facts.finishes do
		local chip = self._chips[i]
		local state: string = entry.state
		self._states[i] = state
		chip.state.Text = STATE_WORD[state]
		chip.check.Visible = state == "Owned"
		if state == "Owned" then
			chip.fill.Color = FINISH_FILL[entry.finish]
			chip.frame.BackgroundColor3 = Color3.new(1, 1, 1)
			chip.state.TextColor3 = Color3.new(1, 1, 1)
			chip.finish.TextColor3 = Color3.new(1, 1, 1)
		else
			local flat = if state == "NotOwned" then NOT_OWNED_FILL else UNKNOWN_FILL
			chip.fill.Color = ColorSequence.new(flat, flat)
			chip.state.TextColor3 = Style.TextSoft
			chip.finish.TextColor3 = Style.TextSoft
		end
	end
end

-- The height of the three rows for a rows column `colW` wide (the caller sizes the card from what is left).
function Facts.rowsHeight(colW: number, compact: boolean?): number
	local rowH, chipH, gap = metrics(compact == true)
	local chipsH = if colW >= MIN_COLUMN then chipH else 3 * STACK_CHIP_H + 2 * gap
	return rowH + gap + rowH + gap + FINISH_LABEL_H + chipsH
end

-- The card size and the row density for a scrolling area `innerW` wide and `scrollH` tall (design px): beside the card
-- when the rows keep their width (the card then takes the height there is), above the rows otherwise (the card takes
-- what the rows leave). Never smaller than the smallest card. Compact rows when the area is short (a phone frame).
function Facts.fit(innerW: number, scrollH: number): (Vector2, boolean)
	local compact = scrollH < 300
	local sideH = math.clamp(scrollH, CarCard.MinSize.Y, 340)
	local sideW = math.max(CarCard.MinSize.X, math.floor(sideH * 200 / 280))
	if innerW >= sideW + COLUMN_GAP + SIDE_COLUMN then
		return Vector2.new(sideW, sideH), compact
	end
	local stackH = math.clamp(scrollH - STACK_GAP - Facts.rowsHeight(innerW, compact), CarCard.MinSize.Y, 280)
	return Vector2.new(math.max(CarCard.MinSize.X, math.floor(stackH * 200 / 280)), stackH), compact
end

-- Places the card and the three rows for `width` (design px) and a card of `cardSize`; returns the content height.
-- Side by side when the rows keep SIDE_COLUMN beside the card, stacked (card centred, rows below) otherwise. The three
-- finish chips sit side by side in a column of MIN_COLUMN or more, stacked one above the other in a narrower one.
function Facts.layout(self: FactsPanel, width: number, cardSize: Vector2, compact: boolean?): number
	self._cardSize = cardSize
	self._width = width
	local card = self._card :: CarCard.Card?
	local side = width >= cardSize.X + COLUMN_GAP + SIDE_COLUMN
	self._side = side
	local rowH, chipH, gap = metrics(compact == true)
	local colX, colW
	if side then
		colX = cardSize.X + COLUMN_GAP
		colW = width - colX
	else
		colX, colW = 0, width
	end
	local rowsH = Facts.rowsHeight(colW, compact)
	local colY = if side then math.max(0, math.floor((cardSize.Y - rowsH) / 2)) else cardSize.Y + STACK_GAP
	if card then
		card:setSize(cardSize)
		card.root.AnchorPoint = Vector2.zero
		card.root.Position = UDim2.fromOffset(if side then 0 else math.floor((width - cardSize.X) / 2), 0)
	end
	local rows = self._rows :: Frame
	rows.Position = UDim2.fromOffset(colX, colY)
	rows.Size = UDim2.fromOffset(colW, rowsH)
	local worldRow, payRow, finishRow = self._worldRow :: Frame, self._payRow :: Frame, self._finishRow :: Frame
	local y = 0
	worldRow.Position = UDim2.fromOffset(0, y)
	worldRow.Size = UDim2.fromOffset(colW, rowH)
	y += rowH + gap
	payRow.Position = UDim2.fromOffset(0, y)
	payRow.Size = UDim2.fromOffset(colW, rowH)
	y += rowH + gap
	finishRow.Position = UDim2.fromOffset(0, y)
	finishRow.Size = UDim2.fromOffset(colW, rowsH - y)
	local across = colW >= MIN_COLUMN
	self._across = across
	local chipW = math.floor((colW - 12) / 3)
	for i, chip in self._chips do
		if across then
			chip.frame.Position = UDim2.fromOffset((i - 1) * (chipW + 6), FINISH_LABEL_H)
			chip.frame.Size = UDim2.fromOffset(chipW, chipH)
			chip.finish.Position = UDim2.fromOffset(4, 3)
			chip.finish.Size = UDim2.new(1, -8, 0, 22)
			chip.state.AnchorPoint = Vector2.zero
			chip.state.Position = UDim2.fromOffset(4, chipH - 26)
			chip.state.Size = UDim2.new(1, -8, 0, 22)
			chip.state.TextXAlignment = Enum.TextXAlignment.Left
			chip.check.Position = UDim2.new(1, -5, 0, chipH - 25)
		else
			chip.frame.Position = UDim2.fromOffset(0, FINISH_LABEL_H + (i - 1) * (STACK_CHIP_H + gap))
			chip.frame.Size = UDim2.fromOffset(colW, STACK_CHIP_H)
			chip.finish.Position = UDim2.fromOffset(8, 7)
			chip.finish.Size = UDim2.new(0.5, -8, 0, 22)
			chip.state.AnchorPoint = Vector2.new(1, 0)
			chip.state.Position = UDim2.new(1, -30, 0, 7)
			chip.state.Size = UDim2.new(0.5, -30, 0, 22)
			chip.state.TextXAlignment = Enum.TextXAlignment.Right
			chip.check.Position = UDim2.new(1, -5, 0, 8)
		end
	end
	local height = if side then math.max(cardSize.Y, colY + rowsH) else colY + rowsH
	self._height = height
	self.root.Size = UDim2.fromOffset(width, height)
	return height
end

function Facts.setSpinning(self: FactsPanel, on: boolean)
	self._spinning = on
	if self._card then
		self._card:setSpinning(on)
	end
end

function Facts.setVisible(self: FactsPanel, on: boolean)
	if self._card then
		self._card:setVisible(on)
		if not on then
			self._card:setSpinning(false)
		end
	end
end

function Facts.destroy(self: FactsPanel)
	if self._card then
		self._card:destroy()
		self._card = nil
	end
	self.root:Destroy()
end

function Facts.getDebugState(self: FactsPanel): { [string]: any }
	local cardState = if self._card then self._card:getDebugState() else nil
	local finishes = {}
	for i, chip in self._chips do
		table.insert(finishes, { finish = chip.finish.Text, state = chip.state.Text, kind = self._states[i] })
	end
	return {
		carId = if self._car then self._car.id else nil,
		side = self._side,
		across = self._across,
		width = self._width,
		height = self._height,
		-- the six facts, as the screen really shows them
		facts = {
			{ key = "Image", shown = if cardState then cardState.status else "none" },
			{ key = "Name", shown = if cardState then cardState.nameText else "" },
			{ key = "Rarity", shown = if cardState then cardState.rarityLabel else "" },
			{ key = "World", shown = self._worldValue.Text },
			{ key = "LapPay", shown = self._payValue.Text },
			{ key = "Finishes", shown = finishes },
		},
		rowLabels = {
			(self._worldCaption :: TextLabel).Text,
			(self._payCaption :: TextLabel).Text,
			(self._finishCaption :: TextLabel).Text,
		},
		card = cardState,
		instances = #self.root:GetDescendants(),
	}
end

----------------------------------------------------------------------------------------------
-- The full-screen detail

function CardDetail.new(ctx: Overlay.Ctx, options: Options?)
	local opts: Options = options or {}
	local overlay = Overlay.new(ctx, { name = "CardDetail" })
	local trove = overlay.trove
	local content = overlay.content
	local shell = Style.panel(content, { name = "Panel", z = 3 })
	local panel = shell.body
	local header =
		Style.header(panel, { fill = "Garage", title = "COLLECTIBLE CARD", icon = "GarageBook", height = 60 })
	local self: any = { root = overlay.root }
	local closeButton = Overlay.closeButton(panel, function()
		self:close()
	end)
	trove:Add(closeButton.trove)
	closeButton.root.AnchorPoint = Vector2.new(1, 0.5)
	closeButton.root.ZIndex = 12

	self._open = false
	self._car = nil :: any
	self._info = {} :: any
	self._drives = 0
	self._facts = nil :: any

	local well = Style.well(panel, "Details", 4)
	local scroll = Style.scroll(well, "Scroll", 5)
	make("UIPadding", {
		PaddingLeft = UDim.new(0, 8),
		PaddingRight = UDim.new(0, 12),
		PaddingTop = UDim.new(0, 8),
		PaddingBottom = UDim.new(0, 12),
		Parent = scroll,
	})
	local facts = Facts.new(scroll, "SixFacts")
	self._facts = facts
	trove:Add(function()
		facts:destroy()
	end)
	-- the FIXED action bar
	local bar: Frame = make("Frame", { Name = "Actions", BackgroundTransparency = 1, ZIndex = 8, Parent = panel })
	local backButton = Arcade.button(bar, {
		name = "Back",
		label = "BACK",
		fill = "Garage",
		size = "Custom",
		width = 160,
		height = 56,
		icon = "Close",
		sound = "Close",
		onActivate = function()
			self:close()
		end,
	})
	trove:Add(backButton.trove)
	backButton.root.AnchorPoint = Vector2.new(0, 0.5)
	backButton.root.Position = UDim2.fromScale(0, 0.5)
	backButton.root.ZIndex = 12
	local driveButton = Arcade.button(bar, {
		name = "Drive",
		label = "DRIVE",
		fill = "Retry",
		size = "Custom",
		width = 196,
		height = 56,
		pattern = true,
		cooldown = 0.6,
		onActivate = function()
			local car = self._car
			if car and car.owned ~= false and opts.onDrive then
				self._drives += 1
				opts.onDrive(car)
			end
		end,
	})
	trove:Add(driveButton.trove)
	driveButton.root.AnchorPoint = Vector2.new(1, 0.5)
	driveButton.root.Position = UDim2.fromScale(1, 0.5)
	driveButton.root.ZIndex = 12

	local function layoutNow()
		overlay:applyScale()
		local ds = overlay:designSize()
		local kind = Overlay.kindFor(ds)
		local short = kind ~= "Wide"
		local pw, ph
		if kind == "Wide" then
			pw, ph = math.min(ds.X - 32, 820), math.min(ds.Y - 24, 560)
		else
			pw, ph = ds.X - 24, ds.Y - 18
		end
		shell.root.Size = UDim2.fromOffset(pw, ph)
		shell.root.Position = UDim2.new(0.5, 0, 0.5, -2)
		local headH = if short then 50 else 60
		header.setHeight(headH)
		closeButton.root.Position = UDim2.new(1, -8, 0, headH / 2)
		local titleLeft = header.title.Position.X.Offset
		local rightUsed = Overlay.CloseWidth + 18
		header.title.AnchorPoint = Vector2.new(0, 0.5)
		header.title.Position = UDim2.new(0, titleLeft, 0.5, 0)
		header.title.Size = UDim2.new(1, -titleLeft - rightUsed, 0, if short then 28 else 36)
		local barH = if short then 62 else 72
		local bodyY = headH + 10
		local barY = ph - barH - 6
		local bodyH = barY - bodyY - 6
		well.Position = UDim2.fromOffset(10, bodyY)
		well.Size = UDim2.fromOffset(pw - 20, bodyH)
		scroll.Size = UDim2.fromScale(1, 1)
		-- the card takes the height the body allows (never narrower than the smallest card), the rows take the rest
		local innerW = pw - 20 - 8 - 12 - 8 -- the well, the scroll padding and the scroll bar
		local cardSize, compact = Facts.fit(innerW, bodyH - 20)
		facts:layout(innerW, cardSize, compact)
		bar.Position = UDim2.fromOffset(14, barY)
		bar.Size = UDim2.fromOffset(pw - 28, barH)
		backButton.root.Size = UDim2.fromOffset(if short then 140 else 160, 56)
	end

	overlay:setBack(function()
		self:close()
	end)
	trove:Connect(ctx.screen.Changed, function()
		layoutNow()
	end)

	function self.open(me: any, car: TradingCard.CarRef, info: TradingCard.Info?, returnTo: GuiObject?)
		me._car = car
		me._info = info or {}
		facts:setCar(car, me._info)
		layoutNow()
		facts:setSpinning(true)
		driveButton.setEnabled(car.owned ~= false)
		scroll.CanvasPosition = Vector2.zero
		overlay:open(backButton.body, returnTo)
		me._open = true
	end
	function self.close(me: any)
		if not overlay:isOpen() then
			return
		end
		facts:setSpinning(false)
		overlay:close()
		me._open = false
	end
	function self.isOpen(_me: any): boolean
		return overlay:isOpen()
	end
	function self.layout(_me: any)
		layoutNow()
	end
	function self.setVisible(_me: any, on: boolean)
		overlay.root.Visible = on and overlay:isOpen()
		facts:setVisible(on and overlay:isOpen())
	end
	function self.destroy(_me: any)
		overlay:destroy()
	end
	function self.getDebugState(me: any): { [string]: any }
		local scrollBottom = scroll.AbsolutePosition.Y + scroll.AbsoluteSize.Y
		local barTop = bar.AbsolutePosition.Y
		local factsState = facts:getDebugState()
		return {
			open = overlay:isOpen(),
			kind = overlay:kind(),
			carId = me._car and me._car.id,
			variant = "SixFacts",
			-- the labelled rows on screen: Name and Rarity (on the card), World, Lap Pay, Finishes
			rows = 2 + #factsState.rowLabels,
			rowLabels = factsState.rowLabels,
			facts = factsState.facts,
			side = factsState.side,
			bars = 0,
			canvasHeight = scroll.AbsoluteCanvasSize.Y,
			scrollHeight = scroll.AbsoluteSize.Y,
			-- the scrolling area must end above the fixed bar: nothing scrolls behind the buttons
			gapToBar = barTop - scrollBottom,
			scrollsBehindBar = scrollBottom > barTop + 0.5,
			drives = me._drives,
			driveEnabled = me._car ~= nil and me._car.owned ~= false,
			card = factsState.card,
			instances = #overlay.root:GetDescendants(),
		}
	end

	layoutNow()
	return self
end

return CardDetail
