--!strict
-- GarageMock: the Garage as a collection INDEX, drawn over gameplay (Lane 3 HUD prototype, PREVIEW only; no ownership,
-- purchase or save logic). ROUND 2 (N10, reference B's Index): a World rail (Downtown, Dusty Highway, Summit Pass), a grid
-- of large car cards (owned in full colour, not owned as a true dark silhouette with ??? and its rarity frame, nothing
-- about it leaked), a completion bar for the open World, a compact completion reward box with CLAIM, CLAIM ALL in the
-- header, "Unlocked X / Y" in the header, and a detail panel for the chosen car with the PUT ON RACEWAY action.
--
--   local garage = GarageMock.new(ctx, { onDrive = function(car) end, onClose = fn?, cars = list?, infoOf = fn?, acquired = map?,
--                                        canPutOnRaceway = fn?, onPreviewClaim = fn?, detailExtras = boolean?, onCustomize = fn? })
--   garage:open(returnTo?)  garage:close()  garage:isOpen()
--   garage:selectTab("Downtown" | "Dusty" | "Summit")
--   garage:selectCar(id)    -- also opens the detail page on a phone (and switches to the car's World)
--   garage:setSort("Rarest" | "LapPay" | "Newest" | nil)   garage:getSort()   -- nil = the collection order
--   garage:setSource(cars?, infoOf?, acquired?)   -- replace the listed collection (nil = the preview fixtures)
--   garage:setLoading(on)   -- the loading case for the current World
--   garage:claimWorld(tab) -> boolean   garage:claimAll() -> number   garage:getRewardState(tab) -> string   -- the session-only preview claims
--   garage:layout()  garage:setVisible(on)  garage:destroy()  garage:getDebugState()
--
-- ONE SOURCE. Every number on this screen comes from the one collection list: the grid, each World's "5 / 10", the bar
-- above the grid, the reward states and the header's "Unlocked 5 / 10" are counted from the same cars. A car counts once
-- (its base id; a Gold / Chrome / Rainbow finish is not another car) and counts as owned when any listed entry of it is
-- owned. A car is in the World its supplied info names (info.world); a car with no World named is listed under Downtown.
-- A World with no cars is EMPTY (Dusty Highway in this mock, "No cars yet"); Summit Pass has NO DATA (no cars of it are supplied)
-- and reads "Not available yet", never a permanent "Loading...". While any World is loading or unavailable, the total reads
-- "10+" (never an invented total), such a World shows no reward, and nothing is ever marked COMPLETE from a World with unknown
-- data: the green tick on a World button means a COMPLETE World and nothing else (the open World wears a white arrow instead).
--
-- REWARDS ARE PREVIEW PROPOSALS (Brian L decides the real ones). States per World: Incomplete (collect N more), Ready
-- (complete, CLAIM works), Claimed (this session only, shown as CLAIMED) and Unavailable (loading or empty). CLAIM and
-- CLAIM ALL only flip that session flag, in World order, once per World per session; they grant nothing and call no remote.
-- options.onPreviewClaim(tab, amount) lets a harness log a claim; it must never be wired to a real grant. The "PREVIEW" label
-- on the reward box is a harness caption (attribute PreviewCaption), so it is not child-facing text.
--
-- PUT ON RACEWAY uses the existing lineup adapter options.onDrive(car). It is enabled only for an owned car whose art
-- exists while the adapter is present and options.canPutOnRaceway (when given: (car) -> (ok, reason?)) says yes. Otherwise the
-- button stays visible, disabled, with a plain reason line under it ("Find this car first to use it", "Not available yet").
-- A press never fakes a result: the screen only calls the adapter.
--
-- DETAIL. The six-fact panel (Screens/CardDetail.Facts): image, full name, full rarity word, World, Lap Pay, the three
-- finishes owned or not. The Family quirk and Race stats rows exist only when options.detailExtras is true, and then only from
-- supplied data (info.quirk, info.raceStats = { { label, value } }); anything not supplied reads "Not available yet". They
-- are off by default so the detail stays the six facts. On a phone the detail is its own page with BACK.
--
-- SORT (Round 3): RAREST (Legendary .. Common; then name A to Z, then id), LAP PAY (the supplied per-lap number, highest
-- first) and NEWEST (the supplied acquisition number, newest first). A car with no supplied number is always last, in the
-- collection order; ties keep the collection order. The sort works on a COPY: the collection array and the catalog are
-- never touched. The active sort shows by text AND shape (selected tab fill, thick boundary, underline, check mark) and a status
-- line ("Rarest first", "Collection order"). Tap the active sort again to go back to the collection order. On a phone the
-- three buttons become one button that steps through them. The sort is local state; it is not saved.
-- Back (Escape / gamepad B): closes the phone detail page first, then the Garage.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Prototype = script.Parent.Parent
local Arcade = require(Prototype.Arcade)
local CardDetail = require(script.Parent.CardDetail)
local CardGrid = require(Prototype.Cards.CardGrid)
local CarCard = require(Prototype.Cards.CarCard)
local Fixtures = require(Prototype.Fixtures)
local Format = require(ReplicatedStorage.Shared.UI.Format)
local RidePick = require(Prototype.RidePick)
local IconArt = require(Prototype.Home.IconArt)
local Motion = require(Prototype.Motion)
local Overlay = require(script.Parent.Overlay)
local PanelKit = require(script.Parent.PanelKit)
local PreviewTokens = require(Prototype.PreviewTokens)
local Sounds = require(Prototype.Sounds)
local Style = require(script.Parent.Style)
local SupportKit = require(script.Parent.SupportKit)
local Tokens = require(ReplicatedStorage.Shared.UI.Tokens)
local TradingCard = require(Prototype.Cards.TradingCard)

local A = PreviewTokens.Arcade
local make = Arcade.make
local Facts = CardDetail.Facts

local GarageMock = {}

-- TOKEN CANDIDATES (design px): sort buttons (the row height is the touch minimum; the width is clamped around the free room).
local SORT_H = 48
local SORT_MIN_W = 104
local SORT_MAX_W = 168
local SORT_GAP = 8
-- the header: CLAIM ALL and the "Unlocked" chip sit left of the red X, and CUSTOMIZE left of those
local CLAIM_ALL_W = 132
local CUSTOMIZE_W = 150
local CHIP_W_WIDE = 190
local CHIP_W_SHORT = 124
-- the reward box under the grid (Wide) and the bar under the detail (PUT ON RACEWAY + its reason line)
local REWARD_H = 64
local COMPLETION_H = 30
local ACTION_H = 100
local DRIVE_W = 236
local CLAIM_W = 118
local BACK_W = 130
-- the right column on a phone: sort button over the reward box
local COLUMN_W = 150
local STRIP_H = 48
-- the grid's own padding and scroll bar take 36 px of its width (CardGrid.Padding twice + the 8 px bar)
local GRID_INSET = 36
local HIDDEN_NAME = "???"
-- A car the player does not own has no Lap Pay and no acquisition number for the sort (see the header). One switch.
local LAP_SORT_HIDES_UNOWNED = true

export type CarRef = CarCard.CarRef
export type Tab = "Downtown" | "Dusty" | "Summit"
export type SortMode = CardGrid.SortMode

export type Options = {
	onDrive: ((CarRef) -> ())?, -- the lineup adapter: put this car on the Raceway
	onRide: ((CarRef) -> ())?, -- Round 7 (U-02): ride this car in runs (the launch card's car)
	ridingId: (() -> string?)?, -- the car picked for runs now
	onClose: (() -> ())?,
	cars: { CarRef }?, -- the collection to list (default: the synthetic Downtown fixtures); read only, never sorted in place
	infoOf: ((CarRef) -> TradingCard.Info?)?, -- supplied per-car data: Lap Pay, World, finishes (default: the preview data)
	acquired: { [string]: number }?, -- supplied acquisition number per car id, larger = newer (for NEWEST)
	canPutOnRaceway: ((CarRef) -> (boolean, string?))?, -- the adapter's verdict (lineup full, ...): ok, and a plain reason when not
	onPreviewClaim: ((Tab, number) -> ())?, -- a harness hook for a session-only preview claim; never a grant
	detailExtras: boolean?, -- show the Family quirk and Race stats rows (supplied data only; "Not available yet" otherwise)
	onCustomize: (() -> ())?, -- opens paint, decals and wheels; the button shows only when this is given
}

export type SortButtonState = {
	id: string,
	active: boolean,
	checkVisible: boolean,
	underlineVisible: boolean,
	text: string,
	visible: boolean,
}

export type WorldState = {
	id: string,
	owned: number,
	total: number,
	state: string, -- "Ready" | "Empty" | "Loading" | "Unavailable"
	reward: string, -- "Incomplete" | "Ready" | "Claimed" | "Unavailable"
	selected: boolean,
	count: string, -- the text on the World button
}

export type DebugState = {
	open: boolean,
	kind: string,
	tab: Tab,
	selectedId: string?,
	detailOpen: boolean,
	collection: string, -- the header's "Unlocked 5 / 10"
	driveEnabled: boolean,
	driveVisible: boolean,
	driveCalls: number,
	driveReason: string, -- the line under the disabled action ("" when it is enabled)
	sort: string, -- "Rarest" | "LapPay" | "Newest" | "None"
	sortStatus: string,
	sortForm: string, -- "Row" (three buttons) | "Cycle" (one button, phone)
	sortButtons: { SortButtonState },
	sortCycle: SortButtonState,
	order: { string }, -- the car ids in the order the cards are laid out
	sourceCount: number,
	grid: CardGrid.DebugState,
	detailCard: CarCard.DebugState?,
	facts: { [string]: any }?,
	detailGapToBar: number, -- the facts scroll area's bottom to the top of the action bar (never negative)
	detailScrolls: boolean, -- the facts content is taller than its scroll area
	worlds: { WorldState },
	unlocked: { owned: number, total: number, known: boolean },
	completion: string, -- the bar above the grid
	rewardState: string, -- the open World's reward state
	rewardLine: string,
	claimEnabled: boolean,
	claimAllEnabled: boolean,
	claimAllLabel: string,
	eligible: number, -- Worlds whose reward CLAIM ALL would take
	previewClaims: number, -- claims made this session
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
	claimWorld: (self: Garage, tab: Tab) -> boolean,
	claimAll: (self: Garage) -> number,
	getRewardState: (self: Garage, tab: Tab) -> string,
	destroy: (self: Garage) -> (),
	getDebugState: (self: Garage) -> DebugState,
}

type WorldDef = { id: Tab, key: string, long: string, short: string, emptyAs: string }

-- The Worlds, in the order the rail lists them. `key` is the World name the supplied card info uses (TradingCard.Worlds).
-- Dusty Highway is the EMPTY case of this mock; Summit Pass is the case with NO DATA at all, which reads "Not available yet"
-- (review fix: a World whose cars are never supplied must not sit on "Loading..." for good).
local WORLDS: { WorldDef } = {
	{ id = "Downtown", key = "Downtown", long = "Downtown", short = "Downtown", emptyAs = "Empty" },
	{ id = "Dusty", key = "DustyHighway", long = "Dusty Highway", short = "Dusty Hwy", emptyAs = "Empty" },
	{ id = "Summit", key = "SummitPass", long = "Summit Pass", short = "Summit", emptyAs = "Unavailable" },
}

-- What a World with no data says, longest first: the first that fits its box wins (never "Loading..." for good).
local UNAVAILABLE_WORDS = { "Not available yet", "Not available", "Not yet" }

-- PREVIEW completion rewards, in dollars: made-up numbers for the reward box, not an economy rule (Brian L decides).
GarageMock.PreviewRewards = table.freeze({
	Downtown = 500,
	Dusty = 1500,
	Summit = 4000,
}) :: { [string]: number }

local SORTS: { { id: SortMode, label: string, status: string } } = {
	{ id = "Rarest", label = "RAREST", status = "Rarest first" },
	{ id = "LapPay", label = "LAP PAY", status = "Highest Lap Pay first" },
	{ id = "Newest", label = "NEWEST", status = "Newest first" },
}
local NO_SORT_STATUS = "Collection order"

-- SYNTHETIC preview acquisition numbers (larger = newer), for NEWEST in the playground. The real number is the player's own
-- collection data; NEWEST never reads the array position or an asset time. Cars without an entry have no date.
GarageMock.PreviewAcquired = table.freeze({
	Putter = 1,
	["Pizza Runner"] = 2,
	Rustbucket = 3,
	Minnow = 4,
	Bolt = 5,
	["Old Faithful"] = 6,
	["Surf Wagon"] = 7,
	Executive = 8,
	["Beach Bug"] = 9,
	Commuter = 10,
}) :: { [string]: number }

-- The collection the Garage lists by default (Round 4): all 27 real cars from the one roster, nine per World, each at its best
-- edition from the example collection (Fixtures.PreviewCollection). One car is marked unseen for the NEW tag.
function GarageMock.downtownCars(): { CarRef }
	local list: { CarRef } = {}
	for _, c in Fixtures.Cars do
		local copy = table.clone(c)
		copy.unseen = copy.id == "Executive"
		table.insert(list, copy)
	end
	return list
end

-- "puglet-gold" -> "puglet" (the id convention the fixtures use for a finish of the same car)
local function baseOf(id: string): string
	return (string.gsub(id, "%-.*$", ""))
end

local function worldColour(def: WorldDef): Color3
	local world = TradingCard.Worlds[def.key]
	return if world then world.tag else Color3.fromRGB(80, 140, 230)
end

type WorldStats = { id: Tab, cars: { CarRef }, total: number, owned: number, state: string }

type WorldButton = {
	id: Tab,
	root: TextButton,
	stroke: UIStroke,
	name: TextLabel,
	count: TextLabel,
	emblem: Frame,
	barTrack: Frame,
	barFill: Frame,
	barGradient: UIGradient,
	check: Frame, -- the green tick: a COMPLETE World, never merely the open one
	chevron: Frame, -- the open World's white arrow (the same corner slot as the tick)
}

function GarageMock.new(ctx: Overlay.Ctx, options: Options?): Garage
	local opts: Options = options or {}
	local tab: Tab = "Downtown"
	local selected: CarRef? = nil
	local selectionByTab: { [string]: CarRef } = {} -- what each World had selected (a World switch never loses it)
	local detailOpen = false
	local driveCalls = 0
	local driveEnabled = false
	local driveReason = ""
	local loadingOverride = false
	local source: { CarRef } = opts.cars or GarageMock.downtownCars()
	local customInfo = opts.infoOf
	local acquired: { [string]: number } = opts.acquired
		or (if opts.cars == nil then GarageMock.PreviewAcquired else {})
	local sortMode: SortMode? = nil
	local sortForm = "Row"
	local claimed: { [string]: boolean } = {} -- the session-only preview claims
	local previewClaims = 0
	local stats: { [string]: WorldStats } = {}
	local shown: { [CarRef]: CarRef } = {} -- the ??? copy of each car the player does not own (stable, so cards are reused)
	local narrowReward = false
	local compactHeader = false -- a phone header has room for "5 / 10" only
	local garage: Garage

	local overlay = Overlay.new(ctx, { name = "GarageMock" })
	local trove = overlay.trove
	local content = overlay.content

	local shell = Style.panel(content, { name = "Panel", z = 3 })
	local panel = shell.body

	---------------------------------------------------------------------------------------------
	-- header: icon + title, the Unlocked chip, CLAIM ALL, the red X
	---------------------------------------------------------------------------------------------

	local header = Style.header(panel, { fill = "Garage", title = "GARAGE INDEX", icon = "Garage" })
	if header.icon then
		IconArt.draw(header.icon, { "Index", "GarageBook", "Garage" })
	end
	local countChip = Style.well(panel, "Collection", 12)
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
	local countText = Style.text(countChip, "Unlocked 0 / 0", "Label", {
		name = "Count",
		size = 20,
		xAlign = Enum.TextXAlignment.Center,
		z = 13,
	})
	countText.AnchorPoint = Vector2.new(0, 0.5)
	countText.Position = UDim2.new(0, 40, 0.5, 0)
	countText.Size = UDim2.new(1, -44, 0, 30)
	local claimAllButton = Arcade.button(panel, {
		name = "ClaimAll",
		label = "CLAIM ALL",
		fill = "Green",
		size = "Custom",
		width = CLAIM_ALL_W,
		height = Tokens.Touch.Minimum,
		cooldown = 0.5,
		onActivate = function()
			garage:claimAll()
		end,
	})
	trove:Add(claimAllButton.trove)
	claimAllButton.root.ZIndex = 12
	local customizeButton: any = nil
	if opts.onCustomize then
		customizeButton = Arcade.button(panel, {
			name = "Customize",
			label = "CUSTOMIZE",
			fill = "Rainbow",
			size = "Custom",
			width = CUSTOMIZE_W,
			height = Tokens.Touch.Minimum,
			cooldown = 0.5,
			onActivate = function()
				if opts.onCustomize then
					opts.onCustomize()
				end
			end,
		})
		trove:Add(customizeButton.trove)
		customizeButton.root.ZIndex = 12
	end
	local closeX = PanelKit.closeX(panel, function()
		garage:close()
	end)
	trove:Add(closeX.trove)
	closeX.root.ZIndex = 12

	---------------------------------------------------------------------------------------------
	-- the World rail (a horizontal strip on a phone)
	---------------------------------------------------------------------------------------------

	local worldButtons: { WorldButton } = {}
	for i, def in WORLDS do
		local colour = worldColour(def)
		local root: TextButton = trove:Add(make("TextButton", {
			Name = "Tab_" .. def.id,
			LayoutOrder = i,
			BackgroundColor3 = Color3.new(1, 1, 1),
			AutoButtonColor = false,
			Text = "",
			Selectable = true,
			ZIndex = 6,
			Parent = panel,
		}))
		Arcade.corner(root, 10)
		local stroke = Arcade.outline(root, "Button")
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border -- a button's outline is drawn round its edge, not round its (empty) text
		make("UIGradient", {
			Color = ColorSequence.new(colour:Lerp(Color3.new(1, 1, 1), 0.3), colour:Lerp(Color3.new(0, 0, 0), 0.3)),
			Rotation = 90,
			Parent = root,
		})
		local emblem: Frame = make("Frame", {
			Name = "Emblem",
			BackgroundColor3 = colour:Lerp(Color3.new(0, 0, 0), 0.4),
			BorderSizePixel = 0,
			ZIndex = 8,
			Parent = root,
		})
		make("UICorner", { CornerRadius = UDim.new(0.5, 0), Parent = emblem })
		Arcade.outline(emblem, "Minor")
		local emblemIcon: Frame = make("Frame", {
			Name = "Icon",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0.68, 0.68),
			BackgroundTransparency = 1,
			ZIndex = 9,
			Parent = emblem,
		})
		IconArt.draw(emblemIcon, { "Portal", "Flag" })
		local name = Style.text(root, def.long, "Label", { name = "Name", size = 20, z = 8 })
		local count = Style.text(root, "0 / 0", "Label", { name = "Count", size = 20, z = 8 })
		local barTrack: Frame = make("Frame", {
			Name = "Bar",
			BackgroundColor3 = A.Ink,
			BackgroundTransparency = 0.25,
			BorderSizePixel = 0,
			ZIndex = 8,
			Parent = root,
		})
		Arcade.corner(barTrack, 5)
		local barFill: Frame = make("Frame", {
			Name = "Fill",
			BackgroundColor3 = Color3.new(1, 1, 1),
			BorderSizePixel = 0,
			Size = UDim2.fromScale(0, 1),
			ZIndex = 9,
			Parent = barTrack,
		})
		Arcade.corner(barFill, 5)
		local barGradient: UIGradient = make("UIGradient", { Color = A.Fill.Green, Rotation = 90, Parent = barFill })
		-- the corner slot has two marks, and the green tick is NOT the selected mark (it said a 6 / 10 World was done): the
		-- tick means a COMPLETE World; the open World wears a white arrow (and the thick white boundary), so the state is not
		-- colour alone
		local check: Frame = make("Frame", {
			Name = "Check",
			Size = UDim2.fromOffset(24, 24),
			BackgroundTransparency = 1,
			Visible = false,
			ZIndex = 10,
			Parent = root,
		})
		Arcade.icon(check, "Check")
		local chevron: Frame = make("Frame", {
			Name = "OpenMark",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Size = UDim2.fromOffset(24, 24),
			BackgroundTransparency = 1,
			Rotation = 180, -- the family has one arrow (Back); turned round it points on into the World
			Visible = false,
			ZIndex = 10,
			Parent = root,
		})
		IconArt.draw(chevron, { "Back" })
		PanelKit.interact(root, trove, 10, Color3.new(1, 1, 1))
		trove:Connect(root.Activated, function()
			Sounds.play("Tap")
			garage:selectTab(def.id)
		end)
		table.insert(worldButtons, {
			id = def.id,
			root = root,
			stroke = stroke,
			name = name,
			count = count,
			emblem = emblem,
			barTrack = barTrack,
			barFill = barFill,
			barGradient = barGradient,
			check = check,
			chevron = chevron,
		})
	end

	---------------------------------------------------------------------------------------------
	-- sort controls: a row of three buttons, or one button that steps through them (phone)
	---------------------------------------------------------------------------------------------

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

	---------------------------------------------------------------------------------------------
	-- the open World: its completion bar, the grid, the reward box
	---------------------------------------------------------------------------------------------

	local completion, setCompletion = Overlay.progress(panel, "Green", 6)
	completion.Name = "Completion"
	local completionGradient = (completion:FindFirstChild("Fill") :: Frame):FindFirstChildOfClass(
			"UIGradient"
		) :: UIGradient

	local gridHolder = Style.well(panel, "GridHolder", 4)
	gridHolder.ClipsDescendants = true
	local grid = CardGrid.new(gridHolder, {
		cell = Vector2.new(150, 210),
		onSelect = function(car: CarRef)
			garage:selectCar(car.id)
		end,
	})
	trove:Add(function()
		grid:destroy()
	end)

	-- above the sort tab (z 6) on a phone, where the box sits right under it, so its PREVIEW tag over the top edge is never hidden
	local rewardBox = Style.well(panel, "RewardBox", 7)
	local rewardStroke = rewardBox:FindFirstChildOfClass("UIStroke") :: UIStroke
	local rewardIcon: Frame = make("Frame", {
		Name = "Icon",
		BackgroundTransparency = 1,
		ZIndex = 8,
		Parent = rewardBox,
	})
	IconArt.draw(rewardIcon, { "Cash", "Coin" })
	local rewardAmount = Arcade.text(rewardBox, {
		text = "",
		role = "Value",
		name = "Amount",
		size = 26,
		face = "Cash",
		italic = true,
		xAlign = Enum.TextXAlignment.Left,
		z = 8,
	})
	local rewardLine = Style.text(rewardBox, "", "Small", {
		name = "Line",
		colour = Style.TextSoft,
		xAlign = Enum.TextXAlignment.Left,
		z = 8,
	})
	local claimButton = Arcade.button(rewardBox, {
		name = "Claim",
		label = "CLAIM",
		fill = "Green",
		size = "Custom",
		width = CLAIM_W,
		height = Tokens.Touch.Minimum,
		cooldown = 0.5,
		onActivate = function()
			garage:claimWorld(tab)
		end,
	})
	trove:Add(claimButton.trove)
	claimButton.root.ZIndex = 9
	-- the PREVIEW labels are harness captions (not child-facing words): one over the reward box's top edge (the reward amount is a
	-- made-up proposal), one over the detail's top edge (Lap Pay is a fixture) and one over the World rail (the counts are a
	-- fixture). They show with the harness captions on, never hidden under a neighbour (see their z and places in layoutNow).
	local previewStamp = Style.stamp(rewardBox, "PREVIEW", "Gold", 9)
	previewStamp.frame.Position = UDim2.fromOffset(8, -12)
	previewStamp.frame:SetAttribute("PreviewCaption", true)
	-- a child of the first World button, so it goes with the rail (or the phone's strip) whenever that is hidden
	local countStamp = Style.stamp(worldButtons[1].root, "PREVIEW", "Gold", 16)
	countStamp.frame.Name = "CountsPreview"
	countStamp.frame.Position = UDim2.fromOffset(8, -12)
	countStamp.frame:SetAttribute("PreviewCaption", true)

	---------------------------------------------------------------------------------------------
	-- the detail (a light card) and its action bar
	---------------------------------------------------------------------------------------------

	local detail = PanelKit.row(panel, "Detail", 6, "Alt")
	-- Lap Pay (and the other numbers in the facts) are fixtures here: a harness caption over the detail's top edge
	local lapStamp = Style.stamp(detail, "PREVIEW", "Gold", 12)
	lapStamp.frame.Name = "LapPayPreview"
	lapStamp.frame.AnchorPoint = Vector2.new(1, 0)
	lapStamp.frame.Position = UDim2.new(1, -8, 0, -12)
	lapStamp.frame:SetAttribute("PreviewCaption", true)
	local detailEmpty =
		Overlay.text(detail, "Pick a car to see it here", 18, PanelKit.InkSoft, Enum.TextXAlignment.Center, 7)
	PanelKit.ink(detailEmpty, true)
	local detailScroll = Style.scroll(detail, "FactsScroll", 7)
	detailScroll.ScrollBarImageColor3 = PanelKit.InkSoft
	detailScroll.ScrollBarImageTransparency = 0.1
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

	-- Family quirk and Race stats (options.detailExtras only): rows from supplied data, "Not available yet" otherwise
	local extras: Frame? = nil
	if opts.detailExtras == true then
		local frame: Frame = make("Frame", {
			Name = "Extras",
			BackgroundTransparency = 1,
			AutomaticSize = Enum.AutomaticSize.Y,
			Size = UDim2.fromOffset(100, 0),
			ZIndex = 5,
			Parent = detailScroll,
		})
		make("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = frame })
		extras = frame
	end

	local actionBar: Frame = make("Frame", { Name = "Actions", BackgroundTransparency = 1, ZIndex = 8, Parent = panel })
	local driveButton = Arcade.button(actionBar, {
		name = "Drive",
		label = "PARK", -- Round 5 (L-04): opens YOUR RACEWAY with this car picked out
		fill = "Green",
		size = "Custom",
		width = DRIVE_W,
		height = Tokens.Touch.Primary,
		cooldown = 0.6,
		onActivate = function()
			local car = selected
			if driveEnabled and car and opts.onDrive then
				driveCalls += 1
				opts.onDrive(car)
			end
		end,
	})
	trove:Add(driveButton.trove)
	driveButton.root.ZIndex = 12
	-- Round 7 (U-02, Adam: "I want some kind of confirmation of what car I'm choosing"): RIDE THIS CAR picks the car for runs and
	-- answers with a green check, "Ready to ride: <name>!" and a glow round the card
	local confirm: TextLabel = make("TextLabel", {
		Name = "RideConfirm",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 10),
		Size = UDim2.fromOffset(340, 44),
		BackgroundColor3 = Color3.fromRGB(46, 180, 80),
		FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json"),
		TextScaled = true,
		TextColor3 = Color3.new(1, 1, 1),
		Visible = false,
		ZIndex = 40,
		Parent = panel,
	})
	make("UICorner", { CornerRadius = UDim.new(1, 0), Parent = confirm })
	make("UIStroke", {
		Thickness = 3,
		Color = Color3.fromRGB(10, 60, 24),
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = confirm,
	})
	make("UIPadding", {
		PaddingTop = UDim.new(0, 6),
		PaddingBottom = UDim.new(0, 6),
		PaddingLeft = UDim.new(0, 12),
		PaddingRight = UDim.new(0, 12),
		Parent = confirm,
	})
	local confirmSerial = 0
	local refreshRide: () -> () = function() end
	local rideButton = Arcade.button(actionBar, {
		name = "Ride",
		label = "RIDE THIS CAR",
		fill = "Gold",
		size = "Custom",
		width = DRIVE_W,
		height = Tokens.Touch.Primary,
		cooldown = 0.6,
		onActivate = function()
			local car = selected
			if not (car and car.owned == true and car.model ~= nil and opts.onRide) then
				return
			end
			opts.onRide(car)
			confirmSerial += 1
			local serial = confirmSerial
			-- Round 8 (C-03): the server saves the pick (it checks the car is yours); the client only asks. The confirmation waits for
			-- the server's answer (review D8); a no shows a short red line instead.
			RidePick.ask(car.id, function(ok: boolean, reason: string?)
				if confirmSerial ~= serial or not confirm.Parent then
					return
				end
				if not ok then
					confirm.Text = "✖ " .. string.upper(reason or "Try again.")
					confirm.BackgroundColor3 = Color3.fromRGB(196, 52, 44)
					confirm.Visible = true
					refreshRide()
					task.delay(2.5, function()
						if confirmSerial == serial then
							confirm.Visible = false
						end
					end)
					return
				end
				confirm.Text = "✔ READY TO RIDE: " .. string.upper(car.name or car.id)
				confirm.BackgroundColor3 = Color3.fromRGB(46, 180, 80)
				confirm.Visible = true
				local cardRef = facts:card()
				local glow: UIStroke? = nil
				if cardRef then
					glow = make("UIStroke", {
						Name = "RideGlow",
						Thickness = 6,
						Color = Color3.fromRGB(90, 255, 120),
						ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
						Parent = cardRef.root,
					})
				end
				refreshRide()
				task.delay(2.5, function()
					if glow then
						glow:Destroy()
					end
					if confirmSerial == serial then
						confirm.Visible = false
					end
				end)
			end)
		end,
	})
	trove:Add(rideButton.trove)
	rideButton.root.ZIndex = 12
	refreshRide = function()
		local car = selected
		local can = car ~= nil and car.owned == true and car.model ~= nil and opts.onRide ~= nil
		local riding = car ~= nil and opts.ridingId ~= nil and opts.ridingId() == car.id
		rideButton.root.Visible = car ~= nil and opts.onRide ~= nil
		rideButton.setEnabled(can and not riding)
		if rideButton.setLabel then
			rideButton.setLabel(if riding then "RIDING ✔" else "RIDE THIS CAR")
		end
	end
	local backButton = Arcade.button(actionBar, {
		name = "Back",
		label = "BACK",
		fill = "Garage",
		size = "Custom",
		width = BACK_W,
		height = Tokens.Touch.Minimum,
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
	-- the bar sits on the dark panel (under the light detail on Wide, beside it on a phone): white outlined words
	local reasonLabel =
		Style.text(actionBar, "", "Small", { name = "Reason", z = 9, fit = false, colour = Style.TextSoft })
	reasonLabel.TextWrapped = true
	reasonLabel.TextSize = Tokens.TextSize.Minimum
	reasonLabel.TextYAlignment = Enum.TextYAlignment.Center
	reasonLabel.TextXAlignment = Enum.TextXAlignment.Center

	---------------------------------------------------------------------------------------------
	-- data: the supplied per-car info, the finishes from the collection, the sort keys, the Worlds
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

	-- the World a car belongs to: the supplied info's World; a car with none named is listed under Downtown
	local function worldIdOf(car: CarRef): Tab
		local key = infoFor(car).world
		for _, def in WORLDS do
			if def.key == key then
				return def.id
			end
		end
		return "Downtown"
	end

	-- counts every World from the one source list (a car once, by its base id; owned when any entry of it is owned)
	local function rebuildStats()
		local byTab: { [string]: WorldStats } = {}
		local bases: { [string]: { [string]: boolean } } = {}
		for _, def in WORLDS do
			byTab[def.id] = { id = def.id, cars = {}, total = 0, owned = 0, state = "Ready" }
			bases[def.id] = {}
		end
		for _, car in source do
			local id = worldIdOf(car)
			table.insert(byTab[id].cars, car)
			local base = baseOf(car.id)
			local seen = bases[id][base]
			if seen == nil then
				bases[id][base] = car.owned == true
			elseif car.owned == true then
				bases[id][base] = true
			end
		end
		for _, def in WORLDS do
			local entry = byTab[def.id]
			for _, owned in bases[def.id] do
				entry.total += 1
				if owned then
					entry.owned += 1
				end
			end
			if #entry.cars == 0 then
				entry.state = def.emptyAs
			end
		end
		stats = byTab
	end

	local function statsOf(id: string): WorldStats
		return stats[id]
	end

	local function defOf(id: string): WorldDef
		for _, def in WORLDS do
			if def.id == id then
				return def
			end
		end
		return WORLDS[1]
	end

	local function unlockedTotals(): (number, number, boolean)
		local owned, total, known = 0, 0, true
		for _, def in WORLDS do
			local st = statsOf(def.id)
			owned += st.owned
			total += st.total
			if st.state == "Loading" or st.state == "Unavailable" then
				known = false -- a World with unknown data: the total is "10+", never an invented number
			end
		end
		return owned, total, known
	end

	local function rewardStateOf(id: string): string
		local st = statsOf(id)
		if claimed[id] then
			return "Claimed"
		end
		if st.state ~= "Ready" or st.total == 0 then
			return "Unavailable"
		end
		if st.owned >= st.total then
			return "Ready"
		end
		return "Incomplete"
	end

	local function eligibleCount(): number
		local n = 0
		for _, def in WORLDS do
			if rewardStateOf(def.id) == "Ready" then
				n += 1
			end
		end
		return n
	end

	-- the cars of the open World, sorted (a copy), each unowned car as its ??? copy
	local function shownFor(car: CarRef): CarRef
		if car.owned == true then
			return car
		end
		local cached = shown[car]
		if cached == nil then
			cached = table.clone(car)
			cached.name = HIDDEN_NAME
			shown[car] = cached
		end
		return cached
	end

	local function displayed(): { CarRef }
		local sorted = CardGrid.sortCars(statsOf(tab).cars, sortMode, { lapPay = lapPayOf, acquired = acquiredOf })
		local out: { CarRef } = {}
		for _, car in sorted do
			table.insert(out, shownFor(car))
		end
		return out
	end

	---------------------------------------------------------------------------------------------
	-- state to screen
	---------------------------------------------------------------------------------------------

	local function rewardLineText(id: string): string
		local st = statsOf(id)
		local state = rewardStateOf(id)
		if state == "Claimed" then
			return if narrowReward then "Claimed!" else "Claimed this session"
		elseif state == "Ready" then
			return if narrowReward then "All found!" else "All cars found. Claim it!"
		elseif state == "Incomplete" then
			local missing = st.total - st.owned
			if narrowReward then
				return string.format("%d more to go", missing)
			end
			return string.format("Find %d more %s to claim", missing, if missing == 1 then "car" else "cars")
		elseif st.state == "Loading" then
			return "Loading..."
		elseif st.state == "Unavailable" then
			return if narrowReward then "Not available" else "Not available yet"
		end
		return if narrowReward then "No cars yet" else "No cars here yet"
	end

	-- the count on a World button: "6 / 10", or (no data) the longest "not available" wording that fits the label's width
	local function countTextOf(id: string, room: number): string
		local st = statsOf(id)
		if st.state == "Loading" then
			return "Loading..."
		elseif st.state == "Unavailable" then
			for _, words in UNAVAILABLE_WORDS do
				if SupportKit.measure(words, Tokens.TextSize.Minimum).X * 1.12 + 6 <= room then
					return words
				end
			end
			return UNAVAILABLE_WORDS[#UNAVAILABLE_WORDS]
		end
		return string.format("%d / %d", st.owned, st.total)
	end

	-- a COMPLETE World: its cars are known, there is at least one, and the player has every one
	local function isComplete(st: WorldStats): boolean
		return st.state == "Ready" and st.total > 0 and st.owned >= st.total
	end

	local function refreshRewards()
		local state = rewardStateOf(tab)
		local amount = GarageMock.PreviewRewards[tab] or 0
		rewardAmount.Text = if state == "Unavailable" then "-" else Format.cash(amount)
		rewardLine.Text = rewardLineText(tab)
		local ready = state == "Ready"
		claimButton.setEnabled(ready)
		claimButton.setLabel(if state == "Claimed" then "CLAIMED" else "CLAIM")
		rewardStroke.Color = if ready or state == "Claimed" then PreviewTokens.Color.Success else A.Ink
		rewardStroke.Thickness = if ready then 4 else A.OutlineMinor
		local n = eligibleCount()
		claimAllButton.setLabel(if n > 0 then string.format("CLAIM ALL (%d)", n) else "CLAIM ALL")
		claimAllButton.setEnabled(n > 0)
	end

	local function refreshWorlds()
		local owned, total, known = unlockedTotals()
		countText.Text = string.format(
			"%s%d / %d%s",
			if compactHeader then "" else "Unlocked ",
			owned,
			total,
			if known then "" else "+"
		)
		for _, wb in worldButtons do
			local st = statsOf(wb.id)
			local on = wb.id == tab
			wb.stroke.Color = if on then Color3.new(1, 1, 1) else A.Ink
			wb.stroke.Thickness = if on then 5 else A.OutlineButton
			-- one corner slot: the green tick for a COMPLETE World, else the white arrow on the open one
			local complete = isComplete(st)
			wb.check.Visible = complete
			wb.chevron.Visible = on and not complete
			wb.count.Text = countTextOf(wb.id, wb.count.Size.X.Offset)
			local fraction = if st.state == "Ready" and st.total > 0 then st.owned / st.total else 0
			wb.barFill.Size = UDim2.fromScale(fraction, 1)
			wb.barFill.Visible = fraction > 0
			wb.barGradient.Color = if fraction >= 1 then A.Fill.Gold else A.Fill.Green
		end
		-- the bar above the grid, for the open World
		local def = defOf(tab)
		local st = statsOf(tab)
		if st.state == "Loading" then
			setCompletion(0, def.long .. ": Loading...")
			completionGradient.Color = A.Fill.Green
		elseif st.state == "Unavailable" then
			setCompletion(0, def.long .. ": Not available yet")
			completionGradient.Color = A.Fill.Green
		elseif st.total == 0 then
			setCompletion(0, def.long .. ": No cars yet")
			completionGradient.Color = A.Fill.Green
		elseif st.owned >= st.total then
			setCompletion(1, def.long .. ": COMPLETE!")
			completionGradient.Color = A.Fill.Gold
		else
			setCompletion(st.owned / st.total, string.format("%s: %d / %d", def.long, st.owned, st.total))
			completionGradient.Color = A.Fill.Green
		end
		refreshRewards()
	end

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

	-- why PUT ON RACEWAY cannot be pressed (nil = it can)
	local function driveVerdict(): (boolean, string)
		local car = selected
		if car == nil then
			return false, ""
		end
		if car.owned ~= true then
			return false, "Find this car first to use it"
		end
		if car.model == nil or opts.onDrive == nil then
			return false, "Not available yet"
		end
		local gate = opts.canPutOnRaceway
		if gate then
			local ok, reason = gate(car)
			if not ok then
				return false, reason or "Not available right now"
			end
		end
		return true, ""
	end

	local function addExtraRow(frame: Frame, order: number, caption: string, value: string)
		local row = PanelKit.row(frame, "ExtraRow", 6)
		row.LayoutOrder = order
		row.Size = UDim2.new(1, 0, 0, 44)
		local cap = PanelKit.ink(Style.text(row, caption, "Small", { name = "Label", z = 8 }), true)
		cap.Position = UDim2.fromOffset(6, 0)
		cap.Size = UDim2.new(0.42, -8, 1, 0)
		local val =
			PanelKit.ink(Style.text(row, value, "Label", { name = "Value", z = 8, xAlign = Enum.TextXAlignment.Right }))
		val.AnchorPoint = Vector2.new(1, 0)
		val.Position = UDim2.new(1, -6, 0, 0)
		val.Size = UDim2.new(0.58, -8, 1, 0)
	end

	-- the extra rows for the chosen car: supplied data only (info.quirk, info.raceStats); a car not owned shows "?" (no leak)
	local function updateExtras(car: CarRef, info: TradingCard.Info)
		local frame = extras
		if not frame then
			return
		end
		for _, child in frame:GetChildren() do
			if child:IsA("Frame") then
				child:Destroy()
			end
		end
		local hidden = car.owned ~= true
		local data = info :: any
		local quirk = if hidden then "?" elseif type(data.quirk) == "string" then data.quirk else "Not available yet"
		addExtraRow(frame, 1, "FAMILY QUIRK", quirk)
		local list = if type(data.raceStats) == "table" then data.raceStats else nil
		if hidden or list == nil or #list == 0 then
			addExtraRow(frame, 2, "RACE STATS", if hidden then "?" else "Not available yet")
		else
			for i, stat in list do
				if i > 3 then
					break
				end
				addExtraRow(frame, 1 + i, string.upper(tostring(stat.label)), tostring(stat.value))
			end
		end
	end

	local function updateDetail()
		local car = selected
		facts.root.Visible = car ~= nil
		detailScroll.Visible = car ~= nil
		detailEmpty.Visible = car == nil
		if not car then
			facts:setVisible(false)
			driveEnabled = false
			driveReason = ""
			driveButton.root.Visible = false
			reasonLabel.Visible = false
			refreshRide()
			return
		end
		local info = infoFor(car)
		facts:setCar(car, info)
		updateExtras(car, info)
		facts:setVisible(overlay:isOpen())
		local ok, reason = driveVerdict()
		driveEnabled = ok
		driveReason = reason
		driveButton.root.Visible = true
		driveButton.setEnabled(ok)
		reasonLabel.Text = reason
		reasonLabel.Visible = reason ~= ""
		refreshRide()
	end

	local function setSelected(car: CarRef?)
		selected = car
		if car ~= nil then
			selectionByTab[tab] = car
		end
	end

	local function applyTab()
		rebuildStats()
		local st = statsOf(tab)
		if loadingOverride or st.state == "Loading" then
			grid:setLoading(true)
			selected = nil
		elseif #st.cars == 0 then
			grid:setEmptyText(
				if st.state == "Unavailable"
					then defOf(tab).long .. " is not available yet."
					elseif tab == "Downtown" then "No cars here yet. Find some on the road!"
					else "No "
						.. defOf(tab).long
						.. " cars yet. Open the "
						.. defOf(tab).long
						.. " portal to start collecting!"
			)
			grid:setCars({})
			selected = nil
		else
			grid:setLoading(false) -- a World that was loading leaves its skeleton behind, whatever cards the grid still holds
			grid:setCars(displayed())
			local keep: CarRef? = selectionByTab[tab]
			if keep and not table.find(st.cars, keep) then
				keep = nil
			end
			if not keep then
				for _, c in st.cars do
					if c.owned then
						keep = c
						break
					end
				end
			end
			setSelected(keep)
			grid:select(if keep then keep.id else nil)
		end
		detailOpen = false
		refreshWorlds()
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

	-- one World button, as a tall card in the rail ("Card") or a 48 px chip in the phone strip ("Chip")
	local function placeWorld(
		wb: WorldButton,
		x: number,
		y: number,
		w: number,
		h: number,
		chip: boolean,
		short: boolean
	)
		wb.root.Position = UDim2.fromOffset(x, y)
		wb.root.Size = UDim2.fromOffset(w, h)
		local def = defOf(wb.id)
		wb.name.Text = if short then def.short else def.long
		if chip then
			wb.emblem.Size = UDim2.fromOffset(32, 32)
			wb.emblem.Position = UDim2.fromOffset(7, 8)
			wb.name.Position = UDim2.fromOffset(44, 1)
			wb.name.Size = UDim2.fromOffset(w - 44 - 34, 24)
			wb.count.Position = UDim2.fromOffset(44, 23)
			wb.count.Size = UDim2.fromOffset(w - 44 - 34, 19)
			wb.barTrack.Position = UDim2.fromOffset(44, h - 6)
			wb.barTrack.Size = UDim2.fromOffset(w - 44 - 10, 4)
			wb.check.Position = UDim2.fromOffset(w - 30, 12)
			wb.chevron.Position = UDim2.fromOffset(w - 30 + 12, 12 + 12)
		else
			local e = if h >= 140 then 52 else 40
			wb.emblem.Size = UDim2.fromOffset(e, e)
			wb.emblem.Position = UDim2.fromOffset(8, 8)
			wb.name.Position = UDim2.fromOffset(8, e + 12)
			wb.name.Size = UDim2.fromOffset(w - 16, 26)
			wb.count.Position = UDim2.fromOffset(8, e + 38)
			wb.count.Size = UDim2.fromOffset(w - 16, 24)
			wb.barTrack.Position = UDim2.fromOffset(8, h - 18)
			wb.barTrack.Size = UDim2.fromOffset(w - 16, 10)
			wb.check.Position = UDim2.fromOffset(w - 32, 8)
			wb.chevron.Position = UDim2.fromOffset(w - 32 + 12, 8 + 12)
		end
	end

	-- the card size for a grid holder of `holderW` x `holderH` design px: 1 to 3 columns, never narrower than the smallest
	-- card and never so wide that a card shows its family row (that row is not shown for a car the player does not own)
	local function cellFor(holderW: number, holderH: number, short: boolean): Vector2
		local inner = holderW - GRID_INSET
		local cols = math.clamp(math.floor((inner + 18) / (CarCard.MinSize.X + 18)), 1, 3)
		-- a phone shows at least TWO tighter columns (never one wide card): each card is a little narrower than the room, so
		-- the second always fits whole beside the first with its selection ring and the scroll bar
		local slack = 0
		local widest = CarCard.CompactBelow - 6
		if short then
			cols = math.max(cols, 2)
			slack = 8
			widest = 176
		end
		local w = math.clamp(math.floor((inner - slack - 18 * (cols - 1)) / cols), CarCard.MinSize.X, widest)
		local h = if short
			then math.clamp(holderH - 28, CarCard.MinSize.Y, math.floor(w * 1.35))
			else math.clamp(math.floor(w * 1.42), CarCard.MinSize.Y, 280)
		return Vector2.new(w, h)
	end

	local function placeReward(w: number, h: number, narrow: boolean)
		rewardBox.Size = UDim2.fromOffset(w, h)
		if narrow then
			rewardIcon.Size = UDim2.fromOffset(28, 28)
			rewardIcon.Position = UDim2.fromOffset(8, 4)
			rewardAmount.Position = UDim2.fromOffset(40, 2)
			rewardAmount.Size = UDim2.fromOffset(w - 46, 32)
			rewardLine.Position = UDim2.fromOffset(6, 34)
			rewardLine.Size = UDim2.fromOffset(w - 12, 20)
			claimButton.root.AnchorPoint = Vector2.new(0.5, 1)
			claimButton.root.Position = UDim2.fromOffset(w / 2, h - 3)
		else
			rewardIcon.Size = UDim2.fromOffset(36, 36)
			rewardIcon.Position = UDim2.fromOffset(10, 14)
			rewardAmount.Position = UDim2.fromOffset(52, 3)
			rewardAmount.Size = UDim2.fromOffset(150, 32)
			rewardLine.Position = UDim2.fromOffset(52, 35)
			rewardLine.Size = UDim2.fromOffset(math.max(w - 52 - CLAIM_W - 16, 60), 24)
			claimButton.root.AnchorPoint = Vector2.new(1, 0.5)
			claimButton.root.Position = UDim2.fromOffset(w - 8, h / 2)
		end
		narrowReward = narrow or w < 470 -- the short words when the line has little room
	end

	-- the facts scroll area inside a detail card of `w` x `h` design px
	local function layoutDetail(w: number, h: number)
		local scrollH = h - 8
		detailScroll.Position = UDim2.fromOffset(4, 4)
		detailScroll.Size = UDim2.fromOffset(w - 8, math.max(scrollH, 40))
		local innerW = w - 8 - 8 - 4 - 8 -- the scroll frame, its bar and its padding
		local cardSize, compact = Facts.fit(innerW, scrollH - 14)
		local contentH = facts:layout(innerW, cardSize, compact)
		local frame = extras
		if frame then
			frame.Position = UDim2.fromOffset(0, contentH + 10)
			frame.Size = UDim2.fromOffset(innerW, 0)
		end
		detailEmpty.Position = UDim2.new(0, 0, 0.5, -12)
	end

	local function layoutNow()
		overlay:applyScale()
		local ds = overlay:designSize()
		local kind = Overlay.kindFor(ds)
		local wide = kind == "Wide"
		local short = kind ~= "Wide"
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
		local headH = if kind == "Short" then Style.HeaderHeightShort else Style.HeaderHeight
		header.setHeight(headH)
		header.title.Text = if wide then "GARAGE INDEX" else "INDEX"
		-- the header's right side, from the edge: the red X, CLAIM ALL, the Unlocked chip
		closeX.root.Position = UDim2.new(1, -8, 0, headH / 2)
		claimAllButton.root.AnchorPoint = Vector2.new(1, 0.5)
		claimAllButton.root.Position = UDim2.new(1, -(8 + Tokens.Touch.Minimum + 8), 0, headH / 2)
		-- room for the whole "Unlocked 24 / 24+" (the count and the tick of unknown totals), measured, never a guessed width
		local chipText = if wide then "Unlocked 88 / 88+" else "88 / 88+"
		local chipW = math.max(
			math.ceil(SupportKit.measure(chipText, 20).X * 1.14) + 54,
			if wide then CHIP_W_WIDE + 44 else CHIP_W_SHORT + 40
		)
		countChip.AnchorPoint = Vector2.new(1, 0.5)
		countChip.Size = UDim2.fromOffset(chipW, 40)
		countChip.Position = UDim2.new(1, -(8 + Tokens.Touch.Minimum + 8 + CLAIM_ALL_W + 8), 0, headH / 2)
		countText.TextXAlignment = Enum.TextXAlignment.Center
		local rightUsed = 8 + Tokens.Touch.Minimum + 8 + CLAIM_ALL_W + 8 + chipW + 12
		if customizeButton then
			customizeButton.root.AnchorPoint = Vector2.new(1, 0.5)
			customizeButton.root.Position = UDim2.new(1, -rightUsed + 4, 0, headH / 2)
			rightUsed += CUSTOMIZE_W + 8
		end
		local titleLeft = header.title.Position.X.Offset
		header.title.Size =
			UDim2.new(1, -titleLeft - rightUsed, 0, math.min(PreviewTokens.Arcade.Text.Display + 8, headH - 6))

		sortForm = if short then "Cycle" else "Row"
		compactHeader = short
		local page = short and detailOpen -- a phone's detail page replaces the Index below the header
		local browse = not page

		if wide then
			local bodyX, bodyY = 10, headH + 8
			local bodyW, bodyH = pw - 20, ph - bodyY - 10
			local gap = 10
			local railW = math.clamp(math.floor(bodyW * 0.19 + 0.5), 124, 210)
			local detailW = math.clamp(math.floor(bodyW * 0.33 + 0.5), 250, 380)
			local centerX = bodyX + railW + gap
			local centerW = bodyW - railW - detailW - 2 * gap
			local detailX = bodyX + bodyW - detailW
			-- the rail: one tall card per World
			local wbH = math.clamp(math.floor((bodyH - 16) / 3), 110, 150)
			for i, wb in worldButtons do
				wb.root.Visible = true
				placeWorld(wb, bodyX, bodyY + (i - 1) * (wbH + 8), railW, wbH, false, false)
			end
			-- the centre: sort, the World's bar, the grid, the reward box
			sortRow.Visible = true
			cycleTab.root.Visible = false
			placeSortRow(centerX, bodyY, centerW)
			local y = bodyY + SORT_H + 8
			completion.Visible = true
			completion.Position = UDim2.fromOffset(centerX, y)
			completion.Size = UDim2.fromOffset(centerW, COMPLETION_H)
			y += COMPLETION_H + 8
			local rewardY = bodyY + bodyH - REWARD_H
			gridHolder.Visible = true
			gridHolder.Position = UDim2.fromOffset(centerX, y)
			gridHolder.Size = UDim2.fromOffset(centerW, rewardY - 8 - y)
			grid:setCell(cellFor(centerW, rewardY - 8 - y, false))
			rewardBox.Visible = true
			rewardBox.Position = UDim2.fromOffset(centerX, rewardY)
			placeReward(centerW, REWARD_H, false)
			-- the detail card and the PUT ON RACEWAY bar
			detail.Visible = true
			detail.Position = UDim2.fromOffset(detailX, bodyY)
			detail.Size = UDim2.fromOffset(detailW, bodyH - ACTION_H - 8)
			layoutDetail(detailW, bodyH - ACTION_H - 8)
			actionBar.Visible = true
			actionBar.Position = UDim2.fromOffset(detailX, bodyY + bodyH - ACTION_H)
			actionBar.Size = UDim2.fromOffset(detailW, ACTION_H)
			backButton.root.Visible = false
			local half = math.min(DRIVE_W, math.floor((detailW - 12) / 2))
			rideButton.root.Size = UDim2.fromOffset(half, Tokens.Touch.Primary)
			driveButton.root.Size = UDim2.fromOffset(half, Tokens.Touch.Primary)
			rideButton.root.AnchorPoint = Vector2.new(1, 0)
			rideButton.root.Position = UDim2.new(0.5, -4, 0, 0)
			driveButton.root.AnchorPoint = Vector2.new(0, 0)
			driveButton.root.Position = UDim2.new(0.5, 4, 0, 0)
			reasonLabel.AnchorPoint = Vector2.new(0, 0)
			reasonLabel.Position = UDim2.fromOffset(4, Tokens.Touch.Primary + 8)
			reasonLabel.Size = UDim2.fromOffset(detailW - 8, ACTION_H - Tokens.Touch.Primary - 8)
		else
			local bodyX = 10
			local stripY = headH + 4
			local belowY = stripY + STRIP_H + 6
			local bodyH = ph - belowY - 6
			-- the World strip across the top
			local wbW = math.floor((pw - 20 - 2 * 8) / 3)
			for i, wb in worldButtons do
				wb.root.Visible = browse
				placeWorld(wb, bodyX + (i - 1) * (wbW + 8), stripY, wbW, STRIP_H, true, kind == "Short" and pw < 700)
			end
			sortRow.Visible = false
			completion.Visible = false
			-- the grid on the left, the sort button and the reward box in a column on the right
			local gridW = pw - 20 - COLUMN_W - 8
			gridHolder.Visible = browse
			gridHolder.Position = UDim2.fromOffset(bodyX, belowY)
			gridHolder.Size = UDim2.fromOffset(gridW, bodyH)
			grid:setCell(cellFor(gridW, bodyH, true))
			local colX = bodyX + gridW + 8
			cycleTab.root.Visible = browse
			cycleTab.root.Position = UDim2.fromOffset(colX, belowY)
			cycleTab.root.Size = UDim2.fromOffset(COLUMN_W, SORT_H)
			rewardBox.Visible = browse
			rewardBox.Position = UDim2.fromOffset(colX, belowY + SORT_H + 6)
			placeReward(COLUMN_W, math.max(bodyH - SORT_H - 6, 112), true)
			-- the detail page: the facts above, BACK and PUT ON RACEWAY under them
			local barH = 64
			local pageW = pw - 20
			detail.Visible = page
			detail.Position = UDim2.fromOffset(bodyX, stripY)
			detail.Size = UDim2.fromOffset(pageW, ph - stripY - barH - 14)
			layoutDetail(pageW, ph - stripY - barH - 14)
			actionBar.Visible = page
			actionBar.Position = UDim2.fromOffset(bodyX, ph - barH - 6)
			actionBar.Size = UDim2.fromOffset(pageW, barH)
			backButton.root.Visible = true
			backButton.root.AnchorPoint = Vector2.new(0, 0.5)
			backButton.root.Position = UDim2.fromScale(0, 0.5)
			local each = math.min(DRIVE_W, math.floor((pageW - BACK_W - 24) / 2))
			rideButton.root.Size = UDim2.fromOffset(each, Tokens.Touch.Primary)
			driveButton.root.Size = UDim2.fromOffset(each, Tokens.Touch.Primary)
			rideButton.root.AnchorPoint = Vector2.new(1, 0.5)
			rideButton.root.Position = UDim2.fromScale(1, 0.5)
			driveButton.root.AnchorPoint = Vector2.new(1, 0.5)
			driveButton.root.Position = UDim2.new(1, -each - 8, 0.5, 0)
			reasonLabel.AnchorPoint = Vector2.new(0, 1)
			reasonLabel.Position = UDim2.fromOffset(BACK_W + 8, -2)
			reasonLabel.Size = UDim2.fromOffset(math.max(pageW - BACK_W - 16, 60), 20)
		end
		refreshWorlds()
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

	local function claimWorldNow(id: string): boolean
		if rewardStateOf(id) ~= "Ready" then
			return false
		end
		claimed[id] = true
		previewClaims += 1
		local amount = GarageMock.PreviewRewards[id] or 0
		if opts.onPreviewClaim then
			opts.onPreviewClaim(id :: Tab, amount)
		end
		return true
	end

	local function afterClaim()
		Sounds.play("Unlock")
		refreshWorlds()
		Motion.pop(rewardBox, 1.04)
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
			rebuildStats()
			refreshWorlds()
			layoutNow()
			overlay:open(grid:firstBody() or worldButtons[1].root, returnTo)
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
			if selected ~= nil then
				selectionByTab[tab] = selected
			end
			tab = t
			loadingOverride = false
			applyTab()
			layoutNow()
		end,
		selectCar = function(_self: Garage, id: string)
			local target: CarRef? = nil
			for _, c in source do
				if c.id == id then
					target = c
					break
				end
			end
			if not target then
				return
			end
			local world = worldIdOf(target)
			if world ~= tab or loadingOverride then
				-- the car lives in another World: open that World with the car chosen
				selectionByTab[world] = target
				tab = world
				loadingOverride = false
				applyTab()
			end
			setSelected(target)
			grid:select(id)
			if overlay:kind() ~= "Wide" then
				detailOpen = true
			end
			updateDetail()
			layoutNow()
			overlay:focus(if driveEnabled then driveButton.body else backButton.body)
		end,
		setSort = function(_self: Garage, mode: SortMode?)
			sortMode = mode
			applySortUI()
			-- the same cars in a new order: the selection, the World and an open detail stay as they are
			local st = statsOf(tab)
			if not loadingOverride and st.state == "Ready" then
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
			shown = {}
			applyTab()
			layoutNow()
		end,
		setLoading = function(_self: Garage, on: boolean)
			loadingOverride = on
			applyTab()
			layoutNow()
		end,
		claimWorld = function(_self: Garage, t: Tab): boolean
			local ok = claimWorldNow(t)
			if ok then
				afterClaim()
			end
			return ok
		end,
		claimAll = function(_self: Garage): number
			local n = 0
			for _, def in WORLDS do
				if claimWorldNow(def.id) then
					n += 1
				end
			end
			if n > 0 then
				afterClaim()
			end
			return n
		end,
		getRewardState = function(_self: Garage, t: Tab): string
			return rewardStateOf(t)
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
			local barTop = actionBar.AbsolutePosition.Y
			local worlds: { WorldState } = {}
			for _, wb in worldButtons do
				local st = statsOf(wb.id)
				table.insert(worlds, {
					id = wb.id,
					owned = st.owned,
					total = st.total,
					state = st.state,
					reward = rewardStateOf(wb.id),
					selected = wb.id == tab,
					count = wb.count.Text,
				})
			end
			local owned, total, known = unlockedTotals()
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
				driveReason = driveReason,
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
				worlds = worlds,
				unlocked = { owned = owned, total = total, known = known },
				completion = (completion:FindFirstChild("Text", true) :: TextLabel).Text,
				rewardState = rewardStateOf(tab),
				rewardLine = rewardLine.Text,
				claimEnabled = rewardStateOf(tab) == "Ready",
				claimAllEnabled = eligibleCount() > 0,
				claimAllLabel = claimAllButton.label.Text,
				eligible = eligibleCount(),
				previewClaims = previewClaims,
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
