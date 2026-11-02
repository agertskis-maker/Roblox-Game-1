--!strict
-- RealCar: Brian L's showroom cars on the Lane 3 screens (Style, launch card, Launch Pad, Car stall). A display copy only: the models
-- under ReplicatedStorage.Cars are never edited, and the car's Paint, Decal and Wheels are PREVIEW looks (nothing here is saved).
--
--   RealCar.list() -> { Entry }             the 27 Normal cars, Common first, then by name
--   local rig = RealCar.mount(parent, { length = number?, height = number? })
--   rig:setCar(name)  rig:pivotTo(cf)  rig:setPaint(item?, phase?)  rig:tick(phase)  rig:setDecal(item?)  rig:setWheels(item?)
--   rig.source -> the car's name, "Supercar" or nil        rig:destroy()
--   RealCar.isAnimated(item?) -> boolean
--
-- HOW IT DRAWS. The cars' textures are baked per car, so the Supercar's shells cannot map onto them. Paint is a see-through coloured
-- copy of the body, which keeps the car's detail (it tints the glass too); pattern paints show their first colour. Decals are real
-- Decals on the two sides of a second, invisible copy, so paint does not tint them. Wheels hide the car's own and put the game's tyre
-- and rim at each wheel. "Factory Paint" and "Stock Five" leave the car as Brian L made it.
--
-- Every car is scaled to one length so the turntable and the trail ribbon fit them all, and shrunk further to stay under `height`.
-- The Supercar stays as the fallback: it shows when ReplicatedStorage.Cars is empty or a car's meshes fail to load.

local ContentProvider = game:GetService("ContentProvider")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Prototype = script.Parent
local GameIconIds = require(Prototype.GameIconIds)
local GameIcons = require(Prototype.GameIcons)
local Supercar = require(Prototype.Supercar)
local Catalog = require(ReplicatedStorage.Shared.UI.CosmeticPreviewCatalog)

local RealCar = {}

export type Entry = { name: string, rarity: string, model: Model }

local LENGTH = 12.6
local HEIGHT = 6
local WASH = 0.45
local WASH_GROW = 1.012
local DECAL_GROW = 1.02
local TYRE_DIAMETER = 2.04 -- the game's tyre mesh, at scale 1
local RARITY_ORDER: { [string]: number } = { COMMON = 1, UNCOMMON = 2, RARE = 3, EPIC = 4, LEGENDARY = 5 }
local RARITY_NAME: { [string]: string } =
	{ COMMON = "Common", UNCOMMON = "Uncommon", RARE = "Rare", EPIC = "Epic", LEGENDARY = "Legendary" }

local failed: { [string]: boolean } = {}

function RealCar.list(): { Entry }
	local list: { Entry } = {}
	local folder = ReplicatedStorage:FindFirstChild("Cars")
	if folder then
		for _, c in folder:GetChildren() do
			if c:IsA("Model") and c:GetAttribute("Variant") == "Normal" then
				local rarity = c:GetAttribute("Rarity")
				table.insert(list, {
					name = c.Name,
					rarity = RARITY_NAME[rarity :: any] or "Common",
					model = c,
				})
			end
		end
	end
	local function rank(e: Entry): number
		return RARITY_ORDER[string.upper(e.rarity)] or 0
	end
	table.sort(list, function(a, b)
		if rank(a) ~= rank(b) then
			return rank(a) < rank(b)
		end
		return a.name < b.name
	end)
	return list
end

local function find(name: string?): Entry?
	local list = RealCar.list()
	for _, e in list do
		if e.name == name then
			return e
		end
	end
	return list[1]
end

function RealCar.isAnimated(item: Catalog.Item?): boolean
	return Supercar.isAnimated(item)
end

local function sample(colours: { Color3 }, t: number): Color3
	local n = #colours
	local f = (t % 1) * n
	local i = math.floor(f)
	return colours[(i % n) + 1]:Lerp(colours[((i + 1) % n) + 1], f - i)
end

-- The side faces of a body, worked out from its rotation: some bodies are turned inside the model.
local function sideFace(body: BasePart, pivot: CFrame, side: number): Enum.NormalId
	local v = body.CFrame:VectorToObjectSpace(pivot.RightVector * side)
	local best, score = Enum.NormalId.Right, -2
	for _, face in Enum.NormalId:GetEnumItems() do
		local s = Vector3.FromNormalId(face):Dot(v)
		if s > score then
			best, score = face, s
		end
	end
	return best
end

local function meshUri(key: string): string
	return GameIconIds[key] or ("rbxasset://carhop/" .. key .. ".mesh")
end

local function wheelPart(parent: Instance, name: string, mesh: string, scale: number, cf: CFrame): (Part, SpecialMesh)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Size = Vector3.one
	p.Material = Enum.Material.SmoothPlastic
	p.CFrame = cf
	local m = Instance.new("SpecialMesh")
	m.MeshType = Enum.MeshType.FileMesh
	m.MeshId = meshUri(mesh)
	m.Scale = Vector3.one * scale
	m.Parent = p
	p.Parent = parent
	return p, m
end

-- One car on show ---------------------------------------------------------------------------------------------------------------

local Body = {}
Body.__index = Body

local function buildBody(entry: Entry, length: number, height: number): any
	local model = entry.model:Clone()
	model.Name = "RealCar"
	local wheels: { BasePart } = {}
	local body: MeshPart? = nil
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			if d.Name == "body_geom" and d:IsA("MeshPart") then
				body = d
			elseif string.find(d.Name, "wheel", 1, true) then
				table.insert(wheels, d)
			end
		elseif not d:IsA("Model") then
			d:Destroy() -- a display copy: nothing runs, nothing sounds
		end
	end
	local _, size = model:GetBoundingBox()
	model:ScaleTo(math.min(length / math.max(size.X, size.Z), height / size.Y))
	local self = setmetatable({ model = model, _wheels = wheels, _rims = {}, _rimMeshes = {} } :: any, Body)
	self._body = assert(body, "a showroom car has no body_geom")
	local wash = self._body:Clone() :: MeshPart
	wash.Name = "PaintWash"
	wash.TextureID = ""
	wash.Material = Enum.Material.SmoothPlastic
	wash.Size = self._body.Size * WASH_GROW
	wash.CFrame = self._body.CFrame
	wash.Transparency = 1
	wash.Parent = model
	self._wash = wash
	return self
end

function Body.tick(self: any, phase: number)
	local item = self._paint
	if item and item.kind == "animated" then
		self._wash.Color = sample(item.colours, phase)
	end
end

function Body.setPaint(self: any, item: Catalog.Item?, phase: number?)
	self._paint = item
	if not item or item.id == "factory_paint" then
		self._wash.Transparency = 1
		return
	end
	self._wash.Transparency = WASH
	self._wash.Color = item.colours[1]
	self:tick(phase or 0.18)
end

function Body.setDecal(self: any, item: Catalog.Item?)
	local uri = item and item.key and GameIcons.uri("thumb_decal_" .. item.key)
	if not uri then
		if self._decals then
			self._decals.Parent = nil
		end
		return
	end
	if not self._decals then
		local layer = self._body:Clone() :: MeshPart
		layer.Name = "DecalLayer"
		layer.Transparency = 1
		layer.Size = self._body.Size * DECAL_GROW
		layer.CFrame = self._body.CFrame
		local pivot = self.model:GetPivot()
		self._decalSides = {}
		for _, side in { 1, -1 } do
			local d = Instance.new("Decal")
			d.Face = sideFace(self._body, pivot, side)
			d.Parent = layer
			table.insert(self._decalSides, d)
		end
		self._decals = layer
	end
	for _, d in self._decalSides do
		d.Texture = uri
	end
	self._decals.Parent = self.model
end

local function buildWheels(self: any)
	local pivot = self.model:GetPivot()
	for _, wheel in self._wheels do
		local at = pivot:PointToObjectSpace(wheel.Position)
		local cf = pivot * CFrame.new(at) * CFrame.Angles(0, if at.X > 0 then 0 else math.pi, 0)
		local scale = math.max(wheel.Size.X, wheel.Size.Y, wheel.Size.Z) / TYRE_DIAMETER
		local tyre = wheelPart(self.model, "Tyre", "car_tyre", scale, cf)
		tyre.Color = Color3.fromRGB(18, 18, 22)
		local rim, mesh = wheelPart(self.model, "Rim", "car_rim_five", scale, cf)
		table.insert(self._rims, tyre)
		table.insert(self._rims, rim)
		table.insert(self._rimMeshes, { part = rim, mesh = mesh })
	end
end

function Body.setWheels(self: any, item: Catalog.Item?)
	local key = item and item.key or "five"
	local own = key == "five"
	if not own and #self._rims == 0 then
		buildWheels(self)
	end
	for _, wheel in self._wheels do
		wheel.Transparency = if own then 0 else 1
	end
	for _, p in self._rims do
		p.Transparency = if own then 1 else 0
	end
	if own or not item then
		return
	end
	local glow = key == "ten"
	local colour = if glow then item.colours[3] else item.colours[1]
	for _, r in self._rimMeshes do
		r.mesh.MeshId = meshUri("car_rim_" .. key)
		r.part.Color = colour
		r.part.Material = if glow then Enum.Material.Neon else Enum.Material.Metal
	end
end

function Body.destroy(self: any)
	self.model:Destroy()
end

-- The Supercar, at a display size: its meshes scale, so the pieces move in to match.
local function buildSupercar(length: number): any
	if not Supercar.available() then
		return nil
	end
	local rig = Supercar.new()
	local k = length / Supercar.Length
	if k < 1 then
		local pivot = rig.model:GetPivot()
		for _, d in rig.model:GetDescendants() do
			if d:IsA("SpecialMesh") then
				d.Scale = Vector3.new(k, k, k)
			elseif d:IsA("BasePart") then
				local rel = pivot:ToObjectSpace(d.CFrame)
				d.CFrame = CFrame.new(pivot * (rel.Position * k)) * pivot.Rotation * rel.Rotation
			end
		end
	end
	return rig
end

-- The stage: holds one car, swaps it, and keeps the looks across a swap -----------------------------------------------------------

local Mount = {}
Mount.__index = Mount

export type Options = { length: number?, height: number? }

function RealCar.mount(parent: Instance, options: Options?): any
	local o: Options = options or {}
	return setmetatable(
		{
			source = nil,
			_parent = parent,
			_length = o.length or LENGTH,
			_height = o.height or HEIGHT,
			_cf = CFrame.identity,
			_body = nil,
			_serial = 0,
			_dead = false,
		} :: any,
		Mount
	)
end

local function show(self: any, body: any, source: string?)
	if self._body then
		self._body:destroy()
	end
	self._body = body
	self.source = source
	if body then
		body.model:PivotTo(self._cf)
		body:setPaint(self._paint, 0.18)
		body:setDecal(self._decal)
		body:setWheels(self._wheelsItem)
		body.model.Parent = self._parent
	end
end

local function watchLoad(self: any, name: string, serial: number)
	task.spawn(function()
		local bad = false
		pcall(function()
			ContentProvider:PreloadAsync({ self._body.model }, function(_id: string, status: Enum.AssetFetchStatus)
				if status == Enum.AssetFetchStatus.Failure then
					bad = true
				end
			end)
		end)
		if bad and not failed[name] then
			failed[name] = true
			warn("[RealCar] " .. name .. " did not load; showing the stand-in car")
		end
		if bad and not self._dead and self._serial == serial then
			show(self, buildSupercar(self._length), "Supercar")
		end
	end)
end

function Mount.setCar(self: any, name: string?)
	local entry = find(name)
	if entry and failed[entry.name] then
		entry = nil
	end
	local source = if entry then entry.name else "Supercar"
	if self.source == source then
		return
	end
	self._serial += 1
	if entry then
		show(self, buildBody(entry, self._length, self._height), source)
		watchLoad(self, source, self._serial)
	else
		local rig = buildSupercar(self._length)
		show(self, rig, if rig then source else nil)
	end
end

function Mount.pivotTo(self: any, cf: CFrame)
	self._cf = cf
	if self._body then
		self._body.model:PivotTo(cf)
	end
end

function Mount.setPaint(self: any, item: Catalog.Item?, phase: number?)
	self._paint = item
	if self._body then
		self._body:setPaint(item, phase)
	end
end

function Mount.tick(self: any, phase: number)
	if self._body then
		self._body:tick(phase)
	end
end

function Mount.setDecal(self: any, item: Catalog.Item?)
	self._decal = item
	if self._body then
		self._body:setDecal(item)
	end
end

function Mount.setWheels(self: any, item: Catalog.Item?)
	self._wheelsItem = item
	if self._body then
		self._body:setWheels(item)
	end
end

function Mount.destroy(self: any)
	self._dead = true
	if self._body then
		self._body:destroy()
		self._body = nil
	end
end

return RealCar
