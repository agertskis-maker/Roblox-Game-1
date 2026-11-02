--!strict
-- The Car Hop sign family (Lane 3, M5). Every sign in the game comes from here: one construction,
-- many characters. Shared rules: one dark outline, the HUD's lettering, a real backing with
-- thickness, two trim widths, and a mount that explains why it stands where it stands. A sign has
-- a silhouette of its own, so it reads before its words do.
--
--   local SignKit = require(ReplicatedStorage.Shared.Island.SignKit)
--   SignKit.sign(parent, CFrame, { style = "Race", text = "PIT ROW", width = 20, height = 3.4 })
--
-- `cf` is the centre of the face with its LookVector out of the sign. Styles: Race, Park, Diner,
-- Motel, Trading, Fuel, Mine, Lodge, Trail, Downtown. Parts here never collide and cast no shadow.
-- Layers on the face are 0.08 apart, so nothing can flicker against its backing (M5-03).

local Tokens = require(script.Parent.Parent.UI.Tokens)

local SignKit = {}

local INK = Color3.fromRGB(26, 34, 56)
local IVORY = Color3.fromRGB(255, 246, 224)
local LAYER = 0.08

export type Style = {
	body: Color3,
	frame: Color3,
	text: Color3,
	stroke: Color3,
	material: Enum.Material,
}

SignKit.Styles = {
	Race = {
		body = Color3.fromRGB(30, 50, 104),
		frame = Color3.fromRGB(247, 200, 58),
		text = IVORY,
		stroke = INK,
		material = Enum.Material.SmoothPlastic,
	},
	Park = {
		body = Color3.fromRGB(28, 110, 116),
		frame = Color3.fromRGB(44, 54, 66),
		text = IVORY,
		stroke = INK,
		material = Enum.Material.SmoothPlastic,
	},
	Diner = {
		body = Color3.fromRGB(64, 196, 190),
		frame = Color3.fromRGB(240, 106, 112),
		text = IVORY,
		stroke = Color3.fromRGB(16, 74, 84),
		material = Enum.Material.SmoothPlastic,
	},
	Motel = {
		body = Color3.fromRGB(232, 92, 128),
		frame = Color3.fromRGB(255, 226, 150),
		text = IVORY,
		stroke = Color3.fromRGB(96, 24, 56),
		material = Enum.Material.SmoothPlastic,
	},
	Trading = {
		body = Color3.fromRGB(128, 62, 40),
		frame = Color3.fromRGB(74, 44, 30),
		text = Color3.fromRGB(248, 226, 182),
		stroke = Color3.fromRGB(52, 28, 18),
		material = Enum.Material.Wood,
	},
	Fuel = {
		body = Color3.fromRGB(244, 164, 56),
		frame = Color3.fromRGB(60, 58, 64),
		text = Color3.fromRGB(44, 38, 40),
		stroke = Color3.fromRGB(255, 232, 186),
		material = Enum.Material.SmoothPlastic,
	},
	Mine = {
		body = Color3.fromRGB(196, 146, 72),
		frame = Color3.fromRGB(70, 48, 34),
		text = Color3.fromRGB(58, 38, 26),
		stroke = Color3.fromRGB(240, 214, 160),
		material = Enum.Material.WoodPlanks,
	},
	Lodge = {
		body = Color3.fromRGB(78, 50, 36),
		frame = Color3.fromRGB(46, 30, 24),
		text = Color3.fromRGB(250, 232, 196),
		stroke = Color3.fromRGB(34, 22, 16),
		material = Enum.Material.Wood,
	},
	Trail = {
		body = Color3.fromRGB(46, 104, 72),
		frame = Color3.fromRGB(234, 226, 200),
		text = IVORY,
		stroke = Color3.fromRGB(20, 54, 36),
		material = Enum.Material.SmoothPlastic,
	},
	Downtown = {
		body = Color3.fromRGB(38, 44, 66),
		frame = Color3.fromRGB(120, 206, 232),
		text = IVORY,
		stroke = INK,
		material = Enum.Material.SmoothPlastic,
	},
} :: { [string]: Style }

export type Options = {
	style: string,
	text: string?,
	width: number,
	height: number,
	-- a short mark drawn in code beside the words, or alone on an icon sign
	icon: string?,
	-- a colour that tints the accent while the frame stays shared (portal identity)
	accent: Color3?,
	-- "posts" stands it on two posts down to `ground`, "hang" hangs it from a beam
	mount: string?,
	ground: number?,
	-- marquee bulbs along the top edge, or a soft glow behind the plate
	bulbs: boolean?,
	backlight: boolean?,
}

local function part(
	parent: Instance,
	name: string,
	size: Vector3,
	cf: CFrame,
	colour: Color3,
	material: Enum.Material?
): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Size = size
	p.CFrame = cf
	p.Color = colour
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function wedge(parent: Instance, name: string, size: Vector3, cf: CFrame, colour: Color3): WedgePart
	local p = Instance.new("WedgePart")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Size = size
	p.CFrame = cf
	p.Color = colour
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

-- The live lettering on a transparent face just proud of the plate.
local function lettering(
	parent: Instance,
	cf: CFrame,
	w: number,
	h: number,
	text: string,
	style: Style,
	align: Enum.TextXAlignment?
)
	local face = part(parent, "SignFace", Vector3.new(w, h, 0.02), cf * CFrame.Angles(0, math.pi, 0), IVORY)
	face.Transparency = 1
	local g = Instance.new("SurfaceGui")
	g.Name = "Face"
	g.Face = Enum.NormalId.Front
	g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	g.PixelsPerStud = 40
	g.LightInfluence = 1
	g.MaxDistance = 500
	g.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	g.Parent = face
	local t = Instance.new("TextLabel")
	t.Name = "Text"
	t.BackgroundTransparency = 1
	t.Size = UDim2.fromScale(1, 1)
	t.FontFace = Tokens.font()
	t.Text = text
	t.TextColor3 = style.text
	t.TextScaled = true
	t.TextXAlignment = align or Enum.TextXAlignment.Center
	t.Parent = g
	local stroke = Instance.new("UIStroke")
	stroke.Color = style.stroke
	stroke.Thickness = math.max(3, math.floor(h * 40 / 14))
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	stroke.Parent = t
	return face
end

-- Small pictures built from parts on the plate. Each reads without words.
local ICONS: { [string]: (Instance, CFrame, number, Style) -> () } = {}

function ICONS.cup(parent, cf, s, style)
	local c = style.text
	part(parent, "IconCup", Vector3.new(s * 0.62, s * 0.55, 0.06), cf * CFrame.new(-s * 0.05, -s * 0.1, 0), c)
	part(parent, "IconCupBase", Vector3.new(s * 0.86, s * 0.08, 0.06), cf * CFrame.new(-s * 0.05, -s * 0.42, 0), c)
	part(parent, "IconCupHandle", Vector3.new(s * 0.14, s * 0.3, 0.06), cf * CFrame.new(s * 0.36, -s * 0.08, 0), c)
end

function ICONS.bed(parent, cf, s, style)
	local c = style.text
	part(parent, "IconBed", Vector3.new(s, s * 0.2, 0.06), cf * CFrame.new(0, -s * 0.22, 0), c)
	part(parent, "IconBedHead", Vector3.new(s * 0.12, s * 0.62, 0.06), cf * CFrame.new(-s * 0.46, 0, 0), c)
	part(parent, "IconPillow", Vector3.new(s * 0.3, s * 0.16, 0.06), cf * CFrame.new(-s * 0.22, -s * 0.03, 0), c)
end

function ICONS.drop(parent, cf, s, style)
	local c = style.text
	part(
		parent,
		"IconDrop",
		Vector3.new(s * 0.5, s * 0.5, 0.06),
		cf * CFrame.new(0, -s * 0.14, 0) * CFrame.Angles(0, 0, math.rad(45)),
		c
	)
	wedge(
		parent,
		"IconDropTip",
		Vector3.new(0.06, s * 0.36, s * 0.36),
		cf * CFrame.new(0, s * 0.3, 0) * CFrame.Angles(0, math.rad(90), 0),
		c
	)
end

function ICONS.mountain(parent, cf, s, style)
	local c = style.text
	for _, m in { { -0.2, 0.7 }, { 0.26, 0.5 } } do
		local h = s * m[2]
		for _, flip in { 1, -1 } do
			wedge(
				parent,
				"IconPeak",
				Vector3.new(0.06, h, h * 0.8),
				cf
					* CFrame.new(s * m[1] + flip * h * 0.4, -s * 0.2 + h / 2, 0)
					* CFrame.Angles(0, flip * math.rad(90), 0),
				c
			)
		end
	end
end

-- The checkered end cap of a Race sign, painted tiles on the plate.
local function checkerCap(parent: Instance, cf: CFrame, w: number, h: number)
	local n = 3
	local tile = h / n
	for row = 0, n - 1 do
		for col = 0, 1 do
			if (row + col) % 2 == 0 then
				part(
					parent,
					"CheckerTile",
					Vector3.new(tile, tile, 0.06),
					cf * CFrame.new((col - 0.5) * tile, (row - (n - 1) / 2) * tile, 0),
					IVORY
				)
			else
				part(
					parent,
					"CheckerTile",
					Vector3.new(tile, tile, 0.06),
					cf * CFrame.new((col - 0.5) * tile, (row - (n - 1) / 2) * tile, 0),
					INK
				)
			end
		end
	end
	return w
end

function SignKit.sign(parent: Instance, cf: CFrame, o: Options): Model
	local style = SignKit.Styles[o.style]
	assert(style, "no sign style " .. o.style)
	-- from here on local +Z is out of the sign and local -X is the viewer's left
	cf *= CFrame.Angles(0, math.pi, 0)
	local m = Instance.new("Model")
	m.Name = "Sign" .. o.style
	local w, h = o.width, o.height
	local depth = 0.5
	local frameW = h * 0.06
	local plate = cf * CFrame.new(0, 0, -depth / 2)
	part(m, "Plate", Vector3.new(w, h, depth), plate, style.body, style.material)
	-- the frame, proud of the plate, overlapping nothing at its corners
	local front = cf * CFrame.new(0, 0, LAYER / 2)
	for _, sy in { 1, -1 } do
		part(
			m,
			"Frame",
			Vector3.new(w, frameW, LAYER),
			front * CFrame.new(0, sy * (h - frameW) / 2, 0),
			o.accent or style.frame
		)
	end
	for _, sx in { 1, -1 } do
		part(
			m,
			"Frame",
			Vector3.new(frameW, h - 2 * frameW, LAYER),
			front * CFrame.new(sx * (w - frameW) / 2, 0, 0),
			o.accent or style.frame
		)
	end

	local inner = cf * CFrame.new(0, 0, LAYER * 1.5)
	local quietW, quietH = w - 2 * h * 0.16, h * 0.6
	local textCentre = 0
	if o.style == "Race" and w > h * 3 then
		local capW = h * 0.68
		for _, sx in { 1, -1 } do
			checkerCap(m, inner * CFrame.new(sx * (w / 2 - frameW - capW / 2), 0, 0), capW, h - 2 * frameW)
		end
		quietW = w - 2 * (capW + frameW) - h * 0.2
	end
	if o.icon and ICONS[o.icon] then
		local size = h * 0.62
		if o.text then
			textCentre = size * 0.6
			quietW -= size * 1.2
			ICONS[o.icon](m, inner * CFrame.new(-quietW / 2 - size * 0.05 + textCentre - size * 0.6, 0, 0), size, style)
		else
			ICONS[o.icon](m, inner, size * 1.3, style)
		end
	end
	if o.text then
		lettering(m, inner * CFrame.new(textCentre, 0, 0.04), quietW, quietH, o.text, style)
	end

	-- silhouette per character
	if o.style == "Lodge" then
		-- a timber gable with snow on it; the snow stays off the words
		local gable = h * 0.42
		for _, flip in { 1, -1 } do
			wedge(
				m,
				"Gable",
				Vector3.new(depth, gable, w / 2),
				cf * CFrame.new(flip * w / 4, h / 2 + gable / 2, -depth / 2) * CFrame.Angles(0, flip * math.rad(90), 0),
				style.frame
			)
		end
		local slope = math.sqrt((w / 2) ^ 2 + gable ^ 2)
		local tilt = math.atan2(gable, w / 2)
		for _, flip in { 1, -1 } do
			part(
				m,
				"Snow",
				Vector3.new(slope, h * 0.1, depth + 0.3),
				cf
					* CFrame.new(flip * w / 4, h / 2 + gable / 2 + h * 0.07, -depth / 2)
					* CFrame.Angles(0, 0, -flip * tilt),
				Color3.fromRGB(244, 248, 252)
			)
		end
	elseif o.style == "Motel" then
		-- a tall arrow silhouette: a pointer under the plate
		wedge(
			m,
			"ArrowTip",
			Vector3.new(depth, h * 0.5, w * 0.5),
			cf * CFrame.new(0, -h * 0.75, -depth / 2) * CFrame.Angles(0, math.rad(90), math.rad(180)),
			o.accent or style.frame
		)
	elseif o.style == "Trail" then
		-- an arrow end, pointing along the sign's +X
		for _, flip in { 1, -1 } do
			wedge(
				m,
				"ArrowHead",
				Vector3.new(depth, h / 2, h * 0.6),
				cf
					* CFrame.new(w / 2 + h * 0.3, flip * h / 4, -depth / 2)
					* CFrame.Angles(if flip > 0 then 0 else math.pi, math.rad(-90), 0),
				style.body
			)
		end
	end

	if o.bulbs then
		local n = math.floor(w / 1.2)
		for k = 0, n - 1 do
			local b = part(
				m,
				"Bulb",
				Vector3.new(0.36, 0.36, 0.36),
				cf * CFrame.new(-w / 2 + (k + 0.5) * w / n, h / 2 + 0.26, -depth / 2),
				Color3.fromRGB(255, 232, 170),
				Enum.Material.Neon
			)
			b.Shape = Enum.PartType.Ball
		end
	end
	if o.backlight then
		local light = Instance.new("SurfaceLight")
		light.Face = Enum.NormalId.Front
		light.Angle = 80
		light.Range = 8
		light.Brightness = 0.6
		light.Color = Color3.fromRGB(255, 236, 190)
		light.Parent = m:FindFirstChild("Plate")
	end

	if o.mount == "posts" and o.ground then
		local y = (plate.Position.Y - h / 2 + o.ground) / 2
		local tall = plate.Position.Y - h / 2 - o.ground
		if tall > 0.05 then
			for _, sx in { 1, -1 } do
				local at = plate * CFrame.new(sx * w * 0.32, 0, 0)
				part(
					m,
					"Post",
					Vector3.new(h * 0.14, tall, h * 0.14),
					CFrame.new(at.X, y, at.Z) * (at - at.Position),
					style.frame
				)
			end
		end
	elseif o.mount == "hang" then
		local beam = h * 0.5
		part(m, "HangBeam", Vector3.new(w + 1.2, 0.3, 0.3), plate * CFrame.new(0, h / 2 + beam, 0), style.frame)
		for _, sx in { 1, -1 } do
			part(
				m,
				"HangChain",
				Vector3.new(0.08, beam, 0.08),
				plate * CFrame.new(sx * w * 0.36, h / 2 + beam / 2, 0),
				Color3.fromRGB(60, 62, 70),
				Enum.Material.Metal
			)
		end
	end
	m.Parent = parent
	return m
end

return SignKit
