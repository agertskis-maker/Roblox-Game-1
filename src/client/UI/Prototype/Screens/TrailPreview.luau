--!strict
-- TrailPreview: a trail coming out of the back of the car on the Style turntable and the launch card (Lane 3, Round 3; Adam: "show
-- them actively moving behind the vehicle", and it must stay on the tail however the car turns). A ViewportFrame cannot show Trail or
-- particle objects, so this is parts in the turntable's own 3D world, placed from the car's tail each step: the ribbon image on three
-- crossed planes, so it reads from every side, and a small pool of pieces streaming away. Cheap: at most 14 moving pieces, one step
-- from the screen's own update, nothing while the screen is shut. Reduce Motion shows the still ribbon.
--
--   local t = TrailPreview.new(world, { length = 6 })
--   t:set(item?)   t:step(dt, tail)   t:destroy()      -- tail: at the car's back, +Z pointing away from the car

local Prototype = script.Parent.Parent
local CarKit = require(Prototype.CarKit)
local GameIcons = require(Prototype.GameIcons)
local Motion = require(Prototype.Motion)

local TrailPreview = {}
TrailPreview.__index = TrailPreview

local POOL = 14
local WIDTH = 2.4
local STUDS_PER_PIXEL = 1 / 32 -- the kinds below are sized in pixels of the old drawn ribbon

type Piece = {
	part: Part,
	age: number,
	life: number,
	x: number,
	y: number,
	drift: number,
	spin: number,
	fadeFrom: number,
}

-- How each trail's pieces look: size, how far they travel per second (share of the length), and their shape.
local KIND: { [string]: { size: number, speed: number, shape: string, rate: number } } = {
	smoke = { size = 26, speed = 0.45, shape = "glow", rate = 9 },
	spark = { size = 7, speed = 0.95, shape = "dot", rate = 16 },
	bubble = { size = 15, speed = 0.4, shape = "ring", rate = 7 },
	neon = { size = 9, speed = 1.1, shape = "dot", rate = 10 },
	star = { size = 12, speed = 0.6, shape = "diamond", rate = 8 },
	flame = { size = 18, speed = 0.9, shape = "glow", rate = 16 },
	confetti = { size = 8, speed = 0.65, shape = "square", rate = 14 },
	rainbow = { size = 9, speed = 0.9, shape = "dot", rate = 12 },
	galaxy = { size = 7, speed = 0.55, shape = "diamond", rate = 12 },
}

local function plain(parent: Instance, name: string): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

-- Each plane's +X runs away from the car and its Front face carries the image, whose right end is the car's end. A Decal cannot be
-- mirrored, so the far side of the vertical plane is a second plane turned over about the ribbon's length.
local PLANE_TURNS = { 0, math.pi, math.pi / 2 }

function TrailPreview.new(world: Instance, o: { length: number? }): any
	local self = setmetatable({}, TrailPreview) :: any
	self._world = world
	self._length = o.length or 6
	self._planes = {} :: { Part }
	self._decals = {} :: { Decal }
	for _ in PLANE_TURNS do
		local plane = plain(world, "TrailRibbon")
		plane.Size = Vector3.new(self._length, WIDTH, 0.02)
		plane.Transparency = 1
		local decal = Instance.new("Decal")
		decal.Face = Enum.NormalId.Front
		decal.Parent = plane
		table.insert(self._planes, plane)
		table.insert(self._decals, decal)
	end
	self._pieces = {} :: { Piece }
	self._clock = 0
	self._emit = 0
	self._kind = nil
	self._colours = { CarKit.White }
	self._shown = false
	return self
end

local function clearPieces(self: any)
	for _, p in self._pieces do
		p.part:Destroy()
	end
	table.clear(self._pieces)
end

function TrailPreview.set(self: any, item: any?)
	clearPieces(self)
	local uri = item and item.key and GameIcons.uri("ribbon_" .. item.key)
	self._shown = uri ~= nil
	for i, plane in self._planes do
		self._decals[i].Texture = uri or ""
		plane.Parent = if uri then self._world else nil
	end
	self._kind = if item and item.key then KIND[item.key] else nil
	self._colours = if item then item.colours else { CarKit.White }
end

local function spawnPiece(self: any)
	local kind = self._kind
	local size = kind.size * STUDS_PER_PIXEL * (0.7 + math.random() * 0.6)
	local part = plain(self._world, "TrailPiece")
	part.Color = self._colours[math.random(1, #self._colours)]
	part.Size = Vector3.one * size
	local fadeFrom = 0
	if kind.shape == "glow" or kind.shape == "ring" or kind.shape == "dot" then
		part.Shape = Enum.PartType.Ball
	end
	if kind.shape == "glow" then
		part.Material = Enum.Material.Neon
		fadeFrom = 0.35
	elseif kind.shape == "ring" then
		fadeFrom = 0.65
	else
		part.Material = Enum.Material.Neon
	end
	table.insert(self._pieces, {
		part = part,
		age = 0,
		life = 0.75 + math.random() * 0.5,
		x = (math.random() - 0.5) * WIDTH * 0.5,
		y = (math.random() - 0.5) * WIDTH * 0.5,
		drift = (math.random() - 0.5) * 0.8,
		spin = if kind.shape == "square" then (math.random() - 0.5) * 8 else 0,
		fadeFrom = fadeFrom,
	})
end

function TrailPreview.step(self: any, dt: number, tail: CFrame)
	if not self._shown then
		return
	end
	local reduced = Motion.reduced()
	if not reduced then
		self._clock += dt
	end
	-- the ribbon sways a little from the tail
	local sway = math.sin(self._clock * 2.3) * 0.03
	local root = tail * CFrame.Angles(0, sway, 0)
	local along = root * CFrame.fromMatrix(Vector3.new(0, 0, self._length / 2), Vector3.zAxis, Vector3.yAxis)
	for i, plane in self._planes do
		plane.CFrame = along * CFrame.Angles(PLANE_TURNS[i], 0, 0)
	end
	local kind = self._kind
	if reduced or not kind then
		clearPieces(self)
		return
	end
	self._emit += dt * kind.rate
	while self._emit >= 1 and #self._pieces < POOL do
		self._emit -= 1
		spawnPiece(self)
	end
	self._emit = math.min(self._emit, 1)
	for i = #self._pieces, 1, -1 do
		local p = self._pieces[i]
		p.age += dt
		local u = p.age / p.life
		if u >= 1 then
			p.part:Destroy()
			table.remove(self._pieces, i)
		else
			local z = u * kind.speed * p.life * self._length
			local turn = if kind.shape == "diamond" then math.rad(45) else p.spin * p.age
			p.part.CFrame = root
				* CFrame.new(p.x + p.drift * u, p.y + p.drift * u * 0.5, z)
				* CFrame.Angles(turn, 0, turn)
			p.part.Transparency = p.fadeFrom + (1 - p.fadeFrom) * u * u
		end
	end
end

function TrailPreview.destroy(self: any)
	clearPieces(self)
	for _, plane in self._planes do
		plane:Destroy()
	end
end

return TrailPreview
