--!strict
-- Original icon art for the HUD prototype (Lane 3 preview), drawn from rounded Frames, UICorner,
-- UIStroke and rotation only, so nothing is copied, traced or uploaded. No logos.
--
--   Icons.draw(holder, name, colour?)   -- fills a square holder Frame with the icon; the art
--                                          is one child Frame named "Art" (attribute Icon = name)
--   Icons.Names                         -- every supported name
--
-- How the art is built: every icon is a few "groups". A group is a set of overlapping shapes
-- that share one silhouette outline: each shape is drawn once in navy ink, grown by the outline
-- width, then again in its fill colour on top, so overlaps never show interior seams. "Flat"
-- details (window panes, holes, lines) are drawn last with no outline. Rings (handles, shackles,
-- the oval track) are transparent frames with a stroke; an outlined ring draws a wider ink stroke
-- under the fill stroke. All geometry is in fractions of the holder, so it scales with the
-- holder and with any UIScale above it.
--
-- Outline width: 5.5% of the holder side, clamped to 1.25..3 px (about 1.8 px at 32 px, 3 px
-- from about 55 px), thin enough that the counters of the small icons stay open at 32 px.
-- The main colour defaults to white (icons sit on coloured buttons); Key, Coin, Flame, Bolt, Star
-- and Medal default to warm gold or orange. A supplied colour replaces the main fill only.
--
-- Assumes the legacy UIStroke placement (a Border stroke grows outward from the frame edge).

local PreviewTokens = require(script.Parent.PreviewTokens)

local Icons = {}

export type Name =
	"Garage"
	| "Shop"
	| "Missions"
	| "Settings"
	| "Track"
	| "Key"
	| "Sneaker"
	| "Flame"
	| "Coin"
	| "Flag"
	| "Check"
	| "Lock"
	| "Car"
	| "Bolt"
	| "Star"
	| "Close"
	| "Speaker"
	| "Music"
	| "Motion"
	| "Portal"
	| "Timer"
	| "Medal"
	| "Hop"
	| "Gamepad"
	| "Keyboard"
	| "Touch"

Icons.Names = {
	"Garage",
	"Shop",
	"Missions",
	"Settings",
	"Track",
	"Key",
	"Sneaker",
	"Flame",
	"Coin",
	"Flag",
	"Check",
	"Lock",
	"Car",
	"Bolt",
	"Star",
	"Close",
	"Speaker",
	"Music",
	"Motion",
	"Portal",
	"Timer",
	"Medal",
	"Hop",
	"Gamepad",
	"Keyboard",
	"Touch",
}

local C = PreviewTokens.Color
local INK = C.Ink
local WHITE = C.White
local GOLD = C.KeysLight
local GOLD_DEEP = C.KeysDeep
local TEAL = C.HopLight
local ORANGE = C.PrimaryLight
local GREEN = C.Success
local BLUE = Color3.fromRGB(110, 190, 255)

-- One shape, in fractions of the holder (centre x, y, size w, h).
type Spec = {
	x: number,
	y: number,
	w: number,
	h: number,
	r: number?, -- corner radius as a fraction of the holder side; -1 = pill / circle
	rot: number?,
	c: Color3?, -- fill colour (default: the icon's main colour; Ink for flat details)
}

type Pen = {
	art: Frame,
	px: number, -- holder side in design px
	t: number, -- outline width in px
	z: number, -- next ZIndex
	main: Color3,
}

local function rect(x: number, y: number, w: number, h: number, r: number?, c: Color3?, rot: number?): Spec
	return { x = x, y = y, w = w, h = h, r = r, c = c, rot = rot }
end

local function circle(x: number, y: number, d: number, c: Color3?): Spec
	return { x = x, y = y, w = d, h = d, r = -1, c = c }
end

-- A round-ended bar from (ax, ay) to (bx, by).
local function bar(ax: number, ay: number, bx: number, by: number, width: number, c: Color3?): Spec
	local dx, dy = bx - ax, by - ay
	return {
		x = (ax + bx) / 2,
		y = (ay + by) / 2,
		w = math.sqrt(dx * dx + dy * dy) + width,
		h = width,
		r = -1,
		rot = math.deg(math.atan2(dy, dx)),
		c = c,
	}
end

local function piece(pen: Pen, spec: Spec, colour: Color3, grow: number, z: number): Frame
	local f = Instance.new("Frame")
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Position = UDim2.fromScale(spec.x, spec.y)
	f.Size = UDim2.new(spec.w, grow * 2, spec.h, grow * 2)
	f.Rotation = spec.rot or 0
	f.BackgroundColor3 = colour
	f.BorderSizePixel = 0
	f.ZIndex = z
	local r = spec.r or 0
	if r < 0 then
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0.5, 0)
		c.Parent = f
	elseif r > 0 or grow > 0 then
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0, r * pen.px + grow)
		c.Parent = f
	end
	f.Parent = pen.art
	return f
end

-- Shapes sharing one silhouette outline.
local function group(pen: Pen, specs: { Spec })
	local z = pen.z
	for _, spec in specs do
		piece(pen, spec, INK, pen.t, z)
	end
	for i, spec in specs do
		piece(pen, spec, spec.c or pen.main, 0, z + i)
	end
	pen.z = z + #specs + 1
end

-- Details with no outline, drawn in order on top.
local function flat(pen: Pen, specs: { Spec })
	for _, spec in specs do
		piece(pen, spec, spec.c or INK, 0, pen.z)
		pen.z += 1
	end
end

-- A hollow ring or stadium (w, h = outer size; thick = band width), optionally outlined.
local function ring(pen: Pen, x: number, y: number, w: number, h: number, thick: number, c: Color3?, outlined: boolean?)
	local band = thick * pen.px
	local function layer(extra: number, colour: Color3, z: number)
		local f = Instance.new("Frame")
		f.AnchorPoint = Vector2.new(0.5, 0.5)
		f.Position = UDim2.fromScale(x, y)
		f.Size = UDim2.new(w, -2 * (band + extra), h, -2 * (band + extra))
		f.BackgroundTransparency = 1
		f.ZIndex = z
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0.5, 0)
		corner.Parent = f
		local s = Instance.new("UIStroke")
		s.Thickness = band + 2 * extra
		s.Color = colour
		s.LineJoinMode = Enum.LineJoinMode.Round
		s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		s.Parent = f
		f.Parent = pen.art
	end
	if outlined ~= false then
		layer(pen.t, INK, pen.z)
		pen.z += 1
	end
	layer(0, c or pen.main, pen.z)
	pen.z += 1
end

type Painter = (pen: Pen) -> ()

local painters: { [string]: Painter } = {}
local defaults: { [string]: Color3 } = {
	Key = GOLD,
	Coin = GOLD,
	Flame = ORANGE,
	Bolt = GOLD,
	Star = GOLD,
	Medal = GOLD,
}

-- Garage: a building with a wide canopy and a half-open door with a small car inside.
painters.Garage = function(pen)
	group(pen, { rect(0.5, 0.62, 0.8, 0.56, 0.08), rect(0.5, 0.32, 0.94, 0.17, -1) })
	flat(pen, {
		rect(0.5, 0.68, 0.56, 0.4, 0.04, INK),
		rect(0.5, 0.52, 0.5, 0.05, -1, pen.main),
		rect(0.5, 0.59, 0.5, 0.05, -1, pen.main),
		rect(0.5, 0.74, 0.18, 0.08, 0.03, ORANGE),
		rect(0.5, 0.8, 0.38, 0.09, -1, ORANGE),
		circle(0.4, 0.85, 0.07, pen.main),
		circle(0.6, 0.85, 0.07, pen.main),
	})
end

-- Shop: a friendly shopping bag with a round handle and a small smile.
painters.Shop = function(pen)
	ring(pen, 0.5, 0.3, 0.38, 0.38, 0.075)
	group(pen, { rect(0.5, 0.63, 0.76, 0.56, 0.1), bar(0.14, 0.37, 0.86, 0.37, 0.11) })
	flat(pen, {
		circle(0.4, 0.58, 0.075),
		circle(0.6, 0.58, 0.075),
		bar(0.42, 0.68, 0.47, 0.72, 0.05),
		bar(0.47, 0.72, 0.53, 0.72, 0.05),
		bar(0.53, 0.72, 0.58, 0.68, 0.05),
	})
end

-- Missions: a clipboard with lines and a green tick.
painters.Missions = function(pen)
	group(pen, { rect(0.46, 0.55, 0.7, 0.8, 0.1) })
	group(pen, { rect(0.46, 0.17, 0.34, 0.13, 0.05, C.PanelShade) })
	flat(pen, {
		bar(0.26, 0.38, 0.6, 0.38, 0.05),
		bar(0.26, 0.52, 0.5, 0.52, 0.05),
		bar(0.26, 0.66, 0.42, 0.66, 0.05),
	})
	group(pen, { bar(0.5, 0.68, 0.6, 0.79, 0.12, GREEN), bar(0.6, 0.79, 0.86, 0.48, 0.12, GREEN) })
end

-- Settings: an eight-tooth gear with an open centre.
painters.Settings = function(pen)
	local specs = { circle(0.5, 0.5, 0.62) }
	for _, a in { 0, 45, 90, 135 } do
		table.insert(specs, rect(0.5, 0.5, 0.9, 0.19, 0.04, nil, a))
	end
	group(pen, specs)
	flat(pen, { circle(0.5, 0.5, 0.24) })
end

-- Track: a small oval racetrack with a chequered flag planted on it.
painters.Track = function(pen)
	ring(pen, 0.45, 0.6, 0.82, 0.52, 0.1)
	group(pen, { bar(0.72, 0.52, 0.72, 0.1, 0.06), rect(0.83, 0.18, 0.22, 0.16, 0.02) })
	flat(pen, { rect(0.775, 0.14, 0.1, 0.07, 0), rect(0.875, 0.21, 0.1, 0.07, 0) })
end

-- Key: a round head and a diagonal shaft with two teeth.
painters.Key = function(pen)
	ring(pen, 0.32, 0.32, 0.42, 0.42, 0.1)
	group(pen, {
		bar(0.45, 0.45, 0.84, 0.84, 0.13),
		bar(0.7, 0.7, 0.79, 0.61, 0.11),
		bar(0.58, 0.58, 0.65, 0.51, 0.1),
	})
end

-- Sneaker: a rounded running shoe with a teal sole and laces.
painters.Sneaker = function(pen)
	group(pen, { rect(0.38, 0.52, 0.44, 0.38, 0.14), bar(0.4, 0.63, 0.84, 0.65, 0.22) })
	group(pen, { bar(0.12, 0.8, 0.88, 0.8, 0.12, TEAL) })
	flat(pen, { bar(0.44, 0.47, 0.52, 0.5, 0.05), bar(0.5, 0.41, 0.58, 0.45, 0.05) })
end

-- Flame: a teardrop with a yellow core.
painters.Flame = function(pen)
	group(pen, { circle(0.5, 0.64, 0.6), rect(0.5, 0.42, 0.42, 0.42, 0.1, nil, 45) })
	flat(pen, { circle(0.5, 0.71, 0.32, GOLD), rect(0.5, 0.6, 0.22, 0.22, 0.05, GOLD, 45) })
end

-- Coin: a gold disk with an inner rim and a centre mark (no currency symbol).
painters.Coin = function(pen)
	group(pen, { circle(0.5, 0.5, 0.84) })
	ring(pen, 0.5, 0.5, 0.6, 0.6, 0.05, GOLD_DEEP, false)
	flat(pen, { bar(0.5, 0.36, 0.5, 0.64, 0.1, GOLD_DEEP) })
end

-- Flag: a chequered flag on a pole.
painters.Flag = function(pen)
	group(pen, { bar(0.2, 0.12, 0.2, 0.9, 0.08), rect(0.56, 0.33, 0.64, 0.42, 0.03) })
	local cells = {}
	local cw, ch = 0.64 / 3, 0.42 / 2
	for _, cell in { { 0, 0 }, { 2, 0 }, { 1, 1 } } do
		table.insert(cells, rect(0.24 + (cell[1] + 0.5) * cw, 0.12 + (cell[2] + 0.5) * ch, cw, ch, 0))
	end
	flat(pen, cells)
end

-- Check: a chunky tick.
painters.Check = function(pen)
	group(pen, { bar(0.2, 0.52, 0.42, 0.74, 0.16), bar(0.42, 0.74, 0.82, 0.3, 0.16) })
end

-- Lock: a padlock with a shackle and keyhole.
painters.Lock = function(pen)
	ring(pen, 0.5, 0.38, 0.46, 0.52, 0.1)
	group(pen, { rect(0.5, 0.66, 0.7, 0.5, 0.1) })
	flat(pen, { circle(0.5, 0.61, 0.13), bar(0.5, 0.63, 0.5, 0.76, 0.07) })
end

-- Car: a side-view compact with navy windows and wheels.
painters.Car = function(pen)
	group(pen, { rect(0.5, 0.6, 0.86, 0.26, 0.1), rect(0.46, 0.43, 0.5, 0.24, 0.1) })
	flat(pen, {
		rect(0.46, 0.44, 0.38, 0.13, 0.03),
		rect(0.47, 0.44, 0.04, 0.13, 0, pen.main),
		rect(0.89, 0.56, 0.04, 0.07, 0.01, GOLD),
	})
	group(pen, { circle(0.28, 0.74, 0.26, INK), circle(0.72, 0.74, 0.26, INK) })
	flat(pen, { circle(0.28, 0.74, 0.1, pen.main), circle(0.72, 0.74, 0.1, pen.main) })
end

-- Bolt: a zigzag lightning bolt.
painters.Bolt = function(pen)
	group(pen, {
		bar(0.64, 0.08, 0.34, 0.52, 0.18),
		bar(0.34, 0.52, 0.66, 0.48, 0.16),
		bar(0.66, 0.48, 0.38, 0.92, 0.16),
	})
end

-- Star: a chunky five-ray star with rounded points.
painters.Star = function(pen)
	local cx, cy = 0.5, 0.54
	local specs = { circle(cx, cy, 0.42) }
	for k = 0, 4 do
		local a = math.rad(-90 + 72 * k)
		table.insert(specs, bar(cx, cy, cx + 0.42 * math.cos(a), cy + 0.42 * math.sin(a), 0.24))
	end
	group(pen, specs)
end

-- Close: a rounded X.
painters.Close = function(pen)
	group(pen, { bar(0.25, 0.25, 0.75, 0.75, 0.18), bar(0.75, 0.25, 0.25, 0.75, 0.18) })
end

-- Speaker: a box and cone with two sound bars.
painters.Speaker = function(pen)
	group(pen, { rect(0.24, 0.5, 0.22, 0.32, 0.05), rect(0.42, 0.5, 0.2, 0.62, 0.06) })
	group(pen, { bar(0.66, 0.4, 0.66, 0.6, 0.08), bar(0.81, 0.3, 0.81, 0.7, 0.08) })
end

-- Music: two beamed notes.
painters.Music = function(pen)
	group(pen, {
		rect(0.32, 0.76, 0.28, 0.21, -1, nil, -20),
		rect(0.72, 0.68, 0.28, 0.21, -1, nil, -20),
		bar(0.44, 0.74, 0.44, 0.2, 0.08),
		bar(0.84, 0.66, 0.84, 0.12, 0.08),
		bar(0.44, 0.2, 0.84, 0.12, 0.14),
	})
end

-- Motion: a wave line.
painters.Motion = function(pen)
	local pts = { { 0.1, 0.6 }, { 0.3, 0.38 }, { 0.5, 0.6 }, { 0.7, 0.38 }, { 0.9, 0.6 } }
	local specs = {}
	for i = 1, #pts - 1 do
		table.insert(specs, bar(pts[i][1], pts[i][2], pts[i + 1][1], pts[i + 1][2], 0.13))
	end
	group(pen, specs)
end

-- Portal: an upright oval with a teal inner swirl ring.
painters.Portal = function(pen)
	ring(pen, 0.5, 0.5, 0.66, 0.88, 0.1)
	ring(pen, 0.5, 0.53, 0.34, 0.5, 0.075, TEAL)
	flat(pen, { circle(0.5, 0.56, 0.12, pen.main) })
end

-- Timer: a stopwatch with crown, side button and two hands.
painters.Timer = function(pen)
	group(pen, {
		rect(0.5, 0.13, 0.24, 0.1, 0.03),
		rect(0.5, 0.2, 0.1, 0.1, 0),
		rect(0.8, 0.27, 0.12, 0.09, 0.02, nil, 45),
		circle(0.5, 0.58, 0.72),
	})
	flat(pen, { bar(0.5, 0.58, 0.5, 0.37, 0.07), bar(0.5, 0.58, 0.65, 0.66, 0.07), circle(0.5, 0.58, 0.1) })
end

-- Medal: a gold disk on a V of blue ribbon.
painters.Medal = function(pen)
	group(pen, { bar(0.3, 0.08, 0.44, 0.5, 0.18, BLUE), bar(0.7, 0.08, 0.56, 0.5, 0.18, BLUE) })
	group(pen, { circle(0.5, 0.66, 0.54) })
	ring(pen, 0.5, 0.66, 0.36, 0.36, 0.05, GOLD_DEEP, false)
	flat(pen, { circle(0.5, 0.66, 0.1, GOLD_DEEP) })
end

-- Hop: an arc rising from the ground to an arrowhead at the upper right.
painters.Hop = function(pen)
	local pts = { { 0.16, 0.86 }, { 0.2, 0.58 }, { 0.36, 0.38 }, { 0.6, 0.28 } }
	local specs = {}
	for i = 1, #pts - 1 do
		table.insert(specs, bar(pts[i][1], pts[i][2], pts[i + 1][1], pts[i + 1][2], 0.13))
	end
	local dx, dy = pts[4][1] - pts[3][1], pts[4][2] - pts[3][2]
	local a = math.atan2(dy, dx)
	local tx, ty = pts[4][1] + 0.1 * math.cos(a), pts[4][2] + 0.1 * math.sin(a)
	table.insert(specs, bar(pts[4][1], pts[4][2], tx, ty, 0.13))
	for _, side in { 1, -1 } do
		local b = a + side * math.rad(140)
		table.insert(specs, bar(tx, ty, tx + 0.26 * math.cos(b), ty + 0.26 * math.sin(b), 0.13))
	end
	group(pen, specs)
end

-- Gamepad: a rounded controller with a cross pad and two buttons.
painters.Gamepad = function(pen)
	group(pen, { rect(0.5, 0.5, 0.9, 0.42, 0.2), circle(0.24, 0.66, 0.34), circle(0.76, 0.66, 0.34) })
	flat(pen, {
		bar(0.18, 0.52, 0.34, 0.52, 0.07),
		bar(0.26, 0.44, 0.26, 0.6, 0.07),
		circle(0.7, 0.46, 0.1),
		circle(0.8, 0.56, 0.1),
	})
end

-- Keyboard: a single key cap (base and raised top face).
painters.Keyboard = function(pen)
	group(pen, { rect(0.5, 0.55, 0.8, 0.7, 0.16, pen.main:Lerp(INK, 0.2)) })
	group(pen, { rect(0.5, 0.47, 0.58, 0.46, 0.1) })
end

-- Touch: a pointing finger with a tap ripple.
painters.Touch = function(pen)
	ring(pen, 0.48, 0.24, 0.38, 0.38, 0.045)
	group(pen, {
		bar(0.48, 0.26, 0.48, 0.66, 0.2),
		rect(0.58, 0.76, 0.46, 0.34, 0.14),
		bar(0.66, 0.56, 0.66, 0.68, 0.17),
		bar(0.78, 0.6, 0.78, 0.72, 0.15),
	})
end

-- Fills `holder` (a square Frame) with the named icon. The art is one child Frame "Art".
function Icons.draw(holder: Frame, name: Name, colour: Color3?)
	local px = holder.Size.X.Offset
	if px <= 0 then
		px = holder.AbsoluteSize.X
	end
	if px <= 0 then
		px = 32
	end
	local art = Instance.new("Frame")
	art.Name = "Art"
	art.BackgroundTransparency = 1
	art.Size = UDim2.fromScale(1, 1)
	art.ZIndex = holder.ZIndex
	local pen: Pen = {
		art = art,
		px = px,
		t = math.clamp(px * 0.055, 1.25, 3),
		z = holder.ZIndex + 1,
		main = colour or defaults[name] or WHITE,
	}
	local painter = painters[name]
	if painter then
		painter(pen)
	end
	art:SetAttribute("Icon", name)
	art.Parent = holder
end

return Icons
