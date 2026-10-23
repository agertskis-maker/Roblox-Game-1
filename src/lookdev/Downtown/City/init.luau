--!strict
-- DOWNTOWN B CITY (Lane 3 preview, ledger D-02 D-04..D-06 D-08..D-12 D-17 D-20). Entry module.
-- Full notes: README.md in this folder. Private look-development harness: never mapped by
-- default.project.json; it runs only in Roblox Studio (edit mode or a playtest client).
--
-- Command bar (Studio edit mode, Downtown look-dev place):
--   local City = require(game.ReplicatedStorage.LookDev.Downtown.City)
--   City.run({ seed = 2207, length = 2400 })  -- plan + build + print + start the chase
--   City.build({ seed = 2207 })               -- plan + build (camera at s 0, no chase)
--   City.plan({ seed = 2207 })                -- plan only, prints the sequence and checks
--   City.chase({ camera = "HIGH", speed = 70 })   City.stop()  City.pause()  City.resume()
--   City.camera("FIXTURE" | "HIGH")   City.frame(1200)   City.sample(20)
--   City.widthStudy()   City.stats()   City.describe()   City.boundaries()
--   City.reset()  or  City.reset({ lighting = true })   -- also restores the place's lighting
-- Module functions use one default city under Workspace.Lane3_DowntownCity and need the
-- playground marker (ReplicatedStorage.Lane3Playground, Kind "downtown") unless the options
-- say preview = true.
--
-- Embedding (e.g. the HUD playground's backdrop, client in Play):
--   local city = City.new({ parent = folder, kit = ReplicatedStorage.Lane3_DowntownKitB2,
--                           seed = 2207, preview = true })
--   city:build()            -- yields while kit templates are made; then builds around s 0
--   city:chase()            -- or drive it yourself: city:setStation(s) every frame
--   city:stats()  city:destroy()

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Assembler = require(script.Assembler)
local Catalog = require(script.Catalog)
local Chase = require(script.Chase)
local RoadWidthStudy = require(script.RoadWidthStudy)
local Sequencer = require(script.Sequencer)
local StreetLife = require(script.StreetLife)
local Traffic = require(script.Traffic)

local City = {}
local CityClass = {}
CityClass.__index = CityClass

City.Sequencer = Sequencer
City.Catalog = Catalog
City.Assembler = Assembler
City.Chase = Chase
City.RoadWidthStudy = RoadWidthStudy

export type Options = {
	seed: number?, -- default 2207
	length: number?, -- minimum route length, studs (default 2400)
	laneWidth: number?, -- default 17 (PREVIEW)
	completeDistrict: boolean?, -- default true
	parent: Instance?, -- default Workspace
	name: string?, -- city folder name (default Lane3_DowntownCity)
	kit: Instance?,
	kitData: Instance?,
	textureId: string?,
	paletteColumn: string?,
	meshIds: { [string]: string }?,
	behind: number?, -- segments kept behind (default 1)
	ahead: number?, -- segments built ahead (default 6)
	budget: number?,
	maxEditableMeshes: number?,
	lighting: boolean?, -- default true
	labels: boolean?,
	useKit: boolean?,
	traffic: boolean?, -- default true
	trafficCount: number?,
	streetLife: boolean?, -- default true
	camera: string?, -- chase camera: "FIXTURE" | "HIGH"
	speed: number?, -- chase speed, studs/s (default 70)
	lane: number?, -- chase lane (default 2)
	chaseLabel: boolean?, -- default true
	controlCamera: boolean?, -- default true
	preview: boolean?, -- the caller's explicit opt-in (gate)
}

type Fields = {
	options: Options,
	plan: Sequencer.Plan,
	catalog: Catalog.Catalog,
	assembler: Assembler.Assembler,
	parent: Instance,
	chaseRig: Chase.Chase?,
	traffic: Traffic.Traffic?,
	life: StreetLife.StreetLife?,
	built: boolean,
	destroyed: boolean,
}

export type City = typeof(setmetatable({} :: Fields, CityClass))

local function marker(): Instance?
	return ReplicatedStorage:FindFirstChild("Lane3Playground")
end

local function gate(options: Options, requireDowntown: boolean)
	assert(RunService:IsStudio(), "the Downtown city preview runs only in Roblox Studio")
	if options.preview == true then
		return
	end
	local m = marker()
	if requireDowntown then
		assert(
			m and m:GetAttribute("Kind") == "downtown",
			"needs the Downtown playground marker (ReplicatedStorage.Lane3Playground, Kind = downtown) or preview = true"
		)
	else
		assert(m ~= nil, "needs a Lane 3 playground marker (ReplicatedStorage.Lane3Playground) or preview = true")
	end
end

-- Plans a city and prepares its assembler (no instances placed yet besides the empty folders).
function City.new(options: Options?): City
	local opts = options or {}
	gate(opts, false)
	local catalog = Catalog.load({ kit = opts.kit, kitData = opts.kitData })
	local plan = Sequencer.plan(opts.seed or Sequencer.DEFAULT_SEED, {
		length = opts.length,
		laneWidth = opts.laneWidth,
		completeDistrict = opts.completeDistrict,
		catalog = catalog,
	})
	local parent = opts.parent or Workspace
	local assembler = Assembler.new(plan, {
		parent = parent,
		name = opts.name,
		kit = opts.kit,
		kitData = opts.kitData,
		textureId = opts.textureId,
		paletteColumn = opts.paletteColumn,
		meshIds = opts.meshIds,
		behind = opts.behind,
		ahead = opts.ahead,
		budget = opts.budget,
		maxEditableMeshes = opts.maxEditableMeshes,
		lighting = opts.lighting,
		labels = opts.labels,
		useKit = opts.useKit,
	})
	local self: Fields = {
		options = opts,
		plan = plan,
		catalog = catalog,
		assembler = assembler,
		parent = parent,
		chaseRig = nil,
		traffic = nil,
		life = nil,
		built = false,
		destroyed = false,
	}
	return setmetatable(self, CityClass)
end

-- Makes the kit templates (yields), builds the window around `station` (default 0) and starts
-- the street life and proxy traffic. Returns the assembler stats.
function CityClass.build(self: City, station: number?): Assembler.Stats
	local s = station or 0
	self.assembler:prepare()
	self.assembler:buildAt(s)
	local root = self.assembler.root
	local function getStation(): number
		return self.assembler:getStation()
	end
	if self.options.streetLife ~= false and not self.life then
		local life = StreetLife.new({
			parent = root,
			plan = self.plan,
			getStation = getStation,
			getFocus = function(): { Vector3 }
				local points = {}
				local camera = Workspace.CurrentCamera
				if camera then
					table.insert(points, camera.CFrame.Position)
				end
				local rig = self.chaseRig
				if rig then
					table.insert(points, rig:carPosition())
				end
				return points
			end,
		})
		life:start()
		self.life = life
	end
	if self.options.traffic ~= false and not self.traffic then
		local traffic = Traffic.new({
			parent = root,
			plan = self.plan,
			getStation = getStation,
			count = self.options.trafficCount,
			chaseLane = self.options.lane or Chase.DEFAULT_LANE,
		})
		traffic:start()
		self.traffic = traffic
	end
	self.built = true
	return self.assembler:getStats()
end

-- Moves the active window (for a caller driving its own camera).
function CityClass.setStation(self: City, s: number)
	self.assembler:setStation(s)
end

function CityClass.rig(self: City): Chase.Chase
	local rig = self.chaseRig
	if rig then
		return rig
	end
	local new = Chase.new({
		plan = self.plan,
		parent = self.assembler.root,
		setStation = function(s: number)
			self.assembler:setStation(s)
		end,
		speed = self.options.speed,
		lane = self.options.lane,
		camera = self.options.camera,
		label = self.options.chaseLabel,
		controlCamera = self.options.controlCamera,
	})
	self.chaseRig = new
	return new
end

-- Starts the chase (async). options: { seconds?, from?, camera?, speed? }.
function CityClass.chase(self: City, options: { seconds: number?, from: number?, camera: string?, speed: number? }?)
	if not self.built then
		self:build()
	end
	local rig = self:rig()
	local opts = options or {}
	if opts.camera then
		rig:setCamera(opts.camera)
	end
	if opts.speed then
		rig.speed = opts.speed
	end
	rig:run({ seconds = opts.seconds, from = opts.from, async = true })
end

function CityClass.sample(self: City, seconds: number?): { [string]: any }
	if not self.built then
		self:build()
	end
	local result = self:rig():sample(seconds)
	return { frames = result, city = self:stats() }
end

function CityClass.frame(self: City, s: number)
	if not self.built then
		self:build(s)
	end
	local rig = self:rig()
	rig:stop()
	self.assembler:buildAt(s)
	rig:place(s)
end

function CityClass.stats(self: City): { [string]: any }
	return {
		assembler = self.assembler:getStats(),
		chase = if self.chaseRig then self.chaseRig:stats() else nil,
		traffic = if self.traffic then self.traffic:stats() else nil,
		streetLife = if self.life then self.life:stats() else nil,
		checksPassed = self.plan.checks.passed,
	}
end

function CityClass.describe(self: City): string
	return Sequencer.describe(self.plan)
end

function CityClass.boundaries(self: City): { { [string]: any } }
	return Sequencer.boundaries(self.plan)
end

function CityClass.destroy(self: City)
	if self.destroyed then
		return
	end
	self.destroyed = true
	if self.chaseRig then
		self.chaseRig:destroy()
		self.chaseRig = nil
	end
	if self.traffic then
		self.traffic:destroy()
		self.traffic = nil
	end
	if self.life then
		self.life:destroy()
		self.life = nil
	end
	self.assembler:destroy()
end

-- Command-bar API (one default city) -------------------------------------------------------

local default: City? = nil
local lastOptions: Options = {}

local function report(verb: string, value: any)
	local ok, json = pcall(function()
		return HttpService:JSONEncode(value)
	end)
	print("[Lane3City] " .. verb .. " " .. (if ok then json else tostring(value)))
end

local function merged(options: Options?): Options
	local out: Options = table.clone(lastOptions)
	for k, v in (options or {}) :: any do
		(out :: any)[k] = v
	end
	return out
end

-- Removes the default city, the width study and leftovers of earlier module copies (by name).
function City.reset(options: { lighting: boolean? }?)
	if default then
		default:destroy()
		default = nil
	end
	for _, name in { Assembler.ROOT_NAME, RoadWidthStudy.FOLDER } do
		local leftover = Workspace:FindFirstChild(name)
		if leftover then
			leftover:Destroy()
		end
	end
	if options and options.lighting then
		Assembler.restoreLighting()
	end
	-- the chase rig puts the camera back when it is destroyed (above)
	report("reset", "ok")
end

function City.plan(options: Options?): Sequencer.Plan
	local opts = merged(options)
	gate(opts, true)
	local plan = Sequencer.plan(opts.seed or Sequencer.DEFAULT_SEED, {
		length = opts.length,
		laneWidth = opts.laneWidth,
		completeDistrict = opts.completeDistrict,
		catalog = Catalog.load({ kit = opts.kit, kitData = opts.kitData }),
	})
	print(Sequencer.describe(plan))
	return plan
end

function City.build(options: Options?): Assembler.Stats
	local opts = merged(options)
	gate(opts, true)
	opts.preview = true -- the marker gate above already passed
	lastOptions = opts
	if default then
		default:destroy()
		default = nil
	end
	local city = City.new(opts)
	default = city
	local stats = city:build(0)
	city:rig() -- car and camera at s 0
	report("build", stats)
	return stats
end

function City.run(options: Options?): { [string]: any }
	local stats = City.build(options)
	local city = default :: City
	print(city:describe())
	city:chase()
	report("run", "chase started")
	return { seed = city.plan.seed, length = city.plan.length, checksPassed = city.plan.checks.passed, stats = stats }
end

local function current(): City
	if not default then
		City.build(nil)
	end
	return default :: City
end

function City.chase(options: { seconds: number?, from: number?, camera: string?, speed: number? }?)
	current():chase(options)
	report("chase", "started")
end

function City.stop()
	if default and default.chaseRig then
		default.chaseRig:stop()
	end
end

function City.pause()
	if default and default.chaseRig then
		default.chaseRig:pause()
	end
end

function City.resume()
	if default and default.chaseRig then
		default.chaseRig:resume()
	end
end

function City.camera(name: string)
	current():rig():setCamera(name)
end

function City.frame(s: number)
	current():frame(s)
end

function City.sample(seconds: number?): { [string]: any }
	local result = current():sample(seconds)
	report("sample", result)
	return result
end

function City.stats(): { [string]: any }?
	if not default then
		report("stats", "no city built")
		return nil
	end
	local stats = default:stats()
	report("stats", stats)
	return stats
end

function City.describe(): string
	local text = current():describe()
	print(text)
	return text
end

function City.boundaries(): { { [string]: any } }
	local table_ = current():boundaries()
	report("boundaries", table_)
	return table_
end

function City.widthStudy(options: RoadWidthStudy.Options?): RoadWidthStudy.Result
	gate(lastOptions, true)
	local result = RoadWidthStudy.build(options)
	RoadWidthStudy.view(options and options.origin)
	return result
end

function City.restoreLighting()
	Assembler.restoreLighting()
end

return City
