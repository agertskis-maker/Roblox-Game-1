--!strict
-- TrailPreview: a trail moving behind the car on the Style turntable and the launch card (Lane 3, Round 3; Adam: "show them actively
-- moving behind the vehicle"). A ViewportFrame cannot show Trail or particle objects, so this is drawn in 2D behind the car: the
-- ribbon sways, bright pulses run down it, and a small pool of pieces streams away from the car. Cheap: at most 14 moving pieces,
-- one step from the screen's own update, nothing while the screen is shut. Reduce Motion shows the still ribbon.
--
--   local t = TrailPreview.new(parent, { position = UDim2, size = UDim2, z = 5 })
--   t:set(item?)   t:step(dt)   t:destroy()

local Prototype = script.Parent.Parent
local CarKit = require(Prototype.CarKit)
local GameIcons = require(Prototype.GameIcons)
local Motion = require(Prototype.Motion)

local make = CarKit.make

local TrailPreview = {}
TrailPreview.__index = TrailPreview

local POOL = 14

type Piece = {
	frame: GuiObject,
	stroke: UIStroke?,
	age: number,
	life: number,
	y: number,
	drift: number,
	size: number,
	spin: number,
}

-- How each trail's pieces look: size, how far they travel per second (share of the width), and their shape.
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

function TrailPreview.new(parent: Instance, o: { position: UDim2, size: UDim2, z: number }): any
	local self = setmetatable({}, TrailPreview) :: any
	self._holder = make("Frame", {
		Name = "TrailPreview",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = o.position,
		Size = o.size,
		ZIndex = o.z,
		Visible = false,
	}, parent)
	self._ribbon = make("ImageLabel", {
		Name = "TrailRibbon",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1),
		ScaleType = Enum.ScaleType.Stretch,
		ZIndex = o.z,
	}, self._holder)
	self._pulse = make("UIGradient", {
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(0.125, 0.45),
			NumberSequenceKeypoint.new(0.25, 0),
			NumberSequenceKeypoint.new(0.375, 0.45),
			NumberSequenceKeypoint.new(0.5, 0),
			NumberSequenceKeypoint.new(0.625, 0.45),
			NumberSequenceKeypoint.new(0.75, 0),
			NumberSequenceKeypoint.new(0.875, 0.45),
			NumberSequenceKeypoint.new(1, 0),
		}),
	}, self._ribbon)
	self._pieces = {} :: { Piece }
	self._clock = 0
	self._emit = 0
	self._z = o.z
	self._kind = nil
	self._colours = { CarKit.White }
	return self
end

local function clearPieces(self: any)
	for _, p in self._pieces do
		p.frame:Destroy()
	end
	table.clear(self._pieces)
end

function TrailPreview.set(self: any, item: any?)
	clearPieces(self)
	local uri = item and item.key and GameIcons.uri("ribbon_" .. item.key)
	self._holder.Visible = uri ~= nil
	self._ribbon.Image = uri or ""
	self._kind = if item and item.key then KIND[item.key] else nil
	self._colours = if item then item.colours else { CarKit.White }
end

local function spawnPiece(self: any)
	local kind = self._kind
	local colour = self._colours[math.random(1, #self._colours)]
	local size = kind.size * (0.7 + math.random() * 0.6)
	local z = self._z + 1
	local frame: GuiObject
	local stroke: UIStroke? = nil
	if kind.shape == "glow" then
		frame = make("ImageLabel", {
			BackgroundTransparency = 1,
			Image = GameIcons.uri("fx_glow") or "",
			ImageColor3 = colour,
		}, self._holder)
	else
		frame = make("Frame", { BackgroundColor3 = colour, BorderSizePixel = 0 }, self._holder)
		if kind.shape == "dot" or kind.shape == "ring" then
			make("UICorner", { CornerRadius = UDim.new(1, 0) }, frame)
		end
		if kind.shape == "ring" then
			(frame :: Frame).BackgroundTransparency = 0.8
			stroke = make(
				"UIStroke",
				{ Thickness = 2, Color = colour, ApplyStrokeMode = Enum.ApplyStrokeMode.Border },
				frame
			)
		end
	end
	frame.Name = "Piece"
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Size = UDim2.fromOffset(size, size)
	frame.ZIndex = z
	frame.Rotation = if kind.shape == "diamond" then 45 else math.random(0, 360)
	table.insert(self._pieces, {
		frame = frame,
		stroke = stroke,
		age = 0,
		life = 0.75 + math.random() * 0.5,
		y = 0.5 + (math.random() - 0.5) * 0.5,
		drift = (math.random() - 0.5) * 0.5,
		size = size,
		spin = if kind.shape == "square" then (math.random() - 0.5) * 500 else 0,
	})
end

function TrailPreview.step(self: any, dt: number)
	if not self._holder.Visible or Motion.reduced() then
		return
	end
	self._clock += dt
	local t = self._clock
	-- pulses run from the car toward the tail
	self._pulse.Offset = Vector2.new(-((t * 0.7) % 0.25), 0)
	self._ribbon.Rotation = math.sin(t * 2.3) * 1.6
	self._ribbon.Size = UDim2.fromScale(1, 1 + math.sin(t * 3.7) * 0.07)
	local kind = self._kind
	if not kind then
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
			p.frame:Destroy()
			table.remove(self._pieces, i)
		else
			-- the car is at the right end of the holder
			local x = 1 - u * kind.speed * p.life
			local fade = u * u
			p.frame.Position = UDim2.fromScale(x, p.y + p.drift * u * 0.4)
			p.frame.Rotation += p.spin * dt
			if p.frame:IsA("ImageLabel") then
				p.frame.ImageTransparency = 0.25 + 0.75 * fade
				p.frame.Size = UDim2.fromOffset(p.size * (1 + u), p.size * (1 + u))
			else
				if not p.stroke then
					(p.frame :: Frame).BackgroundTransparency = fade
				else
					p.stroke.Transparency = fade
				end
			end
		end
	end
end

function TrailPreview.destroy(self: any)
	clearPieces(self)
	self._holder:Destroy()
end

return TrailPreview
