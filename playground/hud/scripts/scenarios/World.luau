--!strict
-- PLAYGROUND ONLY (Lane 3 HUD rebuild 2026-10-22, worker HW): world presentation scenarios.
-- Every value is a synthetic fixture. Each scenario builds its own proxy cars and stand-ins in a
-- "WorldScenario" folder under the backdrop's world folder, on open grass beside the backdrop
-- road, and frames them with api.setCamera. Cleanup is guaranteed: a watcher thread notices when
-- the scenario stops being current (finished, cancelled or replaced) and then destroys the
-- folder, restores the shared components it touched (nameplates, Hop ring, arc, capture, warn,
-- tumble) and releases the camera; starting any World scenario also cleans a leftover one.
-- Components are taken from api.components when mounted, otherwise created locally (and
-- destroyed on cleanup), so the scenarios also work before the lead adds the mount lines.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Prototype = Players.LocalPlayer
	:WaitForChild("PlayerScripts")
	:WaitForChild("Client")
	:WaitForChild("UI")
	:WaitForChild("Prototype")
local World = Prototype:WaitForChild("World")
local Fixtures = require(Prototype:WaitForChild("Fixtures"))
local Motion = require(Prototype:WaitForChild("Motion"))
local ProxyCar = require(Prototype:WaitForChild("ProxyCar"))
local WorldKit = require(World:WaitForChild("WorldKit"))
local Trove = require(ReplicatedStorage.Packages.Trove)

-- open grass west of the backdrop road (roadside blocks end at x = -80; the Home lot is at z > -5)
local STAGE = CFrame.new(-170, 0, -170)
local BASE = CFrame.new(-170, 0, -330)
local DEST = CFrame.new(-190, 0, -520)

type Env = {
	host: any,
	api: any,
	folder: Folder,
	ctx: any,
	trove: any,
	finish: () -> (),
	use: (key: string, module: string, options: any?) -> any,
	car: (id: string, cf: CFrame, patch: { [string]: any }?) -> (Model, any),
	look: (eye: Vector3, at: Vector3) -> (),
	log: (label: string, value: any) -> (),
}

local active: Env? = nil

local function begin(host: any, name: string): Env
	local api = host.api
	if active then
		active.finish()
	end
	local world: Folder = api.backdrop.world
	local old = world:FindFirstChild("WorldScenario")
	if old then
		old:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = "WorldScenario"
	folder.Parent = world
	local trove = Trove.new()
	local done = false
	local cameraSet = false
	local env: Env
	local ctx = {
		store = api.store,
		screen = api.screen,
		layer = api.layers.Feedback,
		world = folder,
		priority = api.priority,
	}
	local function finish()
		if done then
			return
		end
		done = true
		trove:Destroy()
		folder:Destroy()
		Motion.setOverride(nil)
		if cameraSet then
			api.setCamera(nil, nil)
		end
		if active == env then
			active = nil
		end
	end
	env = {
		host = host,
		api = api,
		folder = folder,
		ctx = ctx,
		trove = trove,
		finish = finish,
		use = function(key: string, module: string, options: any?): any
			local mounted = api.components[key]
			if mounted then
				return mounted
			end
			local created = require(World:WaitForChild(module) :: ModuleScript).new(ctx, options)
			trove:Add(function()
				created:destroy()
			end)
			return created
		end,
		car = function(id: string, cf: CFrame, patch: { [string]: any }?): (Model, any)
			local base = Fixtures.byId(id) or Fixtures.Cars[1]
			local car = table.clone(base) :: any
			for k, v in patch or {} do
				car[k] = v
			end
			-- `owned` may be explicitly unknown: patch.owned = "unknown" -> nil
			if car.owned == "unknown" then
				car.owned = nil
			end
			local m = ProxyCar.build(car)
			WorldKit.seat(m, cf)
			m.Parent = folder
			return m, car
		end,
		look = function(eye: Vector3, at: Vector3)
			cameraSet = true
			api.setCamera(eye, at)
		end,
		log = function(label: string, value: any)
			local ok, json = pcall(function()
				return HttpService:JSONEncode(value)
			end)
			host.log("[World] " .. label .. ": " .. (if ok then json else tostring(value)))
		end,
	}
	active = env
	-- watcher: cleans up when this scenario is no longer the current one
	task.spawn(function()
		local scenarios = api.scenarios
		while not done do
			task.wait(0.25)
			if not scenarios or scenarios.current ~= name then
				finish()
			end
		end
	end)
	return env
end

local function at(x: number, z: number): CFrame
	return STAGE * CFrame.new(x, 0, z)
end

-- the shared nameplates; anything the scenario tracked is untracked again on cleanup
local function plates(env: Env): any
	local p = env.use("nameplates", "Nameplates")
	local ids: { string } = {}
	env.trove:Add(function()
		for _, id in ids do
			p:untrack(id)
		end
		p:setRidden(nil)
		p:setTarget(nil)
		p:setCap(nil)
	end)
	return {
		component = p,
		track = function(id: string, model: Model, car: any)
			table.insert(ids, id)
			p:track(id, model, car)
		end,
	}
end

-- restores the playground's own wiring of the ride-bound effects after a scenario
local function restoreRide(env: Env, component: any, kind: "id" | "plain")
	env.trove:Add(function()
		local ride = env.api.backdrop.ride
		if component and component.setRide then
			if kind == "id" then
				component:setRide("ride", ride)
			else
				component:setRide(ride)
			end
		end
	end)
end

local function restoreRing(env: Env, ring: any, arc: any?)
	env.trove:Add(function()
		local api = env.api
		local run = api.store:get().mode == "Run"
		if ring then
			ring:setTarget(api.backdrop.target)
			ring:setState(if run then "Available" else "Hidden")
		end
		if arc then
			arc:setRide(api.backdrop.ride)
			arc:setTarget(api.backdrop.target)
			arc:setState(if run then "Available" else "Hidden")
		end
	end)
end

local scenarios: { [string]: (host: any) -> () } = {}

scenarios["World: nameplate crowding (12 cars, cap, overlap)"] = function(host)
	local env = begin(host, "World: nameplate crowding (12 cars, cap, overlap)")
	local np = plates(env)
	local roster = {
		{ "puglet", 0, 0, {} }, -- ridden
		{ "rev6", 0, -30, {} }, -- Hop target
		{ "hurrikan", -13, -42, {} },
		{ "zoomurai", 13, -46, {} },
		{ "waffle", 0, -58, { owned = true } },
		{ "rangy", 0, -66, {} }, -- directly behind: overlaps on screen
		{ "hyperion", -13, -70, {} },
		{ "fishbowl", 13, -78, { owned = true } },
		{ "puglet", -13, -96, { owned = true } },
		{ "rev6", 13, -104, { owned = true } },
		{ "hurrikan", 0, -118, {} }, -- beyond the fade end
		{ "waffle", -13, -132, { owned = "unknown" } },
	}
	for i, r in roster do
		local m, car = env.car(r[1], at(r[2], r[3]), r[4])
		np.track("crowd-" .. i, m, car)
	end
	local p = np.component
	p:setRidden("crowd-1")
	p:setTarget("crowd-2")
	local ride = at(0, 0).Position
	env.look(ride + Vector3.new(0, 8, 16), ride + Vector3.new(0, 2, -40))
	host.wait(2.5)
	env.log("cap default", p:getDebugState())
	p:setCap(4)
	host.wait(2.5)
	env.log("cap 4 (phone)", p:getDebugState())
	p:setCap(6)
	-- slow sideways camera drift: plates fade in/out with hysteresis, never jump
	for step = 0, 40 do
		local x = math.sin(step / 40 * math.pi) * 14
		env.look(ride + Vector3.new(x, 8, 16), ride + Vector3.new(x * 0.4, 2, -40))
		host.wait(0.1)
	end
	env.log("after drift", p:getDebugState())
	-- retarget to a far car: the target plate stays (clamped size, always on top)
	p:setTarget("crowd-11")
	host.wait(2)
	env.log("far target", p:getDebugState())
	host.wait(1)
	env.finish()
end

scenarios["World: NEW unknown/owned/unowned + variants"] = function(host)
	local env = begin(host, "World: NEW unknown/owned/unowned + variants")
	local np = plates(env)
	np.component:setCap(6)
	local rows = {
		{ "rev6", { owned = "unknown" }, "unknown -> no NEW!" },
		{ "rev6", { owned = true }, "owned -> no NEW!" },
		{ "rev6", { owned = false }, "unowned -> NEW!" },
		{ "puglet", { variant = "Gold", owned = false }, "Gold variant, NEW!" },
		{ "rev6", { variant = "Chrome", owned = true }, "Chrome variant, owned" },
		{ "waffle", { variant = "Rainbow", owned = "unknown" }, "Rainbow variant, unknown" },
	}
	for i, r in rows do
		local x = (i - 3.5) * 16
		local m, car = env.car(r[1], at(x, -40), r[2])
		np.track("new-" .. i, m, car)
		host.log("[World] plate new-" .. i .. ": " .. r[3])
	end
	local c = at(0, -40).Position
	env.look(c + Vector3.new(0, 14, 62), c + Vector3.new(0, 4, 0))
	host.wait(4)
	env.log("plates", np.component:getDebugState())
	host.wait(2)
	env.finish()
end

scenarios["World: rare reveal dedupe (same car leaves/re-enters, 5 rares at once)"] = function(host)
	local env = begin(host, "World: rare reveal dedupe (same car leaves/re-enters, 5 rares at once)")
	host.enterRun()
	host.wait(0.5)
	local reveal = env.use("rareReveal", "RareReveal")
	local function arrive(id: string, carId: string, patch: { [string]: any }?)
		local car = table.clone(host.car(carId)) :: any
		for k, v in patch or {} do
			car[k] = v
		end
		host.emit("RareArrival", { instanceId = id, car = car })
	end
	arrive("traffic-A", "rev6", { owned = false })
	host.wait(1)
	arrive("traffic-A", "rev6", { owned = false }) -- same car again: deduped
	host.wait(6)
	arrive("traffic-A", "rev6", { owned = false }) -- left and re-entered later: still deduped
	host.wait(0.5)
	env.log("after re-entry", reveal:getDebugState())
	host.wait(1)
	-- five rares at once: the Legendary shows, the best of the rest waits in the one slot
	arrive("traffic-B", "rev6")
	arrive("traffic-C", "hurrikan")
	arrive("traffic-D", "hyperion", { owned = false })
	arrive("traffic-E", "zoomurai")
	arrive("traffic-F", "hurrikan", { owned = true })
	host.wait(0.5)
	env.log("five at once", reveal:getDebugState())
	host.wait(6.5) -- the queued Epic shows after the cooldown
	env.log("queued shown", reveal:getDebugState())
	arrive("traffic-G", "puglet") -- Common: ignored
	host.wait(3)
	-- quiet time: a warning silences reveals (dropped, never queued for later)
	host.runPatch({ warning = { id = "w-reveal", reason = "TooHot" } })
	arrive("traffic-H", "hyperion")
	host.wait(0.5)
	local run = host.store:get().run
	if run then
		local cleared = table.clone(run)
		cleared.warning = nil -- runPatch cannot carry a nil, so clear the field directly
		host.store:set("run", cleared)
	end
	env.log("silenced", reveal:getDebugState())
	host.wait(1)
	env.finish()
end

scenarios["World: car despawn and Hop retarget"] = function(host)
	local env = begin(host, "World: car despawn and Hop retarget")
	local ring = env.use("hopRing", "HopRing")
	local arc = env.use("hopArc", "ArcTelegraph")
	restoreRing(env, ring, arc)
	local np = plates(env)
	local rideModel, rideCar = env.car("puglet", at(0, 0))
	local a, carA = env.car("rev6", at(-13, -32))
	local b, carB = env.car("hurrikan", at(13, -38), { owned = false })
	local c, carC = env.car("fishbowl", at(0, -60))
	np.track("hop-ride", rideModel, rideCar)
	np.track("hop-a", a, carA)
	np.track("hop-b", b, carB)
	np.track("hop-c", c, carC)
	np.component:setRidden("hop-ride")
	local ride = at(0, 0).Position
	env.look(ride + Vector3.new(0, 9, 18), ride + Vector3.new(0, 2, -40))
	arc:setRide(rideModel)
	local function target(model: Model?, id: string?)
		ring:setTarget(model)
		arc:setTarget(model)
		np.component:setTarget(id)
	end
	target(a, "hop-a")
	ring:setState("Available")
	arc:setState("Available")
	host.wait(2.5)
	env.log("target A", { ring = ring:getDebugState(), arc = arc:getDebugState() })
	target(b, "hop-b") -- clean retarget: one ring, moved; the previous one is gone
	host.wait(2.5)
	env.log("retarget B", { ring = ring:getDebugState(), arc = arc:getDebugState() })
	ring:setState("Unavailable")
	arc:setState("Unavailable")
	host.wait(2.5)
	env.log("unavailable", { ring = ring:getDebugState(), arc = arc:getDebugState() })
	ring:setState("Timing")
	arc:setState("Timing")
	host.wait(2.5)
	b:Destroy() -- despawn the target
	host.wait(0.6)
	env.log("despawned B", {
		ring = ring:getDebugState(),
		arc = arc:getDebugState(),
		plates = np.component:getDebugState(),
	})
	target(c, "hop-c")
	ring:setState("Available")
	arc:setState("Available")
	host.wait(2.5)
	Motion.setOverride(true)
	ring:setState("Timing")
	host.wait(2)
	env.log("reduced motion timing", ring:getDebugState())
	env.finish()
end

scenarios["World: ring sizes compact vs bus"] = function(host)
	local env = begin(host, "World: ring sizes compact vs bus")
	local ring = env.use("hopRing", "HopRing")
	restoreRing(env, ring, nil)
	local bike = env.car("zoomurai", at(-16, -30))
	local hatch = env.car("puglet", at(0, -30))
	local bus = env.car("fishbowl", at(18, -34))
	local c = at(0, -30).Position
	env.look(c + Vector3.new(0, 26, 34), c)
	for _, m in { bike, hatch, bus } do
		ring:setTarget(m)
		ring:setState("Available")
		host.wait(2.5)
		env.log(m.Name, ring:getDebugState())
	end
	ring:setState("Unavailable")
	host.wait(2.5)
	env.log("bus unavailable", ring:getDebugState())
	env.finish()
end

scenarios["World: capture outline + particles"] = function(host)
	local env = begin(host, "World: capture outline + particles")
	local capture = env.use("captureFx", "CaptureFx")
	local warn = env.use("warnFx", "WarnFx")
	restoreRide(env, capture, "id")
	restoreRide(env, warn, "id")
	local np = plates(env)
	local model, car = env.car("rev6", at(0, 0), { owned = false })
	np.track("cap-ride", model, car)
	np.component:setRidden("cap-ride")
	capture:setRide("cap-ride", model)
	capture:setNameplates(np.component)
	warn:setRide("cap-ride", model)
	env.trove:Add(function()
		capture:setNameplates(env.api.components.nameplates)
	end)
	local p = at(0, 0).Position
	env.look(p + Vector3.new(10, 9, 20), p + Vector3.new(0, 2, 0))
	host.emit("KeysStart", { captureId = "cap-1", car = car })
	host.wait(3)
	env.log("capturing", capture:getDebugState())
	host.emit("KeysStart", { captureId = "cap-1", car = car }) -- duplicate: no restart
	host.emit("KeysConfirmed", { captureId = "cap-1", car = car })
	host.wait(2)
	host.emit("KeysConfirmed", { captureId = "cap-1", car = car }) -- duplicate: no second burst
	env.log("confirmed", capture:getDebugState())
	host.emit("KeysStart", { captureId = "cap-2", car = car })
	host.wait(2)
	host.emit("KeysCanceled", { captureId = "cap-2", reason = "You hopped off" })
	host.wait(1)
	host.emit("KeysStart", { captureId = "cap-2", car = car }) -- late start after cancel: ignored
	env.log("canceled", capture:getDebugState())
	-- warning wins over the capture outline, then the outline comes back
	host.emit("KeysStart", { captureId = "cap-3", car = car })
	host.wait(1.5)
	warn:show("w-cap", "TooHot")
	host.wait(2.5)
	env.log("warning over capture", { capture = capture:getDebugState(), warn = warn:getDebugState() })
	warn:clear()
	host.wait(1.5)
	host.emit("KeysCanceled", { captureId = "cap-3" })
	host.wait(1)
	-- reduced motion: steady outline, no sparkles, no burst
	Motion.setOverride(true)
	host.emit("KeysStart", { captureId = "cap-4", car = car })
	host.wait(2)
	host.emit("KeysConfirmed", { captureId = "cap-4", car = car })
	host.wait(1)
	env.log("reduced motion", capture:getDebugState())
	-- despawn mid-capture cleans everything
	Motion.setOverride(nil)
	host.emit("KeysStart", { captureId = "cap-5", car = car })
	host.wait(1)
	model:Destroy()
	host.wait(0.5)
	env.log("despawned", capture:getDebugState())
	env.finish()
end

scenarios["World: warning emphasis + tumble proxy"] = function(host)
	local env = begin(host, "World: warning emphasis + tumble proxy")
	local warn = env.use("warnFx", "WarnFx")
	local tumble = env.use("tumble", "TumbleProxy")
	restoreRide(env, warn, "id")
	restoreRide(env, tumble, "plain")
	local model = env.car("puglet", at(0, 0), { variant = "Chrome" })
	warn:setRide("warn-ride", model)
	tumble:setRide(model)
	local p = at(0, 0).Position
	env.look(p + Vector3.new(14, 10, 22), p + Vector3.new(4, 2, 0))
	host.emit("RunWarning", { reason = "TooHot" })
	host.wait(3.5)
	env.log("warning", warn:getDebugState())
	warn:clear()
	host.wait(0.8)
	warn:show("w-unknown", "SomethingNew") -- unknown reason: truthful fallback text
	host.wait(2)
	host.emit("Dismounted", { reason = "Overheated" }) -- warning clears; the proxy tumbles off
	host.wait(4)
	env.log("after tumble", { warn = warn:getDebugState(), tumble = tumble:getDebugState() })
	Motion.setOverride(true)
	warn:show("w-rm", "TooHot")
	host.wait(2)
	warn:clear()
	tumble:play(nil)
	host.wait(3)
	env.log("reduced motion", { warn = warn:getDebugState(), tumble = tumble:getDebugState() })
	env.finish()
end

scenarios["World: destination labels near/far/occluded"] = function(host)
	local env = begin(host, "World: destination labels near/far/occluded")
	local fixtures = require(World:WaitForChild("BaseFixtures") :: ModuleScript).new(env.ctx)
	env.trove:Add(function()
		fixtures:destroy()
	end)
	local labels = fixtures:placeDestinations(DEST)
	local centre = (DEST * CFrame.new(0, 10, 0)).Position
	local function report(label: string)
		local out = {}
		for _, l in labels do
			table.insert(out, l:getDebugState())
		end
		env.log(label, out)
	end
	env.look(centre + Vector3.new(0, 4, 60), centre) -- near
	host.wait(3)
	report("near")
	env.look(centre + Vector3.new(0, 30, 240), centre) -- far: minimum size, readable
	host.wait(3)
	report("far")
	env.look(centre + Vector3.new(0, 40, 330), centre) -- past maxDistance: gone, not a speck
	host.wait(3)
	report("beyond max distance")
	local summit = (DEST * CFrame.new(48, 6, 40)).Position -- behind the wall: occluded
	env.look(summit, (DEST * CFrame.new(48, 12, 0)).Position)
	host.wait(3)
	report("occluded")
	env.look(centre + Vector3.new(-90, 12, 30), centre) -- side angle: still faces the camera
	host.wait(3)
	env.finish()
end

scenarios["World: ground markers active/inactive"] = function(host)
	local env = begin(host, "World: ground markers active/inactive")
	local GroundMarker = require(World:WaitForChild("GroundMarker") :: ModuleScript)
	local markers = {}
	local specs = {
		{ x = -16, d = 6, colour = Color3.fromRGB(255, 206, 40) },
		{ x = 0, d = 10, colour = Color3.fromRGB(186, 92, 255) },
		{ x = 18, d = 14, colour = Color3.fromRGB(60, 200, 110) },
	}
	for _, s in specs do
		local m = GroundMarker.new(env.ctx, { position = at(s.x, -24).Position, diameter = s.d, colour = s.colour })
		env.trove:Add(function()
			m:destroy()
		end)
		table.insert(markers, m)
	end
	-- the Hop ring beside them for the "distinct from the Hop ring" comparison
	local ring = env.use("hopRing", "HopRing")
	restoreRing(env, ring, nil)
	local car = env.car("puglet", at(0, -50))
	ring:setTarget(car)
	ring:setState("Available")
	local c = at(0, -32).Position
	env.look(c + Vector3.new(0, 22, 34), c)
	host.wait(3)
	markers[2]:setActive(false)
	host.wait(3)
	env.log("inactive middle", markers[2]:getDebugState())
	markers[2]:setActive(true)
	Motion.setOverride(true) -- reduced motion: steady
	host.wait(3)
	env.log("reduced motion", markers[1]:getDebugState())
	env.finish()
end

scenarios["World: base fixtures tour"] = function(host)
	local env = begin(host, "World: base fixtures tour")
	local fixtures = require(World:WaitForChild("BaseFixtures") :: ModuleScript).new(env.ctx)
	env.trove:Add(function()
		fixtures:destroy()
	end)
	fixtures:place(BASE)
	local pts = fixtures:points()
	local function view(point: Vector3, offset: Vector3, seconds: number)
		env.look(point + offset, point)
		host.wait(seconds)
	end
	view(pts.lineup, Vector3.new(4, 6, 20), 3)
	env.look(pts.lapPay + Vector3.new(2, 5, 18), pts.lapPay)
	host.wait(0.5)
	fixtures:payLap(120)
	host.wait(0.4)
	fixtures:payLap(120) -- merges into one label
	host.wait(2)
	view(pts.board, Vector3.new(0, 1, 16), 3)
	view(pts.plaque, Vector3.new(0, 1, 9), 3)
	view(pts.start, Vector3.new(0, 7, 14), 3)
	env.look(pts.start + Vector3.new(0, 6, 10), pts.portal)
	host.wait(3)
	env.look(pts.gate + Vector3.new(6, 5, 22), pts.gate)
	host.wait(0.4)
	fixtures:arrive()
	host.wait(2.5)
	env.log("fixtures", fixtures:getDebugState())
	env.finish()
end

scenarios["World: arrival sparkle"] = function(host)
	local env = begin(host, "World: arrival sparkle")
	local fixtures = require(World:WaitForChild("BaseFixtures") :: ModuleScript).new(env.ctx)
	env.trove:Add(function()
		fixtures:destroy()
	end)
	fixtures:place(BASE)
	local gate = fixtures:points().gate
	env.look(gate + Vector3.new(4, 6, 24), gate)
	host.wait(0.6)
	host.emit("ArrivedHome", {})
	host.wait(0.5)
	host.emit("ArrivedHome", {}) -- within the repeat guard: ignored
	host.wait(2.5)
	env.log("sparkle", fixtures:getDebugState().sparkle)
	Motion.setOverride(true) -- reduced motion: a soft glow fade only
	host.emit("ArrivedHome", {})
	host.wait(2.5)
	env.log("reduced motion", fixtures:getDebugState().sparkle)
	env.finish()
end

return scenarios
