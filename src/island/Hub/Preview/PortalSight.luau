--!strict
-- DEVELOPMENT CHECKS (Lane 3). Ray tests in the built island (edit mode) of how much of each
-- portal can be seen from each plot entrance: the frameless field (Environment/PortalRig) when
-- the environment is built, else the greybox disc. From each entrance,
-- 27 eye points (eye 4.5, 5.5 and 6.5 studs up; 3 studs either side and 4 ahead and behind the
-- entrance point, for player and camera variation), rays to points filling each portal's disc
-- (radius 11, every 1.5 studs, plus 32 points on its edge). A ray is blocked by any solid part,
-- mesh or terrain on the way, except the portal models themselves and invisible parts. Kit dressing does not take
-- queries in the game, so it is switched on for the test and back off after. Particles and beams
-- (water, spray) are not solid and are judged by eye (see the review page). It also reports how
-- much of the lower falls each entrance sees.
--
--   local I = game.ServerStorage.Island:Clone()
--   require(I.Hub.Preview.PortalSight).run()

local AssetService = game:GetService("AssetService")

local Layout = require(script.Parent.Parent.Layout)

local PortalSight = {}

local R, CY = 11, 13
local EYES = { 4.5, 5.5, 6.5 }

function PortalSight.run(): { [string]: any }
	local park = Layout.Data.park
	local preview = workspace:FindFirstChild("Lane3_IslandPreview")
	assert(preview, "Build the hub preview first")
	local portals = preview:FindFirstChild("Portals", true)
	assert(portals, "No portal placeholders")
	local env = workspace:FindFirstChild("Lane3_IslandEnvironment")
	local rig = env and env:FindFirstChild("Portals")
	local switched: { BasePart } = {}
	if env then
		for _, d in env:GetDescendants() do
			if d:IsA("BasePart") and not d.CanQuery and d.Transparency < 1 then
				d.CanQuery = true
				table.insert(switched, d)
			end
		end
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local exclude: { Instance } = { portals }
	local walkers = workspace:FindFirstChild("Lane3_Wildlife")
	if walkers then
		table.insert(exclude, walkers)
	end
	-- invisible colliders and hosts hide nothing
	for _, d in workspace:GetDescendants() do
		if d:IsA("BasePart") and d.Transparency >= 1 then
			table.insert(exclude, d)
		end
	end
	-- kit meshes collide as boxes in the game; for this test the park dressing gets temporary
	-- copies with their real shape (precise convex decomposition) and the box originals are left
	-- out, so a round fountain or a cone topiary is not judged by its bounding box
	local shapes = Instance.new("Folder")
	shapes.Name = "Lane3_PortalSightShapes"
	shapes.Parent = workspace
	local dressing = env and env:FindFirstChild("ParkDressing")
	local shaped = 0
	if dressing then
		for _, d in dressing:GetDescendants() do
			if d:IsA("MeshPart") and d.Transparency < 1 then
				local ok, copy = pcall(function()
					return AssetService:CreateMeshPartAsync(d.MeshContent, {
						CollisionFidelity = Enum.CollisionFidelity.PreciseConvexDecomposition,
					})
				end)
				if ok and copy then
					copy.Size = d.Size
					copy.CFrame = d.CFrame
					copy.Anchored = true
					copy.Transparency = 0.5
					copy.Name = d.Name
					copy.Parent = shapes
					table.insert(exclude, d)
					shaped += 1
				end
			end
		end
	end
	params.FilterDescendantsInstances = exclude

	local rows = {}
	local worst = 1
	for i, tri in park.corridors do
		local e = Vector3.new(tri[1].X, Layout.SurfaceY, -tri[1].Y)
		local fwd = (Vector3.new(0, 0, 0) - e) * Vector3.new(1, 0, 1)
		fwd = fwd.Unit
		local side = Vector3.new(-fwd.Z, 0, fwd.X)
		for _, q in park.portals do
			local model = portals:FindFirstChild(q.id) :: Model?
			local centre = if model then model:GetBoundingBox().Position else Vector3.new(q.x, CY, 57)
			local targets: { Vector3 } = {}
			local field = rig and rig:FindFirstChild(q.id) :: BasePart?
			if field then
				-- the frameless field: points filling its 20 x 30 outline, 1 stud in front of it
				local fw, fh = field:GetAttribute("Width") :: number, field:GetAttribute("Height") :: number
				for u = -fw / 2 + 1, fw / 2 - 1, 1.5 do
					for v = -fh / 2 + 1, fh / 2 - 1, 1.5 do
						table.insert(targets, (field.CFrame * CFrame.new(u, v, -1)).Position)
					end
				end
			else
				for u = -R, R, 1.5 do
					for v = -R, R, 1.5 do
						if u * u + v * v <= R * R then
							table.insert(targets, Vector3.new(centre.X + u, CY + v, centre.Z - 1))
						end
					end
				end
				for a = 0, 31 do
					local t = a / 32 * math.pi * 2
					table.insert(targets, Vector3.new(centre.X + math.cos(t) * R, CY + math.sin(t) * R, centre.Z - 1))
				end
			end
			local total, blocked = 0, 0
			local by: { [string]: number } = {}
			for _, h in EYES do
				for _, s in { -3, 0, 3 } do
					for _, f in { -4, 0, 4 } do
						local eye = e + side * s + fwd * f + Vector3.new(0, h, 0)
						for _, target in targets do
							total += 1
							local hit = workspace:Raycast(eye, target - eye, params)
							if hit then
								blocked += 1
								local inst = hit.Instance
								local key = if inst == workspace.Terrain
									then "Terrain"
									else (inst:GetFullName()
										:gsub("^Workspace%.", "")
										:gsub("Lane3_IslandEnvironment%.", "")
										:gsub("Lane3_IslandPreview%.Island%.", ""))
								by[key] = (by[key] or 0) + 1
							end
						end
					end
				end
			end
			local visible = 1 - blocked / total
			worst = math.min(worst, visible)
			local blockers = {}
			for k, n in by do
				table.insert(blockers, { k = k, n = n })
			end
			table.sort(blockers, function(a, b)
				return a.n > b.n
			end)
			local names = {}
			for j = 1, math.min(4, #blockers) do
				table.insert(names, string.format("%s (%d)", blockers[j].k, blockers[j].n))
			end
			table.insert(rows, {
				entrance = i,
				portal = q.id,
				rays = total,
				visible = math.round(visible * 10000) / 100,
				blockers = names,
			})
		end
	end
	-- the lower falls from each entrance: eye 5.5 at the entrance and 2 studs either side, to 25
	-- points across the lower falls (x -131 to -111, 4 to 70 up, in front of the cliff)
	local falls = {}
	for i, tri in park.corridors do
		local e = Vector3.new(tri[1].X, Layout.SurfaceY + 5.5, -tri[1].Y)
		local toFalls = (Vector3.new(-121, 0, 272) - e) * Vector3.new(1, 0, 1)
		local side = Vector3.new(-toFalls.Unit.Z, 0, toFalls.Unit.X)
		local total, blocked = 0, 0
		local by: { [string]: number } = {}
		for _, s2 in { -2, 0, 2 } do
			for _, x in { -131, -126, -121, -116, -111 } do
				for _, y in { 4, 15, 30, 50, 70 } do
					total += 1
					local eye = e + side * s2
					local hit = workspace:Raycast(eye, Vector3.new(x, y, 271) - eye, params)
					if hit then
						blocked += 1
						local key = if hit.Instance == workspace.Terrain then "Terrain" else hit.Instance:GetFullName()
						by[key] = (by[key] or 0) + 1
					end
				end
			end
		end
		local names = {}
		for k, n in by do
			table.insert(names, string.format("%s (%d)", k, n))
		end
		table.insert(
			falls,
			{ entrance = i, rays = total, visible = math.round((1 - blocked / total) * 10000) / 100, blockers = names }
		)
	end
	for _, d in switched do
		d.CanQuery = false
	end
	shapes:Destroy()
	return { rows = rows, worstVisiblePercent = math.round(worst * 10000) / 100, shapedCopies = shaped, falls = falls }
end

return PortalSight
