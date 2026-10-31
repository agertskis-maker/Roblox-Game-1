--!strict
-- SPECIMEN SHEET for the rebuilt arcade HUD (Lane 3 preview, worker HA, 2026-10-22; ledger V-01
-- support, V-02, V-04, S-05). A static review sheet the lead captures in Studio over the real
-- world backdrops, to compare side by side with Adam's two HUD references at matched scale before
-- the look is propagated. Everything is built from the Arcade kit and Icons2; every value shown
-- is a synthetic fixture. It is a harness view: it never shows unless asked, owns no gameplay,
-- sends nothing and saves nothing.
--
--   local specimen = Specimen.new(ctx, { visible = false?, mode = "Composed"? })
--   specimen:setMode("Composed" | "Gallery") -> boolean
--   specimen:getMode() -> string
--   specimen:setBackdropNote(text)      -- e.g. "Backdrop: Main Street lot, 13:30" (caption)
--   specimen:layout(), specimen:setVisible(on), specimen:destroy(), specimen:getDebugState()
--
-- Composed: the menu stack left-centre (Settings small red, Shop rainbow + Gift with drift,
-- Garage + GarageBook + badge "1", Missions + Clipboard + badge "!", the Music toggle), stats
-- bottom-left (CarCount + "47", CashStack + "$682K" as a kit specimen, the italic earning line
-- with a PREVIEW caption), Heat bottom-centre (8 segments, Flame), one Keys state right of centre
-- (gold 8-segment ring at 62%, KeyLock centre with the key turned 62% of a quarter, "62%",
-- "HOLD ON"), one static car card ("Revolution 6") and the five district tiles top-centre.
-- Gallery: every Icons2 name at 32 / 48 / 64 DEVICE px on a light and a dark swatch (the HUD
-- scale is undone inside the gallery so the sizes are true device pixels), plus the KeyLock
-- parts turned and open.
--
-- The sheet is built only while visible (hiding it destroys the content, so the Shop drift and
-- the gallery's instances never run or linger while hidden). No Priority slot is requested: the
-- sheet is a harness-only overlay, never shown to players.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Arcade = require(script.Parent.Arcade)
local Fixtures = require(script.Parent.Fixtures)
local Icons2 = require(script.Parent.Icons2)
local KeysLock = require(script.Parent.Run.KeysLock)
local PreviewTokens = require(script.Parent.PreviewTokens)
local Trove = require(ReplicatedStorage.Packages.Trove)

local A = PreviewTokens.Arcade
local B = A.Button
local make = Arcade.make

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

-- TOKEN CANDIDATES (specimen layout and samples; listed in the HA report)
local HEAT_W, HEAT_H = 300, 30 -- Heat frame (design px)
local HEAT_FRAME = rgb(24, 32, 58) -- dark Heat frame (inside the ink outline)
local HEAT_EMPTY = rgb(48, 58, 90) -- unlit Heat segment
local KEYS_SEG_THICK = 14 -- Keys ring segment thickness (design px)
local KEYS_INNER_TOP = rgb(20, 28, 54) -- restrained inner shadow (top) ...
local KEYS_INNER_BOTTOM = rgb(44, 58, 98) -- ... to the lighter bottom
local CARD_W, CARD_H = 150, 196 -- specimen car card (design px)
local TILE = 56 -- district tile in the composed sheet (design px)
local TILE_GAP = 8
local CAPTION = rgb(255, 236, 150) -- harness captions (PreviewCaption)
local SWATCH_LIGHT = rgb(236, 242, 250)
local SWATCH_DARK = rgb(28, 36, 58)
local GALLERY_SIZES = { 32, 48, 64 } -- device px
local ICON_BUDGET, TILE_BUDGET = 40, 60 -- Frames per icon / per district tile

-- Synthetic fixture values shown on the sheet (not rules)
local CAR_COUNT = "47"
local CASH_TEXT = "$682K"
local EARNING_TEXT = "Speedway: +$120 / lap"
local HEAT_LIT = 5 -- of 8 segments
local HEAT_SEGMENTS = 8
local KEYS_PROGRESS = 0.62

export type Mode = "Composed" | "Gallery"

type Ctx = {
	store: any,
	screen: any,
	layer: GuiObject,
	world: any?,
	priority: any?,
}

type Options = { visible: boolean?, mode: Mode? }

local Specimen = {}
Specimen.__index = Specimen

-- Samples a ColorSequence at t (0..1).
local function sample(seq: ColorSequence, t: number): Color3
	local points = seq.Keypoints
	for i = 1, #points - 1 do
		local a, b = points[i], points[i + 1]
		if t <= b.Time then
			local span = math.max(b.Time - a.Time, 1e-6)
			return a.Value:Lerp(b.Value, (t - a.Time) / span)
		end
	end
	return points[#points].Value
end

local function caption(parent: Instance, text: string, name: string): TextLabel
	local label = Arcade.text(parent, {
		text = text,
		role = "Small",
		name = name,
		colour = CAPTION,
		autoWidth = true,
		xAlign = Enum.TextXAlignment.Left,
	})
	label:SetAttribute("PreviewCaption", true)
	return label
end

local function holder(parent: Instance, size: number, name: string?): Frame
	return make("Frame", {
		Name = name or "IconHolder",
		Size = UDim2.fromOffset(size, size),
		BackgroundTransparency = 1,
		ZIndex = 6,
		Parent = parent,
	})
end

local function row(parent: Instance, name: string, padding: number): Frame
	local f = make("Frame", {
		Name = name,
		BackgroundTransparency = 1,
		AutomaticSize = Enum.AutomaticSize.X,
		Parent = parent,
	})
	make("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, padding),
		Parent = f,
	})
	return f
end

function Specimen.new(ctx: Ctx, options: Options?)
	local self = setmetatable({}, Specimen)
	self._ctx = ctx
	self._trove = Trove.new()
	self._sheet = self._trove:Extend()
	self._mode = (options and options.mode or "Composed") :: Mode
	self._visible = options ~= nil and options.visible == true
	self._dirty = true
	self._builds = 0
	self._widgets = 0
	self._note = ""
	self._noteLabel = nil :: TextLabel?
	local musicOn = true
	pcall(function()
		musicOn = ctx.store:get().settings.musicOn ~= false
	end)
	self._musicOn = musicOn

	local root = self._trove:Add(make("Frame", {
		Name = "Specimen",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Visible = self._visible,
		ZIndex = 1,
		Parent = ctx.layer,
	}))
	self.root = root :: Frame
	self._scale = make("UIScale", { Name = "HudScale", Parent = root }) :: UIScale
	self:layout()
	return self
end

export type Specimen = typeof(Specimen.new((nil :: any) :: Ctx))

-- Safe-area size in design px and the HUD scale for the current device profile.
function Specimen._designSize(self: Specimen): (number, number, number)
	local screen = self._ctx.screen
	local p = screen:profile()
	local scale = screen:uiScale()
	local w = (p.size.X - p.insets.left - p.insets.right) / scale
	local h = (p.size.Y - p.insets.top - p.insets.bottom) / scale
	return w, h, scale
end

function Specimen.layout(self: Specimen)
	local _, _, scale = self:_designSize()
	self._scale.Scale = scale
	self.root.Size = UDim2.fromScale(1 / scale, 1 / scale)
	self._dirty = true
	if self._visible then
		self:_build()
	end
end

function Specimen.setVisible(self: Specimen, on: boolean)
	self._visible = on
	self.root.Visible = on
	if on then
		if self._dirty then
			self:_build()
		end
	else
		-- nothing runs or lingers while hidden
		self._sheet:Clean()
		self._widgets = 0
		self._noteLabel = nil
		self._dirty = true
	end
end

function Specimen.setMode(self: Specimen, mode: string): boolean
	if mode ~= "Composed" and mode ~= "Gallery" then
		return false
	end
	self._mode = mode :: Mode
	self._dirty = true
	if self._visible then
		self:_build()
	end
	return true
end

function Specimen.getMode(self: Specimen): string
	return self._mode
end

function Specimen.setBackdropNote(self: Specimen, text: string)
	self._note = text
	local label = self._noteLabel
	if label and label.Parent then
		label.Text = self:_noteText()
	end
end

function Specimen._noteText(self: Specimen): string
	local profile = self._ctx.screen:profile()
	local text = "SPECIMEN · " .. self._mode .. " · " .. tostring(profile.label)
	if self._note ~= "" then
		text ..= " · " .. self._note
	end
	return text
end

function Specimen._icon(_self: Specimen, h: Frame, name: string, opts: Icons2.Options?)
	if not Icons2.draw(h, name, opts) then
		-- Arcade falls back to the flat Icons set, then a "?" glyph (counted as a fallback)
		Arcade.icon(h, name)
	end
end

function Specimen._button(self: Specimen, parent: Instance, spec: Arcade.ButtonSpec): Arcade.Button
	local b = Arcade.button(parent, spec)
	self._widgets += 1
	self._sheet:Add(function()
		b.destroy()
	end)
	return b
end

function Specimen._build(self: Specimen)
	self._sheet:Clean()
	self._widgets = 0
	self._noteLabel = nil
	self._dirty = false
	self._builds += 1
	local content = self._sheet:Add(make("Frame", {
		Name = "Content",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Parent = self.root,
	})) :: Frame
	if self._mode == "Gallery" then
		self:_buildGallery(content)
	else
		self:_buildComposed(content)
	end
end

-- COMPOSED ---------------------------------------------------------------------------------

function Specimen._buildComposed(self: Specimen, content: Frame)
	local W, H = self:_designSize()
	local narrow = W < 700
	local short = H < 620
	local L = A.Stats.MarginLeft
	local compact = H < 420
	local menuW = if compact then B.CompactW else B.WideW
	local wideH = (if compact then B.CompactH else B.WideH)
	local wideRoot = math.max(wideH, 48) + B.DepthOffset
	local smallRoot = math.max(B.SmallH, 48) + B.DepthOffset
	local toggleH = 48

	-- MENU STACK (left-centre; Settings centred over the stack)
	local stackH = smallRoot + 3 * wideRoot + toggleH + 4 * B.Gap
	local y = math.max(8, H * 0.5 - stackH / 2)
	self:_button(content, {
		name = "Settings",
		label = "Settings",
		fill = "Settings",
		size = "Small",
		position = UDim2.fromOffset(L + (menuW - B.SmallW) / 2, y),
	})
	y += smallRoot + B.Gap
	type MenuItem = {
		name: string,
		fill: Arcade.FillName,
		icon: string,
		badge: (number | string)?,
		drift: boolean,
	}
	local menu: { MenuItem } = {
		{ name = "Shop", fill = "Rainbow", icon = "Gift", badge = nil, drift = true },
		{ name = "Garage", fill = "Garage", icon = "GarageBook", badge = 1, drift = false },
		{ name = "Missions", fill = "Missions", icon = "Clipboard", badge = "!", drift = false },
	}
	for _, m in menu do
		self:_button(content, {
			name = m.name,
			label = m.name,
			fill = m.fill,
			size = if compact then "Compact" else "Wide",
			icon = m.icon,
			pattern = true,
			drift = m.drift,
			badge = m.badge,
			position = UDim2.fromOffset(L, y),
		})
		y += wideRoot + B.Gap
	end
	local toggle = Arcade.toggle(content, {
		name = "Music",
		label = "Music",
		value = self._musicOn,
		onChanged = function(on: boolean)
			-- specimen only: remembered locally, not written to the store
			self._musicOn = on
		end,
		position = UDim2.fromOffset(L, y),
	})
	self._widgets += 1
	self._sheet:Add(function()
		toggle.destroy()
	end)

	-- STATS (bottom-left, no panels; beside the menu when the screen is short)
	local statsX = if short and not narrow then L + menuW + 24 else L
	local stats = make("Frame", {
		Name = "Stats",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromOffset(statsX, H - A.Stats.MarginBottom),
		Size = UDim2.fromOffset(260, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Parent = content,
	})
	make("UIListLayout", {
		FillDirection = Enum.FillDirection.Vertical,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, A.Stats.RowGap),
		Parent = stats,
	})
	local cars = row(stats, "CarCount", 6)
	cars.LayoutOrder = 1
	cars.Size = UDim2.fromOffset(0, 48)
	self:_icon(holder(cars, A.Stats.IconCars, "CarCountIcon"), "CarCount")
	Arcade.text(cars, {
		text = CAR_COUNT,
		role = "Value",
		name = "Count",
		face = "Cars",
		italic = true,
		autoWidth = true,
		xAlign = Enum.TextXAlignment.Left,
	}).LayoutOrder =
		2
	local cash = row(stats, "Cash", 6)
	cash.LayoutOrder = 2
	cash.Size = UDim2.fromOffset(0, 52)
	self:_icon(holder(cash, A.Stats.IconCash, "CashIcon"), "CashStack")
	Arcade.text(cash, {
		text = CASH_TEXT,
		role = "Value",
		name = "Amount",
		face = "Cash",
		italic = true,
		autoWidth = true,
		xAlign = Enum.TextXAlignment.Left,
	}).LayoutOrder =
		2
	caption(cash, "kit specimen", "KitCaption").LayoutOrder = 3
	local earning = row(stats, "Earning", 6)
	earning.LayoutOrder = 3
	earning.Size = UDim2.fromOffset(0, 26)
	Arcade.text(earning, {
		text = EARNING_TEXT,
		role = "Earning",
		name = "EarningLine",
		italic = true,
		autoWidth = true,
		xAlign = Enum.TextXAlignment.Left,
	}).LayoutOrder =
		1
	caption(earning, "PREVIEW", "PreviewCaption").LayoutOrder = 2
	local statsTop = H - A.Stats.MarginBottom - (48 + 52 + 26 + 2 * A.Stats.RowGap)

	-- HEAT (bottom-centre)
	local heatX = W / 2
	local heatBottom = H - A.Stats.MarginBottom
	if narrow then
		heatBottom = statsTop - 10
	elseif short then
		heatX = math.max(W / 2, statsX + 250 + (HEAT_W + 24) / 2 + 12)
	end
	self:_buildHeat(content, heatX, heatBottom)

	-- KEYS (right of centre, beside the rider)
	local keysX = if narrow then W * 0.68 else W * 0.62
	local keysY = if narrow then H * 0.6 elseif short then H * 0.45 else H * 0.52
	self:_buildKeys(content, keysX, keysY)

	-- CAR CARD (right edge)
	local tileRows = math.ceil(#Icons2.Districts / 5)
	local tilesH = tileRows * TILE + (tileRows - 1) * TILE_GAP
	local cardY = if narrow then 8 + tilesH + 36 else math.max(8 + tilesH + 12, H * 0.5 - CARD_H / 2)
	self:_buildCard(content, W - 14 - CARD_W, cardY)

	-- DISTRICT TILES (top-centre, where the run's strip lives)
	local tiles = make("Frame", {
		Name = "DistrictTiles",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromOffset(W / 2, 8),
		Size = UDim2.fromOffset(5 * TILE + 4 * TILE_GAP, tilesH),
		BackgroundTransparency = 1,
		Parent = content,
	})
	for i, name in Icons2.Districts do
		local h = holder(tiles, TILE, name)
		h.Position = UDim2.fromOffset(((i - 1) % 5) * (TILE + TILE_GAP), ((i - 1) // 5) * (TILE + TILE_GAP))
		self:_icon(h, name)
	end

	-- BACKDROP NOTE (caption, top right; below the tiles on narrower screens)
	local note = caption(content, self:_noteText(), "BackdropNote")
	note.AnchorPoint = Vector2.new(1, 0)
	note.Position = UDim2.fromOffset(W - 14, if W < 1000 then 8 + tilesH + 8 else 8)
	self._noteLabel = note
end

function Specimen._buildHeat(self: Specimen, content: Frame, cx: number, bottom: number)
	local iconSize = 48
	local box = make("Frame", {
		Name = "HeatSample",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromOffset(cx, bottom),
		Size = UDim2.fromOffset(HEAT_W + 24, iconSize),
		BackgroundTransparency = 1,
		Parent = content,
	})
	local frame = make("Frame", {
		Name = "Frame",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 24, 0.5, 0),
		Size = UDim2.fromOffset(HEAT_W, HEAT_H),
		BackgroundColor3 = HEAT_FRAME,
		ZIndex = 2,
		Parent = box,
	})
	Arcade.corner(frame, 8)
	Arcade.outline(frame, "Button")
	local left, pad, gap = 22, 5, 3
	local segW = (HEAT_W - left - pad - (HEAT_SEGMENTS - 1) * gap) / HEAT_SEGMENTS
	for i = 1, HEAT_SEGMENTS do
		local lit = i <= HEAT_LIT
		local seg = make("Frame", {
			Name = "Segment" .. i,
			Position = UDim2.fromOffset(left + (i - 1) * (segW + gap), pad),
			Size = UDim2.fromOffset(segW, HEAT_H - 2 * pad),
			BackgroundColor3 = if lit then sample(A.Face.Heat, (i - 1) / (HEAT_SEGMENTS - 1)) else HEAT_EMPTY,
			ZIndex = 3,
			Parent = frame,
		})
		Arcade.corner(seg, 3)
		if lit then
			make("UIGradient", {
				Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(215, 215, 215)),
				Rotation = 90,
				Parent = seg,
			})
		end
	end
	-- stage marks after segments 3 and 6 (sample positions only, not thresholds)
	for _, after in { 3, 6 } do
		local mark = make("Frame", {
			Name = "StageMark" .. after,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0, left + after * (segW + gap) - gap / 2, 0.5, 0),
			Size = UDim2.fromOffset(3, HEAT_H + 8),
			BackgroundColor3 = Color3.new(1, 1, 1),
			ZIndex = 4,
			Parent = frame,
		})
		Arcade.outline(mark, "Minor")
	end
	local icon = holder(box, iconSize, "FlameIcon")
	icon.AnchorPoint = Vector2.new(0, 0.5)
	icon.Position = UDim2.fromScale(0, 0.5)
	icon.ZIndex = 8
	self:_icon(icon, "Flame")
end

function Specimen._buildKeys(_self: Specimen, content: Frame, cx: number, cy: number)
	local rs = A.Keys.RingSize
	local box = make("Frame", {
		Name = "KeysSample",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(cx, cy),
		Size = UDim2.fromOffset(rs + 8, rs + 8),
		BackgroundTransparency = 1,
		Parent = content,
	})
	local disk = make("Frame", {
		Name = "Boundary",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(rs + 6, rs + 6),
		BackgroundColor3 = A.Ink,
		ZIndex = 2,
		Parent = box,
	})
	Arcade.corner(disk, (rs + 6) / 2)
	local innerD = rs - 2 * KEYS_SEG_THICK - 2
	local inner = make("Frame", {
		Name = "Inner",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(innerD, innerD),
		BackgroundColor3 = Color3.new(1, 1, 1),
		ZIndex = 3,
		Parent = box,
	})
	Arcade.corner(inner, innerD / 2)
	make("UIGradient", {
		Color = ColorSequence.new(KEYS_INNER_TOP, KEYS_INNER_BOTTOM),
		Rotation = 90,
		Parent = inner,
	})
	-- Round 3: one continuous ring (the same builder the live Keys uses), not eight segments
	KeysLock.drawRing(box, rs, rs / 2 - 4, KEYS_SEG_THICK, KEYS_PROGRESS)
	local lockSize = math.floor(rs * 0.52)
	local lock = holder(box, lockSize, "KeyLock")
	lock.AnchorPoint = Vector2.new(0.5, 0.5)
	lock.Position = UDim2.fromScale(0.5, 0.5)
	lock.ZIndex = 6
	local parts = Icons2.keyLock(lock)
	parts.key.Rotation = KEYS_PROGRESS * 90
	local hold = Arcade.text(box, {
		text = "HOLD ON",
		role = "Button",
		name = "HoldOn",
		face = "Keys",
	})
	hold.AnchorPoint = Vector2.new(0.5, 1)
	hold.Position = UDim2.new(0.5, 0, 0, -6)
	hold.Size = UDim2.fromOffset(220, 36)
	local pct = Arcade.text(box, {
		text = tostring(math.floor(KEYS_PROGRESS * 100 + 0.5)) .. "%",
		role = "Small",
		name = "Percent",
		italic = true,
	})
	pct.AnchorPoint = Vector2.new(0.5, 0)
	pct.Position = UDim2.new(0.5, 0, 1, 4)
	pct.Size = UDim2.fromOffset(80, 22)
end

function Specimen._buildCard(self: Specimen, content: Frame, x: number, y: number)
	local car = Fixtures.byId("rev6")
	local rarityName = if car then car.rarity else "Rare"
	local rar = PreviewTokens.Rarity[rarityName]
	local card = make("Frame", {
		Name = "CarCardSample",
		Position = UDim2.fromOffset(x, y),
		Size = UDim2.fromOffset(CARD_W, CARD_H),
		BackgroundColor3 = Color3.new(1, 1, 1),
		ZIndex = 2,
		Parent = content,
	})
	Arcade.corner(card)
	Arcade.outline(card, "Button")
	make("UIGradient", { Color = ColorSequence.new(rar.light, rar.deep), Rotation = 90, Parent = card })
	Arcade.gloss(card)
	local label = Arcade.text(card, {
		text = rar.label,
		role = "Label",
		name = "Rarity",
		xAlign = Enum.TextXAlignment.Left,
	})
	label.Position = UDim2.fromOffset(6, 3)
	label.Size = UDim2.new(1, -60, 0, 24)
	-- rarity pips (shape count, so the rarity never relies on colour alone)
	for i = 1, rar.pips do
		local pip = make("Frame", {
			Name = "Pip" .. i,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(CARD_W - 12 - (i - 1) * 13, 15),
			Size = UDim2.fromOffset(9, 9),
			Rotation = 45,
			BackgroundColor3 = Color3.new(1, 1, 1),
			ZIndex = 6,
			Parent = card,
		})
		Arcade.outline(pip, 1.5)
	end
	local window = make("Frame", {
		Name = "Window",
		Position = UDim2.fromOffset(8, 30),
		Size = UDim2.fromOffset(CARD_W - 16, CARD_H - 30 - 36),
		BackgroundColor3 = Color3.new(1, 1, 1),
		ZIndex = 3,
		Parent = card,
	})
	Arcade.corner(window, 5)
	Arcade.outline(window, "Minor")
	make("UIGradient", {
		Color = ColorSequence.new(rgb(196, 236, 255), rgb(240, 250, 255)),
		Rotation = 90,
		Parent = window,
	})
	local art = holder(window, CARD_W - 36, "CarArt")
	art.AnchorPoint = Vector2.new(0.5, 0.5)
	art.Position = UDim2.fromScale(0.5, 0.52)
	self:_icon(art, "Car", { tint = if car and car.paint then car.paint else nil })
	local name = Arcade.text(card, {
		text = if car then car.name else "Revolution 6",
		role = "Label",
		name = "CarName",
	})
	name.AnchorPoint = Vector2.new(0.5, 0.5)
	name.Position = UDim2.new(0.5, 0, 1, -18)
	name.Size = UDim2.new(1, -8, 0, 24)
	local note = caption(content, "card specimen (static)", "CardCaption")
	note.Position = UDim2.fromOffset(x, y + CARD_H + 8)
end

-- GALLERY ------------------------------------------------------------------------------------

function Specimen._buildGallery(self: Specimen, content: Frame)
	local _, _, scale = self:_designSize()
	-- undo the HUD scale so the gallery sizes are true device pixels
	local device = make("Frame", {
		Name = "Gallery",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(scale, scale),
		Parent = content,
	})
	make("UIScale", { Name = "DeviceScale", Scale = 1 / scale, Parent = device })
	local header = caption(
		device,
		"ICON GALLERY · 32 / 48 / 64 device px on light and dark · Icons2 · " .. #Icons2.Names .. " names",
		"Header"
	)
	header.Position = UDim2.fromOffset(12, 6)
	local note = caption(device, self:_noteText(), "BackdropNote")
	note.AnchorPoint = Vector2.new(1, 0)
	note.Position = UDim2.new(1, -12, 0, 6)
	self._noteLabel = note
	local scroller = make("ScrollingFrame", {
		Name = "Cells",
		Position = UDim2.fromOffset(0, 34),
		Size = UDim2.new(1, 0, 1, -34),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 8,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		Parent = device,
	})
	make("UIPadding", {
		PaddingLeft = UDim.new(0, 12),
		PaddingRight = UDim.new(0, 12),
		PaddingTop = UDim.new(0, 4),
		PaddingBottom = UDim.new(0, 12),
		Parent = scroller,
	})
	local swatchW = 8
	for _, s in GALLERY_SIZES do
		swatchW += s + 8
	end
	local swatchH = GALLERY_SIZES[#GALLERY_SIZES] + 12
	make("UIGridLayout", {
		CellSize = UDim2.fromOffset(2 * swatchW + 10, swatchH + 24),
		CellPadding = UDim2.fromOffset(12, 10),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = scroller,
	})
	local function cell(order: number, title: string): (Frame, Frame)
		local c = make("Frame", {
			Name = "Cell_" .. title,
			BackgroundTransparency = 1,
			LayoutOrder = order,
			Parent = scroller,
		})
		local label = Arcade.text(c, {
			text = title,
			role = "Small",
			name = "Name",
			xAlign = Enum.TextXAlignment.Left,
		})
		label.Size = UDim2.new(1, 0, 0, 20)
		local function swatch(i: number, colour: Color3): Frame
			local sw = make("Frame", {
				Name = if i == 0 then "Light" else "Dark",
				Position = UDim2.fromOffset(i * (swatchW + 10), 22),
				Size = UDim2.fromOffset(swatchW, swatchH),
				BackgroundColor3 = colour,
				ZIndex = 2,
				Parent = c,
			})
			Arcade.corner(sw, 6)
			Arcade.outline(sw, "Minor")
			return sw
		end
		return swatch(0, SWATCH_LIGHT), swatch(1, SWATCH_DARK)
	end
	local function sizes(sw: Frame, draw: (Frame) -> ())
		local x = 8
		for _, s in GALLERY_SIZES do
			local h = holder(sw, s, "Size" .. s)
			h.Position = UDim2.fromOffset(x, swatchH - 6 - s)
			h.ZIndex = 3
			draw(h)
			x += s + 8
		end
	end
	for i, name in Icons2.Names do
		local light, dark = cell(i, name)
		for _, sw in { light, dark } do
			sizes(sw, function(h)
				self:_icon(h, name)
			end)
		end
	end
	-- the Keys centre's movable parts: key turned a quarter, shackle lifted
	local light, dark = cell(#Icons2.Names + 1, "KeyLock parts: turned + open")
	for _, sw in { light, dark } do
		sizes(sw, function(h)
			local parts = Icons2.keyLock(h)
			parts.key.Rotation = 90
			parts.shackle.Position = UDim2.new(0.5, 0, 0.5, -math.floor(h.Size.X.Offset * 0.16))
		end)
	end
end

-- DEBUG --------------------------------------------------------------------------------------

function Specimen.getDebugState(self: Specimen): { [string]: any }
	local instances, frames = 0, 0
	local drawnSet: { [string]: boolean } = {}
	local fallbackSet: { [string]: boolean } = {}
	local maxFrames: { [string]: number } = {}
	for _, d in self.root:GetDescendants() do
		instances += 1
		if d:IsA("Frame") then
			frames += 1
			local icon = d:GetAttribute("Icon")
			if d.Name == "Art" and type(icon) == "string" then
				if d:GetAttribute("IconSet") == "Icons2" then
					drawnSet[icon] = true
					local n = d:GetAttribute("Frames")
					if type(n) == "number" then
						maxFrames[icon] = math.max(maxFrames[icon] or 0, n)
					end
				else
					fallbackSet[icon] = true
				end
			end
		end
	end
	local function sorted(set: { [string]: boolean }): { string }
		local list = {}
		for k in set do
			table.insert(list, k)
		end
		table.sort(list)
		return list
	end
	local over = {}
	for name, n in maxFrames do
		local budget = if string.sub(name, 1, 9) == "District_" then TILE_BUDGET else ICON_BUDGET
		if n > budget then
			table.insert(over, name .. "=" .. n)
		end
	end
	table.sort(over)
	return {
		mode = self._mode,
		visible = self._visible,
		built = not self._dirty,
		builds = self._builds,
		profile = self._ctx.screen:profile().name,
		note = self._note,
		instances = instances,
		frames = frames,
		widgets = self._widgets,
		connections = 0, -- the sheet holds none itself; kit widgets own theirs (counted in widgets)
		iconsDrawn = sorted(drawnSet),
		iconFallbacks = sorted(fallbackSet),
		iconFrames = maxFrames,
		overBudget = over,
	}
end

function Specimen.destroy(self: Specimen)
	self._trove:Destroy()
	self._noteLabel = nil
end

return Specimen
