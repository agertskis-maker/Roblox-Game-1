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
-- Locked state (architecture review M7, review X2): the lock on Dusty Highway and Summit Pass is
-- built per player on the client (Portals.client.luau buildLock), so it is not in Edit mode. With
-- { locked = true } the test builds blocking boxes for it under Lane3_PortalSightShapes, in the
-- same frames as buildLock, for every gate whose Chained attribute is true (Downtown never is):
-- the padlock body and shackle, the LOCKED plaque hanging under it, the requirement plaque on
-- its pedestal (PlaqueBase), and, unless chains = false, the X chain runs and the four neck
-- wraps. Each box is the piece's KitManifest bounds (min..max in the piece frame), so it is the
-- mesh's bounding box: exact for the plaques and padlock, conservative for the chains (the open
-- link centres count as solid). task4-layout.js --locked uses the same boxes.
--
--   local I = game.ServerStorage.Island:Clone()
--   local S = require(I.Hub.Preview.PortalSight)
--   S.run()                                   -- unlocked (every portal open)
--   S.run({ locked = true })                  -- locked: lock pieces and chains
--   S.run({ locked = true, chains = false })  -- locked without the chains

local AssetService = game:GetService("AssetService")

local Cascade = require(script.Parent.Parent.Environment.Cascade)
local KitManifest = require(script.Parent.Parent.Environment.KitManifest)
local Layout = require(script.Parent.Parent.Layout)

local PortalSight = {}

local R, CY = 11, 13
local EYES = { 4.5, 5.5, 6.5 }

export type Options = {
	locked: boolean?, -- add the Dusty Highway and Summit Pass lock pieces (default false)
	chains: boolean?, -- with locked: include the X chains and neck wraps (default true)
}

-- The client lock's constants (Portals.client.luau buildLock): the X stands LOCK_AHEAD in front
-- of the field plane, its second diagonal 0.7 further forward; the padlock sits 0.35 in front of
-- the crossing.
local LOCK_AHEAD = 2
local DIAGONALS = {
	{ a = "left_high", b = "right_low", offset = 0 },
	{ a = "left_low", b = "right_high", offset = 0.7 },
}

local function kit(name: string): any
	return (KitManifest :: any)[name]
end

local function kitNumber(name: string, key: string, default: number): number
	local v = kit(name) and kit(name).meta[key]
	return if type(v) == "number" then v else default
end

local function kitPoint(name: string, key: string, default: Vector3): Vector3
	local v = kit(name) and kit(name).points[key]
	return if typeof(v) == "Vector3" then v else default
end

-- One gate's lock as blocking boxes { name, cf, size }, in buildLock's frames. Empty when the
-- gate is not chained or has no Origin.
local function lockBoxes(gate: Instance, chains: boolean): { { name: string, cf: CFrame, size: Vector3 } }
	local out = {}
	local gateFrame = gate:GetAttribute("Origin")
	if gate:GetAttribute("Chained") ~= true or typeof(gateFrame) ~= "CFrame" then
		return out
	end
	local function add(piece: string, label: string, frame: CFrame)
		local info = kit(piece)
		if not info then
			return
		end
		local lo, hi = info.min :: Vector3, info.max :: Vector3
		table.insert(out, { name = label, cf = frame * CFrame.new((lo + hi) / 2), size = hi - lo })
	end
	local function localPoint(key: string): Vector3?
		local v = gate:GetAttribute("pt_" .. key)
		return if typeof(v) == "Vector3" then v else nil
	end
	local front = gateFrame:VectorToWorldSpace(Vector3.zAxis)
	local setback = gate:GetAttribute("Setback")
	local fieldZ = if type(setback) == "number" then setback else 0
	local crossZ = fieldZ + LOCK_AHEAD
	local runPitch = kitNumber("GateChainRun", "run_pitch", 11)
	local runLength = kitPoint("GateChainRun", "last_link_centre", Vector3.new(8.8, 0, 0)).X
	for _, d in DIAGONALS do
		local la, lb = localPoint("chain_anchors_" .. d.a), localPoint("chain_anchors_" .. d.b)
		if la and lb then
			crossZ = math.max(crossZ, la.Z)
			if chains then
				local a, b = gateFrame:PointToWorldSpace(la), gateFrame:PointToWorldSpace(lb)
				local ahead = math.max(0, fieldZ + LOCK_AHEAD + d.offset - la.Z)
				local dir = (b - a).Unit
				local length = (b - a).Magnitude
				local count = math.max(1, math.floor((length - runLength) / runPitch) + 1)
				local start = (length - ((count - 1) * runPitch + runLength)) / 2
				local finish = start + (count - 1) * runPitch + runLength
				local function along(s0: number): Vector3
					local ramp = math.clamp(math.min((s0 - start) / runLength, (finish - s0) / runLength), 0, 1)
					return a + dir * s0 + front * (ahead * ramp)
				end
				for r = 0, count - 1 do
					local s0 = start + r * runPitch
					local p0, p1 = along(s0), along(s0 + runLength)
					local runDir = (p1 - p0).Unit
					local up = front:Cross(runDir).Unit
					add("GateChainRun", "ChainRun", CFrame.fromMatrix(p0, runDir, up))
				end
			end
		end
	end
	if chains then
		for _, key in { "left_low", "left_high", "right_low", "right_high" } do
			local at = localPoint("chain_wraps_" .. key)
			if at then
				add("GateChainWrap", "ChainWrap", gateFrame * CFrame.new(at))
			end
		end
	end
	local crossLocal = localPoint("chain_cross")
	if crossLocal then
		local cross = gateFrame:PointToWorldSpace(Vector3.new(crossLocal.X, crossLocal.Y, crossZ + 0.35))
		local below = kitNumber("GatePadlockBody", "assembly.body_centre_below_cross", 4.5)
		local body = CFrame.new(cross - Vector3.new(0, below, 0)) * gateFrame.Rotation
		add("GatePadlockBody", "PadlockBody", body)
		local hinge = body
			* CFrame.new(
				kitNumber("GatePadlockBody", "shackle_seat.1", -2.3),
				kitNumber("GatePadlockBody", "shackle_seat.2", 2.4),
				0
			)
		add("GatePadlockShackle", "PadlockShackle", hinge)
		local eyeY = kitPoint("GatePadlockBody", "plaque_eyes.1", Vector3.new(-2.4, -2.925, 0)).Y
		local ringY = kitPoint("GateLockedPlaque", "hang_rings.1", Vector3.new(-2.4, 2.42, 0)).Y
		add("GateLockedPlaque", "LockedPlaque", body * CFrame.new(0, eyeY - 0.5 - ringY, 0))
	end
	local base = gate:GetAttribute("PlaqueBase")
	if typeof(base) == "CFrame" then
		add("GateRequirementPlaque", "RequirementPlaque", base)
	end
	return out
end

function PortalSight.run(options: Options?): { [string]: any }
	local locked = options ~= nil and options.locked == true
	local withChains = not (options ~= nil and options.chains == false)
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
	local shaped = 0
	-- Task 4: the portal gates (in the rig) and the Garage / Stunt destinations get the same
	-- treatment, so a gate column is judged by its real shape, not its box
	local shapeSources: { Instance } = {}
	for _, name in { "ParkDressing", "Portals", "Destinations" } do
		local folder = env and env:FindFirstChild(name)
		if folder then
			table.insert(shapeSources, folder)
		end
	end
	for _, source in shapeSources do
		for _, d in source:GetDescendants() do
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
	-- the locked state: the client lock's pieces as solid boxes, one Folder "<World>Lock" each
	local lockPieces = 0
	if locked and rig then
		for _, gate in rig:GetChildren() do
			local boxes = lockBoxes(gate, withChains)
			if #boxes > 0 then
				local folder = Instance.new("Folder")
				folder.Name = tostring(gate:GetAttribute("World") or gate.Name) .. "Lock"
				folder.Parent = shapes
				for _, b in boxes do
					local p = Instance.new("Part")
					p.Name = b.name
					p.Anchored = true
					p.CanCollide = false
					p.CanQuery = true
					p.Transparency = 0.5
					p.Size = b.size
					p.CFrame = b.cf
					p.Parent = folder
					lockPieces += 1
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
	-- points across the lower falls (11 west to 9 east of the falls line, 4 to 70 up, in front of
	-- the cliff; Task 4: x -113 to -93 after the move east, was -131 to -111)
	local aimX = Cascade.X - 1
	local aimZ = -(Cascade.LowerFaceY + 4)
	local targetZ = -(Cascade.LowerFaceY + 5)
	local falls = {}
	for i, tri in park.corridors do
		local e = Vector3.new(tri[1].X, Layout.SurfaceY + 5.5, -tri[1].Y)
		local toFalls = (Vector3.new(aimX, 0, aimZ) - e) * Vector3.new(1, 0, 1)
		local side = Vector3.new(-toFalls.Unit.Z, 0, toFalls.Unit.X)
		local total, blocked = 0, 0
		local by: { [string]: number } = {}
		for _, s2 in { -2, 0, 2 } do
			for _, dx in { -10, -5, 0, 5, 10 } do
				local x = aimX + dx
				for _, y in { 4, 15, 30, 50, 70 } do
					total += 1
					local eye = e + side * s2
					local hit = workspace:Raycast(eye, Vector3.new(x, y, targetZ) - eye, params)
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
	return {
		rows = rows,
		worstVisiblePercent = math.round(worst * 10000) / 100,
		shapedCopies = shaped,
		falls = falls,
		locked = locked,
		chains = locked and withChains,
		lockPieces = lockPieces,
	}
end

return PortalSight
