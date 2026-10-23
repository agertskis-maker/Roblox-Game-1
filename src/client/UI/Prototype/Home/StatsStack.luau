--!strict
-- Home HUD: bottom-left Cash (Lane 3 preview; Round 2 2026-10-23; ledger R2-C1, R2-HM1, H-07..H-10).
-- Presentation only: it shows the values the store supplies and never changes, saves or decides an
-- amount.
--
--   Cash       the approved CurrencyCounter via Home/CashLine in embedded mode (gain choreography,
--              timing, sound hooks and reduced-motion path unchanged; see the regression checklist in
--              CashLine.luau). The counter icon stays fixed while digits grow rightward. Full exact value
--              on tap / hover / gamepad focus (CashLine).
--   Earning    a smaller white slightly italic line "Speedway: +$120 / lap" from store.earningPerLap, a
--              FIXTURE rate (Lane 2 owns the real units and wording); a PREVIEW caption beside it carries
--              the PreviewCaption attribute. It ducks while the counter's own "+$N" label uses the same
--              slot. Hidden when the rate is nil and while the block is compact.
--
-- Round 2: the cyan car icon, its inert "+" and the owned count are GONE (the count is now a pill on the
-- Garage button). The run-time block is Cash alone, compact, at the top-left of the safe area below
-- the core UI inset (Layout.RunCashPos); Home keeps it bottom-left (Layout.forProfile).
--
-- Number format (ledger H-10): Cash uses the approved Format.cash (whole dollars with commas below
-- $10,000, then three significant digits with K/M/B/T, TRUNCATED so a value just under a boundary stays
-- in the lower suffix; promotion happens exactly at the boundary; from 1,000T whole trillions with
-- commas).
--
-- API: StatsStack.new(ctx, Options?) -> StatsStack
--   :layout()  :setVisible(on)  :destroy()  :getDebugState()
--   :setCompact(on)                 -- run mode: Cash only, compact, top-left
--   :useApprovedCashIcon(on)        -- rebuilds the Cash line with the approved CashIcon (for a
--                                      like-for-like regression recording); snaps the value
--   :showExact()                    -- the Cash exact-value detail (test hook)
--   :getCash() -> CashLine          -- the embedded Cash line (scenarios call :gain/:spend)

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Arcade = require(script.Parent.Parent.Arcade)
local CashLine = require(script.Parent.CashLine)
local Fade = require(script.Parent.Fade)
local Format = require(ReplicatedStorage.Shared.UI.Format)
local IconArt = require(script.Parent.IconArt)
local Layout = require(script.Parent.Layout)
local Motion = require(script.Parent.Parent.Motion)
local Store = require(script.Parent.Parent.Store)
local Tokens = require(ReplicatedStorage.Shared.UI.Tokens)
local Trove = require(ReplicatedStorage.Packages.Trove)
local Types = require(script.Parent.Types)

-- TOKEN CANDIDATE: earning-line icon box.
local EARNING_ICON = 22

export type Options = {
	approvedCashIcon: boolean?, -- start with the approved CashIcon instead of the CashStack art
	earningSource: string?, -- FIXTURE label before the rate, default "Speedway"
}

export type StatsStack = {
	root: Frame,
	layout: (self: StatsStack) -> (),
	setVisible: (self: StatsStack, on: boolean) -> (),
	destroy: (self: StatsStack) -> (),
	setCompact: (self: StatsStack, on: boolean) -> (),
	useApprovedCashIcon: (self: StatsStack, on: boolean) -> (),
	showExact: (self: StatsStack) -> (),
	getCash: (self: StatsStack) -> any,
	getDebugState: (self: StatsStack) -> { [string]: any },
}

local StatsStack = {}
StatsStack.__index = StatsStack

function StatsStack.new(ctx: Types.Ctx, options: Options?): StatsStack
	local self = setmetatable({}, StatsStack) :: any
	local trove = Trove.new()
	self._trove = trove
	self._ctx = ctx
	self._opts = options or {}
	self._destroyed = false
	self._compact = false
	self._approvedIcon = self._opts.approvedCashIcon == true
	self._duckToken = 0
	local m = Layout.cashMetrics()
	self._m = m
	local height = Layout.statsHeight()
	local width = m.reservedWidth

	local root = trove:Add(Arcade.make("Frame", {
		Name = "StatsStack",
		AnchorPoint = Vector2.new(0, 0),
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(width, height),
		ZIndex = 4,
		Parent = ctx.layer,
	}))
	self.root = root
	self._scale = Arcade.make("UIScale", { Name = "HudScale", Scale = ctx.screen:uiScale(), Parent = root })

	-- Content shrinks toward the top-left corner in compact (run) mode.
	local content = Arcade.make("Frame", {
		Name = "Content",
		AnchorPoint = Vector2.new(0, 0),
		Position = UDim2.fromScale(0, 0),
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = 4,
		Parent = root,
	})
	self._content = content
	self._compactScale = Arcade.make("UIScale", { Name = "Compact", Scale = 1, Parent = content })

	-- Top row: the Cash line holder.
	local cashHolder = Arcade.make("Frame", {
		Name = "CashRow",
		Position = UDim2.fromOffset(0, 0),
		Size = UDim2.fromOffset(width, m.rowHeight),
		BackgroundTransparency = 1,
		ZIndex = 4,
		Parent = content,
	})
	self._cashHolder = cashHolder
	self._cashTrove = trove:Extend()
	self:_buildCash()

	-- Bottom row: the earning line (FIXTURE rate) in the counter's label slot.
	local earning = Arcade.make("Frame", {
		Name = "Earning",
		Position = UDim2.fromOffset(m.artLeft, m.rowHeight + 2),
		Size = UDim2.fromOffset(width, Layout.EarningHeight),
		BackgroundTransparency = 1,
		ZIndex = 3,
		Parent = content,
	})
	Arcade.make("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 4),
		Parent = earning,
	})
	local earningIcon = Arcade.make("Frame", {
		Name = "Icon",
		LayoutOrder = 1,
		Size = UDim2.fromOffset(EARNING_ICON, EARNING_ICON),
		BackgroundTransparency = 1,
		ZIndex = 4,
		Parent = earning,
	})
	IconArt.draw(earningIcon, { "Track" })
	local earningText = Arcade.text(earning, {
		text = "",
		role = "Earning",
		name = "Rate",
		italic = true,
		xAlign = Enum.TextXAlignment.Left,
		autoWidth = true,
		z = 5,
	})
	earningText.LayoutOrder = 2
	-- harness-only caption (the playground shows PreviewCaption objects only for annotated
	-- review captures)
	local caption = Arcade.text(earning, {
		text = "PREVIEW rate (Lane 2 owns units)",
		role = "Small",
		name = "PreviewCaption",
		colour = Color3.fromRGB(255, 236, 140),
		xAlign = Enum.TextXAlignment.Left,
		autoWidth = true,
		z = 5,
	})
	caption:SetAttribute("PreviewCaption", true)
	caption.LayoutOrder = 3
	caption.Visible = false
	self._earning = earning
	self._earningText = earningText
	self._caption = caption
	self._earningFade = Fade.capture(earning)
	trove:Add(function()
		self._earningFade:destroy()
	end)

	trove:Add(ctx.store:subscribe("earningPerLap", function(rate: number?)
		self:_setEarning(rate)
	end))
	trove:Connect(ctx.screen.Changed, function()
		self:layout()
	end)

	local state: Store.State = ctx.store:get()
	self:_setEarning(state.earningPerLap)
	self:layout()
	return self :: StatsStack
end

function StatsStack._buildCash(self: any)
	self._cashTrove:Clean()
	local cash = CashLine.new(self._ctx, {
		parent = self._cashHolder,
		approvedIcon = self._approvedIcon,
		showEarning = false,
		onGainShown = function()
			self:_duck()
		end,
	})
	self._cashTrove:Add(function()
		cash:destroy()
	end)
	cash.root.Position = UDim2.fromOffset(0, 0)
	self._cash = cash
end

function StatsStack._setEarning(self: any, rate: number?)
	if rate == nil then
		self._earning.Visible = false
		return
	end
	self._earning.Visible = not self._compact
	local source = self._opts.earningSource or "Speedway"
	self._earningText.Text = string.format("%s: +%s / lap", source, Format.cash(rate))
end

-- The counter's "+$N" label uses the earning line's slot: fade the line out for that time.
function StatsStack._duck(self: any)
	if not self._earning.Visible or Motion.reduced() then
		return
	end
	self._duckToken += 1
	local token = self._duckToken
	self._earningFade:tween(1, 0.1)
	task.delay(Tokens.Motion.CashGainLabelSeconds + 0.1, function()
		if self._destroyed or token ~= self._duckToken then
			return
		end
		self._earningFade:tween(0, 0.2)
	end)
end

function StatsStack.layout(self: any)
	local ctx: Types.Ctx = self._ctx
	local scale = ctx.screen:uiScale()
	self._scale.Scale = scale
	local L = Layout.forProfile(ctx.screen:profile(), scale)
	-- layer px. Run: Cash alone, compact, top-left below the core UI inset. Home: bottom-left (Layout).
	if self._compact then
		self.root.Position = UDim2.fromOffset(Layout.RunCashPos.X * scale, Layout.RunCashPos.Y * scale)
		self._placement = "RunTopLeft"
	else
		self.root.Position = UDim2.fromOffset(L.stats.x * scale, (L.stats.bottom - L.stats.height) * scale)
		self._placement = L.stats.placement
	end
	if self._cash then
		self._cash:layout()
	end
end

function StatsStack.setCompact(self: any, on: boolean)
	self._compact = on
	self._compactScale.Scale = if on then Layout.runCashScale() else 1
	self:_setEarning(self._ctx.store:get().earningPerLap)
	self:layout()
end

function StatsStack.useApprovedCashIcon(self: any, on: boolean)
	if self._approvedIcon == on then
		return
	end
	self._approvedIcon = on
	self:_buildCash()
	self._cash:setVisible(self.root.Visible)
end

function StatsStack.showExact(self: any)
	self._cash:showExact()
end

function StatsStack.getCash(self: any): any
	return self._cash
end

function StatsStack.setVisible(self: any, on: boolean)
	self.root.Visible = on
	if self._cash then
		self._cash:setVisible(on)
	end
	if not on then
		self._duckToken += 1
		self._earningFade:set(0)
	end
end

function StatsStack.getDebugState(self: any): { [string]: any }
	local ctx: Types.Ctx = self._ctx
	local pos, size = ctx.screen:rectOf(self._content)
	local instances = 0
	for _ in self.root:GetDescendants() do
		instances += 1
	end
	return {
		visible = self.root.Visible,
		compact = self._compact,
		placement = self._placement,
		scale = self._scale.Scale,
		earningVisible = self._earning.Visible,
		earningText = self._earningText.Text,
		earningFade = self._earningFade.value,
		devicePos = pos,
		deviceSize = size,
		reservedOverlap = ctx.screen:overlapsReserved(pos, size),
		instances = instances,
		cash = self._cash:getDebugState(),
	}
end

function StatsStack.destroy(self: any)
	if self._destroyed then
		return
	end
	self._destroyed = true
	self._trove:Destroy()
end

return StatsStack
