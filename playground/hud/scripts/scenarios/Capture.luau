--!strict
-- PLAYGROUND ONLY (Lane 3 Round 2, R2-K1, R2-V1, R2-V2, R2-T1, R2-T2): capture escalation, the SECURED reveal, the tray
-- thumbnails and the collectible cards. Every value is a synthetic fixture played through the preview store; ownership
-- comes only from the explicit KeysConfirmed event, never from progress. Each scenario logs the numbers it checks and
-- PASS / FAIL lines.
--
--   Capture: tiers, countdown and warning     the three tiers, ALMOST once, a capped pulse, sparse sparks, the countdown
--                                             only with trusted timing, warnings outrank decoration, reduced motion,
--                                             the ridden vehicle never moves
--   Capture: SECURED reveal (desktop)         the card, NEW, Lap Pay, count once at confirmation, no replay
--   Capture: SECURED reveal (phone)           no card: the compact ribbon with the thumbnail
--   Capture: SECURED reveal (Legendary)       one shockwave, pooled pieces under the cap
--   Capture: SECURED reveal (reduced motion)  steady card, no confetti, rays, zoom or flight
--   Capture: reveal identity                  duplicate, late and out-of-order confirmations, run end during the reveal
--   Cards: fine print truth                   Lap Pay, per second, unowned, unknown finishes, dates (pure)
--   Cards: detail, sheet and thumbnails       the fixed action bar, foil limit, the ViewportFrame budget
--
-- ROUND 3 (R3-F5, haptics): a recorder stub replaces the platform (Run/Haptics.useBackend) so nothing is felt or claimed felt;
-- these check the calls the code makes. Run-scoped capture identity (R3-F9) is in scenarios/RunIdentity.luau; the Capture
-- scenarios above needed no change for it (each starts its own run, so their ids are scoped to that run).
--   Haptics: default on and capability        ON by default (nil counts as ON), capability reported honestly, one cue
--   Haptics: capture cue and the switch       one cue per claim; OFF stops the running cue and blocks the next call; a direct
--                                             store write behaves the same; ON allows it again
--   Haptics: unsupported hardware             supported=false, no call, no error, the Settings row disabled with its reason,
--                                             a controller-only device stops with motor writes of 0
--   Haptics: Settings row on every frame      the row on all six frames: ON word, state line fits, 48 px hit, the card fits
--   Haptics: Settings row (reduced motion)    the switch snaps with no tween, word and line follow, the store follows
--   Haptics: toggling mid-effect and no leak  off then on mid-effect does not resume it, no double stop, nothing left running

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local Prototype = Players.LocalPlayer
	:WaitForChild("PlayerScripts")
	:WaitForChild("Client")
	:WaitForChild("UI")
	:WaitForChild("Prototype")
local Motion = require(Prototype:WaitForChild("Motion"))
local StoreModule = require(Prototype:WaitForChild("Store"))
local Haptics = require(Prototype:WaitForChild("Run"):WaitForChild("Haptics"))
local TradingCard = require(Prototype:WaitForChild("Cards"):WaitForChild("TradingCard"))

type Host = { [string]: any }

local counter = 0
local function nonce(): string
	counter += 1
	return string.format("%d-%d", math.floor(os.clock() * 1000), counter)
end

local function comp(host: Host, key: string): any
	return host.api.components and host.api.components[key]
end

local function dbg(host: Host, key: string): { [string]: any }
	local c = comp(host, key)
	return if c and c.getDebugState then c:getDebugState() else {}
end

local function verdict(host: Host, name: string, ok: boolean, detail: string)
	host.log(string.format("%s %s: %s", if ok then "PASS" else "FAIL", name, detail))
end

local function send(host: Host, kind: string, fields: { [string]: any }?)
	local e = fields or {}
	e.id = e.id or (kind .. "-" .. nonce())
	return host.emit(kind, e)
end

local function freshRun(host: Host)
	local store = host.store
	Motion.setOverride(nil)
	if store:get().mode == "Run" then
		store:setMode("Home")
	end
	host.enterRun()
	host.wait(0.6)
end

local function setRun(host: Host, fields: { [string]: any })
	local run = host.store:get().run
	if not run then
		return
	end
	local merged = table.clone(run) :: any
	for k, v in fields do
		merged[k] = if v == "__nil" then nil else v
	end
	host.store:set("run", merged)
end

local function setKeys(host: Host, id: string, car: any, progress: number, status: string, extra: { [string]: any }?)
	local keys = { id = id, target = car, progress = progress, status = status }
	if extra then
		for k, v in extra do
			keys[k] = v
		end
	end
	setRun(host, { keys = keys })
end

local function ownedFalse(host: Host, id: string): any
	local c = table.clone(host.car(id)) :: any
	c.owned = false
	return c
end

local S: { [string]: (Host) -> () } = {}

S["Capture: tiers, countdown and warning"] = function(host: Host)
	host.api.setProfile("Desktop")
	host.api.setSpeed(0)
	freshRun(host)
	host.api.backdrop.hold(0)
	host.wait(0.4) -- the held traffic settles at its place before the vehicle is measured
	local rideBody = host.api.backdrop.ride.PrimaryPart
	local before: CFrame = rideBody.CFrame
	local car = ownedFalse(host, "rev6")
	local id = "tier-" .. nonce()
	for _, p in { 0.1, 0.3 } do
		setKeys(host, id, car, p, "Holding")
		host.wait(0.25)
	end
	local t1 = dbg(host, "keys")
	verdict(
		host,
		"Tier 1 (0-50%)",
		t1.tier == 1 and t1.almostShown == false and t1.pulsing == false,
		string.format("tier %s, almost %s", tostring(t1.tier), tostring(t1.almostShown))
	)
	local ticks0 = t1.ticks
	for _, p in { 0.52, 0.6, 0.74 } do
		setKeys(host, id, car, p, "Holding")
		host.wait(0.25)
	end
	local t2 = dbg(host, "keys")
	verdict(
		host,
		"Tier 2 (50-75%)",
		t2.tier == 2 and t2.almostShown == false and t2.pulsing == false,
		string.format("tier %s, clicks +%d", tostring(t2.tier), t2.ticks - ticks0)
	)
	for _, p in { 0.76, 0.85, 0.95 } do
		setKeys(host, id, car, p, "Holding")
		host.wait(0.45)
	end
	local t3 = dbg(host, "keys")
	verdict(
		host,
		"Tier 3 (75-100%)",
		t3.tier == 3
			and t3.almostShown == true
			and t3.instruction == "ALMOST!"
			and t3.pulsing == true
			and t3.pulseHz == 1
			and t3.edgesShown == true,
		string.format(
			"tier %s, instruction %s, pulsing %s at %s Hz, edges %s",
			tostring(t3.tier),
			tostring(t3.instruction),
			tostring(t3.pulsing),
			tostring(t3.pulseHz),
			tostring(t3.edgesShown)
		)
	)
	-- ALMOST appears once: more progress never replays it
	local log = t3.log :: { string }
	local almosts = 0
	for _, line in log do
		if string.find(line, "ALMOST") then
			almosts += 1
		end
	end
	verdict(host, "ALMOST once", almosts == 1, "log lines with ALMOST: " .. tostring(almosts))
	-- sparse sparks: at most 3 a second
	local s0 = dbg(host, "keys").sparksShown
	host.wait(2)
	local s1 = dbg(host, "keys").sparksShown
	verdict(
		host,
		"Sparks are sparse",
		(s1 - s0) <= 7 and (s1 - s0) >= 1,
		string.format("%d sparks in 2 s (cap 3 a second)", s1 - s0)
	)
	-- the countdown only with trusted timing
	setKeys(host, id, car, 0.9, "Holding", { remainingSeconds = 1.2, timingTrusted = true })
	host.wait(0.3)
	local trusted = dbg(host, "keys")
	setKeys(host, id, car, 0.91, "Holding", { remainingSeconds = 1.1, timingTrusted = false })
	host.wait(0.3)
	local untrusted = dbg(host, "keys")
	setKeys(host, id, car, 0.92, "Holding")
	host.wait(0.3)
	local absent = dbg(host, "keys")
	verdict(
		host,
		"Countdown only when trusted",
		trusted.countdownShown == true
			and trusted.percent == "1.2s"
			and untrusted.countdownShown == false
			and absent.countdownShown == false
			and string.find(tostring(absent.percent), "%%") ~= nil,
		string.format(
			"trusted %q, untrusted %q, absent %q",
			tostring(trusted.percent),
			tostring(untrusted.percent),
			tostring(absent.percent)
		)
	)
	-- a warning outranks the decoration
	setRun(host, { warning = { id = "tier-warning", reason = "TooHot" } })
	host.wait(0.6)
	local held = dbg(host, "keys")
	verdict(
		host,
		"A warning outranks capture decoration",
		held.decorationHeld == true and held.pulsing == false,
		string.format("held %s, pulsing %s", tostring(held.decorationHeld), tostring(held.pulsing))
	)
	setRun(host, { warning = "__nil" })
	host.wait(0.8)
	verdict(
		host,
		"...and the decoration returns",
		dbg(host, "keys").pulsing == true,
		tostring(dbg(host, "keys").pulsing)
	)
	-- reduced motion: steady
	Motion.setOverride(true)
	host.wait(0.4)
	local reduced = dbg(host, "keys")
	verdict(
		host,
		"Reduced motion: no pulse, edges or sparks",
		reduced.pulsing == false and reduced.edgesShown == false and reduced.instruction == "ALMOST!",
		string.format(
			"pulsing %s, edges %s, instruction %s",
			tostring(reduced.pulsing),
			tostring(reduced.edgesShown),
			tostring(reduced.instruction)
		)
	)
	Motion.setOverride(nil)
	-- the ridden vehicle was never moved by any of it
	local moved = (rideBody.CFrame.Position - before.Position).Magnitude
	local turned = math.deg(math.acos(math.clamp(rideBody.CFrame.LookVector:Dot(before.LookVector), -1, 1)))
	verdict(
		host,
		"Ridden vehicle unchanged",
		moved < 1e-4 and turned < 0.01,
		string.format("PrimaryPart moved %.6f studs, turned %.4f degrees across the whole capture", moved, turned)
	)
	verdict(
		host,
		"No body motion",
		string.find(tostring(dbg(host, "keys").bodyMotion), "none") ~= nil,
		tostring(dbg(host, "keys").bodyMotion)
	)
	setKeys(host, id, car, 1, "Pending")
	host.wait(0.4)
	local pending = dbg(host, "keys")
	verdict(
		host,
		"SECURING until confirmed",
		pending.phase == "Pending" and pending.instruction == "SECURING…" and pending.pulsing == false,
		string.format("phase %s, instruction %s", tostring(pending.phase), tostring(pending.instruction))
	)
	send(host, "KeysConfirmed", { captureId = id, car = car })
	host.wait(1.2)
	host.api.setSpeed(nil)
end

local function waitReveal(host: Host, seconds: number)
	host.wait(seconds)
end

local function confirm(host: Host, cid: string, car: any, lapPay: number?)
	send(host, "KeysConfirmed", { captureId = cid, car = car, lapPay = lapPay })
end

S["Capture: SECURED reveal (desktop)"] = function(host: Host)
	host.api.setProfile("Desktop")
	host.api.setSpeed(0)
	freshRun(host)
	host.api.backdrop.hold(0)
	local tray = comp(host, "tray")
	local before = dbg(host, "reveal")
	local count0 = tray:count()
	local cid = "reveal-" .. nonce()
	confirm(host, cid, ownedFalse(host, "rev6"), 220)
	waitReveal(host, 0.55)
	local mid = dbg(host, "reveal")
	verdict(
		host,
		"The card plays on a wide screen",
		mid.playing == true and mid.plays == before.plays + 1,
		string.format("playing %s, plays +%d", tostring(mid.playing), mid.plays - before.plays)
	)
	verdict(
		host,
		"It clears the protected road view",
		mid.overlapsProtected == false and mid.cardAvailable == true,
		"placed " .. tostring(mid.placedBox)
	)
	local card = mid.card or {}
	verdict(
		host,
		"SECURED, NEW and Lap Pay",
		card.stamp == "SECURED" and card.newShown == true and card.lapPayText == "$220",
		string.format(
			"stamp %s, NEW %s, Lap Pay %s",
			tostring(card.stamp),
			tostring(card.newShown),
			tostring(card.lapPayText)
		)
	)
	verdict(
		host,
		"Count changed once at confirmation",
		tray:count() == count0 + 1,
		string.format("count %d -> %d while the card shows", count0, tray:count())
	)
	verdict(
		host,
		"Pieces stay under the cap",
		mid.fxPieces <= mid.fxCap and mid.confettiLive <= 24,
		string.format("%d pooled pieces (cap %d), %d confetti live", mid.fxPieces, mid.fxCap, mid.confettiLive)
	)
	waitReveal(host, 2.1)
	local after = dbg(host, "reveal")
	verdict(
		host,
		"It lands at the count and is gone",
		after.playing == false and after.flights == before.flights + 1,
		string.format("playing %s, flights +%d", tostring(after.playing), after.flights - before.flights)
	)
	verdict(host, "The count did not change again", tray:count() == count0 + 1, "count " .. tostring(tray:count()))
	-- the same confirmation again never replays
	confirm(host, cid, ownedFalse(host, "rev6"), 220)
	waitReveal(host, 0.7)
	local again = dbg(host, "reveal")
	verdict(
		host,
		"A duplicate does not replay",
		again.plays == after.plays and tray:count() == count0 + 1,
		string.format("plays +%d, count %d", again.plays - after.plays, tray:count())
	)
	host.api.setSpeed(nil)
end

S["Capture: SECURED reveal (phone)"] = function(host: Host)
	host.api.setProfile("PhoneLandscape")
	host.api.setSpeed(0)
	freshRun(host)
	host.api.backdrop.hold(0)
	local tray = comp(host, "tray")
	local before = dbg(host, "reveal")
	local ribbonBefore = dbg(host, "ribbon")
	local count0 = tray:count()
	confirm(host, "reveal-" .. nonce(), ownedFalse(host, "rev6"), 220)
	waitReveal(host, 0.6)
	local reveal = dbg(host, "reveal")
	local ribbon = dbg(host, "ribbon")
	verdict(
		host,
		"No card on a phone",
		reveal.cardAvailable == false and reveal.plays == before.plays,
		string.format(
			"available %s because %s",
			tostring(reveal.cardAvailable),
			tostring(reveal.cardUnavailableBecause)
		)
	)
	verdict(
		host,
		"The compact ribbon plays at once, with the thumbnail",
		ribbon.title == "SECURED!"
			and ribbon.thumb == true
			and ribbon.shown == ribbonBefore.shown + 1
			and ribbon.overlapsProtected == false
			and ribbon.overlapsTray == false
			and ribbon.overlapsHop == false
			and ribbon.overlapsHeat == false
			and (ribbon.overlapsChip == false or ribbon.chipSteppedAside == true)
			and ribbon.overlapsGear == false,
		string.format(
			"title %s, thumbnail %s, placed as %s at %s, overlaps protected %s, tray %s, Hop %s, Heat %s, chip %s (stepped aside %s), gear %s, line %q",
			tostring(ribbon.title),
			tostring(ribbon.thumb),
			tostring(ribbon.mode),
			tostring(ribbon.box),
			tostring(ribbon.overlapsProtected),
			tostring(ribbon.overlapsTray),
			tostring(ribbon.overlapsHop),
			tostring(ribbon.overlapsHeat),
			tostring(ribbon.overlapsChip),
			tostring(ribbon.chipSteppedAside),
			tostring(ribbon.overlapsGear),
			tostring(ribbon.sub)
		)
	)
	verdict(host, "Lap Pay is the supplied one", string.find(tostring(ribbon.sub), "220") ~= nil, tostring(ribbon.sub))
	verdict(
		host,
		"Count changed once at confirmation",
		tray:count() == count0 + 1,
		string.format("count %d -> %d", count0, tray:count())
	)
	waitReveal(host, 2.4)
	verdict(host, "Count still once after the flight", tray:count() == count0 + 1, "count " .. tostring(tray:count()))
	host.api.setSpeed(nil)
end

S["Capture: SECURED reveal (Legendary)"] = function(host: Host)
	host.api.setProfile("Desktop")
	host.api.setSpeed(0)
	freshRun(host)
	host.api.backdrop.hold(0)
	local before = dbg(host, "reveal")
	confirm(host, "reveal-" .. nonce(), ownedFalse(host, "hyperion"), 480)
	waitReveal(host, 0.5)
	local mid = dbg(host, "reveal")
	verdict(
		host,
		"Legendary adds one shockwave",
		mid.legendary == true and mid.shockwaves == before.shockwaves + 1,
		string.format("shockwaves +%d", mid.shockwaves - before.shockwaves)
	)
	verdict(
		host,
		"Foil shows on the card",
		mid.card ~= nil and mid.card.foil == true,
		string.format("foil %s", tostring(mid.card and mid.card.foil))
	)
	waitReveal(host, 2.2)
	verdict(
		host,
		"Same duration: gone in two seconds",
		dbg(host, "reveal").playing == false,
		"playing " .. tostring(dbg(host, "reveal").playing)
	)
	host.api.setSpeed(nil)
end

S["Capture: SECURED reveal (reduced motion)"] = function(host: Host)
	host.api.setProfile("Desktop")
	host.api.setSpeed(0)
	freshRun(host)
	host.api.backdrop.hold(0)
	Motion.setOverride(true)
	local before = dbg(host, "reveal")
	confirm(host, "reveal-" .. nonce(), ownedFalse(host, "hurrikan"), 340)
	waitReveal(host, 0.6)
	local mid = dbg(host, "reveal")
	verdict(
		host,
		"Reduced motion: a steady card",
		mid.playing == true
			and mid.reducedMotion == true
			and mid.confettiLive == 0
			and mid.raysShown == false
			and mid.scale == 1
			and mid.shockwaves == before.shockwaves,
		string.format(
			"playing %s, confetti %d, rays %s, scale %s",
			tostring(mid.playing),
			mid.confettiLive,
			tostring(mid.raysShown),
			tostring(mid.scale)
		)
	)
	waitReveal(host, 1.6)
	local after = dbg(host, "reveal")
	verdict(
		host,
		"No flight, simply gone",
		after.playing == false and after.flights == before.flights,
		string.format("playing %s, flights +%d", tostring(after.playing), after.flights - before.flights)
	)
	Motion.setOverride(nil)
	host.api.setSpeed(nil)
end

S["Capture: reveal identity"] = function(host: Host)
	host.api.setProfile("Desktop")
	host.api.setSpeed(0)
	freshRun(host)
	host.api.backdrop.hold(0)
	local tray = comp(host, "tray")
	local ribbon = comp(host, "ribbon")
	local count0 = tray:count()
	local plays0 = dbg(host, "reveal").plays
	-- out of order: B confirmed before A is even announced, then A
	local a, b = "id-a-" .. nonce(), "id-b-" .. nonce()
	confirm(host, b, host.car("rangy"), 150)
	confirm(host, a, host.car("zoomurai"), 260)
	confirm(host, b, host.car("rangy"), 150) -- a repeat of B
	host.wait(4.6)
	verdict(
		host,
		"Two claims, each shown and counted once",
		tray:count() == count0 + 2 and dbg(host, "reveal").plays == plays0 + 2,
		string.format("count +%d, plays +%d", tray:count() - count0, dbg(host, "reveal").plays - plays0)
	)
	-- the run ends during a reveal: the claim is kept for Results and counted once
	local c = "id-c-" .. nonce()
	local before = tray:count()
	confirm(host, c, host.car("hurrikan"), 340)
	host.wait(0.5)
	send(host, "RunEnded", { reason = "Overheated" })
	host.wait(1.0)
	local pending = ribbon:pendingCards()
	local names = {}
	for _, car in pending do
		table.insert(names, car.name)
	end
	verdict(
		host,
		"Run end during the reveal keeps the claim",
		tray:count() == before + 1 and table.find(names, "Hurrikan") ~= nil and dbg(host, "reveal").playing == false,
		string.format(
			"count +%d, kept for Results: %s, still playing %s",
			tray:count() - before,
			table.concat(names, ", "),
			tostring(dbg(host, "reveal").playing)
		)
	)
	host.api.setSpeed(nil)
end

S["Cards: fine print truth"] = function(host: Host)
	local rev6 = host.car("rev6")
	local owned = table.clone(rev6) :: any
	owned.owned = true
	local hidden = table.clone(rev6) :: any
	hidden.owned = false
	local function row(rows: any, title: string): any
		for _, r in rows do
			if r.title == title then
				return r
			end
		end
		return nil
	end
	local function kinds(rows: any): { string }
		local out = {}
		for _, r in rows do
			table.insert(out, r.kind)
		end
		return out
	end
	local noDuration = TradingCard.fineRows(owned, { lapPay = 120, collectionNo = 5, collectionTotal = 24 })
	verdict(
		host,
		"Lap Pay shows as supplied",
		row(noDuration, "Lap Pay").value == "$120 / lap",
		tostring(row(noDuration, "Lap Pay").value)
	)
	verdict(
		host,
		"No lap duration: per second unavailable",
		row(noDuration, "Per second").value == "unavailable (proposed)",
		tostring(row(noDuration, "Per second").value)
	)
	local defined = TradingCard.fineRows(owned, { lapPay = 120, lapSeconds = 60 })
	verdict(
		host,
		"A defined lap duration: per second computed",
		row(defined, "Per second").value == "$2.0 / s",
		tostring(row(defined, "Per second").value)
	)
	local none = TradingCard.fineRows(owned, {})
	verdict(
		host,
		"No Lap Pay supplied: nothing invented",
		row(none, "Lap Pay").value == "not set yet",
		tostring(row(none, "Lap Pay").value)
	)
	local unowned = TradingCard.fineRows(
		hidden,
		{ lapPay = 120, collectionNo = 5, collectionTotal = 24, claimedAt = "Oct 22", variants = { Gold = true } }
	)
	local leaks = false
	for _, r in unowned do
		if r.kind == "Variants" or (r.kind == "Footer" and (r.value ~= nil or r.text ~= nil)) then
			leaks = true
		end
	end
	verdict(
		host,
		"Unowned: question marks and no leaks",
		row(unowned, "Lap Pay").value == "?" and leaks == false,
		"kinds: " .. table.concat(kinds(unowned), ",")
	)
	local variants = TradingCard.fineRows(owned, { variants = { Gold = true, Chrome = false } })
	local chips: any = nil
	for _, r in variants do
		if r.kind == "Variants" then
			chips = r.chips
		end
	end
	verdict(
		host,
		"Finishes: owned, not owned, unknown are distinct",
		chips[1].state == "Owned" and chips[2].state == "Not owned" and chips[3].state == "Unknown",
		string.format("%s / %s / %s", chips[1].state, chips[2].state, chips[3].state)
	)
	local dated = TradingCard.fineRows(owned, { claimedAt = "Oct 22", collectionNo = 5, collectionTotal = 24 })
	local undated = TradingCard.fineRows(owned, { collectionNo = 5 })
	local function footer(rows: any): any
		for _, r in rows do
			if r.kind == "Footer" then
				return r
			end
		end
		return {}
	end
	verdict(
		host,
		"Date and number only when supplied",
		footer(dated).text == "Claimed Oct 22"
			and footer(dated).value == "No. 5 / 24"
			and footer(undated).text == nil
			and footer(undated).value == "No. 5",
		string.format(
			"%q %q | %q %q",
			tostring(footer(dated).text),
			tostring(footer(dated).value),
			tostring(footer(undated).text),
			tostring(footer(undated).value)
		)
	)
	local bars = TradingCard.fineRows(owned, {
		stats = {
			{ label = "Heat capacity", value = "11 s", bar = 0.79, scale = "0 to 14 s" },
			{ label = "Preview", value = "5", bar = 0.5 },
		},
	})
	verdict(
		host,
		"A bar needs a documented scale",
		row(bars, "Heat capacity").bar == 0.79
			and row(bars, "Preview").bar == nil
			and row(bars, "Preview").note == "preview value only",
		string.format(
			"bar %s, unscaled bar %s",
			tostring(row(bars, "Heat capacity").bar),
			tostring(row(bars, "Preview").bar)
		)
	)
	local family, mapped = TradingCard.familyIcon({ family = "Bus" } :: any)
	verdict(
		host,
		"Fixture family Bus maps to Truck and is flagged",
		family == "Family_Truck" and mapped == true,
		family .. " mapped=" .. tostring(mapped)
	)
end

-- ViewportFrames that are actually on screen (hidden overlays render nothing).
local function viewportCount(): number
	local gui = Players.LocalPlayer:FindFirstChild("PlayerGui")
	local n = 0
	if gui then
		for _, d in gui:GetDescendants() do
			if d:IsA("ViewportFrame") then
				local shown = true
				local node: Instance? = d
				while node and node ~= gui do
					if
						(node:IsA("GuiObject") and not (node :: GuiObject).Visible)
						or (node:IsA("ScreenGui") and not (node :: ScreenGui).Enabled)
					then
						shown = false
					end
					node = node.Parent
				end
				if shown then
					n += 1
				end
			end
		end
	end
	return n
end

S["Cards: detail, sheet and thumbnails"] = function(host: Host)
	for _, profile in { "PhoneLandscape", "PhoneSmall", "Desktop" } do
		host.api.setProfile(profile)
		host.wait(0.3)
		for _, owned in { true, false } do
			host.api.openCardDetail("rev6", owned)
			host.wait(0.5)
			local d = dbg(host, "cardDetail")
			verdict(
				host,
				string.format("Detail %s, %s Revolution 6", profile, if owned then "owned" else "unowned"),
				d.open == true and d.scrollsBehindBar == false and d.gapToBar >= 0 and d.rows >= 4,
				string.format(
					"variant %s, rows %s, gap to the fixed bar %.1f px, canvas %.0f in %.0f",
					tostring(d.variant),
					tostring(d.rows),
					d.gapToBar,
					d.canvasHeight,
					d.scrollHeight
				)
			)
			host.api.close("cardDetail")
			host.wait(0.2)
		end
	end
	host.api.setProfile("Desktop")
	host.api.open("tradingSheet")
	host.wait(1.2)
	local sheet = dbg(host, "tradingSheet")
	local foilOnlyHigh = true
	for _, st in sheet.states do
		local card = st.card
		if card.foil and card.rarity ~= "Epic" and card.rarity ~= "Legendary" then
			foilOnlyHigh = false
		end
		if not card.foil and (card.rarity == "Epic" or card.rarity == "Legendary") then
			foilOnlyHigh = false
		end
	end
	verdict(
		host,
		"Foil is limited and only on Epic and Legendary",
		foilOnlyHigh and sheet.foilCards == 2 and sheet.foilAnimated <= 4,
		string.format(
			"foil cards %s (2 reward cards; the small duplicate row was removed in Round 3), animated %s (limit 4), only Epic and Legendary: %s",
			tostring(sheet.foilCards),
			tostring(sheet.foilAnimated),
			tostring(foilOnlyHigh)
		)
	)
	host.api.close("tradingSheet")
	-- tray thumbnails: never more than four ViewportFrames while a run shows claims
	host.api.setProfile("Desktop")
	host.api.setSpeed(0)
	freshRun(host)
	for i, id in { "puglet", "fishbowl", "waffle", "rangy", "rev6", "zoomurai" } do
		send(host, "KeysConfirmed", { captureId = "thumb-" .. i .. nonce(), car = host.car(id) })
		host.wait(0.9)
	end
	host.wait(3)
	local tray = dbg(host, "tray")
	verdict(
		host,
		"Tray thumbnails stay within four",
		tray.thumbs <= tray.thumbLimit and tray.thumbs >= 1,
		string.format(
			"%s thumbnails (limit %s), %s ViewportFrames on screen in all",
			tostring(tray.thumbs),
			tostring(tray.thumbLimit),
			tostring(viewportCount())
		)
	)
	verdict(
		host,
		"Three or four tiles, then +N more",
		string.find(table.concat(tray.slots, ","), "More") ~= nil,
		table.concat(tray.slots, ",")
	)
	host.api.setSpeed(nil)
end

-- HAPTICS (R3-F5) ---------------------------------------------------------------------------------------------------------

-- Installs a recorder as the platform; every haptics scenario starts from the real backend and ON, and ends the same way.
local function recorderOn(host: Host, support: { gamepad: boolean?, touch: boolean? }): any
	Haptics.useBackend(nil)
	Haptics.setEnabled(host.store, true)
	local rec = Haptics.recorder(support)
	Haptics.useBackend(rec.backend)
	return rec
end

local function hapticsDone(host: Host)
	Haptics.useBackend(nil)
	Haptics.setEnabled(host.store, true)
	Motion.setOverride(nil)
end

local function goHome(host: Host)
	if host.store:get().mode ~= "Home" then
		host.store:setMode("Home")
	end
	host.wait(0.3)
end

S["Haptics: default on and capability"] = function(host: Host)
	Haptics.useBackend(nil)
	local fresh = StoreModule.new()
	local settings = fresh:get().settings
	verdict(
		host,
		"Haptics is ON by default",
		settings.haptics == true
			and Haptics.isOn(settings)
			and Haptics.isOn({})
			and not Haptics.isOn({ haptics = false }),
		string.format("fixture setting %s, an unset setting counts as ON", tostring(settings.haptics))
	)
	fresh:destroy()
	-- what THIS machine reports (informational: a desktop Studio has no touch screen and usually no controller)
	local cap = Haptics.capability()
	verdict(
		host,
		"The capability report is consistent",
		cap.supported == (cap.gamepad or cap.touch) and Haptics.isSupported() == cap.supported,
		string.format(
			"supported %s (controller %s, touch %s) because: %s",
			tostring(cap.supported),
			tostring(cap.gamepad),
			tostring(cap.touch),
			cap.basis
		)
	)
	-- a touch device with the default preference: exactly one cue is requested, then it is stopped
	local rec = recorderOn(host, { touch = true })
	local result = Haptics.confirm(Haptics.isOn(StoreModule.baseline().settings))
	verdict(
		host,
		"A supported device with the default preference requests one cue",
		result == "requested" and rec.starts == 1 and rec.live == 1 and Haptics.counts().active == 1,
		string.format("result %s, starts %d, live %d", result, rec.starts, rec.live)
	)
	Haptics.stop()
	verdict(
		host,
		"...and stopping it leaves nothing running",
		rec.live == 0 and rec.stops == 1 and Haptics.counts().active == 0,
		table.concat(rec.calls, ",")
	)
	hapticsDone(host)
end

S["Haptics: capture cue and the switch"] = function(host: Host)
	local rec = recorderOn(host, { touch = true })
	host.api.setProfile("Desktop")
	host.api.setSpeed(0)
	freshRun(host)
	host.api.backdrop.hold(0)
	-- ON: one cue for one confirmed claim (the same call site serves the card and the phone stack)
	confirm(host, "hap-1-" .. nonce(), ownedFalse(host, "rev6"), 100)
	host.wait(0.6)
	verdict(
		host,
		"ON: one confirmed claim, one cue",
		rec.starts == 1 and rec.live == 1 and dbg(host, "ribbon").haptic == "requested",
		string.format("starts %d, live %d, ribbon says %s", rec.starts, rec.live, tostring(dbg(host, "ribbon").haptic))
	)
	-- the Settings switch turned OFF while that cue is still running
	Haptics.setEnabled(host.store, false)
	verdict(
		host,
		"OFF stops the cue that is running",
		rec.stops == 1 and rec.live == 0 and Haptics.counts().active == 0,
		string.format("stops %d, live %d, calls %s", rec.stops, rec.live, table.concat(rec.calls, ","))
	)
	host.wait(2.2) -- the first claim finishes its show
	local startsBefore = rec.starts
	confirm(host, "hap-2-" .. nonce(), ownedFalse(host, "zoomurai"), 150)
	host.wait(0.6)
	verdict(
		host,
		"OFF: the next claim makes no haptic call",
		rec.starts == startsBefore and dbg(host, "ribbon").haptic == "off",
		string.format(
			"starts %d (was %d), ribbon says %s",
			rec.starts,
			startsBefore,
			tostring(dbg(host, "ribbon").haptic)
		)
	)
	host.wait(2.2)
	-- ON again: the next claim plays one cue
	Haptics.setEnabled(host.store, true)
	confirm(host, "hap-3-" .. nonce(), ownedFalse(host, "rangy"), 90)
	host.wait(0.6)
	verdict(
		host,
		"ON again: the next claim plays one cue",
		rec.starts == startsBefore + 1 and dbg(host, "ribbon").haptic == "requested",
		string.format("starts %d (was %d)", rec.starts, startsBefore)
	)
	-- a harness that writes the setting directly (not through Haptics.setEnabled) gets the same stop
	local direct = table.clone(host.store:get().settings) :: any
	direct.haptics = false
	host.store:set("settings", direct)
	verdict(
		host,
		"A direct store write of OFF also stops the cue",
		rec.live == 0 and Haptics.counts().active == 0,
		string.format("live %d, calls %s", rec.live, table.concat(rec.calls, ","))
	)
	host.wait(2.2)
	hapticsDone(host)
	host.api.setSpeed(nil)
end

S["Haptics: unsupported hardware"] = function(host: Host)
	local rec = recorderOn(host, { gamepad = false, touch = false })
	local cap = Haptics.capability()
	verdict(
		host,
		"Reports supported = false",
		cap.supported == false and Haptics.isSupported() == false,
		string.format("supported %s because: %s", tostring(cap.supported), cap.basis)
	)
	local before = Haptics.counts()
	local ok, result = pcall(Haptics.confirm, true)
	verdict(
		host,
		"No call and no error",
		ok
			and result == "unsupported"
			and rec.starts == 0
			and #rec.calls == 0
			and Haptics.counts().unsupported == before.unsupported + 1,
		string.format("ok %s, result %s, backend calls %d", tostring(ok), tostring(result), #rec.calls)
	)
	-- through a real capture
	host.api.setProfile("Desktop")
	host.api.setSpeed(0)
	freshRun(host)
	host.api.backdrop.hold(0)
	confirm(host, "hap-u-" .. nonce(), ownedFalse(host, "rev6"), 100)
	host.wait(0.6)
	verdict(
		host,
		"A confirmed claim on this hardware: shown, no haptic call",
		dbg(host, "ribbon").haptic == "unsupported" and rec.starts == 0 and dbg(host, "reveal").playing == true,
		string.format("ribbon says %s, starts %d", tostring(dbg(host, "ribbon").haptic), rec.starts)
	)
	host.wait(2.2)
	host.api.setSpeed(nil)
	-- the Settings row: still shown, with its reason, and it cannot be turned on
	goHome(host)
	host.api.setProfile("Desktop")
	host.api.open("settings")
	host.wait(0.5)
	local d = dbg(host, "settings").haptics
	verdict(
		host,
		"The row is shown, dimmed and disabled, OFF, with a plain reason",
		d.supported == false
			and d.switchEnabled == false
			and d.dimmed == true
			and d.switchOn == false
			and d.switchWord == "OFF"
			and d.stateLine == "Not available on this device"
			and d.stateLineFits == true,
		string.format(
			"supported %s, enabled %s, dimmed %s, word %s, line %q fits %s",
			tostring(d.supported),
			tostring(d.switchEnabled),
			tostring(d.dimmed),
			tostring(d.switchWord),
			tostring(d.stateLine),
			tostring(d.stateLineFits)
		)
	)
	local settings = comp(host, "settings")
	local preference = host.store:get().settings.haptics
	settings:_setHaptics(true) -- what a press would do
	local d2 = dbg(host, "settings").haptics
	verdict(
		host,
		"A press changes nothing: the preference is untouched and the switch stays OFF",
		host.store:get().settings.haptics == preference and d2.switchWord == "OFF" and rec.starts == 0,
		string.format(
			"preference %s -> %s, word %s",
			tostring(preference),
			tostring(host.store:get().settings.haptics),
			tostring(d2.switchWord)
		)
	)
	host.api.close("settings")
	-- a controller-only device: a cue is requested, and turning it off writes 0 to the motors
	rec.gamepad = true
	local result2 = Haptics.confirm(true)
	local stopped = Haptics.stop()
	verdict(
		host,
		"A controller-only device: one cue, then the motors are written 0 on stop",
		result2 == "requested" and stopped == 1 and rec.motorOffs == 1 and rec.live == 0,
		string.format(
			"result %s, stopped %d, motor writes of 0: %d, calls %s",
			result2,
			stopped,
			rec.motorOffs,
			table.concat(rec.calls, ",")
		)
	)
	hapticsDone(host)
end

S["Haptics: Settings row on every frame"] = function(host: Host)
	recorderOn(host, { touch = true })
	goHome(host)
	for _, profile in host.api.profiles do
		host.api.setProfile(profile)
		host.wait(0.3)
		host.api.open("settings")
		host.wait(0.5)
		local d = dbg(host, "settings")
		local h = d.haptics
		verdict(
			host,
			"Haptics row on " .. profile,
			h.supported == true
				and h.switchOn == true
				and h.switchWord == "ON"
				and h.stateLine == "Buzz when you get a car"
				and h.stateLineFits == true
				and h.switchEnabled == true
				and h.hitHeight >= 48
				and d.cardHeight <= d.safeHeight,
			string.format(
				"word %s, line %q fits %s, hit %s px, card %s of %s px (%s)",
				tostring(h.switchWord),
				tostring(h.stateLine),
				tostring(h.stateLineFits),
				tostring(h.hitHeight),
				tostring(d.cardHeight),
				tostring(d.safeHeight),
				if h.compact then "compact" else "normal"
			)
		)
		host.api.close("settings")
		host.wait(0.2)
	end
	host.api.setProfile("Desktop")
	hapticsDone(host)
end

S["Haptics: Settings row (reduced motion)"] = function(host: Host)
	recorderOn(host, { touch = true })
	goHome(host)
	host.api.setProfile("Desktop")
	Motion.setOverride(true)
	host.api.open("settings")
	host.wait(0.5)
	local settings = comp(host, "settings")
	local function knob(): UDim2
		local track = settings._haptics.root:FindFirstChild("Track") :: Frame
		return (track:FindFirstChild("Knob") :: Frame).Position
	end
	local h = dbg(host, "settings").haptics
	verdict(
		host,
		"Reduced motion is in effect and the row reads ON",
		Motion.reduced() == true
			and h.switchOn == true
			and h.switchWord == "ON"
			and h.stateLine == "Buzz when you get a car"
			and knob().X.Scale == 1
			and knob().X.Offset == -40,
		string.format("word %s, line %q, knob at %s", tostring(h.switchWord), tostring(h.stateLine), tostring(knob()))
	)
	settings:_setHaptics(false) -- what a press does; no waiting: reduced motion snaps at once
	local off = dbg(host, "settings").haptics
	verdict(
		host,
		"OFF reads OFF at once, and the store follows",
		off.switchOn == false
			and off.switchWord == "OFF"
			and off.stateLine == "Buzz is off"
			and knob().X.Scale == 0
			and knob().X.Offset == 4
			and host.store:get().settings.haptics == false,
		string.format(
			"word %s, line %q, knob at %s, store %s",
			tostring(off.switchWord),
			tostring(off.stateLine),
			tostring(knob()),
			tostring(host.store:get().settings.haptics)
		)
	)
	settings:_setHaptics(true)
	local on = dbg(host, "settings").haptics
	verdict(
		host,
		"ON again reads ON at once",
		on.switchOn == true
			and on.switchWord == "ON"
			and on.stateLine == "Buzz when you get a car"
			and host.store:get().settings.haptics == true,
		string.format("word %s, line %q", tostring(on.switchWord), tostring(on.stateLine))
	)
	host.api.close("settings")
	hapticsDone(host)
end

S["Haptics: toggling mid-effect and no leak"] = function(host: Host)
	local rec = recorderOn(host, { touch = true })
	local first = Haptics.confirm(true)
	host.wait(0.2)
	Haptics.setEnabled(host.store, false) -- off in the middle of the effect
	host.wait(0.2)
	Haptics.setEnabled(host.store, true) -- on again: it must NOT resume
	verdict(
		host,
		"Off then on mid-effect: the cue stays stopped",
		first == "requested" and rec.starts == 1 and rec.stops == 1 and rec.live == 0 and Haptics.counts().active == 0,
		string.format("calls %s, live %d", table.concat(rec.calls, ","), rec.live)
	)
	host.wait(1.8) -- past the 1.5 s timer: it was cancelled with the effect, so no second stop
	verdict(
		host,
		"No second stop from the cancelled timer",
		table.concat(rec.calls, ",") == "start,stop" and rec.stops == 1,
		table.concat(rec.calls, ",")
	)
	-- many cues with the switch flipped between them, then nothing may be left running
	for i = 1, 20 do
		Haptics.confirm(true)
		if i % 2 == 0 then
			Haptics.setEnabled(host.store, false)
			Haptics.setEnabled(host.store, true)
		end
	end
	Haptics.confirm(true) -- one last cue left to the timer
	host.wait(1.8)
	verdict(
		host,
		"After 22 cues and 10 switch flips nothing is left running",
		Haptics.counts().active == 0 and rec.live == 0 and rec.starts == rec.stops,
		string.format(
			"starts %d, stops %d, live %d, active %d",
			rec.starts,
			rec.stops,
			rec.live,
			Haptics.counts().active
		)
	)
	-- the real backend: no effect instance is left in Workspace (a desktop without haptics makes none at all)
	Haptics.useBackend(nil)
	for _ = 1, 5 do
		Haptics.confirm(true)
	end
	host.wait(1.8)
	local leftovers = 0
	for _, d in Workspace:GetChildren() do
		if d:IsA("HapticEffect") then
			leftovers += 1
		end
	end
	verdict(
		host,
		"The real backend leaves no HapticEffect behind",
		leftovers == 0 and Haptics.counts().active == 0,
		string.format(
			"%d left in Workspace, %d active (supported here: %s)",
			leftovers,
			Haptics.counts().active,
			tostring(Haptics.isSupported())
		)
	)
	hapticsDone(host)
end

return S
