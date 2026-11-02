--!strict
-- TutorialIslandAdapter: the seam between the tutorial and the island (BRIEF M11-09). Lane 3 owns every event here. Like the
-- run adapter it publishes one stream of named events and says what it can and cannot see.
--
-- TWO MODES
--   Standin (default; the HUD playground): events come from adapter:emit(name, data); targets come from options.targets
--     (Vector3 positions) and the route is a straight polyline unless options.nav is given.
--   Real (the beta): everything below is read from the live world. Nothing is sent, nothing is changed.
--
-- EVENTS
--   PortalEntered {world}    the local character stepped into a portal field (Workspace.Lane3_PortalFields.<World>Field, the
--                            same box test BetaRun uses: inside the carrier's X and Y extent and within 3 studs of its plane)
--   PortalFailed             the controller asks for this; the adapter never invents it
--   ArrivedHome              the run takeover attribute MovementSpeedOwner went from "CarHopBetaRun" back to nil: BetaRun
--                            has put the character back on the island (beta only)
--   UpgradeOpened            PlayerGui.Lane3RacewayPanel appeared (the Raceway upgrade or parking card)
--   UpgradeConfirmed         the home plot's SpeedwayLevel attribute went UP (the server's confirmed result; in Studio the
--                            preview attribute Lane3SpeedwayPreviewLevel_PlotNN counts too)
--   LapCue                   a Lineup car crossed the finish on the home plot (LappingPreview.Crossed: the Studio preview
--                            FIXTURE, never a real Lap Pay; no Cash is granted or shown by this)
--   ShopOpened               options.isShopOpen() went from false to true (the Shop screen opened)
--   CarParked                stand-in only (see capabilities): there is no Lineup control in the beta
--
-- CAPABILITIES (adapter:capabilities())
--   portal   always true: the Downtown field when it exists, else the planned portal position from the path graph
--   home     ArrivedHome can be observed (beta marker present) or is stand-in
--   lineup   a Park control exists. Real: false unless options.lineup is supplied (the beta has a parking SIGN that buys
--            spots, not a control that parks a car, so step 7 is skipped there and reported)
--   lapCue   LappingPreview exists and is running (Studio fixture), or stand-in
--   upgrade  the home plot was found and has a numeric SpeedwayLevel, or stand-in
--   shop     options.isShopOpen was supplied, or stand-in
--
-- TARGETS (adapter:getTarget(key) -> Vector3?)  DowntownPortal, Shopkeeper, Paddock, Raceway
--   Found at run time from the plot the server gave this player (player attribute HomePlot, then the Studio preview home).
--   Falls back to the plot nodes of TutorialWaypoints.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Signal = require(ReplicatedStorage.Packages.Signal)
local Trove = require(ReplicatedStorage.Packages.Trove)
local Waypoints = require(script.Parent.TutorialWaypoints)

local IslandAdapter = {}
IslandAdapter.__index = IslandAdapter

local RUN_OWNER = "CarHopBetaRun"
local FIELD_ENTER = 3 -- studs from a field's plane (the same number BetaRun uses)
local POLL = 0.12 -- seconds between world checks

export type Options = {
	mode: string?, -- "Standin" (default) or "Real"
	targets: { [string]: Vector3 }?, -- Standin: positions by target key
	nav: ((from: Vector3, to: Vector3) -> { Vector3 })?, -- a route builder (default: the island graph in Real, straight in Standin)
	isShopOpen: (() -> boolean)?,
	lineup: boolean?, -- true when a Park control exists
	groundY: number?, -- the trail height, and the height Real targets are brought down to (default 0.3)
}

export type IslandAdapter = typeof(setmetatable(
	{} :: {
		Event: any,
		mode: string,
		_trove: any,
		_options: Options,
		_graph: Waypoints.Graph,
		_inField: { [string]: boolean },
		_level: number?,
		_shopOpen: boolean,
		_panelOpen: boolean,
		_calibrated: boolean,
		_emitted: { [string]: number },
		_lapping: any,
		_destroyed: boolean,
	},
	IslandAdapter
))

local function player(): Player
	return Players.LocalPlayer
end

local function rootPart(): BasePart?
	local character = player().Character
	local r = character and character:FindFirstChild("HumanoidRootPart")
	return if r and r:IsA("BasePart") then r else nil
end

local function fire(self: IslandAdapter, name: string, data: { [string]: any }?)
	if self._destroyed then
		return
	end
	self._emitted[name] = (self._emitted[name] or 0) + 1
	self.Event:Fire(name, data or {})
end

-- the plot the server gave this player ("HomePlot"), then the Studio preview home, then plot 3 like the playground
local function homePlot(): (Model?, number)
	local given = player():GetAttribute("HomePlot")
	local preview = player():GetAttribute("Lane3SpeedwayPreviewHome")
	local index = if type(given) == "number" then given elseif type(preview) == "number" then preview else 3
	local root = Workspace:FindFirstChild("Lane3_IslandPreview")
	local island = root and root:FindFirstChild("Island")
	local plots = island and island:FindFirstChild("Plots")
	if plots then
		for _, plot in plots:GetChildren() do
			local n = tonumber(string.match(plot.Name, "^Plot(%d+)$"))
			if plot:IsA("Model") and (plot:GetAttribute("PlotIndex") == index or n == index) then
				return plot, index
			end
		end
	end
	return nil, index
end

local function levelOf(plot: Model?, index: number): number?
	local preview = player():GetAttribute(string.format("Lane3SpeedwayPreviewLevel_Plot%02d", index))
	if type(preview) == "number" then
		return preview
	end
	local all = player():GetAttribute("Lane3SpeedwayPreviewLevel")
	if type(all) == "number" then
		return all
	end
	local real = if plot then plot:GetAttribute("SpeedwayLevel") else nil
	return if type(real) == "number" then real else nil
end

local function fields(): Instance?
	return Workspace:FindFirstChild("Lane3_PortalFields")
end

local function fieldPart(world: string): BasePart?
	local folder = fields()
	local part = folder and folder:FindFirstChild(world .. "Field")
	return if part and part:IsA("BasePart") then part else nil
end

function IslandAdapter.new(options: Options?): IslandAdapter
	local o: Options = options or {}
	local trove = Trove.new()
	local self = setmetatable({
		Event = trove:Add(Signal.new()),
		mode = o.mode or "Standin",
		_trove = trove,
		_options = o,
		_graph = Waypoints.new({ y = o.groundY }),
		_inField = {},
		_level = nil,
		_shopOpen = false,
		_panelOpen = false,
		_calibrated = false,
		_emitted = {},
		_lapping = nil,
		_destroyed = false,
	}, IslandAdapter)
	if self.mode == "Real" then
		IslandAdapter._startReal(self)
	elseif o.isShopOpen then
		IslandAdapter._startShopWatch(self)
	end
	return self
end

function IslandAdapter._startShopWatch(self: IslandAdapter)
	local isOpen = self._options.isShopOpen
	if not isOpen then
		return
	end
	local acc = 0
	self._trove:Connect(RunService.Heartbeat, function(dt: number)
		acc += dt
		if acc < 0.1 then
			return
		end
		acc = 0
		local ok, open = pcall(isOpen)
		local now = ok and open == true
		if now and not self._shopOpen then
			fire(self, "ShopOpened", {})
		end
		self._shopOpen = now
	end)
end

function IslandAdapter._startReal(self: IslandAdapter)
	local trove: any = self._trove
	-- Lap cue (the Studio preview fixture), optional
	local client = script.Parent.Parent.Parent
	local home = client:FindFirstChild("Home")
	local island = home and home:FindFirstChild("Island")
	local module = island and island:FindFirstChild("LappingPreview")
	if module and module:IsA("ModuleScript") then
		local ok, result = pcall(require, module)
		if ok and type(result) == "table" then
			self._lapping = result
			local crossed = (result :: any).Crossed
			if crossed and type(crossed.Connect) == "function" then
				trove:Add(crossed:Connect(function(plot: Instance)
					local mine = homePlot()
					if mine ~= nil and plot == mine then
						fire(self, "LapCue", {})
					end
				end))
			end
		end
	end

	-- the run takeover ends: the beta has put the character back on the island
	local lastOwner = player():GetAttribute("MovementSpeedOwner")
	trove:Connect(player():GetAttributeChangedSignal("MovementSpeedOwner"), function()
		local now = player():GetAttribute("MovementSpeedOwner")
		if lastOwner == RUN_OWNER and now == nil then
			fire(self, "ArrivedHome", {})
		end
		lastOwner = now
	end)

	if self._options.isShopOpen then
		IslandAdapter._startShopWatch(self)
	end

	local plotNow, indexNow = homePlot()
	self._level = levelOf(plotNow, indexNow)
	local acc = 0
	trove:Connect(RunService.Heartbeat, function(dt: number)
		acc += dt
		if acc < POLL then
			return
		end
		acc = 0
		-- calibrate the path graph once, to the real Downtown field
		if not self._calibrated then
			local part = fieldPart("Downtown")
			if part then
				Waypoints.calibrate(self._graph, part.Position)
				self._calibrated = true
			end
		end
		-- portal fields
		local r = rootPart()
		local folder = fields()
		if r and folder then
			for _, carrier in folder:GetChildren() do
				if carrier:IsA("BasePart") and string.sub(carrier.Name, -5) == "Field" then
					local world = string.sub(carrier.Name, 1, -6)
					local p = carrier.CFrame:PointToObjectSpace(r.Position)
					local half = carrier.Size / 2
					local inside = math.abs(p.X) < half.X and math.abs(p.Y) < half.Y + 3 and math.abs(p.Z) < FIELD_ENTER
					if inside and not self._inField[world] then
						fire(self, "PortalEntered", { world = world })
					end
					self._inField[world] = inside
				end
			end
		end
		-- the Raceway upgrade level (the server's confirmed result)
		local plot, index = homePlot()
		local level = levelOf(plot, index)
		if level ~= nil then
			if self._level ~= nil and level > self._level then
				fire(self, "UpgradeConfirmed", { level = level })
			end
			self._level = level
		end
		-- the Raceway panel
		local gui = player():FindFirstChild("PlayerGui")
		local panel = gui and gui:FindFirstChild("Lane3RacewayPanel")
		local open = panel ~= nil
		if open and not self._panelOpen then
			fire(self, "UpgradeOpened", {})
		end
		self._panelOpen = open
	end)
end

function IslandAdapter.emit(self: IslandAdapter, name: string, data: { [string]: any }?)
	fire(self, name, data)
end

function IslandAdapter.capabilities(self: IslandAdapter): { [string]: boolean }
	if self.mode ~= "Real" then
		return {
			portal = true,
			home = true,
			lineup = true,
			lapCue = true,
			upgrade = true,
			shop = true,
			real = false,
		}
	end
	local plot, index = homePlot()
	local lapping = self._lapping :: any
	local lapRunning = false
	if lapping and type(lapping.running) == "function" then
		local ok, running = pcall(lapping.running)
		lapRunning = ok and running == true
	end
	return {
		portal = true, -- the Downtown field when it exists, else the planned portal position from the path graph
		home = ReplicatedStorage:FindFirstChild("CarHopBeta") ~= nil,
		lineup = self._options.lineup == true,
		lapCue = lapRunning,
		upgrade = levelOf(plot, index) ~= nil,
		shop = self._options.isShopOpen ~= nil,
		real = true,
	}
end

function IslandAdapter.playerPosition(_self: IslandAdapter): Vector3?
	local r = rootPart()
	return if r then r.Position else nil
end

-- The look of a target's arrow and glow: how high the arrow floats (studs) and the glow disc radius. A portal is 30 tall.
function IslandAdapter.getTargetStyle(_self: IslandAdapter, key: string): { height: number, radius: number }
	if key == "DowntownPortal" then
		return { height = 34, radius = 12 }
	elseif key == "Raceway" then
		return { height = 12, radius = 8 }
	end
	return { height = 9, radius = 5 }
end

-- A world position for a target key, or nil. Real targets are brought down to the ground height (the arrow floats above it).
function IslandAdapter.getTarget(self: IslandAdapter, key: string): Vector3?
	local fixed = self._options.targets and self._options.targets[key]
	if fixed then
		return fixed
	end
	if self.mode ~= "Real" then
		return nil
	end
	local found = IslandAdapter._findReal(self, key)
	if found then
		return Vector3.new(found.X, self._options.groundY or 0.3, found.Z)
	end
	return nil
end

function IslandAdapter._findReal(self: IslandAdapter, key: string): Vector3?
	if key == "DowntownPortal" then
		local part = fieldPart("Downtown")
		return if part then part.Position else Waypoints.nodePosition(self._graph, "PortalDowntown")
	end
	local plot, index = homePlot()
	if key == "Shopkeeper" then
		local look = plot and plot:FindFirstChild("SpeedwayLook")
		local keeper = look and look:FindFirstChild("Shopkeeper", true)
		if keeper and keeper:IsA("Model") then
			return keeper:GetPivot().Position
		end
		if look then
			for _, d in look:GetDescendants() do
				if d:IsA("BasePart") and d:GetAttribute("ShopPromptAnchor") then
					return d.Position
				end
			end
		end
		return Waypoints.plotNode(self._graph, index, "Front")
	elseif key == "Paddock" then
		local look = plot and plot:FindFirstChild("ParkingLook")
		if look then
			for _, d in look:GetDescendants() do
				if d:IsA("BasePart") and d:GetAttribute("ParkingPromptAnchor") then
					return d.Position
				end
			end
		end
		return Waypoints.plotNode(self._graph, index, "Aisle")
	elseif key == "Raceway" then
		return Waypoints.plotNode(self._graph, index, "Front")
	end
	return nil
end

-- The trail from `from` to a target key: along the path graph on the island, straight in a fixture.
function IslandAdapter.route(self: IslandAdapter, from: Vector3, key: string): { Vector3 }
	local to = IslandAdapter.getTarget(self, key)
	if not to then
		return {}
	end
	local nav = self._options.nav
	if nav then
		local ok, points = pcall(nav, from, to)
		if ok and type(points) == "table" then
			return points :: { Vector3 }
		end
	end
	if self.mode == "Real" then
		return Waypoints.route(self._graph, from, to)
	end
	return Waypoints.straight(Vector3.new(from.X, to.Y, from.Z), to)
end

function IslandAdapter.getDebugState(self: IslandAdapter): { [string]: any }
	local plot, index = homePlot()
	return {
		mode = self.mode,
		emitted = table.clone(self._emitted),
		listeners = #self.Event:GetConnections(), -- tutorial listeners on this adapter (1 while a tutorial runs)
		homePlot = index,
		homePlotFound = plot ~= nil,
		level = self._level,
		calibrated = self._calibrated,
		graph = Waypoints.getDebugState(self._graph),
		capabilities = IslandAdapter.capabilities(self),
		notObserved = {
			"a Lineup Park control (the beta has none)",
			"real Lap Pay (the lap cue is the Studio LappingPreview fixture)",
		},
	}
end

function IslandAdapter.destroy(self: IslandAdapter)
	if self._destroyed then
		return
	end
	self._destroyed = true
	self._trove:Destroy()
end

return IslandAdapter
