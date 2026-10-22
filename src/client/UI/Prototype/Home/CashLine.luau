--!strict
-- Home HUD: Cash line, top-left (Lane 3 preview). Presentation only: it shows the values the
-- store supplies and never changes, saves or decides an amount. A client animation is not proof
-- that a reward happened.
--
-- Reuses the approved CurrencyCounter + CashIcon unchanged (floating, no panel, icon fixed,
-- number grows rightward, Format.cash). Around it:
--   * Exact value: tapping, clicking, hovering or gamepad-focusing the counter shows the exact
--     supplied store.exactCash ("$1,250,000", whole dollars as supplied) in a small cream
--     tooltip for PreviewTokens.Motion.ExactValueSeconds.
--   * Gain chip "+$120": appears at the origin, then merges into the number; the counter is
--     updated (count-up, approved punch and "+$N" label) when the chip lands. Gains within
--     COALESCE seconds of a chip's start join that chip. Pool of 3 chips; when all are busy the
--     oldest lands at once. World origin only when the event carries worldPosition AND it
--     projects in front of the camera inside the device frame; otherwise a local origin just
--     right of the number.
--   * Spend: a neutral white glow behind the number and a small cream "-$500" chip that drifts
--     down and fades (never danger red). Pool of 2.
--   * Big-gain celebration (PREVIEW POLICY, not an economy rule): a gain is "big" when
--         amount >= max(BigGainFraction * previous balance, BigGainMinimum)
--     (0.1 and $500) and no big gain was celebrated in the last BigGainCooldown (8 s).
--     "previous balance" is the value the counter showed before this gain. Because of the $500
--     floor a zero or tiny balance does not make every reward big ($0 -> needs $500; $9,450 ->
--     $945; $1.25M -> $125,000). A big gain adds a slightly bigger pop of the whole counter
--     (about the icon, so the icon stays put) and a burst of 6 small bill sparks; in reduced
--     motion neither happens and a short calm glow is shown instead.
--   * Earning line under Cash: Track icon + "+$120 / lap" from store.earningPerLap, a FIXTURE
--     (Brian L owns the real rate, units and formula). Hidden when the value is nil. On phones it
--     shares the slot under the number and fades out while the counter's own gain label shows.
--
-- Store wiring: subscribes to "cash" (the counter's value), "exactCash" (tooltip), and
-- "earningPerLap"; listens to store.Event kinds "CashGain" (amount, worldPosition?) and
-- "CashSpend" (amount). A cash change is applied on the next defer, so an event emitted right
-- after the set (or right before it) is paired with it. Store.reset snaps the counter (it
-- fires Changed("mode") first, which only reset does).
--
-- API: CashLine.new(ctx) -> CashLine
--   :layout()  :setVisible(on)  :destroy()
--   :gain(amount, worldPosition?)  -- visual only (the store event calls it)
--   :spend(amount)                 -- visual only
--   :showExact()
--   :getDebugState()

local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextService = game:GetService("TextService")
local Workspace = game:GetService("Workspace")

local CashIcon = require(script.Parent.Parent.Parent.CurrencyCounter.CashIcon)
local CurrencyCounter = require(script.Parent.Parent.Parent.CurrencyCounter)
local Fade = require(script.Parent.Fade)
local Format = require(ReplicatedStorage.Shared.UI.Format)
local Gloss = require(script.Parent.Parent.Gloss)
local Icons = require(script.Parent.Parent.Icons)
local Layout = require(script.Parent.Layout)
local Motion = require(script.Parent.Parent.Motion)
local PreviewTokens = require(script.Parent.Parent.PreviewTokens)
local Sounds = require(script.Parent.Parent.Sounds)
local Store = require(script.Parent.Parent.Store)
local Tokens = require(ReplicatedStorage.Shared.UI.Tokens)
local Trove = require(ReplicatedStorage.Packages.Trove)
local Types = require(script.Parent.Types)

local C = PreviewTokens.Color
local M = PreviewTokens.Motion
local make = Gloss.make

local COALESCE = 0.6
local CHIP_POOL = 3
local CHIP_HOLD = 0.22
local CHIP_FLY = 0.38
local CHIP_TEXT = 20
local SPEND_POOL = 2
local SPEND_SECONDS = 0.9
local SPARKS = 6
local SPARK_SECONDS = 0.55

export type CashLine = {
	root: Frame,
	layout: (self: CashLine) -> (),
	setVisible: (self: CashLine, on: boolean) -> (),
	destroy: (self: CashLine) -> (),
	gain: (self: CashLine, amount: number, worldPosition: Vector3?) -> (),
	spend: (self: CashLine, amount: number) -> (),
	showExact: (self: CashLine) -> (),
	getDebugState: (self: CashLine) -> { [string]: any },
}

type Chip = {
	frame: Frame,
	label: TextLabel,
	fade: Fade.FadeObject,
	shrink: UIScale,
	amount: number,
	startedAt: number,
	phase: "Idle" | "Hold" | "Fly",
	origin: "World" | "Local",
	token: number,
}

type SpendChip = { frame: Frame, label: TextLabel, fade: Fade.FadeObject, token: number }

local CashLine = {}
CashLine.__index = CashLine

local function textWidth(text: string, size: number): number
	return TextService:GetTextSize(text, size, Enum.Font.FredokaOne, Vector2.new(4096, 4096)).X
end

local function outlined(
	parent: Instance,
	name: string,
	size: number,
	colour: Color3,
	stroke: number,
	z: number
): TextLabel
	local t = make("TextLabel", {
		Name = name,
		BackgroundTransparency = 1,
		FontFace = Tokens.font(),
		TextSize = size,
		TextColor3 = colour,
		Text = "",
		ZIndex = z,
		Parent = parent,
	})
	Gloss.stroke(t, stroke, C.Ink, Enum.ApplyStrokeMode.Contextual)
	return t
end

function CashLine.new(ctx: Types.Ctx): CashLine
	local self = setmetatable({}, CashLine) :: any
	local trove = Trove.new()
	self._trove = trove
	self._ctx = ctx
	self._destroyed = false
	local state = ctx.store:get()
	local m = Layout.cashMetrics()
	self._m = m

	local root = trove:Add(make("Frame", {
		Name = "CashLine",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(m.reservedWidth, m.reservedHeight + 30),
		ZIndex = 4,
		Parent = ctx.layer,
	}))
	self.root = root
	self._scale = make("UIScale", { Name = "HudScale", Scale = ctx.screen:uiScale(), Parent = root })

	-- The approved counter sits in a wrap anchored at the icon centre, so a big-gain pop of
	-- the whole counter keeps the icon in place.
	local iconCentre = Vector2.new(CashIcon.Size.X / 2, m.rowHeight / 2)
	local wrap = make("Frame", {
		Name = "CounterWrap",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(iconCentre.X / m.reservedWidth, iconCentre.Y / m.reservedHeight),
		Position = UDim2.fromOffset(iconCentre.X, iconCentre.Y),
		Size = UDim2.fromOffset(m.reservedWidth, m.reservedHeight),
		ZIndex = 4,
		Parent = root,
	})
	self._wrap = wrap
	self._iconCentre = iconCentre

	-- Glow behind the number (spend emphasis; calm big-gain cue in reduced motion).
	local glow = make("Frame", {
		Name = "Glow",
		Position = UDim2.fromOffset(m.valueX - 8, 4),
		Size = UDim2.fromOffset(120, m.rowHeight - 8),
		BackgroundColor3 = C.White,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 1,
		Parent = wrap,
	})
	Gloss.corner(glow, 14)
	self._glow = glow

	local counter = CurrencyCounter.new(wrap, {
		name = "Cash",
		buildIcon = CashIcon.build,
		iconSize = CashIcon.Size,
		iconArtSize = CashIcon.ArtSize,
		format = Format.cash,
		widestSamples = Layout.CashWidest,
		reducedMotion = Motion.reduced(),
		initial = state.cash,
	})
	trove:Add(function()
		counter:destroy()
	end)
	counter.Root.ZIndex = 2 -- above the glow
	self._counter = counter
	self._target = state.cash
	self._applied = state.cash
	self._exact = state.exactCash
	self._deferQueued = false
	self._snapNext = false
	self._bigCount = 0
	self._lastBigAt = -math.huge
	self._lastThreshold = 0
	self._lastOrigin = "None"

	-- Exact-value hit area over the icon and number (row height >= 48).
	local hitWidth = m.valueX + counter.TextWidth
	local hit = make("TextButton", {
		Name = "CashDetail",
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false,
		Selectable = true,
		Size = UDim2.fromOffset(hitWidth, math.max(m.rowHeight, PreviewTokens.Size.TouchMin)),
		ZIndex = 8,
		Parent = root,
	})
	local ring = make("Frame", {
		Name = "SelectionRing",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 8, 1, 8),
		Position = UDim2.fromOffset(-4, -4),
		Visible = false,
		Parent = hit,
	})
	Gloss.corner(ring, 16)
	Gloss.stroke(ring, 3, C.White)
	hit.SelectionImageObject = ring
	self._hit = hit
	trove:Connect(hit.Activated, function()
		self:showExact()
	end)
	trove:Connect(hit.SelectionGained, function()
		self:showExact()
	end)
	trove:Connect(hit.MouseEnter, function()
		self:showExact()
	end)
	trove:Add(function()
		if GuiService.SelectedObject == hit then
			GuiService.SelectedObject = nil
		end
	end)

	-- Exact-value tooltip.
	local tip = make("Frame", {
		Name = "ExactValue",
		Position = UDim2.fromOffset(m.valueX - 4, m.rowHeight + 2),
		Size = UDim2.fromOffset(140, 34),
		BackgroundColor3 = C.Panel,
		BorderSizePixel = 0,
		Visible = false,
		ZIndex = 20,
		Parent = root,
	})
	Gloss.corner(tip, 10)
	Gloss.stroke(tip, 2.5)
	local tipText = make("TextLabel", {
		Name = "Value",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		FontFace = Tokens.font(),
		TextSize = 20,
		TextColor3 = C.Ink,
		Text = "",
		ZIndex = 21,
		Parent = tip,
	})
	self._tip = tip
	self._tipText = tipText
	self._tipFade = Fade.capture(tip)
	self._tipToken = 0
	trove:Add(function()
		self._tipFade:destroy()
	end)

	-- Earning line (FIXTURE rate).
	local earning = make("Frame", {
		Name = "Earning",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(m.artLeft, m.reservedHeight + 2),
		Size = UDim2.fromOffset(220, Layout.EarningHeight),
		ZIndex = 3,
		Parent = root,
	})
	local trackHolder = make("Frame", {
		Name = "TrackIcon",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(24, 24),
		ZIndex = 3,
		Parent = earning,
	})
	Icons.draw(trackHolder, "Track")
	local earningText = outlined(earning, "Rate", 18, C.White, 2, 4)
	earningText.Position = UDim2.fromOffset(30, 0)
	earningText.Size = UDim2.new(1, -30, 1, 0)
	earningText.TextXAlignment = Enum.TextXAlignment.Left
	self._earning = earning
	self._earningText = earningText
	self._earningFade = Fade.capture(earning)
	self._earningToken = 0
	self._inline = false
	trove:Add(function()
		self._earningFade:destroy()
	end)

	-- Gain chips.
	self._chips = {} :: { Chip }
	for i = 1, CHIP_POOL do
		local frame = make("Frame", {
			Name = "GainChip" .. i,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Size = UDim2.fromOffset(80, 30),
			BackgroundColor3 = C.White,
			BorderSizePixel = 0,
			Visible = false,
			ZIndex = 30,
			Parent = root,
		})
		Gloss.corner(frame, 15)
		Gloss.stroke(frame, 2.5)
		Gloss.gradient(frame, C.CashLight, C.CashDeep)
		local label = outlined(frame, "Amount", CHIP_TEXT, C.White, 2, 31)
		label.Size = UDim2.fromScale(1, 1)
		local shrink = make("UIScale", { Name = "Shrink", Scale = 1, Parent = frame })
		local chip: Chip = {
			frame = frame,
			label = label,
			fade = Fade.capture(frame),
			shrink = shrink,
			amount = 0,
			startedAt = -math.huge,
			phase = "Idle",
			origin = "Local",
			token = 0,
		}
		chip.fade:set(1)
		table.insert(self._chips, chip)
	end

	-- Spend chips.
	self._spends = {} :: { SpendChip }
	self._nextSpend = 1
	for i = 1, SPEND_POOL do
		local frame = make("Frame", {
			Name = "SpendChip" .. i,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Size = UDim2.fromOffset(80, 26),
			BackgroundColor3 = C.Panel,
			BorderSizePixel = 0,
			Visible = false,
			ZIndex = 30,
			Parent = root,
		})
		Gloss.corner(frame, 13)
		Gloss.stroke(frame, 2)
		local label = make("TextLabel", {
			Name = "Amount",
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			FontFace = Tokens.font(),
			TextSize = 18,
			TextColor3 = C.Ink,
			Text = "",
			ZIndex = 31,
			Parent = frame,
		})
		local spendChip: SpendChip = { frame = frame, label = label, fade = Fade.capture(frame), token = 0 }
		spendChip.fade:set(1)
		table.insert(self._spends, spendChip)
	end
	trove:Add(function()
		for _, chip in self._chips do
			chip.token += 1
			chip.fade:destroy()
		end
		for _, s in self._spends do
			s.token += 1
			s.fade:destroy()
		end
	end)

	-- Bill sparks for the big-gain burst.
	self._sparks = {} :: { Frame }
	for i = 1, SPARKS do
		local spark = make("Frame", {
			Name = "BillSpark" .. i,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Size = UDim2.fromOffset(14, 8),
			BackgroundColor3 = Tokens.Color.BillFace,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Visible = false,
			ZIndex = 29,
			Parent = root,
		})
		Gloss.corner(spark, 2)
		local s = Gloss.stroke(spark, 1.5)
		s.Transparency = 1
		make("Frame", {
			Name = "Band",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.new(0, 3, 1, 0),
			BackgroundColor3 = Tokens.Color.BillBand,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ZIndex = 30,
			Parent = spark,
		})
		table.insert(self._sparks, spark)
	end
	trove:Add(function()
		for _, spark in self._sparks do
			Motion.cancelAll(spark)
		end
		Motion.cancelAll(wrap)
		Motion.cancelAll(glow)
	end)

	-- Store wiring.
	trove:Add(ctx.store:subscribe("mode", function()
		self._snapNext = true
	end))
	trove:Add(ctx.store:subscribe("cash", function(value: number)
		self:_onCash(value)
	end))
	trove:Add(ctx.store:subscribe("exactCash", function(value: number)
		self._exact = value
		if self._tip.Visible then
			self:_setTipText()
		end
	end))
	trove:Add(ctx.store:subscribe("earningPerLap", function(value: number?)
		self:_setEarning(value)
	end))
	trove:Connect(ctx.store.Event, function(event: Store.Event)
		if event.kind == "CashGain" and type(event.amount) == "number" and event.amount > 0 then
			self:gain(event.amount, event.worldPosition)
		elseif event.kind == "CashSpend" and type(event.amount) == "number" and event.amount > 0 then
			self:spend(event.amount)
		end
	end)
	trove:Add(Motion.onReducedChanged(function(reduced: boolean)
		self:_onReduced(reduced)
	end))
	trove:Connect(ctx.screen.Changed, function()
		self:layout()
	end)

	self:_setEarning(state.earningPerLap)
	self:layout()
	return self :: CashLine
end

function CashLine.layout(self: any)
	local ctx: Types.Ctx = self._ctx
	local scale = ctx.screen:uiScale()
	self._scale.Scale = scale
	local L = Layout.forProfile(ctx.screen:profile(), scale)
	local m = self._m
	-- a UIScale does not move its own object: the position is in layer pixels
	self.root.Position = UDim2.fromOffset(L.cash.x * scale, L.cash.y * scale)
	self.root.Size = UDim2.fromOffset(m.reservedWidth, L.cash.bottom - L.cash.y)
	self._inline = L.cash.inlineEarning
	self._earning.Position = UDim2.fromOffset(m.artLeft, L.cash.earningY)
end

function CashLine.setVisible(self: any, on: boolean)
	self.root.Visible = on
	if not on then
		self:_settleAll()
	end
end

-- Lands every chip now and hides every transient.
function CashLine._settleAll(self: any)
	for _, chip in self._chips do
		if chip.phase ~= "Idle" then
			self:_land(chip)
		end
	end
	for _, s in self._spends do
		s.token += 1
		Motion.cancelAll(s.frame)
		s.fade:set(1)
		s.frame.Visible = false
	end
	for _, spark in self._sparks do
		Motion.cancelAll(spark)
		spark.Visible = false
	end
	self._tipToken += 1
	self._tipFade:set(1)
	self._tip.Visible = false
end

function CashLine._onReduced(self: any, reduced: boolean)
	self._counter:setReducedMotion(reduced)
	if reduced then
		self:_settleAll()
		Motion.cancelAll(self._wrap)
		local pop = self._wrap:FindFirstChild("Pop") :: UIScale?
		if pop then
			pop.Scale = 1
		end
	end
end

function CashLine._numberEnd(self: any): number
	return self._m.valueX + textWidth(Format.cash(self._applied), Tokens.TextSize.Cash)
end

function CashLine._onCash(self: any, value: number)
	self._target = value
	if self._snapNext then
		self._snapNext = false
		self:_settleAll()
		self._counter:setValue(value, true)
		self._applied = value
		return
	end
	if self._deferQueued then
		return
	end
	self._deferQueued = true
	task.defer(function()
		self._deferQueued = false
		if self._destroyed then
			return
		end
		for _, chip in self._chips do
			if chip.phase ~= "Idle" then
				return -- the landing chip applies the newest value
			end
		end
		self:_apply(nil)
	end)
end

-- Applies the newest supplied value to the approved counter. `gain` is a landed chip amount.
function CashLine._apply(self: any, gain: number?)
	local previous: number = self._applied
	local target: number = self._target
	local big = false
	if gain then
		local threshold = math.max(M.BigGainFraction * previous, M.BigGainMinimum)
		self._lastThreshold = threshold
		local now = os.clock()
		if gain >= threshold and now - self._lastBigAt >= M.BigGainCooldown then
			big = true
			self._lastBigAt = now
			self._bigCount += 1
		end
		Sounds.play(if big then "CashBig" else "CashGain")
	end
	self._counter:setValue(target)
	self._applied = target
	if target > previous and self._inline then
		self:_duckEarning()
	end
	if big then
		self:_celebrate()
	end
end

function CashLine._celebrate(self: any)
	if Motion.reduced() then
		self:_glow(C.SuccessLight, 0.45)
		return
	end
	Motion.pop(self._wrap, 1.06)
	local c = self._iconCentre
	for i, spark in self._sparks do
		local a = math.rad(-165 + (i - 1) * 33)
		local dist = 44 + (i % 3) * 8
		Motion.cancelAll(spark)
		spark.Position = UDim2.fromOffset(c.X, c.Y)
		spark.Rotation = 0
		spark.BackgroundTransparency = 0
		local stroke = spark:FindFirstChildOfClass("UIStroke") :: UIStroke
		local band = spark:FindFirstChild("Band") :: Frame
		stroke.Transparency = 0
		band.BackgroundTransparency = 0
		spark.Visible = true
		local goal = Vector2.new(c.X + math.cos(a) * dist, c.Y + math.sin(a) * dist)
		Motion.tween(spark, "move", Motion.info(SPARK_SECONDS), {
			Position = UDim2.fromOffset(goal.X, goal.Y),
			Rotation = if i % 2 == 0 then 35 else -35,
		})
		local fadeInfo = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, 0.3)
		local t = Motion.tween(spark, "fade", fadeInfo, { BackgroundTransparency = 1 })
		Motion.tween(stroke, "fade", fadeInfo, { Transparency = 1 })
		Motion.tween(band, "fade", fadeInfo, { BackgroundTransparency = 1 })
		t.Completed:Connect(function(state)
			if state == Enum.PlaybackState.Completed then
				spark.Visible = false
			end
		end)
	end
end

function CashLine._glow(self: any, colour: Color3, peak: number)
	local glow: Frame = self._glow
	glow.BackgroundColor3 = colour
	glow.Size = UDim2.fromOffset(self:_numberEnd() - self._m.valueX + 16, self._m.rowHeight - 8)
	glow.BackgroundTransparency = 1
	local up = Motion.tween(glow, "glow", Motion.info(0.12), { BackgroundTransparency = peak })
	up.Completed:Connect(function(state)
		if state == Enum.PlaybackState.Completed then
			Motion.tween(glow, "glow", Motion.info(0.35), { BackgroundTransparency = 1 })
		end
	end)
end

function CashLine._duckEarning(self: any)
	if not self._earning.Visible then
		return
	end
	self._earningToken += 1
	local token = self._earningToken
	self._earningFade:tween(1, 0.1)
	task.delay(Tokens.Motion.CashGainLabelSeconds + 0.1, function()
		if self._destroyed or token ~= self._earningToken then
			return
		end
		self._earningFade:tween(0, 0.2)
	end)
end

function CashLine._setEarning(self: any, rate: number?)
	if rate == nil then
		self._earning.Visible = false
		return
	end
	self._earning.Visible = true
	self._earningText.Text = "+" .. Format.cash(rate) .. " / lap"
end

function CashLine._setTipText(self: any)
	local exact: number = self._exact or self._applied
	local text = "$" .. Format.group(exact)
	self._tipText.Text = text
	self._tip.Size = UDim2.fromOffset(math.ceil(textWidth(text, 20)) + 24, 34)
end

function CashLine.showExact(self: any)
	self:_setTipText()
	self._tipToken += 1
	local token = self._tipToken
	local tip: Frame = self._tip
	if not tip.Visible then
		tip.Visible = true
		self._tipFade:set(1)
	end
	self._tipFade:tween(0, 0.12)
	task.delay(M.ExactValueSeconds, function()
		if self._destroyed or token ~= self._tipToken then
			return
		end
		local t = self._tipFade:tween(1, 0.2)
		if t then
			t.Completed:Connect(function(state)
				if state == Enum.PlaybackState.Completed and token == self._tipToken then
					tip.Visible = false
				end
			end)
		else
			tip.Visible = false
		end
	end)
end

-- World point -> this root's design px, or nil when it does not project inside the device frame.
function CashLine._worldToLocal(self: any, world: Vector3): Vector2?
	local camera = Workspace.CurrentCamera
	if not camera then
		return nil
	end
	local p, onScreen = camera:WorldToViewportPoint(world)
	if not onScreen or p.Z <= 0 then
		return nil
	end
	local abs = Vector2.new(p.X, p.Y)
	local gui = self.root:FindFirstAncestorOfClass("ScreenGui")
	if gui and not gui.IgnoreGuiInset then
		local inset = GuiService:GetGuiInset()
		abs -= inset
	end
	local device: Frame = self._ctx.screen.root
	local d0, ds = device.AbsolutePosition, device.AbsoluteSize
	if abs.X < d0.X or abs.Y < d0.Y or abs.X > d0.X + ds.X or abs.Y > d0.Y + ds.Y then
		return nil
	end
	local offset = self.root.Size.X.Offset
	local k = if offset > 0 then self.root.AbsoluteSize.X / offset else 0
	if k <= 0 then
		return nil
	end
	return (abs - self.root.AbsolutePosition) / k
end

function CashLine._chipText(chip: Chip)
	local text = "+" .. Format.cash(chip.amount)
	chip.label.Text = text
	chip.frame.Size = UDim2.fromOffset(math.ceil(textWidth(text, CHIP_TEXT)) + 22, 30)
end

function CashLine._land(self: any, chip: Chip)
	chip.token += 1
	Motion.cancelAll(chip.frame)
	Motion.cancelAll(chip.shrink)
	chip.phase = "Idle"
	chip.fade:set(1)
	chip.frame.Visible = false
	chip.shrink.Scale = 1
	self:_apply(chip.amount)
end

function CashLine.gain(self: any, amount: number, worldPosition: Vector3?)
	if self._destroyed or amount <= 0 then
		return
	end
	local now = os.clock()
	-- Join a chip that started recently and has not landed.
	for _, chip in self._chips do
		if chip.phase ~= "Idle" and now - chip.startedAt < COALESCE then
			chip.amount += amount
			CashLine._chipText(chip)
			Motion.pop(chip.frame, 1.12)
			return
		end
	end
	local chip: Chip? = nil
	for _, c in self._chips do
		if c.phase == "Idle" then
			chip = c
			break
		end
	end
	if chip == nil then
		local oldest: Chip = self._chips[1]
		for _, c in self._chips do
			if c.startedAt < oldest.startedAt then
				oldest = c
			end
		end
		self:_land(oldest)
		chip = oldest
	end
	local c = chip :: Chip
	c.amount = amount
	c.startedAt = now
	c.token += 1
	local token = c.token
	CashLine._chipText(c)
	local m = self._m
	local endX = self:_numberEnd()
	local target = Vector2.new(endX - 18, m.rowHeight / 2)
	local origin = if worldPosition then self:_worldToLocal(worldPosition) else nil
	c.origin = if origin then "World" else "Local"
	self._lastOrigin = c.origin
	local start = origin or Vector2.new(endX + c.frame.Size.X.Offset / 2 + 10, m.rowHeight / 2 + 22)
	c.frame.Visible = true
	c.shrink.Scale = 1
	if not self.root.Visible or Motion.reduced() then
		-- No flight: the counter updates now and the chip fades in place beside the number.
		c.frame.Position = UDim2.fromOffset(start.X, start.Y)
		c.phase = "Hold"
		self:_apply(c.amount)
		c.phase = "Idle"
		c.fade:set(1)
		c.fade:tween(0, 0.1)
		task.delay(0.6, function()
			if self._destroyed or token ~= c.token then
				return
			end
			local t = c.fade:tween(1, 0.2)
			if t then
				t.Completed:Connect(function(state)
					if state == Enum.PlaybackState.Completed and token == c.token then
						c.frame.Visible = false
					end
				end)
			end
		end)
		return
	end
	c.phase = "Hold"
	c.frame.Position = UDim2.fromOffset(start.X, start.Y)
	c.fade:set(1)
	c.fade:tween(0, 0.1)
	Motion.pop(c.frame, 1.1)
	task.delay(CHIP_HOLD, function()
		if self._destroyed or token ~= c.token then
			return
		end
		c.phase = "Fly"
		local info = Motion.info(CHIP_FLY, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		Motion.tween(c.frame, "fly", info, { Position = UDim2.fromOffset(target.X, target.Y) })
		Motion.tween(c.shrink, "shrink", info, { Scale = 0.6 })
		task.delay(CHIP_FLY * 0.6, function()
			if self._destroyed or token ~= c.token then
				return
			end
			c.fade:tween(1, CHIP_FLY * 0.4)
		end)
		task.delay(CHIP_FLY, function()
			if self._destroyed or token ~= c.token then
				return
			end
			self:_land(c)
		end)
	end)
end

function CashLine.spend(self: any, amount: number)
	if self._destroyed or amount <= 0 then
		return
	end
	Sounds.play("CashSpend")
	self:_glow(C.White, 0.6)
	local s: SpendChip = self._spends[self._nextSpend]
	self._nextSpend = self._nextSpend % SPEND_POOL + 1
	s.token += 1
	local token = s.token
	local text = "-" .. Format.cash(amount)
	s.label.Text = text
	s.frame.Size = UDim2.fromOffset(math.ceil(textWidth(text, 18)) + 20, 26)
	local m = self._m
	local x = self:_numberEnd() + s.frame.Size.X.Offset / 2 + 8
	local y = m.rowHeight / 2 + 8
	Motion.cancelAll(s.frame)
	s.frame.Position = UDim2.fromOffset(x, y)
	s.frame.Visible = true
	s.fade:set(0)
	if not Motion.reduced() then
		Motion.tween(s.frame, "drift", Motion.info(SPEND_SECONDS), { Position = UDim2.fromOffset(x, y + 14) })
	end
	task.delay(SPEND_SECONDS * 0.45, function()
		if self._destroyed or token ~= s.token then
			return
		end
		local t = s.fade:tween(1, SPEND_SECONDS * 0.55)
		if t then
			t.Completed:Connect(function(state)
				if state == Enum.PlaybackState.Completed and token == s.token then
					s.frame.Visible = false
				end
			end)
		end
	end)
end

function CashLine.getDebugState(self: any): { [string]: any }
	local chips = {}
	local active = 0
	for _, chip in self._chips do
		if chip.phase ~= "Idle" then
			active += 1
		end
		table.insert(chips, { amount = chip.amount, phase = chip.phase, origin = chip.origin })
	end
	local sparks = 0
	for _, spark in self._sparks do
		if spark.Visible then
			sparks += 1
		end
	end
	local spends = 0
	for _, s in self._spends do
		if s.frame.Visible then
			spends += 1
		end
	end
	return {
		visible = self.root.Visible,
		target = self._target,
		applied = self._applied,
		exactText = self._tipText.Text,
		tooltipVisible = self._tip.Visible,
		chips = chips,
		chipsActive = active,
		chipPool = CHIP_POOL,
		spendChipsVisible = spends,
		sparksVisible = sparks,
		sparkPool = SPARKS,
		bigCount = self._bigCount,
		lastBigAt = self._lastBigAt,
		lastThreshold = self._lastThreshold,
		lastOrigin = self._lastOrigin,
		earningVisible = self._earning.Visible,
		earningText = self._earningText.Text,
		earningFade = self._earningFade.value,
		inlineEarning = self._inline,
		reduced = Motion.reduced(),
		scale = self._scale.Scale,
		counter = self._counter:getDebugState(),
	}
end

function CashLine.destroy(self: any)
	if self._destroyed then
		return
	end
	self._destroyed = true
	self._trove:Destroy()
end

return CashLine
