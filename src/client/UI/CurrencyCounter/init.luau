--!strict
-- Floating currency counter (Lane 3). Presentation only: it shows the value it
-- is given and owns only its own animation. It never changes, saves or
-- decides any amount. Used for Cash only; the icon and colours are inputs so
-- the same component can be reused if another currency is ever approved.
--
-- Behaviour:
--   * First value (and any value set while reduced motion is on) snaps.
--   * Increase: counts up over about 0.35 s from the displayed value, punches
--     the number about 12% (16% for big gains, capped), bounces the icon, plays
--     up to three sparkles and shows a "+$N" label that rises and fades.
--   * Decrease: counts down quickly, with no punch, sparkles or label.
--   * A new value during an animation continues from the displayed value; the
--     newest supplied value always wins and the count lands exactly on it.
--   * Gain labels show the real change in supplied value. Gains within
--     CashCoalesceSeconds join the visible label instead of queueing.
--   * Transient labels and sparkles come from small fixed pools.
--   * All per-frame work runs on the shared AlarmClock, subscribed only while
--     something is animating.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextService = game:GetService("TextService")

local AlarmClock = require(script.Parent.AlarmClock)
local Tokens = require(ReplicatedStorage.Shared.UI.Tokens)
local Trove = require(ReplicatedStorage.Packages.Trove)

export type Options = {
	name: string?,
	palette: Tokens.Palette?,
	buildIcon: (parent: Instance, palette: Tokens.Palette) -> Frame,
	iconSize: Vector2,
	format: (value: number) -> string,
	-- Strings used to reserve width for the widest supported value.
	widestSamples: { string },
	textSize: number?,
	reducedMotion: boolean?,
	initial: number?,
}

local GAP = 8 -- between visible icon artwork and text at scale 1.0
local OUTLINE = 3.5
local SHADOW_OFFSET = 3
local LABEL_SIZE = 22
local LABEL_RISE = 16
local LABEL_POOL = 2
local SPARKLE_POOL = 3
local SPARKLE_SECONDS = 0.45
local BOUNCE = 5

local CurrencyCounter = {}
CurrencyCounter.__index = CurrencyCounter

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

-- An outlined, gradient-filled text layer with a drop shadow, as one unit.
local function outlinedText(parent: Instance, name: string, size: number, palette: Tokens.Palette, z: number)
	local holder = make("Frame", {
		Name = name,
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = z,
		Parent = parent,
	})
	local shadow = make("TextLabel", {
		Name = "Shadow",
		Position = UDim2.fromOffset(0, SHADOW_OFFSET),
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		FontFace = Tokens.font(),
		TextSize = size,
		TextColor3 = palette.CashShadow,
		TextTransparency = 0.35,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = z,
		Parent = holder,
	})
	make("UIStroke", {
		Color = palette.CashShadow,
		Thickness = OUTLINE,
		Transparency = 0.35,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
		Parent = shadow,
	})
	local face = make("TextLabel", {
		Name = "Face",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		FontFace = Tokens.font(),
		TextSize = size,
		TextColor3 = Color3.new(1, 1, 1),
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = z + 1,
		Parent = holder,
	})
	make("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new(palette.CashTop, palette.CashBottom),
		Parent = face,
	})
	local stroke = make("UIStroke", {
		Color = palette.CashOutline,
		Thickness = OUTLINE,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
		Parent = face,
	})
	return holder, face, shadow, stroke
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
	self._unsubscribe = nil :: (() -> ())?

	-- Reserve width for the widest supported value plus the punch overhang,
	-- so neither a new digit nor the animation ever moves the neighbours.
	local widest = 0
	for _, sample in options.widestSamples do
		widest = math.max(widest, measure(sample, textSize).X)
	end
	local textWidth = math.ceil(widest + 2 * OUTLINE)
	local punchRoom = math.ceil(textWidth * Tokens.Motion.CashPunchBig)
	local rowHeight = math.max(options.iconSize.Y, textSize + 2 * OUTLINE + SHADOW_OFFSET)
	self.TextWidth = textWidth
	self.RowHeight = rowHeight
	-- Width/height of the counter row, and the reserved effect band beneath it.
	self.ReservedSize = Vector2.new(options.iconSize.X + GAP + textWidth + punchRoom, rowHeight + LABEL_SIZE + 10)

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

	-- Icon, vertically centred on the number row.
	local iconHolder = make("Frame", {
		Name = "IconHolder",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.fromOffset(0, rowHeight / 2),
		Size = UDim2.fromOffset(options.iconSize.X, options.iconSize.Y),
		BackgroundTransparency = 1,
		Parent = root,
	})
	self._iconHolder = iconHolder
	self._iconRest = iconHolder.Position
	options.buildIcon(iconHolder, palette)

	-- Number: punch scales around its left-centre, so it grows right into the
	-- reserved room and outline and shadow scale together.
	local valueFrame = make("Frame", {
		Name = "Value",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.fromOffset(options.iconSize.X + GAP, rowHeight / 2),
		Size = UDim2.fromOffset(textWidth, textSize + 2 * OUTLINE),
		BackgroundTransparency = 1,
		Parent = root,
	})
	self._punchScale = make("UIScale", { Name = "Punch", Scale = 1, Parent = valueFrame })
	local _, face, shadow = outlinedText(valueFrame, "Text", textSize, palette, 2)
	self._face = face
	self._shadow = shadow

	-- Pools: gain labels below the row, sparkles around the icon.
	self._labels = {}
	for i = 1, LABEL_POOL do
		local holder = make("Frame", {
			Name = "GainLabel" .. i,
			Position = UDim2.fromOffset(options.iconSize.X + GAP, rowHeight + 4),
			Size = UDim2.fromOffset(textWidth, LABEL_SIZE + 2 * OUTLINE),
			BackgroundTransparency = 1,
			Visible = false,
			Parent = root,
		})
		local _, lface, lshadow, lstroke = outlinedText(holder, "Text", LABEL_SIZE, palette, 4)
		table.insert(self._labels, {
			holder = holder,
			face = lface,
			shadow = lshadow,
			stroke = lstroke,
			amount = 0,
			age = math.huge,
			rest = holder.Position,
		})
	end
	self._nextLabel = 1
	self._sparkles = {}
	local spots = {
		Vector2.new(-2, -4),
		Vector2.new(options.iconSize.X - 2, 2),
		Vector2.new(options.iconSize.X * 0.45, options.iconSize.Y + 1),
	}
	for i = 1, SPARKLE_POOL do
		local spark = make("Frame", {
			Name = "Sparkle" .. i,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(spots[i].X, spots[i].Y + (rowHeight - options.iconSize.Y) / 2),
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
	local text = self._format(math.floor(self._displayed))
	self._face.Text = text
	self._shadow.Text = text
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

-- Hides every transient and returns all moving parts to rest.
function CurrencyCounter._clearDecor(self: any)
	self._punch = 0
	self._punchScale.Scale = 1
	self._iconHolder.Position = self._iconRest
	for _, label in self._labels do
		label.age = math.huge
		label.amount = 0
		label.holder.Visible = false
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
		label.amount = 0
	end
	label.amount += delta
	label.age = 0
	local text = "+" .. self._format(label.amount)
	label.face.Text = text
	label.shadow.Text = text
	label.holder.Visible = true
	for _, spark in self._sparkles do
		spark.age = -spark.delay
	end
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
		self._punch = if big then Tokens.Motion.CashPunchBig else Tokens.Motion.CashPunch
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
		self._iconHolder.Position = self._iconRest
			+ UDim2.fromOffset(0, -BOUNCE * wave * (if self._punch > 0 then 1 else 0))
		busy = self._animT < 1
	else
		self._punchScale.Scale = 1
		self._iconHolder.Position = self._iconRest
	end

	for _, label in self._labels do
		if label.age < Tokens.Motion.CashGainLabelSeconds then
			label.age += dt
			local t = math.clamp(label.age / Tokens.Motion.CashGainLabelSeconds, 0, 1)
			label.holder.Position = label.rest + UDim2.fromOffset(0, -LABEL_RISE * easeOut(t))
			local fade = if t < 0.6 then 0 else (t - 0.6) / 0.4
			label.face.TextTransparency = fade
			label.shadow.TextTransparency = 0.35 + 0.65 * fade
			label.stroke.Transparency = fade
			busy = true
		elseif label.holder.Visible then
			label.holder.Visible = false
			label.amount = 0
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
	for _, label in self._labels do
		if label.holder.Visible then
			visible += 1
		end
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
		text = self._face.Text,
		animating = self._unsubscribe ~= nil,
		punch = self._punchScale.Scale,
		iconOffset = self._iconHolder.Position - self._iconRest,
		visibleTransients = visible,
		pooledTransients = LABEL_POOL + SPARKLE_POOL,
		instances = count + 1,
		textFits = self._face.TextFits,
		reservedSize = self.ReservedSize,
	}
end

function CurrencyCounter.destroy(self: any)
	self._trove:Destroy()
end

return CurrencyCounter
