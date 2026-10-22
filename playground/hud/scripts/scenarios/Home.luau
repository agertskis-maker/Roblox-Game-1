--!strict
-- PLAYGROUND ONLY (Lane 3 HUD rebuild preview, worker HH). Home HUD scenarios, driven by
-- synthetic fixtures through the preview store. Nothing here is a game rule; amounts, rates,
-- counts and timers are fixtures.
--
-- host = { store, api, wait(seconds), emit(kind, fields) -> boolean, runPatch(patch), car(id),
--          enterRun(), log(text) }
-- Components used (mount keys the lead adds): menu (Home/LeftMenu), stats (Home/StatsStack),
-- tutorial, toasts, settings, timers (Home/TimerStack). Every lookup is nil-safe.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")

local Prototype = Players.LocalPlayer
	:WaitForChild("PlayerScripts")
	:WaitForChild("Client")
	:WaitForChild("UI")
	:WaitForChild("Prototype")
local Fixtures = require(Prototype:WaitForChild("Fixtures")) :: any
local Motion = require(Prototype:WaitForChild("Motion"))
local Sounds = require(Prototype:WaitForChild("Sounds"))
local Home = Prototype:WaitForChild("Home")
local MusicSetting = require(Home:WaitForChild("MusicSetting"))

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Format = require(ReplicatedStorage.Shared.UI.Format)

local function comp(host: any, key: string): any
	return host.api and host.api.components and host.api.components[key]
end

local function setCash(host: any, value: number)
	host.store:set("exactCash", value)
	host.store:set("cash", value)
end

local function gain(host: any, amount: number)
	setCash(host, host.store:get().cash + amount)
	host.emit("CashGain", { amount = amount })
end

local function spend(host: any, amount: number)
	setCash(host, math.max(0, host.store:get().cash - amount))
	host.emit("CashSpend", { amount = amount })
end

local function ensureHome(host: any)
	if host.store:get().mode ~= "Home" and host.api.goHome then
		host.api.goHome()
	end
	if host.api.applyMode then
		host.api.applyMode()
	end
end

local function logDebug(host: any, key: string, fields: { string })
	local c = comp(host, key)
	if not (c and c.getDebugState) then
		host.log(key .. ": not mounted")
		return
	end
	local ok, d = pcall(function()
		return c:getDebugState()
	end)
	if not ok then
		host.log(key .. ": debug failed " .. tostring(d))
		return
	end
	local parts = {}
	for _, f in fields do
		local v = (d :: any)[f]
		if type(v) == "table" then
			local okJson, json = pcall(HttpService.JSONEncode, HttpService, v)
			v = if okJson then json else "<table>"
		end
		table.insert(parts, f .. "=" .. tostring(v))
	end
	host.log(key .. " " .. table.concat(parts, " "))
end

-- The boundary table (H-10). Expected Format.cash results, truncating, promotion exactly at the
-- boundary; the scenario logs each displayed text so a reviewer can compare.
local BOUNDARIES: { number } = {
	999,
	9999,
	10000,
	999999,
	999950,
	1000000,
	9990000,
	9999999,
	10000000,
	999500000000,
	1000000000000,
	12300000000000,
	1000000000000000,
}

return {
	["Home: four layouts tour"] = function(host: any)
		ensureHome(host)
		local screen = host.api.screen
		if screen and screen.showReserved then
			screen:showReserved(true)
		end
		for _, name in { "Desktop", "PhoneLandscape", "PhonePortrait", "Tablet" } do
			host.api.setProfile(name)
			host.wait(0.5)
			logDebug(host, "menu", { "kind", "reservedOverlap" })
			logDebug(host, "stats", { "placement", "reservedOverlap" })
			logDebug(host, "toasts", { "reservedOverlap" })
			host.wait(2.5)
		end
		host.api.setProfile("Desktop")
		if screen and screen.showReserved then
			screen:showReserved(false)
		end
	end,

	["Home: buttons, badges, long labels, missing icon"] = function(host: any)
		ensureHome(host)
		local s = host.store
		local menu = comp(host, "menu")
		for _, n in { 0, 1, 12, 3 } do
			s:set("garage", { owned = 3, total = 12, unseen = n })
			s:set("missionsClaimable", if n == 12 then 0 else n)
			host.wait(1.2)
		end
		-- Shop badge only for an actual free fixture claim
		if menu and menu.setShopFreeClaims then
			menu:setShopFreeClaims(1)
			host.log("Shop badge: 1 free fixture claim")
			host.wait(1.5)
			menu:setShopFreeClaims(nil)
		end
		-- badges survive press scaling (held press)
		if menu and menu.setPressed then
			menu:setPressed("Garage", true)
			menu:setPressed("Missions", true)
			host.wait(1.2)
			logDebug(host, "menu", { "items" })
			menu:setPressed("Garage", false)
			menu:setPressed("Missions", false)
		end
		-- long label and a missing icon
		if menu and menu.setLabelOverride then
			menu:setLabelOverride("Missions", "Missions & Garage Goals")
			menu:setIconOverride("Garage", "NoSuchIconName")
			host.wait(3)
			logDebug(host, "menu", { "items" })
			menu:setLabelOverride("Missions", nil)
			menu:setIconOverride("Garage", nil)
		end
		s:set("garage", { owned = 3, total = 12, unseen = 1 })
		s:set("missionsClaimable", 1)
		host.wait(1)
	end,

	["Home: Cash small gain, spend, big gain (baseline match)"] = function(host: any)
		ensureHome(host)
		local stats = comp(host, "stats")
		-- like-for-like with the overnight baseline reel: the approved CashIcon first
		if stats and stats.useApprovedCashIcon then
			stats:useApprovedCashIcon(true)
		end
		setCash(host, 9450)
		host.wait(1)
		for _ = 1, 5 do -- frequent lap income: coalesced into one chip
			gain(host, 120)
			host.wait(0.15)
		end
		host.wait(1.5)
		gain(host, 5000) -- big gain (>= 10% of the balance and >= $500; counter: >= $1,000 and 25%)
		host.wait(1.6)
		spend(host, 500)
		host.wait(1.4)
		logDebug(host, "stats", { "cash" })
		-- the same big gain with the CashStack art (timing must be identical)
		if stats and stats.useApprovedCashIcon then
			stats:useApprovedCashIcon(false)
		end
		host.wait(9) -- past the 8 s preview big-gain cooldown
		gain(host, 5000)
		host.wait(2)
	end,

	["Home: interrupted count-up"] = function(host: any)
		ensureHome(host)
		setCash(host, 9450)
		host.wait(1)
		local v = host.store:get().cash
		setCash(host, v + 900)
		host.emit("CashGain", { amount = 900 })
		host.wait(0.15)
		setCash(host, v + 2100) -- arrives mid count-up: continues from the displayed value
		host.emit("CashGain", { amount = 1200 })
		host.wait(0.1)
		setCash(host, v + 1800) -- a spend during the count-up: the newest value wins
		host.emit("CashSpend", { amount = 300 })
		host.wait(1.5)
		logDebug(host, "stats", { "cash" })
		-- from zero: a tiny gain must not trigger the big celebration
		setCash(host, 0)
		host.wait(0.8)
		gain(host, 7)
		host.wait(1.5)
		setCash(host, 9450)
		host.wait(1)
	end,

	["Home: large values and format boundaries"] = function(host: any)
		ensureHome(host)
		local stats = comp(host, "stats")
		for _, value in BOUNDARIES do
			setCash(host, value)
			host.wait(0.9)
			if stats and stats.showExact then
				stats:showExact()
			end
			local d = if stats and stats.getDebugState then stats:getDebugState() else nil
			local shown = if d and d.cash and d.cash.counter then d.cash.counter.text else "?"
			host.log(string.format("%s -> expected %s, shown %s", Format.group(value), Format.cash(value), shown))
			host.wait(1.2)
		end
		-- car count with the same rules (no "$")
		for _, owned in { 3, 999, 9999, 10000, 999999, 1000000 } do
			host.store:set("garage", { owned = owned, total = 12, unseen = 0 })
			host.wait(0.8)
			logDebug(host, "stats", { "carCount" })
		end
		host.store:set("garage", { owned = 3, total = 12, unseen = 1 })
		setCash(host, 9450)
		host.wait(1)
	end,

	["Home: reduced motion switched mid-animation"] = function(host: any)
		ensureHome(host)
		setCash(host, 9450)
		host.wait(1)
		gain(host, 5000) -- a big gain: chip flight, count-up, punch, sparks
		host.wait(0.3)
		Motion.setOverride(true) -- mid-animation: everything lands, no further motion
		host.wait(1.5)
		logDebug(host, "stats", { "cash" })
		gain(host, 120) -- the calm path: no flight, snap, no punch
		host.wait(1)
		gain(host, 6000) -- big gain in reduced motion: a short calm glow only
		host.wait(1.5)
		host.emit("Toast", { text = "Reduce Motion is on", tone = "Info" })
		host.wait(3) -- the Shop rainbow drift is stopped
		Motion.setOverride(nil)
		host.wait(1)
	end,

	["Home: Music toggle"] = function(host: any)
		ensureHome(host)
		local s = host.store
		local function report(label: string)
			host.log(
				string.format(
					"%s: musicOn=%s level=%.2f group=%.2f",
					label,
					tostring(MusicSetting.isOn(s)),
					s:get().settings.music,
					Sounds.musicGroup().Volume
				)
			)
		end
		report("start")
		MusicSetting.setOn(s, false) -- same path as tapping the toggle
		host.wait(1.5)
		report("off")
		MusicSetting.setOn(s, true)
		host.wait(1.5)
		report("on")
		-- the Settings panel level is remembered across Off/On
		MusicSetting.setLevel(s, 0.8)
		MusicSetting.setOn(s, false)
		host.wait(1)
		report("level 0.8, off")
		MusicSetting.setOn(s, true)
		host.wait(1)
		report("on again")
		if host.api.open then
			host.api.open("settings")
			host.wait(3)
			host.api.close("settings")
		end
		MusicSetting.setLevel(s, 0.5)
		host.wait(0.5)
	end,

	["Home: tutorial + toasts"] = function(host: any)
		ensureHome(host)
		local s = host.store
		local steps = Fixtures.Tutorial
		for i, step in steps do
			if i > 2 then
				break
			end
			for c = 0, step.goal, math.max(1, step.goal // 3) do
				s:set("tutorial", {
					step = i,
					steps = #steps,
					objective = step.objective,
					count = c,
					goal = step.goal,
					hint = if c == 0 then step.hint else nil,
					state = if c == 0 then "Hint" else "Active",
				})
				host.wait(0.9)
			end
			s:set("tutorial", {
				step = i,
				steps = #steps,
				objective = step.objective,
				count = step.goal,
				goal = step.goal,
				hint = nil,
				state = "Done",
			})
			host.wait(2)
		end
		-- toasts beside the banner: two visible, duplicates coalesce, the queue is bounded
		host.emit("Toast", { text = "Car added to your Garage", tone = "Success" })
		host.wait(0.3)
		host.emit("Toast", { text = "Dusty Highway is coming soon", tone = "Info" })
		host.wait(0.3)
		host.emit("Toast", { text = "New paint unlocked", tone = "Unlock" })
		host.emit("Toast", { text = "Car added to your Garage", tone = "Success" }) -- Ã—2
		host.emit("Toast", { text = "Lap complete", tone = "Info" })
		host.emit("Toast", { text = "Lap complete", tone = "Info" }) -- Ã—2 while waiting
		for i = 1, 6 do
			host.emit("Toast", { text = "Queue test " .. i, tone = "Info" })
		end
		host.wait(1)
		logDebug(host, "toasts", { "shownCount", "queueCount", "dropped" })
		host.wait(6)
		s:set("tutorial", nil)
		-- during a run the stack asks for the Upper slot at Reward before showing
		host.enterRun()
		host.wait(0.5)
		host.emit("Toast", { text = "Lap complete", tone = "Info" })
		host.wait(0.2)
		logDebug(host, "toasts", { "gated", "slotHeld", "slotGranted", "shownCount" })
		host.wait(3)
		ensureHome(host)
		host.wait(1)
	end,

	["Home: timer proposal (captioned)"] = function(host: any)
		ensureHome(host)
		local timers = comp(host, "timers")
		if host.api.setCaptions then
			host.api.setCaptions(true)
		end
		host.store:set("proposals", { timers = true })
		host.wait(5)
		if timers and timers.setFixture then
			timers:setFixture("Stunt Race", 4) -- shows the fixture loop restarting at 0
		end
		host.wait(6)
		logDebug(host, "timers", { "proposalOn", "text", "loopRunning" })
		host.store:set("proposals", { timers = false })
		if timers and timers.setFixture then
			timers:setFixture("Stunt Race", 205)
		end
		host.wait(1)
		logDebug(host, "timers", { "proposalOn", "visible", "loopRunning" })
		if host.api.setCaptions then
			host.api.setCaptions(false)
		end
	end,
}
