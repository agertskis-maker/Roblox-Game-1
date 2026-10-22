--!strict
-- Run view composition for the HUD prototype (Lane 3 preview, worker H3). Presentation only: it
-- displays the run state the preview adapter writes to the store (store.run, store.cash) and
-- decides nothing (no landing, target, capture, ownership or reward).
--
-- DEFAULT = the approved run HUD (revision 4, Adam 2026-10-20): Cash top left, Distance top
-- centre (option B), Heat bottom centre (ENGINE HEAT panel). RunHud.new builds its own ScreenGui
-- and lays itself out against the real viewport, so it cannot live inside the prototype's
-- virtual device layer. Instead this module reuses the approved pieces directly and unedited:
-- CurrencyCounter + CashIcon (Cash, the same options RunHud passes), RunHud.buildDistancePreview
-- (Distance B) and HeatGauge (the panel), and ports RunHud's top-row rule (below) into design px.
-- Added here: coins as a secondary readout under Distance, and the PROPOSAL Heat variant.
--
--   local run = RunLayer.new(ctx)
--   run:setHeatVariant("Approved" | "Proposal")   -- Proposal: segmented Heat bar top left,
--                                                  -- replacing Cash, with the warm edge tint
--   run:setDiagnostics(on)   -- shows the "PROPOSAL" tag and the reserved LANDING VIEW outline
--   run:jolt(strength?)      -- the approved presentation-only bump (Approved variant only)
--   run:layout(), run:setVisible(on), run:destroy(), run:getDebugState()
--
-- Top-row rule (RunHud's, in design px), extended for the options gear: Distance is centred; if
-- the widest Cash at its biggest punch would come within 12 px of the flag the punch is lowered;
-- below 0.06 punch Distance moves right (never into the gear column); if even no punch fits,
-- Distance takes its own row under Cash at the right edge. Text never shrinks. With the
-- Proposal bar the same rule uses the bar's width instead of Cash.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextService = game:GetService("TextService")

local CashIcon = require(script.Parent.Parent.Parent.CurrencyCounter.CashIcon)
local CurrencyCounter = require(script.Parent.Parent.Parent.CurrencyCounter)
local Format = require(ReplicatedStorage.Shared.UI.Format)
local Gloss = require(script.Parent.Parent.Gloss)
local HeatBarProposal = require(script.Parent.HeatBarProposal)
local HeatGauge = require(script.Parent.Parent.Parent.RunHud.HeatGauge)
local Icons = require(script.Parent.Parent.Icons)
local Motion = require(script.Parent.Parent.Motion)
local OutlinedText = require(script.Parent.Parent.Parent.OutlinedText)
local PreviewTokens = require(script.Parent.Parent.PreviewTokens)
local RunHud = require(script.Parent.Parent.Parent.RunHud)
local RunLayout = require(script.Parent.RunLayout)
local Tokens = require(ReplicatedStorage.Shared.UI.Tokens)
local Trove = require(ReplicatedStorage.Packages.Trove)

local C = PreviewTokens.Color
local make = Gloss.make

export type HeatVariant = "Approved" | "Proposal"

-- RunHud's constants (copied, not changed).
local CASH_WIDEST = { "$9,999", "$99.9K", "$999K", "$9.99M", "$99.9M", "$999M", "$999B", "$999T", "$1,000T" }
local TOP_ROW_GAP = 12
local MIN_PUNCH = 0.06
-- Coins (secondary): approved Value size, coin icon, white-to-gold outlined number.
local COIN_TEXT = Tokens.TextSize.Value
local COIN_ICON = 26
local COIN_ROW = 30

local RunLayer = {}
RunLayer.__index = RunLayer

local function nonInteractive(g: GuiObject)
	g.Active = false
	pcall(function()
		(g :: any).Interactable = false
	end)
end

local function textWidth(text: string, size: number): number
	return TextService:GetTextSize(text, size, Enum.Font.FredokaOne, Vector2.new(4096, 4096)).X
end

function RunLayer.new(ctx: RunLayout.Ctx)
	local self = setmetatable({}, RunLayer)
	self._ctx = ctx
	self._trove = Trove.new()
	self._variant = "Approved" :: HeatVariant
	self._diagnostics = false
	self._visible = true
	self._gaugeMounted = false
	self._coinsText = "" -- empty so the first update always writes the text
	self._conflict = 0
	self._punch = 0
	self._row = 1
	self._maxGrowth = 1
	self._top = nil :: RunLayout.Top?

	local root = self._trove:Add(RunLayout.canvas(ctx, "RunLayer"))
	self.root = root

	-- Edge tint sits under everything else.
	local edgeHolder = make("Frame", {
		Name = "EdgeHolder",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 0,
		Parent = root,
	})
	nonInteractive(edgeHolder)

	-- Cash (approved): the same component and options as RunHud.
	local counter = CurrencyCounter.new(root, {
		name = "Cash",
		palette = Tokens.Color,
		buildIcon = CashIcon.build,
		iconSize = CashIcon.Size,
		iconArtSize = CashIcon.ArtSize,
		format = Format.cash,
		widestSamples = CASH_WIDEST,
		reducedMotion = Motion.reduced(),
	})
	self._counter = counter
	self._trove:Add(function()
		counter:destroy()
	end)

	-- Distance (approved option B).
	local distance = RunHud.buildDistancePreview(root, Tokens.Color, 0)
	self._distance = distance
	self._trove:Add(distance.root)

	-- Coins, secondary, under Distance.
	local coins = make("Frame", {
		Name = "Coins",
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(120, COIN_ROW),
		Parent = root,
	})
	nonInteractive(coins)
	local coinIcon = make("Frame", {
		Name = "CoinIcon",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.fromScale(0, 0.5),
		Size = UDim2.fromOffset(COIN_ICON, COIN_ICON),
		BackgroundTransparency = 1,
		ZIndex = 3,
		Parent = coins,
	})
	Icons.draw(coinIcon, "Coin", Tokens.Color.Coin)
	local coinValue = make("Frame", {
		Name = "Value",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, COIN_ICON + 6, 0.5, 0),
		Size = UDim2.fromOffset(100, COIN_TEXT + 2 * OutlinedText.Outline),
		BackgroundTransparency = 1,
		Parent = coins,
	})
	self._coinText =
		OutlinedText.build(coinValue, "Text", COIN_TEXT, Tokens.Color.FloatText, Tokens.Color.Coin, Tokens.Color, 2)
	self._coins = coins
	self._coinValue = coinValue

	-- Heat (approved panel).
	local gauge = HeatGauge.new(root, Tokens.Color, Motion.reduced())
	nonInteractive(gauge.Root)
	self._gauge = gauge
	self._trove:Add(function()
		gauge:destroy()
	end)

	-- Heat (PROPOSAL variant), hidden by default.
	local bar = HeatBarProposal.new(root, edgeHolder)
	self._bar = bar
	self._trove:Add(function()
		bar:destroy()
	end)
	local tag = make("TextLabel", {
		Name = "ProposalTag",
		BackgroundColor3 = C.Ink,
		BackgroundTransparency = 0.1,
		Size = UDim2.fromOffset(96, 22),
		FontFace = Tokens.font(),
		Text = "PROPOSAL",
		TextSize = 16,
		TextColor3 = C.TutorialLight,
		ZIndex = 20,
		Visible = false,
		Parent = root,
	})
	Gloss.corner(tag, 6)
	self._tag = tag

	-- Diagnostics: the reserved landing view.
	local band = make("Frame", {
		Name = "LandingViewDiagnostic",
		BackgroundColor3 = C.HopLight,
		BackgroundTransparency = 0.9,
		ZIndex = 30,
		Visible = false,
		Parent = root,
	})
	nonInteractive(band)
	local bandStroke = Gloss.stroke(band, 2, C.HopLight)
	bandStroke.Transparency = 0.2
	local bandLabel = make("TextLabel", {
		Name = "Label",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 20),
		FontFace = Tokens.font(),
		Text = "LANDING VIEW (kept clear)",
		TextSize = 16,
		TextColor3 = C.White,
		ZIndex = 31,
		Parent = band,
	})
	Gloss.stroke(bandLabel, 2, C.Ink, Enum.ApplyStrokeMode.Contextual)
	self._band = band

	self._trove:Add(ctx.store:subscribe("run", function()
		self:_apply()
	end))
	self._trove:Add(ctx.store:subscribe("cash", function(value: number)
		counter:setValue(value)
	end))
	self._trove:Add(Motion.onReducedChanged(function(reduced: boolean)
		gauge:setReducedMotion(reduced)
		counter:setReducedMotion(reduced)
		bar:onReducedChanged(reduced)
	end))

	counter:setValue(ctx.store:get().cash, true)
	gauge:snap(0, nil)
	self:_applyVariant()
	self:layout()
	self:_apply()
	return self
end

export type RunLayer = typeof(RunLayer.new((nil :: any) :: RunLayout.Ctx))

function RunLayer._apply(self: RunLayer)
	local run = self._ctx.store:get().run
	local distance = if run then run.distance else 0
	local coins = if run then run.coins else 0
	local heat = if run then run.heat else 0
	local stage = if run then run.stage else nil
	self._distance.set(distance)
	local text = Format.group(math.max(0, math.floor(coins)))
	if text ~= self._coinsText then
		self._coinsText = text
		OutlinedText.setText(self._coinText, text)
		self:_sizeCoins()
	end
	-- Only the visible variant is driven, so a hidden ENGINE HEAT panel runs no alarm effects.
	if self._variant == "Approved" then
		if self._gaugeMounted then
			self._gauge:set(heat, stage)
		else
			-- first supplied state: shown as it is (RunHud's mount rule)
			self._gaugeMounted = run ~= nil
			self._gauge:snap(heat, stage)
		end
	else
		self._bar:set(heat, stage)
	end
end

function RunLayer._sizeCoins(self: RunLayer)
	local w = math.ceil(textWidth(self._coinsText, COIN_TEXT) + 2 * OutlinedText.Outline)
	self._coinValue.Size = UDim2.fromOffset(w, COIN_TEXT + 2 * OutlinedText.Outline)
	self._coins.Size = UDim2.fromOffset(COIN_ICON + 6 + w, COIN_ROW)
end

function RunLayer._applyVariant(self: RunLayer)
	local proposal = self._variant == "Proposal"
	self._counter.Root.Visible = self._visible and not proposal
	self._gauge.Root.Visible = self._visible and not proposal
	self._bar:setVisible(self._visible and proposal)
	self._tag.Visible = self._visible and proposal and self._diagnostics
	self._band.Visible = self._visible and self._diagnostics
end

function RunLayer.layout(self: RunLayer)
	local ctx = self._ctx
	RunLayout.fit(ctx, self.root)
	local d = RunLayout.design(ctx)
	local m = RunLayout.Margin
	local proposal = self._variant == "Proposal"
	local counter = self._counter
	local distance = self._distance

	counter.Root.Position = UDim2.fromOffset(m, m)
	self._bar.root.Position = UDim2.fromOffset(m, m)
	self._tag.Position = UDim2.fromOffset(m + HeatBarProposal.Size.X - 96, m + HeatBarProposal.Size.Y + 4)

	-- Top row (RunHud's rule in design px, plus the options gear column).
	local gearColumn = RunLayout.Gear + m
	local minGap = TOP_ROW_GAP
	local half = distance.size.X / 2
	local flagInset = distance.artLeft
	local leftRight: number
	local punchFor: (number) -> number
	if proposal then
		leftRight = m + HeatBarProposal.Size.X
		punchFor = function(centre: number): number
			-- no punch with the bar: >= 0 when it fits, negative when it does not
			return ((centre - half + flagInset) - minGap - leftRight) / HeatBarProposal.Size.X
		end
	else
		local valueLeft = m + counter.ValueX
		local ink = counter.WidestInkRight
		leftRight = valueLeft + ink
		punchFor = function(centre: number): number
			return ((centre - half + flagInset) - minGap - valueLeft) / ink - 1
		end
	end
	local centreX = d.X / 2
	local maxCentre = d.X - m - half - gearColumn
	local minPunch = if proposal then 0 else MIN_PUNCH
	if punchFor(centreX) < minPunch then
		local needed = if proposal
			then leftRight + minGap + half - flagInset
			else (m + counter.ValueX) + counter.WidestInkRight * (1 + MIN_PUNCH) + minGap + half - flagInset
		centreX = math.max(centreX, math.min(needed, maxCentre))
	end
	local punch = punchFor(centreX)
	local distanceY = m
	local row = 1
	local leftBottom = m + (counter.RowHeight + OutlinedText.ShadowOffset)
	if proposal then
		leftBottom = m + HeatBarProposal.Size.Y
	end
	if punch < 0 then
		row = 2
		centreX = d.X - m - half
		punch = Tokens.Motion.CashPunchBig
		distanceY = leftBottom + minGap
	end
	if not proposal then
		counter:setMaxPunch(math.clamp(punch, 0, Tokens.Motion.CashPunchBig))
	end
	self._conflict = math.max(0, -punch)
	self._punch = math.clamp(punch, 0, Tokens.Motion.CashPunchBig)
	self._row = row
	distance.root.Position = UDim2.fromOffset(centreX, distanceY)
	local coinsY = distanceY + distance.size.Y + 2
	self._coins.Position = UDim2.fromOffset(centreX, coinsY)

	-- Heat panel (approved): RunHud's bottom rule, in design px.
	local portrait = d.Y > d.X
	self._gauge.Root.Position = UDim2.new(0.5, 0, 1, -RunLayout.heatBottomOffset(ctx))
	local s = ctx.screen:uiScale()
	local fullWidth = (HeatGauge.Size.X + 2 * HeatGauge.EffectMargin) * s
	local maxGrowth = (d.X * s - 2 * RunLayout.SafeMargin) / fullWidth
	self._gauge:setLayout(maxGrowth, if portrait then 0.6 else 1)
	self._maxGrowth = maxGrowth

	local band = RunLayout.landingBand(ctx)
	self._band.Position = UDim2.fromOffset(band.pos.X, band.pos.Y)
	self._band.Size = UDim2.fromOffset(band.size.X, band.size.Y)

	local coinsW = self._coins.Size.X.Offset
	local top: RunLayout.Top = {
		row = row,
		distance = RunLayout.rect(centreX - half, distanceY, distance.size.X, distance.size.Y, "Distance"),
		coins = RunLayout.rect(centreX - coinsW / 2, coinsY, coinsW, COIN_ROW, "Coins"),
		stackBottom = coinsY + COIN_ROW,
		leftBottom = leftBottom,
	}
	self._top = top
	RunLayout.publishTop(ctx.screen, top)
	self:_applyVariant()
end

function RunLayer.setHeatVariant(self: RunLayer, variant: HeatVariant)
	if variant ~= "Approved" and variant ~= "Proposal" then
		return
	end
	if variant == self._variant then
		return
	end
	self._variant = variant
	-- show the current state immediately in the newly visible variant
	local run = self._ctx.store:get().run
	if variant == "Approved" then
		self._gaugeMounted = run ~= nil
		self._gauge:snap(if run then run.heat else 0, if run then run.stage else nil)
	else
		-- park the hidden panel at rest so its alarm, smoke and stripes stop
		self._gaugeMounted = false
		self._gauge:snap(0, "Calm")
		self._bar:snap(if run then run.heat else 0, if run then run.stage else nil)
	end
	self:layout()
end

function RunLayer.setDiagnostics(self: RunLayer, on: boolean)
	self._diagnostics = on
	self:_applyVariant()
end

function RunLayer.jolt(self: RunLayer, strength: number?)
	if self._variant == "Approved" then
		self._gauge:jolt(strength)
	end
end

function RunLayer.setVisible(self: RunLayer, on: boolean)
	self._visible = on
	self.root.Visible = on
	self:_applyVariant()
end

function RunLayer.getDebugState(self: RunLayer): { [string]: any }
	local top = self._top
	return {
		variant = self._variant,
		variantLabel = if self._variant == "Proposal"
			then "PROPOSAL: segmented Heat bar top left (not approved)"
			else "APPROVED: ENGINE HEAT panel bottom centre (revision 4, 2026-10-20)",
		proposalTagVisible = self._tag.Visible,
		diagnostics = self._diagnostics,
		visible = self._visible,
		profile = self._ctx.screen:profile().name,
		uiScale = self._ctx.screen:uiScale(),
		design = RunLayout.design(self._ctx),
		row = self._row,
		cashPunch = self._punch,
		layoutConflict = self._conflict,
		distanceText = self._distance.number.face.Text .. " " .. self._distance.unit.face.Text,
		distanceBox = top and RunLayout.describe(top.distance),
		coinsText = self._coinsText,
		coinsBox = top and RunLayout.describe(top.coins),
		stackBottom = top and top.stackBottom,
		landingView = RunLayout.describe(RunLayout.landingBand(self._ctx)),
		heatPanel = RunLayout.describe(RunLayout.heatPanelRect(self._ctx)),
		maxGrowth = self._maxGrowth,
		cash = self._counter:getDebugState(),
		gauge = self._gauge:getDebugState(),
		proposal = self._bar:getDebugState(),
	}
end

function RunLayer.destroy(self: RunLayer)
	self._trove:Destroy()
end

return RunLayer
