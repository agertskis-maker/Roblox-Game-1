--!strict
-- Run view base layer for the rebuilt HUD (Lane 3 preview, HUD rebuild worker HR, 2026-10-22).
-- The overnight top Distance + coins look and the run Heat panel are gone from the prototype run
-- view: distance now lives under the avatar head in DistrictStrip, Heat is HeatBar (bottom
-- centre), Cash and the car count belong bottom left (Home worker's stats, shown compact while
-- driving by the lead's mode wiring). The approved production RunHud is untouched.
--
-- What is left here:
--   * a compact COINS readout (run coins, a fixture value): coin icon + italic number, no card,
--     top left (under the strip on the left in phone portrait). Kept because run.coins exists and
--     Results reports it; options.coins = false hides it.
--   * diagnostics: the PROTECTED ROAD-AHEAD region (RunLayout.protectedRect) drawn as an outline
--     with its label, for review captures only.
--
--   local run = RunLayer.new(ctx, { coins = true? })
--   run:setDiagnostics(on)
--   run:layout(), run:setVisible(on), run:destroy(), run:getDebugState()
--   run:setHeatVariant(...) / run:jolt(...)   -- accepted and ignored (overnight API; the
--                                                proposal variant was retired with the rebuild)

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Arcade = require(script.Parent.Parent.Arcade)
local Format = require(ReplicatedStorage.Shared.UI.Format)
local RunKit = require(script.Parent.RunKit)
local RunLayout = require(script.Parent.RunLayout)
local Trove = require(ReplicatedStorage.Packages.Trove)

local make = Arcade.make

export type Options = { coins: boolean? }

local RunLayer = {}
RunLayer.__index = RunLayer

function RunLayer.new(ctx: RunLayout.Ctx, options: Options?)
	local self = setmetatable({}, RunLayer)
	self._ctx = ctx
	self._trove = Trove.new()
	self._visible = true
	self._diagnostics = false
	self._showCoins = not (options and options.coins == false)
	self._coinsText = ""

	local root = self._trove:Add(RunLayout.canvas(ctx, "RunLayer"))
	self.root = root

	local coins = make("Frame", {
		Name = "Coins",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(RunLayout.CoinsSize.X, RunLayout.CoinsSize.Y),
		ZIndex = 2,
		Parent = root,
	})
	RunKit.nonInteractive(coins)
	local icon = make("Frame", {
		Name = "Icon",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.fromScale(0, 0.5),
		Size = UDim2.fromOffset(30, 30),
		BackgroundTransparency = 1,
		ZIndex = 3,
		Parent = coins,
	})
	Arcade.icon(icon, "Coin")
	local value = Arcade.text(coins, {
		text = "0",
		role = "ValueRun",
		name = "Value",
		italic = true,
		face = "Keys",
		xAlign = Enum.TextXAlignment.Left,
		z = 4,
	})
	value.AnchorPoint = Vector2.new(0, 0.5)
	value.Position = UDim2.new(0, 34, 0.5, 0)
	value.Size = UDim2.new(1, -34, 1, 4)
	self._coins = coins
	self._coinValue = value

	-- diagnostics: the protected road-ahead region
	local band = make("Frame", {
		Name = "ProtectedDiagnostic",
		BackgroundColor3 = Color3.fromRGB(120, 255, 230),
		BackgroundTransparency = 0.9,
		ZIndex = 30,
		Visible = false,
		Parent = root,
	})
	RunKit.nonInteractive(band)
	local stroke = make("UIStroke", { Thickness = 2, Color = Color3.fromRGB(120, 255, 230), Parent = band })
	stroke.Transparency = 0.2
	local label = Arcade.text(band, { text = "PROTECTED ROAD AHEAD (kept clear)", role = "Small", z = 31 })
	label.Size = UDim2.new(1, 0, 0, 22)
	self._band = band

	self._trove:Add(ctx.store:subscribe("run", function()
		self:_apply()
	end))
	self._trove:Connect(ctx.store.ModeChanged, function()
		self:_apply()
	end)
	self:layout()
	return self
end

export type RunLayer = typeof(RunLayer.new((nil :: any) :: RunLayout.Ctx))

function RunLayer._apply(self: RunLayer)
	local run = self._ctx.store:get().run
	local coins = if run then run.coins else 0
	local text = Format.group(math.max(0, math.floor(coins)))
	if text ~= self._coinsText then
		self._coinsText = text
		self._coinValue.Text = text
	end
	self._coins.Visible = self._showCoins and run ~= nil and self._ctx.store:get().mode == "Run"
end

function RunLayer.layout(self: RunLayer)
	local ctx = self._ctx
	RunLayout.fit(ctx, self.root)
	RunLayout.place(self._coins, RunLayout.coinsRect(ctx))
	local prot = RunLayout.protected(ctx)
	RunLayout.place(self._band, prot)
	self._band.Visible = self._diagnostics
	self:_apply()
end

function RunLayer.setDiagnostics(self: RunLayer, on: boolean)
	self._diagnostics = on
	self._band.Visible = on
end

function RunLayer.setHeatVariant(_self: RunLayer, _variant: string) end

function RunLayer.jolt(_self: RunLayer, _strength: number?) end

function RunLayer.setVisible(self: RunLayer, on: boolean)
	self._visible = on
	self.root.Visible = on
end

function RunLayer.getDebugState(self: RunLayer): { [string]: any }
	local ctx = self._ctx
	local profile = ctx.screen:profile()
	return {
		visible = self._visible,
		profile = profile.name,
		uiScale = ctx.screen:uiScale(),
		design = RunLayout.design(ctx),
		coinsText = self._coinsText,
		coinsShown = self._coins.Visible,
		coinsBox = RunLayout.describe(RunLayout.coinsRect(ctx)),
		protectedDesign = RunLayout.describe(RunLayout.protected(ctx)),
		protectedDevice = RunLayout.describe(RunLayout.protectedRect(profile)),
		diagnostics = self._diagnostics,
	}
end

function RunLayer.destroy(self: RunLayer)
	self._trove:Destroy()
end

return RunLayer
