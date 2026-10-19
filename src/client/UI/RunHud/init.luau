--!strict
-- Run HUD: Cash (top left), Distance (top centre), Heat (bottom centre).
-- Lane 3 owns this presentation. Lanes 1 and 2 supply its state; it displays
-- that state and nothing else: no remotes, no saving, no balance changes, no
-- gameplay decisions.
--
-- Provisional input contract (needs Lane 1 and Lane 2 agreement, decision 0007):
--   RunHudState = {
--     cash: number,                  -- server-owned balance, display only (Lane 2)
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
}

-- Fixed widget sizes (design px) so a value gaining a digit never resizes the
-- HUD. Sized for "$999,999" and "9,999 m"; larger values use the compact
-- formats in Format.
local CASH_SIZE = Vector2.new(168, 48)
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

	-- Cash, top left.
	local cashRoot, cashCard = card("Cash", CASH_SIZE, Tokens.Radius.Card, palette, gui)
	cashRoot.AnchorPoint = Vector2.new(0, 0)
	local coin = make("Frame", {
		Name = "Coin",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, Tokens.Space.M, 0.5, 0),
		Size = UDim2.fromOffset(28, 28),
		BackgroundColor3 = palette.Coin,
		ZIndex = 3,
		Parent = cashCard,
	})
	make("UICorner", { CornerRadius = Tokens.Radius.Pill, Parent = coin })
	make("UIStroke", { Color = palette.Stroke, Thickness = Tokens.Stroke.Thin, Parent = coin })
	make("TextLabel", {
		Name = "Symbol",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		FontFace = font,
		TextSize = Tokens.TextSize.Minimum,
		TextColor3 = palette.Text,
		Text = "$",
		ZIndex = 4,
		Parent = coin,
	})
	self._cashText = make("TextLabel", {
		Name = "Value",
		Position = UDim2.fromOffset(Tokens.Space.M + 28 + Tokens.Space.S, 0),
		Size = UDim2.new(1, -(Tokens.Space.M + 28 + Tokens.Space.S + Tokens.Space.M), 1, 0),
		BackgroundTransparency = 1,
		FontFace = font,
		TextSize = Tokens.TextSize.Value,
		TextColor3 = palette.Text,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Text = "$0",
		ZIndex = 3,
		Parent = cashCard,
	})
	self._cashRoot = cashRoot

	-- Distance, top centre. Digits are right-aligned in a fixed slot and the
	-- unit sits in its own slot, so the unit never jumps as digits change.
	local distanceRoot, distanceCard = card("Distance", DISTANCE_SIZE, Tokens.Radius.Pill, palette, gui)
	distanceRoot.AnchorPoint = Vector2.new(0.5, 0)
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
		Parent = distanceCard,
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
		Parent = distanceCard,
	})
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
		for _, root in { cashRoot, distanceRoot, gauge.Root } do
			(root:FindFirstChild("HudScale") :: UIScale).Scale = scale
		end
		cashRoot.Position = UDim2.fromOffset(gap, gap)
		-- Distance stays centred unless that would touch the Cash card (narrow
		-- phones in portrait); then it moves right just enough to clear it.
		local safeWidth = gui.AbsoluteSize.X
		local cashRight = gap + CASH_SIZE.X * scale
		local halfDistance = DISTANCE_SIZE.X * scale / 2
		local centreX = math.max(safeWidth / 2, cashRight + gap + halfDistance)
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
	end)

	gui.Parent = parent
	self:setState(self._state)
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
end

function RunHud.setState(self: any, state: RunHudState)
	self._state = state
	self._cashText.Text = Format.cash(state.cash)
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
		cashText = self._cashText.Text,
		cashFits = self._cashText.TextFits,
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
