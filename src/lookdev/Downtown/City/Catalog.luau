--!strict
-- Downtown B kit CATALOGUE (Lane 3 preview). Typed tables of districts, palettes, road pieces,
-- lot modules, landmarks, props and the fictional sign family, built from the kit contract in
-- vault/design/specs/hud-rebuild-downtown-b.md ("Downtown kit contract").
--
-- Catalog.builtIn() is pure data: the sequencer can plan a route with no kit at all, and every
-- module it names is drawn as a labelled proxy until a mesh of that name exists.
-- Catalog.load(options) starts from builtIn() and merges the B2 kit when it is present:
--   kit      a Folder of mesh data, one child per mesh named B2_<family>_<variant> (a JSON
--            ModuleScript as Rojo maps it, or a StringValue holding the JSON)
--   kitData  a Folder holding `manifest` (array of { name, bounds, triangles, meta }) and
--            optionally `swatches`
-- Defaults: ServerStorage.Lane3_DowntownKitB2 / Lane3_DowntownKitB2Data in edit mode,
-- ReplicatedStorage.<same names> in Play (the client cannot see ServerStorage).
-- Lots and landmarks named in the manifest or the kit folder are added (or override the
-- built-in entry of the same name); meta.width / depth / height / heightClass / orientation /
-- mirror_of / district / lod / sockets / facing are read when present, otherwise parsed from the
-- name (B2_Lot_<Type><Width>[L|R]_<finish>, e.g. B2_Lot_Shop24_brick, B2_Lot_Corner24L_stone).
-- All numbers are studs. Heights, palettes and district lengths are PREVIEW values.

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local Catalog = {}

Catalog.KIT_FOLDER = "Lane3_DowntownKitB2"
Catalog.DATA_FOLDER = "Lane3_DowntownKitB2Data"

export type HeightClass = "low" | "mid" | "tall"
export type Orientation = "front" | "corner-L" | "corner-R"
export type LotKind = "building" | "courtyard" | "park" | "corner"

export type Palette = {
	id: string,
	wall: Color3,
	trim: Color3,
	accent: Color3,
	roof: Color3,
}

export type District = {
	id: string,
	name: string,
	order: number,
	target: number, -- fixture length in studs (explicit, not equal spans)
	palettes: { Palette },
	heights: { low: number, mid: number, tall: number }, -- bag weights
	finishes: { string },
	intersections: number,
	curves: number,
	bridge: boolean,
	signature: string, -- landmark id used for the district tile
	landmarks: { string }, -- landmark ids allowed in this district
	furniture: { string }, -- prop kinds (weighted by repetition)
	treatmentEvery: { number }, -- min, max lots between courtyards / pocket parks
	parkBias: number, -- 0..1 chance a treatment is a pocket park rather than a courtyard
	midHeight: { number }, -- midground mass height range
	skyHeight: { number }, -- skyline block height range
	signs: boolean, -- shop signs in this district
	bunting: boolean,
}

export type LotModule = {
	name: string,
	type: string, -- Shop, Mid, Tall, Corner, Court, Park
	kind: LotKind,
	width: number,
	depth: number,
	height: number,
	heightClass: HeightClass,
	orientation: Orientation,
	mirrorOf: string?,
	finish: string,
	districts: { string },
	shop: boolean,
	lod: string,
	sockets: { [string]: CFrame },
	facing: string, -- which mesh axis the facade faces ("-Z" by default)
	fromKit: boolean,
}

export type Landmark = {
	id: string,
	name: string, -- mesh name
	label: string, -- original fictional name shown on the proxy
	width: number,
	depth: number,
	height: number,
	districts: { string },
	placement: "frontage" | "skyline" | "bridge",
	fromKit: boolean,
}

export type Catalog = {
	source: string,
	districts: { District },
	districtById: { [string]: District },
	lots: { LotModule },
	lotByName: { [string]: LotModule },
	landmarks: { Landmark },
	landmarkById: { [string]: Landmark },
	props: { [string]: string }, -- prop kind -> mesh name
	signs: { string },
	kitNames: { [string]: boolean },
	kitCount: number,
	manifestCount: number,
	notes: { string },
}

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

local function palette(id: string, wall: Color3, trim: Color3, accent: Color3, roof: Color3): Palette
	return { id = id, wall = wall, trim = trim, accent = accent, roof = roof }
end

local CREAM = rgb(244, 234, 212)
local NAVY = rgb(48, 64, 104)

-- District order is the fixture order (repeating). Targets are 480..720 and deliberately unequal.
local function districts(): { District }
	return {
		{
			id = "MainStreet",
			name = "Main Street",
			order = 1,
			target = 528,
			palettes = {
				palette("MS-brick", rgb(176, 86, 66), CREAM, rgb(40, 150, 150), rgb(92, 70, 64)),
				palette("MS-cream", rgb(236, 222, 194), rgb(122, 76, 56), rgb(214, 160, 52), rgb(110, 92, 80)),
				palette("MS-mustard", rgb(214, 170, 86), CREAM, NAVY, rgb(96, 84, 76)),
				palette("MS-teal", rgb(96, 152, 146), CREAM, rgb(200, 88, 82), rgb(80, 92, 96)),
			},
			heights = { low = 6, mid = 4, tall = 0 },
			finishes = { "brick", "cream" },
			intersections = 1,
			curves = 1,
			bridge = false,
			signature = "Theater",
			landmarks = { "Theater", "DonutBakery", "CarWash" },
			furniture = { "planter", "bench", "bin", "hydrant", "bikeRack", "planter" },
			treatmentEvery = { 7, 10 },
			parkBias = 0.5,
			midHeight = { 36, 60 },
			skyHeight = { 90, 170 },
			signs = true,
			bunting = true,
		},
		{
			id = "CityHall",
			name = "City Hall",
			order = 2,
			target = 576,
			palettes = {
				palette("CH-stone", rgb(214, 206, 188), rgb(150, 140, 124), rgb(46, 96, 140), rgb(120, 116, 110)),
				palette("CH-sand", rgb(224, 198, 152), CREAM, rgb(46, 110, 92), rgb(122, 108, 92)),
				palette("CH-slate", rgb(156, 166, 180), CREAM, rgb(170, 60, 64), rgb(92, 98, 110)),
				palette("CH-redbrick", rgb(160, 96, 80), rgb(226, 214, 192), rgb(46, 96, 140), rgb(96, 76, 70)),
			},
			heights = { low = 3, mid = 7, tall = 0 },
			finishes = { "stone", "terracotta" },
			intersections = 1,
			curves = 1,
			bridge = false,
			signature = "CityHall",
			landmarks = { "CityHall", "DonutBakery" },
			furniture = { "tree", "tree", "bench", "bin", "tree", "planter" },
			treatmentEvery = { 5, 8 },
			parkBias = 0.4,
			midHeight = { 40, 64 },
			skyHeight = { 100, 180 },
			signs = true,
			bunting = true,
		},
		{
			id = "HarborBridge",
			name = "Harbor Bridge",
			order = 3,
			target = 528,
			palettes = {
				palette("HB-harborred", rgb(168, 72, 62), rgb(232, 226, 214), rgb(52, 120, 150), rgb(84, 74, 72)),
				palette("HB-weatherteal", rgb(76, 132, 140), rgb(232, 226, 214), rgb(220, 180, 70), rgb(70, 84, 92)),
				palette("HB-plank", rgb(232, 226, 212), rgb(64, 84, 112), rgb(178, 74, 64), rgb(110, 104, 98)),
				palette("HB-navy", rgb(58, 74, 106), CREAM, rgb(220, 180, 70), rgb(70, 76, 90)),
			},
			heights = { low = 7, mid = 3, tall = 0 },
			finishes = { "brick", "plank" },
			intersections = 0,
			curves = 0,
			bridge = true,
			signature = "HarborBridge",
			landmarks = { "HarborBridge", "DeliveryDepot", "ServiceCanopy" },
			furniture = { "bench", "bin", "planter", "bench" },
			treatmentEvery = { 6, 9 },
			parkBias = 0.6,
			midHeight = { 30, 50 },
			skyHeight = { 90, 160 },
			signs = true,
			bunting = false,
		},
		{
			id = "Midtown",
			name = "Midtown",
			order = 4,
			target = 624,
			palettes = {
				palette("MT-glass", rgb(124, 164, 198), rgb(226, 232, 238), rgb(40, 150, 150), rgb(96, 104, 116)),
				palette("MT-limestone", rgb(222, 216, 202), rgb(120, 126, 136), rgb(46, 96, 160), rgb(110, 112, 116)),
				palette("MT-terracotta", rgb(196, 122, 92), CREAM, rgb(46, 96, 160), rgb(104, 88, 80)),
				palette("MT-charcoal", rgb(96, 102, 116), rgb(226, 232, 238), rgb(230, 186, 70), rgb(70, 74, 84)),
			},
			heights = { low = 1, mid = 4, tall = 5 },
			finishes = { "glass", "stone", "terracotta" },
			intersections = 2,
			curves = 1,
			bridge = false,
			signature = "Stadium",
			landmarks = { "Stadium", "ServiceCanopy", "CarWash", "DeliveryDepot" },
			furniture = { "planter", "bin", "hydrant", "bikeRack", "bench" },
			treatmentEvery = { 8, 12 },
			parkBias = 0.3,
			midHeight = { 70, 130 },
			skyHeight = { 160, 260 },
			signs = true,
			bunting = false,
		},
		{
			id = "SkylinePark",
			name = "Skyline Park",
			order = 5,
			target = 672,
			palettes = {
				palette("SP-parkgreen", rgb(110, 160, 108), CREAM, rgb(220, 120, 100), rgb(84, 104, 84)),
				palette("SP-cream", rgb(240, 230, 204), rgb(90, 130, 96), rgb(70, 140, 200), rgb(116, 108, 96)),
				palette("SP-sky", rgb(134, 182, 214), CREAM, rgb(220, 120, 100), rgb(88, 104, 120)),
				palette("SP-coral", rgb(226, 132, 112), CREAM, rgb(70, 140, 200), rgb(110, 90, 86)),
			},
			heights = { low = 4, mid = 4, tall = 2 },
			finishes = { "cream", "terracotta" },
			intersections = 1,
			curves = 2,
			bridge = false,
			signature = "Fountain",
			landmarks = { "Fountain", "DonutBakery" },
			furniture = { "tree", "tree", "bench", "tree", "bin" },
			treatmentEvery = { 4, 6 },
			parkBias = 0.75,
			midHeight = { 50, 110 },
			skyHeight = { 150, 240 },
			signs = true,
			bunting = true,
		},
	}
end

-- Which finishes each district may use (finish = the material family baked into a lot mesh).
-- the B2 kit's meta.district codes
local KIT_DISTRICTS: { [string]: { string } } = {
	MS = { "MainStreet" },
	CH = { "CityHall" },
	HB = { "HarborBridge" },
	MT = { "Midtown" },
	SP = { "SkylinePark" },
	any = { "MainStreet", "CityHall", "HarborBridge", "Midtown", "SkylinePark" },
}

local FINISH_DISTRICTS: { [string]: { string } } = {
	brick = { "MainStreet", "HarborBridge" },
	cream = { "MainStreet", "SkylinePark" },
	stone = { "CityHall", "Midtown" },
	glass = { "Midtown" },
	plank = { "HarborBridge" },
	terracotta = { "CityHall", "Midtown", "SkylinePark" },
	green = { "MainStreet", "CityHall", "HarborBridge", "Midtown", "SkylinePark" },
}

type TypeRow = {
	type: string,
	kind: LotKind,
	widths: { number },
	heights: { [number]: number },
	heightClass: HeightClass,
	shop: boolean,
	finishes: { string },
	corner: boolean?,
}

local TYPES: { TypeRow } = {
	{
		type = "Shop",
		kind = "building",
		widths = { 24, 36, 48 },
		heights = { [24] = 28, [36] = 30, [48] = 32 },
		heightClass = "low",
		shop = true,
		finishes = { "brick", "cream", "plank", "terracotta" },
	},
	{
		type = "Mid",
		kind = "building",
		widths = { 24, 36 },
		heights = { [24] = 40, [36] = 52 },
		heightClass = "mid",
		shop = true,
		finishes = { "brick", "cream", "stone", "terracotta", "plank" },
	},
	{
		type = "Tall",
		kind = "building",
		widths = { 36, 48 },
		heights = { [36] = 64, [48] = 88 },
		heightClass = "tall",
		shop = false,
		finishes = { "glass", "stone", "terracotta" },
	},
	{
		type = "Corner",
		kind = "corner",
		widths = { 24 },
		heights = { [24] = 40 },
		heightClass = "mid",
		shop = true,
		finishes = { "brick", "cream", "stone", "terracotta", "plank", "glass" },
		corner = true,
	},
	{
		type = "Court",
		kind = "courtyard",
		widths = { 36 },
		heights = { [36] = 40 },
		heightClass = "mid",
		shop = false,
		finishes = { "stone", "terracotta", "cream" },
	},
	{
		type = "Park",
		kind = "park",
		widths = { 24, 36 },
		heights = { [24] = 0, [36] = 0 },
		heightClass = "low",
		shop = false,
		finishes = { "green" },
	},
}

local LANDMARKS: { Landmark } = {
	{
		id = "Theater",
		name = "B2_LM_Theater",
		label = "REEL WHEELS",
		width = 48,
		depth = 24,
		height = 36,
		districts = { "MainStreet" },
		placement = "frontage",
		fromKit = false,
	},
	{
		id = "CityHall",
		name = "B2_LM_CityHall",
		label = "CITY HALL",
		width = 72,
		depth = 36,
		height = 100,
		districts = { "CityHall" },
		placement = "frontage",
		fromKit = false,
	},
	{
		id = "HarborBridge",
		name = "B2_LM_BridgeArch192_L4W17",
		label = "HARBOR BRIDGE",
		width = 384,
		depth = 0,
		height = 60,
		districts = { "HarborBridge" },
		placement = "bridge",
		fromKit = false,
	},
	{
		id = "Fountain",
		name = "B2_LM_Fountain",
		label = "SKYLINE PARK",
		width = 48,
		depth = 30,
		height = 12,
		districts = { "SkylinePark" },
		placement = "frontage",
		fromKit = false,
	},
	{
		id = "Stadium",
		name = "B2_Sky_Stadium",
		label = "STADIUM",
		width = 220,
		depth = 220,
		height = 48,
		districts = { "Midtown" },
		placement = "skyline",
		fromKit = false,
	},
	{
		id = "CarWash",
		name = "B2_LM_CarWash",
		label = "SUDSY SUDS CAR WASH",
		width = 48,
		depth = 24,
		height = 18,
		districts = { "MainStreet", "Midtown" },
		placement = "frontage",
		fromKit = false,
	},
	{
		id = "ServiceCanopy",
		name = "B2_LM_ServiceCanopy",
		label = "PIT STOP SERVICE",
		width = 48,
		depth = 24,
		height = 18,
		districts = { "Midtown", "HarborBridge" },
		placement = "frontage",
		fromKit = false,
	},
	{
		id = "DonutBakery",
		name = "B2_LM_DonutBakery",
		label = "HOLE IN ONE DONUTS",
		width = 36,
		depth = 22,
		height = 34,
		districts = { "MainStreet", "CityHall", "SkylinePark" },
		placement = "frontage",
		fromKit = false,
	},
	{
		id = "DeliveryDepot",
		name = "B2_LM_DeliveryDepot",
		label = "DELIVERY DEPOT",
		width = 48,
		depth = 24,
		height = 22,
		districts = { "HarborBridge", "Midtown" },
		placement = "frontage",
		fromKit = false,
	},
}

local PROPS: { [string]: string } = {
	-- the B2 kit's street furniture names (assets/downtown/kit-b/README.md)
	lamp = "B2_Street_Lamp",
	bridgeLamp = "B2_Street_LampFormal",
	tree = "B2_Street_Tree",
	bench = "B2_Street_Bench",
	bin = "B2_Street_Bin",
	hydrant = "B2_Street_Hydrant",
	bikeRack = "B2_Street_BikeRack",
	planter = "B2_Street_Planter",
	busStop = "B2_Street_BusStop",
}

-- Small fictional sign family (§16): the three named in the brief plus originals. No real logos.
local SIGNS: { string } = {
	"WHEEL GOOD PIZZA",
	"BRAKE-FAST DINER",
	"LUG NUTS HARDWARE",
	"TIRE-D BOOKS",
	"SPARK PLUG CAFE",
	"GEAR UP GYM",
	"HUBCAP HATS",
	"MUFFLER MUFFINS",
	"PISTON PETS",
	"TOOT TOOT TOYS",
	"DASHBOARD DAISIES",
	"CRUISE CONTROL ICE CREAM",
}

-- Road piece mesh names (contract example: B2_Road_Straight96_L4W17).
function Catalog.roadName(kind: string, length: number, lanes: number, laneWidth: number): string
	local lane = "L" .. tostring(lanes) .. "W" .. string.gsub(tostring(laneWidth), "%.", "p")
	if kind == "CurveL" or kind == "CurveR" then
		return "B2_Road_" .. kind .. "_" .. lane
	end
	-- the kit's names: BridgeDeck192, TransitionVerge96
	local short = if kind == "Transition" then "TransitionVerge" else kind
	return "B2_Road_" .. short .. tostring(math.floor(length + 0.5)) .. "_" .. lane
end

local function sockets(raw: any): { [string]: CFrame }
	local out: { [string]: CFrame } = {}
	if type(raw) ~= "table" then
		return out
	end
	for name, v in raw do
		if type(name) == "string" and type(v) == "table" then
			local x = tonumber(v.x or v[1]) or 0
			local y = tonumber(v.y or v[2]) or 0
			local z = tonumber(v.z or v[3]) or 0
			local yaw = tonumber(v.yaw or v[4]) or 0
			out[name] = CFrame.new(x, y, z) * CFrame.Angles(0, math.rad(yaw), 0)
		end
	end
	return out
end

local function districtsOf(raw: any, finish: string): { string }
	if type(raw) == "string" then
		local code = KIT_DISTRICTS[raw]
		if code then
			return table.clone(code)
		end
		return { raw }
	end
	if type(raw) == "table" then
		local list = {}
		for _, v in raw do
			if type(v) == "string" then
				table.insert(list, v)
			end
		end
		if #list > 0 then
			return list
		end
	end
	return table.clone(FINISH_DISTRICTS[finish] or { "MainStreet" })
end

local function lotModule(
	name: string,
	row: TypeRow,
	width: number,
	finish: string,
	orientation: Orientation,
	mirrorOf: string?
): LotModule
	return {
		name = name,
		type = row.type,
		kind = row.kind,
		width = width,
		depth = if row.kind == "park" then 24 else (if width >= 48 then 24 else 22),
		height = row.heights[width] or 32,
		heightClass = row.heightClass,
		orientation = orientation,
		mirrorOf = mirrorOf,
		finish = finish,
		districts = table.clone(FINISH_DISTRICTS[finish] or { "MainStreet" }),
		shop = row.shop,
		lod = "near",
		sockets = {},
		facing = "-Z",
		fromKit = false,
	}
end

local function index(cat: Catalog)
	cat.districtById = {}
	for _, d in cat.districts do
		cat.districtById[d.id] = d
	end
	cat.lotByName = {}
	for _, l in cat.lots do
		cat.lotByName[l.name] = l
	end
	cat.landmarkById = {}
	for _, lm in cat.landmarks do
		cat.landmarkById[lm.id] = lm
	end
end

-- The built-in catalogue (pure data; no instances read).
function Catalog.builtIn(): Catalog
	local lots: { LotModule } = {}
	for _, row in TYPES do
		for _, finish in row.finishes do
			for _, width in row.widths do
				if row.corner then
					local l = "B2_Lot_" .. row.type .. width .. "L_" .. finish
					local r = "B2_Lot_" .. row.type .. width .. "R_" .. finish
					table.insert(lots, lotModule(l, row, width, finish, "corner-L", nil))
					table.insert(lots, lotModule(r, row, width, finish, "corner-R", l))
				else
					table.insert(
						lots,
						lotModule("B2_Lot_" .. row.type .. width .. "_" .. finish, row, width, finish, "front")
					)
				end
			end
		end
	end
	local landmarks = {}
	for _, lm in LANDMARKS do
		local copy = table.clone(lm)
		copy.districts = table.clone(lm.districts)
		table.insert(landmarks, copy)
	end
	local cat: Catalog = {
		source = "built-in fallback",
		districts = districts(),
		districtById = {},
		lots = lots,
		lotByName = {},
		landmarks = landmarks,
		landmarkById = {},
		props = table.clone(PROPS),
		signs = table.clone(SIGNS),
		kitNames = {},
		kitCount = 0,
		manifestCount = 0,
		notes = {},
	}
	index(cat)
	return cat
end

-- Reads JSON data from a ModuleScript (Rojo JSON module) or a StringValue. In edit mode a module
-- is required from a fresh clone so a re-exported file is not served from the module cache.
function Catalog.readData(source: Instance?): (any, string?)
	if not source then
		return nil, "missing"
	end
	if source:IsA("StringValue") then
		local ok, value = pcall(function()
			return HttpService:JSONDecode(source.Value)
		end)
		if ok then
			return value, nil
		end
		return nil, "bad JSON: " .. tostring(value)
	end
	if source:IsA("ModuleScript") then
		local ok, value = pcall(function()
			local target = if RunService:IsRunning() then source else source:Clone()
			return (require :: any)(target)
		end)
		if ok then
			return value, nil
		end
		return nil, "could not load: " .. tostring(value)
	end
	return nil, "not a ModuleScript or StringValue"
end

-- The default kit and data folders for the current mode (or nil).
function Catalog.defaultFolders(): (Instance?, Instance?)
	local first: Instance = if RunService:IsRunning() then ReplicatedStorage else ServerStorage
	local second: Instance = if RunService:IsRunning() then ServerStorage else ReplicatedStorage
	local kit = first:FindFirstChild(Catalog.KIT_FOLDER) or second:FindFirstChild(Catalog.KIT_FOLDER)
	local data = first:FindFirstChild(Catalog.DATA_FOLDER) or second:FindFirstChild(Catalog.DATA_FOLDER)
	return kit, data
end

local TYPE_ROW: { [string]: TypeRow } = {}
for _, row in TYPES do
	TYPE_ROW[row.type] = row
end

local function mergeLot(cat: Catalog, name: string, meta: { [string]: any }?, bounds: any)
	local typeName, widthText, lr, finish = string.match(name, "^B2_Lot_(%a-)(%d+)([LR]?)_(.+)$")
	-- the B2 kit: B2_Lot_<Type><Width><Height?>_<variant>, with type, width, height class,
	-- orientation and district in meta (e.g. B2_Lot_Shop24Low_a, B2_Lot_Corner24Mid_L, B2_Lot_Park48)
	local m0 = meta or {}
	if type(m0.module) == "string" then
		local moduleName = m0.module :: string
		local hc = m0.height_class
		typeName = if moduleName == "corner"
			then "Corner"
			elseif moduleName == "tall" then "Tall"
			elseif moduleName == "park" then "Park"
			elseif moduleName == "plaza" or moduleName == "pocket" then "Court"
			elseif hc == "low" then "Shop"
			else "Mid"
		widthText = tostring(m0.width or string.match(name, "(%d+)") or 24)
		lr = if m0.orientation == "corner-L" then "L" elseif m0.orientation == "corner-R" then "R" else ""
		finish = tostring(m0.colourway or string.match(name, "_(%w+)$") or "a")
		if moduleName ~= "shop" and moduleName ~= "corner" then
			m0.shop = false
		end
	end
	if not typeName then
		typeName, widthText, lr, finish = string.match(name, "^B2_Lot_(%a-)(%d+)([LR]?)$")
		finish = finish or "plain"
	end
	if not (typeName and widthText) then
		table.insert(cat.notes, "lot name not understood (kept as a kit mesh only): " .. name)
		return
	end
	local m = meta or {}
	local row = TYPE_ROW[typeName :: string] or TYPE_ROW.Shop
	local width = tonumber(m.width) or tonumber(widthText) or 24
	local orientation: Orientation = "front"
	local mo = m.orientation
	if mo == "corner-L" or mo == "corner-R" or mo == "front" then
		orientation = mo
	elseif lr == "L" then
		orientation = "corner-L"
	elseif lr == "R" then
		orientation = "corner-R"
	end
	local f = finish :: string
	local lot = lotModule(name, row, width, f, orientation, if type(m.mirror_of) == "string" then m.mirror_of else nil)
	if orientation ~= "front" and row.kind ~= "corner" then
		lot.kind = "corner"
	end
	local depth = tonumber(m.depth)
	local height = tonumber(m.height)
	if type(bounds) == "table" and type(bounds[1]) == "table" and type(bounds[2]) == "table" then
		height = height or ((tonumber(bounds[2][2]) or 0) - (tonumber(bounds[1][2]) or 0))
	end
	lot.depth = math.min(depth or lot.depth, 24)
	lot.height = height or lot.height
	local hc = m.heightClass or m.height_class
	if hc == "low" or hc == "mid" or hc == "tall" then
		lot.heightClass = hc
	end
	lot.districts = districtsOf(m.district or m.districts, f)
	lot.lod = if type(m.lod) == "string" then m.lod else "near"
	lot.sockets = sockets(m.sockets)
	lot.facing = if type(m.facing) == "string" then m.facing else "-Z"
	lot.shop = if type(m.shop) == "boolean" then m.shop else lot.shop
	lot.fromKit = true
	local existing = cat.lotByName[name]
	if existing then
		for i, l in cat.lots do
			if l == existing then
				cat.lots[i] = lot
			end
		end
	else
		table.insert(cat.lots, lot)
	end
	cat.lotByName[name] = lot
end

local function mergeLandmark(cat: Catalog, name: string, meta: { [string]: any }?)
	local id = string.match(name, "^B2_LM_(.+)$")
	if not id then
		return
	end
	-- kit parts that are not frontage landmarks of their own: the bridge arches (placed by the
	-- built-in HarborBridge entry) and the car wash brush / roller rigs
	if string.find(id, "^BridgeArch") or string.find(id, "Brush$") or string.find(id, "Roller$") then
		return
	end
	local m = meta or {}
	local existing = cat.landmarkById[id]
	if existing then
		existing.name = name
		existing.width = tonumber(m.width) or existing.width
		existing.depth = tonumber(m.depth) or existing.depth
		existing.height = tonumber(m.height) or existing.height
		existing.fromKit = true
		return
	end
	local lm: Landmark = {
		id = id,
		name = name,
		label = if type(m.label) == "string" then m.label else string.upper(id),
		width = tonumber(m.width) or 48,
		depth = tonumber(m.depth) or 24,
		height = tonumber(m.height) or 30,
		districts = districtsOf(m.district or m.districts, "green"),
		placement = if m.placement == "skyline" then "skyline" else "frontage",
		fromKit = true,
	}
	table.insert(cat.landmarks, lm)
	cat.landmarkById[id] = lm
	for _, d in cat.districts do
		if table.find(lm.districts, d.id) and not table.find(d.landmarks, id) then
			table.insert(d.landmarks, id)
		end
	end
end

export type LoadOptions = { kit: Instance?, kitData: Instance? }

-- builtIn() plus whatever B2 kit exists. Deterministic for a given kit.
function Catalog.load(options: LoadOptions?): Catalog
	local cat = Catalog.builtIn()
	local defaultKit, defaultData = Catalog.defaultFolders()
	local kit = (options and options.kit) or defaultKit
	local data = (options and options.kitData) or defaultData
	local names: { string } = {}
	if kit then
		for _, child in kit:GetChildren() do
			if child:IsA("ModuleScript") or child:IsA("StringValue") then
				cat.kitNames[child.Name] = true
				cat.kitCount += 1
				table.insert(names, child.Name)
			end
		end
	end
	local metaByName: { [string]: { meta: any, bounds: any } } = {}
	local manifest = data and data:FindFirstChild("manifest")
	if manifest then
		local value, err = Catalog.readData(manifest)
		local list = if type(value) == "table" and type(value.meshes) == "table" then value.meshes else value
		if type(list) == "table" then
			for _, entry in list do
				if type(entry) == "table" and type(entry.name) == "string" then
					metaByName[entry.name] = {
						meta = if type(entry.meta) == "table" then entry.meta else {},
						bounds = entry.bounds,
					}
					cat.manifestCount += 1
					if not table.find(names, entry.name) then
						table.insert(names, entry.name)
					end
				end
			end
		elseif err then
			table.insert(cat.notes, "manifest not read: " .. err)
		end
	end
	table.sort(names) -- deterministic merge order
	for _, name in names do
		local info = metaByName[name]
		-- the B2 manifest keeps fields at the top level and has no module / width / height class;
		-- the mesh file's own meta has them, so lots and landmarks read it from the kit folder
		local isLot = string.sub(name, 1, 7) == "B2_Lot_"
		if (isLot or string.sub(name, 1, 6) == "B2_LM_") and kit then
			local file = kit:FindFirstChild(name)
			if file then
				local value = Catalog.readData(file)
				if type(value) == "table" and type(value.meta) == "table" then
					info = { meta = value.meta, bounds = value.bounds or (info and info.bounds) }
				end
			end
		end
		if string.sub(name, 1, 7) == "B2_Lot_" then
			mergeLot(cat, name, info and info.meta, info and info.bounds)
		elseif string.sub(name, 1, 6) == "B2_LM_" then
			mergeLandmark(cat, name, info and info.meta)
		end
	end
	-- kit-first: when the kit supplies lots, the built-in placeholder lots are not used (they
	-- have no meshes and would only ever show as proxies)
	local kitLots = 0
	for _, l in cat.lots do
		if l.fromKit then
			kitLots += 1
		end
	end
	if kitLots > 0 then
		for i = #cat.lots, 1, -1 do
			if not cat.lots[i].fromKit then
				cat.lotByName[cat.lots[i].name] = nil
				table.remove(cat.lots, i)
			end
		end
	end
	if cat.kitCount > 0 or cat.manifestCount > 0 then
		cat.source = string.format(
			"built-in + B2 kit (%d meshes in folder, %d manifest entries)",
			cat.kitCount,
			cat.manifestCount
		)
	end
	return cat
end

return Catalog
