--!strict
-- DEVELOPMENT PREVIEW ONLY (Lane 3). Not part of the game.
--
-- Shows the run HUD with mock data so its states can be reviewed in Studio.
-- Nothing runs unless someone calls start() during a Studio playtest; outside
-- Studio every entry point returns without doing anything. No remotes, no
-- saving, no balance or gameplay changes. Every number is sample data from
-- this fixture; the Heat stage is chosen here, standing in for Lane 1, and
-- the Cash value stands in for Lane 2's server balance.
--
-- Start it from the Studio command bar (or MCP) during a playtest, client side:
--   require(game.Players.LocalPlayer.PlayerScripts.Client.UI.Preview.RunHudPreview).start()
--
-- Grey check: the HUD is rebuilt from a grey palette (each colour replaced by
-- the grey of the same brightness) and a temporary ColorCorrectionEffect named
-- Lane3_PreviewGrey desaturates the 3D view. Both are removed by setGrey(false)
-- and stop(). Roblox post-processing does not affect ScreenGuis, which is why
-- the HUD needs its own grey palette.
--
-- Contrast fixture: setBackdrop("Sky" | "Road" | "White" | nil) puts a plain,
-- labelled colour behind the HUD. It is a test fixture, not the Downtown scene.

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local AlarmClock = require(script.Parent.Parent.AlarmClock)
local CashIcon = require(script.Parent.Parent.CurrencyCounter.CashIcon)
local HeatGauge = require(script.Parent.Parent.RunHud.HeatGauge)
local RunHud = require(script.Parent.Parent.RunHud)
local Tokens = require(ReplicatedStorage.Shared.UI.Tokens)
local Trove = require(ReplicatedStorage.Packages.Trove)

type HeatStage = RunHud.HeatStage
type MotionMode = "Follow" | "Reduced" | "Full"
type DistanceStyle = "Pill" | "Floating"

local HUD_NAME = "Lane3_RunHudPreview"
local CONTROLS_NAME = "Lane3_HudPreviewControls"
local BACKDROP_NAME = "Lane3_PreviewBackdrop"
local CLOSEUP_NAME = "Lane3_PreviewIconCloseup"
local GREY_EFFECT_NAME = "Lane3_PreviewGrey"
local SIMULATED_BUMP_HEAT = 0.15 -- preview only; real bump values belong to Lane 1

local BACKDROPS: { [string]: Color3 } = {
	Sky = Color3.fromRGB(110, 190, 235),
	Road = Color3.fromRGB(98, 93, 89),
	White = Color3.fromRGB(245, 245, 245),
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
	cashTrove: any,
	hud: any,
	controls: ScreenGui?,
	status: TextLabel?,
	cash: number,
	distance: number,
	heat: number,
	meltdown: boolean,
	motion: MotionMode,
	grey: boolean,
	distanceStyle: DistanceStyle,
	backdrop: string?,
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
		if
			child.Name == HUD_NAME
			or child.Name == CONTROLS_NAME
			or child.Name == BACKDROP_NAME
			or child.Name == CLOSEUP_NAME
		then
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
	s.hud:setState({
		cash = s.cash,
		distance = s.distance,
		heat = if s.meltdown then 1 else s.heat,
		stage = mockStage(s),
	})
	if s.status then
		s.status.Text = string.format(
			"%s | heat %d%% | cash %d | dist %s | motion %s%s%s",
			mockStage(s),
			math.floor((if s.meltdown then 1 else s.heat) * 100 + 0.5),
			s.cash,
			if s.distanceStyle == "Floating" then "B (proposal)" else "A",
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
		distanceStyle = s.distanceStyle,
	})
end

local function stopDriver(s: Session)
	s.driverTrove:Clean()
	s.driver = nil
end

local function stopCashDriver(s: Session)
	s.cashTrove:Clean()
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
	panel.Size = UDim2.new(0, 330, 0.9, 0)
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

	local header = Instance.new("TextLabel")
	header.Name = "Header"
	header.Position = UDim2.fromOffset(6, 4)
	header.Size = UDim2.new(1, -12, 0, 18)
	header.BackgroundTransparency = 1
	header.Font = Enum.Font.Code
	header.TextSize = 14
	header.TextColor3 = Color3.fromRGB(255, 221, 0)
	header.TextXAlignment = Enum.TextXAlignment.Left
	header.Text = "DEV PREVIEW - mock data, not the HUD"
	header.Parent = panel

	local status = Instance.new("TextLabel")
	status.Name = "Status"
	status.Position = UDim2.fromOffset(6, 22)
	status.Size = UDim2.new(1, -12, 0, 32)
	status.BackgroundTransparency = 1
	status.Font = Enum.Font.Code
	status.TextSize = 12
	status.TextWrapped = true
	status.TextColor3 = Color3.fromRGB(220, 224, 235)
	status.TextXAlignment = Enum.TextXAlignment.Left
	status.Parent = panel
	s.status = status

	local grid = Instance.new("ScrollingFrame")
	grid.Name = "Buttons"
	grid.Position = UDim2.fromOffset(6, 58)
	grid.Size = UDim2.new(1, -12, 1, -64)
	grid.CanvasSize = UDim2.new()
	grid.AutomaticCanvasSize = Enum.AutomaticSize.Y
	grid.ScrollBarThickness = 6
	grid.BackgroundTransparency = 1
	grid.BorderSizePixel = 0
	grid.Parent = panel
	local gridLayout = Instance.new("UIGridLayout")
	gridLayout.CellSize = UDim2.fromOffset(74, Tokens.Touch.Minimum)
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
		b.TextSize = 12
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
	button("Mock Hop", function()
		RunHudPreview.mockHop()
	end)
	button("Simulate bump", function()
		RunHudPreview.simulateBump(false)
	end)
	button("Sim. bump +15% heat", function()
		RunHudPreview.simulateBump(true)
	end)
	button("Cash +$50", function()
		RunHudPreview.addCash(50)
	end)
	button("Cash +$5,000", function()
		RunHudPreview.addCash(5000)
	end)
	button("Spend $300", function()
		RunHudPreview.addCash(-300)
	end)
	button("Long value", function()
		RunHudPreview.setCash(987654321)
	end)
	button("20 rapid gains", function()
		RunHudPreview.rapidGains(20)
	end)
	button("$9,999 to $12.4K", function()
		RunHudPreview.boundaryDemo()
	end)
	button("Distance A/B", function()
		RunHudPreview.setDistanceStyle(if (session :: Session).distanceStyle == "Pill" then "Floating" else "Pill")
	end)
	button("Backdrop", function()
		local nextBackdrop: { [string]: string } = { None = "Sky", Sky = "Road", Road = "White", White = "None" }
		local current = (session :: Session).backdrop or "None"
		local chosen = nextBackdrop[current]
		RunHudPreview.setBackdrop(if chosen == "None" then nil else chosen)
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
		cashTrove = trove:Extend(),
		hud = nil,
		controls = nil,
		status = nil,
		cash = 12480,
		distance = 1240,
		heat = 0,
		meltdown = false,
		motion = "Follow",
		grey = false,
		distanceStyle = "Pill",
		backdrop = nil,
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

-- Heat ------------------------------------------------------------------

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

-- Cash (mock balance; the counter only displays it) ------------------------

function RunHudPreview.setCash(value: number)
	local s = active()
	if not s then
		return
	end
	stopCashDriver(s)
	s.cash = math.max(0, value)
	render(s)
end

function RunHudPreview.addCash(delta: number)
	local s = active()
	if not s then
		return
	end
	stopCashDriver(s)
	s.cash = math.max(0, s.cash + delta)
	render(s)
end

-- Supplies `count` small gains 0.05 s apart.
function RunHudPreview.rapidGains(count: number?)
	local s = active()
	if not s then
		return
	end
	stopCashDriver(s)
	local remaining = count or 20
	local timer = 0
	s.cashTrove:Connect(RunService.Heartbeat, function(dt: number)
		timer += dt
		while timer >= 0.05 and remaining > 0 do
			timer -= 0.05
			remaining -= 1
			s.cash += 25
			render(s)
		end
		if remaining <= 0 then
			stopCashDriver(s)
		end
	end)
end

-- Shows the $9,999 to $12.4K formatting boundary: sets $9,999, then 0.8 s
-- later supplies $12,400.
function RunHudPreview.boundaryDemo()
	local s = active()
	if not s then
		return
	end
	stopCashDriver(s)
	s.cash = 9999
	render(s)
	local timer = 0
	s.cashTrove:Connect(RunService.Heartbeat, function(dt: number)
		timer += dt
		if timer >= 0.8 then
			s.cash = 12400
			render(s)
			stopCashDriver(s)
		end
	end)
end

-- Layout, fixtures and modes ----------------------------------------------

function RunHudPreview.setValues(cash: number?, distance: number?)
	local s = active()
	if not s then
		return
	end
	if cash then
		s.cash = cash
	end
	if distance then
		s.distance = distance
	end
	render(s)
end

-- Option A "Pill" (default) or option B "Floating" (proposal).
function RunHudPreview.setDistanceStyle(style: DistanceStyle)
	local s = active()
	if not s then
		return
	end
	s.distanceStyle = style
	buildHud(s)
	render(s)
end

function RunHudPreview.setBackdrop(name: string?)
	local s = active()
	if not s then
		return
	end
	local existing = playerGui():FindFirstChild(BACKDROP_NAME)
	if existing then
		existing:Destroy()
	end
	s.backdrop = name
	if name == nil or BACKDROPS[name] == nil then
		s.backdrop = nil
		return
	end
	local gui = Instance.new("ScreenGui")
	gui.Name = BACKDROP_NAME
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = -10
	gui.ResetOnSpawn = false
	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = BACKDROPS[name]
	fill.BorderSizePixel = 0
	fill.Parent = gui
	local label = Instance.new("TextLabel")
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.fromScale(0.5, 0.45)
	label.Size = UDim2.fromOffset(320, 24)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.Code
	label.TextSize = 14
	label.TextColor3 = Color3.fromRGB(30, 30, 30)
	label.Text = "contrast fixture: " .. name .. " (not the Downtown scene)"
	label.Parent = fill
	gui.Parent = playerGui()
	s.trove:Add(gui)
end

-- Shows the Cash icon enlarged three times beside an actual-size copy, on a
-- white card in the middle of the screen, for reviewing the artwork.
function RunHudPreview.showIconCloseup(visible: boolean)
	local s = active()
	if not s then
		return
	end
	local existing = playerGui():FindFirstChild(CLOSEUP_NAME)
	if existing then
		existing:Destroy()
	end
	if not visible then
		return
	end
	local palette = Tokens.Color :: Tokens.Palette
	local gui = Instance.new("ScreenGui")
	gui.Name = CLOSEUP_NAME
	gui.DisplayOrder = 100
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	-- Covers the whole screen so nothing else overlaps the artwork.
	local card = Instance.new("Frame")
	card.Size = UDim2.fromScale(1, 1)
	card.BackgroundColor3 = BACKDROPS.White
	card.BorderSizePixel = 0
	card.Parent = gui
	local big = CashIcon.build(card, palette)
	big.AnchorPoint = Vector2.new(0.5, 0.5)
	big.Position = UDim2.fromScale(0.58, 0.45)
	local scale = Instance.new("UIScale")
	scale.Scale = 3
	scale.Parent = big
	local small = CashIcon.build(card, palette)
	small.AnchorPoint = Vector2.new(0.5, 0.5)
	small.Position = UDim2.fromScale(0.25, 0.45)
	local label = Instance.new("TextLabel")
	label.AnchorPoint = Vector2.new(0.5, 0)
	label.Position = UDim2.new(0.5, 0, 0.45, CashIcon.Size.Y * 1.5 + 16)
	label.Size = UDim2.new(1, 0, 0, 18)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.Code
	label.TextSize = 14
	label.TextColor3 = Color3.fromRGB(30, 30, 30)
	label.Text = "Cash icon: actual size (left), 3x (right) - preview only"
	label.Parent = card
	gui.Parent = playerGui()
	s.trove:Add(gui)
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
	local hudCount, controlsCount, backdropCount = 0, 0, 0
	if gui then
		for _, child in gui:GetChildren() do
			if child.Name == HUD_NAME then
				hudCount += 1
			elseif child.Name == CONTROLS_NAME then
				controlsCount += 1
			elseif child.Name == BACKDROP_NAME then
				backdropCount += 1
			end
		end
	end
	return {
		active = s ~= nil,
		hudGuis = hudCount,
		controlGuis = controlsCount,
		backdrops = backdropCount,
		greyEffect = Lighting:FindFirstChild(GREY_EFFECT_NAME) ~= nil,
		driver = if s then s.driver else nil,
		cash = if s then s.cash else nil,
		inputLog = if s then s.inputLog else nil,
		clock = AlarmClock.stats(),
		hud = if s and s.hud then s.hud:getDebugState() else nil,
	}
end

return RunHudPreview
