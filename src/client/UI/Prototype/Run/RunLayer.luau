--!strict
-- Run view base layer for the rebuilt HUD (Lane 3 preview; Round 2, 2026-10-23).
-- The overnight top Distance + coins look is gone: distance lives in the route line, Heat is the original
-- ENGINE HEAT panel (bottom centre), and Cash is the compact top-left Cash (Home/StatsStack in run mode).
-- Round 2 also removed the separate COINS readout: Cash is the single currency, and road coins are Cash
-- pickups shown as a +$N cue on Cash. The approved production RunHud is untouched.
--
-- What is left here:
--   * diagnostics: the PROTECTED ROAD-AHEAD region (RunLayout.protectedRect) drawn as an outline
--     with its label, for review captures only.
--
--   local run = RunLayer.new(ctx)
--   run:setDiagnostics(on)
--   run:layout(), run:setVisible(on), run:destroy(), run:getDebugState()
--   run:setHeatVariant(...) / run:jolt(...)   -- accepted and ignored (overnight API)

local Arcade = require(script.Parent.Parent.Arcade)
local RunKit = require(script.Parent.RunKit)
local RunLayout = require(script.Parent.RunLayout)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Trove = require(ReplicatedStorage.Packages.Trove)

local make = Arcade.make

local RunLayer = {}
RunLayer.__index = RunLayer

function RunLayer.new(ctx: RunLayout.Ctx)
	local self = setmetatable({}, RunLayer)
	self._ctx = ctx
	self._trove = Trove.new()
	self._visible = true
	self._diagnostics = false

	local root = self._trove:Add(RunLayout.canvas(ctx, "RunLayer"))
	self.root = root

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

	self:layout()
	return self
end

export type RunLayer = typeof(RunLayer.new((nil :: any) :: RunLayout.Ctx))

function RunLayer.layout(self: RunLayer)
	local ctx = self._ctx
	RunLayout.fit(ctx, self.root)
	local prot = RunLayout.protected(ctx)
	RunLayout.place(self._band, prot)
	self._band.Visible = self._diagnostics
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
		cashBox = RunLayout.describe(RunLayout.cashRect(ctx)),
		protectedDesign = RunLayout.describe(RunLayout.protected(ctx)),
		protectedDevice = RunLayout.describe(RunLayout.protectedRect(profile)),
		diagnostics = self._diagnostics,
	}
end

function RunLayer.destroy(self: RunLayer)
	self._trove:Destroy()
end

return RunLayer
