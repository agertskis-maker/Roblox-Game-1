--!strict
-- Island kit meshes (Lane 3, build-time). Turns the compact mesh data written by
-- assets/island/kit/build_kit.py (shared positions; per triangle three vertex indices and a
-- palette swatch) into an EditableMesh with flat normals and palette UVs, for previews in
-- Studio and for uploading. The palette image is AssetIds.Palette.

local AssetService = game:GetService("AssetService")

local KitMesh = {}

export type Data = {
	name: string,
	triangles: number,
	bounds: { { number } },
	meta: { [string]: any },
	grid: number,
	p: { number },
	t: { number },
}

function KitMesh.editable(data: Data): EditableMesh
	local em = AssetService:CreateEditableMesh()
	local p = data.p
	local ids = table.create(#p // 3)
	local positions = table.create(#p // 3)
	-- A MeshPart draws an EditableMesh about the mesh origin, while an uploaded mesh is centred
	-- on its bounds; centring here makes previews and uploads place identically.
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

-- A MeshPart shown in this Studio session only (EditableMesh content is not saved or uploaded).
function KitMesh.previewPart(data: Data, textureId: string): (MeshPart, EditableMesh)
	local em = KitMesh.editable(data)
	local part = AssetService:CreateMeshPartAsync(Content.fromObject(em), {
		CollisionFidelity = Enum.CollisionFidelity.Box,
		RenderFidelity = Enum.RenderFidelity.Automatic,
	})
	part.Name = data.name
	part.TextureID = textureId
	part.Anchored = true
	part.Material = Enum.Material.SmoothPlastic
	return part, em
end

return KitMesh
