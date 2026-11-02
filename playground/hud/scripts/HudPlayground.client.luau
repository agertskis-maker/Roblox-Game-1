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
-- :Invoke("setProfile", "PhoneLandscape"), :Invoke("debug") (JSON of every component state).

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
local Fixtures = require(Prototype:WaitForChild("Fixtures"))
local Motion = require(Prototype:WaitForChild("Motion"))
local Music = require(Prototype:WaitForChild("Music"))
local Priority = require(Prototype:WaitForChild("Priority"))
local RunLayout = require(Prototype:WaitForChild("Run"):WaitForChild("RunLayout"))
local Trove = require(ReplicatedStorage.Packages.Trove)

local Backdrop = require(script.Parent:WaitForChild("Backdrop"))
local DebugPanel = require(script.Parent:WaitForChild("DebugPanel"))
local Scenarios = require(script.Parent:WaitForChild("Scenarios"))
local StaminaFixture = require(script.Parent:WaitForChild("StaminaFixture"))
local WorldRoutes = require(script.Parent:WaitForChild("WorldRoutes"))

local trove = Trove.new()

pcall(function()
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)
	-- the harness character loses health off the lot; Roblox then draws its health bar top right,
	-- outside the device frame (reviewer, 2026-10-23: "an empty dark bar top right")
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, false)
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
-- Round 2 (R2-S1): the OFF-by-default Stamina proposal fixture (nothing runs until switched on)
local staminaFixture = StaminaFixture.new(store)
local priority = Priority.new()
trove:Add(function()
	priority:destroy()
end)
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
		local ctx = {
			store = store,
			screen = screen,
			layer = layers[layerName],
			world = backdrop.world,
			priority = priority,
		}
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

-- Harness log: preview-only button results (Retry, GO, Drive, prompts, Hop intent) are reported
-- here and on the debug panel, never as player-facing toasts.
api.lastAction = ""
api.logBuffer = {} :: { string }
function api.harness(text: string)
	api.lastAction = text
	table.insert(api.logBuffer, text)
	if #api.logBuffer > 400 then
		table.remove(api.logBuffer, 1)
	end
	print("[Lane3Hud] preview action: " .. text)
end
-- Debug-only: the last `n` harness lines (all when nil), optionally cleared afterwards.
function api.getLog(n: number?, clear: boolean?): string
	local count = #api.logBuffer
	local from = if n then math.max(1, count - n + 1) else 1
	local out = table.concat(api.logBuffer, "\n", from, count)
	if clear then
		table.clear(api.logBuffer)
	end
	return out
end

-- Preview captions ("PROXY", "Preview values", "placeholder times", "Pass concept (not approved)",
-- "Preview: not saved") are harness labels: hidden in the player-facing view by default and shown
-- with setCaptions(true) for annotated review captures. A watermark outside the device frame
-- always says this is a preview.
api.captions = false
local function applyCaptions(root: Instance)
	for _, d in root:GetDescendants() do
		if d:IsA("GuiObject") and (d:GetAttribute("PreviewCaption") == true or d.Name == "PreviewNote") then
			d.Visible = api.captions
		elseif d:IsA("LayerCollector") and d:GetAttribute("PreviewCaption") == true then
			d.Enabled = api.captions
		end
	end
end
function api.setCaptions(on: boolean)
	api.captions = on
	applyCaptions(gui)
	applyCaptions(backdrop.world)
end
trove:Add(task.spawn(function()
	while true do
		task.wait(0.5)
		applyCaptions(gui)
		applyCaptions(backdrop.world)
	end
end))
trove:Connect(gui.DescendantAdded, function(d)
	if d:IsA("GuiObject") and (d:GetAttribute("PreviewCaption") == true or d.Name == "PreviewNote") then
		task.defer(function()
			d.Visible = api.captions
		end)
	end
end)
do
	local mark = Instance.new("TextLabel")
	mark.Name = "PreviewWatermark"
	mark.AnchorPoint = Vector2.new(1, 1)
	mark.Position = UDim2.new(1, -6, 1, -4)
	mark.Size = UDim2.fromOffset(260, 16)
	mark.BackgroundTransparency = 1
	mark.Font = Enum.Font.GothamMedium
	mark.TextSize = 11
	mark.TextColor3 = Color3.new(1, 1, 1)
	mark.TextStrokeTransparency = 0.4
	mark.TextXAlignment = Enum.TextXAlignment.Right
	mark.Text = "LANE 3 HUD PREVIEW · synthetic fixtures · not production"
	mark.ZIndex = 200
	mark.Parent = gui
end

-- Hide or show the run HUD (the Stunt Circuit mock has its own HUD)
function api.setRunHudVisible(on: boolean)
	for _, key in { "run", "ride", "routeLine", "heat", "tray", "stamina", "keys", "hop", "hopCue", "dash", "reveal" } do
		local c = components[key]
		if c and c.setVisible then
			c:setVisible(on)
		end
	end
end
api.store = store
api.screen = screen
api.profiles = Screen.Order -- the landscape frames (Round 2: no portrait)
api.backdrop = backdrop
api.components = components
api.failures = failures
api.layers = layers

-- Scenario host (scripted playback, cancellable, reproducible)
local scenarios = Scenarios.new(api)
api.scenarios = scenarios
api.priority = priority
scenarios:loadExtras(script.Parent:FindFirstChild("scenarios"))
trove:Add(function()
	scenarios:destroy()
end)

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
		backdrop.restart()
	end
end
api.goHome = goHome
api.goRun = goRun

-- Downtown B as the real backdrop (HUD rebuild V-01, X-06): builds the preview city on this
-- client (EditableMesh kit; labelled proxies for anything missing), hides the neutral road, and
-- moves the backdrop traffic and chase camera along the city route. Preview only.
local city: any = nil
api.uploadedKit = true -- Downtown and both Worlds; `Invoke("useUploadedKit", false)` returns to the session-only EditableMesh preview
function api.useUploadedKit(on: boolean)
	api.uploadedKit = on
end
function api.useCity(on: boolean, seed: number?, world: string?): string
	if city then
		backdrop.setPath(nil)
		scenarios.cityPlan = nil
		scenarios.cityStation = nil
		city:destroy()
		city = nil
	end
	backdrop.setNeutralRoad(not on)
	if not on then
		return "neutral road"
	end
	local lookDev = ReplicatedStorage:FindFirstChild("LookDev")
	local module = lookDev and lookDev:FindFirstChild("Downtown") and lookDev.Downtown:FindFirstChild("City")
	if not module then
		backdrop.setNeutralRoad(true)
		return "city modules are not mapped in this place"
	end
	local City = require(module :: ModuleScript) :: any
	local Route = require((module :: Instance):WaitForChild("Route") :: ModuleScript) :: any
	-- Round 2: a World ("DustyHighway" / "SummitPass") builds from the same planner and finds its own kit and swatches
	local worldId = if world and world ~= "Downtown" then world else nil
	-- Uploaded kits (2026-10-31: all group-owned, LEGION STUDI0S): the Downtown B2 kit (KitIds.luau) and the Dusty Highway
	-- and Summit Pass kits (WorldsKitIds.luau). A World's road pieces are B2 meshes, so its ids are merged over the B2 ones.
	local downtownFolder = lookDev:FindFirstChild("Downtown")
	local kitIdsModule = downtownFolder and downtownFolder:FindFirstChild("KitIds")
	local worldIdsModule = downtownFolder and downtownFolder:FindFirstChild("WorldsKitIds")
	local kitIds: any = if api.uploadedKit and kitIdsModule then require(kitIdsModule :: ModuleScript) else nil
	local meshIds: { [string]: string }? = nil
	local textureId: string? = nil
	if kitIds then
		meshIds = table.clone(kitIds.meshes)
		textureId = kitIds.palettes.MainStreet
		local worldIds: any = if worldId and worldIdsModule
			then (require(worldIdsModule :: ModuleScript) :: any)[worldId]
			else nil
		if worldId and not worldIds then
			meshIds = nil -- a World without uploaded ids keeps the session-only EditableMesh preview
			textureId = nil
		elseif worldIds then
			for name, id in worldIds.meshes do
				(meshIds :: any)[name] = id
			end
			textureId = worldIds.palette
		end
	end
	local ok, err = pcall(function()
		city = City.new({
			parent = backdrop.folder,
			kit = ReplicatedStorage:FindFirstChild("Lane3_DowntownKitB2"),
			kitData = if worldId then nil else ReplicatedStorage:FindFirstChild("Lane3_DowntownKitB2Data"),
			world = worldId,
			meshIds = meshIds,
			textureId = textureId,
			seed = seed or 2207,
			preview = true,
			lighting = true,
			traffic = false, -- the playground's own fixture traffic carries the HUD cues
			streetLife = true,
			controlCamera = false,
			chaseLabel = false,
		})
		city:build(0)
	end)
	if not ok then
		backdrop.setNeutralRoad(true)
		city = nil
		return "city failed: " .. tostring(err)
	end
	local segments = city.plan.segments
	local length = 0
	for _, seg in segments do
		length += seg.length
	end
	local shorts: { [string]: string } = {}
	for _, d in WorldRoutes.plan(worldId or "Downtown").districts do
		shorts[d.id] = d.short
	end
	local districts = {}
	for _, b in city:boundaries() do
		if b.cycle == 1 or b.cycle == nil then
			table.insert(
				districts,
				{ id = b.id, name = b.name, short = shorts[b.id], length = b.lengthMetresProvisional }
			)
		end
	end
	scenarios.cityPlan = if #districts > 0
		then { districts = districts, repeats = true, world = WorldRoutes.worlds[worldId or "Downtown"] }
		else nil
	api.musicWorld = worldId or "Downtown"
	if store:get().mode == "Run" then
		Music.setWorld(api.musicWorld)
	end
	scenarios.cityStation = function(): number
		return backdrop.station()
	end
	backdrop.setPath(
		function(s: number, x: number, y: number): CFrame
			return Route.frame(segments, s, x, y)
		end,
		length,
		function(s: number)
			city:setStation(s)
		end
	)
	return (worldId or "Downtown")
		.. " city built: seed "
		.. tostring(seed or 2207)
		.. ", "
		.. math.floor(length)
		.. " studs"
end
-- Holds the run at `travelled` studs (nil resumes) for still captures; the chase camera stays on.
function api.hold(travelled: number?)
	backdrop.hold(travelled)
end
function api.showReserved(on: boolean)
	screen:showReserved(on)
end
function api.cityStats(): any
	return if city then city:stats() else nil
end
trove:Add(function()
	if city then
		city:destroy()
	end
end)

-- RunEnd hand-off: Results from the current run state (preview: the HUD never computes rewards;
-- the fixture fills what Lane 1 / Lane 2 would supply). Confirmed claims stay; a capture the
-- ribbon could not show is merged once.
function api.resultsFromRun(reason: string?)
	local state = store:get()
	if state.mode ~= "Run" then
		return
	end
	local run = state.run
	local claimed = {}
	local seen: { [string]: boolean } = {}
	if run and run.claims then
		for _, c in run.claims do
			if not seen[c.id] then
				seen[c.id] = true
				table.insert(claimed, c.car)
			end
		end
	end
	local ribbon = components.ribbon
	if ribbon and ribbon.takePendingCards then
		for _, car in ribbon:takePendingCards() do
			local key = "car:" .. tostring(car.id)
			local dup = false
			for _, c in claimed do
				if c.id == car.id then
					dup = true
				end
			end
			if not dup and not seen[key] then
				seen[key] = true
				table.insert(claimed, car)
			end
		end
	end
	local distance = if run then math.floor(run.distance) else 0
	local best = if run then run.best else 0
	local res = {
		distance = distance,
		roadCoins = if run then run.cashPickups else 0,
		totalIncludesPickups = true,
		best = math.max(best, distance),
		newBest = distance > best,
		claimed = claimed,
		earnings = 120 * #claimed + 40, -- FIXTURE amount (Lane 2 supplies real earnings)
		endReason = reason,
	}
	store:set("results", res)
	if store:setMode("Results") then
		local card = components.results
		if card and card.show then
			card:show(res, claimed)
		end
	end
end

-- Home HUD
mount("stats", { "Home", "StatsStack" }, "Hud")
mount("timers", { "Home", "TimerStack" }, "Hud")
mount("menu", { "Home", "LeftMenu" }, "Hud", {
	onGarage = function()
		api.open("garage")
	end,
	onShop = function()
		api.open("shop")
	end,
	onMissions = function()
		api.open("missions")
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
	onReplayTutorial = function()
		local Tutorial = (require :: any)((Prototype.Parent :: any).Tutorial)
		Tutorial.replay()
	end,
})
-- Screens and cards
mount("garage", { "Screens", "GarageMock" }, "Overlay", {
	onDrive = function(car: any)
		api.harness("Drive " .. tostring(car and car.name) .. " (preview only)")
	end,
})
mount("portalCard", { "Screens", "PortalCardMock" }, "Overlay", {
	onGo = function()
		api.harness("GO pressed (preview: no teleport)")
	end,
})
mount("welcome", { "Screens", "WelcomeBackMock" }, "Overlay", {})
mount("shop", { "Screens", "ShopMock" }, "Overlay", {})
mount("missions", { "Screens", "MissionsPanel" }, "Overlay", {})
mount("groupReward", { "Screens", "GroupRewardPopup" }, "Modal", {})
mount("missionTracker", { "Screens", "MissionTracker" }, "Hud", {})
mount("iconsSheet", { "IconsSheet" }, "Overlay", {})
mount("stuntPreRace", { "Screens", "StuntPreRace" }, "Overlay", {})
mount("stuntResults", { "Screens", "StuntResults" }, "Modal", {})
mount("stuntBoard", { "Screens", "StuntLeaderboard" }, "Overlay", {})
mount("stuntCustomize", { "Screens", "StuntCustomize" }, "Overlay", {})
mount("results", { "Screens", "ResultsCard" }, "Modal", {
	onRetry = function()
		goRun()
	end,
	onHome = function()
		goHome()
	end,
})
mount("stunt", { "Screens", "StuntMock" }, "Run", {})
-- Specimen sheet (harness overlay, hidden by default; HUD rebuild V-01)
mount("specimen", { "Specimen" }, "Overlay")
mount("cardSheet", { "Cards", "StatesSheet" }, "Overlay", {})
-- Round 2 collectible cards: the variant sheet and the landscape detail view
mount("tradingSheet", { "Cards", "TradingSheet" }, "Overlay", {})
mount("cardDetail", { "Screens", "CardDetail" }, "Overlay", {
	onDrive = function(car: any)
		api.harness("Drive intent for " .. tostring(car.name) .. " (preview only)")
	end,
})
-- Run HUD and world feedback
mount("run", { "Run", "RunLayer" }, "Run")
mount("ride", { "Run", "RideChip" }, "Run", {
	onOptions = function()
		api.open("settings")
	end,
})
mount("routeLine", { "Run", "RouteLine" }, "Run")
-- Round 2: the ORIGINAL ENGINE HEAT panel (RunHud.HeatGauge, unmodified) is the Heat; the round-1
-- segmented bar stays mounted but hidden, a debug-only variant for before/after comparison.
mount("heat", { "Run", "HeatPanel" }, "Run")
mount("heatSegmented", { "Run", "HeatBar" }, "Run")
-- No onDetail here on purpose: a tray tile opens the non-blocking review beside the tray. A full-screen card detail
-- would swallow Hop and touches under a live ride (reviewer finding), so it is reached only from api.openCardDetail.
mount("tray", { "Run", "ClaimTray" }, "Run")
mount("stamina", { "Run", "StaminaMeter" }, "Run")
mount("keys", { "Run", "KeysLock" }, "Run", {
	anchor = backdrop.ride,
	-- the run-time Cash and car count (StatsStack is re-anchored per device; design px)
	avoid = function()
		local stats = components.stats
		if not (stats and stats._content and stats.root and stats.root.Visible) then
			return {}
		end
		local pos, size = screen:rectOf(stats._content)
		local p = screen:profile()
		local s = screen:uiScale()
		local inset = Vector2.new(p.insets.left, p.insets.top)
		return { RunLayout.rect((pos.X - inset.X) / s, (pos.Y - inset.Y) / s, size.X / s, size.Y / s, "Stats") }
	end,
})
mount("banner", { "Run", "DistrictBanner" }, "Feedback")
mount("ribbon", { "Run", "CaptureRibbon" }, "Feedback")
mount("reveal", { "Run", "SecuredReveal" }, "Feedback") -- the full SECURED card where it clears the road view
mount("runEnd", { "Run", "RunEnd" }, "Feedback", {
	anchor = backdrop.ride,
	onFinished = function(reason: string?)
		api.resultsFromRun(reason)
	end,
})
mount("hop", { "Run", "HopButton" }, "Run", {
	onHopIntent = function()
		api.harness("Hop intent (preview only)")
	end,
})
mount("dash", { "Run", "FootDash" }, "Run")
mount("milestones", { "Run", "Milestones" }, "Feedback")
mount("hopRing", { "World", "HopRing" }, "Run", { target = backdrop.target })
mount("nameplates", { "World", "Nameplates" }, "Feedback")
mount("rareReveal", { "World", "RareReveal" }, "Feedback", {
	isPresent = function(id: string): boolean
		local plates = components.nameplates
		return plates ~= nil and plates:isTracked(id)
	end,
})
mount("hopArc", { "World", "ArcTelegraph" }, "Run", { ride = backdrop.ride, target = backdrop.target })
-- Round 2: the roof reticle (with the target rim and the brief HOP cue) and the one coordinator that drives every
-- Hop target cue (ring, arc, reticle) from the run state
mount("hopReticle", { "World", "LandingReticle" }, "Run", { target = backdrop.target })
mount("hopCue", { "Run", "HopCue" }, "Run")
mount("captureFx", { "World", "CaptureFx" }, "Feedback", { ride = backdrop.ride, rideId = "traffic-1" })
mount("warnFx", { "World", "WarnFx" }, "Feedback", { ride = backdrop.ride, rideId = "traffic-1", badge = false })
mount("tumble", { "World", "TumbleProxy" }, "Feedback", { ride = backdrop.ride })
mount("lapPay", { "World", "LapPay" }, "Feedback", { cars = backdrop.lapCars })
mount("prompts", { "World", "Prompts" }, "Feedback", {
	props = backdrop.props,
	onTriggered = function(name: string)
		api.harness(name .. " (preview: no action)")
	end,
})

-- wire the run and world components to the backdrop (their APIs take these after creation)
do
	local ring = components.hopRing
	if ring and ring.setTarget then
		ring:setTarget(backdrop.target)
		ring:setState("Hidden")
	end
	local hopCue = components.hopCue
	if hopCue and hopCue.bind then
		hopCue:bind({ ring = components.hopRing, arc = components.hopArc, reticle = components.hopReticle })
		hopCue:setTargetModel(backdrop.target)
		hopCue:setRideModel(backdrop.ride)
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
			api.harness("Hop intent sent (preview only)")
		end)
	end
	-- nameplates over the backdrop traffic (ids "traffic-<index>"; ridden = 1, Hop target = 2)
	local plates = components.nameplates
	if plates and plates.track then
		for i, m in backdrop.traffic do
			plates:track("traffic-" .. i, m, backdrop.trafficCars[i])
		end
		plates:setRidden("traffic-1")
		plates:setTarget("traffic-2")
		-- the ridden car's plate names the car the run says is ridden, so the CAPTURING plate, the
		-- Keys ring and the ribbon always name the same car (the 3D proxy keeps its shape)
		trove:Connect(store.Changed, function(key: string, state: any)
			local rideCar = key == "run" and state.run and state.run.ride
			if rideCar and rideCar ~= backdrop.trafficCars[1] then
				backdrop.trafficCars[1] = rideCar
				plates:track("traffic-1", backdrop.ride, rideCar)
			end
		end)
	end
	-- plates never sit under the run HUD (reviewer, 2026-10-23: plates under the top band on
	-- phones): the strip, Cash, Settings, ride chip, Heat, Hop, tray, an entry banner and the stats
	if plates and plates.setBlockers then
		local lctx = { store = store, screen = screen }
		plates:setBlockers(function()
			local out = {}
			-- 10 device px of clearance: the plate estimate is the text block, its outline and the NEW!
			-- tag reach a little further (Studio: RARE touched the strip distance readout)
			local PAD = Vector2.new(10, 10)
			local function add(r: any)
				local pos, size = RunLayout.toDevice(lctx :: any, r)
				table.insert(out, { pos = pos - PAD, size = size + PAD * 2 })
			end
			add(RunLayout.stripRect(lctx :: any))
			add(RunLayout.cashRect(lctx :: any))
			add(RunLayout.gearRect(lctx :: any))
			add(RunLayout.chipRect(lctx :: any))
			add((RunLayout.heatRect(lctx :: any)))
			add((RunLayout.hopRect(lctx :: any)))
			add(RunLayout.trayRect(lctx :: any))
			local banner = components.banner
			if banner and banner.getDebugState and banner:getDebugState().showing then
				add(RunLayout.bannerRect(lctx :: any))
			end
			local stats = components.stats
			if stats and stats._content and stats.root and stats.root.Visible then
				local pos, size = screen:rectOf(stats._content)
				table.insert(out, { pos = pos, size = size })
			end
			return out
		end)
	end
	local fx = components.captureFx
	if fx and fx.setNameplates then
		fx:setNameplates(plates)
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
				api.harness(spec[3] .. " (preview: no action)")
			end)
		end
		api.promptsList = specs
	end
end

-- Round 2: the landscape card detail for a roster car (ownership can be forced for review); fixtures only.
function api.openCardDetail(id: string, owned: boolean?)
	local detail = components.cardDetail
	local base = Fixtures.byId(id)
	if not detail or not base then
		return "unknown card"
	end
	local car = table.clone(base) :: any
	if owned ~= nil then
		car.owned = owned
	end
	detail:open(car, Fixtures.cardInfo(id))
	return car.name
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
local HOME = { "stats", "menu", "tutorial", "route", "timers" }
local RUN = { "hopCue", "run", "ride", "routeLine", "heat", "tray", "stamina", "keys", "hop", "dash", "runEnd" }
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
			c:setVisible(mode == "Run" and not (k == "heat" and api.heatVariant == "Segmented"))
		end
	end
	local segmented = components.heatSegmented
	if segmented and segmented.setVisible then
		segmented:setVisible(mode == "Run" and api.heatVariant == "Segmented")
	end
	local stats = components.stats
	if stats and stats.setVisible then
		stats:setVisible(mode ~= "Results")
		if stats.setCompact then
			stats:setCompact(mode == "Run")
		end
	end
	backdrop.setRunCamera(mode == "Run")
	if mode == "Run" then
		Music.setWorld(api.musicWorld)
	elseif mode == "Home" then
		Music.stop()
	end
	if mode == "Home" then
		-- stand on the playground lot facing the dummy Garage, kiosk and portal
		local character = player.Character
		if character then
			character:PivotTo(backdrop.homeSpot)
		end
	end
	-- the Hop target cues (ring, arc, reticle) follow the run state through HopCue
	local hopCue = components.hopCue
	if hopCue and hopCue.refresh then
		hopCue:refresh()
	end
	local platesNow = components.nameplates
	if platesNow and platesNow.setVisible then
		platesNow:setVisible(mode == "Run")
	end
	if mode ~= "Results" then
		local r = components.results
		if r and r.hide then
			r:hide()
		end
	end
end
trove:Connect(store.ModeChanged, applyMode)
-- re-applies the mode's visibility (a closing overlay can restore Home pieces it had hidden)
function api.applyMode()
	applyMode(store:get().mode)
end

-- Debug-only: "Original" (default; the approved ENGINE HEAT panel) or "Segmented" (the round-1 bar), for
-- before/after comparison. Round 2 uses Original everywhere.
api.stamina = staminaFixture
function api.setStamina(on: boolean, max: number?)
	staminaFixture:setEnabled(on, max)
end
function api.setStaminaRestore(on: boolean)
	staminaFixture:setRestore(on)
end
function api.resetStamina()
	staminaFixture:reset()
end
function api.staminaDebug(): { [string]: any }
	return staminaFixture:getDebugState()
end
-- Debug-only: delivers a store event from MCP (id and kind filled in).
function api.emitEvent(kind: string, fields: { [string]: any }?)
	local e = fields or {}
	e.id = e.id or (kind .. "-" .. tostring(os.clock()))
	e.kind = kind
	store:emit(e)
end
-- Debug-only: merges fields into the current run state (a held state for review captures).
function api.patchRun(patch: { [string]: any })
	local run = store:get().run
	if run then
		local merged = table.clone(run) :: any
		for k, v in patch do
			merged[k] = v
		end
		store:set("run", merged)
	end
end
-- Review-capture helpers (lead, Round 3): enter or leave Run, hold a Keys state, set the Stamina value, a landing.
function api.setMode(mode: string)
	if mode == "Run" and store:get().mode ~= "Run" then
		store:setMode("Run")
		scenarios:startRunState()
	elseif mode ~= "Run" then
		store:setMode(mode :: any)
	end
	applyMode(store:get().mode)
end
function api.setKeysState(progress: number, status: string?, carId: string?)
	local car = table.clone(Fixtures.byId(carId or "rev6") or Fixtures.Cars[1]) :: any
	car.owned = false
	api.patchRun({ keys = { id = "cap-review", target = car, progress = progress, status = status or "Holding" } })
end
function api.clearKeysState()
	local run = store:get().run
	if run then
		local merged = table.clone(run) :: any
		merged.keys = nil
		store:set("run", merged)
	end
end
function api.setStaminaValue(n: number)
	staminaFixture:setValue(n)
end
function api.setRide(carId: string, instanceId: string?)
	local car = Fixtures.byId(carId) or Fixtures.Cars[1]
	api.patchRun({ ride = car, rideInstanceId = instanceId or ("ride-" .. carId) })
end
-- Round 2 route line fixtures (all default to the Downtown route, no prior best, the fixture speed):
-- the World whose route the run shows (also switches the current run), the pre-run record (nil = none) with its
-- verified flag, and the fixture speed in metres per second (0 holds the distance still for captures).
-- Round 2 run music (OFF by default; licensed tracks are metadata-screened only, never claimed listened).
api.musicWorld = "Downtown"
function api.musicEnable(on: boolean)
	Music.enable(on)
	if on and store:get().mode == "Run" then
		Music.setWorld(api.musicWorld)
	end
end
function api.musicCandidate(key: string, index: number)
	Music.useCandidate(key, index)
end
function api.musicTension(progress: number, phase: string?)
	Music.tension(progress, phase or "Holding")
end
function api.musicResolve()
	Music.resolve()
end
function api.musicCancel()
	Music.cancel()
end
function api.musicDuck(id: string, seconds: number?)
	Music.duck(id, seconds or 1.2)
end
function api.musicStop()
	Music.stop()
end
function api.musicReset()
	Music.reset()
end
function api.musicState(): string
	return game:GetService("HttpService"):JSONEncode(Music.state())
end

function api.setWorld(id: string): string
	api.musicWorld = id
	if store:get().mode == "Run" then
		Music.setWorld(id)
	end
	local plan = WorldRoutes.plan(id)
	scenarios.worldPlan = if id == "Downtown" then nil else plan
	api.patchRun({ districtPlan = plan })
	return plan.world.name
end
function api.setRecord(recordM: number?, verified: boolean?)
	scenarios.recordM = recordM
	scenarios.recordVerified = verified
	local run = store:get().run
	if run then
		local merged = table.clone(run) :: any
		merged.recordM = recordM
		merged.recordVerified = verified
		store:set("run", merged)
	end
end
function api.setSpeed(metresPerSecond: number?)
	scenarios.speed = metresPerSecond
end
-- Round 2 Hop cues: the ONE selected target, by traffic index (2 = the Puglet ahead). Retargeting sends the new id
-- through the run state (what Lane 1 would do) and points every cue model at the same car.
-- Haptics (best effort; ON by default since Round 3, switched in Settings; never claimed felt on hardware)
function api.setHaptics(on: boolean)
	local settings = table.clone(store:get().settings) :: any
	settings.haptics = on
	store:set("settings", settings)
end
function api.setHopTarget(index: number?): string
	local model = if index then backdrop.traffic[index] else nil
	api.patchRun({ hopTargetId = if model then "traffic-" .. tostring(index) else nil })
	local run = store:get().run
	if run and not model then
		local merged = table.clone(run) :: any
		merged.hopTargetId = nil
		store:set("run", merged)
	end
	local cue = components.hopCue
	if cue and cue.setTargetModel then
		cue:setTargetModel(model)
	end
	return if model then model.Name else "none"
end
-- Debug: the rectangles the Run HUD lays out on the current layout (design px), as JSON, for overlap work.
function api.layoutRects(): string
	local ribbon = components.ribbon
	local ctx = ribbon and ribbon._ctx
	if not ctx then
		return "no ctx"
	end
	local function box(r: any): any
		return if r then { x = r.pos.X, y = r.pos.Y, w = r.size.X, h = r.size.Y, name = r.name } else nil
	end
	local out: { [string]: any } = { design = { x = RunLayout.design(ctx).X, y = RunLayout.design(ctx).Y } }
	out.protected = box(RunLayout.protected(ctx))
	out.hop = box((RunLayout.hopRect(ctx)))
	out.heat = box((RunLayout.heatRect(ctx)))
	out.tray = box(RunLayout.trayRect(ctx))
	out.cash = box(RunLayout.cashRect(ctx))
	out.gear = box(RunLayout.gearRect(ctx))
	out.stamina = box(RunLayout.staminaRect(ctx))
	out.staminaSoft = RunLayout.staminaSoft(ctx) -- px the display-only meter sinks into the thumbstick zone (phones)
	out.route = box(RunLayout.routeRect(ctx))
	out.chip = box(RunLayout.chipRect(ctx))
	out.side = box(RunLayout.sideRect(ctx))
	out.top = box(RunLayout.topBlock(ctx))
	local zones = {}
	for _, z in RunLayout.zones(ctx) do
		table.insert(zones, box(z))
	end
	out.zones = zones
	return game:GetService("HttpService"):JSONEncode(out)
end
api.heatVariant = "Original"
function api.setHeatVariant(variant: string)
	api.heatVariant = if variant == "Segmented" then "Segmented" else "Original"
	applyMode(store:get().mode)
end

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
-- Debug-only (Round 3): the Heat panel's text floor in real device px (16 = the project minimum; lower = a smaller panel).
function api.setHeatFloor(px: number)
	RunLayout.HeatTextFloor = px
	relayout()
end

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
	applyMode(store:get().mode)
end
function api.reset()
	(require :: any)((Prototype.Parent :: any).Tutorial).stop()
	scenarios:cancel()
	priority:clear()
	local specimen = components.specimen
	if specimen and specimen.setVisible then
		specimen:setVisible(false)
	end
	for _, k in { "settings", "garage", "portalCard", "welcome", "shop", "cardSheet", "tradingSheet", "cardDetail" } do
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
-- Test driver helpers (lead, Round 3): the scenario names, and the one still running (nil when idle).
function api.scenarioList(): string
	return game:GetService("HttpService"):JSONEncode(scenarios.list)
end
function api.scenarioBusy(): string?
	return scenarios.current
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
	if command == "call" then
		-- drive one component from a test: call(key, method, arguments...)
		local c = components[args[1]]
		assert(c, "no component " .. tostring(args[1]))
		local result = c[args[2]](c, table.unpack(args, 3))
		return if type(result) == "table" then HttpService:JSONEncode(result) else result
	end
	if command == "debug" then
		local out: { [string]: any } = { mode = store:get().mode, profile = screen:profile().name, failures = failures }
		out.priority = priority:getDebugState()
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
