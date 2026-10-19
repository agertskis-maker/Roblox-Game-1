--!strict
-- DEVELOPMENT PREVIEW ONLY (Lane 3). Not part of the game.
--
-- Shows the run HUD with mock data so its states can be reviewed in Studio.
-- Nothing runs unless someone calls start() during a Studio playtest; outside
-- Studio every entry point returns without doing anything. No remotes, no
-- saving, no balance or gameplay changes. Every number is sample data; the
-- stage here is chosen by this fixture, standing in for Lane 1.
--
-- Start it from the Studio command bar (or MCP) during a playtest, client side:
--   require(game.Players.LocalPlayer.PlayerScripts.Client.UI.Preview.RunHudPreview).start()
--
-- Grey check: the HUD is rebuilt from a grey palette (each colour replaced by
-- the grey of the same brightness) and a temporary ColorCorrectionEffect named
-- Lane3_PreviewGrey desaturates the 3D view. Both are removed by setGrey(false)
-- and stop(). Roblox post-processing does not affect ScreenGuis, which is why
-- the HUD needs its own grey palette.

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local AlarmClock = require(script.Parent.Parent.AlarmClock)
local HeatGauge = require(script.Parent.Parent.RunHud.HeatGauge)
local RunHud = require(script.Parent.Parent.RunHud)
local Tokens = require(ReplicatedStorage.Shared.UI.Tokens)
local Trove = require(ReplicatedStorage.Packages.Trove)

type HeatStage = RunHud.HeatStage
type MotionMode = "Follow" | "Reduced" | "Full"

local HUD_NAME = "Lane3_RunHudPreview"
local CONTROLS_NAME = "Lane3_HudPreviewControls"
local GREY_EFFECT_NAME = "Lane3_PreviewGrey"
local SIMULATED_BUMP_HEAT = 0.15 -- preview only; real bump values belong to Lane 1

local VALUE_SETS: { { name: string, cash: number, distance: number } } = {
	{ name = "Short", cash = 0, distance = 0 },
	{ name = "Typical", cash = 12480, distance = 1240 },
	{ name = "Long", cash = 999999, distance = 9999 },
	{ name = "Compact", cash = 1999999999, distance = 123456 },
}

local STAGE_HEAT: { [string]: number } = {
	Calm = 0.3,
	Warning = 0.72,
	Critical = 0.95,
	Meltdown = 1,
}

local RunHudPreview = {}

type Session = {
	trove: any,
	driverTrove: any,
	hud: any,
	controls: ScreenGui?,
	status: TextLabel?,
	valueIndex: number,
	heat: number,
	meltdown: boolean,
	motion: MotionMode,
	grey: boolean,
	driver: string?,
	note: string,
	inputLog: { string }?,
}

local session: Session? = nil

local function allowed(): boolean
	if not RunService:IsStudio() then
		return false
	end
	if not RunService:IsRunning() or Players.LocalPlayer == nil then
		warn("[Lane3 preview] start a playtest first, then call start() on the client")
		return false
	end
	return true
end

local function playerGui(): PlayerGui
	return (Players.LocalPlayer :: Player):WaitForChild("PlayerGui") :: PlayerGui
end

-- Removes any preview left behind, including one made by another copy of
-- this module (MCP or the command bar can require a fresh copy).
local function removeLeftovers()
	local gui = playerGui()
	for _, child in gui:GetChildren() do
		if child.Name == HUD_NAME or child.Name == CONTROLS_NAME then
			child:Destroy()
		end
	end
	local effect = Lighting:FindFirstChild(GREY_EFFECT_NAME)
	if effect then
		effect:Destroy()
	end
end

local function overrideFor(mode: MotionMode): boolean?
	if mode == "Reduced" then
		return true
	elseif mode == "Full" then
		return false
	end
	return nil
end

-- The mock "gameplay" stage: Meltdown only when this fixture says so;
-- otherwise derived from heat with the provisional thresholds.
local function mockStage(s: Session): HeatStage
	if s.meltdown then
		return "Meltdown"
	end
	return HeatGauge.stageFor(s.heat)
end

local function render(s: Session)
	local values = VALUE_SETS[s.valueIndex]
	s.hud:setState({
		cash = values.cash,
		distance = values.distance,
		heat = if s.meltdown then 1 else s.heat,
		stage = mockStage(s),
	})
	if s.status then
		s.status.Text = string.format(
			"%s | heat %d%% | %s values | motion %s%s%s",
			mockStage(s),
			math.floor((if s.meltdown then 1 else s.heat) * 100 + 0.5),
			values.name,
			s.motion,
			if s.grey then " | grey" else "",
			if s.note ~= "" then " | " .. s.note else ""
		)
	end
end

local function buildHud(s: Session)
	if s.hud then
		s.hud:destroy()
	end
	s.hud = RunHud.new(playerGui(), {
		name = HUD_NAME,
		palette = if s.grey then Tokens.greyPalette() else nil,
		reducedMotionOverride = overrideFor(s.motion),
	})
end

local function stopDriver(s: Session)
	s.driverTrove:Clean()
	s.driver = nil
end

local function buildControls(s: Session)
	local gui = Instance.new("ScreenGui")
	gui.Name = CONTROLS_NAME
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 100
	gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets

	-- Deliberately unlike the HUD: dark panel, yellow "DEV PREVIEW" header.
	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.AnchorPoint = Vector2.new(1, 0.5)
	panel.Position = UDim2.new(1, -8, 0.5, 0)
	panel.Size = UDim2.fromOffset(312, 0)
	panel.AutomaticSize = Enum.AutomaticSize.Y
	panel.BackgroundColor3 = Color3.fromRGB(20, 22, 30)
	panel.BackgroundTransparency = 0.08
	panel.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = panel
	local outline = Instance.new("UIStroke")
	outline.Color = Color3.fromRGB(255, 221, 0)
	outline.Thickness = 2
	outline.Parent = panel
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 6)
	padding.PaddingBottom = UDim.new(0, 6)
	padding.PaddingLeft = UDim.new(0, 6)
	padding.PaddingRight = UDim.new(0, 6)
	padding.Parent = panel
	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 4)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = panel

	local header = Instance.new("TextLabel")
	header.Name = "Header"
	header.LayoutOrder = 1
	header.Size = UDim2.new(1, 0, 0, 18)
	header.BackgroundTransparency = 1
	header.Font = Enum.Font.Code
	header.TextSize = 14
	header.TextColor3 = Color3.fromRGB(255, 221, 0)
	header.TextXAlignment = Enum.TextXAlignment.Left
	header.Text = "DEV PREVIEW - mock data, not the HUD"
	header.Parent = panel

	local status = Instance.new("TextLabel")
	status.Name = "Status"
	status.LayoutOrder = 2
	status.Size = UDim2.new(1, 0, 0, 32)
	status.BackgroundTransparency = 1
	status.Font = Enum.Font.Code
	status.TextSize = 12
	status.TextWrapped = true
	status.TextColor3 = Color3.fromRGB(220, 224, 235)
	status.TextXAlignment = Enum.TextXAlignment.Left
	status.Parent = panel
	s.status = status

	local grid = Instance.new("Frame")
	grid.Name = "Buttons"
	grid.LayoutOrder = 3
	grid.Size = UDim2.fromScale(1, 0)
	grid.AutomaticSize = Enum.AutomaticSize.Y
	grid.BackgroundTransparency = 1
	grid.Parent = panel
	local gridLayout = Instance.new("UIGridLayout")
	gridLayout.CellSize = UDim2.fromOffset(96, Tokens.Touch.Minimum)
	gridLayout.CellPadding = UDim2.fromOffset(4, 4)
	gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
	gridLayout.Parent = grid

	local order = 0
	local function button(label: string, action: () -> ())
		order += 1
		local b = Instance.new("TextButton")
		b.Name = label
		b.LayoutOrder = order
		b.BackgroundColor3 = Color3.fromRGB(52, 56, 72)
		b.Font = Enum.Font.Code
		b.TextSize = 13
		b.TextWrapped = true
		b.TextColor3 = Color3.new(1, 1, 1)
		b.Text = label
		b.AutoButtonColor = true
		b.Parent = grid
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0, 4)
		c.Parent = b
		s.trove:Connect(b.Activated, action)
	end

	for _, stage in { "Calm", "Warning", "Critical", "Meltdown" } do
		button(stage, function()
			RunHudPreview.setStage(stage :: HeatStage)
		end)
	end
	button("Heat -", function()
		RunHudPreview.scrubHeat(-0.05)
	end)
	button("Heat +", function()
		RunHudPreview.scrubHeat(0.05)
	end)
	button("Sweep 0-100%", function()
		RunHudPreview.sweep(8)
	end)
	button("Simulate bump", function()
		RunHudPreview.simulateBump(false)
	end)
	button("Sim. bump +15% heat", function()
		RunHudPreview.simulateBump(true)
	end)
	button("Mock Hop", function()
		RunHudPreview.mockHop()
	end)
	button("Values", function()
		RunHudPreview.cycleValues()
	end)
	button("Motion", function()
		RunHudPreview.cycleMotion()
	end)
	button("Grey", function()
		RunHudPreview.setGrey(not (session :: Session).grey)
	end)
	button("Hide panel", function()
		RunHudPreview.showControls(false)
	end)
	button("Close", function()
		RunHudPreview.stop()
	end)

	-- Small tab to bring the panel back after hiding it.
	local tab = Instance.new("TextButton")
	tab.Name = "ShowTab"
	tab.AnchorPoint = Vector2.new(1, 0.5)
	tab.Position = UDim2.new(1, -8, 0.5, 0)
	tab.Size = UDim2.fromOffset(Tokens.Touch.Minimum, Tokens.Touch.Minimum)
	tab.BackgroundColor3 = Color3.fromRGB(20, 22, 30)
	tab.Font = Enum.Font.Code
	tab.TextSize = 12
	tab.TextColor3 = Color3.fromRGB(255, 221, 0)
	tab.Text = "DEV"
	tab.Visible = false
	tab.Parent = gui
	s.trove:Connect(tab.Activated, function()
		RunHudPreview.showControls(true)
	end)

	gui.Parent = playerGui()
	s.controls = gui
	s.trove:Add(gui)
	-- If anything else destroys the panel (another copy of this module, or a
	-- manual delete), take the whole session down with it.
	s.trove:Connect(gui.Destroying, function()
		if session == s then
			RunHudPreview.stop()
		end
	end)
end

function RunHudPreview.start(): boolean
	if not allowed() then
		return false
	end
	RunHudPreview.stop()
	removeLeftovers()
	local trove = Trove.new()
	local s: Session = {
		trove = trove,
		driverTrove = trove:Extend(),
		hud = nil,
		controls = nil,
		status = nil,
		valueIndex = 2,
		heat = 0,
		meltdown = false,
		motion = "Follow",
		grey = false,
		driver = nil,
		note = "",
		inputLog = nil,
	}
	session = s
	buildHud(s)
	trove:Add(function()
		if s.hud then
			s.hud:destroy()
			s.hud = nil
		end
	end)
	buildControls(s)
	render(s)
	return true
end

function RunHudPreview.stop()
	local s = session
	session = nil
	if s then
		s.trove:Destroy()
	end
	if RunService:IsRunning() and Players.LocalPlayer then
		removeLeftovers()
	end
end

local function active(): Session?
	return session
end

-- Sets an exact mock Heat (0 to 1). Below 1 this leaves Meltdown.
function RunHudPreview.setHeat(heat01: number)
	local s = active()
	if not s then
		return
	end
	stopDriver(s)
	s.meltdown = false
	s.heat = math.clamp(heat01, 0, 0.999)
	s.note = ""
	render(s)
end

function RunHudPreview.setStage(stage: HeatStage)
	local s = active()
	if not s then
		return
	end
	stopDriver(s)
	s.meltdown = stage == "Meltdown"
	s.heat = STAGE_HEAT[stage]
	s.note = ""
	render(s)
end

function RunHudPreview.scrubHeat(delta: number)
	local s = active()
	if not s then
		return
	end
	RunHudPreview.setHeat((if s.meltdown then 1 else s.heat) + delta)
end

-- Mock driver: raises Heat continuously from 0 to 100% over `seconds`, then
-- enters a mock Meltdown and holds it. It ends nothing.
function RunHudPreview.sweep(seconds: number?)
	local s = active()
	if not s then
		return
	end
	stopDriver(s)
	local duration = seconds or 8
	s.meltdown = false
	s.heat = 0
	s.driver = "sweep"
	s.note = "mock sweep"
	s.driverTrove:Connect(RunService.Heartbeat, function(dt: number)
		s.heat = math.min(0.999, s.heat + dt / duration)
		if s.heat >= 0.999 then
			s.meltdown = true
			s.note = "mock Meltdown (no run ends)"
			stopDriver(s)
		end
		render(s)
	end)
	render(s)
end

-- Plays the presentation-only bump reaction. With addHeat, the mock fixture
-- also raises Heat by a labelled, simulated amount; real bump Heat is Lane 1's.
function RunHudPreview.simulateBump(addHeat: boolean)
	local s = active()
	if not s then
		return
	end
	s.hud:jolt(1)
	if addHeat and not s.meltdown then
		s.heat = math.min(0.999, s.heat + SIMULATED_BUMP_HEAT)
		s.note = "simulated bump +15% (preview only)"
	else
		s.note = "simulated bump"
	end
	render(s)
end

-- Mock Hop: Heat resets on every Hop, which also clears Meltdown and every
-- alarm effect.
function RunHudPreview.mockHop()
	local s = active()
	if not s then
		return
	end
	stopDriver(s)
	s.meltdown = false
	s.heat = 0
	s.note = "mock Hop"
	render(s)
end

function RunHudPreview.cycleValues()
	local s = active()
	if not s then
		return
	end
	s.valueIndex = s.valueIndex % #VALUE_SETS + 1
	render(s)
end

function RunHudPreview.setValues(name: string)
	local s = active()
	if not s then
		return
	end
	for i, values in VALUE_SETS do
		if values.name == name then
			s.valueIndex = i
		end
	end
	render(s)
end

function RunHudPreview.cycleMotion()
	local s = active()
	if not s then
		return
	end
	local nextMode: { [string]: MotionMode } = { Follow = "Reduced", Reduced = "Full", Full = "Follow" }
	RunHudPreview.setMotion(nextMode[s.motion])
end

-- "Follow" uses the player's Roblox Reduce Motion setting; "Reduced" and
-- "Full" force a mode for this preview only. Nothing is saved.
function RunHudPreview.setMotion(mode: MotionMode)
	local s = active()
	if not s then
		return
	end
	s.motion = mode
	s.hud:setReducedMotionOverride(overrideFor(mode))
	render(s)
end

function RunHudPreview.setGrey(enabled: boolean)
	local s = active()
	if not s then
		return
	end
	s.grey = enabled
	local effect = Lighting:FindFirstChild(GREY_EFFECT_NAME)
	if enabled and not effect then
		local cc = Instance.new("ColorCorrectionEffect")
		cc.Name = GREY_EFFECT_NAME
		cc.Saturation = -1
		cc.Parent = Lighting
		s.trove:Add(cc)
	elseif not enabled and effect then
		effect:Destroy()
	end
	buildHud(s)
	render(s)
end

function RunHudPreview.showControls(visible: boolean)
	local s = active()
	if not s or not s.controls then
		return
	end
	local panel = s.controls:FindFirstChild("Panel") :: Frame?
	local tab = s.controls:FindFirstChild("ShowTab") :: TextButton?
	if panel then
		panel.Visible = visible
	end
	if tab then
		tab.Visible = not visible
	end
end

-- Starts recording clicks and touches so a reviewer can check that the HUD
-- does not swallow steering input (gameProcessed stays false over HUD art).
function RunHudPreview.probeInput()
	local s = active()
	if not s then
		return
	end
	s.inputLog = {}
	s.trove:Connect(UserInputService.InputBegan, function(input: InputObject, processed: boolean)
		local kind = input.UserInputType
		if kind == Enum.UserInputType.MouseButton1 or kind == Enum.UserInputType.Touch then
			table.insert(
				s.inputLog,
				string.format(
					"%s at (%d,%d) gameProcessed=%s",
					kind.Name,
					input.Position.X,
					input.Position.Y,
					tostring(processed)
				)
			)
		end
	end)
end

-- Read-only summary for review and tests.
function RunHudPreview.debug(): { [string]: any }
	local s = active()
	local gui = if Players.LocalPlayer then playerGui() else nil
	local hudCount, controlsCount = 0, 0
	if gui then
		for _, child in gui:GetChildren() do
			if child.Name == HUD_NAME then
				hudCount += 1
			elseif child.Name == CONTROLS_NAME then
				controlsCount += 1
			end
		end
	end
	return {
		active = s ~= nil,
		hudGuis = hudCount,
		controlGuis = controlsCount,
		greyEffect = Lighting:FindFirstChild(GREY_EFFECT_NAME) ~= nil,
		driver = if s then s.driver else nil,
		inputLog = if s then s.inputLog else nil,
		clock = AlarmClock.stats(),
		hud = if s and s.hud then s.hud:getDebugState() else nil,
	}
end

return RunHudPreview
