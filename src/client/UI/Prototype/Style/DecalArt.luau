--!strict
-- DecalArt (Round 7, C-04): the decals, drawn by the game into an image (no uploaded art), and put on both sides of a car's body.
-- Each design is drawn once per colour set in "side view" (x from the nose to the tail, y from the roof to the sills) and shown by
-- a Decal on the left and right of the body's paint shell, mirrored. The animated designs really move: their image scrolls
-- (UVOffset) or their colour pulses, from one shared clock.
--
--   local d = DecalArt.attach(part: BasePart) -> Decals     d:set(item?)   d:destroy()

local AssetService = game:GetService("AssetService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Catalog = require(ReplicatedStorage.Shared.UI.CosmeticPreviewCatalog)

local DecalArt = {}

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

-- One image per design and colour set, made the first time it is needed.
local made: { [string]: EditableImage } = {}
function DecalArt.image(item: Catalog.Item): EditableImage?
	local key = item.key or ""
	local draw = DRAW[key]
	if not draw then
		return nil
	end
	local cacheKey = item.id
	local known = made[cacheKey]
	if known then
		return known
	end
	local ok, image = pcall(function()
		return AssetService:CreateEditableImage({ Size = Vector2.new(W, H) })
	end)
	if not ok or not image then
		return nil
	end
	local c = canvas()
	draw(c, item.colours)
	image:WritePixelsBuffer(Vector2.zero, Vector2.new(W, H), c.px)
	made[cacheKey] = image
	return image
end

export type Decals = { set: (self: Decals, item: Catalog.Item?) -> (), destroy: (self: Decals) -> () }

local moving: { [any]: boolean } = {}
local clock: RBXScriptConnection? = nil

local function tick()
	local t = os.clock()
	for d in moving do
		local item: Catalog.Item = d._item
		for _, decal in d._decals do
			if item.key == "chevrons" or item.key == "flames" then
				pcall(function()
					(decal :: any).UVOffset = Vector2.new((-t * (if item.key == "flames" then 0.6 else 0.35)) % 1, 0)
				end)
			end
			if item.key == "lightning" or item.key == "stripe" or item.key == "flames" then
				local beat = (math.sin(t * (if item.key == "stripe" then 1.6 else 6)) + 1) / 2
				local tone = if item.key == "stripe"
					then Color3.fromHSV((t / 4) % 1, 0.8, 1)
					else Color3.new(1, 1, 1):Lerp(item.colours[1], beat * 0.6)
				pcall(function()
					(decal :: any).Color3 = tone
				end)
				decal.Transparency = if item.key == "lightning" then 0.35 * (1 - beat) else 0
			end
		end
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

-- `car` is the model whose pivot faces the car's way (right = +X); the decals go on the two faces of `part` that face the car's
-- sides, whichever way the mesh itself was turned.
function DecalArt.attach(part: BasePart, car: Model?): Decals
	return setmetatable({ _part = part, _car = car, _decals = {}, _item = nil } :: any, Holder) :: any
end

local FACES = {
	Enum.NormalId.Right,
	Enum.NormalId.Left,
	Enum.NormalId.Top,
	Enum.NormalId.Bottom,
	Enum.NormalId.Back,
	Enum.NormalId.Front,
}
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

function Holder.set(self: any, item: Catalog.Item?)
	for _, d in self._decals do
		d:Destroy()
	end
	self._decals = {}
	self._item = item
	watch(self, false)
	if not item or item.isNone then
		return
	end
	local image = DecalArt.image(item)
	if not image then
		return
	end
	for _, face in sideFaces(self._part, self._car) do
		local decal = Instance.new("Decal")
		decal.Name = "StyleDecal"
		decal.Face = face
		local ok = pcall(function()
			(decal :: any).ColorMapContent = Content.fromObject(image)
		end)
		if not ok then
			decal:Destroy()
			return
		end
		decal.Parent = self._part
		table.insert(self._decals, decal)
	end
	watch(self, item.tier == "animated")
end

function Holder.destroy(self: any)
	self:set(nil)
end

return DecalArt
