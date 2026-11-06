--!strict
-- CAR HOP BETA: the portals and the run. Walking into an open World portal on the island goes to that World's Launch Pad (Lane 3,
-- Client.UI.LaunchPad), and START on the pad's ramp comes back here to start Brian R's run (Client.Run.RunController, the "Circuit"
-- profile he plays). LaunchPad owns everything between runs, including the results card. While a run is on, the takeover
-- attribute MovementSpeedOwner = "CarHopBetaRun" tells the island walking speed to stand aside (vault/design/specs/walk-boost.md).
-- The run is paid through the Round 5 bridge below, and his placeholder cars are dressed as Brian L's cars (startRun).
-- Off unless ReplicatedStorage.CarHopBeta exists.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local BetaConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Beta"):WaitForChild("BetaConfig"))
if not BetaConfig.enabled() then
	return
end

local BetaRunMap = require(ReplicatedStorage.Shared.Beta:WaitForChild("BetaRunMap"))
local BetaRunNet = require(ReplicatedStorage.Shared.Beta:WaitForChild("BetaRunNet"))
local RunConfig = require(ReplicatedStorage.Shared:WaitForChild("Run"):WaitForChild("RunConfig"))
local Families = require(ReplicatedStorage.Shared.Run:WaitForChild("Families"))
local RosterFixtures = require(ReplicatedStorage.Shared:WaitForChild("UI"):WaitForChild("RosterFixtures"))
local LiveData = require(ReplicatedStorage.Shared.UI:WaitForChild("LiveData"))
local RunController = require(script.Parent.Parent:WaitForChild("Run"):WaitForChild("RunController"))
local CarTags = require(script.Parent.Parent.Run:WaitForChild("CarTags"))
local PortalPreviewState =
	require(script.Parent.Parent:WaitForChild("Home"):WaitForChild("Island"):WaitForChild("PortalPreviewState"))
local UI = script.Parent.Parent:WaitForChild("UI")
local RealCar = require(UI:WaitForChild("Prototype"):WaitForChild("RealCar"))
local StyleState = require(UI.Prototype:WaitForChild("StyleState"))
local RunScenery = require(UI:WaitForChild("WorldsUnderRoad"):WaitForChild("RunScenery"))
local Tutorial = require(UI:WaitForChild("Tutorial"))
local LaunchPad = require(UI:WaitForChild("LaunchPad"))
local RunExtras = require(UI:WaitForChild("RunHud"):WaitForChild("RunExtras"))

local player = Players.LocalPlayer
local OWNER = "CarHopBetaRun"
local ENTER = 3 -- studs from a field's plane
local BACK = 14 -- studs in front of the portal where the player comes back

-- The Rider Level "Needs" gate is not at launch (Adam, 2026-10-28, note 0022 section 0 of the forwardable messages). Brian R's
-- run still has it, so the beta switches it off from outside his files: the session level sits above every car's need (his
-- largest is NEEDS_BASE.Legendary 80 x NEEDS_SIZE.Giant 2.6 = 208), and his "Needs N" car tags and the "Rider Level" corner
-- label are hidden. Delete this when his run drops the gate (vault/design/specs/beta-driving-update-for-brian-r.md).
local GATE_OFF_LEVEL = 999

-- Brian R's family and rarity names (src/shared/Run/Families, RunConfig), for naming his cars as Brian L's (startRun)
local FAMILIES = table.freeze({
	Compact = true,
	Sedan = true,
	Pickup = true,
	Van = true,
	Sports = true,
	Motorcycle = true,
	Truck = true,
	Special = true,
})
local RARITIES = table.freeze({ Common = true, Rare = true, Epic = true, Legendary = true })

-- one play session's run state (what was claimed, free revives); not saved
local session: RunController.Session = {
	owned = {},
	level = GATE_OFF_LEVEL,
	revives = RunConfig.FREE_REVIVES,
}

local current: RunController.RunController? = nil
local runsThisSession = 0
local scenery: RunScenery.Handle? = nil -- the World beside the road (big round M8)
local extras: any = nil -- Round 7: HOP button, END RUN, IT'S YOURS, SECURED, distance, WRECKED (UI/RunHud/RunExtras)

local function root(): BasePart?
	local character = player.Character
	local r = character and character:FindFirstChild("HumanoidRootPart")
	return if r and r:IsA("BasePart") then r else nil
end

local unbridge: (cause: string) -> ()

local function stopRun(again: boolean?)
	local run = current
	current = nil
	if run then
		local state = run:getDebugState()
		unbridge(if again then "Retry" else (state.cause or "Quit"))
	end
	if run then
		run.Ended:Fire() -- what his Retry button fires: the tutorial and the scenery are listening
	end
	if scenery then
		scenery:destroy()
		scenery = nil
	end
	if extras then
		extras:destroy()
		extras = nil
	end
	if run then
		run:destroy()
	end
	-- a retry goes straight into another run: the tutorial must not read it as coming home
	if not again and player:GetAttribute("MovementSpeedOwner") == OWNER then
		player:SetAttribute("MovementSpeedOwner", nil)
	end
end

-- Round 5 (L-03, decision 0039): the run report bridge. THE RUN REPORT IS CLIENT-TRUSTED IN THE BETA: Brian R's run is
-- client-only, so the server accepts what is reported here inside hard caps and logs it; this is scaffolding for a private
-- playtest, deleted when Lane 1 reports through the server and Lane 2 checks it. The server hands out the seed, so it can
-- rebuild the run's traffic itself. This bridge listens to the run's own report signals (RunReport.Batch and .Urgent, made
-- "for whoever wires them") and never changes the run. It sends what happened, never an amount: the events as note 0021
-- shapes them, plus the beta-only `betaModel` beside a KeysComplete. The server's grants come back and are counted for the
-- Results card (LaunchPad's runTally); a claim not yet answered counts as pending ("Checking...").
local live: { runId: string?, world: string, tally: any, conns: { RBXScriptConnection } }? = nil

local function netRemote(name: string): Instance?
	local net = ReplicatedStorage:FindFirstChild(BetaConfig.NetName)
	return net and net:FindFirstChild(name)
end

-- Round 6 (E-04): the run remotes under Brian L's names (BetaRunNet: StartRun, RunEvents, KeysComplete, RunGranted)
local function runRemote(name: string): Instance?
	local net = ReplicatedStorage:FindFirstChild(BetaRunNet.FolderName)
	return net and net:FindFirstChild(name)
end

local function newTally(): any
	return { cars = {}, claimCash = 0, joyrideCash = 0, milestoneCash = 0, total = 0, pending = 0, waiting = {} }
end

local function bridge(run: any, world: string, runId: string)
	local state = { runId = runId, world = world, tally = newTally(), conns = {} }
	live = state
	local events = runRemote(BetaRunNet.Remotes.RunEvents) :: RemoteEvent?
	local keys = runRemote(BetaRunNet.Remotes.KeysComplete) :: RemoteEvent?
	local report = run._report
	if not (report and events and keys) then
		warn("[CarHopBeta] run report bridge not available: this run is not paid")
		return
	end
	table.insert(
		state.conns,
		report.Batch:Connect(function(batch: { any })
			events:FireServer(runId, batch)
		end)
	)
	table.insert(
		state.conns,
		report.Urgent:Connect(function(e: any)
			if e.kind ~= "KeysComplete" then
				return
			end
			local spawn = run._sequence and run._sequence:get(e.index)
			local betaModel = if spawn then BetaRunMap.carFor(world, spawn.family, spawn.rarity) else nil
			local t = state.tally
			if not t.waiting[e.index] then
				t.waiting[e.index] = true
				t.pending += 1
			end
			-- Round 6 (E-05): the Hop that landed on this car may still sit in the report's buffer; send it first, so the
			-- server knows the ride before the Keys arrive (remote events from one client arrive in order). Brian L's
			-- shape: (runId, event), with the beta-only betaModel inside the event.
			report:flush()
			keys:FireServer(runId, { kind = e.kind, t = e.t, d = e.d, index = e.index, betaModel = betaModel })
			-- an answer that never comes is given up after 3 s (the card then shows what is known)
			task.delay(3, function()
				if t.waiting[e.index] then
					t.waiting[e.index] = nil
					t.pending -= 1
				end
			end)
		end)
	)
end

unbridge = function(cause: string)
	local state = live
	if not state then
		return
	end
	for _, c in state.conns do
		c:Disconnect()
	end
	state.conns = {}
	local finish = netRemote(BetaConfig.Remotes.RunEnd) :: RemoteEvent?
	if finish and state.runId then
		finish:FireServer(state.runId, cause)
	end
end

task.spawn(function()
	local granted = ReplicatedStorage:WaitForChild(BetaRunNet.FolderName, 15)
	local remote = granted and granted:WaitForChild(BetaRunNet.Remotes.RunGranted, 5)
	if remote and remote:IsA("RemoteEvent") then
		remote.OnClientEvent:Connect(function(runId: any, grant: any)
			local state = live
			if not (state and state.runId == runId and type(grant) == "table") then
				return
			end
			local t = state.tally
			if type(grant.index) == "number" and t.waiting[grant.index] then
				t.waiting[grant.index] = nil
				t.pending -= 1
			end
			-- Round 7 (R-11): IT'S YOURS! and SECURED only from the server's grant
			if extras and (grant.kind == "claim" or grant.kind == "joyride") then
				local car = RosterFixtures.byId(grant.carId)
				extras:claimed(
					if car then car.name else tostring(grant.carId),
					if car then car.rarity else "Common",
					grant.kind == "claim"
				)
			end
			if grant.kind == "claim" then
				table.insert(t.cars, { carId = grant.carId, parked = grant.parked })
				t.claimCash += grant.amount
			elseif grant.kind == "joyride" then
				t.joyrideCash += grant.amount
			elseif grant.kind == "milestone" then
				t.milestoneCash += grant.amount
			end
			t.total = t.claimCash + t.joyrideCash + t.milestoneCash
		end)
	end
end)

local function startRun(world: string): RunController.RunController
	player:SetAttribute("MovementSpeedOwner", OWNER)
	-- the server's seed and run id (a short wait; with no answer the run still plays, unpaid, and says so in Output)
	local seed: number? = nil
	local runId: string? = nil
	local luck: number? = nil -- Round 7 (L-02, R-12): the server's Luck snapshot for this run
	local startFn = runRemote(BetaRunNet.Remotes.StartRun)
	if startFn and startFn:IsA("RemoteFunction") then
		local ok, reply = pcall(function()
			return startFn:InvokeServer(world, nil)
		end)
		if ok and type(reply) == "table" and type(reply.seed) == "number" and type(reply.runId) == "string" then
			seed, runId = reply.seed, reply.runId
			luck = if type(reply.luck) == "number" then reply.luck else nil
		else
			warn("[CarHopBeta] the server did not start a run for " .. world .. ": this run is not paid")
		end
	end
	-- his "owned" list follows the save: a family and rarity counts as owned when the car BetaRunMap names for it is in
	-- the Garage, so his NEW and JOYRIDE and his tags' "owned" agree with what the server pays (2026-11-05)
	local garage = LiveData.cars()
	-- his start marks his loaner's family as owned, but in the beta that family and rarity is a car to catch (the
	-- World's Loaner is never a catch): only that one mark, made inside run:start(), is ignored; his claims still count
	local starting = true
	local loanerKey = Families.LOANER .. "_Common"
	local owned = setmetatable({}, {
		__newindex = function(t: any, key: string, value: boolean)
			if not (starting and key == loanerKey) then
				rawset(t, key, value)
			end
		end,
	}) :: { [string]: boolean }
	for family in FAMILIES do
		for rarity in RARITIES do
			local carId = BetaRunMap.carFor(world, family, rarity)
			if carId and garage[carId] then
				rawset(owned, family .. "_" .. rarity, true)
			end
		end
	end
	session.owned = owned
	-- Round 7: the tutorial run and the first two runs of a session float longer and say PRESS AGAIN! (R-01, session only); the
	-- beta shows its own IT'S YOURS feed from the server's grants, so his claim banners stay quiet (R-11)
	runsThisSession += 1
	local help = player:GetAttribute(BetaConfig.TutorialDoneAttribute) ~= true
		or runsThisSession <= RunConfig.FLOAT_HELP_RUNS
	local run = RunController.new({
		session = session,
		profile = "Circuit",
		seed = seed,
		luck = luck,
		floatHelp = help,
		quietClaims = true,
	})
	current = run
	-- Round 7 (C-08): the car you ride wears your Style Shop look (paint, decal, wheels and trail), its wheels turning; the car
	-- you leave goes back to how Brian L made it
	local styleRigs: { [Model]: any } = {}
	local wearing: any = nil
	local riddenModel: Model? = nil
	local function wear(rig: any, on: boolean)
		rig:setPaint(if on then StyleState.item("Paint") else nil)
		rig:setDecal(if on then StyleState.item("Decals") else nil)
		rig:setWheels(if on then StyleState.item("Wheels") else nil)
		rig:setTrail(if on then StyleState.item("Trails") else nil)
	end
	run.Boarded:Connect(function(model: Model)
		riddenModel = model
		if wearing then
			wear(wearing, false)
		end
		wearing = styleRigs[model]
		if wearing then
			wear(wearing, true)
			wearing:clearTrail()
		end
	end)
	local spinner: RBXScriptConnection? = nil
	spinner = RunService.Heartbeat:Connect(function(dt: number)
		if current ~= run then
			if spinner then
				spinner:Disconnect()
			end
			return
		end
		if wearing then
			wearing:spin(dt * 18)
		end
	end)
	if runId then
		bridge(run, world, runId)
	else
		live = { runId = nil, world = world, tally = newTally(), conns = {} }
	end
	run:start()
	starting = false
	-- the run's keyboard hint names keys and sits on the Heat panel; phones play too. A label only: nothing else changes.
	local overlay = player.PlayerGui:FindFirstChild("Lane1RunOverlay")
	if overlay then
		-- the Rider Level corner label is filled in after start, so each label is checked again when its text changes
		local function hideLabel(d: TextLabel)
			if string.find(d.Text, "Cut lanes", 1, true) or string.find(d.Text, "Rider Level", 1, true) == 1 then
				d.Visible = false
			end
			-- his banner and tray name the family ("You got the Keys! BIG Common Motorcycle"): they name the real car,
			-- as the road tags do (one family and rarity is always one car, BetaRunMap)
			local rarity, family = string.match(d.Text, "(%a+) (%a+)$")
			if rarity and family and RARITIES[rarity] and FAMILIES[family] then
				local car = RosterFixtures.byId(BetaRunMap.carFor(world, family, rarity) or "")
				if car then
					d.Text = string.sub(d.Text, 1, #d.Text - #rarity - #family - 1) .. car.rarity .. " " .. car.name
				end
			end
		end
		local function watchLabel(d: Instance)
			if d:IsA("TextLabel") then
				hideLabel(d)
				d:GetPropertyChangedSignal("Text"):Connect(function()
					hideLabel(d)
				end)
			end
		end
		for _, d in overlay:GetDescendants() do
			watchLabel(d)
		end
		overlay.DescendantAdded:Connect(watchLabel) -- goes with his overlay, which each run replaces
	end
	-- the gate is off (GATE_OFF_LEVEL): his "Needs N" line on each car tag would only read "(you 999)", so it is hidden
	local zone = Workspace:FindFirstChild("Lane1_RunZone")
	if zone then
		local function hideNeeds(d: Instance)
			if d:IsA("TextLabel") and d.Name == "Needs" and d.Parent and d.Parent.Name == "Tag" then
				d.Visible = false
			end
		end
		for _, d in zone:GetDescendants() do
			hideNeeds(d)
		end
		zone.DescendantAdded:Connect(hideNeeds) -- goes with the zone, which his run destroys
		-- Brian L's cars on the road (2026-11-05, Adam): each of his placeholder cars shows the showroom car that BetaRunMap
		-- names for it, the same car the server pays for when it is claimed. His model stays and keeps moving (the real car
		-- rides inside it); its parts are only hidden, so his run is unchanged. The rarity underglow stays visible. A
		-- motorcycle shows a car too, sized to the bike (there is no real bike, and a catch is always a car). The car the
		-- player starts on (no tag) is the car picked on the launch card.
		local function dress(model: Instance)
			if not (model:IsA("Model") and string.sub(model.Name, 1, 6) == "Proxy_") then
				return
			end
			local family = model:GetAttribute("Family")
			local rarity = model:GetAttribute("Rarity")
			if type(family) ~= "string" or type(rarity) ~= "string" then
				return
			end
			local carId = if model:FindFirstChild("Tag", true)
				then BetaRunMap.carFor(world, family, rarity)
				else StyleState.car()
			if not carId then
				return
			end
			local size = model:GetExtentsSize()
			-- Transparency, not LocalTransparencyModifier: his in-car view and fade set the modifier back
			local hidden: { [BasePart]: number } = {}
			for _, d in model:GetDescendants() do
				if d:IsA("BasePart") and d.Name ~= "Underglow" then
					hidden[d] = d.Transparency
					d.Transparency = 1
				end
			end
			local rig = RealCar.mount(model, { length = size.Z, height = size.Y })
			rig:pivotTo(model:GetPivot())
			rig:setCar(carId)
			if rig.source ~= carId then
				-- no model for this car: the placeholder shows again rather than the stand-in supercar
				rig:destroy()
				for p, was in hidden do
					p.Transparency = was
				end
				return
			end
			styleRigs[model] = rig
			if model == riddenModel then
				wearing = rig
				wear(rig, true)
			end
			model.Destroying:Connect(function()
				styleRigs[model] = nil
				if wearing == rig then
					wearing = nil
				end
				rig:destroy()
			end)
			-- his tag names the family ("Van"): it names the real car instead. Round 7 (R-10): the rarity word is the real car's
			-- (Uncommon included), with the edition first when the car is an edition car
			local tag = model:FindFirstChild("Tag")
			local title = tag and tag:FindFirstChild("Title")
			local word = tag and tag:FindFirstChild("Rarity")
			local car = RosterFixtures.byId(carId)
			if title and title:IsA("TextLabel") and car then
				title.Text = car.name
			end
			if word and word:IsA("TextLabel") and car then
				local variant = model:GetAttribute("Variant")
				word.Text = CarTags.wordFor(car.rarity, if type(variant) == "string" then variant else nil)
				word.TextColor3 = CarTags.WORD_COLOUR[car.rarity] or word.TextColor3
			end
		end
		local traffic = zone:FindFirstChild("Traffic") or zone
		for _, d in traffic:GetDescendants() do
			dress(d)
		end
		traffic.ChildAdded:Connect(dress)
	end
	extras = RunExtras.attach(run, { world = world, floatHelp = help })
	Tutorial.attachRun(run) -- the tutorial's run steps read the run, they never change it
	if RunScenery.enabled() then
		scenery = RunScenery.attach(world, run)
	end
	print(string.format("[CarHopBeta] %s run started (seed %d)", world, run.seed))
	return run
end

LaunchPad.configure({
	startRun = startRun,
	stopRun = stopRun,
	runTally = function(): any
		return if live then live.tally else newTally()
	end,
	revive = function()
		if current then
			current:revive()
		end
	end,
} :: any)

if RunScenery.enabled() then
	RunScenery.prepareAll() -- the three Worlds load in the background, so a run starts in its World
end
LaunchPad.prepare()

player.CharacterAdded:Connect(function()
	if current then
		stopRun()
	end
	LaunchPad.reset()
end)

-- where a portal puts the player back: the island side of its field, facing it, standing on the real floor there
-- (2026-11-05: the height came from the field's bottom edge, which sits about 3 studs under the plaza, so the player
-- came back inside the floor)
local function backTo(field: BasePart, r: BasePart): CFrame
	local front = field.CFrame * CFrame.new(0, 0, -BACK)
	local side = if (front.Position - field.Position):Dot(r.Position - field.Position) >= 0
		then front
		else field.CFrame * CFrame.new(0, 0, BACK)
	local ground = side.Position - Vector3.new(0, field.Size.Y / 2 - 3, 0)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { field.Parent :: Instance, r.Parent :: Instance }
	params.RespectCanCollide = true
	local hit = Workspace:Raycast(side.Position + Vector3.new(0, 20, 0), Vector3.new(0, -60, 0), params)
	if hit then
		local humanoid = (r.Parent :: Instance):FindFirstChildOfClass("Humanoid")
		local lift = r.Size.Y / 2 + (if humanoid then humanoid.HipHeight else 2) + 0.3
		ground = Vector3.new(side.Position.X, hit.Position.Y + lift, side.Position.Z)
	end
	return CFrame.lookAt(ground, Vector3.new(field.Position.X, ground.Y, field.Position.Z))
end

local last = 0
RunService.Heartbeat:Connect(function()
	local now = os.clock()
	if LaunchPad.phase() ~= "island" or now - last < 0.1 then
		return
	end
	last = now
	local r = root()
	local fields = Workspace:FindFirstChild("Lane3_PortalFields")
	if not (r and fields) then
		return
	end
	local atLocked = false
	for _, carrier in fields:GetChildren() do
		-- the middle carrier of each field is named "<World>Field"
		if carrier:IsA("BasePart") and string.sub(carrier.Name, -5) == "Field" then
			local world = string.sub(carrier.Name, 1, -6)
			local p = carrier.CFrame:PointToObjectSpace(r.Position)
			local half = carrier.Size / 2
			if math.abs(p.X) < half.X and math.abs(p.Y) < half.Y + 3 and math.abs(p.Z) < ENTER + 2 then
				if PortalPreviewState.isLocked(world) then
					atLocked = true
					LaunchPad.lockedPortal(world)
				elseif math.abs(p.Z) < ENTER then
					LaunchPad.enter(world, backTo(carrier, r))
					return
				end
			end
		end
	end
	if not atLocked then
		LaunchPad.lockedAway()
	end
end)

-- Studio test driver (Round 5, L-07 and the multi-client suites): PlayerGui.CarHopBetaControl:Invoke(command, arg).
--   "launch" world   stand on the World's pad and press START (LaunchPad.debug)
--   "autopilot" on   a simple driver: steer round the car ahead, hop when the Keys are done or Heat is high (the same rule
--                    as Brian R's playground driver, written here; his files are not touched)
--   "state"          the run's debug state, the server's tally for this run and the Launch Pad phase
--   "retry" / "home" press the Results card's buttons
-- Nothing here exists outside Studio.
if RunService:IsStudio() then
	local autopilot = false
	local fakeScenery: any = nil
	local lastHop = 0
	local control = Instance.new("BindableFunction")
	control.Name = "CarHopBetaControl"
	local function handleCommand(command: string, arg: any): any
		if command == "launch" then
			LaunchPad.debug("enter", arg)
			task.wait(3.5)
			return LaunchPad.debug("start")
		elseif command == "autopilot" then
			autopilot = arg == true
			if not autopilot and current then
				current:setSteerOverride(nil)
			end
			return autopilot
		elseif command == "state" then
			local s = if current then current:getDebugState() else nil
			return {
				phase = LaunchPad.phase(),
				mode = s and s.mode,
				metres = s and s.metres,
				claimed = s and s.claimed,
				joyrides = s and s.joyrides,
				runId = live and live.runId,
				tally = live and live.tally,
			}
		elseif command == "retry" or command == "home" then
			return LaunchPad.debug(command)
		elseif command == "enter" then
			return LaunchPad.debug("enter", arg) -- Round 7: stand on a pad without starting a run
		elseif command == "pause" or command == "resume" then
			if current then
				current:setPaused(command == "pause")
			end
			return command
		elseif command == "sheet" and type(arg) == "string" then
			-- Round 7 (C-02): all 27 cars in one painted contact sheet, far from everything ("sheet:off" removes it)
			local old = workspace:FindFirstChild("Lane3ContactSheet")
			if old then
				old:Destroy()
			end
			if arg == "off" then
				return "off"
			end
			local Catalog = require(ReplicatedStorage.Shared.UI.CosmeticPreviewCatalog)
			local item = Catalog.byId("Paint", arg)
			local folder = Instance.new("Folder")
			folder.Name = "Lane3ContactSheet"
			folder.Parent = workspace
			local base = Vector3.new(9000, 1500, 0)
			for i, e in RealCar.list() do
				local rig = RealCar.mount(folder, { length = 11, height = 6 })
				rig:setCar(e.name)
				local col, row = (i - 1) % 7, (i - 1) // 7
				rig:pivotTo(CFrame.new(base + Vector3.new(col * 15, 0, row * 16)) * CFrame.Angles(0, math.rad(90), 0))
				rig:setPaint(item)
			end
			return #RealCar.list()
		elseif command == "scenery" and type(arg) == "string" then
			-- Round 7 (R-08): a pretend run at a set distance ("scenery:Downtown/9500", "scenery:off"), to check the World keeps
			-- coming in laps without driving 10 minutes. Reports each World folder standing and how far its nearest part is
			-- from where the car would be.
			if arg == "off" then
				if fakeScenery then
					fakeScenery.ended:Fire()
					fakeScenery.handle:destroy()
					fakeScenery = nil
				end
				return "off"
			end
			local world, at = string.match(arg, "^(%a+)/(%d+)$")
			if not (world and at) then
				return "use World/studs"
			end
			if not fakeScenery then
				local ended = Instance.new("BindableEvent")
				local fake = { along = 0, ended = ended, handle = nil :: any }
				local runLike = {
					getDebugState = function(_self: any)
						return { along = fake.along }
					end,
					Ended = ended.Event,
				}
				fake.handle = RunScenery.attach(world, runLike :: any)
				fakeScenery = fake
			end
			fakeScenery.along = tonumber(at) :: number
			task.wait(8)
			local carZ = (RunConfig.ORIGIN * CFrame.new(0, 0, -fakeScenery.along)).Position.Z
			local out = {}
			for _, f in workspace:GetChildren() do
				if f.Name == "Lane3_WorldUnderRoad" then
					local n, nearest, ahead = 0, math.huge, 0
					for _, d in f:GetDescendants() do
						if d:IsA("BasePart") then
							n += 1
							nearest = math.min(nearest, math.abs(d.Position.Z - carZ))
							if d.Position.Z < carZ - 50 and d.Position.Z > carZ - 1500 then
								ahead += 1
							end
						end
					end
					table.insert(out, string.format("%d parts, nearest %d studs, %d ahead", n, nearest, ahead))
				end
			end
			return table.concat(out, " | ")
		elseif command == "aura" and type(arg) == "string" then
			-- Round 7 (K-01): "Cruiser/1,Executive/1,Bolt/1,Minnow/4" parks those cars with their Raceway aura in front of you
			local RacewayAura = require(UI.Prototype.Style.RacewayAura) :: any
			local old = workspace:FindFirstChild("Lane3AuraTest")
			if old then
				old:Destroy()
			end
			local folder = Instance.new("Folder")
			folder.Name = "Lane3AuraTest"
			folder.Parent = workspace
			local at = root()
			if not at or arg == "off" then
				return "off"
			end
			local base = (at :: BasePart).CFrame * CFrame.new(-18, -2.5, -26)
			local n = 0
			for entry in string.gmatch(arg, "[^,]+") do
				local name, ed = string.match(entry, "^(.-)/(%d)$")
				if name then
					local rig = RealCar.mount(folder, { length = 12.6, height = 5.2 })
					rig:setCar(name)
					rig:pivotTo(base * CFrame.new(n * 12, 0, 0) * CFrame.Angles(0, math.rad(90), 0))
					task.wait(0.5)
					if rig._body then
						RacewayAura.attach(rig._body.model, name, tonumber(ed))
					end
					n += 1
				end
			end
			return n
		elseif command == "style" and type(arg) == "string" then
			-- Round 7 (C-08): "Paint/galaxy" buys (through the server) and wears an item
			local tab, id = string.match(arg, "^(%a+)/(.+)$")
			if tab and id then
				StyleState.buy(tab, id)
				task.wait(0.8)
				StyleState.equip(tab, id)
				task.wait(0.5)
				return (StyleState.get().equipped :: any)[tab]
			end
		end
		return "unknown command " .. tostring(command)
	end
	control.OnInvoke = handleCommand
	control.Parent = player:WaitForChild("PlayerGui")
	-- Round 7: the Studio MCP cannot invoke that BindableFunction in Adam's Studio (it lacks the Network capability), so the same
	-- commands also come in through a LocalPlayer attribute: CarHopBetaCmd = "launch:Downtown", "autopilot:on", "state", "home",
	-- "hop", "end". The answer (JSON) is written to CarHopBetaCmdResult. Studio only.
	player:GetAttributeChangedSignal("CarHopBetaCmd"):Connect(function()
		local text = player:GetAttribute("CarHopBetaCmd")
		if type(text) ~= "string" or text == "" or text == "ping" then
			return
		end
		player:SetAttribute("CarHopBetaCmd", "")
		local command, arg = string.match(text, "^(%w+):?(.*)$")
		task.spawn(function()
			local ok, result = pcall(function(): any
				if command == "hop" then
					if current then
						current:requestHop()
					end
					return if current then current:getDebugState().mode else "no run"
				elseif command == "end" then
					if current then
						current:finish("Ended by you")
					end
					return "ended"
				elseif command == "debug" then
					return if current then current:getDebugState() else nil
				end
				return handleCommand(
					command or "",
					if arg == "on" then true elseif arg == "off" then false elseif arg ~= "" then arg else nil
				)
			end)
			local HttpService = game:GetService("HttpService")
			local encoded = pcall(function()
				return HttpService:JSONEncode({ ok = ok, result = result })
			end)
			player:SetAttribute(
				"CarHopBetaCmdResult",
				if encoded then HttpService:JSONEncode({ ok = ok, result = result }) else tostring(result)
			)
		end)
	end)
	RunService.Heartbeat:Connect(function()
		local run = current
		if not (autopilot and run) then
			return
		end
		local s = run:getDebugState()
		if s.mode == "Riding" then
			local blocked = s.aheadGap ~= nil and (s.aheadGap :: number) < 90
			run:setSteerOverride(if blocked then (if s.lateral > 0 then -1 else 1) else 0)
			local keysDone = s.keysNeed == nil
			local wantHop = (keysDone and s.heat > 0.3) or s.heat > 0.8 or (blocked and (s.aheadGap :: number) < 8)
			if wantHop and s.target and os.clock() - lastHop > 0.8 then
				lastHop = os.clock()
				run:requestHop()
			end
		elseif s.mode == "Float" and s.target then
			-- Round 7 (R-01): the second press dives onto the ringed car
			run:requestHop()
		end
	end)
end
