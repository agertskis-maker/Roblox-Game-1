--!strict
-- Downtown B city ASSEMBLER (Lane 3 preview). Instantiates a Sequencer Plan with a bounded
-- ACTIVE WINDOW: only segments in [current - behind, current + ahead] are built (skyline masses
-- use a wider window, ground tiles a 3 x 3 cell set around the camera and the road ahead).
-- Everything leaving the window goes back to a pool keyed by module and is reused, so a long
-- chase never accumulates instances.
--
-- Runs in Studio edit mode AND on the client in a Studio playtest (no edit-mode assert); the
-- caller decides where it lives:
--   Assembler.new(plan, {
--     parent = folder,          -- where the city folder is created (default Workspace)
--     kit = folder,             -- mesh data: ModuleScripts (Rojo JSON) or StringValues of JSON,
--                               -- named B2_<family>_<variant> (default Catalog.defaultFolders())
--     kitData = folder,         -- manifest / swatches (optional)
--     lighting = true,          -- apply the B daylight once (same values as Builder's study)
--     world = def,              -- a Worlds/<id> definition (Dusty Highway, Summit Pass): its light, ground, mass and
--                               -- hazard meshes and the floor under a bridge landmark (nil = Downtown)
--     extraKits = { folder },   -- more mesh folders searched after `kit` (a World's own kit)
--     labels = nil,             -- proxy labels (default: on in edit mode, off in Play)
--   })
-- then :prepare() (yields: makes one template MeshPart per kit mesh the plan uses, through
-- KitMesh / EditableMesh), :setStation(s) every frame, :getStats(), :destroy().
-- A kit mesh that is missing, over the EditableMesh limits (20k triangles / 60k vertices) or
-- refused by the memory budget (CreateEditableMesh returning nil) becomes a labelled proxy.
-- EditableMesh content is session-only and is never saved or uploaded.

local Lighting = game:GetService("Lighting")
local AssetService = game:GetService("AssetService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local Catalog = require(script.Parent.Catalog)
local KitMesh = require(script.Parent.Parent.KitMesh)
local Merge = require(script.Parent.Merge)
local Proxies = require(script.Parent.Proxies)
local Route = require(script.Parent.Route)
local Sequencer = require(script.Parent.Sequencer)

local Assembler = {}
Assembler.__index = Assembler

Assembler.ROOT_NAME = "Lane3_DowntownCity"
Assembler.DEFAULT_BEHIND = 1
Assembler.DEFAULT_AHEAD = 6
Assembler.DEFAULT_SKY_BEHIND = 2
Assembler.DEFAULT_SKY_AHEAD = 14
Assembler.DEFAULT_BUDGET = 300 -- items placed per setStation call during a chase
Assembler.MAX_EDITABLE = 160
Assembler.EDITABLE_TRIANGLES = 20000
Assembler.EDITABLE_VERTICES = 60000
-- a playtest client here holds only 8 EditableMeshes (measured 2026-10-23), so Play merges each
-- live segment's kit pieces into one mesh (City/Merge.luau); edit mode keeps one per piece
Assembler.MERGE_MAX_MESHES = 8
Assembler.MERGE_AHEAD = 5

local GROUND_CELL = 2000
local GROUND_COLOUR = Color3.fromRGB(150, 146, 134) -- darker paving: the pale tone read as white in Studio
local WATER_COLOUR = Color3.fromRGB(46, 132, 190) -- harbour water under the bridge deck
local WATER_ACROSS = 240 -- studs across the route: the deck, its frontage and a margin, not the skyline
local WATER_Y = -0.25 -- centre; the ground tiles top out at -0.3

-- kit meshes for the midground and skyline masses (were plain blocks: "no crude boxes", §13),
-- picked deterministically per district and scaled to each planned mass
local MID_MESHES: { [string]: { string } } = {
	-- Round 2: taller, layered middle distance (blocks with wedding-cake and tank tops, a long slab); the pick below
	-- takes the entry nearest the planned height so no block is stretched far
	MainStreet = {
		"B2_Mid_Block36_1",
		"B2_Mid_Block36_2",
		"B2_Mid_Block36_3",
		"B2_Mid_Block36_4",
		"B2_Mid_Block36_5",
		"B2_Mid_Block48_1",
	},
	CityHall = {
		"B2_Mid_CivicDome",
		"B2_Mid_Block36_2",
		"B2_Mid_Block36_3",
		"B2_Mid_Block36_4",
		"B2_Mid_Block48_1",
	},
	HarborBridge = { "B2_Mid_Warehouse48", "B2_Mid_Block36_1" },
	Midtown = {
		"B2_Mid_Glass40",
		"B2_Mid_Tower40_4",
		"B2_Mid_Block36_3",
		"B2_Mid_Block40_6",
		"B2_Mid_Block36_5",
		"B2_Mid_Block48_1",
	},
	SkylinePark = {
		"B2_Mid_TreeClump",
		"B2_Mid_Block36_1",
		"B2_Mid_Block36_4",
		"B2_Mid_Block36_5",
		"B2_Mid_Block36_3",
	},
}
local SKY_MESHES: { string } = {
	"B2_Sky_Slab_1",
	"B2_Sky_Slab_2",
	"B2_Sky_Slab_3",
	"B2_Sky_Stepped_1",
	"B2_Sky_Stepped_2",
	"B2_Sky_Stepped_3",
	"B2_Sky_Tower_1",
	"B2_Sky_Tower_2",
	"B2_Sky_Tower_3",
	"B2_Sky_Spire",
	-- Round 2 skyline: stepped wedding-cake towers, crowns, roof water tanks and plant rooms, broadcast needles
	"B2_Sky_Wedding_1",
	"B2_Sky_Wedding_2",
	"B2_Sky_Wedding_3",
	"B2_Sky_Crown_1",
	"B2_Sky_Crown_2",
	"B2_Sky_Crown_3",
	"B2_Sky_Tank_1",
	"B2_Sky_Tank_2",
	"B2_Sky_Tank_3",
	"B2_Sky_Needle_1",
	"B2_Sky_Needle_2",
	"B2_Sky_Needle_3",
}
-- kit meshes for the scenery hazards (construction keeps its barrier-and-cone proxy group)
local HAZARD_MESHES: { [string]: string } = {
	pothole = "B2_Haz_Pothole",
	oil = "B2_Haz_Oil",
}

-- (world = a Worlds definition or nil for Downtown) deterministic per station, as before
local function massList(world: any?, m: Sequencer.MassPlan): { string }
	if world then
		return if m.band == "skyline" then world.skyMeshes else (world.midMeshes[m.district] or world.skyMeshes)
	end
	return if m.band == "skyline" then SKY_MESHES else (MID_MESHES[m.district] or MID_MESHES.MainStreet)
end

local function massIndex(m: Sequencer.MassPlan): number
	return math.floor(m.station / 11 + 0.5) + (if m.side > 0 then 3 else 0)
end

local function hazardMeshesOf(world: any?): { [string]: string }
	return if world then world.hazardMeshes else HAZARD_MESHES
end
local HALF_TURN = CFrame.Angles(0, math.pi, 0)
local FACING_YAW: { [string]: number } = { ["-Z"] = 0, ["+X"] = 90, ["-X"] = -90, ["+Z"] = 180 }

export type Options = {
	parent: Instance?,
	name: string?,
	kit: Instance?,
	kitData: Instance?,
	textureId: string?, -- an uploaded palette texture ("rbxassetid://...") for kit meshes
	paletteColumn: string?, -- swatches column for vertex colours (default "B2", then "B")
	meshIds: { [string]: string }?, -- uploaded mesh ids by name (used before EditableMesh)
	behind: number?,
	ahead: number?,
	skyBehind: number?,
	skyAhead: number?,
	budget: number?,
	maxEditableMeshes: number?,
	merge: boolean?, -- default: true in a running playtest, false in edit mode
	lighting: boolean?,
	labels: boolean?,
	useKit: boolean?,
	ground: boolean?,
	world: any?, -- Worlds.WorldDef (typed any: Worlds requires Catalog, not this module)
	extraKits: { Instance }?,
}

export type Stats = {
	mode: string,
	seed: number,
	routeLength: number,
	station: number,
	windowFrom: number,
	windowTo: number,
	behind: number,
	ahead: number,
	segmentsLive: number,
	skySegmentsLive: number,
	liveItems: number,
	liveMeshInstances: number,
	liveProxyItems: number,
	pooledItems: number,
	createdItems: number,
	reusedItems: number,
	releasedItems: number,
	trianglesPlaced: number,
	uniqueMeshes: number,
	uniqueTriangles: number,
	editableMeshes: number,
	merged: { meshes: number, parts: number, triangles: number, pending: number, failures: { string } },
	estimatedEditableMB: number,
	uploadedMeshes: number,
	missingMeshes: number,
	missingNames: { string },
	socketMismatches: { string },
	liveParts: number,
	groundTiles: number,
	lighting: string,
	kit: string,
	buildPasses: number,
}

type Template = {
	part: MeshPart?,
	triangles: number,
	lo: Vector3,
	hi: Vector3,
	turn: CFrame,
	facing: string,
	meta: { [string]: any },
	source: string,
	editable: EditableMesh?,
	data: KitMesh.Data?, -- merge mode: the mesh data (no per-piece template part)
}

type Spec = {
	key: string,
	kind: string,
	tris: number,
	mesh: boolean,
	make: () -> Instance,
	place: (Instance) -> (),
	merge: { data: KitMesh.Data, cframe: () -> CFrame, scale: Vector3? }?, -- merge mode: appended, not instanced
}

type Item = { key: string, inst: Instance, kind: string, tris: number, mesh: boolean }
type Live = {
	items: { Item },
	specs: { Spec },
	nextSpec: number,
	mergeItems: { Merge.Item }?,
	mergeJob: Merge.Job?,
}

type Bucket = {
	lots: { Sequencer.LotPlan },
	landmarks: { Sequencer.LandmarkPlan },
	props: { Sequencer.PropPlan },
	spans: { Sequencer.SpanPlan },
	hazards: { Sequencer.HazardPlan },
	mid: { Sequencer.MassPlan },
	sky: { Sequencer.MassPlan },
	skyLandmarks: { Sequencer.LandmarkPlan },
	extrasNear: { Sequencer.Extra }, -- World build V2: WorldPlan's backdrop, gorge, ground, edge and prop pieces
	extrasFar: { Sequencer.Extra }, -- the same, in the skyline window
}

type Fields = {
	plan: Sequencer.Plan,
	root: Folder,
	folders: { [string]: Folder },
	poolFolder: Folder,
	pool: { [string]: { Instance } },
	templates: { [string]: Template },
	kit: Instance?,
	extraKits: { Instance },
	world: any?,
	groundColour: Color3,
	kitData: Instance?,
	textureId: string,
	swatches: { Color3 }?,
	swatchMode: string,
	meshIds: { [string]: string },
	labels: boolean,
	useKit: boolean,
	ground: boolean,
	behind: number,
	ahead: number,
	skyBehind: number,
	skyAhead: number,
	budget: number,
	maxEditable: number,
	merge: boolean,
	mergeFailures: { string },
	buckets: { [number]: Bucket },
	specCache: { [number]: { Spec } },
	skySpecCache: { [number]: { Spec } },
	live: { [number]: Live },
	skyLive: { [number]: Live },
	groundLive: { [string]: Item },
	station: number,
	windowFrom: number,
	windowTo: number,
	created: number,
	reused: number,
	released: number,
	passes: number,
	lightingNote: string,
	socketMismatches: { string },
	destroyed: boolean,
	geometry: Proxies.Geometry,
}

export type Assembler = typeof(setmetatable({} :: Fields, Assembler))

local function modeName(): string
	if not RunService:IsRunning() then
		return "studio-edit"
	end
	return if RunService:IsClient() then "play-client" else "play-server"
end

-- Lighting: the B daylight of Builder's study, applied once per Assembler (never changed
-- between passes). Same attribute keys as Builder, so Builder.restoreLighting() also undoes it.
local LIGHT: { [string]: any } = {
	ClockTime = 13.5,
	Brightness = 2.2,
	Ambient = Color3.fromRGB(96, 100, 112),
	OutdoorAmbient = Color3.fromRGB(140, 142, 152),
	EnvironmentDiffuseScale = 1,
	EnvironmentSpecularScale = 0.6,
	ExposureCompensation = 0,
	GlobalShadows = true,
	ShadowSoftness = 0.2,
	GeographicLatitude = 41.7,
	ColorShift_Top = Color3.fromRGB(255, 248, 236),
	ColorShift_Bottom = Color3.new(0, 0, 0),
}
local ORIGINAL = "Lane3LookDevOriginal_"
local OURS = "Lane3LookDev"
local STASH = "Lane3_DowntownLightingStash"

local function stashParent(): Instance
	if RunService:IsRunning() and RunService:IsClient() then
		return ReplicatedStorage -- client-local; the server never sees it
	end
	return ServerStorage
end

function Assembler.applyLighting(preset: any?): string
	local props: { [string]: any } = if preset then preset.props else LIGHT
	for prop, value in props do
		local key = ORIGINAL .. prop
		if Lighting:GetAttribute(key) == nil then
			Lighting:SetAttribute(key, (Lighting :: any)[prop])
		end
		(Lighting :: any)[prop] = value
	end
	local parent = stashParent()
	local stash = parent:FindFirstChild(STASH)
	for _, child in Lighting:GetChildren() do
		if (child:IsA("Atmosphere") or child:IsA("ColorCorrectionEffect")) and child:GetAttribute(OURS) ~= true then
			if not stash then
				local folder = Instance.new("Folder")
				folder.Name = STASH
				folder.Parent = parent
				stash = folder
			end
			child.Parent = stash
		elseif child:GetAttribute(OURS) == true then
			child:Destroy()
		end
	end
	local sky = if preset then preset.atmosphere else nil
	local atmosphere = Instance.new("Atmosphere")
	atmosphere.Name = "Lane3LookDev_Atmosphere"
	atmosphere.Density = if sky then sky.density else 0.3
	atmosphere.Offset = if sky then sky.offset else 0.12
	atmosphere.Color = if sky then sky.colour else Color3.fromRGB(205, 224, 238)
	atmosphere.Decay = if sky then sky.decay else Color3.fromRGB(120, 150, 180)
	atmosphere.Glare = 0
	atmosphere.Haze = if sky then sky.haze else 1.4
	atmosphere:SetAttribute(OURS, true)
	atmosphere.Parent = Lighting
	local look = if preset then preset.grade else nil
	local grade = Instance.new("ColorCorrectionEffect")
	grade.Name = "Lane3LookDev_ColorCorrection"
	grade.Brightness = if look then look.brightness else 0.02
	grade.Contrast = if look then look.contrast else 0.06
	grade.Saturation = if look then look.saturation else 0.08
	grade.TintColor = if look then look.tint else Color3.fromRGB(255, 252, 246)
	grade:SetAttribute(OURS, true)
	grade.Parent = Lighting
	if preset and sky and look then
		return string.format(
			"World daylight: ClockTime %.1f, Brightness %.1f, Atmosphere d%.2f/o%.2f/h%.1f, ColorCorrection c%.2f/s%.2f",
			props.ClockTime,
			props.Brightness,
			sky.density,
			sky.offset,
			sky.haze,
			look.contrast,
			look.saturation
		)
	end
	return "B daylight: ClockTime 13.5, Brightness 2.2, Atmosphere d0.3/o0.12/h1.4, ColorCorrection c0.06/s0.08"
end

-- Puts back the Lighting values and effects saved by applyLighting (or by Builder).
function Assembler.restoreLighting()
	for prop in LIGHT do
		local key = ORIGINAL .. prop
		local value = Lighting:GetAttribute(key)
		if value ~= nil then
			(Lighting :: any)[prop] = value
			Lighting:SetAttribute(key, nil)
		end
	end
	for _, child in Lighting:GetChildren() do
		if child:GetAttribute(OURS) == true then
			child:Destroy()
		end
	end
	local stash = stashParent():FindFirstChild(STASH)
	if stash then
		for _, child in stash:GetChildren() do
			child.Parent = Lighting
		end
		stash:Destroy()
	end
end

-- Kit data ------------------------------------------------------------------------------------

local function vec(value: any): Vector3?
	if typeof(value) == "Vector3" then
		return value
	end
	if type(value) == "table" and type(value[1]) == "number" and type(value[2]) == "number" then
		return Vector3.new(value[1], value[2], (value[3] :: number?) or 0)
	end
	return nil
end

local function loadSwatches(data: Instance?, column: string?): ({ Color3 }?, string)
	local module = data and data:FindFirstChild("swatches")
	if not module then
		return nil, "none (no swatches in kit data)"
	end
	local value, err = Catalog.readData(module)
	if type(value) ~= "table" then
		return nil, "none (swatches not read: " .. tostring(err) .. ")"
	end
	if type(value.colors) == "table" then
		local out = {}
		for i, c in value.colors do
			if type(c) == "table" then
				out[i] = Color3.fromRGB(c[1] or 255, c[2] or 0, c[3] or 255)
			end
		end
		return out, "vertex colours (swatch module colors)"
	end
	local rows = if type(value.swatches) == "table" then value.swatches else value
	local keys = { column or "B2", "B", "rgb", "colour", "color" }
	for _, key in keys do
		local out = {}
		local found = false
		for _, row in rows do
			if type(row) == "table" and type(row.index) == "number" and type(row[key]) == "table" then
				local c = row[key]
				out[row.index + 1] = Color3.fromRGB(c[1], c[2], c[3])
				found = true
			end
		end
		if found then
			return out, "vertex colours (swatches column " .. key .. ")"
		end
	end
	return nil, "none (no usable swatch column)"
end

local function loadMesh(kit: Instance?, name: string): (KitMesh.Data?, string?)
	local source = kit and kit:FindFirstChild(name)
	if not source then
		return nil, "not in kit"
	end
	local value, err = Catalog.readData(source)
	if
		type(value) ~= "table"
		or type(value.p) ~= "table"
		or type(value.t) ~= "table"
		or type(value.bounds) ~= "table"
		or type(value.grid) ~= "number"
	then
		return nil, err or "not kit mesh data"
	end
	value.meta = if type(value.meta) == "table" then value.meta else {}
	value.triangles = if type(value.triangles) == "number" then value.triangles else #value.t // 4
	value.name = name
	return value :: KitMesh.Data, nil
end

local function finishPart(part: MeshPart, name: string)
	part.Name = name
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = true
	part.Material = Enum.Material.SmoothPlastic
	part.Color = Color3.new(1, 1, 1)
end

-- Construction --------------------------------------------------------------------------------

function Assembler.new(plan: Sequencer.Plan, options: Options?): Assembler
	assert(RunService:IsStudio(), "the Downtown city preview runs only in Roblox Studio")
	local opts = options or {}
	local parent = opts.parent or Workspace
	local name = opts.name or Assembler.ROOT_NAME
	local old = parent:FindFirstChild(name)
	if old then
		old:Destroy() -- a second build never leaves duplicates
	end
	local root = Instance.new("Folder")
	root.Name = name
	root:SetAttribute("Note", "Lane 3 Downtown B city preview (deterministic plan). Not game content.")
	root:SetAttribute("Seed", plan.seed)
	root:SetAttribute("RouteLength", plan.length)
	root:SetAttribute("World", if opts.world then opts.world.id else "Downtown")
	local folders: { [string]: Folder } = {}
	for _, n in { "Road", "Lots", "Landmarks", "Signs", "Props", "Spans", "Hazards", "Masses", "Ground" } do
		local f = Instance.new("Folder")
		f.Name = n
		f.Parent = root
		folders[n] = f
	end
	root.Parent = parent
	local poolFolder = Instance.new("Folder")
	poolFolder.Name = "Lane3_CityPool" -- parented to nothing: pooled items never render

	local defaultKit, defaultData = Catalog.defaultFolders()
	local kit = opts.kit or defaultKit
	local kitData = opts.kitData or defaultData
	local swatches, swatchMode = loadSwatches(kitData, opts.paletteColumn)
	local textureId = opts.textureId or ""
	if string.match(textureId, "^%d+$") then
		textureId = "rbxassetid://" .. textureId
	end

	local self: Fields = {
		plan = plan,
		root = root,
		folders = folders,
		poolFolder = poolFolder,
		pool = {},
		templates = {},
		kit = kit,
		extraKits = opts.extraKits or {},
		world = opts.world,
		groundColour = if opts.world then opts.world.ground else GROUND_COLOUR,
		kitData = kitData,
		textureId = textureId,
		swatches = swatches,
		swatchMode = if textureId ~= "" then "texture " .. textureId else swatchMode,
		meshIds = opts.meshIds or {},
		labels = if opts.labels == nil then not RunService:IsRunning() else opts.labels,
		useKit = opts.useKit ~= false,
		ground = opts.ground ~= false,
		behind = opts.behind or Assembler.DEFAULT_BEHIND,
		ahead = opts.ahead or (if (if opts.merge == nil then RunService:IsRunning() else opts.merge)
			then Assembler.MERGE_AHEAD
			else Assembler.DEFAULT_AHEAD),
		skyBehind = opts.skyBehind or Assembler.DEFAULT_SKY_BEHIND,
		skyAhead = opts.skyAhead or Assembler.DEFAULT_SKY_AHEAD,
		budget = opts.budget or Assembler.DEFAULT_BUDGET,
		maxEditable = opts.maxEditableMeshes or Assembler.MAX_EDITABLE,
		merge = if opts.merge == nil then RunService:IsRunning() else opts.merge,
		mergeFailures = {},
		buckets = {},
		specCache = {},
		skySpecCache = {},
		live = {},
		skyLive = {},
		groundLive = {},
		station = 0,
		windowFrom = 0,
		windowTo = 0,
		created = 0,
		reused = 0,
		released = 0,
		passes = 0,
		lightingNote = "unchanged (lighting = false)",
		socketMismatches = {},
		destroyed = false,
		geometry = {
			lanes = plan.lanes,
			laneWidth = plan.laneWidth,
			shoulder = plan.shoulder,
			halfRoad = plan.halfRoad,
			kerb = plan.kerb,
			sidewalk = plan.sidewalk,
		},
	}
	local obj = setmetatable(self, Assembler)
	if opts.lighting ~= false then
		self.lightingNote = Assembler.applyLighting(if opts.world then opts.world.lighting else nil)
	end
	-- plan items by segment
	for i = 1, #plan.segments do
		self.buckets[i] = {
			lots = {},
			landmarks = {},
			props = {},
			spans = {},
			hazards = {},
			mid = {},
			sky = {},
			skyLandmarks = {},
			extrasNear = {},
			extrasFar = {},
		}
	end
	local function bucket(i: number): Bucket
		return self.buckets[math.clamp(i, 1, #plan.segments)]
	end
	for _, lot in plan.lots do
		table.insert(bucket(lot.segment).lots, lot)
	end
	for _, lm in plan.landmarks do
		if lm.placement == "skyline" then
			table.insert(bucket(lm.segment).skyLandmarks, lm)
		else
			table.insert(bucket(lm.segment).landmarks, lm)
		end
	end
	for _, p in plan.props do
		table.insert(bucket(p.segment).props, p)
	end
	for _, sp in plan.spans do
		table.insert(bucket(sp.segment).spans, sp)
	end
	for _, h in plan.hazards do
		table.insert(bucket(h.segment).hazards, h)
	end
	for _, m in plan.masses do
		table.insert(if m.band == "skyline" then bucket(m.segment).sky else bucket(m.segment).mid, m)
	end
	for _, e in plan.extras do
		table.insert(if e.band == "far" then bucket(e.segment).extrasFar else bucket(e.segment).extrasNear, e)
	end
	root:SetAttribute("Kit", if kit then kit:GetFullName() else "none (proxies only)")
	return obj
end

-- Templates (yields) ------------------------------------------------------------------------

function Assembler.prepare(self: Assembler)
	if not self.useKit then
		return
	end
	local names: { string } = {}
	local seen: { [string]: boolean } = {}
	local function want(n: string)
		if n ~= "" and n ~= "GAP" and not seen[n] then
			seen[n] = true
			table.insert(names, n)
		end
	end
	for _, seg in self.plan.segments do
		want(seg.mesh)
	end
	for _, lot in self.plan.lots do
		want(lot.module)
	end
	for _, lm in self.plan.landmarks do
		want(lm.module)
	end
	for _, p in self.plan.props do
		want(p.module)
	end
	for _, m in self.plan.masses do
		for _, name in massList(self.world, m) do
			want(name) -- the whole list: a midground mass picks the entry nearest its height (see chooseMass)
		end
	end
	for _, name in hazardMeshesOf(self.world) do
		want(name)
	end
	for _, e in self.plan.extras do
		want(e.module)
	end
	table.sort(names)
	local editableCount = 0
	for _, t in self.templates do
		if t.editable then
			editableCount += 1
		end
	end
	for index, name in names do
		if not self.templates[name] then
			local data, reason = loadMesh(self.kit, name)
			if not data then
				for _, extra in self.extraKits do
					data, reason = loadMesh(extra, name)
					if data then
						break
					end
				end
			end
			local template: Template = {
				part = nil,
				triangles = 0,
				lo = Vector3.zero,
				hi = Vector3.one,
				turn = CFrame.identity,
				facing = "-Z",
				meta = {},
				source = "missing: " .. tostring(reason),
				editable = nil,
			}
			if data then
				template.lo = vec(data.bounds[1]) or Vector3.zero
				template.hi = vec(data.bounds[2]) or Vector3.one
				template.triangles = data.triangles
				template.meta = data.meta
				template.facing = if type(data.meta.facing) == "string" then data.meta.facing else "-Z"
			end
			local uploaded = self.meshIds[name]
			if uploaded then
				local ok, part = pcall(function()
					return AssetService:CreateMeshPartAsync(Content.fromUri(uploaded), {
						CollisionFidelity = Enum.CollisionFidelity.Box,
						RenderFidelity = Enum.RenderFidelity.Automatic,
					})
				end)
				if ok and data then
					finishPart(part, name)
					part.TextureID = self.textureId
					template.part = part
					template.turn = HALF_TURN -- uploaded kit meshes arrive turned 180 degrees about Y
					template.source = "uploaded"
				elseif not ok then
					template.source = "missing: uploaded mesh failed: " .. tostring(part)
				else
					-- placement needs the mesh JSON's bounds and meta; without them use a proxy
					part:Destroy()
					template.source = "missing: uploaded id given but no mesh JSON (bounds) in the kit"
				end
			end
			if not template.part and data and self.merge then
				template.data = data
				template.source = "merge (one EditableMesh per live segment)"
			elseif not template.part and data then
				local vertices = #data.p // 3
				if data.triangles > Assembler.EDITABLE_TRIANGLES or vertices > Assembler.EDITABLE_VERTICES then
					template.source = string.format(
						"missing: over EditableMesh limits (%d triangles, %d vertices)",
						data.triangles,
						vertices
					)
				elseif editableCount >= self.maxEditable then
					template.source = "missing: maxEditableMeshes (" .. self.maxEditable .. ") reached"
				else
					-- KitMesh asserts when CreateEditableMesh returns nil (memory budget): pcall it
					local ok, part, em = pcall(KitMesh.previewPart, data, self.textureId, self.swatches)
					if ok and part then
						finishPart(part, name)
						template.part = part
						template.editable = em
						template.source = "preview (EditableMesh)"
						editableCount += 1
					else
						template.source = "missing: EditableMesh unavailable: " .. tostring(part)
					end
				end
			end
			-- road pieces: compare the mesh's end socket with the contract geometry
			if template.part and string.sub(name, 1, 8) == "B2_Road_" then
				local sockets = template.meta.sockets
				local e = type(sockets) == "table" and (sockets["end"] or sockets.endSocket or sockets.End)
				if type(e) == "table" then
					for _, seg in self.plan.segments do
						if seg.mesh == name then
							local expected = Route.localFrame(seg.bend, seg.radius, seg.length, 0, 0).Position
							local got = Vector3.new(
								tonumber(e.x or e[1]) or 0,
								tonumber(e.y or e[2]) or 0,
								tonumber(e.z or e[3]) or 0
							)
							if (expected - got).Magnitude > 0.5 then
								table.insert(
									self.socketMismatches,
									string.format(
										"%s end socket %s, contract %s",
										name,
										tostring(got),
										tostring(expected)
									)
								)
							end
							break
						end
					end
				end
			end
			self.templates[name] = template
			if index % 10 == 0 then
				task.wait()
			end
		end
	end
end

local function template(self: Assembler, name: string): Template?
	local t = self.templates[name]
	if t and (t.part or t.data) then
		return t
	end
	return nil
end

-- Where a lot / landmark mesh sits in its lot frame: centred in the slot, front face on z = 0.
local function fit(t: Template, width: number): CFrame
	local yaw = FACING_YAW[t.facing] or 0
	local ext = t.hi - t.lo
	local depth = if math.abs(yaw) == 90 then ext.X else ext.Z
	return CFrame.new(width / 2, (t.lo.Y + t.hi.Y) / 2, depth / 2) * CFrame.Angles(0, math.rad(yaw), 0) * t.turn
end

local function centreOffset(t: Template): CFrame
	return CFrame.new((t.lo + t.hi) / 2) * t.turn
end

local function look(self: Assembler, paletteId: string): Proxies.Look
	local p = self.plan.palettes[paletteId]
	if p then
		return { wall = p.wall, trim = p.trim, accent = p.accent, roof = p.roof }
	end
	return {
		wall = Color3.fromRGB(200, 196, 186),
		trim = Color3.fromRGB(240, 234, 220),
		accent = Color3.fromRGB(40, 150, 150),
		roof = Color3.fromRGB(110, 108, 104),
	}
end

local function pivotTo(inst: Instance, cf: CFrame)
	if inst:IsA("Model") then
		inst:PivotTo(cf)
	elseif inst:IsA("BasePart") then
		inst.CFrame = cf
	end
end

-- Specs ----------------------------------------------------------------------------------------

local function meshOrProxy(
	self: Assembler,
	name: string,
	kind: string,
	proxyKey: string,
	makeProxy: () -> Instance,
	meshCFrame: (Template) -> CFrame,
	proxyCFrame: CFrame,
	noMerge: boolean?
): Spec
	local t = template(self, name)
	if t and not t.part and t.data and not noMerge then
		local data = t.data :: KitMesh.Data
		return {
			key = "merge:" .. name,
			kind = kind,
			tris = t.triangles,
			mesh = true,
			make = makeProxy,
			place = function() end,
			merge = {
				data = data,
				cframe = function(): CFrame
					return meshCFrame(t)
				end,
			},
		}
	end
	if t and t.part then
		local part = t.part :: MeshPart
		return {
			key = "mesh:" .. name,
			kind = kind,
			tris = t.triangles,
			mesh = true,
			make = function()
				return part:Clone()
			end,
			place = function(inst: Instance)
				(inst :: BasePart).CFrame = meshCFrame(t)
			end,
		}
	end
	return {
		key = proxyKey,
		kind = kind,
		tris = 0,
		mesh = false,
		make = makeProxy,
		place = function(inst: Instance)
			pivotTo(inst, proxyCFrame)
		end,
	}
end

-- A planned mass as a scaled kit mesh (edit: a sized MeshPart; play: merged into the segment),
-- or the old plain block when the kit mesh is missing.
-- A midground mass takes, in the deterministic rotation order, the first list entry whose authored height is within
-- 25% of the planned height (else the nearest), so the taller middle distance is chosen rather than stretched. Skyline
-- shapes are unit meshes scaled on purpose, so they keep the plain rotation.
local function chooseMass(self: Assembler, m: Sequencer.MassPlan): string
	local list = massList(self.world, m)
	local k = massIndex(m)
	local first = list[k % #list + 1]
	if m.band == "skyline" then
		return first
	end
	local best, bestRatio = first, math.huge
	for i = 0, #list - 1 do
		local name = list[(k + i) % #list + 1]
		local t = self.templates[name]
		if t and (t.part or t.data) then
			local h = math.max(t.hi.Y - t.lo.Y, 0.1)
			local ratio = math.max(m.size.Y / h, h / m.size.Y)
			if ratio <= 1.25 then
				return name
			end
			if ratio < bestRatio then
				best, bestRatio = name, ratio
			end
		end
	end
	return best
end

local function massSpec(self: Assembler, m: Sequencer.MassPlan, label: string, allowMerge: boolean): Spec
	local name = chooseMass(self, m)
	local t = template(self, name)
	if t then
		local ext = t.hi - t.lo
		local scale = Vector3.new(
			m.size.X / math.max(ext.X, 0.1),
			m.size.Y / math.max(ext.Y, 0.1),
			m.size.Z / math.max(ext.Z, 0.1)
		)
		if t.data and not t.part and allowMerge then
			return {
				key = "merge:" .. name,
				kind = "Masses",
				tris = t.triangles,
				mesh = true,
				make = function()
					return Proxies.block(label)
				end,
				place = function() end,
				merge = {
					data = t.data :: KitMesh.Data,
					cframe = function(): CFrame
						return m.cframe
					end,
					scale = scale,
				},
			}
		end
		if t.part then
			local part = t.part :: MeshPart
			return {
				key = "mesh:" .. name,
				kind = "Masses",
				tris = t.triangles,
				mesh = true,
				make = function()
					return part:Clone()
				end,
				place = function(inst: Instance)
					local p = inst :: MeshPart
					p.Size = m.size
					p.CastShadow = false
					p.CFrame = m.cframe * t.turn
				end,
			}
		end
	end
	return {
		key = "mass",
		kind = "Masses",
		tris = 0,
		mesh = false,
		make = function()
			return Proxies.block(label)
		end,
		place = function(inst: Instance)
			local part = inst :: BasePart
			part.Name = label
			part.Size = m.size
			part.Color = m.colour
			part.CastShadow = false
			part.CFrame = m.cframe
		end,
	}
end

-- World build V2: the folder an extra's instance goes into
local EXTRA_FOLDER: { [string]: string } = {
	ground = "Ground",
	edge = "Props",
	berm = "Props",
	fence = "Props",
	fol = "Props",
	garland = "Props",
	sign = "Signs",
}

-- A WorldPlan extra as a kit mesh at its authored size (uniform scale only; never stretched). The kit meshes are drawn
-- about their bounds centre (KitMesh, Merge), so the part sits at the pivot frame offset by the scaled centre. Edit: one
-- sized MeshPart; Play: merged into the segment. A mesh that is missing is a labelled block of the planned size.
local function extraSpec(self: Assembler, e: Sequencer.Extra, allowMerge: boolean): Spec
	local kind = EXTRA_FOLDER[e.kind] or "Masses"
	-- a wayfinding board with words on it is a part-built board (the same route the shop signs take), never merged
	if e.text then
		local text = e.text :: string
		local width, height = e.size.X, e.size.Y
		return {
			key = string.format("board:%d:%d", math.floor(width + 0.5), math.floor(height + 0.5)),
			kind = "Signs",
			tris = 0,
			mesh = false,
			make = function()
				return Proxies.board(width, height)
			end,
			place = function(inst: Instance)
				Proxies.setText(inst, text)
				if inst:IsA("Model") then
					inst:PivotTo(e.cframe)
				end
			end,
		}
	end
	local t = template(self, e.module)
	local s = e.scale
	if t then
		local ext = t.hi - t.lo
		local at = e.cframe * CFrame.new((t.lo + t.hi) / 2 * s)
		if t.data and not t.part and allowMerge then
			return {
				key = "merge:" .. e.module,
				kind = kind,
				tris = t.triangles,
				mesh = true,
				make = function()
					return Proxies.block(e.label)
				end,
				place = function() end,
				merge = {
					data = t.data :: KitMesh.Data,
					cframe = function(): CFrame
						return at
					end,
					scale = Vector3.one * s,
				},
			}
		end
		if t.part then
			local part = t.part :: MeshPart
			return {
				key = "mesh:" .. e.module,
				kind = kind,
				tris = t.triangles,
				mesh = true,
				make = function()
					return part:Clone()
				end,
				place = function(inst: Instance)
					local p = inst :: MeshPart
					p.Size = ext * s
					p.CastShadow = false
					p.CFrame = at * t.turn
				end,
			}
		end
	end
	return {
		key = "extra:" .. e.kind,
		kind = kind,
		tris = 0,
		mesh = false,
		make = function()
			return Proxies.block(e.label)
		end,
		place = function(inst: Instance)
			local part = inst :: BasePart
			part.Name = e.label
			part.Size = e.size
			part.Color = e.colour
			part.CastShadow = false
			part.CFrame = e.cframe * CFrame.new(0, e.size.Y / 2, 0)
		end,
	}
end

local function segmentSpecs(self: Assembler, index: number): { Spec }
	local cached = self.specCache[index]
	if cached then
		return cached
	end
	local plan = self.plan
	local seg = plan.segments[index]
	local b = self.buckets[index]
	local specs: { Spec } = {}
	local labels = self.labels
	local g = self.geometry

	-- road piece
	local prev, nxt = plan.segments[index - 1], plan.segments[index + 1]
	local roadSpec: Proxies.RoadSpec = {
		kind = seg.kind,
		length = seg.length,
		bend = seg.bend,
		radius = seg.radius,
		crossAt = seg.crossAt,
		waterStart = seg.kind == "BridgeDeck" and not (prev and prev.kind == "BridgeDeck"),
		waterEnd = seg.kind == "BridgeDeck" and not (nxt and nxt.kind == "BridgeDeck"),
	}
	local roadKey = string.format(
		"road:%s:%d:%s%s",
		seg.kind,
		math.floor(seg.length + 0.5),
		if roadSpec.waterStart then "s" else "",
		if roadSpec.waterEnd then "e" else ""
	)
	local spec = meshOrProxy(self, seg.mesh, "Road", roadKey, function()
		return Proxies.road(roadSpec, g, labels)
	end, function(t)
		return seg.start * centreOffset(t)
	end, seg.start)
	table.insert(specs, spec)

	-- lots, forecourts and signs
	for _, lot in b.lots do
		local lotLook = look(self, lot.palette)
		local key: string
		if lot.module == "GAP" and self.world and self.world.v2 then
			-- World build V2: open ground is open ground (no city stone pad, planter or tree in the desert or the snow)
			continue
		elseif lot.module == "GAP" then
			local w = math.max(1, math.floor(lot.width + 0.5))
			key = "gap:" .. w
			table.insert(specs, {
				key = key,
				kind = "Lots",
				tris = 0,
				mesh = false,
				make = function()
					return Proxies.lot({
						name = "GAP",
						kind = "gap",
						width = w,
						depth = 12,
						height = 0,
						orientation = "front",
						finish = "",
						shop = false,
					}, lotLook, false)
				end,
				place = function(inst: Instance)
					pivotTo(inst, lot.pivot)
				end,
			})
		else
			key = "lot:" .. lot.module .. ":" .. lot.palette
			local lotSpec: Proxies.LotSpec = {
				name = lot.module,
				kind = if lot.kind == "transition-park" or lot.kind == "corner-plaza" then "park" else lot.kind,
				width = lot.width,
				depth = lot.depth,
				height = lot.height,
				orientation = lot.orientation,
				finish = lot.finish,
				shop = lot.shop,
			}
			table.insert(
				specs,
				meshOrProxy(self, lot.module, "Lots", key, function()
					return Proxies.lot(lotSpec, lotLook, labels)
				end, function(t)
					return lot.pivot * fit(t, lot.width)
				end, lot.pivot)
			)
		end
		if lot.setback > 0 then
			local fkey = string.format("forecourt:%d:%d", math.floor(lot.width + 0.5), lot.setback)
			table.insert(specs, {
				key = fkey,
				kind = "Lots",
				tris = 0,
				mesh = false,
				make = function()
					return Proxies.forecourt(lot.width, lot.setback)
				end,
				place = function(inst: Instance)
					pivotTo(inst, lot.pivot)
				end,
			})
		end
		local text = lot.sign
		if text then
			local style = lot.signStyle or "band"
			local t = template(self, lot.module)
			local signY = 11.4
			local socket = t and t.meta.sockets
			if t and type(t.meta.sign_band) == "table" then
				signY = ((tonumber(t.meta.sign_band[1]) or 11) + (tonumber(t.meta.sign_band[2]) or 12)) / 2
			end
			local signCF: CFrame
			if style == "blade" then
				signCF = lot.pivot * CFrame.new(3, math.max(signY + 5, 16), -4.6)
			else
				signCF = lot.pivot * CFrame.new(lot.width / 2, signY, -0.5)
			end
			if type(socket) == "table" and type(socket.sign) == "table" then
				local s = socket.sign
				signCF = lot.pivot
					* fit(t :: Template, lot.width)
					* CFrame.new(tonumber(s.x or s[1]) or 0, tonumber(s.y or s[2]) or 0, tonumber(s.z or s[3]) or 0)
			end
			local width = math.clamp(lot.width - 6, 8, 18)
			table.insert(specs, {
				key = "sign:" .. style,
				kind = "Signs",
				tris = 0,
				mesh = false,
				make = function()
					return Proxies.sign(style)
				end,
				place = function(inst: Instance)
					local board = inst:FindFirstChild("Board")
					if style ~= "blade" and board and board:IsA("BasePart") then
						board.Size = Vector3.new(width, 2.2, 0.3)
					end
					Proxies.setText(inst, text)
					pivotTo(inst, signCF)
				end,
			})
		end
	end

	-- landmarks
	for _, lm in b.landmarks do
		-- World build V2: the glacier gallery is composed of kit bays and portals by WorldFeatures.tunnel (extras), so the
		-- bridge landmark itself draws nothing (no 384-stud proxy block, no Round 2 monolith)
		local v2 = if self.world then self.world.v2 else nil
		if lm.placement == "bridge" and v2 and v2.tunnel and lm.district == v2.tunnel.district then
			continue
		end
		local lmLook = look(self, lm.palette)
		local lmSpec: Proxies.LandmarkSpec = {
			id = lm.id,
			name = lm.module,
			label = lm.label,
			width = lm.width,
			depth = lm.depth,
			height = lm.height,
		}
		table.insert(
			specs,
			meshOrProxy(self, lm.module, "Landmarks", "landmark:" .. lm.id .. ":" .. lm.palette, function()
				return Proxies.landmark(lmSpec, lmLook, labels, g)
			end, function(t)
				if lm.placement == "bridge" then
					return lm.pivot * centreOffset(t)
				end
				return lm.pivot * fit(t, lm.width)
			end, lm.pivot, true)
		)
		-- World build V2: a true gorge (WorldPlan) has its own deep floor and cut ground (updateGround), so no flat strip
		local hasGorge = plan.world ~= nil and #plan.world.gorges > 0
		if lm.placement == "bridge" and not hasGorge then
			-- harbour water under the deck (reviewer, 2026-10-23: no water at Harbor Bridge); a plain
			-- part just above the ground tiles, so it costs no EditableMesh. A World names its own floor (a dry
			-- canyon wash, an ice crevasse): still a flat strip, not a depth.
			local under = if self.world then self.world.under else nil
			local underName = if under then under.name else "HarborWater"
			local underColour = if under then under.colour else WATER_COLOUR
			local length = lm.to - lm.from + 24
			table.insert(
				specs,
				{
					key = string.format("water:%s:%d", underName, math.floor(length + 0.5)),
					kind = "Landmarks",
					tris = 0,
					mesh = false,
					make = function()
						local p = Proxies.block(underName)
						p.Size = Vector3.new(WATER_ACROSS, 0.1, length)
						p.Color = underColour
						p.Material = Enum.Material.SmoothPlastic
						p.Reflectance = if under then 0 else 0.15
						p.CastShadow = false
						return p
					end,
					place = function(inst: Instance)
						local at = lm.pivot.Position;
						(inst :: BasePart).CFrame = lm.pivot.Rotation + Vector3.new(at.X, WATER_Y, at.Z)
					end,
				} :: Spec
			)
		end
	end

	-- props
	for _, p in b.props do
		table.insert(
			specs,
			meshOrProxy(self, p.module, "Props", "prop:" .. p.kind, function()
				return Proxies.prop(p.kind)
			end, function(t)
				return p.cframe * centreOffset(t)
			end, p.cframe)
		)
	end

	-- spans
	for _, sp in b.spans do
		table.insert(specs, {
			key = string.format("span:%s:%d", sp.kind, math.floor(sp.width + 0.5)),
			kind = "Spans",
			tris = 0,
			mesh = false,
			make = function()
				return Proxies.span(sp.kind, sp.text, sp.width, sp.clearance)
			end,
			place = function(inst: Instance)
				pivotTo(inst, sp.cframe)
			end,
		})
	end

	-- hazard previews
	for _, h in b.hazards do
		local kitName = hazardMeshesOf(self.world)[h.kind]
		local function proxy(): Instance
			return Proxies.hazard(h.kind, h.length, g.laneWidth, labels)
		end
		if kitName then
			-- the B2 kit pothole / oil (recessed rim, sheen edge) instead of the flat proxies
			table.insert(
				specs,
				meshOrProxy(self, kitName, "Hazards", "hazard:" .. h.kind, proxy, function(t)
					return h.cframe * centreOffset(t)
				end, h.cframe)
			)
		else
			table.insert(specs, {
				key = "hazard:" .. h.kind,
				kind = "Hazards",
				tris = 0,
				mesh = false,
				make = proxy,
				place = function(inst: Instance)
					pivotTo(inst, h.cframe)
				end,
			})
		end
	end

	-- midground masses (one generic block each; roof tanks on some Midtown masses)
	for _, m in b.mid do
		table.insert(specs, massSpec(self, m, "Midground", true))
		if m.roofTank then
			table.insert(specs, {
				key = "tank",
				kind = "Masses",
				tris = 0,
				mesh = false,
				make = function()
					local p = Proxies.block("RoofTank")
					p.Shape = Enum.PartType.Cylinder
					p.Size = Vector3.new(7, 6, 6)
					p.Color = Color3.fromRGB(150, 116, 92)
					p.CastShadow = false
					return p
				end,
				place = function(inst: Instance)
					(inst :: BasePart).CFrame = m.cframe
						* CFrame.new(m.size.X * 0.2, m.size.Y / 2 + 3.5, 0)
						* CFrame.Angles(0, 0, math.pi / 2)
				end,
			})
		end
	end
	if self.merge then
		for _, m in b.sky do
			table.insert(specs, massSpec(self, m, "Skyline", true))
		end
	end
	-- World build V2: backdrop, gorge, ground, edge and prop pieces (far ones ride with the segment in Play, like the sky masses)
	for _, e in b.extrasNear do
		table.insert(specs, extraSpec(self, e, true))
	end
	if self.merge then
		for _, e in b.extrasFar do
			table.insert(specs, extraSpec(self, e, true))
		end
	end
	self.specCache[index] = specs
	return specs
end

local function skySpecs(self: Assembler, index: number): { Spec }
	local cached = self.skySpecCache[index]
	if cached then
		return cached
	end
	local b = self.buckets[index]
	local specs: { Spec } = {}
	if not self.merge then
		for _, m in b.sky do
			table.insert(specs, massSpec(self, m, "Skyline", false))
		end
		for _, e in b.extrasFar do
			table.insert(specs, extraSpec(self, e, false))
		end
	end
	for _, lm in b.skyLandmarks do
		local lmLook = look(self, lm.palette)
		local lmSpec: Proxies.LandmarkSpec = {
			id = lm.id,
			name = lm.module,
			label = lm.label,
			width = lm.width,
			depth = lm.depth,
			height = lm.height,
		}
		table.insert(
			specs,
			meshOrProxy(self, lm.module, "Landmarks", "landmark:" .. lm.id .. ":" .. lm.palette, function()
				return Proxies.landmark(lmSpec, lmLook, false, self.geometry)
			end, function(t)
				return lm.pivot * fit(t, lm.width)
			end, lm.pivot)
		)
	end
	self.skySpecCache[index] = specs
	return specs
end

-- Pool -----------------------------------------------------------------------------------------

local function acquire(self: Assembler, spec: Spec): Instance
	local list = self.pool[spec.key]
	local inst = list and table.remove(list)
	if inst then
		self.reused += 1
	else
		inst = spec.make()
		self.created += 1
		inst:SetAttribute("PoolKey", spec.key)
	end
	spec.place(inst :: Instance)
	return inst :: Instance
end

local function release(self: Assembler, live: Live)
	if live.mergeJob then
		Merge.cancel(live.mergeJob)
		live.mergeJob = nil
	end
	live.mergeItems = nil
	for _, item in live.items do
		item.inst.Parent = self.poolFolder
		local list = self.pool[item.key]
		if not list then
			list = {}
			self.pool[item.key] = list
		end
		table.insert(list, item.inst)
		self.released += 1
	end
	table.clear(live.items)
end

-- Builds up to `budget` items into `live`; returns the budget left.
local function fill(self: Assembler, live: Live, budget: number): number
	while budget > 0 and live.nextSpec <= #live.specs do
		local spec = live.specs[live.nextSpec]
		live.nextSpec += 1
		if spec.merge then
			local list = live.mergeItems
			if not list then
				list = {}
				live.mergeItems = list
			end
			table.insert(
				list :: { Merge.Item },
				{ data = spec.merge.data, cframe = spec.merge.cframe(), scale = spec.merge.scale }
			)
			budget -= 1
			continue
		end
		local inst = acquire(self, spec)
		inst.Parent = self.folders[spec.kind] or self.root
		table.insert(live.items, { key = spec.key, inst = inst, kind = spec.kind, tris = spec.tris, mesh = spec.mesh })
		budget -= 1
	end
	if live.nextSpec > #live.specs and live.mergeItems and not live.mergeJob then
		local assembler = self
		live.mergeJob = Merge.start(live.mergeItems :: { Merge.Item }, {
			swatches = self.swatches,
			textureId = self.textureId,
			parent = self.folders.Lots,
			name = "MergedSegment",
			maxMeshes = function(): boolean
				local count = 0
				for _, l in assembler.live do
					if l.mergeJob then
						count += #l.mergeJob.meshes
					end
				end
				return count < Assembler.MERGE_MAX_MESHES
			end,
		})
	end
	return budget
end

local function groundKey(cx: number, cz: number): string
	return cx .. "," .. cz
end

-- World build V2 (true gorge): does an axis-aligned ground tile (centre `at`, half-size GROUND_CELL / 2 + 24 for the
-- 2,048-stud slab overlap) touch the gorge's oriented rectangle (grown by `grow`)? The gorge is far smaller than a tile, so
-- one corner or edge midpoint inside the tile, or the tile centre inside the rectangle, is a full test.
local GORGE_REACH = 2112 -- how far the replacement slabs reach past a gorge's edge: a touched tile ends at most 2,048 + 40 beyond it
local PART_MAX = 2048 -- Roblox clamps every part to 2,048 studs a side, so a longer slab is built from pieces
local function tileHitsGorge(at: Vector3, g: { [string]: any }, grow: number): boolean
	local centre = g.centre :: CFrame
	local hl, hw = (g.halfLength :: number) + grow, (g.halfWidth :: number) + grow
	local half = 1024 + 8
	local function inTile(p: Vector3): boolean
		return math.abs(p.X - at.X) <= half and math.abs(p.Z - at.Z) <= half
	end
	for _, u in { -hl, 0, hl } do
		for _, v in { -hw, 0, hw } do
			if inTile(centre:PointToWorldSpace(Vector3.new(v, 0, u))) then
				return true
			end
		end
	end
	local rel = centre:PointToObjectSpace(Vector3.new(at.X, centre.Position.Y, at.Z))
	return math.abs(rel.X) <= hw and math.abs(rel.Z) <= hl
end

-- Cuts [lo, hi] into the fewest equal pieces that each fit a part: { { middle, length } }.
local function pieces(lo: number, hi: number): { { number } }
	local n = math.max(1, math.ceil((hi - lo) / PART_MAX - 1e-6))
	local len = (hi - lo) / n
	local out = {}
	for i = 1, n do
		table.insert(out, { lo + (i - 0.5) * len, len })
	end
	return out
end

-- The slabs and the deep floor that replace the tiles a gorge touches: front and back of the span, and the two sides,
-- all in the gorge's own frame (so the hole's edges are straight along the walls), each cut into parts of at most
-- PART_MAX studs, plus the floor far below.
local function gorgeParts(
	self: Assembler,
	g: { [string]: any }
): { { name: string, cframe: CFrame, size: Vector3, colour: Color3 } }
	local centre = g.centre :: CFrame
	local hl, hw = g.halfLength :: number, g.halfWidth :: number
	local reach = GORGE_REACH
	local ground = self.groundColour
	local floorColour = if self.world and self.world.under then self.world.under.colour else Color3.fromRGB(112, 62, 54)
	local parts: { { name: string, cframe: CFrame, size: Vector3, colour: Color3 } } = {}
	-- x across the span (the gorge's width axis), z along it
	local function slab(name: string, x0: number, x1: number, z0: number, z1: number)
		for i, px in pieces(x0, x1) do
			for j, pz in pieces(z0, z1) do
				table.insert(parts, {
					name = string.format("%s%d_%d", name, i, j),
					cframe = centre * CFrame.new(px[1], -0.8, pz[1]),
					size = Vector3.new(px[2], 1, pz[2]),
					colour = ground,
				})
			end
		end
	end
	slab("GorgeFront", -(hw + reach), hw + reach, -(hl + reach), -hl)
	slab("GorgeBack", -(hw + reach), hw + reach, hl, hl + reach)
	slab("GorgeLeft", -(hw + reach), -hw, -hl, hl)
	slab("GorgeRight", hw, hw + reach, -hl, hl)
	table.insert(parts, {
		name = "GorgeFloor",
		cframe = centre * CFrame.new(0, (g.floorY :: number) - 0.5, 0),
		size = Vector3.new(2 * hw + 4, 1, 2 * hl + 4),
		colour = floorColour,
	})
	-- Worlds follow-ups (2026-10-29): the composition dressing, on the rim (the lip, 3 studs wide) or inside the cut (|x| <= hw,
	-- |z| <= hl); preview blocks never collide
	local dress = g.dress
	if dress then
		local lip = dress.lip
		if lip then
			for _, side in { -1, 1 } do
				table.insert(parts, {
					name = if side < 0 then "GorgeLipL" else "GorgeLipR",
					-- on the rim, its inner edge flush with the wall face, its top `rise` over the ground
					cframe = centre * CFrame.new(side * (hw + lip.width / 2), -0.3 + lip.rise / 2 - 0.5, 0),
					size = Vector3.new(lip.width, 1 + lip.rise, 2 * hl),
					colour = lip.colour,
				})
			end
		end
		local shade = dress.shade
		if shade then
			local n = #shade.depths
			for _, side in { -1, 1 } do
				for i, d in shade.depths do
					-- the mirror side runs the steps the other way, so the two walls do not match
					local k = if side < 0 then i else n + 1 - i
					local len = 2 * hl / n
					table.insert(parts, {
						name = string.format("GorgeShade%s%d", if side < 0 then "L" else "R", i),
						cframe = centre * CFrame.new(side * (hw - 0.5), -0.3 - d / 2, -hl + (k - 0.5) * len),
						size = Vector3.new(1, d, len),
						colour = shade.colour,
					})
				end
			end
		end
		local river = dress.river
		if river then
			-- three straight reaches that wander across the floor (opaque: no transparent water stack)
			local xs = { -river.wander, river.wander * 0.6, -river.wander * 0.3 }
			local len = 2 * hl / #xs
			for i, x in xs do
				local nextX = xs[i + 1] or x
				local angle = math.atan2(nextX - x, len)
				table.insert(parts, {
					name = "GorgeRiver" .. i,
					cframe = centre
						* CFrame.new((x + nextX) / 2, (g.floorY :: number) + 0.05, -hl + (i - 0.5) * len)
						* CFrame.Angles(0, angle, 0),
					size = Vector3.new(river.width, 0.2, len / math.cos(angle) + river.width * 0.25),
					colour = river.colour,
				})
			end
		end
	end
	return parts
end

local function updateGround(self: Assembler, points: { Vector3 })
	local wanted: { [string]: Vector3 } = {}
	for _, p in points do
		local cx, cz = math.floor(p.X / GROUND_CELL + 0.5), math.floor(p.Z / GROUND_CELL + 0.5)
		for dx = -1, 1 do
			for dz = -1, 1 do
				wanted[groundKey(cx + dx, cz + dz)] =
					Vector3.new((cx + dx) * GROUND_CELL, -0.8, (cz + dz) * GROUND_CELL)
			end
		end
	end
	-- World build V2: a tile that a gorge touches is not built; the gorge's slabs and floor stand in for it
	local gorges = if self.plan.world then self.plan.world.gorges else {}
	local gorgeWanted: { [string]: boolean } = {}
	if #gorges > 0 then
		for key, at in wanted do
			for i, g in gorges do
				if tileHitsGorge(at, g, 40) then
					wanted[key] = nil
					for _, part in gorgeParts(self, g) do
						gorgeWanted["gorge:" .. i .. ":" .. part.name] = true
					end
					break
				end
			end
		end
	end
	for key, item in self.groundLive do
		if not wanted[key] and not gorgeWanted[key] then
			release(self, { items = { item }, specs = {}, nextSpec = 1 })
			self.groundLive[key] = nil
		end
	end
	for key in gorgeWanted do
		if not self.groundLive[key] then
			local i = tonumber(string.match(key, "^gorge:(%d+):")) :: number
			for _, part in gorgeParts(self, gorges[i]) do
				if "gorge:" .. i .. ":" .. part.name == key then
					local spec: Spec = {
						key = "gorge:" .. part.name,
						kind = "Ground",
						tris = 0,
						mesh = false,
						make = function()
							local p = Proxies.block(part.name)
							p.Size = part.size
							p.Color = part.colour
							p.CastShadow = false
							return p
						end,
						place = function(inst: Instance)
							local p = inst :: BasePart
							p.Size = part.size
							p.Color = part.colour
							p.CFrame = part.cframe
						end,
					}
					local inst = acquire(self, spec)
					inst.Parent = self.folders.Ground
					self.groundLive[key] = { key = spec.key, inst = inst, kind = "Ground", tris = 0, mesh = false }
				end
			end
		end
	end
	for key, at in wanted do
		if not self.groundLive[key] then
			local spec: Spec = {
				key = "ground",
				kind = "Ground",
				tris = 0,
				mesh = false,
				make = function()
					local p = Proxies.block("GroundTile")
					p.Size = Vector3.new(2048, 1, 2048)
					p.Color = self.groundColour
					p.CastShadow = false
					return p
				end,
				place = function(inst: Instance)
					(inst :: BasePart).CFrame = CFrame.new(at)
				end,
			}
			local inst = acquire(self, spec)
			inst.Parent = self.folders.Ground
			self.groundLive[key] = { key = "ground", inst = inst, kind = "Ground", tris = 0, mesh = false }
		end
	end
end

-- Window -----------------------------------------------------------------------------------------

-- Moves the active window to route distance s. Builds up to `budget` items (all of them when
-- `immediate`), nearest segments first; releases everything that left the window to the pool.
function Assembler.setStation(self: Assembler, s: number, immediate: boolean?)
	if self.destroyed then
		return
	end
	local segments = self.plan.segments
	local n = #segments
	if n == 0 then
		return
	end
	self.station = s
	local current = Route.find(segments, s)
	local from, to = math.max(1, current - self.behind), math.min(n, current + self.ahead)
	local skyFrom, skyTo = math.max(1, current - self.skyBehind), math.min(n, current + self.skyAhead)
	self.windowFrom, self.windowTo = from, to
	for i, live in self.live do
		if i < from or i > to then
			release(self, live)
			self.live[i] = nil
		end
	end
	for i, live in self.skyLive do
		if i < skyFrom or i > skyTo then
			release(self, live)
			self.skyLive[i] = nil
		end
	end
	local budget = if immediate then math.huge else self.budget
	local order: { number } = {}
	for i = current, to do
		table.insert(order, i)
	end
	for i = current - 1, from, -1 do
		table.insert(order, i)
	end
	for _, i in order do
		local live = self.live[i]
		if not live then
			live = { items = {}, specs = segmentSpecs(self, i), nextSpec = 1 }
			self.live[i] = live
		end
		budget = fill(self, live, budget)
		if budget <= 0 then
			break
		end
	end
	if budget > 0 then
		for i = skyFrom, skyTo do
			local live = self.skyLive[i]
			if not live then
				live = { items = {}, specs = skySpecs(self, i), nextSpec = 1 }
				self.skyLive[i] = live
			end
			budget = fill(self, live, budget)
			if budget <= 0 then
				break
			end
		end
	end
	if self.ground then
		updateGround(self, {
			Route.point(segments, s),
			Route.point(segments, s + 1200),
		})
	end
	self.passes += 1
end

-- Builds the whole window around s at once (no budget), e.g. for a still frame.
function Assembler.buildAt(self: Assembler, s: number)
	self:setStation(s, true)
end

function Assembler.getStation(self: Assembler): number
	return self.station
end

function Assembler.frame(self: Assembler, s: number, d: number?, y: number?): CFrame
	return Route.frame(self.plan.segments, s, d, y)
end

function Assembler.getStats(self: Assembler): Stats
	local liveItems, liveMesh, liveProxy, tris = 0, 0, 0, 0
	local function count(map: { [number]: Live })
		for _, live in map do
			for _, item in live.items do
				liveItems += 1
				if item.mesh then
					liveMesh += 1
					tris += item.tris
				else
					liveProxy += 1
				end
			end
		end
	end
	count(self.live)
	count(self.skyLive)
	local groundTiles = 0
	for _ in self.groundLive do
		groundTiles += 1
		liveItems += 1
		liveProxy += 1
	end
	local pooled = 0
	for _, list in self.pool do
		pooled += #list
	end
	local unique, uniqueTris, editables, uploaded, missing = 0, 0, 0, 0, 0
	local missingNames: { string } = {}
	for name, t in self.templates do
		if t.part or t.data then
			unique += 1
			uniqueTris += t.triangles
			if t.editable then
				editables += 1
			end
			if t.source == "uploaded" then
				uploaded += 1
			end
		else
			missing += 1
			if #missingNames < 40 then
				table.insert(missingNames, name .. " (" .. t.source .. ")")
			end
		end
	end
	table.sort(missingNames)
	local parts = 0
	for _, d in self.root:GetDescendants() do
		if d:IsA("BasePart") then
			parts += 1
		end
	end
	local segmentsLive, skyLive = 0, 0
	for _ in self.live do
		segmentsLive += 1
	end
	for _ in self.skyLive do
		skyLive += 1
	end
	return {
		mode = modeName(),
		seed = self.plan.seed,
		routeLength = self.plan.length,
		station = math.floor(self.station * 10 + 0.5) / 10,
		windowFrom = self.windowFrom,
		windowTo = self.windowTo,
		behind = self.behind,
		ahead = self.ahead,
		segmentsLive = segmentsLive,
		skySegmentsLive = skyLive,
		liveItems = liveItems,
		liveMeshInstances = liveMesh,
		liveProxyItems = liveProxy,
		pooledItems = pooled,
		createdItems = self.created,
		reusedItems = self.reused,
		releasedItems = self.released,
		trianglesPlaced = tris,
		uniqueMeshes = unique,
		uniqueTriangles = uniqueTris,
		editableMeshes = editables,
		merged = (function()
			local m = { meshes = 0, parts = 0, triangles = 0, pending = 0, failures = {} }
			for _, l in self.live do
				local job = l.mergeJob
				if job then
					m.meshes += #job.meshes
					m.parts += #job.parts
					m.triangles += job.triangles
					if not job.done then
						m.pending += 1
					end
					if job.failed then
						table.insert(m.failures, job.failed)
					end
				end
			end
			return m
		end)(),
		-- rough: about 120 bytes per preview triangle (vertex, face, normal and UV records)
		estimatedEditableMB = math.floor(uniqueTris * 120 / 1e4 + 0.5) / 100,
		uploadedMeshes = uploaded,
		missingMeshes = missing,
		missingNames = missingNames,
		socketMismatches = table.clone(self.socketMismatches),
		liveParts = parts,
		groundTiles = groundTiles,
		lighting = self.lightingNote,
		kit = (if self.kit then self.kit:GetFullName() else "none (proxies only)") .. "; " .. self.swatchMode,
		buildPasses = self.passes,
	}
end

-- Removes everything this Assembler made (city folder, pool, templates, EditableMeshes). The
-- lighting stays until Assembler.restoreLighting().
function Assembler.destroy(self: Assembler)
	if self.destroyed then
		return
	end
	self.destroyed = true
	for _, live in self.live do
		if live.mergeJob then
			Merge.cancel(live.mergeJob)
		end
	end
	self.root:Destroy()
	self.poolFolder:Destroy()
	for _, list in self.pool do
		for _, inst in list do
			inst:Destroy()
		end
	end
	table.clear(self.pool)
	for _, t in self.templates do
		if t.part then
			t.part:Destroy()
		end
		if t.editable then
			t.editable:Destroy()
		end
	end
	table.clear(self.templates)
	table.clear(self.live)
	table.clear(self.skyLive)
	table.clear(self.groundLive)
	table.clear(self.specCache)
	table.clear(self.skySpecCache)
end

return Assembler
