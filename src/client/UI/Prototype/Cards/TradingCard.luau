--!strict
-- TradingCard: the reusable collectible card (Lane 3 preview, Round 2, R2-T2). It EXTENDS CarCard (rarity frame,
-- label and pips, name fitting, ViewportFrame stage, unowned silhouette, variant ring) rather than rebuilding it,
-- and adds the collectible layer: a family icon, a World scene behind the car, a NEW flag, the Epic / Legendary
-- foil sheen, a controlled metallic inner edge, the SECURED stamp and the reward plate with the supplied Lap Pay.
-- The detail view (Screens/CardDetail) shows SIX facts only, built by TradingCard.detailFacts from the same data.
--
--   local card = TradingCard.new(parent, car, info?, { variant = "Compact" | "Reward", stamp = "SECURED"? })
--   card:setInfo(info)   card:setCar(car)   card:setVisible(on)   card:setStamp(text?)
--   card.root            -- Frame (Reward = the card plus its plate underneath)
--   card:getDebugState()   card:destroy()
--   TradingCard.familyIcon(car, info?) -> (iconName, mapped: boolean)
--   TradingCard.detailFacts(car, info?) -> Facts   -- the six player facts of the detail view (pure)
--
-- VARIANTS. Reward (the secured reveal and Results): the full portrait card, a family icon, the World badge, the
-- NEW flag, the stamp and a plate with Lap Pay. Compact (image, name, rarity, NEW) is kept for a small preview; the
-- collection sheet no longer lists compact copies of cards (Round 3).
--
-- TRUTH (R2-T2, R3). Every number comes from `info` or the car as supplied. Lap Pay shows only when supplied; an
-- unknown value reads "?". NEW shows only on info.isNew == true. Variants: true = owned, false = not owned, nil =
-- unknown ("?"). Rarity and variant finishes stay separate dimensions. Family "Bus" (a fixture name) maps to the Truck
-- icon and is flagged. `fineRows` / `lapRows` (the Round 2 fine print, with its per-second row) are no longer drawn
-- by any screen; they stay only because the Round 2 truth scenario still reads them (see the Round 3 notes).
--
-- FOIL (Epic, Legendary). One slow masked sheen across the art window only, restrained spectral colour (pale
-- cyan, white, pale rose), under no text: names, pips and rows sit outside the mask on their own dark panels.
-- It runs on one shared ticker (at most FOIL_LIMIT cards at once, only while shown) and holds a static, pleasant
-- angle in reduced motion or when the card is hidden. Placeholder proxy models stay labelled by CarCard’s PROXY tag.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Prototype = script.Parent.Parent
local Arcade = require(Prototype.Arcade)
local CarCard = require(script.Parent.CarCard)
local Format = require(ReplicatedStorage.Shared.UI.Format)
local Motion = require(Prototype.Motion)
local PreviewTokens = require(Prototype.PreviewTokens)
local Trove = require(ReplicatedStorage.Packages.Trove)

local make = Arcade.make

local TradingCard = {}
TradingCard.__index = TradingCard

export type CarRef = CarCard.CarRef
export type Stat = { label: string, value: string, bar: number?, scale: string? }
export type Info = {
	world: string?, -- "Downtown" | "DustyHighway" | "SummitPass"
	family: string?, -- overrides car.family for the icon
	lapPay: number?, -- dollars per lap, as supplied
	lapSeconds: number?, -- a DEFINED lap duration in seconds; nil = undefined
	stats: { Stat }?, -- only values the game really has (bars need a documented shared scale)
	quirkLine: string?, -- one truthful line
	variants: { Gold: boolean?, Chrome: boolean?, Rainbow: boolean? }?,
	flavour: string?,
	collectionNo: number?,
	collectionTotal: number?,
	claimedAt: string?, -- a preformatted date, ONLY when it exists
	acquiredAt: number?, -- when the player got the car, as a supplied number (larger = newer); NEWEST sorts on this only
	isNew: boolean?,
}
export type Options = { variant: string?, stamp: string?, name: string? }

local FOIL_LIMIT = 4
local SHEEN_SECONDS = 1.9 -- one sweep
local SHEEN_PAUSE = 2.4 -- then a long still moment
local FROZEN_OFFSET = 0.12 -- the static, pleasant angle (reduced motion, hidden, over the limit)

local WORLDS: { [string]: { name: string, top: Color3, bottom: Color3, tag: Color3 } } = {
	Downtown = {
		name = "Downtown",
		top = Color3.fromRGB(84, 168, 255),
		bottom = Color3.fromRGB(214, 200, 176),
		tag = Color3.fromRGB(52, 168, 255),
	},
	DustyHighway = {
		name = "Dusty Highway",
		top = Color3.fromRGB(120, 190, 236),
		bottom = Color3.fromRGB(240, 190, 120),
		tag = Color3.fromRGB(255, 138, 36),
	},
	SummitPass = {
		name = "Summit Pass",
		top = Color3.fromRGB(70, 140, 226),
		bottom = Color3.fromRGB(226, 238, 252),
		tag = Color3.fromRGB(150, 130, 255),
	},
}

local FAMILY_ICON: { [string]: string } = {
	Compact = "Family_Compact",
	Sedan = "Family_Sedan",
	Pickup = "Family_Pickup",
	Van = "Family_Van",
	Motorcycle = "Family_Motorcycle",
	Truck = "Family_Truck",
	Sports = "Family_Sports",
	Special = "Family_Special",
	Bus = "Family_Truck", -- a fixture name; the outline family is Truck (flagged as mapped)
}

TradingCard.Worlds = WORLDS

function TradingCard.familyIcon(car: CarCard.CarRef, info: Info?): (string, boolean)
	local family = (info and info.family) or car.family
	local icon = FAMILY_ICON[family]
	if icon then
		return icon, family == "Bus"
	end
	return "Family_Special", true -- unknown family: the neutral special silhouette, flagged
end

----------------------------------------------------------------------------------------------
-- The shared foil ticker

local foils: { [any]: boolean } = {}
local foilConnection: RBXScriptConnection? = nil

local function foilCount(): number
	local n = 0
	for _ in foils do
		n += 1
	end
	return n
end

local function stopFoilTicker()
	if foilConnection and foilCount() == 0 then
		foilConnection:Disconnect()
		foilConnection = nil
	end
end

local function startFoilTicker()
	if foilConnection then
		return
	end
	foilConnection = RunService.RenderStepped:Connect(function(dt: number)
		for card in foils do
			(card :: any):_sheenTick(dt)
		end
	end)
end

----------------------------------------------------------------------------------------------

local function isShown(gui: GuiObject): boolean
	local node: Instance? = gui
	while node and node ~= game do
		if node:IsA("GuiObject") and not (node :: GuiObject).Visible then
			return false
		elseif node:IsA("ScreenGui") and not (node :: ScreenGui).Enabled then
			return false
		end
		node = node.Parent
	end
	return node == game
end

function TradingCard.new(parent: Instance, car: CarCard.CarRef, info: Info?, options: Options?)
	local self = setmetatable({}, TradingCard)
	local opts: Options = options or {}
	self._trove = Trove.new()
	self._car = car
	self._info = info or {}
	self._variant = if opts.variant == "Compact" then "Compact" else "Reward"
	self._visible = true
	self._phase = 0
	self._offset = FROZEN_OFFSET
	self._sheenOn = false
	self._checkAt = 0
	self._sheenLive = false
	self._onScreen = true
	self._stage = nil :: any
	self._metal = nil :: any
	self._sheenFrame = nil :: any
	self._sheenGrad = nil :: any
	self._familyBadge = nil :: any
	self._worldBadge = nil :: any
	self._worldText = nil :: any
	self._newFlag = nil :: any
	self._plate = nil :: any
	self._lapValue = nil :: any
	self._iconName = ""
	self._iconMapped = false

	local compact = self._variant == "Compact"
	local size = if compact then CarCard.MinSize else CarCard.BaseSize -- the smallest card (132 x 160)
	self._size = size
	local plateH = if compact then 0 else 52
	self._plateH = plateH
	local root = self._trove:Add(make("Frame", {
		Name = opts.name or ("TradingCard_" .. car.id),
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(size.X, size.Y + plateH),
		Parent = parent,
	}))
	self.root = root
	local card = CarCard.new(root, car, { size = size, spinning = false })
	self._trove:Add(function()
		card:destroy()
	end)
	self._card = card

	local stage = card.root:FindFirstChild("Stage", true) :: Frame?
	self._stage = stage
	if stage then
		-- the metallic inner edge: a controlled thin light stroke, never a second heavy outline
		local metal = make("Frame", {
			Name = "MetalEdge",
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			ZIndex = 12,
			Parent = stage,
		})
		Arcade.corner(metal, 5)
		self._metal = make("UIStroke", {
			Thickness = 2,
			Color = Color3.new(1, 1, 1),
			Transparency = 0.45,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			Parent = metal,
		})
		-- the foil sheen: a masked band over the art window only
		local sheen = make("Frame", {
			Name = "FoilSheen",
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = Color3.new(1, 1, 1),
			BackgroundTransparency = 0,
			BorderSizePixel = 0,
			Visible = false,
			ZIndex = 11,
			Parent = stage,
		})
		Arcade.corner(sheen, 5)
		self._sheenFrame = sheen
		self._sheenGrad = make("UIGradient", {
			Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromRGB(190, 240, 255)),
				ColorSequenceKeypoint.new(0.5, Color3.new(1, 1, 1)),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 206, 232)),
			}),
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(0.36, 1),
				NumberSequenceKeypoint.new(0.5, 0.78),
				NumberSequenceKeypoint.new(0.64, 1),
				NumberSequenceKeypoint.new(1, 1),
			}),
			Rotation = 24,
			Offset = Vector2.new(FROZEN_OFFSET, 0),
			Parent = sheen,
		})
		-- the family icon (full cards only; compact cards keep image, name and rarity)
		local icon = make("Frame", {
			Name = "FamilyBadge",
			Position = UDim2.fromOffset(4, 4),
			Size = UDim2.fromOffset(34, 34),
			BackgroundTransparency = 1,
			Visible = not compact,
			ZIndex = 13,
			Parent = stage,
		})
		self._familyBadge = icon
		-- the World badge (bottom-left of the art)
		-- the badge is as wide as its text ("Dusty Highway" is wider than the old fixed 100 px)
		local world = make("Frame", {
			Name = "WorldBadge",
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.new(0, 4, 1, -4),
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromOffset(0, 22),
			BackgroundColor3 = Color3.new(1, 1, 1),
			Visible = false,
			ZIndex = 13,
			Parent = stage,
		})
		Arcade.corner(world, 11)
		Arcade.outline(world, "Minor")
		make("UIPadding", { PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6), Parent = world })
		self._worldBadge = world
		self._worldText = Arcade.text(world, { text = "", role = "Small", name = "Text", autoWidth = true, z = 14 })
		self._worldText.Size = UDim2.fromOffset(0, 22)
		-- the NEW flag (top-right), only on an explicit supplied flag
		local new = make("Frame", {
			Name = "NewFlag",
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -4, 0, 4),
			Size = UDim2.fromOffset(if compact then 44 else 52, 24),
			BackgroundColor3 = Color3.new(1, 1, 1),
			Visible = false,
			ZIndex = 13,
			Parent = stage,
		})
		Arcade.surface(new, "Gold", { outline = "Minor" })
		local newText = Arcade.text(new, { text = "NEW", role = "Badge", name = "Text", z = 14 })
		newText.Size = UDim2.fromScale(1, 1)
		self._newFlag = new
	end
	-- the reward plate under the card: Lap Pay as supplied
	if not compact then
		local plate = make("Frame", {
			Name = "Plate",
			Position = UDim2.fromOffset(0, size.Y + 4),
			Size = UDim2.fromOffset(size.X, plateH - 4),
			BackgroundColor3 = Color3.new(1, 1, 1),
			Parent = root,
		})
		Arcade.surface(plate, "Garage", { outline = "Minor" })
		local label = Arcade.text(plate, {
			text = "LAP PAY",
			role = "Small",
			name = "Label",
			xAlign = Enum.TextXAlignment.Left,
			z = 8,
		})
		label.Position = UDim2.fromOffset(8, 0)
		label.Size = UDim2.new(0.5, -8, 1, 0)
		local value = Arcade.text(plate, {
			text = "",
			role = "Value",
			name = "Value",
			size = 24,
			face = "Cash",
			italic = true,
			xAlign = Enum.TextXAlignment.Right,
			z = 8,
		})
		value.Position = UDim2.fromScale(0.4, 0)
		value.Size = UDim2.new(0.6, -8, 1, 0)
		self._plate = plate
		self._lapValue = value
	end

	self._trove:Add(Motion.onReducedChanged(function()
		self:_applySheen()
	end))
	self._trove:Add(function()
		foils[self] = nil
		stopFoilTicker()
	end)
	if opts.stamp then
		card:setStamp(opts.stamp)
	end
	self:_apply()
	return self
end

export type TradingCard = typeof(TradingCard.new((nil :: any) :: Instance, (nil :: any) :: CarCard.CarRef, nil, nil))

function TradingCard._applySheen(self: TradingCard)
	local frame = self._sheenFrame :: Frame?
	local grad = self._sheenGrad :: UIGradient?
	if not frame or not grad then
		return
	end
	local rarity = self._car.rarity
	local foil = rarity == "Epic" or rarity == "Legendary"
	frame.Visible = foil
	foils[self] = nil
	self._sheenLive = false
	if foil then
		grad.Offset = Vector2.new(FROZEN_OFFSET, 0)
		if not Motion.reduced() and self._visible and foilCount() < FOIL_LIMIT then
			foils[self] = true
			self._sheenLive = true
			self._phase = 0
			startFoilTicker()
		end
	end
	stopFoilTicker()
end

-- One shared tick: a slow sweep, then a long still moment; paused while the card is not on screen.
function TradingCard._sheenTick(self: TradingCard, dt: number)
	local now = os.clock()
	if now >= self._checkAt then
		self._checkAt = now + 0.25
		self._onScreen = isShown(self.root)
	end
	if self._onScreen == false then
		return
	end
	self._phase = (self._phase + dt) % (SHEEN_SECONDS + SHEEN_PAUSE)
	local grad = self._sheenGrad :: UIGradient
	if self._phase < SHEEN_SECONDS then
		local k = self._phase / SHEEN_SECONDS
		grad.Offset = Vector2.new(-1.1 + 2.2 * k, 0)
	else
		grad.Offset = Vector2.new(FROZEN_OFFSET, 0)
	end
end

function TradingCard._apply(self: TradingCard)
	local car, info = self._car, self._info
	local stage = self._stage :: Frame?
	if stage then
		-- the World scene behind the car (a plain gradient; the supported 3D car sits in front)
		local world = WORLDS[info.world or ""]
		local back = stage:FindFirstChildOfClass("UIGradient")
		if back and world and self._variant ~= "Compact" then
			back.Color = ColorSequence.new(world.top, world.bottom)
		end
		local rarity = (PreviewTokens.Rarity :: any)[car.rarity] or PreviewTokens.Rarity.Common
		self._metal.Color = rarity.light:Lerp(Color3.new(1, 1, 1), 0.45)
		-- family icon
		local iconName, mapped = TradingCard.familyIcon(car, info)
		self._iconName, self._iconMapped = iconName, mapped
		local badge = self._familyBadge :: Frame
		badge:ClearAllChildren()
		if self._variant ~= "Compact" then
			Arcade.icon(badge, iconName)
		end
		-- World badge
		local badgeWorld = self._worldBadge :: Frame
		badgeWorld.Visible = world ~= nil and self._variant ~= "Compact"
		if world then
			badgeWorld.BackgroundColor3 = world.tag
			self._worldText.Text = world.name
		end
		-- NEW: only on an explicit supplied flag
		local newFlag = self._newFlag :: Frame
		newFlag.Visible = info.isNew == true
	end
	if self._lapValue then
		self._lapValue.Text = if info.lapPay ~= nil then "$" .. Format.group(math.floor(info.lapPay)) else "?"
	end
	self:_applySheen()
end

function TradingCard.setInfo(self: TradingCard, info: Info)
	self._info = info
	self:_apply()
end

function TradingCard.setCar(self: TradingCard, car: CarCard.CarRef)
	self._car = car
	self._card:setCar(car)
	self:_apply()
end

function TradingCard.setStamp(self: TradingCard, text: string?)
	self._card:setStamp(text)
end

function TradingCard.setVisible(self: TradingCard, on: boolean)
	self._visible = on
	self.root.Visible = on
	self._card:setVisible(on)
	self:_applySheen()
end

function TradingCard.card(self: TradingCard): CarCard.Card
	return self._card
end

function TradingCard.getDebugState(self: TradingCard): { [string]: any }
	local base = self._card:getDebugState()
	local sheenFrame = self._sheenFrame :: Frame?
	return {
		variant = self._variant,
		id = self._car.id,
		rarity = self._car.rarity,
		size = { self.root.Size.X.Offset, self.root.Size.Y.Offset },
		shownName = base.shownName,
		nameFit = base.nameFit,
		nameSize = base.nameSize,
		stamp = base.stamp,
		foil = sheenFrame ~= nil and sheenFrame.Visible,
		foilAnimated = self._sheenLive,
		foilOffset = if self._sheenGrad then (self._sheenGrad :: UIGradient).Offset.X else nil,
		foilCards = foilCount(),
		family = self._iconName,
		familyMapped = self._iconMapped,
		world = self._info.world,
		worldText = if self._worldText then self._worldText.Text else nil,
		newShown = self._newFlag ~= nil and (self._newFlag :: Frame).Visible,
		lapPayText = if self._lapValue then self._lapValue.Text else nil,
		hasPlate = self._plate ~= nil,
		instances = #self.root:GetDescendants(),
	}
end

function TradingCard.destroy(self: TradingCard)
	self._trove:Destroy()
end

----------------------------------------------------------------------------------------------
-- The six detail facts (Round 3): car image, full name, full rarity word, World, Lap Pay per lap, and the three
-- finishes as OWNED / NOT OWNED. Pure (so the scenarios can test it). Nothing else about a car is a detail fact:
-- no per-second figure, Heat, family, quirk, race stat, flavour, number or date.

export type FinishState = "Owned" | "NotOwned" | "Unknown"
export type DetailFacts = {
	name: string, -- the full car name
	rarity: string, -- the full rarity word (COMMON .. LEGENDARY)
	world: string, -- the World name, or "?" when not supplied
	lapPay: string, -- "$220 / lap", or "?" when not supplied (and for a car the player does not own)
	lapPayValue: number?, -- the supplied number, nil when unknown or hidden (sorting reads this, never the text)
	finishes: { { finish: string, state: FinishState } }, -- Gold, Chrome, Rainbow, always in this order
	hidden: boolean, -- the car is not owned: Lap Pay is "?" and no finish is owned
}

TradingCard.Finishes = table.freeze({ "Gold", "Chrome", "Rainbow" })

function TradingCard.detailFacts(car: CarCard.CarRef, info: Info?): DetailFacts
	local data: Info = info or {}
	local hidden = car.owned == false
	local rarity = (PreviewTokens.Rarity :: any)[car.rarity] or PreviewTokens.Rarity.Common
	local world = WORLDS[data.world or ""]
	local pay = if hidden then nil else data.lapPay
	local finishes: { { finish: string, state: FinishState } } = {}
	for _, finish in TradingCard.Finishes do
		local flag = if data.variants then (data.variants :: any)[finish] else nil
		local state: FinishState = if hidden or flag == false
			then "NotOwned"
			elseif flag == true then "Owned"
			else "Unknown"
		table.insert(finishes, { finish = finish, state = state })
	end
	return {
		name = car.name,
		rarity = rarity.label,
		world = if world then world.name else "?",
		lapPay = if pay ~= nil then Format.cash(math.floor(pay)) .. " / lap" else "?",
		lapPayValue = pay,
		finishes = finishes,
		hidden = hidden,
	}
end

----------------------------------------------------------------------------------------------
-- The Round 2 fine print rows. NO SCREEN DRAWS THESE ANY MORE (Round 3: the detail view shows six facts). They stay
-- as pure functions only because the Round 2 truth scenario ("Cards: fine print truth") still reads them; retire
-- both together.

-- A one-line description of what the supplied data says, for the lap pay rows.
function TradingCard.lapRows(info: Info): { { label: string, value: string, note: string? } }
	local rows = {}
	if info.lapPay ~= nil then
		table.insert(rows, { label = "Lap Pay", value = "$" .. Format.group(math.floor(info.lapPay)) .. " / lap" })
	else
		table.insert(rows, { label = "Lap Pay", value = "not set yet" })
	end
	if info.lapPay ~= nil and info.lapSeconds ~= nil and info.lapSeconds > 0 then
		table.insert(rows, {
			label = "Per second",
			value = string.format("$%.1f / s", info.lapPay / info.lapSeconds),
			note = "from a lap of " .. string.format("%.0f", info.lapSeconds) .. " s",
		})
	else
		-- no defined lap duration: never divide by an invented one
		table.insert(
			rows,
			{ label = "Per second", value = "unavailable (proposed)", note = "no lap duration is defined" }
		)
	end
	return rows
end

export type Row = {
	kind: string, -- "Stat" | "Quirk" | "Variants" | "Flavour" | "Footer"
	title: string?,
	value: string?,
	text: string?,
	note: string?,
	bar: number?, -- 0..1, only with a documented shared scale
	chips: { { label: string, state: string } }?, -- state: "Owned" | "Not owned" | "Unknown"
	world: string?,
}

local function chipState(value: boolean?): string
	if value == true then
		return "Owned"
	elseif value == false then
		return "Not owned"
	end
	return "Unknown" -- unknown is not unowned
end

-- The rows of the landscape detail view, from the supplied data only (pure, so it can be tested):
-- an UNOWNED card shows "?" for stats and quirk and leaks nothing about variants, number or date.
function TradingCard.fineRows(car: CarCard.CarRef, info: Info): { Row }
	local rows: { Row } = {}
	local hidden = car.owned == false
	for _, r in TradingCard.lapRows(info) do
		table.insert(rows, {
			kind = "Stat",
			title = r.label,
			value = if hidden then "?" else r.value,
			note = if hidden then nil else r.note,
		})
	end
	for _, st in info.stats or {} do
		table.insert(rows, {
			kind = "Stat",
			title = st.label,
			value = if hidden then "?" else st.value,
			-- a bar needs a documented shared scale; without one the stat is a labelled preview value
			bar = if hidden or st.scale == nil then nil else st.bar,
			note = if hidden then nil elseif st.scale ~= nil then "scale: " .. st.scale else "preview value only",
		})
	end
	table.insert(rows, {
		kind = "Quirk",
		title = car.quirk,
		text = if hidden then "?" else (info.quirkLine or "No description yet"),
	})
	if not hidden then
		local v = info.variants
		table.insert(rows, {
			kind = "Variants",
			chips = {
				{ label = "Gold", state = chipState(v and v.Gold) },
				{ label = "Chrome", state = chipState(v and v.Chrome) },
				{ label = "Rainbow", state = chipState(v and v.Rainbow) },
			},
		})
	end
	if info.flavour then
		table.insert(rows, { kind = "Flavour", text = info.flavour })
	end
	local footer: Row = { kind = "Footer", world = info.world }
	if not hidden and info.collectionNo ~= nil then
		footer.value = if info.collectionTotal ~= nil
			then string.format("No. %d / %d", info.collectionNo, info.collectionTotal)
			else string.format("No. %d", info.collectionNo)
	end
	if not hidden and info.claimedAt ~= nil then
		footer.text = "Claimed " .. info.claimedAt -- only a date that exists, never a generated one
	end
	table.insert(rows, footer)
	return rows
end

return TradingCard
