--!strict
-- TileCar (Lane 3 Round 8, C-06): one Style Shop tile's car. A small static ViewportFrame holding a copy of the player's SELECTED
-- car, dressed in the tile's look (the car, the player's own paint/decal/wheels, and this tile's item in its slot). Adam: "when I'm
-- looking at the fresh lime color, when I have the pizza truck equipped ... it is showing me the sports car."
--
-- The tile is drawn once and never redrawn; only the hovered or selected tile turns (the grid calls tile:turn(dt) for that one).
-- Dressing goes through CarLookApplier.apply(model, look, { lod = "low", trail = false }) (the one place that knows how to dress a
-- car, WS-1). While the applier's body is not merged (it announces itself with CarLookApplier.implemented = true) the tile dresses
-- the copy itself with the same pieces the turntable uses (Style.BodyPaint and Style.DecalArt), frozen so nothing animates.
--
--   TileCar.applierReady() -> boolean
--   TileCar.new(holder, look, { z = number?, yaw = number?, aspect = number? }) -> Tile?   nil when the car's model is not here
--   tile.view -> ViewportFrame     tile:turn(dt)     tile:rest()     tile:destroy()

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Prototype = script.Parent.Parent.Parent
local BodyPaint = require(Prototype.Style.BodyPaint)
local CarLookApplier = require(Prototype.Style.CarLookApplier)
local DecalArt = require(Prototype.Style.DecalArt)
local RealCar = require(Prototype.RealCar)
local Catalog = require(ReplicatedStorage.Shared.UI.CosmeticPreviewCatalog)
local Trove = require(ReplicatedStorage.Packages.Trove)

local CarLook = require(ReplicatedStorage.Shared.Style.CarLook)

local TileCar = {}
TileCar.__index = TileCar

export type Options = { z: number?, yaw: number?, aspect: number? } -- aspect: the thumbnail's width over its height
export type Tile = {
	view: ViewportFrame,
	model: Model,
	turn: (self: Tile, dt: number) -> (),
	rest: (self: Tile) -> (),
	destroy: (self: Tile) -> (),
}

local LENGTH = 12.6 -- every car is scaled to one length, as on the turntable
local HEIGHT = 6
local FOV = 24
local REST_YAW = math.rad(118) -- front toward the lower left, like the reference tiles
local TURN_RATE = math.rad(48) -- how fast the one hovered or selected tile turns
local WASH = 0.45

function TileCar.applierReady(): boolean
	return (CarLookApplier :: any).implemented == true
end

-- The dressing the applier will own. Paint on the body panels only (BodyPaint), a see-through wash where a car has no mask, then
-- the decal on the paint. Frozen: a tile never animates.
local function legacyDress(model: Model, look: CarLook.Look, trove: any)
	local body = model:FindFirstChild("body_geom", true)
	if not (body and body:IsA("MeshPart")) then
		return
	end
	local paint = if look.paint then Catalog.byId("Paint", look.paint) else nil
	local painter: any = nil
	if paint and paint.id ~= "factory_paint" then
		if BodyPaint.supported(look.car) then
			painter = BodyPaint.new(body, look.car)
		end
		if painter then
			painter:set(paint)
			painter._item = nil -- drawn once: the shared animator skips a painter with no item (a tile does not move)
			trove:Add(function()
				painter:destroy()
			end)
		else
			local wash = body:Clone() :: MeshPart
			wash.Name = "PaintWash"
			for _, child in wash:GetChildren() do
				child:Destroy()
			end
			wash.TextureID = ""
			wash.Material = Enum.Material.SmoothPlastic
			wash.Size = body.Size * 1.012
			wash.CFrame = body.CFrame
			wash.Color = paint.colours[1]
			wash.Transparency = WASH
			wash.Parent = model
			trove:Add(wash)
		end
	end
	local decal = if look.decal then Catalog.byId("Decals", look.decal) else nil
	if decal and not decal.isNone then
		local still = table.clone(decal)
		still.tier = "street" -- the animated tier would register with the decal clock
		local target: BasePart = if painter and painter._shell.Parent then painter._shell else body
		local d = DecalArt.attach(target, model)
		d:set(still)
		trove:Add(function()
			d:destroy()
		end)
	end
end

-- Back off until the whole car, turned any way, fits the frame.
local function place(camera: Camera, size: Vector3, aspect: number)
	local tanHalf = math.tan(math.rad(FOV) / 2)
	local half = math.max(size.X, size.Z) * 0.5
	local distance = math.max((half * 1.18) / (tanHalf * math.min(aspect, 1.6)), (size.Y * 0.8) / tanHalf, 14)
	local centre = Vector3.new(0, size.Y * 0.42, 0)
	camera.FieldOfView = FOV
	camera.CFrame = CFrame.lookAt(centre + Vector3.new(0, distance * 0.3, distance), centre)
end

function TileCar.new(holder: GuiObject, look: CarLook.Look, options: Options?): Tile?
	local o: Options = options or {}
	local model = RealCar.displayModel(look.car)
	if not model then
		return nil
	end
	local trove = Trove.new()
	local view = Instance.new("ViewportFrame")
	view.Name = "CarTile"
	view.BackgroundTransparency = 1
	view.Size = UDim2.fromScale(1, 1)
	view.Ambient = Color3.fromRGB(175, 176, 190)
	view.LightColor = Color3.fromRGB(255, 250, 240)
	view.LightDirection = Vector3.new(-0.6, -1, -0.5)
	view.ZIndex = o.z or (holder.ZIndex + 1)
	view.Active = false
	trove:Add(view)
	local camera = Instance.new("Camera")
	camera.Parent = view
	view.CurrentCamera = camera

	-- one size for every car, standing on the origin
	local _, size = model:GetBoundingBox()
	local fit = math.min(LENGTH / math.max(size.Z, 0.01), HEIGHT / math.max(size.Y, 0.01))
	model:ScaleTo(model:GetScale() * fit)
	local _, scaled = model:GetBoundingBox()
	local yaw = o.yaw or REST_YAW
	model:PivotTo(CFrame.Angles(0, yaw, 0))
	model.Parent = view
	if TileCar.applierReady() then
		local handle = CarLookApplier.apply(model, look, { lod = "low", trail = false })
		trove:Add(function()
			handle:destroy()
		end)
	else
		legacyDress(model, look, trove)
	end
	view.Parent = holder
	place(camera, scaled, o.aspect or 1.3)

	local self = setmetatable({ view = view, model = model, _yaw = yaw, _rest = yaw, _trove = trove }, TileCar)
	return (self :: any) :: Tile
end

function TileCar.turn(self: any, dt: number)
	self._yaw += TURN_RATE * dt
	self.model:PivotTo(CFrame.Angles(0, self._yaw, 0))
end

function TileCar.rest(self: any)
	if self._yaw ~= self._rest then
		self._yaw = self._rest
		self.model:PivotTo(CFrame.Angles(0, self._yaw, 0))
	end
end

function TileCar.destroy(self: any)
	self._trove:Destroy()
end

return TileCar
