--!strict
-- RealCar: Brian L's showroom cars on the Lane 3 screens (Style, launch card, Launch Pad, Car stall). A display copy only: the models
-- under ReplicatedStorage.Cars are never edited, and the car's Paint, Decal and Wheels are PREVIEW looks (nothing here is saved).
--
--   RealCar.list() -> { Entry }             the 27 Normal cars, Common first, then by name
--   local rig = RealCar.mount(parent, { length = number?, height = number? })
--   rig:setCar(name)  rig:pivotTo(cf)  rig:setPaint(item?, phase?)  rig:tick(phase)  rig:setDecal(item?)  rig:setWheels(item?)
--   rig:tail() -> CFrame                    the back of the car, +Z pointing away from it: where the trail starts
--   rig.source -> the car's name, "Supercar" or nil        rig:destroy()
--   RealCar.thumb(holder, name) -> ViewportFrame?          RealCar.isAnimated(item?) -> boolean
--
-- HOW IT DRAWS (Round 7, C-02 to C-06). Paint covers the body panels only (Style.BodyPaint: a drawn colour map on a copy of the
-- body, see-through over the windows, tyres, lights and chrome); a car with no paint mask falls back to the old see-through wash.
-- Decals are drawn by the game (Style.DecalArt) on both sides of the body. Wheels hide the car's own and put the game's tyre and
-- rim at each wheel, with the tyre styles on top, and can spin (rig:spin). Trails are layered effects from two exhaust points
-- (Style.TrailFx). "Factory Paint" and "Stock Five" leave the car as Brian L made it.
--
--   rig:setTrail(item?)   rig:spin(radians)   rig:clearTrail()   rig:setTrailSpeed(0..1)
--
-- Every car is scaled to one length so the turntable and the trail ribbon fit them all, and shrunk further to stay under `height`.
-- The Supercar stays as the fallback: it shows when ReplicatedStorage.Cars is empty or a car's meshes fail to load.

local ContentProvider = game:GetService("ContentProvider")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Prototype = script.Parent
local GameIconIds = require(Prototype.GameIconIds)
local Supercar = require(Prototype.Supercar)
local Catalog = require(ReplicatedStorage.Shared.UI.CosmeticPreviewCatalog)
local BodyPaint = require(Prototype.Style.BodyPaint)
local DecalArt = require(Prototype.Style.DecalArt)
local TrailFx = require(Prototype.Style.TrailFx)

local RealCar = {}

export type Entry = { name: string, rarity: string, model: Model }

local LENGTH = 12.6
local HEIGHT = 6
local WASH = 0.45
local WASH_GROW = 1.012
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

-- One World's cars for the Launch Pad (Round 4, E-05): the roster's nine (src/shared/UI/RosterFixtures), the Loaner first (always
-- available), then the cars the player owns, then the rest; roster order inside each group. `owned` reads the example collection
-- (Fixtures.PreviewCollection) until Brian L's saved Cars field reaches the client. Cars whose model is missing are left out.
export type WorldEntry = Entry & { owned: boolean, loaner: boolean }
function RealCar.forWorld(world: string): { WorldEntry }
	local RosterFixtures = require(ReplicatedStorage.Shared.UI.RosterFixtures) :: any
	local Fixtures = require(Prototype.Fixtures) :: any
	local byName: { [string]: Entry } = {}
	for _, e in RealCar.list() do
		byName[e.name] = e
	end
	local groups: { { WorldEntry } } = { {}, {}, {} }
	for _, car in RosterFixtures.inWorld(world) do
		local entry = byName[car.model]
		if entry then
			local owned = car.loaner or Fixtures.PreviewCollection[car.id] ~= nil
			local item: WorldEntry =
				{ name = entry.name, rarity = car.rarity, model = entry.model, owned = owned, loaner = car.loaner }
			table.insert(groups[if car.loaner then 1 elseif owned then 2 else 3], item)
		end
	end
	local out: { WorldEntry } = {}
	for _, g in groups do
		table.move(g, 1, #g, #out + 1, out)
	end
	return out
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

-- In the built place a model's pivot sits at its middle, and some are not turned along the car, so a display copy finds its own
-- from its wheels: bottom centre, front toward -Z. Returns the car's size along those axes.
local function squareUp(model: Model, wheels: { BasePart }): Vector3
	local front, rear = Vector3.zero, Vector3.zero
	for _, wheel in wheels do
		if string.find(wheel.Name, "front", 1, true) then
			front += wheel.Position
		else
			rear += wheel.Position
		end
	end
	local forward = ((front - rear) * Vector3.new(1, 0, 1)).Unit
	local right = forward:Cross(Vector3.yAxis)
	model.WorldPivot = CFrame.fromMatrix(model:GetPivot().Position, right, Vector3.yAxis)
	local cf, size = model:GetBoundingBox()
	model.WorldPivot = CFrame.fromMatrix(cf.Position - Vector3.yAxis * size.Y / 2, right, Vector3.yAxis)
	return size
end

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
	local size = squareUp(model, wheels)
	local fit = math.min(length / size.Z, height / size.Y)
	model:ScaleTo(model:GetScale() * fit)
	local self = setmetatable(
		{
			model = model,
			halfLength = size.Z * fit / 2,
			tailHeight = size.Y * fit * 0.32,
			_wheels = wheels,
			_rims = {},
			_rimMeshes = {},
			_name = entry.name,
			_width = size.X * fit,
		} :: any,
		Body
	)
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
		if self._painter then
			self._painter:set(nil)
			self:setDecal(self._decalItem)
		end
		return
	end
	-- Round 7 (C-02): body panels only, when this car has a paint mask
	if self._painter == nil and BodyPaint.supported(self._name) then
		self._painter = BodyPaint.new(self._body, self._name) or false
	end
	if self._painter then
		self._wash.Transparency = 1
		self._painter:set(item)
		self:setDecal(self._decalItem)
		return
	end
	self._wash.Transparency = WASH
	self._wash.Color = item.colours[1]
	self:tick(phase or 0.18)
end

-- Decals sit on the paint when the car is painted (the paint covers the body), else on the body itself.
function Body.setDecal(self: any, item: Catalog.Item?)
	self._decalItem = item
	local painter = self._painter
	local target = if painter and painter._shell.Parent then painter._shell else self._body
	if self._decals and self._decalTarget ~= target then
		self._decals:destroy()
		self._decals = nil
	end
	if not self._decals then
		if not item or item.isNone then
			return
		end
		self._decals = DecalArt.attach(target, self.model)
		self._decalTarget = target
	end
	self._decals:set(item)
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

-- Round 7 (C-05): the tyre styles on top of the rim: a white wall, a coloured stripe or a glowing tread (rings on the tyre), a
-- neon ring or a glowing hub in the rim, and chrome, gold or carbon finishes.
local function styleWheels(self: any, item: Catalog.Item)
	for _, extra in self._wheelExtras or {} do
		extra:Destroy()
	end
	self._wheelExtras = {}
	local style = item.kind :: any
	local pivot = self.model:GetPivot()
	for _, wheel in self._wheels do
		local at = pivot:PointToObjectSpace(wheel.Position)
		local d = math.max(wheel.Size.X, wheel.Size.Y, wheel.Size.Z)
		local axle = pivot * CFrame.new(at)
		local function ring(name: string, diameter: number, colour: Color3, material: Enum.Material, out: number)
			local r = Instance.new("Part")
			r.Name = name
			r.Shape = Enum.PartType.Cylinder
			r.Anchored = true
			r.CanCollide = false
			r.CanQuery = false
			r.CanTouch = false
			r.Size = Vector3.new(0.06, diameter, diameter)
			r.CFrame = axle * CFrame.new(math.sign(at.X) * out, 0, 0)
			r.Color = colour
			r.Material = material
			r.Parent = self.model
			table.insert(self._wheelExtras, r)
			table.insert(self._rims, r)
		end
		local outside = d * 0.26
		if style == "whitewall" then
			ring("WhiteWall", d * 0.82, Color3.fromRGB(245, 245, 240), Enum.Material.SmoothPlastic, outside)
			ring("WhiteWallIn", d * 0.62, Color3.fromRGB(20, 20, 24), Enum.Material.SmoothPlastic, outside + 0.01)
		elseif style == "stripe" then
			ring("TyreStripe", d * 0.88, item.colours[2], Enum.Material.SmoothPlastic, outside)
			ring("TyreStripeIn", d * 0.8, Color3.fromRGB(20, 20, 24), Enum.Material.SmoothPlastic, outside + 0.01)
		elseif style == "neonring" then
			ring("NeonRing", d * 0.58, item.colours[2], Enum.Material.Neon, outside + 0.02)
			ring("NeonRingIn", d * 0.5, Color3.fromRGB(30, 34, 46), Enum.Material.SmoothPlastic, outside + 0.03)
		elseif style == "glowhub" then
			ring("GlowTread", d * 1.02, item.colours[2], Enum.Material.Neon, 0)
			ring("GlowHub", d * 0.22, item.colours[2], Enum.Material.Neon, outside + 0.04)
		end
	end
end

function Body.setWheels(self: any, item: Catalog.Item?)
	local key = item and item.key or "five"
	local own = key == "five" and (not item or item.kind == nil)
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
	local style = item.kind :: any
	local colour = item.colours[1]
	for _, r in self._rimMeshes do
		r.mesh.MeshId = meshUri("car_rim_" .. key)
		r.part.Color = colour
		r.part.Material = if style == "carbon" then Enum.Material.Slate else Enum.Material.Metal
		r.part.Reflectance = if style == "chrome" or style == "gold" then 0.45 else 0
	end
	styleWheels(self, item)
end

-- Turns every wheel by `angle` (radians) about its axle: the run calls this with how far the car rolled.
function Body.spin(self: any, angle: number)
	local turn = CFrame.Angles(angle, 0, 0)
	for _, p in self._rims do
		if p.Transparency < 1 then
			p.CFrame *= turn
		end
	end
end

function Body.destroy(self: any)
	if self._painter then
		self._painter:destroy()
	end
	if self._trail then
		self._trail:destroy()
	end
	self.model:Destroy()
end

-- A plain display copy of a car in ReplicatedStorage.Cars by its model name (any edition: "Gold Putter"), for the collectible
-- cards (Round 4): anchored, nothing runs or sounds, pivot squared up from the wheels and placed at the origin with the front
-- toward -Z. No paint wash and no scaling (the card fits its camera). nil when the model is not there.
function RealCar.displayModel(name: string): Model?
	local folder = ReplicatedStorage:FindFirstChild("Cars")
	local source = folder and folder:FindFirstChild(name)
	if not (source and source:IsA("Model")) then
		return nil
	end
	local model = source:Clone()
	local wheels: { BasePart } = {}
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			if string.find(d.Name, "wheel", 1, true) then
				table.insert(wheels, d)
			end
		elseif d:IsA("Script") or d:IsA("LocalScript") or d:IsA("Sound") then
			d:Destroy()
		end
	end
	if #wheels >= 2 then
		squareUp(model, wheels)
	end
	model:PivotTo(CFrame.identity)
	return model
end

-- A still picture of a car for a card: no spin and no render loop. nil when the car is not here, so the caller keeps its own art.
function RealCar.thumb(holder: Frame, name: string?): ViewportFrame?
	local entry = find(name)
	if not entry or failed[entry.name] then
		return nil
	end
	local vp = Instance.new("ViewportFrame")
	vp.Name = "CarThumb"
	vp.BackgroundTransparency = 1
	vp.Size = UDim2.fromScale(1, 1)
	vp.Ambient = Color3.fromRGB(170, 172, 186)
	vp.LightColor = Color3.fromRGB(255, 250, 240)
	vp.LightDirection = Vector3.new(-0.6, -1, -0.5)
	vp.ZIndex = holder.ZIndex + 1
	local camera = Instance.new("Camera")
	camera.FieldOfView = 22
	camera.CFrame = CFrame.lookAt(Vector3.new(0, 7.4, 31), Vector3.new(0, 2.2, 0))
	camera.Parent = vp
	vp.CurrentCamera = camera
	local model = buildBody(entry, LENGTH, HEIGHT).model
	model:PivotTo(CFrame.Angles(0, math.rad(215), 0))
	model.Parent = vp
	vp.Parent = holder
	return vp
end

-- The Supercar, at a display size: its meshes scale, so the pieces move in to match.
local function buildSupercar(length: number): any
	if not Supercar.available() then
		return nil
	end
	local rig = Supercar.new() :: any
	local k = length / Supercar.Length
	rig.halfLength = math.min(length, Supercar.Length) / 2
	rig.tailHeight = 1.1
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
		if self._trailItem then
			self:setTrail(self._trailItem)
		end
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

function Mount.tail(self: any): CFrame
	local body = self._body
	-- the car's own pivot (a run moves the car's parent, so the last pivotTo can be far behind)
	local at = if body then body.model:GetPivot() else self._cf
	return at * CFrame.new(0, if body then body.tailHeight else 1, if body then body.halfLength else 6)
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

-- Round 7 (C-06): the trail from the car's two exhaust points (nil or "No trail" removes it).
function Mount.setTrail(self: any, item: Catalog.Item?)
	self._trailItem = item
	local body = self._body
	if not body or not body._body then
		return
	end
	if not body._trail then
		if not item or item.isNone then
			return
		end
		body._trail = TrailFx.attach(body._body, self:tail(), body._width or 5)
	end
	body._trail:set(item)
end

function Mount.clearTrail(self: any)
	local body = self._body
	if body and body._trail then
		body._trail:clear()
	end
end

function Mount.setTrailSpeed(self: any, speed: number)
	local body = self._body
	if body and body._trail then
		body._trail:setSpeed(speed)
	end
end

function Mount.spin(self: any, angle: number)
	local body = self._body
	if body and body.spin then
		body:spin(angle)
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
