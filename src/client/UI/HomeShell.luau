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
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Trove = require(ReplicatedStorage.Packages.Trove)

local Prototype = script.Parent:WaitForChild("Prototype")
local ModalQueue = require(Prototype:WaitForChild("Home"):WaitForChild("ModalQueue"))
local Priority = require(Prototype:WaitForChild("Priority")) :: any
local Screen = require(Prototype:WaitForChild("Screen")) :: any
local Store = require(Prototype:WaitForChild("Store")) :: any
local GroupFixtures = require(Prototype:WaitForChild("SupportFixtures"):WaitForChild("GroupFixtures")) :: any

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
	{ icon = "Raceway", title = "A cleaner Raceway", text = "Roads join up. Real loop!" },
	{ icon = "Shop", title = "A brighter Shop", text = "Nothing to buy yet." },
	{ icon = "Garage", title = "Your Garage", text = "All your cars, by World." },
	{ icon = "Portal", title = "Worlds", text = "Beside your run now." },
}
HomeShell.UpdateVersion = "beta-2.2"

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
	mount("garage", { "Screens", "GarageMock" }, "Overlay", {})
	mount("shop", { "Screens", "ShopMock" }, "Overlay", {
		onFreeReward = function()
			userPanel("groupReward")
		end,
	})
	mount("missions", { "Screens", "MissionsPanel" }, "Overlay", {})
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
