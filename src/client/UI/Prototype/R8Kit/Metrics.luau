--!strict
-- R8Kit.Metrics (Lane 3 Round 8): the one number every kit piece needs from its card, how many real pixels one DESIGN pixel is.
-- A card is laid out in design pixels (the reference image's own pixels, card-relative: the Raceway card is 988 x 527) and scaled
-- uniformly by ONE UIScale at the card root; the card owner calls metrics:setScale(realCardWidth / design.X) whenever the card is
-- resized. Text must never be smaller than 16 real pixels (the style guide minimum), so text sizes go through textSize().
--
--   local m = Metrics.new(Vector2.new(988, 527))
--   m.design: Vector2        m.scale: number (real px per design px, starts at 1)       m.changed (Signal, fires the new scale)
--   m:setScale(s)            m:textSize(designSize) -> number     max(designSize, ceil(16 / scale))
--   m:bindText(trove, label, designSize)    sets label.TextSize now and again whenever the scale changes
--   m:destroy()
-- Every kit constructor takes `metrics: Metrics?`; without one the piece uses a private Metrics with scale 1.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Signal = require(ReplicatedStorage.Packages.Signal)
local Trove = require(ReplicatedStorage.Packages.Trove)

local Metrics = {}
Metrics.MinTextPx = 16

export type Metrics = {
	design: Vector2,
	scale: number,
	changed: any,
	setScale: (self: Metrics, s: number) -> (),
	textSize: (self: Metrics, designSize: number) -> number,
	bindText: (self: Metrics, trove: Trove.Trove, label: TextLabel, designSize: number) -> (),
	destroy: (self: Metrics) -> (),
}

local Obj = {}
Obj.__index = Obj

function Metrics.new(design: Vector2): Metrics
	local self = setmetatable({
		design = design,
		scale = 1,
		changed = Signal.new(),
	}, Obj)
	return (self :: any) :: Metrics
end

function Obj.setScale(self: any, s: number)
	s = math.max(s, 0.05)
	if math.abs(s - self.scale) < 1e-4 then
		return
	end
	self.scale = s
	self.changed:Fire(s)
end

function Obj.textSize(self: any, designSize: number): number
	return math.max(designSize, math.ceil(Metrics.MinTextPx / self.scale))
end

function Obj.bindText(self: any, trove: Trove.Trove, label: TextLabel, designSize: number)
	label.TextSize = self:textSize(designSize)
	trove:Add(self.changed:Connect(function()
		label.TextSize = self:textSize(designSize)
	end))
end

function Obj.destroy(self: any)
	self.changed:Destroy()
end

return Metrics
