--!strict
-- PLAYGROUND BOOTSTRAP (Lane 3 HUD prototype, overnight preview 2026-10-22). Runs only in the
-- dedicated HUD playground place: it needs Studio AND ReplicatedStorage.Lane3Playground with
-- attribute Kind == "hud", which exists only in playground/hud.project.json. The game's
-- default.project.json maps neither this folder nor that marker, so real players and ordinary
-- game Play sessions never load the prototype, its fixtures or its debug panel.
--
-- Everything shown is presentation driven by synthetic fixtures through a preview store. No
-- remotes, saving, rewards, purchases or teleports. Retry, Go Home, Shop, claims and portal
-- buttons only make documented local preview transitions.
--
-- Control from the Studio command bar or MCP (client side): the BindableFunction
-- PlayerGui.Lane3HudPlayground.Lane3HudControl, e.g. :Invoke("play", "Toasts"),
-- :Invoke("setProfile", "PhonePortrait"), :Invoke("debug") (JSON of every component state).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")

local marker = ReplicatedStorage:FindFirstChild("Lane3Playground")
if not (RunService:IsStudio() and marker and marker:GetAttribute("Kind") == "hud") then
	return
end

local player = Players.LocalPlayer
local Prototype = script.Parent.Parent:WaitForChild("Client"):WaitForChild("UI"):WaitForChild("Prototype")
local Screen = require(Prototype:WaitForChild("Screen"))
local Store = require(Prototype:WaitForChild("Store"))
local Motion = require(Prototype:WaitForChild("Motion"))
local Trove = require(ReplicatedStorage.Packages.Trove)

local Backdrop = require(script.Parent:WaitForChild("Backdrop"))
local DebugPanel = require(script.Parent:WaitForChild("DebugPanel"))
local Scenarios = require(script.Parent:WaitForChild("Scenarios"))

local trove = Trove.new()

pcall(function()
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)
end)

local gui = trove:Add(Instance.new("ScreenGui"))
gui.Name = "Lane3HudPlayground"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.ScreenInsets = Enum.ScreenInsets.None -- the device frame applies its own assumed insets once
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.DisplayOrder = 10
gui.Parent = player:WaitForChild("PlayerGui")

local screen = Screen.new(gui, "Desktop")
local store = Store.new()
local backdrop = Backdrop.build()
trove:Add(function()
	backdrop.destroy()
end)

local function layer(name: string, z: number): Frame
	local f = Instance.new("Frame")
	f.Name = name
	f.Size = UDim2.fromScale(1, 1)
	f.BackgroundTransparency = 1
	f.ZIndex = z
	f.Parent = screen.safe
	return f
end
local layers = {
	Hud = layer("HudLayer", 10),
	Run = layer("RunLayer", 20),
	Overlay = layer("OverlayLayer", 30),
	Modal = layer("ModalLayer", 40),
	Feedback = layer("FeedbackLayer", 50),
}

-- Components are required defensively: a missing or failing module is reported on the debug
-- panel instead of stopping the playground.
local components: { [string]: any } = {}
local failures: { [string]: string } = {}
local function mount(key: string, path: { string }, layerName: string, options: any?)
	local ok, result = pcall(function()
		local node: Instance = Prototype
		for _, step in path do
			node = node:FindFirstChild(step) :: Instance
			assert(node, "missing " .. table.concat(path, "/"))
		end
		local module = require(node :: ModuleScript) :: any
		local ctx = { store = store, screen = screen, layer = layers[layerName], world = backdrop.world }
		return module.new(ctx, options)
	end)
	if ok then
		components[key] = result
	else
		failures[key] = tostring(result)
		warn("[Lane3Hud] " .. key .. " failed: " .. tostring(result))
	end
end

local api: { [string]: any } = {}
api.store = store
api.screen = screen
api.backdrop = backdrop
api.components = components
api.failures = failures
api.layers = layers

-- Scenario host (scripted playback, cancellable, reproducible)
local scenarios = Scenarios.new(api)
api.scenarios = scenarios

-- preview transitions (local only)
local function goHome()
	if store:setMode("Home") then
		store:set("run", nil)
	end
end
local function goRun()
	if store:get().mode == "Results" then
		store:set("results", nil)
	end
	if store:setMode("Run") then
		scenarios:startRunState()
	end
end
api.goHome = goHome
api.goRun = goRun

-- Home HUD
mount("cash", { "Home", "CashLine" }, "Hud")
mount("menu", { "Home", "LeftMenu" }, "Hud", {
	onGarage = function()
		api.open("garage")
	end,
	onShop = function()
		api.open("shop")
	end,
	onMissions = function()
		store:emit({
			id = "missions-" .. os.clock(),
			kind = "Toast",
			text = "Missions (mock): nothing to claim yet",
			tone = "Info",
		})
	end,
	onSettings = function()
		local menu = components.menu
		local settings = components.settings
		if settings and settings.open then
			settings:open(if menu and menu.getButton then menu:getButton("Settings") else nil)
		end
	end,
})
mount("tutorial", { "Home", "TutorialBanner" }, "Hud")
mount("toasts", { "Home", "ToastStack" }, "Feedback")
mount("route", { "Home", "TutorialRoute" }, "Hud")
mount("settings", { "Home", "SettingsPanel" }, "Modal", {
	onClosed = function() end,
})
-- Screens and cards
mount("garage", { "Screens", "GarageMock" }, "Overlay", {
	onDrive = function(car: any)
		store:emit({
			id = "drive-" .. os.clock(),
			kind = "Toast",
			text = "Drive " .. tostring(car and car.name) .. " (preview only)",
			tone = "Info",
		})
	end,
})
mount("portalCard", { "Screens", "PortalCardMock" }, "Overlay", {
	onGo = function()
		store:emit({
			id = "go-" .. os.clock(),
			kind = "Toast",
			text = "GO pressed (preview: no teleport)",
			tone = "Info",
		})
	end,
})
mount("welcome", { "Screens", "WelcomeBackMock" }, "Overlay", {})
mount("shop", { "Screens", "ShopMock" }, "Overlay", {})
mount("results", { "Screens", "ResultsCard" }, "Modal", {
	onRetry = function()
		goRun()
	end,
	onHome = function()
		goHome()
	end,
})
mount("stunt", { "Screens", "StuntMock" }, "Run", {})
-- Run HUD and world feedback
mount("run", { "Run", "RunLayer" }, "Run")
mount("ride", { "Run", "RideChip" }, "Run", {
	onOptions = function()
		api.open("settings")
	end,
})
mount("keys", { "Run", "KeysRing" }, "Run")
mount("capture", { "Run", "CaptureCelebration" }, "Feedback")
mount("owned", { "Run", "AlreadyOwned" }, "Feedback")
mount("hop", { "Run", "HopButton" }, "Run", {
	onHopIntent = function()
		store:emit({
			id = "hopintent-" .. os.clock(),
			kind = "Toast",
			text = "Hop intent (preview only)",
			tone = "Info",
		})
	end,
})
mount("dash", { "Run", "FootDash" }, "Run")
mount("milestones", { "Run", "Milestones" }, "Feedback")
mount("hopRing", { "World", "HopRing" }, "Run", { target = backdrop.target })
mount("lapPay", { "World", "LapPay" }, "Feedback", { cars = backdrop.lapCars })
mount("prompts", { "World", "Prompts" }, "Feedback", {
	props = backdrop.props,
	onTriggered = function(name: string)
		store:emit({
			id = "prompt-" .. name .. os.clock(),
			kind = "Toast",
			text = name .. " (preview: no action)",
			tone = "Info",
		})
	end,
})

-- wire the run and world components to the backdrop (their APIs take these after creation)
do
	local ring = components.hopRing
	if ring and ring.setTarget then
		ring:setTarget(backdrop.target)
		ring:setState("Hidden")
	end
	local lap = components.lapPay
	if lap and lap.setCars then
		lap:setCars(backdrop.lapCars)
	end
	local ride = components.ride
	if ride and ride.setOptionsCallback then
		ride:setOptionsCallback(function()
			local settings = components.settings
			if settings and settings.open then
				settings:open(nil)
			end
		end)
	end
	local hop = components.hop
	if hop and hop.setHopIntent then
		hop:setHopIntent(function()
			store:emit({
				id = "hopintent-" .. os.clock(),
				kind = "Toast",
				text = "Hop intent sent (preview only)",
				tone = "Info",
			})
		end)
	end
	-- dummy prompts on the playground props (presentation only; triggering does nothing real)
	local prompts = components.prompts
	if prompts and prompts.attach then
		local specs = {
			{ backdrop.props.garage, "Open Garage", "Garage", 0 },
			{ backdrop.props.kiosk, "Upgrade", "Kiosk", 0.8 },
			{ backdrop.props.portal, "Enter", "Downtown portal", 0 },
		}
		for _, spec in specs do
			local pp = Instance.new("ProximityPrompt")
			pp.ActionText = spec[2]
			pp.ObjectText = spec[3]
			pp.HoldDuration = spec[4]
			pp.MaxActivationDistance = 16
			pp.KeyboardKeyCode = Enum.KeyCode.E
			pp.GamepadKeyCode = Enum.KeyCode.ButtonX
			pp.RequiresLineOfSight = false
			pp.Style = Enum.ProximityPromptStyle.Custom
			pp.Parent = spec[1]
			prompts:attach(pp, function()
				store:emit({
					id = "prompt-" .. spec[3] .. os.clock(),
					kind = "Toast",
					text = spec[3] .. " (preview: no action)",
					tone = "Info",
				})
			end)
		end
		api.promptsList = specs
	end
end

function api.open(name: string)
	local c = components[name]
	if c and c.open then
		c:open()
	end
end
function api.close(name: string)
	local c = components[name]
	if c and c.close then
		c:close()
	end
end

-- visibility by mode
local HOME = { "cash", "menu", "tutorial", "route" }
local RUN = { "run", "ride", "keys", "hop", "dash" }
local function applyMode(mode: string)
	for _, k in HOME do
		local c = components[k]
		if c and c.setVisible then
			c:setVisible(mode == "Home")
		end
	end
	for _, k in RUN do
		local c = components[k]
		if c and c.setVisible then
			c:setVisible(mode == "Run")
		end
	end
	backdrop.setRunCamera(mode == "Run")
	if mode == "Home" then
		-- stand on the playground lot facing the dummy Garage, kiosk and portal
		local character = player.Character
		if character then
			character:PivotTo(backdrop.homeSpot)
		end
	end
	local ring = components.hopRing
	if ring and ring.setState then
		ring:setState(if mode == "Run" then "Available" else "Hidden")
	end
	if mode ~= "Results" then
		local r = components.results
		if r and r.hide then
			r:hide()
		end
	end
end
trove:Connect(store.ModeChanged, applyMode)

local function relayout()
	for _, c in components do
		if c.layout then
			local ok, err = pcall(function()
				c:layout()
			end)
			if not ok then
				warn("[Lane3Hud] layout failed: " .. tostring(err))
			end
		end
	end
end
trove:Connect(screen.Changed, relayout)

-- A fixed capture camera held by this script (MCP resets a camera type set from execute_luau).
local captureCam: RBXScriptConnection? = nil
function api.setCamera(eye: Vector3?, at: Vector3?)
	if captureCam then
		captureCam:Disconnect()
		captureCam = nil
	end
	if not (eye and at) then
		backdrop.setRunCamera(store:get().mode == "Run")
		return
	end
	backdrop.setRunCamera(false)
	local camera = workspace.CurrentCamera
	captureCam = RunService.RenderStepped:Connect(function()
		camera.CameraType = Enum.CameraType.Scriptable
		camera.CFrame = CFrame.lookAt(eye, at)
	end)
end
trove:Add(function()
	if captureCam then
		captureCam:Disconnect()
	end
end)

function api.setProfile(name: string)
	screen:setProfile(name)
end
function api.reset()
	scenarios:cancel()
	for _, k in { "settings", "garage", "portalCard", "welcome", "shop" } do
		api.close(k)
	end
	store:reset()
	Motion.setOverride(nil)
	applyMode("Home")
	relayout()
end
function api.play(name: string)
	return scenarios:play(name)
end

local panel = DebugPanel.new(gui, api)
api.panel = panel
api.hideControls = function(on: boolean)
	panel:setHidden(on)
end

applyMode("Home")
relayout()
store:reset()

local HttpService = game:GetService("HttpService")
local control = Instance.new("BindableFunction")
control.Name = "Lane3HudControl"
control.OnInvoke = function(command: string, ...: any): any
	local args = { ... }
	if command == "debug" then
		local out: { [string]: any } = { mode = store:get().mode, profile = screen:profile().name, failures = failures }
		for key, c in components do
			if c.getDebugState then
				local ok, d = pcall(function()
					return c:getDebugState()
				end)
				out[key] = if ok then d else ("error: " .. tostring(d))
			end
		end
		local ok, json = pcall(function()
			return HttpService:JSONEncode(out)
		end)
		return if ok then json else tostring(json)
	elseif command == "state" then
		return HttpService:JSONEncode(store:get())
	end
	local fn = api[command]
	if type(fn) == "function" then
		return fn(table.unpack(args))
	end
	return "unknown command " .. tostring(command)
end
control.Parent = gui

local count = 0
for _ in failures do
	count += 1
end
print("[Lane3Hud] playground ready; component failures: " .. count)
