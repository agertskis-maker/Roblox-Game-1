--!strict
-- The World portal gates (Lane 3, build-time, the same for every player). Two columns and a crest
-- round each existing field, from the Task 4 `gates` kit family (concepts/gates/README.md,
-- "Production"): Downtown gold art deco, Dusty Highway red sandstone, Summit Pass pale alpine
-- stone with ice. Per World, a Model "<World>Gate" holding:
--   the gate meshes (Plinth, Columns, Crest, Crown), placed with their origin on the ground
--   park.portal.gateSetback behind the field's centre line (so the field is drawn in front of its
--   frame) and their front toward the plots. They never collide: their box collision
--   would wall off the opening, so invisible colliders stand in for the plinths and the columns;
--   the three inlay band meshes (InlayLow, InlayMid, InlayHigh, attribute Band 1 to 3) on the
--   neutral swatch, for each client to colour: dark while locked, lit in the World colour when
--   open (Portals.client.luau). The lock itself is per player and lives on the client;
--   SignFace parts on the recorded crest name face (the World name in live text) and the emblem
--   face (a live emblem drawn from shapes), per the pending sign spec
--   (vault/design/ui/island-task4-signs.md, section 1; nothing there is approved yet);
--   a StandIn folder: the colliders plus simple part blocks (capitals and the crest), invisible
--   here; a client shows them in a playtest while the meshes are only session previews (an
--   un-uploaded mesh does not reach Play), and InlayStrips, part strips from the band meta for the
--   same fallback;
--   attributes for the clients: Origin (the gate frame), Chained (Downtown is never chained),
--   Source (the Columns mesh source, "preview" until uploaded), the Columns mesh points (chain
--   wraps, chain anchors, chain_cross) as "pt_..." Vector3 attributes in the gate frame, and
--   PlaqueBase (the requirement plaque's ground frame) on chained gates.

local KitAssets = require(script.Parent.KitAssets)
local KitManifest = require(script.Parent.KitManifest)
local Layout = require(script.Parent.Parent.Layout)

local PortalGates = {}

local THEME: { [string]: string } = { Downtown = "Downtown", DustyHighway = "Dusty", SummitPass = "Summit" }
local PIECES = { "Plinth", "Columns", "Crest", "Crown" }
local BANDS = { "InlayLow", "InlayMid", "InlayHigh" }
local CREST_PPS = 20 -- TextSize stops at 100 px, so the crest canvas is coarse (text stays sharp)
local EMBLEM_PX = 256
local hex = Color3.fromHex

-- Crest lettering (sign spec section 1, with the production face of 29 x 9.8 and review P3: two
-- lines for both two-word names; capitals 3.6, DOWNTOWN 3.15 on one line, width-limited).
-- Colours are the spec's proposals (not tokens). Readable only from mid-distance (about 130 to
-- 150 studs by the spec's limit rule); the emblem, colour and silhouette carry identity farther.
type CrestStyle = {
	lines: { string },
	cap: number,
	panel: Color3,
	letter: Color3,
	side: Color3,
	outline: Color3,
}
local CREST: { [string]: CrestStyle } = {
	Downtown = {
		lines = { "DOWNTOWN" },
		cap = 3.15,
		panel = hex("1E2A4A"),
		letter = hex("F2C14E"),
		side = hex("8A5F12"),
		outline = hex("141B33"),
	},
	DustyHighway = {
		lines = { "DUSTY", "HIGHWAY" },
		cap = 3.6,
		panel = hex("C8643F"),
		letter = hex("FFF6E0"),
		side = hex("7A2E1E"),
		outline = hex("3B2A1E"),
	},
	SummitPass = {
		lines = { "SUMMIT", "PASS" },
		cap = 3.6,
		panel = hex("E6EEF3"),
		letter = hex("24477A"),
		side = hex("5FA9CF"),
		outline = hex("141B33"),
	},
}

-- Part stand-in colours per theme (Play fallback only): plinth, column, (unused), crest.
local STAND_IN: { [string]: { Color3 } } = {
	Downtown = { hex("1E2A4A"), hex("FFF6E0"), hex("F2C14E"), hex("F2C14E") },
	DustyHighway = { hex("9A4530"), hex("C8643F"), hex("E39A6B"), hex("9A4530") },
	SummitPass = { hex("C3D2DE"), hex("E6EEF3"), hex("F4F8FC"), hex("5FA9CF") },
}

local FONT = Font.fromName("FredokaOne")

-- Attribute names allow letters, digits and underscores only.
function PortalGates.attributeName(key: string): string
	return (string.gsub(key, "[^%w_]", "_"))
end

local function plainPart(name: string, size: Vector3, cf: CFrame, parent: Instance): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Transparency = 1
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Size = size
	p.CFrame = cf
	p.Parent = parent
	return p
end

-- A thin transparent part whose Front face lies exactly on a recorded sign face rectangle
-- (centre, outward normal, up, in the mesh frame `base`), 0.03 proud of the mesh. Its
-- SurfaceGui goes on Face = Front.
function PortalGates.signFace(
	name: string,
	base: CFrame,
	centre: Vector3,
	normal: Vector3,
	up: Vector3,
	size: Vector2,
	parent: Instance
): Part
	local c = base:PointToWorldSpace(centre)
	local n = base:VectorToWorldSpace(normal).Unit
	local u = base:VectorToWorldSpace(up).Unit
	local thick = 0.05
	local at = c + n * (0.03 - thick / 2)
	local part =
		plainPart("SignFace_" .. name, Vector3.new(size.X, size.Y, thick), CFrame.lookAt(at, at + n, u), parent)
	part:SetAttribute("SignFace", name)
	return part
end

-- The recorded sign face of a kit mesh ("sign_faces.1.*"), or nil.
function PortalGates.faceOf(mesh: string): (Vector3?, Vector3?, Vector3?, Vector2?)
	local info = KitAssets.info(mesh)
	local c, n, u =
		info.points["sign_faces.1.centre"], info.points["sign_faces.1.normal"], info.points["sign_faces.1.up"]
	local w, h = info.meta["sign_faces.1.size.1"], info.meta["sign_faces.1.size.2"]
	if not (c and n and u and w and h) then
		return nil, nil, nil, nil
	end
	return c, n, u, Vector2.new(w, h)
end

local function surfaceGui(face: Part, pps: number, lightInfluence: number): SurfaceGui
	local g = Instance.new("SurfaceGui")
	g.Name = "Face"
	g.Face = Enum.NormalId.Front
	g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	g.PixelsPerStud = pps
	g.LightInfluence = lightInfluence
	g.MaxDistance = 0
	g.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	g.Parent = face
	return g
end

local function shape(
	parent: Instance,
	x: number,
	y: number,
	w: number,
	h: number,
	colour: Color3,
	rotation: number?,
	round: boolean?
): Frame
	local f = Instance.new("Frame")
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Position = UDim2.fromOffset(x, y)
	f.Size = UDim2.fromOffset(w, h)
	f.Rotation = rotation or 0
	f.BackgroundColor3 = colour
	f.BorderSizePixel = 0
	if round then
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0.5, 0)
		c.Parent = f
	end
	f.Parent = parent
	return f
end

-- A World emblem drawn from simple original shapes on a 256 x 256 canvas (sign spec section 1:
-- towers and a star; a sun over mesas and a road; two peaks and a snowflake). Every shape stays
-- inside the disc. Texture hook: once crest-emblem-<world>.png is approved and uploaded, an
-- ImageLabel with that id replaces these shapes.
function PortalGates.emblem(world: string): Frame
	local root = Instance.new("Frame")
	root.Name = world
	root.BackgroundTransparency = 1
	root.Size = UDim2.fromOffset(EMBLEM_PX, EMBLEM_PX)
	local function disc(bg: Color3, ring: Color3)
		local d = shape(root, 128, 128, 236, 236, bg, 0, true)
		local s = Instance.new("UIStroke")
		s.Color = ring
		s.Thickness = 10
		s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		s.Parent = d
	end
	if world == "DustyHighway" then
		disc(hex("FFB46B"), hex("9A4530"))
		shape(root, 128, 140, 104, 104, hex("FFF6E0"), 0, true) -- the setting sun
		shape(root, 76, 168, 62, 44, hex("C8643F")) -- mesas
		shape(root, 76, 150, 50, 8, hex("E39A6B"))
		shape(root, 184, 164, 58, 52, hex("C8643F"))
		shape(root, 184, 142, 46, 8, hex("E39A6B"))
		shape(root, 128, 196, 152, 26, hex("9A4530")) -- the ground
		shape(root, 128, 198, 34, 26, hex("3B2A1E")) -- the road
		shape(root, 128, 198, 6, 20, hex("F7CE58"))
	elseif world == "SummitPass" then
		disc(hex("CFE9F7"), hex("24477A"))
		shape(root, 148, 170, 88, 88, hex("24477A"), 45) -- the tall peak
		shape(root, 96, 180, 66, 66, hex("5FA9CF"), 45) -- the low peak
		shape(root, 148, 128, 26, 26, hex("F4F8FC"), 45) -- snow caps
		shape(root, 96, 150, 20, 20, hex("F4F8FC"), 45)
		for _, a in { 0, 60, 120 } do -- a snowflake
			shape(root, 76, 82, 46, 6, hex("FFFFFF"), a)
		end
	else
		disc(hex("1E2A4A"), hex("BA5CFF"))
		local gold = hex("F2C14E")
		shape(root, 86, 166, 34, 70, gold) -- three stepped towers
		shape(root, 86, 128, 22, 10, gold)
		shape(root, 128, 146, 40, 110, gold)
		shape(root, 128, 86, 26, 12, gold)
		shape(root, 170, 160, 34, 84, gold)
		shape(root, 170, 114, 22, 10, gold)
		shape(root, 128, 204, 140, 8, gold)
		shape(root, 128, 58, 26, 26, hex("FFF6E0"), 45) -- the star
		shape(root, 128, 58, 26, 26, hex("FFF6E0"), 0)
	end
	return root
end

local function crestText(face: Part, world: string, size: Vector2)
	local style = CREST[world] or CREST.Downtown
	local g = surfaceGui(face, CREST_PPS, 0.6)
	local w, h = size.X * CREST_PPS, size.Y * CREST_PPS
	-- Texture hook: once crest-name-<world>.png is approved and uploaded, an ImageLabel with that
	-- id goes here in place of this plain panel (the live letters stay on top).
	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.Size = UDim2.fromOffset(w, h)
	panel.BackgroundColor3 = style.panel
	panel.BorderSizePixel = 0
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, math.floor(0.4 * CREST_PPS))
	corner.Parent = panel
	panel.Parent = g
	local n = #style.lines
	local textSize = math.min(100, math.floor(style.cap / 0.75 * CREST_PPS))
	local drop = math.floor(0.22 * CREST_PPS + 0.5) -- the letters' side face, shown as a drop
	for i, line in style.lines do
		for _, layer in { "Side", "Letters" } do
			local l = Instance.new("TextLabel")
			l.Name = layer .. i
			l.BackgroundTransparency = 1
			l.FontFace = FONT
			l.Text = line
			l.TextSize = textSize
			l.TextColor3 = if layer == "Side" then style.side else style.letter
			l.AnchorPoint = Vector2.new(0.5, 0.5)
			l.Position = UDim2.fromOffset(w / 2, h * (i - 0.5) / n + (if layer == "Side" then drop else 0))
			l.Size = UDim2.fromOffset(w, h / n)
			l.ZIndex = if layer == "Side" then 2 else 3
			local s = Instance.new("UIStroke")
			s.Color = style.outline
			s.Thickness = 3
			s.Parent = l
			l.Parent = panel
		end
	end
	g:SetAttribute("Spec", "vault/design/ui/island-task4-signs.md section 1 (pending Adam's approval)")
end

local function emblemFace(face: Part, world: string, size: Vector2)
	local g = surfaceGui(face, EMBLEM_PX / size.X, 0.6)
	local e = PortalGates.emblem(world)
	e.Parent = g
end

local function setPoints(target: Instance, info: KitManifest.Entry)
	for k, v in info.points do
		target:SetAttribute("pt_" .. PortalGates.attributeName(k), v)
	end
end

-- Builds one World's gate into `parent`. `origin` is on the ground at the field's centre line, its
-- +Z (the mesh front) toward the plots; the gate itself stands gateSetback behind it. Returns
-- the triangles placed.
function PortalGates.build(
	world: string,
	origin: CFrame,
	groundAt: (x: number, z: number) -> number,
	parent: Instance
): number
	local theme = THEME[world]
	assert(theme, "no gate theme for World " .. world)
	local model = Instance.new("Model")
	model.Name = world .. "Gate"
	model:SetAttribute("World", world)
	model:SetAttribute("Theme", theme)
	-- the frame stands park.portal.gateSetback behind the field plane (away from the plots; the
	-- mesh's -Z), so the field is drawn in front of its own columns and never clipped by them
	local setback = Layout.Data.park.portal.gateSetback or 0
	origin = origin * CFrame.new(0, 0, -setback)
	model:SetAttribute("Origin", origin)
	model:SetAttribute("Setback", setback) -- the field plane is at +Setback in the gate frame
	local triangles = 0
	for _, piece in PIECES do
		local name = "Gate" .. theme .. piece
		local part = KitAssets.place(name, origin, 1)
		part.Name = piece
		part:SetAttribute("GatePiece", true)
		part.Parent = model
		triangles += KitAssets.info(name).triangles
	end
	model:SetAttribute("Source", KitAssets.sources()["Gate" .. theme .. "Columns"] or "")

	-- the inlay bands: neutral, coloured per player on the client; part strips for the fallback
	local strips = Instance.new("Folder")
	strips.Name = "InlayStrips"
	strips.Parent = model
	for band, piece in BANDS do
		local name = "Gate" .. theme .. piece
		local info = KitAssets.info(name)
		local part = KitAssets.place(name, origin, 1)
		part.Name = piece
		part.CastShadow = false
		part:SetAttribute("Band", band)
		part:SetAttribute("Inlay", true)
		part.Parent = model
		triangles += info.triangles
		local depth = math.max(0.12, info.max.Z - info.min.Z)
		local zc = (info.min.Z + info.max.Z) / 2
		local k = 1
		while info.meta["strips." .. k .. ".x"] do
			local x = info.meta["strips." .. k .. ".x"]
			local z1, z2 = info.meta["strips." .. k .. ".z.1"], info.meta["strips." .. k .. ".z.2"]
			local s =
				plainPart("Strip", Vector3.new(0.6, z2 - z1, depth), origin * CFrame.new(x, (z1 + z2) / 2, zc), strips)
			s:SetAttribute("Band", band)
			k += 1
		end
	end

	-- colliders for the plinths and the columns, and the Play stand-in blocks
	local columns = KitAssets.info("Gate" .. theme .. "Columns")
	local plinthTop = KitAssets.info("Gate" .. theme .. "Plinth").meta.top or 2.6
	local axisX = columns.meta["columns_x.2"] or 13
	local section = columns.meta["column_section.1"] or 4
	local outer = columns.meta.outer_face_x or 15.4
	local top = columns.max.Y
	local colours = STAND_IN[world]
	local standIn = Instance.new("Folder")
	standIn.Name = "StandIn"
	standIn.Parent = model
	local function block(name: string, size: Vector3, at: Vector3, colour: Color3, collide: boolean)
		local b = plainPart(name, size, origin * CFrame.new(at), standIn)
		b.Color = colour
		b:SetAttribute("StandIn", true)
		if collide then
			b.CanCollide = true
			b.CanQuery = true
			b:SetAttribute("Collider", true)
		end
	end
	local plinthW = 2 * (outer - axisX)
	for _, side in { -1, 1 } do
		local x = side * axisX
		local label = if side < 0 then "Left" else "Right"
		block("Plinth" .. label, Vector3.new(plinthW, plinthTop, 5), Vector3.new(x, plinthTop / 2, 0), colours[1], true)
		-- the column runs up to the crest (no separate capital), so nothing crosses the opening
		block(
			"Column" .. label,
			Vector3.new(section, top - plinthTop, section),
			Vector3.new(x, (plinthTop + top) / 2, 0),
			colours[2],
			true
		)
	end
	local crest = KitAssets.info("Gate" .. theme .. "Crest")
	block(
		"Crest",
		Vector3.new(2 * (crest.meta.half_width or 15), crest.max.Y - crest.min.Y, 4.4),
		Vector3.new(0, (crest.min.Y + crest.max.Y) / 2, 0),
		colours[4],
		false
	)
	-- the medallion behind the emblem face: a disc whose front stays just behind that face
	local crown = KitAssets.info("Gate" .. theme .. "Crown")
	local medallion = crown.points["sign_faces.1.centre"] or Vector3.new(0, 46.4, 2.55)
	local radius = crown.meta.medallion_radius or 3.55
	local disc = plainPart(
		"Medallion",
		Vector3.new(1, 2 * radius, 2 * radius),
		origin * CFrame.new(medallion.X, medallion.Y, medallion.Z - 0.6) * CFrame.Angles(0, math.pi / 2, 0),
		standIn
	)
	disc.Shape = Enum.PartType.Cylinder
	disc.Color = colours[4]
	disc:SetAttribute("StandIn", true)

	-- the crest name and the emblem, as live text and shapes on SignFace parts
	local c, n, u, size = PortalGates.faceOf("Gate" .. theme .. "Crest")
	if c and n and u and size then
		crestText(PortalGates.signFace("CrestName", origin, c, n, u, size, model), world, size)
	end
	c, n, u, size = PortalGates.faceOf("Gate" .. theme .. "Crown")
	if c and n and u and size then
		emblemFace(PortalGates.signFace("Emblem", origin, c, n, u, size, model), world, size)
	end

	-- what the client's lock needs: chain points, and the requirement plaque's ground frame
	setPoints(model, columns)
	local chained = columns.points.chain_cross ~= nil
	model:SetAttribute("Chained", chained)
	if chained then
		-- the suggested placement beside a column (Columns meta requirement_plaque_suggested), on
		-- the gate's outer side, away from Downtown, so the two locked gates mirror (movement review
		-- m13: the mesh-local -x side is world east with the half turn, the inner side for Summit
		-- Pass, so a gate west of the axis takes the mirror image). The plaque's top is under 3,
		-- below the corridor limit and the lower-falls sight ray (about 4.6 here)
		local at = columns.points["requirement_plaque_suggested.position"] or Vector3.new(-14, 0, 6.5)
		local yaw = math.rad(columns.meta["requirement_plaque_suggested.yaw_deg"] or 25)
		local east = origin:VectorToWorldSpace(Vector3.new(-1, 0, 0)).X > 0
		local outerIsEast = origin.Position.X > (Layout.Data.park.axisX or 0)
		if east ~= outerIsEast then
			at = Vector3.new(-at.X, at.Y, at.Z)
			yaw = -yaw
		end
		local frame = origin * CFrame.new(at) * CFrame.Angles(0, yaw, 0)
		local p = frame.Position
		local ground = groundAt(p.X, p.Z)
		model:SetAttribute("PlaqueBase", CFrame.new(p.X, ground, p.Z) * frame.Rotation)
	end
	model.Parent = parent
	return triangles
end

return PortalGates
