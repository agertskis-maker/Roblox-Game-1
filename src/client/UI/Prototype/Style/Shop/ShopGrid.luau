--!strict
-- ShopGrid (Lane 3 Round 8, C-06, C-07, W-04, T-09): the Style Shop's grid of item tiles, in the reference's look (R8-IMG-13, 16 and
-- 18): cream tiles with a navy line (the Wheels tab's dark with a cream label bar, the Trails tab's with a tier-coloured line),
-- the name, a price pill, a green check on everything owned, a ring on the tile being tried or worn.
--
--   PAINT and DECALS tiles show YOUR selected car (TileCar: a static ViewportFrame with a low-detail copy of it, in the paint or
--   decal of that tile). They are built a few at a time, only for the rows on screen, and rebuilt when the car or the look the
--   tiles wear changes. Only the hovered or selected tile turns.
--   WHEELS tiles show the rim icon r8_wheel_icon_<item id>, TRAILS tiles the trail icon r8_trail_icon_<item id> (both made by the
--   wheel and trail workstreams); until an icon is uploaded the tile draws the Round 7 art, so it is never empty.
--
--   local grid = ShopGrid.new(scroll: ScrollingFrame, options)
--   grid:refresh(previewedId: string?)     repaint every tile's state
--   grid:redrawCars()                      the car or the worn look changed: rebuild the car tiles that are on screen
--   grid:step(dt, activeId: string?, still: boolean?)   builds waiting tiles (at most one a frame), turns the one tile in motion
--   grid:count() -> number    grid:builtCars() -> number    grid:destroy()

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Prototype = script.Parent.Parent.Parent
local CarKit = require(Prototype.CarKit)
local GameIcons = require(Prototype.GameIcons)
local ShopLook = require(script.Parent.ShopLook)
local StyleState = require(Prototype.StyleState)
local TileCar = require(script.Parent.TileCar)
local AssetIds = require(ReplicatedStorage.Shared.Style.AssetIds)
local Catalog = require(ReplicatedStorage.Shared.UI.CosmeticPreviewCatalog)
local Format = require(ReplicatedStorage.Shared.UI.Format)
local Trove = require(ReplicatedStorage.Packages.Trove)

local make = CarKit.make

local ShopGrid = {}
ShopGrid.__index = ShopGrid

export type Options = {
	tab: string,
	phone: boolean,
	columns: number,
	cellW: number,
	cellH: number,
	padding: number,
	z: number,
	onPick: (id: string) -> (),
	robuxWord: string?,
}

-- the reference's palette (GENERATION-NOTES): cream, navy, orange, green, gold
local CREAM = Color3.fromRGB(255, 244, 218)
local NAVY = Color3.fromRGB(20, 33, 63)
local ORANGE = Color3.fromRGB(244, 119, 22)
local GREEN = Color3.fromRGB(73, 200, 87)
local GREEN_DEEP = Color3.fromRGB(34, 150, 58)
local GOLD = Color3.fromRGB(247, 198, 76)
local PILL = Color3.fromRGB(255, 232, 150)
local GREY = Color3.fromRGB(150, 158, 178)
local WHITE = Color3.new(1, 1, 1)

local KEEP_ROWS = 1 -- car tiles further than this many rows off screen are let go
local BUILD_ROWS = 1 -- and tiles this close to the screen are built ahead of the scroll

local function text(
	parent: Instance,
	words: string,
	size: UDim2,
	position: UDim2,
	maxPx: number,
	color: Color3,
	z: number
)
	local label = make("TextLabel", {
		Name = "Label",
		BackgroundTransparency = 1,
		FontFace = CarKit.body(),
		Text = words,
		TextColor3 = color,
		TextScaled = true,
		Size = size,
		Position = position,
		ZIndex = z,
	}, parent) :: TextLabel
	make("UITextSizeConstraint", { MaxTextSize = maxPx, MinTextSize = 8 }, label)
	return label
end

-- a check mark from two rotated bars, so it needs no font glyph and no picture
local function checkMark(parent: Instance, color: Color3, z: number)
	for _, leg in { { 0.31, 0.6, 0.3, 45 }, { 0.58, 0.5, 0.55, -52 } } do
		local bar = make("Frame", {
			Name = "CheckLeg",
			BackgroundColor3 = color,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(leg[1], leg[2]),
			Size = UDim2.fromScale(leg[3], 0.13),
			Rotation = leg[4],
			ZIndex = z,
		}, parent)
		make("UICorner", { CornerRadius = UDim.new(1, 0) }, bar)
	end
end

local function coin(parent: Instance, px: number, z: number): Frame
	local c = make("Frame", {
		Name = "Coin",
		BackgroundColor3 = GOLD,
		AnchorPoint = Vector2.new(0, 0.5),
		Size = UDim2.fromOffset(px, px),
		ZIndex = z,
	}, parent) :: Frame
	make("UICorner", { CornerRadius = UDim.new(1, 0) }, c)
	make(
		"UIStroke",
		{ Thickness = 1.5, Color = Color3.fromRGB(176, 118, 20), ApplyStrokeMode = Enum.ApplyStrokeMode.Border },
		c
	)
	make(
		"UIGradient",
		{ Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(255, 232, 120), Color3.fromRGB(240, 170, 30)) },
		c
	)
	text(
		c,
		"$",
		UDim2.fromScale(1, 0.84),
		UDim2.fromScale(0, 0.08),
		math.max(px - 6, 8),
		Color3.fromRGB(150, 92, 8),
		z + 1
	)
	return c
end

local function priceText(item: Catalog.Item, robuxWord: string): string
	if item.robux then
		return robuxWord -- the product's real price is not known yet, so no price number is shown
	end
	return Format.cash(item.price)
end

local function tierEdges(tab: string): { [string]: Color3 }
	local out: { [string]: Color3 } = {}
	for _, t in Catalog.Tiers[tab] do
		out[t.id] = (CarKit.Rarity :: any)[t.rarity]
	end
	return out
end

function ShopGrid.new(scroll: ScrollingFrame, o: Options): any
	local self = setmetatable({}, ShopGrid) :: any
	self._trove = Trove.new()
	self._scroll = scroll
	self._o = o
	self._cards = {} :: { [string]: any }
	self._order = {} :: { any }
	self._active = nil :: string?
	self._hover = nil :: string?
	self._previewed = nil :: string?
	self._carSig = ""
	local tab = o.tab
	local edges = tierEdges(tab)
	local phone = o.phone
	local robuxWord = o.robuxWord or "ROBUX"
	local cashTab = tab == "Paint" or tab == "Decals"
	local darkTile = tab == "Wheels"
	self._carTab = cashTab

	for _, c in scroll:GetChildren() do
		if not c:IsA("UIGridLayout") then
			c:Destroy()
		end
	end

	local thumbFrac = if darkTile then 0.6 elseif tab == "Trails" then 0.56 else 0.58
	for order, item in Catalog.itemsFor(tab :: any) do
		local rarityName = "Common"
		for _, t in Catalog.Tiers[tab] do
			if t.id == item.tier then
				rarityName = t.rarity
			end
		end
		local vipTile = item.robux ~= nil or item.vip == true
		local line = if tab == "Trails" then (if vipTile then GOLD else edges[item.tier] or GREY) else NAVY
		local button = make("TextButton", {
			Name = "Item_" .. item.id,
			Text = "",
			AutoButtonColor = false,
			BackgroundColor3 = if darkTile or (tab == "Trails" and vipTile) then NAVY else CREAM,
			LayoutOrder = order,
			ZIndex = o.z,
			Selectable = true,
		}, scroll) :: TextButton
		make("UICorner", { CornerRadius = UDim.new(0, 12) }, button)
		make("UIStroke", { Thickness = 2.5, Color = line, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, button)

		-- the picture
		local holder = make("Frame", {
			Name = "Thumb",
			BackgroundTransparency = 1,
			Position = UDim2.fromScale(0.04, 0.03),
			Size = UDim2.fromScale(0.92, thumbFrac - 0.03),
			ZIndex = o.z + 1,
		}, button) :: Frame

		-- the name and the price: on a cream bar on the Wheels tab, straight on the tile elsewhere
		local info = make("Frame", {
			Name = "Info",
			BackgroundColor3 = CREAM,
			BackgroundTransparency = if darkTile then 0 else 1,
			Position = UDim2.fromScale(0.04, thumbFrac + 0.02),
			Size = UDim2.fromScale(0.92, 0.96 - thumbFrac),
			ZIndex = o.z + 1,
		}, button) :: Frame
		if darkTile then
			make("UICorner", { CornerRadius = UDim.new(0, 9) }, info)
		end
		local nameColor = if tab == "Trails" and vipTile then WHITE else NAVY
		local name = text(
			info,
			item.name,
			UDim2.fromScale(0.96, 0.5),
			UDim2.fromScale(0.02, 0.02),
			if phone then 14 else 20,
			nameColor,
			o.z + 3
		)
		name.Name = "Name"
		local pill = make("Frame", {
			Name = "PricePill",
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.fromScale(0.5, 0.96),
			Size = UDim2.fromScale(0.84, 0.42),
			BackgroundColor3 = PILL,
			ZIndex = o.z + 2,
		}, info) :: Frame
		make("UICorner", { CornerRadius = UDim.new(1, 0) }, pill)
		local pillCoin = coin(pill, if phone then 15 else 20, o.z + 3)
		pillCoin.Position = UDim2.new(0, 6, 0.5, 0)
		local pillText = text(
			pill,
			"",
			UDim2.new(1, -34, 0.82, 0),
			UDim2.new(0, 30, 0.09, 0),
			if phone then 14 else 19,
			NAVY,
			o.z + 3
		)
		pillText.Name = "Price"
		pillText.TextXAlignment = Enum.TextXAlignment.Center
		local pillCheck = make("Frame", {
			Name = "PillCheck",
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 8, 0.5, 0),
			Size = UDim2.fromOffset(if phone then 15 else 20, if phone then 15 else 20),
			ZIndex = o.z + 3,
			Visible = false,
		}, pill) :: Frame
		checkMark(pillCheck, WHITE, o.z + 4)

		-- a green check on every owned item, a ring on the tile being tried or worn
		local badgePx = if phone then 24 else 32
		local badge = make("Frame", {
			Name = "OwnedCheck",
			BackgroundColor3 = GREEN,
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -4, 0, 4),
			Size = UDim2.fromOffset(badgePx, badgePx),
			ZIndex = o.z + 6,
			Visible = false,
		}, button) :: Frame
		make("UICorner", { CornerRadius = UDim.new(1, 0) }, badge)
		make("UIStroke", { Thickness = 2, Color = WHITE, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, badge)
		checkMark(badge, WHITE, o.z + 7)
		local lock = CarKit.slot(button, "lock", 32, { position = UDim2.new(1, -20, 0, 36), z = o.z + 6 })
		lock.Visible = false
		local ring = make("Frame", {
			Name = "Selected",
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			ZIndex = o.z + 5,
			Visible = false,
		}, button) :: Frame
		make("UICorner", { CornerRadius = UDim.new(0, 12) }, ring)
		local ringLine = make(
			"UIStroke",
			{ Thickness = 4, Color = ORANGE, ApplyStrokeMode = Enum.ApplyStrokeMode.Border },
			ring
		) :: UIStroke

		local index = #self._order
		local card = {
			item = item,
			rarity = rarityName,
			button = button,
			holder = holder,
			pill = pill,
			pillText = pillText,
			pillCoin = pillCoin,
			pillCheck = pillCheck,
			badge = badge,
			lock = lock,
			ring = ring,
			ringLine = ringLine,
			index = index,
			vipTile = vipTile,
			tile = nil :: any,
			robuxWord = robuxWord,
		}
		self._cards[item.id] = card
		table.insert(self._order, card)
		self:_drawStatic(card)
		self._trove:Connect(button.Activated, function()
			o.onPick(item.id)
		end)
		self._trove:Connect(button.MouseEnter, function()
			self._hover = item.id
		end)
		self._trove:Connect(button.MouseLeave, function()
			if self._hover == item.id then
				self._hover = nil
			end
		end)
	end
	self:refresh(nil)
	return self
end

-- A rim drawn from the item's colours, for a wheel with neither an uploaded icon nor Round 7 art: a dark tyre, the rim, a hub.
local function drawnRim(holder: Frame, item: Catalog.Item, z: number)
	local function disc(name: string, scale: number, colour: Color3, order: number): Frame
		local d = make("Frame", {
			Name = name,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.46),
			Size = UDim2.fromScale(scale, scale),
			SizeConstraint = Enum.SizeConstraint.RelativeYY,
			BackgroundColor3 = colour,
			ZIndex = z + order,
		}, holder) :: Frame
		make("UICorner", { CornerRadius = UDim.new(1, 0) }, d)
		return d
	end
	disc("Tyre", 0.84, Color3.fromRGB(22, 24, 34), 0)
	local rim = disc("Rim", 0.56, item.colours[1], 1)
	make(
		"UIStroke",
		{ Thickness = 2, Color = item.colours[2] or item.colours[1], ApplyStrokeMode = Enum.ApplyStrokeMode.Border },
		rim
	)
	disc("Hub", 0.16, Color3.fromRGB(70, 76, 96), 2)
end

-- The picture of a tile that does not show a car. Wheels and Trails: the uploaded icon, else Round 7's art.
function ShopGrid._drawStatic(self: any, card: any)
	local item: Catalog.Item = card.item
	local holder: Frame = card.holder
	local z = self._o.z + 2
	if item.tab == "Paint" or item.tab == "Decals" then
		-- placeholder until the car tile is built: a calm rounded shape
		local shape = make("Frame", {
			Name = "Waiting",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0.5, 0.4),
			BackgroundColor3 = NAVY,
			BackgroundTransparency = 0.9,
			ZIndex = z,
		}, holder)
		make("UICorner", { CornerRadius = UDim.new(0.3, 0) }, shape)
		return
	end
	local keyPrefix = if item.tab == "Wheels" then "r8_wheel_icon_" else "r8_trail_icon_"
	local uri = AssetIds.image(keyPrefix .. item.id)
	if item.tab == "Wheels" then
		holder.BackgroundTransparency = 0
		holder.BackgroundColor3 = Color3.fromRGB(14, 24, 50)
		make("UICorner", { CornerRadius = UDim.new(0, 9) }, holder)
	end
	if uri ~= "" then
		make("ImageLabel", {
			Name = "Icon",
			BackgroundTransparency = 1,
			Image = uri,
			ScaleType = Enum.ScaleType.Fit,
			Size = UDim2.fromScale(1, 1),
			ZIndex = z,
		}, holder)
	elseif item.isNone then
		CarKit.art(holder, "close", { z = z, placeholder = false, size = UDim2.fromScale(0.5, 0.7) })
	elseif item.tab == "Wheels" then
		if GameIcons.uri("thumb_wheel_" .. (item.key or "")) then
			CarKit.art(
				holder,
				"thumb_wheel_" .. (item.key or ""),
				{ z = z, placeholder = false, size = UDim2.fromScale(0.86, 0.86) }
			)
		else
			drawnRim(holder, item, z)
		end
		-- Round 7's art is one picture per rim shape: the tile's own colour shows which finish this is
		local swatch = make("Frame", {
			Name = "Finish",
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.fromScale(0.5, 0.97),
			Size = UDim2.fromScale(0.34, 0.07),
			BackgroundColor3 = item.colours[1],
			ZIndex = z + 1,
		}, holder)
		make("UICorner", { CornerRadius = UDim.new(1, 0) }, swatch)
	else
		-- the trail's colours as a fading streak
		local stops = {}
		for i, c in item.colours do
			table.insert(stops, ColorSequenceKeypoint.new((i - 1) / math.max(#item.colours - 1, 1), c))
		end
		if #stops == 1 then
			table.insert(stops, ColorSequenceKeypoint.new(1, item.colours[1]))
		end
		for row = 0, 2 do
			local streak = make("Frame", {
				Name = "Streak",
				BackgroundColor3 = WHITE,
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.3 + row * 0.2),
				Size = UDim2.fromScale(0.84 - row * 0.12, 0.14),
				ZIndex = z,
			}, holder)
			make("UICorner", { CornerRadius = UDim.new(1, 0) }, streak)
			make("UIGradient", { Color = ColorSequence.new(stops), Transparency = NumberSequence.new(0, 0.85) }, streak)
		end
	end
end

local function stateOf(item: Catalog.Item): Catalog.ItemState
	local s = StyleState.get()
	return Catalog.stateOf(item, s.ownership, (s.equipped :: any)[item.tab])
end

function ShopGrid.refresh(self: any, previewedId: string?)
	self._previewed = previewedId
	local equippedId = (StyleState.get().equipped :: any)[self._o.tab]
	for _, card in self._order do
		local item: Catalog.Item = card.item
		local state = stateOf(item)
		local owned = state == "equipped" or state == "owned"
		local selected = (previewedId or equippedId) == item.id
		local pill: Frame = card.pill
		local label: TextLabel = card.pillText
		local dark = card.vipTile and item.tab == "Trails"
		card.ring.Visible = selected
		card.ringLine.Color = if state == "equipped" and (previewedId == nil or previewedId == item.id)
			then GREEN
			else ORANGE
		card.badge.Visible = owned and not item.isNone
		card.lock.Visible = state == "locked"
		card.pillCoin.Visible = state == "priced" and not item.robux
		card.pillCheck.Visible = owned
		pill.BackgroundColor3 = PILL
		label.TextColor3 = NAVY
		label.Position = UDim2.new(0, 30, 0.09, 0)
		label.Size = UDim2.new(1, -34, 0.82, 0)
		if state == "equipped" then
			label.Text = "EQUIPPED"
			pill.BackgroundColor3 = GREEN_DEEP
			label.TextColor3 = WHITE
		elseif state == "owned" then
			label.Text = "OWNED"
			pill.BackgroundColor3 = GREEN
			label.TextColor3 = WHITE
		elseif state == "locked" then
			label.Text = if item.vip then "VIP PASS" else "WIN " .. string.upper(item.medal or "")
			pill.BackgroundColor3 = if dark then NAVY else GREY
			label.TextColor3 = WHITE
			label.Position = UDim2.new(0, 6, 0.09, 0)
			label.Size = UDim2.new(1, -12, 0.82, 0)
		elseif state == "unavailable" then
			label.Text = "N/A"
			pill.BackgroundColor3 = GREY
			label.TextColor3 = WHITE
			label.Position = UDim2.new(0, 6, 0.09, 0)
			label.Size = UDim2.new(1, -12, 0.82, 0)
		else
			label.Text = priceText(item, card.robuxWord)
			if item.robux then
				pill.BackgroundColor3 = if dark then Color3.fromRGB(40, 56, 104) else NAVY
				label.TextColor3 = GOLD
				label.Position = UDim2.new(0, 6, 0.09, 0)
				label.Size = UDim2.new(1, -12, 0.82, 0)
			elseif item.price <= 0 then
				label.Text = "FREE"
				label.Position = UDim2.new(0, 6, 0.09, 0)
				label.Size = UDim2.new(1, -12, 0.82, 0)
			end
		end
		if owned then
			label.Position = UDim2.new(0, 30, 0.09, 0)
			label.Size = UDim2.new(1, -34, 0.82, 0)
		end
	end
end

-- The car (or the paint, decal and wheels the tiles wear) changed: every built car tile is let go and the ones on screen rebuild.
function ShopGrid.redrawCars(self: any)
	if not self._carTab then
		return
	end
	for _, card in self._order do
		self:_release(card)
	end
end

function ShopGrid._release(_self: any, card: any)
	card.tileFailed = nil
	local fallback = card.holder:FindFirstChild("Fallback")
	if fallback then
		fallback:Destroy()
	end
	if card.tile then
		card.tile:destroy()
		card.tile = nil
	end
	local waiting = card.holder:FindFirstChild("Waiting")
	if waiting then
		(waiting :: GuiObject).Visible = true
	end
end

function ShopGrid.count(self: any): number
	return #self._order
end

function ShopGrid.builtCars(self: any): number
	local n = 0
	for _, card in self._order do
		if card.tile then
			n += 1
		end
	end
	return n
end

-- Rows on screen, from the scroll position.
function ShopGrid._window(self: any): (number, number)
	local o: Options = self._o
	local rowH = o.cellH + o.padding
	local top = self._scroll.CanvasPosition.Y
	local height = math.max(self._scroll.AbsoluteWindowSize.Y, o.cellH * 2)
	return math.floor(top / rowH) - BUILD_ROWS, math.floor((top + height) / rowH) + BUILD_ROWS
end

function ShopGrid.step(self: any, dt: number, activeId: string?, still: boolean?)
	if not self._carTab then
		return
	end
	local o: Options = self._o
	local firstRow, lastRow = self:_window()
	local built = false
	for _, card in self._order do
		local row = card.index // o.columns
		if card.tile then
			if row < firstRow - KEEP_ROWS or row > lastRow + KEEP_ROWS then
				self:_release(card)
			end
		elseif not built and not card.tileFailed and row >= firstRow and row <= lastRow and card.holder.Parent then
			built = true -- one tile a frame, so opening the shop never stalls
			local item: Catalog.Item = card.item
			local look = ShopLook.forTile(StyleState.car(), StyleState.get().equipped :: any, item.tab, item)
			if item.isNone then
				look.decal = nil -- "No decal": the car in its paint, bare
			end
			local aspect = (o.cellW * 0.92) / math.max(o.cellH * 0.55, 1)
			local tile = TileCar.new(card.holder, look, { z = o.z + 2, aspect = aspect })
			if tile then
				card.tile = tile
				local waiting = card.holder:FindFirstChild("Waiting")
				if waiting then
					(waiting :: GuiObject).Visible = false
				end
			else
				card.tileFailed = true -- no model of this car here: the tile keeps Round 7's drawing
				self:_fallbackCar(card)
			end
		end
	end
	-- only the hovered tile, or the one being tried or worn, turns; the others rest
	local moving = if still then nil else (self._hover or activeId)
	for id, card in self._cards do
		if card.tile then
			if id == moving then
				card.tile:turn(dt)
			else
				card.tile:rest()
			end
		end
	end
end

-- No model of the car in this place: the old drawn car in the paint colour, so the tile is never empty.
function ShopGrid._fallbackCar(self: any, card: any)
	local item: Catalog.Item = card.item
	local z = self._o.z + 2
	local waiting = card.holder:FindFirstChild("Waiting")
	if waiting then
		(waiting :: GuiObject).Visible = false
	end
	local box = make(
		"Frame",
		{ Name = "Fallback", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = z },
		card.holder
	)
	if item.tab == "Paint" then
		CarKit.art(box, "thumb_car_body", { z = z, placeholder = false, color = item.colours[1] })
		CarKit.art(box, "thumb_car_top", { z = z + 2, placeholder = false })
	elseif item.isNone then
		CarKit.art(box, "close", { z = z, placeholder = false, size = UDim2.fromScale(0.5, 0.7) })
	elseif item.key then
		CarKit.art(box, "thumb_decal_" .. item.key, { z = z, placeholder = false })
	end
end

function ShopGrid.getCard(self: any, id: string): any
	return self._cards[id]
end

function ShopGrid.destroy(self: any)
	for _, card in self._order do
		if card.tile then
			card.tile:destroy()
			card.tile = nil
		end
	end
	self._trove:Destroy()
end

return ShopGrid
