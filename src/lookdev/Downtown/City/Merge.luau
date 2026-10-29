--!strict
-- Per-segment mesh merging for the Downtown B city preview in a PLAY client (Lane 3, HUD rebuild
-- 2026-10-23). Measured in Studio: a playtest client here can hold only 8 EditableMeshes at once
-- (CreateEditableMesh returns nil after 8, with or without FixedSize), so one EditableMesh per kit
-- piece cannot show a city. Instead every kit piece of one road segment is transformed into world
-- space and appended to one shared EditableMesh (a second one only if a segment passes the
-- 20,000-triangle / 60,000-vertex limits). Built over several frames so a new segment does not
-- stall the chase. Edit mode keeps the per-piece templates (its budget is much larger).
--
--   local job = Merge.start(items, { swatches, textureId, parent, name, maxMeshes = n })
--   job.done         -- true when every piece is in
--   job.parts        -- MeshParts created (world-space geometry, each at its bounds centre)
--   job.meshes       -- their EditableMeshes (count against the client budget)
--   job.triangles    -- triangles merged
--   job.failed       -- reason string when the budget refused a mesh (remaining pieces dropped)
--   Merge.cancel(job) -- stops a running job and destroys what it made
--
-- Preview only: geometry has no collision and no query (CanCollide/CanQuery/CanTouch false), so
-- the playground's own ground parts and the Hop ring's downward ray are unaffected.

local AssetService = game:GetService("AssetService")

local KitMesh = require(script.Parent.Parent.KitMesh)

local Merge = {}

local MAX_TRIANGLES = 19000 -- headroom under the documented 20k EditableMesh limit
local MAX_VERTICES = 57000
local TRIANGLES_PER_FRAME = 2500

export type Item = { data: KitMesh.Data, cframe: CFrame, scale: Vector3? }
export type Options = {
	swatches: { Color3 }?,
	textureId: string?,
	parent: Instance,
	name: string,
	maxMeshes: () -> boolean, -- asked before each new EditableMesh: true when one may be made
	onMesh: ((EditableMesh) -> ())?,
}
export type Job = {
	done: boolean,
	cancelled: boolean,
	parts: { MeshPart },
	meshes: { EditableMesh },
	triangles: number,
	failed: string?,
}

local function finish(job: Job, em: EditableMesh, opts: Options, index: number, centre: Vector3)
	local ok, part = pcall(function()
		return AssetService:CreateMeshPartAsync(Content.fromObject(em), {
			CollisionFidelity = Enum.CollisionFidelity.Box,
			RenderFidelity = Enum.RenderFidelity.Automatic,
		})
	end)
	if not ok or not part then
		job.failed = "CreateMeshPartAsync failed: " .. tostring(part)
		return
	end
	local p = part :: MeshPart
	p.Name = opts.name .. "_" .. index
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = true
	p.Material = Enum.Material.SmoothPlastic
	p.TextureID = opts.textureId or ""
	-- the vertices are centred on the chunk bounds; the part goes to that centre
	p.CFrame = CFrame.new(centre)
	if job.cancelled then
		p:Destroy()
		return
	end
	p.Parent = opts.parent
	table.insert(job.parts, p)
end

local function worldOf(item: Item, centre: Vector3, i: number): Vector3
	local p = item.data.p
	local scale = item.scale or Vector3.one
	return item.cframe:PointToWorldSpace((Vector3.new(p[i], p[i + 1], p[i + 2]) - centre) * scale)
end

local function boundsCentre(data: KitMesh.Data): Vector3
	local blo, bhi = data.bounds[1], data.bounds[2]
	return Vector3.new((blo[1] + bhi[1]) / 2, (blo[2] + bhi[2]) / 2, (blo[3] + bhi[3]) / 2)
end

function Merge.start(items: { Item }, opts: Options): Job
	local job: Job = { done = false, cancelled = false, parts = {}, meshes = {}, triangles = 0, failed = nil }
	task.spawn(function()
		-- split into chunks under the EditableMesh limits
		local chunks: { { Item } } = {}
		local current: { Item } = {}
		local tris, verts = 0, 0
		for _, item in items do
			local n = #item.data.p // 3
			local faces = #item.data.t // 4
			if #current > 0 and (tris + faces > MAX_TRIANGLES or verts + n > MAX_VERTICES) then
				table.insert(chunks, current)
				current, tris, verts = {}, 0, 0
			end
			table.insert(current, item)
			tris += faces
			verts += n
		end
		if #current > 0 then
			table.insert(chunks, current)
		end
		local budget = TRIANGLES_PER_FRAME
		for index, chunk in chunks do
			if job.cancelled then
				break
			end
			-- pass 1: the chunk's world bounds, so the vertices can be centred on them (the same rule
			-- the per-piece previews use: a MeshPart draws its mesh about the part position)
			local lo, hi = Vector3.one * math.huge, -Vector3.one * math.huge
			for _, item in chunk do
				local centre = boundsCentre(item.data)
				for i = 1, #item.data.p, 3 do
					local v = worldOf(item, centre, i)
					lo = lo:Min(v)
					hi = hi:Max(v)
				end
			end
			local mid = (lo + hi) / 2
			-- pass 2: build
			if not opts.maxMeshes() then
				job.failed = "EditableMesh budget reached (merge)"
				break
			end
			local mesh = AssetService:CreateEditableMesh()
			if not mesh then
				job.failed = "CreateEditableMesh returned nil (client memory budget)"
				break
			end
			table.insert(job.meshes, mesh)
			if opts.onMesh then
				opts.onMesh(mesh)
			end
			local uvs: { [number]: number } = {}
			local colours: { [number]: number } = {}
			for _, item in chunk do
				if job.cancelled then
					break
				end
				local data = item.data
				local centre = boundsCentre(data)
				local n = #data.p // 3
				local ids = table.create(n)
				local local3 = table.create(n)
				for i = 1, #data.p, 3 do
					local v = worldOf(item, centre, i) - mid
					table.insert(local3, v)
					table.insert(ids, mesh:AddVertex(v))
				end
				local grid = data.grid
				local t = data.t
				for i = 1, #t, 4 do
					local a, b, c, swatch = t[i] + 1, t[i + 1] + 1, t[i + 2] + 1, t[i + 3]
					local face = mesh:AddTriangle(ids[a], ids[b], ids[c])
					local uv = uvs[swatch]
					if not uv then
						uv = mesh:AddUV(Vector2.new((swatch % grid + 0.5) / grid, (swatch // grid + 0.5) / grid))
						uvs[swatch] = uv
					end
					mesh:SetFaceUVs(face, { uv, uv, uv })
					if opts.swatches then
						local colour = colours[swatch]
						if not colour then
							colour = mesh:AddColor(opts.swatches[swatch + 1] or Color3.new(1, 0, 1), 1)
							colours[swatch] = colour
						end
						mesh:SetFaceColors(face, { colour, colour, colour })
					end
					local normal = (local3[b] - local3[a]):Cross(local3[c] - local3[a])
					if normal.Magnitude > 1e-9 then
						local nId = mesh:AddNormal(normal.Unit)
						mesh:SetFaceNormals(face, { nId, nId, nId })
					end
				end
				local faces = #t // 4
				job.triangles += faces
				budget -= faces
				if budget <= 0 then
					budget = TRIANGLES_PER_FRAME
					task.wait()
				end
			end
			if not job.cancelled then
				finish(job, mesh, opts, index, mid)
			end
		end
		job.done = true
	end)
	return job
end

function Merge.cancel(job: Job)
	job.cancelled = true
	for _, p in job.parts do
		p:Destroy()
	end
	for _, em in job.meshes do
		em:Destroy()
	end
	table.clear(job.parts)
	table.clear(job.meshes)
end

return Merge
