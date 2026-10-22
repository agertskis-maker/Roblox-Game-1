--!strict
-- PLAYGROUND ONLY (Lane 3 HUD rebuild preview, worker HS). Screens and cards scenarios, driven by
-- synthetic fixtures through the preview store. Nothing here is a game rule: distances, coins,
-- Cash, claims, the +$50 Joyride Bonus and every capture id are fixtures.
--
-- host = { store, api, wait(seconds), emit(kind, fields) -> boolean, runPatch(patch), car(id),
--          enterRun(), log(text) }
-- Components used (mount keys): results (Screens/ResultsCard), garage, portalCard, welcome,
-- shop, cardSheet (Cards/StatesSheet; if the lead has not mounted it, the scenario makes a
-- temporary one and removes it at the end or at the next Screens scenario). Lookups are nil-safe.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")

local Prototype = Players.LocalPlayer
	:WaitForChild("PlayerScripts")
	:WaitForChild("Client")
	:WaitForChild("UI")
	:WaitForChild("Prototype")
local Fixtures = require(Prototype:WaitForChild("Fixtures")) :: any
local Motion = require(Prototype:WaitForChild("Motion"))

local function comp(host: any, key: string): any
	return host.api and host.api.components and host.api.components[key]
end

local function json(value: any): string
	local ok, out = pcall(function()
		return HttpService:JSONEncode(value)
	end)
	return if ok then out else tostring(value)
end

-- a temporary states sheet (only when the lead has not mounted "cardSheet")
local tempSheet: any = nil
local function dropTempSheet()
	if tempSheet then
		pcall(function()
			tempSheet:destroy()
		end)
		tempSheet = nil
	end
end

local function results(host: any): any
	return comp(host, "results")
end

local function claimedCars(host: any, ids: { string }): { any }
	local out = {}
	for _, id in ids do
		table.insert(out, host.car(id))
	end
	return out
end

-- Run -> Results with a fixture payload, through the store's checked transitions.
local function present(host: any, res: { [string]: any })
	dropTempSheet()
	host.enterRun()
	host.wait(0.8)
	host.store:set("results", res)
	host.store:setMode("Results")
	local card = results(host)
	if card and card.show then
		card:show(res, res.claimed)
	end
end

local function summary(host: any): { [string]: any }
	local card = results(host)
	if not (card and card.getDebugState) then
		return { missing = true }
	end
	local d = card:getDebugState()
	local names = {}
	for _, c in d.cards do
		table.insert(names, c.shownName .. (if c.late then " [SECURED]" else "") .. " (" .. c.nameFit .. ")")
	end
	return {
		heading = d.reasonHeading,
		line = d.reasonLine,
		rows = d.rows,
		claimed = d.claimed,
		late = d.lateClaims,
		separated = d.separated,
		scrollable = d.scrollable,
		retry = d.retryCalls,
		home = d.homeCalls,
		names = names,
	}
end

local function deluxeWaffle(host: any): any
	local c = table.clone(host.car("waffle"))
	c.id = "waffle-deluxe"
	c.name = "Citrine Waffle Van Deluxe Edition"
	return c
end

local function toHome(host: any)
	local mode = host.store:get().mode
	if mode == "Results" then
		host.store:set("results", nil)
	end
	if mode ~= "Home" and host.store:setMode("Home") then
		host.store:set("run", nil)
	end
	host.api.applyMode()
end

return {
	["Results: no claims"] = function(host: any)
		present(host, {
			distance = 85,
			coins = 0,
			best = 1100,
			newBest = false,
			claimed = {},
			earnings = 0,
		})
		host.wait(4)
		host.log("Results no claims: " .. json(summary(host)))
		host.wait(2)
	end,

	["Results: one claim"] = function(host: any)
		present(host, {
			distance = 1240,
			coins = 86,
			best = 1100,
			newBest = true,
			claimed = claimedCars(host, { "rev6" }),
			earnings = 340,
			joyride = 50, -- SYNTHETIC fixture amount (Brian L owns the real value)
			milestones = 2,
		})
		host.wait(5)
		host.log("Results one claim: " .. json(summary(host)))
		host.wait(2)
	end,

	["Results: many claims + long names (Revolution 6)"] = function(host: any)
		local cars = claimedCars(host, { "rev6", "puglet", "fishbowl", "rangy", "zoomurai", "hurrikan", "hyperion" })
		table.insert(cars, 2, deluxeWaffle(host))
		table.insert(cars, Fixtures.Variants.Gold)
		table.insert(cars, Fixtures.Variants.Rainbow)
		table.insert(cars, Fixtures.LongName)
		present(host, {
			distance = 4820,
			coins = 412,
			best = 4100,
			newBest = true,
			claimed = cars,
			earnings = 2150,
			joyride = 150,
			milestones = 5,
		})
		host.wait(2.5)
		local card = results(host)
		if card and card.skip then
			card:skip()
		end
		-- scroll the content region top to bottom: the cards must stay above the button row
		for _, a in { 0, 0.25, 0.5, 0.75, 1 } do
			if card and card.scrollTo then
				card:scrollTo(a)
			end
			host.wait(0.9)
			local d = if card and card.getDebugState then card:getDebugState() else nil
			if d then
				host.log(
					string.format(
						"scroll %.2f: content bottom %.0f, footer top %.0f, separated %s",
						a,
						d.contentBottom,
						d.footerTop,
						tostring(d.separated)
					)
				)
			end
		end
		host.log("Results many claims: " .. json(summary(host)))
		host.wait(1.5)
	end,

	["Results: delayed confirmation after run end"] = function(host: any)
		dropTempSheet()
		host.enterRun()
		local rev6 = host.car("rev6")
		local zoom = host.car("zoomurai")
		local capA = "cap-late-A-" .. tostring(math.floor(os.clock() * 1000))
		local capB = "cap-late-B-" .. tostring(math.floor(os.clock() * 1000))
		host.runPatch({ ride = rev6, keys = { id = capA, target = rev6, progress = 1, status = "Pending" } })
		host.wait(1.2)
		-- the run ends while capture A is still pending (SECURING...)
		host.emit("RunEnded", { reason = "Overheated" })
		host.wait(0.3)
		-- capture B is confirmed between the run end and the Results (queued for the Results)
		host.emit("KeysConfirmed", { captureId = capB, car = zoom })
		host.runPatch({ keys = nil })
		host.wait(0.5)
		local res = {
			distance = 980,
			coins = 41,
			best = 1100,
			newBest = false,
			claimed = {}, -- neither confirmation was in the run's claims when it ended
			earnings = 210,
			endReason = "Overheated",
		}
		host.store:set("results", res)
		host.store:setMode("Results")
		local card = results(host)
		if card and card.show then
			card:show(res, res.claimed)
		end
		host.wait(4)
		-- capture A is confirmed after the Results are open: it appears once, SECURED
		host.emit("KeysConfirmed", { captureId = capA, car = rev6 })
		host.wait(1.5)
		-- duplicate and out-of-order deliveries change nothing
		host.emit("KeysConfirmed", { captureId = capA, car = rev6 })
		host.emit("KeysConfirmed", { captureId = capB, car = zoom })
		local again = if card and card.addLateClaim then card:addLateClaim({ id = capA, car = rev6 }) else nil
		host.wait(0.5)
		local s = summary(host)
		host.log(
			string.format(
				"Delayed confirmation: %d claimed, %d secured (expected 2 and 2); direct duplicate accepted: %s",
				s.claimed or -1,
				s.late or -1,
				tostring(again)
			)
		)
		host.log("Results delayed: " .. json(s))
		host.wait(2)
	end,

	["Results: repeated taps"] = function(host: any)
		present(host, {
			distance = 1240,
			coins = 86,
			best = 1100,
			newBest = true,
			claimed = claimedCars(host, { "rev6" }),
			earnings = 340,
			joyride = 50,
			milestones = 2,
		})
		local card = results(host)
		host.wait(0.4)
		-- a press during the reveal only skips it
		if card and card.pressRetry then
			card:pressRetry()
		end
		host.wait(0.3)
		local changes = 0
		local conn = host.store.ModeChanged:Connect(function()
			changes += 1
		end)
		for i = 1, 6 do
			if card and card.pressRetry then
				card:pressRetry()
			end
			if i % 2 == 0 and card and card.pressHome then
				card:pressHome()
			end
			task.wait(0.03)
		end
		host.wait(0.8)
		conn:Disconnect()
		local d = if card and card.getDebugState then card:getDebugState() else {}
		host.log(
			string.format(
				"Repeated taps: %d mode change(s) (expected 1); retry calls %s, home calls %s, mode now %s",
				changes,
				tostring(d.retryCalls),
				tostring(d.homeCalls),
				host.store:get().mode
			)
		)
		host.wait(1)
	end,

	["Results: overheated reason"] = function(host: any)
		dropTempSheet()
		host.enterRun()
		host.wait(0.6)
		host.emit("RunEnded", { reason = "Overheated" })
		host.wait(0.4)
		local res = {
			distance = 1530,
			coins = 97,
			best = 1100,
			newBest = true,
			claimed = claimedCars(host, { "rangy" }),
			earnings = 420,
			endReason = "Overheated",
		}
		host.store:set("results", res)
		host.store:setMode("Results")
		local card = results(host)
		if card and card.show then
			card:show(res, res.claimed)
		end
		host.wait(5)
		host.log("Overheated: " .. json(summary(host)))
		-- an unknown reason falls back to RUN OVER with no invented cause
		local unknown = table.clone(res)
		unknown.endReason = "SomethingNew"
		if card and card.show then
			card:show(unknown, unknown.claimed)
		end
		host.wait(3.5)
		host.log("Unknown reason: " .. json(summary(host)))
		host.wait(1)
	end,

	["Screens: Garage / Portal / Welcome Back / Shop restyled tour"] = function(host: any)
		dropTempSheet()
		toHome(host)
		local api = host.api
		local garage = comp(host, "garage")
		api.open("garage")
		host.wait(2.5)
		if garage and garage.selectCar then
			garage:selectCar("rev6") -- not owned: shows how to get it, no greyed DRIVE
			host.wait(2)
			garage:selectCar("waffle")
			host.wait(1)
			-- the PROXY caption must follow the harness switch after a selection
			local tags = {}
			for _, d in garage.root:GetDescendants() do
				if d.Name == "ProxyTag" and d:IsA("GuiObject") then
					table.insert(tags, d.Visible == (api.captions == true))
				end
			end
			local bad = 0
			for _, okTag in tags do
				if not okTag then
					bad += 1
				end
			end
			host.log(string.format("PROXY tags following the caption switch: %d of %d", #tags - bad, #tags))
			host.wait(1)
		end
		if garage and garage.selectTab then
			garage:selectTab("Dusty")
			host.wait(1.5)
			garage:selectTab("Summit")
			host.wait(1.5)
			garage:selectTab("Downtown")
			host.wait(1)
		end
		api.close("garage")
		host.wait(0.6)
		local portal = comp(host, "portalCard")
		if portal and portal.setLocked then
			portal:setLocked(true)
		end
		api.open("portalCard")
		host.wait(2.5)
		if portal and portal.setLocked then
			portal:setLocked(false)
			host.wait(1)
			portal:setIndex(2)
		end
		host.wait(1.5)
		api.close("portalCard")
		host.wait(0.6)
		api.open("welcome")
		host.wait(3.5)
		api.close("welcome")
		host.wait(0.6)
		api.open("shop")
		host.wait(3.5)
		local shop = comp(host, "shop")
		if shop and shop.getDebugState then
			local d = shop:getDebugState()
			host.log(string.format("Shop: %d passes, %d badges (expected 0)", d.passes, d.badges or -1))
		end
		api.close("shop")
		host.wait(0.6)
	end,

	["Cards: states sheet"] = function(host: any)
		dropTempSheet()
		toHome(host)
		local api = host.api
		local sheet = comp(host, "cardSheet")
		if not sheet then
			local ok, made = pcall(function()
				local StatesSheet = require(Prototype:WaitForChild("Cards"):WaitForChild("StatesSheet")) :: any
				return StatesSheet.new({
					store = host.store,
					screen = api.screen,
					layer = api.layers.Overlay,
					world = api.backdrop and api.backdrop.world,
					priority = api.priority,
				})
			end)
			if not ok then
				host.log("Cards: states sheet could not be built: " .. tostring(made))
				return
			end
			tempSheet = made
			sheet = made
		end
		sheet:open()
		host.wait(4)
		local d = sheet:getDebugState()
		local fits = {}
		for _, s in d.states do
			table.insert(fits, s.label .. " = " .. s.card.shownName .. " (" .. s.card.nameFit .. ")")
		end
		host.log(string.format("Cards sheet: %d cards, %d spinning (max 6)", d.cards, d.spinning))
		host.log("Card names: " .. json(fits))
		-- reduced motion: every card goes static at once
		Motion.setOverride(true)
		host.wait(2)
		local active = 0
		for _, s in sheet:getDebugState().states do
			if s.card.active then
				active += 1
			end
		end
		host.log(string.format("Reduced motion: %d cards turning (expected 0)", active))
		Motion.setOverride(nil)
		host.wait(2)
		sheet:close()
		host.wait(0.4)
		dropTempSheet()
	end,
}
