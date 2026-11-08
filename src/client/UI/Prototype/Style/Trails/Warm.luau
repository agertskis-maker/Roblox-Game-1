--!strict
-- Trails.Warm (Round 8, T-07): Flame Rush, Comet Tail, Golden Glory, Confetti Party, Money Rain, Pixel Blast. One function per trail,
-- called once for each exhaust point with the context Kit.Ctx. Layers are listed by tier (T-06): every trail has the core and the
-- ribbon; Uncommon adds light particles; Rare adds sparks and a second particle layer; Epic adds an animated texture, the road glow
-- and a soft loop; Legendary adds flares, a pulse and a third layer; Robux and VIP trails are the flashiest.
local Kit = require(script.Parent.Kit)

local Warm = {}

local W = Color3.new(1, 1, 1)
local seq, num, curve = Kit.seq, Kit.num, Kit.curve

function Warm.flame(c: Kit.Ctx)
	local s, k, t = c.scale, c.k, c.tier
	local gold, red = k[1], k[2] or k[1]
	Kit.core(c, seq(W, Kit.hot(gold, 0.5), gold), 0.55 * s)
	Kit.ribbon(
		c,
		{ life = 0.35, colour = seq(gold, red), light = 1, width = curve({ { 0, 1 }, { 0.5, 0.75 }, { 1, 0 } }) }
	)
	-- the body: a wide flame sheet with a scrolling flame texture
	Kit.beam(c, {
		to = c.tip2,
		sheet = "beam_fire",
		speed = 3,
		colour = seq(Kit.hot(gold, 0.2), gold, red),
		fade = curve({ { 0, 0.4 }, { 0.65, 0.4 }, { 1, 1 } }),
		w0 = 0.66 * s,
		w1 = 1.80 * s,
		light = 0.9,
		segments = 12,
	})
	Kit.emit(c, {
		sheet = "smoke_puff",
		rate = 14,
		life = { 0.3, 0.45 },
		speed = { 10, 14 },
		size = curve({ { 0, 1.0 * s }, { 0.4, 2.0 * s }, { 1, 2.6 * s } }),
		rot = true,
		spin = 60,
		colour = seq(W, gold, red),
		fade = curve({ { 0, 0.1 }, { 0.7, 0.45 }, { 1, 1 } }),
		spread = 4,
		light = 1,
		inherit = 0.2,
	})
	Kit.emit(c, { -- embers fly back and spread
		sheet = "flare",
		tier = 2,
		rate = 22,
		life = { 0.5, 0.9 },
		speed = { 7, 13 },
		size = num(0.55 * s, 0),
		colour = seq(Kit.hot(gold, 0.4), gold, red),
		fade = curve({ { 0, 0 }, { 0.7, 0.2 }, { 1, 1 } }),
		spread = 40,
		accel = Vector3.new(0, 4, 0),
		drag = 0.6,
		light = 1,
		squash = num(0.6),
		inherit = 0.5,
	})
	Kit.emit(c, { -- dark smoke at the end of the flame
		sheet = "smoke_puff",
		tier = 3,
		rate = 5,
		life = { 0.8, 1.2 },
		speed = { 3, 5 },
		size = num(1.2 * s, 3.2 * s),
		colour = seq(Color3.fromRGB(90, 70, 70)),
		fade = curve({ { 0, 0.6 }, { 1, 1 } }),
		accel = Vector3.new(0, 3, 0),
		light = 0,
		rot = true,
		spin = 40,
	})
	Kit.emit(c, { -- sparks with a long squash
		sheet = "stars",
		tier = 3,
		rate = 9,
		life = { 0.4, 0.8 },
		speed = { 10, 18 },
		size = num(0.5 * s, 0.05),
		colour = seq(W, gold),
		spread = 25,
		light = 1,
		random = true,
		mode = "Random",
	})
	Kit.glow(c, Color3.fromRGB(255, 130, 40), 7 * s, 10 * s, 0.5, 6)
	Kit.sound(c, "whoosh", 0.16, 0.8)
	if t >= 5 then
		Kit.emit(c, {
			sheet = "backfire",
			rate = 4,
			life = { 0.3, 0.5 },
			speed = { 4, 8 },
			size = num(2.2 * s, 3.6 * s),
			colour = seq(gold, red),
			light = 1,
		})
	end
end

function Warm.comet(c: Kit.Ctx)
	local s, k, t = c.scale, c.k, c.tier
	local light, deep = k[1], k[2] or k[1]
	-- the hot head at the exhaust
	Kit.emit(c, {
		sheet = "flare",
		rate = 5,
		life = { 0.25, 0.35 },
		speed = { 0.5, 1 },
		size = curve({ { 0, 1.8 * s }, { 0.5, 2.6 * s }, { 1, 1.2 * s } }),
		colour = seq(W, light),
		fade = curve({ { 0, 0.1 }, { 1, 1 } }),
		light = 1,
		locked = true,
	})
	Kit.core(c, seq(W, Kit.hot(light, 0.4), deep), 0.7 * s)
	Kit.beam(c, {
		to = c.tip2,
		sheet = "beam_energy",
		speed = 4,
		colour = seq(Kit.hot(light, 0.3), light, deep),
		fade = curve({ { 0, 0.4 }, { 0.5, 0.35 }, { 1, 1 } }),
		w0 = 0.77 * s,
		w1 = 0.18 * s,
		segments = 14,
	})
	Kit.ribbon(c, {
		life = 1.1,
		colour = seq(W, light, deep),
		light = 1,
		fade = curve({ { 0, 0.3 }, { 0.6, 0.65 }, { 1, 1 } }),
		width = curve({ { 0, 0.5 }, { 1, 0 } }),
	})
	Kit.emit(c, { -- stars shed along the tail
		sheet = "stars",
		tier = 2,
		rate = 12,
		life = { 0.8, 1.3 },
		speed = { 3, 8 },
		size = num(1.2 * s, 0.1 * s),
		colour = seq(W, light),
		spread = 20,
		light = 1,
		drag = 1.2,
		random = true,
		mode = "Random",
	})
	Kit.emit(c, {
		sheet = "flare",
		tier = 3,
		rate = 14,
		life = { 0.5, 0.9 },
		speed = { 6, 11 },
		size = num(0.5 * s, 0),
		colour = seq(light),
		spread = 25,
		squash = num(0.8),
		light = 1,
		inherit = 0.6,
	})
	Kit.glow(c, light, 6 * s, 11 * s, 0.5, 3)
	Kit.sound(c, "shimmer", 0.12, 1.1)
	if t >= 5 then
		Kit.emit(c, {
			sheet = "flare",
			rate = 5,
			life = { 0.6, 1.0 },
			speed = { 1, 3 },
			size = num(1.8 * s, 0),
			colour = seq(W),
			spread = 70,
			light = 1,
			rot = true,
		})
	end
end

function Warm.gold(c: Kit.Ctx)
	local s, k, t = c.scale, c.k, c.tier
	local gold, pale = k[1], k[2] or k[1]
	Kit.core(c, seq(W, pale, gold), 0.5 * s)
	Kit.ribbon(c, {
		life = 0.55,
		colour = seq(pale, gold),
		fade = curve({ { 0, 0.05 }, { 0.6, 0.3 }, { 1, 1 } }),
		width = curve({ { 0, 1 }, { 1, 0 } }),
	})
	Kit.beam(c, {
		to = c.tip2,
		sheet = "beam_energy",
		speed = 2.5,
		colour = seq(pale, gold, gold),
		fade = curve({ { 0, 0.4 }, { 0.6, 0.4 }, { 1, 1 } }),
		w0 = 0.55 * s,
		w1 = 1.08 * s,
		segments = 12,
	})
	Kit.emit(c, { -- gold sparks
		sheet = "flare",
		rate = 16,
		life = { 0.5, 0.9 },
		speed = { 6, 11 },
		size = num(0.6 * s, 0),
		colour = seq(pale, gold),
		spread = 35,
		accel = Vector3.new(0, -5, 0),
		light = 1,
		inherit = 0.5,
	})
	Kit.emit(c, { -- glitter
		sheet = "stars",
		tier = 3,
		rate = 8,
		life = { 0.7, 1.2 },
		speed = { 2, 6 },
		size = num(1.4 * s, 0.2 * s),
		colour = seq(pale, gold),
		spread = 30,
		light = 1,
		random = true,
		mode = "Random",
	})
	Kit.emit(c, { -- coins
		sheet = "coin",
		mode = "Loop",
		fps = 24,
		tier = 5,
		rate = 4,
		life = { 0.8, 1.2 },
		speed = { 4, 8 },
		size = num(0.75 * s),
		colour = seq(W),
		fade = curve({ { 0, 0 }, { 0.8, 0.1 }, { 1, 1 } }),
		spread = 30,
		accel = Vector3.new(0, -12, 0),
		light = 0.3,
		random = true,
	})
	Kit.glow(c, gold, 7 * s, 10 * s, 0.5, 2)
	Kit.sound(c, "shimmer", 0.14, 1)
	if t >= 5 then
		Kit.emit(c, {
			sheet = "flare",
			rate = 4,
			life = { 0.5, 0.8 },
			speed = { 0.5, 1.5 },
			size = num(2.0 * s, 0),
			colour = seq(pale),
			spread = 60,
			light = 1,
			rot = true,
		})
	end
end

function Warm.confetti(c: Kit.Ctx)
	local s, k = c.scale, c.k
	Kit.core(c, seq(W, k[1]), 0.4 * s)
	Kit.ribbon(c, { life = 0.5, colour = seq(k[1], k[2] or k[1], k[3] or k[1]), width = num(0.5, 0.1) })
	for i, colour in k do
		Kit.emit(c, {
			sheet = "flutter",
			mode = "Loop",
			fps = 22,
			rate = 7,
			life = { 0.9, 1.5 },
			speed = { 4, 9 },
			size = num(0.55 * s),
			colour = seq(colour),
			fade = curve({ { 0, 0 }, { 0.8, 0.05 }, { 1, 1 } }),
			spread = 50,
			accel = Vector3.new(0, -9, 0),
			drag = 0.4,
			rot = true,
			spin = 280,
			light = 0.35,
			random = true,
			brightness = 1.2,
		})
		if i >= 5 then
			break
		end
	end
	Kit.emit(c, {
		sheet = "flare",
		tier = 2,
		rate = 10,
		life = { 0.4, 0.7 },
		speed = { 3, 8 },
		size = num(0.7 * s, 0),
		colour = seq(W, k[2] or k[1]),
		spread = 40,
		light = 1,
	})
	Kit.emit(c, {
		sheet = "stars",
		tier = 3,
		rate = 6,
		life = { 0.6, 1.0 },
		speed = { 3, 7 },
		size = num(1.1 * s, 0),
		colour = seq(W, k[3] or k[1]),
		spread = 50,
		light = 1,
		random = true,
		mode = "Random",
	})
	Kit.glow(c, k[1]:Lerp(k[2] or k[1], 0.5), 7 * s, 10 * s, 0.45, 2.5)
	Kit.sound(c, "shimmer", 0.12, 1.2)
end

function Warm.money(c: Kit.Ctx)
	local s, k = c.scale, c.k
	local green, gold = k[1], k[2] or k[1]
	Kit.core(c, seq(W, Kit.hot(green, 0.4), green), 0.4 * s)
	Kit.ribbon(c, { life = 0.45, colour = seq(Kit.hot(green, 0.3), green), width = num(0.7, 0.1) })
	Kit.emit(c, { -- bills flutter out and tumble
		sheet = "bill",
		mode = "Loop",
		fps = 20,
		rate = 8,
		life = { 1.0, 1.6 },
		speed = { 4, 9 },
		size = num(1.0 * s),
		colour = seq(W),
		fade = curve({ { 0, 0 }, { 0.85, 0.05 }, { 1, 1 } }),
		spread = 45,
		accel = Vector3.new(0, -7, 0),
		drag = 0.5,
		rot = true,
		spin = 140,
		light = 0.1,
		random = true,
	})
	Kit.emit(c, { -- coins
		sheet = "coin",
		mode = "Loop",
		fps = 26,
		rate = 5,
		life = { 0.9, 1.4 },
		speed = { 4, 8 },
		size = num(0.8 * s),
		colour = seq(W),
		fade = curve({ { 0, 0 }, { 0.85, 0.05 }, { 1, 1 } }),
		spread = 40,
		accel = Vector3.new(0, -13, 0),
		light = 0.25,
		random = true,
	})
	Kit.emit(c, {
		sheet = "flare",
		tier = 3,
		rate = 9,
		life = { 0.4, 0.8 },
		speed = { 3, 8 },
		size = num(0.7 * s, 0),
		colour = seq(Kit.hot(gold, 0.5), gold),
		spread = 40,
		light = 1,
	})
	Kit.glow(c, green:Lerp(gold, 0.35), 7 * s, 10 * s, 0.45, 1.5)
	Kit.sound(c, "whoosh", 0.14, 1.0)
end

function Warm.pixel(c: Kit.Ctx)
	local s, k = c.scale, c.k
	Kit.core(c, seq(W, k[1]), 0.35 * s)
	Kit.ribbon(c, {
		life = 0.35,
		colour = seq(k[1], k[2] or k[1]),
		width = num(0.5, 0.5),
		fade = curve({ { 0, 0.1 }, { 1, 0.8 } }),
	})
	for i, colour in k do
		Kit.emit(c, {
			texture = "rbxasset://textures/particles/SquareParticle.png",
			rate = 8,
			life = { 0.4, 0.8 },
			speed = { 5, 9 },
			size = curve({ { 0, 0.55 * s }, { 0.5, 0.55 * s }, { 0.51, 0.32 * s }, { 1, 0.32 * s } }),
			colour = seq(colour),
			fade = curve({ { 0, 0 }, { 0.7, 0.1 }, { 1, 0.7 } }),
			spread = 15,
			light = 1,
			rot = true,
			spin = 90,
			inherit = 0.3,
		})
		if i >= 3 then
			break
		end
	end
	Kit.emit(c, {
		sheet = "flare",
		tier = 2,
		rate = 8,
		life = { 0.3, 0.5 },
		speed = { 2, 5 },
		size = num(0.8 * s, 0),
		colour = seq(W, k[2] or k[1]),
		spread = 30,
		light = 1,
	})
end

return Warm
