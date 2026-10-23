--!strict
-- PLAYGROUND ONLY (Lane 3 Round 2, R2-X1 integration): the HUD on top of each World's generated city, on every layout, with
-- the proxy traffic carrying the Hop cues, the Stamina demo on and a capture that ends in SECURED. Studio Play numbers
-- only (route, overlap, failure and state checks); no image or timing is claimed here, and nothing is a gameplay test.
--
--   Worlds: combined run   per World (Downtown, Dusty Highway, Summit Pass) and per layout: the World builds, the run
--                          starts, no HUD component fails, the route line shows the World, a SECURED reveal plays clear of
--                          the protected view (or the compact stack on phones), Stamina shows, then the City is removed.

local Players = game:GetService("Players")

local Prototype = Players.LocalPlayer
	:WaitForChild("PlayerScripts")
	:WaitForChild("Client")
	:WaitForChild("UI")
	:WaitForChild("Prototype")
local Motion = require(Prototype:WaitForChild("Motion"))

type Host = { [string]: any }

local counter = 0
local function nonce(): string
	counter += 1
	return string.format("%d-%d", math.floor(os.clock() * 1000), counter)
end

local function verdict(host: Host, name: string, ok: boolean, detail: string)
	host.log(string.format("%s %s: %s", if ok then "PASS" else "FAIL", name, detail))
end

local function comp(host: Host, key: string): any
	return host.api.components and host.api.components[key]
end

local function dbg(host: Host, key: string): { [string]: any }
	local c = comp(host, key)
	return if c and c.getDebugState then c:getDebugState() else {}
end

local function failureCount(host: Host): number
	local n = 0
	for _ in host.api.failures do
		n += 1
	end
	return n
end

local S: { [string]: (Host) -> () } = {}

S["Worlds: combined run"] = function(host: Host)
	for _, world in { "Downtown", "DustyHighway", "SummitPass" } do
		local message = host.api.useCity(true, 2207, world)
		host.log("World " .. world .. ": " .. message)
		verdict(host, world .. " builds", string.find(message, "city built") ~= nil, message)
		host.wait(0.5)
		for _, profile in host.api.profiles do
			host.api.setProfile(profile)
			host.api.setSpeed(0)
			Motion.setOverride(nil)
			if host.store:get().mode == "Run" then
				host.store:setMode("Home")
			end
			host.enterRun()
			host.wait(0.7)
			host.api.setStamina(true, 10)
			host.api.hold(900)
			host.wait(0.8)
			local stats = host.api.cityStats()
			local asm = stats and stats.assembler or {}
			local route = dbg(host, "routeLine")
			local reveal0 = dbg(host, "reveal")
			local stamina = host.api.staminaDebug()
			-- a SECURED capture while the city runs behind the HUD
			local cid = "world-" .. nonce()
			local car = table.clone(host.car("rev6")) :: any
			car.owned = false
			host.emit("KeysConfirmed", { id = "KeysConfirmed-" .. cid, captureId = cid, car = car, lapPay = 220 })
			host.wait(0.7)
			local reveal = dbg(host, "reveal")
			local ribbon = dbg(host, "ribbon")
			local presented: boolean
			local how: string
			if reveal.cardAvailable then
				presented = (reveal.plays or 0) == (reveal0.plays or 0) + 1 and reveal.overlapsProtected == false
				how = "full card, clear of the protected view"
			else
				local soft = ribbon.softOverlap
				presented = ribbon.mode == "Stack"
					and ribbon.visible == true
					and ribbon.overlapsProtected == false
					and ribbon.overlapsHop == false
					and ribbon.overlapsHeat == false
					and ribbon.overlapsTray == false
					and (soft == nil or soft == "Options")
				how = string.format(
					"compact stack %s, soft overlap %s, ribbon box %s",
					tostring(ribbon.mode),
					tostring(soft),
					tostring(ribbon.box)
				)
			end
			verdict(
				host,
				string.format("%s / %s: HUD fine over the city", world, profile),
				failureCount(host) == 0 and (asm.liveItems or 0) > 0 and presented,
				string.format(
					"failures %d, city live items %s (proxy %s), route world %s, stamina on %s, SECURED: %s",
					failureCount(host),
					tostring(asm.liveItems),
					tostring(asm.liveProxyItems),
					tostring(route.world),
					tostring(stamina.enabled),
					how
				)
			)
			host.wait(1.6)
		end
		host.api.setStamina(false)
	end
	host.api.useCity(false)
	host.api.setSpeed(nil)
	host.api.setProfile("Desktop")
end

return S
