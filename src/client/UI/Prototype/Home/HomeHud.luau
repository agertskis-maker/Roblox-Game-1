--!strict
-- Home/HomeHud: the Round 2 Home HUD, composed (Lane 3, N7-01 .. N7-05 and N8-05, 2026-11-02; references IMG-09 and
-- the two HUD videos). ONE call mounts everything the island needs: the left tiles, Cash with its rate and car count, the
-- right-hand round buttons, the notification and goal pills, the in-world pieces, and the returning-player guide.
--
--   local hud = HomeHud.mount(parent, adapters, options?) -> Hud
--
--   parent    a ScreenGui, or a Frame that covers the safe area (below Roblox's own top bar)
--   adapters  everything the HUD may show comes through these; it owns no game data and decides nothing:
--     getCash         () -> number?          the server-backed balance; nil = "Loading" (then "Unavailable"), never 0
--     getCashRate     (() -> number?)?       Cash per second, ONLY when its computation is approved; absent or nil = no rate
--     getOwned        (() -> (number?, number?))?   unique cars owned, and the loaded catalog size (the denominator)
--     onShop, onGarage, onMissions, onSettings   (() -> ())   the tiles and the Settings button
--     onShopCash      () -> ()               the green "+" next to Cash: open the Shop's Cash section (shop:openSection("Cash"))
--     onLeaderboard, onVip, onFreeGift   (() -> ())?     a button exists only when its callback does
--     getShopUnread (() -> boolean)?, getGarageUnseen / getMissionsClaimable (() -> number?)?, getFreeGiftReady (() -> boolean)?
--                     real unread / claimable states: a red badge shows only while the answer is true or above zero
--     getTimer        (() -> { label: string?, seconds: number }?)?   a REAL timer for the bottom-right corner; absent = empty
--     preview         { cash: boolean?, rate: boolean?, owned: boolean? }?   marks fixtures: a small "PREVIEW" beside the value
--   options   { screen: Screen?, world: Folder? }   the preview's virtual Screen (the playground) and the Folder the
--             in-world pieces live in; both nil in the real game (the live viewport and a Folder in Workspace)
--
--   hud:notify(text, icon?)         one event pill at the top centre ("RACEWAY LEVEL 5!", "NEW CAR!"); icon = a painter name
--   hud:setGoal(spec?)              the goal pill { title, subtitle?, progress? (0..1), icon?, onActivate? }; nil clears it
--   hud:setTutorialActive(on)       the tutorial owns the top-centre spot: the pills and the return guide slide away
--   hud:setVisible(on)              hide / show everything (a run, a full-screen card)
--   hud:destroy()                   everything is cleaned through one Trove
--   hud:refresh()                   read the adapters now (it also reads them five times a second by itself)
--   hud:attachBanner(banner?)       tells a Home/TutorialBanner where the top centre is, so it sits between the side columns
--   hud:startReturnGuide(options) -> ReturnGuide    the returning-player trail and goal pill (Home/ReturnGuide)
--   hud.world                       Home/HomeWorld: setTrail, setBubble (UNLOCK! / OPEN!), floatCash, setRate, setCircle ...
--   hud:getButton(name) -> GuiObject?   "Shop" | "Garage" | "Missions" | "Settings" | a shortcut id | "CashPlus"
--   hud:getLayout() -> Plan   hud:getDebugState()
--
-- Layout is HomeLayout's: phone landscape first (844 x 390, 667 x 375), then tablet and desktop; it reflows (tile shape,
-- how many round buttons, Cash beside the thumbstick zone) instead of shrinking, keeps every control 48 px or more after the
-- UIScale, and stays clear of the thumbstick and jump zones. Nothing here buys, grants, saves or sends a remote.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Arcade = require(script.Parent.Parent.Arcade)
local HomeCash = require(script.Parent.HomeCash)
local HomeLayout = require(script.Parent.HomeLayout)
local HomeNav = require(script.Parent.HomeNav)
local HomePills = require(script.Parent.HomePills)
local HomeShortcuts = require(script.Parent.HomeShortcuts)
local HomeView = require(script.Parent.HomeView)
local HomeWorld = require(script.Parent.HomeWorld)
local IconArt = require(script.Parent.IconArt)
local Motion = require(script.Parent.Parent.Motion)
local ReturnGuide = require(script.Parent.ReturnGuide)
local Trove = require(ReplicatedStorage.Packages.Trove)

local make = Arcade.make

local POLL_SECONDS = 0.2

export type Adapters = {
	getCash: (() -> number?)?,
	getCashRate: (() -> number?)?,
	getOwned: (() -> (number?, number?))?,
	onShop: (() -> ())?,
	onShopCash: (() -> ())?,
	onGarage: (() -> ())?,
	onMissions: (() -> ())?,
	onSettings: (() -> ())?,
	onLeaderboard: (() -> ())?,
	onVip: (() -> ())?,
	onFreeGift: (() -> ())?,
	getShopUnread: (() -> boolean)?,
	getGarageUnseen: (() -> number?)?,
	getMissionsClaimable: (() -> number?)?,
	getFreeGiftReady: (() -> boolean)?,
	getTimer: (() -> { label: string?, seconds: number }?)?,
	preview: { cash: boolean?, rate: boolean?, owned: boolean? }?,
}

export type Options = { screen: any?, world: Folder? }

export type Hud = {
	world: HomeWorld.World,
	notify: (self: Hud, text: string, icon: string?) -> (),
	setGoal: (self: Hud, spec: HomePills.GoalSpec?) -> (),
	setTutorialActive: (self: Hud, on: boolean) -> (),
	setVisible: (self: Hud, on: boolean) -> (),
	destroy: (self: Hud) -> (),
	refresh: (self: Hud) -> (),
	attachBanner: (self: Hud, banner: any?) -> (),
	startReturnGuide: (self: Hud, options: ReturnGuide.Options) -> ReturnGuide.Guide,
	getButton: (self: Hud, name: string) -> GuiObject?,
	getLayout: (self: Hud) -> HomeLayout.Plan,
	getDebugState: (self: Hud) -> { [string]: any },
}

local HomeHud = {}
HomeHud.__index = HomeHud

-- A getter that may be absent or may throw: nil either way.
local function safe(fn: (() -> any)?): any
	if fn == nil then
		return nil
	end
	local ok, value = pcall(fn)
	if ok then
		return value
	end
	return nil
end

local function timeText(seconds: number): string
	local s = math.max(0, math.floor(seconds))
	if s >= 3600 then
		return string.format("%dh %02dm", s // 3600, (s % 3600) // 60)
	elseif s >= 60 then
		return string.format("%dm %02ds", s // 60, s % 60)
	end
	return string.format("%ds", s)
end
HomeHud.timeText = timeText

function HomeHud.mount(parent: GuiBase2d, adapters: Adapters, options: Options?): Hud
	local self = setmetatable({}, HomeHud) :: any
	local opts: Options = options or { screen = nil, world = nil }
	local trove = Trove.new()
	self._trove = trove
	self._adapters = adapters
	self._destroyed = false
	self._visible = true
	self._tutorial = false
	self._banner = nil :: any
	self._guides = {} :: { any }
	self._plan = nil :: HomeLayout.Plan?
	self._cache = {} :: { [string]: any }
	self._entryKey = ""
	self._timerOn = false

	local view = HomeView.new(parent, { screen = opts.screen })
	trove:Add(function()
		view:destroy()
	end)
	self._view = view

	local root = trove:Add(make("Frame", {
		Name = "HomeHud",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 4,
		Parent = parent,
	}))
	self._root = root

	self._nav = HomeNav.new(root, {
		onShop = adapters.onShop,
		onGarage = adapters.onGarage,
		onMissions = adapters.onMissions,
	})
	trove:Add(function()
		self._nav:destroy()
	end)
	self._cash = HomeCash.new(root, adapters :: any)
	trove:Add(function()
		self._cash:destroy()
	end)
	self._shortcuts = HomeShortcuts.new(root)
	trove:Add(function()
		self._shortcuts:destroy()
	end)
	self._pills = HomePills.new(root)
	trove:Add(function()
		self._pills:destroy()
	end)
	self.world = HomeWorld.new({ folder = opts.world, view = view })
	trove:Add(function()
		self.world:destroy()
	end)
	self:_buildTimer()

	-- re-layout whenever the screen changes; read the adapters a few times a second
	trove:Add(view.Changed:Connect(function()
		self:_place()
	end))
	self:_syncEntries()
	self:refresh()
	self:_place()
	local poll = task.spawn(function()
		while not self._destroyed do
			task.wait(POLL_SECONDS)
			if not self._destroyed then
				self:refresh()
			end
		end
	end)
	trove:Add(function()
		pcall(task.cancel, poll)
	end)
	return self :: Hud
end

-- THE TIMER (bottom right, only a real one) -------------------------------------------------------------------------

function HomeHud._buildTimer(self: any)
	local holder = make("Frame", {
		Name = "HomeTimer",
		AnchorPoint = Vector2.new(1, 1),
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(190, 40),
		Visible = false,
		ZIndex = 4,
		Parent = self._root,
	})
	pcall(function()
		(holder :: any).Interactable = false
	end)
	self._timerScale = make("UIScale", { Name = "HudScale", Scale = 1, Parent = holder })
	make("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Right,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 6),
		Parent = holder,
	})
	local icon = make("Frame", {
		Name = "Icon",
		LayoutOrder = 1,
		Size = UDim2.fromOffset(34, 34),
		BackgroundTransparency = 1,
		ZIndex = 5,
		Parent = holder,
	})
	IconArt.draw(icon, { "Moon", "Timer", "Flag" })
	local text = Arcade.text(holder, {
		text = "",
		role = "Timer",
		name = "Timer",
		italic = true,
		xAlign = Enum.TextXAlignment.Right,
		autoWidth = true,
		z = 6,
	})
	text.LayoutOrder = 2
	self._timer = holder
	self._timerText = text
end

function HomeHud._syncTimer(self: any)
	local info: { label: string?, seconds: number }? = safe(self._adapters.getTimer)
	local on = type(info) == "table" and type((info :: any).seconds) == "number"
	if on ~= self._timerOn then
		self._timerOn = on
		self._timer.Visible = on and self._visible
		if self._plan then
			self:_place()
		end
	end
	if on and info then
		local label = if info.label and info.label ~= "" then info.label .. " " else ""
		local text = label .. "in " .. timeText(info.seconds)
		if self._timerText.Text ~= text then
			self._timerText.Text = text
		end
	end
end

-- THE ROUND BUTTONS -------------------------------------------------------------------------------------------------

-- The entries the right-hand column holds right now: only what the game really has.
function HomeHud._syncEntries(self: any)
	local a: Adapters = self._adapters
	local entries: { HomeShortcuts.Entry } = {}
	local claimable = safe(a.getMissionsClaimable)
	local giftReady = safe(a.getFreeGiftReady) == true
	table.insert(entries, {
		id = "Settings",
		label = "Settings",
		icons = { "Settings" },
		fill = "Garage",
		priority = 1,
		order = 1,
		onActivate = a.onSettings,
	})
	if a.onLeaderboard then
		table.insert(entries, {
			id = "Leaderboard",
			label = "Leaderboard",
			icons = { "Leaderboard", "Trophy", "Medal" },
			fill = "Gold",
			priority = 5,
			order = 2,
			onActivate = a.onLeaderboard,
		})
	end
	-- the Missions rewards button: only while a reward really waits
	if a.onMissions and type(claimable) == "number" and claimable > 0 then
		table.insert(entries, {
			id = "Rewards",
			label = "Rewards",
			icons = { "Goals", "Trophy", "Medal" },
			fill = "Missions",
			priority = 3,
			order = 3,
			onActivate = a.onMissions,
			badge = claimable,
		})
	end
	if a.onVip then
		table.insert(entries, {
			id = "VIP",
			label = "VIP",
			icons = { "VipCrown", "Star" },
			fill = "Gold",
			priority = 6,
			order = 4,
			onActivate = a.onVip,
		})
	end
	if a.onFreeGift then
		table.insert(entries, {
			id = "FreeGift",
			label = "Free Gift",
			icons = { "Gift", "Star" },
			fill = "Green",
			priority = if giftReady then 2 else 7,
			order = 5,
			onActivate = a.onFreeGift,
			badge = if giftReady then "!" else nil,
		})
	end
	local ids: { string } = {}
	for _, e in entries do
		table.insert(ids, e.id .. (if e.priority == 2 then "*" else ""))
	end
	local key = table.concat(ids, ",")
	if key ~= self._entryKey then
		self._entryKey = key
		self._shortcuts:setEntries(entries)
	end
	-- badges that change without changing the set
	for _, e in entries do
		local cacheKey = "entry:" .. e.id
		if self._cache[cacheKey] ~= e.badge then
			self._cache[cacheKey] = e.badge
			self._shortcuts:setBadge(e.id, e.badge)
		end
	end
end

local function setIfChanged(self: any, key: string, value: any, apply: (any) -> ())
	if self._cache[key] ~= value then
		self._cache[key] = value
		apply(value)
	end
end

function HomeHud.refresh(self: any)
	if self._destroyed then
		return
	end
	local a: Adapters = self._adapters
	self._cash:refresh()
	local unread = safe(a.getShopUnread) == true
	setIfChanged(self, "Shop", unread, function(v: boolean)
		self._nav:setBadge("Shop", v)
	end)
	local garage = safe(a.getGarageUnseen)
	setIfChanged(self, "Garage", if type(garage) == "number" and garage > 0 then garage else false, function(v: any)
		self._nav:setBadge("Garage", if v == false then nil else v)
	end)
	local missions = safe(a.getMissionsClaimable)
	setIfChanged(
		self,
		"Missions",
		if type(missions) == "number" and missions > 0 then missions else false,
		function(v: any)
			self._nav:setBadge("Missions", if v == false then nil else v)
		end
	)
	self:_syncEntries()
	self:_syncTimer()
end

-- LAYOUT ------------------------------------------------------------------------------------------------------------

function HomeHud._place(self: any)
	if self._destroyed then
		return
	end
	local m = self._view:get()
	local size = HomeCash.blockSize()
	local plan = HomeLayout.plan(m, { cashW = size.X, cashH = size.Y, hasTimer = self._timerOn })
	self._plan = plan
	self._nav:place(plan.nav, m.scale)
	self._cash:place(plan.cash, m.scale)
	self._shortcuts:place(plan.shortcuts, m.scale)
	self._pills:place(plan.top, m.scale)
	local timer: Frame = self._timer
	self._timerScale.Scale = m.scale
	timer.Position = UDim2.fromOffset(plan.timer.right * m.scale, plan.timer.bottom * m.scale)
	self.world:layout()
	self:_pushBanner()
end

function HomeHud._pushBanner(self: any)
	local banner = self._banner
	local plan: HomeLayout.Plan? = self._plan
	if banner and plan then
		banner:setHomeFrame({ cx = plan.top.cx, y = plan.top.y, width = plan.top.width, compact = plan.top.compact })
	end
end

function HomeHud.attachBanner(self: any, banner: any?)
	local previous = self._banner
	if previous and previous ~= banner then
		previous:setHomeFrame(nil)
	end
	self._banner = banner
	self:_pushBanner()
end

-- THE PUBLIC SURFACE ------------------------------------------------------------------------------------------------

function HomeHud.notify(self: any, text: string, icon: string?)
	if self._tutorial then
		return -- the tutorial banner owns the top centre; an event is not queued behind it
	end
	self._pills:notify(text, icon)
end

function HomeHud.setGoal(self: any, spec: HomePills.GoalSpec?)
	self._pills:setGoal(spec)
end

function HomeHud.setTutorialActive(self: any, on: boolean)
	self._tutorial = on
	self._pills:setSuppressed(on)
	for _, guide in self._guides do
		guide:setSuppressed(on)
	end
end

function HomeHud.setVisible(self: any, on: boolean)
	self._visible = on
	self._root.Visible = on
	self._pills:setVisible(on)
	self.world:setVisible(on)
	self._shortcuts:setVisible(on)
	local timer: Frame = self._timer
	timer.Visible = on and self._timerOn
end

function HomeHud.startReturnGuide(self: any, options: ReturnGuide.Options): ReturnGuide.Guide
	local guide = ReturnGuide.new(self :: any, options)
	table.insert(self._guides, guide)
	if self._tutorial then
		guide:setSuppressed(true)
	end
	return guide
end

function HomeHud.getButton(self: any, name: string): GuiObject?
	if name == "CashPlus" then
		return self._cash:getPlusButton()
	end
	return self._nav:getButton(name) or self._shortcuts:getButton(name)
end

function HomeHud.getLayout(self: any): HomeLayout.Plan
	return self._plan :: HomeLayout.Plan
end

function HomeHud.getDebugState(self: any): { [string]: any }
	local plan: HomeLayout.Plan? = self._plan
	return {
		visible = self._visible,
		tutorialActive = self._tutorial,
		kind = if plan then plan.metrics.kind else nil,
		designSize = if plan then { w = plan.metrics.width, h = plan.metrics.height } else nil,
		scale = if plan then plan.metrics.scale else nil,
		navStyle = if plan then plan.nav.tile.style else nil,
		navTile = if plan then { w = plan.nav.tile.w, h = plan.nav.tile.h } else nil,
		cashPlacement = if plan then plan.cash.placement else nil,
		shortcutsCapacity = if plan then plan.shortcuts.capacity else nil,
		topWidth = if plan then plan.top.width else nil,
		reducedMotion = Motion.reduced(),
		nav = self._nav:getDebugState(),
		cash = self._cash:getDebugState(),
		shortcuts = self._shortcuts:getDebugState(),
		pills = self._pills:getDebugState(),
		world = self.world:getDebugState(),
		guides = (function(): { any }
			local out = {}
			for _, g in self._guides do
				table.insert(out, g:getDebugState())
			end
			return out
		end)(),
		cameraViewport = if Workspace.CurrentCamera then HomeView.vec(Workspace.CurrentCamera.ViewportSize) else nil,
	}
end

function HomeHud.destroy(self: any)
	if self._destroyed then
		return
	end
	self._destroyed = true
	-- guides first: they take their goal, trail and bubble off a HUD that is still alive
	for _, guide in table.clone(self._guides) do
		guide:destroy()
	end
	table.clear(self._guides)
	local banner = self._banner
	if banner then
		self._banner = nil
		banner:setHomeFrame(nil)
	end
	self._trove:Destroy()
end

return HomeHud
