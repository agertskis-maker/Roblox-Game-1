--!strict
-- StuntCustomize: the "Customize" screen for the Stunt Circuit (Lane 3, Round 2 N12-03; PREVIEW). A turntable car under a light, three
-- tabs (PAINT, DECALS, WHEELS), item cards with rarity-coloured frames grouped by tier, and one big action button: EQUIP for what
-- you own, "BUY $X" for what you can afford, and a clear "not enough" message with BACK and VIEW SHOP when you cannot.
--
--   local c = StuntCustomize.new(ctx, { ownership = Ownership?, equipped = Equipped?, balance = number?, onEquip = fn?,
--                                       onBuy = fn?, onViewShop = fn?, onClose = fn? })
--   c:open(returnTo?)  c:close()  c:isOpen()
--   c:selectTab("Paint" | "Decals" | "Wheels")  c:select(itemId) -> boolean  c:pressEquip() -> boolean
--   c:pressBuy() -> boolean  c:pressBack()  c:pressViewShop()  c:setBalance(n)  c:getBalance() -> number
--   c:rotate(degrees)  c:setSpin(on)           -- the turntable (arrows turn it 45 degrees; drag turns it; it also turns by itself)
--   c:setOwnership(o)  c:setEquipped(e)        -- fixtures: a different set of owned items, a different look worn
--   c:layout()  c:setVisible(on)  c:destroy()  c:getDebugState()  c:touchReport()
--   StuntCustomize.geometry(designSize) -> Geo
--
-- THE CONTENT is CosmeticPreviewCatalog (33 paints, 15 decals, 10 wheels in tiers, PREVIEW prices, medal-locked paints). It is shown as
-- one Previewed item per tab and one Equipped item per tab: tapping a card PREVIEWS it on the turntable at once; an owned item then
-- offers EQUIP (which changes the session fixture only); an item you do not own offers "BUY $X" inside a PREVIEW frame that says
-- "Preview only. Nothing is charged or saved."; a medal-locked item says exactly what it needs ("Win GOLD to unlock") and offers no
-- way to buy it. EVERYTHING here is PREVIEW: the balance is a fixture labelled "PREVIEW Cash" (never the real Cash counter), a
-- purchase only edits this screen's own copy of the fixture, no MarketplaceService, no remote, nothing saved. There is no new currency.
--
-- THE STATES are distinct and none depends on colour alone (a word, a badge and a frame change as well):
--   equipped     a green tick badge and the word EQUIPPED; the button says EQUIPPED (disabled)
--   selected     a thick white ring on the card (the one you tapped); an eye mark says it is only previewed, not worn
--   locked       a dim cover, a padlock and the medal's word; the button says LOCKED
--   unavailable  a grey cover, a slash and N/A ("Not available for this car"); it cannot be previewed
--   priced       the PREVIEW price under the card; the button says BUY and previewing is allowed
--   insufficient BUY pressed with too little PREVIEW Cash: the words say how much is missing, with BACK and VIEW SHOP (VIEW SHOP only
--                navigates through options.onViewShop; it never opens a purchase prompt)
-- Closing the screen throws away every preview and shows what is worn. Bought items stay bought for as long as this screen exists
-- (the session) and a new Play resets them.
--
-- MOTION. The turntable turns at 12 degrees a second, pauses while it is dragged (and 2 s after), and stops under Reduce Motion.
-- Animated paints recolour six body bands at 12 Hz from one shared phase while the screen is open and shown; hidden or reduced, they
-- stop (reduced motion freezes a flattering phase). ONE connection serves both and exists only while the screen is open. The cards
-- are static thumbnails: there is exactly one ViewportFrame and one car on this screen.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Prototype = script.Parent.Parent
local Arcade = require(Prototype.Arcade)
local CardKit = require(script.Parent.CardKit)
local Catalog = require(ReplicatedStorage.Shared.UI.CosmeticPreviewCatalog)
local CosmeticCar = require(script.Parent.CosmeticCar)
local Format = require(ReplicatedStorage.Shared.UI.Format)
local IconArt = require(Prototype.Home.IconArt)
local Motion = require(Prototype.Motion)
local Overlay = require(script.Parent.Overlay)
local PreviewTokens = require(Prototype.PreviewTokens)
local ShopKit = require(Prototype.ShopKit)
local StuntFixtures = require(Prototype.SupportFixtures.StuntFixtures)
local StuntKit = require(script.Parent.StuntKit)
local Style = require(script.Parent.Style)
local SupportKit = require(script.Parent.SupportKit)
local Tokens = require(ReplicatedStorage.Shared.UI.Tokens)

local A = PreviewTokens.Arcade
local make = Arcade.make

local StuntCustomize = {}

StuntCustomize.SpinDegreesPerSecond = 12
StuntCustomize.StepDegrees = 45
StuntCustomize.PaintHz = 12
StuntCustomize.Tabs = Catalog.Tabs
StuntCustomize.NoteText = "Preview only. Nothing is charged or saved."

local SPIN_HZ = 30
local DRAG_PAUSE = 2
local DEG_PER_PIXEL = 0.5

type TabId = Catalog.TabId
type Item = Catalog.Item
type ItemState = Catalog.ItemState

export type Options = {
	ownership: Catalog.Ownership?,
	equipped: Catalog.Equipped?,
	balance: number?, -- PREVIEW Cash the screen starts with (default CosmeticPreviewCatalog.DefaultBalance)
	onEquip: ((tab: string, item: Item) -> ())?,
	onBuy: ((tab: string, item: Item) -> ())?, -- reports a PREVIEW purchase; nothing real happens
	onViewShop: (() -> ())?, -- navigate to the Shop (the screen closes after it)
	onClose: (() -> ())?,
}

export type Rect = { x: number, y: number, w: number, h: number }

export type Geo = {
	fit: SupportKit.Fit,
	pw: number,
	ph: number,
	headH: number,
	left: Rect,
	view: Rect, -- the turntable
	nameY: number,
	infoY: number,
	noteY: number,
	actionY: number, -- the action row's bottom edge, in panel px
	right: Rect,
	tabs: Rect,
	grid: Rect,
	tile: number, -- the card's side
	action: Vector2,
	pair: Vector2,
}

export type DebugState = {
	open: boolean,
	kind: string,
	fit: string,
	tab: string,
	selected: { [string]: string },
	equipped: { [string]: string },
	previewing: { [string]: boolean },
	state: string, -- the selected item's state on the current tab
	stateWord: string,
	mode: string, -- browse | short (the not-enough message)
	status: string,
	detail: string,
	note: string,
	equipLabel: string,
	buyLabel: string,
	equipEnabled: boolean,
	buyVisible: boolean,
	tiles: number,
	counts: { [string]: number }, -- per state, current tab
	tiers: { [string]: number }, -- per tier, current tab
	groups: { [string]: number }, -- the same as tiers (the old key)
	itemCounts: { [string]: number }, -- 33 / 15 / 10
	balance: number,
	buyCalls: number,
	purchased: { string },
	carPaint: { number },
	carDecal: string,
	carWheels: string,
	paintAnimated: boolean,
	paintUpdates: number,
	paintPhase: number,
	bands: number,
	decalParts: number,
	wheelParts: number,
	renderNote: string,
	spinning: boolean,
	dragging: boolean,
	yaw: number,
	ownershipChecksum: string,
	ownershipUntouched: boolean, -- the fixture handed in was never written
	equipCalls: number,
	caption: string,
	instances: number,
}

export type Customize = {
	root: Frame,
	layout: (self: Customize) -> (),
	setVisible: (self: Customize, on: boolean) -> (),
	open: (self: Customize, returnTo: GuiObject?) -> (),
	close: (self: Customize) -> (),
	isOpen: (self: Customize) -> boolean,
	selectTab: (self: Customize, tab: TabId) -> (),
	select: (self: Customize, itemId: string) -> boolean,
	pressEquip: (self: Customize) -> boolean,
	pressBuy: (self: Customize) -> boolean,
	pressBack: (self: Customize) -> (),
	pressViewShop: (self: Customize) -> (),
	setBalance: (self: Customize, amount: number) -> (),
	getBalance: (self: Customize) -> number,
	rotate: (self: Customize, degrees: number) -> (),
	setSpin: (self: Customize, on: boolean) -> (),
	setOwnership: (self: Customize, o: Catalog.Ownership) -> (),
	setEquipped: (self: Customize, e: Catalog.Equipped) -> (),
	destroy: (self: Customize) -> (),
	getDebugState: (self: Customize) -> DebugState,
	touchReport: (self: Customize) -> { { name: string, w: number, h: number } },
}

-- GEOMETRY ---------------------------------------------------------------------------------------------------------------

-- Left: the turntable, the item's name, one line about it, the PREVIEW note and the big action. Right: three tabs and the cards. A pure
-- function of the design-px viewport; phone landscape (about 750 x 325 and 573 x 310) is the first target.
function StuntCustomize.geometry(ds: Vector2): Geo
	local fit = SupportKit.fitFor(ds)
	local pw, ph, headH, leftW, tile, action
	if fit == "Compact" then
		pw, ph, headH, leftW = math.min(ds.X - 12, 700), ds.Y - 8, 46, 240
		tile, action = 58, Vector2.new(240, 56)
	elseif fit == "Regular" then
		pw, ph, headH, leftW = math.min(ds.X - 24, 780), math.min(ds.Y - 16, 440), 54, 290
		tile, action = 64, Vector2.new(290, 58)
	else
		pw, ph, headH, leftW = math.min(ds.X - 32, 920), math.min(ds.Y - 24, 580), 60, 360
		tile, action = 74, Vector2.new(360, 62)
	end
	local pad = 12
	local top = headH + 8
	local bodyH = ph - top - 10
	local rightX = pad * 2 + leftW
	local rightW = pw - pad - rightX
	local nameH, infoH, noteH = 24, 20, 20
	local actionBox = action.Y + 4
	local viewH = math.max(bodyH - nameH - infoH - noteH - actionBox - 16, 84)
	local viewY = top
	local nameY = viewY + viewH + 4
	local infoY = nameY + nameH
	local noteY = infoY + infoH
	local tabsH = Tokens.Touch.Minimum
	return {
		fit = fit,
		pw = pw,
		ph = ph,
		headH = headH,
		left = { x = pad, y = top, w = leftW, h = bodyH },
		view = { x = pad, y = viewY, w = leftW, h = viewH },
		nameY = nameY,
		infoY = infoY,
		noteY = noteY,
		actionY = top + bodyH,
		right = { x = rightX, y = top, w = rightW, h = bodyH },
		tabs = { x = rightX, y = top, w = rightW, h = tabsH },
		grid = { x = rightX, y = top + tabsH + 6, w = rightW, h = bodyH - tabsH - 6 },
		tile = tile,
		action = action,
		pair = Vector2.new(math.floor((action.X - 8) / 2), action.Y),
	}
end

-- HELPERS ------------------------------------------------------------------------------------------------------------------

local WHITE = Color3.new(1, 1, 1)

local function checksum(o: Catalog.Ownership): string
	local parts: { string } = {}
	for _, section in { "owned", "medals", "unavailable" } do
		local ids: { string } = {}
		for id, on in (o :: any)[section] do
			table.insert(ids, id .. "=" .. tostring(on))
		end
		table.sort(ids)
		table.insert(parts, section .. ":" .. table.concat(ids, ","))
	end
	return table.concat(parts, ";")
end

local function copyOwnership(o: Catalog.Ownership): Catalog.Ownership
	return { owned = table.clone(o.owned), medals = table.clone(o.medals), unavailable = table.clone(o.unavailable) }
end

local STATE_WORDS = {
	equipped = "EQUIPPED",
	owned = "OWNED",
	locked = "LOCKED",
	priced = "BUY",
	unavailable = "N/A",
}

local TAB_FALLBACKS: { [string]: { string } } = {
	Paint = { "PaintBucket", "Star" },
	Decals = { "Decal", "Star" },
	Wheels = { "Wheel", "Car" },
}

local function rarityOf(tab: TabId, item: Item): any
	local tier = Catalog.tierOf(tab, item.tier)
	local name = if tier then tier.rarity else "Common"
	return (PreviewTokens.Rarity :: any)[name]
end

-- BUILD ------------------------------------------------------------------------------------------------------------------

type Tile = {
	item: Item,
	button: TextButton,
	ring: Frame,
	eye: Frame,
	check: Frame,
	cover: Frame,
	lock: Frame,
	slash: Frame,
	caption: TextLabel,
}

type TabView = { scroll: ScrollingFrame, tiles: { [string]: Tile } }

function StuntCustomize.new(ctx: Overlay.Ctx, options: Options?): Customize
	local opts: Options = options or {}
	local fixtureOwnership = opts.ownership or Catalog.defaultOwnership()
	local initialChecksum = checksum(fixtureOwnership)
	local ownership = copyOwnership(fixtureOwnership) -- this screen's own copy: a PREVIEW purchase edits it, never the fixture
	local equipped: Catalog.Equipped = table.clone(opts.equipped or Catalog.defaultEquipped())
	local balance = opts.balance or Catalog.DefaultBalance
	local selected: { [string]: string } =
		{ Paint = equipped.Paint, Decals = equipped.Decals, Wheels = equipped.Wheels }
	local tab: TabId = "Paint"
	local geo = StuntCustomize.geometry(Vector2.new(750, 325))
	local mode = "browse" -- "short" while the not-enough message shows
	local views: { [string]: TabView } = {}
	local builtKey = ""
	local builtButtons = ""
	local yaw = 28
	local spin = true
	local dragging: InputObject? = nil
	local dragLast = 0
	local pausedUntil = 0
	local equipCalls, buyCalls = 0, 0
	local purchased: { string } = {}
	local paintUpdates = 0
	local paintPhase = CosmeticCar.flatteringPhase
	local spinClock, paintClock = 0, 0
	local shown = true
	local visibleCheck = 0
	local animating = false
	local customize: Customize

	local overlay = Overlay.new(ctx, {
		name = "StuntCustomize",
		onDim = function()
			customize:close()
		end,
	})
	local trove = overlay.trove
	local viewsTrove = trove:Extend()
	local buttonsTrove = trove:Extend()
	local animTrove = trove:Extend()
	local dragTrove = trove:Extend()
	local content = overlay.content
	-- a deep garage-night panel: the kit's panel shape with a dark violet gradient
	local shell = Style.panel(
		content,
		{ name = "Panel", z = 3, top = Color3.fromRGB(58, 52, 140), bottom = Color3.fromRGB(26, 24, 78) }
	)
	local panel = shell.body
	local header = Style.header(panel, { fill = "Garage", title = "CUSTOMIZE", icon = "Car", rightInset = 330 })
	local closeX = SupportKit.closeX(panel, function()
		customize:close()
	end)
	trove:Add(closeX.trove)
	local preview = StuntKit.previewChip(header.band, nil, 12)
	preview.frame.AnchorPoint = Vector2.new(1, 0.5)

	-- the PREVIEW Cash chip: a fixture balance, never the real Cash counter
	local cashChip = Style.chip(header.band, "PreviewCash", 12)
	cashChip.AnchorPoint = Vector2.new(1, 0.5)
	cashChip.Size = UDim2.fromOffset(190, 36)
	cashChip:SetAttribute("PersistentPreview", true)
	local cashCoin = CardKit.coin(cashChip, 22, 13)
	cashCoin.Position = UDim2.new(0, 20, 0.5, 0)
	local cashWord =
		Style.text(cashChip, "PREVIEW CASH", "Small", { name = "Word", z = 13, colour = PreviewTokens.Color.KeysLight })
	cashWord.AnchorPoint = Vector2.new(0, 0)
	cashWord.Position = UDim2.fromOffset(38, 1)
	cashWord.Size = UDim2.new(1, -44, 0, 16)
	local cashAmount = Style.text(cashChip, "$0", "Label", {
		name = "Amount",
		face = "Cash",
		italic = true,
		z = 13,
	})
	cashAmount.Position = UDim2.fromOffset(38, 17)
	cashAmount.Size = UDim2.new(1, -44, 0, 18)

	-- the turntable ------------------------------------------------------------------------------------------------------------
	local viewBox: Frame = make("Frame", {
		Name = "Turntable",
		BackgroundColor3 = WHITE,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		ZIndex = 5,
		Parent = panel,
	})
	Arcade.corner(viewBox, 12)
	Arcade.outline(viewBox, "Button")
	make("UIGradient", {
		Color = ColorSequence.new(Color3.fromRGB(46, 40, 112), Color3.fromRGB(14, 14, 44)),
		Rotation = 90,
		Parent = viewBox,
	})
	-- garage neon: two thin tubes along the top, and a soft pool of light on the floor (three ellipses, getting fainter)
	local neonA: Frame = make("Frame", {
		Name = "NeonA",
		Position = UDim2.fromScale(0.08, 0.07),
		Size = UDim2.fromScale(0.36, 0.025),
		BackgroundColor3 = Color3.fromRGB(255, 80, 170),
		BorderSizePixel = 0,
		ZIndex = 6,
		Parent = viewBox,
	})
	Arcade.corner(neonA, 99)
	local neonB: Frame = make("Frame", {
		Name = "NeonB",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(0.92, 0.07),
		Size = UDim2.fromScale(0.3, 0.025),
		BackgroundColor3 = Color3.fromRGB(80, 210, 255),
		BorderSizePixel = 0,
		ZIndex = 6,
		Parent = viewBox,
	})
	Arcade.corner(neonB, 99)
	for i, spec in { { 0.92, 0.8, 0.26 }, { 0.72, 0.62, 0.19 }, { 0.52, 0.44, 0.13 } } do
		local pool: Frame = make("Frame", {
			Name = "LightPool" .. i,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.66),
			Size = UDim2.fromScale(spec[2], spec[3]),
			BackgroundColor3 = Color3.fromRGB(255, 244, 200),
			BackgroundTransparency = 1 - (1 - spec[1]) * 0.55,
			BorderSizePixel = 0,
			ZIndex = 6,
			Parent = viewBox,
		})
		Arcade.corner(pool, 999)
	end
	local viewport: ViewportFrame = make("ViewportFrame", {
		Name = "Viewport",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Ambient = Color3.fromRGB(172, 176, 196),
		LightColor = Color3.fromRGB(255, 246, 228),
		LightDirection = Vector3.new(-0.5, -1, -0.4),
		ZIndex = 7,
		Parent = viewBox,
	})
	local camera: Camera = make("Camera", { Name = "TurntableCamera", FieldOfView = 30, Parent = viewport })
	camera.CFrame = CFrame.lookAt(Vector3.new(15, 8, 25), Vector3.new(0, 1.8, 0))
	viewport.CurrentCamera = camera
	-- ONE disposable car on ONE stage (a neutral part-built rig; no model of Brian L's is touched or cloned)
	local rig = CosmeticCar.newRig(viewport)
	trove:Add(rig.stage)
	local carChip = Style.chip(viewBox, "PreviewCarChip", 9)
	local carChipText = Overlay.text(carChip, "PREVIEW CAR", 16, nil, Enum.TextXAlignment.Center, 10)
	carChip:SetAttribute("PersistentPreview", true)
	local swatchChip = Style.chip(viewBox, "CardOnlyChip", 9)
	local swatchChipText = Overlay.text(swatchChip, "CARD PREVIEW ONLY", 16, nil, Enum.TextXAlignment.Center, 10)
	swatchChip.Visible = false
	-- drag to turn: a transparent catcher under the arrows
	local dragArea: TextButton = make("TextButton", {
		Name = "DragArea",
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false,
		Selectable = false,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 8,
		Parent = viewBox,
	})
	local turnLeft = Arcade.button(viewBox, {
		name = "TurnLeft",
		label = "<",
		fill = "Garage",
		size = "Custom",
		width = 48,
		height = 48,
		cooldown = 0.1,
		onActivate = function()
			customize:rotate(-StuntCustomize.StepDegrees)
		end,
	})
	trove:Add(turnLeft.trove)
	turnLeft.root.ZIndex = 12
	local turnRight = Arcade.button(viewBox, {
		name = "TurnRight",
		label = ">",
		fill = "Garage",
		size = "Custom",
		width = 48,
		height = 48,
		cooldown = 0.1,
		onActivate = function()
			customize:rotate(StuntCustomize.StepDegrees)
		end,
	})
	trove:Add(turnRight.trove)
	turnRight.root.ZIndex = 12

	local function applyYaw()
		rig.stage:PivotTo(CFrame.Angles(0, math.rad(yaw), 0))
	end

	-- what is selected, in words -----------------------------------------------------------------------------------------------
	local nameLabel = SupportKit.label(panel, "ItemName", 22, 6)
	local infoLabel = SupportKit.label(panel, "ItemInfo", 16, 6)
	infoLabel.TextColor3 = Style.TextSoft
	local noteLabel = SupportKit.label(panel, "PreviewNote", 16, 6)
	noteLabel.TextColor3 = PreviewTokens.Color.KeysLight
	noteLabel.Text = StuntCustomize.NoteText
	noteLabel:SetAttribute("PersistentPreview", true)

	-- the action bar: a vivid moving gradient behind BUY (a selling surface), buttons drawn over it
	local actionBar: Frame = make("Frame", {
		Name = "ActionBar",
		BackgroundColor3 = WHITE,
		BorderSizePixel = 0,
		Visible = false,
		ZIndex = 5,
		Parent = panel,
	})
	Arcade.corner(actionBar, 10)
	Arcade.outline(actionBar, "Button")
	ShopKit.vividBackground(actionBar, trove, { fill = "Popup", recipe = "Popup" })

	-- tabs --------------------------------------------------------------------------------------------------------------------------
	local tabs: { [string]: Style.Tab } = {}
	for _, id in Catalog.Tabs do
		local t = Style.tab(panel, {
			name = "Tab_" .. id,
			label = (Catalog.TabLabels :: any)[id],
			onActivate = function()
				customize:selectTab(id)
			end,
		})
		trove:Add(t.trove)
		-- the tab's own icon on the left; the word moves right of it
		local icon = CardKit.icon(t.root, TAB_FALLBACKS[id], 30, 9)
		icon.AnchorPoint = Vector2.new(0, 0.5)
		icon.Position = UDim2.new(0, 8, 0.5, 0)
		t.label.Position = UDim2.new(0.5, 16, 0.5, 0)
		t.label.Size = UDim2.new(1, -60, 0, A.Text.Label + 6)
		tabs[id] = t
	end
	local gridBox = Style.well(panel, "GridBox", 5)

	-- STATE HELPERS ------------------------------------------------------------------------------------------------------------

	local function itemById(tabId: string, id: string): Item?
		return Catalog.byId(tabId :: TabId, id)
	end

	local function stateOf(item: Item): ItemState
		return Catalog.stateOf(item, ownership, (equipped :: any)[item.tab])
	end

	-- the id the turntable shows for a tab: the selected one if it can be previewed, else what is worn
	local function effectiveId(tabId: string): string
		local item = itemById(tabId, selected[tabId])
		if item and stateOf(item) ~= "unavailable" then
			return item.id
		end
		return (equipped :: any)[tabId]
	end

	local function isPreviewing(tabId: string): boolean
		return effectiveId(tabId) ~= (equipped :: any)[tabId]
	end

	local function currentItem(): Item?
		return itemById(tab, selected[tab])
	end

	local function medalWord(item: Item): string?
		local medal = item.medal
		if medal then
			return (StuntFixtures.Medals :: any)[medal].word
		end
		return nil
	end

	-- THE TURNTABLE CAR --------------------------------------------------------------------------------------------------------

	local carPaintId, carDecalId, carWheelId = "", "", ""
	local function applyCar()
		local paintItem = itemById("Paint", effectiveId("Paint"))
		local decalItem = itemById("Decals", effectiveId("Decals"))
		local wheelItem = itemById("Wheels", effectiveId("Wheels"))
		-- only what changed is rewritten: no rebuild on a hover or a re-select of the same item
		if paintItem and paintItem.id ~= carPaintId then
			carPaintId = paintItem.id
			CosmeticCar.setPaint(rig, paintItem, if Motion.reduced() then CosmeticCar.flatteringPhase else paintPhase)
		end
		if decalItem and decalItem.id ~= carDecalId then
			carDecalId = decalItem.id
			CosmeticCar.setDecal(rig, decalItem)
		end
		if wheelItem and wheelItem.id ~= carWheelId then
			carWheelId = wheelItem.id
			CosmeticCar.setWheels(rig, wheelItem)
		end
	end

	-- CARDS --------------------------------------------------------------------------------------------------------------------

	local function captionFor(item: Item, state: ItemState): string
		if state == "equipped" then
			return "EQUIPPED"
		elseif state == "locked" then
			return medalWord(item) or "LOCKED"
		elseif state == "unavailable" then
			return "N/A"
		elseif state == "priced" then
			return Format.cash(item.price)
		end
		return if item.price == 0 then "FREE" else "OWNED"
	end

	local function buildTile(parent: Instance, item: Item, side: number): Tile
		local rarity = rarityOf(item.tab, item)
		local button: TextButton = make("TextButton", {
			Name = "Tile_" .. item.id,
			BackgroundTransparency = 1,
			AutoButtonColor = false,
			Text = "",
			Selectable = true,
			Size = UDim2.fromOffset(side, side + 20),
			ZIndex = 8,
			Parent = parent,
		})
		button:SetAttribute("Item", item.id)
		button:SetAttribute("Tier", item.tier)
		-- the rarity frame: a dark card with a coloured edge (the tier name and pips in the section header say the same in words)
		local card: Frame = make("Frame", {
			Name = "Card",
			Size = UDim2.fromOffset(side, side),
			BackgroundColor3 = rarity.deep:Lerp(Color3.new(0, 0, 0), 0.55),
			BorderSizePixel = 0,
			ZIndex = 8,
			Parent = button,
		})
		Arcade.corner(card, 10)
		make("UIStroke", {
			Thickness = 3,
			Color = rarity.light,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			Parent = card,
		})
		local scale: UIScale = make("UIScale", { Name = "Hover", Parent = card })
		local art: Frame = make("Frame", {
			Name = "Art",
			Position = UDim2.fromOffset(5, 5),
			Size = UDim2.fromOffset(side - 10, side - 10),
			BackgroundTransparency = 1,
			ZIndex = 9,
			Parent = card,
		})
		CosmeticCar.drawThumb(art, item, side - 10)
		-- the selection ring sits just outside the card
		local ring: Frame = make("Frame", {
			Name = "Ring",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(side / 2, side / 2),
			Size = UDim2.fromOffset(side + 8, side + 8),
			BackgroundTransparency = 1,
			Visible = false,
			ZIndex = 14,
			Parent = button,
		})
		Arcade.corner(ring, 12)
		Arcade.outline(ring, 3.5, WHITE)
		local focusRing: Frame = make("Frame", {
			Name = "FocusRing",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(side / 2, side / 2),
			Size = UDim2.fromOffset(side + 10, side + 10),
			BackgroundTransparency = 1,
			Visible = false,
			ZIndex = 14,
			Parent = button,
		})
		Arcade.corner(focusRing, 13)
		Arcade.outline(focusRing, 3, Color3.fromRGB(255, 230, 90))
		button.SelectionImageObject = focusRing
		local cover: Frame = make("Frame", {
			Name = "Cover",
			Size = UDim2.fromOffset(side, side),
			BackgroundColor3 = Color3.fromRGB(14, 20, 38),
			BackgroundTransparency = 0.38,
			BorderSizePixel = 0,
			Visible = false,
			ZIndex = 10,
			Parent = button,
		})
		Arcade.corner(cover, 10)
		local lock: Frame = make("Frame", {
			Name = "Padlock",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(side / 2, side / 2),
			Size = UDim2.fromOffset(side * 0.56, side * 0.56),
			BackgroundTransparency = 1,
			Visible = false,
			ZIndex = 12,
			Parent = button,
		})
		IconArt.draw(lock, { "Padlock", "Lock" })
		local slash: Frame = make("Frame", {
			Name = "Slash",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(side / 2, side / 2),
			Size = UDim2.fromOffset(5, side * 1.1),
			Rotation = 40,
			BackgroundColor3 = WHITE,
			BorderSizePixel = 0,
			Visible = false,
			ZIndex = 12,
			Parent = button,
		})
		Arcade.outline(slash, 1.5)
		local check: Frame = make("Frame", {
			Name = "EquippedTick",
			Position = UDim2.fromOffset(-5, -5),
			Size = UDim2.fromOffset(26, 26),
			BackgroundColor3 = Color3.fromRGB(46, 190, 90),
			BorderSizePixel = 0,
			Visible = false,
			ZIndex = 16,
			Parent = button,
		})
		Arcade.corner(check, 13)
		Arcade.outline(check, 2.5)
		local tick: Frame = make("Frame", {
			Name = "Icon",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(18, 18),
			BackgroundTransparency = 1,
			ZIndex = 17,
			Parent = check,
		})
		IconArt.draw(tick, { "Check" })
		local eye: Frame = make("Frame", {
			Name = "PreviewEye",
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.fromOffset(side + 4, -4),
			Size = UDim2.fromOffset(28, 18),
			BackgroundColor3 = WHITE,
			BorderSizePixel = 0,
			Visible = false,
			ZIndex = 16,
			Parent = button,
		})
		Arcade.corner(eye, 9)
		Arcade.outline(eye, 2)
		local pupil: Frame = make("Frame", {
			Name = "Pupil",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(10, 10),
			BackgroundColor3 = A.Ink,
			BorderSizePixel = 0,
			ZIndex = 17,
			Parent = eye,
		})
		Arcade.corner(pupil, 5)
		local caption = Overlay.text(button, "", 16, nil, Enum.TextXAlignment.Center, 9)
		caption.Name = "Caption"
		caption.Position = UDim2.fromOffset(-5, side + 1)
		caption.Size = UDim2.fromOffset(side + 10, 19)
		-- mouse hover lifts the card a little; a press squeezes it; touch has no hover
		viewsTrove:Connect(button.MouseEnter, function()
			if not Motion.reduced() then
				Motion.tween(scale, "hover", Motion.info(0.1), { Scale = 1.06 })
			end
		end)
		viewsTrove:Connect(button.MouseLeave, function()
			Motion.tween(scale, "hover", Motion.info(0.1), { Scale = 1 })
		end)
		viewsTrove:Connect(button.MouseButton1Down, function()
			Motion.tween(scale, "hover", Motion.info(0.06), { Scale = 0.95 })
		end)
		viewsTrove:Connect(button.MouseButton1Up, function()
			Motion.tween(scale, "hover", Motion.info(0.1), { Scale = 1 })
		end)
		viewsTrove:Connect(button.Activated, function()
			customize:select(item.id)
		end)
		return {
			item = item,
			button = button,
			ring = ring,
			eye = eye,
			check = check,
			cover = cover,
			lock = lock,
			slash = slash,
			caption = caption,
		}
	end

	local function buildTabView(tabId: TabId): TabView
		local scroll = Style.scroll(gridBox, "Items_" .. tabId, 6)
		scroll.ScrollBarThickness = 6
		scroll.Position = UDim2.fromOffset(6, 6)
		scroll.Size = UDim2.new(1, -12, 1, -12)
		scroll.Visible = false
		make("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			Padding = UDim.new(0, 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
			Parent = scroll,
		})
		local view: TabView = { scroll = scroll, tiles = {} }
		local side = geo.tile
		local order = 0
		for _, t in Catalog.Tiers[tabId] do
			local items = Catalog.tierItems(tabId, t.id)
			if #items > 0 then
				order += 1
				local rarity = (PreviewTokens.Rarity :: any)[t.rarity]
				local section: Frame = make("Frame", {
					Name = "Tier_" .. t.id,
					LayoutOrder = order,
					BackgroundTransparency = 1,
					AutomaticSize = Enum.AutomaticSize.Y,
					Size = UDim2.new(1, -8, 0, 0),
					ZIndex = 7,
					Parent = scroll,
				})
				make("UIListLayout", {
					FillDirection = Enum.FillDirection.Vertical,
					Padding = UDim.new(0, 3),
					SortOrder = Enum.SortOrder.LayoutOrder,
					Parent = section,
				})
				-- the tier's name in a coloured pill, the rarity pips (colour is never the only signal) and the price range
				local head: Frame = make("Frame", {
					Name = "Head",
					LayoutOrder = 1,
					BackgroundTransparency = 1,
					Size = UDim2.new(1, 0, 0, 26),
					ZIndex = 8,
					Parent = section,
				})
				local pill: Frame = make("Frame", {
					Name = "Pill",
					Size = UDim2.fromOffset(math.ceil(SupportKit.measure(t.name, 16).X) + 22, 24),
					BackgroundColor3 = rarity.deep,
					BorderSizePixel = 0,
					ZIndex = 8,
					Parent = head,
				})
				Arcade.corner(pill, 12)
				Arcade.outline(pill, "Minor")
				local pillText =
					Overlay.text(pill, t.name, 16, rarity.light:Lerp(WHITE, 0.6), Enum.TextXAlignment.Center, 9)
				pillText.Size = UDim2.fromScale(1, 1)
				local pips = SupportKit.pips(head, t.rarity, 9)
				pips.AnchorPoint = Vector2.new(0, 0.5)
				pips.Position = UDim2.new(0, pill.Size.X.Offset + 8, 0.5, 0)
				local low, high = math.huge, 0
				for _, it in items do
					low = math.min(low, it.price)
					high = math.max(high, it.price)
				end
				local range = if high == 0
					then "FREE"
					elseif low == high then Format.cash(low)
					else Format.cash(low) .. " - " .. Format.cash(high)
				local rangeLabel = Overlay.text(head, range, 16, Style.TextSoft, Enum.TextXAlignment.Right, 9)
				rangeLabel.AnchorPoint = Vector2.new(1, 0.5)
				rangeLabel.Position = UDim2.new(1, -2, 0.5, 0)
				rangeLabel.Size = UDim2.fromOffset(130, 22)
				local grid: Frame = make("Frame", {
					Name = "Grid",
					LayoutOrder = 2,
					BackgroundTransparency = 1,
					AutomaticSize = Enum.AutomaticSize.Y,
					Size = UDim2.fromScale(1, 0),
					ZIndex = 7,
					Parent = section,
				})
				make("UIGridLayout", {
					CellSize = UDim2.fromOffset(side + 12, side + 28),
					CellPadding = UDim2.fromOffset(4, 2),
					FillDirection = Enum.FillDirection.Horizontal,
					SortOrder = Enum.SortOrder.LayoutOrder,
					Parent = grid,
				})
				for i, item in items do
					-- each card sits in a cell a little bigger than itself, so the ring and the badges are never clipped
					local cell: Frame = make("Frame", {
						Name = "Cell_" .. item.id,
						LayoutOrder = i,
						BackgroundTransparency = 1,
						ZIndex = 7,
						Parent = grid,
					})
					local holder: Frame = make("Frame", {
						Name = "Holder",
						Position = UDim2.fromOffset(6, 5),
						Size = UDim2.fromOffset(side, side + 20),
						BackgroundTransparency = 1,
						ZIndex = 7,
						Parent = cell,
					})
					view.tiles[item.id] = buildTile(holder, item, side)
				end
			end
		end
		return view
	end

	local function refreshTiles()
		local view = views[tab]
		if not view then
			return
		end
		for id, t in view.tiles do
			local state = stateOf(t.item)
			local isSelected = selected[t.item.tab] == id
			t.ring.Visible = isSelected
			t.check.Visible = state == "equipped"
			t.eye.Visible = isSelected and state ~= "equipped" and state ~= "unavailable"
			t.cover.Visible = state == "locked" or state == "unavailable"
			t.cover.BackgroundTransparency = if state == "unavailable" then 0.2 else 0.38
			t.lock.Visible = state == "locked"
			t.slash.Visible = state == "unavailable"
			t.caption.Text = captionFor(t.item, state)
			t.button:SetAttribute("State", state)
			t.button:SetAttribute("Selected", isSelected)
			t.button:SetAttribute("Previewing", isSelected and state ~= "equipped" and state ~= "unavailable")
		end
	end

	-- THE WORDS AND THE ACTION --------------------------------------------------------------------------------------------------

	local equipButton: Arcade.Button? = nil
	local buyButton: Arcade.Button? = nil
	local backButton: Arcade.Button? = nil
	local shopButton: Arcade.Button? = nil

	local function shortfall(item: Item): number
		return math.max(0, item.price - balance)
	end

	local function infoFor(item: Item, state: ItemState): string
		local tier = Catalog.tierOf(item.tab, item.tier)
		local tierName = if tier then tier.name else ""
		if state == "equipped" then
			return tierName .. " · ON YOUR CAR"
		elseif state == "owned" then
			return tierName .. (if item.price == 0 then " · FREE" else " · OWNED")
		elseif state == "priced" then
			return tierName .. " · " .. Format.cash(item.price)
		elseif state == "locked" then
			local word = medalWord(item)
			return if word then string.format("Win %s to unlock · %s", word, Format.cash(item.price)) else "Locked"
		end
		return "Not available for this car"
	end

	local function refreshStatus()
		local item = currentItem()
		local eq, buy, back, shop = equipButton, buyButton, backButton, shopButton
		if not item then
			nameLabel.Text = ""
			infoLabel.Text = ""
			return
		end
		local state = stateOf(item)
		local short = mode == "short" and state == "priced"
		if short then
			nameLabel.Text = "Not enough PREVIEW Cash"
			infoLabel.Text = string.format("You need %s more. Nothing is charged.", Format.cash(shortfall(item)))
		else
			nameLabel.Text = item.name
			infoLabel.Text = infoFor(item, state)
		end
		SupportKit.fitLabel(nameLabel, nameLabel.Text, geo.left.w, 24, 22)
		SupportKit.fitLabel(infoLabel, infoLabel.Text, geo.left.w, 20, 16)
		swatchChip.Visible = item.render == "swatch"
		-- the buttons: EQUIP (or its resting words), BUY, or the BACK / VIEW SHOP pair
		local showBuy = state == "priced" and not short
		local showEquip = not short and state ~= "priced"
		if eq then
			eq.root.Visible = showEquip
			eq.setLabel(
				if state == "owned"
					then "EQUIP"
					elseif state == "equipped" then "EQUIPPED"
					elseif state == "locked" then "LOCKED"
					else "N/A"
			)
			eq.setEnabled(state == "owned")
		end
		if buy then
			buy.root.Visible = showBuy
			buy.setLabel("BUY " .. Format.cash(item.price))
		end
		if back and shop then
			back.root.Visible = short
			shop.root.Visible = short
		end
		actionBar.Visible = showBuy or short
	end

	local function refreshAll()
		applyCar()
		refreshTiles()
		refreshStatus()
		cashAmount.Text = Format.cash(balance)
	end

	-- BUILD, SHOW AND LAYOUT THE GRIDS -------------------------------------------------------------------------------------------

	local function showTab()
		for id, view in views do
			view.scroll.Visible = id == tab
		end
		if not views[tab] then
			views[tab] = buildTabView(tab)
			views[tab].scroll.Visible = true
		end
		refreshTiles()
	end

	local function buildButtons()
		local key = string.format("%dx%d/%dx%d", geo.action.X, geo.action.Y, geo.pair.X, geo.pair.Y)
		if key == builtButtons and equipButton then
			return
		end
		builtButtons = key
		buttonsTrove:Clean()
		local function mk(
			name: string,
			label: string,
			fill: Arcade.FillName,
			size: Vector2,
			drift: boolean?,
			fn: () -> ()
		): Arcade.Button
			local b = Arcade.button(panel, {
				name = name,
				label = label,
				fill = fill,
				size = "Custom",
				width = size.X,
				height = size.Y,
				pattern = fill ~= "Rainbow",
				drift = drift,
				cooldown = 0.4,
				onActivate = fn,
			})
			buttonsTrove:Add(b.trove)
			b.root.ZIndex = 12
			return b
		end
		equipButton = mk("Equip", "EQUIP", "Green", geo.action, nil, function()
			customize:pressEquip()
		end)
		buyButton = mk("Buy", "BUY", "Missions", geo.action, nil, function()
			customize:pressBuy()
		end)
		backButton = mk("Back", "BACK", "Garage", geo.pair, nil, function()
			customize:pressBack()
		end)
		shopButton = mk("ViewShop", "VIEW SHOP", "Rainbow", geo.pair, true, function()
			customize:pressViewShop()
		end)
	end

	local function layoutNow()
		overlay:applyScale()
		geo = StuntCustomize.geometry(overlay:designSize())
		shell.root.Size = UDim2.fromOffset(geo.pw, geo.ph)
		shell.root.Position = UDim2.new(0.5, 0, 0.5, -2)
		header.setHeight(geo.headH)
		header.title.Size =
			UDim2.new(1, -header.title.Position.X.Offset - 330, 0, math.min(A.Text.Display + 8, geo.headH - 6))
		closeX.root.Position = UDim2.new(1, -8, 0, geo.headH / 2)
		cashChip.Position = UDim2.new(1, -8 - Tokens.Touch.Minimum - 8, 0.5, 0)
		preview.frame.Position = UDim2.new(1, -8 - Tokens.Touch.Minimum - 8 - 190 - 8, 0.5, 0)
		-- the turntable and the lines under it
		local v = geo.view
		viewBox.Position = UDim2.fromOffset(v.x, v.y)
		viewBox.Size = UDim2.fromOffset(v.w, v.h)
		carChip.AnchorPoint = Vector2.new(0.5, 0)
		carChip.Position = UDim2.new(0.5, 0, 0, 12)
		carChip.Size = UDim2.fromOffset(math.min(v.w - 120, 150), 24)
		carChipText.Size = UDim2.fromScale(1, 1)
		swatchChip.AnchorPoint = Vector2.new(0.5, 1)
		swatchChip.Position = UDim2.new(0.5, 0, 1, -6)
		swatchChip.Size = UDim2.fromOffset(math.min(v.w - 120, 190), 24)
		swatchChipText.Size = UDim2.fromScale(1, 1)
		turnLeft.root.AnchorPoint = Vector2.new(0, 1)
		turnLeft.root.Position = UDim2.new(0, 4, 1, -2)
		turnRight.root.AnchorPoint = Vector2.new(1, 1)
		turnRight.root.Position = UDim2.new(1, -4, 1, -2)
		nameLabel.Position = UDim2.fromOffset(v.x, geo.nameY)
		nameLabel.Size = UDim2.fromOffset(v.w, 24)
		infoLabel.Position = UDim2.fromOffset(v.x, geo.infoY)
		infoLabel.Size = UDim2.fromOffset(v.w, 20)
		noteLabel.Position = UDim2.fromOffset(v.x, geo.noteY)
		noteLabel.Size = UDim2.fromOffset(v.w, 20)
		SupportKit.fitLabel(noteLabel, StuntCustomize.NoteText, v.w, 20, 16)
		-- the action row
		buildButtons()
		local rowBottom = geo.actionY
		local barH = geo.action.Y + 12
		actionBar.AnchorPoint = Vector2.new(0, 1)
		actionBar.Position = UDim2.fromOffset(v.x, rowBottom + 2)
		actionBar.Size = UDim2.fromOffset(v.w, barH)
		local eq, buy, back, shop = equipButton, buyButton, backButton, shopButton
		if eq and buy and back and shop then
			for _, b in { eq, buy } do
				b.root.AnchorPoint = Vector2.new(0.5, 1)
				b.root.Position = UDim2.fromOffset(v.x + v.w / 2, rowBottom - 2)
			end
			back.root.AnchorPoint = Vector2.new(0, 1)
			shop.root.AnchorPoint = Vector2.new(1, 1)
			back.root.Position = UDim2.fromOffset(v.x + (v.w - geo.action.X) / 2, rowBottom - 2)
			shop.root.Position = UDim2.fromOffset(v.x + (v.w + geo.action.X) / 2, rowBottom - 2)
		end
		-- the tabs and the grid
		local t = geo.tabs
		local tabW = math.floor((t.w - 12) / 3)
		for i, id in Catalog.Tabs do
			local tb = tabs[id]
			tb.root.Position = UDim2.fromOffset(t.x + (i - 1) * (tabW + 6), t.y)
			tb.root.Size = UDim2.fromOffset(tabW, t.h)
		end
		local g = geo.grid
		gridBox.Position = UDim2.fromOffset(g.x, g.y)
		gridBox.Size = UDim2.fromOffset(g.w, g.h)
		-- cards change size with the fit, so a new fit rebuilds the grids (and only the current one is built at once)
		local key = string.format("%s|%d", geo.fit, geo.tile)
		if key ~= builtKey then
			builtKey = key
			viewsTrove:Clean()
			for _, view in views do
				view.scroll:Destroy()
			end
			table.clear(views)
		end
		showTab()
		refreshAll()
	end

	-- THE ONE ANIMATOR: turn the stage and tick an animated paint ---------------------------------------------------------------

	local function stopAnimator()
		animTrove:Clean()
		animating = false
	end

	local function startAnimator()
		if animating then
			return
		end
		animating = true
		animTrove:Connect(RunService.Heartbeat, function(dt: number)
			visibleCheck -= dt
			if visibleCheck <= 0 then
				visibleCheck = 0.25
				shown = CardKit.visible(overlay.root)
			end
			if not shown or Motion.reduced() then
				return
			end
			-- the stage turns at 30 updates a second, never while it is being dragged (or just after)
			spinClock += dt
			if spinClock >= 1 / SPIN_HZ then
				local step = spinClock
				spinClock = 0
				if spin and dragging == nil and os.clock() >= pausedUntil then
					yaw = (yaw + StuntCustomize.SpinDegreesPerSecond * step) % 360
					applyYaw()
				end
			end
			-- an animated paint: ONE shared phase, about 12 updates a second
			paintClock += dt
			if paintClock >= 1 / StuntCustomize.PaintHz then
				paintClock = 0
				local item = rig.paint
				if CosmeticCar.isAnimated(item) and item then
					paintPhase = (os.clock() / (item.cycleSeconds or 6)) % 1
					CosmeticCar.tickPaint(rig, paintPhase)
					paintUpdates += 1
				end
			end
		end)
	end

	local function refreshAnimator()
		if overlay:isOpen() and overlay.root.Visible then
			startAnimator()
		else
			stopAnimator()
		end
	end

	-- a flattering frozen phase while Reduce Motion is on, the live one when it is switched off
	trove:Add(Motion.onReducedChanged(function(reduced: boolean)
		if reduced then
			CosmeticCar.tickPaint(rig, CosmeticCar.flatteringPhase)
		end
	end))

	-- dragging the turntable ----------------------------------------------------------------------------------------------------
	trove:Connect(dragArea.InputBegan, function(input: InputObject)
		if
			input.UserInputType ~= Enum.UserInputType.MouseButton1
			and input.UserInputType ~= Enum.UserInputType.Touch
		then
			return
		end
		dragging = input
		dragLast = input.Position.X
		dragTrove:Clean()
		dragTrove:Connect(UserInputService.InputChanged, function(moved: InputObject)
			local d = dragging
			if d == nil then
				return
			end
			if moved == d or moved.UserInputType == Enum.UserInputType.MouseMovement then
				local x = moved.Position.X
				yaw = (yaw + (x - dragLast) * DEG_PER_PIXEL) % 360
				dragLast = x
				applyYaw()
			end
		end)
		dragTrove:Connect(UserInputService.InputEnded, function(ended: InputObject)
			if ended == dragging then
				dragging = nil
				pausedUntil = os.clock() + DRAG_PAUSE
				dragTrove:Clean()
			end
		end)
	end)

	overlay:setBack(function()
		if mode == "short" then
			customize:pressBack()
		else
			customize:close()
		end
	end)
	trove:Connect(ctx.screen.Changed, function()
		layoutNow()
	end)

	-- PUBLIC -----------------------------------------------------------------------------------------------------------

	customize = {
		root = overlay.root,
		layout = function(_self: Customize)
			layoutNow()
		end,
		setVisible = function(_self: Customize, on: boolean)
			overlay.root.Visible = on and overlay:isOpen()
			refreshAnimator()
		end,
		open = function(_self: Customize, returnTo: GuiObject?)
			if overlay:isOpen() then
				return
			end
			-- every preview is thrown away: the screen always opens on what is worn
			selected = { Paint = equipped.Paint, Decals = equipped.Decals, Wheels = equipped.Wheels }
			tab = "Paint"
			mode = "browse"
			for id, tb in tabs do
				tb.set(id == tab)
			end
			applyYaw()
			layoutNow()
			local view = views[tab]
			local firstTile: GuiObject? = nil
			if view then
				local focusItem = view.tiles[selected[tab]]
				firstTile = if focusItem then focusItem.button else nil
			end
			overlay:open(firstTile, returnTo)
			refreshAnimator()
		end,
		close = function(_self: Customize)
			if not overlay:isOpen() then
				return
			end
			-- closing a preview changes nothing else: ownership and what is worn stay exactly as they were
			selected = { Paint = equipped.Paint, Decals = equipped.Decals, Wheels = equipped.Wheels }
			mode = "browse"
			dragging = nil
			dragTrove:Clean()
			refreshAll()
			overlay:close()
			refreshAnimator()
			if opts.onClose then
				opts.onClose()
			end
		end,
		isOpen = function(_self: Customize): boolean
			return overlay:isOpen()
		end,
		selectTab = function(_self: Customize, id: TabId)
			if tab == id then
				return
			end
			tab = id
			mode = "browse"
			for tabId, tb in tabs do
				tb.set(tabId == id)
			end
			showTab()
			refreshAll()
		end,
		select = function(_self: Customize, itemId: string): boolean
			local item = itemById(tab, itemId)
			if not item then
				return false
			end
			selected[tab] = itemId
			mode = "browse"
			refreshAll()
			return true
		end,
		pressEquip = function(_self: Customize): boolean
			local item = currentItem()
			if not item or stateOf(item) ~= "owned" then
				return false -- worn already, locked, priced, unavailable: nothing to equip
			end
			local worn: any = equipped
			worn[tab] = item.id
			equipCalls += 1
			refreshAll()
			if opts.onEquip then
				opts.onEquip(tab, item)
			end
			return true
		end,
		pressBuy = function(_self: Customize): boolean
			local item = currentItem()
			if not item or stateOf(item) ~= "priced" then
				return false -- locked, owned, worn or unavailable: there is nothing to buy
			end
			if balance < item.price then
				mode = "short" -- not enough PREVIEW Cash: say so, with BACK and VIEW SHOP
				refreshAll()
				return false
			end
			-- a PREVIEW purchase: this screen's own copy of the fixture changes, nothing else anywhere
			balance -= item.price
			ownership.owned[item.id] = true
			buyCalls += 1
			table.insert(purchased, item.id)
			mode = "browse"
			refreshAll()
			if opts.onBuy then
				opts.onBuy(tab, item)
			end
			return true
		end,
		pressBack = function(_self: Customize)
			if mode == "short" then
				mode = "browse"
				refreshAll()
			end
		end,
		pressViewShop = function(_self: Customize)
			if mode ~= "short" then
				return
			end
			mode = "browse"
			refreshAll()
			if opts.onViewShop then
				opts.onViewShop() -- navigation only: the Shop opens its own flow, this screen never prompts a purchase
				customize:close()
			end
		end,
		setBalance = function(_self: Customize, amount: number)
			balance = math.max(0, math.floor(amount))
			mode = "browse"
			refreshAll()
		end,
		getBalance = function(_self: Customize): number
			return balance
		end,
		rotate = function(_self: Customize, degrees: number)
			yaw = (yaw + degrees) % 360
			applyYaw()
		end,
		setSpin = function(_self: Customize, on: boolean)
			spin = on
		end,
		setOwnership = function(_self: Customize, o: Catalog.Ownership)
			fixtureOwnership = o
			ownership = copyOwnership(o)
			initialChecksum = checksum(o)
			mode = "browse"
			refreshAll()
		end,
		setEquipped = function(_self: Customize, e: Catalog.Equipped)
			equipped = table.clone(e)
			selected = { Paint = equipped.Paint, Decals = equipped.Decals, Wheels = equipped.Wheels }
			refreshAll()
		end,
		destroy = function(_self: Customize)
			overlay:destroy()
		end,
		getDebugState = function(_self: Customize): DebugState
			local item = currentItem()
			local state = if item then stateOf(item) else "unavailable"
			local counts: { [string]: number } = {}
			local tiers: { [string]: number } = {}
			local tileCount = 0
			local view = views[tab]
			if view then
				for _, t in view.tiles do
					local s = stateOf(t.item)
					counts[s] = (counts[s] or 0) + 1
					tiers[t.item.tier] = (tiers[t.item.tier] or 0) + 1
					tileCount += 1
				end
			end
			local previewing: { [string]: boolean } = {}
			for _, id in Catalog.Tabs do
				previewing[id] = isPreviewing(id)
			end
			local bodyColour = {
				math.floor(rig.body.Color.R * 255 + 0.5),
				math.floor(rig.body.Color.G * 255 + 0.5),
				math.floor(rig.body.Color.B * 255 + 0.5),
			}
			local eq, buy = equipButton, buyButton
			return {
				open = overlay:isOpen(),
				kind = overlay:kind(),
				fit = geo.fit,
				tab = tab,
				selected = table.clone(selected),
				equipped = table.clone(equipped :: any),
				previewing = previewing,
				state = state,
				stateWord = (STATE_WORDS :: any)[state] or state,
				mode = mode,
				status = nameLabel.Text,
				detail = infoLabel.Text,
				note = noteLabel.Text,
				equipLabel = if eq then eq.label.Text else "",
				buyLabel = if buy then buy.label.Text else "",
				equipEnabled = state == "owned",
				buyVisible = buy ~= nil and buy.root.Visible,
				tiles = tileCount,
				counts = counts,
				tiers = tiers,
				groups = tiers,
				itemCounts = Catalog.counts(),
				balance = balance,
				buyCalls = buyCalls,
				purchased = table.clone(purchased),
				carPaint = bodyColour,
				carDecal = carDecalId,
				carWheels = carWheelId,
				paintAnimated = CosmeticCar.isAnimated(rig.paint),
				paintUpdates = paintUpdates,
				paintPhase = paintPhase,
				bands = #rig.bands,
				decalParts = rig.decalParts,
				wheelParts = rig.wheelParts,
				renderNote = if item then item.render .. ": " .. item.note else "",
				spinning = spin and not Motion.reduced() and dragging == nil,
				dragging = dragging ~= nil,
				yaw = yaw,
				ownershipChecksum = checksum(fixtureOwnership),
				ownershipUntouched = checksum(fixtureOwnership) == initialChecksum,
				equipCalls = equipCalls,
				caption = preview.label.Text,
				instances = #overlay.root:GetDescendants(),
			}
		end,
		touchReport = function(_self: Customize): { { name: string, w: number, h: number } }
			local ds = overlay:designSize()
			local ratio = if ds.X > 0 then overlay.content.AbsoluteSize.X / ds.X else 1
			return SupportKit.touchReport(overlay.root, ratio)
		end,
	}

	for id, tb in tabs do
		tb.set(id == tab)
	end
	applyYaw()
	layoutNow()
	return customize
end

return StuntCustomize
