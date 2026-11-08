--!strict
-- RealCar: Brian L's showroom cars on the Lane 3 screens (Style, launch card, Launch Pad, Car stall). A display copy only: the models
-- under ReplicatedStorage.Cars are never edited, and the car's Paint, Decal and Wheels are PREVIEW looks (nothing here is saved).
--
--   RealCar.list() -> { Entry }             the 27 Normal cars, Common first, then by name
--   local rig = RealCar.mount(parent, { length = number?, height = number? })
--   rig:setCar(name)  rig:pivotTo(cf)  rig:setPaint(item?, phase?)  rig:tick(phase)  rig:setDecal(item?)  rig:setWheels(item?)
--   rig:tail() -> CFrame                    the back of the car, +Z pointing away from it: where the trail starts
--   rig:setLook(look)  rig:model()  rig:handle()   Round 8: a whole CarLook at once; the car's model; its CarLookApplier handle
--   RealCar.preload(name)                  loads a car's meshes ahead of the run
--   rig.source -> the car's name, "Supercar" or nil        rig:destroy()
--   RealCar.thumb(holder, name) -> ViewportFrame?          RealCar.isAnimated(item?) -> boolean
--
-- HOW IT DRAWS (Round 7, C-02 to C-06; Round 8 C-01: all of it is done by Style.CarLookApplier, which this file only calls).
-- Paint covers the body panels only (Style.BodyPaint: a drawn colour map on a copy of the
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
local Supercar = require(Prototype.Supercar)
local Catalog = require(ReplicatedStorage.Shared.UI.CosmeticPreviewCatalog)
local CarLook = require(ReplicatedStorage.Shared.Style.CarLook)
local CarLookApplier = require(Prototype.Style.CarLookApplier)
local LiveData = require(ReplicatedStorage.Shared.UI.LiveData)

local RealCar = {}

export type Entry = { name: string, rarity: string, model: Model }

local LENGTH = 12.6
local HEIGHT = 6
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
			-- the server's Cars attribute when there is one (the beta), else the example collection of the UI previews
			local owned = car.loaner
				or (
					if LiveData.hasCars()
						then LiveData.cars()[car.id] ~= nil
						else Fixtures.PreviewCollection[car.id] ~= nil
				)
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

-- Loads the meshes of a showroom car ahead of time (C-02: the car you start the run on must not pop in after the gantry lights).
-- Returns at once; the loading goes on in the background.
function RealCar.preload(name: string?)
	local folder = ReplicatedStorage:FindFirstChild("Cars")
	local source = name and folder and folder:FindFirstChild(name)
	if source then
		task.spawn(function()
			pcall(function()
				ContentProvider:PreloadAsync({ source })
			end)
		end)
	end
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

local function buildBody(entry: Entry, length: number, height: number, trail: boolean?): any
	local model = entry.model:Clone()
	model.Name = "RealCar"
	model:SetAttribute("CarName", entry.name) -- for the end-to-end look test and for debugging
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
			_name = entry.name,
			_width = size.X * fit,
			_spinTotal = 0,
		} :: any,
		Body
	)
	self._body = assert(body, "a showroom car has no body_geom")
	-- Round 8 (C-01): every look on this car goes through the one applier
	self._look = CarLookApplier.apply(model, CarLook.plain(entry.name), { trail = trail })
	return self
end

-- Paint, decals, wheels and the trail are the applier's (Style.CarLookApplier): one body of code for every screen (Round 8, C-01).
function Body.tick(self: any, phase: number)
	self._look:tick(phase)
end

function Body.setPaint(self: any, item: Catalog.Item?, phase: number?)
	self._look:setItem("Paint", item)
	if item and item.kind == "animated" then
		self._look:tick(phase or 0.18)
	end
end

function Body.setDecal(self: any, item: Catalog.Item?)
	self._look:setItem("Decals", item)
end

function Body.setWheels(self: any, item: Catalog.Item?)
	self._look:setItem("Wheels", item)
end

function Body.setTrail(self: any, item: Catalog.Item?)
	self._look:setItem("Trails", item)
end

-- Turns every wheel by `angle` (radians) about its axle: the run calls this with how far the car rolled.
function Body.spin(self: any, angle: number)
	self._spinTotal += angle
	self._look:setWheelSpin(self._spinTotal)
end

function Body.destroy(self: any)
	self._look:destroy()
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
function RealCar.thumb(holder: Frame, name: string?, look: CarLook.Look?): ViewportFrame?
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
	local body = buildBody(entry, LENGTH, HEIGHT, false)
	local model = body.model :: Model
	if look then
		-- the picture wears the look it is for (C-03's portrait, the shop tiles): no animated paint redraw, no trail
		body._look:update(CarLook.withCar(look, entry.name))
	end
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

-- Round 7 (C-06): the trail from the car's exhaust points (nil or "No trail" removes it). Round 8: built by the applier on the car's body.
function Mount.setTrail(self: any, item: Catalog.Item?)
	self._trailItem = item
	local body = self._body
	if body and body._look then
		body:setTrail(item)
	end
end

function Mount.clearTrail(self: any)
	local body = self._body
	if body and body._look then
		body._look:clearTrail()
	end
end

function Mount.setTrailSpeed(self: any, speed: number)
	local body = self._body
	if body and body._look then
		body._look:setTrailSpeed(speed)
	end
end

-- Round 8 (C-01): a whole look at once, from the ids a CarLook holds (the car itself is chosen with setCar).
function Mount.setLook(self: any, look: CarLook.Look)
	self:setPaint(if look.paint then Catalog.byId("Paint", look.paint) else nil)
	self:setDecal(if look.decal then Catalog.byId("Decals", look.decal) else nil)
	self:setWheels(if look.wheels then Catalog.byId("Wheels", look.wheels) else nil)
	self:setTrail(if look.trail then Catalog.byId("Trails", look.trail) else nil)
end

-- The car's own model (a RealCar clone) and the applier handle that dresses it; nil while the stand-in car shows.
function Mount.model(self: any): Model?
	local body = self._body
	return if body and body._look then body.model else nil
end

function Mount.handle(self: any): any?
	local body = self._body
	return if body then body._look else nil
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
