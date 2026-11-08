--!strict
-- BodyPaint (Round 7 C-02 and C-03, Round 8 C-04): paint that covers only a car's body panels. Adam: white paint put "a white film over the
-- entire car". The cars are one mesh each (body, glass, lights and tyres share one texture), so the paint is a copy of the body
-- mesh whose texture is drawn here (an EditableImage, MeshPart.TextureContent): painted where the car's mask says "body",
-- see-through everywhere else, with the car's own light and shade kept from the mask. The copy is 2% transparent: a mesh only
-- honours its texture's see-through pixels in the transparent pass (found in Studio, 2026-11-05; a game script may not set a
-- SurfaceAppearance colour map, which was the first plan). The masks are in
-- PaintMasks (one per car texture; Gold and Diamond editions share the Normal car's mask, each Rainbow edition has its own).
-- Round 8 (C-04): a mask value is a region label, not only "paint here". 1 to 6 = body panel (dark to bright shade); 8 glass,
-- 9 light, 10 tyre or rim, 11 trim (chrome, grille, bumper, plate, sign, rack), 12 interior or underside, 13 other: never painted.
-- The painted edge is feathered one texel inward so the body-to-glass line is smooth, and BodyPaint.labels hands the label map to
-- the paint audit (src/server/Beta/PaintAudit.luau).
--
-- One shared animator moves every animated paint: colour-only paints (Colour Shift, Rainbow, Neon Pulse) redraw from six shade
-- colours 12 times a second; patterned paints (Aurora, Lava, Ocean, Galaxy, Sparkle, ...) redraw a few times a second.
-- Hidden or destroyed paints stop at once.
--
--   BodyPaint.supported(carName) -> boolean
--   BodyPaint.labels(carName) -> (buffer?, number)        (region label per texel, 256 x 256, and the size)
--   BodyPaint.bodyParts(model: Model) -> { MeshPart }     (the parts that take paint: Anchors.PaintParts, else body_geom)
--   local p = BodyPaint.new(bodyMesh: MeshPart, carName) -> Painter?      (nil: no mask for this car, or images not available)
--   p:set(item?)   p:destroy()

local AssetService = game:GetService("AssetService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Catalog = require(ReplicatedStorage.Shared.UI.CosmeticPreviewCatalog)
local PaintParts = require(ReplicatedStorage.Shared.Style.Anchors.PaintParts)
local PaintMasks = require(script.Parent.PaintMasks)
local PaintMasksRainbow = require(script.Parent.PaintMasksRainbow)

local BodyPaint = {}

-- the region names behind the label values 8 to 13 (1 to 6 are body shades)
BodyPaint.LABEL_NAMES = table.freeze({
	[8] = "glass",
	[9] = "light",
	[10] = "tyre",
	[11] = "trim",
	[12] = "interior",
	[13] = "other",
})

local N = 256
local GROW = 1.006 -- the paint shell sits just outside the body
local SHELL_COLOUR = Color3.fromRGB(163, 162, 165) -- the Normal cars' own body colour: the shell keeps that tint on every edition
local PATTERN_HZ = 7 -- how often a patterned paint redraws
-- the mask's six shades, as a brightness multiplier on the paint colour (the car's own light and shade)
local SHADE = { 0.42, 0.58, 0.74, 0.9, 1.04, 1.18 }

local B64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local B64_VALUE: { [number]: number } = {}
for i = 1, #B64 do
	B64_VALUE[string.byte(B64, i)] = i - 1
end

-- The decoded mask of one car: shade per pixel (0 = not painted), the paint's opacity per pixel (full inside, feathered on the
-- edge), the region label per pixel (see the header), the painted pixels listed once, and the ones well inside the paint.
type Mask = { shade: buffer, alpha: buffer, label: buffer, body: { number }, inside: { number } }
local masks: { [string]: Mask } = {}

local function baseName(carName: string): string
	return (carName:gsub("^Gold ", ""):gsub("^Diamond ", ""))
end

local function decode(text: string): buffer
	local bytes = buffer.create(math.floor(#text * 3 / 4) + 3)
	local n = 0
	for i = 1, #text, 4 do
		local a = B64_VALUE[string.byte(text, i)] or 0
		local b = B64_VALUE[string.byte(text, i + 1)] or 0
		local c = B64_VALUE[string.byte(text, i + 2)]
		local d = B64_VALUE[string.byte(text, i + 3)]
		buffer.writeu8(bytes, n, bit32.bor(bit32.lshift(a, 2), bit32.rshift(b, 4)))
		n += 1
		if c then
			buffer.writeu8(bytes, n, bit32.band(bit32.bor(bit32.lshift(b, 4), bit32.rshift(c, 2)), 255))
			n += 1
		end
		if c and d then
			buffer.writeu8(bytes, n, bit32.band(bit32.bor(bit32.lshift(c, 6), d), 255))
			n += 1
		end
	end
	local values = buffer.create(N * N)
	local at = 0
	for i = 0, n - 2, 2 do
		local hi = buffer.readu8(bytes, i)
		local value = bit32.rshift(hi, 4)
		local len = bit32.lshift(bit32.band(hi, 15), 8) + buffer.readu8(bytes, i + 1) + 1
		if value > 0 then
			buffer.fill(values, at, value, math.min(len, N * N - at))
		end
		at += len
		if at >= N * N then
			break
		end
	end
	return values
end

local function maskFor(carName: string): Mask?
	local key = baseName(carName)
	local known = masks[key]
	if known then
		return known
	end
	local text = PaintMasks[key] or PaintMasksRainbow[key]
	if not text then
		return nil
	end
	local label = decode(text)
	local shade = buffer.create(N * N)
	for i = 0, N * N - 1 do
		local v = buffer.readu8(label, i)
		if v >= 1 and v <= 6 then
			buffer.writeu8(shade, i, v)
		end
	end
	-- the paint's edge is feathered one texel inward: a pixel with fewer painted neighbours is a little see-through, so the
	-- body-to-glass line is soft instead of stair-stepped (Adam: the Galaxy paint's ragged edges)
	local alpha = buffer.create(N * N)
	local body = {}
	local inside = {}
	for i = 0, N * N - 1 do
		if buffer.readu8(shade, i) > 0 then
			local x, y = i % N, i // N
			local near = 0
			for dy = -1, 1 do
				for dx = -1, 1 do
					if dx ~= 0 or dy ~= 0 then
						local nx, ny = x + dx, y + dy
						if nx >= 0 and nx < N and ny >= 0 and ny < N and buffer.readu8(shade, ny * N + nx) > 0 then
							near += 1
						end
					end
				end
			end
			buffer.writeu8(alpha, i, if near == 8 then 255 else 150 + 13 * near)
			table.insert(body, i)
			if near == 8 then
				table.insert(inside, i)
			end
		end
	end
	local mask = { shade = shade, alpha = alpha, label = label, body = body, inside = inside }
	masks[key] = mask
	return mask
end

-- The region label of every texel of a car's mask (for the paint audit): the buffer (256 x 256 bytes, nil when the car has no
-- mask) and its width.
function BodyPaint.labels(carName: string): (buffer?, number)
	local mask = maskFor(carName)
	if not mask then
		return nil, N
	end
	return mask.label, N
end

-- The parts of a car model that take paint: the car's PaintParts entry, else every "body_geom". Everything else (wheels, the pizza
-- sign, roof racks, glass or lights built as their own parts) never takes paint.
function BodyPaint.bodyParts(model: Model): { MeshPart }
	local entry = PaintParts[baseName(model.Name)] or PaintParts[model.Name]
	local wanted: { string } = (entry and entry.body) or { "body_geom" }
	local list: { MeshPart } = {}
	for _, name in wanted do
		local part = model:FindFirstChild(name, true)
		if part and part:IsA("MeshPart") then
			table.insert(list, part)
		end
	end
	return list
end

function BodyPaint.supported(carName: string): boolean
	local key = baseName(carName)
	return PaintMasks[key] ~= nil or PaintMasksRainbow[key] ~= nil
end

local function sample(colours: { Color3 }, t: number): Color3
	local n = #colours
	local f = (t % 1) * n
	local i = math.floor(f)
	return colours[(i % n) + 1]:Lerp(colours[((i + 1) % n) + 1], f - i)
end

local function clamp255(v: number): number
	return if v > 255 then 255 elseif v < 0 then 0 else v
end

-- A colour for each of the six shades, from a rule.
local function shadeColours(fn: (number, number) -> Color3): { Color3 }
	local out = {}
	for s = 1, 6 do
		out[s] = fn(s, SHADE[s])
	end
	return out
end

local function times(c: Color3, k: number): Color3
	return Color3.new(math.min(c.R * k, 1), math.min(c.G * k, 1), math.min(c.B * k, 1))
end

-- How each still paint looks at each shade. Animated paints start from these and move.
local function stillLook(item: Catalog.Item): { Color3 }
	local c = item.colours
	local kind = item.kind
	if kind == "metallic" then
		return shadeColours(function(s: number, k: number): Color3
			local base = times(c[1], k ^ 1.7)
			return if s == 6
				then base:Lerp(Color3.new(1, 1, 1), 0.55)
				elseif s == 5 then base:Lerp(Color3.new(1, 1, 1), 0.2)
				else base
		end)
	elseif kind == "pearl" or kind == "gradient" then
		local soft = kind == "pearl"
		return shadeColours(function(s: number, k: number): Color3
			local mix = c[1]:Lerp(c[2] or c[1], (s - 1) / 5)
			return times(mix, if soft then 0.8 + 0.2 * k else 0.7 + 0.3 * k)
		end)
	elseif kind == "chrome" then
		return shadeColours(function(s: number, _k: number): Color3
			local v = ({ 0.16, 0.3, 0.62, 0.86, 0.97, 1 })[s]
			return Color3.new(v * 0.95, v * 0.97, v)
		end)
	elseif kind == "galaxy" then
		return shadeColours(function(_s: number, k: number): Color3
			return times(c[1]:Lerp(c[2], 0.25), k)
		end)
	end
	-- solid, and the white base under the tinted paints
	local base = if kind == "animated"
			or kind == "rainbow"
			or kind == "pulse"
			or kind == "holo"
		then Color3.new(1, 1, 1)
		else c[1]
	return shadeColours(function(_s: number, k: number): Color3
		return times(base, k * (if base == Color3.new(1, 1, 1) then 0.82 else 1))
	end)
end

local TINTED: { [string]: boolean } = { animated = true, rainbow = true, pulse = true, holo = true }
local PATTERNED: { [string]: boolean } =
	{ flow = true, galaxy = true, sparkle = true, molten = true, electric = true, holo = true }

export type Painter = {
	set: (self: Painter, item: Catalog.Item?) -> (),
	snapshot: (self: Painter) -> buffer?,
	destroy: (self: Painter) -> (),
}

local live: { [any]: boolean } = {}
local animator: RBXScriptConnection? = nil

local TINT_HZ = 12
local GALAXY_HZ = 5 -- the nebula drifts slowly and the stars twinkle slowly: no need to redraw faster

-- The colour a colour-only paint shows at time t.
local function tintAt(item: Catalog.Item, t: number): Color3
	local c = item.colours
	if item.kind == "pulse" then
		local beat = (math.sin(t * math.pi * 2 / 1.2) + 1) / 2
		return c[1]:Lerp(c[2] or c[1], beat)
	elseif item.kind == "rainbow" then
		return Color3.fromHSV((t / (item.cycleSeconds or 4)) % 1, 0.85, 1)
	end
	return sample(c, t / (item.cycleSeconds or 6))
end

-- Galaxy (Round 8, O-09: "the Galaxy paint's ragged edges"): a smooth deep-space base with two soft nebula bands, and stars that
-- sit still and twinkle. The old version drifted single star pixels across the texture (they flickered over the mask's edge) and cut
-- the nebula at a hard threshold. Stars now only sit well inside the painted area, and nothing here has a hard edge.
local SIN_LUT: { number } = {}
for i = 0, 1023 do
	SIN_LUT[i] = (math.sin(i / 1024 * math.pi * 2) + 1) / 2
end

local function wave(phase: number): number
	return SIN_LUT[math.floor((phase % 1) * 1024)]
end

local function blendPixel(pixels: buffer, i: number, c: Color3, k: number)
	local o = i * 4
	buffer.writeu8(pixels, o, clamp255(buffer.readu8(pixels, o) * (1 - k) + c.R * 255 * k))
	buffer.writeu8(pixels, o + 1, clamp255(buffer.readu8(pixels, o + 1) * (1 - k) + c.G * 255 * k))
	buffer.writeu8(pixels, o + 2, clamp255(buffer.readu8(pixels, o + 2) * (1 - k) + c.B * 255 * k))
end

type Star = { i: number, phase: number, big: boolean }

local function buildStars(mask: Mask): { Star }
	local stars: { Star } = {}
	local rng = Random.new(7)
	local pool = mask.inside
	if #pool == 0 then
		return stars
	end
	for n = 1, 230 do
		table.insert(stars, { i = pool[rng:NextInteger(1, #pool)], phase = rng:NextNumber(), big = n % 4 == 0 })
	end
	return stars
end

local function drawGalaxy(self: any, t: number)
	local mask: Mask = self._mask
	local item: Catalog.Item = self._item
	local pixels: buffer = self._pixels
	local look: { Color3 } = self._look
	local shade = mask.shade
	local glow = item.colours[2]
	local spark = item.colours[#item.colours]
	local gr, gg, gb = glow.R * 255, glow.G * 255, glow.B * 255
	local shift = t / 26
	for _, i in mask.body do
		local c = look[buffer.readu8(shade, i)]
		local x, y = i % N, i // N
		local a = wave(x / N * 1.6 + y / N * 0.8 + shift)
		local b = wave(x / N * 0.7 - y / N * 1.3 - shift * 0.7 + 0.27)
		local k = a * a * a * 0.5 + b * b * 0.22
		local o = i * 4
		buffer.writeu8(pixels, o, clamp255(c.R * 255 + gr * k))
		buffer.writeu8(pixels, o + 1, clamp255(c.G * 255 + gg * k))
		buffer.writeu8(pixels, o + 2, clamp255(c.B * 255 + gb * k))
	end
	for _, star in self._stars :: { Star } do
		local tw = wave(t / 2.4 + star.phase)
		local k = 0.25 + 0.75 * tw * tw
		blendPixel(pixels, star.i, spark, k)
		if star.big then
			local arm = k * 0.45
			blendPixel(pixels, star.i - 1, spark, arm)
			blendPixel(pixels, star.i + 1, spark, arm)
			blendPixel(pixels, star.i - N, spark, arm)
			blendPixel(pixels, star.i + N, spark, arm)
		end
	end
	self._image:WritePixelsBuffer(Vector2.zero, Vector2.new(N, N), pixels)
end

local function draw(self: any, t: number)
	local mask: Mask = self._mask
	local item: Catalog.Item = self._item
	local pixels: buffer = self._pixels
	local look: { Color3 } = self._look
	local kind = item.kind
	if kind == "galaxy" then
		drawGalaxy(self, t)
		return
	end
	if TINTED[kind or ""] then
		local colour = tintAt(item, t)
		look = shadeColours(function(_s: number, k: number): Color3
			return times(colour, k * 0.95)
		end)
	end
	local shade = mask.shade
	if kind == "flow" or kind == "molten" then
		-- bands of the paint's colours drifting across the body (in the texture's own layout)
		local colours = item.colours
		local lut = {}
		for i = 0, 63 do
			lut[i] = sample(colours, i / 64)
		end
		local shift = t / (item.cycleSeconds or 6)
		for _, i in mask.body do
			local x, y = i % N, i // N
			local phase = (x / N + y / (N * 2) + shift) % 1
			local c = lut[math.floor(phase * 64)]
			local k = SHADE[buffer.readu8(shade, i)]
			local o = i * 4
			buffer.writeu8(pixels, o, clamp255(c.R * k * 255))
			buffer.writeu8(pixels, o + 1, clamp255(c.G * k * 255))
			buffer.writeu8(pixels, o + 2, clamp255(c.B * k * 255))
		end
		if kind == "molten" then
			-- hot spots that glow
			local rng = Random.new(math.floor(t * PATTERN_HZ))
			for _ = 1, 120 do
				local i = mask.body[rng:NextInteger(1, #mask.body)]
				local o = i * 4
				buffer.writeu8(pixels, o, 255)
				buffer.writeu8(pixels, o + 1, 250)
				buffer.writeu8(pixels, o + 2, 200)
			end
		end
	else
		-- still base, then stars, glitter or sparks on top (they move each redraw)
		for _, i in mask.body do
			local c = look[buffer.readu8(shade, i)]
			local o = i * 4
			buffer.writeu8(pixels, o, c.R * 255)
			buffer.writeu8(pixels, o + 1, c.G * 255)
			buffer.writeu8(pixels, o + 2, c.B * 255)
		end
		local count = if kind == "sparkle" then 420 elseif kind == "electric" then 300 else 160
		local rng = Random.new(math.floor(t * PATTERN_HZ))
		local spark = item.colours[#item.colours]
		for _ = 1, count do
			local i = mask.body[rng:NextInteger(1, #mask.body)]
			local o = i * 4
			buffer.writeu8(pixels, o, spark.R * 255)
			buffer.writeu8(pixels, o + 1, spark.G * 255)
			buffer.writeu8(pixels, o + 2, spark.B * 255)
		end
	end
	self._image:WritePixelsBuffer(Vector2.zero, Vector2.new(N, N), pixels)
end

local function step()
	local t = os.clock()
	for p in live do
		if not p._shell.Parent then
			continue
		end
		local kind = p._item and p._item.kind
		local hz = if kind and TINTED[kind] then TINT_HZ elseif kind == "galaxy" then GALAXY_HZ else PATTERN_HZ
		if kind and (PATTERNED[kind] or TINTED[kind]) and t - p._drawn >= 1 / hz then
			p._drawn = t
			draw(p, t)
		end
	end
end

local function watch(p: any, on: boolean)
	if on then
		live[p] = true
		if not animator then
			animator = RunService.Heartbeat:Connect(step)
		end
	else
		live[p] = nil
		if animator and next(live) == nil then
			animator:Disconnect()
			animator = nil
		end
	end
end

local Painter = {}
Painter.__index = Painter

function BodyPaint.new(body: MeshPart, carName: string): Painter?
	local mask = maskFor(carName)
	if not mask then
		return nil
	end
	local ok, image = pcall(function()
		return AssetService:CreateEditableImage({ Size = Vector2.new(N, N) })
	end)
	if not ok or not image then
		warn("[BodyPaint] no paint image for " .. carName .. ": " .. tostring(image))
		return nil
	end
	local shell = body:Clone()
	shell.Name = "BodyPaint"
	for _, d in shell:GetChildren() do
		d:Destroy()
	end
	shell.TextureID = ""
	-- the same plastic on every edition: Gold, Diamond and Rainbow bodies are metal, glass or neon-white, and a shell that copied
	-- that would be tinted gold, see-through or shiny (Round 8, C-04)
	shell.Color = SHELL_COLOUR
	shell.Material = Enum.Material.Plastic
	shell.Reflectance = 0
	shell.Size = body.Size * GROW
	shell.CFrame = body.CFrame
	shell.CastShadow = false
	shell.Transparency = 0.02
	local applied = pcall(function()
		shell.TextureContent = Content.fromObject(image)
	end)
	if not applied then
		image:Destroy()
		shell:Destroy()
		warn("[BodyPaint] this client cannot show drawn paint")
		return nil
	end
	local self = setmetatable(
		{
			_mask = mask,
			_image = image,
			_pixels = buffer.create(N * N * 4),
			_shell = shell,
			_body = body,
			_item = nil,
			_look = {},
			_drawn = 0,
		} :: any,
		Painter
	)
	return self
end

function Painter.set(self: any, item: Catalog.Item?)
	if not item or item.id == "factory_paint" or item.tab ~= "Paint" then
		self._item = nil
		self._shell.Parent = nil
		watch(self, false)
		return
	end
	self._item = item
	self._look = stillLook(item)
	-- every painted pixel opaque (the edge a little see-through), the rest see-through
	local pixels: buffer = self._pixels
	buffer.fill(pixels, 0, 0)
	local mask: Mask = self._mask
	for _, i in mask.body do
		buffer.writeu8(pixels, i * 4 + 3, buffer.readu8(mask.alpha, i))
	end
	self._stars = if item.kind == "galaxy" then buildStars(mask) else nil
	draw(self, os.clock())
	self._drawn = os.clock()
	self._shell.CFrame = self._body.CFrame
	self._shell.Parent = self._body.Parent
	watch(self, TINTED[item.kind or ""] == true or PATTERNED[item.kind or ""] == true)
end

-- What is drawn now: the colour map the shell shows, RGBA bytes (256 x 256), read back from the image (for the paint audit).
function Painter.snapshot(self: any): buffer?
	local ok, pixels = pcall(function()
		return self._image:ReadPixelsBuffer(Vector2.zero, Vector2.new(N, N))
	end)
	if ok then
		return pixels :: buffer
	end
	return nil
end

function Painter.destroy(self: any)
	watch(self, false)
	self._shell:Destroy()
	self._image:Destroy()
end

return BodyPaint
