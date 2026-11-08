--!strict
-- ShopTrail (Lane 3 Round 8, T-09): the trail on the Style Shop's turntable. A ViewportFrame cannot show Trail, Beam or particle
-- objects, so the trail is TrailPreview's ribbon and pieces (parts in the turntable's world) with two additions the Trails tab
-- needs: a SPEED (the treadmill's: 0 is the turntable, 1 is a run at top speed, so the trail streams out long and fast) and a
-- BURST (tapping the preview: the hop burst of T-04, here a ring of sparks in the trail's colours puffing out from the car).
--
-- The same two calls exist on CarLookApplier's handle (setTrailSpeed, burst); the real run and the Launch Pad use that one. This
-- file is only the turntable's, where those effects would not show.
--
--   local t = ShopTrail.new(world, length)
--   t:set(item?)  t:setSpeed(0..1)  t:burst(moment, tail: CFrame, reduced: boolean)  t:step(dt, tail, reduced)  t:destroy()

local Prototype = script.Parent.Parent.Parent
local TrailPreview = require(Prototype.Screens.TrailPreview) :: any

local ShopTrail = {}
ShopTrail.__index = ShopTrail

type Spark = {
	part: Part,
	age: number,
	life: number,
	dir: Vector3,
	speed: number,
	size: number,
}

local SPARKS = 18
local STREAKS = 22 -- at most this many streaks of light streaming back at once
local STREAK_REACH = 15 -- studs a streak travels at full speed
local BURST_LIFE = 0.75

local function plain(parent: Instance, size: number, color: Color3): Part
	local p = Instance.new("Part")
	p.Name = "TrailBurst"
	p.Shape = Enum.PartType.Ball
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	p.Size = Vector3.one * size
	p.Color = color
	p.Parent = parent
	return p
end

function ShopTrail.new(world: Instance, length: number): any
	local self = setmetatable({}, ShopTrail) :: any
	self._world = world
	self._preview = TrailPreview.new(world, { length = length })
	self._speed = 0
	self._colours = { Color3.new(1, 1, 1) }
	self._sparks = {} :: { Spark }
	self._streaks = {} :: { Spark }
	self._streamOn = false
	self._emit = 0
	self._seed = 0
	return self
end

function ShopTrail.set(self: any, item: any?)
	self._preview:set(item)
	self._colours = if item and item.colours and #item.colours > 0 then item.colours else { Color3.new(1, 1, 1) }
	self._streamOn = item ~= nil and item.isNone ~= true
	for _, s in self._streaks do
		s.part:Destroy()
	end
	table.clear(self._streaks)
end

function ShopTrail.setSpeed(self: any, speed: number)
	self._speed = math.clamp(speed, 0, 1)
end

local function clearSparks(self: any)
	for _, s in self._sparks do
		s.part:Destroy()
	end
	table.clear(self._sparks)
end

-- A ring of sparks out of the car's tail (its plane faces the way the car travels), and a few thrown back along the trail.
function ShopTrail.burst(self: any, moment: string, tail: CFrame, reduced: boolean)
	clearSparks(self)
	if reduced then
		return -- Reduce Motion: no screen-filling burst
	end
	self._origin = tail
	local count = if moment == "leap" then SPARKS else math.floor(SPARKS * 0.6)
	for i = 1, count do
		local angle = (i / count) * math.pi * 2
		local ring = i % 3 ~= 0
		local out = if ring
			then tail:VectorToWorldSpace(Vector3.new(math.cos(angle), math.sin(angle), 0.18))
			else tail:VectorToWorldSpace(Vector3.new(math.cos(angle) * 0.3, math.sin(angle) * 0.3, 1))
		local size = 0.34 + 0.16 * ((i * 7) % 3)
		local part = plain(self._world, size, self._colours[(i % #self._colours) + 1])
		part.CFrame = tail
		table.insert(self._sparks, {
			part = part,
			age = 0,
			life = BURST_LIFE * (0.8 + 0.2 * ((i * 5) % 4) / 3),
			dir = out.Unit,
			speed = if ring then 8.5 else 6,
			size = size,
		})
	end
end

-- Streaks of light in the trail's colours stream back from the tail, longer and faster at speed: the look of a trail in a run.
local function streak(self: any)
	self._seed += 1
	local n = self._seed
	local width = 0.14 + 0.1 * ((n * 7) % 4) / 3
	local part = plain(self._world, width, self._colours[(n % #self._colours) + 1])
	part.Shape = Enum.PartType.Block
	part.Name = "TrailStreak"
	local length = 1.4 + 1.8 * ((n * 5) % 5) / 4
	part.Size = Vector3.new(width, width, length)
	local side = (((n * 13) % 9) - 4) / 4 -- -1 to 1
	local lift = (((n * 11) % 7) - 3) / 3
	table.insert(self._streaks, {
		part = part,
		age = 0,
		life = 0.6 + 0.35 * ((n * 3) % 4) / 3,
		dir = Vector3.new(side * 0.95, lift * 0.55, 0), -- where it starts, across the tail
		speed = 0.8 + 0.5 * ((n * 17) % 5) / 4,
		size = length,
	})
end

function ShopTrail.step(self: any, dt: number, tail: CFrame, reduced: boolean)
	-- time runs faster at speed: the ribbon sways quicker and the pieces stream and refill sooner
	self._preview:step(dt * (1 + 1.1 * self._speed), tail)
	if self._streamOn and not reduced and self._speed > 0 then
		self._emit += dt * (8 + 26 * self._speed)
		while self._emit >= 1 and #self._streaks < STREAKS do
			self._emit -= 1
			streak(self)
		end
		self._emit = math.min(self._emit, 1)
	end
	for i = #self._streaks, 1, -1 do
		local s = self._streaks[i]
		s.age += dt
		local u = s.age / s.life
		if u >= 1 or reduced or not self._streamOn then
			s.part:Destroy()
			table.remove(self._streaks, i)
		else
			local back = STREAK_REACH * s.speed * (0.25 + 0.75 * self._speed) * u
			s.part.CFrame = tail * CFrame.new(s.dir.X, s.dir.Y, s.size / 2 + back)
			s.part.Transparency = 0.12 + 0.88 * u * u
		end
	end
	for i = #self._sparks, 1, -1 do
		local s = self._sparks[i]
		s.age += dt
		local u = s.age / s.life
		if u >= 1 or reduced then
			s.part:Destroy()
			table.remove(self._sparks, i)
		else
			local eased = 1 - (1 - u) * (1 - u)
			s.part.Position = self._origin.Position + s.dir * (s.speed * s.life * eased)
			s.part.Size = Vector3.one * (s.size * (1 - 0.7 * u))
			s.part.Transparency = u * u
		end
	end
end

function ShopTrail.destroy(self: any)
	clearSparks(self)
	for _, s in self._streaks do
		s.part:Destroy()
	end
	table.clear(self._streaks)
	self._preview:destroy()
end

return ShopTrail
