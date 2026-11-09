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
local Luck = require(ReplicatedStorage.Shared.Run.Luck)
local RunSequence = require(ReplicatedStorage.Shared.Run.RunSequence)
local Signal = require(ReplicatedStorage.Packages.Signal)
local Trove = require(ReplicatedStorage.Packages.Trove)

local CarTags = require(script.Parent.CarTags)
local CarVisual = require(script.Parent.CarVisual)
local ChaseCamera = require(script.Parent.ChaseCamera)
local HopGuide = require(script.Parent.HopGuide) -- Round 8 (WS-10, R-01 and R-02): the lock-on ring, the landing ring and the dive path
local RunFx = require(script.Parent.RunFx)
local RunInput = require(script.Parent.RunInput)
local RunOverlay = require(script.Parent.RunOverlay)
local RunReport = require(script.Parent.RunReport)
local RunRoad = require(script.Parent.RunRoad)
local TrailMoments = require(script.Parent.TrailMoments) -- Round 8 (T-03 to T-05)

-- Round 7 (R-01): Riding -> Float -> Dive -> Riding; Float -> Recover (a bonk) -> Riding; any -> Ended. "Hopping" and "FootDash" are
-- Brian R's earlier one-press Hop; they are no longer entered (kept so his debug tools still read).
type Mode = "Riding" | "Float" | "Dive" | "Recover" | "Hopping" | "FootDash" | "Ended"
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
	bounce: number, -- suspension offset (studs), presentation only
	bounceVel: number,
}

type Float = {
	startT: number,
	duration: number,
	fromUp: number,
	from: Car?,
}

type Dive = {
	startT: number,
	fromAlong: number,
	fromLateral: number,
	fromUp: number,
	target: Car,
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
	firstClaim: boolean?, -- set after the first claim; until then Heat runs slower (first-run assist)
}

export type Options = {
	seed: number?,
	session: Session?,
	profile: string?, -- "Highway" (default) or "Circuit"

	hud: boolean?, -- drive Lane 3's RunHud (default true when it exists)
	-- Round 7 (Lane 3 with Adam's opening of every lane):
	stamina: number?, -- bolts for this run (one unit per leap, bump, bonk or throw); nil = no limit (Brian R's playground)
	luck: number?, -- the server's Luck snapshot for this run (L-02); the sequence is built with it
	floatHelp: boolean?, -- the tutorial and first runs: a longer float and a PRESS AGAIN! prompt
	quietClaims: boolean?, -- the beta shows its own IT'S YOURS feed from the server's grants (R-11)
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
	stamina: number?,
	staminaMax: number?,
	luck: number,
	floatLeft: number?,
	floatDuration: number?,
	guide: { [string]: any }?,
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
	getGuideLog: (self: RunController) -> { any }, -- Round 8 (R-04)
	destroy: (self: RunController) -> (),
	finish: (self: RunController, cause: string) -> (),
	refillStamina: (self: RunController, n: number) -> (),
	StaminaChanged: any, -- Signal(value: number, max: number, kind: string): "Leap" | "Bump" | "Bonk" | "Thrown" | "Refused" | "Refill"
	Bonk: any, -- Signal(kind: string, at: CFrame): a bonk, a bump or a throw, for the beta's BONK! pop
	Boarded: any, -- Signal(model: Model): the rider landed on this car (Round 7, C-08)
	Moment: any, -- Signal(kind: "leap" | "dive", model: Model?): Round 8 (T-04) TrailMoments; model = the car the rider leaves
	getSpeed01: (self: RunController) -> number, -- Round 8 (T-03): 0 at the run's start speed, 1 at top speed
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

	-- Round 8 (R-01): the old neon disc and the bouncing ball over the target are gone; HopGuide draws the guidance (built after
	-- the Fx below, which plays its tick)

	-- Red outline on the car you are about to hit (forgiveness aid).
	local danger = Instance.new("Highlight")
	danger.Name = "DangerOutline"
	danger.FillColor = Color3.fromRGB(255, 60, 50)
	danger.FillTransparency = 0.75
	danger.OutlineColor = Color3.fromRGB(255, 70, 60)
	danger.OutlineTransparency = 0
	danger.DepthMode = Enum.HighlightDepthMode.Occluded
	danger.Enabled = false
	danger.Parent = zone

	local self = setmetatable({}, RunController) :: any
	self.seed = seed
	self._danger = danger
	self.Ended = trove:Add(Signal.new())
	self._trove = trove
	self._player = player
	self._zone = zone
	self._carsFolder = carsFolder
	self._session = session
	self._profile = RunConfig.profile(opts.profile)
	self.luck = Luck.clamp(opts.luck)
	self._sequence = RunSequence.new(seed, self._profile, self.luck)
	self._road = trove:Add(RunRoad.new(zone, seed, self._profile.scenery), "destroy")
	self._fx = trove:Add(RunFx.new(zone), "destroy")
	self._guide = trove:Add(
		HopGuide.new(zone, {
			floatHelp = opts.floatHelp == true,
			onSwing = function()
				self._fx:sound("tick", 0.18, 1.5)
			end,
		}),
		"destroy"
	)
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
	self._queued = 0
	self._laneQueue = {} :: { { RunSequence.Spawn } }
	self._laneHead = {} :: { number }
	for lane = 1, RunConfig.LANES do
		self._laneQueue[lane] = {}
		self._laneHead[lane] = 1
	end
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
	self._targetSince = 0 -- Round 8 (R-02): when the current target was taken (os.clock), for the hysteresis dwell
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
	self._graceLeft = 0
	self._hopA = 0
	self._cockpit = false
	self._cockpitCar = nil :: Car?
	-- Round 7
	self._float = nil :: Float?
	self._dive = nil :: Dive?
	self._recoverLeft = 0
	self._warnLeft = nil :: number?
	self._bumpGrace = 0
	self._floatHelp = opts.floatHelp == true
	self._quietClaims = opts.quietClaims == true
	self._staminaMax = opts.stamina
	self._stamina = opts.stamina
	self.StaminaChanged = trove:Add(Signal.new())
	self.Bonk = trove:Add(Signal.new())
	-- Round 7 (C-08): (model) whenever the rider lands on a car, so the car you ride can wear your Style Shop look
	self.Boarded = trove:Add(Signal.new())
	self.Moment = trove:Add(Signal.new()) -- Round 8 (T-04): "leap" and "dive", for TrailMoments
	trove:Add(TrailMoments.attachToRun(self), "destroy") -- Round 8 (T-03 to T-05): the trail reacts to this run
	-- the warning on the car itself at full Heat (R-02): a red outline and a red "!" over the car
	local warnLight = Instance.new("Highlight")
	warnLight.Name = "HeatWarning"
	warnLight.FillColor = Color3.fromRGB(255, 40, 40)
	warnLight.OutlineColor = Color3.fromRGB(255, 60, 60)
	warnLight.FillTransparency = 0.45
	warnLight.DepthMode = Enum.HighlightDepthMode.Occluded
	warnLight.Enabled = false
	warnLight.Parent = zone
	self._warnLight = warnLight
	local bang = Instance.new("BillboardGui")
	bang.Name = "HeatBang"
	bang.Size = UDim2.fromOffset(70, 90)
	bang.StudsOffset = Vector3.new(0, 4, 0)
	bang.AlwaysOnTop = true
	bang.Enabled = false
	local bangText = Instance.new("TextLabel")
	bangText.BackgroundTransparency = 1
	bangText.Size = UDim2.fromScale(1, 1)
	bangText.Font = Enum.Font.FredokaOne
	bangText.TextScaled = true
	bangText.Text = "!"
	bangText.TextColor3 = Color3.fromRGB(255, 50, 50)
	bangText.TextStrokeTransparency = 0
	bangText.TextStrokeColor3 = Color3.new(1, 1, 1)
	bangText.Parent = bang
	bang.Parent = zone
	self._bang = bang

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
		bounce = 0,
		bounceVel = 0,
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
		-- Round 7 (R-10): rarer cars are labelled from further away
		tag.MaxDistance = if rarity == "Legendary" then 420 elseif rarity == "Epic" then 300 else TAG_RANGE
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

-- Spawns cars as they come into range. Every car in a lane drives at that lane's speed, so
-- within a lane the seed order is also the order along the road: one queue per lane, and the
-- front of each queue is the only car that can be next to appear. Cars are created only when
-- they are within the profile's view distance, so the count stays flat however long a run lasts.
local function spawnAhead(self: any)
	local horizon = self._along + self._profile.spawnAhead
	-- A car's position is always at or past its start, so every car that could be in range has
	-- start < horizon: generate up to there and sort the new ones into their lane queues.
	local spawns = self._sequence:ensure(horizon)
	while self._queued < #spawns do
		self._queued += 1
		local spawn = spawns[self._queued]
		table.insert(self._laneQueue[spawn.lane], spawn)
	end
	for lane = 1, RunConfig.LANES do
		local queue = self._laneQueue[lane]
		local head = self._laneHead[lane]
		while head <= #queue do
			local spawn = queue[head]
			local along = self._sequence:alongAt(spawn, self._t)
			if along > horizon then
				break
			end
			head += 1
			if along > self._along - RunConfig.DESPAWN_BEHIND then
				local car = addCar(self, spawn, spawn.family, spawn.rarity, spawn.size, spawn.paint)
				car.along = along
				car.lateral = self._sequence:lateralAt(spawn, self._t)
				-- A burst as an Epic or Legendary joins the road, plus a ring for a Legendary.
				if self._t > 1 and (spawn.rarity == "Epic" or spawn.rarity == "Legendary") then
					local at = RunRoad.frame(car.along, car.lateral, car.roof + 2)
					self._fx:burst(at, CarVisual.RARITY_COLOR[spawn.rarity])
					if spawn.rarity == "Legendary" then
						self._fx:shockwave(at, 24)
					end
				end
				if self._t > 1 and (spawn.rarity == RunConfig.ALERT_RARITY or spawn.size == "Giant") then
					self._overlay:alert(
						"A " .. carName(car) .. " is on the road ahead!",
						CarTags.RARITY_TEXT[spawn.rarity]
					)
					self._fx:sound("alert", 0.5, 1.3)
				end
			end
		end
		-- Drop consumed entries now and then so the queues never grow.
		if head > 64 then
			table.move(queue, head, #queue, 1)
			for i = #queue - head + 2, #queue do
				queue[i] = nil
			end
			head = 1
		end
		self._laneHead[lane] = head
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
	local range = if self._mode == "Float"
		then RunConfig.FLOAT_REACH
		else (if self._ridden then (self._ridden :: Car).family.hopRange else 30) * self._profile.hopRangeScale
	local steer = self._steer
	local best: Car? = nil
	local bestScore = math.huge
	local current = self._target :: Car?
	local currentScore: number? = nil
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
		if car == current then
			currentScore = score
		end
		if score < bestScore then
			best, bestScore = car, score
		end
	end
	-- Round 8 (R-02): the ring never flickers between two cars. The current target stays until another car beats it by
	-- HopGuide.SWITCH_MARGIN and HopGuide.SWITCH_DWELL seconds have passed (a target that left reach or the road is dropped at once).
	if
		best
		and current
		and best ~= current
		and HopGuide.keepCurrent(currentScore, bestScore, os.clock() - self._targetSince)
	then
		return current
	end
	if best ~= current then
		self._targetSince = os.clock()
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
	local seated = (self._mode == "Riding" and self._ridden ~= nil) or self._mode == "Recover" or self._mode == "Ended"
	local lean = 0
	if seated then
		lean = -self._steer * 0.18
	end
	local bob = if seated then math.sin(self._t * 14) * 0.05 else 0
	-- In the air: a front flip on a Hop to another car, a quick twirl on a hop in place.
	local spin = CFrame.identity
	local hop = self._hop :: Hop?
	if hop and self._mode == "Hopping" then
		local a = self._hopA
		local eased = a * a * (3 - 2 * a)
		if hop.inPlace then
			spin = CFrame.Angles(0, 2 * math.pi * eased, 0)
		else
			-- Tuck at the start, full rotation through the middle, open up for the landing.
			spin = CFrame.Angles(-2 * math.pi * RunConfig.HOP_FLIPS * eased, 0, math.sin(math.pi * a) * 0.25)
		end
	end
	root.CFrame = RunRoad.frame(self._along, self._lateral, self._up + (if seated then SIT_UP else ROOT_UP) + bob)
		* CFrame.Angles(0, 0, lean)
		* spin
	if humanoid and humanoid.Sit ~= seated then
		humanoid.Sit = seated
	end
	-- Round 7 (R-05, Adam: "you see yourself on top of the car"): the rider is always hidden in the driver's seat, on every car
	-- (the beta shows a real closed car on every family), during the blink after a bonk and after the run ends; visible only in
	-- the leap and the dive.
	local hidden = seated
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

-- Round 7 (R-01): the two-press Hop. First press while riding: leap and float (costs 1 bolt). Second press while floating: dive onto
-- the ringed car. Any other press is ignored, so a held key, a repeated tap or a press during the dive never costs twice.
local leap: (self: any) -> ()
local dive: (self: any, target: Car) -> ()

function RunController.requestHop(self: any)
	if self._mode == "Ended" or not self._started then
		return
	end
	if self._mode == "Riding" then
		leap(self)
	elseif self._mode == "Float" then
		local target = self._target :: Car?
		if target then
			dive(self, target)
		end
	end
end

-- Round 8 (R-04): the dive log (what the ring showed, what was pressed, where it landed), for the feel check
function RunController.getGuideLog(self: any): { any }
	return self._guide:getDiveLog()
end

function RunController.setSteerOverride(self: any, steer: number?)
	self._input:setOverride(steer)
end

-- Test hook: the next landing misses so Foot Dash can be checked in a playtest.
function RunController.forceMiss(self: any)
	self._forceMiss = true
end

-- Stamina (Round 7) --------------------------------------------------------------------------
-- One unit per leap, per bump (then BUMP_GRACE free), per bonk on the road and per throw at full Heat; red and purple bolts hold 2
-- and 3 units (the beta's RunStamina draws them). A leap with no units left is refused. A bump, bonk or throw that takes the last
-- unit (or finds none) ends the run: WRECKED (R-06). The server counts the same events from the run report (BetaRun).

local endRun: (self: any, cause: string) -> ()

local function spend(self: any, kind: string): boolean
	if self._stamina == nil then
		return true
	end
	if kind == "Leap" then
		if self._stamina <= 0 then
			self.StaminaChanged:Fire(0, self._staminaMax, "Refused")
			return false
		end
		self._stamina -= 1
		self.StaminaChanged:Fire(self._stamina, self._staminaMax, kind)
		return true
	end
	local before = self._stamina
	self._stamina = math.max(self._stamina - 1, 0)
	self.StaminaChanged:Fire(self._stamina, self._staminaMax, kind)
	if before <= 1 then
		endRun(
			self,
			if kind == "Thrown" then "Overheated" elseif kind == "Bump" then "Wrecked by bumps" else "Out of Stamina"
		)
		return false
	end
	return true
end

function RunController.refillStamina(self: any, n: number)
	if self._stamina ~= nil then
		self._stamina = math.min(self._stamina + n, self._staminaMax)
		self.StaminaChanged:Fire(self._stamina, self._staminaMax, "Refill")
	end
end

-- Sets this run's bolts (the beta's Stamina Shop level), full. Only before the first leap.
function RunController.setStamina(self: any, max: number)
	if self._hops == 0 then
		self._staminaMax = max
		self._stamina = max
		self.StaminaChanged:Fire(max, max, "Refill")
	end
end

function RunController.getStamina(self: any): (number?, number?)
	return self._stamina, self._staminaMax
end

-- Round 8 (T-03): the run's speed ramp, 0 at START_SPEED to 1 at TOP_SPEED, whatever the profile (TrailMoments reads it each frame).
function RunController.getSpeed01(self: any): number
	local range = RunConfig.TOP_SPEED - RunConfig.START_SPEED
	return math.clamp((RunConfig.speedAt(self._t) - RunConfig.START_SPEED) / range, 0, 1)
end

leap = function(self: any)
	if not spend(self, "Leap") then
		self._overlay:banner("Out of bolts!", Color3.fromRGB(255, 120, 90))
		return
	end
	local from = self._ridden :: Car?
	self._report:push({ kind = "Leap", t = self._t, d = self._along, x = self._lateral })
	self._hops += 1
	self._float = {
		startT = self._t,
		duration = if self._floatHelp then RunConfig.FLOAT_TIME_HELP else RunConfig.FLOAT_TIME,
		fromUp = self._up,
		from = from,
	}
	if from then
		from.bounceVel += RunConfig.LAUNCH_KICK
		self._fx:burst(RunRoad.frame(from.along, from.lateral, from.roof + 0.5), Color3.fromRGB(255, 236, 170))
		retire(self, from)
		self._ridden = nil
	end
	self._keys = nil
	self._keysNeed = nil
	self._warnLeft = nil
	self._mode = "Float"
	self._fx:sound("hop", 0.6, 1.15)
	local _, root = riderParts(self)
	self._fx:setTrail(root, true)
	self.Moment:Fire("leap", if from then from.model else nil) -- Round 8 (T-04)
	if self._camera then
		self._camera:punch()
	end
end

dive = function(self: any, target: Car)
	self._report:push({ kind = "Hop", t = self._t, d = self._along, x = self._lateral, target = target.index })
	self._guide:noteDive(target, math.sqrt((target.along - self._along) ^ 2 + (target.lateral - self._lateral) ^ 2)) -- R-04
	self._dive = {
		startT = self._t,
		fromAlong = self._along,
		fromLateral = self._lateral,
		fromUp = self._up,
		target = target,
	}
	self._float = nil
	self._mode = "Dive"
	self.Moment:Fire("dive") -- Round 8 (T-04)
	self._fx:sound("hop", 0.5, 1.5)
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

endRun = function(self: any, cause: string)
	if self._mode == "Ended" then
		return
	end
	self._mode = "Ended"
	self._cause = cause
	self._target = nil
	self._float = nil
	self._dive = nil
	self._warnLeft = nil
	self._warnLight.Enabled = false
	self._bang.Enabled = false
	self._guide:hide()
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
	self.Boarded:Fire(car.model)
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
	self._graceLeft = RunConfig.LANDING_GRACE
	startKeys(self, car)
	self._fx:setSteam(car.model, 0)
	self._meter.gui.Enabled = true
end

-- Round 7 (R-07): while END RUN asks "End this run?", the run waits (nothing moves, Heat and Keys stand still).
function RunController.setPaused(self: any, paused: boolean)
	self._paused = paused == true
end

-- Round 7 (R-07): END RUN on the HUD, after the player confirms. Ends like any other end (Results, then home).
function RunController.finish(self: any, cause: string)
	endRun(self, cause)
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
	self._session.firstClaim = true
	local name = carName(car)
	local colour = CarTags.RARITY_TEXT[car.rarity]
	if self._session.owned[car.modelId] then
		self._joyrides += 1
		if not self._quietClaims then
			self._overlay:banner("Joyride Bonus! " .. name, colour)
			self._overlay:addToTray(name, colour, false)
		end
	else
		self._session.owned[car.modelId] = true
		self._session.level += RunConfig.LEVEL_PER_NEW_MODEL
		table.insert(self._claimed, name)
		if not self._quietClaims then
			self._overlay:banner("You got the Keys! " .. name, colour)
			self._overlay:addToTray(name, colour, true)
		end
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
			-- Forgiving crash box, plus a short grace after landing. Closer than the box but not
			-- inside it is a graze: the cars slide apart with a few sparks and the run goes on.
			local hitA = (car.length + ridden.length) / 2 * RunConfig.HIT_SCALE - math.abs(da)
			local hitL = (car.width + ridden.width) / 2 * RunConfig.HIT_SCALE - math.abs(dl)
			if self._graceLeft > 0 or hitA <= 0 or hitL <= 0 then
				if overlapL < overlapA then
					ridden.lateral -= math.sign(dl) * (overlapL + 0.05)
				elseif da > 0 then
					ridden.along -= overlapA + 0.05
				else
					ridden.along += overlapA + 0.05
				end
				if car.bumpCooldown <= 0 then
					car.bumpCooldown = RunConfig.BUMP_COOLDOWN
					self._fx:sparks(
						RunRoad.frame((car.along + ridden.along) / 2, (car.lateral + ridden.lateral) / 2, 1.5)
					)
					self._fx:sound("bump", 0.35, 1.4)
					if self._camera then
						self._camera:jolt(0.15)
					end
				end
				continue
			end
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
		if fresh and self._bumpGrace <= 0 then
			-- Round 7 (R-04): driving into a car costs 1 bolt, then BUMP_GRACE seconds where bumps are free
			self._bumpGrace = RunConfig.BUMP_GRACE
			self._report:push({ kind = "Bump", t = self._t, d = self._along, index = car.index })
			local at =
				RunRoad.frame((car.along + ridden.along) / 2, (car.lateral + ridden.lateral) / 2, ridden.height + 2)
			self.Bonk:Fire("Bump", at)
			self._fx:sound("bump", 0.9, 0.7)
			if self._camera then
				self._camera:jolt(0.6)
			end
			if not spend(self, "Bump") then
				return
			end
		end
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

local fall: (self: any, kind: string) -> ()

local function stepRiding(self: any, dt: number, steerInput: number, drag: number)
	local ridden = self._ridden :: Car
	local family = ridden.family
	local strong = tooStrong(self, ridden)
	self._graceLeft = math.max(self._graceLeft - dt, 0)

	-- Heat (paused while the Keys card is up). Round 7 (R-02): Heat fills in the car's Keys time plus HEAT_TO_SPARE seconds (a
	-- Common in the Circuit profile: 8 s to full, Critical at 6.8 s), half speed until the first claim of the session.
	if self._cardLeft > 0 then
		self._cardLeft -= dt
	else
		local keysTime = self._profile.keysTime[ridden.rarity] or self._profile.keysTime.Common
		local full = keysTime + RunConfig.HEAT_TO_SPARE
		self._heat += dt / full * (if self._session.firstClaim then 1 else RunConfig.FIRST_CLAIM_HEAT)
	end
	if self._heat >= 1 and not self._warnLeft then
		self._warnLeft = RunConfig.HEAT_WARN_TIME
		self._warnLight.Adornee = ridden.model
		self._warnLight.Enabled = true
		self._bang.Adornee = ridden.model
		self._bang.StudsOffset = Vector3.new(0, ridden.height + 3, 0)
		self._bang.Enabled = true
		self._fx:sound("alert", 0.8, 0.8)
		-- Round 8 declutter: no floating "HOP NOW!" banner here; the Engine Heat panel already says HOP NOW! at Meltdown
	end
	local melt = 0
	if self._warnLeft then
		self._warnLeft -= dt
		melt = 1 - math.max(self._warnLeft, 0) / RunConfig.HEAT_WARN_TIME
		-- the car flashes red, and the "!" pops
		self._warnLight.FillTransparency = if math.floor(self._warnLeft * 8) % 2 == 0 then 0.25 else 0.75
		self._bang.Size = UDim2.fromOffset(70 + 30 * math.sin(melt * math.pi), 90 + 40 * math.sin(melt * math.pi))
		if self._warnLeft <= 0 then
			self._warnLight.Enabled = false
			self._bang.Enabled = false
			self._warnLeft = nil
			fall(self, "Thrown")
			return
		end
	end
	self._meltdownLeft = nil

	-- Steering: free left/right; sluggish and drifting during Meltdown, never inverted.
	local lag = 1 - math.exp(-dt * 14)
	self._steer += (steerInput - self._steer) * lag
	local lateral = ridden.lateral + self._steer * family.steerSpeed * self._profile.steerScale * dt
	lateral += drag * RunConfig.ROAD_HALF_WIDTH * 2.4
	if self._warnLeft then
		lateral += math.sin(self._t * 30) * 4 * melt * dt -- the car shakes before it throws you
	end
	ridden.lateral = clampLateral(lateral, ridden.width)

	-- Forward.
	local factor = family.speedMultiplier
	if self._slowLeft > 0 then
		self._slowLeft -= dt
		factor *= RunConfig.REAR_SLOW_FACTOR
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

-- Round 7 (R-01) ------------------------------------------------------------------------------

-- Lands the rider on a car: the same landing as Brian R's Hop (squash, dust, ring, burst, sound).
local function landOn(self: any, car: Car)
	local _, root = riderParts(self)
	self._fx:setTrail(root, false)
	self._guide:noteLanding(car) -- R-04
	boardCar(self, car)
	car.bounceVel += RunConfig.LANDING_SQUASH
	self._fx:dust(RunRoad.frame(car.along, car.lateral, 0.5), math.max(car.width, 5))
	self._fx:shockwave(
		RunRoad.frame(car.along, car.lateral, car.roof + 0.2),
		math.max(car.width, car.length * 0.6) * 1.8
	)
	self._fx:burst(RunRoad.frame(car.along, car.lateral, car.roof + 1), Color3.fromRGB(255, 220, 110))
	self._fx:sound("land", 0.8, 0.9)
	if self._camera then
		self._camera:jolt(0.3)
	end
end

-- The car under the rider (within its roof outline plus CATCH_TOLERANCE), or nil.
local function carUnder(self: any): Car?
	for _, car in self._cars do
		if car.fade then
			continue
		end
		if
			math.abs(car.along - self._along) < car.length / 2 + RunConfig.CATCH_TOLERANCE
			and math.abs(car.lateral - self._lateral) < car.width / 2 + RunConfig.CATCH_TOLERANCE
		then
			return car
		end
	end
	return nil
end

-- A fall: BONK! on the road, or thrown at full Heat. One bolt; then a short blink and back onto the nearest car behind.
fall = function(self: any, kind: string)
	local ridden = self._ridden :: Car?
	if ridden then
		retire(self, ridden)
		self._ridden = nil
	end
	self._float = nil
	self._dive = nil
	self._keys = nil
	self._keysNeed = nil
	self._up = 0
	self._report:push({ kind = kind :: any, t = self._t, d = self._along, x = self._lateral })
	local at = RunRoad.frame(self._along, self._lateral, 3)
	self.Bonk:Fire(kind, at)
	self._fx:dust(RunRoad.frame(self._along, self._lateral, 0.5), 5)
	self._fx:sound("bump", 0.9, 0.6)
	if self._camera then
		self._camera:jolt(0.7)
	end
	local _, root = riderParts(self)
	self._fx:setTrail(root, false)
	if not spend(self, kind) then
		return -- out of bolts: endRun has run
	end
	self._overlay:banner(if kind == "Thrown" then "Too hot! Thrown off!" else "BONK!", Color3.fromRGB(255, 110, 90))
	self._mode = "Recover"
	self._recoverLeft = RunConfig.BONK_BLINK
end

local function stepFloat(self: any, dt: number, steerInput: number)
	local f = self._float :: Float
	local a = math.clamp((self._t - f.startT) / f.duration, 0, 1)
	self._hopA = a
	self._along += self._sequence:speedAt(self._t) * dt
	self._steer = steerInput
	self._lateral = clampLateral(self._lateral + steerInput * RunConfig.FLOAT_STEER * dt, RunConfig.FOOT_SIZE)
	-- up fast, a hover with a little bob, a slight sink at the end
	local rise = 1 - (1 - math.min(a / 0.3, 1)) ^ 2
	local sink = math.max(a - 0.75, 0) / 0.25
	self._up = f.fromUp + RunConfig.FLOAT_HEIGHT * rise - 3 * sink * sink + math.sin(self._t * 6) * 0.25
	if a >= 1 then
		-- no second press: a car under you catches you, otherwise the road
		local under = carUnder(self)
		if under then
			self._report:push({ kind = "Hop", t = self._t, d = self._along, x = self._lateral, target = under.index })
			self._float = nil
			landOn(self, under)
		else
			fall(self, "Bonk")
		end
	end
end

local function stepDive(self: any, _dt: number)
	local d = self._dive :: Dive
	local a = math.clamp((self._t - d.startT) / RunConfig.DIVE_TIME, 0, 1)
	self._hopA = a
	local target = d.target
	-- a car that left the road while you dived: catch whatever is under you, or the road
	if table.find(self._cars, target) == nil or target.fade then
		self._dive = nil
		local under = carUnder(self)
		if under then
			landOn(self, under)
		else
			fall(self, "Bonk")
		end
		return
	end
	local e = a * a
	self._along = d.fromAlong + (target.along - d.fromAlong) * e
	self._lateral = d.fromLateral + (target.lateral - d.fromLateral) * e
	self._up = d.fromUp + (target.seat - d.fromUp) * e
	if a >= 1 then
		self._dive = nil
		landOn(self, target)
	end
end

local function stepRecover(self: any, dt: number)
	self._recoverLeft -= dt
	self._along += self._sequence:speedAt(self._t) * 0.6 * dt
	if self._recoverLeft > 0 then
		return
	end
	-- the nearest car behind (or just beside) you; with none close, a Loaner under you
	local best: Car? = nil
	local bestGap = 120
	for _, car in self._cars do
		local gap = self._along - car.along
		if not car.fade and gap > -6 and gap < bestGap then
			best, bestGap = car, gap
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
	self._report:push({ kind = "Hop", t = self._t, d = landed.along, x = landed.lateral, target = landed.index })
	self._fx:burst(RunRoad.frame(landed.along, landed.lateral, landed.roof + 2), Color3.fromRGB(255, 220, 120))
	landOn(self, landed)
end

local function render(self: any, dt: number)
	local t = self._t
	for _, car in self._cars do
		-- Suspension spring: kicks on take-off, squashes on landing, settles in a few bounces.
		if car.bounce ~= 0 or car.bounceVel ~= 0 then
			local accel = -RunConfig.SUSPENSION_STIFFNESS * car.bounce - RunConfig.SUSPENSION_DAMPING * car.bounceVel
			car.bounceVel += accel * dt
			car.bounce += car.bounceVel * dt
			if math.abs(car.bounce) < 0.002 and math.abs(car.bounceVel) < 0.02 then
				car.bounce, car.bounceVel = 0, 0
			end
		end
		local offset = CFrame.new(0, math.clamp(car.bounce, -1.2, 1.2), 0)
			* CFrame.Angles(math.clamp(car.bounceVel * 0.012, -0.12, 0.12), 0, 0)
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
	-- Round 8 (R-01, R-02): the guidance (WS-10): a quiet lock-on ring while riding, the landing ring, the outline and the dive path
	-- (HopGuide.updateScreen, after the camera) while floating; no arrows over the road
	local target = self._target :: Car?
	local diving = self._dive :: Dive?
	self._guide:update({
		mode = self._mode,
		target = target,
		diveTarget = if diving then diving.target else nil,
		rider = { along = self._along, lateral = self._lateral, up = self._up },
		hopA = self._hopA,
		tooStrong = target ~= nil and tooStrong(self, target),
	})
end

local function updateUi(self: any)
	local stage = stageFor(self._heat, self._warnLeft ~= nil)
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
		self._t < 7 and not self._quietClaims,
		if self._profile.crashEndsRun
			then "Cut lanes to survive! Touching a car ends the run  ·  Hop: Space  ·  V: in-car view"
			else "Steer: A / D or drag  ·  Hop: Space or tap  ·  V: in-car view"
	)
	self._overlay:setLevel(self._session.level, self._session.revives)
	refreshLevel(self)
end

-- Outlines in red the car you will hit within DANGER_TIME seconds if you keep going straight.
local function updateDanger(self: any)
	local danger = self._danger :: Highlight
	local ridden = self._ridden :: Car?
	if not (self._profile.crashEndsRun and self._mode == "Riding" and ridden) then
		danger.Enabled = false
		return
	end
	local mySpeed = self._sequence:speedAt(self._t) * ridden.family.speedMultiplier
	local worst: Car? = nil
	local worstTime = RunConfig.DANGER_TIME
	for _, car in self._cars do
		if car == ridden or car.fade then
			continue
		end
		if math.abs(car.lateral - ridden.lateral) >= (car.width + ridden.width) / 2 * RunConfig.HIT_SCALE then
			continue
		end
		local gap = car.along - ridden.along - (car.length + ridden.length) / 2
		if gap < 0 then
			continue
		end
		local carSpeed = self._sequence:speedAt(self._t) * self._sequence:laneSpeed(car.lane)
		local closing = mySpeed - carSpeed
		if closing > 0 and gap / closing < worstTime then
			worst, worstTime = car, gap / closing
		end
	end
	if worst then
		danger.Adornee = worst.model
		danger.Enabled = true
	else
		danger.Enabled = false
	end
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
	if self._paused then
		return
	end
	dt = math.min(dt, 1 / 20)
	local realDt = dt
	-- Round 7 (R-01): while floating this run's own clock runs at FLOAT_SLOWMO (traffic, Heat and the run report all use it; the
	-- server's checks allow for it, BetaRun). Nothing outside this run slows.
	if self._mode == "Float" then
		dt *= RunConfig.FLOAT_SLOWMO
	end
	self._bumpGrace = math.max(self._bumpGrace - dt, 0)
	self._t += dt
	local steerInput = self._input:getSteer()
	local drag = self._input:takeDrag()

	spawnAhead(self)
	moveTraffic(self, dt)
	if self._mode == "Riding" then
		stepRiding(self, dt, steerInput, drag)
	elseif self._mode == "Float" then
		stepFloat(self, dt, steerInput)
	elseif self._mode == "Dive" then
		stepDive(self, dt)
	elseif self._mode == "Recover" then
		stepRecover(self, dt)
	end
	if self._mode == "Ended" then
		render(self, dt)
		return
	end
	self._target = if self._mode == "Riding" or self._mode == "Float" then findTarget(self) else nil

	local metres = RunConfig.toMetres(self._along)
	if metres >= self._nextMilestone then
		self._overlay:banner(string.format("%d m!", self._nextMilestone))
		self._fx:sound("claim", 0.4, 0.8)
		self._nextMilestone += RunConfig.MILESTONE_METRES
	end

	self._road:update(self._along)
	render(self, dt)
	updateDanger(self)
	placeRider(self)
	applyCockpit(self)
	local ridden = self._ridden :: Car?
	if self._cockpit and self._mode == "Riding" and ridden then
		self._camera:stepCockpit(
			realDt,
			ridden.along - ridden.length * 0.08,
			ridden.lateral,
			ridden.height * 0.72,
			speed01
		)
	else
		local lift = if self._mode == "Float" then 6 else 0
		self._camera:step(realDt, self._along, self._lateral, self._up, carLength + lift, speed01)
	end
	self._fx:setSpeedLines(self._camera:getCFrame(), if self._mode == "Float" then 1 else 0.3 + speed01 * 0.7)
	self._guide:updateScreen() -- Round 8 (R-02): the dive path, placed with this frame's final camera
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
		stage = stageFor(self._heat, self._warnLeft ~= nil),
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
		stamina = self._stamina,
		staminaMax = self._staminaMax,
		luck = self.luck,
		floatLeft = if self._float
			then (self._float :: Float).duration - (self._t - (self._float :: Float).startT)
			else nil,
		floatDuration = if self._float then (self._float :: Float).duration else nil, -- Round 8 (R-03): the HOP / DIVE button's drain ring
		guide = self._guide:getDebugState(), -- Round 8 (R-04): the guidance's own counters (the dive log is getGuideLog)
	}
end

function RunController.destroy(self: any)
	local character = self._player.Character
	if character and self._riderHidden then
		for _, d in character:GetDescendants() do
			if d:IsA("BasePart") or d:IsA("Decal") then
				(d :: any).LocalTransparencyModifier = 0
			end
		end
		self._riderHidden = false
	end
	for _, car in self._cars do
		car.model:Destroy()
	end
	table.clear(self._cars)
	self._trove:Destroy()
end

return RunController
