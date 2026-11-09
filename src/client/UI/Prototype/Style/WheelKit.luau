--!strict
-- WheelKit (Lane 3 Round 8, W-02 and W-03): fits the sixteen real 3D rim designs on any car. Adam: "the rims are still not
-- showing up in the preview ... They look absolutely horrible ... Everything with the wheels needs to be changed".
--
-- What it does: hides the car's own wheels, then at each of the four hubs puts one shared tyre mesh (black rubber) and the design's
-- rim mesh, plus its Neon glow layer (a slow pulse) or drifting stars where the design has them. The rim is stretched to the car's
-- own tyre (radius and width measured from the real model in Anchors/Wheels.luau), sits flush with the tyre's outer face, looks
-- OUT of the car on both sides (the left hubs are turned half a turn) and turns with the wheel.
--
--   local h = WheelKit.fit(model, wheelsItemId?, anchors?, options?) -> Handle
--       wheelsItemId: a Wheels id in CosmeticPreviewCatalog (old Round 7 ids still work). nil or "stock_five": nothing is
--       changed, the car keeps its own wheels (the handle is a no-op). anchors: defaults to Anchors.Wheels for the car (the
--       Normal name; Gold, Diamond and Rainbow editions share it), else the model's own wheel parts are measured.
--   h:spin(rad)      ADDS rad to how far the wheels have rolled (positive = the car rolling forward, like RealCar's spin)
--   h:setSpin(rad)   sets the roll angle outright (turntables and the Raceway can pass a running total)
--   h:set(id?)       changes the design on the same car; h:destroy() gives the car's own wheels back and removes everything
--   options.lod = "low": tyre and rim only, no glow layer, stars or pulse (tiles, ghosts, Raceway lineups). options.reduceMotion: no pulse or drift (also follows
--   GuiService.ReducedMotionEnabled and the LocalPlayer attribute "Lane3ReducedMotionOverride").
--
--   WheelKit.preload(ids?) -> Promise     loads the mesh templates (all designs, or the listed Wheels ids); fit() works before
--                                         they arrive (plain-part fallback), then swaps to the real meshes
--   WheelKit.hub(model, index, anchors?) -> Hub?   { cframe (world, +X out of the car), radius, width } of one hub (1 front
--                                         left, 2 front right, 3 rear left, 4 rear right): the Style Shop wheel cam looks here
--   WheelKit.designOf(id) / WheelKit.anchorsFor(model) / WheelKit.meshesReady(id) / WheelKit.VertexColours
--
-- Meshes: AssetIds.Wheels keys (uploaded by the lead; before that, in Studio with ReplicatedStorage.Lane3_LocalArt, the local
-- .mesh files in content/carhop/r8). MeshParts are made with AssetService:CreateMeshPartAsync once per mesh and cloned.

local AssetService = game:GetService("AssetService")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Catalog = require(ReplicatedStorage.Shared.UI.CosmeticPreviewCatalog)
local AssetIds = require(ReplicatedStorage.Shared.Style.AssetIds)
local AnchorTypes = require(ReplicatedStorage.Shared.Style.Anchors.Types)
local WheelAnchors = require(ReplicatedStorage.Shared.Style.Anchors.Wheels)
local Promise = require(ReplicatedStorage.Packages.Promise)
local Trove = require(ReplicatedStorage.Packages.Trove)
local Designs = require(script.Parent.WheelDesigns)

local WheelKit = {}

-- true: the meshes carry their colours as vertex colours and the parts are left white; false (if an import ever drops them):
-- every rim part takes the design's own rimColor
WheelKit.VertexColours = true

export type Wheels = AnchorTypes.Wheels
export type Options = { lod: ("full" | "low")?, reduceMotion: boolean? }
export type Hub = { cframe: CFrame, radius: number, width: number }

type Piece = { part: BasePart, offset: CFrame, role: string, base: Color3? }
type Wheel = { hub: CFrame, sign: number, pieces: { Piece } }

export type Handle = {
	model: Model,
	design: string?,
	spin: (self: Handle, rad: number) -> (),
	setSpin: (self: Handle, rad: number) -> (),
	set: (self: Handle, wheelsItemId: string?) -> (),
	destroy: (self: Handle) -> (),
}

local HALF_W = Designs.HALF_WIDTH
local TYRE_KEY = Designs.TYRE
local RUBBER = Color3.fromRGB(26, 26, 30)
local OVERRIDE = "Lane3ReducedMotionOverride"
-- the importer turns an FBX half a turn about Y (found in Studio 2026-11-08: the rim face looked into the car): turn it back
local MESH_TURN = CFrame.Angles(0, math.pi, 0)
local TICK = 1 / 20 -- the pulse and the drift are slow: twenty updates a second is plenty

-- Mesh templates ---------------------------------------------------------------------------------------------------------------

local templates: { [string]: MeshPart } = {}
local loading: { [string]: any } = {}
local failed: { [string]: boolean } = {}

local function localArt(): boolean
	return RunService:IsStudio() and ReplicatedStorage:FindFirstChild("Lane3_LocalArt") ~= nil
end

local function contentFor(key: string): Content?
	local entry = AssetIds.entry(key)
	if entry == nil then
		return nil
	end
	if AssetIds.UseUploaded and entry.id then
		return Content.fromUri("rbxassetid://" .. tostring(entry.id))
	end
	if localArt() then
		return Content.fromUri("rbxasset://carhop/r8/" .. key .. ".mesh")
	end
	return nil
end

local function load(key: string): any
	local known = loading[key]
	if known then
		return known
	end
	local p = Promise.new(function(resolve, reject)
		local content = contentFor(key)
		if content == nil then
			failed[key] = true
			reject("no mesh for " .. key)
			return
		end
		local ok, result = pcall(function()
			return AssetService:CreateMeshPartAsync(content)
		end)
		if ok then
			templates[key] = result
			resolve(result)
		else
			failed[key] = true
			reject(tostring(result))
		end
	end)
	p:catch(function() end) -- a failed mesh is not an error: the fit falls back to plain parts
	loading[key] = p
	return p
end

local function keysOf(design: Designs.Design): { string }
	local keys = { TYRE_KEY, design.rim }
	if design.glow then
		table.insert(keys, design.glow)
	end
	if design.stars then
		table.insert(keys, design.stars)
	end
	return keys
end

local function allLoaded(design: Designs.Design): boolean
	for _, key in keysOf(design) do
		if templates[key] == nil then
			return false
		end
	end
	return true
end

-- Catalog helpers ---------------------------------------------------------------------------------------------------------------

function WheelKit.designOf(wheelsItemId: string?): Designs.Design?
	if wheelsItemId == nil or wheelsItemId == "" then
		return nil
	end
	local item = Catalog.byId("Wheels", wheelsItemId)
	if item == nil or item.design == nil then
		return nil
	end
	return Designs.designs[item.design]
end

function WheelKit.meshesReady(wheelsItemId: string?): boolean
	local design = WheelKit.designOf(wheelsItemId)
	return design ~= nil and allLoaded(design)
end

function WheelKit.preload(ids: { string }?): any
	local waits = {}
	local wanted: { [string]: boolean } = { [TYRE_KEY] = true }
	if ids then
		for _, id in ids do
			local design = WheelKit.designOf(id)
			if design then
				for _, key in keysOf(design) do
					wanted[key] = true
				end
			end
		end
	else
		for _, design in Designs.designs do
			for _, key in keysOf(design) do
				wanted[key] = true
			end
		end
	end
	for key in wanted do
		table.insert(waits, load(key))
	end
	return Promise.allSettled(waits)
end

-- Anchors -----------------------------------------------------------------------------------------------------------------------

local function baseName(name: string): string
	return (name:gsub("^Gold ", ""):gsub("^Diamond ", ""):gsub("^Rainbow ", ""))
end

-- No table entry: measure the model's own wheel parts (four BasePart descendants with "wheel" in the name).
local function measure(model: Model): Wheels?
	local pivot = model:GetPivot()
	local found: { { at: Vector3, part: BasePart } } = {}
	for _, d in model:GetDescendants() do
		if
			d:IsA("BasePart")
			and string.find(string.lower(d.Name), "wheel", 1, true)
			and d:GetAttribute("R8WheelKit") == nil
		then
			table.insert(found, { at = pivot:PointToObjectSpace(d.Position), part = d })
		end
	end
	if #found ~= 4 then
		return nil
	end
	table.sort(found, function(a, b)
		if math.abs(a.at.Z - b.at.Z) > 0.5 then
			return a.at.Z < b.at.Z
		end
		return a.at.X < b.at.X
	end)
	local hubs: { CFrame } = {}
	local names: { string } = {}
	local radius, width = 0, 0
	-- found is front-left, front-right, rear-left, rear-right (front is -Z, left is -X)
	for _, w in found do
		local left = w.at.X < 0
		table.insert(hubs, CFrame.new(w.at) * (if left then CFrame.Angles(0, math.pi, 0) else CFrame.identity))
		table.insert(names, w.part.Name)
		local s = w.part.Size
		local dims = { s.X, s.Y, s.Z }
		table.sort(dims)
		width += dims[1]
		radius += dims[3] / 2
	end
	return { hubs = hubs, radius = radius / 4, width = width / 4, hideParts = names }
end

function WheelKit.anchorsFor(model: Model): Wheels?
	return WheelAnchors[model.Name] or WheelAnchors[baseName(model.Name)]
end

-- How much bigger (or smaller) the model is than when the anchors were measured: the model's own wheels against the table.
local function scaleOf(model: Model, anchors: Wheels): number
	local total, n = 0, 0
	for _, name in anchors.hideParts or {} do
		local p = model:FindFirstChild(name, true)
		if p and p:IsA("BasePart") then
			total += p.Size.Y
			n += 1
		end
	end
	if n == 0 or anchors.radius <= 0 then
		return 1
	end
	return (total / n) / (2 * anchors.radius)
end

local function resolveAnchors(model: Model, given: Wheels?): (Wheels?, number)
	if given then
		return given, scaleOf(model, given)
	end
	local table_ = WheelKit.anchorsFor(model)
	if table_ then
		return table_, scaleOf(model, table_)
	end
	return measure(model), 1
end

function WheelKit.hub(model: Model, index: number, anchors: Wheels?): Hub?
	local a, f = resolveAnchors(model, anchors)
	if a == nil or a.hubs[index] == nil then
		return nil
	end
	local hub = a.hubs[index]
	local scaled = CFrame.new(hub.Position * f) * hub.Rotation
	return { cframe = model:GetPivot() * scaled, radius = a.radius * f, width = a.width * f }
end

-- Reduced motion and the animator ------------------------------------------------------------------------------------------------

local function reducedMotion(forced: boolean?): boolean
	if forced then
		return true
	end
	local lp = Players.LocalPlayer
	if lp then
		local override = lp:GetAttribute(OVERRIDE)
		if type(override) == "boolean" then
			return override
		end
	end
	return GuiService.ReducedMotionEnabled
end

local Fit = {}
Fit.__index = Fit

local active: { [any]: boolean } = {}
local beat: RBXScriptConnection? = nil
local lastTick = 0

local function stepAll()
	local now = os.clock()
	if now - lastTick < TICK then
		return
	end
	lastTick = now
	for fit in active do
		(fit :: any):_animate(now)
	end
end

local function register(fit: any)
	active[fit] = true
	if beat == nil then
		beat = RunService.Heartbeat:Connect(stepAll)
	end
end

local function unregister(fit: any)
	active[fit] = nil
	if beat and next(active) == nil then
		beat:Disconnect()
		beat = nil
	end
end

-- Building -----------------------------------------------------------------------------------------------------------------------

local function plain(name: string, size: Vector3, colour: Color3, material: Enum.Material): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Massless = true
	p.Size = size
	p.Color = colour
	p.Material = material
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p:SetAttribute("R8WheelKit", true)
	return p
end

local function cylinder(name: string, length: number, diameter: number, colour: Color3, material: Enum.Material): Part
	local p = plain(name, Vector3.new(length, diameter, diameter), colour, material)
	p.Shape = Enum.PartType.Cylinder -- a cylinder's axle is its X axis
	return p
end

local function meshPiece(key: string, name: string, size: Vector3, colour: Color3, material: Enum.Material): MeshPart
	local p = (templates[key] :: MeshPart):Clone()
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Massless = true
	p.Size = size
	p.Color = colour
	p.Material = material
	p:SetAttribute("R8WheelKit", true)
	return p
end

-- A mesh made in the authoring frame (tyre radius 1) stretched to this car's tyre: `tyreFrame` meshes also follow the tyre's
-- width; rim-frame meshes only the radius, with their front plane moved to the car's outer tyre face.
local function boxFor(key: string, r: number, halfW: number, tyreFrame: boolean): (Vector3, Vector3)
	local b = Designs.BBOX[key]
	if b == nil then
		return Vector3.new(0.88 * r, 2 * r, 2 * r), Vector3.zero
	end
	local xs = if tyreFrame then halfW / HALF_W else r
	local size = Vector3.new((b[2] - b[1]) * xs, (b[4] - b[3]) * r, (b[6] - b[5]) * r)
	local shift = if tyreFrame then 0 else halfW - HALF_W * r
	local centre = Vector3.new((b[1] + b[2]) / 2 * xs + shift, (b[3] + b[4]) / 2 * r, (b[5] + b[6]) / 2 * r)
	return size, centre
end

local function addPiece(w: Wheel, folder: Folder, part: BasePart, offset: CFrame, role: string, base: Color3?)
	part.Parent = folder
	table.insert(w.pieces, { part = part, offset = offset, role = role, base = base })
end

local function buildMeshWheel(w: Wheel, folder: Folder, design: Designs.Design, r: number, width: number, low: boolean)
	local halfW = width / 2
	local vc = WheelKit.VertexColours
	-- the shared tyre: its box is exactly the car's tyre (width x diameter x diameter), centred on the hub
	local tyreSize = Vector3.new(width, 2 * r, 2 * r)
	local tyreColour = if vc then Color3.new(1, 1, 1) else RUBBER
	addPiece(
		w,
		folder,
		meshPiece(TYRE_KEY, "Tyre", tyreSize, tyreColour, Enum.Material.SmoothPlastic),
		CFrame.identity,
		"tyre"
	)
	local size, centre = boxFor(design.rim, r, halfW, false)
	local rimColour = if vc then Color3.new(1, 1, 1) else design.rimColor
	local rim = meshPiece(design.rim, "Rim", size, rimColour, design.material)
	rim.Reflectance = design.reflectance
	addPiece(w, folder, rim, CFrame.new(centre) * MESH_TURN, "rim")
	local glowColour = design.glowColor or Color3.new(1, 1, 1)
	if design.glow and not low then
		local tyreFrame = design.glowFrame == "tyre"
		local gs, gc = boxFor(design.glow, r, halfW, tyreFrame)
		local g = meshPiece(design.glow, "Glow", gs, if vc then Color3.new(1, 1, 1) else glowColour, Enum.Material.Neon)
		addPiece(w, folder, g, CFrame.new(gc) * MESH_TURN, "glow", g.Color)
	end
	if design.stars and not low then
		local ss, sc = boxFor(design.stars, r, halfW, false)
		local s =
			meshPiece(design.stars, "Stars", ss, if vc then Color3.new(1, 1, 1) else glowColour, Enum.Material.Neon)
		addPiece(w, folder, s, CFrame.new(sc) * MESH_TURN, "stars", s.Color)
	end
end

-- The plain-part version, used while a mesh is not uploaded yet or failed to load.
local function buildFallbackWheel(w: Wheel, folder: Folder, design: Designs.Design, r: number, width: number)
	local f = design.fallback
	local halfW = width / 2
	local glow = design.glowColor or Color3.fromRGB(30, 235, 255)
	local function put(part: BasePart, x: number, role: string?, base: Color3?)
		addPiece(w, folder, part, CFrame.new(x, 0, 0), role or "flat", base)
	end
	put(cylinder("Tyre", width, 2 * r, RUBBER, Enum.Material.SmoothPlastic), 0, "tyre")
	if f.whiteWall then
		put(
			cylinder("WhiteWall", 0.02 * r, 1.88 * r, Color3.fromRGB(246, 246, 240), Enum.Material.SmoothPlastic),
			halfW + 0.002 * r
		)
		put(cylinder("WhiteWallIn", 0.02 * r, 1.46 * r, RUBBER, Enum.Material.SmoothPlastic), halfW + 0.004 * r)
	end
	if f.stripe then
		put(cylinder("Stripe", 0.02 * r, 1.88 * r, f.stripe, Enum.Material.SmoothPlastic), halfW + 0.002 * r)
		put(cylinder("StripeIn", 0.02 * r, 1.72 * r, RUBBER, Enum.Material.SmoothPlastic), halfW + 0.004 * r)
	end
	if f.glowTread then
		for _, side in { -1, 1 } do
			local band = cylinder("GlowTread", 0.07 * width, 2.02 * r, glow, Enum.Material.Neon)
			put(band, side * 0.25 * width, "glow", glow)
		end
	end
	local rimFace = halfW - 0.015 * r
	put(cylinder("Lip", 0.05 * r, 1.4 * r, f.rim, design.material), rimFace - 0.02 * r)
	local discColour = f.disc or RUBBER
	put(
		cylinder(
			"Face",
			0.05 * r,
			1.22 * r,
			discColour,
			if f.solidFace then design.material else Enum.Material.SmoothPlastic
		),
		rimFace - 0.045 * r
	)
	if f.glowRing then
		put(cylinder("GlowRing", 0.03 * r, 1.2 * r, glow, Enum.Material.Neon), rimFace - 0.03 * r, "glow", glow)
		put(cylinder("GlowRingIn", 0.03 * r, 1.04 * r, discColour, Enum.Material.SmoothPlastic), rimFace - 0.022 * r)
	end
	for k = 1, f.spokes do
		local spoke = plain(
			"Spoke",
			Vector3.new(0.05 * r, 0.56 * r, f.spokeWidth * r),
			f.spoke,
			if f.neonSpokes then Enum.Material.Neon else design.material
		)
		-- x in front of the face, 0.36 r out along the rotated Y axis
		local offset = CFrame.Angles(2 * math.pi * k / f.spokes, 0, 0) * CFrame.new(rimFace - 0.06 * r, 0.36 * r, 0)
		addPiece(
			w,
			folder,
			spoke,
			offset,
			if f.neonSpokes then "glow" else "flat",
			if f.neonSpokes then f.spoke else nil
		)
	end
	if f.solidFace then
		put(cylinder("Dome", 0.05 * r, 1.0 * r, f.rim, design.material), rimFace - 0.04 * r)
	end
	put(
		cylinder("Hub", 0.09 * r, 0.34 * r, f.hub, if f.glowHub then Enum.Material.SmoothPlastic else design.material),
		rimFace - 0.03 * r
	)
	if f.glowHub then
		put(cylinder("GlowHub", 0.03 * r, 0.24 * r, glow, Enum.Material.Neon), rimFace + 0.02 * r, "glow", glow)
	end
end

-- The fit ------------------------------------------------------------------------------------------------------------------------

function Fit._hideOwn(self: any)
	local anchors: Wheels = self._anchors
	for _, name in anchors.hideParts or {} do
		local p = self._model:FindFirstChild(name, true)
		if p and p:IsA("BasePart") and self._hidden[p] == nil then
			self._hidden[p] = p.Transparency
			p.Transparency = 1
			p:SetAttribute("WheelKitHidden", true)
		end
	end
end

function Fit._showOwn(self: any)
	for p, t in self._hidden do
		if p.Parent then
			p.Transparency = t
			p:SetAttribute("WheelKitHidden", nil)
		end
	end
	table.clear(self._hidden)
end

function Fit._clear(self: any)
	if self._folder then
		self._folder:Destroy()
		self._folder = nil
	end
	self._wheels = {}
	unregister(self)
end

function Fit._place(self: any, w: Wheel)
	local base = self._model:GetPivot() * w.hub * CFrame.Angles(w.sign * self._roll, 0, 0)
	for _, piece in w.pieces do
		if piece.role == "stars" then
			piece.part.CFrame = base * CFrame.Angles(self._drift, 0, 0) * piece.offset
		else
			piece.part.CFrame = base * piece.offset
		end
	end
end

function Fit._placeAll(self: any)
	-- the model was scaled (ScaleTo) after the fit: its own wheels changed size, so measure again and rebuild
	local ref: BasePart? = self._ownRef
	if ref and math.abs(ref.Size.Y - self._ownY) > 0.002 * self._ownY then
		self._scale = scaleOf(self._model, self._anchors)
		self:_build()
		return
	end
	for _, w in self._wheels do
		self:_place(w)
	end
end

function Fit._build(self: any)
	self:_clear()
	local design: Designs.Design? = self._design
	local anchors: Wheels? = self._anchors
	if design == nil or anchors == nil then
		self:_showOwn()
		return
	end
	local f: number = self._scale
	local r, width = anchors.radius * f, anchors.width * f
	local folder = Instance.new("Folder")
	folder.Name = "R8Wheels"
	local useMesh = allLoaded(design)
	local wheels: { Wheel } = {}
	for i, hub in anchors.hubs do
		local scaled = CFrame.new(hub.Position * f) * hub.Rotation
		local w: Wheel = { hub = scaled, sign = if hub.XVector.X < 0 then 1 else -1, pieces = {} }
		if useMesh then
			buildMeshWheel(w, folder, design, r, width, self._lod == "low")
		else
			buildFallbackWheel(w, folder, design, r, width)
		end
		for _, piece in w.pieces do
			piece.part.Name = piece.part.Name .. i
		end
		table.insert(wheels, w)
	end
	self._wheels = wheels
	self._folder = folder
	self._ownRef = nil
	for _, name in anchors.hideParts or {} do
		local own = self._model:FindFirstChild(name, true)
		if own and own:IsA("BasePart") then
			self._ownRef = own
			self._ownY = own.Size.Y
			break
		end
	end
	self:_hideOwn()
	self:_placeAll()
	folder.Parent = self._model
	local animated = design.pulse ~= nil or design.drift ~= nil
	if animated and self._lod ~= "low" then
		register(self)
	end
	if not useMesh then
		-- ask for the real meshes, then swap once (the fallback is a stand-in until then)
		local mine = self._buildId
		local waits = {}
		for _, key in keysOf(design) do
			table.insert(waits, load(key))
		end
		Promise.all(waits)
			:andThen(function()
				if self._alive and self._buildId == mine and self._design == design then
					self:_build()
				end
			end)
			:catch(function() end)
	end
end

function Fit._animate(self: any, now: number)
	local design: Designs.Design? = self._design
	if design == nil then
		return
	end
	local calm = reducedMotion(self._reduce)
	local level = 1.0
	if design.pulse and not calm then
		if design.flicker then
			level = 0.72 + 0.28 * (0.5 + 0.5 * math.sin(now * 6.1)) * (0.75 + 0.25 * math.noise(now * 2.3, 1.7))
		else
			level = 0.55 + 0.45 * (0.5 - 0.5 * math.cos(now * 2 * math.pi / design.pulse))
		end
	end
	if self._level ~= level then
		self._level = level
		for _, w in self._wheels do
			for _, piece in w.pieces do
				if piece.role == "glow" and piece.base then
					piece.part.Color = piece.base:Lerp(Color3.new(0, 0, 0), 1 - level)
				end
			end
		end
	end
	if design.drift then
		local drift = if calm then 0 else now * design.drift
		if self._drift ~= drift then
			self._drift = drift
			self:_placeAll()
		end
	end
end

function Fit.spin(self: any, rad: number)
	self._roll += rad
	self:_placeAll()
end

function Fit.setSpin(self: any, rad: number)
	self._roll = rad
	self:_placeAll()
end

function Fit.set(self: any, wheelsItemId: string?)
	local design = WheelKit.designOf(wheelsItemId)
	if design and design.id == "stock_five" then
		design = nil
	end
	if design == self._design then
		return
	end
	self._design = design
	self.design = if design then design.id else nil
	self._buildId += 1
	self:_build()
end

function Fit.destroy(self: any)
	if not self._alive then
		return
	end
	self._alive = false
	self._trove:Destroy()
end

-- WheelKit.fit(model, wheelsItemId?, anchors?, options?) -> Handle (see the header)
function WheelKit.fit(model: Model, wheelsItemId: string?, anchors: Wheels?, options: Options?): Handle
	local opts = options or {}
	local design = WheelKit.designOf(wheelsItemId)
	if design and design.id == "stock_five" then
		design = nil
	end
	local a, f = resolveAnchors(model, anchors)
	local self = setmetatable({
		model = model,
		design = if design then design.id else nil,
		_model = model,
		_design = design,
		_anchors = a,
		_scale = f,
		_lod = opts.lod or "full",
		_reduce = opts.reduceMotion,
		_roll = 0,
		_drift = 0,
		_level = -1,
		_wheels = {},
		_ownRef = nil,
		_ownY = 1,
		_hidden = {},
		_buildId = 0,
		_alive = true,
		_trove = Trove.new(),
	}, Fit)
	local trove = self._trove
	trove:Add(function()
		self:_clear()
		self:_showOwn()
	end)
	trove:Connect(model.Destroying, function()
		self:destroy()
	end)
	if design and a then
		self:_build()
	end
	return (self :: any) :: Handle
end

return WheelKit
