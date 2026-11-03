--!strict
-- CardDetail: the landscape detail view of one collectible card (Lane 3 preview, Round 3, edition ladder Round 4).
-- Presentation only: it shows the supplied car and card data and never grants, buys or equips anything.
--
--   local detail = CardDetail.new(ctx, { onDrive = function(car) end? })
--   detail:open(car, info?, returnTo?)   detail:close()   detail:isOpen()
--   detail:layout()   detail:setVisible(on)   detail:destroy()   detail:getDebugState()
--
--   local facts = CardDetail.Facts.new(parent, name?)       -- the facts as a reusable panel (the Garage uses it)
--   facts:setCar(car, info?)   facts:layout(width, cardSize) -> contentHeight   facts:setSpinning(on)   facts:setVisible(on)
--   facts:card()   facts:getDebugState()   facts:destroy()
--
-- THE FACTS. (1) the car image, (2) its full name, (3) its full rarity word (name and word are on the card), (4) the World
-- where it is found, (5) its Lap Pay per lap, (6) the EDITION LADDER (Round 4, E-06; reference R4-IMG-01 and -02): the five
-- editions Normal, Gold, Diamond, Rainbow and Galaxy as badges in order, each with its word and a state word (reached ones lit
-- with a tick, the next one outlined with NEXT, later ones locked), a progress bar "12 / 25 copies to GOLD", one plain line on
-- how copies are earned, and the Lap Pay multiplier of the best edition reached ("x3 Lap Pay"). Rarity and edition stay
-- separate facts: an Epic car is Epic at every edition. The numbers are Brian L's economy v1 proposal (EconomyPreview,
-- PREVIEW); Galaxy's look is his to approve, so its badge is a placeholder marked PREVIEW. At Galaxy the bar reads "Top edition
-- reached!" (no invented sixth tier, no 0 / 25). An unowned car keeps its silhouette, shows "?" for Lap Pay and every edition
-- locked with "Claim this car first" (nothing leaks). A badge is a label, never a button: editions are earned, never sold.
--
-- Look (Round 2 N7-02): the one panel family (Screens/PanelKit): a light card, the Garage-blue header with the icon and the
-- outlined title, a red square X, light rows with navy captions. The car card and the edition badges keep their own colours.
--
-- Layout: the plain card (image, name, rarity word) on the left and the rows on the right when the width allows (stacked
-- below the card otherwise), inside a SCROLLING area; a FIXED action bar underneath (BACK, DRIVE). The five badges sit in one
-- row in a column of LADDER_ACROSS or more and in two rows (three, then two) in a narrower one, so a phone keeps readable
-- 16 px words instead of five squeezed ones. Back (Escape or gamepad B) and CLOSE close it.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Prototype = script.Parent.Parent
local Arcade = require(Prototype.Arcade)
local CarCard = require(Prototype.Cards.CarCard)
local Overlay = require(script.Parent.Overlay)
local PanelKit = require(script.Parent.PanelKit)
local Style = require(script.Parent.Style)
local TradingCard = require(Prototype.Cards.TradingCard)
local EconomyPreview = require(ReplicatedStorage.Shared.UI.EconomyPreview)
local Tokens = require(ReplicatedStorage.Shared.UI.Tokens)

local make = Arcade.make

local CardDetail = {}

export type Options = { onDrive: ((TradingCard.CarRef) -> ())? }

-- TOKEN CANDIDATE: the facts rows (design px).
local LADDER_LABEL_H = 24
local CAPTION_W = 84 -- the row captions (WORLD, LAP PAY) at 16 px
local WORLD_TAG_LEFT = 8 + CAPTION_W + 8 + 8 -- caption column, gaps and the right margin; the World tag takes the rest of the row
local COLUMN_GAP = 16 -- card to rows when side by side
local STACK_GAP = 12 -- card to rows when stacked
local SIDE_COLUMN = 300 -- the least width the rows need beside the card
local LADDER_ACROSS = 440 -- five badges in one row need about 86 px each for RAINBOW at 16 px; narrower, three then two
local BAR_H = 28
local EARN_H = 22

-- row height, badge height and the gap between rows (design px); `compact` is for a short phone frame
local function metrics(compact: boolean): (number, number, number)
	if compact then
		return 36, 44, 4
	end
	return 46, 52, 6
end
-- a short phone frame: WORLD and LAP PAY share one row when the column is this wide, so the copies bar shows without scrolling
local PAIR_MIN = 480
local function paired(colW: number, compact: boolean?): boolean
	return compact == true and colW >= PAIR_MIN
end
local LOCKED_FILL = Color3.fromRGB(26, 36, 78)
local WORLD_UNKNOWN_FILL = Color3.fromRGB(70, 82, 120)
local BAR_TRACK = Color3.fromRGB(26, 36, 78)
local INK = Color3.fromRGB(20, 27, 51)

CardDetail.FactKeys = table.freeze({ "Image", "Name", "Rarity", "World", "LapPay", "Editions" })
CardDetail.RowLabels = table.freeze({ "WORLD", "LAP PAY", "EDITIONS" })

local STATE_WORD: { [string]: string } = { Reached = "GOT IT", Next = "NEXT", Locked = "LOCKED" }

----------------------------------------------------------------------------------------------
-- The facts panel

local Facts = {}
Facts.__index = Facts
CardDetail.Facts = Facts

type Badge = { frame: Frame, stroke: UIStroke, word: TextLabel, state: TextLabel, check: Frame }

local function starry(frame: Frame)
	-- Galaxy's placeholder look: small stars on deep purple, and a small PREVIEW tag (Brian L approves the real one)
	for i, at in { Vector2.new(0.14, 0.3), Vector2.new(0.86, 0.3), Vector2.new(0.8, 0.78), Vector2.new(0.2, 0.82) } do
		make("Frame", {
			Name = "Star" .. i,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(at.X, at.Y),
			Size = UDim2.fromOffset(4, 4),
			Rotation = 45,
			BackgroundColor3 = Color3.fromRGB(236, 224, 255),
			BorderSizePixel = 0,
			ZIndex = 8,
			Parent = frame,
		})
	end
	local tag: Frame = make("Frame", {
		Name = "PreviewTag",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, 2, 0, 0),
		Size = UDim2.fromOffset(58, 16),
		BackgroundColor3 = INK,
		BorderSizePixel = 0,
		ZIndex = 10,
		Parent = frame,
	})
	Arcade.corner(tag, 8)
	local text = Arcade.text(tag, { text = "PREVIEW", role = "Small", name = "Text", z = 11 })
	text.TextSize = 11
	text.Size = UDim2.fromScale(1, 1)
end

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
	local worldRow = PanelKit.row(rows, "WorldRow", 6)
	self._worldRow = worldRow
	local worldCaption = Arcade.text(worldRow, {
		text = CardDetail.RowLabels[1],
		role = "Small",
		name = "Label",
		xAlign = Enum.TextXAlignment.Left,
		z = 8,
	})
	PanelKit.ink(worldCaption, true)
	worldCaption.AnchorPoint = Vector2.new(0, 0.5)
	worldCaption.Position = UDim2.new(0, 8, 0.5, 0)
	worldCaption.Size = UDim2.fromOffset(CAPTION_W, 24)
	local worldTag: Frame = make("Frame", {
		Name = "WorldTag",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -8, 0.5, 0),
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

	-- LAP PAY: a label on the left, "$6,000 / lap" (or "?") on the right
	local payRow = PanelKit.row(rows, "LapPayRow", 6)
	self._payRow = payRow
	local payCaption = Arcade.text(payRow, {
		text = CardDetail.RowLabels[2],
		role = "Small",
		name = "Label",
		xAlign = Enum.TextXAlignment.Left,
		z = 8,
	})
	PanelKit.ink(payCaption, true)
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

	-- EDITIONS: a caption with the best edition's multiplier, five badges, the bar, the earn line
	local ladder: Frame =
		make("Frame", { Name = "EditionLadder", BackgroundTransparency = 1, ZIndex = 6, Parent = rows })
	self._ladder = ladder
	local caption = Arcade.text(ladder, {
		text = CardDetail.RowLabels[3],
		role = "Small",
		name = "Label",
		xAlign = Enum.TextXAlignment.Left,
		z = 8,
	})
	PanelKit.ink(caption, true)
	caption.Position = UDim2.fromOffset(4, 0)
	caption.Size = UDim2.new(0.5, -4, 0, LADDER_LABEL_H)
	self._ladderCaption = caption
	local boost = Arcade.text(ladder, {
		text = "",
		role = "Small",
		name = "Boost",
		xAlign = Enum.TextXAlignment.Right,
		z = 8,
	})
	PanelKit.ink(boost)
	boost.AnchorPoint = Vector2.new(1, 0)
	boost.Position = UDim2.new(1, -4, 0, 0)
	boost.Size = UDim2.new(0.5, -4, 0, LADDER_LABEL_H)
	self._boost = boost
	local badges: { Badge } = {}
	for _, edition in EconomyPreview.Editions do
		local frame: Frame = make("Frame", {
			Name = "Badge_" .. edition.key,
			BackgroundColor3 = LOCKED_FILL,
			BorderSizePixel = 0,
			ZIndex = 7,
			Parent = ladder,
		})
		Arcade.corner(frame, 8)
		local stroke = Arcade.outline(frame, "Minor")
		local word =
			Arcade.text(frame, { text = edition.label, role = "Small", name = "Word", z = 8, outline = "Minor" })
		word.Position = UDim2.fromOffset(4, 3)
		word.Size = UDim2.new(1, -8, 0, 22)
		local state = Arcade.text(frame, { text = "LOCKED", role = "Small", name = "State", z = 8 })
		state.Size = UDim2.new(1, -8, 0, 20)
		local check: Frame = make("Frame", {
			Name = "Check",
			AnchorPoint = Vector2.new(1, 1),
			Position = UDim2.new(1, -3, 1, -3),
			Size = UDim2.fromOffset(16, 16),
			BackgroundTransparency = 1,
			Visible = false,
			ZIndex = 9,
			Parent = frame,
		})
		Arcade.icon(check, "Check")
		if edition.preview then
			starry(frame)
		end
		table.insert(badges, { frame = frame, stroke = stroke, word = word, state = state, check = check })
	end
	self._badges = badges
	self._states = { "Locked", "Locked", "Locked", "Locked", "Locked" } :: { string }
	-- the progress bar toward the next edition
	local track: Frame = make("Frame", {
		Name = "CopiesBar",
		BackgroundColor3 = BAR_TRACK,
		BorderSizePixel = 0,
		ZIndex = 7,
		ClipsDescendants = true,
		Parent = ladder,
	})
	Arcade.corner(track, 8)
	Arcade.outline(track, "Minor")
	local fill: Frame = make("Frame", {
		Name = "Fill",
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = Color3.fromRGB(246, 190, 40),
		BorderSizePixel = 0,
		ZIndex = 8,
		Parent = track,
	})
	Arcade.corner(fill, 8)
	local barText = Arcade.text(track, { text = "", role = "Small", name = "Text", z = 9, outline = "Minor" })
	barText.Size = UDim2.fromScale(1, 1)
	self._track, self._fill, self._barText = track, fill, barText
	local earn = Arcade.text(ladder, {
		text = EconomyPreview.EarnLine,
		role = "Small",
		name = "EarnLine",
		xAlign = Enum.TextXAlignment.Left,
		z = 8,
	})
	PanelKit.ink(earn, true)
	self._earn = earn
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
	local data = self._info :: any
	local facts = TradingCard.detailFacts(car, data)
	-- World
	local world = TradingCard.Worlds[data.world or ""]
	self._worldValue.Text = facts.world
	self._worldTag.BackgroundColor3 = if world then world.tag else WORLD_UNKNOWN_FILL
	-- Lap Pay
	self._payValue.Text = facts.lapPay
	-- Editions: reached, the next one, locked; all locked for a car the player does not own
	local owned = not facts.hidden and data.edition ~= nil
	local progress = EconomyPreview.editionProgress(data.edition, data.copies)
	for i, badge in self._badges do
		local edition = EconomyPreview.Editions[i]
		local nextIndex = if progress.nextEdition then progress.nextEdition.index else 0
		local state = if not owned
			then "Locked"
			elseif i <= progress.edition.index then "Reached"
			elseif i == nextIndex then "Next"
			else "Locked"
		self._states[i] = state
		badge.state.Text = STATE_WORD[state]
		badge.check.Visible = state == "Reached"
		badge.frame.BackgroundColor3 = if state == "Reached" then edition.colour else LOCKED_FILL
		badge.stroke.Color = if state == "Next" then edition.colour else INK
		badge.stroke.Thickness = if state == "Next" then 3 else 2
		badge.word.TextColor3 = if state == "Locked" then Style.TextSoft else Color3.new(1, 1, 1)
		badge.state.TextColor3 = if state == "Locked"
			then Style.TextSoft
			elseif state == "Next" then edition.colour
			else Color3.new(1, 1, 1)
	end
	if owned then
		self._boost.Text = "x" .. progress.edition.multiplier .. " Lap Pay"
		self._fill.Size = UDim2.fromScale(progress.fraction, 1)
		self._fill.BackgroundColor3 = if progress.nextEdition
			then progress.nextEdition.colour
			else progress.edition.colour
		self._barText.Text = progress.text
		self._earn.Text = if progress.nextEdition
			then EconomyPreview.EarnLine
			else "This car has every edition. Amazing!"
	else
		self._boost.Text = ""
		self._fill.Size = UDim2.fromScale(0, 1)
		self._barText.Text = "Claim this car first"
		self._earn.Text = "Fill the Keys on this car in a run to claim it."
	end
end

-- The height of the rows for a rows column `colW` wide (the caller sizes the card from what is left).
function Facts.rowsHeight(colW: number, compact: boolean?): number
	local rowH, badgeH, gap = metrics(compact == true)
	local badgesH = if colW >= LADDER_ACROSS then badgeH else 2 * badgeH + gap
	local infoH = if paired(colW, compact) then rowH + gap else rowH + gap + rowH + gap
	return infoH + LADDER_LABEL_H + badgesH + gap + BAR_H + gap + EARN_H
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

-- Places the card and the rows for `width` (design px) and a card of `cardSize`; returns the content height.
function Facts.layout(self: FactsPanel, width: number, cardSize: Vector2, compact: boolean?): number
	self._cardSize = cardSize
	self._width = width
	local card = self._card :: CarCard.Card?
	local side = width >= cardSize.X + COLUMN_GAP + SIDE_COLUMN
	self._side = side
	local rowH, badgeH, gap = metrics(compact == true)
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
	local worldRow, payRow, ladder = self._worldRow :: Frame, self._payRow :: Frame, self._ladder :: Frame
	local y = 0
	if paired(colW, compact) then
		local half = math.floor((colW - 6) / 2)
		worldRow.Position = UDim2.fromOffset(0, y)
		worldRow.Size = UDim2.fromOffset(half, rowH)
		payRow.Position = UDim2.fromOffset(colW - half, y)
		payRow.Size = UDim2.fromOffset(half, rowH)
	else
		worldRow.Position = UDim2.fromOffset(0, y)
		worldRow.Size = UDim2.fromOffset(colW, rowH)
		y += rowH + gap
		payRow.Position = UDim2.fromOffset(0, y)
		payRow.Size = UDim2.fromOffset(colW, rowH)
	end
	y += rowH + gap
	ladder.Position = UDim2.fromOffset(0, y)
	ladder.Size = UDim2.fromOffset(colW, rowsH - y)
	local across = colW >= LADDER_ACROSS
	self._across = across
	local perRow = if across then 5 else 3
	local badgeW = math.floor((colW - (perRow - 1) * 6) / perRow)
	for i, badge in self._badges do
		local slot = (i - 1) % perRow
		local line = (i - 1) // perRow
		badge.frame.Position = UDim2.fromOffset(slot * (badgeW + 6), LADDER_LABEL_H + line * (badgeH + gap))
		badge.frame.Size = UDim2.fromOffset(badgeW, badgeH)
		badge.state.Position = UDim2.fromOffset(4, badgeH - 23)
	end
	local below = LADDER_LABEL_H + (if across then badgeH else 2 * badgeH + gap) + gap
	local track = self._track :: Frame
	track.Position = UDim2.fromOffset(0, below)
	track.Size = UDim2.fromOffset(colW, BAR_H)
	local earn = self._earn :: TextLabel
	earn.Position = UDim2.fromOffset(4, below + BAR_H + gap)
	earn.Size = UDim2.fromOffset(colW - 8, EARN_H)
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
	local editions = {}
	for i, badge in self._badges do
		table.insert(editions, { edition = badge.word.Text, state = badge.state.Text, kind = self._states[i] })
	end
	return {
		carId = if self._car then self._car.id else nil,
		side = self._side,
		across = self._across,
		width = self._width,
		height = self._height,
		facts = {
			{ key = "Image", shown = if cardState then cardState.status else "none" },
			{ key = "Name", shown = if cardState then cardState.nameText else "" },
			{ key = "Rarity", shown = if cardState then cardState.rarityLabel else "" },
			{ key = "World", shown = self._worldValue.Text },
			{ key = "LapPay", shown = self._payValue.Text },
			{ key = "Editions", shown = editions },
		},
		progress = self._barText.Text,
		boost = self._boost.Text,
		earnLine = self._earn.Text,
		rowLabels = {
			(self._worldCaption :: TextLabel).Text,
			(self._payCaption :: TextLabel).Text,
			(self._ladderCaption :: TextLabel).Text,
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
	local shell = PanelKit.panel(content, { name = "Panel", z = 3 })
	local panel = shell.body
	local header =
		Style.header(panel, { fill = "Garage", title = "COLLECTIBLE CARD", icon = "GarageBook", height = 60 })
	local self: any = { root = overlay.root }
	local closeButton = PanelKit.closeX(panel, function()
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

	local well = PanelKit.row(panel, "Details", 4, "Alt")
	local scroll = Style.scroll(well, "Scroll", 5)
	scroll.ScrollBarImageColor3 = PanelKit.InkSoft
	scroll.ScrollBarImageTransparency = 0.1
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
		local rightUsed = Tokens.Touch.Minimum + 18
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
