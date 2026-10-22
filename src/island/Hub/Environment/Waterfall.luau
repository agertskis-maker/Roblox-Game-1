--!strict
-- The waterfall system's visuals (Lane 3, build-time), replacing the earlier flat sheets in the
-- same owned container (Lane3_IslandEnvironment.Waterfall). Terrain holds the creek, tarn,
-- ledge basin, spill sheet, landing pool, lake and river; these beams and particles carry the
-- moving water. Task 4 (brief section 7): one main curtain from the second ledge down.
--   upper falls: the feed, a narrower free fall off the lip into the ledge basin;
--   horsetail: a thin slide down the rock chute into the same basin (Cascade.SideFalls);
--   main curtain: 14 wide off the second ledge, a white lip band, three overlapping blue-green
--     body beams at two speeds, fast strands, highlights and hard white edges, fading at both
--     ends into the lip band and the impact;
--   landing pool: splash, droplets, churn, whitewater and ripples across the curtain foot, a
--     foam ring and foam patch, low and rising mist;
--   current: foam carried from the pool to the river's nearer mouth, the river's flow round the
--     loop, and a faint return current from the far mouth toward the outlet gorge;
--   creek rapids, grotto drips and fireflies, and a larger soft mist rainbow.
-- One colour progression per drop (lip white, deep teal, blue-green, aerated pale, white foam).
-- Beams scroll on their own (TextureSpeed); the client scales activity by distance and reduced
-- motion (Home/Island/EnvironmentMotion) using the Base* attributes set here.

local AssetIds = require(script.Parent.AssetIds)
local Cascade = require(script.Parent.Cascade)
local Field = require(script.Parent.Field)
local Layout = require(script.Parent.Parent.Layout)

local Waterfall = {}

local rgb = Color3.fromRGB
local TEX = AssetIds.Textures

-- Palette (Adam's suggestion, tuned by eye). Revision 2 (Adam, 2026-10-21): the main drop is
-- blue-green and see-through in the middle; white belongs at the lip, the broken edges, narrow
-- streaks, turbulence and the impact.
Waterfall.Palette = {
	LipWhite = rgb(226, 244, 246),
	Lip = rgb(52, 140, 150),
	Body = rgb(64, 156, 158),
	Lower = rgb(118, 186, 190),
	Aerated = rgb(220, 239, 248),
	Foam = rgb(244, 251, 255),
	FoamShadow = rgb(191, 216, 230),
	-- Task 4 curtain (research: teal centre about 90, 200, 200; white edges about 230, 250, 255)
	CurtainDeep = rgb(62, 164, 170),
	Curtain = rgb(90, 200, 200),
	Edge = rgb(230, 250, 255),
}
local P = Waterfall.Palette

-- Colour along one full drop, t from 0 (source) to 1 (impact at the lake).
local STOPS: { { any } } =
	{ { 0, P.LipWhite }, { 0.05, P.Lip }, { 0.22, P.Body }, { 0.78, P.Lower }, { 0.94, P.Aerated }, { 1, P.Foam } }
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

-- A transparency `t` along the middle of a beam, fading to fully clear over the first and last
-- `ends` of its length. Shared with the client (Home/Island/EnvironmentMotion rebuilds it from
-- the beam's BaseTransparency and SoftEnds attributes when it fades the rainbow).
function Waterfall.softEnds(t: number, ends: number): NumberSequence
	return NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(ends, t),
		NumberSequenceKeypoint.new(1 - ends, t),
		NumberSequenceKeypoint.new(1, 1),
	})
end
local RAINBOW_SOFT_ENDS = 0.24

-- How far south (world z) the written terrain reaches at (x, y) looking north from the lake,
-- or nil; the lower streams start just in front of it so the rock never hides them.
local function faceZ(x: number, y: number): number?
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { workspace.Terrain }
	local hit = workspace:Raycast(Vector3.new(x, y, 230), Vector3.new(0, 0, 80), params)
	return hit and hit.Position.Z
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
	{ "Body", TEX.WaterBody, 1.0, 1.3, 1.6, 10, 0.42, 0.5, 0, 0 },
	{ "FastStrands", TEX.WaterStrandsFast, 0.8, 1.15, 3.1, 8, 0.3, 0.22, 0.55, 0.8 },
	{ "SlowStrands", TEX.WaterStrandsSlow, 1.1, 1.45, 1.15, 15, 0.5, 0.42, 0, -0.6 },
	{ "Highlights", TEX.WaterHighlights, 0.45, 0.7, 3.7, 6, 0.42, 0.34, 0.85, 0.3 },
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
		-- layers stay on the fall's own line, offset a little each, so gaps between falls stay open
		local dx = (rng:NextNumber() - 0.5) * 0.22 * scale
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
	-- broken white edges: a narrow fast streak down each side of the fall
	for k, side in { -1, 1 } do
		local edge = side * 0.5 * scale
		local a0 = attach(host, top + Vector3.new(edge, 0, 0), out)
		local a1 = attach(host, bottom + Vector3.new(edge * 1.25, 0, 0), Vector3.new(0, -1, 0))
		beam(folder, a0, a1, {
			name = name .. "Edge" .. k,
			texture = TEX.WaterStrandsFast,
			width0 = 0.16 * scale,
			width1 = 0.24 * scale,
			speed = 3.4 + rng:NextNumber() * 0.6,
			length = 7 + rng:NextNumber() * 3,
			colour = gradient(t0, t1, 0.8),
			transparency = fade(0.2, 0.3),
			curve0 = arc,
			curve1 = (bottom - top).Magnitude * 0.38,
			light = 0.35,
			z = 0.1,
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
		Transparency = fade(0.8, 1), -- research: mist never below 0.8
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

-- An attachment for a flat curtain beam (not facing the camera): X along the flow (curves bend
-- along it), Y along world X so the beam's width runs across the cliff face.
local function curtainAttach(host: BasePart, pos: Vector3, flow: Vector3): Attachment
	local a = Instance.new("Attachment")
	local x = flow.Unit
	local across = Vector3.new(1, 0, 0)
	local y = (across - x * across:Dot(x)).Unit
	a.CFrame = host.CFrame:ToObjectSpace(CFrame.fromMatrix(pos, x, y))
	a.Parent = host
	return a
end

-- Transparency along a curtain beam: faded at the top (under the lip band) and at the foot
-- (under the foam), steady between (research: about 10 percent at each end).
local function curtainFade(mid: number, top: number?, foot: number?): NumberSequence
	return NumberSequence.new({
		NumberSequenceKeypoint.new(0, top or math.min(1, mid + 0.35)),
		NumberSequenceKeypoint.new(0.1, mid),
		NumberSequenceKeypoint.new(0.86, mid + 0.04),
		NumberSequenceKeypoint.new(1, foot or math.min(1, mid + 0.4)),
	})
end

local CURTAIN_COLOUR = ColorSequence.new({
	ColorSequenceKeypoint.new(0, P.LipWhite),
	ColorSequenceKeypoint.new(0.07, P.CurtainDeep),
	ColorSequenceKeypoint.new(0.35, P.Curtain),
	ColorSequenceKeypoint.new(0.8, P.Curtain:Lerp(P.Aerated, 0.35)),
	ColorSequenceKeypoint.new(0.93, P.Aerated),
	ColorSequenceKeypoint.new(1, P.Foam),
})
local EDGE_COLOUR = ColorSequence.new(P.Edge, P.Foam)

-- The main curtain's layers: name, texture, offset across (fraction of the half width), width at
-- the lip, width at the foot, scroll speed, repeat length, mid transparency, light, lift to white.
-- Three overlapping body beams at two speeds carry the blue-green centre; strands, highlights
-- and the hard white edges sit over them.
local CURTAIN_LAYERS: { { any } } = {
	{ "BodyWest", TEX.WaterBody, -0.5, 6.5, 8.5, 1.15, 11, 0.32, 0.12, 0 },
	{ "BodyCentre", TEX.WaterBody, 0, 7, 9, 1.55, 10, 0.28, 0.12, 0 },
	{ "BodyEast", TEX.WaterStrandsSlow, 0.5, 6.5, 8.5, 1.25, 14, 0.38, 0.12, 0 },
	{ "StrandsWest", TEX.WaterStrandsFast, -0.3, 5, 6.5, 2.9, 8, 0.42, 0.18, 0.4 },
	{ "StrandsEast", TEX.WaterStrandsFast, 0.34, 5, 6.5, 3.3, 7, 0.44, 0.18, 0.4 },
	{ "Highlights", TEX.WaterHighlights, 0.05, 9, 11, 3.6, 6, 0.45, 0.45, 0.7 },
}

-- One main curtain from `top` (the lip, world) to `bottom` (the landing, world), `width` across.
local function curtain(folder: Instance, host: BasePart, top: Vector3, bottom: Vector3, width: number)
	local half = width / 2
	local spread = 1.12 -- the sheet widens a little as it falls
	local out = Vector3.new(0, -0.45, -1) -- leaving the lip, outward and down
	local down = Vector3.new(0, -1, 0)
	local drop = (top - bottom).Y
	for k, sp in CURTAIN_LAYERS do
		local off = (sp[3] :: number) * half
		local a0 = curtainAttach(host, top + Vector3.new(off, 0, 0), out)
		local a1 = curtainAttach(host, bottom + Vector3.new(off * spread, 0, 0), down)
		local lift = sp[10] :: number
		local b = beam(folder, a0, a1, {
			name = "Curtain" .. sp[1],
			texture = sp[2],
			width0 = sp[4],
			width1 = sp[5],
			speed = sp[6],
			length = sp[7],
			colour = if lift > 0
				then ColorSequence.new(P.Curtain:Lerp(P.Foam, lift), P.Aerated:Lerp(P.Foam, lift))
				else CURTAIN_COLOUR,
			transparency = curtainFade(sp[8]),
			curve0 = 3.4,
			curve1 = drop * 0.36,
			faceCamera = false,
			light = sp[9],
			z = k * 0.02,
		})
		b.Segments = 20
	end
	-- hard white edges where the sheet breaks up (research: 1.5 to 3 studs, 0 to 0.15)
	for k, side in { -1, 1 } do
		local off = side * (half - 0.9)
		local a0 = curtainAttach(host, top + Vector3.new(off, 0, 0), out)
		local a1 = curtainAttach(host, bottom + Vector3.new(off * spread, 0, 0), down)
		beam(folder, a0, a1, {
			name = "CurtainEdge" .. k,
			texture = TEX.WaterStrandsFast,
			width0 = 2.4,
			width1 = 3.2,
			speed = 3.4 + k * 0.3,
			length = 7 + k,
			colour = EDGE_COLOUR,
			transparency = curtainFade(0.1, 0.3, 0.45),
			curve0 = 3.4,
			curve1 = drop * 0.36,
			faceCamera = false,
			light = 0.35,
			z = 0.16,
		})
	end
	-- the white lip band, about 3 studs tall, where the spill sheet tips over the edge
	local lipEnd = top + out.Unit * 3.2
	beam(folder, curtainAttach(host, top + Vector3.new(0, 0.25, 0), out), curtainAttach(host, lipEnd, out), {
		name = "CurtainLip",
		texture = TEX.WaterStrandsFast,
		width0 = width + 0.6,
		width1 = width + 1,
		speed = 2.2,
		length = 6,
		colour = ColorSequence.new(P.LipWhite, P.Edge),
		transparency = fade(0.05, 0.4),
		faceCamera = false,
		light = 0.3,
		z = 0.2,
	})
end

-- Points along a quadratic curve from a to b bowed toward `bow` (plan), n segments.
local function bowed(a: Vector2, bow: Vector2, b: Vector2, n: number): { Vector2 }
	local pts = {}
	for k = 0, n do
		local t = k / n
		table.insert(pts, a * (1 - t) ^ 2 + bow * 2 * t * (1 - t) + b * t * t)
	end
	return pts
end

-- Flat foam ribbons on the lake surface along plan points, widths and transparency eased from
-- the first values to the last.
local function surfaceRibbon(
	folder: Instance,
	host: BasePart,
	name: string,
	pts: { Vector2 },
	w0: number,
	w1: number,
	t0: number,
	t1: number,
	speed: number
)
	for i = 1, #pts - 1 do
		local a, b = pts[i], pts[i + 1]
		local dir = world(b, 0) - world(a, 0)
		local a0 = attach(host, world(a, Field.LakeLevel + 0.06), dir, true)
		local a1 = attach(host, world(b, Field.LakeLevel + 0.06), dir, true)
		local f0, f1 = (i - 1) / (#pts - 1), i / (#pts - 1)
		beam(folder, a0, a1, {
			name = string.format("%s%02d", name, i),
			texture = TEX.Current,
			width0 = w0 + (w1 - w0) * f0,
			width1 = w0 + (w1 - w0) * f1,
			speed = speed * (1 - 0.4 * f0),
			length = 16,
			colour = ColorSequence.new(P.Foam),
			transparency = fade(t0 + (t1 - t0) * f0, t0 + (t1 - t0) * f1),
			faceCamera = false,
			light = 0.1,
		})
	end
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
	for _, name in { "UpperFalls", "Horsetail", "Curtain", "Creek", "Foam", "Current", "Rainbow" } do
		local f = Instance.new("Folder")
		f.Name = name
		f.Parent = model
		folders[name] = f
	end

	-- upper falls: the feed, off the projecting lip into the ledge basin. Narrower than the main
	-- curtain (about 7 against 14) so the curtain below the second ledge reads as the one fall
	local lipTop = Vector3.new(X, Cascade.LipHeight + 0.5, -Cascade.LipEdgeY)
	local basin = Cascade.Ledge.basin
	local ledgeLanding = world(basin + Vector2.new(-1.5, 1.2), Cascade.Ledge.water)
	local outward = Vector3.new(0, -0.22, -1)
	local upperT1 = (Cascade.LipHeight - Cascade.Ledge.water) / Cascade.LipHeight * 0.95
	fall(folders.UpperFalls, host, "Upper", lipTop, ledgeLanding, outward, 0, upperT1, 6.5, 3, 7)

	-- horsetail: a thin slide on the chute, from the tarn stream into the same ledge basin
	local tail: { Vector3 } = {}
	for _, fp in Cascade.Horsetail do
		table.insert(tail, world(fp.p, fp.h + 0.7))
	end
	local tailLayers: { { any } } = {
		{ "Body", TEX.WaterBody, 3, 1.4, 9, 0.25 },
		{ "Fast", TEX.WaterStrandsFast, 2.6, 2.8, 7, 0.36 },
	}
	for k, sp in if Cascade.SideFalls then tailLayers else {} do
		chain(folders.Horsetail, host, "Horsetail" .. sp[1], tail, 0.16, 0.62, {
			name = "",
			texture = sp[2],
			width0 = sp[3],
			width1 = sp[3] * 1.15,
			speed = sp[4],
			length = sp[5],
			colour = ColorSequence.new(P.Body),
			transparency = fade(sp[6], sp[6] + 0.08),
			light = 0.12,
			z = k * 0.02,
		}, false)
	end

	-- the main curtain off the second ledge, in front of the rock wherever the written terrain
	-- reaches furthest north across its width (so the face never hides the sheet)
	local pool = Cascade.Pool
	local cw = Cascade.Curtain
	local topZ = -(Cascade.LowerLip.y + 0.4)
	for _, ox in { -cw.width / 2, 0, cw.width / 2 } do
		for _, y in { Cascade.LowerLip.height - 4, Cascade.LowerLip.height - 20, Cascade.LowerLip.height - 40 } do
			local z = faceZ(cw.x + ox, y)
			if z then
				topZ = math.min(topZ, z - 1.2)
			end
		end
	end
	local curtainTop = Vector3.new(cw.x, Cascade.LowerLip.height + 0.35, topZ)
	-- it lands about 5 studs out from the lip, inside the pool's south half
	local landingPlan = Vector2.new(cw.x - 1, -topZ + 5)
	local poolLanding = world(landingPlan, Field.LakeLevel + 0.2)
	curtain(folders.Curtain, host, curtainTop, poolLanding, cw.width)

	-- creek and side stream: flowing water on the channel, white rapids where it steepens
	local streams: { { any } } = { { "Creek", Cascade.Creek, 0, 0.08 } }
	if Cascade.SideFalls then
		table.insert(streams, { "Side", Cascade.SideStream, 0.06, 0.15 })
	end
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

	-- the curtain foot: impacts across its width (two, not three, to keep the particle count near
	-- the old falls), the ledge impact under the feed, foam rings, a foam patch, rising mist
	impact(host, "Ledge", ledgeLanding, 0.6)
	for k, ox in { -cw.width * 0.25, cw.width * 0.25 } do
		impact(host, "Pool" .. k, poolLanding + Vector3.new(ox, 0, 0), 0.85)
	end
	foamRing(folders.Foam, host, "LedgeFoam", basin + Vector2.new(-1, 1), Cascade.Ledge.water, 3.2)
	-- the ring (about 16 to 22 across) stays inside the 40 by 26 pool
	foamRing(folders.Foam, host, "PoolFoam", landingPlan + Vector2.new(0, 0.5), Field.LakeLevel, 7.5)
	local patchA = world(landingPlan - Vector2.new(cw.width * 0.6, 0), Field.LakeLevel + 0.1)
	local patchB = world(landingPlan + Vector2.new(cw.width * 0.6, 0), Field.LakeLevel + 0.1)
	beam(folders.Foam, attach(host, patchA, patchB - patchA, true), attach(host, patchB, patchB - patchA, true), {
		name = "PoolFoamPatch",
		texture = TEX.FoamTile,
		width0 = 5.5,
		width1 = 5.5,
		speed = 0.2,
		length = 8,
		colour = ColorSequence.new(P.Foam),
		transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.7),
			NumberSequenceKeypoint.new(0.2, 0.18),
			NumberSequenceKeypoint.new(0.8, 0.18),
			NumberSequenceKeypoint.new(1, 0.7),
		}),
		faceCamera = false,
		light = 0.15,
		z = 0.05,
	})
	-- rising mist off the curtain foot (research: size 20 to 25, lifetime about 4, rate 3, never
	-- below transparency 0.8)
	emitter(host, "CliffMist", poolLanding + Vector3.new(0, 3, 0), Vector3.new(0, 1, 0.0001), {
		Texture = TEX.Mist,
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 10), NumberSequenceKeypoint.new(1, 24) }),
		Transparency = fade(0.82, 1),
		Lifetime = NumberRange.new(4, 6),
		Rate = 3,
		Speed = NumberRange.new(3, 5),
		SpreadAngle = Vector2.new(16, 16),
		Drag = 0.3,
		Color = ColorSequence.new(rgb(240, 248, 252)),
	})

	-- The current and the river's flow. With the river loop (park.riverLoop) the falls sit almost
	-- due south of the river's west mouth, so the pool's foam runs north across the lake into that
	-- (nearer) mouth, the river carries it one way round the park (west leg north, over the top,
	-- east leg south), and it comes out of the east mouth as a faint return current toward the
	-- outlet gorge at the lake's east end. One consistent circulation, nothing flowing uphill
	-- from a spring the layout no longer has. Without the loop (the S-stream layout) the current
	-- feeds the lake end and the stream flows away from the lake toward its spring, as before.
	local park = Layout.Data.park
	local stream = park.stream
	local loop = (park :: any).riverLoop == true
	local first, last = stream[1], stream[#stream]
	local inFirst = loop and (first - pool.centre).Magnitude <= (last - pool.centre).Magnitude
	local inMouth = if inFirst then first else last
	local outMouth = if inFirst then last else first
	local start = landingPlan + Vector2.new(2, 9)
	local currentBow = (start + inMouth) / 2 + Vector2.new(16, 0)
	surfaceRibbon(folders.Current, host, "Current", bowed(start, currentBow, inMouth, 5), 13, 7, 0.45, 0.72, 0.75)

	local flowPts: { Vector3 } = {}
	local step = if inFirst then 6 else -6
	local i0, i1 = if inFirst then 1 else #stream, if inFirst then #stream else 1
	local lastIndex = i0
	for i = i0, i1, step do
		table.insert(flowPts, world(stream[i], Field.LakeLevel + 0.08))
		lastIndex = i
	end
	if lastIndex ~= i1 then
		table.insert(flowPts, world(stream[i1], Field.LakeLevel + 0.08))
	end
	chain(folders.Current, host, "StreamFlow", flowPts, 0, 0, {
		name = "",
		texture = TEX.Current,
		width0 = park.streamWidth * 0.5,
		width1 = park.streamWidth * 0.5,
		speed = 0.55,
		length = 12,
		colour = ColorSequence.new(P.Foam),
		transparency = fade(0.7, 0.7),
		light = 0.05,
	}, true)
	if loop then
		local outlet = Field.Outlet.points[1]
		local returnBow = (outMouth + outlet) / 2 + Vector2.new(0, -24)
		surfaceRibbon(
			folders.Current,
			host,
			"ReturnCurrent",
			bowed(outMouth, returnBow, outlet, 4),
			7,
			4,
			0.72,
			0.97,
			0.5
		)
	end

	-- grotto: slow drips and a few fireflies in the shade behind the curtain
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

	-- A larger, softer mist rainbow (Task 4) beside the curtain (the client fades it by distance
	-- and viewpoint). It rises from the landing pool's spray on the west side, so its arc stands
	-- against the dark wet cliff and the west buttress rather than over the white water; only its
	-- right foot meets the spray. 50 across and about 26 high (the old bow was 33 by 16), its
	-- band 6.5 wide, lowest transparency 0.45 (research: 0.35 to 0.55), and both feet fade out
	-- (SoftEnds) so it reads as a partial arc in the mist rather than a hard painted band.
	local bowY = -(pool.centre.Y + 13)
	local left = Vector3.new(cw.x - 54, 2.5, bowY)
	local right = Vector3.new(cw.x - 4, 2.5, bowY)
	-- curves bend along X (up); the band faces the camera, so it keeps its width over the top of
	-- the arc, and the texture is stretched once along it
	local r0 = Instance.new("Attachment")
	r0.CFrame = CFrame.fromMatrix(left, Vector3.yAxis, Vector3.xAxis)
	r0.Parent = host
	local r1 = Instance.new("Attachment")
	r1.CFrame = CFrame.fromMatrix(right, Vector3.yAxis, Vector3.xAxis)
	r1.Parent = host
	local bow = beam(folders.Rainbow, r0, r1, {
		name = "MistRainbow",
		texture = TEX.Rainbow,
		width0 = 6.5,
		width1 = 6.5,
		speed = 0,
		length = 50,
		colour = ColorSequence.new(Color3.new(1, 1, 1)),
		transparency = Waterfall.softEnds(0.45, RAINBOW_SOFT_ENDS),
		curve0 = 34,
		curve1 = -34,
		faceCamera = true,
		light = 0.5,
		-- drawn over the falls behind it (it hangs in the spray in front of them)
		z = 2,
	})
	bow:SetAttribute("BaseTransparency", 0.45)
	bow:SetAttribute("SoftEnds", RAINBOW_SOFT_ENDS)
	bow.Segments = 40
	bow.TextureMode = Enum.TextureMode.Stretch
	bow.TextureLength = 1

	model:SetAttribute("Version", "falls-5")
	model:SetAttribute("TotalDrop", Cascade.LipHeight - Field.LakeLevel)
	model.Parent = parent
	return model
end

return Waterfall
