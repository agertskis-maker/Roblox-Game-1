--!strict
-- DecalArt (Round 7 C-04, Round 8 C-05): the decals, drawn by the game into an image (no uploaded art), and put on both sides of a
-- car's body.
--
-- Each design is drawn once per colour set in "left side view": x from the nose (left) to the tail (right), y from the roof to the
-- sills. How it reaches the car depends on whether the car has a measured panel (Anchors/DecalPanels, one per car and side, in the
-- car's own space):
--   * PANEL MODE (every car in assets/cars): the design is fitted inside the car's door and quarter panel (never over the windows,
--     wheel arches, lights or door gap) and drawn into a padded picture that a Decal projects onto the body's side face; the
--     picture is transparent everywhere outside the panel. The right side gets the design turned round (flames, stripes, chevrons,
--     the shark grin all face the nose on both sides); numbers are never turned, so "07" reads correctly on both sides.
--   * AUTO MODE (a car with no panel entry): the whole design is stretched over the body's side faces, as in Round 7, but the right
--     side is turned round the same way.
-- The animated designs really move: their colour pulses, and in panel mode their pattern runs through a few pre-drawn frames (in
-- auto mode the image scrolls with UVOffset), all from one shared clock.
--
--   local d = DecalArt.attach(part: BasePart, car: Model?, carName: string?) -> Decals     d:set(item?)   d:destroy()
--   DecalArt.image(item) -> EditableImage?     the design on its own (shop thumbnails)
--   DecalArt.panels(car, carName?) -> DecalPanels?     DecalArt.fit(item, panelSize) -> Vector2?     (the audit uses these)

local AssetService = game:GetService("AssetService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Catalog = require(ReplicatedStorage.Shared.UI.CosmeticPreviewCatalog)
local Types = require(ReplicatedStorage.Shared.Style.Anchors.Types)
local DecalPanels = require(ReplicatedStorage.Shared.Style.Anchors.DecalPanels)

local DecalArt = {}

export type Panels = Types.DecalPanels

local W, H = 256, 96

-- A drawing surface: RGBA pixels, painted with simple shapes.
type Canvas = { px: buffer }

local function canvas(): Canvas
	local px = buffer.create(W * H * 4)
	return { px = px }
end

local function put(c: Canvas, x: number, y: number, colour: Color3, alpha: number?)
	x, y = math.floor(x), math.floor(y)
	if x < 0 or y < 0 or x >= W or y >= H then
		return
	end
	local o = (y * W + x) * 4
	buffer.writeu8(c.px, o, colour.R * 255)
	buffer.writeu8(c.px, o + 1, colour.G * 255)
	buffer.writeu8(c.px, o + 2, colour.B * 255)
	buffer.writeu8(c.px, o + 3, math.floor((alpha or 1) * 255))
end

local function rect(c: Canvas, x0: number, y0: number, x1: number, y1: number, colour: Color3)
	for y = math.floor(y0), math.ceil(y1) - 1 do
		for x = math.floor(x0), math.ceil(x1) - 1 do
			put(c, x, y, colour)
		end
	end
end

-- Fill every pixel where `inside(x, y)` is true.
local function shape(c: Canvas, colour: Color3, inside: (number, number) -> boolean)
	for y = 0, H - 1 do
		for x = 0, W - 1 do
			if inside(x + 0.5, y + 0.5) then
				put(c, x, y, colour)
			end
		end
	end
end

local function disc(c: Canvas, cx: number, cy: number, r: number, colour: Color3)
	for y = math.floor(cy - r), math.ceil(cy + r) do
		for x = math.floor(cx - r), math.ceil(cx + r) do
			if (x + 0.5 - cx) ^ 2 + (y + 0.5 - cy) ^ 2 <= r * r then
				put(c, x, y, colour)
			end
		end
	end
end

local function star(c: Canvas, cx: number, cy: number, r: number, colour: Color3)
	shape(c, colour, function(x: number, y: number): boolean
		local dx, dy = x - cx, y - cy
		local d = math.sqrt(dx * dx + dy * dy)
		if d > r then
			return false
		end
		local a = math.atan2(dy, dx) + math.pi / 2
		return d <= r * (0.42 + 0.58 * ((math.cos(5 * a) + 1) / 2) ^ 2)
	end)
end

-- Thick line from a to b.
local function line(c: Canvas, ax: number, ay: number, bx: number, by: number, width: number, colour: Color3)
	local steps = math.ceil(math.max(math.abs(bx - ax), math.abs(by - ay)))
	for i = 0, steps do
		local t = i / math.max(steps, 1)
		disc(c, ax + (bx - ax) * t, ay + (by - ay) * t, width / 2, colour)
	end
end

-- Blocky digits (a seven-segment look) for the race numbers.
local SEGMENTS: { [string]: string } =
	{ ["2"] = "abged", ["3"] = "abgcd", ["7"] = "abc", ["0"] = "abcdef", ["1"] = "bc", ["4"] = "fgbc", ["5"] = "afgcd" }
local function digit(c: Canvas, ch: string, x: number, y: number, w: number, h: number, t: number, colour: Color3)
	local s = SEGMENTS[ch] or ""
	local function on(k: string): boolean
		return string.find(s, k, 1, true) ~= nil
	end
	if on("a") then
		rect(c, x, y, x + w, y + t, colour)
	end
	if on("g") then
		rect(c, x, y + h / 2 - t / 2, x + w, y + h / 2 + t / 2, colour)
	end
	if on("d") then
		rect(c, x, y + h - t, x + w, y + h, colour)
	end
	if on("f") then
		rect(c, x, y, x + t, y + h / 2, colour)
	end
	if on("b") then
		rect(c, x + w - t, y, x + w, y + h / 2, colour)
	end
	if on("e") then
		rect(c, x, y + h / 2, x + t, y + h, colour)
	end
	if on("c") then
		rect(c, x + w - t, y + h / 2, x + w, y + h, colour)
	end
end

local function number(c: Canvas, text: string, colours: { Color3 })
	-- a round badge with the number
	disc(c, 128, 52, 30, colours[1])
	disc(c, 128, 52, 25, colours[2] or Color3.new(0, 0, 0))
	local n = #text
	local w, h, t = 16, 28, 5
	local x0 = 128 - (n * w + (n - 1) * 5) / 2
	for i = 1, n do
		digit(c, string.sub(text, i, i), x0 + (i - 1) * (w + 5), 38, w, h, t, colours[1])
	end
end

local DRAW: { [string]: (Canvas, { Color3 }) -> () } = {}

DRAW.stripe = function(c, k)
	rect(c, 0, 40, W, 58, k[1])
end
DRAW.twin = function(c, k)
	rect(c, 0, 36, W, 46, k[1])
	rect(c, 0, 52, W, 62, k[2] or k[1])
end
DRAW.pin = function(c, k)
	rect(c, 0, 46, W, 49, k[1])
	rect(c, 20, 52, W - 20, 54, k[1])
end
DRAW.checkers = function(c, k)
	for y = 0, 2 do
		for x = 0, 31 do
			rect(c, x * 8, 40 + y * 8, x * 8 + 8, 48 + y * 8, if (x + y) % 2 == 0 then k[1] else (k[2] or k[1]))
		end
	end
end
DRAW.seven = function(c, k)
	number(c, "7", k)
end
DRAW.twentythree = function(c, k)
	number(c, "23", k)
end
-- Round 8: "07" (the decal audit and the placement guide use it; no catalog item points at it yet)
DRAW.number07 = function(c, k)
	number(c, "07", k)
end
-- Round 8: the decal audit's "show me the panel" design: a frame with a cross, filling the whole panel (no catalog item uses it)
DRAW.panel = function(c, k)
	rect(c, 0, 0, W, 3, k[1])
	rect(c, 0, H - 3, W, H, k[1])
	rect(c, 0, 0, 3, H, k[1])
	rect(c, W - 3, 0, W, H, k[1])
	line(c, 0, 0, W, H, 2, k[2] or k[1])
	line(c, 0, H, W, 0, 2, k[2] or k[1])
end
DRAW.stars = function(c, k)
	for i = 0, 6 do
		star(c, 18 + i * 37, 48 + (i % 2) * 10 - 5, 11, k[1])
	end
end
DRAW.dots = function(c, k)
	for i = 0, 7 do
		for j = 0, 1 do
			disc(c, 16 + i * 32 + j * 16, 36 + j * 24, 8, k[1])
		end
	end
end
DRAW.flames = function(c, k)
	-- licks from the nose (x = 0) back along the side
	local function lick(colour: Color3, scale: number)
		shape(c, colour, function(x: number, y: number): boolean
			local along = x / W
			if along > 0.75 * scale then
				return false
			end
			local mid = 56
			local reach = (1 - along / (0.75 * scale)) * 26 * scale
			local wave = math.sin(along * 34) * 7 * scale
			return math.abs(y - mid - wave) < reach * (0.55 + 0.45 * math.abs(math.sin(along * 17)))
		end)
	end
	lick(k[1], 1)
	lick(k[2] or k[1], 0.75)
	lick(k[3] or k[2] or k[1], 0.45)
end
DRAW.lightning = function(c, k)
	local pts = { { 6, 50 }, { 70, 34 }, { 58, 56 }, { 140, 38 }, { 126, 62 }, { 250, 44 } }
	for i = 1, #pts - 1 do
		line(c, pts[i][1], pts[i][2], pts[i + 1][1], pts[i + 1][2], 9, k[2] or k[1])
	end
	for i = 1, #pts - 1 do
		line(c, pts[i][1], pts[i][2], pts[i + 1][1], pts[i + 1][2], 5, k[1])
	end
end
DRAW.wings = function(c, k)
	for f = 0, 4 do
		local y = 30 + f * 9
		local len = 120 - f * 18
		line(c, 150, 48, 150 - len, y - 12, 8, if f % 2 == 0 then k[1] else (k[2] or k[1]))
	end
	disc(c, 154, 48, 10, k[1])
end
DRAW.swoosh = function(c, k)
	for x = 0, W - 1, 1 do
		local t = x / W
		disc(c, x, 64 - math.sin(t * math.pi) * 30, 4 + 4 * math.sin(t * math.pi), k[1])
		disc(c, x, 72 - math.sin(t * math.pi) * 22, 2 + 3 * math.sin(t * math.pi), k[2] or k[1])
	end
end
DRAW.splatter = function(c, k)
	local rng = Random.new(42)
	for i = 1, 14 do
		local cx, cy = rng:NextNumber(10, W - 10), rng:NextNumber(20, H - 20)
		local colour = k[(i % #k) + 1]
		disc(c, cx, cy, rng:NextNumber(6, 13), colour)
		for _ = 1, 6 do
			disc(c, cx + rng:NextNumber(-22, 22), cy + rng:NextNumber(-14, 14), rng:NextNumber(1.5, 4), colour)
		end
	end
end
DRAW.circuit = function(c, k)
	local rng = Random.new(9)
	for _ = 1, 9 do
		local x, y = rng:NextNumber(0, W), rng:NextInteger(3, 9) * 9
		local len = rng:NextNumber(30, 90)
		line(c, x, y, x + len, y, 3, k[1])
		local up = if rng:NextNumber() > 0.5 then 12 else -12
		line(c, x + len, y, x + len + 12, y + up, 3, k[1])
		disc(c, x + len + 12, y + up, 4, k[1])
		disc(c, x, y, 4, k[1])
	end
end
DRAW.shark = function(c, k)
	-- a grin on the nose: a red mouth with white teeth
	shape(c, k[2] or k[1], function(x: number, y: number): boolean
		return x < 70 and math.abs(y - 60) < 14 * (1 - x / 70)
	end)
	for i = 0, 5 do
		local x = 4 + i * 10
		shape(c, k[1], function(px: number, py: number): boolean
			return math.abs(px - x - 4) < (1 - math.abs(py - 52) / 8) * 4 and py < 60 and py > 46
		end)
	end
end
DRAW.chevrons = function(c, k)
	for i = 0, 7 do
		local x = i * 32 + 4
		line(c, x + 18, 34, x, 50, 7, k[(i % #k) + 1])
		line(c, x, 50, x + 18, 66, 7, k[(i % #k) + 1])
	end
end

-- One drawing per design and colour set (its pixels and the box round what is drawn), made the first time it is needed.
type Design = { px: buffer, minX: number, minY: number, maxX: number, maxY: number, base: Color3 }
local designs: { [string]: Design } = {}

local function designFor(item: Catalog.Item): Design?
	local draw = DRAW[item.key or ""]
	if not draw then
		return nil
	end
	local known = designs[item.id]
	if known then
		return known
	end
	local c = canvas()
	draw(c, item.colours)
	local minX, minY, maxX, maxY = W, H, -1, -1
	for y = 0, H - 1 do
		for x = 0, W - 1 do
			if buffer.readu8(c.px, (y * W + x) * 4 + 3) > 8 then
				minX, maxX = math.min(minX, x), math.max(maxX, x)
				minY, maxY = math.min(minY, y), math.max(maxY, y)
			end
		end
	end
	if maxX < 0 then
		return nil
	end
	local design: Design =
		{ px = c.px, minX = minX, minY = minY, maxX = maxX, maxY = maxY, base = item.colours[1] or Color3.new(1, 1, 1) }
	designs[item.id] = design
	return design
end

-- The design on its own, as an image (the shop's thumbnails use this).
local made: { [string]: EditableImage } = {}
function DecalArt.image(item: Catalog.Item): EditableImage?
	local design = designFor(item)
	if not design then
		return nil
	end
	local known = made[item.id]
	if known then
		return known
	end
	local ok, image = pcall(function()
		return AssetService:CreateEditableImage({ Size = Vector2.new(W, H) })
	end)
	if not ok or not image then
		return nil
	end
	image:WritePixelsBuffer(Vector2.zero, Vector2.new(W, H), design.px)
	made[item.id] = image
	return image
end

-- The design turned round left to right (the right side of a car, in auto mode).
local madeTurned: { [string]: EditableImage } = {}
local function turnedImage(item: Catalog.Item): EditableImage?
	local known = madeTurned[item.id]
	if known then
		return known
	end
	local design = designFor(item)
	if not design then
		return nil
	end
	local px = buffer.create(W * H * 4)
	for y = 0, H - 1 do
		for x = 0, W - 1 do
			buffer.copy(px, (y * W + x) * 4, design.px, (y * W + (W - 1 - x)) * 4, 4)
		end
	end
	local ok, image = pcall(function()
		return AssetService:CreateEditableImage({ Size = Vector2.new(W, H) })
	end)
	if not ok or not image then
		return nil
	end
	image:WritePixelsBuffer(Vector2.zero, Vector2.new(W, H), px)
	madeTurned[item.id] = image
	return image
end

-- How a design sits in a panel -----------------------------------------------------------------------------------------------------
-- Numbers are never turned round, so "07" reads correctly on both sides; every other design faces the nose on both sides.
local KEEP_ORIENTATION: { [string]: boolean } = { seven = true, twentythree = true, number07 = true }
-- Band designs fill a panel's length and take this share of its height; every other design keeps its own proportions.
local BAND: { [string]: number } =
	{ stripe = 0.46, twin = 0.66, pin = 0.26, checkers = 0.6, lightning = 0.7, swoosh = 0.7, panel = 1 }
local FILL = 0.94 -- how much of the panel a design may use (the panel already keeps clear of windows and seams)
-- Animated designs that run through pre-drawn frames in panel mode: the share of the design one cycle covers (nil: all of it), the
-- seconds one cycle takes, and which way it runs (1 toward the nose, -1 toward the tail).
local FRAMES = 8
local RUNS: { [string]: { period: number?, seconds: number, dir: number } } = {
	flames = { period = nil, seconds = 1.4, dir = -1 },
	chevrons = { period = 64 / 243, seconds = 0.8, dir = 1 },
}
local CANVAS_WIDTH = 512
-- Round 8 playtest (Adam: "make the decals more dramatic, you can cover the car with the decal"): a design may spread this much past
-- its measured door panel, over the wheel arches and up to the window line; whatever runs off the body side is simply not drawn.
local DRAMA = Vector2.new(2.4, 2)

-- The size in studs (at the car's authored size) that a design takes inside a panel.
local function fitSize(key: string, design: Design, panel: Vector2): Vector2
	local cw = design.maxX - design.minX + 1
	local ch = design.maxY - design.minY + 1
	local inW, inH = panel.X * FILL, panel.Y * FILL
	local band = BAND[key]
	if band then
		return Vector2.new(inW, math.min(inH, band * panel.Y))
	end
	local s = math.min(inW / cw, inH / ch)
	return Vector2.new(cw * s, ch * s)
end

function DecalArt.fit(item: Catalog.Item, panelSize: Vector2): Vector2?
	local design = designFor(item)
	if not design then
		return nil
	end
	return fitSize(item.key or "", design, panelSize)
end

-- Where a car's panels are ------------------------------------------------------------------------------------------------------------
local function carKeyOf(car: Model?, carName: string?): string?
	local name = carName
	if not name and car then
		local attr = car:GetAttribute("CarName")
		name = if typeof(attr) == "string" then attr else car.Name
	end
	if not name then
		return nil
	end
	return (name:gsub("^Gold ", ""):gsub("^Diamond ", ""):gsub("^Rainbow ", ""))
end

function DecalArt.panels(car: Model?, carName: string?): Panels?
	local key = carKeyOf(car, carName)
	return if key then DecalPanels[key] else nil
end

-- How much bigger (or smaller) the live car is than the model in ReplicatedStorage.Cars that the panels were measured on.
local function scaleFactor(car: Model, key: string): number
	local cars = ReplicatedStorage:FindFirstChild("Cars")
	local template = if cars then cars:FindFirstChild(key) else nil
	if template and template:IsA("Model") then
		return car:GetScale() / template:GetScale()
	end
	return 1
end

-- The car's own space: origin at the bottom centre, +X to the car's right, -Z toward the nose. Every car's pivot is that, and
-- RealCar squares its display copies up the same way; a car that is not squared up gets the frame worked out from its wheels.
local function carFrame(car: Model): CFrame
	local pivot = car:GetPivot()
	local front, rear = Vector3.zero, Vector3.zero
	local nf, nr = 0, 0
	local lowest = math.huge
	for _, d in car:GetDescendants() do
		if d:IsA("BasePart") and string.find(d.Name, "wheel_geom", 1, true) then
			if string.find(d.Name, "front", 1, true) then
				front += d.Position
				nf += 1
			elseif string.find(d.Name, "rear", 1, true) then
				rear += d.Position
				nr += 1
			end
			lowest = math.min(lowest, d.Position.Y - math.max(d.Size.X, d.Size.Y, d.Size.Z) / 2)
		end
	end
	if nf == 0 or nr == 0 then
		return pivot
	end
	local forward = ((front / nf) - (rear / nr)) * Vector3.new(1, 0, 1)
	if forward.Magnitude < 1e-3 then
		return pivot
	end
	forward = forward.Unit
	if pivot.LookVector:Dot(forward) > 0.99 and pivot.UpVector.Y > 0.99 then
		return pivot
	end
	local body = car:FindFirstChild("body_geom", true)
	local centre = if body and body:IsA("BasePart") then body.Position else pivot.Position
	return CFrame.fromMatrix(Vector3.new(centre.X, lowest, centre.Z), forward:Cross(Vector3.yAxis), Vector3.yAxis)
end

-- Which face of the body part a panel is on, and where the panel sits on that face (0 to 1 across and down the face, as a Decal
-- maps its picture: the picture's left edge is the left as you look at the face from outside).
type Region = { face: Enum.NormalId, uc: number, vc: number, su: number, sv: number }

local function regionFor(part: BasePart, frame: CFrame, factor: number, panel: CFrame): Region?
	local world = frame:PointToWorldSpace(panel.Position * factor)
	local out = part.CFrame:VectorToObjectSpace(frame:VectorToWorldSpace(panel.ZVector))
	local lp = part.CFrame:PointToObjectSpace(world)
	local s = part.Size
	local face: Enum.NormalId
	local uc: number
	local su: number
	if math.abs(out.X) >= math.abs(out.Z) then
		if math.abs(out.X) < 0.9 then
			return nil
		end
		su = s.Z
		if out.X > 0 then
			face, uc = Enum.NormalId.Right, 0.5 - lp.Z / su
		else
			face, uc = Enum.NormalId.Left, 0.5 + lp.Z / su
		end
	else
		if math.abs(out.Z) < 0.9 then
			return nil
		end
		su = s.X
		if out.Z > 0 then
			face, uc = Enum.NormalId.Back, 0.5 + lp.X / su
		else
			face, uc = Enum.NormalId.Front, 0.5 - lp.X / su
		end
	end
	return { face = face, uc = uc, vc = 0.5 - lp.Y / s.Y, su = su, sv = s.Y }
end

-- Draws one picture for a Decal: the whole face, transparent, with the design fitted into the rectangle `area` (in the picture's own
-- pixels). `flip` turns the design round left to right; `shift` (a share of the design's width) runs its pattern along.
type Rect = { x0: number, y0: number, x1: number, y1: number }

local function drawSide(
	design: Design,
	cw: number,
	ch: number,
	area: Rect,
	flip: boolean,
	shift: number
): EditableImage?
	local total = cw * ch * 4
	local buf = buffer.create(total)
	-- the design's own colour under the see-through pixels, so soft edges do not go dark
	buffer.writeu8(buf, 0, design.base.R * 255)
	buffer.writeu8(buf, 1, design.base.G * 255)
	buffer.writeu8(buf, 2, design.base.B * 255)
	local filled = 4
	while filled < total do
		buffer.copy(buf, filled, buf, 0, math.min(filled, total - filled))
		filled *= 2
	end
	local px = design.px
	local dw = design.maxX - design.minX + 1
	local dh = design.maxY - design.minY + 1
	local rw, rh = area.x1 - area.x0, area.y1 - area.y0
	local shiftPx = shift * dw
	for y = math.max(0, math.floor(area.y0)), math.min(ch - 1, math.ceil(area.y1) - 1) do
		local sy0 = design.minY + math.clamp((y - area.y0) / rh, 0, 1) * dh
		local sy1 = design.minY + math.clamp((y + 1 - area.y0) / rh, 0, 1) * dh
		local ny = math.max(2, math.ceil(sy1 - sy0))
		for x = math.max(0, math.floor(area.x0)), math.min(cw - 1, math.ceil(area.x1) - 1) do
			local fx0 = math.clamp((x - area.x0) / rw, 0, 1)
			local fx1 = math.clamp((x + 1 - area.x0) / rw, 0, 1)
			if flip then
				fx0, fx1 = 1 - fx1, 1 - fx0
			end
			local sx0, sx1 = fx0 * dw, fx1 * dw
			local nx = math.max(2, math.ceil(sx1 - sx0))
			local aSum, rSum, gSum, bSum = 0, 0, 0, 0
			for j = 0, ny - 1 do
				local sy = math.clamp(math.floor(sy0 + (j + 0.5) / ny * (sy1 - sy0)), design.minY, design.maxY)
				for i = 0, nx - 1 do
					local sx = design.minX + math.floor(sx0 + (i + 0.5) / nx * (sx1 - sx0) + shiftPx) % dw
					local o = (sy * W + sx) * 4
					local a = buffer.readu8(px, o + 3)
					if a > 0 then
						aSum += a
						rSum += buffer.readu8(px, o) * a
						gSum += buffer.readu8(px, o + 1) * a
						bSum += buffer.readu8(px, o + 2) * a
					end
				end
			end
			if aSum > 0 then
				local o = (y * cw + x) * 4
				buffer.writeu8(buf, o, rSum / aSum)
				buffer.writeu8(buf, o + 1, gSum / aSum)
				buffer.writeu8(buf, o + 2, bSum / aSum)
				buffer.writeu8(buf, o + 3, aSum / (nx * ny))
			end
		end
	end
	local ok, image = pcall(function()
		return AssetService:CreateEditableImage({ Size = Vector2.new(cw, ch) })
	end)
	if not ok or not image then
		return nil
	end
	image:WritePixelsBuffer(Vector2.zero, Vector2.new(cw, ch), buf)
	return image
end

export type Layout = {
	face: Enum.NormalId,
	panel: Rect, -- the car's panel, in the picture's pixels
	decal: Rect, -- where the design sits, in the picture's pixels
	size: Vector2, -- the picture's size
	image: EditableImage,
	flipped: boolean,
}

export type Decals = {
	set: (self: Decals, item: Catalog.Item?) -> (),
	destroy: (self: Decals) -> (),
	layout: (self: Decals) -> { [string]: Layout }, -- panel mode: "left" and "right" (the audit reads this)
}

local moving: { [any]: boolean } = {}
local clock: RBXScriptConnection? = nil

local function tick()
	local t = os.clock()
	for d in moving do
		local item: Catalog.Item = d._item
		local key = item.key
		local frames = d._frames
		local run = RUNS[key or ""]
		local frameAt = if frames and run then math.floor(t / (run.seconds / FRAMES)) % FRAMES + 1 else 0
		for _, decal in d._decals do
			local side = d._sides[decal]
			if frames and run then
				if d._frameAt ~= frameAt then
					local list = frames[side]
					local image = list and list[frameAt]
					if image then
						pcall(function()
							(decal :: any).ColorMapContent = Content.fromObject(image)
						end)
					end
				end
			elseif key == "chevrons" or key == "flames" then
				-- auto mode: the whole picture scrolls (the right side runs the other way, because its picture is turned round)
				local turn = if side == "right" then 1 else -1
				pcall(function()
					(decal :: any).UVOffset = Vector2.new((turn * t * (if key == "flames" then 0.6 else 0.35)) % 1, 0)
				end)
			end
			if key == "lightning" or key == "stripe" or key == "flames" then
				local beat = (math.sin(t * (if key == "stripe" then 1.6 else 6)) + 1) / 2
				local tone = if key == "stripe"
					then Color3.fromHSV((t / 4) % 1, 0.8, 1)
					else Color3.new(1, 1, 1):Lerp(item.colours[1], beat * 0.6)
				pcall(function()
					(decal :: any).Color3 = tone
				end)
				decal.Transparency = if key == "lightning" then 0.35 * (1 - beat) else 0
			end
		end
		d._frameAt = frameAt
	end
end

local function watch(d: any, on: boolean)
	if on then
		moving[d] = true
		if not clock then
			clock = RunService.Heartbeat:Connect(tick)
		end
	else
		moving[d] = nil
		if clock and next(moving) == nil then
			clock:Disconnect()
			clock = nil
		end
	end
end

local Holder = {}
Holder.__index = Holder
local warned = false

-- `car` is the model whose pivot faces the car's way (right = +X); the decals go on the two faces of `part` that face the car's
-- sides, whichever way the mesh itself was turned. `carName` is the Normal car's name (the key of DecalPanels); without it the
-- model's CarName attribute is used.
function DecalArt.attach(part: BasePart, car: Model?, carName: string?): Decals
	return setmetatable(
		{
			_part = part,
			_car = car,
			_carName = carName,
			_decals = {},
			_sides = {},
			_images = {},
			_layout = {},
			_item = nil,
		} :: any,
		Holder
	) :: any
end

local FACES = {
	Enum.NormalId.Right,
	Enum.NormalId.Left,
	Enum.NormalId.Top,
	Enum.NormalId.Bottom,
	Enum.NormalId.Back,
	Enum.NormalId.Front,
}
-- The two faces of `part` that face the car's right and left, in that order (without a car: Left, Right as the part sees them).
local function sideFaces(part: BasePart, car: Model?): { Enum.NormalId }
	if not car then
		return { Enum.NormalId.Left, Enum.NormalId.Right }
	end
	local right = car:GetPivot().RightVector
	local best, score = Enum.NormalId.Right, -math.huge
	for _, face in FACES do
		local normal = part.CFrame:VectorToWorldSpace(Vector3.FromNormalId(face))
		local d = normal:Dot(right)
		if d > score then
			best, score = face, d
		end
	end
	local opposite = {
		[Enum.NormalId.Right] = Enum.NormalId.Left,
		[Enum.NormalId.Left] = Enum.NormalId.Right,
		[Enum.NormalId.Top] = Enum.NormalId.Bottom,
		[Enum.NormalId.Bottom] = Enum.NormalId.Top,
		[Enum.NormalId.Back] = Enum.NormalId.Front,
		[Enum.NormalId.Front] = Enum.NormalId.Back,
	}
	return { best, opposite[best] }
end

local function newDecal(self: any, face: Enum.NormalId, image: EditableImage, side: string): boolean
	local decal = Instance.new("Decal")
	decal.Name = "StyleDecal"
	decal.Face = face
	local ok = pcall(function()
		(decal :: any).ColorMapContent = Content.fromObject(image)
	end)
	if not ok then
		decal:Destroy()
		return false
	end
	decal.Parent = self._part
	table.insert(self._decals, decal)
	self._sides[decal] = side
	return true
end

local function clear(self: any)
	for _, d in self._decals do
		d:Destroy()
	end
	for _, image in self._images do
		pcall(function()
			image:Destroy()
		end)
	end
	self._decals = {}
	self._sides = {}
	self._images = {}
	self._layout = {}
	self._frames = nil
	self._frameAt = nil
	self._item = nil
	watch(self, false)
end

-- Panel mode: the design fitted into the car's measured panel on each side. False when this car has no panel entry or the body
-- part cannot be mapped (the caller then falls back to auto mode).
local function panelSet(self: any, item: Catalog.Item): boolean
	local car: Model? = self._car
	local part: BasePart = self._part
	local key = carKeyOf(car, self._carName)
	local panels = if key then DecalPanels[key] else nil
	local design = designFor(item)
	if not car or not key or not panels or not design then
		return false
	end
	local frame = carFrame(car)
	local factor = scaleFactor(car, key)
	local itemKey = item.key or ""
	local size = panels.size * DRAMA
	local fit = fitSize(itemKey, design, size) * factor
	local run = if item.tier == "animated" then RUNS[itemKey] else nil
	local frames: { [string]: { EditableImage } } = {}
	local layout: { [string]: Layout } = {}
	for _, side in { "right", "left" } do
		local region = regionFor(part, frame, factor, if side == "right" then panels.right else panels.left)
		if not region then
			clear(self)
			return false
		end
		local cw = CANVAS_WIDTH
		local ch = math.clamp(math.floor(CANVAS_WIDTH * region.sv / region.su + 0.5), 32, 1024)
		local pxPerU, pxPerV = cw, ch
		local panelRect: Rect = {
			x0 = (region.uc - size.X * factor / 2 / region.su) * pxPerU,
			x1 = (region.uc + size.X * factor / 2 / region.su) * pxPerU,
			y0 = (region.vc - size.Y * factor / 2 / region.sv) * pxPerV,
			y1 = (region.vc + size.Y * factor / 2 / region.sv) * pxPerV,
		}
		local area: Rect = {
			x0 = region.uc * pxPerU - fit.X / 2 / region.su * pxPerU,
			x1 = region.uc * pxPerU + fit.X / 2 / region.su * pxPerU,
			y0 = region.vc * pxPerV - fit.Y / 2 / region.sv * pxPerV,
			y1 = region.vc * pxPerV + fit.Y / 2 / region.sv * pxPerV,
		}
		local flip = side == "right" and not KEEP_ORIENTATION[itemKey]
		local count = if run then FRAMES else 1
		local list: { EditableImage } = {}
		for i = 1, count do
			local shift = 0
			if run then
				local period = run.period or 1
				shift = run.dir * (i - 1) / FRAMES * period
			end
			local image = drawSide(design, cw, ch, area, flip, shift)
			if not image then
				clear(self)
				return false
			end
			table.insert(self._images, image)
			list[i] = image
		end
		frames[side] = list
		if not newDecal(self, region.face, list[1], side) then
			clear(self)
			return false
		end
		layout[side] = {
			face = region.face,
			panel = panelRect,
			decal = area,
			size = Vector2.new(cw, ch),
			image = list[1],
			flipped = flip,
		}
	end
	self._layout = layout
	self._frames = if run then frames else nil
	return true
end

-- Auto mode: the whole design over each side face (a car with no panel entry).
local function autoSet(self: any, item: Catalog.Item): boolean
	local image = DecalArt.image(item)
	if not image then
		return false
	end
	local faces = sideFaces(self._part, self._car)
	local turn = self._car ~= nil and not KEEP_ORIENTATION[item.key or ""]
	for i, face in faces do
		local right = self._car ~= nil and i == 1
		local picture = image
		if right and turn then
			picture = turnedImage(item) or image
		end
		if not newDecal(self, face, picture, if right then "right" else "left") then
			return false
		end
	end
	return true
end

function Holder.set(self: any, item: Catalog.Item?)
	clear(self)
	if not item or item.isNone then
		return
	end
	local placed = false
	if self._car then
		-- a problem in the panel fit must never take the decal away: say so once and use the automatic fit
		local ok, result = pcall(panelSet, self, item)
		if ok then
			placed = result == true
		elseif not warned then
			warned = true
			warn("[DecalArt] panel fit failed, using the automatic fit: " .. tostring(result))
		end
	end
	if not placed then
		clear(self)
		if not autoSet(self, item) then
			return
		end
	end
	self._item = item
	watch(self, item.tier == "animated")
end

function Holder.layout(self: any): { [string]: Layout }
	return self._layout
end

function Holder.destroy(self: any)
	self:set(nil)
end

return DecalArt
