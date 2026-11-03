--!strict
-- LaunchPad: the whole loop around a run (Lane 3, Round 3 N6 and N8): island portal -> Launch Pad -> ramp -> launch card -> START ->
-- run -> results -> RETRY or HOME. The beta glue says how a run starts and stops; everything the player sees between runs is here.
--
--   LaunchPad.configure({ startRun = fn(world) -> run, stopRun = fn(), onPhase = fn(phase)? })
--   LaunchPad.attachShell(shell)           -- mounts the panels on the HomeShell's screen
--   LaunchPad.enter(world, islandCFrame)   -- from a portal: wipe, stand on the pad
--
-- On the pad: stand in a kiosk's glowing circle to open it, walk the ramp for the launch card, and START runs the gantry's four
-- lights before the run. The camera's zoom is capped on the pad and put back when the player leaves it.
--   LaunchPad.phase() -> "island" | "pad" | "run"     LaunchPad.reset()     LaunchPad.prepare()
--
-- From a run it reads only public things: run:getDebugState(), run:revive(), run.Ended, and PlayerGui.Lane1RunOverlay (to hide his
-- temporary results card in the beta). Hopping and Heat are never touched.
-- Pads stand far from the island and the road, built on the client the first time they are needed, so a run or the island can
-- never see one. Brian R's and Brian L's files are not edited. Cash shown after a run is a PREVIEW figure.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Build = require(script.Build)
local RunCamera = require(script.RunCamera)
local RunStamina = require(script.RunStamina)
local Prototype = script.Parent.Prototype
local CarKit = require(Prototype.CarKit)
local Motion = require(Prototype.Motion)
local Sounds = require(Prototype.Sounds)
local StyleState = require(Prototype.StyleState)
local Catalog = require(ReplicatedStorage.Shared.UI.ShopPreviewCatalog)
local Trove = require(ReplicatedStorage.Packages.Trove)

local LaunchPad = {}

export type Hooks = {
	startRun: (world: string) -> any,
	stopRun: (again: boolean) -> (),
	onPhase: ((phase: string) -> ())?,
}

local WORLD_TITLE: { [string]: string } =
	{ Downtown = "DOWNTOWN", DustyHighway = "DUSTY HIGHWAY", SummitPass = "SUMMIT PASS" }
local ORIGINS: { [string]: CFrame } = {
	Downtown = CFrame.new(6000, 1200, 0),
	DustyHighway = CFrame.new(7400, 1200, 0),
	SummitPass = CFrame.new(8800, 1200, 0),
}

local player = Players.LocalPlayer
local hooks: Hooks? = nil
local shell: any = nil
local phase = "island"
local world = "Downtown"
local returnTo: CFrame? = nil
local pads: { [string]: Build.Pad } = {}
local padTrove = Trove.new()
local lifeTrove = Trove.new()
local runTrove = Trove.new()
local rampArmed = true
local bestMetres = 0
local unbindKey: (() -> ())? = nil
local hint: string? = nil
local padVisits = 0
local savedZoom: number? = nil

local PAD_ZOOM = 44 -- far enough to take in the floor, never so far the platform looks small
local STAND_RADIUS = 3.8
local LIGHT_RED = Color3.fromRGB(255, 50, 50)
local LIGHT_GREEN = Color3.fromRGB(70, 255, 110)
local LIGHT_SECONDS = 0.4
local CHEVRON_VISITS = 3 -- how many visits show the way to the ramp

-- tutorial events, through the lazily required module, so a place with no tutorial still runs
local function tutorial(name: string, data: { [string]: any }?)
	pcall(function()
		(require :: any)(script.Parent.Tutorial).emitIsland(name, data)
	end)
end

local function setPhase(p: string)
	phase = p
	if hooks and hooks.onPhase then
		hooks.onPhase(p)
	end
end

function LaunchPad.phase(): string
	return phase
end

function LaunchPad.world(): string
	return world
end

-- The tutorial's sub-hint on the launch card, nil to clear.
function LaunchPad.setHint(text: string?)
	hint = text
end

function LaunchPad.configure(h: Hooks)
	hooks = h
end

local function root(): BasePart?
	local c = player.Character
	local r = c and c:FindFirstChild("HumanoidRootPart")
	return if r and r:IsA("BasePart") then r else nil
end

local function moveTo(cf: CFrame)
	local r = root()
	if r then
		r.AssemblyLinearVelocity = Vector3.zero;
		(r.Parent :: Model):PivotTo(cf)
		-- the camera turns with the player, so the first look is at what is ahead
		local cam = Workspace.CurrentCamera
		if cam then
			cam.CFrame = CFrame.lookAt((cf * CFrame.new(0, 7, 15)).Position, (cf * CFrame.new(0, 1, -20)).Position)
		end
	end
end

-- A short wipe: the screen closes, `middle` runs out of sight, the screen opens.
local function wipe(title: string?, middle: () -> ())
	local gui = shell and shell.gui
	if not gui then
		middle()
		return
	end
	local veil = CarKit.make("Frame", {
		Name = "LaunchWipe",
		BackgroundColor3 = Color3.fromRGB(10, 16, 40),
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 500,
	}, gui) :: Frame
	local label: TextLabel? = nil
	if title then
		label = CarKit.title(veil, title, 72, {
			align = Enum.TextXAlignment.Center,
			top = CarKit.Yellow,
			bottom = CarKit.Orange,
			z = 501,
			shadow = false,
		});
		(label :: TextLabel).TextTransparency = 1
	end
	local info = TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(veil, info, { BackgroundTransparency = 0 }):Play()
	if label then
		TweenService:Create(label, info, { TextTransparency = 0 }):Play()
	end
	task.wait(0.2)
	middle()
	task.wait(if title and not Motion.reduced() then 0.45 else 0.1)
	local out = TweenInfo.new(0.24, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	TweenService:Create(veil, out, { BackgroundTransparency = 1 }):Play()
	if label then
		TweenService:Create(label, out, { TextTransparency = 1 }):Play()
		local stroke = label:FindFirstChildOfClass("UIStroke")
		if stroke then
			TweenService:Create(stroke, out, { Transparency = 1 }):Play()
		end
	end
	task.delay(0.3, function()
		veil:Destroy()
	end)
end

local function setLight(name: string?)
	local look = ReplicatedStorage:FindFirstChild("LookDev")
	if not look then
		return
	end
	pcall(function()
		local City = look.Downtown.City
		local Assembler = (require :: any)(City.Assembler)
		if name then
			local Worlds = (require :: any)(City.Worlds)
			local def = Worlds.get(name)
			Assembler.applyLighting(def and def.lighting)
		else
			Assembler.restoreLighting()
		end
	end)
end

-- Keep the HUD simple on the pad: the leaderboard and VIP buttons rest until the player is back on the island.
local function quietHud(on: boolean)
	local hud = shell and shell.hud
	if hud then
		for _, name in { "Leaderboard", "VIP", "Vip" } do
			local button = hud:getButton(name)
			if button then
				button.Visible = not on
			end
		end
	end
end

local function setPadLight(pad: Build.Pad)
	local look = ReplicatedStorage:FindFirstChild("LookDev")
	if look then
		pcall(function()
			((require :: any)(look.Downtown.City.Assembler)).applyLighting(pad.theme.lighting)
		end)
	end
end

local function capZoom(on: boolean)
	if on and savedZoom == nil then
		savedZoom = player.CameraMaxZoomDistance
		player.CameraMaxZoomDistance = PAD_ZOOM
	elseif not on and savedZoom then
		player.CameraMaxZoomDistance = savedZoom
		savedZoom = nil
	end
end

-- "<WORLD> LAUNCH PAD" slides in for about two seconds.
local function arrivalBanner(text: string)
	local gui = shell and shell.gui
	if not gui then
		return
	end
	local label = CarKit.title(gui, text, 54, {
		align = Enum.TextXAlignment.Center,
		anchor = Vector2.new(0.5, 0),
		position = UDim2.new(0.5, 0, 0, -80),
		size = UDim2.new(0.9, 0, 0, 66),
		top = CarKit.White,
		bottom = CarKit.Yellow,
		z = 60,
		name = "PadBanner",
	})
	if Motion.reduced() then
		label.Position = UDim2.new(0.5, 0, 0, 56)
	else
		local info = TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
		TweenService:Create(label, info, { Position = UDim2.new(0.5, 0, 0, 56) }):Play()
	end
	task.delay(2.2, function()
		local gone = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		TweenService:Create(label, gone, { Position = UDim2.new(0.5, 0, 0, -80) }):Play()
		task.delay(0.3, function()
			label:Destroy()
		end)
	end)
end

local function padFor(name: string): Build.Pad
	local pad = pads[name]
	if not pad then
		pad = Build.build(name, ORIGINS[name] or ORIGINS.Downtown)
		pad.folder.Parent = nil -- out of the world until someone stands on it
		pads[name] = pad
	end
	return pad
end

-- Builds the pads ahead of time, a frame apart, so the first portal has no pause.
function LaunchPad.prepare()
	task.spawn(function()
		for name in ORIGINS do
			task.wait(1)
			padFor(name)
		end
	end)
end

local function isTutorial(): boolean
	local ok, active = pcall(function()
		return (require :: any)(script.Parent.Tutorial).isActive()
	end)
	return ok and active == true
end

local function panel(key: string): any
	return shell and shell.components[key]
end

-- A panel left open must not ride along through a portal.
local function closeHomePanels()
	for _, key in { "shop", "garage", "customize", "missions", "settings", "stuntBoard" } do
		local c = panel(key)
		if c and c.isOpen and c.close and c:isOpen() then
			c:close()
		end
	end
end

local function anyPanelOpen(): boolean
	for _, key in { "launchStyle", "carStall", "shop", "garage", "customize", "missions", "settings" } do
		local c = panel(key)
		if c and c.isOpen and c:isOpen() then
			return true
		end
	end
	return false
end

local function openStall(key: string)
	if key == "Cars" then
		panel("carStall"):open()
	elseif key == "Trails" then
		panel("launchStyle"):open(nil, { title = "TRAILS", tabs = { "Trails" }, tab = "Trails" })
	else
		panel("launchStyle"):open(nil, { title = "PAINT SHOP", tabs = { "Paint", "Decals", "Wheels" }, tab = "Paint" })
	end
end

local function watchPad(pad: Build.Pad)
	padTrove:Clean()
	lifeTrove:Clean()
	rampArmed = true
	lifeTrove:Connect(RunService.Heartbeat, function(dt: number)
		pad:step(dt)
	end)
	-- the kiosks' circles: each opens once per visit to the circle
	local standing: { [string]: boolean } = {}
	local last = 0
	padTrove:Connect(RunService.Heartbeat, function()
		local now = os.clock()
		if now - last < 0.1 or phase ~= "pad" then
			return
		end
		last = now
		local r = root()
		if not r then
			return
		end
		local p = r.Position
		-- over the edge somehow: back on the pad, no harm done
		if p.Y < pad.floorY - 12 then
			moveTo(pad.arrival)
			return
		end
		for key, part in pad.stalls do
			local flat = Vector3.new(p.X - part.Position.X, 0, p.Z - part.Position.Z)
			if flat.Magnitude < STAND_RADIUS then
				if not standing[key] and not anyPanelOpen() then
					standing[key] = true
					openStall(key)
				end
			else
				standing[key] = false
			end
		end
		local d = p - pad.rampCentre
		local inside = math.abs(d.X) < pad.rampHalf.X and math.abs(d.Z) < pad.rampHalf.Y and math.abs(d.Y) < 12
		local card = panel("launchCard")
		if inside and rampArmed and not anyPanelOpen() and card and not card:isOpen() then
			rampArmed = false
			card:open(WORLD_TITLE[world] or world, hint)
			tutorial("PadCard", { open = true })
		elseif not inside and not rampArmed then
			rampArmed = true
			if card and card:isOpen() then
				card:close()
			end
			tutorial("PadCard", { open = false })
		end
		local h = Vector3.new(p.X - pad.home.X, 0, p.Z - pad.home.Z)
		if h.Magnitude < 5.5 then
			LaunchPad.leave()
		end
	end)
end

function LaunchPad.enter(name: string, islandCFrame: CFrame)
	if phase ~= "island" then
		return
	end
	setPhase("pad")
	world = name
	returnTo = islandCFrame
	closeHomePanels()
	wipe(WORLD_TITLE[name], function()
		local pad = padFor(name)
		pad.folder.Parent = Workspace
		setPadLight(pad)
		capZoom(true)
		moveTo(pad.arrival)
		padVisits += 1
		pad:showChevrons(padVisits <= CHEVRON_VISITS or isTutorial())
		pad:setLive(true)
		quietHud(true)
		arrivalBanner(pad.theme.title)
		-- a pad built this frame has no collision yet: hold the player still for a moment
		local r = root()
		if r then
			r.Anchored = true
			task.delay(0.3, function()
				r.Anchored = false
			end)
		end
		watchPad(pad)
		tutorial("PadEntered", { ramp = pad.rampCentre, world = name })
	end)
end

function LaunchPad.leave()
	if phase ~= "pad" then
		return
	end
	padTrove:Clean()
	lifeTrove:Clean()
	capZoom(false)
	quietHud(false)
	local gone = pads[world]
	if gone then
		gone:setLive(false)
	end
	setPhase("leaving")
	local card = panel("launchCard")
	if card and card:isOpen() then
		card:close()
	end
	task.spawn(function()
		wipe(nil, function()
			setLight(nil)
			if returnTo then
				moveTo(returnTo)
			end
			local pad = pads[world]
			if pad then
				pad.folder.Parent = nil
			end
		end)
		task.wait(2) -- out of the portal's field before it can fire again
		setPhase("island")
	end)
end

-- The real Trail behind the player's car, from attachments on the rider. It follows every hop.
local function attachTrail()
	local item = StyleState.item("Trails")
	local r = root()
	if not (item and item.key and r) then
		return
	end
	local GameIcons = require(Prototype.GameIcons)
	local a = runTrove:Add(Instance.new("Attachment"))
	local b = runTrove:Add(Instance.new("Attachment"))
	a.Position = Vector3.new(-1.8, -1.4, 5.4)
	b.Position = Vector3.new(1.8, -1.4, 5.4)
	a.Parent = r
	b.Parent = r
	local trail = runTrove:Add(Instance.new("Trail"))
	trail.Name = "Lane3RunTrail"
	trail.Attachment0 = a
	trail.Attachment1 = b
	trail.Lifetime = 0.55
	trail.LightEmission = 0.6
	trail.FaceCamera = false
	trail.Texture = GameIcons.uri("ribbon_" .. item.key) or ""
	trail.TextureMode = Enum.TextureMode.Stretch
	if #item.colours > 1 and not trail.Texture then
		local stops = {}
		for i, c in item.colours do
			table.insert(stops, ColorSequenceKeypoint.new((i - 1) / (#item.colours - 1), c))
		end
		trail.Color = ColorSequence.new(stops)
	end
	trail.Parent = r
end

local function rarityOf(name: string): string
	for _, word in { "Legendary", "Epic", "Rare", "Uncommon" } do
		if string.find(string.lower(name), string.lower(word), 1, true) then
			return word
		end
	end
	return "Common"
end

local begin: () -> ()
local stamina: any = nil

local function finishRun(again: boolean?)
	runTrove:Clean()
	if hooks then
		hooks.stopRun(again == true)
	end
	if shell and shell.gui then
		shell.gui.DisplayOrder = 1
	end
end

local function hideHisResults()
	local gui = player.PlayerGui:FindFirstChild("Lane1RunOverlay")
	if gui then
		-- his keyboard hint names keys, and phones play too; he sets it visible again, so keep it down
		for _, d in gui:GetDescendants() do
			if d:IsA("TextLabel") and string.find(d.Text, "Space", 1, true) then
				d.Visible = false
				runTrove:Connect(d:GetPropertyChangedSignal("Visible"), function()
					d.Visible = false
				end)
				runTrove:Connect(d:GetPropertyChangedSignal("Text"), function()
					d.Visible = false
				end)
			end
		end
		local card = gui:FindFirstChild("Results")
		if card and card:IsA("GuiObject") then
			card.Visible = false
		end
		runTrove:Connect(gui.ChildAdded, function(child: Instance)
			if child.Name == "Results" and child:IsA("GuiObject") then
				child.Visible = false
			end
		end)
	end
end

local function watchRun(run: any)
	hideHisResults()
	local shown = false
	runTrove:Connect(RunService.Heartbeat, function()
		local state = run:getDebugState()
		if state.mode == "Ended" and not shown then
			shown = true
			-- his card appears 0.8 s after the crash; ours takes that moment too
			task.delay(0.8, function()
				if phase ~= "run" or run:getDebugState().mode ~= "Ended" then
					return
				end
				local m = run:getDebugState()
				local cars = {}
				for _, title in m.claimed do
					table.insert(cars, { name = title, rarity = rarityOf(title), isNew = true })
				end
				local metres = m.metres
				local isBest = metres > bestMetres
				bestMetres = math.max(bestMetres, metres)
				-- PREVIEW: the real payout is Lane 2's
				local cash = math.floor((metres * 1.5 + m.hops * 10 + #cars * 250) / 10) * 10
				local store = shell.store
				store:set("cash", (store:get().cash or 0) + cash)
				if shell.gui then
					shell.gui.DisplayOrder = 20
				end
				panel("runResults"):show({
					metres = metres,
					best = bestMetres,
					isBest = isBest,
					cars = cars,
					cash = cash,
					revives = m.revives,
					outOfBolts = stamina ~= nil and stamina:isOut(),
				})
			end)
		elseif state.mode ~= "Ended" and shown then
			shown = false
			local r = panel("runResults")
			if r:isOpen() then
				r:hide()
			end
		end
	end)
end

begin = function()
	setPhase("run")
	wipe(nil, function()
		local h = hooks
		if not h then
			return
		end
		local pad = pads[world]
		if pad then
			pad:setLive(false)
			pad.folder.Parent = nil
		end
		setLight(world)
		capZoom(false)
		quietHud(false)
		local run = h.startRun(world)
		runTrove:Add(RunCamera.attach(), "destroy")
		stamina = runTrove:Add(
			RunStamina.attach(run, { max = if isTutorial() then RunStamina.TutorialMax else nil }),
			"destroy"
		)
		attachTrail()
		watchRun(run)
	end)
end

-- START: the gantry's lights go red, red, red, green, a beep each, and the run begins on green. Reduce Motion keeps the view where it
-- is and the lights steady: nothing flashes or swings.
local function countdown()
	local pad = pads[world]
	if not pad then
		begin()
		return
	end
	setPhase("launching")
	local r = root()
	if r then
		r.Anchored = true
	end
	local cam = Workspace.CurrentCamera
	local calm = Motion.reduced()
	if cam and not calm then
		cam.CameraType = Enum.CameraType.Scriptable
		cam.CFrame = pad.gantryView
	end
	task.spawn(function()
		for i = 1, 3 do
			pad:setLight(i, LIGHT_RED)
			Sounds.startLight(false)
			task.wait(LIGHT_SECONDS)
		end
		pad:setLight(4, LIGHT_GREEN)
		Sounds.startLight(true)
		task.wait(0.2)
		lifeTrove:Clean()
		for i = 1, 4 do
			pad:setLight(i, nil)
		end
		if cam then
			cam.CameraType = Enum.CameraType.Custom
		end
		if r then
			r.Anchored = false
		end
		begin()
	end)
end

-- RETRY goes straight back into a run: the point of retry is speed, and the pad has been seen.
local function retry()
	finishRun(true)
	begin()
end

-- One-time hints, later and gentle: never a block, once a session at most (Adam's decision 5).
local homeRuns = 0
local HINT_SECONDS = 12
local function laterHints()
	homeRuns += 1
	local hud = shell and shell.hud
	if not hud then
		return
	end
	local Strings = (require :: any)(script.Parent.Tutorial.TutorialStrings)
	if homeRuns == 1 then
		hud:setGoal({
			title = Strings.get("later.upgrade.title"),
			subtitle = Strings.get("later.upgrade.line"),
			icon = "Raceway",
			seconds = HINT_SECONDS,
		})
	elseif homeRuns == 3 then
		hud:setGoal({
			title = Strings.get("later.shop.title"),
			subtitle = Strings.get("later.shop.line"),
			icon = "Garage",
			seconds = HINT_SECONDS,
			onActivate = function()
				shell.customizeAt("Trails")
				hud:setGoal(nil)
			end,
		})
	end
end

local function home()
	finishRun()
	setPhase("leaving")
	padTrove:Clean()
	task.spawn(function()
		wipe(nil, function()
			setLight(nil)
			if returnTo then
				moveTo(returnTo)
			end
			local pad = pads[world]
			if pad then
				pad.folder.Parent = nil
			end
		end)
		task.wait(2)
		setPhase("island")
		pcall(laterHints)
	end)
end

function LaunchPad.attachShell(s: any)
	shell = s
	unbindKey = RunCamera.bindKey()
	-- "Get more spots" on the Raceway's parking panel opens the Shop at the passes
	pcall(function()
		local ShopPanel = (require :: any)(script.Parent.Parent.Home.Island.Speedway.ShopPanel)
		ShopPanel.onMoreSpots = function()
			s.shopAt("Passes")
		end
	end)
	s:mountPanel("launchCard", { "Screens", "LaunchCard" }, "Overlay", {
		onStart = function()
			padTrove:Clean()
			countdown()
		end,
		hops = RunStamina.Max,
		onChangeCar = function()
			panel("carStall"):open()
		end,
		onChangeTrail = function()
			panel("launchStyle"):open(nil, { title = "TRAILS", tabs = { "Trails" }, tab = "Trails" })
		end,
	})
	s:mountPanel("carStall", { "Screens", "CarStall" }, "Modal", {})
	s:mountPanel("launchStyle", { "Screens", "StuntCustomize" }, "Modal", {
		onBuy = function(_id: string, title: string, _art: string?)
			s.hud:notify(title .. ": coming soon!", "Trail")
		end,
		onViewShop = function()
			s.shopAt("Cash")
		end,
	})
	s:mountPanel("runResults", { "Screens", "RunResults" }, "Overlay", {
		onRetry = retry,
		onHome = home,
		onRevive = function()
			local h = hooks
			if h and (h :: any).revive then
				(h :: any).revive()
				if stamina then
					stamina:refill(RunStamina.ReviveRefill)
				end
			end
		end,
		respawnRobux = Catalog.RespawnRobux,
		onBuyRespawn = function()
			print("[LaunchPad] Robux respawn is a PREVIEW: nothing was charged")
		end,
		onEarnFaster = function()
			home()
			s.shopAt("Passes")
		end,
	})
end

-- A locked portal: Coach Roxy says what it needs (PREVIEW numbers until the unlock rules are real). Once per visit to the portal.
local lockedOpen: any = nil
local LOCK_PRESET: { [string]: string } = { DustyHighway = "DustyLocked", SummitPass = "SummitLocked" }

function LaunchPad.lockedPortal(name: string)
	if lockedOpen and lockedOpen:isOpen() then
		return
	end
	local Dialogue = (require :: any)(Prototype.Screens.DialogueCard)
	local Fixtures = (require :: any)(Prototype.SupportFixtures.DialogueFixtures)
	local spec = Fixtures.preset(LOCK_PRESET[name] or "Unknown")
	local layer = shell and shell.screen.safe:FindFirstChild("ModalLayer")
	if spec and layer and not Dialogue.isSuppressed(spec.key) then
		lockedOpen = Dialogue.show(layer, spec)
	end
end

function LaunchPad.lockedAway()
	pcall(function()
		local Dialogue = (require :: any)(Prototype.Screens.DialogueCard)
		for place in LOCK_PRESET do
			local Fixtures = (require :: any)(Prototype.SupportFixtures.DialogueFixtures)
			local spec = Fixtures.preset(LOCK_PRESET[place])
			if spec then
				Dialogue.clearSuppression(spec.key)
			end
		end
	end)
end

-- The character was replaced in the middle of something: back to the island's normal state.
function LaunchPad.reset()
	padTrove:Clean()
	lifeTrove:Clean()
	runTrove:Clean()
	setLight(nil)
	capZoom(false)
	phase = "island"
end

function LaunchPad.destroy()
	if unbindKey then
		unbindKey()
		unbindKey = nil
	end
end

return LaunchPad
