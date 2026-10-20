--!strict
-- Visible bounds of a small icon built from rounded UI rectangles that is
-- rotated and scaled about its frame's centre (Lane 3). Used so HUD icons can
-- be centred by their visible artwork, not by their frame.
--
-- Shapes are in the icon frame's own (unrotated, unscaled) coordinates and
-- already include any outline (a UIStroke outline sits outside the frame and
-- widens the corner radius by its thickness). The extreme point of a rotated
-- rounded rectangle is the rotated corner of the rectangle inset by its
-- radius, pushed out by the radius, so the result is exact for these shapes.

local IconGeometry = {}

export type Shape = { x: number, y: number, w: number, h: number, r: number }

-- Returns the visible size and the visible centre relative to the frame's
-- centre (the rotation pivot), after rotation (degrees, Roblox convention:
-- positive turns clockwise on screen) and scale.
function IconGeometry.bounds(shapes: { Shape }, frameSize: Vector2, rotation: number, scale: number): (Vector2, Vector2)
	local angle = math.rad(rotation)
	local c, s = math.cos(angle), math.sin(angle)
	local minX, minY, maxX, maxY = math.huge, math.huge, -math.huge, -math.huge
	for _, shape in shapes do
		local r = math.min(shape.r, shape.w / 2, shape.h / 2)
		for _, corner in
			{
				Vector2.new(shape.x + r, shape.y + r),
				Vector2.new(shape.x + shape.w - r, shape.y + r),
				Vector2.new(shape.x + r, shape.y + shape.h - r),
				Vector2.new(shape.x + shape.w - r, shape.y + shape.h - r),
			}
		do
			local p = corner - frameSize / 2
			-- Screen y points down, so this is a clockwise turn for positive angles.
			local x = (p.X * c - p.Y * s) * scale
			local y = (p.X * s + p.Y * c) * scale
			local rr = r * scale
			minX = math.min(minX, x - rr)
			minY = math.min(minY, y - rr)
			maxX = math.max(maxX, x + rr)
			maxY = math.max(maxY, y + rr)
		end
	end
	return Vector2.new(maxX - minX, maxY - minY), Vector2.new(minX + maxX, minY + maxY) / 2
end

return IconGeometry
