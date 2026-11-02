--!strict
-- Supercar: Car Hop's original preview supercar (Lane 3, Round 3 N4). A code-built body with no real model, badge or name, used
-- for the Style turntable, the launch card and the Launch Pad stalls. It is a preview rig only: finished cars stay Brian L's.
--
--   local rig = Supercar.new()            -- a Model of SpecialMesh parts, front toward -Z, wheels on y = 0
--   rig:setPaint(item?, phase?)  rig:tick(phase)  rig:setDecal(item?)  rig:setWheels(item?)  rig:destroy()
--   Supercar.available() -> boolean       -- false until the meshes exist here; the caller shows its fallback
--
-- HOW IT DRAWS. Paint is the body part's colour. Over it sit shells: copies of the body a hair larger whose texture has real
-- alpha, because a part at Transparency 0.02 honours a texture's alpha where an opaque one shows black. One shell carries the
-- paint pattern (tinted by VertexColor, so one image serves every colour), one the decal, one the fixed details (glass, lamps,
-- vents, gloss). Decals are masked off the glass when they are baked, so the shells' draw order does not matter.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Prototype = script.Parent
local GameIconIds = require(Prototype.GameIconIds)
local GameIcons = require(Prototype.GameIcons)
local Catalog = require(ReplicatedStorage.Shared.UI.CosmeticPreviewCatalog)

local Supercar = {}
Supercar.__index = Supercar

Supercar.Length = 13
Supercar.Height = 3.3

local WHEEL_R = 1.02
local AXLE_Z = { -6.5 + 13 * 0.2, -6.5 + 13 * 0.785 }
local TRACK = 2.62

local function meshUri(key: string): string?
	local id = GameIconIds[key]
	if id then
		return id
	end
	if ReplicatedStorage:FindFirstChild("Lane3_LocalArt") then
		return "rbxasset://carhop/" .. key .. ".mesh"
	end
	return nil
end

function Supercar.available(): boolean
	return meshUri("car_body") ~= nil
end

local function piece(parent: Instance, name: string, mesh: string, colour: Color3, cf: CFrame?): (Part, SpecialMesh)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Size = Vector3.new(1, 1, 1)
	p.Color = colour
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CFrame = cf or CFrame.new()
	local m = Instance.new("SpecialMesh")
	m.MeshType = Enum.MeshType.FileMesh
	m.MeshId = meshUri(mesh) or ""
	m.Scale = Vector3.new(1, 1, 1)
	m.Parent = p
	p.Parent = parent
	return p, m
end

local function shell(parent: Instance, name: string, texture: string?): (Part, SpecialMesh)
	local p, m = piece(parent, name, "car_shell", Color3.new(1, 1, 1))
	p.Transparency = 0.02
	m.TextureId = texture or ""
	return p, m
end

type RigFields = {
	model: Model,
	_body: Part,
	_pattern: Part,
	_patternMesh: SpecialMesh,
	_decal: Part,
	_decalMesh: SpecialMesh,
	_rims: { Part },
	_rimMeshes: { SpecialMesh },
	_paint: Catalog.Item?,
}
export type Rig = typeof(setmetatable({} :: RigFields, Supercar))

function Supercar.new(): Rig
	local model = Instance.new("Model")
	model.Name = "Supercar"
	local body = piece(model, "Body", "car_body", Color3.fromRGB(40, 110, 240))
	local pattern, patternMesh = shell(model, "Pattern", nil)
	pattern.Transparency = 1
	local decal, decalMesh = shell(model, "Decal", nil)
	decal.Transparency = 1
	shell(model, "Detail", GameIcons.uri("car_detail"))
	piece(model, "Trim", "car_trim", Color3.fromRGB(14, 15, 20))
	local rims: { Part } = {}
	local rimMeshes: { SpecialMesh } = {}
	for _, z in AXLE_Z do
		for _, side in { 1, -1 } do
			local cf = CFrame.new(side * TRACK, WHEEL_R, z) * CFrame.Angles(0, if side > 0 then 0 else math.pi, 0)
			piece(model, "Tyre", "car_tyre", Color3.fromRGB(18, 18, 22), cf)
			local rim, mesh = piece(model, "Rim", "car_rim_five", Color3.fromRGB(200, 206, 222), cf)
			rim.Material = Enum.Material.Metal
			table.insert(rims, rim)
			table.insert(rimMeshes, mesh)
		end
	end
	model.PrimaryPart = body
	local self = setmetatable({
		model = model,
		_body = body,
		_pattern = pattern,
		_patternMesh = patternMesh,
		_decal = decal,
		_decalMesh = decalMesh,
		_rims = rims,
		_rimMeshes = rimMeshes,
		_paint = nil,
	}, Supercar)
	return self
end

local function setPattern(self: Rig, key: string?, tint: Color3?)
	local uri = key and GameIcons.uri(key)
	if uri then
		self._pattern.Transparency = 0.02
		self._patternMesh.TextureId = uri
		local c = tint or Color3.new(1, 1, 1)
		self._patternMesh.VertexColor = Vector3.new(c.R, c.G, c.B)
	else
		self._pattern.Transparency = 1
	end
end

local ANIMATED_FX: { [string]: string } = {
	galaxy = "paintfx_stars",
	lava = "paintfx_lava",
}

local function sample(colours: { Color3 }, t: number): Color3
	local n = #colours
	local f = (t % 1) * n
	local i = math.floor(f)
	return colours[(i % n) + 1]:Lerp(colours[((i + 1) % n) + 1], f - i)
end

function Supercar.setPaint(self: Rig, item: Catalog.Item?, phase: number?)
	self._paint = item
	if not item then
		self._body.Color = Color3.fromRGB(40, 110, 240)
		setPattern(self, nil)
		return
	end
	local c = item.colours
	self._body.Color = c[1]
	if item.kind == "metallic" then
		setPattern(self, "paintfx_pearl", c[1]:Lerp(Color3.new(1, 1, 1), 0.3))
	elseif item.kind == "pearl" then
		setPattern(self, "paintfx_pearl", c[2] or c[1]:Lerp(Color3.new(1, 1, 1), 0.5))
	elseif item.kind == "gradient" then
		setPattern(self, "paintfx_grad", c[2] or c[1])
	elseif item.kind == "animated" then
		local name = string.lower(item.name)
		local fx = "paintfx_wave"
		for word, key in ANIMATED_FX do
			if string.find(name, word, 1, true) then
				fx = key
			end
		end
		setPattern(self, fx, c[2] or c[1])
		self:tick(phase or 0.18)
	else
		setPattern(self, nil)
	end
end

-- Animated paints only: one shared phase in 0..1. Costs two colour writes.
function Supercar.tick(self: Rig, phase: number)
	local item = self._paint
	if not (item and item.kind == "animated") then
		return
	end
	local fixed = self._patternMesh.TextureId == GameIcons.uri("paintfx_stars")
	if fixed then
		local c = sample(item.colours, phase)
		self._patternMesh.VertexColor = Vector3.new(c.R, c.G, c.B)
	else
		local a, b = sample(item.colours, phase), sample(item.colours, phase + 0.35)
		self._body.Color = a
		self._patternMesh.VertexColor = Vector3.new(b.R, b.G, b.B)
	end
end

function Supercar.isAnimated(item: Catalog.Item?): boolean
	return item ~= nil and item.kind == "animated"
end

function Supercar.setDecal(self: Rig, item: Catalog.Item?)
	local uri = item and item.key and GameIcons.uri("decal_" .. item.key)
	if uri then
		self._decal.Transparency = 0.02
		self._decalMesh.TextureId = uri
	else
		self._decal.Transparency = 1
	end
end

function Supercar.setWheels(self: Rig, item: Catalog.Item?)
	local key = item and item.key or "five"
	local uri = meshUri("car_rim_" .. key)
	local colour = item and item.colours[1] or Color3.fromRGB(200, 206, 222)
	local glow = key == "ten"
	if glow and item then
		colour = item.colours[3]
	end
	for i, rim in self._rims do
		self._rimMeshes[i].MeshId = uri or ""
		rim.Color = colour
		rim.Material = if glow then Enum.Material.Neon else Enum.Material.Metal
	end
end

function Supercar.destroy(self: Rig)
	self.model:Destroy()
end

return Supercar
