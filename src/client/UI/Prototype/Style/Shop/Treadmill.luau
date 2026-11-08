--!strict
-- Treadmill (Lane 3 Round 8, T-09): the Trails tab's turntable becomes a short belt of road. Lane marks scroll under the car and
-- wind lines streak past, so the trail streams out behind it as it does in a run. Parts in the turntable's own ViewportFrame
-- world (a few dozen anchored parts; two small pools move each step). Reduce Motion keeps the belt still.
--
-- The belt runs along the car's own axis: the car's front is -Z in the belt's space and the trail side is +Z. setYaw turns the
-- whole belt about the origin to match the car's yaw on the turntable.
--
--   local t = Treadmill.new(world: Instance)
--   t:show()  t:hide()  t:setYaw(radians)  t:step(dt, speed01, reduced)  t:destroy()

local Treadmill = {}
Treadmill.__index = Treadmill

local LENGTH = 25 -- the belt, along the car's axis
local WIDTH = 8.8
local TOP = 0.47 -- the belt's surface: level with the turntable disc it replaces
local MID = 2.8 -- the belt's centre along the axis, toward the trail
local RAIL = 2.5 -- one kerb block's length
local SCROLL = 17 -- studs a second at full speed
local DASHES = 6
local WINDS = 16

local ASPHALT = Color3.fromRGB(48, 54, 74)
local KERB_RED = Color3.fromRGB(231, 72, 67)
local KERB_WHITE = Color3.fromRGB(255, 248, 238)
local MARK = Color3.fromRGB(236, 238, 246)
local ROLLER = Color3.fromRGB(28, 34, 54)
local GLOW = Color3.fromRGB(255, 170, 40)

type Moving = { part: Part, base: number, x: number, y: number, speed: number }

local function plain(parent: Instance, name: string, size: Vector3, color: Color3): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	p.Size = size
	p.Color = color
	p.Parent = parent
	return p
end

function Treadmill.new(world: Instance): any
	local self = setmetatable({}, Treadmill) :: any
	local model = Instance.new("Model")
	model.Name = "Treadmill"
	self._model = model
	self._world = world
	self._yaw = 0
	self._scroll = 0
	self._fixed = {} :: { { part: Part, at: CFrame } }
	self._dashes = {} :: { Moving }
	self._winds = {} :: { Moving }

	local function fixed(part: Part, at: CFrame)
		table.insert(self._fixed, { part = part, at = at })
	end

	-- the belt, its two edge lines and the kerb blocks along both sides
	fixed(plain(model, "Belt", Vector3.new(WIDTH, 0.6, LENGTH), ASPHALT), CFrame.new(0, TOP - 0.3, MID))
	for _, side in { -1, 1 } do
		fixed(
			plain(model, "EdgeLine", Vector3.new(0.18, 0.05, LENGTH - 1), MARK),
			CFrame.new(side * (WIDTH / 2 - 0.6), TOP + 0.02, MID)
		)
		for i = 0, math.floor(LENGTH / RAIL) - 1 do
			local z = MID - LENGTH / 2 + RAIL * (i + 0.5)
			fixed(
				plain(model, "Kerb", Vector3.new(1, 0.62, RAIL), if i % 2 == 0 then KERB_RED else KERB_WHITE),
				CFrame.new(side * (WIDTH / 2 + 0.5), TOP - 0.02, z)
			)
		end
	end
	-- the two rollers at the ends, with a warm glow on their inner side
	for _, end_ in { -1, 1 } do
		local roller = plain(model, "Roller", Vector3.new(WIDTH + 1.4, 1.5, 1.5), ROLLER)
		roller.Shape = Enum.PartType.Cylinder
		fixed(roller, CFrame.new(0, TOP - 0.5, MID + end_ * (LENGTH / 2)))
		local glow = plain(model, "RollerGlow", Vector3.new(WIDTH - 0.4, 0.12, 0.35), GLOW)
		glow.Material = Enum.Material.Neon
		fixed(glow, CFrame.new(0, TOP + 0.03, MID + end_ * (LENGTH / 2 - 0.9)))
	end

	-- lane marks that scroll toward the trail side
	for i = 1, DASHES do
		local dash = plain(model, "Dash", Vector3.new(0.34, 0.05, 2.2), MARK)
		table.insert(
			self._dashes,
			{ part = dash, base = (i - 1) * (LENGTH / DASHES), x = 0, y = TOP + 0.03, speed = 1 }
		)
	end
	-- wind lines streak past on both sides and over the car, never through its body
	local rng = Random.new(11)
	for i = 1, WINDS do
		local length = rng:NextNumber(2.4, 5.2)
		local line = plain(model, "Wind", Vector3.new(0.07, 0.07, length), Color3.new(1, 1, 1))
		line.Material = Enum.Material.Neon
		line.Transparency = rng:NextNumber(0.5, 0.78)
		local side = if i % 2 == 0 then 1 else -1
		local overhead = i % 5 == 0
		table.insert(self._winds, {
			part = line,
			base = rng:NextNumber(0, LENGTH),
			x = if overhead then rng:NextNumber(-1.8, 1.8) else side * rng:NextNumber(3.3, 5.6),
			y = if overhead then rng:NextNumber(5.8, 7.4) else rng:NextNumber(0.9, 5.2),
			speed = rng:NextNumber(1.9, 3.1),
		})
	end
	self:_place()
	return self
end

function Treadmill._place(self: any)
	local root = CFrame.Angles(0, self._yaw, 0)
	for _, f in self._fixed do
		f.part.CFrame = root * f.at
	end
	local near = MID - LENGTH / 2
	for _, d in self._dashes do
		d.part.CFrame = root * CFrame.new(d.x, d.y, near + (d.base + self._scroll) % LENGTH)
	end
	for _, w in self._winds do
		w.part.CFrame = root * CFrame.new(w.x, w.y, near + (w.base + self._scroll * w.speed) % LENGTH)
	end
end

function Treadmill.show(self: any)
	self._model.Parent = self._world
end

function Treadmill.hide(self: any)
	self._model.Parent = nil
end

function Treadmill.setYaw(self: any, radians: number)
	self._yaw = radians
	self:_place()
end

-- speed is 0 to 1 (a run's top speed is 1); a still belt does no work
function Treadmill.step(self: any, dt: number, speed: number, reduced: boolean)
	if reduced or speed <= 0 or self._model.Parent == nil then
		return
	end
	self._scroll = (self._scroll + dt * SCROLL * speed) % (LENGTH * 60)
	self:_place()
end

function Treadmill.destroy(self: any)
	self._model:Destroy()
end

return Treadmill
