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

local ContextActionService = game:GetService("ContextActionService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TextService = game:GetService("TextService")
local UserInputService = game:GetService("UserInputService")

local AlarmClock = require(script.Parent.Parent.AlarmClock)
local CashIcon = require(script.Parent.Parent.CurrencyCounter.CashIcon)
local CurrencyCounter = require(script.Parent.Parent.CurrencyCounter)
local FlagIcon = require(script.Parent.Parent.RunHud.FlagIcon)
local Format = require(ReplicatedStorage.Shared.UI.Format)
local HeatGauge = require(script.Parent.Parent.RunHud.HeatGauge)
local RunHud = require(script.Parent.Parent.RunHud)
local Tokens = require(ReplicatedStorage.Shared.UI.Tokens)
local Trove = require(ReplicatedStorage.Packages.Trove)

type HeatStage = RunHud.HeatStage
type MotionMode = "Follow" | "Reduced" | "Full"

local HUD_NAME = "Lane3_RunHudPreview"
local CONTROLS_NAME = "Lane3_HudPreviewControls"
local BACKDROP_NAME = "Lane3_PreviewBackdrop"
local CLOSEUP_NAME = "Lane3_PreviewIconCloseup"
local GAP_GUIDE_NAME = "Lane3_PreviewGapGuide"
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
	backdrop: string?,
	driver: string?,
	note: string,
	inputLog: { string }?,
	closeup: any,
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
			or child.Name == GAP_GUIDE_NAME
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
			"%s | heat %d%% | cash %d | dist %d | motion %s%s%s",
			mockStage(s),
			math.floor((if s.meltdown then 1 else s.heat) * 100 + 0.5),
			s.cash,
			s.distance,
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
	button("Long distance", function()
		RunHudPreview.setValues(nil, 9999)
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

-- Optional initial mock state, for checking how the HUD first mounts.
export type StartOptions = {
	stage: HeatStage?,
	heat: number?,
	cash: number?,
	distance: number?,
	motion: MotionMode?,
}

function RunHudPreview.start(initial: StartOptions?): boolean
	if not allowed() then
		return false
	end
	RunHudPreview.stop()
	removeLeftovers()
	local init: StartOptions = initial or {}
	local trove = Trove.new()
	local s: Session = {
		trove = trove,
		driverTrove = trove:Extend(),
		cashTrove = trove:Extend(),
		hud = nil,
		controls = nil,
		status = nil,
		cash = init.cash or 12480,
		distance = init.distance or 1240,
		heat = init.heat or (if init.stage then STAGE_HEAT[init.stage] else 0),
		meltdown = init.stage == "Meltdown",
		motion = init.motion or "Follow",
		grey = false,
		backdrop = nil,
		driver = nil,
		note = "",
		inputLog = nil,
		closeup = nil,
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

-- Thin guide line or crosshair for the enlarged close-up (preview only).
local function guide(
	parent: Instance,
	name: string,
	color: Color3,
	horizontal: boolean,
	at: UDim2,
	z: number,
	overhang: number?
): Frame
	local extra = overhang or 16
	local line = Instance.new("Frame")
	line.Name = name
	line.AnchorPoint = Vector2.new(0.5, 0.5)
	line.Position = at
	line.Size = if horizontal then UDim2.new(1, extra, 0, 1) else UDim2.new(0, 1, 1, extra)
	line.BackgroundColor3 = color
	line.BorderSizePixel = 0
	line.ZIndex = z
	line.Parent = parent
	return line
end

local GUIDE_COLORS = {
	bill = Color3.fromRGB(255, 0, 200), -- magenta: top-bill centre
	band = Color3.fromRGB(0, 170, 255), -- blue: band centre
	container = Color3.fromRGB(255, 120, 0), -- orange: icon holder centre
	art = Color3.fromRGB(0, 160, 60), -- green: visible artwork bounds
	digits = Color3.fromRGB(200, 0, 0), -- red: visible digit midpoint
}

-- Shows the Cash counter and the Distance widget enlarged three times on a
-- white card (preview only), with optional alignment guides:
--   magenta / blue  the top bill's centre line and the band's centre line,
--                   drawn inside the bill so they rotate with it
--   orange          the square icon holder's centre (crosshair) and outline
--   green           the visible artwork bounds computed from the geometry
--   red             the visible digit midpoint (and the icon's centre line)
-- Without guides the same view is used for pixel measurement.
function RunHudPreview.showIconCloseup(visible: boolean, guides: boolean?, cash: number?, magnification: number?)
	local s = active()
	if not s then
		return
	end
	local existing = playerGui():FindFirstChild(CLOSEUP_NAME)
	if existing then
		existing:Destroy()
	end
	s.closeup = nil
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
	card.Name = "Card"
	card.Size = UDim2.fromScale(1, 1)
	card.BackgroundColor3 = BACKDROPS.White
	card.BorderSizePixel = 0
	card.Parent = gui

	-- 3x for review; larger values only for pixel measurement.
	local zoomFactor = magnification or 3
	local zoom = Instance.new("Frame")
	zoom.Name = "Zoom"
	zoom.AnchorPoint = Vector2.new(0.5, 0.5)
	zoom.Position = UDim2.fromScale(0.5, 0.45)
	zoom.Size = UDim2.fromOffset(240, 130)
	zoom.BackgroundTransparency = 1
	zoom.Parent = card
	local scale = Instance.new("UIScale")
	scale.Scale = zoomFactor
	scale.Parent = zoom
	-- Measuring views only: two magenta calibration squares at known screen
	-- positions, so a capture can be mapped back to rendered pixels.
	if magnification and magnification ~= 3 then
		-- Bottom-left and upper-right, away from Roblox's top-bar buttons and
		-- a landscape phone's camera notch.
		for i, spot in { { 0, 24, 1, -24 }, { 1, -24, 0.3, 0 } } do
			local mark = Instance.new("Frame")
			mark.Name = "CalibrationMark" .. i
			mark.AnchorPoint = Vector2.new(0.5, 0.5)
			mark.Position = UDim2.new(spot[1], spot[2], spot[3], spot[4])
			mark.Size = UDim2.fromOffset(8, 8)
			mark.BackgroundColor3 = Color3.fromRGB(255, 0, 255)
			mark.BorderSizePixel = 0
			mark.ZIndex = 30
			mark.Parent = card
		end
	end

	local counter = CurrencyCounter.new(zoom, {
		name = "CashCloseup",
		palette = palette,
		buildIcon = CashIcon.build,
		iconSize = CashIcon.Size,
		iconArtSize = CashIcon.ArtSize,
		format = Format.cash,
		widestSamples = { "$99.9M" },
		initial = cash or 12480,
	})
	counter.Root.Position = UDim2.fromOffset(0, 0)
	s.trove:Add(function()
		counter:destroy()
	end)
	s.closeup = counter
	local distanceRoot = RunHud.buildDistancePreview(zoom, palette, 1240).root
	distanceRoot.AnchorPoint = Vector2.new(0, 0)
	distanceRoot.Position = UDim2.fromOffset(0, 80)

	if guides then
		-- Inside the top bill (rotates with it) and inside the band.
		local holder = counter.Root:FindFirstChild("IconHolder") :: Frame
		local icon = holder:FindFirstChild("CashIcon") :: Frame
		local top = icon:FindFirstChild("BillTop", true) :: Frame
		local band = top:FindFirstChild("Band") :: Frame
		-- The bill line is longer so it shows past both ends of the band line.
		guide(top, "GuideBillCentre", GUIDE_COLORS.bill, false, UDim2.fromScale(0.5, 0.5), 20, 30)
		guide(band, "GuideBandCentre", GUIDE_COLORS.band, false, UDim2.fromScale(0.5, 0.5), 21, 0)
		-- Holder centre and outline.
		for _, root in
			{ icon, (distanceRoot:FindFirstChild("FlagHolder") :: Frame):FindFirstChildOfClass("Frame") :: Frame }
		do
			guide(root, "GuideHolderH", GUIDE_COLORS.container, true, UDim2.fromScale(0.5, 0.5), 20)
			guide(root, "GuideHolderV", GUIDE_COLORS.container, false, UDim2.fromScale(0.5, 0.5), 20)
			local box = Instance.new("UIStroke")
			box.Color = GUIDE_COLORS.container
			box.Thickness = 1
			box.Parent = root
		end
		-- Computed visible artwork bounds (centred in the holder).
		for _, spec in
			{
				{ icon, CashIcon.ArtSize },
				{
					(distanceRoot:FindFirstChild("FlagHolder") :: Frame):FindFirstChildOfClass("Frame") :: Frame,
					FlagIcon.ArtSize,
				},
			}
		do
			local art = Instance.new("Frame")
			art.Name = "GuideArtBounds"
			art.AnchorPoint = Vector2.new(0.5, 0.5)
			art.Position = UDim2.fromScale(0.5, 0.5)
			art.Size = UDim2.fromOffset(spec[2].X, spec[2].Y)
			art.BackgroundTransparency = 1
			art.ZIndex = 20
			art.Parent = spec[1]
			local stroke = Instance.new("UIStroke")
			stroke.Color = GUIDE_COLORS.art
			stroke.Thickness = 1
			stroke.Parent = art
		end
		-- Digit midpoint across each row (the icons' centres sit on it).
		for _, row in { counter.Root, distanceRoot } do
			local value = row:FindFirstChild("Value") :: Frame
			local line = Instance.new("Frame")
			line.Name = "GuideDigitMid"
			line.AnchorPoint = Vector2.new(0, 0.5)
			line.Position = UDim2.new(0, -4, value.AnchorPoint.Y, 0)
			line.Size = UDim2.new(1, 8, 0, 1)
			line.BackgroundColor3 = GUIDE_COLORS.digits
			line.BorderSizePixel = 0
			line.ZIndex = 20
			line.Parent = value
			local iconLine = Instance.new("Frame")
			iconLine.Name = "GuideIconMid"
			iconLine.AnchorPoint = Vector2.new(0, 0.5)
			iconLine.Position = UDim2.new(0, -4, 0.5, 0)
			iconLine.Size = UDim2.new(1, 8, 0, 1)
			iconLine.BackgroundColor3 = GUIDE_COLORS.digits
			iconLine.BorderSizePixel = 0
			iconLine.ZIndex = 20
			iconLine.Parent = (row:FindFirstChild("IconHolder") or row:FindFirstChild("FlagHolder")) :: Frame
		end
	end
	local label = Instance.new("TextLabel")
	label.AnchorPoint = Vector2.new(0.5, 1)
	label.Position = UDim2.new(0.5, 0, 1, -24)
	label.Size = UDim2.new(1, 0, 0, 18)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.Code
	label.TextSize = 14
	label.TextColor3 = Color3.fromRGB(30, 30, 30)
	label.Text = string.format("Cash and Distance enlarged %gx on white - preview only", zoomFactor)
		.. (
			if guides
				then " - guides: magenta bill centre, blue band centre, orange holder, green art bounds, red midpoints"
				else ""
		)
	label.Parent = card
	gui.Parent = playerGui()
	s.trove:Add(gui)
end

-- Holds the top row at its tightest point (preview only): the widest Cash
-- value with the number frozen at the largest punch this screen allows, and
-- the longest Distance. Draws the visible gap between them and labels it in
-- rendered px. Returns the measured gap and the punch used.
function RunHudPreview.showTopRowGap(cash: number?, distance: number?): (number?, number?)
	local s = active()
	if not s or not s.hud then
		return nil, nil
	end
	stopCashDriver(s)
	local existing = playerGui():FindFirstChild(GAP_GUIDE_NAME)
	if existing then
		existing:Destroy()
	end
	s.cash = cash or 1e15
	s.distance = distance or 9999
	render(s)
	local hud = s.hud
	local counter = hud._counter
	counter:setValue(s.cash, true)
	local gui = hud.Gui :: ScreenGui
	local cashRoot = gui:FindFirstChild("Cash") :: Frame
	local value = cashRoot:FindFirstChild("Value") :: Frame
	local punchScale = value:FindFirstChild("Punch") :: UIScale
	local limit = counter:getMaxPunch()
	local scale = hud._scale
	-- Measured before the punch is applied: the label box and its anchor
	-- (the digit centre line), which the punch scales about.
	local anchorY = value.AbsolutePosition.Y + value.AbsoluteSize.Y * value.AnchorPoint.Y
	local belowAnchor = value.AbsoluteSize.Y * (1 - value.AnchorPoint.Y)
	punchScale.Scale = 1 + limit
	local face = value:FindFirstChild("Face", true) :: TextLabel
	local width =
		TextService:GetTextSize(face.Text, Tokens.TextSize.Cash, Enum.Font.FredokaOne, Vector2.new(4096, 4096)).X
	local cashRight = face.AbsolutePosition.X + (width + 3.5) * scale * (1 + limit)
	-- Lowest visible point: the label box (conservative) plus the shadow.
	local cashBottom = anchorY + (belowAnchor + 3 * scale) * (1 + limit)
	local distanceRoot = gui:FindFirstChild("Distance") :: Frame
	local flagHolder = distanceRoot:FindFirstChild("FlagHolder") :: Frame
	local flagLeft = flagHolder.AbsolutePosition.X + flagHolder.AbsoluteSize.X / 2 - FlagIcon.ArtSize.X / 2 * scale
	local distanceTop = math.min(
		flagHolder.AbsolutePosition.Y + flagHolder.AbsoluteSize.Y / 2 - FlagIcon.ArtSize.Y / 2 * scale,
		(distanceRoot:FindFirstChild("Value") :: Frame).AbsolutePosition.Y
	)
	-- Separated if either the horizontal or the vertical gap is clear.
	local horizontal = flagLeft - cashRight
	local vertical = distanceTop - cashBottom
	local secondRow = hud._distanceRow == 2
	local gap = if secondRow then vertical else horizontal

	local overlay = Instance.new("ScreenGui")
	overlay.Name = GAP_GUIDE_NAME
	overlay.DisplayOrder = 50
	overlay.ResetOnSpawn = false
	overlay.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
	local function line(x: number, y: number, w: number, h: number)
		local f = Instance.new("Frame")
		f.Position = UDim2.fromOffset(x, y)
		f.Size = UDim2.fromOffset(w, h)
		f.BackgroundColor3 = Color3.fromRGB(255, 0, 200)
		f.BorderSizePixel = 0
		f.Parent = overlay
	end
	local labelY
	if secondRow then
		-- Horizontal lines at Cash's lowest point and Distance's top.
		local left = flagLeft - 20
		line(left, cashBottom, 180, 1)
		line(left, distanceTop, 180, 1)
		labelY = distanceTop + flagHolder.AbsoluteSize.Y + 4
	else
		local top = flagHolder.AbsolutePosition.Y - 6
		local height = flagHolder.AbsoluteSize.Y + 12
		line(cashRight, top, 1, height)
		line(flagLeft, top, 1, height)
		labelY = top + height + 2
	end
	local label = Instance.new("TextLabel")
	label.AnchorPoint = Vector2.new(1, 0)
	label.Position = UDim2.new(1, -4, 0, labelY)
	label.Size = UDim2.fromOffset(300, 30)
	label.BackgroundColor3 = Color3.new(1, 1, 1)
	label.BackgroundTransparency = 0.2
	label.Font = Enum.Font.Code
	label.TextSize = 11
	label.TextWrapped = true
	label.TextColor3 = Color3.fromRGB(30, 30, 30)
	label.Text = string.format(
		"%s gap %.1f px (horizontal %.1f, vertical %.1f), punch %.2f - guide: preview only",
		if secondRow then "Distance on 2nd row:" else "same row:",
		gap,
		horizontal,
		vertical,
		1 + limit
	)
	label.Parent = overlay
	overlay.Parent = playerGui()
	s.trove:Add(overlay)
	return gap, 1 + limit
end

-- Plays a gain on the enlarged close-up counter (preview only).
function RunHudPreview.closeupGain(amount: number)
	local s = active()
	if not s or not s.closeup then
		return
	end
	local counter = s.closeup
	counter:setValue((counter:getDebugState().value or 0) + amount)
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

-- Preview-only input receiver standing in for the game's controls (Brian R's
-- driving input is not in this place). It binds a ContextActionService action
-- to mouse button 1 and touch, the way a game control would: Roblox does not
-- deliver input to such an action when a GUI element sinks it. Each press
-- the receiver gets is logged with its position and the matching
-- UserInputService gameProcessed flag. Proves pass-through to this receiver
-- only, not driving integration. Returns Pass so nothing else is blocked.
local RECEIVER_ACTION = "Lane3PreviewInputReceiver"

function RunHudPreview.probeInput()
	local s = active()
	if not s then
		return
	end
	s.inputLog = {}
	local log = s.inputLog :: { string }
	-- Names of the HUD pieces under a point (which element was pressed).
	local function hudUnder(position: Vector3): string
		local names = {}
		for _, object in playerGui():GetGuiObjectsAtPosition(position.X, position.Y) do
			if object:IsDescendantOf(s.hud.Gui) then
				table.insert(names, object.Name)
			end
		end
		return if #names > 0 then table.concat(names, ">") else "(no HUD element)"
	end
	s.trove:Connect(UserInputService.InputBegan, function(input: InputObject, processed: boolean)
		local kind = input.UserInputType
		if kind == Enum.UserInputType.MouseButton1 or kind == Enum.UserInputType.Touch then
			table.insert(
				log,
				string.format(
					"input %s at (%d,%d) gameProcessed=%s over [%s]",
					kind.Name,
					input.Position.X,
					input.Position.Y,
					tostring(processed),
					hudUnder(input.Position)
				)
			)
		end
	end)
	ContextActionService:BindAction(RECEIVER_ACTION, function(_, state: Enum.UserInputState, input: InputObject)
		if state == Enum.UserInputState.Begin then
			table.insert(
				log,
				string.format(
					"receiver got %s at (%d,%d)",
					input.UserInputType.Name,
					input.Position.X,
					input.Position.Y
				)
			)
		end
		return Enum.ContextActionResult.Pass
	end, false, Enum.UserInputType.MouseButton1, Enum.UserInputType.Touch)
	s.trove:Add(function()
		ContextActionService:UnbindAction(RECEIVER_ACTION)
	end)
end

-- Centres of the HUD parts the pass-through test presses, in the same
-- coordinates as InputObject.Position (GUI inset excluded), for the driver.
function RunHudPreview.inputTargets(): { [string]: Vector2 }
	local s = active()
	if not s or not s.hud then
		return {}
	end
	local gui = s.hud.Gui :: ScreenGui
	local function centre(object: Instance?): Vector2
		local o = object :: GuiObject
		return o.AbsolutePosition + o.AbsoluteSize / 2
	end
	local cash = gui:FindFirstChild("Cash") :: Frame
	local distance = gui:FindFirstChild("Distance") :: Frame
	local body = (gui:FindFirstChild("HeatGauge") :: Frame):FindFirstChild("Body") :: Frame
	local function textCentre(value: Frame): Vector2
		local face = value:FindFirstChild("Face", true) :: TextLabel
		local left = face.AbsolutePosition
		return Vector2.new(left.X + face.TextBounds.X / 2, left.Y + face.AbsoluteSize.Y / 2)
	end
	local hopText = body:FindFirstChild("HopNow", true) :: Frame
	local hopFace = hopText:FindFirstChild("Text") :: TextLabel
	local hopRight = hopFace.AbsolutePosition + Vector2.new(hopFace.AbsoluteSize.X, hopFace.AbsoluteSize.Y / 2)
	return {
		CashIcon = centre(cash:FindFirstChild("IconHolder")),
		CashNumber = textCentre(cash:FindFirstChild("Value") :: Frame),
		DistanceFlag = centre(distance:FindFirstChild("FlagHolder")),
		DistanceNumber = textCentre(distance:FindFirstChild("Value") :: Frame),
		TitleTab = centre(body:FindFirstChild("TitleTab")),
		HopNow = hopRight - Vector2.new(hopFace.TextBounds.X / 2, 0),
	}
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
