--!strict
-- Run HUD: Cash (top left), Distance (top centre), Heat (bottom centre).
-- Lane 3 owns this presentation. Lanes 1 and 2 supply its state; it displays
-- that state and nothing else: no remotes, no saving, no balance changes, no
-- gameplay decisions.
--
-- Provisional input contract (needs Lane 1 and Lane 2 agreement, decision 0007):
--   RunHudState = {
--     cash: number,                  -- server-owned balance, display only (Lane 2); the
--                                    -- floating counter animates changes but always lands
--                                    -- exactly on this value
--     distance: number,              -- metres this run (Lane 1)
--     heat: number,                  -- 0 to 1 on the ridden car (Lane 1)
--     stage: HeatStage?,             -- "Calm" | "Warning" | "Critical" | "Meltdown" (Lane 1)
--     meltdownRemaining01: number?,  -- no longer used (0008 amendment: no visible timer); ignored
--   }
-- Also provisional, for Lane 1: hud:jolt(strength?) plays the presentation-only
-- bump reaction, and hud.HeatCue fires ("Stage" | "AlarmPeak", stage) for
-- future audio. Neither changes any gameplay value.
--
-- Scaling: each widget root has one UIScale ("HudScale") set to
-- Tokens.uiScaleFor(viewport). It scales the widget's size, text, strokes and
-- corners. A UIScale does not move a widget, so only the gap between a widget
-- and the safe-area edge is multiplied by the scale in code. Nothing is scaled
-- twice. The Heat gauge has a second UIScale inside it ("StageScale"); that is
-- the design's stage emphasis, not device scaling.
--
-- Reduced motion follows GuiService.ReducedMotionEnabled (the player's Roblox
-- setting). setReducedMotionOverride exists for the development preview only;
-- it is never saved and production code does not call it.

local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextService = game:GetService("TextService")
local Workspace = game:GetService("Workspace")

local CashIcon = require(script.Parent.CurrencyCounter.CashIcon)
local CurrencyCounter = require(script.Parent.CurrencyCounter)
local FlagIcon = require(script.FlagIcon)
local Format = require(ReplicatedStorage.Shared.UI.Format)
local HeatGauge = require(script.HeatGauge)
local OutlinedText = require(script.Parent.OutlinedText)
local Tokens = require(ReplicatedStorage.Shared.UI.Tokens)
local Trove = require(ReplicatedStorage.Packages.Trove)

export type HeatStage = HeatGauge.HeatStage

export type RunHudState = {
	cash: number,
	distance: number,
	heat: number,
	stage: HeatStage?,
	meltdownRemaining01: number?,
}

export type Options = {
	name: string?,
	displayOrder: number?,
	palette: Tokens.Palette?,
	reducedMotionOverride: boolean?,
}

-- Widest Cash strings the counter reserves room for: every width class
-- Format.cash produces, up to "$1,000T" (the first value past the T suffix).
local CASH_WIDEST = { "$9,999", "$99.9K", "$999K", "$9.99M", "$99.9M", "$999M", "$999B", "$999T", "$1,000T" }
-- Widest Distance values (number, unit) the HUD reserves room for.
local DISTANCE_WIDEST = { { "9,999", "m" }, { "999.9", "km" }, { "9,999", "km" } }
local DISTANCE_UNIT_SIZE = 22
-- Minimum distance between the Heat panel (with its effects) and the safe-area edge.
local SAFE_MARGIN = 24
-- Minimum visible gap between Cash (at its largest punch) and Distance.
local TOP_ROW_GAP = 12
-- Narrow screens lower the Cash punch before moving Distance off centre, but
-- never below this, so a gain still reads as a gain.
local MIN_PUNCH = 0.06

local RunHud = {}
RunHud.__index = RunHud

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

local function nonInteractive(widget: GuiObject)
	widget.Active = false
	pcall(function()
		(widget :: any).Interactable = false
	end)
end

local function textWidthOf(text: string, size: number): number
	return TextService:GetTextSize(text, size, Enum.Font.FredokaOne, Vector2.new(4096, 4096)).X
end

export type DistanceWidget = {
	root: Frame,
	number: OutlinedText.Parts,
	unit: OutlinedText.Parts,
	set: (metres: number) -> (),
	size: Vector2,
	artLeft: number,
}

-- Distance (approved option B): a floating white-to-cream number with the
-- flag icon, styled like Cash (same outline, shadow and alignment rules).
-- The unit is a second, smaller outlined label placed on the number's
-- baseline right after it. (A single rich-text label was tried; Roblox draws
-- a much thinner UIStroke on rich text, so the outline would not match Cash.)
local function buildDistance(parent: Instance, palette: Tokens.Palette): DistanceWidget
	local textSize = Tokens.TextSize.FloatDistance
	local unitSize = DISTANCE_UNIT_SIZE
	local outline = OutlinedText.Outline
	local space = textWidthOf(" ", unitSize)
	local widestNumber, widest = 0, 0
	for _, sample in DISTANCE_WIDEST do
		local number = textWidthOf(sample[1], textSize)
		widestNumber = math.max(widestNumber, number)
		widest = math.max(widest, number + space + textWidthOf(sample[2], unitSize))
	end
	local textWidth = math.ceil(widest + 2 * outline)
	local textHeight = textSize + 2 * outline
	local unitHeight = unitSize + 2 * outline
	local side = FlagIcon.Size.X
	local art = FlagIcon.ArtSize
	local rowHeight = math.max(FlagIcon.Size.Y, textHeight + OutlinedText.ShadowOffset)
	local mid = rowHeight / 2
	local artLeft = side / 2 - art.X / 2
	local inkLeft = OutlinedText.DigitInkLeftEm * textSize - outline
	local textX = side / 2 + art.X / 2 + CurrencyCounter.Gap - inkLeft
	local size = Vector2.new(textX + textWidth, rowHeight)
	-- Baseline of the number (digits sit on it), and where the unit label's
	-- own baseline sits inside it, from the measured digit metrics.
	local baselineY = mid + OutlinedText.DigitHeightEm * textSize / 2
	local unitBaselineAnchor = 0.5
		+ (OutlinedText.DigitCentreEm + OutlinedText.DigitHeightEm / 2) * unitSize / unitHeight

	local root = make("Frame", {
		Name = "Distance",
		AnchorPoint = Vector2.new(0.5, 0),
		Size = UDim2.fromOffset(size.X, size.Y),
		BackgroundTransparency = 1,
		Parent = parent,
	})
	nonInteractive(root)
	make("UIScale", { Name = "HudScale", Scale = 1, Parent = root })
	local flagHolder = make("Frame", {
		Name = "FlagHolder",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(side / 2 / size.X, mid / size.Y),
		Size = UDim2.fromOffset(side, side),
		BackgroundTransparency = 1,
		Parent = root,
	})
	FlagIcon.build(flagHolder, palette)
	local valueFrame = make("Frame", {
		Name = "Value",
		AnchorPoint = Vector2.new(0, 0.5 + OutlinedText.DigitCentreEm * textSize / textHeight),
		Position = UDim2.fromScale(textX / size.X, mid / size.Y),
		Size = UDim2.fromOffset(math.ceil(widestNumber + 2 * outline), textHeight),
		BackgroundTransparency = 1,
		Parent = root,
	})
	local number =
		OutlinedText.build(valueFrame, "Text", textSize, palette.FloatText, palette.FloatTextCream, palette, 2)
	local unitFrame = make("Frame", {
		Name = "Unit",
		AnchorPoint = Vector2.new(0, unitBaselineAnchor),
		Size = UDim2.fromOffset(math.ceil(textWidthOf("km", unitSize) + 2 * outline), unitHeight),
		BackgroundTransparency = 1,
		Parent = root,
	})
	local unit = OutlinedText.build(unitFrame, "Text", unitSize, palette.FloatText, palette.FloatTextCream, palette, 2)
	local function set(metres: number)
		local numberText, unitText = Format.distanceParts(metres)
		OutlinedText.setText(number, numberText)
		OutlinedText.setText(unit, unitText)
		-- The unit follows the number's advance width plus one space.
		local unitX = textX + textWidthOf(numberText, textSize) + space
		unitFrame.Position = UDim2.fromScale(unitX / size.X, baselineY / size.Y)
	end
	return {
		root = root,
		number = number,
		unit = unit,
		set = set,
		size = size,
		artLeft = artLeft,
	}
end

function RunHud.new(parent: Instance, options: Options?)
	local opts: Options = options or {}
	local palette: Tokens.Palette = opts.palette or Tokens.Color
	local self = setmetatable({}, RunHud)
	self._trove = Trove.new()
	self._override = opts.reducedMotionOverride
	self._state = { cash = 0, distance = 0, heat = 0 } :: RunHudState
	self._scale = 1
	self._mounted = false

	local gui = make("ScreenGui", {
		Name = opts.name or "RunHud",
		ResetOnSpawn = false,
		IgnoreGuiInset = false,
		ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = opts.displayOrder or 0,
	})
	self._trove:Add(gui)
	self.Gui = gui

	-- Cash, top left: floating counter (no card), scaled once by HudScale.
	local counter = CurrencyCounter.new(gui, {
		name = "Cash",
		palette = palette,
		buildIcon = CashIcon.build,
		iconSize = CashIcon.Size,
		iconArtSize = CashIcon.ArtSize,
		format = Format.cash,
		widestSamples = CASH_WIDEST,
		reducedMotion = self:isReducedMotion(),
	})
	make("UIScale", { Name = "HudScale", Scale = 1, Parent = counter.Root })
	self._counter = counter
	self._cashRoot = counter.Root
	self._trove:Add(function()
		counter:destroy()
	end)

	-- Distance, top centre (option B, approved by Adam 2026-10-19). The number
	-- and unit are left-aligned after the flag, like Cash after its icon, so
	-- the flag always sits 8 px from the digits.
	local distance = buildDistance(gui, palette)
	local distanceRoot = distance.root
	self._distance = distance
	self._distanceRoot = distanceRoot

	-- Heat, bottom centre.
	local gauge = HeatGauge.new(gui, palette, self:isReducedMotion())
	nonInteractive(gauge.Root)
	make("UIScale", { Name = "HudScale", Scale = 1, Parent = gauge.Root })
	self._gauge = gauge
	self._gaugeRoot = gauge.Root
	self.HeatCue = gauge.Cue
	self._trove:Add(function()
		gauge:destroy()
	end)

	local function applyScale()
		local camera = Workspace.CurrentCamera
		local viewport = if camera then camera.ViewportSize else Vector2.new(1280, 720)
		local scale = Tokens.uiScaleFor(viewport)
		self._scale = scale
		self._viewport = viewport
		local gap = Tokens.Space.M * scale
		for _, root in { counter.Root, distanceRoot, gauge.Root } do
			(root:FindFirstChild("HudScale") :: UIScale).Scale = scale
		end
		counter.Root.Position = UDim2.fromOffset(gap, gap)
		-- Top row (predictable rule, all in rendered px):
		--   1. Distance is centred.
		--   2. If the widest Cash value at its biggest punch would come within
		--      TOP_ROW_GAP of the flag, the Cash punch is lowered to fit.
		--   3. Only if that would need a punch below MIN_PUNCH does Distance
		--      move right, never past the safe area.
		--   4. If even no punch would leave TOP_ROW_GAP at the right edge (the
		--      narrowest phones, about 375 px and below), Distance moves to its
		--      own row under Cash, against the right edge, and Cash keeps its
		--      full punch. Text sizes never shrink.
		--   5. Anything still overlapping is recorded for review, not hidden.
		local safeWidth = gui.AbsoluteSize.X
		local minGap = TOP_ROW_GAP * scale
		local valueLeft = gap + counter.ValueX * scale
		local inkWidth = counter.WidestInkRight * scale
		local halfDistance = distance.size.X * scale / 2
		local flagInset = distance.artLeft * scale
		local function punchFor(centre: number): number
			local room = (centre - halfDistance + flagInset) - minGap - valueLeft
			return room / inkWidth - 1
		end
		local centreX = safeWidth / 2
		local maxCentre = safeWidth - gap - halfDistance
		if punchFor(centreX) < MIN_PUNCH then
			local needed = valueLeft + inkWidth * (1 + MIN_PUNCH) + minGap + halfDistance - flagInset
			centreX = math.max(centreX, math.min(needed, maxCentre))
		end
		local punch = punchFor(centreX)
		local distanceY = gap
		self._distanceRow = 1
		if punch < 0 and safeWidth > 0 then
			centreX = maxCentre
			punch = Tokens.Motion.CashPunchBig
			-- Below the Cash row at its largest punch (and its shadow).
			distanceY = gap + (counter.RowHeight + OutlinedText.ShadowOffset) * scale + minGap
			self._distanceRow = 2
		end
		counter:setMaxPunch(math.clamp(punch, 0, Tokens.Motion.CashPunchBig))
		self._layoutConflict = math.max(0, -punch * inkWidth)
		self._topRowPunch = math.clamp(punch, 0, Tokens.Motion.CashPunchBig)
		distanceRoot.Position = UDim2.fromOffset(centreX, distanceY)
		-- In portrait the gauge is nearly as wide as the screen, so it would
		-- cover both bottom corners where touch controls (the Hop button)
		-- live. There it sits one touch row higher; landscape has room beside it.
		local portrait = viewport.Y > viewport.X
		local touchRow = if portrait then (Tokens.Touch.Primary + Tokens.Space.XL) * scale else 0
		-- The panel and its effects (halo) stay at least 24 px inside the safe
		-- area: at the bottom, and at the sides through a cap on stage growth.
		local edge = SAFE_MARGIN + HeatGauge.EffectMargin * scale
		gauge.Root.Position = UDim2.new(0.5, 0, 1, -(edge + touchRow))
		local fullWidth = (HeatGauge.Size.X + 2 * HeatGauge.EffectMargin) * scale
		local maxGrowth = if safeWidth > 0 then (safeWidth - 2 * SAFE_MARGIN) / fullWidth else 1
		gauge:setLayout(maxGrowth, if portrait then 0.6 else 1)
		self._maxGrowth = maxGrowth
	end
	applyScale()
	self._trove:Connect(gui:GetPropertyChangedSignal("AbsoluteSize"), applyScale)
	local function watchCamera()
		local camera = Workspace.CurrentCamera
		if camera then
			self._trove:Connect(camera:GetPropertyChangedSignal("ViewportSize"), applyScale)
		end
		applyScale()
	end
	watchCamera()
	self._trove:Connect(Workspace:GetPropertyChangedSignal("CurrentCamera"), watchCamera)

	self._trove:Connect(GuiService:GetPropertyChangedSignal("ReducedMotionEnabled"), function()
		gauge:setReducedMotion(self:isReducedMotion())
		counter:setReducedMotion(self:isReducedMotion())
	end)

	gui.Parent = parent
	-- Show defaults for Distance and Heat without any animation; Cash stays
	-- empty until the first setState. The first setState then mounts every
	-- widget at the supplied state with no gain, fill or stage transition.
	self:_setDistance(0)
	gauge:snap(0, nil)
	return self
end

function RunHud._setDistance(self: any, metres: number)
	self._distance.set(metres)
end

-- Development preview only: builds a standalone Distance widget (for the
-- enlarged alignment close-up) showing `metres`.
function RunHud.buildDistancePreview(parent: Instance, palette: Tokens.Palette, metres: number): DistanceWidget
	local widget = buildDistance(parent, palette)
	widget.set(metres)
	return widget
end

function RunHud.isReducedMotion(self: any): boolean
	if self._override ~= nil then
		return self._override
	end
	return GuiService.ReducedMotionEnabled
end

-- Preview only. nil returns to following the player's Roblox setting.
function RunHud.setReducedMotionOverride(self: any, value: boolean?)
	self._override = value
	self._gauge:setReducedMotion(self:isReducedMotion())
	self._counter:setReducedMotion(self:isReducedMotion())
end

function RunHud.setState(self: any, state: RunHudState)
	self._state = state
	-- The counter snaps on its first value and animates later changes.
	self._counter:setValue(state.cash)
	self:_setDistance(state.distance)
	if self._mounted then
		self._gauge:set(state.heat, state.stage)
	else
		-- First supplied state: shown as it is, with no entrance fill or stage
		-- cross-fade. An ongoing Critical or Meltdown alarm still runs.
		self._mounted = true
		self._gauge:snap(state.heat, state.stage)
	end
end

-- Presentation-only bump reaction (provisional, for Lane 1). Changes no Heat.
function RunHud.jolt(self: any, strength: number?)
	self._gauge:jolt(strength)
end

function RunHud.getDebugState(self: any): { [string]: any }
	local function box(root: GuiObject): string
		return string.format(
			"%dx%d at (%d,%d)",
			root.AbsoluteSize.X,
			root.AbsoluteSize.Y,
			root.AbsolutePosition.X,
			root.AbsolutePosition.Y
		)
	end
	return {
		viewport = self._viewport,
		scale = self._scale,
		reducedMotion = self:isReducedMotion(),
		override = self._override,
		cash = self._counter:getDebugState(),
		cashText = self._counter:getDebugState().text,
		cashFits = self._counter:getDebugState().textFits,
		layoutConflict = self._layoutConflict,
		topRowPunch = self._topRowPunch,
		distanceRow = self._distanceRow,
		distanceText = self._distance.number.face.Text .. " " .. self._distance.unit.face.Text,
		distanceFits = self._distance.number.face.TextFits and self._distance.unit.face.TextFits,
		cashBox = box(self._cashRoot),
		distanceBox = box(self._distanceRoot),
		gaugeBox = box(self._gaugeRoot),
		maxGrowth = self._maxGrowth,
		gauge = self._gauge:getDebugState(),
	}
end

function RunHud.destroy(self: any)
	self._trove:Destroy()
end

return RunHud
