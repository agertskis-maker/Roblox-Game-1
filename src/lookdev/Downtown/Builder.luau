--!strict
-- Downtown look-development BUILDER (Lane 3 preview, Studio EDIT MODE only). Builds one of the
-- three visual studies (A Sunny Toy City, B Bright Real City, C Big Bright Metropolis) into
-- Workspace.Lane3_DowntownLookDev from:
--   ServerStorage.Lane3_DowntownKit      one ModuleScript per mesh (Rojo-mapped mesh JSON:
--                                        name, triangles, bounds, meta, grid, p, t)
--   ServerStorage.Lane3_DowntownLayouts  layout-A / layout-B / layout-C (Rojo-mapped JSON: an
--                                        array, or { instances = [...] }, of
--                                        { mesh, position = {x,y,z}, yaw (degrees), scale? (number or
--                                          [w,h,d] for unit meshes), sign? (text for every
--                                          sign face, or { [faceName] = text }), landmark?,
--                                          animated? } in the road frame)
--                                        and D1's swatches (swatches.json: { grid, swatches =
--                                        [{ index, A, B, C }] }), or an optional palette-<id>
--                                        module { grid, colors = {{r,g,b}, ...} }
-- Mesh y = 0 is the ground line. yaw is CFrame.Angles(0, rad(yaw), 0): positive turns
-- counter-clockwise seen from above (options.yawSign = -1 flips it if the Blender export
-- disagrees). One template MeshPart per mesh name (one EditableMesh each), cloned per instance.
-- A mesh missing from the kit becomes a labelled grey box of its bounds (or 4 x 4 x 4) and is
-- counted as missing; the build never errors on kit content. Road and hazard groups that the
-- layout does not provide are filled with labelled part proxies (Road, Hazards).
--
-- Nothing here runs in Play or for players: build() asserts Studio edit mode. EditableMesh
-- content is session-only (not saved, not carried into Play); uploaded mesh ids passed in
-- options.meshIds are used instead where present and do survive into Play.

local AssetService = game:GetService("AssetService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local Fixture = require(script.Parent.Fixture)
local Hazards = require(script.Parent.Hazards)
local KitMesh = require(script.Parent.KitMesh)
local Parts = require(script.Parent.Parts)
local Road = require(script.Parent.Road)
local Tokens = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UI"):WaitForChild("Tokens"))

local Builder = {}

Builder.ROOT = "Lane3_DowntownLookDev"
local KIT_FOLDER = "Lane3_DowntownKit"
local LAYOUT_FOLDER = "Lane3_DowntownLayouts"
local STASH = "Lane3_DowntownLightingStash"
local ORIGINAL = "Lane3LookDevOriginal_"
local OURS = "Lane3LookDev"
local YIELD_EVERY = 150
local HALF_TURN = CFrame.Angles(0, math.pi, 0)

export type Direction = "A" | "B" | "C"
export type Options = {
	-- an uploaded palette asset ("rbxassetid://123" or "123") used as TextureID, or a palette
	-- name ("A") whose swatches (palette-A module, or column A of swatches) give vertex colours
	paletteId: string,
	meshIds: { [string]: string }?, -- uploaded mesh ids by mesh name (used before preview data)
	yawSign: number?, -- 1 (default) or -1
	roadProxy: ("auto" | "always" | "never")?, -- auto: only when the layout has no road meshes
	hazardFallbacks: boolean?, -- default true
	keepTemplates: boolean?, -- keep other directions' templates (default false: frees memory)
}
export type Stats = {
	direction: string,
	palette: string,
	paletteMode: string,
	layoutFound: boolean,
	layoutEntries: number,
	invalidEntries: number,
	uniqueMeshes: number,
	instances: number,
	missing: number,
	missingNames: { string },
	totalTriangles: number,
	uniqueTriangles: number,
	editableMeshes: number,
	estimatedEditableMB: number,
	uploadedMeshes: number,
	parts: number,
	proxyParts: number,
	signs: number,
	transparentEffects: number,
	transparentBreakdown: { [string]: number },
	animatedObjects: number,
	roadProxy: boolean,
	hazardFallbacks: { string },
	buildSeconds: number,
	lighting: string,
}

type Entry = {
	mesh: string,
	position: Vector3,
	yaw: number,
	scale: Vector3, -- a number in the layout is uniform; [w, h, d] scales unit meshes
	sign: any, -- a string for every sign face, or { [faceName or index] = text }
	landmark: boolean,
	animated: boolean,
}

type Template = {
	part: MeshPart?, -- nil when the mesh could not be made
	data: KitMesh.Data?,
	turn: CFrame,
	source: string, -- "uploaded", "preview" or "missing: <reason>"
}

-- Module state (rebuilt on demand if a fresh require loses it).
local templates: { [string]: Template } = {}
local editables: { [string]: EditableMesh } = {}
local templatePalette: string? = nil

local function assertEditMode()
	assert(
		RunService:IsStudio() and not RunService:IsRunning(),
		"Downtown Builder runs only in Studio edit mode (not in Play)"
	)
end

local function findFolder(name: string): Instance?
	return ServerStorage:FindFirstChild(name) or ReplicatedStorage:FindFirstChild(name)
end

local function freshRequire(module: Instance): (boolean, any)
	if not module:IsA("ModuleScript") then
		return false, "not a ModuleScript"
	end
	-- a fresh copy, so a re-exported file is not served from the module cache
	return pcall(function()
		return (require :: any)(module:Clone())
	end)
end

local function vec(value: any): Vector3?
	if typeof(value) == "Vector3" then
		return value
	end
	if type(value) == "table" and type(value[1]) == "number" and type(value[2]) == "number" then
		return Vector3.new(value[1], value[2], (value[3] :: number?) or 0)
	end
	return nil
end

local function lower(s: string): string
	return string.lower(s)
end

local function matchesAny(name: string, patterns: { string }): boolean
	local l = lower(name)
	for _, p in patterns do
		if string.find(l, p, 1, true) then
			return true
		end
	end
	return false
end

local ANIMATED_PATTERNS = { "flag", "train", "steam", "cart", "blimp", "screen", "billboard" }

-- Palette -------------------------------------------------------------------------------------

local function resolvePalette(paletteId: string): (string, { Color3 }?, string)
	if string.match(paletteId, "^%d+$") then
		return "rbxassetid://" .. paletteId, nil, "texture"
	end
	if string.find(paletteId, "://", 1, true) then
		return paletteId, nil, "texture"
	end
	for _, folderName in { LAYOUT_FOLDER, KIT_FOLDER } do
		local folder = findFolder(folderName)
		local module = folder and (folder:FindFirstChild("palette-" .. paletteId) or folder:FindFirstChild(paletteId))
		if module then
			local ok, value = freshRequire(module)
			if ok and type(value) == "table" and type(value.colors) == "table" then
				local swatches = {}
				for i, c in value.colors do
					if type(c) == "table" then
						swatches[i] = Color3.fromRGB(c[1] or 255, c[2] or 0, c[3] or 255)
					end
				end
				return "", swatches, "vertex colours from palette-" .. paletteId
			end
			warn("[Lane3 Downtown] palette module " .. module:GetFullName() .. " is not a swatch table")
		end
	end
	-- D1's manifest: any list of { index, A = {r,g,b}, B = ..., C = ... } (palette.swatch_table)
	for _, folderName in { LAYOUT_FOLDER, KIT_FOLDER } do
		local folder = findFolder(folderName)
		local module = folder and (folder:FindFirstChild("swatches") or folder:FindFirstChild("manifest"))
		local ok, value = false, nil
		if module then
			ok, value = freshRequire(module)
		end
		if ok and type(value) == "table" then
			for _, list in value do
				local first = type(list) == "table" and list[1]
				if type(first) == "table" and type(first.index) == "number" and type(first[paletteId]) == "table" then
					local swatches = {}
					for _, row in list do
						local c = row[paletteId]
						if type(row.index) == "number" and type(c) == "table" then
							swatches[row.index + 1] = Color3.fromRGB(c[1], c[2], c[3])
						end
					end
					return "", swatches, "vertex colours from manifest swatches (" .. paletteId .. ")"
				end
			end
		end
	end
	warn(
		"[Lane3 Downtown] palette '"
			.. paletteId
			.. "' is neither an asset id nor a swatch module; meshes will be untextured"
	)
	return "", nil, "none (untextured)"
end

-- Templates -----------------------------------------------------------------------------------

local function releaseTemplates(keep: { [string]: boolean }?)
	for name, template in templates do
		if not (keep and keep[name]) then
			if template.part then
				template.part:Destroy()
			end
			local em = editables[name]
			if em then
				em:Destroy()
				editables[name] = nil
			end
			templates[name] = nil
		end
	end
end

local function loadData(kit: Instance?, name: string): (KitMesh.Data?, string?)
	local module = kit and kit:FindFirstChild(name)
	if not module then
		return nil, "not in " .. KIT_FOLDER
	end
	local ok, value = freshRequire(module)
	if not ok then
		return nil, "could not load: " .. tostring(value)
	end
	if
		type(value) ~= "table"
		or type(value.p) ~= "table"
		or type(value.t) ~= "table"
		or type(value.bounds) ~= "table"
		or type(value.grid) ~= "number"
	then
		return nil, "not kit mesh data"
	end
	value.meta = if type(value.meta) == "table" then value.meta else {}
	value.triangles = if type(value.triangles) == "number" then value.triangles else #value.t // 4
	value.name = name
	return value :: KitMesh.Data, nil
end

local function finish(part: MeshPart, name: string)
	part.Name = name
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = true
	part.Material = Enum.Material.SmoothPlastic
	part.Color = Color3.new(1, 1, 1)
end

-- meta.material hints from the kit ("Metal", "Asphalt-look Plastic", "Neon (dim) or SmoothPlastic"):
-- only Metal changes the material; everything else stays SmoothPlastic so daylight reads evenly.
local function applyMaterial(part: MeshPart, data: KitMesh.Data?)
	local hint = data and data.meta.material
	if type(hint) == "string" and string.find(string.lower(hint), "^metal") then
		part.Material = Enum.Material.Metal
	end
end

local function template(
	kit: Instance?,
	name: string,
	textureId: string,
	swatches: { Color3 }?,
	meshIds: { [string]: string }?
): Template
	local cached = templates[name]
	if cached then
		return cached
	end
	local data, reason = loadData(kit, name)
	local result: Template
	local uploaded = meshIds and meshIds[name]
	if uploaded then
		local ok, part = pcall(function()
			return AssetService:CreateMeshPartAsync(Content.fromUri(uploaded), {
				CollisionFidelity = Enum.CollisionFidelity.Box,
				RenderFidelity = Enum.RenderFidelity.Automatic,
			})
		end)
		if ok then
			finish(part, name)
			part.TextureID = textureId
			applyMaterial(part, data)
			-- uploaded kit meshes arrive turned 180 degrees about Y (as on the island)
			result = { part = part, data = data, turn = HALF_TURN, source = "uploaded" }
			templates[name] = result
			return result
		end
		warn("[Lane3 Downtown] uploaded mesh " .. uploaded .. " for " .. name .. " failed: " .. tostring(part))
	end
	if not data then
		result = { part = nil, data = nil, turn = CFrame.identity, source = "missing: " .. tostring(reason) }
	else
		local ok, part, em = pcall(KitMesh.previewPart, data, textureId, swatches)
		if ok then
			finish(part, name)
			editables[name] = em
			applyMaterial(part, data)
			result = { part = part, data = data, turn = CFrame.identity, source = "preview" }
		else
			result = { part = nil, data = data, turn = CFrame.identity, source = "missing: " .. tostring(part) }
		end
	end
	templates[name] = result
	return result
end

-- Layout --------------------------------------------------------------------------------------

local function loadLayout(direction: Direction): ({ Entry }, boolean, number)
	local folder = findFolder(LAYOUT_FOLDER)
	local module = folder
		and (
			folder:FindFirstChild("layout-" .. direction)
			or folder:FindFirstChild("layout_" .. direction)
			or folder:FindFirstChild("Layout" .. direction)
		)
	if not module then
		warn("[Lane3 Downtown] no layout-" .. direction .. " in " .. LAYOUT_FOLDER .. "; building proxies only")
		return {}, false, 0
	end
	local ok, value = freshRequire(module)
	if not ok or type(value) ~= "table" then
		warn("[Lane3 Downtown] layout-" .. direction .. " did not load: " .. tostring(value))
		return {}, false, 0
	end
	local list = if type(value.instances) == "table" then value.instances else value
	local entries: { Entry } = {}
	local invalid = 0
	for _, raw in list do
		local position = type(raw) == "table" and vec(raw.position)
		if type(raw) == "table" and type(raw.mesh) == "string" and position then
			table.insert(entries, {
				mesh = raw.mesh,
				position = position,
				yaw = if type(raw.yaw) == "number" then raw.yaw else 0,
				scale = if type(raw.scale) == "number" and raw.scale > 0
					then Vector3.one * raw.scale
					else vec(raw.scale) or Vector3.one,
				sign = if (type(raw.sign) == "string" and raw.sign ~= "") or type(raw.sign) == "table"
					then raw.sign
					else nil,
				landmark = raw.landmark == true or matchesAny(raw.mesh, { "landmark" }),
				animated = raw.animated == true or matchesAny(raw.mesh, ANIMATED_PATTERNS),
			})
		else
			invalid += 1
		end
	end
	return entries, true, invalid
end

-- Signs ---------------------------------------------------------------------------------------

local NORMALS: { [string]: Vector3 } = {
	Front = Vector3.new(0, 0, -1),
	Back = Vector3.new(0, 0, 1),
	Right = Vector3.new(1, 0, 0),
	Left = Vector3.new(-1, 0, 0),
	Top = Vector3.new(0, 1, 0),
	Bottom = Vector3.new(0, -1, 0),
}

type Face = { name: string, centre: Vector3, width: number, height: number, normal: Vector3, bothSides: boolean }

-- Sign faces from mesh meta: D1's `faces` list ({ name, centre, size = {w, h}, normal =
-- "Front" | ... or {x,y,z}, both_sides }) or a single sign_face / signFace / sign table.
local function signFaces(meta: { [string]: any }): { Face }
	local list = meta.faces
	if type(list) ~= "table" then
		local single = meta.sign_face or meta.signFace or meta.sign
		list = if type(single) == "table" then { single } else {}
	end
	local faces: { Face } = {}
	for i, f in list do
		local centre = type(f) == "table" and (vec(f.centre) or vec(f.center))
		if type(f) == "table" and centre and type(f.size) == "table" then
			local normal = if type(f.normal) == "string" then NORMALS[f.normal] else vec(f.normal)
			table.insert(faces, {
				name = if type(f.name) == "string" then f.name else tostring(i),
				centre = centre,
				width = tonumber(f.size[1]) or 4,
				height = tonumber(f.size[2]) or 1.5,
				normal = if normal and normal.Magnitude > 1e-6 then normal.Unit else NORMALS.Front,
				bothSides = f.both_sides == true or f.bothSides == true,
			})
		end
	end
	return faces
end

local function signPanel(parent: Instance, text: string, cf: CFrame, width: number, height: number, onMesh: boolean)
	local panel = Parts.block(parent, "Sign", Vector3.new(width, height, 0.05), cf, Tokens.Color.Card)
	panel.CastShadow = false
	panel.Transparency = if onMesh then 1 else 0
	panel:SetAttribute("SignText", text)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 1
	gui.MaxDistance = 400
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.TextScaled = true
	label.FontFace = Tokens.font()
	label.TextColor3 = Tokens.Color.Text
	label.Text = text
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0.05, 0)
	padding.PaddingRight = UDim.new(0.05, 0)
	padding.PaddingTop = UDim.new(0.1, 0)
	padding.PaddingBottom = UDim.new(0.1, 0)
	padding.Parent = label
	if onMesh then
		-- on the mesh's own sign board: navy letters with a cream outline read on any board colour
		local stroke = Instance.new("UIStroke")
		stroke.Color = Tokens.Color.Card
		stroke.Thickness = 3
		stroke.Parent = label
	end
	label.Parent = gui
	gui.Parent = panel
end

local function textFor(sign: any, face: Face, index: number): string?
	if type(sign) == "string" then
		return sign
	end
	if type(sign) == "table" then
		local t = sign[face.name] or sign[index]
		return if type(t) == "string" and t ~= "" then t else nil
	end
	return nil
end

-- Places the sign text for one instance; returns the number of sign panels made.
local function makeSigns(parent: Instance, sign: any, base: CFrame, data: KitMesh.Data?, scale: Vector3): number
	local lo = data and vec(data.bounds[1]) or Vector3.new(-2, 0, -2)
	local hi = data and vec(data.bounds[2]) or Vector3.new(2, 4, 2)
	local faces = if data then signFaces(data.meta) else {}
	local made = 0
	for index, face in faces do
		local text = textFor(sign, face, index)
		if text then
			local centre = base:PointToWorldSpace(face.centre * scale)
			local normal = base:VectorToWorldSpace(face.normal)
			local up = if math.abs(normal.Y) > 0.95 then base.LookVector else Vector3.yAxis
			local horizontal = if math.abs(face.normal.X) > 0.5 then scale.Z else scale.X
			local width, height = face.width * horizontal, face.height * scale.Y
			for _, side in (if face.bothSides then { 1, -1 } else { 1 }) do
				local n = normal * side
				signPanel(parent, text, CFrame.lookAt(centre + n * 0.06, centre + n * 2, up), width, height, true)
				made += 1
			end
		end
	end
	if made > 0 or #faces > 0 then
		return made
	end
	-- no sign face in the mesh meta: a cream board on the side that faces the road most
	local text = textFor(
		sign,
		{ name = "", centre = Vector3.zero, width = 0, height = 0, normal = Vector3.zero, bothSides = false },
		1
	)
	if not text then
		return 0
	end
	local centre = base:PointToWorldSpace((lo + hi) / 2 * scale)
	local s = Fixture.project(centre)
	local toRoad = Fixture.point(s) - centre
	toRoad = Vector3.new(toRoad.X, 0, toRoad.Z)
	toRoad = if toRoad.Magnitude > 1e-3 then toRoad.Unit else -base.LookVector
	local half = (hi - lo) / 2 * scale
	local best, bestDot, bestHalf, bestSpan = Vector3.zAxis, -math.huge, half.Z, half.X
	for _, side in
		{
			{ Vector3.xAxis, half.X, half.Z },
			{ -Vector3.xAxis, half.X, half.Z },
			{ Vector3.zAxis, half.Z, half.X },
			{ -Vector3.zAxis, half.Z, half.X },
		}
	do
		local n = base:VectorToWorldSpace(side[1] :: Vector3)
		local dot = n:Dot(toRoad)
		if dot > bestDot then
			best, bestDot, bestHalf, bestSpan = n, dot, side[2] :: number, side[3] :: number
		end
	end
	local y = math.clamp((hi.Y * scale.Y) * 0.72, 3, 16)
	local faceCentre = Vector3.new(centre.X, base.Position.Y + y, centre.Z) + best * (bestHalf + 0.08)
	local width = math.clamp(bestSpan * 2 * 0.8, 3, 24)
	signPanel(
		parent,
		text,
		CFrame.lookAt(faceCentre, faceCentre + best),
		width,
		math.clamp(width * 0.22, 1.6, 4.5),
		false
	)
	return 1
end

-- Lighting ------------------------------------------------------------------------------------

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

local function applyLighting(): string
	for prop, value in LIGHT do
		local key = ORIGINAL .. prop
		if Lighting:GetAttribute(key) == nil then
			Lighting:SetAttribute(key, (Lighting :: any)[prop])
		end
		(Lighting :: any)[prop] = value
	end
	-- park the place's own Atmosphere / ColorCorrection so ours are the only ones
	local stash = ServerStorage:FindFirstChild(STASH)
	for _, child in Lighting:GetChildren() do
		if (child:IsA("Atmosphere") or child:IsA("ColorCorrectionEffect")) and child:GetAttribute(OURS) ~= true then
			if not stash then
				local folder = Instance.new("Folder")
				folder.Name = STASH
				folder.Parent = ServerStorage
				stash = folder
			end
			child.Parent = stash
		elseif child:GetAttribute(OURS) == true then
			child:Destroy()
		end
	end
	local atmosphere = Instance.new("Atmosphere")
	atmosphere.Name = "Lane3LookDev_Atmosphere"
	atmosphere.Density = 0.3
	atmosphere.Offset = 0.12
	atmosphere.Color = Color3.fromRGB(205, 224, 238)
	atmosphere.Decay = Color3.fromRGB(120, 150, 180)
	atmosphere.Glare = 0
	atmosphere.Haze = 1.4
	atmosphere:SetAttribute(OURS, true)
	atmosphere.Parent = Lighting
	local grade = Instance.new("ColorCorrectionEffect")
	grade.Name = "Lane3LookDev_ColorCorrection"
	grade.Brightness = 0.02
	grade.Contrast = 0.06
	grade.Saturation = 0.08
	grade.TintColor = Color3.fromRGB(255, 252, 246)
	grade:SetAttribute(OURS, true)
	grade.Parent = Lighting
	return "ClockTime 13.5, Brightness 2.2, Atmosphere d0.3/o0.12/h1.4, ColorCorrection c0.06/s0.08"
end

-- Puts back the Lighting values and effects that were there before the first build.
function Builder.restoreLighting()
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
	local stash = ServerStorage:FindFirstChild(STASH)
	if stash then
		for _, child in stash:GetChildren() do
			child.Parent = Lighting
		end
		stash:Destroy()
	end
end

-- Clear / build -------------------------------------------------------------------------------

-- Removes everything the builder placed (the lighting stays until restoreLighting).
function Builder.clear(releaseAll: boolean?)
	local root = Workspace:FindFirstChild(Builder.ROOT)
	if root then
		root:Destroy()
	end
	if releaseAll ~= false then
		releaseTemplates(nil)
	end
end

local function countEffects(root: Instance): (number, number, { [string]: number })
	local parts, transparent = 0, 0
	local breakdown = { particles = 0, beams = 0, trails = 0, semiTransparentParts = 0, surfaceGuis = 0 }
	for _, d in root:GetDescendants() do
		if d:IsA("BasePart") then
			parts += 1
			if d.Transparency > 0 and d.Transparency < 1 then
				breakdown.semiTransparentParts += 1
			end
		elseif d:IsA("ParticleEmitter") then
			breakdown.particles += 1
		elseif d:IsA("Beam") then
			breakdown.beams += 1
		elseif d:IsA("Trail") then
			breakdown.trails += 1
		elseif d:IsA("SurfaceGui") then
			breakdown.surfaceGuis += 1
		end
	end
	for _, n in breakdown do
		transparent += n
	end
	return parts, transparent, breakdown
end

function Builder.build(direction: Direction, options: Options): Stats
	assertEditMode()
	assert(direction == "A" or direction == "B" or direction == "C", "direction must be A, B or C")
	local started = os.clock()
	local yawSign = options.yawSign or 1
	local textureId, swatches, paletteMode = resolvePalette(options.paletteId)
	local paletteKey = options.paletteId
	local entries, layoutFound, invalid = loadLayout(direction)

	-- one direction in memory at a time unless asked otherwise; a palette change rebuilds all
	local keep: { [string]: boolean }? = nil
	if options.keepTemplates and templatePalette == paletteKey then
		keep = {}
		for name in templates do
			(keep :: { [string]: boolean })[name] = true
		end
	end
	Builder.clear(false)
	releaseTemplates(keep)
	if templatePalette ~= paletteKey then
		releaseTemplates(nil)
	end
	templatePalette = paletteKey

	local root = Instance.new("Folder")
	root.Name = Builder.ROOT
	root:SetAttribute("Direction", direction)
	root:SetAttribute("Palette", options.paletteId)
	root:SetAttribute("Note", "Lane 3 Downtown look-dev study (preview). Not game content.")
	root.Parent = Workspace
	local kitFolder = Instance.new("Folder")
	kitFolder.Name = "Kit"
	kitFolder.Parent = root
	local signFolder = Instance.new("Folder")
	signFolder.Name = "Signs"
	signFolder.Parent = root
	local missingFolder = Instance.new("Folder")
	missingFolder.Name = "Missing"
	missingFolder.Parent = root

	local kit = findFolder(KIT_FOLDER)
	if not kit then
		warn("[Lane3 Downtown] no " .. KIT_FOLDER .. " folder; every mesh will be a grey box")
	end

	local stats: Stats = {
		direction = direction,
		palette = options.paletteId,
		paletteMode = paletteMode,
		layoutFound = layoutFound,
		layoutEntries = #entries,
		invalidEntries = invalid,
		uniqueMeshes = 0,
		instances = 0,
		missing = 0,
		missingNames = {},
		totalTriangles = 0,
		uniqueTriangles = 0,
		editableMeshes = 0,
		estimatedEditableMB = 0,
		uploadedMeshes = 0,
		parts = 0,
		proxyParts = 0,
		signs = 0,
		transparentEffects = 0,
		transparentBreakdown = {},
		animatedObjects = 0,
		roadProxy = false,
		hazardFallbacks = {},
		buildSeconds = 0,
		lighting = applyLighting(),
	}
	local missingSeen: { [string]: boolean } = {}
	local present = { road = false, construction = false, pothole = false, oil = false }

	for index, entry in entries do
		local t = template(kit, entry.mesh, textureId, swatches, options.meshIds)
		local base = CFrame.new(entry.position) * CFrame.Angles(0, math.rad(entry.yaw * yawSign), 0)
		local data = t.data
		local placed: BasePart
		if t.part and data then
			local lo, hi = vec(data.bounds[1]) :: Vector3, vec(data.bounds[2]) :: Vector3
			local part = t.part:Clone()
			part.Size = (hi - lo) * entry.scale
			part.CFrame = base * CFrame.new((lo + hi) / 2 * entry.scale) * t.turn
			part.Parent = kitFolder
			placed = part
			stats.instances += 1
			stats.totalTriangles += data.triangles
			local l = lower(entry.mesh)
			-- a road piece: long, low and on the carriageway (name-agnostic)
			local size = part.Size
			if size.Y < 3 and math.max(size.X, size.Z) >= 20 and Fixture.onCarriageway(part.Position) then
				present.road = true
			end
			for groupName, patterns in Hazards.PATTERNS do
				if matchesAny(l, patterns) then
					(present :: any)[groupName] = true
				end
			end
		else
			local lo = data and vec(data.bounds[1]) or Vector3.new(-2, 0, -2)
			local hi = data and vec(data.bounds[2]) or Vector3.new(2, 4, 2)
			local box = Parts.block(
				missingFolder,
				"MISSING_" .. entry.mesh,
				((hi - lo) * entry.scale):Max(Vector3.new(0.2, 0.2, 0.2)),
				base * CFrame.new((lo + hi) / 2 * entry.scale),
				Color3.fromRGB(150, 150, 156)
			)
			box:SetAttribute("Missing", t.source)
			Parts.label(box, "MISSING " .. entry.mesh, (hi.Y - lo.Y) * entry.scale.Y / 2 + 1.5)
			placed = box
			stats.missing += 1
			if not missingSeen[entry.mesh] then
				missingSeen[entry.mesh] = true
				table.insert(stats.missingNames, entry.mesh .. " (" .. t.source .. ")")
			end
		end
		placed:SetAttribute("Mesh", entry.mesh)
		if entry.landmark then
			placed:SetAttribute("Landmark", true)
		end
		if entry.animated then
			placed:SetAttribute("Lane3Animated", true)
			stats.animatedObjects += 1
		end
		if data and type(data.meta.rail_top) == "number" then
			placed:SetAttribute("RailTop", entry.position.Y + data.meta.rail_top * entry.scale.Y)
		elseif data and type(data.meta.railTop) == "number" then
			placed:SetAttribute("RailTop", entry.position.Y + data.meta.railTop * entry.scale.Y)
		end
		if entry.sign then
			stats.signs += makeSigns(signFolder, entry.sign, base, data, entry.scale)
		end
		if index % YIELD_EVERY == 0 then
			task.wait()
		end
	end

	-- proxies for whatever the layout does not provide
	local roadMode = options.roadProxy or "auto"
	if roadMode == "always" or (roadMode == "auto" and not present.road) then
		local _, count = Road.build(root)
		stats.roadProxy = true
		stats.proxyParts += count
	end
	if options.hazardFallbacks ~= false then
		local hazardFolder = Instance.new("Folder")
		hazardFolder.Name = "HazardFallbacks"
		hazardFolder.Parent = root
		stats.hazardFallbacks = Hazards.build(hazardFolder, {
			construction = not present.construction,
			pothole = not present.pothole,
			oil = not present.oil,
		})
		for _, d in hazardFolder:GetDescendants() do
			if d:IsA("BasePart") then
				stats.proxyParts += 1
			end
		end
	end

	for name, t in templates do
		if t.part and t.data then
			stats.uniqueMeshes += 1
			stats.uniqueTriangles += t.data.triangles
			if t.source == "uploaded" then
				stats.uploadedMeshes += 1
			end
		end
		if editables[name] then
			stats.editableMeshes += 1
		end
	end
	-- rough: about 120 bytes per preview triangle (vertex, face, normal and UV records)
	stats.estimatedEditableMB = math.floor(stats.uniqueTriangles * 120 / 1e4 + 0.5) / 100
	local parts, transparent, breakdown = countEffects(root)
	stats.parts = parts
	stats.transparentEffects = transparent
	stats.transparentBreakdown = breakdown
	stats.buildSeconds = math.floor((os.clock() - started) * 100 + 0.5) / 100
	root:SetAttribute("BuildSeconds", stats.buildSeconds)
	return stats
end

-- Where each cached template came from ("uploaded", "preview", "missing: ...").
function Builder.sources(): { [string]: string }
	local out = {}
	for name, t in templates do
		out[name] = t.source
	end
	return out
end

return Builder
