--!strict
-- The waterfall system's visuals (Lane 3, build-time), replacing the earlier flat sheets in the
-- same owned container (Lane3_IslandEnvironment.Waterfall). Terrain holds the creek, tarn,
-- ledge basin, plunge pool and lake; these beams and particles carry the moving water:
--   upper falls: a free fall arcing off the lip, layered body, fast and slow strands,
--     highlights and escaping spray ribbons;
--   horsetail: a narrower slide down the rock chute into the same ledge basin;
--   lower falls: three unequal streams split by rock, converging on the plunge pool;
--   creek rapids, an irregular foam ring at each impact, a fading foam current across the lake
--   to the park stream, the park stream's flow, splash, droplets, whitewater, ripples, low and
--   rising mist, grotto drips and fireflies, and a faint mist rainbow.
-- One colour progression per full drop (lip blue, body blue, aerated pale, white at impact).
-- Beams scroll on their own (TextureSpeed); the client scales activity by distance and reduced
-- motion (Home/Island/EnvironmentMotion) using the Base* attributes set here.

local AssetIds = require(script.Parent.AssetIds)
local Cascade = require(script.Parent.Cascade)
local Field = require(script.Parent.Field)
local Layout = require(script.Parent.Parent.Layout)

local Waterfall = {}

local rgb = Color3.fromRGB
local TEX = AssetIds.Textures

-- Palette (Adam's suggestion, tuned by eye)
Waterfall.Palette = {
	Lip = rgb(44, 127, 179),
	Body = rgb(58, 147, 196),
	Aerated = rgb(220, 239, 248),
	Foam = rgb(244, 251, 255),
	FoamShadow = rgb(191, 216, 230),
}
local P = Waterfall.Palette

-- Colour along one full drop, t from 0 (source) to 1 (impact at the lake).
local STOPS: { { any } } = { { 0, P.Lip }, { 0.22, P.Body }, { 0.62, P.Aerated }, { 1, P.Foam } }
local function colourAt(t: number): Color3
	t = math.clamp(t, 0, 1)
	for i = 2, #STOPS do
		if t <= STOPS[i][1] then
			local a, b = STOPS[i - 1], STOPS[i]
			return (a[2] :: Color3):Lerp(b[2] :: Color3, (t - a[1]) / (b[1] - a[1]))
		end
	end
	return P.Foam
end
local function gradient(t0: number, t1: number, lift: number?): ColorSequence
	local keys = {}
	for k = 0, 4 do
		local f = k / 4
		local c = colourAt(t0 + (t1 - t0) * f)
		if lift then
			c = c:Lerp(P.Foam, lift)
		end
		table.insert(keys, ColorSequenceKeypoint.new(f, c))
	end
	return ColorSequence.new(keys)
end
local function fade(a: number, b: number): NumberSequence
	return NumberSequence.new({ NumberSequenceKeypoint.new(0, a), NumberSequenceKeypoint.new(1, b) })
end

local function world(p: Vector2, h: number): Vector3
	return Vector3.new(p.X, h, -p.Y)
end

-- An attachment on the invisible host at a world position, with its X axis along `axis`
-- (beam curves bend along it). A beam that does not face the camera is as wide as the
-- attachments' Y axis (probe, 2026-10-21), so flat ribbons get a horizontal Y axis.
local function attach(host: BasePart, pos: Vector3, axis: Vector3, flat: boolean?): Attachment
	local a = Instance.new("Attachment")
	local x = axis.Unit
	local y
	if flat then
		y = Vector3.new(0, 1, 0):Cross(x).Unit
	elseif math.abs(x.Y) > 0.95 then
		y = Vector3.zAxis
	else
		y = Vector3.yAxis
	end
	a.CFrame = host.CFrame:ToObjectSpace(CFrame.fromMatrix(pos, x, y))
	a.Parent = host
	return a
end

export type BeamSpec = {
	name: string,
	texture: string,
	width0: number,
	width1: number,
	speed: number,
	length: number,
	colour: ColorSequence,
	transparency: NumberSequence,
	curve0: number?,
	curve1: number?,
	faceCamera: boolean?,
	light: number?,
	z: number?,
}

local function beam(parent: Instance, a0: Attachment, a1: Attachment, s: BeamSpec): Beam
	local b = Instance.new("Beam")
	b.Name = s.name
	b.Attachment0 = a0
	b.Attachment1 = a1
	b.Texture = s.texture
	b.TextureMode = Enum.TextureMode.Wrap
	b.TextureLength = s.length
	b.TextureSpeed = s.speed
	b.Width0 = s.width0
	b.Width1 = s.width1
	b.CurveSize0 = s.curve0 or 0
	b.CurveSize1 = s.curve1 or 0
	b.FaceCamera = s.faceCamera ~= false
	b.Color = s.colour
	b.Transparency = s.transparency
	b.LightEmission = s.light or 0.12
	b.LightInfluence = 1
	b.Segments = 24
	b.ZOffset = s.z or 0
	b:SetAttribute("BaseSpeed", s.speed)
	b.Parent = parent
	return b
end

-- A layered free fall between two points: body, fast and slow strands, highlights.
local FALL_LAYERS: { { any } } = {
	-- name, texture, width0, width1, speed, repeat length, transparency top, bottom, whiten, arc
	{ "Body", TEX.WaterBody, 1.0, 1.35, 1.6, 10, 0.1, 0.28, 0, 0 },
	{ "FastStrands", TEX.WaterStrandsFast, 1.1, 1.5, 3.1, 8, 0.22, 0.12, 0.12, 0.8 },
	{ "SlowStrands", TEX.WaterStrandsSlow, 1.25, 1.7, 1.15, 15, 0.42, 0.3, 0.05, -0.6 },
	{ "Highlights", TEX.WaterHighlights, 0.75, 1.1, 3.7, 6, 0.38, 0.3, 0.5, 0.3 },
}

local function fall(
	folder: Instance,
	host: BasePart,
	name: string,
	top: Vector3,
	bottom: Vector3,
	out: Vector3,
	t0: number,
	t1: number,
	scale: number,
	layers: number,
	arc: number
)
	local rng = Random.new(#name * 131 + math.floor(math.abs(top.X) * 10))
	for k = 1, math.min(layers, #FALL_LAYERS) do
		local sp = FALL_LAYERS[k]
		local dx = (rng:NextNumber() - 0.5) * 0.9 * scale
		local a0 = attach(host, top + Vector3.new(dx, 0, 0), out)
		local a1 = attach(host, bottom + Vector3.new(dx * 1.6, 0, 0), Vector3.new(0, -1, 0))
		beam(folder, a0, a1, {
			name = name .. sp[1],
			texture = sp[2],
			width0 = sp[3] * scale * (0.92 + rng:NextNumber() * 0.16),
			width1 = sp[4] * scale * (0.92 + rng:NextNumber() * 0.16),
			speed = sp[5] * (0.9 + rng:NextNumber() * 0.2),
			length = sp[6] * (0.85 + rng:NextNumber() * 0.3),
			colour = gradient(t0, t1, sp[9]),
			transparency = fade(sp[7], sp[8]),
			curve0 = arc + sp[10],
			curve1 = (bottom - top).Magnitude * 0.38,
			light = if k == 4 then 0.45 else 0.12,
			z = k * 0.02,
		})
	end
end

-- Beams along a polyline, the colour progressing from t0 to t1 over the whole chain.
local function chain(
	folder: Instance,
	host: BasePart,
	name: string,
	points: { Vector3 },
	t0: number,
	t1: number,
	spec: BeamSpec,
	flat: boolean
)
	local n = #points
	for i = 1, n - 1 do
		local dir = points[i + 1] - points[i]
		local a0 = attach(host, points[i], dir, flat)
		local a1 = attach(host, points[i + 1], dir, flat)
		local ta = t0 + (t1 - t0) * (i - 1) / (n - 1)
		local tb = t0 + (t1 - t0) * i / (n - 1)
		local s = table.clone(spec)
		s.name = string.format("%s%02d", name, i)
		if t1 > t0 then
			s.colour = gradient(ta, tb)
		end
		s.faceCamera = not flat
		beam(folder, a0, a1, s)
	end
end

local function emitter(
	host: BasePart,
	name: string,
	pos: Vector3,
	dir: Vector3,
	props: { [string]: any }
): ParticleEmitter
	local a = Instance.new("Attachment")
	a.Name = name
	-- emitters shoot along the attachment's Y axis ("Top"): turn it to point along dir
	a.CFrame = host.CFrame:ToObjectSpace(CFrame.lookAt(pos, pos + dir) * CFrame.Angles(-math.pi / 2, 0, 0))
	a.Parent = host
	local e = Instance.new("ParticleEmitter")
	e.Name = name
	for k, v in props do
		(e :: any)[k] = v
	end
	e:SetAttribute("BaseRate", e.Rate)
	e.Parent = a
	return e
end

local function impact(host: BasePart, name: string, at: Vector3, s: number)
	local up = Vector3.new(0, 1, 0.0001)
	emitter(host, name .. "Splash", at + Vector3.new(0, 0.4, 0), up, {
		Texture = TEX.Droplet,
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.7 * s), NumberSequenceKeypoint.new(1, 0.25 * s) }),
		Transparency = fade(0.1, 0.8),
		Lifetime = NumberRange.new(0.6, 1.1),
		Rate = 42 * s,
		Speed = NumberRange.new(13 * s, 24 * s),
		SpreadAngle = Vector2.new(38, 38),
		Acceleration = Vector3.new(0, -48, 0),
		Drag = 0.4,
		Color = ColorSequence.new(P.Foam),
		LightEmission = 0.25,
	})
	emitter(host, name .. "Droplets", at + Vector3.new(0, 0.6, 0), up, {
		Texture = TEX.Droplet,
		Size = NumberSequence.new(0.22 * s),
		Transparency = fade(0.15, 0.9),
		Lifetime = NumberRange.new(0.45, 0.9),
		Rate = 60 * s,
		Speed = NumberRange.new(7 * s, 14 * s),
		SpreadAngle = Vector2.new(60, 60),
		Acceleration = Vector3.new(0, -40, 0),
		Color = ColorSequence.new(P.Aerated),
	})
	emitter(host, name .. "Churn", at + Vector3.new(0, 0.2, 0), up, {
		Texture = TEX.FoamPatch,
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 3 * s), NumberSequenceKeypoint.new(1, 6.5 * s) }),
		Transparency = fade(0.15, 1),
		Lifetime = NumberRange.new(1, 1.7),
		Rate = 14 * s,
		Speed = NumberRange.new(1, 3),
		SpreadAngle = Vector2.new(70, 70),
		RotSpeed = NumberRange.new(-40, 40),
		Rotation = NumberRange.new(0, 360),
		Color = ColorSequence.new(P.Foam, P.FoamShadow),
	})
	emitter(host, name .. "Whitewater", at + Vector3.new(0, 0.3, 0), up, {
		Texture = TEX.FoamPatch,
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.4 * s), NumberSequenceKeypoint.new(1, 3.4 * s) }),
		Transparency = fade(0.2, 1),
		Lifetime = NumberRange.new(0.8, 1.3),
		Rate = 20 * s,
		Speed = NumberRange.new(4 * s, 9 * s),
		SpreadAngle = Vector2.new(75, 75),
		Acceleration = Vector3.new(0, -14, 0),
		Rotation = NumberRange.new(0, 360),
		Color = ColorSequence.new(P.Foam),
	})
	emitter(host, name .. "Ripples", at + Vector3.new(0, 0.05, 0), up, {
		Texture = TEX.Ripple,
		Orientation = Enum.ParticleOrientation.VelocityPerpendicular,
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 2 * s), NumberSequenceKeypoint.new(1, 15 * s) }),
		Transparency = fade(0.45, 1),
		Lifetime = NumberRange.new(2.4, 3.4),
		Rate = 2.6,
		Speed = NumberRange.new(0.01, 0.02),
		Color = ColorSequence.new(P.Foam),
	})
	emitter(host, name .. "LowMist", at + Vector3.new(0, 1.2, 0), up, {
		Texture = TEX.Mist,
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 8 * s), NumberSequenceKeypoint.new(1, 22 * s) }),
		Transparency = fade(0.74, 1),
		Lifetime = NumberRange.new(4, 6),
		Rate = 4 * s,
		Speed = NumberRange.new(2.5, 5.5),
		SpreadAngle = Vector2.new(82, 82),
		Acceleration = Vector3.new(0, -0.6, 0),
		Drag = 0.5,
		Color = ColorSequence.new(rgb(236, 246, 250)),
	})
end

-- An irregular flat foam ring shaped round the landing zone (wider toward the lake).
local function foamRing(folder: Instance, host: BasePart, name: string, centre: Vector2, level: number, size: number)
	local pts: { Vector3 } = {}
	local n = 12
	for k = 0, n do
		local a = (k % n) / n * math.pi * 2
		local r = size * (1 + 0.28 * math.sin(2 * a + 1) + 0.16 * math.sin(5 * a + 0.4))
		local stretch = 1 + 0.45 * math.max(0, math.sin(a))
		table.insert(pts, world(centre + Vector2.new(math.cos(a) * r, math.sin(a) * r * stretch), level + 0.08))
	end
	chain(folder, host, name, pts, 0, 0, {
		name = name,
		texture = TEX.FoamTile,
		width0 = size * 0.55,
		width1 = size * 0.55,
		speed = 0.12,
		length = 7,
		colour = ColorSequence.new(P.Foam),
		transparency = fade(0.22, 0.22),
		light = 0.15,
	}, true)
end

function Waterfall.build(parent: Instance): Model
	local model = Instance.new("Model")
	model.Name = "Waterfall"
	local host = Instance.new("Part")
	host.Name = "WaterHost"
	host.Anchored = true
	host.CanCollide = false
	host.CanQuery = false
	host.CanTouch = false
	host.Transparency = 1
	host.Size = Vector3.one
	host.CFrame = CFrame.new()
	host.Parent = model

	local X = Cascade.X
	local folders: { [string]: Folder } = {}
	for _, name in { "UpperFalls", "Horsetail", "LowerFalls", "Creek", "Foam", "Current", "Rainbow" } do
		local f = Instance.new("Folder")
		f.Name = name
		f.Parent = model
		folders[name] = f
	end

	-- upper falls: off the projecting lip, arcing out, into the ledge basin
	local lipTop = Vector3.new(X, Cascade.LipHeight + 0.5, -Cascade.LipEdgeY)
	local basin = Cascade.Ledge.basin
	local ledgeLanding = world(basin + Vector2.new(-1.5, 1.2), Cascade.Ledge.water)
	local outward = Vector3.new(0, -0.22, -1)
	local upperT1 = (Cascade.LipHeight - Cascade.Ledge.water) / Cascade.LipHeight * 0.95
	fall(folders.UpperFalls, host, "Upper", lipTop, ledgeLanding, outward, 0, upperT1, 9.2, 4, 7)
	-- stray spray ribbons escaping the edges, unevenly spaced
	local strays = { { -4.4, 9, 0.55 }, { 3.1, 7.5, 0.62 }, { 5.6, 10.5, 0.7 } }
	for k, spec in strays do
		local a0 = attach(host, lipTop + Vector3.new(spec[1], -0.8, 0), Vector3.new(spec[1] * 0.08, -0.3, -1))
		local a1 = attach(host, ledgeLanding + Vector3.new(spec[1] * 1.7, 3, -1.5), Vector3.new(0, -1, 0))
		beam(folders.UpperFalls, a0, a1, {
			name = "UpperSpray" .. k,
			texture = TEX.WaterSpray,
			width0 = 0.9,
			width1 = 2.6,
			speed = 3.3 + k * 0.35,
			length = 9 + k * 2,
			colour = gradient(0.15, upperT1, 0.35),
			transparency = fade(spec[3], 0.92),
			curve0 = spec[2],
			curve1 = 26,
		})
	end

	-- horsetail: hugs the chute, from the tarn stream into the same ledge basin
	local tail: { Vector3 } = {}
	for _, fp in Cascade.Horsetail do
		table.insert(tail, world(fp.p, fp.h + 0.7))
	end
	local tailLayers: { { any } } = {
		{ "Body", TEX.WaterBody, 3.6, 1.4, 9, 0.15 },
		{ "Fast", TEX.WaterStrandsFast, 3.2, 2.8, 7, 0.28 },
		{ "Highlights", TEX.WaterHighlights, 2.4, 3.4, 6, 0.45 },
	}
	for k, sp in tailLayers do
		chain(folders.Horsetail, host, "Horsetail" .. sp[1], tail, 0.16, 0.62, {
			name = "",
			texture = sp[2],
			width0 = sp[3],
			width1 = sp[3] * 1.15,
			speed = sp[4],
			length = sp[5],
			colour = ColorSequence.new(P.Body),
			transparency = fade(sp[6], sp[6] + 0.08),
			light = if k == 3 then 0.4 else 0.12,
			z = k * 0.02,
		}, false)
	end

	-- lower falls: three unequal streams off the lower lip, converging on the plunge pool
	local pool = Cascade.Pool
	local poolLanding = world(pool.centre + Vector2.new(0, -1.5), Field.LakeLevel + 0.2)
	for k, s in Cascade.LowerStreams do
		local top = Vector3.new(s.x, Cascade.LowerLip.height + 0.35, -(Cascade.LowerLip.y + 0.4))
		local bottom = poolLanding + Vector3.new((s.x - X) * 0.42, 0, 0)
		local layers = if s.width > 5 then 4 else 3
		fall(
			folders.LowerFalls,
			host,
			"Lower" .. k,
			top,
			bottom,
			Vector3.new(0, -0.45, -1),
			0.5,
			1,
			s.width,
			layers,
			2.6 + k * 0.4
		)
	end

	-- creek and side stream: flowing water on the channel, white rapids where it steepens
	local streams: { { any } } = { { "Creek", Cascade.Creek, 0, 0.08 }, { "Side", Cascade.SideStream, 0.06, 0.15 } }
	for _, entry in streams do
		local list = entry[2] :: { Cascade.FlowPoint }
		local pts: { Vector3 } = {}
		for _, fp in list do
			table.insert(pts, world(fp.p, fp.h + 1.45))
		end
		chain(folders.Creek, host, entry[1], pts, entry[3], entry[4], {
			name = "",
			texture = TEX.Current,
			width0 = 6,
			width1 = 6,
			speed = 1.4,
			length = 10,
			colour = ColorSequence.new(P.Body),
			transparency = fade(0.35, 0.35),
			light = 0.1,
		}, true)
		for i = 1, #list - 1 do
			local a, b = list[i], list[i + 1]
			local slope = (a.h - b.h) / (b.p - a.p).Magnitude
			if slope > 0.36 then
				local dir = world(b.p, b.h) - world(a.p, a.h)
				local a0 = attach(host, world(a.p, a.h + 1.6), dir, true)
				local a1 = attach(host, world(b.p, b.h + 1.6), dir, true)
				local tr = math.clamp(0.5 - slope * 0.4, 0.15, 0.5)
				beam(folders.Creek, a0, a1, {
					name = string.format("%sRapids%02d", entry[1], i),
					texture = TEX.WaterStrandsFast,
					width0 = 4.6,
					width1 = 4.6,
					speed = 2.4 + slope * 2,
					length = 7,
					colour = ColorSequence.new(P.Aerated),
					transparency = fade(tr, tr),
					faceCamera = false,
					light = 0.2,
					z = 0.05,
				})
			end
		end
	end

	-- impacts, foam rings, rising mist close to the cliff
	impact(host, "Ledge", ledgeLanding, 0.75)
	impact(host, "Pool", poolLanding, 1)
	foamRing(folders.Foam, host, "LedgeFoam", basin + Vector2.new(-1, 1), Cascade.Ledge.water, 3.6)
	foamRing(folders.Foam, host, "PoolFoam", pool.centre + Vector2.new(0, 0.5), Field.LakeLevel, 6.5)
	emitter(host, "CliffMist", Vector3.new(X, 4, -(Cascade.LowerFaceY + 2)), Vector3.new(0, 1, 0.0001), {
		Texture = TEX.Mist,
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 6), NumberSequenceKeypoint.new(1, 18) }),
		Transparency = fade(0.8, 1),
		Lifetime = NumberRange.new(5, 7),
		Rate = 3,
		Speed = NumberRange.new(2, 4),
		SpreadAngle = Vector2.new(14, 14),
		Color = ColorSequence.new(rgb(240, 248, 252)),
	})

	-- the current: foam carried from the pool across the lake to the park-stream outflow, thinning
	local stream = Layout.Data.park.stream -- [1] is the garden pond, the last point meets the lake
	local mouth = stream[#stream]
	local current = {
		pool.centre + Vector2.new(6, 6),
		Vector2.new(-82, -236),
		Vector2.new(-24, -206),
		Vector2.new(36, -158),
		Vector2.new(80, -112),
		mouth + Vector2.new(0, -6),
	}
	for i = 1, #current - 1 do
		local a, b = current[i], current[i + 1]
		local dir = world(b, 0) - world(a, 0)
		local a0 = attach(host, world(a, Field.LakeLevel + 0.06), dir, true)
		local a1 = attach(host, world(b, Field.LakeLevel + 0.06), dir, true)
		local f0, f1 = (i - 1) / (#current - 1), i / (#current - 1)
		beam(folders.Current, a0, a1, {
			name = string.format("Current%02d", i),
			texture = TEX.Current,
			width0 = 13 - 8 * f0,
			width1 = 13 - 8 * f1,
			speed = 0.75 - 0.35 * f0,
			length = 16,
			colour = ColorSequence.new(P.Foam),
			transparency = fade(0.45 + 0.5 * f0, 0.45 + 0.5 * f1),
			faceCamera = false,
			light = 0.1,
		})
	end
	-- the park stream flows away from the lake, toward its garden pond
	local flowPts: { Vector3 } = {}
	for i = #stream, 1, -8 do
		table.insert(flowPts, world(stream[i], Field.LakeLevel + 0.08))
	end
	table.insert(flowPts, world(stream[1], Field.LakeLevel + 0.08))
	chain(folders.Current, host, "StreamFlow", flowPts, 0, 0, {
		name = "",
		texture = TEX.Current,
		width0 = 7,
		width1 = 7,
		speed = 0.55,
		length = 12,
		colour = ColorSequence.new(P.Foam),
		transparency = fade(0.7, 0.7),
		light = 0.05,
	}, true)

	-- grotto: slow drips and a few fireflies in the shade behind the lower falls
	local grotto = Vector3.new(X + 10, 15, -(Cascade.LowerFaceY - 3.5))
	emitter(host, "GrottoDrips", grotto, Vector3.new(0, -1, 0.0001), {
		Texture = TEX.Droplet,
		Size = NumberSequence.new(0.18),
		Transparency = fade(0.2, 0.6),
		Lifetime = NumberRange.new(0.9, 1.2),
		Rate = 1.6,
		Speed = NumberRange.new(0, 0.2),
		Acceleration = Vector3.new(0, -32, 0),
		Color = ColorSequence.new(P.Aerated),
	})
	emitter(host, "GrottoFireflies", grotto + Vector3.new(0, -7, 0), Vector3.new(0, 1, 0.0001), {
		Texture = TEX.Glow,
		Size = NumberSequence.new(0.35),
		Transparency = fade(0.1, 1),
		Lifetime = NumberRange.new(4, 6),
		Rate = 1.2,
		Speed = NumberRange.new(0.3, 0.8),
		SpreadAngle = Vector2.new(180, 180),
		LightEmission = 1,
		Color = ColorSequence.new(rgb(232, 255, 170)),
	})

	-- a faint mist rainbow across the lower falls' spray (the client fades it by viewpoint)
	local left = Vector3.new(X - 17, 4, -(pool.centre.Y + 5))
	local right = Vector3.new(X + 15, 4, -(pool.centre.Y + 5))
	-- curves bend along X (up); the band is as wide as Y, east-west, so it faces the plaza
	local r0 = Instance.new("Attachment")
	r0.CFrame = CFrame.fromMatrix(left, Vector3.yAxis, Vector3.xAxis)
	r0.Parent = host
	local r1 = Instance.new("Attachment")
	r1.CFrame = CFrame.fromMatrix(right, Vector3.yAxis, Vector3.xAxis)
	r1.Parent = host
	local bow = beam(folders.Rainbow, r0, r1, {
		name = "MistRainbow",
		texture = TEX.Rainbow,
		width0 = 3.2,
		width1 = 3.2,
		speed = 0,
		length = 40,
		colour = ColorSequence.new(Color3.new(1, 1, 1)),
		transparency = fade(0.82, 0.82),
		curve0 = 19,
		curve1 = -19,
		faceCamera = false,
		light = 0.6,
	})
	bow:SetAttribute("BaseTransparency", 0.82)
	bow.TextureMode = Enum.TextureMode.Stretch

	model:SetAttribute("Version", "falls-2")
	model:SetAttribute("TotalDrop", Cascade.LipHeight - Field.LakeLevel)
	model.Parent = parent
	return model
end

return Waterfall
