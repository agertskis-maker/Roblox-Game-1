--!strict
-- Floating currency counter (Lane 3). Presentation only: it shows the value it
-- is given and owns only its own animation. It never changes, saves or
-- decides any amount. Used for Cash only; the icon and colours are inputs so
-- the same component can be reused if another currency is ever approved.
--
-- Behaviour:
--   * First value (and any value set while reduced motion is on) snaps, with
--     no gain label, sparkles, pop or punch.
--   * Increase: counts up over about 0.35 s from the displayed value, punches
--     the number about 12% (16% for big gains, capped by setMaxPunch on narrow
--     screens), pops the icon about its centre, plays up to three sparkles and
--     shows a "+$N" label that rises and fades.
--   * Decrease: counts down quickly, with no punch, sparkles or label.
--   * A new value during an animation continues from the displayed value; the
--     newest supplied value always wins and the count lands exactly on it.
--   * Gain labels show the real change in supplied value. Gains within
--     CashCoalesceSeconds join the visible label instead of queueing.
--   * Transient labels and sparkles come from small fixed pools. A gain
--     label's text, outline and shadow fade from one value and every property
--     is reset when the label is reused.
--   * All per-frame work runs on the shared AlarmClock, subscribed only while
--     something is animating.
--
-- Alignment (revision 4): the icon's visible artwork is centred on the
-- visible digit height (not the TextLabel box) and sits GAP px from the
-- visible ink of the "$" at scale 1.0. The number punches about its left
-- edge at the digit centre line, and the icon pops about its own centre, so
-- the two stay aligned while animating.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextService = game:GetService("TextService")

local AlarmClock = require(script.Parent.AlarmClock)
local OutlinedText = require(script.Parent.OutlinedText)
local Tokens = require(ReplicatedStorage.Shared.UI.Tokens)
local Trove = require(ReplicatedStorage.Packages.Trove)

export type Options = {
	name: string?,
	palette: Tokens.Palette?,
	buildIcon: (parent: Instance, palette: Tokens.Palette) -> Frame,
	-- Square holder size and the visible artwork size centred inside it.
	iconSize: Vector2,
	iconArtSize: Vector2,
	format: (value: number) -> string,
	-- Strings used to reserve width for the widest supported value.
	widestSamples: { string },
	textSize: number?,
	reducedMotion: boolean?,
	initial: number?,
}

local GAP = 8 -- between visible icon artwork and visible "$" ink at scale 1.0
local OUTLINE = OutlinedText.Outline
local LABEL_SIZE = 22
local LABEL_RISE = 16
local LABEL_POOL = 2
local SPARKLE_POOL = 3
local SPARKLE_SECONDS = 0.45
local ICON_POP = 0.08

local CurrencyCounter = {}
CurrencyCounter.__index = CurrencyCounter
CurrencyCounter.Gap = GAP

local function make(className: string, props: { [string]: any }): any
	local instance = Instance.new(className)
	local parent = props.Parent
	for key, value in props do
		if key ~= "Parent" then
			(instance :: any)[key] = value
		end
	end
	instance.Parent = parent
	return instance
end

local function easeOut(t: number): number
	return 1 - (1 - t) * (1 - t)
end

local function measure(text: string, size: number): Vector2
	return TextService:GetTextSize(text, size, Enum.Font.FredokaOne, Vector2.new(4096, 4096))
end

function CurrencyCounter.new(parent: Instance, options: Options)
	local palette: Tokens.Palette = options.palette or Tokens.Color
	local textSize = options.textSize or Tokens.TextSize.Cash
	local self = setmetatable({}, CurrencyCounter)
	self._trove = Trove.new()
	self._format = options.format
	self._reduced = options.reducedMotion == true
	self._value = nil :: number?
	self._displayed = 0
	self._from = 0
	self._animT = 1
	self._duration = Tokens.Motion.CashGainSeconds
	self._punch = 0
	self._maxPunch = Tokens.Motion.CashPunchBig
	self._unsubscribe = nil :: (() -> ())?

	-- Widest supported value: advance width, plus the outline on each side.
	local widest = 0
	for _, sample in options.widestSamples do
		widest = math.max(widest, measure(sample, textSize).X)
	end
	local textWidth = math.ceil(widest + 2 * OUTLINE)
	local textHeight = textSize + 2 * OUTLINE
	local side = options.iconSize.X
	local art = options.iconArtSize
	local rowHeight = math.max(options.iconSize.Y, textHeight + OutlinedText.ShadowOffset)
	local mid = rowHeight / 2
	-- The "$" ink (with its outline) starts this far right of the label's edge.
	local inkLeft = OutlinedText.DollarInkLeftEm * textSize - OUTLINE
	local artRight = side / 2 + art.X / 2
	local valueX = artRight + GAP - inkLeft
	-- Digit centre below the label's centre, as an anchor inside the label.
	local digitAnchorY = 0.5 + OutlinedText.DigitCentreEm * textSize / textHeight
	local punchRoom = math.ceil(textWidth * Tokens.Motion.CashPunchBig)

	self.TextWidth = textWidth
	self.RowHeight = rowHeight
	self.ValueX = valueX
	self.ArtLeft = side / 2 - art.X / 2
	-- Visible right edge of the widest value at rest, from the label's left.
	self.WidestInkRight = widest + OUTLINE
	self.ReservedSize = Vector2.new(valueX + textWidth + punchRoom, rowHeight + LABEL_SIZE + 10)

	local root = make("Frame", {
		Name = options.name or "Counter",
		Size = UDim2.fromOffset(self.ReservedSize.X, self.ReservedSize.Y),
		BackgroundTransparency = 1,
		Active = false,
		Parent = parent,
	})
	pcall(function()
		(root :: any).Interactable = false
	end)
	self._trove:Add(root)
	self.Root = root

	-- Icon: square holder centred on the visible digit centre line. It pops
	-- about its centre, which is also the artwork's visible centre.
	local reserved = self.ReservedSize
	local iconHolder = make("Frame", {
		Name = "IconHolder",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(side / 2 / reserved.X, mid / reserved.Y),
		Size = UDim2.fromOffset(options.iconSize.X, options.iconSize.Y),
		BackgroundTransparency = 1,
		Parent = root,
	})
	self._iconHolder = iconHolder
	self._iconPop = make("UIScale", { Name = "Pop", Scale = 1, Parent = iconHolder })
	options.buildIcon(iconHolder, palette)

	-- Number: anchored at its left edge on the digit centre line, so the punch
	-- grows right and evenly up and down about the digits. Sub-pixel values go
	-- in the scale components (UDim offsets are whole pixels).
	local valueFrame = make("Frame", {
		Name = "Value",
		AnchorPoint = Vector2.new(0, digitAnchorY),
		Position = UDim2.fromScale(valueX / reserved.X, mid / reserved.Y),
		Size = UDim2.fromOffset(textWidth, textHeight),
		BackgroundTransparency = 1,
		Parent = root,
	})
	self._valueFrame = valueFrame
	self._punchScale = make("UIScale", { Name = "Punch", Scale = 1, Parent = valueFrame })
	self._text = OutlinedText.build(valueFrame, "Text", textSize, palette.CashTop, palette.CashBottom, palette, 2)

	-- Pools: gain labels below the row, sparkles around the icon artwork.
	self._labels = {}
	for i = 1, LABEL_POOL do
		local holder = make("Frame", {
			Name = "GainLabel" .. i,
			Position = UDim2.fromOffset(math.floor(valueX), rowHeight + 4),
			Size = UDim2.fromOffset(textWidth, LABEL_SIZE + 2 * OUTLINE),
			BackgroundTransparency = 1,
			Visible = false,
			Parent = root,
		})
		local parts = OutlinedText.build(holder, "Text", LABEL_SIZE, palette.CashTop, palette.CashBottom, palette, 4)
		OutlinedText.setFade(parts, 1)
		table.insert(self._labels, {
			holder = holder,
			parts = parts,
			amount = 0,
			age = math.huge,
			rest = holder.Position,
		})
	end
	self._nextLabel = 1
	self._sparkles = {}
	local artLeft, artTop = side / 2 - art.X / 2, mid - art.Y / 2
	local spots = {
		Vector2.new(artLeft - 1, artTop - 2),
		Vector2.new(artLeft + art.X, artTop + 6),
		Vector2.new(artLeft + art.X * 0.45, artTop + art.Y + 2),
	}
	for i = 1, SPARKLE_POOL do
		local spark = make("Frame", {
			Name = "Sparkle" .. i,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(spots[i].X, spots[i].Y),
			Size = UDim2.fromOffset(7, 7),
			Rotation = 45,
			BackgroundColor3 = palette.Sparkle,
			BorderSizePixel = 0,
			Visible = false,
			ZIndex = 6,
			Parent = root,
		})
		make("UIStroke", { Color = palette.CashTop, Thickness = 1.5, Parent = spark })
		table.insert(self._sparkles, { frame = spark, age = math.huge, delay = (i - 1) * 0.06 })
	end

	self._trove:Add(function()
		self:_stopLoop()
	end)

	if options.initial ~= nil then
		self:setValue(options.initial)
	end
	return self
end

function CurrencyCounter._render(self: any)
	OutlinedText.setText(self._text, self._format(math.floor(self._displayed)))
end

function CurrencyCounter._startLoop(self: any)
	if self._unsubscribe == nil then
		self._unsubscribe = AlarmClock.subscribe(function(dt: number)
			self:_step(dt)
		end)
	end
end

function CurrencyCounter._stopLoop(self: any)
	if self._unsubscribe then
		self._unsubscribe()
		self._unsubscribe = nil
	end
end

-- Returns a pooled label to its hidden resting state.
local function resetLabel(label: any)
	label.age = math.huge
	label.amount = 0
	label.holder.Visible = false
	label.holder.Position = label.rest
	OutlinedText.setFade(label.parts, 1)
end

-- Hides every transient and returns all moving parts to rest.
function CurrencyCounter._clearDecor(self: any)
	self._punch = 0
	self._punchScale.Scale = 1
	self._iconPop.Scale = 1
	for _, label in self._labels do
		resetLabel(label)
	end
	for _, spark in self._sparkles do
		spark.age = math.huge
		spark.frame.Visible = false
	end
end

function CurrencyCounter._showGain(self: any, delta: number)
	-- Join a label that started very recently, otherwise use the next one.
	local recent = nil
	for _, label in self._labels do
		if label.age < Tokens.Motion.CashCoalesceSeconds then
			recent = label
		end
	end
	local label = recent
	if label == nil then
		label = self._labels[self._nextLabel]
		self._nextLabel = self._nextLabel % LABEL_POOL + 1
		resetLabel(label)
	end
	label.amount += delta
	label.age = 0
	OutlinedText.setText(label.parts, "+" .. self._format(label.amount))
	OutlinedText.setFade(label.parts, 0)
	label.holder.Position = label.rest
	label.holder.Visible = true
	for _, spark in self._sparkles do
		spark.age = -spark.delay
	end
end

-- Largest punch allowed (fraction of size), from the HUD layout. Both punch
-- amounts are scaled down together so a big gain still reads bigger.
function CurrencyCounter.setMaxPunch(self: any, limit: number)
	self._maxPunch = math.clamp(limit, 0, Tokens.Motion.CashPunchBig)
end

function CurrencyCounter.getMaxPunch(self: any): number
	return self._maxPunch
end

-- Sets the supplied value. The first value, and every value while reduced
-- motion is on, snaps without celebrating.
function CurrencyCounter.setValue(self: any, value: number, instant: boolean?)
	local previous: number? = self._value
	self._value = value
	if previous == nil or instant or self._reduced then
		self:_stopLoop()
		self:_clearDecor()
		self._displayed = value
		self._animT = 1
		self:_render()
		return
	end
	if value == previous then
		return
	end
	self._from = self._displayed
	self._animT = 0
	if value > previous then
		local delta = value - previous
		self._duration = Tokens.Motion.CashGainSeconds
		local big = delta >= math.max(1000, previous * 0.25)
		local ratio = self._maxPunch / Tokens.Motion.CashPunchBig
		self._punch = ratio * (if big then Tokens.Motion.CashPunchBig else Tokens.Motion.CashPunch)
		self:_showGain(delta)
	else
		self._duration = Tokens.Motion.CashSpendSeconds
		self._punch = 0
	end
	self:_startLoop()
end

function CurrencyCounter._step(self: any, dt: number)
	local busy = false
	local target: number = self._value or 0

	if self._animT < 1 then
		self._animT = math.min(1, self._animT + dt / self._duration)
		local p = easeOut(self._animT)
		self._displayed = self._from + (target - self._from) * p
		if self._animT >= 1 then
			self._displayed = target
		end
		self:_render()
		local wave = math.sin(math.pi * self._animT)
		self._punchScale.Scale = 1 + self._punch * wave
		self._iconPop.Scale = 1 + (if self._punch > 0 then ICON_POP * wave else 0)
		busy = self._animT < 1
	else
		self._punchScale.Scale = 1
		self._iconPop.Scale = 1
	end

	for _, label in self._labels do
		if label.age < Tokens.Motion.CashGainLabelSeconds then
			label.age += dt
			local t = math.clamp(label.age / Tokens.Motion.CashGainLabelSeconds, 0, 1)
			label.holder.Position = label.rest + UDim2.fromOffset(0, -LABEL_RISE * easeOut(t))
			OutlinedText.setFade(label.parts, if t < 0.6 then 0 else (t - 0.6) / 0.4)
			busy = true
		elseif label.holder.Visible then
			resetLabel(label)
		end
	end

	for _, spark in self._sparkles do
		if spark.age < SPARKLE_SECONDS then
			spark.age += dt
			local t = math.clamp(spark.age / SPARKLE_SECONDS, 0, 1)
			spark.frame.Visible = spark.age > 0
			local grow = math.sin(math.pi * t)
			spark.frame.Size = UDim2.fromOffset(3 + 6 * grow, 3 + 6 * grow)
			spark.frame.BackgroundTransparency = t * 0.6
			busy = true
		elseif spark.frame.Visible then
			spark.frame.Visible = false
		end
	end

	if not busy then
		self:_stopLoop()
	end
end

function CurrencyCounter.setReducedMotion(self: any, reduced: boolean)
	self._reduced = reduced
	if reduced then
		-- Cancel decorative motion and land on the newest value now.
		self:_stopLoop()
		self:_clearDecor()
		if self._value ~= nil then
			self._displayed = self._value
			self._animT = 1
			self:_render()
		end
	end
end

function CurrencyCounter.getDebugState(self: any): { [string]: any }
	local visible = 0
	local labels = {}
	for _, label in self._labels do
		if label.holder.Visible then
			visible += 1
		end
		table.insert(labels, {
			visible = label.holder.Visible,
			face = label.parts.face.TextTransparency,
			faceStroke = label.parts.faceStroke.Transparency,
			shadow = label.parts.shadow.TextTransparency,
			shadowStroke = label.parts.shadowStroke.Transparency,
		})
	end
	for _, spark in self._sparkles do
		if spark.frame.Visible then
			visible += 1
		end
	end
	local count = 0
	for _ in self.Root:GetDescendants() do
		count += 1
	end
	return {
		value = self._value,
		displayed = self._displayed,
		text = self._text.face.Text,
		animating = self._unsubscribe ~= nil,
		punch = self._punchScale.Scale,
		maxPunch = self._maxPunch,
		iconPop = self._iconPop.Scale,
		visibleTransients = visible,
		pooledTransients = LABEL_POOL + SPARKLE_POOL,
		labels = labels,
		instances = count + 1,
		textFits = self._text.face.TextFits,
		reservedSize = self.ReservedSize,
	}
end

function CurrencyCounter.destroy(self: any)
	self._trove:Destroy()
end

return CurrencyCounter
