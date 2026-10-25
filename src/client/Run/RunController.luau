--!strict
-- One collection run, played on the player's device (outline section 06, Stage 1 prototype),
-- tuned to play like a rodeo-style stampede game: the rider rides inside the car, a weaving herd of
-- traffic of mixed sizes, a catch meter over the rider (the Keys), "Needs N" gates on stronger
-- cars, a tray of cars caught this run, free revives and rare-car alerts.
--
-- Team names stay: Heat (the time limit on each car, reset on every Hop, decision 0008) and Keys
-- (the catch meter, timed by rarity). What this does NOT do yet, by design for Stage 1: no
-- remotes, no saving, no Cash. Ownership, Rider Level and revives live in a session table the
-- playground keeps, so the Joyride and Needs paths can be felt. Every event is recorded in
-- run-report shape (RunReport) for Lane 2 later.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Families = require(ReplicatedStorage.Shared.Run.Families)
local RunConfig = require(ReplicatedStorage.Shared.Run.RunConfig)
local RunSequence = require(ReplicatedStorage.Shared.Run.RunSequence)
local Signal = require(ReplicatedStorage.Packages.Signal)
local Trove = require(ReplicatedStorage.Packages.Trove)

local CarTags = require(script.Parent.CarTags)
local CarVisual = require(script.Parent.CarVisual)
local ChaseCamera = require(script.Parent.ChaseCamera)
local RunFx = require(script.Parent.RunFx)
local RunInput = require(script.Parent.RunInput)
local RunOverlay = require(script.Parent.RunOverlay)
local RunReport = require(script.Parent.RunReport)
local RunRoad = require(script.Parent.RunRoad)

type Mode = "Riding" | "Hopping" | "FootDash" | "Ended"
type Stage = "Calm" | "Warning" | "Critical" | "Meltdown"

type Car = {
	index: number, -- spawn index; 0 for a Loaner
	spawn: RunSequence.Spawn?,
	family: Families.Family,
	rarity: RunConfig.Rarity,
	size: RunConfig.Size,
	variant: RunConfig.Variant,
	modelId: string,
	model: Model,
	tag: BillboardGui?,
	length: number,
	width: number,
	height: number,
	roof: number,
	seat: number, -- where the rider sits: inside the cabin, or on the saddle of an open vehicle
	needs: number,
	along: number,
	lateral: number,
	lane: number,
	retired: boolean, -- was ridden; drifts with traffic, off the seed schedule
	fade: number?, -- seconds left before a drifting car with nowhere to go disappears
	keysDone: boolean,
	bumpCooldown: number,
}

type Hop = {
	startT: number,
	fromAlong: number,
	fromLateral: number,
	fromUp: number,
	target: Car,
	inPlace: boolean,
	fromFoot: boolean,
	nudge: number,
}

-- Kept by the playground across runs in one playtest. Not saved anywhere.
export type Session = {
	owned: { [string]: boolean },
	level: number,
	revives: number,
}

export type Options = {
	seed: number?,
	session: Session?,
	profile: string?, -- "Highway" (default) or "Circuit"

	hud: boolean?, -- drive Lane 3's RunHud (default true when it exists)
}

export type DebugState = {
	seed: number,
	mode: Mode,
	t: number,
	metres: number,
	speed: number,
	along: number,
	lateral: number,
	family: string?,
	rarity: string?,
	size: string?,
	needs: number?,
	level: number,
	revives: number,
	heat: number,
	stage: Stage,
	meltdownLeft: number?,
	keys: number?,
	keysNeed: number?,
	tooStrong: boolean,
	footDashLeft: number?,
	target: number?,
	targetDistance: number?,
	aheadGap: number?,
	cars: number,
	hops: number,
	claimed: { string },
	joyrides: number,
	saves: number,
	bumps: number,
	events: { [string]: number },
	cause: string?,
}

export type RunController = {
	seed: number,
	Ended: any, -- Signal(results) fired when the player presses Retry
	start: (self: RunController) -> (),
	requestHop: (self: RunController) -> (),
	revive: (self: RunController) -> boolean,
	setSteerOverride: (self: RunController, steer: number?) -> (),
	forceMiss: (self: RunController) -> (),
	getDebugState: (self: RunController) -> DebugState,
	destroy: (self: RunController) -> (),
}

local RunController = {}
RunController.__index = RunController

local BIND_NAME = "Lane1Run"
local SIT_UP = 1.7 -- HumanoidRootPart above the roof while seated
local ROOT_UP = 3 -- HumanoidRootPart above the feet when standing
local TAG_RANGE = 170

local function stageFor(heat: number, melting: boolean): Stage
	if melting then
		return "Meltdown"
	elseif heat >= RunConfig.HEAT_CRITICAL then
		return "Critical"
	elseif heat >= RunConfig.HEAT_WARNING then
		return "Warning"
	end
	return "Calm"
end

local function nearestLane(lateral: number): number
	local best, bestDist = 1, math.huge
	for lane = 1, RunConfig.LANES do
		local d = math.abs(RunConfig.laneCenter(lane) - lateral)
		if d < bestDist then
			best, bestDist = lane, d
		end
	end
	return best
end

local function setModelTransparency(model: Model, transparency: number)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.LocalTransparencyModifier = transparency
		end
	end
end

local function carName(car: Car): string
	return CarTags.title({
		family = car.family.name,
		rarity = car.rarity,
		size = car.size,
		variant = car.variant,
		odds = 1,
		needs = car.needs,
		owned = false,
	})
end

function RunController.new(options: Options?): RunController
	local opts: Options = options or {}
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")
	local seed = opts.seed or Random.new():NextInteger(1, 2 ^ 30)
	local trove = Trove.new()
	local session: Session = opts.session
		or { owned = {}, level = RunConfig.START_RIDER_LEVEL, revives = RunConfig.FREE_REVIVES }

	local zone = trove:Add(Instance.new("Folder"))
	zone.Name = "Lane1_RunZone"
	local carsFolder = Instance.new("Folder")
	carsFolder.Name = "Traffic"
	carsFolder.Parent = zone

	local ring = Instance.new("Part")
	ring.Name = "HopRing"
	ring.Shape = Enum.PartType.Cylinder
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	ring.CanTouch = false
	ring.CastShadow = false
	ring.Material = Enum.Material.Neon
	ring.Color = Color3.fromRGB(255, 214, 70)
	ring.Transparency = 1
	ring.Size = Vector3.new(0.2, 10, 10)
	ring.Parent = zone
	local arrow = Instance.new("Part")
	arrow.Name = "HopArrow"
	arrow.Anchored = true
	arrow.CanCollide = false
	arrow.CanQuery = false
	arrow.CanTouch = false
	arrow.CastShadow = false
	arrow.Material = Enum.Material.Neon
	arrow.Color = Color3.fromRGB(255, 214, 70)
	arrow.Shape = Enum.PartType.Ball
	arrow.Size = Vector3.new(1.4, 1.4, 1.4)
	arrow.Transparency = 1
	arrow.Parent = zone

	local self = setmetatable({}, RunController) :: any
	self.seed = seed
	self.Ended = trove:Add(Signal.new())
	self._trove = trove
	self._player = player
	self._zone = zone
	self._carsFolder = carsFolder
	self._ring = ring
	self._arrow = arrow
	self._session = session
	self._profile = RunConfig.profile(opts.profile)
	self._sequence = RunSequence.new(seed, self._profile)
	self._road = trove:Add(RunRoad.new(zone, seed, self._profile.scenery), "destroy")
	self._fx = trove:Add(RunFx.new(zone), "destroy")
	self._input = trove:Add(RunInput.new(), "destroy")
	self._overlay = trove:Add(RunOverlay.new(playerGui), "destroy")
	self._report = trove:Add(RunReport.new(seed), "destroy")
	self._meter = CarTags.rideMeter(zone)
	self._camera = nil
	self._hud = nil
	if opts.hud ~= false then
		local ui = script.Parent.Parent:FindFirstChild("UI")
		local hudModule = ui and ui:FindFirstChild("RunHud")
		if hudModule and hudModule:IsA("ModuleScript") then
			local ok, RunHud = pcall(require, hudModule)
			if ok then
				local created, hud = pcall((RunHud :: any).new, playerGui, { name = "RunHud" })
				if created then
					self._hud = trove:Add(hud, "destroy")
				else
					warn("[Lane1Run] RunHud could not start: " .. tostring(hud))
				end
			end
		end
	end

	-- Run state.
	self._mode = "Riding" :: Mode
	self._t = 0
	self._cars = {} :: { Car }
	self._nextSpawn = 1
	self._ridden = nil :: Car?
	self._along = 0
	self._lateral = RunConfig.laneCenter(2)
	self._up = 0
	self._steer = 0
	self._heat = 0
	self._meltdownLeft = nil :: number?
	self._meltdownDrift = 1
	self._slowLeft = 0
	self._keys = nil :: number?
	self._keysNeed = nil :: number?
	self._cardLeft = 0
	self._hop = nil :: Hop?
	self._footLeft = nil :: number?
	self._target = nil :: Car?
	self._hops = 0
	self._claimed = {} :: { string }
	self._joyrides = 0
	self._saves = 0
	self._bumps = 0
	self._nextMilestone = RunConfig.MILESTONE_METRES
	self._cause = nil :: string?
	self._started = false
	self._forceMiss = false
	self._lastLevel = -1
	self._riderHidden = false
	self._cockpit = false
	self._cockpitCar = nil :: Car?

	trove:Connect(self._input.Hop, function()
		self:requestHop()
	end)
	trove:Connect(self._input.View, function()
		self._cockpit = not self._cockpit
	end)

	return self :: RunController
end

-- Car bookkeeping -------------------------------------------------------------------------

local function addCar(
	self: any,
	spawn: RunSequence.Spawn?,
	familyName: string,
	rarity: RunConfig.Rarity,
	size: RunConfig.Size,
	paint: number
): Car
	local family = Families.get(familyName)
	local modelId = familyName .. "_" .. rarity
	local owned = self._session.owned[modelId] == true
	local variant: RunConfig.Variant = if spawn then RunSequence.variantFor(spawn, owned) else "None"
	local model =
		CarVisual.build({ family = familyName, rarity = rarity, size = size, paint = paint, variant = variant })
	local dims = CarVisual.dimensions(familyName, size)
	local car: Car = {
		index = if spawn then spawn.index else 0,
		spawn = spawn,
		family = family,
		rarity = rarity,
		size = size,
		variant = variant,
		modelId = modelId,
		model = model,
		tag = nil,
		length = dims.length,
		width = dims.width,
		height = dims.height,
		roof = CarVisual.roofHeight(familyName, size),
		seat = if family.openTop then CarVisual.roofHeight(familyName, size) else dims.height * 0.22,
		needs = if spawn then spawn.needs else 0,
		along = 0,
		lateral = 0,
		lane = if spawn then spawn.lane else 2,
		retired = spawn == nil,
		fade = nil,
		keysDone = false,
		bumpCooldown = 0,
	}
	if spawn then
		local tag = CarTags.attach(model, {
			family = familyName,
			rarity = rarity,
			size = size,
			variant = variant,
			odds = spawn.odds,
			needs = spawn.needs,
			owned = owned,
		}, car.height)
		tag.MaxDistance = TAG_RANGE
		CarTags.setLevel(tag, car.needs, self._session.level)
		car.tag = tag
	end
	model.Parent = self._carsFolder
	table.insert(self._cars, car)
	return car
end

local function removeCar(self: any, car: Car)
	local i = table.find(self._cars, car)
	if i then
		table.remove(self._cars, i)
	end
	car.model:Destroy()
	if self._target == car then
		self._target = nil
	end
end

local function spawnAhead(self: any)
	local horizon = self._along + self._profile.spawnAhead
	local spawns = self._sequence:ensure(horizon)
	while self._nextSpawn <= #spawns do
		local spawn = spawns[self._nextSpawn]
		if spawn.start > horizon then
			break
		end
		self._nextSpawn += 1
		local along = self._sequence:alongAt(spawn, self._t)
		if along > self._along - RunConfig.DESPAWN_BEHIND then
			local car = addCar(self, spawn, spawn.family, spawn.rarity, spawn.size, spawn.paint)
			car.along = along
			car.lateral = self._sequence:lateralAt(spawn, self._t)
			if self._t > 1 and (spawn.rarity == RunConfig.ALERT_RARITY or spawn.size == "Giant") then
				self._overlay:alert("A " .. carName(car) .. " is on the road ahead!", CarTags.RARITY_TEXT[spawn.rarity])
				self._fx:sound("alert", 0.5, 1.3)
			end
		end
	end
end

local function laneClear(self: any, car: Car, lane: number): boolean
	local x = RunConfig.laneCenter(lane)
	for _, other in self._cars do
		if other ~= car and other ~= self._ridden and math.abs(other.lateral - x) < RunConfig.LANE_WIDTH / 2 then
			if math.abs(other.along - car.along) < (other.length + car.length) / 2 + 6 then
				return false
			end
		end
	end
	return true
end

local function moveTraffic(self: any, dt: number)
	local speed = self._sequence:speedAt(self._t)
	for i = #self._cars, 1, -1 do
		local car = self._cars[i]
		car.bumpCooldown = math.max(car.bumpCooldown - dt, 0)
		if car == self._ridden then
			continue
		end
		if car.retired then
			car.along += self._sequence:laneSpeed(car.lane) * speed * dt
			local x = RunConfig.laneCenter(car.lane)
			car.lateral += (x - car.lateral) * (1 - math.exp(-2 * dt))
			if car.fade then
				car.fade -= dt
				setModelTransparency(car.model, 1 - math.max(car.fade :: number, 0))
				if (car.fade :: number) <= 0 then
					removeCar(self, car)
					continue
				end
			end
		else
			local spawn = car.spawn :: RunSequence.Spawn
			car.along = self._sequence:alongAt(spawn, self._t)
			car.lateral = self._sequence:lateralAt(spawn, self._t)
		end
		if car.along < self._along - RunConfig.DESPAWN_BEHIND then
			removeCar(self, car)
		end
	end
end

local function retire(self: any, car: Car)
	car.retired = true
	local lane = nearestLane(car.lateral)
	car.lane = lane
	if not laneClear(self, car, lane) then
		car.fade = 1
	end
	CarVisual.update(car.model, 0, self._t)
	if car.tag then
		car.tag.Enabled = true
	end
end

local function refreshLevel(self: any)
	local level = self._session.level
	if level == self._lastLevel then
		return
	end
	self._lastLevel = level
	for _, car in self._cars do
		if car.tag then
			CarTags.setLevel(car.tag, car.needs, level)
		end
	end
end

-- Hop targeting -----------------------------------------------------------------------------

local function findTarget(self: any): Car?
	local range = if self._ridden then (self._ridden :: Car).family.hopRange else 30
	local steer = self._steer
	local best: Car? = nil
	local bestScore = math.huge
	for _, car in self._cars do
		if car == self._ridden or car.fade then
			continue
		end
		local da = car.along - self._along
		if da < -RunConfig.HOP_BEHIND_ALLOWANCE then
			continue
		end
		local dl = car.lateral - self._lateral
		local dist = math.sqrt(da * da + dl * dl) - car.length * 0.25
		if dist > range then
			continue
		end
		local score = dist
		if math.abs(steer) > 0.1 and math.abs(dl) > 3 then
			score += if math.sign(dl) == math.sign(steer) then -14 else 25
		end
		if da < 0 then
			score += 10
		end
		if score < bestScore then
			best, bestScore = car, score
		end
	end
	return best
end

-- Rider ---------------------------------------------------------------------------------------

local function riderParts(self: any): (Model?, BasePart?, Humanoid?)
	local character = self._player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if root and root:IsA("BasePart") then
		return character, root, humanoid
	end
	return character, nil, humanoid
end

local function placeRider(self: any)
	local _, root, humanoid = riderParts(self)
	if not root then
		return
	end
	root.Anchored = true
	root.AssemblyLinearVelocity = Vector3.zero
	local seated = self._mode == "Riding" and self._ridden ~= nil
	local lean = 0
	if seated then
		lean = -self._steer * 0.18
	end
	local bob = if seated then math.sin(self._t * 14) * 0.05 else 0
	root.CFrame = RunRoad.frame(self._along, self._lateral, self._up + (if seated then SIT_UP else ROOT_UP) + bob)
		* CFrame.Angles(0, 0, lean)
	if humanoid and humanoid.Sit ~= seated then
		humanoid.Sit = seated
	end
	-- Inside a closed car the rider is hidden behind tinted glass (outline section 06); on an
	-- open vehicle, in the air and on foot the rider is visible.
	local ridden = self._ridden :: Car?
	local hidden = seated and ridden ~= nil and not ridden.family.openTop
	if hidden ~= self._riderHidden then
		self._riderHidden = hidden
		local character = self._player.Character
		if character then
			for _, d in character:GetDescendants() do
				if d:IsA("BasePart") or d:IsA("Decal") then
					(d :: any).LocalTransparencyModifier = if hidden then 1 else 0
				end
			end
		end
	end
end

local COCKPIT_HIDE = {
	Cabin = true,
	Roof = true,
	Windscreen = true,
	RearWindow = true,
	PartyBall = true,
	Wing = true,
	WingStand = true,
	Cab = true,
	Trailer = true,
	TrailerStripe = true,
}

-- In the in-car view, hide the parts of the ridden car that would block the windscreen.
local function applyCockpit(self: any)
	local ridden = self._ridden :: Car?
	local want = if self._cockpit and self._mode == "Riding" then ridden else nil
	if self._cockpitCar == want then
		return
	end
	local old = self._cockpitCar :: Car?
	if old then
		for _, d in old.model:GetChildren() do
			if d:IsA("BasePart") and COCKPIT_HIDE[d.Name] then
				d.LocalTransparencyModifier = 0
			end
		end
	end
	self._cockpitCar = want
	if want then
		for _, d in want.model:GetChildren() do
			if d:IsA("BasePart") and COCKPIT_HIDE[d.Name] then
				d.LocalTransparencyModifier = 1
			end
		end
	end
end

-- Public actions ----------------------------------------------------------------------------

function RunController.requestHop(self: any)
	if self._mode == "Ended" or self._mode == "Hopping" or not self._started then
		return
	end
	local fromFoot = self._mode == "FootDash"
	local target = self._target
	if not target and fromFoot then
		return
	end
	local inPlace = target == nil
	self._report:push({
		kind = "Hop",
		t = self._t,
		d = self._along,
		x = self._lateral,
		target = if target then target.index else (if self._ridden then (self._ridden :: Car).index else 0),
	})
	self._hops += 1
	self._hop = {
		startT = self._t,
		fromAlong = self._along,
		fromLateral = self._lateral,
		fromUp = self._up,
		target = target or self._ridden,
		inPlace = inPlace,
		fromFoot = fromFoot,
		nudge = 0,
	} :: Hop
	if not inPlace and self._ridden then
		retire(self, self._ridden)
		self._ridden = nil
	end
	self._keys = nil
	self._keysNeed = nil
	self._footLeft = nil
	self._mode = "Hopping"
	self._fx:sound("hop", 0.5, 1.05)
	local _, root = riderParts(self)
	self._fx:setTrail(root, true)
	if self._camera then
		self._camera:punch()
	end
end

function RunController.setSteerOverride(self: any, steer: number?)
	self._input:setOverride(steer)
end

-- Test hook: the next landing misses so Foot Dash can be checked in a playtest.
function RunController.forceMiss(self: any)
	self._forceMiss = true
end

-- Simulation --------------------------------------------------------------------------------

local function results(self: any)
	return {
		metres = RunConfig.toMetres(self._along),
		hops = self._hops,
		claimed = table.clone(self._claimed),
		joyrides = self._joyrides,
		saves = self._saves,
		cause = self._cause or "?",
		seed = self.seed,
	}
end

local function showEnd(self: any)
	if self._mode ~= "Ended" then
		return
	end
	self._overlay:showResults(results(self), self._session.revives, function()
		self:revive()
	end, function()
		self.Ended:Fire(results(self))
	end)
end

local function endRun(self: any, cause: string)
	if self._mode == "Ended" then
		return
	end
	self._mode = "Ended"
	self._cause = cause
	self._target = nil
	self._ring.Transparency = 1
	self._arrow.Transparency = 1
	self._meter.gui.Enabled = false
	self._overlay:setFootDash(nil)
	self._report:push({ kind = "RunEnd", t = self._t, d = self._along, cause = cause })
	self._fx:dust(RunRoad.frame(self._along, self._lateral, 1), 6)
	self._fx:sound("bump", 0.7, 0.8)
	if self._camera then
		self._camera:jolt(0.8)
	end
	if self._ridden then
		setModelTransparency((self._ridden :: Car).model, 0.5)
	end
	print(
		string.format(
			"[Lane1Run] run over: seed %d, %d m, %d hops, cause %s, events %s",
			self.seed,
			math.floor(RunConfig.toMetres(self._along)),
			self._hops,
			cause,
			HttpService:JSONEncode(self._report:counts())
		)
	)
	task.delay(0.8, function()
		showEnd(self)
	end)
end

local function startKeys(self: any, car: Car)
	self._keys = nil
	self._keysNeed = nil
	if not car.keysDone and car.spawn then
		self._keys = 0
		self._keysNeed = self._profile.keysTime[car.rarity]
	end
end

local function boardCar(self: any, car: Car)
	self._mode = "Riding"
	self._ridden = car
	car.retired = true -- leaves the seed schedule while ridden
	car.fade = nil
	setModelTransparency(car.model, 0)
	if car.tag then
		car.tag.Enabled = false
	end
	self._lateral = car.lateral
	self._along = car.along
	self._up = car.seat
	self._heat = 0
	self._meltdownLeft = nil
	self._slowLeft = 0
	startKeys(self, car)
	self._fx:setSteam(car.model, 0)
	self._meter.gui.Enabled = true
end

local function land(self: any, hop: Hop)
	local car = hop.target
	self._hop = nil
	local _, root = riderParts(self)
	self._fx:setTrail(root, false)
	if hop.inPlace then
		self._mode = "Riding"
		self._fx:sound("land", 0.4)
		return
	end
	local stillThere = table.find(self._cars, car) ~= nil and not car.fade
	local miss = self._forceMiss or not stillThere or math.abs(hop.nudge) > car.width / 2 + RunConfig.LAND_TOLERANCE
	self._forceMiss = false
	if miss then
		self._mode = "FootDash"
		self._footLeft = RunConfig.FOOT_DASH_TIME
		self._up = 0
		self._meter.gui.Enabled = false
		self._fx:dust(RunRoad.frame(self._along, self._lateral, 0.5), 4)
		self._overlay:banner("Missed! Run!", Color3.fromRGB(255, 120, 90))
		return
	end
	boardCar(self, car)
	self._fx:dust(RunRoad.frame(car.along, car.lateral, 0.5), math.max(car.width, 5))
	self._fx:sound("land", 0.6)
	if hop.fromFoot then
		self._saves += 1
		self._overlay:banner("Nice save!", Color3.fromRGB(120, 230, 140))
	end
end

function RunController.revive(self: any): boolean
	if self._mode ~= "Ended" or self._session.revives <= 0 then
		return false
	end
	self._session.revives -= 1
	self._overlay:hideResults()
	if self._ridden then
		retire(self, self._ridden)
		self._ridden = nil
	end
	-- Land on the nearest car ahead; if there is none close, a fresh Loaner appears under you.
	local best: Car? = nil
	local bestDist = 80
	for _, car in self._cars do
		local da = car.along - self._along
		if not car.fade and da > -5 and da < bestDist then
			best, bestDist = car, da
		end
	end
	local car = best
	if not car then
		local loaner = addCar(self, nil, Families.LOANER, "Common", "Normal", 1)
		loaner.along = self._along
		loaner.lateral = RunConfig.laneCenter(nearestLane(self._lateral))
		car = loaner
	end
	local landed = car :: Car
	self._cause = nil
	boardCar(self, landed)
	self._report:push({ kind = "Revive", t = self._t, d = self._along, target = landed.index })
	self._overlay:banner("Revived!", Color3.fromRGB(255, 200, 90))
	self._fx:burst(RunRoad.frame(landed.along, landed.lateral, landed.roof + 2), Color3.fromRGB(255, 220, 120))
	return true
end

local function completeKeys(self: any, car: Car)
	car.keysDone = true
	self._keys = nil
	self._keysNeed = nil
	self._cardLeft = RunConfig.KEYS_CARD_TIME
	self._report:push({ kind = "KeysComplete", t = self._t, d = self._along, index = car.index })
	local name = carName(car)
	local colour = CarTags.RARITY_TEXT[car.rarity]
	if self._session.owned[car.modelId] then
		self._joyrides += 1
		self._overlay:banner("Joyride Bonus! " .. name, colour)
		self._overlay:addToTray(name, colour, false)
	else
		self._session.owned[car.modelId] = true
		self._session.level += RunConfig.LEVEL_PER_NEW_MODEL
		table.insert(self._claimed, name)
		self._overlay:banner("You got the Keys! " .. name, colour)
		self._overlay:addToTray(name, colour, true)
	end
	self._fx:burst(RunRoad.frame(car.along, car.lateral, car.roof + 2), CarVisual.RARITY_COLOR[car.rarity])
	self._fx:sound("claim", 0.7, if car.rarity == "Common" then 1 else 1.25)
end

local function bumpRidden(self: any, ridden: Car)
	for _, car in self._cars do
		if car == ridden or car.fade then
			continue
		end
		local da = car.along - ridden.along
		local dl = car.lateral - ridden.lateral
		local overlapA = (car.length + ridden.length) / 2 - math.abs(da)
		local overlapL = (car.width + ridden.width) / 2 - math.abs(dl)
		if overlapA <= 0 or overlapL <= 0 then
			continue
		end
		if self._profile.crashEndsRun then
			local at = RunRoad.frame(
				(car.along + ridden.along) / 2,
				(car.lateral + ridden.lateral) / 2,
				math.min(car.height, ridden.height) * 0.5
			)
			self._fx:sparks(at)
			self._fx:burst(at, Color3.fromRGB(255, 150, 60))
			self._bumps += 1
			endRun(self, "Crashed into a " .. carName(car))
			return
		end
		local fresh = car.bumpCooldown <= 0
		local mult = ridden.family.bumpHeatMultiplier
		local rear = false
		if overlapA <= overlapL then
			if da > 0 then
				ridden.along -= overlapA + 0.05
				rear = true
				if fresh then
					self._heat += RunConfig.BUMP_REAR * mult
					self._slowLeft = RunConfig.REAR_SLOW_TIME
				end
			else
				ridden.along += overlapA + 0.05
				if fresh then
					self._heat += RunConfig.BUMP_SIDE * mult
				end
			end
		else
			ridden.lateral -= math.sign(dl) * (overlapL + 0.05)
			if fresh then
				self._heat += RunConfig.BUMP_SIDE * mult
			end
		end
		if fresh then
			car.bumpCooldown = RunConfig.BUMP_COOLDOWN
			self._bumps += 1
			local at = RunRoad.frame(
				(car.along + ridden.along) / 2,
				(car.lateral + ridden.lateral) / 2,
				math.min(car.height, ridden.height) * 0.5
			)
			self._fx:sparks(at)
			self._fx:sound("bump", if rear then 0.6 else 0.4, if rear then 0.9 else 1.2)
			if self._camera then
				self._camera:jolt(if rear then 0.45 else 0.25)
			end
			if self._hud then
				self._hud:jolt(if rear then 0.8 else 0.5)
			end
		end
	end
end

local function clampLateral(lateral: number, width: number): number
	local limit = RunConfig.ROAD_HALF_WIDTH - width / 2
	return math.clamp(lateral, -limit, limit)
end

local function tooStrong(self: any, car: Car): boolean
	return car.spawn ~= nil and not car.keysDone and self._session.level < car.needs
end

local function stepRiding(self: any, dt: number, steerInput: number, drag: number)
	local ridden = self._ridden :: Car
	local family = ridden.family
	local strong = tooStrong(self, ridden)

	-- Heat (paused while the Keys card is up). A car that is too strong overheats faster.
	if self._cardLeft > 0 then
		self._cardLeft -= dt
	else
		self._heat += dt / (family.heatCapacity * self._profile.heatScale) * (if strong
			then RunConfig.TOO_STRONG_HEAT
			else 1)
	end
	if self._heat >= 1 and not self._meltdownLeft then
		self._meltdownLeft = RunConfig.MELTDOWN_TIME
		self._meltdownDrift = if Random.new(self.seed + self._hops):NextNumber() < 0.5 then -1 else 1
		self._overlay:banner("Losing control! HOP NOW!", Color3.fromRGB(255, 90, 70))
	end
	local melt = 0
	if self._meltdownLeft then
		self._meltdownLeft -= dt
		melt = 1 - math.max(self._meltdownLeft, 0) / RunConfig.MELTDOWN_TIME
		if self._meltdownLeft <= 0 then
			endRun(self, "Meltdown")
			return
		end
	end

	-- Steering: free left/right; sluggish and drifting during Meltdown, never inverted.
	local lag = if self._meltdownLeft
		then 1 - math.exp(-dt / (RunConfig.MELTDOWN_STEER_LAG * (0.3 + melt)))
		else 1 - math.exp(-dt * 14)
	self._steer += (steerInput - self._steer) * lag
	local lateral = ridden.lateral + self._steer * family.steerSpeed * self._profile.steerScale * dt
	lateral += drag * RunConfig.ROAD_HALF_WIDTH * 2.4
	if self._meltdownLeft then
		lateral += (math.sin(self._t * 9) * 5 * melt + self._meltdownDrift * 6 * melt) * dt
	end
	ridden.lateral = clampLateral(lateral, ridden.width)

	-- Forward.
	local factor = family.speedMultiplier
	if self._slowLeft > 0 then
		self._slowLeft -= dt
		factor *= RunConfig.REAR_SLOW_FACTOR
	end
	if self._meltdownLeft then
		factor *= 1 - (1 - RunConfig.MELTDOWN_MIN_SPEED) * melt
	end
	ridden.along += self._sequence:speedAt(self._t) * factor * dt
	bumpRidden(self, ridden)
	if self._mode == "Ended" then
		return
	end
	ridden.lateral = clampLateral(ridden.lateral, ridden.width)
	self._heat = math.min(self._heat, 1)

	-- Keys (the catch meter): only fills when the Rider Level is enough.
	if self._keys and self._keysNeed and not strong then
		self._keys += dt
		if self._keys >= self._keysNeed then
			completeKeys(self, ridden)
		end
	end

	self._along = ridden.along
	self._lateral = ridden.lateral
	self._up = ridden.seat
end

local function stepHop(self: any, dt: number, steerInput: number)
	local hop = self._hop :: Hop
	local a = math.clamp((self._t - hop.startT) / RunConfig.HOP_TIME, 0, 1)
	local target = hop.target
	if hop.inPlace and target then
		-- The car keeps going straight under an in-place hop.
		target.along += self._sequence:speedAt(self._t) * target.family.speedMultiplier * dt
	else
		hop.nudge = math.clamp(
			hop.nudge + steerInput * RunConfig.HOP_NUDGE_SPEED * dt,
			-RunConfig.HOP_NUDGE,
			RunConfig.HOP_NUDGE
		)
	end
	local toAlong = if target then target.along else hop.fromAlong
	local toLateral = (if target then target.lateral else hop.fromLateral) + hop.nudge
	local toUp = if target then target.seat else 0
	-- Ease the forward travel so the leap reads: quick launch, soft landing.
	local e = 1 - (1 - a) * (1 - a)
	self._along = hop.fromAlong + (toAlong - hop.fromAlong) * e
	self._lateral = hop.fromLateral + (toLateral - hop.fromLateral) * e
	self._up = hop.fromUp + (toUp - hop.fromUp) * a + 4 * RunConfig.HOP_HEIGHT * a * (1 - a)
	if a >= 1 then
		land(self, hop)
	end
end

local function stepFoot(self: any, dt: number, steerInput: number, drag: number)
	self._footLeft -= dt
	self._steer = steerInput
	self._along += self._sequence:speedAt(self._t) * RunConfig.FOOT_SPEED * dt
	local lateral = self._lateral
		+ steerInput * RunConfig.FOOT_STEER * self._profile.steerScale * dt
		+ drag * RunConfig.ROAD_HALF_WIDTH * 2
	self._lateral = clampLateral(lateral, RunConfig.FOOT_SIZE)
	self._up = 0
	for _, car in self._cars do
		if car.fade then
			continue
		end
		local da = car.along - self._along
		local dl = car.lateral - self._lateral
		if
			math.abs(da) < car.length / 2 + RunConfig.FOOT_SIZE / 2
			and math.abs(dl) < car.width / 2 + RunConfig.FOOT_SIZE / 2
		then
			endRun(self, "Hit on foot")
			return
		end
	end
	if self._footLeft <= 0 then
		endRun(self, "Foot Dash ran out")
	end
end

local function render(self: any)
	local t = self._t
	for _, car in self._cars do
		local offset = CFrame.identity
		if car == self._ridden then
			CarVisual.update(car.model, self._heat, t)
			if self._heat >= RunConfig.HEAT_CRITICAL or self._meltdownLeft then
				local s = if self._meltdownLeft then 0.1 else 0.04
				offset = CFrame.Angles(math.sin(t * 40) * s, 0, math.cos(t * 33) * s)
			end
			-- Landing bounce on the suspension.
			if self._hop == nil and self._mode == "Riding" then
				offset *= CFrame.Angles(0, -self._steer * 0.06, -self._steer * 0.05)
			end
		elseif car.variant == "Rainbow" then
			CarVisual.update(car.model, 0, t)
		end
		-- Traffic rocks gently, like animals in a herd.
		local rock = math.sin(t * 6 + car.index) * 0.015
		car.model:PivotTo(RunRoad.frame(car.along, car.lateral, 0) * offset * CFrame.Angles(rock, 0, rock))
	end
	local target = self._target
	if target and (self._mode == "Riding" or self._mode == "FootDash") then
		local d = math.max(target.width, target.length * 0.7) + 3
		local pulse = 1 + math.sin(t * 8) * 0.06
		self._ring.Size = Vector3.new(0.2, d * pulse, d * pulse)
		self._ring.CFrame = RunRoad.frame(target.along, target.lateral, 0.15) * CFrame.Angles(0, 0, math.pi / 2)
		self._ring.Color = if tooStrong(self, target) then Color3.fromRGB(255, 96, 86) else Color3.fromRGB(255, 214, 70)
		self._ring.Transparency = 0.3
		self._arrow.CFrame =
			RunRoad.frame(target.along, target.lateral, target.roof + 2.5 + math.abs(math.sin(t * 6)) * 1.2)
		self._arrow.Color = self._ring.Color
		self._arrow.Transparency = 0
	else
		self._ring.Transparency = 1
		self._arrow.Transparency = 1
	end
end

local function updateUi(self: any)
	local stage = stageFor(self._heat, self._meltdownLeft ~= nil)
	local riding = self._mode == "Riding"
	if self._hud then
		self._hud:setState({
			cash = 0,
			distance = RunConfig.toMetres(self._along),
			heat = if riding then self._heat else 0,
			stage = if riding then stage else "Calm",
		})
	end
	self._fx:setSteam(
		if riding and self._ridden then (self._ridden :: Car).model else nil,
		if riding then self._heat else 0
	)

	-- Catch meter over the rider.
	local meter = self._meter
	local _, root = riderParts(self)
	meter.gui.Adornee = root
	local ridden = self._ridden :: Car?
	if riding and ridden and ridden.spawn then
		meter.gui.Enabled = true
		if ridden.keysDone then
			meter.fill.Size = UDim2.fromScale(1, 1)
			meter.label.Text = "Got the Keys!"
			meter.label.TextColor3 = Color3.fromRGB(140, 240, 150)
		elseif tooStrong(self, ridden) then
			meter.fill.Size = UDim2.fromScale(0, 1)
			meter.label.Text = string.format("Too strong! Needs %d", ridden.needs)
			meter.label.TextColor3 = Color3.fromRGB(255, 120, 110)
		elseif self._keys and self._keysNeed then
			meter.fill.Size = UDim2.fromScale(math.clamp(self._keys / self._keysNeed, 0, 1), 1)
			meter.label.Text = string.format("Keys %.1f / %.0f s", self._keys, self._keysNeed)
			meter.label.TextColor3 = Color3.fromRGB(255, 248, 232)
		end
	else
		meter.gui.Enabled = false
	end

	self._overlay:setFootDash(if self._footLeft then self._footLeft / RunConfig.FOOT_DASH_TIME else nil)
	self._overlay:setHint(
		self._t < 7,
		if self._profile.crashEndsRun
			then "Cut lanes to survive! Touching a car ends the run  ·  Hop: Space  ·  V: in-car view"
			else "Steer: A / D or drag  ·  Hop: Space or tap  ·  V: in-car view"
	)
	self._overlay:setLevel(self._session.level, self._session.revives)
	refreshLevel(self)
end

local function step(self: any, dt: number)
	local carLength = if self._ridden then (self._ridden :: Car).length else 4
	local speed01 = (self._sequence:speedAt(self._t) - RunConfig.START_SPEED)
		/ (RunConfig.TOP_SPEED - RunConfig.START_SPEED)
	if self._mode == "Ended" then
		if self._camera then
			self._camera:step(dt, self._along, self._lateral, self._up, carLength, 0)
			self._fx:setSpeedLines(self._camera:getCFrame(), 0)
		end
		return
	end
	dt = math.min(dt, 1 / 20)
	self._t += dt
	local steerInput = self._input:getSteer()
	local drag = self._input:takeDrag()

	spawnAhead(self)
	moveTraffic(self, dt)
	if self._mode == "Riding" then
		stepRiding(self, dt, steerInput, drag)
	elseif self._mode == "Hopping" then
		stepHop(self, dt, steerInput)
	elseif self._mode == "FootDash" then
		stepFoot(self, dt, steerInput, drag)
	end
	if self._mode == "Ended" then
		render(self)
		return
	end
	self._target = if self._mode == "Riding" or self._mode == "FootDash" then findTarget(self) else nil

	local metres = RunConfig.toMetres(self._along)
	if metres >= self._nextMilestone then
		self._overlay:banner(string.format("%d m!", self._nextMilestone))
		self._fx:sound("claim", 0.4, 0.8)
		self._nextMilestone += RunConfig.MILESTONE_METRES
	end

	self._road:update(self._along)
	render(self)
	placeRider(self)
	applyCockpit(self)
	local ridden = self._ridden :: Car?
	if self._cockpit and self._mode == "Riding" and ridden then
		self._camera:stepCockpit(dt, ridden.along - ridden.length * 0.08, ridden.lateral, ridden.height * 0.72, speed01)
	else
		self._camera:step(dt, self._along, self._lateral, self._up, carLength, speed01)
	end
	self._fx:setSpeedLines(self._camera:getCFrame(), 0.3 + speed01 * 0.7)
	updateUi(self)
	self._report:step(self._t)
end

function RunController.start(self: any)
	if self._started then
		return
	end
	self._started = true
	self._zone.Parent = Workspace

	local controls = nil
	local playerModule = self._player:FindFirstChild("PlayerScripts")
		and self._player.PlayerScripts:FindFirstChild("PlayerModule")
	if playerModule then
		local ok, module = pcall(require, playerModule)
		if ok then
			controls = (module :: any):GetControls()
			controls:Disable()
		end
	end
	self._trove:Add(function()
		if controls then
			controls:Enable()
		end
		local _, root, humanoid = riderParts(self)
		if humanoid then
			humanoid.Sit = false
		end
		if root then
			root.Anchored = false
		end
	end)

	local loaner = addCar(self, nil, Families.LOANER, "Common", "Normal", 1)
	loaner.along = 0
	loaner.lateral = RunConfig.laneCenter(2)
	self._session.owned[loaner.modelId] = true
	boardCar(self, loaner)

	self._camera = ChaseCamera.new()
	self._trove:Add(function()
		self._camera:destroy()
	end)
	self._road:update(0)
	spawnAhead(self)
	RunService:BindToRenderStep(BIND_NAME, Enum.RenderPriority.Camera.Value + 1, function(dt: number)
		step(self, dt)
	end)
	self._trove:Add(function()
		RunService:UnbindFromRenderStep(BIND_NAME)
	end)
	self._overlay:banner("Go!")
end

function RunController.getDebugState(self: any): DebugState
	local ridden = self._ridden :: Car?
	local aheadGap: number? = nil
	if ridden then
		for _, car in self._cars do
			if car ~= ridden and math.abs(car.lateral - ridden.lateral) < (car.width + ridden.width) / 2 then
				local gap = car.along - ridden.along - (car.length + ridden.length) / 2
				if gap >= -1 and (aheadGap == nil or gap < (aheadGap :: number)) then
					aheadGap = gap
				end
			end
		end
	end
	local target = self._target :: Car?
	return {
		seed = self.seed,
		mode = self._mode,
		t = self._t,
		metres = RunConfig.toMetres(self._along),
		speed = self._sequence:speedAt(self._t),
		along = self._along,
		lateral = self._lateral,
		family = if ridden then ridden.family.name else nil,
		rarity = if ridden then ridden.rarity else nil,
		size = if ridden then ridden.size else nil,
		needs = if ridden then ridden.needs else nil,
		level = self._session.level,
		revives = self._session.revives,
		heat = self._heat,
		stage = stageFor(self._heat, self._meltdownLeft ~= nil),
		meltdownLeft = self._meltdownLeft,
		keys = self._keys,
		keysNeed = self._keysNeed,
		tooStrong = if ridden then tooStrong(self, ridden) else false,
		footDashLeft = self._footLeft,
		target = if target then target.index else nil,
		targetDistance = if target
			then math.sqrt((target.along - self._along) ^ 2 + (target.lateral - self._lateral) ^ 2)
			else nil,
		aheadGap = aheadGap,
		cars = #self._cars,
		hops = self._hops,
		claimed = table.clone(self._claimed),
		joyrides = self._joyrides,
		saves = self._saves,
		bumps = self._bumps,
		events = self._report:counts(),
		cause = self._cause,
	}
end

function RunController.destroy(self: any)
	for _, car in self._cars do
		car.model:Destroy()
	end
	table.clear(self._cars)
	self._trove:Destroy()
end

return RunController
