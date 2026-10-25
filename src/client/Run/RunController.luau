--!strict
-- One collection run, played on the player's device (outline section 06, Stage 1 prototype).
-- Steering, traffic from the run seed, the Hop with its target ring, Foot Dash, Heat with the
-- Meltdown escape window (decision 0008), bumps, the Keys meter and the chase camera.
--
-- What this does NOT do yet (by design for Stage 1): no remotes, no saving, no Cash, no real
-- ownership. "Claimed" cars are remembered only for this playtest session so the Joyride Bonus
-- path can be seen. Every event is recorded in run-report shape (RunReport) for Lane 2 later.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Families = require(ReplicatedStorage.Shared.Run.Families)
local RunConfig = require(ReplicatedStorage.Shared.Run.RunConfig)
local RunSequence = require(ReplicatedStorage.Shared.Run.RunSequence)
local Signal = require(ReplicatedStorage.Packages.Signal)
local Trove = require(ReplicatedStorage.Packages.Trove)

local CarVisual = require(script.Parent.CarVisual)
local ChaseCamera = require(script.Parent.ChaseCamera)
local RunInput = require(script.Parent.RunInput)
local RunOverlay = require(script.Parent.RunOverlay)
local RunReport = require(script.Parent.RunReport)
local RunRoad = require(script.Parent.RunRoad)

type Mode = "Riding" | "Hopping" | "FootDash" | "Ended"
type Stage = "Calm" | "Warning" | "Critical" | "Meltdown"

type Car = {
	index: number, -- spawn index; 0 for the Loaner
	spawn: RunSequence.Spawn?,
	family: Families.Family,
	rarity: RunConfig.Rarity,
	modelId: string,
	paint: number,
	model: Model,
	along: number,
	lateral: number,
	lane: number,
	retired: boolean, -- was ridden; now drifts with traffic and is no longer on the seed schedule
	fade: number?, -- seconds left before a drifting car that has nowhere to go disappears
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

export type Options = {
	seed: number?,
	owned: { [string]: boolean }?, -- model ids treated as owned this session (Joyride Bonus path)
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
	heat: number,
	stage: Stage,
	meltdownLeft: number?,
	keys: number?,
	keysNeed: number?,
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
	Ended: any, -- Signal(results)
	start: (self: RunController) -> (),
	requestHop: (self: RunController) -> (),
	setSteerOverride: (self: RunController, steer: number?) -> (),
	forceMiss: (self: RunController) -> (),
	getDebugState: (self: RunController) -> DebugState,
	destroy: (self: RunController) -> (),
}

local RunController = {}
RunController.__index = RunController

local BIND_NAME = "Lane1Run"
local SEAT_UP = 0.55 -- fraction of car height where the rider sits
local ROOT_UP = 3 -- HumanoidRootPart centre above the feet

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
			d.Transparency = math.max(d.Transparency, transparency)
		end
	end
end

function RunController.new(options: Options?): RunController
	local opts: Options = options or {}
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")
	local seed = opts.seed or Random.new():NextInteger(1, 2 ^ 30)
	local trove = Trove.new()

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
	ring.Transparency = 0.35
	ring.Size = Vector3.new(0.2, 10, 10)
	ring.Parent = zone

	local self = setmetatable({}, RunController) :: any
	self.seed = seed
	self.Ended = trove:Add(Signal.new())
	self._trove = trove
	self._player = player
	self._zone = zone
	self._carsFolder = carsFolder
	self._ring = ring
	self._sequence = RunSequence.new(seed)
	self._road = trove:Add(RunRoad.new(zone, seed), "destroy")
	self._input = trove:Add(RunInput.new(), "destroy")
	self._overlay = trove:Add(RunOverlay.new(playerGui), "destroy")
	self._report = trove:Add(RunReport.new(seed), "destroy")
	self._camera = nil
	self._owned = opts.owned or {}
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
	self._riderVisible = true

	trove:Connect(self._input.Hop, function()
		self:requestHop()
	end)

	return self :: RunController
end

-- Car bookkeeping -------------------------------------------------------------------------

local function addCar(
	self: any,
	spawn: RunSequence.Spawn?,
	familyName: string,
	rarity: RunConfig.Rarity,
	paint: number
): Car
	local family = Families.get(familyName)
	local model = CarVisual.build(familyName, rarity, paint)
	model.Parent = self._carsFolder
	local car: Car = {
		index = if spawn then spawn.index else 0,
		spawn = spawn,
		family = family,
		rarity = rarity,
		modelId = familyName .. "_" .. rarity,
		paint = paint,
		model = model,
		along = 0,
		lateral = 0,
		lane = if spawn then spawn.lane else 2,
		retired = spawn == nil,
		fade = nil,
		keysDone = false,
		bumpCooldown = 0,
	}
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
	local horizon = self._along + RunConfig.SPAWN_AHEAD
	local spawns = self._sequence:ensure(horizon)
	while self._nextSpawn <= #spawns do
		local spawn = spawns[self._nextSpawn]
		if spawn.start > horizon then
			break
		end
		self._nextSpawn += 1
		local along = self._sequence:alongAt(spawn, self._t)
		if along > self._along - RunConfig.DESPAWN_BEHIND then
			local car = addCar(self, spawn, spawn.family, spawn.rarity, spawn.paint)
			car.along = along
			car.lateral = self._sequence:lateralAt(spawn, self._t)
		end
	end
end

local function laneClear(self: any, car: Car, lane: number): boolean
	local x = RunConfig.laneCenter(lane)
	for _, other in self._cars do
		if other ~= car and other ~= self._ridden and math.abs(other.lateral - x) < RunConfig.LANE_WIDTH / 2 then
			if math.abs(other.along - car.along) < (other.family.length + car.family.length) / 2 + 6 then
				return false
			end
		end
	end
	return true
end

local function moveTraffic(self: any, dt: number)
	local speed = RunConfig.speedAt(self._t)
	for i = #self._cars, 1, -1 do
		local car = self._cars[i]
		car.bumpCooldown = math.max(car.bumpCooldown - dt, 0)
		if car == self._ridden then
			continue
		end
		if car.retired then
			car.along += RunConfig.LANE_SPEED[car.lane] * speed * dt
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
	if laneClear(self, car, lane) then
		car.lane = lane
	else
		car.lane = lane
		car.fade = 1
	end
	CarVisual.setHeat(car.model, car.paint, 0)
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
		local dist = math.sqrt(da * da + dl * dl)
		if dist > range then
			continue
		end
		local score = dist
		if math.abs(steer) > 0.1 and math.abs(dl) > 3 then
			score += if math.sign(dl) == math.sign(steer) then -12 else 25
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
end

function RunController.setSteerOverride(self: any, steer: number?)
	self._input:setOverride(steer)
end

-- Test hook: the next landing misses so Foot Dash can be checked in a playtest.
function RunController.forceMiss(self: any)
	self._forceMiss = true
end

-- Simulation --------------------------------------------------------------------------------

local function endRun(self: any, cause: string)
	if self._mode == "Ended" then
		return
	end
	self._mode = "Ended"
	self._cause = cause
	self._target = nil
	self._ring.Transparency = 1
	self._overlay:setKeys(nil)
	self._overlay:setFootDash(nil)
	self._report:push({ kind = "RunEnd", t = self._t, d = self._along, cause = cause })
	if self._camera then
		self._camera:jolt(0.8)
	end
	if self._ridden then
		setModelTransparency((self._ridden :: Car).model, 0.5)
	end
	local results = {
		metres = RunConfig.toMetres(self._along),
		hops = self._hops,
		claimed = table.clone(self._claimed),
		joyrides = self._joyrides,
		saves = self._saves,
		cause = cause,
		seed = self.seed,
	}
	print(
		string.format(
			"[Lane1Run] run over: seed %d, %d m, %d hops, cause %s, events %s",
			self.seed,
			math.floor(results.metres),
			self._hops,
			cause,
			game:GetService("HttpService"):JSONEncode(self._report:counts())
		)
	)
	task.delay(0.8, function()
		if self._overlay and self._mode == "Ended" then
			self._overlay:showResults(results, function()
				self.Ended:Fire(results)
			end)
		end
	end)
end

local function land(self: any, hop: Hop)
	local car = hop.target
	self._hop = nil
	if hop.inPlace then
		self._mode = "Riding"
		return
	end
	local stillThere = table.find(self._cars, car) ~= nil and not car.fade
	local miss = self._forceMiss
		or not stillThere
		or math.abs(hop.nudge) > car.family.width / 2 + RunConfig.LAND_TOLERANCE
	self._forceMiss = false
	if miss then
		self._mode = "FootDash"
		self._footLeft = RunConfig.FOOT_DASH_TIME
		self._up = 0
		self._overlay:banner("Missed! Run!", Color3.fromRGB(255, 120, 90))
		return
	end
	self._mode = "Riding"
	self._ridden = car
	car.retired = true -- leaves the seed schedule while ridden
	car.fade = nil
	self._lateral = car.lateral
	self._heat = 0
	self._meltdownLeft = nil
	self._slowLeft = 0
	if hop.fromFoot then
		self._saves += 1
		self._overlay:banner("Nice save!", Color3.fromRGB(120, 230, 140))
	end
	if not car.keysDone and car.spawn then
		self._keys = 0
		self._keysNeed = RunConfig.KEYS_TIME[car.rarity]
	end
end

local function completeKeys(self: any, car: Car)
	car.keysDone = true
	self._keys = nil
	self._keysNeed = nil
	self._cardLeft = RunConfig.KEYS_CARD_TIME
	self._report:push({ kind = "KeysComplete", t = self._t, d = self._along, index = car.index })
	local name = car.rarity .. " " .. car.family.name
	if self._owned[car.modelId] then
		self._joyrides += 1
		self._overlay:banner("Joyride Bonus! " .. name, CarVisual.RARITY_COLOR[car.rarity])
	else
		self._owned[car.modelId] = true
		table.insert(self._claimed, name)
		self._overlay:banner("You got the Keys! " .. name, CarVisual.RARITY_COLOR[car.rarity])
	end
end

local function bumpRidden(self: any, ridden: Car)
	for _, car in self._cars do
		if car == ridden or car.fade then
			continue
		end
		local da = car.along - ridden.along
		local dl = car.lateral - ridden.lateral
		local overlapA = (car.family.length + ridden.family.length) / 2 - math.abs(da)
		local overlapL = (car.family.width + ridden.family.width) / 2 - math.abs(dl)
		if overlapA <= 0 or overlapL <= 0 then
			continue
		end
		local fresh = car.bumpCooldown <= 0
		local mult = ridden.family.bumpHeatMultiplier
		if overlapA <= overlapL then
			if da > 0 then
				ridden.along -= overlapA + 0.05
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
			if self._camera then
				self._camera:jolt(0.35)
			end
			if self._hud then
				self._hud:jolt(0.6)
			end
		end
	end
end

local function clampLateral(lateral: number, width: number): number
	local limit = RunConfig.ROAD_HALF_WIDTH - width / 2
	return math.clamp(lateral, -limit, limit)
end

local function stepRiding(self: any, dt: number, steerInput: number, drag: number)
	local ridden = self._ridden :: Car
	local family = ridden.family

	-- Heat (paused while the Keys card is up).
	if self._cardLeft > 0 then
		self._cardLeft -= dt
	else
		self._heat += dt / family.heatCapacity
	end
	if self._heat >= 1 and not self._meltdownLeft then
		self._meltdownLeft = RunConfig.MELTDOWN_TIME
		self._meltdownDrift = if Random.new(self.seed + self._hops):NextNumber() < 0.5 then -1 else 1
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
	local lag = if self._meltdownLeft then 1 - math.exp(-dt / (RunConfig.MELTDOWN_STEER_LAG * (0.3 + melt))) else 1
	self._steer += (steerInput - self._steer) * lag
	local lateral = ridden.lateral + self._steer * family.steerSpeed * dt
	lateral += drag * RunConfig.ROAD_HALF_WIDTH * 2.4
	if self._meltdownLeft then
		lateral += (math.sin(self._t * 9) * 5 * melt + self._meltdownDrift * 6 * melt) * dt
	end
	ridden.lateral = clampLateral(lateral, family.width)

	-- Forward.
	local factor = family.speedMultiplier
	if self._slowLeft > 0 then
		self._slowLeft -= dt
		factor *= RunConfig.REAR_SLOW_FACTOR
	end
	if self._meltdownLeft then
		factor *= 1 - (1 - RunConfig.MELTDOWN_MIN_SPEED) * melt
	end
	ridden.along += RunConfig.speedAt(self._t) * factor * dt
	bumpRidden(self, ridden)
	ridden.lateral = clampLateral(ridden.lateral, family.width)
	self._heat = math.min(self._heat, 1)

	-- Keys.
	if self._keys and self._keysNeed then
		self._keys += dt
		if self._keys >= self._keysNeed then
			completeKeys(self, ridden)
		end
	end

	self._along = ridden.along
	self._lateral = ridden.lateral
	self._up = family.height * SEAT_UP
end

local function stepHop(self: any, dt: number, steerInput: number)
	local hop = self._hop :: Hop
	local a = math.clamp((self._t - hop.startT) / RunConfig.HOP_TIME, 0, 1)
	local target = hop.target
	if hop.inPlace and target then
		-- The car keeps going straight under an in-place hop.
		target.along += RunConfig.speedAt(self._t) * target.family.speedMultiplier * dt
	else
		hop.nudge = math.clamp(
			hop.nudge + steerInput * RunConfig.HOP_NUDGE_SPEED * dt,
			-RunConfig.HOP_NUDGE,
			RunConfig.HOP_NUDGE
		)
	end
	local toAlong = if target then target.along else hop.fromAlong
	local toLateral = (if target then target.lateral else hop.fromLateral) + hop.nudge
	local toUp = if target then target.family.height * SEAT_UP else 0
	self._along = hop.fromAlong + (toAlong - hop.fromAlong) * a
	self._lateral = hop.fromLateral + (toLateral - hop.fromLateral) * a
	self._up = hop.fromUp + (toUp - hop.fromUp) * a + 4 * RunConfig.HOP_HEIGHT * a * (1 - a)
	if a >= 1 then
		land(self, hop)
	end
end

local function stepFoot(self: any, dt: number, steerInput: number, drag: number)
	self._footLeft -= dt
	self._steer = steerInput
	self._along += RunConfig.speedAt(self._t) * RunConfig.FOOT_SPEED * dt
	local lateral = self._lateral + steerInput * RunConfig.FOOT_STEER * dt + drag * RunConfig.ROAD_HALF_WIDTH * 2
	self._lateral = clampLateral(lateral, RunConfig.FOOT_SIZE)
	self._up = 0
	for _, car in self._cars do
		if car.fade then
			continue
		end
		local da = car.along - self._along
		local dl = car.lateral - self._lateral
		if
			math.abs(da) < car.family.length / 2 + RunConfig.FOOT_SIZE / 2
			and math.abs(dl) < car.family.width / 2 + RunConfig.FOOT_SIZE / 2
		then
			endRun(self, "Hit on foot")
			return
		end
	end
	if self._footLeft <= 0 then
		endRun(self, "Foot Dash ran out")
	end
end

local function placeRider(self: any)
	local character = self._player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not (root and root:IsA("BasePart")) then
		return
	end
	root.Anchored = true
	root.AssemblyLinearVelocity = Vector3.zero
	root.CFrame = RunRoad.frame(self._along, self._lateral, self._up + ROOT_UP)
	local hidden = self._mode == "Riding" and self._ridden ~= nil and not (self._ridden :: Car).family.openTop
	if hidden ~= not self._riderVisible then
		self._riderVisible = not hidden
		for _, d in character:GetDescendants() do
			if d:IsA("BasePart") or d:IsA("Decal") then
				(d :: any).LocalTransparencyModifier = if hidden then 1 else 0
			end
		end
	end
end

local function render(self: any)
	local t = self._t
	for _, car in self._cars do
		local shake = CFrame.identity
		if car == self._ridden then
			local heat = self._heat
			CarVisual.setHeat(car.model, car.paint, heat)
			if heat >= RunConfig.HEAT_CRITICAL or self._meltdownLeft then
				local s = if self._meltdownLeft then 0.12 else 0.05
				shake = CFrame.Angles(math.sin(t * 40) * s, 0, math.cos(t * 33) * s)
			end
		end
		car.model:PivotTo(RunRoad.frame(car.along, car.lateral, 0) * shake)
	end
	local target = self._target
	if target and (self._mode == "Riding" or self._mode == "FootDash") then
		local d = math.max(target.family.width, target.family.length * 0.6) + 2
		local pulse = 1 + math.sin(t * 8) * 0.06
		self._ring.Size = Vector3.new(0.2, d * pulse, d * pulse)
		self._ring.CFrame = RunRoad.frame(target.along, target.lateral, 0.15) * CFrame.Angles(0, 0, math.pi / 2)
		self._ring.Transparency = 0.35
	else
		self._ring.Transparency = 1
	end
end

local function updateHud(self: any)
	local stage = stageFor(self._heat, self._meltdownLeft ~= nil)
	local heat = if self._mode == "Riding" then self._heat else 0
	if self._hud then
		self._hud:setState({
			cash = 0,
			distance = RunConfig.toMetres(self._along),
			heat = heat,
			stage = if self._mode == "Riding" then stage else "Calm",
		})
	end
	if self._keys and self._keysNeed and self._ridden then
		local ridden = self._ridden :: Car
		self._overlay:setKeys(
			self._keys / self._keysNeed,
			string.format("Keys: %s %s  %.1f / %.0f s", ridden.rarity, ridden.family.name, self._keys, self._keysNeed)
		)
	else
		self._overlay:setKeys(nil)
	end
	self._overlay:setFootDash(if self._footLeft then self._footLeft / RunConfig.FOOT_DASH_TIME else nil)
	self._overlay:setHint(self._t < 6)
end

local function step(self: any, dt: number)
	if self._mode == "Ended" then
		if self._camera then
			self._camera:step(dt, self._along, self._lateral, self._up, 12)
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
		self._nextMilestone += RunConfig.MILESTONE_METRES
	end

	self._road:update(self._along)
	render(self)
	placeRider(self)
	local carLength = if self._ridden then (self._ridden :: Car).family.length else 4
	self._camera:step(dt, self._along, self._lateral, self._up, carLength)
	updateHud(self)
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
		local character = self._player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") then
			root.Anchored = false
		end
		if character then
			for _, d in character:GetDescendants() do
				if d:IsA("BasePart") or d:IsA("Decal") then
					(d :: any).LocalTransparencyModifier = 0
				end
			end
		end
	end)

	local loaner = addCar(self, nil, Families.LOANER, "Common", 1)
	loaner.along = 0
	loaner.lateral = RunConfig.laneCenter(2)
	self._owned[loaner.modelId] = true
	self._ridden = loaner
	self._along = 0
	self._lateral = loaner.lateral
	self._up = loaner.family.height * SEAT_UP

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
			if
				car ~= ridden
				and math.abs(car.lateral - ridden.lateral) < (car.family.width + ridden.family.width) / 2
			then
				local gap = car.along - ridden.along - (car.family.length + ridden.family.length) / 2
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
		speed = RunConfig.speedAt(self._t),
		along = self._along,
		lateral = self._lateral,
		family = if ridden then ridden.family.name else nil,
		rarity = if ridden then ridden.rarity else nil,
		heat = self._heat,
		stage = stageFor(self._heat, self._meltdownLeft ~= nil),
		meltdownLeft = self._meltdownLeft,
		keys = self._keys,
		keysNeed = self._keysNeed,
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
