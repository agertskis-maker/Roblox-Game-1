--!strict
-- CarLookApplier (Lane 3 Round 8, C-01; API frozen by the lead in vault/design/specs/lane3-round8-contracts.md, body by WS-1):
-- puts a CarLook.Look on a car model, the same way everywhere (Style Shop turntable, shop tiles, launch card, Garage, Raceway racing
-- cars, parking ghosts, the run car). Wraps Style.BodyPaint (paint), Style.DecalArt (decal), Style.WheelKit (wheels, when that module
-- exists; else the stock-rim code below, moved here from RealCar) and Style.TrailFx (trail). Everything it creates is owned by the
-- handle's Trove and is removed on update() or destroy(); update() rebuilds only the tabs that changed.
--
--   local h = CarLookApplier.apply(model: Model, look: CarLook.Look, options: Options?) -> Handle
--   h:update(look)              re-dress (only the tabs that changed are rebuilt)
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
--
-- Options: ghost (H-03: see-through, no collision, no shadow, no trail, a rarity outline when `outline` is given), lod ("full" |
-- "low": tiles and ghosts use "low": no particles and no animated paint redraw), trail (default true), reduceMotion.
--
-- The model is a squared-up display car: its pivot at the bottom centre with the front toward -Z (RealCar.buildBody and
-- RealCar.displayModel make that), `body_geom` the one body mesh and "wheel" in the name of each of the car's own wheel parts. A model
-- that is not that (the run's part-built stand-in) still takes a trail: the holder is then its biggest part.

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
		_trailOn = o.trail ~= false and not ghost and not lowDetail,
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
	if first == false and look.matchPaint ~= before.matchPaint and self._trail then
		self._trail:set(self._items.Trails)
	end
end

-- One tab, with a catalog item (or nil: as the car was made).
function Applied.setItem(self: any, tab: Catalog.TabId, item: Catalog.Item?)
	if self._dead then
		return
	end
	if item and item.isNone then
		item = nil
	end
	self._items[tab] = item
	if tab == "Paint" then
		self:_paint(item)
	elseif tab == "Decals" then
		self:_decal(item)
	elseif tab == "Wheels" then
		self:_wheelsFor(item)
	elseif tab == "Trails" then
		self:_trailFor(item)
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
			return
		end
		local anchors = anchorsFor("Wheels", self.look.car)
		local ok, handle = pcall(function()
			return kit.fit(self.model, id, anchors)
		end)
		if ok and handle then
			self._kitHandle = handle
			if self._spin ~= 0 then
				pcall(function()
					handle:spin(self._spin)
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
	styleRims(self, item)
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
			self._kitHandle:spin(radians)
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
	local fx = TrailFx.attach(holder, tail, math.max(width, 3))
	fx:setSpeed(self._speed)
	self._trail = fx
	self._trailHolder = holder
	self._trailOn_model = model
	holder:SetAttribute("CarLookTrail", "") -- marks the part the trail hangs on (the end-to-end look test reads it)
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
	end
end

-- Forget the ribbon behind the car (after a teleport or a hop, so it never draws a line across the map).
function Applied.clearTrail(self: any)
	if self._trail then
		self._trail:clear()
	end
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
	-- the car's own wheels come back
	for _, wheel in self._wheels do
		if wheel.Parent then
			wheel.Transparency = 0
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
