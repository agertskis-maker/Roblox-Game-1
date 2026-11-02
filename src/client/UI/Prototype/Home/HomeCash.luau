--!strict
-- Home/HomeCash: the bottom-left block of the Round 2 Home HUD (Lane 3, N7-01 / N7-03a / N7-03b, 2026-11-02). Presentation
-- only: it shows what the adapters supply and never changes, saves or decides an amount.
--
--   row 1   Cash, the approved floating counter (Cash icon fixed, digits growing rightward, count-up 0.35 s, punch and a
--           "+$N" label under the number: Tokens.Motion, unchanged), then a green "+" that opens the Shop's Cash section
--           (adapter onShopCash). The "+" follows the end of the number, so it never floats far from it.
--   row 2   a green "+$X/s" rate, only when the adapter getCashRate exists and returns a number (never invented, never an
--           offline-capped total turned into a promise), and the cars-owned count "17 / 24", counted from the supplied
--           denominator (never a hard-coded 24). The row ducks while the counter's own "+$N" label is showing.
--
-- Missing data is never zero: while an adapter returns nil the block shows "Loading", and after 8 seconds of nil
-- "Unavailable". A fixture is marked: adapters.preview = { cash = true, rate = true, owned = true } puts a small "PREVIEW" tag
-- beside that value (always drawn when the flag is on, so a fixture is never mistaken for a real balance).
--
--   local cash = HomeCash.new(parent, adapters)
--   cash:place(plan, scale)    -- HomeLayout.CashPlan and the HUD scale
--   cash:refresh()             -- read the adapters (HomeHud calls it a few times a second and on demand)
--   HomeCash.blockSize() -> Vector2    -- the typical size HomeLayout reserves
--   cash:getPlusButton() -> GuiObject?   cash:setVisible(on)   cash:getDebugState()   cash:destroy()

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextService = game:GetService("TextService")

local Arcade = require(script.Parent.Parent.Arcade)
local CashIcon = require(script.Parent.Parent.Parent.CurrencyCounter.CashIcon)
local CurrencyCounter = require(script.Parent.Parent.Parent.CurrencyCounter)
local Fade = require(script.Parent.Fade)
local Format = require(ReplicatedStorage.Shared.UI.Format)
local GameIcons = require(script.Parent.Parent.GameIcons)
local HomeButton = require(script.Parent.HomeButton)
local HomeLayout = require(script.Parent.HomeLayout)
local HomeView = require(script.Parent.HomeView)
local IconArt = require(script.Parent.IconArt)
local Layout = require(script.Parent.Layout)
local Motion = require(script.Parent.Parent.Motion)
local OutlinedText = require(script.Parent.Parent.Parent.OutlinedText)
local Sounds = require(script.Parent.Parent.Sounds)
local Tokens = require(ReplicatedStorage.Shared.UI.Tokens)
local Trove = require(ReplicatedStorage.Packages.Trove)

local make = Arcade.make

local PLUS = Tokens.Touch.Minimum -- the green "+" is a 48 px touch target
local ROW2 = 28
local ROW2_GAP = 4
local ICON2 = 24
local UNAVAILABLE_AFTER = 8 -- seconds of nil before "Loading" becomes "Unavailable"
local SOUND_EVERY = 0.8 -- one cash sound at most this often, never one per count-up tick

export type Adapters = {
	getCash: (() -> number?)?,
	getCashRate: (() -> number?)?,
	getOwned: (() -> (number?, number?))?,
	onShopCash: (() -> ())?,
	preview: { [string]: boolean }?,
}

export type Cash = {
	place: (self: Cash, plan: HomeLayout.CashPlan, scale: number) -> (),
	refresh: (self: Cash) -> (),
	getPlusButton: (self: Cash) -> GuiObject?,
	setVisible: (self: Cash, on: boolean) -> (),
	getDebugState: (self: Cash) -> { [string]: any },
	destroy: (self: Cash) -> (),
}

local HomeCash = {}
HomeCash.__index = HomeCash

local GROW = 1.4 -- Adam, Round 3: a bigger Cash display. The whole block scales, so the icon and number stay in proportion.

local function baseSize(): Vector2
	local m = Layout.cashMetrics()
	return Vector2.new(m.valueX + 150 + 8 + PLUS, m.rowHeight + ROW2_GAP + ROW2)
end

function HomeCash.blockSize(): Vector2
	return baseSize() * GROW
end

local function textWidth(text: string, size: number): number
	return TextService:GetTextSize(text, size, Enum.Font.FredokaOne, Vector2.new(4096, 4096)).X
end

-- The approved counter's icon: the image family's Cash art in a box of the approved icon's size when it exists, else the
-- approved CashIcon. Same geometry either way (CurrencyCounter measures it).
local function buildIcon(parent: Instance, palette: any): Frame
	if GameIcons.has("cash") then
		local box = make("Frame", {
			Name = "CashArtIcon",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(CashIcon.Size.X, CashIcon.Size.Y),
			BackgroundTransparency = 1,
			Parent = parent,
		})
		if GameIcons.image(box, "cash", UDim2.fromOffset(CashIcon.ArtSize.X * 1.35, CashIcon.ArtSize.Y * 1.35)) then
			return box
		end
		box:Destroy()
	end
	return CashIcon.build(parent, palette)
end

local function tag(parent: Instance, name: string): TextLabel
	local t = Arcade.text(parent, {
		text = "PREVIEW",
		role = "Small",
		name = name,
		colour = Color3.fromRGB(255, 236, 140),
		xAlign = Enum.TextXAlignment.Left,
		autoWidth = true,
		z = 6,
	})
	t.Visible = false
	return t
end

function HomeCash.new(parent: Instance, adapters: Adapters): Cash
	local self = setmetatable({}, HomeCash) :: any
	local trove = Trove.new()
	self._trove = trove
	self._adapters = adapters
	self._destroyed = false
	self._m = Layout.cashMetrics()
	local m = self._m
	local size = baseSize()
	self._value = nil :: number?
	self._firstNilAt = nil :: number?
	self._lastSound = -math.huge
	self._duck = 0
	self._ownedNilAt = nil :: number?

	local root = trove:Add(make("Frame", {
		Name = "HomeCash",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(size.X, size.Y),
		ZIndex = 4,
		Parent = parent,
	}))
	self.root = root
	self._scale = make("UIScale", { Name = "HudScale", Scale = 1, Parent = root })

	-- row 1: the approved counter, or "Loading" until a value exists
	local row1 = make("Frame", {
		Name = "CashRow",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(size.X, m.rowHeight),
		ZIndex = 4,
		Parent = root,
	})
	local counter = CurrencyCounter.new(row1, {
		name = "Cash",
		buildIcon = buildIcon,
		iconSize = CashIcon.Size,
		iconArtSize = CashIcon.ArtSize,
		format = Format.cash,
		widestSamples = Layout.CashWidest,
		reducedMotion = Motion.reduced(),
	})
	trove:Add(function()
		counter:destroy()
	end)
	trove:Add(Motion.onReducedChanged(function(reduced: boolean)
		counter:setReducedMotion(reduced)
	end))
	counter.Root.Position = UDim2.fromOffset(0, 0)
	counter.Root.Visible = false
	self._counter = counter
	local loading = Arcade.text(row1, {
		text = "Loading",
		role = "Value",
		name = "Status",
		size = Tokens.TextSize.Value,
		italic = true,
		xAlign = Enum.TextXAlignment.Left,
		autoWidth = true,
		z = 6,
	})
	loading.AnchorPoint = Vector2.new(0, 0.5)
	loading.Position = UDim2.fromOffset(m.valueX, m.rowHeight / 2)
	self._status = loading
	local statusIcon = make("Frame", {
		Name = "StatusIcon",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(CashIcon.Size.X / 2, m.rowHeight / 2),
		Size = UDim2.fromOffset(CashIcon.Size.X, CashIcon.Size.Y),
		BackgroundTransparency = 1,
		ZIndex = 5,
		Parent = row1,
	})
	buildIcon(statusIcon, Tokens.Color)
	self._statusIcon = statusIcon
	self._previewCash = tag(row1, "PreviewCash")

	local plus = HomeButton.round(root, {
		name = "CashPlus",
		fill = "Green",
		icons = { "Plus" },
		glyph = if GameIcons.has("plus") then nil else "+",
		d = PLUS,
		colW = PLUS,
		onActivate = function()
			local cb = adapters.onShopCash
			if cb then
				cb()
			end
		end,
	})
	trove:Add(plus.trove)
	plus.root.Position = UDim2.fromOffset(m.valueX + 120, (m.rowHeight - PLUS) / 2)
	plus.root.Visible = false
	self._plus = plus

	-- row 2: the rate and the owned count
	local row2 = make("Frame", {
		Name = "Row2",
		Position = UDim2.fromOffset(m.artLeft, m.rowHeight + ROW2_GAP),
		Size = UDim2.fromOffset(size.X, ROW2),
		BackgroundTransparency = 1,
		ZIndex = 4,
		Parent = root,
	})
	make("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 12),
		Parent = row2,
	})
	self._row2 = row2
	local function group(name: string, order: number): Frame
		local g = make("Frame", {
			Name = name,
			LayoutOrder = order,
			Size = UDim2.fromOffset(0, ROW2),
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundTransparency = 1,
			Visible = false,
			ZIndex = 4,
			Parent = row2,
		})
		make("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 4),
			Parent = g,
		})
		return g
	end
	local rateGroup = group("Rate", 1)
	local rateIcon = make("Frame", {
		Name = "Icon",
		LayoutOrder = 1,
		Size = UDim2.fromOffset(ICON2, ICON2),
		BackgroundTransparency = 1,
		Visible = GameIcons.has("cashPerSecond"),
		ZIndex = 5,
		Parent = rateGroup,
	})
	if GameIcons.has("cashPerSecond") then
		IconArt.draw(rateIcon, { "CashPerSecond" })
	end
	local rateText = Arcade.text(rateGroup, {
		text = "",
		role = "Earning",
		name = "Text",
		face = "Cash",
		italic = true,
		xAlign = Enum.TextXAlignment.Left,
		autoWidth = true,
		z = 5,
	})
	rateText.LayoutOrder = 2
	local previewRate = tag(rateGroup, "PreviewRate")
	previewRate.LayoutOrder = 3
	local ownedGroup = group("Owned", 2)
	local ownedIcon = make("Frame", {
		Name = "Icon",
		LayoutOrder = 1,
		Size = UDim2.fromOffset(ICON2, ICON2),
		BackgroundTransparency = 1,
		ZIndex = 5,
		Parent = ownedGroup,
	})
	IconArt.draw(ownedIcon, { "Garage", "Car" })
	local ownedText = Arcade.text(ownedGroup, {
		text = "",
		role = "Earning",
		name = "Text",
		face = "Cars",
		italic = true,
		xAlign = Enum.TextXAlignment.Left,
		autoWidth = true,
		z = 5,
	})
	ownedText.LayoutOrder = 2
	local previewOwned = tag(ownedGroup, "PreviewOwned")
	previewOwned.LayoutOrder = 3
	self._rateGroup, self._rateText, self._previewRate = rateGroup, rateText, previewRate
	self._ownedGroup, self._ownedText, self._previewOwned = ownedGroup, ownedText, previewOwned
	self._row2Fade = Fade.capture(row2)
	trove:Add(function()
		self._row2Fade:destroy()
	end)

	self:refresh()
	return self :: Cash
end

-- The "+$N" label under the number uses row 2's space for 0.7 s: row 2 fades out for that time.
function HomeCash._duckRow(self: any)
	if Motion.reduced() then
		return
	end
	self._duck += 1
	local token = self._duck
	self._row2Fade:tween(1, 0.1)
	task.delay(Tokens.Motion.CashGainLabelSeconds + 0.1, function()
		if self._destroyed or token ~= self._duck then
			return
		end
		self._row2Fade:tween(0, 0.2)
	end)
end

local function read(fn: (() -> any)?): (boolean, any)
	if fn == nil then
		return false, nil
	end
	local ok, value = pcall(fn)
	if not ok then
		return true, nil
	end
	return true, value
end

function HomeCash.refresh(self: any)
	if self._destroyed then
		return
	end
	local a: Adapters = self._adapters
	local m = self._m
	local preview = a.preview or {}
	local now = os.clock()

	-- Cash: a number, "Loading", or "Unavailable" (never zero for missing data)
	local _, cash = read(a.getCash)
	if type(cash) == "number" and cash == cash then
		local previous = self._value
		self._value = cash
		self._firstNilAt = nil
		self._counter.Root.Visible = true
		self._status.Visible = false
		self._statusIcon.Visible = false
		self._counter:setValue(math.max(0, cash))
		if previous ~= nil and cash > previous then
			self:_duckRow()
			if now - self._lastSound >= SOUND_EVERY then
				self._lastSound = now
				Sounds.play("CashGain")
			end
		end
		-- the green "+" follows the end of the number (measured only when the value changed)
		if previous ~= cash or not self._plus.root.Visible then
			local endX = m.valueX
				+ textWidth(Format.cash(math.max(0, cash)), Tokens.TextSize.Cash)
				+ OutlinedText.Outline
			local goal = UDim2.fromOffset(math.floor(endX + 8), (m.rowHeight - PLUS) / 2)
			if self._plus.root.Visible and not Motion.reduced() then
				Motion.tween(self._plus.root, "slide", Motion.info(0.18), { Position = goal })
			else
				Motion.cancelAll(self._plus.root)
				self._plus.root.Position = goal
			end
			self._plus.root.Visible = true
			self._previewCash.Position = UDim2.fromOffset(math.floor(endX + 8 + PLUS + 6), (m.rowHeight - 22) / 2)
		end
		self._previewCash.Visible = preview.cash == true
	else
		self._value = nil
		local since = self._firstNilAt or now
		self._firstNilAt = since
		self._counter.Root.Visible = false
		self._status.Visible = true
		self._statusIcon.Visible = true
		self._status.Text = if now - since >= UNAVAILABLE_AFTER then "Unavailable" else "Loading"
		self._plus.root.Visible = false
		self._previewCash.Visible = false
	end

	-- the rate: only when the adapter exists AND returns a number
	local hasRate, rate = read(a.getCashRate)
	local rateGroup: Frame = self._rateGroup
	if hasRate and type(rate) == "number" and rate == rate and rate > 0 then
		self._rateText.Text = "+" .. Format.cash(rate) .. "/s"
		rateGroup.Visible = true
		self._previewRate.Visible = preview.rate == true
	else
		rateGroup.Visible = false
	end

	-- the owned count: "17 / 24" from the supplied denominator, "17 cars" without one, "Loading" while nil
	local hasOwned = false
	local owned: number? = nil
	local total: number? = nil
	if a.getOwned then
		hasOwned = true
		local ok, o, t = pcall(a.getOwned)
		if ok then
			owned, total = o, t
		end
	end
	local ownedGroup: Frame = self._ownedGroup
	if not hasOwned then
		ownedGroup.Visible = false
	elseif type(owned) == "number" and owned == owned then
		self._ownedNilAt = nil
		local count = math.max(0, math.floor(owned))
		if type(total) == "number" and total == total and total >= 1 then
			self._ownedText.Text = Format.group(count) .. " / " .. Format.group(math.floor(total))
		else
			self._ownedText.Text = Format.group(count) .. (if count == 1 then " car" else " cars")
		end
		ownedGroup.Visible = true
		self._previewOwned.Visible = preview.owned == true
	else
		local since = self._ownedNilAt or now
		self._ownedNilAt = since
		self._ownedText.Text = if now - since >= UNAVAILABLE_AFTER then "Unavailable" else "Loading"
		ownedGroup.Visible = true
		self._previewOwned.Visible = false
	end
end

function HomeCash.place(self: any, plan: HomeLayout.CashPlan, scale: number)
	local size = baseSize()
	self._scale.Scale = scale * GROW
	self.root.Position = UDim2.fromOffset(plan.x * scale, (plan.bottom - size.Y * GROW) * scale)
	self.root.Size = UDim2.fromOffset(size.X, size.Y)
end

function HomeCash.getPlusButton(self: any): GuiObject?
	return self._plus.body
end

function HomeCash.setVisible(self: any, on: boolean)
	self.root.Visible = on
end

function HomeCash.getDebugState(self: any): { [string]: any }
	return {
		value = self._value,
		counter = self._counter:getDebugState(),
		status = if self._status.Visible then self._status.Text else nil,
		plusVisible = self._plus.root.Visible,
		plusSize = HomeView.vec(self._plus.body.AbsoluteSize),
		rate = if self._rateGroup.Visible then self._rateText.Text else nil,
		owned = if self._ownedGroup.Visible then self._ownedText.Text else nil,
		absPos = HomeView.vec(self.root.AbsolutePosition),
		absSize = HomeView.vec(self.root.AbsoluteSize),
	}
end

function HomeCash.destroy(self: any)
	if self._destroyed then
		return
	end
	self._destroyed = true
	self._trove:Destroy()
end

return HomeCash
