--!strict
-- Trails.Cool (Round 8, T-07): Neon Ribbon, Bubble Pop, Frost Bite, Lightning, Aurora Veil, Retro Grid. See Warm.luau for how a recipe
-- is read: one call per exhaust point, layers added by tier.
local Kit = require(script.Parent.Kit)

local Cool = {}

local W = Color3.new(1, 1, 1)
local seq, num, curve = Kit.seq, Kit.num, Kit.curve

-- Neon Ribbon (Common): two clean ribbons of light twisting round each other. MATCH MY PAINT lives in the colours (Kit.Ctx.k).
function Cool.neon(c: Kit.Ctx)
	local s, k = c.scale, c.k
	local colour = if c.side >= 0 then k[1] else (k[2] or k[1])
	local beam = Kit.beam(c, {
		colour = seq(Kit.hot(colour, 0.5), colour),
		fade = curve({ { 0, 0 }, { 0.7, 0.15 }, { 1, 1 } }),
		w0 = 0.5 * s,
		w1 = 0.12 * s,
		segments = 16,
		light = 1,
		brightness = 2.5,
	})
	Kit.core(c, seq(W, Kit.hot(colour, 0.6)), 0.18 * s)
	Kit.ribbon(c, { life = 0.6, colour = seq(Kit.hot(colour, 0.3), colour), width = num(0.6, 0), light = 1 })
	local phase = if c.side >= 0 then 0 else math.pi
	local home = c.home
	Kit.motion(c, function(t: number)
		local a = t * 6 + phase
		c.at.CFrame = home * CFrame.new(math.cos(a) * 0.5 * s * c.amp, math.sin(a) * 0.5 * s * c.amp, 0)
		beam.CurveSize0 = math.sin(a) * 2.2 * c.amp
		beam.CurveSize1 = -math.sin(a) * 2.2 * c.amp
	end)
end

-- Bubble Pop (Uncommon): a soft ribbon and iridescent bubbles that pop into little stars.
function Cool.bubble(c: Kit.Ctx)
	local s, k = c.scale, c.k
	Kit.core(c, seq(W, k[1]), 0.3 * s)
	Kit.ribbon(c, {
		life = 0.45,
		colour = seq(k[1], k[2] or k[1]),
		fade = curve({ { 0, 0.3 }, { 1, 1 } }),
		width = num(0.5, 0),
		light = 0.8,
	})
	Kit.emit(c, {
		sheet = "bubble",
		rate = 8,
		life = { 1.0, 1.6 },
		speed = { 3, 6 },
		size = curve({ { 0, 0.5 * s }, { 0.2, 1.0 * s }, { 1, 1.1 * s } }),
		colour = seq(W),
		fade = curve({ { 0, 0.15 }, { 0.85, 0.25 }, { 1, 1 } }),
		drag = 1.8,
		accel = Vector3.new(0, 2.5, 0),
		spread = 30,
		light = 0.5,
		rot = true,
		spin = 30,
	})
	Kit.emit(c, { -- the pop: little stars where the bubbles end
		sheet = "flare",
		rate = 7,
		life = { 0.25, 0.4 },
		speed = { 4, 7 },
		size = num(0.8 * s, 0),
		colour = seq(W, k[2] or k[1]),
		spread = 60,
		light = 1,
	})
end

-- Frost Bite (Rare): a pale ribbon, ice shards, snow glints and cold mist.
function Cool.frost(c: Kit.Ctx)
	local s, k = c.scale, c.k
	local ice, deep = k[1], k[2] or k[1]
	Kit.core(c, seq(W, ice), 0.4 * s)
	Kit.ribbon(c, {
		life = 0.6,
		colour = seq(W, deep),
		fade = curve({ { 0, 0.35 }, { 0.6, 0.6 }, { 1, 1 } }),
		width = num(0.7, 0),
	})
	Kit.beam(c, {
		to = c.tip2,
		colour = seq(ice, deep),
		fade = curve({ { 0, 0.4 }, { 0.6, 0.6 }, { 1, 1 } }),
		w0 = 0.50 * s,
		w1 = 1.08 * s,
		light = 0.7,
	})
	Kit.emit(c, { -- shards
		sheet = "ice",
		rate = 10,
		life = { 0.6, 1.0 },
		speed = { 5, 9 },
		size = num(1.7 * s, 1.0 * s),
		colour = seq(W, ice),
		fade = curve({ { 0, 0 }, { 0.8, 0.2 }, { 1, 1 } }),
		spread = 30,
		drag = 0.8,
		rot = true,
		spin = 80,
		light = 0.9,
	})
	Kit.emit(c, { -- snow glints
		sheet = "snow",
		rate = 8,
		life = { 0.8, 1.2 },
		speed = { 2, 5 },
		size = num(1.3 * s, 0.4 * s),
		colour = seq(W),
		spread = 40,
		light = 1,
		rot = true,
		spin = 60,
	})
	Kit.emit(c, { -- cold mist
		sheet = "mist",
		rate = 5,
		life = { 0.9, 1.4 },
		speed = { 2, 4 },
		size = num(1.2 * s, 3.2 * s),
		colour = seq(ice, deep),
		fade = curve({ { 0, 0.65 }, { 1, 1 } }),
		light = 0.4,
		rot = true,
		spin = 20,
	})
	Kit.emit(c, {
		sheet = "flare",
		rate = 12,
		life = { 0.4, 0.8 },
		speed = { 4, 9 },
		size = num(0.5 * s, 0),
		colour = seq(W, ice),
		spread = 35,
		light = 1,
	})
end

-- Lightning (Epic): crackling bolts that jump between the exhausts and the road, a blue-white core, flickering light.
function Cool.lightning(c: Kit.Ctx)
	local s, k = c.scale, c.k
	local blue, white = k[1], k[2] or W
	Kit.core(c, seq(white, Kit.hot(blue, 0.5), blue), 0.4 * s)
	Kit.ribbon(c, { life = 0.28, colour = seq(white, blue), width = curve({ { 0, 1 }, { 1, 0 } }), light = 1 })
	-- bolts: three beams from the exhaust to points on the road, redrawn at random several times a second
	local ends: { Attachment } = {}
	local bolts: { Beam } = {}
	local defs = {
		{ sheet = "beam_lightning", w0 = 1.0, w1 = 0.7, col = seq(white, white, Kit.hot(blue, 0.3)) },
		{ sheet = "beam_arc", w0 = 0.9, w1 = 0.5, col = seq(Kit.hot(blue, 0.6), blue) },
		{ sheet = "beam_lightning", w0 = 0.7, w1 = 0.4, col = seq(Kit.hot(blue, 0.7), blue) },
	}
	for i, d in defs do
		local e = Kit.attach(c, "BoltEnd" .. i, CFrame.new(0, -c.height + 0.15, (4 + i * 1.5) * s))
		table.insert(ends, e)
		table.insert(
			bolts,
			Kit.beam(c, {
				to = e,
				sheet = d.sheet,
				speed = 6,
				colour = d.col,
				fade = curve({ { 0, 0 }, { 0.7, 0.1 }, { 1, 0.5 } }),
				w0 = d.w0 * s,
				w1 = d.w1 * s,
				segments = 14,
				light = 1,
				brightness = 3,
			})
		)
	end
	-- a short arc that jumps across between the two exhausts
	local jump: Beam? = nil
	if c.index == 2 and c.shared.first then
		jump = Kit.beam(c, {
			from = c.shared.first,
			to = c.at,
			sheet = "beam_arc",
			speed = 8,
			colour = seq(Kit.hot(blue, 0.7)),
			fade = curve({ { 0, 0.05 }, { 1, 0.05 } }),
			w0 = 0.7 * s,
			w1 = 0.7 * s,
			segments = 10,
			light = 1,
			brightness = 3,
		})
	end
	if c.index == 1 then
		c.shared.first = c.at
	end
	local home = c.home
	local nextAt = 0
	Kit.motion(c, function(t: number)
		if t < nextAt then
			return
		end
		nextAt = t + (if c.reduce then 0.16 else 0.05) + Kit.hash(t, c.index) * 0.07
		for i, e in ends do
			local r1, r2, r3, r4 = Kit.hash(t, i), Kit.hash(t, i + 7), Kit.hash(t, i + 13), Kit.hash(t, i + 29)
			e.CFrame = home * CFrame.new((r1 - 0.5) * 5 * s, -c.height + 0.15, (3 + r2 * 7) * s)
			local bolt = bolts[i]
			bolt.CurveSize0 = (r3 - 0.5) * 7
			bolt.CurveSize1 = (r4 - 0.5) * 7
			bolt.Enabled = r4 > 0.18
		end
		if jump then
			jump.CurveSize0 = (Kit.hash(t, 3) - 0.5) * 3
			jump.CurveSize1 = (Kit.hash(t, 5) - 0.5) * 3
			jump.Enabled = Kit.hash(t, 11) > 0.25
		end
	end)
	Kit.emit(c, { -- crackle flashes
		sheet = "bolt",
		rate = 9,
		life = { 0.2, 0.35 },
		speed = { 1, 3 },
		size = num(3.2 * s, 2.4 * s),
		colour = seq(white, blue),
		fade = curve({ { 0, 0.1 }, { 1, 1 } }),
		spread = 80,
		light = 1,
		rot = true,
	})
	Kit.emit(c, {
		sheet = "chain",
		rate = 5,
		life = { 0.25, 0.4 },
		speed = { 2, 5 },
		size = num(2.6 * s),
		colour = seq(Kit.hot(blue, 0.5)),
		fade = curve({ { 0, 0.2 }, { 1, 1 } }),
		spread = 60,
		light = 1,
		rot = true,
	})
	Kit.emit(c, { -- sparks
		sheet = "flare",
		rate = 18,
		life = { 0.2, 0.45 },
		speed = { 6, 13 },
		size = num(0.55 * s, 0),
		colour = seq(white, blue),
		spread = 70,
		light = 1,
		squash = num(0.5),
	})
	Kit.glow(c, Kit.hot(blue, 0.2), 8 * s, 10 * s, 0.55, 11)
	Kit.sound(c, "crackle", 0.14, 1)
end

-- Aurora Veil (Epic): wavy curtains of green and pink light standing up behind the car.
function Cool.aurora(c: Kit.Ctx)
	local s, k = c.scale, c.k
	local green, pink = k[1], k[2] or k[1]
	local teal = k[3] or green
	Kit.core(c, seq(W, Kit.hot(green, 0.5)), 0.22 * s)
	for i = 1, 2 do
		local dx = (i - 1.5) * 1.1 * s
		local top = Kit.attach(c, "CurtainTop" .. i, CFrame.new(dx, 1.9 * s, 0))
		local bot = Kit.attach(c, "CurtainBot" .. i, CFrame.new(dx, -c.height + 0.2, 0))
		local from = if i == 1 then green else pink
		local to = if i == 1 then pink else green
		Kit.ribbon(c, {
			a = top,
			b = bot,
			life = 1.2,
			colour = seq(from, pink, teal, to),
			fade = curve({ { 0, 0.05 }, { 0.5, 0.3 }, { 1, 1 } }),
			faceCamera = true,
			sheet = "aurora",
			light = 1,
			brightness = 2.2,
		})
		local home = c.home
		Kit.motion(c, function(t: number)
			local a = t * 2.6 + i * 1.7
			top.CFrame = home
				* CFrame.new(dx + math.sin(a) * 0.7 * s * c.amp, 1.9 * s + math.sin(a * 0.7) * 0.3 * s * c.amp, 0)
		end)
	end
	Kit.emit(c, {
		sheet = "stars",
		rate = 7,
		life = { 0.8, 1.4 },
		speed = { 2, 5 },
		size = num(1.4 * s, 0.2 * s),
		colour = seq(Kit.hot(green, 0.6), Kit.hot(pink, 0.6)),
		spread = 40,
		accel = Vector3.new(0, 2, 0),
		light = 1,
		random = true,
		mode = "Random",
	})
	Kit.emit(c, {
		sheet = "flare",
		rate = 9,
		life = { 0.5, 1.0 },
		speed = { 1, 4 },
		size = num(0.6 * s, 0),
		colour = seq(green, pink),
		spread = 60,
		accel = Vector3.new(0, 3, 0),
		light = 1,
	})
	Kit.glow(c, green:Lerp(pink, 0.4), 8 * s, 10 * s, 0.45, 1.2)
	Kit.sound(c, "whoosh", 0.12, 1.15)
end

-- Retro Grid (Epic): a glowing synthwave grid lying on the road behind the car; left magenta, right cyan.
function Cool.retro(c: Kit.Ctx)
	local s, k = c.scale, c.k
	local colour = if c.side >= 0 then k[2] or k[1] else k[1]
	local sun = k[3] or colour
	Kit.core(c, seq(W, Kit.hot(colour, 0.5), colour), 0.35 * s)
	local left = Kit.attach(c, "GridL", CFrame.new(-1.3 * s, -c.height + 0.12, 0))
	local right = Kit.attach(c, "GridR", CFrame.new(1.3 * s, -c.height + 0.12, 0))
	Kit.ribbon(c, {
		a = left,
		b = right,
		life = 1.1,
		colour = seq(Kit.hot(colour, 0.25), colour, sun),
		fade = curve({ { 0, 0.05 }, { 0.6, 0.35 }, { 1, 1 } }),
		faceCamera = false,
		sheet = "grid",
		wrap = true,
		textureLength = 2.6 * s,
		light = 1,
		brightness = 2,
		width = num(1, 1.0),
	})
	Kit.beam(c, {
		to = c.tip,
		colour = seq(Kit.hot(colour, 0.4), colour),
		fade = curve({ { 0, 0.1 }, { 1, 1 } }),
		w0 = 0.45 * s,
		w1 = 0.1 * s,
		light = 1,
	})
	Kit.emit(c, {
		sheet = "flare",
		rate = 14,
		life = { 0.5, 0.9 },
		speed = { 3, 8 },
		size = num(0.7 * s, 0),
		colour = seq(W, colour),
		spread = 35,
		light = 1,
	})
	Kit.emit(c, {
		sheet = "stars",
		rate = 5,
		life = { 0.7, 1.1 },
		speed = { 2, 5 },
		size = num(1.2 * s, 0.2 * s),
		colour = seq(W, sun),
		spread = 40,
		light = 1,
		random = true,
		mode = "Random",
	})
	Kit.glow(c, colour:Lerp(sun, 0.3), 8 * s, 10 * s, 0.5, 1.5)
	Kit.sound(c, "whoosh", 0.12, 0.9)
end

return Cool
