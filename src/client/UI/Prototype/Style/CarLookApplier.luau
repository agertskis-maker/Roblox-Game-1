--!strict
-- CarLookApplier (Lane 3 Round 8, C-01; API frozen by the lead in vault/design/specs/lane3-round8-contracts.md, body by WS-1):
-- puts a CarLook.Look on a car model, the same way everywhere (Style Shop turntable, shop tiles, launch card, Garage, Raceway racing
-- cars, parking ghosts, the run car). Wraps Style.BodyPaint (paint), Style.DecalArt (decal), Style.WheelKit (wheels, when that module
-- exists; else the stock-rim code below, moved here from RealCar) and Style.TrailFx (trail). Everything it creates is owned by the
-- handle's Trove and is removed on update() or destroy(); update() rebuilds only the tabs that changed.
--
--   local h = CarLookApplier.apply(model: Model, look: CarLook.Look, options: Options?) -> Handle
--   h:update(look)              re-dress (only the tabs that changed are rebuilt). A handle is per car: look.car is read once, at
--                               apply(); to dress another car, destroy this handle and apply() on that car (review N1)
--   h:setTrailSpeed(0..1)       T-03: 0 = standing / launch card, 1 = top run speed
--   h:burst(moment)             T-04: "leap" | "dive" | "catch" | "flare" (Style.TrailBursts when that module exists)
--   h:moveTrailTo(model)        C-02: the trail follows the player to the next car (paint, decal, wheels stay behind)
--   h:setWheelSpin(radians)     turntables and the Raceway; the run turns wheels itself (radians = total turn, not a step)
--   h:destroy()
--
-- Also (additive, used by RealCar and by callers that hold a catalog item rather than an id):
--   h:setItem(tab, item?)       dress one tab with a catalog item (an ad-hoc item is fine), nil = the car as it was made
--   h:tick(phase)               a colour-only paint on a car with no paint mask (the see-through wash) follows `phase`
--   h:tail() -> CFrame          the back of the model, +Z pointing away from it: where a trail starts
--   h:setTrailLevel(0..3)  h:flareTrail(seconds?)  h:getTrailFx()   forwarded to the TrailFx handle (the run's trail moments, WS-5b)
--   CarLookApplier.runHandle() -> Handle?   the handle that carries the player's trail in the current run (BetaRun.client sets it)
--   h:setChaseView(on)          the run car (review D1, C-02): the decal also on the rear panel, a rim-coloured lip on each wheel
--
-- Options: ghost (H-03: see-through, no collision, no shadow, no trail, a rarity outline when `outline` is given), lod ("full" |
-- "low": tiles and ghosts use "low": no particles and no animated paint redraw), trail (default true), reduceMotion.
--
-- The model is a squared-up display car: its pivot at the bottom centre with the front toward -Z (RealCar.buildBody and
-- RealCar.displayModel make that), `body_geom` the one body mesh and "wheel" in the name of each of the car's own wheel parts. A model
-- that is not that (the run's part-built stand-in) still takes a trail: the holder is then its biggest part.

local AssetService = game:GetService("AssetService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Catalog = require(ReplicatedStorage.Shared.UI.CosmeticPreviewCatalog)
local CarLook = require(ReplicatedStorage.Shared.Style.CarLook)
local Trove = require(ReplicatedStorage.Packages.Trove)

local Style = script.Parent
local Prototype = Style.Parent
local BodyPaint = require(Style.BodyPaint)
local DecalArt = require(Style.DecalArt)
local GameIconIds = require(Prototype.GameIconIds)
local TrailFx = require(Style.TrailFx)

local CarLookApplier = {}

export type Options = {
	ghost: boolean?,
	ghostTransparency: number?, -- default 0.65
	outline: Color3?, -- ghost rarity outline
	lod: ("full" | "low")?,
	trail: boolean?,
	reduceMotion: boolean?,
	paintColour: Color3?, -- additive: the paint colour a MATCH MY PAINT trail takes when this handle itself paints nothing (the run's trail handle)
	trailScale: number?, -- additive (review D1): the trail is this much bigger than the car's width makes it (the run's trail handle)
	trailLevelFloor: number?, -- additive (review D1): setTrailLevel never goes below this (TrailFx:setLevel, when the TrailFx has it)
}

export type Moment = "leap" | "dive" | "catch" | "flare"

export type Handle = {
	model: Model,
	look: CarLook.Look,
	update: (self: Handle, look: CarLook.Look) -> (),
	setTrailSpeed: (self: Handle, speed: number) -> (),
	burst: (self: Handle, moment: Moment) -> (),
	moveTrailTo: (self: Handle, model: Model) -> (),
	setWheelSpin: (self: Handle, radians: number) -> (),
	destroy: (self: Handle) -> (),
	setItem: (self: Handle, tab: Catalog.TabId, item: Catalog.Item?) -> (),
	tick: (self: Handle, phase: number) -> (),
	tail: (self: Handle) -> CFrame,
	clearTrail: (self: Handle) -> (),
	setTrailLevel: (self: Handle, level: number) -> (),
	flareTrail: (self: Handle, seconds: number?) -> (),
	getTrailFx: (self: Handle) -> any?,
	setChaseView: (self: Handle, on: boolean) -> (),
}

local WASH = 0.45 -- the see-through colour wash on a car with no paint mask
local WASH_GROW = 1.012
local TYRE_DIAMETER = 2.04 -- the game's tyre mesh, at scale 1
local TABS: { Catalog.TabId } = { "Paint", "Decals", "Wheels", "Trails" }
local MOVING: { [string]: boolean } = {
	animated = true,
	rainbow = true,
	pulse = true,
	holo = true,
	flow = true,
	galaxy = true,
	sparkle = true,
	molten = true,
	electric = true,
}

local Applied = {}
Applied.__index = Applied

local function sample(colours: { Color3 }, t: number): Color3
	local n = #colours
	local f = (t % 1) * n
	local i = math.floor(f)
	return colours[(i % n) + 1]:Lerp(colours[((i + 1) % n) + 1], f - i)
end

local function meshUri(key: string): string
	return GameIconIds[key] or ("rbxasset://carhop/" .. key .. ".mesh")
end

local function baseName(name: string): string
	return (name:gsub("^Gold ", ""):gsub("^Diamond ", ""))
end

-- An optional sibling module: the file is there once its workstream has merged, and the applier works without it.
local function optional(name: string): any?
	local module = Style:FindFirstChild(name)
	if module and module:IsA("ModuleScript") then
		local ok, result = pcall(require, module)
		if ok then
			return result
		end
		warn("[CarLookApplier] " .. name .. " did not load: " .. tostring(result))
	end
	return nil
end

local function anchorsFor(kind: string, car: string): any?
	local ok, data = pcall(function()
		local module = ReplicatedStorage.Shared.Style:FindFirstChild("Anchors")
		local sub = module and module:FindFirstChild(kind)
		return if sub and sub:IsA("ModuleScript") then (require :: any)(sub) else nil
	end)
	if not ok or type(data) ~= "table" then
		return nil
	end
	return data[car] or data[baseName(car)]
end

-- What each tab is today, as the ids a Look holds.
local function itemFor(tab: Catalog.TabId, id: string?): Catalog.Item?
	if id == nil then
		return nil
	end
	return Catalog.byId(tab, id)
end

local function idOf(look: CarLook.Look, tab: Catalog.TabId): string?
	if tab == "Paint" then
		return look.paint
	elseif tab == "Decals" then
		return look.decal
	elseif tab == "Wheels" then
		return look.wheels
	end
	return look.trail
end

local function findBody(model: Model): MeshPart?
	local body = model:FindFirstChild("body_geom", true)
	return if body and body:IsA("MeshPart") then body else nil
end

local function findWheels(model: Model): { BasePart }
	local list: { BasePart } = {}
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and string.find(d.Name, "wheel", 1, true) and d.Name ~= "Tyre" and d.Name ~= "Rim" then
			table.insert(list, d)
		end
	end
	return list
end

-- The part a trail's attachments hang on: the car's body mesh, else its biggest part (the run's part-built stand-in).
local function holderOf(model: Model): BasePart?
	local body = findBody(model)
	if body then
		return body
	end
	local best: BasePart? = nil
	local volume = 0
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d.Name ~= "Underglow" then
			local v = d.Size.X * d.Size.Y * d.Size.Z
			if v > volume then
				best, volume = d, v
			end
		end
	end
	return best
end

-- The back of a model, +Z pointing away from it, from its bounding box along its own pivot (the pivot is at the bottom centre with
-- the front toward -Z). Returns the width too, for the trail's size.
local function tailOf(model: Model): (CFrame, number)
	local pivot = model:GetPivot()
	local cf, size = model:GetBoundingBox()
	local rel = pivot:ToObjectSpace(cf)
	local y = rel.Y - size.Y / 2 + size.Y * 0.32
	return pivot * CFrame.new(rel.X, y, rel.Z + size.Z / 2), size.X
end

-- The run's handle (additive): the handle that carries the player's trail through the current run, set by BetaRun.client when the run
-- starts and cleared when it ends. The run's trail moments (WS-5b) call CarLookApplier.runHandle():burst("leap") on it; nil between runs.
local runHandle: Handle? = nil
function CarLookApplier.setRunHandle(handle: Handle?)
	runHandle = handle
end
function CarLookApplier.runHandle(): Handle?
	return runHandle
end

-- Apply -----------------------------------------------------------------------------------------------------------------------

function CarLookApplier.apply(model: Model, look: CarLook.Look, options: Options?): Handle
	local o: Options = options or {}
	local ghost = o.ghost == true
	local lowDetail = o.lod == "low"
	local self: any = setmetatable({
		model = model,
		look = CarLook.plain(look.car),
		options = o,
		trove = Trove.new(),
		_body = findBody(model),
		_wheels = findWheels(model),
		_rims = {} :: { BasePart },
		_rimMeshes = {} :: { { part: BasePart, mesh: SpecialMesh } },
		_extras = {} :: { Instance },
		_items = {} :: { [string]: Catalog.Item? },
		_spin = 0,
		_speed = 1,
		_dead = false,
		_ghost = ghost,
		_still = lowDetail or ghost, -- no animated paint redraw
		_trailOn = o.trail ~= false and not ghost,
	}, Applied)
	-- what the handle made outside the Trove's reach is let go with it
	self.trove:Add(function()
		self:_dropTrail()
		if self._kitHandle then
			self._kitHandle:destroy()
			self._kitHandle = nil
		end
	end)
	self:update(look)
	self:_ghostify()
	return self :: Handle
end

function Applied.update(self: any, look: CarLook.Look)
	if self._dead then
		return
	end
	local before: CarLook.Look = self.look
	local first = self._applied == nil
	self._applied = true
	self.look = look
	if not first and CarLook.equal(before, look) then
		return
	end
	for _, tab in TABS do
		local id = idOf(look, tab)
		if first or id ~= idOf(before, tab) then
			self:setItem(tab, itemFor(tab, id))
		end
	end
	if first == false and look.matchPaint ~= before.matchPaint then
		self:_syncMatchPaint()
	end
end

local failedOnce: { [string]: boolean } = {}

-- One tab, with a catalog item (or nil: as the car was made).
function Applied.setItem(self: any, tab: Catalog.TabId, item: Catalog.Item?)
	if self._dead then
		return
	end
	if item and item.isNone then
		item = nil
	end
	self._items[tab] = item
	-- Live game (2026-11-10): with the experience's Mesh / Image APIs off, the paint and decal pictures cannot be made and the error
	-- stopped the whole look, wheels and trail included. Each tab now goes on by itself; a failed one is reported once and skipped.
	local ok, err = pcall(function()
		if tab == "Paint" then
			self:_paint(item)
			self:_syncMatchPaint() -- a trail that matches the paint follows the paint
		elseif tab == "Decals" then
			self:_decal(item)
		elseif tab == "Wheels" then
			self:_wheelsFor(item)
		elseif tab == "Trails" then
			self:_trailFor(item)
		end
	end)
	if not ok and not failedOnce[tab] then
		failedOnce[tab] = true
		warn("[CarLookApplier] " .. tab .. " skipped: " .. tostring(err))
	end
	self:_ghostify()
end

-- Paint --------------------------------------------------------------------------------------------------------------------------

-- A paint that moves, drawn still (tiles and ghosts never redraw): its first colour as a solid.
local function stillOf(item: Catalog.Item): Catalog.Item
	if not (item.kind and MOVING[item.kind]) then
		return item
	end
	local copy = table.clone(item)
	copy.kind = "solid"
	copy.colours = { sample(item.colours, 0.18) }
	return copy
end

function Applied._wash(self: any): MeshPart?
	local body: MeshPart? = self._body
	if not body then
		return nil
	end
	if not self._washPart then
		local wash = body:Clone() :: MeshPart
		wash.Name = "PaintWash"
		for _, d in wash:GetChildren() do
			d:Destroy()
		end
		wash.TextureID = ""
		wash.Material = Enum.Material.SmoothPlastic
		wash.Size = body.Size * WASH_GROW
		wash.CFrame = body.CFrame
		wash.Transparency = 1
		wash.CanCollide = false
		wash.CanQuery = false
		wash.CanTouch = false
		wash.CastShadow = false
		wash.Parent = body.Parent
		self.trove:Add(wash)
		self._washPart = wash
	end
	return self._washPart
end

function Applied.tick(self: any, phase: number)
	local item: Catalog.Item? = self._items.Paint
	if item and item.kind == "animated" and self._washPart and self._washPart.Transparency < 1 then
		self._washPart.Color = sample(item.colours, phase)
	end
end

function Applied._paint(self: any, item: Catalog.Item?)
	local body: MeshPart? = self._body
	if not body then
		return
	end
	local wash = self._washPart :: MeshPart?
	if not item or item.id == "factory_paint" then
		if wash then
			wash.Transparency = 1
		end
		if self._painter then
			self._painter:set(nil)
		end
		self:_decal(self._items.Decals)
		return
	end
	local shown = if self._still then stillOf(item) else item
	-- body panels only, when this car has a paint mask
	if self._painter == nil and BodyPaint.supported(self.look.car) then
		self._painter = BodyPaint.new(body, self.look.car) or false
	end
	if self._painter then
		if wash then
			wash.Transparency = 1
		end
		self._painter:set(shown)
		self:_decal(self._items.Decals)
		return
	end
	-- a car with no mask: the old see-through wash
	local w = self:_wash() :: MeshPart
	w.Transparency = WASH
	w.Color = shown.colours[1]
	if shown.kind == "animated" then
		w.Color = sample(shown.colours, 0.18)
	end
end

-- Decals ---------------------------------------------------------------------------------------------------------------------------

-- Decals sit on the paint when the car is painted (the paint covers the body), else on the body itself.
function Applied._decal(self: any, item: Catalog.Item?)
	local body: MeshPart? = self._body
	if not body then
		return
	end
	local painter = self._painter
	local target: BasePart = if painter and painter._shell.Parent then painter._shell else body
	if self._decals and self._decalTarget ~= target then
		self._decals:destroy()
		self._decals = nil
	end
	if not self._decals then
		if not item then
			return
		end
		self._decals = DecalArt.attach(target, self.model)
		self._decalTarget = target
		self.trove:Add(function()
			if self._decals then
				self._decals:destroy()
				self._decals = nil
			end
		end)
	end
	self._decals:set(item)
	self:_chaseDecal(item, target)
end

-- Wheels: the stock-rim code RealCar had (used when Style.WheelKit is not there) ------------------------------------------------

local function wheelPart(parent: Instance, name: string, mesh: string, scale: number, cf: CFrame): (Part, SpecialMesh)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = true
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

local function buildRims(self: any)
	local model: Model = self.model
	local pivot = model:GetPivot()
	for _, wheel in self._wheels do
		local at = pivot:PointToObjectSpace(wheel.Position)
		local cf = pivot * CFrame.new(at) * CFrame.Angles(0, if at.X > 0 then 0 else math.pi, 0)
		local scale = math.max(wheel.Size.X, wheel.Size.Y, wheel.Size.Z) / TYRE_DIAMETER
		local tyre = wheelPart(model, "Tyre", "car_tyre", scale, cf)
		tyre.Color = Color3.fromRGB(18, 18, 22)
		local rim, mesh = wheelPart(model, "Rim", "car_rim_five", scale, cf)
		self.trove:Add(tyre)
		self.trove:Add(rim)
		table.insert(self._rims, tyre)
		table.insert(self._rims, rim)
		table.insert(self._rimMeshes, { part = rim, mesh = mesh })
	end
end

-- the tyre styles on top of the rim: a white wall, a coloured stripe or a glowing tread (rings on the tyre), a neon ring or a glowing
-- hub in the rim, and chrome, gold or carbon finishes
local function styleRims(self: any, item: Catalog.Item)
	for _, extra in self._extras do
		local at = table.find(self._rims, extra)
		if at then
			table.remove(self._rims, at) -- review N2: setWheelSpin never writes to a destroyed part
		end
		extra:Destroy()
	end
	self._extras = {}
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
			table.insert(self._extras, r)
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

function Applied._wheelsFor(self: any, item: Catalog.Item?)
	-- Style.WheelKit (WS-4) fits tyre and rim models to the car from its per-car anchors; its handle is destroyed to give the car's own
	-- wheels back. Without that module (or when it fails) the stock-rim code below runs.
	local kit = optional("WheelKit")
	if kit and #self._wheels > 0 then
		local id = if item then item.id else nil
		if self._kitHandle then
			if self._kitId == id then
				return
			end
			self._kitHandle:destroy()
			self._kitHandle = nil
		end
		self._kitId = id
		if id == nil then
			self:_chaseLips(nil)
			return
		end
		local anchors = anchorsFor("Wheels", self.look.car)
		local ok, handle = pcall(function()
			return kit.fit(
				self.model,
				id,
				anchors,
				{ lod = self.options.lod, reduceMotion = self.options.reduceMotion }
			)
		end)
		if ok and handle then
			self._kitHandle = handle
			self:_chaseLips(item) -- review D1: the chase view's rim lip, at WheelKit's hubs
			if self._spin ~= 0 then
				pcall(function()
					if handle.setSpin then
						handle:setSpin(self._spin) -- WheelKit: the total roll angle
					else
						handle:spin(self._spin)
					end
				end)
			end
			return
		end
		warn("[CarLookApplier] WheelKit.fit failed for " .. self.look.car .. ": " .. tostring(handle))
	end
	if item == nil and #self._rims == 0 then
		return -- the car's own wheels, and nothing was ever put over them
	end
	-- the stock-rim code
	local key = if item and item.key then item.key else "five"
	local own = key == "five" and (not item or item.kind == nil)
	if not own and #self._rims == 0 then
		buildRims(self)
	end
	self._hid = not own -- the car's own wheels are hidden by this handle (given back in destroy)
	for _, wheel in self._wheels do
		wheel.Transparency = if own then 0 else 1
	end
	for _, p in self._rims do
		p.Transparency = if own then 1 else 0
	end
	if own or not item then
		self:_chaseLips(nil)
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
	styleRims(self, item)
	self:_chaseLips(item)
end

-- Turns every wheel to `radians` (total) about its axle.
function Applied.setWheelSpin(self: any, radians: number)
	if self._dead then
		return
	end
	local delta = radians - self._spin
	self._spin = radians
	if self._kitHandle then
		pcall(function()
			local kit = self._kitHandle
			if kit.setSpin then
				kit:setSpin(radians) -- WheelKit: sets the roll angle outright (spin() would add)
			else
				kit:spin(delta)
			end
		end)
		return
	end
	if delta == 0 then
		return
	end
	local turn = CFrame.Angles(delta, 0, 0)
	for _, p in self._rims do
		if p.Transparency < 1 then
			p.CFrame *= turn
		end
	end
end

-- Trail --------------------------------------------------------------------------------------------------------------------------

function Applied._trailModel(self: any): Model
	return self._trailOn_model or self.model
end

-- Builds (or re-places) the trail on the model it follows. A trail needs a holder part that moves with the car.
function Applied._dropTrail(self: any)
	if self._trail then
		self._trail:destroy()
		self._trail = nil
	end
	local holder: BasePart? = self._trailHolder
	if holder and holder.Parent then
		holder:SetAttribute("CarLookTrail", nil)
	end
	self._trailHolder = nil
end

function Applied._attachTrail(self: any, model: Model)
	self:_dropTrail()
	local holder = holderOf(model)
	if not holder then
		return
	end
	local tail, width = tailOf(model)
	-- TrailFx (WS-5a) finds the car's exhaust points itself from the CarName attribute up the model tree; the car name here is for a
	-- model that carries none. The old four-argument-free call still works (the options are ignored by a TrailFx without them).
	local scale = self.options.trailScale or 1
	local fx = (TrailFx :: any).attach(
			holder,
			tail,
			math.max(width, 3) * scale,
			{ model = model, car = self.look.car }
		) :: any
	if self.options.lod == "low" and fx.setQuality then
		fx:setQuality("low") -- beams and ribbons only: no particles, no glow, no sound
	end
	if self.options.reduceMotion ~= nil and fx.setReduceMotion then
		fx:setReduceMotion(self.options.reduceMotion)
	end
	fx:setSpeed(self._speed)
	if self.options.trailLevelFloor and fx.setLevel then
		fx:setLevel(math.clamp(self.options.trailLevelFloor, 0, 3))
	end
	self._trail = fx
	self._trailHolder = holder
	self._trailOn_model = model
	holder:SetAttribute("CarLookTrail", "") -- marks the part the trail hangs on (the end-to-end look test reads it)
end

-- T-08: the colour a MATCH MY PAINT trail takes: this car's worn paint, else the colour the caller gave (the run's trail handle).
function Applied._syncMatchPaint(self: any)
	local fx = self._trail
	if not (fx and fx.setMatchPaint) then
		return
	end
	local colour: Color3? = nil
	if self.look.matchPaint then
		local trail: Catalog.Item? = self._items.Trails
		local supports = (TrailFx :: any).supportsMatchPaint
		if trail == nil or supports == nil or supports(trail) then
			local paint: Catalog.Item? = self._items.Paint
			colour = if paint and paint.colours[1] then paint.colours[1] else self.options.paintColour
		end
	end
	fx:setMatchPaint(colour)
end

function Applied._trailFor(self: any, item: Catalog.Item?)
	if not self._trailOn then
		return
	end
	if not item then
		self:_dropTrail()
		return
	end
	if not self._trail then
		self:_attachTrail(self._trailOn_model or self.model)
	end
	if self._trail then
		self._trail:set(item)
		if self._trailHolder then
			(self._trailHolder :: BasePart):SetAttribute("CarLookTrail", item.id)
		end
		self:_syncMatchPaint()
	end
end

-- Forget the ribbon behind the car (after a teleport or a hop, so it never draws a line across the map).
function Applied.clearTrail(self: any)
	if self._trail then
		self._trail:clear()
	end
end

-- The trail's own hooks for the run's trail moments (WS-5b, src/client/Run/TrailMoments): forwarded to the TrailFx handle when it has them
-- (WS-5a: fx:setLevel(0..3) for a hop chain, fx:flare(seconds) for a brief brighter moment); a TrailFx without them changes nothing.
function Applied.setTrailLevel(self: any, level: number)
	local fx = self._trail
	if fx and fx.setLevel then
		fx:setLevel(math.clamp(math.max(level, self.options.trailLevelFloor or 0), 0, 3))
	end
end

function Applied.flareTrail(self: any, seconds: number?)
	local fx = self._trail
	if fx and fx.flare then
		fx:flare(seconds)
	end
end

function Applied.getTrailFx(self: any): any?
	return self._trail
end

function Applied.setTrailSpeed(self: any, speed: number)
	self._speed = math.clamp(speed, 0, 1)
	if self._trail then
		self._trail:setSpeed(self._speed)
	end
end

-- The trail follows the player to the next car: it is built again on that car's body, at its back; paint, decal and wheels stay where
-- they were. A model with nothing to hang a trail on (or this handle having no trail) changes nothing.
function Applied.moveTrailTo(self: any, model: Model)
	if self._dead or not self._trailOn then
		return
	end
	local item: Catalog.Item? = self._items.Trails
	self._trailOn_model = model
	self:_dropTrail()
	if item then
		self:_trailFor(item)
		if self._trail then
			self._trail:clear()
		end
	end
end

function Applied.tail(self: any): CFrame
	local at = tailOf(self:_trailModel())
	return at
end

-- A short burst of the trail's colours (Style.TrailBursts, WS-5b); nothing when that module is not there yet.
function Applied.burst(self: any, moment: Moment)
	if self._dead then
		return
	end
	local bursts = optional("TrailBursts")
	if bursts and self.look.trail then
		pcall(function()
			bursts.play(self:_trailModel(), self.look, moment, self.options.reduceMotion)
		end)
	end
end

-- Chase view (review D1, C-02: Adam saw no decal, wheels or trail in a run) ---------------------------------------------------------
-- The run's camera sits behind and above the car you ride, so it sees the back and the top, never a side. On that one car (BetaRun.client
-- calls setChaseView(true) on your start car) the decal is also put on the rear panel, and each wheel gets a lip in the rim colour that
-- sticks out past the tyre, so the rims read at the slight angle of a lane change. The other screens keep the side-only look.

local REAR_W, REAR_H = 256, 128
local rearImages: { [string]: EditableImage } = {}

-- The design fitted into the lower band of the rear face (the tailgate or rear doors: under the rear window, above the bumper),
-- transparent everywhere else, so the rear window and lights stay clear. One image per design, made the first time it is needed.
local function rearImage(item: Catalog.Item): EditableImage?
	local known = rearImages[item.id]
	if known then
		return known
	end
	local source = DecalArt.image(item)
	if not source then
		return nil
	end
	local ok, image = pcall(function(): EditableImage
		local size = source.Size
		local sw, sh = math.floor(size.X), math.floor(size.Y)
		local src = source:ReadPixelsBuffer(Vector2.zero, size)
		local out = buffer.create(REAR_W * REAR_H * 4) -- all zero: transparent
		local x0, x1 = math.floor(REAR_W * 0.1), math.floor(REAR_W * 0.9)
		local y0, y1 = math.floor(REAR_H * 0.46), math.floor(REAR_H * 0.84)
		for y = y0, y1 - 1 do
			local sy = math.min(math.floor((y - y0) / (y1 - y0) * sh), sh - 1)
			for x = x0, x1 - 1 do
				local sx = math.min(math.floor((x - x0) / (x1 - x0) * sw), sw - 1)
				buffer.writeu32(out, (y * REAR_W + x) * 4, buffer.readu32(src, (sy * sw + sx) * 4))
			end
		end
		local made = AssetService:CreateEditableImage({ Size = Vector2.new(REAR_W, REAR_H) })
		made:WritePixelsBuffer(Vector2.zero, Vector2.new(REAR_W, REAR_H), out)
		return made
	end)
	if not ok or not image then
		return nil
	end
	rearImages[item.id] = image
	return image
end

local FACES = {
	Enum.NormalId.Right,
	Enum.NormalId.Left,
	Enum.NormalId.Top,
	Enum.NormalId.Bottom,
	Enum.NormalId.Back,
	Enum.NormalId.Front,
}

-- The face of `part` whose outward normal is closest to `direction` (world space).
local function faceToward(part: BasePart, direction: Vector3): Enum.NormalId
	local best, score = Enum.NormalId.Back, -math.huge
	for _, face in FACES do
		local d = part.CFrame:VectorToWorldSpace(Vector3.FromNormalId(face)):Dot(direction)
		if d > score then
			best, score = face, d
		end
	end
	return best
end

function Applied.setChaseView(self: any, on: boolean)
	if self._dead or self._chase == on then
		return
	end
	self._chase = on
	if not self._chaseCleanup then
		self._chaseCleanup = true
		self.trove:Add(function()
			self:_chaseDecal(nil, nil)
			self:_chaseLips(nil)
		end)
	end
	self:_chaseDecal(self._items.Decals, self._decalTarget)
	local wheels: Catalog.Item? = self._items.Wheels
	local stock = wheels == nil or wheels.id == "stock_five" or (wheels.key == "five" and wheels.kind == nil)
	self:_chaseLips(if stock then nil else wheels)
end

function Applied._chaseDecal(self: any, item: Catalog.Item?, target: BasePart?)
	if self._rearDecal then
		self._rearDecal:Destroy()
		self._rearDecal = nil
	end
	if not (self._chase and item and target and target.Parent) then
		return
	end
	local pivot = self.model:GetPivot()
	if target.CFrame.UpVector:Dot(pivot.UpVector) < 0.7 then
		return -- a body mesh lying on its side: its rear face would show the design turned; leave it to the sides
	end
	local image = rearImage(item)
	if not image then
		return
	end
	local decal = Instance.new("Decal")
	decal.Name = "StyleDecalRear"
	decal.Face = faceToward(target, -pivot.LookVector) -- the front is -Z, so the back is +Z
	local ok = pcall(function()
		(decal :: any).ColorMapContent = Content.fromObject(image)
	end)
	if not ok then
		decal:Destroy()
		return
	end
	decal.Parent = target
	self._rearDecal = decal
end

local LIP_SEGMENTS = 10

-- A hoop in the rim colour on the outside of each wheel, built from short bars (a Part cannot be a ring), so the spokes stay visible
-- from the side and the hoop's edge reads from behind. At WheelKit's hubs when WheelKit dressed the wheels, else at the car's own wheels.
function Applied._chaseLips(self: any, item: Catalog.Item?)
	for _, p in self._lips or {} do
		p:Destroy()
	end
	self._lips = {}
	if not (self._chase and item) then
		return
	end
	local style = item.kind :: any
	local colour = item.colours[1]
	local hubs: { { cf: CFrame, d: number, out: number } } = {}
	local kit = if self._kitHandle then optional("WheelKit") else nil
	if kit then
		pcall(function()
			local design = kit.designOf(item.id)
			if design and design.rimColor then
				colour = design.rimColor
			end
			local anchors = anchorsFor("Wheels", self.look.car)
			for i = 1, 4 do
				local hub = kit.hub(self.model, i, anchors)
				if hub then
					table.insert(hubs, { cf = hub.cframe, d = hub.radius * 2, out = hub.width / 2 })
				end
			end
		end)
	else
		local pivot = self.model:GetPivot()
		for _, wheel in self._wheels do
			local at = pivot:PointToObjectSpace(wheel.Position)
			local d = math.max(wheel.Size.X, wheel.Size.Y, wheel.Size.Z)
			-- +X out of the car, as WheelKit's hubs
			local cf = pivot * CFrame.new(at) * CFrame.Angles(0, if at.X > 0 then 0 else math.pi, 0)
			table.insert(hubs, { cf = cf, d = d, out = d * 0.26 })
		end
	end
	for _, hub in hubs do
		local d = hub.d
		local thick = d * 0.14
		local radius = d * 0.4
		local seg = 2 * math.pi * radius / LIP_SEGMENTS * 1.1
		local axle = hub.cf * CFrame.new(hub.out + thick / 2, 0, 0)
		for i = 1, LIP_SEGMENTS do
			local p = Instance.new("Part")
			p.Name = "RimLip"
			p.Anchored = true
			p.CanCollide = false
			p.CanQuery = false
			p.CanTouch = false
			p.CastShadow = false
			p.Size = Vector3.new(thick, d * 0.12, seg)
			p.CFrame = axle * CFrame.Angles((i / LIP_SEGMENTS) * math.pi * 2, 0, 0) * CFrame.new(0, radius, 0)
			p.Color = colour
			p.Material = if style == "carbon" then Enum.Material.Slate else Enum.Material.SmoothPlastic
			p.Reflectance = if style == "chrome" or style == "gold" then 0.25 else 0
			p.Parent = self.model
			table.insert(self._lips, p)
		end
	end
end

-- Ghost ------------------------------------------------------------------------------------------------------------------------------

-- A see-through car that cannot be touched and casts no shadow. Runs after every tab, so a part made later is ghostly too.
function Applied._ghostify(self: any)
	if not self._ghost then
		return
	end
	local transparency = self.options.ghostTransparency or 0.65
	for _, d in self.model:GetDescendants() do
		if d:IsA("BasePart") then
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			d.CastShadow = false
			if d.Transparency < 1 then
				d.Transparency = math.max(d.Transparency, transparency)
			end
		end
	end
	local colour: Color3? = self.options.outline
	if colour and not self._outline then
		local h = Instance.new("Highlight")
		h.Name = "GhostOutline"
		h.FillTransparency = 1
		h.OutlineColor = colour
		h.OutlineTransparency = 0.1
		h.DepthMode = Enum.HighlightDepthMode.Occluded
		h.Adornee = self.model
		h.Parent = self.model
		self.trove:Add(h)
		self._outline = h
	end
end

function Applied.destroy(self: any)
	if self._dead then
		return
	end
	self._dead = true
	-- the car's own wheels come back (only if this handle hid them)
	if self._hid then
		for _, wheel in self._wheels do
			if wheel.Parent then
				wheel.Transparency = 0
			end
		end
	end
	if self._painter then
		self._painter:destroy()
		self._painter = nil
	end
	self.trove:Destroy()
	for _, extra in self._extras do
		extra:Destroy()
	end
	self._extras = {}
end

return CarLookApplier
