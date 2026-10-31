--!strict
-- Shared sightline rules for the island dressing (Lane 3, build-time).
-- The lower falls seen from each plot entrance (Adam, 2026-10-21: a blossom tree hid it from
-- Plot06; a birch, a blossom tree, a willow and topiary hid it from other entrances): a plan
-- wedge from each entrance to the lower falls' width, inside which nothing may rise above the
-- sight ray from eye height (5.5) to the bottom of the falls (4 above the plunge pool).

local Cascade = require(script.Parent.Cascade)
local Layout = require(script.Parent.Parent.Layout)

local Sightlines = {}

-- The lower falls' width as seen from the park: 14 studs west to 12 east of the falls line, 4 in
-- front of the lower face (Task 4: x -116 to -90 after the move east; was -134 to -108).
local FALLS_Y = Cascade.LowerFaceY + 4
local FALLS_LEFT, FALLS_RIGHT = Vector2.new(Cascade.X - 14, FALLS_Y), Vector2.new(Cascade.X + 12, FALLS_Y)
local FALLS_BOTTOM, EYE = 4, 5.5

local function cross(a: Vector2, b: Vector2): number
	return a.X * b.Y - a.Y * b.X
end

-- The lowest sight-ray height over plan point p toward the lower falls, or nil outside every
-- entrance's wedge.
function Sightlines.fallsRayHeight(p: Vector2): number?
	local lowest: number? = nil
	for _, tri in Layout.Data.park.corridors do
		local e = tri[1]
		local a, b = FALLS_LEFT - e, FALLS_RIGHT - e
		local d = p - e
		if cross(a, d) * cross(a, b) >= 0 and cross(b, d) * cross(b, a) >= 0 then
			local mid = (a + b) / 2
			local t = d:Dot(mid) / mid:Dot(mid)
			if t > 0 and t < 1 then
				local h = EYE + (FALLS_BOTTOM - EYE) * t
				lowest = if lowest then math.min(lowest, h) else h
			end
		end
	end
	return lowest
end

-- Whether a round crown (plan centre, radius) whose top is at world height `top` would hide
-- part of the lower falls from an entrance (ray heights are world heights: the entrances and the
-- falls bottom are measured from the walking surface, y 0).
-- The crown is sampled densely (its centre and three rings of 16) because near an entrance the
-- wedge is only a few studs wide.
function Sightlines.blocksFalls(centre: Vector2, radius: number, top: number): boolean
	local function test(p: Vector2): boolean
		local ray = Sightlines.fallsRayHeight(p)
		return ray ~= nil and top > ray
	end
	if test(centre) then
		return true
	end
	for _, f in { 0.35, 0.7, 1 } do
		for k = 0, 15 do
			local a = k * math.pi / 8
			if test(centre + Vector2.new(math.cos(a), math.sin(a)) * radius * f) then
				return true
			end
		end
	end
	return false
end

-- The same test for a box footprint (four plan corners, top at world height): a 6 x 6 grid over it.
function Sightlines.boxBlocksFalls(corners: { Vector2 }, top: number): boolean
	local a, b, d = corners[1], corners[2], corners[3]
	for i = 0, 5 do
		for j = 0, 5 do
			local p = a + (b - a) * (i / 5) + (d - a) * (j / 5)
			local ray = Sightlines.fallsRayHeight(p)
			if ray and top > ray then
				return true
			end
		end
	end
	return false
end

return Sightlines
