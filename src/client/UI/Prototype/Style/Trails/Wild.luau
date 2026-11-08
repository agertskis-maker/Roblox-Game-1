--!strict
-- Trails.Wild (Round 8, T-07): Galaxy, Rainbow Runway, Toxic Slime, VIP Gradient, Petal Storm, Drift Smoke. See Warm.luau for how a
-- recipe is read.
local Kit = require(script.Parent.Kit)

local Wild = {}

local W = Color3.new(1, 1, 1)
local seq, num, curve = Kit.seq, Kit.num, Kit.curve

-- Galaxy (Legendary): a nebula that swirls out of the exhaust with stars in it.
function Wild.galaxy(c: Kit.Ctx)
	local s, k = c.scale, c.k
	local purple, pink, cyan = k[1], k[2] or k[1], k[3] or k[1]
	Kit.core(c, seq(W, Kit.hot(purple, 0.6), purple), 0.4 * s)
	Kit.ribbon(c, {
		life = 0.8,
		colour = seq(purple, pink, cyan),
		fade = curve({ { 0, 0.15 }, { 0.6, 0.5 }, { 1, 1 } }),
		light = 1,
	})
	Kit.beam(c, {
		to = c.tip2,
		sheet = "beam_energy",
		speed = 2,
		colour = seq(Kit.hot(purple, 0.3), pink, cyan),
		fade = curve({ { 0, 0.2 }, { 0.6, 0.5 }, { 1, 1 } }),
		w0 = 1.2 * s,
		w1 = 3.0 * s,
		segments = 12,
	})
	Kit.emit(c, { -- spiral nebulae
		sheet = "galaxy",
		rate = 2.5,
		life = { 1.4, 2.0 },
		speed = { 3, 5 },
		size = curve({ { 0, 2.8 * s }, { 1, 6 * s } }),
		colour = seq(Kit.hot(purple, 0.3), pink, cyan),
		fade = curve({ { 0, 0.5 }, { 0.5, 0.35 }, { 1, 1 } }),
		light = 1,
		rot = true,
		spin = 30,
	})
	Kit.emit(c, { -- haze
		sheet = "mist",
		rate = 6,
		life = { 0.9, 1.5 },
		speed = { 3, 5 },
		size = num(1.2 * s, 3.4 * s),
		colour = seq(purple, pink),
		fade = curve({ { 0, 0.55 }, { 1, 1 } }),
		light = 1,
		rot = true,
	})
	Kit.emit(c, { -- stars
		sheet = "stars",
		rate = 12,
		life = { 0.8, 1.4 },
		speed = { 2, 6 },
		size = num(1.7 * s, 0.3 * s),
		colour = seq(W, Kit.hot(cyan, 0.5)),
		spread = 30,
		light = 1,
		random = true,
		mode = "Random",
	})
	Kit.emit(c, {
		sheet = "flare",
		rate = 8,
		life = { 0.5, 1.0 },
		speed = { 5, 10 },
		size = num(0.6 * s, 0),
		colour = seq(W, pink),
		spread = 40,
		light = 1,
	})
	Kit.glow(c, purple:Lerp(pink, 0.5), 8 * s, 11 * s, 0.5, 1.5)
	Kit.sound(c, "shimmer", 0.13, 0.9)
	Kit.emit(c, {
		sheet = "flare",
		tier = 5,
		rate = 4,
		life = { 0.6, 1.0 },
		speed = { 0.5, 2 },
		size = num(2.2 * s, 0),
		colour = seq(Kit.hot(pink, 0.5)),
		spread = 60,
		light = 1,
		rot = true,
	})
end

-- Rainbow Runway (Robux): a six-stripe rainbow laid on the road, sparkling.
function Wild.rainbow(c: Kit.Ctx)
	local s, k = c.scale, c.k
	Kit.core(c, seq(W, Kit.hot(k[3] or W, 0.6)), 0.4 * s)
	local count = math.min(#k, 6)
	for i = 1, count do
		local x = (i - (count + 1) / 2) * 0.46 * s
		local left = Kit.attach(c, "RainbowL" .. i, CFrame.new(x - 0.23 * s, -c.height + 0.12 + i * 0.004, 0))
		local right = Kit.attach(c, "RainbowR" .. i, CFrame.new(x + 0.23 * s, -c.height + 0.12 + i * 0.004, 0))
		Kit.ribbon(c, {
			a = left,
			b = right,
			life = 1.3,
			colour = seq(k[i]),
			fade = curve({ { 0, 0.05 }, { 0.7, 0.15 }, { 1, 1 } }),
			faceCamera = false,
			light = 0.9,
			width = num(1, 1),
			brightness = 1.4,
		})
	end
	Kit.beam(c, {
		to = c.tip,
		colour = seq(table.unpack(k)),
		fade = curve({ { 0, 0.2 }, { 1, 1 } }),
		w0 = 0.9 * s,
		w1 = 1.8 * s,
		light = 1,
	})
	Kit.emit(c, {
		sheet = "flare",
		rate = 16,
		life = { 0.5, 1.0 },
		speed = { 3, 8 },
		size = num(0.8 * s, 0),
		colour = seq(table.unpack(k)),
		spread = 45,
		light = 1,
	})
	Kit.emit(c, {
		sheet = "stars",
		rate = 8,
		life = { 0.7, 1.2 },
		speed = { 2, 6 },
		size = num(1.6 * s, 0.2 * s),
		colour = seq(W, k[2] or W),
		spread = 40,
		light = 1,
		random = true,
		mode = "Random",
	})
	Kit.glow(c, k[3] or W, 9 * s, 11 * s, 0.4, 1.2)
	Kit.sound(c, "shimmer", 0.12, 1.25)
end

-- Toxic Slime (Rare): thick glossy goo ribbons, drips and glowing bubbles.
function Wild.slime(c: Kit.Ctx)
	local s, k = c.scale, c.k
	local lime, deep = k[1], k[2] or k[1]
	Kit.core(c, seq(Kit.hot(lime, 0.6), lime), 0.35 * s)
	local top = Kit.attach(c, "SlimeTop", CFrame.new(0, 0.5 * s, 0))
	local bot = Kit.attach(c, "SlimeBot", CFrame.new(0, -0.5 * s, 0))
	Kit.ribbon(c, {
		a = top,
		b = bot,
		life = 0.55,
		colour = seq(lime, deep),
		fade = curve({ { 0, 0.1 }, { 0.7, 0.2 }, { 1, 1 } }),
		width = curve({ { 0, 0.8 }, { 0.3, 1 }, { 1, 0.1 } }),
		light = 0.25,
	})
	Kit.beam(c, {
		to = c.tip,
		colour = seq(lime, deep),
		fade = curve({ { 0, 0.15 }, { 0.7, 0.35 }, { 1, 1 } }),
		w0 = 0.9 * s,
		w1 = 1.6 * s,
		light = 0.35,
	})
	Kit.emit(c, { -- drips
		sheet = "slime",
		rate = 8,
		life = { 0.7, 1.0 },
		speed = { 2, 5 },
		size = num(1.3 * s, 1.1 * s),
		colour = seq(lime, deep),
		fade = curve({ { 0, 0.05 }, { 0.8, 0.1 }, { 1, 1 } }),
		accel = Vector3.new(0, -16, 0),
		spread = 30,
		light = 0.5,
	})
	Kit.emit(c, { -- glowing bubbles
		sheet = "bubble",
		rate = 6,
		life = { 0.6, 1.0 },
		speed = { 2, 4 },
		size = num(0.5 * s, 0.8 * s),
		colour = seq(lime),
		fade = curve({ { 0, 0.3 }, { 1, 1 } }),
		accel = Vector3.new(0, 3, 0),
		spread = 40,
		light = 0.9,
	})
	Kit.emit(c, { -- goo puffs
		sheet = "smoke_puff",
		rate = 4,
		life = { 0.7, 1.1 },
		speed = { 2, 4 },
		size = num(0.9 * s, 2.2 * s),
		colour = seq(lime, deep),
		fade = curve({ { 0, 0.4 }, { 1, 1 } }),
		light = 0.4,
		rot = true,
		spin = 30,
	})
end

-- VIP Gradient (VIP): a gold-to-purple ribbon that slides between its colours, with sparkles and a tiny crown.
function Wild.vip(c: Kit.Ctx)
	local s, k = c.scale, c.k
	local gold, purple = k[1], k[2] or k[1]
	local core = Kit.core(c, seq(W, gold, purple), 0.5 * s)
	local tail = Kit.ribbon(
		c,
		{ life = 0.85, colour = seq(gold, purple), fade = curve({ { 0, 0 }, { 0.6, 0.3 }, { 1, 1 } }), light = 1 }
	)
	local body = Kit.beam(c, {
		to = c.tip2,
		sheet = "beam_strands",
		speed = 3,
		colour = seq(gold, purple),
		fade = curve({ { 0, 0.1 }, { 0.6, 0.4 }, { 1, 1 } }),
		w0 = 1.1 * s,
		w1 = 2.4 * s,
		segments = 14,
	})
	Kit.emit(c, {
		sheet = "flare",
		rate = 16,
		life = { 0.5, 0.9 },
		speed = { 5, 10 },
		size = num(0.65 * s, 0),
		colour = seq(gold, purple),
		spread = 40,
		light = 1,
		inherit = 0.5,
	})
	Kit.emit(c, {
		sheet = "stars",
		rate = 10,
		life = { 0.7, 1.2 },
		speed = { 2, 6 },
		size = num(1.6 * s, 0.2 * s),
		colour = seq(W, gold),
		spread = 40,
		light = 1,
		random = true,
		mode = "Random",
	})
	Kit.emit(c, { -- the tiny crown
		sheet = "crown",
		rate = 0.9,
		life = { 1.2, 1.6 },
		speed = { 1.5, 3 },
		size = curve({ { 0, 0.9 * s }, { 0.2, 1.7 * s }, { 1, 1.4 * s } }),
		colour = seq(W),
		fade = curve({ { 0, 0.1 }, { 0.8, 0.1 }, { 1, 1 } }),
		accel = Vector3.new(0, 3, 0),
		spread = 20,
		light = 0.6,
	})
	Kit.glow(c, gold:Lerp(purple, 0.5), 9 * s, 11 * s, 0.5, 1.6)
	Kit.sound(c, "shimmer", 0.14, 1.0)
	Kit.motion(c, function(t: number)
		-- the gradient slides from gold to purple and back
		local f = (math.sin(t * 2) + 1) / 2
		local a, b = gold:Lerp(purple, f), purple:Lerp(gold, f)
		core.Color = seq(W, a, b)
		tail.Color = seq(a, b)
		body.Color = seq(a, b)
	end)
end

-- Petal Storm (Rare): flower petals swirling out behind the car.
function Wild.petal(c: Kit.Ctx)
	local s, k = c.scale, c.k
	local rose, pale = k[1], k[2] or k[1]
	Kit.core(c, seq(W, pale), 0.3 * s)
	Kit.ribbon(c, {
		life = 0.6,
		colour = seq(pale, rose),
		fade = curve({ { 0, 0.2 }, { 0.6, 0.5 }, { 1, 1 } }),
		width = num(0.8, 0),
		light = 0.8,
	})
	local swirl = Kit.attach(c, "Swirl", CFrame.new(0, 0, 0))
	local home = c.home
	local phase = if c.side >= 0 then 0 else math.pi
	Kit.motion(c, function(t: number)
		local a = t * 4.5 + phase
		swirl.CFrame = home * CFrame.new(math.cos(a) * 0.9 * s * c.amp, math.sin(a) * 0.9 * s * c.amp, 0)
	end)
	Kit.emit(c, {
		from = swirl,
		sheet = "petal",
		mode = "Loop",
		fps = 14,
		rate = 14,
		life = { 1.2, 1.8 },
		speed = { 3, 6 },
		size = num(0.95 * s),
		colour = seq(W),
		fade = curve({ { 0, 0 }, { 0.8, 0.05 }, { 1, 1 } }),
		spread = 18,
		accel = Vector3.new(0, 0.6, 0),
		drag = 0.5,
		rot = true,
		spin = 120,
		light = 0.3,
		random = true,
	})
	Kit.emit(c, {
		from = swirl,
		sheet = "petal",
		tier = 3,
		mode = "Loop",
		fps = 18,
		rate = 8,
		life = { 0.9, 1.4 },
		speed = { 5, 8 },
		size = num(0.6 * s),
		colour = seq(pale),
		fade = curve({ { 0, 0 }, { 0.8, 0.05 }, { 1, 1 } }),
		spread = 28,
		rot = true,
		spin = 200,
		light = 0.4,
		random = true,
	})
	Kit.emit(c, {
		sheet = "flare",
		rate = 9,
		life = { 0.4, 0.8 },
		speed = { 3, 7 },
		size = num(0.6 * s, 0),
		colour = seq(W, rose),
		spread = 40,
		light = 1,
	})
end

-- Drift Smoke (Uncommon): thick coloured tyre smoke from the rear wheels. `c.at` is a wheel here, not an exhaust.
function Wild.drift(c: Kit.Ctx)
	local s, k = c.scale, c.k
	local colour = if c.side >= 0 then k[1] else (k[2] or k[1])
	Kit.ribbon(
		c,
		{ life = 0.5, colour = seq(colour), fade = curve({ { 0, 0.5 }, { 1, 1 } }), width = num(0.5, 0), light = 0.5 }
	)
	Kit.emit(c, { -- the thick cloud
		sheet = "smoke_puff",
		rate = 14,
		life = { 0.8, 1.2 },
		speed = { 4, 7 },
		size = curve({ { 0, 1.8 * s }, { 1, 4.6 * s } }),
		colour = seq(colour:Lerp(W, 0.15), colour),
		fade = curve({ { 0, 0.25 }, { 0.5, 0.35 }, { 1, 1 } }),
		accel = Vector3.new(0, 1.5, 0),
		drag = 2,
		spread = 25,
		light = 0.45,
		rot = true,
		spin = 45,
		inherit = 0.3,
	})
	Kit.emit(c, { -- wispy edge
		sheet = "mist",
		rate = 8,
		life = { 0.9, 1.4 },
		speed = { 3, 6 },
		size = num(2.0 * s, 4.8 * s),
		colour = seq(colour),
		fade = curve({ { 0, 0.55 }, { 1, 1 } }),
		accel = Vector3.new(0, 1, 0),
		drag = 1.5,
		spread = 35,
		light = 0.35,
		rot = true,
		spin = 25,
	})
end

return Wild
