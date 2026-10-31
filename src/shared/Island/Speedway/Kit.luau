--!strict
-- Speedway kit pieces (Lane 3, presentation only): MeshPart templates for the speedway kit
-- meshes, and small part helpers. Runs on clients (the Speedway is assembled per client) and in
-- Studio edit mode. A mesh with an uploaded id in KitIds.Meshes loads from that asset; until the
-- guided import, a session-only preview is built from its mesh data in
-- ReplicatedStorage.Lane3_SpeedwayKitData (synced only by Adam's island preview project, outside
-- Git). Mesh data, palette and conventions: assets/island/kit/kit_speedway.py, kitlib.py.

local AssetService = game:GetService("AssetService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local KitIds = require(script.Parent.KitIds)
local KitManifest = require(script.Parent.KitManifest)

local Kit = {}

export type Entry = KitManifest.Entry

local cache: { [string]: MeshPart | false } = {}
local turns: { [string]: CFrame } = {}
local sources: { [string]: string } = {}
-- the 3D Importer stores meshes turned half round about Y (assets/island/kit/manifest.md)
local HALF_TURN = CFrame.Angles(0, math.pi, 0)

function Kit.has(name: string): boolean
	return (KitManifest :: any)[name] ~= nil
end

function Kit.info(name: string): Entry
	local entry = (KitManifest :: any)[name]
	assert(entry, "no speedway kit mesh called " .. name)
	return entry
end

type Data = { bounds: { { number } }, grid: number, p: { number }, t: { number } }

-- An EditableMesh with flat normals and palette UVs, centred on its bounds like an uploaded mesh
-- (the same build as Island/Hub/Environment/KitMesh, which lives in ServerStorage).
local function editable(data: Data): EditableMesh
	local em = AssetService:CreateEditableMesh()
	local p = data.p
	local ids = table.create(#p // 3)
	local positions = table.create(#p // 3)
	local lo, hi = data.bounds[1], data.bounds[2]
	local centre = Vector3.new((lo[1] + hi[1]) / 2, (lo[2] + hi[2]) / 2, (lo[3] + hi[3]) / 2)
	for i = 1, #p, 3 do
		local v = Vector3.new(p[i], p[i + 1], p[i + 2]) - centre
		table.insert(positions, v)
		table.insert(ids, em:AddVertex(v))
	end
	local grid = data.grid
	local uvs: { [number]: number } = {}
	local t = data.t
	for i = 1, #t, 4 do
		local a, b, c, swatch = t[i] + 1, t[i + 1] + 1, t[i + 2] + 1, t[i + 3]
		local face = em:AddTriangle(ids[a], ids[b], ids[c])
		local uv = uvs[swatch]
		if not uv then
			uv = em:AddUV(Vector2.new((swatch % grid + 0.5) / grid, (swatch // grid + 0.5) / grid))
			uvs[swatch] = uv
		end
		em:SetFaceUVs(face, { uv, uv, uv })
		local normal = (positions[b] - positions[a]):Cross(positions[c] - positions[a])
		if normal.Magnitude > 1e-9 then
			local n = em:AddNormal(normal.Unit)
			em:SetFaceNormals(face, { n, n, n })
		end
	end
	return em
end

local function finish(part: MeshPart, name: string)
	part.Name = name
	part.TextureID = KitIds.Palette
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = true
	part.Material = Enum.Material.SmoothPlastic
end

-- The template MeshPart for a kit mesh (not parented; clone it), or nil when the mesh has neither
-- an uploaded id nor preview data in this place (the look then leaves that piece out).
function Kit.template(name: string): MeshPart?
	local cached = cache[name]
	if cached ~= nil then
		return if cached then cached else nil
	end
	if not Kit.has(name) then
		cache[name] = false
		return nil
	end
	local part: MeshPart? = nil
	local uploaded = KitIds.Meshes[name]
	if uploaded then
		local ok, loaded = pcall(function()
			return AssetService:CreateMeshPartAsync(Content.fromUri(uploaded), {
				CollisionFidelity = Enum.CollisionFidelity.Box,
				RenderFidelity = Enum.RenderFidelity.Automatic,
			})
		end)
		if ok then
			part = loaded
			sources[name] = uploaded
			turns[name] = HALF_TURN
		else
			warn(string.format("Speedway kit: %s (%s) failed to load (%s)", name, uploaded, tostring(loaded)))
		end
	end
	if not part then
		local folder = ReplicatedStorage:FindFirstChild("Lane3_SpeedwayKitData")
		local module = folder and folder:FindFirstChild(name, true)
		if module and module:IsA("ModuleScript") then
			local ok, made = pcall(function()
				local data = (require :: any)(module) :: Data
				return AssetService:CreateMeshPartAsync(Content.fromObject(editable(data)), {
					CollisionFidelity = Enum.CollisionFidelity.Box,
					RenderFidelity = Enum.RenderFidelity.Automatic,
				})
			end)
			if ok then
				part = made
				sources[name] = "preview"
				turns[name] = CFrame.identity
			else
				warn(string.format("Speedway kit: preview of %s failed (%s)", name, tostring(made)))
			end
		end
	end
	if not part then
		cache[name] = false
		return nil
	end
	local made = part :: MeshPart
	finish(made, name)
	cache[name] = made
	return made
end

-- A clone of the template with the mesh origin (recipe ground point) at `base`. The mesh's
-- front (recipe -y) faces base's local +Z, so CFrame.lookAt(at, at - facing) faces it along
-- `facing`. `scale` is a number or a per-axis Vector3 (for stretched pieces such as columns).
function Kit.place(name: string, base: CFrame, scale: (number | Vector3)?): MeshPart?
	local template = Kit.template(name)
	if not template then
		return nil
	end
	local entry = Kit.info(name)
	local s: Vector3 = if typeof(scale) == "Vector3"
		then scale
		elseif type(scale) == "number" then Vector3.one * scale
		else Vector3.one
	local part = template:Clone()
	local centre = (entry.min + entry.max) / 2
	part.Size = (entry.max - entry.min) * s
	part.CFrame = base * CFrame.new(centre * s) * turns[name]
	return part
end

-- A meta point of a mesh (Roblox mesh-local, from the origin) in the world, for a piece at base.
function Kit.point(name: string, key: string, base: CFrame, scale: number?): Vector3?
	local p = Kit.info(name).points[key]
	if not p then
		return nil
	end
	return base:PointToWorldSpace(p * (scale or 1))
end

function Kit.meta(name: string, key: string, default: number): number
	return Kit.info(name).meta[key] or default
end

function Kit.sources(): { [string]: string }
	return table.clone(sources)
end

export type PartOptions = {
	name: string?,
	color: Color3?,
	material: Enum.Material?,
	transparency: number?,
	collide: boolean?,
	shape: Enum.PartType?,
	castShadow: boolean?,
}

-- Every Speedway part is anchored. Decoration does not collide, query or touch.
function Kit.part(parent: Instance, size: Vector3, cframe: CFrame, options: PartOptions?): Part
	local o: PartOptions = options or {}
	local p = Instance.new("Part")
	p.Name = o.name or "Part"
	p.Anchored = true
	p.Size = size
	p.CFrame = cframe
	p.Color = o.color or Color3.fromRGB(200, 200, 200)
	p.Material = o.material or Enum.Material.SmoothPlastic
	p.Transparency = o.transparency or 0
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CastShadow = if o.castShadow == nil then true else o.castShadow
	if o.shape then
		p.Shape = o.shape
	end
	local collide = o.collide == true
	p.CanCollide = collide
	p.CanQuery = collide
	p.CanTouch = false
	p.Parent = parent
	return p
end

-- A slab between two points along its length, its top `top` above the points' frame, tilted by
-- the frame `up` (for banked or sloped road). a and b are world points on the slab's top centre.
function Kit.slab(
	parent: Instance,
	a: Vector3,
	b: Vector3,
	up: Vector3,
	width: number,
	thickness: number,
	options: PartOptions?,
	overlap: number?
): Part?
	local along = b - a
	local length = along.Magnitude
	if length < 1e-3 then
		return nil
	end
	local look = along.Unit
	local upv = (up - look * up:Dot(look)).Unit
	local centre = (a + b) / 2 - upv * thickness / 2
	return Kit.part(
		parent,
		Vector3.new(width, thickness, length + (overlap or 0)),
		CFrame.lookAt(centre, centre + look, upv),
		options
	)
end

return Kit
