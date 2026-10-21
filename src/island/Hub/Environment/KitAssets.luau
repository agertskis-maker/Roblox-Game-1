--!strict
-- Island kit meshes as MeshPart templates (Lane 3, build-time). A mesh with an uploaded id in
-- AssetIds.Meshes loads from that asset; until it is uploaded, a session-only preview is built
-- from its mesh data in ServerStorage.Lane3_KitData (synced only by Adam's island preview
-- project), so the build can be reviewed before the upload. Templates are cached and cloned.

local AssetService = game:GetService("AssetService")
local ServerStorage = game:GetService("ServerStorage")

local AssetIds = require(script.Parent.AssetIds)
local KitManifest = require(script.Parent.KitManifest)
local KitMesh = require(script.Parent.KitMesh)

local KitAssets = {}

local cache: { [string]: MeshPart } = {}
local sources: { [string]: string } = {}

function KitAssets.info(name: string): KitManifest.Entry
	local entry = KitManifest[name]
	assert(entry, "no kit mesh called " .. name)
	return entry
end

local function finish(part: MeshPart, name: string)
	part.Name = name
	part.TextureID = AssetIds.Palette
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = true
	part.Material = Enum.Material.SmoothPlastic
end

-- The template MeshPart for a kit mesh (not parented; clone it).
function KitAssets.template(name: string): MeshPart
	local cached = cache[name]
	if cached then
		return cached
	end
	KitAssets.info(name)
	local part: MeshPart
	local uploaded = (AssetIds.Meshes :: { [string]: string })[name]
	if uploaded then
		part = AssetService:CreateMeshPartAsync(Content.fromUri(uploaded), {
			CollisionFidelity = Enum.CollisionFidelity.Box,
			RenderFidelity = Enum.RenderFidelity.Automatic,
		})
		sources[name] = uploaded
	else
		local folder = ServerStorage:FindFirstChild("Lane3_KitData")
		local module = folder and folder:FindFirstChild(name)
		assert(
			module and module:IsA("ModuleScript"),
			name .. " has no uploaded id and no preview data (ServerStorage.Lane3_KitData)"
		)
		part = KitMesh.previewPart((require :: any)(module), AssetIds.Palette)
		sources[name] = "preview"
	end
	finish(part, name)
	cache[name] = part
	return part
end

-- Where each template used so far came from: an asset id, or "preview".
function KitAssets.sources(): { [string]: string }
	return table.clone(sources)
end

-- A clone of the template with the mesh's ground line (y 0 in mesh space) at `base`.
function KitAssets.place(name: string, base: CFrame, scale: number): MeshPart
	local entry = KitAssets.info(name)
	local part = KitAssets.template(name):Clone()
	local centre = (entry.min + entry.max) / 2
	part.Size = (entry.max - entry.min) * scale
	part.CFrame = base * CFrame.new(centre * scale)
	return part
end

function KitAssets.clear()
	for _, part in cache do
		part:Destroy()
	end
	table.clear(cache)
	table.clear(sources)
end

return KitAssets
