--!strict
-- ILLUSTRATED icons for the rebuilt arcade HUD (Lane 3 preview, worker HA, 2026-10-22; ledger
-- vault/design/specs/hud-rebuild-downtown-b.md: V-02, V-04, S-05 and art for H-02/H-03/H-04/
-- H-06/H-07, U-01, U-07, K-02). Original art drawn only from Frames, UICorner, UIStroke,
-- UIGradient and rotation: no images, nothing traced or copied from the references (their
-- qualities are imitated: a clear silhouette, a little illustrated depth, a purposeful tilt).
--
--   Icons2.draw(holder, name, opts?) -> boolean   -- false for an unknown name (Arcade falls back)
--   Icons2.keyLock(holder) -> { shackle, key, body } -- the Keys centre with movable parts
--   Icons2.Names                                   -- every supported name
--
-- opts = { tint: Color3? (replaces the main fill), tilt: number? (degrees; replaces the icon's
-- default sticker tilt) }. The art is one child Frame "Art" of the holder with attributes
-- Icon = name, IconSet = "Icons2", Frames = Frame count (budget: icons <= 40, tiles <= 60).
--
-- How an icon is built (one look across the set):
--   * a GROUP is a few overlapping shapes that share one silhouette: each shape is drawn in ink
--     grown by the outline width, then in a darker "lip" colour, then its face shrunk by the
--     depth and shifted up-left, so every silhouette shows a thin darker lower-right face (light
--     from the top-left everywhere);
--   * faces carry a vertical gradient measured over the whole group (light at the top, the base
--     colour from the middle, slightly deeper at the bottom), so overlaps show no seams;
--   * flat details (windows, ribbons, hands) have no outline; one small white highlight per icon
--     sits on the main mass, top-left.
-- Outline: 5.8% of the holder side clamped 1.5..3.5 px (about 1.9 px at 32 px, so small counters
-- stay open); depth 5% clamped 1..3 px. District tiles use 60% of both inside the scene.
-- Geometry is in fractions of the holder, so the art follows any UIScale above it.
-- Assumes the legacy UIStroke placement (a Border stroke grows outward from the frame edge).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PreviewTokens = require(script.Parent.PreviewTokens)
local Tokens = require(ReplicatedStorage.Shared.UI.Tokens)

local Icons2 = {}

local A = PreviewTokens.Arcade
local C = PreviewTokens.Color
local INK = A.Ink
local WHITE = Color3.new(1, 1, 1)

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

-- TOKEN CANDIDATES (icon palette; preview values, listed in the HA report)
local GOLD = rgb(255, 204, 48) -- trophy, star, ribbon, padlock body (Keys gold family)
local SILVER = rgb(206, 216, 232) -- shackles, cart frame, clip
local KEY_WHITE = rgb(242, 246, 255) -- the inserted key (stands off the gold body)
local GIFT_RED = rgb(238, 58, 78)
local BOOK_ORANGE = rgb(255, 122, 48) -- book cover (contrasts the cyan Garage fill)
local PAGE = rgb(252, 246, 228)
local BOARD_VIOLET = rgb(128, 98, 232) -- clipboard (contrasts the orange Missions fill)
local TICK_GREEN = rgb(56, 204, 92)
local CAR_CYAN = rgb(48, 206, 248) -- the collection's colour (matches the Cars face)
local CAR_CYAN_DEEP = rgb(18, 132, 214)
local GLASS = rgb(206, 244, 255)
local FLAME = rgb(250, 96, 40)
local NOTE_PINK = rgb(255, 92, 186)
local EVENT_ORANGE = rgb(255, 124, 56)
local ASPHALT = rgb(78, 88, 110)
local GRASS = rgb(92, 200, 92)
local STAMP_RED = rgb(226, 52, 62)
local WARN_ORANGE = rgb(255, 146, 28)
local BRICK = rgb(196, 78, 58)
local CREAM = rgb(248, 234, 198)
local COPPER = rgb(104, 172, 132)
local WATER = rgb(40, 132, 222)
local STEEL_RED = rgb(236, 96, 54)
local TEAL_GLASS = rgb(72, 192, 204)
local TREE = rgb(60, 172, 82)
local STONE = rgb(214, 218, 228)

export type Options = { tint: Color3?, tilt: number? }

export type KeyLockParts = {
	shackle: Frame, -- lift it (Position offset) or rotate it to open the lock
	key: Frame, -- rotates about the keyhole (its centre); 0 = pointing right, 90 = turned
	body: Frame,
}

-- One shape in fractions of the current container (centre x, y; size w, h).
type Spec = {
	x: number,
	y: number,
	w: number,
	h: number,
	r: number?, -- corner radius as a fraction of the container side; -1 = pill / circle
	rot: number?,
	c: Color3?, -- fill (default: the icon's main colour; Ink for flat details)
	flat: boolean?, -- in a group: no lip (fillers that only abut other shapes)
}

type Pen = {
	parent: GuiObject,
	px: number, -- current container side in px
	t: number, -- outline width in px
	d: number, -- depth (lip) in px
	z: number,
	main: Color3,
	frames: { n: number },
}

local function lighten(c: Color3, k: number): Color3
	return c:Lerp(WHITE, k)
end

local function darken(c: Color3, k: number): Color3
	return c:Lerp(INK, k)
end

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

local function flatSpec(s: Spec): Spec
	s.flat = true
	return s
end

local function newFrame(pen: Pen, name: string?): Frame
	local f = Instance.new("Frame")
	if name then
		f.Name = name
	end
	f.BorderSizePixel = 0
	pen.frames.n += 1
	return f
end

local function piece(pen: Pen, s: Spec, colour: Color3, grow: number, shrink: number, z: number): Frame
	local f = newFrame(pen)
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Position = UDim2.new(s.x, -shrink / 2, s.y, -shrink / 2)
	f.Size = UDim2.new(s.w, grow * 2 - shrink, s.h, grow * 2 - shrink)
	f.Rotation = s.rot or 0
	f.BackgroundColor3 = colour
	f.ZIndex = z
	local r = s.r or 0
	if r < 0 then
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0.5, 0)
		corner.Parent = f
	elseif r > 0 or grow > 0 then
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, math.max(r * pen.px + grow - shrink / 2, 0))
		corner.Parent = f
	end
	f.Parent = pen.parent
	return f
end

-- Vertical extent of a (possibly rotated) shape, in container fractions.
local function vExtent(s: Spec): (number, number)
	local a = math.rad(s.rot or 0)
	local half = (math.abs(s.w * math.sin(a)) + math.abs(s.h * math.cos(a))) / 2
	return s.y - half, s.y + half
end

-- The shared face ramp: light at the top, the base colour from 55%, a little deeper at the bottom.
local function ramp(c: Color3, g: number): Color3
	g = math.clamp(g, 0, 1)
	if g < 0.55 then
		return lighten(c, 0.42 * (1 - g / 0.55))
	end
	return darken(c, 0.16 * (g - 0.55) / 0.45)
end

-- Shapes sharing one outlined silhouette with a lip and a group-wide gradient.
local function group(pen: Pen, specs: { Spec })
	local y0, y1 = math.huge, -math.huge
	for _, s in specs do
		local a, b = vExtent(s)
		y0 = math.min(y0, a)
		y1 = math.max(y1, b)
	end
	local span = math.max(y1 - y0, 1e-3)
	local z = pen.z
	for _, s in specs do
		piece(pen, s, INK, pen.t, 0, z)
	end
	if pen.d > 0 then
		for _, s in specs do
			if not s.flat then
				piece(pen, s, darken(s.c or pen.main, 0.42), 0, 0, z + 1)
			end
		end
	end
	for _, s in specs do
		local colour = s.c or pen.main
		local face = piece(pen, s, WHITE, 0, if s.flat then 0 else pen.d, z + 2)
		local top, bottom = vExtent(s)
		local g0, g1 = (top - y0) / span, (bottom - y0) / span
		local grad = Instance.new("UIGradient")
		grad.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, ramp(colour, g0)),
			ColorSequenceKeypoint.new(0.5, ramp(colour, (g0 + g1) / 2)),
			ColorSequenceKeypoint.new(1, ramp(colour, g1)),
		})
		grad.Rotation = 90 - (s.rot or 0)
		grad.Parent = face
	end
	pen.z = z + 3
end

-- Details with no outline, drawn in order on top.
local function flat(pen: Pen, specs: { Spec })
	for _, s in specs do
		piece(pen, s, s.c or INK, 0, 0, pen.z)
		pen.z += 1
	end
end

-- The one small highlight (a soft white pill).
local function shine(pen: Pen, x: number, y: number, w: number, h: number, rot: number?)
	local f = piece(pen, rect(x, y, w, h, -1, nil, rot), WHITE, 0, 0, pen.z)
	f.BackgroundTransparency = 0.18
	pen.z += 1
end

-- A hollow ring or stadium (w, h = outer size; thick = band width). Outlined rings get ink,
-- a lip and a face; plain rings are one stroke.
local function ring(pen: Pen, x: number, y: number, w: number, h: number, thick: number, c: Color3?, outlined: boolean?)
	local band = thick * pen.px
	local colour = c or pen.main
	local function layer(extra: number, thin: number, shift: number, fill: Color3, gradient: boolean)
		local f = newFrame(pen)
		f.AnchorPoint = Vector2.new(0.5, 0.5)
		f.Position = UDim2.new(x, -shift, y, -shift)
		f.Size = UDim2.new(w, -2 * (band + extra), h, -2 * (band + extra))
		f.BackgroundTransparency = 1
		f.ZIndex = pen.z
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0.5, 0)
		corner.Parent = f
		local s = Instance.new("UIStroke")
		s.Thickness = math.max(band + 2 * extra - thin, 0.5)
		s.Color = if gradient then WHITE else fill
		s.LineJoinMode = Enum.LineJoinMode.Round
		s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		s.Parent = f
		if gradient then
			local g = Instance.new("UIGradient")
			g.Color = ColorSequence.new(lighten(fill, 0.4), darken(fill, 0.08))
			g.Rotation = 90
			g.Parent = s
		end
		f.Parent = pen.parent
		pen.z += 1
	end
	if outlined == false then
		layer(0, 0, 0, colour, false)
		return
	end
	layer(pen.t, 0, 0, INK, false)
	layer(0, 0, 0, darken(colour, 0.42), false)
	layer(0, pen.d / 2, pen.d / 2, colour, true)
end

-- A square sub-container (fractions of the current container); painting inside it uses its own
-- fractions. Used for parts that rotate as a unit (cars, key, shackle).
local function within(pen: Pen, x: number, y: number, size: number, rot: number, name: string, fn: () -> ()): Frame
	local f = newFrame(pen, name)
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Position = UDim2.fromScale(x, y)
	f.Size = UDim2.fromScale(size, size)
	f.Rotation = rot
	f.BackgroundTransparency = 1
	f.ZIndex = pen.z
	f.Parent = pen.parent
	local oldParent, oldPx = pen.parent, pen.px
	pen.parent = f
	pen.px = oldPx * size
	fn()
	pen.parent = oldParent
	pen.px = oldPx
	return f
end

type Painter = (pen: Pen) -> ()
local painters: { [string]: Painter } = {}
local defaults: { [string]: Color3 } = {}
local tilts: { [string]: number } = {}

-- SHARED PARTS ------------------------------------------------------------------------------

-- A chunky side-view hatchback filling its container (original proportions). `glass` replaces the pale window
-- colour (the Hop icon uses a dark pane so the roofline still reads on a white body and in greyscale).
local function carShape(pen: Pen, colour: Color3, withShine: boolean, glass: Color3?)
	group(pen, {
		rect(0.5, 0.6, 0.92, 0.28, 0.12, colour),
		rect(0.45, 0.42, 0.52, 0.26, 0.11, colour),
	})
	flat(pen, {
		rect(0.44, 0.43, 0.4, 0.13, 0.04, glass or GLASS),
		rect(0.47, 0.43, 0.045, 0.15, 0, colour),
		rect(0.935, 0.56, 0.05, 0.08, 0.02, rgb(255, 230, 120)),
		circle(0.25, 0.76, 0.3, INK),
		circle(0.74, 0.76, 0.3, INK),
		circle(0.25, 0.76, 0.12, SILVER),
		circle(0.74, 0.76, 0.12, SILVER),
	})
	if withShine then
		shine(pen, 0.26, 0.52, 0.18, 0.05)
	end
end

-- Padlock body + shackle, optionally with the key. Returns the three containers.
local function lockParts(pen: Pen, withKey: boolean): (Frame, Frame, Frame?)
	local shackle = within(pen, 0.5, 0.5, 1, 0, "Shackle", function()
		ring(pen, 0.5, 0.36, 0.46, 0.52, 0.1, SILVER)
	end)
	local body = within(pen, 0.5, 0.5, 1, 0, "Body", function()
		group(pen, { rect(0.5, 0.66, 0.72, 0.48, 0.09) })
		flat(pen, { circle(0.5, 0.63, 0.15, INK) })
		if not withKey then
			flat(pen, { bar(0.5, 0.65, 0.5, 0.77, 0.075, INK) })
		end
		shine(pen, 0.3, 0.49, 0.18, 0.045)
	end)
	local key: Frame? = nil
	if withKey then
		-- centred on the keyhole so rotating it turns the key in place
		key = within(pen, 0.5, 0.63, 1, 0, "Key", function()
			group(pen, {
				circle(0.5, 0.5, 0.16, KEY_WHITE),
				bar(0.5, 0.5, 0.74, 0.5, 0.1, KEY_WHITE),
				circle(0.84, 0.5, 0.28, KEY_WHITE),
			})
			flat(pen, { circle(0.865, 0.5, 0.1, darken(GOLD, 0.55)) })
		end)
	end
	return shackle, body, key
end

-- MENU ICONS (sticker tilt) ---------------------------------------------------------------

-- Gift: a lidded present with a gold ribbon and a two-loop bow.
defaults.Gift = GIFT_RED
tilts.Gift = -10
painters.Gift = function(pen)
	group(pen, { rect(0.47, 0.67, 0.66, 0.48, 0.05) })
	group(pen, { rect(0.47, 0.67, 0.13, 0.48, 0, GOLD) })
	group(pen, { rect(0.47, 0.39, 0.82, 0.17, 0.05) })
	group(pen, { rect(0.47, 0.39, 0.15, 0.17, 0, GOLD) })
	group(pen, {
		rect(0.35, 0.21, 0.27, 0.17, -1, GOLD, 28),
		rect(0.59, 0.21, 0.27, 0.17, -1, GOLD, -28),
		circle(0.47, 0.27, 0.13, GOLD),
	})
	flat(pen, {
		rect(0.36, 0.21, 0.1, 0.06, -1, darken(GOLD, 0.35), 28),
		rect(0.58, 0.21, 0.1, 0.06, -1, darken(GOLD, 0.35), -28),
	})
	shine(pen, 0.24, 0.36, 0.13, 0.045)
end

-- Cart: a shop cart with a red basket and a small gold parcel peeking out.
defaults.Cart = GIFT_RED
tilts.Cart = -10
painters.Cart = function(pen)
	group(pen, { rect(0.62, 0.25, 0.24, 0.2, 0.03, GOLD) })
	flat(pen, { rect(0.62, 0.25, 0.06, 0.2, 0, GIFT_RED) })
	group(pen, {
		bar(0.06, 0.17, 0.2, 0.17, 0.1, SILVER),
		bar(0.2, 0.17, 0.3, 0.7, 0.085, SILVER),
		bar(0.3, 0.71, 0.84, 0.71, 0.085, SILVER),
	})
	group(pen, { rect(0.58, 0.47, 0.6, 0.34, 0.05) })
	flat(pen, {
		rect(0.58, 0.32, 0.56, 0.045, -1, lighten(GIFT_RED, 0.45)),
		rect(0.46, 0.5, 0.035, 0.2, -1, darken(GIFT_RED, 0.3)),
		rect(0.58, 0.5, 0.035, 0.2, -1, darken(GIFT_RED, 0.3)),
		rect(0.7, 0.5, 0.035, 0.2, -1, darken(GIFT_RED, 0.3)),
		circle(0.38, 0.86, 0.2, INK),
		circle(0.77, 0.86, 0.2, INK),
		circle(0.38, 0.86, 0.08, SILVER),
		circle(0.77, 0.86, 0.08, SILVER),
	})
	shine(pen, 0.38, 0.38, 0.12, 0.04)
end

-- GarageBook: the car book. A thick cover over a page block, a bookmark and a white car.
defaults.GarageBook = BOOK_ORANGE
tilts.GarageBook = -11
painters.GarageBook = function(pen)
	group(pen, { rect(0.67, 0.87, 0.09, 0.16, 0.01, GOLD) })
	group(pen, { rect(0.55, 0.55, 0.72, 0.74, 0.05, PAGE) })
	flat(pen, {
		rect(0.885, 0.57, 0.014, 0.6, 0, rgb(214, 202, 178)),
		rect(0.55, 0.885, 0.6, 0.014, 0, rgb(214, 202, 178)),
	})
	group(pen, { rect(0.46, 0.48, 0.72, 0.74, 0.06) })
	flat(pen, { rect(0.15, 0.48, 0.07, 0.68, 0.02, darken(pen.main, 0.25)) })
	within(pen, 0.5, 0.5, 0.54, 0, "Car", function()
		carShape(pen, WHITE, false)
	end)
	shine(pen, 0.3, 0.18, 0.2, 0.045)
end

-- Clipboard: a violet board, white sheet, silver clip, three rows and a bold green tick.
defaults.Clipboard = BOARD_VIOLET
tilts.Clipboard = -9
painters.Clipboard = function(pen)
	group(pen, { rect(0.48, 0.55, 0.72, 0.84, 0.07) })
	flat(pen, { rect(0.48, 0.58, 0.56, 0.66, 0.03, rgb(255, 252, 242)) })
	group(pen, { rect(0.48, 0.16, 0.36, 0.14, 0.04, SILVER), circle(0.48, 0.1, 0.15, SILVER) })
	flat(pen, {
		circle(0.48, 0.095, 0.055, INK),
		circle(0.29, 0.38, 0.09, TICK_GREEN),
		circle(0.29, 0.54, 0.09, TICK_GREEN),
		circle(0.29, 0.7, 0.09, rgb(200, 206, 218)),
		bar(0.39, 0.38, 0.64, 0.38, 0.05, rgb(170, 180, 204)),
		bar(0.39, 0.54, 0.6, 0.54, 0.05, rgb(170, 180, 204)),
		bar(0.39, 0.7, 0.52, 0.7, 0.05, rgb(170, 180, 204)),
	})
	group(pen, {
		bar(0.54, 0.76, 0.65, 0.88, 0.13, TICK_GREEN),
		bar(0.65, 0.88, 0.92, 0.55, 0.13, TICK_GREEN),
	})
	shine(pen, 0.22, 0.24, 0.05, 0.12)
end

-- STATS ICONS --------------------------------------------------------------------------------

-- CashStack: three fanned bills held by ONE gold paper band (original, uses the approved bill colours of the
-- CashIcon). Round 3 (R3-C1): the band is no longer a rectangle pasted on the front bill. It is a single loop
-- around the whole hand of bills, drawn on top of all of them as one outlined silhouette (so no bill outline
-- crosses it): a strip on each bill, square to that bill's long axis and at the same distance from its left
-- end, so it turns with the fan; the strips overlap a little where one bill's edge meets the next and share one
-- outline. Depth reads two ways: the front strip is lit and the strips behind it step darker, so a visible step
-- shows where one layer meets the next; and both ends stand a hair past the bills' edges (the top end past the
-- back bill, the bottom end past the front bill), where the band goes round behind and under the stack. The strips
-- are flat (no lip), so the band stays one clean ribbon.
local CASH_BAND_WIDTH = 0.12 -- of the holder
local CASH_BAND_LIFT = 0.02 -- how far the band's ends stand proud of the bills' edges
defaults.CashStack = Tokens.Color.BillFace
tilts.CashStack = -8
painters.CashStack = function(pen)
	local face = pen.main
	local colors = Tokens.Color
	-- A strip on one bill: the bill's centre, its tilt, the strip's distance along the bill's long axis from the
	-- centre (negative = toward the left end), its extent along the bill's short axis (v0 to v1, from the bill's
	-- centre; positive = down the bill), and how much it steps toward the shaded band colour (0 = lit).
	local function strip(cx: number, cy: number, tilt: number, u: number, v0: number, v1: number, mix: number): Spec
		local a = math.rad(tilt)
		local vm = (v0 + v1) / 2
		local x = cx + u * math.cos(a) - vm * math.sin(a)
		local y = cy + u * math.sin(a) + vm * math.cos(a)
		return rect(x, y, CASH_BAND_WIDTH, v1 - v0, 0.02, colors.BillBand:Lerp(colors.BillBandShade, mix), tilt)
	end
	group(pen, { rect(0.54, 0.36, 0.78, 0.36, 0.04, face:Lerp(colors.BillDark, 0.55), -14) })
	group(pen, { rect(0.5, 0.48, 0.8, 0.36, 0.04, face:Lerp(colors.BillDark, 0.25), -6) })
	group(pen, { rect(0.47, 0.63, 0.82, 0.38, 0.04, face, 2) })
	flat(pen, {
		rect(0.47, 0.63, 0.66, 0.24, 0.03, colors.BillLight, 2),
		rect(0.47, 0.63, 0.6, 0.18, 0.02, face, 2),
		circle(0.5, 0.63, 0.17, colors.BillLight),
		circle(0.5, 0.63, 0.08, colors.BillDark),
	})
	group(pen, {
		-- behind: from just past the back bill's top edge to a little way under the middle bill's top edge
		flatSpec(strip(0.54, 0.36, -14, -0.2245, -0.18 - CASH_BAND_LIFT, -0.073, 0.75)),
		-- middle: from its top edge to a little way under the front bill's top edge
		flatSpec(strip(0.5, 0.48, -6, -0.209, -0.18, -0.044, 0.4)),
		-- front: lit, from a little above its top edge to a little past its lower edge (it turns under there)
		flatSpec(strip(0.47, 0.63, 2, -0.2, -0.19 - 0.02, 0.19 + CASH_BAND_LIFT, 0)),
	})
	shine(pen, 0.62, 0.5, 0.16, 0.04, 2)
end

-- Car: the plain side-view car (card art, tinted with the car's paint).
defaults.Car = CAR_CYAN
painters.Car = function(pen)
	within(pen, 0.5, 0.5, 0.96, 0, "Car", function()
		carShape(pen, pen.main, true)
	end)
end

-- CarCount: a cyan car in front of a second car (the collection) with an inert "+" disc set
-- into the emblem behind the front wheel: same palette, no gloss, never a button.
defaults.CarCount = CAR_CYAN
tilts.CarCount = -6
painters.CarCount = function(pen)
	within(pen, 0.6, 0.34, 0.66, 0, "BackCar", function()
		group(pen, {
			rect(0.5, 0.6, 0.92, 0.28, 0.12, darken(pen.main, 0.3)),
			rect(0.45, 0.42, 0.52, 0.26, 0.11, darken(pen.main, 0.3)),
		})
	end)
	group(pen, { circle(0.8, 0.8, 0.34, CAR_CYAN_DEEP) })
	flat(pen, {
		rect(0.8, 0.8, 0.2, 0.07, -1, WHITE),
		rect(0.8, 0.8, 0.07, 0.2, -1, WHITE),
	})
	within(pen, 0.42, 0.5, 0.82, -4, "Car", function()
		carShape(pen, pen.main, true)
	end)
end

-- Flame (Heat): a teardrop flame with a side lick, a yellow core and a pale centre.
defaults.Flame = FLAME
tilts.Flame = -6
painters.Flame = function(pen)
	group(pen, {
		circle(0.5, 0.64, 0.62),
		rect(0.5, 0.42, 0.42, 0.42, 0.1, nil, 45),
		rect(0.29, 0.44, 0.16, 0.3, -1, nil, -28),
	})
	flat(pen, {
		circle(0.52, 0.7, 0.36, C.HeatLow),
		rect(0.52, 0.57, 0.24, 0.24, 0.05, C.HeatLow, 45),
		circle(0.52, 0.75, 0.15, rgb(255, 250, 206)),
	})
	shine(pen, 0.34, 0.56, 0.05, 0.14, 20)
end

-- STAMINA (Round 2, R2-S1) --------------------------------------------------------------------

-- Bolt: a large glossy yellow lightning bolt (two offset slanted slabs and a chunky joint).
local BOLT_YELLOW = rgb(255, 214, 40)
defaults.Bolt = BOLT_YELLOW
tilts.Bolt = 0
painters.Bolt = function(pen)
	group(pen, {
		rect(0.6, 0.27, 0.34, 0.5, 0.06, nil, 22),
		rect(0.4, 0.73, 0.34, 0.5, 0.06, nil, 22),
		rect(0.5, 0.5, 0.58, 0.2, 0.05, nil, -16),
	})
	shine(pen, 0.52, 0.2, 0.06, 0.2, 22)
end

-- BoltPip: the SIMPLE silhouette of the pip row (two slanted slabs, no joint, no highlight), so ten of
-- them stay countable on a phone.
defaults.BoltPip = BOLT_YELLOW
tilts.BoltPip = 0
painters.BoltPip = function(pen)
	group(pen, {
		rect(0.6, 0.3, 0.46, 0.56, 0.08, nil, 18),
		rect(0.4, 0.7, 0.46, 0.56, 0.08, nil, 18),
	})
end

-- BoltEmpty: the depleted bolt, grey with a dark crack through it (zero Stamina).
local BOLT_GREY = rgb(168, 174, 188)
defaults.BoltEmpty = BOLT_GREY
tilts.BoltEmpty = 0
painters.BoltEmpty = function(pen)
	group(pen, {
		rect(0.6, 0.27, 0.34, 0.5, 0.06, nil, 22),
		rect(0.4, 0.73, 0.34, 0.5, 0.06, nil, 22),
		rect(0.5, 0.5, 0.58, 0.2, 0.05, nil, -16),
	})
	flat(pen, {
		bar(0.46, 0.34, 0.54, 0.5, 0.045, INK),
		bar(0.54, 0.5, 0.44, 0.62, 0.045, INK),
		bar(0.44, 0.62, 0.52, 0.76, 0.045, INK),
	})
end

-- KEYS ---------------------------------------------------------------------------------------

-- KeyLock: a gold padlock with a white key inserted (parts "Shackle", "Body", "Key").
defaults.KeyLock = GOLD
painters.KeyLock = function(pen)
	lockParts(pen, true)
end

-- Padlock: the same lock, locked, with a keyhole.
defaults.Padlock = GOLD
tilts.Padlock = -6
painters.Padlock = function(pen)
	lockParts(pen, false)
end

-- RUN / FEEDBACK -----------------------------------------------------------------------------

-- HopCar (Hop, Round 3, R3-C2): an original side-view CAR (roof, dark window, two wheels) low in the box with ONE
-- bold arc rising from above it to an arrowhead that points up and forward. It supersedes HopFigure (a character
-- between two roofs). The icon names the action; it does not say whether the car or the driver leaves the ground.
-- At about 56 px the silhouette reads first: one car, one arc, one arrowhead, nothing else; every shape has the
-- dark outline, so it holds in greyscale. About 38 frames (budget 40).
local HOP_GLASS = rgb(52, 108, 176) -- a dark pane: the roofline reads on the white body and in greyscale
defaults.HopCar = WHITE
painters.HopCar = function(pen)
	-- the arc: a quadratic curve from above the car's rear, flat at first, then climbing steeply to the upper right
	local p0x, p0y, p1x, p1y, p2x, p2y = 0.2, 0.33, 0.68, 0.35, 0.77, 0.14
	local width = 0.11
	local specs: { Spec } = {}
	local px, py = p0x, p0y
	for i = 1, 5 do
		local t = i / 5
		local u = 1 - t
		local x = u * u * p0x + 2 * u * t * p1x + t * t * p2x
		local y = u * u * p0y + 2 * u * t * p1y + t * t * p2y
		table.insert(specs, bar(px, py, x, y, width))
		px, py = x, y
	end
	-- the arrowhead: the tip a little past the end of the curve, two barbs sweeping back from it
	local heading = math.atan2(p2y - p1y, p2x - p1x)
	local tx, ty = p2x + 0.05 * math.cos(heading), p2y + 0.05 * math.sin(heading)
	for _, side in { 1, -1 } do
		local back = heading + side * math.rad(140)
		table.insert(specs, bar(tx, ty, tx + 0.19 * math.cos(back), ty + 0.19 * math.sin(back), width))
	end
	group(pen, specs)
	within(pen, 0.5, 0.675, 0.66, 0, "Car", function()
		carShape(pen, pen.main, true, HOP_GLASS)
	end)
end

-- FAMILY ICONS (Round 2, cards): the eight vehicle families as side silhouettes that share one weight (a body, a
-- cabin, two or three wheels, the same outline), so a row of them reads as a set. Original shapes, no real models.
local function wheel(pen: Pen, x: number, y: number, d: number)
	flat(pen, { circle(x, y, d, INK), circle(x, y, d * 0.4, WHITE) })
end

local function familyBody(pen: Pen, specs: { Spec })
	group(pen, specs)
end

defaults.Family_Compact = WHITE
painters.Family_Compact = function(pen)
	familyBody(pen, { rect(0.5, 0.6, 0.72, 0.26, 0.08), rect(0.5, 0.4, 0.4, 0.22, 0.08) })
	flat(pen, { rect(0.5, 0.4, 0.3, 0.1, 0.03, GLASS) })
	wheel(pen, 0.28, 0.76, 0.2)
	wheel(pen, 0.72, 0.76, 0.2)
end

defaults.Family_Sedan = WHITE
painters.Family_Sedan = function(pen)
	familyBody(pen, { rect(0.5, 0.62, 0.88, 0.22, 0.07), rect(0.48, 0.44, 0.46, 0.2, 0.08) })
	flat(pen, { rect(0.48, 0.44, 0.36, 0.1, 0.03, GLASS) })
	wheel(pen, 0.22, 0.76, 0.2)
	wheel(pen, 0.78, 0.76, 0.2)
end

defaults.Family_Pickup = WHITE
painters.Family_Pickup = function(pen)
	familyBody(
		pen,
		{ rect(0.5, 0.62, 0.9, 0.22, 0.05), rect(0.32, 0.43, 0.3, 0.2, 0.06), rect(0.76, 0.54, 0.34, 0.08, 0.02) }
	)
	flat(pen, { rect(0.32, 0.43, 0.2, 0.1, 0.03, GLASS) })
	wheel(pen, 0.24, 0.77, 0.2)
	wheel(pen, 0.74, 0.77, 0.2)
end

defaults.Family_Van = WHITE
painters.Family_Van = function(pen)
	familyBody(pen, { rect(0.5, 0.52, 0.84, 0.44, 0.08) })
	flat(pen, { rect(0.74, 0.44, 0.2, 0.16, 0.03, GLASS), rect(0.4, 0.62, 0.3, 0.04, 0.01, INK) })
	wheel(pen, 0.26, 0.76, 0.2)
	wheel(pen, 0.74, 0.76, 0.2)
end

defaults.Family_Motorcycle = WHITE
painters.Family_Motorcycle = function(pen)
	flat(pen, {
		circle(0.22, 0.7, 0.32, INK),
		circle(0.78, 0.7, 0.32, INK),
		circle(0.22, 0.7, 0.2, WHITE),
		circle(0.78, 0.7, 0.2, WHITE),
	})
	group(pen, {
		bar(0.22, 0.7, 0.5, 0.5, 0.07),
		bar(0.5, 0.5, 0.78, 0.7, 0.07),
		rect(0.46, 0.4, 0.26, 0.09, 0.04),
		bar(0.68, 0.48, 0.8, 0.32, 0.06),
	})
end

defaults.Family_Truck = WHITE
painters.Family_Truck = function(pen)
	familyBody(pen, { rect(0.62, 0.48, 0.68, 0.46, 0.04), rect(0.2, 0.58, 0.28, 0.34, 0.06) })
	flat(pen, { rect(0.2, 0.52, 0.16, 0.12, 0.03, GLASS), rect(0.62, 0.48, 0.5, 0.02, 0, INK) })
	wheel(pen, 0.2, 0.78, 0.2)
	wheel(pen, 0.54, 0.78, 0.2)
	wheel(pen, 0.8, 0.78, 0.2)
end

defaults.Family_Sports = WHITE
painters.Family_Sports = function(pen)
	familyBody(
		pen,
		{ rect(0.5, 0.64, 0.92, 0.16, 0.06), rect(0.44, 0.5, 0.34, 0.14, 0.07), bar(0.86, 0.5, 0.94, 0.5, 0.05) }
	)
	flat(pen, { rect(0.44, 0.5, 0.24, 0.07, 0.03, GLASS) })
	wheel(pen, 0.24, 0.76, 0.2)
	wheel(pen, 0.76, 0.76, 0.2)
end

defaults.Family_Special = WHITE
painters.Family_Special = function(pen)
	familyBody(pen, { rect(0.5, 0.68, 0.84, 0.2, 0.07), rect(0.48, 0.52, 0.4, 0.16, 0.07) })
	wheel(pen, 0.25, 0.8, 0.18)
	wheel(pen, 0.75, 0.8, 0.18)
	within(pen, 0.5, 0.2, 0.34, 0, "Star", function()
		painters.Star(pen)
	end)
end

-- CarJump (Hop): a white car leaping up-right off a dotted arc.
defaults.CarJump = WHITE
painters.CarJump = function(pen)
	flat(pen, { rect(0.2, 0.93, 0.34, 0.05, -1, INK) })
	group(pen, {
		flatSpec(circle(0.12, 0.8, 0.1, pen.main)),
		flatSpec(circle(0.23, 0.64, 0.09, pen.main)),
		flatSpec(circle(0.35, 0.52, 0.08, pen.main)),
	})
	within(pen, 0.62, 0.44, 0.72, -18, "Car", function()
		carShape(pen, pen.main, true)
	end)
end

-- Trophy: a gold cup with two handles on a dark plinth.
defaults.Trophy = GOLD
tilts.Trophy = -8
painters.Trophy = function(pen)
	ring(pen, 0.21, 0.34, 0.26, 0.28, 0.07)
	ring(pen, 0.79, 0.34, 0.26, 0.28, 0.07)
	-- bowl = a flat-topped block over a circle (flat rim, round bottom)
	group(pen, {
		rect(0.5, 0.24, 0.58, 0.26, 0.02),
		circle(0.5, 0.4, 0.58),
		rect(0.5, 0.72, 0.13, 0.14, 0),
		rect(0.5, 0.8, 0.34, 0.07, 0.02),
	})
	group(pen, { rect(0.5, 0.89, 0.52, 0.11, 0.03, rgb(120, 72, 44)) })
	flat(pen, {
		rect(0.5, 0.15, 0.48, 0.05, -1, darken(pen.main, 0.45)),
		circle(0.5, 0.42, 0.16, darken(pen.main, 0.18)),
	})
	shine(pen, 0.32, 0.34, 0.05, 0.17)
end

-- Star: a chunky five-point star with rounded points.
defaults.Star = GOLD
tilts.Star = -12
painters.Star = function(pen)
	local cx, cy = 0.5, 0.54
	local specs = { circle(cx, cy, 0.42) }
	for k = 0, 4 do
		local a = math.rad(-90 + 72 * k)
		table.insert(specs, bar(cx, cy, cx + 0.42 * math.cos(a), cy + 0.42 * math.sin(a), 0.25))
	end
	group(pen, specs)
	shine(pen, 0.4, 0.38, 0.1, 0.05, -20)
end

-- Music: a single eighth note with a curled flag.
defaults.Music = NOTE_PINK
tilts.Music = -10
painters.Music = function(pen)
	group(pen, {
		rect(0.36, 0.76, 0.36, 0.26, -1, nil, -22),
		bar(0.5, 0.74, 0.5, 0.14, 0.1),
		bar(0.5, 0.15, 0.78, 0.36, 0.11),
		bar(0.78, 0.36, 0.73, 0.56, 0.1),
	})
	shine(pen, 0.3, 0.72, 0.1, 0.05, -22)
end

-- Event (timer proposal): an orange stopwatch with a small chequered flag behind it.
defaults.Event = EVENT_ORANGE
tilts.Event = -8
painters.Event = function(pen)
	group(pen, {
		bar(0.8, 0.1, 0.8, 0.5, 0.06, SILVER),
		rect(0.89, 0.2, 0.2, 0.17, 0.02, WHITE),
	})
	flat(pen, {
		rect(0.84, 0.16, 0.08, 0.075, 0, INK),
		rect(0.93, 0.24, 0.08, 0.075, 0, INK),
	})
	group(pen, {
		circle(0.44, 0.58, 0.72),
		rect(0.44, 0.17, 0.2, 0.09, 0.03),
		rect(0.71, 0.28, 0.1, 0.08, 0.02, nil, 42),
	})
	flat(pen, {
		circle(0.44, 0.58, 0.52, rgb(252, 252, 255)),
		bar(0.44, 0.58, 0.44, 0.4, 0.06, INK),
		bar(0.44, 0.58, 0.58, 0.65, 0.06, INK),
		circle(0.44, 0.58, 0.08, pen.main),
	})
	shine(pen, 0.22, 0.42, 0.05, 0.13, 30)
end

-- Track (earning line): an oval racetrack with a green infield, lane dashes and a start line.
defaults.Track = ASPHALT
tilts.Track = -8
painters.Track = function(pen)
	flat(pen, { rect(0.5, 0.52, 0.66, 0.36, -1, GRASS) })
	ring(pen, 0.5, 0.52, 0.92, 0.62, 0.13)
	flat(pen, {
		rect(0.35, 0.275, 0.09, 0.025, -1, WHITE),
		rect(0.5, 0.275, 0.09, 0.025, -1, WHITE),
		rect(0.65, 0.275, 0.09, 0.025, -1, WHITE),
		rect(0.35, 0.765, 0.09, 0.025, -1, WHITE),
		rect(0.65, 0.765, 0.09, 0.025, -1, WHITE),
		rect(0.5, 0.735, 0.045, 0.06, 0, WHITE),
		rect(0.5, 0.795, 0.045, 0.06, 0, INK),
	})
	shine(pen, 0.2, 0.36, 0.04, 0.1, 30)
end

-- Stamp: a round red claim stamp with a white tick.
defaults.Stamp = STAMP_RED
tilts.Stamp = -14
painters.Stamp = function(pen)
	group(pen, { circle(0.5, 0.5, 0.86) })
	ring(pen, 0.5, 0.5, 0.68, 0.68, 0.035, lighten(pen.main, 0.55), false)
	flat(pen, {
		bar(0.33, 0.52, 0.45, 0.64, 0.11, WHITE),
		bar(0.45, 0.64, 0.68, 0.36, 0.11, WHITE),
	})
	shine(pen, 0.28, 0.3, 0.12, 0.05, -45)
end

-- Warning: an orange rounded triangle with a navy "!" (never a round red badge).
defaults.Warning = WARN_ORANGE
painters.Warning = function(pen)
	local ax, ay, bx, by, cx, cy = 0.5, 0.14, 0.1, 0.84, 0.9, 0.84
	local function hw(y: number): number
		return 0.4 * (y - ay) / (by - ay)
	end
	local specs = {
		bar(ax, ay, bx, by, 0.18),
		bar(bx, by, cx, cy, 0.18),
		bar(cx, cy, ax, ay, 0.18),
	}
	local bands = 4
	local step = (by - ay) / bands
	for i = 0, bands - 1 do
		local top = ay + i * step
		local mid = top + step / 2
		table.insert(specs, flatSpec(rect(0.5, mid, math.max(2 * hw(mid), 0.04), step + 0.01, 0)))
	end
	group(pen, specs)
	flat(pen, {
		bar(0.5, 0.38, 0.5, 0.6, 0.1, INK),
		circle(0.5, 0.73, 0.11, INK),
	})
	shine(pen, 0.36, 0.42, 0.04, 0.12, 30)
end

-- DISTRICT TILES -----------------------------------------------------------------------------
-- A rounded square with a sky gradient and a ground strip; each scene sums up one district's
-- landmark and colour (ledger D-13). Same frame, outline, sky style and ground height for all.

local TILE_RADIUS = 0.16

local function tile(
	pen: Pen,
	name: string,
	skyTop: Color3,
	skyBottom: Color3,
	ground: Color3,
	horizon: number,
	fn: () -> ()
)
	local inset = pen.t
	local f = newFrame(pen, "Tile")
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Position = UDim2.fromScale(0.5, 0.5)
	f.Size = UDim2.new(1, -2 * inset, 1, -2 * inset)
	f.BackgroundColor3 = ground -- the tile itself is the ground; its own corners round the bottom
	f.ClipsDescendants = true
	f.ZIndex = pen.z
	f:SetAttribute("District", name)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(TILE_RADIUS, 0)
	corner.Parent = f
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = pen.t
	stroke.Color = INK
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = f
	f.Parent = pen.parent
	local oldParent, oldPx, oldT, oldD = pen.parent, pen.px, pen.t, pen.d
	pen.parent = f
	pen.px = oldPx - 2 * inset
	pen.z += 1
	-- sky: a rounded top (follows the tile corners) squared off at the horizon by a second piece
	-- whose gradient continues the first one's
	local function skyPiece(s: Spec, from: Color3, to: Color3)
		local p = piece(pen, s, WHITE, 0, 0, pen.z)
		local g = Instance.new("UIGradient")
		g.Color = ColorSequence.new(from, to)
		g.Rotation = 90
		g.Parent = p
	end
	skyPiece(rect(0.5, horizon / 2, 1, horizon, TILE_RADIUS), skyTop, skyBottom)
	skyPiece(rect(0.5, horizon * 0.75, 1, horizon / 2, 0), skyTop:Lerp(skyBottom, 0.5), skyBottom)
	pen.z += 1
	pen.t = math.max(oldT * 0.6, 1)
	pen.d = math.max(oldD * 0.6, 0.75)
	fn()
	pen.parent, pen.px, pen.t, pen.d = oldParent, oldPx, oldT, oldD
end

-- Main Street: the REEL WHEELS theatre (warm brick, cream marquee with bulbs, gold blade sign).
defaults.District_MainStreet = BRICK
painters.District_MainStreet = function(pen)
	tile(pen, "MainStreet", rgb(110, 196, 255), rgb(255, 222, 176), rgb(150, 156, 170), 0.78, function()
		group(pen, { rect(0.1, 0.57, 0.24, 0.42, 0.02, rgb(232, 172, 92)) })
		flat(pen, { rect(0.1, 0.48, 0.1, 0.09, 0.01, rgb(255, 240, 196)) })
		group(pen, { rect(0.5, 0.52, 0.6, 0.54, 0.02) })
		flat(pen, {
			rect(0.5, 0.26, 0.62, 0.04, 0, darken(pen.main, 0.3)),
			rect(0.38, 0.36, 0.09, 0.1, 0.01, rgb(255, 236, 170)),
			rect(0.56, 0.36, 0.09, 0.1, 0.01, rgb(255, 236, 170)),
			rect(0.47, 0.44, 0.5, 0.015, 0, darken(pen.main, 0.18)),
			rect(0.47, 0.72, 0.18, 0.12, 0.01, darken(pen.main, 0.6)),
		})
		group(pen, { rect(0.48, 0.58, 0.64, 0.12, 0.02, CREAM) })
		flat(pen, {
			rect(0.48, 0.585, 0.44, 0.04, 0, rgb(206, 52, 62)),
			circle(0.22, 0.52, 0.045, rgb(255, 214, 64)),
			circle(0.39, 0.52, 0.045, rgb(255, 214, 64)),
			circle(0.57, 0.52, 0.045, rgb(255, 214, 64)),
			circle(0.74, 0.52, 0.045, rgb(255, 214, 64)),
		})
		group(pen, { rect(0.8, 0.3, 0.14, 0.42, 0.03, GOLD) })
		flat(pen, {
			rect(0.8, 0.17, 0.07, 0.07, 0.01, rgb(206, 52, 62)),
			rect(0.8, 0.29, 0.07, 0.07, 0.01, rgb(206, 52, 62)),
			rect(0.8, 0.41, 0.07, 0.07, 0.01, rgb(206, 52, 62)),
			rect(0.3, 0.9, 0.12, 0.02, 0, WHITE),
			rect(0.7, 0.9, 0.12, 0.02, 0, WHITE),
		})
		shine(pen, 0.27, 0.32, 0.03, 0.08)
	end)
end

-- City Hall: a cream clock tower with a copper roof over a columned wing, trees and lamps.
defaults.District_CityHall = CREAM
painters.District_CityHall = function(pen)
	tile(pen, "CityHall", rgb(84, 176, 255), rgb(206, 238, 255), rgb(226, 212, 186), 0.78, function()
		group(pen, { circle(0.12, 0.62, 0.24, TREE), circle(0.88, 0.62, 0.24, TREE) })
		flat(pen, {
			rect(0.12, 0.75, 0.04, 0.08, 0, rgb(120, 80, 50)),
			rect(0.88, 0.75, 0.04, 0.08, 0, rgb(120, 80, 50)),
		})
		group(pen, { rect(0.5, 0.66, 0.8, 0.24, 0.02, darken(pen.main, 0.06)) })
		flat(pen, {
			rect(0.22, 0.69, 0.025, 0.14, 0, darken(pen.main, 0.25)),
			rect(0.32, 0.69, 0.025, 0.14, 0, darken(pen.main, 0.25)),
			rect(0.68, 0.69, 0.025, 0.14, 0, darken(pen.main, 0.25)),
			rect(0.78, 0.69, 0.025, 0.14, 0, darken(pen.main, 0.25)),
		})
		group(pen, { rect(0.5, 0.2, 0.18, 0.18, 0.03, COPPER, 45) })
		group(pen, { rect(0.5, 0.48, 0.26, 0.56, 0.02, lighten(pen.main, 0.2)) })
		flat(pen, {
			circle(0.5, 0.35, 0.19, INK),
			circle(0.5, 0.35, 0.15, WHITE),
			bar(0.5, 0.35, 0.5, 0.29, 0.025, INK),
			bar(0.5, 0.35, 0.545, 0.37, 0.025, INK),
			rect(0.5, 0.55, 0.08, 0.1, 0.01, rgb(70, 110, 170)),
			rect(0.5, 0.71, 0.12, 0.12, 0.01, rgb(140, 96, 60)),
			rect(0.5, 0.8, 0.42, 0.03, 0, lighten(pen.main, 0.35)),
			rect(0.3, 0.86, 0.018, 0.1, 0, INK),
			circle(0.3, 0.8, 0.05, rgb(255, 224, 110)),
			rect(0.7, 0.86, 0.018, 0.1, 0, INK),
			circle(0.7, 0.8, 0.05, rgb(255, 224, 110)),
		})
		shine(pen, 0.42, 0.3, 0.025, 0.1)
	end)
end

-- Harbor Bridge: a red steel arch and white deck over blue water, a faint skyline beyond.
defaults.District_HarborBridge = STEEL_RED
painters.District_HarborBridge = function(pen)
	tile(pen, "HarborBridge", rgb(76, 166, 255), rgb(196, 232, 255), WATER, 0.74, function()
		flat(pen, {
			circle(0.84, 0.17, 0.13, rgb(255, 236, 140)),
			rect(0.13, 0.62, 0.12, 0.24, 0, rgb(170, 200, 232)),
			rect(0.25, 0.66, 0.1, 0.16, 0, rgb(186, 212, 238)),
			rect(0.86, 0.63, 0.12, 0.22, 0, rgb(170, 200, 232)),
		})
		local cx, cy, ow, oh, band = 0.5, 0.78, 0.86, 0.8, 0.07
		ring(pen, cx, cy, ow, oh, band)
		local a, b = ow / 2 - band / 2, oh / 2 - band / 2
		local hangers = {}
		for _, x in { 0.32, 0.41, 0.5, 0.59, 0.68 } do
			local u = (x - cx) / a
			local yArch = cy - b * math.sqrt(math.max(1 - u * u, 0))
			table.insert(hangers, rect(x, (yArch + 0.6) / 2, 0.018, 0.6 - yArch, 0, lighten(pen.main, 0.35)))
		end
		flat(pen, hangers)
		group(pen, { rect(0.5, 0.61, 1.06, 0.07, 0, rgb(244, 244, 248)) })
		flat(pen, {
			rect(0.5, 0.585, 1.06, 0.012, 0, darken(pen.main, 0.2)),
			rect(0.5, 0.79, 1, 0.1, 0, WATER),
			rect(0.24, 0.79, 0.14, 0.02, -1, WHITE),
			rect(0.62, 0.86, 0.14, 0.02, -1, WHITE),
			rect(0.8, 0.77, 0.1, 0.02, -1, WHITE),
		})
		shine(pen, 0.2, 0.62, 0.025, 0.08, 30)
	end)
end

-- Midtown: tall teal glass towers with a roof tank, a sandstone block and a stadium curve.
defaults.District_Midtown = TEAL_GLASS
painters.District_Midtown = function(pen)
	tile(pen, "Midtown", rgb(56, 176, 236), rgb(184, 240, 248), rgb(150, 160, 178), 0.78, function()
		group(pen, { rect(0.84, 0.7, 0.36, 0.16, -1, rgb(238, 242, 248)) })
		flat(pen, { rect(0.84, 0.665, 0.3, 0.045, -1, rgb(222, 70, 70)) })
		group(pen, { rect(0.33, 0.47, 0.24, 0.62, 0.01) })
		flat(pen, {
			rect(0.33, 0.13, 0.02, 0.08, 0, INK),
			rect(0.28, 0.48, 0.03, 0.52, 0, lighten(pen.main, 0.35)),
			rect(0.38, 0.48, 0.03, 0.52, 0, lighten(pen.main, 0.35)),
			rect(0.33, 0.36, 0.22, 0.015, 0, darken(pen.main, 0.3)),
			rect(0.33, 0.56, 0.22, 0.015, 0, darken(pen.main, 0.3)),
		})
		group(pen, { rect(0.63, 0.29, 0.09, 0.07, 0.02, rgb(156, 104, 64)) })
		group(pen, { rect(0.6, 0.56, 0.2, 0.46, 0.01, rgb(108, 168, 232)) })
		flat(pen, {
			rect(0.56, 0.56, 0.03, 0.36, 0, lighten(rgb(108, 168, 232), 0.35)),
			rect(0.65, 0.56, 0.03, 0.36, 0, lighten(rgb(108, 168, 232), 0.35)),
		})
		group(pen, { rect(0.1, 0.68, 0.2, 0.22, 0.01, rgb(232, 190, 130)) })
		flat(pen, {
			rect(0.1, 0.64, 0.1, 0.05, 0, rgb(255, 238, 190)),
			rect(0.3, 0.9, 0.12, 0.02, 0, WHITE),
			rect(0.7, 0.9, 0.12, 0.02, 0, WHITE),
		})
		shine(pen, 0.27, 0.27, 0.025, 0.12, 12)
	end)
end

-- Skyline Park: round trees and a fountain on green lawns with a pale skyline behind.
defaults.District_SkylinePark = TREE
painters.District_SkylinePark = function(pen)
	tile(pen, "SkylinePark", rgb(104, 196, 255), rgb(222, 244, 255), rgb(100, 198, 92), 0.7, function()
		flat(pen, {
			rect(0.2, 0.56, 0.12, 0.3, 0, rgb(164, 192, 226)),
			rect(0.33, 0.6, 0.1, 0.22, 0, rgb(182, 204, 232)),
			rect(0.7, 0.54, 0.12, 0.34, 0, rgb(164, 192, 226)),
			rect(0.82, 0.6, 0.1, 0.22, 0, rgb(182, 204, 232)),
			rect(0.3, 0.74, 0.7, 0.2, -1, rgb(132, 214, 112)),
			rect(0.78, 0.75, 0.6, 0.18, -1, rgb(132, 214, 112)),
		})
		group(pen, { circle(0.16, 0.6, 0.22), circle(0.85, 0.58, 0.24) })
		flat(pen, {
			rect(0.16, 0.74, 0.04, 0.08, 0, rgb(120, 80, 50)),
			rect(0.85, 0.73, 0.04, 0.08, 0, rgb(120, 80, 50)),
			rect(0.5, 0.48, 0.045, 0.22, -1, rgb(206, 242, 255)),
			circle(0.43, 0.42, 0.1, rgb(170, 224, 255)),
			circle(0.57, 0.42, 0.1, rgb(170, 224, 255)),
			circle(0.5, 0.37, 0.12, rgb(196, 236, 255)),
		})
		group(pen, {
			rect(0.5, 0.8, 0.4, 0.1, 0.03, STONE),
			rect(0.5, 0.7, 0.06, 0.14, 0, STONE),
			rect(0.5, 0.62, 0.2, 0.05, 0.02, STONE),
		})
		flat(pen, {
			rect(0.5, 0.775, 0.34, 0.035, 0.01, rgb(120, 200, 255)),
			rect(0.5, 0.93, 0.3, 0.08, 0.02, rgb(232, 214, 168)),
		})
		shine(pen, 0.1, 0.55, 0.06, 0.03, -20)
	end)
end

-- ROUND 2 WORLD TILES (R2-R1): five stations each for Dusty Highway and Summit Pass, in the same frame,
-- outline, sky style and ground height as the Downtown tiles. Original scenes.

local SAND = rgb(236, 184, 118)
local SAND_DEEP = rgb(214, 148, 88)
local ROCK_RED = rgb(196, 90, 58)
local ROCK_DEEP = rgb(150, 62, 44)
local CACTUS = rgb(78, 168, 92)
local TURQ = rgb(60, 196, 190)
local DINER_RED = rgb(206, 52, 62)
local SNOW = rgb(244, 248, 253)
local SNOW_SHADE = rgb(204, 222, 244)
local PINE = rgb(44, 126, 86)
local WOOD = rgb(154, 100, 58)
local ICE = rgb(156, 218, 244)
local ICE_DEEP = rgb(84, 162, 220)
local MOUNTAIN = rgb(128, 156, 196)
local ROOF_RED = rgb(176, 70, 56)
local METAL = rgb(188, 190, 202)

-- A triangle with a 90-degree apex standing on baseY: a rotated square drawn into a frame that ends at
-- the base line, so nothing is left below it. `plain` skips the outline (distant mountains).
local function triangle(pen: Pen, x: number, baseY: number, height: number, c: Color3?, plain: boolean?)
	local clip = newFrame(pen, "Triangle")
	clip.BackgroundTransparency = 1
	clip.Size = UDim2.fromScale(1, baseY)
	clip.ClipsDescendants = true
	clip.ZIndex = pen.z
	clip.Parent = pen.parent
	local oldParent = pen.parent
	pen.parent = clip
	local side = height * math.sqrt(2)
	local spec = rect(x, 1, side, side / baseY, 0, c, 45)
	if plain then
		flat(pen, { spec })
	else
		group(pen, { spec })
	end
	pen.parent = oldParent
end

-- A pine: three stacked tiers over a trunk.
local function pine(pen: Pen, x: number, baseY: number, s: number)
	flat(pen, { rect(x, baseY + 0.02 * s, 0.03 * s, 0.06 * s, 0, rgb(110, 72, 48)) })
	triangle(pen, x, baseY, 0.16 * s, PINE)
	triangle(pen, x, baseY - 0.06 * s, 0.14 * s, PINE)
	triangle(pen, x, baseY - 0.12 * s, 0.12 * s, PINE)
end

-- A saguaro: stout body with two arms (pieces of one outlined group).
local function saguaro(x: number, baseY: number, s: number): { Spec }
	return {
		rect(x, baseY - 0.21 * s, 0.1 * s, 0.42 * s, -1, CACTUS),
		bar(x - 0.1 * s, baseY - 0.2 * s, x, baseY - 0.2 * s, 0.045 * s, CACTUS),
		bar(x - 0.1 * s, baseY - 0.2 * s, x - 0.1 * s, baseY - 0.3 * s, 0.045 * s, CACTUS),
		bar(x + 0.1 * s, baseY - 0.14 * s, x, baseY - 0.14 * s, 0.045 * s, CACTUS),
		bar(x + 0.1 * s, baseY - 0.14 * s, x + 0.1 * s, baseY - 0.25 * s, 0.045 * s, CACTUS),
	}
end

-- Dusty Highway 1: Cactus Flats (saguaros, far mesas and a windmill).
defaults.District_CactusFlats = CACTUS
painters.District_CactusFlats = function(pen)
	tile(pen, "CactusFlats", rgb(112, 184, 238), rgb(255, 226, 180), SAND, 0.74, function()
		flat(pen, {
			rect(0.3, 0.7, 0.4, 0.1, 0, rgb(226, 150, 100)),
			rect(0.74, 0.69, 0.3, 0.12, 0, rgb(236, 164, 110)),
			rect(0.4, 0.9, 0.7, 0.03, 0, SAND_DEEP),
		})
		group(pen, { rect(0.82, 0.6, 0.05, 0.36, 0.01, rgb(206, 208, 220)) })
		flat(pen, {
			bar(0.82, 0.38, 0.91, 0.29, 0.035, WHITE),
			bar(0.82, 0.38, 0.73, 0.29, 0.035, WHITE),
			bar(0.82, 0.38, 0.91, 0.47, 0.035, WHITE),
			bar(0.82, 0.38, 0.73, 0.47, 0.035, WHITE),
			circle(0.82, 0.38, 0.06, rgb(120, 126, 142)),
		})
		group(pen, saguaro(0.3, 0.88, 1))
		group(pen, saguaro(0.56, 0.84, 0.7))
		shine(pen, 0.27, 0.58, 0.025, 0.12)
	end)
end

-- Dusty Highway 2: Diner Strip (a cream roadside diner with a turquoise band, a round sign and a pump).
defaults.District_DinerStrip = TURQ
painters.District_DinerStrip = function(pen)
	tile(pen, "DinerStrip", rgb(120, 190, 236), rgb(255, 230, 190), SAND, 0.76, function()
		group(pen, { rect(0.36, 0.62, 0.56, 0.3, 0.02, CREAM) })
		flat(pen, {
			rect(0.36, 0.56, 0.56, 0.05, 0, TURQ),
			rect(0.22, 0.67, 0.14, 0.1, 0.01, rgb(176, 226, 244)),
			rect(0.42, 0.67, 0.14, 0.1, 0.01, rgb(176, 226, 244)),
			rect(0.56, 0.69, 0.07, 0.14, 0.01, DINER_RED),
		})
		group(pen, { rect(0.36, 0.45, 0.62, 0.06, 0.02, DINER_RED) })
		flat(pen, { rect(0.78, 0.56, 0.025, 0.4, 0, rgb(96, 70, 52)) })
		group(pen, { circle(0.78, 0.3, 0.2, GOLD) })
		flat(pen, { circle(0.78, 0.3, 0.1, DINER_RED) })
		group(pen, { rect(0.92, 0.72, 0.08, 0.2, 0.02, DINER_RED) })
		flat(pen, { rect(0.92, 0.67, 0.05, 0.05, 0.01, WHITE) })
		shine(pen, 0.18, 0.58, 0.03, 0.1, 20)
	end)
end

-- Dusty Highway 3: Red Rock Arches (a thick sandstone arch between mesas).
defaults.District_RedRockArches = ROCK_RED
painters.District_RedRockArches = function(pen)
	tile(pen, "RedRockArches", rgb(104, 178, 232), rgb(255, 224, 176), SAND, 0.78, function()
		group(pen, {
			rect(0.12, 0.58, 0.24, 0.4, 0.03, ROCK_DEEP),
			rect(0.9, 0.62, 0.2, 0.32, 0.03, ROCK_DEEP),
		})
		ring(pen, 0.5, 0.72, 0.8, 0.8, 0.15, ROCK_RED)
		flat(pen, {
			rect(0.5, 0.89, 1.2, 0.22, 0, SAND),
			rect(0.5, 0.78, 0.5, 0.02, 0, SAND_DEEP),
			rect(0.5, 0.42, 0.26, 0.02, 0, ROCK_DEEP),
			rect(0.3, 0.62, 0.02, 0.12, 0, ROCK_DEEP),
		})
		shine(pen, 0.3, 0.4, 0.03, 0.12, 40)
	end)
end

-- Dusty Highway 4: Canyon Bridge (layered cliffs, a deep gap and a braced span).
defaults.District_CanyonBridge = ROCK_RED
painters.District_CanyonBridge = function(pen)
	tile(pen, "CanyonBridge", rgb(112, 182, 232), rgb(255, 226, 184), ROCK_DEEP, 0.7, function()
		flat(pen, { rect(0.5, 0.64, 0.3, 0.1, 0, rgb(214, 130, 100)), rect(0.5, 0.86, 0.5, 0.36, 0, rgb(70, 48, 68)) })
		group(pen, { rect(0.13, 0.64, 0.3, 0.64, 0.02), rect(0.88, 0.6, 0.28, 0.56, 0.02) })
		flat(pen, {
			rect(0.13, 0.5, 0.3, 0.025, 0, ROCK_DEEP),
			rect(0.13, 0.66, 0.3, 0.025, 0, ROCK_DEEP),
			rect(0.88, 0.52, 0.28, 0.025, 0, ROCK_DEEP),
			rect(0.88, 0.68, 0.28, 0.025, 0, ROCK_DEEP),
			bar(0.3, 0.43, 0.5, 0.62, 0.03, METAL),
			bar(0.7, 0.43, 0.5, 0.62, 0.03, METAL),
		})
		group(pen, { rect(0.5, 0.4, 0.9, 0.055, 0.01, rgb(236, 232, 224)) })
		flat(pen, { rect(0.5, 0.36, 0.9, 0.012, 0, rgb(178, 56, 50)) })
		shine(pen, 0.14, 0.45, 0.025, 0.1, 30)
	end)
end

-- Dusty Highway 5: Mirage Dunes (soft dunes, a weathered hut and a giant cactus).
defaults.District_MirageDunes = SAND
painters.District_MirageDunes = function(pen)
	tile(pen, "MirageDunes", rgb(150, 206, 238), rgb(255, 236, 200), SAND, 0.72, function()
		flat(pen, { circle(0.82, 0.2, 0.16, rgb(255, 244, 196)) })
		group(pen, { circle(0.82, 0.95, 0.6, rgb(246, 200, 140)) })
		group(pen, { rect(0.74, 0.66, 0.18, 0.13, 0.015, rgb(168, 112, 70)) })
		flat(
			pen,
			{ rect(0.74, 0.595, 0.21, 0.03, 0, rgb(120, 78, 52)), rect(0.74, 0.69, 0.05, 0.08, 0, rgb(82, 54, 40)) }
		)
		group(pen, { circle(0.2, 0.98, 0.8, SAND) })
		group(pen, saguaro(0.4, 0.9, 1.1))
		shine(pen, 0.36, 0.62, 0.02, 0.1)
	end)
end

-- Summit Pass 1: Pine Village (a chalet and pines under snowy peaks).
defaults.District_PineVillage = WOOD
painters.District_PineVillage = function(pen)
	tile(pen, "PineVillage", rgb(70, 150, 230), rgb(206, 232, 255), SNOW, 0.74, function()
		triangle(pen, 0.2, 0.74, 0.4, MOUNTAIN, true)
		triangle(pen, 0.78, 0.74, 0.46, MOUNTAIN, true)
		flat(pen, { rect(0.5, 0.82, 0.58, 0.03, -1, SNOW_SHADE) })
		triangle(pen, 0.5, 0.56, 0.24, ROOF_RED)
		group(pen, { rect(0.5, 0.67, 0.4, 0.22, 0.015, WOOD) })
		flat(pen, {
			rect(0.4, 0.66, 0.08, 0.1, 0.01, rgb(255, 232, 150)),
			rect(0.6, 0.66, 0.08, 0.1, 0.01, rgb(255, 232, 150)),
			rect(0.5, 0.7, 0.07, 0.14, 0.01, rgb(96, 62, 40)),
		})
		pine(pen, 0.12, 0.84, 1.2)
		pine(pen, 0.88, 0.86, 1.1)
		shine(pen, 0.33, 0.62, 0.03, 0.1, 20)
	end)
end

-- Summit Pass 2: Ski Lift Ridge (a slope with a cable and a red chair between two towers).
defaults.District_SkiLiftRidge = ICE_DEEP
painters.District_SkiLiftRidge = function(pen)
	tile(pen, "SkiLiftRidge", rgb(64, 146, 232), rgb(200, 230, 255), SNOW, 0.8, function()
		triangle(pen, 0.7, 0.8, 0.6, MOUNTAIN, true)
		flat(pen, { bar(0.62, 0.3, 0.32, 0.76, 0.09, SNOW) })
		flat(pen, {
			rect(0.26, 0.62, 0.035, 0.3, 0, rgb(96, 100, 116)),
			rect(0.74, 0.4, 0.035, 0.3, 0, rgb(96, 100, 116)),
			bar(0.26, 0.47, 0.74, 0.25, 0.014, INK),
		})
		flat(pen, { rect(0.5, 0.4, 0.012, 0.06, 0, INK) })
		group(pen, { rect(0.5, 0.45, 0.13, 0.05, 0.02, DINER_RED) })
		pine(pen, 0.12, 0.88, 1)
		pine(pen, 0.9, 0.9, 0.9)
		shine(pen, 0.34, 0.3, 0.025, 0.1, 30)
	end)
end

-- Summit Pass 3: Frozen Lake (an ice sheet with two skaters between snowy banks).
defaults.District_FrozenLake = ICE
painters.District_FrozenLake = function(pen)
	tile(pen, "FrozenLake", rgb(76, 156, 236), rgb(214, 238, 255), SNOW, 0.6, function()
		triangle(pen, 0.22, 0.6, 0.34, MOUNTAIN, true)
		triangle(pen, 0.8, 0.6, 0.3, MOUNTAIN, true)
		group(pen, { rect(0.5, 0.8, 0.84, 0.32, -1, ICE) })
		flat(pen, {
			bar(0.26, 0.82, 0.44, 0.76, 0.012, ICE_DEEP),
			bar(0.58, 0.9, 0.78, 0.84, 0.012, ICE_DEEP),
		})
		group(pen, { circle(0.38, 0.69, 0.07, rgb(238, 98, 70)), rect(0.38, 0.77, 0.07, 0.12, -1, rgb(238, 98, 70)) })
		group(pen, { circle(0.66, 0.73, 0.07, rgb(70, 130, 240)), rect(0.66, 0.81, 0.07, 0.12, -1, rgb(70, 130, 240)) })
		pine(pen, 0.1, 0.7, 0.9)
		pine(pen, 0.92, 0.7, 0.9)
		shine(pen, 0.5, 0.76, 0.1, 0.02)
	end)
end

-- Summit Pass 4: Glacier Tunnel (a blue ice mass with a wide arched opening onto the road).
defaults.District_GlacierTunnel = ICE_DEEP
painters.District_GlacierTunnel = function(pen)
	tile(pen, "GlacierTunnel", rgb(86, 160, 236), rgb(214, 238, 255), rgb(120, 126, 142), 0.78, function()
		group(pen, {
			rect(0.5, 0.5, 0.96, 0.56, 0.05, ICE),
			circle(0.28, 0.26, 0.34, ICE),
			circle(0.68, 0.22, 0.4, ICE),
		})
		flat(pen, {
			circle(0.5, 0.58, 0.46, INK),
			rect(0.5, 0.69, 0.46, 0.18, 0, INK),
			circle(0.5, 0.58, 0.34, rgb(40, 52, 96)),
			rect(0.5, 0.69, 0.34, 0.18, 0, rgb(40, 52, 96)),
			rect(0.5, 0.89, 1.2, 0.22, 0, rgb(120, 126, 142)),
			rect(0.5, 0.88, 0.04, 0.05, 0, rgb(250, 232, 120)),
		})
		shine(pen, 0.22, 0.4, 0.03, 0.12, 30)
	end)
end

-- Summit Pass 5: Summit Lodge (a timber lodge, an observatory tower and a snowman).
defaults.District_SummitLodge = WOOD
painters.District_SummitLodge = function(pen)
	tile(pen, "SummitLodge", rgb(60, 140, 232), rgb(206, 232, 255), SNOW, 0.76, function()
		triangle(pen, 0.5, 0.76, 0.66, MOUNTAIN, true)
		triangle(pen, 0.84, 0.46, 0.08, METAL)
		group(pen, { rect(0.84, 0.59, 0.1, 0.26, 0.015, rgb(214, 218, 232)) })
		flat(pen, { rect(0.84, 0.55, 0.025, 0.1, 0, INK) })
		triangle(pen, 0.46, 0.52, 0.3, ROOF_RED)
		group(pen, { rect(0.46, 0.65, 0.52, 0.26, 0.015, WOOD) })
		flat(pen, {
			rect(0.32, 0.66, 0.08, 0.1, 0.01, rgb(255, 232, 150)),
			rect(0.46, 0.66, 0.08, 0.1, 0.01, rgb(255, 232, 150)),
			rect(0.6, 0.66, 0.08, 0.1, 0.01, rgb(255, 232, 150)),
		})
		group(pen, { circle(0.1, 0.87, 0.16, SNOW), circle(0.1, 0.77, 0.11, SNOW) })
		flat(pen, { circle(0.1, 0.75, 0.014, INK), rect(0.125, 0.77, 0.04, 0.012, 0, rgb(255, 140, 40)) })
		shine(pen, 0.3, 0.58, 0.03, 0.1, 20)
	end)
end

-- PUBLIC API ---------------------------------------------------------------------------------

Icons2.Names = {
	"Gift",
	"Cart",
	"GarageBook",
	"Clipboard",
	"CashStack",
	"CarCount",
	"Car",
	"Flame",
	"KeyLock",
	"Padlock",
	"CarJump",
	"HopCar",
	"Family_Compact",
	"Family_Sedan",
	"Family_Pickup",
	"Family_Van",
	"Family_Motorcycle",
	"Family_Truck",
	"Family_Sports",
	"Family_Special",
	"Trophy",
	"Star",
	"Music",
	"Event",
	"Track",
	"Stamp",
	"Warning",
	"Bolt",
	"BoltPip",
	"BoltEmpty",
	"District_MainStreet",
	"District_CityHall",
	"District_HarborBridge",
	"District_Midtown",
	"District_SkylinePark",
	"District_CactusFlats",
	"District_DinerStrip",
	"District_RedRockArches",
	"District_CanyonBridge",
	"District_MirageDunes",
	"District_PineVillage",
	"District_SkiLiftRidge",
	"District_FrozenLake",
	"District_GlacierTunnel",
	"District_SummitLodge",
}

Icons2.Districts = {
	"District_MainStreet",
	"District_CityHall",
	"District_HarborBridge",
	"District_Midtown",
	"District_SkylinePark",
	"District_CactusFlats",
	"District_DinerStrip",
	"District_RedRockArches",
	"District_CanyonBridge",
	"District_MirageDunes",
	"District_PineVillage",
	"District_SkiLiftRidge",
	"District_FrozenLake",
	"District_GlacierTunnel",
	"District_SummitLodge",
}

local function holderSide(holder: Frame): number
	local px = holder.Size.X.Offset
	if px <= 0 then
		px = holder.AbsoluteSize.X
	end
	if px <= 0 then
		px = 48
	end
	return px
end

local function newPen(holder: Frame, art: Frame, name: string, opts: Options?): Pen
	local px = holderSide(holder)
	return {
		parent = art,
		px = px,
		t = math.clamp(px * 0.058, 1.5, 3.5),
		d = math.clamp(px * 0.05, 1, 3),
		z = holder.ZIndex + 1,
		main = (opts and opts.tint) or defaults[name] or WHITE,
		frames = { n = 1 },
	}
end

local function newArt(holder: Frame, name: string, opts: Options?): Frame
	local art = Instance.new("Frame")
	art.Name = "Art"
	art.BackgroundTransparency = 1
	art.AnchorPoint = Vector2.new(0.5, 0.5)
	art.Position = UDim2.fromScale(0.5, 0.5)
	art.Size = UDim2.fromScale(1, 1)
	art.Rotation = (opts and opts.tilt) or tilts[name] or 0
	art.ZIndex = holder.ZIndex
	return art
end

-- Fills `holder` (a square Frame) with the named icon. Returns false (and draws nothing) for an
-- unknown name or a painter error, so the caller can fall back.
function Icons2.draw(holder: Frame, name: string, opts: Options?): boolean
	local painter = painters[name]
	if not painter then
		return false
	end
	local art = newArt(holder, name, opts)
	local pen = newPen(holder, art, name, opts)
	local ok, err = pcall(painter, pen)
	if not ok then
		art:Destroy()
		warn("[Icons2] " .. name .. " failed: " .. tostring(err))
		return false
	end
	art:SetAttribute("Icon", name)
	art:SetAttribute("IconSet", "Icons2")
	art:SetAttribute("Frames", pen.frames.n)
	art.Parent = holder
	return true
end

-- The Keys centre (K-02): draws KeyLock into `holder` and returns its movable parts. The key
-- container is centred on the keyhole: Rotation 0 points the key right, 90 = turned a quarter.
-- Opening: move `shackle` up (e.g. Position offset of -18% of the holder) or rotate it.
function Icons2.keyLock(holder: Frame): KeyLockParts
	local art = newArt(holder, "KeyLock", nil)
	local pen = newPen(holder, art, "KeyLock", nil)
	local shackle, body, key = lockParts(pen, true)
	art:SetAttribute("Icon", "KeyLock")
	art:SetAttribute("IconSet", "Icons2")
	art:SetAttribute("Frames", pen.frames.n)
	art.Parent = holder
	return { shackle = shackle, key = key :: Frame, body = body }
end

function Icons2.has(name: string): boolean
	return painters[name] ~= nil
end

return Icons2
