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
local Workspace = game:GetService("Workspace")

local CashIcon = require(script.Parent.CurrencyCounter.CashIcon)
local CurrencyCounter = require(script.Parent.CurrencyCounter)
local Format = require(ReplicatedStorage.Shared.UI.Format)
local HeatGauge = require(script.HeatGauge)
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
	-- "Pill" (default, option A) or "Floating" (option B, a proposal shown
	-- only in the preview until Adam chooses).
	distanceStyle: ("Pill" | "Floating")?,
}

-- Widest Cash strings the counter reserves room for (Format.cash never
-- produces anything wider below $1,000T).
local CASH_WIDEST = { "$9,999", "$99.9K", "$999K", "$9.99M", "$99.9M", "$999B" }
-- Fixed Distance size (design px) so a new digit never resizes the HUD.
local DISTANCE_SIZE = Vector2.new(164, 44)
-- Minimum distance between the Heat panel (with its effects) and the safe-area edge.
local SAFE_MARGIN = 24

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

-- A cream card with a soft navy shadow. Returns the widget root and the card.
local function card(
	name: string,
	size: Vector2,
	radius: UDim,
	palette: Tokens.Palette,
	parent: Instance
): (Frame, Frame)
	local root = make("Frame", {
		Name = name,
		Size = UDim2.fromOffset(size.X, size.Y),
		BackgroundTransparency = 1,
		Parent = parent,
	})
	nonInteractive(root)
	make("UIScale", { Name = "HudScale", Scale = 1, Parent = root })
	local shadow = make("Frame", {
		Name = "Shadow",
		Position = UDim2.fromOffset(0, Tokens.Shadow.OffsetY),
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = palette.Shadow,
		BackgroundTransparency = Tokens.Shadow.Transparency,
		BorderSizePixel = 0,
		Parent = root,
	})
	make("UICorner", { CornerRadius = radius, Parent = shadow })
	local face = make("Frame", {
		Name = "Card",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = palette.Card,
		BorderSizePixel = 0,
		ZIndex = 2,
		Parent = root,
	})
	make("UICorner", { CornerRadius = radius, Parent = face })
	make("UIStroke", {
		Color = palette.Stroke,
		Thickness = Tokens.Stroke.Regular,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = face,
	})
	return root, face
end

-- Floating white text with a near-black outline and a drop shadow (option B).
local function floatingText(parent: Instance, name: string, size: number, palette: Tokens.Palette): TextLabel
	local label = make("TextLabel", {
		Name = name,
		BackgroundTransparency = 1,
		FontFace = Tokens.font(),
		TextSize = size,
		TextColor3 = palette.FloatText,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 3,
		Parent = parent,
	})
	make("UIStroke", {
		Color = palette.CashOutline,
		Thickness = 3,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
		Parent = label,
	})
	local shadow = make("TextLabel", {
		Name = "Shadow",
		Position = UDim2.fromOffset(0, 3),
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		FontFace = Tokens.font(),
		TextSize = size,
		TextColor3 = palette.CashShadow,
		TextTransparency = 0.35,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 2,
		Parent = label,
	})
	label:GetPropertyChangedSignal("Text"):Connect(function()
		shadow.Text = label.Text
	end)
	label:GetPropertyChangedSignal("TextXAlignment"):Connect(function()
		shadow.TextXAlignment = label.TextXAlignment
	end)
	return label
end

-- Small original checkered flag on a pole (option B icon).
local function buildFlag(parent: Instance, palette: Tokens.Palette)
	local holder = make("Frame", {
		Name = "Flag",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.fromScale(0, 0.5),
		Size = UDim2.fromOffset(24, 28),
		Rotation = -8,
		BackgroundTransparency = 1,
		Parent = parent,
	})
	local pole = make("Frame", {
		Name = "Pole",
		Position = UDim2.fromOffset(2, 2),
		Size = UDim2.fromOffset(4, 24),
		BackgroundColor3 = palette.Chrome,
		BorderSizePixel = 0,
		Parent = holder,
	})
	make("UIStroke", { Color = palette.CashOutline, Thickness = 2, Parent = pole })
	local cloth = make("Frame", {
		Name = "Cloth",
		Position = UDim2.fromOffset(6, 2),
		Size = UDim2.fromOffset(16, 12),
		BackgroundColor3 = palette.FloatText,
		BorderSizePixel = 0,
		Parent = holder,
	})
	make("UIStroke", { Color = palette.CashOutline, Thickness = 2, Parent = cloth })
	for _, spot in { { 0, 0 }, { 8, 6 } } do
		make("Frame", {
			Name = "Check",
			Position = UDim2.fromOffset(spot[1], spot[2]),
			Size = UDim2.fromOffset(8, 6),
			BackgroundColor3 = palette.CashOutline,
			BorderSizePixel = 0,
			Parent = cloth,
		})
	end
end

function RunHud.new(parent: Instance, options: Options?)
	local opts: Options = options or {}
	local palette: Tokens.Palette = opts.palette or Tokens.Color
	local self = setmetatable({}, RunHud)
	self._trove = Trove.new()
	self._override = opts.reducedMotionOverride
	self._state = { cash = 0, distance = 0, heat = 0 } :: RunHudState
	self._scale = 1

	local font = Tokens.font()

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

	-- Distance, top centre. Option A (default): cream pill. Option B
	-- (proposal, preview only): floating white number with a flag icon.
	-- Digits are right-aligned in a fixed slot and the unit sits in its own
	-- slot, so the unit never jumps as digits change.
	local distanceStyle = opts.distanceStyle or "Pill"
	self._distanceStyle = distanceStyle
	local distanceRoot
	if distanceStyle == "Floating" then
		distanceRoot = make("Frame", {
			Name = "Distance",
			Size = UDim2.fromOffset(DISTANCE_SIZE.X, DISTANCE_SIZE.Y),
			BackgroundTransparency = 1,
			Parent = gui,
		})
		nonInteractive(distanceRoot)
		make("UIScale", { Name = "HudScale", Scale = 1, Parent = distanceRoot })
		buildFlag(distanceRoot, palette)
		self._distanceText = floatingText(distanceRoot, "Value", Tokens.TextSize.FloatDistance, palette)
		self._distanceText.Position = UDim2.fromOffset(28, 0)
		self._distanceText.Size = UDim2.new(0, 96, 1, 0)
		self._distanceText.TextXAlignment = Enum.TextXAlignment.Right
		self._distanceUnit = floatingText(distanceRoot, "Unit", Tokens.TextSize.Label, palette)
		self._distanceUnit.Position = UDim2.fromOffset(28 + 96 + Tokens.Space.XS, 4)
		self._distanceUnit.Size = UDim2.new(0, 36, 1, 0)
	else
		local pill
		distanceRoot, pill = card("Distance", DISTANCE_SIZE, Tokens.Radius.Pill, palette, gui)
		self._distanceText = make("TextLabel", {
			Name = "Value",
			Position = UDim2.fromOffset(Tokens.Space.L, 0),
			Size = UDim2.new(0, 96, 1, 0),
			BackgroundTransparency = 1,
			FontFace = font,
			TextSize = Tokens.TextSize.Value,
			TextColor3 = palette.Text,
			TextXAlignment = Enum.TextXAlignment.Right,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Text = "0",
			ZIndex = 3,
			Parent = pill,
		})
		self._distanceUnit = make("TextLabel", {
			Name = "Unit",
			Position = UDim2.fromOffset(Tokens.Space.L + 96 + Tokens.Space.XS, 2),
			Size = UDim2.new(0, 36, 1, 0),
			BackgroundTransparency = 1,
			FontFace = font,
			TextSize = Tokens.TextSize.Label,
			TextColor3 = palette.TextSecondary,
			TextXAlignment = Enum.TextXAlignment.Left,
			Text = "m",
			ZIndex = 3,
			Parent = pill,
		})
	end
	distanceRoot.AnchorPoint = Vector2.new(0.5, 0)
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
		-- Distance stays centred unless that would touch the Cash counter's
		-- reserved row (widest value plus punch); then it moves right just
		-- enough to clear it, but never past the safe area. If even that is
		-- not enough the overlap is recorded for review, not hidden.
		local safeWidth = gui.AbsoluteSize.X
		local cashRight = gap + counter.ReservedSize.X * scale
		local halfDistance = DISTANCE_SIZE.X * scale / 2
		local wanted = math.max(safeWidth / 2, cashRight + gap + halfDistance)
		local maxCentre = safeWidth - gap - halfDistance
		local centreX = if safeWidth > 0 then math.min(wanted, maxCentre) else wanted
		self._layoutConflict = math.max(0, (cashRight + gap) - (centreX - halfDistance))
		distanceRoot.Position = UDim2.fromOffset(centreX, gap)
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
	-- Show defaults for Distance and Heat; Cash stays empty until the first
	-- real setState, which mounts it without a "gain" animation.
	local number, unit = Format.distanceParts(0)
	self._distanceText.Text = number
	self._distanceUnit.Text = unit
	gauge:set(0, nil)
	return self
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
	local number, unit = Format.distanceParts(state.distance)
	self._distanceText.Text = number
	self._distanceUnit.Text = unit
	self._gauge:set(state.heat, state.stage)
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
		distanceStyle = self._distanceStyle,
		distanceText = self._distanceText.Text .. " " .. self._distanceUnit.Text,
		distanceFits = self._distanceText.TextFits and self._distanceUnit.TextFits,
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
