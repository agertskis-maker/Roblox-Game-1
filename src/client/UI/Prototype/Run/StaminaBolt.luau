--!strict
-- Original lightning-bolt art for the Stamina meter (Lane 3 preview; Round 3, ledger R3-S1). ONE flat, sharp zigzag
-- bolt with a thick dark edge, built from plain Frames only (no images, nothing traced or copied). It is the hero icon
-- and, drawn smaller and slimmer, the ten pips, so the pips are the same shape as the icon in a simpler form.
--
-- The silhouette (units of the face height H; y grows down; x is multiplied by the width factor `slim`):
--
--        A _________ B       A (0.29, 0)    B (0.69, 0)    C (0.49, 0.40)   D (0.78, 0.40)
--         /         /        E (0.26, 1.00) F (0.26, 0.58) G (0.00, 0.58)   K (0.26, 0.40)
--        /     C __/__ D
--       /           /          top slab:  A B C .. F G, two edges leaning together (0.5 across per 1 down)
--    G /__ F        /          tip:       the right triangle K D E: a vertical left edge F to E and the long diagonal
--          |      /                       D to E; its upper part hides inside the slab
--          |    /
--          |  /
--          |/ E
--
-- Two kinds of piece, both with the technique this project already uses for its triangles (Icons2.triangle): an
-- axis-aligned CLIP frame (ClipsDescendants) that cuts a rotated bar.
--   * slab:  a bar rotated by the lean and cut by the clip frame at a top and a bottom line = a parallelogram with
--            horizontal ends (the top slab);
--   * wedge: a big rotated bar used as a half plane (one long edge on the line D to E) cut by the clip frame at the box
--            of the triangle = the right triangle (the tip).
-- The outline is the same pieces grown by `outline` px (bars wider by 2 x outline, clip frames taller and wider by
-- the same, the wedge's line moved outward), drawn first and in ink, so the edge is one clean thick dark line with
-- mitred (slightly bevelled) corners. Every piece is a flat colour. The hero gets one lighter strip on the top slab;
-- the depleted bolt (setCracked) gets a dark zigzag crack between the two notches ("broken in half").
--
-- Rotated frames are never clip frames here (ClipsDescendants does not follow rotation), and the art is never tilted
-- as a whole: the lean is in the pieces. Offsets are whole pixels in the engine, so the outline is a whole number of
-- pixels and every silhouette number is rounded once before it is used (the ink and the face then agree).
-- NOT checked in Studio: this was verified by redrawing the same maths offline, which proves the geometry, not how
-- Roblox rasterises rotated frames (edge softness, hairline seams) - look at it in a real frame at 20, 28 and 44 px.
--
--   local metrics = StaminaBolt.metrics(height, outline?, slim?) -> (width, faceHeight, outline)
--   local bolt = StaminaBolt.new(parent, { height = 44, colour = Color3 })
--   bolt.root                  -- Frame, size (width, height); place it yourself
--   bolt:setColour(c)          -- every face piece (the strip follows, lighter)
--   bolt:setCracked(on)        -- the depleted look: crack on, strip off
--   bolt:destroy()
--   bolt.frames                -- Instances it made (a leak and budget number)

local Arcade = require(script.Parent.Parent.Arcade)
local PreviewTokens = require(script.Parent.Parent.PreviewTokens)

local make = Arcade.make
local INK = PreviewTokens.Arcade.Ink
local WHITE = Color3.new(1, 1, 1)

local StaminaBolt = {}
StaminaBolt.__index = StaminaBolt

export type Options = {
	height: number, -- the whole art, outline included, design px
	colour: Color3,
	outline: number?, -- px; default 7% of the height, at least 2
	slim: number?, -- 1 = the hero's width, below 1 = narrower (the pips use 0.8)
	shine: boolean?, -- one lighter strip on the top slab (the hero)
	crack: boolean?, -- build the (hidden) crack for setCracked
	name: string?,
	z: number?,
}

-- Silhouette numbers in units of the face height (see the drawing above).
local ASPECT = 0.78 -- face width / face height at slim = 1
local LEAN = 0.5 -- the slab's edges move left this much per unit down (at slim = 1)
local TOP_LEFT = 0.29 -- x of the top edge's left end
local TOP_WIDTH = 0.40 -- horizontal width of the slab
local JOG_Y = 0.40 -- where the right jog (C to D) and the tip's top edge sit
local SHOULDER_Y = 0.58 -- where the slab ends and the left jog (G to F) sits
local TIP_X = 0.26 -- x of the vertical left edge of the tip (F to E)
local RIGHT_X = 0.78 -- x of the right point D

-- UDim offsets are whole pixels in the engine, so every number that becomes an offset is rounded here, once, and the
-- outline is a whole number of pixels: the ink and the face then round the same way and the edge is even all round.
local function px(n: number): number
	return math.floor(n + 0.5)
end

local function defaultOutline(height: number): number
	return math.max(2, px(height * 0.07))
end

-- (width, face height, outline) of a bolt `height` px tall. The outline is a whole number of pixels.
function StaminaBolt.metrics(height: number, outline: number?, slim: number?): (number, number, number)
	local t = outline or defaultOutline(height)
	local face = math.max(height - 2 * t, 1)
	return px(ASPECT * (slim or 1) * face + 2 * t), face, t
end

local function lighten(c: Color3, k: number): Color3
	return c:Lerp(WHITE, k)
end

-- A parallelogram with horizontal ends: the bar leans like the slab, the clip frame cuts it at y0 and y1 (both grown).
-- `xl` is the left end of the slab at y0, `widthH` its horizontal width, `lean` its horizontal run per px down.
local function slab(
	parent: Instance,
	z: number,
	colour: Color3,
	y0: number,
	y1: number,
	xl: number,
	widthH: number,
	lean: number,
	grow: number,
	boxW: number
): Frame
	local top, bottom = y0 - grow, y1 + grow
	local clip = make("Frame", {
		Name = "Slab",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Position = UDim2.fromOffset(0, top),
		Size = UDim2.fromOffset(boxW, bottom - top),
		ZIndex = z,
		Parent = parent,
	})
	local theta = math.atan(lean)
	local perp = px(widthH * math.cos(theta) + 2 * grow)
	local midY = (y0 + y1) / 2
	local cx = xl + widthH / 2 - lean * (midY - y0)
	local length = px((bottom - top) / math.cos(theta) + perp * math.tan(theta) + 8)
	return make("Frame", {
		Name = "Bar",
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = colour,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(px(cx), px(midY - top)),
		Rotation = math.deg(theta),
		Size = UDim2.fromOffset(perp, length),
		ZIndex = z,
		Parent = clip,
	})
end

-- The right triangle K (x0, y0), D (x1, y0), E (x0, y1), grown by `grow`: the clip frame is its box, the bar is a half
-- plane whose long edge lies on the line D to E (moved outward by `grow`) and which reaches over the K side.
local function wedge(
	parent: Instance,
	z: number,
	colour: Color3,
	x0: number,
	y0: number,
	x1: number,
	y1: number,
	grow: number
): Frame
	local gx0, gy0, gx1, gy1 = x0 - grow, y0 - grow, x1 + grow, y1 + grow
	local clip = make("Frame", {
		Name = "Wedge",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Position = UDim2.fromOffset(gx0, gy0),
		Size = UDim2.fromOffset(gx1 - gx0, gy1 - gy0),
		ZIndex = z,
		Parent = parent,
	})
	local u = Vector2.new(x0 - x1, y1 - y0).Unit -- from D down to E
	local n = Vector2.new(-u.Y, u.X)
	if n.X > 0 then
		n = -n -- the normal that points to K, which is left of D
	end
	local mid = Vector2.new((x0 + x1) / 2, (y0 + y1) / 2) - n * grow
	local reach = (gx1 - gx0) + (gy1 - gy0) + 8 -- longer than the clip frame's diagonal
	local centre = mid + n * (reach / 2) - Vector2.new(gx0, gy0)
	return make("Frame", {
		Name = "Plane",
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = colour,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(px(centre.X), px(centre.Y)),
		Rotation = math.deg(math.atan2(u.Y, u.X)),
		Size = UDim2.fromOffset(px(reach * 2), px(reach)),
		ZIndex = z,
		Parent = clip,
	})
end

-- A round-ended line from a to b (the crack).
local function stroke(parent: Instance, z: number, a: Vector2, b: Vector2, width: number): Frame
	local d = b - a
	local f = make("Frame", {
		Name = "Crack",
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = INK,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(px((a.X + b.X) / 2), px((a.Y + b.Y) / 2)),
		Rotation = math.deg(math.atan2(d.Y, d.X)),
		Size = UDim2.fromOffset(px(d.Magnitude + width), width),
		ZIndex = z,
		Parent = parent,
	})
	make("UICorner", { CornerRadius = UDim.new(0.5, 0), Parent = f })
	return f
end

function StaminaBolt.new(parent: Instance, options: Options)
	local self = setmetatable({}, StaminaBolt)
	local k = options.slim or 1
	local width, face, t = StaminaBolt.metrics(options.height, options.outline, options.slim)
	local z = options.z or 1
	self.width = width
	self.height = options.height
	self._colour = options.colour
	self._faces = {} :: { Frame }
	self._shine = {} :: { Frame }
	self._crack = nil :: Frame?

	local root = make("Frame", {
		Name = options.name or "Bolt",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(width, options.height),
		ZIndex = z,
		Parent = parent,
	})
	self.root = root

	-- whole-pixel positions of the silhouette
	local xTopLeft = px(t + k * TOP_LEFT * face)
	local topWidth = px(k * TOP_WIDTH * face)
	local lean = LEAN * k
	local yTop, yShoulder = t, px(t + SHOULDER_Y * face)
	local tipX0, tipX1 = px(t + k * TIP_X * face), px(t + k * RIGHT_X * face)
	local tipY0, tipY1 = px(t + JOG_Y * face), t + face

	-- the outline: every piece grown by `t`, in ink, under everything
	slab(root, z, INK, yTop, yShoulder, xTopLeft, topWidth, lean, t, width)
	wedge(root, z + 1, INK, tipX0, tipY0, tipX1, tipY1, t)
	-- the faces: flat colour
	table.insert(self._faces, slab(root, z + 2, options.colour, yTop, yShoulder, xTopLeft, topWidth, lean, 0, width))
	table.insert(self._faces, wedge(root, z + 3, options.colour, tipX0, tipY0, tipX1, tipY1, 0))

	if options.shine then
		-- one lighter strip along the left of the top slab
		local y0, y1 = px(t + 0.05 * face), px(t + 0.33 * face)
		local xl = px(xTopLeft - lean * (y0 - t) + 0.06 * k * face)
		table.insert(
			self._shine,
			slab(
				root,
				z + 4,
				lighten(options.colour, 0.5),
				y0,
				y1,
				xl,
				math.max(1, px(0.075 * k * face)),
				lean,
				0,
				width
			)
		)
	end

	if options.crack then
		-- a dark zigzag between the two notches (F and C): the bolt looks broken in half
		local function pt(x: number, y: number): Vector2
			return Vector2.new(t + k * x * face, t + y * face)
		end
		local crack = make("Frame", {
			Name = "Crack",
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = UDim2.fromScale(1, 1),
			Visible = false,
			ZIndex = z + 5,
			Parent = root,
		})
		local path = { pt(0.24, 0.60), pt(0.31, 0.47), pt(0.37, 0.55), pt(0.43, 0.44), pt(0.51, 0.38) }
		local w = math.max(2, px(0.06 * face))
		for i = 1, #path - 1 do
			stroke(crack, z + 5, path[i], path[i + 1], w)
		end
		self._crack = crack
	end

	self.frames = #root:GetDescendants() + 1
	return self
end

export type Bolt = typeof(StaminaBolt.new((nil :: any) :: Instance, (nil :: any) :: Options))

function StaminaBolt.setColour(self: Bolt, colour: Color3)
	self._colour = colour
	for _, f in self._faces do
		f.BackgroundColor3 = colour
	end
	for _, f in self._shine do
		f.BackgroundColor3 = lighten(colour, 0.5)
	end
end

function StaminaBolt.setCracked(self: Bolt, on: boolean)
	local crack = self._crack
	if crack then
		crack.Visible = on
	end
	for _, f in self._shine do
		(f.Parent :: Frame).Visible = not on -- the strip's clip frame
	end
end

function StaminaBolt.destroy(self: Bolt)
	self.root:Destroy()
end

return StaminaBolt
