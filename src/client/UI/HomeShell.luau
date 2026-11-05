--!strict
-- HomeShell: the whole Lane 3 home UI in one call, for a real place rather than the HUD playground (Round 2 N13). It mounts
-- the HUD, the tutorial, the Shop and the panels on one virtual screen, puts every pop-up through the one ModalQueue, and
-- runs the join flow. It reads nothing and saves nothing by itself: what a place knows comes in through `options`, and
-- whatever is not supplied stays a labelled PREVIEW fixture (Store's fixture Cash, Garage counts, Missions, Welcome back).
--
--   local shell = HomeShell.start({ joinMode = "new", isRunning = function() ... end, onLog = print })
--   shell:runStarted()   shell:runEnded()   shell:destroy()
--
-- Join flow (N13-01a). `joinMode` is the caller's: it knows whether this player has seen the tutorial. New: the tutorial first, everything else waits; after it,
-- the Update Log. Returning: the Update Log, then Welcome back. No offer opens by itself: the group reward is not real yet.

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local LiveData = require(ReplicatedStorage.Shared.UI.LiveData)
local Trove = require(ReplicatedStorage.Packages.Trove)
local CosmeticPreviewCatalog = require(ReplicatedStorage.Shared.UI.CosmeticPreviewCatalog)
local RobuxSeam = require(script.Parent:WaitForChild("RobuxSeam"))
local MissionFeed = require(script.Parent:WaitForChild("MissionFeed"))
local StuntCircuit = require(script.Parent:WaitForChild("StuntCircuit"))

local Prototype = script.Parent:WaitForChild("Prototype")
local ModalQueue = require(Prototype:WaitForChild("Home"):WaitForChild("ModalQueue"))
local Priority = require(Prototype:WaitForChild("Priority")) :: any
local Screen = require(Prototype:WaitForChild("Screen")) :: any
local Store = require(Prototype:WaitForChild("Store")) :: any
local GroupFixtures = require(Prototype:WaitForChild("SupportFixtures"):WaitForChild("GroupFixtures")) :: any
local StyleState = require(Prototype:WaitForChild("StyleState")) :: any

local HomeShell = {}
HomeShell.__index = HomeShell

export type Options = {
	joinMode: string?, -- "new" (default) or "returning"
	onLog: ((string) -> ())?,
	updates: { { icon: string, title: string, text: string } }?, -- what the Update Log lists
	updateVersion: string?,
	world: Instance?, -- the Folder the world pieces live in
	cashPreview: boolean?, -- true: the Cash shown is a fixture and says PREVIEW
	onTutorialDone: (() -> ())?, -- the tutorial was finished or skipped: the caller remembers it
}

-- What is in this beta now, and nothing else (N11-02a). Plans stay out of it.
HomeShell.Updates = {
	{ icon = "Hop", title = "Better hops", text = "Flip, land and ride!" },
	{ icon = "Shop", title = "Stamina Shop", text = "More bolts at every hub." },
	{ icon = "Garage", title = "Real cars on the road", text = "Catch the car you see." },
	{ icon = "Portal", title = "Worlds on the road", text = "Cities beside every run." },
}
HomeShell.UpdateVersion = "beta-4.0" -- the beta driving update (2026-11-05)

function HomeShell.start(options: Options?): any
	local o: Options = options or {}
	local self = setmetatable({}, HomeShell) :: any
	local trove = Trove.new()
	self.trove = trove
	self.joinMode = o.joinMode or "new"
	local player = Players.LocalPlayer
	local log = o.onLog or function(_text: string) end
	self.log = log

	local gui = trove:Add(Instance.new("ScreenGui"))
	gui.Name = "CarHopHome"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.ScreenInsets = Enum.ScreenInsets.None
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.DisplayOrder = 1 -- under the run's own screens: its results card is never covered
	gui.Parent = player:WaitForChild("PlayerGui")

	local screen = Screen.new(gui, "Live")
	local store = Store.new()
	-- Round 5 (L-01): with a live server, the Cash every home screen reads is the server's (LiveData), never a fixture and
	-- never client arithmetic. Without one, the Store's labelled fixture stays.
	trove:Add(task.spawn(function()
		local t0 = os.clock()
		while not LiveData.active() and os.clock() - t0 < 10 do
			task.wait(0.2)
		end
		if not LiveData.active() then
			return
		end
		local function sync()
			store:set("cash", LiveData.cash(player) or 0)
		end
		trove:Add(LiveData.changed(player, "cash", sync))
		sync()
	end))
	local priority = Priority.new()
	trove:Add(function()
		priority:destroy()
	end)
	local world = o.world
	if not world then
		local folder = trove:Add(Instance.new("Folder"))
		folder.Name = "CarHopHomeWorld"
		folder.Parent = Workspace
		world = folder
	end
	self.screen, self.store, self.world, self.gui = screen, store, world, gui

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
		Overlay = layer("OverlayLayer", 30),
		Modal = layer("ModalLayer", 40),
		Feedback = layer("FeedbackLayer", 50),
	}

	local components: { [string]: any } = {}
	self.components = components
	local function mount(key: string, path: { string }, layerName: string, opts: any?)
		local ok, result = pcall(function()
			local node: Instance = Prototype
			for _, step in path do
				node = node:WaitForChild(step, 5) :: Instance
			end
			local module = (require :: any)(node)
			return module.new({
				store = store,
				screen = screen,
				layer = (layers :: any)[layerName],
				world = world,
				priority = priority,
			}, opts)
		end)
		if ok then
			components[key] = result
			trove:Add(function()
				pcall(function()
					result:destroy()
				end)
			end)
		else
			warn("[HomeShell] " .. key .. " failed: " .. tostring(result))
		end
	end

	-- later panels (the Launch Pad's) mount the same way
	function self.mountPanel(_self: any, key: string, path: { string }, layerName: string, opts: any?)
		mount(key, path, layerName, opts)
	end

	-- the common art is fetched now, behind the loading screen; a failed file falls back by itself
	trove:Add(task.spawn(function()
		local GameIcons = (require :: any)(Prototype:WaitForChild("GameIcons"))
		local loaded, failed = GameIcons.preload(GameIcons.Common)
		log(("art preloaded: %d, failed: %d"):format(loaded, failed))
	end))

	local queue = ModalQueue.new({ onLog = log })
	self.queue = queue
	queue:block("loading")

	-- a panel opened through the queue: `done` fires when it closes (its own Closed signal, or when it hides)
	local function openPanel(key: string, done: () -> (), ...)
		local c = components[key]
		if not (c and c.open) then
			done()
			return
		end
		c:open(...)
		trove:Add(task.spawn(function()
			while true do
				task.wait(0.25)
				local open = true
				local state = c.isOpen
				if state then
					open = c:isOpen()
				end
				if not open then
					done()
					return
				end
			end
		end))
	end
	self.openPanel = openPanel

	local function userPanel(key: string, ...)
		local args = table.pack(...)
		queue:userOpen({
			key = key,
			class = "user",
			open = function(done)
				openPanel(key, done, table.unpack(args, 1, args.n))
			end,
		})
	end
	self.userPanel = userPanel

	mount("tutorial", { "Home", "TutorialBanner" }, "Hud")
	mount("route", { "Home", "TutorialRoute" }, "Hud")
	mount("settings", { "Home", "SettingsPanel" }, "Modal", {
		onReplayTutorial = function()
			local Tutorial = (require :: any)(Prototype.Parent:WaitForChild("Tutorial"))
			Tutorial.replay()
		end,
	})
	mount("customize", { "Screens", "StuntCustomize" }, "Modal", {
		-- Round 6 (R-03, R-04): a Robux trail goes through RobuxSeam; once the server says it is owned it is the
		-- player's and equipped (with no provider it says coming soon, as before)
		onBuy = function(id: string, title: string, _art: string?)
			RobuxSeam.buy(id, function(r: RobuxSeam.Result)
				local words = if r.status == "Purchased"
					then title .. " is yours!"
					elseif r.status == "Cancelled" then nil
					elseif r.status == "NotCreated" then title .. ": not set up on Roblox yet"
					elseif r.status == "Unavailable" then title .. ": not available for your account"
					elseif r.status == "Error" then title .. ": try later"
					else title .. ": coming soon!"
				if r.status == "Purchased" then
					StyleState.own(id)
					StyleState.equip("Trails", id)
				end
				if words and self.hud then
					self.hud:notify(words, "Trail")
				end
			end)
		end,
		onViewShop = function()
			components.customize:close()
			self.shopAt("Cash")
		end,
	})
	-- Round 6 (R-04): a Robux trail the server says this player owns (its Game Pass) is owned in the Garage too
	local function syncOwnedTrails()
		for _, item in CosmeticPreviewCatalog.itemsFor("Trails") do
			if item.robux and RobuxSeam.state(item.id) == "Owned" and not StyleState.get().ownership.owned[item.id] then
				StyleState.own(item.id)
			end
		end
	end
	RobuxSeam.Changed:Connect(syncOwnedTrails)
	task.defer(syncOwnedTrails)
	local function customizeView(tab: string): { [string]: any }
		return { title = "CUSTOMIZE", tabs = { "Paint", "Decals", "Wheels", "Trails" }, tab = tab }
	end
	self.customizeAt = function(tab: string)
		userPanel("customize", nil, customizeView(tab))
	end
	mount("garage", { "Screens", "GarageMock" }, "Overlay", {
		onCustomize = function()
			components.customize:open(nil, customizeView("Paint"))
		end,
		-- Round 5 (L-04): PARK opens YOUR RACEWAY with the car picked out (live server only; the preview keeps it disabled)
		onDrive = function(car: any)
			components.garage:close()
			self.openLineup(car.id)
		end,
		canPutOnRaceway = function(car: any): (boolean, string?)
			if not LiveData.hasCars(player) then
				return false, "Parking works in the beta place."
			elseif table.find(LiveData.lineup(player), car.id) then
				return false, "Already parked at your Raceway."
			end
			return true, nil
		end,
	})
	-- Round 5: with a live server the Garage lists the save's own cars, editions and copies (the server's attribute)
	trove:Add(task.spawn(function()
		local t0 = os.clock()
		while not LiveData.hasCars(player) and os.clock() - t0 < 15 do
			task.wait(0.25)
		end
		local garage = components.garage
		if not (garage and LiveData.hasCars(player)) then
			return
		end
		local Fixtures = (require :: any)(Prototype.Fixtures)
		local RosterFixtures = require(ReplicatedStorage.Shared.UI.RosterFixtures)
		local function sync()
			local owned = LiveData.cars(player)
			local cars = {}
			for _, car in RosterFixtures.Cars do
				table.insert(cars, Fixtures.carRef(car, owned))
			end
			garage:setSource(cars, nil, nil)
		end
		trove:Add(LiveData.changed(player, "cars", sync))
		trove:Add(LiveData.changed(player, "lineup", sync))
		sync()
	end))
	-- the Garage building on the island
	trove:Connect(ProximityPromptService.PromptTriggered, function(prompt: ProximityPrompt, who: Player)
		if prompt.Name == "OpenGarage" and who == player then
			self.customizeAt("Paint")
		end
	end)
	mount("shop", { "Screens", "ShopMock" }, "Overlay", {
		onFreeReward = function()
			userPanel("groupReward")
		end,
	})
	-- Round 6 (G-01): the live feed (MissionFeed) drives the panel when the server publishes missions; with none, the
	-- PREVIEW fixtures and their 0.35 s preview claim stay as before
	mount("missions", { "Screens", "MissionsPanel" }, "Overlay", {
		onClaim = function(id: string)
			if not MissionFeed.claim(id) then
				task.delay(0.35, function()
					local panel = components.missions
					if panel then
						panel:resolveClaim(id, "Success")
					end
				end)
			end
		end,
	})
	if components.missions then
		task.spawn(function()
			-- the server's folder and the attribute may arrive a moment after the shell is built
			for _ = 1, 40 do
				if LiveData.active() and Players.LocalPlayer:GetAttribute(MissionFeed.Attribute) ~= nil then
					break
				end
				task.wait(0.25)
			end
			local detach = MissionFeed.attach(components.missions)
			if detach then
				trove:Add(detach)
			end
		end)
	end
	-- nothing joins and nothing is rewarded here yet, so the card must never say "You're in!": until the real join and reward
	-- exist it answers "try later", and it is never offered by itself
	mount("groupReward", { "Screens", "GroupRewardPopup" }, "Modal", {
		gateway = GroupFixtures.fakeGateway({ outcomes = { "None" } }),
	})
	mount("welcome", { "Screens", "WelcomeBackMock" }, "Overlay", {
		-- the coins of CLAIM fly to the Cash counter: a look only, the amount comes from the server later
		cashTarget = function(): Vector2?
			local plus = self.hud and self.hud:getButton("CashPlus")
			return if plus and plus.Visible then plus.AbsolutePosition else nil
		end,
	})
	mount("stuntBoard", { "Screens", "StuntLeaderboard" }, "Overlay", {})
	-- Round 6 (C-02, C-03): the Stunt Circuit's gate prompt, pre-race card, race HUD, results and this server's board
	local okStunt, stuntCleanup = pcall(StuntCircuit.attach, self, mount, components, userPanel)
	if okStunt then
		trove:Add(stuntCleanup)
	else
		warn("[HomeShell] Stunt Circuit failed: " .. tostring(stuntCleanup))
	end
	-- Round 6 (V-03): while a panel or a modal is open, the HUD layer (buttons, Cash, tutorial pill) steps back, so nothing
	-- shows through or sits on a panel's tabs (two reviewers' first fix). WelcomeCoins is an effect that is always shown.
	local function syncHud()
		local open = false
		for _, front in { layers.Overlay, layers.Modal } do
			for _, child in front:GetChildren() do
				if child:IsA("GuiObject") and child.Visible and child.Name ~= "WelcomeCoins" then
					open = true
				end
			end
		end
		layers.Hud.Visible = not open
	end
	for _, front in { layers.Overlay, layers.Modal } do
		local function watch(child: Instance)
			if child:IsA("GuiObject") then
				trove:Connect(child:GetPropertyChangedSignal("Visible"), syncHud)
			end
		end
		for _, child in front:GetChildren() do
			watch(child)
		end
		trove:Connect(front.ChildAdded, function(child: Instance)
			watch(child)
			syncHud()
		end)
	end
	syncHud()
	-- Round 5 (L-04): YOUR RACEWAY, the Lineup panel (from the parking sign and the Garage's PARK)
	mount("lineup", { "Screens", "LineupPanel" }, "Overlay", {
		onMoreSpots = function()
			-- the Raceway's own parking panel while spots are for sale; at the top, the Shop's Expanded Paddock
			local ShopPanel = (require :: any)(Prototype.Parent.Parent.Home.Island.Speedway.ShopPanel)
			if ShopPanel.openHome and ShopPanel.openHome("parking") then
				return
			end
			if ShopPanel.onMoreSpots then
				ShopPanel.onMoreSpots()
			end
		end,
	})
	self.openLineup = function(highlight: string?)
		userPanel("lineup", { highlight = highlight })
	end

	local function shopAt(section: string?)
		userPanel("shop")
		local shop = components.shop
		if section and shop and shop.openSection then
			shop:openSection(section)
		end
	end
	self.shopAt = shopAt

	local ok, hud = pcall(function()
		local HomeHud = (require :: any)(Prototype.Home.HomeHud)
		return HomeHud.mount(layers.Hud, {
			getCash = function(): number?
				return store:get().cash
			end,

			onShop = function()
				shopAt(nil)
			end,
			onShopCash = function()
				shopAt("Cash")
			end,
			onGarage = function()
				userPanel("garage")
			end,
			onMissions = function()
				userPanel("missions")
			end,
			onSettings = function()
				userPanel("settings", self.hud and self.hud:getButton("Settings") or nil)
			end,
			onLeaderboard = function()
				userPanel("stuntBoard")
			end,
			onVip = function()
				shopAt("Passes")
			end,
			preview = { cash = o.cashPreview ~= false },
		}, { screen = screen, world = world })
	end)
	if ok then
		self.hud = hud
		components.homeHud = hud
		trove:Add(function()
			hud:destroy()
		end)
		if components.tutorial and components.tutorial.setHomeFrame then
			hud:attachBanner(components.tutorial)
		end
		trove:Connect(store.Changed, function(key: string)
			if key == "tutorial" then
				hud:setTutorialActive(store:get().tutorial ~= nil)
			end
		end)
	else
		warn("[HomeShell] HomeHud failed: " .. tostring(hud))
	end

	-- the join flow starts when the loading screen is gone
	trove:Add(task.spawn(function()
		local t0 = os.clock()
		while player:GetAttribute("Lane3LoadingDone") ~= true and os.clock() - t0 < 20 do
			task.wait(0.1)
		end
		queue:unblock("loading")
		self:_join(o)
	end))
	return self
end

function HomeShell._updateLog(self: any, o: Options)
	local trove = self.trove
	local queue = self.queue
	queue:push({
		key = "UpdateLog",
		version = o.updateVersion or HomeShell.UpdateVersion,
		class = "info",
		open = function(done)
			local ok, err = pcall(function()
				local UpdateLog = (require :: any)(Prototype.Screens.UpdateLog)
				local panel = UpdateLog.show(self.screen.safe, {
					version = o.updateVersion or HomeShell.UpdateVersion,
					entries = o.updates or HomeShell.Updates,
				}, { onClose = done })
				if panel then
					trove:Add(function()
						pcall(function()
							panel:close()
						end)
					end)
				else
					done()
				end
			end)
			if not ok then
				warn("[HomeShell] UpdateLog failed: " .. tostring(err))
				done()
			end
		end,
	})
end

function HomeShell._join(self: any, o: Options)
	if self.joinMode == "returning" then
		self:_updateLog(o)
		self.queue:push({
			key = "WelcomeBack",
			class = "info",
			open = function(done)
				-- Round 5 (L-06): with a live server the card shows the credit the server ALREADY added on load (and the time it
				-- covers); COLLECT only acknowledges it. Nothing earned (under a minute, or a rejoin in the same server): no card.
				local player = Players.LocalPlayer
				if LiveData.active() then
					local t0 = os.clock()
					while player:GetAttribute(LiveData.Attributes.welcomeAmount) == nil and os.clock() - t0 < 3 do
						task.wait(0.1)
					end
					local amount = player:GetAttribute(LiveData.Attributes.welcomeAmount)
					local away = player:GetAttribute(LiveData.Attributes.welcomeSeconds)
					local welcome = self.components.welcome
					if type(amount) ~= "number" or amount <= 0 or not welcome then
						done()
						return
					end
					local cars = {}
					for i, id in LiveData.lineup(player) do
						if i > 3 then
							break
						end
						table.insert(cars, {
							id = id,
							name = id,
							family = "Compact",
							paint = Color3.fromHSV((i * 0.27) % 1, 0.6, 0.9),
						})
					end
					local seconds = if type(away) == "number" then away else 0
					welcome:setData({
						source = "server (PREVIEW rate)",
						status = "Ready",
						earned = amount,
						awaySeconds = seconds,
						cappedSeconds = math.min(seconds, 8 * 3600),
						lineup = cars,
					})
				end
				self.openPanel("welcome", done)
			end,
		})
		return
	end
	local Tutorial = (require :: any)(Prototype.Parent:WaitForChild("Tutorial"))
	self.queue:block("tutorial")
	local stopped = false
	self.trove:Add(Tutorial.onEnded(function(how: string)
		if stopped then
			return
		end
		stopped = true
		self.log("tutorial " .. how)
		if how ~= "Stopped" and o.onTutorialDone then
			o.onTutorialDone()
		end
		self.queue:unblock("tutorial")
		self:_updateLog(o)
	end))
	local c = self.components
	-- Round 5 (L-04): the Park step with a live server. Its ground arrows lead to the parking sign, whose Park Cars prompt opens
	-- YOUR RACEWAY with the tutorial run's car picked out. A save whose only car (the Loaner) is already parked has nothing to
	-- park: the step is told so at once. After parking, the first REAL payout on the home plot says "Cars pay you every lap!".
	if LiveData.active() then
		local player = Players.LocalPlayer
		local parkSeen, lapToldAt = false, nil :: number?
		self.trove:Connect(self.store.Changed, function(key: string)
			if key ~= "tutorial" then
				return
			end
			local controller = Tutorial.getController()
			local step = controller and controller._step
			if step and step.key == "Park" and controller._phase == "Active" and not parkSeen then
				parkSeen = true
				local free = false
				for id in LiveData.cars(player) do
					if not table.find(LiveData.lineup(player), id) then
						free = true
					end
				end
				if not free then
					task.delay(1.5, function()
						Tutorial.emitIsland("CarParked", { already = true })
					end)
				end
			end
		end)
		self.trove:Add(LiveData.changed(player, "lineup", function()
			if parkSeen and lapToldAt == nil then
				lapToldAt = os.clock()
			end
		end))
		local lapPaid = LiveData.remote(LiveData.Remotes.LapPaid)
		if lapPaid then
			self.trove:Connect(lapPaid.OnClientEvent, function(plotIndex: any)
				if lapToldAt and plotIndex == player:GetAttribute(LiveData.Attributes.homePlot) and self.hud then
					lapToldAt = nil
					parkSeen = false
					self.hud:notify("Cars pay you every lap!", "Cash")
				end
			end)
		end
	end
	Tutorial.start({
		store = self.store,
		screen = self.screen,
		layer = self.screen.safe:FindFirstChild("HudLayer"),
		world = self.world,
	}, {
		mode = "Real",
		banner = c.tutorial,
		route = c.route,
		menu = self.hud,
		isShopOpen = function()
			local shop = c.shop
			return shop ~= nil and shop.isOpen ~= nil and shop:isOpen()
		end,
	})
end

-- The caller's run is starting: home prompts go, the HUD steps aside.
function HomeShell.runStarted(self: any)
	self.running = true
	self.queue:block("run")
	self.queue:clearHome("run started")
	if self.hud then
		self.hud:setVisible(false)
	end
	local c = self.components.route
	if c and c.setVisible then
		c:setVisible(false)
	end
end

-- The caller's run has ended and the player is home. `earnFaster` shows the Results "Earn faster" way into the Shop.
function HomeShell.runEnded(self: any, earnFaster: boolean?)
	self.running = false
	self.queue:unblock("run")
	local route = self.components.route
	if route and route.setVisible then
		route:setVisible(true)
	end
	if self.hud then
		self.hud:setVisible(true)
		if earnFaster then
			self.hud:setGoal({
				title = "EARN FASTER",
				subtitle = "See Double Lap Pay in the Shop",
				icon = "DoubleLapPay",
				onActivate = function()
					self.userPanel("shop")
					local shop = self.components.shop
					if shop and shop.openDoubleLapPay then
						shop:openDoubleLapPay()
					end
					self.hud:setGoal(nil)
				end,
			})
		end
	end
end

function HomeShell.destroy(self: any)
	self.queue:destroy()
	self.trove:Destroy()
end

return HomeShell
