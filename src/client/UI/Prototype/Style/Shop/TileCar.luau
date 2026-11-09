--!strict
-- TileCar (Lane 3 Round 8, C-06): one Style Shop tile's car. A small static ViewportFrame holding a copy of the player's SELECTED
-- car, dressed in the tile's look (the car, the player's own paint/decal/wheels, and this tile's item in its slot). Adam: "when I'm
-- looking at the fresh lime color, when I have the pizza truck equipped ... it is showing me the sports car."
--
-- The tile is drawn once and never redrawn; only the hovered or selected tile turns (the grid calls tile:turn(dt) for that one).
-- Dressing goes through CarLookApplier.apply(model, look, { lod = "low", trail = false }): the one place that knows how to dress a
-- car (WS-1): paint on the body panels only, the decal, the wheels; low detail draws a moving paint still. A tile never shows a
-- trail, but its handle is set to the idle trail speed (0.2, T-03: short and gentle when standing) all the same, so nothing can
-- ever start at run speed.
--
--   TileCar.new(holder, look, { z = number?, yaw = number?, aspect = number? }) -> Tile?   nil when the car's model is not here
--   tile.view -> ViewportFrame     tile:turn(dt)     tile:rest()     tile:destroy()

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Prototype = script.Parent.Parent.Parent
local CarLookApplier = require(Prototype.Style.CarLookApplier)
local RealCar = require(Prototype.RealCar)
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
local HEIGHT = 7.5
local FOV = 24
local REST_YAW = math.rad(118) -- front toward the lower left, like the reference tiles
local TURN_RATE = math.rad(48) -- how fast the one hovered or selected tile turns
local IDLE_TRAIL_SPEED = 0.2 -- T-03: a standing car's trail is short and gentle

-- Back off until the whole car, turned any way, fits the frame.
local function place(camera: Camera, size: Vector3, aspect: number)
	local tanHalf = math.tan(math.rad(FOV) / 2)
	local across = math.max(size.X, size.Z)
	local distance =
		math.max((across * 1.1) / (2 * tanHalf * math.min(aspect, 1.8)), (size.Y * 1.3) / (2 * tanHalf), 12)
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
	local handle = CarLookApplier.apply(model, look, { lod = "low", trail = false })
	handle:setTrailSpeed(IDLE_TRAIL_SPEED)
	trove:Add(function()
		handle:destroy()
	end)
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
